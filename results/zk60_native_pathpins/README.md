# Evidence: the toy gates' source pins widened to the WHOLE path (round 5, item B)

The security owner's ruling of **2026-09-20 22:06**: condition 7 of the toy
profile's accepted privacy statement (register D22) says *a change to any
pinned Rust file suspends step 3*, and the re-read at `4751b93`
(`ZK60_NATIVE_D22_REPIN_4751B93.md` §7 item 1) found that condition narrower
in practice than in words — `hashline/src/pcs.rs`,
`hashline/src/private_block.rs` and the hashline-side `merkle`, `transcript`,
`field` and `ntt` files are on the toy block profile's path and were pinned
by nothing. The pin set is extended to every file on the path.

Report: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md` round 5, §R5.5
(the file-by-file reading) and §R5.6 (the refresh).

**Nothing here is a privacy acceptance.** Widening a pin set makes a
suspension condition mean what it says; it establishes no property.

## How the list was established

Read from the COMMITTED BLOBS at `4751b93`
(`git show 4751b93:<path>`), never the working tree, by following `use` and
call out of `hashline/src/private_block.rs` and
`private_block/{argument,layout,protocol,wire,witness}.rs`. Note that main's
`private_block` module is the TOY-ONLY one, older than the lane's shaped
module: it has no `shape.rs`, `run.rs` or `plane_index.rs`.

**29 files.** 9 were already pinned by a port; **20 were pinned by nothing**
and each was READ before it was pinned. Four more are now pinned by
`zk60_native_mask_commit` at the SAME digests `zk60_native_terminal_polys`
uses, because the P10 privacy gate — step 3's instrument — reads only the
first tool's table.

## Files

| file | what |
|---|---|
| `pb_pcs.diff.txt` | `git diff 4751b93^ 4751b93 -- private_block.rs pcs.rs`: 2 and 47 added lines, **0 removed** |
| `gpu_mod.diff.txt` | the same for `gpu/mod.rs`: 426 added lines in two hunks, **0 removed or modified**; `backend()` and `enabled()` untouched |
| `before_p10.json`, `before_channels.json`, `before_jointview.json` | the three committed records, taken with `git show HEAD:…` BEFORE any re-run |
| `gates.sh`, `gates.log`, `gates.done` | the three toy gates re-run on the four 2026-09-19 captures, detached under `flock /tmp/zk-heavy.lock` |
| `*.diff.json` | each refreshed record against its committed bytes, leaf by leaf |

## Why the tool hashes moved

Exactly one tool changed: `scripts/zk60_native_mask_commit.py`, and only
because the pin tables were written into it — four entries added to
`SOURCE_PINS`, the new `PATH_PINS` table, `FIXTURE_PATH_NOT_PINNED`, three
second digests in `ALSO_ACCEPTED`, and the `pin_kind` field and the
path-specific refusal message in `check_source_pins`. **No arithmetic in
that file changed**, and the leaf-by-leaf diffs are the proof of it.

## Three files carry TWO digests

This lane's worktree still carries `4751b93^`'s bytes for
`private_block.rs`, `pcs.rs` and `gpu/mod.rs` while main carries
`4751b93`'s. Each diff was read in full (above), each is purely additive,
and none of the added code is reachable from this profile. Both digests are
accepted and the lane tree's — the tree the four captures were produced in
— is the pin of record. That is exactly the form §4.1 of the re-pin report
used for `zk.rs`.
