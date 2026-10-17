//! UNCOMPILED, UNAPPLIED Rust sketch for public shape support, not ZK masks.
//! Native shape/profile and tiling admission stay with the caller. Bind MSB.
//! No table allocation proportional to context; no field arithmetic in at().
use crate::field::Fp2;

#[derive(Clone, Copy)]
pub struct Axis { pub start: usize, pub bits: usize, pub limit: usize }

pub struct Support {
    n: usize,
    next: usize,
    axes: Vec<Axis>,
    cursor: usize,
    prefix: Fp2,
    lo: Fp2,
    hi: Fp2,
}

impl Support {
    pub fn new(n: usize, mut axes: Vec<Axis>) -> Result<Self, &'static str> {
        if n >= usize::BITS as usize { return Err("support dimension"); }
        axes.sort_by_key(|a| a.start);
        let mut end = 0;
        for a in &axes {
            let stop = a.start.checked_add(a.bits).ok_or("support extent")?;
            if a.start < end || stop > n || a.limit > (1usize << a.bits) {
                return Err("support extent or overlapping axes");
            }
            end = stop;
        }
        axes.retain(|a| a.limit != 1usize << a.bits);
        let mut s = Self { n, next: 0, axes, cursor: 0,
            prefix: Fp2::ONE, lo: Fp2::ZERO, hi: Fp2::ONE };
        s.normalize();
        Ok(s)
    }

    fn normalize(&mut self) {
        while let Some(a) = self.axes.get(self.cursor) {
            if self.next < a.start+a.bits { break; }
            self.prefix = self.lo;
            self.cursor += 1;
            self.lo = Fp2::ZERO;
            self.hi = self.prefix;
        }
    }

    pub fn at(&self, index: usize) -> Result<Fp2, &'static str> {
        if index >= 1usize << (self.n-self.next) { return Err("support index"); }
        let Some(active) = self.axes.get(self.cursor) else { return Ok(self.prefix); };
        for a in &self.axes[self.cursor+1..] {
            let x = (index >> (self.n-a.start-a.bits)) & ((1usize << a.bits)-1);
            if x >= a.limit { return Ok(Fp2::ZERO); }
        }
        let remaining = active.start+active.bits-self.next.max(active.start);
        let mask = (1usize << remaining)-1;
        let x = (index >> (self.n-active.start-active.bits)) & mask;
        Ok(if x < (active.limit & mask) { self.hi } else { self.lo })
    }

    pub fn bind(&mut self, r: Fp2) -> Result<(), &'static str> {
        if self.next == self.n { return Err("support overbind"); }
        if let Some(a) = self.axes.get(self.cursor) {
            if self.next >= a.start {
                let bit = a.start+a.bits-self.next-1;
                if (a.limit >> bit) & 1 == 1 {
                    self.lo = self.hi.add(r.mul(self.lo.sub(self.hi)));
                } else {
                    self.hi = self.lo.add(Fp2::ONE.sub(r).mul(self.hi.sub(self.lo)));
                }
            }
        }
        self.next += 1;
        self.normalize();
        Ok(())
    }

    pub fn terminal(&self) -> Result<Fp2, &'static str> {
        if self.next != self.n { return Err("support premature terminal"); }
        Ok(self.prefix)
    }
}
