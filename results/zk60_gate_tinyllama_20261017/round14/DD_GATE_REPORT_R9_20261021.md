# Privacy gate on native R9 DD captures (D30), tools v17: the DD rung (T32 / d256) and TinyLlama T128 DD, L = 1 and 2 (gate round 14)

Written 2026-10-21 (02:10 UTC) by the PRIVACY GATE lane, a delegated Claude
Opus 5.5 agent.

| Status | **Gate evidence. It is NOT a privacy acceptance.** It measures what D30 requires before any DD receipt is called private: the rank lemma, NL-1 and the joint passes, with the new dictionary planes in A (P_dict, its limbs, M_dd), slot 23 (`SC_DD`, standalone, appended last), the table helper `gdd` in the value-0 sum claim, and the reserved sites. Only the security review process can accept, and rulings are Victor's. |
|---|---|

**Labels.**

- [MEASURED]: a run happened and a record is cited (shared box, one run).
- [COUNTED]: arithmetic from the code and the shape.
- [READ]: read in a cited source line.
- [ARGUED]: a short argument stated where it is used.

EV below is `results/zk60_gate_tinyllama_20261017/`.

**Status at writing (02:10 UTC).** Three heavy records are still running:

- the DD surjection on T128 L2, dense and zero;
- everything + controls on T128 L2 dense;
- the official re-run of everything on T128 L1 dense. The same pass with
  byte-identical v17 tools has already passed (dev11, below).

§6 lists them. A dated update will follow when they land. Everything else
below is final.

## 0. In plain words

DD replaces each score entry's own division limbs with one lookup into a
per-row dictionary of committed slots. That adds new committed planes, a
new slot (23) and a new helper inside H's zero-sum claim. The gate had to
learn all of them before it could say anything about a DD receipt.

**On every DD capture gated so far, the DD planes and slots add no
disclosure.**

- Each A commitment discloses **0**. The A commitment now carries the
  dictionary's planes.
- Each H commitment discloses **2**, the same 2 Fp as before DD. H now
  carries the tuple helper and `gdd` in the value-0 sum claim.
- The endpoints and boundaries disclose **0**.

**The checks that back this:**

- Every stage's 24 slots, including slot 23 and slot 17's DD arm, recompute
  the Rust terminal polynomial exactly.
- NL-1 holds on both DD slots.
- The DD surjection finds every A group onto and H at its known 2.
- Where it has run, the full zero-data preimage reproduces the captured view
  with **0 entries differing**: rung L1 / L2 and T128 L1.
- The mask and joint passes hold.

**Every new check failed first where it could have passed vacuously.**

**One thing the tools did not handle before this round** is a run whose
layers carry their own calibration constants. Native R8 allows this, and the
T128 export has it: layer 1's score shift is 8 where the run's is 6.

- v16 read one calibration for every stage. It would have checked stage 1
  at the wrong constants.
- v17 reads each stage's constants from its schedule line, binds them to the
  schedule digest, and evaluates the stage there.
- Control TL-5 shows that evaluating that stage at the run's constants (the
  v16 behaviour) fails at exactly its two affected slots.

## 1. What was gated

| | |
|---|---|
| Captures (read in place, outside the repo) | `~/zk60-artifacts/dd-gate-r9/`. **DD rung** `dd-rung-l{1,2}-{dense,zero}`: profile `…private-run-rung-dd-t32-dev/1`, T32 / d256 / f512, 8 heads over 2 KV heads, trained-norm rung calibration. **TinyLlama T128 DD** `tl128dd-l{1,2}-{dense,zero}`: profile `…private-run-tinyllama-1.1b-t128-ddict32-statement/1`, export `tinyllama_dg_rot1_T128` (fidelity lane), layers 0 / 0–1, held-out `ho00` (dense) or the all-zero plane. All eight: 24 slots, `dd_cap` 32, 46 pins |
| Parity (dense) | The native DD chain equals the export's reference output **bit for bit**: 262,144 words (L1), 524,288 words (L2) [MEASURED] |
| Per-layer calibration | At T128 L2, layer 1 is proved at its own constants. Stage 01's schedule line reads `score shift 8 (run 6)`, `norm cn_a 2198 (1253)`, `norm cn_m 1764 (1444)` and `ao shift 6 (7)` [MEASURED] |
| Tree | `ops/zkp-mvp/trained-1b-gate-r9/`: native R9 frozen tree `af90c703…` (222 files; every production file equal to `results/zk60_1b_native_20261017/r9/manifest_frozen.json`, checked before every build) **plus a test-only gate patch** in `run_capture.rs`, `plane_index.rs` and `run_capture_tests.rs` (H-1..H-5, the coordinator's option (b); all `#[cfg(test)]`). Patch **v2** `EV/round14/trained-1b-gate-r9-vs-frozen-r9.v2.patch` (052a82cf…), sources v2 `trained-1b-gate-r9.sources.v2.sha256` (d9b80c92…). v1 (cbf013d9…) wrote the rung and T128 L1 captures; v2 differs only in `run_capture_tests.rs`, where the harness builds each block at its layer's own shape, as the stack CLI does (`trained_block.rs:2121`). The first T128 L2 captures built every block at the run shape and the prover's CS-3 refused them (kept as `cap-tl128dd-l2-*.v1-failed.*`). At L = 1 and on the rung every block's shape IS the run shape, so v1 and v2 write the same bundles there |
| Capture cost [MEASURED] | Rung: 1–2.5 s, 0.10–0.12 GiB, 9.6 / 17.8 MB. T128: L1 10–11 s, 3.25 GiB, 74 MB; L2 17–19 s, 3.35–3.38 GiB, 108 MB |
| Tools | **v17**: `EV/gate-tinyllama.tools.frozen.v17.sha256` (70 files, ff68af54…), snapshot `frozen_v17/`, patches `gate-tinyllama-v16-to-v17.{scripts,tests}.patch` (c00e1ca1…, bf4628e1…), vs-original v17 (5bc598d4…). **Every staged record's `tool_sha256` equals the v17 manifest** (`EV/round14/summarize_r14.py`) |
| Queues | `EV/round14/r14_gate_a.sh` (failing-first, pass A, predictions, DD tools, controls, suite), `r14_gate_b.sh` (everything + controls), `r14_gate_c.sh` (the control tail, and the long T128 L2 surjections; §6); common `r14_common.sh` |

## 2. What tools v17 adds, each with a failing-first check

1. **The R9 readings** (`zk60_native_rg_tinyllama_r9_pins.py`). 14 moved
   pins are read and merged into the run-layer, terminal, mask and GQA
   tables:
   - two are the gate patch's test-only files;
   - six are R9 production files that a port transcribes;
   - six are report-only.

   **Failing first [MEASURED]:** frozen v16 on `dd-rung-l1-dense` and on
   `tl128dd-l2-dense` refuses the R9 pins by name: argument.rs `112352bc`
   "neither definition", layout.rs, protocol.rs, plane_index.rs, shape.rs,
   and more. "NO slot of any stage was checked"; NOT-OK
   (`EV/round14/ff/`). Before that, frozen R9's own capture path, with only
   the new tests added, refused a DD rung capture: "the A plane name table
   has 83 names for 85 planes" (`EV/round14/r14-ff-*.log`).
2. **The DD slot ports** (`zk60_native_rg_terminals.py`):
   - `TAG_DD = 141`;
   - `lookups_at` for Dom::S at DD (no division limbs) and for Dom::Dd;
   - `g_dd`;
   - the helper counts with `H_STUPLE` / `H_GDD`;
   - `sc_szc_dd` (slot 17's DD arm) and `sc_dd` (slot 23). Each refuses
     `pad_on` with R9's own text;
   - slot 23's captured e column, structure-checked;
   - its attribution to the stage's slot-19 exp table;
   - `ports_for` / `covered_at` per bundle, so slot 23 can never be
     silently uncovered.
3. **New DD tools**, each with predicted controls:
   - `zk60_native_rg_ddnl.py`: NL-1 S1–S5 on slots 17-DD and 23, from a
     symbolic transcription. The chain of checks is T-0 → X-0 → F-0, with
     controls F-1 and X-1;
   - `zk60_native_rg_ddcontrols.py`: DT-1..DT-7;
   - `zk60_native_rg_ddts.py`: the G-7 surjection on every role, the
     review's controls, and DS-1 / DS-2.
4. **Each stage's calibration** (`zk60_native_rg_stagecal.py`, new):
   - It reads the stage line's own clauses (R9 `run.rs:525-541`).
   - It binds them by **recomputing the run's schedule digest** from
     run.json's lines (`run.rs:572-587`). The digest recomputes equal on all
     eight captures.
   - It re-derives `d_max` / `norm_wrho` (`derive_at_width`).
   - Refusals SC-1..SC-7, each by its code.
   - The terminals port evaluates stage k at its shape (`set_stage`).
     ddnl and gcontrols do too.

   **Failing first:** TL-5 and TL-6 (§5).
5. **The export check's per-layer fields** (`zk60_native_rg_exportcheck.py`).
   v16 compared the run shape's per-layer fields with `null` and refused every
   per-layer export. That was dev8's only NOT-OK. v17 adds:
   - **E0**: the export's integrity;
   - **E1**: per-layer fields against the RUN calibration of the run's
     export layers (the modal tuple, ties the smallest, OWN_FIELDS order:
     `run_constants`);
   - **E3b**: each stage's layer identified from its slot-14 gains when no
     statement is given;
   - **E5**: each stage's calibration against its export layer.

   **Failing first [MEASURED]**, `EV/round14/controls_c/ex-perlayer-controls-tl128dd-l2-dense.json`.
   The honest bundle passes; 4 / 4 fire:
   - EXP-1, sh_s 6 → 7: E1 refuses "sh_s is 7 in the bundle and 6 in the
     run calibration of export layers [0, 1]";
   - EXP-2, cn_a + 1: E1 refuses;
   - EXP-3, stage 1's own score shift 8 → 7 with the digest re-bound: E5
     refuses "stage 1 (layer 1) is proved at sh_s 7, the export layer's
     is 8";
   - EXP-4, the README's layers [0, 2]: E3b refuses.
6. **TL controls per stage.** TL-1 / TL-2 perturb every stage's shape and
   predict per (stage, slot). New TL-5 and TL-6.
7. The unit suite grows to **79 tests**: `R9Pins` (2), `DDPorts` (3) and
   `StageCal` (2) are new. All OK in the working copy.

## 3. Results [MEASURED]

**All eight pass-A records PASS**, with 0 unexplained false leaves. The
only false leaves are the control arms that pass A does not request, and
the status explains them.

| | Rung L1 dense / zero | Rung L2 dense / zero | T128 L1 dense / zero | T128 L2 dense / zero |
|---|---|---|---|---|
| Pass A status | **PASS / PASS** | **PASS / PASS** | **PASS / PASS** | **PASS / PASS** |
| Replay: challenges / positions, binding | 2,735 / 132, yes | 5,458 / 261, yes | 5,002 / 132, yes | 9,984 / 261, yes |
| Terminal identity (24 slots per stage) | 24 / 24 | 48 / 48 | 24 / 24 | 48 / 48, **stage 1 at layer 1's own constants** |
| A per stage: disclosed (rows / claims / groups) | **0** (907 / 125 / 38) | **0** each | **0** (1,871 / 123 / 38) | **0** each |
| H per stage: disclosed (rows / claims / groups) | **2** (928 / 55 / 10) | **2** each | **2** (2,026 / 52 / 10) | **2** each |
| Endpoints, B0 | 0 | 0 | 0 | 0 |
| Export cross-check | (synthetic calibration; none) | none | **ok**: E3b layer [0], E4 tables equal | **ok**: E3b layers [0, 1] (= README), E1 run calibration = layer 0's (a tie, the smallest), **E5 stage 1 = layer 1 at its own constants**, E4 equal at both stages |
| Prediction validated | 12 / 12 figures | 12 / 12 | 12 / 12 | 12 / 12 |

**Everything + controls** (full zero-data preimage of every commitment,
mask / CFS, the joint, the run controls):

| Record | Status | Full preimage: entries / differing | Mask / CFS | Joint: entries / differing, couplings | Wall, peak |
|---|---|---|---|---|---|
| rung L1 dense | **PASS**, 0 unexplained | 534,573 / **0** (4 commitments, all solved and exhibited) | 16,499 / 0 | 551,072 / **0**, respected | 280 s, 0.53 GiB |
| rung L1 zero | **PASS** | 532,649 / **0** | 16,499 / 0 | 549,148 / **0**, respected | 283 s, 0.53 GiB |
| rung L2 dense | **PASS** | 1,060,276 / **0** (7 commitments) | 32,998 / 0 | 1,093,274 / **0**, respected | 361 s, 0.57 GiB |
| T128 L1 dense (dev11, tools byte-identical to v17) | **PASS**, 0 unexplained | 1,905,229 / **0** (4) | 16,906 / 0 | 1,922,135 / **0**, respected | 3,324 s (full preimage 2,794 s), 1.93 GiB |
| T128 L2 dense | running (§6) | | | | |

The full preimage is the strongest check here. It exhibits prover blinding
that reproduces the captured view, entry by entry, under the ALL-ZERO hidden
input. That view covers:

- every opening group's vector, message and pad half;
- the proximity vector;
- every claim value;
- every opened column.

## 4. D30's items, one by one

- **The dictionary planes in A** (P_dict, its limbs, M_dd: the block
  `pdict()..=mdd()`, of size 2 + limbs_p + 2·limbs_σs; H-3's check):
  - **[MEASURED]** A discloses 0 at every stage of every capture. Its
    123–125 claims each use their own reserved pair: `reserved_pairs_used`
    = claims, `reserved_mask_rows` = 2 × claims.
  - The DD surjection finds **38 / 38 A groups onto**, disclosed 0, on every
    capture gated.
  - **DS-1**: slot 23's A group (10 claims on the rung, 8 at T128) with one
    claim's reserved pair removed discloses **2 Fp**, where the honest group
    discloses 0. This is the control that the dictionary's claims are not
    vacuously covered.
- **Slot 23 (`SC_DD`, standalone, appended last):**
  - **[MEASURED]** slot 23's terminal equals the Rust polynomial at every
    stage.
  - NL-1 holds on it: T-0, X-0, F-0, S1, S4, all four challenge modes, S3
    tight.
  - DT-1 (P_dict's terminal + 1), DT-3 (`H_GDD`'s terminal + 1), DT-4 (the
    e column, digest off) and DT-7 (`H_GDD` dropped from the plane list)
    each fail at exactly (that stage, 23) or at the push-order check.
  - DT-6 (tag 140 for 141) fails slots 17 and 23 in every stage and nothing
    else.
  - DT-5 (a non-increasing e column) is refused by the structure check.
  - The e column is attributed to the stage's own exp table at every stage.
- **The table helper `gdd` in the single value-0 sum claim:**
  - **[MEASURED]** H discloses exactly **2** at every stage: the known two
    zero-sum rows, joint component {7, 9} = 2 in the surjection. 9 of 10 H
    groups are onto.
  - That is the pre-DD figure, so adding `H_STUPLE` and `H_GDD` to the sum
    claim adds no disclosure.
  - **DS-2**: the tuple helper's 4-claim H group with a pair removed
    discloses 2 where the honest group discloses 0.
  - DT-2 (`H_STUPLE`'s terminal + 1) fails at exactly (stage, 17).
- **Reserved sites:**
  - **[MEASURED]** every claim of A and H is opened at its own reserved
    pair. No claim evaluates a u row except H's two zero-sum claims (as
    before).
  - The plane index tiles A and H exactly, and every plane is read by a
    slot.
  - The review's controls on the first two-member A group fire as of
    record: C1, C2 and G7-D3 fire; C3, C6, C8, G7-D1 and G7-D2 behave as
    the review found.
- **Slot 17's DD arm** (no division clause, one tuple lookup):
  - its terminal is equal at every stage;
  - NL-1 holds;
  - pads: at DD the ports of slots 17 and 23 refuse `pad_on` with R9's
    own text ("would host a pad term"), as `argument.rs` R9 does. The
    round-9 controls M9-3 and CT-9 count that refusal as the pad mechanism
    of slots 17 / 23 at DD, and their arms are ok in every everything
    record.

## 5. Controls [MEASURED] (each predicted; all fire)

- **DT-1..DT-7: 7 / 7** on all four rung captures and T128 L1 dense / zero.
- **DD NL-1:** PASS on all four rung captures and T128 L1 dense / zero; T-0
  equal on every DD slot instance.
- **DD surjection controls:** ok on all four rung captures and T128 L1
  dense, including DS-1 / DS-2 at every stage.
- **TL controls:**
  - 19 / 19 on rung L2 dense, 16 / 16 on T128 L1 dense, **24 / 24 on T128
    L2 dense and zero** (`EV/round14/controls_c/`).
  - TL-1 / TL-2 are exact per (stage, slot).
  - **TL-5/stage-1** (stage 1 evaluated at the run shape, as v16 did) fails
    at exactly (1, 14) and (1, 17): the slots that read cn_a / cn_m / sh_ao
    and sh_s.
  - **TL-6** refuses all five edited stage lines by their codes, SC-1..SC-5.
  - TL-5 is named not applicable where no stage has its own constants.
- **Export controls:** EX-1, EX-2, EX-3 and EX-6 fire on T128 L1 / L2 dense.
  EX-4 / EX-5 need a statement, which these captures do not have. EXP-1..4
  fire (§2).
- **G-10: 8 / 8** on rung L1, T128 L1 and T128 L2.
- **Schema:** ok over all eight bundles (228 allowed keys).
- **Run / hash / round-9 controls** inside each everything record: ok.

## 6. Pending at writing (a dated update will follow)

- **The DD surjection on T128 L2, dense and zero.**
  - The development run on L2 dense (dev10, the same tools) hit its
    1-hour cap. Before that it had finished stage 0 A (38 / 38 onto,
    disclosed 0), stage 0 H (2, joint {7, 9}), stage 0 Input, and stage 1 A
    (38 / 38, 0). The stage H pass alone takes ~1,260 s at T128.
  - Queue A's copies, also capped at 1 hour, will time out (that will be
    recorded).
  - Queue C re-runs both with a 4-hour cap into `EV/round14/dd_long/`.
- **Everything + controls on T128 L2 dense** (queue B; the full preimage is
  ~2 × L1's).
- **The official re-run of T128 L1 dense everything** (queue B, last). dev11
  is already a v17 record (all 62 tool hashes equal the manifest).
- **Duplicates and the suite at queue A's end:** T128 L1 zero / L2
  ddnl / ddcontrols, queue A's own copies of the control tail, the v17
  suite.

## 7. What is NOT covered

- **Not run:**
  - Llama-3-8B T128 DD; T512; L > 2 at T128 DD;
  - zero-input everything at T128;
  - a statement-bound T128 DD capture. These captures carry the model
    statement's identity in the header, but no independent `statement.json`
    was written, so E3 / EX-4 / EX-5 are not applicable; E3b's
    identification from the gains is used.
- **Not established by these checks:**
  - **Soundness.** That is D24 review r9's, which accepted R9 on soundness.
  - Blinding independence across commitments: G-R4's, by R-3 / X-1.
  - The refusal residual of D30 (4) (2·L·(768 + rows·cap)/p²). It is a
    counted term for the statement, not something a capture shows.
- **Not covered by construction:**
  - **The CLI path for DD.** The captures come from the gate's test-only
    harness, which builds each block exactly as the stack CLI does. They
    are not P-18 captures of the CLI binary.
  - **The GPU path.**
- **None of this is a privacy acceptance.**

## 8. Evidence index

| What | Where |
|---|---|
| Records (pass A, predictions, everything) | `EV/round14/v17/` |
| DD NL-1, DD controls, DD surjection | `EV/round14/dd/` (and `dd_long/` for T128 L2) |
| TL, export, EXP, G-10, pin controls, schema, witness comparison | `EV/round14/controls_c/` (queue A's copies in `controls/`) |
| Failing first | `EV/round14/ff/` (v16 on DD); `EV/round14/r14-ff-*.log` (frozen R9's capture path) |
| Development records (superseded, except dev11 as noted) | `EV/round14/dev/` |
| Summary | `EV/round14/summarize_r14.py` → `EV/round14/r14-summary.json` |
| Capture patch and sources | `EV/round14/trained-1b-gate-r9-vs-frozen-r9.v{1,2}.patch`, `trained-1b-gate-r9.sources.v{1,2}.sha256`, `r9-source-pins.v1.json` |
| Capture hook request | `EV/round14/DD_CAPTURE_HOOK_REQUEST.md` |
| Tools | `EV/gate-tinyllama.tools.frozen.v17.sha256` and patches; snapshot `ops/zkp-mvp/gate-tinyllama/frozen_v17/` |
| Ledger | `EV/PROGRESS.md` (round 14 entries, 2026-10-20 06:00 to 2026-10-21) |
