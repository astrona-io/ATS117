# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Telemetry and monitoring

## Scenario

The three-node OpenBao cluster in the namespace `openbao` has no telemetry. A Prometheus server in the namespace `monitoring` was set up for it, but its OpenBao job scrapes only the Service `openbao-active` and has never collected a single OpenBao metric. The on-call team wants to see the seal state of every node.

The Helm release is `openbao` (chart `openbao` 0.30.4); the cluster uses the Shamir seal, and the lab-only key share and root token are in the Secret `openbao-init`. Prometheus reads its configuration from the ConfigMap `prometheus-config`.

## Your task

1. Turn on telemetry on every OpenBao pod: the Prometheus format with a retention time of `30s`, host names removed from metric names, and metrics readable without a token.
2. Roll the change out to all three pods without the cluster losing quorum.
3. Make Prometheus scrape each of the three pods directly, in the Prometheus format, under the job name `openbao`.

## Constraints

- Do not initialize the cluster again and do not delete PersistentVolumeClaims.
- Do not give Prometheus an OpenBao token.
- Keep the job name `openbao`.

## Done when

- Every pod serves `vault_core_unsealed` at `/v1/sys/metrics?format=prometheus` without a token.
- Prometheus has three healthy targets in the job `openbao`.
- In Prometheus, `vault_core_unsealed` is `1` for three pods.
- The secret `secret/platform/marker` still exists.
