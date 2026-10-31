//! [ZK60-METAL M3, 2026-10-31] A slot's polynomial, from its expression IR
//! (`slot_ir.rs`, stage 34), as a Metal function `slot_poly(T, cf)`.
//!
//! The IR is the closure's transcription, held to it by
//! `slot_ir_tests::the_slot_ir_evaluates_to_the_closure_at_every_registered_shape_and_slot`
//! (equal field elements at random points of the whole space, every registered
//! shape and slot). The generated function evaluates the same graph: the same
//! nodes in topological order, the same sums of products, coefficient VALUES
//! read from the `cf` buffer. Field arithmetic is exact, so any algebraically
//! equal evaluation gives the same canonical element; the two rewrites made here
//! (a coefficient 1 is not multiplied, a coefficient -1 becomes a negation) are
//! of that kind. Challenge-derived coefficients never enter the source text,
//! only the buffer, so one compiled kernel serves every proof of a shape.

use super::slot_ir::{Coef, CoefProv, Factor, NodeBody, SlotIr};
use crate::field::Fp2;

fn factor(f: &Factor) -> String {
    match f {
        Factor::Table(t) => format!("T[{t}]"),
        Factor::Node(n) => format!("n{n}"),
    }
}

/// `coef * prod(factors)` as one MSL expression; coefficients go to `cf`
fn product(coef: &Coef, factors: &[String], cf: &mut Vec<Fp2>) -> String {
    let mut p = match factors.split_first() {
        None => None,
        Some((first, rest)) => Some(rest.iter().fold(first.clone(), |a, x| format!("f2_mul({a}, {x})"))),
    };
    match coef.prov {
        CoefProv::One => p.take().unwrap_or_else(|| "f2(1UL, 0UL)".to_string()),
        CoefProv::NegOne => format!("f2_neg({})", p.take().unwrap_or_else(|| "f2(1UL, 0UL)".to_string())),
        _ => {
            let i = cf.len();
            cf.push(coef.value);
            match p {
                None => format!("CF(cf, {i}u)"),
                Some(e) => format!("f2_mul(CF(cf, {i}u), {e})"),
            }
        }
    }
}

/// The MSL source of `slot_poly` for `ir`, and its coefficient buffer.
pub(super) fn msl_poly(ir: &SlotIr) -> (String, Vec<Fp2>) {
    let mut cf: Vec<Fp2> = Vec::new();
    let mut s = String::new();
    s.push_str(&format!("// slot {} ({}) at {}: {} tables, {} nodes, {} terms\n", ir.slot, ir.name, ir.profile, ir.tables.len(), ir.nodes.len(), ir.terms.len()));
    s.push_str("inline fp2 slot_poly(thread const fp2 *T, constant ulong *cf) {\n");
    for n in &ir.nodes {
        match &n.body {
            NodeBody::Affine { konst, terms } => {
                let mut e = product(konst, &[], &mut cf);
                for (c, t) in terms {
                    let p = product(c, &[format!("T[{t}]")], &mut cf);
                    e = format!("f2_add({e}, {p})");
                }
                s.push_str(&format!("    fp2 n{} = {e};\n", n.id));
            }
            NodeBody::Sum { subterms } => {
                s.push_str(&format!("    fp2 n{} = f2(0UL, 0UL);\n", n.id));
                for st in subterms {
                    let fs: Vec<String> = st.factors.iter().map(factor).collect();
                    let p = product(&st.coef, &fs, &mut cf);
                    s.push_str(&format!("    n{0} = f2_add(n{0}, {p});\n", n.id));
                }
            }
        }
    }
    s.push_str("    fp2 out = f2(0UL, 0UL);\n");
    for t in &ir.terms {
        let mut fs: Vec<String> = t.wrapper.iter().map(|w| format!("T[{w}]")).collect();
        fs.extend(t.inner.iter().map(factor));
        let p = product(&t.coef, &fs, &mut cf);
        s.push_str(&format!("    out = f2_add(out, {p});\n"));
    }
    s.push_str("    return out;\n}\n");
    (s, cf)
}

/// The runtime guard: `ir.eval(v) == poly(v)` at eight pseudo-random points of
/// the whole space (a local splitmix stream seeded by the slot number; it draws
/// nothing from the proof's transcript or randomness).
pub(super) fn ir_matches_closure(ir: &SlotIr, poly: &(dyn Fn(&[Fp2]) -> Fp2 + Sync), slot: usize) -> bool {
    use crate::field::Fp;
    let mut z = 0x9E37_79B9_7F4A_7C15u64 ^ (slot as u64).wrapping_mul(0xD1B5_4A32_D192_ED03);
    let mut next = move || {
        z = z.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut x = z;
        x = (x ^ (x >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        x = (x ^ (x >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        Fp::new(x ^ (x >> 31))
    };
    (0..8).all(|_| {
        let v: Vec<Fp2> = (0..ir.tables.len()).map(|_| Fp2::new(next(), next())).collect();
        ir.eval(&v) == poly(&v)
    })
}

static CPU_SLOTS: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// A slot that stays on the CPU because no matching IR exists at this profile.
pub(super) fn note_cpu_slot(slot: usize, diag: bool) {
    CPU_SLOTS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    if diag {
        eprintln!("[ZK60-METAL] slot {slot}: the IR does not match this profile's closure; this slot runs on the CPU");
    }
}

/// how many slot sumchecks ran on the CPU for want of a matching IR
pub(crate) fn cpu_slots() -> usize {
    CPU_SLOTS.load(std::sync::atomic::Ordering::Relaxed)
}
