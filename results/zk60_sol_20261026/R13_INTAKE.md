# R13 intake: LOW accuracy stack

Prepared 2026-10-26 while R12 acceptance runs. This is an implementation map,
not a final build spec, a proof, or a security acceptance. No R13 source edits
have started. The final fidelity report is an explicit dependency of S2.

Current evidence: `results/zk60_fidelity_parity_20261019/PROGRESS.md`, especially
the 2026-10-26 17:34 UTC entry. TinyLlama LOWv6 LAMBADA is reported complete;
the 8B gate-bound and masked-score fixes are still being checked. Do not infer
the final export's constants from the earlier LOW labels.

| Requested change | Existing implementation seam | Required evidence |
|---|---|---|
| c2 per-output-channel multipliers; q5 k5 v6 o8 g6 u4 d6 | `trained_loader`, block public data, `witness`, matmul claims in `argument` | Export schema, integer rounding/offset formula, multiplier order/axis and binding; independently computed dense references and coefficient tamper controls |
| Wider requantization remainders | `shape::NormCalibration` shift classes; `layout::Ids`, plane domains, byte lookups and zero-check clauses | Exact shift windows from final export; counted plane/lookup totals; top-limb pins; reject each out-of-class shift |
| Norm outputs int16, tn minus 8 | Shape norm-window derivation, norm witness/relation, kernel norm output, layer input consumers | Three-limb remainder window where derived; int16 decomposition; no-wrap arithmetic for final per-model constants |
| Softmax F_P 12 | `layout::F_P`, separate private `shape::F_P`, softmax witness/relation, kernel calibration, DD quotient dictionary | Make precision profile-derived everywhere, including top-limb lookup pins; preserve legacy F_P=9 bytes; DD and non-DD dense parity |
| Attention int16 | Q/K/RoPE/O planes, range lookups, score/PV/AO arithmetic, pad and dependency claims, kernel types | Range decompositions and full T-by-T score bounds, including masked positions; reject mismatched scales and profile |
| Per-group SiLU, at most four tables; int12 input | F-domain public table binding and activation lookup pair | Group column is public and bound to output channels; group/table cardinalities and exact signed input encoding; swapped group/table rejection |
| Gate-times-up h int24 where selected | Product witness, three-byte signed h decomposition and downstream down projection | Final model-specific choice (TinyLlama LOW versus 8B LOW+h24), exact h scale/rounding and remainder widths, dense boundary cases |

The independent reference kernel also needs the chosen stack. Reusing the
prover's computation as its own reference would not establish arithmetic
parity. Preserve the fixed kernel crate's frozen behavior.

Before implementation, obtain from Claude's final report:

1. Exact model/profile names and whether LOW or LOW+h24 applies at each one;
   the intended Shieldstral export's treatment of that choice.
2. Export format and pins, all per-site/per-layer shifts, multiplier arrays,
   norm constants, group indices, table values/scales and rounding rules.
3. Final zero-refusal fixes (gate bound and any score/exp adjustment), with
   fidelity artifacts and their hashes. The source ledger currently proposes
   gate tensor cap 4 at 8B L21 and SH_S/exp exponent +1 at L15; they are not yet
   a frozen instruction to implement.

Then implement behind new profile identities, starting with failing tests.
Keep old profile encodings and schedules unchanged, including RNG/absorb order.
Count actual layout totals against the R10/R11 replica, rather than reporting
the +22.8% estimate as a measured R13 cost. Run old seeded goldens and retained
R8/R9/R12 receipt compatibility, new dense proof/kernel parity, fresh-process
verification and rejection controls, then the full suite and frozen manifest.
Claude routes the independent D24 review and privacy gate.

R12 acceptance source is held fixed meanwhile. Do not modify the native working
tree until its acceptance worker is terminal and the R12 frozen copy has been
verified.


## Spec received

The fidelity lane published `S2_BUILD_SPEC.json`; exact received bytes and SHA-256 are retained beside this intake (`S2_BUILD_SPEC.received.json` and `.received.sha256.json`). It specifies LOW+h24 as the common stack, documents TinyLlamas cheaper LOW candidate, and leaves full-set fidelity reruns pending. R13 implementation can follow the supplied arithmetic while those fidelity claims remain qualified. R12 must first finish and freeze.
