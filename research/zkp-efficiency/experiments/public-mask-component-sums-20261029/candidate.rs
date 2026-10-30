//! Research component only. Prepared public data belongs to one current call.
use crate::field::{Fp, Fp2};
use crate::eq_table_msb;

pub struct PublicWeights {
    point: Vec<Fp2>,
    eq: Vec<Fp2>,
}
impl PublicWeights {
    pub fn new(point: &[Fp2]) -> Self {
        Self { point: point.to_vec(), eq: eq_table_msb(point) }
    }
    pub fn dot(&self, point: &[Fp2], xs: &[Fp], ys: &[Fp]) -> Fp2 {
        assert_eq!(self.point, point);
        assert_eq!(self.eq.len(), xs.len());
        assert_eq!(xs.len(), ys.len());
        let (mut a, mut b, mut c) = (Fp::ZERO, Fp::ZERO, Fp::ZERO);
        for ((e, x), y) in self.eq.iter().zip(xs).zip(ys) {
            a = a.add(e.c0.mul(*x));
            b = b.add(e.c1.mul(*y));
            c = c.add(e.c0.add(e.c1).mul(x.add(*y)));
        }
        Fp2::new(a.add(b.mul(Fp(7))), c.sub(a).sub(b))
    }
}

pub struct PreparedWeights {
    weights: PublicWeights,
    sums: Vec<Fp>,
}
impl PreparedWeights {
    pub fn new(point: &[Fp2]) -> Self {
        let weights = PublicWeights::new(point);
        let sums = weights.eq.iter().map(|e| e.c0.add(e.c1)).collect();
        Self { weights, sums }
    }
    pub fn dot(&self, point: &[Fp2], xs: &[Fp], ys: &[Fp]) -> Fp2 {
        assert_eq!(self.weights.point, point);
        assert_eq!(self.weights.eq.len(), xs.len());
        assert_eq!(xs.len(), ys.len());
        let (mut a, mut b, mut c) = (Fp::ZERO, Fp::ZERO, Fp::ZERO);
        for (((e, s), x), y) in self.weights.eq.iter().zip(&self.sums).zip(xs).zip(ys) {
            a = a.add(e.c0.mul(*x));
            b = b.add(e.c1.mul(*y));
            c = c.add(s.mul(x.add(*y)));
        }
        Fp2::new(a.add(b.mul(Fp(7))), c.sub(a).sub(b))
    }
    pub fn sum_payload_bytes(&self) -> usize { self.sums.len() * 8 }
}
