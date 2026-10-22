# Monitor An OpenBao Cluster

Restart one standby in your playground cluster and leave it sealed. Requests through the Service `openbao-active` still succeed, so an application sees nothing. But the cluster now survives no further failure, and nothing tells you.

Metrics close that gap. OpenBao keeps counters and gauges about itself and serves them in the Prometheus format. Keep one sentence in mind: **every node reports only its own state, so every node must be scraped.** A monitor that asks only the active node never sees a sealed standby.

The module has three parts. **Telemetry And The Metrics Endpoint** shows the `telemetry` stanza that is already on in the playground, reads the metrics endpoint by hand, and explains unauthenticated access. **Scraping Every Node With Prometheus** writes the Prometheus scrape configuration for all three pods; a graded lab follows it. **Key Metrics And The Health Endpoint** picks the metrics that matter and shows the health endpoint that load balancers use.

## Learning objectives

After this module you can:

- Configure the `telemetry` stanza and unauthenticated metrics access on the listener.
- Read `/v1/sys/metrics?format=prometheus` from a single node.
- Write a Prometheus scrape job that reaches every pod, with the `format` parameter.
- Roll a configuration change out to a Shamir cluster without losing quorum.
- Name the metrics that show seal state, leadership and Raft health.
- Use the status codes of `/v1/sys/health` for load balancers and probes.

## Before you start

You need to know how a three-node OpenBao cluster on Integrated Storage behaves: the leader, standbys, quorum, and that every restarted pod comes back sealed with the Shamir seal. You need `kubectl exec`, `kubectl apply` and `helm upgrade`, and a little PromQL.

Your playground has:

| Object | What it is |
| --- | --- |
| Cluster `openbao` (namespace `openbao`) | Pods `openbao-0` to `openbao-2`, Shamir seal; the Helm values include a `telemetry` stanza and unauthenticated metrics access. Key and root token in the Secret `openbao-init` |
| Prometheus (namespace `monitoring`) | `prom/prometheus:v3.15.1`, configuration in the ConfigMap `prometheus-config`, alert rules in `prometheus-rules`. It scrapes only itself at the start |
| `tester` (namespace `clients`) | A pod with `curl` and `jq` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
