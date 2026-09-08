# CL10 — where the proof bytes actually are, before any redesign

Task: `zk60_claude_tasks.json` CL10 (`ready_analysis`). Owner: Claude.
Tool: `scripts/hashline_cl_artifact_profile.py` · tests:
`tests/test_hashline_cl_artifact_profile.py` (82, green: 27 at round 7 +
55 for CL19; 9 at round 6). Nothing in Codex's receipt/codec modules was
touched.

> **[ZK60-CL19, 2026-09-07.]** The size telemetry §7.5 proposed now EXISTS:
> Codex implemented `LayerProofZk::size_breakdown()` and a per-layer
> `HASHLINE_PROOF_SIZE` row in round 10 (uncommitted in the main checkout
> when read). §8 reviews it against the CL19 contract and reconciles the
> lane's derivation with Codex's ACTUAL rows at the frozen 12×512 fixture:
> layer 0 agrees on all 51 leaves, and the two layers that were 12,288 B
> larger differ on exactly two leaves. CL10's "unknown residual" is now
> derived (§8.5) and, where rows exist, counted.

> **[ZK60-CL10 round-7 CORRECTION, 2026-09-06.]** Codex's review
> (`ZK60_CL8_CL10_REVIEW.md`) found that the round-6 model gave W the same row
> count and the same salted framing in both privacy modes. It does not: P1's
> W is a plain `Opening` (10,752 rows, no salt), P3's is an `OpeningZk`
> (10,774 rows, 32 B salt per column). The round-6 numbers are left in place
> below, struck through where wrong, and the corrected accounting with its
> derivation and tests is **§7**. The headline (opened column data is ~89% of
> the artifact) survives; the "whole delta lands in the residual" claim, its
> cross-check, and the residual's label do not.

**Sizes are sizes.** Nothing below says a smaller alternative is compatible,
hiding, or sound. Every candidate in §4 carries the gate it would have to pass
first, and one of them is already disqualified for the private tier.

---

## 1. The measurement

One Mistral FFN layer, `d 4096 / f 14336`, T=512, `inv_rate` 4, 256 column
checks, encoded columns 65,536 (Merkle path 16). Committed rows: **W 10,752
under P1** (plain) **/ 10,774 under P3** (hiding: + 21 block masks + 1
proximity row), from the memory planner's mirror of `ZkLayoutV3::new`;
**A 3,601 / H 3,033** in both modes, declared from the binary's own mask-site
dump. Artifact sizes are the published, measured ones (lane AM rung 2, CL1
rung 4: `am_r2_mistral.log`).

### 1a. The round-6 table — SUPERSEDED, kept so the error stays visible

~~W 10,774 rows, salted, in both modes:~~

| component | P1 bytes | share | P3 bytes | share |
|---|---:|---:|---:|---:|
| ~~opened column DATA~~ | ~~35,651,584~~ | ~~88.7%~~ | 35,651,584 | 88.6% |
| ~~opened column framing (index, salt, path)~~ | ~~423,936~~ | ~~1.1%~~ | 423,936 | 1.1% |
| commitment headers + mask root | 164 | 0.000% | 164 | 0.000% |
| ~~residual: sumcheck arguments, claims, terms~~ | ~~4,110,544~~ | ~~10.2%~~ | ~~4,176,176~~ | ~~10.4%~~ |
| **observed artifact** | **40,186,228** | 100% | **40,251,860** | 100% |

The P1 column is wrong (W was given 22 rows and 8,192 B of salt it does not
have). The P3 column totals are right, but the "residual" row was mislabelled
in both modes: it held ~4.0 MB of clear group/proximity vectors and 174 KB of
mask opening — both of KNOWN shape — not "sumcheck arguments".

### 1b. The corrected table (round 7; derivation and tests in §7)

| component | P1 bytes | share | P3 bytes | share | P3 − P1 |
|---|---:|---:|---:|---:|---:|
| **opened column DATA** (field elements) | 35,606,528 | **88.60%** | 35,651,584 | **88.57%** | 45,056 |
| opened column framing (index, path; salt only where the opening type has one) | 415,744 | 1.03% | 423,936 | 1.05% | 8,192 |
| clear group + proximity vectors (W 3, A 6, H 6; Fp2) | 3,981,312 | 9.91% | 3,993,600 | 9.92% | 12,288 |
| mask opening (q', prox; 256 salted 16-row columns) | 174,080 | 0.43% | 174,080 | 0.43% | 0 |
| commitment headers + mask root | 164 | 0.0004% | 164 | 0.0004% | 0 |
| UNKNOWN residual: sumcheck rounds, claims/gammas, masked terminals | 8,400 | 0.02% | 8,496 | 0.02% | 96 |
| **observed artifact** | **40,186,228** | 100% | **40,251,860** | 100% | **65,632** |

Both reconcile **exactly**: derived + residual = observed, by construction. The
residual is obtained by subtraction; it is NOT a measurement of any one of
the parts it names, and its internal split is not claimed.

### ~~The cross-check that makes this credible~~ — it was an identity

~~The published P1 → P3 delta is +65,632 B. The opened-column term is
mode-independent, so the entire delta must land in the residual. It does, to
the byte: 4,176,176 − 4,110,544 = 65,632. A test pins this.~~ Codex is right
that this could not fail: `residual = observed − derived`, and with the SAME
derived total in both modes, `residual_P3 − residual_P1 = observed_P3 −
observed_P1` for any two artifacts, whatever the model says about them. The
test that pinned it now demonstrates exactly that on the round-6 model
(`test_why_the_old_cross_check_was_an_identity`). The replacement, which does
fail on the misallocation, is §7.3 item 3.

**Conclusion: ~89% of a proof is opened column field elements**, a further
~10% is the clear group/proximity vectors (Fp2 row combinations — argument
data too, not framing), framing is ~1%, and headers are four parts in a
million. That is a statement about BYTES; it says nothing about time (§5).

---

## 2. What this means for "make the proof smaller"

The proof is not carrying overhead worth trimming. It is carrying **opened
column data** (and, for a tenth, the clear row-combination vectors — round-7
correction), which is the Ligero-style argument itself. Concretely, the data
term is exactly

```
columns_opened  ×  committed_rows  ×  8 bytes
```

with `columns_opened = 256` fixed by the soundness parameter and
`committed_rows` fixed by the layout. Neither is framing, and neither can be
compressed away without changing what is proved or how strongly.

---

## 3. Byte-preserving improvements, ranked — and the ranking is short

"Byte-preserving" here means: the verifier accepts the same statement with the
same soundness, and the frozen digests do not move.

| # | candidate | ceiling | verdict |
|---|---|---:|---|
| 1 | per-column `u64` index → `u32` (65,536 encoded columns needs 16 bits) | 4 B × 256 × 3 = **3,072 B/layer**, 0.008% | real but negligible; **moves every digest**, so it is not byte-preserving in the frozen-artifact sense at all |
| 2 | deduplicate Merkle paths across the three commitments | 0 — the three trees are distinct, paths are not shared | not available |
| 3 | drop the per-column salt (P3: 32 B × 256 × 3 = 24,576 B, 0.06%; P1: × 2 = 16,384 B, 0.04%, because P1's plain W opening has none — round-7 correction) | 0.04-0.06% | **NO**: the salts are the hiding construction. Removing them is a privacy change, not a serialization one |
| 4 | compress the non-column ~10% with a general-purpose codec (round-7 correction: that tenth is the clear group/proximity vectors, 3.98-3.99 MB of Fp2, plus a 174 KB mask opening and ~8 KB of sumcheck rounds/terminals — not "arguments" as the old label said) | unknown, likely nil — folded row combinations over a 64-bit field are near-uniform bytes | must be measured before it is claimed; near-uniform data does not compress |

**Honest total for byte-preserving work: under 0.1%, and the only candidate
that reaches even that moves the frozen digests.** There is no serialization
SIZE win here (time is a separate question, §5). Anyone hoping to shrink
these artifacts must change the protocol, which is §4.

---

## 4. Protocol-changing candidates, each with the gate it must pass

These are **costed, not recommended**. None may be called compatible, private
or sound on the strength of a size number.

**(a) Open fewer columns.** The data term is linear in `columns_opened`, so
this is the only lever with real leverage inside the current PCS. It trades
directly against soundness: 256 checks is the current parameter.
**Gate: an explicit soundness re-derivation and a review ruling on the target
security level.** Not a serialization change.

**(b) The compact (BaseFold-class) PCS, already measured by lane AF.** A
Mistral layer's proof **38.7 → 1.94 MB (19.9x)** at 4.4x prover; 8B modelled
`1.23 GB → ~62 MB` [COUNTED]. That is the only order-of-magnitude candidate on
the table, and it is **currently disqualified for the private tier on three
independent counts**:
- **Soundness is LOWER**: 2^-98.2 / 2^-95.1 against Ligero's 2^-106, and it is
  a *field-size* term, so it is **not fixable by adding queries**. A ruling is
  pending and has not been made.
- **It is not hiding**: `--pcs compact --zk` is refused by the code today. So
  it cannot serve P1 or P3 as things stand.
- **It is not device-resident** (slower on GPU), which cuts against everything
  CL1 just established about getting the private tier onto the device.
**Gate: its own codec gates, a soundness ruling, and a hiding construction that
does not exist yet.** Until all three, it is a fast-tier-only, ruling-pending
option and must not be quoted as a proof-size roadmap for the private product.

**(c) Pack field elements below 8 bytes.** Goldilocks elements are ~64 bits and
the opened columns are masked, so they are near-uniform over the field. There
is no headroom. **Gate: none needed — this one is simply not available**, and
recording that is more useful than leaving it as an open idea.

---

## 5. Transfer and allocation assumptions, stated separately

CL10 asks that disk/network assumptions not be folded into the byte count:
- The measured artifact is what `--proof-out` writes: the **concatenated layer
  proofs, flat LE**, with no container, no compression and no framing beyond
  the per-layer structure above.
- A 32-layer 8B proof is ~1.23 GB by the same arithmetic. Any statement about
  transferring that is a deployment question, not a proof-size one, and none is
  made here.
- Output-buffer allocation: `to_bytes` reserves `size_bytes()` up front, so the
  serialization is a single allocation of the final size, not a growing buffer.
  That is a statement about the code's shape, not about its time.
- **Bytes are not time (round-7 correction, in place).** This bullet used to
  end: ~~"Serialization time was measured at 0.03-0.07 s and runs outside the
  prove clock (round-14 correction). It is not a bottleneck and should not be
  presented as one."~~ The 0.03-0.07 s is the round-14 ledger's measurement,
  taken outside the prove clock; nothing in THIS document measures serializer,
  transfer or allocation time, and a size partition cannot show that a
  serializer has no runtime headroom — a 40 MB write can be slow for reasons
  that have nothing to do with how the 40 MB splits. Serializer/transfer
  time is CL5's collectors' to measure; this document makes no claim about
  it either way.

---

## 6. Handoff to Codex's codec/CLI owners

- The tool profiles a **declared** layout against a **measured** artifact size.
  It refuses unknown or underspecified layouts, and refuses any model whose
  derived components exceed the observed artifact — that condition means the
  model has drifted from `zk.rs` and every number would be fiction.
- To add a layout: read its serializer, declare its commitments' rows/columns/
  path lengths in `KNOWN_LAYOUTS`, and add its measured artifact size to the
  tests. Do not infer a layout from a file.
- **The actionable finding for a codec owner is that there is nothing for a
  codec to do about SIZE.** ~99% of the artifact is field elements (89% opened
  columns, 10% clear vectors) that are near-uniform bytes. The lever is §4(a)
  or a different PCS with its own gates, not encoding. Whether the
  serializer's TIME has headroom is a different question this document does
  not answer (§5).
- If a per-component dump is ever wanted from the Rust side rather than derived
  here, `LayerProofZk::size_bytes` already has the exact structure and a
  `debug_assert_eq!` tying it to `to_bytes`; exposing it would need a change in
  `zk.rs`, which is **read-only to this lane** and is therefore proposed, not
  made (the concrete proposal is §7.5).

---

## 7. Round-7 review response (Codex, 2026-09-06)

Review: `ZK60_CL8_CL10_REVIEW.md`, "CL10: P1 and P3 column costs differ".
Recorded counts: `results/zk60_round7_claude_review.json` →
`cl10_rust_layout_counts` (plain_w_rows 10,752 / private_w_rows 10,774 /
w_mask_rows 22 / w_cols 16,384, obtained through `ZkLayoutV3::new` on
metadata only) and `cl10_p1_p3_attribution`. Every number below is
reproduced by

```
python3 -m unittest discover -s tests -p 'test_hashline_cl_artifact_profile.py'   # 27 tests
python3 scripts/hashline_cl_artifact_profile.py --layout mistral-v3-layer-P1 --observed-bytes 40186228 \
    --against-layout mistral-v3-layer-P3 --against-observed-bytes 40251860
```

No proof was generated for this correction; it is a serializer/layout count
correction against the two archived artifacts, exactly as the review scoped
it.

### 7.1 What was wrong, in the source's own words

| the source says | the round-6 model assumed |
|---|---|
| `LayerProofZk` carries BOTH `w_open: Opening` and `w_open_zk: OpeningZk`; the prover fills one per mode and the other serializes to 0 B (`zk.rs:859-863`, `:3258-3266`) | one salted W opening, in both modes |
| `Opening::size_bytes` = vectors + Σ(8 + rows·8 + path·32), **no salt** (`pcs.rs:94-99`); `OpeningZk::size_bytes` adds 32 B per column (`pcs.rs:543-548`) | 32 B salt on every column of every commitment |
| P1's W has `LayoutV3.w_len / n` = 3·d·f/n = **10,752** rows; P3's has `ZkLayoutV3.w_len_p3 / n` = 10,752 + 3·nb_d·nb_f block-mask rows (21) + 1 proximity row = **10,774** (`zk.rs:2136-2143`; the verifier demands exactly this per mode, `zk.rs:3511`) | 10,774 in both modes |
| `Opening` vectors are n = 16,384 Fp2 long (`pcs.rs:405-421`); `OpeningZk` vectors are n + Q = 16,640 (`pcs.rs:957-970`). W forms 2 column-weight groups (all Wg/Wu claims at p3, all Wd claims at p6; `group_claims` keys on the point's column part, `pcs.rs:237-252`), A and H 5 each (the dump's "group vector 0..4" lines); one proximity vector each | vectors not counted at all; their ~4 MB sat inside a residual labelled "sumcheck arguments" |
| `MaskOpening` = 1,024 + 1,024 Fp2 (q', prox) + 256 salted columns of the (2·6+4)-row mask commitment on a 4,096-point coset, path 12 (`zk.rs:466-468`, `:523-560`, `:605-642`) | not counted; inside the residual |
| P3 adds one degree-2 round to each matmul sumcheck, 3 Fp2 each (`mask_specs_v3`, `zk.rs:2210-2221`; `SumcheckProof` writes degree+1 Fp2 per round, `sumcheck.rs:23-25`) | — (the one P3 cost this model still leaves in the residual; now PREDICTED, 7.2) |

### 7.2 The corrected attribution

The per-mode table is §1b. The delta column, component by component:

| P3 − P1 | bytes | derived from |
|---|---:|---|
| 22 extra W rows × 256 opened columns × 8 B | 45,056 | `w_shape(hiding=True)` − `w_shape(hiding=False)` |
| a 32 B salt on each of W's 256 opened columns | 8,192 | `OpeningZk` vs `Opening` |
| Q = 256 pad entries × 16 B on each of W's 3 clear vectors | 12,288 | `OpeningZk` vectors are n + Q long |
| mask opening; headers | 0 | mode-independent shapes |
| **explained by modelled components** | **65,536** | |
| residual delta: two extra degree-2 sumcheck rounds | 96 | `p3_extension_round_bytes()` = 2 × 3 × 16 |
| **observed** | **65,632** | `am_r2_mistral.log` |

Codex's 12,384 B "outside the columns" is 12,288 B of vector pads plus 96 B
of sumcheck rounds. The whole observed delta is accounted for from the
source with nothing left over. Read that for what it is: a consistency check
of the model against ONE measured difference. It is not a measurement of any
residual part on its own, and it does not make the residual's split known.

### 7.3 Finding → change → test

1. **Separate plain/hiding layouts with the actual W rows per mode; test
   against Rust counts, not constants pasted into model and test alike.**
   *Change:* `CommitmentOpening.hiding` selects the serializer (salt or none;
   n or n+Q vectors). `w_shape(d, f, log_cols, hiding)` derives W's rows by
   importing `weight_shape` from `scripts/hashline_memory_plan.py` — the
   planner's mirror of `ZkLayoutV3::new`, tested there against the same
   counts — so the profile contains no W row constant. `mistral_v3_layer("P1")`
   declares W plain, `("P3")` hiding; A and H stay declared from the dump
   (the review kept them as handoff inputs and so does this).
   *Tests:* `RustMirror.test_w_rows_match_the_recorded_rust_layout_counts`
   (reads `cl10_rust_layout_counts` from Codex's JSON when present, else the
   review's published values); `test_w_rows_match_the_archived_prover_dump`
   (parses the binary's own "W masks (P3): commitment 10774 rows of 2^14 =
   10752 data + 21 block masks + 1 prox row" line and both proof sizes from
   `am_r2_mistral.log`; skipped where the archive is not mounted);
   `test_the_mirror_is_the_planners_rule_not_a_pasted_constant` (three shapes,
   including frugal-lm's 768→2048: 288 plain / 298 hiding);
   `test_the_declared_layouts_use_those_rows_per_mode`;
   `ReviewTable.test_column_components_match_the_corrected_table` (all six
   cells and the three deltas of the review's table);
   `test_the_residual_delta_after_columns_is_12384_not_65632`.
2. **Count group/proximity vectors explicitly when their shapes are known;
   otherwise label them part of the unknown residual.**
   *Change:* vectors are a component when a commitment declares `groups`
   (W 2, A 5, H 5, + 1 proximity each; length from the opening type); the
   mask opening is a component with its shape from the `zk.rs` constants.
   When either is undeclared, the profile's `residual_note` begins "UNKNOWN
   residual:" and names what it holds. The residual is never called a
   measurement of arguments; the old `residual_arguments` share is gone.
   *Tests:* `Vectors.test_vector_lengths_follow_the_opening_type`,
   `test_mistral_vectors_are_counted_and_are_a_tenth_of_the_artifact`,
   `test_undeclared_vectors_are_named_in_the_residual_not_silently_zero`,
   `test_the_residual_is_never_called_a_measurement_of_arguments`;
   `Components.test_mask_opening_shape_follows_the_zk_constants`.
3. **Replace the identity cross-check with one that can fail.**
   *Change:* `mode_delta(p1, p3)` differences every component and the two
   OBSERVED sizes separately; the test asserts each component delta against
   its source-derived value and the residual delta against the single
   un-modelled P3 cost (96 B). Two negative controls: on the round-6 model
   (same W both modes, vectors and mask opening uncounted) the same check
   reports a 65,632 B residual delta and fails; and under the corrected
   accounting the round-6 misallocation does not even FIT the P1 artifact —
   `profile` refuses it (derived exceeds observed by 57,136 B), because the
   ~4.1 MB of slack that let it pass was the uncounted vectors. Each mode is
   also reconciled INDEPENDENTLY against its own artifact with the residual
   bounded below 10,000 B: one mis-assigned W row is 2,048 B and a salt
   block is 8,192 B, both visible against that bound.
   *Tests:* `ModeCrossCheck.test_the_observed_delta_is_explained_component_by_component`,
   `test_the_cross_check_rejects_the_round_6_misallocation`,
   `test_the_corrected_accounting_cannot_even_fit_the_misallocation`,
   `test_why_the_old_cross_check_was_an_identity` (the old assertion holds
   on the wrong model for every observed pair tried);
   `Reconciliation.test_each_mode_reconciles_independently_with_a_bounded_residual`;
   `Refusals.test_the_p3_model_does_not_fit_the_p1_artifact`.
4. **Keep byte accounting apart from serialization/transfer/allocation
   time.** *Change:* §3, §5 and §6 corrected in place (the "not a bottleneck"
   sentence is struck, not deleted); every profile carries a `bytes_not_time`
   field; the module docstring states that a size partition cannot show a
   serializer has no runtime headroom. No timing claim is made anywhere in
   this document now. *Test:* `Components.test_profile_output_keeps_bytes_and_time_apart`.

### 7.4 What remains unknown or unmeasured

- **The residual's split** (8,400 B P1 / 8,496 B P3): sumcheck rounds, the
  seven claims/gammas, the masked terminals. Modelling them needs the
  terminal lengths from the prover; not done, and the residual is labelled
  accordingly. The 96 B delta is predicted from `mask_specs_v3`, not
  measured in isolation.
- **A and H** rows (3,601 / 3,033) and group counts (5 / 5) are DECLARED from
  the prover's dump, not mirrored in Python; the planner mirrors only W.
- **The mask opening** (174,080 B) is derived from the `zk.rs` constants and
  the six-entry `mask_specs_v3` of function 1; mode-independent; not
  separately measured.
- **P1's W group count** (2) is read from the claim structure; the P1 log
  prints no W group lines because W is not masked under P1.
- **Time:** nothing. No serializer, transfer or allocation timing is claimed
  here; CL5's collectors own that.
- **Scope:** one Mistral FFN layer, function 1, two archived artifacts. No
  new proof was generated.

### 7.5 Proposed Rust helper (proposal only — `zk.rs` is read-only to this lane)

> **[CL19 update, 2026-09-07]** Implemented by Codex in round 10 as
> `LayerProofZk::size_breakdown()` (`hashline/src/zk_proof_size.rs`) plus the
> `HASHLINE_PROOF_SIZE` row, printed per layer under `--phase-profile` rather
> than `HL_TIMING=1`; typed categories instead of a `Vec<(&str, usize)>`.
> Review and reconciliation in §8. The proposal below is kept as written.

`LayerProofZk::size_breakdown(&self) -> Vec<(&'static str, usize)>` beside
`size_bytes`: the per-field byte counts in write order (three headers and the
mask root; each claim, sumcheck and terminal; `mask_open` split into
vectors/columns; `w_open`, `w_open_zk`, `a_open`, `h_open` each split into
vectors/columns), with a `debug_assert_eq!` that the parts sum to
`size_bytes()`, printed alongside the mask-site dump when `HL_TIMING=1` or a
similar opt-in is set. It would replace every derived number in this
document with a printed one and turn the unknown residual into an exact
count — including the 96 B that is currently predicted rather than seen.
Codex's round-7 metadata helper through `ZkLayoutV3::new` already covers the
W row counts; this would cover the rest.

---

## 8. CL19 — the proof-size telemetry: review of Codex's implementation, and the lane consumer

Task: `zk60_fable_tasks.json` CL19 (queued as `ready_design`, re-scoped
2026-09-07 12:22 PDT when Codex reported it had implemented the producer
side). **Status: producer implemented by Codex in round 10 and validated
there (marker 0, 12:25 PDT), still UNCOMMITTED in the main checkout at
`52a13d1`'s tree when this section was written; lane consumer ready (this
tool, 55 new tests); lane reconciliation DONE against Codex's actual rows at
the frozen 12×512 zkv3 fixture (P1, 12 layers) and the T16 P3/P1 cases —
against uncommitted evidence, so repo-archived rows are still pending.**
Nothing in this section is a Codex-owned edit; the lane read, consumed and
reviewed.

### 8.1 What was read, and that it was uncommitted

All from `/home/victor/IntelligenceRegulation` (Codex's main checkout), read
2026-09-07 12:25-12:40 PDT, all showing as `??` or ` M` in `git status`
against `52a13d1`; sha256 of each file as read:

| file | state | sha256 |
|---|---|---|
| `hashline/src/zk_proof_size.rs` (new module: `ColumnBytes`, `OpeningBytes`, `MaskOpeningBytes`, `ArgumentBytes`, `ProofSizeBreakdown`, `LayerProofZk::size_breakdown()`, `to_json()`) | untracked | `a7598d0a..8c04fcf` |
| `hashline/tests/zk60_proof_size.rs` (5 tests) | untracked | `c5b6409b..682be7d` |
| `hashline/src/zk.rs` (`#[path] mod proof_size; pub use ...` after `LayerProofZk`; two `tests_v3` tests extended) | modified | `1f04986c..cff20de3` |
| `hashline/src/bin/hashline.rs` (the `HASHLINE_PROOF_SIZE` row in `pass_zk_v3`, after `wcache::report()`, under `o.phase_profile`) | modified | `2809dff2..dd59484e` |
| `docs/zkmatrix-poc/ZK60_ROUND10.md` (Codex's record) | untracked | re-read after its validation section landed |
| `results/zk60_round10_validation.json` (`frozen_size_rows` ×12, `cli_checks[*].size_rows`, hashes, commands) | untracked | `32390305..5dd273` |
| `/tmp/zk60-round10/{frozen_zkv3,p3_profile,p1_unverified,p3_default}.log` (the actual prover logs; ephemeral) | — | `ceb0d4bc..`, `9e94be99..`, `00eda09b..`, (not hashed) |

The diffs were obtained with `git -C <main> --no-pager diff hashline/src/zk.rs
hashline/src/bin/hashline.rs`. No binary was built or run from the main
checkout by this lane; Codex's validation ran detached under the heavy lock
and had finished (`validation.done` = 0) before any of its logs were read.

### 8.2 What Codex built (from the source, not the record)

- `LayerProofZk::size_breakdown(&self) -> Result<ProofSizeBreakdown, &'static str>`
  refuses a proof missing any of the three commitments (as `to_bytes` would
  panic) and otherwise counts, per field, the length the writer would write:
  `commitment_headers` = `3 * (32 + 8 + 4)`, `mask_root` = 32, six
  `ArgumentBytes` {`claim_or_challenge` 16, `round_evaluations` =
  Σ `rounds[j].len() * 16`, `terminals` = `term.len() * 16`} for gu / d /
  zc20 / zc17 / zs / table, `mask_opening` {`functional_vector` = `q.len()*16`,
  `proximity_vector`, `columns`}, `w_plain` (from `w_open: Opening`, salts
  fixed 0), `w_hiding` (from `w_open_zk: OpeningZk`), `a`, `h`, and
  `predicate` (`Option`, null under function 1). `ColumnBytes` splits every
  opening into `indices` (8 B each), `values` (`col.len() * 8`), `salts`
  (`columns.len() * 32` for the salted tuple), `authentication_paths`
  (`path.len() * 32`).
- It reads `.len()` only. **No second byte buffer is allocated**, no field
  value is read, and nothing in `to_bytes`/`write_bytes` changed (Codex's
  `unchanged_serialization.json` records the `LayerProofZk` layout and
  serializer regions source-identical to baseline).
- CLI: one row per actual layer, `HASHLINE_PROOF_SIZE {"schema":1,"unit":
  "bytes","coverage":"ffn-only","profile":"v3","privacy":"P1|P3","layer":N,
  "serialized":true,"pass_verified":<o.verify && ok>,"sizes":{to_json()}}`,
  printed after `report_timing` and `wcache::report()`, only under
  `--phase-profile` (which is `--profile v3`-only, **CPU-only** — refused
  under `HL_GPU=1` — and prints the PRIVATE TIMING DIAGNOSTICS warning).
  `privacy` is the CLI's mode (`o.zk.p3()`), not read from the proof.

### 8.3 Review against the CL19 contract

| contract item | verdict | evidence (Codex's tests are in `hashline/tests/zk60_proof_size.rs` unless noted) |
|---|---|---|
| sections sum exactly to `to_bytes().len()` | **met** | `complete_empty_fields_count_fixed_headers_and_scalar_arguments` (276 B skeleton), `ragged_openings_count_actual_columns_and_preserve_plain_vs_salted_framing`, `all_argument_families_and_optional_predicate_match_their_writers`; in `zk.rs tests_v3`: the fresh-randomness test asserts `sizes.total_bytes() == to_bytes().len()` for real P1 and P3 proofs and that fresh randomness leaves the breakdown unchanged; the function-2 test asserts it with a predicate |
| every byte in exactly one section (no omission, no double count) | **met, per section** | each opening and the mask opening is compared to the length of ITS OWN `write_bytes` output, each argument to `16 + sc.write_bytes + terms*16`, the predicate to `pred.write_bytes`, and the whole to `to_bytes().len()` — so an omission in one section cannot be cancelled by a double count in another. Within a section, leaves are pinned for `w_plain` (all four), `w_hiding.columns.salts`, `mask_opening.functional_vector`/`.salts`; `a`/`h` leaves are not pinned individually but share `OpeningBytes::hiding` with `w_hiding`. The lane validator adds `salts == opened columns × 32` and `indices ≡ 0 mod 8` per opening |
| P1 W no salts / P3 W salts | **met** | `zk.rs tests_v3` per mode: P1 → `w_plain > 0`, `w_plain.columns.salts == 0`, `w_hiding == 0`; P3 → `w_plain == 0`, `w_hiding.columns.salts > 0`. Actual rows: frozen P1 layer 0 has `w_plain.columns.salts 0`, `w_hiding` all zero; T16 P3 has `w_plain` all zero, `w_hiding.columns.salts 8192` |
| predicate counted separately | **met** | `all_argument_families...` (+`extra.len()` exactly); `zk.rs` function-2 test |
| counted without a second complete proof | **met** | `size_breakdown` uses `.len()` arithmetic only; the `Vec::new()` buffers in the Rust tests are test-side oracles; `ragged_openings...` asserts `proof.to_bytes() == before` after counting |
| `pass_verified` explicit | **met** | `o.verify && ok`; Codex's `p1_unverified` case (`--no-verify`) prints `pass_verified:false`; the lane validator keeps such a row as a diagnostic and marks it `rankable: false` |
| tamper: a changed section length moves only its own counter | **met** | `independent_section_mutations_cannot_hide_in_a_residual`: +1 Fp in a W column → only `w_plain.columns.values` +8; +1 path digest in A → only `a.columns.authentication_paths` +32 |
| proof bytes unchanged | **met (validated)** | frozen `zkv3` reproduced at `40eb5479..` / 87,697,008 B WITH `--phase-profile`; P3 T16 proof files byte-identical with profiling off/on (`p3_default` vs `p3_profile`: `8d9c66c3..`, 3,432,468 B); all four frozen CPU artifacts unmoved (`frozen_cpu`) |
| categories are not contiguous offsets | **stated, correct** | inside an opening each column's index, values, salt and path are written before the next column's, so `salts` is not an interval; an interval-cover test is therefore not possible and a partition test is the right check. The lane validator checks the partition, not offsets |
| framing "lengths, tags, versions" | **n/a — the format has none** | `LayerProofZk` is a flat LE concatenation with no length prefix, tag or version; there is no byte decoder for it (the verifier takes the struct). The only framing is 132 B of headers, the 32 B mask root and one u64 index per opened column; Merkle paths are authentication data, salts are the hiding construction. Schema 1 names each separately |

**Independence, stated exactly.** `size_breakdown()` walks the same struct
fields the writer walks, so it is not a third-party parser; what makes it a
measurement rather than a formula is that every section is checked against
the writer's OUTPUT length. In release builds `to_bytes`'s
`debug_assert_eq!(out.len(), self.size_bytes())` is compiled out, so the
production guarantees are the CLI's `assert_eq!(all.len(), bytes)` on the
whole file (`hashline.rs:1345`) and, now, the row. On every archived fixture
FOUR counts agree to the byte: (i) `size_bytes()` (the `layer N: ... B`
line), (ii) `size_breakdown().total_bytes()` (the row), (iii) `all.len()`
(the `PROOF sha256 ... (N B)` line), (iv) the lane's derivation from the
layout rules (§8.5).

### 8.4 Findings for Codex (suggestions, none blocking)

1. `w_plain.columns.salts` is a constant 0 written by `OpeningBytes::plain`,
   not a count — a schema placeholder so both W variants share one shape. The
   consumer refuses a nonzero value there; the doc string could say so.
2. `privacy` comes from the CLI, not the proof; the consumer cross-checks it
   (P1 ⇒ `w_hiding` empty and `w_plain` non-empty; P3 the reverse with
   salts). A row that lies about its mode is refused.
3. Schema 1 has no nested per-category totals (only `total_bytes`); the
   consumer derives them. If a later schema adds `total_bytes` inside a
   category, the consumer already checks it against that category's leaves.
4. The row is gated on `--phase-profile`, which is CPU-only and carries the
   private-timing warning although the size row reveals only shape counts the
   mask-site dump already prints. A GPU gate log (CL17) therefore cannot carry
   rows today. A separate opt-in (e.g. `--proof-size`) or printing the row
   whenever `--proof-out` is given would let the frozen GPU gates archive
   rows. Suggestion only; the current gating is correct and conservative.
5. The actual rows exist only in `/tmp/zk60-round10/*.log` (ephemeral) and in
   the untracked `results/zk60_round10_validation.json`. Committing that JSON
   archives them; the lane pins one row verbatim in its tests (§8.6) and
   skips the others where the files are absent.
6. Unmeasured cases: **P3 at 12×512** (only the T16 P3 layer was run; the
   lane derives 7,347,092 B for layer 0, matching the archived
   `layer 0: ... 7347092 B` line of `cl5_r7/p3.1.log`, but no row);
   **Mistral** (no row; the export is not on this box); **function 2** (the
   derivation predicts the predicate at 1,200 B in its own category PLUS
   4,096 B in `mask_opening.columns.values`, because `mask_specs_v3` gains a
   seventh sumcheck and the mask commitment 2 rows — 18, not 16 — on each of
   the 256 opened mask columns; unmeasured).

### 8.5 The lane mirror now derives every category — and the actual rows agree

CL10 could only subtract: its "UNKNOWN residual" (8,400 / 8,496 B Mistral,
and by the same method 6,800 / 6,896 B at 12×512) held the sumcheck rounds,
claims and terminals. Those are now derived from the source too —
`mask_specs_v3` (zk.rs:2210-2221) for the (variables, degree) of each
sumcheck, `SumcheckProof::size_bytes` (degree+1 Fp2 per round), and the v3
verifier's terminal lengths (zk.rs:3549-3669: gu `nb_d + 2·nb_d·nb_f`, d
`nb_f + nb_f·nb_d`, zc20 `10·nb_f`, zc17 `4·nb_d`, zs 1, table `2 × 6`
slots), with `LayoutV3::new` (layer.rs:1284-1290) for log_t / log_db /
log_fb / nb_d / nb_f and `ZkLayoutV3::new` for log_n = min(log_cols, log_t +
min(log_db, log_fb)), log_s = max(log_n, 16), log_wn = min(log_cols, log_db +
log_fb). (The fixed-length terminals of the v2 verifier at zk.rs:1761-1854
are NOT the v3 rule — using them left Mistral 1,088 B short, exactly the
68 extra terminal Fp2 that nb_f = 7 produces.) With that, all four archived
per-layer sizes reproduce with **zero residual**: Mistral 40,186,228 /
40,251,860; 12×512 layer 0 7,306,036 / 7,347,092.

Then the actual rows. `python3 scripts/hashline_cl_artifact_profile.py
--from-log /tmp/zk60-round10/frozen_zkv3.log --reconcile auto` (the fixture
declared from the log's own header, `layout:` and `claims in N groups`
lines):

- all 12 rows validate; each row's `total_bytes` equals its `layer N: ... B`
  line; the rows sum to the PROOF line's **87,697,008 B** (`40eb5479..`) and
  to `HASHLINE_TIMING.proof_bytes`; all `pass_verified: true`.
- **layers 0 and 3-11: derived == measured on all 51 leaves.**
- **layers 1 and 2** (7,318,324 B, +12,288): differ from the layer-0
  derivation on exactly two leaves — `a.columns.values` +4,096 (2 rows × 256
  columns × 8 B) and `h.columns.values` +8,192 (4 rows). That is the whole
  12,288 B the layer-0 dump could never attribute (CL10 §7.4 "every layer
  identical in structure up to its window sizes"): consistent with one table
  slot spanning 2 rows instead of 1 in those layers (m + mask rows in A,
  re/im/mre/mim in H), but the row is the authority and no dump is printed
  for those layers — this is precisely what measured rows are for.
- T16 P3 (`p3_profile.log`, 1 layer × 16 tokens, A 134 / H 167 rows at
  n = 2^12 while W stays at 2^14): 3,432,468 B, derived == measured on every
  leaf — the separated log_n / log_wn rule was necessary here. T16 P1 with
  `--no-verify` (`p1_unverified.log`): 3,391,412 B, every leaf agrees,
  retained as a diagnostic, `rankable: false`. `p3_default.log` (no
  `--phase-profile`): no rows → the tool refuses and says the run predates
  the CLI or lacked the flag; it infers nothing from the size lines.

The frozen 12×512 layer 0 (P1), measured, with the derived P3 beside it:

| category | leaf | P1 measured (= derived) | P3 derived | P3 − P1 |
|---|---|---:|---:|---:|
| commitment_headers / mask_root | | 132 / 32 | 132 / 32 | 0 |
| arguments (6) | claim 16 each; rounds 432 / 576 / 1,680 / 1,440 / 720 / 1,088; terminals 144 / 64 / 160 / 192 / 16 / 192 | **6,800** | 6,896 | +96 (gu, d: one round each, 48 B) |
| mask_opening | functional 16,384; proximity 16,384; indices 2,048; values 32,768; salts 8,192; paths 98,304 | 174,080 | 174,080 | 0 |
| w_plain (P1) | groups 524,288; prox 262,144; indices 2,048; values 589,824; salts **0**; paths 131,072 | 1,509,376 | 0 | −1,509,376 |
| w_hiding (P3) | groups 532,480; prox 266,240; indices 2,048; values 610,304; salts **8,192**; paths 131,072 | 0 | 1,550,336 | +1,550,336 |
| a | groups 1,331,200; prox 266,240; indices 2,048; values 1,144,832; salts 8,192; paths 131,072 | 2,883,584 | 2,883,584 | 0 |
| h | groups 1,331,200; prox 266,240; indices 2,048; values 993,280; salts 8,192; paths 131,072 | 2,732,032 | 2,732,032 | 0 |
| predicate | null | 0 | 0 | 0 |
| **total** | | **7,306,036** | **7,347,092** | **+41,056** = 20,480 values (10 W mask rows) + 8,192 salts + 12,288 vector pads (Q on 3 vectors) + 96 rounds |

Mistral, derived only (no row): the same shape of delta, 65,632 = 45,056
(22 W rows) + 8,192 + 12,288 + 96 — CL10 §7.2's numbers, now leaf by leaf.

**What the measured row says about this shape.** At 12×512 the clear
group/proximity vectors are 4,014,080 B = **54.9%** of the layer, opened
column values 2,760,704 B = 37.8%, Merkle paths 491,520 B = 6.7%, salts
24,576 B = 0.34%, column indices 8,192 B = 0.11%, arguments 6,800 B = 0.09%,
headers + root 164 B. CL10's "89% column data" is a Mistral-shape statement
(rows 10,752 / 3,601 / 3,033 against n = 16,384); at 12×512 (rows 288 / 559 /
485 against the same n) the vectors dominate because they scale with n ×
groups while values scale with rows. Both are sizes of near-uniform field
elements; neither says anything about compressibility, and nothing here
promotes compression, mask removal or fewer column checks as compatible —
those remain protocol changes with their own gates (§4).

### 8.6 The lane consumer (`scripts/hashline_cl_artifact_profile.py`, 82 tests)

- `--schema`: the schema-1 section list — 51 leaf paths, each with its
  meaning, the Rust field that supplies it, P1/P3 applicability, producer and
  consumer ownership, status. Key names are copied from `to_json()` and a
  test checks every one against `zk_proof_size.rs` when it is mounted.
- `--validate-breakdown PATH` (a row object, a list, or any text with
  `HASHLINE_PROOF_SIZE` lines): refuses duplicate JSON keys (strict loader —
  plain `json.loads` keeps the last and loses a category), unknown or missing
  categories, duplicate / unknown / missing / out-of-order argument names,
  `claim_or_challenge ≠ 16`, headers ≠ 132, mask root ≠ 32, salts ≠ opened
  columns × 32 (0 for `w_plain`), indices not whole u64s, negative or
  non-integer leaves, `serialized ≠ true`, a non-boolean `pass_verified`,
  a P1 row carrying `w_hiding` bytes or `w_plain` salts, a P3 row carrying
  `w_plain` bytes or no hiding-W salts, a predicate not named "predicate",
  and — the partition — leaves that do not sum exactly to `total_bytes`
  (reported with the signed discrepancy). Nested `total_bytes` inside a
  category is optional and checked when present. `pass_verified` is
  reported explicitly; a false row is kept and marked `rankable: false`.
- `--from-log PATH [--reconcile FIXTURE|auto]`: every row of a prover log,
  each pinned to its `layer N: ... B` line, the sum to the `PROOF sha256`
  line and to `HASHLINE_TIMING.proof_bytes`, one row per layer (duplicates
  and gaps refused), one privacy per run; a log without rows is refused with
  the reason, never inferred. `--reconcile auto` declares the fixture from
  the log's own dump lines (d/f/T/log_cols/inv_rate/checks, A/H rows, group
  counts; W groups from the P3 dump or the function-1 claim structure) and
  compares leaf by leaf; the dump covers layer 0, so other layers show
  exactly where they differ.
- `--derive FIXTURE --mode P1|P3`: the mirror's row for `mistral-v3-layer`
  or `zkv3-12x512-layer0`, flagged DERIVED, with `derived_equals_archived`.
- The CL10 interface (`--layout/--observed-bytes[/--against-*]`) is unchanged
  and its 27 tests still pass; CL10's residual is now shown equal to the
  derived arguments (`test_cl10s_unknown_residual_is_exactly_the_derived_arguments`).
- Tests (55 new): schema (6), positive rows including the verbatim actual
  layer-0 row and the predicate case (6), one refusal per rule (22), mirror
  (8), log rows (13). Six of the 55 are skip-guarded and run only where
  Codex's uncommitted module and evidence or the lane's archived `cl5_r7`
  logs are mounted (all six ran here).

```
python3 -m unittest discover -s tests -p 'test_hashline_cl_artifact_profile.py'      # 82 tests
python3 scripts/hashline_cl_artifact_profile.py --schema
python3 scripts/hashline_cl_artifact_profile.py --derive zkv3-12x512-layer0 --mode P3
python3 scripts/hashline_cl_artifact_profile.py --from-log /tmp/zk60-round10/frozen_zkv3.log --reconcile auto
python3 scripts/hashline_cl_artifact_profile.py --from-log results/cl5_r7/p1cold.1.log   # refused: no rows (predates the CLI)
```

### 8.7 Time and copies, kept apart from bytes

The row is bytes. The clock the log calls `serialize_s` (0.091 s for
87.7 MB in `frozen_zkv3.log`, 2 threads, not a quiesced measurement and not
promoted) spans, in `pass_zk_v3` (`hashline.rs:1343-1354`): each layer's
`to_bytes()` into ITS OWN `Vec<u8>` (copy 1, sized by `size_bytes()` up
front), `extend_from_slice` into the whole-file `all` (copy 2), `sha256_hex`
over `all`, `fs::write` (copy 3, into the page cache) and two `println!`s.
`size_breakdown()` runs after `report_timing` and `wcache::report()`, so it
is inside neither `serialize_s` nor `proof_ready_s`, allocates only the
small `ProofSizeBreakdown` and its JSON string, and cannot perturb the
recorded clocks. A per-category byte count says nothing about which of
those copies or the hash dominates the 0.09 s; that is a separate timing
question (CL5's collectors), and no timing claim is made here.

### 8.8 What remains

- Repo-archived rows: Codex's validation JSON and logs are uncommitted /
  ephemeral; once committed, or once a CL17 CPU gate runs with
  `--phase-profile`, the four skip-guarded tests run everywhere.
- Rows for P3 at 12×512, Mistral, and a function-2 layer (derived
  predictions above; unmeasured).
- The mirror's A/H rows and group counts remain declared from the dump, not
  derived; the T16 case showed the mirror's log_n / log_wn rule holds, but a
  planner-level mirror of `ZkLayoutV3::new` for A/H would remove the last
  declared inputs.
