# Review lead: exact S12 cardinality and larger public DD caps

2026-10-20, cycle 0112, run `20261020T201854Z-91cdb36a`. **Counted candidate only; no native patch or measured proving improvement.**

R11 already says S12 exceeds cap32. Exact public values sharpen that result: for head_dim128, f_e9 and base e_s2/3/4, the proposed S12 input grid has n_col156/94/55, including zero. Its actual e_s is base minus4. Power-of-two caps256/128/64 exceed today's32 and require separate profiles. F_P12 changes quotient precision, not exp cardinality.

On the complete R11 HIGH block count, the proposed T512 DD variants give 803,176,448 / 752,844,800 / 727,678,976 committed words against 836,337,664 without DD (-3.965% / -9.983% / -12.992%). This does not inherit the old R9 -20.8% number. At T128, the same alternatives add9.771% /2.884% or save0.560%; preserve these negatives. T512 is not registered/proved by this study, and HIGH quality is not evaluated.

At T512 / f_e9 / F_P12, dictionary slots carry10 A planes,7 H pairs and11 byte lookups. At cap256 those data payloads alone are320MiB and448MiB. Six additional net claim sites add393,216 fresh base-field mask words (3MiB). The full counted delta includes removed S helper pairs: `-16*S +24*Dd +12*row_width`. This is a payload/count identity, not allocator peak/VRAM or runtime. Actual lookup temporaries, histograms, original owners, encode/hash/open scratch, pools and transfers remain to measure.

Interface and patch location: research implementation is
`experiments/public-exp-dd-cardinality-20261020/probe.py` (`table`, `dd_column`, `dd_row`) and `cost.py` (owner R11 build adapter). It snapshots the current local source, with hashes in `source-pins.json`. No production patch is supplied. An owner implementation would need reviewed changes at:

- `r9/frozen-tree/hashline/src/tables_attn.rs`:256-entry generator/spec digest to an explicitly versioned S12 table, never a silent legacy-table change.
- `hashline/src/private_block.rs:dd_e_column_of`:same whole-public-table union-zero rule; extend table width only on new profiles.
- `private_block/shape.rs`:public cap/profile/schedule, Dd domains and no-lift restriction, widths and F_P limb class.
- `private_block/trained_block.rs`:table metadata/generator/digest validation and pre-header refusal.

Native source paths above are relative to `results/zk60_1b_native_20261017/`; actual file hashes, exact source paths and copies are retained. Do not modify the frozen tree. Main/Claude reviews and chooses any fresh candidate location.

Validation:486,630 checks/1,080 synthetic arithmetic rows/7 controls; independent1,927-check90-digit recurrence,265,728 entries,130-digit repeat,410 actual public arrays,16pins;612 cost checks, four retained native size anchors and the saved R11 HIGH baseline. CPU clocks0.308s probe /0.445s audit /0.044s count. Both initial cost-accounting assertion failures are retained and explained in README. No native private sumcheck/receipt/device result is implied.

Next: freeze the actual fidelity-relevant S12 tables and e_s before adopting any counts. A bounded follow-up can compare uniform versus per-layer public caps on a labeled schedule, costing masks, round/site/receipt changes and payload lifetimes. Existing b7 public e_s distribution is only a sensitivity fixture; new calibration can change it. No observed private-trace cardinality, dynamic hidden cap, reduced checking or reused blinding.

Review obligations: D32 quality/refusals, new profile/model identity and complete relation coverage; fresh private masks and joint-view/capture gate; D27 whole-run soundness with changed domains/queries; D30 N-r9-a Sum/slot17/Ht and N-r9-b M_dd-in-A before lookup challenges. Existing R9 or D33 privacy cannot be transferred. The literal source still has cap32 and rejects these S12 tables. New count-positive cases do not authorize changing the target or claiming >=50/s.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode was run. Synthetic row lengths 32/128/512 and counted T128/T512 geometries are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private 8B >=50 proved positions/s target on an RTX 5090 or another named high-end GPU remains unachieved.

[Full experiment](../experiments/public-exp-dd-cardinality-20261020/README.md). Saved review notes do not establish delivery. No merge or production write.
