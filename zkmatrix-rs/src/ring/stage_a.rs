// [UPERF3-GG] U-PERF3 round 5, lane GG — STAGE A INTEGRATION (skeleton).
//
// The descent replacement in the REAL pass: the ten per-table masked
// descent pairs of the BK full-statement path (bin: bk_pass_run) replaced
// by the validated Stage-A components behind an explicit selector —
// range/narrowing pairs by the aggregate zero-check of
// zc_range::[UPERF3-EE] (zc_agg_prove/verify + the O-4 mask), the SiLU
// pairs by the LogUp-as-one-sumcheck of zc_range::[UPERF3-S]
// (logup_sumcheck_prove/verify with the committed helper h). Spec:
// docs/zkmatrix-poc/U_PERF3_OPENING_LAYER_DESIGN.md §2.2-2.6; the frozen
// pass is the ORACLE and the default path stays byte-identical (nothing
// here is called by any shipped path).
//
// This module holds the shape-independent Stage-A logic (instance
// building from the pass's committed columns, plane extraction, the
// claim-serving forms); the pass driver itself lives in the bin's
// [UPERF3-GG] section (it needs the bin's statement/layer statics).
//
// Ownership (round-5 lane GG): this NEW file; ONE `pub mod` line in
// ring/mod.rs; the bin's [UPERF3-GG] section + the `uperf-a` dispatch
// line. zc_range / ec_kernel / eval_proof / the pass code are READ-ONLY
// reuse — any needed-but-private zc_range surface is wrapped here, never
// edited there.

// (rung 1+ content lands here)
