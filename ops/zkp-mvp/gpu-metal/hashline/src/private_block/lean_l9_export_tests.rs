//! **D63 step L9 (Lean lane, 2026-11-07): one real W16R2 block receipt, framed as a D55 fork frame, and EVERY
//! transcript challenge its verifier draws, written for the Lean block verifier to recompute.**
//!
//! TEST ONLY. The block is the W16R2 development rung's core (`range16_tests::rung_case(W16R2_RUNG_H24)`), proved by
//! the production `protocol::prove_core` with `w16r2_tests`'s seeded recipe (`prove`, its rng seed and its header), so
//! the frame is the same bytes on every run. It is public synthetic data (the fixture's weights and input), so
//! writing it reveals nothing; no production path calls this module.
//!
//! What it writes (to `$L9_OUT`, a directory; nothing is written when the variable is unset, every assertion still
//! runs):
//! * `fork_frame.bin`: the core framed by the PRODUCTION encoder `wire::fork::encode_fork` (`HLPFORK1`, `L = 1`,
//!   `k = 0`, the binding and both position tags), and checked by the production `decode_fork` and `verify_core`;
//! * `corpus.txt`: the frame's length and digest, the starting transcript, the shape's schedule (per slot its rounds,
//!   extension rounds, degree, terminal count and name), and every challenge `verify_core` draws, in its order: the
//!   three LogUp challenges, per slot the challenges `define` draws (counted by squeezing a clone until its state is
//!   the transcript's), the CFS challenge `c`, the claimed sum, the round challenges, the final value and `g(ρ)`; `M`'s
//!   `θ`, row challenges and column indices; per opening the group counts, the `λ`s, the proximity row challenges and
//!   the column indices; the transcript state after every phase; and twelve single-change frames with the verdict of
//!   the production decoder and verifier.
//!
//! Every replayed phase is asserted to end in the production transcript's state and counter, so the recorded schedule
//! IS the code's. The Lean side is `formal/ZK60Formal/ExecBlockCheck.lean`. Registered by one `#[cfg(test)]` line in
//! `w16r2_tests.rs` (whose harness it uses) and listed in `s25_tests.rs`'s `TEST_ONLY_FILES`.
use super::*;
use crate::private_block::argument::{self as arg, Acc, Ctx, Points, Side};
use crate::private_block::layout::{SLOT_NAMES, TAG_DD};
use crate::private_block::wire::fork::{self as fw, ForkFrame};
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use std::fmt::Write as _;

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn f2(x: &Fp2) -> String {
    format!("{},{}", x.c0.0, x.c1.0)
}

fn f2s(v: &[Fp2]) -> String {
    if v.is_empty() {
        "-".into()
    } else {
        v.iter().map(f2).collect::<Vec<_>>().join(",")
    }
}

fn nums(v: &[usize]) -> String {
    if v.is_empty() {
        "-".into()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

/// `run::position_tag` (private there): two `challenge_fp2` of a clone, as 32 bytes
fn pos_tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

fn st(tr: &Transcript) -> String {
    format!("{} {}", hex(&tr.state()), tr.counter())
}

/// the challenges between two transcripts that differ by squeezes only: squeeze a clone of `from` until it is `to`
fn draws_between(from: &Transcript, to: &Transcript) -> Vec<Fp2> {
    let mut probe = Transcript::clone_state(from);
    let mut out = Vec::new();
    while probe.state() != to.state() || probe.counter() != to.counter() {
        out.push(probe.challenge_fp2());
        assert!(out.len() < 4096, "define changed the transcript by something other than squeezes");
    }
    out
}

/// `verify_one_fork`'s body on bytes (`run_fork.rs`), at this harness's header: decode, T-4, `verify_core`, end tag
fn verify_fork_bytes(sh: &Shape, lay: &Layout, blk: &BlockPublic, binding: &[u8; 32], bytes: &[u8]) -> Result<(), String> {
    let start = header(sh, lay);
    let start_tag = pos_tag(&start);
    let (frame, end_tag) = fw::decode_fork(bytes, lay, binding, 1, 0, &start_tag)?;
    let bp = protocol::pcs_params_at(sh);
    super::super::hash_domain::paths_are_the_tree_depth("A", &bp, &frame.a_open)?;
    super::super::hash_domain::paths_are_the_tree_depth("H", &bp, &frame.h_open)?;
    super::super::hash_domain::mask_paths_are_the_tree_depth(&frame.mask_open)?;
    let view = CoreView { a_root: frame.a_root, h_root: frame.h_root, mask_root: frame.mask_root, slots: &frame.slots, mask_open: &frame.mask_open, a_open: &frame.a_open, h_open: &frame.h_open };
    let ntt = NttTables::new(protocol::ntt_log_at(sh));
    let mut f = start;
    let mut ph = super::super::timing::Phases::start();
    protocol::verify_core(sh, lay, blk, view, &ntt, &mut f, &mut ph)?;
    if pos_tag(&f) != end_tag {
        return Err("fork 0's end tag is not the verifier's own fork-0 position".into());
    }
    Ok(())
}

/// the transcript challenges of one hiding opening (`pcs::verify_zk_tagged`'s `zk_rhos`, absorbs, indices), replayed
/// on `tr`; returns `(group counts, lambdas, prox rhos, indices)`
fn replay_pcs(claims: &[ZClaim], log_cols: usize, rows: usize, nn: usize, q: usize, o: &OpeningZk, tr: &mut Transcript) -> (Vec<usize>, Vec<Fp2>, Vec<Fp2>, Vec<usize>) {
    let counts: Vec<usize> = protocol::opening_groups_at(claims, log_cols).unwrap().iter().map(|(_, c)| *c).collect();
    let lambdas: Vec<Fp2> = counts.iter().flat_map(|c| tr.challenge_fp2_vec(*c)).collect();
    let prox = tr.challenge_fp2_vec(rows);
    for v in &o.group_vecs {
        tr.absorb_fp2(b"pcs-vec", v);
    }
    tr.absorb_fp2(b"pcs-prox", &o.prox_vec);
    let idx = tr.challenge_indices(q, nn);
    (counts, lambdas, prox, idx)
}

#[test]
fn lean_l9_export_the_w16r2_rung_block() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    let lay = Layout::for_shape(&sh).unwrap();
    let core = prove(&sh, &blk, copy(&w)).expect("the honest W16R2 rung core");
    verify(&sh, &blk, &core).expect("the honest W16R2 rung core verifies");
    let mut c = String::new();
    let _ = writeln!(c, "# D63 L9 agreement corpus (hashline src/private_block/lean_l9_export_tests.rs); one record per line");

    // ---- the frame, by the production encoder, and its two position tags
    let header0 = header(&sh, &lay);
    let binding = header0.state();
    let start_tag = pos_tag(&header0);
    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let end = {
        let mut f = header(&sh, &lay);
        let view = CoreView { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: &core.slots, mask_open: &core.mask_open, a_open: &core.a_open, h_open: &core.h_open };
        let mut ph = super::super::timing::Phases::start();
        protocol::verify_core(&sh, &lay, &blk, view, &ntt, &mut f, &mut ph).unwrap();
        f
    };
    let end_tag = pos_tag(&end);
    let ff = ForkFrame { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots.clone(), mask_open: core.mask_open.clone(), a_open: core.a_open.clone(), h_open: core.h_open.clone() };
    let frame = fw::encode_fork(&ff, &lay, &binding, 1, 0, &start_tag, &end_tag).unwrap();
    assert_eq!(frame.len(), fw::fork_len(&lay));
    verify_fork_bytes(&sh, &lay, &blk, &binding, &frame).expect("the framed honest core verifies");
    let _ = writeln!(c, "META {} {}", sh.profile, sh.name.replace(' ', "_"));
    let _ = writeln!(c, "FRAME {} {}", frame.len(), blake3::hash(&frame).to_hex());
    let _ = writeln!(c, "BINDING {}", hex(&binding));
    let key = sh.hash_tag().transcript_key().map(|k| hex(k)).unwrap_or_else(|| "-".into());
    let _ = writeln!(c, "START {} {key}", st(&header0));
    let _ = writeln!(c, "TAGS {} {}", hex(&start_tag), hex(&end_tag));
    let (pa, pe) = (protocol::pcs_params_at(&sh), protocol::endpoint_pcs_params(&sh));
    let _ = writeln!(
        c,
        "SHAPE log_cols {} inv_rate {} q {} enc_cols {} a_rows {} h_rows {} m_rows {} a_groups {} h_groups {} n_slots {} a_prox {} h_prox {} mask_specs {} endpoint {} {} {}",
        sh.log_cols, sh.inv_rate, sh.opened_cols, pa.enc_cols(), lay.a_rows, lay.h_rows, lay.m_rows(), sh.a_groups(), sh.h_groups(), lay.n_slots(), lay.a_prox, lay.h_prox, lay.mask_specs().len(), pe.log_cols, pe.inv_rate, sh.endpoint_rows
    );
    for s in 0..lay.n_slots() {
        let (n, e, d) = lay.slots()[s];
        // the name last: it has spaces, and the Lean reader takes the rest of the line
        let _ = writeln!(c, "SLOTSHAPE {s} {n} {e} {d} {} {:?} {}", lay.slot_terms(s), crate::private_block::layout::SLOT_KINDS[s], SLOT_NAMES[s]);
    }
    let _ = writeln!(c, "SITES a {} h {} hu {} {}", nums(&lay.a_site_rows()), nums(&lay.h_site_rows()), lay.h_u_rows()[0], lay.h_u_rows()[1]);

    // ---- the replay of `verify_core`, phase by phase, beside the production calls on the same transcript
    let mut t = header(&sh, &lay);
    protocol::absorb_root(&mut t, b"A", &core.a_root, lay.a_rows, sh.log_cols);
    t.absorb(b"M", &core.mask_root);
    let (beta, gamma, alpha) = (t.challenge_fp2(), t.challenge_fp2(), t.challenge_fp2());
    protocol::absorb_root(&mut t, b"H", &core.h_root, lay.h_rows, sh.log_cols);
    let _ = writeln!(c, "ROOTS {} {} {}", hex(&core.a_root), hex(&core.h_root), hex(&core.mask_root));
    let _ = writeln!(c, "LOGUP {} {} {} {}", f2(&beta), f2(&gamma), f2(&alpha), st(&t));
    let ctx = Ctx {
        accuracy: blk.accuracy(),
        lay: &lay,
        public: blk.attention(),
        ff: blk.feed_forward(),
        alpha,
        beta,
        g_u8: gamma.mul_base(Fp::new(TAG_U8)),
        g_exp: gamma.mul_base(Fp::new(TAG_EXP)),
        g_act: gamma.mul_base(Fp::new(TAG_ACT)),
        g_dd: gamma.mul_base(Fp::new(TAG_DD)),
    };
    // the production slot loop on `t`, slot by slot; the replay on a clone `r` of it
    let mut side = Side::Verify { slots: &core.slots };
    let mut acc = Acc::default();
    let mut pts = Points::default();
    let mut scalars: Vec<Fp2> = Vec::new();
    for s in 0..lay.n_slots() {
        let (n, e, d) = lay.slots()[s];
        let sp = &core.slots[s];
        let t0 = Transcript::clone_state(&t);
        let def = arg::define(s, &ctx, &mut pts, &mut t).unwrap();
        let draws = draws_between(&t0, &t);
        let hosted = def.hosted.clone();
        let mut r = Transcript::clone_state(&t);
        r.absorb_u64(b"pb-slot", s as u64);
        let cc = r.challenge_fp2();
        r.absorb_fp2(b"pb-scalar", &[sp.scalar]);
        let claimed = hosted.iter().fold(sp.scalar, |a, (hs, coef)| a.add(coef.mul(scalars[*hs])));
        let (fin, rho) = crate::sumcheck::verify(claimed, d, n + e, &sp.sc, &mut r).unwrap();
        r.absorb_fp2(b"pb-term", &sp.terms);
        arg::run_slot(&mut side, &mut acc, def, &mut t).unwrap();
        assert_eq!((r.state(), r.counter()), (t.state(), t.counter()), "slot {s}: the replay left the production transcript");
        let g_val = acc.fs.last().unwrap().value;
        let hs: Vec<String> = hosted.iter().map(|(h, k)| format!("{h}:{}", f2(k))).collect();
        let _ = writeln!(
            c,
            "SLOT {s} draws {} c {} scalar {} hosted {} claimed {} rho {} fin {} terms {} gval {} {}",
            f2s(&draws),
            f2(&cc),
            f2(&sp.scalar),
            if hs.is_empty() { "-".into() } else { hs.join(";") },
            f2(&claimed),
            f2s(&rho),
            f2(&fin),
            f2s(&sp.terms),
            f2(&g_val),
            st(&t)
        );
        let _ = (n, e);
        scalars.push(sp.scalar);
    }
    let hosts = std::mem::take(&mut acc.host_fs);
    acc.fs.extend(hosts);
    assert_eq!(acc.fs.len(), sh.n_functionals());
    let _ = writeln!(c, "FUNCTIONALS {}", acc.fs.len());

    // ---- M: `zk::mask_verify_tagged`
    let tag = sh.hash_tag();
    let specs = lay.mask_specs();
    let mut r = Transcript::clone_state(&t);
    let theta = r.challenge_fp2();
    r.absorb_fp2(b"mask-q", &core.mask_open.q);
    let rs = r.challenge_fp2_vec(2 * specs.len() + 2);
    r.absorb_fp2(b"mask-prox", &core.mask_open.prox);
    let midx = r.challenge_indices(crate::zk::MASK_Q, 1usize << crate::zk::MASK_LOG_DOM);
    crate::zk::mask_verify_tagged(&core.mask_root, &specs, &acc.fs, &core.mask_open, &ntt, &mut t, &tag).unwrap();
    assert_eq!((r.state(), r.counter()), (t.state(), t.counter()), "M: the replay left the production transcript");
    let mcols: Vec<usize> = core.mask_open.columns.iter().map(|(j, _, _, _)| *j).collect();
    assert_eq!(mcols, midx);
    let _ = writeln!(c, "MASK theta {} rs {} idx {} {}", f2(&theta), f2s(&rs), nums(&midx), st(&t));

    // ---- A and H: `check_opening` (a clone) and `pcs::verify_zk_tagged`
    let mut claims = acc.claims;
    claims[1].push(protocol::logup_sum_claim(&lay));
    let zko = ZkOpts::standard(&pa);
    for (name, ci, root, rows, sites, sum_rows, prox, groups, o) in [
        ("A", 0usize, core.a_root, lay.a_rows, lay.a_site_rows(), None, lay.a_prox, sh.a_groups(), &core.a_open),
        ("H", 1usize, core.h_root, lay.h_rows, lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, sh.h_groups(), &core.h_open),
    ] {
        protocol::check_opening(&claims[ci], sh.log_cols, rows, &sites, sum_rows, prox, groups, &t).unwrap();
        let mut r = Transcript::clone_state(&t);
        let (counts, lambdas, rhos, idx) = replay_pcs(&claims[ci], sh.log_cols, rows, pa.enc_cols(), pa.num_col_checks, o, &mut r);
        crate::pcs::verify_zk_tagged(&pa, &zko, &protocol::commitment(root, rows, sh.log_cols), &claims[ci], o, &ntt, &mut t, &tag).unwrap();
        assert_eq!((r.state(), r.counter()), (t.state(), t.counter()), "{name}: the replay left the production transcript");
        let cols: Vec<usize> = o.columns.iter().map(|(j, _, _, _)| *j).collect();
        assert_eq!(cols, idx);
        let _ = writeln!(c, "PCS {name} counts {} lambdas {} prox {} idx {} {}", nums(&counts), f2s(&lambdas), f2s(&rhos), nums(&idx), st(&t));
    }
    assert_eq!((t.state(), t.counter()), (end.state(), end.counter()), "the replay's end is not verify_core's");
    let _ = writeln!(c, "END {}", st(&t));

    // ---- the decoded fields, as digests of their canonical bytes (Lean re-encodes what it decoded)
    let mut slots_bytes = Vec::new();
    for sp in &core.slots {
        slots_bytes.extend_from_slice(&sp.scalar.to_bytes());
        sp.sc.write_bytes(&mut slots_bytes);
        for x in &sp.terms {
            slots_bytes.extend_from_slice(&x.to_bytes());
        }
    }
    let mut mb = Vec::new();
    core.mask_open.write_bytes(&mut mb);
    let (mut ab, mut hb) = (Vec::new(), Vec::new());
    core.a_open.write_bytes(&mut ab);
    core.h_open.write_bytes(&mut hb);
    let _ = writeln!(c, "FIELDS slots {} {} mask {} {} a {} {} h {} {}", slots_bytes.len(), blake3::hash(&slots_bytes).to_hex(), mb.len(), blake3::hash(&mb).to_hex(), ab.len(), blake3::hash(&ab).to_hex(), hb.len(), blake3::hash(&hb).to_hex());

    // ---- single changes to the frame, each with the production verdict
    let p_le = 0xFFFF_FFFF_0000_0001u64.to_le_bytes();
    let off_slots = 8 + 32 + 8 + 8 + 32 + 96;
    let slot_off = |s: usize| -> usize {
        let sl = lay.slots();
        off_slots + (0..s).map(|i| (1 + (sl[i].0 + sl[i].1) * (sl[i].2 + 1) + lay.slot_terms(i)) * 16).sum::<usize>()
    };
    let off_mask = slot_off(lay.n_slots());
    let mask_vec = 2usize << crate::zk::MASK_LOG_MSG;
    let off_mcol0 = off_mask + 2 * mask_vec * 16;
    let mut cases: Vec<(&str, Vec<u8>)> = Vec::new();
    cases.push(("honest", frame.clone()));
    cases.push(("short", frame[..frame.len() - 1].to_vec()));
    let mut b = frame.clone();
    b.push(0);
    cases.push(("long", b));
    let patch = |off: usize, bytes: &[u8]| -> Vec<u8> {
        let mut b = frame.clone();
        b[off..off + bytes.len()].copy_from_slice(bytes);
        b
    };
    let flip = |off: usize| -> Vec<u8> {
        let mut b = frame.clone();
        b[off] ^= 1;
        b
    };
    cases.push(("magic", flip(0)));
    cases.push(("binding", flip(8)));
    // magic 0..8, binding 8..40, L 40..48, k 48..56, the start tag 56..88, the roots 88..184
    cases.push(("fork-index", patch(48, &1u64.to_le_bytes())));
    cases.push(("start-tag", flip(64)));
    cases.push(("a-root", flip(96)));
    cases.push(("noncanonical-scalar", patch(off_slots, &p_le)));
    cases.push(("noncanonical-mask-column", patch(off_mcol0 + 8, &u64::MAX.to_le_bytes())));
    cases.push(("mask-column-index", patch(off_mcol0, &4096u64.to_le_bytes())));
    // slot 3's round 0, value 0, c0 plus one (canonical): s(0) + s(1) is no longer the claim
    let r0 = slot_off(3) + 16;
    let v = u64::from_le_bytes(frame[r0..r0 + 8].try_into().unwrap());
    cases.push(("round-sum", patch(r0, &Fp(v).add(Fp::ONE).0.to_le_bytes())));
    cases.push(("end-tag", flip(frame.len() - 1)));
    for (name, bytes) in &cases {
        let verdict = match verify_fork_bytes(&sh, &lay, &blk, &binding, bytes) {
            Ok(()) => "OK".to_string(),
            Err(e) => format!("ERR {e}"),
        };
        let diff: Vec<String> = if bytes.len() == frame.len() {
            (0..frame.len()).filter(|i| bytes[*i] != frame[*i]).map(|i| format!("{i}:{}", bytes[i])).collect()
        } else {
            vec![format!("len:{}", bytes.len())]
        };
        // the verdict last: an error message has spaces
        let _ = writeln!(c, "TAMPER {name} {} {verdict}", if diff.is_empty() { "-".into() } else { diff.join(",") });
        eprintln!("L9 tamper {name}: {verdict}");
    }
    eprintln!("L9: frame {} B, corpus {} B, {} slots", frame.len(), c.len(), lay.n_slots());
    if let Ok(dir) = std::env::var("L9_OUT") {
        let dir = std::path::Path::new(&dir);
        std::fs::write(dir.join("fork_frame.bin"), &frame).unwrap();
        std::fs::write(dir.join("corpus.txt"), &c).unwrap();
        eprintln!("L9: wrote {}", dir.display());
    }
}
