# Server Logs And bao monitor

Metrics tell you that something changed. Logs tell you why. Every OpenBao node writes its own log, and the first question in any incident is which node to read. This part sets the log level and format, reads the logs of a pod, and streams them from the API with `bao monitor`.

## Where the log goes

OpenBao writes its operational log to standard error. In Kubernetes, the container runtime collects it, so `kubectl logs` shows it. Each pod has its own log, and the log of a standby does not contain what the leader did. Set up the helper and read the last lines of the leader and of a standby:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
kubectl -n openbao logs openbao-0 --tail=20
kubectl -n openbao logs openbao-1 --tail=20
```

Each line has a timestamp, a level (`[INFO]`, `[WARN]`, `[ERROR]`, `[DEBUG]` or `[TRACE]`) and a source, followed by the message. Startup lines show the seal type, the storage backend and the listener. Lines after startup show elections, unseal events and warnings.

## Level and format

The server reads the log level from the `log_level` setting in the configuration file, from the flag `-log-level`, or from the environment variable `BAO_LOG_LEVEL`. The levels are `trace`, `debug`, `info`, `warn` and `error`. The default is `info`. A higher level of detail costs disk and CPU, so raise it for a short time. The format is set by `log_format`, which is `standard` or `json`. Use `json` when a log shipper parses the lines.

The setting goes in the server configuration, which in the chart is `server.ha.raft.config`:

```hcl
log_level  = "info"
log_format = "json"
```

A change to the configuration file takes effect after a restart of the pod. The next section shows a way to see debug output without one.

## Streaming logs with bao monitor

`bao monitor` connects to a node's API and streams its log, at a level you choose, until you stop it. The stream is read from the node you connect to, and it needs a token with read capability on `sys/monitor`. Run it for a few seconds against a standby:

```sh
timeout 20 kubectl -n openbao exec -i openbao-1 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao monitor -log-level=debug
```

The stream starts with debug lines that `kubectl logs` does not show, because the server's own level is still `info`. Closing the command ends the stream, and the server goes back to its normal output. This makes `bao monitor` the right tool for a short investigation: turn up the detail on one node, reproduce the problem, and stop.

Because the stream shows server internals, the policy for `sys/monitor` belongs only to operators:

```hcl
path "sys/monitor" {
  capabilities = ["read"]
}
```

## What to look for

Three kinds of lines carry most of the information in an incident:

- **Seal and unseal lines.** They show when a node unsealed, and a failure shows the error from the seal.
- **Election lines.** `entering candidate state` and `election won` mean the leadership moved. A burst of them means an unstable leader.
- **Warnings from the storage.** Slow disk writes and failed heartbeats show a node that is struggling before autopilot marks it unhealthy.

You now know where the logs are, how to set their level and format, and how to stream debug output from one node without a restart. Logs describe the server's own behaviour. The audit log, which is the subject of the next part, describes what clients did.

## Common pitfalls

> [!WARNING]
> - **Reading the log of one pod only.** Each node logs separately; find the leader first.
> - **Leaving `debug` on.** The log grows fast and may contain details you do not want to ship.
> - **Giving `sys/monitor` to application tokens.** It shows server internals.
> - **Treating the operational log as an audit trail.** It does not record who read which secret.
