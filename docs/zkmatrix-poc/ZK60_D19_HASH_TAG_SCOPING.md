# ZK60 D19 — the separating hash tag for new profiles: scoping memo

Drafted by a delegated Opus agent for the security owner.
Read at 2026-09-20 14:05 PDT.
Source read: worktree `/home/victor/wt-zk60-block125m`, branch
`zk60-private-block-125m` (its gitdir is
`/home/victor/IntelligenceRegulation/.git/worktrees/wt-zk60-block125m`, whose
`HEAD` is `ref: refs/heads/zk60-private-block-125m`). A stage was in progress in
that worktree while I read; another agent may have uncommitted capture-writer
edits there. I read the working tree as it stood, touched nothing in it, ran no
build and no test, and wrote only this file.

Every number below is marked **[COUNTED]** (I derived it from the code, by hand
or with a throwaway arithmetic script over numbers read from the code) or
**[MODEL]** (an estimate, no measurement). I measured nothing.

---

## 0. The recommendation in one paragraph

Give every new profile a **BLAKE3 key per hash domain**, derived once from the
profile string, and select it through one new parameter that defaults to the
legacy unkeyed mode. Keyed BLAKE3 costs **exactly zero extra compressions**
[COUNTED from the algorithm: the key words replace the IV], so the 25%-of-prove
commit phase does not move, and the legacy path is byte-identical *by
construction* because the old functions keep their bodies and the new ones are
separate entry points. Five small additive changes to the integrator's files are
needed — `zkp-core/src/transcript.rs`, `zkp-core/src/merkle.rs`,
`zkp-core/src/pcs.rs`, `hashline/src/pcs.rs`, `hashline/src/zk.rs` — and
**nothing in `gpu/*`, `layer.rs`, `wcache.rs`, `native_capture.rs` or
`private_seam.rs`**. The answer to "can the tag be done without touching the
integrator's files" is **no**: every hash on the block's path is computed in
`zkp-core` or in `hashline/src/zk.rs`; the lane owns the *callers*, not one
hashing line.

---

## 1. Inventory: every BLAKE3 call on the private block's and the run's path

"Input layout" is the exact byte string handed to one `blake3::Hasher`
(concatenating its `update` calls) or to `blake3::hash`. Lengths are in bytes.
`|x|` is the byte length of `x`.

| # | What | Where (`file:line`) | Input layout | Length | Computed by | Owner |
|---|------|--------------------|--------------|--------|-------------|-------|
| T1 | transcript start | `zkp-core/src/transcript.rs:26-29` | `"hashline-v1/"` (12) ‖ domain | `12 + \|domain\|` | both | integrator |
| T2 | transcript absorb | `zkp-core/src/transcript.rs:45-51` | state (32) ‖ `len(label)` u64 LE (8) ‖ label ‖ `len(data)` u64 LE (8) ‖ data | `48 + \|label\| + \|data\|` | both | integrator |
| T3 | transcript squeeze | `zkp-core/src/transcript.rs:86-91` | state (32) ‖ `"squeeze"` (7) ‖ counter u64 LE (8) | **47** | both | integrator |
| P1 | column digest (single) | `zkp-core/src/pcs.rs:137-143` | the column's `rows` field words, little-endian, 8 B each | `8 · rows` | prover (verify side re-hashes the opened column) | integrator |
| P2 | column digests (tiled, the commit path) | `zkp-core/src/pcs.rs:147-165` (`blake3::hash` at :161) | same byte string as P1, per column, 64 columns per tile | `8 · rows` | prover | integrator |
| P3 | salted leaf | `zkp-core/src/pcs.rs:640-645` (`salt_leaf`) | column digest (32) ‖ salt (32) | **64** | prover at `pcs.rs:689`, verifier at `pcs.rs:1018` | integrator |
| P4 | Merkle inner node | `zkp-core/src/merkle.rs:14-19` (`hash_pair`) | left (32) ‖ right (32) | **64** | prover (`merkle.rs:22-35` `build`), verifier (`merkle.rs:56-63` `verify_path`) | integrator |
| P5 | root | — | not a hash; `levels.last()[0]`, `merkle.rs:37-39` | — | — | — |
| P6 | path verification | `zkp-core/src/merkle.rs:56-63`, called from `pcs.rs:489` (plain) and `pcs.rs:1019` (ZK) | repeated P4 | 64 each | verifier | integrator |
| R1 | RNG seed, fixture form | `zkp-core/src/rng.rs:21-25` | `"hashline-zk-rng/"` (16) ‖ domain ‖ seed u64 LE (8) | `24 + \|domain\|` | prover | integrator |
| R2 | RNG seed, OS form | `zkp-core/src/rng.rs:47-50` | **keyed** with 32 B of `/dev/urandom`; message `"hashline-zk-os-rng/v1/"` (22) ‖ domain | `22 + \|domain\|` | prover | integrator |
| R3 | RNG refill (XOF) | `zkp-core/src/rng.rs:54-58` | key (32) ‖ counter u64 LE (8) | **40** | prover | integrator |
| M1 | mask (`M`) column digests | `hashline/src/zk.rs:463` → `pcs::hash_columns` | as P2, `rows = 2·slots + 4 = 50` | **400** | prover | integrator |
| M2 | mask salted leaves + tree | `hashline/src/zk.rs:464-465` | as P3, P4 | 64 | prover | integrator |
| M3 | mask opening verify | `hashline/src/zk.rs:576-577`, column re-hash at `zk.rs:592-595` (`pcs_hash_column`, a private copy of P1) | as P1, P3, P4 | 400 / 64 | verifier | integrator |
| G1 | GPU column digests | `hashline/src/gpu/kernels.cu:512-579` (`b3_hash_column`), kernels `k_hash_cols` (`:582`) and `k_hash_cols_stream` (`:1429`), launched from `hashline/src/gpu/cuda.rs:1732, 2142, 2194, 2764-2768` | byte-identical to P2 by construction (`kernels.cu:447-453`) | `8 · rows` | prover, only with `--features gpu-cuda` **and** `HL_GPU=1` | integrator |
| B1 | public-statement digest | `hashline/src/private_block.rs:464-470`, feeding `absorb_into` at `:345-356` and `:425-435` | `"hashline/private-block-public/1"` (31) ‖ all attention words ‖ all feed-forward words, each length-prefixed | 31 + weights | both | **lane** |
| B2 | calibration identity | `hashline/src/private_block.rs:173-175` | `"B3 public fixed calibration v1"` | **30** | both | **lane** |
| B3 | block schedule digest | `hashline/src/private_block/layout.rs:1223-1231` | `"hashline/private-block-schedule/1"` (33) ‖ for each `describe()` line: `len` u64 LE (8) ‖ line | 33 + Σ(8+len) | both | **lane** |
| B4 | generalised-endpoint spec digest | `hashline/src/private_block/endpoint_g.rs:132-141`, `DOMAIN` at `:44` | `"hashline/private-block/general-endpoint/v1"` (42) ‖ context (32) ‖ 8 × u64 LE (64) ‖ scale i32 LE (4) | **142** | both | **lane** |
| B5 | internal-boundary spec digest | `hashline/src/private_block/boundary.rs:190-209`, `DOMAIN` at `:57` | `"hashline/private-block/internal-boundary/v1"` (43) ‖ context (32) ‖ 9 × u64 LE (72) ‖ scale i32 LE (4) | **151** | both | **lane** |
| B6 | frozen-seam spec digest | `hashline/src/private_seam.rs:115-133`, `DOMAIN` at `:26` | `"experimental-private-seam/v1"` (28) ‖ context (32) ‖ 8 × u64 LE (64) ‖ scale (4) | **128** | both | integrator |
| B7 | run public statement | `hashline/src/private_block/run.rs:159-166` | `"hashline/private-run-blocks/1"` (29) ‖ L block digests (32 each) | `29 + 32·L` | both | **lane** |
| B8 | run schedule digest | `hashline/src/private_block/run.rs:224-239` | `"hashline/private-run-schedule/1"` (31) ‖ for each line: `len` u64 LE (8) ‖ line | 31 + Σ(8+len) | both | **lane** |
| B9 | run segment position tag | `hashline/src/private_block/run.rs:339-346` (`position_tag`) | **no hash of its own** — two `challenge_fp2` squeezes (T3) from a discarded `Transcript::clone_state` | 47 × 2 | both | **lane** |
| B10 | run binding | `hashline/src/private_block/run.rs:263-265` | **no hash of its own** — the transcript state after the header | — | both | **lane** |
| B11 | run capture header rebuild | `hashline/src/private_block/run_capture.rs:257-268` | replays T1 + six T2 absorbs from copied public words; compares with B10 | as T1/T2 | capture (test-only) | **lane** |
| S1 | sumcheck round absorb | `zkp-core/src/sumcheck.rs:109` (prover), `:154` (verifier) | T2 with label `"sc-round"`, data `16·(degree+1)` | `56 + 16(d+1)` | both | integrator |
| S2 | run stage / slot / scalar / terminal absorbs | `run.rs:427-438, 562-567`; `argument.rs:311, 331, 362, 391`; `protocol.rs:94-99, 128-132, 641, 651, 749, 820-828` | T2, labels listed in §4 | see §4 | both | **lane** |
| C1 | run capture / run sink file digests | `run_capture.rs:317, 793, 964`; `run_sink.rs:29, 50` | **SHA-256**, not BLAKE3 (`crate::export_v3::sha256_hex`) | — | capture | **lane** |
| K1 | `private-block-kernel-shaped` | — | **hashes nothing** (grep over `private-block-kernel-shaped/src/{lib,tests}.rs` finds only comments) | — | — | — |

Two things to notice in this table.

* Every *hash* is in an integrator file. The lane's own BLAKE3 calls (B1–B8) are
  all **statement digests fed into a transcript absorb** — they never become a
  Merkle leaf or a node, and each one already begins with its own ASCII domain
  string.
* B9 and B10 are not hashes at all. The run's position tag and binding are
  transcript outputs, so they inherit whatever separation the transcript gets
  and need no rule of their own.

---

## 2. Ownership, call site by call site

**Lane-owned** (under `hashline/src/private_block/`, plus `private_block.rs`):
B1, B2, B3, B4, B5, B7, B8, B9, B10, B11, S2, C1, and every *call* to the
commit / open / verify entry points (`protocol.rs:637, 649, 745, 771, 775,
839, 852, 882, 949`; `endpoint_g.rs:204`; `boundary.rs:304, 254`;
`run.rs:438, 468, 476, 597, 627, 659`).

**Integrator-owned**: T1, T2, T3 (`zkp-core/src/transcript.rs`); P1–P6
(`zkp-core/src/pcs.rs`, `zkp-core/src/merkle.rs`); R1–R3
(`zkp-core/src/rng.rs`); M1–M3 (`hashline/src/zk.rs`); G1 (`hashline/src/gpu/`);
B6 (`hashline/src/private_seam.rs`); the dispatch adapter
`hashline/src/pcs.rs:36-84`; S1 (`zkp-core/src/sumcheck.rs`).

So: **the tag cannot be done lane-only.** The lane can change *which strings it
absorbs* and *which row counts it commits*, and nothing else.

---

## 3. What already takes a domain, label, context or key

* `Transcript::new(domain: &[u8])` — `transcript.rs:25`. The lane already passes
  the **profile string** here (`protocol.rs:93`, `run.rs:245`,
  `run_capture.rs:257`, `grow_tests.rs:1050`), and D17 already requires a new
  profile string per shape. **This is the hook the tag should reuse**: a key
  derived from the same string is automatic and cannot be forgotten.
* `Transcript::absorb(label, data)` — every absorb is labelled, and the label is
  length-prefixed (`transcript.rs:47-48`). Labels separate absorbs *from each
  other*; they do not separate the transcript from the Merkle tree.
* `ZkRng::new(seed, domain)` / `ZkRng::from_os(domain)` — `rng.rs:20, 30`. Both
  take a domain; `from_os` **already uses keyed BLAKE3**
  (`blake3::Hasher::new_keyed`, `rng.rs:47`), with the OS entropy as the key.
  So keyed mode is already in use in this codebase; there is no new dependency
  or new idiom to introduce.
* `PcsParams` (`pcs.rs:41-45`: `log_cols`, `inv_rate`, `num_col_checks`) and
  `ZkOpts` (`pcs.rs:533-537`: `q_pad`, `coset`) carry **no hasher
  configuration**. Both are `Copy` structs built by literal in several places,
  so adding a field to either would break existing construction sites; a new
  parameter is cleaner than a new field.
* **There is no generic hasher trait anywhere.** `zkp-core`'s only trait
  exports are `RoundMask` (`transcript.rs:12`) and `pcs::Backend` /
  `pcs::EncodedStore` (`pcs/backend.rs`, re-exported at `pcs.rs:38`). BLAKE3 is
  called concretely at each of the nine sites in the table.
* **There is a second hashing code path**: the CUDA column kernel (G1). It is a
  hand-written BLAKE3 with the IV hard-coded (`kernels.cu:474-477`) and no key
  input — keyed mode would need the key words to replace the IV at
  `kernels.cu:530, 536, 565` and the `KEYED_HASH` flag (`1<<4`) OR-ed into every
  compression. It is **off by default**: the `gpu-cuda` feature is opt-in
  (`hashline/Cargo.toml:25`) *and* gated at runtime by `HL_GPU=1`; without the
  feature the backend is `zkp_core::pcs::Cpu` (`gpu/mod.rs:257-262`) and the
  device store type is uninhabited, so the CPU body always runs. The private
  block nevertheless *routes through* the seam
  (`private_block/protocol.rs:637` → `hashline/src/pcs.rs:60-62` →
  `zkp_core::pcs::commit_zk_owned_with(&backend(), …)`), so a GPU build would
  pick it up.
* `blake3` is pinned at **1.8.7** in both lockfiles
  (`hashline/Cargo.lock:22-25`, dep declared `blake3 = "1.8"` in
  `hashline/Cargo.toml:29` and `zkp-core/Cargo.toml:9`). The vendored source
  (`~/.cargo/registry/src/*/blake3-1.8.7/src/lib.rs`) exports
  `keyed_hash` (`:949`), `derive_key` (`:1003`), `Hasher::new_keyed` (`:1097`)
  and `Hasher::new_derive_key` (`:1107`). Everything option A needs is already
  there. [COUNTED]

---

## 4. The present length classes at the four new shapes

Shapes read from `hashline/src/private_block/shape.rs:225-318`; commitment row
counts from `layout.rs:1011-1046` and the pins in `grow_tests.rs:270-332,
1379-1409`, `endpoint_g.rs:249-255`, `boundary.rs:341-345`. All **[COUNTED]**.

| Shape | profile string (len) | T / d / f | `log_cols` / `inv_rate` / Q | `A` rows | `H` rows | `M` rows | endpoint rows | boundary rows |
|---|---|---|---|---|---|---|---|---|
| toy (frozen) | `hashline-zk-mr1/private-block-t32-poc/1` (39) | 32/16/16 | 8 / 8 / 256 | 455 | 384 | 50 | 7 | — |
| rung | `hashline-zk-mr1/private-block-rung-t24-dev/1` (44) | 24/96/192 | 10 / 4 / 256 | 623 | 576 | 50 | 21 (frozen seam) | — |
| rung-G | `hashline-zk-mr1/private-block-rung-g-t24-dev/1` (46) | 24/96/192 | 10 / 4 / 256 | 623 | 576 | 50 | 9 | 10 |
| 125M | `hashline-zk-mr1/private-block-m125/1` (36) | 512/768/2048 | 14 / 4 / 256 | 5,681 | 7,120 | 50 | 37 | 38 |

### 4a. Column-digest input lengths (`8 · rows`)

| Shape | A | H | M | endpoint | boundary |
|---|---|---|---|---|---|
| toy | 3,640 | 3,072 | 400 | **56** | — |
| rung | 4,984 | 4,608 | 400 | 168 | — |
| rung-G | 4,984 | 4,608 | 400 | 72 | 80 |
| 125M | 45,448 | 56,960 | 400 | 296 | 304 |

### 4b. Transcript input lengths

Fixed for every shape (T2, `48 + |label| + |data|`):

| absorb | label | data | length |
|---|---|---|---|
| squeeze (T3) | — | — | **47** |
| `rows` | 4 | 8 | 60 |
| `pb-slot` | 7 | 8 | 63 |
| **`log-cols`** | **8** | **8** | **64** |
| `pb-run-stage` | 12 | 8 | 68 |
| `pb-term` (1…6 terminals) | 7 | 16k | 71, 87, 103, 119, 135, 151 |
| `pb-scalar` | 9 | 16 | 73 |
| `A` / `H` / `B` / `M` root | 1 | 32 | 81 |
| `schedule` | 8 | 32 | 88 |
| `calibration` | 11 | 32 | 91 |
| `pb-run-block` | 12 | 32 | 92 |
| `public-statement` | 16 | 32 | 96 |
| `sc-round` (degree 2…5) | 8 | 16(d+1) | 104, 120, 136, 152 |
| `run-shape` | 9 | 56 | 113 |
| `expected-IO` | 11 | 112 | 171 |

Shape-dependent:

| | toy | rung | rung-G | 125M |
|---|---|---|---|---|
| `Transcript::new` (T1) | 51 | 56 | 58 | **48** |
| `parameters` | 171 | 210 | 210 | 215 |
| `pcs-vec` / `pcs-prox`, block | 8,247 / 8,248 | 20,535 / 20,536 | 20,535 / 20,536 | 266,295 / 266,296 |
| `pcs-vec` / `pcs-prox`, endpoint | 8,247 / 8,248 | 8,247 / 8,248 | 20,535 / 20,536 | 266,295 / 266,296 |
| `mask-q` / `mask-prox` | 16,438 / 16,441 | same | same | same |

Fixed non-transcript lengths: **Merkle node 64**, **salted leaf 64**, **RNG
refill 40**, endpoint spec digest 142, boundary spec digest 151, calibration
identity 30.

### 4c. The coincidences

**The one in-profile coincidence, present at all four shapes** [COUNTED]:

> `tr.absorb_u64(b"log-cols", …)` — `protocol.rs:131`, also `run.rs` via
> `absorb_root`, also `private_seam.rs:253` — produces a BLAKE3 input of
> `32 + 8 + 8 + 8 + 8 = 64` bytes, **exactly the length of a Merkle inner node
> and of a salted leaf**. `"log-cols"` is 8 characters, and that is the whole
> reason. This is the overlap the earlier review flagged; it is not confined to
> the toy.

The concrete shape of the confusion: the 64-byte string is
`state(32) ‖ 08 00 00 00 00 00 00 00 ‖ "log-cols" ‖ 08 00 00 00 00 00 00 00 ‖ value(8)`.
For a Merkle node to equal it, the node's right child digest would have to be
that fixed 24-byte pattern followed by a chosen 8-byte value — a 24-byte
preimage constraint on a BLAKE3 output, about `2^-192` by chance. So it is a
structural defect, not a live break. [MODEL]

**No column digest coincides with any transcript input at any of the four
shapes.** [COUNTED] The nearest misses are worth recording, because they are
what the existing guard is protecting:

* `layout.rs:930-937` (`no_commitment_has_a_node_shaped_column`, code condition
  C-H4, called at `layout.rs:1046`, `endpoint_g.rs:107`, `boundary.rs:135`)
  refuses any commitment with **5 or 8 rows**, i.e. a 40-byte column (= the RNG
  refill block) or a 64-byte column (= a Merkle node).
* **C-H4's forbidden set is incomplete for the present label set.** Intersecting
  the transcript lengths above with multiples of 8 gives these additional
  dangerous row counts: **11** (`schedule`, 88), **12** (`public-statement`, 96),
  **13** (`sc-round` degree 2, 104), **15** (degree 3, 120), **17** (degree 4,
  136), **19** (degree 5, 152) — at every shape — plus **6** at 125M only
  (`Transcript::new` = 12 + 36 = 48) and **7** at the rung only
  (`Transcript::new` = 12 + 44 = 56). [COUNTED] The rung-G endpoint is 9 rows
  and its boundary 10, so the *next* plausible geometry is uncomfortably close
  to 11, 12 and 13.
* A cross-profile coincidence exists today and is invisible to C-H4: the **toy's
  7-row endpoint column digest is 56 bytes, which is exactly the rung's
  `Transcript::new` input length**. Different proofs, so nothing is broken; but
  it shows that C-H4's per-shape check cannot see the whole picture.

**Leaf vs node.** The salted leaf (`pcs.rs:640-645`) and the inner node
(`merkle.rs:14-19`) are the *same function on the same 64-byte shape*: leaf =
`blake3(colhash ‖ salt)`, node = `blake3(left ‖ right)`. The salt is fully
prover-chosen (drawn at `pcs.rs:674`, shipped in the opening at
`pcs.rs:591-599`). What stops the classic depth-confusion attack today is not
the hash: it is the **wire format**, which reads a fixed number of path entries
and a fixed row count from the shape
(`private_block/wire.rs:178-193`, `:188-193`), plus the absorbed `rows` /
`log-cols` words and the `col.len() != rows` check (`pcs.rs:1015-1017`). Note
that `pcs::verify_zk` **on its own does not check `path.len()`** — the loop in
`merkle.rs:56-63` folds however many siblings it is handed. The private block is
safe because of `wire.rs`, not because of `pcs.rs`. That is worth writing down.

---

## 5. The options

Costs are in BLAKE3 **compressions** (one 64-byte block = one compression; a
1,024-byte chunk adds one parent compression). [MODEL — arithmetic over the
counted row and column counts, no measurement.]

Hashing per 125M stage (A, H, M, one external endpoint, one boundary):
columns 112,095,232 compressions, salted leaves + inner nodes 532,475, total
112,627,707. The tree is **0.47%** of the hashing. At rung-G the tree is 5.6%;
at the toy 7.4% (the toy does not change).

### (A) BLAKE3 keyed mode, one fixed public 32-byte key per domain

Keys derived once with `blake3::derive_key(context, profile_bytes)` from four
distinct context strings (transcript, column, leaf, node), selected by a small
`HashTag` parameter whose legacy value is "all `None`" = the present unkeyed
calls.

* **Separates**: transcript vs Merkle vs column digest vs leaf vs node — all
  four pairwise, and, because the key is derived from the profile string, also
  **profile from profile**, which no other option does.
* **Files**: `zkp-core/src/transcript.rs`, `zkp-core/src/merkle.rs`,
  `zkp-core/src/pcs.rs`, `hashline/src/pcs.rs`, `hashline/src/zk.rs`. Not
  `gpu/*` (see §6). Lane side: `protocol.rs`, `run.rs`, `endpoint_g.rs`,
  `boundary.rs`, `run_capture.rs`, `shape.rs`.
* **Byte-identical old callers**: yes, by construction — the existing functions
  keep their bodies and the new ones are separate names / an extra argument that
  the old names supply as the legacy value.
* **Cost**: **+0 compressions**. The key words replace the IV; the message is
  unchanged. [COUNTED from the BLAKE3 construction; confirmed against the
  vendored 1.8.7 API.]
* **Verifier**: identical work, with the key.
* **Wire format** (`wire.rs`): **unchanged** — no field is added, no length
  moves. Receipt byte counts for new profiles stay exactly as
  `grow_tests.rs:1170` pins them.
* **Run capture** (`run_capture.rs`, schema `hashline-native-capture/4-run`):
  the header rebuild at `:257` must construct its transcript with the same key,
  one line. The schema gains one optional field (the tag name) if we want the
  bundle to record which rule made it; the allow-list test at
  `run_capture.rs:1226+` would need that key added.
* **Python tools**: they must learn `blake3.blake3(data, key=…)` for the
  transcript and the tree. I found one Python transcript reimplementation in
  this worktree, `results/zk60_form_e_check/jv_field.py:187, 210-213`; the
  joint-view / privacy replay tools on the other branch will need the same
  four keys, which is why the memo should publish them as hex literals.

### (B) A one-byte prefix tag per domain

* **Separates**: the same four domains, and nothing across profiles.
* **Files**: the same five, plus the GPU kernel if the column digest is tagged.
* **Byte-identical old callers**: only if the prefix is behind the same
  opt-in parameter — the prefix itself is not free, so it cannot be a default.
* **Cost**: a 64-byte node or leaf becomes 65 bytes = **2 compressions instead
  of 1**. Per 125M stage that is +532,475 compressions, **+0.47% of the
  stage's hashing** [MODEL] — small, but not nothing, and it is concentrated in
  exactly the shallow commitments (endpoint, boundary, M) where the tree is a
  third of the work. Tagging the column digest too adds one more block per
  column (+266,240 per 125M stage) **and** forces the CUDA kernel change.
* Otherwise equivalent to (A) and strictly worse on cost and on cross-profile
  separation. It has one advantage: a one-byte prefix is trivially auditable by
  eye in a hex dump, where a key is not.

### (C) Lane-only: never let a transcript input take a Merkle length

Concretely: in new profiles, rename `"log-cols"` to a 7- or 9-character label so
the absorb is 63 or 65 bytes, and extend C-H4 to the full forbidden row set of
§4c.

* **Files**: `protocol.rs:131` and `layout.rs:930` only. **No integrator file.**
* **Cost**: zero.
* **What it does NOT fix, honestly**:
  1. **The leaf/node ambiguity is untouched.** Salted leaf and inner node remain
     the same untagged 64-byte function. This is the binding question nobody has
     checked, and (C) does not answer it.
  2. It is a **standing obligation, not a construction**. Every future label,
     every future profile string length, every future row count has to be
     re-checked against the whole set. §4c already shows one such rule
     (`{5, 8}`) going stale.
  3. No cross-profile separation.
* It is, however, **worth doing anyway and independently** — the extended C-H4
  is cheap, changes no byte, and would have caught the 11/12/13-row cases.

### (D) A fifth option the code suggests: derive the tag from the profile string

Not an alternative to (A) but the way to wire it: `Shape` already carries
`profile: &'static str` (`shape.rs:92`), D17 already forces a new profile per
shape, and the transcript is already seeded from it (`protocol.rs:93`). If the
tag is `HashTag::for_profile(sh.profile)`, then **a new profile cannot exist
without a new tag** — which is exactly the obligation D19 states, discharged by
a type rather than by a reviewer's memory.

---

## 6. Recommendation

**Adopt (A) keyed mode, keyed off the profile string as in (D), and do (C)'s
extended C-H4 as well** — not as an alternative but because it is free, it
protects the toy (which keeps the legacy rule forever), and it is the check that
fails loudly if a future shape's geometry drifts.

### 6.1 The new type (new file `zkp-core/src/hashtag.rs`, ~40 lines, nothing else imports it yet)

```rust
/// A BLAKE3 key per hash domain. `None` everywhere is the LEGACY rule: the
/// unkeyed `blake3::Hasher::new()` line that produced every byte to date.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct HashTag {
    pub transcript: Option<[u8; 32]>,
    pub column:     Option<[u8; 32]>,
    pub leaf:       Option<[u8; 32]>,
    pub node:       Option<[u8; 32]>,
}

pub const LEGACY: HashTag = HashTag { transcript: None, column: None, leaf: None, node: None };

/// Every NEW profile's tag (D19). Distinct context strings; the profile id is
/// the key material, so two profiles can never share a tag.
pub fn for_profile(profile: &str) -> HashTag {
    let k = |ctx: &str| Some(blake3::derive_key(ctx, profile.as_bytes()));
    HashTag {
        transcript: k("hashline-zk-mr1 2026-09-20 fiat-shamir transcript"),
        column:     k("hashline-zk-mr1 2026-09-20 pcs column digest"),
        leaf:       k("hashline-zk-mr1 2026-09-20 pcs salted merkle leaf"),
        node:       k("hashline-zk-mr1 2026-09-20 pcs merkle inner node"),
    }
}

#[inline]
pub(crate) fn hasher(key: Option<&[u8; 32]>) -> blake3::Hasher {
    match key { None => blake3::Hasher::new(), Some(k) => blake3::Hasher::new_keyed(k) }
}
```

### 6.2 The additive changes to the integrator's files

Every one of these keeps the existing function with its existing body reachable,
so "old callers stay byte-identical" is a compile-time fact, not a claim.

**`zkp-core/src/transcript.rs`** — one field, one constructor, two one-line
substitutions:

```rust
pub struct Transcript { state: [u8;32], counter: u64, masker: …, masked_rounds: …,
                        key: Option<[u8;32]> }                 // NEW, last field

pub fn new(domain: &[u8]) -> Transcript                        // UNCHANGED, sets key: None
pub fn new_tagged(domain: &[u8], key: [u8; 32]) -> Transcript  // NEW
```
and inside `new_tagged`, `absorb` (`:45`) and `squeeze_bytes` (`:86`), replace
`blake3::Hasher::new()` with `crate::hashtag::hasher(self.key.as_ref())`.
`clone_state` (`:139`) copies `key`. With `key: None` the emitted code is the
same call, so the toy and every FFN / seam / attention / receipt caller is
byte-identical.

**`zkp-core/src/merkle.rs`** — three new functions, the three old ones become
one-line forwards:

```rust
pub fn hash_pair_keyed(a: &Digest, b: &Digest, key: Option<&[u8;32]>) -> Digest;
impl MerkleTree {
    pub fn build_keyed(leaves: Vec<Digest>, key: Option<&[u8;32]>) -> MerkleTree;
    pub fn verify_path_keyed(root: &Digest, idx: usize, leaf: &Digest,
                             path: &[Digest], key: Option<&[u8;32]>) -> bool;
}
```
`hash_pair(a,b) = hash_pair_keyed(a,b,None)`, and likewise for the other two.

**`zkp-core/src/pcs.rs`** — four new entry points:

```rust
pub fn salt_leaf_keyed(leaf: &Digest, salt: &[u8;32], key: Option<&[u8;32]>) -> Digest;
pub fn hash_columns_keyed(encoded: &[Fp], rows: usize, nn: usize,
                          key: Option<&[u8;32]>) -> Vec<Digest>;
pub fn commit_zk_owned_with_tag<B: Backend>(backend: &B, params: &PcsParams, data: Vec<Fp>,
        ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng, tag: &HashTag) -> CommittedZk<B::Store>;
pub fn verify_zk_tagged(params: &PcsParams, zk: &ZkOpts, cm: &Commitment, claims: &[ZClaim],
        opening: &OpeningZk, ntt: &NttTables, tr: &mut Transcript,
        tag: &HashTag) -> Result<(), String>;
```
`commit_zk_owned_with(…) = commit_zk_owned_with_tag(…, &LEGACY)` and
`verify_zk(…) = verify_zk_tagged(…, &LEGACY)`. `open_zk` needs **no** change: it
hashes nothing (it reads `cm.tree.path(j)`, `pcs.rs:930-942`).

**The GPU stays untouched, by one line inside the new function**: draw the pads
and salts first exactly as now (`pcs.rs:673-674`, the byte-order invariant), then

```rust
let dev = if tag.column.is_none() { backend.try_commit_zk(params, data_ref, &pads, &pows, ntt) } else { None };
```

A tagged commitment simply does not offer its column hashing to the accelerator,
so `gpu/kernels.cu` and `gpu/cuda.rs` are not in this change at all. New profiles
are CPU-only today, so this costs nothing now. When 125M wants the GPU, the
follow-up is a separate, later, reviewable kernel change: load the eight key
words in place of `b3_iv` at `kernels.cu:530, 536, 565` and OR `1<<4`
(`KEYED_HASH`) into the flags at `:541-542, 531, 567`.

**`hashline/src/pcs.rs`** — one adapter, five lines:

```rust
pub fn commit_zk_owned_tagged(params: &PcsParams, data: Vec<Fp>, ntt: &NttTables,
        zk: &ZkOpts, rng: &mut ZkRng, tag: &HashTag) -> CommittedZk {
    zkp_core::pcs::commit_zk_owned_with_tag(&backend(), params, data, ntt, zk, rng, tag)
}
```

**`hashline/src/zk.rs`** — the mask commitment is the only other place that
builds and checks a tree:

```rust
pub fn mask_commit_tagged(specs: &[(usize,usize)], ntt: &NttTables, rng: &mut ZkRng,
                          tag: &HashTag) -> MaskCommit;          // :430 body, keys threaded to :463-465
pub fn mask_verify_tagged(root: &Digest, specs: &[(usize,usize)], functionals: &[MaskFunctional],
                          op: &MaskOpening, ntt: &NttTables, tr: &mut Transcript,
                          tag: &HashTag) -> Result<(), String>;  // :552 body, keys at :576-577, :592
```
with `mask_commit` / `mask_verify` forwarding with `&LEGACY`. The private
`pcs_hash_column` (`zk.rs:592-595`) takes the column key.

**Not touched**: `hashline/src/gpu/*`, `layer.rs`, `wcache.rs`,
`native_capture.rs`, `private_seam.rs`, `zkp-core/src/rng.rs`,
`zkp-core/src/sumcheck.rs` (it only calls `absorb`).

**One accepted residual, stated plainly**: the **frozen-seam rung**
(`Shape::rung()`, endpoint rows 21) commits its endpoint through
`private_seam.rs`, an integrator file. Tagging it would mean a sixth additive
change. Since the rung is declared "development grade, never a deliverable"
(`shape.rs:229-233`) and `rung_g` exists precisely to move onto the lane's own
`endpoint_g.rs`, I recommend **tagging rung-G, 125M and the run**, and recording
the frozen-seam rung's endpoint as keeping the legacy rule. If the security
owner wants no exception, add `private_seam::prepare_plane_tagged` and the rung
comes along too.

### 6.3 The lane-side changes

* `shape.rs`: add `pub fn hash_tag(&self) -> HashTag { if self.is_frozen_toy() { LEGACY } else { HashTag::for_profile(self.profile) } }`. One place, keyed off the same predicate (`shape.rs:367`) every other freeze uses.
* `protocol.rs:93` and `run.rs:245` and `run_capture.rs:257`: `Transcript::new_tagged(profile, tag.transcript.unwrap())` when the shape is not the frozen toy.
* `protocol.rs:637, 745` and `endpoint_g.rs:204` and `boundary.rs:304`: the tagged commit.
* `protocol.rs:852, 882, 949`, `run.rs:597, 627, 659`, `boundary.rs:262`: the tagged verify.
* `protocol.rs:649/839`: the tagged `mask_commit` / `mask_verify`.
* `layout.rs:930`: replace the hard-coded `{5, 8}` with a shape-driven check that
  rebuilds the profile's transcript-input length set (T1 from the profile string,
  T2 from the label table, T3's 47, the RNG's 40, the node/leaf 64) and refuses
  any commitment whose `8 · rows` lands in it. Keep it for the toy, where the
  counted answer is still "455, 384, 50 and 7 are all clear".
* `run_capture.rs`: one extra field in the run JSON naming the tag, added to the
  allow-list at `:1226+`.
* `wire.rs`: **no change**, and that is a feature — the tag moves no byte of any
  frame, so `grow_tests.rs:1170`'s four receipt sizes are unaffected.

### 6.4 The tests that pin it

1. **The toy does not move.** `Shape::toy().hash_tag() == LEGACY` (an equality
   test, not a proof run); the existing `tests.rs:108`,
   `zero_witness_tests.rs:172`, `review_tests.rs:696` and
   `grow_tests.rs:497, 1170, 1184` frame-length pins and the toy prove/verify
   round trip stay green; `python3 -m unittest discover -s tests` plus
   freeze-check stay green.
2. **Cross-rule rejection, both directions.** Prove at rung-G with the tag and
   verify with `LEGACY` → the error must be a Merkle-path failure, by name.
   Prove with `LEGACY` and verify with the tag → the same. This is the test that
   makes the tag load-bearing rather than decorative.
3. **A leaf cannot be presented as a node.** For the same 64 bytes `(a ‖ b)`:
   assert `salt_leaf(&a, &b) == hash_pair(&a, &b)` under the legacy rule — that
   is the ambiguity, written down — and `salt_leaf_keyed(&a, &b, leaf_key) !=
   hash_pair_keyed(&a, &b, node_key)` under a tag.
4. **A transcript input can never equal a Merkle input.** Under a tag this is a
   key-separation fact, so pin it as such: the four derived keys are pairwise
   distinct and equal the documented `derive_key(context, profile)` outputs,
   asserted against hex literals in the test so the Python tools can be checked
   against the same numbers.
5. **The length rule still holds where no key does.** The extended C-H4 refuses a
   synthetic shape with 11, 12, 13, 15, 17 or 19 commitment rows, by name, at
   every profile; and refuses 6 at 125M and 7 at the rung. (`grow_tests.rs:1241`
   already sweeps the current rule and is the place to extend.)
6. **The run capture still rebuilds the binding.** `run_capture.rs:269-271`'s
   "the rebuilt run header is not the verifier's binding" path must not fire at
   a tagged profile — i.e. the capture's transcript is constructed with the same
   tag.
7. **The accelerator seam is honest.** A test that a tagged commitment does not
   call `Backend::try_commit_zk` (a counting stub backend), so the CPU/GPU parity
   question cannot be answered wrongly by accident.

---

## 7. What I did not check

* **I ran nothing.** No `cargo`, no test, no build, no git write. Every "cost"
  is arithmetic over counted row and column counts, marked [MODEL]. I did not
  measure the commit phase, so I cannot say what fraction of the 25% is hashing
  versus NTT encoding.
* **The integrator's in-flight uncommitted work.** I read the committed state of
  `/home/victor/wt-zk60-block125m` only. If the integrator's working copies of
  `zk.rs`, `pcs.rs`, `gpu/*` or `zkp-core/` already move these functions, the
  line numbers and possibly the shape of the additive change will differ.
* **Whether the CUDA path has ever been exercised for the private block.** I
  established that the seam routes through it and that it is off by default; I
  did not look for evidence of a GPU run at any private-block profile.
* **The Python privacy / joint-view tools.** They are on another branch. In this
  worktree I found exactly one Python reimplementation of the transcript
  (`results/zk60_form_e_check/jv_field.py:187, 210-213`) and no Python that
  recomputes a Merkle root from salted leaves. Ten scripts mention "merkle" and
  ten call blake3; I did not read them to see which ones would have to learn the
  tag.
* **Every caller outside the private block.** I listed the other users of
  `hash_pair` / `salt_leaf` / `hash_columns` / `Transcript::new`
  (`layer.rs`, `wcache.rs`, `pcs_compact.rs`, `stable_weight_material.rs`,
  `causal_oracle.rs`, `public_block_receipt.rs`, `public_block_oracle.rs`,
  `model_identity.rs`, `private_attention/`, `zk_ffn_*`, `bin/hashline.rs`) but
  did not audit each one; the argument that they are unaffected rests on the
  legacy functions keeping their bodies, not on having read them all.
* **Frozen artifacts outside `hashline/`.** I checked that `zkvm-block/`,
  `zkvm-native-tools/` and `scripts/` contain no copy of the `"hashline-v1/"`
  transcript rule or of `salt_leaf` / `hash_pair`; I did not check the
  `results/` capture bundles for pinned digests that a tag would invalidate.
* **The exact `B1` / `B3` / `B8` digest input lengths.** They depend on the
  weight tensors and on the `describe()` strings; I gave their prefixes and
  structure, not their totals. None of them is a Merkle input, so the omission
  does not affect the coincidence analysis.
* **Soundness of the construction as a whole.** This memo is about hash-domain
  separation. It is not a privacy review, not a security acceptance, and it
  changes nothing about D22's scope.
