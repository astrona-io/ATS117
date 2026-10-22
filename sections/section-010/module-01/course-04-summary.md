# Summary

Integrated Storage lets several OpenBao nodes keep the same data. This module showed how they agree, how a node joins, and what happens when nodes fail.

## What you learned

Every node keeps a full copy of the data in its Raft folder. The Raft consensus protocol elects one leader, which is also OpenBao's active node; the others are standbys. The leader commits a write only when a quorum, a majority of the voters, has stored it. Three voters have a quorum of two and survive one failure; four voters need three and still survive only one. `bao operator raft list-peers` shows the members and their roles, and `bao operator raft autopilot state` shows their health and the failure tolerance.

A new node finds the cluster through the `retry_join` addresses in its `storage "raft"` block. It must answer an encrypted challenge to join, so a node that uses the Shamir seal joins only after it is unsealed with the cluster's key. Autopilot promotes a healthy node to voter after the stabilization time. It removes dead servers only when `cleanup_dead_servers` is on, and never below `min_quorum`.

When the leader fails, the remaining voters elect a new one as long as they form a quorum, and writes continue. Standbys forward writes to the active node and, since v2.5.0, answer reads from their own copy. When the quorum is lost, nothing can be written: bring the lost voters back first, remove peers that are gone for good, and keep the `peers.json` recovery for disasters. The key facts to remember are these:

- Quorum is `(voters / 2) + 1` of the voters in the Raft configuration, not of the pods that run.
- A Shamir-sealed pod comes back sealed after every restart and must be unsealed before it serves or joins.
- Scaling down without `remove-peer` leaves a dead voter behind.
- Step the active node down before you restart it.

<!-- astrona:playground:destroy -->
