# Automate Backups And Plan Upgrades

A snapshot taken by hand protects you until the person who takes it is on holiday. A restore tried for the first time during an incident takes much longer than one practiced. This module makes backups, restores and upgrades routine.

Keep one sentence in mind: **a backup job must be able to take a snapshot and nothing else, and a restore plan is real only after you have timed it.** The module builds the identity of the job, the schedule, the disaster restore, the upgrade plan and the drill.

The module has five parts. **A Least-Privilege Backup Token** writes the policy and creates an orphan, periodic token for the job; a graded lab follows it. **Scheduled Snapshots** reads a CronJob and explains retention. **Restoring Into A New Cluster** walks through a disaster restore. **Planning An Upgrade** covers release notes, a test on a copy, and rollback. **Drills And Runbooks** sets recovery targets and describes a drill.

## Learning objectives

After this module you can:

- Write a policy that allows a snapshot and not a restore, and create an orphan, periodic token for a backup job.
- Test what a token can and cannot do from a client pod.
- Read and design a CronJob that takes snapshots safely.
- Choose frequency and retention from the recovery point objective.
- Restore a snapshot into a new cluster and list the checks that prove it worked.
- Plan an upgrade with release notes, a test on a copy and a rollback by restore.
- Write a runbook and run a recovery drill.

## Before you start

You need to know how to save and restore a snapshot and how a rolling upgrade works from the first module of this section. You need `kubectl`, a little `curl`, and tokens and policies in OpenBao.

Your playground has a three-node OpenBao cluster in the namespace `openbao` (pods `openbao-0` to `openbao-2`, Shamir seal, key and root token in the Secret `openbao-init`) with a KV version 2 engine at `secret/` and the secrets `secret/platform/marker` and `secret/payments/db`, and a `tester` pod in the namespace `clients` with `curl`. Real installations never keep the key share or root token in a Kubernetes Secret.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
