# Audit Devices

The operational log says what the server did. The audit log says who asked for what and what the server answered. Security teams need it for investigations, and some regulations require it. This part enables an audit device, reads an entry, and explains why OpenBao refuses requests when no audit device can write.

## What an audit device records

An audit device writes one JSON line for each request and one for each response. A line holds the time, the identity of the caller, the path, the operation, and the data of the request or response. Secret values and tokens in the line are not written in the clear. OpenBao replaces each one with `hmac-sha256:` followed by a salted hash. You can compare a value you know with a logged value, without the log revealing it.

Three device types exist: `file` writes to a file or to standard output, `syslog` writes to the local syslog, and `socket` writes to a TCP or UDP address. In Kubernetes, the simplest is the file device with the path `stdout`, because the container runtime then collects the audit lines like any other log.

## Enabling the file device

An audit device is cluster-wide, so you enable it once. The path `stdout` makes every node that handles a request write it to its own standard output:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
LEADER=$(bao_on openbao-0 operator raft list-peers -format=json | tr -d '\n ' | grep -o '{[^{}]*"leader":true[^{}]*}' | sed -n 's/.*"node_id":"\([^"]*\)".*/\1/p')
echo "$LEADER"
bao_on "$LEADER" audit enable file file_path=stdout
bao_on "$LEADER" audit list -detailed
```

The list shows the device at the path `file/`, its type and its options. Enabling an audit device needs the `sudo` capability on `sys/audit/<path>`; a root token has it.

## Reading an entry

Make one request and read the audit lines of the leader:

```sh
bao_on "$LEADER" kv get secret/platform/marker
kubectl -n openbao logs "$LEADER" --tail=6
```

Among the operational lines are JSON lines with `"type":"request"` and `"type":"response"`. The request line has the path (`secret/data/platform/marker`), the operation (`read`) and the `client_token`, which is a hash, not the token. The response line shows the data keys with hashed values. To see what the hash of a value looks like, ask the server to compute it:

```sh
bao_on "$LEADER" write sys/audit-hash/file input=ats-117
```

The hash is the same value that appears in the log for that input, so a person who knows a value can find it in the log.

## When the audit device cannot write

If at least one audit device is enabled, OpenBao must write each request to at least one of them before it answers. If every device fails, the server refuses the request. This protects the audit trail, and it also means a full disk or an unreachable syslog target stops the whole cluster from serving requests. Two rules follow from it:

- Enable at least two devices in a production cluster, on different targets, so one failure does not block requests.
- Watch the audit failure metrics (`vault_audit_log_request_failure` and `vault_audit_log_response_failure`) and alert on any increase.

You can also set `log_raw=true` on a device to write values in the clear. Never do this outside a lab, because the log then holds every secret that was read.

## Who reads the audit log

The audit lines are as sensitive as the secrets' metadata: they name every path that clients use. Ship them to a system that operators cannot edit, keep them longer than the operational logs, and restrict who can read them. Standard output is the lab choice; a production cluster usually uses a socket or a file on a volume that a log agent collects.

You now know how to enable an audit device, read a request and a response, and why a failing device blocks requests. The next part covers the health endpoint, which tells load balancers and probes whether a node can serve traffic.

## Common pitfalls

> [!WARNING]
> - **Enabling a single audit device.** If it fails, the cluster stops answering requests.
> - **Using `log_raw=true` in production.** The log then holds secrets in the clear.
> - **Expecting one node to log everything.** Each node logs the requests it handled; collect all pods.
> - **Letting operators edit the audit log.** A trail they can change is not evidence.
