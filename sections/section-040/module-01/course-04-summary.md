# Summary

High availability protects OpenBao against lost nodes. This module covered the protection against lost data and the safe way to change versions.

## What you learned

A Raft snapshot is a point-in-time copy of all data in Integrated Storage, saved by the leader with `bao operator raft snapshot save` or a `GET` on `sys/storage/raft/snapshot`. The file stays encrypted with the cluster's keyring. To use it you need what unseals the cluster that made it: the Shamir key shares, or the same key in the same key service. A snapshot belongs outside the cluster, kept apart from those keys.

Restoring a snapshot replaces the whole cluster's data with the data of that moment. When the keys match, the cluster stays unsealed. Everything written since the snapshot is rolled back, including tokens, leases and policies, so changes that must survive are read before the restore and written again afterwards. `-force` skips the key check and belongs to disaster recovery into a different cluster only.

The Helm chart's `OnDelete` strategy means a template change reaches a pod only when you delete it. An upgrade takes a snapshot first, then restarts the standbys one at a time, steps the leader down and restarts it last, checking for three voters after each pod. With auto-unseal the pods unseal themselves, but the order stays the same. The key facts to remember are these:

- Raft replicates a deletion as fast as any write; snapshots are the protection against mistakes.
- A snapshot without the matching keys cannot be used.
- A restore rolls back everything after the snapshot, not only what you lost.
- Snapshot first, standbys next, leader last.

<!-- astrona:playground:destroy -->
