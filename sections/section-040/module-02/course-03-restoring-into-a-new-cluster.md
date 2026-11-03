# Restoring Into A New Cluster

The first module restored a snapshot into the running cluster. A real disaster is different: the cluster is gone, and you build a new one. This part walks through that restore, which keys it needs, and the checks that show it worked.

## What you need before you start

A disaster restore needs three things that you kept apart in advance:

- The latest snapshot, from storage outside the cluster.
- What unseals the old cluster's data: the Shamir key shares, or access to the key service that holds the auto-unseal key.
- A way to build a new cluster of the same version, or a newer one that supports the data.

The root key of the old cluster is inside the snapshot, wrapped by the old seal. The new cluster must use the old seal's key material, or it cannot read what it restored. Everything else about the new cluster, such as its name and addresses, can be different.

## The steps

For a cluster that uses the Shamir seal, the order is:

1. **Install a new cluster** from the same Helm chart and values, in a new namespace if the old one still exists.
2. **Initialize the new cluster** with `bao operator init` and unseal `openbao-0` with the new keys. A new cluster must be initialized before it accepts a restore.
3. **Log in with the new root token** and restore with `-force`:

```sh
bao operator raft snapshot restore -force /tmp/disaster.snap
```

`-force` is needed because the snapshot comes from a cluster with a different identity. Without it, the restore refuses the file.

4. **Unseal with the old keys.** After the restore, the data is the old cluster's, so the key that protects it is the old cluster's key. Unseal the nodes with the key shares of the old cluster, not the new ones.
5. **Join and unseal the other nodes** with the old keys, and wait for three voters.

With auto-unseal, step 4 is different: the restored root key is wrapped by the old Transit or KMS key, so the new cluster's seal configuration must point at the same key. A new key service with a new key cannot unwrap it.

## What the restore replaces

The restore replaces everything in storage. Tokens, leases, policies, auth methods and secrets all return to the moment of the snapshot. A client that held a token created after the snapshot now has an invalid token. Applications that use dynamic secrets must request new leases. Plan this in the runbook: the restore is not invisible to clients.

## Prove the restore worked

Run the same short list every time:

1. `bao status` on every node shows `Sealed false`.
2. `bao operator raft list-peers` shows three voters and a leader.
3. A secret you know existed at the time of the snapshot reads back with the right value. The marker secret exists for this purpose.
4. The audit device is enabled again, if you use one. Audit devices are part of the restored data, but check that they can write in the new environment.
5. The applications can log in and read, with the new address if it changed.

You now know what a disaster restore needs, the order of its steps and the checks that prove it. The next part covers the other planned change that needs a snapshot: an upgrade.

## Common pitfalls

> [!WARNING]
> - **Restoring without the old seal's key material.** The data is there and cannot be read.
> - **Using the new cluster's key shares after the restore.** The restored data needs the old cluster's keys.
> - **Restoring into a cluster of an older version.** The data may use a format the older version cannot read.
> - **Skipping the checks.** A restore that finished without an error can still be a restore of the wrong file.
