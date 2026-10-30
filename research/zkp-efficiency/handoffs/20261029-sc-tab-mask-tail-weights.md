# SC_TAB terminal-mask equality weights — conditional handoff

Cycle0136, run `20261029T055649Z-74b83633`. **No native proving gain.**
The algebra/source prerequisite passes; the selected scope's measured parent
phase is small. Owner measurement should precede a build or integration.

Seam: `ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs`,
`mask_eval` at405 and `run_slot` extension closure at611 in the pinned source.
Actual source SHA256 and seven companion pins are in
[native-pins.json](../experiments/final-claim-lifetimes-20261029/native-pins.json).

Patch: [mask-tail-weights.unapplied.patch](../experiments/final-claim-lifetimes-20261029/mask-tail-weights.unapplied.patch).
It is uncompiled/unapplied. `MaskTailWeights::at(&mut self, &[Fp2]) -> &[Fp2]`
stores one exact ordered public tail and its Eq table. `mask_eval_cached`
keeps the original row_log/logm/c0/slices/read/combine body. Only SC_TAB selects
it inside one extension closure. Every other slot retains `mask_eval`.
Original shape checks, all terminal ordering and the entire verifier are literal.

Source census: SC_TAB has3A+3H private pairs, all onDom::Tab atlog_cols,
coordsrho(0..log); its six Eq constructions have one identical fresh point.
The ordinary main-table finals are already retained. No savings there.

AtN16384: Eq mul196596→32766; five Eq and reversed-point vectors avoided.
All196608 private mask-row reads/mul_base calls remain. Added key/dispatch/
comparisons; point payload224B. The262144B logical Eq vector now remains live
during subsequent extension work. Actual peak and exclusive cost are unknown.
Cache no private data/evaluation, mask, pad or opening. No cross-proof reuse.

Validation: 1042 checks/102 synthetic fixtures/13 wrong-control families;
independent original-cube and large-row MSBfold Fp2 reference. Actual row
logs13/14 tested, but no model context/proof. 75source/count/patch checks
passed; unified patch applies in memory to exact pinned source only. CPU model
1.528105s/41284KiB; source audit0.004654s/15884KiB. Reproduction commands and
limits are in the [experiment](../experiments/final-claim-lifetimes-20261029/README.md).

Historical TinyLlamaR4T128/L22 source ledger: GPU-assisted SC_TAB extension
0.55s/prove_run135.809s. Even free whole-phase deletion gives≤1.004066x on
THAT diagnostic. Actual savings are smaller; no8B transfer or numeric GPU rate.
This exactness result does not justify displacing whole-prover GPU work.

Owner next: isolate Eq preparation, row dots and extension/CFS clocks; census
tail hit/miss incidence and actual live capacities. If material, compile under
the current shared heavy/build guard, then native direct field, zero/one/tail,
dirty row/offset/width, mask/claim-site and source-drift controls. Require actual
slot masked rounds, RNG/next-draw/transcript, golden receipt bytes, refusal
ordering, PCS/capture/privacy gates and independent fresh-process complete
receipt verification. Compare actual enclosing cold/warm workloads with startup,
all recurring work, serialization/drain and verification. Reject regressions.

No production/reviewer/instruction/receipt/calibration/safety files changed.
No native job queued, GPU/install/Git/external write/message performed. Main/
Claude reviews/integrates; no merge. Saved handoff is not delivered-message evidence.
