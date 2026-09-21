# The RUN gate — what it computes on a multi-block run capture, and what it does not show

**Written 2026-09-20 on lane `zk60-native-jointview`.** Tool:
`scripts/zk60_native_run_gate.py`. Evidence:
`results/zk60_native_run_gate/`. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`.

> **Sections 1–5 are the first round (the two stage-14 bundles).
> Section 6, added the same day, is the second round**: the Rust lane
> shipped the PLANE INDEX TABLE that §3 item 4 asked for, and the per-slot
> terminal identity is now recomputed at the run's shape for **12 of the 23
> slots**, on two NEW bundles. Where §3 item 4, §4 and §5 say that check is
> open, read them against §6, which says exactly how far it closed and why
> the other eleven slots did not.
>
> **Section 7, the same day again, is the third round**, on the two TAGGED
> bundles the Rust lane's stage 18 wrote: every hash is now BLAKE3 in KEYED
> mode under decision D19's four derived keys, and the bundles carry the
> public tables' VALUES. Read §6's "eleven slots stay OPEN" against §7.4,
> which closes them — **23 of 23** — and read §5's "the hash layer is
> ARGUED" against §7.3, which computes the part of it that is about
> soundness and says why the HIDING part is argued still. The disclosure
> figures of §2.3 and §2.4 did not move under the tag, which is itself one
> of round 3's results.
>
> **Section 8, the same day again, is the fourth round**, and it is the
> first on a witness that is NOT degenerate. The Rust lane found and
> repaired a COMPLETENESS defect in the two bilinear attention slots
> (finding S19-F1) and re-took the captures on fully dense weights with a
> non-constant hidden input whose two key-value groups carry different
> data. Every bundle §§1–7 read used a fixture that is identical in every
> head, or the all-zero input. §8 ports the repaired definition, DERIVES
> the new public group factor instead of consuming it, and re-establishes
> every figure of rounds 1–3 on the dense witness. **A dated correction
> under ruling R-3 sits in §2.4 and again above §7**: it changes the
> READING of the joint figures and not one number.

> **THIS IS NOT A PRIVACY ACCEPTANCE AND ESTABLISHES NO PRIVACY PROPERTY.**
> Every number below is a rank, a count or a digest of an explicitly stated
> LINEAR model, at two captured runs' real challenges, at ONE development
> shape. The hash layer is argued, not computed. The joint-law composition
> for a run is unwritten. The bundles themselves carry
> `privacy_review_complete: false`, and so does every record this gate
> writes.

---

## 0. In one paragraph

A private RUN is several blocks under one transcript: block `k`'s hidden
output is block `k+1`'s hidden input, carried on ONE boundary commitment per
internal boundary with TWO claim sites (block `k`'s output-equality slot 22
and block `k+1`'s input-equality slot 21), one reserved mask pair per site, a
row count DERIVED as `data + 2·sites + 2`, opened exactly once. Ruling M-8
asks for a gate on three blocks at the development rung with **all three
roles of each boundary plane ranked jointly** and the shared-pair and
single-proximity-row controls included. This tool is that gate. On both
captured runs it re-derives the whole transcript, ranks every commitment of
every stage, ranks each boundary **restricted to its reserved rows**, ranks
the three commitments that hold the same boundary plane as one system, ranks
the WHOLE RUN as one system, exhibits a zero-data preimage for the message
half of every singleton-group commitment, fires six negative controls, and
labels every channel of a run's view CONSTRUCTED / DERIVED / ARGUED / OPEN.

---

## 1. Input, and how it is pinned

Two independent honest three-block runs at the development rung shape (24
tokens, width 96, hidden 192, 6 query heads over 2 key-value heads; 1,024
columns, inverse rate 4, 256 opened columns), written by
`hashline/src/private_block/run_capture.rs` on lane
`zk60-private-block-125m`, schema `hashline-native-capture/4-run`, format
`docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`:

| bundle | hidden input | bytes | source commit |
|---|---|---|---|
| `run-a-tame` | the lane fixture's | 38,484,890 | `cb27845d5ad3a0e401c48c4eebeac7fe4a86f171` |
| `run-b-zero` | all zero | 38,482,131 | the same |

Neither hidden input is in its bundle. The bundles live on the Rust lane's
worktree and are NOT copied into this repository; only the gate's own record
is. The bundle pins its own Rust sources
(`manifest.json["source_pins"]`): `run_capture.rs 51f26bc1`, `run.rs
02f7ee7e`, `boundary.rs 9860c35d`, `protocol.rs 4e916c69`, `argument.rs
909670c9`, `layout.rs fec2e647`.

**Nothing is ported.** Every size comes from `run.json["shape"]`, every
label from `run.json["transcript_labels"]`, the parameter line from
`run.json["parameter_line"]` and each opening's PCS parameters from its own
`params` — findings U-7 and U-8 of the format document. The toy gates'
flat constants (`zk60_native_jv_capture.py:38-46`) are deliberately not
imported, and no file those gates hash into their evidence was edited: the
shape-driven variants are new `zk60_native_rg_*.py` modules, and the
shape-agnostic parts (`zk60_native_jv_field`, `JointSystem`, and every check
of `RoleView` that reads no size) are imported and reused.

---

## 2. What the gate computes

### 2.1 Integrity (stage 1)

Every file's byte length and SHA-256 against `manifest.json` (5 files,
38,484,890 bytes); the three schema strings and the coverage string, refusing
a schema-3 single-block capture **by name**; the field modulus and the
extension nonresidue; `expected_policy_sha256` against the policy bytes;
`run_shape_words` against the shape; the label set; per stage the slot count
and every slot's `(main, extension, degree)` against the shape, `M`'s
`2·slots + 4` rows, the opening order, the block digest and the boundary this
stage commits; per opening the PCS parameters, the row-role count, the
proximity PAIR and the endpoint row count. Per boundary: the DERIVED row
count `data + 2·sites + 2 = 10`, `site_rows = [4,5,6,7]` as two **disjoint
adjacent** pairs, `prox_row = 8`, committed at stage `k` and opened at stage
`k+1` and nowhere else, the root committed in stage `k` equal to the root
opened in stage `k+1`, and `claim_sources = [(k, 22), (k+1, 21)]`. Finally:
the run's ten PCS openings have ten distinct roots — **no commitment is
opened twice**.

Both bundles: no findings.

### 2.2 The transcript replay (stage 2)

The whole run transcript is re-derived in Python with BLAKE3 from the
bundle's public data, in run order, following `run.rs::transcript` and the
stage loop, `protocol.rs::absorb_root`, `sumcheck.rs::verify`,
`zk.rs::mask_verify` and `pcs.rs::verify_zk`:

| | both bundles |
|---|---|
| run binding (the state after the header, before any commitment) | reproduced |
| recorded transcript positions compared as (state, next challenge) | **375** |
| challenges re-derived and compared | **6,086** |
| final transcript counter | 6,918 |
| segment position tags (`start_tag`, `end_tag`, outside the chain — ruling M-6) | 6 of 6 reproduced from a discarded clone, and each stage's end tag equals the next stage's start tag |
| challenges NOT re-derived | **none** |

Nothing in the replay needs a public table's values, so
`public_tables_included: false` costs it nothing. One altered published
field breaks it (a control).

### 2.3 Per commitment, per stage (stage 3)

The model is `zk60_native_jv_pcs`'s, stated there in full:
`disclosed = dim_Fp(F ∩ T)`, which under H-pad, H-pair and H-prox — each
CHECKED — reduces to `n·k0 + (u-row term)`. Here `n = 1,024`.

**One thing the toy conflated and this shape separates.** A committed row is
`z_i = (msg_i, pad_i)` in `Fp^n × Fp^Q`. At the toy profile `n = Q = 256`; at
the rung `n = 1,024` and `Q = 256`, so a published vector is 1,280 entries
and the column functional's two halves have different lengths:
`E_j[msg s] = (x_j^n − 1)/(n(x_j w_n^{−s} − 1))` and
`E_j[pad k] = (x_j^n − 1) x_j^k` for `k < Q`. With that split the verifier's
own sampled-column identity reproduces on every commitment with **0
failures**.

`run-a-tame` (run-b-zero is identical except for the column counts):

| commitment | kind | rows | data | groups | claims | generators `2(G+1)` | k0 | disclosed | expected | certifying minor | distinct columns / pads |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `A@0` | block | 623 | 377 | 36 | 122 | 74 | 0 | **0** | 0 | nonsingular | 246 / 256 |
| `H@0` | block | 576 | 468 | 9 | 53 | 20 | 0 | **2** | 2 | nonsingular | 249 / 256 |
| `E-Input` | external endpoint | 9 | 4 | 1 | 1 | 4 | 0 | **0** | 0 | nonsingular | 250 / 256 |
| `A@1` | block | 623 | 377 | 36 | 122 | 74 | 0 | **0** | 0 | nonsingular | 249 / 256 |
| `H@1` | block | 576 | 468 | 9 | 53 | 20 | 0 | **2** | 2 | nonsingular | 250 / 256 |
| `B0` | internal boundary | 10 | 4 | 2 | 2 | 6 | 0 | **0** | 0 | nonsingular | 247 / 256 |
| `A@2` | block | 623 | 377 | 36 | 122 | 74 | 0 | **0** | 0 | nonsingular | 250 / 256 |
| `H@2` | block | 576 | 468 | 9 | 53 | 20 | 0 | **2** | 2 | nonsingular | 249 / 256 |
| `B1` | internal boundary | 10 | 4 | 2 | 2 | 6 | 0 | **0** | 0 | nonsingular | 249 / 256 |
| `E-Output` | external endpoint | 9 | 4 | 1 | 1 | 4 | 0 | **0** | 0 | nonsingular | 250 / 256 |
| `M@0..2` | masking | 50 | 0 | — | — | 2 | 0 | **0** | 0 | — | 256 mask columns |

`run-b-zero`'s distinct column counts are 243..251 of 256; the variation is
the birthday surplus of sampling with replacement, and in every case the
distinct count is **inside the pad budget**.

`H`'s 2 is the public LogUp identity, and the gate checks that it IS that
identity rather than assuming it: both zero-sum row indicators are
admissible and the `ξ` they produce span exactly the span of the sum claim's
data-row weights (`equals_public_logup_identity: true`, 234 nonzero weights
each).

H-pad is computed, not assumed, once per run: the pad block of `{E_j}` over
the distinct opened columns of `B0` has exact rank 247 of 247 (3.7 s).

### 2.4 The boundary — ruling M-8 (stage 4)

**(a) Restricted to the reserved rows.** A boundary's opening has two
singleton groups, so its generators are the real and imaginary parts of the
two group combinations and of the proximity combination: `2(G+1) = 6` real
vectors. Its reserved block is the two claim pairs `(4,5)`, `(6,7)` and the
proximity pair `(8,9)` — 6 columns.

| boundary, both bundles | rank on the reserved block | of | disclosed | determinant |
|---|---|---|---|---|
| `B0` | **6** | 6 | **0** | nonzero |
| `B1` | **6** | 6 | **0** | nonzero |

This is the checker's exact small model (A1.4 of
`ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md`) reproduced on real captured runs.
The gate also reports the rank over ALL rows — also 6 — and says why that
figure is worthless on its own: over all rows the honest case and both
degenerate cases are indistinguishable, which is exactly the omitted
condition M-1 was written for.

**(b) The three roles of one boundary plane.** The same hidden plane sits in
block `k`'s activation commitment (its output plane), in the boundary
commitment, and in block `k+1`'s activation commitment (its input plane).
The identification is read from `claim_sources`, **never from the role
names** (finding U-8): stage `k`'s slot 22 raises claim 0 of `Bk` and stage
`k+1`'s slot 21 raises claim 1 of the same commitment, and the gate checks
each equality slot is Standalone, that the two claims' first parts have the
same `log_size` and the same evaluation point, and that the site's reserved
pair is the one its position in the claim order implies.

| boundary | roles | identified rows | classes | generators | parts | sum | joint | equal |
|---|---|---|---|---|---|---|---|---|
| `B0` | `A@0`, `B0`, `A@1` | 8 | 1,248 | 154 | 0, 0, 0 | 0 | **0** | yes |
| `B1` | `A@1`, `B1`, `A@2` | 8 | 1,248 | 154 | 0, 0, 0 | 0 | **0** | yes |

> **CORRECTION, 2026-09-20 (round 4), ruling R-3.** Nothing in this table
> or in the paragraph below is wrong, and no number here moves. What was
> too generous was the READING. `joint == sum of the parts` is a
> **consistency check of this model's coordinate classes, NOT evidence that
> the commitments' blinding is independent.** The checker for the run's
> joint-law composition built the counterexample: two DISTINCT blinding
> rows whose VALUES coincide score exactly like an honest run (joint 0 =
> sum 0) while disclosing 1,024 field elements at this shape. Independence
> across the 4L+1 commitments rests on the generator and the draw
> discipline (gap G-R4) and is to be machine-asserted elsewhere. The same
> correction applies wherever a joint figure appears below — §2.6's control
> C3, §5, §6.5, §7.6 — and round 4 put the sentence into the gate's own
> records (`ruling_R3`, beside every joint figure).

**Is `joint == sum` a theorem here?** Yes, *given two facts the gate
computes rather than assumes* — and "theorem" here means only that the two
NUMBERS must agree, which is the reading ruling R-3 corrects above. Only
DATA coordinates are shared — no
blinding source is: each commitment draws its own mask rows, proximity rows
and pads — so the non-data block of the joint generator matrix is block
diagonal by role (`non_data_block_is_block_diagonal_by_role: true`) and its
rank is the sum of the three. Identifying data coordinates can then only
LOWER `rank(all)`, so `k0_joint ≤ Σ k0_r`; with every part 0 the joint is
forced to 0. It is NOT a theorem in general, and control C3 below shares one
blinding row and the joint rises above the sum. The figure is computed in
both cases.

**(c) The whole run.** One generator system over ALL thirteen commitments of
all three stages — three `A`, three `H`, three `M`, two boundaries, two
external endpoints — with every shared plane identified (24 rows, from the
six equality slots).

| system | matrix | coordinate classes | sum of parts | joint | seconds |
|---|---|---|---|---|---|
| stages 0 and 1 with boundary 0 | 202 × 2,505 | 2,505 | 4 | **4** | <1 |
| stages 1 and 2 with boundary 1 | 202 × 2,505 | 2,505 | 4 | **4** | <1 |
| **the whole run** | **308 × 3,761** | 3,761 | 6 | **6** | **1.0** |

The whole-run figure is COMPUTED, not left open: 6 `Fp` is three copies of
`H`'s public LogUp identity and nothing else. The largest exact rank the
gate takes is that 308 × 3,761 Goldilocks matrix; no computation in the gate
approaches 4 GB or 20 minutes (the whole gate is ~9 s per bundle, and its
single slowest step is the 247 × 256 pad block at 3.7 s).

### 2.5 A zero-data preimage, message half (stage 5)

For a commitment whose opening groups are all SINGLETONS — both boundaries
and both external endpoints — the view's message half is, at each of the
1,024 message positions, one `2(G+1) × (non-data rows)` system over `Fp`:
the very matrix whose rank 2.4(a) reports. Fixing the hidden data to ZERO
and solving it exactly (one factorisation, 1,024 back-substitutions) turns
that rank into a construction.

| commitment | non-data rows | generators | rank | positions without a solution | free `Fp` per position | message entries recomputed and equal | claim values recomputed and equal |
|---|---|---|---|---|---|---|---|
| `B0`, `B1` | 6 | 6 | 6 | 0 | 0 (unique) | 3,072 / 3,072 | 2 / 2 |
| `E-Input`, `E-Output` | 5 | 4 | 4 | 0 | 1 | 2,048 / 2,048 | 1 / 1 |

`A` and `H` are **skipped, not faked**: their opening groups have several
members, so each claim's own published value is an extra constraint, and the
correction step that handles it lives in `zk60_native_pg_pcs`, whose
`MSG == PAD == 256` does not hold here. The pad half and the opened column
values are not constructed either. Both are OPEN in the channel table with
that reason.

### 2.6 Negative controls (stage 6)

Each is shown to PASS on the honest bundle first, and each makes the gate
fail. C1 and C2 perturb the MODEL (which rows are ranked, which coordinates
are one unknown); C3 adds an identification; C4 and C5 alter a JSON field or
swap a file in memory and restore it afterwards — no captured file on disk
is ever written, and a test asserts the restoration.

| control | honest | perturbed | fires |
|---|---|---|---|
| **C1** the two boundary claims share one reserved pair (the two pairs' coordinates identified) | rank 6 of 6, disclosed **0**; each claim's own figure rank 2 of 2 | rank **4** of 6, disclosed **2**; **each claim's own figure is unchanged** | yes |
| **C2** a single proximity row (`data + 2·sites + 1`) | rank 6 of 6, disclosed 0 | rank **5** of 6, disclosed **1** | yes |
| **C3** a blinding row shared between the boundary and an adjacent activation commitment (`A@0[377] ≡ B0[4]`) | parts 0,0,0; sum 0; joint 0; block diagonal | parts **unchanged** 0,0,0; sum 0; joint **1,024** (`k0 = 1`); no longer block diagonal | yes |
| **C4** a claim whose source stage is wrong (`claim_sources` swapped) | integrity ok, 0 discovery findings, 24 identified rows | integrity refuses (`claim_sources … are not the two claim sites`) and the discovery refuses to identify the planes (the site's reserved pair contradicts its claim order) | yes |
| **C5** a stage file swapped between the two bundles | replay ok, 6,086 challenges | replay refuses (first: the end tag is not the next stage's start tag), 4,577 failures; integrity refuses (the root committed in stage 0 is not the root opened in stage 1) | yes |
| **C6** one pad fewer than the distinct opened columns | H-pad holds, 249 distinct inside 256 pads | H-pad FAILS, so the ranks are no longer a disclosed dimension and the gate refuses rather than reporting a number | yes |

C1 and C2 reproduce the checker's predicted **disclosed 2** and **disclosed
1** exactly, on real captured runs rather than on a hand-built small model.
C1's honest/perturbed pair is also the sharpest statement of why M-1 matters:
a per-claim reading of a boundary cannot see a shared pair — only the joint
reading on the reserved rows can.

### 2.7 The channel table (stage 7)

23 channels: **2 constructed, 2 derived, 4 argued, 15 open**. Full text in
the record; the shape of it:

| status | channels |
|---|---|
| CONSTRUCTED | the message half of the boundaries' and endpoints' group and proximity vectors; those commitments' claim values |
| DERIVED | every Fiat-Shamir challenge of the run (6,086, re-derived); the PCS and M column indices |
| ARGUED | the Merkle roots, including the `L−1` boundary roots (M-2; a boundary root is an observed commitment and NOT part of the statement); the leaf salts (M-3); the authentication paths (M-2); **the sequencing surface** (shape facts + M-6) |
| OPEN | `A` and `H`'s vectors (multi-member groups); the pad half; the opened column values; the masked sumcheck rounds; the per-slot terminal identity; **the cross-block joint law beyond the linear rank**; **a preimage for a RUN**; **the boundary scale tags**; refusal events; rejected-but-emitted receipts; retained captures; timing/memory/power; prior proofs; the integer-range facts; any nonlinear functional |

**What is new for a run**, and what the gate says about each:

* **the sequencing surface** — the number of segments, their byte lengths
  and their position tags. ARGUED: `L` is a public word of the run statement
  (absorbed under `run-shape`), a segment's length is a function of the shape
  and of the stage's position, and the position tags are squeezed from a
  DISCARDED transcript clone, compared and never absorbed (M-6). EVIDENCE,
  not proof: the two bundles are independent runs on different hidden inputs
  and their three segment lengths agree exactly — 4,066,824 / 4,089,352 /
  4,257,256 bytes — while their segment digests differ. The lengths differ
  BETWEEN stages, so a segment's length reveals its position in the run,
  which is public.
* **the cross-block joint law beyond the linear rank** — OPEN. Obligation
  O-R3. What is computed is a RANK. That the three views of a boundary plane
  are jointly input-free needs per-commitment independent blinding (O-R2,
  verified in the code, not here) and a composition argument for a run, which
  is unwritten. The check's OMITTED CONDITION 7 — rank the two `A`s that hold
  the same plane, not the boundary alone — IS met, by 2.4(b).
* **a preimage construction for a RUN** — OPEN. Exhibited per commitment,
  message half, for four of the thirteen commitments. A run preimage is a
  joint object: it must reproduce every stage's view at once with the
  boundary planes shared between three commitments, and it needs the pad half
  and the CFS channel first.
* **the boundary scale tags and the one calibration identity** — OPEN, on
  the strength of the check's A7.5: nothing in the run's privacy section
  covers the boundary's scale/calibration binding, and D12 item 5 records
  that a tag-equality check would pass on a factor-of-8 mismatch. The gate
  reads the scales as public constants (`[0, 0]`) and checks that the run
  declares ONE calibration identity (M-4); it does not check what the tag
  proves.

---

## 3. Findings about the bundle itself

Three, none of them a privacy matter, all of them about a field's meaning.
Each names the exact field and says whether it is public.

1. **`arguments[s].tables[i].claim` is not what §4a of the format document
   says, for an IO table of a run.** The document says it is "the index of
   the claim this table raises in that commitment's claim list"; in both
   bundles every IO table carries `claim: 0`, including stage `k+1`'s slot 21,
   whose claim is index **1** of the boundary. It is evidently the index
   inside the STAGE's own `[ic, oc]` claim pair. A tool that trusted it would
   attribute both of a boundary's claims to claim 0. The gate therefore takes
   the claim index from `claim_sources`' accumulation and CROSS-CHECKS it
   against the table's `mask_row` (4 for site 0, 6 for site 1). Public data;
   a documentation fix, or an added field, would settle it.
2. **`roles[i].data_rows` counts `H`'s two zero-sum rows, `row_roles` does
   not.** For `H`, `data_rows = 470` while exactly 468 rows carry
   `kind: "data"`, the difference being `sum_rows = [468, 469]`. The gate
   uses `row_roles` for the data/non-data split (as the toy tool does) and
   records the discrepancy with the check that the difference IS the zero-sum
   pair. Public data.
3. **An external endpoint has one SPARE mask row and a boundary has none.**
   `site_rows` is `[4,5]` on a 9-row endpoint whose non-proximity mask rows
   are `{4,5,8}` — ruling M-7's "a pair, a proximity pair and a spare". A
   derived boundary has no spare (`site_rows == {4,5,6,7}` exactly). The gate
   reports `spare_mask_rows` per opening instead of demanding equality.

One thing the bundle LACKS that the gate needs, and does not guess at:

4. **The plane index table at the run's shape.** `run.json["shape"]` carries
   every geometry axis (`norm_wrho 31`, `wrho_s 17`, `f_e 12`, the pads, the
   23 slot triples) but not the A-plane and H-plane index assignment of
   `layout.rs` (`A_D … N_A`, `H_L … H_U`) nor the per-slot table push order,
   which is what the 23 terminal closures read. It is **public** — a function
   of the public layout, not of any hidden value — so the lane could add it
   without publishing anything new. Until it is there, the per-slot terminal
   identity is OPEN for a run (see §4).

   **RESOLVED the same day.** Stage 15 of the Rust lane added it as
   `run.json["plane_index"]`, and the two NEW bundles `run-c-tame` and
   `run-d-zero` carry it. §6 is what it bought: 12 of the 23 slots checked.
   A FIFTH finding took its place as the thing the bundle lacks — see §6.2:
   `public_tables_included` is `false`, so the eleven weight-, gain-,
   RoPE- and table-value-bearing slots still cannot be evaluated.

---

## 4. What remains a reviewed obligation, or is simply not done

* **The per-slot terminal check is OPEN at this shape** — as of the first
  round, on the two stage-14 bundles. **Partly closed in §6** on the two
  stage-15 bundles: 12 of 23 slots, all three stages, both bundles. The
  paragraph below is the first round's statement and is kept as written.
  The strong form
  `fin = c·mask_eval + poly(terminals)` needs the 23 composition closures
  ported at the rung geometry. `scripts/zk60_native_terminal_polys.py` is a
  hand-port of the TOY layout: its `_Layout` namespace carries that shape's
  plane index table and its `SOURCE_PINS` pin `argument.rs`, `layout.rs` and
  `protocol.rs` by SHA-256 at commit `5ca721f`, while this bundle pins
  different digests of the same files at `cb27845`. The port does not
  generalise from `run.json["shape"]` alone (§3 item 4). The toy gate still
  checks this for the four single-block captures; a run does not.
* **The CFS / masking-commitment channel is OPEN at this shape.**
  `zk60_native_jv_cfs` and `zk60_native_mask_commit` are written at the toy's
  row layout and slot specs. What IS computed is `M`'s part in the joint
  system: a block with `2S + 4 = 50` rows, no data row, one published row
  combination, and a computed part of 0.
* **The equality of every Python port with its Rust source remains a
  reviewed obligation, established by reading.** That covers the transcript,
  `absorb_root`, `zpart_weights` / `zkey_weights` / `group_zclaims` and
  `encode_row_zk`. The replay is the one place where reading is backed by
  machine agreement: 6,086 challenges and 375 positions reproduce, which
  would not happen if the port were wrong.
* **O-R2, per-commitment independent blinding**, is verified in the Rust
  (check A7.2) and assumed here.
* **D8/D11, the caller-fixed endpoint-root obligation**, is untouched and
  remains open.

---

## 5. WHAT IT DOES NOT SHOW

* It is about the **linear channels of two captured three-block runs at one
  development shape** — 24 tokens, width 96, hidden 192 — at those runs'
  real challenges. Two runs are not a distribution.
* **It says nothing about the 125M shape.** There, exact rank over thousands
  of rows per commitment is a different computation, and this gate has not
  been run on it: the largest matrix ranked here is 308 × 3,761.
* **The hash layer is ARGUED, not computed.** The Merkle roots, the leaf
  salts and the authentication paths are hash objects; they rest on M-2 and
  M-3, and no linear algebra covers them.
* **The joint-law composition for a run is unwritten.** A rank of zero over
  a linear model is not a statement that the run's view is independent of the
  witness; it is evidence about that model at those challenges.
* **The per-slot terminal identity is not checked** on the two stage-14
  bundles, so the nonlinear link between the commitment and masking channels
  is outside everything in sections 1–5. On the stage-15 bundles it is
  checked for 12 of the 23 slots (§6) and open for the other eleven; even
  there, the DISCLOSURE model of §2.3 and §2.4 stays linear.
* **It is NOT a privacy acceptance**, and it establishes no privacy
  property. Ruling M-8 asks for this gate; passing it is one input to a
  decision that is the security owner's and, for the run's soundness level
  and its receipt size, the project owner's.

---

# 6. 2026-09-20, second round: the PLANE INDEX TABLE and the per-slot terminal identity

**Written 2026-09-20 14:45 PDT on the same lane.** Stage 15 of the Rust
lane added `run.json["plane_index"]` — the one field §3 item 4 above asked
for and would not guess at — and wrote two NEW bundles that carry it:
`run-c-tame` and `run-d-zero`. `run-a-tame` and `run-b-zero` predate it, and
the four are **four different runs**, not one run with a field added.

New tools, all new files (no toy gate's bytes were touched):
`scripts/zk60_native_rg_planes.py` (the table, read and integrity-checked),
`scripts/zk60_native_rg_terminals.py` (the identity), 
`scripts/zk60_native_rg_tcontrols.py` (its controls),
`scripts/zk60_native_rg_recdiff.py` (a record diff). They are stage 8 of
`scripts/zk60_native_run_gate.py`. Evidence:
`results/zk60_native_run_gate_planeindex/`.

> **STILL NOT A PRIVACY ACCEPTANCE AND STILL NO PRIVACY PROPERTY.** What
> this round adds is the VERIFIER'S OWN final check, recomputed from the
> published terminals at the runs' real challenges. That the receipt is
> self-consistent says nothing about what it discloses. The disclosure
> figures of §2.3 and §2.4 are unchanged and are still ranks of a linear
> model at ONE development shape.

## 6.1 The table, and what is checked about it

`run.json["plane_index"]` gives, for every committed `A` and `H` plane, its
id, name, domain, row range and own domain log, and for every slot the
ORDERED list of planes whose evaluations that slot's `terminals` carries.
Everything in it is public: it says where a plane lives and what it is
called, never what is in it.

| check | `run-c-tame` and `run-d-zero`, identically |
|---|---|
| `A` planes tile `[0, a_data_rows)` exactly, no gap, no overlap | **83** planes, **377** rows |
| each `H` plane's two halves (`re`, `im`) tile `[0, h_data_rows)` exactly | **52** planes, **470** rows |
| `offset == first_row · cols` (and the same for both `H` halves) | holds for all 135 planes |
| the totals against each stage's OWN `A` / `H` opening `data_rows` | equal, all three stages |
| one log per domain, no plane of a domain disagreeing | `T 5, Ht 8, L 10, D 12, Q 12, Kv 10, S 13, F 13, Tab 10` |
| every id a slot names exists and has the role the slot claims | yes |
| every committed plane is read by at least one slot | yes |
| `len(terminals) == len(planes)` per slot per stage | **176 = 176**, all three stages |
| every private table's slice offset lies INSIDE the plane it names | **226 of 226**, all three stages |

The last row is the one that makes the identification a check rather than a
relabelling: the stage file's own `slices[].offset` must land in the row
range the table gives the plane. A plane read on a sub-slice (`SC_TZC`'s
nine limb sub-planes) or at a flipped coordinate is containment, not
equality, so the test is containment.

Two further facts, both computed: the table is **byte-identical in the two
independent bundles** (it is a function of the public shape; the runs'
bindings differ), and an OLD bundle loads exactly as before, with the
channel left OPEN and the reason it had.

## 6.2 The identity, per slot

The check is the verifier's own last step,
`fin_s == c_s·mask_eval_s + poly_s(vals_s)`
(`argument.rs:381`), with `poly_s` recomputed from the PUBLISHED terminals
and `vals_s` built the way the verifier builds it: `sel·eq_point(...)` for
an `eq` table, `sel·eval_mle_ext(...)` for a public table, the published
terminal for a private one. The capture writes
`terminal_polynomial = fin − c·mask_eval`, so the recomputed polynomial is
compared against that field too. Both comparisons must hold.

**Twelve of the twenty-three slots are evaluated and compared, in every
stage — 36 of 36 checks per bundle, all equal, all matching the stored
`terminal_polynomial`:**

| slot | name | what it covers that the toy did not have |
|---|---|---|
| 00 | `SC_SS` | the `supp(Dom::D)` gate |
| 01 | `SC_SSM` | the same, on `norm_m` |
| 02 | `SC_TZC` | the pad-zero term on `Dom::T` (four planes batched on `ζ`), the `supp(T)` gate on both host terms |
| 03 | `SC_LZC` | the pad-zero term on `Dom::L` — the one domain with NO closed-form indicator |
| 04 | `SC_RS` | the causal mask and the `supp(Dom::S)` gate |
| 08 | `SC_SCORE` | GQA: the key-value factor at the QUERY head's group bits (C-1 / trap T-3) |
| 09 | `SC_PV` | the same, on the value side |
| 17 | `SC_SZC` | the rung's THIRD `sigma_s` limb (`A_SR2`, `A_SG2`), and the only slot that hosts two domains — `Dom::Ht`'s lifted indicator with its own pad-zero group (finding S9-F7) |
| 18 | `SC_FZC` | the `Dom::F` pad-zero term and the ungated activation-pair LogUp arm |
| 20 | `SC_ZS` | the zero-sum row on the lifted `Dom::Tab` cube |
| 21 | `SC_IO_IN` | **a run's boundary claim site**: in every stage but the first, the IO table is an internal BOUNDARY at the reserved pair the stage's position implies |
| 22 | `SC_IO_OUT` | the same, the outgoing site |

Slots 21 and 22 are worth naming twice: with three stages, both claim sites
of both boundaries (`stage k` slot 22 and `stage k+1` slot 21) are inside
the checked set, so the equality the whole boundary construction rests on is
now recomputed, not just ranked.

**Eleven slots stay OPEN, and the reason is NOT the plane index.** It is
that `run.json["public_tables_included"]` is `false`: a bundle carries a
public table's length and SHA-256 but not its values, and these slots' tables
are not functions of the shape.

| slots | the table that is missing |
|---|---|
| 05 `SC_QMM`, 06 `SC_KMM`, 07 `SC_VMM`, 10 `SC_WO`, 11 `SC_GMM`, 12 `SC_UMM`, 13 `SC_DMM` | `fold_rows_i8` / `fold_cols_i8` of a public WEIGHT matrix at the round's point |
| 14 `SC_DZC` | the two padded norm GAIN vectors `gamma_a`, `gamma_m` |
| 15 `SC_QZC`, 16 `SC_KVZC` | the RoPE `(cos, sin)` pair |
| 19 `SC_TAB` | the exp and activation lookup TABLE VALUES (two of its four public tables; the other two are rebuildable) |

Nothing HIDDEN is missing from any of them — every one is a function of the
public statement. A re-capture with `HL_RUN_CAPTURE_PUBLIC_TABLES=1`, or a
bundle that carried the weights, closes all eleven without publishing
anything new. **That is the single next step for this channel.**

## 6.3 What is rebuilt, and why it is not taken on trust

The public tables that ARE a function of the shape are rebuilt in Python
from a port of `pad.rs` and `argument.rs::causal_mask_at`, and each is
compared with **the capture's own SHA-256 of the real one** before it is
used — 11 table instances per stage, every digest matching: `supp(T)`,
`supp(Ht)`, `supp(L)`, `supp(D)`, `supp(S)`, `supp(F)`, the causal mask and
`SC_ZS`'s all-ones `Dom::Tab` vector. That is a machine check of the
pad-rule port itself, not a reading. A separate test also shows the closed
multilinear form and the support oracle agree entry for entry on the eight
domains that have a closed form, and that `Dom::L` has none — exactly what
the memo says.

The reading that is NOT machine-checked is each ported polynomial against
its Rust closure. It is pinned rather than trusted: the bundle's own
`manifest.json["source_pins"]` names `argument.rs 909670c9`,
`layout.rs fec2e647`, `protocol.rs 4e916c69` and `plane_index.rs 9de8320a`,
and those are exactly the digests the port declares it was read at. A pin
that moved makes **every slot NOT CHECKED** rather than silently wrong, and
a test asserts that.

## 6.4 The controls

Each is shown to pass honest first, and the record says WHICH check fired.

| control | what | fires | how |
|---|---|---|---|
| **CT-1** | one captured terminal changed by +1 (stage 1, slot 17, terminal 3) | yes | the identity fails at **exactly** that slot and stage — 35 of 36 — and nowhere else; the transcript replay refuses the same bundle independently, because `pb-term` absorbs the terminals |
| **CT-2** | two entries of slot 17's plane list SWAPPED (`A_SR0` / `A_SR1`: same domain, same row count) | yes | three ways — the port refuses the push order; with that check DROPPED the identity itself fails at slot 17 in **all three** stages; and the loader refuses, because the slice offsets no longer lie in the planes the list names |
| **CT-3** | slot 17's `A_SR0` entry RE-POINTED at `A_SG0` (same domain, same rows) | yes | the loader refuses on the slice offset (`243712 is outside plane 66 (A_SG0), rows 262..270`) and the port cannot evaluate the slot in any stage. A second form, `id` moved with the name kept, is caught by the loader's name-against-id cross-check |
| **CT-4** | an OLD bundle (`run-a-tame`, no table) | yes | the channel stays OPEN with the reason the gate had before, no slot is reported checked, and the stage is not a failure — a missing input is not a broken gate |
| **CT-5** | one entry of the rebuilt `supp(Dom::S)` flipped 1 → 0 | yes | the capture's own SHA-256 refuses it, so the port never evaluates a polynomial the verifier did not evaluate |

CT-2 is the sharpest: a swap that no count can see (same domain, same size,
same slot, same polynomial) changes which terminal each factor reads, and
the arithmetic catches it in every stage.

One more perturbation, asserted in the tests rather than in the gate: a
terminal of an UNCOVERED slot (15, `SC_QZC`) is changed and **nothing the
gate reports moves** — the port does not silently claim a slot it never
evaluated.

## 6.5 The channel table, recounted

Counted from the tool's own `stage7_channels.channels` array, not by hand.
The terminal-identity channel is now TWO entries, because one status cannot
honestly describe a channel that is 12/23 evaluated:

| bundle | total | constructed | derived | argued | **open** |
|---|---:|---:|---:|---:|---:|
| `run-c-tame`, `run-d-zero` | **24** | 2 | **3** | 4 | **15** |
| `run-a-tame`, `run-b-zero` (re-run) | **24** | 2 | 2 | 4 | **16** |
| `run-a-tame`, `run-b-zero` (before this round) | 23 | 2 | 2 | 4 | 15 |

The open COUNT does not fall, and that is the honest reading: half a channel
closed and half a channel named. What moved is inside the entry — the
DERIVED half now carries the derivation (36 of 36 slot checks) and the OPEN
half carries one precise reason for eleven named slots instead of "the plane
index table is missing".

For the two OLD bundles **nothing measured changed**:
`results/zk60_native_run_gate_planeindex/old_bundles_unchanged.json` shows
21 of their 23 channel entries byte-identical (the terminal channel split in
two, both OPEN for them; the nonlinear-functional channel gained a sentence),
and the leaf-by-leaf diffs show **2,189 identical leaves** each, with the
only changes being the tool hashes, the new stage-8 block saying the table is
absent, the channel split (which shifts every later entry's index), three
wall-clock leaves and one sentence of `what_it_does_not_show`. No rank,
disclosed dimension, challenge count or control figure moved.

## 6.6 The suite

`python3 -m unittest discover -s tests -p 'test_zk60_native*.py'`:
**232 tests, OK**, one skip and one recorded expected failure, 227.8 s —
against **193** before this round. The 39 new ones are
`tests/test_zk60_native_run_gate_planeindex.py`, in the two arms this lane
already uses: a RECORDED arm that asserts every figure quoted above from the
tracked evidence (and that the evidence was produced by the tool bytes now
in the tree), and a LIVE arm that is skipped when the ~38.5 MB bundles are
absent. The whole live arm runs in 5.5 s, so nothing here needs a
`skipUnless` for time.

## 6.7 What this round is NOT

* **Linear channels only, still.** Recomputing the terminal identity does
  not make the disclosure model nonlinear. §2.3 and §2.4's figures are the
  same ranks of the same linear model; the "any nonlinear functional"
  channel stays OPEN and now says so in those words.
* **Two runs, one development shape.** `run-c-tame` and `run-d-zero` are two
  captured runs at 24 tokens, width 96, hidden 192. Two runs are not a
  distribution.
* **Nothing about the 125M shape.** The port is shape-driven — every count
  comes from `run.json["shape"]` or from the plane index table — but it has
  been RUN at one shape, and `f_e`, `norm_wrho` and `wrho_s` move at 125M
  while `SH_S`, `SH_G`, `SH_H_PROD`, `F_P` and `NORM_CEPS` are read here as
  fixed calibration constants of `layout.rs`. At a shape where one of those
  moved, the identity would simply fail; it would not be silently wrong.
* **Eleven of twenty-three slots are not checked at all**, and the nonlinear
  link between the commitment and masking channels is therefore covered for
  twelve slots and not for eleven.
* **Not a privacy claim.** The verifier's own check passing is a statement
  about the receipt's self-consistency. Ruling M-8, D8/D11 and the run's
  joint-law composition are untouched by this round.

---

# 7. 2026-09-20, third round: the KEYED HASH RULE (D19) and the last eleven slots

**Written 2026-09-20 17:20 PDT on the same lane.** Two things landed on the
Rust lane and they are independent of each other:

* **Stage 17** put decision D19's **separating hash tag** into the code. On
  a TAGGED profile — and the development rung is one — every BLAKE3 call is
  in KEYED mode under one of four public 32-byte keys, each
  `blake3.derive_key(<context>, <block profile>)`. Every proof byte of
  those profiles moved once.
* **Stage 18** re-took the bundles under the tag **with the public tables'
  values**: `run-e-tame-tagged`, `run-f-zero-tagged`. The four earlier
  bundles are LEGACY-rule bundles and are superseded for gate purposes.

New tools, all new files: `scripts/zk60_native_rg_hashrule.py` (the rule,
the four derived keys, a KEYED transcript, keyed column / leaf / node, and
the comparison with what a bundle declares), `scripts/zk60_native_rg_
hashlayer.py` (stage 9 — every opened column re-hashed and re-authenticated),
`scripts/zk60_native_rg_hcontrols.py` (the rule's six controls),
`scripts/zk60_native_rg_recclass.py` (the old-bundle diffs, classified).
Evidence: `results/zk60_native_run_gate_tagged/`.

> **STILL NOT A PRIVACY ACCEPTANCE AND STILL NO PRIVACY PROPERTY.** Which
> BLAKE3 made a receipt is not a statement about what it discloses, and
> neither is the receipt's self-consistency. Every disclosure figure of
> §2.3 and §2.4 is **unchanged** — that is itself one of this round's
> results: the tag moved every proof byte and not one rank.

> **CORRECTION, 2026-09-20 (round 4), ruling R-3**, applying to every joint
> figure quoted in §6 and §7 as it does to §2.4: `joint == sum of the
> parts` is a consistency check of the model's coordinate classes, not
> evidence of independent blinding — two distinct blinding rows whose
> values coincide score like an honest run. See the correction block in
> §2.4. No figure of round 2 or round 3 moves.

## 7.1 The rule, and the one rule about the rule

The gate **derives** the key set itself. The four context strings and the
list of LEGACY profiles (a denylist of two: the byte-frozen toy and the
frozen-seam rung, so a profile the tool has never heard of is TAGGED — the
fail-safe direction) are pinned in `zk60_native_rg_hashrule.py`'s own
source; the keys come from the profile the bundle's own SHAPE names. Only
then is the bundle's `hash_tag` member read, and only to be COMPARED:
rule name, profile, four contexts, four keys. **Re-derive, never consume**
(ruling T-7). A key is never taken from a bundle and used.

| check, both tagged bundles | figure |
|---|---|
| rule derived from the shape's profile | `blake3-keyed/1` |
| keys re-derived here and compared with `keys_hex` | **4 of 4** |
| contexts compared with the ones pinned in the tool | **4 of 4** |
| the declared profile against the shape's | equal |
| the run profile (the transcript DOMAIN) against the block profile (the KEYS) | different strings, as the design says |
| refusals | none |

The keyed transcript is a **subclass** of the toy module's `Transcript`:
`zk60_native_jv_field.py` is pinned byte for byte by
`tests/test_zk60_native_gate_record.py`, so the keyed rule could not be
written into it, and subclassing is also the statement that only the hash
FUNCTION differs — the absorb framing, the counter and the challenge
decoding are inherited unchanged. The clone carries the key, which is what
the segment position tags are squeezed from (`clone_state`,
transcript.rs:156).

**One path does not compare, and it is named.** A bundle written before
stage 17 has no `hash_tag` member at all. Its bytes are the legacy rule's
whatever its profile is now, so it is replayed under the legacy rule and
marked **SUPERSEDED**: a pre-tag bundle of a tagged profile is the
verifier's view of a run made under a rule this profile's code no longer
uses, and nothing measured on it is a statement about what the profile
produces today. Control CH-5 shows that path cannot be abused — delete the
member from a TAGGED bundle and the replay fails on the bytes.

## 7.2 The replay under the tag

Round 1's counts, exactly, under another hash function:

| | round 1 (legacy) | round 3 (tagged) |
|---|---|---|
| run binding | reproduced | **reproduced** |
| transcript positions compared as (state, next challenge) | 375 | **375** |
| challenges re-derived and compared | 6,086 | **6,086** |
| final transcript counter | 6,918 | **6,918** |
| segment position tags, from a DISCARDED clone | 6 of 6 | **6 of 6** |
| challenges NOT re-derived | none | **none** |

Nothing is left un-re-derived, and the three segment byte lengths are the
same 4,066,824 / 4,089,352 / 4,257,256 as in rounds 1 and 2 — the tag moves
the bytes' VALUES and not the receipt's size, which is what `hashtag.rs`
says and is now a measurement.

## 7.3 The hash layer, computed rather than argued (stage 9, new)

Three of D19's four keys never touch the transcript, so a gate that only
replayed Fiat–Shamir would exercise ONE key and take the other three on the
bundle's word. Stage 9 computes them on real bytes:

    leaf_j   = H_column(column j's little-endian Fp bytes)      pcs.rs:148
    salted_j = H_leaf(leaf_j || salt_j)                          pcs.rs:691
    fold     = H_node(left || right) up the path                 merkle.rs:28
             == the commitment's root

| | both tagged bundles |
|---|---|
| openings re-hashed (M, A, H, Input, + Output in the last stage) | **13** |
| opened columns re-hashed and re-authenticated | **3,328 of 3,328** |
| path lengths checked against the tree depth 12 (`verify_zk_tagged`'s own first check) | **3,328** |
| bytes hashed | 7,751,680 |
| cross-rule probe on one column: wrong rules tried | **4**, none reached the root |

**What this does and does not move.** The Merkle roots, the leaf salts and
the authentication paths stay **ARGUED** in the channel table, because what
that channel is about is HIDING — what an unopened leaf reveals is M-2's
assumption either way. What stage 9 adds is the soundness-side fact that
the opened columns really are this run's own, under the rule the profile
implies, and the evidence that the BYTES were made under the tag rather
than merely declared to be.

## 7.4 All twenty-three slots

`public_tables_included` is true, so the eleven slots §6.2 left OPEN are
ported and evaluated. `argument.rs` — the file that decides what a slot's
polynomial IS — is **byte-identical** at the stage-15 and stage-18 commits,
so no earlier port is in question; `layout.rs`, `protocol.rs` and (newly
pinned) `shape.rs` moved, each diff was read line by line, and each is the
hash-tag plumbing and the T-3 / T-4 path-length checks with nothing this
port reads changed. The two moved digests are accepted BY NAME with that
reason; any other move still makes every slot NOT CHECKED.

| slot | name | what closed it |
|---|---|---|
| 05, 06, 07 | `SC_QMM`, `SC_KMM`, `SC_VMM` | `fold_rows_i8` of the query / key / value weights |
| 10 | `SC_WO` | `fold_rows_i8` of the output projection |
| 11, 12 | `SC_GMM`, `SC_UMM` | `fold_cols_i8` of the gate / up weights |
| 13 | `SC_DMM` | `fold_cols_i8` of the down weights |
| 14 | `SC_DZC` | the two padded norm GAIN vectors (the eleven `Dom::D` clauses, hosting `SC_WO` and `SC_DMM`) |
| 15, 16 | `SC_QZC`, `SC_KVZC` | the RoPE `(cos, sin)` pair (the partner slice at the flipped bit, trap T-8) |
| 19 | `SC_TAB` | the exp and activation lookup tables' VALUES (the byte table is rebuilt here) |

| | round 2 | round 3 |
|---|---|---|
| slots evaluated | 12 of 23 | **23 of 23** |
| slot checks equal, every stage | 36 of 36 | **69 of 69** |
| matching the capture's own `terminal_polynomial` | 36 | **69** |
| slots OPEN | 11 | **0** |

### A captured table is not taken on trust

Three checks stand between a carried table and the polynomial that reads it.

1. **Its own length and SHA-256.** Every public table of every slot of
   every stage: **93 of 93** per bundle, over the concatenated 16-byte
   little-endian `Fp2` encodings (`run_capture.rs:788`).
2. **Rebuilt where the shape allows it.** Sixteen tables per stage are
   still rebuilt in Python and digest-compared — the seven `supp`
   indicators, the causal mask, `SC_ZS`'s all-ones vector, and now
   `table_values_u8_at` and the `supp` tables of the four new zero-check
   slots. These are never taken.
3. **The structure its builder gives it**, 45 checks per bundle: a weight
   fold vanishing off its own input support (ruling P-2), a norm gain
   periodic in the padded width and zero off it, the RoPE pair's zero set
   and its partner symmetry (`cos` repeats, `sin` negates), and a lookup
   table periodic in the byte class after the P-3 lift with a small
   BASE-FIELD integer recovered from every one of its 256 entries.

**What it does NOT establish, and this is the honest limit of the round:**
that a folded weight table is the fold of the weight matrix the statement
names. No bundle carries a weight. The port checks the capture's own
length, digest and structure, and the identity at the run's real
challenges — and no more. It is stated in the record itself
(`what_a_captured_table_does_not_establish`).

Check 3 did real work on the first run: it refused `SC_WO`, because a
weight fold's live index range is not always the width. The output
projection is indexed by the **padded head slots**, and the fold is nonzero
exactly on slots {0,1,2,4,5,6} × 16 = `[0,48) ∪ [64,112)`, which is above
the width at its top end and zero below it. The check now knows the three
supports (width, heads, hidden) and says which one it used.

## 7.5 The controls

Fourteen, **all firing** on both bundles: CT-1 … CT-5 as in round 2, plus

| control | what | fires |
|---|---|---|
| **CT-6** | one value of a captured public table changed by +1 | the capture's own SHA-256 refuses it; the slot is not reported checked |
| **CT-7** | the same, with the digest check dropped (in the control only) | the identity fails at **exactly** stage 0 slot 5 and nowhere else |
| **CT-8** | one terminal of a NEWLY checked slot (14, `SC_DZC`) perturbed | fails at exactly that slot and stage — the new ports are load-bearing |
| **CH-1** | one declared key replaced by zeros | refused by name; the other three still compare |
| **CH-2** | one character added to a declared context string | refused by name against the tool's own pins |
| **CH-3** | the tag's profile replaced by the 125M profile's | refused by name against the shape's profile |
| **CH-4** | the bundle renamed `legacy` while its profile is tagged | refused by name — and with the legacy rule actually computed, the run binding does not reproduce (**6,854** replay failures) and **0 of 3,328** columns authenticate |
| **CH-5** | the whole `hash_tag` member removed | read as pre-tag and marked SUPERSEDED, and the replay then fails on the bytes |
| **CH-6** | a legacy bundle's columns checked under the rung-G tag | 3,328 of 3,328 under the legacy rule, **0** under the tag |

CH-4 is the sharpest of the round: it separates "the bundle says it is
tagged" from "the bytes were made under the tag", and only the second is
evidence.

## 7.6 The channel table, recounted

Counted from the tool's own `stage7_channels.channels` array.

| bundle | total | constructed | derived | argued | **open** |
|---|---:|---:|---:|---:|---:|
| `run-e-tame-tagged`, `run-f-zero-tagged` | **25** | 2 | **5** | 4 | **14** |
| `run-c-tame`, `run-d-zero` (re-run) | 25 | 2 | 4 | 4 | 15 |
| `run-a-tame`, `run-b-zero` (re-run) | 25 | 2 | 3 | 4 | 16 |
| round 2's table on the stage-15 bundles | 24 | 2 | 3 | 4 | 15 |

Two things moved and they are separate. One entry was **added** — the hash
RULE of the run, which is a new part of a tagged run's public view and is
DERIVED (the keys are public functions of public strings, re-derived here,
and the bytes are shown to be under them). One entry **closed**: the half
of the terminal channel that round 2 split off for the eleven
table-bearing slots is DERIVED now, so the open count falls from 15 to 14.

The fourteen that remain open are unchanged in kind: `A` and `H`'s vectors
(multi-member groups), the pad half, the opened column values, the masked
sumcheck rounds, the cross-block joint law beyond the linear rank, a
preimage for a RUN, the boundary scale tags, refusal events,
rejected-but-emitted receipts, retained captures, timing/memory/power,
prior proofs, the integer-range facts, and any nonlinear functional.

## 7.7 The four superseded bundles

Re-run under round 3 and diffed leaf by leaf against their round-2 records
(`results/zk60_native_run_gate_tagged/old/`): **0 unclassified differing
leaves** on all four, with 2,222 / 2,223 / 2,831 / 2,831 identical leaves.
Every difference is a wall clock, a tool SHA-256, one of the two new record
blocks (`hash_rule`, stage 9), the replay naming its rule, the new and
empty fields about captured tables, the reworded OPEN reason of the eleven
slots, or the insertion of one channel entry (which shifts every later
index). **No rank, disclosed dimension, challenge count, slot check or
control figure moved.** The classifier is a tool
(`zk60_native_rg_recclass.py`), not a reading.

## 7.8 The suite

`python3 -m unittest discover -s tests -p 'test_zk60_native*.py'`:
**261 tests, OK**, one skip and one recorded expected failure, 234.1 s —
against **232** before this round. The 29 new ones are
`tests/test_zk60_native_run_gate_tagged.py`, in three arms: a PURE arm that
needs no bundle (the eight pinned keys re-derived, keyed against unkeyed
transcripts, the three roles separating under the tag and the leaf/node
ambiguity that exists under the legacy rule), a RECORDED arm asserting
every figure above from the tracked evidence, and a LIVE arm skipped when
the ~41 MB bundles are absent. Two round-2 assertions had to move and only
two: the channel total (24 → 25) and the shape of the covered-slot
statement (every slot now HAS a port; eleven need a carried table). The toy
gates' record guard still passes and no toy file's bytes were touched.

## 7.9 What this round is NOT

* **Not a privacy claim, again.** Ruling M-8's decision, D8/D11 and the
  run's joint-law composition are untouched, and `privacy_review_complete`
  is `false` in the bundles and in every record.
* **The disclosure model is still LINEAR and still one shape.** §2.3 and
  §2.4's figures are the same ranks of the same model on two captured runs
  at 24 tokens, width 96, hidden 192. Two runs are not a distribution.
* **The hash layer's HIDING is still argued.** Authenticating an opened
  column says nothing about what an unopened leaf hides.
* **The keyed rule is an idealisation.** D19 reads BLAKE3's modes as a
  family of independent random functions indexed by mode and key; distinct
  profiles share a key only with NEGLIGIBLE probability, not never (ruling
  T-1 as amended). Nothing here tests that assumption; the gate computes
  under it.
* **Nothing about the 125M shape.** The port is shape-driven, but it has
  been RUN at one shape. The m125 profile's four keys are re-derived and
  pinned in the tests, and that is the only 125M fact here.
* **A weight fold is the capture's.** See §7.4: no bundle carries a weight,
  so "this is the fold of the statement's matrix" is not established by
  anything in this round.

---

# 8. 2026-09-20, fourth round: the REPAIRED bilinear slots, and the first NON-DEGENERATE witness

**Written 2026-09-20 21:30 PDT on the same lane.** Evidence:
`results/zk60_native_run_gate_s20/`. New tools:
`scripts/zk60_native_rg_gqa.py` (the group factor) and
`scripts/zk60_native_rg_gcontrols.py` (GQ-1 … GQ-6); the comparison tool
`scripts/zk60_native_rg_witcmp.py` sits beside the gate rather than in it.

Two things landed, and they are not the same kind of thing.

* **A COMPLETENESS defect was found and repaired** in the two bilinear
  attention slots, 08 `SC_SCORE` and 09 `SC_PV` — finding S19-F1, the
  security owner's disposition `ZK60_BLOCK125M_S19F1_DISPOSITION.md`.
  Under grouped-query attention the key-value GROUP bits of the head
  challenge were FIXED coordinates of BOTH private factors. A product of
  two multilinear extensions that share a variable is quadratic in it, so
  prover and verifier computed different polynomials the moment two
  key-value groups carried different data, and the verifier refused an
  HONEST proof. Soundness was not weakened (argued by the owner,
  confirmed independently). The repair (lane stage 20) makes the group
  bits SUMCHECK VARIABLES `rho(0..lkv)` shared by both factors, with a
  PUBLIC factor `eq(r_g, ·)`, `lkv = clog2(kv_heads)` more main rounds and
  one more degree.
* **Every bundle this gate has ever read used a DEGENERATE witness.**
  `run-a` … `run-f` used the lane fixture, whose normalised hidden state is
  identical in every attention head, or the all-zero input. The defect
  turned on exactly that. So no disclosure or rank figure in §§1–7 was ever
  taken on a witness that varies across heads, and round 4's real job is
  not the port — it is re-establishing every one of those figures on a
  witness that does.

> **STILL NOT A PRIVACY ACCEPTANCE AND STILL NO PRIVACY PROPERTY.** A
> dense witness makes these figures worth more than a degenerate one did;
> it does not turn a rank of a stated linear model at one shape into a
> privacy property. Both bundles carry `privacy_review_complete: false`
> and so does every record.

## 8.1 The two bundles, and how the definition is chosen

| bundle | witness (the capture's README — see §8.9) | argument |
|---|---|---|
| `run-g-dense-s20` | **fully dense public weights, a non-constant hidden input, the two key-value groups carrying different data in every block** | repaired |
| `run-h-zero-s20` | the all-zero hidden input | repaired |

Both pin `argument.rs dd8469cb` where the stage-18 bundles pin `909670c9`,
and **that digest is what selects which definition of slots 08 and 09 the
port evaluates.** The alternative — "does the bundle carry an `eq`
table?" — would be consuming the prover's own claim about its schedule.
Both digests are definitions this port has READ
(`ARGUMENT_DEFINITIONS`); any other digest still makes every slot NOT
CHECKED, and control GQ-5 shows the wrong definition cannot be smuggled in
either direction. `layout.rs`, `protocol.rs` and `plane_index.rs` are
byte-identical to round 3's pins; `argument.rs`'s whole diff is the two
slots, the `B::group_eq` helper and a `#[cfg(test)]` accessor, and
`shape.rs`'s is the two slots' dims plus finding F-2's named refusal —
both of which this port **derives for itself** and compares, so it does not
take the moved file's word for either.

## 8.2 The group factor: derived, compared, never consumed

`eq(r_g, ·)` is a VERIFIER-COMPUTED table. A gate that read its point out
of the bundle would be checking the prover's arithmetic against the
prover's own claim. So the tool derives everything and compares:

| check, both bundles | figure |
|---|---|
| the geometry, from `run.json["shape"]` alone | `lt = lg(t_pad) = 5`, `lh = lg(h_pad) = 3`, `ldh = lg(head_dim) = 4`, **`lkv = clog2(kv_heads) = 1`** |
| each slot's `(main, extension, degree)` derived, and compared with the slot's own declaration AND with the shape's `slots` array | **6 of 6** — slot 08 `(5, 2, 3)`, slot 09 `(6, 2, 3)` (were `(4, 2, 2)` and `(5, 2, 2)`) |
| each slot's definition-draw count derived and compared | **6 of 6** — 13 and 12 |
| `r_g = r_h[..lkv]` taken from the REPLAY's own re-derived definition challenges and compared entry by entry with the bundle's `Tab::Eq` (kind, `start = 0`, length) | **6 of 6** points, 6 entries |
| both private factors' WHOLE coordinate lists re-derived — which axis is a summed `rho`, which is a fixed challenge, and WHICH challenge | **12 of 12** lists, **135** entries, of which **69** fixed coordinates compared with a re-derived challenge |
| refusals, failures | none |

The derived point is what the identity evaluates; the declared one is only
ever compared, and `vals` refuses the slot outright if the two disagree
(ruling T-7, as round 3 applied it to the hash keys).

The coordinate lists are where the repair actually shows. Written out at
this shape, with `r_h = dc[0:3]`, `r_t = dc[3:8]`, `r_j = dc[8:13]`:

    A_QR8  fixed(r_t) ‖ rho(0..1) ‖ fixed(r_hj) ‖ rho(1..5)
    A_KR8  fixed(r_j) ‖ rho(0..1)              ‖ rho(1..5)

Before the repair the group bit `dc[0]` appeared as a FIXED coordinate of
both factors; after it, the same summed variable `rho(0)` appears in both.
A pure test asserts exactly that as a property of the two schedules, and
another asserts the property the repair had to keep: at `kv_heads == 1`
the two definitions are the SAME schedule, the same dimensions and no
public table — which is why the frozen toy did not move a byte.

## 8.3 The replay under the repaired schedule

| | round 3 | round 4 |
|---|---|---|
| run binding | reproduced | **reproduced** |
| transcript positions as (state, next challenge) | 375 | **375** |
| challenges re-derived and compared | 6,086 | **6,092** |
| final transcript counter | 6,918 | **6,924** |
| segment position tags, from a discarded clone | 6 of 6 | **6 of 6** |
| challenges NOT re-derived | none | **none** |
| segment byte lengths | 4,066,824 / 4,089,352 / 4,257,256 | **4,067,160 / 4,089,688 / 4,257,592** |

`+6` challenges is exactly `lkv` per bilinear slot per stage (1 × 2 × 3);
`+336` bytes per stage is exactly the figure the S19-F1 disposition
counted. Neither was read from anywhere: the round counts and degrees come
from the shape, and the replay compares every one.

## 8.4 The twenty-three slots, under the new definition for two of them

**23 of 23** slots, **69 of 69** checks equal and matching the capture's own
`terminal_polynomial`, **0** open, on both bundles — round 3's figures,
with slots 08 and 09 now closed under `eq(r_g, ρ_g) · X · Y` instead of
`X · Y`. The carried public tables are checked as in §7.4: 93 per bundle
against the capture's own `len` and SHA-256, 16 per stage rebuilt and
digest-matched, 45 structure checks.

## 8.5 The headline: dense against degenerate

`witness_comparison_dense_vs_zero.json` — **173 figures compared, 153
identical.** Every one of the 20 that differ is a count of DISTINCT
sampled columns, or the pad margin (256 minus it), or the pad block's exact
rank (which equals it). Those columns are drawn from the transcript, so
they move with the randomness and not with the witness.

**Not one rank, disclosed dimension, joint figure, boundary figure,
preimage figure, terminal check, public-table count, hash-layer count,
channel count or control figure differs between the dense witness and the
zero one.** Against round 3's `e` / `f` the only further differences are
the repair's own cost (§8.3) and the group-factor figures, which exist only
under the repair.

| figure | `g` dense | `h` zero | `e` fixture (round 3) | `f` zero (round 3) |
|---|---|---|---|---|
| `A` disclosed, each stage | **0** | 0 | 0 | 0 |
| `H` disclosed, each stage | **2** | 2 | 2 | 2 |
| boundaries, endpoints, `M` disclosed | **0** | 0 | 0 | 0 |
| `rank_P1` — `A` 74 of 623 rows, `H` 20 of 576, endpoints 4 / 6 | same | same | same | same |
| each boundary on its reserved rows: 10 rows, 6 generators, rank 6 | disclosed **0** | 0 | 0 | 0 |
| three-role joint (`A@k`, `B_k`, `A@k+1`), 154 generators | **0** = sum 0 | 0 = 0 | 0 = 0 | 0 = 0 |
| the whole run, 308 × 3,761 | joint **6** = sum 6 | 6 = 6 | 6 = 6 | 6 = 6 |
| zero-data preimage, message half | 4 commitments, 0 free `Fp` per position | same | same | same |
| distinct opened columns (stage 0, `A`) | 252 | 250 | 250 | 242 |
| pad block: distinct columns = exact rank, full rank | 249 | 248 | 248 | 246 |
| terminal identity | 69 / 69 | 69 / 69 | 69 / 69 | 69 / 69 |
| hash layer: 13 openings, 3,328 columns, 7,751,680 bytes | same | same | same | same |
| channels | 25, **14 open** | 25, 14 open | 25, 14 open | 25, 14 open |

**Was a low rank artificially low because the planes were identical across
heads?** No — that is the one thing this comparison is for, and the answer
is measured, not argued. The `A` commitment's `rank_P1` is 74 of 623 rows
and its disclosed dimension 0 on the dense witness exactly as on the
fixture; the boundary's rank on its ten reserved rows is 6 either way. The
model's disclosure figures are ranks of the BLINDING structure — mask
rows, proximity rows, pads — and that structure does not depend on the
values the witness puts in the data rows. A dense witness was the right
thing to demand, and the result is that the figures are the same figures.

## 8.6 Round 4's controls

Six, **all firing on both bundles**; four of them fire on a pre-repair
bundle, which has no group table to perturb.

| control | what | fires |
|---|---|---|
| **GQ-1** | stage 0, slot 08 `SC_SCORE`, terminal 0 changed by +1 | fails at **exactly** that slot and stage, 68 of 69 |
| **GQ-2** | stage 2, slot 09 `SC_PV`, terminal 1 changed by +1 | the same |
| **GQ-3** | the bundle's DECLARED eq point changed in memory | refused **by name** — "the declared eq point is not `r_g = r_h[..lkv]` re-derived from the transcript" — and the slot is not evaluated at the prover's point |
| **GQ-4** | the point THIS TOOL derived perturbed, the bundle untouched | refused too: the comparison is two-sided and neither side is the authority |
| **GQ-5** | the OTHER definition forced on these bytes | both slots refused in every stage, on the derived dims, on the missing or extra group table AND on the coordinate lists; the other 21 slots are unaffected (63 of 69 still check) |
| **GQ-6** | the PRE-REPAIR polynomial `X·Y` measured beside `eq·X·Y` | the repaired one holds **6 of 6**, the pre-repair one **0 of 6**; no group factor is 1 and no terminal product is 0 |

The 8 terminal controls (CT-1 … CT-8), the 6 hash-rule controls
(CH-1 … CH-6) and the 6 run controls (C1 … C6) all still fire on both new
bundles, unchanged.

### What GQ-6 does NOT show, and why that is the round's most honest line

GQ-6 gives the **same** answer on the dense bundle and on the zero bundle.
That is not a disappointment to be explained away; it is the limit of what
a capture reader can reach. Finding S19-F1 is a disagreement between the
prover's CLAIM and the true sum over key-value groups, and both sides of
that need a witness. No capture carries one. What GQ-6 measures is the
arithmetic weight of the group factor in the verifier's own final check —
real on both witnesses, `eq` never 1 and no terminal product ever 0. So:
**from this gate's side the defect is invisible on EVERY witness, not only
on a degenerate one**, and the mechanism that hid it — prover and verifier
sharing one wrong definition function — is exactly the mechanism a
round-trip reader cannot see. The gate's record says this in its own
`what_it_does_not_show`.

## 8.7 The four (now six) superseded bundles

`run-a` … `run-f` are kept IN scope and replayed under the definition that
made their bytes, marked **SUPERSEDED** for the two slots — the treatment
round 3 gave a pre-tag hash rule, for the same reason: refusing them by
name would throw away three rounds of evidence, and replaying them under
the repaired definition would mis-replay them. Their records say which
definition was in force, that it is the one finding S19-F1 names as wrong
for a witness that varies across groups, and that nothing measured on them
is a statement about what the profile produces today.

All six were re-run under round 4's tools and diffed leaf by leaf against
their committed records (`old/old_bundles_unchanged.json`): **0
unclassified differing leaves**, with 2,512 / 2,512 / 3,159 / 3,160 /
3,480 / 3,479 identical leaves. Every difference is a wall clock, a tool
SHA-256, the new stage-10 block, ruling R-3's note beside a joint figure,
the terminal port naming which definition is in force, the one channel
reason that gained R-3's sentence, or the `what_it_does_not_show` wording.
**No rank, disclosed dimension, challenge count, slot check or control
figure moved.** The classifier is a tool, not a reading.

## 8.8 The channel table, recounted

Counted from the tool's own `stage7_channels.channels` array.

| bundle | total | constructed | derived | argued | **open** |
|---|---:|---:|---:|---:|---:|
| `run-g-dense-s20`, `run-h-zero-s20` | **25** | 2 | 5 | 4 | **14** |
| `run-e-tame-tagged`, `run-f-zero-tagged` (re-run) | 25 | 2 | 5 | 4 | 14 |
| `run-c-tame`, `run-d-zero` (re-run) | 25 | 2 | 4 | 4 | 15 |
| `run-a-tame`, `run-b-zero` (re-run) | 25 | 2 | 3 | 4 | 16 |

**Nothing moved, and that is the right answer.** Round 4 added no channel
and closed none. Deriving the group factor makes the terminal-identity
channel *better founded* — the verifier-computed table in it is now
computed here rather than taken — but it was already DERIVED, and a
channel does not get counted twice for being derived more carefully. The
fourteen that stay open are the same fourteen §7.6 lists.

## 8.9 Ruling R-3, and what the gate cannot see

Two corrections were recorded this round, both dated, neither rewriting a
number.

* **Ruling R-3** (`ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md`):
  `joint == sum of the parts` is a **consistency check of this model's
  coordinate classes, not evidence that the commitments' blinding is
  independent.** The checker built the counterexample — two DISTINCT
  blinding rows whose VALUES coincide score exactly like an honest run
  (joint 0 = sum 0) while disclosing 1,024 field elements at this shape.
  Independence rests on the generator and the draw discipline (gap G-R4)
  and is to be machine-asserted elsewhere. The correction block is in
  §2.4 and repeated above §7; the sentence now travels with every joint
  figure the gate reports, as `ruling_R3` in the records.
* **The gate cannot see the witness.** No capture carries one. "Dense" and
  "zero" are claims about the Rust lane's test that wrote each bundle, read
  from the capture's README. The record says so in
  `what_it_does_not_show`, and nothing in §8 should be read as this tool
  having verified what was proved.

## 8.10 The suite

`python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate*.py'`:
**123 tests, OK**, 30.0 s — round 3's 94 plus this round's 29.
`-p 'test_zk60_native*.py'`: **290 tests, OK**, 240.6 s, one skip and one
recorded expected failure — against **261** before this round. The 29 new ones are `tests/test_zk60_native_run_gate_s20.py`, in
the three arms this lane uses: a PURE arm that needs no bundle (the
geometry, both definitions' dimensions and coordinate schedules written
out, the group bit fixed-then-summed property, and the `kv_heads == 1`
reduction), a RECORDED arm asserting every figure above from the tracked
evidence, and a LIVE arm skipped when the ~41 MB bundles are absent.
**No round-1, round-2 or round-3 assertion had to move** — the only reason
their evidence was refreshed is that the tool bytes changed. The toy
gates' record guard still passes and no toy file's bytes were touched.

## 8.11 What this round is NOT

* **Not a privacy claim, and a dense witness does not make it one.** Ruling
  M-8's decision, D8/D11 and the run's joint-law composition are untouched.
* **Still LINEAR channels.** §2.3 and §2.4's figures are ranks of the same
  explicitly stated linear model; the "any nonlinear functional" channel
  stays OPEN.
* **Two runs, one development shape.** `run-g-dense-s20` and
  `run-h-zero-s20` are two captured runs at 24 tokens, width 96, hidden
  192, 6 query heads over 2 key-value heads. Two runs are not a
  distribution, and one dense witness is not a distribution of witnesses.
* **Nothing about the 125M shape.** The port is shape-driven — `lkv`, the
  round counts, the degrees and both coordinate schedules come from
  `run.json["shape"]` — but it has been RUN at one shape, where `lkv = 1`.
  At `lkv > 1` the same code paths carry more group variables and nothing
  here has exercised them.
* **The hash layer's HIDING is still argued** (§7.3), and the masked
  sumcheck / CFS channel is still the largest open one a port could close.
* **The defect itself is out of reach from a capture** (§8.6). What round 4
  establishes is that the claim point and the schedule are the repaired
  construction's, at this run's real challenges — not that the run proved
  the statement it names, and not that the witness was what its README
  says.
