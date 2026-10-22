# Overview: Monitor An OpenBao Cluster (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs a three-node OpenBao cluster with telemetry turned on and a Prometheus server, and then waits. There is no task, no `astrona submit` and no pass or fail.

## What's in the box

- A single-node `kind` Kubernetes cluster, with Helm and the `bao` CLI 2.7.1 on your machine.
- **OpenBao** in the namespace `openbao`: pods `openbao-0` to `openbao-2` on Integrated Storage, Shamir seal with one lab-only key share (Secret `openbao-init`). The configuration has a `telemetry` stanza (`prometheus_retention_time = "30s"`, `disable_hostname = true`) and unauthenticated metrics access on the listener.
- **Prometheus** v3.15.1 in the namespace `monitoring`: configuration in the ConfigMap `prometheus-config`, alert rules in the ConfigMap `prometheus-rules`. At the start it scrapes only itself.
- A `tester` pod with `curl` and `jq` in the namespace `clients`.

## Helpers

Paste these once in each new terminal. `metrics_of` prints the Prometheus metrics of one pod. `promql` runs a query in Prometheus and prints instance and value.

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
metrics_of() { kubectl -n clients exec -i deploy/tester -- curl -s "http://$1.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/metrics?format=prometheus"; }
promql() { kubectl -n clients exec -i deploy/tester -- curl -s -G --data-urlencode "query=$1" http://prometheus.monitoring:9090/api/v1/query | jq -r '.data.result[] | "\(.metric.instance // "-") \(.value[1])"'; }
```

Use them like this: `metrics_of openbao-1 | grep '^vault_core'`, `promql vault_core_unsealed`.

To open Prometheus in a browser, run `kubectl -n monitoring port-forward svc/prometheus 9090:9090` in a second terminal and visit `http://localhost:9090`.

## Practice tasks

- Compare `metrics_of openbao-0` with `metrics_of openbao-1` for `vault_core_active`, and explain the difference.
- Request the metrics endpoint without `format=prometheus` and look at the answer. Then add the scrape job from the module.
- Restart one standby without unsealing it. Watch `promql vault_core_unsealed` and `promql 'up{job="openbao"}'` and note which one changes.
- Ask every pod for `/v1/sys/health` and write down the status codes. Repeat with `?standbyok=true` and with the sealed pod.
- Add the `OpenBaoNodeSealed` rule, seal a standby by restarting it, and watch the alert move from pending to firing.
