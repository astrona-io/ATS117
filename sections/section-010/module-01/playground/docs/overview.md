# Overview: Run OpenBao As A Raft Cluster (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs a three-node OpenBao cluster on Integrated Storage, initializes and unseals it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it, and Helm and the `bao` CLI 2.7.1 are on your machine.
- **OpenBao v2.7.1** in the namespace `openbao`: the StatefulSet `openbao` with the pods `openbao-0`, `openbao-1` and `openbao-2`. They form one cluster on Integrated Storage (Raft) and find each other with `retry_join`. The Raft node IDs are the pod names.
- The Service `openbao-active`, which points at the leader, and the headless Service `openbao-internal`, which gives each pod a DNS name.
- The Shamir seal with one key share. The lab-only key (`unseal-key`) and root token (`root-token`) are in the Secret `openbao-init`. A real cluster never keeps them in a Kubernetes Secret.
- A KV version 2 secrets engine at `secret/` with one secret, `secret/platform/marker`.
- A `tester` pod with `curl` and `jq` in the namespace `clients`.

Every pod restart seals that pod again. A sealed pod shows `0/1` in `kubectl get pods`; that is expected.

## Helpers

Paste these once in each new terminal. `bao_on` runs `bao` inside one pod against its own listener. `unseal` enters the lab-only key on one pod. `peers` prints the Raft configuration as the first unsealed pod sees it.

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
unseal() { bao_on "$1" operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"; }
peers() { for pod in openbao-0 openbao-1 openbao-2; do bao_on "$pod" operator raft list-peers 2>/dev/null && return; done; }
```

Use them like this: `peers`, `bao_on openbao-1 status`, `unseal openbao-2`.

To use `bao` from your machine instead, start a port-forward in a second terminal (start it again after every leader change) and set the address:

```sh
kubectl -n openbao port-forward svc/openbao-active 8200:8200
export BAO_ADDR=http://openbao.localtest.me:8200
```

## Practice tasks

- Run `peers` and `bao_on openbao-0 operator raft autopilot state`. Write down the failure tolerance, then delete one follower pod and run both again before you unseal it.
- Delete the leader pod and time how long it takes until `peers` shows a new leader. Write a secret with the new leader, then unseal the old one.
- Delete two pods at once. Try a write on the survivor and read the error. Unseal one of the two and try again.
- Run `bao_on openbao-0 operator step-down` and see which pod becomes leader, without any pod restarting.
- Read the autopilot configuration, turn on dead-server cleanup with `-min-quorum=3`, and read it again.
