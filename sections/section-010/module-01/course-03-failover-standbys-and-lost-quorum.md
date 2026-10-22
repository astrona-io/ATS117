# Failover, Standbys And Lost Quorum

A cluster exists for the moment a node fails. This part makes that moment happen: you delete the leader and watch the others elect a new one. Then it looks at what the standbys do with requests while they wait, and at the worse case, a cluster that has lost its quorum.

## Losing the leader

Set up the helper and the token on this page, so the commands work in a new terminal too:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
```

Note which pod is the leader. Now delete it. Replace `openbao-0` below with the leader's name if it is a different pod:

```sh
kubectl -n openbao delete pod openbao-0 --wait=false
sleep 20
bao_on openbao-1 operator raft list-peers
```

One of the two remaining pods is now the leader. The followers noticed that the leader stopped sending heartbeats, one of them asked for votes, and two of three voters agreed. Two voters are still a quorum, so the new leader can commit writes. Prove it:

```sh
bao_on openbao-1 kv put secret/platform/failover-check at="$(date)"
```

The write succeeds. The deleted pod comes back sealed, because the cluster uses the Shamir seal; unseal it and it rejoins as a follower:

```sh
bao_on openbao-0 operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
```

During those 20 seconds the Service `openbao-active` had no pod behind it, or the wrong one, until the chart's Kubernetes service registration moved its label to the new leader. Your port-forward from the machine also broke, because it was bound to the old pod. Start it again after every leader change.

A planned leader change is gentler. `bao operator step-down` asks the active node to give up leadership, and the others elect a new leader without any pod restarting. You use it before restarting the active node for an upgrade or a configuration change.

## What standbys do with requests

A client does not always reach the leader. Requests through the Service `openbao` can land on any pod. A standby handles them in two ways:

- **Request forwarding.** A request that writes is forwarded by the standby to the active node over the cluster port `8201`. The client gets the active node's response. This is on by default.
- **Standby reads.** Since OpenBao v2.5.0, a standby on Integrated Storage answers requests that do not write from its own copy of the data. This is similar to Vault Enterprise's performance standby nodes. It spreads read load across the cluster; turn it off with `disable_standby_reads = true` in the server configuration.

A standby's copy can be a moment behind the leader. A client that writes and immediately reads through a different pod may not see its own write yet. OpenBao's consistency features handle this for clients that need it; the simple rule is that writes always go through the active node.

## When quorum is lost

Delete two of three pods, or let two restart and stay sealed, and the cluster has one voter of three. That is not a quorum. No node can become leader, every write fails, and `list-peers` on the survivor reports no leader.

The fix depends on whether the lost nodes can come back. If they can, bring them back: start the pods and, with the Shamir seal, unseal them. As soon as enough voters are back to form a quorum, they elect a leader and the cluster works again, with no data lost. This is always the first choice.

If the lost nodes are gone for good, a quorum can never form again from the configuration as it is. Integrated Storage then supports a manual recovery: you stop the surviving nodes, write a file called `peers.json` into each node's Raft folder that lists only the surviving servers, and start them again. They form a new, smaller configuration and elect a leader. Writes that were not yet committed when the nodes were lost may be lost or committed by the recovery. It is a last resort for disasters, not a routine step.

A dead peer that stays in the configuration is the quiet version of this problem. If you scale the StatefulSet from four pods to three without removing the fourth node from Raft, the configuration still has four voters and needs three of them for a quorum. Remove such a node yourself:

```sh
bao_on openbao-0 operator raft remove-peer <NODE_ID>
```

Replace `<NODE_ID>` with the node ID that `list-peers` shows for the dead node. Or let autopilot do it, with `-cleanup-dead-servers` and a `-min-quorum`.

You now know what failover looks like from inside the cluster, how standbys forward writes and answer reads, and the order of steps when the quorum is gone: bring voters back first, remove dead peers, and use `peers.json` only when nothing else is left.

## Common pitfalls

> [!WARNING]
> - **Keeping an old port-forward.** It follows one pod. After a leader change, stop it and start it again.
> - **Restarting the active node without stepping down.** Clients see errors until an election finishes. Run `bao operator step-down` first.
> - **Reaching for `peers.json` first.** If the lost nodes can come back, bringing them back recovers everything without risk.
> - **Scaling the StatefulSet down without `remove-peer`.** The removed node stays a voter and lowers the number of failures the cluster survives.
