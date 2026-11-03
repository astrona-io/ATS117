# Seal Status And Manual Sealing

An operator must be able to read the seal state of a node in a second, and sometimes needs to seal a node on purpose. This part reads the seal status, explains each field, and shows what `bao operator seal` does to a cluster.

## Reading the seal status

`bao status` is the quickest way to see a node's seal. It talks to one node, so run it on each pod you care about. Set up the helper and ask the first pod:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 status
```

The fields that describe the seal:

- `Seal Type` is the way the root key is protected: `shamir`, `transit`, `static`, or the name of a plugin seal.
- `Initialized` is `true` once `bao operator init` has run.
- `Sealed` is `true` when the node cannot read its data.
- `Total Shares` and `Threshold` appear with the Shamir seal. They are the number of unseal key shares and how many unseal the node.
- `Recovery Seal Type`, `Total Recovery Shares` and `Recovery Threshold` appear with an auto-unseal. The recovery keys cannot unseal; they authorize special operations.
- `Unseal Progress` counts the shares entered so far, while a Shamir unseal is in progress.

The same facts are available over HTTP, without a token, at `/v1/sys/seal-status`. Monitoring tools and scripts read that endpoint, and `bao status` itself uses it.

## Sealing a node on purpose

`bao operator seal` seals the node it is sent to. The node forgets the root key, stops answering requests, and keeps its data on disk. With the Shamir seal it stays sealed until someone enters the key shares again. With an auto-unseal, restart the pod and it unseals itself. Sealing is an emergency control: if you suspect a node is compromised, sealing it stops it from serving anything.

Try it on a standby and read the result. Replace `openbao-2` if it is the leader:

```sh
bao_on openbao-0 operator raft list-peers
bao_on openbao-2 operator seal
bao_on openbao-2 status
bao_on openbao-0 operator raft autopilot state
```

The sealed node shows `Sealed true`. The autopilot state of the leader shows the cluster as unhealthy, or the sealed node as not alive, and the failure tolerance falls to `0`. The cluster still serves requests, because two voters remain. Unseal the node again, with the key from the Secret `openbao-init` in this lab:

```sh
bao_on openbao-2 operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
```

If the playground cluster uses auto-unseal instead, restart the pod to unseal it.

## Sealing the active node

Sealing the active node makes a standby take over. The standby wins an election, becomes active and keeps serving. The clients that talk to the Service `openbao-active` find the new leader after the Service follows the pod labels. Sealing the active node is the right first step when a leader misbehaves and you want a clean failover; `bao operator step-down` does the same without sealing it.

Sealing every node is an outage. After that, only the unseal procedure brings the cluster back, and with the Shamir seal that needs the key holders. This is why a break-glass seal of the whole cluster belongs in the incident runbook with the names of the people who can unseal.

## Permissions

`bao operator seal` is a `sudo` operation on `sys/seal`. Unseal needs no token, because a sealed node cannot check one. That is by design: the key shares are the authorization. Anybody who can reach a sealed node and holds the shares can unseal it, which is why the shares are kept apart.

You now know how to read a node's seal state, what the recovery fields mean and how sealing a node differs from stepping it down. The module's graded lab brings the first pieces together.

## Common pitfalls

> [!WARNING]
> - **Sealing the active node without a standby that can take over.** The service stops.
> - **Sealing every node.** Only the key holders can bring the cluster back.
> - **Checking only one node.** The seal state is per node; look at each pod.
> - **Expecting an auto-unsealed node to unseal itself right after `operator seal`.** Restart the pod to make it unseal.
