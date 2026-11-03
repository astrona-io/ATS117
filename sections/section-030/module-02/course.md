# Logs, Audit And Alerts

A cluster with metrics still leaves questions open. Why did the leader change at three in the morning? Who read a secret last week? Which node should a load balancer use? Each question has its own source of evidence, and an operator must know which one to open.

Keep one sentence in mind: **metrics say that something changed, logs say what the server did, and the audit log says what clients did.** This module adds the last two and turns the metrics into alerts.

The module has five parts. **Server Logs And bao monitor** sets the log level and streams a node's log. **Audit Devices** enables an audit device and reads an entry. **Health Checks And Probes** reads the status codes of the health endpoint and the probes of your pods. **Raft And Lease Metrics** picks the metrics for cluster health, leases and audit failures. **Alert Rules** writes Prometheus rules and loads them; a graded lab follows it.

## Learning objectives

After this module you can:

- Set the log level and format and stream a node's log with `bao monitor`.
- Enable a file audit device and read a request and a response entry.
- Explain why a failing audit device blocks requests.
- Read the status codes of `/v1/sys/health` and change them with parameters.
- Name the metrics for autopilot health, leases and audit failures.
- Write, load and test Prometheus alert rules for an OpenBao cluster.

## Before you start

You need the telemetry and Prometheus basics from the first module of this section: the `telemetry` stanza, scraping every node and the main gauges. You need `kubectl exec`, and a little PromQL.

Your playground has a three-node OpenBao cluster in the namespace `openbao` (Shamir seal, telemetry on, unauthenticated metrics access; the key and root token are in the Secret `openbao-init`), Prometheus in the namespace `monitoring` that scrapes all three pods (the rules are in the ConfigMap `prometheus-rules`, which is empty at the start), and the `tester` pod in the namespace `clients` with `curl` and `jq`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
