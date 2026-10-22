# Run OpenBao As A Raft Cluster

Three OpenBao pods run in your playground, and all three hold the same data. You can delete one of them, and requests still succeed. You can delete two, and every write fails, even though one pod still runs and still has all the data. This module explains why, and how to keep a cluster on the right side of that line.

Integrated Storage is OpenBao's built-in storage backend. Every node keeps a full copy of the data, and the nodes agree on each change with the Raft consensus protocol. Keep one sentence in mind: **a write is committed only when a majority of the voters has stored it.** That majority is called the quorum, and almost every operational task in this module protects it.

The module has three parts. **Raft, Voters And Quorum** looks at the running cluster and explains leaders, voters and how many failures three nodes survive. **Joining Nodes And Autopilot** shows how a node finds the cluster with `retry_join`, why a sealed node does not join, and how autopilot watches node health; a graded lab follows it. **Failover, Standbys And Lost Quorum** deletes the leader on purpose, shows what standbys do with requests, and explains how to recover when the quorum is gone.

## Learning objectives

After this module you can:

- Explain the roles of leader, follower, voter and non-voter in Integrated Storage.
- Calculate the quorum of a cluster and how many node failures it survives.
- Read `bao operator raft list-peers` and `bao operator raft autopilot state`.
- Explain how `retry_join` works and why a Shamir-sealed node joins only after it is unsealed.
- Configure autopilot to clean up dead servers with a minimum quorum.
- Describe what happens when the leader fails and how standbys handle reads and writes.
- Recover a cluster that lost quorum by bringing voters back, and remove a dead peer.

## Before you start

You need Kubernetes basics: StatefulSets, pods, Services, Secrets and `kubectl exec`. You need to know the `bao` CLI: `BAO_ADDR`, `BAO_TOKEN`, `bao status` and `bao kv`. You also need to know that a sealed OpenBao server cannot decrypt its data, and that the Shamir seal needs key shares to unseal.

Your playground is a single-node `kind` cluster with **OpenBao v2.7.1** installed by the `openbao` Helm chart in the namespace **`openbao`**:

| Object | What it is |
| --- | --- |
| StatefulSet `openbao` | Three pods, `openbao-0`, `openbao-1` and `openbao-2`, each with its own 1 GiB volume for Raft data |
| Service `openbao-active` | Selects the pod that is the leader at the moment |
| Service `openbao-internal` | A headless Service that gives each pod a stable DNS name, such as `openbao-0.openbao-internal` |
| Secret `openbao-init` | The lab-only key share (`unseal-key`) and root token (`root-token`) |

The cluster uses the Shamir seal with one key share. That is for the lab only: a real cluster splits the key into several shares held by different people, and never keeps them in a Kubernetes Secret. All three pods are unsealed and the cluster is healthy when the playground starts.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
