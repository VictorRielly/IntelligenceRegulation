# IntelligenceRegulation — project instructions

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
