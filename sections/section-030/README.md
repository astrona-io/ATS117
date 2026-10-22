# Section 030: Telemetry And Monitoring

A cluster that no one watches fails quietly. A sealed standby, a node that fell behind the leader, or a seal that cannot reach its key service all look fine from the outside until the next restart or the next failure turns them into an outage.

OpenBao can report its own state as metrics. This section turns that on, scrapes every node with Prometheus, picks the metrics that tell you the cluster is healthy, and uses OpenBao's health endpoint the way a load balancer does. The capstone ends with an alert that fires when a node is sealed.

## What you will learn

- The `telemetry` stanza, the metrics endpoint `/v1/sys/metrics?format=prometheus`, and unauthenticated metrics access.
- Why every node must be scraped, not only the active one, and how to point Prometheus at each pod.
- The key metrics: `vault_core_unsealed`, `vault_core_active`, autopilot health and failure tolerance, Raft peers, and lease counts.
- The health endpoint `/v1/sys/health`, its status codes, and how a load balancer uses them.

## The learning path

The module starts at its landing page, which also launches the playground: a three-node cluster with telemetry turned on and a Prometheus server that scrapes only itself.

### 1. Monitor An OpenBao Cluster

1. Telemetry And The Metrics Endpoint
2. Scraping Every Node With Prometheus, followed by the lab **Scrape Every Node With Prometheus**
3. Key Metrics And The Health Endpoint
4. Summary

## Section capstone: Alert When A Node Is Sealed

Prometheus watches the cluster, but only through one Service and in a format it cannot read, and no rule tells anyone when a node is sealed. Fix the scraping and write an alert that fires when a pod restarts sealed. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-117-capstone-030
```
