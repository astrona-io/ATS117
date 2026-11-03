---
estimated_duration: 20m
---

# Create A Backup Token

- **ID:** LAB
- **Slug:** ats-117-lab-040-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for OpenBao. Read `question.md` for the task; `solution.md` is the walkthrough.
Built from the OpenBao 2.7 documentation and not yet run (see the repository `CLAUDE.md`).
The plumbing is generated: change shared helpers in every environment.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-117-lab-040-02
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | Tools, cluster and starting state |
| `manifests/` | Helm values, the tester pod and any extra objects |
| `solution/apply.sh` | Reference solution used by `astrona test` |
| `testing/wait-for-openbao.sh` | Waits until the starting state is ready |
| `validation/` | Grading scripts, one per check |
