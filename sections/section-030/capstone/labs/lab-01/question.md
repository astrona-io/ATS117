# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Telemetry and monitoring

## Scenario

Last month a standby in the OpenBao cluster in the namespace `openbao` restarted and stayed sealed for three days. Nobody noticed until the leader failed and the cluster went down. The cluster already has telemetry turned on. Prometheus runs in the namespace `monitoring`, but its OpenBao job reaches only the Service `openbao-active` and gets no usable metrics. There are no alert rules.

Prometheus reads its configuration from the ConfigMap `prometheus-config` and its alert rules from the ConfigMap `prometheus-rules` (every `*.yml` key is loaded).

## Your task

1. Make Prometheus scrape all three OpenBao pods directly, in the Prometheus format, under the job name `openbao`.
2. Add an alert rule named `OpenBaoNodeSealed` that fires, within two minutes, when any OpenBao node is sealed. It must be based on `vault_core_unsealed`, and it must also fire if a sealed node stops answering the scrape.

## Constraints

- Do not change the OpenBao cluster: it is configured correctly.
- Do not give Prometheus an OpenBao token.
- Keep the job name `openbao` and the alert name `OpenBaoNodeSealed`.

## Done when

- Prometheus has three healthy targets in the job `openbao`.
- Prometheus has loaded the alert `OpenBaoNodeSealed`, and its expression uses `vault_core_unsealed`.
- When the grader restarts a standby and leaves it sealed, `OpenBaoNodeSealed` fires within four minutes. (The grader unseals the pod afterwards.)
- The secret `secret/platform/marker` still exists.
