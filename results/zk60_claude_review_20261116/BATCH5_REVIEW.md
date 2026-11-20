# Batch 5 independent review (D80a M1 + M2, H127, H128, H132, Candidate B census)

Reviewer: Claude (reading review only; no GPU run, no build, no proof, no git write, no network).
Date: 2026-11-17. Repository HEAD 4a24243c, perf/zk-batch-optimizations.
Scope read: `results/zk60_h132_batched_forward_20261116/` (REPORT.md, both metrics JSONs, bench_batch5_d80a.py,
run_batch5_guarded.py, metal_batched_llama8b.mm, the guard JSONs and logs, the two Rust logs), the last
"Antigravity (co-coordinator) 2026-11-17T08:42:00Z" entry in `ops/zkp-mvp/RECOVERY_COORDINATION.md` (string index
about 607,164), `results/zk60_resource_guard/history.jsonl`, D80a in `docs/zkmatrix-poc/ZK60_DECISIONS.md:131`, candidate E
in `docs/zkmatrix-poc/ZK60_NEXT_PROTOCOL_CANDIDATES.md:225`, the hypothesis texts under `research/zkp-efficiency/handoffs/`,
and the production kernel in `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs:4257-4475`.

## Verdict: STANDS WITH CORRECTIONS

The kernel timing itself is sound: same shader text as production, word-for-word exact against an independent CPU
integer reference, 32 alternating-order repeats, tight IQRs, one heavy job at a time. What does not stand is most of
the interpretation built on it:

1. H132 is reported as PASS. On the baseline the gate implies (the best K = 1 kernel, `sk4`) it FAILS: 0.887 at K = 4,
   0.832 at K = 8 against a 0.80 line. The metrics JSON itself says `passes_h132_kill_gate_lt_0_80: false` for `sk4`.
2. "D80a M1 UNBLOCKS candidate A" is not a measurement result. The kernel Victor's coordinator asked to be measured
   (the Stage 2 `metal_int_gemm.mm` kernel) was slower than production (0.56x GPU, 0.67x end to end). The pass is for a new kernel
   written in the same batch, against a 1.25x line that appears in no earlier source. The whole-block gain the measured
   kernel could give is about 1.01x to 1.02x, and fold kernels and the witness forward pass were not measured against
   production at all.
3. The Candidate B census ran on the script's fallback prompts (hand-written paragraphs, not WikiText-2), two prompts only,
   and measures only the "class W" planes that tick 6 left open. It does not settle candidate B.
4. The production figures from Rust come from a test binary built 2026-11-06, four commits older than the current
   `metal.rs`, and the report's Rust row mixes a best-of-30 with means that do not add up.

The most defensible speed-up figure for the new kernel against production is **1.40x** (host-i64 end to end, both sides
7 command buffers, same host pack): 13.475 ms to 9.625 ms, W16R2 T128, medians of 32. Details in answer 4.

---

## 1. Do the numbers match the JSON and the logs?

Most of the headline numbers match. Mismatches found, with sources:

| # | Where | Says | Source says | Effect |
|---|---|---|---|---|
| 1a | REPORT.md:71 (BASE, Stage 2, Scope B) | 18.382 ms (IQR 0.388), 0.670x E2E | `H132_H128_H127_METRICS.json` -> `m1_h128_h132_and_cand_b.d80a_m1_h128_production_block_comparison.base_8b_t128_f14336.scope_B_end_to_end_from_host_i64_with_copies_and_pack_ms.stage2_32x64_e2e_7cb.total_e2e_ms`: median 17.8595, IQR 0.3570; `speedup_summary_medians.stage2_32x64_7cb_e2e_over_prod_A4_7cb_e2e` = 0.69 | Medium. Stale number; the sign of the result is unchanged. |
| 1b | REPORT.md:72 (BASE, sk1, 1 cmdbuf, E2E) | 7.669 ms (0.130), 1.606x | `...fast_64x64_sk1_autoi8_e2e_1cb`: 7.5145 (IQR 0.1807); summary key `fast_sk1_autoi8_1cb_e2e_over_prod_A4_7cb_e2e` = 1.639 | Medium. Stale. |
| 1c | REPORT.md:73-74 (BASE, sk4 E2E IQRs) | IQR 0.222 and 0.175 | JSON: 0.5117 (7cb) and 0.5026 (1cb) | Low. Medians (8.976, 7.070) are right; the quoted spread is a third of the retained one. |
| 1d | REPORT.md:54 and coordination entry (Rust `[A4]` row) | "best of 30": 9.460 GPU, 13.160 cmdbuf wall, 14.400 E2E, pack 2.59, encode 0.33; entry writes "14.400 = 9.46 + 2.59 + 0.33 + 3.70 sync" | `rust_a4_30reps.log` line "device Simd2x4, weights and outputs mapped": 14.4 ms is "the seven products alone", which is the best of 30 (`witness_speed_tests.rs:493-499` takes the minimum); 9.46, 13.16, 2.59, 0.33 are the "per block of seven" averages over all calls (`witness_speed_tests.rs:535-539`). 9.46 + 2.59 + 0.33 + 3.70 = 16.08, not 14.40 | High (basis of the "vs Rust 1.875x"). A minimum and a mean of components are presented as one row. Details in answer 4. |
| 1e | `H132_H128_H127_METRICS.json` -> `m2_host_share_and_h127_rust_w16r2_8b.d80a_m2_single_8b_block_host_vs_gpu_share.note_6fork_d55_concurrency` | 126.4 ms / 37.5%, 135.9 ms / 32.8%, 210.6 ms / 62.5%, 278.2 ms / 67.2% | Same JSON's computed fields: 127.4 ms / 37.8%, 136.9 ms / 33.05%, 209.6 ms / 62.2%, 277.2 ms / 66.95% (and REPORT.md uses these) | Low. Stale text left in the receipt. |
| 1f | REPORT.md:86-90, K ratios "Best exact-int over float16" | K = 4 last-token 1.621x, K = 4 full 1.611x, K = 8 last 1.663x | JSON `best_exact_int_over_fp16_overhead_ratio`: 1.623, 1.648, 1.665 | Low. REPORT picks the faster of sk1 and sk4 per K; JSON picks sk4 for every K. No pass / fail changes. |
| 1g | Coordination entry (Candidate B) | "all int8 planes satisfy worst_layer_rms <= 24.43" | REPORT.md:22: "<= 40.85". The census JSON has int8 worst 24.43 (`s_score_i8`) and `p_prob_u12` 40.85 | Note. Consistent only if `p_prob` is excluded; see answer 7 for why `p_prob` matters. |
| 1h | REPORT.md:19, "Host CPU ~71%" for the 477 ms m4_trained block | not in any JSON | Derived: (477.0 - 136.9) / 477.0 = 71.3%, which subtracts the mapped-witness GPU share from an unmapped-witness total | Low. Mixed bases. |

Checked and matching: every Table 3A row (medians, IQRs, ratios, including 1.553x, 1.556x, 1.834x, 1.841x, 1.400x, 1.754x, 2.090x,
1.279x); Table 3B rows other than those above; the H132 table medians for all K; 6,029,312 = 128 x 47,104 and 5,505,024 = 128 x 43,008
output words; 16,416,768 = 128 x 128,256 logits; the M2 sums (GPU 18 + 17 + 78 + 1.2 + 13.2 = 127.4; host
33 + 40 + 4 + 23 + 24 + 68.8 + 16.8 = 209.6; 23 slot rows sum to 148 ms; the 38 phases sum to 337 ms); the census table against
`batch5_m1_h128_h132_metrics.json`; guard run ids, walls (309.05 s, 38.77 s), peaks (18.31 GiB, 3.74 GiB, 12,584 MiB).

Rounding that changes a pass / fail: none of the above. One related item: the 1.25x gate in REPORT.md:18 is passed by
every route that was kept; the only value near the line is the int16-only end-to-end comparison done at equal structure
(answer 4, item 4d), which is 1.03x.

## 2. Exactness: what was compared, and against what

- **56 adversarial checks** (`bench_batch5_d80a.py:359-410`): 4 patterns x 2 weight layouts (`in_out` 0 and 1) x 7 routes = 56,
  shape [65, 2200, 70]; each of the 7 projection outputs is compared with `np.array_equal` against a CPU numpy `int64` matmul
  (256-column chunks). That reference is independent of the GPU code. The REPORT's description ("kernel variant x in_out x is_i8 x SPLIT_K x
  boundary values") is looser than the code: is_i8 is fixed per pattern and SPLIT_K comes from the route. The int8 path sees only one
  pattern (all -128 x all -128, the largest slab sum, exactly 2^23 per 512 terms); the int16 path sees +32767, -32768 and a random mix.
  All 7 projections get the same data in each call. Low.
- **W16R2 and BASE block words** (`bench_batch5_d80a.py:499-545`): CPU reference is float64 BLAS in 1,024-column chunks cast to
  int64. This is exact by the bound in the docstring (each chunk below 2^32, far below 2^53), so it is an integer reference in effect,
  but the docstring's "100% bit-identical to scalar int64" is asserted, not tested in this file. Compared: all 7 outputs, for routes 0 to 6 in the resident path
  (one-command-buffer mode only, `scb = 0`) and for E2E routes `(2,1), (0,1), (5,1), (6,1), (6,0)` only (line 532).
  **Not compared: the E2E path of route 1 (`fast_64x64_sk1`)**, which is timed in Scope B (`fast_64x64_sk1_autoi8_e2e_7cb` and `_1cb`),
  and the 7-command-buffer resident mode. The kernels are the same as in the verified resident route, so the risk is the host pack
  and layout code only. Low to Medium.
- **Verification is done once, before timing, and is not repeated inside the timed loop.** The timed loops pass `None` for outputs
  (Scope A, line 566-572) or write to a scratch plane that is never read back (Scope B). The same compiled dylib and the same
  input buffers are used, and the kernels are deterministic, so this is acceptable, but "evaluated inside the harness for the kernels
  that were timed" is true only in the weaker sense of same binary, same data, earlier in the same process.
- **`max_abs_diff == 0` is an assert, not a recorded measurement.** `"max_abs_diff_all_routes_and_scopes": 0` (line 643),
  `"gate1_cpu_vs_resident_gpu_exact"` (line 990) and the adversarial return value are hard-coded zeros written after `assert` /
  `AssertionError` checks. A failure would have aborted the run (no `python -O`), so this is sound, but the JSON is not independent evidence.
- **Gate 1 (32 layers + logits vs CPU)** (lines 835-843): one prompt only (`prompts_8[0]`), kernel modes 0, 1, 5, comparing the final hidden state
  `x` (128 x 4096) and all 16,416,768 logits against `run_forward` from the Stage 2 Python model. Independent implementation,
  shared constants and loader; per-layer intermediate values are not compared.
- **Gate 2 (batched vs standalone)** (lines 845-862): GPU against GPU. K = 2, 4, 8 batched outputs for 3 kernel modes are compared with 8
  standalone runs made with `kernel_mode = 5` (`sk4`). So seven of the 8 prompts have no CPU comparison at all, and the stage2 and sk1
  batched routes are checked against an `sk4` standalone run, not against themselves.
- **The headline H132 path was not the one verified.** Timed numbers use `last_token_only_head = True` (the 155.70 ms headline).
  Gates 1 and 2 use `last_token_only_head = False` with the full head. The gather-last kernel and the head GEMM at M = K rows
  were never compared with any reference. Medium.
- **The forward is the Stage 2 Python model's integer semantics, not the prover's `build_accuracy`.** The original H132 text asks for
  "digests equal" on the existing builder; nothing here compares with `build_accuracy`. See answer 6.

## 3. Timing method

- **Interleaving (M1):** each iteration runs all 11 Scope A arms (or 6 Scope B arms) in list order on even iterations and in reverse order
  on odd ones (`bench_batch5_d80a.py:564-572, 591-606`). That is alternating-order interleaving, not strict ABBA pairs, but it does cancel linear drift. Three untimed warm-up passes first.
  n = 32 for every M1 arm (JSON `n: 32`), median plus p25 / p75 IQR computed by index (`stats_of`, lines 112-127). Scope A IQRs are tiny (0.01 to 0.03 ms on GPU time; 0.03 to 0.25 ms on wall).
- **"GPU ms"** is the command buffer's `GPUEndTime - GPUStartTime`, summed over the 7 buffers in the 7-buffer mode (`metal_batched_llama8b.mm:1600, 1610`).
  **"Cmdbuf wall"** is host `steady_clock` from before encoding to after `waitUntilCompleted` (line 1578 to 1613), so it includes encode, commit, scheduling and
  the wait; for 7 buffers it includes 7 round trips (about 1.5 to 1.8 ms more than one buffer: A4 10.579 vs 9.057). **"Scope B E2E"** adds the NEON range check and pack, the page views, encoding, and a copy-out if the
  output view is not direct.
- **H132 timing is not interleaved the same way.** The modes run in blocks (all `sk1` passes, then all `sk4`, then `stage2`, then the fp16 baseline,
  lines 876-940), only the order of K alternates inside a pass, and n differs: `sk1` 16 passes, `sk4` 8, `stage2` 8, fp16 16, and the full-head
  runs 8. The docstring says "16 interleaved ABBA repeats per K". Cross-mode ratios (sk4 against fp16, sk1 against sk4) therefore compare numbers taken minutes apart.
  The K = 1 full-head wall IQR is 5.12 ms (sk4) and 3.73 ms (sk1) on about 160 to 185 ms. Medium.
- **Quiet GPU.** `quiet_gpu_pre` and `quiet_gpu_post` come from the script's own `pgrep -fl` for four names (`ds4-bench`, `zk60_classify`,
  `zk60_trained_block`, `hashline`; `bench_batch5_d80a.py:130-138`), run at start and end. Nothing samples GPU utilisation during the run, and the guard JSON
  carries no quietness field (only `gpu_drain_failed: false`, `gpu_telemetry_lost: false`). The M2 leaf has no quiet check at all.
- **Anything else heavy?** From `results/zk60_resource_guard/history.jsonl`: the dylib build `fabdef37e4bd` ended 07:50:18Z, M1 `a09f5097e4af` ran about 07:50:30 to 07:55:39Z with
  `waited_s 0.1` and the heavy lock free; `astra-full-image-replay-replay` (`cargo test -j 2`, class cpu, `cd9117f17371`) had been waiting 303.8 s
  and ran 07:55:41 to 07:57:19Z, i.e. after M1 and immediately before M2 (M2 started about 07:57:22Z after `waited_s 91.4`). So no guarded heavy job overlapped M1 or M2. Unguarded
  light work cannot be excluded from the retained files. The M2 prove timings began about 3 s after a 98 s CPU-heavy cargo test ended.
- **Command-buffer count** enters the headline: production issues one command buffer per product (`metal.rs:4840-4851`, 7 per block), the
  7-buffer arms reproduce that, and the 1-buffer arms are a structural change that production could also make. A4 appears in Scope A in both modes, but in Scope B **only with 7 buffers**.

## 4. Like for like

**Same shader text.** I diffed the production `WPROD_SRC` (`metal.rs:4258-4475`) against the harness copy (`metal_batched_llama8b.mm`, from `struct WProdArgs` to the end
of `k_wprod_int`). The only differences are removed comments and the extra includes; the kernels `k_wprod_sg_2x4`, `k_wprod_sg_4x2` and `k_wprod_int` are
character-identical. Compile options: fast math off in both; the harness pins `MTLLanguageVersion3_1` (line 1405), production uses the default (`metal.rs:4576-4579`).
Dispatch (64 x 64 tiles, 256 threads, one encoder per product in 7-buffer mode) matches `wprod_run`. Verbatim, modulo the language version. Note.

**Same shapes and data?** Partly.
- The harness "W16R2" arm uses `f_pad = 16,384` (zero padding of the three FFN weights and of `h`). The Rust A4 test's "seven products alone" and the "per block of seven" split use
  `hidden = 14,336` (27.92 G MACs in the log equals 128 x 218.1 M; 16,384 would give 31.1 G; `witness_speed_tests.rs` shapes use `sh.hidden`,
  `shape.rs:302` gives hidden 14,336). So the Rust row in REPORT.md:54 belongs next to the **BASE** table (f = 14,336), not the W16R2 f_pad table. (The real `build_accuracy` multiplies at `f_pad`, `witness_accuracy.rs:976, 989`, so both shapes are legitimate; the comparison must be matched.) Medium.
- Data: the harness uses layer-0 trained activations (zero-padded) and the real layer-0 weights; the Rust test uses random full-range values (+-32,767 activations, +-127 weights). A4 is data-independent in its instructions, but GPU clock and power can depend on data.
- **The harness `[A4]` is faster than production's own log at the same shape.** BASE: harness A4 GPU 7.914 ms, E2E 12.315 ms; Rust log GPU 9.46 ms (mean), products 14.4 ms (best of 30), components 16.2 ms (mean). W16R2: 8.807 / 13.475 vs the same Rust figures.
  The cause is not established (candidates: data, the single-thread NEON pack 0.73 ms against the production Rayon pack 2.59 ms, concurrent Rayon load in the Rust run, a different binary). The practical consequence is that the "production" baseline in Scope B already includes a faster pack than production has. Medium.
- **The Rust test binary is stale.** The guard command for M2 runs `target/release/deps/hashline-a90b6cf7715dc2a7`, built 2026-11-06 08:58. `metal.rs` has four later commits (A27 round 2, A28 milestones 1 to 3, last 2026-11-09 15:47, including "the witness products on per-thread queues" and "the pruned NTT head as its own kernel instance"),
  and `witness_speed_tests.rs` was changed 2026-11-07. A newer test binary `hashline-299f612456456fca` (2026-11-10) exists in the same `deps` directory. The M2 profile, the commit GPU timers and the Rust `[A4]` log may describe a prover older than HEAD. I cannot tell from the files whether the feature set differs. Medium.

**Which ratios are equal-condition, which are not.**

| Item | Ratio | Condition | Like for like? |
|---|---|---|---|
| 4a | 1.835x GPU: 8.781 to 4.785 ms (W16R2, 1 cmdbuf both) ; BASE 7.886 to 4.307 = 1.831x | Scope A, resident, n = 32, GPU command-buffer time | Yes in structure, and data-independent for A4. But it includes int8 single-limb for 6 of 7 projections (needs activations to fit int8), split-K, and fewer barriers; no ablation separates them. |
| 4b | 1.841x "GPU" in REPORT.md:63 (8.807 7cb vs 4.785 1cb) | GPU time only, so the buffer count barely matters (8.807 vs 8.781) | Effectively yes. |
| 4c | 1.400x E2E: 13.475 to 9.625 ms (sk4, 7 cmdbuf both) | Scope B, same NEON pack, same page views, n = 32 | **Yes. The most defensible drop-in figure.** sk1 equivalent: 1.307x. |
| 4d | 1.754x E2E (13.475 7cb vs 7.681 1cb), 2.090x wall (10.579 7cb vs 5.062 1cb), 1.616x | A4 only has a 7-buffer Scope B arm | **No.** These mix a 7-to-1 command-buffer change with the kernel gain. From the Scope A pair (A4 1cb wall 9.057 vs 10.579), A4 at 1 buffer would be about 11.95 ms E2E (inferred, not measured), giving about 1.56x against 7.681. |
| 4e | 1.875x "vs Rust A4": 14.4 / 7.681 | Min of 30 (Rust) against a median of 32 (harness), different pack, 1 vs 7 buffers, Rust row shape f = 14,336 against an f_pad = 16,384 harness arm | **No.** |
| 4f | 1.279x "pure int16 (R13)": 8.807 / 6.885 | `sk4`, 1 cmdbuf, GPU time; the harness feeds trained inputs but the `i16` kernel has no data-dependent skip (the comment in the .mm header about "skipping chi when hi == 0" is stale; the kernels at lines 421-660 have none) | GPU-only yes. But the arbitrary-int16 Scope B arms show: `sk1` i16 7cb E2E 13.145 vs A4 13.494 = **1.027x**; `sk1` i16 GPU 8.255 vs 8.818 = **1.07x**; `sk4` i16 1cb E2E 10.060 vs 13.494 = 1.34x (mixed buffer count). The zero-spill 64x64 kernel by itself is a few percent faster than A4; the gain comes from the int8 route, split-K (M = 128 is only 2 M tiles) and one buffer. |

**Rust production figure against the harness.** From `rust_a4_30reps.log`, Simd2x4 mapped: whole witness 0.0771 s, seven products alone 0.0144 s (best of 30), per block of seven: pack 2.59, weights 0.09, output plane + encode 0.33,
command buffer 13.16 of which GPU 9.46 ms (these are means, summing to 16.17 ms). The harness A4 Scope B mean-like components are pack 0.728, encode 0.103, buffers 12.58 of which GPU 8.81 (sum 13.475). The 7-buffer
wait overhead agrees within 5% (harness 3.77 ms, Rust 3.70), which supports the harness being a faithful stand-in for the buffer structure.

**Single most defensible figure.** 1.40x (13.475 to 9.625 ms), i.e. a drop-in `k_wprod_fast_i8/i16_2x4` with split-K = 4, 7 command buffers as production does, same NEON pack on both sides,
W16R2 T128 shape (f_pad = 16,384), layer-0 trained activations with 6 of 7 inputs fitting int8, M = 128, medians of 32 interleaved repeats (IQR 0.13 ms and 0.30 ms), word-for-word equal to CPU integer arithmetic.
It becomes 1.37x on the BASE f = 14,336 shape (12.315 to 8.976). As a GPU-time figure for the same condition, 1.83x to 1.84x. For arbitrary int16 activations it is about 1.03x (sk1) at equal structure, and the int8 route is a data-range property of the Stage 2 model: the prover's layout
declares the norm outputs `Y`, `YM` as int16 words (tick 6, class W), while the model's own values fit int8.

## 5. Scope against D80a

D80a (`ZK60_DECISIONS.md:131`) waits "until the exact integer GPU work (candidate E: byte-preserving kernels for the witness forward pass and the folds, no protocol change, no new proofs) has been measured against the production kernels".

What Batch 5 measured against production:
- **The witness weight-product GEMM** (7 projections): yes, against production `k_wprod_sg_2x4` (answer 4).
- **A resident whole-forward** (32 layers + head, 155.70 ms at K = 1): measured against **nothing from production**. There is no comparison with `build_accuracy`, the forward produces only the final hidden state and the logits (not the 19 A planes, remainders, limbs
  and histograms that the prover commits), and it follows the Stage 2 Python integer model, not the prover's witness. The only comparison is with a float16 pipeline that omits softmax, RoPE, masking and the embedding gather, and uses placeholder weights (a ring of 6 layers, mostly zero, `metal_batched_llama8b.mm:1996-2003, 2068`).
- **The folds**: not measured. There is no fold kernel in `metal_batched_llama8b.mm` or `bench_batch5_d80a.py`. The production "store fold with pads" lines (5.3 + 5.9 ms) were only read from the Rust log.
- The measurement requested at 2026-11-16T19:30Z (coordination file, position ~523,284) was "the exact chunked kernel in metal_int_gemm.mm against the production kernel ... at least 30 repeats on a quiet GPU". That kernel
  is Stage 2's 32x64. It is slower: 15.738 vs 8.807 ms GPU (0.560x), 20.233 vs 13.475 ms E2E (0.666x). The answer to the question that was asked is "slower than production". The "PASS" belongs to a new kernel.
  I found no earlier source for the "H128 >= 1.25x" line (H128's own text is "over 9 ms per 8B block on the 5090" or a digest mismatch against `build_accuracy`, `research/zkp-efficiency/handoffs/20261116-claude-cycle-literature-scan.md`, section H128).

**M2 profile (host / GPU share).**
- It is one warm pass, n = 1, not a repeated measurement. `rust_m4_8b_pbtiming.log` holds a cold pass (0.510 s) and two warm passes (0.341 s, 0.337 s); the report uses the last (log line 686-687). The log header says "diagnostics on a shared box, not a receipt".
  Timer resolution is 1 ms per phase (three decimals in seconds), so a 9-slot sum of 1 ms entries carries up to about +-4.5 ms of rounding.
- All timers are the Rust prover's own log lines (`PB-TIMING`, `PB-SLOTSTEP`, `[ZK60-METAL]`), parsed by regex in `run_batch5_guarded.py:parse_m2_host_share_and_h127`. The host share is computed by subtraction
  (`prove_true_host_s = prove_wall - prove_true_gpu_s`, line 160). "Host upper Merkle" 20 ms and 21 ms are the remainder of `commit` wall after the prover's own GPU total and setup, not separately measured.
- "True GPU" 127.4 ms includes the 78 ms "device sumcheck rounds", which is the prover's wall for the device rounds (dispatch and sync included), not a GPU-busy time. It cannot be pure GPU busy time: 32 x 136.9 ms = 4.38 s is larger than the 3.94 s per request the same entry quotes for the six-fork stream,
  while the JSON note itself cites 53% to 59% GPU busy in earlier runs (about 2.1 to 2.3 s). So 33% to 38% GPU is an upper bound and the host share (62% to 67%) a lower bound. Medium.
- "414.1 ms" is a composite of two different tests: the witness comes from the A4 test (synthetic admissible input, mapped, best of 30) and the prove core from the m4_trained test (trained fixture, one pass). Neither run measured a block end to end at 414.1 ms; the trained test's own total is 477 ms with an unmapped CPU-side witness of 140 ms. Medium.

**Share of one block's wall time that the measured kernel touches, and the whole-block gain if nothing else changes** (Amdahl, baseline 414.1 ms as the report defines it):

| Replaced time | New time | Saved | Whole-block gain |
|---|---|---|---|
| A4 harness E2E 13.475 ms (3.25% of 414.1) | sk4 7 cmdbuf 9.625 ms | 3.85 ms (0.93%) | 1.009x |
| same | sk4 1 cmdbuf 7.681 ms | 5.79 ms (1.40%) | 1.014x |
| Rust best-of-30 products 14.4 ms (3.48%) | sk4 1 cmdbuf 7.681 ms | 6.72 ms (1.62%) | 1.017x |
| Rust mean components 16.17 ms (3.9%) | sk4 1 cmdbuf 7.681 ms | 8.49 ms (2.05%) | 1.021x |

The GPU-only part (9.46 ms, 2.3% of the block) goes to about 4.8 ms, 3.4% of the block's "GPU" share. The whole witness is 77.1 ms (18.6% of 414.1), of which the host non-product part is 67.6 ms; that remainder (RMSNorm, RoPE, SwiGLU, pack, sync) is the only witness-side lever with real size and is exactly what Batch 5 did not
measure against production. Even deleting the entire witness would bound the block at 414.1 / 337.0 = 1.23x. Against the D80a gate: one of three parts (product kernel) measured, a bounded gain of about 1.01x to 1.02x on one block, folds and the witness forward pass unmeasured against production.

## 6. H127, H128, H132 against their definitions as first written

**H128** (`handoffs/20261116-claude-cycle-literature-scan.md`, section H128): "Kill if a fused int8-limb forward for one 8B block ... takes over 9 ms on the 5090, or fails bit-exact digests against `build_accuracy` at W16, W16R2 and R13 shapes. Also kill if the builder remainder (about 0.16 s per block at 32 threads, not matmul) is not removed by the same change."
- The 9 ms test needs a CUDA GPU and cannot be run on the Mac. On the Mac production `[A4]` is already under 9 ms (8.8 ms GPU), so the line does not discriminate here.
- Digests against `build_accuracy`: not tested (reference is numpy, only W16R2 f_pad and BASE shapes; "R13" is random int16 data). Builder remainder: untouched (M2 shows 67.6 ms per block of host witness work). The "1.25x" line was introduced by the report.
- Verdict: **not decided by this batch.** The kernel part is a real, exact, 1.4x (GPU 1.8x) improvement on the Mac; the original gate is untested.

**H127** (cycle 1 in the literature scan: "kill if the share is under 5% of block proof time"; cycle 2 in `20261116-claude-cycle2-flashprove-batching.md` section 6, recommendation 1: "(b) work that depends on request-independent challenges only if challenges were shared (LogUp pair-inverse and helper tables) ... kill M2 and H127 if (b) is under 10% of one request's proof time"):
- Strict bucket in the report: 3 table helpers 1 ms + `tables: build` for slots 05, 06, 07, 10, 11, 12, 13, 19, 20 (8 ms) = 9 ms, 2.67% of the 337 ms prove core, 2.17% of 414.1. I recomputed the sums from the log: 8 ms and 23 ms are right at 1 ms resolution.
- The slot choice is a judgement: the cycle 1 claim names "pair-inverse tables for the five domain zero-checks, helper table", which are slots 14 to 18 (1 + 1 + 0 + 0 + 2 ms) plus slot 19 (1 ms); the report's strict bucket instead picks the matmul slots 05 to 07 and 10 to 13 and omits 14 to 18. The 9-ms figure carries up to about +-4.5 ms of rounding.
- The report's "generous bound" (all 23 slots + 3 helpers = 24 ms, 7.12% / 5.80%) is not the generous reading. Cycle 2's wording includes "LogUp pair-inverse": the log has "H: LogUp helper inverses (six lookup domains)" 7 ms and "H: exp + activation helper inverses" 12 ms. Adding them gives 1 + 7 + 12 + 23 = 43 ms = **12.8%** of the prove core and 10.4% of 414.1, which is over 10%. Those inverses are over witness values and so are probably request-dependent, which is the reason to exclude them, but the choice belongs to the author of the gate, not to the measurer.
- Against the cycle 1 gate (5% of block time), the report's own generous figure (5.80% to 7.12%) does not kill; only the strict figure does.
- Verdict: **killed under the cycle 2 10% line on the report's two buckets; not robust**: it depends on a bucket definition and a 1 ms resolution on a single warm pass. Astra's earlier 3.3% to 6.2% agrees with that range.

**H132** (cycle 2 recommendation 2: "Test: K = 4 per-request build wall at most 0.8x K = 1, digests equal ... Do it after H128's 9 ms test, because a fast GPU forward may already fill the device"; STATE.md:211: "kill if K = 4 per-request wall above 0.8x K = 1"):
- The gate does not name a kernel variant. The report divides K = 4 `sk1` (138.12 ms) by K = 1 `sk1` (179.35 ms) = 0.7701 and calls it a pass. But `sk1` at K = 1 is the handicapped variant (2 M tiles on 80 cores; the report says so); the deployable K = 1 is `sk4`, 155.70 ms.
- On that baseline (medians, last-token head): K = 4 best 138.12 / 155.696 = **0.887** (sk4 K = 4: 138.294 / 155.696 = 0.888); K = 8 best 129.51 / 155.696 = **0.832**. Full-token head: K = 4 147.245 / 163.125 = **0.903**, K = 8 139.346 / 163.125 = 0.854. All above 0.80.
  The JSON agrees: `h132_batched_32layer_llama8b_scaling.fast_64x64_sk4.passes_h132_kill_gate_lt_0_80 = false` (k4 over k1 0.8882, k8 over k1 0.8328; full head 0.9236 and 0.8542), while `fast_64x64_sk1` and `stage2_32x64` give true. The report and the coordination entry quote only the true one.
  `stage2_32x64` also "passes" at 0.7929 on its own baseline, but its K = 1 time is 542.9 ms, which shows how much the baseline choice moves the ratio.
- The original text predicted this ("a fast GPU forward may already fill the device"); the report's own "architectural insight" says the same.
- Other departures from the definition: the measured object is a resident GPU forward in one command buffer, not "the existing builder", with no digest comparison to `build_accuracy`; n is 8 to 16, not interleaved across modes; and "tok/s" (822, 927, 988) are forward-pass rows per second, not proved tokens per second.
- Verdict: **H132 FAILS its gate (0.887 at K = 4)**: batching saves about 11% of a 156 ms forward at K = 4, which is about 1% of a 13 s request, and the forward is not the witness.

**Float16 comparison.** "Exact integer is only 1.39x to 1.42x slower than native float16" compares a complete integer pipeline with an incomplete float pipeline: the fp16 path has no embedding gather, RoPE, softmax or mask, no output copy, and uses 6 reused placeholder layers (`metal_batched_llama8b.mm:1996-2003, 2068-2150`; 1 of every 64 elements nonzero).
It is a loose lower bound on a float pipeline, not a like-for-like overhead; the integer wall also includes the logits copy-out (131 MB at the full head). This comparison is new in Batch 5 and is not part of any gate.

## 7. Per-plane RMS census (candidate B)

- **Script and data.** `bench_batch5_d80a.py:682-787` (`compute_candidate_b_trained_plane_rms`); results in `batch5_m1_h128_h132_metrics.json` -> `d80_candidate_b_trained_llama8b_plane_rms` (same content under
  `m1_h128_h132_and_cand_b` in `H132_H128_H127_METRICS.json`). Model: the Llama-3-8B integer export `results/zk60_astra_20261026/a7_a8_versioned_exports_20261104/llama3-8b/export` run through the Stage 2 working model
  (`results/zk60_llama3_8b_feedforward_20261115/llama8b_working_model.py`), with `cpu_gemm_nk` replaced by float64 BLAS.
- **Prompts: the fallback set, not WikiText-2.** The script looks for `.../zk60_fidelity_parity_20261019/data/wikitext2/wiki.test.tokens` (line 807) and otherwise builds prompts from eight hand-written paragraphs
  (lines 816-826), each followed by " Reference section N: " and the paragraph reversed character by character, repeated until 127 tokens. That directory holds only `test.parquet` and `validation.parquet`; I found no `wiki.test.tokens` in `results/zk60_fidelity_parity_20261019`. So the fallback ran, without any message.
  The docstrings still say "real WikiText-2" and "8 prompts, 1,024 tokens". The census used the first two prompts (line 715), 256 tokens, 32 layers (the Gate 1, Gate 2 and H132 data also use these prompts, and layer-0 activations for M1 come from prompt 0).
  Part of each prompt is reversed-character text. I did not tokenise to count the share. Medium (High for the claim "trained 32-layer ... census").
- **RMS definition.** For each plane and layer: `sqrt(mean(x^2))` over all 256 tokens x all channels of that layer, not centred, not per token or per cell row; "worst layer" is the maximum over 32 layers; "global" pools all layers. Tick 6's cap (about 453 at k = 4,096, 342 at k = 7,168, from `handoffs/20261117-claude-tick6-cell-width.md` section 2)
  is about the RMS of a row of k cell values and depends on k. The census applies a flat 450 to every plane, including the F-domain planes (u_up, act_silu, h_swiglu, g_gate) whose k after splitting is 7,168 (cap 342). A layer-pooled RMS can sit well below the worst row's RMS (massive-activation tokens such as the BOS position). Medium.
- **Do the numbers support "all 8 int16 planes need two byte cells"?** By range, yes: every one of the eight has max |v| above 127 (smallest 705). By the RMS cap, six exceed it (u_up 1,875.7; act_silu 1,051.6; z_down 646.1; x2_out 640.9; x1_res 574.4; x_in 552.1; vs 450 or 342), two do not:
  **`ao_proj_i16`** (global RMS 37.88, worst layer 132.07, max 705) and **`h_swiglu_i16`** (global RMS 23.86, worst layer 39.66, max 7,778). For these two the RMS says one byte would be fine statistically; they need two cells only because rare tails exceed a byte (the script's own rule: `max_abs > 255`). That is a range statement; a tail count (what fraction of words exceed 127 or 255) would show whether a mostly-zero second cell is
  cheap. Tick 6's own kill rule for class W is "more than 150 of 672 W rows exceed the cap": x_in, x1_res, z_down, x2_out are 32 rows each and u_up, act_silu 128 each (domain row counts from tick 6), i.e. 384 rows over the cap, so the kill triggers and "C, M and W split" (0.63 to 0.67 of today's A rows) is the scenario that applies.
- **What it does not settle.** Tick 6 found the larger open items in classes C (the 16-bit low limbs of remainders, 480 rows, 21.3%) and M (9 to 16 bit remainders, 272 rows). The census measures none of the remainder or limb planes. It also measures the model's own intermediates (19 planes), not the prover's committed planes. It records `y_a` and `y_m` as int8 (RMS 5.6 and 3.4) where tick 6 lists the corresponding `Y` and `YM` as int16 words. And `p_prob` is labelled `u12 ([0, 4096])` with a measured max of 512 (more than a byte).
  So "Settles Candidate B open item" is too strong: it adds data for the W-class planes (and it supports the pessimistic scenario for them), nothing for C and M.

## 8. Hygiene for a public repository

- `git status --short hashline/ zkp-core/ src/` prints nothing: clean. The prover under test lives at `ops/zkp-mvp/gpu-metal/hashline/` (not the repository-root `hashline/`);
  `git status --short ops/zkp-mvp/gpu-metal/hashline/` is also empty. "hashline untouched" is true. The working tree is otherwise dirty (documents, Lean, apps), unrelated to this batch.
- The whole result directory is untracked (`?? results/zk60_h132_batched_forward_20261116/`, 736 KB). Contents:
  - `libmetal_batched_llama8b.dylib` (139,776 bytes): a compiled binary, **not gitignored** (`git check-ignore` returns nothing). A directory-level `git add` would commit it. Do not commit it; the retained `.mm` source plus the guard history entry (`clang++ -O3 -fno-fast-math -std=c++17 -fobjc-arc -shared`) rebuild it, but the build command is not in the directory.
    `strings` finds no home paths in it.
  - `__pycache__/` is gitignored (`.gitignore:31`) and holds two `.pyc` files (about 100 KB).
  - No model weights, activation dumps, credentials, salts or openings found (grep of logs and guard JSONs for key / secret / salt / token / password: only the word "openings" in prover phase names). Largest text files: `H132_H128_H127_METRICS.json` 82 KB, `rust_m4_8b_pbtiming.log` 79 KB, `batch5_m1_h128_h132_metrics.json` 63 KB (its content is duplicated inside the combined JSON).
  - Absolute paths with the local home directory and the venv path appear in the guard JSONs and scripts; the repository already contains such paths widely. Low.
  - The scripts read inputs from outside the directory (export, checkpoint, venv under `/Users/victorrielly/zk60-artifacts`); reproduction needs those.
- Suggested commit set: the `.mm`, the two `.py` files, REPORT.md (after the corrections above), the two metrics JSONs and logs; exclude the `.dylib`.

---

## Findings list (for the coordinator)

| ID | Level | Finding |
|---|---|---|
| F1 | High | H132 passes only against the handicapped `sk1` K = 1 baseline. Against the best K = 1 (`sk4`) the ratio is 0.887 (K = 4) and 0.832 (K = 8); the JSON's own `sk4` flag is false. Verdict should be FAIL. |
| F2 | High | "D80a M1 unblocks candidate A" overreaches: the kernel asked for (Stage 2 32x64) is slower than production (0.56x / 0.67x); the pass is for a new kernel against a 1.25x line with no earlier source; fold kernels and the witness forward pass vs production are unmeasured; the whole-block gain from the measured kernel is 1.009x to 1.02x. D80a's gate is Victor's ruling, not a speed-up threshold. |
| F3 | High | Candidate B census: fallback synthetic prompts (not WikiText-2), 2 prompts, layer-pooled RMS against a flat 450, nothing on remainder / limb classes; "settles" is too strong. |
| F4 | High | Rust `[A4]` row mixes best-of-30 (14.4) with means (9.46, 13.16, 2.59, 0.33) that sum to 16.08; shape is f = 14,336 but is shown against the f_pad = 16,384 arm; "1.875x vs Rust" compares a minimum to a median with different buffer counts. |
| F5 | Medium | Headline "1.754x E2E" and "2.090x wall" compare a 7-buffer A4 with a 1-buffer new kernel; A4 has no 1-buffer Scope B arm. Like-for-like is 1.40x (sk4) / 1.307x (sk1). |
| F6 | Medium | Arbitrary-int16 case is about 1.03x (sk1, 7 buffers, E2E) and 1.07x (GPU): the zero-spill 64x64 kernel alone is a few percent; the gain comes from the int8 route (data range property), split-K and fewer buffers. No ablation. |
| F7 | Medium | Rust test binary dated 2026-11-06 predates four `metal.rs` commits and a newer test binary exists; the M2 profile and Rust `[A4]` may not be HEAD. Harness `[A4]` runs 7% (W16R2) to 16% (BASE GPU) faster than the Rust log's GPU mean at the same shape, unexplained. |
| F8 | Medium | M2: n = 1 warm pass at 1 ms resolution; host share by subtraction; "true GPU" is an upper bound (32 x 136.9 ms = 4.38 s exceeds the 3.94 s stream request time); 414.1 ms is a composite of two tests. H127's 9 ms strict bucket is a slot judgement (omits the five domain zero-check slots) with +-4.5 ms rounding; a broader reading of (b) gives 12.8%. |
| F9 | Medium | Gate 1 compares one prompt to CPU; Gate 2 compares GPU to GPU (with `sk4` as the standalone reference); the headline last-token-head path was never compared; E2E route 1 not verified; H132 timing is not interleaved across modes and n = 8 to 16. |
| F10 | Medium | Stale numbers in REPORT.md Table 3B (items 1a to 1c) and in the JSON `note_6fork_d55_concurrency` (1e). |
| F11 | Low | fp16 baseline omits softmax, RoPE, embedding and uses placeholder weights; "tok/s" are forward rows per second; mechanism claims ("0 register spills", "32-way bank conflicts", "air-lld spill slots") have no compiler or profiler evidence in the directory. |
| F12 | Low | Do not commit the `.dylib`; it is not gitignored. |
| F13 | Note | Same shader text as production verified by diff; adversarial reference independent; ABBA-style alternation and n = 32 for M1; no heavy guarded job overlapped M1 or M2; `hashline` sources untouched. |

## What I did not check

- I did not rebuild, run or profile anything; the dylib is not shown to be built from the retained `.mm`, and I did not inspect the Rust test binary's build inputs or the 2026-11-10 binary.
- I did not read the non-GEMM Metal kernels (norm, RoPE, attention, SwiGLU, requant) for exactness; I relied on Gate 1 for prompt 0 only.
- I did not verify that the float64-BLAS `cpu_gemm_nk` matches scalar `int64` on the real inputs, nor read the Stage 2 model's `run_forward` or `i_norm_2d`.
- I did not tokenise the fallback prompts (reversed-text share unknown), and I searched only `results/zk60_fidelity_parity_20261019` for `wiki.test.tokens`.
- I did not check that the production kernel text in the 2026-11-06 binary equals today's `WPROD_SRC`; I only know the files changed after it.
- I did not verify the 3.94 s / 32.4 tok/s D55 figure, the 13.25 s serial figure's source, or Astra's 3.3% to 6.2% H127 estimate.
- I did not check whether the six int8-fitting activations hold in the prover's actual W16R2 witness (tick 6 types `Y` and `YM` as int16).
- I did not read the Lean L65 part of the coordination entry.
- I did not quantify thermal or power effects of data (zero padding, trained vs random activations) on the A4 baseline.
