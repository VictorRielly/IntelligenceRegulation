# Research handoff: hidden weights (P3) priced on the current prover (2026-11-24, claude tick 54)

From Claude, the background researcher (D50). Queue item 91 (the co-coordinator's request on the owner's question about hidden weights). Clock at writing 2026-11-24T15:54Z.

**Scope.** Local reading, arithmetic, 3 searches, 4 fetches (the zkLLM PDF did not extract; the Hollow-LLM abstract has no numbers). No build, run or Git. Written: this file and `20261124-claude-tick54-hidden-weights-price.py` / `.out.txt`. Read: `ZK60_PRIVACY_REQUIREMENTS.md`; `U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md` lines 1-770 (2026-09-02 design, older); `ZK60_FABLE_MODEL_IDENTITY.md` lines 1-430 (FA4, the budgeted stable commitment); `ZK60_STABLE_WEIGHT_SLOTS.md`; the Lean statements file lines 100-200; B6a plan sections 1-3; tick 4; `argument.rs:3195-3220, 3338-3360`. **Triage material, not a work order:** a change of what is committed needs the owner's ruling, a new profile (D17), re-proved Lean (D63); D82 keeps P3 at study level. Labels: COUNTED, MEASURED, [AUTHORS], DERIVED (script), ASSUMED.

## 0. Headline

- **Bytes are the main price.** One stable hidden-weight opening adds **220 to 1,250 MB to the 818.7 MB receipt (x1.27 to x2.5)**; best row found: **220 MB (x1.27) at 2^16-wide rows, rate 1/4, budget 16, one batched group** (430 MB with seven groups). B6a removes clear vectors, leaving column data: **146 MB (x1.18)** (DERIVED, section 3).
- **Prover time is not bounded by anything measured:** the row combination costs **0.09 to 2.5 s a request** (2.5 to 66% of the 3.7455 s cadence). A fresh commit per proof costs **2.4 s** (+65%); the stable commitment exists to avoid it.
- **Mask reuse is the hard rule:** the budget k forces code rate 1/4 at k = 16 (no rate-1/2 solution above k = 4).
- **Hiding does not give identity:** two different hidden tensors verify under one declared model today (FA4, reproduced).

## 1. What changes in the prover and the verifier

Today a matmul claim folds the **public** int8 matrix by an eq vector and enters the sumcheck as a public table (`argument.rs:3205-3212`, `3346-3353`: `fold_rows_i8` / `fold_checked`, `b.public(folded)`). Both sides run it, so the verifier holds the 7.0 GB of weights (32 x 218,103,808 [COUNTED, cycle 4]; verifier path inferred from the shared builder, not separately read). With hidden weights (FA4 sections 4.3 and 5.1, mapped by reading):
1. The folded table is a prover secret; the matmul sumchecks become private-by-private, masked like the activation slots, ending in an **evaluation of the committed weight matrix** (7 points a block: q, k, v, o, gate, up, down). The prover's fold pass stays.
2. The weights sit in a **stable hiding commitment** per layer, root signed by an approver, opened by every proof.
3. The verifier stops folding and needs no weights; it checks Q' columns of 13,312 rows a block: about 1.9 G mults a request against 14 G for today's fold (DERIVED; **verifier work falls about seven-fold**, unmeasured).
4. Once per model: the commitment, a **range proof** that every word is in [-127, 127] (the integer relation needs it; the verifier can no longer see the weights), and the manifest.

## 2. Committed values and the reuse budget

- **Rows:** 218.1 M words = **13,312 rows at n = 2^14** (2.61 x the 5,103 rows of A and H), 3,328 at 2^16, 832 at 2^18; one int8 per word (packing needs per-limb claims, tick 49/51: unpriced).
- **What must not repeat** (FA4 section 5.1): the pad hides at most q_pad = k Q' distinct opened positions per row; every group vector, proximity vector and block terminal needs a mask row **unused by any earlier proof** (one set per slot); sumcheck masks and A, H pads and salts stay fresh. Slots are burned before use (`stable_weight_slots.rs`: journal exists, budget at most 65,536, no prover consumes it). Residual risk: a restored backup resetting the counter (FlashProve's main risk too).
- **Budget against rate** (DERIVED, Q' for 2^-114 per list at distance/2, n = 2^14): rate 1/2: k = 1 needs Q' = 281, k = 4 needs 300, **k >= 16 none**; rate 1/4: k = 16 needs 182, k = 64 needs 321, k = 256 none; rate 1/8: k = 64 needs 155. Mask rows add 1 to 11% to the rows (ASSUMED 8 to 22 a slot).
- **Storage per model:** encoded matrix 112 GB at rate 1/2, **223 GB at 1/4**, 447 GB at 1/8 (FA4: 54 to 95 GB payload if columns are re-derived).

## 3. Receipt bytes (DERIVED from the wire formula `wire.rs:106-108`, script 3)

Added bytes for 32 blocks, one opening per block, today 818.7 MB (clear vectors 427.9 MB, columns 371.9 MB [MEASURED, B6a plan]):

| n | rate, k, Q' | groups | added MB | x today |
|---|---|---:|---:|---:|
| 2^14 | 1/2, 1, 281 | 1 / 7 | 979 / 1,031 | 2.20 / 2.26 |
| 2^14 | 1/4, 16, 182 | 1 / 7 | 643 / 703 | 1.79 / 1.86 |
| 2^16 | 1/2, 1, 277 | 1 / 7 | 309 / 511 | 1.38 / 1.62 |
| **2^16** | **1/4, 16, 172** | **1 / 7** | **220 / 430** | **1.27 / 1.52** |
| 2^16 | 1/4, 64, 182 | 1 / 7 | 238 / 475 | 1.29 / 1.58 |
| 2^18 | 1/4, 16, 169 | 1 / 7 | 311 / 1,125 | 1.38 / 2.37 |

Width trades columns (fall with n) against vectors ((G+1)(n+q_pad) x 16 B, rise with n); n = 2^16 is the minimum. After B6a the vectors go and the weight part is the column data alone (146 MB at the best row). "One group" needs every weight claim of a block merged into one batched claim (the BAT step of B6a); with seven distinct points it is seven groups: **not checked whether the opening grammar allows the merge for committed-times-committed products**.

**Batching across requests** divides columns by the batch only if requests share a receipt (FlashProve: shared chain per batch, [AUTHORS] 34.5 to 47 s fixed per batch of 24, tick 4); our receipts are per request. "One group" needs the BAT merge to carry seven committed-weight claims: unchecked (T-P3c).

## 4. Prover time (DERIVED, script 4 and 5; kernels unmeasured)

- **Row combination** (one pass over 218.1 M words, all groups): (G+1) x 2 x N = 0.87 G (G = 1) to 3.49 G (G = 7) base mults a block: 19 to 78 ms at 45 G/s (tick 41's measured sparse-fold rate), 3 to 23 ms at 150 to 300 G/s; **0.09 to 2.5 s a request**. Memory floor 0.3 to 2.5 ms a block. Int8 words may allow cheaper wide-integer accumulation (ASSUMED).
- **Fresh commit per proof:** 3.49 GB a block at rate 1/2; 46 GB/s [MEASURED, A+H 28.95 ms]; **76 ms a block, 2.42 s a request, +65%**.
- **Range proof, once per model:** 3.3 to 4.6 s (ASSUMED linear from tick 53's tree bound).
- **Proved tokens/s:** +0.09 to +2.5 s on a 3.7455 s cadence is a loss of 2% to 40% at full pass-through; the stream is not GPU-paced (tick 22 rule a), so the low end is likelier.

## 5. Falsifiable tests (not run)

- **T-P3a (kernel).** Time the multi-group row combination on 13,312 x 2^14 with int8 source, G = 1 and 7, quiet GPU, through the guard. Pass: <= 25 ms a block at G = 7. Kill: > 75 ms.
- **T-P3b (bytes).** `open_zk` wire length at 1/64 scale (208 rows, rate 1/4, G = 1 and 7); columns are linear in rows. Pass: table within 1%.
- **T-P3c (merge).** Read whether one group can carry seven committed-weight claims (`layout.rs:120` refuses "claim parts with different column weights"). Fail: G = 7 stands.

## 6. Lean statements that change (`ZK60_LEAN_PRODUCTION_STATEMENTS.md`)

- **T1a / T1b** already read W "extracted from `s.wroot` under P3": the extractor must now extract from the stable commitment's openings, and the range statement moves into the proof.
- **T2** simulates from the root alone. Its **R <= 2^64 receipts cannot hold** for a stable commitment (budget at most 65,536): R becomes per commitment, and the k-fold reuse simulator is **not written** (FA4 5.1).
- **Model identity** ("a fresh private weight root alone does not prove use of a previously approved model", privacy requirements) is **not among the two approved statements**: a clause in T1b (proof root = manifest root) or a third statement; owner's ruling. Hollow-LLM (arXiv 2607.28884, abstract only) shows the limit: ghost weights pass the circuit, so identity pins approved weights, not the compute done.

## 7. Comparison [AUTHORS, search summaries, unchecked] and not verified

zkLLM: 13B in under 15 minutes, proof under 200 kB, parameters private; FlashProve: commitment about 6.5 MB, 38:43 minutes once, 18.78 MB a request, no separable cost of hiding (tick 4 stands). Not verified: the verifier path; whether claims merge; kernel rates; the embedding, head and norm gains (about 1.05 G words at Llama-3 shapes, ASSUMED) are not in the 218.1 M; the B6a tower bytes for W; zkLLM's commitment form; the Hollow-LLM body.

## 9. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H166 (stable-commitment opening at 2^16-wide rows is the byte minimum; the tests above).
