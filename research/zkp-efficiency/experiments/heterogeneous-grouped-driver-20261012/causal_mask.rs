//! Unapplied, UNCOMPILED Rust sketch for the owner. Python is the tested code.
//! The round adapter must keep all original table positions and cube length.
use crate::field::Fp2;

pub struct CausalMask {
    leading: usize,
    token_bits: usize,
    n: usize,
    bound: usize,
    lo: Vec<Fp2>,
    hi: Vec<Fp2>,
}

impl CausalMask {
    pub fn n_vars(&self) -> usize { self.n }
    pub fn bound(&self) -> usize { self.bound }

    pub fn new(n: usize, t_pad: usize) -> Result<Self, &'static str> {
        if !t_pad.is_power_of_two() || n >= usize::BITS as usize {
            return Err("causal mask public dimensions");
        }
        let token_bits = t_pad.trailing_zeros() as usize;
        let leading = n.checked_sub(2 * token_bits)
            .ok_or("causal mask cube too short")?;
        Ok(Self { leading, token_bits, n, bound: 0,
            lo: vec![Fp2::ZERO], hi: vec![Fp2::ONE] })
    }

    /// Read a residual Boolean row. Only a round adapter calls this;
    /// group closures continue consuming their original scalar table indices.
    pub fn at(&self, index: usize) -> Result<Fp2, &'static str> {
        if index >= 1usize << (self.n - self.bound) {
            return Err("causal mask residual index");
        }
        if self.bound >= self.leading + self.token_bits {
            return Ok(self.hi[index]);
        }
        let k = self.bound.saturating_sub(self.leading).min(self.token_bits);
        let tpad = 1usize << self.token_bits;
        let suffix_extent = 1usize << (self.token_bits - k);
        let j = index & (tpad - 1);
        let t = (index >> self.token_bits) & (suffix_extent - 1);
        let prefix_j = j >> (self.token_bits - k);
        let suffix_j = j & (suffix_extent - 1);
        Ok(if suffix_j <= t { self.hi[prefix_j] } else { self.lo[prefix_j] })
    }

    /// Called ONCE after round reduction, never inside shared Fn+Send+Sync.
    pub fn bind(&mut self, r: Fp2) -> Result<(), &'static str> {
        if self.bound == self.n { return Err("causal mask already terminal"); }
        if self.bound < self.leading {
            // Original mask is one on every padded/lifted head slot.
        } else if self.bound < self.leading + self.token_bits {
            let mut lo = Vec::with_capacity(2 * self.lo.len());
            let mut hi = Vec::with_capacity(2 * self.hi.len());
            for (&a, &b) in self.lo.iter().zip(&self.hi) {
                let middle = a.add(r.mul(b.sub(a)));
                lo.extend([middle, a]);
                hi.extend([b, middle]);
            }
            self.lo = lo;
            self.hi = hi;
            if self.bound + 1 == self.leading + self.token_bits {
                // Release capacity, unlike clear()/truncate().
                self.lo = Vec::new();
            }
        } else {
            let half = self.hi.len() / 2;
            for i in 0..half {
                self.hi[i] = self.hi[i].add(r.mul(self.hi[i + half].sub(self.hi[i])));
            }
            self.hi.truncate(half);
        }
        self.bound += 1;
        Ok(())
    }

    pub fn terminal(&self) -> Result<Fp2, &'static str> {
        if self.bound != self.n { return Err("causal mask not terminal"); }
        self.at(0)
    }
}

/// Verifier public MLE; caller still multiplies by EVERY (1-e) selector.
pub fn eval_causal_mask(n: usize, t_pad: usize, rho: &[Fp2]) -> Result<Fp2, &'static str> {
    let shape = CausalMask::new(n, t_pad)?;
    if rho.len() != n { return Err("causal mask point arity"); }
    let offset = shape.leading;
    let mut out = Fp2::ONE;
    for i in (0..shape.token_bits).rev() {
        let t = rho[offset + i];
        let j = rho[offset + shape.token_bits + i];
        let not_j = Fp2::ONE.sub(j);
        let eq = Fp2::ONE.sub(t).mul(not_j).add(t.mul(j));
        out = t.mul(not_j).add(eq.mul(out));
    }
    Ok(out)
}
