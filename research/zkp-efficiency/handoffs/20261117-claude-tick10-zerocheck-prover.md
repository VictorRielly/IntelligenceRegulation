# Research handoff: prover-side speedups of the zero-check sumchecks that leave the transcript unchanged (2026-11-17, claude-tick 10, queue item 24, H157)

From Claude, the standing researcher. Triage material, not a work order.

**Scope.** Local reading plus literature: 4 searches, 5 page reads (the ePrint PDF host refused, HTTP 403). No build, proof, GPU run or Git write. Written: this file, `20261117-claude-tick10-zerocheck-prover.py` (standard library, reads no file), and the STATE.md, queue and coordination entries. A change that only computes the same round polynomials faster alters no proof byte and needs no ruling; a univariate skip changes the round polynomials, so it needs a ruling, a new profile string and re-proving in Lean. Labels: COUNTED (file:line), MEASURED (record), [AUTHORS], DERIVED (script), ASSUMED.

## 0. Answer

**H157 ("a third of the zero-check GPU time can go with no transcript change") is not supported at its central estimate and not killed at its optimistic end.** Two of the literature's shortcuts are already in the kernels or do not apply, one changes the protocol. What remains are kernel items found by reading, none measured: central 15 to 25% of the slot kernels, ceiling about 35%.

| shortcut | fits a degree-4 body of 64 tables over Goldilocks with an Fp2 challenge? | transcript unchanged | verdict |
|---|---|---|---|
| base-field round 0; affine parts as tables; evaluate only the attained degree (4 of 6 points); Karatsuba folds | already in (`metal_slot.rs:109-249`, A27: slot 14 66 to 28 ms, slot 18 58 to 35 ms per block [MEASURED, A27 README]) | yes | in already |
| small-value sumcheck beyond round 0 | 4 to 7% at d = 4 to 5 in a one-product model (section 2) | yes | fails |
| eq factoring (Gruen) | one point saved only for a one-eq polynomial; each slot has three eq terms (section 3) | yes | 0 to a few % |
| univariate skip (Gruen) | needs a high-degree first variable and a modified sumcheck [AUTHORS] | **no** | out |
| line values by additions (zkDuel's interpolation) | yes, largest share left (section 4, H158) | yes | open |
| delayed reduction (tessera, CPU) | plausible (section 4, H159) | yes | open |

## 1. What a slot computes per round (COUNTED)

- One command buffer per slot: table build, every round's fold, round kernel, reduction, transcript step (`metal.rs:3235, 4029`). One thread per (pair, point); point 1 is not launched in later rounds.
- Round 0 is typed per table; **from round 1 every table is an Fp2 pair** (`metal_slot.rs:109-119`). Each table's value at point d is built as `lo + dd (hi - lo)` (`metal.rs:2247-2260`): one `gl_mul` per base table, two per Fp2 table, per point d >= 2.
- Slot 14 term structure: `eq(tau) * [gate * 11 batched clauses + LogUp helper terms with mu_k]` plus hosted terms `eq(p_a) * gate`, `eq(p_z) * gate` (`slot_ir.rs:1262-1266`; slot 18 the same, `:1275-1277`). Eq tables, helper columns (`u`) and planes read at claim points are Fp2 (`slot_ir.rs:100-150`).
- Pre-A27 dump of slot 14's later-round kernel: 116 `f2_mul`, 77 `f2_mulb`, 182 `f2_add`, 64 `ln_ext`: 502 `gl_mul` and about 430 modular additions per point (`kbench/slot14_shieldstral_r13_a26.metal`; matches the README's 502). A27 cut later rounds 43 to 16 ms (slot 14) and 31 to 17 ms (slot 18) [MEASURED, `metal_slot.rs:159-161`]. M4g put loads plus line values at about a fifth before A27 [README]; nothing since splits the kernel, and the stream traces show one buffer per slot.

## 2. Small-value sumcheck (Bagad, Dao, Domb, Thaler, ePrint 2025/1117)

Read: full text of the 2025/1117 mirror (extended 2026/587 refused). [AUTHORS] Theorem 4.1: `(d-1)((d+1)/2)^(l0-1) N` small-small, `d N` small-large, `d^2/2^(l0+1) N` large-large multiplications; speedup about `2^l0`; their case, u64 against BN254, l0 about 3.7 at d = 2, "about 4 times". Measured 2-3x in Jolt and 20 to 40% standalone over the eq-only prover for degrees 2 and 3, "degree-2 ... better than degree-3" (section 8). **No degree above 3 is measured.**
**DERIVED (script, part 1)**, with small-small = 1, small-large = 2, large-large = 3 base multiplications: the best l0 is 2 and the gain over l0 = 1 (what the kernels do: round 0 base, the rest Fp2) is **9.3% at d = 3, 6.5% at d = 4, 4.2% at d = 5**. Only if a small product were 4 times cheaper than a `gl_mul` (true bytes and int16 in 32-bit multiplies) does it reach 24 to 27%; at 16 times, about 40%. That models one product of base tables; a slot body is a sum of about 190 products with Fp2 coefficients, Fp2 helpers and fixed-point planes. Prover-only: yes.

## 3. eq factoring (Gruen, ePrint 2024/108; Bagad et al. section 5)

Gruen's PDF refused; read through Bagad et al. [AUTHORS] `s_i = l_i t_i`, `t_i` has degree d, `t_i(1)` from the claim: one point saved; split-eq tables avoid the 2^n eq table; "reducing ... by roughly N" large multiplications. **Local:** eq(tau) is 1 of 64 tables (slot 14), about 1.5% of table traffic [DERIVED]. The point saving needs the slot to be one eq times something; it is three terms with three eqs and degrees 4, 3, 3. Writing `s = l_tau t + h` needs `t` and `h` at the same four points without shared nodes. Estimated 0 to a few %, not additive with A27's attained-degree point. Prover-only (Setty-Thaler send `s_i`).

## 4. What the reading found

- **H158, line values by additions.** `dd` is 2 to 5, so `x*dd` is one to three modular additions, not a `gl_mul`. zkDuel (arXiv 2610.37710, section 3.2.1, Table 1) does this: [AUTHORS] 1.65-1.75x (CUDA) and 1.55-1.59x (Triton) on 256-bit evaluation kernels, **1.04-1.06x at 32 bits**; H100; Goldilocks not reported alone. **DERIVED (script, part 2):** slot 14 spends 64 x 2 x 3 = 384 `gl_mul` per pair on line values against 4 x 502 in the body: 16% of multiplications before A27, **about 34% after it** if the body shrank with the time (ASSUMED), and 54% of the 16 ms if M4g's "a fifth of 43 ms" stayed whole. Saving: **6 to 10% of the kernel before A27, 12 to 21% after**, for a `gl_mul` worth 3 to 6 additions (ASSUMED, not measured on the Apple GPU).
- **H159, delayed reduction.** Every `f2_mul` reduces three times and every `gl_add` canonicalises. tessera's merged change keeps a 192-bit accumulator and reduces once per block: Goldilocks, one M4 Max core, 20.1-21.1% (product forests) and 25.2-31.1% (fraction trees), identical proof digests [AUTHORS, GitHub issue 391, CPU only, author-reviewed only; it says a GPU run must price carries and registers]. For this body, plausibly 5 to 15%; unknown.
- **Support skipping (my reading, not literature).** Slot 18's cube is 128 x 16,384 = 2^21 with 14,336 live columns at the 8B shape (87.5%, `shape.rs:1037, 2425, 2443`): up to 12.5% of slot 18 (2.6% of the prover GPU union) if gate-zero pairs are skipped in the first seven rounds and every term carries the gate. The LogUp terms are not gated in the IR (`slot_ir.rs:870-902`); **not verified**.

## 5. Falsifiable tests

1. **H158:** in `results/zk60_a27_app_20261107/kbench/` with A27 kernels (the dumps are A26), swap the `gl_mul(.., dd)` in `ln_base` and `ln_ext` for add chains; time slot 14 and 18 later rounds. **Pass:** `part` buffers bit-identical and slot 14 at least 10% faster. **Kill:** under 5%. Guarded gpu-class job, quiesced.
2. **H159:** same bench, 128-bit accumulators across the body's sums; pass 5% more, bit-identical.
3. **Support skipping:** CPU count over the IR terms of slots 14 to 18: which carry the gate, and gate-zero pairs per round at the 8B shape. Dies if any term is ungated.
4. **H157:** tests 1 to 3 together at least a third of slots 14 and 18 later rounds; fails under 25% or on any non-identical `part` buffer.

## 6. Honest expected effect

- **Committed words per request: none.**
- **Proved tokens per second.** Slots 14 to 18 are 49.5% of the prover GPU union (STREAM_GPU_PHASES.md section 4). If the call is GPU-bound and freed time converts 1:1 (that note's model): 10% of slot time is 0.13 s, **x1.04 on P**; 20% (central) 0.27 s, **x1.08**; a third 0.44 s, **x1.14**. On the two-lane cadence the sealing chain absorbs half: about x1.02, x1.04, x1.07. The 2.56 s target needs 0.13 to 0.93 s of union removed; this is a part. Candidate A removes helper terms from these same slots, so the gains overlap: do not multiply.

## 7. Risks and what was not verified

- Every kernel share is derived from a pre-A27 dump, two A27 timings and M4g's "a fifth", never measured on today's kernels. A kernel limited by registers or occupancy gains less from fewer multiplications; a stretched buffer is residence, not work (STREAM_GPU_PHASES.md section 13). `gl_mul` against `gl_add` on Apple silicon (`mul_64x64` is four 32-bit multiplies) is assumed.
- Not read: Gruen's paper (403), the extended 2026/587 text, zkDuel beyond the page returned, Chimera (ePrint 2026/1388), TensorZKP (queue item 4). Lazy-reduction miscompiles on GPUs are reported for Goldilocks (a prime-ir issue, seen in a search result only): test every round, not one digest.
- Bit-identity is the guard: the device transcript step and the host's replay of every device round already refuse any difference (A27 README section 2), so a wrong kernel fails loudly.
