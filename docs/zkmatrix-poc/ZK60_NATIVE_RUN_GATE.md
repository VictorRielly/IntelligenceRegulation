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

> **Section 11, 2026-09-21, is the seventh round**, and it closes the one
> thing every section above records as missing: §2.5's "`A` and `H` are
> **skipped, not faked**". The toy gate's solve now runs at `MSG != PAD`,
> so every PCS commitment of all four current runs has a CONSTRUCTED and
> VERIFIED zero-data preimage — both halves, every opened column and the
> salted leaves of the opened columns. Wherever §2.5, §2.7 or §4 say that
> `A` and `H`'s vectors, the pad half or the opened column values are OPEN,
> read them against §11.7, which moves exactly those three channels to
> CONSTRUCTED and no others. **A preimage for a RUN is still OPEN**, and
> §11.6's control P-5 is the reason that is not a formality.

> **Section 12, 2026-09-21, is the eighth round**, and it closes the thing
> §11.7 called "the largest open one a port could close": the masking
> commitment `M` and the masked-sumcheck (CFS) channel at the SHAPED
> layouts. Wherever this report says that channel is OPEN because the toy
> port is "written at the toy's row layout and slot specs", read it against
> §12.2, which says what really was layout-specific (five things, and the
> solver was not one of them). **§11.7's "a preimage for a RUN — still
> OPEN" is superseded by §12.7**, which joins the two arms into ONE
> assignment for the whole run and enumerates the four couplings it has to
> respect; C1, the boundary planes, is the one that does the work.
> The table goes from 25 channels at 5 / 5 / 4 / 11 to **28 at
> 10 / 5 / 4 / 9**.

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

> **DATED CORRECTION, 2026-09-21 (round 6).** A bundle PINNING a file and a
> gate CHECKING that pin are two different things, and this paragraph read
> as though they were one. Until tonight only `argument.rs`, `layout.rs`,
> `protocol.rs`, `plane_index.rs` and `shape.rs` were compared with a digest
> any run-gate tool had read; the first three named above —
> `run_capture.rs`, `run.rs` and `boundary.rs` — were compared with nothing
> (finding **K4-F2**, §9.1 item 3), and the rung-K4 bundles' `run.rs` moved
> without a tool noticing. §10 closes it: `zk60_native_rg_runpins` now
> carries all three, at every digest the ten bundles declare, each with a
> written reading. Nothing above this line changed as a result.

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

> **DATED NOTE, 2026-09-21 (round 7).** That assumption is gone and the
> construction is done: **§11**. `zk60_native_rg_ahpreimage` is the same
> solve with the two widths apart, and on all four current bundles every one
> of the ten PCS commitments — `A` and `H` included — has a constructed and
> verified zero-data preimage: both halves, every opened column and the
> salted leaves of the opened columns, **4,763,302 view entries recomputed
> and compared, none differing**. No number in this section changed; §11.5
> is the larger table beside it. The arm is opt-in (`--full-preimage`), so a
> default record still reports this section's four commitments and no more.

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
  > **DATED NOTE, 2026-09-21 (round 7).** The per-commitment side is now
  > **ten of the thirteen**, both halves, with every opened column and its
  > salted leaf (§11). The channel itself is still OPEN and for a sharper
  > reason than "it needs the pad half first": control **P-5** exhibits two
  > commitments of one stage that each have a preimage and, with one
  > blinding row identified between them, jointly have none. The CFS
  > channel — the remaining three commitments, `M@0..2` — is still
  > unconstructed.
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
  > **DATED NOTE, 2026-09-21 (round 7).** Still open, and now the LARGEST
  > open channel a port could close: round 7 did the same re-derivation for
  > the PCS side (`zk60_native_pg_pcs` at `MSG != PAD`, §11) and it took a
  > day, so the shape of the remaining work is known rather than guessed.
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

> **DATED NOTE, 2026-09-21 (round 6).** Those four, plus `shape.rs`, are
> what THIS port pins. The other three files a bundle pins —
> `run_capture.rs`, `run.rs`, `boundary.rs` — are the RUN layer and are
> pinned by `zk60_native_rg_runpins` as of tonight; before tonight they
> were pinned by nothing (finding K4-F2). See §10.

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
unclassified differing leaves**, with 2,512 / 2,512 / 3,159 / 3,159 /
3,480 / 3,480 identical leaves. Every difference is a wall clock, a tool
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

# 9. 2026-09-20, fifth round: TWO key-value group bits (rung-K4), and two findings about the gate itself

**Written 2026-09-20 23:40 PDT on the same lane.** Evidence:
`results/zk60_native_run_gate_k4/`. No new gate module; the changes are in
`zk60_native_rg_terminals.py` (one accepted shape digest, one repaired
refusal path, one corrected comment), `zk60_native_rg_gqa.py` and
`zk60_native_rg_gcontrols.py` (the controls per group coordinate, and
GQ-7), `zk60_native_rg_hcontrols.py` (CH-7) and the gate's
`--cross-profile` flag.

Round 4's NEXT list opened with "a shape with `lkv > 1`", because every
group figure this gate had ever reported was taken at `kv_heads = 2` — one
group bit, a one-element `eq` point, two terms in the sum over groups. The
Rust lane's stage 22 wrote **rung-K4**: 24 tokens, width 96, hidden 192,
**12 query heads of 8 over 4 key-value heads**, `h_pad = 16`, padded head
slots **{3, 7, 11, 15}**. That is the 125M model's own head geometry, and
it is the case a contiguous padded tail can never produce. Two tagged
three-block bundles at it, `run-i-dense-k4` and `run-j-zero-k4`, under a
NEW profile (D17) with its own keyed-hash key set.

The port claims to be shape-driven. This is the first time the claim has
been tested against a shape it was not written at — and rung-K4 moves more
than `lkv`: `lh` goes 3 → 4 and `ldh` goes 4 → 3, so a tool that had
quietly assumed six heads or a sixteen-wide head would fail here too.

> **STILL NOT A PRIVACY ACCEPTANCE AND STILL NO PRIVACY PROPERTY.** Two
> more captured runs at a second development shape are two more runs at a
> second development shape. Both bundles carry
> `privacy_review_complete: false` and so does every record.

## 9.1 The headline, in one line each

1. **Every figure scaled as the shape predicts, and nothing that should be
   invariant moved.** §9.4 is the table; §9.3 gives the exact arithmetic
   for the one figure that looked large.
2. **Finding K4-F1: the gate's REFUSAL path crashed.** The first probe on
   `run-i-dense-k4` died with `KeyError: 'slot_checks_expected'`. The port
   had correctly refused the bundle (its `shape.rs` pin had moved), but
   `check_terminals`'s moved-pin arm returned a dict without the keys
   stage 8 and the terminal controls read. That path had never been
   exercised end to end, because no bundle had ever moved a pin; the
   rung-K4 bundles moved two. **A refusal path that crashes is not a
   refusal path.** Repaired, and now covered by a test.
3. **Finding K4-F2: three of the eight files a bundle pins are pinned by
   nothing, and the tool said otherwise.** `zk60_native_rg_terminals`'s own
   comment read: "the other three (`run_capture.rs`, `run.rs`,
   `boundary.rs`) decide the bundle's shape and are checked by
   `zk60_native_rg_bundle`". They are not. No run-gate tool hashes or
   compares them, and the K4 bundles' `run.rs` moved from `65d55d25` to
   `73f68221` with nothing noticing. The comment is corrected and the three
   are named in the tool with their digests and what was read; the gap is
   **not closed here**, because closing it means reading three files at
   five capture commits, and a pin added without a reading is what this
   discipline exists to forbid.

## 9.2 The pins the new shape moves, and what was read

Two of the eight digests a bundle pins move between `0426ad2` (rung-G) and
`3247a89` (rung-K4):

| file | rung-G | rung-K4 | read |
|---|---|---|---|
| `shape.rs` | `8f734422` | **`07a0547f`** | `git diff 0426ad2 3247a89`: **60 added lines, 0 removed** — a doc comment and `Shape::rung_k4()` calling the UNCHANGED `Shape::new`. Not one geometry function this port reads moved: not `true_size`, not `head_slot`, not `pads`, not `clog2`, not `slot_dims`. Accepted as a second read digest in `PINNED_IF_PRESENT` |
| `run.rs` | `65d55d25` | **`73f68221`** | **9 added lines, 0 removed** (written as 12 on the night; `git diff --numstat 0426ad2 3247a89` says 9/0 — corrected 2026-09-21) — `RUN_PROFILE_RUNG_K4` and `RunShape::rung_k4`. **Pinned by nothing** (finding K4-F2) on the night; read and recorded anyway, and pinned in §10 |

`argument.rs` is `dd8469cb` on both, so both bundles select the REPAIRED
definition of slots 08 and 09 by their own pin, as round 4's do.
`layout.rs`, `protocol.rs`, `plane_index.rs`, `run_capture.rs` and
`boundary.rs` are byte-identical **between these two commits**. (Across all
five capture commits they are not: `run_capture.rs` has three digests and
`boundary.rs` two. §10's table is the full history, and the tool comment
that said `boundary.rs` was "byte-identical at every capture commit so far"
is corrected there, 2026-09-21.)

The shape's numbers are not taken from the moved file: `zk60_native_rg_gqa.Geometry`
derives `lt`, `lh`, `ldh` and `lkv` from `run.json["shape"]` and compares
every slot dimension with the shape's own `slots` array and with the slot's
own declaration.

## 9.3 The replay, and the one figure that looked large

| | rung-G (round 4) | **rung-K4** |
|---|---|---|
| run binding | reproduced | **reproduced** |
| transcript positions | 375 | **375** |
| challenges re-derived and compared | 6,092 | **6,854** |
| final transcript counter | 6,924 | **7,686** |
| segment position tags | 6 of 6 | **6 of 6** |
| challenges NOT re-derived | none | **none** |
| segment byte lengths | 4,067,160 / 4,089,688 / 4,257,592 | **4,575,304 / 4,597,832 / 4,765,736** |

`+762` challenges is a big number beside round 4's `+6`, so it is worth
writing out. It is exactly **3 stages × (3 + 3 + 104 + 144)**:

* **+3 definition draws** per stage. `SC_SCORE` draws `r_h ‖ r_t ‖ r_j`, so
  `lh` 3 → 4 gives one; slots 04 and 17 gain one each with `Dom::S`.
* **+3 sumcheck rounds** per stage: the three slots whose `main` grows
  (04 `13 → 14`, 09 `6 → 7`, 17 `13 → 14`), because `Dom::S = h_pad ×
  t_pad × t_pad` doubles from `2^13` to `2^14` when sixteen head slots
  replace eight.
* **+104 and +144 proximity rows**, one challenge each, because the `A`
  commitment grows 623 → 727 rows and `H` 576 → 720.

Every term is read from the shape or the capture, and the sum is the
measured figure to the unit. The segments grow by **+508,144 bytes in each
of the three stages**, the same figure three times.

## 9.4 Every figure, rung-K4 beside rung-G

`shape_comparison_k4_vs_rungg.json`: **173 figures over four records
(K4 dense, rung-G dense, K4 zero, rung-G zero), 134 identical.**

| figure | rung-K4 | rung-G | reading |
|---|---|---|---|
| `lkv` | **2** | 1 | the point of the round |
| slot 08 / 09 `(main, ext, degree)` | **(5,2,3) / (7,2,3)** | (5,2,3) / (6,2,3) | derived, and compared with the slot AND the shape: **6 of 6** |
| group points derived and compared | 6 | 6 | one per bilinear slot per stage |
| **group point ENTRIES compared** | **12** | 6 | exactly `lkv` per point |
| coordinate lists re-derived | 12 | 12 | |
| coordinate entries compared | **138** | 135 | predicted from the two geometries, not observed |
| of which fixed, against a re-derived challenge | **66** | 69 | `ldh` 4 → 3 loses three |
| `A` rows / data / **non-data** | 727 / 481 / **246** | 623 / 377 / **246** | the blinding block does not move |
| `H` rows / data / **non-data** | 720 / 612 / **108** | 576 / 468 / **108** | nor here |
| `A` disclosed / `rank_P1` | **0 / 74** | 0 / 74 | |
| `H` disclosed / `rank_P1` | **2 / 20** | 2 / 20 | |
| endpoints, boundaries, `M` disclosed | **0** | 0 | |
| each boundary: rows / generators / rank / disclosed | **10 / 6 / 6 / 0** | 10 / 6 / 6 / 0 | |
| three-role joint, generators | **0, 154** | 0, 154 | |
| whole run | **308 × 4,505, joint 6 = sum 6** | 308 × 3,761, joint 6 = sum 6 | ruling R-3 below |
| zero-data preimage, message half | **4 commitments, 0 free `Fp`** | same | |
| terminal identity | **69 / 69**, 0 open | 69 / 69, 0 open | |
| public tables: rebuilt / carried / structure checks | **16 / 15 / 45** | 16 / 15 / 45 | |
| hash layer: openings / columns / bytes | **13 / 3,328 / 9,275,392** | 13 / 3,328 / 7,751,680 | |
| channels | **25, 14 open** | 25, 14 open | |

**Every one of the 39 figures that differ is a size the shape must change,
a transcript-drawn column count, or a group figure that scales with `lkv`.
Not one disclosed dimension, rank, boundary figure, three-role figure,
joint figure, preimage figure, terminal check or channel count moved.**

That the `A` commitment's `rank_P1` is 74 and its disclosed dimension 0 at
BOTH shapes is the same reading §8.5 gave for dense against degenerate,
now across a change of geometry: the model's disclosure figures are ranks
of the BLINDING structure — mask rows, proximity rows, pads — and that
structure is a function of the group counts (`a_groups` 36, `h_groups` 9,
equal at both rungs), not of how the head axis is cut.

**Dense against zero, at two group bits**
(`witness_comparison_k4_dense_vs_zero.json`): **173 compared, 153
identical**, and every one of the 20 that differ is a count of distinct
sampled columns, a pad margin (256 minus it) or the pad block's exact rank
(which equals it) — **the same twenty classes, and the same reading, round
4 found at one group bit.** The witness result reproduces at `lkv = 2`.

## 9.5 The controls, re-aimed at the third and fourth group

`GQ-3` and `GQ-4` were single controls aimed at slot 08's only group
coordinate. They are now **families**, one member per bilinear slot per
group coordinate, and two controls are new.

| control | what | rung-K4 | rung-G |
|---|---|---|---|
| **GQ-1** | stage 0, slot 08, terminal 0 `+1` | fires at exactly that slot, 68 of 69 | fires |
| **GQ-2** | stage 2, slot 09, terminal 1 `+1` | fires | fires |
| **GQ-3.08.0 / .1**, **GQ-3.09.0 / .1** | the bundle's DECLARED eq point, each coordinate in turn `+1` | **4 of 4 fire**, refused by name | 2 of 2 |
| **GQ-4.08.0 / .1**, **GQ-4.09.0 / .1** | the point THIS TOOL derived, each coordinate in turn | **4 of 4 fire** | 2 of 2 |
| **GQ-5** | the pre-repair definition forced on these bytes | fires; both slots refused in every stage, the other 21 unaffected | fires |
| **GQ-6** | the pre-repair polynomial `X·Y` measured beside `eq·X·Y` | repaired **6 of 6**, pre-repair **0 of 6**; no group factor is 1, no terminal product 0 | same |
| **GQ-7** *(new)* | the declared point's two group coordinates **SWAPPED**, every value kept | **fires** — refused by name, entries `[0, 1]` both differ | **NAMED AND SKIPPED**: a one-entry point cannot be reordered |
| **CH-7** *(new)* | each bundle's real captured columns re-hashed under the OTHER tagged profile's derived key set | **fires, two-sided**: 3,328 of 3,328 under its own keys, **0 of 3,328** under the other's, in both directions, with all four role keys differing | the same pair, from the other side |

**13 of 13** group controls fire on both K4 bundles, none skipped; **8 of
8** on both rung-G bundles with GQ-7 named and skipped. The 8 terminal
controls (CT-1 … CT-8), the 7 hash-rule controls (CH-1 … CH-7) and the 6
run controls (C1 … C6) all fire on both.

Two of these deserve their reason written down.

* **GQ-7 is the control that needed the shape.** Swapping the two
  coordinates keeps every value the point names and only changes which
  group each bit selects — group 1 and group 2 exchange places. A
  comparison that treated the point as a SET, or that checked only its
  length and its first entry, would pass it. At `lkv = 1` the control does
  not exist, which is why it is skipped by name rather than counted.
* **CH-7 is not CH-3.** CH-3 rewrites a DECLARED profile string and is
  refused by the derivation before a byte is hashed. CH-7 perturbs nothing:
  both key sets are complete, internally consistent and derived here from
  profile strings that really exist, and the only thing wrong is which
  profile. It says the separation of D19 is in the BYTES, not only in the
  bookkeeping — and it could not be run until round 5, because until
  rung-K4 there was only one tagged profile to read.

## 9.6 Did anything in the tools assume one group bit?

Asked directly, and the answer is **no for the group arithmetic and yes for
two things next to it**.

* `Geometry`, `dims`, `n_definition_challenges`, `coordinate_schedule`,
  `has_group_table`, `PadGeometry.head_slot` and every domain size read
  `kv_heads`, `q_heads`, `h_pad`, `head_dim` and `t_pad` from
  `run.json["shape"]`. Nothing in them is a rung-G constant, and the
  padded head slots the port derives at rung-K4 are `{3, 7, 11, 15}`,
  which is the interleaved case and not a tail.
* `plane_index.rs` is byte-identical at both shapes, so the "rung-G plane
  index digest" the brief asked about was never a shape-dependent pin.
* **`GroupFactors`' control hook did assume one bit**: `perturb_derived_point`
  perturbed `r_g[0]` and had no way to name another coordinate. That is a
  test-surface assumption rather than a gate one — no measured figure came
  from it — but it meant the round-4 controls could not have reached the
  second bit even on a bundle that had one. It now takes
  `perturb_derived_entry` and refuses an out-of-range coordinate by name.
* The **refusal** path assumed no bundle would ever move a pin (finding
  K4-F1), and the **pin coverage** comment assumed three files were checked
  somewhere they are not (finding K4-F2).

## 9.7 The channel table, recounted

Counted from the tool's own `stage7_channels.channels` array.

| bundle | total | constructed | derived | argued | **open** |
|---|---:|---:|---:|---:|---:|
| `run-i-dense-k4`, `run-j-zero-k4` | **25** | 2 | 5 | 4 | **14** |
| `run-g-dense-s20`, `run-h-zero-s20` (re-run) | 25 | 2 | 5 | 4 | 14 |
| `run-e-tame-tagged`, `run-f-zero-tagged` (re-run) | 25 | 2 | 5 | 4 | 14 |
| `run-c-tame`, `run-d-zero` (re-run) | 25 | 2 | 4 | 4 | 15 |
| `run-a-tame`, `run-b-zero` (re-run) | 25 | 2 | 3 | 4 | 16 |

**Nothing moved.** Round 5 added no channel and closed none. A second shape
makes the open ones no less open; the fourteen are the fourteen §7.6 lists.

## 9.8 The eight older records, refreshed

The tool bytes changed, so every committed run-gate record was re-run and
diffed leaf by leaf against its committed bytes
(`old/prev/*.json`, `old/*.diff.json`, `old/old_bundles_unchanged.json`):
**0 unclassified differing leaves on all eight**, and a direct comparison
of the figures of record — `ok`, the challenge and position counts, every
per-commitment disclosed dimension / rank / column count, the whole-run
joint and sum, the slot checks and the channel counts — finds **0 bundles
whose figures moved**. Every difference is a wall clock, a tool SHA-256,
or the two new control entries.

## 9.9 Ruling R-3, and what the gate still cannot see

Unchanged and repeated, because a joint figure appears in §9.4:

> **Ruling R-3.** `joint == sum of the parts` is a **consistency check of
> this model's coordinate classes, not evidence that the commitments'
> blinding is independent.** Two DISTINCT blinding rows whose VALUES
> coincide score exactly like an honest run (joint 0 = sum 0) while
> disclosing 1,024 field elements at this shape. Independence rests on the
> generator and the draw discipline (gap G-R4) and is to be machine-asserted
> elsewhere.

And: **the gate cannot see the witness.** "Dense" and "zero" are claims
about the Rust lane's test that wrote each bundle, read from the capture's
README. §8.6 still stands in full — finding S19-F1 is invisible to a
capture reader on EVERY witness, and a second shape does not change that.

## 9.10 The suite

`python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate_k4.py'`:
**36 tests, OK**, 11.9 s, in four arms — a PURE arm (the K4 geometry, both
slots' dimensions and coordinate schedules written out at two group bits,
the padded head slots, and the scaling laws the two shapes must obey), a
**GENERIC** arm (the `eq` algebra the two-group case newly exercises, on
uniformly random `Fp2` elements over seven seeds and never on the shaped
instance), a RECORDED arm and a LIVE arm. The record guard
`tests/test_zk60_native_gate_record.py` gains six for Item B.

`-p 'test_zk60_native_run_gate*.py'`: **159 tests, OK**, 42.5 s (round 4:
123). `-p 'test_zk60_native*.py'`: **335 tests, OK**, 281.5 s, one skip and
one recorded expected failure, against **293** before this round.

**Six earlier assertions moved, deliberately.** The first whole-suite pass
after the tool changes was 5 failures and 1 error, and every one was an
earlier round asserting an exact set round 5 widened on purpose: the pin
count (now both tables), the tree materialised at `4751b93` (now 30 files,
four of them at an accepted second digest), round 4's `GQ-1 … GQ-6` (now
nine entries with `GQ-3` and `GQ-4` as families and `GQ-7` skipped at
`lkv = 1`), and round 3's `CH-1 … CH-6` (now seven). Each was updated with
the reason written beside it, and the ledger's §R5.7b tabulates all six.
**Not one was a measured figure**: every rank, disclosed dimension,
challenge count, slot check and channel count asserted by rounds 1–4 is
asserted unchanged.

## 9.11 What this round is NOT

* **Not a privacy claim.** A second shape is not a distribution of shapes,
  and ruling M-8's decision, D8/D11 and the run's joint-law composition are
  untouched.
* **Still LINEAR channels.** §2.3 and §2.4's figures are ranks of the same
  explicitly stated linear model; the "any nonlinear functional" channel
  stays OPEN.
* **Two runs, and one development shape per head geometry.** `run-i` and
  `run-j` are two captured runs at rung-K4, as `run-g` and `run-h` are two
  at rung-G. Two runs are not a distribution.
* **Nothing at the 125M shape.** Rung-K4 has 125M's HEAD geometry — four
  key-value groups, `lkv = 2`, interleaved padded slots — and nothing else
  of it: 24 tokens against 512, width 96 against 768, three blocks against
  twelve. The exact-rank computation over thousands of rows per commitment
  is still untried, and a 484 MB run is still more than this gate ingests.
* **`lkv = 2` is not `lkv > 2`.** The 125M shape's `lkv` is 2 as well, so
  what is now exercised is the case that shape needs; a shape with eight or
  more key-value groups is still unread.
* **The hash layer's HIDING is still argued** (§7.3), and the masked
  sumcheck / CFS channel is still the largest open one a port could close.
* **Finding K4-F2 is recorded, not repaired.** Three files a bundle pins
  are checked by nothing, and until they are read at every capture commit
  they can still move unnoticed. *(CLOSED 2026-09-21 in §10: all three read
  at all five capture commits and pinned.)*

---

# 10. 2026-09-21, sixth round: the RUN LAYER's own pins (finding K4-F2, closed)

**Written 2026-09-21 on the same lane.** Tool:
`scripts/zk60_native_rg_runpins.py` (new). Evidence:
`results/zk60_native_run_gate_runpins/`. No new figure about any run: this
round adds a PIN, corrects the record where it said or implied one existed,
and re-establishes every figure of rounds 1–5 unchanged.

Round 5 (§9.1 item 3) found that three of the eight files a bundle pins in
its own manifest — `run_capture.rs`, `run.rs`, `boundary.rs` — were checked
by **no run-gate tool**, while `zk60_native_rg_terminals`'s comment said
they were "checked by `zk60_native_rg_bundle`". They were not. The rung-K4
bundles' `run.rs` moved from `65d55d25` to `73f68221` and nothing noticed.

**Why the replay is not a pin.** Everything the gate says about the run
layer — the run header and its binding, the stage order, the boundary
geometry and its reserved rows, the segment position tags, what a capture
records and in which order — rested on the replay reproducing every
challenge and every tag. That is strong evidence. It is not a pin: **a
change to the CAPTURE WRITER that altered what is recorded without moving a
challenge would be invisible to it.**

> **STILL NOT A PRIVACY ACCEPTANCE AND STILL NO PRIVACY PROPERTY.** A pin
> is a statement about which Rust this gate has read. Every bundle still
> carries `privacy_review_complete: false`, and so does every record.

## 10.1 The headline, in one line each

1. **Eight run-layer files considered; four are depended on; three of those
   were pinned by nothing.** §10.2 is the dependency list, with each port's
   own reference. The fourth, `plane_index.rs`, was already pinned by
   `zk60_native_rg_terminals` and stays there — two tools pinning one file
   is how a pin quietly stops meaning anything.
2. **Nine (file, digest) pairs over five capture commits, all READ, none
   refused.** §10.3. Every diff between consecutive capture commits was
   classified hunk by hunk and the production / `#[cfg(test)]` split
   counted rather than eyeballed.
3. **No port turned out stale.** Three hunks touch something a port depends
   on, and the port had already been updated for all three (the tagged
   transcript and the `hash_tag` member in round 3, the `plane_index`
   member in round 2). The one change to what a capture RECORDS that no
   port noticed is `TRANSCRIPT_PROGRAM` growing 9 → 10 entries, and no port
   reads it — checked, not assumed.
4. **A refusal names the affected stages and does not crash** (§10.4),
   which is finding K4-F1's lesson one layer up; all three refusal paths
   are exercised end to end through the whole gate by a live test.
5. **Two figures of round 5 are corrected** (§10.5), and every figure of
   record of all ten bundles is unchanged: **0 unclassified differing
   leaves** on all ten (§10.6).
6. **Finding R6-F1, small and real:** K4-F1 made the moved-pin arm return
   every key a caller reads, but `stage8` did not copy the sentence saying
   the zeros are the absence of a check, so a reader of the JSON saw zeros
   with no explanation. Fixed, and only on a refusal, so no healthy record
   gains a leaf.

## 10.2 What the ports depend on in the run layer

The list is `zk60_native_rg_runpins.DEPENDS`, and a test asserts the pin
table covers it **exactly**, in both directions: a file a port depends on
with no pin fails, and a pin for a file no port depends on fails.

| file | what a port transcribes or relies on | pinned before tonight |
|---|---|---|
| `run.rs` | the run header's six absorbs and their order and the seven-word shape; the stage loop (`pb-run-stage`, `pb-run-block`, `B` before `A`); `position_tag`, two Fp2 from a DISCARDED clone; the opening order; `BOUNDARY_SITES = 2` and `in_site`/`out_site` = slots 21/22 | **no** |
| `boundary.rs` | `commitment_rows = data + 2·sites + 2`, `site_rows`, `prox_row`, `mask_row`, ruling M-1's declared-row refusal, and `prepare` setting `mask_rows` / `prox_mask_row` | **no** |
| `run_capture.rs` | the WRITER: schema, the three kinds, `coverage`, every field name and order, `TRANSCRIPT_LABELS` (19) as `EXPECTED_LABELS`, the manifest, and the `plane_index` and `hash_tag` members | **no** |
| `plane_index.rs` | `plane_index::build` / `render` / `locate`, and the per-slot push order | yes, `rg_terminals.PORTED_FROM` |

**Four run-layer files are NOT depended on, and are named rather than
merely absent** (`NOT_PINNABLE_FROM_A_BUNDLE`), each with two reasons:
`wire.rs` (no port decodes a segment; the tags are compared against
`run::position_tag`, not against the frame), `run_sink.rs` (no port reads a
segment file), `endpoint_g.rs` (the endpoint's rows come from the shape and
its non-data rows from the capture's `row_roles`; `MASK_ROWS` is
transcribed nowhere here) and `hash_domain.rs` (the one guard the gate
computes, the path length, is ported from `pcs::verify_zk_tagged`). The
second reason in each case is the same and is the mechanism's limit:
**this gate reads a BUNDLE, never the Rust tree**, so a file can be pinned
here only if the writer pins it — and none of the four is in
`run_capture.rs::SOURCE_FILES`. That fact is read out of the Rust by a
test, not asserted. Closing it is a Rust-lane ask, recorded in the ledger.

## 10.3 Read, then pinned

| file | digests | lane commits | bundles |
|---|---|---|---|
| `run_capture.rs` | `51f26bc1` / `975364b9` / `0cb54ae3` | `cb27845d` / `aff891d` / `facc057`+`0426ad2`+`3247a89` | a,b / c,d / e–j |
| `run.rs` | `02f7ee7e` / `87b3f0c4` / `65d55d25` / `73f68221` | `cb27845d`+`aff891d` / `facc057` / `0426ad2` / `3247a89` | a–d / e,f / g,h / i,j |
| `boundary.rs` | `9860c35d` / `3786a300` | `cb27845d`+`aff891d` / `facc057`+`0426ad2`+`3247a89` | a–d / e–j |

Every digest was recomputed from the committed blob at every commit it
names — fifteen (file, commit) combinations — and equals what the bundles'
manifests declare. The written reading of each pair is in
`zk60_native_rg_runpins.READINGS` and is tabulated line by line in the
ledger's §R6.5b. In short: the two `run_capture.rs` steps are stage 15's
plane index (84/3) and stage 17/18's D19 tag (65/7), neither touching a
field the loader already read; the three `run.rs` steps are the D19 tag
plumbing (48/9, header and stage loop untouched), ruling R-5's scale
refusal (30/0, no absorb added) and rung-K4's profile constant (9/0); the
one `boundary.rs` step is the D19 tag plumbing again (production +27/−3,
tests +15/−10), with **not one geometry accessor moved**.

## 10.4 What a refusal does

A digest outside the table leaves the AFFECTED STAGES not checked, **by
name**, with every reason listed and a sentence saying the zeros are the
absence of a check and not a passing one.

| refused file | stages suspended |
|---|---|
| `run_capture.rs` | all ten |
| `run.rs` | all ten |
| `boundary.rs` | **six** — 1, 3, 4, 5, 6, 7. Stage 2 absorbs the boundary ROOT with the rows and width the capture states, so the replay does not depend on this file; nor do the plane index, the hash layer or the group factor, and a live test shows those four really run |

`stage7_channels` is suspended whenever anything is, so `channels()` is
never handed a partial record. Three live tests run the WHOLE gate on a
bundle whose digest the table has not read — one run-layer file, the
boundary (the partial case), and an ARGUMENT-layer file (`shape.rs`, the
path K4-F1 repaired) — and none of the three raises.

## 10.5 The record corrected

Nothing is rewritten; each correction is dated in place.

| where | said | says |
|---|---|---|
| §1 | the bundle "pins its own Rust sources", reading as though the gate checked them | a dated note: a bundle PINNING and a gate CHECKING are two different things, and three of these were compared with nothing until 2026-09-21 |
| §6.3 | the four the terminal port pins | plus a dated note naming where the other three are pinned now, and that they were pinned by nothing before |
| §9.2 here, and §R5.4 of the ledger | `run.rs` `0426ad2 → 3247a89`: "12 added lines, 0 removed" | **9 added, 0 removed** (`git diff --numstat`); both carry the dated correction beside the original figure |
| §9.2 | "`run_capture.rs` and `boundary.rs` are byte-identical" | true BETWEEN those two commits; across all five, `run_capture.rs` has three digests and `boundary.rs` two |
| `rg_terminals`'s `NOT_PINNED_BY_ANY_RUN_GATE_TOOL` | "`boundary.rs` … byte-identical at every capture commit so far (`3786a300`)" | **wrong**: bundles a–d pin `9860c35d`. The dict is renamed `WAS_NOT_PINNED_BY_ANY_RUN_GATE_TOOL_UNTIL_20260921`, kept as the dated record of what was true, with the old name as an alias |
| §9.11 | "finding K4-F2 is recorded, not repaired" | plus "CLOSED 2026-09-21 in §10" |

## 10.6 Every figure of record, unchanged

All ten in-scope bundles re-run under the current tools, into the same
evidence directory each record of record lives in, and diffed **leaf by
leaf** against the committed bytes taken with `git show HEAD:…` into
`results/zk60_native_run_gate_runpins/before/` before any run.

| | a–d | e–j |
|---|---:|---:|
| identical leaves | 2,748–3,528 | 3,861–4,029 |
| new leaves, all under `run_layer_source_pins` | **46** | **52** |
| changed leaves | **4–5** | **3–5** |
| leaves only in the OLD record | **0** | **0** |
| **UNCLASSIFIED differing leaves** | **0** | **0** |

The changed leaves are, on every bundle, one to three wall clocks and two
tool hashes (`zk60_native_run_gate.py`, `zk60_native_rg_terminals.py`),
plus one new tool hash for the new module. **Not one rank, disclosed
dimension, challenge count, slot check, control figure, channel count or
receipt size differs on any of the ten.**

## 10.7 The suite

`-p 'test_zk60_native_run_gate_runpins.py'`: **25 tests, OK**, 28.5 s.
`-p 'test_zk60_native_run_gate*.py'`: **184 tests, OK**, 71.6 s (round 5:
159). The whole native suite is in the ledger's §R6.7.

## 10.8 What this round is NOT

* **It is not a new figure about a run.** Round 6 computes no rank it did
  not compute before; it makes true a sentence about the tools that was
  false.
* **A pin is not a proof that the Rust is right.** It says this gate has
  READ the bytes that made the bundle. The reading is a human reading,
  recorded next to the digest so the next reader can disagree with it.
* **It does not close the writer-side gap.** Four run-layer files are on
  the run's path and in no bundle's `source_pins`, so they cannot be pinned
  from a bundle at all. No port depends on any of them today — which is
  exactly the fact that would stop being true if a port grew.
* **Nothing here moves D8/D11, ruling M-8's decision, the hash layer's
  ARGUED hiding, or the open sumcheck / CFS channel.**

---

# 11. 2026-09-21, seventh round: the PREIMAGE for `A` and `H`, constructed

**Written 2026-09-21 on the same lane.** New modules:
`scripts/zk60_native_rg_ahpreimage.py` (the construction),
`scripts/zk60_native_rg_ahcontrols.py` (six controls); the gate gains one
opt-in stage, `--full-preimage` → `stage11_full_preimage`. Evidence:
`results/zk60_native_run_gate_preimage/`. Tests:
`tests/test_zk60_native_run_gate_ahpreimage.py`.

§2.5 has said the same sentence since round 1: "`A` and `H` are **skipped,
not faked**: their opening groups have several members, so each claim's own
published value is an extra constraint, and the correction step that handles
it lives in `zk60_native_pg_pcs`, whose `MSG == PAD == 256` does not hold
here." Round 7 removes that assumption and does the construction. **All ten
PCS commitments of every one of the four current runs now have a
constructed, verified, zero-data preimage** — message half AND pad half AND
every opened column AND the salted leaves of the opened columns.

> **STILL NOT A PRIVACY ACCEPTANCE AND STILL NO PRIVACY PROPERTY.** A
> preimage EXISTS; that is not the statement that the honest prover's
> randomness is uniform on the fibre, which is the lemma's job and is not
> touched here. §11.8 is the list of what this does not show, and it is
> longer than the list of what it does.

## 11.1 The headline, in one line each

1. **The cost was never the obstacle.** Round 1 skipped `A` and `H` "for
   cost". Measured: the whole construction plus its verification is
   **11.5–12.7 s for an `A`** and **7.9–9.6 s for an `H`**, and **70–77 s
   for a whole three-block run's ten commitments**, in pure Python with
   exact `Fp` arithmetic, and the construction's own peak resident set is
   **103 MB** above the loaded bundle (325 MB for a process that does
   nothing else). What was real was the `MSG == PAD` assumption; the cost
   estimate was wrong by two orders of magnitude.
2. **4,763,302 view entries recomputed and compared, none differing**, over
   the four bundles — and **10,240 salted Merkle leaves** rebuilt from the
   construction and re-authenticated against the published salts and paths.
3. **It is the toy gate's own solve, not a second one.** Every arithmetic
   primitive is IMPORTED from `zk60_native_pg_pcs`; the two classes around
   them are re-derived with the widths apart, and a test runs the NEW
   classes on the TOY captures at `256/256` and requires the matrix digest,
   the step records, the solved matrix `X`, the exhibited-randomness digest,
   the fibre dimension and every verification count to equal the toy
   module's **to the byte**.
4. **Six controls, all fire** (§11.6), including the two that test the
   gate's own criterion and one — P-5 — that exhibits a case where both
   per-commitment preimages exist and **no joint one does**.
5. **Three channels move from OPEN to CONSTRUCTED**: `A` and `H`'s vectors,
   the pad half of every published vector, and the opened column values.
   The table goes from 2 constructed / 14 open to **5 constructed / 11
   open**, of 25. **A preimage for a RUN stays OPEN**, and P-5 is the reason
   it is not a formality.

## 11.2 The system, stated exactly

For one commitment the committed matrix is `X` in `Fp^{rows × (n+Q)}`; row
`i` is `z_i = (msg_i, pad_i)` in `Fp^n × Fp^Q`, with `n = 1,024` message
positions and `Q = 256` pad symbols at both development rungs. Split the
coordinates into the DATA block (`msg_i[t]` on the data rows) and the
BLINDING block (`msg_i[t]` on the non-data rows, and `pad_i[k]` on **every**
row, subject to the layout's public linear constraints).

**The unknowns.** Per commitment: the reserved mask-pair rows (one adjacent
pair per claim, H-pair), the proximity pair, `H`'s zero-sum `u` pair, and
`Q` pads per row.

**The equations.** Every entry of the verifier's field-valued view: each
opening group's vector (`n+Q` `Fp2` entries each), the proximity vector
(`n+Q`), each claim's published value, each opened column entry
(`d × rows`), plus the public zero-sum constraint on each `u` row.

| | `A`, rung-G | `H`, rung-G | `A`, rung-K4 | `H`, rung-K4 |
|---|---:|---:|---:|---:|
| rows | 623 | 576 | 727 | 720 |
| data rows | 377 | 468 | 481 | 612 |
| non-data rows | 246 | 108 | 246 | 108 |
| opening groups `G` | 36 | 9 | 36 | 9 |
| claims | 122 | 53 | 122 | 53 |
| generators `2(G+1)` | 74 | 20 | 74 | 20 |
| reserved pairs | 122 | 53 (one of them the `u` pair) | 122 | 53 |
| distinct opened columns `d` | 248–252 | 245–250 | 250–253 | 244–247 |
| **blinding unknowns (`Fp`)** | **411,392** | **258,046** | **438,016** | **294,910** |
| **equations (`Fp`)** | **249,468–251,960** | **166,828–169,708** | **276,714–278,895** | **201,388–203,548** |

The system is **underdetermined by construction** — that is what a hiding
commitment is — and the interesting question is not its size but whether it
is CONSISTENT for a data block that is not the one the run was proved on.

## 11.3 How it is solved: the order, not the size

No dense elimination over 600+ rows appears anywhere. The system decomposes,
and each step is small and exact over Goldilocks `Fp`:

1. **The message half, per opening group, in dependency order.** Under
   H-pair each claim owns one reserved pair that no other claim touches, so
   a group's only non-data support is its own claims' pairs. The whole
   per-position residual goes on ONE anchor pair — at each of the 1,024
   positions a 2×2 `Fp` system whose determinant the verifier itself refuses
   when zero — and then a correction **inside the kernel of that
   constraint** meets (a) each claim's own published value and (b) the
   public zero-sum constraint on any `u` row. The correction space is
   parametrised exactly (≤ 3 positions reach what all 1,024 reach, because
   the claim values see a correction only through `<δ_i, cw>` and a `u` row
   only through its row sum), so "no solution" is a statement about the
   channel and not about the search.
   The **order matters and is computed, not assumed**: `H`'s zero-sum slot
   READS the `u` pair that another group OWNS, so that group must be solved
   first. On `H` the gate reports `{7: [8]}` — group 7 reads group 8's rows
   — and the solve order is `0..6, 8, 7`.
2. **The message half of the proximity pair, last**: no claim touches it
   (H-prox).
3. **The pads, per row.** Writing the encoded row as `Enc_i = Msg_i + Z_n
   Pad_i`, the opened columns fix `Pad_i` at the `d` distinct sampled nodes;
   one Lagrange interpolation through those nodes (built once for the
   commitment, `d × d`) gives a solution, and the whole fibre is
   `I(p_i) + Z_S q_i` with `deg q_i < Q − d`.
4. **The pad half of each group vector and of the proximity vector.** It
   fixes `Σ_i ρ[i] q_i`, which is a polynomial **only when the residual is
   divisible by `Z_S`** — exactly when the verifier's own sampled-column
   identity holds. That divisibility is the channel's feasibility test, and
   controls P-1 and P-3 make it fire.

**Why the cost is small.** The per-row Lagrange solve is `d²` and the group
steps are per-position 2×2 systems; the only `rows × (n+Q)` passes are the
forward map in the verification. With the data block at zero, the residual
accumulation drops every zero row — an exact re-association of the same sum,
not a shortcut past a constraint, and the point at which round 1's cost
estimate went wrong.

## 11.4 It is the same solve, and that is asserted rather than asserted-to

`zk60_native_pg_pcs.py` is a hash-pinned record of the toy gate and this
lane does not edit it, so the two classes had to be re-derived. Three things
keep that from being a fork:

* **Every primitive is imported, not copied**: `solve_pair`,
  `kernel_basis`, `poly_div_exact`, `Lagrange` (with its `Z_S` and its
  interpolation basis) and `poly_eval`. A test asserts each name in the new
  module **IS** the toy module's object, and that the new module's source
  defines no function or class of those names.
* **`DERIVED_FROM` and `NEW_HERE`** name, method by method, the toy method
  each one comes from and the one thing that differs — and a test requires
  every method with a toy counterpart to be in the first map and every other
  method to be in the second, so the map cannot silently fall behind.
* **The equivalence run.** The new classes, at `msg_width == pad_width ==
  256`, are run on a real TOY capture (`40083e7a…`, roles `H` and `Input`)
  beside `zk60_native_pg_pcs`'s own classes. Equal: the matrix digest, the
  anchor list, the solve order, `d`, the step records, the failure list, the
  **whole solved matrix `X`**, the exhibited-randomness digest, the fibre
  dimension, and every verification count. One difference, stated: the wide
  `verify` has a hash arm the toy has no Merkle layer for, and with no rule
  supplied it says `checked: false` rather than pretending.

A fourth, on the run side: round 1's singleton-group construction
(`zk60_native_rg_preimage`) and round 7's general one are two different
routes to the same object, and a test requires them to agree on **every**
message entry of `B0`.

## 11.5 What was constructed and verified

Every PCS commitment of every stage of all four bundles, at the ALL-ZERO
data block. `run-h-zero-s20` and `run-j-zero-k4` are the sanity anchor: on
those the prover's own hidden input was all zero, so the construction is a
preimage of the same data block the prover used, and it succeeds exactly as
on the dense ones.

| bundle | witness | commitments exhibited | view entries compared | differing | salted leaves re-authenticated | stage-11 seconds |
|---|---|---:|---:|---:|---:|---:|
| `run-g-dense-s20` | fully dense generic | **10 / 10** | **1,097,847** | **0** | 2,560 | 70.4 |
| `run-h-zero-s20` | all zero | **10 / 10** | **1,103,569** | **0** | 2,560 | 71.3 |
| `run-i-dense-k4` | fully dense generic | **10 / 10** | **1,282,025** | **0** | 2,560 | 76.1 |
| `run-j-zero-k4` | all zero | **10 / 10** | **1,279,861** | **0** | 2,560 | 76.2 |
| **total** | | **40 / 40** | **4,763,302** | **0** | **10,240** | |

Per commitment, rung-G (`run-g-dense-s20`; the other three differ only in
`d` and in the row counts of the table in §11.2):

| commitment | rows | `d` | group-vector entries | proximity | claim values | opened-column entries | **total** | fibre (`Fp`) | seconds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `A@0` | 623 | 252 | 46,080 | 1,280 | 122 | 156,996 | **204,478** | 178,152 | 11.8 |
| `H@0` | 576 | 250 | 11,520 | 1,280 | 53 | 144,000 | **156,853** | 93,360 | 8.3 |
| `E-Input` | 9 | 246 | 1,280 | 1,280 | 1 | 2,214 | **4,775** | 50 | 2.7 |
| `A@1` | 623 | 248 | 46,080 | 1,280 | 122 | 154,504 | **201,986** | 180,348 | 11.6 |
| `H@1` | 576 | 246 | 11,520 | 1,280 | 53 | 141,696 | **154,549** | 95,584 | 8.1 |
| `B0` | 10 | 249 | 2,560 | 1,280 | 2 | 2,490 | **6,332** | 28 | 2.9 |
| `A@2` | 623 | 251 | 46,080 | 1,280 | 122 | 156,373 | **203,855** | 178,701 | 11.5 |
| `H@2` | 576 | 245 | 11,520 | 1,280 | 53 | 141,120 | **153,973** | 96,140 | 7.9 |
| `B1` | 10 | 242 | 2,560 | 1,280 | 2 | 2,420 | **6,262** | 56 | 2.7 |
| `E-Output` | 9 | 247 | 1,280 | 1,280 | 1 | 2,223 | **4,784** | 45 | 2.7 |

An `Fp2` entry counts once. "Entries compared" means: the view was
RECOMPUTED from (all-zero data + the solved blinding) by the forward map and
compared with the capture, entry by entry. **None differ**, on any
commitment of any bundle, and the record also carries a `first_mismatch`
field which is `null` everywhere.

**The hash layer of the opened columns.** For each of the 256 opened columns
of each commitment (sampled with replacement) the column is rebuilt from the
preimage, its leaf digest recomputed under the bundle's own derived rule,
salted with the PUBLISHED salt and folded along the PUBLISHED path. All
2,560 per bundle reach the committed root, and all 2,560 rebuilt columns are
equal to the capture's bytes. So the construction reproduces the receipt's
BYTES for the opened columns, not only its field values.
**The unopened leaves are not reproduced and cannot be**: an unopened leaf
is a salted digest of data nothing publishes. Their hiding is M-2 / M-3 and
stays ARGUED — round 7 does not touch it.

## 11.6 The controls

Each is shown to PASS on the honest capture first, and each makes the
construction refuse **by name**, at the thing that moved. Nothing on disk is
written: every perturbation is applied to the layout object in memory, and a
test re-digests the bundle directory afterwards.

| control | what moves | what fires |
|---|---|---|
| **P-1** | one OPENED COLUMN entry of `H@0`, by one (column 21, row 288) | `H@0: pad:group4 — NO PREIMAGE: the pad half of this combination is not reachable from the opened columns (the residual is not divisible by the sampled nodes' vanishing polynomial)` |
| **P-2** | one GROUP VECTOR entry of `A@0`, message half, at a position the group's column key really reads | `A@0: group 0 — NO PREIMAGE: the published claim values and the public row constraints cannot be met inside the kernel of the group-vector constraint` |
| **P-3** | one GROUP VECTOR entry of `H@0`, first pad coefficient | the `Z_S` divisibility, as P-1 |
| **P-4** | `H@0` modelled with 249 pads against 250 distinct opened columns | `H@0: row 0 — NO PREIMAGE: 249 pad symbols cannot meet 250 distinct opened columns (the interpolant of the required values has degree 249)` |
| **P-5** | one reserved mask row of `A@0` (row 377) and one of `H@0` (row 470) declared the SAME unknown | both per-commitment preimages exist and **force different values at all 1,024 message positions**, first at position 0: **no JOINT preimage** |
| **P-6** | a SECOND fixed input on `H@0` — public, deterministic, in-range, from the toy gate's own seed — before and after projection onto the identity the view discloses | **before**: `H@0: group 8 — NO PREIMAGE …`; **after**: solved, and 156,853 entries recomputed and equal |

**P-2 is the control that tests the gate's own criterion.** If the solver
returned something for every view whatsoever, "constructed" would measure
nothing. It does not: the anchor pair still absorbs the moved entry, so the
group VECTOR is reproduced — and then the verifier's own group identity
`<v_g, cw> = Σ λ·value` no longer holds, and nothing inside the kernel of
the vector constraint can change that sum, because that sum is invariant on
the kernel. The refusal is a property of the channel.

**P-6 is what `H`'s disclosed dimension of 2 MEANS.** §2.3 reports
`disclosed = 2` for `H` and says it is the public LogUp identity. P-6 shows
the same fact as a REFUSAL: a fixed input off that identity has no preimage
at all, and the same input projected onto it has one, verified entry by
entry. It also explains why round 7's honest case is feasible: the published
LogUp sum is zero and the all-zero data block sits on the identity.
It is also the one place where the SAME captured view is shown to have
preimages at **two different** data blocks.

**P-5 is the one that should be read twice.** Two commitments of the same
stage each have a preimage; identify one blinding row between them and there
is none. Each of the two rows is FORCED by its own commitment — each is the
anchor of a group whose only non-data support is that pair and whose
correction kernel is empty, so with the data at zero its value at every
position is the unique solution of an invertible 2×2 system — and the two
forced values differ everywhere. This is exactly the case a per-commitment
acceptance cannot see, and it is the concrete form of ruling **R-3**: the
run gate's joint figures are a consistency check of coordinate classes, not
evidence that the commitments' blinding is independent.

## 11.7 The channel table, recounted

25 channels: **5 constructed, 5 derived, 4 argued, 11 open** (round 6: 2 /
5 / 4 / 14). Three moved, and only three:

> **2026-09-21, later: this is the count of the table ROUND 7 had, and it
> is history.** Round 8 grades `M`'s `q`, `M`'s proximity vector and `M`'s
> own opened columns as three separate channels — as the TOY gate already
> did — so the array is 28, and round 7's own evidence directory was
> re-taken under round 8's gate and now reads **28 at 5 / 5 / 4 / 14**
> (the three new entries are OPEN because `--mask-cfs` is off there).
> **No stage-11 figure moved**: §12.9 has the four entry counts, unchanged.
> The paragraph below is deliberately left as written.

| channel | was | is | why |
|---|---|---|---|
| opening-group and proximity vectors of `A` and `H` | OPEN (`MSG == PAD` does not hold) | **CONSTRUCTED** | §11.3, verified §11.5 |
| the pad half of every published vector | OPEN (needs the `Z_S` step of a module written at `MSG == PAD`) | **CONSTRUCTED** | the same solve; the masking commitment `M`'s own opening is excluded and is the separate CFS channel, still OPEN |
| opened column values | OPEN (a function of the pads) | **CONSTRUCTED** | every row re-encoded and read at every distinct sampled position, and the rebuilt columns re-hashed and re-authenticated |

**Nothing else moved.** In particular:

* **a preimage for a RUN** — still OPEN. What exists is ten per-commitment
  preimages; a run preimage is a JOINT object, one randomness reproducing
  every stage's view at once with each boundary plane shared between three
  commitments. P-5 is a live demonstration that per-commitment existence
  does not give joint existence.
* **the masked sumcheck rounds and the CFS channel** — still OPEN, and now
  the largest open one a port could close.
* **the Merkle roots, the leaf salts, the authentication paths** — still
  ARGUED (M-2, M-3). Re-authenticating an OPENED column says nothing about
  what an UNOPENED leaf hides.
* **the cross-block joint law, the boundary scale tags, the integer-range
  facts, any nonlinear functional** — unchanged.

When `--full-preimage` is not passed, `stage11_full_preimage` records that
it was not requested and the three channels stay OPEN with round 1's reason
plus a sentence saying round 7 removed the assumption. **The ten records of
rounds 1–6 keep their 2 / 5 / 4 / 14 counts**, which is how the refresh in
§11.9 can be a leaf diff with nothing measured moving.

## 11.8 What this establishes, and what it does not

**It establishes**, for these four captured runs, these two development
shapes and these runs' real challenges: the linear view of every PCS
commitment — both halves of every published vector, every claim value,
every opened column entry, and the salted leaves of the opened columns — is
**reproducible from a data block that is identically zero**, with blinding
that the gate exhibits and that the gate then checks by recomputing the view
entry by entry. Two of the four runs were proved on a fully dense generic
hidden input; their views have a preimage at zero all the same.

**It does not establish:**

* **anything about the LAW of the blinding.** A preimage exists; whether the
  honest prover's randomness is uniform on the fibre is the lemma's job
  (obligation O-R2 / gap G-R4) and nothing here bears on it.
* **that the zero DATA BLOCK is a reachable witness.** What is fixed is the
  data rectangle of the commitment, set to zero — the same object the toy
  gate and rounds 1–6 call "the all-zero hidden input". Whether a model
  input exists whose activations are exactly that block is a question about
  the block's ARITHMETIC, not about its linear view, and this gate does not
  ask it. The statement is about the view map.
* **a RUN preimage** (§11.7), and nothing joint: P-5 exhibits the gap.
* **anything about the CFS / masked-sumcheck channel**, which is untouched.
* **anything about an unopened Merkle leaf**, which no preimage can
  reproduce.
* **anything at the 125M shape**, where `A` has thousands of rows, nor
  anything nonlinear, nor anything about the four out-of-band channels.
* **and it is not a privacy acceptance.** Both bundles carry
  `privacy_review_complete: false`, and so does every record round 7 wrote.

## 11.9 Timings, memory, the refresh and the suite

The whole gate with the arm on is **170–193 s per bundle**, of which
stage 11 is **70–77 s**; the solve itself is **20–22 s** of that and the
rest is the verification, which is the part that is worth the time. The
gate PROCESS peaks at **677–713 MB**, but that is four bundles held at once
(`--other`, `--old`, `--cross-profile`); isolated, one bundle and its views
are 215 MB and **the arm itself adds 103 MB** (`mem_probe.py`, rung-K4, the
largest of the four). Measured with `/usr/bin/time -v`; §R7.6 of the ledger
has both figures.

The arm is **off by default**, so the gate stays a ~10–25 s tool and no
earlier figure changed cost. The ten records of record were nevertheless
re-run, because the tool hashes moved and the record gained one stage block,
and diffed **leaf by leaf** against the committed bytes: the ledger's §R7.7
has the table — **0 unclassified leaves on all ten**, and the ten records
still read 25 channels at 2 / 5 / 4 / 14.

The suite: `test_zk60_native_run_gate_ahpreimage.py` **30 tests, OK**;
`-p 'test_zk60_native_run_gate*.py'` **214 tests, OK** (round 6: 184);
`-p 'test_zk60_native*.py'` **390 tests, OK**, 457.6 s, one skip and one
recorded expected failure (round 6: 360). **No assertion of rounds 1–6 had
to move.** The ledger's §R7.8 has the two assertions of round 7's OWN test
file that did, and why each was wrong about the record rather than about
the gate.

## 11.10 What this round is NOT

* **It is not a privacy result and not a step toward one on its own.** It
  closes three channels of a table with eleven still open, and the two
  biggest open ones — the joint law and the CFS channel — are untouched.
* **It is not a statement about the prover.** The exhibited blinding is a
  SOLVED object for a public fixed data block. No capture carries a witness
  and none was read; the record keeps a sha256 of the exhibited randomness,
  not its values.
* **It does not make `joint == sum` mean more than ruling R-3 says.** P-5
  points the other way.
* **It does not generalise to the 125M shape by arithmetic.** The solve is
  `O(rows · d²)` in the pads and `O(G · n · rows)` in the verification; at
  125M both grow, and nobody has measured it.

---

# 12. 2026-09-21, eighth round: the masking commitment `M` and the CFS channel, constructed at the shaped layouts — and the run's preimage made JOINT

**Written 2026-09-21 on the same lane.** New modules:
`scripts/zk60_native_rg_mask.py` (the port and the driver),
`scripts/zk60_native_rg_mcontrols.py` (six controls),
`scripts/zk60_native_rg_mjoint.py` (the joint run preimage); the gate gains
two stages, `--mask-cfs` → `stage12_mask_and_cfs`, and
`stage13_joint_run_preimage` when BOTH arms are on. Evidence:
`results/zk60_native_run_gate_mask/`. Tests:
`tests/test_zk60_native_run_gate_mask.py`.

§11.7 named the next thing: "the masked sumcheck rounds and the CFS
channel — still OPEN, and now the largest open one a port could close."
Round 8 closes it, and closing it makes the run's preimage joint.

> **STILL NOT A PRIVACY ACCEPTANCE AND STILL NO PRIVACY PROPERTY.** The
> masking layer's fixed data is a NAMED PUBLIC element of the channel's data
> space, not the zero witness's own honest round messages, which no capture
> carries and which this gate cannot compute. §12.8 is the list of what this
> does not show.

## 12.1 The headline, in one line each

1. **The reason channel 7 carried since round 1 was partly wrong, and
   saying so is round 8's first result.** It said the mask-row port and the
   CFS analysis "are written at the toy's row layout and slot specs". They
   are not: `MaskModel`, `MaskPreimage`, `disclosed_dimension` and
   `CfsPreimage` read `mask["specs"]` from the capture and DERIVE `M`'s
   `2S + 4` rows, so they are already driven by whatever slot table they are
   handed. Five other things were layout-specific (§12.2), and those are
   what round 8 supplied.
2. **`M` has fifty rows and thirty-four functionals at BOTH rungs**, because
   `layout.rs` sets `M_ROWS = 2·N_SLOTS + 4` and `N_FUNCTIONALS = 34` as
   constants of the block's slot table and not of the shape. What the rung
   moves is every `L_s`.
3. **The two sides are JOINED.** The toy gate solves the masked rounds and
   `M`'s opening separately and never checks that one coefficient vector
   does both. Round 8 feeds the CFS-solved coefficients to the `M` preimage:
   **one vector per stage** reproduces all 23 slots' masked rounds and
   mask-bearing scalars, all 34 functional values, `M`'s `q`, `M`'s
   proximity vector and all 12,800 of `M`'s opened column entries.
4. **Every figure of the port equals the TOY gate's own, to the byte** —
   including the two exhibited-randomness digests `e0513e22…` and
   `f943d3a0…`: 19 of 19 compared figures (§12.4).
5. **Six controls, all fire** (§12.6), and two of them say more than was
   asked: a moved entry of an a-row's opened column fires at exactly FOUR
   entries, all on the `b` and `u` rows of that one column; and M-5 is the
   masking layer's own P-5.
6. **A JOINT run-wide preimage** (§12.7), the thing §11.7 listed as still
   open: one assignment per run, **1,145,727–1,329,950 entries recomputed
   and compared per run and 4,954,912 over the four, none differing, 3,328
   salted leaves re-authenticated per run and 13,312 over the four**, with
   the four couplings of an honest run enumerated and each checked.
7. **The channel table goes from 25 to 28 and from 5 / 5 / 4 / 11 to
   10 / 5 / 4 / 9.** Three channels are new (`M`'s `q`, `M`'s proximity
   vector, `M`'s own opened columns — the TOY gate has graded them
   separately since its §14 and the run gate never did); two moved from
   OPEN to CONSTRUCTED (the masked rounds, and the RUN preimage).

## 12.2 What in the toy port was layout-specific, exactly

Named in the port's own `LAYOUT_SPECIFIC` map, which a test requires to have
exactly these five keys and each to say what replaces it:

| # | what the toy does | why it cannot be used as written | supplied here |
|---|---|---|---|
| 1 | `SOURCE_PINS` / `PATH_PINS` read at the toy lane's commits | **five** of the files the mask port transcribes moved by the bundles' capture commits: `zk.rs`, `pcs.rs`, `merkle.rs`, `transcript.rs`, `argument.rs` | `MASK_LAYER_PINS` (bundle-side, three files) and `NOT_PINNABLE_FROM_A_BUNDLE` (eight files, each with the reading of its difference) |
| 2 | takes a `Capture` and a `Replay`, one proof, three challenge attributes | a run has L stages and keeps the three per stage | `StageReplay`, three lines; the run `Stage` object serves as the capture unchanged |
| 3 | `MASK_LOG_MSG = 9`, `MASK_LOG_DOM = 12`, `MASK_Q = 256` as module constants | a bundle declares its own mask domain, and a shape that moved any of the three would make the toy solver silently wrong | `derive_mask_domain`, which READS the domain from the bundle and refuses by name on a difference |
| 4 | nothing to check `mask["specs"]` against (the toy's slot table is a Rust constant no capture carries) | a run bundle carries `shape["slots"]` | `check_specs_against_shape`: every `(n_s, d_s)` re-derived as `(main + ext, degree)` and compared |
| 5 | does not hash | a run bundle carries `M`'s root, 256 salts and 12-level paths, and the loader derives the rule | `_hash_layer`, the same arm round 7 added for the PCS side |

**The pins, read and then written down.** `argument.rs` moved from
`e62f46c2…` to `dd8469cb…`; read hunk by hunk, the declared-order block and
`acc.fs.extend(hosts)` are IDENTICAL except that `sum_weights(s)` became
`sum_weights(&sh, s)`, and `fn sum_weights(sh, slot)` is
`CfsMask::sum_weights(n + e, d)` over `sh.slots()[slot]` where the toy read
a module-level `SLOTS[slot]` — the same function of the same triple, taken
from the shape instead of a constant, which is precisely what item 4 above
now checks. `zk.rs` moved from `c5b54753…` to `d4280962…`; the diff is **106
lines added and one removed** (a trailing blank), and the addition is the
three D19 / T-1 keyed entry points `mask_commit_tagged`,
`mask_verify_tagged` and `pcs_hash_column_keyed`. Every function the port
transcribes and all three constants are byte-identical, and the tagged
commit draws its randomness in exactly `mask_commit`'s order and builds
exactly `mask_commit`'s rows. `sumcheck.rs`, `ntt.rs`, `field.rs` and
`rng.rs` are **unchanged** at all three capture commits. `pcs.rs`,
`merkle.rs` and `transcript.rs` moved for the keyed forms, and those are
checked by COMPUTATION rather than by a pin: the column indices and every
challenge are re-derived by stage 2, and every one of `M`'s 256 opened
columns is rebuilt and re-authenticated here.

**And what cannot be pinned at all.** `run_capture.rs::SOURCE_FILES` pins
eight `private_block` files and no `zkp-core` or `hashline` root file, so no
bundle carries a digest for `zk.rs` or for any of the seven `zkp-core`
files. They are NAMED rather than merely absent, with the digest read at the
capture commits and the reading beside it. That is a writer-side ask, and it
is R6.8 item 1 again with a longer list.

## 12.3 The `M` system at the shaped layouts

With `S = 23` slots, `M` is `2S + 4 = 50` rows over the coset `7·G_4096`:

| rows | what they hold | free values |
|---|---|---|
| `2s`, `2s+1` | slot `s`'s mask coefficients, real and imaginary parts, in VALUE form over `G_512`: `[ L_s coefficients \| 256 pads \| zeros ]` | the 256 pads of each row |
| `46`, `47` | `b_re`, `b_im`, 1,024 coefficients each, one constraint `b[512] = -b[0]` | 1,023 each |
| `48`, `49` | `u_re`, `u_im`, 1,024 coefficients each | 1,024 each, unconstrained |

`L_s = CfsMask::len(n_s, d_s) = n_s d_s + 2` with `(n_s, d_s) = (main_s +
ext_s, degree_s)` from `Shape::slots`. The two BILINEAR slots are the ones
stage 20 repaired (finding S19-F1): they alone have `ext = 2`, and their
degree gains one when `lkv > 0`.

| | rung-G | rung-K4 |
|---|---|---|
| slots / rows / functionals | 23 / **50** / **34** | 23 / **50** / **34** |
| slot 08 (`SC_SCORE`) `L` | **23** | **23** |
| slot 09 (`SC_PV`) `L` | **26** | **29** |
| largest `L` | **72** (slots 17, 18) | **77** (slot 17) |
| coefficient unknowns | **1,718 `Fp`** (859 `Fp2`) | **1,742 `Fp`** (871 `Fp2`) |
| disclosed / `M`'s fibre | **2 `Fp`** / 1,716 | **2 `Fp`** / 1,740 |
| the CFS fibre per stage | **46 `Fp`** (2 per slot) | **46 `Fp`** |
| blinding unknowns in `M` | **15,870 `Fp`** | 15,870 `Fp` |
| published round entries / scalars per stage | **1,055** / 23 | **1,070** / 23 |
| `q` / `prox` / opened column entries per stage | 1,024 / 1,024 / **12,800** | the same |
| distinct opened columns `D` / pad margin | 246–254 / **2–10** | 248–251 / **5–8** |

**The functionals and their declared order**, taken from the code and not
from a memo: for each slot `s` in slot order, a **Standalone** slot's
`Gamma` immediately before its own evaluation functional, then that
evaluation; a **Host** slot contributes only its evaluation there, its
`Gamma` deferred; a **Private** slot contributes its evaluation alone; then
every Host slot's `Gamma`, in slot order, LAST. At both rungs the slot kinds
are 12 Private, 6 Host, 5 Standalone, and the port checks the order against
the capture three ways — POSITION, VALUE and WEIGHTS recomputed from
`CfsMask::sum_weights · c` and `CfsMask::eval_weights` at the replayed
challenges. **34 of 34 on all three checks, on every stage of every
bundle** — the same "34 of 34" the toy gate reports, at a different shape.

**The batching challenge θ** is drawn at the `M` site and stage 2 re-derives
it; `combined_weights` weights functional `i` by `θ^i`, so the ORDER is
load-bearing (control M-3). `combined_weights` also bounds every term's
weights by `L_row`, so `ws[s][t] = 0` for `t ≥ L_s` — checked per stage as
`weights_vanish_above_L` — and therefore the pads drop out of the sum and
`b`'s only constraint reads exactly `512 (q[0] + q[512]) = V(a)`, the
verifier's own first check.

## 12.4 It is the toy module's construction, and that is asserted

`zk60_native_mask_commit.py` and `zk60_native_pg_cfs.py` are hash-pinned
records this lane does not edit, and round 8 does not edit them: a test
asserts their sha256 unchanged. Four things keep the port from being a fork:

* **Every object is IMPORTED, not re-derived.** `IMPORTED_OBJECTS` lists
  twelve names from `zk60_native_mask_commit`, `CfsPreimage` from
  `zk60_native_pg_cfs` and `column_bytes` from `zk60_native_rg_hashlayer`; a
  test asserts each name in the new module IS that module's object, and that
  the new module's source defines no `def`/`class` of those names.
* **`LAYOUT_SPECIFIC`, `DERIVED_FROM` and `NEW_HERE`** name the five things
  supplied, the toy entry point each figure comes from, and everything the
  new module adds; a test requires every definition in the file to be in one
  of the maps.
* **The equivalence run.** The driver, at the toy's widths, on the tracked
  toy block capture `40083e7a…`, against the figures the TOY gate's
  committed record carries: **19 of 19 equal**, including the disclosed
  dimension 2, the unknown space 1,166 `Fp`, the fibre 1,164, the 34/34/34
  order check, 50 rows, 246 distinct columns, pad margin 10, 12,800 column
  entries, 721 round entries, 23 scalars, the CFS fibre 46 `Fp`, the
  projection `{34 conditions, 29 unmet, 68 Fp}` and **both
  exhibited-randomness digests**.
* **The join also works at the toy**: the CFS-solved coefficients reproduce
  the toy capture's `M` opening entry by entry too, which the toy gate never
  asked.

## 12.5 What was constructed and verified

Every stage of all four current bundles. The fixed data of the masking layer
is the flat honest transcript whose claimed sum the hosted slots' published
scalars force, projected onto the 34 functional identities (the conservative
accounting); what is SOLVED is the `L_s` mask coefficients of every slot,
the 256 pads of every a-row, the two `b` rows and the two `u` rows.

**The masking layer, per bundle** (three stages each; an `Fp2` entry counts
once, as in §11.5):

| bundle | masked round entries | scalars | functional values | `q` | `prox` | opened columns | **total** | **differing** | salted leaves | stage-12 s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `run-g-dense-s20` | 3,165 | 69 | 102 | 3,072 | 3,072 | 38,400 | **47,880** | **0** | 768 | 18.0 |
| `run-h-zero-s20` | 3,165 | 69 | 102 | 3,072 | 3,072 | 38,400 | **47,880** | **0** | 768 | 17.9 |
| `run-i-dense-k4` | 3,210 | 69 | 102 | 3,072 | 3,072 | 38,400 | **47,925** | **0** | 768 | 18.0 |
| `run-j-zero-k4` | 3,210 | 69 | 102 | 3,072 | 3,072 | 38,400 | **47,925** | **0** | 768 | 18.0 |
| **total** | 12,750 | 276 | 408 | 12,288 | 12,288 | 153,600 | **191,610** | **0** | **3,072** | |

"Entries compared" means the view was RECOMPUTED from (the fixed transcript
+ the solved coefficients + the solved blinding) by the forward map and
compared with the capture, entry by entry. **None differ**, on any stage of
any bundle. The two ZERO bundles are the sanity anchor as they are for round
7: on them the prover's own hidden input was all zero, and the masking layer
behaves exactly as on the dense ones — which is itself the point, since the
masking layer's data is a transcript and not an input.

**Per stage the figures are flat**, because `M`'s geometry does not depend
on the stage: 50 rows, 34 functionals, disclosed 2 `Fp`, the CFS fibre 46
`Fp` (2 per slot, on all 23), `q` and `prox` 1,024 entries each, 12,800
opened column entries, 256 salted leaves at 12 levels. What varies from
stage to stage is only `D`, the number of distinct sampled columns, and
therefore the pad margin: **2 to 10** over the twelve stages.

**The hash layer of `M`'s opened columns.** For each of the 256 opened
columns of each stage the column is rebuilt from the preimage, its leaf
digest recomputed under the bundle's own derived rule, salted with the
PUBLISHED salt and folded along the PUBLISHED 12-level path. All 768 per
bundle reach the committed root and all 768 rebuilt columns equal the
capture's bytes. The unopened leaves are not reproduced and cannot be.

**Joined with round 7**, the whole run (§12.7):

| bundle | PCS entries (round 7) | masking entries (round 8) | **joint total** | **differing** | salted leaves |
|---|---:|---:|---:|---:|---:|
| `run-g-dense-s20` | 1,097,847 | 47,880 | **1,145,727** | **0** | 3,328 |
| `run-h-zero-s20` | 1,103,569 | 47,880 | **1,151,449** | **0** | 3,328 |
| `run-i-dense-k4` | 1,282,025 | 47,925 | **1,329,950** | **0** | 3,328 |
| `run-j-zero-k4` | 1,279,861 | 47,925 | **1,327,786** | **0** | 3,328 |
| **total** | 4,763,302 | 191,610 | **4,954,912** | **0** | **13,312** |

**Where the honest round polynomials went, and why there is no pretending.**
Round 7 could fix its data block to ZERO because a data block is a public
object. This channel's hidden data is each slot's *honest, unmasked* round
messages and honest scalar, and **no capture carries them**: the security
owner has refused publishing them for a real slot, and
`ZK60_PRIVACY_CASE_FIRST_MVP.md` §4.3 asks for them only as a labelled
synthetic fixture. They are not recoverable from a bundle either. For the
all-zero WITNESS the honest round polynomials *are* a deterministic function
of the public weights and the challenges — but evaluating them means running
each slot's composition over its whole `2^(main+ext)` cube through the
prover's table machinery, which this gate does not have and which the
capture does not carry. So the gate does what the toy gate does and says so
in the record: it FIXES `CfsPreimage.flat_transcript`, a named, public,
deterministic element of the channel's data space, and SOLVES for the
coefficients. **The zero transcript itself is infeasible** on every stage of
every bundle — `zero_transcript_is_infeasible: true` — and that infeasibility
IS the disclosed dimension made visible; the projection then moves the fixed
transcript onto the identities, 29 of the 34 conditions unmet before it and
`68 Fp` of conditions in total, the same two figures the toy gate reports.

## 12.6 The controls

Each is shown to PASS on the honest capture first, and each perturbation is
applied to an in-memory SHADOW of the stage — a shallow copy of `arguments`
and `mask` with exactly one field replaced. Nothing on disk is written, and
a test re-reads the bundle afterwards and compares every file's sha256.

**Two of the six say more than the brief asked.**

**M-2 at an a-row fires at exactly four entries.** Moving one entry of an
opened column at an a-row does NOT break that row: the a-rows carry 256 pads
against 246–254 distinct sampled nodes, so their Cauchy block is square and
nonsingular and the pads absorb the moved target exactly. It breaks the
FOUR rows below — `b_re`, `b_im`, `u_re`, `u_im` — at that one column and at
no other, because `b` is the residue of `q` and `u` the residue of the
proximity vector: absorbing the move on the a-row moves the verifier's
per-column identity at that node, and the capture's own `b` and `u` entries
there contradict it. **The pads buy the a-row and pay for it four rows
down.** At a `b` row the same perturbation fires at one entry, directly.

**M-5 is the masking layer's P-5.** Two slots are declared to share one mask
coefficient, and WHICH index is used is computed from the two slots' own
kernels rather than chosen. At an index where both slots' rounds leave a
whole `Fp2` free the identification is satisfiable, and the record says so
rather than hiding it. At an index where both FORCE the value — index 3 at
rung-G, found by arithmetic — the two forced values differ and **no joint
assignment exists**, while `M`'s own disclosed dimension stays at 2 `Fp`
either way and the unknown space and the fibre each lose exactly the 2 `Fp`
the identification removes. Per-slot solutions exist and a joint one does
not: the same shape of fact as round 7's P-5, one layer down, and the reason
§12.7's joint claim has to be earned rather than assumed.

## 12.7 The JOINT run-wide preimage

§11.7 listed "a preimage for a RUN" as open and P-5 as the reason it was not
a formality. With the masking layer constructed the two halves can be
joined, and `stage13_joint_run_preimage` does it — but only after
enumerating what actually couples the parts of an honest run and checking
each:

| | coupling | checked | verdict |
|---|---|---|---|
| **C1** | the internal boundary planes and the two endpoint planes: rows two commitments HOLD and a third claims about | every identified row pair, row by row, on both sides | **24 pairs on every one of the four bundles, 24 of 24 data rows on both sides, none touching a blinding row** |
| **C2** | published CLAIM VALUES that more than one commitment carries | counted, not assumed to be zero | 531 claim values, 529 distinct, **1** carried by two commitments (the same figure on all four) — and each part meets the number the CAPTURE carries, so it is met identically by both |
| **C3** | the masking layer against the 23 slots | the declared order 34 of 34 by position, value and weights; all 34 values recomputed from the solved coefficients | **respected, and by ONE coefficient vector per stage** |
| **C4** | the terminal identity `fin_s = c_s·mask_eval_s + poly_s(terminals)`, degree up to 4 | no linear model sees it | **respected only in a narrow sense**, stated below |

**Why C1 is the whole of it.** An identification between DATA rows is
satisfied because the data block is zero on both sides. An identification
that reached a BLINDING row would be P-5 exactly — two commitments each
forcing the shared row to a different value. So the count "24 of 24 data
rows, 0 touching a blinding row" is the entire difference between "each part
has a preimage" and "the run has one", and it is computed from the layout's
own identifications rather than asserted.

**What C4 can and cannot mean.** Every quantity the terminal identity
relates — `fin_s`, `c_s`, `mask_eval_s` and the terminals — is a PUBLISHED
number, and this assignment reproduces every published number of the run
exactly. So the identity holds at the reproduced view for the trivial reason
that the reproduced view IS the captured view, entry by entry. That is NOT
the statement that the assignment is a witness of the identity's arithmetic:
the terminals are met as claim VALUES by blinding, and whether a model input
exists whose activations make them is a question about the block's
arithmetic that no preimage argument answers (§11.8, second bullet).

**The channel table, recounted.** 28 channels: **10 constructed, 5 derived,
4 argued, 9 open** (round 7: 25 at 5 / 5 / 4 / 11), the same on all four
bundles, with `grading_failures` empty. Three entries are NEW and two
statuses MOVED; nothing else changed:

| channel | was | is | why |
|---|---|---|---|
| `M`'s opening: the product polynomial `q` and the batched value it pins | *(not graded separately by this gate; the TOY gate has graded it since its §14)* | **CONSTRUCTED** | §12.3, §12.5; the disclosed dimension computed as an exact rank, the refusal one off the `V` plane exhibited |
| `M`'s proximity vector | *(not graded separately)* | **CONSTRUCTED** | the same solve; reproduced BY CONSTRUCTION, and the record says so |
| `M`'s own opened columns and their salted leaves | *(not graded separately)* | **CONSTRUCTED** | 153,600 entries over the twelve stages, 3,072 salted leaves re-authenticated |
| the masked sumcheck round messages and the published scalars | OPEN (the port "is written at the toy's row layout and slot specs") | **CONSTRUCTED** | §12.5; 12,750 round entries and 276 scalars recomputed and compared, none differing |
| the preimage construction for a RUN | OPEN (per-commitment existence is not joint existence, P-5) | **CONSTRUCTED** | §12.7; the four couplings enumerated and each checked, 4,954,912 entries over the four runs |

**Nothing else moved.** In particular the Merkle roots, the leaf salts and
the authentication paths are still ARGUED (M-2, M-3); the cross-block joint
LAW, the boundary scale tags, the integer-range facts, any nonlinear
functional and the four out-of-band channels are unchanged; and the run's
`privacy_review_complete` is still `false`.

When `--mask-cfs` is not passed, `stage12_mask_and_cfs` records that it was
not requested and the four channels stay OPEN; when either arm is off,
`stage13_joint_run_preimage` records that it needs both.

## 12.8 What this establishes, and what it does not

**It establishes**, for these four captured runs, these two development
shapes and these runs' real challenges: the masking layer's whole published
linear view — every slot's masked round messages and mask-bearing scalar,
all 34 functional values, `M`'s product polynomial, `M`'s proximity vector,
every one of `M`'s opened column entries and the salted leaves of those
columns — is reproducible from ONE coefficient vector per stage at a fixed
public transcript, with blinding the gate exhibits and then checks by
recomputing the view entry by entry; and that this, joined with round 7's
per-commitment construction over a data block that is zero everywhere, is a
single assignment reproducing the WHOLE run's linear view at once, with the
four couplings enumerated and each checked.

**It does not establish:**

* **anything about the LAW of the blinding or of the mask coefficients.**
  A preimage exists; whether the honest prover's `CfsMask::random` draws are
  uniform on the fibre is the lemma's job (obligation O-R2 / gap G-R4) and
  nothing here bears on it. **The law of the mask coefficients is the
  lemma's job, not the gate's.**
* **that the fixed transcript is the zero witness's own.** It is a named
  public element of the channel's data space; the honest unmasked rounds are
  in no capture and this gate cannot compute them (§12.5).
* **that the zero data block is a reachable witness** — unchanged from
  §11.8.
* **anything about an unopened Merkle leaf.** `M`'s root, its 256 leaf salts
  and its 12-level paths stay ARGUED under M-2 / M-3; re-authenticating an
  OPENED column says nothing about what an unopened one hides.
* **anything nonlinear** beyond C4's narrow sense, and nothing about the
  four out-of-band channels.
* **anything at the 125M shape.** Nothing here was measured there, and
  `L_s + 256 ≤ 512` is a constraint a bigger shape could break — which is
  exactly why `derive_mask_domain` refuses rather than assumes.
* **and it is not a privacy acceptance.** Both bundles carry
  `privacy_review_complete: false`, and so does every record round 8 wrote.

**Ruling R-3 still applies wherever a joint figure appears**: the run gate's
joint figures are a consistency check of coordinate classes, not evidence
that the commitments' blinding is independent. §12.7's joint preimage is a
construction over those classes, and C1 is the check that the classes really
are disjoint in the honest layout — it is not evidence about the prover.

## 12.9 Timings, the refresh and the suite

**The masking arm is cheap.** Stage 12 is **5.7–6.2 s per stage** and
**17.4–18.0 s per bundle** for the three stages, and its six controls are
**22 s** more; the joint stage 13 is bookkeeping over the two stage records
and costs nothing measurable. The whole gate with BOTH arms on is
**207–230 s per bundle** (3:27–3:50 wall) against round 7's 170–193 s with
one arm, so the masking layer adds roughly **20 %** to a run already
dominated by the `A` and `H` solves. The gate PROCESS peaks at
**780–851 MB** (round 7: 677–713 MB) — again four bundles held at once
under `--other`, `--old` and `--cross-profile` — so the masking arm adds
about **100–140 MB**. Measured with `/usr/bin/time -v`;
`…/mask/time-<bundle>.log`.

**The arm is off by default**, so the gate stays what it was and no earlier
figure changed cost. The ten records of record were nevertheless re-run,
because the tool hashes moved and the record gained two stage blocks and
three channel entries, and diffed **leaf by leaf** against the committed
bytes: **0 unclassified leaves on all ten**, with every difference in one
of six classes — the channel array (2,326 leaves), the channel counts
(110), the two new stage blocks (50 each), the tool hashes (60) and the
wall clock (23).

**Round 7's own evidence had to be re-taken, and that is a cost round 8
paid rather than hid.** `results/zk60_native_run_gate_preimage/`'s four
records pinned tool digests that round 8 moved, and round 7's own test
`test_the_evidence_came_from_the_tool_bytes_now_in_the_tree` said so. They
were re-run under `--full-preimage` with `--mask-cfs` OFF: **every
stage-11 figure is identical** — 1,097,847 / 1,103,569 / 1,282,025 /
1,279,861 entries, 0 differing, 2,560 salted leaves each — and what moved
is the tool hashes and the channel table, 25 → 28 at **5 / 5 / 4 / 14**,
because the three new entries are OPEN when the masking arm is off. §11.7's
"25 channels: 5 / 5 / 4 / 11" is left as written; it is the count of the
table round 7 had.

**The suite**: `test_zk60_native_run_gate_mask.py` **42 tests, OK**;
`-p 'test_zk60_native_run_gate*.py'` **256 tests, OK** (round 7: 214);
`-p 'test_zk60_native*.py'` **432 tests, OK**, 437.8 s, one skip and one
recorded expected failure (round 7: 390). **Five assertions of earlier test
files had to move** — the channel-count assertions in the `s20`,
`planeindex`, `tagged`, `k4` and `ahpreimage` files — and each is about the
record's SHAPE (three entries added) and not about any figure. Round 7 could
say "no assertion of rounds 1–6 had to move"; round 8 cannot, and says so
instead.

## 12.10 What this round is NOT

* **It is not a privacy result and not a step toward one on its own.** It
  closes five channels of a table that still has nine open, and the two
  largest of those — the joint LAW and the hash layer's hiding — are
  untouched.
* **It is not a statement about the prover.** The exhibited coefficients and
  blinding are SOLVED objects for a public fixed transcript. No capture
  carries a witness and none was read; the record keeps sha256 digests of
  the exhibited coefficients and blinding, not their values.
* **It does not make the joint preimage into the joint LAW.** C1 says no
  coordinate is shared; it does not say the prover's draws for two
  commitments are independent, which is what a privacy argument needs and
  what ruling R-3 keeps separate.
* **It does not generalise to the 125M shape by arithmetic.** `M` keeps 50
  rows there, but every `L_s` grows with the shape and `L_s + 256 ≤ 512` is
  an assertion in `mask_commit` itself; whether it survives at 125M is a
  question for the Rust lane, and nobody has measured the solve there.
