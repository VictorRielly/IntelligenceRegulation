//! **D63 step L1 (Lean lane, 2026-11-06): the integer witness of the R13 trace
//! fixture, printed for the Lean integer model to check value for value.**
//!
//! TEST ONLY. It prints the WHOLE integer trace that `witness_accuracy::build`
//! makes for the synthetic 32-token fixture of
//! `witness_accuracy::tests::both_export_stacks_match_the_independent_full_block_oracle`
//! (the same fixture, rebuilt here because that test's helper is private):
//! every word, every requantization remainder, both norms' isqrt witnesses and
//! division remainders, and the softmax internals (row maxima, row sums, the
//! argmax selector, the exp values, the quotients and both division slacks).
//! The fixture is public synthetic data (`r13_vectors/block_fixture_t32.tsv`),
//! not a real input, so printing it reveals nothing; no production path calls
//! this module.
//!
//! Output: one line per array, `L1<TAB><stack><TAB><name><TAB>v0<TAB>v1...`,
//! dense in the support order of each array's domain (the order the oracle
//! fixture uses); the `Dom::T` arrays by token, the `Dom::Ht` arrays by
//! (query head, token). Run with `-- --nocapture`. The Lean side is
//! `formal/ZK60Formal/L1Check.lean`.
use super::accuracy::{build, Trace};
use super::*;
use crate::private_block::accuracy_groups::Group;
use crate::private_block::accuracy_precision::{BaseShifts, Stack};
use crate::private_block::accuracy_public::{AccuracyPublic, Geometry, Multipliers};
use std::collections::BTreeMap;

fn parse(text: &str) -> BTreeMap<&str, Vec<i64>> {
    text.lines()
        .map(|line| {
            let mut cells = line.split('\t');
            (cells.next().unwrap(), cells.map(|s| s.parse().unwrap()).collect())
        })
        .collect()
}

/// `witness_accuracy::tests::fixture`, verbatim but for its formatting
fn fixture(stack: Stack) -> (Shape, AttentionPublic, FeedForwardPublic, AccuracyPublic, Vec<i16>) {
    let f = parse(include_str!("r13_vectors/block_fixture_t32.tsv"));
    let mut sh = Shape::new("R13 trace fixture", "r13-trace-fixture", 32, 16, 32, 4, 4, 2, 8, 8, 9, 7, None, None, None, None).unwrap();
    sh.norm_tn = 10;
    sh.norm_cn_a = 200;
    sh.norm_cn_m = 180;
    sh.norm_ceps = 123;
    sh.sh_qkv = 8;
    sh.sh_s = 6;
    sh.sh_o = 9;
    sh.sh_ao = 7;
    sh.sh_g = 8;
    sh.sh_h = 14;
    sh.sh_z = 6;
    let i8s = |key: &str| f[key].iter().map(|&v| i8::try_from(v).unwrap()).collect::<Vec<_>>();
    let transpose = |key: &str, rows: usize, cols: usize| {
        let w = &f[key];
        (0..cols).flat_map(|j| (0..rows).map(move |i| i8::try_from(w[i * cols + j]).unwrap())).collect::<Vec<_>>()
    };
    let public = AttentionPublic::new_shaped(
        &sh,
        &transpose("w_q", 16, 16),
        &transpose("w_k", 16, 8),
        &transpose("w_v", 16, 8),
        &transpose("w_o", 16, 16),
        &i8s("gamma"),
        &f["cos"],
        &f["sin"],
        &f["exp"],
    )
    .unwrap();
    let ff = FeedForwardPublic::new_shaped(&sh, &i8s("gamma"), &i8s("w_g"), &i8s("w_u"), &i8s("w_d"), &[0; 256]).unwrap();
    let ms = |key: &str| f[key].iter().map(|&v| u16::try_from(v).unwrap()).collect::<Vec<_>>();
    let groups: Vec<Group> = f["members"].chunks_exact(2).map(|v| Group { e_in: v[0] as i32, e_out: v[1] as i32 }).collect();
    let tables = groups.iter().map(|g| crate::private_block::accuracy_tables::silu_table(g.e_in, g.e_out, 12).unwrap()).collect();
    let accuracy = AccuracyPublic::new(
        stack,
        Geometry { width: 16, query_width: 16, kv_width: 8, hidden: 32 },
        BaseShifts { norm_tn: 10, qkv: 8, score: 6, pv: 9, ao: 7, gate: 8, up: 0, product: 14, down: 6 },
        (-3, -11),
        Multipliers { q: ms("m_q"), k: ms("m_k"), v: ms("m_v"), o: ms("m_o"), g: ms("m_g"), u: ms("m_u"), d: ms("m_d") },
        groups,
        f["groups"].iter().map(|&v| v as usize).collect(),
        tables,
    )
    .unwrap();
    let input = f["input"].iter().map(|&v| i16::try_from(v).unwrap()).collect();
    (sh, public, ff, accuracy, input)
}

fn line(stack: &str, name: &str, v: &[i64]) {
    let cells: Vec<String> = v.iter().map(|x| x.to_string()).collect();
    println!("L1\t{stack}\t{name}\t{}", cells.join("\t"));
}

fn export(stack: Stack, tag: &str) {
    let (sh, public, ff, accuracy, input) = fixture(stack);
    let tr: Trace = build(&sh, &public, &ff, &accuracy, &input).unwrap();
    let g = Geom::new(&sh);
    let dense = |dom: Dom, a: &[i64]| -> Vec<i64> { g.support(dom).into_iter().map(|i| a[i]).collect() };
    let rows = |a: &[i64]| -> Vec<i64> { (0..g.t).map(|t| a[t]).collect() };
    let heads = |a: &[i64]| -> Vec<i64> { (0..g.hq).flat_map(|h| (0..g.t).map(move |t| (h, t))).map(|(h, t)| a[g.htix(g.slot(h), t)]).collect() };
    let p = accuracy.precision();
    let folds = accuracy.folds();
    line(tag, "shifts", &[p.norm_tn as i64, p.q as i64, p.k as i64, p.v as i64, p.score as i64, p.pv as i64, p.ao as i64, p.up as i64, p.down as i64, p.f_p as i64, folds.gate.shift as i64, folds.product.shift as i64, sh.wrho_s as i64]);
    line(tag, "gate_mult", &folds.gate.multipliers.iter().map(|&m| m as i64).collect::<Vec<_>>());
    line(tag, "product_mult", &folds.product.multipliers.iter().map(|&m| m as i64).collect::<Vec<_>>());
    line(tag, "x", &dense(Dom::D, &tr.x));
    for (name, n) in [("na", &tr.na), ("nm", &tr.nm)] {
        line(tag, &format!("{name}.words"), &dense(Dom::D, &n.words));
        line(tag, &format!("{name}.rho"), &dense(Dom::D, &n.rho));
        line(tag, &format!("{name}.sigma"), &dense(Dom::D, &n.sigma));
        line(tag, &format!("{name}.d"), &rows(&n.d));
        line(tag, &format!("{name}.dsq"), &rows(&n.dsq));
        line(tag, &format!("{name}.a1"), &rows(&n.a1));
        line(tag, &format!("{name}.a2"), &rows(&n.a2));
    }
    for (name, dom, qz) in [
        ("q", Dom::Q, &tr.q),
        ("k", Dom::Kv, &tr.k),
        ("v", Dom::Kv, &tr.v),
        ("qr", Dom::Q, &tr.qr),
        ("kr", Dom::Kv, &tr.kr),
        ("s", Dom::S, &tr.s),
        ("o", Dom::Q, &tr.o),
        ("ao", Dom::D, &tr.ao),
        ("gate", Dom::F, &tr.gate),
        ("up", Dom::F, &tr.up),
        ("h", Dom::F, &tr.h),
        ("z", Dom::D, &tr.z),
    ] {
        line(tag, &format!("{name}.words"), &dense(dom, &qz.words));
        line(tag, &format!("{name}.rho"), &dense(dom, &qz.rho));
    }
    line(tag, "mx", &heads(&tr.mx));
    line(tag, "sum", &heads(&tr.sum));
    for (name, a) in [("zsel", &tr.zsel), ("e", &tr.e), ("p", &tr.p), ("sr", &tr.sr), ("sg", &tr.sg)] {
        line(tag, name, &dense(Dom::S, a));
    }
    line(tag, "a_scaled", &dense(Dom::F, &tr.a_scaled));
    line(tag, "x1", &dense(Dom::D, &tr.x1));
    line(tag, "x2", &dense(Dom::D, &tr.x2));
}

#[test]
fn lean_l1_export_the_fixture_trace() {
    export(Stack::LowH24, "low-h24");
    export(Stack::Low, "low");
}
