//! **STAGE 37 (TEST-ONLY): EIGHT KEY-VALUE GROUPS, `lkv = 3` — "rung-K8".**
//!
//! **The gap this closes.** Stage 20 made the key-value GROUP a set of
//! sumcheck variables of the two bilinear attention slots `SC_SCORE` and
//! `SC_PV` — `lkv = log2(kv_heads)` of them, summed under a public
//! `eq(r_g, .)` (finding S19-F1). Everything proved or captured since is at
//! `lkv <= 2`: rung-G has one group bit, rung-K4, rung-P2 and 125M have two.
//! The native run gate's open item R5.8 item 3 says it in its own words:
//! "eight or more key-value groups are still unread". This file is the
//! Rust-side evidence at THREE group bits.
//!
//! **Why a test-only shape and not a `Shape::rung_k8` in `shape.rs`.** This
//! stage may not move a production file on the proving path, and `shape.rs`
//! is one (it is a source pin of every capture bundle). The geometry is
//! therefore built HERE through the existing `Shape::new` and
//! `RunShape::new`, with its own block and run profile strings (D17: a new
//! shape is a new profile). What that costs, stated rather than hidden:
//! `run_statement_file::shape_of_profile` does not know these two profiles,
//! so no run STATEMENT file can be written or read for rung-K8 by this
//! build, and the registry guards of stage 24 (which read the profile
//! literals out of `shape.rs` and `run.rs`) do not list them. The capture
//! bundles do not depend on either: a bundle carries its shape in
//! `run.json`, and the keyed hash rule derives the four keys from the
//! profile string alone (`HashTag::for_profile`).
//!
//! **THE SHAPE, AND WHY EACH NUMBER IS WHAT IT IS** (the full reasoning is in
//! the lane ledger, stage 37):
//!
//! * `kv_heads = 8` — the point of the stage, `lkv = 3`;
//! * `q_heads = 16`, so each group owns TWO query heads. Eight over eight is
//!   smaller and `Shape::new` accepts it, but its group map is the IDENTITY
//!   (`kv_of_slot(sl) == sl`, no head-in-group bit), so a construction that
//!   confused the head index with the group index would pass it — a
//!   degenerate geometry of exactly the kind that hid S19-F1. Sixteen over
//!   eight is the smallest head axis with a non-trivial group map.
//! * `head_dim = 8` — the head size rung-K4 and rung-P2 prove at. A
//!   `head_dim = 4` geometry (width 64) is also accepted and smaller, but no
//!   shape has ever proved at `head_dim = 4`; choosing it would put two
//!   untested axes into one shape, and a refusal could not be attributed.
//! * `width = q_heads * head_dim = 128`, forced; `d_pad = h_pad * head_dim =
//!   128` holds exactly, so the padded layout is rung-K4's (`t_pad 32`,
//!   `d_pad 128`, `h_pad 16`, `f_pad 256`) and `norm_wrho` stays 31.
//! * `tokens = 24`, `hidden = 192`, `log_cols = 10`, `inv_rate = 4`,
//!   `F_E = 12`, the generalised 9-row endpoint: rung-K4's, untouched.
//! * `Dom::Kv = t_pad * kv_heads * head_dim = 2^11`, `Dom::Q = 2^12`,
//!   `Dom::S = 2^14` — none below the row width, so ruling F-2's P-3
//!   refusal does not fire.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** A CORRECTNESS result at a new
//! development-grade profile (ruling P-7): the honest prover and the honest
//! verifier agree at `lkv = 3`, the witness equals the independent reference
//! kernel, and tampers in the LAST key-value group are rejected by the
//! VERIFIER. It is NOT a privacy result and NOT an acceptance.
//!
//! **THE CAPTURE RULE.** Everything here is public synthetic test data from
//! fixed-seed integer streams; the census prints fractions and live-slot
//! totals, never a value or a position.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::run_capture::{self, Bundle};
use super::run_sink::{DirSink, MemorySink, SegmentSink};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use private_block_kernel_shaped as kshaped;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------- the shape's own facts

/// The block profile of the test-only eight-key-value-head shape (D17).
pub(super) const K8_BLOCK_PROFILE: &str = "hashline-zk-mr1/private-block-rung-k8-t24-dev/1";
/// Its run profile, by the same rule: one profile per shape.
pub(super) const K8_RUN_PROFILE: &str = "hashline-zk-mr1/private-run-rung-k8-t24-dev/1";

/// **THE COUNTED RECEIPT LENGTH OF ONE rung-K8 BLOCK — the INDEPENDENT
/// Python model's own prediction, transcribed.**
///
/// `scripts/zk60_private_block_layout_model.py` has no command-line entry for
/// a shape it does not register (`--shape` is a closed choice), so the model
/// was driven as a LIBRARY, unedited: its own `Shape(...)` class at these
/// exact arguments, then `receipt_bytes(sh)["total"]`
/// (`results/zk60_block125m_lane/s37-model-prediction.json`). It is rung-K4's
/// 4,743,128 plus 37,088: `Dom::Kv` doubles (eight groups of eight against
/// four), and each bilinear slot gains one main round (`lkv` 3, not 2).
pub(super) const K8_FRAME_BYTES: usize = 4_780_216;

/// The model's other figures at this shape (same JSON), compared one by one
/// with the Rust's own count in [`the_rung_k8_layout_is_the_independent_models`].
struct ModelFigures {
    a_planes: usize,
    h_planes: usize,
    a_data_rows: usize,
    h_data_rows: usize,
    a_rows: usize,
    h_rows: usize,
    a_sites: usize,
    h_sites: usize,
    a_groups: usize,
    h_groups: usize,
    largest_slot_length: usize,
    main_rounds: usize,
    extension_rounds: usize,
    published_round_values: usize,
    challenge_draws: usize,
    bilinear_lengths: (usize, usize),
    u8_per_domain: [usize; 6],
    u8_lookups: usize,
    exp_pairs: usize,
    act_pairs: usize,
    receipt_total: usize,
}

const MODEL_RUNG_K8: ModelFigures = ModelFigures {
    a_planes: 83,
    h_planes: 52,
    a_data_rows: 487,
    h_data_rows: 626,
    a_rows: 733,
    h_rows: 732,
    a_sites: 122,
    h_sites: 52,
    a_groups: 36,
    h_groups: 9,
    largest_slot_length: 77,
    main_rounds: 223,
    extension_rounds: 25,
    published_round_values: 1_084,
    challenge_draws: 248,
    bilinear_lengths: (26, 32),
    u8_per_domain: [2_048, 155_648, 73_728, 53_248, 24_576, 245_760],
    u8_lookups: 555_008,
    exp_pairs: 16_384,
    act_pairs: 8_192,
    receipt_total: K8_FRAME_BYTES,
};

/// **THE DOWN-PROJECTION BAND A THREE-BLOCK rung-K8 CHAIN CARRIES**,
/// MEASURED by [`the_pinned_rung_k8_chain_band_is_the_first_admissible_one`]
/// exactly as stage 22 measured rung-K4's: **48, the recipe's own
/// single-block band** — no reduction is needed for three blocks at this
/// shape (rung-K4 needed 47). `dense_tests::band_down_run` has no `(192, 8)`
/// arm and falls back to exactly that single-block band, so the SHARED run
/// recipe `dense_tests::dense_run_case` already produces this band at
/// rung-K8 and this file uses it unchanged; the band test asserts both.
const K8_RUN_BAND: i64 = 48;

/// **rung-K8**: 24 tokens, width 128, hidden 192, sixteen query heads of
/// eight over EIGHT key-value heads, on the rungs' row geometry and the
/// generalised endpoint. Built only here (see the module note).
pub(super) fn rung_k8() -> Shape {
    Shape::new(
        "development rung, eight key-value heads (T24 / d128 / f192, 16 heads of 8 over 8 KV heads)",
        K8_BLOCK_PROFILE,
        24,
        128,
        192,
        16,
        8,
        8,
        10,
        4,
        12,
        9,
        None,
        None,
        None,
        None,
    )
    .expect("the rung-K8 shape is well formed")
}

fn k8_run_shape(l: usize) -> RunShape {
    RunShape::new(rung_k8(), l, K8_RUN_PROFILE).expect("the rung-K8 run shape")
}

fn every_registered_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()]
}

fn k8_context() -> Digest {
    *blake3::hash(b"private block: stage 37, the eight-key-value-head development shape").as_bytes()
}

/// the padded plane of a witness, as `int16`
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// the TRUE `(tokens, width)` input inside a padded `Dom::D` plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung-K8 plane map");
    let spec = IoSpec::new_shaped(sh, k8_context(), 0, 0).expect("the rung-K8 endpoint spec");
    prepare_endpoints(spec, &padded(w, ids.at(A_X)), &padded(w, ids.at(A_X2))).expect("the rung-K8 endpoint owners")
}

fn prove_k8(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

/// The fully dense RUN recipe — the shared `dense_tests::dense_run_case`,
/// unchanged, whose down band at this shape is [`K8_RUN_BAND`] (asserted by
/// the band test).
fn k8_dense_run_case(sh: &Shape) -> (AttentionPublic, FeedForwardPublic, Vec<i16>) {
    assert_eq!(super::dense_tests::band_down_run(sh), K8_RUN_BAND, "the shared run recipe's band at rung-K8 is not the measured one");
    super::dense_tests::dense_run_case(sh)
}

// ---------------------------------------------------------------- the geometry itself

/// **THE SHAPE IS WHAT IT SAYS IT IS**, before anything is proved at it:
/// every dimension, THREE group bits, two query heads per group, no padded
/// head slot, no P-3 lift on the three bilinear domains, and a NEW profile
/// whose keys differ from every registered profile's.
#[test]
fn the_rung_k8_shape_is_the_eight_key_value_head_geometry_it_claims() {
    let sh = rung_k8();
    let k4 = Shape::rung_k4();
    assert_eq!((sh.tokens, sh.width, sh.hidden), (24, 128, 192), "rung-K8's block dimensions");
    assert_eq!((sh.q_heads, sh.head_dim, sh.kv_heads), (16, 8, 8), "rung-K8's head axis");
    assert_eq!((sh.t_pad, sh.d_pad, sh.h_pad, sh.f_pad), (32, 128, 16, 256), "rung-K8's padded axes");
    assert_eq!((sh.t_pad, sh.d_pad, sh.h_pad, sh.f_pad), (k4.t_pad, k4.d_pad, k4.h_pad, k4.f_pad), "rung-K8's padded layout is meant to be rung-K4's");
    assert_eq!(sh.d_pad, sh.h_pad * sh.head_dim, "the padded head slots do not tile the padded width");
    assert_eq!(sh.width, sh.q_heads * sh.head_dim, "the true heads do not tile the width");
    assert_eq!(sh.kv_heads.trailing_zeros() as usize, 3, "rung-K8 must carry THREE group bits, which is the whole point of it");
    assert_eq!(sh.slots_per_kv_group(), 2, "slots per key-value group");
    assert_eq!(sh.log_slots_per_kv_group(), 1, "one head-in-group bit");
    // the head permutation is the identity (sixteen true heads in sixteen
    // slots), and the group of slot `sl` is its HIGH three bits
    let slots: Vec<usize> = (0..sh.q_heads).map(|h| sh.head_slot(h)).collect();
    assert_eq!(slots, (0..16).collect::<Vec<_>>(), "the head permutation");
    assert!((0..sh.h_pad).all(|s| sh.slot_is_true_head(s)), "rung-K8 has no padded head slot");
    for sl in 0..sh.h_pad {
        assert_eq!(sh.kv_of_slot(sl), sl / 2, "slot {sl}'s key-value group is not its high bits");
    }
    // the group map is NOT the identity: two different slots share a group
    assert_eq!(sh.kv_of_slot(14), sh.kv_of_slot(15), "slots 14 and 15 must share the LAST group");
    assert_eq!(sh.kv_of_slot(15), 7, "the last group is index 7");
    for dom in [Dom::Q, Dom::Kv, Dom::S] {
        assert_eq!(sh.log(dom), sh.natural_log(dom), "{dom:?} is lifted by P-3, so the bilinear slots cannot serve this shape");
    }
    assert_eq!((sh.log(Dom::Q), sh.log(Dom::Kv), sh.log(Dom::S)), (12, 11, 14), "the three bilinear domains' logs");
    assert!(sh.endpoint_general, "rung-K8 must ride the GENERALISED endpoint");
    assert!(sh.carries_pad_rule(), "rung-K8 must carry the pad rule");
    assert_eq!((sh.f_e, sh.norm_wrho, sh.wrho_s), (k4.f_e, k4.norm_wrho, k4.wrho_s), "rung-K8's calibration differs from rung-K4's");
    assert_eq!((sh.log_cols, sh.inv_rate, sh.endpoint_rows, sh.endpoint_log_n, sh.endpoint_inv_rate), (10, 4, 9, 10, 4), "rung-K8's row geometry and endpoint");
    // D17: a NEW profile with its own key set, distinct from EVERY registered
    // profile's keys in every role
    assert!(!sh.hashes_under_the_legacy_rule(), "rung-K8 must be TAGGED");
    assert_eq!(sh.hash_tag(), zkp_core::hashtag::HashTag::for_profile(K8_BLOCK_PROFILE), "the tag is not a function of the profile string");
    let mine = sh.hash_tag();
    let my_keys = [mine.transcript_key(), mine.column_key(), mine.leaf_key(), mine.node_key()].map(|k| *k.expect("a tagged profile carries all four keys"));
    for other in every_registered_shape() {
        assert_ne!(other.profile, sh.profile, "rung-K8 shares a profile with {}", other.name);
        let t = other.hash_tag();
        for k in [t.transcript_key(), t.column_key(), t.leaf_key(), t.node_key()].into_iter().flatten() {
            assert!(!my_keys.contains(k), "a rung-K8 key equals one of {}'s", other.name);
        }
    }
    for i in 0..4 {
        for j in i + 1..4 {
            assert_ne!(my_keys[i], my_keys[j], "two of rung-K8's own keys coincide");
        }
    }
    let rs = k8_run_shape(3);
    assert_eq!(rs.profile, K8_RUN_PROFILE);
    for p in [run::RUN_PROFILE_RUNG_G, run::RUN_PROFILE_RUNG_K4, run::RUN_PROFILE_RUNG_P2, run::RUN_PROFILE_RUNG_C6, run::RUN_PROFILE_RUNG_W14, run::RUN_PROFILE_RUNG_E32, run::RUN_PROFILE_M125] {
        assert_ne!(p, K8_RUN_PROFILE, "two runs share a profile");
    }
    // the two slots the stage is about
    assert_eq!(sh.slots()[SC_SCORE], (6, 2, 3), "SC_SCORE at rung-K8: lkv(3) + log2(head_dim)(3) main rounds, degree 3");
    assert_eq!(sh.slots()[SC_PV], (8, 2, 3), "SC_PV at rung-K8: lkv(3) + log2(t_pad)(5) main rounds, degree 3");
    assert!(sh.slot_lengths().iter().all(|l| l + 256 <= 512), "a mask row leaves the M budget");
    eprintln!(
        "S37 rung-K8: T{}/d{}/f{}, {} heads of {} over {} KV heads, pads ({}, {}, {}, {}), lkv 3, 2 heads per group, largest L {}, counted receipt {} B",
        sh.tokens,
        sh.width,
        sh.hidden,
        sh.q_heads,
        sh.head_dim,
        sh.kv_heads,
        sh.t_pad,
        sh.d_pad,
        sh.h_pad,
        sh.f_pad,
        sh.slot_lengths().iter().max().expect("slots"),
        sh.receipt_bytes().total
    );
}

/// **THE CHOICE, RECORDED.** Every `lkv = 3` geometry on the rungs' row
/// geometry (24 tokens, row width 2^10, rate 4, `F_E` 12) that is smaller
/// than rung-K8 is ACCEPTED by `Shape::new` — so the choice above is a
/// choice, made for the two reasons the module note gives (a non-identity
/// group map, and no never-proved head size), and not a refusal. Their
/// counted receipts are printed; none of them is proved here. And the
/// geometries below the row width ARE refused, by ruling F-2's name.
#[test]
fn every_smaller_eight_key_value_head_geometry_is_accepted_and_the_choice_is_recorded() {
    let accepted = [
        ("8 heads of 4 over 8 (width 32): identity group map, head_dim 4", 32usize, 64usize, 8usize, 4usize),
        ("8 heads of 8 over 8 (width 64): identity group map", 64, 128, 8, 8),
        ("16 heads of 4 over 8 (width 64): head_dim 4, never proved", 64, 128, 16, 4),
    ];
    let k8 = rung_k8().receipt_bytes().total;
    for (what, width, hidden, q, dh) in accepted {
        let sh = Shape::new("stage 37 survey", "hashline-zk-mr1/stage37-survey/1", 24, width, hidden, q, dh, 8, 10, 4, 12, 5 + (32 * width.next_power_of_two()).div_ceil(1024), None, None, None, None)
            .unwrap_or_else(|e| panic!("{what}: refused: {e}"));
        let total = sh.receipt_bytes().total;
        assert!(total < k8, "{what}: {total} B is not smaller than rung-K8's {k8} B");
        eprintln!("S37 SURVEY accepted, not chosen: {what}: counted receipt {total} B (rung-K8 {k8} B)");
    }
    // `head_dim = 2` puts `Dom::Kv = 32 * 8 * 2 = 2^9` below the row width
    let e = Shape::new("stage 37 survey", "hashline-zk-mr1/stage37-survey/1", 24, 32, 64, 16, 2, 8, 10, 4, 12, 6, None, None, None, None).err().expect("a Dom::Kv below the row width was accepted");
    assert!(e.contains("lifted by P-3"), "the refusal is not F-2's: {e}");
    eprintln!("S37 SURVEY refused by name: 16 heads of 2 over 8: {e}");
}

/// **THE COUNTED LAYOUT IS THE INDEPENDENT MODEL'S.** Every figure of
/// [`MODEL_RUNG_K8`] — the Python model's own output at this shape — against
/// the Rust's own count, and the receipt to the byte.
#[test]
fn the_rung_k8_layout_is_the_independent_models() {
    let sh = rung_k8();
    let want = &MODEL_RUNG_K8;
    let t = sh.totals();
    let sl = sh.slots();
    let published_round_values: usize = sl.iter().map(|(m, e, d)| (m + e) * (d + 1)).sum();
    let challenge_draws: usize = sl.iter().map(|(m, e, _)| m + e).sum();
    let lengths = sh.slot_lengths();
    assert_eq!(t.a_planes, want.a_planes, "A planes");
    assert_eq!(t.h_planes, want.h_planes, "H planes");
    assert_eq!(t.a_data_rows, want.a_data_rows, "A data rows");
    assert_eq!(t.h_data_rows, want.h_data_rows, "H data rows");
    assert_eq!(t.a_rows, want.a_rows, "A rows");
    assert_eq!(t.h_rows, want.h_rows, "H rows");
    assert_eq!(t.m_rows, 50, "M rows");
    assert_eq!(t.a_sites, want.a_sites, "A claim sites");
    assert_eq!(t.h_sites, want.h_sites, "H claim sites");
    assert_eq!(t.a_groups, want.a_groups, "A opening groups");
    assert_eq!(t.h_groups, want.h_groups, "H opening groups");
    assert_eq!(t.functionals, 34, "functionals");
    assert_eq!(t.largest_slot_length, want.largest_slot_length, "largest slot L");
    assert_eq!(t.main_rounds, want.main_rounds, "main rounds");
    assert_eq!(t.extension_rounds, want.extension_rounds, "extension rounds");
    assert_eq!(published_round_values, want.published_round_values, "published round values");
    assert_eq!(challenge_draws, want.challenge_draws, "sumcheck challenge draws per block");
    assert_eq!((lengths[SC_SCORE], lengths[SC_PV]), want.bilinear_lengths, "the two bilinear slots' mask lengths");
    assert_eq!(t.u8_per_domain, want.u8_per_domain.to_vec(), "U8 lookups per domain");
    assert_eq!(t.u8_lookups, want.u8_lookups, "U8 lookups");
    assert_eq!(t.exp_pairs, want.exp_pairs, "exp pairs");
    assert_eq!(t.act_pairs, want.act_pairs, "act pairs");
    assert_eq!(t.logup_sum_claim_keys, 1, "the LogUp sum claim raises more than one column-weight key");
    assert_eq!(t.receipt_bytes.total, want.receipt_total, "the Rust's counted receipt is not the model's prediction");
    assert_eq!(sh.receipt_bytes().total, K8_FRAME_BYTES);
}

// ---------------------------------------------------------------- the independent reference

/// **THE DENSE rung-K8 WITNESS EQUALS THE INDEPENDENT REFERENCE KERNEL.** The
/// read-only `private-block-kernel-shaped` crate takes this geometry
/// unaltered; its OWN rotated-key buffer carries eight pairwise different
/// groups, and the block output agrees on every true word. (The
/// plane-by-plane comparison of `parity.rs` is private to that file; the
/// output is the end-to-end statement.)
#[test]
fn the_dense_witness_equals_the_reference_kernel_at_the_rung_k8() {
    let s = rung_k8();
    let (words, input) = super::dense_tests::dense_words(&s);
    let (public, ff) = super::dense_tests::statement_of_words(&s, &words);
    let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
    let (exp, _) = crate::tables_attn::exp_member(0, s.head_dim, s.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member");
    let ksh = kshaped::Shape::new(s.tokens, s.width, s.hidden, s.q_heads, s.kv_heads, s.head_dim, s.f_e, F_P, s.wrho_s, s.norm_wrho);
    let mut scratch = vec![0i64; ksh.scratch_len()];
    let mut tbuf = vec![0i64; ksh.trace_len()];
    let mut out = vec![0i16; ksh.x_len()];
    let wr = kshaped::WeightsRef { wq: &words[0], wk: &words[1], wv: &words[2], wo: &words[3], gamma_a: &words[4], gamma_m: &words[5], wg_t: &words[6], wu_t: &words[7], wd_t: &words[8] };
    let tr = kshaped::TablesRef { rope_cos: &cos, rope_sin: &sin, exp: &exp, act: &act };
    let kernel = kshaped::run_shaped(&ksh, &input, &wr, &tr, &mut scratch, Some(&mut tbuf), &mut out);
    let wit = witness::build_shaped(&s, &public, &ff, &input);
    let w = match (kernel, wit) {
        (Ok(()), Ok(w)) => w,
        (Err(e), Ok(_)) => panic!("the rung-K8 dense witness was accepted where the reference kernel refused ({e:?})"),
        (Ok(()), Err(m)) => panic!("the rung-K8 dense witness refused (`{m}`) where the reference kernel accepted"),
        (Err(e), Err(m)) => panic!("both refused the rung-K8 dense recipe: kernel `{e:?}`, witness `{m}`"),
    };
    let (o, n) = ksh.part(kshaped::Part::Kr8);
    let kvw = s.kv_heads * s.head_dim;
    assert_eq!(n, s.tokens * kvw, "the kernel's kr8 buffer is not (tokens, kv_heads * head_dim)");
    for a in 0..s.kv_heads {
        for b in a + 1..s.kv_heads {
            let differs = (0..s.tokens).flat_map(|t| (0..s.head_dim).map(move |i| (t, i))).any(|(t, i)| tbuf[o + t * kvw + a * s.head_dim + i] != tbuf[o + t * kvw + b * s.head_dim + i]);
            assert!(differs, "the reference kernel's key-value groups {a} and {b} carry identical rotated keys");
        }
    }
    let mine = true_input(&s, &w.output().expect("the dense block's output is inside int16"));
    assert_eq!(mine.len(), out.len(), "the block output lengths differ");
    assert_eq!(mine, out, "the rung-K8 dense block output differs from the reference kernel's");
    assert!(out.iter().filter(|v| **v != 0).count() * 2 > out.len(), "the reference output is mostly zero, so the comparison is weak");
    eprintln!("S37 REFERENCE: the rung-K8 dense block output equals the independent kernel's on all {} words; the kernel's eight key-value groups are pairwise different", out.len());
}

// ---------------------------------------------------------------- one honest block

/// how non-trivial a rung-K8 witness is, as FRACTIONS and LIVE-SLOT COUNTS
/// only (the capture rule)
fn assert_non_trivial(sh: &Shape, ids: &Ids, w: &Witness, what: &str) {
    let (d, f, fp, dh, dp) = (sh.width, sh.hidden, sh.f_pad, sh.head_dim, sh.d_pad);
    let kvw = sh.kv_heads * dh;
    for (plane, name, floor) in [(A_G8, "gate", 50u64), (A_A16, "activation", 20)] {
        let p = &w.planes[ids.at(plane)];
        let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| p[*i] != 0).count();
        let pct = (100 * live as u64) / (sh.tokens * (f - d)) as u64;
        assert!(pct >= floor, "{what}: the {name} plane is nonzero at only {pct}% of the upper hidden half [{d}, {f})");
    }
    let o8 = &w.planes[ids.at(A_O8)];
    let live_slots = (0..sh.h_pad).filter(|sl| (0..sh.tokens).flat_map(|t| (0..dh).map(move |c| t * dp + sl * dh + c)).any(|i| o8[i] != 0)).count();
    assert_eq!(live_slots, sh.q_heads, "{what}: only {live_slots} of the {} head slots carry an attention output", sh.q_heads);
    let (kr, v8, qr) = (&w.planes[ids.at(A_KR8)], &w.planes[ids.at(A_V8)], &w.planes[ids.at(A_QR8)]);
    let group_live = |p: &Vec<i64>, g: usize| (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| j * kvw + g * dh + c)).any(|i| p[i] != 0);
    let live_groups = (0..sh.kv_heads).filter(|g| group_live(kr, *g) && group_live(v8, *g)).count();
    assert_eq!(live_groups, 8, "{what}: only {live_groups} of the eight key-value groups carry nonzero keys AND values");
    // ALL EIGHT groups pairwise different in keys AND in values: with three
    // group bits, coinciding groups would leave parts of `eq(r_g, .)`
    // unexercised
    for p in [kr, v8] {
        for a in 0..sh.kv_heads {
            for b in a + 1..sh.kv_heads {
                let differs = (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| (j, c))).any(|(j, c)| p[j * kvw + a * dh + c] != p[j * kvw + b * dh + c]);
                assert!(differs, "{what}: key-value groups {a} and {b} carry IDENTICAL data, so the three group bits are not exercised");
            }
        }
    }
    // and the two query heads INSIDE every group differ, so the head-in-group
    // bit is exercised too
    for g in 0..sh.kv_heads {
        let (s0, s1) = (2 * g, 2 * g + 1);
        let differs = (0..sh.tokens).flat_map(|t| (0..dh).map(move |c| (t, c))).any(|(t, c)| qr[t * dp + s0 * dh + c] != qr[t * dp + s1 * dh + c]);
        assert!(differs, "{what}: the two query heads of group {g} carry IDENTICAL rotated queries");
    }
    eprintln!("S37 CENSUS [{what}]: 16/16 head slots live, 8/8 key-value groups live and pairwise different (keys and values), both heads of every group different, the upper hidden half live");
}

/// **(a) THE HONEST rung-K8 BLOCK PROVES AND VERIFIES FROM BYTES**, on the
/// FULLY DENSE recipe with a generic hidden input. The frame is the counted
/// length (the model's prediction), and a one-byte truncation is refused.
#[test]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_k8() {
    let sh = rung_k8();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K8 dense honest witness");
    let ids = Ids::new(&sh).expect("the rung-K8 plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the honest rung-K8 witness is internally inconsistent");
    assert_non_trivial(&sh, &ids, &w, "one dense block");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_k8(&sh, &blk, w).expect("the rung-K8 dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), K8_FRAME_BYTES, "the rung-K8 frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung-K8 receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung-K8 receipt verifies from bytes");
    eprintln!("S37 rung-K8 DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung-K8 frame was accepted");
}

/// **(d) THE ALL-ZERO INPUT, NAMED AS A DEGENERATE CASE.** On the tame
/// fixture (the witness the second capture bundle carries) and on the dense
/// public weights: both prove and verify at the counted length. Neither says
/// anything about the group bits — every group is identically zero.
#[test]
fn the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_k8() {
    let sh = rung_k8();
    let tame = super::grow_tests::tame_case(&sh);
    let dense = super::dense_tests::dense_case(&sh);
    for (what, (public, ff, _)) in [("the tame fixture", tame), ("the dense public weights", dense)] {
        let input = vec![0i16; sh.tokens * sh.width];
        let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K8 all-zero witness");
        let blk = BlockPublic::new(public, ff);
        let t0 = std::time::Instant::now();
        let (expected, receipt, bytes) = prove_k8(&sh, &blk, w).expect("the rung-K8 all-zero prover");
        let prove_s = t0.elapsed().as_secs_f64();
        assert_eq!(bytes.len(), K8_FRAME_BYTES, "a receipt's length is a function of the shape alone");
        verify_inner_at(&sh, &blk, &expected, &receipt).expect("the all-zero receipt verifies in typed form");
        let t1 = std::time::Instant::now();
        verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the all-zero receipt verifies from bytes");
        eprintln!("S37 rung-K8 ALL-ZERO (degenerate) one block on {what}: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", t1.elapsed().as_secs_f64(), bytes.len());
    }
}

// ---------------------------------------------------------------- the negative controls

/// **(c) EVERY TAMPER IN THE LAST KEY-VALUE GROUP (INDEX 7) IS REJECTED BY THE
/// VERIFIER.** Group 7 is `0b111`: all three group bits set, the one group a
/// construction that summed fewer than three bits, or read any one of them
/// wrong, could not reach. On each of the four private planes `SC_SCORE`
/// (`A_QR8`, `A_KR8`) and `SC_PV` (`A_P`, `A_V8`) read:
///
/// * `A_KR8` and `A_V8` in group 7;
/// * `A_QR8` and `A_P` at BOTH head slots of group 7 (14 and 15), so the
///   head-in-group bit is covered in both of its values.
///
/// The honest control is asserted ACCEPTED first. A refusal by the PROVER is
/// not a soundness statement (a cheating prover does not run the honest
/// prover's checks), so verifier rejections are counted separately and all
/// six must be the verifier's.
#[test]
fn a_perturbation_in_the_last_key_value_group_is_rejected_by_the_verifier_at_the_rung_k8() {
    let sh = rung_k8();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K8 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-K8 plane map");
    let (tp, dp, dh) = (sh.t_pad, sh.d_pad, sh.head_dim);
    let kvw = sh.kv_heads * dh;
    let honest = outcome(&sh, &blk, clone_witness(&base));
    assert!(honest.is_accepted(), "the honest rung-K8 witness is not accepted: {}", honest.short());
    let g = 7usize;
    assert_eq!((sh.kv_of_slot(14), sh.kv_of_slot(15)), (g, g), "slots 14 and 15 must be group 7's two heads");
    let cases: [(&str, usize, usize); 6] = [
        ("A_KR8, the rotated key of key-value group 7 (token 3)", ids.at(A_KR8), 3 * kvw + g * dh + 5),
        ("A_V8, the value of key-value group 7 (source token 6)", ids.at(A_V8), 6 * kvw + g * dh + 1),
        ("A_QR8, the rotated query of head slot 14 (group 7, first head)", ids.at(A_QR8), 3 * dp + 14 * dh + 5),
        ("A_QR8, the rotated query of head slot 15 (group 7, second head)", ids.at(A_QR8), 4 * dp + 15 * dh + 2),
        ("A_P, a causally live softmax weight of head slot 14 (group 7)", ids.at(A_P), (14 * tp + 5) * tp + 2),
        ("A_P, a causally live softmax weight of head slot 15 (group 7)", ids.at(A_P), (15 * tp + 9) * tp + 4),
    ];
    let (mut prover, mut verifier) = (0usize, 0usize);
    for (what, plane, at) in cases {
        let mut w = clone_witness(&base);
        w.planes[plane][at] += 1;
        let o = outcome(&sh, &blk, w);
        eprintln!("S37 GROUP-7 TAMPER {what}: {}", o.short());
        match o {
            Outcome::Accepted => panic!("{what} was ACCEPTED at rung-K8"),
            Outcome::ProverRefused(_) => prover += 1,
            Outcome::VerifierRejected(_) => verifier += 1,
        }
    }
    eprintln!("S37 GROUP-7 SWEEP: {prover} refused by the prover, {verifier} rejected by the VERIFIER, 0 accepted");
    assert_eq!(prover + verifier, 6, "not every case was exercised");
    assert_eq!(verifier, 6, "a tamper was caught by the prover rather than the verifier, which is not a soundness statement");
}

/// **EXCHANGING GROUP 7's KEY FAMILY WITH A GROUP THAT DIFFERS IN EXACTLY ONE
/// GROUP BIT IS REJECTED BY THE VERIFIER — for each of the three bits.**
/// Group 7 (`111`) against group 6 (`110`, the low bit), group 5 (`101`, the
/// middle bit) and group 3 (`011`, the high bit). A construction blind to any
/// ONE of the three bits would accept exactly one of these swaps. The values
/// are untouched, so each is a statement about the group map alone.
#[test]
fn exchanging_group_sevens_keys_across_each_single_group_bit_is_rejected_at_the_rung_k8() {
    let sh = rung_k8();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K8 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-K8 plane map");
    let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-K8 witness is not accepted");
    let key_planes = [ids.at(A_K8), ids.at(A_RKL), ids.at(A_KR8), ids.at(A_RKRL)];
    for (other, bit) in [(6usize, "low"), (5, "middle"), (3, "high")] {
        assert_eq!((7 ^ other).count_ones(), 1, "groups 7 and {other} must differ in exactly one bit");
        let mut w = clone_witness(&base);
        let mut moved = 0usize;
        for p in key_planes {
            for t in 0..sh.t_pad {
                for i in 0..dh {
                    let (a, b) = (t * kvw + 7 * dh + i, t * kvw + other * dh + i);
                    if w.planes[p][a] != w.planes[p][b] {
                        moved += 1;
                    }
                    w.planes[p].swap(a, b);
                }
            }
        }
        assert!(moved > 0, "key-value groups 7 and {other} carry identical keys: the swap is a no-op");
        let o = outcome(&sh, &blk, w);
        eprintln!("S37 GQA SWAP groups 7 <-> {other} (the {bit} group bit; {moved} positions differ): {}", o.short());
        assert!(matches!(o, Outcome::VerifierRejected(_)), "the rung-K8 swap of groups 7 and {other} was not rejected by the VERIFIER: {}", o.short());
    }
}

// ---------------------------------------------------------------- a three-block run

/// The honest chain of `l` rung-K8 blocks: each block's hidden output is the
/// next one's hidden input, and none of it is published.
struct K8Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl K8Chain {
    fn build(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> K8Chain {
        let ids = Ids::new(sh).expect("the rung-K8 plane map");
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the rung-K8 chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        K8Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl RunWitnessSource for K8Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// the run statement and the two EXTERNAL endpoint owners of a rung-K8 chain
fn k8_statement_of(c: &K8Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let spec = IoSpec::new_shaped(&c.sh, k8_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(k8_run_shape(l), k8_context(), expected, blocks, &vec![(0, 0); l]).expect("the rung-K8 run statement");
    (st, owners)
}

/// the chain of `l` blocks on the fully dense run recipe (`dense`) or on the
/// tame fixture with the all-zero input, and its `l` public statements
fn k8_chain(l: usize, dense: bool) -> (K8Chain, Vec<BlockPublic>) {
    let sh = rung_k8();
    let (public, ff, x0) = if dense {
        k8_dense_run_case(&sh)
    } else {
        let (p, f, _) = super::grow_tests::tame_case(&sh);
        (p, f, vec![0i16; sh.tokens * sh.width])
    };
    let blocks = (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect();
    (K8Chain::build(&sh, l, public, ff, x0), blocks)
}

/// **THE PINNED CHAIN BAND IS THE FIRST ADMISSIBLE ONE — MEASURED**, exactly
/// as stage 22 measured rung-K4's: the down band is walked DOWN from the
/// recipe's own single-block band and the first one at which the witness
/// builder accepts all three blocks is taken.
#[test]
fn the_pinned_rung_k8_chain_band_is_the_first_admissible_one() {
    use super::dense_tests::{band_down, dense_words_with, statement_of_words, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    let sh = rung_k8();
    let ids = Ids::new(&sh).expect("plane map");
    let mut found: Option<i64> = None;
    for down in (1..=band_down(&sh)).rev() {
        let (words, input) = dense_words_with(&sh, BAND_ATTN, BAND_GATE, down, GAIN, INPUT_MAG);
        let (public, ff) = statement_of_words(&sh, &words);
        let mut x = input;
        let mut ok = true;
        for k in 0..3 {
            match witness::build_shaped(&sh, &public, &ff, &x) {
                Ok(w) => x = true_input(&sh, &padded(&w, ids.at(A_X2))),
                Err(m) => {
                    eprintln!("S37 K8 DENSE RUN band {down}: the witness builder refused block {k} of the chain: {m}");
                    ok = false;
                    break;
                }
            }
        }
        if ok {
            found = Some(down);
            break;
        }
    }
    let band = found.expect("no fully dense band makes a three-block chain admissible at rung-K8");
    eprintln!("S37 K8 DENSE RUN: the first admissible three-block down band is {band} (the recipe's single-block band is {})", band_down(&sh));
    assert_eq!(band, K8_RUN_BAND, "K8_RUN_BAND is not the first admissible band");
    assert_eq!(super::dense_tests::band_down_run(&sh), K8_RUN_BAND, "the shared run recipe's band at rung-K8 is not the first admissible one");
}

/// A temporary run directory under the system temporary directory, removed
/// when the test leaves. Never inside the repository.
struct TempRunDir(PathBuf);

impl TempRunDir {
    fn new(tag: &str) -> TempRunDir {
        let n = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
        let p = std::env::temp_dir().join(format!("hl-private-run-s37-{tag}-{}-{n}", std::process::id()));
        std::fs::create_dir_all(&p).unwrap_or_else(|e| panic!("the test's temporary run directory {}: {e}", p.display()));
        TempRunDir(p)
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempRunDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// **(b) AN HONEST THREE-BLOCK FULLY DENSE rung-K8 RUN PROVES AND VERIFIES —
/// STREAMING.** The segments go to a directory as they are finished (and to
/// memory, for the comparison); the STREAMING verifier reads them back one
/// file at a time, the in-memory verifier agrees, every segment is the
/// counted length, and one flipped byte in the LAST segment's file is
/// refused by the streaming verifier. Every block's census is asserted, so
/// the eight groups carry different data in all three blocks.
#[test]
fn an_honest_three_block_fully_dense_run_verifies_streaming_at_the_rung_k8() {
    let sh = rung_k8();
    let ids = Ids::new(&sh).expect("plane map");
    let (mut c, blocks) = k8_chain(3, true);
    for k in 0..3 {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a fully dense witness of the chain");
        assert_non_trivial(&sh, &ids, &w, &format!("run block {k}"));
    }
    let (st, owners) = k8_statement_of(&c, 3, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    let tmp = TempRunDir::new("k8-dense");
    let mut disk = DirSink::create(tmp.path(), 3).expect("the run directory");
    let mut mem = MemorySink::default();
    let t0 = std::time::Instant::now();
    let stats = run::prove_run(&st, &blocks, &mut c, owners, &mut |k, bytes| {
        mem.accept(k, bytes.clone())?;
        disk.accept(k, bytes)
    })
    .expect("the honest three-block fully dense rung-K8 run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    let counted = super::run_tests::counted_segment_bytes(&sh, 3, rows);
    assert_eq!(stats.segment_bytes, counted, "a rung-K8 segment is not the counted length");
    assert_eq!(disk.lengths(), &counted[..], "a file on disk is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the honest rung-K8 run verifies STREAMING, one file at a time");
    let stream_s = t1.elapsed().as_secs_f64();
    run::verify_run(&st, &blocks, mem.segments()).expect("the honest rung-K8 run verifies from its segments in memory");
    // one flipped byte in the last segment's FILE
    let last = super::run_sink::segment_paths(tmp.path(), 3).expect("the three segment files")[2].clone();
    let mut b = std::fs::read(&last).expect("the last segment");
    let mid = b.len() / 2;
    b[mid] ^= 1;
    std::fs::write(&last, &b).expect("rewrite the last segment");
    let e = run::verify_run_from_dir(&st, &blocks, tmp.path()).err().expect("a flipped byte in the last segment was ACCEPTED by the streaming verifier");
    eprintln!(
        "S37 K8 FULLY DENSE RUN L=3 (down band {K8_RUN_BAND}): prove {prove_s:.2} s, streaming verify {stream_s:.2} s, segments {:?} B (total {} B), boundary {rows} rows; a flipped byte in segment 2 refused: {}",
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>(),
        e.chars().take(160).collect::<String>()
    );
}

// ---------------------------------------------------------------- the two capture bundles

/// Prove an honest `l`-block rung-K8 run and CAPTURE its verification.
fn prove_and_capture_k8(l: usize, dense: bool) -> (Vec<Vec<u8>>, Bundle) {
    let (mut c, blocks) = k8_chain(l, dense);
    let (st, owners) = k8_statement_of(&c, l, &blocks);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&st, &blocks, &mut c, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest rung-K8 run proves");
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(st.capture_header().expect("the run's capture header"), st.binding().expect("the run binding"));
    run::verify_run(&st, &blocks, &segs).expect("the honest rung-K8 run verifies");
    let bundle = run_capture::take().expect("a bundle for an accepted run");
    drop(guard);
    (segs, bundle)
}

fn count(haystack: &[u8], needle: &str) -> usize {
    let n = needle.as_bytes();
    if n.is_empty() || haystack.len() < n.len() {
        return 0;
    }
    (0..=haystack.len() - n.len()).filter(|i| &haystack[*i..*i + n.len()] == n).count()
}

fn contains(haystack: &[u8], needle: &str) -> bool {
    count(haystack, needle) > 0
}

/// **(f) STAGE 37: `run-s-dense-k8` and `run-t-zero-k8`**, written exactly as
/// stage 22 wrote `run-i-dense-k4` / `run-j-zero-k4`: three blocks each, the
/// classic `/4-run` encoding, the D19 tag, the public tables' values.
///
/// **Why they exist.** Every bundle the native run gate has read is at
/// `lkv <= 2`. Here slots 08 and 09 carry `{"kind":"eq","start":0,
/// "point":[<THREE Fp2>]}`, the group sum has eight terms, and `point` is the
/// leading THREE entries of that slot's head challenge, which a reader
/// re-derives from `definition_challenges` and COMPARES (ruling T-7).
///
/// Nothing here deletes or rewrites a bundle: `write_bundle` creates every
/// file with `create_new`, so a re-run into an existing directory refuses.
#[test]
#[ignore = "writes the stage-37 rung-K8 gate bundles; set HL_RUN_CAPTURE_DIR, HL_RUN_CAPTURE_PUBLIC_TABLES=1 and HL_TEST_SOURCE_COMMIT"]
fn write_the_k8_gate_bundles() {
    let root = PathBuf::from(std::env::var("HL_RUN_CAPTURE_DIR").expect("HL_RUN_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    assert!(
        std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").map(|v| v == "1").unwrap_or(false),
        "HL_RUN_CAPTURE_PUBLIC_TABLES=1 is not set: these bundles exist so the run gate can close every slot's terminal identity at THREE group bits, which needs the public tables' VALUES"
    );
    // finding E32-F1: a stale source label is a defect, so an absent one is
    // refused rather than defaulted
    let commit = std::env::var("HL_TEST_SOURCE_COMMIT").expect("HL_TEST_SOURCE_COMMIT is not set: the bundle must name the commit it was taken at");
    assert!(!commit.is_empty() && commit != "uncommitted-test", "HL_TEST_SOURCE_COMMIT must be the HEAD the capture is taken at");
    assert!(!run_capture::array_store_wanted(), "these bundles are the classic /4-run encoding, as rung-K4's were; unset HL_RUN_CAPTURE_ARRAYS");
    let sh = rung_k8();
    assert!(!sh.hashes_under_the_legacy_rule(), "these bundles are meant to be TAGGED and this shape is not");
    let lkv = (sh.kv_heads as u32).trailing_zeros() as usize;
    assert_eq!(lkv, 3, "this shape does not carry three group bits, which is the only reason these bundles exist");
    let mut total = 0usize;
    for (tag, dense) in [("run-s-dense-k8", true), ("run-t-zero-k8", false)] {
        let (segs, bundle) = prove_and_capture_k8(3, dense);
        assert!(contains(&bundle.run_json, "\"hash_tag\":{\"rule\":\"blake3-keyed/1\""), "{tag}: the run file does not name the keyed hash rule");
        assert!(contains(&bundle.run_json, "\"public_tables_included\":true"), "{tag}: the run file does not declare that the public tables are included");
        assert!(contains(&bundle.run_json, K8_RUN_PROFILE), "{tag}: the run file does not carry the rung-K8 run profile");
        assert!(contains(&bundle.run_json, K8_BLOCK_PROFILE), "{tag}: the run file does not carry the rung-K8 block profile");
        assert!(contains(&bundle.run_json, &format!("\"source_commit\":{commit:?}")), "{tag}: the run file does not carry the source commit {commit}");
        let (score, pv) = (sh.slots()[SC_SCORE], sh.slots()[SC_PV]);
        assert_eq!((score, pv), ((6, 2, 3), (8, 2, 3)), "the rung-K8 bilinear schedule moved");
        for (k, stage) in bundle.stages.iter().enumerate() {
            for (s, (main, ext, degree)) in [(SC_SCORE, score), (SC_PV, pv)] {
                let head = format!("{{\"slot\":{s},\"name\":{:?},\"kind\":\"Private\",\"main\":{main},\"extension\":{ext},\"degree\":{degree},", SLOT_NAMES[s]);
                assert!(contains(stage, &head), "{tag} stage {k}: slot {s} does not report the repaired schedule ({main}, {ext}, {degree})");
            }
            assert!(
                count(stage, "\"tables\":[{\"kind\":\"eq\",\"start\":0,\"point\":[") >= 2,
                "{tag} stage {k}: the two bilinear slots do not both open their table list with the group eq at start 0"
            );
        }
        let dir = root.join(tag);
        let note = format!(
            "Bundle `{tag}`: one honest three-block run at the EIGHT-KEY-VALUE-HEAD\ndevelopment shape rung-K8 (24 tokens, width 128, hidden 192, 16 query heads of 8\nover 8 key-value heads, two query heads per group, no padded head slot; padded\nlayout t_pad 32 / d_pad 128 / h_pad 16 / f_pad 256, rung-K4's), under the D19\nseparating hash tag, with the public tables' values. Lane stage 37.\n\nTEST-ONLY SHAPE. rung-K8 is built in `hashline/src/private_block/k8_tests.rs`\nthrough the existing `Shape::new` / `RunShape::new`; it is NOT registered in\n`shape.rs` or `run.rs`, so this build can write no run STATEMENT file for it.\nThe bundle carries its shape in `run.json`, and the four hash-tag keys derive\nfrom the block profile string alone.\n\nWHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Every bundle written before this\none is at log2(kv_heads) <= 2. The repaired bilinear attention argument (lane\nstage 20, finding S19-F1) SUMS over the {lkv} key-value group bits under a\npublic eq(r_g, .). Here:\n\n* `arguments[8]` (`10 score matmul`) is (main {}, extension {}, degree {}) and\n  `arguments[9]` (`11 PV matmul`) is (main {}, extension {}, degree {});\n* each of those two slots' `tables` begins with\n  `{{\"kind\":\"eq\",\"start\":0,\"point\":[<THREE Fp2 values>]}}`. The point is the\n  leading {lkv} entries of that slot's head challenge, which a reader\n  RE-DERIVES from the slot's own `definition_challenges` and COMPARES; it must\n  never take a value from it (ruling T-7).\n* the PRIVATE tables are unchanged in number, order and role, so\n  `plane_index.slot_planes[8]` and `[9]` are the same two-plane lists as at\n  rung-G and rung-K4.\n\nHidden input and public weights: {}\n\nNEW PROFILES (D17): `{K8_BLOCK_PROFILE}` for the block and\n`{K8_RUN_PROFILE}` for the run. No byte of any earlier profile moves.\n\nDevelopment grade (ruling P-7). Still not a privacy result: no gate has read\nthis.",
            score.0,
            score.1,
            score.2,
            pv.0,
            pv.1,
            pv.2,
            if dense {
                "the FULLY DENSE run recipe (`private_block::dense_tests::dense_run_case`, unchanged) at this shape's MEASURED three-block down band, 48, which is the recipe's own single-block band and `band_down_run`'s fallback at (192, 8) (pinned in `k8_tests.rs` as `K8_RUN_BAND`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half of the feed-forward planes live, sixteen of sixteen head slots live, ALL EIGHT key-value groups carrying PAIRWISE DIFFERENT keys and values and the two query heads of every group different, in every block. THE FIRST CAPTURE WITH MORE THAN TWO GROUP BITS"
            } else {
                "the ALL-ZERO hidden plane on the lane's synthetic tame fixture: the fixed input the privacy case is stated at, and a DEGENERATE witness (every key-value group identically zero), kept as the pair's control"
            }
        );
        run_capture::write_bundle(
            &dir,
            &bundle,
            &segs,
            &note,
            "HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<HEAD at capture> cargo test --release --lib private_block::k8_tests::write_the_k8_gate_bundles -- --ignored --nocapture",
        )
        .expect("the stage-37 rung-K8 gate bundle is written");
        let n: usize = std::fs::read_dir(&dir).expect("the bundle directory").filter_map(|e| e.ok()).map(|e| e.metadata().map(|m| m.len() as usize).unwrap_or(0)).sum();
        total += n;
        assert!(n < 120_000_000, "{tag} is {n} B, past the 120 MB ceiling");
        eprintln!(
            "S37 K8 GATE BUNDLE {tag}: {} B run file, {} B of stage files, {} B of segments (pinned by digest, not written), {n} B on disk ({:.1} MB)",
            bundle.run_json.len(),
            bundle.stages.iter().map(|s| s.len()).sum::<usize>(),
            segs.iter().map(|s| s.len()).sum::<usize>(),
            n as f64 / 1e6
        );
    }
    eprintln!("S37 K8 GATE BUNDLES total about {:.1} MB in {}", total as f64 / 1e6, root.display());
}
