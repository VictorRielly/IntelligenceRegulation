# Fable lane handoff — branch `zk60-mvp-fable` (pushed; tip `679ac26`, base `763e308`)

Written by the interactive Claude Fable 5.1 session on 2026-09-18 so the
integrator can find two unreviewed deliveries. This file is a pointer only;
the shared boards are the integrator's.

## 0. CURRENT — read this first; everything below is a dated log

### 16:58 (2026-09-23) — two notes on YOUR files from the blinding-law check (LW-4), a proposed operating rule D23, and the lane tip (test-only additions)

- **LW-4** (`ZK60_BLINDING_LAW_GR4_DISPOSITION.md`): `CfsMask` is `Clone`
  and `CommittedZk`'s fields are `pub` — a clone of a mask or a written
  commitment field is a way to reuse blinding that no test forbids. The lane
  made `ZkRng` non-Clone for the same reason; offered, your call.
- **What protects against reuse today, now tested:** lane stage 47
  (`32c11d9`) brought in a seeded root-rebuild check (`gr4_check_tests.rs`)
  that rebuilds A, M and H from the witness and the predicted generator
  stream WITHOUT calling the commit functions and requires the roots to
  match. Three mutations that copy blinding between commitments (including
  one inside `zk::mask_commit_tagged`) are caught by it and MISSED by stage
  36's value scan (blind to `*x = rng.fp()` lines and to α). Any change you
  make to the commit functions' draw order will fail it on purpose — it is
  the byte-level contract for the draw sequence.
- **Proposed D23 (Victor's):** an accepted receipt's endpoint roots are never
  registered, republished or referred to by a later artifact (the privacy
  case's O-2, never listed until today). For your CLI / publication
  boundary: do not record accepted toy receipts' endpoint roots anywhere a
  later artifact checks against, and do not chain them into another proof.
- **Lane tip `32c11d9`:** everything after the named stable tip `1ab1498` is
  test-only or `#[cfg(test)]` (stages 45–47: the standalone shaped capture,
  draw measurement at rung-G / 125M, the root-rebuild check) plus two
  comment fixes; filter 499/0/21.

### 09:20 (2026-09-23) — one rule for your production caller (CLI): VERIFY BEFORE TRANSMIT, for every shaped block and run receipt (ruling HB-1); and the standalone 125M block now gated

- **HB-1** (`ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK_DISPOSITION.md`): the
  block prover deliberately has NO output-equality precheck
  (`protocol.rs:770-771` on the lane: an endpoint committed to other values
  must fail the verifier's identity — the soundness tests rely on it). So a
  mis-sealed Output endpoint yields an assembled receipt the verifier
  rejects, whose view depends on the mismatch. **D21 therefore rests on the
  caller: run the verifier on the receipt before it leaves the prover, for
  a standalone block exactly as M-9 already requires for a run.** Together
  with CS-6 (compare the run statement's block digests with the blocks
  fetched), that is what the CLI / publication boundary must do.
- **Standalone shaped block through the whole gate** (joint-view round 9j,
  `b7fd6c8`): lane stage 45 (`544fbaf`) added a `#[cfg(test)]` verifier-side
  capture, schema `hashline-native-capture/5-block-shaped`; at 125M every
  predicted figure held, full preimage 4,144,778 entries 0 differing, A 0 /
  H 2 / endpoints 0, joint 2 = sum 2, channels 28 at 10/5/5/8. The paper
  half (hash layer at L = 1) is ruled: 2^-72.86 per 125M proof, hash terms
  37 bits below. Nothing accepted; D19b (Victor) and G-R1/G-R2/G-R4 remain.
- **Lane tip is now `544fbaf`** (stage 45 = test-only capture hooks on top
  of the stable `1ab1498`); `1ab1498` stays the tip I named for integration —
  `544fbaf` adds only `#[cfg(test)]` lines and test files (I read them).

### 02:55 (2026-09-23) — STABLE LANE TIP for your next integration: `zk60-private-block-125m` at `1ab1498` (pushed); independently code-reviewed, no soundness or completeness regression, no receipt byte moved

- **What the tip adds after your fixed snapshot (`fee1a8d`):** stage 36
  (test observers, pre-read at `a8e4939`), stage 37 (rung-K8, lkv = 3,
  test-only), and stages 38–44: the shaped refusal census and the
  statement-admissibility rulings of `ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md`
  §2–§9 — every part of a block / run statement and every shape re-checked
  against what it is proved at, before any absorb, commit or draw (CS-1,
  CS-4, CS-8); undersized window overrides, `f_e` outside 4…31 and width
  above 16,384 refused (CS-2, C-6, CS-5); a lookup miss is one named prover
  refusal with no witness-derived value in its text (CS-3, K-1, K-2); a run
  statement's block digests must equal the blocks proved / verified (CS-6 —
  **the one your run CLI needs**); a run profile names one run shape (CS-7)
  and **a block profile string names exactly one geometry** (CS-9, a
  registry; unregistered strings only under `cfg!(test)`); test-only bypass
  `CheatingProver` shown absent from a release build.
- **Evidence:** lane filter `--lib private_` **487/0/18** at
  `--test-threads=6` (22 threads OOM under an 8 GiB cap); toy receipt
  2,816,472 B and every frame / receipt / schedule / slot-IR / 125M / R-5 /
  registry / source-pin / hash-call-site pin unchanged. Independent
  adversarial code review of stages 39–43 (review branch `dc12f44`,
  `ZK60_LANE_S39_S43_CODE_REVIEW.md`): no soundness regression (every
  verifier hunk adds or widens a refusal), no completeness regression on 29
  honest inputs across the registered shapes, ordering holds, only CS-3
  reads the witness. Stage 44 fixed its four findings.
- **Lane production files changed since `fee1a8d`:** `private_block.rs`,
  `private_block/{shape,protocol,witness,run,layout,timing}.rs`,
  `run_statement_file.rs` (test-only reader), plus stage 36's `rng.rs` /
  `transcript.rs` / manifests. Digests per stage in the lane ledger.
- **D22 at integration (my part, when you commit):** the re-pin of the
  pre-read (43 paths, rulings P-1…P-4) takes `shape.rs`, `timing.rs`,
  `protocol.rs`, `private_block.rs` at THIS tip and lists CS-3 and CS-9 as
  refusal sites on the toy path (both pass every admitted toy input
  unchanged, by review). If you integrate `fee1a8d` first and this tip
  later, I re-read twice; one integration of `1ab1498` is one re-read.
- Nothing is running on the lane. Awaited: your commit of the integration
  tree; your answers on R1d (R-1…R-4, R-9) and R2a (U-2).

### 01:37 (2026-09-23) — your three review asks answered: the D22 pre-read of your snapshot (condition 7 re-establishable, pin set → 43 paths), R2a sound, R1d correct but not landable yet

Read from your uncommitted coordination note (main working copy). All
three reviews are independent agents' readings, pushed on this branch.

- **D22 pre-read of `reviewed-source.tar.gz`** (`c794360a…`, all 179
  hashes verified; `ZK60_D22_PREREAD_SHAPED_SNAPSHOT.md` + my rulings §9):
  nothing on the toy path changes behaviour — the toy now reaches the tagged
  functions with `HashTag::legacy()` and each was compared line by line with
  its legacy original (same draw order, same absorbs/squeezes, unkeyed hashes;
  `transcript.rs` is the one legacy text that changed, identical through
  `hashtag::hasher(None)`); receipt frame 2,816,472 B. 24 of 37 pins equal,
  13 moved. **Rulings:** P-1 six unpinned files on the toy path join the pin
  set (`shape.rs`, `hash_domain.rs`, `pad.rs`, `timing.rs`, `endpoint_g.rs`,
  `zkp-core/src/hashtag.rs` → 43 paths); **P-2 `HL_PB_BASEFIELD` /
  `HL_PB_TIMING` output is prover-private under D21** (the census counts
  depend on the hidden witness; the lane corrects the comment) — never put it
  in a bundle or a published log, leave both unset in production runs; P-3
  freeze assertions now run at serialisation (note); **P-4 the re-pin happens
  when you COMMIT the integration tree** — re-hashed there, every existing
  digest kept, both toy gates replayed on a capture of your new receipt
  `7eb33b93…`. D22 stays in force for main `4751b93` meanwhile. Note: the
  snapshot is the lane at stage 35 — stages 36–42 need their own
  condition-7 read at their integration (F-7).
- **R2a** (`ZK60_R2A_UNSAFE_REVIEW.md`): **both unsafe boundaries sound**, no
  UB found; the reviewer's own harness (1,291 shapes, 1/2/3/8 threads, an
  injected worker panic; your first candidate fails it) is in the doc's
  appendix. Optional hardening U-2: count rows in the workers and assert
  `== rows` before `set_len`. Correction to my 13:40 ask (U-7): only the
  TAGGED arm changes; `:732` is the untagged `commit_zk_owned_with` and keeps
  its zero fill. Miri/sanitizers not run (none installed).
- **R1d** (`ZK60_R1D_ROUND_INTERFACE_REVIEW.md`, reading only): **the
  s(1) recovery, the Private seeding and the additive interface are
  correct**, and fully evaluating round 0 of host/standalone slots is the
  right call. **Not landable yet:** R-1 it touches three D22-pinned files and
  adds `rounds.rs` on the toy path (condition-7 read at landing; moving
  `masked_prove_rounds` out of `zk.rs` would spare the security probe's pin);
  R-2 validated at the stage-35 base — re-run against the lane tip so the
  stage-40 `CheatingProver` soundness harness runs against it, plus the
  integration tests, Python suite and freeze-check; R-3 the in-process
  oracle silently skips slots above 2^18 words, so no time-carrying 125M
  slot was byte-compared — record skips and compare at least one large
  slot; R-4 take the Private seed from the computed total, not back out of
  the published scalar; **R-9 some failure messages print secret-derived
  values — D21 says a refusal reason is never shown to anyone not entitled
  to the input**. Expected saving ≈ 8% of the counted baseline, not 15.8%;
  your A/B (6.3% on summed sumcheck phases, no end-to-end claim) agrees.
- Lane: stage 43 (the CS-8 sweep of constructor-established invariants) is
  running; after it, an independent code review of the lane delta since
  `27398d0`, then I name a stable tip for you. MVP_STATUS / START_HERE /
  TASK_BOARD carry your uncommitted edits — I have not touched them.

### 00:45 (2026-09-23) — for your run CLI: a run statement's block digests were never compared with the blocks proved or verified (S41-N2 → ruling CS-6, being built); and the lane's statement-admissibility work since 21:53

- **CS-6, read by me in `run.rs`:** `prove_run` and the run verifier absorb
  the STATEMENT's `block_digests[k]` (`:602`, `:752`) but prove / verify
  against the `BlockPublic` values they are HANDED; nothing compares
  `blocks[k].digest()` with `st.block_digests[k]`. A statement naming block
  X, proved with block Y, is accepted by a verifier handed Y. Today's callers
  build the statement from the same blocks (`:207`), so no recorded run is
  affected — **but your run CLI / publication boundary is exactly the caller
  that would read a statement from disk and fetch blocks separately.** Lane
  stage 42 (running) adds the comparison, by name and before any absorb, in
  `prove_run`, `RunVerifier::start` and every statement reader. Until it
  lands, a CLI must make that comparison itself. Also CS-7: a run profile
  will be accepted only over the block shape it is registered for.
- **Statement admissibility, lane stages 40–41 (`c735d77`, `17d10ac`, both
  pushed), rulings in `ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md` §2–§6:**
  every part of a block statement (feed-forward and attention weights, gains,
  rotary and exp tables, the endpoint policy) is re-checked against the shape
  it is proved at, at the builder and every prover / verifier / run entry,
  refusing by name with 0 draws and the transcript unmoved (CS-1, CS-4);
  undersized window overrides, `f_e` > 31 and width > 16,384 are refused by
  `Shape::new` (CS-2, C-6, CS-5); a lookup miss is one named prover refusal
  before the first `A` mask draw (CS-3; its test-only bypass
  `CheatingProver` is `#[cfg(test)]` throughout — read by me). **No byte of
  any receipt moved**; lane filter 463/0/18 at `--test-threads=6`. Lane
  production files moved since `27398d0`: `private_block.rs`, `shape.rs`,
  `protocol.rs`, `witness.rs`, `run.rs` (+ a `layout.rs` comment) — digests
  in the lane ledger, stages 40–41. Two of the holes closed were
  input-dependent (an undersized `wrho_s` override; an exp-table scale built
  for another shape): the failure class that leaks. None was reachable by a
  registered shape with its own statement.
- The same evening: rung-K8 (lkv = 3) through the whole run gate (round 9i,
  R5.8 item 3 closed); GS-13 ruled. Awaited, unchanged: your snapshot's
  commit id; R1d, R2a, the interface, the buffer-review list. D19b is
  Victor's.

### 21:53 (2026-09-22; first written "22:05" before reading the clock) — three lane stages after your snapshot: lkv = 3 proves (37), a shaped refusal census (38) found one public-only completeness hole at the padded development rungs, fixed by a named refusal (39); GS-13 ruled

- **Lane tip `27398d0` (pushed).** Your fixed snapshot is `fee1a8d` (+ stage
  36 at `29cba9a`, pre-read at `a8e4939`). The delta after `a8e4939`
  contains **ONE production change**, everything else test-only or docs:
  `hashline/src/private_block.rs` `FeedForwardPublic::new_shaped` refuses,
  by name, `act[128] != 0` at any shape whose `Dom::F` pads (`sh.pads(Dom::F)`;
  9 lines, `7472a3c`, read by me). Nothing new is absorbed; the toy receipt
  (2,816,472 B), every shaped length and schedule digest are unchanged.
  `private_block.rs` digest moves (`b6728273…` at stage 38 → `29ba0084…`); the
  gate re-pins per bundle source commit.
- **Why (finding S38-F1, `ZK60_SHAPED_REFUSAL_CENSUS.md` §6 on the lane):**
  where the feed-forward domain pads (frozen-seam rung, rung-G, rung-K4,
  rung-K8 — NOT the toy, P2, C6, W14, E32 or 125M) every pad looks up the
  activation pair (128, 0), which is a table row only when `act[128] == 0`;
  the constructor admitted any table, and with `act[128] = 1` every honest
  proof was refused at the verifier (`H: pcs zk: group 8`), reproduced
  failing-first. Every SiLU member has `act[128] = 0`, so no run ever hit
  it. Public-only: no leak. Ruling S38-F1(a); the alternative (pad =
  `act[128]`, `A_A16` exempt) would move every shaped receipt and is not
  taken. **If your integration carries the dev rungs, take `7472a3c`.**
- **Stage 38's census** (34 data-dependent sites × 10 shapes, bounds derived
  from the `Shape`): every reachable site is refused by the witness builder
  first with the same bound; `AO` becomes reachable above width 258 (C6,
  W14, E32, 125M) and is covered at `witness.rs:594`; 37 edge proofs pass,
  one step past each edge is refused by name. **Stage 37:** rung-K8 (16
  q-heads over 8 KV, lkv = 3) proves and verifies as a block and a 3-block
  run on a dense generic witness, 4,780,216 B = the layout model; capture
  bundles `results/zk60_run_captures_20260922_k8/` (gate round 9i reading
  them now).
- **Test hygiene you will meet (S38-N1, fixed test-only at `cfc48a3`):** a
  stage-35 test counted a process-wide observer counter and failed under
  parallel threads; it now reads a per-thread count. Also: the lane filter
  OOMs at 22 threads under an 8 GiB cap — run it at `--test-threads=6`
  (440/0/18, 137 s, peak 4.28 GB).
- **GS-13 ruled** (`ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md`, main): the
  non-linear channel lifts to the shaped layouts as an algebraic reading;
  no code consequence. For P3: hidden weights remove the matmul slots' only
  public factor (NL-7).
- Awaited, unchanged: your snapshot's commit id; R1d, R2a, the interface,
  the buffer-review list. D19b is Victor's.

### 19:50 (2026-09-22) — your committed toy bundle (`eaaac8f`) is the one replayed at 10:22; the gate passes on the committed directory as delivered

- Your 19:36 commit carries the 07:25 note and the bundle that round 9d
  already replayed this morning (joint-view `d837d50`): the capture JSON's
  digest `e8d3c55b…` is the one in 9d's record, so nothing new is owed on
  it. As a check that the commit did not change the delivery, the pinned toy
  gate (joint-view `d5dbd33`, `--controls-on all`) was run directly on
  `results/zk60_security_probe_repin_20260922/`, with no shim: **exit 0, ok,
  manifest `capture-validation.json` present, 1 of 1 checked, 0 mismatches;
  28 channels at 11 constructed / 2 derived / 8 argued / 7 open; 14 controls
  fire** — the figures of record. The record (`privacy_gate.json`, SHA-256
  `ff394769…`) and its log are in
  `results/zk60_toy_bundle_commit_check_20260922/`.
- Stage 36 (the observers you authorised at 07:25) landed at 09:00 (lane
  `29cba9a`, handoff 08:58); its D22 condition-7 pre-read is done (review
  `8505810`). Your note's other items were answered in the 07:50–10:48
  entries below.
- **Awaited, unchanged:** your integration snapshot's commit id (the D22
  re-pin against YOUR tree waits for it — `/tmp/wt-zk60-shaped-20260920`
  is still at `4751b93` with uncommitted assembly); your read of R1d, R2a,
  the interface and the buffer-review list. D19b is still Victor's.

### 14:12 (2026-09-22) — the seed of a device-NTT conformance harness exists and is Rust-verified at every registered width, the 2^14 row included

- Since the commitment's time is the ENCODE (13:40), the harness a device
  encode must pass was built today from a THIRD implementation:
  `ZK60_ENCODE_CONFORMANCE_VECTORS.md` + `results/zk60_encode_vectors/`
  (main, pushed) — a Python `encode_row_zk` written from the code with every
  constant at `file:line` (p, generator 7, the pinned two-adic root, ONE
  twiddle table indexed `tw[k·max_n/len]`, bit-reversal on the INPUT, the
  inverse's 1/n after the butterflies, coset h = 7, the pad mixed into the
  coefficient vector between the two transforms), self-checked against the
  O(n²) definition and a Lagrange closed form at the production widths; 35
  vectors over the seven (width, rate) profiles; five NAMED negative
  controls at 2^14 (DIF/bit-reversed output — differs at 65,280 of 65,536
  entries, the 256 bit-reversal fixed points survive; conjugate root;
  twiddle stride off by one; inverse scaled by 1/nn; `tw[k]`), each with its
  own digest so a device bug is identified by WHICH wrong digest it makes.
- **Rust-verified (review branch `3257c33`, pushed;
  `zkp-core/src/pcs/encode_conformance_tests.rs`, six tests, `zkp-core` 62
  passed / 0 failed):** the listing compiled and passed unchanged — whole-row
  digests at 2^10 rate 4 and at 2^14 rate 4 (65,536 entries), the widths no
  bundle could check; bit-reversing the row Rust itself produced hashes to
  the ordering control's digest; a deliberate coset perturbation fails five
  of six. **For your device work: the vectors are the target; `dev_hash_check`
  is not, and neither is the verifier (0.39% of columns).** A device encode
  that reproduces `bf144694…` for the seeded 2^14 row is byte-identical on
  that row; one that produces `43c5b6d1…` has the DIF ordering bug, and so
  on down the table.
- Partial cross-check from published data, for the record: the verifier's
  proximity identity holds 256 / 256 on all 16 role-commitments of the four
  committed toy bundles under the reference (the ordering bug would agree at
  10 / 256 there — the fixed points).
- Note: the new test file under `zkp-core/src` bumps the 5090 preflight's
  newest-source time (the gate working, not damage).
- Awaited unchanged: your snapshot's commit id; your read of R1d, R2a, the
  interface, the buffer-review list; D19b with Victor.

### 13:40 (2026-09-22) — stage 0.5 MEASURED: the commitment's time is the ENCODE, not the hashing (3.7 : 1) — so the keyed CUDA hasher moves down the list; and one cheap item in your file, R2a: a 3 GB memset nobody reads

- **The split at 125M [MEASURED, 3 repetitions, two agreeing heavy runs,
  shared box; review branch `81c519a`, `results/zk60_stage05_commit_split/LEDGER.md`,
  test-only on the real functions, reproducing the enclosing call's Merkle
  root]:** `A` encode 1.270 s (50.7%) / column hashing 0.338 s (13.5%) /
  tree 0.025 s / whole 2.504 s; `H` encode 1.631 s (51.6%) / hashing 0.438 s
  (13.8%) / tree 0.019 s / whole 3.161 s; the five commitments 5.78 s, of
  which ALL column hashing is 0.79 s (13.7%) and the whole Merkle layer
  0.12 s. The parts reproduce your phase clocks at 81–90%. Keying costs
  nothing measurable. rung-W14 shows the same 3.5–3.7 : 1.
- **What that changes:** the keyed CUDA column hasher is worth under 5% of
  the prove — build the conformance harness when you want it, but it is not
  first. The device target inside the commitment is the ENCODE (the NTT),
  where the byte trap is the output ordering (13:06 entry). "Encode on the
  device, hash on the host" would be a new entry point (today's returns
  leaves, not the matrix) and moves 3–4 GB back per commitment — unmeasured.
- **R2a, the cheapest item on the page, in your file:**
  `commit_zk_owned_with_tag` allocates `vec![Fp::ZERO; rows·nn]`
  (`zkp-core/src/pcs.rs:732`, `:789`; `:221` on the non-hiding path) —
  2.98 / 3.73 GB of zeros written and then overwritten in full by
  `encode_row_zk`. A test on the review branch proves the encoding is
  identical from a zeroed and from a `0xA5`-filled buffer. Measured cold
  against warm, the dead zero stores are **0.237 + 0.302 s per 125M block —
  about 0.54 s, 3.1% of the prove**, no byte moved, no protocol
  consequence; the rest of that allocation is page faulting that moves into
  the encode. An uninitialised (`with_capacity` + full-overwrite) or reused
  buffer takes it; `A` and `H` are both live to the opening, so cross-block
  reuse is a run-driver question. rung-W14's receipt is the gate. Offered,
  not done: it is your file; the review branch's test is the oracle.
- The stage-0.5 module stays on the review branch (test-only); the lane's
  integration delta is unchanged at `fee1a8d..a8e4939`.

### 13:06 (2026-09-22) — an OFFER for the larger half of the CPU time: the hiding commitment on the device — a byte contract, counts, memory on both cards, the keyed-kernel recipe with reference vectors, and two private-byte facts for your buffer review; nothing here is a patch

- **Three documents on this branch:** `ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN.md`
  (drafted), `…_DESIGN_CHECK.md` (an independent agent re-derived it by other
  methods) and `…_DISPOSITION.md` (my rulings DC-A..DC-H). You own the keyed
  CUDA path and the device-buffer review; this is what the security owner
  can hand you for both.
- **What it gives you:** (1) an eleven-step byte contract for
  `commit_zk_owned_tagged` with `file:line` — a device version is
  byte-identical iff it reproduces the list; the trap most likely to bite is
  the NTT's output ORDERING (`transform` bit-reverses its input and returns
  natural order; a decimation-in-frequency device NTT permutes the columns —
  every value right, every digest at the wrong index, a different root);
  (2) counts [COUNTED, checked]: 6.29 GiB encoded across the five hiding
  commitments of a block = your measured 6.4 GiB of resident-set growth;
  112,066,560 of 112,590,844 compressions are column digests; the receipts
  reconcile part by part (40,783,352 / 16,421,048 / 2,816,472 B); (3) the
  keyed recipe against blake3 1.8.7: key words in place of the IV at all
  THREE sites (chunk start, lazy-merge parent, root-fold parent) and
  `KEYED_HASH` in every compression — keying only the chunk start is exactly
  right for columns of ≤128 rows, so a short probe passes it; it first shows
  at 129 rows; only the column key ever needs to reach the device (leaves
  are salted and the tree built on the host); six launch sites, four on
  non-hiding paths, so opt-in per call; (4) **reference vectors** from a
  third implementation (BLAKE3 written from the specification, anchored to
  the official vectors, agreeing with the Python package, re-deriving all
  eight pinned keys of `hashtag.rs`):
  `results/zk60_device_commit_check/keyed_vectors.json` — the seed of a
  conformance harness; (5) memory: the chunked 8 GB peak 1,909,852,144 B to
  the byte, held 1.63 GiB to the openings; with the round loop's tables the
  block is 81% of the card ON PAPER (unrun — under the VRAM rule that is the
  sentence); 32 GB: chunking optional, the 1 GiB threshold the wrong
  constant there.
- **Two private-byte facts for your buffer review, first rank (DC-B):**
  (i) **two 64 MiB page-locked host staging buffers** (`cuda.rs:766-772,
  808-880, 1047-1060`) through which every witness upload passes — unzeroed,
  process-lifetime — the "pinned host memory" half of the toy statement's
  03:23 scope note, on the unkeyed path today; (ii) on the resident arm
  `d_coef` is dropped but never freed (`pool_put` never frees, `pool_take`
  matches by exact length), so it stays through the expand NTT — 125M `H`
  8.71 GiB there, not 7.84; rung-W14's commit phase 1.20 GiB, not 0.80.
  With the rest of the inventory (witness rows held past the openings, pad
  rows retained to the opening on the chunked arm, no zeroing on free,
  `HL_GPU_HOST_HASH=1` copying the whole private encoding back) that is the
  list the toy statement's device-path extension waits on. Claimed unread,
  not unsafe.
- **Why the harness comes first:** `verify_zk_tagged` recomputes leaves for
  the 256 sampled columns of 65,536 — 0.39% — so a device bug confined to
  unopened columns passes 99.6% of honest proofs; `dev_hash_check` runs one
  block at 64 columns and cannot see a multi-block bug. The keyed-mode
  conformance harness at the small shapes (whole commitments, every column
  digest compared, CPU-only, no device) is the only total check, and the
  lane can offer it, seeded by those vectors.
- **Two things that may change the order, before any kernel:** (a) **stage
  0.5, running now on my side** — one measurement splitting the commit's CPU
  time into encode / hash / tree at 125M and rung-W14 (counts say hashing
  dominates the compressions; nobody has measured whether it dominates the
  time — if the encode is the larger half, "encode on the device, hash on
  the host" needs no keyed kernel at all); (b) **pipelining across layers**
  in a multi-layer pass — layer `i`'s round loop against layer `i+1`'s
  commitment — the same Amdahl term as a device commitment, no kernel, no
  keyed mode, no new private surface; a scheduling lever in your run
  driver, after the private 8B pass exists. The "keyed prefix" shortcut is
  dead for four reasons (in the check); nobody should try it.
- **Framing, so nothing is over-read [MODEL, one run]:** commitments free →
  10.9 s of the 17.4 s prove; both commitments and round loop free → 4.3 s of
  the PROVE, about 9.6 s end to end with the 5.24 s witness build; no number
  is a time for the 8B pass, which has never been run on a GPU on the
  private line.

### 12:16 (2026-09-22) — the two manifests are now in the toy statement's pin set, with a content assertion (gate round 9f); one residual is yours at integration

- **Round 9f** (joint-view `442634b`, pushed): `zkp-core/Cargo.toml` and
  `hashline/Cargo.toml` pinned at main's `4751b93` digests in a check both
  toy gates run before any analysis (a new `zk60_native_manifest_pins.py`,
  deliberately NOT in the table that 122 run-gate records hash), plus a
  content assertion: no feature in `default` or `[dependencies]`,
  `test-observers` only in a dev-dependency section, an unparsable manifest
  refused — so a manifest that ships the observers is refused BY NAME even
  at a re-pinned digest (failing-first evidence: before, a synthetic tree
  with `default = ["test-observers"]` passed every pin table). Record guard
  re-pinned; 204 + 29 tests green; 0 figures moved. The lane's post-delta
  manifests (`a8e4939`: zkp-core `0c746b9d…`, hashline `10d99a63…`) already
  pass the content assertion, so the integration re-pin is a digest move.
- **Residual for you (R9f.10):** the Rust capture writer (`run_capture`'s
  38-file pin list) records neither manifest, so a bundle cannot be checked
  against the manifests it was built with. One list entry each; yours at
  integration, or the lane's after it — say which.
- Awaited unchanged: your snapshot's commit id (then the D22 re-pin: 13
  differing pinned paths + these two manifests, against your tree).

### 11:45 (2026-09-22) — the observers delta pre-read against every condition of the toy statement (holds), plus one line it needed: the delta is now `fee1a8d..a8e4939` (lane pushed); what your merge will have to reproduce, and one conflict to expect

- **Pre-read** (an independent reviewer; `ZK60_D22_CONDITION7_PREREAD_STAGE36.md`,
  on the lane): every condition of the statement holds against the delta.
  The production residue of the four moved source files — each file taken
  whole at both commits with every gated item and comment removed — is
  byte-identical; the release graph resolves `zkp-core` with `features: []`
  and none of the three observer identifiers in the rlib or rmeta; the
  hook's replay is differential-tested with and without the observer engaged
  (same verdicts, same draws); no `Clone`/`Copy` for the generator anywhere,
  even under `cfg(test)`; the three OS reads untouched; 327,052 reproduced
  on the reviewer's own run.
- **What it found, and what I did:** (P36-3) the "observers never ship"
  claim rested on Cargo's resolver v2 being IMPLIED by `edition = "2021"`
  (no workspace root, no `resolver` key) — under v1 a dev-dependency's
  feature unifies into the release build; **`resolver = "2"` is now explicit
  in both `[package]` sections (`a8e4939`; release build and the frozen toy
  tests green, no manifest warning). Please carry it.** (P36-2) the two
  `Cargo.toml` files now decide whether the observers compile and are pinned
  by nothing — they join the D22 pin set at the re-pin (gate side, mine).
  (P36-4) the replica test pins `private_seam::prepare_with_rng`; `prepare`
  itself draws nothing, now asserted. So **the stage-36 delta for your
  integration is `fee1a8d..a8e4939`** (stage 36 + the pre-read's three
  review-only tests + the two manifest lines).
- **For your merge, from the three-way table:** 13 of the statement's 32
  pinned paths ALREADY differ between the lane's base `fee1a8d` and main's
  `4751b93` — nine lane-only since the fork (`argument.rs`, `zkp-core/pcs.rs`,
  `transcript.rs`, `merkle.rs`, `wire.rs`, `witness.rs`, `zkp-core/lib.rs`,
  `layout.rs`, `protocol.rs`), one main-only (`gpu/mod.rs`), **three changed on
  both sides (`hashline/src/zk.rs`, `hashline/src/private_block.rs`,
  `hashline/src/pcs.rs`)**; your reported hashes fit that model. Expect one
  real conflict: `hashline/src/private_block/norm_alias.rs` exists on both
  sides with different content (`cfg(test)`, unpinned). The D22 re-pin is
  against YOUR tree, never against the lane — so please name the snapshot's
  commit when it exists.

### 10:22 (2026-09-22) — your toy capture replayed: 132 of 132 pins equal, nothing moved, every control fires — the gate now describes the merged tree's proofs; three notes, one of them a weakness in the gate itself

- **Round 9d** (joint-view `d837d50`, pushed; the D22 re-pin record's new
  §8): your bundle is schema 3, profile `…private-block-t32-poc/1` under the
  legacy hash rule, `source_commit` `4751b93`, receipt `10b9d4be…`
  (2,816,472 B) — byte-identical to
  `results/zk60_host_private_20260920/main-gate/native-block/block_receipt.bin`,
  the new-tree receipt the record's §7 had named as the one no bundle yet
  carried. **All 132 entries of your `capture-validation.json[source_hashes]`
  equal `git show 4751b93:<path>`; the 32 pinned paths are all at digests the
  statement accepts** (28 at the pin of record, 4 at the second accepted
  digest written for `4751b93`). Both toy gates replayed: **0 figures of
  record moved** (A/B/N leaf comparison against the two block captures of
  record, every stage), 28 channels with the same names and grades, ranks
  72 / 20 / 4 / 4, all ten controls fire, no pinned tool changed; 176 tests
  OK. So §7's gap is closed. The statement, its D22 row and the record say so
  (dated). CPU only, same profile; it extends nothing.
- **Three notes.** (a) The statement never named a digest for "the accepted
  receipt" — D22 accepts a profile evidenced by four captures; yours is a
  fifth, and "the retained accepted receipt" is your phrase, not the
  statement's. (b) **A weakness in the gate, not in your bundle:** its
  manifest cross-check silently skips when a validation file carries a single
  `accepted` record instead of a list (`validation_json: absent`, gate still
  passes); the replay staged a wrapped copy to make it fire, with a control
  run showing the shim changes nothing else. **Fixed at 10:45 (round 9e,
  joint-view `025e1ac`, pushed) — and the real cause was the file NAME:** the
  gate looked only for `validation.json`, yours is `capture-validation.json`;
  the single-record `accepted` was a second defect behind it. The tool now
  reads either name and either form, refuses by name on anything else, its
  three hashes are re-pinned with the reason recorded, and your bundle was
  replayed again with no shim: the check fires on its own, 0 figures moved.
  **Nothing for you to rename or change.** (c) `M`'s pad margin on this receipt is
  4 of 256 — inside the rule; 0 would be too (the generic case at wide
  shapes).
- **Your `.expected` and your binary pin** (`cbc1864c…`) check out by the
  gate's own screen; your own verification was not used as an input.
- Still owed by me: the condition-7 read of the six files stage 36 moves, at
  your integration. Still with you: the snapshot's commit id; R1d; the
  interface; keyed CUDA. D19b with Victor.

### 10:05 (2026-09-22) — the gate's round 9c (joint-view `d9ca384`, pushed): 125M carries the whole channel table; your toy capture's replay is running now (round 9d); one stale label in the lane's E32 bundles, ruled

- **125M:** the full pass under the repaired tools landed — 46 of 46 slots,
  preimage sums exact, every control family firing, **28 channels at 10
  constructed / 5 derived / 4 argued / 9 open, the same table as the small
  shapes** (I counted the grades in the committed record). The three new
  small shapes (rung-C6, rung-W14, rung-E32) through the whole gate: 46 of
  46 each, 180 predicted figures with none unexplained, all controls. Your
  interest: **a third independent reading confirms stages 28–35 changed
  nothing sent, absorbed or drawn** (the stage-35 rewrites read hunk by
  hunk), and the lane's slot-IR export agrees with the gate's hand port at
  1,288 structural comparisons.
- **Your toy capture:** round 9d started at 10:01 — the toy joint gate
  replayed on `10b9d4be…` against the D22 pin set at `4751b93`, leaf-diffed
  against the D22 record of record, with the D22 controls; the toy gate's
  scripts are hash-pinned, so if anything has to change to read your bundle
  that is reported, not patched. Result in the next entry.
- **E32-F1 (lane, mine):** the rung-E32 bundles' `source_commit` label says
  `4505ddf`, one commit before the shape existed — the writer's environment
  variable was not advanced; the 38 digests are honest, the label is stale.
  Ruled: recorded, not regenerated (regression data, not evidence for a
  statement); after your integration the lane's writer will refuse a label
  that is not the tree it runs from. Nothing for you to do.
- **Operational:** the gate's native suite (530 tests) now needs
  `MemoryMax=8G`; at 4 GiB the process is killed (not a leak — measured). If
  you run it, use 8G.

### 08:58 (2026-09-22) — stage 36 LANDED (lane `29cba9a`, pushed): the observers under your conditions, as a separate delta on top of `fee1a8d`; the toy statement's 327,052 draws reproduced by the accessor to the digit

- **The delta, for your integration after the fixed snapshot** (eight
  commits; the ledger's "What the integrator needs" section has the file
  list and every digest before → after): `zkp-core/src/rng.rs` +225 lines,
  `transcript.rs` +114, `zkp-core/Cargo.toml` (`test-observers` in
  `[features]` only), `hashline/Cargo.toml` (the dev-dependency enabling it,
  one stanza), `private_block/protocol.rs` +21 (the hook in
  `check_opening_challenges`), `private_block.rs` module lines, a new
  `draw_observer.rs` and `s36_tests.rs`, one older test's tripwire retired
  by its mirror image. **Every added code line in the three shared/production
  files is inside a `cfg` gate and nothing is deleted** (script-proved,
  `results/zk60_block125m_lane/z36-cfg-gate-proof.{py,txt}`); `cargo tree`
  without dev-dependencies shows the feature nowhere; release builds of both
  crates with the feature off exit 0 and the toy's 2,816,472 B receipt is
  unmoved (rung-C6 and rung-W14 likewise). `Cargo.lock` byte-identical.
  Accessors: `ZkRng::consumed_bytes` = `(counter−1)·8192 + pos` (0 before the
  first refill), `ZkRng::refills` = `counter`, `Transcript::squeezes` =
  `counter` — no new field, no work on any draw; `ZkRng` non-`Clone` asserted.
- **What it measures [MEASURED, on the lane's tree]:** toy 327,052 field
  draws per proof (the statement's D9 figure exactly), 12,288 salts, 1,863
  live squeezes, the refusal replay 1,027 points in four calls consuming no
  generator bytes; rung-K4 750,540 draws (the lane's claim A-5 row to the
  digit); rung-W14 5,998,940. Filter 416 passed / 0 failed / 17 ignored;
  `zkp-core` 56 / 0 with and without the feature.
- **Three limits, stated as findings, none a defect:** S36-F1 absorbs cannot
  be counted from existing state (no per-absorb counter exists, and your
  condition forbids adding one to the hot path) — the 317 absorbs stay a
  count; S36-F2 the two endpoint generators are measured on a replica of
  their two call sites (`private_seam::prepare`, `endpoint_g::prepare`, both
  outside this delta's write set), pinned by a source test — one line
  (`prepare_with_rng` on `endpoint_g`) would make it the object itself, a
  later lane stage; S36-F3 an in-proof consumption snapshot would need a hook
  in `prove_core`, not done.
- **Owed by me:** the D22 pin set watches six files this delta moves; I
  re-read the diff and update the statement's pins when your integration
  lands (a dated note in the statement, §9 item 11, says so now). Nothing
  else on the lane moves until then unless you say otherwise.

### 07:55 (2026-09-22) — read your 07:25 note; the observers are being built under your conditions (lane stage 36); your toy capture is queued for the gate's replay; one ask — commit the fixed snapshot and name the commit

- **Your integration branch at `fee1a8d`:** good; that tip is the one I
  meant, and the lane will not move under you until stage 36 lands (a
  separate delta, below). The three shared-file hashes you listed will be
  re-read against the D22 pin set when your tag delta is in — please name
  the commit of the assembled snapshot here when it exists, so the re-read
  has a fixed object.
- **The security probe:** thank you. Noted that the tag delta gets its own
  review and pin, not a silent approval.
- **Your toy capture** (`…/captures/10b9d4be…json`, 9.25 MB; I read its
  profile `hashline-zk-mr1/private-block-t32-poc/1`, `source_commit`
  `4751b93`, receipt 2,816,472 B): the joint gate's replay is queued as the
  gate's next round, right after the round now closing (the three new small
  shapes and the IR cross-check). It runs against the D22 pin set as re-read
  at `4751b93`; if the bundle's own pins disagree with that set anywhere the
  gate will say so by name. D22 stays CPU-only, as you say.
- **Observers — dispatched at 07:48 as lane stage 36 under your conditions,
  restated so they are checkable:** explicit `test-observers` feature in
  `zkp-core` (never in dependencies or defaults), hashline's dev-dependency
  enables it, `cfg(test)` for core's own tests; consumption and squeeze
  counts DERIVED from existing counter/position state, no work added to any
  draw; `ZkRng` stays non-`Clone` (asserted by a test); no key, stream byte,
  seed or challenge value through any interface; every added line in
  `zkp-core` and in `protocol.rs` inside a `cfg` gate, proved by a script,
  and the release build without the feature shown to verify the frozen toy
  receipts unchanged. Separate commits per part; the delta's before/after
  digests of the D22-pinned `zkp-core` files will be in the ledger for your
  integration and my re-read. The lane's draw-accounting test then reproduces
  the toy statement's 327,052 draws per proof from the accessor — if it does
  not, that is a finding, not an adjustment.
- **Agreed on ownership.** rung-W14's receipt (16,421,048 B, verifies from
  bytes in the ordinary filter in about four seconds) as the first check on
  any shared speed change is exactly what it was built for. S35-F1
  (`argument.rs::limbs`, dead code) is yours to delete at integration.

### 07:20 (2026-09-22) — lane at `fee1a8d` (pushed): lever (b) measured at 125M is worth about 0.4 s on one slot, which settles where the CPU time is; nothing else moved overnight (my session was out from 20:10 to 07:15 on an expired login)

- **Lane stage 35 [MEASURED, one run each, shared box]:** the closures of
  slots 17 and 14 rewritten by pure algebraic identities (support gate
  hoisted, two sub-products formed once, public constants through
  `mul_base`) — old closure = new closure = the stage-34 IR at 576 points,
  receipt identical, filter 408 passed / 0 failed / 17 ignored. Counted:
  13.8% and 18.7% of the two closures' multiplications. Clock at 125M: slot
  17's masked sumcheck 3.05 / 3.11 → 2.66 s (about −13%, in line with the
  count); slot 14 1.64 / 1.87 → 1.74 s (nothing, despite the larger count);
  the whole prove 18.40 s, inside the 17.4–19.4 s band. **So lever (b) alone
  is about 0.4 s on one slot, the counts do not predict the clock (the
  check's IR-C9, now measured twice), and there is nothing more for the lane
  to take inside the closures.** What remains of the round loop's time needs
  the shared loop — request R1d and the `SumcheckRounds` interface of my
  16:35 entry — and the larger half of the CPU time is the two commitments.
  One item for you from the stage (S35-F1): `argument.rs::limbs` is now dead
  code (its only callers were those two arms; the lane's arms-only rule kept
  it) — delete it or keep it behind `cfg(test)` as an oracle for the new fold.
- **Unchanged and waiting on you:** the red `tests/test_zk60_mvp_security_probe.py`
  on main for `zk.rs` since `4751b93` (re-pin first); R1d; the interface
  offer; the five items of 04:38 yesterday; D19b with Victor. Your last
  coordination note is still 2026-09-20 20:52 — if you are working in a
  place I cannot see, one line here saying where would save both of us time.
- The Python gate's round 9c (the three new small shapes through the whole
  gate, and the lane's slot-IR export read as a cross-check of its hand port)
  ran overnight and is being written up this morning.

### 16:35 (2026-09-21) — a design for the sumcheck rounds as DATA (drafted, adversarially checked, ruled): what it is worth as counts, the one shared-file lever that is cheap, an interface OFFER for your files, and one thing I verified that needs you first — the security probe test is red on main for `zk.rs`

- **Three documents on this branch:** `ZK60_SLOT_EXPRESSION_IR_DESIGN.md`
  (the memo), `…_DESIGN_CHECK.md` (an independent agent that re-derived every
  count by a different method) and `…_DISPOSITION.md` (my rulings I-1..I-9).
  The idea: each of the 23 sub-arguments' round polynomial written as data,
  from which a specialised CPU evaluator, a device kernel and a description
  the Python gate can read are all derived; the closures stay as the oracle.
- **Counts, not times [COUNTED, confirmed to the digit by two methods]:**
  16.48 billion base-multiplication units per 125M proof today (746 million
  at rung-W14, whose slot structure is identical). Three byte-preserving
  levers remove 59.9% of them at zero addition cost (30–52% with additions
  priced); the counts do NOT reproduce the measured per-slot seconds, so read
  them as a bound on work, not a time. **The check's ceiling for the CPU
  prove with every lever taken is 13.4 s [MODEL, not a prediction]; with the
  round loop at zero cost, 10.8 s, of which your two commitments are 60%.**
  So the IR is worth building for the device path and the gate's
  independence; it is not the road to 5 s by itself, and the commitments are
  the larger half of that road.
- **R1d — the cheapest lever, in your file, offered first.**
  `zkp-core/src/sumcheck.rs::prove` evaluates every round polynomial at
  `degree + 1` points (`:83-89`; I read it) although the prover holds the
  running claim and `s(1) = claim − s(0)`: one evaluation per pair index is
  redundant, **15.8% of the baseline [COUNTED]**, nothing sent changes. Loses
  a mid-proof self-check that the terminal check still provides one round
  later; condition: a debug assertion of `s(0) + s(1) == claim`, and the
  oracle tests compare against the full evaluation. Inside `masked_prove` it
  applies only if the claim tracked at that point is the unmasked one — you
  would know.
- **The interface (Option A), as an OFFER, not a request:** a
  `SumcheckRounds` trait (`round(j)`, `fold(r)`, `finals()`) beside the
  closure path, `prove` a wrapper over a `ClosureRounds` that is today's code
  verbatim, an additive `masked_prove_rounds` in `zk.rs`; legacy untouched
  (`masked_prove` has 18 call sites, the frozen seam among them). The check's
  corrections are in my I-5: no `Sync` supertrait (the device handle is
  `Send`), the preservation list written into the trait (absorb order, where
  the mask enters, extension rounds, the refusal points, exact-addition
  chunking), and the frozen byte gates named. Without it the lane can do only
  lever (b) inside the closures (14.2%); levers (a), (c) and R1d all need the
  loop to hand the evaluator a range or the round.
- **Needs you first, and I verified it myself at 16:20:**
  `tests/test_zk60_mvp_security_probe.py` is RED on main — `hashline/src/zk.rs`
  (head `ce8cc516…`) no longer matches the round-22 capture manifest
  (`c5b54753…`) since your `4751b93` of 2026-09-20 20:52; one failure and one
  error from the same cause. That pin is yours: please re-read the `zk.rs`
  diff against the manifest's commit and re-pin BEFORE any further change to
  `zk.rs`, or the next change cannot be told apart from the last. (The toy
  statement's D22 pins are a separate set, re-read at `4751b93` on 2026-09-20
  22:06; D22 is unaffected.)
- **Device memory, under the VRAM rule:** the round loop's tables fit an 8 GB
  card slot-at-a-time (3.4 GiB at 125M [COUNTED]) with the base-to-extension
  fold peak written as an implementation condition; the prover as a whole
  does not — the two commitments' encode and Merkle passes add about 6.4 GiB
  of resident set at 125M [MEASURED]. Nothing about "fits an 8 GB card" may
  be said of the whole block; the whole block is a 32 GB-card design.
- **Lane side, now:** IR stage 1 — types, a builder beside each arm of
  `define`, the oracle test against the closures at every registered shape
  under 1/2/8 threads, and the field-kind oracle (the check found twelve of
  the memo's 143 "base-field" tables are extension-valued because challenges
  enter them — a wrong label there would be a wrong proof at the evaluation
  stage, so the kind is derived and tested, never declared). No execution
  path changes, no byte moves.

### 15:23 (2026-09-21) — lane at `226f3b2` (pushed): a 4-second shape with 125M's row width, head size and slot degrees, and a 2-second shape with 125M's endpoint row count — validate shared-file changes on THESE before any 10 GiB run; two rulings implemented; the gate's round 9b

- **For your optimisation work, the point of today's lane stages 30–33:** four
  new small profiles now reach, in the ORDINARY filter (394 passed / 0 failed / 17
  ignored, about 9.5 minutes), every shape-dependent branch the 125M block
  takes except what scales with 512 tokens and twelve blocks:
  | profile | what it shares with 125M | one proof |
  |---|---|---|
  | `rung-P2` (32 tok, 96/256) | T, Kv, F unpadded: `pad_on == false` in slots 02, 16, 18 | 0.6 s |
  | `rung-C6` (32 tok, 384/512, heads of 32) | + correction C-6 (`norm_top_is_full_byte`) | 1.2 s |
  | **`rung-W14`** (64 tok, 768/1,024, heads of 64) | **row width 2^14 → encoded 2^16, 256 opened columns, Merkle depth 16, head axis, all 23 slot degrees, 83 `A` / 50 `H` planes, 36 / 9 opening groups, the ×64 table lift, the 14-log endpoint, C-6** | **3.9 s, 757 MB** |
  | `rung-E32` (32 tok, 768/1,024) | the endpoint's 32 data / 37 commitment rows and 296-byte column digest; boundary 38 rows in a run | 1.8 s, 361 MB |
  Every one: dense generic witness equal to the independent reference kernel
  on every plane, receipt length equal to the Python model's count, all-zero
  input, a multi-block run from segments, tampers at the positions only that
  shape has (columns ≥ 2^13, the ×64 lifted table rows, the last index of an
  unpadded domain, endpoint rows ≥ 16), each rejected by the verifier at the
  expected slot. **No soundness finding in any of them.** What stays
  heavy-only: 32 endpoint data rows AT the 14-log endpoint (that conjunction is
  125M itself), the token ladder (128 would still be ordinary, 256 medium),
  long runs and the memory path. **If you change `pcs.rs`, `zk.rs` or
  `zkp-core` for speed, `rung-W14` is the shape whose receipt must not move**
  (16,421,048 B; its test verifies from bytes), and it costs four seconds.
- **Ruling S-6, implemented:** `Shape::a_groups`'s first arm
  (`natural_log(Dom::T) >= log_cols`) was reached by no registered shape; the
  failing-first test showed the toy's axes at 256 tokens were ACCEPTED and read
  `a_groups() = 28` out of that arm. Such shapes are now refused at validation
  by name (`private block shape: ruling S-6 …`), the Python model refuses the
  same family with the same sentence, and the arm stays as a panic-free
  defensive return (the two arms provably agree on the refused family).
- **Ruling J-7a, implemented:** the separator of every declared hash-input
  length coincidence is now CHECKED: 42 fixed literals (14 profiles, 4
  key-derivation contexts, 22 transcript labels, 2 transcript literals) are
  printable ASCII with no zero byte, and for every registered profile length
  the transcript constructor's input is separated from every absorb layout of
  the same length (124 layouts) by at least 14 forced-zero positions inside
  length fields — positions computed, a bad test-local profile rejected. If
  you add a profile, that test tells you at once whether its length is safe.
- **The Python gate, round 9b** (joint-view `4db3a4d`, pushed; suite 507):
  `rung-P2` through the whole gate, pad rule derived by the predictor before
  the run, 46 of 46 twice, every control family firing; **a second independent
  reading confirms the speed stages 28–29 changed nothing sent, absorbed or
  drawn.** It also corrected round 9 and I corrected my pages: the 125M joint
  figure is the sum of its parts (the joint statement rests on the coupling
  check), only the preimage and masking control families have fired at 125M
  so far, and the gate's M-F1 control had never fired at any shape until its
  repair today (finding P-F2) — the development-shape twin now runs in a
  second.
- **Repository size, my side:** today's capture bundles add about 143 MB to
  the lane branch (the largest pair 33 MB each). From now on I keep bundles
  over 20 MB outside the repository with committed manifests, as for 125M and
  `rung-W14`.
- Unchanged: the five items I am waiting on from you (04:38), D19b with
  Victor. Message-only notes for integration: S31-F1, T30-F1, and S33-F1 (a
  declared separator said "six" zero bytes where there are seven — corrected).

### 13:20 (2026-09-21) — lane at `d282dd6` (pushed): `rung-C6` puts correction C-6 in the ordinary filter, no soundness finding; the 125M prove figure is now a RANGE (17.4–19.4 s, two runs); the gate's preimage step is complete at 125M; stage 32 (row width 2^14, head_dim 64, the 14-log endpoint) running

- **`Shape::rung_c6`** — 32 tokens, width 384, hidden 512, 12 heads of 32 over
  4 key-value heads (`lkv = 2`), `log_cols` 10; it also keeps rung-P2's three
  unpadded domains, so it carries both pad branches AND `norm_top_is_full_byte`.
  Additive only. Filter 362 passed / 0 failed / 15 ignored. Receipt 7,452,040 B
  = the Python model's count. **The soundness question of C-6 — what enforces
  the norm's top limb's range once four lookups are dropped — has an answer:**
  on that arm the dropped scaled lookup is term for term the `byte(top)` lookup
  that is emitted unconditionally (shown statically by the lookup multiset,
  rung-P2 minus rung-C6 being exactly those four, and dynamically: a carry
  moved between the top limb and the one below keeps every arithmetic clause
  true and is rejected by the verifier at `H`'s group 8, the value-0 LogUp
  identity, for all four remainders; the same tamper at rung-K4, which keeps
  the scaled lookup, gives the same refusal).
- **Two message-only findings for you, same family:** S31-F1 (that LogUp
  refusal names neither slot nor lookup) and T30-F1 (the wire refusal of a
  padded-style frame does not name the slot). One line each if you touch those
  messages; not security matters.
- **A dead arm, not a heavy one:** `Shape::a_groups`'s
  `natural_log(Dom::T) >= log_cols` arm is reached by NO registered shape,
  125M included. Worth a named refusal or a deletion when you integrate; I
  will rule if you want one.
- **Second sample of the stage-28 prover at 125M: 19.36 s** (same receipt
  length; one run, shared box, with a counting diagnostic on that costs
  0.05 s). Quote **17.4–19.4 s, two runs**, against 27.7 s. The base-field
  census at 125M is 62.1% of round-1 table words (61.5% at the rung) — a
  property of the schedule; my recommendation on R1b is unchanged (not first).
- **The Python gate at 125M, completed since 11:20** (joint-view `51f74b2`,
  pushed): all seven commitments of both two-block captures reproduced from
  all-zero data (8,263,736 and 8,256,579 published entries, none differing)
  and one joint assignment per run (8,296,654 / 8,289,497, none differing, no
  coupling touching a blinding row); about 21 minutes a run at 5.5 GB. Round
  9b is reading the rung-P2 bundles now; the rung-C6 bundles
  (`run-m-dense-c6`, `run-n-zero-c6`) are next.
- **Stage 32 is running:** the smallest admitted shape with `log_cols = 14`,
  `head_dim = 64` and the 14-log endpoint (candidate: 64 tokens, width 768,
  hidden 1,024), so that a change to the shared commitment or sumcheck code
  can be validated at 125M's row width in seconds, not in a 10 GiB run. If it
  is too slow for the filter it becomes a documented medium tier with one
  command. After it, only what scales with 512 tokens and twelve blocks stays
  heavy-only.
- **Housekeeping, my side:** twice today a finished agent was re-woken by its
  own queued job and committed into a worktree I had already handed to the
  next writer (joint-view around 12:30, this lane around 12:55; ledger and
  evidence commits only, no source collision). Contained; I now stop an agent
  before its worktree gets a new writer. If you see interleaved commit authorship
  in those two branches, that is why.

### 12:26 (2026-09-21) — lane at `b923d07` (pushed): a new small profile `rung-P2` puts the UNPADDED branch of the pad rule into the ordinary filter; one wire-contract suggestion for you; stage 31 (the C-6 branch) running

- **`Shape::rung_p2`** — 32 tokens, width 96, hidden 256, 12 query heads of 8
  over 4 key-value heads (`lkv = 2`): rung-K4's padded layout with T (32), Kv
  (1024) and F (8192) sitting exactly on their pads, so their host slots 02,
  16 and 18 take `pad_on == false` — the same three as at 125M — while Ht, L,
  D, Q, S and Tab stay padded. Purely additive in production code (a shape, a
  run profile `…private-run-rung-p2-t32-dev/1`, two registry lists; I read the
  `run.rs` / `run_statement_file.rs` hunks). Filter 348 passed / 0 failed /
  14 ignored; no older profile moved.
- **What it shows [MEASURED at this shape]:** receipt 4,742,728 B = the
  independent Python model's count = rung-K4 minus exactly 400 B; the draw
  census differs from rung-K4 only at slots 02 (13 vs 15), 16 (19 vs 21) and
  18 (24 vs 26) — one `mu` and one `zeta` each — and the verifier's counts
  equal the prover's on all 23 slots; tampers at the LAST index of each
  unpadded domain (where a padded domain would have a pad row) and at index 0
  are rejected by the verifier at the slot under test; a dense generic witness
  matches the independent reference kernel on every plane; a three-block run
  proves in 1.81 s and verifies from segments. Two capture bundles
  (`run-k-dense-p2`, `run-l-zero-p2`, 16 MB each) give the Python gate a
  seconds-long regression for its finding M-F1; the gate is reading them now.
- **Finding T30-F1, for you, small:** a frame shaped as if the domain were
  padded (one extra value per round message) is refused by `wire::validate`
  before any transcript operation — fail-closed and correct — but the refusal
  says only "private block wire: argument shape" and does not name the slot,
  unlike the sumcheck refusals. If you touch the wire contract at integration,
  naming the slot there costs one line. Not a security matter.
- **Stage 31 is running:** the same treatment for correction C-6
  (`norm_top_is_full_byte`: 4 lookups and 2 `Dom::D` helpers dropped), today
  reached only by the ignored 125M runs — a small shape of width 384, with the
  explicit question of WHICH remaining relation enforces the top limb's range
  once those lookups are gone. After it, what stays heavy-only is what a small
  shape cannot stand in for (row width 2^14, head_dim 64, the 37-row endpoint,
  twelve blocks and the 484 MB receipt).

### 11:29 (2026-09-21) — lane at `6c302f5` (pushed): the review's gaps are closed, so stage 28 + 29 may go to you; the base-field count for R1b; a small shape for the unpadded pad-rule branch is being added

- **Stage 29 (lane files only; filter 336 passed / 0 failed / 13 ignored; I
  checked the scope and the result).** Every size threshold stage 28
  introduced is now an ARGUMENT of an inner function whose production wrapper
  passes the same constant (`TOTAL_PAR_MIN` 2^14, `TABLES_PAR_MIN`,
  `LOOKUP_PAR_MIN`, `HISTOGRAM_PAR_MIN` 2^17, `HELPER_PAR_MIN` 2^14) — no
  `cfg(test)` switch. Five gates drive both branches on the same input against
  the text of `79f0726` under 1, 2 and 8 threads; `eq_cube` has a hard
  assertion for its precondition. None of the nine changed computations is now
  without an old-against-new oracle. **Take `6c302f5` as the base for your
  optimisation delta.**
- **R1b, the count I promised [COUNTED at rung-K4; the 125M census is queued
  behind the gate's jobs on the heavy lock]:** at the start of round 1, 61.5%
  of the table words in the five big zero-check slots are base-field-valued
  (85 of 139 tables); the exceptions are the `eq` tables and the LogUp helper
  columns. No round-1 product is wholly base-field — every slot carries an
  `eq` factor — so a joint change would buy base-times-extension
  multiplications for about that share of operands and half the traffic for
  those tables, not a base-field round. **My recommendation: not first.** R1a
  (a batched evaluation interface instead of one boxed call per point per
  evaluation) and R2 (the two commitments on the GPU, which needs your keyed
  CUDA BLAKE3 kernels) before it.
- **Stage 30 is running on the lane:** a new small profile whose T, Kv and F
  domains are exact powers of two while others stay padded, so that the
  `pad_on == false` branch of the pad rule — today reached only by the ignored
  10 GiB 125M runs — is proved, tampered and run-composed in the ordinary
  filter, with two capture bundles for the Python gate. No older profile
  moves. This is the development-shape control for the gate's finding M-F1
  (11:20 below).

### 11:20 (2026-09-21) — the Python gate has MEASURED at the 125M shape for the first time (joint-view `ad16a77`, pushed): nothing unexpected on the prover's side; one defect found in the gate's own port that only this shape could show

- **Input:** the two two-block 125M captures from the lane at `f4697f9` (dense
  generic input; all-zero input). **The writer-side pin the gate had been
  asking the capture writer for now exists:** those bundles pin 38 files
  including 23 shared ones (`zk.rs` and the `zkp-core` files among them), and
  the eight a Python port depends on carry exactly the digests I had read.
- **Results [MEASURED on both bundles]:** 27,828 challenges re-derived; 2,304
  opened columns (52.9 MB) re-hashed under independently derived keys; the
  23-slot terminal identity 46 of 46 with two group bits; exact ranks — `A`
  (5,681 rows, 122 claims) discloses 0, `H` (7,120 rows, 51 claims) discloses 2
  and that 2 is checked to be the public LogUp identity, endpoints 0, the
  boundary 0 on 6 of 6 reserved rows, `M` 0, the run the sum of its parts.
  180 figures were predicted from the shape and validated on both development
  shapes BEFORE the 125M run; none came out unexplained. Dense against
  all-zero: 124 of 128 identical, the four being sampled-column counts and the
  pad margins they imply.
- **Finding M-F1 — in the gate's port, not in your code or the lane's, but
  worth knowing when you integrate:** at 125M three domains are exact powers
  of two (T 2^9, Kv 2^17, F 2^20), so `pad_on` is false for them and their host
  zero-check slots draw two fewer challenges (`argument.rs:936`: `mu(6+n_pad)`
  and `zeta` only if `pad_on`). Every development shape pads every domain, so
  no test below 125M exercises the unpadded branch **on either side**. The
  Rust side is right (the honest 125M proofs verify, and the gate's
  independent identity now agrees 46 of 46); the point for you is that a
  shape-general change to those slots cannot be validated at the rungs alone.
- **Preimage construction at 125M:** done for the three small commitments,
  the masking layer and `A` of block 0 (2,070,138 published entries reproduced
  from all-zero data, none differing; 6 minutes, 2.5 GB). The other three big
  commitments, the controls and the whole-run joint assignment are running
  detached on the heavy lock (about an hour more); until they land the 125M
  channel table is 2 constructed / 5 derived / 4 argued / 17 open, not the
  rungs' 10 / 5 / 4 / 9.
- **Not a privacy claim.** Two blocks, one internal boundary; linear channels;
  the law of the blinding, the joint law and the hiding of unopened leaves are
  where they were.

### 10:46 (2026-09-21) — stage 28 REVIEWED, no defect (lane `db28728`, pushed, review merged); please build your optimisation delta ON TOP of it — two of your three named targets are already done there

- **The review** (`ZK60_BLOCK125M_S28_REVIEW.md` on the lane; my rulings in
  `ZK60_BLOCK125M_S28_DISPOSITION.md` on this branch): no defect, no production
  line changed by the reviewer. **A complete twelve-block dense 125M run
  written by the old prover (`0426ad2`) is accepted by the stage-28 verifier
  through `run_statement_file::verify_from_disk` — 15.20 s, 476 MiB**
  [MEASURED]; 1,800 randomised comparisons against the verbatim `79f0726` code
  and all 560 `eq_cube` triples agree; the whole filter passes again under
  `RAYON_NUM_THREADS=1` (327 passed / 0 failed / 13 ignored); no changed
  computation has a caller on the verifying path. So 17.40 s may be quoted as
  [MEASURED, one run, shared box, reviewed]; the all-zero control is 17.71 s,
  same receipt length.
- **You wrote on 2026-09-20 14:15 that your next speed work targets "the
  softmax slot, hiding commitments and lookup helpers" and asked for a stable
  tip first. This is it: `db28728`.** The lookup helpers (4.06 → 1.08 s) and
  the lane's side of the softmax slot (7.20 → 3.56 s) are done there, inside
  `private_block/` only. What remains of your three targets is inside your
  files, measured on the same run: `zkp-core/src/sumcheck.rs` round loop
  6.59 s, the two `pcs::commit_zk_owned` calls 6.50 s, openings 0.67 s, of
  17.40 s. If you already have a delta against the older shaped source, the
  lane's changed functions are `argument::priv_table` / the slot-table build,
  `protocol`'s helper-inverse block and the claimed sum — say so here and I
  will reconcile rather than have you redo it.
- **Test gaps the review found, which I ruled are closed BEFORE you take the
  stage (lane stage 29, running now):** the parallel claimed sum has no direct
  old-against-new test and the small shapes never take the parallel branches
  (both branches of every threshold get a test in the ordinary filter); one
  unguarded precondition in `eq_cube` becomes a hard assertion; ledger wording.
  Stage 29 also counts how much of the big zero-check slots' table data is
  base-field-valued at round 1 — the number that decides whether a joint
  base-field first round (request R1b) is worth designing with you.
- **A ruling that touches the accepted toy statement, number unchanged
  (V-3; statement §9 item 10; D22 row):** for every admitted witness, whether
  an attempt is refused for a zero lookup denominator is a function of the
  public challenges and the three public tables alone, because the prover
  inverts each whole table on every attempt (main: `protocol.rs:353-357`; I
  read it). Only which of two lines returns first depends on the hidden input,
  with the identical string and no absorb or draw between them (main `:332` to
  `:362`). **Please keep that property when you touch this region**: the table
  inversion must stay unconditional and before any draw, and the two refusal
  strings must stay identical. The unqualified sentence (for ANY witness) is
  false — the reviewer's counterexample is a looked value no table carries —
  and is not claimed.
- Round 9 of the Python gate at 125M is still working through its heavy queue
  (the full preimage pass is about 7 minutes per big commitment); results when
  it reports. Unchanged: the five items I am waiting on from you (04:38).

### 10:00 (2026-09-21) — lane at `309d238` (pushed): one 125M block proves in 17.40 s instead of 27.71 s with the same bytes — under independent review; what is left is 79% yours, with measured attribution

- **Result [MEASURED, one run each, shared box; I re-read the logs].** One
  block at the 125M shape, dense weights, generic hidden input: **prove 27.71 →
  17.40 s, verify 1.28 → 1.15 s, receipt 40,783,352 B in both, high-water mark
  10,232 → 10,156 MiB.** Filter `private_`: 319 passed / 0 failed / 12 ignored
  (309 + ten old-against-new equality gates). **The diff is
  `private_block.rs`, `private_block/{argument,protocol,timing}.rs` and a new
  test file — nothing of yours, nothing shared** (`git diff --stat 79f0726`
  over every forbidden path prints nothing; I checked).
- **What changed, all lane-side:** the LogUp helper inverses come from a
  256-entry table built once per proof (4.06 → 1.08 s; values outside a byte —
  only a tampered witness — take the old path; the refusal is preserved value
  by value); the per-slot tables are built in parallel and cheaper (6.01 →
  0.59 s over the 23 slots); the claimed sums, the looked columns and the byte
  histogram run in parallel. No line draws from a generator, reorders an
  absorb, or changes what is sent. The controls did not move: your masked
  sumcheck 6.91 → 6.59 s, the two commitments 3.08 → 3.07 s and 3.50 → 3.43 s.
- **No deterministic digest pin was added, deliberately** (finding S28-F2): a
  seeded generator on the proving path would break the accepted toy
  statement's condition 6, which a test enforces. "Same bytes" therefore rests
  on the equality gates, the size pins and honest proofs verifying at five
  shapes — so **an independent reviewer is attacking it now** on the review
  branch (differential tests against the code at `79f0726`, thread-count
  independence, draw and absorb order, and receipts written by the OLD prover
  checked by the NEW verifier on the twelve-block dense 125M run). Treat
  17.40 s as a measurement of code under review until I write again.
- **A finding that is good news if the reviewer confirms it (S28-F1):** the
  three table helpers invert all 256 denominators of each public table on
  every attempt, so WHETHER an attempt is refused for a zero LogUp denominator
  is a function of the public challenges and public tables alone; the hidden
  input only decides which of two lines returns the (same) string first. I
  will rule after the review; the toy statement prices that refusal as if it
  were input-dependent, which is conservative either way.
- **What is left, and whose it is [MEASURED, same run]:** of 17.40 s,
  **13.76 s (79%) is in shared files** — `zkp-core/src/sumcheck.rs` `prove`'s
  round loop via `zk::masked_prove` 6.59 s (37.9%); `pcs::commit_zk_owned` for
  `H` 3.43 s and `A` 3.07 s (37.3% together); openings 0.67 s. The lane's
  ledger (stage 28, "Integrator requests") has the detail, including what the
  round loop ALREADY does so nobody re-suggests it. In the order I would take
  them: (R2) the two commitments are the GPU's — and the tagged hash rule
  declines the accelerator today, so keyed variants of the two CUDA BLAKE3
  kernels (same compression function, key words in place of the IV, the
  keyed-hash flag) gate any GPU number on this line; (R1a) a batched `poly`
  interface in the round loop instead of one boxed call per point per
  evaluation; (R1c) the constant 1,024 chunk at every cube from 2^10 to 2^23;
  (R1b) a base-field first round is a JOINT change (lane tables + your loop) —
  I will measure how many of a big slot's tables are base-field-valued before
  asking for it. All four keep every byte.
- **Pins:** capture bundles written before this stage (including the two 125M
  ones from 09:04) pin the OLD text of `protocol.rs`, `argument.rs` and
  `timing.rs` at `f4697f9`; the Python gate's round 9 reads them against that
  commit. Captures taken after this stage pin the new text and need the diff
  read first — mine to do.

### 09:04 (2026-09-21) — two 125M run captures exist (lane `79f0726`, pushed); the Python gate is reading them now; a lane-local speed stage has started — nothing of yours is touched

- **Captures [MEASURED, one run each, shared box].** The stage-27 test-only
  writer (schema `hashline-native-capture/5-run`: every field array of 256 or
  more entries goes to one `arrays.bin`, referenced by SHA-256, identical
  arrays stored once) wrote two two-block runs at the 125M shape from the
  lane's `f4697f9` binaries. Dense generic input: exit 0, prove + verify +
  record 79.69 s, high-water mark 10.05 GiB, 281,106,431 B on disk. All-zero
  input: exit 0, 78.44 s, 10.05 GiB, 272,660,458 B. Both self-consistent, every
  key on the allow-list, every array reference resolved. Logs, exit markers
  and the two manifests are committed on the lane; the bundles stay outside
  the repository under `/home/victor/zk60-artifacts/m125-capture-{dense,zero}-l2`.
  **A capture is not a privacy result** — no gate had read either when they
  were committed.
- **The Python gate's round 9 is running on them** (joint-view lane, sole
  writer there): loader for the new schema, source pins read up to `f4697f9`,
  then replay, hash layer, the 23-slot terminal identity with two group bits,
  disclosure figures and the preimage construction — the first time anything
  is MEASURED at 125M. Its heavy steps queue on `/tmp/zk-heavy.lock` under an
  8 GB ceiling.
- **Lane stage 28 has started: speed without moving a byte.** The measured
  125M phase table (`m125-run2-timing.log`, 26.5 s before the stage-20 repair)
  puts 3.9 s in the LogUp helper inverses — a per-element batch inversion over
  about 98.6 M BYTE-valued entries, so at most 256 distinct denominators per
  proof — and 6.7 s + 2.9 s + 1.3 s in three zero-check slots. The stage
  replaces the inversion by a 256-entry table with the refusal preserved
  exactly, and attributes and tightens the lane's part of those slots.
  Acceptance is byte identity (toy frozen; deterministic receipt pins at the
  rung shapes) and the same refusals at the same point with the same message.
  **Only `private_block/*` is edited.** Anything whose hot loop sits in
  `zk.rs` or `pcs.rs` will come to you as a measured attribution and a request,
  not as a patch. For scale: the two PCS commits were 6.6 s of those 26.5 s and
  the tagged commit declines the accelerator, so keyed variants of the two
  CUDA BLAKE3 kernels are the first thing the private line needs from the GPU
  side. I am not asking for them now; I will bring the measured split first.
- **Heavy lock:** expect it to be busy on and off for the next few hours (one
  125M Rust run is about 90 s; the Python steps are longer). Yours queue
  behind them as usual.
- Still waiting on you, unchanged from 04:38: the `#[cfg(test)]` consumption
  accessor on `ZkRng`; which gate pins the two CUDA BLAKE3 kernels on a hiding
  toy commitment; one schema-3 toy capture from `4751b93` binaries; a word on
  the observer hook and the squeeze counter; when the lane/main merge starts.

### 08:10 (2026-09-21) — the Python gate now builds ONE joint preimage for a whole run; I am going after the 125M shape next — heads-up on the heavy lock

- **`zk60-native-jointview` at `6fa571e`, pushed (suite 432; I re-ran the 42
  new tests).** Round 8: the masking commitments at both development shapes —
  one mask-coefficient vector per stage that reproduces both every slot's
  masked round messages and the commitment's opened view (191,610 entries,
  none differing) — and **one joint assignment per run** (zero data
  everywhere, constructed blinding, constructed mask coefficients) reproducing
  **4,954,912 published entries over four real runs, none differing**, with
  the four couplings between commitments enumerated and checked (the boundary
  and endpoint planes couple through data rows only; none touches a blinding
  row). Channels: 28, of which 10 constructed, 5 derived, 4 argued, 9 open.
  What stays open is the *law* of the blinding — the draw-accounting test,
  which waits for your `ZkRng` accessor — and everything at the 125M shape.
- **The 125M shape is next, and it is feasible after all**: a capture records
  the verifier's view, which is small even there (256 opened columns per
  commitment). Lane stage 27 (running, **test-only**) makes the run capture
  work at 125M — streaming, a compact encoding if the JSON is too large — and
  adds writer-side pins for `zk.rs` and the `zkp-core` files the run depends
  on (**listing** them records their SHA-256 at test time; nothing of yours is
  edited). **I will then take the heavy lock for two two-block 125M proofs
  (dense and all-zero), about 70 s each plus the capture, under the 12 GB
  ceiling; if you need the lock this morning, take it — mine queue.**
- Victor has a morning summary (07:28) and the D19b ask. Still waiting on you:
  the five items of my 04:38 entry.

### 06:00 (2026-09-21) — lane at `fc782a3` (pushed): ONE small production change in the prover's generator domains — no verifier-visible byte moves; D22 re-examined and unchanged; the gate's preimage step done for all ten commitments of a run

- **Stage 26, the change you should know about before you merge** (filter
  `private_` 306 passed, none failing; receipts 2,816,472 / 4,218,600 /
  4,234,984 / 4,743,128 / 40,783,352 B, the pinned rung-G run binding and its
  two boundary digests, and four generic honest proofs under the UNCHANGED
  verifier all green; shared and frozen files untouched): at every
  **unfrozen** profile the domain handed to `ZkRng::from_os` now says what the
  generator is for — single-block prover: literal ‖ `0x02` ‖ profile; run
  prover: literal ‖ `0x03` ‖ run profile; generalised endpoint: literal ‖ role
  byte (`0x00` input, `0x01` output) ‖ the public endpoint spec digest. Draw
  order and counts are untouched; only the bytes of one keyed BLAKE3 call per
  generator change, and no verifier ever sees a generator. **Why:** a
  re-examination of the accepted toy statement found that the toy's two
  endpoint generators derive their keys from **byte-identical** public inputs,
  so two operating-system entropy reads are the only thing separating them —
  equal reads would mean two commitments sharing every pad, salt and mask row.
  It cannot be changed at the frozen toy or the frozen seam (it is now a
  stated weakness of that profile, §9 item 6 of the statement); everywhere
  else it has a structural backstop. A side effect: the generalised
  endpoint's seed-derivation input is 99 bytes, no longer exactly the 64 of a
  Merkle node. **The same pattern is worth a look on your FFN private-IO
  path: any two generators created from the same domain literal in one
  proof.**
- **D22 re-examined against the complete hash-call table: unchanged, with
  nine clarifications** (`ZK60_TOY_ROUTE_A_REEXAMINATION.md`; statement §9).
  Every figure of the statement reproduces from main at your `4751b93`. For
  your own reading: the prover's refusal replay re-issues 1,027 squeeze points
  per toy proof with no absorb in between — uniqueness in the argument is of
  the challenge *point*, not of the call.
- **The Python gate, round 7** (`zk60-native-jointview` at `df04d14`, pushed;
  suite 390): for all forty hiding commitments of the four current bundles —
  `A` and `H` included — blinding is constructed for all-zero data that
  reproduces the view captured from a fully dense generic input, and the view
  is recomputed from it: **4,763,302 entries, none differing**, plus 10,240
  salted leaves re-authenticated. A commitment takes 8–13 s in exact
  arithmetic. One control is the project's standing counterexample made
  concrete: a blinding row shared between `A` and `H` leaves each with a
  preimage and the pair with none. Not covered: the masking commitments, a
  joint run-wide preimage, the 125M shape.
- Still waiting on you: the five items of my 04:38 entry.

### 04:38 (2026-09-21) — lane at `fd45a67` (pushed): stage 25, tests and one wider guard; nothing an existing profile proves moved. What I am waiting on from you, in one place

- **Stage 25** (filter `private_` 298 passed, none failing; receipts
  2,816,472 / 4,218,600 / 4,234,984 / 4,743,128 / 40,783,352 B unmoved;
  shared and frozen files untouched): every hash input kind on every
  registered profile's path re-derived from the code — 410 kinds, eight
  profiles — with a per-function assertion that no two different kinds have
  equal length unless a declared literal separates them; 113 one-byte margins
  listed, none an equality; the refusal replay shown to re-issue exactly the
  live chain's next challenges and leave its state unmoved, on a real
  internal boundary; the legacy length guard widened by the statement digests
  and the seed-derivation inputs (a 16-row legacy commitment is now refused by
  name; every real legacy geometry passes); a source scan that fails on any
  unclassified BLAKE3 call site in the lane; a source scan showing no seeded
  generator is reachable from the private block or the run; and
  `docs/zkmatrix-poc/ZK60_HASH_FUNCTION_SEPARATION_TABLE.md` on the lane —
  per pair of hash functions, what separates them, where each is built, and
  which test pins it. **One production line changed, in `run.rs`: the run now
  hands its own facts to the legacy guard; no absorb, no byte.**
- **Worth knowing on your side:** `ZkRng` is not `Clone`, so "the generator is
  never forked" is enforced by the compiler; please keep it that way. The
  `calibration` absorb is 91 bytes, one below `pb-run-block`'s 92 at all
  three runs — a margin, not a collision, now watched.
- **Waiting on you** (all asked earlier; gathered here): (1) a
  `#[cfg(test)]` consumption accessor on `ZkRng` — five of the seven
  assertions of the blinding-independence test are blocked on it, and the lane
  carries a test that fails the day it lands; (2) which gate pins the two CUDA
  BLAKE3 kernels' agreement on a hiding commitment of the toy block, and the
  lifetime of the device and pinned buffers that carry pads and blinding rows —
  until then the accepted toy statement is CPU-only; (3) one schema-3 capture
  of the toy block from the `4751b93` binaries; (4) your word on the
  `#[cfg(test)]` observer in `protocol::check_opening_challenges` and on a
  squeeze-counter accessor on `Transcript` (two tests are partial without
  them); (5) when you start merging the lane with main, say so — the Python
  pins need a third `zk.rs` digest the same hour.

### 03:25 (2026-09-21) — TWO REQUESTS and one scope ruling that is about your code: the accelerator at the untagged profiles; a consumption accessor in `rng.rs`

1. **D22 now says it covers the toy profile on the CPU path only**
   (`ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_DISPOSITION.md`, ruling J-3;
   written into the statement and the register). The tagged commit declines
   the accelerator; **the legacy commit does not** —
   `commit_zk_owned_with` (`zkp-core/src/pcs.rs:728`) has no tag gate, and
   `private_seam::prepare` goes through it — so at the toy and the frozen-seam
   rung a `gpu-cuda` build with `HL_GPU=1` hashes the columns of `A`, `H` and
   the endpoints with **two hand-written CUDA BLAKE3 kernels**
   (`kernels.cu:512/582` via `cuda.rs:2741, 3597`; and the chunk-streamed
   `kernels.cu:1429` via `cuda.rs:1741, 2154, 2242`), and blinding rows and
   pads travel to device and pinned host memory. Agreement with the CPU
   function is pinned by your differential probe (`cuda.rs:2795`) and the
   proof-byte parity gates — good, but it is not the hash-domain argument, and
   all my evidence for D22 is CPU-only (the capture runner strips `HL_*`).
   **Request: tell me which gate, by name and log, pins the two kernels'
   agreement on a hiding commitment of the toy private block, and what the
   lifetime of the device and pinned buffers holding pads and blinding rows
   is** (zeroed? reused across proofs? through your new pool?). With that I
   can read it and extend D22 to the accelerator path; without it the
   statement stays CPU-only. This is the same question as the buffer pool I
   raised at 22:07. *(Citations corrected at 03:45 by the errata pass, which
   re-read them at `8c5922b`: the chunk-streamed kernel `k_hash_cols_stream`
   has **three** launch sites — `cuda.rs:1741` in `commit_zk_chunked`, `:2154`
   in `commit_chunked`, `:2242` in `commit_chunked_upload`; and the
   differential probe is `dev_hash_check` at `cuda.rs:2783`.)*
2. **Request: a consumption accessor on `ZkRng`** — for example
   `#[cfg(test)] pub fn consumed(&self) -> u64` (bytes or draws taken so far),
   nothing else. It is what the blinding-independence test needs (ruling J-5;
   ruling R-3 before it): seven assertions, five about stream positions —
   every commitment's blinding, pads, mask rows and salts come from disjoint,
   schedule-determined positions, summing to the counted 327,052 draws at the
   toy and 109,728,784 for a twelve-block 125M run — and two about values. An
   independent re-enumeration tonight found **no generator draw inside a
   parallel region and none behind a witness, challenge, refusal, feature or
   environment branch**, and the field sampler is a reduction of exactly 16
   stream bytes; but that is two readings, not a test, and it is what excludes
   the project's two known counterexamples (a shared blinding row; two rows
   with coinciding values, which no rank gate can see). I will not touch
   `zkp-core/src/rng.rs` without your word.
3. For your own accounting: a proof uses **three generators** (the block's
   and the two endpoints'; a run: one for the whole run plus the two external
   endpoints'), each seeded by its own operating-system entropy read; their
   independence is an assumption about the OS, now written down. And the
   generator's refill is an unkeyed BLAKE3 query in the same function a
   verifier can query — so "the oracle is independent of the prover's
   randomness" is never a premise; it is what the generator assumption buys.

### 02:04 (2026-09-21) — night report: lane at `5758b95` (pushed), Python gate at `eacdddc` (pushed); three more rulings; five things that touch YOUR side, two of them soundness

**The lane since 00:04 — stage 24, tests and one new refusal; nothing an
existing profile proves moved** (receipts 2,816,472 / 4,218,600 / 4,234,984 /
4,743,128 / 40,783,352 B; filter `private_` 285 passed, none failing; shared
and frozen files untouched since the two tag commits).

**What touches you:**
1. **Soundness — host discipline was checked by nothing at the shaped
   layouts** (ruling C-3 of `ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md`): no
   test and no production check compared the hosted-claim lists written
   literally in the slot definitions with the host table; the old assertions
   were against the toy's constants. **Now a test at all five shapes — 6
   hosts, 12 hosted claims, each hosted exactly once by a host that runs after
   it; no mismatch found.** If you restructure a slot for speed, that test is
   the one that tells you a hosted claim went missing.
2. **Soundness — the model behind the hash tag (proposed D19b).** An
   independent check found that my register entry D19a mislabelled its own
   assumption: the leaf and node functions are one BLAKE3 mode under two
   *published* keys, which is not the designers' mode-separation claim; the
   honest model is an ideal compression function at a chaining value the
   adversary chooses. It is on Victor's page with my recommendation to accept;
   nothing accepted rests on it. It bears on your soundness accounting of the
   tagged profiles exactly as on my privacy accounting. **Also corrected: the
   randomness generator's stream is plain unkeyed BLAKE3 over key ‖ counter —
   only its key derivation is keyed; the doc comment at
   `zkp-core/src/hashtag.rs:22-33` says otherwise and should be fixed at
   integration** (a comment; I did not touch your crate for it). And
   `zkp-core`'s pairwise-distinct key test covers 8 of the 12 keys that exist
   (the four-group rung is missing); the lane now covers all 12 from the
   profile registry.
3. **For your run wrapper — the hidden input is fixed by the header, and the
   forward pass is already done before it** (ruling H-1 of
   `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md`): the run header absorbs
   both external endpoint roots before any challenge, so a caller has computed
   the final output before stage 0. **Rule: seal the endpoints with the
   witness builder's own pass, refusals included** — then an inadmissible
   input is refused before any segment exists (tested on the lane: no
   directory, no segment). The rule is written into `RunWitnessSource`'s doc
   comment. Rule M-9 stays as the second line — and note that **M-9 has no
   production code behind it today**: the verify-then-publish writer is
   test-only and `prove_run` has no production caller. That is your wrapper.
4. **A one-byte margin to know about:** the 125M **run** profile's transcript
   constructor input is 46 bytes; a squeeze input is 47. They cannot collide
   (a constructor input would have to spell `squeeze` at a fixed offset after
   a hash state), and a lane test now watches every registered profile's
   length. If you add a profile string, run that test.
5. **The capture writer now lists 15 source files** (was 8): the four the
   Python gate asked for plus three the enumeration found — the parent
   `private_block.rs` (whose `ExpectedIo::to_bytes` the run header absorbs),
   `witness.rs` and `pad.rs`. Future bundles only; committed ones untouched.

**Also new on the lane:** a named `Shape::new` refusal for the mask budget
(a violating shape *was* constructible: 2^20 − 1 tokens over 2,048 heads); the
head-dimension refusal now documented and tested as protecting the rotary
slots' two claims on one plane as well; the closure polynomial evaluated on
extension-round-supported vectors with arbitrary values at every shape — 375
evaluations, all zero, and both mechanisms observed separately (at the toy,
slots 08 / 09 rely on the other private factor; at the shaped layouts every
monomial carries a public factor); the trailer-equals-next-header-tag property
of the stage loop pinned.

**On paper, since 00:04** (all committed, each drafted, attacked and ruled):
the slot closures at the shaped layouts (holds with changes; masking tight at
1,120 checks; no verifier-side panic reachable from a receipt); the hash layer
and lift for a run (every hash term at least 37 bits below the sampler's
2^-69.3); and a **draft, under check now, of the one lemma never closed — the
sequential composition for (field, hash) messages.** One thing in that draft
you may care about even unchecked: the project's own phrasing "for arbitrary
challenge functions" is false for this protocol — a constant challenge
function would steer the one input-dependent refusal to certainty — so that
term genuinely needs oracle-like challenges.

### 00:04 (2026-09-21) — end-of-day state for you: lane at `8c5922b` (pushed), Python gate at `6667aba` (pushed); what is yours to pick up, what is mine next

**The lane since the tip I named at 21:03 (`e6b612f`): additions and two
refusals, nothing an existing profile proves moved.** Receipts 2,816,472 /
4,218,600 / 4,234,984 / 4,743,128 / 40,783,352 B; toy freeze gates green;
filter `private_` 275 passed, none failing; shared and frozen files untouched
since the two tag commits `d2e5988` and `7de6ea1`.
- Stage 22: `Shape::rung_k4` (the 125M head geometry at development size) and
  a run statement that describes public weights only (23:06 entry).
- Stage 23 (`8c5922b`): **two named `Shape::new` refusals.** (1) Ruling S-1:
  the lookup-table domain must sit at exactly the row width — a violating
  shape (the toy's axes at `log_cols = 7`) *was constructible* before tonight.
  It protects an **argument, not a proof**: such a shape would still produce
  verifying receipts; what would stop holding is the reading of what they
  disclose. (2) Ruling S-3: `head_dim` below the row width — a violating shape
  (one head of 256 at `log_cols = 8`) was constructible too, and every proof
  at it would have been refused. A dependency nobody had connected: what keeps
  `SC_PV` out of the same trap is the unrelated refusal `head_dim ≥ 2`, written
  for the rotary partner bit; it is now asserted as such. Also: the
  independent layout model derives every shape's endpoint geometry itself and
  **equals the Rust to the byte at all five shapes with no correction term
  left**; and a test pins the refusal order inside an opening (each group
  position tested for zero in order and short-circuiting; the determinant
  reading exactly the two proximity rows; audit → group count → challenges,
  the transcript untouched until the first two pass) on a real two-block dense
  capture, through existing hooks only. **One hook is named and not built**,
  because it needs a production file: a `#[cfg(test)]` observer inside
  `protocol::check_opening_challenges` to see the live order in
  `prove_core` / `verify_core`. Say if you would take that.
- The Python gate (23:57, `6667aba`): the four-group shape went through with
  nothing failing to scale; the toy gates now pin all 29 files on the toy's
  path at your `4751b93` (20 were pinned by nothing until tonight; none
  refused). One gap it found in itself: `run_capture.rs`, `run.rs` and
  `boundary.rs` are pinned by no run-gate tool — recorded, owed.

**Yours to pick up, in the order I would take them:** (1) integrate the two
tag commits and the lane (the merge with `4751b93` needs a third accepted
`zk.rs` digest in the Python pins — tell me when you start); (2) the three
Python source pins of S17-F1; (3) one schema-3 toy capture from the
`4751b93` binaries, so D22's re-read becomes a replay; (4) the legacy
verifiers' path-length check; (5) the run wrapper with rule M-9, the
refusal-reason rule and a statement that describes public data only; (6) your
three speed levers, measured on `HL_PB_WEIGHTS=dense`, with the three
boundary refusals, the claim audit and the table-domain invariant left alone;
(7) your word on a `#[cfg(test)]` draw-position hook in `zkp-core/src/rng.rs`
(for the blinding-independence test) and on the observer hook above.

**Mine next:** the run gate's own run-layer pins; the blinding-independence
draw accounting once you answer (7); the slot closures as a reading at the
shaped layouts and the sequential lift for a run (the two paper gaps left on
a run's privacy path); the non-degenerate-witness rule applied retroactively
to anything of mine that still reports on the old fixture.

### 23:30 (2026-09-20) — the per-commitment lemma at the shaped layouts is checked and ruled (`ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`); three things in it touch you

- **The figure I asked you not to quote is now confirmed and ruled (S-4):**
  the inverted lookup denominators fall in three families of at most 256
  arguments — byte values, exponent-table rows, activation-table rows; the
  three table helpers are subsets — so **at most 768 distinct arguments per
  block at every shape: 2^-118.4 per block, 2^-114.8 for a twelve-block 125M
  run** [COUNTED twice, independently, from `protocol.rs`]. The raw
  2^-101.4 / 2^-97.8 remain valid upper bounds. If your soundness accounting
  carries the same event (a zero LogUp denominator), the same refinement
  applies to it: the union is over distinct arguments, not over inversions.
- **An invariant you should know before you touch the lookup helpers
  (S-1):** the privacy argument needs the lookup-table domain to sit at
  **exactly the row width** — `log(Dom::Tab) == log_cols`, which ruling P-3's
  lift gives today at every shape. `SC_ZS`'s claim on `H_U` and the pairless
  sum claim put data weights on the helper commitment's two zero-sum rows,
  and only that equality keeps those weights independent of the evaluation
  point. It is becoming a named, tested shape refusal on the lane (stage 23,
  running). **If an optimisation of the helper commitment wants to split or
  re-tile the table domain, stop and ask.**
- **A finding of the draft that was STRUCK, so that nobody builds on it:** the
  opening-group-count check is *not* a privacy check. `check_opening` runs
  the claim audit first, and on a two-site boundary the audit forces exactly
  two claims; the only thing the count check can still catch is a key merge,
  a liveness event with computed disclosure 0. What a boundary's hiding does
  rest on: the audit's pair exclusivity, the two zero-mask refusals and the
  proximity-determinant refusal — with 6 generators on 6 non-data rows a
  boundary has **zero slack**, and its 6 × 6 determinant factorises exactly as
  `Norm(λ₁cm₁)·Norm(λ₂cm₂)·wedge(prox)`. **None of those three may be relaxed
  for speed.**
- Also ruled: a named refusal for `head_dim ≥ row width` (there the repaired
  score slot's two claims would share a column key on every run — every proof
  refused; no shape in scope is near it). No structural key collision exists
  for slots 08 / 09 at any shape in scope (2^-768 and below); the pre-repair
  schedule also discloses 0, so S19-F1 was privacy-neutral in the linear view.
- The 125M dense recipe is re-confirmed admissible under stage 22's new
  hidden input (witness-only census, 61.6 s, exit 0; lane tip `823d86d`,
  pushed). At the 125M shape the lemma is an argument plus counts;
  nothing is measured there and nothing can be with the present Python tools.

### 23:06 (2026-09-20) — lane at `ff53c33` (pushed): ADDITIONS ONLY on top of `e6b612f` — a development shape with four key-value heads, and the run statement now describes public weights only. Nothing an existing profile proves moved

- **What you integrate is unchanged.** Every existing profile's receipts,
  digests and tests are where they were (2,816,472 / 4,218,600 / 4,234,984 /
  40,783,352 B; toy freeze gates green); shared and frozen files untouched;
  filter `private_` 267 passed, none failing. If you cut a delta against
  `e6b612f`, `ff53c33` adds `Shape::rung_k4`, its two profile strings, one
  measured arm in the dense recipe's band table, and tests.
- **`Shape::rung_k4`** — 24 tokens, width 96, hidden 192, **12 query heads of
  8 over 4 key-value heads**, padded head slots {3,7,11,15}: the 125M head
  geometry at development size, so the repaired attention slots' TWO group
  bits are exercised by something smaller than a 40 MB proof. On fully dense
  weights with a generic input [MEASURED by the lane]: the witness agrees
  with the untouched shaped kernel on every plane and all 2,304 output words;
  an independent Boolean-cube evaluation of both bilinear identities (new =
  left side; old ≠ left side on dense, = on the degenerate fixture); one
  block proves and verifies from bytes (4,743,128 B — **the independent
  Python model's own total, no correction term**, as are 21 other figures);
  a three-block run verifies from segments; **7 of 7 perturbations in the
  third and fourth groups, a padded slot included, and a key swap between
  groups 2 and 3, all rejected by the verifier.** Two tagged bundles with
  public tables (`run-i-dense-k4`, `run-j-zero-k4`) — the first captures
  anywhere with more than one group bit; the Python gate is on them now.
- **The run statement describes PUBLIC weights only** (my 21:03 note): the
  dense recipe's seed is consumed entirely by the nine public words, the
  hidden input has its own never-published seed, and a test searches the
  whole statement file for it. The public weights are bit-identical, shown by
  regenerating the 125M weights from the recipe each retained statement names
  and matching all 24 absorbed block digests. The two retained statements of
  tonight's 125M runs carry the old string and are not rewritten; the old
  strings stay accepted as read-only aliases. **For your run wrapper: a
  statement names a recipe or a digest for public data and NOTHING that
  describes or regenerates a hidden input — worth a deny-list test on your
  side too.**
- A consequence I am checking now: the dense tests' hidden input is a
  different vector, so the 125M dense recipe's admissibility (down band ±1)
  is being re-confirmed by the witness builder alone (one minute, no proof).
- On the paper side: the first draft of the per-commitment lemma at the
  shaped layouts is committed as unchecked
  (`ZK60_GENERIC_RANK_LEMMA_SHAPED.md`) and under adversarial check. One
  figure in it matters to your soundness accounting if the check confirms it:
  the inverted lookup denominators take at most 768 distinct values per block,
  which would move the input-dependent refusal from 2^-97.8 to about 2^-114.8
  for a twelve-block 125M run. Do not quote it yet.

### 22:07 (2026-09-20) — the D22 re-read at your `4751b93` is done: D22 covers the new tree. One request (a toy capture from the new binaries), one observation about your buffer pool for you to own

- **Result** (`ZK60_NATIVE_D22_REPIN_4751B93.md`, `zk60-native-jointview` at
  `8a3b3f1`, pushed; suite 293 passing): no hunk changes behaviour on the toy
  private block's path; none touches draw order or a pooled buffer on it.
  `zk.rs`: +380 −15, every hunk at or below line 2277 (your v3 layer prover);
  lines 1–2276 untouched, and all eighteen items the profile reaches or the
  gates port — the three constants, `mask_commit` and with it the whole draw
  order, `mask_open`, `mask_verify`, `combined_weights`, `weight_polys`,
  `poly_mul_512`, `encode_coeffs_coset`, `pcs_hash_column`, `mask_challenge`,
  `masked_prove`, `extension` — are unchanged. One pin of fourteen moved
  (`hashline/src/zk.rs`, both digests kept). The gates re-run on the four
  captures give every figure of record unchanged. The statement's suspension
  note is lifted, with two corrections to my own 21:28 note (the pinned
  `pcs.rs` is `zkp-core`'s, not hashline's).
- **A request:** the re-run shows the ports still describe the code; it does
  **not** replay a receipt your new binaries made, because none exists in the
  gate's schema — your new-tree proof of this profile
  (`results/zk60_host_private_20260920/main-gate/block-prove.log`) has no
  capture bundle beside it. **When convenient, take one schema-3 capture of
  the toy private block with the `4751b93` binaries** (your capture writer,
  your runner); the gate run on it is ten minutes on my side and turns
  "covers the tree" from a reading into a replay.
- **Your buffer pool, read as a privacy question** (it is off D22's path; this
  is for your FFN private-IO line): `zkhostbuf` hands a caller a buffer whose
  `[0, tiled)` prefix still holds the previous holder's numbers. My agent
  checked your exactness claim against `Layout::new` in the untouched core —
  both prefixes are exactly tiled and fully written before use — and found
  the two `take` and three `give` sites all inside
  `prepare_layer_zk_v3_inner` / `PendingV3::finish`. It could **not**
  establish the P3 mask-row geometry or the fused `fold_block_i8` arithmetic;
  those are yours to own. **A rule I would attach to any pool on a private
  path: a pooled buffer never holds pads, mask rows or salts across a `give`,
  and a test shows that a buffer taken after a private proof is fully
  overwritten before any byte of it can reach a commitment or the wire.** If
  you already have that test, point me to it.
- **A gap on my side:** `hashline/src/pcs.rs`, `private_block.rs` and the
  hashline-side `merkle`, `transcript`, `field`, `ntt` files are on the toy's
  path and pinned by nothing; the pin set is being extended to every file on
  the path.
- **At the merge of my lane with main** `zk.rs` will need a third accepted
  digest and the run gate's bundle digests a re-read; the tag commits were
  placed clear of your hunks, but whether the merge is clean is a reading to
  do against the merged bytes. Tell me when you start it.

### 21:36 (2026-09-20) — the run gate's first pass over a NON-DEGENERATE witness: every figure equals the all-zero run's; no capture defect, so `e6b612f` stands; the re-read of your `4751b93` has started

- **`zk60-native-jointview` at `50fab1c`, pushed** (suite 290 passing; I re-ran
  the 29 new tests). On `run-g-dense-s20` (fully dense weights, generic
  hidden input) and `run-h-zero-s20`: the repaired slots 08 / 09 replay and
  check under their new definition (23 slots of 23, 69 of 69; 6,092
  challenges per bundle, the group challenges included; the gate derives the
  public `eq` factor itself and compares both ways). **Of 173 figures compared
  between the dense and the zero bundle, the only ones that differ are counts
  of distinct sampled columns** — transcript randomness, not witness. No
  disclosure figure, rank, boundary or joint figure moves with the data.
  Written into the run's disposition as round 4, with the R-3 correction to
  rounds 1–3 ("joint = sum" is a model consistency check, not evidence of
  independence).
- **A sentence worth keeping on your side too:** the lane tried to make the
  gate show S19-F1 and could not, on any witness — the pre-repair definition
  fails the captured terminals 0 of 6 on both new bundles, but the defect was
  between the prover's claim and the true sum, and a capture has no witness.
  **A privacy gate checks the verifier's view; it is no test of
  completeness.** Only a generic honest witness against an independent
  reference is.
- **Not yet exercised anywhere in the gate:** a shape with more than one group
  bit (125M has two). The Rust side has it (the reviewer's four-group
  synthetic geometry, the dense 125M runs); the Python ports do not.
- **The D22 re-read at `4751b93` is running** (one agent, auditor first):
  every hunk of your `pcs.rs` and `zk.rs` delta classified against the toy
  private block's path and the functions the gates port; draw order and the
  "private host reuse" pooling looked at specifically — a pooled buffer that
  could carry pads, masks, salts or data from one commitment or proof into
  another would be a privacy finding, not a porting detail. Pins move only if
  the reading supports it. I report the result here.

### 21:29 (2026-09-20) — I see your `4751b93` on main (20:52). D22's condition 7 applies to it; the re-read is queued

- Your commit changes two files the toy gate pins — `hashline/src/pcs.rs` and
  `hashline/src/zk.rs` — so, exactly as you said at 14:04, D22 does not
  extend to the new tree on the strength of file names. I have written that
  into the statement itself (`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`, note of
  21:28): **the acceptance stands for main before `4751b93`; for the tree at
  and after it, step 3 is suspended until I have re-read the changed functions
  on the toy's path, moved the pins with both hashes kept, and re-run the gate
  on the four captures.**
- It is queued behind the run gate's round now in progress (one writer per
  worktree). If you have the list of functions on the toy private block's
  path that your delta touches in `zk.rs` — or a statement that none are —
  put it in your file; it shortens the re-read and I will check it rather
  than trust it.
- My lane is still based before your merge. The two tag commits `d2e5988`
  and `7de6ea1` were placed to merge cleanly with exactly this delta
  (`commit_planes` after `commit` in `pcs.rs`; your `zk.rs` hunks from line
  2277 on, mine around 430–700). Tell me if the merge says otherwise.

### 21:03 (2026-09-20) — THE NEW TIP: `zk60-private-block-125m` at `e6b612f` (pushed). Reviewed repair, dense twelve-block 125M run measured. The hold on slots 08 / 09 is lifted

**Production source is settled again from my side** — with the same caveat as
at 16:41, now said up front: the Python gate is running on the first
non-degenerate captures, and if it finds a defect in a *capture* I fix
test-only code and tell you. What you integrate or optimise against does not
move for that.

- **Since `caa9b9a`, in production code:** the S19-F1 repair of `SC_SCORE` /
  `SC_PV` (stage 20, `5155d5b`: group bits summed, a public `eq` factor,
  degree 3, `lkv` more main rounds; toy byte-identical); `RunStatement::new`
  refuses any block scale pair but the approved calibration's (stage 21,
  ruling R-5; no absorb added; the rung-G run's binding, boundary digests and
  parameter line asserted unchanged); a named `Shape::new` refusal for a
  shape whose bilinear domains would be lifted (it caught an existing test
  building a 5-head / 1-group probe that the slots could never serve).
  **Shared files: untouched since the two tag commits `d2e5988` and
  `7de6ea1`.** Filter `private_` 254 passed, none failing; warnings 13; the
  independent review's six tests merged.
- **The independent layout model is an oracle again** (review finding F-1):
  it derives the group rounds and degree from the shape, gained the
  generalised rung, and agrees with Rust on every figure at all four shapes —
  main rounds 159 / 217 / 217 / 336, round values 721 / 1,055 / 1,055 / 1,554,
  challenge draws 184 / 242 / 242 / 361, receipts 2,816,472 / 4,218,600 /
  4,234,984 / 40,783,352 — with the Rust-side adjustment removed.
- **125M, all twelve blocks, fully dense weights, generic hidden input**
  [MEASURED by me, one run, launched 20:53, shared box, CPU only, 12 GB
  ceiling, allocator threshold pinned; `m125-run-l12-dense.log`]: **prove
  397.71 s (32.3–34.7 s per block), verify by streaming 14.45 s, receipt
  484,107,456 bytes equal to the counted figure, peak 10.15 GiB, flat.**
  Recipe `dense_run_case` (seed and bands in the run statement, so a fresh
  verifier regenerates the public weights): the down band must be ±1 at this
  shape — every larger band pushes the chain's second block out of the
  `residual 2` range — and with it every block's upper hidden half is about
  98% non-zero, all twelve head slots and all four key-value groups live.
  Artifact: `/home/victor/zk60-artifacts/m125-run-l12-dense` (462 MB, with its
  `statement/`). One block, dense: 27.67 s prove (19:31 entry).
- **For your speed work:** the baselines are these dense figures. The two
  attention slots gained 4 main rounds of 336 at degree 3; nothing else in
  the phase table should have moved — re-take your phase split on
  `HL_PB_WEIGHTS=dense` before and after a lever. `HL_PB_INPUT=zero` and the
  default `tame` remain for regression.
- **Known small things, mine, not blocking:** the dense recipe's description
  string in the run statement also says how the synthetic hidden input is
  drawn — harmless for a test fixture, wrong as a model for a production
  statement writer, which must describe public weights only; I will split it.
  The captures a–f are superseded; `run-g-dense-s20` / `run-h-zero-s20` are
  current.
- **Your integration list, updated:** the two tag commits; the three Python
  source pins of S17-F1; the legacy verifiers' path-length check (yours);
  D22's pins when your candidate is committed; the run wrapper with rule M-9
  and the refusal-reason rule; and — new — the generic-witness rule for
  anything that says "proves and verifies".

### 19:58 (2026-09-20) — the independent review of the S19-F1 repair: NO HOLE FOUND (soundness, completeness, masking budget); lane at `901557e`, pushed; one more lane stage before I name the tip

- **`ZK60_BLOCK125M_S19F1_DISPOSITION.md`** is my ruling on the whole episode;
  the reviewer's report is `ZK60_BLOCK125M_S20_FIX_REVIEW.md` on the lane
  (its six tests merged; filter `private_` 251 passed, none failing).
- **What the reviewer did that matters to you:** drove the REAL `define` with
  its own table builder against its own extension of the product — equal at
  the toy, the rung and a synthetic four-group geometry with padded slots;
  seven of seven honest cases verify (three random dense inputs, half the
  width zero, one query head moved, all-zero, the old fixture); five of five
  cheating witnesses refused; mask lengths re-derived from the axes and equal
  to the lane's; the verifier computes the public `eq` factor itself
  (`argument.rs:389`). **It confirmed independently that the old construction
  was sound though incomplete: no pre-repair receipt could attest a false
  statement.** Its privacy verdict is on the mechanism and the budget only —
  no disclosure measurement exists at a grouped shape on a non-degenerate
  witness yet.
- **Its finding F-1 is worth your attention as integrator:** the Python
  layout model still declares the old schedule, and a Rust test had begun
  adjusting the model's expectation by a Rust-computed delta, so the shaped
  receipt figures had lost their independent witness. Being repaired in the
  model, from the shape, with the adjustment removed.
- **Stage 21 (running, lane-only, no shared file):** F-1; a named refusal for
  shapes the bilinear slots cannot serve (F-2); R-5 (interior scales become
  constants of the approved calibration — no absorb added, byte-identity
  asserted); a fully dense admissible twelve-block recipe at the 125M shape;
  re-taken captures on a fully dense witness. Then I run the twelve-block
  dense 125M proof, the Python gate learns the two repaired slots, and I name
  the tip. **Until then, please keep slots 08 / 09 and their hosts out of
  your optimisation delta; everything else in the shaped block is as it was
  at `caa9b9a` plus the D19 tag.**
- **A rule I am adopting and recommend to you for the FFN private-IO path
  too:** no "proves and verifies" without a generic honest witness — dense
  weights, non-constant hidden data — checked against an independent
  reference, and every new identity evaluated once outside the shared
  definition function. A prove-then-verify round trip cannot see a shared
  wrong definition; ours hid this one for a day.

### 19:31 (2026-09-20) — S19-F1 is REPAIRED on the lane (`a00f831`, pushed); first 125M proofs on a non-degenerate input; an independent review of the repair is running — still hold off on slots 08 / 09 until I name the tip

- **The repair (stage 20, `5155d5b`; lane-only, no shared or frozen file
  touched).** I read both arms (`argument.rs:1126-1187`): `r_h` splits into
  the group bits `r_g` (top `lkv`) and the head within its group `r_hj`; the
  group becomes sumcheck variables `rho(0..lkv)` **shared by both private
  factors**; a public factor `eq(r_g, ·)`; degree 3; `lkv` more main rounds in
  each of `SC_SCORE` and `SC_PV`. With `kv_heads = 1` the new helper returns
  nothing — no variable, no table, no degree — and the toy's frozen tests are
  green (2,816,472 B, schedule digest, parameter line, the four pre-lane
  receipts).
- **Acceptance** [MEASURED by the lane; I re-ran the first two myself]: the
  former reproducer is accepted; a FULLY dense generic block proves and
  verifies at the generalised rung; a fully dense three-block run verifies
  from segments; an independent Boolean-cube evaluation of both identities
  (no `define`, no layout, no transcript) shows **new = left side on generic
  and degenerate witnesses, old ≠ left side on generic and = on the degenerate
  fixture** — the invisibility mechanism as a test; at `kv_heads = 1` old =
  left side, the toy's exemption algebraically. Perturbations in the second
  key-value group and a key swap between groups: all rejected by the
  verifier. Filter `private_` 245 passed, none failing.
- **What moved** (all counted in tests, none pasted): receipts +336 B per
  block at the rungs, +560 B at 125M — **125M one block 40,782,792 →
  40,783,352 B; twelve blocks 484,100,736 → 484,107,456 B**; main rounds
  215 → 217 (rungs), 332 → 336 (125M); the two slots' mask lengths 14/16 →
  23/26 and 18/24 → 32/41; the worst mask length, the masking commitment's
  50 rows, terminals, claim sites and opening groups unchanged.
- **125M, one block, after the repair** [MEASURED by me, one run each, 19:25,
  shared box, CPU only, 12 GB ceiling]: **fully dense weights, generic hidden
  input — prove 27.67 s, verify 1.12 s, 40,783,352 B, peak 9.99 GiB;
  all-zero input — prove 26.98 s, verify 1.23 s.** Both verified from bytes
  and then the test stopped on one stale size literal in the ignored heavy
  test (fixed in `a00f831`). Dense weights cost no measurable time, so your
  speed baselines stand; the two attention slots gained 4 rounds of 336.
- **Not yet done:** the twelve-block 125M run on dense weights (a fully dense
  admissible *run* recipe needs a smaller down band; the lane has a probe for
  it), re-taken captures and the Python gate's ports of slots 08 / 09, the
  layout model script's two-line schedule change, R-5 (interior scales). **An
  independent adversarial review of the repair — soundness, the masking
  budget with two private factors at shared coordinates, completeness on many
  seeds, the toy path — is running in its own worktree.** I name the tip when
  it reports.

### 18:39 (2026-09-20) — STOP before you optimise the attention slots: a COMPLETENESS DEFECT in the shaped block (mine). An honest proof is rejected by the verifier as soon as the hidden state differs between heads. `caa9b9a` is NOT a base to build on for slots 08 and 09

- **Finding S19-F1, reproduced by me at 18:35** (lane `zk60-private-block-125m`
  at `d4742ce`, pushed; the test
  `private_block::dense_tests::s19_f1_an_honest_proof_of_the_fixture_with_one_input_word_moved_is_rejected`,
  run with `--ignored`): the production fixture `tame_case` at the generalised
  rung with **one word of the hidden input changed** is admitted by the
  witness builder, agrees plane for plane with the independent shaped kernel,
  and its receipt is refused: `slot 15 [04 Q zero-check (hosts 09Q, 11)]:
  sumcheck round 0: s(0) + s(1) != claim`. It affects every profile with more
  than one key-value head: both rungs and 125M. **The toy is exempt**
  (`kv_heads = 1`), so D22 and every frozen byte are untouched.
- **The cause, read by me in `argument.rs:1057-1087`** [ARGUED by me, not yet
  confirmed by a fix]: `SC_SCORE` multiplies `A_QR8` at `(r_t, r_h, ρ)` by
  `A_KR8` at `(r_j, r_h[..lkv], ρ)` and sums over the head-dimension variables
  `ρ` only; `SC_PV` does the same with `A_P` at `(r_h, r_t, ρ)` and `A_V8` at
  `(ρ, r_h[..lkv], r_i)`. **The key-value group bits `r_h[..lkv]` are FIXED
  coordinates of BOTH private factors.** The multilinear extension of
  `score[h] = Σ_c q[h,c]·k[g(h),c]` is `Σ_h eq(r_h,h)·(…)`, which is *not* the
  product of the two extensions when both depend on the shared bits: the
  product is quadratic in them. It coincides exactly when one factor does not
  vary across groups — which is every input ever proved at a shaped profile
  (`tame_case`'s norm output is +3 / −3 by parity at every token, so every head
  sees the same state; the all-zero input likewise; the review's
  `distinct_kv_case` has a zero second key-value head).
- **Soundness, as far as I can argue it [ARGUED, unchecked]:** not weakened.
  An accepted proof forces the enforced identity as polynomials, hence at
  Boolean points, where a product of extensions *is* the right relation. The
  defect costs completeness: the verifier refuses honest proofs of generic
  inputs. **So this morning's 125M results are true of what they proved — a
  degenerate witness — and the shaped block is NOT yet a working proof for
  general inputs.** I am correcting `MVP_STATUS.md` and telling Victor now.
- **The fix (starting now on the lane):** the shared group bits become
  sumcheck variables — sum over `(g, c)` of `eq(r_g, g)·q̃(r_t, g, r_hj, c)·
  k̃(r_j, g, c)`, a public `eq` factor, degree 3, `lkv` more rounds in each of
  the two slots; the same for `SC_PV`. With `lkv = 0` it must reduce to
  today's toy path byte for byte. It moves the proof bytes, round counts,
  mask lengths and receipt sizes of every shaped profile; an independent
  review of the two changed slots (soundness and the masking budget) follows
  the fix. **Please do not cut an optimisation delta against slots 08 / 09 or
  their hosts (15, 17) until I name a new tip.** The feed-forward side held up:
  a dense feed-forward block and a dense three-block run prove and verify, and
  11 of 11 perturbations at hidden indices ≥ d are rejected by the verifier.
- **Also from the same stage:** the all-zero hidden input IS admitted by the
  witness builder at the 125M shape under both recipes, with zero headroom on
  one bound (softmax remainder complement 262,143 of 262,144) — pinned as
  normal tests. The heavy dense and zero 125M runs wait for the fix.
- **How it was missed, for both of us:** every shaped proof, the code review's
  80 perturbations, the captures and the Python gate all ran on one fixture
  whose hidden state is identical in every head. The layout design, its
  checker and the reviewer attacked soundness and privacy; nobody proved a
  generic honest witness. The dense-recipe test now exists for that.

### 18:00 (2026-09-20) — CORRECTION to "production source is final": ONE small production change is coming in `run.rs` (no proof byte moves); and three rules for your run wrapper, from the check of the run's privacy argument

`ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md` (register D12b). The argument
survived as a reduction and every counted figure reproduced; what it turned up
is about the code and the operating rules.

- **The change (mine, lane stage 20, after the test-only stage now running):
  `RunStatement::new` will refuse any block scale pair other than the approved
  calibration's.** I read it myself: the per-block scale pairs are a caller
  argument (`run.rs:113`); the external ones are bound through the absorbed
  expected-IO bytes, **the interior ones by nothing** — they are not in the
  parameter line, not in the stage lines, and `BoundarySpec::digest()` is
  never absorbed. They have no arithmetic effect, so no equation is at risk,
  but a receipt does not attest to them, and a scale chosen from the input
  would publish a hidden intermediate's range. Restricting them to the
  approved constants (as `IoSpec::new` already does for endpoints) binds them
  through the calibration identity the run already absorbs. **No absorb is
  added, so no proof byte, capture or measurement moves.** If you have already
  cut your delta against `caa9b9a`, this touches only `RunStatement::new` and
  tests.
- **For your wrapper — a run's refusal is not challenge-only.** A run builds
  block k's witness *inside* stage k (`run.rs:461-473`), after segments
  0..k−1 are on disk under their final names; twelve of the witness builder's
  fourteen refusal sites are range checks on hidden values. So an inadmissible
  input is discovered at its first inadmissible block, with certainty, and
  leaves that many finished segments behind. Rules (M-9): **a directory
  without `statement/run-statement.json` is not a run — never transmitted,
  removed by the launcher**; **which stage refused is a function of the hidden
  input and is never shown to anyone not entitled to it**. Your "stage
  privately, verify the whole run, then publish" is exactly right; this is why
  it is necessary and not only tidy. An admissibility pre-pass before segment
  0 is recorded as the alternative, not built.
- **One generator per run is accepted as built** (`run.rs:436`); the design's
  one-per-commitment was a recommendation and is withdrawn. Condition: never
  cloned or serialised, and the run's hidden input fixed before the first
  segment.
- **Figures corrected.** The input-dependent refusal inside the argument
  scales with the number of inverted lookup denominators: 2^-112.0 at the toy,
  2^-101.4 per 125M block, **2^-97.8 for twelve** by raw count — my 09:50
  figure of 2^-108.4 multiplied the toy's by twelve and was wrong. It lands on
  the layout memo's own dominant soundness term, so it matters to you too.
  Liveness is about 2^-58.8 for a twelve-block run. The run draws 109,728,040
  field elements (the design and its checker both missed the helper
  commitment's zero-sum re-draw, `protocol.rs:760-768`); the residual 2^-69.3
  stands.
- **A request, not urgent:** to machine-assert that the 4L + 1 commitments'
  blinding comes from disjoint positions of the stream, a test needs to see
  the generator's position (a draw counter or an instrumented wrapper). If
  `zkp-core/src/rng.rs` has no such hook, would you accept a `#[cfg(test)]`
  one? I will not touch that file without your word.

### 17:33 (2026-09-20) — the weights oddity is a FIXTURE quirk, not a defect — but it is a coverage hole in everything shaped, my 125M numbers included; a test-only stage is closing it; production source unchanged

- **Verdict, with evidence:** `grow_tests.rs:583` — the only weights recipe
  the shaped tests know (`tame_case`) is `diag(outer, inner)`: 64 on the
  diagonal, zero elsewhere; the down matrix is `diag(f, d)`, gate and up
  `diag(d, f)`. With f > d, hidden units d..f−1 get zero input and zero output
  weights. The investigator re-derived slot 13's captured 256-long public
  table entry for entry as `64·eq(r_j, i)` for i < 96 and 0 elsewhere. The
  layout reads right in both directions (`argument.rs:1100-1110`,
  `zkp-core/src/mle.rs:141-154`, `private_block.rs:429-435`), the witness
  builder and the shaped kernel both sum over the whole hidden axis
  (`witness.rs:312-320, 685`; `private-block-kernel-shaped/src/lib.rs:517-531,
  819`).
- **Why it still matters.** The toy has d = f = 16 and can show neither this
  nor an axis mix-up. At every shape with f > d — the rungs and 125M — **the
  upper part of every hidden-layer plane has been identically zero in every
  honest proof run so far**, and attention has only ever seen diagonal
  projections. An indexing error confined to hidden indices ≥ d, or to
  off-diagonal weights, would be invisible to all existing tests, the code
  review's 80 perturbations included. Nothing suggests there is one.
- **What I am doing (stage 19, TEST-ONLY, running):** a seeded dense recipe
  for all seven matrices with an admissible non-trivial witness; the witness
  builder against the independent shaped kernel on it; a dense block and a
  dense three-block run proved and verified at the generalised rung;
  perturbations at hidden indices ≥ d each rejected; the one-sided
  non-triviality assertion in `pad.rs`'s test tightened; a dense option for
  the heavy one-block 125M test, which I will then launch. **No production
  code path changes; `caa9b9a` stays the stable tip for your delta.** If a
  dense test fails for what looks like a production reason, the lane records
  the failing test and I bring it to you at once.
- **For your speed work:** `fold_cols_i8` / `fold_rows_i8` skip zero weights
  (`mle.rs:133, 149`), so with diagonal weights the seven weight folds per
  block cost about min(rows, cols) instead of rows × cols. My 125M timings
  are optimistic by that phase — about a second per twelve-block run by the
  investigator's estimate, not measured. Measure your levers on dense weights
  once the recipe lands.

### 17:28 (2026-09-20) — the Python run gate passes under the tag (23 slots of 23; the hash layer computed); no capture defect found, so `caa9b9a` stands as the stable tagged tip; two things the privacy drafting turned up in `run.rs` for your eye

- **`zk60-native-jointview` at `8bab0f5`, pushed.** On the two tagged bundles:
  the gate derives the four keys itself and compares (never consumes) what
  the bundle names; the whole-run replay re-derives 375 positions, 6,086
  challenges and 6 of 6 position tags per bundle under the keyed function;
  **3,328 of 3,328 opened columns re-hashed and authenticated** (digest →
  salted leaf → path), every path length checked; **the terminal identity
  now checks in all 23 slots, 69 of 69**, the eleven new ones from the
  captured public tables; fourteen controls fire (a tagged bundle claiming
  the legacy rule is refused by name, and forced through the legacy rule it
  authenticates 0 of 3,328 columns). Disclosure, rank and joint figures are
  identical to the untagged rounds. Suite 261 passing [MEASURED by the lane; I
  re-ran the 29 new tests]. **The Rust captures needed no change: `caa9b9a`
  is the stable tagged tip.** Not a privacy claim about any run.
- **One oddity in the PUBLIC test weights, being looked at now, read-only:**
  at the generalised rung the down projection's fold is nonzero on only 96 of
  192 hidden indices. Either the synthetic generator leaves half the matrix
  zero, or an axis or length is wrong somewhere in the down matmul's public
  table (the toy has width = hidden = 16, which would hide that). Prover,
  verifier and tool agree with each other either way, so it is a
  statement-correctness question, not soundness or privacy. I will tell you
  what it is before you cut the optimisation delta if it turns out to be the
  second.
- **From the first draft of the run's composition argument
  (`ZK60_JOINT_LAW_COMPOSITION_RUN.md`, committed as an unchecked draft; an
  adversarial check is running)** — two facts about the code, stated by the
  drafter with `file:line`, not yet confirmed by the checker: (a) `prove_run`
  creates **one** `ZkRng::from_os` for the whole run (`run.rs:436`) and hands
  it to every stage and boundary, where the design's ruling R-D4 had one
  generator per commitment; only the two external endpoints keep their own.
  I have not ruled on it — one fail-closed entropy point has its own merit —
  and nothing needs changing today. (b) The input-dependent refusal class is
  shape-dependent: the toy's 2^-112 becomes about 2^-101 per 125M block
  (103,890,944 inverted lookup denominators), about 2^-97.8 for twelve.
  If the check confirms it, the figures in my 09:50 entry were low by ten
  bits; it lands on the layout memo's own dominant soundness term.

### 16:41 (2026-09-20) — HAND-BACK: the tagged Rust tip is `zk60-private-block-125m` at `caa9b9a` (pushed). Production source is final from my side; the heavy lock is free

**What "final" means.** The prover, the verifier, the wire format, the run and
its sink will not change again on my side. The only thing still in flight is
the Python run gate learning the keyed rule on its own branch; if it finds a
defect in a *capture* (test-only code, `#[cfg(test)]`), I will fix that and
tell you — nothing you integrate or optimise against would move. So you can
cut your optimisation delta against `caa9b9a`.

**Stage 18 (lane-only; `dc16648`), then my evidence commit `caa9b9a`:**
- *The legacy length guard is off for tagged endpoints and boundaries* (your
  fourth point): `EndpointSpecG::new_with_tag`, `BoundarySpec::new_with_tag`;
  the bare constructors mean the legacy rule and stay fail-closed. Shown
  failing first (a tagged 13-row endpoint refused), then fixed; legacy-rule
  geometries are still refused by name.
- *The public run statement beside the segments* (your 14:04 request):
  `<run dir>/statement/run-statement.json`, schema
  `hashline-private-run-statement/1`, written **only after the whole run has
  verified**; a corrupted segment leaves no `statement/` at all. Segments keep
  their names and bytes at the top level; the sink allows exactly that one
  directory and still refuses everything else. **A fresh `RunVerifier` built
  from the file plus the public weights recipe alone verifies a three-block
  run** (test), and eight one-byte tampers are each refused — a flipped
  endpoint commitment lands on the run binding. Public weights are not dumped;
  the recipe and digests are. I read the writer against the capture rule: it
  takes the verifier's statement types and nothing else.
- *Two re-taken bundles under the tag*, with the public tables' values:
  `results/zk60_run_captures_20260920/run-e-tame-tagged`,
  `run-f-zero-tagged` (82.5 MB the pair); a–d are legacy-rule and superseded
  for gate purposes (README says so).
- Counts [MEASURED by the lane, log read by me]: filter `private_` 222 passed,
  none failing, 7 ignored (was 214); warnings 13; receipt sizes unmoved; **no
  shared file changed in stage 18** — the whole shared change is still the two
  commits `d2e5988` and `7de6ea1`.
- **The tagged 125M runs** [MEASURED by me, one run each, shared box with one
  agent doing light work, CPU only, 12 GB ceiling, allocator threshold pinned;
  launched 16:30, finished 16:39; logs `m125-run-l12-tagged.log`,
  `m125-one-block-tagged.log` on the lane]: **twelve blocks — prove 393.59 s
  (32.4–34.0 s per block), verify by streaming 14.09 s, receipt 484,100,736
  bytes equal to the counted figure, peak 10.15 GiB; one block — prove
  27.87 s, verify from bytes 1.21 s, 40,782,792 bytes, peak 9.99 GiB.** About
  5% over the morning's untagged figures. **I do not attribute it to the
  tag**: the two `commit_zk_owned` calls moved 3.00 → 3.37 s and 3.63 → 3.52 s
  (one up, one down), while the helper inversions — no hashing in them — moved
  3.92 → 4.25 s. A quiet-box A/B would settle it; I have not run one.
- The twelve-block artifact is at
  `/home/victor/zk60-artifacts/m125-run-l12-tagged` (462 MB, outside the
  repository, with its `statement/`); a copy of the statement is committed
  beside the logs. To reproduce: the 11:25 entry's command with
  `HL_PB_RUN_DIR` pointed at a fresh directory; the test binary is
  `…/target/release/deps/hashline-70a7a72f73401de5` (built 16:22).

**For your integration list:** (1) the two shared commits; (2) the three Python
source pins of finding S17-F1, to move with both hashes kept; (3) the one-line
path-length check in the *legacy* verifiers, yours to decide; (4) D22's pins
when your candidate is committed — tell me the commit; (5) the command-line
wrapper and its publication boundary, with the refusal-reason rule. **The
three speed levers are yours from here.** From my side next: the Python gate
under the tag, then the privacy argument owed at the new shapes.

### 15:52 (2026-09-20) — the D19 tag is BUILT and reviewed: `zk60-private-block-125m` at `9ded619`, pushed — reviewable now, NOT yet the stable tip

- **The shared-file commits, apart from everything else:** `d2e5988`
  (zkp-core) and `7de6ea1` (hashline); no lane file in either. Per file
  [COUNTED by me from the diff]: `hashtag.rs` new (+253), `lib.rs` +5,
  `merkle.rs` +76, `zkp-core/pcs.rs` +444, `hashline/pcs.rs` +13, `zk.rs`
  +105 — **additions only** — and `transcript.rs` +76 −4. I read the four
  changed lines: `key: None` in `new`'s struct literal; the hasher built from
  the optional key in `absorb` and `squeeze_bytes` (with `None`, the identical
  `blake3::Hasher::new()`); `clone_state` copies the key, so the run's
  position tags stay in the keyed function. A unit test recomputes the legacy
  transcript by hand and pins it.
- **Functions added**, each right after the legacy one it mirrors, none a
  forward: `Transcript::new_tagged`; `hash_pair_keyed`, `build_keyed`,
  `verify_path_keyed`; `hash_column_keyed`, `hash_columns_keyed`,
  `salt_leaf_keyed`, `commit_zk_owned_with_tag`, `verify_zk_tagged` (which
  also refuses a path of the wrong length — in the new function only);
  `commit_zk_owned_tagged` in `hashline/src/pcs.rs`, beside
  `commit_zk_owned`; `mask_commit_tagged`, `mask_verify_tagged`,
  `pcs_hash_column_keyed` in `zk.rs` around lines 430–700, far from your
  hunks. The tag type is opaque: `HashTag::legacy()`,
  `HashTag::for_profile(&str)`, four read-only accessors.
- **Your four review points, as built:** the verifier takes the tag from its
  shape's profile, never from a receipt; no mixtures (toy and frozen-seam rung
  wholly legacy; generalised rung, 125M and runs wholly tagged); **in both
  cross-rule directions the first refusal is Fiat–Shamir** — a sumcheck round
  check in slot 0 — exactly as you predicted, and the layers are identified by
  isolated column, leaf, node and transcript controls in `zkp-core`; a tagged
  commitment declines the device hasher, commented as a temporary CPU
  fallback.
- **Counts** [MEASURED by the lane, logs read by me]: filter `private_` 214
  passed, none failing (was 208); `zkp-core` 50 passed; the legacy-side
  filters `pcs`, `merkle`, `transcript`, `mask`, `zk::` all passing; warnings
  unchanged at 13; receipt sizes unmoved (2,816,472 / 4,218,264 / 4,234,648 /
  40,782,792); `private_seam.rs`, `layer.rs`, `wcache.rs`, `gpu/*`,
  `native_capture.rs` and the three frozen crates untouched.
- **One thing integration will meet (the lane's finding S17-F1):** three
  Python tests pin the SHA-256 of Rust sources this change moves (`zk.rs`,
  `zkp-core/pcs.rs`, `zkp-core/transcript.rs`, through
  `zk60_round22_captures.json` and `zk60_round19_validation.json`). The lane
  did not re-pin. My ruling is in the tag disposition §2b: the change
  preserves what those analyses concluded (two files gained lines and lost
  none; the third changed four lines that are the identical call under the
  legacy rule). The pins move at integration with both hashes kept — together
  with whatever your own candidate moves in `zk.rs`.
- **A design choice you may want to look at:** a run is keyed under its
  shape's keys, not under its run profile string; the run is separated from a
  single-block proof by its own domain string, absorbed first under the
  transcript key. I accepted it (a block inside a run is then hashed exactly
  like a standalone block). Say so if you see a reason for run-level keys.
- **Still to come before I call the tip stable** — stage 18, running now,
  lane-only: the legacy length guard switched off for tagged endpoints and
  boundaries (your fourth point; stage 17 left that half on); **the public
  run statement retained beside the segments, written only after the whole
  run verifies, with a fresh-verifier test that the file is sufficient** (your
  14:04 request); two re-taken capture bundles under the tag with the public
  tables' values. Then I launch the tagged 125M runs myself (one block for
  timing, twelve blocks for the artifact) under the heavy lock, and the
  Python gate learns the keyed rule. If you need the heavy lock in the next
  two hours, take it — mine queue behind it.

### 15:02 (2026-09-20) — your 14:22 review of the tag: all four points accepted, two of my rulings changed by them; stage 16 landed; the tag stage is running

- **Read in your working copy at 14:59** (your note is not committed yet).
  Thank you for the go-ahead on the five shared files and `hashtag.rs`; and
  understood that it is engineering ownership, not acceptance of the argument.
- **Your four points, as rulings** (`ZK60_D19_HASH_TAG_DISPOSITION.md` §2a;
  register entry D19a):
  1. *Keys are never an input.* The tag type is opaque — the legacy rule or
     one profile's complete key set, built only by `legacy()` or
     `for_profile(profile)`; no public fields, no partial sets; the verifier
     derives it from its trusted profile; the mode is carried through every
     endpoint, boundary, masking tree and transcript clone, **the run's
     position tags included**. **No mixtures — which overturned my own T-2**:
     the frozen-seam development rung now stays on the legacy rule as a
     whole, named as a fixture outside the obligation and barred from any
     privacy statement.
  2. *Not injective.* My "can never share a key" is corrected to "negligible
     collision probability", and the model is stated: D19's oracle read as a
     family of independent random functions by BLAKE3 mode and key. Timing
     will be measured, not inferred from the compression count.
  3. *Mismatch may die at Fiat–Shamir first.* The cross-rule tests require
     refusal in both directions whatever refuses first, and the layers are
     identified by isolated column, leaf and node controls.
  4. *No legacy length bans on a tagged shape.* Agreed, and stage 16 had just
     shown why: the completed guard refuses geometries the constructions
     really reach (a 13-row generalised endpoint, a 12-row boundary), and the
     run's parameter line sits two bytes from a boundary column's length at
     the 125M shape. The guard now applies to legacy-rule profiles only; the
     toy's accepted geometry passes it. The accelerator decline is recorded
     as a temporary CPU fallback, nothing more.
- **Stage 16 landed: `f67f3fc`, pushed** — lane-only; filter `private_` 208
  passed, none failing (was 195); shared files touched: none. The explicit
  path-length check now refuses a truncated path by name before any hashing
  (before it, the refusal came from deep inside the core verifier as a Merkle
  mismatch). The completed length set found one thing the memo missed: the
  `pcs-prox` absorb is always a multiple of eight bytes (1,031 / 2,567 /
  33,287 rows would collide) — harmless at every real shape.
- **Stage 17 (the tag) is running.** Placement, so it merges with your
  working copy: nothing in `zkp-core` conflicts (you have not touched it);
  in `hashline/src/pcs.rs` the adapter goes beside `commit_zk_owned`, well
  below your `commit_planes` insertion after `commit`; in `zk.rs` the two
  tagged mask functions go in the 430–600 region beside the legacy ones, far
  from your hunks (2277 onward). Shared-file changes in their own commits,
  old bodies untouched except the three transcript sites (hasher built from
  the optional key; `None` is today's call). The new `verify_zk_tagged` also
  checks the path length — in the new function only; the legacy verifier is
  yours.
- **Your next speed work (softmax slot, hiding commitments, lookup helpers):
  yours, as offered at 08:48 — I start none of them.** The stable tagged tip
  comes first; I will name it here. After stage 17 I review it myself, then
  stage 18 re-takes the captures (with the public run statement you asked
  for, and the public tables' values the Python gate needs).
- **D22 and your applied candidate:** I see the ten-file delta in main's
  working copy. The pins move when it is committed — tell me the commit.

### 14:52 (2026-09-20) — the run gate now checks the per-slot terminal identity at the development shape: 12 slots of 23, 36 of 36 equal; the other 11 wait for a capture that includes the public tables

- `zk60-native-jointview` at `fdc210e`, pushed; new modules only
  (`zk60_native_rg_planes.py`, `zk60_native_rg_terminals.py`,
  `zk60_native_rg_tcontrols.py`), the toy gates' files untouched (their record
  guard still passes); suite 232 passing [MEASURED by the lane; I re-ran the
  39 new tests].
- Checked, every stage of both new bundles: the pad-zero term and support
  gates, the grouped-head slots, the third limb, and **both boundary claim
  sites**. Five controls fired for their stated reasons. The old bundles give
  2,189 identical leaves each and stay OPEN on that channel, not "passed".
- **Open, and why:** eleven slots need the *values* of public tables (folded
  public weights, norm gains, the rotary pair, the exponent table); the
  bundles carry only lengths and hashes. Nothing hidden is missing. The
  re-capture owed under the D19 tag will be taken with
  `HL_RUN_CAPTURE_PUBLIC_TABLES=1`. Channel count 15 open of 24 (one channel
  honestly split in two). No privacy claim about any run.
- Useful to you when you review the capture: `slot_planes` repeats a plane
  name when a slot reads sub-slices (`A_LIMB` nine times), so resolve by
  occurrence, never by a name-to-index map.

### 14:26 (2026-09-20) — your 14:04 note read; agreed on all five points; what the tagged tip will contain

Our notes crossed: yours of 14:04 predates my 14:16 entry below (the
path-length finding and the tag's shape). Nothing in it conflicts.

- **Publication guard (D21) on the toy example — thank you.** Verifying the
  exact encoded bytes before the output directory exists is the right order.
- **Public run-statement metadata — agreed, and it goes into the tagged
  delivery**: the twelve-block test will retain the public `ExpectedIo` and
  run statement beside (not inside) the exact-segments directory, so a fresh
  process can rebuild the statement. Public values only; I will read the
  writer myself against the capture rule before it lands. No repeat of the
  untagged heavy run.
- **C1–C8 yours; the shaped block, the run and the D19 tag mine.** I read
  "you retain the D19 tags" together with your 00:26 condition (a needed
  shared-file change as its own reviewable commit) as the go-ahead for the
  additive change described at 14:16. **It will sit in separate commits,
  new functions only, old bodies untouched, placed at the end of each file to
  stay clear of your direct-plane entry in `pcs.rs` and your pool/fold work
  in `zk.rs`.** If you want a different API shape, say so before the lane's
  current stage finishes (it is lane-only and running now).
- **D22 and your combined candidate — agreed, and you have it exactly right.**
  Condition 7 of the statement: a change to any pinned Rust file suspends the
  gate step until the file is re-read and re-pinned. When your candidate lands
  on main I will re-read the changed functions of `pcs.rs` and `zk.rs` on the
  toy's path, move the pins with both hashes kept (as was done for `mle.rs`),
  re-run the gate on the four captures, and only then say D22 covers the new
  tree. Until then D22 covers the tree it was argued on, not the candidate.
  Tell me the commit when it lands.
- **The command-line wrapper is yours**; I will not build a second one. Two
  rules for it from my side, both already decisions: (a) D21 as you wrote it —
  stage privately, verify the whole run, then publish, never an
  accepted-looking prefix; (b) **a refusal reason is never printed to anyone
  not entitled to the input** — three of the lane's refusal strings
  (`private_block/witness.rs:80, 271, 287`) depend on the input, so a wrapper
  that serves others returns a fixed string and keeps the reason in a private
  log.
- **What the stable tagged tip will contain, in order:** stage 16 (running:
  completed length guard, explicit path-length check), stage 17 (the tag:
  the shared additive commits, then the lane plumbing and the seven tests of
  the scoping memo §6.4), stage 18 (public run-statement metadata retained;
  captures re-taken under the tag), and on the Python branch the run gate
  taught the keyed rule. I will name the tip here when all of it is green.

### 14:16 (2026-09-20) — TWO THINGS FOR YOU: (1) a finding in your verifier — `pcs::verify_zk` never checks the length of a Merkle path; (2) the D19 hash tag needs a small additive change in five of your files — proposal, not yet code

**(1) The finding. Please check your own wire formats.**
`zkp-core/src/pcs.rs:1019` passes the opening's path to
`MerkleTree::verify_path` (`merkle.rs:56-63`), which folds however many
siblings it is handed; nothing compares `path.len()` with `log_cols` (the
non-hiding verifier at `:489` lacks the check too; there a leaf is the bare
column digest, so the confusion below needs a 64-byte column, that is, an
8-row commitment). Because a salted leaf and an inner
node are the same function on the same 64 bytes, **an inner node one level
above the leaves verifies as the salted leaf of any column whose digest is its
left child, with its right child as the "salt", under a path one entry
shorter** — at the two indices congruent to its position. I ran it
(`results/zk60_d19_hash_tag/short_path_demo.py`, a mirror of `verify_path`
with SHA-256 standing in, the point being structural) [MEASURED 14:15]: index
1 opens two ways, index 5 opens to the planted column, the planted left child
becomes unopenable, and a length check refuses both short openings.
- **The private block is not reachable this way**: `private_block/wire.rs:178`
  reads the number of path entries from the layout, never from the receipt. I
  read it myself.
- **I have not looked at your other wire formats** (the FFN private-IO
  receipts, the compact GPU openings, the public block receipt). Any one that
  carries a length-prefixed path inherits the gap.
- **Size of the problem** [ARGUED by me, unchecked]: my rough look at one
  attack family does not beat the accepted per-opening figure — each planted
  node kills a position, and I get at most about (2/3)^256 against the
  accounted (3/4)^256 — but nobody has analysed it and it is a binding gap in
  principle. **Suggested fix, yours to make: `path.len() == params.log_cols`
  (or the tree depth) inside both verifiers. It rejects no honest proof and
  moves no byte.** It also vanishes wherever leaves and nodes are keyed apart.

**(2) The D19 tag: `ZK60_D19_HASH_TAG_DISPOSITION.md` (my rulings T-1..T-6),
on `ZK60_D19_HASH_TAG_SCOPING.md` (the agent's inventory, with `file:line`).**
- **What:** BLAKE3 keyed mode, four public keys per profile (transcript,
  column digest, salted leaf, Merkle node), each
  `derive_key(<context>, <profile string>)`. No extra compressions: the key
  replaces the initial value. The legacy rule — no key — is today's literal
  call and stays the default; the toy is never tagged.
- **Where it touches you, all additive:** a new `zkp-core/src/hashtag.rs`;
  `transcript.rs` (one `key: Option<[u8;32]>` field, `new_tagged`, and the
  hasher constructed from the key in `absorb` and `squeeze_bytes` — the only
  edits to existing bodies, and with `None` it is the same call);
  `merkle.rs` (`hash_pair_keyed`, `build_keyed`, `verify_path_keyed`);
  `zkp-core/src/pcs.rs` (`salt_leaf_keyed`, `hash_columns_keyed`,
  `commit_zk_owned_with_tag`, `verify_zk_tagged`); `hashline/src/pcs.rs` (a
  five-line adapter); `hashline/src/zk.rs` (`mask_commit_tagged`,
  `mask_verify_tagged`). **Old functions keep their bodies untouched — no
  forwarding through the new ones.** `gpu/*` untouched: a tagged commitment
  declines the accelerator in one line of the new function; keying the CUDA
  kernel is a later, separate change. `private_seam.rs` untouched.
- **Who writes it:** your 00:26 conditions allow a needed shared-file change
  as its own reviewable commit. **If you would rather write it, or want a
  different shape of API, say so here.** Otherwise the lane writes it as
  separate commits after its next stage (lane-only: the completed length
  guard and a path-length check before every opening) and lists them at
  hand-back. I will not start the shared part before that stage is done.
- **What moves:** the proof bytes of the rung, the generalised rung, the 125M
  block and the run, once. Receipt sizes do not (the wire carries no tag).
  Toy: nothing.

### 14:06 (2026-09-20) — stage 15 landed on the 125M lane (`b26c869`, pushed): the run capture gained its plane index table; no proof byte moved

- **What:** a new test-only module `private_block/plane_index.rs` and one new
  `run.json` member, `plane_index` — which plane each slot's terminal
  evaluations refer to, in the prover's push order, and where each plane sits
  in commitments A and H. **I read the module: it takes the public layout
  and shape and nothing else** — no witness, no protocol state — so the
  capture rule (nothing computed from a hidden input) holds. The schema name
  is kept (`hashline-native-capture/4-run`): a pure addition, twelve keys
  added to the allow-list, the unknown-key test still fires.
- **Counts** [MEASURED by the lane, log read by me]: filter `private_`
  195 passed, 0 failed, 6 ignored (was 191); the toy's frozen receipt, its
  schedule digest and its parameter line unchanged; shared files touched:
  none; `private-block-kernel`, `private-model-kernel`, `zkvm-block`
  identical to `11c01b2`.
- **Two new bundles** under `results/zk60_run_captures_20260920/`
  (`run-c-tame`, `run-d-zero`, 77.0 MB); the two old ones are untouched and a
  parent README says they predate the table.
- **Your build lock:** the lane waited about 20 minutes behind your `run.py`
  and one cosmetic log came out empty because its wait expired; it never
  bypassed the lock. No action needed — only so you know the queue was real.
- **Next on my side:** the run gate is being extended on
  `zk60-native-jointview` to use the table (the per-slot terminal check at
  the development shape, the one channel it declared open for a missing
  field). The D19 hash tag is being scoped read-only first, because the
  hashing sits in your files; the proposal will come to you here before any
  code. **The lane tip is therefore still not final.**

### 13:50 (2026-09-20) — Victor accepted D19, D20 and D21; the toy private block's privacy is ACCEPTED (register D22) — for that one artifact only

- **Victor, at the console, 13:45: "Yes on D19 D20 and D21."** D19: the hash
  functions modelled as random oracles; the untagged shared BLAKE3 domain is a
  recorded deviation **for the toy profile**, and **every new profile gets a
  separating hash tag**. D20: timing, memory and power out of scope for the
  first MVP, refusals kept in scope. D21: a rejected receipt is never
  transmitted; a retained capture counts as publishing; a refusal reason is
  never shown to anyone not entitled to the input.
- **D22, mine, 13:46: privacy accepted for the toy private-block profile
  `hashline-zk-mr1/private-block-t32-poc/1` and for nothing else** —
  `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`: the statement, what each of the
  five steps rests on, every residual sized, **seven conditions under which it
  lapses for the changed code**, and what reopens it. Several of those
  conditions live in your files: one reserved pair per claim site with
  weights of the shape `(cm, cm·U)`; `audit_claims` never relaxed; pad count
  equal to opened columns; `d + 1` values per sumcheck round; the exact-row-span
  assertions in the commitment code; every leaf salted; fresh operating-system
  randomness with no seeded configuration on that profile's path. **If an
  integration of yours touches one of them, tell me before it lands: the
  statement lapses for the changed code until the affected step is redone.**
- **What D19 obliges in code, on my lane:** a separating hash tag in the
  development-rung, 125M and run profiles (all unfrozen, so no accepted byte
  moves; the toy stays exactly as it is). I will do it on
  `zk60-private-block-125m` once the agent now working there has finished, and
  the two run captures will be re-taken afterwards.
- Still open for Victor, not urgent: a run's whole-proof soundness level
  (about 2^-97.5) and its 484 MB receipt.

**Answers to your pickup of 13:32 / 13:48 (read at 13:50):**

- **U-1 — your review is accepted as written.** The instance shows a
  precondition of the helper (it trusts the row declaration it is handed), not
  an accepted leaking proof; I had not checked that both endpoint constructors
  randomise all five appended rows and that the determinant check sits on
  `data+2`, `data+3` regardless of the declaration. No shared-audit change is
  requested. Recorded in the run's disposition beside the U-1 ruling. The
  invariant on my side: `BoundarySpec` derives the geometry once; preparation,
  metadata and opening use that one spec; the single-row control stays,
  labelled as a deliberately weakened construction.
- **The `mle.rs` re-pin at `4bf1fa0` is already done** on
  `zk60-native-jointview`: `scripts/zk60_native_terminal_polys.py` keeps it as
  a *moved* pin with both hashes (`131cf1b4…` as ported, `b20c8b75…` at
  `4bf1fa0`), made after the changed function was re-read; the gate was re-run
  after it and nothing was recaptured. Your independent review of the
  Python/Rust polynomial mapping is welcome — it is the one thing on that
  branch equal to the Rust by a single reading.
- **The lane tip to integrate is NOT final yet.** `663555f` is coherent and
  reviewable today (filter `private_`: 191 passed, none failing; no shared
  file touched; the five frozen crates identical to `11c01b2`). Two stages
  follow: stage 15 (running now) adds a plane index table to the run capture
  — a capture-only change, no proof byte moves; then the D19 hash tag, which
  **changes the proof bytes of the rung, 125M and run profiles once** (the toy
  does not move). I will name the final tip and the re-taken captures here
  when both have landed. If you want to start reviewing before that, review at
  `663555f` and expect one more delta confined to the hash-input tagging and
  the capture writer.
- **C1–C8:** your hand-back text lists them under my lane. They are on the
  FFN private-IO path (`zk.rs`, `zk_ffn_fresh_io.rs`), which your conditions
  close to me, and the block does not use that path (handoff 04:45). They stay
  with you unless you say otherwise.
- **Your twelve-block reproduction:** the command and the environment are in
  the 11:25 entry; it needs the heavy lock, the 12 GB ceiling and
  `MALLOC_MMAP_THRESHOLD_=131072`, and about 6.5 minutes of an otherwise idle
  CPU. It writes 462 MB of segments to `HL_PB_RUN_DIR` — point it outside the
  repository.

### 13:01 (2026-09-20) — the run's privacy gate has run on two three-block captures and passes; not a privacy claim

- **`scripts/zk60_native_run_gate.py`** on `zk60-native-jointview` (pushed at
  `9997d6c`; a NEW tool, no existing module edited; tests 161 → **187, all
  passing**; the toy gates' outputs unchanged). On two independent honest
  three-block runs at the development rung [MEASURED by the lane]: the whole
  run's transcript is replayed in Python (375 positions, 6,086 challenges, 6
  segment tags per bundle, nothing left un-re-derived); every commitment of
  every stage discloses what it should (`A` 0, `H` the public lookup identity,
  endpoints 0, `M` its batched value); **each boundary, restricted to its
  reserved rows, has rank 6 of 6 and discloses 0; the same hidden plane under
  three commitments gives joint 0 = sum; the whole run (308 × 3,761) gives
  joint 6 = sum 6.** Six controls fire, each after the honest case passes —
  among them the two the design's checker predicted on paper, now on real
  receipts: two claims sharing a pair disclose 2; a single proximity row
  discloses 1; and a blinding row shared between a boundary and its neighbour
  leaves every marginal at 0 and moves the joint to 1,024.
- **Not a privacy claim**: linear channels, two runs, one development shape;
  15 of 23 channels open (the sequencing surface and the cross-block joint law
  among the new ones); the hash layer argued; nothing about 125M.
- **One note for the record, mine to fix:** the committed `privacy_gate.json`
  on that branch was not refreshed when the masking commitment's three
  channels were closed at `d360466`; the numbers are right, the record is
  stale. And the run capture lacks one PUBLIC field — the plane index table —
  without which the per-slot terminal check stays open at the rung; I am
  having the lane add it.

### 12:22 (2026-09-20) — a run capture exists (a NEW module; your `native_capture.rs` untouched); the run's privacy gate is being built in Python

- **`hashline/src/private_block/run_capture.rs`** on `zk60-private-block-125m`
  (pushed at `663555f`; filter `private_` **191 passed / 0 failed / 6 ignored**;
  no shared file touched; toy byte-identical). Schema
  `hashline-native-capture/4-run`, a strict superset of your schema 3: a run
  header with every shape number and every transcript label **as data**, per
  stage exactly your single-block content, per internal boundary its derived
  geometry, both claim sites with the stage and slot that raised each, and its
  single opening. **It is taken verifier-side only**, through `cfg(test)` hooks
  that return on their first line unless a recorder is attached (the same
  pattern as yours); nothing is recorded prover-side, and nothing was missing
  for want of a forbidden file. The recorder keeps its own transcript, seeded
  from the run statement and never adopted from the verifier, and re-derives
  every challenge of the run; a run the verifier rejects produces no bundle;
  a test scans every key of every bundle file against an allow-list. Format
  note: `ZK60_RUN_CAPTURE_FORMAT.md` on the lane.
- **Two things in that note you may want for your own loader some day:** the
  Python chain never reads `params` / `q_pad` from a bundle — it hard-codes the
  toy's sizes as module constants — so every shape number is now carried as
  data; and the role names `A / H / Input / Output` name the CLAIM SITE, while
  new fields name the COMMITMENT, because one boundary commitment is the
  `Output` of stage k and the `Input` of stage k+1.
- Two bundles of independent honest three-block runs at the development rung
  are committed (77 MB in all, under `results/zk60_run_captures_20260920/` on
  the lane). **The gate itself (ruling M-8) is being built now on
  `zk60-native-jointview` as a new tool**: whole-run transcript replay; the
  disclosed dimension of every commitment of every stage; each boundary ranked
  restricted to its reserved rows; the same hidden plane under three
  commitments ranked jointly; controls for a shared pair, a single proximity
  row, a shared blinding row, a wrong claim source and a swapped stage file.
  No privacy claim about any run until it has run, and none about the 125M
  shape after it either — exact rank over thousands of rows is a different
  computation.

### 11:25 (2026-09-20) — MEASURED: a private run of ALL TWELVE blocks at the 125M shape proves and verifies under one transcript; the heavy lock is free

- **[MEASURED by me, one run, shared box, CPU only, exit 0, finished
  11:22:07; inside `systemd-run … MemoryMax=12G` with
  `MALLOC_MMAP_THRESHOLD_=131072`; log with every segment's length and SHA-256
  committed on the lane branch, `results/zk60_block125m_lane/m125-run-l12.log`;
  the 462 MB of segments are outside the repository at
  `/home/victor/zk60-artifacts/m125-run-l12`]:** twelve blocks, 512 tokens,
  width 768, hidden 2048, 12 query heads over 4 key-value heads, synthetic
  weights, every internal boundary hidden — **prove 370.61 s (30.5–31.6 s per
  block, flat), verify by streaming from disk 13.71 s, receipt 484,100,736
  bytes in twelve files, equal to the counted figure to the byte, peak
  resident memory 10.15 GiB with no rise after the first block.** The design's
  counted figures were 6.26 minutes and 12.5 s.
- **How:** stage 13 added a directory segment sink (write to a temporary name,
  sync, rename; the prover holds nothing of a finished segment) and a
  streaming verifier with one segment resident, checking exactly L files, L
  being its own; at the development rung a twelve-block run on disk verifies
  by streaming and a missing, truncated, swapped, duplicated, extra or foreign
  segment file is rejected by name. Filter `private_` **185 passed / 0 failed
  / 5 ignored**; **no shared or forbidden file touched in the whole lane; toy
  byte-identical.**
- **What it is not:** synthetic weights; the blocks only (D13); no GPU; one
  run on a shared box; and **no privacy claim for any run** — the gate for a
  run (three blocks at the development rung, all three roles of each boundary
  ranked jointly, through a NEW run-capture module) is ruled and not built.
- **The lane `zk60-private-block-125m` is now the whole private line above the
  toy**: the shaped block, the generalised endpoint, the run, the sinks, 185
  tests, its ledger, an independent code review and the evidence of five
  measured 125M runs. It is ready for your integration whenever you take it
  up; I will keep it rebased on nothing and merged with the shared tip only
  when you ask, so that your review sees one coherent branch.
- I am telling Victor now (one short message), and updating `MVP_STATUS.md`.

### 10:48 (2026-09-20) — MEASURED: a two-block private RUN at the 125M shape proves and verifies under one transcript; the heavy lock is free

- **The run is built** (stage 12 on `zk60-private-block-125m`, pushed; filter
  `private_` 157 → **181 passed / 0 failed / 4 ignored**; new files
  `private_block/boundary.rs`, `run.rs`, `run_tests.rs`, a segment codec in
  `wire.rs`; **no shared or forbidden file touched, toy byte-identical; your
  `pcs.rs`, `zk.rs`, `private_seam.rs` and `native_capture.rs` exactly as they
  were**). Runs of 2, 3 and 12 blocks verify from their segments at the
  development rung. The headline negative test passes both ways with the
  prover succeeding and the verifier refusing: block 2 run on something other
  than block 1's output is rejected at the input-equality slot; the mirror
  case at the output-equality slot. Dropped, swapped, duplicated, truncated and
  foreign segments, a wrong block count, a foreign calibration, and all 27
  single-block tamper families applied to block 2 are rejected.
- **At the 125M shape** [MEASURED by me, shared box, CPU only, inside a 12 GB
  ceiling; logs on the lane branch]: **two blocks under one transcript: prove
  62.86 s (31.19 + 31.67 s per block), verify from segments 2.04 s, receipt
  81,084,496 bytes, equal to the counted figure to the byte; peak 10.82 GiB**
  (finished 10:45:45).
- **An operating fact worth having for any large job on this box:** the
  high-water mark rose between blocks (10.67 → 10.82 GiB). That is glibc's
  dynamic mmap threshold: a large freed buffer raises it, later large buffers
  come from the heap, and the heap fragments. **With
  `MALLOC_MMAP_THRESHOLD_=131072` in the environment the same run is flat
  (10.04 → 10.05 GiB), its peak 0.77 GiB lower, at no measurable cost in
  time** (finished 10:47:36). I am making it the rule for multi-block runs;
  it may help your 8B-width host paths too.
- **Precise form of the audit question from 09:50:** the lane found that the
  checker's 37-row instance is refused for bookkeeping reasons, but that
  `audit_claims` does accept a one-site budget whose proximity position is
  declared one row too high — a geometry with a single effective proximity
  row, which discloses 1 in the checker's exact model. The boundary module
  derives its geometry and cannot be asked for it; the accepted profiles
  declare theirs correctly. Whether the shared audit should refuse it is
  yours.
- **Next:** a disk-writing segment sink and a streaming verifier, then ONE
  twelve-block run at the 125M shape (about 6.5 minutes of proving, about 10.1
  GiB with the threshold pinned, 484 MB written outside the repository; only
  hashes and lengths committed). I launch it myself under the heavy lock when
  it is prepared. No privacy claim is made about any run: the gates for a run
  do not exist yet.

### 09:50 (2026-09-20) — the multi-block private run is designed, checked and ruled (D12a in the register); building has started on the lane; one correction to my 08:48 figure

- **What it is.** A private run of L blocks under ONE transcript — what a
  full-model private proof at the 125M shape needs, since separately finished
  block proofs cannot be chained. Design `ZK60_PRIVATE_RUN_MULTI_BLOCK.md`,
  independent check against the real code `…_CHECK.md`, my ruling
  `…_DISPOSITION.md` (M-1 … M-8), and **amendment D12a recorded in the
  register.** One boundary commitment per internal boundary, claimed by block
  k's output-equality slot and block k+1's input-equality slot, one reserved
  pair per claim site, opened once; block k is dropped before block k+1 is
  committed, so the modelled peak for twelve blocks is the single block's
  measured peak plus the carry-over and the statements: 10.74 GiB [MODEL from
  MEASURED]; twelve segments under 40 MiB each, about 484 MB, verified one at a
  time.
- **What the check established about YOUR code, all of it good news:**
  `pcs::open_zk` borrows the commitment and the claim list and `verify_zk`
  re-forms the groups itself, so **one opening can take claims accumulated
  across two stages with no change to `pcs.rs`, `zk.rs` or `private_seam.rs`**;
  the block's per-role arrays have exactly four places and this design uses
  exactly four. Its reachability table (the check's A9.3) lists every function
  the run needs. A run capture will be a NEW module, not an edit to
  `native_capture.rs`.
- **One finding you should know even if you never touch this:** a boundary
  with a *single* proximity row (37 rows where 38 are needed) discloses 1 in
  the checker's exact model, **and `audit_claims` accepts that geometry** — the
  proximity *pair* is a hiding requirement the audit does not enforce. Today's
  single-claim endpoints are fine (their five non-data rows are a pair, a
  proximity pair and a spare). I have ruled that the boundary module derives
  its row count and refuses any other; whether `audit_claims` itself should
  refuse a geometry without a proximity pair is a question for you, since it
  is shared with the accepted profiles.
- **Correction to 08:48:** twelve blocks are about **6.3 minutes** of proving
  on this CPU, not 5.3 — I left out 4.7 s per block of witness building. The
  completion plan is corrected.
- **Building now on `zk60-private-block-125m`** (additive, new profiles, no
  shared file expected): the claim audit on a hand-built two-claim schedule
  first; the 37-row refusal; then two blocks at the development rung with the
  headline negative test (block 2 rebuilt on a different hidden input than
  block 1's output, rejected by the VERIFIER); then three and twelve at the
  rung; a two-block 125M run prepared but not launched.
- For Victor, added to his page as not urgent: a twelve-block run's soundness
  is about 2^-97.5 by the project's accounting (the level of D3), and its
  receipt about 484 MB against a 256 KB budget.

### 08:48 (2026-09-20) — MEASURED: where the 125M private block's 26.5 s goes; the heavy lock is free again

- **Second 125M run, phase timing on** [MEASURED, one run, shared box, CPU
  only, exit 0; `results/zk60_block125m_lane/m125-run2-timing.log` on the lane
  branch, pushed]. The recorder (`private_block/timing.rs`, off unless
  `HL_PB_TIMING=1`) reads no proof state and changes no byte: a proof made
  with it on verifies with it off, receipts equal, toy byte-identical, filter
  157 passed / 0 failed / 3 ignored; its phases sum to the wall-clock within
  0.003 s. **Prove 26.54 s: the softmax zero-check 6.71 s (25.3%); the lookup
  helpers' inversions 3.92 s (14.8%); committing `H` 3.63 s (13.7%);
  committing `A` 3.00 s (11.3%); the mixed residual-and-norm zero-check 2.95 s
  (11.1%); the feed-forward zero-check 1.34 s (5.0%); all five openings 0.65
  s.** By half: attention slots 34.4%, feed-forward slots 5.3%, the rest 60.3%
  (commitments and lookup helpers, which serve both). Verify 1.03 s, 57% of it
  attention.
- **P5 is answered** (`ZK60_MVP_COMPLETION_PLAN.md` §5.2b): everything a GPU
  feed-forward prover could take over at this shape is about 14% of the proof
  (up to about 18% with a share of the mixed slot) before the two-prover
  design's own costs. **Form E is not built for this shape.**
- **What would make a private block faster, for whenever you or I take it
  up — none of it changes the protocol or a byte:** (1) the softmax
  zero-check, one host sumcheck over an 8.4-million-entry cube; (2) the two
  commitments — 6.6 s of exactly the encode-and-hash work your device kernels
  already do for the feed-forward line; this module has no device path at all,
  and the commit call is inside `pcs::commit_zk_owned`, which is yours, so I
  could only time it as one phase; (3) the 98.6 million helper inversions.
  I am not starting any of these without hearing from you, since (2) lives in
  your files.
- Twelve blocks at this rate are about 5.3 minutes of proving on this CPU
  [COUNTED]. That is the honest figure to set beside the speed target, which
  is defined over a different workload.

### 08:17 (2026-09-20) — the lane no longer breaks the Python suite: the inventory tool reads the shaped layout (`zk60-private-block-125m` at `ebb7cf5`, pushed)

- **What would have gone red on integration, now fixed on the branch.**
  `scripts/zk60_private_block_inventory.py` parses the block module's Rust;
  nine of its tests errored on the reshaped `layout.rs` (all in
  `parse_dom_logs`: `Dom::log` is now a call, not a `match`; four more
  breakages sat behind it). Repaired with four adapters in the tool's own
  style — each requires a pinned source body and **refuses otherwise**;
  nothing is duplicated from the layout model: the six axis logs are inverted
  out of the nine domain logs and cross-checked against the frozen toy
  constants. No test was weakened or skipped, and what the tool checks is
  unchanged.
- **Acceptance** [MEASURED by the lane]: the toy's record regenerated and
  diffed key by key against the one accepted at `f1df3ba` — **the schedule,
  the pair schedule, the masked-sumcheck slots and the hosts are
  byte-identical**; the 41 differences are source hashes, adapter prose, an
  output path, four added keys and one added gate (62 items cross-checked
  against the layout model, all agreeing). Inventory tests 9 erroring → **40
  passing**; the module's two Python files 65 passing; the whole suite on the
  branch 1,153 tests with two failures the lane says are missing fixtures in
  its worktree (`test_zk60_endpoint_view.py`, `test_zkmatrix_native_backends.py`).
  I ran the first in the main tree: 8 of 8 pass there, so it is the worktree,
  not the lane. The second is running in the main tree as I write.
- A `--shape` argument for the tool (the first privacy-structure check above
  the toy) was deliberately skipped: it needs the pad rule and the
  proved-zero plane list modelled in Python first. Recorded in the lane
  ledger's stage 10.
- **The lane is now complete as far as I can take it without you**: one block
  at the 125M shape proves and verifies; the review found no hole and its
  findings are fixed; the Python suite is not broken by it; no shared file is
  touched. Still asked of you: integrate it; a capture writer over a shape;
  the frozen seam's per-opening soundness at the toy geometry. Victor has the
  morning update and the three privacy rulings to answer (sent 07:32).

### 07:10 (2026-09-20) — RESULT: one complete private block at the 125M shape PROVES AND VERIFIES; the heavy lock is free again

- **[MEASURED, one run, shared box, CPU only, 07:03–07:04; exit code 0;
  evidence committed on the lane branch at the tip of
  `zk60-private-block-125m`: `results/zk60_block125m_lane/m125-run1.log`,
  `.done`, `m125-build.log`]:** 512 tokens, width 768, hidden 2048, 12 query
  heads over 4 key-value heads, synthetic weights, generalised endpoints —
  **prove 26.89 s, verify from bytes 1.04 s, receipt 40,782,792 bytes (equal
  to the counted figure), peak resident memory 10.42 GiB, witness build
  5.46 s.** The paper model had said 25–36 s and about 11 GiB; for once a
  modelled figure held. The 12 GB ceiling was not hit. **The heavy lock is
  released.**
- **What it is not.** Not a privacy claim (the gates are owed at this shape
  and need the shape-parameterised capture writer I asked you for at 05:48);
  not a real checkpoint (the first-residual stream's range on the real 125M
  model is still unmeasured, ruling P-5); one block of twelve; no GPU path
  exists for this module; a single run on a shared box, so the seconds are
  diagnostic.
- **What I would like from you, in your own order:** (1) integrate the lane —
  it changes no shared file, the toy is byte-identical (four receipts made
  before the lane verify under it), and the three frozen crates, `zk.rs`,
  `private_seam.rs`, `native_capture.rs` and `zkp-core/` are untouched; the
  ledger `ZK60_BLOCK125M_LANE_PROGRESS.md` and the independent review
  `ZK60_BLOCK125M_RUNG_CODE_REVIEW.md` are on the branch; (2) the capture
  writer over a shape; (3) your answer on the frozen seam's per-opening
  soundness at the toy's endpoint geometry (06:22).
- I have added one paragraph to `MVP_STATUS.md` (it was clean in the tree)
  with these figures and their limits.

### 07:03 (2026-09-20) — stage 9 green (`2f61f36`, pushed); ONE 125M-shape proof is RUNNING on the box, under the heavy lock, memory-capped

- **A heavy job of mine holds (or is queued on) `/tmp/zk-heavy.lock` as of
  07:03**: one complete private block at the 125M shape (512 tokens, width
  768, hidden 2048, 12 heads over 4), synthetic weights, CPU only, **no GPU**.
  Launched detached by the no-hangup protocol, inside `systemd-run --user
  --scope -p MemoryMax=12G -p MemorySwapMax=0`, so that an overrun kills the
  process and not the box (modelled peak about 11 GiB, 9.6 after the buffer
  frees; 14.4 GB was available at launch). Log and marker:
  `/home/victor/wt-zk60-block125m/results/zk60_block125m_lane/m125-run1.log`
  and `.done` (the exit code). It is one run, not a ladder; modelled at tens
  of seconds to a few minutes. If you need the box before it finishes, it is
  safe to kill — nothing else depends on it.
- **Stage 9 [MEASURED by the lane]:** all nine review findings fixed and the
  merge green — filter `private_` 149 → **156 passed / 0 failed / 3 ignored**;
  none of the reviewer's 15 tests needed adjusting. The debug-only guard is
  now a real refusal in a release build on both sides ("an indicator that
  does not tile its slot's cube"); a sweep of the lane's other debug
  assertions turned one more into a real check and found three harmless. The
  tamper helper is split into "the verifier rejects" and "the honest prover
  is expected to refuse": **no test changed category — all 70 tamper cases
  were verifier rejections all along.** A moved lookup multiplicity on the
  table domain's pad is caught by the pad-zero term alone (slot 19), with
  every product relation and the lookup identity intact. On the review's
  F-7, **the code was right and the layout memo's row for the lookup domain
  was wrong**; a note is opened against the memo. The endpoint's commitment
  parameters are absorbed into the transcript in the new profiles (receipt
  lengths unchanged; the two development profiles' earlier receipts are
  deliberately invalidated). The 125M layout constructs with closed-form
  indicators equal to their definition at every position of all six padded
  domains. **Shared-file list: none. Toy byte-identical. Frozen crates and
  forbidden files untouched.**
- One pre-existing item it noticed and did not touch: nine tests of the older
  Python inventory script error on the shaped `layout.rs` (they parse the
  Rust); the 25 tests of the layout model pass. Mine to fix.

### 06:27 (2026-09-20) — the independent code review of the 125M lane is in: NO HOLE; four pre-lane toy receipts verify under the lane's verifier

- **`ZK60_BLOCK125M_RUNG_CODE_REVIEW.md`** (branch
  `zk60-private-block-125m-review`, pushed, and merged into the lane). The
  reviewer was told to assume the code wrong and to write its attacks as
  tests, each decided end to end — edit the witness, run the honest prover,
  encode, verify from bytes in a fresh call — with a prover refusal counted
  as a test *failure*. **It could not make the verifier accept a false
  statement** [MEASURED by the review]: all 80 committed `A` planes perturbed
  on their support — 80 rejected; 79 of 82 proved-zero planes perturbed at 151
  padded positions across all nine padded domains — none accepted (the other
  three are prover-derived histograms); a query head reading the wrong
  key-value head — rejected; all six remainders above their integer window —
  rejected; shape and profile confusion in three forms — rejected; 58
  malformed frames — all a clean error, no panic reachable from a frame.
  `audit_claims` is unchanged but for its row-width parameter, and all six of
  its refusals fire at both row widths.
- **The toy, checked the strong way.** Length and schedule pins do not prove
  the transcript's bytes are unchanged, so the review took four receipts made
  *before* the lane — `results/zk60_rowfold_20260919/integration/native-block-0`
  and `-1`, `zk60_private_block_evidence/owner_run1`,
  `zk60_attention_integration_20260919/block_public` — and ran them through the
  lane's verifier: **all four verify, and a one-bit change to each is
  refused.** That test stays in the lane.
- **Nine weaknesses, all being fixed now (stage 9), the first one serious in
  kind:** the guard that a support indicator tiles its slot's cube is a
  `debug_assert_eq!` (`private_block/argument.rs:533`), and the release profile
  — the only one the rung and 125M build in — has no debug assertions; a
  non-tiling indicator would give prover and verifier the same wrong factor
  and verify. It becomes a real refusal on both sides, and every other
  `debug_assert` in the lane is ruled on one by one. Others: one slot batches
  its table planes by a hard-coded list and never checks the declared one;
  the rung's only fixture gave every head identical data, so head-permuting
  tampers were no-ops and two acceptance tests were missing; a test helper
  counted a *prover* refusal as a rejection (being split, and I will report
  how many tamper tests change category); a mis-sized public table reaches an
  assertion on the verifier side.
- Also in stage 9: the endpoint's commitment parameters go into the
  transcript's parameter line in every new profile (the toy untouched; the two
  development profiles' receipts change, which is allowed); the transform
  tables are raised for 125M; and **the 125M proof is prepared but NOT run** —
  a prebuilt binary and an exact detached command under the heavy lock with a
  memory ceiling. I launch it myself, once, when stage 9 is green and the box
  has the memory free; if your integration has heavy jobs queued on
  `/tmp/zk-heavy.lock`, it will wait its turn behind them.

### 06:22 (2026-09-20) — 125M lane stage 8 pushed at `010f6dd`: a generalised endpoint, the rung re-proved with it, the 125M layout constructed (not proved); one soundness question for you

- **Stage 8 [MEASURED by the lane; final log read: filter `private_` 134 passed
  / 0 failed / 2 ignored].** A generalised endpoint lives in a new module
  beside the frozen `private_seam.rs`, which is untouched: the same
  construction (five mask rows with the same roles, pad count equal to opened
  columns, one three-part claim with the `(cm, cm·U)` pair, one opening, the
  owner taken by value), with its parameters from the shape, its own 42-byte
  domain label and its own digest. **No private item of `private_seam.rs` was
  needed.** A new profile `hashline-zk-mr1/private-block-rung-g-t24-dev/1` uses
  it with four data rows per endpoint, as the 125M shape will: receipt
  4,234,648 bytes; an honest proof verifies from bytes; both padding attacks,
  the 27 tamper families, the norm alias and **eight new endpoint tampers**
  (input and output, a word on the support and a word in the pad) are rejected
  by the verifier. Prove 0.41 s, verify 0.10 s, 95 MiB peak (diagnostic). The
  earlier rung profile on the frozen seam stays green beside it. Toy
  byte-identical; **shared-file list: none**; frozen crates and forbidden files
  identical to their state before the lane.
- **The 125M layout constructs without being proved** [COUNTED by the Rust,
  equal to the wire format's own length]: `A` 5,681 rows, `H` 7,120, each
  endpoint 37 rows with 32 data rows, **receipt 40,782,792 bytes**. The only
  thing that refuses at 125M is the lane's own NTT-table check (2^16 needed,
  2^12 built); raising it is inside the lane and is arranged so that the
  frozen seam keeps its own tables. Modelled peak memory about 11 GiB.
  **Nothing is run at 125M until the independent code review reports; then it
  is one detached run under the heavy lock with a memory ceiling.**
- **A soundness question I cannot answer and you own** (decision D15's
  territory). The lane chose inverse rate 4 for the generalised endpoint and
  records, by the project's own per-opening formula, 2^-96.15 at the rung-G
  geometry and the memo's 2^-105.61 at 125M — **and 2^-67.3 for the frozen
  seam at the rung's 4,096-word ceiling.** That last figure concerns only a
  development profile, but it raises the question I would like answered for
  the record: **what is the per-opening soundness of the frozen seam at the
  TOY's own endpoint geometry (7 rows)?** If it is also well under the 106
  bits quoted for the default profile, the toy block's whole-proof figure is
  set by its endpoints and the status pages should say so.
- One finding I will rule on when the review is in: the endpoint's
  commitment parameters are not in the transcript's parameter line (the lane
  says they are bound otherwise, through the endpoint digest). For new
  profiles I am inclined to put them there explicitly.

### 05:48 (2026-09-20) — MILESTONE: an honest private-block proof verifies from bytes at the padded rung (`zk60-private-block-125m` at `3f762d0`, pushed); ONE REQUEST for you

- **What now exists** [MEASURED by the lane; I read the final test log:
  filter `private_` 116 passed / 0 failed / 2 ignored, the rung end-to-end
  tests among them]. The complete private block — hidden input, output and
  activations — proves and verifies from bytes at **24 tokens, width 96,
  hidden 192, six query heads of 16 over two key-value heads, 2^10 columns**:
  a shape in which every domain pads, grouped-query attention is real, the
  norm needs its third limb and the lookup domains straddle the row width.
  Receipt 4,218,264 bytes; prove 0.49 s, verify 0.10 s, 74 MiB peak
  (diagnostic, shared box). The all-zero hidden input proves and verifies
  there too. **Rejected by the verifier:** 27 tamper families, a lone nonzero
  pad value, the consistent-adjustment attack on the norm's divisor (the hole
  the layout check found before anyone built it), and the norm-range alias.
  **The toy is byte-identical throughout** (receipt 2,816,472, literal
  schedule digest); **no shared file changed; `private-block-kernel`,
  `private-model-kernel`, `zkvm-block`, `zk.rs`, `private_seam.rs` and
  `native_capture.rs` are identical to their state before the lane.**
- **How it got there, in case you review it:** the pad-zero term is
  `mu_pad·(1 − supp)·Σ zeta^j·plane_j` inside each host slot, one `zeta` per
  slot refused on zero, no new claim site or mask pair; support factors on the
  inhomogeneous clauses of eight slots, never on the lookup arm. Three bugs
  surfaced only when an honest proof failed, each reproduced first: a
  shaped-versus-toy plane-id map in the lookup tables; **a reserved pair
  addressed at the toy's row width — caught by `audit_claims`, which was not
  relaxed**; an exempt plane whose pad must hold real table rows.
- **THE REQUEST: a shape-parameterised capture writer.** `native_capture.rs`
  hard-codes `log_cols: 8`, `Layout::new()` and the no-shape `pcs_params()`,
  so no capture of a rung receipt can be made, and the privacy gates are owed
  again at every new shape — **I make no privacy claim at the rung until they
  have run on rung captures.** The lane exposes what you need:
  `Layout::for_shape(&Shape)`, `prove_inner_at` / `verify_inner_at`, the shaped
  `pcs_params`, and the free functions it kept for you (`mask_specs`,
  `slot_terms`). Whenever it suits your integration order; nothing here is
  blocked on it today.
- **Running now:** an independent adversarial code review of the whole lane
  in its own worktree (`/home/victor/wt-zk60-block125m-review`; it writes
  attacks as tests — a slot-by-slot perturbation sweep, a nonzero pad on
  every padded domain, a query head reading the wrong key-value head, shape
  confusion, and whether a toy receipt made *before* the lane verifies under
  the lane's verifier), and stage 8: a generalised endpoint built beside the
  frozen `private_seam.rs`, the rung re-run with it, and the 125M layout
  constructed without being proved. **Nothing is run at 125M until both
  report.**

### 05:13 (2026-09-20) — the privacy gate is complete as far as a linear gate can go (`zk60-native-jointview` at `d360466`, pushed)

- The mask-commitment layout is ported to Python with six source pins
  (`hashline/src/zk.rs`, both `argument.rs`, `zkp-core/src/sumcheck.rs`,
  `ntt.rs`, `pcs.rs` — **the gate will refuse when any of them changes; the
  re-read and re-pin are mine**). `M` discloses exactly 2 Fp, the batched
  value, by exact rank; two preimages at coefficient vectors differing in all
  583 positions reproduce `M`'s 12,800 opened-column entries with none
  differing; the declared order of the mask functionals is checked against
  your captures, 34 of 34; joint 4 = sum 4 with `M` included [MEASURED by the
  lane]. Tests 139 → 161, all passing. Channels 11 constructed / 2 derived /
  8 argued / 7 open, and **none of the seven is open for want of a capture
  field — nothing is requested from your capture writer for the toy.**
- What now stands between the toy profile and a written privacy acceptance is
  Victor's rulings D19–D21 and my assembling the five dispositions' conditions
  into one statement. Not a privacy acceptance today.

### 04:45 (2026-09-20) — 125M lane stage 6 pushed at `f3e3ef6`: prover and verifier over a shape; a correction to what I told you about C1 … C8; one request coming

- **Stage 6 [MEASURED by the lane]:** `protocol.rs` and `wire.rs` now run over
  a shape (`prove_inner_at` / `verify_inner_at`; the old pair is each at the
  toy shape); `wire::encoded_len` equals the layout's receipt figure at all
  three shapes — the toy's 2,816,472 and the rung's 4,173,208 agreed on the
  first try. Filter `private_`: 100 → **107 passed / 0 failed / 4 ignored**;
  toy receipt and digest unmoved after every commit; **shared-file list
  empty; the three frozen crates identical to `11c01b2`.** Four hash-layer
  conditions are pinned as byte-free tests (no leaf without a salt; no
  commitment with 5 or 8 rows, refused inside the shaped layout; no 28- or
  35-byte transcript label on the block path; pad count against opened
  columns). Still no rung receipt: the pad-zero term and the endpoints come
  first; stage 7 is on them.
- **A correction to my 23:31 and 00:41 entries.** I folded your
  hidden-endpoint change list C1 … C8 into this lane. The lane read it
  against the code: **C1 … C8 are the feed-forward private-IO path's
  (`zk.rs`, `zk_ffn_fresh_io.rs`, `zk_ffn_fresh_wire.rs`), not the block's.**
  They are forbidden files here and are *not owed by this lane*. The block's
  endpoints are separate commitments bound to `A`'s planes by equality slots
  over the whole padded plane. So C1 … C8 stay where they were before I
  folded them: unowned until the private feed-forward pass at model width is
  scheduled. My mistake, corrected here.
- **How the block's endpoints go, as I have ruled it (two steps).** First, a
  rung receipt with the existing endpoint machinery: the frozen `private_seam`
  accepts the rung's padded endpoint `(32, 128)` at exactly its 4,096-word
  ceiling, so three edits inside the lane and **no change to
  `private_seam.rs`** give a first end-to-end rung run (receipt about
  4,218,264 bytes). Second, before anything runs at 125M, a generalised
  endpoint built additively beside `private_seam.rs` — the frozen seam cannot
  serve 125M at all (`log_len 19` against `MAX_LOG_LEN 12`) — and the rung
  re-run with it. `MAX_WIRE_BYTES` (4 MiB, `private_block/wire.rs:20`, absorbed
  nowhere) stays the toy's bound; new profiles get a shape-driven one (the
  125M receipt is about 40.7 MB).
- **One request is coming, not yet:** a rung *capture* needs
  `native_capture.rs`, which hard-codes `log_cols: 8`, `Layout::new()` and the
  no-shape `pcs_params()`. When the rung proves I will ask you for a
  shape-parameterised capture writer, since the privacy gates are owed again
  at every new shape.
- Recorded, no change: opened columns are drawn with replacement (1,280 draws
  at 1,225 distinct indices in one toy receipt). The soundness count uses the
  draws; the privacy count uses the distinct indices against the pad count,
  which the code already checks.

### 04:20 (2026-09-20) — `audit_claims` is the whole defence against a shared mask pair; 125M lane stage 5 pushed; the privacy argument's paper steps all have a checked core

- **One thing in your code is now known to be load-bearing in a way nobody
  had measured: the pair-exclusivity check in `audit_claims`.** The gate's
  small model was extended overnight with real opening groups
  (`zk60-native-jointview` at `1857c04`, pushed; tests 112 → 139, the two
  gates' outputs on your four captures unchanged apart from timing fields).
  With two ordinary terminals sharing one reserved pair, **the dense rank
  shows 2 disclosed and the tool's reduction shows 0** — both marginals keep
  full support, the joint support halves, and two data vectors give disjoint
  supports. The reduction is blind to it by construction (it drops the claim
  values); the joint stage fails only through the pair-exclusivity check, as
  `audit_claims` does in Rust. Across two groups even a per-group system
  misses it. **So: never relax `audit_claims`, and any new claim path (the
  125M lane's endpoints, a future form E) ports it before its first external
  claim** — already a build precondition (D17, form-E ruling R-5), now with a
  measured reason. Also confirmed in that model: the reduction misses an
  opened position beyond the pad budget (dense 3, reduction 0); the
  real-capture path already refuses on it and the small-model path now does
  too. The one legitimate sharing — the helper commitment's two groups on the
  zero-sum pair — is ranked jointly at 2, the public lookup identity.
- **125M lane, stage 5 pushed at `d9c57f9`** [MEASURED by the lane]: the
  layout and the prover's relation definitions now run over a shape, the toy
  being one instance of the same code — `describe()` byte-identical on the
  first try, toy receipt and digest unmoved, filter 98 → 100 passed / 0
  failed / 4 ignored, **shared-file list unchanged, the three frozen crates
  identical to `11c01b2`**. `protocol.rs` and `wire.rs` are not yet
  shape-driven, so there is no rung receipt yet; stage 6 is on that, then the
  pad-zero term, your endpoint changes C1 … C8, and the rung end to end. I
  have ruled that no rung run is called a proof before the pad indicators are
  in (two public tables have inhomogeneous clauses).
- **The privacy argument for the toy block: every paper step now has a core
  that survived an independent attack** — the generic-rank lemma, the
  joint-law composition (its one unreviewed step since reviewed and
  corrected: `ZK60_TERMINAL_SURJECTION_REVIEW.md`), the hash layer with the
  Fiat–Shamir lift (`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`). Not a
  privacy acceptance: the gate has 10 open channels, one errata pass is
  running, and Victor's rulings D19–D21 are not yet given. Three notes for
  your code from it: **(a)** Merkle node inputs and salted-leaf inputs are
  both 64 untagged bytes — for hiding it is negligible, for *binding* it is
  the classic internal-node-as-leaf ambiguity; I believe fixed-depth,
  position-checked paths make it need a preimage, but nobody has checked
  soundness there, and it is one more reason for a separating tag in new
  profiles; **(b)** some refusal strings are data-dependent for inputs the
  statement does not admit (`private_block/witness.rs:80, 271, 287`) — a
  service must never return a refusal reason to anyone not entitled to the
  input; **(c)** four conditions are being pinned as byte-free assertions on
  the 125M lane (no leaf without a salt; no commitment with 5 or 8 rows; no
  28- or 35-byte transcript label; pad count at least the number of opened
  columns).

### 03:37 (2026-09-20) — 125M lane stage 4 (partial) pushed at `f2c89d4`; one finding about the ACCEPTED toy profile

- **Stage 4 got part of the way** [MEASURED by the lane]: the head permutation
  (key-value group in the high bits of the head slot; failing test first —
  "q8 differs in 90 of 2304"), the profile gate, public weights refused off
  their support under two distinct refusal names, and the first step of the
  shaped argument (`HIds`, built and tested, not yet wired in). Filter
  `private_`: 92 / 0 / 4 → **98 passed / 0 failed / 4 ignored**; toy receipt
  and schedule digest unmoved after every commit; **shared-file list
  unchanged; the three frozen crates still byte-identical to `11c01b2`.** The
  pad-zero term itself, the shaped prover and verifier, the column count, the
  endpoints and the rung end to end are NOT done; stage 5 is running on
  exactly that list.
- **A finding about the accepted toy profile, reported and deliberately not
  fixed.** Two byte-limb planes that the new pad rule classes as "must be zero
  off their support" — `A_LIMB` and `A_LIMBM` — already sit on a padded domain
  in the toy (`Dom::L`, 288 true positions of 512). Their pad is constrained
  only by the byte lookups: it is proved to hold **bytes, not zeros**. By the
  lane's reading nothing else reads those positions, and the honest builder
  writes zeros there (asserted). So this is slack, not a hole that I can see:
  a prover could put arbitrary bytes where no relation looks. **The toy stays
  byte-frozen.** I have ruled that new profiles cover those planes with the
  pad-zero term like any other, and that a test at the toy shape documents
  which relations read the two planes and that none reads a padded position,
  so that a future relation that did would fail it. If your own reading of
  the toy finds a relation that does read them there, tell me — that would
  change the ruling.
- Also ruled: closed forms replace the support-indicator tables wherever they
  exist (168 MB of tables at the 125M shape otherwise), each asserted equal to
  the builder's support table exhaustively at the rung; the definition of
  record stays the table.
- Paper, since 02:54: the composition memo is revised (`ZK60_JOINT_LAW_COMPOSITION.md`);
  an independent review of the one step its check supplied is running — its
  first job is a loose end, **whether the claim weight `cw` can be zero with
  nothing refusing**; and the last named gap, the hash layer with the
  Fiat–Shamir lift, is being drafted.

### 02:54 (2026-09-20) — 125M lane stage 3 green and pushed; the zkVM-side crates are byte-identical to `11c01b2` again; privacy rulings prepared for Victor

- **The kernel reversal is done.** `private-block-kernel/` is restored and the
  shape-generalised kernel lives in a new crate,
  `private-block-kernel-shaped/`. I removed the two leftover files myself
  (the lane cannot delete). **`git diff 11c01b2 -- private-block-kernel
  private-model-kernel zkvm-block` is empty** — nothing this lane does changes
  what the guest compiles. Frozen crate tests back to 10 / 0, model kernel
  19 / 0. Cross-parity at the toy shape: 1,200 cases, 23 trace planes element
  for element, 905 accept / 295 refuse identically [MEASURED by the lane].
  `cc94698` is superseded; integrate from the branch tip, never that commit
  alone.
- **S8 done** (both integer windows; plane ids from a segment table that is
  the identity at the toy, so no toy byte can move). **S9 prepared**: the two
  padding attacks are written as failing tests at the relation level, and the
  lane's plane table reproduces the memo's exactly (64 proved-zero / 35 exempt
  / 1 with no pad at 125M). Filter `private_`: 79 / 0 / 3 → **92 passed / 0
  failed / 4 ignored**; toy receipt 2,816,472 bytes and the schedule digest
  unmoved after every commit.
- **Shared-file list for your hand-back, complete so far:**
  `hashline/Cargo.toml`, `hashline/Cargo.lock` (registering the new crate), the
  new crate itself. Nothing in `zk.rs`, `layer.rs`, `pcs.rs`, `wcache.rs`,
  `gpu/*`, `native_capture.rs`, `zkp-core/`, `zkvm-block/` or the two frozen
  kernels.
- **Three rulings I made on its findings:** the pad rule is gated by profile
  (the toy already pads its lookup domain, and its transcript must carry no
  new machinery — the lane also checks, without changing anything, that no
  proved-zero plane sits on that domain in the accepted toy); the key-value
  group takes the high bits of the head index, so padded head slots interleave
  and the builder is permuted first; a support indicator is defined as the
  builder's public support table at every shape, a closed form being an
  optimisation that must equal it.
- **Stage 4 is running: finish S9, then make the argument and the protocol
  shape-driven (today only the layout is), then S10, then S11 — your
  hidden-endpoint changes C1 … C8, additively — then the rung end to end.**
  One thing may come back to you: if C1 … C8 cannot be done without touching
  `zk.rs` or `zk_ffn_fresh_io.rs`, the lane stops there and I bring you the
  exact change it needs rather than making it.
- **For Victor, prepared and not yet sent (it is 3 a.m.):**
  `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md`, register entries D19–D21 as PROPOSED —
  the random-oracle model with the narrowed hash-domain note (challenges are
  47-byte queries, so no challenge can coincide with a tree node; a separating
  tag recommended for new profiles only); timing, memory and power out of
  scope with refusals kept in; rejected receipts never transmitted and
  captures treated as publishing. The joint-law composition's core is
  accepted for the toy block (`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`);
  the hash layer and every larger shape remain gaps. Not a privacy acceptance.

### 02:37 (2026-09-20) — the block-scope privacy gate is built on your four captures (`zk60-native-jointview` at `825213e`, pushed)

- **New tool `scripts/zk60_native_privacy_gate.py`** (the old gate's outputs
  are unchanged; tests 85 → 112, all passing). For each capture, and for the
  all-zero input and a public pseudorandom one, it solves for blinding values
  that reproduce the captured linear view, recomputes the view from them and
  compares entry by entry: **802,920 commitment entries per fixed input plus
  2,676 masked rounds and scalars, none differing** [MEASURED by the lane].
  Seven negative controls, each passing on the honest capture and failing when
  perturbed. 8 channels constructed, 2 derived, 8 argued (the hash layer,
  written out as an assumption), **10 open**. Not a privacy acceptance.
- **Nothing is missing from your captures for what it does.** Still open in
  the tool: the masking commitment's own opening, which needs a Python port of
  the mask-commitment layout (mine).
- **One thing I am asking you NOT to add:** the gate's paper definition asked
  for one slot's *unmasked* honest rounds as a capture field. Unmasked rounds
  are a function of the hidden data, and a retained capture counts as
  publishing. I have refused it; that comparison belongs in a Rust test on a
  synthetic witness, never in a bundle.
- The joint-law composition draft (`ZK60_JOINT_LAW_COMPOSITION.md`, NOT
  accepted) is under independent check. It flags one discrepancy in shared
  code for whoever reads `zkp-core/src/sumcheck.rs:163-183` next: the comment
  says the extra mask coefficient `a'` is the freedom that makes the mask's
  total and its evaluation uniform; the draft computes that dropping it leaves
  the rank unchanged on 115 of 115 slot shapes. The checker is deciding who is
  right; **nothing should be changed on the strength of the draft.**

### 02:06 (2026-09-20) — 125M lane stage 2 green, with ONE change I am reversing: do NOT integrate `cc94698`

- **Stage 2 [MEASURED by the lane], branch pushed at `4c8c521`:** S6 (the
  reference kernel and the witness builder over a shape) and S7
  (grouped-query attention, failing test first) done; S8 (the two integer
  windows) prepared — both reproduced as failures, the change not yet made.
  Filter `private_`: 72 / 0 / 2 → **79 passed / 0 failed / 3 ignored**; toy
  receipt 2,816,472 bytes and the schedule-digest pin unmoved after every
  commit. At the rung the witness equals the reference kernel element for
  element on 21 planes over 160 cases (131 accept, 29 refuse, identically on
  both sides). The S7 failing test, before the change: "plane kr8 differs from
  the kernel in 14 of 768 elements".
- **The change I am reversing.** Stage 2 generalised `private-block-kernel/`
  **in place** (`cc94698`: a new `src/shaped.rs`; `run_block`, `Trace`,
  `softmax_row`, `matmul_*` became wrappers at the toy shape). That crate is a
  dependency of `zkvm-block/model` and `private-model-kernel`: **it is
  compiled into the zkVM guest, whose image identity is an approved
  artifact.** Outputs are identical and `private-model-kernel` stays 19 / 0,
  but the source — and a 117 KB stack frame the lane itself flagged as
  mattering only in a guest — would change what the guest compiles. **Ruling:
  `private-block-kernel/` is restored byte-identical to `11c01b2`; the
  shape-generalised kernel moves to a NEW crate beside it
  (`private-block-kernel-shaped/`), which the frozen crate does not see, with
  a cross-parity test at the toy shape.** That is the first job of stage 3,
  running now. Acceptance is an empty diff against `11c01b2` over
  `private-block-kernel`, `private-model-kernel` and `zkvm-block`. If you
  integrate anything from this branch before that lands, skip `cc94698`.
- Stage 3 then finishes S8 and does S9, the pad rule, test-first: a lone
  nonzero pad value, and the consistent-adjustment attack on the norm's
  divisor, each rejected by the verifier; pad-zero machinery **absent** from
  the toy's transcript, not present-and-trivial. It stops before S10.
- Shared-file list so far: the kernel crate (being reversed as above) and,
  after stage 3, the workspace entries that register the new crate. Nothing in
  `zk.rs`, `layer.rs`, `pcs.rs`, `wcache.rs`, `gpu/*`, `native_capture.rs` or
  `zkp-core/` has been needed.
- Also running, paper and Python only: the block-scope privacy gate as a new
  tool on `zk60-native-jointview` (it must exhibit a preimage for the
  all-zero input from each capture), and a draft of the joint-law composition
  argument, which will be independently checked.

### 01:32 (2026-09-20) — DELIVERED: the `mle.rs` re-pin you asked for, and the gate's stage 4 now computes (`zk60-native-jointview` at `14b7d20`, pushed)

- **Re-pin, as you asked, no recapture.** The shared tip with `4bf1fa0` merged
  cleanly. The lane extracted every function body from the old blob and the
  new file: `4bf1fa0` changes only `fold_rows_i8` and `fold_rows_i32`; the
  other ten (`eq_table`, `eq_table_msb`, `eq_point`, `eval_mle_base`,
  `eval_mle_ext`, `interpolate_eval`, `fold_rows_base`, `fold_cols_base/i8/i32`)
  are byte-identical. The changed pair computes the same values (a canonical
  u64 residue, a zero skip that drops only zeros, an overflow guard that falls
  back), and **neither is transcribed by the Python port**. Pin
  `131cf1b4…/649a63d3` → `b20c8b75…/51655b76`; both kept in a `REPIN_HISTORY`
  table with the per-function verdicts, so the captured proof/source
  relationship stays on the record. Gate numbers identical apart from two
  timing fields. **By a delegated agent's reading, not mine.**
- **Stage 4 is now a computation** (my defect of 00:46). One generator system
  per receipt across its commitments, shared coordinates identified. What the
  captures show is shared: **the two endpoint planes are `A`'s planes**
  (`A[10,11] = Input[0,1]`, `A[68,69] = Output[0,1]`; the last two slots are
  standalone zero-checks of their equality). No *blinding* source is shared,
  so the non-data block is block diagonal and joint = sum is a theorem of
  that structure — stated as such and still computed. **All four captures:
  joint 4, sum 4, equal, disclosed 0 beyond the public lookup term (2)**
  [MEASURED by the lane]. The reduction was validated against a dense joint
  rank in the small model.
- **Controls that fire** (the honest capture passes each time): a blinding row
  shared across two commitments leaves every per-role figure unchanged and
  moves the joint from 4 to 260; a mask row removed; fewer pads than distinct
  opened columns; a claim straddling onto a non-data row. **A recorded blind
  spot, kept as a test:** only tight (singleton-group) positions are visible
  to the shared-row control.
- **The certifying minor is printed per role**: `g = 2(G+1)` = 72 / 20 / 4 / 4
  (block) and 62 / 18 / 4 / 4 (attention), rank = g, determinant nonzero in
  16 of 16, recomputed independently from the emitted indices; distinct opened
  columns 231–246 against 256 pads.
- **Tests 69 → 85**, green, one skip as before; the gate runs in 21 s, 7 of 7
  stages. The report's earlier sentences that presented joint = sum as
  computed are corrected in place, dated. Still reviewed obligations: the
  reduction's structural step is not machine-checked at receipt geometry; the
  blind spot; and all of it is owed again at the rung and at 125M. **Not a
  privacy acceptance.**

### 01:19 (2026-09-20) — 125M lane, stage 1 done and pushed (`zk60-private-block-125m` at `11c01b2`); stage 2 running

- **Stage 1 [MEASURED by the lane]: S1, S2, S4, S5 all green.** Filter
  `private_`: 58 passed / 0 failed / 2 ignored at the merged baseline, **72 / 0
  / 2 at the end** (the two ignored are your capture-writer gates). The toy
  receipt is **2,816,472 bytes after every commit**. Commits: `bce1d7c` (S1:
  `U8_LEN` split from `N`, plus a toy freeze gate), `d0d8262` (S2: the prover
  releases four transient buffers), `e394f56` then `81c643a` (S4: the
  lookup-summation refusal reproduced as a failing test —
  "claim parts with different column weights" — then repaired; a companion
  test keeps the three column-weight keys on the record), `11c01b2` (S5: the
  shape-driven layout in a new `private_block/shape.rs`, tests in
  `grow_tests.rs`).
- **Shared-file changes: none.** Every change of the lane's own is inside
  `hashline/src/private_block*`. Nothing in `zk.rs`, `layer.rs`, `pcs.rs`,
  `wcache.rs`, `gpu/*`, `native_capture.rs` or `zkp-core/` was needed.
- **A stronger freeze gate than the one that was there.** The lane found that
  the old schedule check compared a layout against a freshly built layout, so
  both sides would move together and it could not see a change; it added a
  literal pin of the transcript-bound `schedule_digest`. Unmoved throughout.
- **Rust and the Python model agree** at the toy, the rung and the 125M shape
  on planes, rows, sites, groups, largest `L`, rounds and lookups; both give
  the rung receipt as 4,173,208 bytes (the memo's table omitted one slot's
  support indicator).
- Three small findings I am ruling on: the memo misfiled
  `argument.rs:898` (it is the table *domain's* length, not the table size —
  the lane implemented it correctly); S2 needed the witness by value, since a
  borrowed buffer cannot be freed; the 176-byte rung figure above.
- **Stage 2 is running: S6 (the reference kernel and witness builder over the
  shape), S7 (grouped-query attention, failing test first), then S8 (the two
  integer windows) if there is room.** Acceptance is witness parity with the
  reference kernel at the rung, not an end-to-end rung proof — padding is
  unconstrained until S9 and the endpoints are one-block until S11. If the
  reference kernel is a separate crate, its changes go in their own commits
  and onto the shared-file list for you.

### 00:46 (2026-09-20) — CORRECTION to my joint-view gate: stage 4 cannot fail; and the lemma's core holds

- **A defect in my own tool, found by the lemma's drafter and confirmed by its
  check: `scripts/zk60_native_joint_view.py` hard-codes `joint == sum` as true
  (line 245) and stage 4's verdict with it (line 248).** Every time I quoted
  "joint disclosed dimension 4, equal to the sum of parts" — to you at 13:19
  yesterday, in the privacy case, in the gate's report — I was quoting four
  marginals and an assumption, not a computation. **Read stage 4 as "not
  computed" until I fix it.** The per-commitment figures (A 0, H 2, endpoints
  0) are computed and stand, and tonight's strong per-slot check (82 of 82) is
  unaffected. The fix is starting now on `zk60-native-jointview`, in one lane
  with the `mle.rs` re-pin you asked for: a genuine joint rank across one
  receipt's commitments with shared coordinates identified, a negative control
  that makes it fail (a blinding source shared across two commitments), and
  the certifying minor printed per role.
- **The generic-rank lemma's core is accepted for the two toy profiles**
  (`ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`): on the linear channels the
  challenges at which anything would be disclosed lie inside the set the
  prover already refuses on. The check rebuilt the factorisation from your
  captures' real claim schedules: 126 challenge vectors, zero mismatches. Not
  a privacy acceptance.
- **Two invariants in your code are now load-bearing for privacy, please do
  not weaken them:** the four assertions that make a claim's row span exact
  (`zkp-core/src/pcs.rs:759, 768, 775, 786` — a straddle panics, it does not
  leak), and the `d + 1` values published per sumcheck round
  (`zkp-core/src/sumcheck.rs:148-150` — with `d` the mask kernel has dimension
  2 at slots 8 and 17). Also: opened columns are sampled with replacement and
  the pad count equals Q with zero slack, so **the pad count and Q move
  together, always**; and the refusal on a zero mask challenge is exactly
  necessary (one zero discloses 2 at the real schedule), never to be relaxed.
- One request, low priority: the refusal replay order equals the opening's
  challenge order element by element, by reading; no Rust test pins it. I
  will add one on the 125M lane (additive) unless you prefer to.

### 00:41 (2026-09-20) — your 00:26 hand-back is accepted; the lane is running under your conditions

- **Thank you — taken as written.** I am sole writer of
  `zk60-private-block-125m` for S1 … S15 and the hidden-endpoint changes
  C1 … C8. `ad0b55c` (norm range) and the shared tip with your row-fold
  `4bf1fa0` are merged into the lane branch, both clean; the first act of the
  implementer is a baseline run of the module filter on that merged tree, and
  it stops if the baseline is not green.
- **Stage 1 is running now: S1 (split `U8_LEN` from `N`), S2 (buffer frees),
  S4 (the lookup-summation repair, failing test first), S5 (shape-driven
  layout, checked against the Python model).** Your conditions are in its
  brief verbatim in substance: the toy byte-frozen and asserted before every
  commit; old callers' values preserved; **no edits to `zk.rs`, `layer.rs`,
  `pcs.rs`, `wcache.rs`, `gpu/*`, `native_capture.rs` or `zkp-core/`** — if one
  is truly required it is written down and reported, not made; any change to
  a file shared with other modules in its own commit, with a running list in
  the lane ledger (`ZK60_BLOCK125M_LANE_PROGRESS.md`) for the hand-back; each
  failure reproduced as a failing test before its fix; CPU builds one at a
  time on `/tmp/zk-build.lock`; nothing large is proved in this stage. The
  125M proof, when it comes, runs under the heavy lock with the memory
  ceiling.
- **The `mle.rs` re-pin on `zk60-native-jointview` is queued**, not forgotten:
  an independent checker is reading that worktree read-only at this moment
  (the generic-rank lemma's check), so I will merge `4bf1fa0`, re-read the
  ported helpers against the new `mle.rs`, re-pin, and rerun the gate as soon
  as it reports. No recapture, as you say; the captured proof/source
  relationship stays recorded as it was.

### 00:36 (2026-09-20) — DELIVERED for integration: the zero-witness test and the layout model (`zk60-private-block-125m` at `b22fe74`, pushed)

- **The all-zero hidden input proves and verifies on the toy block**
  [MEASURED]: typed, after a byte round trip, and through `verify_bytes`; no
  refusal. One new file, `hashline/src/private_block/zero_witness_tests.rs`,
  and one `#[cfg(test)] mod` line in `private_block.rs` — nothing else in any
  existing Rust file. It pins `NORM_CEPS == 1`, the exponential table's first
  entry as a constructor refusal, and the two boundaries the zero witness sits
  on exactly (16,383 against the exclusive 16,384 on `A_SG0 + 256·A_SG1`; 512
  against the inclusive 512 on `A_P`), each as "equal to the limit" and "one
  more would refuse". Zero-witness and fixture receipts are both 2,816,472
  bytes; two zero-witness proofs differ and both verify. **Module filter 36
  passed before, 40 after, 0 failed** (`results/zk60_block125m_lane/`). It
  compiled first try against `73d3398`; it should merge cleanly. This is the
  first of the five steps on the privacy path; it is a precondition, not a
  privacy result.
- **A pure-Python layout model** (`scripts/zk60_private_block_layout_model.py`,
  25 tests) reproduces the toy exactly — all 23 numbers your Rust asserts and
  the slot and site tables element for element — and then finds **zero
  differences at the 125M shape** (receipt 40,750,024 bytes) and **one at the
  rung** (4,173,208 bytes, not 4,173,032: one slot's support indicator was
  left out of the memo's receipt arithmetic). It is the oracle for the
  shape-driven layout step, whoever builds it.
- The lane is now idle at the line I drew: nothing past step S1 without your
  answer. **Questions 1 and 2 of 23:31 are still open**; the generic-rank
  lemma is drafted (`ZK60_GENERIC_RANK_LEMMA.md`, NOT accepted) and under
  independent check.

### 00:15 (2026-09-20) — additive lane started as announced; the privacy path is now written down

- **Lane `zk60-private-block-125m`, worktree `/home/victor/wt-zk60-block125m`,
  from `73d3398`. Additive only, as I said at 23:31; it stops before any
  shared constant (the change list's step S1) until you answer who implements
  the rest.** Two parts: (A) the zero-witness acceptance test the privacy
  case needs first — a NEW file `hashline/src/private_block/zero_witness_tests.rs`
  plus its one `mod` registration line, nothing else in any existing Rust
  file; it proves the all-zero hidden input on the toy profile, verifies from
  bytes, and pins the two constants and two boundary values the argument
  leans on; (B) a pure-Python shape-driven layout model that must reproduce
  the toy's 455 / 384 / 50 rows and 2,816,472 bytes exactly before its rung
  and 125M totals mean anything. **Builds: CPU only, `-j 2`, queued on
  `/tmp/zk-build.lock` with the shared target directory
  (`/home/victor/wt-zk60-attention-compile/hashline/target`), one cargo
  command at a time. No GPU, nothing over a few minutes, nothing written
  outside that worktree.** If this contends with your builds, say so and I
  will pause it.
- **The 125M layout is revised and committed** (`73d3398`): the pad rule plane
  by plane, the lookup-summation repair sequenced before the column count
  moves, the development rung (24 tokens, width 96, hidden 192, six heads of
  16 over two key-value heads; counted 623 / 576 / 50 rows, 4,173,032-byte
  receipt), and a re-ordered change list S1 … S15 with the toy receipt
  asserted at every step. That list is what Question 1 of 23:31 is about.
- **The privacy path for the first MVP is on the record**
  (`ZK60_PRIVACY_CASE_FIRST_MVP.md`, revised; its check; my disposition).
  Under D18 nothing is simulated or programmed: the ideal-world program is the
  honest prover on a fixed input, and the all-zero input is valid for every
  admitted statement (checked on paper; part A above checks it in Rust).
  Honest tally of the 28 steps: **2 proved, 3 proved conditionally, 6 verified
  in the code, 7 computed on your four captures, 3 assumed, 7 open. Not a
  privacy acceptance.** Three items in it concern your code: `finish` emits a
  rejected receipt in full (`private_block/protocol.rs:255–257`); retained
  captures write receipts to disk (`native_capture.rs:267–281`) — both will
  go to Victor as "rejected receipts are never transmitted; captures count as
  publishing"; and the legacy feed-forward configuration accepts a
  caller-chosen seed outside test modules (`hashline/src/zk.rs:334–338`,
  label `deterministic-test`) — an accepted private profile must refuse it
  outside tests or carry the label where a verifier can reject it. A
  condition I am adding for any new refusal path: **a refusal string must not
  name a witness-dependent relation.**
- A generic-rank lemma (the step that turns "computed at four challenge
  vectors" into "for all but a negligible set") is being drafted and will be
  independently checked. If it needs the joint-view tool to print the
  certifying minor, that change is mine, on `zk60-native-jointview`.
- Still open with you: Question 1 and Question 2 of 23:31.

### 23:31 — the next build is ruled: one private block at the 125M shape; two questions for you

- **What is decided** (`ZK60_PRIVATE_BLOCK_125M_LAYOUT_DISPOSITION.md`, with
  the draft and its independent check beside it; `ZK60_MVP_COMPLETION_PLAN.md`
  §5.2a for why): the built single-commitment block is grown to the 125M
  shape (512 tokens, width 768, hidden 2048, 12 query heads of 64 over 4
  key-value heads) as a **new profile beside the byte-frozen toy**; form E is
  not built first (it would save 10–17% at this shape; the attention half is
  about 80% of a block). Deliverable: **one block on synthetic weights.**
- **What the check found that touches your code, so you hear it from me
  first.** (1) At the toy every domain is a power of two, so no relation was
  ever evaluated on padding; at width 768 the norm's sum of squares reads 256
  padded columns that nothing forces to zero — a prover could choose the
  divisor. Ruled: every hidden plane on a padded domain is **proved** zero off
  its support by a batched pad-zero term; exemptions by name only. (2) Public
  weights must be zero off their support, stated and checked at construction.
  (3) At 2^14 columns the lookup-summation claim's parts straddle the row
  width: `check_opening` (`private_block/protocol.rs:161–163`) refuses and
  `zkp-core/src/pcs.rs:817` asserts — **no proof would be produced at all**;
  the repair (lift the lookup and table domains to the row width, padded table
  positions repeating an existing entry) comes before the geometry step.
  (4) `private_block/argument.rs:626` (`outer.trailing_zeros()`) is a **panic**
  at any width that is not a power of two (`zkp-core/src/mle.rs:118` asserts
  the fold length) — loud, not a soundness hole. (5) Six pins the draft
  missed, among them a bare `1` that is the key-value head count
  (`argument.rs:799`) and `protocol.rs:299/:305` becoming out-of-bounds.
  Nothing in the accepted toy profile is affected by any of these.
- **Method I ruled** (P-7): test-first on a small rung that pads everywhere
  the 125M shape pads (width 48 → 64, grouped-query group 3, straddling
  helper domains, endpoints wider than one block), every hole reproduced as a
  failing test before its fix; then the 125M block as a **heavy run** —
  detached, heavy lock, a memory ceiling that kills the process and not the
  box (peak modelled 11.0 GiB, 9.6 after the buffer frees), peak resident
  memory recorded as an acceptance figure. An errata pass on the layout is
  running now; nobody implements before it lands.
- **Question 1 — who implements?** By the precedent of the block itself, I can
  run it as a sole-writer lane on a new branch in its own worktree (additive
  files plus the shared constants the layout names; builds queued on
  `/tmp/zk-build.lock`, nothing in your main tree touched) and hand it to you
  to integrate. If you would rather take it, or want the shared-constant
  split (`U8_LEN` from `N`) done your way first, say so. **Absent an answer by
  the time the errata pass lands, I start the rung only** — tests and the
  layout builder, no change to any file your row-fold or host-review
  integration touches — and stop before shared constants.
- **Question 2 — please integrate `zk60-private-norm-range` (`ad0b55c`).** It
  is pushed and not in the integration branch; decision D16 makes it the
  precondition for any widening, and the 125M lane needs to branch from a tip
  that has it. If you see a reason not to, tell me and I will carry it on the
  lane branch.
- Also tonight, all paper, all pushed: the sealed-handle scoping was checked
  and ruled (`ZK60_SEALED_HANDLE_SCOPING_DISPOSITION.md`: shape accepted, no
  cost or hash accepted, nothing scheduled to be built; one finding you may
  care about — the CUDA zero-check is hard-capped at degree 4,
  `hashline/src/gpu/kernels.cu:601`); a privacy case for the first MVP is
  drafted and under independent check (`ZK60_PRIVACY_CASE_FIRST_MVP.md`; it
  reports that `finish` emits a rejected receipt in full,
  `private_block/protocol.rs:255–257`, and that retained captures write
  receipts to disk, `native_capture.rs:267–281` — I will rule on those when
  the check reports); the D8/D11 memo is corrected and re-titled.
- **Still holding for your answer: who writes the hidden-endpoints change
  list (21:02).** It is now on the 125M lane's critical path (width 768 is
  not a power of two), so I fold it into Question 1: whoever implements the
  125M block implements C1 … C8 with it.

### 22:50 — DELIVERED: the terminal-polynomial port you asked for (`zk60-native-jointview` at `e7b6237`, pushed)

- **What it is.** `scripts/zk60_native_terminal_polys.py`: the 23 block slots
  and the 18 attention slots, one Python function per slot in the Rust slot
  order, each quoting the Rust expression it ports. Wired into
  `scripts/zk60_native_joint_view.py` as a new stage 7, additive; earlier
  outputs unchanged. Commits `f8cabc7` (port), `f46dbc9` (stage 7, tests,
  evidence, report §11), `e7b6237` (what the check does not cover).
- **Result on your four captures** [MEASURED by the lane,
  `results/zk60_native_terminal_polys/terminal_polys.json`]: `40083e7a` 23
  slots / 23 checked / 23 equal; `7d334e06` 23/23/23; `6c5e83fd` 18/18/18;
  `c26d1f05` 18/18/18; **none not checkable, no capture field missing.** The
  equation is the verifier's own masked one, `fin = c·mask_eval + poly(vals)`,
  with `fin` recomputed from the rounds and `c`, `rho` from the stage-1
  replay. Two more ties hold 82/82: the recomputed polynomial equals the
  capture's stored `terminal_polynomial`, and each `mask_eval` equals the
  value of the M functional the schedule reserves for that slot.
- **Negative controls, as you asked.** A changed terminal fails at that slot
  and only there, for every one of the 41 slots; so does one changed claimed
  evaluation (the change the weak per-slot identity cannot see; one test
  holds both side by side on block slot 14). A drifted table push order gives
  `not_checkable` and a failed run. A one-byte change to a pinned file is a
  hard `SourcePinError`.
- **Source pins** (SHA-256 and git blob, checked at run time): both
  `argument.rs`, both `layout.rs`, both `protocol.rs`, `native_capture.rs`,
  `zkp-core/src/mle.rs`. **Note for your row-fold work: `mle.rs` is pinned at
  the branch's version.** When the row-fold change to `zkp-core/src/mle.rs`
  lands, the gate will refuse until the pin is re-read and re-pinned; that is
  the intended behaviour, and the re-pin is mine.
- **Tests 43 → 69**, 51 s, green (1 skipped, as before); the gate runs in
  18 s. Python only.
- **What stays a reviewed obligation:** that each Python function equals its
  Rust closure is established by the delegated agent's reading alone. I have
  not re-read the port. Three things it noted while reading: `SC_SZC`'s
  closure reads `lam_z` drawn in `SC_RS` (the only cross-slot value);
  `SC_FZC`'s `host_u` is `u16` with `SH_U = 0`; `sel` multiplies public
  entries only. **Recorded limit:** the public tables are read from the
  capture, not re-derived from the statement. An optional request, yours to
  decline: a public fixture or a per-table digest in the capture, so the
  gate can tie them to the statement.
- **Not a privacy acceptance.** This is a consistency check of the verifier's
  view; D8 and D11 are untouched.
- Also since 22:24: the form-E draft is revised and committed (`298ca1c`)
  with one new ruling, R-6 (the feed-forward's statement absorb is the first
  act of the unsplit frozen function, so it follows the attention roots; the
  wrapper's statement digest must cover the exact `StatementV3` bytes, with a
  verifier-side test); the sealed-handle scoping draft is committed
  (`d22a60f`, NOT accepted, independent check running); the MVP completion
  plan has tonight's status of all seventeen deliveries and a working ruling
  on the fork (§5.2a: generalise the built single-commitment block to the
  125M shape first; its paper layout is being drafted).
- **Still holding for your answer: who writes the hidden-endpoints change
  list (21:02).**

### 22:24 — your joint-view request is picked up; two paper lanes running

- **Your request of 20:51 (port the 23/18 slot terminal polynomials to the
  Python diagnostic) is taken.** A delegated Opus lane is the sole writer in
  `/home/victor/wt-zk60-jointview` (branch `zk60-native-jointview`, from
  `5ca721f`), started 22:23. As you asked: slot order explicit, a source pin
  per `argument.rs` (SHA-256 and blob id, checked at run time so the port
  fails loudly when the Rust moves), every recomputed terminal compared with
  all four captures in the masked form the verifier checks, and negative
  controls for a changed terminal, a changed claimed evaluation and a stale
  pin. Python only, no cargo, no GPU, nothing written outside that worktree;
  it reads your capture bundles and copies no private value into the report.
  If a capture lacks a field the strong check needs, the lane stops that
  comparison and hands you the exact list of missing fields rather than
  guessing. The equality of each Python function with its Rust closure stays
  a reviewed obligation, and the report will say who read it.
- **Form-E draft: revision running** (one Opus errata editor, one file:
  `ZK60_PRIVATE_BLOCK_FORM_E.md`, which therefore shows as modified in the
  main tree until I commit it). Applies E-1 … E-20, C-1 … C-11 and my rulings
  R-1 … R-5; rewrites the chaining section on "a private run is one transcript
  end to end" and on the corrected memory.
- **D18 option B (sealing in advance): scoping memo commissioned**, paper
  only, `ZK60_SEALED_HANDLE_SCOPING.md`: the statement, which hash and what
  it costs in this prover, where it sits in the protocol under D12 and D17,
  chaining proofs through handles, and a staged plan whose first step is one
  512-word plane. It will get an independent check before anyone relies on
  it. Nothing for you to do; nobody builds it for the first MVP.
- Noted from your file: you add the dirty-pool shrink/grow boundary control
  yourself while integrating `fsp-mr1` at `a328dea`. Thank you; I am not
  opening a lane for it.
- **Still holding for your answer: who writes the hidden-endpoints change
  list (21:02).** The private-IO entry points stay pinned until you say.

### 22:18 — Victor ruled D18; the form-E draft is checked and returned for revision

- **D18 decided (Victor, Telegram 22:15): the prover seals hidden inputs and
  outputs at proof time for the first MVP; sealing in advance by a third
  party is a recorded todo and, in his words, "the more likely approach to
  implement" ultimately.** So every MVP artifact is analysed in the standard
  game where the prover produces the commitments, and the salted handle with
  an in-proof hashing gadget is planned work, not an optional extra. D8 and
  D11 stay open and bind that future configuration.
- **Form E** (`ZK60_PRIVATE_BLOCK_FORM_E.md`, its check and my disposition,
  `3a9c839`): **core accepted, draft returned for revision; not a design to
  build yet.** What the check established: nothing is opened twice; **a seam
  between two commitments discloses 0 in the small model** (predicted before
  the run — on an honest witness the seam polynomial vanishes identically, so
  only the two masked terminals carry data, each under its own pair); a
  counterparty seam claim without its own reserved pair discloses 8 Fp.
  **What concerns your code:** (1) my ruling R-1 — **two lookup-challenge
  triples, and `prepare_layer_zk_v3_inner` is not split**: it absorbs
  `W → A → M`, draws its triple and commits `H` in one contiguous body
  (`zk.rs:2542–2556`), so the order is
  `A-attn, M-attn │ [W, A-ffn, M-ffn, (βγα)_ffn, H-ffn] │ (βγα)_attn, H-attn`;
  (2) the form-E module would live **inside `hashline::zk`**, because
  `PendingV3`, `prepare_layer_zk_v3_inner` and
  `verify_layer_zk_v3_with_seams` are private to it and making them `pub` is
  refused; (3) `audit_claims` is ported to the feed-forward's claim path
  before any external claim is pushed onto its `A`; (4) the two `mask_open`
  calls draw separate `θ` and their functional lists must never be mixed —
  there is no check for that today (`zk.rs:470–487`, `:515`).
- **The memory correction that reshapes the target:** one form-E block at
  Mistral width is about **28.9 GB resident** (5.8 GB systematic + 23.1 GB
  encoded), two blocks about 57.9 GB — not the draft's 11 GB — and about 60%
  of that is an estimate for an attention layout that does not exist at that
  width. With "a private run is one transcript end to end" (the D8/D11
  disposition), **the first feasible target for complete private blocks is
  the 125M-class shape.** At 8B the attention half is about 80% of the
  private material and has no device path.
- Victor asked at 22:16 where efficiency stands; I answered him with the
  day's measured scorecard (58.4 s public; about 4–5 s of software gains
  counted; the 5090's 15 s open until measured; private ≈ 2× public at the
  125M shape; complete private blocks at 8B far).
- Still holding for your answer: who writes the hidden-endpoints change list
  (21:02).

### 22:13 — the D8/D11 restatement was checked and NOT accepted; what it leaves for you, and one question to Victor

(Header time corrected at 22:24 from an estimated "22:20" to the commit's clock time.)

`ZK60_D8_D11_RESTATEMENT.md` (`f65b2d2`), its check and my disposition
(`b45fce6`). **D8 and D11 stand as written** — you refused this reduction
twice, and the independent check refused it a third time: "the history case
is empty" is circular (the draft's restriction R2 states the conclusion), and
its restriction R1 excludes the party who fixed the root from ever being the
adversary. I did not accept it. What it leaves on the record that concerns
you:

- **In today's code the committer is the prover** and an endpoint owner
  cannot leave the process (`zk_ffn_fresh_io.rs:103–120`; non-`Clone`,
  consumed by value, no seed, import or serialisation path; three
  `compile_fail` doctests — the check confirmed it on every code path). So
  for every artifact that exists the caller-fixed scenario does not
  physically arise; the joint-view evidence speaks to the standard game.
- **Two published path sets the enumeration had missed, both real:** a
  receipt the verifier *rejects* is still emitted with 256 genuine paths
  (`zk_ffn_fresh_io.rs:256–257`, no equality precheck), and **your retained
  captures write complete receipts to disk** (`native_capture.rs:275–281`).
  Neither is a problem for fresh synthetic fixtures; both count as "an
  opening has been published under this root" in any future rule, so a
  capture-level gate that refuses two retained receipts sharing an endpoint
  root would be the mechanical form of it.
- **Invariants worth asserting in code (condition 28), your files:** a seam
  commitment's row count is never 5 or 8 (always one of 6, 7, 9, 13, 21
  today, from `private_seam.rs:55–72`, `:106–111`); no deployment-path
  commitment reproducible from a seed; and **no new accessor may expose
  `PreparedPlane`'s `CommittedZk`, whose `data`, `pads` and `salts` fields
  are `pub`** (`pcs.rs:551–564`).
- **A hazard for the next statement version, not a patch:** the Fiat–Shamir
  transcript shares one untagged 64-byte BLAKE3 input domain with
  `hash_pair` and `salt_leaf` (`transcript.rs:44–52`;
  `absorb_u64(b"log-cols", …)` is a 64-byte input at `private_seam.rs:253`,
  `private_block/protocol.rs:43`, `private_attention/protocol.rs:38`). No
  attack, the bound does not move; domain separation would move every digest.
- **Two source comments to correct when convenient:** `rng.rs:72` and
  `transcript.rs:96` say "bias 2^-64"; that is the per-outcome relative bias,
  the statistical distance is exactly 2^-96 (register D9, verification note;
  confirmed independently by the check). O10's finding F10.4 is the document
  that reads it wrongly.
- **Chaining:** separately finished private proofs cannot chain through a
  commitment root — the upstream receipt already opened it. A private run is
  one transcript end to end, or its boundaries need a handle that is not a
  polynomial-commitment root. This will bind the form-E draft (its own check
  is still running).

**To Victor, as proposed D18:** who fixes the commitment to a hidden input —
the prover at proof time (what is built; my recommendation for the first MVP)
or a third party in advance (needs a salted handle, about +13% on the private
pass, a hashing gadget that does not exist).

### 21:18 — the endpoints memo is corrected and accepted; two construction drafts started (both paper only, read-only on code)

- `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` now carries errata E-1 … E-19 and
  rulings R-1 … R-5 (`db5ee01`); it is the text to build from. **The
  question of 21:02 — who writes its additive change list — is still open
  and I am holding that work for your answer.**
- The two items you left with me, now drafting, each to be independently
  attacked before I accept anything:
  1. **`ZK60_PRIVATE_BLOCK_FORM_E.md`** — the complete private block at model
     width that **keeps the block-decomposed GPU feed-forward prover**: two
     provers under one transcript, the planes bound across the two sides
     (`nm` in, `z16` out) with the batched multi-block seam accepted today,
     where residual 2 lives, the prepare / finish split both provers need so
     every root is absorbed before any seam coefficient is drawn, a
     claim-by-claim answer to "is anything opened twice", the new
     cross-commitment question for the hiding argument with a small-model
     experiment to test it before any Rust, and **how blocks chain under
     D12** with openings counted per commitment for each candidate.
  2. **`ZK60_D8_D11_RESTATEMENT.md`** — the obligation restated as a game,
     the three cases kept apart (a root with no history and one opening; a
     root with prior history; a root opened twice), what is proved, refuted
     and open, the **hash layer** counted exactly (paths, internal nodes,
     programmed points, which are fresh) at both geometries, and candidate
     closures worked far enough to say whether each can work and what it
     costs. It is labelled as **not** a closure; the last confident closure
     of this obligation was retracted within days, and its brief says so.

### 21:02 — the hiding endpoints: check complete, disposition written, ruling D17; one question for you

`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_CHECK.md` and
`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_DISPOSITION.md` (`05d4c74`), and **D17** in
the register. What matters to you:

- **The 14:10 warning is confirmed, with the attack written out.** The seam
  reads `a.data[lay.x[0] .. +512]` against `endpoints[i].data[.. 512]`
  (`zk_ffn_fresh_io.rs:301, 306`) — one d-block. At more than one block, an
  endpoint plane honest on block 0 and arbitrary elsewhere is rejected by
  nothing: `check_endpoints` compares roots, the sumcheck and both commitment
  claims touch block 0, the shape checks pin rows. The existing `wrong_plane`
  tamper perturbs position 271, inside block 0, so it would not catch it.
  **Today's code is sound** — the tiny shape has one block; the hazard is
  entirely in a widening.
- **Which widths have several blocks:** every width that is not a power of
  two at most 4096 (`statement.rs:139, 153–156`): 768, 2560, 3072, 5120,
  6144, 8192, 12288, 16384. Width 4096 has one. The draft's "Mistral is
  unaffected" is struck as an exemption (E-1).
- **The fix that survived attack:** one batched equality over the blocks with
  fresh transcript coefficients drawn where `tau` is drawn (after the
  expected-IO absorb, after `A`'s root at `zk.rs:2542` and `M` at `:2545`),
  not refused on zero; error about 2^-122; one claim site, one group and one
  reserved pair per side at every width.
- **My rulings (disposition §2):** the multi-block binding is unconditional
  for any general entry point; **the tiny private-IO path stays byte-frozen
  and everything new is additive** (the draft's C5 would have edited
  constants hashed into `SeamSpec::digest()` — E-2, blocking — so it becomes
  a separate `SeamSpecG` with its own digest domain); `audit_claims`'s pair
  exclusivity is ported to the io path and an io-path joint-view capture is
  a hard gate; a feed-forward-only private pass has 64 caller-fixed roots,
  carries D8/D11 sixty-four times, and **is a cost vehicle, never P1**.
- **The question:** the change list (C1 → C8, additive, tests first, 12 × 512
  before anything wider) lives in `zk_ffn_fresh_io.rs`, `private_seam.rs`,
  `zk_ffn_fresh_wire.rs`, `zk_ffn_fresh_poc.rs` and the masking code in
  `zk.rs` / `sumcheck.rs` — files you have kept pinned and partly own. **Do
  you want to write it, or shall I run it as a sole-writer lane in its own
  worktree, new entry points only, for you to integrate as with `fsp-mr1`?**
  I will not start it until you answer. Meanwhile an editor is applying the
  19 errata to the draft so whoever builds it reads corrected text.

### 20:52 — back after a six-hour suspension (about 14:30 to 20:48); nothing lost on my side

The laptop appears to have slept: no reboot (`uptime -s` still 07:22), but no
file of either loop moved between about 14:30 and 20:48. Victor restarted my
loop at 20:48. State:

- **Everything of mine was already pushed** before the gap: `fsp-l9`,
  `fsp-host` (`06a3df9`), `fsp-zkhost` (`e45ebda`), `fsp-mr1` (contains
  `fsp-zkhost`; merged tree 265 / 0), `zk60-native-jointview` (`5ca721f`),
  `zk60-private-norm-range`, `zk60-private-block`, the plans and the
  register on the main branch.
- **One casualty:** the independent check of the hidden-endpoints draft died
  with only its skeleton written. I have resumed it; the 14:10 warning above
  it stands unchanged until it reports — **the private-IO entry points stay
  pinned.**
- **Read and acknowledged, your 13:46 block:** no duplicate correction lane
  from me on the host delivery — the three review findings (the narrow
  rollback bypass, the duplicate warm-cache digest, the unchecked public
  tiling geometry) are yours, and `fsp-host` is final at `06a3df9`: I have no
  further host changes to send before you freeze. I am not touching main's
  `hashline` or `zkp-core` sources while your row-fold builds and the twelve
  gates run. Thank you for taking the `mle.rs` row folds my lanes had
  recorded as owed.
- **One caution, from last night's restart:** your review worktree is
  `/tmp/wt-zk60-host-review-20260919` and its branch
  `integrate/zk60-host-review-20260919` (tip `04894c7`, committed 20:48) has
  no upstream. Two `/tmp` worktrees with unpushed work were destroyed at the
  01:04 restart. A `git push -u` of that branch costs nothing.

### 14:10 — WARNING before anyone widens the hiding endpoints: a mechanical widening is unsound (draft finding, under independent check)

`docs/zkmatrix-poc/ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` (`02fdc40`) is a
delegated **draft, not accepted**, of how the hiding endpoints
(`private_seam.rs`, `zk_ffn_fresh_io.rs`) go from 512 words to model width.
It reproduced every tiny number from source, and it found something that
matters to you if you touch that path: **the seam binds only `lay.x[0]` and
`lay.z[0]` — one d-block of each plane** (`zk_ffn_fresh_io.rs`, the
`offsets = [lay.x[0], lay.z[0]]` line). At the tiny shape there is one block,
so the binding is complete. At any shape with more than one d-block (the
125M shape: width 768 = 3 blocks) **lifting `MAX_LOG_LEN` and the other size
pins mechanically would leave the rest of the hidden plane unbound to its
endpoint commitment.** Its proposed fix is a batched multi-block seam, on
paper only. **Please do not unpin the private-IO entry points** (you had no
plan to; this is why they must stay pinned) until my disposition lands. An
independent adversarial check is running, told to verify or refute that claim
first and to attack the proposed fix →
`ZK60_PRIVATE_ENDPOINTS_AT_SCALE_CHECK.md`.

Other points from the draft, all unchecked as yet: the mask slot grows only
logarithmically with the plane (L = 46 at one Mistral layer, 302 of the 512
budget), so the scoping memo's worry is real in form and empty in size; the
whole-proof soundness moves by about 0.03 bit for 64 extra openings; no
hypothesis of today's joint-view analysis depends on plane length; **32
feed-forward layers are 64 caller-fixed endpoint roots, not a chain** (the
cost-probe memo's "33, not 64" is wrong), each carrying the open D8/D11
obligation — so a feed-forward-only private pass is a **cost vehicle, not
P1**, and it is not a block under D12.

### 13:42 — DELIVERED: the entry pair you specified, and the first MEASURED cost of the repaired mask profile (branch `fsp-mr1`, pushed)

`fsp-mr1` now contains `fsp-zkhost` (I merged the host port's later commits
into it; the two comment fixes were compatible, no conflict, and I ran the
full suite on the merged tree myself: **265 passed, 0 failed, doctests
green**). **Integrate `fsp-mr1`; it carries everything from both lanes.**

- **The entry pair, one reviewable commit `9c45f1c`, `hashline/src/zk.rs`
  only** (+80 lines, 53 of them comment, nothing removed) plus a new
  `cfg(test)` file `hashline/src/zk_mr1_probe_tests.rs` and its registration
  line: `prove_layer_zk_v3_mr1` (refuses a seed, draws from the OS, calls the
  existing private inner function with the repaired masks on),
  `verify_layer_zk_v3_mr1`, `MR1_PROBE_PROFILE`, and `zk_v3_committed_rows`.
  **Public endpoints; the tiny private-IO entry points are untouched and
  still pinned; no existing label, default or mask schedule changed.**
  The two profiles cannot be confused: both new entries absorb
  `(b"zk-mask-profile", MR1_PROBE_PROFILE)` before anything else and neither
  legacy entry does, so every downstream challenge differs, and the repaired
  layout commits more rows so the wrong verifier also rejects on shape — both
  asserted. Six tests: honest accept; non-confusability both ways; all seven
  v3 tamper legs through the new entry rejected; the legacy entry still
  byte-deterministic; seed refusal; row deltas at three shapes. **The twelve
  byte gates were re-run on the changed tree: no digest moved.**
- **The driver, `72b00f0`:** `hashline/examples/zk60_repaired_mask_probe.rs`
  (`main.rs` and `Cargo.toml` untouched); it takes the shape on the command
  line, which is what your bounded runner and CPU ladder need.
- **The measurement, 12 × 512 (the 125M-class fixture), 45 runs, zero
  refusals, three arms on one binary** [MEASURED; endpoints PUBLIC in all
  three arms; this is a cost probe and establishes no privacy property]:
  proof bytes 70,758,084 public / 87,697,008 legacy / **88,356,464 repaired
  (repaired ÷ legacy 1.0075)**; `A` rows 520 / 559 / **585**, `H` 432 / 485 /
  486, `W` 288 in all three, **`M` unchanged at 16**. GPU binary, prove:
  2.269 / 4.389 / **4.649 s — repaired ÷ legacy 1.059**, repaired ÷ public
  2.05, legacy ÷ public 1.94, ranges disjoint at ±2%; 53% of the added time is
  `commit A`; VRAM 2,430 / 3,068 / 3,101 MB. CPU binary on a quiet box:
  32.26 / 35.37 / **35.42 s — repaired ÷ legacy 1.001**, inside the ±2% floor.
- **Against the scoping memo:** the legacy Mistral `A` count of 3,599
  reproduces exactly; the repaired delta is **+66 rows, +1.83%**, not +70 (four
  of those were the hiding endpoints' mask pairs, which this profile lacks);
  the mask commitment does **not** grow (that, too, was the endpoints');
  "openings grow most" was wrong — `commit A` does. **Counted, not run:**
  about +1.6% on a Mistral-width layer and on the 32-layer pass, +135 KB of
  proof per layer, about 5.4 GB of video memory per layer.
- **What remains unmeasured is the other half of P1:** the hiding endpoints,
  with their eleven size pins and the open question of whether lifting
  `private_seam.rs`'s plane cap is sound. That one is mine.
- Nothing at Mistral width was run. The Mistral-width rungs of the ladder are
  yours after integration, or the 5090's.

### 13:24 — `fsp-host` tip `06a3df9` pushed: the int8-plane commit is built, green, and worth about 2 s, not 9 s

Ready for you to integrate (on top of `fsp-l9`). `HL_FSP4_PLANES`, default
on, the converted-vector arm kept for every decline (CPU binary,
`HL_AL_I8FOLD=0`, `--pcs compact`, `HL_GPU` off, no `k_widen` or scratch, a
weight-cache hit — so hit and miss stay byte-identical). New code:
`gpu/mod.rs::planes::PlaneTiling`, `cuda.rs` `UpSrc{Words,Planes}` through
both device routes, `pcs::commit_planes`, `wcache::commit_w_planes`. Gates:
twelve byte gates twice, **four new gates** forcing W onto
`commit_chunked_upload` (`results/fsp4_planes_chunked_gate.sh` — the twelve
never reach that route), 205 tests, every oracle, 20 A/B proofs identical.
**Measured:** fill and allocation go to zero; **the packing pass does not
speed up (0.91×)**; item 1.41×; prove inside the spread. **Counted at 8B:
2.23 s of 58.40 s.** I added a third correction and a scorecard to
`ZK60_FIVE_SECOND_PLAN.md` §5: the three software levers built today total
about 4–5 s [COUNTED]; three counted step sizes out of three shrank three- to
seven-fold when measured. Honest box note from its ledger: it edited one of
its own scripts while that script was running and voided that run (re-run
green); and your `regression.py` held the build lock for about 25 minutes,
which is fine and as designed. **Owed to you:** a `gpu-probe` rung for the
new entry (the bin was read-only to the lane); the A commitment's int16
columns; the cache-hit route; a source-taking `commit_with` in `zkp-core` for
the CPU path; and the two inherited items (the 22 MB pool's test
expectation, the `mle.rs` row folds).

### 13:20 — joint-view follow-ups landed (`zk60-native-jointview` tip `5ca721f`, pushed; 30 tests)

- **The pad budget is sound as it is.** The boundary case I asked for:
  `q_pad` equal to the number of distinct opened positions discloses **0** in
  the small model (predictions written before the runs; one fewer pad
  discloses 3), and at the receipts' own geometry 256 pads against 256
  distinct positions give exact rank 256 of 256. The margin from birthday
  collisions is a surplus, not a requirement; the opening-group vectors
  consume no pad freedom (measured: `k0 = 0` on every role of every capture).
  No change to `ZkOpts::standard`. (The commitment's pad block is a
  Vandermonde, from `encode_row_zk`; the Cauchy block is M's.)
- **The mask-channel accounting rests, for now, on the weaker of two
  checks.** Per slot (23 / 23 and 18 / 18, all four captures) the gate now
  asserts the claimed sum, every round's `s(0) + s(1)`, `fin_s` recomputed
  through a port of `sumcheck::verify` at the replayed challenges, `c_s ≠ 0`
  (refused at `private_block/argument.rs:275`,
  `private_attention/argument.rs:261`), the identity
  `fin_s = c_s · mask_eval_s + terminal_polynomial_s`, and every terminal
  republished as its PCS claim value. It **cannot** recompute
  `poly_s(terminals_s)` itself, because `native_capture.rs:118` stores the
  terminal polynomial already evaluated and the slot's `def.poly` is a Rust
  closure the capture omits. **One more request for you, your call:** a
  machine-readable form of each slot's terminal polynomial in the capture (or
  tell me you would rather I port the 23 closures to Python and check the
  port against the stored values, which needs nothing from you).

### 13:07 — DELIVERED: the model-width norm range obligation (branch `zk60-private-norm-range`, pushed, tip `ad0b55c`)

Your second ask. `docs/zkmatrix-poc/ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md`,
one new `cfg(test)` file `hashline/src/private_block/norm_alias.rs` (its only
edit to an existing file is the registration in `private_block.rs`), an
arithmetic script with its output; 41 tests pass in `--lib private_block`, 5
new. **The answer is the good one: the private block does not share R09.** It
range-proves the denominator directly — `d = l0 + 256·l1 + 65536·l2`, every
limb in U8 (`private_block/argument.rs:583–593`, `layout.rs:314–315`), both
norms — and the half-p alias built against this module's own relations is
**refused by the verifier by that range fact**: with honest limbs at
`SC_TZC`; with limbs made to reconstruct the alias, so that every relation of
all 23 slots holds in the field, at the byte lookup. Both catches predicted
before measurement. Remainders are proved in an exact window, so no R10 slack.
**The precondition for widening is now ruling D16** in the register: four
limbs on `D`, `a1` and `a2` at width 4096 with an int24 residual (three
suffice with int16), never more than four, the remainder window rewritten
(its margin is about one bit at int24 / 4096, and `1 << (32 − NORM_WRHO)`
underflows above 32), the non-unit-coefficient audit re-run, the alias
tampers travelling with the module. Cost: 12 `A` rows, 96 bytes, a new
statement version. The widened profile itself was analysed on paper and by
arithmetic tests only. **`attention.rs`'s R09 is unchanged and still yours.**

### 13:02 — DELIVERED: the native joint-view gate on your captures (branch `zk60-native-jointview`, pushed, tip `f0b181a`)

`scripts/zk60_native_joint_view.py` (one command, about 18 s) with six helper
modules `scripts/zk60_native_jv_*.py`, 22 tests, the record
`results/zk60_native_joint_view/joint_view.json`, and the report
`docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md`. Python only; it reads the four
bundles under `results/zk60_native_captures_20260919/` and touches no Rust and
none of your files. **I ran the gate myself before writing this** (exit 0;
the figures below are from my run as well as the agent's).

- **Stage 1, transcript replay at the real challenges:** every checkpoint and
  every challenge reproduced from the captured public data with BLAKE3 —
  block 80 checkpoints / 1,543 challenges, attention 65 / 1,122; zero
  failures on all four captures; manifest cross-check 4 of 4.
- **Stage 2, A and H together *with* the 256 sampled columns and their pads:**
  disclosed dimension A 0, H 2, input endpoint 0, output endpoint 0, on all
  four. The 2 on H is exactly the public LogUp identity (the spans coincide).
  The columns add nothing because the pad block has full rank on the 231–247
  distinct sampled positions; exact rank check 246 of 246.
- **Stage 3, the masking commitment at captured challenges:** on every slot
  (23 / 18) the mask covers the whole consistency subspace. **One finding:**
  every published M functional lies inside the round span, so the count
  depends on whether a *derived* mask evaluation is an observation. **My
  ruling (report §9a): it is not** — the verifier computes it from `fin_s`,
  `c_s` and the published terminals, so a simulator computes it too; the
  headline is **4 Fp, all public identity**, with 68 / 56 reported beside it.
  Owed and in progress: the per-slot identity asserted in the gate, with its
  lemma, so the accounting rests on a checked fact.
- **Stage 4:** A, H, the endpoints and M stacked = the sum of the parts
  (disjoint randomness). **Stage 5:** a zero-data preimage exists on every
  linear channel with equal fibre dimension; the roots, the 256 salts and the
  paths are **not** covered and rest on the open D8/D11 obligation. **Stage
  6:** every negative control fires (masks removed, shared pair, opened
  twice, extra helper sum, one pad fewer), and altered capture bytes break
  the replay on all four.
- **A discrepancy it found in my own earlier tool:** the seeded block run in
  `results/zk60_private_block_tools/` models the block's H opening with eight
  groups where the receipts and `layout.rs` have nine, so its H figures are
  about a different opening. The A side agrees. This gate supersedes it for
  H; correcting the seeded driver is mine to schedule.
- **Two requests for you, entirely your call** (report §9 question 4): the
  unmasked honest round messages of **one slot on a synthetic fixture**, so
  the zero-witness gate can be exhibited rather than argued; and a capture of
  **one commitment deliberately opened twice**, as a real-receipt negative
  control. Both are labelled test fixtures; neither changes the rule that
  real captures export no witness plane, private pad, mask coefficient or
  RNG state.
- **Not established:** any privacy property (the record keeps
  `privacy_property_established = false`); D8/D11; more than two challenge
  vectors per profile; the adaptive and distributional lift (the
  sequential-kernel lemma's joint hypothesis stays with U-3); integer-range
  side information; timing.

**Correction to my 12:31 note — `fsp-zkhost` is green and mergeable on its
own (tip `e45ebda`, pushed).** Its agent came back when its queued jobs
finished, fixed the doctest it had created (the formula fenced as a `text`
block; documentation only) and re-verified rather than argued: doctests pass,
the zk-v3 byte gate is green on the rebuilt binary, and the full suite is
259 passed / 0 failed across 28 binaries. Its GPU A/B is now complete at 5
runs per arm in alternating order, all ten proofs byte-identical:
**prove 1.149×**, commit W 1.24×, commit A 1.25×, matmuls 1.50× / 1.61×,
openings 1.21×, with the two untouched control phases at 1.01× and 1.03×
[MEASURED, 12 × 512, GPU binary; the block taken under compile load agrees
with the quiet one]. It also notes something useful for anyone gating by
binary hash: a binary's SHA-256 changes across a comment-only edit, so only
the proof-byte gates are a usable identity check. **One thing to expect when
you integrate:** `fsp-mr1` was cut from the older tip and carries its own
comment-only fix for the same doc comment, so merging both gives a trivial
conflict there; I will reconcile the two branches when `fsp-mr1` hands back.

### 12:31 — `fsp-zkhost`'s queued test reported: one red DOCTEST, comment-only; do not merge that branch alone

The fold rung's `cargo test --release` finished with exit 101. Every
functional test binary passed; the single failure is the doctest
`src/zk.rs - zk::fsp_i8fold (line 2381)`: a formula in that function's doc
comment is indented four spaces, so rustdoc compiles it as Rust and chokes
on `[`. No behaviour and no proof byte is involved, but the branch is red as
pushed. **Integrate `fsp-mr1` (which sits on top of it) rather than
`fsp-zkhost` alone:** its agent has been told to fix the comment (a fenced
`text` block) as its first, separate commit and to re-run the full test
suite including doctests and the four frozen digests before anything else.
I will confirm here when that commit is green.

### 12:27 update — the private prover's host port is done; the entry pair you asked for is started; the 5090 goes into a clean Linux desktop

- **`fsp-zkhost` pushed** (branch `fsp-zkhost`, tip `fb850b8`; ledger
  `docs/zkmatrix-poc/ZK60_FSP_ZKHOST_PROGRESS.md`; only `hashline/src/zk.rs`
  and its own results changed). It first settled what the lane is worth:
  **the repaired private feed-forward does run through the body it changed**
  — `zk_ffn_fresh_io.rs:165` → `prepare_layer_zk_v3_inner` (`zk.rs:2337`, with
  `w_data` at `:2416` and `a_data` at `:2476`), `zk_ffn_fresh_poc.rs:104` →
  `prove_layer_zk_v3_inner` (`:2284`); the plan's "zk.rs:925–966" was stale.
  Both ports are in, each behind a switch (`HL_FSP_POOL`, `HL_FSP_I8FOLD`),
  **no digest moved** on CPU, GPU, `HL_ZK_CHUNK` and forced
  `HL_GPU_CHUNK_BYTES`, the rollback arm reproduces the frozen proof from
  one binary, 259 tests. Three places where a straight copy of `layer.rs`
  would have been a byte bug are recorded (rows past the tiled region with
  partial writes; `commit_zk_owned` taking the data by value, so the returns
  go in `PendingV3::finish`; `h_data`'s load-bearing zeros). At 12 × 512 on
  the GPU binary: matmul g/u 1.50×, d 1.62×, commit W 1.24×, commit A 1.19×,
  prove 1.10× [MEASURED, 3 new / 2 old runs, loaded box; the order effect is
  4–5% so both orders were run]; on the CPU binary the matmuls 1.16×/1.25×
  and the prove inside noise. Counted on the recorded 265 s legacy private
  pass: 227–235 s — soft, that pass was paging. **Not ready to merge yet:**
  the fold rung's `cargo test` was queued behind `fsp-host`'s oracle run and
  has not reported; I have a waiter on its marker and will say so here. Owed
  to a larger card: the Mistral-width tamper battery and any 8B A/B.
- **`fsp-mr1` started** (worktree `/home/victor/wt-fsp-mr1`, on top of
  `fsp-zkhost`), to your specification: **one reviewable commit** adding the
  narrow shape-general prover/verifier entry pair for the repaired mask
  profile with **public endpoints**, `zk.rs` only, the legacy default
  untouched, the tiny private-IO entry points left pinned, the four frozen
  digests required not to move, tests that the two profiles cannot be
  confused and that tampers are refused through the new entry. A second
  commit adds an **example** (not `main.rs`) running three arms — public,
  legacy, repaired — at the **12 × 512 shape only**, CPU and GPU, which gives
  the first measured repaired/legacy ratio. The bounded runner and the CPU
  ladder beyond that are yours after integration, as you said; nothing at
  model width runs here.
- **The 5090** (Victor, Telegram 12:16–12:19): it goes into a **separate,
  clean desktop running plain Linux**, disk ≥ 200 GB, 32 GB on the card;
  system RAM not yet known; he will bring it up with me. So **nothing on this
  laptop needs to stop for the install**, the WSL video-memory freeze does
  not apply there, and the private 8B pass will fit. I am having the bring-up
  checklist written (`ZK60_5090_LINUX_BRINGUP.md`: his steps, the agent's
  steps over SSH, the data to copy, the byte gates before any timing, the
  measurement ladder with each projection labelled). If you have views on
  what the first runs there should be, put them in your file and I will fold
  them in.

### 12:15 update — the private path is moving: two lanes on your captures and the norm; the D14 verdict

Thank you for the captures and for integrating `fsp-l9`. You asked for my next
concrete deliveries on the private path; both are now running, sole-writer
Opus agents in their own worktrees from `d399b32`:

1. **Native joint-view gate on your capture bundles** — worktree
   `/home/victor/wt-zk60-jointview`, branch `zk60-native-jointview`. Delivers
   `scripts/zk60_native_joint_view.py` with tests, outputs under
   `results/zk60_native_joint_view/` and the report
   `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md`, in stages that can each
   fail: a BLAKE3 replay of the transcript from the captured public data
   (so the analysis runs at the receipts' **real** challenges, not the seeded
   stand-ins the inventory tools used); the joint A + H view **with the 256
   sampled columns and their pads**; the M view at captured challenges; A, H
   and M stacked; the construction's zero-witness gate, channel by channel,
   with the channels linear algebra cannot cover named as such; negative
   controls that must fire. Python only: no Rust edit, no cargo, no new
   receipts — if it needs a value the captures lack it will say so under
   "questions" rather than regenerate anything, since the writer is yours.
   It will not claim a privacy property and will not touch D8/D11.
2. **The norm range obligation in the private module** — worktree
   `/home/victor/wt-zk60-normrange`, branch `zk60-private-norm-range`.
   Delivers `docs/zkmatrix-poc/ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md` and one
   new `cfg(test)` file in `hashline/src/private_block/` (its only edit to an
   existing file is the line that registers it): the R09 half-p alias
   `D = k + (p−1)/2` built against **this** module's relations for `norm_a`
   and `norm_m`, the catch predicted before it is measured; whether `D` is
   range-proved directly or excluded only by a width coincidence as in
   `attention.rs`; the maximum `D` at width 4096 for int16 and int24
   residuals; every other relation in the block whose exactness rests on a
   width coincidence; and the precondition for widening, with its cost. If
   the alias **verifies** it stops and reports it as blocking.

**D14 memo delivered** (`ZK60_L4_FEWER_HASHED_BYTES_MEMO.md`, `d399b32`;
Victor has the verdict): the lever cannot reach 5 s. Encoding and re-encoding
are 48% of the 58.40 s pass and hashing 0.8%; rate 1/2 buys 1.26–1.32× at the
price of 404 opened columns and a 1.95 GB proof under the proximity rule the
code assumes; a 31-bit field cannot hold the exact integer relations and gives
back most of what it takes; a post-ladder 5090 projects to 8.7–13.2 s with a
7.4–9.2 s ceiling. **Two corrections it forced, both in files you may quote
from:** the "free Merkle cap, −29%" is the compact commitment's figure and is
about 1% on the Ligero-class proof (register D10, the rulings page and the
speed plan are fixed); and new **D15**: "106 bits" is per opening — the
projected whole 8B proof is about 94 (`ZK60_FABLE_SECURITY_OBLIGATIONS.md` §5)
— so model-scale security statements quote the whole-proof figure.

Speed lanes unchanged: `fsp-host` is building the int8-plane commit (about
9 s counted at 8B), `fsp-zkhost` the private prover's host port.

### 11:56 update — the host floor is 18–19 s, not 11.9 s; `fsp-host` pushed and continuing

`fsp-host` (branch pushed, tip `d63e128`; ledger
`docs/zkmatrix-poc/ZK60_FSP_HOST_PROGRESS.md`; source changes only in
`hashline/src/layer.rs` and `hashline/src/gpu/cuda.rs`) committed its
attribution table before any code. **The counter the 8B logs print as "h2d"
is about 72% a host pass, `pack_narrow`** [MEASURED at 12 × 512 with a
default-off `HL_FSP4_TIMING` split; about 84% at 8B, COUNTED], so host work
inside the 58.40 s prove is 18–19 s. Largest item: handing the commitment the
int8 planes directly, about 9 s at 8B [COUNTED], being built now behind a
switch with a new staged-bytes oracle; then the host folds (5.53 s). Built
and green already: the block fold with deferred reduction (byte-identical,
1.21×/1.26× on that item). I added a second correction block to
`ZK60_FIVE_SECOND_PLAN.md` §5: a bigger card alone buys less than that page
said, so the host lane is the prerequisite for the 5090 to pay.
**Owed to you as integrator, from both speed lanes:** pooling the 22 MB
opening buffer reddens `expect_alloc(…, 2, …)` in
`hashline/tests/zk60_gpu_commit.rs`; the row folds in `zkp-core/src/mle.rs`
take the same deferred-reduction treatment (about 0.25 s at 8B).

### 11:53 update — Victor ruled on all six; what changes for each of us

Victor answered on Telegram at 11:50 and the register is updated
(`ZK60_DECISIONS.md`, `fa9b2a3`; pages in `ZK60_RULINGS_FOR_VICTOR.md`):

- **D7 accepted**, with three qualifiers that travel with every claim (salt
  secrecy carries the 32-value toy answer and the model library still accepts
  an all-zero or repeated salt; the image ID depends on the build directory,
  so "locally built, unreproduced"; timing is declared leakage — the scan and
  the cycle check ran for the block program only). **For you:** the two
  Groth16 receipts may now be labelled "zkVM line, private under D3, D4, D5
  and D7"; the approval record for the model digests is the open half and
  cannot be credible before a reproducible build.
- **D13 (new): the hidden blocks are enough for the first MVP**; generating a
  token is the next milestone. **For you:** task A10 and everything
  downstream of an emitted word leave the MVP's critical path.
- **D10 declined** (the compact commitment cannot run privately); the free
  Merkle cap may be built. **D9 accepted as stated**, nothing is re-frozen; I
  corrected the register's wording (the term comes from the prover's mask and
  pad draws, not from challenges; it is a privacy term).
- **D14 (new): write the costed memo** for the fewer-hashed-bytes lever, paper
  only. An Opus agent is drafting `ZK60_L4_FEWER_HASHED_BYTES_MEMO.md`; its
  brief puts the hard question first — a 31-bit field cannot hold the exact
  integer relations that today rely on the 2^49 no-wraparound limit.
- **The RTX 5090 install is a go.** I have asked Victor for the date, the
  machine and its RAM. When he names a window, **both of us push everything
  and stop all lanes first** (`/home/victor/cuda-root` is shared by every
  worktree; the order is driver ≥ 570, then the toolkit, then the feature —
  the runbook records that doing the toolkit first silently took the GPU
  away while the binary still printed ACCEPT).

I see you are integrating `fsp-l9` and fixing the two stale MVP definitions —
thank you. I updated `MVP_STATUS.md` §3 item 4 with the rulings and the
honest speed paragraph (it was clean in your tree when I edited it).

### 11:20 update — the kernel lane is done and it shrank the plan; a host-floor lane started

- **`fsp-l9` is finished and pushed** (branch `fsp-l9`, tip `f0d3481`; ledger
  `docs/zkmatrix-poc/ZK60_FSP_L9_PROGRESS.md`; it changed only
  `hashline/src/gpu/cuda.rs` and `kernels.cu` plus its own results). Floor
  green before and after (202 tests, every `gpu-probe` oracle, the twelve
  byte gates; no digest moved). **Its finding matters more than its gain:**
  on a quiet box the re-encode path at the 8B weight shape is already
  0.095–0.098 s; lane AO's 0.178 s was taken under CPU load. Two of the three
  levers measured **below parity** (0.93×, 0.91×) and were withdrawn behind a
  default-off switch; the producer/consumer **fusion pays 1.162×** at 10,752
  rows. Counted worth on the 58.40 s pass: **0.8–1.8 s, not the plan's 7 s**.
  I corrected `ZK60_FIVE_SECOND_PLAN.md` §5 (`36b0017`): on this card the
  kernels are near their memory roof; the seconds left are the host floor,
  the weight cache, the bigger card and the ruling-sized lever.
  **Ready for you to integrate when convenient.** One change it could not
  make because the file is yours: pooling the 22 MB output allocation turns
  `hashline/tests/zk60_gpu_commit.rs`'s `expect_alloc(…, 2, …)` red.
- **`fsp-host` started** (worktree `/home/victor/wt-fsp-host`, on top of
  `fsp-l9`, one Opus agent): the plan's step 4, the ~11.9 s of host work
  inside the prove. Its first stage is an **attribution table committed
  before any code** — where the host time really goes, measured at 12 × 512
  and counted to the 8B shape, reconciled against lane AL's 11.9 s — because
  this morning showed the plan's counted step sizes cannot be trusted
  untested. It owns `layer.rs`, the host side of the commitment, `wcache.rs`,
  and the GPU files `fsp-l9` has released; `zk.rs` stays with `fsp-zkhost`.
  Small shapes only, heavy lock for every GPU command.

### 11:00 update — zk.rs lane started, six rulings sent to Victor, the private-cost probe scoped

Thank you for the reply and for correcting the headline. Done since:

- **`fsp-zkhost`** (worktree `/home/victor/wt-fsp-zkhost`, from `ad0f50c`, one
  Opus agent, sole writer of `hashline/src/zk.rs`): the staging-pool and
  int8-fold port, each behind a switch, gated by the two zero-knowledge
  digests and the two public ones on both binaries and in the forced-chunked
  form. Your conditions are in its brief word for word. It runs nothing at
  Mistral width; the large-shape tamper battery and the 8B A/B are recorded
  as owed to a window. It shares the heavy lock with `fsp-l9`.
- **`ZK60_RULINGS_FOR_VICTOR.md`** (`e97488e`), sent to Victor at 10:55 as one
  message: the 5090 install (go; power was ruled at 600 W on 2026-09-04), D7
  accept with three qualifiers, proposed D13 (hidden blocks are enough for the
  first MVP) and D14 (commission the costed memo for the fewer-hashed-bytes
  lever), D10 no, D9 accept. I corrected one fact on its D7 page: the secret
  scan and the constant-cycle check *were* run for the block program on the
  hardening lane you are integrating; not yet for the token program.
- **`ZK60_PRIVATE_FFN_COST_PROBE.md`** (`bc5dbe0`, scoping only, no run): the
  repaired mask profile is **already shape-general** (`ZkLayoutV3::with_masks`
  `zk.rs:2002–2054`, the CFS specs `:2149–2174`, the refusals in
  `zk_ffn_fresh_poc.rs:221–341`) but **has no caller** —
  `prove_layer_zk_v3` hard-codes `mr1 = false` (`zk.rs:2280`) and the inner
  functions are private (`:2337`, `:3471`); about 25–45 lines would let it
  run at the 125M shape and at one Mistral layer on either path. Counted
  delta at one Mistral layer, T = 512: **+70 A rows of 3,599 (+1.94%)**, +1 H
  row, W unchanged — structurally the legacy cost plus a few per cent. The
  hiding-endpoint half is another matter: eleven size pins, the worst
  `private_seam.rs:31` `MAX_LOG_LEN = 12` (4,096 words against the 2,097,152
  a Mistral plane needs) and `zk_ffn_fresh_wire.rs:11` `MAX_WIRE_BYTES`
  32 MiB below one Mistral layer's proof; and whether raising the plane cap
  is *sound* is open, because the seam's mask slot grows with the plane —
  that one is mine.

**Proposed next, for your yes or no:** once `fsp-zkhost` hands back, a
follow-on lane on the same branch exposes the repaired mask profile to a
caller as a **new opt-in arm** (no existing default, digest, label or mask
schedule changes; the two zero-knowledge byte gates must not move), then
runs the scoping's ladder from the safe end: tiny anchor, then the 125M shape
on the GPU in three arms on one binary (public, legacy, repaired), then the
CPU. It needs a driver flag; **if `hashline/src/main.rs` or the demo runners
are in your way for the capture writers, tell me and I will keep the flag
inside an example instead.** Nothing at Mistral width without a window we
both agree.

### 10:39 update — the MVP completion plan is in; what I am running and holding

`docs/zkmatrix-poc/ZK60_MVP_COMPLETION_PLAN.md` is committed (`f518910`): the
MVP as 14 acceptance gates with status, the conflicting MVP definitions it
found (for you, as integrator of the shared boards: `LLM_POC_ROADMAP.md:22–23`
still defines PoC-complete in mode P2, which contradicts D1; and
`ZK60_MVP_20260915.md:12` asks for an "attention/FFN boundary equality" that
the accepted no-seam block does not have), the privacy-acceptance path in
order (capture writer → D8 restatement → joint-view tools on real receipts →
block-scope gate → D8/D11 → D9), and 18 deliveries with an owner class each.
Its first lane, the block capture writer, is the one you already took.

Three gaps it names that shape my next work: the built block gives up the
GPU feed-forward prover (the form that keeps it is unbuilt and its privacy
unanalysed); real weights need an int24 residual, which at width 4096 pushes
the norm to three remainder limbs — **the profile with the known half-p
`isqrt` alias, R09** in `ZK60_FABLE_SECURITY_OBLIGATIONS.md` (fix verified
locally on 2026-09-08 as two U16 limbs on `D`, a new statement version, never
committed because `attention.rs` is yours; the private module must range-prove
its `D` directly before it is widened — I will check that it does); and no
privacy statement can start without the capture writer.

**Running under me now, all read-only except the kernel lane:** `fsp-l9`
(above); one-page plain-words rulings for Victor on D7, D9, D10, the
fewer-hashed-bytes speed lever, the token-product question and the 5090
install → `ZK60_RULINGS_FOR_VICTOR.md`; and a scoping of how to measure the
**repaired** private feed-forward at one Mistral-width layer safely on this
box (no run performed) → `ZK60_PRIVATE_FFN_COST_PROBE.md`. **Holding for your
answer:** the `zk.rs` host-fix lane (Ask 2 below) and the 8B re-measurement
window.

### 10:33 update — the speed plan is in, one speed lane is running, two asks for Codex

Thank you for the pickup and for integrating both deliveries; I read your
CURRENT block. Agreed on the split as you restated it.

**The five-second plan is committed:**
`docs/zkmatrix-poc/ZK60_FIVE_SECOND_PLAN.md` (`090ec2a`). I checked its
headline myself in `results/hashline_convert_r3.log`: `PROVE 58.40 s |
VERIFY 1.08 s`, proof `dc980e81..` at 1,234,936,956 B, the arm before lane
AL's host fix 98.54 s on the same box; phases commit W 19.8, openings 17.2,
helpers + H 5.6, matmuls 5.5, zero-checks 5.5, commit A 4.8; device 46.5 s
(transforms 27.7, h2d 8.6, sumcheck 5.5), **host 11.9 s** [MEASURED,
NOISY-SHARED, 2026-09-04, cold weight cache, public IO, FFN only]. Its
verdict, which I accept: four byte-preserving steps take the laptop to about
34 s; a 5090 then gives 10–15 s [MODEL]; under 10 s needs a ruling that
moves every frozen digest (encoding rate and/or field width); **5 s is
outside every recorded assumption, and for a P1-private complete layer the
project's own band is 12–34 s on an H100.** The largest unknown by far is
what the *repaired* private feed-forward costs at width 4096 — every private
second in the repository was measured on the profile later found to
disclose.

**Ask 1 (you hold the file uncommitted, so I will not touch it):**
`MVP_STATUS.md` §2 and `START_HERE.md` still say 95 s and "19× slower". The
true row is 58.40 s, 11.7× from 5 s and 3.9× from 15 s, source as above.
Please fold it in with your next commit, or tell me to once yours is in.

**GPU notice, as promised before any GPU use:** speed lane `fsp-l9`
(worktree `/home/victor/wt-fsp-l9`, one Opus agent, sole writer of
`hashline/src/gpu/{cuda.rs,kernels.cu,mod.rs}` and `hashline/src/ntt.rs`
only) is finishing the re-encode kernels lane AO left (`k_dit_p1_pad_s`,
`k_dif_pb`, the `columns_chunked` host tail). It runs **small shapes only**
(`gpu-probe`, the 12 × 512 fixtures), every GPU command under
`flock /tmp/zk-heavy.lock` with `nvidia-smi` checked idle first, one GPU
process at a time, never an 8B-width or `--zk` pass. If you need the card,
take the heavy lock and it will wait.

**Ask 2 (ownership, before I start it):** the plan's third lane ports lane
AL's host staging pool and the fold-off-the-int8-planes change into
`hashline/src/zk.rs`'s own copy of the v3 prover body (about `zk.rs:925–966`),
byte-gated by `021485e4..` and `40eb5479..`. Your CL lanes have worked in
that file (`HL_ZK_COMPACT_PAD`). It is clean in your tree now. **I will
start it in a worktree at the next tick unless your coordination file says
otherwise**; merges are yours as always.

**Deferred to a window we agree:** the three-arm 8B re-measurement
(defaults, pre-AO switches, warm weight cache; public pass only, 5.2 GB of
the 8 GB card, separate detached launches with the card verified idle
between them). It is best done once, after the kernel lanes land.

### 10:30 — the morning's restart

**Victor's instruction to both loops this morning:** collaborate to finish
the MVP and reach the 5-second-per-proof target. The Fable loop is running
again (self-paced, Opus subagents for the heavy reading and building).

**What I am doing right now** (read-only, no builds, no locks, one new file
each, nothing of yours touched): two inventories, the pattern that produced
the block overnight —
`docs/zkmatrix-poc/ZK60_FIVE_SECOND_PLAN.md` (the true current 8B numbers with
their phase breakdown, every recorded speed lever with what it is worth on
the 8B pass and whether it is built, what a 5090 changes under the project's
own cost model, one ordered plan to 5 s with acceptance checks) and
`docs/zkmatrix-poc/ZK60_MVP_COMPLETION_PLAN.md` (the MVP as a checklist of
gates, the distance from the tiny block to a model, the privacy-acceptance
path, one ordered plan). I will fold them into one plan here within about an
hour and mark each delivery with a proposed owner.

**One thing I noticed that you may want before then:** `MVP_STATUS.md` and
`START_HERE.md` do not carry the 2026-09-04 lane-AL result (the 8B public-IO
GPU pass at 58.40 s after the host allocation fix, per my ledger notes); the
status page still says 95 s and "19× slower". The speed inventory is
confirming the figure and its log path before I change the page.

**Proposed split until the integrated plan lands — say so in your
coordination file if you want it otherwise:**

- **Codex (you own code integration, the zkVM line, the runners, the heavy
  queue):** commit your hardening integration (my response, with one new
  low-severity gap N-1, is on `zk60-zkvm-hardening` at `c054eb1`) and your
  attention integration; then integrate `zk60-private-block` (`98a5db9`:
  new files plus one line in `hashline/src/lib.rs`, a dev-dependency in
  `hashline/Cargo.toml`, one constant in `hashline/src/tables_attn.rs`; its
  ledger has the exact build and test commands); the schema-3 capture
  writer for the attention profile and then the block profile; relaunch the
  ceremony check that died with `/tmp` in the 01:04 restart; the token-model
  hardening items of §3f. The `(-3, -3)` fixture fix on the attention
  component is yours, as agreed.
- **Fable (security owner):** the two plans above; then the construction
  work they expose (I expect: how a private block keeps the GPU
  feed-forward prover at 8B widths, i.e. the equality-seam form deferred in
  the block construction memo §B.2, and how blocks chain under D12); the
  D8/D11 restatement; review of whatever you land.
- **Shared-box rule, unchanged:** every cargo call under
  `/tmp/zk-build.lock`, every run over about five minutes detached under
  `/tmp/zk-heavy.lock` with a `.done` marker; **no GPU run while another GPU
  run is live** (an 8 GB card that runs out of video memory freezes the
  whole box). I will not start any GPU or heavy run without writing it here
  first.

## 1. Round 2 of the MVP security decision (2026-09-15) — answers the "next acceptance gate" of `ZK60_MVP_REVIEW.md`

Memo: `docs/zkmatrix-poc/ZK60_MVP_JOINT_VIEW.md` on the branch. It does **not**
repeat the two rejected round-1 claims; it rules the opposite way on both:

- the caller-fixed external-root obligation **stays** and is met by a
  simulator that programs exactly one random-oracle point per endpoint root
  (two per proof) in the programmable-ROM model Fiat–Shamir already assumes;
  the joint-preparation workflow programs none;
- the adaptive lift is a lemma whose hypothesis is the **joint** law of every
  field value at fixed challenges; the round-1 marginal evidence did not supply
  it, and Codex's `H(mask), mask ⊕ w` counterexample violates the hypothesis,
  not the lemma.

Executable: BLAKE3 transcript replay of the four round-22 receipts (every
captured checkpoint matches; the six FFN slots' challenges recovered), the
joint PCS-side view **with opened columns** (disclosed = O8's numbers exactly),
the joint CFS/M-opening view at captured challenges (honest disclosed 0),
the root simulator bookkeeping, and the sequential-kernel lemma checked
exhaustively on finite models. One-command gate
`scripts/zk60_mvp_joint_view_gate.py` (10 stages, all passed; record under
`results/zk60_mvp_joint_view_evidence/`).

## 2. Private attention construction (2026-09-16) — A1–A4 for the custom-PCS path

Memo: `docs/zkmatrix-poc/ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md`; schedule
`zk60_private_attention_schedule.json`. Six private claimed sums via masked
scalars hosted by ν-batched zero-checks (the FFN's gu/ZC20 form), QKV slot
split by domain, one zero-sum row for the nineteen helper sums, histograms
committed, eighteen mask slots / 40-row M, hosts after hosted slots. Rank
tool (whole A/H/W disclosed 0, H = public identity only; 33 tests) and CFS
tool (18 slots, 5 host groups; 97 checks, 14 tests). Row cost ≈ 77 MB at
A00, dominated by the two 65,536-entry tables.

## 3. Disposition of the zkVM construction review (2026-09-18)

`docs/zkmatrix-poc/ZK60_ZKVM_REVIEW_DISPOSITION.md` on the branch: every
[RECALLED] item of the headless review's §15 checklist verified in the local
risc0 3.0.x source (fetched 2026-09-18 08:17), with corrections: the guest
toolchain and crates are present; Docker is absent; a CUDA Groth16 path
exists but its rzup component is not installed; the rv32im segment prover
adds no blinding rows (composite receipts are never public, as a fact); the
target is exactly 97 bits conjectured at 2^20 segments. Ruling: sound as a
functional intermediate with Groth16 receipts, under three rulings for
Victor (sub-128-bit deviation, trusted setup, prover path) and a new
endpoint/weight identity profile.

## 3a. Source review of `zkvm-block/` (2026-09-18, evening)

`docs/zkmatrix-poc/ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on the branch:
guest, statement, model, host, wrap and the security calculator read line
by line against D5 and the disposition. Verdict: consistent, no defect;
eight hardening items (host should scrub `RISC0_DEV_MODE` itself; wrap
should pin the native tool hashes; default to removing the private work
directory after a verified wrap; add the P1 secret-scan and P3
constant-cycle evidence; label the image ID unreproduced; keep segments at
or below 2^20; add a D4 claim-shape regression). D7 remains Victor's.

## 3b. First Groth16 receipt verified; evidence retained (2026-09-18 19:18)

The security owner re-verified `demo-public/groth16.bin` (785 bytes) in a
fresh process: `{"verified":true,"kind":"groth16"}`. Public artifacts were
copied to `results/zk60_loop_20260918/block-integration/groth16_public/`
(no private files) because `/tmp` evidence does not survive a reboot. D6 is
closed in the register. For Codex: the eight hardening items of §3a are the
suggested next hardening pass; the P1 secret-scan and P3 constant-cycle
evidence are the two cheapest. `MVP_STATUS.md` now carries the plain-words
status Victor asked for; please keep it current when your loop lands news.

## 3c. Token-model build failure diagnosed (2026-09-18 19:23 markers)

`token-build.done` and `token-proof.done` are both `1`. The build launcher's
stage `token-host-build` runs
`cargo build --release --offline --locked -p zk60-token-host -p zk60-token-wrap --examples`;
with `--examples` cargo builds only the example targets of those packages,
so `zkvm-block/target/release/zk60-token-host` is never produced (the
stage "succeeds" in 0.11 s), the launcher then fails with
`FileNotFoundError` on that path, and `token_prove.py` refuses to start.
Fix: `--bins --examples` (or drop `--examples` from that stage and build the
example packages separately, as `token-export`/`token-rust-vectors` already
do). Everything before it passed (workspace tests 82 s, export, Rust and
Python vectors agree on all three digests).

## 3d. Hardening lane `zk60-zkvm-hardening` (from db021ba) and a reproducibility finding

Opus agents under the security owner implemented the review's items on a
lane branched from Codex's checkpoint: runner `secret-scan` stage (61
tests), host environment scrub plus executor cycle/segment reporting, the
P3 constant-cycle gate with a real executor run (nine inputs: padded total
cycles and segment count identical, user cycles vary by 17,610 = 0.27%,
declared as host-side timing leakage only; record under
`results/zk60_zkvm_hardening/cycle_gate/`), and wrap-side additions
(the checkpoint already pinned the tool hashes in `zkvm-native-tools`, so
the lane adds a `check-tools DIR` subcommand, a test that the linked pins
equal `groth16-native-files.json`, default removal of the private work
directory after a verified wrap with `--keep-work` to retain it, and
claim-shape regressions for Paused, non-empty assumptions and wrong
verifier parameters, with the check ordering documented). **Lane pushed:
`zk60-zkvm-hardening`, four commits.** Verified by the security owner: host
6 tests, wrap 8 tests, runner 61 tests, cycle gate 12 tests, real
`check-tools` on the extracted tools. Two contract notes for integration:
(a) the runner now passes `--keep-work` (it owns the private tree); a hand
run of `wrap` removes the work directory on success; (b) the host refuses
`RISC0_*`/`BONSAI_*` switches loudly before scrubbing `RUST_LOG*`, so the
refusal semantics of the checkpoint are preserved. Known box quirk hit
again: the toolchain-directory cargo fails on the `ff` crate with
`Unrecognized option: 'check-cfg'`; the `~/.cargo/bin/cargo` shim works.

**Finding for the approval record:** the guest image ID is
build-path dependent. Every guest-affecting source on the lane is
byte-identical to the checkpoint, yet `image-id` prints
`c5a04b83448eb2a17919e38a9a00db7edfab4bdc979800ee867be11f5dc295a5`
instead of `8d74aab3…98d9`, because the guest ELF embeds one absolute
source path (`private-block-kernel/src/lib.rs`) and `risc0-build` 3.0.6
applies no path remap outside its Docker mode. Consequence: the approved
image ID is reproducible only from `/home/victor/IntelligenceRegulation`
or a reproducible build; the README's "locally built, unreproduced" label
now has a concrete cause, and a registry entry should pin the build path
or move to the Docker build before any approval.

## 3e. Native private attention delivery: compile pass and R-1/R-2 reviews in progress (2026-09-18, late evening)

The headless attention lane's delivery (`/tmp/wt-zk60-attention-fable-20260918`,
uncompiled: cargo was denied there) has been copied unchanged onto lane
`zk60-attention-compile` (from db021ba). Three Opus agents under the
security owner are running there: (1) compile and run its own tests and
example with the smallest fixes and no design change (design-level
failures are reported, not patched); (2) its review request R-1, the
pair-schedule rank and CFS slot checks regenerated on the layout it
actually declares (306/290 rows, 75/35 sites, 18 slots); (3) its request
R-2, the no-wraparound bounds, isqrt/softmax exactness and the
extension-round premise per slot. **Done and pushed (`zk60-attention-compile`, three commits):** the delivery
compiled with zero fixes; 11 unit + 4 integration + 1 doc tests pass; the
example proves in 0.09 s (2,245,800-byte receipt) and verifies in a fresh
process with three refusals; R-1 regenerated on the declared layout gives
disclosed 0 on A, every group and each endpoint, H residual = the public
identity, all 18 slots and 5 host groups pass the CFS criterion, 11 rank
and 7 CFS negative controls fire, and every derived count matches the
note (29/29); R-2 holds (all bounds < 2^49, exact limbs, isqrt/softmax
pinned, extension premise mechanically verified) with eight cosmetic flags.
Disposition: `ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md` accepts the
deviations (single U8 table, degree-4 softmax, no W under P1, module-local
rows, extra refusals) as the experimental component; it is not a block
(norm_m, FFN seams, residual 2 remain) and not whole-proof privacy. Codex:
integrate, the three cosmetic follow-ups, and a schema-3 capture writer so
the round-2 joint tools run on its real receipts.

## 3f. Box restart 2026-09-19 01:04: what survived, what was lost, what is running

The WSL box restarted at 01:04:46 (both loops died with it; Codex was back
at about 01:05). Checked by the security owner at 01:06–01:10:

- **Git is intact.** No zero-byte objects, `git fsck --no-dangling` clean,
  `core.fsyncObjectFiles=true` still set. Main-tree tip `063566a` and the
  lanes `zk60-zkvm-hardening` (`12341e6`), `zk60-attention-compile`
  (`ea81815`) and `zk60-mvp-fable` (`2b7f5eb`) all equal their remotes.
  Codex's uncommitted main-tree edits are still on disk, untouched by me.
- **Retained evidence survived**: both Groth16 public bundles under
  `results/zk60_loop_20260918/` (block and token), and the binaries that
  produced them (`zkvm-block/target/release/zk60-{block,token}-{host,wrap}`,
  built 19:36–19:37).
- **Lost with `/tmp`** (for Codex, who owns these): the whole loop scratch
  directory `/tmp/zk60-loop-20260917/` — the task files, logs and every
  `.done` marker in it, the queued `prepare_ceremony.py` (PID 297871) and
  `verify_ceremony.py` (PID 318776) jobs and any ceremony downloads made so
  far, so **no ceremony check ran and its queue must be relaunched**; and
  the two `/tmp` worktrees. The headless attention worktree had already
  been copied onto `zk60-attention-compile` and pushed, so nothing of it is
  lost. The Opus private-profile worktree
  (`zk60-private-profile-opus-20260918`) had **no commit beyond `db021ba`**,
  so whatever it had written is gone and that task restarts from zero.
  Both branches still exist locally at `db021ba`; their worktree entries
  are prunable.
- **Running now under the security owner (three Opus subagents, read-only,
  no builds, no heavy lock, one new file each, orchestrator commits):**
  (1) the review Codex asked for of the token receipt profile and source
  pins, the token-model twin of §3a, plus a fresh-process re-verification of
  both retained receipts with the surviving binaries →
  `ZK60_ZKVM_TOKEN_SOURCE_REVIEW_FABLE.md` on `zk60-mvp-fable`;
  (2) a response to `ZK60_HARDENING_INTEGRATION_REVIEW.md`: each of its six
  findings checked against the delivery and against Codex's current
  working copies, and a check that integration dropped nothing →
  `ZK60_HARDENING_INTEGRATION_RESPONSE.md` on `zk60-zkvm-hardening`. I am
  **not** patching those findings on my lane, so there is one writer
  (Codex) for the corrections;
  (3) a gap inventory for composing the native attention with the repaired
  FFN into a complete private block (norm_m, the two seams, residual 2,
  the schema-3 capture writer), with the D8/D11 endpoint-reuse obligation
  stated per seam and not declared solved →
  `ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md` on `zk60-attention-compile`.

**Delivered 01:22 — response to the hardening integration review** (pushed,
`zk60-zkvm-hardening` at `c054eb1`,
`docs/zkmatrix-poc/ZK60_HARDENING_INTEGRATION_RESPONSE.md`; snapshot of
Codex's working copies taken 01:15). All six of Codex's findings are
correct. F1 (`--keep-work` per profile), F2 (inner-seal wording), F3 (saved
bytes reread and verified) and F6 (cycle counts as private telemetry) are
soundly corrected in the working copy; nothing the delivery provided was
dropped or weakened (refusal before scrub, no refused value printed, tool
pins on both paths, cleanup semantics, the three claim-shape tests,
Groth16-only with dev mode off). Withdrawing the secret-scan record from the
public `outcome.json` is right: deduplicated needles would leak
value-equality. Still open, for Codex as the one writer: **F4** the README
still describes blanket retention (draft text is in the response); **F5**
the control that alters only the journal of a valid recorded outer receipt
is still to write; **F6** the recorded evidence under
`results/zk60_zkvm_hardening/cycle_gate/` (`README.txt`, the JSON's
`declared_leakage`) still carries the wording the script no longer uses.
**One new low-severity gap, verified by me in the source (N-1):**
`zkvm-block/wrap/src/main.rs` writes the public receipt at line 176 and only
then rereads and verifies it (179–180). If that readback fails, the
unverified file stays in the public directory, the `output already exists`
guard at the top of `wrap()` blocks a retry, and `kept_work` names only the
work directory. Suggested form: write to a temporary name in the same
directory, reread and verify, then rename; also add the byte-equality
comparison the token wrapper already has (`zkvm-model/wrap/src/main.rs:214–216`).
Snapshot tests: runner 62 pass, cycle gate 14 pass; no Rust tests were run,
so the binaries behind the live receipts are untouched.

**Delivered 01:27 — composition gap inventory for a complete private block
on the custom line** (pushed, `zk60-attention-compile` at `c2e010e`,
`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md`; read-only, no
build). Fifteen gaps, each classed as engineering (Codex can build to an
existing design), construction decision (security owner) or ruling. The
attention output endpoint and the FFN input endpoint have identical
geometry (7 × 256, mask pair rows 2–3, one opening group, same PCS
parameters) but can never be the same object, and rightly so. Two code facts
I re-checked in the source: **the FFN proves no range on its hidden input**
(`hashline/src/layer.rs` lookup list: `g8/a16`, `u16`, `h16`, `z/rd`, never
`x`), so the missing second norm is load-bearing for soundness, not only for
completeness; and **the attention fixtures declare endpoint scales
`(-3, -3)`** (`hashline/tests/zk60_private_attention.rs:17`,
`hashline/examples/zk60_private_attention.rs:36`) where the approved
calibration has `e_r = e_r1 = 0` (`causal_oracle.rs:115–118`). The central
finding: every "obvious" seam (share one endpoint commitment between two
proofs) is the double-opening configuration D11 records as recovering all
512 hidden words. **Recorded today as D12** in the decisions register: one
proof, one transcript, two external endpoints, no commitment opened twice,
hidden intermediates only on prover-generated commitments, the second norm's
int8 range proof mandatory, endpoint scales tied to the calibration.
Restrictive only; D8/D11 stay open for the two external endpoints.

*Codex, unblocked now (no dependency on my next memo):* the schema-3 capture
writer for the attention profile (inventory step 2, gap G6); the fixture
scale fix plus a test that fails when `IoSpec` disagrees with
`causal_oracle` (step 3, G11; today's `(-3, -3)` must fail it); the
interface requests P-1/P-2/P-3 (G14); kernel parity as a dev-dependency
(G13). *Waiting on me:* the block construction memo (seam form, grown
layout for `norm_m` and residual 2, the joint transcript order label by
label, the pending/manifest role list, slot-tag namespace). An Opus draft
is being prepared for my review as
`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` on `zk60-attention-compile`; it is a
draft until this file says it is accepted.

**Delivered 01:29 — the review Codex asked for of the token receipt profile
and source pins** (pushed, `zk60-mvp-fable` at `25b589c`,
`docs/zkmatrix-poc/ZK60_ZKVM_TOKEN_SOURCE_REVIEW_FABLE.md`; the token-model
twin of §3a; source read only, no build). Verdict: consistent with D5 and
the disposition, **no code defect**; D7 untouched. **Both retained Groth16
receipts re-verified in fresh processes after the restart** with the
surviving 19:36–19:37 binaries: token
`{"verified":true,"kind":"groth16","coverage":"synthetic-T32-V32-two-block-greedy-token"}`,
block `{"verified":true,"kind":"groth16"}`; each profile's verifier refuses
the other's receipt on the policy tag. `token_public/SHA256SUMS` all match.
For Codex:

- **Evidence-record defect (I re-checked the hash):**
  `results/zk60_loop_20260918/token-integration/token-build-source.json`
  records `zkvm-model/wrap/src/main.rs` as `7f9780…` but the committed file
  the 19:37 binary was built from is `80139fe9…` (the hash-pinned-tools
  wrapper); 4 of its 36 entries are stale (also `wrap/Cargo.toml`,
  `Cargo.lock`, the README). Every guest-affecting file matches, so the
  image binding of the receipt is unaffected; the record simply describes a
  weaker wrapper that was never used. Regenerate it from the committed
  sources and keep the old one beside it, labelled.
- **Hardening, in my order of value:** the token wrapper never removes the
  private work directory holding the inner STARK witness, which the block
  wrapper now does (`zkvm-model/wrap/src/main.rs:165–216`); the token host
  prints no cycle or segment counts, so D3's segment limit rests on source
  (`host/src/main.rs:168`, po2 18) and the cycle gate cannot run for the
  token profile; `model/src/lib.rs:125–130` accepts all-zero or equal salts
  although the output space is only 32 values, so a weak salt makes the
  output digest guessable (honest runs draw fresh salts; this is input
  validation); nothing checks `model.bin` against the policy's model digest
  (recomputed by hand, it matches); the retained run's eleven controls
  included block-refuses-token, which the maintained runner's thirteen lack.
- **Build-path dependence, stronger than for the block:** the token guest
  ELF embeds two absolute repository paths and fourteen `$HOME` cargo
  paths; `risc0-build` 3.0.6 applies no remap outside its Docker mode. The
  pre-approval item of §3d applies to the token image ID too.

**Block construction memo: draft received, interim disposition (01:54).**
(Times in this section are commit times; four earlier entries here carried
estimated times up to an hour ahead and were corrected at 01:56.)
`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` on `zk60-attention-compile` (`0795c6c`)
is a delegated Opus **draft, not accepted; please do not build from it
yet.** What I have reviewed myself (§B, §C.2, §C.5, §H.3) and my position:

- **Agreed: build the single shared layout first** (the draft's form S).
  The native attention component grows into the whole block; `nm` is one
  plane read by two relations; there is no seam, no second `M`, no second
  transcript, no composed wire frame, so D12 is met with no new privacy
  machinery. The equality-seam form is documented with its cost, and is what
  8B will probably need because it is the only form that keeps the
  block-decomposed GPU feed-forward prover; the two measurements that would
  force it (peak resident bytes, host versus GPU feed-forward time at the
  125M rung) are named, not assumed. `norm_m` and residual 2 live in the
  attention-side component; the output endpoint carries `xres2`; `z16` and
  `nm` are never external endpoints.
- **Consequence for the two existing components:** used as block halves
  as they are, both violate D12 item 3 — the attention output endpoint
  commits `xres1` (`private_attention/argument.rs:757`) and the FFN-IO output
  endpoint commits `z16` (`zk_ffn_fresh_io.rs:284`), caller-fixed roots on
  hidden intermediates. They remain valid standalone experimental
  components; they are not block halves.
- **Condition I am adding, which the draft does not state:** its "Tier 1"
  (attention + `norm_m` + residual 2) carries `z16` as a plane that nothing
  ties to `nm`, because the feed-forward relations are only estimated
  ("Tier 2"). A Tier-1 artifact would let the prover choose the block's
  output. **Nothing may carry the block profile string, or be called a
  block, until the feed-forward relations bind `z16` to `nm`.** The tripwire
  is written first: tamper `z16` consistently (keep `xres2 = xres1 + z16`
  and every class proof satisfied) and require the verifier to reject; in a
  Tier-1-only build that test fails, which is its purpose.
- **Provisional, pending the tools:** hosting both sum-of-squares slots in
  `SC_TZC` (k = 2), the second `Dom::L` plane with `SC_LZC` at degree 4, and
  the slot renumbering all change what the rank and slot checks assert; the
  accepted R-1/R-2 verdicts do not transfer.
- **Correction to the gap inventory, from the draft:** G8 is not "absent".
  `private_attention/protocol.rs:84–127` already refuses an unconsumed or a
  shared reserved pair on both sides; what is missing is a named role list.

Two Opus agents are running on the same lane, one new file each: an
adversarial check of the sections I have not read (§C.1, §C.3, §C.4, §D–§G:
counts re-derived from source, `norm_m` and residual-2 no-wraparound bounds,
transcript order against `protocol.rs`, tag-namespace freedom, and the rank
and slot tools run on a paper schedule if they can work from a description)
→ `ZK60_PRIVATE_BLOCK_CONSTRUCTION_CHECK.md`; and the precise Tier-2
feed-forward design → `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2.md`. Acceptance
follows both.

**Block construction, state at 02:24 (still NOT ACCEPTED; please do not
build from it yet).** On `zk60-attention-compile` at `498dd60`:

- `ZK60_PRIVATE_BLOCK_CONSTRUCTION_CHECK.md` — the independent check of the
  Tier-1 draft. The accepted counts reproduce, by hand and by the unmodified
  inventory tool (29/29). **Every grown count is confirmed**, and the two
  group counts the draft estimated are now derived (A 31, H 8). Decisions 6,
  7 and 8 are sound; one zero-check hosting two slots already has three
  precedents in the accepted layout (`SC_QZC`, `SC_KVZC`, `SC_SZC`). The
  `norm_m` no-wraparound bounds are identical to `norm_a`'s because `xres1`
  is enforced int16 by the same two-limb proof as `x_in`. **The rank and
  slot tools were run on the paper Tier-1 schedule** (driver and outputs
  under `results/zk60_private_block_construction/`; I read the summary file
  myself): every A group, every H group and both endpoints disclose 0, whole
  H's residual is exactly the public identity as on the accepted layout,
  the grown `SC_TZC` has ΣL 84, rank 81, kernel 3, leaked 0, all 19 slots
  pass the length criterion, every negative control fires. These are
  verdicts on a paper description, not on code, and the tools' models
  exclude what they excluded before (sampled columns, salted Merkle paths,
  the CFS channel, transcript conditioning, A↔H correlation). **Blocking
  finding B-1 confirms my condition and states it more strongly:** with Tier
  1 alone `A_Z16` has no lookup and one relation, so for any int16 `xres2` a
  witness exists; the statement is vacuous on its output, and nothing in the
  draft gates the block profile, `BlockPublic` or the output endpoint's move
  to `A_X2` on Tier 2. Eleven corrections, none changing the design.
- `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2.md` (`f8ff98f`) — the feed-forward
  half designed precisely in the attention module's idiom: five relations
  with the kernel's biased requantization identity; the gate output's class
  is `[-128, 127]`, not the symmetric one (using the symmetric lookup would
  be a completeness bug); the activation lookup on the pair
  `(g8 + 128, a16)` joins `SC_TAB` as a third triple and also gives `g8`'s
  and `a16`'s classes (I checked that reasoning: table membership under a
  combination drawn after commitment forces both); `SH_U = 0` removes the up
  remainder; four new slots (`SC_GMM`, `SC_UMM` hosted by a new `SC_FZC`;
  `SC_DMM` hosted by `SC_DZC`). Whole-block totals, as drafted: A 455 rows,
  H 384, sites 120/51, 23 slots, 50 `M` rows, 34 functionals, receipt about
  2.82 MB. Tamper tests for `z16`, `g`, `a`, `u`, `h` with the relation that
  catches each.
- **Running:** the independent check of Tier 2, including the tools on the
  whole-block paper schedule and one consolidated errata list for both
  drafts → `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md`. My disposition
  follows it.

**Block construction ACCEPTED AS THE DESIGN TO BUILD (03:01).** On
`zk60-attention-compile` at `e5962d2`:
`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` is my
ruling on the construction memo, the Tier-2 feed-forward design and their two
independent checks. Not a privacy acceptance; D8/D11 open for the block's two
external endpoints; no speed claim.

- **The Tier-2 check** (`…_TIER2_CHECK.md`, `1cf9ba7`): the Tier-1 tool outputs
  reproduce byte for byte; **no feed-forward plane is free** and seven
  attempts to build a consistent tamper of `z16` were defeated; every count
  confirmed (A 455 / H 384 rows, sites 120/51, 23 slots, six host groups, 50
  `M` rows, 34 functionals, opening groups A 35 / H 9, receipt 2,816,472
  bytes); the tools on the **whole-block** paper schedule: every group and
  both endpoints disclose 0, H's residual exactly the public identity, every
  host group kernel 3 and leaked 0, all 23 slots within `L + 256 ≤ 512`, all
  18 negative controls fire. One new blocking finding, which I re-checked in
  the source: the activation table's int16 value range was enforced by
  nothing in the proof's own public statement (the draft cited the kernel
  crate's type); `BlockPublic::new` must refuse out-of-range values as
  `private_attention.rs:97–99` does for the exp table. One consolidated list
  of 22 errata, all made binding.
- **Two rulings of mine that matter to Codex.** **R-A: the block is a new
  module** (`hashline/src/private_block.rs`, `hashline/src/private_block/`),
  grown from a copy of the attention module; **the accepted attention
  component's files are not edited from my lane**, so its receipt, tests and
  R-1/R-2 records stay valid and your integration of it in the main tree gets
  no collisions. **R-B:** the new profile string
  `hashline-zk-mr1/private-block-t32-poc/1` and parameters payload are
  accepted; renaming the per-slot labels is not required.
- **Conditions on the build** (disposition §3): the tripwire test
  `block_output_cannot_be_chosen` first, and the block profile lands only in
  the commit that contains the feed-forward relations; the activation range
  check; the tools re-run on the real Rust with all controls firing plus two
  owed ones; endpoint scales pinned to the calibration; kernel parity
  including the refusal site.
- **Running:** an Opus editor applying the 22 errata and the two rulings to
  the two memos, so an implementer reads corrected text. **Next from this
  lane:** the implementation on a new lane off `zk60-attention-compile`, new
  files only, tests first, builds under the shared build lock. Codex: if you
  would rather own that implementation or assign its writer yourself, say so
  in your coordination file and I will hold it; otherwise I start it once the
  corrected memos are committed. The `(-3, -3)` fixture fix on the attention
  component stays yours.

**Block implementation lane opened (03:22).** The corrected memos are
committed (`zk60-attention-compile` at `58f6150`: errata E-1 … E-22 and
rulings R-A/R-B applied, both marked accepted as the design to build, T1
§C.5 marked superseded by the Tier-2 design). No reply from Codex in the
coordination file, so as announced the implementation has started:
worktree `/home/victor/wt-zk60-private-block`, branch `zk60-private-block`
(local until its first reviewed push), one Opus agent as **sole writer**.

- **Files it may create:** `hashline/src/private_block.rs`,
  `hashline/src/private_block/`, `hashline/examples/zk60_private_block.rs`,
  `hashline/tests/zk60_private_block.rs`, and its progress ledger
  `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_IMPL_PROGRESS.md`. **Existing files it
  may edit:** one `pub mod private_block;` line in `hashline/src/lib.rs` and
  a dev-dependency on `private-block-kernel` in `hashline/Cargo.toml` (Codex:
  these two are the only places a merge with your P-3 work could touch).
  Nothing under `private_attention*`, `zk.rs`, `layer.rs`,
  `zk_ffn_fresh_io.rs`, `private_seam.rs`, `scripts/` or the Python suite.
- **Stages.** S0 scaffold (a faithful copy under a work-in-progress profile
  string, every digest domain changed, the accepted attention files proven
  byte-identical); S1 tests first (witness parity against
  `private-block-kernel::run_block` over at least 1,000 generated inputs
  including the kernel's refusals); S2 witness and layout growth to the whole
  block (A 455 / H 384 rows asserted). Then, by a following agent: S3 the
  argument's new arms and the tamper tests; S4 the block profile,
  `BlockPublic` with the activation-table range check, the output endpoint's
  move to `xres2` and the tripwire, all in one commit; S5 the rank and slot
  tools on the real source. The final block profile string is forbidden until
  S4.
- **Box discipline:** every cargo call under `flock -w 540 /tmp/zk-build.lock`,
  offline, `-j 2`, the rustup shim, sharing the design lane's warm target
  directory; no heavy lock, no GPU, no benchmark, nothing over a few minutes.

**Block implementation, stages S0–S2 done and pushed (04:07).** Lane
`zk60-private-block` at `a882bd1` (now on the remote); ledger
`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_IMPL_PROGRESS.md`. Checked by me, not
only reported: the accepted attention files, `zk.rs`, `layer.rs`,
`zk_ffn_fresh_io.rs`, `private_seam.rs`, `scripts/` and the Python suite are
byte-identical to `zk60-attention-compile`; the lane added only new files
plus one line of `hashline/src/lib.rs` and the `private-block-kernel`
dev-dependency (`Cargo.toml`, `Cargo.lock`); my own run of
`cargo test --release --lib private_` gave **27 passed, 0 failed**.

- S0: the new module is a faithful copy under the work-in-progress profile
  `hashline-zk-mr1/private-block-t32-wip/0`; every digest domain, magic and
  slot label forked so no transcript is shared with the accepted profile.
- S1: a fixed-seed sweep of 1,200 public synthetic cases against
  `private-block-kernel::run_block`.
- S2: the witness and layout grown to the whole block behind a second
  constructor (`Layout::new_block()`: A 455 / H 384 rows, 23 slots, 50 `M`
  rows, sites 120/51, groups 35/9, 61,440 byte lookups, all asserted in
  code). **Whole-block witness parity holds**: every plane, including `nm`,
  `g8`, `a16`, `u16`, `h16`, `z16`, `xres2`, the limbs and the three biased
  requantization identities, equals the kernel element for element; 905
  cases accept, 295 refuse at the identical site with the identical message,
  nine refusal sites reached. The argument, the profile and the output
  endpoint are untouched, so nothing yet claims to be a block.
- My two answers in the ledger: hand-built cases for every reachable refusal
  site, unreachable ones documented with their bound; the activation table
  stays `[i16; 256]` and must enter the statement digest when `BlockPublic`
  lands.
- **Running:** the next Opus agent, same lane, sole writer: S3a the
  refusal-site cases, S3b the argument's new arms on the whole-block layout
  (honest proof must verify; receipt expected at 2,816,472 bytes), S3c the
  tamper tests caught at the verifier, S4 the block profile with
  `BlockPublic`, the endpoint's move to `xres2`, scale pinning and the
  tripwire, in one commit. It may add exactly one constant (LogUp tag 134) to
  `tables_attn.rs` if the design requires it there; nothing else existing.

**The complete private block proves and verifies on the custom line (05:14)
— experimental, under review.** Lane `zk60-private-block` at `a5e8010`
(pushed). Stages S3a–S4 by the second Opus agent; then **checked by my own
runs**, recorded in `results/zk60_private_block_evidence/README.md` on the
lane with the public receipt and endpoint policy retained:

- accepted files byte-identical; the lane's only edits to existing files are
  the module export in `lib.rs`, the dev-dependency in `Cargo.toml`, and one
  constant `TAG_ACT = 134` in `hashline/src/tables_attn.rs` (Codex: a third
  possible merge point with your tree);
- `cargo test --release --lib private_`: **38 passed, 0 failed**; integration
  4 passed; the example proves the whole block under the final profile
  `hashline-zk-mr1/private-block-t32-poc/1` (A 455 / H 384 / M 50 rows, 34
  functionals, groups 35/9, lookups U8 61,440, exp 2,048, act 512), **receipt
  2,816,472 bytes, the design's exact figure**, prove 0.095 s, fresh-process
  verify 0.043 s, three corruptions refused [diagnostic timings, shared box];
- I read the tripwire's source: `z16` tampered by one with `xres2` and both
  limb pairs recomputed, the endpoint owner committing the chosen output so
  the endpoint cannot be what rejects, a real receipt built, the verifier
  rejecting at the down-requantization slot, the honest path asserted beside
  it. Nine tamper tests in all, each caught at the verifier by slot index or
  by the LogUp sum claim.
- One ruling: the calibration digest is a literal pinned to
  `causal_oracle`'s registration by a test; accepted for the proof of
  concept, to become a statement field when a second calibration exists.

**Not accepted as a block yet, and nothing about privacy is claimed.**
Running now, in parallel, on the lane: **S5**, the rank and slot tools pointed
at the real Rust source with the two owed negative controls and a Python test
module (condition 4 of the disposition); and **an independent adversarial
code review**, read-only, told to assume nothing is right, to confirm in the
code that every new plane is pinned, that each relation is the kernel's, what
the statement digest absorbs, the Fiat–Shamir order, and to try to construct
a false witness the verifier accepts →
`ZK60_PRIVATE_BLOCK_CODE_REVIEW.md`. My disposition of the implementation
follows both. Codex: when you integrate, the block module is self-contained
(new files) and the schema-3 capture writer for its profile can follow the
attention one.

**Block implementation: tools on the real source pass, code review clean of
blocking findings (05:49).** Lane `zk60-private-block` at `3fc5d11` (pushed).

- **S5, condition 4 of the disposition**
  (`scripts/zk60_private_block_inventory.py`,
  `tests/test_zk60_private_block_inventory.py`,
  `results/zk60_private_block_tools/`; I ran the test module myself: 29 OK).
  The driver first reproduces the accepted attention verdict with the
  committed tool unmodified (29/29). On the **real Rust** of
  `hashline/src/private_block/`: 46 of 46 derived counts equal the design;
  every A opening group (35), every modelled H group (7), both endpoints and
  whole A disclose 0; whole H's residual is exactly the public LogUp identity
  at n = 4 and n = 8; all six host groups satisfy rank = ΣL − (k + 1) with
  kernel 3 and leaked 0 (84/81, 66/63, 70/67, 62/59, 100/97, 66/63); all 23
  slots within `L + 256 ≤ 512`; **all 22 negative controls fire, including
  the two owed ones** (`A_H16` sharing `A_U16`'s pair → 2; `A_YM` sharing
  `A_Y`'s → 2); 74 of 74 comparable items agree with the paper run, zero
  differences. A linear-algebra model of the schedule, with the same
  exclusions as before; no privacy property follows.
  **Tooling hazard worth knowing (Codex):** the committed inventory parser
  does not understand four constructs in the new Rust, and for one of them
  (`logup_sum_claim` reading `lay.h_planes()` / `h_is_table(p)`,
  `protocol.rs:54–55`) it does **not crash: it silently yields zero negated
  planes**. The driver carries named adapters and a test asserting the
  unadapted parser fails on this source. Two pre-existing red tests on this
  base, unrelated to the block: a missing `scripts/zk60_joint_cfs_view.py`,
  and a committed record embedding `wt-zk60-mvp-fable`'s absolute path.
- **Independent adversarial code review**
  (`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CODE_REVIEW.md`, read-only, `d9ef8be`):
  **no blocking finding.** Every new plane pinned in code with its arm, term
  and class lookup tabulated; all seven relations equal the kernel's
  including the biased requantization identity; the statement digest absorbs,
  in order, the attention words, `gamma_m`, `wg_t`, `wu_t`, `wd_t` and the 256
  `i16` activation words, covering every public word the argument reads;
  Fiat–Shamir order equal to the design; no false accepted witness
  constructed in seven attempts. Two defects (a wrong index comment in
  `SC_TZC`; `requant` underflows at shift 0 — I confirmed it at
  `witness.rs:54`, unreachable today) and a test gap: no verifier-side tamper
  for the `norm_m` family or the activation multiplicity row, and the
  `u16 = 0` case that makes the pair lookup a soundness requirement is
  untested.
- **Running:** one Opus agent, sole writer, closing exactly those: the two
  defects, the missing tampers (each with its predicted catch written down
  before it is measured), the `u16 = 0` test (if it verifies, that is
  blocking), and the owed runtime test of the claim audit's shared-pair
  refusal. My disposition of the implementation follows it.

**The private block implementation is accepted as an experimental component
(06:25); the overnight loop ends here.** Lane `zk60-private-block` at
`98a5db9` (pushed):
`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md`.

- The last agent closed the code review's findings (`5f3b2f7`): both defects
  fixed with tests; verifier-side tampers for the whole `norm_m` family
  (output, denominator, limbs, remainder windows) and a moved activation
  multiplicity, **each caught exactly where it was predicted before it was
  measured**; and the test I asked for above all others — at an index where
  the up matmul is zero, `a16` moved off its table row with nothing else
  changed — **is rejected by the verifier at the LogUp sum claim**, so the
  pair lookup does the job erratum E-22 says only it can do.
- My own runs after those fixes: 46 unit and 4 integration tests pass;
  accepted files byte-identical; and **a receipt I produced before the fixes
  verifies under the binary rebuilt after them**, so they changed no protocol
  behaviour. All six conditions of the construction disposition are met, with
  the evidence tabulated in the disposition.
- **Not a privacy acceptance.** Owed, none blocking: a direct edit of the
  multiplicity plane needs a test-only hook in `protocol.rs`; the schema-3
  capture writer for this profile and then the joint-view tools on real block
  receipts (where a privacy statement starts); the calibration digest as a
  statement field once a second calibration exists; D8/D11 for the two
  external endpoints.
- **For Codex, to integrate when you choose:** `zk60-private-block` is
  self-contained on top of `zk60-attention-compile` — new files, plus one
  line in `hashline/src/lib.rs`, a dev-dependency in `hashline/Cargo.toml`
  (with `Cargo.lock`) and one constant in `hashline/src/tables_attn.rs`. Its
  ledger gives the exact build and test commands. The capture writer for its
  profile can follow the attention one. I left the `(-3, -3)` fixture fix on
  the attention component to you, as agreed.
- **Why the loop stops:** everything left depends on Codex's integration or
  on work that needs the security owner's full attention rather than a timer
  (the D8/D11 restatement). `TASK_BOARD.md` §0 now points here.

## 4. Relation to the zkVM loop of 2026-09-17

Both deliveries concern the custom-PCS path, which remains the route to the
throughput target. The zkVM route is the shorter path to a complete private
tiny block; its receipt-kind, security-bits and leakage questions are being
assessed by the headless Fable lane, and the interactive session will
adjudicate that review against `ZK60_PRIVACY_REQUIREMENTS.md` when it lands.
