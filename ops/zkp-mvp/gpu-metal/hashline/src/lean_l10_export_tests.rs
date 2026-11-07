//! **D63 lane L10 (Lean, 2026-11-07): a REAL W16R2 block core receipt's `M`, `A` and `H` openings, exported for the
//! executable Lean verifiers (`formal/ZK60Formal/ExecOpening.lean`, `ExecOpeningM.lean`) to re-verify.**
//!
//! TEST ONLY. Declared `#[cfg(test)]` by ONE line in `private_block/w16r2_tests.rs` (so that it can use that file's
//! seeded W16R2 rung harness: `rung_case`, `prove`, `header`); it lives in `src/`, not `src/private_block/`, so
//! `s25_tests.rs`'s directory check (TOKEN ROUND 19b) needs no new entry. No production path calls it, and no
//! production source changes.
//!
//! What it does: proves the W16R2 development rung's block core (`W16R2_RUNG_H24`, the public synthetic fixture of
//! `range16_tests::rung_case`, the seeded M4 recipe of `w16r2_tests::prove`), then replays the verifier body
//! `protocol::verify_core` step by step (the A root, M root, the LogUp challenges, the H root, the twenty-three slots
//! through `argument`), recording the transcript BEFORE each of the three openings the body verifies: `M`
//! (`zk::mask_verify_tagged`), `A` and `H` (`pcs::verify_zk_tagged`). For each it writes the opening, the claims or
//! functionals the verifier computed, the commitment, the profile's hash-tag keys, the transcript before, and the
//! crate's verdict and transcript after; then the same for tampered copies (the crate's verdict on each).
//! The replay is checked against the body itself: the transcript after `H` equals `verify_core`'s.
//!
//! Output: `LEAN_L10_CORPUS=<path>` (it is several MB, so it is written OUTSIDE the repository by the lane's script);
//! without the variable only the record counts are printed. Run:
//!   cargo test --release --offline --locked -j 2 --lib lean_l10_export -- --nocapture
use super::*;
use crate::private_block::argument::{argument, Ctx, Side};
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use crate::zk::{self, MaskOpening};
use std::fmt::Write as _;

fn hex(b: &[u8]) -> String {
    let mut s = String::with_capacity(2 * b.len());
    for x in b {
        let _ = write!(s, "{x:02x}");
    }
    s
}

fn key(k: Option<&[u8; 32]>) -> String {
    k.map(|k| hex(k)).unwrap_or_else(|| "-".to_string())
}

fn fp_csv(v: &[Fp]) -> String {
    if v.is_empty() {
        return "-".into();
    }
    v.iter().map(|x| x.0.to_string()).collect::<Vec<_>>().join(",")
}

fn fp2_csv(v: &[Fp2]) -> String {
    if v.is_empty() {
        return "-".into();
    }
    v.iter().map(|x| format!("{}:{}", x.c0.0, x.c1.0)).collect::<Vec<_>>().join(",")
}

fn path_csv(p: &[[u8; 32]]) -> String {
    if p.is_empty() {
        return "-".into();
    }
    p.iter().map(|d| hex(d)).collect::<Vec<_>>().join(",")
}

fn tr_line(t: &Transcript) -> String {
    format!("{} {} {}", hex(&t.state()), t.counter(), key(t.fs_key().as_ref()))
}

struct Out {
    s: String,
    records: usize,
}

impl Out {
    fn line(&mut self, l: String) {
        self.s.push_str(&l);
        self.s.push('\n');
    }
}

fn columns(o: &mut Out, cols: &[(usize, Vec<Fp>, [u8; 32], Vec<[u8; 32]>)]) {
    for (j, col, salt, path) in cols {
        o.line(format!("L10C {j} {} {} {}", fp_csv(col), hex(salt), path_csv(path)));
    }
}

/// one `M` record: the opening, the functionals, the transcript before, the crate's verdict and transcript after
fn mask_record(o: &mut Out, name: &str, root: &[u8; 32], specs: &[(usize, usize)], fs: &[zk::MaskFunctional], op: &MaskOpening, before: &Transcript, tag: &HashTag) {
    let ntt = NttTables::new(zk::MASK_LOG_DOM);
    let mut tr = Transcript::clone_state(before);
    let v = zk::mask_verify_tagged(root, specs, fs, op, &ntt, &mut tr, tag);
    o.line(format!("L10M {name} {} {} {}", specs.len(), hex(root), v.is_ok() as u8));
    if let Err(e) = &v {
        o.line(format!("L10ERR {e}"));
    }
    o.line(format!("L10TR {}", tr_line(before)));
    for f in fs {
        o.line(format!("L10F {}:{} {}", f.value.c0.0, f.value.c1.0, f.terms.len()));
        for (s, w) in &f.terms {
            o.line(format!("L10T {s} {}", fp2_csv(w)));
        }
    }
    o.line(format!("L10Q {}", fp2_csv(&op.q)));
    o.line(format!("L10X {}", fp2_csv(&op.prox)));
    columns(o, &op.columns);
    o.line(format!("L10END {}", if v.is_ok() { tr_line(&tr) } else { "-".into() }));
    o.records += 1;
}

/// one regular opening's record
#[allow(clippy::too_many_arguments)]
fn pcs_record(o: &mut Out, name: &str, params: &PcsParams, zko: &ZkOpts, root: [u8; 32], rows: usize, claims: &[ZClaim], op: &OpeningZk, before: &Transcript, tag: &HashTag) {
    let ntt = NttTables::new(params.log_cols + params.inv_rate.trailing_zeros());
    let mut tr = Transcript::clone_state(before);
    let cm = Commitment { root, rows, log_cols: params.log_cols };
    let v = zpcs::verify_zk_tagged(params, zko, &cm, claims, op, &ntt, &mut tr, tag);
    o.line(format!("L10PCS {name} {} {} {} {} {rows} {} {} {}", params.log_cols, params.inv_rate, params.num_col_checks, zko.q_pad, params.log_cols, hex(&root), v.is_ok() as u8));
    if let Err(e) = &v {
        o.line(format!("L10ERR {e}"));
    }
    o.line(format!("L10TR {}", tr_line(before)));
    for c in claims {
        o.line(format!("L10CLAIM {}:{} {}", c.value.c0.0, c.value.c1.0, c.parts.len()));
        for p in &c.parts {
            o.line(format!("L10PART {} {} {}:{} {}", p.slice.offset, p.slice.log_size, p.coef.c0.0, p.coef.c1.0, fp2_csv(&p.point)));
        }
    }
    for g in &op.group_vecs {
        o.line(format!("L10G {}", fp2_csv(g)));
    }
    o.line(format!("L10P {}", fp2_csv(&op.prox_vec)));
    columns(o, &op.columns);
    o.line(format!("L10END {}", if v.is_ok() { tr_line(&tr) } else { "-".into() }));
    o.records += 1;
}

#[test]
fn lean_l10_export_the_w16r2_rung_openings() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    let lay = Layout::for_shape(&sh).unwrap();
    let t0 = std::time::Instant::now();
    let core = prove(&sh, &blk, copy(&w)).expect("the seeded W16R2 rung core proof");
    let prove_s = t0.elapsed().as_secs_f64();
    // the verifier body, step by step (`protocol::verify_core`, its transcript operations in order)
    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let mut tr = header(&sh, &lay);
    let (public, ff) = (blk.attention(), blk.feed_forward());
    let params = protocol::pcs_params_at(&sh);
    let zko = ZkOpts::standard(&params);
    let tag = sh.hash_tag();
    protocol::absorb_root(&mut tr, b"A", &core.a_root, lay.a_rows, sh.log_cols);
    tr.absorb(b"M", &core.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(TAG_ACT));
    protocol::absorb_root(&mut tr, b"H", &core.h_root, lay.h_rows, sh.log_cols);
    let g_dd = gamma.mul_base(Fp::new(TAG_DD));
    let ctx = Ctx { accuracy: blk.accuracy(), lay: &lay, public, ff, alpha, beta, g_u8, g_exp, g_act, g_dd };
    let mut side = Side::Verify { slots: &core.slots };
    let mut ph = super::timing::Phases::start();
    let acc = argument(&mut side, &ctx, &mut tr, &mut ph).expect("the slots verify");
    let specs = lay.mask_specs();
    let before_m = Transcript::clone_state(&tr);
    zk::mask_verify_tagged(&core.mask_root, &specs, &acc.fs, &core.mask_open, &ntt, &mut tr, &tag).expect("M verifies");
    let [ac, mut hc, _, _] = acc.claims;
    hc.push(protocol::logup_sum_claim(&lay));
    let before_a = Transcript::clone_state(&tr);
    zpcs::verify_zk_tagged(&params, &zko, &protocol::commitment(core.a_root, lay.a_rows, sh.log_cols), &ac, &core.a_open, &ntt, &mut tr, &tag).expect("A verifies");
    let before_h = Transcript::clone_state(&tr);
    zpcs::verify_zk_tagged(&params, &zko, &protocol::commitment(core.h_root, lay.h_rows, sh.log_cols), &hc, &core.h_open, &ntt, &mut tr, &tag).expect("H verifies");
    // the replay IS the body: the same transcript after H
    {
        let mut vt = header(&sh, &lay);
        let view = CoreView { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: &core.slots, mask_open: &core.mask_open, a_open: &core.a_open, h_open: &core.h_open };
        let mut vph = super::timing::Phases::start();
        protocol::verify_core(&sh, &lay, &blk, view, &ntt, &mut vt, &mut vph).expect("the honest core verifies");
        assert_eq!(vt.state(), tr.state(), "the step-by-step replay left the body's transcript");
        assert_eq!(vt.counter(), tr.counter());
    }
    let mut o = Out { s: String::new(), records: 0 };
    o.line(format!("# D63 lane L10 corpus: the W16R2 rung block core ({}), M / A / H openings, honest and tampered", sh.profile));
    let nt = NttTables::new(15);
    for k in [9u32, 12, 14, 15] {
        o.line(format!("L10ROOT {k} {}", nt.roots[k as usize].0));
    }
    o.line(format!("L10TAG {} {} {} {}", key(tag.column_key()), key(tag.leaf_key()), key(tag.node_key()), key(tag.transcript_key())));
    // ---------------------------------------------------------------- M
    mask_record(&mut o, "m-honest", &core.mask_root, &specs, &acc.fs, &core.mask_open, &before_m, &tag);
    let bump = |x: Fp2| x.add(Fp2::ONE);
    let mut m1 = core.mask_open.clone();
    m1.q[0] = bump(m1.q[0]);
    mask_record(&mut o, "m-q0", &core.mask_root, &specs, &acc.fs, &m1, &before_m, &tag);
    let mut m2 = core.mask_open.clone();
    m2.q[5] = bump(m2.q[5]);
    mask_record(&mut o, "m-q5", &core.mask_root, &specs, &acc.fs, &m2, &before_m, &tag);
    let mut m3 = core.mask_open.clone();
    m3.prox[3] = bump(m3.prox[3]);
    mask_record(&mut o, "m-prox3", &core.mask_root, &specs, &acc.fs, &m3, &before_m, &tag);
    let mut fs4 = acc.fs.clone();
    fs4[0].value = bump(fs4[0].value);
    mask_record(&mut o, "m-value0", &core.mask_root, &specs, &fs4, &core.mask_open, &before_m, &tag);
    let mut m5 = core.mask_open.clone();
    m5.columns[0].1[0] = m5.columns[0].1[0].add(Fp::ONE);
    mask_record(&mut o, "m-col0", &core.mask_root, &specs, &acc.fs, &m5, &before_m, &tag);
    let mut m6 = core.mask_open.clone();
    m6.columns[1].0 ^= 1;
    mask_record(&mut o, "m-index1", &core.mask_root, &specs, &acc.fs, &m6, &before_m, &tag);
    let mut m7 = core.mask_open.clone();
    m7.columns[2].3.pop();
    mask_record(&mut o, "m-path2", &core.mask_root, &specs, &acc.fs, &m7, &before_m, &tag);
    let mut m8 = core.mask_open.clone();
    let last = m8.columns.len() - 1;
    m8.columns[last].1[1] = m8.columns[last].1[1].add(Fp::ONE);
    mask_record(&mut o, "m-collast", &core.mask_root, &specs, &acc.fs, &m8, &before_m, &tag);
    // ---------------------------------------------------------------- A and H
    pcs_record(&mut o, "a-honest", &params, &zko, core.a_root, lay.a_rows, &ac, &core.a_open, &before_a, &tag);
    pcs_record(&mut o, "h-honest", &params, &zko, core.h_root, lay.h_rows, &hc, &core.h_open, &before_h, &tag);
    // A's opening is the larger (36 groups at the rung): its tamperings are the ones refused BEFORE the clear vectors
    // are absorbed; H's (9 groups) are the ones that replay the absorbs and the indices
    let n = params.cols();
    let mut a1 = core.a_open.clone();
    a1.group_vecs[0][0] = bump(a1.group_vecs[0][0]);
    pcs_record(&mut o, "a-vec0", &params, &zko, core.a_root, lay.a_rows, &ac, &a1, &before_a, &tag);
    let mut ac3 = ac.clone();
    ac3[0].value = bump(ac3[0].value);
    pcs_record(&mut o, "a-claim0", &params, &zko, core.a_root, lay.a_rows, &ac3, &core.a_open, &before_a, &tag);
    let mut a6 = core.a_open.clone();
    a6.columns[2].3.pop();
    pcs_record(&mut o, "a-path2", &params, &zko, core.a_root, lay.a_rows, &ac, &a6, &before_a, &tag);
    let mut h2 = core.h_open.clone();
    h2.group_vecs[0][n] = bump(h2.group_vecs[0][n]);
    pcs_record(&mut o, "h-pad0", &params, &zko, core.h_root, lay.h_rows, &hc, &h2, &before_h, &tag);
    let mut h3 = core.h_open.clone();
    let lv = h3.group_vecs.len() - 1;
    h3.group_vecs[lv][1] = bump(h3.group_vecs[lv][1]);
    pcs_record(&mut o, "h-veclast", &params, &zko, core.h_root, lay.h_rows, &hc, &h3, &before_h, &tag);
    let mut h4 = core.h_open.clone();
    h4.columns[0].1[0] = h4.columns[0].1[0].add(Fp::ONE);
    pcs_record(&mut o, "h-col0", &params, &zko, core.h_root, lay.h_rows, &hc, &h4, &before_h, &tag);
    let mut h5 = core.h_open.clone();
    h5.columns[1].0 ^= 1;
    pcs_record(&mut o, "h-index1", &params, &zko, core.h_root, lay.h_rows, &hc, &h5, &before_h, &tag);
    let mut h6 = core.h_open.clone();
    h6.columns.pop();
    pcs_record(&mut o, "h-ncols", &params, &zko, core.h_root, lay.h_rows, &hc, &h6, &before_h, &tag);
    let mut h7 = core.h_open.clone();
    h7.prox_vec[0] = bump(h7.prox_vec[0]);
    pcs_record(&mut o, "h-prox0", &params, &zko, core.h_root, lay.h_rows, &hc, &h7, &before_h, &tag);
    // a claim's coefficient changed: the claim check still passes (the values and the vectors are the same, and
    // claims are not absorbed), the transcript and the indices are the same, and the FIRST column's check against
    // the clear vectors fails: the encoder's column equation itself is exercised
    let mut hc8 = hc.clone();
    hc8[0].parts[0].coef = bump(hc8[0].parts[0].coef);
    pcs_record(&mut o, "h-coef0", &params, &zko, core.h_root, lay.h_rows, &hc8, &core.h_open, &before_h, &tag);
    let mut h1 = core.h_open.clone();
    let lastc = h1.columns.len() - 1;
    h1.columns[lastc].1[0] = h1.columns[lastc].1[0].add(Fp::ONE);
    pcs_record(&mut o, "h-collast", &params, &zko, core.h_root, lay.h_rows, &hc, &h1, &before_h, &tag);
    o.line(format!("L10SHAPE {} {} {} {} {} {}", sh.profile, lay.a_rows, lay.h_rows, specs.len(), core.a_open.group_vecs.len(), core.h_open.group_vecs.len()));
    eprintln!(
        "LEAN-L10: {} records, {} bytes; prove {prove_s:.1} s; A {} rows {} groups, H {} rows {} groups, M {} masks, {} functionals",
        o.records, o.s.len(), lay.a_rows, core.a_open.group_vecs.len(), lay.h_rows, core.h_open.group_vecs.len(), specs.len(), acc.fs.len()
    );
    if let Ok(path) = std::env::var("LEAN_L10_CORPUS") {
        std::fs::write(&path, &o.s).expect("write the corpus");
        eprintln!("LEAN-L10: written to {path}");
    }
}
