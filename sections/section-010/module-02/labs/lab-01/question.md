# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** High availability with Integrated Storage

## Scenario

The `openbao` cluster once had four pods. A colleague scaled the StatefulSet back to three with `helm upgrade` and closed the ticket. Three pods run and every request works, but nobody told Raft that the fourth node is gone.

## Your task

In the namespace `openbao`:

1. Find out which node is in the Raft configuration but no longer runs.
2. Remove it from the Raft configuration, so only `openbao-0`, `openbao-1` and `openbao-2` remain, all voters.
3. Remove the PersistentVolumeClaim the retired node left behind.
4. Make sure autopilot reports a healthy cluster with a failure tolerance of 1.

The lab-only unseal key and root token are in the Secret `openbao-init`.

## Constraints

- Do not initialize the cluster again. The data in the cluster must survive.
- Do not delete the claims of `openbao-0`, `openbao-1` or `openbao-2`.
- Do not change the Helm release. It already runs three replicas.

## Done when

- `bao operator raft list-peers` shows exactly `openbao-0`, `openbao-1` and `openbao-2`, all voters.
- `bao operator raft autopilot state` reports `Healthy` as `true` and `Failure Tolerance` as `1`.
- The PersistentVolumeClaim `data-openbao-3` no longer exists.
- The secret `secret/platform/marker` still exists.
