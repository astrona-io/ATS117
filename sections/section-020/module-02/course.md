# Operate The Seal

An auto-unsealed cluster looks finished once it unseals itself. Then the key rotates, a token expires, a person leaves who held a recovery share, or the team moves to another key service. Each of these touches the seal, and a mistake shows up only at the next restart.

Keep one sentence in mind: **a running pod does not prove the seal works; a restarted pod does.** This module works on the seal of a running cluster and tests every change with a restart.

The module has six parts. **Rotating The Transit Key** adds a version to the key and shows the setting that must stay unchanged; a graded lab follows it. **The Seal Token Lifecycle** covers the token that the pods present to the key service. **Recovery Keys In Practice** generates a root token from the recovery key. **The Static Seal** reads a seal that needs no second server. **KMS Plugin Seals** explains the cloud seals. **Migration Paths And Seal Failures** lists the ways from one seal to another and makes a seal fail on purpose.

## Learning objectives

After this module you can:

- Rotate a Transit key without making the cluster unable to unseal.
- Explain the properties and the policy of the seal token, and test and replace the token.
- Generate a root token with the recovery keys and explain rekeying.
- Configure and rotate a static seal.
- Declare a KMS plugin seal and list the causes of a failed start.
- Choose the right migration path between seals and diagnose a pod that stays sealed.

## Before you start

You need to know what a seal is, what auto-unseal changes, and how a cluster is unsealed with the Transit seal. You need Kubernetes basics and the `bao` CLI.

Your playground is a single-node `kind` cluster with two OpenBao installations. **OpenBao v2.7.1** runs in the namespace **`openbao`** as three pods that unseal themselves with the Transit seal; the recovery key and root token are in the Secret `openbao-init`. A second OpenBao, the **unsealer**, runs in the namespace **`unsealer`** as `unsealer-0`. It serves the Transit key `autounseal` and unseals itself with a static seal. The seal token is in the Secret `transit-seal-token`, and the unsealer's root token is in the Secret `unsealer-init`. These Secrets are for the lab only; a real installation never keeps them in Kubernetes Secrets.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
