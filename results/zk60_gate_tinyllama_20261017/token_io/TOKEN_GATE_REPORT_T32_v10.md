# Privacy gate on the token-I/O stages, tools v10: TinyLlama T32 at L = 1, 2, 22 and Llama-3-8B T32 at L = 1, 2 (gate round 7, step 2)

Written 2026-10-19 (23:24 UTC) by the PRIVACY GATE lane, a delegated Claude
Opus 5.5 agent.

| Status | **Gate evidence, NOT a privacy acceptance.** It measures DESIGN §4.2's items G-1..G-6 on ten token-I/O run captures, plus the four coverage gaps step 2 named. Only the security review process can accept, and rulings are Victor's. |
|---|---|

This report **supersedes the v9 report for coverage**. The v9 report itself
(`EV/token_io/TOKEN_GATE_REPORT_R2_T32.md`, sha256 dc5fed0e…: L = 1, 2 at
v9) is kept unchanged.

**Labels.**

- [MEASURED]: a run happened and a record is cited (shared box, one run).
- [COUNTED]: arithmetic from the code and the shape.
- [READ]: read in a cited source line.
- [ARGUED]: a short argument stated where it is used.

EV below is `results/zk60_gate_tinyllama_20261017/`.

## 0. In plain words

Step 2 asked for four coverage gaps to be closed as tool work, and then a
re-run of everything. All four are closed, and all ten runs pass:

1. **The new slots' terminal identity, and an NL-1 check of the new slots.**
   Each of the 15 new slots (4 in stage IN, 11 in stage OUT) now has its
   polynomial evaluated, and it equals the captured terminal. The NL-1
   premises hold on all 15.
2. **The preimage and joint arms on the new commitments**, including a
   **computed** joint figure over tok / B_in / B_out:
   - The frozen joint system modelled one row width only, so v10 extends it
     to a word-level decomposition. Every generator acts identically at
     every word position, so the mixed 2^12-to-2^8 identification is exact
     word by word.
   - The computed joint disclosure is **0** (= the sum of the parts, 0)
     over 133,153 identified word pairs at TinyLlama and 266,273 at 8B.
   - The full preimage runs on **every** commitment of the run: 10, 13 or
     73 commitments, up to 24.9 M view entries, **0 differing**.
3. **The block-stage terminal identity inside a token run.** It holds 23
   of 23 per block: 506 of 506 at L = 22.
   - This includes one block proved at its **layer's own score shift**
     (8B L = 2, layer 1: sh_s 7 against the run's 6).

Nothing failed. Every live control fires.

## 1. What was gated

| | |
|---|---|
| Captures (read in place, 0700, outside the repo) | `/home/victor/zk60-artifacts/token-io/captures/`: **TinyLlama** `tinyllama-t32-L{1,2,22}-{dense,fixed}-pt1`; **8B** `llama3-8b-t32-L{1,2}-{dense,fixed}-pt1`. Schema `hashline-native-capture/6-token-run`, `L + 2` stages. dense = the export's held-out sequence; fixed = 32 copies of BOS (id 1 at TinyLlama, 128,000 at 8B) |
| Run profiles | `…private-token-io-run-tinyllama-1.1b-t32-trained-statement-public-row/1` and `…private-token-io-run-llama-3-8b-t32-trained-statement-public-row/1`: public-row variant, mode (i), tier `mvp-95-whole-run (D27)` |
| Exports (named in each capture's README, cross-checked X1–X10) | TinyLlama `pg_rot1_b4_T32_cal128` (`per_layer_constants_differ` = exp_e_s, silu_member). 8B `llama3_8b_pg_rot1_b7voc0_T32` (fidelity lane; **adds sh_s per layer**) |
| Tree | The token lane's round-7 capture tree "r7c" (native R8 + the token files + the step-A capture hooks). Its 52 pinned files equal those of the final round-7 manifest `manifest_final_r7.sha256` (eb912dd5…; checked file by file). 40 pins are R7's read in v8; 12 are read in `zk60_native_rg_tokenio_r7c_pins.py`. 0 refused |
| Tools | **v10**: `EV/gate-tinyllama.tools.frozen.v10.sha256` (59 files, 167391ec…), snapshot `frozen_v10/`, patches `gate-tinyllama-v9-to-v10.{scripts,tests}.patch`. **Every record's `tool_sha256` equals the v10 manifest** (54 files hashed per record; `summarize_v10.py`) |
| Records | `EV/token_io/v10/token-v10-*.json` (10); summary `EV/token_io/v10/token-v10-summary.json` (31e7b40e…); queue `EV/token_io/token_queue_v10.sh` (`.done` = 0; the unit suite at its start ran 60 tests, OK: `EV/token_io/v10-unittests.log`) |
| Not built, so out of scope | G-7 (D26 variant P), variant F, mode (ii), the hidden-length variant: `token_io/run.rs` `variant_is_built` refuses them [READ] |

## 2. Results [MEASURED]

**All ten records PASS:**

- 0 false parts;
- the replay re-derives every challenge, with 0 failures;
- every column is authenticated;
- every pin is read;
- 36 / 36 live controls fire.

| | TL L1 dense / fixed | TL L2 dense / fixed | TL L22 dense / fixed | 8B L1 dense / fixed | 8B L2 dense / fixed |
|---|---|---|---|---|---|
| Status | **PASS / PASS** | **PASS / PASS** | **PASS / PASS** | **PASS / PASS** | **PASS / PASS** |
| Replay: challenges / positions, binding | 5,347 / 220, yes | 9,838 / 344, yes | 99,658 / 2,824, yes | 5,788 / 220, yes | 10,248 / 344, yes |
| Columns authenticated | 3,328 | 4,352 | 24,832 | 3,328 | 4,352 |
| Wall (s) | 714 / 653 | 862 / 832 | 3,756 / 3,429 | 798 / 689 | 942 / 916 |
| Peak RSS (guard) | 0.55 GiB | 0.60 GiB | 1.75 GiB | 0.90 GiB | 0.96 GiB |

### 2.1 Gap 1: the new slots' terminal identity and NL-1 (new in v10)

**What is checked** (`zk60_native_rg_tokenterminals.py`, sha256 62e1dcc2…):

- per new slot, `fin == c·mask_eval + poly(vals)` (`token_io.rs:974-992`);
- the polynomial is transcribed from `define` (`stage_in.rs:149-221`,
  `stage_out.rs:336-542`), and is evaluated on the recorded terminals, the
  public tables at ρ and the re-derived definition challenges;
- it is compared both with the captured `terminal_polynomial` (= fin −
  c·mask_eval, `run_capture.rs:1209`) and with fin recomputed from the
  rounds.

| | Every capture |
|---|---|
| New slots equal | **15 / 15** (IN 4, OUT 11) |
| Public tables rebuilt from re-derived geometry | 18 |
| Public tables taken from the capture | 2 (stage IN's τ table, stage OUT's head fold) |
| NL-1 (S1 premises on the symbolic expansion) | **15 / 15** |

The NL-1 premises are:

- a public TABLE factor in every monomial (the affine 1 − supp is split by
  the expansion, NL-3);
- product degree ≤ the declared degree;
- private-terminal count = the slot's terminals;
- one extension round with every private table in round 0.

**Observations**, which are not findings:

- In IN-03 and OUT-09 (and OUT-01 at 8B) one monomial's only public factor
  has a constant MLE. This is the all-ones factor of a zero-sum slot, or at
  8B the all-ones supp(d) because d = d_pad.
- In OUT-02 / OUT-07 (and OUT-01 at TinyLlama) some monomials carry only
  indicator tables.

S1 counts both as a public factor.

**What it does not establish:**

- That the two taken tables fold the embedding and the head the statement
  names. No bundle carries those weights, so they are checked for length,
  sha256 and builder structure only.
- That mask_eval agrees with the committed mask. That is the M opening,
  item G-3 below.

### 2.2 Gap 2: the computed joint figure and the preimage / joint arms (new in v10)

**The extension.** The frozen `RunJointSystem` models row combinations at
one row width. The token run identifies a 2^12-word stage row with a
2^8-word endpoint row:

- tok on A-in and E-token-in;
- the output tok on A-out and E-token-out.

It also identifies B_out's last token row with A-out's row T−1, two token
rows per 2^12 commitment row.

v10's `token_joint_figure` decomposes by **word position**:

- each commitment's generators (reserved and pad rows, proximity rows, group
  vectors) act identically at every word, so a word position is an
  independent sub-system;
- identified words are tied across commitments;
- each connected component is ranked once.

This is exact, not a bound [ARGUED in the module and checked by J-1..J-3].

| | TinyLlama (every L) | 8B (L1 / L2) |
|---|---|---|
| Identified word pairs | 133,153 | 266,273 |
| Components ranked | 4 (L1), 5 (L ≥ 2) | 4 / 5 |
| **Joint disclosed (Fp per word)** | **0** | **0** |
| Sum of the parts | 0 | 0 |
| An identification reaching a non-data row | none | none |

**Components at L ≥ 2** (TinyLlama L22 shown; at L = 1, B0 and B1 share
block 1's A):

- {A-in, E-token-in}: 32 words;
- {A@1, B0}: 4,096;
- {A@L, B_L}: 2,048;
- {A-out, A@L, B_L, E-token-out}: 1 word;
- {A-out, A@L, B_L}: 2,047.

By ruling R-3, joint = sum of parts is a consistency check of the model's
coordinate classes, not evidence that the blinding is independent. That is
G-R4's.

**The full preimage on every commitment** (`full_preimage`):

- every commitment of the run: A-in, H-in, E-token-in, each block's A and
  H, every boundary, A-out, H-out, E-token-out;
- **0 entries differing** on every capture;
- leaves: 256 salted leaves per commitment are authenticated (2,560 / 3,328
  / 18,688).

| | TL L1 | TL L2 | TL L22 | 8B L1 | 8B L2 |
|---|---|---|---|---|---|
| Commitments | 10 | 13 | 73 | 10 | 13 |
| View entries compared (dense) | 1,376,986 | 2,500,124 | 24,883,666 | 1,700,292 | 3,010,156 |
| Differing | 0 | 0 | 0 | 0 | 0 |

**The joint assignment (`joint_preimage`).** The four couplings are
respected on every capture:

- **C1:** the shared planes take one value across their commitments (the
  identified word pairs above), and no identification reaches a non-data
  row;
- **C2:** the one claim value published by two commitments is one number;
- **C3:** the masking layer against the slots (G-3's recomputation): 0
  entries differing, on all stages;
- **C4:** the terminal identity at every new slot and every block slot.

### 2.3 Gap 3: the block-stage terminal identity inside a token run (new in v10)

`zk60_native_rg_tokenblocks.py` (sha256 2cbe4f54…) runs the frozen stage-8
port `check_terminals`:

- on each block stage of the token run, through a one-stage shim;
- with the calibration taken from the export the capture's README names, and
  cross-checked against the token header and the layout description (X1–X10).

The bundle's `shape.rs` (8c62519c) is the token r7c reading, which v10 added
in memory for the call only. The port's own table stays frozen. NC-0 shows
that the port refuses without it.

| | TL L1 | TL L2 | TL L22 | 8B L1 | 8B L2 |
|---|---|---|---|---|---|
| Block slots equal | 23 / 23 | 46 / 46 | **506 / 506** | 23 / 23 | 46 / 46 |
| Bilinear group factor | ok | ok | ok | ok | ok |

**The layer-own calibration [MEASURED].** The 8B export lists `sh_s` per
layer. At L = 2 the run value is 6 (the majority rule of
`trained_block.rs run_constants`; tie at one layer each, smallest wins), and
**layer 1 is proved at its own sh_s = 7**. Its stage's 23 slots equal at
that shape. This is the per-layer path of native R6/R8, exercised inside a
token run. Only `sh_s` is exercised; R8's other ten per-layer fields are not
(no export uses them).

## 3. G-1..G-6 on all ten captures [MEASURED]

These are unchanged in form from the v9 report and now cover L = 22 and 8B.

**G-1, rank per commitment.** Every commitment meets its expectation on every
capture:

- A-in 0, H-in **2**, E-token-in 0, A-out 0, H-out **2**, E-token-out 0;
- every block A 0, H **2**, every boundary 0;
- the M commitments disclose 0 each (3 / 4 / 24 of them);
- the H figure is the exact public LogUp identity;
- k0 = 0 everywhere;
- the 16 exclusivity clauses hold.

The reserved block of B_in and of B_out (ruling M-8(a)) has rank 6 of 6,
disclosed 0, determinant ≠ 0.

**G-2, claim points:**

- B_in's stage-IN claim has **11** (TinyLlama) / **12** (8B) column
  coordinates in r_emb (= clog2 d_pad);
- B_out's stage-OUT claim has **5 public bits**, row T−1, one of them a
  column bit, at both sizes;
- the other claims are random.

**G-3, mask / CFS per stage.** Every stage re-derives its functionals:

- IN: 8 functionals; 5,352 entries (TinyLlama) / 5,362 (8B);
- OUT: 20 functionals; 9,326 / 9,354 entries;
- each block: 34 functionals, 16,155 / 16,240 entries;
- **0 differing** on every stage of every capture, at L = 22 on 24 stages.

**G-4, pads and support:**

- TinyLlama: 8 of 8 required support tables present, vocabulary pads 768.
- 8B: **7 of 7**, vocabulary pads **2,816** (128,256 → 2^17). OUT-05's
  supp(d_pad) over Do is not a pad factor at 8B, because d = 4,096 = Do (no
  P-3 lift of Do: `G4_static.p3_lift`).
- Endpoint pad words: 224 / 256 (input), 255 / 256 (output).

**G-5:** the byte table sits at 2^12 = the stage-OUT row width. Stage IN has
no byte table.

**G-6, the token endpoints at 2^8.** Disclosed is 0 on both endpoints of all
ten captures. The pad block has full rank equal to the distinct opened
columns:

| | TL L1 d / f | TL L2 d / f | TL L22 d / f | 8B L1 d / f | 8B L2 d / f |
|---|---|---|---|---|---|
| E-token-in | 242 / 245 | 244 / 239 | 237 / 231 | 245 / 243 | 239 / 240 |
| E-token-out | 242 / 243 | 232 / 239 | 243 / 237 | 240 / 244 | 238 / 243 |

## 4. Controls (each predicted to fire; 36 live, all fire on all ten captures; 2 not applicable)

| Control | What it perturbs | Result |
|---|---|---|
| TC-1..TC-10 | as in the v9 report: exclusivity on IN / OUT, shared pair / one proximity row on B_in / B_out, replay perturbations (r_emb, LogUp count, opening order), integrity (input root, B_out rows, plane index, endpoint stage), G-2's fixed bits, G-4's support digests, round 8's mask controls M1–M3, M5, M6 on M_in / M_out, the token pins | all fire. M4 (shortens a BILINEAR slot) is **not applicable** by name on IN and OUT, which have none |
| **J-1** (v10) | the input endpoint's reserved row identified with tok's data row | the joint model refuses: "identifies a data row with a non-data row" |
| **J-2** (v10) | B_in's reserved row identified with block 0's Input row | refuses, by name |
| **J-3** (v10) | one proximity row shared between two commitments | the shared non-data class is detected; the joint stays 0 |
| **TC-11 / TC-12** (v10) | the P-family preimage controls (P-1..P-6) on stage IN / stage OUT | 6 / 6 fire on each |
| **NC-0** (block terminals) | the port's table as frozen (the token shape.rs reading not added) | the port refuses before any slot (0 slot checks attempted) |
| **NC-1** | sh_z moved by one inside its class in every stage's shim | fails exactly at the predicted slot (14), predicted from `tlcontrols.READS` |
| **NC-2** | the shim with the token bundle's shape as written (no trained keys), so the port falls back to the FROZEN calibration | fails exactly at the predicted slots 2, 14, 15, 16, 18 in every stage |
| **NC-3** | the run calibration's sh_z moved to 5 | cross-checks X1, X3, X6 fire |
| **NC-4** (L ≥ 2) | token stage 2's carried SC_TAB tables replaced by stage 1's, one at a time | fails exactly at the predicted slot. Not applicable at L = 1 (one block) |

## 5. What is NOT covered

- **Not run:**
  - 8B at L = 32. No such capture exists.
  - Any export other than the two named in §1.
  - The other ten R8 per-layer calibration fields: no export uses them.
- **Not established by these checks:**
  - That the τ table and the head fold are the statement's embedding and
    head (§2.1).
  - Blinding independence across commitments: G-R4's, by R-3.
  - Anything about soundness. The token tree's soundness review (round 6,
    REVIEW5) was in progress when this was written.
- **Not covered by construction:**
  - **The CLI token path.** It has no capture hooks, so it is not gated.
  - **The GPU path.**
  - G-7 / variant P, variant F, mode (ii).
- **None of this is a privacy acceptance.**
