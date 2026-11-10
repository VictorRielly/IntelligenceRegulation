//! **D63 Lean lane L56 (2026-11-10): WHERE the classify run absorbs each block's two boundary roots, and WHICH opening
//! checks each of the block's boundary claims, on a REAL classifier receipt.** TEST ONLY: a child of the test-only
//! `private_block/token_io/classify_capture_tests.rs` (declared there by one `#[cfg(test)]` line; the file lives in
//! `src/`, not `src/private_block/`, as lanes L10's, L18's, L29's and L51's do, so `s25_tests`' `TEST_ONLY_FILES` needs
//! no entry). No prover or verifier source changes; nothing here is reachable from a production build.
//!
//! Lane L56's Lean schedule `blockSchedXB` hands block `k`'s slot polynomials the roots and log cuts the run's
//! transcript shows before the block's own roots; its boundary slots read the input boundary at run position
//! `off k + 2` and the output boundary at `off (k + 1) + 2` (the third absorb of part `k`'s and of part `k + 1`'s
//! frame). What this test does, on the development rung's classifier fixture (`classify_capture_tests::fx`, TWO
//! blocks, so that a block opens the previous block's boundary):
//! 1. proves an honest classifier run (`honest_run`) and verifies it with the production `verify_classify_run`;
//! 2. REPLAYS `verify_classify_run_with`'s loop (classify_run.rs:385-500, lane L18's replay) with the production pieces,
//!    recording for every block part its frame's absorbs IN ORDER (label, data, position in the part), the root its
//!    closing (boundary) opening is verified against, and the claims that opening checks: the previous part's outgoing
//!    claims (stage IN-C's, or the previous block's `SC_IO_OUT`) then the block's incoming claims (`SC_IO_IN`); every
//!    segment's end tag is ASSERTED equal to the replay's own position tag after the part (so the replay is the code's
//!    transcript), and every closing opening's root is ASSERTED to be the bytes the PREVIOUS part's frame absorbed at
//!    its position 2 (stage IN-C's: lane L29's replay of `stage_in_c::verify`, stage_in_c.rs:422-424, the root it
//!    returns is `seg.b_root`);
//! 3. NEGATIVE CONTROLS, each on a clone of the transcript at the block's start, each ASSERTED to be refused (an error,
//!    or a part ending off the segment's end tag): (N1) the frame with the boundary root at position 1 (before the block
//!    digest); (N2) the boundary opening against the block's OWN boundary root (absorbed at the part's position 2)
//!    instead of the previous part's; (N3) against the previous part's `A` root; (N4) the boundary opening without the
//!    block's incoming claims; (N5) the block's OUTGOING claims (`SC_IO_OUT`) checked by this part's opening in place
//!    of its incoming ones; (N6) stage OUT-C's closing opening against the last block's `A` root;
//! 4. writes the records to `LEAN_L56_CORPUS` for `results/zk60_lean_l56_20261110/l56_bnd_check.py`.
//!
//! Every value is public: the fixture's public synthetic data, the receipt's roots and tags, the transcript's states
//! (no witness value, no mask, no RNG state is written).
use super::super::super::boundary::{self, BoundarySpec};
use super::super::super::hash_domain;
use super::super::super::protocol::{self, CoreView};
use super::super::super::timing;
use super::super::super::wire;
use super::super::stage_in_c;
use super::super::stage_out_c;
use super::{fx, honest_run, POLICY_93};
use crate::ntt::NttTables;
use crate::pcs::{self, ZClaim, ZkOpts};
use crate::transcript::Transcript;
use std::fmt::Write as _;

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// `classify_run::position_tag` (classify_run.rs:37-44), replayed: two `challenge_fp2` of a clone.
fn tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

/// How a block's part is run: the code's way, or one of the negative controls.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Mode {
    Code,
    RootFirst,
    OwnRoot,
    PrevARoot,
    NoIncoming,
    OutHere,
}

/// What one block's part did: the frame's absorbs in order (label, data), the root its boundary opening was verified
/// against, the claim counts, the outgoing claims, its own boundary root and `A` root, and the end tag.
struct Part {
    frame: Vec<(Vec<u8>, Vec<u8>)>,
    opened: [u8; 32],
    pending_n: usize,
    in_n: usize,
    oc: Vec<ZClaim>,
    root: [u8; 32],
    a_root: [u8; 32],
    end_tag: [u8; 32],
}

/// **Block `k`'s part of `verify_classify_run_with`** (classify_run.rs:409-476) on the transcript `tr`, from the carry
/// `pending` and `prev` (the previous part's boundary spec and root) and the previous part's `A` root, in `mode`.
#[allow(clippy::too_many_arguments)]
fn block_part(
    st: &super::super::classify::ClassifyRunStatement,
    blk: &super::super::super::BlockPublic,
    k: usize,
    bytes: &[u8],
    binding: &[u8; 32],
    ntt: &NttTables,
    htag: &zkp_core::hashtag::HashTag,
    tr: &mut Transcript,
    pending: Vec<ZClaim>,
    prev: (&BoundarySpec, [u8; 32]),
    prev_a_root: [u8; 32],
    mode: Mode,
) -> Result<Part, String> {
    let sh = st.sh();
    let lay = st.block_layout(k)?;
    let start = tag(tr);
    let (seg, end) = wire::decode_segment(bytes, &lay, st.block_geom(k)?, binding, &start)?;
    hash_domain::segment_paths_are_the_tree_depth(&seg, sh)?;
    let spec = st.boundary_spec(k + 1)?;
    let root = seg.b_root.ok_or("a block segment carries its boundary root")?;
    let stage = ((k + 1) as u64).to_le_bytes().to_vec();
    let rows = (spec.commitment_rows() as u64).to_le_bytes().to_vec();
    let logn = (spec.log_n() as u64).to_le_bytes().to_vec();
    let mut frame: Vec<(Vec<u8>, Vec<u8>)> = vec![
        (b"pb-run-stage".to_vec(), stage),
        (b"pb-run-block".to_vec(), st.block_digests[k].to_vec()),
        (b"B".to_vec(), root.to_vec()),
        (b"rows".to_vec(), rows),
        (b"log-cols".to_vec(), logn),
    ];
    if mode == Mode::RootFirst {
        frame.swap(1, 2);
    }
    for (lab, data) in &frame {
        tr.absorb(lab, data);
    }
    let view = CoreView { a_root: seg.a_root, h_root: seg.h_root, mask_root: seg.mask_root, slots: &seg.slots, mask_open: &seg.mask_open, a_open: &seg.a_open, h_open: &seg.h_open };
    let ssh = st.stage_shape(k)?;
    let mut ph = timing::Phases::start();
    let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, blk, view, ntt, tr, &mut ph)?;
    let mut claims = pending;
    let (pending_n, in_n) = (claims.len(), ic.len());
    match mode {
        Mode::NoIncoming => {}
        Mode::OutHere => claims.extend(oc.iter().cloned()),
        _ => claims.extend(ic),
    }
    let (pspec, proot) = prev;
    let opened = match mode {
        Mode::OwnRoot => root,
        Mode::PrevARoot => prev_a_root,
        _ => proot,
    };
    boundary::check_opening(pspec, &claims, tr)?;
    let bp = pspec.params();
    pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(opened, pspec.commitment_rows(), pspec.log_n()), &claims, &seg.in_open, ntt, tr, htag)
        .map_err(|e| format!("the boundary opening: {e}"))?;
    let end_tag = tag(tr);
    if end_tag != end {
        return Err(format!("block {k}'s part ends off the segment's end tag"));
    }
    Ok(Part { frame, opened, pending_n, in_n, oc, root, a_root: seg.a_root, end_tag })
}

#[test]
fn lean_l56_export_the_boundary_positions() {
    let f = fx(2);
    let r = honest_run(&f, "1", None);
    let st = &r.st;
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    let segs = &r.segs;
    assert_eq!(l, 2, "two blocks, so that a block opens the previous block's boundary");
    assert_eq!(segs.len(), l + 2, "a classifier run has L + 2 segments");
    super::super::classify_run::verify_classify_run(st, &f.blocks, &r.bound, segs, POLICY_93)
        .expect("the production verifier accepts the honest classifier run");
    let tables = r.bound.tables();
    let htag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript().expect("the run header");
    let binding = tr.state();
    let mut out = String::new();
    writeln!(out, "L56 BOUNDARIES {} L={l} segments={}", st.profile(), segs.len()).unwrap();
    // ---- stage IN-C (part 0): its frame is lane L29's replay; the root it hands on is its segment's B_in root
    let in_lay = stage_in_c::layout(sh, cp);
    let start = tag(&tr);
    let (seg, end) = st.in_geom(&in_lay).decode(&segs[0], &binding, &start).expect("segment 0 decodes");
    let b0 = st.boundary_spec(0).unwrap();
    let in_b_root = seg.b_root.expect("stage IN-C's segment carries B_in's root");
    let in_a_root = seg.a_root;
    let (mut pending, b_root) =
        stage_in_c::verify(&in_lay, cp, tables, &seg, &b0, &st.in_spec, &st.in_root(), &ntt, &mut tr, &htag).expect("stage IN-C");
    assert_eq!(tag(&tr), end, "stage IN-C's end tag");
    assert_eq!(b_root, in_b_root, "stage IN-C hands on its segment's B_in root (the root its frame absorbs at position 2)");
    // the IN-C frame as stage_in_c.rs:422-424 absorbs it (lane L29 replayed it against the production verifier)
    let in_frame: Vec<(Vec<u8>, Vec<u8>)> = vec![
        (b"pb-run-stage".to_vec(), 0u64.to_le_bytes().to_vec()),
        (b"pb-run-block".to_vec(), cp.emb_digest.to_vec()),
        (b"B".to_vec(), in_b_root.to_vec()),
        (b"rows".to_vec(), (b0.commitment_rows() as u64).to_le_bytes().to_vec()),
        (b"log-cols".to_vec(), (b0.log_n() as u64).to_le_bytes().to_vec()),
    ];
    for (j, (lab, data)) in in_frame.iter().enumerate() {
        writeln!(out, "FRAME 0 {j} {} {}", hex(lab), hex(data)).unwrap();
    }
    writeln!(out, "AROOT 0 {}", hex(&in_a_root)).unwrap();
    writeln!(out, "CARRY 0 out={}", pending.len()).unwrap();
    let mut prev = (b0, b_root);
    let mut prev_a = in_a_root;
    let mut refused = 0usize;
    // ---- the blocks (part k + 1)
    for k in 0..l {
        let blk = &f.blocks[k];
        // the negative controls, each on a clone of the transcript at the block's start
        for mode in [Mode::RootFirst, Mode::OwnRoot, Mode::PrevARoot, Mode::NoIncoming, Mode::OutHere] {
            let mut c = Transcript::clone_state(&tr);
            let res = block_part(st, blk, k, &segs[k + 1], &binding, &ntt, &htag, &mut c, pending.clone(), (&prev.0, prev.1), prev_a, mode);
            assert!(res.is_err(), "negative control {mode:?} at block {k} must be refused");
            writeln!(out, "NEG {} {mode:?} refused: {}", k + 1, res.err().unwrap().replace('\n', " ")).unwrap();
            refused += 1;
        }
        // the code's way
        let p = block_part(st, blk, k, &segs[k + 1], &binding, &ntt, &htag, &mut tr, std::mem::take(&mut pending), (&prev.0, prev.1), prev_a, Mode::Code)
            .expect("the block's part, the code's way");
        assert_eq!(p.opened, prev.1, "block {k}'s boundary opening is verified against the previous part's root");
        for (j, (lab, data)) in p.frame.iter().enumerate() {
            writeln!(out, "FRAME {} {j} {} {}", k + 1, hex(lab), hex(data)).unwrap();
        }
        assert_eq!(p.frame[2].0, b"B".to_vec(), "the boundary root is the frame's third absorb");
        assert_eq!(p.frame[2].1, p.root.to_vec(), "and it is the block's own boundary root");
        writeln!(out, "AROOT {} {}", k + 1, hex(&p.a_root)).unwrap();
        writeln!(out, "OPEN {} root={} pending={} in={}", k + 1, hex(&p.opened), p.pending_n, p.in_n).unwrap();
        writeln!(out, "CARRY {} out={}", k + 1, p.oc.len()).unwrap();
        writeln!(out, "END {} {}", k + 1, hex(&p.end_tag)).unwrap();
        pending = p.oc;
        prev = (st.boundary_spec(k + 1).unwrap(), p.root);
        prev_a = p.a_root;
    }
    // ---- stage OUT-C (part L + 1): its closing opening is the last block's boundary, against the root the last
    // block's frame absorbed at its position 2
    let out_lay = stage_out_c::layout(sh, cp);
    let start = tag(&tr);
    let (seg, end) = st.out_geom(&out_lay).unwrap().decode(&segs[l + 1], &binding, &start).expect("segment L + 1 decodes");
    let (bspec, broot) = prev;
    let pn = pending.len();
    // (N6) stage OUT-C against the last block's A root: refused
    {
        let mut c = Transcript::clone_state(&tr);
        let res = stage_out_c::verify(&out_lay, cp, tables, st.verdict(), &seg, &bspec, &prev_a, pending.clone(), (l + 1) as u64, &ntt, &mut c, &htag);
        assert!(res.is_err(), "negative control: stage OUT-C against the last block's A root must be refused");
        writeln!(out, "NEG {} PrevARoot refused: {}", l + 1, res.err().unwrap().replace('\n', " ")).unwrap();
        refused += 1;
    }
    stage_out_c::verify(&out_lay, cp, tables, st.verdict(), &seg, &bspec, &broot, pending, (l + 1) as u64, &ntt, &mut tr, &htag).expect("stage OUT-C");
    assert_eq!(tag(&tr), end, "stage OUT-C's end tag");
    writeln!(out, "OPEN {} root={} pending={pn} in=0", l + 1, hex(&broot)).unwrap();
    writeln!(out, "REFUSED {refused}").unwrap();
    writeln!(out, "DONE {}", segs.len()).unwrap();
    eprintln!("LEAN-L56 | the boundary roots' positions and openings (rung, L = {l}, verdict {}): {refused} negative controls refused, corpus {} B", st.verdict(), out.len());
    if let Ok(path) = std::env::var("LEAN_L56_CORPUS") {
        std::fs::write(&path, &out).unwrap_or_else(|e| panic!("writing {path}: {e}"));
        eprintln!("LEAN-L56 | wrote {path}");
    }
}
