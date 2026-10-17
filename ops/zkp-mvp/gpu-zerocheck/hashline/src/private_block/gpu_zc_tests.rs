//! **[ZK60-GZC] THE DEVICE SLOT-18 ZERO-CHECK: EQUALITY EVIDENCE.** TEST CODE
//! ONLY. Public synthetic data only.
//!
//! * `gzc_descriptor_*` (no device): the device description `FzcDesc` and its
//!   host mirror `FzcDesc::eval` (the kernel's expression, term for term) equal
//!   the slot's OWN closure at random points, at every small registered shape
//!   and at the trained ones; the layout check accepts the real definition and
//!   refuses perturbed ones.
//! * `gzc_device_*` (ignored; run under the guard's gpu class with `HL_GPU=1`):
//!   from ONE transcript state, the device body and the CPU body
//!   (`ClosureRounds` on the real closure, under the unchanged
//!   `zk::masked_prove_rounds`) give the same masked rounds, challenges,
//!   finals, transcript state and next challenge — the R1d oracle pattern of
//!   `argument.rs::run_slot` — on synthetic descriptors at edge sizes, and on
//!   the real slot-18 definition at the registered shapes with dense random
//!   and honest-witness tables, from host words and from device-resident rows;
//!   and the SEEDED proof-byte gate: `prove_core` twice from one seeded
//!   generator and one transcript, device slot 18 off / on, encodes the same
//!   receipt bytes.

use super::argument::{build_tables_keeping, define, device_fzc, total_at, Ctx, Points, ProverData, SlotDef, TOTAL_PAR_MIN};
use super::layout::*;
use super::shape::{NormCalibration, Shape};
use super::witness::Witness;
use super::trained_calib_tests::{generic_witness_with, llama3_8b_calibration, rung_tc_calibration, tinyllama_at, trained_dense_block_with, Bands, TRAINED_BANDS};
use super::*;
use crate::field::{Fp, Fp2};
use crate::gpu::fzc::{self, FzcDesc, FzcSrc};
use crate::sumcheck::{CfsMask, ClosureRounds};
use crate::transcript::Transcript;
use zkp_core::rng::ZkRng;

/// a test-local xorshift (no production generator)
fn xs(seed: u64) -> impl FnMut() -> u64 {
    let mut s = seed | 1;
    move || {
        s ^= s << 13;
        s ^= s >> 7;
        s ^= s << 17;
        s
    }
}

fn fp_of(r: &mut impl FnMut() -> u64) -> Fp {
    Fp::new(r() % crate::field::P)
}

fn fp2_of(r: &mut impl FnMut() -> u64) -> Fp2 {
    Fp2::new(fp_of(r), fp_of(r))
}

/// the definition-time scalars, every one with an imaginary part (S34-F2)
fn ctx_scalars() -> (Fp2, Fp2, Fp2, Fp2, Fp2) {
    let c = |re: u64, im: u64| Fp2::new(Fp::new(re), Fp::new(im));
    (c(7, 1), c(11, 2), c(13, 3), c(17, 5), c(19, 7))
}

fn small_shapes() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32()]
}

/// R4-2's generic 8B calibration (`r4_tests::generic_8b_calibration`)
fn generic_8b() -> Shape {
    Shape::llama3_8b_t32_trained(&NormCalibration { cn_a: 6380, cn_m: 6672, ..llama3_8b_calibration() }, 9).expect("the generic 8B shape")
}

fn rung_tc() -> Shape {
    Shape::rung_tc(&rung_tc_calibration()).expect("the trained-calibration rung")
}

/// the trained shapes the plan names: rung-TC, TinyLlama T32 / T128, 8B T32
fn trained_shapes() -> Vec<Shape> {
    vec![rung_tc(), tinyllama_at(32), tinyllama_at(128), generic_8b()]
}

/// R4-2's band search (`r4_tests::bands_8b`), for any trained shape
fn bands_for(sh: &Shape) -> Bands {
    let cands = [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 4, gate: 6, down: 1, xmag: 4_000, ..TRAINED_BANDS }];
    for b in cands {
        let (blk, input) = trained_dense_block_with(sh, b);
        if witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &input).is_ok() {
            return b;
        }
    }
    panic!("{}: no candidate band is admissible", sh.name);
}

/// The public statement a shape's definitions are built against: the tame
/// case at the small shapes, the trained-dense block at the trained ones.
fn public_of(sh: &Shape) -> (AttentionPublic, FeedForwardPublic) {
    if sh.trained_calibration {
        let (blk, _) = trained_dense_block_with(sh, bands_for(sh));
        (blk.attention().clone(), blk.feed_forward().clone())
    } else {
        let (public, ff, _) = super::grow_tests::tame_case(sh);
        (public, ff)
    }
}

/// Walk `define` through slots 0 ..= 18 on one transcript and keep slot 18's
/// definition (each earlier definition is dropped as soon as it is built).
fn slot18(sh: &Shape, lay: &Layout, public: &AttentionPublic, ff: &FeedForwardPublic) -> SlotDef {
    let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
    let ctx = Ctx { lay, public, ff, alpha, beta, g_u8, g_exp, g_act };
    let mut tr = Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    for s in 0..SC_FZC {
        drop(define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name)));
    }
    define(SC_FZC, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot 18: {e}", sh.name))
}

// ------------------------------------------------------------ no device

/// The description equals the closure at random points, at every shape.
fn descriptor_equals_closure(sh: &Shape) {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (public, ff) = public_of(sh);
    let def = slot18(sh, &lay, &public, &ff);
    let desc = def.fzc.as_ref().expect("slot 18 carries its device description");
    desc.check_layout(def.tabs.len()).unwrap_or_else(|e| panic!("{}: {e}", sh.name));
    assert_eq!(def.tabs.len(), if sh.pads(Dom::F) && sh.carries_pad_rule() { 21 } else { 20 }, "{}: slot 18's table count", sh.name);
    assert_eq!(desc.params().expect("the parameter block").len(), fzc::FZ_LEN);
    let mut r = xs(0x6A5C ^ (sh.tokens as u64) << 20 ^ sh.width as u64);
    for _ in 0..64 {
        let v: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
        assert_eq!(desc.eval(&v), (def.poly)(&v), "{}: FzcDesc::eval differs from the slot's closure", sh.name);
    }
    // and at a base-field point (the A planes' round-0 values) with a 0/1 gate
    for _ in 0..16 {
        let mut v: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
        for t in fzc::T_A..fzc::T_A + fzc::N_A_F {
            v[t] = Fp2::from_base(fp_of(&mut r));
        }
        if let Some(s) = desc.supp {
            v[s] = if r() & 1 == 0 { Fp2::ZERO } else { Fp2::ONE };
        }
        assert_eq!(desc.eval(&v), (def.poly)(&v), "{}: FzcDesc::eval differs at a base-field point", sh.name);
    }
    eprintln!(
        "GZC descriptor {}: slot 18 n {} degree {} tables {} supp {} pad planes {} mu {}; FzcDesc::eval == closure at 80 points",
        sh.name,
        sh.slots()[SC_FZC].0,
        sh.slots()[SC_FZC].2,
        def.tabs.len(),
        desc.supp.is_some(),
        desc.pad.len(),
        desc.mu.len()
    );
}

#[test]
fn gzc_descriptor_equals_the_closure_at_every_small_shape() {
    for sh in small_shapes() {
        descriptor_equals_closure(&sh);
    }
}

#[test]
#[ignore = "GZC: trained shapes (TinyLlama T128 / 8B T32 definitions); release"]
fn gzc_descriptor_equals_the_closure_at_the_trained_shapes() {
    for sh in trained_shapes() {
        descriptor_equals_closure(&sh);
    }
}

#[test]
fn gzc_layout_check_refuses_a_perturbed_description() {
    let sh = Shape::rung();
    let lay = Layout::for_shape(&sh).unwrap();
    let (public, ff) = public_of(&sh);
    let def = slot18(&sh, &lay, &public, &ff);
    let good = def.fzc.clone().unwrap();
    let k = def.tabs.len();
    good.check_layout(k).expect("the real definition passes");
    let mut bad: Vec<(&str, FzcDesc)> = Vec::new();
    let mut d = good.clone();
    d.a_tab.swap(0, 1);
    bad.push(("two A planes swapped", d));
    let mut d = good.clone();
    d.lk_tab[3] = usize::MAX;
    bad.push(("a two-term lookup", d));
    let mut d = good.clone();
    d.lk_tab.pop();
    bad.push(("eight lookups", d));
    let mut d = good.clone();
    d.i_fact += 1;
    bad.push(("the activation helper moved", d));
    let mut d = good.clone();
    d.mu.push(Fp2::ONE);
    bad.push(("one mu too many", d));
    let mut d = good.clone();
    d.pad = vec![(usize::MAX, Fp2::ZERO)];
    d.supp = Some(fzc::T_SUPP);
    bad.push(("two pad groups", d));
    for (what, d) in &bad {
        assert!(d.check_layout(k).is_err() || d.check_layout(k + 1).is_err(), "{what}: accepted");
    }
    assert!(good.check_layout(k + 1).is_err(), "a table too many: accepted");
    let mut d = good.clone();
    d.k_h = Fp2::U;
    assert!(d.params().is_err(), "an extension-field shift constant: accepted");
}

// ------------------------------------------------------------ device

fn require_device() {
    assert!(crate::gpu::enabled(), "GZC device tests need the gpu-cuda build and HL_GPU=1 ({})", crate::gpu::label());
}

/// one CPU body and one device body from the same transcript state; both
/// outputs, the transcript states and the next challenges must be equal
#[allow(clippy::too_many_arguments)]
fn compare_bodies(what: &str, desc: &FzcDesc, srcs: &[FzcSrc], tables: &[Vec<Fp2>], poly: &(dyn Fn(&[Fp2]) -> Fp2 + Sync), degree: usize, claim: Option<Fp2>, seed: u64) -> f64 {
    let n = tables[0].len().trailing_zeros() as usize;
    let mut rng = ZkRng::new(seed, b"gzc-equality-mask");
    let mask = CfsMask::random(&mut rng, n + 1, degree);
    let c = rng.fp2_vec(1)[0];
    let tr0 = Transcript::new_tagged(b"gzc-equality", [5; 32]);
    let mut tr_cpu = Transcript::clone_state(&tr0);
    let mut tr_dev = Transcript::clone_state(&tr0);
    let mut t_cpu = tables.to_vec();
    let mut ev = ClosureRounds::new(&mut t_cpu, degree, poly).recover_one(claim);
    let cpu = crate::zk::masked_prove_rounds(&mut ev, &mask, c, &mut tr_cpu);
    let t0 = std::time::Instant::now();
    let dev = fzc::prove(desc, srcs, n, degree, claim, &mask, c, &mut tr_dev).unwrap_or_else(|e| panic!("{what}: the device declined: {e}"));
    let secs = t0.elapsed().as_secs_f64();
    assert_eq!(dev.0, cpu.0, "{what}: masked rounds");
    assert_eq!(dev.1, cpu.1, "{what}: challenges");
    assert_eq!(dev.2, cpu.2, "{what}: finals");
    assert_eq!(tr_dev.state(), tr_cpu.state(), "{what}: transcript state");
    assert_eq!(tr_dev.challenge_fp2(), tr_cpu.challenge_fp2(), "{what}: next challenge");
    secs
}

/// a synthetic description with random parameters on the canonical layout
fn synthetic_desc(r: &mut impl FnMut() -> u64, supp: bool, pad: bool) -> FzcDesc {
    let mut f2 = || fp2_of(r);
    let base = |x: u64| Fp2::from_base(Fp::new(x));
    let pad_planes: Vec<(usize, Fp2)> = if supp && pad { [0usize, 2, 3, 6, 9, 10].iter().map(|j| (fzc::T_A + j, f2())).collect() } else { Vec::new() };
    let n_mu = 4 + fzc::N_HELP + usize::from(!pad_planes.is_empty());
    FzcDesc {
        alpha: f2(),
        beta: f2(),
        g_act: f2(),
        nu: [f2(), f2()],
        mu: (0..n_mu).map(|_| f2()).collect(),
        lk_cst: (0..9).map(|_| f2()).collect(),
        lk_coef: [1u64, 2, 1, 1, 1, 1, 1, 1, 4].iter().map(|c| Fp::new(*c)).collect(),
        lk_tab: fzc::LK_PLANES.iter().map(|p| fzc::T_A + p).collect(),
        a_tab: (0..fzc::N_A_F).map(|j| fzc::T_A + j).collect(),
        h0: fzc::T_H,
        n_help: fzc::N_HELP,
        i_fact: fzc::T_FACT,
        supp: supp.then_some(fzc::T_SUPP),
        pad: pad_planes,
        mu_pad: f2(),
        k_h: base(1 << 7),
        k_h_half: base(1 << 6),
        k_g: base(1 << 5),
        k_g_half: base(1 << 4),
        p1: base(256),
    }
}

/// synthetic descriptors at the edge sizes: n = 1 (no fused round), 2 (one
/// fused round of one pair), 3, 4, 7, 10; degree 4 and 5; gate and pad on and
/// off; a correct and a missing initial claim (and, in release, a WRONG one,
/// which only recovery can reproduce)
#[test]
#[ignore = "GZC device: run with HL_GPU=1 under the guard's gpu class"]
fn gzc_device_synthetic_edges_equal_the_cpu_body() {
    require_device();
    let mut cases = 0usize;
    for (seed, n) in [(1u64, 1usize), (2, 2), (3, 3), (4, 4), (5, 7), (6, 10)] {
        for (degree, supp, pad) in [(4usize, false, false), (5, true, true), (5, true, false), (4, true, true), (5, false, false)] {
            let mut r = xs(0x6A5C_0000 + seed * 977 + degree as u64 * 31 + u64::from(supp) * 7 + u64::from(pad));
            let desc = synthetic_desc(&mut r, supp, pad);
            let k = desc.k();
            let tables: Vec<Vec<Fp2>> = (0..k).map(|_| (0..1usize << n).map(|_| fp2_of(&mut r)).collect()).collect();
            let srcs: Vec<FzcSrc> = tables.iter().map(|t| FzcSrc::Host(t.as_slice())).collect();
            let poly = |v: &[Fp2]| desc.eval(v);
            let total = (0..1usize << n).fold(Fp2::ZERO, |acc, x| {
                let row: Vec<Fp2> = tables.iter().map(|t| t[x]).collect();
                acc.add(poly(&row))
            });
            let mut claims = vec![None, Some(total)];
            if !cfg!(debug_assertions) {
                claims.push(Some(total.add(Fp2::ONE)));
            }
            for claim in claims {
                for (fused, lean) in [("1", "0"), ("0", "0"), ("1", "1"), ("0", "1")] {
                    std::env::set_var("HL_GZC_FUSED", fused);
                    std::env::set_var("HL_GZC_LEAN", lean);
                    compare_bodies(&format!("synthetic n {n} D {degree} supp {supp} pad {pad} claim {claim:?} fused {fused} lean {lean}"), &desc, &srcs, &tables, &poly, degree, claim, seed);
                    cases += 1;
                }
            }
        }
    }
    std::env::remove_var("HL_GZC_FUSED");
    std::env::remove_var("HL_GZC_LEAN");
    eprintln!("GZC device synthetic: {cases} device bodies equal the CPU body (rounds, challenges, finals, transcript)");
}

/// dense random A / H words (every word nonzero) or the honest witness planes
fn prover_words(sh: &Shape, lay: &Layout, honest: Option<&Witness>) -> (Vec<Fp>, Vec<Fp>, Vec<Fp>) {
    let n = lay.n();
    let mut r = xs(0x4157_9E55 ^ (sh.tokens as u64) << 17 ^ sh.width as u64);
    let mut a: Vec<Fp> = (0..lay.a_rows * n).map(|_| Fp::new(1 + r() % (crate::field::P - 1))).collect();
    let h: Vec<Fp> = (0..lay.h_rows * n).map(|_| Fp::new(1 + r() % (crate::field::P - 1))).collect();
    let io: Vec<Fp> = (0..(1usize << sh.log(Dom::D)).max(n)).map(|_| Fp::new(1 + r() % (crate::field::P - 1))).collect();
    if let Some(w) = honest {
        let ids = lay.ids();
        for p in lay.a_planes() {
            if ids.is_multiplicity(p) {
                continue;
            }
            for (i, v) in w.planes[p].iter().enumerate() {
                a[lay.a_off[p] + i] = Fp::from_i64(*v);
            }
        }
    }
    (a, h, io)
}

/// a device-resident copy of a committed matrix's rows (the buffer a keyed
/// device commitment keeps as `DevCommit.data`), without the encoding
#[cfg(feature = "gpu-cuda")]
fn resident_copy(params: &crate::pcs::PcsParams, data: &[Fp], _ntt: &NttTables) -> crate::gpu::DevStore {
    crate::gpu::dev_resident_rows(data, params.log_cols).unwrap_or_else(|e| panic!("resident rows: {e}"))
}
#[cfg(not(feature = "gpu-cuda"))]
fn resident_copy(_params: &crate::pcs::PcsParams, _data: &[Fp], _ntt: &NttTables) -> crate::gpu::DevStore {
    panic!("device-resident rows need the gpu-cuda build")
}

/// the real slot-18 definition at `sh`, from host words and (when `resident`)
/// from device-resident copies of A and H made by a device commitment
fn real_slot_case(sh: &Shape, honest: bool, resident: bool, seed: u64) {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (public, ff) = public_of(sh);
    let wit = honest.then(|| generic_witness_with(sh, bands_for(sh)).2);
    let (a, h, io) = prover_words(sh, &lay, wit.as_ref());
    drop(wit);
    let def = slot18(sh, &lay, &public, &ff);
    let (n, _, degree) = sh.slots()[SC_FZC];
    let masks: Vec<CfsMask> = Vec::new();
    // device-resident copies: a plain device commitment keeps the rows on the device
    let params = protocol::pcs_params_at(sh);
    let ntt = NttTables::new(protocol::ntt_log_at(sh));
    let dev_a = if resident { Some(resident_copy(&params, &a, &ntt)) } else { None };
    let dev_h = if resident { Some(resident_copy(&params, &h, &ntt)) } else { None };
    let pd = ProverData { data: [&a, &h, &io, &io], masks: &masks, dev: [dev_a.as_ref(), dev_h.as_ref()] };
    let tables = build_tables_keeping(&def.tabs, n, &pd);
    let poly = |v: &[Fp2]| (def.poly)(v);
    // the production source builder: `argument::device_fzc` builds the sources
    // from the definition; here they are rebuilt the same way through it, so
    // the comparison uses the real dispatch, not a test transcription
    let mut rng = ZkRng::new(seed, b"gzc-equality-mask");
    let mask = CfsMask::random(&mut rng, n + 1, degree);
    let c = rng.fp2_vec(1)[0];
    let total = total_at(&tables, &def.poly, TOTAL_PAR_MIN);
    let what = format!("{} slot 18 (n {n}, D {degree}, k {}, {} data, {})", sh.name, def.tabs.len(), if honest { "honest-witness" } else { "dense random" }, if resident { "device-resident rows" } else { "host words" });
    for claim in [None, Some(total)] {
        let tr0 = Transcript::new_tagged(b"gzc-equality", [9; 32]);
        let mut tr_cpu = Transcript::clone_state(&tr0);
        let mut t_cpu = tables.clone();
        let t0 = std::time::Instant::now();
        let mut ev = ClosureRounds::new(&mut t_cpu, degree, &poly).recover_one(claim);
        let cpu = crate::zk::masked_prove_rounds(&mut ev, &mask, c, &mut tr_cpu);
        let cpu_s = t0.elapsed().as_secs_f64();
        let cpu_state = tr_cpu.state();
        let cpu_next = tr_cpu.challenge_fp2();
        for lean in ["0", "1"] {
            std::env::set_var("HL_GZC_LEAN", lean);
            let mut tr_dev = Transcript::clone_state(&tr0);
            let t1 = std::time::Instant::now();
            let dev = device_fzc(&def, &pd, &[], n, degree, claim, &mask, c, &mut tr_dev).unwrap_or_else(|| panic!("{what}: the device declined"));
            let dev_s = t1.elapsed().as_secs_f64();
            assert_eq!(dev.0, cpu.0, "{what} lean {lean}: masked rounds");
            assert_eq!(dev.1, cpu.1, "{what} lean {lean}: challenges");
            assert_eq!(dev.2, cpu.2, "{what} lean {lean}: finals");
            assert_eq!(tr_dev.state(), cpu_state, "{what} lean {lean}: transcript state");
            assert_eq!(tr_dev.challenge_fp2(), cpu_next, "{what} lean {lean}: next challenge");
            eprintln!("GZC device == CPU: {what}, lean {lean}, claim {}: {} rounds equal; CPU body {cpu_s:.3} s, device body (tables built on the device) {dev_s:.4} s", if claim.is_some() { "given" } else { "none (round 0 evaluated)" }, cpu.0.len());
        }
        std::env::remove_var("HL_GZC_LEAN");
    }
}

#[test]
#[ignore = "GZC device: run with HL_GPU=1 under the guard's gpu class"]
fn gzc_device_real_slot18_equals_the_cpu_body_at_every_small_shape() {
    require_device();
    for (i, sh) in small_shapes().iter().enumerate() {
        real_slot_case(sh, false, false, 100 + i as u64);
        real_slot_case(sh, false, true, 200 + i as u64);
    }
}

#[test]
#[ignore = "GZC device: trained shapes (rung-TC, TinyLlama T32/T128, 8B T32); release, HL_GPU=1, gpu class"]
fn gzc_device_real_slot18_equals_the_cpu_body_at_the_trained_shapes() {
    require_device();
    for (i, sh) in trained_shapes().iter().enumerate() {
        real_slot_case(sh, false, true, 300 + i as u64);
        real_slot_case(sh, true, true, 400 + i as u64);
        if i == 0 {
            real_slot_case(sh, true, false, 500);
        }
    }
}

/// **THE SEEDED PROOF-BYTE GATE.** `prove_core` twice from ONE seeded
/// generator, ONE transcript header and the SAME endpoint owners, device slot
/// 18 off and on; the encoded receipts must be byte-identical. (Production
/// draws from the OS; the seeded generator exists only in this test.)
fn seeded_receipt(sh: &Shape, blk: &BlockPublic, planes: &[Vec<i64>], expected: &ExpectedIo, ends: &[pcs::CommittedZk; 2], device: bool) -> (Vec<u8>, f64) {
    fzc::force(Some(device));
    let lay = Layout::for_shape(sh).unwrap();
    let ntt = NttTables::new(protocol::ntt_log_at(sh));
    let mut rng = ZkRng::new(0x6A5C_5EED, b"gzc-seeded-proof-byte-gate");
    let mut tr = protocol::transcript(blk, expected, &lay);
    let mut ph = timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = std::time::Instant::now();
    let runs0 = fzc::runs();
    let t0 = std::time::Instant::now();
    let core = protocol::prove_core(sh, &lay, blk, Witness { planes: planes.to_vec() }, [ends[0].data.as_slice(), ends[1].data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).unwrap_or_else(|e| panic!("{}: prove_core: {e}", sh.name));
    let secs = t0.elapsed().as_secs_f64();
    fzc::force(None);
    assert_eq!(fzc::runs() - runs0, usize::from(device), "{}: the device slot-18 body ran {} times", sh.name, fzc::runs() - runs0);
    let [ic, oc] = core.io_claims;
    let in_open = pcs::open_zk(&ends[0], &ic, &mut tr);
    let out_open = pcs::open_zk(&ends[1], &oc, &mut tr);
    let receipt = Receipt {
        a_root: core.a_root,
        h_root: core.h_root,
        mask_root: core.mask_root,
        slots: core.slots,
        mask_open: core.mask_open,
        a_open: core.a_open,
        h_open: core.h_open,
        io_open: [in_open, out_open],
    };
    let bytes = wire::encode(&receipt, &[7u8; 32], &lay).unwrap_or_else(|e| panic!("{}: encode: {e}", sh.name));
    (bytes, secs)
}

#[test]
#[ignore = "GZC device: seeded proof-byte gate at the trained shapes; release, HL_GPU=1, gpu class"]
fn gzc_device_seeded_receipts_are_byte_identical() {
    require_device();
    for sh in trained_shapes() {
        let (blk, _, w) = generic_witness_with(&sh, bands_for(&sh));
        let ids = Ids::new(&sh).unwrap();
        let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect() };
        let spec = IoSpec::new_shaped(&sh, *blake3::hash(b"gzc seeded gate").as_bytes(), 0, 0).expect("the endpoint spec");
        let (expected, endpoints) = prepare_endpoints(spec, &plane(ids.at(A_X)), &plane(ids.at(A_X2))).expect("the endpoints");
        let ends = protocol::check_endpoints(&sh, &expected, endpoints).expect("the endpoint owners");
        let (cpu, cpu_s) = seeded_receipt(&sh, &blk, &w.planes, &expected, &ends, false);
        let (dev, dev_s) = seeded_receipt(&sh, &blk, &w.planes, &expected, &ends, true);
        assert_eq!(cpu.len(), dev.len(), "{}: receipt lengths", sh.name);
        assert!(cpu == dev, "{}: the seeded receipts differ (first byte {:?})", sh.name, cpu.iter().zip(dev.iter()).position(|(a, b)| a != b));
        let digest = |b: &[u8]| super::trained_block::hex(blake3::hash(b).as_bytes());
        eprintln!(
            "GZC seeded proof-byte gate {}: {} B, blake3 {} both ways; prove_core CPU slot 18 {cpu_s:.2} s, device slot 18 {dev_s:.2} s",
            sh.name,
            cpu.len(),
            &digest(&cpu)[..16]
        );
    }
}

/// Fail closed: with `HL_GPU_REQUIRED=1`, a device refusal PANICS instead of
/// falling back (run alone, with the variable set by the caller).
#[test]
#[ignore = "GZC device: run ALONE with HL_GPU=1 HL_GPU_REQUIRED=1"]
fn gzc_device_refusal_fails_closed_under_required() {
    require_device();
    assert!(crate::gpu::required(), "run this test with HL_GPU_REQUIRED=1");
    let sh = Shape::rung();
    let lay = Layout::for_shape(&sh).unwrap();
    let (public, ff) = public_of(&sh);
    let mut def = slot18(&sh, &lay, &public, &ff);
    def.fzc.as_mut().unwrap().i_fact += 1; // a layout the kernel refuses
    let (a, h, io) = prover_words(&sh, &lay, None);
    let masks: Vec<CfsMask> = Vec::new();
    let pd = ProverData { data: [&a, &h, &io, &io], masks: &masks, dev: [None, None] };
    let (n, _, degree) = sh.slots()[SC_FZC];
    let mut rng = ZkRng::new(77, b"gzc-fail-closed");
    let mask = CfsMask::random(&mut rng, n + 1, degree);
    let mut tr = Transcript::new(b"gzc-fail-closed");
    let before = tr.state();
    let declines = crate::gpu::declines();
    let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| device_fzc(&def, &pd, &[], n, degree, None, &mask, Fp2::ONE, &mut tr)));
    let msg = match r {
        Ok(_) => panic!("a refused device body under HL_GPU_REQUIRED=1 returned instead of failing closed"),
        Err(e) => e.downcast_ref::<String>().cloned().unwrap_or_default(),
    };
    assert!(msg.contains("fail closed") && msg.contains("ZK60-GZC"), "unexpected panic: {msg}");
    assert_eq!(crate::gpu::declines(), declines + 1, "the refusal was not counted");
    assert_eq!(tr.state(), before, "the refused attempt touched the caller's transcript");
    eprintln!("GZC fail-closed: {msg}");
}

/// **THE CUBE-SIZE LADDER (measurement, not a gate).** The device body
/// against the CPU body (`ClosureRounds` on the kernel's own expression, all
/// rayon threads) on the slot's exact layout — 21 tables, degree 5, gate and
/// pad on, the trained profiles' shape — at cube sizes `GZC_BENCH_LOGS`
/// (default 18,19,20,21: 8B T16..T128 / TinyLlama T32..T256), equality
/// asserted at every size. Run with `HL_GZC_PROFILE=1` for the per-kernel
/// split. Synthetic data; the real closure's CPU cost is measured in the
/// trained-shape test and the stack runs.
#[test]
#[ignore = "GZC device: measurement ladder; release, HL_GPU=1, gpu class"]
fn gzc_device_bench_cube_ladder() {
    require_device();
    let logs: Vec<usize> = std::env::var("GZC_BENCH_LOGS").ok().map(|v| v.split(',').filter_map(|x| x.trim().parse().ok()).collect()).unwrap_or_else(|| vec![18, 19, 20, 21]);
    let reps: usize = std::env::var("GZC_BENCH_REPS").ok().and_then(|v| v.parse().ok()).unwrap_or(3);
    let cpu_on = std::env::var("GZC_BENCH_CPU").map(|v| v != "0").unwrap_or(true);
    for n in logs {
        let mut r = xs(0x6A5C_BE4C ^ n as u64);
        let desc = synthetic_desc(&mut r, true, true);
        let k = desc.k();
        let tables: Vec<Vec<Fp2>> = (0..k)
            .map(|t| (0..1usize << n).map(|_| if (fzc::T_A..fzc::T_A + fzc::N_A_F).contains(&t) { Fp2::from_base(fp_of(&mut r)) } else if t == fzc::T_SUPP { if r() & 3 == 0 { Fp2::ZERO } else { Fp2::ONE } } else { fp2_of(&mut r) }).collect())
            .collect();
        let srcs: Vec<FzcSrc> = tables.iter().map(|t| FzcSrc::Host(t.as_slice())).collect();
        let poly = |v: &[Fp2]| desc.eval(v);
        let degree = 5;
        let mut rng = ZkRng::new(n as u64, b"gzc-bench-mask");
        let mask = CfsMask::random(&mut rng, n + 1, degree);
        let c = rng.fp2_vec(1)[0];
        let tr0 = Transcript::new_tagged(b"gzc-bench", [3; 32]);
        let mut cpu_s = f64::NAN;
        let mut cpu_out = None;
        if cpu_on {
            let mut t_cpu = tables.clone();
            let mut tr = Transcript::clone_state(&tr0);
            let t0 = std::time::Instant::now();
            let mut ev = ClosureRounds::new(&mut t_cpu, degree, &poly).recover_one(None);
            cpu_out = Some(crate::zk::masked_prove_rounds(&mut ev, &mask, c, &mut tr));
            cpu_s = t0.elapsed().as_secs_f64();
        }
        let mut best = f64::INFINITY;
        for rep in 0..reps {
            if let Ok(v) = std::env::var("GZC_BENCH_LEAN") {
                std::env::set_var("HL_GZC_LEAN", &v);
            }
            let mut tr = Transcript::clone_state(&tr0);
            let t0 = std::time::Instant::now();
            let dev = fzc::prove(&desc, &srcs, n, degree, None, &mask, c, &mut tr).unwrap_or_else(|e| panic!("n {n}: the device declined: {e}"));
            let s = t0.elapsed().as_secs_f64();
            best = best.min(s);
            if let Some(cpu) = &cpu_out {
                assert_eq!(&dev, cpu, "n {n} rep {rep}: the device body differs from the CPU body");
            }
        }
        let plan_bytes = 72.0 * (1u64 << n) as f64 * 17.0;
        eprintln!(
            "GZC ladder n {n} (2^{n} = {} entries, k {k}, D {degree}): CPU body {cpu_s:.3} s ({} threads), device body best of {reps} {:.2} ms incl. H2D of the host tables ({} MB); plan figure 72 B x 2^n x 17 = {:.3} GB -> {:.1} GB/s = {:.1}% of 256 GB/s; speed-up {:.1}x",
            1u64 << n,
            rayon::current_num_threads(),
            best * 1e3,
            (k << n) * 16 >> 20,
            plan_bytes / 1e9,
            plan_bytes / best / 1e9,
            100.0 * plan_bytes / best / 256e9,
            cpu_s / best
        );
    }
    #[cfg(feature = "gpu-cuda")]
    {
        eprintln!("GZC ladder totals: {}", crate::gpu::fzc_totals().line("ladder"));
        eprintln!("GZC slot-18 module compile (NVRTC + load, once per process): {:.2} s", crate::gpu::fzc_compile_secs());
        // the card's streaming reference: a device-to-device copy of 512 MiB
        match crate::gpu::dev_copy_bandwidth(1 << 26) {
            Ok(gbs) => eprintln!("GZC streaming reference: device-to-device copy of 512 MiB at {gbs:.1} GB/s (read + write counted) = {:.1}% of 256 GB/s", 100.0 * gbs / 256.0),
            Err(e) => eprintln!("GZC streaming reference unavailable: {e}"),
        }
    }
}
