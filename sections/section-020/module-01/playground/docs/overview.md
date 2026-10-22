# Overview: Unseal OpenBao Automatically (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs a three-node OpenBao cluster on the Shamir seal and a second OpenBao server that serves a Transit key, and then waits. There is no task, no `astrona submit` and no pass or fail.

## What's in the box

- A single-node `kind` Kubernetes cluster, with Helm and the `bao` CLI 2.7.1 on your machine.
- **The cluster** in the namespace `openbao`: pods `openbao-0` to `openbao-2` on Integrated Storage, Shamir seal with one lab-only key share. The key (`unseal-key`) and root token (`root-token`) are in the Secret `openbao-init`. The StatefulSet uses the `OnDelete` update strategy.
- **The unsealer** in the namespace `unsealer`: one pod, `unsealer-0`, with the Transit engine at `transit/`, the key `autounseal` and the policy `autounseal` (update on `transit/encrypt/autounseal` and `transit/decrypt/autounseal`). It unseals itself with the static seal; its 32-byte key was generated when the playground started and is in the Secret `unsealer-static-key`. Its root token is in `unsealer-init`.
- The Secret `transit-seal-token` in the namespace `openbao`: an orphan token with a 24-hour period and the policy `autounseal`.
- A KV version 2 engine at `secret/` with `secret/platform/marker`, and a `tester` pod in the namespace `clients`.

Real installations keep none of these keys or tokens in Kubernetes Secrets.

## Helpers

Paste these once in each new terminal. `bao_on` runs `bao` in one cluster pod with the root token; `unsealer_bao` does the same on the unsealer.

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
export SHAMIR_KEY=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)
export UNSEALER_TOKEN=$(kubectl -n unsealer get secret unsealer-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
unsealer_bao() { kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$UNSEALER_TOKEN" bao "$@"; }
```

Use them like this: `bao_on openbao-0 status`, `unsealer_bao read transit/keys/autounseal`.

## Practice tasks

- Compare `bao_on openbao-0 status` with the unsealer's status. Find the lines that differ between a Shamir seal and an auto-unseal seal.
- Look up the seal token with `unsealer_bao token lookup` and check that it is orphan and periodic. Create a second token without `-orphan` and compare.
- Use the seal token yourself: run `unsealer_bao` with `BAO_TOKEN` set to it, and try to read `transit/keys/autounseal`. Explain the result from the policy.
- Run the full migration from the module, then delete each pod once and watch it unseal itself.
- After the migration, stop the unsealer with `kubectl -n unsealer scale statefulset unsealer --replicas=0`, delete one cluster pod, and read its log. Scale the unsealer back to one replica and watch the pod recover.
