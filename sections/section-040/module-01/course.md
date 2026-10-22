# Back Up, Restore And Upgrade OpenBao

Delete a secret in your playground cluster and ask the other two nodes for it. They do not have it either. Raft did exactly its job: it made the deletion durable on every node. High availability protects against lost nodes, not against lost data.

A Raft snapshot is the protection against lost data. It is a copy of everything in Integrated Storage at one moment, saved to a file. Keep one sentence in mind: **a snapshot is encrypted with the cluster's keys, and restoring it puts the whole cluster back to that moment, not only the part you lost.**

The module has three parts. **Raft Snapshots** saves a snapshot and explains what is in it and what you need to use it. **Restoring A Snapshot** restores one into the running cluster and shows how to keep changes made after it; a graded lab follows it. **Rolling Upgrades** moves a cluster to a new OpenBao version one pod at a time.

## Learning objectives

After this module you can:

- Save a Raft snapshot and store it outside the cluster.
- Explain what a snapshot contains and why it is useless without the seal or keys of the cluster that made it.
- Restore a snapshot into a running cluster, and keep changes made after it.
- Explain when `-force` applies and why it is dangerous.
- Upgrade a cluster with the Helm chart and the `OnDelete` strategy: snapshot first, standbys next, leader last.

## Before you start

You need to know how a three-node OpenBao cluster on Integrated Storage behaves: the leader, standbys, quorum, `bao operator step-down`, and that every restarted pod comes back sealed with the Shamir seal. You need `kubectl exec`, `kubectl create configmap` and `helm upgrade`.

Your playground is a three-node cluster in the namespace `openbao` (pods `openbao-0` to `openbao-2`, Shamir seal, key and root token in the Secret `openbao-init`) with a KV version 2 engine at `secret/` and two secrets: `secret/platform/marker` and `secret/payments/db`. Real installations never keep the key share or root token in a Kubernetes Secret.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
