# Solution: Create A Backup Token

Work the task yourself first. Running `astrona submit -c sections/section-040/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: the token in the Secret is an orphan, periodic and has the right policy, it can take a snapshot, it can neither read a secret nor restore, and the original data.

## Step 1: Write the policy

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 policy write snapshot-backup - <<'POLICY'
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
POLICY
bao_on openbao-0 policy read snapshot-backup
```

A snapshot is a `read` on this path. A restore is an `update`, so the policy leaves it out.

## Step 2: Create an orphan, periodic token

```sh
JOB_TOKEN=$(bao_on openbao-0 token create -orphan -period=24h -policy=snapshot-backup -field=token)
bao_on openbao-0 token lookup "$JOB_TOKEN"
```

The lookup shows `orphan true`, `period 24h` and the policies `default` and `snapshot-backup`. A child token would end together with the token that created it, and a token with only a TTL would stop at its maximum lifetime.

## Step 3: Store the token in a Secret

```sh
kubectl -n openbao create secret generic snapshot-backup-token --from-literal=token="$JOB_TOKEN"
```

## Step 4: Test the token as the job would use it

```sh
T=$(kubectl -n openbao get secret snapshot-backup-token -o jsonpath='{.data.token}' | base64 -d)
H=http://openbao-active.openbao.svc.cluster.local:8200
kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' -H "X-Vault-Token: $T" $H/v1/sys/storage/raft/snapshot
kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' -H "X-Vault-Token: $T" $H/v1/secret/data/platform/marker
kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "X-Vault-Token: $T" $H/v1/sys/storage/raft/snapshot
```

The answers are `200`, `403` and `403`: the token takes a snapshot, cannot read a secret and cannot restore.
