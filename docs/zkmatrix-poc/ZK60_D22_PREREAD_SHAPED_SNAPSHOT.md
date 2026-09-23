# The D22 condition-7 PRE-READ of the integrator's shaped snapshot

**Status: CLOSED (the reading is done).** Opened 2026-09-23 01:13 PDT and
closed 01:28 on `perf/zk-batch-optimizations` (main tree). Written by one
delegated Opus reviewer for the security owner; the six large private-block
files and the path closure were read by five parallel forks of that
reviewer, each hunk by hunk, and their tables are kept verbatim as evidence.
Python and `git show` only — no Rust build, no gate run.

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

**Verdict in plain words.** The archive is the one asked for (all 179 files
check out). 24 of the 37 pinned files are unchanged; **13 moved**. Every
changed hunk of those 13 was read: **none changes what the toy prover
computes, draws, absorbs or hashes, or what an honest toy receipt looks
like.** The toy still hashes under the legacy (unkeyed) rule everywhere,
though it now gets there through new "tagged" functions called with the
legacy tag; those were checked line by line against the originals. The
verifier accepts exactly the same receipt frames; it now refuses some
malformed in-memory receipts earlier or with different wording. **Condition 7
can be re-established for this tree, but not by moving the 13 pins alone:**
the toy now also runs through **six new production files that no pin
covers** (F-1), and one of them contains an operator-switched diagnostic
that prints counts computed from the hidden input (F-2), which the owner
should rule on before that file is pinned. **The stage-36 observers are not
in this snapshot at all** — it is the lane at stage 35 — so the observer
question has a trivial answer here and comes back when stages 36–42 are
integrated (F-7).

## 0. Status

| # | item | state |
|---|---|---|
| W0 | skeleton | DONE — `125f727` |
| W1 | archive verified, every file hash against `review-snapshot.json` | DONE — §1 |
| W2 | the 37-file pin set, snapshot digest vs pin(s) of record | DONE — §2 |
| W3 | every moved pin: diff vs `4751b93`, hunk by hunk | DONE — §3 |
| W4 | the two Cargo manifests: can the observers reach a release build? | DONE — §4 |
| W5 | the toy path's closure: on-path files no pin covers | DONE — §5 |
| W6 | findings, and the conclusion for condition 7 | DONE — §6, §7 |

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

## 3. The re-read, hunk by hunk

**Method.** For each moved file: the unified diff main `4751b93` → snapshot
(`diff/*.main-4751b93.diff`, and for the two "neither" files also lane
`fee1a8d` → snapshot), read hunk by hunk; an item-level comparison
(`items.py`: every `fn`/`impl`/`struct`/`const`/`use` keyed by its enclosing
items, compared byte for byte, `cfg(test)` marked; comment/string-aware, depth
0 asserted) so that a hunk the diff aligner splits across two functions is
attributed correctly (`items_changed.txt`). **"The toy path"** is what
`Shape::toy()` (profile `hashline-zk-mr1/private-block-t32-poc/1`) reaches
through `prove`/`prove_with_stats` and `verify`/`verify_bytes`, in a CPU
build. Classes: **(i)** off the toy path; **(ii)** on it, behaviour-identical,
with the reason; **(iii)** behaviour-changing — a finding, or, where marked,
a verifier that refuses MORE while every honest receipt and the prover's
output are unchanged.

**The decisive fact for the hash layer.** At the snapshot the toy no longer
calls the legacy entry points. `protocol.rs` routes every commitment and
every opening through the tagged twins with `sh.hash_tag()`, which is
`HashTag::legacy()` for exactly two profiles, the toy being one
(`shape.rs:932-955`; the `cfg(test)` override can only force legacy):
`pcs::commit_zk_owned_tagged` for A and H (`protocol.rs:858`, `:977`),
`zk::mask_commit_tagged` for M (`:870`), `zk::mask_verify_tagged` (`:1086`),
`pcs::verify_zk_tagged` for A, H and both endpoints (`:1099`, `:1129`,
`:1202`), and `tagged_transcript` = `Transcript::new` at a legacy profile
(`:96-99`, `:115`). So "the legacy bodies are byte-identical" — true for
every legacy function the two tag patches touch — is necessary but not
sufficient: what has to hold is that each **twin under `HashTag::legacy()`
behaves as its legacy original**. `twins.py` prints each twin against its
original, line for line (`twins.txt`); the differences are, exhaustively:

* `blake3::Hasher::new()` → `crate::hashtag::hasher(key)` with `key = None`:
  `hasher(None)` is literally `blake3::Hasher::new()` (`hashtag.rs`, the one
  `match`);
* `blake3::hash(b)` → `hasher(None)` + `update(b)` + `finalize()`: the same
  digest by the blake3 crate's definition of `hash` (one-shot = the default
  hasher over the same input);
* `hash_pair` / `salt_leaf` / `hash_column(s)` / `MerkleTree::{build,
  verify_path}` → their `_keyed(…, None)` twins, each identical under `None`
  by the two points above;
* `commit_zk_owned_with_tag` offers the backend **iff** `column_key()` is
  `None` — i.e. exactly as before at the toy;
* **one real addition**: `verify_zk_tagged` refuses any opened column whose
  Merkle path length is not `log2(enc_cols)`. `verify_zk` did not check it.
  An honest path is `tree.path(j)`, exactly the tree depth long, so no honest
  receipt is refused and the prover's output is untouched. At the toy it is
  also **redundant for every frame**: main's `wire::validate`, run first in
  `verify_inner`, already required path length `PATH = 11` (A, H, endpoints)
  and `MASK_PATH = 12` (M), and `log2(2048) = 11`; so the set of accepted
  frames is unchanged and only an in-memory receipt with a malformed path is
  refused earlier and in other words (F-4). `mask_verify_tagged` has no such
  check (the snapshot's `hash_domain::mask_paths_are_the_tree_depth` makes it
  in `verify_core`).

Draw order: `mask_commit_tagged` and `commit_zk_owned_with_tag` contain the
draw lines of their originals **unchanged and in the same order** (per mask
spec `CfsMask::random`, then `MASK_Q` pads per real/imaginary part, then
`b_re`, `b_im` with `b[m] = −b[0]`, `u_re`, `u_im`, then one 32-byte salt per
column; for A/H `rng.fp_vec(rows·q)` then `nn` salts, both before the backend
branch). The integrator's own run (not an input here) is consistent:
`baseline-validation.json` has the new binary proving the toy (2,816,472 B,
`7eb33b93…`), the `4751b93` verifier accepting it, and the new verifier
accepting the retained `4751b93` receipt `10b9d4be…`.

### 3.1 The hash layer: seven files

| file | hunk | item | what | class |
|---|---|---|---|---|
| `zkp-core/src/lib.rs` | `@@ -14,6 +14,11` | crate root | `pub mod hashtag;` + doc | (ii) — declares the module every absorb now calls; adds nothing else |
| `zkp-core/src/merkle.rs` | `@@ -18,6 +18,19` | NEW `hash_pair_keyed` | node hash through `hasher(key)` | (ii) — on the path (via `build_keyed`/`verify_path_keyed` with `None`); = `hash_pair` under `None` |
| | `@@ -28,6 +41,23` | NEW `MerkleTree::build_keyed` | (the aligner splits it across `build`; `items.py`: `build` identical) | (ii) — A, H, M trees; = `build` under `None` |
| | `@@ -61,6 +91,22` | NEW `MerkleTree::verify_path_keyed` | | (ii) — verifier; = `verify_path` under `None` |
| | `@@ -82,4 +128,34` | `mod tests` | isolated node control | (i) `cfg(test)` |
| `zkp-core/src/pcs.rs` (+444 −0) | `@@ -27,6 +27,7` | `use crate::hashtag::HashTag` | import | (ii) additive |
| | `@@ -137,6 +138,15` | NEW `hash_column_keyed` (`hash_column` identical) | | (ii) verifier column digest; = `hash_column` under `None` |
| | `@@ -159,6 +169,33` | NEW `hash_columns_keyed` | tiled column digests | (ii) A/H CPU arm and M; = `hash_columns` under `None` (`blake3::hash` ≡ default hasher) |
| | `@@ -644,6 +681,20` | NEW `salt_leaf_keyed` | | (ii) = `salt_leaf` under `None` |
| | `@@ -699,6 +750,63` | NEW `commit_zk_owned_with_tag` | the A/H commitment | (ii) — pads then salts drawn first, same lines, same order; backend offered iff unkeyed (so as before); CPU body identical but for the `_keyed(None)` calls |
| | `@@ -1017,6 +1125,128` | NEW `verify_zk_tagged` (`verify_zk` identical) | the A/H/endpoint opening check | (ii) for every frame; **verifier-only** addition: a Merkle-path-length check, redundant with `wire::validate`'s fixed `PATH = 11` at the toy (F-4); otherwise identical under `None` (same absorbs `pcs-vec`, `pcs-prox`, same `challenge_indices`) |
| | `@@ -1308,3 +1538,217` | `mod tag_tests` | | (i) `cfg(test)` |
| `zkp-core/src/transcript.rs` (+77 −5) | `@@ -19,6 +19,10` | `struct Transcript` | field `key: Option<[u8; 32]>` | (ii) — `None` at the toy |
| | `@@ -26,7 +30,18` | `new` (+`key: None`); NEW `new_tagged` | | (ii) `new`: same state computation; `new_tagged` (i) — the toy takes `Transcript::new` (`protocol.rs:98`) |
| | `@@ -42,7 +57,8` | `absorb` | `Hasher::new()` → `hashtag::hasher(self.key.as_ref())` | (ii) — EVERY absorb of the toy; identical under `None` |
| | `@@ -83,7 +99,8` | `squeeze_bytes` | the same | (ii) — every challenge; identical under `None` |
| | `@@ -138,7 +155,10` | `clone_state` | carries `key` | (ii) — the two clones on the toy path (`protocol.rs:305`, `:367`): `None` → `None` |
| | `@@ -168,4 +188,56` | `mod tests` | keyed-separation + unkeyed-unchanged pins | (i) `cfg(test)` |
| `hashline/src/pcs.rs` (+13 −0 vs main) | `@@ -108,6 +108,19` | NEW `commit_zk_owned_tagged` | forwards to the core twin through `backend()` | (ii) — A and H |
| `hashline/src/zk.rs` (+105 −0 vs main) | `@@ -466,6 +466,57` | NEW `mask_commit_tagged` | M's commitment | (ii) — body = `mask_commit` except the three hashing lines; same draws, same order, same count |
| | `@@ -589,9 +640,63` | NEW `mask_verify_tagged`, NEW `pcs_hash_column_keyed` | M's check | (ii) — = `mask_verify` except the hashing lines (and one comment); same `theta`, `mask-q`, `rs`, `mask-prox`, `challenge_indices(MASK_Q, dom)` |

Against `fee1a8d`, `zk.rs` shows main's twelve `4751b93` hunks (re-read in
`ZK60_NATIVE_D22_REPIN_4751B93.md` §2.1, all at or below the v3 FFN prover)
and `pcs.rs` main's one `commit_planes` hunk (§2.2 there); both were read and
are unchanged here.

**What this section establishes, and its one caveat.** On the toy path the
hash rule is still the legacy, unkeyed BLAKE3 at every layer — transcript,
column digest, salted leaf, node — and no draw moved in the two commitment
functions. The legacy **functions** of `zkp-core/src/{pcs,merkle}.rs` and
`hashline/src/{zk,pcs}.rs` are byte-identical; the legacy **bodies of
`Transcript::{new, absorb, squeeze_bytes, clone_state}` are not** (the lane's
stage-17 edit, not the integrator's patch): they are behaviour-identical only
through `zkp_core::hashtag::hasher(None)`, a function in a file that no pin
covers (F-1).

### 3.2 `hashline/src/private_block/protocol.rs` — 12 hunks, +924 −194

Table: `hunks_protocol.txt` (12 hunks split by item into 36 rows):
**34 × (ii), 2 × (i) (the `cfg(test)` moved-multiplicity hook and the
`cfg(test)` capture hooks), 0 × (iii).** The file was generalised from
module constants to a `Shape`; at `Shape::toy()` every shape-driven value
equals the constant it replaced — profile bytes, the `parameters` line
(rebuilt by script: the frozen literal byte for byte), `log_cols` 8,
`NttTables::new(12)`, PCS `{8, 8, 256}`, endpoint geometry `(7, 2, 4)`,
opening groups 35 / 9, the `HIds` helper indices 0/1/20/27/33/40/41/46/47–49/50
(= main's `H_*`), and `sh.size`/`sh.log` = `Dom::len`/`log` (no domain is
lifted at the toy). Every `rayon` threshold is above the toy's sizes, so the
serial branch runs, and the parallel branches are indexed.

* **The toy prover, against main line by line: identical.** `ZkRng::from_os`
  with the same domain bytes (`hash_domain::single_block_seed_domain` returns
  the bare profile for a legacy-rule profile, `hash_domain.rs:240-243`).
  Draws in main's order and count: A mask and proximity rows (242 × 256
  `fp`), the A commitment (455 × 256 pads, then 2,048 salts), M in
  `mask_commit`'s order through its legacy twin, H mask rows (104 × 256),
  the two `u` rows (2 × 255, last = −sum), the H commitment. Transcript:
  `Transcript::new`, the same header absorbs (expected-IO, public statement,
  parameters, calibration, schedule), then A, M, β/γ/α, H, the argument,
  and openings M, A, H, IN, OUT. The refusal replays are still
  `clone_state` copies. The stage-28 byte-table inverses give the same words
  and the same refusal rule (at the toy every looked column is used).
* **One reorder, harmless:** the witness-SHAPE refusal now fires after
  `from_os` and the transcript header rather than before (`prove_core`).
  Same error string, nothing published, one discarded OS read; `witness::build`
  never produces such a witness.
* **The toy verifier: the same transcript operations; the same accepted
  frames.** The added T-4 path-depth refusals (`hash_domain.rs`, called at
  `protocol.rs:1064-1066`, `:1176`, plus `verify_zk_tagged`'s own) duplicate
  main's `wire::validate`; `spec.validate()` replaces `seams()` and adds a
  rows check the toy satisfies (7 = 7). Only refusal text and order move, and
  only for malformed receipts (F-4).
* `prove_inner` now takes the witness by value and drops its buffers earlier
  — memory only.

### 3.3 `hashline/src/private_block/argument.rs` — 25 hunks, +1208 −256

Table: `hunks_argument.txt` (25 hunks split into 49 entries): **40 × (ii),
8 × (i), 1 × (iii)** — the (iii) is F-2, a diagnostic print that changes no
receipt byte, no draw and no absorb.

* At the toy the axis logs are `lt 5, lh 1, ldh 3, ld 4, lf 4, lkv 0`; limbs
  4/2/2 with lookup scales 8/4/64; `sh.helpers` = 1, 19, 7, 6, 7, 5 (the
  unchanged `H_*`); `carries_pad_rule()` is false, so `pad::zero_rule_a_planes`
  returns empty and `supp` is `None` — **no `zeta`, no `mu_pad`, no extra `mu`
  entry, no support table**; the pad term evaluates to 0 and the gate to one.
  The stage-20 bilinear repair reduces to main's code at `lkv = 0`; the
  stage-28/29 table builders return the same words; the stage-35 closure
  rewrites are exact field identities.
* **Transcript: the same labels in the same order** — `pb-slot`, `c` (with
  the same zero-challenge refusal text), `pb-scalar`, the rounds, `pb-term`.
  Every `define` challenge length equals main's literal; no draw is added;
  degree and rounds per slot are main's `SLOTS`, so `d + 1` values per round;
  **34 functionals pushed in the same order**; claim sites pushed in the same
  order.
* One new refusal: a public table whose length is not `2^n` is refused
  before `pb-slot`. Schedule-driven, never fires on an honest toy run.
* **The Python ports still describe the toy** (`zk60_native_terminal_polys`
  pb00..pb22, and the declared functional order in
  `zk60_native_mask_commit`): equal field elements, unchanged push orders.
  Their `argument.rs:NNN` citations are main's line numbers and are stale
  (e.g. `run_slot 361-376` / `argument 924-925` are now `600-615` /
  `1876-1877`) — F-5.

### 3.4 `hashline/src/private_block/layout.rs` (10 hunks, +703 −93) and `wire.rs` (4 hunks, +329 −39)

Table: `hunks_layout_wire.txt`. **layout.rs: 0 × (iii)**, 2 items off-path
(`no_commitment_has_a_node_shaped_column(_under)`, called only from
`endpoint_g.rs`/`boundary.rs`; `with_io_mask_rows`, called only from
`run.rs`), the rest (ii). **wire.rs: 0 × (iii)**, 2 off-path
(`MAX_WIRE_BYTES_ANY`, the run-segment codec `HLPRUNS1`), the rest (ii).

* **The toy's numbers, re-derived by hand from `Shape::toy()`:** natural logs
  T 5, Ht 6, L/D/Q/F 9, Kv/Tab 8, S 11 (the old `Dom::log` table; the P-3 lift
  is the identity at the toy); norm window 29, softmax window 14, limbs 4/2/2;
  the `Ids` map the identity (18 contiguous segments ending at 81); `HIds`
  0/1/20/27/33, sexp 40, F 41, fact 46, tables 47–49, u 50, `n_h` 51;
  `lookups_at(toy)` = main's literal lookup list entry for entry (scaled
  coefficients 8, 64, 4 included); **rows A 455 / H 384 / M 50** (data 213 /
  280), **34 functionals, 23 slots, groups 35 / 9**, IO mask row 7 − 5 = 2
  (= main's `mask_row: 2`). The transcript-bound `describe()` renders
  identically and keeps the legacy label `private-block-t32/1` for the toy.
* **The frame is byte-identical.** Block and endpoint openings: 256 checks,
  vectors of 512, 2,048 encoded columns, path 11; mask opening 1024 / 1024 /
  256 columns × 50 rows, path 12; magic, header, field order, the `Reader`
  and the encode body unchanged; bound still 4 MiB. `encoded_len` recomputed
  from the constants: **2,816,472 B exactly.** `encode` / `decode` /
  `validate` accept and refuse the same frames as at `4751b93`, with the same
  error strings.
* A new construction refusal on the toy path (`layout.rs:1111`,
  `hash_domain::imposed_at_shape(sh).refuse(...)` over A 455 / H 384 / M 50 /
  endpoint 7) — fail-closed; that it passes at the toy rests on
  `hash_domain.rs` (F-1).
* **`Layout::new`'s toy freeze assertions (`layout.rs:1035-1053`) no longer
  run on the proving call** — F-3.
* Port: the constants the gates port are unchanged (`PB_*`, the literal
  lookups, `helpers`, `pow256`); only the citations moved (`lookups_at` at
  `:701`, `helpers` `:780`, `pow256` `:1300`) — F-5.

### 3.5 `hashline/src/private_block/witness.rs` (9 hunks, +480 −187) and `private_block.rs` (10 hunks, +527 −20)

Table: `hunks_witness_root.txt`. **witness.rs: 9 × (ii), 0 × (iii).**
**private_block.rs: 9 × (ii), 1 × (i)** (`to_bytes_at` / `from_bytes_at` /
`verify_bytes_at`, whose only callers are `cfg(test)`; plus the test-module
and `run` / `run_sink` / `boundary` declarations inside hunk 1), **0 × (iii).**

* **Witness: every committed value is computed identically at the toy** —
  isqrt, requant, both RMSNorms, QKV, RoPE, scores, integer softmax, PV, O,
  AO, both residuals, the SiLU feed-forward: the plane-id map leaves all 81
  ids unchanged, the head-slot map is the identity, the new support lists are
  `0..len` in order (so `quantize` returns the same values and fails at the
  same first index), every strided `matmul` / `matmul_in_out` / `rotate` call
  reduces to main's arguments, windows and shifts unchanged. The new `A_E`
  pad pass (`witness.rs:632-643`) cannot fire at the toy; the other new
  refusals are shape-only. No draw, no transcript, no hash, no print.
* **Condition 6 holds:** the toy branch of `prepare_endpoints`
  (`private_block.rs:863-866`) is main's body — `seams()`,
  `NttTables::new(12)`, `private_seam::prepare` for the input and then the
  output: two OS reads under the frozen 28-byte domain, in the same order;
  `private_seam.rs` is byte-identical. The frozen arm of `into_committed`
  (called at `protocol.rs:643`) is main's input-then-output sequence.
* **Condition 4 holds:** `Endpoints` and the new `EndpointOwner` have no
  `Clone` and no derive and are consumed by value; the compile-fail doctest is
  unchanged.
* `IoSpec::new` goes through `new_shaped` at the toy; its `validate()` is
  main's `seams()` check plus a rows check that holds (7 = 7); the new fields
  are toy constants and are not written into the 112-byte expected-policy
  frame. The attention and feed-forward constructors add weight-support
  checks that never refuse at the toy. `PROFILE`, the public structs,
  `absorb_into`, `digest`, `ExpectedIo`, `prove`, `verify`, `verify_bytes`,
  `to_bytes`, `from_bytes` and `capture` are identical text.

### 3.6 `hashline/Cargo.toml` — 1 hunk, +5 −0

One `[dev-dependencies]` entry, `private-block-kernel-shaped`, and its
comment. **(i) off every release path**: a dev-dependency is compiled for
test targets only; the only source uses of either kernel crate are
`parity.rs:23/27`, `refusals.rs:28`, `tests.rs:346`, all `cfg(test)`
modules; the examples mention them only in comments; `zkp-core` does not use
them (`path_closure.txt`). No feature names either crate. See §4.

### 3.7 The thirteen, in one table

| moved pin | hunks | (i) | (ii) | (iii) | reading |
|---|---:|---:|---:|---:|---|
| `hashline/Cargo.toml` | 1 | 1 | 0 | 0 | §3.6 |
| `hashline/src/pcs.rs` | 1 | 0 | 1 | 0 | §3.1 |
| `hashline/src/zk.rs` | 2 | 0 | 2 | 0 | §3.1 |
| `hashline/src/private_block.rs` | 10 | 1 | 9 | 0 | §3.5 |
| `private_block/argument.rs` | 25 (49 items) | 8 | 40 | 1 (F-2, a print) | §3.3 |
| `private_block/layout.rs` | 10 | 2 items | rest | 0 | §3.4 |
| `private_block/protocol.rs` | 12 (36 items) | 2 | 34 | 0 | §3.2 |
| `private_block/wire.rs` | 4 | 2 items | rest | 0 | §3.4 |
| `private_block/witness.rs` | 9 | 0 | 9 | 0 | §3.5 |
| `zkp-core/src/lib.rs` | 1 | 0 | 1 | 0 | §3.1 |
| `zkp-core/src/merkle.rs` | 4 | 1 | 3 | 0 | §3.1 |
| `zkp-core/src/pcs.rs` | 7 | 1 | 6 | 0 | §3.1 (one verifier-only check, F-4) |
| `zkp-core/src/transcript.rs` | 6 | 1 | 5 | 0 | §3.1 |

**No hunk of the thirteen changes the toy prover's draws, draw order,
transcript absorbs or squeezes, hash rule, commitment or opening order, or a
byte of an honest toy receipt, and none puts a hidden value in a buffer that
leaves the prover** — with the single exception of F-2's operator-switched
print, which reaches the prover's own stdout and nothing else.

**Conditions 1–6 of the statement against the snapshot.** 1 (one reserved
pair per claim site; `audit_claims`' exclusivity): `audit_claims` changed only
by taking `n = 256` as a parameter — holds. 2 (pads = opened columns): the
commitment twins draw `rows·q` pads with `q_pad = 256` and the frame checks
256 columns — holds. 3 (`d + 1` per round; exact-row-span assertions; the
zero-mask-challenge refusal; the declared functional order, 34 of 34):
`zk.rs`'s mask functions are identical, the argument's rounds and order are
unchanged — holds. 4 (one opening per commitment; a refusal terminal, by
type): holds (§3.5). 5 (every leaf salted; no unsalted column digest
published, logged or captured): every leaf goes through `salt_leaf_keyed(…,
None)` = `salt_leaf`; F-2's print carries counts, not digests — holds. 6
(fresh OS randomness; no seeded configuration): holds (§3.2, §3.5). §9 item
8 (no commitment of 5 or 8 rows, no transcript domain of length 28 or 35):
rows 455 / 384 / 50 / 7 and the domain bytes are unchanged — holds.

## 4. The Cargo manifests: can the observers reach a release build?

Read, not built (`cargo tree -e features` was not run; the manifests
suffice, because the question is whether anything declares or enables the
feature). `manifests.py` / `manifests.txt` run the joint-view gate's own
content assertion (`zk60_native_manifest_pins.assert_manifest_policy`,
finding P36-2) on the snapshot's bytes.

* **The observers do not exist in this tree.** `test-observers` appears in
  neither manifest and in none of the 179 files; `consumed_bytes`,
  `squeezes`, `draw_observer`, `OBSERVED_BLOCK_BYTES` likewise. There is
  nothing a release build could compile in.
* `zkp-core/Cargo.toml` = pin of record `b9038a52…`: no `[features]` table
  at all, no `resolver` key. Content assertion: **ACCEPTED** (`default`
  absent, token absent).
* `hashline/Cargo.toml` = lane base `e3acda1b…` (MOVED): main's bytes plus
  one `[dev-dependencies]` entry, `private-block-kernel-shaped = { path =
  "../private-block-kernel-shaped" }`, with a 4-line comment. Nothing in
  `[dependencies]` or `[features]` moved; no `resolver` key. Content
  assertion: **ACCEPTED**. The new crate has no dependencies and no
  features (its own manifest), and whether any non-test code names it is
  answered in §5.
* **Resolver (P36-3).** Neither manifest writes `resolver = "2"`; the lane
  added it only at stage 36+, which the snapshot does not carry. With no
  feature anywhere in a dev-dependency edge that could unify into the normal
  graph, the resolver version decides nothing in THIS tree; it becomes
  load-bearing again the day `test-observers` is integrated, and the explicit
  key should arrive with it.

## 5. The toy path's closure: files on it that no pin covers

The owner's ruling of 2026-09-20 22:06 extends the pin set to **every Rust
file the toy prover and verifier reach** (test-only modules and the three
fixture-only files excepted). At `4751b93` that was the 35 Rust pins. Traced
at the snapshot by `use`, `mod` and call site from `private_block.rs` and
`private_block/{protocol,argument,layout,wire,witness}.rs` outward
(`path_closure.txt`, with file:line for every edge), **six production files
are on the toy path and in no pin table**, all new in the snapshot:

| file | sha256 (snapshot) | reached from | what it decides at the toy |
|---|---|---|---|
| `hashline/src/private_block/shape.rs` | `dbf4e2bc36e9f74c432d6e529b229e3a593e794271fd8593d1412b8312403911` | `protocol.rs:663`, `:1160`; `layout.rs:1063`; `wire.rs:108`, `:237`; `private_block.rs:421`, `:539`, `:674` | **every toy number**: `Shape::toy()`, slots, claim sites, groups, receipt bytes, the profile string, `hash_tag()` (legacy), `carries_pad_rule()` (false), `endpoint_general` (false) |
| `hashline/src/private_block/hash_domain.rs` | `da61c1d97ca1cd6d35071e3917cfdb900a2039c5abd213cdfe2f0ccc251ed3cd` | `protocol.rs:688`, `:1064-1066`, `:1176`; `layout.rs:1111` | **the generator's seed domain** (the bare profile at a legacy profile); the T-4 path-depth checks; the C-H4/T-3 construction refusal |
| `hashline/src/private_block/pad.rs` | `f8b1f6c26d18eadf01eb5e8527f3a2e9620fad533b8ab332cd57a6014bf96df0` | `argument.rs:1115`, every slot | **the toy's challenge count**: its empty result at a no-pad-rule shape is what keeps the toy from drawing `zeta` or an extra `mu` entry |
| `hashline/src/private_block/timing.rs` | `f3d0befdaa09310914e14976ba6366a275b5d9ffd50b895794d93c27a1556feb` | `argument.rs:492-532`; `ph.mark` at `protocol.rs:689-1207` | the phase clock (inert unless `HL_PB_TIMING=1`; labels, durations, public sizes, RSS — timing, out of scope by D20/D21) and **the base-field census (F-2)** |
| `hashline/src/private_block/endpoint_g.rs` | `6e3691d0bfa1c1fb1f66b9be8ae5438597492c62dc00451d6f25dbff90ab84ce` | `private_block.rs:704`; `layout.rs:1138` | only the constant `MASK_ROWS = 5` and the `EndpointOwner` type; its `from_os` is the general endpoint's and is not reached |
| `zkp-core/src/hashtag.rs` | `71bf33150a296c2ce4da49d189c6d84a9f741b9ada1ef2488711938cffd6b651` | every `Transcript::absorb` / `squeeze_bytes`; every tagged twin | **the hash rule**: `hasher(None)` = `blake3::Hasher::new()` is what keeps every toy hash legacy |

None of the six constructs or draws from a `ZkRng` on the toy path or touches
the transcript (beyond `hash_domain` building the domain bytes and `hashtag`
supplying the hasher). Off the toy path: `boundary.rs` (`5b1c85fe…`),
`run.rs` (`f39aec79…`), `run_sink.rs` (`005bac23…`) are production code the
toy never calls; `plane_index.rs`, `slot_ir.rs`, `run_capture.rs`,
`run_statement_file.rs` and every capture hook are `cfg(test)`.

## 6. Findings

**F-1 — six production files on the toy path are pinned by nothing.
Severity: medium; it blocks re-establishing condition 7 until done.** §5.
Four of them carry a fact the whole reading above rests on — `shape.rs` every
toy number, `hash_domain.rs` the seed domain, `pad.rs` the absence of the pad
challenges, `hashtag.rs` the legacy hash — so after the 13 moves a one-line
change to any of them could move a toy byte, a draw or the hash rule and no
gate would notice. This is exactly the gap the 22:06 ruling closed at
`4751b93`; the snapshot re-opens it by moving logic out of pinned files into
new ones. It also means `Transcript::{absorb, squeeze_bytes}` — whose bodies
are NOT byte-identical to the pinned ones (§3.1) — are legacy only through a
function in an unpinned file. **Recommendation:** add all six to the pin set
at their snapshot digests, with the readings of §3/§5 as the record. (Where
they go is the owner's choice; `zk60_native_mask_commit.PATH_PINS` stales
~122 run-gate records, which is why rounds 9f and 9h used separate modules.)

**F-2 — an operator-switched diagnostic prints counts computed from the
hidden input. Severity: low-to-medium, operational; no receipt, transcript
or draw is affected.** `argument.rs:502-520` calls
`timing::base_field_census` (`timing.rs:342-391`) for every slot named in
the environment variable `HL_PB_BASEFIELD` (or `all`). It is compiled into
release builds, nothing restricts it by profile, so it runs at the toy, and
it prints to stdout, per table, how many words have a zero imaginary part.
Its doc comment (`timing.rs:332-337`) says that count "is decided by the
SHAPE of the table, not by the data". **That is false**, read here in the
code: a private table with `Coord::Fixed` coordinates or an `Fp2` slice
coefficient (`priv_table`, `argument.rs:204-256`) has entries `eq(z)·v` or
`coef·v` whose imaginary part is zero exactly when the hidden words are zero
(or equal, for a fold) — e.g. slot 19's table-helper planes, `inv·m`, are
zero exactly where the private multiplicity `m` is zero, so the count and the
"mixed tables" list reveal how many byte / exp / activation table entries the
hidden witness never uses; slot `SC_QMM`'s `A_Y` table gives the number of
all-zero columns of `y`. It is off by default, never enters a receipt, a
transcript or a capture (the capture runners strip `HL_*`), and goes only to
the prover operator's own stdout — so it is not a lapse of §2's sentence,
which is about the verifier's view. But it is a statistic of the hidden
input written to a log, and a retained log is the same kind of artifact §6's
"a retained capture bundle counts as publishing" rule exists for.
**Recommendation (the owner rules):** refuse it at `is_frozen_toy()` (or gate
it `cfg(test)`, or restrict it to tables without fixed coordinates or
extension coefficients), correct the doc comment, and in any case add to §6
that output of `HL_PB_BASEFIELD` from a run on a hidden input is never
retained. `timing.rs` should not be pinned (F-1) as-is without that ruling.

**F-3 — the toy freeze gate no longer runs on the proving call. Severity:
low.** `Layout::new`'s assertions of the frozen toy constants
(`layout.rs:1035-1053`) run on `to_bytes` / `from_bytes` / `encoded_len` /
`schedule` (`private_block.rs:929-983`), but `prove_inner_at` and
`verify_inner_at` build `Layout::for_shape(&Shape::toy())` directly
(`protocol.rs:676`, `:1171`). An encoded receipt still passes through the
gate; an in-memory prove-and-verify does not. The toy's layout at the proving
call now rests on `shape.rs` computing the right numbers (and on the lane's
tests), not on an assertion executed with every proof. Not a behaviour
change today (§3.4 re-derived every number); it is one more reason F-1's pin
on `shape.rs` matters. A one-line call to the freeze assertions from
`prove_inner`/`verify_inner` would restore it.

**F-4 — the verifier refuses malformed in-memory receipts earlier and in
other words. Severity: informational.** The T-4 path-depth checks
(`verify_zk_tagged`, `hash_domain::*_paths_are_the_tree_depth`) and
`IoSpec::validate`'s rows check are stricter than main's code in isolation,
but at the toy they duplicate what `wire::validate` already required of every
frame (`PATH = 11`, `MASK_PATH = 12`, 7 endpoint rows). The set of accepted
frames is unchanged; the prover and every honest receipt are untouched.

**F-5 — the Python ports' citations are stale, and the toy reaches the
ported functions under new names. Severity: informational (bookkeeping at the
re-pin).** The ported arithmetic is unchanged at the toy (§3.1, §3.3, §3.4),
so no port needs a value changed; but the toy now reaches the port's
subjects under other names — `mask_commit_tagged` / `mask_verify_tagged` /
`commit_zk_owned_with_tag` / `verify_zk_tagged` (with `HashTag::legacy()`) for
`mask_commit` / `mask_verify` / `commit_zk_owned` / `verify_zk`, and
`lookups_at` for `lookups` — and the `argument.rs:NNN` / `layout.rs:NNN`
citations are main's lines (`run_slot 361-376` → `600-615`, `argument
924-925` → `1876-1877`, `SC_DZC 699-748` → `1401-1544`). The re-pin records
should name the twins and the new lines, so the next reader of a port finds
the function the toy actually runs.

**F-6 — "the tag patches leave the legacy bodies byte-identical" holds for
the integrator's two patches, not for the whole hash layer. Severity:
informational.** Every legacy function in `hashline/src/{zk,pcs}.rs` and
`zkp-core/src/{pcs,merkle}.rs` is byte-identical (item comparison, 0
CHANGED). `zkp-core/src/transcript.rs` is the exception: the lane's stage-17
edit changed the text of `new`, `absorb`, `squeeze_bytes`, `clone_state` and
the struct; they are behaviour-identical under `key = None` (§3.1), which is
the toy's, and depend on `hashtag.rs` for it (F-1).

**F-7 — this snapshot is the lane at stage 35; the observer re-read and the
"six files" list do not describe it. Severity: informational, but it scopes
the next re-read.** Stage 36 (the observers) and stages 37–42 are absent
(§1). So: the six files statement §9 item 11 lists as owed "at integration"
are not this tree's list — here `rng.rs` and `zkp-core/Cargo.toml` are
unchanged and the obligation is the 13 + 6 of this page; the stage-36
pre-read's predicted merge digests (`rng.rs` `b9920aeb…`, `transcript.rs`
`b8a228d9…`, `protocol.rs` `e0e617be…`, `private_block.rs` `fa0daca6…`) and
`zk60_native_manifest_pins.EXPECTED_AFTER_INTEGRATION` (`0c746b9d…`,
`10d99a63…`) do not apply to it; §9 item 11's measured counts (327,052 draws
etc.) were measured on `29cba9a`, not on this tree. When stages 36–42 are
integrated — they touch at least `rng.rs`, `transcript.rs`, both manifests,
`protocol.rs`, `private_block.rs`, `layout.rs`, `witness.rs` (all differ
between `fee1a8d` and the lane tip in `pin_table.txt`) — that is another
condition-7 read, against the digests this page records as the new baseline.

## 7. Conclusion for condition 7

**Condition 7 CAN be re-established for the snapshot tree, and nothing in
the code blocks it** — no hunk of the 13 moved pins changes the toy prover's
behaviour, draws, transcript or hash rule, or the accepted frames. It needs,
in this order, the security owner's rulings on:

1. **F-2** — how the base-field census is handled at the toy (refusal,
   `cfg(test)`, or an operating rule) — before `timing.rs` is pinned.
2. **F-1** — the six on-path files join the pin set (Part B below).
3. **The 13 moves**, both (or all) digests kept, each with its reading
   (Part A below). For `zk.rs`, `hashline/src/pcs.rs` and
   `private_block.rs`, which already carry a second accepted digest, the
   snapshot's is a **third**. The captures of record keep their digests and
   keep passing.
4. **F-5** — the re-pin records name the tagged twins and the new line
   numbers.

Then, as at `4751b93` (round 9d), **recommended though not required by
condition 7**: a schema-3 capture of the integrator's new-tree toy receipt
(`baseline/native-block/block_receipt.bin` in its `/tmp` worktree, 2,816,472
B, `7eb33b93…`, built from exactly these 179 sources) replayed through both
toy gates, so that "the ports still describe the code" becomes "the ports
reproduce a receipt this code made". And **the digests must be re-hashed in
the integrator's COMMITTED tree**: this reading is of the archive; if the
committed integration differs from it by one byte in any of the 43 paths of
the resulting pin set (the 24 unchanged pins, Part A, Part B), the reading
does not transfer to that file.

**Part A — the 13 moves (add as accepted; keep every existing digest).**

| path | pin of record (kept) | other accepted (kept) | add |
|---|---|---|---|
| `hashline/Cargo.toml` | `eaba50ecf1434ad8514feb83c6e610b0d662b8fd6d512f26bacdde69163b860a` | — | `e3acda1bf4cf1a8cbbd671e51885a3e4b31b41e976f7ecf15057fdf0018015fc` |
| `hashline/src/pcs.rs` | `6d27f3a5bc28fb7bb57ab14ddb395f4c6911db2b8541876af73344125520d8a8` | `9537915b26b21ea906b0098d14afedf65c3d33320619bd380d4987d0c5fcf5a7` | `6f4b2cd4ef1128f85d1c813a2702e5bdfb5f5a99bb1c603dfa3b87340608314c` |
| `hashline/src/zk.rs` | `c5b54753d01d85f3469b8fbb873a36c7fcbc91faf15d16004f8cecff019c1310` | `ce8cc51648d0da51b56bb08109059171aca95c50828b7245b6b3b19e227de70b` | `07282c766e882029d6886fcaee27d1503d595af1839263f61c802fb3f1a0f18c` |
| `hashline/src/private_block.rs` | `5d9dd178beb708650d37a0af2bb7736e20c797cbb39d5ca7dfdadc300b48e001` | `412a43f488f809a5b479cf20690f06e35d79807c39d380f52abddb8966b09cf7` | `b4aeb6ed32331b29b3d470ca5fc2f4789c1f2f4a9785751ca52aacaa51a3300e` |
| `hashline/src/private_block/argument.rs` | `e62f46c29fe41848737e157b65c16d11d2c2c9501722b88660420a7a21a642ab` | — | `f7fa2ad4213d925b2d8dcb8d8273b92c6af2e9f90f94978da8630cc123fcef3d` |
| `hashline/src/private_block/layout.rs` | `6cc8f6fed8bc55ccb7cde23270976ed23912f768a6a60f3d392da08f2fcf0989` | — | `14758039fbe9daa61affa1316c6e4159437b98d888d72a926f6e70e788592b30` |
| `hashline/src/private_block/protocol.rs` | `d9455a1054aab7e18e1cba0194416a83847e862db26d8b4f5b9cf982ba082d65` | — | `ac4122375397a155d392df27a7e08f818ee78f80b38d41207565b325f5290413` |
| `hashline/src/private_block/wire.rs` | `5b11631d4c74b24d0ba82388385ad20c19c4304fa3a6c0026c0074b2c55d17d5` | — | `99e69b5c92154ed2ba44c6c568d14704ecd66ae2ee85b13ae337b6501bffc8a1` |
| `hashline/src/private_block/witness.rs` | `640754fb5b3acb85d383e7505e2e3f5ac6b41739d307c10f2f971819b7ab70a5` | — | `b9b66c024e7ca68d2a0ae4ba46241eb2abbccc8c8d94fe828041abbc710850ad` |
| `zkp-core/src/lib.rs` | `1c2a6ce1755df396d0e9f8c87eece27ac23657a24005b6d286ab5f551b7453fa` | — | `388f012fbb535617bc5a105de8640c84b5572544284cb4947a4ad7606e891164` |
| `zkp-core/src/merkle.rs` | `77bc5f51e5f11f150bec0813a2a810dd77d3dff3d1d4963e43a8923d106e4f62` | — | `6e7817bd767a883985bfcd62b7a387d0c5f4c361010c4c5db37f5087d965744a` |
| `zkp-core/src/pcs.rs` | `2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d` | — | `6b8d1bfa1a69293e0ea82df46a8b231d896043577e62ab3a837d3fbf743db81a` |
| `zkp-core/src/transcript.rs` | `31ce3c9a72da3bd3d6dcc9203c9ed7a51963cde462b59a66186467b4cb733da8` | — | `cc9752d0ef9bcd6d7b20e94e611ff26748593a2ea1a4f55b63d8c221715f1967` |

The one-line reason to record for each is its row in §3.7 and its section.
`argument.rs`, `layout.rs` and `protocol.rs` are pinned in BOTH
`zk60_native_mask_commit` and `zk60_native_terminal_polys`; they must move
together, or the record guard's two-tables-agree check fails.

**Part B — the six additions (F-1), at their snapshot digests:** `shape.rs`
`dbf4e2bc…`, `hash_domain.rs` `da61c1d9…`, `pad.rs` `f8b1f6c2…`, `timing.rs`
`f3d0befd…` (after the F-2 ruling), `endpoint_g.rs` `6e3691d0…`,
`zkp-core/src/hashtag.rs` `71bf3315…` (full digests in §5). The pin set
would then be **43 paths (41 Rust + 2 manifests)**.

**What is NOT established here.** No Rust was built and no gate was run;
the claims are readings of source, checked by scripts where a script could
check them (hashes, item identity, the twins, the manifest policy). The
integrator's cross-verification (new prover ↔ old verifier, old receipt ↔
new verifier; `baseline-validation.json`) was noted as consistent and was
not an input. No release-artifact symbol check was made (there are no
observers here to look for). Nothing here is a privacy acceptance and it
establishes no privacy property.

## 8. Evidence

All under `results/zk60_d22_preread_snapshot/`:

* `pins.py` → `pin_table.txt` — archive hash, the 179-file check, the 37-pin
  table read out of the joint-view pin modules, full digests against main,
  lane base, stage 36 and lane tip, and the whole-snapshot provenance split.
* `diffs.py` → `diff/*.diff`, `diffstat.txt` — every moved file's diff
  against `4751b93` (and against `fee1a8d` for the two "neither" files).
* `items.py` → `items_changed.txt` — the item-level comparison.
* `twins.py` → `twins.txt` — every tagged twin against its legacy original.
* `manifests.py` → `manifests.txt` — the manifest digests and the gate's
  own content assertion on the snapshot.
* `hunks_protocol.txt`, `hunks_argument.txt`, `hunks_layout_wire.txt`,
  `hunks_witness_root.txt` — the per-hunk tables of the six large files.
* `path_closure.txt` — the toy path's closure, with file:line for every edge.

The snapshot itself was extracted to `/tmp/claude-1000/d22-snapshot/`
(scratch, not kept); every script takes `--snapshot` to run against a fresh
extraction, and `pins.py` re-verifies the archive and all 179 hashes first.
