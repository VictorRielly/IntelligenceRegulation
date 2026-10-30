# DD grouping: calibrated constants and short row-equality follow-up

Cycle0169 (`20261030T174123Z-29d8a272`) extends
[the prior DD handoff](20261030-dictionary-softmax-grouping.md). It adds
arithmetic evidence and no distinct speed claim. Main/Claude owns native
review, implementation and integration; no source patch was applied or merged.

Interface: `argument.rs` DD SC_SZC -> `SlotDef.groups` -> `GroupedEqRounds`.
Three internal brackets, equality points tau/p_ht/p_s at start0, degrees3/1/1,
slot degree4. Keep original tables/folds/finals, all dictionary/lookup/exp/
host/future-score relations, masks, transcripts and openings.

The concrete research patch is
[dd_projection.py](../experiments/dd-calibration-boundaries-20261030/dd_projection.py):
score coefficient2^sh, half2^(sh-1), remainder range coefficient2^(8-sh),
for source structural shifts1..8. All four lookups and both helpers remain.
Keep shorter p_ht equality and hosted SC_RS multiplicity|S|/|Ht|. Full-file
source pins and comparison with owner R14 final DD branch are retained.

160 fixtures and54 negative controls pass; standalone ungrouped audit27026
checks passes, including every saved round/final and host multiplicity. Main
2.130617s/23164KiB; one CPU, synthetic n0..3, no GPU/native cryptographic proof.
Zero proved positions. This is not native masked-byte, privacy or performance
evidence. The separate R14 native terminal count is not this projection's
15-table count.

The prior scan/fold saving36 Fp2mul/7 mul_base/47add/15sub per pair is unchanged
across shifts. Setup, inverses/recovery, degree completion, reduction and
whole-proof costs remain unpriced; complete-model ceiling unknown.

Next owner: actual DD incidence and exclusive slot/group clocks, then source
degree/lookup/calibration checks and native unmasked+masked round, RNG/
transcript, extensions/PCS, receipt/refusal/final-order parity; independently
verified full-stack proofs and current privacy gates under shared heavy/build
locks. Reject any mismatch or added critical cost at least avoided cost.
Do not duplicate or edit the owner's pending R14 freeze/review work.

Details, commands, controls, limits and falsification:
[experiment](../experiments/dd-calibration-boundaries-20261030/README.md) and
[integration note](../experiments/dd-calibration-boundaries-20261030/INTEGRATION.md).
