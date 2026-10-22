# Prerequisites

Before starting you should be able to:

- Use `kubectl` to read pods, Secrets and ConfigMaps, and to run commands in a pod with `kubectl exec`.
- Use the `bao` command-line tool with `BAO_ADDR` and `BAO_TOKEN`.
- Read a Helm values file and run `helm upgrade`.

## What the environment gives you

The environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- Helm 3.22.1 and the `bao` CLI 2.7.1 on your machine.
- OpenBao in the namespace `openbao`: the StatefulSet `openbao` with the pods `openbao-0`, `openbao-1` and `openbao-2`, Integrated Storage (Raft), the Services `openbao-active` and `openbao-internal`, and the lab-only unseal or recovery key and root token in the Secret `openbao-init`.
- Prometheus v3.15.1 in the namespace `monitoring` (Service `prometheus`, port `9090`).
- A `tester` pod with `curl` and `jq` in the namespace `clients`.

Nothing the task asks you to create has been created for you.

## Working rules

- Everything is graded on the **final state**. Leave your fix in place.
- The StatefulSet uses the `OnDelete` update strategy: a pod picks up new Helm values only when you delete it.
- With the Shamir seal, every restarted pod comes back sealed. Unseal it before you restart the next one.
