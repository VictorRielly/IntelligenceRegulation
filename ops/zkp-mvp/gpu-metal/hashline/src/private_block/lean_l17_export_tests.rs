//! **D63 Lean lane L17 (2026-11-07): the agreement corpora of the R13 block verifier, from REAL R13 block receipts.**
//!
//! TEST ONLY: a child of the test-only `w16r2_tests` (declared there under `cfg(test)`, so that it uses that file's
//! seeded block harness: `rung_case`, `prove`, `verify`, `header`, `copy`), listed in `s25_tests`'s `TEST_ONLY_FILES`.
//! No prover or verifier source changes; nothing here is reachable from a production build. Every value written is
//! public: the fixtures' public synthetic data, the receipts and the transcripts' challenges (no witness value, no mask
//! coefficient, no RNG state).
//!
//! The R13 development rung `shape::R13_RUNG_H24` (`hashline-zk-mr1/private-block-rung-lh-t32-dev/2`, LOW + h24, the
//! byte-limb arithmetic, rate 1/4, `Q = 256`), proved by the production `protocol::prove_core` with `w16r2_tests`'
//! seeded recipe, is exported in the THREE formats of the W16R2 lanes, so that their Lean checkers' R13 adapters read
//! it (`formal/ZK60Formal/CheckR13Block.lean`, `CheckR13Slots.lean`, `CheckR13Open.lean`):
//! * `lean_l17_export_r13_block`: L9's format (`lean_l9_export_tests.rs`): the core framed by the production
//!   `wire::fork::encode_fork` (`HLPFORK1`, the frame an R13 D55 fork run carries) and every challenge `verify_core`
//!   draws, phase by phase, each replay asserted to end in the production transcript; thirteen single changes with the
//!   production verdict. Writes `$L17_OUT/block_corpus.txt` and `$L17_OUT/fork_frame.bin`.
//! * `lean_l17_export_r13_slots`: L11's format (`lean_l11_export_tests.rs`): per slot its draws, the verify arm
//!   recomputed on a clone, the tables and the slot IR. Writes `$L17_OUT/slots_corpus.txt`.
//! * `lean_l17_export_r13_openings`: L10's format (`lean_l10_export_tests.rs`): `M`, `A`, `H` and `check_opening`,
//!   honest and tampered, at R13's PCS parameters. Writes `$L17_OUT/open_corpus.txt` (large: outside the repository).
//!
//! And two R13-specific records:
//! * `lean_l17_export_r13_segment`: a REAL D12a segment (`HLPRUNS1`, the frame the R13 classifier run carries): a
//!   one-stage R13 run on the public loader fixture `r13-h24-wide` (`accuracy_proof_tests::prove_case`'s recipe;
//!   `HL_R13_LOADER_FIXTURES` names the fixtures in a checkout), proved by the production `run::prove_run` and accepted
//!   by `run::verify_run`; the segment's geometry, its decoded fields' digests and single changes with the production
//!   `wire::decode_segment` verdict. Writes `$L17_OUT/segment.bin` and `$L17_OUT/segment_corpus.txt`.
//! * `lean_l17_export_r13_shapes`: the registered Shieldstral T128 R13 shape's facts (`R13_SHIELD_T128_H24`) beside
//!   its W16R2 twin: the slot schedule, the domain facts, the plane counts, the rows and groups. Writes
//!   `$L17_OUT/shape_corpus.txt`.
//!
//! Without `L17_OUT` nothing is written; every assertion still runs.
use super::*;
use crate::private_block::argument::{self as arg, Acc, Ctx, Points, Side, Tab};
use crate::private_block::layout::{SLOT_NAMES, TAG_DD};
use crate::private_block::slot_ir::{build_slot_ir, Factor, IrPoints, NodeBody, SlotIr};
use crate::private_block::wire::fork::{self as fw, ForkFrame};
use crate::mle::{eq_point, eval_mle_ext};
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use crate::zk::{self, MaskOpening};
use std::fmt::Write as _;

// ---------------------------------------------------------------- formatting (the W16R2 lanes' own)

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

fn out_dir() -> Option<std::path::PathBuf> {
    std::env::var_os("L17_OUT").map(std::path::PathBuf::from)
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

/// the challenges between two transcripts that differ by squeezes only
fn draws_between(from: &Transcript, to: &Transcript) -> Vec<Fp2> {
    let mut probe = Transcript::clone_state(from);
    let mut out = Vec::new();
    while probe.state() != to.state() || probe.counter() != to.counter() {
        out.push(probe.challenge_fp2());
        assert!(out.len() < 4096, "define changed the transcript by something other than squeezes");
    }
    out
}

/// the R13 development rung (LOW + h24, the byte limbs, rate 1/4, `Q = 256`), its public synthetic block and witness
fn r13_rung() -> (Shape, BlockPublic, Witness) {
    let (sh, blk, w) = rung_case(shape::R13_RUNG_H24);
    assert!(!sh.range16(), "the R13 rung is not a W16 shape");
    assert_eq!((sh.inv_rate, sh.opened_cols, sh.log_cols), (4, 256, 14), "the R13 rung's PCS geometry");
    (sh, blk, w)
}

// ---------------------------------------------------------------- 1. L9's format: the fork frame and the transcript

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

/// the transcript challenges of one hiding opening (`zk_rhos`, the absorbs, the indices), replayed on `tr`
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
fn lean_l17_export_r13_block() {
    let (sh, blk, w) = r13_rung();
    let lay = Layout::for_shape(&sh).unwrap();
    let core = prove(&sh, &blk, copy(&w)).expect("the honest R13 rung core");
    verify(&sh, &blk, &core).expect("the honest R13 rung core verifies");
    let mut c = String::new();
    let _ = writeln!(c, "# D63 L17 R13 block corpus, L9's format (hashline src/private_block/lean_l17_export_tests.rs)");
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
        let _ = writeln!(c, "SLOTSHAPE {s} {n} {e} {d} {} {:?} {}", lay.slot_terms(s), crate::private_block::layout::SLOT_KINDS[s], SLOT_NAMES[s]);
    }
    let _ = writeln!(c, "SITES a {} h {} hu {} {}", nums(&lay.a_site_rows()), nums(&lay.h_site_rows()), lay.h_u_rows()[0], lay.h_u_rows()[1]);
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
        scalars.push(sp.scalar);
    }
    let hosts = std::mem::take(&mut acc.host_fs);
    acc.fs.extend(hosts);
    assert_eq!(acc.fs.len(), sh.n_functionals());
    let _ = writeln!(c, "FUNCTIONALS {}", acc.fs.len());
    let tag = sh.hash_tag();
    let specs = lay.mask_specs();
    let mut r = Transcript::clone_state(&t);
    let theta = r.challenge_fp2();
    r.absorb_fp2(b"mask-q", &core.mask_open.q);
    let rs = r.challenge_fp2_vec(2 * specs.len() + 2);
    r.absorb_fp2(b"mask-prox", &core.mask_open.prox);
    let midx = r.challenge_indices(zk::MASK_Q, 1usize << zk::MASK_LOG_DOM);
    zk::mask_verify_tagged(&core.mask_root, &specs, &acc.fs, &core.mask_open, &ntt, &mut t, &tag).unwrap();
    assert_eq!((r.state(), r.counter()), (t.state(), t.counter()), "M: the replay left the production transcript");
    let mcols: Vec<usize> = core.mask_open.columns.iter().map(|(j, _, _, _)| *j).collect();
    assert_eq!(mcols, midx);
    let _ = writeln!(c, "MASK theta {} rs {} idx {} {}", f2(&theta), f2s(&rs), nums(&midx), st(&t));
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
    let p_le = 0xFFFF_FFFF_0000_0001u64.to_le_bytes();
    let off_slots = 8 + 32 + 8 + 8 + 32 + 96;
    let slot_off = |s: usize| -> usize {
        let sl = lay.slots();
        off_slots + (0..s).map(|i| (1 + (sl[i].0 + sl[i].1) * (sl[i].2 + 1) + lay.slot_terms(i)) * 16).sum::<usize>()
    };
    let off_mask = slot_off(lay.n_slots());
    let mask_vec = 2usize << zk::MASK_LOG_MSG;
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
    cases.push(("fork-index", patch(48, &1u64.to_le_bytes())));
    cases.push(("start-tag", flip(64)));
    cases.push(("a-root", flip(96)));
    cases.push(("noncanonical-scalar", patch(off_slots, &p_le)));
    cases.push(("noncanonical-mask-column", patch(off_mcol0 + 8, &u64::MAX.to_le_bytes())));
    cases.push(("mask-column-index", patch(off_mcol0, &4096u64.to_le_bytes())));
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
        let _ = writeln!(c, "TAMPER {name} {} {verdict}", if diff.is_empty() { "-".into() } else { diff.join(",") });
        eprintln!("L17 block tamper {name}: {verdict}");
    }
    eprintln!("L17 block: frame {} B, corpus {} B, {} slots, A {} rows, H {} rows", frame.len(), c.len(), lay.n_slots(), lay.a_rows, lay.h_rows);
    if let Some(dir) = out_dir() {
        std::fs::write(dir.join("fork_frame.bin"), &frame).unwrap();
        std::fs::write(dir.join("block_corpus.txt"), &c).unwrap();
    }
}

// ---------------------------------------------------------------- 2. L11's format: the slot arithmetic

fn f2v(x: Fp2) -> String {
    format!("{},{}", x.c0.0, x.c1.0)
}

fn f2vs(v: &[Fp2]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| f2v(*x)).collect::<Vec<_>>().join(",")
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

fn coef(c: &crate::private_block::slot_ir::Coef) -> String {
    format!("{}:{}:{}", c.value.c0.0, c.value.c1.0, c.prov.label().replace(' ', "_"))
}

fn ir_lines(out: &mut String, ir: &SlotIr) {
    writeln!(out, "IR {} {} {}", ir.tables.len(), ir.nodes.len(), ir.terms.len()).unwrap();
    for t in &ir.tables {
        use crate::private_block::slot_ir::TableKind;
        let kind = match t.kind {
            TableKind::Eq { start, point_len } => format!("eq:{start}:{point_len}"),
            TableKind::GroupEq { bits } => format!("geq:{bits}"),
            TableKind::Public => "pub".to_string(),
            TableKind::Support { dom } => format!("supp:{dom:?}"),
            TableKind::PlaneA => "A".to_string(),
            TableKind::HelperH => "H".to_string(),
            TableKind::Endpoint => "EP".to_string(),
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
        writeln!(out, "TERM {} {} {}", coef(&t.coef), nums(&w), factors(&t.inner)).unwrap();
    }
}

/// the largest public table whose values the corpus carries (L11's bound)
const PUB_EXPORT_MAX: usize = 1 << 10;

/// L11's `SHAPE` line (the facts the Lean slot schedule is computed from)
fn shape_line(sh: &Shape) -> String {
    let ids = Ids::new(sh).unwrap();
    let lg = |v: usize| v.trailing_zeros() as usize;
    let doms = [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab];
    let logs: Vec<usize> = doms.iter().map(|d| sh.log(*d)).collect();
    let pads: Vec<usize> = doms.iter().map(|d| usize::from(sh.pads(*d))).collect();
    let helpers: Vec<usize> = doms.iter().map(|d| sh.helpers(*d)).collect();
    let zero_rule: Vec<usize> = doms.iter().map(|d| usize::from(!super::super::pad::zero_rule_a_planes(sh, &ids, *d).is_empty())).collect();
    let n_range = super::super::range16::sub_planes(&sh.range_families()).len();
    format!(
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
        nums(&logs),
        nums(&pads),
        nums(&helpers),
        nums(&zero_rule)
    )
}

#[test]
fn lean_l17_export_r13_slots() {
    let (sh, blk, w) = r13_rung();
    let core = prove(&sh, &blk, copy(&w)).expect("the honest R13 rung core");
    verify(&sh, &blk, &core).expect("the honest R13 rung core verifies (production verify_core)");
    let lay = Layout::for_shape(&sh).unwrap();
    let mut out = String::new();
    let key = header(&sh, &lay).fs_key();
    writeln!(out, "L11 {} {} {}", sh.name.replace(' ', "_"), key.map(|k| hex(&k)).unwrap_or_else(|| "-".into()), sh.n_slots()).unwrap();
    writeln!(out, "{}", shape_line(&sh)).unwrap();
    let slots_decl: Vec<String> = (0..sh.n_slots()).map(|s| format!("{}:{}:{}", sh.slots()[s].0, sh.slots()[s].1, sh.slots()[s].2)).collect();
    writeln!(out, "SCHED {}", slots_decl.join(",")).unwrap();
    writeln!(out, "TERMSDECL {}", nums(&sh.slot_terms()[..sh.n_slots()])).unwrap();
    let mut tr = header(&sh, &lay);
    writeln!(out, "HEAD {} {}", hex(&tr.state()), tr.counter()).unwrap();
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
    writeln!(out, "ROOTS {} {} {} {} {} {}", hex(&core.a_root), lay.a_rows, hex(&core.mask_root), hex(&core.h_root), lay.h_rows, sh.log_cols).unwrap();
    writeln!(out, "LOGUP {} {} {}", f2v(beta), f2v(gamma), f2v(alpha)).unwrap();
    writeln!(out, "TAGS {} {} {}", f2v(g_u8), f2v(g_exp), f2v(g_act)).unwrap();
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
        let def = arg::define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
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
        writeln!(out, "DRAWS {}", f2vs(&draws)).unwrap();
        writeln!(out, "TRB {} {}", hex(&tr.state()), tr.counter()).unwrap();
        let sp = &core.slots[s];
        writeln!(out, "SCALAR {}", f2v(sp.scalar)).unwrap();
        let hosted: Vec<String> = def.hosted.iter().map(|(hs, c)| format!("{hs}:{}:{}", c.c0.0, c.c1.0)).collect();
        writeln!(out, "HOSTED {}", if hosted.is_empty() { "-".to_string() } else { hosted.join(";") }).unwrap();
        for (j, r) in sp.sc.rounds.iter().enumerate() {
            writeln!(out, "ROUND {j} {}", f2vs(r)).unwrap();
        }
        writeln!(out, "TERMS {}", f2vs(&sp.terms)).unwrap();
        let mut t2 = Transcript::clone_state(&tr);
        t2.absorb_u64(b"pb-slot", s as u64);
        let c = t2.challenge_fp2();
        assert!(!c.is_zero());
        t2.absorb_fp2(b"pb-scalar", &[sp.scalar]);
        let claimed = def.hosted.iter().fold(sp.scalar, |a, (hs, coef)| a.add(coef.mul(scalars[*hs])));
        let (fin, rho_full) = crate::sumcheck::verify(claimed, degree, n + ext, &sp.sc, &mut t2).expect("an honest slot verifies");
        let rho = rho_full[..n].to_vec();
        let es = rho_full[n..].to_vec();
        let sel = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
        let mut k = 0usize;
        let mut vals = Vec::with_capacity(def.tabs.len());
        for (i, t) in def.tabs.iter().enumerate() {
            match t {
                Tab::Eq { point, start } => {
                    writeln!(out, "TAB {i} eq {start} {}", f2vs(point)).unwrap();
                    vals.push(sel.mul(eq_point(point, &rho[*start..*start + point.len()])));
                }
                Tab::Pub(v) => {
                    let m = eval_mle_ext(v, &rho);
                    if v.len() <= PUB_EXPORT_MAX {
                        writeln!(out, "TAB {i} pub {} {}", v.len(), f2vs(v)).unwrap();
                        n_pub_full += 1;
                    } else {
                        writeln!(out, "TAB {i} pubv {} {}", v.len(), f2v(m)).unwrap();
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
        writeln!(out, "VALS {}", f2vs(&vals)).unwrap();
        match &ir {
            Ok(ir) => {
                assert_eq!(ir.tables.len(), def.tabs.len(), "slot {s}: the IR's table count");
                assert_eq!(ir.eval(&vals), pv, "slot {s}: the IR differs from the closure at the real terminal values");
                ir_lines(&mut out, ir);
                n_ir += 1;
            }
            Err(e) => writeln!(out, "IRNONE {}", e.replace(' ', "_")).unwrap(),
        }
        writeln!(out, "RES {} {} {} {} {} {}", f2v(c), f2v(claimed), f2v(fin), f2vs(&rho_full), f2v(pv), f2v(g_val)).unwrap();
        writeln!(out, "TRA {} {}", hex(&t2.state()), t2.counter()).unwrap();
        arg::run_slot(&mut side, &mut acc, def, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        assert_eq!(tr.state(), t2.state(), "slot {s}: the recomputed verify arm left another transcript");
        assert_eq!(tr.counter(), t2.counter());
        assert_eq!(acc.scalars.last().copied(), Some(sp.scalar));
        assert_eq!(acc.fs.last().map(|f| f.value), Some(g_val), "slot {s}: the mask functional's value is g");
        scalars.push(sp.scalar);
        writeln!(out, "END {s}").unwrap();
    }
    writeln!(out, "DONE {n_ir} {n_pub_full} {n_pub_value}").unwrap();
    eprintln!("L17 slots corpus: {} slots, {n_ir} slot IRs, {n_pub_full} public tables with values, {n_pub_value} by value only, {} bytes", sh.n_slots(), out.len());
    if let Some(dir) = out_dir() {
        std::fs::write(dir.join("slots_corpus.txt"), out.as_bytes()).unwrap();
    }
}

// ---------------------------------------------------------------- 3. L10's format: M, A, H and check_opening

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

#[allow(clippy::too_many_arguments)]
fn check_record(o: &mut Out, name: &str, log_n: usize, rows: usize, site_rows: &[usize], sum_rows: Option<[usize; 2]>, prox: usize, groups: usize, claims: &[ZClaim], tr: &Transcript) {
    let v = protocol::check_opening(claims, log_n, rows, site_rows, sum_rows, prox, groups, tr);
    let sites = site_rows.iter().map(|r| r.to_string()).collect::<Vec<_>>().join(",");
    let sums = match sum_rows {
        Some([a, b]) => format!("{a},{b}"),
        None => "-".to_string(),
    };
    o.line(format!("L10CHK {name} {log_n} {rows} {} {sums} {prox} {groups} {}", if sites.is_empty() { "-".into() } else { sites }, v.is_ok() as u8));
    if let Err(e) = &v {
        o.line(format!("L10ERR {e}"));
    }
    o.line(format!("L10TR {}", tr_line(tr)));
    for c in claims {
        o.line(format!("L10CLAIM {}:{} {}", c.value.c0.0, c.value.c1.0, c.parts.len()));
        for p in &c.parts {
            o.line(format!("L10PART {} {} {}:{} {}", p.slice.offset, p.slice.log_size, p.coef.c0.0, p.coef.c1.0, fp2_csv(&p.point)));
        }
    }
    o.line("L10END -".to_string());
    o.records += 1;
}

#[test]
fn lean_l17_export_r13_openings() {
    let (sh, blk, w) = r13_rung();
    let lay = Layout::for_shape(&sh).unwrap();
    let core = prove(&sh, &blk, copy(&w)).expect("the seeded R13 rung core proof");
    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let mut tr = header(&sh, &lay);
    let (public, ff) = (blk.attention(), blk.feed_forward());
    let params = protocol::pcs_params_at(&sh);
    assert_eq!((params.log_cols, params.inv_rate, params.num_col_checks), (14, 4, 256), "R13's regular PCS parameters");
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
    let mut ph = super::super::timing::Phases::start();
    let acc = arg::argument(&mut side, &ctx, &mut tr, &mut ph).expect("the slots verify");
    let specs = lay.mask_specs();
    let before_m = Transcript::clone_state(&tr);
    zk::mask_verify_tagged(&core.mask_root, &specs, &acc.fs, &core.mask_open, &ntt, &mut tr, &tag).expect("M verifies");
    let [ac, mut hc, _, _] = acc.claims;
    hc.push(protocol::logup_sum_claim(&lay));
    let before_a = Transcript::clone_state(&tr);
    zpcs::verify_zk_tagged(&params, &zko, &protocol::commitment(core.a_root, lay.a_rows, sh.log_cols), &ac, &core.a_open, &ntt, &mut tr, &tag).expect("A verifies");
    let before_h = Transcript::clone_state(&tr);
    zpcs::verify_zk_tagged(&params, &zko, &protocol::commitment(core.h_root, lay.h_rows, sh.log_cols), &hc, &core.h_open, &ntt, &mut tr, &tag).expect("H verifies");
    {
        let mut vt = header(&sh, &lay);
        let view = CoreView { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: &core.slots, mask_open: &core.mask_open, a_open: &core.a_open, h_open: &core.h_open };
        let mut vph = super::super::timing::Phases::start();
        protocol::verify_core(&sh, &lay, &blk, view, &ntt, &mut vt, &mut vph).expect("the honest core verifies");
        assert_eq!((vt.state(), vt.counter()), (tr.state(), tr.counter()), "the step-by-step replay left the body's transcript");
    }
    let mut o = Out { s: String::new(), records: 0 };
    o.line(format!("# D63 lane L17 corpus, L10's format: the R13 rung block core ({}), M / A / H openings, honest and tampered", sh.profile));
    let nt = NttTables::new(16);
    for k in [9u32, 12, 14, 16] {
        o.line(format!("L10ROOT {k} {}", nt.roots[k as usize].0));
    }
    o.line(format!("L10TAG {} {} {} {}", key(tag.column_key()), key(tag.leaf_key()), key(tag.node_key()), key(tag.transcript_key())));
    mask_record(&mut o, "m-honest", &core.mask_root, &specs, &acc.fs, &core.mask_open, &before_m, &tag);
    let bump = |x: Fp2| x.add(Fp2::ONE);
    let mut m1 = core.mask_open.clone();
    m1.q[0] = bump(m1.q[0]);
    mask_record(&mut o, "m-q0", &core.mask_root, &specs, &acc.fs, &m1, &before_m, &tag);
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
    pcs_record(&mut o, "a-honest", &params, &zko, core.a_root, lay.a_rows, &ac, &core.a_open, &before_a, &tag);
    pcs_record(&mut o, "h-honest", &params, &zko, core.h_root, lay.h_rows, &hc, &core.h_open, &before_h, &tag);
    let n = params.cols();
    let mut a1 = core.a_open.clone();
    a1.group_vecs[0][0] = bump(a1.group_vecs[0][0]);
    pcs_record(&mut o, "a-vec0", &params, &zko, core.a_root, lay.a_rows, &ac, &a1, &before_a, &tag);
    let mut ac3 = ac.clone();
    ac3[0].value = bump(ac3[0].value);
    pcs_record(&mut o, "a-claim0", &params, &zko, core.a_root, lay.a_rows, &ac3, &core.a_open, &before_a, &tag);
    let mut h2 = core.h_open.clone();
    h2.group_vecs[0][n] = bump(h2.group_vecs[0][n]);
    pcs_record(&mut o, "h-pad0", &params, &zko, core.h_root, lay.h_rows, &hc, &h2, &before_h, &tag);
    let mut h4 = core.h_open.clone();
    h4.columns[0].1[0] = h4.columns[0].1[0].add(Fp::ONE);
    pcs_record(&mut o, "h-col0", &params, &zko, core.h_root, lay.h_rows, &hc, &h4, &before_h, &tag);
    let mut h5 = core.h_open.clone();
    h5.columns[1].0 ^= 1;
    pcs_record(&mut o, "h-index1", &params, &zko, core.h_root, lay.h_rows, &hc, &h5, &before_h, &tag);
    let mut h6 = core.h_open.clone();
    h6.columns.pop();
    pcs_record(&mut o, "h-ncols", &params, &zko, core.h_root, lay.h_rows, &hc, &h6, &before_h, &tag);
    let mut hc8 = hc.clone();
    hc8[0].parts[0].coef = bump(hc8[0].parts[0].coef);
    pcs_record(&mut o, "h-coef0", &params, &zko, core.h_root, lay.h_rows, &hc8, &core.h_open, &before_h, &tag);
    let (ls, la) = (sh.log_cols, lay.a_rows);
    check_record(&mut o, "chk-a", ls, la, &lay.a_site_rows(), None, lay.a_prox, sh.a_groups(), &ac, &before_a);
    check_record(&mut o, "chk-h", ls, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, sh.h_groups(), &hc, &before_h);
    check_record(&mut o, "chk-h-groups", ls, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, sh.h_groups() + 1, &hc, &before_h);
    check_record(&mut o, "chk-a-prox", ls, la, &lay.a_site_rows(), None, lay.a_prox + 1, sh.a_groups(), &ac, &before_a);
    o.line(format!("L10SHAPE {} {} {} {} {} {}", sh.profile, lay.a_rows, lay.h_rows, specs.len(), core.a_open.group_vecs.len(), core.h_open.group_vecs.len()));
    eprintln!(
        "LEAN-L17 openings: {} records, {} bytes; A {} rows {} groups, H {} rows {} groups, M {} masks, {} functionals",
        o.records, o.s.len(), lay.a_rows, core.a_open.group_vecs.len(), lay.h_rows, core.h_open.group_vecs.len(), specs.len(), acc.fs.len()
    );
    if let Some(dir) = out_dir() {
        std::fs::write(dir.join("open_corpus.txt"), &o.s).expect("write the corpus");
    }
}

// ---------------------------------------------------------------- 4. a real D12a segment (the classifier's frame)

struct OneStage(Option<Witness>);

impl crate::private_block::run::RunWitnessSource for OneStage {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        if k != 0 {
            return Err("one public synthetic stage".into());
        }
        self.0.take().ok_or_else(|| "witness consumed".to_string())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("no internal boundary".into())
    }
}

#[test]
fn lean_l17_export_r13_segment() {
    use crate::private_block::run;
    use crate::private_block::trained_block::TrainedExport;
    let base = std::env::var_os("HL_R13_LOADER_FIXTURES").map(std::path::PathBuf::from).unwrap_or_else(|| std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures"));
    let path = base.join("r13-h24-wide");
    let mut ex = TrainedExport::load(&path).expect("the public R13 loader fixture r13-h24-wide (HL_R13_LOADER_FIXTURES)");
    ex.accuracy_dd = false;
    let cst = ex.run_constants(&[0]).unwrap();
    let seed = ex.shape_for(&cst).unwrap();
    let layer = ex.load_layer(&seed, &cst, 0, false).unwrap();
    let sh = layer.record.shape_at(&seed).unwrap();
    assert!(!sh.range16(), "the fixture's stage is an R13 (byte-limb) shape");
    let (x, _) = ex.load_seq(&sh, "public", 0).unwrap();
    let wit = witness::build_for_block(&sh, &layer.blk, &x).unwrap();
    let ids = Ids::new(&sh).unwrap();
    let input: Vec<i16> = wit.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
    let output: Vec<i16> = wit.planes[ids.at(A_X2)].iter().map(|&v| v as i16).collect();
    let model = ex.statement(&seed, &cst, &[&layer]).unwrap();
    let blocks = vec![layer.blk];
    let context = [37u8; 32];
    let spec = IoSpec::new_shaped(&seed, context, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &input, &output).unwrap();
    let stmt = RunStatement::new_bound(RunShape::accuracy(seed.clone(), 1).unwrap(), context, expected, &blocks, &[(0, 0)], &model).unwrap();
    let mut segments: Vec<Vec<u8>> = Vec::new();
    let mut source = OneStage(Some(wit));
    run::prove_run(&stmt, &blocks, &mut source, owners, &mut |_, bytes| {
        segments.push(bytes);
        Ok(())
    })
    .unwrap();
    assert_eq!(segments.len(), 1);
    run::verify_run(&stmt, &blocks, &segments).expect("the production D12a run verifier accepts the segment");
    let seg_bytes = segments[0].clone();
    let ssh = stmt.stage_shape(0).unwrap();
    let lay = Layout::for_shape(&ssh).unwrap();
    let g = wire::SegGeom { l: 1, k: 0, boundary_rows: 0, sites: 0 };
    let binding: [u8; 32] = seg_bytes[8..40].try_into().unwrap();
    let start_tag: [u8; 32] = seg_bytes[56..88].try_into().unwrap();
    assert_eq!(binding, stmt.binding().unwrap(), "the segment carries the run binding");
    let (seg, end_tag) = wire::decode_segment(&seg_bytes, &lay, g, &binding, &start_tag).expect("the production decoder accepts the segment");
    assert!(seg.b_root.is_none() && seg.out_open.is_some());
    let mut c = String::new();
    let _ = writeln!(c, "# D63 L17 R13 D12a segment corpus (hashline src/private_block/lean_l17_export_tests.rs)");
    let _ = writeln!(c, "META {} {} {}", ssh.profile, stmt.rs().profile(), ssh.name.replace(' ', "_"));
    let _ = writeln!(c, "SEGMENT {} {}", seg_bytes.len(), blake3::hash(&seg_bytes).to_hex());
    let _ = writeln!(c, "BINDING {}", hex(&binding));
    let _ = writeln!(c, "TAGS {} {}", hex(&start_tag), hex(&end_tag));
    let _ = writeln!(
        c,
        "SEGSHAPE l 1 k 0 log_cols {} inv_rate {} q {} a_rows {} h_rows {} m_rows {} a_groups {} h_groups {} n_slots {} e_log_n {} e_inv_rate {} e_rows {} ceiling {}",
        ssh.log_cols, ssh.inv_rate, ssh.opened_cols, lay.a_rows, lay.h_rows, lay.m_rows(), ssh.a_groups(), ssh.h_groups(), lay.n_slots(), ssh.endpoint_log_n, ssh.endpoint_inv_rate, ssh.endpoint_rows, wire::wire_ceiling(&ssh)
    );
    for s in 0..lay.n_slots() {
        let (n, e, d) = lay.slots()[s];
        let _ = writeln!(c, "SLOTSHAPE {s} {n} {e} {d} {}", lay.slot_terms(s));
    }
    let mut slots_bytes = Vec::new();
    for sp in &seg.slots {
        slots_bytes.extend_from_slice(&sp.scalar.to_bytes());
        sp.sc.write_bytes(&mut slots_bytes);
        for x in &sp.terms {
            slots_bytes.extend_from_slice(&x.to_bytes());
        }
    }
    let mut mb = Vec::new();
    seg.mask_open.write_bytes(&mut mb);
    let (mut ab, mut hb, mut ib, mut ob) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    seg.a_open.write_bytes(&mut ab);
    seg.h_open.write_bytes(&mut hb);
    seg.in_open.write_bytes(&mut ib);
    seg.out_open.as_ref().unwrap().write_bytes(&mut ob);
    let _ = writeln!(c, "ROOTS {} {} {}", hex(&seg.a_root), hex(&seg.h_root), hex(&seg.mask_root));
    let d = |b: &[u8]| blake3::hash(b).to_hex().to_string();
    let _ = writeln!(c, "FIELDS slots {} {} mask {} {} a {} {} h {} {} in {} {} out {} {}", slots_bytes.len(), d(&slots_bytes), mb.len(), d(&mb), ab.len(), d(&ab), hb.len(), d(&hb), ib.len(), d(&ib), ob.len(), d(&ob));
    // offsets: the header (88), the three roots (96), the slots, M, A, H, then the input endpoint's opening
    let off_slots = 88 + 96;
    let off_in = off_slots + slots_bytes.len() + mb.len() + ab.len() + hb.len();
    let off_out = off_in + ib.len();
    let e_vec = (1usize << ssh.endpoint_log_n) + ssh.opened_cols;
    let off_in_col0 = off_in + 2 * e_vec * 16;
    let e_enc = (1usize << ssh.endpoint_log_n) * ssh.endpoint_inv_rate;
    let p_le = 0xFFFF_FFFF_0000_0001u64.to_le_bytes();
    let mut cases: Vec<(&str, Vec<u8>)> = Vec::new();
    cases.push(("honest", seg_bytes.clone()));
    cases.push(("short", seg_bytes[..seg_bytes.len() - 1].to_vec()));
    let mut b = seg_bytes.clone();
    b.push(0);
    cases.push(("long", b));
    let patch = |off: usize, bytes: &[u8]| -> Vec<u8> {
        let mut b = seg_bytes.clone();
        b[off..off + bytes.len()].copy_from_slice(bytes);
        b
    };
    let flip = |off: usize| -> Vec<u8> {
        let mut b = seg_bytes.clone();
        b[off] ^= 1;
        b
    };
    cases.push(("magic", flip(0)));
    cases.push(("binding", flip(8)));
    cases.push(("run-length", patch(40, &2u64.to_le_bytes())));
    cases.push(("segment-index", patch(48, &1u64.to_le_bytes())));
    cases.push(("start-tag", flip(64)));
    cases.push(("noncanonical-scalar", patch(off_slots, &p_le)));
    cases.push(("noncanonical-input-vector", patch(off_in, &p_le)));
    cases.push(("input-column-index", patch(off_in_col0, &(e_enc as u64).to_le_bytes())));
    cases.push(("noncanonical-output-vector", patch(off_out, &p_le)));
    cases.push(("a-root", flip(96)));
    cases.push(("end-tag", flip(seg_bytes.len() - 1)));
    for (name, bytes) in &cases {
        let verdict = match wire::decode_segment(bytes, &lay, g, &binding, &start_tag) {
            Ok((_, et)) => format!("OK {}", hex(&et)),
            Err(e) => format!("ERR {e}"),
        };
        let diff: Vec<String> = if bytes.len() == seg_bytes.len() {
            (0..seg_bytes.len()).filter(|i| bytes[*i] != seg_bytes[*i]).map(|i| format!("{i}:{}", bytes[i])).collect()
        } else {
            vec![format!("len:{}", bytes.len())]
        };
        let _ = writeln!(c, "TAMPER {name} {} {verdict}", if diff.is_empty() { "-".into() } else { diff.join(",") });
        eprintln!("L17 segment tamper {name}: {}", verdict.chars().take(120).collect::<String>());
    }
    eprintln!("L17 segment: {} B, {} slots, A {} rows {} groups, H {} rows, endpoint rows {}", seg_bytes.len(), lay.n_slots(), lay.a_rows, ssh.a_groups(), lay.h_rows, ssh.endpoint_rows);
    if let Some(dir) = out_dir() {
        std::fs::write(dir.join("segment.bin"), &seg_bytes).unwrap();
        std::fs::write(dir.join("segment_corpus.txt"), &c).unwrap();
    }
}

// ---------------------------------------------------------------- 5. the Shieldstral T128 R13 shape's facts

#[test]
fn lean_l17_export_r13_shapes() {
    let mut c = String::new();
    let _ = writeln!(c, "# D63 L17 shape facts: R13 Shieldstral T128 beside its W16R2 twin, and the two rungs");
    for profile in [shape::R13_SHIELD_T128_H24, shape::W16R2_SHIELD_T128_H24, shape::R13_RUNG_H24, shape::W16R2_RUNG_H24] {
        let sh = built(profile);
        let lay = Layout::for_shape(&sh).unwrap();
        let t = sh.totals();
        let _ = writeln!(c, "PROFILE {profile}");
        let _ = writeln!(c, "{}", shape_line(&sh));
        let slots_decl: Vec<String> = (0..sh.n_slots()).map(|s| format!("{}:{}:{}", sh.slots()[s].0, sh.slots()[s].1, sh.slots()[s].2)).collect();
        let _ = writeln!(c, "SCHED {}", slots_decl.join(","));
        let _ = writeln!(c, "TERMSDECL {}", nums(&sh.slot_terms()[..sh.n_slots()]));
        let _ = writeln!(
            c,
            "COUNTS a_planes {} h_planes {} a_rows {} h_rows {} m_rows {} a_groups {} h_groups {} functionals {} mask_specs {} inv_rate {} q {} log_cols {} e_log_n {} e_inv_rate {} e_rows {} range16 {} limbs_sigma_s {}",
            t.a_planes, t.h_planes, lay.a_rows, lay.h_rows, lay.m_rows(), sh.a_groups(), sh.h_groups(), sh.n_functionals(), lay.mask_specs().len(), sh.inv_rate, sh.opened_cols, sh.log_cols, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.endpoint_rows, usize::from(sh.range16()), sh.limbs_sigma_s()
        );
        let lks: Vec<String> = sh.lookup_doms().iter().map(|d| format!("{d:?}:{}", sh.lookups_per_position(*d))).collect();
        let _ = writeln!(c, "LOOKUPS {}", lks.join(","));
        eprintln!("L17 shape {profile}: A {} planes, H {} planes, a_rows {}, h_rows {}", t.a_planes, t.h_planes, lay.a_rows, lay.h_rows);
    }
    if let Some(dir) = out_dir() {
        std::fs::write(dir.join("shape_corpus.txt"), &c).unwrap();
    }
}
