// U-K1 (M4_LOOKUP_DESIGN.md Section 8): scalar arithmetic for the
// lookup's challenge/soundness field K = GF(q^16), realized as the
// residue field of CRT slot 0 of the k = 8 split:
//
//     K := Z_q[Y] / (Y^16 - s0),   s0 = slot_roots[0],
//
// |K| = q^16 ~ 2^496 at q31 — the field every LogUp/GKR challenge,
// round polynomial and MLE value lives in. Elements are length-16
// coefficient vectors (little-endian in Y); multiplication is the
// existing slot kernel (`slot_mul_g`), inversion is Fermat
// (a^(q^16 - 2), test/verifier-grade — the GKR prover never inverts,
// which is the point of the projective accumulation).
//
// LANE NOTE (the 8-lane cost model, Section 2.2 of the design): a full
// ring multiplication executes 8 INDEPENDENT slot-field multiplications
// — one per CRT slot — which is what prices a K-mult at ~1/8th of a
// ring mult. The lanes are NOT interchangeable as K-instances: slot j
// computes in Z_q[Y]/(Y^16 - s_j), and s_j/s0 is not a 16th power in
// Z_q (the slot roots are distinct primitive-root powers), so
// transporting a canonical-K value into lane j requires the field
// isomorphism phi_j : Y -> c_j Y with c_j a 16th root of s_j/s0 — which
// lives only in the extension. Bulk kernels must therefore either keep
// each value in one lane for its whole life (the U-K3 layout) or apply
// an explicit 16x16 change-of-basis per transport; `lane_split`/
// `lane_merge` below expose the per-lane view and the U-K1 battery pins
// the per-lane consistency (ring mult == 8 slot-field mults, each in
// its own field). Scalar K arithmetic (this module) is the semantic
// reference; lane routing is a U-K3 throughput decision.

use sha2::{Digest, Sha256};

use super::{D, Poly, RingCtx, XofReader, Zq, crt_merge, crt_split, slot_mul_g};

/// Extension degree of the slot field at the frozen point (D / k).
pub const K_DEG: usize = 16;

/// One K-element: K_DEG base-field coefficients, little-endian in Y.
pub type KElem = Vec<u64>;

/// The canonical slot field: slot 0's binomial.
pub struct KField {
    pub zq: Zq,
    /// The binomial root: Y^K_DEG = s in K.
    pub s: u64,
    /// Little-endian u64 limbs of q^K_DEG - 2 (the Fermat inversion
    /// exponent), precomputed once.
    inv_exp: Vec<u64>,
}

/// Little-endian limbs of q^K_DEG - delta (delta in {1, 2}).
fn q_pow_minus(q: u64, delta: u64) -> Vec<u64> {
    let mut limbs: Vec<u64> = vec![1];
    for _ in 0..K_DEG {
        let mut carry: u128 = 0;
        for l in limbs.iter_mut() {
            let wide = *l as u128 * q as u128 + carry;
            *l = wide as u64;
            carry = wide >> 64;
        }
        if carry != 0 {
            limbs.push(carry as u64);
        }
    }
    // Subtract delta (q^K_DEG ends in ...001? no — just do the borrow).
    let mut borrow = delta;
    for l in limbs.iter_mut() {
        let (v, under) = l.overflowing_sub(borrow);
        *l = v;
        borrow = u64::from(under);
        if borrow == 0 {
            break;
        }
    }
    assert_eq!(borrow, 0);
    limbs
}

impl KField {
    /// The canonical instance for a ring context: slot 0 of the CRT
    /// split. Asserts the frozen slot degree.
    pub fn new(ctx: &RingCtx) -> KField {
        assert_eq!(ctx.slot_deg, K_DEG, "slot field expects the frozen k = 8 split");
        let q = ctx.zq.q;
        KField { zq: Zq::new(q), s: ctx.slot_roots[0], inv_exp: q_pow_minus(q, 2) }
    }

    pub fn zero(&self) -> KElem {
        vec![0; K_DEG]
    }

    pub fn one(&self) -> KElem {
        self.embed(1)
    }

    /// The field generator Y (the design's fixed fusion element kappa).
    pub fn gen_y(&self) -> KElem {
        let mut e = self.zero();
        e[1] = 1;
        e
    }

    /// Z_q -> K subfield embedding (constant coefficient).
    pub fn embed(&self, x: u64) -> KElem {
        let mut e = self.zero();
        e[0] = x % self.zq.q;
        e
    }

    /// Coordinate c of a K-element (a PUBLIC Z_q-linear functional —
    /// the E4 landing reads K-values coordinate-wise).
    pub fn coord(&self, a: &KElem, c: usize) -> u64 {
        a[c]
    }

    pub fn is_zero(&self, a: &KElem) -> bool {
        a.iter().all(|&x| x == 0)
    }

    pub fn add(&self, a: &KElem, b: &KElem) -> KElem {
        a.iter().zip(b.iter()).map(|(&x, &y)| self.zq.add(x, y)).collect()
    }

    pub fn sub(&self, a: &KElem, b: &KElem) -> KElem {
        a.iter().zip(b.iter()).map(|(&x, &y)| self.zq.sub(x, y)).collect()
    }

    pub fn neg(&self, a: &KElem) -> KElem {
        a.iter().map(|&x| self.zq.neg(x)).collect()
    }

    /// Scale by a base-field scalar.
    pub fn scale(&self, c: u64, a: &KElem) -> KElem {
        a.iter().map(|&x| self.zq.mul(c, x)).collect()
    }

    pub fn mul(&self, a: &KElem, b: &KElem) -> KElem {
        slot_mul_g(&self.zq, a, b, self.s, K_DEG)
    }

    pub fn sq(&self, a: &KElem) -> KElem {
        self.mul(a, a)
    }

    /// b^e for little-endian u64 limbs e (MSB-first square-and-multiply).
    pub fn pow_limbs(&self, b: &KElem, e_limbs: &[u64]) -> KElem {
        let mut acc = self.one();
        let mut started = false;
        for limb in e_limbs.iter().rev() {
            for bit in (0..64).rev() {
                if started {
                    acc = self.sq(&acc);
                }
                if (limb >> bit) & 1 == 1 {
                    if started {
                        acc = self.mul(&acc, b);
                    } else {
                        acc = b.clone();
                        started = true;
                    }
                }
            }
        }
        acc
    }

    pub fn pow(&self, b: &KElem, e: u64) -> KElem {
        self.pow_limbs(b, &[e])
    }

    /// Fermat inversion: a^(q^16 - 2). Verifier/test-grade cost
    /// (~750 slot mults); the GKR prover never calls it.
    pub fn inv(&self, a: &KElem) -> KElem {
        assert!(!self.is_zero(a), "K inversion of zero");
        self.pow_limbs(a, &self.inv_exp)
    }

    /// Uniform K-element from an XOF stream (16 rejection-free
    /// next_field draws — the challenge sampler for alpha/rho/r/mu).
    pub fn uniform(&self, reader: &mut XofReader) -> KElem {
        (0..K_DEG).map(|_| reader.next_field(self.zq.q)).collect()
    }

    /// Canonical transcript bytes (little-endian u64 per coefficient) —
    /// every K-element that enters a hash uses exactly this encoding.
    pub fn bytes(&self, a: &KElem) -> Vec<u8> {
        let mut out = Vec::with_capacity(K_DEG * 8);
        for &c in a {
            out.extend_from_slice(&c.to_le_bytes());
        }
        out
    }
}

// ---------------------------------------------------------------------------
// The per-lane view of a ring element (the 8-lane cost-model anchor).

/// Split a ring element into its 8 slot-field residues: lane j is a
/// K_DEG-coefficient element of Z_q[Y]/(Y^16 - slot_roots[j]) — lane
/// j's OWN field, see the module header's lane note.
pub fn lane_split(ctx: &RingCtx, a: &Poly) -> Vec<KElem> {
    let buf = crt_split(ctx, a);
    (0..ctx.k).map(|j| buf[j * ctx.slot_deg..(j + 1) * ctx.slot_deg].to_vec()).collect()
}

/// Inverse of lane_split.
pub fn lane_merge(ctx: &RingCtx, lanes: &[KElem]) -> Poly {
    assert_eq!(lanes.len(), ctx.k);
    let mut buf = vec![0u64; D];
    for (j, lane) in lanes.iter().enumerate() {
        assert_eq!(lane.len(), ctx.slot_deg);
        buf[j * ctx.slot_deg..(j + 1) * ctx.slot_deg].copy_from_slice(lane);
    }
    crt_merge(ctx, &mut buf);
    buf
}

/// LKP-5: the digest freezing the slot-field constants — q, k,
/// slot_deg and every slot root. Any parameter move that changes the
/// field the lookup transcript lives in must trip this row.
pub fn slot_field_digest(ctx: &RingCtx) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lkp5-slot-field-v1");
    hasher.update(ctx.zq.q.to_le_bytes());
    hasher.update((ctx.k as u64).to_le_bytes());
    hasher.update((ctx.slot_deg as u64).to_le_bytes());
    for &r in &ctx.slot_roots {
        hasher.update(r.to_le_bytes());
    }
    hasher.finalize().into()
}
