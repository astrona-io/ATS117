# Summary

This module added the sources of evidence an operator needs beside the first metrics: the server log, the audit log, the health endpoint, the metrics of the Raft cluster and alert rules.

## What you learned

Each node writes its own operational log. `log_level` and `log_format` set its detail, and `bao monitor` streams a node's log at a level you choose, without a restart. The audit log records the requests of clients, with secret values replaced by salted hashes. It is written by the audit devices, and if every device fails, the server refuses requests. A production cluster therefore enables at least two.

The health endpoint answers `200` for the active node, `429` for a standby, `501` when not initialized and `503` when sealed; query parameters change the codes for load balancers and probes. Metrics show trends: `vault_autopilot_failure_tolerance` warns before a failure becomes an outage, `vault_expire_num_leases` shows lease growth, and the audit failure counters show a failing device. Alert rules turn these into notifications; `up` covers the node that is gone. The key facts to remember are these:

- Read the log of the leader first, and use `bao monitor` for a short debug session.
- Enable more than one audit device and alert on audit failures.
- Do not use the health code of one node for monitoring.
- Test every alert rule by causing the condition once.

<!-- astrona:playground:destroy -->
