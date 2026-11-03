# Adding A Node To A Running Cluster

Clusters grow: more resilience, a replaced machine, a move to five voters. Adding a node is simple, but each step has a reason, and skipping one leaves a pod that runs without being part of the cluster. This part adds a fourth pod to the playground and follows it until it votes.

## Scaling the StatefulSet

The playground has three pods. A StatefulSet creates pods from a template, and the Helm chart sets the number of replicas. Raise it to four, keeping all other values the cluster already has:

<!-- astrona:playground:renew -->

```sh
helm upgrade openbao openbao/openbao --version 0.30.4 -n openbao --reuse-values --set server.ha.replicas=4
kubectl -n openbao get pods -w
```

Press Ctrl-C when `openbao-3` shows `Running`. The StatefulSet creates the pod and its own 1 GiB volume. Scaling up does not restart the other pods; the `OnDelete` strategy only affects pods when the template changes. Because the template did not change in a way that matters here, the three running pods stay as they are.

## Joining and unsealing

The new pod starts with an empty volume. Its `storage "raft"` block lists the three `retry_join` addresses, and it needs only one of them to answer. It does not matter that `openbao-3` is not in the list: the list names places to look for the cluster, not the members.

With the Shamir seal, the pod is sealed at start and joins only after it is unsealed. Set up the helper and unseal it:

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-3 operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
```

If the answer says that the node is not initialized, the pod has not reached the leader yet. Wait a few seconds and run the command again. Then check the Raft configuration:

```sh
sleep 20
bao_on openbao-0 operator raft list-peers
```

`openbao-3` appears as a follower and, after the stabilization time of 10 seconds, as a voter. A node without `retry_join` joins by hand with `bao operator raft join <leader API address>` run on the new node.

## Why four voters are not better than three

Look at the failure tolerance now:

```sh
bao_on openbao-0 operator raft autopilot state
```

Four voters have a quorum of three, so the cluster still survives only one failure. The fourth voter adds a copy of the data, but not more tolerance. A fifth voter would raise the quorum to three of five and the tolerance to two.

| Voters | Quorum | Failures survived |
| --- | --- | --- |
| 3 | 2 | 1 |
| 4 | 3 | 1 |
| 5 | 3 | 2 |
| 6 | 4 | 2 |
| 7 | 4 | 3 |

This is why clusters run an odd number of voters: an even number adds cost and a larger quorum without more tolerance. A cluster of four is acceptable for a short time while you replace a node, but not as a target.

You now know how to add a node: raise the replicas, unseal the pod, and wait for autopilot to promote it. The reverse is more dangerous, because a node that leaves must also leave the Raft configuration.

## Common pitfalls

> [!WARNING]
> - **Forgetting to unseal the new pod.** With the Shamir seal it never joins, and `list-peers` does not show it.
> - **Running `bao operator init` on the new pod.** It would start a separate cluster. A new node joins; it is never initialized.
> - **Using `helm upgrade` without `--reuse-values`.** The chart falls back to its defaults and drops your configuration.
> - **Stopping at four voters.** Four tolerate one failure, the same as three.
