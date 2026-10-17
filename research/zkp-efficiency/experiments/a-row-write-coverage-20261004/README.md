# A rows written once — cycle0020

Run `20261004T020146Z-c40246c9`, completed 2026-10-04T02:17:08.049413+00:00. Research-only source-pinned Python oracle. Safe Rust review sketch is uncompiled and unintegrated. No native proof, GPU, transcript, real mask generator, trained checkpoint, or measured proving improvement.

Question: can the recurring private-block A assembly avoid zero stores later overwritten by witness conversion, table histograms and fresh randomness while keeping every row fully initialized? Baseline: `ops/zkp-mvp/candidate/hashline/src/private_block/protocol.rs:798` allocates a zero A buffer then scatters all supplied witness planes; after deriving histograms it writes their first256 entries and overwrites all reserved mask/proximity rows. Public offsets come from `layout.rs:1064` and row widths/P-3 domain lifts from shape.rs.

The tested candidate computes the existing histograms first, then appends each plane/256 histogram words, required zero row tails, and fresh mask words in the exact original row order. Restricted source parsing is checked against an independent plane-family catalog; an independent row-address decoder and modulo-p byte oracle check the resulting buffer. Synthetic PRNG continuation and changed-attempt seeds are checked; this is Python random.Random, not native ZkRng. Moving histogram computation before assembly has no draw/absorb in the inspected original interval, but native refusal/order/lifetime effects still require review.

Result: 18 cases, 800,768 field words, 53,646 required zero words and 48,640 synthetic fresh-mask words; all 18 controls pass. CPU 2.156225s, peakRSS 29496KiB, Python3.10.12, Intel(R) Core(TM) Ultra 9 185H, one low-priority CPU pinned to core0, no GPU. Estimate64MiB, address-space cap512MiB,59s alarm. Synthetic contexts1/3/5/8/32, row widths256/512/1024, norm/softmax limb variants(4,2,2),(4,3,2),(5,3,2); none admits new native profiles. Arbitrary supplied padding values are copied unchanged. Integers include i64MIN/MAX; lookup indices include-1,255,256 and widened-row boundary. Bucket-0 fallback, exp/act pair mismatch and table padding above255 are retained.

Controls: missing/duplicate/gapped/negative/unknown coverage intervals; short witness and histogram; dirty row tail/table padding; moved histogram; altered first mask/proximity/plane; widened-table fallback mutation; substituted masks from another attempt; RNG-continuation mismatch; supplied internal padded word incorrectly zeroed. Full list in result.json. Initial pass preserved before the final supplied-padding control refinement. Fresh appended construction has no pooled dirty-buffer path; no native pooled shrink/grow claim.

## Counted work, not physical traffic or timing

| Public geometry | Final A MiB | Required zeros MiB | Logical overwritten initial zeros MiB |
|---|---:|---:|---:|
| Toy T32,d16 |0.889|0.0098|0.879|
| Synthetic125M T512,d768 |710.125|0.979|709.146|
| Historical Mistral geometry T512,d4096 (unregistered) |2329.125|0.854|2328.271|
| Historical Mistral geometry T1024,d4096 (unregistered) |6289.375|0.838|6288.537|

These large shapes are allocation-free counts, not experiment allocations or accepted private8B model shapes. Counts match retained layout payload totals. No matrix capacity is saved. Witness reads/conversion, histogram derivation, fresh masks/pads, encoding, hashing, openings, proof bytes and transfers remain. Padded supplied coordinates are NOT inferred to be zero from an input value; only public row tails/table extension are explicitzero ranges. Mask randomness is not cached/reused.

Local installed Rust alloc sources and official current source distinguish generic Clone+extend_with from internal IsZero+zeroed-allocation. Fp is a transparent customu64 wrapper and does not implement that private primitive specialization. This supports inspecting actual assembly; it does not prove runtime zero stores: LLVM/backend or allocator may transform fill. Installed stable source was pinned, production compiler identity/assembly not established. Python array allocation/timing does not measure native Rust or allocator behavior.

## End-to-end bounds and missing clocks

Same retained onecold synthetic12-block125M-geometry T512 RTX4070Laptop8188MiB diagnostic:408.609226s enclosingwall,318.22s runprover INCLUDINGwitness/serialization,12.15s in-processverify,484107456B, independentverificationfalse. A allocation+plane-fill sum86.691s across12 blocks=21.216% wall. Entire parent deletion at zero cost leaves321.918226s and arithmetic1.590466positions/s. This is neither candidate saving nor countable private8B throughput. Real candidate saving M and addedcost C are unmeasured; target ceiling N/(T-M+C) unknown. Tables/masks appear in separate later timers, so this parent bound applies to the allocation/plane part and is not a strict bound on every A-related zero store across all phases. Startup/steady slopes and proof backlog/drain absent.

This cycle complete private8B passes0, countabletokens0, modelcontextnull, deviceCPUonly. Steady-state/total-workload rates,startupfraction,witness/proof/serialization/independentverification clocks,prooflatency/lag/drain all unmeasured/null. Context growth can raise attention quadratically; count-only longerprefill is not resident-pass or decode evidence. No startup amortization measured, no acceptance512-latency cap.

Added costs: exact-capacity owned Vec assembly, public offset/coverage checks, append/resize loops, histogram-before-assembly scheduling and changed private lifetimes. Safe review sketch uses only initialized Vec operations. Scratch/list overhead omitted from payload counts. Falsification: any native value/padding/refusal/RNG/transcript/proofbyte mismatch, hidden-value schedule, native allocation alreadyavoids redundant stores, unchanged phase time, or append/scheduling cost>=removed work.

Reproduce: `python3 experiments/a-row-write-coverage-20261004/experiment.py`. command.txt,stdout/stderr,exit-code,source-pins,source snapshots,seed/dimensions and result retained. No foreign code run. Source search in search-log.md/source-records.json and sources.jsonl. Main/Claude owns any promotion; researcher does not merge.

Next: owner should split allocation/zero-initialization from Fp conversion/copy before guarded native A/B. Complementary nextCPU experiment: compare exact signed-i64 field conversion without a redundant magnitude modulo (abs(i64)<=2^63<P), including i64MIN, to the independent modulo oracle. Inspect generated code only in an admitted small or guarded owner lane; compiler may alreadyremove it. Never substitute a dtype/precision/refusal change. Rotate sumcheck/GKR literature next while preserving the owner-held actualSC_SZC lane.
