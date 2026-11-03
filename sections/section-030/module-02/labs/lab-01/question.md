# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Telemetry

## Scenario

The OpenBao cluster in the namespace `openbao` has three pods on Integrated Storage and the Shamir seal. Prometheus in the namespace `monitoring` already scrapes all three pods. A security review found two gaps: nobody can tell afterwards which client read which secret, and nothing alerts the team when the cluster has no active node.

What you have:

- The cluster's lab-only unseal key and root token in the Secret `openbao-init` (namespace `openbao`).
- Prometheus with its configuration in the ConfigMap `prometheus-config` and its alert rules in the ConfigMap `prometheus-rules` (namespace `monitoring`). The rules ConfigMap is empty.
- A `tester` pod in the namespace `clients` with `curl` and `jq`.
- A marker secret at `secret/platform/marker`.

## Your task

1. Enable an audit device of the type `file` that writes to standard output, so the container logs hold the audit entries.
2. Make a read request and confirm that its audit entry appears in the log of the active node.
3. Add an alert rule named `OpenBaoNoActiveNode` to Prometheus. It must use the metric `vault_core_active`, and it must fire when no node is active.
4. Make Prometheus load the rule and confirm that it is healthy and not firing.

## Constraints

- Do not initialize the cluster again and do not delete PersistentVolumeClaims.
- Do not enable `log_raw` on the audit device.
- Do not change the scrape configuration.

## Done when

- A `file` audit device is enabled.
- The log of the active node holds an audit entry for a request to `secret/data/platform/marker`.
- The Prometheus API lists the rule `OpenBaoNoActiveNode` with the health `ok`, an expression that uses `vault_core_active`, and a state other than `firing`.
- The secret `secret/platform/marker` still exists.
