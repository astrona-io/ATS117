# Scheduled Snapshots

A snapshot you take by hand is a snapshot you forget. A CronJob in the cluster takes one on a schedule, with the token from the previous part, and writes it to storage. This part reads such a CronJob, explains each choice in it, and covers retention and verification.

## The CronJob

A backup job needs three things: a way to reach the active node, the token, and a place to write the file. This manifest does it with a small `curl` image, and writes to a volume:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: openbao-snapshot
  namespace: openbao
spec:
  schedule: "0 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: snapshot
              image: curlimages/curl:8.11.1
              env:
                - name: BAO_TOKEN
                  valueFrom:
                    secretKeyRef:
                      name: snapshot-backup-token
                      key: token
              command: ["/bin/sh", "-c"]
              args:
                - |
                  set -eu
                  FILE=/backup/raft-$(date +%Y%m%d-%H%M%S).snap
                  curl -sf -H "X-Vault-Token: $BAO_TOKEN" -o "$FILE" \
                    http://openbao-active.openbao.svc.cluster.local:8200/v1/sys/storage/raft/snapshot
                  test -s "$FILE"
                  ls -l "$FILE"
              volumeMounts:
                - name: backup
                  mountPath: /backup
          volumes:
            - name: backup
              persistentVolumeClaim:
                claimName: openbao-backups
```

The settings that matter:

- `concurrencyPolicy: Forbid` stops a second job from starting while one still runs. Two snapshots at once only load the leader.
- `curl -sf` fails the job on an HTTP error, so a `403` from a bad token shows as a failed job and not as an empty file.
- `test -s` fails the job if the file is empty. A snapshot of zero bytes is not a backup.
- The Service `openbao-active` always points at the leader, so the job does not need to know which pod leads. A snapshot request to a standby is forwarded to the leader anyway.

## Where the file goes

The volume in the example is only the first step. A file on a volume in the same cluster is lost with the cluster. A production job copies the snapshot to storage outside it, such as object storage in another region, and applies a retention rule there. The tool for that step is the one your platform already uses; the important points are the same for all of them:

- The destination is in another failure domain than the cluster.
- The credentials for the destination can write but not delete old backups, so a compromised job cannot erase the history.
- The bucket or volume keeps the files for as long as the retention rule says, not for ever.

## Retention and frequency

Choose the frequency from the amount of data you can afford to lose. This amount is the recovery point objective (RPO). A job every hour means up to an hour of lost changes. Retention depends on how long a mistake can stay unnoticed: a deleted secret found after a month needs a snapshot from a month ago. A common pattern keeps hourly snapshots for a day, daily snapshots for a month and monthly snapshots for a year.

## Verify the backup

A job that exits with success proves that a file was written. It does not prove the file restores. Add one of these checks, and run it on a schedule of its own:

- Compare the size with the previous snapshot. A sudden drop or a size of a few bytes is a sign of a problem.
- Restore the latest snapshot into a throw-away cluster and read the marker secret. The next part shows how.

You now know how a CronJob takes snapshots with a least-privilege token, why the file must leave the cluster, and how to choose frequency and retention. A backup is only as good as its last restore, which is the subject of the next part.

## Common pitfalls

> [!WARNING]
> - **A backup volume in the same cluster.** The backup is lost with the cluster.
> - **A job without `curl -f`.** An error page from a `403` is saved as if it were a snapshot.
> - **Backup credentials that can delete.** A compromised job then erases the history.
> - **Never testing a restore.** A backup that was never restored is a hope, not a backup.
