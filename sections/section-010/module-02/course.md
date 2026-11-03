# Grow, Shrink And Maintain A Raft Cluster

A cluster that never changes is easy. A real one changes: a machine is replaced, a volume fills up, a team wants five voters instead of three. Every change touches the Raft configuration, and a change made in the wrong order can leave a cluster that looks fine and has lost its failure tolerance.

Keep one sentence in mind: **the Raft configuration, not the list of running pods, decides the quorum.** Each part of this module changes one thing about the cluster and shows what happens to that configuration.

The module has four parts. **Addresses, Request Forwarding And The Cluster Port** explains the two addresses of a node and how standbys forward requests. **Adding A Node To A Running Cluster** scales the cluster to four pods and follows the new node until it votes. **Removing And Replacing Nodes** retires a node in the right order; a graded lab follows it. **Storage Settings And Disk Care** covers the `storage "raft"` block and the volumes under it.

## Learning objectives

After this module you can:

- Explain `api_addr`, `cluster_addr`, request forwarding and the cluster port `8201`.
- Add a node to a running cluster and follow it until autopilot makes it a voter.
- Explain why an even number of voters adds no failure tolerance.
- Remove a node in the correct order: `remove-peer`, scale down, delete the volume.
- Replace a node whose volume is lost.
- Measure and grow the volumes of a Raft cluster.

## Before you start

You need to know what a Raft cluster is, what voters and the quorum are, and how to read `bao operator raft list-peers`. You need Kubernetes basics: StatefulSets, PersistentVolumeClaims and `kubectl exec`, and you need to know how to run `helm upgrade`.

Your playground is a single-node `kind` cluster with **OpenBao v2.7.1** in the namespace **`openbao`**: three pods, `openbao-0` to `openbao-2`, on the Shamir seal with one lab-only key share in the Secret `openbao-init`. All three pods are unsealed and the cluster is healthy when the playground starts.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
