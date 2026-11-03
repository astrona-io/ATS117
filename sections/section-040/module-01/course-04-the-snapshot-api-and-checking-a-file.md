# The Snapshot API And Checking A File

The `bao operator raft snapshot` commands are wrappers around an HTTP API, and the API is what backup tools call. This part reads the three endpoints, then shows simple checks that tell a usable snapshot file from a broken one before the day you need it.

## The endpoints

| Request | What it does |
| --- | --- |
| `GET /v1/sys/storage/raft/snapshot` | Returns a snapshot of the cluster as the response body |
| `POST /v1/sys/storage/raft/snapshot` | Restores the snapshot in the request body into the cluster |
| `POST /v1/sys/storage/raft/snapshot-force` | Restores a snapshot from a different cluster, the same as `-force` in the command |

The commands are `bao operator raft snapshot save`, `restore` and `restore -force`. A standby that gets the request forwards it to the leader, so a client does not need to find the leader. The token needs `read` for the first request and `update` for the other two, on the path `sys/storage/raft/snapshot` or `sys/storage/raft/snapshot-force`.

## Taking a snapshot over HTTP

The `tester` pod has `curl`. Take a snapshot through the Service `openbao-active`, save it in the pod and look at its size:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
kubectl -n clients exec -i deploy/tester -- sh -c "curl -sf -H 'X-Vault-Token: $BAO_TOKEN' -o /tmp/api.snap http://openbao-active.openbao.svc.cluster.local:8200/v1/sys/storage/raft/snapshot && ls -l /tmp/api.snap"
```

The file has a size above zero. `curl -f` makes the command fail on an HTTP error; without it, a `403` page is saved into the file, and the file looks like a snapshot until someone tries to restore it.

## Checks that catch a bad file

A snapshot job can succeed and still leave a useless file. Four checks catch most problems:

1. **The size is above zero**, and close to the size of the previous snapshot. A sudden drop to a few hundred bytes means an error page or a truncated download.
2. **A checksum is stored next to the file.** Compute it when the file is created, with `sha256sum`, and compare it after every copy. A copy to object storage can fail halfway without an error in some tools.
3. **The file is binary, not text.** A snapshot is a compressed archive. A file that starts with the text `{"errors"` is an error response, and you can see that with `head -c 40`.
4. **A restore test passes on a schedule.** Restore the newest snapshot into a throw-away cluster and read the marker secret. Only this proves the file restores.

Try the second and third checks on the file you made:

```sh
kubectl -n clients exec -i deploy/tester -- sh -c "sha256sum /tmp/api.snap && head -c 40 /tmp/api.snap | od -c | head -3"
```

The checksum is a hexadecimal string. The first bytes are binary data, not readable text.

## Where checks belong

Put checks one and two inside the backup job, so a bad file fails the job and raises an alert at once. Run check four from a separate job, since it takes minutes and needs a second cluster. Record the result of each run, so you can show when the last good restore test happened.

You now know the snapshot API, why `curl -f` matters and which checks tell a good file from a bad one. This closes the module's reading. The next module automates these checks.

## Common pitfalls

> [!WARNING]
> - **Saving the response of a failed request.** Without `curl -f`, the error page is stored as a snapshot.
> - **Trusting a copy.** Compare a checksum after every copy.
> - **Using `snapshot-force` for a normal restore.** It skips the check that protects you from restoring the wrong file.
> - **Never running a restore test.** A file is a backup only once it has restored.
