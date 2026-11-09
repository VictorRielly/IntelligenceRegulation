//! **D63 Lean lane L29 (2026-11-07): stage IN-C's and stage OUT-C's verifiers replayed on a REAL classifier receipt.**
//! TEST ONLY: a child of the test-only `private_block/token_io/classify_capture_tests.rs` (declared there by one
//! `#[cfg(test)]` line; the file lives in `src/`, not `src/private_block/`, as lanes L10's and L18's do, so `s25_tests`'
//! `TEST_ONLY_FILES` needs no entry). No prover or verifier source changes; nothing here is reachable from a production
//! build.
//!
//! What it does, on the development rung's classifier fixture (`classify_capture_tests::fx`, one block):
//! 1. proves an honest classifier run (`honest_run`) and verifies it with the production `verify_classify_run`;
//! 2. REPLAYS `stage_in_c::verify` (stage_in_c.rs:399-464) step by step with the production pieces (`define`,
//!    `run_stage_slot`, `finish_functionals`, `mask_verify_tagged`, `check_opening`, `verify_zk_tagged`,
//!    `check_token_endpoint_opening`) on a clone of the run's transcript, recording the stage's public data, the
//!    segment's roots and slot proofs, the head's challenges, the transcript after the head, after each slot and after
//!    each opening, every claim the slots leave per commitment and every `M` functional; the replay's final transcript
//!    and pending claims are ASSERTED equal to the production `stage_in_c::verify`'s on the run's transcript;
//! 3. replays the blocks as `verify_classify_run_with` does (lane L18's loop) to reach stage OUT-C's transcript and
//!    carry, then replays `stage_out_c::verify` (:658-749) the same way, asserted against the production verifier;
//! 4. writes the records to `LEAN_L29_CORPUS` (one record per line) and the two stage segments' bytes to
//!    `LEAN_L29_SEG_IN` / `LEAN_L29_SEG_OUT` (each over 1 MB: they stay outside the repository), for
//!    `formal/ZK60Formal/StageVerifyExecCheck.lean`, which runs Lean's executable stage verifiers on them.
//!
//! Every value is public: the fixture's public synthetic data, the receipt, the transcript's states and challenges, the
//! claims and functionals the verifier computes (no witness value, no mask, no RNG state is written).
use super::super::super::argument::{Acc, Side, SlotProof};
use super::super::super::boundary;
use super::super::super::hash_domain;
use super::super::super::protocol::{self, CoreView};
use super::super::super::timing;
use super::super::super::wire;
use super::super::stage_in_c::{self, InCCtx};
use super::super::stage_out_c::{self, OutCCtx};
use super::super::{check_token_endpoint_opening, finish_functionals, run_stage_slot, Dim, StageSegment, TAG_EMB};
use super::{fx, honest_run, POLICY_93};
use crate::field::{Fp, Fp2};
use crate::ntt::NttTables;
use crate::pcs::{self, ZClaim, ZkOpts};
use crate::transcript::Transcript;
use crate::zk::MaskFunctional;
use std::fmt::Write as _;

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn key(k: Option<&[u8; 32]>) -> String {
    k.map(|k| hex(k)).unwrap_or_else(|| "-".into())
}

/// `classify_run::position_tag`, replayed: two `challenge_fp2` of a clone.
fn tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

fn trs(tr: &Transcript) -> String {
    format!("{} {}", hex(&tr.state()), tr.counter())
}

fn f2(x: &Fp2) -> String {
    format!("{}:{}", x.c0.0, x.c1.0)
}

fn f2s(v: &[Fp2]) -> String {
    if v.is_empty() {
        "-".into()
    } else {
        v.iter().map(f2).collect::<Vec<_>>().join(",")
    }
}

/// one claim: its value, then each part `offset/log/coef/point`
fn claim(c: &ZClaim) -> String {
    let parts: Vec<String> = c.parts.iter().map(|p| format!("{}/{}/{}/{}", p.slice.offset, p.slice.log_size, f2(&p.coef), f2s(&p.point))).collect();
    format!("{} {}", f2(&c.value), if parts.is_empty() { "-".to_string() } else { parts.join(";") })
}

/// one functional: its value, then each term `slot/weights`
fn functional(f: &MaskFunctional) -> String {
    let terms: Vec<String> = f.terms.iter().map(|(s, w)| format!("{s}/{}", f2s(w))).collect();
    format!("{} {}", f2(&f.value), if terms.is_empty() { "-".to_string() } else { terms.join(";") })
}

fn dim(d: &Dim) -> String {
    format!("{} {} {} {}", d.checks, d.vec, d.enc_cols, d.path)
}

fn slot_line(pre: &str, s: usize, sp: &SlotProof) -> String {
    let rounds: Vec<String> = sp.sc.rounds.iter().map(|r| f2s(r)).collect();
    format!("{pre} {s} {} {} {}", f2(&sp.scalar), if rounds.is_empty() { "-".to_string() } else { rounds.join(";") }, f2s(&sp.terms))
}

fn roots(pre: &str, seg: &StageSegment) -> String {
    format!("{pre} {} {} {} {}", seg.b_root.map(|r| hex(&r)).unwrap_or_else(|| "-".into()), hex(&seg.a_root), hex(&seg.h_root), hex(&seg.mask_root))
}

#[test]
fn lean_l29_export_the_classify_stages() {
    let f = fx(1);
    let r = honest_run(&f, "1", None);
    let st = &r.st;
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    let segs = &r.segs;
    assert_eq!(segs.len(), l + 2, "a classifier run has L + 2 segments");
    super::super::classify_run::verify_classify_run(st, &f.blocks, &r.bound, segs, POLICY_93)
        .expect("the production verifier accepts the honest classifier run");
    let tables = r.bound.tables();
    let htag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript().expect("the run header");
    let binding = tr.state();
    let mut out = String::new();
    writeln!(out, "L29 STAGES {} L={l} segments={}", st.profile(), segs.len()).unwrap();
    writeln!(out, "KEY {}", tr.fs_key().map(|k| hex(&k)).unwrap_or_else(|| "-".into())).unwrap();
    writeln!(out, "MTAG {} {} {}", key(htag.column_key()), key(htag.leaf_key()), key(htag.node_key())).unwrap();
    writeln!(out, "BINDING {}", hex(&binding)).unwrap();

    // ---------------------------------------------------------------- stage IN-C
    let in_lay = stage_in_c::layout(sh, cp);
    let b0 = st.boundary_spec(0).unwrap();
    let ep = &st.in_spec;
    let start = tag(&tr);
    let (seg, end) = st.in_geom(&in_lay).decode(&segs[0], &binding, &start).expect("segment 0 decodes");
    let sn = 1usize << cp.ti_log();
    writeln!(out, "INP {} {} {} {} {} {} {} {}", cp.tokens, cp.t_pad, cp.d_pad, cp.v, cp.bos, cp.policy.num_special, cp.tier.stage_log_n, cp.tier.ep_log_n).unwrap();
    writeln!(out, "INGEO {} {} {} {} {}", b0.log_n(), b0.commitment_rows(), b0.mask_row(0).unwrap(), ep.data_rows(), ep.commitment_rows()).unwrap();
    writeln!(out, "INDIM {} {}", dim(&Dim::of(&in_lay.params)), dim(&Dim::of(&ep.params()))).unwrap();
    writeln!(out, "INPCS {} {} {} {}", in_lay.params.inv_rate.trailing_zeros(), ep.params().inv_rate.trailing_zeros(), in_lay.params.num_col_checks, ep.params().num_col_checks).unwrap();
    writeln!(out, "INDERIV {} {} {} {} {} {} {} {}", cp.ti_log(), cp.voc_log(), cp.in_ep_words(), (cp.t_pad * cp.d_pad).trailing_zeros(), in_lay.a_rows, in_lay.h_rows, in_lay.m_rows(), in_lay.n_functionals()).unwrap();
    writeln!(out, "INTMPL {}", (0..sn).map(|t| if cp.is_template(t) { '1' } else { '0' }).collect::<String>()).unwrap();
    writeln!(out, "INKAPPA {}", (0..sn).map(|t| cp.kappa(t).to_string()).collect::<Vec<_>>().join(",")).unwrap();
    writeln!(out, "INEMBDIG {}", hex(&cp.emb_digest)).unwrap();
    writeln!(out, "INSTART {}", trs(&tr)).unwrap();
    writeln!(out, "INTAG {} {}", hex(&start), hex(&end)).unwrap();
    writeln!(out, "INSEG {} {}", segs[0].len(), blake3::hash(&segs[0]).to_hex()).unwrap();
    writeln!(out, "{}", roots("INROOTS", &seg)).unwrap();
    for (s, sp) in seg.slots.iter().enumerate() {
        writeln!(out, "{}", slot_line("INSLOT", s, sp)).unwrap();
    }
    // the replay of stage_in_c::verify (stage_in_c.rs:411-463), on a clone of the run's transcript
    let mut rt = Transcript::clone_state(&tr);
    let b_root = seg.b_root.expect("stage IN-C's segment carries B_in's root");
    rt.absorb_u64(b"pb-run-stage", 0);
    rt.absorb(b"pb-run-block", &cp.emb_digest);
    protocol::absorb_root(&mut rt, b"B", &b_root, b0.commitment_rows(), b0.log_n());
    protocol::absorb_root(&mut rt, b"A", &seg.a_root, in_lay.a_rows, in_lay.log_n);
    rt.absorb(b"M", &seg.mask_root);
    let beta = rt.challenge_fp2();
    let gamma = rt.challenge_fp2();
    let alpha = rt.challenge_fp2();
    let r_emb = rt.challenge_fp2_vec(cp.d_pad.next_power_of_two().trailing_zeros() as usize);
    let g_emb = gamma.mul_base(Fp::new(TAG_EMB));
    let ef = tables.emb_fold(&r_emb);
    let tau_tab = stage_in_c::tau_table(cp, &ef, beta, g_emb);
    protocol::absorb_root(&mut rt, b"H", &seg.h_root, in_lay.h_rows, in_lay.log_n);
    let mut ch = vec![beta, gamma, alpha];
    ch.extend(r_emb.iter().copied());
    writeln!(out, "INEF {}", f2s(&ef)).unwrap();
    writeln!(out, "INHEAD {} {}", trs(&rt), f2s(&ch)).unwrap();
    let cx = InCCtx {
        lay: &in_lay,
        cp,
        alpha,
        beta,
        g_emb,
        r_emb: r_emb.clone(),
        tau_tab,
        b_in_row: b0.mask_row(0).unwrap(),
        b_in_log: (cp.t_pad * cp.d_pad).trailing_zeros() as usize,
        ep_mask_row: ep.data_rows(),
    };
    let mut side = Side::Verify { slots: &seg.slots };
    let mut acc = Acc::default();
    for s in 0..in_lay.sched.slots.len() {
        let def = stage_in_c::define(s, &cx, &mut rt).expect("IN-C define");
        run_stage_slot(&mut side, &mut acc, def, &in_lay.sched, &mut rt).expect("IN-C slot");
        writeln!(out, "INAFTER {s} {}", trs(&rt)).unwrap();
    }
    let acc = finish_functionals(acc, &in_lay).expect("IN-C functionals");
    for (cm, cl) in acc.claims.iter().enumerate() {
        for c in cl {
            writeln!(out, "INCLAIM {cm} {}", claim(c)).unwrap();
        }
    }
    for fu in &acc.fs {
        writeln!(out, "INFUN {}", functional(fu)).unwrap();
    }
    crate::zk::mask_verify_tagged(&seg.mask_root, &in_lay.mask_specs(), &acc.fs, &seg.mask_open, &ntt, &mut rt, &htag).expect("IN-C M");
    writeln!(out, "INPHASE m {}", trs(&rt)).unwrap();
    let [ac, mut hc, ic, oc] = acc.claims;
    hc.push(in_lay.logup_sum_claim());
    let params = in_lay.params;
    let zko = ZkOpts::standard(&params);
    protocol::check_opening(&ac, in_lay.log_n, in_lay.a_rows, &in_lay.a_site_rows(), None, in_lay.a_prox, stage_in_c::A_GROUPS, &rt).expect("IN-C check A");
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.a_root, in_lay.a_rows, in_lay.log_n), &ac, &seg.a_open, &ntt, &mut rt, &htag).expect("IN-C A");
    writeln!(out, "INPHASE a {}", trs(&rt)).unwrap();
    protocol::check_opening(&hc, in_lay.log_n, in_lay.h_rows, &in_lay.h_site_rows(), Some(in_lay.h_u_rows()), in_lay.h_prox, stage_in_c::H_GROUPS, &rt).expect("IN-C check H");
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.h_root, in_lay.h_rows, in_lay.log_n), &hc, &seg.h_open, &ntt, &mut rt, &htag).expect("IN-C H");
    writeln!(out, "INPHASE h {}", trs(&rt)).unwrap();
    check_token_endpoint_opening(&ic, ep.data_rows(), cp.tier.ep_n(), &rt).expect("IN-C token endpoint audit");
    let ep_params = ep.params();
    pcs::verify_zk_tagged(&ep_params, &ZkOpts::standard(&ep_params), &protocol::commitment(st.in_root(), ep.commitment_rows(), cp.tier.ep_log_n), &ic, &seg.closes[0], &ntt, &mut rt, &htag).expect("IN-C endpoint");
    writeln!(out, "INPHASE ep {}", trs(&rt)).unwrap();
    writeln!(out, "INEPROOT {}", hex(&st.in_root())).unwrap();
    writeln!(out, "INRESULT {} {}", oc.len(), hex(&b_root)).unwrap();
    // the production verifier on the run's own transcript: the replay is the code's
    let (mut pending, b_root_p) = stage_in_c::verify(&in_lay, cp, tables, &seg, &b0, ep, &st.in_root(), &ntt, &mut tr, &htag).expect("stage IN-C (production)");
    assert_eq!(rt.state(), tr.state(), "the IN-C replay ends on the production verifier's transcript");
    assert_eq!(rt.counter(), tr.counter());
    assert_eq!(b_root_p, b_root);
    assert_eq!(pending.len(), oc.len());
    assert!(pending.iter().zip(oc.iter()).all(|(a, b)| claim(a) == claim(b)), "the pending claims are the replay's");
    assert_eq!(tag(&tr), end, "stage IN-C's end tag");
    if let Ok(p) = std::env::var("LEAN_L29_SEG_IN") {
        std::fs::write(&p, &segs[0]).unwrap_or_else(|e| panic!("writing {p}: {e}"));
    }

    // ---------------------------------------------------------------- the blocks (lane L18's replay)
    let mut prev = (b0, b_root);
    for k in 0..l {
        let blk = &f.blocks[k];
        let lay = st.block_layout(k).unwrap();
        let start = tag(&tr);
        let (bseg, bend) = wire::decode_segment(&segs[k + 1], &lay, st.block_geom(k).unwrap(), &binding, &start).expect("a block segment decodes");
        hash_domain::segment_paths_are_the_tree_depth(&bseg, sh).expect("the paths' depth");
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1).unwrap();
        let root = bseg.b_root.expect("a block segment carries its boundary root");
        protocol::absorb_root(&mut tr, b"B", &root, spec.commitment_rows(), spec.log_n());
        let view = CoreView { a_root: bseg.a_root, h_root: bseg.h_root, mask_root: bseg.mask_root, slots: &bseg.slots, mask_open: &bseg.mask_open, a_open: &bseg.a_open, h_open: &bseg.h_open };
        let ssh = st.stage_shape(k).unwrap();
        let mut ph = timing::Phases::start();
        let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, blk, view, &ntt, &mut tr, &mut ph).expect("verify_core");
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, proot) = prev;
        boundary::check_opening(&pspec, &claims, &tr).expect("the boundary audit");
        let bp = pspec.params();
        pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(proot, pspec.commitment_rows(), pspec.log_n()), &claims, &bseg.in_open, &ntt, &mut tr, &htag)
            .expect("the boundary opening");
        pending = oc;
        prev = (spec, root);
        assert_eq!(tag(&tr), bend, "block {k}'s end tag");
    }

    // ---------------------------------------------------------------- stage OUT-C
    let out_lay = stage_out_c::layout(sh, cp);
    let (bspec, broot) = prev;
    let start = tag(&tr);
    let (seg, end) = st.out_geom(&out_lay).unwrap().decode(&segs[l + 1], &binding, &start).expect("segment L + 1 decodes");
    let verdict = st.verdict();
    let w = &tables.w_delta;
    writeln!(out, "OUTP {} {} {} {} {} {} {} {} {} {} {} {}", cp.d, cp.d_pad, cp.t_pad, cp.tier.stage_log_n, cp.limbs, cp.policy.c, cp.norm.ceps, cp.norm.g0, cp.norm.cn, cp.norm.tn, cp.verdict_row(), verdict).unwrap();
    writeln!(out, "OUTGEO {} {} {} {} {}", bspec.log_n(), bspec.commitment_rows(), bspec.data_rows(), bspec.sites(), bspec.mask_row(1).unwrap()).unwrap();
    writeln!(out, "OUTDIM {} {}", dim(&Dim::of(&out_lay.params)), dim(&Dim::of(&bspec.params()))).unwrap();
    writeln!(out, "OUTPCS {} {} {} {} {}", out_lay.params.inv_rate.trailing_zeros(), bspec.params().inv_rate.trailing_zeros(), out_lay.params.num_col_checks, bspec.params().num_col_checks, l + 1).unwrap();
    writeln!(out, "OUTDERIV {} {} {} {} {} {} {} {} {}", cp.lo_log(), cp.do_log(), cp.tab_log(), (cp.t_pad * cp.d_pad).trailing_zeros(), out_lay.a_rows, out_lay.h_rows, out_lay.m_rows(), out_lay.n_functionals(), out_lay.a_off[stage_out_c::C_LIMB]).unwrap();
    writeln!(out, "OUTWD {}", w.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")).unwrap();
    writeln!(out, "OUTWDIG {}", hex(&cp.w_digest)).unwrap();
    writeln!(out, "OUTSTART {}", trs(&tr)).unwrap();
    writeln!(out, "OUTTAG {} {}", hex(&start), hex(&end)).unwrap();
    writeln!(out, "OUTSEG {} {}", segs[l + 1].len(), blake3::hash(&segs[l + 1]).to_hex()).unwrap();
    writeln!(out, "OUTBROOT {}", hex(&broot)).unwrap();
    for c in &pending {
        writeln!(out, "OUTPEND {}", claim(c)).unwrap();
    }
    writeln!(out, "{}", roots("OUTROOTS", &seg)).unwrap();
    for (s, sp) in seg.slots.iter().enumerate() {
        writeln!(out, "{}", slot_line("OUTSLOT", s, sp)).unwrap();
    }
    // the replay of stage_out_c::verify (stage_out_c.rs:672-748)
    let stage_index = (l + 1) as u64;
    let mut rt = Transcript::clone_state(&tr);
    rt.absorb_u64(b"pb-run-stage", stage_index);
    rt.absorb(b"pb-run-block", &cp.w_digest);
    protocol::absorb_root(&mut rt, b"A", &seg.a_root, out_lay.a_rows, out_lay.log_n);
    rt.absorb(b"M", &seg.mask_root);
    let gamma = rt.challenge_fp2();
    let alpha = rt.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(crate::tables_attn::TAG_U8));
    protocol::absorb_root(&mut rt, b"H", &seg.h_root, out_lay.h_rows, out_lay.log_n);
    writeln!(out, "OUTHEAD {} {}", trs(&rt), f2s(&[gamma, alpha])).unwrap();
    let cx = OutCCtx { lay: &out_lay, cp, tables, verdict, alpha, g_u8, b_out_row: bspec.mask_row(1).unwrap(), b_out_log: (cp.t_pad * cp.d_pad).trailing_zeros() as usize };
    let mut side = Side::Verify { slots: &seg.slots };
    let mut acc = Acc::default();
    for s in 0..out_lay.sched.slots.len() {
        let def = stage_out_c::define(s, &cx, &mut rt).expect("OUT-C define");
        run_stage_slot(&mut side, &mut acc, def, &out_lay.sched, &mut rt).expect("OUT-C slot");
        writeln!(out, "OUTAFTER {s} {}", trs(&rt)).unwrap();
    }
    let acc = finish_functionals(acc, &out_lay).expect("OUT-C functionals");
    for (cm, cl) in acc.claims.iter().enumerate() {
        for c in cl {
            writeln!(out, "OUTCLAIM {cm} {}", claim(c)).unwrap();
        }
    }
    for fu in &acc.fs {
        writeln!(out, "OUTFUN {}", functional(fu)).unwrap();
    }
    crate::zk::mask_verify_tagged(&seg.mask_root, &out_lay.mask_specs(), &acc.fs, &seg.mask_open, &ntt, &mut rt, &htag).expect("OUT-C M");
    writeln!(out, "OUTPHASE m {}", trs(&rt)).unwrap();
    let [ac, mut hc, ic, oc] = acc.claims;
    assert!(oc.is_empty(), "no claim on an output endpoint");
    hc.push(out_lay.logup_sum_claim());
    let params = out_lay.params;
    let zko = ZkOpts::standard(&params);
    protocol::check_opening(&ac, out_lay.log_n, out_lay.a_rows, &out_lay.a_site_rows(), None, out_lay.a_prox, stage_out_c::A_GROUPS, &rt).expect("OUT-C check A");
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.a_root, out_lay.a_rows, out_lay.log_n), &ac, &seg.a_open, &ntt, &mut rt, &htag).expect("OUT-C A");
    writeln!(out, "OUTPHASE a {}", trs(&rt)).unwrap();
    protocol::check_opening(&hc, out_lay.log_n, out_lay.h_rows, &out_lay.h_site_rows(), Some(out_lay.h_u_rows()), out_lay.h_prox, stage_out_c::H_GROUPS, &rt).expect("OUT-C check H");
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.h_root, out_lay.h_rows, out_lay.log_n), &hc, &seg.h_open, &ntt, &mut rt, &htag).expect("OUT-C H");
    writeln!(out, "OUTPHASE h {}", trs(&rt)).unwrap();
    let mut claims = pending.clone();
    claims.extend(ic);
    boundary::check_opening(&bspec, &claims, &rt).expect("OUT-C's boundary audit");
    let bpp = bspec.params();
    pcs::verify_zk_tagged(&bpp, &ZkOpts::standard(&bpp), &protocol::commitment(broot, bspec.commitment_rows(), bspec.log_n()), &claims, &seg.closes[0], &ntt, &mut rt, &htag).expect("B_out");
    writeln!(out, "OUTPHASE b {}", trs(&rt)).unwrap();
    stage_out_c::verify(&out_lay, cp, tables, verdict, &seg, &bspec, &broot, pending, stage_index, &ntt, &mut tr, &htag).expect("stage OUT-C (production)");
    assert_eq!(rt.state(), tr.state(), "the OUT-C replay ends on the production verifier's transcript");
    assert_eq!(rt.counter(), tr.counter());
    assert_eq!(tag(&tr), end, "stage OUT-C's end tag");
    writeln!(out, "OUTRESULT {}", trs(&tr)).unwrap();
    if let Ok(p) = std::env::var("LEAN_L29_SEG_OUT") {
        std::fs::write(&p, &segs[l + 1]).unwrap_or_else(|e| panic!("writing {p}: {e}"));
    }
    writeln!(out, "END").unwrap();
    eprintln!("LEAN-L29 | the classify run's stages replayed (rung, L = {l}, verdict {verdict}): IN-C {} B, OUT-C {} B, corpus {} B", segs[0].len(), segs[l + 1].len(), out.len());
    if let Ok(path) = std::env::var("LEAN_L29_CORPUS") {
        std::fs::write(&path, &out).unwrap_or_else(|e| panic!("writing {path}: {e}"));
        eprintln!("LEAN-L29 | wrote {path}");
    }
}
