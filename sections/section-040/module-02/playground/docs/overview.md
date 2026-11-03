# Overview: Automate Backups And Plan Upgrades (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs a three-node OpenBao cluster with example data, and then waits. There is no task, no `astrona submit` and no pass or fail.

## What's in the box

- A single-node `kind` Kubernetes cluster, with Helm and the `bao` CLI 2.7.1 on your machine. The Helm repository `openbao` is already added.
- **OpenBao v2.7.1** in the namespace `openbao`: pods `openbao-0` to `openbao-2` on Integrated Storage, Shamir seal with one lab-only key share. The key (`unseal-key`) and root token (`root-token`) are in the Secret `openbao-init`. The StatefulSet uses the `OnDelete` update strategy.
- A KV version 2 engine at `secret/` with `secret/platform/marker` and `secret/payments/db` (`password=s3cr3t-from-before`).
- A `tester` pod with `curl` and `jq` in the namespace `clients`.

## Helpers

Paste these once in each new terminal. `bao_on` runs `bao` in one pod with the root token. `unseal` enters the lab-only key on one pod. `leader` prints the leader's pod name.

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
unseal() { bao_on "$1" operator unseal "$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"; }
leader() { bao_on openbao-0 operator raft list-peers -format=json | jq -r '.data.config.servers[] | select(.leader) | .node_id'; }
```

Use them like this: `bao_on "$(leader)" operator raft snapshot save /tmp/x.snap`, `unseal openbao-2`.

## Practice tasks

- Write the policy `snapshot-backup` with `read` on `sys/storage/raft/snapshot` and create an orphan, periodic token for it.
- Test the token from the `tester` pod: a snapshot request, a secret read and a restore request.
- Read the version history and the image of each pod with the commands from the planning part.
- Run the recovery drill: write a marker, snapshot, delete, restore and time it.
