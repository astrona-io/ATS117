# Alert Rules

Metrics that nobody watches do not help. An alert rule turns a query into a notification when the query holds true for long enough. This part writes Prometheus alert rules for an OpenBao cluster, loads them, and checks their state.

## The shape of a rule

A rule file has groups, and a group has rules. An alert rule has a name, an expression, a duration, labels and annotations:

```yaml
groups:
  - name: openbao
    rules:
      - alert: OpenBaoNodeSealed
        expr: vault_core_unsealed == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "OpenBao node {{ $labels.instance }} is sealed"
```

The `expr` is a PromQL query; the alert is active for every series it returns. The `for` duration is how long the expression must hold true before the alert fires; until then the alert is `pending`. A short `for` avoids missing real problems, and a longer one avoids alerts for a restart that takes a minute.

## Rules that fit OpenBao

| Alert | Expression | Why |
| --- | --- | --- |
| `OpenBaoNodeSealed` | `vault_core_unsealed == 0` | A node cannot serve; the cluster has less tolerance |
| `OpenBaoNoActiveNode` | `sum(vault_core_active) < 1` | No node is the leader; every request fails |
| `OpenBaoNoFailureTolerance` | `vault_autopilot_failure_tolerance < 1` | One more failure stops the cluster |
| `OpenBaoAuditFailure` | `increase(vault_audit_log_request_failure[5m]) > 0` | An audit device is failing |
| `OpenBaoTargetDown` | `up{job="openbao"} == 0` | Prometheus cannot reach a node at all |

The last one is easy to forget. A sealed node still answers the metrics endpoint, but a node that is down answers nothing, and then the other metrics from it simply disappear. `up` is the only metric that shows the silence.

A note on `OpenBaoNoActiveNode`: if Prometheus cannot reach any node, `sum(vault_core_active)` returns nothing, not `0`, and the rule never fires. Together with `OpenBaoTargetDown`, the case is covered. Using `absent()` is another way.

## Loading rules into Prometheus

In the playground, Prometheus reads rule files from the ConfigMap `prometheus-rules`, which is mounted at `/etc/prometheus/rules`. Add a rule file to the ConfigMap, restart Prometheus so that it re-reads the files, and then read the rules through the API:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring get configmap prometheus-rules -o yaml
kubectl -n monitoring rollout restart deployment/prometheus
kubectl -n monitoring rollout status deployment/prometheus
kubectl -n clients exec -i deploy/tester -- curl -s http://prometheus.monitoring:9090/api/v1/rules | jq '.data.groups[].rules[] | {name, health, state}'
```

For each rule, `health` is `ok` when the expression evaluated without an error. `state` is `inactive` when it returns nothing, `pending` while the `for` duration runs, and `firing` after that. Read the first value, `health`: a rule with a wrong metric name has the health `ok` and never fires, because a query on a missing metric returns nothing. Test every new rule by changing the world once: seal a standby, or stop a scrape target, and watch the alert go through `pending` to `firing`.

## Rules and the cluster

Prometheus only evaluates; it does not send notifications. An Alertmanager takes the firing alerts, groups them and sends them to a chat, a pager or an email. That part is outside this module. Check the rules first, because an Alertmanager with wrong rules only delivers wrong alerts.

You now know how to write the alerts that matter for OpenBao, load them into Prometheus and read their state. You can apply this in the graded lab.

## Common pitfalls

> [!WARNING]
> - **A rule on a metric name that does not exist.** It stays `inactive` for ever and looks healthy.
> - **No alert for a node that is down.** Metrics from it vanish; use `up`.
> - **Editing the ConfigMap without restarting Prometheus.** In this setup, Prometheus reads the rule files at start.
> - **Setting `for` to zero on every rule.** A planned restart then pages someone.

## Your mission: Audit And Alert On The Cluster

You can now enable an audit device and write an alert rule. The graded lab gives you a monitored cluster that has neither and asks you to add both.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-117-playground-030-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-030/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-117-lab-030-02
astrona start ats-117-playground-030-02
```
