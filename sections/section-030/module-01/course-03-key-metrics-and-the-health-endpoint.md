# Key Metrics And The Health Endpoint

An OpenBao node serves hundreds of metrics. Most are useful only when you already know what is wrong. This part picks the handful that tell you the cluster is healthy, turns one of them into an alert rule, and then looks at the health endpoint, which load balancers and probes use instead of metrics.

## The metrics that matter

The OpenBao metric reference groups the metrics by area. For a cluster on Integrated Storage, these answer the first questions in an incident:

| Metric | Type | What it tells you |
| --- | --- | --- |
| `vault_core_unsealed` | Gauge | `1` if this node is unsealed, `0` if sealed |
| `vault_core_active` | Gauge | `1` on the active node, `0` on standbys |
| `vault_autopilot_healthy` | Gauge | `1` if autopilot considers all voters healthy |
| `vault_autopilot_failure_tolerance` | Gauge | How many voters can fail before quorum is lost |
| `vault_raft_peers` | Gauge | How many peers this node sees in the Raft configuration |
| `vault_expire_num_leases` | Gauge | How many leases exist; a fast rise often means a client creates tokens or secrets in a loop |

Query the failure tolerance in the playground:

<!-- astrona:playground:renew -->

```sh
kubectl -n clients exec -i deploy/tester -- \
  curl -s -G --data-urlencode 'query=vault_autopilot_failure_tolerance' http://prometheus.monitoring:9090/api/v1/query | jq '.data.result'
```

With three healthy voters the value is `1`. If it drops to `0`, the next failure is an outage, even though every request still succeeds. Autopilot metrics come from the active node; the other metrics come from every node. The Prometheus scrape job must reach all pods for these queries to work.

## An alert for a sealed node

A sealed node can fail in two ways in Prometheus. Either it still answers and reports `vault_core_unsealed 0`, or it stops answering the metrics endpoint and its target goes down, so `up` is `0`. A rule that covers both is safer than guessing which one you get. Save this as `configmap-prometheus-rules.yaml`:

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

Apply it and restart Prometheus:

```sh
kubectl apply -f configmap-prometheus-rules.yaml
kubectl -n monitoring rollout restart deployment/prometheus
```

Then check `http://localhost:9090/alerts` through your port-forward. The rule is listed and inactive. Delete one standby pod and leave it sealed; within about a minute the alert becomes pending and then firing for that instance. Unseal the pod and it clears.

## The health endpoint

Load balancers and Kubernetes probes do not read metrics. They send one request and look at the HTTP status code. OpenBao's health endpoint, `/v1/sys/health`, needs no token and answers with a code that describes the node:

| Status code | Meaning |
| --- | --- |
| `200` | Initialized, unsealed and active |
| `429` | Unsealed and standby |
| `501` | Not initialized |
| `503` | Sealed |

Ask each pod:

```sh
for pod in openbao-0 openbao-1 openbao-2; do
  echo "$pod: $(kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}' "http://$pod.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/health")"
done
```

The leader answers `200` and the standbys `429`. A load balancer that sends traffic only to the active node can use these defaults as they are. One that should also send reads to standbys adds `standbyok=true`, which makes standbys answer `200`. Parameters such as `standbycode`, `sealedcode` and `uninitcode` change each code for systems that only accept a fixed set. The Helm chart's liveness probe, when you turn it on, uses `/v1/sys/health?standbyok=true`.

You now know which metrics describe the cluster's health, how to alert on a sealed node in a way that covers both failure modes, and how the health endpoint's status codes serve load balancers.

## Common pitfalls

> [!WARNING]
> - **Alerting only on `vault_core_unsealed == 0`.** A sealed node may stop answering the scrape, and then the metric simply disappears. Add `up == 0`.
> - **Treating `429` as an error.** It is a healthy standby. Add `standbyok=true` where standbys should count as up.
> - **Reading failure tolerance from a standby.** Autopilot metrics come from the active node.
> - **Watching only request errors.** Failure tolerance drops long before any request fails.
