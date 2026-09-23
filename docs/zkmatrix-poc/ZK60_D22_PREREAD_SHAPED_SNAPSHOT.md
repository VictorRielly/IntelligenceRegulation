# The D22 condition-7 PRE-READ of the integrator's shaped snapshot

**Status: OPEN (W0–W2 done, W3 in progress).** Opened 2026-09-23 01:13 PDT
on `perf/zk-batch-optimizations` (main tree). Written by one delegated Opus
reviewer for the security owner. Python and `git show` only — no Rust build.

**What this is.** The integrator (Codex) assembled the block lane at
`fee1a8d` onto main `4751b93` plus two additive hash-tag patches as a FIXED,
uncommitted source snapshot:
`results/zk60_shaped_integration_20260922/reviewed-source.tar.gz`
(SHA-256 `c794360a…`), with `review-snapshot.json` (179 per-file hashes).
Condition 7 of the toy profile's accepted privacy statement (register D22):
*a change to any pinned file suspends step 3 until re-read and re-pinned.*
This page is the reading, against exactly that archive.

**What this is NOT.** Not the re-pin (only the security owner moves a pin of
D22; no pin table or gate was edited). Not a privacy acceptance. Not a
review of the snapshot's non-toy code except where it touches the toy path.

## 0. Status

| # | item | state |
|---|---|---|
| W0 | skeleton | DONE — `125f727` |
| W1 | archive verified, every file hash against `review-snapshot.json` | DONE — §1 |
| W2 | the 37-file pin set, snapshot digest vs pin(s) of record | DONE — §2 |
| W3 | every moved pin: diff vs `4751b93`, hunk by hunk | in progress |
| W4 | the two Cargo manifests: can the observers reach a release build? | DONE — §4 |
| W5 | conclusion for condition 7 | pending |

## 1. The archive

`results/zk60_d22_preread_snapshot/pin_table.txt` (`pins.py`, first block).

* `reviewed-source.tar.gz` SHA-256 **`c794360a09de1770104d8e40ce043344b25c21498cfe37ed661575a8ac06626a`**
  — equal to the value asked for and to `review-snapshot.json[archive_sha256]`.
* Extracted to `/tmp/claude-1000/d22-snapshot/` (never into the repo):
  **179 files, 179 hashes equal to `review-snapshot.json[source_hashes]`, 0
  missing, 0 extra.**
* The integrator's `baseline-validation.json[source_hashes]` is the same 179
  entries at the same digests, so its builds and runs were made from exactly
  these bytes.
* What the snapshot IS, file by file against `4751b93` and `fee1a8d`
  (`pin_table.txt`, last block): 107 files equal both; **62 are the lane's
  bytes** (main never changed them); 7 are main's (the lane never changed
  them: `gpu/{cuda,mod}.rs`, `layer.rs`, `wcache.rs`, two examples,
  `zk_mr1_probe_tests.rs`); **2 are neither side's** — `hashline/src/zk.rs`
  and `hashline/src/pcs.rs`, each exactly main's `4751b93` bytes plus the
  lane's additive tag block (the lines the lane added to the fork base
  `3811e55` are, line for line, the lines the snapshot adds to main: 105 in
  `zk.rs`, 13 in `pcs.rs`; checked by script) — these are the "two additive
  hash-tag patches"; 1 is new (`private-block-kernel-shaped/Cargo.lock`).
* **The snapshot is the lane at STAGE 35 (`fee1a8d`), not later.** Stage 36
  (`29cba9a`, the read-only observers) and stages 37–42 are not in it: the
  tokens `test-observers`, `consumed_bytes`, `squeezes`, `draw_observer`,
  `OBSERVED_BLOCK_BYTES` occur **nowhere** in the 179 files, `zkp-core/src/rng.rs`
  and `zkp-core/Cargo.toml` are at their pins of record, and
  `hashline/Cargo.toml` is the lane BASE's `e3acda1b…`, not stage 36's
  `5633d1e4…` nor the lane tip's `10d99a63…`.

## 2. The pin set against the snapshot

The 37 paths (35 Rust + 2 manifests) are read OUT of the joint-view
worktree's four pin modules (`zk60_native_mask_commit.SOURCE_PINS` +
`PATH_PINS` + `ALSO_ACCEPTED`, `zk60_native_terminal_polys.SOURCE_PINS`,
`zk60_native_manifest_pins.MANIFEST_PINS`,
`zk60_native_profile_pins.PROFILE_PINS`), imported read-only, not retyped.
Full 64-hex digests and the four reference trees are in `pin_table.txt`.

**24 equal, 13 moved, 0 absent.**

| path | pin of record | 2nd accepted | snapshot | equal? | snapshot bytes are |
|---|---|---|---|---|---|
| `hashline/Cargo.toml` | `eaba50ec…` | — | `e3acda1b…` | **MOVED** | lane `fee1a8d` |
| `hashline/src/field.rs` | `1dc6c53b…` | — | `1dc6c53b…` | yes | all four |
| `hashline/src/gpu/mod.rs` | `a5ceeba2…` | `706ca7fa…` | `706ca7fa…` | yes (2nd) | main |
| `hashline/src/lib.rs` | `fcb784d3…` | — | `fcb784d3…` | yes | all four |
| `hashline/src/merkle.rs` | `06fd5f0b…` | — | `06fd5f0b…` | yes | all four |
| `hashline/src/mle.rs` | `bffe83fb…` | — | `bffe83fb…` | yes | all four |
| `hashline/src/native_capture.rs` | `621f6459…` | — | `621f6459…` | yes | all four |
| `hashline/src/ntt.rs` | `a7f7ac0b…` | — | `a7f7ac0b…` | yes | all four |
| `hashline/src/pcs.rs` | `6d27f3a5…` | `9537915b…` | `6f4b2cd4…` | **MOVED** | neither (main + tag patch) |
| `hashline/src/private_attention.rs` | `dfc02d91…` | — | `dfc02d91…` | yes | all four |
| `hashline/src/private_attention/argument.rs` | `3343620e…` | — | `3343620e…` | yes | all four |
| `hashline/src/private_attention/layout.rs` | `17159dcc…` | — | `17159dcc…` | yes | all four |
| `hashline/src/private_attention/protocol.rs` | `cf297220…` | — | `cf297220…` | yes | all four |
| `hashline/src/private_attention/wire.rs` | `a35a468c…` | — | `a35a468c…` | yes | all four |
| `hashline/src/private_attention/witness.rs` | `795cf629…` | — | `795cf629…` | yes | all four |
| `hashline/src/private_block.rs` | `5d9dd178…` | `412a43f4…` | `b4aeb6ed…` | **MOVED** | lane `fee1a8d` |
| `hashline/src/private_block/argument.rs` | `e62f46c2…` | — | `f7fa2ad4…` | **MOVED** | lane |
| `hashline/src/private_block/layout.rs` | `6cc8f6fe…` | — | `14758039…` | **MOVED** | lane `fee1a8d` |
| `hashline/src/private_block/protocol.rs` | `d9455a10…` | — | `ac412237…` | **MOVED** | lane `fee1a8d` |
| `hashline/src/private_block/wire.rs` | `5b11631d…` | — | `99e69b5c…` | **MOVED** | lane |
| `hashline/src/private_block/witness.rs` | `640754fb…` | — | `b9b66c02…` | **MOVED** | lane `fee1a8d` |
| `hashline/src/private_seam.rs` | `2f36c779…` | — | `2f36c779…` | yes | all four |
| `hashline/src/sumcheck.rs` | `f097dd71…` | — | `f097dd71…` | yes | all four |
| `hashline/src/tables_attn.rs` | `5a874788…` | — | `5a874788…` | yes | all four |
| `hashline/src/transcript.rs` | `4850b2b4…` | — | `4850b2b4…` | yes | all four |
| `hashline/src/zk.rs` | `c5b54753…` | `ce8cc516…` | `07282c76…` | **MOVED** | neither (main + tag patch) |
| `zkp-core/Cargo.toml` | `b9038a52…` | — | `b9038a52…` | yes | main = lane base |
| `zkp-core/src/field.rs` | `df3eb5a6…` | — | `df3eb5a6…` | yes | all four |
| `zkp-core/src/lib.rs` | `1c2a6ce1…` | — | `388f012f…` | **MOVED** | lane |
| `zkp-core/src/merkle.rs` | `77bc5f51…` | — | `6e7817bd…` | **MOVED** | lane |
| `zkp-core/src/mle.rs` | `b20c8b75…` | — | `b20c8b75…` | yes | all four |
| `zkp-core/src/ntt.rs` | `97572d4f…` | — | `97572d4f…` | yes | all four |
| `zkp-core/src/pcs.rs` | `2d914956…` | — | `6b8d1bfa…` | **MOVED** | lane |
| `zkp-core/src/pcs/backend.rs` | `1734c03c…` | — | `1734c03c…` | yes | all four |
| `zkp-core/src/rng.rs` | `0d4a99ab…` | — | `0d4a99ab…` | yes | main = lane base |
| `zkp-core/src/sumcheck.rs` | `56dbb8c7…` | — | `56dbb8c7…` | yes | all four |
| `zkp-core/src/transcript.rs` | `31ce3c9a…` | — | `cc9752d0…` | **MOVED** | lane `fee1a8d` |

("all four" = main `4751b93`, lane `fee1a8d`, stage-36 `29cba9a`, lane tip
`6b68561`. "lane" = `fee1a8d`, `29cba9a` and the tip.)

The thirteen are exactly the stage-36 pre-read's prediction of what the lane
base moves against main (§6 there: 9 lane-only + 3 both-sides; `gpu/mod.rs`,
main-only, is at its accepted second digest) plus `hashline/Cargo.toml`,
which was pinned after that pre-read (round 9f). **None of the 13 snapshot
digests is in any accepted set today**, so both toy gates would refuse the
snapshot tree at their first pin check (`manifests.txt` shows the manifest
check doing so, naming `hashline/Cargo.toml`). Neither pin of the manifests
moves to the `EXPECTED_AFTER_INTEGRATION` values recorded in
`zk60_native_manifest_pins.py` (`0c746b9d…`, `10d99a63…`): those are the
stage-36-and-later lane manifests, which this snapshot does not carry.
