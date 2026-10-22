# Monitor An OpenBao Cluster — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-117-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no task, no grading

A three-node OpenBao v2.7.1 cluster with Integrated Storage (Raft) for
exploring the module's topic. Built from the OpenBao 2.7 documentation and not
yet run (see the repository `CLAUDE.md`). The plumbing is generated: change
shared helpers in every environment.

## Run it

```sh
astrona run -c .
astrona destroy ats-117-playground-030-01
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition |
| `bootstrap/prepare.sh` | Tools, cluster and starting state |
| `manifests/` | Helm values and the tester pod |
| `docs/overview.md` | What the environment contains and ideas to try |
