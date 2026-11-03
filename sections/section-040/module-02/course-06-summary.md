# Summary

This module turned the manual backup and upgrade steps of the first module into an operation: a safe identity for the job, a schedule, a disaster restore, an upgrade plan and drills.

## What you learned

A snapshot needs `read` on `sys/storage/raft/snapshot`, and a restore needs `update` on the same path. A backup job therefore gets a policy with `read` only and an orphan, periodic token that it renews. A CronJob takes snapshots with `curl -f`, rejects empty files, and copies the file to storage in another failure domain, with credentials that cannot delete old backups. Frequency follows the recovery point objective, and retention follows how long a mistake can stay unnoticed.

A disaster restore builds a new cluster, initializes it, restores with `-force` and unseals with the keys of the old cluster. The restore replaces tokens, leases and policies too, so clients need new tokens afterwards. An upgrade starts with release notes for every version in between, a test on a restored copy of the data and a snapshot taken immediately before. Rollback means restoring that snapshot. Runbooks and drills turn all of this into measured recovery numbers. The key facts to remember are these:

- Give the backup job `read` on the snapshot path and nothing else.
- Keep snapshots outside the cluster, and keep the keys somewhere else again.
- A restore replaces everything, including tokens and leases.
- Measure RPO and RTO in a drill.

<!-- astrona:playground:destroy -->
