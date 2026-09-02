//! Radix-2 NTT over F_p (iterative Cooley-Tukey, in place, bit-reversed
//! input ordering handled internally) and the Reed-Solomon row encoder
//! used by the Ligero-class commitment: a row of `n` coefficients is
//! evaluated at the `n * inv_rate` roots of unity (zero-padded NTT).

use crate::field::Fp;

/// Precomputed twiddles for NTTs of size <= 2^max_log.
pub struct NttTables {
    pub max_log: u32,
    /// roots[k] = omega_{2^k}, k = 0..=max_log
    pub roots: Vec<Fp>,
    pub inv_roots: Vec<Fp>,
    /// Per level twiddles for the largest size, laid out for the size-2^max_log transform;
    /// smaller transforms use strides.
    twiddles: Vec<Fp>,
    inv_twiddles: Vec<Fp>,
}

impl NttTables {
    pub fn new(max_log: u32) -> NttTables {
        let mut roots = Vec::with_capacity(max_log as usize + 1);
        let mut inv_roots = Vec::with_capacity(max_log as usize + 1);
        for k in 0..=max_log {
            let r = Fp::two_adic_root(k);
            roots.push(r);
            inv_roots.push(r.inv());
        }
        let n = 1usize << max_log;
        let half = n / 2;
        let w = roots[max_log as usize];
        let wi = inv_roots[max_log as usize];
        let mut twiddles = Vec::with_capacity(half.max(1));
        let mut inv_twiddles = Vec::with_capacity(half.max(1));
        let mut cur = Fp::ONE;
        let mut curi = Fp::ONE;
        for _ in 0..half.max(1) {
            twiddles.push(cur);
            inv_twiddles.push(curi);
            cur = cur.mul(w);
            curi = curi.mul(wi);
        }
        NttTables { max_log, roots, inv_roots, twiddles, inv_twiddles }
    }

    /// In-place forward NTT of `a` (length 2^log_n): coefficients -> evaluations
    /// at omega^i, i = 0..n (natural order).
    pub fn forward(&self, a: &mut [Fp]) {
        self.transform(a, false);
    }

    /// In-place inverse NTT: evaluations -> coefficients.
    pub fn inverse(&self, a: &mut [Fp]) {
        self.transform(a, true);
        let n = a.len() as u64;
        let ninv = Fp::new(n).inv();
        for v in a.iter_mut() {
            *v = v.mul(ninv);
        }
    }

    fn transform(&self, a: &mut [Fp], inverse: bool) {
        let n = a.len();
        assert!(n.is_power_of_two());
        let log_n = n.trailing_zeros();
        assert!(log_n <= self.max_log, "ntt size 2^{log_n} exceeds tables (2^{})", self.max_log);
        if n == 1 { return; }
        // bit reversal
        let mut j = 0usize;
        for i in 1..n {
            let mut bit = n >> 1;
            while j & bit != 0 {
                j ^= bit;
                bit >>= 1;
            }
            j |= bit;
            if i < j {
                a.swap(i, j);
            }
        }
        let tw = if inverse { &self.inv_twiddles } else { &self.twiddles };
        let max_n = 1usize << self.max_log;
        let mut len = 2usize;
        while len <= n {
            let half = len / 2;
            let stride = max_n / len; // twiddle stride in the max-size table
            let mut i = 0;
            while i < n {
                let (lo, hi) = a[i..i + len].split_at_mut(half);
                for k in 0..half {
                    let w = tw[k * stride];
                    let u = lo[k];
                    let v = hi[k].mul(w);
                    lo[k] = u.add(v);
                    hi[k] = u.sub(v);
                }
                i += len;
            }
            len <<= 1;
        }
    }

    /// Reed-Solomon encode a row: `coeffs` (length n) -> evaluations at
    /// the (n * inv_rate)-th roots of unity, written into `out`
    /// (length n * inv_rate).
    pub fn rs_encode(&self, coeffs: &[Fp], out: &mut [Fp]) {
        let n = coeffs.len();
        let nn = out.len();
        assert!(nn >= n && nn % n == 0);
        out[..n].copy_from_slice(coeffs);
        for v in out[n..].iter_mut() {
            *v = Fp::ZERO;
        }
        self.forward(out);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn naive_eval(coeffs: &[Fp], x: Fp) -> Fp {
        let mut acc = Fp::ZERO;
        for c in coeffs.iter().rev() {
            acc = acc.mul(x).add(*c);
        }
        acc
    }

    #[test]
    fn ntt_matches_naive_and_roundtrips() {
        let t = NttTables::new(12);
        for log_n in [0u32, 1, 2, 3, 6, 10, 12] {
            let n = 1usize << log_n;
            let mut s = 0xdead_beefu64 + log_n as u64;
            let coeffs: Vec<Fp> = (0..n).map(|_| { s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407); Fp::new(s >> 1) }).collect();
            let mut a = coeffs.clone();
            t.forward(&mut a);
            let w = t.roots[log_n as usize];
            let mut x = Fp::ONE;
            for i in 0..n.min(64) {
                assert_eq!(a[i], naive_eval(&coeffs, x), "log_n {log_n} i {i}");
                x = x.mul(w);
            }
            t.inverse(&mut a);
            assert_eq!(a, coeffs);
        }
    }

    #[test]
    fn rs_encode_is_evaluation() {
        let t = NttTables::new(10);
        let n = 64;
        let coeffs: Vec<Fp> = (0..n).map(|i| Fp::new((i as u64 * 7919 + 13) % 1000)).collect();
        let mut out = vec![Fp::ZERO; 4 * n];
        t.rs_encode(&coeffs, &mut out);
        let w = t.roots[8];
        let mut x = Fp::ONE;
        for i in 0..4 * n {
            assert_eq!(out[i], naive_eval(&coeffs, x));
            x = x.mul(w);
        }
    }
}
