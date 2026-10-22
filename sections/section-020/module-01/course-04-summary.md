# Summary

Auto-unseal takes people out of the unseal step. This module showed what the seal protects, which seals OpenBao offers, how the Transit seal works and how to migrate a running cluster to it.

## What you learned

OpenBao encrypts its data with a keyring, the keyring with the root key, and the root key with the seal. The Shamir seal splits the root key into key shares that people enter after every restart. Auto-unseal lets a key service decrypt the root key at start instead. The shares created at initialization then become recovery keys: they authorize operations such as generating a root token, but they cannot unseal.

OpenBao 2.7 builds in four seals: Shamir, Transit, static and KMIP. Since v2.7.0 the cloud seals, such as AWS KMS, Google Cloud KMS and Azure Key Vault, and PKCS#11 for hardware security modules, are external KMS plugins that need a `plugin "kms"` block. The static seal reads a 32-byte key from an environment variable or a file and is only as safe as the place that key comes from.

The Transit seal uses the Transit engine of a second OpenBao server. It needs a key that is never deleted, a policy limited to `update` on that key's encrypt and decrypt paths, and an orphan, periodic token. The Helm chart passes the token as `BAO_TOKEN` from a Kubernetes Secret, which also makes it the default token inside the pod.

Seal migration follows a fixed order on an Integrated Storage cluster: add the new seal to the configuration, restart each standby and unseal it with `-migrate`, step the active node down so a migrated node performs the migration, then restart the old active node, which auto-unseals. The key facts to remember are these:

- With auto-unseal, OpenBao is only as available as its key service.
- Recovery keys cannot unseal and cannot replace a lost key service.
- The seal token must be orphan and periodic, with only the encrypt and decrypt capabilities it needs.
- Migrate one pod at a time and keep the quorum.

<!-- astrona:playground:destroy -->
