# Raft And Lease Metrics

The first metrics module picked seal and leader gauges. Production monitoring needs a few more: the health of the Raft cluster, the number of leases, and the failures of the audit devices. This part reads them and shows what each one answers. The metric names keep the `vault_` prefix.

## Reading a metric by hand

Prometheus scrapes the same endpoint you can call yourself. Fetch the metrics from one node and filter for a name:

<!-- astrona:playground:renew -->

```sh
kubectl -n clients exec -i deploy/tester -- curl -s "http://openbao-0.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/metrics?format=prometheus" | grep -E '^vault_(autopilot|expire_num_leases|core_active|raft_peers)'
```

If the endpoint answers with a permission error, the listener is not set to unauthenticated metrics access; the playground sets it. Which metrics appear depends on the node: a standby does not report every metric of the leader.

## Cluster health

| Metric | Type | Answers |
| --- | --- | --- |
| `vault_core_active` | gauge | Is this node the active node? Summed over all nodes, it should be 1 |
| `vault_core_unsealed` | gauge | Is this node unsealed? |
| `vault_autopilot_healthy` | gauge | Does autopilot report the cluster as healthy? (1 or 0) |
| `vault_autopilot_failure_tolerance` | gauge | How many voters can fail before the quorum is lost? |
| `vault_raft_leader_lastContact` | summary | How long ago did the leader last hear from its followers? |
| `vault_raft_commitTime` | summary | How long does a log entry take to commit? |

The autopilot metrics are published by the leader. The two most useful alerts for the Raft cluster come from them: `vault_autopilot_healthy == 0`, and `vault_autopilot_failure_tolerance < 1`. The second one fires before the first failure becomes an outage, because it says the cluster has no spare node.

A rising `vault_raft_leader_lastContact` or `vault_raft_commitTime` shows a slow network or disk before autopilot marks a node unhealthy. Compare them with the thresholds you read in the autopilot settings.

## Leases and tokens

| Metric | Type | Answers |
| --- | --- | --- |
| `vault_expire_num_leases` | gauge | How many leases are active? |
| `vault_token_count` | gauge | How many tokens exist? |

A lease is created for each dynamic secret and each service token. A count that rises without stopping means some client creates leases and never revokes or lets them expire. A large number slows expiry, startup and unseal, and a restart has to load them all. Alert on a trend, such as growth over several hours, not on one value.

## Audit device failures

| Metric | Type | Answers |
| --- | --- | --- |
| `vault_audit_log_request_failure` | counter | How many request entries could not be written? |
| `vault_audit_log_response_failure` | counter | How many response entries could not be written? |

These counters should stay at zero. An increase means a device is failing, and when all devices fail the server refuses requests. Use `increase(vault_audit_log_request_failure[5m]) > 0`.

## Writing a good query

Two habits keep queries correct in a cluster with several nodes. First, aggregate over nodes when the question is about the cluster: `sum(vault_core_active)` is 1 in a healthy cluster. Second, keep the node in the result when the question is about a node: `vault_core_unsealed == 0` returns one series per sealed node, and the label `instance` names it.

You now know the metrics that describe the Raft cluster, the leases and the audit devices. The last part turns these into alert rules.

## Common pitfalls

> [!WARNING]
> - **Alerting on the value of a counter.** Use `increase()` or `rate()`.
> - **Alerting on one node's `vault_core_active`.** Standbys report 0 by design; sum over all nodes.
> - **Expecting every metric on every node.** Some are published only by the leader.
> - **Alerting on lease counts as a fixed number.** Alert on growth.
