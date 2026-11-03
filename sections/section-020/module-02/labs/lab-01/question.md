# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Auto-unseal

## Scenario

The OpenBao cluster in the namespace `openbao` unseals itself with the Transit key `autounseal` on the unsealer in the namespace `unsealer`. The key has never been rotated. Your security team requires a new key version every quarter, and this quarter's rotation is yours.

What you have:

- The unsealer's root token in the Secret `unsealer-init` (namespace `unsealer`). The Transit key `autounseal` is at `transit/keys/autounseal`.
- The cluster's lab-only recovery key and root token in the Secret `openbao-init`.
- A marker secret at `secret/platform/marker` that proves the data was not lost.

## Your task

1. Rotate the Transit key `autounseal` so that it has a second version.
2. Leave the setting `min_decryption_version` of the key at 1, so that the root key, which the key's first version encrypted, can still be decrypted.
3. Prove that the cluster still unseals itself: restart the pods one at a time, standbys first, and check each one.

## Constraints

- Do not initialize the cluster again and do not migrate it to another seal.
- Do not delete, export or configure the key in a way that stops the first version from decrypting.
- Do not delete PersistentVolumeClaims.

## Done when

- The key `autounseal` has a `latest_version` of 2 or higher.
- `min_decryption_version` of the key is still 1.
- The grader can delete a standby pod and it unseals itself.
- The secret `secret/platform/marker` still exists.
