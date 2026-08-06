# Audited snapshot and recovery map

## Checked-out worktree

- Branch: `perf/zk-batch-optimizations`
- HEAD: `8a206aec09f15f8eb203354eeaa02c15258abe68`
- Remote tracking ref: `origin/perf/zk-batch-optimizations` at `7da16f2`
- Remote state observed locally: checked-out branch is ahead by one commit.
- No staged changes.
- Live tracked changes:
  - `PROGRESS.md`
  - `docs/zkmatrix-poc/M4_LOOKUP_DESIGN.md`
- Existing untracked audit directories were preserved.

Relative to the prior audited code commit `444f057`, checked-out HEAD contains
23 commits touching 15 files (`+6,551/-207`). The size and security sensitivity
of that tranche justify treating the green regression suite as necessary but
not sufficient evidence.

The checked-out U-K8 commit is therefore recoverable locally but is not present
on the recorded remote-tracking ref. The two latest measurement/documentation
edits are not committed.

## Attached Fable worktrees

### U-K9 worktree

- Path: `.claude/worktrees/agent-aba54d89afd23bcca`
- Branch: `worktree-agent-aba54d89afd23bcca`
- HEAD: `e8fa7772d445e1d8a05a558a9f28f325d7e3bd5a`
- Parent tranche commit: `d1cfa56`
- Branch point: `7da16f2`
- Commit contents: packed q31 tables, custom bulk field kernels, packed GKR
  trees/rounds, a scalar differential oracle, and a U-K9 battery.
- Live residue: 32 uncommitted lines in `zkmatrix-rs/src/ring/kfield.rs`.
- Live residue status: **does not compile**; it changes `fold_body` to an
  in-place signature but does not update the generated wrapper/call sites.

The clean `e8fa777` commit is safe to preserve as a review candidate. The live
32-line continuation must be either finished in its worktree or explicitly
quarantined; it must not be swept into a merge.

### Test-hygiene worktree

- Path: `.claude/worktrees/agent-a8ea401f9f142462b`
- Branch: `worktree-agent-a8ea401f9f142462b`
- HEAD: `4d9d0d2076c1033221b312d7ddf5a33cde3c1c05`
- Worktree: clean.
- Contents: deterministic entropy fixture scoped to two probabilistic tamper
  tests. The two affected tests pass.

## Merge state

U-K8 and U-K9 both fork from `7da16f2`; neither contains the other. A read-only
`git merge-tree` inspection found at least one direct conflict in
`ring_matmul.rs`: U-K8 adds `self_test_ffn_chain()` to the dispatcher while
U-K9 adds `self_test_uk9()` at the same site. A correct resolution must retain
both calls. `lookup.rs` also changed on both sides and needs semantic review
even where Git can merge it mechanically.

There is no tested combined U-K8+U-K9 tree. The clean U-K9 tests establish only
that U-K9 works against its `7da16f2` base.

## Unreachable objects

`git fsck --no-reflogs --unreachable` found older WIP/stash objects from the
July 8–10 tranches. Their commit subjects correspond to work already represented
in later reachable commits. I found no newer lost U-K9 commit beyond
`e8fa777`; the latest additional work is the visible 32-line worktree edit.

## Recommended preservation order

1. Preserve the existing refs and live diffs before any merge operation.
2. Commit the two documentation edits separately only after correcting the
   audit findings; they currently overstate U-K8 closure.
3. Preserve `e8fa777` unchanged as the U-K9 review baseline.
4. Do not include the live 32-line U-K9 residue in a merge until it builds and
   has its own differential tests.
5. Merge/cherry-pick the test-hygiene commit independently.
6. Build a dedicated integration branch from U-K8, merge clean U-K9, retain
   both self-tests, then run the full suite plus the new security regressions
   listed in this audit.

This audit did not perform any of those Git mutations.
