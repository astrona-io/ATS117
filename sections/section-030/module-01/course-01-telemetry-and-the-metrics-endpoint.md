# Telemetry And The Metrics Endpoint

Before Prometheus can collect anything, OpenBao must keep metrics and serve them where Prometheus can reach them without a token. This part shows the two pieces of configuration that do that, and reads the metrics of one node by hand.

## The telemetry stanza

OpenBao keeps metrics in memory and can send them to several systems. For Prometheus, which pulls metrics, two settings in the `telemetry` stanza matter. Look at the configuration of the playground cluster:

<!-- astrona:playground:renew -->

```sh
kubectl -n openbao get configmap openbao-config -o jsonpath='{.data.extraconfig-from-values\.hcl}'
```

Next to the `listener` and `storage` blocks you find:

```hcl
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
```

`prometheus_retention_time` turns on the Prometheus format and says how long OpenBao keeps a value that has not been updated. The default is `24h`; a short value keeps old values from lingering after something stopped. `disable_hostname` removes the host name from the front of every metric name, so the names are the same on every pod and in every query. The OpenBao documentation recommends it for Prometheus.

## Who may read the metrics

The metrics endpoint is `/v1/sys/metrics`. By default it needs a token, like almost every OpenBao endpoint. Prometheus has no token, so the listener allows anonymous reads of the metrics, and only the metrics. In the playground's `listener "tcp"` block:

```hcl
listener "tcp" {
  tls_disable     = 1
  address         = "[::]:8200"
  cluster_address = "[::]:8201"

  telemetry {
    unauthenticated_metrics_access = true
  }
}
```

Read the metrics of one pod from the `tester` pod. Each pod has its own DNS name through the headless Service `openbao-internal`:

```sh
kubectl -n clients exec -i deploy/tester -- \
  curl -s "http://openbao-1.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/metrics?format=prometheus" | head -40
```

The output is plain text in the Prometheus exposition format: a `# HELP` line, a `# TYPE` line and one line per value. The `format=prometheus` parameter matters. Without it, the endpoint returns JSON that Prometheus cannot read. The metric names start with `vault_`, kept from the project OpenBao was forked from. Look for one line in particular:

```sh
kubectl -n clients exec -i deploy/tester -- \
  curl -s "http://openbao-1.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/metrics?format=prometheus" | grep '^vault_core_unsealed'
```

`vault_core_unsealed` is a gauge: `1` when this node is unsealed, `0` when it is sealed. It is the single most useful number in this module.

## What one node can tell you

Ask `openbao-0` and `openbao-2` the same question and compare `vault_core_active`:

```sh
for pod in openbao-0 openbao-1 openbao-2; do
  echo "$pod: $(kubectl -n clients exec -i deploy/tester -- curl -s "http://$pod.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/metrics?format=prometheus" | grep '^vault_core_active')"
done
```

Only the leader reports `1`. Each node describes itself and nothing else: the active node does not report that a standby is sealed. That is the reason the next step scrapes every pod.

You now know the two settings that make metrics available to Prometheus, how to read them by hand with the `format` parameter, and that each node only describes itself. The open question is how to make Prometheus collect them from all three pods.

## Common pitfalls

> [!WARNING]
> - **Leaving out `format=prometheus`.** The endpoint answers with JSON, and the Prometheus scrape fails.
> - **Turning on unauthenticated access for everything.** The setting is in the listener's `telemetry` block and covers the metrics endpoint only; it is not a general anonymous mode.
> - **Scraping through a Service.** A Service picks one pod per request; you never learn which one, and sealed pods are skipped.
> - **Forgetting the restart.** The configuration is read at start. With the `OnDelete` strategy, nothing changes until you delete each pod.
