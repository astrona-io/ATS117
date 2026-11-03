# Solution: Rotate The Transit Key Safely

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: the key has a new version, `min_decryption_version` is still 1, a restarted standby unseals itself, and the original data is still there.

## Step 1: Read the key before you change it

```sh
export UNSEALER_TOKEN=$(kubectl -n unsealer get secret unsealer-init -o jsonpath='{.data.root-token}' | base64 -d)
unsealer_bao() { kubectl -n unsealer exec -i unsealer-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$UNSEALER_TOKEN" bao "$@"; }
unsealer_bao read transit/keys/autounseal
```

Note `latest_version` (1) and `min_decryption_version` (1). The `keys` map has one entry.

## Step 2: Rotate the key

```sh
unsealer_bao write -f transit/keys/autounseal/rotate
unsealer_bao read transit/keys/autounseal
```

`latest_version` is now 2 and `min_decryption_version` is still 1. The keys map holds both versions. New encryption uses version 2, and version 1 stays available for what it already protects.

## Step 3: Leave min_decryption_version alone

Do not run `transit/keys/autounseal/config` with a higher `min_decryption_version`. The cluster's root key was encrypted with version 1 and is not re-encrypted by a rotation. If version 1 stops decrypting, the next pod that starts cannot unseal.

## Step 4: Restart the pods, standbys first

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
```

Pick a standby from the list, delete its pod and wait until the new container runs:

```sh
kubectl -n openbao delete pod openbao-2
sleep 30
bao_on openbao-2 status
```

The pod unseals itself (`Sealed false`). Repeat for the other standby. Last, step down the leader with `bao_on <leader> operator step-down`, then delete its pod the same way.

## Step 5: Check the result

```sh
bao_on openbao-0 operator raft autopilot state
bao_on openbao-0 kv get secret/platform/marker
```

Autopilot reports three healthy voters, and the marker secret is still there.
