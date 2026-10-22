# Unseal OpenBao Automatically

Delete one pod of the cluster in your playground and it comes back sealed. Until someone enters the key share, it serves nothing. In a real cluster with three key holders, that means paging people at night because Kubernetes moved a pod.

Auto-unseal hands that job to a key service. At start, OpenBao sends its encrypted root key to the service, gets it back decrypted, and unseals itself. Keep one sentence in mind: **with auto-unseal, OpenBao is only as available as its key service, and the key shares become recovery keys that can no longer unseal.**

The module has three parts. **Seals, Auto-Unseal And Recovery Keys** explains what a seal protects, which seals OpenBao 2.7 has built in, and why the cloud seals are now plugins. **The Transit Seal** looks at the unsealer in your playground: its Transit key, the policy and the token the cluster will use. **Migrating From Shamir To Transit** walks through the documented migration on the running cluster; a graded lab follows it.

## Learning objectives

After this module you can:

- Explain what the seal protects and how auto-unseal changes the unseal step.
- Tell unseal keys from recovery keys and say what each can do.
- Name the built-in seals of OpenBao 2.7 and configure a cloud seal as a KMS plugin.
- Configure the Transit seal with a least-privilege, orphan, periodic token from a Kubernetes Secret.
- Migrate a running cluster from Shamir to Transit with `bao operator unseal -migrate`.
- Find why a pod cannot auto-unseal.

## Before you start

You need to know how a three-node OpenBao cluster on Integrated Storage behaves: one leader, standbys, quorum, and that the StatefulSet uses the `OnDelete` update strategy, so a pod takes new configuration only when you delete it. You need `helm upgrade` and `kubectl exec`.

Your playground has two OpenBao installations:

| Installation | What it is |
| --- | --- |
| Cluster `openbao` (namespace `openbao`) | Pods `openbao-0` to `openbao-2` on Raft, Shamir seal with one lab-only key share. Key and root token in the Secret `openbao-init` |
| Unsealer `unsealer` (namespace `unsealer`) | One pod, `unsealer-0`. Transit engine at `transit/` with the key `autounseal`, the policy `autounseal`. It unseals itself with the static seal. Its root token is in the Secret `unsealer-init` |

The Secret `transit-seal-token` in the namespace `openbao` holds a token for the cluster's future Transit seal. Real installations keep none of these keys or tokens in Kubernetes Secrets; the lab does so that you can work freely.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
