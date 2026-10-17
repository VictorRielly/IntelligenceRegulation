# Privacy statement for the trained TinyLlama-1.1B T32 profile — DRAFT (not in force)

Drafted 2026-10-17, from about 12:50 UTC, by the PRIVACY GATE lane (a
delegated Claude Opus 5.5 agent). It follows the form of
`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` (register D22).

| Status | **DRAFT, for the security owner and for an independent adversarial review. NOT a privacy acceptance, and nothing on this page establishes a privacy property.** It proposes a sentence and lists what that sentence would rest on, what changes at the trained layout, what has been measured at that layout, and what is still owed. Every step of it carries the same caveat as D22's, and a stronger one: the arguments it leans on were drafted, attacked and ruled for the TOY and for the 125M development shape. Each is re-read here **for the trained layout by one agent (me), and nobody has attacked that reading yet.** D22 still covers only the toy block. |
|---|---|

**Labels.** [MEASURED] means a run happened and a record is cited.
[COUNTED] means arithmetic from the code and the shape. [ARGUED] means a drafted
argument that survived one independent attack, as its disposition rules.
[READ] means a fact read in a cited source line or document. **[MINE]** means
my own reading or arithmetic for this page, checked by nobody. The evidence is
in `results/zk60_gate_tinyllama_20261017/` (called **EV** below); its ledger
is `EV/PROGRESS.md`.

## 0. In plain words

- **What would be claimed.** A verifier who receives a verified private run
  of trained TinyLlama blocks at 32 tokens learns, from its bytes, nothing
  about the hidden input, the hidden output, the hidden activations or the
  hidden planes between blocks. "Nothing" here means beyond a distance of
  about 2^-70 per 22-block run. The claim holds in the model Victor accepted
  for the toy (D19, D20, D21), plus D19b, which he has not ruled. Whether the
  prover refuses depends on the input only through a residual of about
  2^-113.
- **What has been measured at this shape.** The privacy gate's whole set of
  linear checks was run on real receipts:
  - two-block runs, on a real held-out input and on the all-zero input;
  - one-block runs, on both;
  - the full 22-block stack, on the real input, for the per-commitment and
    whole-run figures and for the masking layer.

  Every figure came out as predicted beforehand, apart from three counting
  slips of mine, recorded in EV.
- **What is not done.** All of these are owed before a ruling, and are listed
  in §10:
  - The three paper arguments were re-read at this layout only by me.
  - The trained code lacks eight hardening rulings of the 125M lane (G-1).
    One of them is part of the closure of a rank-lemma gap that, at this
    shape, is not vacuous (G-8).
  - The trained code can now send tagged commitments to the GPU (G-6).
  - At 22 blocks the full preimage was not constructed, and no all-zero run
    was captured.
  - D19b and D23 are Victor's.

## 1. Scope — what a statement would cover

| | |
|---|---|
| Block profile | `hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/1` (`shape.rs` `TINYLLAMA_T32_TRAINED_PROFILE`) |
| Run profile | `hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1` (`run.rs` `RUN_PROFILE_TINYLLAMA_T32_TRAINED`) |
| Shape | 32 tokens; width 2048; hidden 5632 (padded to 8192); 32 query heads of 64 over 4 key-value heads. Rows 2^12 wide at rate 1/4, 256 opened columns. Endpoints have 21 rows (16 data + 5); a boundary has 22. Per stage, A has 1,729 rows (1,487 data, 120 claims, 36 groups) and H has 1,798 rows (50 claims, 9 groups) [MEASURED, every record] |
| Form | **Only a BOUND RUN.** A single-block receipt is refused at a trained-calibration profile (R2-4, `protocol::single_block_profile_allowed`). "One block" means a run with L = 1. The run header absorbs the trained-model statement's identity as its `calibration` word (`RunStatement::new_bound`) |
| Calibration | `pg_rot1_export_T32` (profile.json sha256 `b25ba5f5…`), the model at revision `fe8a4ea1`. tn 10; Cn_a 3999; Cn_m 3122; Ceps 91,255; shifts qkv 8 / score 6 / o 9 / ao 3 / gate 8 / product 14 / down 5; f_e 9. The exp and SiLU tables differ per layer (7 distinct SiLU members, 2 distinct exp tables over the 22 layers). The residual basis is rotated by a public randomized Hadamard map |
| Lengths in evidence | L = 1 (layer 0), L = 2 (layers 7–8), L = 22 (all; statement identity `68ad19c8…`, the same statement the native lane's 22-block stack proved) |
| Hash rule | D19a tag: keyed BLAKE3, four keys derived from the block profile (re-derived by the gate and equal to the declared keys) |
| Sealing | The prover, at proof time (D18, option A) |
| Path | **CPU only, by configuration** (see G-6: tagged commitments are no longer declined by the accelerator in this tree) |
| Code | `ops/zkp-mvp/trained-1b-gate/`: the frozen review copy `trained-1b-review-r2` plus test-only capture code. **No commit, no integrated tree.** A statement has to name an integrated tree and its pin set (§5, condition 7) |

**Not in scope; each owes the argument again:**

- any other calibration under the same profile string (finding F-6 of the D24
  review: one profile string covers a family of calibrations, which the
  statement identity separates; the gate read pg_rot1 only — see §7, G-7);
- any T other than 32;
- the GPU path (G-6);
- hidden weights (P3; NL-7 says the non-linear argument does not carry);
- sealing in advance (D8, D11, D18 option B);
- joining two finished runs (D12a);
- the embedding, final norm, LM head and token selection (D13; outside the
  proved stack);
- soundness.

## 2. The statement (proposed sentence — not in force)

> In the random-oracle model for BLAKE3 (D19), read as BLAKE3's compression
> function being ideal also at a chaining value the adversary knows (proposed
> D19b, **pending Victor**), and assuming the prover's generators' joint
> output is indistinguishable from uniform (E-1; X-1 across runs), a verifier
> who receives an **accepted** run directory of this profile with L blocks,
> bound to its trained-model statement, and who makes at most `q ≤ 2^128`
> hash queries, sees a view within about **2^-74.8 (L = 1), 2^-73.8 (L = 2),
> 2^-70.4 (L = 22)** per run of a distribution that does not depend on the
> hidden run input, output, activations or internal boundary planes — for
> every **admissible** hidden run input, admissibility being a joint
> condition on all L blocks (R-1.1). Whether an attempt on an admissible input
> is refused is, up to **2^-117.4 / 2^-116.4 / 2^-113.0** (two-world
> distance), a function of the verifier-visible challenges and the public
> tables alone.

The numbers are [COUNTED] (§4). The structure is the run statement of
`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §1 at this shape. The
sentence stands or falls with §3's five steps and the conditions of §5.

## 3. What it would rest on, step by step, at the trained layout

For each step: the argument of record; **what changes at the trained
layout**; what is MEASURED here; what is OWED. The layout changes that matter
are these:

- **(a) The pad set is {F, L, Tab}.** D, Ht, Kv, Q, S and T are exact powers
  of two. At 125M the pad set was {Ht, L, D, Q, S, Tab}. Dom::F pads here and
  did not at 125M: 2,560 of 8,192 per token, 81,920 positions.
- **(b) Per-profile constants.** The D24 norm (tn, two separate Cn, Ceps) and
  seven windowed requantization shifts are now shape fields, read by the
  relations of slots 02, 14, 15, 16, 17 and 18. They also set the top-limb
  coefficients of `lookups_at` (`2^(8-sh)`, `2^(16-sh)`).
- **(c) Per-layer public tables** (exp `e_s`, SiLU member, weight folds).
- **(d) The rotated basis.** A public change of basis of the residual stream,
  folded into the public weights.
- **(e) Duplicate lookups.** At sh_qkv = sh_g = 8 the scaled top-limb lookup
  of RQL, RKL, RVL and RGL has coefficient 1. It is then the same lookup as
  the byte lookup already in the list. Unlike correction C-6 for the norm, it
  is not dropped, so H carries two helper planes of equal value for each
  (§7, G-7).
- **(f) Code lineage.** The trained tree lacks the 125M lane's stages 36–45
  (§7, G-1).

### Step 1 — the all-zero input is admissible, proves and verifies

- **Argument.** None needed beyond the run. The zero chain is zero at every
  block (x = 0, so every norm is 0, attention is 0, the residual is 0, the
  FFN is 0), with Ceps > 0 keeping the norm's denominator non-zero.
- **Changes here.** Real weights, and the zero plane on them.
- **MEASURED.** The all-zero plane on the trained blocks proves and verifies
  with the production run verifier, captured with the recorder attached:
  - L = 2, layers 7–8: `EV/capture-zero.*`, 50 s, 1.01 GiB;
  - L = 1, layer 0: `EV/l1/capture-l1-zero.*`.
- **OWED.** A 22-block all-zero run (the 125M case's open row 1 as well). It
  rests today on the same argument as at 125M: the zero chain is identically
  zero, and the witness does not depend on the weights.

### Step 2 — per commitment, the linear view discloses nothing (G-R1)

**Argument of record:** `ZK60_GENERIC_RANK_LEMMA_SHAPED.md`, accepted with
changes S-1…S-6 [ARGUED, its disposition], plus the four closures GS-4, GS-5,
GS-11 and GS-12 (`ZK60_GS4_GS5_GS11_GS12_CLOSURES.md`, ruled GC-1 and GC-2).

**What changes here [MINE].** The lemma is about commitment geometry: rows,
reserved pairs, groups, proximity pair, pad count equal to opened columns. It
is not about the relations' coefficients, so (b), (c) and (d) do not enter it.
Its shape invariants hold, checked against the bundles:

- S-1, `log(Dom::Tab) == log_cols`: 12 = 12, measured in the prediction.
- S-3, head_dim 64 < row width 4096.
- S-6, `log T` = 5 < 12.
- C-4, the mask budget: largest `L_s` 97 + 256 ≤ 512.

Of the four closures:

- GS-5's formula is derived for any n and Q; here n = 4096 and Q = 256.
- GS-11 holds: M's geometry is identical (50 rows, 34 functionals, measured).
- GS-4 holds: exclusivity measured 16 of 16 on every commitment.
- **GS-12 is NOT vacuous here**, for the first time at a real shape, because
  of (a): Dom::F pads. Its closure rests on three things: every admitted
  witness carries `(g8, a16) = (0, 0)` at a padded F position; ruling
  **S38-F1(a)** refuses `act[128] ≠ 0` wherever F pads; ruling **CS-3**
  refuses any activation miss before the first commitment. **Both rulings
  are absent from the trained tree (G-1).** What holds instead is
  [MEASURED]: `act[128] = 0` in all 22 layers' activation tables of
  pg_rot1, recovered by the gate from each stage's public table and equal to
  the export's `act.bin`. The closure therefore holds **for this export, not
  as an enforced invariant** (G-8).

**MEASURED** (`EV/l2/tl-{dense,zero}-a.json`, `EV/l1/tl-l1-*-a.json`,
`EV/l22/tl-l22-dense-a.json`):

- A disclosed 0 everywhere (rank 74 of the 74 generators on the non-data
  rows).
- H disclosed 2, computed equal to the public LogUp identity (exact u* =
  per-indicator).
- Both endpoints 0.
- Every internal boundary 0, its reserved block of rank 6 of 6; at L = 22,
  all 21 boundaries.
- M 0.
- k0 = 0 everywhere; exclusivity 16 of 16 on every commitment.
- The H-pad cross-check has full rank.
- These figures are the same for the dense and the all-zero bundles.

**OWED.**

- GS-12's enforcement (G-1, G-8).
- G-7's reading for the duplicate helper planes. The linear view is measured
  unaffected (H stays at 2), because the lemma does not look at data values.
- The lemma's own errata at this shape: none expected [MINE].

### Step 3 — the gate constructs blinding that reproduces the view under the all-zero input

**What changes here.** The tools had to be ported:

- 21 source digests re-read and re-pinned, with readings;
- the terminal identity reading the per-bundle calibration;
- D24's window in the prediction;
- control CT-5 generalised to the first padded domain;
- the one-block predictor branch.

The port moves no frozen figure: the original and ported tools, run on the
frozen rung-K4 bundle with controls, agree on 5,261 record fields, with 0
unexplained differences (`EV/equivalence/equivalence-k4.json`).

**MEASURED.**

| Item | L = 2 dense / zero | L = 1 dense | L = 22 dense |
|---|---|---|---|
| Per-commitment preimage from zero data: entries, differing | 2,246,389 / 2,255,011, 0 | 1,125,324, 0 | **not run** (about 1 h) |
| Masking layer and CFS: entries, differing | 32,310, 0 (each) | 16,155, 0 | 355,410, 0 |
| One joint assignment: entries, differing | 2,278,699 / 2,287,321, 0; four couplings respected | 1,141,479, 0 | not run |
| Salted leaves authenticated | 1,792 + 512 | 1,024 + 256 | 5,632 (M) |
| Every control family fires (by-name skips as at 125M) | yes / yes | yes. With tools v3 (G-5): C1…C4 NOT APPLICABLE by name; C6 fires; C5 fires on the replay only (G-10); CH 6 of 7 (CH-6 skipped by name); M9-1, M9-2, M9-3 fire (`EV/p2/tl-l1-dense-runcontrols.json`) | M1…M6 |
| Channels | 28 = 10 constructed / 5 derived / 5 argued / 8 open | the same | pass A only |

**OWED.** The 22-block full preimage, joint arm and control families
(dense and zero), and the CH/M9 families on a one-block bundle (G-5).

### Step 4 — the joint law of all published field values is input-free (Theorem B)

**Argument of record:** `ZK60_JOINT_LAW_COMPOSITION_RUN.md`, accepted as a
REDUCTION (R-1…R-7), conditional on G-R1 (step 2), G-R2 (the slot closures),
G-R4 (cross-role independence of the blinding) and G-R5 (step 5). The
non-linear channel's algebraic half is NL-1
(`ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md`). The law of the blinding
(G-R4) is `ZK60_BLINDING_LAW_GR4_DISPOSITION.md` (LW-1…LW-4).

**What changes here [MINE].**

- **G-R2, the slot closures.** The trained relations differ from the 125M
  ones by coefficients only. The argument for every slot (`argument.rs`,
  read in EV's pin readings) is the 125M argument with frozen literals
  replaced by shape fields: SC_TZC Ceps; SC_DZC 2Cn_a, 2Cn_m, 2^tn,
  2^(tn+1), 2^sh_ao, 2^sh_z; SC_FZC sh_h and sh_g; SC_QZC and SC_KVZC
  sh_qkv and sh_o; SC_SZC sh_s. Each is a non-zero public constant, so the
  structure NL-1 rests on (a public table in every monomial, degree within
  the declared degree, the mask covering each slot) is unchanged. Slot 17's
  prover is now a grouped evaluator, but the verifier's polynomial is the
  same function (read).
- **The bilinear slots 08/09** carry stage 20's repaired definition.
- **(e) duplicate helper planes.** These add two published terminals of
  equal value per duplicated lookup at slots 15, 16 and 18. That equality is
  structural and does not depend on the witness. Whether the terminal
  surjection step (`ZK60_TERMINAL_SURJECTION_REVIEW.md`) and NL-1's
  machine check accept a slot whose terminal map has two identical
  coordinates has not been re-run (G-7).
- **G-R4.** The draw discipline is unchanged in the trained tree [MINE,
  from the readings]:
  - no draw site of `zk.rs`'s masking functions moved;
  - the PCS pads and salts are drawn in the same order, before any branch,
    and `encode_buffer.rs` (unpinned, G-2) reads them only after they are
    drawn;
  - `masked_prove_rounds` publishes the same CfsMasker's rounds;
  - one generator per run (R-2) and one per endpoint.
  
  But **the machine assertions of G-R4 do not exist in this tree**: the
  stage-36 draw observers and the stage-47 root-rebuild check
  (`gr4_check_tests.rs`, LW-2) are lane stages 36 and 47, absent here
  (G-1). Draws are therefore [COUNTED] only (§4), not measured.
- **R-1/H-1 and M-9.** For the first time the run has a **production
  caller**: the trained stack CLI `stack-prove`.
  - It seals with the witness builder's own pass first (H-1's rule), with
    parity at every layer, before the header.
  - Its witness source takes the input at construction.
  - It writes `statement/` only after in-process verification.
  - It does **not** remove a segment directory whose run failed to verify;
    the `--lie-at-boundary` control leaves such a directory without
    `statement/`. M-9's "never transmitted, removed by whoever launched the
    run" is therefore still an operating rule.
- **R-5, interior scales.** These are constants of the approved calibration:
  the trained statement's own `block_scales` pair, (0, 0) for pg_rot1.
  `new_with_calibration` refuses any other pair, and the measured capture
  carries `[0, …, 0]`.

**MEASURED.**

- The terminal identity at the trained constants: 46 of 46 (L = 2), 23 of 23
  (L = 1), **506 of 506 (L = 22)**.
- It is not vacuous: control family TL (`EV/l2/tl-controls-*.json`,
  `EV/l1/tl-controls-l1-dense.json`) moves each of the eleven trained
  constants one step inside its class, and **exactly** the slots the Rust
  reads it in stop matching. Restoring the frozen constants breaks exactly
  slots {02, 14, 15, 16, 18}. 15 of 15 controls fire on every bundle.
- The whole-run linear joint figure equals the sum of parts at L = 1, 2 and
  22 (2 = 2, 4 = 4, 44 = 44).

  > *Ruling R-3 applies:* "joint = sum of parts" is a consistency check of
  > the model, not evidence of independence.

**OWED.**

- G-R4's machine assertion on this tree (port stage 36 and stage 47's check),
  or a ruling that the reading suffices.
- NL-1's `nl_check.py` and the terminal-surjection computation re-run at the
  trained slot-IR export (G-7).
- GN-1 / GS-14, completeness for every admissible witness.
  - Evidence: two held-out sequences proved through all 22 layers (native
    lane, R2-2/R2-3) and the six captures here. The calibration lane's
    Python reference refuses 0 of 36 held-out and 0 of 54 calibration
    sequences, which is admissibility in a reference, not completeness of
    the prover.
  - The shaped refusal census and its rulings CS-1…CS-9 are not in this tree
    (G-1).

### Step 5 — the hash layer adds nothing; the lift to the hashed protocol (G-R5)

**Argument of record:** Lemma H^run and Route A^run
(`ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md`, core accepted with changes H-1…H-8).
The model is D19 plus **D19b (pending Victor)**: this profile is TAGGED, so
it cannot rest on D19 as worded alone.

**What changes here [MINE].** The counts are new (§4): 4L + 1 roots, the leaf
and query totals. The key set is derived from the new profile strings. H-8
(constructor length against the squeeze length) was a live hazard at this
profile: the first trained run-profile string would have put the
transcript-constructor input at 68 B, equal to a `pb-run-stage` absorb. The
native lane caught it with the s25 census and lengthened the string to 66 B
(constructor 78 B, nothing at 77–79). Position tags and H-5 are unchanged in
code (run.rs absorb sequence, read). GS-7 and the explicit L = 2 hybrid stay
open as bookkeeping (as at 125M).

**MEASURED.** In every record:

- the derived keys equal the declared ones;
- every challenge is re-derived: 4,511, 9,002 and **98,822** at L = 1, 2 and
  22, the run binding reproduced and every position tag re-derived;
- every opened column is re-hashed and re-authenticated under the derived
  keys: 1,280, 2,304 and **22,784 columns (162.2 MB)**;
- four wrong hash rules never reach a root (cross-rule probe).

**OWED.** D19b. Route B (G-H1) is not needed by a Route-A statement and stays
unruled.

## 4. Residuals, sized [COUNTED]

Source: `ops/zkp-mvp/gate-tinyllama/counts/run_hash_counts.py`, a copy of the
lane's counting script with the TinyLlama shape added. Every old figure of
the original script reproduces byte for byte. Its parameter line equals the
bundle's character for character; its squeeze model equals the measured final
counter. Output: `EV/run_hash_counts_tinyllama.json`. The draw totals are a
COUNT: the in-situ observers of lane stages 36/46 do not exist in this tree.
Per-block draws are 2,329,764, per boundary 30,208 and per endpoint 25,856.

| Term | L = 1 | L = 2 | L = 22 | Kind |
|---|---|---|---|---|
| Field draws per run | 2,381,476 | 4,741,448 | 51,940,888 | — |
| Sampler bias (D9): draws × 2^-96 | **2^-74.82** | **2^-73.82** | **2^-70.37** | distance |
| Input-dependent refusal (S-4): L·768/p², one world | 2^-118.42 | 2^-117.42 | 2^-113.96 | — |
| … as a two-world distance (2·L·768/p²) | 2^-117.42 | 2^-116.42 | 2^-112.96 | distance |
| Salt guessing, q·N_leaf·2^-256 (q = 2^128) | 2^-111.9 | 2^-111.1 | 2^-107.8 | distance |
| Transcript pre-query | 2^-115.5 | 2^-114.5 | 2^-111.0 | distance |
| Leaf-input / transcript-input collisions | 2^-224.8 / 2^-231.9 | 2^-223.2 / 2^-230.0 | 2^-216.6 / 2^-223.1 | distance |
| Generator, in-model alternative (6q·2^-256, ASSUMED) | 2^-125.4 | 2^-125.4 | 2^-125.4 | assumption |
| Tag-key collision (D19b model; zero by test today) | 2^-252.4 | 2^-252.4 | 2^-252.4 | distance |
| **Total distance** | **2^-74.82** | **2^-73.82** | **2^-70.37** | |
| Refusal on degenerate challenges, (3L+1)/p | 2^-62.0 | 2^-61.19 | 2^-57.93 | **liveness, not distance** |
| A million runs (2^20), linear | 2^-54.8 | 2^-53.8 | 2^-50.4 | distance |

The S-4 count (≤ 768 distinct inverted arguments per block) is unchanged by
per-layer tables (c). Each block's three tables still have 256 rows each, and
the run total is L × 768 as before. For an admissible witness, *whether* a
zero-denominator refusal happens is a function of the challenges and the
public tables (D22 §9 item 10's argument). *Which* line returns first depends
on the data. That last point, at this tree, rests on the absence of CS-3
making no difference for admissible witnesses [MINE; to be checked with G-1].

## 5. Conditions — the toy's seven and the shaped ones, at this tree

| # | Condition | State at the trained tree |
|---|---|---|
| 1 | One reserved pair per claim site, weights `(cm, cm·U)`; H's zero-sum pair the one exception; `audit_claims`' exclusivity is the whole defence | Code fact (the shared audit, unchanged); MEASURED 16 of 16 on every commitment at L = 1, 2, 22; the 24 exclusivity controls fire |
| 2 | Pad count = opened columns | Code fact; MEASURED pad margins 0–4, H-pad ranks full |
| 3 | `d + 1` values per round; exact-row-span assertions; zero-mask refusal; declared order of the 34 mask functionals | MEASURED (mask arm, 34 of 34, M1…M6 at L = 1, 2, 22); the prover's round evaluator changed (`masked_prove_rounds`), the published rounds did not (replay) |
| 4 | One opening per commitment; a refusal is terminal | Code fact. **CS-3 (lookup-miss refusal before the first commitment) is ABSENT** (G-1): an inadmissible witness that passes the builder now reaches the verifier, which rejects it (D21 covers transmission) |
| 5 | Every Merkle leaf salted with 32 fresh bytes; no unsalted digest published | Code fact on the CPU path (salts drawn by the core). **On a gpu-cuda build with HL_GPU=1 the unsalted columns of tagged commitments are now hashed on the device** (G-6), not covered |
| 6 | Fresh OS randomness per run; no seeded configuration | One generator per run (R-2) plus two endpoints; generator domains carry role and spec (lane stage 26, present: `endpoint_g.rs` and `hash_domain.rs` are byte-identical to the 125M-gated digests) |
| 7 | The gates' source pins; a change suspends step 3 | **Pinned for these bundles**: all 39 `source_pins` read (21 new readings, `zk60_native_rg_tinyllama_pins.py`); the remainder equal the 125M digests. **OPEN:** `encode_buffer.rs`, `sumcheck/rounds.rs` and `sumcheck/grouped.rs` are on the prover path and pinned by no bundle (G-2); no integrated tree to pin |
| S | Shaped invariants: S-1, S-3, S-6, C-4 (in `Shape::new` at the trained tree); D24's window (`derive_at_width`, re-checked in `Layout::for_shape`); F-1's f_e class; R-5 interior scales; M-1 boundary geometry derived; H-8 constructor lengths (s25 census) | Present and exercised. **CS-1, CS-2, CS-4…CS-9 and S38-F1(a) absent** (G-1) |

## 6. Hypotheses and operating rules

- **D18**: the prover seals both endpoints at proof time. The stack CLI
  commits the first input plane and the last output plane it built (H-1).
- **D19** (accepted) and **D19b** (proposed, pending Victor): the model of
  the tag.
- **D20** (accepted): timing, memory and power are out of scope. A 22-block
  run adds per-stage wall clock and high-water marks to what an observer
  could time. The sealing pass's duration grows with L.
- **D21** (accepted): a rejected receipt is never transmitted; a retained
  capture counts as publishing. The captures of this evidence are of
  held-out calibration data the export itself stores in the repository
  (`seq_ho00/x_in_L*.bin`), so they publish nothing new; the gate's channel
  text calling them "a public synthetic fixture" is stale (G-3).
- **M-9 / D12b(1)**: a run directory is publishable only with its statement
  written after verification. The stack CLI writes it so, but does not remove
  a failed directory (operating rule).
- **Refusal reasons are never shown to anyone not entitled to the input.** A
  run's refusal names the stage, and the CLI's parity refusal names the layer
  and a token/channel position (no value). Diagnostics `HL_PB_BASEFIELD` and
  `HL_PB_TIMING` are prover-private (P-2).
- **D23 (proposed, pending Victor)**: an accepted run's two endpoint roots
  are never registered, republished or referred to by a later artifact.
  **This is directly in play for the stack.** Proving the embedding or the
  LM head in a SEPARATE receipt that refers to this run's input or output root
  would put that root under D8/D11 and lapse this statement. Such proofs must
  live inside the same run, one transcript (D12a).
- **E-1 / X-1**: separate OS entropy reads are independent and uniform,
  within and across runs (LW-3).

## 7. Findings, with recommended dispositions

| # | Finding | Recommended disposition |
|---|---|---|
| **G-1** | The trained tree (candidate + lane C + native lane) branched before the 125M lane's stages 36–45. It lacks rulings CS-1, CS-3, CS-4, CS-6, CS-7, CS-8 and CS-9; S38-F1(a); the stage-36 draw observers; the stage-47 root-rebuild check; and the stage-45 block-capture writer. None moves an absorb, a draw or a published byte (the replay with the UNEDITED tools reproduced every challenge). CS-3 sits on the refusal channel; S38-F1(a) and CS-3 are GS-12's closure (G-8); CS-6 is soundness. | **Block a statement on it.** Port the rulings into the trained tree, or rebase the trained work on the integrated 125M-lane tree, before any statement; then re-capture and re-run the gate (cheap: L = 2 in under 20 min). |
| **G-2** | `zkp-core/src/pcs/encode_buffer.rs` (my reading: the same arithmetic as `encode_row_zk`, pads drawn before), `zkp-core/src/sumcheck/rounds.rs` and `sumcheck/grouped.rs` (prover round evaluators) are on the prover path and in no bundle's `source_pins`. | Writer-side ask: add them to `run_capture.rs::SHARED_SOURCE_FILES`, then pin them with readings (the gate's per-row reproduction already re-checks the encoding by computation). |
| **G-3** | The gate's channel text "retained captures … a deliberately public synthetic fixture" is false for trained bundles (real held-out activations). | Wording fix in the gate (P2-2 of this lane). |
| **G-4** | Control M9-3 fires on all five unpadded domains, but its own ok-criterion (the refusal naming the draw counts) is false at TinyLlama exactly as in every 125M record; "only this slot" is false for D and S because their indicators also gate slots 00/01 and 04. | Re-word the criterion to "the refusal is by name" and "only the slots `pad::indicator_slots` lists". A tool fix, no figure moves. |
| **G-5** | At L = 1 the run-control stage raises (C1/C2 need a boundary), so the CH and M9 families did not run on a one-block bundle. | Skip the boundary family by name at L = 1 and run CH/M9 (P2-2 of this lane, if cheap). |
| **G-6** | **Ruling T-8 no longer holds in this tree.** Tagged commitments are offered to `Backend::try_commit_zk_keyed`, which the CUDA backend implements (`hashline/src/gpu/mod.rs:691`). Under `gpu-cuda` + `HL_GPU=1` the hidden rows and pads go to the device and unsalted keyed columns are hashed there (salts stay on the host). The native lane's GPU stack runs use it. | The statement is **CPU-only by configuration**, and says so. A GPU statement needs the DC-B device-buffer review (`ZK60_HIDING_COMMITMENT_ON_DEVICE_DISPOSITION.md`), the CUDA files pinned, and GPU-path captures through the gate. |
| **G-7** | At sh = 8 (one-limb shifts) or sh = 16 (two-limb), the scaled top-limb lookup has coefficient 1 and duplicates the byte lookup of the same plane. Unlike C-6, it is not dropped. pg_rot1 has four such duplicates (RQL, RKL, RVL, RGL), each giving two H helper planes with identical values and two equal terminals. The linear view is measured unaffected (H = 2, unchanged). The non-linear argument's machine check (NL-1) and the terminal-surjection computation were run at nine exports, none trained. | Re-run `nl_check.py` and the surjection computation at the trained slot-IR export. If anything objects, either restrict the declared class (sh ≤ 7, sh ≤ 15) or drop the duplicates in a new profile version (a layout change). Until then the statement covers pg_rot1's constants only, not the declared class (D24 F-6). |
| **G-8** | GS-12 is non-vacuous here (Dom::F pads, 81,920 padded positions per block), and its closure's two refusals are absent (G-1). `act[128] = 0` MEASURED in all 22 layers of pg_rot1. | Port S38-F1(a) and CS-3 (with G-1); until then the statement is limited to exports whose activation tables have `act[128] = 0`, checked by the gate per stage (it now records this). |
| **G-10** | At L = 1, control C5 (the only stage swapped for the other bundle's) is caught by the replay (4,770 failures, first at the stage header) but NOT by the run integrity pass: in run mode `integrity` never compares a stage's external-endpoint opening roots with `run.json`'s `external_endpoints` roots. The block reader does compare them (`zk60_native_rg_block.py:643, :737`). At L >= 2 the boundary-root check catches a swapped stage, so this was never seen. | Add the block reader's root comparison to the run integrity pass, inert on honest bundles. I did not make the change: my heavy queue had already verified the v3 tool digests and was waiting to run. The replay is the stronger check and it fires. |
| **G-9** | My predictions missed three counting figures (TL-1's slot 17, corrected in writing before the run; L = 1 roots 5 vs 4; L = 22 manifest files 5 vs 25). The predictor's one-block fallback was wrong exactly as predicted beforehand. | None for the argument. Recorded in EV. |

## 8. What must not be claimed, even if this came into force

That TinyLlama or "a 1B model" is private in general; that any other
calibration or token count is covered; that the GPU path is covered; that the
full model (embedding, LM head, sampling) is covered; that soundness was
reviewed here; that the 22-block full preimage was constructed (it was not);
that this is a proof re-derived by the security owner.

## 9. What would lapse or reopen it

- A change to any condition of §5.
- A change to any file of the pin set (once one exists for an integrated
  tree).
- A finding against any step of §3.
- A calibration or export outside what the gate measured (G-7, G-8).
- A GPU-built receipt (G-6).
- A later artifact referring to an accepted run's endpoint roots (D23).
- Victor declining D19b; a published weakness in BLAKE3 as a random function
  or in the OS generator.
- An independent reader finding that a Python port differs from the Rust it
  claims to port — in particular the per-bundle calibration transcription of
  this port (`zk60_native_rg_terminals.Calibration`).

## 10. What is owed before the security owner could rule (ranked)

1. **G-1 and G-8**: port the missing rulings, or rebase on the integrated
   125M-lane tree; re-capture; re-gate (L = 2 under 20 min, L = 22 pass A
   8 min at 5.5 GiB) [lane + integrator].
2. **An integrated tree, and its pin set** (condition 7), including G-2's
   files [integrator + gate].
3. **G-7**: the NL-1 check and the terminal-surjection computation at the
   trained slot-IR export [delegated, small].
4. **The 22-block full preimage and joint arm, dense and all-zero**, and the
   22-block all-zero capture [this lane, P2-2: about 2 h of compute].
5. **G-R4 at this tree**: the stage-36 assertions and the stage-47
   root-rebuild check, or a ruling that the count suffices [lane].
6. **GN-1 / GS-14 at the trained profile**: a refusal census with real
   weights (the 125M census is on synthetic weights, and its CS rulings are
   absent here) [delegated].
7. **Victor**: D19b; D23 (which constrains how the stack may be extended to
   the embedding and LM head).
8. **An independent adversarial review of this draft and of the port**, in
   the drafter → checker → ruling pattern of D22.
9. Gate bookkeeping: G-4's criterion, and G-10's endpoint-root cross-check in
   the run integrity pass [gate owner, small].

## 11. Evidence index (EV = `results/zk60_gate_tinyllama_20261017/`)

| What | Where |
|---|---|
| Ledger, results tables, costs | `EV/PROGRESS.md` |
| Captures (outside the repo) | `/home/victor/zk60-artifacts/tinyllama-trained-capture-{dense,zero}-{l1,l2}`, `…-dense-l22` |
| Predictions written first | `EV/l2/prediction_*`, `EV/l1/prediction_*`, `EV/l22/prediction_*` |
| Records of record | `EV/l2/tl-{dense,zero}-{a,everything}.json`, `EV/l2/tl-zero-arms.json`, `EV/l1/tl-l1-*.json`, `EV/l22/tl-l22-dense-{a,m}.json` |
| Port's own controls | `EV/l2/tl-controls-{dense,zero}.json`, `EV/l1/tl-controls-l1-dense.json` |
| Dense against zero | `EV/l2/witness_comparison_tl_dense_vs_zero.json` (128 figures, the 14 that differ all sampled-column) |
| The port moves no frozen figure | `EV/equivalence/equivalence-k4.json` |
| Tools, frozen | `ops/zkp-mvp/gate-tinyllama/` (`original/`, `frozen_v1/`, `scripts/`), `EV/gate-tinyllama.tools.frozen{,.v2}.sha256`, patches `EV/gate-tinyllama-vs-original.v{1,2}.patch` |
| Capture code | `ops/zkp-mvp/trained-1b-gate/`, `EV/trained-1b-gate-vs-review-r2.v{1,2}.patch`, `EV/trained-1b-gate.sources.v{1,2}.sha256` |
| Sized terms | `EV/run_hash_counts_tinyllama.json` |
