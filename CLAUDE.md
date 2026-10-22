# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS117 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Enterprise Operations, Auto-Unseal & HA
  Clusters** domain of the **OpenBao** training path (`ATP022`). It is 15% of
  the path. There is no official OpenBao certification exam; the path's
  domains and weights are Astrona's own, set in `ATP022/path.yaml`.
- **What the domain really tests:** operating a production-shaped OpenBao
  cluster: join nodes to Integrated Storage, keep quorum, recover from a lost
  quorum, unseal automatically, migrate seals, scrape metrics, take and
  restore snapshots, and upgrade without losing data. Every fix is proved
  with the cluster's own state (`list-peers`, `seal-status`, metrics in
  Prometheus) and data that survived.
- **The four topics and sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | High Availability With Integrated Storage | Raft, quorum, autopilot |
  | 020 | Auto-Unseal | Transit, KMS plugins, static seal, seal migration |
  | 030 | Telemetry And Monitoring | Metrics, Prometheus, health endpoint |
  | 040 | Snapshots, Backup And Upgrades | Raft snapshots, restore, rolling upgrades |

- **Scope note:** the original domain description was cut off after
  "telemetry". The course covers Raft HA, Transit and KMS auto-unseal,
  telemetry, snapshots and backup, and upgrades.
- **The versions:** **OpenBao v2.7.1** (image `quay.io/openbao/openbao`, the
  `bao` CLI from the release archive), the `openbao` Helm chart **0.30.4**,
  Helm **3.22.1**, Prometheus **v3.15.1**, on a single-node `kind` cluster.
  The upgrade capstone starts on **2.7.0**. Do not teach fields, flags or
  output from other versions without saying so.
- **The main sources:** <https://openbao.org/docs/> and the source of
  `openbao/openbao` at tag `v2.7.1` (docs under `website/content/docs/`).

### Status: built, not yet run

The first version of this repository was written from the OpenBao 2.7
documentation, the v2.7.1 source and chart 0.30.4 **without a live run**. No
playground or lab has been started, and no `astrona test` has passed yet.
Until a maintainer runs them:

- Pages describe results in words. Do not add `text` output blocks until the
  output comes from a real run, and then paste it exactly.
- Treat every lab as unverified. Run `astrona validate` and `astrona test` on
  each one, one cluster at a time, before the course goes past `maturity:
  draft`.

Risks to check first, most likely first:

1. **Shamir joining with `retry_join`.** The design assumes a fresh pod with
   `retry_join` joins the cluster only after it is unsealed with the cluster's
   key, and that a restarted pod is sealed again. Every environment depends
   on this.
2. **Seal migration on Kubernetes.** The lab and `rolling_restart migrate`
   follow the documented steps (standbys get `unseal -migrate`, the leader
   steps down, the new active node migrates, the old leader auto-unseals).
   Unverified on this chart.
3. **Metrics on standbys.** The telemetry graders assume every pod, standbys
   included, serves `/v1/sys/metrics?format=prometheus` without a token when
   `unauthenticated_metrics_access = true`, and that a sealed pod stops
   answering (so `up == 0`). Metric names keep the `vault_` prefix
   (`vault_core_unsealed`), as the 2.7.1 metric reference shows; check this.
4. **Snapshot restore with Shamir.** The restore lab assumes the cluster stays
   unsealed after `bao operator raft snapshot restore` because the snapshot
   was taken with the same keys (no `-force`).
5. **`bao status -format=json` fields** used by graders: `type`, `sealed`,
   `recovery_seal`, `version`, `leader_address`; and `list-peers -format=json`
   with `node_id`, `leader` and `voter` per server.
6. **Version history.** Nothing grades `sys/version-history`; pages mention it
   in words only.

### Terms, not metaphors

| Term | First-use definition (example wording) |
| --- | --- |
| Integrated Storage (Raft) | OpenBao's built-in storage backend; every node keeps a full copy of the data and the nodes agree on changes with the Raft consensus protocol |
| Leader / follower | The node that accepts writes and replicates them / the nodes that copy them; in OpenBao the leader is also the active node and the followers are standbys |
| Voter / non-voter | A node that counts toward quorum and can become leader / a node that copies data but does not vote |
| Quorum | The majority of voters, `(voters / 2) + 1`, that must agree before a write is committed; 3 voters tolerate 1 failure |
| `retry_join` | A `storage "raft"` block that tells a node which addresses to try when it joins the cluster |
| Autopilot | The part of Integrated Storage that watches node health, promotes new nodes to voters and can remove dead servers |
| Standby read | Since v2.5.0 a standby answers requests that do not write, similar to Vault Enterprise performance standbys; turned off with `disable_standby_reads` |
| Request forwarding | A standby sends write requests to the active node over the cluster port `8201` |
| Seal / auto-unseal | The mechanism that protects the root key; auto-unseal asks a key service to decrypt it at start, so no person enters key shares |
| Recovery keys | With auto-unseal, the key shares created by `bao operator init`; they authorize operations such as generating a root token, but cannot unseal |
| Transit seal | An auto-unseal that uses the Transit secrets engine of another OpenBao server |
| Static seal | An auto-unseal that uses a 32-byte key from the configuration, an environment variable or a file |
| KMS plugin | Since v2.7.0 the cloud seals (`awskms`, `gcpckms`, `azurekeyvault`, `ocikms`, `alicloudkms`, `pkcs11` and others) are external plugins registered with a `plugin "kms"` block; `transit`, `static`, `kmip` and Shamir are built in |
| Seal migration | Moving a cluster from one seal to another with `bao operator unseal -migrate` |
| Telemetry | The `telemetry` stanza that makes OpenBao keep metrics; `/v1/sys/metrics?format=prometheus` serves them |
| Raft snapshot | A point-in-time copy of all Raft data, saved and restored with `bao operator raft snapshot` |

### The example workloads

| Name | What it is |
| --- | --- |
| OpenBao (namespace `openbao`, release `openbao`) | StatefulSet `openbao`, pods `openbao-0`, `openbao-1`, `openbao-2`, Raft on 1 GiB volumes, `retry_join` to all three through `openbao-internal`, node IDs = pod names, `service_registration "kubernetes"` so the Service `openbao-active` selects the leader. No TLS (lab-only). Update strategy `OnDelete` (chart default) |
| Secret `openbao-init` | The lab-only key share (`unseal-key`; a recovery key when the cluster uses auto-unseal) and the root token (`root-token`). Say on the page that a real installation never keeps these in a Kubernetes Secret |
| Unsealer (namespace `unsealer`, release `unsealer`, pod `unsealer-0`) | Section 020 only. A single-node OpenBao with the Transit engine at `transit/` and the key `autounseal`; it unseals itself with the `static` seal (key in the Secret `unsealer-static-key`, generated at start). Its root token is in `unsealer-init`. The policy `autounseal` allows `update` on `transit/encrypt/autounseal` and `transit/decrypt/autounseal` |
| Secret `transit-seal-token` (namespace `openbao`) | An orphan, periodic (24h) token with the policy `autounseal`; the chart passes it to the pods as `BAO_TOKEN` |
| Prometheus (namespace `monitoring`) | Section 030 only. `prom/prometheus:v3.15.1`, ConfigMaps `prometheus-config` and `prometheus-rules` |
| `tester` (namespace `clients`) | `nicolaka/netshoot:v0.13` with `curl` and `jq` |
| `secret/platform/marker` | A KV v2 secret written at start; graders read it to prove the cluster was not re-initialized |

### Environment facts the text must respect

- **One address everywhere: `http://openbao.localtest.me:8200`**, the
  Service `openbao-active`. Inside the cluster a CoreDNS `rewrite stop` block
  (answer name rewritten back) sends the name there; on the reader's machine
  `kubectl -n openbao port-forward svc/openbao-active 8200:8200` does. A
  port-forward follows one pod: when the leader changes, start it again.
  Never use the one-line `rewrite name` form.
- **Per-pod commands run inside the pod.** Pages define, once per page:

  ```sh
  export BAO_TOKEN=$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)
  bao_on() { pod=$1; shift; kubectl -n openbao exec -i "$pod" -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$BAO_TOKEN" bao "$@"; }
  ```

  `BAO_TOKEN` is passed explicitly because pods that use the Transit seal
  carry the seal's token in their own `BAO_TOKEN`.
- **`OnDelete` means nothing restarts by itself.** After `helm upgrade`, the
  reader deletes pods one at a time: standbys first, then `bao operator
  step-down` on the leader, then the old leader.
- **Shamir means every restarted pod is sealed.** Pages show the unseal step
  after every restart until the cluster uses auto-unseal.
- **The plumbing is generated.** `config.yaml`, author READMEs,
  `prerequisites.md`, `bootstrap/`, `testing/`, `solution/apply.sh`,
  `validation/` and `manifests/` of every environment come from a generator
  outside the repository with one shared shell library inlined in every
  script. When a shared helper changes, change it in every script.

### Lab metadata in `astrona.yaml`

`training:` block: id `ATS117`, domain `Enterprise Operations, Auto-Unseal &
HA Clusters`, weight `15`. Lab entries carry `title`, `path`, `difficulty`,
`estimated_duration`, `topic`, `task_kind`, `tags`, `learning_goals`,
`resources`, in that order, as in ATS016.

- `topic`: exactly one of `high-availability`, `auto-unseal`, `telemetry`,
  `backup`, `upgrades`.
- `task_kind`: `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8, only from this list: `raft`, `quorum`, `retry-join`,
  `list-peers`, `remove-peer`, `autopilot`, `step-down`, `standby`,
  `transit-seal`, `static-seal`, `kms-plugin`, `recovery-keys`,
  `seal-migration`, `periodic-token`, `telemetry`, `prometheus`, `metrics`,
  `alerting`, `health-endpoint`, `raft-snapshot`, `restore`,
  `rolling-upgrade`, `helm-chart`, `ondelete`.
- `resources`: 1 to 4 pages on `openbao.org`.

### Running things

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-010/module-01/playground
astrona destroy ats-117-playground-010-01
astrona run --git ssh://git@github.com/astrona-io/ATS117.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-117-lab-010-01
astrona test -c sections/section-010/module-01/labs/lab-01   # authors
```

Names: `ats-117-playground-<section>-<module>`, `ats-117-lab-<section>-<module>`,
`ats-117-capstone-<section>`. Graders check **behaviour** (voters in
`list-peers`, a write accepted after the leader is lost, a pod that unseals
itself after a restart, metrics in Prometheus, an alert that fires, a secret
that came back) and reject the plausible but wrong fix (re-initializing the
cluster, a seal token with the `root` policy, restoring a snapshot and losing
later changes, upgrading before taking a snapshot). A lab's `question.md` and
`solution.md` must match what its `validation/` scripts check. Each
environment needs about 6 GiB; run one at a time.

### Where to find trusted sources

- **HA and Raft:** <https://openbao.org/docs/concepts/ha/>,
  <https://openbao.org/docs/concepts/integrated-storage/>,
  <https://openbao.org/docs/concepts/integrated-storage/autopilot/>,
  <https://openbao.org/docs/commands/operator/raft/>
- **Seals:** <https://openbao.org/docs/concepts/seal/>,
  <https://openbao.org/docs/configuration/seal/> (transit, static, and the
  KMS plugin pages)
- **Telemetry:** <https://openbao.org/docs/configuration/telemetry/>,
  <https://openbao.org/docs/internals/telemetry/>,
  <https://openbao.org/docs/api/system/health/>
- **Kubernetes:** <https://openbao.org/docs/platform/k8s/helm/>
