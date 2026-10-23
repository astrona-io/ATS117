# Solution: Migrate The Cluster From Shamir To Transit Auto-Unseal

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: every pod on the Transit seal and unsealed, a recovery seal, a standby that unseals itself after a restart, and the original data.

## Step 1: Set up and find the leader

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
export SHAMIR_KEY=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
```

The walkthrough below assumes `openbao-0` is the leader. If another pod is, swap the names.

## Step 2: Add the seal to the Helm values

Save this as `openbao-values-transit.yaml`:

```yaml
fullnameOverride: openbao
injector:
  enabled: false
server:
  # The chart allows one pod per node by default; the kind cluster has a
  # single node, so switch that off or openbao-1 and openbao-2 never start.
  affinity: ""
  # Create and replace pods without waiting for the one before to be Ready.
  # A sealed or migrating pod is never Ready, so with the chart's default,
  # OrderedReady, a restarted openbao-2 would wait for openbao-1 forever.
  # Kubernetes cannot change this on an existing StatefulSet, so every values
  # file sets it.
  podManagementPolicy: Parallel
  image:
    tag: "2.7.1"
  dataStorage:
    enabled: true
    size: 1Gi
  extraSecretEnvironmentVars:
    - envName: BAO_TOKEN
      secretName: transit-seal-token
      secretKey: token
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true
      config: |
        ui = true

        listener "tcp" {
          tls_disable     = 1
          address         = "[::]:8200"
          cluster_address = "[::]:8201"
        }

        storage "raft" {
          path = "/openbao/data"

          retry_join {
            leader_api_addr = "http://openbao-0.openbao-internal:8200"
          }
          retry_join {
            leader_api_addr = "http://openbao-1.openbao-internal:8200"
          }
          retry_join {
            leader_api_addr = "http://openbao-2.openbao-internal:8200"
          }
        }

        seal "transit" {
          address    = "http://unsealer.unsealer.svc.cluster.local:8200"
          key_name   = "autounseal"
          mount_path = "transit/"
        }

        service_registration "kubernetes" {}
ui:
  enabled: true
```

Apply it:

```sh
helm repo add openbao https://openbao.github.io/openbao-helm
helm upgrade openbao openbao/openbao --version 0.30.4 -n openbao -f openbao-values-transit.yaml
```

No pod restarts: the StatefulSet uses `OnDelete`.

## Step 3: Migrate the standbys, one at a time

```sh
for pod in openbao-1 openbao-2; do
  kubectl -n openbao delete pod "$pod"
  kubectl -n openbao wait --for=jsonpath='{.status.containerStatuses[0].started}'=true pod/"$pod" --timeout=180s
  kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 bao operator unseal -migrate "$SHAMIR_KEY"
  sleep 15
  bao_on openbao-0 operator raft list-peers
done
```

Each standby restarts with the Transit seal in its configuration and Shamir in its storage. The `-migrate` flag accepts the Shamir key share as part of the migration. Wait for three voters after each pod.

## Step 4: Step the leader down

```sh
bao_on openbao-0 operator step-down
sleep 15
bao_on openbao-1 operator raft list-peers
kubectl -n openbao logs openbao-1 | grep -i migrat
```

A migrated standby becomes active and performs the migration. Look at the log of whichever pod is now the leader.

## Step 5: Restart the old leader

```sh
kubectl -n openbao delete pod openbao-0
sleep 30
for pod in openbao-0 openbao-1 openbao-2; do bao_on "$pod" status | grep -E 'Seal Type|Recovery Seal|Sealed'; done
```

`openbao-0` unseals itself. All three pods show `Seal Type transit`, `Recovery Seal Type shamir` and `Sealed false`.

## Step 6: Prove it and submit

Delete a standby and watch it come back unsealed without a key:

```sh
kubectl -n openbao delete pod openbao-2
sleep 30
bao_on openbao-2 status | grep Sealed
bao_on openbao-0 kv get secret/platform/marker
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Common mistakes

- Restarting all three pods at once. During the migration the cluster still needs a quorum.
- Unsealing a migrated standby without `-migrate`. It refuses the Shamir key share.
- Putting the token in the `seal` block. It ends up in the ConfigMap `openbao-config`, readable by anyone who can read ConfigMaps.
- Initializing the cluster again to get a "clean" Transit cluster. The data is gone, and the grader checks for it.
