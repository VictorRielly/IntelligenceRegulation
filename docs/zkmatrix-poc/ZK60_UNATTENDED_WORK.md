# Keep the proof work moving while Victor is away

Victor's instruction, 2026-09-22: avoid day-long waits for approvals; prefer
building inside the sandbox or a simpler supported notification route.

## Immediate workflow

The active sandbox permits source/output edits in this repository and `/tmp`,
and offline CPU compilation/testing. It protects Git metadata and does not
provide the actual GPU route. Keep those boundaries; stop making a Git commit,
new worktree or unsandboxed CPU launcher a prerequisite for the next code change.

Use existing isolated checkouts. Preserve source hashes and exact reviewable
diffs; a source-pinned uncommitted validation candidate can be reviewed before
its later scoped commit. Build with the cached dependency graph, the shared
build lock and two jobs. Run foreground CPU commands with a yielded tool
session; poll the returned session id, not an outside process namespace.
For long suites, retain independent groups' logs and done markers so completed
work survives an interruption even if the current process does not.

GPU execution, publication and other boundary-crossing actions still need
the host's permission mechanism. Prepare them fully and batch narrow related
actions; keep independent CPU work moving until they can run. No claim of
device acceptance may be inferred from CPU tests.

## One host setting for the remaining approvals

Codex **Approve for me** sends eligible boundary-crossing requests to an
automatic reviewer while retaining the sandbox and its filesystem/network
limits. The installed CLI exposes `--approve-for-me`; the documented
configuration is `approval_policy = "on-request"` with
`approvals_reviewer = "auto_review"`. Managed requirements take precedence.
This is a host/UI setting and has **not** been changed by this repository edit.
It does not guarantee that every request is approved.

The existing phone-related hooks are configured in Claude's user settings;
there is no Codex hooks directory or notification configuration on this host.
Do not pretend those Claude hooks notify about Codex approvals. A separate
phone bridge is unnecessary for ordinary sandbox work and is not installed
by this change. For manual decisions, the official Remote workflow can surface
approvals in the ChatGPT mobile app once the host is connected.

Sources read on 2026-09-22:
[Auto-review](https://learn.chatgpt.com/docs/sandboxing/auto-review),
[Notifications](https://learn.chatgpt.com/docs/notifications), and
[Remote engineering from a phone](https://developers.openai.com/blog/mastering-codex-remote-for-engineering).

## Verification

The larger-block integration's detached baseline finished successfully before
this workflow change; its result is separate from the sandbox execution check.
The sandbox-only offline build/check below uses the isolated core prototype
under `/tmp/zk60-rounds-20260922` and needs no elevated execution or Git write.
Its evidence is recorded under `results/zk60_sandbox_workflow_20260922/`.

**Passed:** ordinary sandbox execution compiled the isolated core with
`cargo test --offline --locked`, two build jobs and the shared build lock.
All 50 unit tests and 2 integration tests passed. The retained source hashes
are unchanged, `run.done` is zero, and the command, source hashes and log hash
are in `validation.json`. No Git write, network access, GPU access or escalated
launcher was used. This checks the unattended CPU workflow, not proof speed.
