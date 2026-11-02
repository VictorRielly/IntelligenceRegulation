//! **W16R2 (D59): W16 at code rate 1/2, the column test counted at the
//! Reed–Solomon unique-decoding radius.** Test builds only.
//!
//! The profiles (`shape::W16R2_PROFILES`) are W16's geometries under new
//! strings. Their regular commitments (`A`, `H`, every boundary and both
//! endpoints) are encoded at rate 1/2 with `Q = 260` opened columns and
//! `Q` pads per row; the masking commitment `M` keeps its own constants. The
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
//! * the four D59 malicious controls, (a) a far matrix, (b) a wrong opened
//!   column, (c) a column set chosen before the challenge, (d) a forged pad
//!   half, at the profile's own PCS parameters and keys through
//!   `pcs::verify_zk_tagged` (the function `verify_core` calls for `A` and
//!   `H`, and a run for every boundary and endpoint), and on real block
//!   proofs where a post-hoc edit can express the cheat; plus, at a toy
//!   rate-1/2 geometry where the bound is measurable, the empirical
//!   acceptance rate of (a) and (d) against `(1 - (e + 1)/N)^Q`;
//! * W16's own malicious controls (the out-of-range limbs and review F3's
//!   four) ported to the W16R2 rung;
//! * the dev rung's golden digest (CPU), and its CPU = Metal identity;
//! * the lemma's load-bearing invariants, pinned;
//! * the accounting inputs, printed from the code
//!   (`results/zk60_w16r2_20261101/ACCOUNTING.md` reads them);
//! * the A/B on one binary (W16 against W16R2 at 8B T128), ignored.
use super::layout::*;
use super::protocol::{self, CoreProof, CoreView};
use super::range16_tests::{built, rung_case};
use super::shape::{self, ColumnRegime, Shape};
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

/// the header both sides absorb (`range16_tests::prove_and_verify_core`'s)
fn header(sh: &Shape, lay: &Layout) -> Transcript {
    let mut tr = Transcript::new(b"zk60 W16R2 core");
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
/// 1/2 and `Q = 260` (pads included), its endpoint geometry following the
/// core's, its own string of the sibling's length, its own four keys and a
/// parameter line of the sibling's length that differs only in the rate and
/// `Q`. Every other profile this lane builds keeps its rate and `Q = 256`.
#[test]
fn w16r2_profiles_fix_rate_one_half_and_q_260_and_change_nothing_else() {
    assert_eq!(shape::W16R2_PROFILES.len(), PAIRS.len());
    for (r2, w16) in PAIRS {
        let (a, b) = (built(r2), built(w16));
        a.check_constructed().unwrap();
        assert!(shape::is_w16r2_profile(a.profile) && !shape::is_w16r2_profile(b.profile));
        assert!(a.range16() && b.range16() && shape::is_trained_profile_string(a.profile));
        assert_eq!((a.log_cols, a.inv_rate, a.opened_cols, a.endpoint_log_n, a.endpoint_inv_rate), (14, 2, 260, 14, 2), "{}", a.name);
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
        assert_eq!(da[0].replacen(a.profile, b.profile, 1).replace("inv_rate=2 Q=260", "inv_rate=4 Q=256"), db[0], "{}: the schedule's header differs outside the profile, rate and Q", a.name);
        assert_ne!(la.schedule_digest(), lb.schedule_digest());
        // the PCS parameters every verifier site reads
        let (p, e) = (protocol::pcs_params_at(&a), protocol::endpoint_pcs_params(&a));
        assert_eq!((p.log_cols, p.inv_rate, p.num_col_checks), (14, 2, 260));
        assert_eq!((e.log_cols, e.inv_rate, e.num_col_checks), (14, 2, 260));
        assert_eq!(ZkOpts::standard(&p).q_pad, 260, "q_pad >= Q: the pads ARE the opened-column count");
        assert_eq!(protocol::ntt_log_at(&a), 15);
        // strings, keys, parameter line
        assert_eq!(a.profile.len(), b.profile.len(), "{}: the W16R2 string is not its sibling's length", a.name);
        assert!(!a.hashes_under_the_legacy_rule() && a.hash_tag() == HashTag::for_profile(a.profile) && a.hash_tag() != b.hash_tag());
        let (pa, pb) = (protocol::parameter_line(&a), protocol::parameter_line(&b));
        assert_eq!(pa.len(), pb.len(), "the parameter line changed length");
        assert_eq!(pa.replace("inv_rate2/Q260", "inv_rate4/Q256").replace("rate2-pad260", "rate4-pad256"), pb, "the parameter lines differ outside the rate and Q");
        // the per-opening column term: no soundness given up
        let ((ca, cea), (cb, ceb)) = (a.regular_column_terms_log2(), b.regular_column_terms_log2());
        assert!(ca <= cb && cea <= ceb, "{}: the W16R2 opening ({ca:.3}) is weaker than W16's ({cb:.3})", a.name);
        eprintln!("W16R2 {} vs {}: rate 1/2 Q 260 column term 2^{ca:.3} (unique decoding) against 2^{cb:.3} (rate 1/4 Q 256, delta/3); A rows {}, H rows {}, receipt (counted) {} B against {} B", a.name, b.name, la.a_rows, la.h_rows, a.receipt_bytes().total, b.receipt_bytes().total);
    }
    // the lemma check's figures (§5): Q = 260 gives 2^-105.946 (exact form),
    // Q = 259 2^-105.53, W16 2^-105.61
    let ud = |q| shape::column_term_log2(ColumnRegime::UniqueDecoding, 14, 2, q);
    assert!((ud(260) + 105.946).abs() < 0.001 && (ud(259) + 105.53).abs() < 0.01, "{} {}", ud(260), ud(259));
    assert!((shape::column_term_log2(ColumnRegime::GeneralCode, 14, 4, 256) + 105.61).abs() < 0.01);
    assert!(ud(259) > shape::column_term_log2(ColumnRegime::GeneralCode, 14, 4, 256), "Q = 259 would already suffice; 260 is not the minimum");
    // nothing else moves: every other profile this lane builds keeps Q = 256
    let mut others: Vec<Shape> = vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()];
    others.extend(super::trained_calib_tests::registered_trained_shapes());
    others.extend(super::accuracy_profile_tests::registered_shapes());
    others.extend(shape::W16_PROFILES.iter().map(|s| built(s.profile)));
    for sh in &others {
        assert_eq!(sh.opened_cols, 256, "{}: Q moved", sh.name);
        assert!(!shape::is_w16r2_profile(sh.profile) && sh.column_regime() == ColumnRegime::GeneralCode, "{}", sh.name);
    }
    eprintln!("W16R2 profiles: {} at rate 1/2 Q 260; {} other profiles unchanged at Q 256 under the delta/3 count", shape::W16R2_PROFILES.len(), others.len());
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

/// the first eight hex digits of the W16R2 rung's seeded CPU digest
const W16R2_RUNG_GOLDEN: &str = "334e168f";

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
    /// `e = floor((N - K)/2)`, `K = n + q_pad`
    fn e(&self) -> usize {
        (self.nn() - self.n() - self.zko.q_pad) / 2
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
/// W16R2 profile's own geometry (`n = 2^14`, `N = 2^15`, `Q = 260`, its
/// keys) the verifier must reject at the column test; the miss probability
/// is `(1 - (e+1)/N)^Q = 2^-105.95`. Then at a toy rate-1/2 geometry
/// (`n = 16`, `N = 32`, `Q = 4`, `e = 6`) where that probability is 0.373,
/// the empirical acceptance rate over 4,000 seeds must sit at the bound
/// (for this attack the bound is exact).
#[test]
fn w16r2_control_a_a_far_matrix_is_rejected_at_the_column_test() {
    let sh = built(shape::W16R2_RUNG_H24);
    let rig = Rig::profile(&sh);
    assert_eq!((rig.n(), rig.nn(), rig.zko.q_pad, rig.e()), (1 << 14, 1 << 15, 260, 8062));
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
    let trials = 4000u64;
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

// ------------------------------------------------------------ control (d)

/// **D59 control (d): a forged pad (hiding) half.** The pads are message
/// symbols of the row code (`K = n + Q`), so a clear vector's pad entries
/// are bound like its data entries. A cheater changes the first pad entry of
/// the group vector (which `<v[..n], c>` never reads, so the claim check
/// passes) — and, separately, of the proximity vector — absorbs the forged
/// vector, opens the columns the transcript then draws: the column test must
/// reject. At the toy geometry the acceptance rate over 4,000 seeds must sit
/// at or below the lemma's `(1 - (e + 1)/N)^Q`. On a real block proof the
/// edit is rejected too (there the redrawn indices object first).
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
    // the measurable geometry
    let toy = Rig::at(&sh, PcsParams { log_cols: 4, inv_rate: 2, num_col_checks: 4 }, 4);
    let trials = 4000u64;
    let mut accepted = 0u64;
    for t in 0..trials {
        let data = toy.matrix(200 + t);
        let claims = [toy.claim(&data)];
        let c = toy.commit(data, 200 + t);
        let delta = Fp2::new(Fp::new(1 + t), Fp::new(t / 3));
        let (o, _, _) = open_as(&c, &mut toy.transcript(&c.commitment().root), &Cheat { group_pad: Some(delta), ..Cheat::default() });
        accepted += u64::from(toy.verify(&c.commitment(), &claims, &o).is_ok());
    }
    let (rate, bound) = (accepted as f64 / trials as f64, toy.bound());
    eprintln!("W16R2 control (d) toy rate 1/2 (n 16, N 32, Q 4): {accepted} of {trials} forged pad halves accepted = {rate:.4}; the lemma's bound {bound:.4}");
    assert!(rate <= bound, "the forged-pad acceptance rate {rate} exceeds the lemma's bound {bound}");
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
/// proof with one opened column dropped (`Q` 259) or added (261), or with
/// its clear vectors cut to `n + 256` (256 pads). At the PCS level, honest
/// openings genuinely made at rate 1/2 with `Q` 256, at `Q` 259 with 260
/// pads, and at rate 1/4 with `Q` 260, each handed to the profile's
/// verifier. Every one is rejected, because the verifier's rate and `Q` are
/// the profile's and the receipt carries no say in them.
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
        ("one A column dropped (Q 259)", |o, _| { o.columns.pop(); }, "A: pcs zk: wrong number of columns"),
        ("one A column added (Q 261)", |o, _| { let c = o.columns[0].clone(); o.columns.push(c); }, "A: pcs zk: wrong number of columns"),
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
    for (what, params, q_pad, want) in [
        ("rate 1/2, Q 256, 256 pads", PcsParams { log_cols: 14, inv_rate: 2, num_col_checks: 256 }, 256, "group vector 0 has length 16640"),
        ("rate 1/2, Q 259, 260 pads", PcsParams { log_cols: 14, inv_rate: 2, num_col_checks: 259 }, 260, "wrong number of columns"),
        ("rate 1/4, Q 260, 260 pads", PcsParams { log_cols: 14, inv_rate: 4, num_col_checks: 260 }, 260, "Merkle path of 16 entries"),
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
///   length, under the profile's keys.
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
    for spec in shape::W16R2_PROFILES.iter() {
        let s = built(spec.profile);
        let p = protocol::pcs_params_at(&s);
        assert!(ZkOpts::standard(&p).q_pad >= p.num_col_checks && ZkOpts::standard(&protocol::endpoint_pcs_params(&s)).q_pad >= p.num_col_checks);
        assert!(!s.hashes_under_the_legacy_rule() && s.hash_tag().column_key().is_some(), "{}: not a tagged profile", spec.name);
    }
    eprintln!("W16R2 invariants: proximity weights = rows independent challenge_fp2 draws; indices after both absorbs in open_zk and verify_zk_tagged, and they move with the vectors; q_pad >= Q; A/H through verify_zk_tagged (path length checked) under each profile's keys");
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
