# Solution: Repair A Transit Seal That Stopped Working

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks five things: every pod unsealed on Transit, a valid least-privilege seal token, the key name in the Helm values, a standby that unseals itself, and the original data.

## Step 1: Read the log of the sealed pod

```sh
kubectl -n openbao get pods
kubectl -n openbao logs openbao-2 | tail -30
```

`openbao-2` shows `0/1`. Its log reports errors from the Transit seal when it tries to decrypt the root key. Read them carefully: the unsealer refuses the request. The exact text depends on which fault it hits first.

## Step 2: Check the seal token at the unsealer

```sh
export UNSEALER_TOKEN=$(kubectl -n unsealer get secret unsealer-init -o jsonpath='{.data.root-token}' | base64 -d)
unsealer_bao() { kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$UNSEALER_TOKEN" bao "$@"; }
SEAL_TOKEN=$(kubectl -n openbao get secret transit-seal-token -o jsonpath='{.data.token}' | base64 -d)
unsealer_bao token lookup "$SEAL_TOKEN"
```

The lookup fails: the token was revoked during the clean-up. That is the first fault. `openbao-0` and `openbao-1` still run because they unsealed before the revocation; the seal's health check now logs warnings on them too, and they would fail on their next restart.

## Step 3: Check the seal configuration

```sh
kubectl -n openbao get configmap openbao-config -o jsonpath='{.data.extraconfig-from-values\.hcl}' | grep -A4 'seal "transit"'
unsealer_bao list transit/keys
```

The configuration names the key `auto-unseal`, but the key on the unsealer is `autounseal`. That is the second fault. Even with a valid token, `openbao-2` would ask for a key that does not exist, and the cluster's root key is encrypted with `autounseal` anyway.

## Step 4: Create a correct seal token

```sh
NEW_TOKEN=$(unsealer_bao token create -orphan -period=24h -policy=autounseal -field=token)
kubectl -n openbao create secret generic transit-seal-token --from-literal=token="$NEW_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
unsealer_bao token lookup "$NEW_TOKEN"
```

The lookup shows `orphan true`, `period 24h` and the policies `autounseal` and `default`. A pod reads the Secret only when it starts, so nothing changes yet.

## Step 5: Fix the key name in the Helm values

Get the current values, fix the key name and apply them:

```sh
helm get values openbao -n openbao > openbao-values.yaml
sed -i.bak 's/key_name   = "auto-unseal"/key_name   = "autounseal"/' openbao-values.yaml
grep key_name openbao-values.yaml
helm upgrade openbao openbao/openbao --version 0.30.4 -n openbao -f openbao-values.yaml
```

If Helm does not know the repository, add it with `helm repo add openbao https://openbao.github.io/openbao-helm`.

## Step 6: Restart the pods, one at a time

Start with the sealed pod, then the other standby, then step the leader down and restart it:

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
kubectl -n openbao delete pod openbao-2; sleep 30; bao_on openbao-2 status | grep Sealed
bao_on openbao-0 operator raft list-peers
```

`openbao-2` unseals itself with the new token and the right key. Repeat for the standby, then run `bao operator step-down` on the leader and restart it last. After each pod, wait for three voters.

## Step 7: Submit

```sh
bao_on openbao-0 kv get secret/platform/marker
astrona submit -c sections/section-020/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Put the unsealer's root token in `transit-seal-token` | It works, and anyone who can read that Secret controls the unsealer |
| Create the token without `-orphan` | It is revoked with its parent, and the next clean-up breaks the seal again |
| Create a new key called `auto-unseal` | The root key is encrypted with `autounseal`; a new key cannot decrypt it |
| Restart all pods at once | The cluster loses quorum while the pods come back |
