//! **D63 step L13 (Lean lane, 2026-11-07): the W16R2 layout facts the slot IR builders read, at the three W16R2
//! profiles.** TEST ONLY: a child of `w16r2_tests` (declared there under `cfg(test)`), listed in `s25_tests`'s
//! `TEST_ONLY_FILES`. No prover or verifier source changes; nothing here is reachable from a production build.
//!
//! For the W16R2 development rung (with the calibration of `range16_tests::rung_case`, the shape of the L11 corpus),
//! and for the W16R2 Shieldstral T128 and 8B T128 shapes (`range16_tests::built`: the registered geometry with a
//! synthetic calibration in the trained class), it writes:
//! * `PREC`: the shape's stack and derived precision (`accuracy_precision::derive`), the norm constants, the gate shift,
//!   the softmax window `wrho_s`, `SH_ROPE`, and (rung only, from its bound accuracy data) the product fold's shift;
//! * `APLANES`: the `A` plane list of the W16 allocation (`AccuracyIds::new_w16`): domain and name, in plane order;
//! * `HPLANES` / `HIDS`: the `H` plane domains and the helper ids (`HIds`);
//! * `LK`: every lookup of every lookup domain (`Layout::lookups`, i.e. `lookups_w16`), in order;
//! * `ZERO`: the zero-rule `A` planes of every domain (`pad::zero_rule_a_planes`);
//! * `WIDTHS`, `FAMS`: the range widths (`range16::widths`) and families (`Shape::range_families`).
//!
//! `formal/ZK60Formal/SlotW16BuildCheck.lean` recomputes all of these from `PREC` and the corpus's `SHAPE` facts with the
//! Lean ports (`SlotW16BuildLayout.lean`), and with them every slot's table list and IR of the L11 corpus.
//! Every value is public (shape constants only).
use super::super::accuracy_precision::Stack;
use super::*;
use std::fmt::Write as _;

const DOMS: [Dom; 9] = [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab];

fn layout_lines(out: &mut String, sh: &Shape, fold: Option<u32>) {
    let p = sh.accuracy_precision().expect("a W16R2 shape's precision");
    let lay = Layout::for_shape(sh).expect("the W16R2 layout");
    let ids = lay.ids();
    let hids = lay.hids();
    let acc = ids.accuracy().expect("the W16 allocation");
    writeln!(out, "L13 {}", sh.name).unwrap();
    writeln!(
        out,
        "PREC h24={} tn={} cna={} cnm={} ceps={} q={} k={} v={} score={} pv={} ao={} gate={} up={} prodbits={} down={} fp={} wrho={} rope={} fold={} lt={} ld={} lf={} lkv={} lh={} ldh={}",
        usize::from(sh.accuracy_stack() == Stack::LowH24),
        p.norm_tn,
        sh.norm_cn_a,
        sh.norm_cn_m,
        sh.norm_ceps,
        p.q,
        p.k,
        p.v,
        p.score,
        p.pv,
        p.ao,
        sh.accuracy_gate_shift,
        p.up,
        p.product_bits,
        p.down,
        sh.f_p(),
        sh.wrho_s,
        SH_ROPE,
        fold.map(|f| f.to_string()).unwrap_or_else(|| "-".into()),
        sh.t_pad.trailing_zeros(),
        sh.d_pad.trailing_zeros(),
        sh.f_pad.trailing_zeros(),
        sh.kv_heads.next_power_of_two().trailing_zeros(),
        sh.h_pad.trailing_zeros(),
        sh.head_dim.trailing_zeros()
    )
    .unwrap();
    let pads: Vec<String> = DOMS.iter().map(|d| usize::from(sh.pads(*d)).to_string()).collect();
    let logs: Vec<String> = DOMS.iter().map(|d| sh.log(*d).to_string()).collect();
    writeln!(out, "DOMS pad_rule={} pads={} logs={} log_cols={}", usize::from(sh.carries_pad_rule()), pads.join(","), logs.join(","), sh.log_cols).unwrap();
    let planes: Vec<String> = (0..ids.n_a()).map(|i| format!("{:?}:{}", acc.doms[i], acc.names[i])).collect();
    writeln!(out, "APLANES {}", planes.join(",")).unwrap();
    let hp: Vec<String> = (0..hids.n_h()).map(|i| format!("{:?}", hids.dom(i))).collect();
    writeln!(out, "HPLANES {}", hp.join(",")).unwrap();
    let th = hids.table_helpers();
    writeln!(
        out,
        "HIDS l={} d={} q={} kv={} s={} sexp={} f={} fact={} gu8={} nrange={} u={}",
        hids.first_helper(Dom::L),
        hids.first_helper(Dom::D),
        hids.first_helper(Dom::Q),
        hids.first_helper(Dom::Kv),
        hids.first_helper(Dom::S),
        hids.sexp(),
        hids.first_helper(Dom::F),
        hids.fact(),
        th[0],
        hids.range_helpers().len(),
        hids.u()
    )
    .unwrap();
    for d in [Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F] {
        let lks: Vec<String> = lay
            .lookups(d)
            .iter()
            .map(|l| {
                let tag = match l.tag {
                    LkTag::U8 => "U8".to_string(),
                    LkTag::Range(w) => format!("R{w}"),
                };
                let ts: Vec<String> = l.terms.iter().map(|(pl, c)| format!("{pl}*{c}")).collect();
                format!("{}:{}:{}", l.cst, tag, ts.join("+"))
            })
            .collect();
        writeln!(out, "LK {:?} {} {}", d, sh.helpers(d), if lks.is_empty() { "-".to_string() } else { lks.join(";") }).unwrap();
    }
    for d in DOMS {
        let z = super::super::pad::zero_rule_a_planes(sh, ids, d);
        let zs: Vec<String> = z.iter().map(|x| x.to_string()).collect();
        writeln!(out, "ZERO {:?} {}", d, if zs.is_empty() { "-".to_string() } else { zs.join(",") }).unwrap();
    }
    let ws = super::super::range16::widths(sh.accuracy_stack(), &p, sh.accuracy_gate_shift, sh.wrho_s);
    let wl: Vec<String> = ws.iter().map(|w| w.to_string()).collect();
    writeln!(out, "WIDTHS {}", wl.join(",")).unwrap();
    let fl: Vec<String> = sh.range_families().iter().map(|f| format!("{}:{}", f.width, f.sub)).collect();
    writeln!(out, "FAMS {}", fl.join(",")).unwrap();
    writeln!(out, "LEND").unwrap();
}

#[test]
fn lean_l13_export_the_w16r2_layout_facts() {
    let mut out = String::new();
    let (sh, blk, _w) = rung_case(shape::W16R2_RUNG_H24);
    let fold = blk.accuracy().map(|a| a.folds().product.shift);
    layout_lines(&mut out, &sh, fold);
    for profile in [shape::W16R2_SHIELD_T128_H24, shape::W16R2_8B_T128_H24] {
        let s = built(profile);
        layout_lines(&mut out, &s, None);
    }
    writeln!(out, "DONE 3").unwrap();
    eprintln!("L13 corpus: 3 shapes, {} bytes", out.len());
    if let Ok(path) = std::env::var("LEAN_L13_CORPUS") {
        std::fs::write(path, out.as_bytes()).unwrap();
    }
}
