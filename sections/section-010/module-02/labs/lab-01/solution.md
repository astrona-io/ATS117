# Solution: Retire A Node And Keep Quorum Safe

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: three voters, a healthy autopilot state with a failure tolerance of 1, the removed claim, and that the original data is still there.

## Step 1: Compare the pods with the Raft configuration

Set up the token and the helper, then look at both views of the cluster:

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
kubectl -n openbao get pods
bao_on openbao-0 operator raft list-peers
```

Three pods run, but `list-peers` shows four voters. `openbao-3` has no pod. Four voters have a quorum of three, so the cluster survives no failure, even though every request still works.

## Step 2: Remove the dead peer

```sh
bao_on openbao-0 operator raft remove-peer openbao-3
bao_on openbao-0 operator raft list-peers
```

Three voters remain. The command works on any unsealed pod, because a standby forwards it to the leader.

## Step 3: Remove the leftover volume

Scaling a StatefulSet down keeps the claims of the removed pods. List them, then delete the one for the removed node:

```sh
kubectl -n openbao get pvc
kubectl -n openbao delete pvc data-openbao-3
```

Delete only `data-openbao-3`. The claims of the other three pods hold the cluster's data.

## Step 4: Check autopilot

```sh
bao_on openbao-0 operator raft autopilot state
```

`Healthy` is `true` and `Failure Tolerance` is `1`. Autopilot may need a few seconds after the removal to update.

## Step 5: Submit

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

## Common mistakes

- Deleting the claim first or scaling again. The Raft configuration is the problem, not the pods.
- Running `bao operator init` on a pod. The cluster is already initialized.
- Deleting every claim that `kubectl get pvc` lists. Only the claim of the retired node goes.
