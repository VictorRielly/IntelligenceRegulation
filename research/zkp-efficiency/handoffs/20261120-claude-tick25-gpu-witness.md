# Research handoff: GPU witness generation for integer transformer inference, and what it would do to the sealing side (2026-11-20, claude-tick 25, queue item 5)

From Claude, the standing background researcher (D50). One bounded tick on one question.

**Scope.**
- Web reading plus local counting: 6 searches, 6 page fetches (one failed: the ZK-Tracer PDF exceeded the fetch size limit; ePrint full texts not read). No build, prover run, GPU run or Git write. Written: this file, the script `20261120-claude-tick25-gpu-witness.py` (standard library, reads no file), a STATE.md entry, the queue update and the coordination pointer.
- **Triage material, not a work order.** Anything here that changes what is committed alters proof bytes and needs the owner's ruling, a new profile and re-proving in Lean. The items below change no committed word: a witness builder that returns the same planes is byte-gated (goldens, pinned digests). The owner shelved proof-size work on 2026-11-09.

Labels: **[AUTHORS]** (a number a source reports), **COUNTED** / **MEASURED** (record cited), **DERIVED** (arithmetic in the script), **MODEL**. Sources read in part are marked.

## 0. Headline

- **The queue item's pointer is wrong.** EmuGEMM (arXiv 2606.25453) is a library for emulating FP32/FP64 matrix products with integer tensor-core kernels (Ozaki schemes), aimed at scientific computing; it has no zero-knowledge or witness content [read: HTML full text via fetch summary]. Its one relevant sentence is the exactness fact we already use: "an INT8 x INT8 matrix multiplication accumulated into INT32 is an exact integer computation without rounding error" [paper]. It covers GH200 and B200 only; the RTX 5090 is not mentioned.
- **Published GPU witness generation gives nothing that maps onto the sealing chain.** ZKPoG (ePrint 2025/765) puts witness generation on an RTX 4090 for Plonkish circuits: 22.8x over CPU and 12.7x over other GPU work end to end [AUTHORS, abstract only]; no witness-stage figure, no AI workload, nothing on serial dependencies. The cost survey arXiv 2611.17042 says ZKPoG is the only surveyed design that accelerates witness generation and gives witness shares of proving time: zkLLM 32 to 44% (A100), DeepProve 3 to 6% on GPU at 64 to 1,024 tokens (67% in one CPU run), LoRA proofs 3.6 to 18.8%, ZKTorch 14%, Expander block about zero [survey, first 100,000 characters; its numbers, not checked]. MegaZK's "more than 25%" is the combined share of witness generation, commitment, quotient and FRI, not witness alone [search-result text, abstract level; corrects my first reading of a search summary]. ZK-Tracer is an ASIC for zkVM traces (1,829x on trace generation [AUTHORS, abstract only]); a zkVM trace is not this witness.
- **No published system I found has a forward chain that gates the prover start the way ours does** (block k+1's build needs only block k's output vector). The literature does not decide this question; the local records do.
- **Local finding (DERIVED from MEASURED, section 2):** the weight products are already on the GPU and are 17% of the Mac's sealing pass; 80% is host work. On a 5090 the products' floor is about 4 ms per request (section 3), so a GPU does not help by making the products faster; the only GPU-witness lever left is the data-parallel host work (histograms, limb planes), 0.667 s of the 2.183 s solo pass (30.6%).
- **Effect on proved tokens/s today: none** (A33: the stream is paced by the prove call). It matters only once the prove call shrinks; section 4 gives the test.

## 1. What the literature says, per source

| Source | What it is | Bearing on us |
|---|---|---|
| EmuGEMM (2606.25453) | FP-emulation GEMM on INT8 tensor cores; 1,639 Top/s on GH200 (83% of INT8 peak), 3,654 Top/s on B200 (81%) [AUTHORS] | none beyond exactness of INT8 to INT32 |
| Deterministic INT8 inference papers (2609.00363, 2608.13756; search summaries only) | INT8 x INT8 to INT32 is order-independent while K stays under about 131,072 | our exact i16 / f64 argument (H124 README) is stronger and already tested; no new constraint |
| ZKPoG (ePrint 2025/765) | Plonkish witness generation plus proving on one RTX 4090 | no AI circuit, no witness-stage number |
| MegaZK (ACM 10.1145/3797905.3807842; abstract level) | memory-efficient GPU prover, less than 1/5 of baseline memory [AUTHORS]; has a witness scheduling section | combined 25% is not a witness share |
| Infrastructure for Verifiable AI (2611.17042) | cost survey; witness is 3 to 44% of proving time depending on system | confirms witness cost is system-specific; our share is not in the range of any one of them (section 2) |
| ZK-Tracer (2605.25493) | ASIC trace generation for zkVMs | different problem |

## 2. Where this project's witness time sits now (all from `results/zk60_claude_batch8_sealing_split_20261117/REPORT.md`)

MEASURED (solo sealing pass 2.183 s, 32 blocks, sampler split converted at the unsampled figure; the sampler perturbs groups unevenly, so shares are approximate):

| Group | s | share | Content |
|---|---:|---:|---|
| (a) witness-only finish | 1.065 | 48.8% | CS-3 lookup-miss check 0.728 (of which 0.349 repeated the build's public check: removed by A33 stage 1), `assign_with` 0.302 |
| (b) before first product | 0.146 | 6.7% | the build's own weight scan 0.128 |
| (c) middle | 0.531 | 24.3% | scores, softmax, PV 0.354; requant and RoPE 0.114 |
| (d) device wait | 0.440 | 20.2% | `wait_done` spin 0.416 |

- GPU busy is 0.372 s per pass (17.0%; 11.6 ms per block). Host-only groups (a)+(b)+(c) are 1.743 s (79.8%) [DERIVED].
- The weight products are already on the Metal GPU (A4, byte-identical). `HL_GPU_WITNESS_VIEW=0` cut the commit-to-start latency from 0.242 to 0.085 s and the pass did not shorten: the saving reappeared as host copy time (Batch 8, Q3).
- **Which of the host work is data-parallel and exact** [COUNTED from the table above]: `w16_histograms_cols` 0.250 s, the other histograms 0.128 s, limb planes and scatter 0.289 s: **0.667 s, 30.6% of the pass, 20.8 ms per block**. With scores, softmax, PV, requant and RoPE (0.468 s, integer and exact but with more state) the host-only builder work is 1.135 s (52.0%).
- **The request-independent scan.** `check_accuracy_for_shape` depends on the block's public data and the shape only (`private_block.rs:852-874`, read just now: no request input), and scans about 218 MB of weights per block, 7.0 GB per request. The build runs it once per block per request (group (b), 0.128 s, 5.9% of the pass). The resident blocks are shared across requests (A23) and the check could be memoised per block; whether the startup load already does this scan I did not verify, and the H-1 ruling fixes the order and text of refusals (`trained_block.rs:2822-2828`, cited in the A33 README), which a load-time check would move. Same words out.

## 3. What a 5090 changes (figures for the card are third-party spec pages, not NVIDIA's datasheet)

- INT8 dense about 838 TOPS, bandwidth 1,792 GB/s [search results; one outlier site lists 3,352 TOPS, which others give as FP4 sparse].
- One 8B block's products are 27.92 G MACs and about 218 M weights (H124 README). **Floors per block: 0.067 ms arithmetic, 0.122 ms weight read; 3.9 ms per request** [DERIVED]. The Mac's measured GPU busy is 11.6 ms per block, about 96 times the weight-read floor (it includes non-matrix kernels and launch gaps, so this is a gap to the floor, not a ratio of like with like). So **products stop being a cost on a 5090 even at 10x off the floor**, and the device-wait group (d) (20%) shrinks with them.
- **What does not shrink:** groups (a), (b), (c) are host code. On a discrete GPU there is a further question the Mac does not have: planes built on the host must cross PCIe. A rows are 2,279 per block (984 words, 1,272 limbs, 8 aggregates, 15 tables; cycle 6a section 2), 299 MB per block, 9.6 GB per request; at 40 to 55 GB/s that is 0.17 to 0.24 s per request, overlappable with the prove call [DERIVED; link rates ASSUMED]. A device-side builder would also remove that.

## 4. Proposed test (nothing built; falsifiable in this project's terms)

**W1 (counting, plus one small Metal bench the coordinator may run on a quiet GPU).** Hypothesis H164: a device builder for the histograms and limb planes (same words out) takes at most one third of their host time at the Mac's own GPU.
- *Measure:* a micro-bench of `w16_histograms_cols` and the limb scatter for one W16R2_8B block on the Metal GPU, from the same inputs, compared with the host figures 7.8 ms (histograms) and 9.0 ms (limbs) per block (section 2).
- *Pass:* device time at or below 6 ms per block for both together (a third of 16.8 ms), including the copy of the inputs if the planes stay host-resident. *Kill:* above 11 ms per block.
- *Even at pass, the stream gains nothing on the Mac* (A33: prove-paced). The test is worth running only as part of a decision on the target box; hence it is not urgent.
- **What the target needs** [MODEL, from `MVP_STATUS.md` and Batch 7: two lanes, cadence = (sealing + write + prove) / 2, so 2.56 s per request allows 5.12 s per lane]. With the prove call at 2.8 s, sealing plus write may be 2.32 s against about 3.7 s beside a proof today (3.35 s sealing before A33, write 0.33 s). Moving the 0.667 s data-parallel subtotal off the CPU would be about 1.0 s beside a proof if the x1.51 contention slowdown applies uniformly (ASSUMED); the gap to close is about 1.05 s. So this lever is the same size as the gap; it is not small, but it is one of several (Batch 8's "(a) off the chain" model gives 1.9 to 2.3 s beside a proof; the memoised scan another 0.13 s).

## 5. Expected effect

- **Committed words per request:** 0 (byte-identical planes; gated by the goldens and pinned digests).
- **Proved tokens/s:** 0 now on the Mac (the prove call paces the stream, A33 and tick 22's rule (a)). On a box whose prove call falls to about 2.5 to 3.0 s the sealing side is the next limiter, and then the device builder is worth up to the 0.667 s to 1.0 s above, about x1.2 to x1.3 on the sealing side, not on the cadence by itself. No cadence figure is claimed.

## 6. Risks and what was not verified

- All 5090 figures are floors from third-party spec pages; no 5090 measurement exists here. The sealing host on the target box is unknown (CPU cores differ from the Mac's 32).
- The sampler split perturbs groups unevenly (Batch 8 says shares are supported for (a)+(b), not for (c) and (d) separately).
- I read only abstracts for ZKPoG, MegaZK and ZK-Tracer and the first 100,000 characters of the survey; no ePrint full text. The survey's shares are its own and mix systems and hardware.
- The memoised scan was not checked against the startup load or the H-1 refusal order; a code owner must check before anyone relies on it.
- A device builder must preserve the plane layout the commitment reads and the order of refusals (Batch 8 Q4: hand-over order, refusal order, the Turn and the memory budget constrain moving work off the chain).

## 7. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0.** Hypotheses: H164 added (device builder for histograms and limbs). The complete private 8B at >= 50 proved tokens/s remains **unachieved**.
- Pointer posted to `ops/zkp-mvp/RECOVERY_COORDINATION.md` (see the report).

## 8. Next concrete actions

1. Coordinator: note that the queue pointer to EmuGEMM was a misread; the literature offers no GPU witness design for this chain.
2. Anyone with the code open: does the startup load already scan the weights for the symmetric-int8 rule? If not, a per-block memo of `check_accuracy_for_shape` removes group (b)'s 0.128 s per pass without a protocol change (refusal order to be settled).
3. If the target box is chosen as a discrete GPU, schedule W1 on it rather than on the Mac.
