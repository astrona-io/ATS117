# Solution: Scrape Every Node With Prometheus

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: the metrics endpoint on every pod, three healthy targets, `vault_core_unsealed` for three pods, and the original data.

## Step 1: Add telemetry to the Helm values

Save this as `openbao-values-telemetry.yaml`. It is the cluster's current values with the listener's `telemetry` block and the `telemetry` stanza added:

```yaml
fullnameOverride: openbao
injector:
  enabled: false
server:
  # The chart allows one pod per node by default; the kind cluster has a
  # single node, so switch that off or openbao-1 and openbao-2 never start.
  affinity: ""
  # Create and replace pods without waiting for the one before to be Ready.
  # A sealed or migrating pod is never Ready, so with the chart's default,
  # OrderedReady, a restarted openbao-2 would wait for openbao-1 forever.
  # Kubernetes cannot change this on an existing StatefulSet, so every values
  # file sets it.
  podManagementPolicy: Parallel
  image:
    tag: "2.7.1"
  dataStorage:
    enabled: true
    size: 1Gi
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true
      config: |
        ui = true

        listener "tcp" {
          tls_disable     = 1
          address         = "[::]:8200"
          cluster_address = "[::]:8201"

          telemetry {
            unauthenticated_metrics_access = true
          }
        }

        storage "raft" {
          path = "/openbao/data"

          retry_join {
            leader_api_addr = "http://openbao-0.openbao-internal:8200"
          }
          retry_join {
            leader_api_addr = "http://openbao-1.openbao-internal:8200"
          }
          retry_join {
            leader_api_addr = "http://openbao-2.openbao-internal:8200"
          }
        }

        telemetry {
          prometheus_retention_time = "30s"
          disable_hostname          = true
        }

        service_registration "kubernetes" {}
ui:
  enabled: true
```

Apply it:

```sh
helm repo add openbao https://openbao.github.io/openbao-helm
helm upgrade openbao openbao/openbao --version 0.30.4 -n openbao -f openbao-values-telemetry.yaml
```

Nothing restarts yet: the StatefulSet uses `OnDelete`.

## Step 2: Restart the pods, standbys first

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
export SHAMIR_KEY=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
```

Assuming `openbao-0` is the leader, restart each standby and unseal it before the next:

```sh
for pod in openbao-1 openbao-2; do
  kubectl -n openbao delete pod "$pod"
  sleep 20
  bao_on "$pod" operator unseal "$SHAMIR_KEY"
  sleep 10
  bao_on openbao-0 operator raft list-peers
done
```

Then step the leader down and restart it last:

```sh
bao_on openbao-0 operator step-down
sleep 15
kubectl -n openbao delete pod openbao-0
sleep 20
bao_on openbao-0 operator unseal "$SHAMIR_KEY"
```

## Step 3: Check one pod by hand

```sh
kubectl -n clients exec -i deploy/tester -- \
  curl -s "http://openbao-1.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/metrics?format=prometheus" | grep '^vault_core_unsealed'
```

## Step 4: Fix the Prometheus job

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

Apply it and restart Prometheus:

```sh
kubectl apply -f configmap-prometheus-config.yaml
kubectl -n monitoring rollout restart deployment/prometheus
kubectl -n monitoring rollout status deployment/prometheus
```

## Step 5: Check in Prometheus and submit

Wait for two scrape intervals, then query:

```sh
sleep 40
kubectl -n clients exec -i deploy/tester -- \
  curl -s -G --data-urlencode 'query=vault_core_unsealed' http://prometheus.monitoring:9090/api/v1/query | jq '.data.result | length'
astrona submit -c sections/section-030/module-01/labs/lab-01
```

The query returns `3`.

## Common mistakes

- Scraping `openbao-active` with the format parameter. It works, but it reports only the leader.
- Restarting two pods at once and losing quorum.
- Giving Prometheus the root token instead of allowing unauthenticated metrics. The token lands in a ConfigMap.
