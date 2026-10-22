# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** High availability with Integrated Storage

## Scenario

A three-node OpenBao cluster runs in the namespace `openbao`. The team believes it survives the loss of one node. A colleague checked `kubectl get pods`, saw three pods running, and closed the ticket.

The Raft configuration tells a different story: only two nodes are in it. If either of them fails now, the cluster loses its quorum.

## Your task

In the namespace `openbao`:

1. Find out which pod is not part of the Raft cluster, and why.
2. Make it a voter, so that `openbao-0`, `openbao-1` and `openbao-2` are all voters.
3. Configure autopilot so that it removes dead servers, never shrinks the cluster below three voters, and treats a server as dead after 10 minutes without contact.

The lab-only unseal key and root token are in the Secret `openbao-init`.

## Constraints

- Do not initialize the cluster again and do not delete any PersistentVolumeClaim. The data in the cluster must survive.
- Do not change the Helm release or the StatefulSet. Nothing is wrong with them.

## Done when

- `bao operator raft list-peers` shows exactly `openbao-0`, `openbao-1` and `openbao-2`, all voters.
- The autopilot configuration has `cleanup_dead_servers` set to `true` and `min_quorum` set to `3`.
- The grader can delete the leader pod and the two others still elect a leader and accept a write. (The grader unseals the deleted pod again afterwards.)
- The secret `secret/platform/marker` still exists.
