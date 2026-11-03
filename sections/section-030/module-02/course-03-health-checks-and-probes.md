# Health Checks And Probes

Load balancers, Kubernetes probes and monitoring tools all need a quick answer to one question: can this node serve traffic right now? OpenBao answers with the endpoint `/v1/sys/health`. It needs no token, and its HTTP status code carries the answer. This part reads the codes, changes them with query parameters, and checks the probes of your pods.

## The status codes

Ask three nodes for their health and print only the status code. The `tester` pod has `curl`:

<!-- astrona:playground:renew -->

```sh
for pod in openbao-0 openbao-1 openbao-2; do
  echo "$pod: $(kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}' http://$pod.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/health)"
done
```

One node answers `200` and the other two answer `429`:

| Code | Meaning |
| --- | --- |
| `200` | Initialized, unsealed and the active node |
| `429` | Unsealed and a standby |
| `501` | Not initialized |
| `503` | Sealed |

The body is JSON with the same facts: `initialized`, `sealed`, `standby`, the version and the cluster name. A script reads the body, a load balancer reads the code.

## Changing the codes

The defaults suit a load balancer that should send traffic only to the active node, because only that node answers `200`. A Kubernetes probe has a different job: it should not restart a healthy standby. Query parameters change the codes:

| Parameter | Effect |
| --- | --- |
| `standbyok=true` | A standby answers `200` instead of `429` |
| `sealedcode=204` | A sealed node answers `204` instead of `503` |
| `uninitcode=204` | An uninitialized node answers `204` instead of `501` |
| `activecode=` and `standbycode=` | Set the code of the active node and of a standby to another value |

Try one of them on a standby:

```sh
kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' "http://openbao-1.openbao-internal.openbao.svc.cluster.local:8200/v1/sys/health?standbyok=true"
```

The answer is `200` for a standby (use another pod name if `openbao-1` is the leader).

## What your pods use

The chart defines the probes of the StatefulSet. Read them:

```sh
kubectl -n openbao get statefulset openbao -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
echo
kubectl -n openbao get statefulset openbao -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'
echo
```

The output shows the path with its query parameters, the delays and the thresholds. A readiness probe decides whether the pod receives traffic from a Service. A liveness probe decides whether Kubernetes restarts the container. A liveness probe that fails on a sealed node would restart a pod that only needs unsealing, which is why such a probe must accept the sealed state.

## Choosing the right check

| Consumer | Needs | Check |
| --- | --- | --- |
| Load balancer for clients | Only the active node | The default `/v1/sys/health` with `200` as healthy |
| Kubernetes readiness | A node that is able to serve | Depends on the design; read the probe of the chart |
| Kubernetes liveness | The process is running | A path that accepts standby and sealed nodes |
| Monitoring | The state of every node | Metrics from every node, not the health code of one |

You now know the four status codes, how the parameters change them and how to read the probes of your pods. The health endpoint answers yes or no for a moment. The metrics in the next part show the trend.

## Common pitfalls

> [!WARNING]
> - **Pointing a client load balancer at all pods with `standbyok=true`.** Clients then reach standbys, which forward every write.
> - **A liveness probe that fails when the node is sealed.** Kubernetes restarts the pod in a loop.
> - **Relying on the health code for monitoring.** It shows one node at one moment; use metrics from every node.
> - **Forgetting that a standby answers `429`.** Many tools treat any non-200 as down.
