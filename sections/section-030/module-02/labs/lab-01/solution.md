# Solution: Audit And Alert On The Cluster

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks five things: a file audit device exists, the leader's log holds an audit entry, the rule `OpenBaoNoActiveNode` is loaded and healthy, it is not firing, and the original data.

## Step 1: Find the active node

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
```

The leader is the row with `leader` in the `State` column. Set `LEADER` to its name, for example `LEADER=openbao-0`.

## Step 2: Enable the audit device

```sh
bao_on "$LEADER" audit enable file file_path=stdout
bao_on "$LEADER" audit list -detailed
```

The list shows the device `file/` of the type `file`. An audit device is cluster-wide, so this is done once.

## Step 3: Make a request and read the entry

```sh
bao_on "$LEADER" kv get secret/platform/marker
kubectl -n openbao logs "$LEADER" --tail=10
```

Among the log lines are JSON lines with `"type":"request"` and `"type":"response"`. The request line holds the path `secret/data/platform/marker`.

## Step 4: Add the alert rule

```sh
kubectl apply -f - <<'RULES'
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
          - alert: OpenBaoNoActiveNode
            expr: sum(vault_core_active) < 1
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "No OpenBao node is active"
RULES
```

The sum over all nodes is 1 in a healthy cluster, because only the active node reports 1.

## Step 5: Make Prometheus load the rule

Prometheus reads the rule files when it starts, so restart it:

```sh
kubectl -n monitoring rollout restart deployment/prometheus
kubectl -n monitoring rollout status deployment/prometheus
sleep 30
kubectl -n clients exec -i deploy/tester -- curl -s http://prometheus.monitoring:9090/api/v1/rules | jq '.data.groups[].rules[] | {name, health, state}'
```

The rule shows `health` `ok` and a `state` of `inactive`. The state is `inactive` because the cluster has an active node.
