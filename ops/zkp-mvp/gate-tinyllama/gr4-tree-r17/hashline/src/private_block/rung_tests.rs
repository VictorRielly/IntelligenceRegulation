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
/// and `grow_tests::MODEL_RUNG` all agree on it). It is what the frozen
/// seam's PADDED `(32, 128)` endpoint costs — 21 commitment rows at the
/// seam's own row width `2^8` and inverse rate 8, the plane sitting at
/// exactly its 4,096-word ceiling (finding S11-F4). **Since lane stage 23
/// (the shaped check's finding B-12) the independent Python model derives
/// that geometry itself and produces this figure too**, so the 45,056 B it
/// used to differ by — its pricing of the TRUE `(24, 96)` plane — is no
/// longer a correction term anywhere.
/// **STAGE 20 (the S19-F1 repair) moves both of these**, and by an amount
/// that is COUNTED from the shape's axes in `grow_tests::s20_bilinear_delta`
/// and never pasted: the two bilinear attention slots gain `log2(kv_heads)`
/// main rounds and one degree, which at both rungs (`kv_heads = 2`) is
/// `+336 B` — the only part of a frame the repair touches.
fn rung_bytes() -> usize {
    super::grow_tests::s20_frame_bytes(&Shape::rung(), RUNG_BYTES_BEFORE_S20)
}

fn rung_g_bytes() -> usize {
    super::grow_tests::s20_frame_bytes(&Shape::rung_g(), RUNG_G_BYTES_BEFORE_S20)
}

const RUNG_BYTES_BEFORE_S20: usize = 4_218_264;

/// **S11b: the RUNG-G profile's counted frame.** The same block at the same
/// shape with the GENERALISED endpoint: the rung's 4,218,264 B less the
/// frozen seam's two openings (319,488 B, 21 rows at row width 2^8 and rate
/// 8) plus the generalised ones (335,872 B, 9 rows at row width 2^10 and
/// rate 4). `Shape::receipt_bytes`, `wire::encoded_len` and
/// `the_codec_length_is_the_models_at_every_shape` all agree on it.
const RUNG_G_BYTES_BEFORE_S20: usize = 4_234_648;

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
fn rung_parts_at(sh: &Shape, zero: bool) -> (Shape, BlockPublic, Witness) {
    let (public, ff, tame) = super::grow_tests::tame_case(sh);
    let input = if zero { vec![0i16; sh.tokens * sh.width] } else { tame };
    let w = witness::build_shaped(sh, &public, &ff, &input).expect("the rung's honest witness");
    (sh.clone(), BlockPublic::new(public, ff), w)
}

fn rung_parts(zero: bool) -> (Shape, BlockPublic, Witness) {
    rung_parts_at(&Shape::rung(), zero)
}

/// The two caller-fixed endpoints of a rung witness. They commit the PADDED
/// `Dom::D` cube — 4,096 words, exactly the frozen seam's ceiling — because
/// that is the slice `SC_IO_IN` / `SC_IO_OUT` claim, and `SeamSpec::new`
/// refuses the true `(24, 96)` plane outright (S11-F2).
fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    endpoints_of_t(sh, w, None)
}

/// The same, with ONE word of ONE committed endpoint plane changed — the
/// endpoint owner sealing something other than the witness it proves about.
/// `tamper` is `(which endpoint: 0 input / 1 output, position in the padded
/// plane, delta)`. The WITNESS is untouched, so nothing but the equality
/// slot `SC_IO_IN` / `SC_IO_OUT` can notice.
fn endpoints_of_t(sh: &Shape, w: &Witness, tamper: Option<(usize, usize, i16)>) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung has a plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect() };
    let spec = IoSpec::new_shaped(sh, rung_context(), 0, 0).expect("the rung endpoint spec");
    let (mut a, mut b) = (plane(ids.at(A_X)), plane(ids.at(A_X2)));
    if let Some((which, at, delta)) = tamper {
        let p = if which == 0 { &mut a } else { &mut b };
        p[at] += delta;
    }
    prepare_endpoints(spec, &a, &b).expect("the rung endpoint owners")
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
    the_honest_proof_verifies_from_bytes_at(&Shape::rung(), rung_bytes());
}

/// **S11b's ACCEPTANCE.** The same, on the RUNG-G profile: the generalised
/// endpoint, at a row width and rate the frozen seam cannot offer, and a
/// geometry with four data rows per endpoint as 125M will have thirty-two.
#[test]
fn the_honest_rung_g_proof_verifies_from_bytes() {
    the_honest_proof_verifies_from_bytes_at(&Shape::rung_g(), rung_g_bytes());
}

fn the_honest_proof_verifies_from_bytes_at(shape: &Shape, want: usize) {
    let (sh, blk, w) = rung_parts_at(shape, false);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_rung(&sh, &blk, w).expect("the honest rung prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), want, "the rung frame is not the counted length");
    // typed form first, then the only form that counts: from the bytes
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung receipt verifies from bytes");
    let verify_s = t1.elapsed().as_secs_f64();
    eprintln!("{} end to end: prove {prove_s:.2} s, verify from bytes {verify_s:.2} s, frame {} B, endpoint {} rows at 2^{} / rate {}, peak RSS {:.0} MiB (shared box, diagnostics only)", sh.name, bytes.len(), sh.endpoint_rows, sh.endpoint_log_n, sh.endpoint_inv_rate, peak_rss_mib());
    // a truncated or lengthened frame is refused before anything is parsed
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung frame was accepted");
}

/// **STAGE 11's PARITY GATE: the phase clock changes no proof.** One rung-G
/// proof is made with the clock ON and one with it OFF; the clocked frame is
/// the counted length, and a verifier with the clock OFF accepts it, in typed
/// form and from bytes, while a one-byte truncation of it is still refused.
///
/// BYTE EQUALITY BETWEEN THE TWO IS NOT ASSERTED AND IS NOT EXPECTED: every
/// attempt draws a fresh OS randomness stream, so two honest proofs of the
/// same statement differ in their bytes whatever the switch is doing. What is
/// asserted is that the clock moves neither the length nor acceptance.
#[test]
fn a_proof_made_with_the_phase_clock_on_verifies_with_it_off() {
    let shape = Shape::rung_g();
    // the reference frame, clock off
    super::timing::force(Some(false));
    let (sh, blk, w) = rung_parts_at(&shape, false);
    let (_, _, off) = prove_rung(&sh, &blk, w).expect("the rung-G prover with the clock off");
    // the same statement, clock on for the PROVER only
    super::timing::force(Some(true));
    let (sh, blk, w) = rung_parts_at(&shape, false);
    let clocked = prove_rung(&sh, &blk, w);
    // the clock goes off before ANY assertion, so a failure cannot leave it set
    super::timing::force(Some(false));
    let (expected, receipt, on) = clocked.expect("the rung-G prover with the clock on");
    assert_eq!(on.len(), off.len(), "the phase clock moved the frame length");
    assert_eq!(on.len(), rung_g_bytes(), "the clocked frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("a clocked receipt is refused by an unclocked verifier in typed form");
    verify_bytes_at(&sh, &blk, &expected, &on).expect("a clocked receipt is refused by an unclocked verifier from bytes");
    assert!(verify_bytes_at(&sh, &blk, &expected, &on[..on.len() - 1]).is_err(), "a short clocked frame was accepted");
    super::timing::force(None);
    eprintln!("stage 11 parity: clock ON frame {} B, clock OFF frame {} B, both the counted length; the ON frame verifies under a verifier with the clock OFF", on.len(), off.len());
}

/// The ALL-ZERO hidden input at the rung: the fixed input of the privacy case
/// is a valid witness at this shape too, and its receipt verifies from bytes.
/// A precondition of the privacy argument, not a privacy result.
#[test]
fn the_all_zero_hidden_input_proves_and_verifies_at_the_rung() {
    the_all_zero_hidden_input_proves_at(&Shape::rung(), rung_bytes());
}

/// The same on the RUNG-G profile.
#[test]
fn the_all_zero_hidden_input_proves_and_verifies_at_the_rung_g() {
    the_all_zero_hidden_input_proves_at(&Shape::rung_g(), rung_g_bytes());
}

fn the_all_zero_hidden_input_proves_at(shape: &Shape, want: usize) {
    let (sh, blk, w) = rung_parts_at(shape, true);
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    assert!(w.planes[ids.at(A_X)].iter().all(|v| *v == 0), "the zero input's x_in plane is not zero");
    assert!(w.planes[ids.at(A_X2)].iter().all(|v| *v == 0), "the zero input's block output is not zero");
    let (expected, _, bytes) = prove_rung(&sh, &blk, w).expect("the all-zero rung input is a valid witness");
    assert_eq!(bytes.len(), want, "the frame length moves with the hidden input");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the zero-witness rung receipt verifies from bytes");
}

/// **PZ-1 END TO END (ruling P-1).** ONE nonzero value in a padded position of
/// a ZERO-rule plane that no claimed sum reads. At the witness level `pad.rs`
/// showed nothing saw it; here the pad-zero term must make the VERIFIER reject.
#[test]
fn pz1_end_to_end_a_lone_nonzero_pad_value_is_rejected_by_the_verifier() {
    pz1_at(&Shape::rung());
}

/// PZ-1 on the RUNG-G profile.
#[test]
fn pz1_end_to_end_at_the_rung_g_profile() {
    pz1_at(&Shape::rung_g());
}

fn pz1_at(shape: &Shape) {
    let (sh, blk, mut w) = rung_parts_at(shape, false);
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let supp = super::pad::indicator_table(&sh, Dom::D);
    let pad_pos = (0..sh.size(Dom::D)).find(|i| supp[*i] == 0).expect("Dom::D pads at the rung");
    w.planes[ids.at(A_RAL)][pad_pos] = 1;
    assert_verifier_rejects(&sh, &blk, w, "PZ-1");
}

/// **PZ-2 END TO END (blocking items B-1 / B-4).** `A_X`'s padded columns of
/// one token row, with that row's whole isqrt witness recomputed from the
/// enlarged sum of squares, so every relation but the pad rule is satisfied
/// under a norm divisor the prover chose.
#[test]
fn pz2_end_to_end_a_consistently_adjusted_pad_is_rejected_by_the_verifier() {
    pz2_at(&Shape::rung());
}

/// PZ-2 on the RUNG-G profile.
#[test]
fn pz2_end_to_end_at_the_rung_g_profile() {
    pz2_at(&Shape::rung_g());
}

fn pz2_at(shape: &Shape) {
    let (sh, blk, mut w) = rung_parts_at(shape, false);
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
    assert_verifier_rejects(&sh, &blk, w, "PZ-2");
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
    for dom in lay.lookup_doms().iter() {
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

/// **EVERY TOY TAMPER FAMILY, RE-RUN AT THE RUNG SHAPE.** `tamper.rs` and
/// `norm_alias.rs` decide their cases at the TOY, where nothing pads, the
/// head axis is the identity and the row width is the seam's. This battery
/// re-runs one representative of each family at the rung, on a TRUE support
/// position so that the pad rule is never what catches it, and requires each
/// to be refused by the prover or rejected by the verifier from the bytes.
/// The reason each is caught is printed, so a tamper that starts being
/// caught by the WRONG relation is visible in the log.
#[test]
fn every_toy_tamper_family_is_rejected_at_the_rung() {
    every_toy_tamper_family_is_rejected_at(&Shape::rung());
}

/// The same twenty-seven families on the RUNG-G profile.
#[test]
fn every_toy_tamper_family_is_rejected_at_the_rung_g_profile() {
    every_toy_tamper_family_is_rejected_at(&Shape::rung_g());
}

fn every_toy_tamper_family_is_rejected_at(shape: &Shape) {
    let sh = shape.clone();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    // one true-support position of each cube: index 0 is `(t 0, i 0)`,
    // `(t 0, j 0)`, `(head slot 0, t 0, j 0)` and so on, and head slot 0 is
    // a true slot at the rung
    let cases: Vec<(&str, usize, usize, i64)> = vec![
        ("the norm_a denominator", ids.at(A_D), 0, 1),
        ("a norm_a byte limb", ids.at(A_LIMB), 0, 300),
        ("the norm_a quotient", ids.at(A_Y), 0, 1),
        ("residual 1", ids.at(A_X1), 0, 1),
        ("the input plane", ids.at(A_X), 0, 1),
        ("an int16 byte limb of x", ids.at(A_XL0), 0, 300),
        ("the Q projection", ids.at(A_Q8), 0, 1),
        ("the rotated query", ids.at(A_QR8), 0, 1),
        ("the K projection", ids.at(A_K8), 0, 1),
        ("the V projection", ids.at(A_V8), 0, 1),
        ("the score", ids.at(A_S8), 0, 1),
        ("the row maximum", ids.at(A_MX), 0, 1),
        ("the exp value", ids.at(A_E), 0, 1),
        ("the softmax quotient", ids.at(A_P), 0, 1),
        ("the output projection", ids.at(A_O8), 0, 1),
        ("the attention output", ids.at(A_AO), 0, 1),
        ("a biased attention remainder", ids.at(A_RAL), 0, 1),
        ("the norm_m denominator", ids.at(A_DM), 0, 1),
        ("a norm_m byte limb", ids.at(A_LIMBM), 0, 300),
        ("the norm_m quotient", ids.at(A_YM), 0, 1),
        ("the gate output", ids.at(A_G8), 0, 1),
        ("a biased gate remainder", ids.at(A_RGL), 0, 1),
        ("the activation value", ids.at(A_A16), 0, 1),
        ("the up output", ids.at(A_U16), 0, 1),
        ("the gate-up product", ids.at(A_H16), 0, 1),
        ("the feed-forward output", ids.at(A_Z16), 0, 1),
        ("residual 2", ids.at(A_X2), 0, 1),
    ];
    // NOT in the table: the three histograms. They are DERIVED by the prover
    // from the witness (`protocol.rs:418-441`) and the integer builder leaves
    // their planes empty, so the toy's moved-multiplicity tamper has to edit
    // the prover's own buffer and cannot be expressed as a witness edit. It
    // stays a toy case (`tamper::a_moved_activation_multiplicity_is_rejected_
    // by_the_logup_sum_claim`); what the rung adds for that arm is
    // `every_rung_lookup_is_a_genuine_table_row` above.
    for (name, plane, at, delta) in cases {
        let (_, blk, mut w) = rung_parts_at(&sh, false);
        w.planes[plane][at] += delta;
        assert_verifier_rejects(&sh, &blk, w, name);
    }
}

/// **THE TWO ENDPOINT TAMPER FAMILIES (S11b), which only an endpoint the
/// prover does not control can express.** The witness is honest and the
/// receipt is built from it; what moves is ONE word of the plane the
/// endpoint owner SEALED. Nothing in the block's arithmetic reads the
/// endpoint commitment: the only thing that binds it to the proof is the
/// equality slot `SC_IO_IN` / `SC_IO_OUT` over the WHOLE PADDED plane, so
/// each of these must be rejected by the verifier and by nothing else.
///
/// The PAD case is the interesting one. `A_X`'s and `A_X2`'s padded columns
/// are forced to zero by ruling P-1's pad-zero term, and the equality slot
/// claims the whole padded `Dom::D` cube, so a nonzero word in the
/// ENDPOINT's pad has nothing on the witness side to match it.
#[test]
fn an_endpoint_that_seals_a_different_plane_is_rejected() {
    for shape in [Shape::rung(), Shape::rung_g()] {
        let (sh, blk, w) = rung_parts_at(&shape, false);
        // a TRUE support position, `(t 0, i 0)`, and a PADDED one — the
        // first column past the true width of token row 0
        let pad_at = sh.width;
        assert!(pad_at < sh.d_pad, "the rung's Dom::D pads");
        for (which, what) in [(0usize, "the input endpoint"), (1, "the output endpoint")] {
            for (at, where_) in [(0usize, "a true support position"), (pad_at, "a padded position")] {
                let (_, _, w) = rung_parts_at(&shape, false);
                let (expected, owners) = endpoints_of_t(&sh, &w, Some((which, at, 1)));
                let label = format!("{}: {what} sealing {where_}", sh.name);
                // FINDING F-8 applies here too: the prover must produce the
                // receipt and the VERIFIER must be the one that refuses it.
                match prove_inner_at(&sh, &blk, w, &expected, owners) {
                    Err(e) => panic!("{label}: the PROVER refused, so this case says nothing about the verifier: {e}"),
                    Ok((receipt, _)) => {
                        let bytes = receipt.to_bytes_at(&sh, &blk, &expected).expect("the frame encodes");
                        let e = verify_bytes_at(&sh, &blk, &expected, &bytes).err().unwrap_or_else(|| panic!("{label}: a receipt against a foreign endpoint VERIFIED"));
                        eprintln!("{label}: rejected by the verifier: {e}");
                    }
                }
            }
        }
        // and the honest endpoints of the same witness still verify, so the
        // rejection above is the tamper and not the machinery
        let (expected, receipt, bytes) = prove_rung(&sh, &blk, w).expect("the honest prover");
        verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest endpoints verify");
        assert_eq!(bytes.len(), if sh.endpoint_general { rung_g_bytes() } else { rung_bytes() }, "{}: frame length", sh.name);
        drop(receipt);
    }
}

/// **THE NORM-RANGE ALIAS (ruling P-5), END TO END AT THE RUNG.** The
/// half-`p` alias of the isqrt denominator satisfies (R1), (R3) and (R4) in
/// `F_p` — `norm_alias::the_alias_still_breaks_exactly_r2_on_a_rung_witness`
/// proves that at the rung's own numbers — and is refused only by (R2), the
/// byte-limb reconstruction. Here it is refused END TO END, from the bytes,
/// at the rung.
#[test]
fn the_norm_range_alias_is_rejected_end_to_end_at_the_rung() {
    the_norm_range_alias_is_rejected_at(&Shape::rung());
}

/// The alias on the RUNG-G profile.
#[test]
fn the_norm_range_alias_is_rejected_end_to_end_at_the_rung_g() {
    the_norm_range_alias_is_rejected_at(&Shape::rung_g());
}

fn the_norm_range_alias_is_rejected_at(shape: &Shape) {
    let sh = shape.clone();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let half = super::norm_alias::half_p_minus_one();
    for (t, form) in [(0usize, "norm_a row 0"), (1, "norm_a row 1")] {
        let (_, blk, mut w) = rung_parts_at(&sh, false);
        let d = crate::field::Fp::from_i64(w.planes[ids.at(A_D)][t]).add(half);
        // form (a): the limbs are left honest, so (R2) is the one relation
        // the alias cannot satisfy
        w.planes[ids.at(A_D)][t] = super::norm_alias::to_plane(d);
        w.planes[ids.at(A_DSQ)][t] = super::norm_alias::to_plane(d.mul(d));
        assert_verifier_rejects(&sh, &blk, w, &format!("the half-p isqrt alias on {form}"));
    }
}

/// **FINDING F-8 of the independent review.** The helper this replaces counted
/// a refusal BY THE PROVER as a pass, and a prover refusal is not a soundness
/// statement: a cheating prover does not run the honest prover's own checks.
/// A tamper test now has to say which of the two it means.
///
/// `assert_verifier_rejects`: the honest prover MUST produce a receipt from the
/// tampered witness, and the VERIFIER must refuse it from the bytes. This is
/// the one that carries a soundness claim, and every one of the lane's rung
/// tamper cases uses it.
fn assert_verifier_rejects(sh: &Shape, blk: &BlockPublic, w: Witness, label: &str) {
    // STAGE 40 (ported, native round 5), ruling CS-3: the honest prover
    // refuses a lookup miss by name; a cheating prover does not, so this
    // helper proves with the check off and the verifier has to speak
    let _cheating = super::protocol::CheatingProver::on();
    match prove_rung(sh, blk, w) {
        Err(e) => panic!("{label}: the PROVER refused, so this case says nothing about the verifier: {e}"),
        Ok((expected, _, bytes)) => {
            let r = verify_bytes_at(sh, blk, &expected, &bytes);
            let e = r.err().unwrap_or_else(|| panic!("{label}: a tampered rung receipt VERIFIED"));
            eprintln!("{label}: rejected by the verifier: {e}");
        }
    }
}

/// The other half of the split: a witness the HONEST PROVER is expected to
/// refuse, because it is outside the range its own construction can encode.
/// It is a liveness / diagnostics statement and NOT a soundness one — a
/// cheating prover is not bound by it — so no case may use this helper unless
/// the ledger records why the verifier cannot be the one to speak.
#[allow(dead_code)]
fn assert_the_honest_prover_refuses(sh: &Shape, blk: &BlockPublic, w: Witness, label: &str) {
    match prove_rung(sh, blk, w) {
        Err(e) => eprintln!("{label}: refused by the honest prover (NOT a soundness statement): {e}"),
        Ok(_) => panic!("{label}: the honest prover was expected to refuse and did not"),
    }
}
