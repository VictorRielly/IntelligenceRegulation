# ZK60 O8 — the FFN input/output captures, analysed jointly

**Reviewer:** Opus 5, independent reviewer, 2026-09-09 session (task O8 of
[the Opus queue](ZK60_OPUS_QUEUE.md)).
**Worktree:** `/home/victor/wt-zk60-fa`, branch `zk60-fable-review`, started at
Codex's round-19 tip `863507a`, round 20 merged in at `9d06dd3` during the work.
**Capture producer pin:** `1f0ff3680c4cda88f1744343e24eb93cdddfcba4`.
**Profile:** `ffn-v3-mr1-fresh-io-poc/2`, coverage
`ffn-v3-mr1-fresh-io-poc-function-1`, capture schema 3.

This is a **linear observation-model result on four proof-of-concept captures**.
It is not a privacy theorem, it does not close U-2, and it does not touch Rust.
Codex retains integration and cryptographic judgment.

## Headline

| system | disclosed base dimensions | residual |
| --- | --- | --- |
| A (702 rows) | **0** | — |
| W, P3 (11 rows) | **0** | — |
| Input endpoint (7 rows) | **0** | — |
| Output endpoint (7 rows) | **0** | — |
| H (1326 rows) | **2** | its public LogUp identity, value fixed to 0 |
| **A ∪ Input ∪ Output, X and z16 aliased** | **0** | — |
| **every private commitment, aliased** | **2** | the same public LogUp identity |
| control: the same union with the alias removed | 0 | — |
| control: an endpoint with a legacy single mask row | **256** (1 per column) | the FA1 projection |

Identical on all four captures. The queue set no expected number for this
profile; these are derived, and the earlier profile's zero was not presumed.
Nothing unexpected was disclosed, so there is no finding of that kind to report.

## Artifacts and digests

| file | sha256 |
| --- | --- |
| `scripts/zk60_opus_io_capture.py` (new) | `ccb9043ceb1d372b0800e0cae8e904d3978185b7e466d8003000306fbdade2cb` |
| `tests/test_zk60_opus_io_capture.py` (new) | `eac208d035026252e29dd11cdb37481fea500b3e53cfc8fe04f4aff77359bf7e` |
| `results/zk60_opus_io_capture_analysis.json` (new) | `8e339276e0f45cdee96d5045b577180ccfa17fb987ff30d05636a43fde71fbba` |
| `results/zk60_round19_validation.json` (manifest, read) | `db36bdf514decaa6f9eef850f890083847da55956eae9c9fb47640665a819b0e` |
| `scripts/zk60_opus_repaired_capture.py` (O2, imported unchanged) | `9bc226dce00fd8d1ede28cf49220eab52cf60a019c92fd2b556f1d0e10c516a1` |
| `scripts/zk60_fable_joint_capture.py` (FA7, imported unchanged) | `9dd9b6bafaedeb19c8e2ca008cc255bcede84502dd1f58d3091223e7f6bdf8b2` |
| `scripts/zk60_fable_joint_rank.py` (FA2/FA7 algebra, imported unchanged) | `ad5e4e483c6dd8c5f73a87ddb0af1d06c3084576e82428e9c2ada6a764ffbb5b` |
| `scripts/zk60_opus_io_layout.py` (O7, imported unchanged) | `d9a537ede46f3ebbd58a7bd153c7cfcebe79ddf553c6f7eadc153b295e77ace4` |
| `scripts/zk60_opus_wire_length.py` (O5, imported unchanged) | `6c5de133fa4a85939ff5d46bb0b1a4494366c02ec8282c6bd7c89fa1c8608e5a` |
| `scripts/zk60_io_capture_preflight.py` (Codex, reviewed + re-run) | `a4e230f5f6aed62fc0f12b662a3b3becbbb6bee1d41cd12c06baa6918a5ce217` |
| `scripts/zk60_io_capture_controls.py` (Codex, reviewed + re-run) | `8128d3e2a5afcd3f34c78271f58c6ab8a5ae0a7e53091e4f49a38fbf2fc2369a` |
| `scripts/zk60_io_opening_translation.py` (Codex round 20, cited only) | `3579e0ff10f5f501a5596e3ef56dc812060a8f34a883910b2bb89c8c675ae0bf` |
| `results/zk60_round20_opening_translation.json` (cited only) | `efd99b15c8f66e981809fbad0b9342b8c2ee434a8908fbb859043a22fc146951` |

Nothing outside the four new files was edited. The archived FA7/O2 tools, their
tests and their results keep their original meaning; they are imported by path
and never re-pointed at these captures.

## Commands and exit codes

```
python3 scripts/zk60_io_capture_preflight.py --captures /tmp/zk60-round19/captures \
    --source-commit 1f0ff3680c4cda88f1744343e24eb93cdddfcba4 \
    --output /tmp/zk60-opus-o8/codex_preflight.json                        exit 0
python3 scripts/zk60_io_capture_controls.py --capture <P1 capture> ...     exit 0  (32 controls)
python3 scripts/zk60_io_capture_controls.py --capture <P3 capture> ...     exit 0  (32 controls)
python3 scripts/zk60_opus_io_capture.py preflight --captures-dir /tmp/zk60-round19/captures \
    --manifest results/zk60_round19_validation.json -o /tmp/zk60-opus-o8/preflight.json
                                                                           exit 0  (51/51 checks)
python3 scripts/zk60_opus_io_capture.py analyze --captures-dir /tmp/zk60-round19/captures \
    --manifest results/zk60_round19_validation.json \
    --legacy-dir /tmp/zk60-round11/final-observations \
    --runs-file /tmp/zk60-opus-o8/runs.json \
    -o results/zk60_opus_io_capture_analysis.json                          exit 0
python3 -m unittest discover -s tests -p 'test_zk60_opus_*.py' -v          exit 0  136 tests, OK
python3 -m unittest discover -s tests -p 'test_zk60_fable_*.py'            exit 0   94 tests, OK
```

136 = the 100 pre-existing Opus review tests plus 36 new O8 tests; the Fable
suite is unchanged at 94. Both counts include no skips on this box. Every
number in this document is reproduced by those two suites and by the analysis
record, which is bound to the capture, receipt, policy, tool and source digests.

---

## 1. The four capture / receipt / policy triples (checklist item 1)

`zk60_opus_io_capture.py preflight` ran **51 checks, all pass**
(`results/zk60_opus_io_capture_analysis.json` → `preflight`). It checks, per
triple and independently of Codex's tool:

* the file `sha256` and byte length against the manifest entry;
* `schema` 3, `kind`, `coverage`, `profile`, `transcript_domain`,
  `weight_policy` `fresh-per-proof`, `proof_digest_encoding`
  `"complete HFFNIO version 2 receipt"`, `fully_verified` true,
  `privacy_review_complete` false, `slot`/`k` null, Goldilocks modulus and
  `u^2 = 7`, shape `{t:32,d:16,f:16}`, shifts `[7,0,14,6]`;
* the source pin `1f0ff36…` in the capture **and** in the manifest's
  `source_commit`, which is the Rust capture producer;
* the receipt: `sha256(receipt) == proof_sha256 == the file stem`, magic
  `HFFNIO\0\x02`, and a byte length **re-derived from the O5/O7 wire model**
  rather than read back — 5 029 244 (P1) and 5 066 204 (P3), both exact;
* the policy: 112 bytes, magic `HFFNEXP1`, 32-byte context, two little-endian
  `i32` scales, then the input and output roots — and those two roots are
  **equal to the two captured endpoint commitment roots**;
* role order, row counts, group shapes, the recomputed layout digest;
* the manifest's own recorded tool digests against the files in this worktree
  (all four match), and its `privacy_analysis_performed` /
  `full_privacy_review_complete` both false.

| receipt digest | mode | capture bytes | receipt bytes | policy sha256 |
| --- | --- | --- | --- | --- |
| `040b90d1c051…` | P3 | 15 088 602 | 5 066 204 | `c9fd11d24c9d…` |
| `43a11148995a…` | P3 | 15 085 864 | 5 066 204 | `c6208f285aeb…` |
| `834237f486ab…` | P1 | 14 488 540 | 5 029 244 | `6e12707a4943…` |
| `edccd0b7e7b9…` | P1 | 14 481 418 | 5 029 244 | `00107f1dc4b0…` |

Two P1 and two P3, exactly as the manifest's `counts` say. All twelve files are
present; no capture was relabelled and none was substituted.

### Codex's preflight (`zk60_io_capture_preflight.py`)

**What it establishes.** It is a genuine independent recomputation, not a
read-back: it derives the layout from O2's `zk_layout` / `expected_role` and
O7's `a_row_map`, rebuilds A's two IO claims and both endpoint expectations, and
compares the capture's declared claim slices, coefficient tags, row-role map,
group shapes and layout description against them. It re-checks each group's
`sum_j eq(tail)[j] v[j] == sum_k lambda_k value_k` equation over the real Fp2
values, the mask-pair coefficient relation `coef[2] == coef[1]*u`, the
transcript joins across `M → (public W) → A → H → Input → Output` and
`io[0] → io[1] → M`, the M slot schedule and its fourteen functionals' widths,
the endpoint policy digest and root binding, the receipt digest, frame magic and
independently derived length, and it refuses duplicate JSON keys and any
floating-point value. It also refuses schema 2 and the superseded `/1` label.

**What it does not establish.** It is a *capture-integrity and geometry* check.
It reads only public observations; it does no rank or disclosure analysis, no
simulator argument, and nothing about pads, encoded-column values, CFS values or
adaptive composition. It checks that the observations are *shaped* as the source
says, not that they hide anything. Its own header says so, and its result
carries `privacy_analysis_performed: false`. It also does not verify the proof:
that is the Rust replay recorded in round 19.

### Codex's real-capture controls (`zk60_io_capture_controls.py`)

Re-run here against one real P1 and one real P3 capture: **exit 0, 32 controls
each**, matching the manifest's recorded batteries exactly.

**What they establish.** Each mutation is applied to a genuinely accepted
capture and must be refused *by the recomputation*, with the unmodified capture
accepted before and after the battery — so a refusal cannot come from an
external digest comparison. They cover the relabelled source, the legacy and
superseded profiles, legacy A rows, a missing mask pair, a copied plane alias, a
broken pair coefficient, a wrong symbolic tag, a missing IO group, a broken
group/terminal equation, a short proximity vector, a missing or swapped
endpoint, an endpoint mask row relabelled as data, missing IO mask slots, an old
mask column width, a missing or mis-shaped functional, an out-of-domain column
index, a non-canonical word, a boolean coordinate, broken opening and equality
joins, a wrong slot, a wrong endpoint terminal, a changed policy digest, a
missing FFN round, and duplicate-key / float / NaN JSON.

**What they do not establish.** They are *ingestion* controls: they show the
parser cannot be fooled, not that the protocol hides anything. They mutate one
P1 and one P3 capture only, and they do not exercise the analysis path at all —
there was none to exercise before this task. Section 5 adds the analysis-side
controls, which are what make a "0" mean something.

---

## 2. Structure, recomputed rather than trusted (checklist item 2)

Everything below is recomputed from the layout rules in
`zkp-core/src/ffn_v3/statement.rs::Layout::new`, `hashline/src/zk.rs`
(`ZkLayoutV3::with_masks`, `with_io`, `build_claims_zk_v3`, `pair_claim`),
`hashline/src/zk_ffn_fresh_io.rs::claim` and
`hashline/src/private_seam.rs::prepare_with_rng`, then compared with the
capture. **Two independent derivations are cross-checked against each other**
before either is compared to the capture: O2's `zk_layout` and O7's
`a_row_map` / `endpoint_plane` / `io_frame_len`. A disagreement between them
refuses the capture.

**A: 702 rows.** 698 base rows plus exactly four appended by `with_io`, at
**698/699** (the X endpoint pair) and **700/701** (the z16 endpoint pair). The
four are disjoint from every data row, every existing terminal-mask row, every
table row, every table-mask row and the proximity pair `44/45`.

**A: seven groups, member counts `[7, 3, 1, 1, 6, 1, 1]`** — the five base
column tails (ρ_F, ρ_D, p2, p5, ρ_tab) plus one per IO equality, since each
equality draws its own ρ and therefore its own tail. Claims 18 and 19 are the
IO claims; claim members are `[[0..6], [7,8,9], [10], [11], [12..17], [18], [19]]`.

**A: the X and z16 aliases are preserved.** Rows 14/15 (plane offset 3584,
`log_size` 9) are opened by **three** claims — 7 (`zcD X`), 10 (`gu X`) and now
18 (the IO equality). Rows 16/17 (offset 4096) are opened by claims 8 (`zcD
z16`) and 19. Row pair 10/11 (`h16`) is opened by claims 5 and 11. In the model
these are one set of unknowns, not three.

**Each IO claim has three parts**: the real plane slice with coefficient
`1 − e`, then the mask pair `(e, e·u)` on its own two rows, at
`698·256 / 699·256` and `700·256 / 701·256`, all at the same column tail.
Coefficient tags `1-e_io`, `e_io`, `e_io*u`.

**Endpoint commitments: seven rows, one claim, one group.** Rows **0/1** are the
data plane (one 512-element slice at offset 0, `log_size` 9 — 32×16 values at
`log_cols` 8); rows **2/3** are the terminal mask pair (offsets 512 and 768,
`log_size` 8, coefficients `e` and `e·u`); rows **4/5/6** are three further
fresh random rows. All five non-data rows are filled from the seam's `ZkRng`,
row 4 is the reserved proximity mask row, and **all seven rows carry a nonzero
proximity coefficient in every capture**. That is the round-19 correction to
O7's `endpoint_plane`, whose `unused_random_rows: [6]` label is now stale
(finding F6); this analysis treats 4/5/6 as proximity rows, as the capture and
the source do.

**The layout description** was recomputed byte-for-byte and its sha256 is
`b7d1388565757d503f0f814dacab351f50bf741d82592a9364cb412cacb012db`, equal to
the capture's `layout_digest` in all four files. Only the A line differs from
the base profile's description; every other line is identical.

**The corrected O7 §6 rule, and it is the rule used here.** Round 19 corrects
O7 §6: each added group vector's **message** portion combines only the rows
selected by that group's claims, while the **proximity** vector combines all
rows of its commitment. That is what the inherited FA7/O2 model has always
encoded — `RoleModel` accumulates a group's block coefficient only over its
member claims' parts, and the proximity coefficient over every row — so O7's
prose was wrong, not the model. This analysis uses the corrected rule
throughout and states it explicitly in the tool's docstring and in
`included_observation_classes`.

What is checkable from the capture alone: which rows each group's claims
reference (the claim mapping), that the proximity `rho` vector has exactly one
entry per row, and that each group's clear vector reproduces its members'
terminals. What is *not* checkable from the capture alone: that the published
clear vectors were actually formed that way from the committed rows — that is
the PCS column-consistency check, which round 19's Rust replay performs and
which this tool deliberately leaves outside the model (§4).

**Structural facts recorded per commitment**: `q_pad` = 256 = `num_col_checks`;
every clear vector has `n + Q = 512` entries; 256 sampled columns from a 2048
domain with 11-node paths (245 distinct indices in the P1 Input endpoint, i.e.
duplicates occur and are handled); the M commitment has 20 rows, 256 sampled
columns from a 4096 domain with 12-node paths, and two 1024-entry vectors.

---

## 3. The joint model, and what combining actually required (checklist item 3)

### 3.1 The model

Unchanged from FA7 §5 as applied per commitment by O2. One base-field unknown
per (row, column); rows opened by several claims are the same unknowns.
Observations, all Fp2 and therefore two base rows each:

* **every** message coordinate `v_g[j]`, `j < n`, of **every** group vector;
* **every** message coordinate `prox[j]`, `j < n`, of **every** proximity vector;
* **every** terminal (claim value), including H's public 0;
* H's public zero-sum constraint `sum_j u[j] = 0` on its `(24, 25)` pair.

`disclosed = rank([data | mask]) − rank(mask)`: the number of base-field data
functionals that survive elimination of every mask contribution.

### 3.2 Per commitment (the inherited `RoleModel`, unchanged)

Every commitment, every capture: **A 0, W 0, Input 0, Output 0, H 2.**
Per-column disclosure is 0 for all of them.

For A (16 planes), W (3) and both endpoints (1 each), every plane is 0 both
projected and isolated — including `X[0]` (rows 14/15), `z16[0]` (rows 16/17)
and each endpoint's data pair (rows 0/1). For H, every one of its 10 planes is
**projected 2, isolated 0**: taken with the masks, any single H plane exposes
the same 2-dimensional public identity, and removing any single plane does not
reduce the joint rank — the 2 dimensions are shared by the identity and no
plane is individually pinned. H's 2 drop to **0** when the zero-sum constraint
is removed, and adding the public LogUp identity as an extra observation does
not raise the joint rank, so the residual **is exactly that public identity**,
whose value the proof itself fixes to 0.

Why the endpoints are 0, concretely: the group observation's mask contribution
is `e·m2[j] + e·u·m3[j]`, and `{e, e·u}` is an Fp-basis of Fp2 whenever `e ≠ 0`
(the verifier refuses `e = 0`), so the mask pair alone spans the whole two-
dimensional observation; the proximity observation is spanned by rows 4/5/6,
whose ρ coefficients have Fp-rank 2 in every capture (checked).

### 3.3 What combining required

Reporting five independent zeros is not a joint result, and the queue says so.
Five things were needed:

1. **One shared column index.** Every commitment opens at `log_cols` 8, so
   `n = 256` everywhere and the aliased planes have the same (row, column)
   decomposition. *Established from the capture.*
2. **A row identification between A and each endpoint.** A rows 14/15 ≡ Input
   rows 0/1; A rows 16/17 ≡ Output rows 0/1. **This is imported, not
   established.** The linear observations cannot prove that A's X slice and the
   endpoint's first 512 values are the same numbers — that equality is the
   *statement* the IO sumcheck proves
   (`zk_ffn_fresh_io.rs:379-410`: `eq(tau, rho[..9])·(t0 − t1) + c·mask_eval`).
   What the capture *does* show, and what is checked here, is that both claims
   are opened at **one** point `rho[..9]`, with **one** coefficient split
   `(1 − e, e, e·u)`, and **one** shared column tail — consistent with the
   alias and exactly what the argument binds. The joint model takes the
   equality itself from soundness. This is the boundary the dispatch asked me
   to document rather than assume, and §3.5 says what it costs.
3. **Separate masks.** A's IO mask pairs are rows 698–701 of A; each endpoint's
   terminal pair is rows 2/3 of its own commitment and rows 4/5/6 are further
   fresh rows. No alias touches a mask row — the model refuses one by
   construction (tested). *Established.*
4. **One block coordinate pair per proximity vector.** The inherited
   `RoleModel` carries exactly one, because it models one commitment. Merging
   three needs three, kept separate: summing them would model an adversary who
   sees only their sum, which is strictly weaker than what is published. **This
   is the one implementation generalisation.** The observation classes, the
   unknown space and the exact linear algebra are unchanged and imported.
5. **One cross-column coordinate space for all terminals**, so that a
   functional may mix terminals of different commitments, plus H's zero-sum
   extra. *Established.*

The inherited model **could** express all of this: the mathematics is FA7's,
applied to a union. Nothing was invented and no new assumption was introduced
beyond the imported alias of item 2, which is named as imported everywhere it
is used.

### 3.4 The joint numbers

| union | block coords / column | rank(mask) | rank(joint) | disclosed |
| --- | --- | --- | --- | --- |
| A ∪ Input ∪ Output, aliased | 24 | 24 | 24 | **0** per column, **0** total |
| the same, alias removed (control) | 24 | 24 | 24 | 0 |
| every private commitment, P1 | 36 | 36 | 36 | 0 per column, **2** total |
| every private commitment, P3 | 42 | 42 | 42 | 0 per column, **2** total |

For the IO cluster the merged system has **712 rows** (702 + 7 + 7 − 4 aliased),
182 272 unknowns of which 88 064 are data, and **the mask rows alone already
span the entire 24-dimensional per-column observation space** — the strongest
form the statement can take here. The whole-system model has 2 049 merged rows
(P3) / 2 038 (P1) and 524 544 / 521 728 unknowns; its 2 disclosed dimensions
appear only in the cross-column part (`cross_column_increment` 2, per-column 0),
vanish when H's zero-sum constraint is removed, and are matched exactly by the
public LogUp identity. **No functional of X, z16, any other A plane, or W
survives.** The aliased `X[0]` and `z16[0]` planes are 0 projected and 0
isolated in the merged model (their merged row indices shift — 25/26 and 27/28
in P3, where W's 11 rows precede A's — because the merged model renumbers).

The unaliased control also gives 0, which is the honest reading: in this
structure the alias does not *change* the answer, because every mask row is
private to one commitment and each commitment's masks already span its own
observation space. The joint computation is what shows that, and it is not
implied by the five independent zeros in general.

Three cross-checks make the number mean something:

* **`JointModel` reproduces the inherited `RoleModel` exactly** on every single
  commitment of every capture (same `rank_mask`, `rank_joint`,
  `disclosed_total`, both cross-column kernels, same per-column ranks).
* **An explicit, uncompressed per-column observation matrix** — written out row
  by row over all 712 merged unknowns with no site compression — gives the same
  `rank_mask`, `rank_joint` and per-column disclosure as the compressed model.
* **The ablation control**: dropping the endpoint's second (`×u`) mask part,
  i.e. rebuilding the legacy single-base-mask form on this very commitment,
  makes the same machinery report **256** disclosed dimensions (1 per column).
  A model that cannot see the legacy leak proves nothing; this one sees it.

### 3.5 What Codex's round-20 lemma can draw from this

Round 20 proves, at fixed claim points, group lambdas and proximity challenges,
that any **message difference which already satisfies the individual terminal,
public-row, shared-endpoint-plane and zero-sum conditions** can be absorbed by
each owner's independent pads so that every group and proximity vector and every
sampled encoded word stay unchanged simultaneously, bijectively on the pad
space — and the analogous statement for the eight-slot M opening and its two
blinders. In Codex's words the lemma "does not supply the message difference or
prove those conditions satisfiable", and "O8 must still establish the required
joint message result".

**This result supplies that premise, and here is exactly which of its conditions
are established and which are not.**

Established here, jointly and simultaneously across the commitments:

* every message coordinate of every group vector of every commitment in the
  union is preserved — column by column, this is precisely the lemma's
  `B·delta_D[:,j] = 0`;
* every message coordinate of every commitment's proximity vector is preserved;
* every individual claim terminal is preserved;
* H's public zero-sum condition is preserved (it is an explicit observation
  here, not an afterthought);
* the **shared endpoint planes** are respected by construction: X and z16 are
  one set of unknowns, so a single difference is compensated inside A *and*
  inside its endpoint at once, by their separate masks. This is the condition
  the lemma cannot get from independent per-role checks.

In dimensions: for the IO cluster the space of admissible differences projects
onto **all 88 064** shared data unknowns — nothing is pinned. For the union
containing H it projects onto a **codimension-2** subspace, the 2 conditions
being exactly the public LogUp identity whose value the proof fixes to 0; that
is a public constraint, not witness information, and it is one of the conditions
the lemma already requires.

Not established here, and therefore still attached to the premise:

* **public rows.** Every data row of every private commitment is treated as a
  free unknown. If the statement publicly determines any committed row, the
  lemma's premise additionally requires the difference to vanish there, and this
  model does not impose it. Codex should say which rows, if any, that is.
* **the alias itself**, imported from the soundness of the IO equality sumcheck
  (§3.3 item 2). If that import is not acceptable in the composed argument, the
  joint statement degenerates to the unaliased one and the lemma's
  shared-endpoint-plane condition is no longer supplied by this result.

And the lemma's own exclusions remain open and are **not** accepted here: fixed
challenges only (adaptive Fiat–Shamir is untouched), one opening only (repeats
excluded, and its own negatives show one blinder translation generally cannot
preserve two M weightings), the salted Merkle roots and authentication paths are
*not* held fixed, CFS round messages are outside it, and the caller-fixed
endpoint roots still need a specified preparation/auxiliary-input model. **The
adaptive composition and the caller-fixed endpoint simulation are not marked
accepted.**

---

## 4. What is deliberately outside the model, and what is still owed (item 4)

The capture now *contains* all of these observations. Containing them is not
analysing them; none of them entered the linear model.

**Excluded classes** (unchanged from FA7/O2, plus two restated for this
profile): `pads`, `sampled_columns`, `cfs`, `repeats`, `unopened_columns`,
`adaptive_composition`, and the new `endpoint_second_encoding`.

**Validated in structure only** (widths, ranges, path lengths, bindings — never
values): pad widths, sampled columns, the whole CFS/M section, and the endpoint
policy.

### Cross-component obligation inventory for Codex

| id | class | what this capture actually contains | what is still owed |
| --- | --- | --- | --- |
| OBL-1 | pads | 18 (P1) / 21 (P3) role clear vectors, each with 256 pad coordinates after 256 message coordinates, plus two 1024-entry M vectors; the IO profile adds six of those role vectors (A's two IO groups, each endpoint's group and proximity vector) | the Vandermonde / pad-budget argument over the new vectors. **Conditionally covered** by round 20 §1 |
| OBL-2 | sampled columns | 256 opened encoded columns per role commitment (1 024 P1 / 1 280 P3 per capture), each with a salt and an 11-node path, plus 256 M columns of 20 words and 12 nodes | the salted-leaf / pad hiding argument, now over the endpoints too. Round 20 §1 keeps every sampled **word** fixed but explicitly **not** the Merkle roots or paths |
| **OBL-3** | endpoint second encoding | **each aliased plane is encoded and column-opened twice** — once as A rows 14/15 resp. 16/17 and once as rows 0/1 of its endpoint — at independently drawn column sets (512 openings per plane), with independent masks and independent pads | **new with the IO seam; nothing in the linear model or in any earlier profile covers it.** Round 20 §1 applies its construction separately per owner, which is compatible, but does not by itself settle the two-encodings question at the hash layer |
| OBL-4 | CFS | one M commitment, 8 slots, 225 (P1) / 229 (P3) CFS mask coefficients, 14 public Fp2 functionals; **every slot is opened by exactly two functionals**, the IO slots 6 and 7 as the claimed sum γ and the sumcheck's mask evaluation | FA6's CFS argument extended to the two new slots and to the combined M opening. Round 20 §2 covers the M **opening** conditionally; the CFS **round messages** are explicitly outside it |
| OBL-5 | nonlinear rounds | 20 masked IO sumcheck rounds (degree 2, three coefficients each) and 56 (P1) / 58 (P3) masked FFN rounds, plus their terminals | the masked-round-message argument; nonlinear in the witness, in no linear model |
| OBL-6 | repeats | four retained proofs, two per mode; **all four carry the same 32-byte policy context and the same (−3, 0) scale pair, while every commitment root differs** — one SeamSpec, fresh randomness per proof | FA8's repeated-proof argument, now concrete: if the two proofs of a mode share a witness their observation sets compose. Round 20 excludes repeated openings and its negatives show why |
| OBL-7 | adaptive composition | every λ, ρ, τ, e and θ here is drawn after masked messages are absorbed | the transcript/simulator argument. Neither this result nor round 20 treats witness-dependent challenges as fixed independent inputs |
| OBL-8 | side information | X and z16 are scaled integer planes with public scales (−3, 0) and a public 32-byte context in the policy | range / small-domain side information is outside a linear disclosure model entirely |
| OBL-9 | identity | the policy binds two roots for one proof; weights are fresh per proof | registered private-model identity and scale authorization remain open |
| **OBL-10** | conditional progress | round 20's opening lemma covers the pad / encoded-column / M-opening channel **conditionally** and consumes §3's joint result as its premise | compose the joint message result with the CFS round-message channel and the opening lemma **under the actual adaptive transcript**; recheck the FA8 simulator hypotheses for `/2` (refusal, randomness allocation, single-opening owner lifecycle); specify the endpoint preparation / auxiliary-input model for the **caller-fixed** endpoint roots. Not accepted here |

---

## 5. Controls (checklist item 5)

**Positive control, archived legacy disclosure — retained and still
reproducing.** Fable's archived tool, run unchanged on the ten round-11
schema-1 captures, still reports **A = 2n + 4 = 516**, **P3 W = 2n + 2 = 514**,
**H = 2**, and still fully recovers the T32 `Wd` plane. This adapter refuses
every one of those captures, and refuses a legacy capture wearing a complete
schema-3 IO label — by the layout recomputation, not by the label.

**Positive control, analysis side.** The endpoint mask-pair ablation (§3.4):
256 disclosed dimensions with a single base mask row, 0 with the pair.

**Negative controls, 30 per mode**, applied to a real accepted P1 and a real
accepted P3 capture, with the unmodified capture accepted before and after the
battery. Every one is rejected, each by the recomputation:

| dispatch requirement | controls |
| --- | --- |
| a missing IO group or mask row | `missing_IO_group` (drop the last group; drop both), `missing_IO_mask_row` (A claim 18 with two parts; A at 698 or 700 rows; the endpoint claim with two parts; a 6-row endpoint) |
| incorrect endpoint aliases | `incorrect_endpoint_alias_A_side` (A's IO claim pointed at the other plane, or at offset 0), `incorrect_endpoint_alias_endpoint_side` (endpoint claim at offset 512, or `log_size` 8), a mismatched evaluation point, a swapped IO terminal, `zero_terminal_mask_challenge` |
| a changed role order | `changed_role_order`, `missing_output_endpoint`, a duplicated role, `changed_opening_order` |
| an altered source or profile | `altered_source` (zeros; a short hash), `altered_profile` (the superseded `/1`), `legacy_schema`, `legacy_coverage`, `relabelled_transcript_domain`, `legacy_digest_encoding`, `privacy_acceptance_claim` |
| narrowed M columns | `narrowed_M_columns` (16-word columns), `missing_M_IO_slots`, a wrong slot spec, `missing_M_functional`, an empty weight vector, an out-of-domain column index, a short proximity rho list |
| malformed fields | a non-canonical word (`P`), a negative word, a boolean coordinate, a short group vector, a short proximity vector, a short policy, a wrong policy digest, a wrong modulus, duplicate JSON keys, floats, `NaN`, a non-object top level, truncated JSON |
| (additional) | `endpoint_mask_row_relabelled_as_data`, `broken_group_terminal_equation`, `broken_transcript_join`, `wrong_io_slot`, a wrong `proof_bytes`, a P3 frame length on a P1 capture, a missing sibling receipt or policy |

Every result in the record is bound to the capture sha256, the receipt sha256
and length, the policy sha256, the source pin and the tool digests, with the
commands and exit codes listed above.

---

## 6. Findings for Codex

* **F1 (labelling).** The `layout_description` whose sha256 *is* the
  `layout_digest` still begins `ffn-v3-mr1-fresh-poc/1` — the superseded base
  profile string — because `ZkLayoutV3::describe()` hard-codes it. Not a
  soundness issue (`profile`, `transcript_domain` and `coverage` are separate
  checked fields, and the geometry differs), but a layout digest alone cannot
  distinguish the IO profile from the base one. Suggest emitting the active
  profile string.
* **F2 (CFS).** Each IO slot's mask polynomial (22 coefficients, spec `(10, 2)`)
  is opened by **two** public functionals — γ at f10/f12 and the sumcheck mask
  evaluation at f11/f13. This is the *same* two-openings-per-slot pattern the
  six FFN slots already have (`openings_per_slot` is 2 for all eight), so the
  obligation is FA6's existing argument extended to two more slots inside one
  shared M, not a new shape. Round 20 §2 covers the M opening but explicitly not
  the CFS round messages.
* **F3 (the one genuinely new leak surface).** Each aliased plane is committed,
  encoded and column-opened **twice**, with independent masks, pads and sampled
  column sets. This arrives with the IO seam, is outside every model in play,
  and is the item I would put first on the cryptographic queue (OBL-3).
* **F4 (repeats, now concrete).** All four retained proofs share one policy
  context and one scale pair, i.e. one SeamSpec, while every root differs. The
  retained set is therefore very likely four proofs of one witness per mode.
  Each is analysed alone here; composing them is the excluded `repeats` class.
* **F5 (not a gap — recorded so it is not mistaken for one).** The capture
  records **18** proximity rhos for a **20**-row M commitment. That is correct:
  `zk.rs::mask_verify` draws `2·slots + 2 = 18` rhos and uses rows 18/19 as the
  fixed `(1, u)` proximity mask pair.
* **F6 (stale label in my own O7 helper).** `zk60_opus_io_layout.endpoint_plane`
  still reports `unused_random_rows: [6]`. Round 19 corrected that; row 6 carries
  a proximity coefficient in every capture. I have not edited the file because
  its digest is recorded in the round-19 manifest and in Codex's preflight —
  flagging it for whenever it is next touched.
* **No unexpected disclosure.** Every derived number is 0 except H's 2, and that
  2 is identified as the public LogUp identity by an explicit test, not assumed.

---

## 7. Limits

* A linear-model rank result on four proof-of-concept captures, under the
  captured (fixed) public coefficients. Not a simulator, not a conditioning
  argument, not an upper bound on disclosure.
* The joint result **imports** the A ↔ endpoint plane equality from the
  soundness of the IO sumcheck; the linear observations do not establish it.
  The unaliased union is reported as a control.
* Excluded by construction: pad coordinates, sampled encoded columns, the CFS
  mask commitment and every masked sumcheck round message, repeated proofs of
  one witness, the Merkle root over unopened columns, and adaptive transcript
  composition. The capture contains these observations; containing them is not
  analysing them.
* Codex's round-20 opening lemma covers the pad / encoded-column / M-opening
  channel **conditionally** and consumes this result as its premise. Nothing
  here folds that channel into the model, and neither the adaptive composition
  nor the caller-fixed endpoint root simulation is accepted.
* This is **not** whole-protocol zero knowledge and **U-2 is not closed**. It
  covers only `ffn-v3-mr1-fresh-io-poc/2` at T32/d16/f16, function 1, fresh
  per-proof weights: no registered model identity, no function 2, no attention,
  no stable-weight profile, no transport envelope.
* The captures hold no witness values; nothing here is compared to a ground
  truth. No private-block, deployment or throughput acceptance follows.
