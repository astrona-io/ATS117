# Summary

This module covered the day-to-day operation of the seal: the Transit key, the seal token, the recovery keys, the static seal, the KMS plugins and the migration between seals.

## What you learned

The Transit key lives in another OpenBao server and has numbered versions. Rotating it adds a version and leaves the old ones decryptable, which the stored root key still needs. Raising `min_decryption_version` too early stops a restarted pod from unsealing. A restart of one pod is the proof that the seal still works.

The pods authenticate to the key service with an orphan, periodic token that has a narrow policy. A revoked or expired token breaks the next restart, not the running pods. With auto-unseal, the key shares from `init` are recovery keys: they cannot unseal, and they authorize generating a root token, rekeying and migrations.

The static seal reads a 32-byte key from the environment or a file and rotates with `current_key` and `previous_key`; it is as safe as the place the key comes from. Cloud seals are plugins declared with a `plugin "kms"` block and a `seal` block of the same name, and authorize through the identity of the workload. A migration changes how the root key is protected and follows the same order every time. The key facts to remember are these:

- Rotate the Transit key, but leave `min_decryption_version` alone until nothing needs old versions.
- Test the seal by restarting a standby, not by reading a running pod.
- Never give the seal token the `root` policy.
- Mark the old seal `disabled = "true"` during an auto-unseal migration.

<!-- astrona:playground:destroy -->
