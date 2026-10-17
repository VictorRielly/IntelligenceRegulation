// Research candidate: uncompiled, unintegrated, no privacy/receipt claim.
// Only six proven [-127,127] projection inputs may use this helper.
// A shape-bound or input-class failure preserves the scalar helper's behavior.
// The int16 FFN down call stays on matmul_in_out.
#[allow(clippy::too_many_arguments)]
fn matmul_i8_projection(
    g: &Geom, x: &[i64], xs: usize, w: &[i8], inner: usize,
    outer: usize, os: usize, out_len: usize, in_out: bool,
) -> Vec<i64> {
    let fallback = || {
        if in_out { matmul_in_out(g, x, xs, w, inner, outer, os, out_len) }
        else { matmul(g, x, xs, w, inner, outer, os, out_len) }
    };
    // Absolute-sum bound protects EVERY partial sum, in any reduction order.
    // Both signs of -128 weights are included; no saturation or wrapping.
    if inner > (i32::MAX as usize) / (127 * 128) {
        return fallback();
    }
    let mut packed = Vec::<i8>::with_capacity(g.t * inner);
    for t in 0..g.t {
        for i in 0..inner {
            let v = x[t * xs + i];
            if !(-127..=127).contains(&v) {
                return fallback();
            }
            packed.push(v as i8);
        }
    }
    let mut out = vec![0i64; out_len];
    for t in 0..g.t {
        if !in_out {
            for j in 0..outer {
                let acc: i32 = (0..inner).map(|i|
                    i32::from(packed[t * inner + i]) * i32::from(w[j * inner + i])
                ).sum();
                out[t * os + j] = i64::from(acc);
            }
        } else {
            for j0 in (0..outer).step_by(64) {
                let count = (outer - j0).min(64);
                let mut acc = [0i32; 64];
                for i in 0..inner {
                    let xi = i32::from(packed[t * inner + i]);
                    let wi = &w[i * outer + j0..i * outer + j0 + count];
                    for j in 0..count {
                        acc[j] += xi * i32::from(wi[j]);
                    }
                }
                for j in 0..count {
                    out[t * os + j0 + j] = i64::from(acc[j]);
                }
            }
        }
    }
    out
}
