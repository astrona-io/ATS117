# Section 020: Auto-Unseal

With the Shamir seal, every OpenBao restart needs people. Someone must enter enough key shares before the server can decrypt its data. On Kubernetes, where pods restart for upgrades, node maintenance and rescheduling, that turns into an outage every time a pod moves.

Auto-unseal removes that step. OpenBao asks a key service to decrypt its root key at start, and the people who held key shares now hold recovery keys instead. This section shows which seals OpenBao 2.7 has built in and which come as plugins, sets up the Transit seal against a second OpenBao server, migrates a running cluster from Shamir to Transit, and repairs a Transit seal that stopped working.

## What you will learn

- What a seal protects, and the difference between unseal keys and recovery keys.
- The built-in seals (Shamir, Transit, static, KMIP) and the cloud seals that are plugins since v2.7.0.
- The Transit seal: the key, the policy and the orphan, periodic token it needs, and how the Helm chart passes the token.
- The documented seal migration steps, with `bao operator unseal -migrate`, standbys first and the leader last.

## The learning path

The module starts at its landing page, which also launches the playground: a three-node cluster on the Shamir seal, and a second OpenBao server, the unsealer, that serves the Transit key.

### 1. Unseal OpenBao Automatically

1. Seals, Auto-Unseal And Recovery Keys
2. The Transit Seal
3. Migrating From Shamir To Transit, followed by the lab **Migrate The Cluster From Shamir To Transit Auto-Unseal**
4. Summary

## Section capstone: Repair A Transit Seal That Stopped Working

A cluster that used Transit auto-unseal for months suddenly has a pod that will not unseal after a restart. Two things changed, and both must be fixed without re-initializing the cluster or weakening the seal's token. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-117-capstone-020
```
