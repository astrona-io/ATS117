# Storage Settings And Disk Care

Integrated Storage keeps all data on the local volume of every node. If a volume fills up, the node stops accepting writes, and the cluster can stop with it. This part looks at the settings in the `storage "raft"` block and at how to watch and grow the disk before it becomes a problem.

## The storage block

Read the block that the playground uses:

<!-- astrona:playground:renew -->

```sh
kubectl -n openbao get configmap openbao-config -o jsonpath='{.data.extraconfig-from-values\.hcl}'
```

The settings you meet in a production block are these:

| Setting | What it does |
| --- | --- |
| `path` | The folder on the volume where the node keeps its Raft data. In the chart it is `/openbao/data` |
| `node_id` | The name of the node in the Raft configuration. The chart sets it to the pod name when `setNodeId` is true. It must be unique and must never change |
| `retry_join` | The addresses a new node tries to find the cluster. Several blocks can be given |
| `performance_multiplier` | Scales the Raft timeouts; lower detects failures sooner |
| `max_entry_size` | The largest entry Raft accepts, in bytes |

The `node_id` is the setting that causes the most trouble. Raft recognizes a server by its ID. If a node starts with a new ID but old data, or two nodes share an ID, the configuration becomes inconsistent. Pod names in a StatefulSet are stable, which is why the chart uses them.

## Watching the disk

Every write grows the data. Deleted data and old versions of a secret shrink it only after OpenBao and Raft compact it. Check the size of the data folder and the free space of the volume on one pod:

```sh
kubectl -n openbao exec openbao-0 -- du -sh /openbao/data
kubectl -n openbao exec openbao-0 -- df -h /openbao/data
```

The first command prints the size of the Raft data. The second prints the size of the volume and its free space. Alert at about 70 percent used, because a volume that is 100 percent full cannot be repaired by deleting secrets: every delete is itself a write.

The metrics from the telemetry stanza also report on storage. A rising `vault_raft_apply` count with growing latency suggests slow disks, and the volumes of all nodes should be checked together because Raft writes the same data on every node.

## Growing a volume

Each pod has its own PersistentVolumeClaim, named `data-openbao-0`, `data-openbao-1` and so on. If the StorageClass allows volume expansion, raise the requested size of the claim. Do it one claim at a time and check `list-peers` between steps:

```sh
kubectl get storageclass
kubectl -n openbao get pvc
```

The column `ALLOWVOLUMEEXPANSION` in the first command says whether the class allows it. If it does not, the safe way is to add a new node with a larger volume, wait until it votes, remove an old node with `remove-peer`, and repeat. This is the same procedure as replacing a node, and it needs no downtime.

You now know the storage settings that matter, how to measure the disk, and two ways to give a node more space. The last part of this module collects what you have learned.

## Common pitfalls

> [!WARNING]
> - **Changing `node_id` of an existing node.** Raft treats it as a different server.
> - **Waiting for a full disk.** A full volume blocks deletes too.
> - **Watching one node's disk.** Every node stores the same data; check all of them.
> - **Resizing all claims at the same time.** Do one node, check `list-peers`, then the next.
