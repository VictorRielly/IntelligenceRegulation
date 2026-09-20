# The RUN gate — what it computes on a multi-block run capture, and what it does not show

**Written 2026-09-20 on lane `zk60-native-jointview`.** Tool:
`scripts/zk60_native_run_gate.py`. Evidence:
`results/zk60_native_run_gate/`. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`.

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

**Is `joint == sum` a theorem here?** Yes, *given two facts the gate
computes rather than assumes*. Only DATA coordinates are shared — no
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

---

## 4. What remains a reviewed obligation, or is simply not done

* **The per-slot terminal check is OPEN at this shape.** The strong form
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
* **The per-slot terminal identity is not checked**, so the nonlinear link
  between the commitment and masking channels is outside everything here.
* **It is NOT a privacy acceptance**, and it establishes no privacy
  property. Ruling M-8 asks for this gate; passing it is one input to a
  decision that is the security owner's and, for the run's soundness level
  and its receipt size, the project owner's.
