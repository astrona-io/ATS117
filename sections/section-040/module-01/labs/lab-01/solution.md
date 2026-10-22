# Solution: Restore A Deleted Secret From A Snapshot

Work the task yourself first. Running `astrona submit -c sections/section-040/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: the restored secret, the later secret, a healthy cluster, and the original data.

## Step 1: Set up and find the leader

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
```

The steps below assume `openbao-0` is the leader. If another pod is, use its name.

## Step 2: Save the change that must survive

A restore rolls back everything written after the snapshot, so read the later secret first:

```sh
API_KEY=$(bao_on openbao-0 kv get -field=key secret/payments/api)
echo "$API_KEY"
```

Keep that value until the end of the task.

## Step 3: Get the snapshot into the leader pod

The ConfigMap stores the snapshot as binary data. Decode it to a file and copy it into the pod:

```sh
kubectl -n openbao get configmap nightly-snapshot -o jsonpath='{.binaryData.nightly\.snap}' | base64 -d > nightly.snap
kubectl -n openbao exec -i openbao-0 -- sh -c 'cat > /tmp/nightly.snap' < nightly.snap
```

## Step 4: Restore

```sh
bao_on openbao-0 operator raft snapshot restore /tmp/nightly.snap
sleep 15
bao_on openbao-0 operator raft list-peers
```

The snapshot was made by this cluster, so its keys match and the restore needs no `-force`. The cluster stays unsealed. If the leader changed during the restore, use the new leader's name from here on.

## Step 5: Check, and write the later change again

```sh
bao_on openbao-0 kv get secret/payments/db
bao_on openbao-0 kv get secret/payments/api
```

`secret/payments/db` is back. `secret/payments/api` is gone, as expected. Write it again with the value you saved:

```sh
bao_on openbao-0 kv put secret/payments/api key="$API_KEY"
```

## Step 6: Submit

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

## Common mistakes

- Restoring first and reading `secret/payments/api` afterwards. It is already gone.
- Using `-force`. Not needed here, and dangerous when the keys do not match.
- Restoring into a standby pod. Run the restore against the leader.
