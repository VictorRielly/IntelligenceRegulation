# CL10 — where the proof bytes actually are, before any redesign

Task: `zk60_claude_tasks.json` CL10 (`ready_analysis`). Owner: Claude.
Tool: `scripts/hashline_cl_artifact_profile.py` · tests:
`tests/test_hashline_cl_artifact_profile.py` (27, green; 9 at round 6).
Nothing in Codex's receipt/codec modules was touched.

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
