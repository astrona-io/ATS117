# Solution: Upgrade The Cluster From 2.7.0 To 2.7.1 Safely

Work the task yourself first. Running `astrona submit -c sections/section-040/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: the version of every pod, the snapshot and its timing, a healthy cluster, and the original data.

## Step 1: Set up and look at the cluster

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
export SHAMIR_KEY=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
for pod in openbao-0 openbao-1 openbao-2; do bao_on "$pod" status | grep Version; done
```

All three report 2.7.0. The steps below assume `openbao-0` is the leader; swap names if not.

## Step 2: Snapshot first, and keep it

```sh
bao_on openbao-0 operator raft snapshot save /tmp/pre-upgrade.snap
kubectl -n openbao exec -i openbao-0 -- cat /tmp/pre-upgrade.snap > pre-upgrade.snap
kubectl -n openbao create configmap pre-upgrade-snapshot --from-file=pre-upgrade.snap=pre-upgrade.snap
```

The snapshot is now outside the pods. In production it would go to storage outside the cluster as well.

## Step 3: Change the template

```sh
helm repo add openbao https://openbao.github.io/openbao-helm
helm upgrade openbao openbao/openbao --version 0.30.4 -n openbao --reuse-values --set server.image.tag=2.7.1
kubectl -n openbao get statefulset openbao -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The template now names 2.7.1. No pod restarted, because the StatefulSet uses `OnDelete`.

## Step 4: Upgrade the standbys, one at a time

```sh
for pod in openbao-1 openbao-2; do
  kubectl -n openbao delete pod "$pod"
  sleep 20
  bao_on "$pod" operator unseal "$SHAMIR_KEY"
  sleep 10
  bao_on "$pod" status | grep Version
  bao_on openbao-0 operator raft list-peers
done
```

Wait for three voters after each pod before the next one.

## Step 5: Step the leader down and upgrade it last

```sh
bao_on openbao-0 operator step-down
sleep 15
bao_on openbao-1 operator raft list-peers
kubectl -n openbao delete pod openbao-0
sleep 20
bao_on openbao-0 operator unseal "$SHAMIR_KEY"
for pod in openbao-0 openbao-1 openbao-2; do bao_on "$pod" status | grep Version; done
```

All three report 2.7.1, with one of the first upgraded pods now the leader.

## Step 6: Submit

```sh
bao_on openbao-1 kv get secret/platform/marker
astrona submit -c sections/section-040/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Snapshot after the upgrade | It cannot take you back to 2.7.0's data; the grader checks the timing |
| Delete all three pods after `helm upgrade` | Quorum is lost, and every pod needs unsealing at once |
| Change the StatefulSet's update strategy to `RollingUpdate` | Kubernetes waits for a sealed pod to become Ready, which it never does |
| Upgrade the leader first | The cluster elects twice, and older standbys follow a newer leader |
