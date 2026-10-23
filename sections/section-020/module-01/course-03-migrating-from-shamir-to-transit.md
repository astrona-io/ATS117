# Migrating From Shamir To Transit

A seal cannot be switched off and on like a setting. The root key must be re-encrypted with the new seal, and every node must agree on it. The OpenBao documentation gives a fixed order of steps for this, called seal migration. This part runs that migration on the cluster in your playground: standbys first, then the leader.

## The plan

Seal migration needs both seals during the migration: the old Shamir key shares and the new Transit key. It also needs a short window with brief downtime, and the documentation asks for a backup first. The steps for an Integrated Storage cluster are:

1. Change the configuration to add the new seal.
2. Restart one standby, and unseal it with `bao operator unseal -migrate` and the Shamir key shares. Repeat for each standby, one at a time.
3. Step the active node down. A standby with the new configuration becomes active and performs the migration.
4. Restart the old active node. It now auto-unseals with the new seal.

The Shamir key shares you enter with `-migrate` become the recovery keys of the new seal.

## Step 1: Add the seal to the Helm values

Set up the helpers and confirm the starting point:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
export SHAMIR_KEY=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft list-peers
```

Note which pod is the leader. Save this as `openbao-values-transit.yaml`. It is the cluster's current values with two additions, the `extraSecretEnvironmentVars` entry and the `seal "transit"` block:

```yaml
fullnameOverride: openbao
injector:
  enabled: false
server:
  # The chart allows one pod per node by default; the kind cluster has a
  # single node, so switch that off or openbao-1 and openbao-2 never start.
  affinity: ""
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
helm upgrade openbao openbao/openbao --version 0.30.4 -n openbao -f openbao-values-transit.yaml
```

Nothing restarts yet. The StatefulSet uses the `OnDelete` update strategy, so each pod keeps its old configuration until you delete it. If Helm does not know the repository `openbao`, add it first with `helm repo add openbao https://openbao.github.io/openbao-helm`.

## Step 2: Migrate the standbys

Take the first standby. In the commands below it is `openbao-1`; use a pod that is not the leader:

```sh
kubectl -n openbao delete pod openbao-1
kubectl -n openbao wait --for=jsonpath='{.status.containerStatuses[0].started}'=true pod/openbao-1 --timeout=180s
kubectl -n openbao exec -i openbao-1 -- env BAO_ADDR=http://127.0.0.1:8200 bao operator unseal -migrate "$SHAMIR_KEY"
```

The new pod starts with both seals in mind: its configuration says Transit, and its storage still says Shamir. The `-migrate` flag tells it that the key share is part of a migration. The pod unseals and rejoins as a standby. Check with `bao_on openbao-1 status`: the seal type now shows the migration in progress. Then do the same for the other standby, and wait until `list-peers` shows three voters before you go on.

## Step 3: Step the leader down

```sh
bao_on openbao-0 operator step-down
sleep 15
bao_on openbao-1 operator raft list-peers
```

Replace `openbao-0` with the leader's name if it is a different pod. One of the migrated standbys becomes active, and it performs the migration: it re-encrypts the root key with the Transit key and turns the Shamir shares into recovery keys. The information replicates to the other nodes through Raft. The pod's log reports the completed migration:

```sh
kubectl -n openbao logs openbao-1 | grep -i migrat
```

## Step 4: Restart the old leader

```sh
kubectl -n openbao delete pod openbao-0
sleep 30
bao_on openbao-0 status
```

This time you enter no key. The pod asks the unsealer for its root key and unseals itself. `bao status` shows `Seal Type transit`, `Recovery Seal Type shamir` and `Sealed false`. Every pod now uses the Transit seal. Delete any pod again and it comes back unsealed by itself.

You now know the full migration: values first, standbys with `-migrate` one at a time, step-down, and a restart of the old leader that auto-unseals. The cluster's availability now depends on the unsealer's.

## Common pitfalls

> [!WARNING]
> - **Restarting all pods at once.** Raft needs a quorum during the migration. One pod at a time, and wait for three voters in between.
> - **Forgetting `-migrate`.** Without it, the restarted standby refuses the Shamir key share because its configuration names a different seal.
> - **Migrating without a backup.** The documentation asks for a snapshot before you start, in case something goes wrong.
> - **Deleting the Shamir key shares afterwards.** They are now the recovery keys. Keep them as safely as before.

## Your mission: Migrate The Cluster From Shamir To Transit Auto-Unseal

You can now move a running cluster from Shamir to Transit without losing data. The graded lab gives you the same starting point and asks for the full migration, proven by a pod that unseals itself after a restart.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-117-playground-020-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-020/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-117-lab-020-01
astrona start ats-117-playground-020-01
```
