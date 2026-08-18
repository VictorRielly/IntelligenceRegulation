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
allowlist in `.claude/settings.local.json`**; the rules below exist for that
reason.

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
- **python via bare `python3`** (allowlisted), multi-step logic in a script
  or one `-c` block rather than shell loops.
- **git**: read ops plus `add`/`commit`/`worktree`/`merge` are allowlisted
  (the tranche protocol's lane ops). `push`, `reset`, `checkout`, `rebase`,
  `rm`, `mv`, `kill` require approval — batch them (e.g. the push at tranche
  close) and present them together with one-line rationales.

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
