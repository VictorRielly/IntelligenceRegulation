//! **D63 step L11 (Lean lane, 2026-11-07): the W16R2 slot arithmetic's agreement corpus, from a REAL W16R2 block
//! receipt.** TEST ONLY: a child of `w16r2_tests` (declared there under `cfg(test)`), listed in `s25_tests`'s
//! `TEST_ONLY_FILES`. No prover or verifier source changes; nothing here is reachable from a production build.
//!
//! What it does, at the W16R2 development rung (`shape::W16R2_RUNG_H24`, `range16_tests::rung_case`):
//! 1. proves one block CORE (`w16r2_tests::prove`) and verifies it with the production `verify_core`
//!    (`w16r2_tests::verify`);
//! 2. replays `verify_core`'s head on the same header (protocol.rs:2827-2837: the `A` root, `M`, `beta`, `gamma`,
//!    `alpha`, the `H` root) and then `argument_with`'s slot loop (argument.rs:3003-3056): for every slot, the slot's
//!    expression IR on a twin transcript (`slot_ir::build_slot_ir`, as the Metal path does), `define`, then the
//!    VERIFY arm of `run_slot` (argument.rs:1434-1468) recomputed on a clone (the claimed sum with its hosted terms,
//!    `sumcheck::verify`, the terminal values `sel·eq`, `sel·mle(pub)`, the masked terminals, `poly(vals)`, the mask
//!    value `g = (fin − poly(vals))/c`), and finally the real `run_slot` on the real transcript;
//! 3. asserts that the IR evaluates to the closure on the real terminal values, and that the recomputation's transcript
//!    ends where `run_slot`'s does;
//! 4. writes every slot's record to the file named by `LEAN_L11_CORPUS` (one record per line), for
//!    `formal/ZK60Formal/L11Check.lean` to recompute with the Lean definitions of `SlotW16Ir.lean` and `SlotW16R2.lean`.
//!
//! Every value is public: the fixture's public synthetic data, the receipt and the transcript's challenges (no witness
//! value, no mask coefficient, no RNG state is written).
use super::super::argument::{define, run_slot, Acc, Ctx, Points, Side, Tab};
use super::super::slot_ir::{build_slot_ir, Factor, IrPoints, NodeBody, SlotIr};
use super::*;
use crate::mle::{eq_point, eval_mle_ext};
use crate::sumcheck;
use std::fmt::Write as _;

fn f2(x: Fp2) -> String {
    format!("{},{}", x.c0.0, x.c1.0)
}

fn f2s(v: &[Fp2]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| f2(*x)).collect::<Vec<_>>().join(",")
    }
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn usizes(v: &[usize]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

fn factor(f: &Factor) -> String {
    match f {
        Factor::Table(t) => format!("t{t}"),
        Factor::Node(n) => format!("n{n}"),
    }
}

fn factors(fs: &[Factor]) -> String {
    if fs.is_empty() {
        "-".to_string()
    } else {
        fs.iter().map(factor).collect::<Vec<_>>().join(".")
    }
}

/// a coefficient: `c0:c1:provenance` (the provenance label with no spaces)
fn coef(c: &super::super::slot_ir::Coef) -> String {
    format!("{}:{}:{}", c.value.c0.0, c.value.c1.0, c.prov.label().replace(' ', "_"))
}

fn ir_lines(out: &mut String, ir: &SlotIr) {
    writeln!(out, "IR {} {} {}", ir.tables.len(), ir.nodes.len(), ir.terms.len()).unwrap();
    for t in &ir.tables {
        let kind = match t.kind {
            super::super::slot_ir::TableKind::Eq { start, point_len } => format!("eq:{start}:{point_len}"),
            super::super::slot_ir::TableKind::GroupEq { bits } => format!("geq:{bits}"),
            super::super::slot_ir::TableKind::Public => "pub".to_string(),
            super::super::slot_ir::TableKind::Support { dom } => format!("supp:{dom:?}"),
            super::super::slot_ir::TableKind::PlaneA => "A".to_string(),
            super::super::slot_ir::TableKind::HelperH => "H".to_string(),
            super::super::slot_ir::TableKind::Endpoint => "EP".to_string(),
        };
        writeln!(out, "IRTAB {} {kind} {}", t.id, t.label.replace(' ', "_")).unwrap();
    }
    for n in &ir.nodes {
        match &n.body {
            NodeBody::Affine { konst, terms } => {
                let ts: Vec<String> = terms.iter().map(|(c, t)| format!("{}@t{t}", coef(c))).collect();
                writeln!(out, "NODE {} A {} {}", n.id, coef(konst), if ts.is_empty() { "-".to_string() } else { ts.join(";") }).unwrap();
            }
            NodeBody::Sum { subterms } => {
                let ss: Vec<String> = subterms.iter().map(|s| format!("{}@{}", coef(&s.coef), factors(&s.factors))).collect();
                writeln!(out, "NODE {} S {}", n.id, if ss.is_empty() { "-".to_string() } else { ss.join(";") }).unwrap();
            }
        }
        writeln!(out, "NLABEL {} {}", n.id, n.label.replace(' ', "_")).unwrap();
    }
    for t in &ir.terms {
        let w: Vec<usize> = t.wrapper.iter().map(|x| *x as usize).collect();
        writeln!(out, "TERM {} {} {}", coef(&t.coef), usizes(&w), factors(&t.inner)).unwrap();
    }
}

/// the largest public table whose values the corpus carries (above it, only its multilinear value at `rho` is
/// written, and the Lean check does not recompute that one value)
const PUB_EXPORT_MAX: usize = 1 << 10;

#[test]
fn lean_l11_export_the_w16r2_rung_slots() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    let core = prove(&sh, &blk, copy(&w)).expect("the honest W16R2 rung core");
    verify(&sh, &blk, &core).expect("the honest W16R2 rung core verifies (production verify_core)");
    let lay = Layout::for_shape(&sh).unwrap();
    let ids = Ids::new(&sh).unwrap();
    let mut out = String::new();
    let key = header(&sh, &lay).fs_key();
    writeln!(out, "L11 {} {} {}", sh.name, key.map(|k| hex(&k)).unwrap_or_else(|| "-".into()), sh.n_slots()).unwrap();
    // the shape facts the Lean slot schedule is computed from
    let lg = |v: usize| v.trailing_zeros() as usize;
    let doms = [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab];
    let logs: Vec<usize> = doms.iter().map(|d| sh.log(*d)).collect();
    let pads: Vec<usize> = doms.iter().map(|d| usize::from(sh.pads(*d))).collect();
    let helpers: Vec<usize> = doms.iter().map(|d| sh.helpers(*d)).collect();
    let zero_rule: Vec<usize> = doms.iter().map(|d| usize::from(!super::super::pad::zero_rule_a_planes(&sh, &ids, *d).is_empty())).collect();
    let n_range = super::super::range16::sub_planes(&sh.range_families()).len();
    writeln!(
        out,
        "SHAPE lt={} lh={} ldh={} ld={} lf={} lq={} lkvw={} lkv={} pad_rule={} n_range={} per_row={} logs={} pads={} helpers={} zero_rule={}",
        lg(sh.t_pad),
        lg(sh.h_pad),
        lg(sh.head_dim),
        lg(sh.d_pad),
        lg(sh.f_pad),
        lg(sh.q_pad()),
        lg((sh.kv_heads * sh.head_dim).next_power_of_two()),
        lg(sh.kv_heads.next_power_of_two()),
        usize::from(sh.carries_pad_rule()),
        n_range,
        sh.size(Dom::S) / sh.size(Dom::Ht),
        usizes(&logs),
        usizes(&pads),
        usizes(&helpers),
        usizes(&zero_rule)
    )
    .unwrap();
    let slots_decl: Vec<String> = (0..sh.n_slots()).map(|s| format!("{}:{}:{}", sh.slots()[s].0, sh.slots()[s].1, sh.slots()[s].2)).collect();
    writeln!(out, "SCHED {}", slots_decl.join(",")).unwrap();
    writeln!(out, "TERMSDECL {}", usizes(&sh.slot_terms()[..sh.n_slots()])).unwrap();
    // `verify_core`'s head (protocol.rs:2827-2837), on the header `w16r2_tests::verify` uses
    let mut tr = header(&sh, &lay);
    writeln!(out, "HEAD {} {}", hex(&tr.state()), tr.counter()).unwrap();
    protocol::absorb_root(&mut tr, b"A", &core.a_root, lay.a_rows, sh.log_cols);
    tr.absorb(b"M", &core.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(crate::tables_attn::TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(crate::tables_attn::TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(crate::tables_attn::TAG_ACT));
    protocol::absorb_root(&mut tr, b"H", &core.h_root, lay.h_rows, sh.log_cols);
    let g_dd = gamma.mul_base(Fp::new(TAG_DD));
    writeln!(out, "ROOTS {} {} {} {} {} {}", hex(&core.a_root), lay.a_rows, hex(&core.mask_root), hex(&core.h_root), lay.h_rows, sh.log_cols).unwrap();
    writeln!(out, "LOGUP {} {} {}", f2(beta), f2(gamma), f2(alpha)).unwrap();
    writeln!(out, "TAGS {} {} {}", f2(g_u8), f2(g_exp), f2(g_act)).unwrap();
    writeln!(out, "HEADEND {} {}", hex(&tr.state()), tr.counter()).unwrap();
    let ctx = Ctx { accuracy: blk.accuracy(), lay: &lay, public: blk.attention(), ff: blk.feed_forward(), alpha, beta, g_u8, g_exp, g_act, g_dd };
    let mut side = Side::Verify { slots: &core.slots };
    let mut acc = Acc::default();
    let mut pts = Points::default();
    let mut ipts = IrPoints::default();
    let mut scalars: Vec<Fp2> = Vec::new();
    let (mut n_ir, mut n_pub_full, mut n_pub_value) = (0usize, 0usize, 0usize);
    for s in 0..sh.n_slots() {
        let before_def = Transcript::clone_state(&tr);
        let mut twin = Transcript::clone_state(&tr);
        let ir = build_slot_ir(s, &ctx, &mut ipts, &mut twin);
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        // the definition's draws: `define` only squeezes (`native_capture::slot` asserts the same)
        let mut replay = Transcript::clone_state(&before_def);
        let mut draws = Vec::new();
        while replay.counter() < tr.counter() {
            draws.push(replay.challenge_fp2());
        }
        assert_eq!(replay.state(), tr.state(), "slot {s}: the definition did more than squeeze");
        let (n, ext, degree) = sh.slots()[s];
        let kind = match SLOT_KINDS[s] {
            SlotKind::Private => "P",
            SlotKind::Standalone => "S",
            SlotKind::Host => "H",
        };
        let n_priv = def.tabs.iter().filter(|t| matches!(t, Tab::Priv(_))).count();
        writeln!(out, "SLOT {s} {kind} {n} {ext} {degree} {n_priv} {}", def.tabs.len()).unwrap();
        writeln!(out, "DRAWS {}", f2s(&draws)).unwrap();
        writeln!(out, "TRB {} {}", hex(&tr.state()), tr.counter()).unwrap();
        let sp = &core.slots[s];
        writeln!(out, "SCALAR {}", f2(sp.scalar)).unwrap();
        let hosted: Vec<String> = def.hosted.iter().map(|(hs, c)| format!("{hs}:{}:{}", c.c0.0, c.c1.0)).collect();
        writeln!(out, "HOSTED {}", if hosted.is_empty() { "-".to_string() } else { hosted.join(";") }).unwrap();
        for (j, r) in sp.sc.rounds.iter().enumerate() {
            writeln!(out, "ROUND {j} {}", f2s(r)).unwrap();
        }
        writeln!(out, "TERMS {}", f2s(&sp.terms)).unwrap();
        // run_slot's VERIFY arm (argument.rs:1434-1468), recomputed on a clone
        let mut t2 = Transcript::clone_state(&tr);
        t2.absorb_u64(b"pb-slot", s as u64);
        let c = t2.challenge_fp2();
        assert!(!c.is_zero());
        t2.absorb_fp2(b"pb-scalar", &[sp.scalar]);
        let claimed = def.hosted.iter().fold(sp.scalar, |a, (hs, coef)| a.add(coef.mul(scalars[*hs])));
        let (fin, rho_full) = sumcheck::verify(claimed, degree, n + ext, &sp.sc, &mut t2).expect("an honest slot verifies");
        let rho = rho_full[..n].to_vec();
        let es = rho_full[n..].to_vec();
        let sel = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
        let mut k = 0usize;
        let mut vals = Vec::with_capacity(def.tabs.len());
        for (i, t) in def.tabs.iter().enumerate() {
            match t {
                Tab::Eq { point, start } => {
                    writeln!(out, "TAB {i} eq {start} {}", f2s(point)).unwrap();
                    vals.push(sel.mul(eq_point(point, &rho[*start..*start + point.len()])));
                }
                Tab::Pub(v) => {
                    let m = eval_mle_ext(v, &rho);
                    if v.len() <= PUB_EXPORT_MAX {
                        writeln!(out, "TAB {i} pub {} {}", v.len(), f2s(v)).unwrap();
                        n_pub_full += 1;
                    } else {
                        writeln!(out, "TAB {i} pubv {} {}", v.len(), f2(m)).unwrap();
                        n_pub_value += 1;
                    }
                    vals.push(sel.mul(m));
                }
                Tab::Priv(_) => {
                    writeln!(out, "TAB {i} priv {k}").unwrap();
                    vals.push(sp.terms[k]);
                    k += 1;
                }
            }
        }
        let pv = (def.poly)(&vals);
        let g_val = fin.sub(pv).mul(c.inv());
        assert!(es.iter().all(|e| !e.is_zero() && *e != Fp2::ONE));
        t2.absorb_fp2(b"pb-term", &sp.terms);
        writeln!(out, "VALS {}", f2s(&vals)).unwrap();
        match &ir {
            Ok(ir) => {
                assert_eq!(ir.tables.len(), def.tabs.len(), "slot {s}: the IR's table count");
                assert_eq!(ir.eval(&vals), pv, "slot {s}: the IR differs from the closure at the real terminal values");
                ir_lines(&mut out, ir);
                n_ir += 1;
            }
            Err(e) => writeln!(out, "IRNONE {}", e.replace(' ', "_")).unwrap(),
        }
        writeln!(out, "RES {} {} {} {} {} {}", f2(c), f2(claimed), f2(fin), f2s(&rho_full), f2(pv), f2(g_val)).unwrap();
        writeln!(out, "TRA {} {}", hex(&t2.state()), t2.counter()).unwrap();
        // the real `run_slot`, on the real transcript: it must end where the recomputation does
        run_slot(&mut side, &mut acc, def, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        assert_eq!(tr.state(), t2.state(), "slot {s}: the recomputed verify arm left another transcript");
        assert_eq!(tr.counter(), t2.counter());
        assert_eq!(acc.scalars.last().copied(), Some(sp.scalar));
        assert_eq!(acc.fs.last().map(|f| f.value), Some(g_val), "slot {s}: the mask functional's value is g");
        scalars.push(sp.scalar);
        writeln!(out, "END {s}").unwrap();
    }
    writeln!(out, "DONE {n_ir} {n_pub_full} {n_pub_value}").unwrap();
    eprintln!("L11 corpus: {} slots, {n_ir} slot IRs, {n_pub_full} public tables with values, {n_pub_value} by value only, {} bytes", sh.n_slots(), out.len());
    if let Ok(path) = std::env::var("LEAN_L11_CORPUS") {
        std::fs::write(path, out.as_bytes()).unwrap();
    }
}
