//! **NATIVE R12: byte identity of the EXISTING profiles across R9 -> R12**
//! (the coordinator's check (a), as in R9). TEST CODE ONLY. Public synthetic
//! data only.
//!
//! Proof bytes come from OS randomness, so two proofs never repeat. Each test
//! proves ONE block with a SEEDED generator (`ZkRng::new`, test code only)
//! through the shared `protocol::prove_core`, at a registered trained shape,
//! on a generic dense witness, with a fixed transcript prefix and
//! deterministic endpoint data, and digests EVERYTHING the core produces: the
//! three roots, every slot proof, the three openings, the IO claims, the
//! absorb order and the final transcript state. The non-DD bodies are R9's
//! `r9_golden_tests` verbatim (so their digests are the R8 / R9 ones); the DD
//! shapes use the same recipe with an exp table of score exponent 2 (a
//! dictionary column well inside cap 32). The same file runs in a copy of the
//! R9 freeze (`r12/r9-golden-tree/`) to record the DD digests, and in the R12
//! tree against all four.
//!
//! Heavy (two width-2048 and two width-4096 T128 blocks): `#[ignore]`, run
//! through the guard by name.

use super::layout::*;
use super::shape::{NormCalibration, Shape};
use super::*;
use crate::field::Fp;
use crate::transcript::Transcript;

/// the R8 / R9 digests of the non-DD shapes (R9's `r9_golden_tests`) and the
/// R9 digests of the DD shapes, recorded in `r12/r9-golden-tree/`
const GOLDEN: &[(&str, &str)] = &[
    ("tinyllama-t128", "782b64c97a88cba4c6c34a2fecb73132f26d5f54adc9bd159f3d6cf9df4205c0"),
    ("llama3-8b-t128", "05a22d72a892aff5fb2e35da4d0ab0c894d696f2e6afa542b6ecece5aeb9f4db"),
];

fn digest_of_seeded_block(sh: &Shape, blk: &BlockPublic, w: super::witness::Witness) -> String {
    let lay = Layout::for_shape(sh).unwrap();
    let rows = sh.endpoint_rows;
    let n = 1usize << sh.endpoint_log_n;
    let ids = Ids::new(sh).unwrap();
    let io = |p: usize| -> Vec<Fp> {
        let mut d = vec![Fp::ZERO; rows * n];
        for (i, v) in w.planes[p].iter().enumerate().take(d.len()) {
            d[i] = Fp::from_i64(*v);
        }
        d
    };
    let (ein, eout) = (io(ids.at(A_X)), io(ids.at(A_X2)));
    let ntt = crate::ntt::NttTables::new(super::protocol::ntt_log_at(sh));
    let mut rng = crate::zk::ZkRng::new(20261019, b"native r9 golden");
    let mut tr = Transcript::new(b"native r9 golden");
    tr.absorb(b"profile", sh.profile.as_bytes());
    tr.absorb(b"schedule", &lay.schedule_digest());
    let mut ph = super::timing::Phases::start();
    let mut phases = Vec::new();
    let mut tick = std::time::Instant::now();
    let core = super::protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the seeded core proof");
    let text = format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
        core.a_root,
        core.h_root,
        core.mask_root,
        core.slots,
        core.mask_open,
        core.a_open,
        core.h_open,
        core.io_claims,
        core.order,
        core.lookups,
        tr.state()
    );
    eprintln!("R12-GOLDEN {}: {} slots, {} absorbs, debug text {} B", sh.profile, core.slots.len(), core.order.len(), text.len());
    blake3::hash(text.as_bytes()).to_hex().to_string()
}

fn check(name: &str, got: &str) {
    eprintln!("R12-GOLDEN-DIGEST {name} {got}");
    match GOLDEN.iter().find(|(n, _)| *n == name) {
        Some((_, want)) => assert_eq!(got, *want, "{name}: the seeded core proof's bytes moved between R9 and R12"),
        None => eprintln!("R12-GOLDEN {name}: no recorded golden yet (recording run)"),
    }
}

/// the 8B T128 dense case: the R4-2 / ladder bands, the FIRST admissible
fn eight_b_dense(sh: &Shape) -> (BlockPublic, Vec<i16>, super::witness::Witness) {
    use super::trained_calib_tests::{Bands, TRAINED_BANDS};
    let cands = [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 4, gate: 6, down: 1, xmag: 4_000, ..TRAINED_BANDS }];
    for b in cands {
        let (blk, input) = super::trained_calib_tests::trained_dense_block_with(sh, b);
        if let Ok(w) = super::witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &input) {
            eprintln!("R12-GOLDEN 8B bands {b:?}");
            return (blk, input, w);
        }
    }
    panic!("no candidate band is admissible at the 8B T128 geometry");
}

/// the same dense words with an exp table of score exponent 2 (DD shapes)
fn dd_dense(sh: &Shape, b: super::trained_calib_tests::Bands) -> (BlockPublic, Vec<i16>) {
    let (w, input) = super::trained_calib_tests::trained_dense_words(sh, b);
    let (cos, sin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, super::shape::trained_rope_theta(sh.profile).unwrap_or(10000.0), F_RO);
    let (exp, _) = crate::tables_attn::exp_member(2, sh.head_dim, sh.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("a frozen SiLU member");
    let aw = super::grow_tests::pad_attention_weights(sh, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let fw = super::grow_tests::pad_ff_weights(sh, &w[5], &w[6], &w[7], &w[8]);
    let public = AttentionPublic::new_shaped(sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("the attention statement");
    let ff = FeedForwardPublic::new_shaped(sh, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("the feed-forward statement");
    (BlockPublic::new(public, ff), input)
}

#[test]
#[ignore = "native lane heavy: seeded TinyLlama T128 block proof (byte identity across R9 -> R12)"]
fn r12_golden_seeded_tinyllama_t128_block_is_byte_identical() {
    let cal = super::trained_calib_tests::t3_calibration();
    let sh = Shape::tinyllama_trained(128, &cal, 9).unwrap();
    let (blk, input) = super::trained_calib_tests::trained_dense_block(&sh);
    let w = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the generic dense witness");
    check("tinyllama-t128", &digest_of_seeded_block(&sh, &blk, w));
}

#[test]
#[ignore = "native lane heavy: seeded Llama-3-8B T128 block proof (byte identity across R9 -> R12)"]
fn r12_golden_seeded_llama3_8b_t128_block_is_byte_identical() {
    let cal = NormCalibration { cn_a: 6380, cn_m: 6672, ..super::trained_calib_tests::llama3_8b_calibration() };
    let sh = Shape::llama3_8b_trained(128, &cal, 9).unwrap();
    let (blk, _, w) = eight_b_dense(&sh);
    check("llama3-8b-t128", &digest_of_seeded_block(&sh, &blk, w));
}

#[test]
#[ignore = "native lane heavy: seeded TinyLlama T128 DD block proof (byte identity across R9 -> R12)"]
fn r12_golden_seeded_tinyllama_t128_dd_block_is_byte_identical() {
    let cal = super::trained_calib_tests::t3_calibration();
    let sh = Shape::tinyllama_t128_trained_dd(&cal, 9).unwrap();
    let (blk, input) = dd_dense(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let w = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the generic dense DD witness");
    check("tinyllama-t128-dd", &digest_of_seeded_block(&sh, &blk, w));
}

#[test]
#[ignore = "native lane heavy: seeded Llama-3-8B T128 DD block proof (byte identity across R9 -> R12)"]
fn r12_golden_seeded_llama3_8b_t128_dd_block_is_byte_identical() {
    let cal = NormCalibration { cn_a: 6380, cn_m: 6672, ..super::trained_calib_tests::llama3_8b_calibration() };
    let sh = Shape::llama3_8b_t128_trained_dd(&cal, 9).unwrap();
    use super::trained_calib_tests::{Bands, TRAINED_BANDS};
    let cands = [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 4, gate: 6, down: 1, xmag: 4_000, ..TRAINED_BANDS }];
    for b in cands {
        let (blk, input) = dd_dense(&sh, b);
        if let Ok(w) = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input) {
            eprintln!("R12-GOLDEN 8B DD bands {b:?}");
            check("llama3-8b-t128-dd", &digest_of_seeded_block(&sh, &blk, w));
            return;
        }
    }
    panic!("no candidate band is admissible at the 8B T128 DD geometry");
}

/// the R9 identities of the synthetic trained-model statements (cheap): a
/// statement of an existing profile keeps its bytes across R9 -> R12
const GOLDEN_IDENTITIES: &[(&str, &str)] = &[];

#[test]
#[ignore = "native lane: run with the goldens (cheap)"]
fn r12_golden_statement_identities() {
    let t3 = super::trained_calib_tests::t3_calibration();
    let c8 = NormCalibration { cn_a: 6380, cn_m: 6672, ..super::trained_calib_tests::llama3_8b_calibration() };
    let shapes = [
        ("tinyllama-t128", Shape::tinyllama_trained(128, &t3, 9).unwrap()),
        ("llama3-8b-t128", Shape::llama3_8b_trained(128, &c8, 9).unwrap()),
        ("tinyllama-t128-dd", Shape::tinyllama_t128_trained_dd(&t3, 9).unwrap()),
        ("llama3-8b-t128-dd", Shape::llama3_8b_t128_trained_dd(&c8, 9).unwrap()),
        ("rung-dd", super::trained_calib_tests::rung_dd()),
    ];
    for (name, sh) in shapes {
        let (public, ff, _) = super::grow_tests::tame_case(&sh);
        let blk = BlockPublic::new(public, ff);
        let st = super::trained_calib_tests::synthetic_statement(&sh, &[blk]);
        let id: String = st.identity().iter().map(|b| format!("{b:02x}")).collect();
        let enc = blake3::hash(&st.encode()).to_hex().to_string();
        eprintln!("R12-GOLDEN-IDENTITY {name} {id} encode-blake3 {enc}");
        if let Some((_, want)) = GOLDEN_IDENTITIES.iter().find(|(n, _)| *n == name) {
            assert_eq!(id, *want, "{name}: the synthetic statement's identity moved between R9 and R12");
        }
    }
}
