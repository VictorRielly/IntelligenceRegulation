// [UAGB1-BG] U-AG-B1 wave 3, lane BG: PASS-LEVEL COMPOSITION — BF's
// 12-layer real-weights pass statement -> BE's IXF folded instance
// families -> BD's per-group batched opening + eval proof (W-C
// two-group layout, one eval proof per commitment group).
//
// This module is the LIBRARY face of the composition: the pass group
// registry (per-layer tensors under the frozen exact-digit class
// table), the GENERALIZED multi-claim value-weight assembly (built
// around eval_proof::ClaimKernelCtx's one-kernel-per-tensor limit —
// an API-change export is filed for lane BH's zone; eval_proof.rs is
// NOT edited), the folded-requant table/combiner builders on
// fold.rs's public scheduled-sumcheck API, the counted-byte
// accounting, and the DERIVED 125M pass-budget expectation (the BA
// rule: derived at 125M shapes from the design formulas, never
// extrapolated from the 7B rows).
//
// COMPOSED RELATION SET (wave-3 machinery state, stated honestly):
// 3 folded matmuls + 1 folded Hadamard zero-check + 4 folded requant
// zero-checks (public layer-coefficient MLE from the statement shift
// table) + public-tensor binding claims (X/z; weights never — the
// FD 6.4 W-A rejection ruling). NOT composed: the table-membership
// facts (SiLU LookupAt + RangeLookups) — the folded masked descent
// is the recorded unbuilt piece (BE WILL-NOT-DO; multi-wave C2
// lift); their line rides the derived expectation [MODEL].
//
// Privacy modes (Amendment A1, manifest::ModeDecl): P0 bare; P2 =
// FP-L3 split (weight group Tier-Z masked ONCE per pass — the
// E2/E4 carve-out, act group bare); P1/P3 REFUSED this wave (the
// act-side mask + T_blind instance masking are absent). I-6 holds
// everywhere outside the priced Tier-Z floor response.

use super::kfield::{KElem, KField, K_DEG};
use super::{poly_zero, Poly, Zq, D};
use std::rc::Rc;

// ---------------------------------------------------------------------------
// The pass claim set: additive multi-claim product-form weights.
// (skeleton — filled by the build stages)

/// One product-form weight contribution of a claim to ONE registered
/// (per-layer) tensor: weight of value f = scale * row[f / cols] *
/// col[f % cols]. A stacked claim contributes to each of its layers'
/// tensors with scale = nu_claim * eq(l*, layer).
#[derive(Clone)]
pub struct ClaimContrib {
    pub tensor_idx: usize,
    pub scale: KElem,
    pub row: Rc<Vec<KElem>>,
    pub col: Rc<Vec<KElem>>,
}

/// The per-group claim assembly: contributions bucketed per tensor
/// (additive — the CR-L4a/b mu/nu batching lands additively in the
/// same rows).
pub struct GroupClaims {
    pub per_tensor: Vec<Vec<ClaimContrib>>,
}

impl GroupClaims {
    pub fn new(n_tensors: usize) -> GroupClaims {
        GroupClaims { per_tensor: vec![Vec::new(); n_tensors] }
    }
    pub fn push(&mut self, c: ClaimContrib) {
        let ti = c.tensor_idx;
        self.per_tensor[ti].push(c);
    }
    /// K-weight row of value ring `vr` of tensor `ti` (length D; values
    /// past the tensor tail are zero) — computed on the fly (the
    /// vw-free streaming form; no O(N_values) table exists).
    pub fn kw_value_row(
        &self,
        kf: &KField,
        tensor: &super::eval_proof::AggTensor,
        ti: usize,
        vr: usize,
    ) -> Vec<KElem> {
        let mut out = vec![kf.zero(); D];
        let n = tensor.n_values();
        for c in &self.per_tensor[ti] {
            for (c1, o) in out.iter_mut().enumerate() {
                let f = vr * D + c1;
                if f < n {
                    let w = kf.mul(&c.row[f / tensor.cols], &c.col[f % tensor.cols]);
                    *o = kf.add(o, &kf.mul(&c.scale, &w));
                }
            }
        }
        out
    }
}

/// conj-packed claim-row polys of one digit ring, from the ring's
/// VALUE-row weights (radix-scaled per limb) — the eval_proof bpolys
/// form, generalized to the additive multi-claim weight.
pub fn bpolys_from_kw(zq: &Zq, kw: &[KElem], radix: u64) -> Vec<Poly> {
    let mut rows = vec![poly_zero(); K_DEG];
    for (c1, w) in kw.iter().enumerate() {
        for (cd, row) in rows.iter_mut().enumerate() {
            row[c1] = zq.mul(radix, w[cd]);
        }
    }
    rows.iter().map(|r| super::eval_proof::conj_poly(zq, r)).collect()
}
