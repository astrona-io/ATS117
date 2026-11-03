# Section 040: Snapshots, Backup And Upgrades

Three nodes protect OpenBao against a failed node, not against a mistake. When someone deletes a secret, Raft copies the deletion to every node in milliseconds. And an upgrade that goes wrong on every pod at once takes the whole cluster with it.

This section covers the two routine operations that protect the data over time. Raft snapshots are point-in-time copies of everything in Integrated Storage; you will save one, see what it needs to be usable, and restore it, including what a restore takes away. Rolling upgrades move a cluster to a new OpenBao version one pod at a time, so it never loses quorum.

## What you will learn

- Saving a Raft snapshot with `bao operator raft snapshot save`, and what else you need to restore it.
- Restoring a snapshot into a running cluster, what the restore rolls back, and when `-force` applies.
- Upgrading with the Helm chart and the `OnDelete` strategy: snapshot first, standbys next, leader last.
- The snapshot API, checking a snapshot file, least-privilege backup tokens, scheduled snapshots, restoring into a new cluster, upgrade planning, drills and runbooks.

## The learning path

The module starts at its landing page, which also launches the playground: a three-node cluster on the Shamir seal with example data.

### 1. Back Up, Restore And Upgrade OpenBao

1. Raft Snapshots
2. Restoring A Snapshot, followed by the lab **Restore A Deleted Secret From A Snapshot**
3. Rolling Upgrades
4. The Snapshot API And Checking A File
5. Summary

### 2. Automate Backups And Plan Upgrades

1. A Least-Privilege Backup Token, followed by the lab **Create A Backup Token**
2. Scheduled Snapshots
3. Restoring Into A New Cluster
4. Planning An Upgrade
5. Drills And Runbooks
6. Summary

## Section capstone: Upgrade The Cluster From 2.7.0 To 2.7.1 Safely

A cluster runs OpenBao 2.7.0 and must move to 2.7.1. Take a snapshot first and keep it, then upgrade every pod without the cluster losing quorum or data. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-040/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-117-capstone-040
```
