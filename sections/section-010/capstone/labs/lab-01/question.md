# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** High availability with Integrated Storage

## Scenario

Last week the team scaled the OpenBao StatefulSet in the namespace `openbao` to four pods for a load test, then back to three. Nobody touched Raft. This morning two pods restarted after a node maintenance. Now every write to OpenBao fails, and applications cannot renew their leases.

`kubectl get pods` shows three pods running. The data is still on every volume.

## Your task

1. Find out why the cluster cannot elect a leader.
2. Bring the cluster back to a working state without losing data.
3. Clean up the Raft configuration so it matches the three pods that exist.
4. Configure autopilot so a server that is gone for 10 minutes is removed automatically, but the cluster never drops below three voters.

The lab-only unseal key and root token are in the Secret `openbao-init`.

## Constraints

- Do not initialize the cluster again, do not delete PersistentVolumeClaims, and do not use a `peers.json` recovery. The lost nodes can come back.
- Do not change the Helm release or the StatefulSet.

## Done when

- `bao operator raft list-peers` shows exactly `openbao-0`, `openbao-1` and `openbao-2`, all voters, and no other peer.
- The cluster has a leader and accepts a write.
- The autopilot configuration has `cleanup_dead_servers` `true` and `min_quorum` `3`.
- The secret `secret/platform/marker` still exists.
