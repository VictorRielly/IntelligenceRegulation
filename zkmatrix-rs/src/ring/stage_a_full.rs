// [UPERF3-SS] U-PERF3 round 10, lane SS — THE COMMITTED-h ENCODING
// (spec: docs/zkmatrix-poc/U_PERF3_COMMITTED_H.md §3, rungs V1-V4).
//
// FULL-mode routing of the Stage-A pass (bin: uperf_a_gg_pass, the
// [UPERF3-GG] selector driver; `uperf-a pass [layers] [t] full`). Range
// mode is lane RR's and stays byte-identical; everything here is reached
// from the driver's Full-mode branches only, through the ONE dispatch line
// in ring/stage_a.rs (`pub use super::stage_a_full as full;`).
//
// WHAT THE act-h GROUP IS (read from the code, not from the memo): the
// third commitment group of lane GG's full mode holds the LogUp HELPER
// h_i = 1/(alpha - key_i) of the two SiLU pair families — a K-field
// element per looked-up element (16 coordinates x l0_q = 16 base-4
// digits = 256 digit values = 2 digit rings PER ELEMENT), committed at
// the blinder class after alpha is drawn (the F2 ordering). It is NOT a
// range-fact commitment of the activation h; nothing in the v3 entry
// list (Hlo/Hhi/H/Rh) stands in for it. The memo's candidate C2 ("route
// h's range facts as 256-row lookups over the existing limbs") therefore
// does not make the act-h group vanish — a lookup instance NEEDS a helper
// column of its own, and the S2 helper costs 2 rings/element against
// w/128 rings/element for the width planes it would replace (32x MORE
// for an 8-bit fact). Rung V1 measures exactly that on the real pass;
// rung V2 counts it at 12x512 and 8B; rung V3 then makes full mode fit
// the 15 GiB box by shrinking the helper of the lookups that are
// unavoidable (the SiLU tables) — the kappa-level PARTIAL-FRACTION
// helper: commit h at node granularity (one K element per 2^kappa
// consecutive keys, h_node = sum_{i in node} 1/(alpha - key_i)) and
// prove h_node * prod_i (alpha - key_i) = sum_i prod_{i' != i} (alpha -
// key_i') by ONE degree-(2^kappa + 2) zero-check whose final claims are
// the 2^kappa key MLEs at (b || x*) over the EXISTING member commitments
// plus h(x*) / h_sum over the (2^kappa-times smaller) act-h block. The
// LogUp sum identity sum_nodes h_node = sum_j m_j / (alpha - t_j) is
// unchanged. kappa = 0 is exactly the S2 form.
//
// Ownership (round-10 lane SS): this NEW file + its `pub mod` line; ONE
// dispatch line in ring/stage_a.rs; the driver's Full-mode branches and
// ADDITIVE `uperf-a` subcommands in the bin. zc_range / fold / eval_proof
// / kfield / sumcheck / gkr / the v3 statement are READ-ONLY reuse —
// anything needed-but-private is reimplemented here, never edited there.

use super::kfield::{KElem, KField, K_DEG};
use super::D;

// ---------------------------------------------------------------------------
// Rung 0/V2: the ring arithmetic of the committed objects (no proving).

/// Digit rings of a committed K-valued helper column over `n_el` elements
/// at `coords` K coordinates (16 = the full K element; 4 = an E_4
/// element) and `l0` digits per coordinate (the blinder class l0_q = 16 at
/// e0 = 2). One value ring holds D = 128 coordinates.
pub fn helper_rings(n_el: usize, coords: usize, l0: usize) -> usize {
    (n_el * coords).div_ceil(D) * l0
}

/// Digit rings of `w` committed width planes (e0 = 1, l0 = 1) over `n_el`
/// elements padded to `n_pad` per plane — the range-mode planes tensor.
pub fn planes_rings(n_pad: usize, w: usize) -> usize {
    (w * n_pad).div_ceil(D)
}

/// Digit rings of the kappa-level partial-fraction helper: one K element
/// per 2^kappa elements.
pub fn pf_helper_rings(n_el: usize, kappa: usize, l0: usize) -> usize {
    helper_rings(n_el >> kappa, K_DEG, l0)
}

/// The round-polynomial degree of the kappa-level relation eq * (h * Q -
/// P): 1 (eq) + 1 (h) + 2^kappa (Q, the product of the node's keys).
pub fn pf_degree(kappa: usize) -> usize {
    2 + (1usize << kappa)
}

/// The rung plan, printed by `uperf-a full-plan` (rung 0).
pub fn plan_lines() -> Vec<&'static str> {
    vec![
        "V1  one 8-bit range fact (nrw-88, the h8 narrowing of layer 0) as a 256-row identity LogUp over the EXISTING h8 commitment in the full-mode path; differential vs the planes (zc) form and the descent (table) form; rings counted",
        "V2  the helper/multiplicity commit bill counted at 12x512 and 32x512 8B: S2 K-helper, E_4 helper, kappa-level partial-fraction helper, width planes, descent",
        "V3  full mode's SiLU helper routed through the kappa-level partial-fraction form; `uperf-a pass 12 128 full` peak RSS vs range mode",
        "V4  the 8B full-mode counted row on lane OO's baseline (commit ~61 GB, pass peak lvl-0 ~72 GB)",
    ]
}

/// Sanity: the helper arithmetic reproduces lane GG's measured act-h
/// n_0 rows (3x16: 196,608; 12x128: 6,291,456 at the m125 shape f = 2048).
pub fn gg_act_h_rings(layers: usize, t: usize, f_pad: usize, l0_q: usize) -> usize {
    helper_rings(layers * t * f_pad, K_DEG, l0_q)
}

#[allow(dead_code)]
fn _kelem_marker(_: &KElem, _: &KField) {}
