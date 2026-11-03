# Telemetry Settings That Matter

The metrics module so far used the defaults of the `telemetry` stanza and one listener setting. A few more settings change what Prometheus sees, how much it stores and how heavy the scrape is. This part reads them and says when to change each.

## Where the settings live

There are two places. The `telemetry` stanza at the top level of the server configuration sets what the server records and how long it keeps it. The `telemetry` block inside a `listener` sets who may read the metrics. Look at both in your playground:

<!-- astrona:playground:renew -->

```sh
kubectl -n openbao get configmap openbao-config -o jsonpath='{.data.extraconfig-from-values\.hcl}'
```

The ConfigMap holds the server configuration. Find the listener block with `unauthenticated_metrics_access` and the top-level block with `prometheus_retention_time` and `disable_hostname`.

## The settings

| Setting | Where | What it does |
| --- | --- | --- |
| `prometheus_retention_time` | `telemetry` | How long the server keeps its metrics in memory for the Prometheus format. A value of `0` turns the Prometheus output off. The scrape interval must be shorter than this |
| `disable_hostname` | `telemetry` | Leaves the host name out of the metric names. Set it to `true` when the metric name should be the same on every node and the node is a label instead |
| `usage_gauge_period` | `telemetry` | How often the server counts entities, tokens and secrets for the usage gauges. A larger number means less work on a big cluster |
| `maximum_gauge_cardinality` | `telemetry` | The upper limit of label combinations for a gauge, to protect the server and Prometheus from too many series |
| `lease_metrics_epsilon` and `num_lease_metrics_buckets` | `telemetry` | The width and number of buckets of the lease expiry histogram |
| `unauthenticated_metrics_access` | `listener` `telemetry` | Lets a client read the metrics without a token |

Three of them decide most cases. First, keep `prometheus_retention_time` longer than two scrape intervals; a retention of `30s` with a scrape interval of `15s` is the smallest sensible pair, and a Prometheus that misses one scrape sees a gap. Second, set `disable_hostname = true`, so that metric names do not contain the host name; Prometheus adds the `instance` label. Third, change the usage gauge settings only if the gauges cost too much on a cluster with many tokens.

## Unauthenticated access, and the alternative

The simple setup lets any client in the cluster read the metrics. That is acceptable when a network policy limits who reaches the port, and the metrics hold no secret values. When that is not acceptable, use a token instead: Prometheus supports a bearer token for a scrape job, and the token needs `read` on `sys/metrics`:

```hcl
path "sys/metrics" {
  capabilities = ["read"]
}
```

A token for Prometheus follows the same rules as any job token: orphan, periodic, and renewed by something. If the token expires, the scrape fails with `403` and the `up` metric drops to `0`, which is why an alert on `up` is the first one to write.

## Other destinations

The Prometheus format is a pull model: Prometheus asks each node. Other telemetry destinations push, and the stanza has settings for statsd, DogStatsD and a few cloud monitoring services. They use the same metric names. Choose the model your platform already runs, not the one that looks newest, and make sure every node reports, since each node reports only itself.

You now know which telemetry settings change what Prometheus records, how to protect the metrics endpoint with a token and why every node reports separately. This closes the module's reading; the next module goes further with logs, audit and alerts.

## Common pitfalls

> [!WARNING]
> - **A retention shorter than the scrape interval.** Prometheus sees gaps and empty results.
> - **Metrics names with the host name inside.** Queries must then change per node; set `disable_hostname = true`.
> - **A scrape token that expires.** The scrape fails with `403` and the node looks down.
> - **Leaving the metrics open on a network where untrusted pods run.** Restrict the port or use a token.
