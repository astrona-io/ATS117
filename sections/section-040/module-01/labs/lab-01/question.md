# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Snapshots and restore

## Scenario

Overnight, a clean-up script deleted the secret `secret/payments/db`, with all its versions, from the OpenBao cluster in the namespace `openbao`. The payments service can no longer reach its database.

The nightly backup job ran before the clean-up. Its Raft snapshot is stored in the ConfigMap `nightly-snapshot` in the namespace `openbao`, under the key `nightly.snap`. After the snapshot, but before you were called, the API team wrote a new secret, `secret/payments/api`, that their service now uses.

The lab-only key share and root token are in the Secret `openbao-init`.

## Your task

1. Bring back `secret/payments/db` with the value it had in the nightly snapshot.
2. Make sure `secret/payments/api` still exists afterwards, with the value it has now.

## Constraints

- Do not initialize the cluster again and do not delete PersistentVolumeClaims.
- Do not type the value of `secret/payments/db` in by hand: it must come from the snapshot.

## Done when

- `secret/payments/db` holds its value from the snapshot.
- `secret/payments/api` exists with the value it had before you started.
- The cluster has three voters, a leader, and every pod is unsealed.
- The secret `secret/platform/marker` still exists.
