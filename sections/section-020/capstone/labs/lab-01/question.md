# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Auto-unseal

## Scenario

The OpenBao cluster in the namespace `openbao` has used Transit auto-unseal against the unsealer in the namespace `unsealer` for months. This morning `openbao-2` restarted and stayed sealed. `openbao-0` and `openbao-1` still run, but the team is afraid to restart them.

Two things changed last week. Someone cleaned up "unused" tokens on the unsealer. And someone "tidied" the Helm values of the release `openbao`.

What you have:

- The unsealer's root token in the Secret `unsealer-init` (namespace `unsealer`); the Transit key `autounseal` and the policy `autounseal` exist there.
- The seal token in the Secret `transit-seal-token` (namespace `openbao`, key `token`), which the pods read as `BAO_TOKEN`.
- The cluster's lab-only recovery key and root token in the Secret `openbao-init`.

## Your task

1. Find out why `openbao-2` cannot unseal. There is more than one reason.
2. Fix the seal so that every pod of the cluster can unseal itself after a restart.
3. Make sure every pod runs with the fixed setup, without losing quorum.

## Constraints

- Do not initialize the cluster again, do not migrate it back to Shamir, and do not delete PersistentVolumeClaims.
- The seal token must be an orphan, periodic token with only the `autounseal` policy. A root token or a child token is wrong.
- The Transit key `autounseal` must not be changed, rotated away or deleted.

## Done when

- Every pod is unsealed and uses the seal type `transit`.
- The token in `transit-seal-token` is valid at the unsealer, orphan, periodic, and carries the `autounseal` policy but not `root`.
- The Helm values name the Transit key `autounseal`.
- The grader can delete a standby pod and it unseals itself.
- The secret `secret/platform/marker` still exists.
