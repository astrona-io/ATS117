# Planning An Upgrade

The rolling upgrade steps are short. The planning around them is what prevents the bad day. This part covers how to read release notes, how to test an upgrade on a copy of your data, and what rollback means for a storage that moves forward.

## Read before you move

Each OpenBao release has release notes and, between larger versions, an upgrade guide. Read the entries for every version between the one you run and the one you want, not only the target. Look for three kinds of change: removed or renamed configuration fields, changed defaults, and changes to storage or API behaviour. A field you use that is now removed stops the server from starting.

Record the current state first:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 status
bao_on openbao-0 list sys/version-history
kubectl -n openbao get pods -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}'
helm list -n openbao
```

The output is the starting point of the change record: the version each pod runs, the versions the cluster has seen, and the chart release.

## One step at a time

Move one minor version at a time unless the release notes say that a jump is supported. Each step is a full cycle: snapshot, rolling restart, checks. A cluster that went through a series of small steps is easier to debug than one that jumped three versions and shows a failure.

## Test on a copy

The best test of an upgrade uses your own data. Restore the latest snapshot into a throw-away cluster, as the previous part described, but start that cluster on the new version. Then check:

- The server starts and unseals with your configuration.
- The data reads back, including the marker secret.
- The auth methods and secrets engines you use still answer.
- Your own checks pass, such as a login from an application's role.

If the new version fails on a copy, you learned that without any outage. Fix the configuration or wait for a patch release.

## What rollback means

A snapshot is the path back. Rolling the image tag back to the old version on a cluster that has already written data in a newer format may not work, because storage can move forward. The safe rollback is to restore the snapshot from before the upgrade into a cluster of the old version. This replaces everything written since, as any restore does, so the window for a rollback is short. Decide before the upgrade how long you wait before you call it successful, and write that time in the plan.

## The plan on one page

A good upgrade plan fits on one page and has these lines:

1. The versions: from, to, and the steps between.
2. The release-notes findings that apply to this cluster.
3. The snapshot taken immediately before, with its file name.
4. The order of pods and the checks after each one.
5. The success criteria and the time until the rollback window closes.
6. Who does it, who watches the metrics, and who decides on a rollback.

You now know how to read release notes, test an upgrade on a copy of your data and why a snapshot, not an image tag, is the way back. The last part joins backup and upgrade into practice.

## Common pitfalls

> [!WARNING]
> - **Reading only the notes of the target version.** A field removed three versions ago is still removed.
> - **Upgrading production first.** Test on a restored copy of the data.
> - **Planning rollback as an image change.** Storage may have moved forward; plan a restore.
> - **No snapshot immediately before the change.** The last scheduled one may be hours old.
