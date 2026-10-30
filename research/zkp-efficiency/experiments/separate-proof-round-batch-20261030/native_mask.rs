use crate::native_field::{Fp, Fp2};
#[derive(Clone, Debug)]
pub struct CfsMask {
    pub n_vars: usize,
    pub degree: usize,
    /// coefficients in the layout [a_0, a', a_{0,1..d}, a_{1,1..d}, ..., a_{N-1,1..d}]
    pub coeffs: Vec<Fp2>,
}

impl CfsMask {
    pub fn len(n_vars: usize, degree: usize) -> usize {
        n_vars * degree + 2
    }

    fn a(&self, j: usize, e: usize) -> Fp2 {
        self.coeffs[2 + j * self.degree + (e - 1)]
    }

    /// u_j(X) = sum_e a_{j,e} X^e
    fn u(&self, j: usize, x: Fp2) -> Fp2 {
        let mut acc = Fp2::ZERO;
        let mut xp = Fp2::ONE;
        for e in 1..=self.degree {
            xp = xp.mul(x);
            acc = acc.add(self.a(j, e).mul(xp));
        }
        acc
    }

    /// The weight vector w such that <coeffs, w> = sum_x g(x):
    /// 2^N on a_0, 1 on a', 2^(N-1) on every a_{j,e}.
    pub fn sum_weights(n_vars: usize, degree: usize) -> Vec<Fp2> {
        let mut w = vec![Fp2::from_u64(1u64 << (n_vars - 1)); Self::len(n_vars, degree)];
        w[0] = Fp2::from_u64(1u64 << n_vars);
        w[1] = Fp2::ONE;
        w
    }

    /// The weight vector w such that <coeffs, w> = g(rho).
    pub fn eval_weights(rho: &[Fp2], degree: usize) -> Vec<Fp2> {
        let n = rho.len();
        let mut w = Vec::with_capacity(Self::len(n, degree));
        w.push(Fp2::ONE);
        w.push(rho.iter().fold(Fp2::ONE, |a, r| a.mul(*r)));
        for r in rho {
            let mut xp = Fp2::ONE;
            for _ in 0..degree {
                xp = xp.mul(*r);
                w.push(xp);
            }
        }
        w
    }

    pub fn total(&self) -> Fp2 {
        Self::sum_weights(self.n_vars, self.degree).iter().zip(self.coeffs.iter()).fold(Fp2::ZERO, |a, (w, c)| a.add(w.mul(*c)))
    }

    pub fn eval(&self, rho: &[Fp2]) -> Fp2 {
        assert_eq!(rho.len(), self.n_vars);
        Self::eval_weights(rho, self.degree).iter().zip(self.coeffs.iter()).fold(Fp2::ZERO, |a, (w, c)| a.add(w.mul(*c)))
    }

    /// The round-j message of g at X = 0..=degree, given the earlier challenges.
    pub fn round(&self, j: usize, prev: &[Fp2]) -> Vec<Fp2> {
        assert_eq!(prev.len(), j);
        let n = self.n_vars;
        let half = Fp::new(2).inv();
        let mut base = self.coeffs[0];
        for (i, r) in prev.iter().enumerate() {
            base = base.add(self.u(i, *r));
        }
        for i in j + 1..n {
            base = base.add(self.u(i, Fp2::ONE).mul_base(half));
        }
        let scale = Fp2::from_u64(1u64 << (n - 1 - j));
        let prod_prev = prev.iter().fold(Fp2::ONE, |a, r| a.mul(*r));
        (0..=self.degree)
            .map(|x| {
                let xv = Fp2::from_u64(x as u64);
                scale.mul(base.add(self.u(j, xv))).add(self.coeffs[1].mul(prod_prev).mul(xv))
            })
            .collect()
    }
}

