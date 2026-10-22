# Solution: Join The Third Node And Configure Autopilot

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: three voters, the autopilot configuration, a write after the leader is lost, and that the original data is still there.

## Step 1: Compare the pods with the Raft configuration

Set up the token and the helper, then look at both views of the cluster:

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
kubectl -n openbao get pods
bao_on openbao-0 operator raft list-peers
```

All three pods run, but `openbao-2` shows `0/1` in the `READY` column, and `list-peers` lists only `openbao-0` and `openbao-1`. Two voters have a quorum of two: one more failure stops every write.

## Step 2: Find out why openbao-2 is missing

Ask `openbao-2` itself:

```sh
bao_on openbao-2 status
```

It reports `Sealed true`. The cluster uses the Shamir seal, and a node joins through `retry_join` only after it is unsealed, because it must decrypt the leader's challenge with the cluster's key. Nobody unsealed `openbao-2`, so it never joined.

## Step 3: Unseal openbao-2

Enter the lab-only key on `openbao-2`:

```sh
bao_on openbao-2 operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
```

Wait a few seconds for autopilot's stabilization time, then check again:

```sh
sleep 15
bao_on openbao-0 operator raft list-peers
```

Three rows now, all with `true` in the voter column. Re-initializing or deleting the volume would also give you three pods, but it would throw away the cluster's data; the grader checks that `secret/platform/marker` still exists.

## Step 4: Configure autopilot

Run the change on the leader, the pod that `list-peers` marks as `leader`:

```sh
bao_on openbao-0 operator raft autopilot set-config \
  -cleanup-dead-servers=true \
  -min-quorum=3 \
  -dead-server-last-contact-threshold=10m
bao_on openbao-0 operator raft autopilot get-config
```

If `openbao-0` is not the leader, the standby forwards the request to the active node, so the command still works. The output shows `Cleanup Dead Servers` as `true` and `Min Quorum` as `3`.

## Step 5: Prove the cluster survives losing the leader

The grader does this for you, but it is worth seeing once. Delete the leader, wait, and write through another pod:

```sh
kubectl -n openbao delete pod openbao-0 --wait=false
sleep 20
bao_on openbao-1 kv put secret/platform/failover-check at="$(date)"
bao_on openbao-0 operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
```

The write succeeds because two of three voters remain. The last line unseals the restarted pod so the cluster has three voters again.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Common mistakes

- Checking `kubectl get pods` only. Running pods are not voters; `list-peers` is the cluster's own view.
- Running `bao operator init` on `openbao-2`. It belongs to an existing cluster; initializing it would try to start a second, separate cluster.
- Turning on cleanup without `-min-quorum`. OpenBao refuses the change.
