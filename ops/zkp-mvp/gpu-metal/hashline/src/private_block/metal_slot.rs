//! [ZK60-METAL M3, 2026-10-31] A slot's polynomial, from its expression IR
//! (`slot_ir.rs`, stage 34), as a Metal round kernel `k_sc_round`.
//!
//! The IR is the closure's transcription, held to it by
//! `slot_ir_tests::the_slot_ir_evaluates_to_the_closure_at_every_registered_shape_and_slot`
//! (equal field elements at random points of the whole space, every registered
//! shape and slot), and at run time by [`ir_matches_closure`] against the very
//! definition being proved. The generated code evaluates the same graph: the
//! same nodes in topological order, the same sums of products, coefficient
//! VALUES read from the `cf` buffer (challenge values never enter the source,
//! so one compiled kernel serves every proof of a shape).
//!
//! **Field typing (M3b).** A table whose IR provenance is base-field (ruling
//! I-2) holds `c1 = 0` at every cube point, so every point on the line between
//! two of its cube points is base-field too (`lo + t (hi - lo)`, t an integer).
//! Such tables are kept as one word, and an expression is base-field when all
//! its inputs and coefficients are; a product with a base operand is then 2
//! field multiplications instead of 5, or 1 when both are base. The device
//! checks `c1 = 0` on every table typed base before the first round, so a
//! mistyped table can only send the slot back to the CPU, never change a value.
//! Field arithmetic is exact, so these algebraically equal evaluations give the
//! same canonical elements.

use super::slot_ir::{Coef, CoefProv, Factor, FieldKind, NodeBody, SlotIr};
use crate::field::Fp2;

/// a generated expression and whether its value is base-field
#[derive(Clone)]
struct Ex {
    code: String,
    base: bool,
}

fn ext_of(e: &Ex) -> String {
    if e.base {
        format!("f2({}, 0UL)", e.code)
    } else {
        e.code.clone()
    }
}

fn mul(a: &Ex, b: &Ex) -> Ex {
    match (a.base, b.base) {
        (true, true) => Ex { code: format!("gl_mul({}, {})", a.code, b.code), base: true },
        (false, true) => Ex { code: format!("f2_mulb({}, {})", a.code, b.code), base: false },
        (true, false) => Ex { code: format!("f2_mulb({}, {})", b.code, a.code), base: false },
        (false, false) => Ex { code: format!("f2_mul({}, {})", a.code, b.code), base: false },
    }
}

fn add(a: &Ex, b: &Ex) -> Ex {
    match (a.base, b.base) {
        (true, true) => Ex { code: format!("gl_add({}, {})", a.code, b.code), base: true },
        (false, true) => Ex { code: format!("f2_addb({}, {})", a.code, b.code), base: false },
        (true, false) => Ex { code: format!("f2_addb({}, {})", b.code, a.code), base: false },
        (false, false) => Ex { code: format!("f2_add({}, {})", a.code, b.code), base: false },
    }
}

fn neg(a: &Ex) -> Ex {
    if a.base {
        Ex { code: format!("gl_neg_sc({})", a.code), base: true }
    } else {
        Ex { code: format!("f2_neg({})", a.code), base: false }
    }
}

fn one() -> Ex {
    Ex { code: "1UL".to_string(), base: true }
}

/// a coefficient as an expression (None for 1): base when its value is
/// (c1 = 0), its value in the `cf` buffer either way
fn coef_ex(c: &Coef, cf: &mut Vec<Fp2>) -> Option<Ex> {
    match c.prov {
        CoefProv::One => None,
        _ => {
            let i = cf.len();
            cf.push(c.value);
            Some(if c.value.c1.is_zero() {
                Ex { code: format!("cf[{}u]", 2 * i), base: true }
            } else {
                Ex { code: format!("CF(cf, {i}u)"), base: false }
            })
        }
    }
}

/// `coef * prod(factors)`
fn product(c: &Coef, factors: &[Ex], cf: &mut Vec<Fp2>) -> Ex {
    if matches!(c.prov, CoefProv::NegOne) {
        let p = factors.iter().skip(1).fold(factors.first().cloned().unwrap_or_else(one), |a, x| mul(&a, x));
        return neg(&p);
    }
    let mut acc = coef_ex(c, cf);
    for f in factors {
        acc = Some(match acc {
            None => f.clone(),
            Some(a) => mul(&a, f),
        });
    }
    acc.unwrap_or_else(one)
}

/// The generated round kernels for `ir`: (round-0 kernel typed by field,
/// later-round kernel with every table extension-valued), the coefficient
/// buffer (shared: both kernels push the same coefficients in the same order)
/// and which tables round 0 keeps as base-field words.
///
/// **Why two kernels.** A base-field table is base-field on the CUBE only: the
/// first fold mixes it with an extension challenge, so from round 1 on every
/// table is extension-valued (found 2026-10-31: a kernel typed for all rounds
/// moved the golden digests; the base check on upload cannot see it because it
/// runs before the first fold).
pub(super) fn msl_round_kernels(ir: &SlotIr) -> (String, String, Vec<Fp2>, Vec<bool>) {
    let base: Vec<bool> = ir.tables.iter().map(|t| t.field() == FieldKind::Base).collect();
    let (k0, cf0) = gen_kernel(ir, &base, "k_sc_round0");
    let (k1, cf1) = gen_kernel(ir, &vec![false; base.len()], "k_sc_round");
    assert_eq!(cf0.len(), cf1.len(), "both kernels read the same coefficient buffer");
    (k0, k1, cf0, base)
}

fn gen_kernel(ir: &SlotIr, base: &[bool], name: &str) -> (String, Vec<Fp2>) {
    let mut cf: Vec<Fp2> = Vec::new();
    let base: Vec<bool> = base.to_vec();
    let k = ir.tables.len();
    let tab = |t: usize| Ex { code: format!("v{t}"), base: base[t] };
    let fac = |f: &Factor, nodes: &[Ex]| -> Ex {
        match f {
            Factor::Table(t) => tab(*t as usize),
            Factor::Node(n) => nodes[*n as usize].clone(),
        }
    };
    // the polynomial body, typed, as statements ending in `out`
    let mut body = String::new();
    let mut nodes: Vec<Ex> = Vec::with_capacity(ir.nodes.len());
    for n in &ir.nodes {
        let val = match &n.body {
            NodeBody::Affine { konst, terms } => {
                let mut e = coef_ex(konst, &mut cf).unwrap_or_else(one);
                for (c, t) in terms {
                    let p = product(c, &[tab(*t as usize)], &mut cf);
                    e = add(&e, &p);
                }
                e
            }
            NodeBody::Sum { subterms } => {
                let mut e: Option<Ex> = None;
                for st in subterms {
                    let fs: Vec<Ex> = st.factors.iter().map(|f| fac(f, &nodes)).collect();
                    let p = product(&st.coef, &fs, &mut cf);
                    e = Some(match e {
                        None => p,
                        Some(a) => add(&a, &p),
                    });
                }
                e.unwrap_or(Ex { code: "0UL".to_string(), base: true })
            }
        };
        let ty = if val.base { "ulong" } else { "fp2" };
        body.push_str(&format!("            {ty} n{} = {};\n", n.id, val.code));
        nodes.push(Ex { code: format!("n{}", n.id), base: val.base });
    }
    body.push_str("            fp2 out = f2(0UL, 0UL);\n");
    for t in &ir.terms {
        let mut fs: Vec<Ex> = t.wrapper.iter().map(|w| tab(*w as usize)).collect();
        fs.extend(t.inner.iter().map(|f| fac(f, &nodes)));
        let p = product(&t.coef, &fs, &mut cf);
        body.push_str(&format!("            out = f2_add(out, {});\n", ext_of(&p)));
    }
    // [M4e] the kernel: ONE THREAD PER (pair stride, evaluation point d), the
    // grid `nthreads * (D + 1)` wide with `d = tid % (D + 1)`. Each table's
    // value at `d` along the pair's line is formed directly: `lo` at 0, `hi` at
    // 1, `lo + d (hi - lo)` beyond, the field element the CPU reaches by adding
    // the step `d` times (`ln_base` / `ln_ext`, SC_PRELUDE). Partial
    // `(gid, d)` lands where the M3 kernel put it. Measured on slot 14's later
    // rounds (64 tables, degree 5) in isolation: 0.170 s -> 0.059 s with one
    // pair per thread, against the M3 form's six points in sequence per thread.
    let mut s = String::new();
    s.push_str(&format!(
        "// slot {} ({}) at {}: {} tables ({} base), {} nodes, {} terms\n",
        ir.slot,
        ir.name,
        ir.profile,
        k,
        base.iter().filter(|b| **b).count(),
        ir.nodes.len(),
        ir.terms.len()
    ));
    if name == "k_sc_round0" {
        s.push_str("struct RoundArgs { ulong nhalf; ulong cap; uint eval_one; uint nthreads; };\n");
    }
    s.push_str(&format!("kernel void {name}(device const ulong *tabs [[buffer(0)]],\n"));
    s.push_str(concat!(
        "                       device ulong *part [[buffer(1)]],\n",
        "                       constant ulong *cf [[buffer(2)]],\n",
        "                       constant RoundArgs &a [[buffer(3)]],\n",
        "                       uint tid [[thread_position_in_grid]]) {\n",
        "    uint d = tid % (SC_D + 1u);\n",
        "    uint gid = tid / (SC_D + 1u);\n",
        "    if (gid >= a.nthreads) { return; }\n",
        "    ulong dd = ulong(d);\n",
        "    fp2 acc = f2(0UL, 0UL);\n",
        "    if (d != 1u || a.eval_one != 0u) {\n",
        "        for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {\n",
    ));
    for t in 0..k {
        let f = if base[t] { ("ulong", "ln_base") } else { ("fp2", "ln_ext") };
        s.push_str(&format!("            {} v{t} = {}(tabs, ({t}UL * a.cap + i) * 2UL, ({t}UL * a.cap + i + a.nhalf) * 2UL, d, dd);\n", f.0, f.1));
    }
    s.push_str(&body);
    s.push_str(concat!(
        "            acc = f2_add(acc, out);\n",
        "        }\n",
        "    }\n",
        "    ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;\n",
        "    part[o] = acc.c0;\n",
        "    part[o + 1] = acc.c1;\n",
        "}\n",
    ));
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
