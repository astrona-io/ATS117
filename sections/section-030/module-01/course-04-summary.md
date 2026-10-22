# Summary

OpenBao can describe its own health, but only node by node. This module showed how to collect that description from every node and turn it into alerts and load balancer decisions.

## What you learned

The `telemetry` stanza makes OpenBao keep metrics. `prometheus_retention_time` turns on the Prometheus format, and `disable_hostname` keeps metric names the same on every node. The metrics endpoint `/v1/sys/metrics` needs a token unless the listener's `telemetry` block sets `unauthenticated_metrics_access = true`, and it answers in the Prometheus format only with the `format=prometheus` parameter. The metric names start with `vault_`.

Each node reports only its own state, so Prometheus must scrape every pod. A scrape job with `metrics_path: /v1/sys/metrics` and `params: format: ["prometheus"]`, targeting each pod through the headless Service, gives one series per node with an `instance` label. A configuration change reaches a Shamir cluster with the `OnDelete` strategy only through a rolling restart: standbys one at a time with an unseal after each, then a step-down and the old leader last.

A few metrics answer most questions: `vault_core_unsealed` and `vault_core_active` per node, autopilot's health and failure tolerance from the active node, the Raft peer count, and the number of leases. An alert on a sealed node should cover both a node that reports `0` and a node that stops answering. The health endpoint `/v1/sys/health` answers without a token with `200` for the active node, `429` for a standby, `501` when not initialized and `503` when sealed; parameters such as `standbyok` adapt it to load balancers. The key facts to remember are these:

- Scrape every node; the active node does not report a sealed standby.
- Use `params` for the format parameter, not the path.
- Failure tolerance drops before any request fails.
- `429` is a healthy standby.

<!-- astrona:playground:destroy -->
