# R13 widened-word endpoint audit, 2026-10-26

Coordinator rule: 19:50 UTC in ZK60_SOL_ASTRA_TODOS_20261026.md. Widened
norm/attention words use **[-32768,32767]**. The received S2 build-spec bytes
remain pinned; this amendment must be recorded in the R13 freeze note and
reviewed under D24. This is a source/design audit, not an R13 proof or security
acceptance. The R13 proof profile is still inactive.

| Consumer | Endpoint dependency and required implementation |
|---|---|
| Norm division | The quotient is fixed by its division identity and two nonnegative remainders. No negated quotient must itself fit int16. Use the full biased two-byte decomposition for y and nm. The new executor accepts -32768; legacy norm remains symmetric int8. |
| Q/K/V, O and their public matmuls | Requantization fixes the quotient; the additional input endpoint changes the accumulator magnitude bound from 32767 to 32768. Output-channel multipliers remain public and narrow. Use biased two-byte output decompositions. |
| Half-split RoPE | `c*a-s*b` and `s*a+c*b` are computed in i64 / the field, then requantized. Neither `-a` nor `-b` is stored as an int16 word. The largest absolute raw rotation is 2*128*32768=8388608. A rotation that produces +32768 must still refuse at the rotated output range; it is not silently wrapped to -32768. No inverse exclusion is required. |
| Score and causal sentinel | The widened inputs occur in the dot product; the score itself remains symmetric [-127,127]. Its sentinel stays -127 and its exp difference stays [0,255]. Keep full T*T score checks before masking. No attention-word negation is used to form the sentinel. |
| U8 range lookups | Legacy `layout::sym` is explicitly symmetric int8 and is retained for old profiles and R13 scores. It MUST NOT be reused for R13 y/nm/q/k/v/qr/kr/o. Their new limbs prove `word+32768=lo+256*hi`, with lo/hi in U8, exactly the amended domain. This replacement is pending layout integration. |
| DD | Tuple keys are row Sum, E and P. They do not include signed attention or norm words. Only the PV accumulator consumes widened V. F_P=12 still needs propagation to quotient pins and DD clauses; the endpoint amendment does not change the dictionary keys. |
| Residuals/endpoints | Residuals already use full int16. Existing trained D_max uses 32768, not 32767. Keep that trained rule and derive the norm remainder window from each actual calibration. |
| Transcript, masking and wire | `Fp::from_i64` maps signed integers without an i16 negation. All signed16 values are distinct modulo the Goldilocks prime. Mask rows, challenge derivation and wire field encoding do not require a symmetric integer interval. No new transcript rule follows from the endpoint amendment; new profile/layout/statement binding is still required. |
| No-wrap | `nowrap_counted.json` now uses norm_abs=attention_abs=32768 and explicitly includes rotation, PV, up and norm reconstruction. Largest conservative local bound remains 51 bits < the pinned field modulus. Derived SiLU output stays signed31, with raw table abs<=32767. This count is conditional on the actual R13 validators/range relations. |
| Public weights/gains | The existing i8 storage type can represent -128. The coordinator retains symmetric public int8 weights; R13 must explicitly reject -128 in all seven matrices and both gains before relying on the 127 bound. This is a new-profile check only; do not edit frozen legacy semantics. |

No site in this audit needs the inverse exclusion construction. The historical
`symmetric_endpoint_cost.json` remains as a rejected proposal, not the selected
R13 count. The selected count remains the byte-aligned table construction;
actual native counts are still required.

Validation to retain: -32768 and +32767 quantizer controls, both out-of-range
neighbors, norm -32768, RoPE -32768 identity and +32768 refusal, both complete
oracle stacks, explicit public -128 rejection, new-profile limb/argument
controls, existing-profile seeded goldens and retained receipts.
