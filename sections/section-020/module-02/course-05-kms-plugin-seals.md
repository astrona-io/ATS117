# KMS Plugin Seals

Cloud key services protect the key outside your cluster, give you an audit log of every use, and let the cloud account control who may use the key. Since OpenBao v2.7.0 their seals are not part of the server binary any more. They run as external plugins. This part explains how a plugin seal is declared, how it is authorized and what to check when a pod does not unseal.

## Built in or plugin

The server binary contains four seals: `shamir`, `transit`, `static` and `kmip`. The seals for cloud key management services (`awskms`, `gcpckms`, `azurekeyvault`, `ocikms`, `alicloudkms`) and for hardware security modules (`pkcs11`) are plugins of the type `kms`. A plugin is a separate executable that the server starts and talks to. You install it on the server image or on a volume, and you register it in the configuration.

## Declaring a plugin seal

Two blocks work together. The `plugin "kms"` block registers the executable, and the `seal` block configures it. The second label of the `plugin` block and the label of the `seal` block must be the same name:

```hcl
plugin "kms" "awskms" {
  command = "openbao-plugin-kms-awskms"
}

seal "awskms" {
  region     = "eu-west-1"
  kms_key_id = "19ec80b0-dfdd-4d97-8164-c6examplekey"
}
```

The `seal` fields differ by provider, and the plugin's own documentation lists them. Google Cloud KMS uses `project`, `region`, `key_ring` and `crypto_key`. Azure Key Vault uses `tenant_id`, `vault_name` and `key_name`. The pattern is always the same: a place to find the key service and the name of the key in it.

## Authorizing the server

The server proves who it is to the cloud with credentials from the environment, not from the configuration file. On Kubernetes the safest way is the identity of the workload: an IAM role bound to the service account on AWS, workload identity on Google Cloud, or a managed identity on Azure. The key policy in the cloud account then allows that identity to encrypt and decrypt with the key, and to read its metadata. It needs no permission to manage or delete the key.

This separation is the reason to use a KMS: the cloud account decides who can use the key, logs each use, and can disable the key in an emergency. Disabling the key is also its danger. When the key is disabled or scheduled for deletion, every pod that restarts stays sealed, and every snapshot becomes unusable.

## When a plugin seal does not start

Check the causes in this order, because each one is more common than the next:

1. The plugin executable is not at the path in `command`, or it is not executable. The server log names the file.
2. The names in the `plugin` and the `seal` block differ.
3. The pod has no cloud identity, or the identity lacks the permission to use the key. The log shows the error from the cloud service.
4. The key is in another region than the `seal` block says.

Look at the log of a pod that does not unseal:

<!-- astrona:playground:renew -->

```sh
kubectl -n openbao logs openbao-0 --tail=30
```

The playground does not use a KMS plugin, so the log of a healthy pod shows the Transit seal lines instead. A plugin failure appears in the same place, near the start of the log, before the lines about Raft.

Moving a cluster to a KMS plugin follows the same procedure as moving from Shamir to Transit: add the new seal, restart pods in the right order, and migrate with the recovery or unseal keys. The migration paths are the subject of the next part.

You now know how a plugin seal is declared, why its credentials come from the environment, and the order in which to look for a failure. The last part of this module collects the migration paths and the diagnosis of an unseal failure.

## Common pitfalls

> [!WARNING]
> - **Different names in the `plugin` and `seal` blocks.** The server cannot find the plugin for the seal.
> - **Credentials in the configuration file.** Use the workload's identity.
> - **A key policy that allows management but not use.** Encrypt and decrypt must be allowed.
> - **Disabling or deleting the key in the cloud.** It makes the cluster and its snapshots unusable.
