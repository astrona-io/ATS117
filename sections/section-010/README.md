# Section 010: High Availability With Integrated Storage

A single OpenBao server is a single point of failure. When it stops, every application that needs a secret stops with it. Integrated Storage lets you run several OpenBao nodes that keep the same data, so one node can fail and the cluster keeps serving requests.

This section is about running and keeping such a cluster. Integrated Storage uses the Raft consensus protocol: the nodes elect a leader, the leader accepts every write, and a write counts only when a majority of the voting nodes, the quorum, has stored it. You will join nodes, read the cluster's own view of itself, lose a node on purpose, and bring back a cluster that lost its quorum.

## What you will learn

- How Raft, the leader, voters and quorum work, and how many failures three nodes survive.
- How `retry_join` lets a node find the cluster, and why a Shamir-sealed node joins only after it is unsealed.
- Reading `bao operator raft list-peers` and `bao operator raft autopilot state`.
- Configuring autopilot to remove dead servers while keeping a minimum quorum.
- What happens when the leader fails, how standbys forward writes and answer reads, and what to do when quorum is lost.

## The learning path

The module starts at its landing page, which also launches the playground: a three-node cluster that is already unsealed.

### 1. Run OpenBao As A Raft Cluster

1. Raft, Voters And Quorum
2. Joining Nodes And Autopilot, followed by the lab **Join The Third Node And Configure Autopilot**
3. Failover, Standbys And Lost Quorum
4. Summary

## Section capstone: Restore Quorum And Remove A Dead Peer

A fourth node was added and later removed by scaling the StatefulSet down, without telling Raft. Then two nodes restarted. Now only one voter of four is alive, the cluster has no leader, and nothing can be written. Bring the quorum back, remove the dead peer, and make sure it cannot happen again silently. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-117-capstone-010
```
