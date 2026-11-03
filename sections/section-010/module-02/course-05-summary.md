# Summary

This module covered how a Raft cluster is addressed, how it grows and shrinks, and how its storage is kept healthy.

## What you learned

Every node advertises an API address for clients on port `8200` and a cluster address for other nodes on port `8201`. A standby forwards writes to the active node over the cluster port with mutual TLS, and it can instead answer with a `307` redirect to the active node's API address. Blocking the cluster port breaks forwarding and replication even when the API port answers.

A new node joins when its pod runs, it is unsealed with the Shamir key, and autopilot promotes it to voter after the stabilization time. Four voters tolerate one failure, the same as three, so clusters run an odd number of voters. To retire a node, remove it from the Raft configuration first, then scale the StatefulSet down, then delete its volume. A node whose volume was lost is removed and started empty.

The `node_id` identifies a server in Raft and must be unique and stable. Disks fill with every write, and a full disk blocks even deletes, so measure the volume of every node and grow it before it is full. The key facts to remember are these:

- Run `remove-peer` before you scale a StatefulSet down.
- An even number of voters adds cost and no tolerance.
- A removed node must start with an empty volume.
- Port `8201` must be open between all nodes.

<!-- astrona:playground:destroy -->
