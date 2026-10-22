# Solution: Restore Quorum And Remove A Dead Peer

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: exactly three voters and no other peer, a leader that accepts a write, the autopilot configuration, and the original data.

## Step 1: See the state of every pod

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
kubectl -n openbao get pods
for pod in openbao-0 openbao-1 openbao-2; do echo "== $pod"; bao_on "$pod" status | grep -E 'Sealed|HA Mode|Active Node'; done
```

`openbao-0` is unsealed but has no active node: it waits for an election it cannot win. `openbao-1` and `openbao-2` are sealed, because they restarted and the cluster uses the Shamir seal.

## Step 2: Work out the quorum

The Raft configuration still has the fourth node from the load test. The StatefulSet was scaled down without `remove-peer`, so `openbao-3` is still a voter. That makes four voters with a quorum of three. Only `openbao-0` takes part in elections, so no leader can be elected.

You cannot read `list-peers` yet, because it needs a leader. Bringing the two sealed voters back is enough: three of four voters form a quorum.

## Step 3: Unseal the two sealed voters

```sh
KEY="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
bao_on openbao-1 operator unseal "$KEY"
bao_on openbao-2 operator unseal "$KEY"
sleep 15
bao_on openbao-0 operator raft list-peers
```

Now three of four voters answer, they elect a leader, and `list-peers` works. It shows four peers: `openbao-0` to `openbao-2`, and `openbao-3`, which no longer exists.

## Step 4: Remove the dead peer

```sh
bao_on openbao-0 operator raft remove-peer openbao-3
bao_on openbao-0 operator raft list-peers
```

Three voters remain, with a quorum of two. The cluster survives one failure again. A standby forwards the command to the leader, so it works on any unsealed pod.

## Step 5: Configure autopilot

```sh
bao_on openbao-0 operator raft autopilot set-config \
  -cleanup-dead-servers=true \
  -min-quorum=3 \
  -dead-server-last-contact-threshold=10m
```

The next time a pod disappears for good, autopilot removes it after 10 minutes, but never below three voters.

## Step 6: Prove it and submit

```sh
bao_on openbao-0 kv put secret/platform/quorum-check at="$(date)"
bao_on openbao-0 kv get secret/platform/marker
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `peers.json` recovery | Works, but risks uncommitted writes; the lost nodes could simply come back |
| Re-initialize the cluster | Every secret, policy and token is gone; the grader finds no marker |
| Scale the StatefulSet back to four | Brings `openbao-3` back, but the task is a three-node cluster, and the next scale-down repeats the problem |
| `remove-peer` before unsealing | Fails: the command needs a leader, and there is none without a quorum |
