// [UPERF3-FF] Spike S4: the sqrt (two-tier / Greyhound-shape) front
// end for the group opening — U_PERF3_HEADLINE_ROUTES.md Section 4.2,
// built VERBATIM behind the `uperf-t` selector. NOTHING in this module
// is called by any shipped path; the frozen pass (bg_prove_group /
// bg_verify_group, eval_proof.rs — READ-ONLY reuse) is the ORACLE.
//
// SHAPE (memo 2.1/4.2): view the group's n_0 digit rings as a
// two-tier grid; commit each row group under an inner Ajtai
// commitment (the EXISTING expand_level_matrix / matvec machinery);
// draw the challenge fold w = sum_i c_i row_i from the transcript;
// feed the EXISTING recursion (plan_schedule + the group prove path)
// the sqrt-sized folded relation. The differential leg is the point:
// at fixed seeds the evaluation claims this front end serves must
// EQUAL the built opening's claim values (the per-tensor MLE
// evaluations at the batched point, the b_row images).
//
// Rungs (lane FF, PROGRESS_UPERF3.md "Agent FF status"):
//   1. planner  — two-tier sizing + per-tier exact-digit gates at
//                 2^20/22/23 and the 8B group shapes (no proving).
//   2. differential — synthetic group at 2^20, both ways, claims
//                 bit-for-bit (STOP + record divergence if not).
//   3. scale    — 2^22-2^23 synthetic + the real 12x512 act group;
//                 fold wall 1T/8T, prove-group-equivalent, verifier
//                 1T, bytes.

// (rung 0 skeleton — planner and front end land on the next rungs)
