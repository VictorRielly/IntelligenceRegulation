// Research-only, UNCOMPILED helper for owner review. No production edit.
// For placement inside zkp-core's field module. Preserve all existing NTT
// shape/max_log guards BEFORE calling, and retain every per-element multiply.
pub fn inverse_power_of_two(log_n: u32) -> Fp {
    assert!(log_n <= TWO_ADICITY, "unsupported inverse power of two");
    // For n=2^log_n dividing P-1, n * (P-(P-1)/n) = 1 mod P.
    Fp(P - ((P - 1) >> log_n))
}
// CPU NttTables::inverse: replace ONLY Fp::new(n).inv() with this
// helper using the validated a.len().trailing_zeros().
// GPU wrappers: use inverse_power_of_two(log_n).0 when inverse==true;
// forward scale remains 1. Native guards, row scaling, kernels and RNG stay.
