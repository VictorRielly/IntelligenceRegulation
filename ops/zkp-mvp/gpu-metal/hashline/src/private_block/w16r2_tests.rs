//! **W16R2 (D59): W16 at code rate 1/2, the column test counted at the
//! Reed–Solomon unique-decoding radius.** Test builds only.
//!
//! The profiles (`shape::W16R2_PROFILES`) are W16's geometries under new
//! strings. Their regular commitments (`A`, `H`, every boundary and both
//! endpoints) are encoded at rate 1/2 with `Q = 280` opened columns and
//! `Q` pads per row (`shape::W16R2_OPENED_COLS`: Victor's ruling on review
//! F2, 2026-11-02; it was 260); the masking commitment `M` keeps its own constants. The
//! lemma that prices them is the independent check of 2026-11-01
//! (`research/zkp-efficiency/handoffs/20261101-delta-half-lemma-check.md`):
//! per opening `(1 - (e + 1)/N)^Q + N/|Fp2|`, `e = floor((N - K)/2)`,
//! `K = n + Q`.
//!
//! What is here:
//! * the profile facts, and that nothing else moves (every other profile
//!   keeps rate 1/4 or its own, and `Q = 256`);
//! * the verifier reads `(rate, Q)` from the profile: a shape that carries a
//!   W16R2 string at any other geometry cannot be built, and receipts made
//!   at another rate or `Q` are rejected (control (e));
//! * the D59 malicious controls, (a) a far matrix, (b) a wrong opened
//!   column, (c) a column set chosen before the challenge, (d) a forged
//!   clear vector against an honest matrix (its pad half, and the
//!   max-agreement forgery), (e) another rate or `Q`, and since the review
//!   of 2026-11-02 (f) THE LEMMA'S CLOSE CASE (a matrix inside the
//!   unique-decoding radius, both clear vectors moved by a codeword that
//!   vanishes on `K - 1` columns, a false claim) and (g) a replay at the
//!   same geometry under another profile's keys — at the profile's own PCS
//!   parameters and keys through `pcs::verify_zk_tagged` (the function
//!   `verify_core` calls for `A` and `H`, and a run for every boundary and
//!   endpoint), and on real block proofs where a post-hoc edit can express
//!   the cheat; plus, at a toy rate-1/2 geometry where the rates are
//!   measurable, the acceptance rates of (a), (d) and (f) against their
//!   EXACT values (`(1 - (e + 1)/N)^Q` for (a) and (f));
//! * review F3: run-level controls on a W16R2 rung run (`L = 3`): its
//!   boundaries and endpoints tampered or replaced by rate-1/4 ones, under
//!   the D12a run verifier and the D55 fork verifier, and an endpoint policy
//!   committed at rate 1/4 refused by CS-4;
//! * review F4 (b): the codec length is the count at every W16R2 shape, and
//!   every frame of a real W16R2 run has its counted length;
//! * W16's own malicious controls (the out-of-range limbs and review F3's
//!   four) ported to the W16R2 rung;
//! * the dev rung's golden digest (CPU), and its CPU = Metal identity;
//! * the lemma's load-bearing invariants, pinned (`run_fork.rs` too);
//! * the accounting inputs, printed from the code
//!   (`results/zk60_w16r2_20261101/ACCOUNTING.md` reads them);
//! * the A/B on one binary (W16 against W16R2 at 8B T128), ignored.
//!
//! **`Q` is ONE constant** (`shape::W16R2_OPENED_COLS`; review F2's ruling
//! moved it from 260 to 280, 2026-11-03). Every control added on 2026-11-02
//! derives `Q`, `K`, `e` and its expected probabilities from that constant
//! and the shape. The deliberate literal pins, which a change of the
//! constant must update by hand, are the profile-facts test
//! (`w16r2_profiles_fix_rate_one_half_and_q_280_and_change_nothing_else`)
//! and the rung golden [`W16R2_RUNG_GOLDEN`]
//! (`results/zk60_w16r2_q280_20261103/README.md`).
//! * since F2's ruling: the privacy argument's hypotheses at `Q = 280`,
//!   checked on the production encoder (the pad block is `diag(Z_n) V`,
//!   full rank on any `<= Q` distinct opened points; `Q` = the pad count);
//! * review F6: the token and classifier whole-run counters price a W16R2
//!   block opening by the lemma that covers it, and every other profile's
//!   figure bit for bit as before.
use super::layout::*;
use super::protocol::{self, CoreProof, CoreView};
use super::range16_tests::{built, rung_case};
use super::run::fork::{D55OptIn, ForkReceipt, ForkRun};
use super::run::{RunShape, RunStatement};
use super::shape::{self, ColumnRegime, Shape};
use super::trained_statement::{IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind, TrainedModelStatement};
use super::wire;
use super::witness::Witness;
use super::*;
use crate::field::{Fp, Fp2};
use crate::ntt::NttTables;
use crate::transcript::Transcript;
use zkp_core::hashtag::HashTag;
use zkp_core::merkle::MerkleTree;
use zkp_core::pcs::{self as zpcs, Commitment, CommittedZk, NoExternal, OpeningZk, PcsParams, Slice, Store, ZClaim, ZPart, ZkOpts};
use zkp_core::rng::ZkRng;

/// each W16R2 profile beside its W16 sibling (the same geometry, rate 1/4)
const PAIRS: [(&str, &str); 3] = [
    (shape::W16R2_RUNG_H24, shape::W16_RUNG_H24),
    (shape::W16R2_SHIELD_T128_H24, shape::W16_SHIELD_T128_H24),
    (shape::W16R2_8B_T128_H24, shape::W16_8B_T128_H24),
];

// ------------------------------------------------------------ block harness

/// the endpoint planes a seeded block core proof is handed (the M4 recipe)
fn io_planes(sh: &Shape, w: &Witness) -> (Vec<Fp>, Vec<Fp>) {
    let ids = Ids::new(sh).unwrap();
    let (rows, n) = (sh.endpoint_rows, 1usize << sh.endpoint_log_n);
    let io = |p: usize| -> Vec<Fp> {
        let mut d = vec![Fp::ZERO; rows * n];
        for (i, v) in w.planes[p].iter().enumerate().take(d.len()) {
            d[i] = Fp::from_i64(*v);
        }
        d
    };
    (io(ids.at(A_X)), io(ids.at(A_X2)))
}

/// the header both sides absorb (`range16_tests::prove_and_verify_core`'s),
/// under the profile's Fiat–Shamir key: `protocol::tagged_transcript`, as
/// every production caller of `verify_core` builds its transcript (review
/// F3: this harness was an untagged `Transcript::new`)
fn header(sh: &Shape, lay: &Layout) -> Transcript {
    let mut tr = protocol::tagged_transcript(sh, b"zk60 W16R2 core");
    tr.absorb(b"profile", sh.profile.as_bytes());
    tr.absorb(b"schedule", &lay.schedule_digest());
    tr
}

/// prove one block's CORE at `sh` (`Err("prover: ..")` on a refusal)
fn prove(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<CoreProof, String> {
    let lay = Layout::for_shape(sh).map_err(|e| format!("prover: {e}"))?;
    let (ein, eout) = io_planes(sh, &w);
    let ntt = NttTables::new(protocol::ntt_log_at(sh));
    let mut rng = ZkRng::new(20261101, b"zk60 W16R2 core");
    let mut tr = header(sh, &lay);
    let mut ph = super::timing::Phases::start();
    let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
    protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).map_err(|e| format!("prover: {e}"))
}

/// verify a block CORE with the verifier of shape `sh` (its own layout, its
/// own PCS parameters), on a fresh transcript of the same header
fn verify(sh: &Shape, blk: &BlockPublic, core: &CoreProof) -> Result<(), String> {
    let lay = Layout::for_shape(sh)?;
    let ntt = NttTables::new(protocol::ntt_log_at(sh));
    let mut vt = header(sh, &lay);
    let view = CoreView { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: &core.slots, mask_open: &core.mask_open, a_open: &core.a_open, h_open: &core.h_open };
    let mut vph = super::timing::Phases::start();
    protocol::verify_core(sh, &lay, blk, view, &ntt, &mut vt, &mut vph).map(|_| ())
}

fn copy(w: &Witness) -> Witness {
    Witness { planes: w.planes.clone(), output_plane: w.output_plane }
}

/// one seeded block proof's digest, `slot_ir_accuracy::tests::seeded_accuracy_digest`'s
/// recipe exactly (its rng seed and domain, its transcript header, its text)
fn seeded_digest(sh: &Shape, blk: &BlockPublic, w: Witness) -> String {
    let lay = Layout::for_shape(sh).unwrap();
    let (ein, eout) = io_planes(sh, &w);
    let ntt = NttTables::new(protocol::ntt_log_at(sh));
    let mut rng = ZkRng::new(20261031, b"zk60 metal m4 accuracy");
    let mut tr = Transcript::new(b"zk60 metal m4 accuracy");
    tr.absorb(b"profile", sh.profile.as_bytes());
    tr.absorb(b"schedule", &lay.schedule_digest());
    let mut ph = super::timing::Phases::start();
    let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
    let core = protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the seeded W16R2 core proof");
    let text = format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
        core.a_root, core.h_root, core.mask_root, core.slots, core.mask_open, core.a_open, core.h_open, core.io_claims, core.order, core.lookups, tr.state()
    );
    blake3::hash(text.as_bytes()).to_hex().to_string()
}

/// the bytes of one block core: `(total, A opening, H opening, M opening, slots)`
fn core_bytes(core: &CoreProof) -> (usize, usize, usize, usize, usize) {
    let slots: usize = core.slots.iter().map(|s| 16 + s.sc.size_bytes() + 16 * s.terms.len()).sum();
    let (a, h, m) = (core.a_open.size_bytes(), core.h_open.size_bytes(), core.mask_open.size_bytes());
    (3 * 32 + slots + a + h + m, a, h, m, slots)
}

// --------------------------------------------------------------- the profile

/// **The profile facts, and nothing else moves.** Each W16R2 profile is its
/// W16 sibling's geometry and layout with the regular commitments at rate
/// 1/2 and `Q = 280` (pads included; review F2's ruling, 2026-11-02), its endpoint geometry following the
/// core's, its own string of the sibling's length, its own four keys and a
/// parameter line of the sibling's length that differs only in the rate and
/// `Q`. Every other profile this lane builds keeps its rate and `Q = 256`.
#[test]
fn w16r2_profiles_fix_rate_one_half_and_q_280_and_change_nothing_else() {
    assert_eq!(shape::W16R2_PROFILES.len(), PAIRS.len());
    for (r2, w16) in PAIRS {
        let (a, b) = (built(r2), built(w16));
        a.check_constructed().unwrap();
        assert!(shape::is_w16r2_profile(a.profile) && !shape::is_w16r2_profile(b.profile));
        assert!(a.range16() && b.range16() && shape::is_trained_profile_string(a.profile));
        assert_eq!((a.log_cols, a.inv_rate, a.opened_cols, a.endpoint_log_n, a.endpoint_inv_rate), (14, 2, 280, 14, 2), "{}", a.name);
        assert_eq!((b.log_cols, b.inv_rate, b.opened_cols, b.endpoint_log_n, b.endpoint_inv_rate), (14, 4, 256, 14, 4), "{}", b.name);
        assert_eq!(a.column_regime(), ColumnRegime::UniqueDecoding);
        assert_eq!(b.column_regime(), ColumnRegime::GeneralCode);
        // the same geometry in every other field
        let mut c = a.clone();
        (c.profile, c.name, c.inv_rate, c.opened_cols, c.endpoint_inv_rate) = (b.profile, b.name, b.inv_rate, b.opened_cols, b.endpoint_inv_rate);
        assert_eq!(c, b, "{}: the W16R2 shape differs from its W16 sibling outside the PCS geometry", a.name);
        // the same layout: the rate moves no plane, row or lookup
        let (la, lb) = (Layout::for_shape(&a).unwrap(), Layout::for_shape(&b).unwrap());
        assert_eq!((la.a_rows, la.h_rows, la.m_rows(), la.n()), (lb.a_rows, lb.h_rows, lb.m_rows(), lb.n()), "{}", a.name);
        // the transcript-bound schedule: every line the same but the first,
        // which names the profile and states the rate and Q (so the schedule
        // digest binds them as well)
        let (da, db) = (la.describe(), lb.describe());
        assert_eq!(da.len(), db.len(), "{}: the schedule's line count moved", a.name);
        assert_eq!(da[1..], db[1..], "{}: the slot schedule moved outside its header line", a.name);
        assert_eq!(da[0].replacen(a.profile, b.profile, 1).replace("inv_rate=2 Q=280", "inv_rate=4 Q=256"), db[0], "{}: the schedule's header differs outside the profile, rate and Q", a.name);
        assert_ne!(la.schedule_digest(), lb.schedule_digest());
        // the PCS parameters every verifier site reads
        let (p, e) = (protocol::pcs_params_at(&a), protocol::endpoint_pcs_params(&a));
        assert_eq!((p.log_cols, p.inv_rate, p.num_col_checks), (14, 2, 280));
        assert_eq!((e.log_cols, e.inv_rate, e.num_col_checks), (14, 2, 280));
        assert_eq!((ZkOpts::standard(&p).q_pad, ZkOpts::standard(&e).q_pad), (280, 280), "q_pad = Q: the pads ARE the opened-column count");
        assert_eq!(protocol::ntt_log_at(&a), 15);
        // strings, keys, parameter line
        assert_eq!(a.profile.len(), b.profile.len(), "{}: the W16R2 string is not its sibling's length", a.name);
        assert!(!a.hashes_under_the_legacy_rule() && a.hash_tag() == HashTag::for_profile(a.profile) && a.hash_tag() != b.hash_tag());
        let (pa, pb) = (protocol::parameter_line(&a), protocol::parameter_line(&b));
        assert_eq!(pa.len(), pb.len(), "the parameter line changed length");
        assert_eq!(pa.replace("inv_rate2/Q280", "inv_rate4/Q256").replace("rate2-pad280", "rate4-pad256"), pb, "the parameter lines differ outside the rate and Q");
        // the per-opening column term: no soundness given up
        let ((ca, cea), (cb, ceb)) = (a.regular_column_terms_log2(), b.regular_column_terms_log2());
        assert!(ca <= cb && cea <= ceb, "{}: the W16R2 opening ({ca:.3}) is weaker than W16's ({cb:.3})", a.name);
        eprintln!("W16R2 {} vs {}: rate 1/2 Q 280 column term 2^{ca:.3} (unique decoding) against 2^{cb:.3} (rate 1/4 Q 256, delta/3); A rows {}, H rows {}, receipt (counted) {} B against {} B", a.name, b.name, la.a_rows, la.h_rows, a.receipt_bytes().total, b.receipt_bytes().total);
    }
    // the lemma check's figures (§5): Q = 260 gives 2^-105.946 (exact form),
    // Q = 259 2^-105.53, W16 2^-105.61 — so 260 is the PROVEN-bound minimum
    // (review F2 asks that this gate stay), and the ruled Q is at or above it
    let ud = |q| shape::column_term_log2(ColumnRegime::UniqueDecoding, 14, 2, q);
    let w16 = shape::column_term_log2(ColumnRegime::GeneralCode, 14, 4, 256);
    assert!((ud(260) + 105.946).abs() < 0.001 && (ud(259) + 105.53).abs() < 0.01, "{} {}", ud(260), ud(259));
    assert!((w16 + 105.61).abs() < 0.01);
    assert!(ud(259) > w16 && ud(260) <= w16, "260 is no longer the smallest Q that keeps W16's proven per-opening figure");
    // F2's ruling: Q = 280, 2^-113.932 per opening (the recount's figure)
    assert_eq!(shape::W16R2_OPENED_COLS, 280);
    assert!((ud(shape::W16R2_OPENED_COLS) + 113.932).abs() < 0.001, "{}", ud(shape::W16R2_OPENED_COLS));
    assert!(shape::W16R2_OPENED_COLS >= 260 && ud(shape::W16R2_OPENED_COLS) <= w16);
    // nothing else moves: every other profile this lane builds keeps Q = 256
    let mut others: Vec<Shape> = vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()];
    others.extend(super::trained_calib_tests::registered_trained_shapes());
    others.extend(super::accuracy_profile_tests::registered_shapes());
    others.extend(shape::W16_PROFILES.iter().map(|s| built(s.profile)));
    for sh in &others {
        assert_eq!(sh.opened_cols, 256, "{}: Q moved", sh.name);
        assert!(!shape::is_w16r2_profile(sh.profile) && sh.column_regime() == ColumnRegime::GeneralCode, "{}", sh.name);
    }
    eprintln!("W16R2 profiles: {} at rate 1/2 Q 280; {} other profiles unchanged at Q 256 under the delta/3 count", shape::W16R2_PROFILES.len(), others.len());
}

/// **The verifier reads `(rate, Q)` from the PROFILE.** A shape carrying a
/// W16R2 string at any other rate or `Q` cannot be constructed or reach a
/// prover or verifier: `Shape::build` refuses it by name (D59), and a field
/// write is caught by ruling CS-8's rebuild. The W16 strings cannot be
/// re-rated either. A frozen shape under a W16R2 string (W16 review F1's
/// class) is refused by both name guards.
#[test]
fn w16r2_a_shape_at_another_rate_or_q_under_a_w16r2_string_is_refused() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    // Shape::new at rate 1/4 under the W16R2 rung string
    let e = Shape::new(sh.name, sh.profile, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.head_dim, sh.kv_heads, sh.log_cols, 4, sh.f_e, sh.endpoint_rows, None, None, None, None).expect_err("Shape::new built a W16R2 string at rate 1/4");
    assert!(e.contains("D59"), "{e}");
    eprintln!("W16R2 (e) Shape::new at rate 1/4: {e}");
    // the endpoints at another rate than the core
    let e = Shape::new(sh.name, sh.profile, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.head_dim, sh.kv_heads, sh.log_cols, 2, sh.f_e, sh.endpoint_rows, None, Some(4), None, None).expect_err("a W16R2 shape with rate-1/4 endpoints was built");
    assert!(e.contains("D59"), "{e}");
    // field writes: rate 1/4 with Q 256, and Q 256 alone at rate 1/2
    let mut quarter = sh.clone();
    (quarter.inv_rate, quarter.endpoint_inv_rate, quarter.opened_cols) = (4, 4, 256);
    let e = quarter.check_constructed().expect_err("CS-8 accepted a W16R2 shape at rate 1/4");
    assert!(e.contains("ruling CS-8") && e.contains("D59"), "{e}");
    eprintln!("W16R2 (e) a W16R2 shape written to rate 1/4, Q 256: {e}");
    let mut q256 = sh.clone();
    q256.opened_cols = 256;
    let e = q256.check_constructed().expect_err("CS-8 accepted a W16R2 shape at Q 256");
    assert!(e.contains("ruling CS-8") && e.contains("opened_cols"), "{e}");
    eprintln!("W16R2 (e) a W16R2 shape written to Q 256: {e}");
    // neither reaches a prover or a verifier
    let e = prove(&q256, &blk, copy(&w)).err().expect("the prover took a W16R2 shape at Q 256");
    assert!(e.contains("ruling CS-8"), "{e}");
    let honest = prove(&sh, &blk, copy(&w)).expect("the honest W16R2 rung core");
    for rogue in [&quarter, &q256] {
        let e = verify(rogue, &blk, &honest).expect_err("the verifier took a rogue W16R2 shape");
        assert!(e.contains("ruling CS-8"), "{e}");
    }
    // the W16 string cannot be re-rated
    let mut w16 = built(shape::W16_RUNG_H24);
    w16.inv_rate = 2;
    assert!(w16.check_constructed().is_err(), "a W16 shape at rate 1/2 passed CS-8");
    // W16 review F1's class, at every W16R2 string
    for spec in shape::W16R2_PROFILES.iter() {
        let mut f = Shape::rung_c6();
        f.profile = spec.profile;
        assert!(protocol::single_block_profile_allowed(&f).is_err(), "{}: the single-block path admitted a W16R2 string", spec.name);
        assert!(Layout::for_shape(&f).is_err(), "{}: Layout::for_shape accepted a frozen shape under a W16R2 string", spec.name);
    }
    verify(&sh, &blk, &honest).expect("the honest W16R2 rung core verifies");
}

/// **The dev rung's golden digest** (CPU), at the M4 byte-identity gate's
/// recipe (`range16_tests::rung_case`, `seeded_accuracy_digest`'s seed,
/// domain and text). Pinned: a change of any W16R2 byte fails here. The
/// honest core also verifies, and a changed `A` root is refused.
#[test]
fn w16r2_rung_core_proves_and_verifies_and_its_golden_digest_is_pinned() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    let d = seeded_digest(&sh, &blk, copy(&w));
    eprintln!("W16R2-GOLDEN {} cpu {d}", sh.name);
    assert!(d.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's seeded digest moved: {d} (pinned {W16R2_RUNG_GOLDEN})");
    let t = std::time::Instant::now();
    let core = prove(&sh, &blk, copy(&w)).unwrap();
    let prove_s = t.elapsed().as_secs_f64();
    let t = std::time::Instant::now();
    verify(&sh, &blk, &core).expect("the honest W16R2 rung core verifies");
    let verify_s = t.elapsed().as_secs_f64();
    let mut bad = prove(&sh, &blk, w).unwrap();
    bad.a_root[3] ^= 1;
    let e = verify(&sh, &blk, &bad).expect_err("a changed A root was accepted");
    let (bytes, a, h, m, slots) = core_bytes(&core);
    eprintln!("W16R2 rung core: prove {prove_s:.2} s, verify {verify_s:.2} s (CPU); core {bytes} B (A {a}, H {h}, M {m}, slots {slots}); a changed A root: {e}");
}

/// the first eight hex digits of the W16R2 rung's seeded CPU digest (at
/// `Q = 280` since F2's ruling; `334e168f` at `Q = 260`). D65(1), finding F12:
/// `96e4f0b6` under the `/2` profile and `M` from theta^1; it was `c6d5c2d8`
/// under the `/1` profile and theta^0 (theta^1 alone, still under `/1`, gave
/// `553137f1`: `results/zk60_f12_fix_20261104/REPIN.md`)
const W16R2_RUNG_GOLDEN: &str = "96e4f0b6";

/// **CPU = Metal at the W16R2 rung, and both equal the golden.** Toggles
/// `HL_GPU` in-process, so it is ignored and run alone by name.
#[cfg(feature = "gpu-metal")]
#[test]
#[ignore = "toggles HL_GPU in-process; run alone by name on a Mac"]
fn w16r2_rung_cpu_and_metal_digests_equal_the_golden() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    std::env::remove_var("HL_GPU");
    let cpu = seeded_digest(&sh, &blk, copy(&w));
    let before = crate::gpu::metal_sumcheck_stats().1;
    std::env::set_var("HL_GPU", "1");
    let metal = seeded_digest(&sh, &blk, w);
    std::env::remove_var("HL_GPU");
    let ran = crate::gpu::metal_sumcheck_stats().1 - before;
    eprintln!("W16R2-RUNG-DIGEST {} cpu {cpu} metal {metal} (device sumcheck rounds {ran:.4} s)", sh.name);
    assert_eq!(cpu, metal, "the Metal W16R2 rung proof's bytes differ from the CPU's");
    assert!(cpu.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's digest moved");
    assert!(ran > 0.0, "no sumcheck round ran on the device");
}

/// **[A11] the pool a proof runs in changes no byte (CPU).** The seeded W16R2
/// rung proof as a fork worker's own pool runs it (`run_fork.rs`,
/// `HL_D55_FORK_POOL`): inside a rayon pool of one thread, of two and of three,
/// and on the global pool. Every digest is the golden.
#[test]
fn a11_w16r2_rung_golden_inside_small_rayon_pools() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    for threads in [Some(1usize), Some(2), Some(3), None] {
        let d = match threads {
            Some(t) => rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("a rayon pool").install(|| seeded_digest(&sh, &blk, copy(&w))),
            None => seeded_digest(&sh, &blk, copy(&w)),
        };
        eprintln!("A11-POOLS {}: rayon pool {threads:?}: {d}", sh.name);
        assert!(d.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's digest moved inside a pool of {threads:?} threads: {d}");
    }
}

/// **[A11] the same on the device, concurrently.** Three seeded W16R2 rung
/// proofs at once, each inside its own rayon pool of `t` threads (1, 2, 6), as
/// three fork workers with their own pools run them: every digest is the CPU's,
/// which is the golden. Toggles `HL_GPU` in-process, so it is ignored and run
/// alone by name (`HL_GPU_REQUIRED=1`).
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A11: toggles HL_GPU in-process; run alone by name on a Mac, HL_GPU_REQUIRED=1"]
fn a11_w16r2_rung_digests_in_per_fork_pools_on_the_device() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    std::env::remove_var("HL_GPU");
    let cpu = seeded_digest(&sh, &blk, copy(&w));
    assert!(cpu.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's digest moved");
    std::env::set_var("HL_GPU", "1");
    for t in [1usize, 2, 6] {
        let before = crate::gpu::metal_sumcheck_stats().1;
        let got: Vec<String> = std::thread::scope(|s| {
            let hs: Vec<_> = (0..3)
                .map(|_| {
                    let (sh, blk, w) = (&sh, &blk, copy(&w));
                    s.spawn(move || rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("a rayon pool").install(|| seeded_digest(sh, blk, w)))
                })
                .collect();
            hs.into_iter().map(|h| h.join().expect("a proof thread")).collect()
        });
        let ran = crate::gpu::metal_sumcheck_stats().1 - before;
        eprintln!("A11-POOLS {} on the device: three concurrent proofs, each in its own pool of {t}: {:?} (device sumcheck rounds {ran:.4} s)", sh.name, got.iter().map(|d| &d[..8]).collect::<Vec<_>>());
        for d in &got {
            assert_eq!(d, &cpu, "a Metal W16R2 rung proof inside a pool of {t} threads differs from the CPU's");
        }
        assert!(ran > 0.0, "no sumcheck round ran on the device");
    }
    std::env::remove_var("HL_GPU");
}

/// **[A12] the device-built slot tables change no byte.** The seeded W16R2 rung
/// proof on the device with a device slot's tables built on the HOST
/// (`HL_METAL_DEVICE_TABLES=0`'s path) and on the DEVICE (`=1`'s), alone and as
/// three concurrent proofs each in its own rayon pool (1, 2 and 6 threads, as
/// fork workers run them): every digest is the CPU's, which is the golden, and
/// the device arm really built tables on the device. Toggles `HL_GPU`
/// in-process, so it is ignored and run alone by name (`HL_GPU_REQUIRED=1`).
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A12: toggles HL_GPU in-process; run alone by name on a Mac, HL_GPU_REQUIRED=1"]
fn a12_w16r2_rung_golden_with_the_slot_tables_built_on_the_host_and_on_the_device() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    std::env::remove_var("HL_GPU");
    let cpu = seeded_digest(&sh, &blk, copy(&w));
    assert!(cpu.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's digest moved");
    std::env::set_var("HL_GPU", "1");
    use super::argument::{DT_DEVICE, DT_HOST, DT_SYNC};
    for (on, mode) in [("host", DT_HOST), ("device (ahead of the first round)", DT_DEVICE), ("device (own command buffer)", DT_SYNC)] {
        super::argument::set_device_tables_for_test(Some(mode));
        let b0 = crate::gpu::MetalTables::build_stats();
        let alone = seeded_digest(&sh, &blk, copy(&w));
        let got: Vec<String> = std::thread::scope(|s| {
            let hs: Vec<_> = [1usize, 2, 6]
                .into_iter()
                .map(|t| {
                    let (sh, blk, w) = (&sh, &blk, copy(&w));
                    s.spawn(move || rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("a rayon pool").install(|| seeded_digest(sh, blk, w)))
                })
                .collect();
            hs.into_iter().map(|h| h.join().expect("a proof thread")).collect()
        });
        let b1 = crate::gpu::MetalTables::build_stats();
        let builds: Vec<u64> = b1.iter().zip(b0.iter()).map(|(a, b)| a - b).collect();
        eprintln!("A12-TABLES {} tables on the {on}: alone {}, three concurrent {:?}; device builds (builds, device tables, host tables, views, copies, resident, deferred, left to the host) {builds:?}", sh.name, &alone[..8], got.iter().map(|d| &d[..8]).collect::<Vec<_>>());
        assert_eq!(alone, cpu, "a Metal W16R2 rung proof with the tables on the {on} differs from the CPU's");
        for d in &got {
            assert_eq!(d, &cpu, "a concurrent Metal W16R2 rung proof with the tables on the {on} differs from the CPU's");
        }
        match mode {
            DT_HOST => assert_eq!(builds[0], 0, "the host arm built tables on the device: {builds:?}"),
            _ => {
                // four proofs, several device slots each, every one reading the
                // committed rows from the commitments' resident copies
                assert!(builds[0] >= 4 * 4 && builds[1] > 0 && builds[5] > 0 && builds[3] == 0 && builds[4] == 0 && builds[7] == 0, "the device arm's builds: {builds:?}");
                assert_eq!(builds[6] > 0, mode == DT_DEVICE, "the deferred builds: {builds:?}");
            }
        }
    }
    super::argument::set_device_tables_for_test(None);
    std::env::remove_var("HL_GPU");
}

/// **[A7] the queues change no byte, under concurrency.** The seeded W16R2 rung
/// proof on six threads at once, as six fork workers would run: first with every
/// thread's command buffers on the one shared queue, then on six queues (one per
/// thread). Every thread's digest must equal the CPU's and the golden. The second
/// arm also records the GPU timeline and checks its clock against the host's: each
/// command buffer begins, is committed, starts and ends on the GPU, and is seen
/// complete in that order (to 1 ms), and the six threads used six queues.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A7: toggles HL_GPU and the queue count in-process; run alone by name on a Mac, HL_GPU_REQUIRED=1"]
fn a7_w16r2_rung_digests_on_six_threads_at_one_and_at_six_queues() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    std::env::remove_var("HL_GPU");
    let cpu = seeded_digest(&sh, &blk, copy(&w));
    assert!(cpu.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's digest moved");
    std::env::set_var("HL_GPU", "1");
    let own = crate::gpu::metal_set_queues_for_test(false);
    for (q, per_thread) in [("shared", false), ("thread", true)] {
        crate::gpu::metal_set_queues_for_test(per_thread);
        let before = crate::gpu::metal_sumcheck_stats().1;
        let h0 = if per_thread { Some(crate::gpu::gpu_timeline_start()) } else { None };
        let t = std::time::Instant::now();
        let got: Vec<String> = std::thread::scope(|s| {
            let hs: Vec<_> = (0..6)
                .map(|_| {
                    let (sh, blk, w) = (&sh, &blk, copy(&w));
                    s.spawn(move || seeded_digest(sh, blk, w))
                })
                .collect();
            hs.into_iter().map(|h| h.join().expect("a proof thread")).collect()
        });
        let wall = t.elapsed().as_secs_f64();
        let ran = crate::gpu::metal_sumcheck_stats().1 - before;
        eprintln!("A7-QUEUES {} queues {q}: six concurrent seeded proofs in {wall:.2} s (device sumcheck rounds {ran:.4} s); digests {:?}", sh.name, got.iter().map(|d| &d[..8]).collect::<Vec<_>>());
        for d in &got {
            assert_eq!(d, &cpu, "a concurrent Metal W16R2 rung proof at {q} queues differs from the CPU's");
        }
        assert!(ran > 0.0, "no sumcheck round ran on the device");
        if let Some(h0) = h0 {
            let spans = crate::gpu::gpu_timeline_take();
            eprintln!("A7-QUEUES timeline at {q} queues:\n{}", crate::gpu::gpu_timeline_report(&spans, h0, h0 + wall));
            assert!(spans.len() > 6, "the timeline recorded {} command buffers", spans.len());
            let eps = 1e-3;
            for s in &spans {
                assert!(s.begin <= s.committed + eps && s.committed <= s.gpu_start + eps && s.gpu_start <= s.gpu_end && s.gpu_end <= s.done + eps, "a command buffer's times are out of order: {s:?}");
                assert!(s.begin >= h0 - eps && s.done <= h0 + wall + eps, "a command buffer outside the window: {s:?}");
            }
            // every thread on its own queue, and the six proof threads on six
            let mut pairs: Vec<(u32, u32)> = spans.iter().filter(|s| s.tag != "wprod").map(|s| (s.thread, s.queue)).collect();
            pairs.sort();
            pairs.dedup();
            let mut queues: Vec<u32> = pairs.iter().map(|p| p.1).collect();
            queues.dedup();
            assert!(pairs.iter().all(|&(t, q)| q == t + 1), "a thread's command buffers were not on its own queue: {pairs:?}");
            assert!(queues.len() >= 6, "six proof threads used the queues {queues:?}");
        }
    }
    crate::gpu::metal_set_queues_for_test(own);
    std::env::remove_var("HL_GPU");
}

// ------------------------------------------------- the PCS-level control rig

/// One commitment at a given PCS geometry, under a profile's hash tag, with
/// four data rows, one site mask row and the proximity mask row, and one
/// masked sum claim over the data rows and the site row (its row weights are
/// 1 on rows 0..=4). The verifier is `zkp_core::pcs::verify_zk_tagged`, on a
/// transcript under the profile's key that has absorbed the root.
struct Rig {
    sh: Shape,
    params: PcsParams,
    zko: ZkOpts,
    tag: HashTag,
    ntt: NttTables,
}

const DATA_ROWS: usize = 4;
const ROWS: usize = DATA_ROWS + 2;

impl Rig {
    fn at(sh: &Shape, params: PcsParams, q_pad: usize) -> Rig {
        Rig { sh: sh.clone(), params, zko: ZkOpts { q_pad, coset: Fp::new(7) }, tag: sh.hash_tag(), ntt: NttTables::new(params.log_cols + params.inv_rate.trailing_zeros()) }
    }
    /// the profile's own regular-commitment geometry
    fn profile(sh: &Shape) -> Rig {
        let p = protocol::pcs_params_at(sh);
        Rig::at(sh, p, ZkOpts::standard(&p).q_pad)
    }
    fn n(&self) -> usize {
        self.params.cols()
    }
    fn nn(&self) -> usize {
        self.params.enc_cols()
    }
    /// `(1 - (e + 1)/N)^Q` at this rig's geometry (unique decoding)
    fn bound(&self) -> f64 {
        2f64.powf(shape::column_term_log2(ColumnRegime::UniqueDecoding, self.params.log_cols as usize, self.params.inv_rate, self.params.num_col_checks))
    }
    /// `K = n + q_pad`, the dimension of the row code
    fn k(&self) -> usize {
        self.n() + self.zko.q_pad
    }
    /// `e = floor((N - K)/2)`, `K = n + q_pad`
    fn e(&self) -> usize {
        (self.nn() - self.k()) / 2
    }
    fn matrix(&self, seed: u64) -> Vec<Fp> {
        let n = self.n();
        let mut rng = ZkRng::new(seed, b"w16r2 control matrix");
        let mut d: Vec<Fp> = (0..DATA_ROWS * n).map(|_| Fp::from_i64((rng.fp().0 % 256) as i64 - 128)).collect();
        d.extend(rng.fp_vec(2 * n));
        d
    }
    fn claim(&self, data: &[Fp]) -> ZClaim {
        let (n, ln) = (self.n(), self.params.log_cols);
        let value = data[..(DATA_ROWS + 1) * n].iter().fold(Fp::ZERO, |a, x| a.add(*x));
        ZClaim {
            parts: vec![
                ZPart { slice: Slice { offset: 0, log_size: ln + DATA_ROWS.trailing_zeros() }, coef: Fp2::ONE, point: vec![] },
                ZPart { slice: Slice { offset: DATA_ROWS * n, log_size: ln }, coef: Fp2::ONE, point: vec![] },
            ],
            value: Fp2::new(value, Fp::ZERO),
        }
    }
    fn commit(&self, data: Vec<Fp>, seed: u64) -> CommittedZk<NoExternal> {
        let mut rng = ZkRng::new(seed, b"w16r2 control commit");
        let mut c = zpcs::commit_zk_owned_with_tag(&zpcs::Cpu, &self.params, data, &self.ntt, &self.zko, &mut rng, &self.tag);
        c.mask_rows = vec![DATA_ROWS];
        c.prox_mask_row = Some(DATA_ROWS + 1);
        c
    }
    fn transcript(&self, root: &[u8; 32]) -> Transcript {
        let mut tr = protocol::tagged_transcript(&self.sh, b"zk60 W16R2 pcs control");
        tr.absorb(b"root", root);
        tr
    }
    fn verify(&self, com: &Commitment, claims: &[ZClaim], o: &OpeningZk) -> Result<(), String> {
        let mut vt = self.transcript(&com.root);
        zpcs::verify_zk_tagged(&self.params, &self.zko, com, claims, o, &self.ntt, &mut vt, &self.tag)
    }
}

/// re-hash the host store's columns into the tree under the tag (after the
/// encoded matrix was edited): the salts stay the commitment's own
fn reroot(c: &mut CommittedZk<NoExternal>, tag: &HashTag) {
    let (rows, nn) = (c.cm.rows, c.cm.params.enc_cols());
    let Store::Host { encoded } = &c.cm.store else { panic!("a CPU commitment") };
    let leaves = zpcs::hash_columns_keyed(encoded, rows, nn, tag.column_key());
    let salted = leaves.iter().zip(c.salts.iter()).map(|(l, s)| zpcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    c.cm.tree = MerkleTree::build_keyed(salted, tag.node_key());
}

/// a FAR matrix: row 0 of every listed encoded column moved by a nonzero
/// value, then committed (re-rooted). The data, pads and salts are the
/// honest ones, so the honest clear vectors are what a cheater sends.
fn corrupt(c: &mut CommittedZk<NoExternal>, tag: &HashTag, cols: &[usize], seed: u64) {
    let mut rng = ZkRng::new(seed, b"w16r2 control corrupt");
    let Store::Host { encoded } = &mut c.cm.store else { panic!("a CPU commitment") };
    for &j in cols {
        let mut d = rng.fp();
        if d.is_zero() {
            d = Fp::ONE;
        }
        encoded[j] = encoded[j].add(d);
    }
    reroot(c, tag);
}

/// `k` distinct column indices in `[0, nn)`, from a seed (chosen with no
/// transcript at all)
fn distinct_columns(k: usize, nn: usize, seed: u64) -> Vec<usize> {
    let mut rng = ZkRng::new(seed, b"w16r2 control columns");
    let mut all: Vec<usize> = (0..nn).collect();
    for i in 0..k {
        let j = i + (rng.fp().0 as usize) % (nn - i);
        all.swap(i, j);
    }
    all.truncate(k);
    all
}

/// What a cheating opener does differently from `zkp_core::pcs::open_zk`.
#[derive(Default, Clone)]
struct Cheat {
    /// added to the first PAD entry of the group vector (`v[n]`)
    group_pad: Option<Fp2>,
    /// added to the first pad entry of the proximity vector
    prox_pad: Option<Fp2>,
    /// open THESE columns instead of the ones the transcript draws
    preset: Option<Vec<usize>>,
    /// open as if row 0 of `[data | pads]` were moved by THIS whole vector
    /// (`n + q` entries): each clear vector moves by its own row-0 weight
    /// times it (`lambda` for the group vector, `rho_0` for the proximity
    /// vector) — control (f)'s close-case cheater and control (d)'s
    /// forgeries (review F1)
    row0_shift: Option<Vec<Fp>>,
}

/// `open_zk`'s transcript order, written out so a cheater can deviate: the
/// group's lambda, the proximity rho, `rho^T [data | pads]` for both, the
/// two absorbs, the indices, the columns with their salts and paths. With
/// `Cheat::default()` it reproduces `open_zk` byte for byte (asserted by the
/// controls before any cheat is used).
fn open_as(c: &CommittedZk<NoExternal>, tr: &mut Transcript, cheat: &Cheat) -> (OpeningZk, Vec<usize>, [Vec<Fp2>; 2]) {
    let (rows, n, q, nn) = (c.cm.rows, c.cm.params.cols(), c.zk.q_pad, c.cm.params.enc_cols());
    let lam = tr.challenge_fp2_vec(1)[0];
    let rho_g: Vec<Fp2> = (0..rows).map(|i| if i <= DATA_ROWS { lam } else { Fp2::ZERO }).collect();
    let rho_p = tr.challenge_fp2_vec(rows);
    let fold = |rho: &[Fp2]| -> Vec<Fp2> {
        let mut v = vec![Fp2::ZERO; n + q];
        for i in 0..rows {
            for j in 0..n {
                v[j] = v[j].add(rho[i].mul_base(c.data[i * n + j]));
            }
            for k in 0..q {
                v[n + k] = v[n + k].add(rho[i].mul_base(c.pads[i * q + k]));
            }
        }
        v
    };
    let (mut g, mut p) = (fold(&rho_g), fold(&rho_p));
    if let Some(d) = cheat.group_pad {
        g[n] = g[n].add(d);
    }
    if let Some(d) = cheat.prox_pad {
        p[n] = p[n].add(d);
    }
    if let Some(d) = &cheat.row0_shift {
        assert_eq!(d.len(), n + q, "a row-0 shift is one whole clear vector");
        for (k, x) in d.iter().enumerate() {
            g[k] = g[k].add(rho_g[0].mul_base(*x));
            p[k] = p[k].add(rho_p[0].mul_base(*x));
        }
    }
    tr.absorb_fp2(b"pcs-vec", &g);
    tr.absorb_fp2(b"pcs-prox", &p);
    let drawn = tr.challenge_indices(c.cm.params.num_col_checks, nn);
    let idx = cheat.preset.clone().unwrap_or_else(|| drawn.clone());
    let Store::Host { encoded } = &c.cm.store else { panic!("a CPU commitment") };
    let columns = idx.iter().map(|&j| (j, (0..rows).map(|i| encoded[i * nn + j]).collect(), c.salts[j], c.cm.tree.path(j))).collect();
    (OpeningZk { group_vecs: vec![g], prox_vec: p, columns }, drawn, [rho_g, rho_p])
}

fn bytes_of(o: &OpeningZk) -> Vec<u8> {
    let mut b = Vec::new();
    o.write_bytes(&mut b);
    b
}

/// the replica opener IS `open_zk` when nothing is cheated (at this rig)
fn assert_the_replica_is_open_zk(rig: &Rig, seed: u64) {
    let data = rig.matrix(seed);
    let claims = [rig.claim(&data)];
    let c = rig.commit(data, seed);
    let root = c.commitment().root;
    let real = zpcs::open_zk(&c, &claims, &mut rig.transcript(&root));
    let (mine, _, _) = open_as(&c, &mut rig.transcript(&root), &Cheat::default());
    assert_eq!(bytes_of(&real), bytes_of(&mine), "the replica opener is not open_zk");
    rig.verify(&c.commitment(), &claims, &mine).expect("the honest replica opening verifies");
}

// ------------------------------------------------------------ control (a)

/// **D59 control (a): a far matrix.** A cheater commits a matrix whose
/// encoded rows are NOT close to codewords — `e + 1` columns off the honest
/// encoding, `e = floor((N - K)/2)`, i.e. just beyond the unique-decoding
/// radius the lemma counts at — and opens the honest clear vectors. At the
/// W16R2 profile's own geometry (`n = 2^14`, `N = 2^15`,
/// `Q = W16R2_OPENED_COLS`, its keys) the verifier must reject at the column
/// test; the miss probability is `(1 - (e+1)/N)^Q` (2^-113.93 at `Q = 280`).
/// Then at a toy rate-1/2 geometry (`n = 16`, `N = 32`, `Q = 4`, `e = 6`)
/// where that probability is 0.373, the empirical acceptance rate must sit
/// at the bound (for this attack the bound is exact) within 5 sigma; review
/// F7: 40,000 seeds (the first 4,000 sat 2 sigma low).
#[test]
fn w16r2_control_a_a_far_matrix_is_rejected_at_the_column_test() {
    let sh = built(shape::W16R2_RUNG_H24);
    let rig = Rig::profile(&sh);
    let (q, n) = (shape::W16R2_OPENED_COLS, 1usize << shape::W16R2_LOG_COLS);
    let nn = n * shape::W16R2_INV_RATE;
    assert_eq!((rig.n(), rig.nn(), rig.zko.q_pad, rig.e()), (n, nn, q, (nn - n - q) / 2));
    assert_the_replica_is_open_zk(&rig, 1);
    let data = rig.matrix(2);
    let claims = [rig.claim(&data)];
    let mut c = rig.commit(data, 2);
    let far = distinct_columns(rig.e() + 1, rig.nn(), 3);
    corrupt(&mut c, &rig.tag, &far, 4);
    let root = c.commitment().root;
    let (o, drawn, _) = open_as(&c, &mut rig.transcript(&root), &Cheat::default());
    let hit = drawn.iter().filter(|j| far.contains(j)).count();
    let e = rig.verify(&c.commitment(), &claims, &o).expect_err("CONTROL (a): A FAR MATRIX WAS ACCEPTED");
    assert!(e.contains("disagrees with clear vector"), "{e}");
    eprintln!("W16R2 control (a) far matrix ({} of {} columns off the code, e = {}), {hit} of {} sampled columns in the far set: REJECTED: {e}", far.len(), rig.nn(), rig.e(), drawn.len());
    // the same rejection at the W16R2 8B profile's keys (the same geometry)
    let rig8 = Rig::profile(&built(shape::W16R2_8B_T128_H24));
    let data = rig8.matrix(5);
    let claims = [rig8.claim(&data)];
    let mut c = rig8.commit(data, 5);
    corrupt(&mut c, &rig8.tag, &distinct_columns(rig8.e() + 1, rig8.nn(), 6), 7);
    let (o, _, _) = open_as(&c, &mut rig8.transcript(&c.commitment().root), &Cheat::default());
    let e = rig8.verify(&c.commitment(), &claims, &o).expect_err("CONTROL (a) at the 8B keys: ACCEPTED");
    assert!(e.contains("disagrees with clear vector"), "{e}");
    // THE MEASURABLE GEOMETRY
    let toy = Rig::at(&sh, PcsParams { log_cols: 4, inv_rate: 2, num_col_checks: 4 }, 4);
    assert_eq!((toy.n(), toy.nn(), toy.e()), (16, 32, 6));
    assert_the_replica_is_open_zk(&toy, 8);
    let trials = 40_000u64;
    let mut accepted = 0u64;
    for t in 0..trials {
        let data = toy.matrix(100 + t);
        let claims = [toy.claim(&data)];
        let mut c = toy.commit(data, 100 + t);
        corrupt(&mut c, &toy.tag, &distinct_columns(toy.e() + 1, toy.nn(), 20_000 + t), 40_000 + t);
        let (o, _, _) = open_as(&c, &mut toy.transcript(&c.commitment().root), &Cheat::default());
        accepted += u64::from(toy.verify(&c.commitment(), &claims, &o).is_ok());
    }
    let (rate, bound) = (accepted as f64 / trials as f64, toy.bound());
    let sigma = (bound * (1.0 - bound) / trials as f64).sqrt();
    eprintln!("W16R2 control (a) toy rate 1/2 (n 16, N 32, Q 4, e 6): {accepted} of {trials} far matrices accepted = {rate:.4}; the lemma's (1 - (e+1)/N)^Q = {bound:.4} (sigma {sigma:.4})");
    assert!(rate <= bound + 5.0 * sigma, "the far-matrix acceptance rate {rate} exceeds the lemma's bound {bound}");
    assert!(rate >= bound - 5.0 * sigma, "the far-matrix acceptance rate {rate} is far below the exact rate {bound}: the rig does not model the attack");
}

// ------------------------------------------------------------ control (b)

/// **D59 control (b): a wrong opened column.** At the profile geometry: a
/// sampled column whose entries are not the committed ones (Merkle), and a
/// committed column (valid path) at an index the transcript did not draw.
/// Then on a REAL W16R2 rung block proof, both edits on `A` and on `H`.
#[test]
fn w16r2_control_b_a_wrong_opened_column_is_rejected() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    let rig = Rig::profile(&sh);
    let data = rig.matrix(11);
    let claims = [rig.claim(&data)];
    let c = rig.commit(data, 11);
    let root = c.commitment().root;
    let (honest, drawn, _) = open_as(&c, &mut rig.transcript(&root), &Cheat::default());
    rig.verify(&c.commitment(), &claims, &honest).expect("the honest opening");
    let mut o = honest.clone();
    o.columns[0].1[2] = o.columns[0].1[2].add(Fp::ONE);
    let e = rig.verify(&c.commitment(), &claims, &o).expect_err("CONTROL (b): AN EDITED COLUMN WAS ACCEPTED");
    assert!(e.contains("Merkle path"), "{e}");
    eprintln!("W16R2 control (b) an opened column with one entry changed: REJECTED: {e}");
    let other = (0..rig.nn()).find(|j| !drawn.contains(j)).unwrap();
    let mut o = honest.clone();
    let Store::Host { encoded } = &c.cm.store else { panic!() };
    o.columns[0] = (other, (0..ROWS).map(|i| encoded[i * rig.nn() + other]).collect(), c.salts[other], c.cm.tree.path(other));
    let e = rig.verify(&c.commitment(), &claims, &o).expect_err("CONTROL (b): A COMMITTED COLUMN AT AN UNDRAWN INDEX WAS ACCEPTED");
    assert!(e.contains("!= sampled"), "{e}");
    eprintln!("W16R2 control (b) a committed column (valid path) at an undrawn index: REJECTED: {e}");
    // a real block proof
    let core = prove(&sh, &blk, w).unwrap();
    verify(&sh, &blk, &core).expect("the honest W16R2 rung core");
    for which in ["A", "H"] {
        let mut bad = CoreProof { slots: core.slots.clone(), mask_open: core.mask_open.clone(), a_open: core.a_open.clone(), h_open: core.h_open.clone(), io_claims: core.io_claims.clone(), order: core.order.clone(), ..core };
        let o = if which == "A" { &mut bad.a_open } else { &mut bad.h_open };
        o.columns[0].1[0] = o.columns[0].1[0].add(Fp::ONE);
        let e = verify(&sh, &blk, &bad).expect_err("CONTROL (b): AN EDITED BLOCK COLUMN WAS ACCEPTED");
        assert!(e.starts_with(&format!("{which}: pcs zk: Merkle path")), "{e}");
        eprintln!("W16R2 control (b) rung block, one {which} column entry changed: REJECTED: {e}");
        let mut bad = CoreProof { slots: core.slots.clone(), mask_open: core.mask_open.clone(), a_open: core.a_open.clone(), h_open: core.h_open.clone(), io_claims: core.io_claims.clone(), order: core.order.clone(), ..core };
        let o = if which == "A" { &mut bad.a_open } else { &mut bad.h_open };
        let k = (1..o.columns.len()).find(|&k| o.columns[k].0 != o.columns[0].0).unwrap();
        o.columns.swap(0, k);
        let e = verify(&sh, &blk, &bad).expect_err("CONTROL (b): SWAPPED BLOCK COLUMNS WERE ACCEPTED");
        assert!(e.starts_with(&format!("{which}: pcs zk: column index")), "{e}");
        eprintln!("W16R2 control (b) rung block, two {which} columns (each with its valid path) swapped: REJECTED: {e}");
    }
}

// ------------------------------------------------------------ control (c)

/// **D59 control (c): a column set chosen before the challenge.** The
/// cheater fixes `Q` column indices with no transcript at all, commits a
/// matrix that is honest on exactly those columns and off the code
/// everywhere else (far: `N - Q` columns), and opens its own set. Every
/// per-column check passes on that set (shown with the verifier's own
/// algebra: Merkle path under the keys, and `rho^T column = Enc(v)[j]` for
/// both vectors), so the ONLY objection is that the indices are not the
/// transcript's: the verifier must reject at the index check.
#[test]
fn w16r2_control_c_a_column_set_chosen_before_the_challenge_is_rejected() {
    let sh = built(shape::W16R2_RUNG_H24);
    let rig = Rig::profile(&sh);
    let q = rig.params.num_col_checks;
    let preset = distinct_columns(q, rig.nn(), 21);
    let data = rig.matrix(22);
    let claims = [rig.claim(&data)];
    let mut c = rig.commit(data, 22);
    let rest: Vec<usize> = (0..rig.nn()).filter(|j| !preset.contains(j)).collect();
    corrupt(&mut c, &rig.tag, &rest, 23);
    let com = c.commitment();
    let (o, drawn, [rho_g, rho_p]) = open_as(&c, &mut rig.transcript(&com.root), &Cheat { preset: Some(preset.clone()), ..Cheat::default() });
    // THE POSITIVE CONTROL: on its own set, every column check passes
    let pows = zpcs::coset_powers(rig.zko.coset, rig.nn());
    let enc = |v: &[Fp2]| -> (Vec<Fp>, Vec<Fp>) {
        let n = rig.n();
        let re: Vec<Fp> = v.iter().map(|x| x.c0).collect();
        let im: Vec<Fp> = v.iter().map(|x| x.c1).collect();
        let (mut a, mut b) = (vec![Fp::ZERO; rig.nn()], vec![Fp::ZERO; rig.nn()]);
        zpcs::encode_row_zk(&rig.ntt, &re[..n], &re[n..], &pows, &mut a);
        zpcs::encode_row_zk(&rig.ntt, &im[..n], &im[n..], &pows, &mut b);
        (a, b)
    };
    let encs = [enc(&o.group_vecs[0]), enc(&o.prox_vec)];
    for (j, col, salt, path) in &o.columns {
        let leaf = zpcs::salt_leaf_keyed(&zpcs::hash_columns_keyed(col, col.len(), 1, rig.tag.column_key())[0], salt, rig.tag.leaf_key());
        assert!(MerkleTree::verify_path_keyed(&com.root, *j, &leaf, path, rig.tag.node_key()), "a preset column's path fails");
        for (rho, (re, im)) in [&rho_g, &rho_p].into_iter().zip(encs.iter()) {
            let acc = (0..ROWS).fold(Fp2::ZERO, |a, i| a.add(rho[i].mul_base(col[i])));
            assert_eq!(acc, Fp2::new(re[*j], im[*j]), "a preset column disagrees with a clear vector: the positive control is broken");
        }
    }
    let caught = drawn.iter().filter(|j| !preset.contains(j)).count();
    let e = rig.verify(&com, &claims, &o).expect_err("CONTROL (c): A PRE-CHOSEN COLUMN SET WAS ACCEPTED");
    assert!(e.contains("!= sampled"), "{e}");
    eprintln!("W16R2 control (c) {q} columns chosen before any challenge, the matrix honest on them and off the code on the other {} (every per-column check passes on the preset: positive control); {caught} of the {q} transcript-drawn columns are off the code: REJECTED: {e}", rest.len());
}

// ------------------------------------------- the close-case machinery (F1)

/// The evaluation point of each encoded column at `rig`'s geometry: column
/// `j` of `encode_row_zk` is `f(h w^j)`, `h` the coset generator and `w` the
/// size-`N` root `NttTables::forward` evaluates at (natural order; the
/// tables' top root to the power `2^max_log / N`). Checked, not assumed:
/// [`close_case`] asserts that a polynomial built from these points vanishes
/// exactly where it was built to, through the production encoder.
fn coset_points(rig: &Rig) -> Vec<Fp> {
    let (nn, top) = (rig.nn(), rig.ntt.max_log as usize);
    let w = rig.ntt.roots[top].pow(((1usize << top) / nn) as u64);
    let mut x = rig.zko.coset;
    (0..nn)
        .map(|_| {
            let v = x;
            x = x.mul(w);
            v
        })
        .collect()
}

/// `prod_{j in at} (X - xs[j])`, coefficients lowest first
fn vanishing_on(xs: &[Fp], at: &[usize]) -> Vec<Fp> {
    let mut c = Vec::with_capacity(at.len() + 1);
    c.push(Fp::ONE);
    for &j in at {
        let x = xs[j];
        c.push(Fp::ZERO);
        for i in (1..c.len()).rev() {
            c[i] = c[i - 1].sub(c[i].mul(x));
        }
        c[0] = c[0].mul(x).neg();
    }
    c
}

/// the `N` coset evaluations of a polynomial of degree `< N` (coefficients
/// lowest first): `encode_row_zk`'s last two steps
fn coset_evals(rig: &Rig, coeffs: &[Fp]) -> Vec<Fp> {
    let pows = zpcs::coset_powers(rig.zko.coset, rig.nn());
    let mut out = vec![Fp::ZERO; rig.nn()];
    for (i, c) in coeffs.iter().enumerate() {
        out[i] = c.mul(pows[i]);
    }
    rig.ntt.forward(&mut out);
    out
}

/// `encode_row_zk` of one base-field clear vector `[message | pads]`
fn encode_vec(rig: &Rig, v: &[Fp]) -> Vec<Fp> {
    let n = rig.n();
    let pows = zpcs::coset_powers(rig.zko.coset, rig.nn());
    let mut out = vec![Fp::ZERO; rig.nn()];
    zpcs::encode_row_zk(&rig.ntt, &v[..n], &v[n..], &pows, &mut out);
    out
}

/// A polynomial of degree `< K = n + q` as the clear vector
/// `[message | pads]` whose `encode_row_zk` it is. The encoder writes
/// `f = f_data + (X^n - 1) g` with `f_data` the message's interpolant on
/// `G_n` and `g` the pads as coefficients, so `g = f[n..n+q]`,
/// `f_data = f[..n] + g` (on the low `q` coefficients), and the message is
/// `f_data` on `G_n`.
fn as_clear_vector(rig: &Rig, f: &[Fp]) -> Vec<Fp> {
    let (n, q) = (rig.n(), rig.zko.q_pad);
    assert!(f.len() <= n + q && q <= n, "a polynomial of {} coefficients is not below K = {}", f.len(), n + q);
    let mut f = f.to_vec();
    f.resize(n + q, Fp::ZERO);
    let pads = f[n..].to_vec();
    let mut msg = f[..n].to_vec();
    for (m, p) in msg.iter_mut().zip(pads.iter()) {
        *m = m.add(*p);
    }
    rig.ntt.forward(&mut msg);
    msg.extend(pads);
    msg
}

/// **THE POSITIVE CONTROL'S MEASUREMENT:** every encoded column at which
/// either clear vector of `o` disagrees with `rho^T U`, `U` the COMMITTED
/// encoded matrix — the columns `verify_zk_tagged` objects to when it draws
/// one, computed over all `N` with the verifier's own algebra
fn disagreeing_columns(rig: &Rig, c: &CommittedZk<NoExternal>, o: &OpeningZk, rhos: &[Vec<Fp2>; 2]) -> Vec<usize> {
    let (rows, nn) = (c.cm.rows, rig.nn());
    let Store::Host { encoded } = &c.cm.store else { panic!("a CPU commitment") };
    let enc2 = |v: &[Fp2]| -> (Vec<Fp>, Vec<Fp>) {
        let re: Vec<Fp> = v.iter().map(|x| x.c0).collect();
        let im: Vec<Fp> = v.iter().map(|x| x.c1).collect();
        (encode_vec(rig, &re), encode_vec(rig, &im))
    };
    let encs = [enc2(&o.group_vecs[0]), enc2(&o.prox_vec)];
    (0..nn)
        .filter(|&j| {
            rhos.iter().zip(encs.iter()).any(|(rho, (re, im))| {
                let acc = (0..rows).fold(Fp2::ZERO, |a, i| a.add(rho[i].mul_base(encoded[i * nn + j])));
                acc != Fp2::new(re[j], im[j])
            })
        })
        .collect()
}

/// a CLOSE matrix: row 0 of every listed encoded column moved by `by[j]`,
/// then committed (re-rooted); the data, pads and salts are the honest ones
fn shift_row0(c: &mut CommittedZk<NoExternal>, tag: &HashTag, cols: &[usize], by: &[Fp]) {
    let Store::Host { encoded } = &mut c.cm.store else { panic!("a CPU commitment") };
    for &j in cols {
        encoded[j] = encoded[j].add(by[j]);
    }
    reroot(c, tag);
}

/// **The lemma's close case at one geometry** (the review's
/// `review_logs/close_case_attack.py`, in the zkp-core encoder's own
/// convention): the `N` columns split at random into `Z` (`K - 1` of them),
/// `S` (`s_len`) and `R` (the rest, `N - K + 1 - s_len`), and
/// `D0 = prod_{z in Z} (X - x_z)`, the codeword of degree `K - 1` that
/// vanishes on `Z` and nowhere else.
struct CloseCase {
    s: Vec<usize>,
    /// sorted
    r: Vec<usize>,
    /// `D0` on the coset (zero exactly on `Z`)
    d0: Vec<Fp>,
    /// `D0` as a clear vector `[message | pads]` (`n + q` entries)
    dec: Vec<Fp>,
}

fn close_case(rig: &Rig, xs: &[Fp], s_len: usize, seed: u64) -> CloseCase {
    let (nn, k) = (rig.nn(), rig.k());
    let perm = distinct_columns(nn, nn, seed);
    let (z, rest) = perm.split_at(k - 1);
    let (s, r) = rest.split_at(s_len);
    let coeffs = vanishing_on(xs, z);
    assert_eq!(coeffs.len(), k, "D0 is not of degree K - 1");
    let d0 = coset_evals(rig, &coeffs);
    let mut zs = z.to_vec();
    zs.sort_unstable();
    let zeros: Vec<usize> = (0..nn).filter(|&j| d0[j].is_zero()).collect();
    assert_eq!(zeros, zs, "D0 does not vanish exactly on Z: these are not the encoder's evaluation points");
    let dec = as_clear_vector(rig, &coeffs);
    assert_eq!(encode_vec(rig, &dec), d0, "dec(D0) does not encode to D0 under encode_row_zk's convention");
    let mut r = r.to_vec();
    r.sort_unstable();
    CloseCase { s: s.to_vec(), r, d0, dec }
}

/// One attempt of the close-case cheater (control (f)), or, with `S` empty,
/// of the max-agreement forger against an honest matrix (control (d)), at
/// `rig`: a fresh honest matrix, its row 0 moved by `D0` on `S` and
/// committed; a FALSE claim (the true value plus `<dec(D0)[..n], 1>`, which
/// the moved group vector satisfies); both clear vectors moved by their
/// row-0 weight times `dec(D0)`, absorbed, the drawn columns opened. Returns
/// the verifier's verdict, the positive control (every column where a clear
/// vector disagrees with `rho^T U`) and the drawn indices.
fn close_attempt(rig: &Rig, cc: &CloseCase, seed: u64) -> (Result<(), String>, Vec<usize>, Vec<usize>) {
    let n = rig.n();
    let data = rig.matrix(seed);
    let mut claim = rig.claim(&data);
    let t0 = cc.dec[..n].iter().fold(Fp::ZERO, |a, x| a.add(*x));
    assert!(!t0.is_zero(), "<dec(D0), 1> is zero: the moved claim would be the true one");
    claim.value = claim.value.add(Fp2::from_base(t0));
    let mut c = rig.commit(data, seed);
    if !cc.s.is_empty() {
        shift_row0(&mut c, &rig.tag, &cc.s, &cc.d0);
    }
    let com = c.commitment();
    let (o, drawn, rhos) = open_as(&c, &mut rig.transcript(&com.root), &Cheat { row0_shift: Some(cc.dec.clone()), ..Cheat::default() });
    let bad = disagreeing_columns(rig, &c, &o, &rhos);
    (rig.verify(&com, &[claim], &o), bad, drawn)
}

/// `(rate, sigma)` of `accepted` of `trials` against an exact probability
fn rate_and_sigma(accepted: u64, trials: u64, exact: f64) -> (f64, f64) {
    (accepted as f64 / trials as f64, (exact * (1.0 - exact) / trials as f64).sqrt())
}

// ------------------------------------------------------------ control (d)

/// **D59 control (d): a forged clear vector against an honest matrix.** The
/// pads are message symbols of the row code (`K = n + Q`), so a clear
/// vector's pad entries are bound like its data entries. At the profile
/// geometry, and on a real block proof: the first pad entry of a clear
/// vector + 1 (which `<v[..n], c>` never reads, so the claim check passes),
/// absorbed and the columns redrawn, is rejected at the column test.
///
/// **Review F1 (iii): that edit measures nothing as a rate.** It moves the
/// encoding by `delta (x^n - 1)`, which is nonzero at EVERY point of the
/// coset, so its acceptance is exactly 0 — asserted as such below (all `N`
/// columns disagree), no longer as "below the bound". The forgeries whose
/// rates DO measure the column test, at the toy rate-1/2 geometry over
/// 20,000 seeds each, with the positive control (the disagreeing columns are
/// exactly the predicted set) on every seed:
/// * **the max-agreement forgery** (the review's fix): the honest matrix, a
///   FALSE claim, both clear vectors moved by `dec(D0)`, `D0` the codeword
///   vanishing on `K - 1` chosen columns: accepted at exactly
///   `((K - 1)/N)^Q` (0.1243 at the toy), within 5 sigma both ways;
/// * **the best PAD-ONLY forgery**: the pad halves moved by `delta`,
///   `delta = prod (X - x_z)` over `q - 1` chosen columns — the most zeros a
///   pad-only change can have, since `x^n - 1` has none on the coset — with
///   the (true) claim: accepted at exactly `((q - 1)/N)^Q` (7.7e-5 at the
///   toy, 1.5 expected acceptances), at most 5 sigma above.
///
/// At the profile geometry the max-agreement forgery is rejected too, its
/// exact rate printed from `W16R2_OPENED_COLS`.
#[test]
fn w16r2_control_d_a_forged_pad_half_is_rejected() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    let rig = Rig::profile(&sh);
    let n = rig.n();
    for (what, cheat, vec) in [
        ("the group vector's first pad entry + 1", Cheat { group_pad: Some(Fp2::ONE), ..Cheat::default() }, 0),
        ("the proximity vector's first pad entry + 1", Cheat { prox_pad: Some(Fp2::ONE), ..Cheat::default() }, 1),
    ] {
        let data = rig.matrix(31);
        let claims = [rig.claim(&data)];
        let c = rig.commit(data, 31);
        let (o, _, _) = open_as(&c, &mut rig.transcript(&c.commitment().root), &cheat);
        let e = rig.verify(&c.commitment(), &claims, &o).expect_err("CONTROL (d): A FORGED PAD HALF WAS ACCEPTED");
        assert!(e.contains(&format!("disagrees with clear vector {vec}")), "{e}");
        eprintln!("W16R2 control (d) {what} (absorbed, columns redrawn; the claim check passes): REJECTED: {e}");
    }
    // the max-agreement forgery at the profile geometry
    let (nn, k, q) = (rig.nn(), rig.k(), rig.zko.q_pad);
    assert_eq!((rig.params.num_col_checks, q), (shape::W16R2_OPENED_COLS, shape::W16R2_OPENED_COLS));
    let cc = close_case(&rig, &coset_points(&rig), 0, 32);
    let (v, bad, _) = close_attempt(&rig, &cc, 33);
    assert_eq!(bad, cc.r, "POSITIVE CONTROL: the max-agreement forgery does not fail exactly on the N - K + 1 columns outside Z");
    let e = v.expect_err("CONTROL (d): THE MAX-AGREEMENT FORGERY WAS ACCEPTED AT THE PROFILE");
    assert!(e.contains("disagrees with clear vector 0"), "{e}");
    eprintln!(
        "W16R2 control (d) profile geometry (n {n}, N {nn}, Q {q}, K {k}): the max-agreement forgery (honest U, a false claim, both vectors + dec(D0), D0 zero on K - 1 = {} columns) disagrees on exactly {} columns; accepted with probability ((K - 1)/N)^Q = 2^{:.3}: REJECTED: {e}",
        k - 1,
        bad.len(),
        q as f64 * ((k - 1) as f64 / nn as f64).log2()
    );
    // ---- the measurable geometry
    let toy = Rig::at(&sh, PcsParams { log_cols: 4, inv_rate: 2, num_col_checks: 4 }, 4);
    let (tn, tnn, tk, tq) = (toy.n(), toy.nn(), toy.k(), toy.zko.q_pad);
    assert_eq!((tn, tnn, tk, tq), (16, 32, 20, 4));
    let xs = coset_points(&toy);
    // (1) the +1 pad edit: every column disagrees, so the rate is exactly 0
    let mut accepted = 0u64;
    for t in 0..4000u64 {
        let data = toy.matrix(200 + t);
        let claims = [toy.claim(&data)];
        let c = toy.commit(data, 200 + t);
        let delta = Fp2::new(Fp::new(1 + t), Fp::new(t / 3));
        let (o, _, rhos) = open_as(&c, &mut toy.transcript(&c.commitment().root), &Cheat { group_pad: Some(delta), ..Cheat::default() });
        assert_eq!(disagreeing_columns(&toy, &c, &o, &rhos).len(), tnn, "toy seed {t}: a pad entry + delta agrees with the matrix at some column (x^n - 1 vanishes nowhere on the coset)");
        accepted += u64::from(toy.verify(&c.commitment(), &claims, &o).is_ok());
    }
    assert_eq!(accepted, 0, "a pad entry + delta was accepted although it disagrees at every column");
    eprintln!("W16R2 control (d) toy rate 1/2 (n 16, N 32, Q 4): the first pad entry + delta disagrees at all {tnn} columns on each of 4000 seeds, so it is accepted exactly never: {accepted} of 4000");
    let trials = 20_000u64;
    // (2) the max-agreement forgery
    let mut accepted = 0u64;
    for t in 0..trials {
        let cc = close_case(&toy, &xs, 0, 500_000 + t);
        let (v, bad, _) = close_attempt(&toy, &cc, 600_000 + t);
        assert_eq!(bad, cc.r, "toy seed {t}: POSITIVE CONTROL: the max-agreement forgery does not fail exactly outside Z");
        accepted += u64::from(v.is_ok());
    }
    let exact = ((tk - 1) as f64 / tnn as f64).powi(tq as i32);
    let (rate, sigma) = rate_and_sigma(accepted, trials, exact);
    eprintln!("W16R2 control (d) toy rate 1/2: the max-agreement forgery (both vectors + dec(D0), D0 zero on K - 1 = {} of {tnn} columns, a false claim): {accepted} of {trials} accepted = {rate:.4}; exact ((K - 1)/N)^Q = {exact:.4} (sigma {sigma:.4}; tolerance 5 sigma both ways)", tk - 1);
    assert!(rate <= exact + 5.0 * sigma, "the max-agreement forgery is accepted ABOVE its exact rate: the column test is weaker than counted");
    assert!(rate >= exact - 5.0 * sigma, "the max-agreement forgery is accepted BELOW its exact rate: the rig does not model it");
    // (3) the best pad-only forgery
    let mut accepted = 0u64;
    for t in 0..trials {
        let perm = distinct_columns(tnn, tnn, 700_000 + t);
        let (zp, rest) = perm.split_at(tq - 1);
        let mut shift = vec![Fp::ZERO; tn];
        shift.extend(vanishing_on(&xs, zp));
        let data = toy.matrix(800_000 + t);
        let claims = [toy.claim(&data)];
        let c = toy.commit(data, 800_000 + t);
        let (o, _, rhos) = open_as(&c, &mut toy.transcript(&c.commitment().root), &Cheat { row0_shift: Some(shift), ..Cheat::default() });
        let mut want = rest.to_vec();
        want.sort_unstable();
        assert_eq!(disagreeing_columns(&toy, &c, &o, &rhos), want, "toy seed {t}: POSITIVE CONTROL: the pad-only forgery does not agree on exactly its q - 1 chosen columns");
        accepted += u64::from(toy.verify(&c.commitment(), &claims, &o).is_ok());
    }
    let exact = ((tq - 1) as f64 / tnn as f64).powi(tq as i32);
    let (mean, sd) = (exact * trials as f64, (exact * (1.0 - exact) * trials as f64).sqrt());
    eprintln!("W16R2 control (d) toy rate 1/2: the best pad-only forgery (the pad halves + delta, delta zero on q - 1 = {} columns, the true claim): {accepted} of {trials} accepted; exact ((q - 1)/N)^Q = {exact:.3e}, {mean:.2} expected (sd {sd:.2}; tolerance 5 sd above)", tq - 1);
    assert!(accepted as f64 <= mean + 5.0 * sd, "the pad-only forgery is accepted above its exact rate: a pad half is not bound like a data half");
    // a real block proof
    let core = prove(&sh, &blk, w).unwrap();
    let mut bad = CoreProof { slots: core.slots.clone(), mask_open: core.mask_open.clone(), a_open: core.a_open.clone(), h_open: core.h_open.clone(), io_claims: core.io_claims.clone(), order: core.order.clone(), ..core };
    bad.a_open.group_vecs[0][n] = bad.a_open.group_vecs[0][n].add(Fp2::ONE);
    let e = verify(&sh, &blk, &bad).expect_err("CONTROL (d): A FORGED PAD ENTRY IN A BLOCK PROOF WAS ACCEPTED");
    assert!(e.starts_with("A: pcs zk"), "{e}");
    eprintln!("W16R2 control (d) rung block, A group vector 0's first pad entry + 1: REJECTED: {e}");
}

// ------------------------------------------------------------ control (e)

/// **D59 control (e): a receipt at another rate or `Q` under the W16R2
/// profile.** On real rung block proofs: the honest W16 (rate 1/4, `Q` 256)
/// proof of the same block handed to the W16R2 verifier; the honest W16R2
/// proof with one opened column dropped (`Q - 1`) or added (`Q + 1`), or
/// with its clear vectors cut to `n + 256` (256 pads, W16's count). At the
/// PCS level, honest openings genuinely made at rate 1/2 with `Q` 256, at
/// `Q - 1` with `Q` pads, and at rate 1/4 with `Q`, each handed to the
/// profile's verifier (`Q = W16R2_OPENED_COLS` throughout since the review
/// of 2026-11-02). Every one is rejected, because the verifier's rate and
/// `Q` are the profile's and the receipt carries no say in them.
#[test]
fn w16r2_control_e_a_receipt_at_another_rate_or_q_is_rejected() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    let (s4, b4, w4) = rung_case(shape::W16_RUNG_H24);
    let quarter = prove(&s4, &b4, w4).unwrap();
    verify(&s4, &b4, &quarter).expect("the honest W16 rung core verifies under its own profile");
    let e = verify(&sh, &blk, &quarter).expect_err("CONTROL (e): A RATE-1/4 RECEIPT VERIFIED UNDER W16R2");
    assert!(e.contains("Merkle path of 16 entries") && e.contains("15 deep"), "{e}");
    eprintln!("W16R2 control (e) the honest rate-1/4 (Q 256) W16 proof of the same block under the W16R2 verifier: REJECTED: {e}");
    let core = prove(&sh, &blk, w).unwrap();
    let n = 1usize << sh.log_cols;
    let edits: [(&str, fn(&mut OpeningZk, usize), &str); 3] = [
        ("one A column dropped (Q - 1)", |o, _| { o.columns.pop(); }, "A: pcs zk: wrong number of columns"),
        ("one A column added (Q + 1)", |o, _| { let c = o.columns[0].clone(); o.columns.push(c); }, "A: pcs zk: wrong number of columns"),
        ("every A clear vector cut to n + 256 (256 pads)", |o, n| { for v in o.group_vecs.iter_mut() { v.truncate(n + 256); } o.prox_vec.truncate(n + 256); }, "A: pcs zk: group vector 0 has length 16640"),
    ];
    for (what, edit, want) in edits {
        let mut bad = CoreProof { slots: core.slots.clone(), mask_open: core.mask_open.clone(), a_open: core.a_open.clone(), h_open: core.h_open.clone(), io_claims: core.io_claims.clone(), order: core.order.clone(), ..core };
        edit(&mut bad.a_open, n);
        let e = verify(&sh, &blk, &bad).expect_err("CONTROL (e): A RECEIPT WITH ANOTHER Q VERIFIED");
        assert!(e.starts_with(want), "{what}: {e}");
        eprintln!("W16R2 control (e) rung block, {what}: REJECTED: {e}");
    }
    verify(&sh, &blk, &core).expect("the unedited W16R2 core verifies");
    // genuinely re-proved openings at another geometry, under the W16R2 keys
    let rig = Rig::profile(&sh);
    let q = shape::W16R2_OPENED_COLS;
    for (what, params, q_pad, want) in [
        ("rate 1/2, Q 256, 256 pads".to_string(), PcsParams { log_cols: 14, inv_rate: 2, num_col_checks: 256 }, 256, "group vector 0 has length 16640"),
        (format!("rate 1/2, Q {}, {q} pads", q - 1), PcsParams { log_cols: 14, inv_rate: 2, num_col_checks: q - 1 }, q, "wrong number of columns"),
        (format!("rate 1/4, Q {q}, {q} pads"), PcsParams { log_cols: 14, inv_rate: 4, num_col_checks: q }, q, "Merkle path of 16 entries"),
    ] {
        let other = Rig::at(&sh, params, q_pad);
        let data = other.matrix(41);
        let claims = [other.claim(&data)];
        let c = other.commit(data, 41);
        let com = c.commitment();
        let o = zpcs::open_zk(&c, &claims, &mut other.transcript(&com.root));
        other.verify(&com, &claims, &o).expect("the opening verifies at its own geometry");
        let e = rig.verify(&com, &claims, &o).expect_err("CONTROL (e): AN OPENING AT ANOTHER GEOMETRY VERIFIED UNDER W16R2");
        assert!(e.contains(want), "{what}: {e}");
        eprintln!("W16R2 control (e) an honest opening made at {what}, under the W16R2 profile's verifier: REJECTED: {e}");
    }
}

// ------------------------------------------------------------ control (f)

/// **D59 control (f) (review F1): THE LEMMA'S CLOSE CASE, which delta/2
/// makes load-bearing.** Under delta/3 the consistency half of the column
/// round was 2^-248; under delta/2 it equals the column term, and it is
/// ATTAINED (`review_logs/close_case_attack.py`):
///
/// 1. the cheater commits `U = Enc[M | P] + E`, `E` nonzero on row 0 only,
///    equal to `D0` on `e` columns `S` — so `U` is within the unique-decoding
///    radius — where `D0 = prod_{z in Z} (X - x_z)` over `K - 1` OTHER
///    columns `Z`;
/// 2. it opens `y_g = honest + lambda dec(D0)` and `y_p = honest + rho_0
///    dec(D0)`;
/// 3. it claims `value + <dec(D0)[..n], c>`, which is FALSE.
///
/// Both vectors then agree with `rho^T U` on `Z` (both sides zero) and on
/// `S` (both sides `D0`), and disagree on the `N - K + 1 - e` columns of `R`,
/// which is `e + 1` when `N - K` is even: the false claim is accepted with
/// probability EXACTLY `(1 - (e + 1)/N)^Q`, the lemma's count.
///
/// * **Profile geometry** (`n = 2^14`, `N = 2^15`, `Q = q_pad =
///   W16R2_OPENED_COLS`, at each W16R2 profile's keys): the positive control
///   — the columns where either vector disagrees with `rho^T U` are exactly
///   `R`, all `e + 1` of them — then `verify_zk_tagged` rejects at a column
///   of `R` with "disagrees with clear vector 0", and the per-opening
///   probability computed from the measured `R` equals the counted
///   `column_term_log2(UniqueDecoding, ..)`.
/// * **Toy rate-1/2 geometry** (`n = 16`, `N = 32`, `Q = 4`, `e = 6`), 20,000
///   seeds, the positive control on every one: the acceptance rate must lie
///   within 5 sigma of the exact `(1 - (e + 1)/N)^Q = 0.3725`. Above means
///   the lemma is broken; below means the rig does not model the attack.
#[test]
fn w16r2_control_f_the_lemmas_close_case_is_accepted_at_exactly_the_counted_rate() {
    // ---- the profile geometry
    let q = shape::W16R2_OPENED_COLS;
    let base = built(shape::W16R2_RUNG_H24);
    assert_eq!((base.log_cols, base.inv_rate, base.opened_cols), (shape::W16R2_LOG_COLS, shape::W16R2_INV_RATE, q));
    let rig = Rig::profile(&base);
    let (n, nn, k, e) = (rig.n(), rig.nn(), rig.k(), rig.e());
    assert_eq!(
        (n, nn, rig.params.num_col_checks, rig.zko.q_pad, k, e),
        (1 << base.log_cols, (1 << base.log_cols) * base.inv_rate, q, q, (1 << base.log_cols) + q, ((1 << base.log_cols) * (base.inv_rate - 1) - q) / 2),
        "the rig is not at the profile's own PCS geometry with q_pad = Q"
    );
    assert_the_replica_is_open_zk(&rig, 60);
    let t = std::time::Instant::now();
    let cc = close_case(&rig, &coset_points(&rig), e, 61);
    let build_s = t.elapsed().as_secs_f64();
    assert_eq!((cc.s.len(), cc.r.len()), (e, nn - (k - 1) - e));
    // the counted figure, and the one the measured R attains
    let counted = shape::column_term_log2(ColumnRegime::UniqueDecoding, base.log_cols, base.inv_rate, q);
    assert!((counted - base.regular_column_terms_log2().0).abs() < 1e-12, "the profile does not count its regular openings at the unique-decoding term");
    let attained = q as f64 * (1.0 - cc.r.len() as f64 / nn as f64).log2();
    if (nn - k) % 2 == 0 {
        assert_eq!(cc.r.len(), e + 1, "N - K is even, so the cheater should fail on exactly e + 1 columns");
        assert!((attained - counted).abs() < 1e-9, "the close case attains 2^{attained} per opening, the count is 2^{counted}");
    } else {
        assert!(attained <= counted + 1e-9, "the close case is accepted MORE often than counted: 2^{attained} > 2^{counted}");
    }
    for (i, spec) in shape::W16R2_PROFILES.iter().enumerate() {
        let rig = Rig::profile(&built(spec.profile));
        assert_eq!((rig.n(), rig.nn(), rig.k(), rig.e()), (n, nn, k, e), "{}: another geometry", spec.name);
        let (v, bad, drawn) = close_attempt(&rig, &cc, 62 + i as u64);
        assert_eq!(bad, cc.r, "{}: POSITIVE CONTROL: the cheater does not fail exactly on the columns outside Z and S", spec.name);
        let err = v.expect_err("CONTROL (f): A FALSE CLAIM ON A CLOSE MATRIX WAS ACCEPTED AT THE PROFILE GEOMETRY");
        assert!(err.contains("disagrees with clear vector 0"), "{}: {err}", spec.name);
        let at: usize = err.strip_prefix("pcs zk: column ").and_then(|s| s.split(' ').next()).and_then(|s| s.parse().ok()).unwrap_or_else(|| panic!("{}: no column in `{err}`", spec.name));
        assert!(cc.r.binary_search(&at).is_ok(), "{}: rejected at column {at}, which is not one of the e + 1 columns outside Z and S", spec.name);
        let hit = drawn.iter().filter(|j| cc.r.binary_search(j).is_ok()).count();
        eprintln!(
            "W16R2 control (f) {} (n {n}, N {nn}, Q = q_pad {q}, K {k}, e {e}): U = Enc + D0 on |S| = {} columns of row 0 (inside the unique-decoding radius), D0 zero on |Z| = K - 1 = {} columns, both vectors + dec(D0), a FALSE claim; POSITIVE CONTROL: they disagree with rho^T U on exactly the {} columns of R; {hit} of {} drawn columns in R: REJECTED: {err}",
            spec.name,
            cc.s.len(),
            k - 1,
            cc.r.len(),
            drawn.len()
        );
    }
    let verdict = if (nn - k) % 2 == 0 { "EQUAL: the count is attained" } else { "the attack is one column short of the count (N - K odd)" };
    eprintln!("W16R2 control (f) profile geometry: per opening the close case is accepted with (1 - |R|/N)^Q = 2^{attained:.3} (|R| = {} measured), the counted unique-decoding term is 2^{counted:.3}: {verdict} (D0 built and checked in {build_s:.2} s)", cc.r.len());
    // ---- the measurable geometry
    let toy = Rig::at(&base, PcsParams { log_cols: 4, inv_rate: 2, num_col_checks: 4 }, 4);
    assert_the_replica_is_open_zk(&toy, 9);
    let (tnn, tk, te, tq) = (toy.nn(), toy.k(), toy.e(), toy.zko.q_pad);
    assert_eq!((toy.n(), tnn, tk, te, tq), (16, 32, 20, 6, 4));
    let xs = coset_points(&toy);
    let trials = 20_000u64;
    let mut accepted = 0u64;
    for t in 0..trials {
        let cc = close_case(&toy, &xs, te, 300_000 + t);
        let (v, bad, _) = close_attempt(&toy, &cc, 100_000 + t);
        assert_eq!(bad, cc.r, "toy seed {t}: POSITIVE CONTROL: the cheater does not fail exactly on R");
        accepted += u64::from(v.is_ok());
    }
    let r = tnn - (tk - 1) - te;
    let exact = (1.0 - r as f64 / tnn as f64).powi(tq as i32);
    let bound = toy.bound();
    assert!((tnn - tk) % 2 == 0 && r == te + 1 && (exact - bound).abs() < 1e-12, "the toy's exact rate {exact} is not the lemma's bound {bound}");
    let (rate, sigma) = rate_and_sigma(accepted, trials, exact);
    eprintln!("W16R2 control (f) toy rate 1/2 (n 16, N 32, Q 4, K {tk}, e {te}): {accepted} of {trials} close-case false claims accepted = {rate:.4}; exact (1 - (e+1)/N)^Q = {exact:.4} (sigma {sigma:.4}; tolerance 5 sigma both ways)");
    assert!(rate <= exact + 5.0 * sigma, "the close case is accepted ABOVE (1 - (e+1)/N)^Q: the lemma's bound is broken");
    assert!(rate >= exact - 5.0 * sigma, "the close case is accepted BELOW its exact rate: the rig does not model the attack");
}

// ------------------------------------------------------------ control (g)

/// **D59 control (g) (review F7): a replay at the SAME geometry under
/// another profile's keys.** Control (e) rejects a W16 receipt under W16R2
/// by its geometry (T-4 fires first). Here the geometry is W16R2's own —
/// rate 1/2, `Q = q_pad = W16R2_OPENED_COLS` — and only the profile's keys
/// differ, one mechanism at a time, each with its positive control (the same
/// opening ACCEPTED when the verifier is handed the key it was made under, so
/// the key is the only thing the rejection can be about):
/// 1. the Merkle keys (column, leaf, node): committed under W16's, opened on
///    W16R2's transcript: "Merkle path ... fails";
/// 2. the Fiat–Shamir key: committed under W16R2's keys, opened on a
///    transcript under W16's key: the group weight differs, so the claim
///    check objects;
/// 3. the transcript constructor's domain alone (W16R2's key, the W16
///    profile string against the W16R2 one): the same;
/// 4. all of them: a whole W16-keyed opening at W16R2's geometry.
#[test]
fn w16r2_control_g_a_replay_at_the_same_geometry_under_another_profiles_keys_is_rejected() {
    let (r2s, w16s) = (built(shape::W16R2_RUNG_H24), built(shape::W16_RUNG_H24));
    let r2 = Rig::profile(&r2s);
    let w16 = Rig::at(&w16s, r2.params, r2.zko.q_pad);
    let q = shape::W16R2_OPENED_COLS;
    assert_eq!((r2.params.inv_rate, r2.params.num_col_checks, r2.zko.q_pad), (shape::W16R2_INV_RATE, q, q));
    let (a, b) = (&r2.tag, &w16.tag);
    assert!(a.column_key() != b.column_key() && a.leaf_key() != b.leaf_key() && a.node_key() != b.node_key() && a.transcript_key() != b.transcript_key(), "the two profiles share a key");
    let data = r2.matrix(71);
    let claims = [r2.claim(&data)];
    let at_domain = |domain: &[u8], root: &[u8; 32]| {
        let mut tr = protocol::tagged_transcript(&r2s, domain);
        tr.absorb(b"root", root);
        tr
    };
    let under = |tag: &HashTag, com: &Commitment, o: &OpeningZk, tr: &mut Transcript| zpcs::verify_zk_tagged(&r2.params, &r2.zko, com, &claims, o, &r2.ntt, tr, tag);
    // 1. the Merkle keys alone
    let c = w16.commit(data.clone(), 72);
    let com = c.commitment();
    let o = zpcs::open_zk(&c, &claims, &mut r2.transcript(&com.root));
    under(b, &com, &o, &mut r2.transcript(&com.root)).expect("POSITIVE CONTROL: the opening verifies on W16R2's transcript with W16's Merkle keys");
    let e = r2.verify(&com, &claims, &o).expect_err("CONTROL (g): AN OPENING UNDER W16'S MERKLE KEYS VERIFIED UNDER W16R2");
    assert!(e.starts_with("pcs zk: Merkle path for column ") && e.ends_with(" fails"), "{e}");
    eprintln!("W16R2 control (g) 1. committed under W16's column/leaf/node keys, opened on W16R2's transcript, at W16R2's geometry (rate 1/2, Q {q}): REJECTED: {e}");
    // 2. the Fiat-Shamir key alone
    let c = r2.commit(data.clone(), 73);
    let com = c.commitment();
    let o = zpcs::open_zk(&c, &claims, &mut w16.transcript(&com.root));
    under(a, &com, &o, &mut w16.transcript(&com.root)).expect("POSITIVE CONTROL: the opening verifies under W16R2's Merkle keys on W16's transcript");
    let e = r2.verify(&com, &claims, &o).expect_err("CONTROL (g): AN OPENING ON W16'S FIAT-SHAMIR KEY VERIFIED UNDER W16R2");
    assert_eq!(e, "pcs zk: group 0: <v, c> != combined claim");
    eprintln!("W16R2 control (g) 2. committed under W16R2's keys, opened on a transcript under W16's Fiat-Shamir key: REJECTED: {e}");
    // 3. the constructor's domain alone
    let o = zpcs::open_zk(&c, &claims, &mut at_domain(w16s.profile.as_bytes(), &com.root));
    under(a, &com, &o, &mut at_domain(w16s.profile.as_bytes(), &com.root)).expect("POSITIVE CONTROL: the opening verifies on its own domain");
    let e = under(a, &com, &o, &mut at_domain(r2s.profile.as_bytes(), &com.root)).expect_err("CONTROL (g): AN OPENING ON THE W16 DOMAIN VERIFIED ON THE W16R2 DOMAIN");
    assert_eq!(e, "pcs zk: group 0: <v, c> != combined claim");
    eprintln!("W16R2 control (g) 3. W16R2's keys, the transcript constructed on the W16 profile string, verified on the W16R2 string: REJECTED: {e}");
    // 4. everything
    let c = w16.commit(data, 74);
    let com = c.commitment();
    let o = zpcs::open_zk(&c, &claims, &mut w16.transcript(&com.root));
    w16.verify(&com, &claims, &o).expect("POSITIVE CONTROL: the W16-keyed opening at this geometry verifies under W16's keys");
    let e = r2.verify(&com, &claims, &o).expect_err("CONTROL (g): A W16-KEYED OPENING AT THE W16R2 GEOMETRY VERIFIED UNDER W16R2");
    assert_eq!(e, "pcs zk: group 0: <v, c> != combined claim");
    eprintln!("W16R2 control (g) 4. a whole W16-keyed opening at W16R2's geometry: REJECTED: {e}");
}

// ------------------------------------------------ W16's controls, ported

/// W16's seven out-of-range limb cases (`range16_tests`) at the W16R2 rung
#[test]
fn w16r2_limbs_out_of_their_range_are_rejected_by_the_verifier() {
    super::range16_tests::limbs_out_of_their_range_are_rejected_at(shape::W16R2_RUNG_H24);
}

/// W16 review F3 (a) at the W16R2 rung: a remainder filed in a wider family
/// is refused by the tag fold, and with the tags collapsed it is accepted
#[test]
fn w16r2_f3_a_remainder_filed_in_a_wider_family_is_refused_by_the_tag_fold() {
    super::range16_tests::f3_a_remainder_filed_in_a_wider_family_at(shape::W16R2_RUNG_H24);
}

/// W16 review F3 (b) at the W16R2 rung: a 16-bit word at +32768
#[test]
fn w16r2_f3_b_a_word_at_plus_32768_is_rejected_by_the_verifier() {
    super::range16_tests::f3_b_a_word_at_plus_32768_at(shape::W16R2_RUNG_H24);
}

/// W16 review F3 (c) at the W16R2 rung: a count moved into a narrow range
/// family's padded copy
#[test]
fn w16r2_f3_c_a_count_moved_into_a_narrow_range_padded_copy_is_rejected() {
    super::range16_tests::f3_c_a_count_moved_into_a_narrow_range_padded_copy_at(shape::W16R2_RUNG_H24);
}

/// W16 review F3 (d) at the W16R2 rung: a direct softmax quotient of 2^13
#[test]
fn w16r2_f3_d_a_direct_quotient_of_2_13_is_rejected_by_the_verifier() {
    super::range16_tests::f3_d_a_direct_quotient_of_2_13_at(shape::W16R2_RUNG_H24);
}

// ------------------------------------------------ the lemma's invariants

/// One of this crate's (or zkp-core's) source files, read at test time.
fn source(rel: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(rel);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("{}: {e}", p.display()))
}

/// the text of one top-level `fn` (from its signature to its closing brace
/// in column 0)
fn body<'a>(text: &'a str, signature: &str) -> &'a str {
    let i = text.find(signature).unwrap_or_else(|| panic!("`{signature}` is gone"));
    let rest = &text[i..];
    let end = rest.find("\n}\n").map(|k| k + 2).unwrap_or_else(|| panic!("`{signature}` has no closing brace in column 0"));
    &rest[..end]
}

/// **The lemma check's §8 item 6: its load-bearing invariants, pinned.**
/// * The proximity weights are `rows` independent `challenge_fp2` draws,
///   never powers or a tensor of one challenge (that would cost a factor
///   `m - 1` under BCIKS20 Thm 1.6), and every row is weighted.
/// * The column indices are drawn after every vector is absorbed, in the
///   verifier as in the prover; and they DEPEND on the vectors (two openings
///   differing in one vector entry draw different sets).
/// * `q_pad >= Q` at every W16R2 commitment.
/// * A W16R2 block verifies its `A` and `H` (and a run its boundaries and
///   endpoints) only through `verify_zk_tagged`, which checks the Merkle path
///   length, under the profile's keys — in `protocol::verify_core`, in
///   `run.rs`, and (review F4 (d)) in the D55 fork verifier `run_fork.rs`.
#[test]
fn w16r2_the_lemmas_load_bearing_invariants_are_pinned() {
    let pcs = source("../zkp-core/src/pcs.rs");
    let rhos = body(&pcs, "fn zk_rhos(");
    assert!(rhos.contains("let prox_rho = tr.challenge_fp2_vec(rows);"), "the proximity rho is no longer `rows` independent draws:\n{rhos}");
    assert!(!rhos.contains(".pow(") && !rhos.contains("powers"), "the proximity rho is built from powers");
    let tr_src = source("../zkp-core/src/transcript.rs");
    assert!(body(&tr_src, "pub fn challenge_fp2_vec(").contains("(0..n).map(|_| self.challenge_fp2()).collect()"), "challenge_fp2_vec is no longer n independent squeezes");
    for f in ["pub fn verify_zk_tagged(", "pub fn open_zk<"] {
        let b = body(&pcs, f);
        let (v, p, i) = (b.find("absorb_fp2(b\"pcs-vec\"").expect("pcs-vec"), b.find("absorb_fp2(b\"pcs-prox\"").expect("pcs-prox"), b.find("challenge_indices(").expect("indices"));
        assert!(v < p && p < i, "{f}: the indices are not drawn after both vectors are absorbed");
    }
    assert!(body(&pcs, "pub fn verify_zk_tagged(").contains("path.len() != depth"), "verify_zk_tagged no longer checks the path length");
    // the vectors decide the indices
    let sh = built(shape::W16R2_RUNG_H24);
    let rig = Rig::profile(&sh);
    let data = rig.matrix(51);
    let c = rig.commit(data, 51);
    let root = c.commitment().root;
    let (_, a, _) = open_as(&c, &mut rig.transcript(&root), &Cheat::default());
    let (_, b, _) = open_as(&c, &mut rig.transcript(&root), &Cheat { prox_pad: Some(Fp2::ONE), ..Cheat::default() });
    assert_ne!(a, b, "the column indices do not depend on the absorbed vectors");
    // the W16R2 verifier paths
    let proto = source("src/private_block/protocol.rs");
    let vc = body(&proto, "pub(crate) fn verify_core(");
    assert_eq!(vc.matches("pcs::verify_zk_tagged(").count(), 2, "verify_core does not verify A and H through verify_zk_tagged");
    assert!(!vc.contains("pcs::verify_zk("), "verify_core calls the untagged verifier");
    let run = source("src/private_block/run.rs");
    assert!(!run.contains("pcs::verify_zk(&"), "a run verifies a boundary or an endpoint through the untagged verifier");
    // review F4 (d) / the re-check's finding 5: the D55 fork verifier too (a
    // D55 run can take a W16R2 base). Every boundary and both endpoints
    // through `verify_zk_tagged` after T-4, and each fork's A and H through
    // `verify_core` after T-4; never the untagged verifier
    let fork = source("src/private_block/run_fork.rs");
    assert!(!fork.contains("pcs::verify_zk(&") && !fork.contains("pcs::verify_zk("), "the D55 fork run calls the untagged verifier");
    let vf = body(&fork, "pub(crate) fn verify_run_with_forks(");
    assert_eq!(vf.matches("pcs::verify_zk_tagged(").count(), 3, "verify_run_with_forks does not open the boundaries, the input endpoint and the output endpoint through verify_zk_tagged (three sites)");
    let first_open = vf.find("pcs::verify_zk_tagged(").unwrap();
    for t4 in ["paths_are_the_tree_depth(&format!(\"boundary {k}\")", "paths_are_the_tree_depth(\"run input endpoint\"", "paths_are_the_tree_depth(\"run output endpoint\""] {
        assert!(vf.find(t4).is_some_and(|i| i < first_open), "verify_run_with_forks: T-4 `{t4}` is gone or comes after an opening is verified");
    }
    let one = body(&fork, "fn verify_one_fork(");
    let (t4a, t4h, vc) = (one.find("paths_are_the_tree_depth(\"A\"").expect("T-4 for A in a fork"), one.find("paths_are_the_tree_depth(\"H\"").expect("T-4 for H in a fork"), one.find("protocol::verify_core(").expect("a fork's verify_core"));
    assert!(t4a < vc && t4h < vc && one.matches("protocol::verify_core(").count() == 1, "verify_one_fork does not check T-4 before its one verify_core");
    for spec in shape::W16R2_PROFILES.iter() {
        let s = built(spec.profile);
        let p = protocol::pcs_params_at(&s);
        assert!(ZkOpts::standard(&p).q_pad >= p.num_col_checks && ZkOpts::standard(&protocol::endpoint_pcs_params(&s)).q_pad >= p.num_col_checks);
        assert!(!s.hashes_under_the_legacy_rule() && s.hash_tag().column_key().is_some(), "{}: not a tagged profile", spec.name);
    }
    eprintln!("W16R2 invariants: proximity weights = rows independent challenge_fp2 draws; indices after both absorbs in open_zk and verify_zk_tagged, and they move with the vectors; q_pad >= Q; A/H through verify_zk_tagged (path length checked) under each profile's keys");
}

// ------------------------------------------------ F2's ruling: the privacy argument at Q = 280

/// **The privacy argument's hypotheses at the ruled `Q = 280`, checked on the
/// production encoder** (D59 condition (5), re-checked for F2's ruling). The
/// argument (`results/zk60_w16r2_20261101/PRIVACY_RECHECK_20261102.md`): a
/// regular row is `f = f_data + Z_n g`, `Z_n = X^n - 1`, `g` the row's
/// `q_pad` uniform pads as coefficients, evaluated on the coset `7 G_N`; the
/// opened entries of a row are uniform given its message exactly when the pad
/// block at the DISTINCT opened positions has full rank, and `Q` draws give at
/// most `Q` distinct positions. Checked here, not assumed:
/// 1. `Q = q_pad` BY CONSTRUCTION at every W16R2 shape, at both geometries
///    (`pcs_params_at`, `endpoint_pcs_params`, and `ZkOpts::standard`, whose
///    text is read), and an honest opening draws exactly `Q` indices;
/// 2. the pad block of `pcs::encode_row_zk`, at ALL `N` encoded positions and
///    for every one of the `q_pad` unit pads, IS `diag(Z_n(x_j)) V` with
///    `V_{j,i} = x_j^i` (`i < q_pad`); the `x_j` are pairwise distinct and
///    `Z_n(x_j) != 0` at every one of the `N` positions (no opened column is
///    pad-free). A Vandermonde block times a nonzero diagonal has full rank
///    on ANY `<= q_pad` distinct rows, which is the claim;
/// 3. as a measurement on that encoder: rank `Q` at `Q`-point sets chosen to
///    stress it (the first and the last `Q` positions, a stride, positions in
///    one small sub-coset, positions sharing `x^n`, random sets, a real
///    opening's draw), and rank exactly `q_pad` at `q_pad + 1` points — the
///    reason `Q` may never exceed the pad count.
#[test]
fn w16r2_at_q_280_the_pad_block_is_full_rank_on_any_q_distinct_opened_points() {
    use super::w16_privacy_gate_tests::{pad_codewords, pad_rank};
    let q = shape::W16R2_OPENED_COLS;
    assert_eq!(q, 280, "F2's ruling");
    // 1. Q = q_pad by construction
    let pcs = source("../zkp-core/src/pcs.rs");
    assert!(pcs.contains("ZkOpts { q_pad: params.num_col_checks, coset: Fp::new(7) }"), "ZkOpts::standard no longer takes its pad count from the column count");
    for spec in shape::W16R2_PROFILES.iter() {
        let s = built(spec.profile);
        for (what, p) in [("pcs_params_at", protocol::pcs_params_at(&s)), ("endpoint_pcs_params", protocol::endpoint_pcs_params(&s))] {
            assert_eq!((p.inv_rate, p.num_col_checks, ZkOpts::standard(&p).q_pad, s.opened_cols), (2, q, q, q), "{}: {what}", spec.name);
        }
    }
    let rig = Rig::profile(&built(shape::W16R2_RUNG_H24));
    let (n, nn) = (rig.n(), rig.nn());
    assert_eq!((n, nn, rig.zko.q_pad, rig.params.num_col_checks), (1 << 14, 1 << 15, q, q));
    let c = rig.commit(rig.matrix(61), 61);
    let (o, drawn, _) = open_as(&c, &mut rig.transcript(&c.commitment().root), &Cheat::default());
    let mut real: Vec<usize> = drawn.clone();
    real.sort_unstable();
    real.dedup();
    assert!(drawn.len() == q && o.columns.len() == q && real.len() <= rig.zko.q_pad, "an opening draws {} indices ({} distinct) against {} pads", drawn.len(), real.len(), rig.zko.q_pad);
    // 2. the pad block's structure, every unit pad at every position
    let t = std::time::Instant::now();
    let xs = coset_points(&rig);
    let mut keys: Vec<u64> = xs.iter().map(|x| x.0).collect();
    keys.sort_unstable();
    keys.dedup();
    assert_eq!(keys.len(), nn, "two encoded positions share an evaluation point");
    let z: Vec<Fp> = xs.iter().map(|x| x.pow(n as u64).sub(Fp::ONE)).collect();
    assert!(z.iter().all(|v| !v.is_zero()), "Z_n vanishes at an encoded position: that opened column would carry no pad randomness");
    let cw = pad_codewords(shape::W16R2_LOG_COLS, shape::W16R2_INV_RATE, rig.zko.q_pad, Some(rig.zko.coset), &rig.ntt);
    assert_eq!(cw.len(), rig.zko.q_pad);
    let mut pw = z.clone(); // Z_n(x_j) x_j^i, i = 0 first
    for (i, row) in cw.iter().enumerate() {
        assert_eq!(row.len(), nn);
        if let Some(j) = (0..nn).find(|&j| row[j] != pw[j]) {
            panic!("unit pad {i}: the encoder's entry at position {j} is not Z_n(x_j) x_j^{i}");
        }
        for (p, x) in pw.iter_mut().zip(&xs) {
            *p = p.mul(*x);
        }
    }
    let structure_s = t.elapsed().as_secs_f64();
    // 3. the rank, measured
    let mut rng = ZkRng::new(20261103, b"w16r2 q280 pad rank");
    let mut random_set = || -> Vec<usize> {
        let mut s: Vec<usize> = Vec::new();
        while s.len() < q {
            let j = (rng.fp().0 % nn as u64) as usize;
            if !s.contains(&j) {
                s.push(j);
            }
        }
        s
    };
    let sets: Vec<(&str, Vec<usize>)> = vec![
        ("the first Q positions", (0..q).collect()),
        ("the last Q positions", (nn - q..nn).collect()),
        ("a stride of N / Q", (0..q).map(|k| k * (nn / q)).collect()),
        ("the sub-coset 7 G_512 (stride 64)", (0..q).map(|k| k * 64).collect()),
        ("the even positions (x^n all equal 7^n)", (0..q).map(|k| 2 * k).collect()),
        ("the odd positions (x^n all equal -7^n)", (0..q).map(|k| 2 * k + 1).collect()),
        ("random 1", random_set()),
        ("random 2", random_set()),
        ("random 3", random_set()),
    ];
    let mut lines = Vec::new();
    for (what, set) in &sets {
        let mut d = set.clone();
        d.sort_unstable();
        d.dedup();
        assert_eq!(d.len(), q, "{what}: not {q} distinct positions");
        let r = pad_rank(&cw, &d, rig.zko.q_pad);
        assert_eq!(r, q, "{what}: the pad block at {q} distinct positions has rank {r}");
        lines.push(format!("{what} {r}"));
    }
    let r = pad_rank(&cw, &real, rig.zko.q_pad);
    assert_eq!(r, real.len(), "an honest opening's {} distinct positions: rank {r}", real.len());
    let over: Vec<usize> = (0..q + 1).collect();
    let r_over = pad_rank(&cw, &over, rig.zko.q_pad);
    assert_eq!(r_over, q, "q_pad + 1 positions: rank {r_over}, not the pad count");
    eprintln!(
        "W16R2 PRIVACY Q = q_pad = {q} (n {n}, N {nn}, coset {}): Q = q_pad by construction at every W16R2 shape and both geometries; an honest opening draws {} indices, {} distinct; the encoder's pad block = diag(Z_n(x_j)) x_j^i at all {nn} positions for all {} unit pads, the x_j pairwise distinct and Z_n(x_j) != 0 at every position ({structure_s:.2} s): so full rank on ANY <= {q} distinct points; measured rank at {q}-point sets: {}; at the opening's draw {r}; at {} points {r_over} (= q_pad)",
        rig.zko.coset.0,
        drawn.len(),
        real.len(),
        cw.len(),
        lines.join(", "),
        over.len()
    );
}

// ------------------------------------------------ review F6: the production counters take the regime

/// **Review F6 (pre-registration): the production whole-run counters price a
/// block opening by the lemma that covers its profile** — the token run's
/// `whole_run_of` and the classifier run's `whole_run_of_classifier`, through
/// `token_io::run::push_block_openings` / `omitted_bound` /
/// `whole_run_words`. Before F6 both priced every block and boundary opening
/// at D15's delta/3 (`hiding_opening_log2`), about 2^-72 at a W16R2 shape.
/// * At EVERY other profile this lane builds: the regime is `GeneralCode`,
///   and each term is the old float BIT FOR BIT — the per-opening column
///   term, the field term, the pushed sequence (the column sum is a float sum,
///   so its order matters), the omitted bound, and the parameter-line words.
///   That is why no registered statement's whole-run floor, which its
///   parameter line binds, can move.
/// * At each W16R2 shape: BCIKS20 Thm 3.1, 2^-113.93 per opening at Q = 280,
///   field `(N + 4096)/p^2`; the 8B T128 run's 32 blocks give the block
///   part of `ACCOUNTING.md`'s column term (97 regular openings and 32 `M`),
///   and the parameter-line words name the regime and its count.
#[test]
fn w16r2_f6_the_whole_run_counters_price_each_block_opening_under_its_profiles_regime() {
    use super::token_io::run::{omitted_bound, push_block_openings, whole_run_words, WholeRun, PCS_FIELD_PER_OPENING_LOG2, SUMCHECK_PER_STAGE_LOG2};
    use super::token_io::{hiding_opening_log2, mask_opening_log2, regular_opening_field_log2, regular_opening_log2};
    let bits = |v: &[f64]| -> Vec<u64> { v.iter().map(|x| x.to_bits()).collect() };
    let old_block_openings = |sh: &Shape, l: usize| -> Vec<f64> {
        let mut c = Vec::new();
        for _ in 0..l {
            c.push(hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols));
            c.push(hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols));
            c.push(mask_opening_log2());
        }
        for _ in 0..=l {
            c.push(hiding_opening_log2(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols));
        }
        c
    };
    let wr = |regime: ColumnRegime, special: usize| WholeRun { openings: 141, column_log2: -100.0, logup_log2: -98.0, omitted_log2: -106.0, total_log2: -97.5, floor_bits: 97, block_regime: regime, block_regime_openings: special };
    // every other profile: bit for bit
    let mut others: Vec<Shape> = vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()];
    others.extend(super::trained_calib_tests::registered_trained_shapes());
    others.extend(super::accuracy_profile_tests::registered_shapes());
    others.extend(shape::W16_PROFILES.iter().map(|s| built(s.profile)));
    for sh in &others {
        assert_eq!(sh.column_regime(), ColumnRegime::GeneralCode, "{}", sh.name);
        for (ln, ir) in [(sh.log_cols, sh.inv_rate), (sh.endpoint_log_n, sh.endpoint_inv_rate)] {
            assert_eq!(regular_opening_log2(sh.column_regime(), ln, ir, sh.opened_cols).to_bits(), hiding_opening_log2(ln, ir, sh.opened_cols).to_bits(), "{}: the column term moved", sh.name);
            assert_eq!(regular_opening_field_log2(sh.column_regime(), ln, ir).to_bits(), PCS_FIELD_PER_OPENING_LOG2.to_bits(), "{}: the field term moved", sh.name);
        }
        for l in [1usize, 3, 22, 32] {
            let mut col = vec![-103.69, -106.25];
            let (special, field) = push_block_openings(sh, l, &mut col);
            let mut old = vec![-103.69, -106.25];
            old.extend(old_block_openings(sh, l));
            assert_eq!(bits(&col), bits(&old), "{} L{l}: the pushed sequence moved", sh.name);
            assert_eq!((special, field.to_bits()), (0, 0.0f64.to_bits()), "{} L{l}", sh.name);
            let was = col.len() as f64 * PCS_FIELD_PER_OPENING_LOG2.exp2() + (l + 2) as f64 * SUMCHECK_PER_STAGE_LOG2.exp2();
            assert_eq!(omitted_bound(col.len(), special, field, l + 2).to_bits(), was.to_bits(), "{} L{l}: the omitted bound moved", sh.name);
        }
    }
    let figure = "column-plus-logup-derived-plus-pcs-field-and-sumcheck-bound";
    assert_eq!(whole_run_words(&wr(ColumnRegime::GeneralCode, 0), figure), format!("whole-run-floor-97-bits-141-openings-{figure}"), "the registered parameter-line words moved");
    // the W16R2 shapes: Thm 3.1
    let p2 = 2.0 * (crate::field::P as f64).log2();
    for spec in shape::W16R2_PROFILES.iter() {
        let sh = built(spec.profile);
        assert_eq!(sh.column_regime(), ColumnRegime::UniqueDecoding);
        let (ud, d3) = (regular_opening_log2(sh.column_regime(), sh.log_cols, sh.inv_rate, sh.opened_cols), hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols));
        assert!((ud + 113.932).abs() < 0.001, "{}: {ud}", spec.name);
        assert_eq!(ud.to_bits(), shape::column_term_log2(ColumnRegime::UniqueDecoding, sh.log_cols, sh.inv_rate, sh.opened_cols).to_bits());
        assert!(d3 > -73.0 && d3 < -72.0, "{}: the delta/3 figure F6 replaces is {d3}", spec.name);
        let f = regular_opening_field_log2(sh.column_regime(), sh.endpoint_log_n, sh.endpoint_inv_rate);
        assert!((f - ((32768.0f64 + 4096.0).log2() - p2)).abs() < 1e-12 && f > PCS_FIELD_PER_OPENING_LOG2, "{}: field {f}", spec.name);
        let l = 32;
        let mut col = Vec::new();
        let (special, field) = push_block_openings(&sh, l, &mut col);
        assert_eq!((col.len(), special), (4 * l + 1, 3 * l + 1), "{}", spec.name);
        let column: f64 = col.iter().map(|x| x.exp2()).sum();
        let want = (97.0 * ud.exp2() + 32.0 * mask_opening_log2().exp2()).log2();
        assert!((column.log2() - want).abs() < 1e-9 && (column.log2() + 101.228).abs() < 0.001, "{}: block column part 2^{}", spec.name, column.log2());
        assert!((field.log2() - (97.0f64.log2() + f)).abs() < 1e-9, "{}: block field part 2^{}", spec.name, field.log2());
        let w = whole_run_words(&wr(sh.column_regime(), special), figure);
        assert_eq!(w, format!("whole-run-floor-97-bits-141-openings-{figure}-with-97-block-and-boundary-openings-at-the-unique-decoding-radius-d59"));
        eprintln!("W16R2 F6 {}: a block/boundary opening is priced 2^{ud:.3} (Thm 3.1; delta/3 said 2^{d3:.3}), field 2^{f:.3}; at L = {l}: {} block openings, {special} at the unique-decoding radius, block column part 2^{:.3}, block field part 2^{:.3}; the statement words end \"...{}\"", spec.name, col.len(), column.log2(), field.log2(), &w[w.len() - 72..]);
    }
    eprintln!("W16R2 F6: {} other profiles' counters unchanged bit for bit (column, field, sequence, omitted bound, words)", others.len());
}

// ------------------------------------------------ the codec against the count (F4 (b))

/// the counted bytes of one hiding opening at a W16R2 commitment of row
/// width `2^log_n` and rate `1/inv_rate`: `groups + 1` clear vectors of
/// `n + Q` Fp2 words, then `Q` columns, each its index, `rows` words, a salt
/// and a path of the tree's depth (`OpeningZk::size_bytes`'s terms), `Q`
/// being `W16R2_OPENED_COLS`
fn w16r2_opening_bytes(log_n: usize, inv_rate: usize, groups: usize, rows: usize) -> usize {
    let (q, n) = (shape::W16R2_OPENED_COLS, 1usize << log_n);
    let depth = (n * inv_rate).trailing_zeros() as usize;
    (groups + 1) * (n + q) * 16 + q * (8 + rows * 8 + 32 + depth * 32)
}

/// `M`'s counted opening, from its OWN `zk.rs` geometry (never the block's `Q`)
fn mask_opening_bytes(m_rows: usize) -> usize {
    use crate::zk::{MASK_LOG_DOM, MASK_LOG_MSG, MASK_Q};
    2 * (2usize << MASK_LOG_MSG) * 16 + MASK_Q * (8 + m_rows * 8 + 32 + MASK_LOG_DOM as usize * 32)
}

/// **Review F4 (b): the codec length IS the count at every W16R2 shape.**
/// `receipt_bytes` reads the shape's own `opened_cols` since D59, and
/// `wire::encoded_len == receipt_bytes().total` was asserted only at four
/// `Q = 256` shapes (`grow_tests::the_codec_length_is_the_models_at_every_shape`).
/// Here at each W16R2 shape, and each opening's part against the formula
/// from `W16R2_OPENED_COLS`, the row width and the tree depth; `M`'s part
/// is its own `zk.rs` geometry. (W16R2 refuses a single-block receipt, so
/// the frames a W16R2 proof really ships are a run's: their lengths are
/// asserted against the same counts by the run-level tests below.)
#[test]
fn w16r2_the_codec_length_is_the_count_at_every_w16r2_shape() {
    for spec in shape::W16R2_PROFILES.iter() {
        let sh = built(spec.profile);
        let lay = Layout::for_shape(&sh).unwrap();
        let rb = sh.receipt_bytes();
        assert_eq!(sh.opened_cols, shape::W16R2_OPENED_COLS, "{}", spec.name);
        assert_eq!(wire::encoded_len(&lay), rb.total, "{}: the codec's frame length is not the counted receipt", spec.name);
        assert_eq!(rb.a_opening, w16r2_opening_bytes(sh.log_cols, sh.inv_rate, sh.a_groups(), lay.a_rows), "{}: A", spec.name);
        assert_eq!(rb.h_opening, w16r2_opening_bytes(sh.log_cols, sh.inv_rate, sh.h_groups(), lay.h_rows), "{}: H", spec.name);
        let e_open = w16r2_opening_bytes(sh.endpoint_log_n, sh.endpoint_inv_rate, 1, sh.endpoint_rows);
        assert_eq!(rb.endpoint_openings, 2 * e_open, "{}: the endpoints", spec.name);
        assert_eq!(rb.mask_opening, mask_opening_bytes(lay.m_rows()), "{}: M", spec.name);
        eprintln!("W16R2 F4(b) {}: encoded_len = receipt_bytes().total = {} B (A {}, H {}, M {}, one endpoint opening {} B at Q {})", spec.name, rb.total, rb.a_opening, rb.h_opening, rb.mask_opening, e_open, sh.opened_cols);
    }
}

// ------------------------------------------------ run-level controls (F3)

/// a padded `[t_pad, d_pad]` plane's true `[T, width]` words
fn unpad(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

/// a run's private inputs, every witness built before the run (the sealing
/// pass)
struct Chain {
    witnesses: Vec<Option<Witness>>,
    planes: Vec<Vec<i16>>,
}

impl super::run::RunWitnessSource for Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.witnesses.get_mut(k).and_then(Option::take).ok_or_else(|| format!("witness {k} was consumed"))
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.planes.get(k).cloned().ok_or_else(|| format!("no boundary {k}"))
    }
}

/// **A W16-family rung run of `l` blocks at its own geometry** — the recipe
/// of `run_fork_tests::d55_ab_one_request_serial_against_forks`, which is
/// how the builder proved and verified the honest W16R2 `L = 3` run: ONE
/// public synthetic block at every layer (`range16_tests::case`), the
/// profile's test-only run identity (`W16_TEST_RUN_PROFILES`), a synthetic
/// trained-model statement, and an honest witness chain from M10's
/// admissible input. The run's transcript is the profile's tagged one
/// (`RunStatement::transcript`, `ForkRun::transcript`).
struct RungRun {
    sh: Shape,
    blk: BlockPublic,
    data: super::accuracy_public::AccuracyPublic,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    l: usize,
    run_profile: &'static str,
    model: TrainedModelStatement,
    xs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
    input: Vec<i16>,
    output: Vec<i16>,
}

impl RungRun {
    fn new(profile: &str, l: usize) -> RungRun {
        let (sh, data, public, ff) = super::range16_tests::case(built(profile), 3);
        let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
        let build = |x: &[i16]| super::witness::build_accuracy(&sh, &public, &ff, &data, x);
        // M10's admissible input, then the honest chain through every layer
        let mut s = 0usize;
        let x0 = loop {
            let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
            match build(&input) {
                Ok(_) => break input,
                Err(_) if s < 6 => s += 1,
                Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
            }
        };
        let ids = Ids::new(&sh).unwrap();
        let (mut xs, mut planes, mut input, mut output) = (vec![x0], Vec::new(), Vec::new(), Vec::new());
        for k in 0..l {
            let w = build(&xs[k]).unwrap_or_else(|e| panic!("{}: layer {k} of the synthetic chain is not admissible: {e}", sh.name));
            if k == 0 {
                input = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
            }
            let out = w.output().unwrap();
            xs.push(unpad(&sh, &out));
            if k + 1 < l {
                planes.push(out);
            } else {
                output = out;
            }
        }
        let run_profile = super::w16_privacy_gate_tests::W16_TEST_RUN_PROFILES.iter().find(|(_, b)| *b == sh.profile).map(|(r, _)| *r).expect("a W16-family test-only run identity");
        let mut prov = Provenance::recipe("W16R2 review F3 fixture (public synthetic)", 1.0, [3; 32], [4; 32]);
        prov.rope_theta = shape::trained_rope_theta(sh.profile).expect("the profile's pinned RoPE base");
        prov.rope_scaling = shape::trained_rope_scaling(sh.profile).expect("the profile's pinned RoPE transform");
        let source = ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: "synthetic/w16r2-f3".into(), revision: "f3".into(), weights_sha256: [0; 32], config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: l as u32 };
        let r0 = LayerRecord::of_block(0, &blk, vec![]);
        let records: Vec<LayerRecord> = (0..l)
            .map(|i| {
                let mut r = r0.clone();
                r.index = i as u32;
                r
            })
            .collect();
        let model = TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(&sh, run_profile, source, IntegerCalibration::as_the_code_proves(&sh, &prov), records).unwrap_or_else(|e| panic!("the synthetic {l}-layer statement: {e}"));
        RungRun { sh, blk, data, public, ff, l, run_profile, model, xs, planes, input, output }
    }
    fn blocks(&self) -> Vec<BlockPublic> {
        vec![self.blk.clone(); self.l]
    }
    /// every witness of one proof, built before the call
    fn chain(&self) -> Chain {
        let witnesses = (0..self.l).map(|k| Some(super::witness::build_accuracy(&self.sh, &self.public, &self.ff, &self.data, &self.xs[k]).expect("the chain was admissible"))).collect();
        Chain { witnesses, planes: self.planes.clone() }
    }
    /// the run statement on an endpoint policy `expected` (ruling CS-4 runs
    /// inside the constructor, before the run's header exists)
    fn statement_on(&self, context: u8, expected: ExpectedIo) -> Result<RunStatement, String> {
        RunStatement::new_bound_from_digests(RunShape::new(self.sh.clone(), self.l, self.run_profile)?, [context; 32], expected, vec![self.blk.digest(); self.l], &vec![(0, 0); self.l], &self.model)
    }
    /// the honest statement and its endpoint owners, at this profile's own policy
    fn statement(&self, context: u8) -> (RunStatement, Endpoints) {
        let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&self.sh, [context; 32], 0, 0).unwrap(), &self.input, &self.output).unwrap();
        (self.statement_on(context, expected).expect("the honest run statement"), owners)
    }
    /// an honest D12a run: its statement and its `L` segments
    fn d12a(&self, context: u8) -> (RunStatement, Vec<Vec<u8>>) {
        let (st, owners) = self.statement(context);
        let mut src = self.chain();
        let mut segs: Vec<Vec<u8>> = Vec::new();
        super::run::prove_run(&st, &self.blocks(), &mut src, owners, &mut |k, b| {
            assert_eq!(k, segs.len());
            segs.push(b);
            Ok(())
        })
        .expect("the honest D12a run proves");
        (st, segs)
    }
    /// an honest D55 fork run on `l` workers: its statement and its receipt
    fn d55(&self, context: u8) -> (RunStatement, ForkReceipt) {
        let (st, owners) = self.statement(context);
        let mut src = self.chain();
        let blocks = self.blocks();
        let rc = {
            let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
            super::run::fork::prove_run_with_forks(&fr, &blocks, &mut src, owners, self.l).expect("the honest D55 fork run proves").0
        };
        (st, rc)
    }
    /// the rate, `Q` and keys every control below relies on
    fn assert_the_profile(&self, inv_rate: usize, q: usize) {
        let sh = &self.sh;
        assert_eq!((sh.inv_rate, sh.endpoint_inv_rate, sh.opened_cols), (inv_rate, inv_rate, q), "{}: not the geometry this control is about", sh.name);
        assert!(!sh.hashes_under_the_legacy_rule() && sh.hash_tag().transcript_key().is_some() && sh.hash_tag().column_key().is_some(), "{}: the run's transcript and hashes are not keyed", sh.name);
    }
}

/// `(one internal boundary opening, one external endpoint opening)`, their
/// counted bytes at a run of `st`: a boundary carries its two claim sites
/// (`BOUNDARY_SITES` groups) over its own derived rows, an endpoint one
fn run_opening_counts(st: &RunStatement) -> (usize, usize) {
    let sh = st.rs().sh();
    let b_rows = st.boundary_spec(0).unwrap().commitment_rows();
    (w16r2_opening_bytes(sh.endpoint_log_n, sh.endpoint_inv_rate, super::run::BOUNDARY_SITES, b_rows), w16r2_opening_bytes(sh.endpoint_log_n, sh.endpoint_inv_rate, 1, sh.endpoint_rows))
}

/// One D12a segment, decoded with the verifier's own counts; its binding
/// and start tag are read from its own header (`decode_segment` compares
/// them, and the verifier compares them again), so an edit re-encoded here
/// carries the honest header and trailer.
struct SegFrame {
    seg: wire::Segment,
    lay: Layout,
    g: wire::SegGeom,
    binding: [u8; 32],
    start: [u8; 32],
    end: [u8; 32],
}

impl SegFrame {
    fn decode(st: &RunStatement, bytes: &[u8], k: usize) -> SegFrame {
        let l = st.rs().l();
        let lay = Layout::for_shape(&st.stage_shape(k).unwrap()).unwrap();
        let g = wire::SegGeom { l, k, boundary_rows: if l > 1 { st.boundary_spec(0).unwrap().commitment_rows() } else { 0 }, sites: super::run::BOUNDARY_SITES };
        let binding: [u8; 32] = bytes[8..40].try_into().unwrap();
        assert_eq!(binding, st.binding().unwrap(), "segment {k}'s binding is not where this harness reads it");
        let start: [u8; 32] = bytes[wire::RUN_HEADER - 32..wire::RUN_HEADER].try_into().unwrap();
        let (seg, end) = wire::decode_segment(bytes, &lay, g, &binding, &start).unwrap_or_else(|e| panic!("segment {k} does not decode: {e}"));
        let f = SegFrame { seg, lay, g, binding, start, end };
        assert_eq!(f.encode(), bytes, "segment {k} does not re-encode to its own bytes");
        f
    }
    fn try_encode(&self) -> Result<Vec<u8>, String> {
        wire::encode_segment(&self.seg, &self.lay, self.g, &self.binding, &self.start, &self.end)
    }
    fn encode(&self) -> Vec<u8> {
        self.try_encode().unwrap()
    }
}

/// `bytes` with the opening `old` (asserted to be at `at`) replaced by `new`
fn splice_opening(bytes: &[u8], at: usize, old: &OpeningZk, new: &OpeningZk) -> Vec<u8> {
    let (o, w) = (bytes_of(old), bytes_of(new));
    assert_eq!(&bytes[at..at + o.len()], &o[..], "the opening is not at the offset this harness computed");
    let mut b = bytes[..at].to_vec();
    b.extend(w);
    b.extend_from_slice(&bytes[at + o.len()..]);
    b
}

/// one opened column's first entry + 1 (its Merkle path no longer opens it)
fn bump_column(o: &mut OpeningZk) {
    o.columns[0].1[0] = o.columns[0].1[0].add(Fp::ONE);
}

/// the proximity vector's first PAD entry + 1 (absorbed: the verifier
/// redraws the columns, and the encoding moves at every coset point)
fn bump_prox_pad(o: &mut OpeningZk, n: usize) {
    o.prox_vec[n] = o.prox_vec[n].add(Fp2::ONE);
}

/// a column-test objection at `site`: the redrawn indices (`!= sampled`), or
/// with probability `1/N` the disagreement the moved encoding has at EVERY
/// column (both are `verify_zk_tagged`'s column round at that commitment)
fn is_the_column_round_at(e: &str, site: &str) -> bool {
    e.starts_with(&format!("{site}: pcs zk: ")) && (e.contains(" != sampled ") || e.contains(" disagrees with clear vector "))
}

/// **Review F3, the D12a run verifier.** A W16R2 rung run (`L = 3`: two
/// internal boundaries and both endpoints at rate 1/2, `Q =
/// W16R2_OPENED_COLS`, under the profile's tagged transcript and keys) and
/// the same run at W16 (rate 1/4) for the splices. The honest receipt
/// verifies, and so does its decode-and-re-encode; every frame has its
/// counted length (F4 (b)). Each control is a complete receipt that the
/// verifier REJECTS, at the site it asserts:
/// * (i) W16's rate-1/4 `B_1` opening, and its rate-1/4 output-endpoint
///   opening, spliced into the W16R2 receipt: the frame is not the counted
///   length the verifier's OWN shape gives, so the wire refuses it before a
///   byte is hashed; the frame format cannot even carry a 16-entry path, and
///   handed the decoded opening the verifier's T-4 refuses "16 entries ... 15
///   deep" (and the encoder will not write it);
/// * (ii) one entry of one opened column of `B_1`, `B_0`, the input
///   endpoint and the output endpoint: "Merkle path" at that site;
/// * (iii) one pad entry of `B_1`'s, and of the output endpoint's, proximity
///   vector + 1: the column round at that site.
#[test]
fn w16r2_f3_run_level_controls_under_the_d12a_run_verifier() {
    let (r2, w16) = (RungRun::new(shape::W16R2_RUNG_H24, 3), RungRun::new(shape::W16_RUNG_H24, 3));
    r2.assert_the_profile(shape::W16R2_INV_RATE, shape::W16R2_OPENED_COLS);
    w16.assert_the_profile(4, 256);
    let (st, segs) = r2.d12a(91);
    let blocks = r2.blocks();
    super::run::verify_run(&st, &blocks, &segs).expect("the honest W16R2 L3 D12a run verifies");
    let l = st.rs().l();
    // ---- F4 (b): every segment is the codec's length and the count's
    let rb = r2.sh.receipt_bytes();
    let (b_open, e_open) = run_opening_counts(&st);
    let frames: Vec<SegFrame> = (0..l).map(|k| SegFrame::decode(&st, &segs[k], k)).collect();
    for (k, f) in frames.iter().enumerate() {
        let counted = wire::RUN_HEADER
            + (if k + 1 < l { 32 } else { 0 })
            + 3 * 32
            + rb.slots
            + mask_opening_bytes(f.lay.m_rows())
            + w16r2_opening_bytes(r2.sh.log_cols, r2.sh.inv_rate, r2.sh.a_groups(), f.lay.a_rows)
            + w16r2_opening_bytes(r2.sh.log_cols, r2.sh.inv_rate, r2.sh.h_groups(), f.lay.h_rows)
            + (if k == 0 { e_open } else { b_open })
            + (if k + 1 == l { e_open } else { 0 })
            + wire::RUN_TRAILER;
        assert_eq!((segs[k].len(), wire::segment_len(&f.lay, f.g)), (counted, counted), "segment {k}: the frame, the codec's segment_len and the count disagree");
        assert_eq!((f.seg.a_open.size_bytes(), f.seg.h_open.size_bytes(), f.seg.mask_open.size_bytes()), (rb.a_opening, rb.h_opening, rb.mask_opening), "segment {k}: an opening is not its counted size");
        assert_eq!(f.seg.in_open.size_bytes(), if k == 0 { e_open } else { b_open }, "segment {k}: the opening it closes");
    }
    let fresh: Vec<Vec<u8>> = frames.iter().map(SegFrame::encode).collect();
    super::run::verify_run(&st, &blocks, &fresh).expect("the decoded and re-encoded honest receipt verifies");
    eprintln!("W16R2 F3 D12a | honest W16R2 rung L{l} run: verifies (and re-encoded); segments {:?} B = the codec's segment_len = the count (boundary opening {b_open} B, endpoint opening {e_open} B at Q {})", segs.iter().map(Vec::len).collect::<Vec<_>>(), r2.sh.opened_cols);
    // ---- the rate-1/4 run whose openings are spliced in
    let (st4, segs4) = w16.d12a(92);
    super::run::verify_run(&st4, &w16.blocks(), &segs4).expect("the honest W16 (rate 1/4) L3 run verifies under its own profile");
    let last4 = SegFrame::decode(&st4, &segs4[l - 1], l - 1);
    let (w16_b1, w16_out) = (last4.seg.in_open.clone(), last4.seg.out_open.clone().unwrap());
    let reject = |what: &str, k: usize, bytes: Vec<u8>| -> String {
        let mut bad = segs.clone();
        bad[k] = bytes;
        let e = super::run::verify_run(&st, &blocks, &bad).err().unwrap_or_else(|| panic!("RUN CONTROL (D12a) {what}: ACCEPTED"));
        eprintln!("W16R2 F3 D12a | {what} | REJECTED: {e}");
        e
    };
    let edited = |k: usize, edit: &dyn Fn(&mut wire::Segment)| -> Vec<u8> {
        let mut f = SegFrame::decode(&st, &segs[k], k);
        edit(&mut f.seg);
        f.encode()
    };
    // ---- (i) the rate-1/4 openings spliced in
    let (d4, d2) = (wire::path_len(&protocol::endpoint_pcs_params(&w16.sh)), wire::path_len(&protocol::endpoint_pcs_params(&r2.sh)));
    assert_eq!((d4, d2), (16, 15));
    let last = &frames[l - 1];
    let out_len = last.seg.out_open.as_ref().unwrap().size_bytes();
    let out_at = segs[l - 1].len() - wire::RUN_TRAILER - out_len;
    let in_at = out_at - last.seg.in_open.size_bytes();
    for (what, at, old, new, t4_site) in [
        ("(i) W16's rate-1/4 B_1 opening spliced into segment 2", in_at, &last.seg.in_open, &w16_b1, "incoming boundary or endpoint"),
        ("(i) W16's rate-1/4 output-endpoint opening spliced into segment 2", out_at, last.seg.out_open.as_ref().unwrap(), &w16_out, "run output endpoint"),
    ] {
        let bytes = splice_opening(&segs[l - 1], at, old, new);
        let n_spliced = bytes.len();
        let e = reject(what, l - 1, bytes);
        assert_eq!(e, format!("private run wire: segment {} is {n_spliced} B, the counted length is {}", l - 1, segs[l - 1].len()), "{what}");
        // the decoded opening, handed to the verifier's own T-4 and encoder
        let mut f = SegFrame::decode(&st, &segs[l - 1], l - 1);
        if t4_site == "run output endpoint" {
            f.seg.out_open = Some(new.clone());
        } else {
            f.seg.in_open = new.clone();
        }
        let t4 = super::hash_domain::segment_paths_are_the_tree_depth(&f.seg, &r2.sh).expect_err("T-4 accepted a rate-1/4 path at a rate-1/2 commitment");
        assert_eq!(t4, format!("private block: opened column 0 of the {t4_site} commitment carries a Merkle path of {d4} entries; this commitment's tree is {d2} deep (T-4)"));
        assert_eq!(f.try_encode().err().as_deref(), Some("private run wire: opening shape"), "{what}: the encoder wrote it");
        eprintln!("W16R2 F3 D12a | {what}, as a decoded opening | T-4: {t4}; the encoder: private run wire: opening shape");
    }
    // ---- (ii) one entry of one opened column (`out`: the segment's output
    // endpoint opening, otherwise the opening it closes)
    for (what, k, site, out) in [
        ("(ii) one B_1 column entry + 1", 2usize, "boundary 1", false),
        ("(ii) one B_0 column entry + 1", 1, "boundary 0", false),
        ("(ii) one input-endpoint column entry + 1", 0, "run input endpoint", false),
        ("(ii) one output-endpoint column entry + 1", 2, "run output endpoint", true),
    ] {
        let e = reject(what, k, edited(k, &|s: &mut wire::Segment| bump_column(if out { s.out_open.as_mut().unwrap() } else { &mut s.in_open })));
        assert!(e.starts_with(&format!("{site}: pcs zk: Merkle path for column ")) && e.ends_with(" fails"), "{what}: rejected, but not at {site}'s Merkle path: {e}");
    }
    // ---- (iii) one pad entry of a proximity vector + 1
    let n_e = 1usize << r2.sh.endpoint_log_n;
    for (what, site, out) in [("(iii) B_1's proximity vector, first pad entry + 1", "boundary 1", false), ("(iii) the output endpoint's proximity vector, first pad entry + 1", "run output endpoint", true)] {
        let e = reject(what, 2, edited(2, &|s: &mut wire::Segment| bump_prox_pad(if out { s.out_open.as_mut().unwrap() } else { &mut s.in_open }, n_e)));
        assert!(is_the_column_round_at(&e, site), "{what}: rejected, but not at {site}'s column round: {e}");
    }
    super::run::verify_run(&st, &blocks, &segs).expect("the unedited receipt still verifies");
}

/// One D55 tail, decoded with the verifier's own counts (its binding and S1
/// tag read from its own header, compared by `decode_tail` and again by the
/// verifier), so an edit re-encoded here carries the honest header and end
/// tag.
struct TailBytes {
    t: super::wire::fork::TailFrame,
    sh: Shape,
    l: usize,
    boundary_rows: usize,
    binding: [u8; 32],
    s1: [u8; 32],
    end: [u8; 32],
}

impl TailBytes {
    fn decode(st: &RunStatement, rc: &ForkReceipt) -> TailBytes {
        let fr = ForkRun::new(st, D55OptIn::unreviewed_prototype()).unwrap();
        let (sh, l) = (st.rs().sh().clone(), st.rs().l());
        let boundary_rows = st.boundary_spec(0).unwrap().commitment_rows();
        let binding = fr.binding().unwrap();
        assert_eq!(&rc.tail[8..40], &binding[..], "the tail's binding is not where this harness reads it");
        let s1: [u8; 32] = rc.tail[48..80].try_into().unwrap();
        let (t, end) = wire::fork::decode_tail(&rc.tail, &sh, &binding, l, boundary_rows, super::run::BOUNDARY_SITES, &s1).unwrap_or_else(|e| panic!("the tail does not decode: {e}"));
        let b = TailBytes { t, sh, l, boundary_rows, binding, s1, end };
        assert_eq!(b.encode(), rc.tail, "the tail does not re-encode to its own bytes");
        b
    }
    fn try_encode(&self) -> Result<Vec<u8>, String> {
        wire::fork::encode_tail(&self.t, &self.sh, &self.binding, self.l, self.boundary_rows, super::run::BOUNDARY_SITES, &self.s1, &self.end)
    }
    fn encode(&self) -> Vec<u8> {
        self.try_encode().unwrap()
    }
}

/// a D55 tail's openings in frame order: `B_0 .. B_{L-2}`, then the input
/// endpoint (`L - 1`), then the output endpoint (`L`)
fn tail_opening(t: &mut wire::fork::TailFrame, which: usize) -> &mut OpeningZk {
    let b = t.boundary_opens.len();
    if which < b {
        &mut t.boundary_opens[which]
    } else if which == b {
        &mut t.in_open
    } else {
        &mut t.out_open
    }
}

/// **Review F3, the D55 fork verifier.** The same W16R2 rung run (`L = 3`)
/// proved as a D55 fork run, and the W16 one for the splices. The honest
/// receipt verifies (and its re-encoded tail); the head, every fork frame and
/// the tail have their counted lengths and `decode_fork`'s openings their
/// counted sizes (F4 (b)). The controls, on the tail (which carries every
/// boundary and endpoint opening), each REJECTED by `verify_run_with_forks`
/// at the site asserted:
/// * (i) W16's rate-1/4 `B_1` and output-endpoint openings spliced in: the
///   tail is not its counted length; as decoded openings, T-4 "16 entries
///   ... 15 deep" at the verifier's own site, and the encoder refuses them;
/// * (ii) one opened column entry of `B_1`, `B_0`, the input endpoint and the
///   output endpoint: "Merkle path" at that site;
/// * (iii) one pad entry of `B_1`'s and of the output endpoint's proximity
///   vector + 1: the column round at that site.
#[test]
fn w16r2_f3_run_level_controls_under_the_d55_fork_verifier() {
    let (r2, w16) = (RungRun::new(shape::W16R2_RUNG_H24, 3), RungRun::new(shape::W16_RUNG_H24, 3));
    r2.assert_the_profile(shape::W16R2_INV_RATE, shape::W16R2_OPENED_COLS);
    w16.assert_the_profile(4, 256);
    let (st, rc) = r2.d55(93);
    let blocks = r2.blocks();
    let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
    super::run::fork::verify_run_with_forks(&fr, &blocks, &rc, 3).expect("the honest W16R2 L3 D55 fork run verifies");
    let l = st.rs().l();
    // ---- F4 (b): the head, the fork frames and the tail at their counts
    let rb = r2.sh.receipt_bytes();
    let (b_open, e_open) = run_opening_counts(&st);
    let binding = fr.binding().unwrap();
    assert_eq!(rc.head.len(), wire::fork::head_len(l));
    assert_eq!(rc.head.len(), 8 + 32 + 8 + 32 * (l - 1) + 32);
    for (k, bytes) in rc.forks.iter().enumerate() {
        let lay = Layout::for_shape(&st.stage_shape(k).unwrap()).unwrap();
        let counted = 8 + 32 + 8 + 8 + 32 + 3 * 32 + rb.slots + mask_opening_bytes(lay.m_rows()) + w16r2_opening_bytes(r2.sh.log_cols, r2.sh.inv_rate, r2.sh.a_groups(), lay.a_rows) + w16r2_opening_bytes(r2.sh.log_cols, r2.sh.inv_rate, r2.sh.h_groups(), lay.h_rows) + 32;
        assert_eq!((bytes.len(), wire::fork::fork_len(&lay)), (counted, counted), "fork {k}: the frame, the codec's fork_len and the count disagree");
        let start: [u8; 32] = bytes[56..88].try_into().unwrap();
        let (f, _) = wire::fork::decode_fork(bytes, &lay, &binding, l, k, &start).unwrap_or_else(|e| panic!("fork {k} does not decode: {e}"));
        assert_eq!((f.a_open.size_bytes(), f.h_open.size_bytes(), f.mask_open.size_bytes()), (rb.a_opening, rb.h_opening, rb.mask_opening), "fork {k}: an opening is not its counted size");
    }
    let tb = TailBytes::decode(&st, &rc);
    let tail_counted = 8 + 32 + 8 + 32 + (l - 1) * b_open + 2 * e_open + 32;
    assert_eq!((rc.tail.len(), wire::fork::tail_len(&r2.sh, l, tb.boundary_rows, super::run::BOUNDARY_SITES)), (tail_counted, tail_counted), "the tail, the codec's tail_len and the count disagree");
    assert!(tb.t.boundary_opens.iter().all(|o| o.size_bytes() == b_open) && tb.t.in_open.size_bytes() == e_open && tb.t.out_open.size_bytes() == e_open);
    super::run::fork::verify_run_with_forks(&fr, &blocks, &ForkReceipt { tail: tb.encode(), ..rc.clone() }, 3).expect("the re-encoded honest tail verifies");
    eprintln!("W16R2 F3 D55 | honest W16R2 rung L{l} fork run: verifies (and re-encoded); head {} B, forks {:?} B, tail {} B = the codec's counts = the count (boundary opening {b_open} B, endpoint opening {e_open} B at Q {})", rc.head.len(), rc.forks.iter().map(Vec::len).collect::<Vec<_>>(), rc.tail.len(), r2.sh.opened_cols);
    // ---- the rate-1/4 fork run whose openings are spliced in
    let (st4, rc4) = w16.d55(94);
    let fr4 = ForkRun::new(&st4, D55OptIn::unreviewed_prototype()).unwrap();
    super::run::fork::verify_run_with_forks(&fr4, &w16.blocks(), &rc4, 3).expect("the honest W16 (rate 1/4) L3 fork run verifies under its own profile");
    let tb4 = TailBytes::decode(&st4, &rc4);
    let reject = |what: &str, tail: Vec<u8>| -> String {
        let e = super::run::fork::verify_run_with_forks(&fr, &blocks, &ForkReceipt { tail, ..rc.clone() }, 3).err().unwrap_or_else(|| panic!("RUN CONTROL (D55) {what}: ACCEPTED"));
        eprintln!("W16R2 F3 D55 | {what} | REJECTED: {e}");
        e
    };
    let edited = |edit: &dyn Fn(&mut wire::fork::TailFrame)| -> Vec<u8> {
        let mut b = TailBytes::decode(&st, &rc);
        edit(&mut b.t);
        b.encode()
    };
    // ---- (i) the rate-1/4 openings spliced in
    let (d4, d2) = (wire::path_len(&protocol::endpoint_pcs_params(&w16.sh)), wire::path_len(&protocol::endpoint_pcs_params(&r2.sh)));
    let ep = protocol::endpoint_pcs_params(&r2.sh);
    let b1_at = 80 + b_open;
    let out_at = rc.tail.len() - 32 - e_open;
    for (what, at, old, new, site) in [
        ("(i) W16's rate-1/4 B_1 opening spliced into the tail", b1_at, &tb.t.boundary_opens[1], &tb4.t.boundary_opens[1], "boundary 1"),
        ("(i) W16's rate-1/4 output-endpoint opening spliced into the tail", out_at, &tb.t.out_open, &tb4.t.out_open, "run output endpoint"),
    ] {
        let tail = splice_opening(&rc.tail, at, old, new);
        let n_spliced = tail.len();
        let e = reject(what, tail);
        assert_eq!(e, format!("D55 wire: the tail is {n_spliced} B, the counted length is {}", rc.tail.len()), "{what}");
        let t4 = super::hash_domain::paths_are_the_tree_depth(site, &ep, new).expect_err("T-4 accepted a rate-1/4 path at a rate-1/2 commitment");
        assert_eq!(t4, format!("private block: opened column 0 of the {site} commitment carries a Merkle path of {d4} entries; this commitment's tree is {d2} deep (T-4)"));
        let mut b = TailBytes::decode(&st, &rc);
        if site == "boundary 1" {
            b.t.boundary_opens[1] = new.clone();
        } else {
            b.t.out_open = new.clone();
        }
        assert_eq!(b.try_encode().err().as_deref(), Some("D55 wire: tail opening shape"), "{what}: the encoder wrote it");
        eprintln!("W16R2 F3 D55 | {what}, as a decoded opening | T-4 at the verifier's `{site}` site: {t4}; the encoder: D55 wire: tail opening shape");
    }
    // ---- (ii) one entry of one opened column (`which`: the tail's openings
    // in frame order, B_0 .. B_{L-2}, then the input and output endpoints)
    for (what, site, which) in [
        ("(ii) one B_1 column entry + 1", "D55: boundary 1", 1usize),
        ("(ii) one B_0 column entry + 1", "D55: boundary 0", 0),
        ("(ii) one input-endpoint column entry + 1", "D55: run input endpoint", l - 1),
        ("(ii) one output-endpoint column entry + 1", "D55: run output endpoint", l),
    ] {
        let e = reject(what, edited(&|t: &mut wire::fork::TailFrame| bump_column(tail_opening(t, which))));
        assert!(e.starts_with(&format!("{site}: pcs zk: Merkle path for column ")) && e.ends_with(" fails"), "{what}: rejected, but not at {site}'s Merkle path: {e}");
    }
    // ---- (iii) one pad entry of a proximity vector + 1
    let n_e = 1usize << r2.sh.endpoint_log_n;
    for (what, site, which) in [("(iii) B_1's proximity vector, first pad entry + 1", "D55: boundary 1", 1usize), ("(iii) the output endpoint's proximity vector, first pad entry + 1", "D55: run output endpoint", l)] {
        let e = reject(what, edited(&|t: &mut wire::fork::TailFrame| bump_prox_pad(tail_opening(t, which), n_e)));
        assert!(is_the_column_round_at(&e, site), "{what}: rejected, but not at {site}'s column round: {e}");
    }
    super::run::fork::verify_run_with_forks(&fr, &blocks, &rc, 3).expect("the unedited fork receipt still verifies");
}

/// **Review F3 (iv): an endpoint policy whose endpoints were committed at
/// rate 1/4** (W16's, at the same plane, under W16's keys) handed to a W16R2
/// run: refused by ruling CS-4 (`policy_fits_the_shape`) inside the run
/// statement's constructor — before the run's header transcript exists, so
/// before any hash of the run. Both verifiers take that statement (D12a's
/// `verify_run` and D55's `ForkRun::new`), so neither can be reached with
/// it. The same planes under W16R2's own policy build a statement.
#[test]
fn w16r2_f3_an_endpoint_policy_committed_at_rate_one_quarter_is_refused_by_cs4() {
    let r2 = RungRun::new(shape::W16R2_RUNG_H24, 3);
    let w16sh = super::range16_tests::case(built(shape::W16_RUNG_H24), 3).0;
    assert_eq!((w16sh.t_pad, w16sh.d_pad), (r2.sh.t_pad, r2.sh.d_pad), "the two rungs do not share the endpoint plane");
    let (quarter, _) = prepare_endpoints(IoSpec::new_shaped(&w16sh, [95; 32], 0, 0).unwrap(), &r2.input, &r2.output).expect("the rate-1/4 endpoints commit");
    let e = r2.statement_on(95, quarter).err().expect("RUN CONTROL (iv): A RATE-1/4 ENDPOINT POLICY WAS ACCEPTED BY A W16R2 RUN");
    let (mine, theirs) = ((w16sh.endpoint_log_n, w16sh.endpoint_inv_rate, w16sh.endpoint_rows, w16sh.opened_cols), (r2.sh.endpoint_log_n, r2.sh.endpoint_inv_rate, r2.sh.endpoint_rows, r2.sh.opened_cols));
    assert_eq!(e, format!("private run: {}: its endpoint commitment parameters (log_n, rate, rows, opened columns) are {mine:?}, this shape's are {theirs:?}", super::CS4_POLICY_REFUSAL));
    eprintln!("W16R2 F3 (iv) | an endpoint policy committed at rate 1/4 handed to a W16R2 run | REFUSED before the run header: {e}");
    let (st, _) = r2.statement(96);
    assert_eq!(st.rs().sh().opened_cols, shape::W16R2_OPENED_COLS);
}

// ------------------------------------------------ the accounting inputs

/// **The inputs of `results/zk60_w16r2_20261101/ACCOUNTING.md`, from the
/// code.** One `W16R2-ACCOUNTING` line per profile (each W16R2 profile and
/// its W16 sibling): the regular commitments' geometry, the masking
/// commitment's constants, the layout's rows, the lookup counts and range
/// families (the LogUp term's `N` and `T_d`), and the slot table's
/// `sum (main + ext) degree` (the sumcheck term). The 8B counts are asserted
/// equal to the W16 review's (`REVIEW_W16_20261101.md` §1), so the recount
/// rests on the same `N`.
#[test]
fn w16r2_accounting_inputs_are_printed_from_the_code() {
    let mut names = Vec::new();
    for (r2, w16) in PAIRS {
        for p in [r2, w16] {
            let sh = built(p);
            let lay = Layout::for_shape(&sh).unwrap();
            let lookup_words: usize = sh.lookup_doms().iter().map(|d| lay.lookups(*d).len() * sh.size(*d)).sum();
            let (exp, act) = (sh.size(Dom::S), sh.size(Dom::F));
            let fams: Vec<(u32, usize)> = sh.range_families().iter().map(|f| (f.width, f.sub)).collect();
            let mut widths: Vec<u32> = fams.iter().map(|f| f.0).collect();
            widths.dedup();
            let range_entries: usize = widths.iter().map(|w| 1usize << w).sum();
            let sl = sh.slots();
            let sc: usize = (0..sh.n_slots()).map(|s| (sl[s].0 + sl[s].1) * sl[s].2).sum();
            let zc: usize = (0..sh.n_slots()).map(|s| 3 * (sl[s].0 + sl[s].1) + 3).sum();
            let (col, ecol) = sh.regular_column_terms_log2();
            let n = 1usize << sh.log_cols;
            let nn = n * sh.inv_rate;
            let k = n + sh.opened_cols;
            if sh.tokens == 128 {
                assert_eq!((lookup_words, exp, act, range_entries), (32_276_480, 524_288, 2_097_152, 110_772), "{}: the lookup counts are not the W16 review's", sh.name);
            }
            eprintln!(
                "W16R2-ACCOUNTING {{\"name\":\"{}\",\"profile\":\"{}\",\"tokens\":{},\"regime\":\"{:?}\",\"log_cols\":{},\"n\":{n},\"inv_rate\":{},\"N\":{nn},\"Q\":{},\"q_pad\":{},\"K\":{k},\"e_unique\":{},\"endpoint_log_n\":{},\"endpoint_inv_rate\":{},\"a_rows\":{},\"h_rows\":{},\"endpoint_rows\":{},\"m_rows\":{},\"mask_log_dom\":{},\"mask_log_msg\":{},\"mask_q\":{},\"lookup_words\":{lookup_words},\"exp_queries\":{exp},\"act_queries\":{act},\"range_families\":{:?},\"range_entries\":{range_entries},\"slots\":{},\"sumcheck_main_ext_degree\":{sc},\"zerocheck_allowance\":{zc},\"column_log2\":{col:.4},\"endpoint_column_log2\":{ecol:.4},\"receipt_bytes_counted\":{}}}",
                sh.name,
                sh.profile,
                sh.tokens,
                sh.column_regime(),
                sh.log_cols,
                sh.inv_rate,
                sh.opened_cols,
                ZkOpts::standard(&protocol::pcs_params_at(&sh)).q_pad,
                (nn - k) / 2,
                sh.endpoint_log_n,
                sh.endpoint_inv_rate,
                lay.a_rows,
                lay.h_rows,
                sh.endpoint_rows,
                lay.m_rows(),
                crate::zk::MASK_LOG_DOM,
                crate::zk::MASK_LOG_MSG,
                crate::zk::MASK_Q,
                fams,
                sh.n_slots(),
                sh.receipt_bytes().total,
            );
            names.push(sh.name);
        }
    }
    assert_eq!(names.len(), 6);
}

// ------------------------------------------------ the A/B on one binary

/// **THE A/B, W16 against W16R2 on one binary** (ignored; guarded, alone,
/// `HL_PB_ORACLE=0`). For each profile in `HL_W16R2_AB` (default the two 8B
/// T128 profiles), M4's trained recipe (synthetic diagonal weights, its
/// admissible input). One cold Metal pass each (kernel compiles), then
/// `HL_W16R2_AB_WARM` (default 3) warm passes INTERLEAVED across the arms;
/// the block core verified `HL_W16R2_AB_VERIFY` (default 3) times on the CPU
/// per arm; the core's bytes. `HL_METAL_TIMING=1` in a SEPARATE run gives
/// the GPU commit attribution (its `[ZK60-METAL] commit` lines).
#[cfg(feature = "gpu-metal")]
#[test]
#[ignore = "heavy: 8B T128 blocks on Metal, toggles HL_GPU in-process; run alone by name with HL_PB_ORACLE=0"]
fn w16r2_ab_w16_against_w16r2_on_one_binary() {
    use crate::private_block::shape::NormCalibration;
    let want = std::env::var("HL_W16R2_AB").unwrap_or_else(|_| "W16_8B_T128_H24,W16R2_8B_T128_H24".to_string());
    let warm: usize = std::env::var("HL_W16R2_AB_WARM").ok().and_then(|v| v.parse().ok()).unwrap_or(3).max(1);
    let verifies: usize = std::env::var("HL_W16R2_AB_VERIFY").ok().and_then(|v| v.parse().ok()).unwrap_or(3).max(1);
    struct Arm {
        sh: Shape,
        blk: BlockPublic,
        data: crate::private_block::accuracy_public::AccuracyPublic,
        public: AttentionPublic,
        ff: FeedForwardPublic,
        input: Vec<i16>,
        cores: Vec<f64>,
        last: Option<CoreProof>,
    }
    let mut arms: Vec<Arm> = Vec::new();
    for name in want.split(',') {
        let spec = shape::W16_PROFILES.iter().chain(shape::W16R2_PROFILES.iter()).find(|s| s.name == name).unwrap_or_else(|| panic!("{name}: not a W16 or W16R2 profile"));
        let cal = NormCalibration { tn: if spec.width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 };
        let original = Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20).unwrap();
        let (sh, data, public, ff) = super::range16_tests::case(original, 3);
        let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
        let mut seed = 0usize;
        let input = loop {
            let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + seed) % (41 + 20 * (seed % 3))) as i16 - 20).collect();
            match super::witness::build_accuracy(&sh, &public, &ff, &data, &input) {
                Ok(_) => break input,
                Err(_) if seed < 6 => seed += 1,
                Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
            }
        };
        arms.push(Arm { sh, blk, data, public, ff, input, cores: Vec::new(), last: None });
    }
    // one timed core proof on the device; the witness is built before the clock
    let pass = |a: &Arm| -> (f64, CoreProof) {
        let w = super::witness::build_accuracy(&a.sh, &a.public, &a.ff, &a.data, &a.input).unwrap();
        let lay = Layout::for_shape(&a.sh).unwrap();
        let (ein, eout) = io_planes(&a.sh, &w);
        let ntt = NttTables::new(protocol::ntt_log_at(&a.sh));
        let mut rng = ZkRng::new(20261101, b"zk60 W16R2 core");
        let mut tr = header(&a.sh, &lay);
        let mut ph = super::timing::Phases::start();
        let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
        std::env::set_var("HL_GPU", "1");
        let t = std::time::Instant::now();
        let core = protocol::prove_core(&a.sh, &lay, &a.blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the A/B core proof");
        let s = t.elapsed().as_secs_f64();
        std::env::remove_var("HL_GPU");
        (s, core)
    };
    for a in arms.iter() {
        let (s, _) = pass(a);
        eprintln!("W16R2-AB {} cold (kernel compiles) prove core {s:.3} s", a.sh.name);
    }
    for p in 0..warm {
        for a in arms.iter_mut() {
            let (s, core) = pass(a);
            eprintln!("W16R2-AB {} warm pass {p} prove core {s:.3} s", a.sh.name);
            a.cores.push(s);
            a.last = Some(core);
        }
    }
    let med = |v: &[f64]| -> f64 {
        let mut c = v.to_vec();
        c.sort_by(|x, y| x.partial_cmp(y).unwrap());
        c[c.len() / 2]
    };
    for a in arms.iter() {
        let core = a.last.as_ref().unwrap();
        let mut vs = Vec::new();
        for _ in 0..verifies {
            let t = std::time::Instant::now();
            verify(&a.sh, &a.blk, core).expect("the A/B core verifies");
            vs.push(t.elapsed().as_secs_f64());
        }
        let (bytes, ao, ho, mo, slots) = core_bytes(core);
        let rb = a.sh.receipt_bytes();
        let (col, _) = a.sh.regular_column_terms_log2();
        eprintln!(
            "W16R2-AB SUMMARY {} rate 1/{} Q {} | prove core warm {:?} s, median {:.3} s | verify core (CPU) {:?} s, median {:.3} s | core bytes {bytes} (A open {ao}, H open {ho}, M open {mo}, slots {slots}) | one endpoint/boundary opening (counted) {} B | column term 2^{col:.3}",
            a.sh.name,
            a.sh.inv_rate,
            a.sh.opened_cols,
            a.cores.iter().map(|s| (s * 1000.0).round() / 1000.0).collect::<Vec<_>>(),
            med(&a.cores),
            vs.iter().map(|s| (s * 1000.0).round() / 1000.0).collect::<Vec<_>>(),
            med(&vs),
            rb.endpoint_openings / 2,
        );
    }
    let (compile, rounds) = crate::gpu::metal_sumcheck_stats();
    eprintln!("W16R2-AB device evidence: Metal kernel compile {compile:.3} s, device sumcheck rounds {rounds:.3} s");
}

/// **D63 L3 finding F16.** The run's context is never absorbed, so the run statement must bind it to
/// the context its endpoint spec carries, which is absorbed. A statement whose context differs from
/// its endpoint spec's is REFUSED; the matching one is built.
#[test]
fn f16_a_run_context_that_differs_from_the_endpoint_spec_is_refused() {
    let r = RungRun::new(shape::W16R2_RUNG_H24, 1);
    let (expected, _) = prepare_endpoints(IoSpec::new_shaped(&r.sh, [7; 32], 0, 0).unwrap(), &r.input, &r.output).unwrap();
    let e = r.statement_on(8, expected).err().expect("a run statement with a context other than its endpoint spec's was built");
    assert!(e.contains("differs from the context its endpoint spec binds"), "{e}");
    let (expected, _) = prepare_endpoints(IoSpec::new_shaped(&r.sh, [7; 32], 0, 0).unwrap(), &r.input, &r.output).unwrap();
    r.statement_on(7, expected).expect("the matching context builds");
}

// ------------------------------------------- A8: the openings' store folds

/// splitmix64, for the A8 fold tests' words and coefficients
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
fn a8_mix(x: &mut u64) -> u64 {
    *x = x.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *x;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

/// the per-term reference (`fold_rows_host`, zkp-core's arithmetic) of
/// `rho^T [M | pads]`: the message fold, then the pad fold appended, as
/// `pcs::fold_rows_multi_zk` forms the hiding opening's vectors before A8
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
fn a8_reference(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>], pads: Option<(&[u64], usize)>) -> Vec<Vec<Fp2>> {
    let mut m = crate::gpu::metal_fold_rows_host_for_test(src, rows, n, nn, ir, rhos);
    if let Some((p, q)) = pads {
        let pf = crate::gpu::metal_fold_rows_host_for_test(p, rows, q, q, 1, rhos);
        for (a, b) in m.iter_mut().zip(pf) {
            a.extend(b);
        }
    }
    m
}

/// every A8 form at the chunk widths `widths` (and the rule's), with and
/// without the small-word path, against the per-term reference; and the M11
/// forms on the message part. Returns how many forms were compared.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[allow(clippy::too_many_arguments)]
fn a8_check_forms(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>], pads: Option<(&[u64], usize)>, widths: &[usize], what: &str) -> usize {
    use crate::gpu::MetalA8Seg as Seg;
    let want = a8_reference(src, rows, n, nn, ir, rhos, pads);
    let msg_want: Vec<Vec<Fp2>> = want.iter().map(|v| v[..n].to_vec()).collect();
    assert!(crate::gpu::metal_fold_rows_host_m11_for_test(src, rows, n, nn, ir, rhos) == msg_want, "{what}: the M11 forms differ from the per-term fold");
    let mut compared = 1;
    for small in [false, true] {
        // the production options (`a8_opts`), then each width without prefetch
        let prod = crate::gpu::metal_a8_opts(n, small);
        {
            let mut segs = vec![Seg { src, n, nn, ir }];
            if let Some((p, q)) = pads {
                segs.push(Seg { src: p, n: q, nn: q, ir: 1 });
            }
            assert!(crate::gpu::metal_fold_segments_a8_opts(&segs, rows, rhos, prod) == want, "{what}: the A8 fold at the production options ({prod:?}) differs from the per-term fold");
            assert!(crate::gpu::metal_fold_rows_host_a8(src, rows, n, nn, ir, rhos, prod) == msg_want, "{what}: the A8 message fold at the production options ({prod:?}) differs from the per-term fold");
            compared += 2;
        }
        for &w in widths.iter().chain(std::iter::once(&prod.w)) {
            let mut segs = vec![Seg { src, n, nn, ir }];
            if let Some((p, q)) = pads {
                segs.push(Seg { src: p, n: q, nn: q, ir: 1 });
            }
            let got = crate::gpu::metal_fold_segments_a8(&segs, rows, rhos, w, small);
            assert!(got == want, "{what}: the A8 fold (w {w}, small {small}) differs from the per-term fold");
            let got1 = crate::gpu::metal_fold_rows_host_a8(src, rows, n, nn, ir, rhos, crate::gpu::MetalA8Opts { w, small, pf: 0, neon: false });
            assert!(got1 == msg_want, "{what}: the A8 message fold (w {w}, small {small}) differs from the per-term fold");
            compared += 2;
            // the prefetch distances and the NEON small lanes
            for (pf, neon) in [(1usize, false), (2, true), (5, true)] {
                let opts = crate::gpu::MetalA8Opts { w, small, pf, neon };
                let got = crate::gpu::metal_fold_segments_a8_opts(&segs, rows, rhos, opts);
                assert!(got == want, "{what}: the A8 fold ({opts:?}) differs from the per-term fold");
                compared += 1;
            }
        }
    }
    compared
}

/// **[A8] every store fold form is the per-term fold, word for word.** Random
/// canonical words of every kind (full width, `p - 1`, small signed integers of
/// both signs, the small path's edges `2^15 - 1`, `2^15`, `p - 2^15`,
/// `p - 2^15 - 1`), rows that are all small, small but for the odd word, full
/// or zero; coefficient vectors dense, in blocks, sparse and nearly empty, with
/// entries `1`, `p - 1`, `p - 2` and random; strided (systematic) and plain
/// sources; with and without the pad segment (`q` 1, 7, 280); chunk widths
/// from 1 to wider than the rows; no vectors at all. Then the small path's
/// overflow edge: `2^16 - 1` rows of the largest small words against
/// coefficients whose 32-bit halves are both near `2^32`, and `2^16` rows,
/// where the path must stand aside.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
fn a8_store_fold_forms_equal_the_per_term_fold_word_for_word() {
    let p = crate::field::P;
    let h = 1u64 << 15;
    let small_edges = [0u64, 1, h - 1, p - h, p - 1];
    let edges = [0u64, 1, h - 1, h, p - h, p - h - 1, 1 << 16, (1 << 16) - 1, p - 1, p - 2];
    let mut seed = 0xA8A8_2026_1105u64;
    let mut compared = 0usize;
    let shapes: [(usize, usize, usize, usize, usize, Option<usize>); 9] = [
        (1, 1, 1, 1, 1, None),
        (37, 300, 300, 1, 3, Some(7)),
        (64, 513, 2052, 4, 2, None),
        (9, 256, 512, 2, 5, Some(280)),
        (300, 1024, 1024, 1, 37, Some(280)),
        (70, 100, 100, 1, 0, None),
        (40, 64, 64, 1, 10, Some(1)),
        (5, 33, 33, 1, 17, Some(280)),
        (128, 96, 96, 1, 1, None),
    ];
    for (si, &(rows, n, nn, ir, k, q)) in shapes.iter().enumerate() {
        let word = |kind: u64, s: &mut u64| -> u64 {
            let r = a8_mix(s);
            match kind {
                // all small: small signed integers of both signs and the small edges
                0 => match r % 4 {
                    0 => r % h,
                    1 => p - 1 - (r >> 8) % h,
                    2 => small_edges[(r >> 4) as usize % small_edges.len()],
                    _ => (r >> 9) % 256,
                },
                // small but for the odd word (an edge just outside the path)
                1 => {
                    if r % 29 == 0 {
                        edges[(r >> 5) as usize % edges.len()]
                    } else {
                        r % h
                    }
                }
                2 => match r % 3 {
                    0 => r % p,
                    1 => p - 1 - (r >> 3) % 4,
                    _ => (r >> 7) % (1 << 32),
                },
                _ => 0,
            }
        };
        let kinds: Vec<u64> = (0..rows).map(|i| [0u64, 0, 1, 2, 0, 3, 0, 2][(i + si) % 8]).collect();
        let src: Vec<u64> = (0..rows * nn).map(|e| word(kinds[e / nn], &mut seed)).collect();
        let pads: Option<Vec<u64>> = q.map(|q| (0..rows * q).map(|e| if e % 3 == 0 { word(0, &mut seed) } else { word(2, &mut seed) }).collect());
        let rhos: Vec<Vec<Fp2>> = (0..k)
            .map(|g| {
                (0..rows)
                    .map(|i| {
                        let on = match g % 4 {
                            0 => true,
                            1 => (i / 8) % 3 == g % 3,
                            2 => a8_mix(&mut seed) % 5 == 0,
                            _ => g % 8 == 3 && i == rows / 2,
                        };
                        if !on {
                            return Fp2::ZERO;
                        }
                        let r = a8_mix(&mut seed);
                        match r % 6 {
                            0 => Fp2::new(Fp(p - 1), Fp(p - 2)),
                            1 => Fp2::new(Fp(1), Fp(0)),
                            2 => Fp2::new(Fp(0), Fp(p - 1)),
                            _ => Fp2::new(Fp(a8_mix(&mut seed) % p), Fp(a8_mix(&mut seed) % p)),
                        }
                    })
                    .collect()
            })
            .collect();
        let pads_ref = pads.as_ref().map(|v| (v.as_slice(), q.unwrap()));
        compared += a8_check_forms(&src, rows, n, nn, ir, &rhos, pads_ref, &[1, 3, 32, 64, 512, 4096], &format!("shape {si} ({rows} x {n}, nn {nn}, ir {ir}, k {k}, q {q:?})"));
    }
    // the small path's overflow edge: every lane at its largest sum
    for rows in [(1usize << 16) - 1, 1 << 16] {
        let n = 3;
        let src: Vec<u64> = (0..rows * n).map(|e| [h - 1, h - 1, p - h][e % 3]).collect();
        let rhos = vec![vec![Fp2::new(Fp(p - 2), Fp(0xFFFF_FFFE_FFFF_FFFE)); rows], (0..rows).map(|i| if i % 2 == 0 { Fp2::new(Fp(0xFFFF_FFFF), Fp(p - 2)) } else { Fp2::ZERO }).collect()];
        compared += a8_check_forms(&src, rows, n, n, 1, &rhos, None, &[1, 2, 3], &format!("the overflow edge at {rows} rows"));
    }
    eprintln!("A8-FOLD-EQUAL: {compared} fold forms equal the per-term fold, word for word");
}

/// one seeded W16R2 core proof's digest (as [`seeded_digest`]) under a store
/// fold form, with the folds' inputs captured; restores the form
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
fn a8_digest_under(sh: &Shape, blk: &BlockPublic, w: Witness, form: crate::gpu::MetalA8Form) -> (String, Vec<crate::gpu::MetalFoldCapture>) {
    let own = crate::gpu::metal_set_a8_fold_for_test(Some(form));
    crate::gpu::metal_fold_capture_for_test(true);
    let d = seeded_digest(sh, blk, w);
    let caps = crate::gpu::metal_fold_capture_for_test(false);
    crate::gpu::metal_set_a8_fold_for_test(own);
    (d, caps)
}

/// **[A8] the W16R2 rung's golden under every store fold form, and every fold
/// of it word for word.** The seeded rung proof on the device under the M11
/// forms, the row-sparse form and the small-word form (the default): every
/// digest is the CPU's, which is the golden. Every fold each proof made is captured and folded
/// again by every form at several chunk widths, against the per-term fold,
/// word for word. Toggles `HL_GPU` in-process, so it is ignored and run alone
/// by name (`HL_GPU_REQUIRED=1`).
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A8: toggles HL_GPU and the store fold's form in-process; run alone by name on a Mac, HL_GPU_REQUIRED=1"]
fn a8_w16r2_rung_golden_under_every_store_fold_form() {
    use crate::gpu::MetalA8Form as F;
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    std::env::remove_var("HL_GPU");
    let cpu = seeded_digest(&sh, &blk, copy(&w));
    assert!(cpu.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's digest moved");
    std::env::set_var("HL_GPU", "1");
    for form in [F::M11, F::Sparse, F::Small] {
        let before = crate::gpu::metal_sumcheck_stats().1;
        let (d, caps) = a8_digest_under(&sh, &blk, copy(&w), form);
        let ran = crate::gpu::metal_sumcheck_stats().1 - before;
        assert_eq!(d, cpu, "the Metal W16R2 rung proof under the store fold form {form:?} differs from the CPU's");
        assert!(ran > 0.0, "no sumcheck round ran on the device");
        assert!(!caps.is_empty(), "no store fold was captured under {form:?}");
        let mut compared = 0;
        for (ci, c) in caps.iter().enumerate() {
            let pads = c.pads.as_ref().map(|(p, q)| (p.as_slice(), *q));
            assert_eq!(pads.is_some(), form != F::M11, "the fold under {form:?} took the pads: {}", pads.is_some());
            compared += a8_check_forms(&c.src, c.rows, c.n, c.nn, c.ir, &c.rhos, pads, &[32, 64, 256], &format!("rung fold {ci} under {form:?}"));
        }
        eprintln!(
            "A8-RUNG {} form {form:?}: digest {} (the golden); {} folds captured ({}); {compared} forms equal the per-term fold word for word",
            sh.name,
            &d[..8],
            caps.len(),
            caps.iter().map(|c| format!("{} rho x {} rows x {}{}", c.rhos.len(), c.rows, c.n, c.pads.as_ref().map(|(_, q)| format!(" + {q}")).unwrap_or_default())).collect::<Vec<_>>().join(", ")
        );
    }
    std::env::remove_var("HL_GPU");
}

/// **[A8, census and bench, ignored]** one W16R2 8B T128 block
/// (`HL_A8_PROFILE`, w16r2_ab's recipe) proved on the device under each store
/// fold form (the phase clock on; every digest equal), the inputs of its two
/// store folds captured; then for each fold: its shape, the coefficient
/// vectors' sparsity, how many of its words are small signed integers, and
/// every fold form timed in rayon pools of `HL_A8_BENCH_THREADS` (default 6
/// and 32) threads, `HL_A8_BENCH_REPS` (default 7) times, each checked against
/// the per-term fold word for word.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A8: heavy (one 8B T128 block on Metal), toggles HL_GPU; run alone by name with HL_PB_ORACLE=0"]
fn a8_store_fold_census_and_bench_on_the_8b_block() {
    use crate::gpu::MetalA8Form as F;
    use crate::gpu::MetalA8Seg as Seg;
    use crate::private_block::shape::NormCalibration;
    let name = std::env::var("HL_A8_PROFILE").unwrap_or_else(|_| "W16R2_8B_T128_H24".to_string());
    let threads: Vec<usize> = std::env::var("HL_A8_BENCH_THREADS").unwrap_or_else(|_| "6,32".to_string()).split(',').map(|t| t.trim().parse().expect("HL_A8_BENCH_THREADS")).collect();
    let reps: usize = std::env::var("HL_A8_BENCH_REPS").ok().and_then(|v| v.parse().ok()).unwrap_or(7).max(1);
    let spec = shape::W16_PROFILES.iter().chain(shape::W16R2_PROFILES.iter()).find(|s| s.name == name).unwrap_or_else(|| panic!("{name}: not a W16 or W16R2 profile"));
    let cal = NormCalibration { tn: if spec.width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 };
    let original = Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20).unwrap();
    let (sh, data, public, ff) = super::range16_tests::case(original, 3);
    let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
    let mut seed = 0usize;
    let input = loop {
        let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + seed) % (41 + 20 * (seed % 3))) as i16 - 20).collect();
        match super::witness::build_accuracy(&sh, &public, &ff, &data, &input) {
            Ok(_) => break input,
            Err(_) if seed < 6 => seed += 1,
            Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
        }
    };
    let lay = Layout::for_shape(&sh).unwrap();
    eprintln!("A8-CENSUS {} A rows {} H rows {} n {}", sh.name, lay.a_rows, lay.h_rows, lay.n());
    // the block on the device: a cold pass, then each form with the phase clock
    std::env::set_var("HL_GPU", "1");
    let prove_once = |form: F, capture: bool| -> (f64, String, Vec<(String, f64)>, Vec<crate::gpu::MetalFoldCapture>) {
        let w = super::witness::build_accuracy(&sh, &public, &ff, &data, &input).unwrap();
        let (ein, eout) = io_planes(&sh, &w);
        let ntt = NttTables::new(protocol::ntt_log_at(&sh));
        let mut rng = ZkRng::new(20261101, b"zk60 W16R2 core");
        let mut tr = header(&sh, &lay);
        let own = crate::gpu::metal_set_a8_fold_for_test(Some(form));
        crate::gpu::metal_fold_capture_for_test(capture);
        super::timing::force(Some(true));
        let mut ph = super::timing::Phases::start();
        let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
        let t = std::time::Instant::now();
        let core = protocol::prove_core(&sh, &lay, &blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the A8 core proof");
        let s = t.elapsed().as_secs_f64();
        super::timing::force(None);
        let caps = crate::gpu::metal_fold_capture_for_test(false);
        crate::gpu::metal_set_a8_fold_for_test(own);
        let text = format!("{:?}|{:?}|{:?}|{:?}|{:?}|{:?}", core.a_root, core.h_root, core.slots, core.a_open, core.h_open, tr.state());
        (s, blake3::hash(text.as_bytes()).to_hex().to_string(), ph.rows_for_test(), caps)
    };
    let (s, d0, _, _) = prove_once(F::M11, false);
    eprintln!("A8-CENSUS cold pass (M11 forms) prove core {s:.3} s digest {}", &d0[..16]);
    let mut caps = Vec::new();
    for (label, form) in [("m11", F::M11), ("sparse", F::Sparse), ("small", F::Small), ("m11", F::M11), ("sparse", F::Sparse), ("small", F::Small)] {
        let (s, d, rows, c) = prove_once(form, caps.is_empty() && form == F::Sparse);
        assert_eq!(d, d0, "the 8B block's proof under {label} differs");
        if !c.is_empty() {
            caps = c;
        }
        let open: Vec<String> = rows.iter().filter(|(l, _)| l.contains("open")).map(|(l, v)| format!("{l} {:.2} ms", v * 1e3)).collect();
        eprintln!("A8-CENSUS prove core [{label}] {s:.3} s (digest equal) | {}", open.join(" | "));
    }
    assert!(!caps.is_empty(), "no store fold was captured");
    eprintln!("A8-CENSUS {} store folds captured: {}", caps.len(), caps.iter().map(|c| format!("{} rho x {} rows", c.rhos.len(), c.rows)).collect::<Vec<_>>().join(", "));
    let p = crate::field::P;
    let half = 1u64 << 15;
    for (fi, c) in caps.iter().enumerate() {
        let (rows, n, k) = (c.rows, c.n, c.rhos.len());
        let (pw, q) = c.pads.as_ref().map(|(p, q)| (p.as_slice(), *q)).expect("the captured fold took the pads");
        // the coefficient vectors' sparsity
        let nnz: Vec<usize> = c.rhos.iter().map(|r| r[..rows].iter().filter(|x| !x.is_zero()).count()).collect();
        let per_row: Vec<usize> = (0..rows).map(|i| c.rhos.iter().filter(|r| !r[i].is_zero()).count()).collect();
        let total: usize = nnz.iter().sum();
        // the words: whole rows and 32-column chunks of small signed integers
        let small = |v: u64| v < half || v >= p - half;
        let small32 = |v: u64| v < (1 << 31) || v >= p - (1 << 31);
        let row_small = (0..rows).filter(|&i| c.src[i * n..(i + 1) * n].iter().all(|&v| small(v))).count();
        let row_small32 = (0..rows).filter(|&i| c.src[i * n..(i + 1) * n].iter().all(|&v| small32(v))).count();
        let chunk_small: Vec<usize> = (0..rows).map(|i| c.src[i * n..(i + 1) * n].chunks(32).filter(|ch| ch.iter().all(|&v| small(v))).count()).collect();
        let upd_small: usize = (0..rows).map(|i| per_row[i] * chunk_small[i]).sum();
        let upd_all: usize = total * n.div_ceil(32);
        let words_small = c.src.iter().filter(|&&v| small(v)).count();
        eprintln!(
            "A8-CENSUS fold {fi}: {k} rho x {rows} rows x ({n} + {q}) cols | nonzero coefficients {total} ({:.2} rows' worth; per vector {:?}) | per row max {}, rows with none {} | small16 rows {row_small} of {rows}, small32 rows {row_small32}; small16 words {:.1}%; small16 32-column chunks, weighted by coefficients, {:.1}% of the updates",
            total as f64 / rows as f64,
            nnz,
            per_row.iter().max().unwrap(),
            per_row.iter().filter(|&&x| x == 0).count(),
            100.0 * words_small as f64 / c.src.len() as f64,
            100.0 * upd_small as f64 / upd_all.max(1) as f64
        );
        let want = a8_reference(&c.src, rows, n, n, 1, &c.rhos, Some((pw, q)));
        // the forms: before A8 (the M11 message fold, then the pads per-term on
        // one chunk, appended), and the A8 forms over both segments; `true`
        // compares the whole vectors, `false` the message part
        type Run<'a> = Box<dyn Fn() -> Vec<Vec<Fp2>> + Sync + 'a>;
        let mut forms: Vec<(String, bool, Run)> = Vec::new();
        forms.push((
            "m11 + pads per-term (before A8)".into(),
            true,
            Box::new(|| {
                let mut m = crate::gpu::metal_fold_rows_host_m11_for_test(&c.src, rows, n, n, 1, &c.rhos);
                let pf = crate::gpu::metal_fold_rows_host_for_test(pw, rows, q, q, 1, &c.rhos);
                for (a, b) in m.iter_mut().zip(pf) {
                    a.extend(b);
                }
                m
            }),
        ));
        forms.push(("  of which the m11 message fold".into(), false, Box::new(|| crate::gpu::metal_fold_rows_host_m11_for_test(&c.src, rows, n, n, 1, &c.rhos))));
        let widths: Vec<usize> = std::env::var("HL_A8_BENCH_W").unwrap_or_else(|_| "128,256,512,1024".to_string()).split(',').map(|t| t.trim().parse().expect("HL_A8_BENCH_W")).collect();
        let pfs: Vec<usize> = std::env::var("HL_A8_BENCH_PF").unwrap_or_else(|_| "0,1,2".to_string()).split(',').map(|t| t.trim().parse().expect("HL_A8_BENCH_PF")).collect();
        for small in [false, true] {
            for &w in &widths {
                for &pf in &pfs {
                    for neon in if small { vec![false, true] } else { vec![false] } {
                        let segs = [Seg { src: &c.src, n, nn: n, ir: 1 }, Seg { src: pw, n: q, nn: q, ir: 1 }];
                        let opts = crate::gpu::MetalA8Opts { w, small, pf, neon };
                        forms.push((format!("a8 {} w {w} pf {pf}{}", if small { "small" } else { "sparse" }, if neon { " neon" } else { "" }), true, Box::new(move || crate::gpu::metal_fold_segments_a8_opts(&segs, rows, &c.rhos, opts))));
                    }
                }
            }
        }
        // six at once, each in its own pool of six threads (six forks folding together)
        let six: Vec<rayon::ThreadPool> = (0..6).map(|_| rayon::ThreadPoolBuilder::new().num_threads(6).build().expect("a rayon pool")).collect();
        for (label, _, f) in &forms {
            let mut ms = Vec::with_capacity(reps);
            for _ in 0..reps {
                let s = std::time::Instant::now();
                std::thread::scope(|sc| {
                    for p in &six {
                        sc.spawn(move || p.install(f).len());
                    }
                });
                ms.push(s.elapsed().as_secs_f64() * 1e3);
            }
            ms.sort_by(|a, b| a.partial_cmp(b).unwrap());
            eprintln!("A8-BENCH fold {fi} ({k} rho x {rows} rows) six x 6: {label:<46} min {:>7.2} ms  median {:>7.2} ms  (six folds at once)", ms[0], ms[ms.len() / 2]);
        }
        // the pads alone, per-term: one chunk, so one thread whatever the pool
        let pads_alone = || crate::gpu::metal_fold_rows_host_for_test(pw, rows, q, q, 1, &c.rhos);
        for &t in &threads {
            let pool = rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("a rayon pool");
            let mut ms_p = Vec::new();
            for _ in 0..reps {
                let s = std::time::Instant::now();
                let got = pool.install(pads_alone);
                ms_p.push(s.elapsed().as_secs_f64() * 1e3);
                assert!(got.iter().zip(want.iter()).all(|(a, b)| a[..] == b[n..]), "fold {fi}: the per-term pad fold differs");
            }
            ms_p.sort_by(|a, b| a.partial_cmp(b).unwrap());
            eprintln!("A8-BENCH fold {fi} ({k} rho x {rows} rows) pool {t:>2}: {:<46} min {:>7.2} ms  median {:>7.2} ms  (equal: yes)", "  of which the pads per-term (one chunk)", ms_p[0], ms_p[ms_p.len() / 2]);
            for (label, whole, f) in &forms {
                let mut ms = Vec::with_capacity(reps);
                for _ in 0..reps {
                    let s = std::time::Instant::now();
                    let got = pool.install(f);
                    ms.push(s.elapsed().as_secs_f64() * 1e3);
                    if *whole {
                        assert!(got == want, "fold {fi}: {label} differs from the per-term fold");
                    } else {
                        assert!(got.len() == want.len() && got.iter().zip(want.iter()).all(|(a, b)| a[..] == b[..n]), "fold {fi}: {label} differs from the per-term fold");
                    }
                }
                ms.sort_by(|a, b| a.partial_cmp(b).unwrap());
                eprintln!("A8-BENCH fold {fi} ({k} rho x {rows} rows) pool {t:>2}: {label:<46} min {:>7.2} ms  median {:>7.2} ms  (equal: yes)", ms[0], ms[ms.len() / 2]);
            }
        }
    }
    std::env::remove_var("HL_GPU");
}

// ------------------------------------------------------------ [A14] the forks' remaining host work

/// [A14] the six settings of A14's three forms: (label, the generator's XOF,
/// a long absorb in parallel, the lazy sums). `a14old` is the tree before A14,
/// `a14new` every form on; the default is `lazy1 only` (the parallel absorb and
/// the lane XOF are opt-in), and `xof8+lazy1` is the default A14 proposed.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
const A14_SETTINGS: [(&str, zkp_core::rng::XofForm, bool, bool); 6] = [
    ("a14old", zkp_core::rng::XofForm::Blake3, false, false),
    ("xof8 only", zkp_core::rng::XofForm::Lanes8, false, false),
    ("trpar only", zkp_core::rng::XofForm::Blake3, true, false),
    ("lazy1 only", zkp_core::rng::XofForm::Blake3, false, true),
    ("a14new", zkp_core::rng::XofForm::Lanes8, true, true),
    ("xof8+lazy1", zkp_core::rng::XofForm::Lanes8, false, true),
];

/// [A14] put one setting in force for the process, or (`None`) the environment's
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
fn a14_set(s: Option<(zkp_core::rng::XofForm, bool, bool)>) {
    zkp_core::rng::set_xof_form(s.map(|s| s.0));
    crate::transcript::set_absorb_parallel(s.map(|s| s.1));
    super::argument::set_lazy_for_test(s.map(|s| s.2));
}

/// **[A14] the W16R2 rung's golden under every setting of A14's forms.** The
/// seeded rung proof on the CPU under the tree before A14, every form on and
/// the A14 default, then on the device under all six settings (each form
/// alone, all off, all on, the default): every digest is the CPU's, which is
/// the golden `96e4f0b6`.
/// Toggles `HL_GPU` and the forms in-process, so it is ignored and run alone
/// by name (`HL_GPU_REQUIRED=1`).
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A14: toggles HL_GPU and the A14 forms in-process; run alone by name on a Mac, HL_GPU_REQUIRED=1"]
fn a14_w16r2_rung_golden_under_every_a14_setting() {
    let (sh, blk, w) = rung_case(shape::W16R2_RUNG_H24);
    std::env::remove_var("HL_GPU");
    let mut cpu: Option<String> = None;
    for (label, x, p, l) in [A14_SETTINGS[0], A14_SETTINGS[4], A14_SETTINGS[5]] {
        a14_set(Some((x, p, l)));
        let d = seeded_digest(&sh, &blk, copy(&w));
        a14_set(None);
        assert!(d.starts_with(W16R2_RUNG_GOLDEN), "the W16R2 rung's CPU digest under {label} moved: {}", &d[..8]);
        eprintln!("A14-RUNG {} CPU [{label}]: digest {} (the golden)", sh.name, &d[..8]);
        cpu.get_or_insert(d);
    }
    let cpu = cpu.unwrap();
    std::env::set_var("HL_GPU", "1");
    for (label, x, p, l) in A14_SETTINGS {
        let before = crate::gpu::metal_sumcheck_stats().1;
        a14_set(Some((x, p, l)));
        let d = seeded_digest(&sh, &blk, copy(&w));
        a14_set(None);
        let ran = crate::gpu::metal_sumcheck_stats().1 - before;
        assert_eq!(d, cpu, "the Metal W16R2 rung proof under {label} differs from the CPU's");
        assert!(ran > 0.0, "no sumcheck round ran on the device under {label}");
        eprintln!("A14-RUNG {} Metal [{label}]: digest {} (the golden)", sh.name, &d[..8]);
    }
    std::env::remove_var("HL_GPU");
}

/// **[A14, ignored] one W16R2 8B T128 block's core proof under every setting
/// of A14's forms** (the 8B block's digest unchanged): a8's census recipe (the
/// trained calibration, a seeded generator, the tagged header), proved on the
/// device under each of the six settings, the digest of the whole core proof
/// and the transcript's final state equal in every one. At 8B every A14 form
/// is on the path: `fill_fp`'s parallel chunks, the openings' long absorbs and
/// the matmul planes' accumulating tables. Heavy; run alone by name with
/// `HL_PB_ORACLE=0`.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A14: heavy (one 8B T128 block on Metal, thirteen times), toggles HL_GPU; run alone by name with HL_PB_ORACLE=0"]
fn a14_the_8b_block_proves_the_same_under_every_a14_setting() {
    use crate::private_block::shape::NormCalibration;
    let spec = shape::W16R2_PROFILES.iter().find(|s| s.name == "W16R2_8B_T128_H24").expect("the W16R2 8B profile");
    let cal = NormCalibration { tn: if spec.width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 };
    let original = Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20).unwrap();
    let (sh, data, public, ff) = super::range16_tests::case(original, 3);
    let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
    let mut seed = 0usize;
    let input = loop {
        let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + seed) % (41 + 20 * (seed % 3))) as i16 - 20).collect();
        match super::witness::build_accuracy(&sh, &public, &ff, &data, &input) {
            Ok(_) => break input,
            Err(_) if seed < 6 => seed += 1,
            Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
        }
    };
    let lay = Layout::for_shape(&sh).unwrap();
    std::env::set_var("HL_GPU", "1");
    let prove_once = |s: (zkp_core::rng::XofForm, bool, bool)| -> (f64, String) {
        let w = super::witness::build_accuracy(&sh, &public, &ff, &data, &input).unwrap();
        let (ein, eout) = io_planes(&sh, &w);
        let ntt = NttTables::new(protocol::ntt_log_at(&sh));
        let mut rng = ZkRng::new(20261105, b"zk60 A14 core");
        let mut tr = header(&sh, &lay);
        let mut ph = super::timing::Phases::start();
        let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
        a14_set(Some(s));
        let t = std::time::Instant::now();
        let core = protocol::prove_core(&sh, &lay, &blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the A14 core proof");
        let secs = t.elapsed().as_secs_f64();
        a14_set(None);
        let text = format!(
            "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
            core.a_root, core.h_root, core.mask_root, core.slots, core.mask_open, core.a_open, core.h_open, core.io_claims, core.order, core.lookups, tr.state()
        );
        (secs, blake3::hash(text.as_bytes()).to_hex().to_string())
    };
    let (s0, d0) = prove_once((A14_SETTINGS[0].1, A14_SETTINGS[0].2, A14_SETTINGS[0].3));
    eprintln!("A14-8B cold pass [a14old] prove core {s0:.3} s, digest {}", &d0[..16]);
    for (label, x, p, l) in A14_SETTINGS.iter().chain(A14_SETTINGS.iter()) {
        let (s, d) = prove_once((*x, *p, *l));
        assert_eq!(d, d0, "the 8B block's core proof under {label} differs");
        eprintln!("A14-8B prove core [{label}] {s:.3} s, digest {} (equal)", &d[..16]);
    }
    std::env::remove_var("HL_GPU");
}

// ---- [A15] the sealing pool: every witness plane, in every pool (efficiency plan A15) ----

/// [A15] where one witness of a chain is built: on the calling thread (the global
/// pool), inside a rayon pool, or in the trained stack's sealing pool
#[derive(Clone, Copy)]
enum A15At<'p> {
    Caller,
    Pool(&'p rayon::ThreadPool),
    Seal(&'p super::trained_block::SealPool),
}

/// [A15] a chain of up to `l` witnesses at `sh` from `x0` through the trained stack's
/// builder (`witness::build_for_block`, what `seal_and_record` and the stack source's
/// rebuild call), each built at `at`; block k + 1's input is block k's output, and a
/// refusal ends the chain (it is compared too)
fn a15_chain(at: A15At, sh: &Shape, blk: &BlockPublic, x0: &[i16], l: usize) -> Vec<Result<Witness, String>> {
    let mut out = Vec::with_capacity(l);
    let mut x = x0.to_vec();
    for _ in 0..l {
        let f = || super::witness::build_for_block(sh, blk, &x);
        let r = match at {
            A15At::Caller => f(),
            A15At::Pool(p) => p.install(f),
            A15At::Seal(s) => s.run(f),
        };
        let next = r.as_ref().ok().and_then(|w| w.output().ok()).map(|o| unpad(sh, &o));
        out.push(r);
        match next {
            Some(n) => x = n,
            None => break,
        }
    }
    out
}

/// [A15] one witness's digest: its output plane index, then every plane's length and words
fn a15_witness_digest(w: &Witness) -> String {
    let mut h = blake3::Hasher::new();
    h.update(&(w.output_plane as u64).to_le_bytes());
    let mut buf: Vec<u8> = Vec::with_capacity(1 << 16);
    for p in &w.planes {
        h.update(&(p.len() as u64).to_le_bytes());
        for c in p.chunks(1 << 13) {
            buf.clear();
            for v in c {
                buf.extend_from_slice(&v.to_le_bytes());
            }
            h.update(&buf);
        }
    }
    h.finalize().to_hex().to_string()
}

/// [A15] a chain as comparable text: per block, the digest of every plane or the refusal
fn a15_chain_digests(c: &[Result<Witness, String>]) -> Vec<Result<String, String>> {
    c.iter().map(|r| r.as_ref().map(a15_witness_digest).map_err(|e| e.clone())).collect()
}

/// [A15] the places to build at: the calling thread, rayon pools of 1, 4, 8 and 16
/// threads, and the trained stack's sealing pool set to 0 (the global pool), 1, 4, 8, 16
/// threads and its default rule; each with its label. `f` builds one chain at each.
fn a15_every_place(mut f: impl FnMut(&str, A15At)) {
    use super::trained_block::{set_seal_pool_auto_for_test, set_seal_pool_for_test, SealPool};
    f("the calling thread (global pool)", A15At::Caller);
    for t in [1usize, 4, 8, 16] {
        let p = rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("a rayon pool");
        f(&format!("a rayon pool of {t}"), A15At::Pool(&p));
    }
    for t in [Some(0usize), Some(1), Some(4), Some(8), Some(16), None] {
        match t {
            Some(t) => set_seal_pool_for_test(Some(t)),
            None => set_seal_pool_auto_for_test(),
        }
        let sp = SealPool::get().expect("the sealing pool");
        set_seal_pool_for_test(None);
        if let Some(t) = t {
            assert_eq!(sp.threads(), t, "HL_SEAL_POOL's test override {t} gave a pool of {}", sp.threads());
        }
        f(&format!("the sealing pool, setting {t:?} ({} threads)", sp.threads()), A15At::Seal(&sp));
    }
}

/// **[A15] the sealing pool's size rule, and the pool a witness is built in changes no
/// word (CPU).** The default is a quarter of the logical CPUs, at least 1 and at most 8
/// (8 on the 32-core M3 Ultra); `0` is the global pool. At the W16R2 rung, a chain of
/// three witnesses through the trained stack's builder is built on the calling thread,
/// in rayon pools of 1, 4, 8 and 16 threads, and in the sealing pool at 0, 1, 4, 8, 16
/// threads and the default: every plane of every witness (or the refusal that ends the
/// chain) is the same everywhere, and the first witness is `rung_case`'s.
#[test]
fn a15_the_seal_pool_rule_and_the_rung_witness_planes_in_every_pool() {
    use super::trained_block::default_seal_pool_threads_for_test as rule;
    assert_eq!((rule(1), rule(4), rule(8), rule(16), rule(32), rule(64), rule(128)), (1, 1, 2, 4, 8, 8, 8));
    let (sh, blk, w0) = rung_case(shape::W16R2_RUNG_H24);
    let x0: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11) % 201) as i16 - 100).collect();
    let base = a15_chain(A15At::Caller, &sh, &blk, &x0, 3);
    match &base[0] {
        Ok(w) => assert!(w.planes == w0.planes && w.output_plane == w0.output_plane, "the trained builder's first witness is not rung_case's"),
        Err(e) => panic!("the rung's first witness refused: {e}"),
    }
    let want = a15_chain_digests(&base);
    let ok = want.iter().filter(|d| d.is_ok()).count();
    a15_every_place(|label, at| {
        let got = a15_chain(at, &sh, &blk, &x0, 3);
        assert_eq!(got.len(), base.len(), "{label}: the chain's length moved");
        for (k, (g, b)) in got.iter().zip(&base).enumerate() {
            match (g, b) {
                (Ok(g), Ok(b)) => assert!(g.planes == b.planes && g.output_plane == b.output_plane, "{label}: a plane of witness {k} differs"),
                (Err(g), Err(b)) => assert_eq!(g, b, "{label}: block {k}'s refusal differs"),
                _ => panic!("{label}: block {k} built in one place and refused in the other"),
            }
        }
        eprintln!("A15-RUNG {} {label}: {ok} witnesses ({} blocks), every plane equal", sh.name, got.len());
    });
}

/// **[A15, ignored] the same at the W16R2 8B T128 block, CPU and device products.**
/// A14's 8B recipe (`range16_tests::case`, the first admissible synthetic input), a
/// chain of three witnesses through the trained stack's builder, built at every place
/// of [`a15_every_place`] with `HL_GPU` unset (CPU products) and with `HL_GPU=1` (the A4
/// device products): one digest of every plane of every witness, equal everywhere.
/// Heavy; toggles `HL_GPU`; run alone by name (`HL_GPU_REQUIRED=1`).
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A15: heavy (a three-block W16R2 8B T128 chain built 22 times), toggles HL_GPU; run alone by name, HL_GPU_REQUIRED=1"]
fn a15_the_8b_witness_planes_in_every_sealing_pool() {
    use crate::private_block::shape::NormCalibration;
    let spec = shape::W16R2_PROFILES.iter().find(|s| s.name == "W16R2_8B_T128_H24").expect("the W16R2 8B profile");
    let cal = NormCalibration { tn: if spec.width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 };
    let original = Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20).unwrap();
    let (sh, data, public, ff) = super::range16_tests::case(original, 3);
    let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
    std::env::remove_var("HL_GPU");
    let mut seed = 0usize;
    let x0 = loop {
        let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + seed) % (41 + 20 * (seed % 3))) as i16 - 20).collect();
        match super::witness::build_accuracy(&sh, &public, &ff, &data, &input) {
            Ok(_) => break input,
            Err(_) if seed < 6 => seed += 1,
            Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
        }
    };
    let want = a15_chain_digests(&a15_chain(A15At::Caller, &sh, &blk, &x0, 3));
    assert!(want.iter().all(|d| d.is_ok()), "the 8B chain refused: {want:?}");
    for gpu in [false, true] {
        if gpu {
            std::env::set_var("HL_GPU", "1");
        } else {
            std::env::remove_var("HL_GPU");
        }
        a15_every_place(|label, at| {
            let made = crate::gpu::witness_product_stats().0;
            let t = std::time::Instant::now();
            let got = a15_chain_digests(&a15_chain(at, &sh, &blk, &x0, 3));
            let secs = t.elapsed().as_secs_f64();
            let on_device = crate::gpu::witness_product_stats().0 - made;
            assert_eq!(got, want, "{label} ({}): a plane of the 8B chain's witnesses differs", if gpu { "device products" } else { "CPU products" });
            assert!(!gpu || on_device > 0, "{label}: no product ran on the device");
            eprintln!("A15-8B {} {label} [{}]: 3 witnesses in {secs:.2} s, {on_device} device products, every plane equal (digests {:?})", sh.name, if gpu { "device products" } else { "CPU products" }, got.iter().map(|d| d.as_ref().map(|s| s[..8].to_string()).unwrap_or_default()).collect::<Vec<_>>());
        });
    }
    std::env::remove_var("HL_GPU");
}
