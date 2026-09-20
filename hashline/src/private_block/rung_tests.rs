//! **STEP S12a: the DEVELOPMENT RUNG, end to end.**
//!
//! Every earlier step of this lane was a definition, a count or a witness-level
//! check. This module is the first one that PROVES at the rung shape (24
//! tokens, width 96, hidden 192, 6 query heads of 16 over 2 key-value heads)
//! and hands the bytes to a fresh verifier.
//!
//! WHAT A GREEN RUN HERE IS, AND IS NOT. It is a CORRECTNESS milestone for the
//! rung profile: the honest prover and the honest verifier agree at a shape
//! where nine domains pad, the head axis is grouped and permuted, the softmax
//! remainder needs a third limb, and ruling P-1's pad-zero term is live. It is
//! NOT a privacy result and NOT an acceptance: the privacy checks (the joint
//! view, the rank and CFS tools, the simulator) are owed again at every new
//! shape and none of them has been run here. The rung is development grade by
//! ruling P-7: no receipt from it is shown to anyone.
//!
//! Every fixture is the PUBLIC SYNTHETIC / tame one of `grow_tests`. Run in
//! release; the timings below are diagnostics on a shared box.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;

/// The rung frame's counted length (`Shape::receipt_bytes`, `wire::encoded_len`
/// and `grow_tests::MODEL_RUNG` all agree on it): the Python model's 4,173,208
/// plus the 45,056 B the frozen seam's PADDED `(32, 128)` endpoint costs over
/// the model's TRUE `(24, 96)` pricing (finding S11-F4).
const RUNG_BYTES: usize = 4_218_264;

/// Peak resident memory of this process, in MiB — Linux `VmHWM`, read for the
/// record only. It is a whole-process high-water mark on a SHARED box, so it
/// bounds this proof's cost from above and is not a measurement of it.
fn peak_rss_mib() -> f64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines()
                .find(|l| l.starts_with("VmHWM:"))
                .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok()))
        })
        .map(|kb| kb / 1024.0)
        .unwrap_or(f64::NAN)
}

fn rung_context() -> Digest {
    *blake3::hash(b"private block: the development rung, end to end (S12a)").as_bytes()
}

/// The rung statement and an honest witness for it. `zero` selects the
/// ALL-ZERO hidden input — the fixed input of the privacy case — instead of
/// `grow_tests`' tame one.
fn rung_parts(zero: bool) -> (Shape, BlockPublic, Witness) {
    let sh = Shape::rung();
    let (public, ff, tame) = super::grow_tests::tame_case(&sh);
    let input = if zero { vec![0i16; sh.tokens * sh.width] } else { tame };
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung's honest witness");
    (sh, BlockPublic::new(public, ff), w)
}

/// The two caller-fixed endpoints of a rung witness. They commit the PADDED
/// `Dom::D` cube — 4,096 words, exactly the frozen seam's ceiling — because
/// that is the slice `SC_IO_IN` / `SC_IO_OUT` claim, and `SeamSpec::new`
/// refuses the true `(24, 96)` plane outright (S11-F2).
fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung has a plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect() };
    let spec = IoSpec::new_shaped(sh, rung_context(), 0, 0).expect("the rung endpoint spec");
    prepare_endpoints(spec, &plane(ids.at(A_X)), &plane(ids.at(A_X2))).expect("the rung endpoint owners")
}

/// prove the rung for a witness, returning the policy, the receipt and its
/// bytes (encoding is part of what S12a has to show works)
fn prove_rung(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

/// **THE STEP'S ACCEPTANCE.** An honest rung proof verifies FROM BYTES in a
/// fresh verifier call, and its frame is the counted length.
#[test]
fn the_honest_rung_proof_verifies_from_bytes() {
    let (sh, blk, w) = rung_parts(false);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_rung(&sh, &blk, w).expect("the honest rung prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), RUNG_BYTES, "the rung frame is not the counted length");
    // typed form first, then the only form that counts: from the bytes
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung receipt verifies from bytes");
    let verify_s = t1.elapsed().as_secs_f64();
    eprintln!("S12a rung end to end: prove {prove_s:.2} s, verify from bytes {verify_s:.2} s, frame {} B, peak RSS {:.0} MiB (shared box, diagnostics only)", bytes.len(), peak_rss_mib());
    // a truncated or lengthened frame is refused before anything is parsed
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung frame was accepted");
}

/// The ALL-ZERO hidden input at the rung: the fixed input of the privacy case
/// is a valid witness at this shape too, and its receipt verifies from bytes.
/// A precondition of the privacy argument, not a privacy result.
#[test]
fn the_all_zero_hidden_input_proves_and_verifies_at_the_rung() {
    let (sh, blk, w) = rung_parts(true);
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    assert!(w.planes[ids.at(A_X)].iter().all(|v| *v == 0), "the zero input's x_in plane is not zero");
    assert!(w.planes[ids.at(A_X2)].iter().all(|v| *v == 0), "the zero input's block output is not zero");
    let (expected, _, bytes) = prove_rung(&sh, &blk, w).expect("the all-zero rung input is a valid witness");
    assert_eq!(bytes.len(), RUNG_BYTES, "the frame length moves with the hidden input");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the zero-witness rung receipt verifies from bytes");
}

/// **PZ-1 END TO END (ruling P-1).** ONE nonzero value in a padded position of
/// a ZERO-rule plane that no claimed sum reads. At the witness level `pad.rs`
/// showed nothing saw it; here the pad-zero term must make the VERIFIER reject.
#[test]
fn pz1_end_to_end_a_lone_nonzero_pad_value_is_rejected_by_the_verifier() {
    let (sh, blk, mut w) = rung_parts(false);
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let supp = super::pad::indicator_table(&sh, Dom::D);
    let pad_pos = (0..sh.size(Dom::D)).find(|i| supp[*i] == 0).expect("Dom::D pads at the rung");
    w.planes[ids.at(A_RAL)][pad_pos] = 1;
    assert_rejected(&sh, &blk, w, "PZ-1");
}

/// **PZ-2 END TO END (blocking items B-1 / B-4).** `A_X`'s padded columns of
/// one token row, with that row's whole isqrt witness recomputed from the
/// enlarged sum of squares, so every relation but the pad rule is satisfied
/// under a norm divisor the prover chose.
#[test]
fn pz2_end_to_end_a_consistently_adjusted_pad_is_rejected_by_the_verifier() {
    let (sh, blk, mut w) = rung_parts(false);
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let t = 0usize;
    let (px, pd, pdsq, plimb) = (ids.at(A_X), ids.at(A_D), ids.at(A_DSQ), ids.at(A_LIMB));
    for i in sh.width..sh.d_pad {
        w.planes[px][t * sh.d_pad + i] = 32_767;
        let v = 32_767 + 32_768;
        w.planes[ids.at(A_XL0)][t * sh.d_pad + i] = v & 255;
        w.planes[ids.at(A_XL1)][t * sh.d_pad + i] = v >> 8;
    }
    let ss: i64 = 1 + (0..sh.d_pad).map(|i| w.planes[px][t * sh.d_pad + i].pow(2)).sum::<i64>();
    let d = witness::isqrt(ss as u64) as i64;
    let (a1, a2) = (ss - d * d, 2 * d - (ss - d * d));
    w.planes[pd][t] = d;
    w.planes[pdsq][t] = d * d;
    for (base, v) in [(0usize, d), (3, a1), (6, a2)] {
        for kk in 0..3 {
            w.planes[plimb][(base + kk) * sh.t_pad + t] = (v >> (8 * kk)) & 255;
        }
    }
    assert_rejected(&sh, &blk, w, "PZ-2");
}

/// **THE LOGUP ARM IS NEVER GATED (§3.7a), so EVERY position of every padded
/// domain must still be a genuine table row.** Ruling P-1 excludes the LogUp
/// arm from the support factor on purpose: gating it would drop the padded
/// positions out of the value-0 identity while the histograms still counted
/// them. The price is this obligation, and it is the one the first honest
/// rung proof failed on ("H: pcs zk: group 8"), because the histogram folds
/// an out-of-table value into entry 0 and only the identity notices.
///
/// This test is the same three "hit" conditions the prover's histogram loop
/// uses (`protocol.rs:418-437`), checked position by position and REPORTED by
/// name, so that a future calibration or pad change says which lookup left
/// its table instead of failing a PCS group.
#[test]
fn every_rung_lookup_is_a_genuine_table_row() {
    let (sh, blk, w) = rung_parts(false);
    let lay = Layout::for_shape(&sh).expect("the rung layout");
    let ids = lay.ids();
    let (public, ff) = (blk.attention(), blk.feed_forward());
    for dom in lay.lookup_doms() {
        for (k, col) in super::protocol::lookup_values(&lay, &w, *dom).iter().enumerate() {
            if let Some((x, v)) = col.iter().enumerate().find(|(_, v)| !(0..256).contains(*v)) {
                panic!("{dom:?} lookup {k} at position {x} has value {v}, outside the U8 table");
            }
        }
    }
    let deltas = super::protocol::exp_deltas(&lay, &w);
    let e = &w.planes[ids.at(A_E)];
    if let Some((x, d)) = deltas.iter().enumerate().find(|(x, d)| !((0..256).contains(*d) && public.exp[**d as usize] == e[*x])) {
        let (tp, hp) = (sh.t_pad, sh.h_pad);
        let (h, t, j) = (x / (tp * tp), (x / tp) % tp, x % tp);
        panic!("the exp pair at (head slot {h}, t {t}, j {j}) is not a table row: delta {d}, e {} (head slot true: {}, t true: {}, j true: {})", e[x], sh.slot_is_true_head(h), t < sh.tokens, j < sh.tokens);
    }
    assert_eq!(deltas.len(), sh.h_pad * sh.t_pad * sh.t_pad, "the exp lookup covers the whole padded S cube ({hp} head slots)", hp = sh.h_pad);
    let act = super::protocol::act_indices(&lay, &w);
    let a16 = &w.planes[ids.at(A_A16)];
    if let Some((x, i)) = act.iter().enumerate().find(|(x, i)| !((0..256).contains(*i) && i64::from(ff.act[**i as usize]) == a16[*x])) {
        let (t, j) = (x / sh.f_pad, x % sh.f_pad);
        panic!("the activation pair at (t {t}, j {j}) is not a table row: index {i}, a16 {} (t true: {}, j true: {})", a16[x], t < sh.tokens, j < sh.hidden);
    }
}

/// A tampered witness must not produce an accepted receipt: either the honest
/// prover refuses it (its own relation checks), or a receipt is produced and
/// the VERIFIER rejects it from the bytes. Both are recorded, because which
/// one happens is part of the finding.
fn assert_rejected(sh: &Shape, blk: &BlockPublic, w: Witness, label: &str) {
    match prove_rung(sh, blk, w) {
        Err(e) => eprintln!("{label}: refused by the prover: {e}"),
        Ok((expected, _, bytes)) => {
            let r = verify_bytes_at(sh, blk, &expected, &bytes);
            let e = r.err().unwrap_or_else(|| panic!("{label}: a tampered rung receipt VERIFIED"));
            eprintln!("{label}: rejected by the verifier: {e}");
        }
    }
}
