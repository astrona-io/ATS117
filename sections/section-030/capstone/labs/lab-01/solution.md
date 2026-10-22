# Solution: Alert When A Node Is Sealed

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: three healthy targets, the alert rule, the alert firing for a sealed node, and the original data.

## Step 1: See what Prometheus gets today

```sh
kubectl -n monitoring get configmap prometheus-config -o jsonpath='{.data.prometheus\.yml}'
kubectl -n clients exec -i deploy/tester -- \
  curl -s http://prometheus.monitoring:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, url: .scrapeUrl, health: .health, error: .lastError}'
```

The OpenBao job has one target, the Service `openbao-active`, with the path `/v1/sys/metrics` and no `format` parameter. The target is down: the endpoint answers with JSON, which Prometheus cannot parse. Even fixed, it would only ever see the leader.

## Step 2: Scrape every pod in the Prometheus format

Save this as `configmap-prometheus-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    rule_files:
      - /etc/prometheus/rules/*.yml
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]
      - job_name: openbao
        metrics_path: /v1/sys/metrics
        params:
          format: ["prometheus"]
        static_configs:
          - targets:
              - openbao-0.openbao-internal.openbao.svc.cluster.local:8200
              - openbao-1.openbao-internal.openbao.svc.cluster.local:8200
              - openbao-2.openbao-internal.openbao.svc.cluster.local:8200
```

Apply it:

```sh
kubectl apply -f configmap-prometheus-config.yaml
```

## Step 3: Add the alert rule

A sealed node either reports `vault_core_unsealed 0` or stops answering the scrape, so the rule covers both. Save this as `configmap-prometheus-rules.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: monitoring
data:
  openbao.yml: |
    groups:
      - name: openbao
        rules:
          - alert: OpenBaoNodeSealed
            expr: vault_core_unsealed == 0 or up{job="openbao"} == 0
            for: 30s
            labels:
              severity: critical
            annotations:
              summary: "OpenBao node {{ $labels.instance }} is sealed or not answering"
```

Apply it and restart Prometheus so it reads both ConfigMaps:

```sh
kubectl apply -f configmap-prometheus-rules.yaml
kubectl -n monitoring rollout restart deployment/prometheus
kubectl -n monitoring rollout status deployment/prometheus
```

A `for` of 30 seconds plus a 15-second scrape and evaluation interval keeps the alert well inside two minutes.

## Step 4: Test it

```sh
kubectl -n openbao delete pod openbao-2
sleep 90
kubectl -n clients exec -i deploy/tester -- \
  curl -s http://prometheus.monitoring:9090/api/v1/alerts | jq '.data.alerts[] | {alert: .labels.alertname, instance: .labels.instance, state: .state}'
```

The alert is firing for `openbao-2`. Unseal it again with the lab-only key from the Secret `openbao-init` and the alert clears:

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
kubectl -n openbao exec -i openbao-2 -- env BAO_ADDR=http://127.0.0.1:8200 bao operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
```

If `openbao-2` is the leader on your cluster, test with a standby instead.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Add `?format=prometheus` to `metrics_path` | Prometheus escapes the question mark and the scrape still fails |
| Alert on `vault_core_unsealed == 0` only | A sealed node that stops answering produces no series, and the alert never fires |
| Scrape `openbao-active` with the right format | Only the leader is ever seen; a sealed standby is invisible |
| Give Prometheus a token | The task forbids it; the token would sit in a ConfigMap |
