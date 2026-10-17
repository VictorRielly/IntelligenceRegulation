//! UNCOMPILED / UNAPPLIED. Local helper for the owner's mixed table adapter.
//! Construct from native Tab::Eq before table_of/eq_cube. Original Tab metadata,
//! ordering, extension targets and verifier remain authoritative. Generic row,
//! total and census must call at(); only an internally audited SC_SZC bracket
//! dependency list may omit Eq rows from cur/dif/sample advancement.
use crate::field::Fp2;

pub(super) struct SymbolicEq {
    n: usize,
    start: usize,
    point: Vec<Fp2>,
    bound: usize,
    scale: Fp2,
}

impl SymbolicEq {
    pub(super) fn new(n: usize, start: usize, point: &[Fp2]) -> Self {
        assert!(n < usize::BITS as usize && start <= n && point.len() <= n-start);
        Self { n, start, point:point.to_vec(), bound:0, scale:Fp2::ONE }
    }
    pub(super) fn at(&self, index: usize) -> Fp2 {
        assert!(index < (1usize << (self.n-self.bound)));
        self.point.iter().enumerate().fold(self.scale, |a,(k,w)| {
            let axis=self.start+k;
            if axis < self.bound { a }
            else {
                let factor=if ((index >> (self.n-1-axis)) & 1)==1 { *w }
                    else { Fp2::ONE.sub(*w) };
                a.mul(factor)
            }
        })
    }
    pub(super) fn bind(&mut self, r: Fp2) {
        assert!(self.bound < self.n);
        if self.bound >= self.start && self.bound-self.start < self.point.len() {
            let w=self.point[self.bound-self.start];
            self.scale=self.scale.mul(Fp2::ONE.sub(w).mul(Fp2::ONE.sub(r)).add(w.mul(r)));
        }
        self.bound+=1;
    }
    pub(super) fn terminal(&self) -> Fp2 {
        assert_eq!(self.bound,self.n);
        self.scale
    }
}

// Owner integration contract, deliberately not an unaudited opaque-Fn API:
// 1. The SC_SZC constructor owns the bracket and its dependencies; validate
//    native Eq positions/points/start and all non-Eq index ranges there.
// 2. Build mixed entries with the explicit n even when entry[0] is Eq.
// 3. Every part scans all original data pairs; cur/dif retain original arity.
//    Read/difference/advance only the internally derived live indices. Use
//    a debug instrumented reader that detects any dead-slot consumption.
// 4. Group factors/suffixes/brackets/degrees/actual claims/recovery/fallback
//    stay exactly as grouped.rs. Bind every original entry once after parts.
// 5. Return all original finals in order, including these public Eq scales.
// 6. Generic total/census/materialized small test oracle use exact at(index).
//    Unknown bracket dependencies keep exact reads; no private-value checks.
// 7. Extension and verifier consume the original full polynomial, not the
//    reduced bracket. Public Eq target is zero at EVERY extension round.
