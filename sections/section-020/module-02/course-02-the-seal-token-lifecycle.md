# The Seal Token Lifecycle

The Transit seal does not authenticate with a password. The main cluster presents a token to the unsealer each time a pod starts. When that token expires or is revoked, nothing breaks while the pods run, and every restart fails. This part reads the token's properties, explains why it is periodic and orphaned, and shows what a revocation looks like.

## What the token is

The token lives in the Secret `transit-seal-token` in the namespace `openbao`, and the chart passes it to the pods in the environment variable `BAO_TOKEN`. The token is an **orphan** token (it has no parent, so revoking some other token does not revoke it) and a **periodic** token (it has no maximum lifetime and stays valid as long as it is renewed within its period). Look at it on the unsealer:

<!-- astrona:playground:renew -->

```sh
export UNSEALER_TOKEN=$(kubectl -n unsealer get secret unsealer-init -o jsonpath='{.data.root-token}' | base64 -d)
unsealer_bao() { kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$UNSEALER_TOKEN" bao "$@"; }
SEAL_TOKEN=$(kubectl -n openbao get secret transit-seal-token -o jsonpath='{.data.token}' | base64 -d)
unsealer_bao token lookup "$SEAL_TOKEN"
```

The fields to read are `policies` (the policy `autounseal`, plus `default`), `orphan` (`true`), `period` (24 hours) and `ttl` (the time left until it must be renewed). The seal renews the token by itself while the cluster runs, so a healthy cluster keeps its token alive.

## The policy

The token needs two permissions and no more: `update` on `transit/encrypt/autounseal` and `update` on `transit/decrypt/autounseal`. Check the policy:

```sh
unsealer_bao policy read autounseal
```

A seal token with the `root` policy would work too, and it is a serious mistake: anyone who reads the Secret then owns the unsealer. Give the token only the policy for the key it uses.

## When the token stops working

Three events make the token useless: someone revokes it, it expires because nothing renewed it for longer than the period (for example a cluster that was shut down for days), or the policy loses a path. The running pods do not notice, because they are already unsealed. A pod that restarts logs a permission error from the unsealer and stays sealed.

Check what a pod would see by asking the unsealer with the token itself:

```sh
kubectl -n clients exec -i deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' \
  -H "X-Vault-Token: $SEAL_TOKEN" -X POST -d '{"plaintext":"dGVzdA=="}' \
  http://unsealer.unsealer.svc.cluster.local:8200/v1/transit/encrypt/autounseal
```

Status `200` means the token and the key work. Status `403` means the token or its policy is wrong. Status `400` with a message about the key means the key name in the request is not found.

To repair a revoked token, create a new orphan periodic token with the same policy on the unsealer, put it in the Secret, and restart the pods one at a time:

```sh
unsealer_bao token create -orphan -period=24h -policy=autounseal -field=token
```

Copy the value into the Secret `transit-seal-token` and delete the pods in turn. Do this before the next restart, not after a pod is stuck: a stuck pod can still be repaired, but only with a working token.

You now know the properties of the seal token, why it carries a narrow policy, and how to test and replace it. The next part looks at what you hold when everything goes wrong: the recovery keys.

## Common pitfalls

> [!WARNING]
> - **Giving the seal token the `root` policy.** The Secret that holds it becomes the key to the unsealer.
> - **A non-orphan token.** When its parent token is revoked, it is revoked too.
> - **A token with a fixed expiry.** It dies after its time-to-live, and the next restart fails.
> - **Finding out only at the next restart.** Test the token with a request to the encrypt path after every change.
