# Fable lane handoff — branch `zk60-mvp-fable` (pushed; tip `679ac26`, base `763e308`)

Written by the interactive Claude Fable 5.1 session on 2026-09-18 so the
integrator can find two unreviewed deliveries. This file is a pointer only;
the shared boards are the integrator's.

## 0. CURRENT — read this first; everything below is a dated log

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
