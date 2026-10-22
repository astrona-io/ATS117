# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Auto-unseal

## Scenario

The three-node OpenBao cluster in the namespace `openbao` uses the Shamir seal. Every pod restart pages someone at night to enter a key share. The security team has set up a second OpenBao server, the unsealer, in the namespace `unsealer`. It has a Transit key for the cluster and a token for it. Your job is to move the cluster to Transit auto-unseal.

What exists already:

- On the unsealer: the Transit engine at `transit/`, the key `autounseal`, and the policy `autounseal`.
- In the namespace `openbao`: the Secret `transit-seal-token` (key `token`) with an orphan, periodic token for the seal, and the Secret `openbao-init` with the lab-only Shamir key share (`unseal-key`) and root token (`root-token`).
- The Helm release `openbao` (chart `openbao` 0.30.4). The unsealer's address inside the cluster is `http://unsealer.unsealer.svc.cluster.local:8200`.

## Your task

Migrate the cluster from the Shamir seal to the Transit seal with the key `autounseal` at the mount path `transit/`. Pass the seal token to the pods as the environment variable `BAO_TOKEN` from the Secret `transit-seal-token`. Follow the documented seal migration order, so the cluster keeps its data.

## Constraints

- Do not initialize the cluster again and do not delete PersistentVolumeClaims.
- Do not write the token into the Helm values or the configuration.
- Do not create a new token for the seal; use the one in `transit-seal-token`.

## Done when

- Every pod reports the seal type `transit` and is unsealed.
- The cluster reports a recovery seal: the Shamir key share became the recovery key.
- The grader can delete a standby pod and it unseals itself without anyone entering a key.
- The secret `secret/platform/marker` still exists.
