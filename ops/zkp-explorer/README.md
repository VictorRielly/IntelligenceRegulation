# Persistent ZKP efficiency explorer

**Sol agent selection, 2026-09-27 UTC:** Victor requests GPT-6 Sol for agents.
The launcher now passes `--model gpt-6-sol` and rereads PROMPT.md each cycle.
The account's local catalog lists that exact model. Fifteen control tests pass.
The idle supervisor was restarted; host health at 02:32:18 UTC confirms new
worker 1107851 alive and unpaused. Its retained next due time is 02:52:33 UTC;
no completed Sol research cycle is claimed yet. An inherited `stopped` status
label while waiting is not a dead-process finding; use host health.
The [CLI model flag](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
was also checked against the installed `codex exec --help`.

**Proactive research mandate, 2026-09-26:** Victor expects the researcher to
generate and investigate questions such as KV reuse and proof amortization
without waiting for user suggestions. The
[standing agenda](../../research/zkp-efficiency/AGENDA.md) requires ranked
hypotheses, tests that could disprove them, end-to-end cost accounting, and a
concrete next experiment each cycle. CLAUDE.md and active coordination require
this read for the existing worker, whose original launcher prompt is cached.
The updated PROMPT.md also includes it for future launches. The schedule
remains one bounded cycle per hour; this does not mean continuous GPU work.

Host health at **20:30:47 UTC** confirmed the unpaused supervisor alive and
idle after completed run `20260926T195233Z-cef0b7d6`, next due 20:52:33 UTC.
That cycle delivered a public pair-inverse-cache arithmetic candidate, whose
cited helper phase is under 0.6% of CPU proving time. Separate session
[KV research](../../research/zkp-efficiency/handoffs/20260926-kv-proof-state.md)
includes a synthetic counterexample to skipping masked future score checks.
Neither is a measured full-model speedup. The next scheduled cycle has not
yet acknowledged the new agenda; it is available through its required reads.

**Latest target clarification, 2026-09-26:** >=50 proved tokens/s on an RTX 5090
or another high-end GPU, with larger workloads allowed to amortize initialization
and initial prefill. The earlier 512/10.24 s wording below is a reference only.
The [research prompt](PROMPT.md) and
[authoritative target](../../docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md) carry
the amendment. Current workers also read the latest project decisions and
coordination on every cycle. Cycle `20260926T185233Z-aa002e55` completed its
NTT-layout study and proposed a source-derived pad-overlap repair; no native
or device speedup was measured.

**Resumed 2026-09-26:** Victor requested continuation toward an 8B forward-pass
proof at >=50 tokens/s. The prompt now carries that minimum (<=10.24 s over the
standing 512-token prefill window; five seconds remains a stretch objective).
The pause flag was cleared. A sandbox launch failed before a model turn with a
read-only filesystem error; host resume then succeeded, and the supervisor's
host identity was confirmed live again at 18:07 UTC. It is scheduled to retry
at 18:52:33 UTC under the existing hourly limit; resume is not a completed
research cycle. Evidence: `results/zk60_grouped_rounds_20260926/research-supervisor-health.json`.
The session research agent separately completed the
[forward-budget handoff](../../research/zkp-efficiency/handoffs/20260926-forward-budget-and-traffic.md).

Requested by Victor on 2026-09-22. This is an independent research lane for
the full private 8B attention-plus-FFN / five-second target. It does not replace
the implementation/integration queue. See [the cycle prompt](PROMPT.md).

**Operational, 2026-09-23:** the cron+bubblewrap backend is installed and its
first independent Codex cycle completed in 907 seconds with live web searches,
a new experiment and a handoff. Host process identity was confirmed after that
completion; the supervisor remained alive, idle until the next hourly cycle.
Fourteen supervisor/control tests pass. See the durable research
[state](../../research/zkp-efficiency/STATE.md) and
[first scheduled handoff](../../research/zkp-efficiency/handoffs/20260924-sc-szc-groups.md).

The supervised worker wakes once per hour, allows at most 20 minutes per cycle,
and checkpoints research to `research/zkp-efficiency/`. It reads STATE.md,
FINDINGS.md and sources.jsonl on every cycle; chat/session continuity is not
required. The installed Codex account and explicitly requested Sol model are used, so recurring
runs consume that account's usage allowance. No separate API key is created.

Research uses live native web search and original papers/repositories, followed
by one small differential experiment or a concrete negative finding. Experimental
artifacts remain separate from production; integration requires review.

The systemd user service stays in the background across Codex session closure,
restarts on supervisor failure, and starts with the user's systemd session.
It needs the host/WSL environment running, working Codex authentication and
network access. Without user lingering, systemd does not promise operation
after OS logout or before the next login. Turning off/suspending the computer
stops computation. Files survive; after startup, pending work resumes.

**Host fallback installed 2026-09-23, 19:44 PDT:** the user systemd bus was absent even
outside the Codex sandbox; installation stopped before writing a unit. A live
host cron daemon and `/usr/bin/bwrap` were confirmed. The explicit
`install-cron` alternative adds a marked, idempotent user crontab block with an
`@reboot` start and a five-minute watchdog. It launches the same single-worker
loop in a bubblewrap namespace, with the production tree read-only, only the
research/account/session/tmp directories writable, and no host GPU devices.
The watchdog never launches a second worker while the singleton lock is held.
It retains the prior crontab and verifies readback. Cron runs survive Codex
closure and resume after host boot; they still require the host/WSL and cron
daemon to run. This fallback uses nice/one-thread experiment settings and the
wall/log limits, but **does not claim the systemd cgroup CPU/memory ceilings**.
`runtime/installation.json` records the backend actually installed. Installation
and crontab readback succeeded; a host-side identity check confirmed the actual
supervisor process alive after its first cycle completed. The completed run is
`runtime/runs/20260924T024433Z-0c043a75/` (UTC date); the supervisor remained
alive with its next run scheduled for 03:44:33 UTC.

Controls and evidence:

- `python3 scripts/zk60_explorer.py status` reads recorded status; this alone
  does not prove a process is live.
- `systemctl --user status zk60-efficiency-explorer.service` checks liveness.
- `systemctl --user stop zk60-efficiency-explorer.service` stops the worker
  and its children. `disable --now` also stops startup at future logins.
- `systemctl --user start zk60-efficiency-explorer.service` resumes it.
- For the installed cron backend, run
  `python3 scripts/zk60_explorer.py health` on the host to check the recorded
  launcher start identity and its actual supervisor descendant. A separate
  process namespace may be unable to observe it; that is not evidence of death.
- `python3 scripts/zk60_explorer.py pause` on the host disables watchdog launches
  using a durable flag and signals only the identified supervisor; it stops its
  current child gracefully. `python3 scripts/zk60_explorer.py resume` clears
  the flag and starts the worker if absent. Neither alters unrelated cron jobs.
- `research/zkp-efficiency/runtime/runs/<id>/` records prompt, JSON events,
  stderr, final text, outcome, thread ID, usage and a terminal marker.
- Missing authentication, unavailable search or denied tools are failures or
  recorded research blockers, not successful research. Exit zero without a
  completed turn is not counted as a completed run. A completed model turn
  still requires reviewing its artifact claims; it is not proof of a speedup.

Safety/resource limits: one worker via flock; one experiment thread; 20-minute
cycle timeout; 32 MiB per-cycle tool-log cap; low scheduling priority; one CPU
quota and 3 GiB service memory ceiling. No GPU jobs. The systemd mount policy
makes the production project read-only while allowing the research directory,
Codex's normal account/session directory and `/tmp`. The child additionally
uses `workspace-write` and approval policy `never` (deny escalation, not approve
it), with live native search enabled. No sandbox-bypass flag or approval hook.
No PrivateTmp namespace: project build/heavy locks remain shared.

Install only after tests and unit review:

```
python3 -m unittest tests.test_zk60_explorer -v
python3 scripts/zk60_explorer.py render-unit
python3 scripts/zk60_explorer.py install
```

For the explicitly reviewed fallback: `python3 scripts/zk60_explorer.py install-cron`.

The systemd variant writes one user service outside the project and enables it; the
host's scoped approval is required in this managed workspace. The installer
refuses to overwrite an existing different unit or silently fall back to an
unsupervised process if systemd is unavailable. Presence of these files is not
evidence that installation succeeded.

Codex execution uses the documented [non-interactive interface](https://learn.chatgpt.com/docs/non-interactive-mode).
The CLI has no native Scheduled management interface; see
[official scheduled-task documentation](https://learn.chatgpt.com/docs/automations).
This service is a project-owned supervisor, not a claimed native Codex automation.
