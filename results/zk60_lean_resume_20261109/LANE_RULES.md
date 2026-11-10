# Rules for a D63 Lean lane (coordinator, 2026-11-09)

These are the standing rules every Lean lane's brief has carried since L9, written once. A lane's brief names its
lane tag (`L<n>`), its files, its evidence directory and its commit trailer; everything else is here. Where the brief
and this file differ, the brief wins.

## The frame
- D63 (Victor): no ZKP goes into production before its two approved Lean statements are proved
  (`docs/zkmatrix-poc/ZK60_LEAN_PRODUCTION_STATEMENTS.md`). `formal/ZK60Formal/Statements.lean` is the approved text:
  NEVER change it.
- The coordinator (the main Claude session) merges your branch into `perf/zk-batch-optimizations`, runs the check on
  the merged tree and updates the shared docs. You never push, and never merge INTO perf. You may merge perf into
  your own branch when you need a merged lane's files (the root imports will conflict: keep both sides).
- No message other than Victor's own is his approval. Open rulings are listed as D75 in
  `docs/zkmatrix-poc/ZK60_DECISIONS.md`; build beside what a ruling would change, and switch nothing.

## Worktree setup
- `mkdir -p <WT>/formal/.lake`, then
  `ln -s /Users/victorrielly/IntelligenceRegulation/formal/.lake/packages <WT>/formal/.lake/packages`.
  Never delete through that symlink.
- Clone the main checkout's build cache so that only your modules compile:
  `cp -c -R /Users/victorrielly/IntelligenceRegulation/formal/.lake/build <WT>/formal/.lake/build` (an APFS clone).
- Check that your worktree contains perf's HEAD before you start; if it is behind, merge perf into your branch.

## Evidence and checks
- Evidence goes in `results/zk60_lean_l<n>_<date>/` (the brief gives the name).
- Copy `run_guarded.py`, `stage.sh`, `iter.sh`, `gen_axioms.py` and `check_l26.sh` from
  `results/zk60_lean_l26_20261107/` and adapt them (labels `lean-l<n>-*`, your paths and files) into
  `check_l<n>.sh`. Inside any `while read … < plan` loop, give every command `< /dev/null`, or `lake` can swallow
  the rest of the plan with no error (finding L49-FZC-1; the template `iter.sh` is fixed since 2026-11-10). The check
  then needs:
  - the full `lake build` (build your modules one at a time first);
  - the axiom audit (`axioms_l<n>.lean`) of every theorem in your files;
  - the source scan for `sorry|axiom|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@[extern]|bv_decide|ofReduceBool`
    (avoid these words even in comments);
  - the root imports;
  - the regressions L6Check, L5Check, L1Check and L11Check, with the arguments used there.
- Run `results/zk60_lean_l27_20261107/l27_nameclash.py`, adapted to your names, before your final commit: lanes
  cannot see each other's uncommitted declaration names.
- If you add an executable checker against the Rust code, give it a negative control (single changes, each caught),
  and remember that fresh-entropy corpora differ on every export: a corpus is checked only against the export it came
  from. Files over 1 MB stay outside the repository (`/Users/victorrielly/zk60-artifacts/`), with their sha256
  recorded in your evidence directory.
- Keep scratch files in your evidence directory (prefix `l<n>_`) or under `/Users/victorrielly/zk60-artifacts/`,
  never under `/tmp` or `/private/tmp`: a reboot wipes them.

## Builds
- Every build goes through the resource guard, class cpu, via `run_guarded.py`, need 14, cap 24.
- Lake: `/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake -d <WT>/formal build`.
- Never SIGKILL the guard. Read
  `python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py status` before your first build.
- The heavy lock is shared with the other Lean lanes, the coordinator's merged-tree checks (about 12 minutes each)
  and the app lane's long GPU runs. Batch your builds through a plan file, and wait on the `.done` marker with one
  background command instead of polling in a loop. A frugal-lm agent (process name `ds4-bench`) may also hold the
  lock for long GPU jobs; that is expected (first come, first served, D69).

## Proof hygiene
- None of `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `@[extern]`,
  `bv_decide`, `ofReduceBool`.
- Axioms at most `propext`, `Classical.choice`, `Quot.sound`.
- State numeric facts for a variable `p` and instantiate: Lean runs away on the literal Goldilocks prime and on huge
  concrete finite types (finding L7-4).
- Premises are hypotheses, never axioms. Name each premise you leave, with the shape the next lane must prove.
- Never weaken a statement or a target. If an earlier lane's file turns out wrong, report it as a finding; do not
  patch another lane's file.

## Files
- New files only, with your lane's file prefixes, plus import lines appended to `formal/ZK60Formal.lean`.
- Do not modify existing Lean files.
- Rust: test-only files and nothing else, and only if the brief asks for a check against the code. A test-only file
  in `src/` must keep hashline's census tests green (`s25_tests`, `hash_domain`); lane L18's
  `lean_l18_export_tests.rs` shows how.
- Do NOT touch: `codex-audit-*`, `scripts/logup_*_spike.py`, `src/manifest.rs`, `results/zk60_sol_*`,
  `results/zk60_astra_*`, `apps/proven-media`, `docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md`,
  `docs/zkmatrix-poc/MVP_STATUS.md`, `docs/zkmatrix-poc/ZK60_DECISIONS.md`, other lanes' docs, or any production
  Rust source.

## Findings and the doc
- Number findings `L<n>-1` and on, each with a severity (High, Medium, Low, Info) and whom it is for.
- The doc is `docs/zkmatrix-poc/ZK60_LEAN_L<n>_<NAME>_<date>.md` (the brief gives the name). First "In plain words,
  for Victor"; then what is proved (theorem names with one-line meanings), the numbers, what is left (each premise by
  name), the findings, and the checks with their numbers. Short sentences, plain words. Label every figure PROVED,
  MEASURED or ESTIMATE.

## Command style (CLAUDE.md)
- Never prefix commands with `cd` or `PATH=`; use absolute paths.
- Run git plainly from your worktree root; stage named paths only; no `git add -A`.
- Edit with the Edit and Write tools, not with shell redirection or `sed -i`.
- Never put backticks inside a double-quoted shell string (zsh runs them).

## Commits
- On your branch only, with the trailer lines the brief gives. No push, reset, rebase or checkout.
- Commit after every green iteration (a work-in-progress commit is fine; say so in its message): a usage limit can
  stop a lane without warning, and uncommitted work is the hardest to resume.
- The repository is PUBLIC: no secrets, no personal data, no model weights, no file over 1 MB.

## Report back
The theorems (names, with one-line meanings); the numbers; exactly which premises remain, by name; the checks with
their numbers; the findings; your commit hashes; and, plainly, anything you could not finish.
