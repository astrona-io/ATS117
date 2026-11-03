# A Least-Privilege Backup Token

A backup job runs every night without a person. If it uses the root token, a leak of the job's credentials gives away the whole cluster. A snapshot needs only one permission, so the job should have only that. This part writes the policy, creates a token that fits a job, and checks what the token can and cannot do.

## What a snapshot needs

Saving a snapshot is a `read` on the path `sys/storage/raft/snapshot`. Restoring one is an `update` on the same path. The two operations use the same path with different capabilities, so a policy that grants only `read` can take backups and cannot restore them. This matters: a stolen backup token should not be able to replace the cluster's data.

Set up the helper and write the policy:

<!-- astrona:playground:renew -->

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

## A token that fits a job

A job needs a token that does not expire in the middle of its life and that does not depend on a person's token. Two properties give that:

- An **orphan** token has no parent. When the token that created it is revoked or expires, the orphan keeps working. A child token would be revoked together with its parent.
- A **periodic** token has no maximum lifetime. It expires only if it is not renewed within its period.

Create one with a period of 24 hours, and read its properties:

```sh
JOB_TOKEN=$(bao_on openbao-0 token create -orphan -period=24h -policy=snapshot-backup -field=token)
bao_on openbao-0 token lookup "$JOB_TOKEN"
```

The lookup shows `orphan true`, `period 24h` and the policies `default` and `snapshot-backup`. The job must renew the token within 24 hours, or it expires. A nightly job that calls `bao token renew-self` before it takes the snapshot, or one that reads the token's TTL, stays inside the period. A token without renewal fails silently on the first night after it expires.

Store the token where the job can read it, and nowhere else. In Kubernetes, that is a Secret in the namespace of the job:

```sh
kubectl -n openbao create secret generic snapshot-backup-token --from-literal=token="$JOB_TOKEN"
```

## Check what the token can do

Test the token from the `tester` pod, as the job would use it. Replace nothing in the commands; the Service `openbao-active` reaches the active node:

```sh
T=$(kubectl -n openbao get secret snapshot-backup-token -o jsonpath='{.data.token}' | base64 -d)
for req in "GET /v1/sys/storage/raft/snapshot" "GET /v1/secret/data/platform/marker" "POST /v1/sys/storage/raft/snapshot"; do
  set -- $req
  echo "$req: $(kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}' -X "$1" -H "X-Vault-Token: $T" "http://openbao-active.openbao.svc.cluster.local:8200$2")"
done
```

The first request answers `200`: the token can take a snapshot. The second and third answer `403`: it cannot read a secret, and it cannot restore. This is the test to repeat after every change to the policy.

## Where the token must not go

The backup token protects the snapshot, not the keys. A snapshot is encrypted, so someone with the file and the token still cannot read secrets. Keep the unseal keys or the seal's key service out of the namespace of the backup job, as the first module explained. The job holds a token that can read the snapshot and nothing that can open it.

You now know the policy that fits a backup job, why the token must be an orphan and periodic, and how to prove the token cannot do more than it should. The next part schedules the job.

## Common pitfalls

> [!WARNING]
> - **Using the root token for backups.** One leaked credential then opens everything.
> - **Giving the backup policy `update` on the snapshot path.** The same token could then restore, and replace the cluster's data.
> - **A child token as the job's token.** It is revoked together with the token that created it.
> - **A periodic token that nobody renews.** It expires after its period and the backups stop without a visible error.

## Your mission: Create A Backup Token

You can now write a least-privilege policy and create an orphan, periodic token. The graded lab gives you a cluster that has no backup identity and asks you to create it.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-117-playground-040-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-040/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-117-lab-040-02
astrona start ats-117-playground-040-02
```
