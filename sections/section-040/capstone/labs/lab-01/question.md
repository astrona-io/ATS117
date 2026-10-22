# Question

Solve this question on: `terminal`

**Time:** about 40 minutes · **Topic:** Upgrades

## Scenario

The OpenBao cluster in the namespace `openbao` runs OpenBao 2.7.0. A patch release, 2.7.1, is out, and the security team wants the cluster on it today. The cluster serves production traffic, so it must keep its quorum during the upgrade, and the team wants a way back if the new version misbehaves.

The Helm release is `openbao` (chart `openbao` 0.30.4); the image tag is set with `server.image.tag`. The cluster uses the Shamir seal; the lab-only key share and root token are in the Secret `openbao-init`.

## Your task

1. Before anything changes, save a Raft snapshot of the cluster and keep it in the ConfigMap `pre-upgrade-snapshot` in the namespace `openbao`, under the key `pre-upgrade.snap`.
2. Upgrade every pod to OpenBao 2.7.1 with a rolling restart that never takes down more than one pod at a time.

## Constraints

- Do not initialize the cluster again and do not delete PersistentVolumeClaims.
- Do not change the chart version.
- The snapshot must exist before the first pod runs 2.7.1.

## Done when

- Every pod runs the image tag `2.7.1` and reports version 2.7.1.
- The ConfigMap `pre-upgrade-snapshot` holds a snapshot under `pre-upgrade.snap`, created before any pod started on 2.7.1.
- The cluster has three voters, a leader, and every pod is unsealed.
- The secret `secret/platform/marker` still exists.
