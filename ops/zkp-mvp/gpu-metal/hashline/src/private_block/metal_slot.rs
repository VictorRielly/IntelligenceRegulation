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
    let plan = lin_plan(ir);
    let (mut k0, cf0) = gen_kernel(ir, &base, "k_sc_round0", &plan);
    let (k1, cf1) = gen_kernel(ir, &vec![false; base.len()], "k_sc_round", &plan);
    assert_eq!(cf0.len(), cf1.len(), "both kernels read the same coefficient buffer");
    if !plan.is_empty() {
        // [A27] the materialization kernel rides in the round-0 kernel's source
        let (km, cfm) = gen_mat_kernel(ir, &base, &plan);
        assert!(cfm == cf0, "the materialization kernel reads the same coefficient buffer");
        k0.push_str(&km);
    }
    (k0, k1, cf0, base)
}

/// **[A27] one table of a slot's linear materialization** (`HL_A27_LIN`, [`lin_plan`]):
/// the whole of a node of degree <= 1, or the subterms of degree <= 1 of a sum
/// node of higher degree (by subterm index)
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) enum Mat {
    Node(usize),
    Part(usize, Vec<usize>),
}

/// **[A27] `HL_A27_LIN`** (default on; `0`: no materialization, as before): which
/// linear parts of a slot's polynomial the device keeps as TABLES of their own.
///
/// A node of degree <= 1 is an affine function of the tables, `L = k + sum c_t v_t`
/// (a formal fact of the graph, `SlotIr::recompute_degrees`). So its value at a point
/// of a pair's line is `L(lo) + d (L(hi) - L(lo))`, and folding the table of its
/// values by `r` gives the table of `L` over the folded tables: in exact field
/// arithmetic the same element as evaluating `L` from the tables' line values, at
/// every point of every round. The device therefore computes `L` once per cube point
/// before round 0 (`k_sc_mat`), keeps it in an extra table (`xtabs`), folds it with
/// the others, and the round kernels read its line value instead of re-evaluating
/// its terms at every point of every pair. The round values, challenges and the
/// original tables' finals are the same field elements; only the work changes (the
/// original tables are still folded: their finals are the slot's output).
///
/// The plan is a function of the graph's STRUCTURE (degrees, uses, products), never
/// of a value: a node of degree <= 1 whose own expression makes >= 3 base products
/// (in the later-round form) and that a node of degree >= 2 or a term uses; and, of
/// a sum node of degree >= 2, its subterms of degree <= 1 (at least two, >= 3 base
/// products together; a bare reference to a node already materialized not counted).
/// The A27 kernel bench (`results/zk60_a27_app_20261107/README.md`): slot 14's later
/// rounds 43 -> 16 ms, slot 18's 31 -> 17 ms on the real Shieldstral kernels.
pub(super) fn lin_plan(ir: &SlotIr) -> Vec<(usize, Mat)> {
    static ON: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    if !*ON.get_or_init(|| std::env::var("HL_A27_LIN").map(|v| v != "0").unwrap_or(true)) {
        return Vec::new();
    }
    let deg = ir.recompute_degrees();
    let nn = ir.nodes.len();
    let fdeg = |f: &Factor| match f {
        Factor::Table(_) => 1,
        Factor::Node(n) => deg[*n as usize],
    };
    // whether a node of degree >= 2, or a term, uses each node
    let mut nonlinear_use = vec![false; nn];
    for (i, n) in ir.nodes.iter().enumerate() {
        if let NodeBody::Sum { subterms } = &n.body {
            if deg[i] >= 2 {
                for st in subterms {
                    for f in &st.factors {
                        if let Factor::Node(m) = f {
                            nonlinear_use[*m as usize] = true;
                        }
                    }
                }
            }
        }
    }
    for t in &ir.terms {
        for f in &t.inner {
            if let Factor::Node(m) = f {
                nonlinear_use[*m as usize] = true;
            }
        }
    }
    // the base products of the later-round form (every table and node extension-
    // valued; a coefficient base when its provenance is a public base constant)
    let coef_cost = |c: &Coef| match c.prov {
        CoefProv::One | CoefProv::NegOne => 0usize,
        CoefProv::Base(_) => 2,
        _ => 3,
    };
    let product_cost = |c: &Coef, nf: usize| -> usize {
        let c0 = if nf == 0 { 0 } else { coef_cost(c) };
        c0 + 3 * nf.saturating_sub(1)
    };
    let mut plan: Vec<(usize, Mat)> = Vec::new();
    let mut whole = vec![false; nn];
    for (i, n) in ir.nodes.iter().enumerate() {
        if deg[i] <= 1 {
            let cost: usize = match &n.body {
                NodeBody::Affine { terms, .. } => terms.iter().map(|(c, _)| product_cost(c, 1)).sum(),
                NodeBody::Sum { subterms } => subterms.iter().map(|st| product_cost(&st.coef, st.factors.len())).sum(),
            };
            if cost >= 3 && nonlinear_use[i] {
                whole[i] = true;
                plan.push((i, Mat::Node(i)));
            }
            continue;
        }
        if let NodeBody::Sum { subterms } = &n.body {
            let bare_mat = |st: &super::slot_ir::SubTerm| matches!(st.coef.prov, CoefProv::One) && st.factors.len() == 1 && matches!(st.factors[0], Factor::Node(m) if whole[m as usize]);
            let lin: Vec<usize> = (0..subterms.len()).filter(|&j| subterms[j].factors.iter().map(fdeg).sum::<usize>() <= 1 && !bare_mat(&subterms[j])).collect();
            let cost: usize = lin.iter().map(|&j| product_cost(&subterms[j].coef, subterms[j].factors.len())).sum();
            if lin.len() >= 2 && cost >= 3 && lin.len() < subterms.len() {
                plan.push((i, Mat::Part(i, lin)));
            }
        }
    }
    plan
}

/// **[A27] `HL_A27_DEGREE`** (default on; `0`: every declared point, as before):
/// the degree the device evaluates a slot's round polynomial at, when the IR
/// ATTAINS less than the declared degree D (`SlotIr::max_term_degree`, a formal
/// bound from the graph: every table is affine along a pair's line, so each pair's
/// polynomial, and the round's sum, has degree at most the attained one for ANY
/// table values). Such a round polynomial is fixed by its values at
/// `0..=attained`, so the values at `attained + 1..=D` follow exactly (Lagrange
/// extrapolation in the field: the same canonical elements the device evaluated
/// before, `gpu/metal.rs` [`crate::gpu::MetalRounds`]); the kernel skips those
/// points. A6's census: slot 18 (and slot 14 at the rung) attains 4 of a declared
/// 5 (`results/zk60_effplan_20261105/a7/README.md` §6). `None`: evaluate all.
pub(super) fn evaluated_degree(ir: &SlotIr) -> Option<usize> {
    static ON: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    if !*ON.get_or_init(|| std::env::var("HL_A27_DEGREE").map(|v| v != "0").unwrap_or(true)) {
        return None;
    }
    let attained = ir.max_term_degree();
    (attained >= 1 && attained < ir.degree).then_some(attained)
}

/// The node statements, term products and coefficients of one typing (`base`: which
/// tables are base-field words), with the [`lin_plan`] items `substitute`d by their
/// tables (`v{k + j}`, typed as their expression is) or not. Every coefficient is
/// pushed in the same order either way (the nodes, then the terms), so every kernel
/// of a slot reads one coefficient buffer. Returns (node statements, term products,
/// the plan items' expressions, cf); a node of degree >= 2 is left out when
/// `linear_only`.
fn node_pass(ir: &SlotIr, base: &[bool], plan: &[(usize, Mat)], substitute: bool, linear_only: bool) -> (String, Vec<Ex>, Vec<Ex>, Vec<Fp2>) {
    let mut cf: Vec<Fp2> = Vec::new();
    let k = ir.tables.len();
    let deg = ir.recompute_degrees();
    let tab = |t: usize| Ex { code: format!("v{t}"), base: base[t] };
    let fac = |f: &Factor, nodes: &[Ex]| -> Ex {
        match f {
            Factor::Table(t) => tab(*t as usize),
            Factor::Node(n) => nodes[*n as usize].clone(),
        }
    };
    let sum_of = |xs: &[Ex]| -> Option<Ex> {
        let mut e: Option<Ex> = None;
        for p in xs {
            e = Some(match e {
                None => p.clone(),
                Some(a) => add(&a, p),
            });
        }
        e
    };
    let mut body = String::new();
    let mut nodes: Vec<Ex> = Vec::with_capacity(ir.nodes.len());
    let mut mats: Vec<Ex> = vec![one(); plan.len()];
    for (i, n) in ir.nodes.iter().enumerate() {
        let item = plan.iter().position(|(ni, _)| *ni == i);
        let val = match &n.body {
            NodeBody::Affine { konst, terms } => {
                let mut e = coef_ex(konst, &mut cf).unwrap_or_else(one);
                for (c, t) in terms {
                    let p = product(c, &[tab(*t as usize)], &mut cf);
                    e = add(&e, &p);
                }
                if let Some(j) = item {
                    mats[j] = e.clone();
                    if substitute {
                        e = Ex { code: format!("v{}", k + j), base: e.base };
                    }
                }
                e
            }
            NodeBody::Sum { subterms } => {
                let ps: Vec<Ex> = subterms
                    .iter()
                    .map(|st| {
                        let fs: Vec<Ex> = st.factors.iter().map(|f| fac(f, &nodes)).collect();
                        product(&st.coef, &fs, &mut cf)
                    })
                    .collect();
                let whole = sum_of(&ps).unwrap_or(Ex { code: "0UL".to_string(), base: true });
                match item.map(|j| (j, &plan[j].1)) {
                    Some((j, Mat::Node(_))) => {
                        mats[j] = whole.clone();
                        if substitute {
                            Ex { code: format!("v{}", k + j), base: whole.base }
                        } else {
                            whole
                        }
                    }
                    Some((j, Mat::Part(_, lin))) => {
                        let group: Vec<Ex> = lin.iter().map(|&s| ps[s].clone()).collect();
                        let g = sum_of(&group).expect("a materialized part has subterms");
                        mats[j] = g.clone();
                        if substitute {
                            // the field sum in another order: the same element
                            let rest: Vec<Ex> = (0..ps.len()).filter(|s| !lin.contains(s)).map(|s| ps[s].clone()).collect();
                            let mut e = Ex { code: format!("v{}", k + j), base: g.base };
                            for p in &rest {
                                e = add(&e, p);
                            }
                            e
                        } else {
                            whole
                        }
                    }
                    None => whole,
                }
            }
        };
        if !linear_only || deg[i] <= 1 {
            let ty = if val.base { "ulong" } else { "fp2" };
            body.push_str(&format!("            {ty} n{} = {};\n", n.id, val.code));
        }
        nodes.push(Ex { code: format!("n{}", n.id), base: val.base });
    }
    let mut outs = Vec::with_capacity(ir.terms.len());
    for t in &ir.terms {
        let mut fs: Vec<Ex> = t.wrapper.iter().map(|w| tab(*w as usize)).collect();
        fs.extend(t.inner.iter().map(|f| fac(f, &nodes)));
        outs.push(product(&t.coef, &fs, &mut cf));
    }
    (body, outs, mats, cf)
}

/// **[A27] the materialization kernel** `k_sc_mat`: one thread per cube point `x`,
/// the plan items' values from the round-0 tables at `x` (the round-0 typing: a
/// base table a word), written to table `j` of `xtabs` as `(c0, c1)`.
fn gen_mat_kernel(ir: &SlotIr, base: &[bool], plan: &[(usize, Mat)]) -> (String, Vec<Fp2>) {
    let k = ir.tables.len();
    let (body, _outs, mats, cf) = node_pass(ir, base, plan, false, true);
    let mut s = String::new();
    s.push_str("struct MatArgs { ulong cap; };\n");
    s.push_str("kernel void k_sc_mat(device const ulong *tabs [[buffer(0)]],\n");
    s.push_str("                     device ulong *xtabs [[buffer(1)]],\n");
    s.push_str("                     constant ulong *cf [[buffer(2)]],\n");
    s.push_str("                     constant MatArgs &a [[buffer(3)]],\n");
    s.push_str("                     uint tid [[thread_position_in_grid]]) {\n");
    s.push_str("    ulong x = ulong(tid);\n    if (x >= a.cap) { return; }\n");
    for t in 0..k {
        if base[t] {
            s.push_str(&format!("    ulong v{t} = tabs[({t}UL * a.cap + x) * 2UL];\n"));
        } else {
            s.push_str(&format!("    fp2 v{t} = f2(tabs[({t}UL * a.cap + x) * 2UL], tabs[({t}UL * a.cap + x) * 2UL + 1UL]);\n"));
        }
    }
    s.push_str(&body);
    for (j, m) in mats.iter().enumerate() {
        s.push_str(&format!("    fp2 m{j} = {};\n", ext_of(m)));
        s.push_str(&format!("    xtabs[({j}UL * a.cap + x) * 2UL] = m{j}.c0;\n    xtabs[({j}UL * a.cap + x) * 2UL + 1UL] = m{j}.c1;\n"));
    }
    s.push_str("}\n");
    (s, cf)
}

fn gen_kernel(ir: &SlotIr, base: &[bool], name: &str, plan: &[(usize, Mat)]) -> (String, Vec<Fp2>) {
    let base: Vec<bool> = base.to_vec();
    let k = ir.tables.len();
    let m = plan.len();
    // the polynomial body, typed, as statements ending in `out`
    let (mut body, outs, mats, cf) = node_pass(ir, &base, plan, true, false);
    body.push_str("            fp2 out = f2(0UL, 0UL);\n");
    for p in &outs {
        body.push_str(&format!("            out = f2_add(out, {});\n", ext_of(p)));
    }
    // [M4e] the kernel: ONE THREAD PER (pair stride, evaluation point d), the
    // grid `nthreads * (D + 1)` wide with `d = tid % (D + 1)`. Each table's
    // value at `d` along the pair's line is formed directly: `lo` at 0, `hi` at
    // 1, `lo + d (hi - lo)` beyond, the field element the CPU reaches by adding
    // the step `d` times (`ln_base` / `ln_ext`, SC_PRELUDE). Partial
    // `(gid, d)` lands where the M3 kernel put it. Measured on slot 14's later
    // rounds (64 tables, degree 5) in isolation: 0.170 s -> 0.059 s with one
    // pair per thread, against the M3 form's six points in sequence per thread.
    //
    // [M4g] ONE POINT PER SIMD GROUP: lanes `tid & 31` of group `tid >> 5`
    // share the point `d` (no divergent branches in the line values), and
    // when the round recovers s(1) from the claim (`eval_one == 0`, every
    // later round of a closure slot) point 1 is not launched at all: the grid
    // is `ceil(nthreads / 32) * 32 * np` with `np` the points evaluated, and
    // `d` skips 1. Before, a sixth of every SIMD group idled at point 1, and
    // the divergent form was slower still: slot 14's later rounds in the
    // `kbench` harness with `eval_one == 0`, 0.087 s -> 0.050 s, equal sums.
    // The partial `(gid, d)` lands where it did; point 1's is not written and
    // the host does not read it (it uses the claim).
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
        // [A27] the points the kernel evaluates: 0..=SC_DE (the IR's attained
        // degree when it is below the declared one, [`evaluated_degree`]); the
        // host and the transcript step extrapolate s(SC_DE + 1..=SC_D) exactly
        if let Some(de) = evaluated_degree(ir) {
            s.push_str(&format!("#define SC_DE {de}u\n"));
        }
        // [A27] the materialized tables ([`lin_plan`]): `xtabs`, buffer 4
        if m > 0 {
            s.push_str(&format!("#define SC_M {m}u\n"));
        }
    }
    s.push_str("#ifndef SC_DE\n#define SC_DE SC_D\n#endif\n");
    s.push_str(&format!("kernel void {name}(device const ulong *tabs [[buffer(0)]],\n"));
    s.push_str(concat!(
        "                       device ulong *part [[buffer(1)]],\n",
        "                       constant ulong *cf [[buffer(2)]],\n",
        "                       constant RoundArgs &a [[buffer(3)]],\n",
    ));
    if m > 0 {
        s.push_str("                       device const ulong *xtabs [[buffer(4)]],\n");
    }
    s.push_str(concat!(
        "                       uint tid [[thread_position_in_grid]]) {\n",
        "    uint np = a.eval_one != 0u ? SC_DE + 1u : SC_DE;\n",
        "    uint grp = tid >> 5;\n",
        "    uint di = grp % np;\n",
        "    uint d = (a.eval_one != 0u || di == 0u) ? di : di + 1u;\n",
        "    uint gid = (grp / np) * 32u + (tid & 31u);\n",
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
    // [A27] a materialized table: base in round 0 exactly when its expression is
    for (j, me) in mats.iter().enumerate() {
        let f = if me.base { ("ulong", "ln_base") } else { ("fp2", "ln_ext") };
        s.push_str(&format!("            {} v{} = {}(xtabs, ({j}UL * a.cap + i) * 2UL, ({j}UL * a.cap + i + a.nhalf) * 2UL, d, dd);\n", f.0, k + j, f.1));
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
