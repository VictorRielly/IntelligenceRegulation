//! Multilinear helpers: eq tables, folding a table over its first
//! variable, and the "fold a matrix against a weight vector" primitives
//! the matmul sumcheck needs.

use crate::field::{Fp, Fp2};
use rayon::prelude::*;

/// eq(r, x) for all x in {0,1}^n, x indexed as an integer with bit 0 =
/// the LAST variable?  No: convention here is x's bit i corresponds to
/// r[n-1-i], i.e. r[0] is the MOST significant bit of the index. So a
/// row-major matrix index (i * cols + j) with i having log_rows bits and
/// j log_cols bits corresponds to the point (r_row || r_col).
pub fn eq_table(r: &[Fp2]) -> Vec<Fp2> {
    let n = r.len();
    let mut out = vec![Fp2::ONE; 1 << n];
    let mut len = 1usize;
    for &ri in r.iter() {
        // split each existing entry e into (e*(1-ri), e*ri) for the next bit (more significant first)
        let (lo, hi) = out.split_at_mut(len);
        let hi = &mut hi[..len];
        let one_minus = Fp2::ONE.sub(ri);
        // [UPERF3-XX] small steps run sequentially: a rayon region per
        // doubling step cost ~0.3 ms of pool wake-up each and dominated
        // pcs::group_claims (37 claims x 2 tables x up to 14 steps per
        // layer); same values.
        if len < 4096 {
            for (a, b) in lo.iter_mut().zip(hi.iter_mut()) {
                let e = *a;
                *b = e.mul(ri);
                *a = e.mul(one_minus);
            }
        } else {
            lo.par_iter_mut().zip(hi.par_iter_mut()).for_each(|(a, b)| {
                let e = *a;
                *b = e.mul(ri);
                *a = e.mul(one_minus);
            });
        }
        len <<= 1;
    }
    // out[idx] where idx bit (n-1-i) = variable i -> but the loop above makes
    // the FIRST r the least significant split. Fix by building in the
    // opposite order: iterate r in reverse so r[0] ends up most significant.
    out
}

/// eq table with r[0] the MOST significant index bit (row-major convention).
pub fn eq_table_msb(r: &[Fp2]) -> Vec<Fp2> {
    let rev: Vec<Fp2> = r.iter().rev().copied().collect();
    eq_table(&rev)
}

/// eq(r, s) for two points.
pub fn eq_point(r: &[Fp2], s: &[Fp2]) -> Fp2 {
    assert_eq!(r.len(), s.len());
    let mut acc = Fp2::ONE;
    for (a, b) in r.iter().zip(s.iter()) {
        // a*b + (1-a)*(1-b)
        let t = a.mul(*b).add(Fp2::ONE.sub(*a).mul(Fp2::ONE.sub(*b)));
        acc = acc.mul(t);
    }
    acc
}

/// Evaluate the MLE of a base-field vector (length 2^n, MSB convention) at r.
pub fn eval_mle_base(v: &[Fp], r: &[Fp2]) -> Fp2 {
    assert_eq!(v.len(), 1 << r.len());
    let eq = eq_table_msb(r);
    v.par_iter().zip(eq.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b))
}

pub fn eval_mle_ext(v: &[Fp2], r: &[Fp2]) -> Fp2 {
    assert_eq!(v.len(), 1 << r.len());
    let eq = eq_table_msb(r);
    v.par_iter().zip(eq.par_iter()).map(|(a, e)| e.mul(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b))
}

/// Given a row-major matrix M (rows x cols, base field) and row weights
/// w (len rows), return w^T M (len cols) in the extension.
pub fn fold_rows_base(m: &[Fp], rows: usize, cols: usize, w: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(m.len(), rows * cols);
    assert_eq!(w.len(), rows);
    // parallel over column chunks
    let chunk = 256usize.min(cols);
    let mut out = vec![Fp2::ZERO; cols];
    out.par_chunks_mut(chunk).enumerate().for_each(|(ci, oc)| {
        let c0 = ci * chunk;
        for i in 0..rows {
            let wi = w[i];
            if wi.is_zero() { continue; }
            let row = &m[i * cols + c0..i * cols + c0 + oc.len()];
            for (o, &v) in oc.iter_mut().zip(row.iter()) {
                *o = o.add(wi.mul_base(v));
            }
        }
    });
    out
}

/// Given a row-major matrix M (rows x cols, base field) and column
/// weights c (len cols), return M c (len rows) in the extension.
pub fn fold_cols_base(m: &[Fp], rows: usize, cols: usize, c: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(m.len(), rows * cols);
    assert_eq!(c.len(), cols);
    (0..rows).into_par_iter().map(|i| {
        let row = &m[i * cols..(i + 1) * cols];
        let mut acc = Fp2::ZERO;
        for (&v, &cw) in row.iter().zip(c.iter()) {
            acc = acc.add(cw.mul_base(v));
        }
        acc
    }).collect()
}

/// Same, for a matrix given as i8 (avoids materializing Fp).
pub fn fold_rows_i8(m: &[i8], rows: usize, cols: usize, w: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(m.len(), rows * cols);
    assert_eq!(w.len(), rows);
    if deferred_rows() {
        if let Some(out) = fold_rows_deferred(m, rows, cols, w, 128, |v| v as i64) {
            return out;
        }
    }
    let chunk = 256usize.min(cols);
    let mut out = vec![Fp2::ZERO; cols];
    out.par_chunks_mut(chunk).enumerate().for_each(|(ci, oc)| {
        let c0 = ci * chunk;
        for i in 0..rows {
            let wi = w[i];
            let row = &m[i * cols + c0..i * cols + c0 + oc.len()];
            for (o, &v) in oc.iter_mut().zip(row.iter()) {
                let v = v as i64;
                if v == 0 { continue; }
                *o = o.add(wi.mul_base(Fp::from_i64(v)));
            }
        }
    });
    out
}

pub fn fold_cols_i8(m: &[i8], rows: usize, cols: usize, c: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(m.len(), rows * cols);
    assert_eq!(c.len(), cols);
    (0..rows).into_par_iter().map(|i| {
        let row = &m[i * cols..(i + 1) * cols];
        let mut acc = Fp2::ZERO;
        for (&v, &cw) in row.iter().zip(c.iter()) {
            let v = v as i64;
            if v == 0 { continue; }
            acc = acc.add(cw.mul_base(Fp::from_i64(v)));
        }
        acc
    }).collect()
}

pub fn fold_rows_i32(m: &[i32], rows: usize, cols: usize, w: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(m.len(), rows * cols);
    assert_eq!(w.len(), rows);
    if deferred_rows() {
        if let Some(out) = fold_rows_deferred(m, rows, cols, w, 1i64 << 31, |v| v as i64) {
            return out;
        }
    }
    let chunk = 256usize.min(cols);
    let mut out = vec![Fp2::ZERO; cols];
    out.par_chunks_mut(chunk).enumerate().for_each(|(ci, oc)| {
        let c0 = ci * chunk;
        for i in 0..rows {
            let wi = w[i];
            let row = &m[i * cols + c0..i * cols + c0 + oc.len()];
            for (o, &v) in oc.iter_mut().zip(row.iter()) {
                if v == 0 { continue; }
                *o = o.add(wi.mul_base(Fp::from_i64(v as i64)));
            }
        }
    });
    out
}

/// `HL_FSP_ROW_FOLD=0` retains the per-element field arithmetic for a
/// same-binary differential measurement. The protocol and output order are
/// unchanged: only the representation of the intermediate sum differs.
fn deferred_rows() -> bool {
    static ON: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *ON.get_or_init(|| std::env::var("HL_FSP_ROW_FOLD").map(|v| v != "0").unwrap_or(true))
}

/// Fold signed integers by reducing once per output, rather than once per
/// input. Each extension component accumulates the exact signed integer
/// sum of the u64 coefficient times the signed matrix value. Retain the
/// inherited zero skip: adding a bias to every value made sparse inputs
/// substantially slower even though dense inputs improved.
/// The only callers have |v| <= max_abs, for max_abs = 128 or 2^31.
///
/// Use the full u64 bound for coefficients so the accumulator cannot wrap
/// even before relying on the field's canonical-representation invariant.
/// Rows beyond this bound use the inherited field-arithmetic path. The
/// bound is public and ensures every partial sum fits, in any sign order.
fn fold_rows_deferred<T, F>(m: &[T], rows: usize, cols: usize, w: &[Fp2], max_abs: i64, value: F) -> Option<Vec<Fp2>>
where
    T: Copy + Sync,
    F: Fn(T) -> i64 + Sync,
{
    if rows as u128 > i128::MAX as u128 / (u64::MAX as u128 * max_abs as u128) {
        return None;
    }
    let reduce = |s: i128| {
        let magnitude = Fp::from_u128(s.unsigned_abs());
        if s < 0 { Fp::ZERO.sub(magnitude) } else { magnitude }
    };
    let chunk = 256usize.min(cols);
    let mut out = vec![Fp2::ZERO; cols];
    out.par_chunks_mut(chunk).enumerate().for_each(|(ci, oc)| {
        let c0 = ci * chunk;
        // Fixed per-task scratch; no allocation inside the row loop.
        let mut sums = [(0i128, 0i128); 256];
        for (i, &wi) in w.iter().enumerate() {
            let row = &m[i * cols + c0..i * cols + c0 + oc.len()];
            for (sum, &v) in sums.iter_mut().zip(row) {
                let v = value(v) as i128;
                if v == 0 { continue; }
                sum.0 += wi.c0.0 as i128 * v;
                sum.1 += wi.c1.0 as i128 * v;
            }
        }
        for (o, &(s0, s1)) in oc.iter_mut().zip(&sums) {
            *o = Fp2::new(reduce(s0), reduce(s1));
        }
    });
    Some(out)
}

pub fn fold_cols_i32(m: &[i32], rows: usize, cols: usize, c: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(m.len(), rows * cols);
    assert_eq!(c.len(), cols);
    (0..rows).into_par_iter().map(|i| {
        let row = &m[i * cols..(i + 1) * cols];
        let mut acc = Fp2::ZERO;
        for (&v, &cw) in row.iter().zip(c.iter()) {
            if v == 0 { continue; }
            acc = acc.add(cw.mul_base(Fp::from_i64(v as i64)));
        }
        acc
    }).collect()
}

/// Lagrange-interpolate a univariate polynomial given its values at
/// 0, 1, ..., d and evaluate at x.
pub fn interpolate_eval(vals: &[Fp2], x: Fp2) -> Fp2 {
    let d = vals.len();
    let mut acc = Fp2::ZERO;
    for i in 0..d {
        let mut num = Fp2::ONE;
        let mut den = Fp::ONE;
        for j in 0..d {
            if i == j { continue; }
            num = num.mul(x.sub_base(Fp::new(j as u64)));
            den = den.mul(Fp::from_i64(i as i64 - j as i64));
        }
        acc = acc.add(vals[i].mul(num).mul_base(den.inv()));
    }
    acc
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pt(seed: u64, n: usize) -> Vec<Fp2> {
        (0..n).map(|i| Fp2::new(Fp::new(seed * 1000 + i as u64 * 7 + 3), Fp::new(seed + i as u64 * 11 + 5))).collect()
    }

    #[test]
    fn eq_table_sums_to_one_and_matches_point() {
        let r = pt(3, 5);
        let t = eq_table_msb(&r);
        let sum = t.iter().fold(Fp2::ZERO, |a, b| a.add(*b));
        assert_eq!(sum, Fp2::ONE);
        for idx in 0..32usize {
            let bits: Vec<Fp2> = (0..5).map(|i| if (idx >> (4 - i)) & 1 == 1 { Fp2::ONE } else { Fp2::ZERO }).collect();
            assert_eq!(t[idx], eq_point(&r, &bits));
        }
    }

    #[test]
    fn mle_eval_at_boolean_points_is_lookup() {
        let v: Vec<Fp> = (0..16).map(|i| Fp::new(i * i + 1)).collect();
        for idx in 0..16usize {
            let bits: Vec<Fp2> = (0..4).map(|i| if (idx >> (3 - i)) & 1 == 1 { Fp2::ONE } else { Fp2::ZERO }).collect();
            assert_eq!(eval_mle_base(&v, &bits), Fp2::from_base(v[idx]));
        }
    }

    #[test]
    fn matrix_folds_are_tensor_evaluations() {
        // M 4 x 8; MLE at (r_row(2) || r_col(3)) == fold_rows then dot with eq(r_col)
        let m: Vec<Fp> = (0..32).map(|i| Fp::new(i * 3 + 7)).collect();
        let r_row = pt(1, 2);
        let r_col = pt(2, 3);
        let mut r = r_row.clone();
        r.extend_from_slice(&r_col);
        let full = eval_mle_base(&m, &r);
        let v = fold_rows_base(&m, 4, 8, &eq_table_msb(&r_row));
        let ec = eq_table_msb(&r_col);
        let dot = v.iter().zip(ec.iter()).fold(Fp2::ZERO, |a, (x, y)| a.add(x.mul(*y)));
        assert_eq!(full, dot);
        let w = fold_cols_base(&m, 4, 8, &ec);
        let er = eq_table_msb(&r_row);
        let dot2 = w.iter().zip(er.iter()).fold(Fp2::ZERO, |a, (x, y)| a.add(x.mul(*y)));
        assert_eq!(full, dot2);
    }

    fn edge_weights(rows: usize) -> Vec<Fp2> {
        use crate::field::P;
        let mut state = 0x82a7_413d_6679_e405u64;
        let mut draw = || {
            state = state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            Fp::new(state)
        };
        (0..rows).map(|i| match i % 6 {
            0 => Fp2::ZERO,
            1 => Fp2::new(Fp(P - 1), Fp(P - 2)),
            2 => Fp2::new(Fp::ONE, Fp(P - 1)),
            3 => Fp2::new(Fp(P / 2), Fp(P / 2 + 1)),
            _ => Fp2::new(draw(), draw()),
        }).collect()
    }

    #[test]
    fn deferred_integer_rows_match_base_field_at_signed_and_field_edges() {
        // Both sides of the parallel column boundary, including a ragged
        // final chunk; all 256 signed bytes occur, and i32 extrema occur in
        // every row. Base-field folding is the independent reference.
        let edges = [i32::MIN, i32::MAX, -1, 0, 1, -128, 127, -(1 << 30), 1 << 30];
        for rows in [0, 1, 3, 33, 512] {
            let w = edge_weights(rows);
            for cols in [1, 7, 255, 256, 257, 513] {
                let bytes: Vec<i8> = (0..rows * cols).map(|i| (i.wrapping_mul(151) as u8) as i8).collect();
                let ints: Vec<i32> = (0..rows * cols).map(|i| {
                    if i % 13 < edges.len() { edges[i % 13] }
                    else { (i as u32).wrapping_mul(0x9e37_79b9) as i32 }
                }).collect();
                let byte_fields: Vec<Fp> = bytes.iter().map(|&v| Fp::from_i64(v as i64)).collect();
                let int_fields: Vec<Fp> = ints.iter().map(|&v| Fp::from_i64(v as i64)).collect();
                let want_bytes = fold_rows_base(&byte_fields, rows, cols, &w);
                let want_ints = fold_rows_base(&int_fields, rows, cols, &w);
                assert_eq!(fold_rows_deferred(&bytes, rows, cols, &w, 128, |v| v as i64).unwrap(), want_bytes);
                assert_eq!(fold_rows_deferred(&ints, rows, cols, &w, 1i64 << 31, |v| v as i64).unwrap(), want_ints);
                assert_eq!(fold_rows_i8(&bytes, rows, cols, &w), want_bytes);
                assert_eq!(fold_rows_i32(&ints, rows, cols, &w), want_ints);
            }
        }
    }

    #[test]
    fn deferred_zero_rows_with_nonzero_extension_weights() {
        let w = edge_weights(512);
        let want = vec![Fp2::ZERO; 257];
        assert_eq!(fold_rows_deferred(&vec![0i8; 512 * 257], 512, 257, &w, 128, |v| v as i64).unwrap(), want);
        assert_eq!(fold_rows_deferred(&vec![0i32; 512 * 257], 512, 257, &w, 1i64 << 31, |v| v as i64).unwrap(), want);
    }

    #[test]
    fn deferred_rows_refuse_integer_overflow_before_reading_the_matrix() {
        for max_abs in [128, 1i64 << 31] {
            let limit = i128::MAX as u128 / (u64::MAX as u128 * max_abs as u128);
            if let Ok(rows) = usize::try_from(limit + 1) {
                assert!(fold_rows_deferred::<i32, _>(&[], rows, 1, &[], max_abs, |v| v as i64).is_none());
            }
        }
    }

    #[test]
    fn interpolation() {
        // p(x) = 3x^2 + 2x + 5 at 0,1,2 -> 5, 10, 21
        let vals = [Fp2::from_u64(5), Fp2::from_u64(10), Fp2::from_u64(21)];
        assert_eq!(interpolate_eval(&vals, Fp2::from_u64(3)), Fp2::from_u64(38));
        assert_eq!(interpolate_eval(&vals, Fp2::from_u64(0)), Fp2::from_u64(5));
    }
}
