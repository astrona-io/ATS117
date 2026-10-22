# ATS117 — Enterprise Operations, Auto-Unseal & HA Clusters (OpenBao)

Course material for the **Enterprise Operations, Auto-Unseal & HA Clusters**
domain of the Astrona OpenBao training path
([ATP022](https://github.com/astrona-io/ATP022)), which is **15% of the path**.
Written for **OpenBao v2.7.1** (Helm chart `openbao` 0.30.4).

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the OpenBao 2.7 documentation, the v2.7.1 source and the chart. None
> has been started on a cluster, and no lab has passed `astrona test` yet. See
> `CLAUDE.md` for the ranked list of what to check first.

The course opens with an Introduction in `sections/intro/`. Each section has a
module (landing page, parts, summary, playground, a graded lab right after the
part it tests) and a capstone.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | High Availability With Integrated Storage | 1 | 1 + capstone | Raft, quorum, autopilot |
| [020](sections/section-020) | Auto-Unseal | 1 | 1 + capstone | Transit, static seal, KMS plugins, seal migration |
| [030](sections/section-030) | Telemetry And Monitoring | 1 | 1 + capstone | Metrics, Prometheus, health endpoint |
| [040](sections/section-040) | Snapshots, Backup And Upgrades | 1 | 1 + capstone | Raft snapshots, restore, rolling upgrades |

The order follows the life of a production cluster: first make it highly
available, then take people out of the unseal step, then watch it, and last
protect its data and keep it current.

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Run OpenBao As A Raft Cluster](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Unseal OpenBao Automatically](sections/section-020/module-01/course.md) | 3 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Monitor An OpenBao Cluster](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |
| 040-01 | [Back Up, Restore And Upgrade OpenBao](sections/section-040/module-01/course.md) | 3 | [lab-01](sections/section-040/module-01/labs/lab-01) |

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Restore Quorum And Remove A Dead Peer | two sealed voters, a dead fourth peer, autopilot defaults |
| [020](sections/section-020/capstone/labs/lab-01) | Repair A Transit Seal That Stopped Working | a revoked seal token, a wrong key name |
| [030](sections/section-030/capstone/labs/lab-01) | Alert When A Node Is Sealed | one scrape target in the wrong format, no alert rule |
| [040](sections/section-040/capstone/labs/lab-01) | Upgrade The Cluster From 2.7.0 To 2.7.1 Safely | an upgrade that needs a snapshot first and a rolling restart |

## The lab environment

Every environment is a single-node **kind** cluster with a three-node OpenBao
cluster (StatefulSet `openbao`, Raft, `retry_join`, `OnDelete` updates), the
bao CLI and Helm on the machine, and a tester pod. Section 020 adds a second
OpenBao, the unsealer, that serves a Transit key and unseals itself with the
static seal. Section 030 adds Prometheus. The address everywhere is
`http://openbao.localtest.me:8200` (the Service `openbao-active`): CoreDNS
inside the cluster, a port-forward on the machine. Each environment needs
about 6 GiB of memory.

The environment plumbing (configuration, scripts, graders, manifests) is
generated from one shared shell library; see `CLAUDE.md`.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/<section>/<module>/playground
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```
