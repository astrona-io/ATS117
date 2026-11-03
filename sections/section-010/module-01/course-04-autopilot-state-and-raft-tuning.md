# Autopilot State And Raft Tuning

A cluster can accept every request and still be one failure away from an outage. The only way to see that early is to read the cluster's own health report. This part reads the autopilot state field by field, explains the autopilot settings that decide when a node counts as healthy, and then looks at the Raft settings in the `storage` block that change how fast a failover happens.

## Reading the autopilot state

Autopilot is the part of Integrated Storage that tracks the health of every server. Its report is the most useful single command on a running cluster. Set up the helper and ask for the state:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
bao_on openbao-0 operator raft autopilot state
```

The first lines describe the cluster as a whole:

- `Healthy` is `true` when every voter is healthy.
- `Failure Tolerance` is how many voters can fail before the quorum is lost. With three healthy voters it is `1`.
- `Leader` is the node ID of the leader.
- `Voters` lists the node IDs that count toward the quorum.

Below that, each server has its own block. The fields that matter most are `Status` (`leader`, `voter` or `non-voter`), `Node Status` (`alive` when the leader has contact with the server), `Healthy`, `Last Contact` (how long ago the leader last heard from the server), `Last Term` and `Last Index` (the position of the server in the Raft log). A follower whose `Last Index` is far behind the leader's is slow, and autopilot will mark it unhealthy once it is more than a set number of entries behind.

The same report is available as JSON, which scripts and graders read:

```sh
bao_on openbao-0 operator raft autopilot state -format=json
```

Autopilot's report matters more than `kubectl get pods`. A pod can be `Running` and still be sealed, cut off from the leader, or far behind in the log. The state shows the cluster's own view.

## What decides that a server is healthy

Autopilot calls a server healthy when three things are true: the leader had contact with it recently, its log is close to the leader's log, and it has been in that state for a minimum time. Each condition has a setting. Read them all:

```sh
bao_on openbao-0 operator raft autopilot get-config
```

| Setting | Default | What it controls |
| --- | --- | --- |
| `last_contact_threshold` | 10s | How long the leader may go without contact with a server before the server is unhealthy |
| `max_trailing_logs` | 1000 | How many log entries a server may be behind the leader before it is unhealthy |
| `server_stabilization_time` | 10s | How long a new server must stay healthy before autopilot makes it a voter |
| `cleanup_dead_servers` | false | Whether autopilot removes servers that are dead |
| `dead_server_last_contact_threshold` | 24h | How long a server must be silent before autopilot calls it dead |
| `min_quorum` | 0 | The number of voters below which autopilot never removes a server |

Change them with `bao operator raft autopilot set-config`, which takes one flag per setting, for example `-last-contact-threshold=20s`, `-max-trailing-logs=2000` and `-server-stabilization-time=30s`. A longer `last_contact_threshold` fits a cluster whose nodes are far apart or whose network is slow, because it avoids marking a slow server unhealthy. A shorter `server_stabilization_time` promotes new servers sooner. Change one setting at a time and read the state again afterwards.

The same settings are available over HTTP at `sys/storage/raft/autopilot/configuration`, and the state at `sys/storage/raft/autopilot/state`. Monitoring systems use these paths.

## Raft settings in the storage block

Autopilot judges health. The Raft library underneath decides when an election starts. Both are tuned in different places: autopilot with `set-config`, Raft in the `storage "raft"` block of the server configuration, which changes only when a pod restarts. These are the settings that matter for operations:

| Setting | What it controls |
| --- | --- |
| `performance_multiplier` | Scales the Raft timeouts. A lower number detects a failed leader sooner and elects a new one sooner, but makes the cluster react to a slow disk or a slow network. A higher number is slower and more tolerant. The default is 5 |
| `trailing_logs` | How many log entries the leader keeps after a snapshot, so that a slightly late follower can catch up from the log instead of from a full snapshot |
| `snapshot_threshold` | How many log entries Raft collects before it takes an internal snapshot of its own |
| `max_entry_size` | The largest single entry, in bytes, that Raft accepts. A write bigger than this is refused |

These internal snapshots are not the backups you take with `bao operator raft snapshot save`. They let Raft shorten its own log. The default values suit most clusters. Lower `performance_multiplier` only after you have measured that your network and disks are fast and steady, because a value that is too low causes elections that nobody needed.

Your playground does not set any of them, so it runs on the defaults. A change goes into the Helm values under `server.ha.raft.config` and takes effect on each pod after you delete it, standbys first and the leader last.

You now know how to read the autopilot state, which three conditions make a server healthy, and which Raft settings change the speed of a failover. The settings give you control, but the habit matters more: read the failure tolerance before you change anything on the cluster.

## Common pitfalls

> [!WARNING]
> - **Trusting `kubectl get pods` for cluster health.** Only the autopilot state shows failure tolerance, lag and contact time.
> - **Lowering `performance_multiplier` to speed up failover.** On a slow disk it causes extra elections and short outages.
> - **Changing several autopilot settings at once.** You cannot tell which one changed the behaviour.
> - **Confusing internal Raft snapshots with backups.** `snapshot_threshold` has nothing to do with `bao operator raft snapshot save`.
