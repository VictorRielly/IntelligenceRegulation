# IntelligenceRegulation — project instructions

**New to the project? Read `docs/zkmatrix-poc/START_HERE.md` first**
(plain words: what is built, the measured numbers, why the speed goal
is hard, the open choices, the rules, a glossary).

**The repository is PUBLIC, and all work is open source (D62, Victor 2026-11-04).** Every commit on
every pushed branch is world-readable, history included. Before any commit (Claude, Sol, Astra, any agent):
- no credentials, keys, tokens, salts, openings or owner-private values;
- no personal data: phone numbers, home addresses, CVs, references' contacts, employment details;
- no funding applications or business plans. These live outside the repository, and `.gitignore` refuses
  `results/zk60_funding_*/` and `cv/`;
- no model weights (pin and fetch instead).

Stage named paths, never `git add -A` / `git add .` in the main checkout. **Production rule (D63):** no ZKP goes
into production before its two Lean statements are proved
(`docs/zkmatrix-poc/ZK60_LEAN_PRODUCTION_STATEMENTS.md`, proposed, awaiting Victor's approval). The
latency work does not wait for it.

**Machine change, 2026-10-31 (Victor): work continues on the M3 Ultra Mac
Studio** (macOS arm64, 256 GB unified memory, 32 CPU cores, 80-core GPU)
until the RTX 5090 box is up; the WSL laptop is no longer reachable. Read
`docs/zkmatrix-poc/ZK60_MAC_BRINGUP_20261031.md` before any build, proof or
lane launch. In short:
- The repo is `/Users/victorrielly/IntelligenceRegulation`. Every
  `/home/victor/...` path below and in older docs/scripts means the laptop;
  use the Mac path or the script's environment override.
- The resource guard runs on macOS (`scripts/zk60_resource_guard.py`,
  watchdog-only: no cgroup cap; probes via `ps`, `vm_stat`, `sysctl`,
  `ioreg`). The guard rules below still apply.
- No `setsid`, `flock` CLI, systemd, bubblewrap, `nvidia-smi` or CUDA here.
  Detach with a `python3` runner using `subprocess.Popen(...,
  start_new_session=True)`. The hourly explorer needs bubblewrap and is not
  installed on the Mac.
- `gpu-cuda` cannot build; the Apple GPU needs a Metal backend first
  (`docs/zkmatrix-poc/ZK60_METAL_PORT_PLAN.md`).
- About 446 GiB of large files (each > 1 MiB) and everything kept outside
  the repo (`/home/victor/zk60-artifacts`, owner-private keys, salts and
  openings) stayed on the laptop. `SNAPSHOT_20261017_EXCLUDED_LARGE_FILES.json`
  lists the in-repo ones with hashes.
- The 2026-10-30 HOLD was for the Windows restart; lanes resume from here.

**Crash recovery, 2026-09-30 UTC:** Victor requested coordination between
both interactive Codex sessions and Claude after the WSL restart. Before a
native build/proof or checkpoint calibration, read and acknowledge
`ops/zkp-mvp/RECOVERY_COORDINATION.md`. It records exclusive file ownership,
the shared resource-guard review and launch hold. Builds and proofs need one
common memory-heavy lock plus admission/caps; separate build/proof locks alone
permit unsafe overlap. Do not start a second researcher or relaunch a run
from a stale status file. Follow the acknowledged guard interface once it is
validated; retained lightweight receipt verification and bounded Python
checks can continue during recovery.

**Resource rules, 2026-09-30 (the box froze 2026-09-29 17:40 PDT with five
heavy jobs live; cause not proven):** anything over 1.5 GiB RAM, a minute of
several cores, or the GPU runs through
`python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run
--class {light,build,cpu,gpu} ... -- <cmd>`; build/cpu/gpu share one heavy lock,
so a build never overlaps a proof, and the kernel caps each job's memory. Guard
the leaf command, never SIGKILL the guard, read `status` before timing runs.
Full rules, numbers and limits: `docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md`;
history of measured peaks: `results/zk60_resource_guard/history.jsonl`. The
heavy-run detach recipe below still applies; put the guard inside it.

**Privacy requirements are decided:** the first PoC (P1) hides inputs,
outputs and intermediate activations; weights may be public. The full version
(P3) also hides weights. Read `docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md`.
Do not reopen this choice or substitute public IO to bypass a proof obligation.

**New intermediate checkpoint, Victor 2026-09-27 UTC:** advance a trained
approximately 1B complete-stack CPU/GPU proof on the local 8 GB RTX 4070,
with measured scaling, while retaining the final private 8B / >=50 proved
tokens/s goal. Read `docs/zkmatrix-poc/ZK60_1B_CHECKPOINT.md` for actual
checkmarks, lane ownership and limits. Three Sol implementation lanes are
active on model/memory inventory, strict layer-streaming import and the
actual native softmax masked-transcript boundary. The hourly researcher
should choose complementary work rather than duplicate those tasks. Model
weight size alone is not proof memory; do not claim trained/full-stack
coverage from a synthetic block or reopen P1 scope.

**Plain status for Victor:** `docs/zkmatrix-poc/MVP_STATUS.md` answers "do we
have a workable proof, how slow are we against the target, what blocks the
MVP" in one page with labelled numbers. Refresh it whenever a proof lands,
a measurement changes or a blocker moves; never let it go stale for a week.

**Decisions register:** `docs/zkmatrix-poc/ZK60_DECISIONS.md` holds every
product and security ruling (accepted deviations such as the 97-bit zkVM
level, the Groth16 trusted setup, receipt kinds, pending rulings). Read it
before claiming any security or privacy property; record a new ruling there
the day it is made.

**Any agent working on the proof clocks (Claude, Grok/Cursor, human):
start at `docs/zkmatrix-poc/TASK_BOARD.md`** — the ordered queue of
small, self-checking tasks with exact commands and byte-identity
acceptance. Ledgers: `PROGRESS_UPERF3.md` (current: the 8B MVP on the
lattice line, opened 2026-08-18), `PROGRESS_UPERF2.md` (rounds 1-9),
`PROGRESS_UPERF.md` (Phase 0); phase plan:
`docs/zkmatrix-poc/CONTINUATION.md`; the two proving channels side by
side: `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md`.

Victor approves permission prompts over Telegram, one text per prompt. Every
avoidable prompt is a real interruption. **Shape commands to match the
allowlist in `.claude/settings.json` (read-only ops) and
`.claude/settings.local.json` (git write ops)**; the rules below exist for
that reason. Both files are gitignored and local to the WSL box. Since
mid-August 2026 that box runs `permissions.defaultMode: auto`: allowlisted
commands run with no check at all, everything else goes to the auto-mode
classifier, which allows or blocks without prompting. Since then only
AskUserQuestion and EnterWorktree have reached Telegram (hook log,
2026-09-01); the rules below now buy classifier-free execution rather than
fewer pings.

## Command style (prompt hygiene)

- **Never prefix commands with `cd`.** Use absolute paths.
  `cd X && cmd` requires every part of the compound to be allowlisted and is
  this repo's single biggest source of prompts.
- **Run git plain from the repo root** (sessions start there): the allowlist
  matches `git status*`, `git worktree*`, etc. as prefixes, so
  `git -C <path> ...` and `cd X && git ...` do NOT match and will prompt.
- **Never prefix commands with `PATH=...`.** Call the rustup toolchain by
  absolute path instead: `~/.rustup/toolchains/<toolchain>/bin/cargo build
  --release` matches the allowlist; a `PATH=` prefix never will.
- **Prefer one simple command per call** over `&&`/`;`/pipe chains — one
  stray head sends the whole chain to Victor's phone.
- **`sed -n` (read-only paging) is allowlisted; `sed -i` is not** — edit
  files with the Edit/Write tools.
- **python via bare `python3`** (classifier-approved; only `python3 -m
  unittest *` is allowlisted), multi-step logic in a script or one `-c`
  block rather than shell loops.
- **git**: read ops plus `add`/`commit`/`worktree`/`merge` are allowlisted
  (the tranche protocol's lane ops). `push`, `reset`, `checkout`, `rebase`,
  `rm`, `mv`, `kill` require approval — batch them (e.g. the push at tranche
  close) and present them together with one-line rationales. (As of
  2026-09-01 `git push *` is nonetheless in the WSL box's
  `.claude/settings.local.json` allowlist, so it does not actually prompt
  there.)

## Heavy runs: detach, queue, marker (the no-hangup protocol, 2026-08-26)

**Codex exception, directed by Victor on 2026-09-22:** do not spend a day
waiting for an approval merely to create a worktree, commit, launch a CPU
test, or inspect a process. Prefer the sandbox-first workflow below. The
detached convention still applies when an already permitted launcher exists;
it must not make otherwise permitted CPU work depend on an escalation.

The box must keep working when the session dies (usage cutout, /clear,
crash). Evidence: 2026-08-26, a foreground Gemma margins run died with
the session ~1 min after starting and the box sat idle 80+ minutes.
Therefore every run expected to take > ~5 minutes is launched DETACHED:

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock <cmd> >> <log> 2>&1; echo $? > <log-stem>.done' >/dev/null 2>&1 &
```

- `setsid nohup` — the run survives session death.
- `flock /tmp/zk-heavy.lock` — serializes heavy jobs on the 15 GB box
  (the shared-box rule); the KERNEL releases the lock when the holder
  dies, so a stale lock is impossible (never hand-roll lock files).
  ENQUEUE follow-up runs immediately with the same wrapper — they
  block on the lock and self-start when it frees, session or no
  session. CPU-light gates (a verify pass, a battery) can skip the
  lock and run alongside.
- The `.done` marker holds the exit code — the universal "did it
  finish" answer for ANY later session or agent. Check for `.done`
  files and half-written logs when resuming; integrate before
  starting new work.
- The session watching a run uses a Monitor/background watcher on the
  log or marker (cover FAILURE lines too, not just success), never a
  foreground wait.

## Protocol invariants (from the PROGRESS ledgers — verify there before acting)

- **Do NOT touch**: `codex-audit-*` (read-only), `scripts/logup_*_spike.py`,
  `src/manifest.rs` (see PROGRESS.md header).
- The test suite (`python3 -m unittest discover -s tests`) plus freeze-check
  must stay green; freeze gates are load-bearing.
- **Wall-clock benchmarks need a quiesced box.** The Mac currently runs
  multi-week frugal-lm training (F2); timing ladders taken now are polluted
  (~2x run-to-run variance was already measured on this box). Design, code,
  and correctness work are fine; defer quiesced measurement passes.
- Parallel agents work in sibling worktrees (`../wt-<tranche>-<lane>`) with
  strict file-lane ownership declared in the tranche ledger — read your
  lane's ownership block before writing anything.
- Cross-project: the U-AG-B1 build round's first integration rung uses
  frugal-lm's ladder shapes (125M, 768->2048). Coordinate through
  the frugal-lm memory index and its CLAUDE.md rather than re-deriving.

## Approval etiquette

If something is not allowlisted, do not fire the prompt the moment you hit
it. Collect what you need and make the request once: what command, why, and
what happens after. Victor says yes to almost everything — the cost is the
interruption, not the permission.

## Codex unattended workflow — Victor's direction, 2026-09-22

Victor is often unavailable to approve requests. Continue authorized work
inside the sandbox whenever possible; approval latency is not a reason to
stop coding, reviewing, building or testing.

- Use the existing writable checkout and `/tmp`. Reuse an isolated checkout
  already created for this task; when only a small prototype needs isolation,
  copy its source files without Git metadata. Do not make a new worktree or
  commit a prerequisite for implementation. Protected Git metadata remains
  protected: no alternate write path, permission bypass or automatic approval
  hook. Save reviewed diffs and source-hash manifests until a scoped commit
  can be made; describe uncommitted candidates honestly.
- Run CPU builds/tests with the ordinary sandbox tool, `--offline --locked`,
  two build jobs, and the existing build/heavy locks. Keep a long foreground
  job in the tool's yielded execution session and poll that session handle.
  Prefer bounded, resumable groups for long suites, retaining each group's
  logs and completion marker. A live tool session is not a promise that a
  process survives application or machine restart.
- Do not escalate just to read a PID from another process namespace. Use the
  original tool handle for sandbox jobs; for existing detached jobs, use their
  recorded process/terminal evidence. An invisible PID in the sandbox alone
  does not establish that an outside process stopped. Never restart a job
  solely because a poll timed out or a status file looks old.
- Prepare all reviewable work before an unavoidable approval. Bundle related
  Git publication or actual-device checks in a narrowly scoped request. While
  a GPU/network/publication action is deferred, keep advancing independent
  CPU implementation and validation; do not claim that deferred checks passed.
  Actual sandbox failures still follow the runtime's escalation instructions.
- `.claude` permission/Telegram hooks do not configure this Codex session.
  Codex's supported **Approve for me** mode uses automatic review at the
  sandbox boundary; it does not remove the sandbox. The active session's
  permission mode is controlled by the host/UI, not by repository instructions.
  Never silently disable the sandbox or replace the user's approval policy.

Setup, limits and a verified sandbox build are recorded in
`docs/zkmatrix-poc/ZK60_UNATTENDED_WORK.md`.

## Persistent efficiency research lane (Victor, 2026-09-22)

Victor requested a cross-session background agent that continually searches
new literature and GitHub projects and tests plug-in efficiency ideas. Its
durable memory and experiments are in `research/zkp-efficiency/`; its supervisor
and operating limits are in `ops/zkp-explorer/README.md`. Read its `STATE.md`
and new `handoffs/` when resuming the main project, and triage actionable results
with Claude in the existing coordination file. It supplements the full private
8B GPU implementation goal; it does not redefine it.

The installed backend is a user cron watchdog plus a bubblewrap-isolated
worker (2026-09-23): one bounded cycle per hour, low CPU priority, isolated
experiments, no changes to the main prover without review. The systemd variant
was not installed because this host has no reachable user bus. Confirm actual
supervisor/child liveness with `python3 scripts/zk60_explorer.py health` on the
host before saying it is
running or starting another worker; a status file alone is not enough. Do not
spawn a duplicate explorer every time a conversation resumes. Check installation
evidence in `research/zkp-efficiency/runtime/`; setup files alone do not mean it
is installed. Do not stop it just because a Codex session ends. Honor an explicit
later stop/pause instruction using this supervisor's `pause` / `resume` controls.

**Standing research direction, Victor, 2026-09-26:** the researcher must
proactively generate and investigate optimization questions such as KV reuse,
proof batching and cached preprocessing; do not wait for Victor to propose
them. Read `research/zkp-efficiency/AGENDA.md` on every research cycle and
follow its hypothesis, falsification, measurement and handoff requirements.
Its current >=50 proved-token/s target permits longer workloads on an RTX
5090 or another named high-end GPU. This explicit later direction supersedes
fixed-512 acceptance wording in older launcher prompts or research state.

**Agent delegation, Victor, 2026-09-26 PDT:** use as many agents as needed
to complete the MVP, and use **GPT-6 Sol (`gpt-6-sol`)** for those agents.
Delegate independent implementation/review lanes up to available capacity,
with explicit file ownership and shared build/heavy locks. The current lane
map is `docs/zkmatrix-poc/ZK60_SOL_TEAM_20260927.md`. The standing explorer's
launcher also selects Sol explicitly. Report meaningful progress regularly;
agent count, synthetic gates and kernel gains do not establish MVP completion.
