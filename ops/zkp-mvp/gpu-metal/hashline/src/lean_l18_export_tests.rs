//! **D63 Lean lane L18 (2026-11-07): the classify run's FRAMING on a REAL classifier receipt.** TEST ONLY: a child of
//! the test-only `private_block/token_io/classify_capture_tests.rs` (declared there by one `#[cfg(test)]` line; the
//! file lives in `src/`, not `src/private_block/`, as lane L10's does, so `s25_tests`' `TEST_ONLY_FILES` needs no
//! entry). No prover or verifier source changes; nothing here is reachable from a production build.
//!
//! What it does, on the development rung's classifier fixture (`classify_capture_tests::fx`, TWO blocks, so that a
//! block opens the previous block's boundary):
//! 1. proves an honest classifier run (`honest_run`) and verifies it with the production `verify_classify_run`;
//! 2. REPLAYS `verify_classify_run_with`'s loop (classify_run.rs:277-396) with the same production pieces, in the same
//!    order, on its own transcript, and records at every segment boundary the transcript (state, squeeze counter),
//!    the start tag it computes and the end tag the segment carries; for every block the framing absorbs' inputs (the
//!    stage index, the block digest, the boundary root, its rows and log size) and the transcript right after them;
//!    and the claim counts carried from one segment to the next. Every segment's decoder compares the start tag the
//!    replay hands it with the one the prover framed, and every end tag the segment carries is ASSERTED equal to the
//!    replay's own position tag after the part (as the production verifier checks both), so the replay is on the
//!    code's transcript at every segment boundary;
//! 3. writes the records to the file named by `LEAN_L18_CORPUS`, for `formal/ZK60Formal/ProtocolClassifyCheck.lean`,
//!    which recomputes every position tag (`posTag`, BLAKE3 in Lean) and every block's framing (`blockFrame`) from the
//!    recorded transcripts, and checks the run's shape (`L + 2` segments: IN-C, the blocks, OUT-C), the continuity of
//!    the transcript between segments and the carry of the pending claims.
//!
//! Every value is public: the fixture's public synthetic data, the receipt's tags and roots, the transcript's states
//! (no witness value, no mask, no RNG state is written).
use super::super::super::boundary;
use super::super::super::hash_domain;
use super::super::super::protocol::{self, CoreView};
use super::super::super::timing;
use super::super::super::wire;
use super::super::stage_in_c;
use super::super::stage_out_c;
use super::{fx, honest_run, POLICY_93};
use crate::ntt::NttTables;
use crate::pcs::{self, ZkOpts};
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

fn trs(tr: &Transcript) -> String {
    format!("{} {}", hex(&tr.state()), tr.counter())
}

#[test]
fn lean_l18_export_the_classify_run_framing() {
    let f = fx(2);
    let r = honest_run(&f, "1", None);
    let st = &r.st;
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    let segs = &r.segs;
    assert_eq!(segs.len(), l + 2, "a classifier run has L + 2 segments");
    super::super::classify_run::verify_classify_run(st, &f.blocks, &r.bound, segs, POLICY_93)
        .expect("the production verifier accepts the honest classifier run");
    // the replay of verify_classify_run_with's loop, with the production pieces in the production order
    let tables = r.bound.tables();
    let htag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript().expect("the run header");
    let binding = tr.state();
    let mut out = String::new();
    writeln!(out, "L18 FRAMING {} L={l} segments={}", st.profile(), segs.len()).unwrap();
    writeln!(out, "KEY {}", tr.fs_key().map(|k| hex(&k)).unwrap_or_else(|| "-".into())).unwrap();
    writeln!(out, "HEADER {}", trs(&tr)).unwrap();
    writeln!(out, "BINDING {}", hex(&binding)).unwrap();
    // ---- stage IN-C
    let in_lay = stage_in_c::layout(sh, cp);
    let t0 = trs(&tr);
    let start = tag(&tr);
    let (seg, end) = st.in_geom(&in_lay).decode(&segs[0], &binding, &start).expect("segment 0 decodes");
    let b0 = st.boundary_spec(0).unwrap();
    let (mut pending, b_root) =
        stage_in_c::verify(&in_lay, cp, tables, &seg, &b0, &st.in_spec, &st.in_root(), &ntt, &mut tr, &htag).expect("stage IN-C");
    assert_eq!(tag(&tr), end, "stage IN-C's end tag");
    writeln!(out, "SEG 0 IN-C {} {} {} {} {}", segs[0].len(), t0, hex(&start), hex(&end), trs(&tr)).unwrap();
    writeln!(out, "CARRY 0 out={} root={}", pending.len(), hex(&b_root)).unwrap();
    let mut prev = (b0, b_root);
    // ---- the blocks
    for k in 0..l {
        let blk = &f.blocks[k];
        let lay = st.block_layout(k).unwrap();
        let ts = trs(&tr);
        let start = tag(&tr);
        let (seg, end) = wire::decode_segment(&segs[k + 1], &lay, st.block_geom(k).unwrap(), &binding, &start).expect("a block segment decodes");
        hash_domain::segment_paths_are_the_tree_depth(&seg, sh).expect("the paths' depth");
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1).unwrap();
        let root = seg.b_root.expect("a block segment carries its boundary root");
        protocol::absorb_root(&mut tr, b"B", &root, spec.commitment_rows(), spec.log_n());
        writeln!(
            out,
            "FRAME {k} {} {} {} {} {}",
            hex(&st.block_digests[k]),
            hex(&root),
            spec.commitment_rows(),
            spec.log_n(),
            trs(&tr)
        )
        .unwrap();
        let view = CoreView { a_root: seg.a_root, h_root: seg.h_root, mask_root: seg.mask_root, slots: &seg.slots, mask_open: &seg.mask_open, a_open: &seg.a_open, h_open: &seg.h_open };
        let ssh = st.stage_shape(k).unwrap();
        let mut ph = timing::Phases::start();
        let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, blk, view, &ntt, &mut tr, &mut ph).expect("verify_core");
        let mut claims = std::mem::take(&mut pending);
        let (pn, inn) = (claims.len(), ic.len());
        claims.extend(ic);
        let (pspec, proot) = prev;
        boundary::check_opening(&pspec, &claims, &tr).expect("the boundary audit");
        let bp = pspec.params();
        pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(proot, pspec.commitment_rows(), pspec.log_n()), &claims, &seg.in_open, &ntt, &mut tr, &htag)
            .expect("the boundary opening");
        let on = oc.len();
        pending = oc;
        prev = (spec, root);
        assert_eq!(tag(&tr), end, "block {k}'s end tag");
        writeln!(out, "SEG {} BLOCK {} {} {} {} {}", k + 1, segs[k + 1].len(), ts, hex(&start), hex(&end), trs(&tr)).unwrap();
        writeln!(out, "CARRY {} pending={pn} in={inn} out={on} opened={} root={}", k + 1, hex(&proot), hex(&root)).unwrap();
    }
    // ---- stage OUT-C
    let out_lay = stage_out_c::layout(sh, cp);
    let ts = trs(&tr);
    let start = tag(&tr);
    let (seg, end) = st.out_geom(&out_lay).unwrap().decode(&segs[l + 1], &binding, &start).expect("segment L + 1 decodes");
    let (bspec, broot) = prev;
    let pn = pending.len();
    stage_out_c::verify(&out_lay, cp, tables, st.verdict(), &seg, &bspec, &broot, pending, (l + 1) as u64, &ntt, &mut tr, &htag).expect("stage OUT-C");
    assert_eq!(tag(&tr), end, "stage OUT-C's end tag");
    writeln!(out, "SEG {} OUT-C {} {} {} {} {}", l + 1, segs[l + 1].len(), ts, hex(&start), hex(&end), trs(&tr)).unwrap();
    writeln!(out, "CARRY {} pending={pn} opened={}", l + 1, hex(&broot)).unwrap();
    writeln!(out, "END {}", segs.len()).unwrap();
    eprintln!("LEAN-L18 | the classify run's framing (rung, L = {l}, verdict {}): {} segments, corpus {} B", st.verdict(), segs.len(), out.len());
    if let Ok(path) = std::env::var("LEAN_L18_CORPUS") {
        std::fs::write(&path, &out).unwrap_or_else(|e| panic!("writing {path}: {e}"));
        eprintln!("LEAN-L18 | wrote {path}");
    }
}
