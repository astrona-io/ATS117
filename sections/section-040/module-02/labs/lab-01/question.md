# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Backup

## Scenario

The OpenBao cluster in the namespace `openbao` has three pods on Integrated Storage and the Shamir seal. The team wants a nightly job to take Raft snapshots. Until now an engineer took them by hand with the root token. The security team will not allow the root token in a job.

What you have:

- The cluster's lab-only unseal key and root token in the Secret `openbao-init` (namespace `openbao`).
- A `tester` pod in the namespace `clients` with `curl` and `jq`. The Service `openbao-active` in the namespace `openbao` reaches the active node on port 8200.
- A marker secret at `secret/platform/marker`.

## Your task

1. Create a policy named `snapshot-backup` that allows taking a snapshot and nothing else.
2. Create a token with that policy that fits an unattended job: it must not depend on the token that created it, and it must not have a fixed maximum lifetime.
3. Store the token in a Secret named `snapshot-backup-token`, with the key `token`, in the namespace `openbao`.
4. Check from the `tester` pod that the token can take a snapshot, cannot read a secret and cannot restore.

## Constraints

- Do not initialize the cluster again and do not delete PersistentVolumeClaims.
- The token must not carry the `root` policy.
- Do not give the policy capabilities beyond what a snapshot needs.

## Done when

- The Secret `snapshot-backup-token` holds a valid token that is an orphan, is periodic, and carries the policy `snapshot-backup` but not `root`.
- A `GET` on `/v1/sys/storage/raft/snapshot` with the token answers `200`.
- A `GET` on `/v1/secret/data/platform/marker` and a `POST` on `/v1/sys/storage/raft/snapshot` with the token answer `403`.
- The secret `secret/platform/marker` still exists.
