# Drills And Runbooks

Backups, restores and upgrades fail in the same way: the first time a person tries them is during an incident. A runbook and a drill replace that first time with a practiced one. This part defines the targets, shows what a runbook holds and describes a drill you can repeat.

## Two numbers

Every recovery plan starts with two numbers that the business agrees to:

- **Recovery point objective (RPO):** how much data may be lost. It sets the snapshot frequency. An RPO of one hour needs a snapshot at least every hour.
- **Recovery time objective (RTO):** how long the cluster may be unavailable. It sets how much you automate. A restore into a new cluster takes minutes if scripted and hours if written on a wiki that nobody has read.

Measure both in a drill. A number that was never measured is a guess.

## What a runbook holds

A runbook is for a tired person at night. It lists steps, not explanations, and each step has a check. For OpenBao, write one runbook per event:

| Event | Contents |
| --- | --- |
| A node is sealed or lost | How to find it, how to unseal, how to remove a dead peer, the failure tolerance check |
| Data deleted by mistake | Where the snapshots are, how to restore into a side cluster and copy the data back |
| Cluster lost | The disaster restore: where the keys are, the order of the steps, the checks |
| Seal key service lost | Which backups of the key exist, who can restore the key, what to do for a pod that stays sealed |
| Planned upgrade | The one-page plan from the previous part |

Each runbook names the people and systems it needs: who holds the key shares, where the snapshots are, who can approve an emergency. If a step needs a secret that is stored in OpenBao, the runbook fails exactly when you need it. Keep the break-glass material elsewhere.

## A drill you can repeat

Run this in the playground, or in a staging cluster, every quarter:

1. Write a marker value to a new secret, and note the time.
2. Take a snapshot and move it out of the cluster.
3. Delete the secret and a policy, as a mistake would.
4. Restore the snapshot into the cluster. Time the restore.
5. Read the marker. Check that the policy is back.
6. Write down what was unclear, slow or missing in the runbook, and fix the runbook.

A second drill is the disaster restore: build a new cluster in a new namespace, restore into it, and unseal with the old keys. The result is a measured RTO and a list of changes to the runbook.

## After the drill

Treat a drill like a test run. A step that failed is a bug in the runbook or in the setup, and the fix goes in the same week. Record the date, the RPO and RTO you measured, and what changed. Over a year, this record is what tells an auditor that your backups work.

You now know how to set recovery targets, what a runbook for OpenBao holds and how a drill produces measured numbers. This closes the module.

## Common pitfalls

> [!WARNING]
> - **A runbook that depends on the cluster it recovers.** Keep break-glass material outside OpenBao.
> - **Targets nobody measured.** Run a drill and write down the real numbers.
> - **A drill that skips the keys.** The part that fails in a real disaster is finding them.
> - **Fixing problems in your head.** Update the runbook the day of the drill.
