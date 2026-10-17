# ZKP efficiency explorer — durable state

Cycle0060 COMPLETE: `20261017T102624Z-c13de864`; checkpoint2026-10-17T10:38:15.278965+00:00. AGENDA/current target,
durable/project memory and latest3 experiment results read/snapshotted.
303 source records parsed;6 LIVE primary records appended,309 total.
Historical FINDINGS/source prefixes preserved. No native speedup established.

Latest owner evidence: linked trainedTinyLlama1.1B,T32,22blocks,one CPU pass
528.926s and one RTX4070Laptop-assisted pass545.079s,each with matching retained
fresh-verifier log. Sealing/parity+source rebuild453.647/457.911s(85.77%/84.01%);
these include reads/parity/extraction,not isolated matmul. Pure startup and
serialization unsplit. Prove_run includes witness and sink; exclusive remainder
59.619/68.066s is not pure proving. No fresh native verification rerun here.
D24 round2 accepted with conditions in current register; no trained/GPU shape
privacy acceptance. None of these diagnostics count toward8B target tokens.

Experiment experiments/exact-witness-limb-census-20261017:
200fixtures,17820 independent dots,59496 kernel output,318888 rounding,
6348 padding checks,12 real controls. Own tiny C helper compile+test only:
1.866833s/37876KiB,seed2026101760,one nice19 CPU0
thread,59s/512MiB. Synthetic tiled C median ratios3.12–7.72x; IO narrowing alone
slower. Not native Rust/proof/GPU gains. Six exact-int8-fed calls are direct
i32 eligible (K<=132104,including -128 weights); int16down is not. Full padded
K and original quantize/refusal order retained. CSE/fusion/older negatives preserved.
Candidate i8-projection-candidate.patch changes six calls+one helper,uncompiled,
unapplied; exact inverse source reconstruction. Independent audit145snapshot checks pass.
Live hashes changed in witness.rs/shape.rs/run.rs/trained_block.rs during the cycle; original
live-hash audit failed as designed. Drift is retained in live-source-drift.json.
Owner R3 now tiles/parallelizes with i32 products/i64 accumulation and builds
witnesses ONCE with endpoint/parity checks during proving. Candidate is STALE;
do not apply without comparing/rebasing. No R3 verified timing reproduced here.
Handoff handoffs/20261017-exact-witness-projections.md; main/Claude integrates.

Ranked queue:
1 REFINED/TESTED SYNTHETIC/OWNER exact i32 accumulation on six i8 projection paths;
 compare to concurrent R3 tiled i32-product/i64-accumulating one-pass code first;
 native compiler/allocations/phase/refusal/bytes gates before any end-to-end factor.
2 OWNER native GPU SC_SZC with masked/transcript/RNG/PCS/privacy gates.
3 OWNER resident complete-pass slope; R3 one-pass changes supersede old duplicate
 witness cache proposal; no startup relabel of old sealing and no mask reuse.
4 OWNER prior split-int16down fullK/i64 reconstruction; never direct i32 down.
5 OWNER prior public selector/factory actual capture and profile,local demoted.
6 NEW AWE exactFP4 encoding algebra reproduced65536pairs,coverage±148,stored<=6;
 42849 coefficient mutation failures. Source theoreticalRTXPRO6000/B200 ratio1/3
 versus nativeINT8 before overhead; demoted on INT8-capable hardware,not5090
 measured. No author performance reproduced. Ozaki knowncycle22 refresh;
 IntegerAlibi newAug13/18,2026;CUTLASS4.8 September date evidence qualified;
 PR3302 open,full example commit metadata only,diff blocked;C++BSD3 vsDSLEULA.
 zkIE public activations/verifier rerun excludesP1;history update unknown.

Next LOCAL: allocation-free witness allocation/lifetime census at initialpl
 allocation/replacement and clones in new R3 one-pass code. Do not duplicate
 owner's parallelization/one-pass work. No private data written to research.
Next OWNER: compare/rebase stale patch versus R3 before shared build/heavy guard,native exact witness /
 first-refusal / transcript/RNG/proof bytes / fresh verifier gates; split all
 seven projection/norm/range/plane clocks including packing/allocations,then
 fixed-context resident workloads with true startup,slope,lag/drain and masks.
Complete8B ceiling unknown; deleting ENTIRE retained witness-related families
 yields only diagnostic7.0262xCPU/6.2532xGPU,not predictions or8B bounds.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, context length, proof latency/lag/drain: **unmeasured**. Local experiments: one Intel Core Ultra 9 185H CPU thread, CPU0, nice19, no GPU. Retained owner diagnostics: TinyLlama1.1B, T32,22 linked blocks, one CPU pass and one RTX4070Laptop-assisted pass (not resident repeats); shape privacy acceptance is absent. No long-context prefill, resident-model sweep or decode proof ran. Longer contexts increase dense-attention work approximately quadratically. Larger workloads remain permitted with fresh masks and all privacy obligations; the >=50 proved-token/s target remains unchanged and unachieved.

Research only:production/runtime/Git/calibration/gates/instructions/reviewer
files untouched.No native/application build,proof,GPU,install,foreign script,
external write/message,merge or heavy job queued.Own tiny C compilation only.
Saved reports do not establish user delivery or supervisor liveness.
Next cycle not before2026-10-17T11:26:24Z.

Final checkpoint 2026-10-17T10:38:29.841443+00:00: historical FINDINGS/source prefixes preserved;309 source records and6unique new IDs;63artifact pins;executed source hashes match. Four concurrent owner source changes are retained, so candidate remains stale pending comparison/rebase. Native gates remain unrun.
