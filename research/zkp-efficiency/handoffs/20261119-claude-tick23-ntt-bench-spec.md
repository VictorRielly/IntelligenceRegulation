# Research handoff: specification of the NTT-only bench for the commit kernels (2026-11-19 UTC, claude-tick 23, queue item 39)

From Claude, the standing researcher. Triage material, not a work order. Specification only: nothing here is scheduled and nothing was run.

**Question.** The commit NTTs run 2.1 to 2.3 times over a 700 GB/s traffic floor (tick 21 section 2). Which bench would say whether the gap is arithmetic, occupancy or access pattern, and which of H117b, a radix-8 pass or a matrix-NTT split each outcome favours?

**What was read and how.** Local only, no web. Full: `metal_kernels.metal` lines 1 to 110 and 205 to 463 (`gl_mul`, `k_ntt_head_t`, `k_ntt_tail`), `metal.rs` 210 to 332 and 2056 to 2110 (`encode_fused`, `commit_impl`), the K0, K1 and K4 sections of `results/zk60_k0k1_roofline_20261118/README.md`, tick 21's handoff. Script `20261119-claude-tick23-ntt-bench-spec.py` (standard library; every DERIVED number below). Paths under `ops/zkp-mvp/gpu-metal/hashline/src/gpu/`. Labels: COUNTED (file), MEASURED (record), DERIVED (script).

## 0. Headline

1. **A two-term model already reproduces the measured NTT times.** Arithmetic at K4's independent-chain rates (gl_mul 4.55 ps, gl_add 1.71 ps, whole GPU; MEASURED) plus the traffic floor of tick 21, with no overlap between them, gives 4.01 to 4.36 ms (8B A inverse; measured 4.110), 7.28 to 7.86 (8B A forward; 6.897), 7.32 to 7.95 (Shieldstral inverse; 7.427) and 26.9 to 29.1 (Shieldstral forward; 25.138): measured is 0.92 to 1.02 of the low end of the sum (DERIVED). Either term alone is 0.45 to 0.60 of measured. So "arithmetic or memory" is the wrong split: the kernels look serial in the two (load tile, compute, store), and the bench must test overlap, not pick a winner. Caveat: the add/sub count uses K4's optimistic rate and the shift multiply `gl_mul_pow2` was never timed (bounded between add and mul), so a fit this close is partly luck; treat it as a prediction to falsify, not a finding.
2. **Two reading findings the bench should isolate.** (a) The head's input read is a bit-reversed gather: `head_input(..., rev_bits(g, log_n), ...)` (`metal_kernels.metal:296, 310`). A threadgroup's 2,048 consecutive g read words whose low log_n-11 bits are fixed and whose high bits vary, i.e. one word in 8 (inverse, 2^14) or 16 (2^15) across the whole 128 KB row; the 8 (or 16) groups of a row together read every line. Line efficiency within a group is about 1/8 (DERIVED from the index map; 128 B lines assumed, not verified), and tick 21's traffic floor counted one read. (b) Production 8B forward (`MODE_ZK`) is NOT pruned: `extent = 2^14 + q` (280 or 256) exceeds `2^(log_n - 1) = 2^14` (`metal.rs:299-300`), whereas the diag forward (`MODE_PLAIN`) is pruned, and the ZK head also does a `gl_mul` by `pows[i]` per input word. Estimated extra arithmetic for the A commit: 0.21 to 0.33 ms for the unpruned pass plus about 0.19 ms for the multiply (DERIVED), against the unexplained 1.32 ms (9.4%) between the commit and its three diag parts. At Shieldstral (`log_n = 16`) the row is pruned in both modes. Neither is a defect proved here; both are things a plain-mode diag cannot see.
3. **Ceiling for the one arithmetic lever.** General multiplications are stages 7 up (stages 1 to 6 are shifts). A 2^6 x 2^6 x 2^k split (64-point blocks are shift-only: 2 has order 192, so every 64th root is a power of 2, `metal_kernels.metal:214-217`) needs two inter-pass twiddle sets, 0.40 to 0.50 of today's general multiplications (DERIVED: 2^14 row 32,768 against 65,536; 2^15 row 65,536 against 147,456; 2^16 row 131,072 against 327,680, scale excluded, trivial twiddles not skipped). On the K4 model that saves 2.5 to 3.0 ms per block at W16R2_8B (2.7 to 3.2% of 91.46 ms; at most 2.5% of cadence at full pass-through, by tick 22's rule) and 8.0 to 9.6 ms at Shieldstral (4.6 to 5.5% of 174.25 ms), before the cost of the extra transposition pass. Same words out, so no commitment change; under the 5% rule it stays unscheduled unless the bench shows the model's arithmetic share is real.

## 1. The counts the bench is set against (DERIVED, script)

| shape | rows | general mults / row | shift / row | add-sub ops / row | barriers head + tail | groups head, tail |
|---|---:|---:|---:|---:|---|---|
| 8B A inverse, 2^14 | 2,504 | 81,920 (incl. 2^14 scale) | 49,152 | 229,376 | 7 + 3 | 20,032 each |
| 8B A forward, 2^15, pruned | 2,504 | 147,456 | 81,920 | 458,752 | 6 + 3 | 40,064 each |
| Shield A inverse | 4,577 | 81,920 | 49,152 | 229,376 | 7 + 3 | 36,616 each |
| Shield A forward, 2^16, pruned | 4,577 | 327,680 | 163,840 | 983,040 | 6 + 4 | 146,464 each |

Arithmetic floor at K4 rates: 2.13 to 2.48 ms, 4.00 to 4.58, 3.89 to 4.52, 15.80 to 17.93 (range = shift priced at add or at mul). Threadgroup array 2^11 x 8 B = 16 KB (`TILE_LOG = 11`), 512 threads requested with radix 4 (COUNTED). Residency per core is not known to me.

## 2. The bench (K-series continues: N0 to N5; all guarded `gpu` class, quiesced box)

Harness as K0 and K1: kernels sliced verbatim from `metal_kernels.metal`, 3 warm-up and 15 interleaved timed repetitions, GPU timestamps per command buffer, head and tail timed separately, IQR under 10% of median or the run is void. Shapes: inverse 2^14 at 2,504 and 4,577 rows; forward 2^15 at 2,504 and 2^16 at 4,577, each in PLAIN and ZK mode (q = 280 or 256, real-sized pads and `pows`), because production is ZK. The shipped variant is compared word for word with the CPU NTT; the timing-only variants carry the K1 check (flipping one input word changes the output, so nothing is dead-code-eliminated).

- **N0 (no timing).** `maxTotalThreadsPerThreadgroup`, `threadExecutionWidth`, static threadgroup length of `k_ntt_head`, `k_ntt_head_pruned`, `k_ntt_tail`. If the maximum is under 512 the loops already run several items per thread.
- **N1 shipped**, per kernel, and the **roofline set**: (a) linear copy of a row-sized tile; (b) the head's gather map with a linear store; (c) the tail's map. (a) against (b) isolates the gather.
- **N2 arithmetic out.** `gl_mul` replaced by `gl_add` (same loads, barriers, threadgroup traffic), then `gl_mul_pow2` replaced by an add. Also a `gl_mul` only, no butterfly microbench to price the shift multiply.
- **N3 occupancy.** Add an unused threadgroup array so the group uses 16, 24, 32 KB (`threadgroup` memory limit permitting), leaving the work unchanged; resident groups per core fall in proportion.
- **N4 banking.** Index padding `i + (i >> 5)` on the tile (exact, same words). Apple's threadgroup bank structure is not verified.
- **N5 overlap.** Run head and tail with half the rows to see whether time per row is flat (latency hidden) or not.

## 3. Pre-stated readings and what each favours (inverse 8B A, 4.110 ms, as the example; scale by shape)

| outcome | reading | favours |
|---|---|---|
| N2 `gl_mul` to add cuts 18% or more of total (model: 0.93 / 4.11 = 23%, plus shift part) | arithmetic is serial with traffic | the split above, a radix-8 or split-radix pass that drops trivial-twiddle multiplies |
| N2 cuts under 8% and N3 time moves with resident groups | latency, not arithmetic | fewer barriers: radix-8 pass (about 4 head passes instead of 6, each with a barrier; the multiply count does not fall); smaller register footprint |
| N1(b) is 15% or more slower than N1(a) | the bit-reversed gather costs | choosing which end carries the permutation (internal `t` buffer layout; the forward's e is the commitment, so only internal order may move) |
| N3 flat from 16 to 32 KB | occupancy is not the limit | drops radix-8 and occupancy work |
| PLAIN against ZK forward differs by more than the 0.4 to 0.5 ms derived | ZK-mode specifics matter | a ZK-specific prune (the pad columns occupy only 280 positions) |

None of these is a prediction that a kernel can reach any floor; they are limits, as tick 21 stated.

## 4. Honest effect

On committed words per request: 0 (no protocol change; the factorisation, gather placement and prune are kernel-internal and must reproduce the same words). On proved tokens per second: nothing now. Bounds on cadence from tick 21 and 22 stand: H117b x1.10 / x1.09 on block GPU (a protocol-visible change, shelved by the owner's 2026-11-03 ruling), traffic-floor limit x1.15 / x1.25 and free-NTT limit x1.36 / x1.60, each discounted by the stream not being GPU-paced (a saving of x ms per block is at most x * 32 / 3,745.5 of the 8B cadence). The arithmetic-share lever above is 2.5% of cadence at most at 8B; only the Shieldstral profile (4.6 to 5.5% of block GPU) reaches the 5% line.

## 5. Risks and what was not verified

- K4's rates are independent-chain throughput; K3a showed these kernels issue products far below that, so the model's "arithmetic" term may be a floor too low, and its agreement with measured times may be partly accidental.
- 128 B cache line and the L2/SLC reuse across the groups of a row are assumptions; the gather finding is about the index map, not a measured miss rate.
- The ZK-mode extra work is an arithmetic estimate, not a measurement; production's own commit trace is not available (tick 21 T1).
- Add/sub counts treat `gl_sub` as `gl_add`; twiddle table loads in the tail (3 strided 8 B loads per radix-4 item, indices `kk * 2^(max_log - s)`) were counted but not priced. No ISA readout.
- Any change to the committed rows, order or pads alters roots and needs the owner's ruling, a new profile version and re-proving in Lean; the 2026-11-09 shelving of size work stands.
