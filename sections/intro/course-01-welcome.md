# Welcome To The Course

This course trains you for the **Enterprise Operations, Auto-Unseal & HA Clusters** part of the Astrona **OpenBao** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: StatefulSets, pods, Services, Secrets, ConfigMaps, `kubectl exec` and `helm upgrade`. You have used OpenBao before: you can set `BAO_ADDR` and `BAO_TOKEN`, write and read a secret with `bao kv`, and you know what sealed and unsealed mean. You do not need to have run OpenBao as a cluster. Each new idea is explained the first time it appears.

## What you can do at the end

Running OpenBao for real means keeping it available, unsealed, watched and backed up. This course asks you to do each of those things on a live cluster and prove the result. It has four topics, and each one turns into a set of skills you will practise.

The first topic is **high availability with Integrated Storage**. You will learn to:

- Explain Raft, voters and quorum, and how many node failures a cluster survives.
- Join nodes with `retry_join`, read `list-peers` and the autopilot state, and configure autopilot.
- Recover a cluster that lost quorum and remove a dead peer.

The second topic is **auto-unseal**. You will learn to:

- Explain the difference between unseal keys and recovery keys.
- Configure the Transit seal against a second OpenBao server, and know when the static seal or a KMS plugin fits.
- Migrate a running cluster from Shamir to Transit, and repair a seal that stopped working.

The third topic is **telemetry and monitoring**. You will learn to:

- Turn on telemetry and the metrics endpoint, and scrape every node with Prometheus.
- Pick the metrics that matter and alert when a node is sealed.
- Use the health endpoint for load balancers.

The fourth topic is **snapshots, backup and upgrades**. You will learn to:

- Save and restore Raft snapshots, and know what a restore rolls back.
- Upgrade a cluster pod by pod without losing quorum.

Everything is written for **OpenBao v2.7.1**.

## The words this course uses

The pages use OpenBao's, Raft's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

**Integrated Storage** is OpenBao's built-in storage. Every node keeps a full copy of the data, and the nodes agree on every change with the **Raft** consensus protocol. One node is the **leader**: it accepts writes and is OpenBao's **active node**. The others are **standbys**. A **voter** is a node that counts toward **quorum**, the majority that must agree before a write is committed.

A **seal** protects the key that decrypts OpenBao's data:

| Seal | How OpenBao gets its key at start |
| --- | --- |
| Shamir | People enter enough key shares with `bao operator unseal` |
| Transit | OpenBao asks another OpenBao server's Transit engine to decrypt it |
| Static | OpenBao reads a 32-byte key from its configuration, an environment variable or a file |
| KMS plugin | OpenBao asks a cloud key service, through a plugin |

## The example setup in your playground

Every playground and lab runs the same setup. A StatefulSet called `openbao` runs three pods, `openbao-0`, `openbao-1` and `openbao-2`, in the namespace `openbao`. They form one cluster on Integrated Storage. The Service `openbao-active` always points at the leader. A `tester` pod with `curl` and `jq` sends requests from inside the cluster.

In the auto-unseal section, a second OpenBao server called the unsealer runs in the namespace `unsealer`. In the monitoring section, Prometheus runs in the namespace `monitoring`. Many labs start with something broken on purpose. That is the material, not a fault in the course.

## How the course is laid out

The course has four sections, in the order you meet these tasks when you run a cluster in production.

| Section | What it covers |
| --- | --- |
| 010 | High Availability With Integrated Storage |
| 020 | Auto-Unseal |
| 030 | Telemetry And Monitoring |
| 040 | Snapshots, Backup And Upgrades |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
