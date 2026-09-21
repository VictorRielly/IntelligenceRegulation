//! The acceptance tests of the ORDERED CHANGE LIST of
//! `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §9 — the steps that
//! grow the toy private block towards the development rung and the 125M shape.
//!
//! Every test here is on the TOY profile unless it says otherwise, and the
//! standing condition of the whole lane (ruling P-8) is that the toy stays
//! BYTE-FROZEN: `tests.rs` and `zero_witness_tests.rs` assert the 2,816,472-byte
//! receipt, and nothing in this file may move it.
//!
//! Nothing here establishes a privacy or a soundness property; these are
//! mechanical acceptance checks that a growth step did what it said.

use super::argument::{table_values_act, table_values_act_at, table_values_exp, table_values_exp_at, table_values_u8, table_values_u8_at};
use super::layout::*;
use super::protocol::{logup_sum_claim, opening_groups_at};
use super::*;
use crate::field::Fp2;
use crate::pcs::{Slice, ZClaim, ZPart};

// ---------------------------------------------------------------- the freeze gate

/// THE TOY FREEZE GATE (ruling P-8), as a literal rather than a
/// self-consistency check. `schedule_digest` is absorbed into the transcript
/// (`private_block.rs`), so if it moves, every toy receipt moves with it — and
/// `Layout::new().schedule_digest() == lay.schedule_digest()` cannot see that,
/// because both sides move together. This constant was captured on the merged
/// tree at the start of the growth lane, BEFORE step S1, and no step S1..S15
/// may change it: the 125M shape is a NEW profile beside the toy, never an
/// edit of it (D17).
pub(crate) const TOY_SCHEDULE_DIGEST: [u8; 32] = [
    112, 56, 132, 168, 120, 2, 56, 138, 36, 107, 39, 200, 210, 57, 84, 103, 114, 193, 232, 211, 163, 155, 89, 43, 184, 176, 15, 139, 226, 31, 139, 141,
];

#[test]
fn the_toy_schedule_digest_is_frozen() {
    let lay = Layout::new();
    assert_eq!(lay.schedule_digest(), TOY_SCHEDULE_DIGEST, "the TOY profile's transcript-bound schedule digest moved");
    // and the profile string itself, which names the shape and the geometry
    assert!(lay.describe()[0].starts_with("private-block-t32/1: T32 d16 H2 KV1 dh8 F16; n=256 "), "the toy profile line moved: {}", lay.describe()[0]);
}

// ---------------------------------------------------------------- S1: `U8_LEN` vs `N`

/// **S1**, trap T-1. `N` meant two things: the width of a committed row and
/// the number of entries in each lookup table. They are now two constants, and
/// this test pins which is which. At the toy shape they are EQUAL, which is
/// exactly why the split moves no byte — and why a test that only checked the
/// toy's numbers would prove nothing. So the test asserts the two INVARIANTS
/// that survive a row-width change instead of the coincidence:
///
/// * the three table-value vectors are `U8_LEN` long, whatever `N` is;
/// * the in-class guards' bound never exceeds the arrays they index.
#[test]
fn the_byte_table_length_is_split_from_the_row_width() {
    assert_eq!(U8_LEN, 256, "the byte class is [0, 256) at every shape");
    assert_eq!(N, 1 << LOG_N, "N is the row width");
    // the coincidence that makes S1 byte-identical here, stated as such
    assert_eq!(U8_LEN, N, "at the TOY shape the two meanings coincide");

    let (blk, _) = BlockPublic::synthetic_fixture();
    let (public, ff) = (blk.attention(), blk.feed_forward());
    let z = Fp2::ZERO;
    assert_eq!(table_values_u8(z).len(), U8_LEN);
    assert_eq!(table_values_exp(public, Fp2::ONE, z).len(), U8_LEN);
    assert_eq!(table_values_act(ff, Fp2::ONE, z).len(), U8_LEN);

    // M-4: the guards at `protocol.rs` test `[0, U8_LEN)` and then index
    // `public.exp` / `ff.act` with the value. If the bound were the row width,
    // a witness value of 300 at `N = 16,384` would index past the end of a
    // 256-word table: an out-of-bounds PANIC, not a refusal.
    assert_eq!(public.exp.len(), U8_LEN, "the exp table is exactly the byte class");
    assert_eq!(ff.act.len(), U8_LEN, "the activation table is exactly the byte class");
}

/// **S1 / M-4, the behaviour.** An out-of-class witness value must be REFUSED,
/// never panic. `tamper.rs::a_limb_outside_its_byte_range_is_rejected_by_the_lookups`
/// covers the refusal end to end; this test pins the mechanism the refusal
/// rests on — a value outside `[0, U8_LEN)` is counted into bucket 0 and so
/// has no partner on the table side, which is what makes the value-0 LogUp sum
/// fail to close. It is stated as a property of the guard, at every shape.
#[test]
fn an_out_of_class_lookup_value_falls_into_bucket_zero() {
    let bucket = |v: i64| if (0..U8_LEN as i64).contains(&v) { v as usize } else { 0 };
    assert_eq!(bucket(0), 0);
    assert_eq!(bucket(255), 255);
    for v in [256i64, 300, 1_128, 16_383, -1] {
        assert_eq!(bucket(v), 0, "an out-of-class value must land in bucket 0, not index the table");
        assert!(bucket(v) < U8_LEN, "the bucket index is always inside the histogram");
    }
}

// ------------------------------------------------- S4: the lookup-summation repair

/// THE DEVELOPMENT RUNG's row geometry (memo §9a): `log_cols = 10`, so
/// `n = 1024`.
const RUNG_LOG_COLS: usize = 10;

/// The rung's nine domains, as `(name, natural log, carries H planes)`
/// [memo §9a, "Domains at the rung"]. `Tab` 8 and `L` 9 sit BELOW the row
/// width, `Kv` 10 sits at it, and `D`/`Q` 12, `S`/`F` 13 sit above: that is
/// the straddle, and it is what raises three distinct column-weight keys.
const RUNG_DOMAINS: [(&str, usize, bool); 9] =
    [("T", 5, false), ("Ht", 8, false), ("L", 9, true), ("D", 12, true), ("Q", 12, true), ("Kv", 10, true), ("S", 13, true), ("F", 13, true), ("Tab", 8, true)];

/// Rebuild `protocol::logup_sum_claim` from a list of `H` plane domain logs at
/// a row width of `1 << log_n`, laying the planes out exactly as
/// `Layout::new` does: one `re` slice then one `im` slice, each
/// `max(1, size / n)` rows, every plane row aligned.
///
/// This is a RECONSTRUCTION, and it is used only because the module cannot yet
/// be instantiated at any geometry but the toy's (that is step S5). The test
/// below earns the right to use it by showing it reproduces the real
/// `logup_sum_claim(&Layout::new())` at the toy, part for part.
fn sum_claim_from_logs(logs: &[(usize, bool)], log_n: usize) -> ZClaim {
    let n = 1usize << log_n;
    let mut row = 0usize;
    let mut parts = Vec::new();
    for (log, is_table) in logs {
        let sign = if *is_table { Fp2::ONE.neg() } else { Fp2::ONE };
        let r = std::cmp::max(1, (1usize << log) / n);
        for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
            parts.push(ZPart { slice: Slice { offset: (row + k * r) * n, log_size: *log as u32 }, coef: sign.mul(u), point: vec![] });
        }
        row += 2 * r;
    }
    ZClaim { parts, value: Fp2::ZERO }
}

/// the reconstruction above is the real thing, checked at the toy
#[test]
fn the_reconstructed_sum_claim_equals_the_modules_own_at_the_toy() {
    let lay = Layout::new();
    let real = logup_sum_claim(&lay);
    let logs: Vec<(usize, bool)> = lay.h_planes().into_iter().map(|p| (h_dom(p).log(), h_is_table(p))).collect();
    let rebuilt = sum_claim_from_logs(&logs, LOG_N);
    assert_eq!(real.parts.len(), rebuilt.parts.len(), "part count");
    for (i, (a, b)) in real.parts.iter().zip(rebuilt.parts.iter()).enumerate() {
        assert_eq!((a.slice.offset, a.slice.log_size), (b.slice.offset, b.slice.log_size), "part {i} slice");
        assert_eq!(a.coef, b.coef, "part {i} coefficient");
        assert!(a.point.is_empty() && b.point.is_empty(), "part {i} point");
    }
}

/// **S4 / B-3, THE BUG.** At the development rung the module, as it stands,
/// cannot produce a proof AT ALL — not slowly, not with a worse bound: the
/// single value-0 LogUp sum claim has parts under three different
/// column-weight keys, `check_opening` refuses before any byte is produced and
/// `zkp-core`'s PCS asserts below it.
///
/// This test asserts the repaired behaviour — ONE key at the rung — and so
/// FAILS today with exactly that refusal. It is ignored until the repair
/// lands (ruling P-7: reproduce the failure first).
#[test]
fn the_logup_sum_claim_has_one_column_weight_key_at_the_rung() {
    // the module's own lift rule, asked at the rung's row width
    let logs: Vec<(usize, bool)> = RUNG_DOMAINS
        .iter()
        .filter(|(_, _, carries_h)| *carries_h)
        .map(|(_, natural, carries_h)| (domain_log_at(*natural, *carries_h, RUNG_LOG_COLS), false))
        .collect();
    let claim = sum_claim_from_logs(&logs, RUNG_LOG_COLS);
    let groups = opening_groups_at(&[claim], RUNG_LOG_COLS).expect("the sum claim must be openable at the rung");
    assert_eq!(groups.len(), 1, "the value-0 LogUp sum claim must raise exactly ONE column-weight key");
}

/// the same geometry WITHOUT the lift, kept as the standing reproduction of
/// B-3: three keys, and the refusal by name
#[test]
fn the_unlifted_rung_sum_claim_raises_three_keys_and_is_refused() {
    let logs: Vec<(usize, bool)> = RUNG_DOMAINS.iter().filter(|(_, _, c)| *c).map(|(_, natural, _)| (*natural, false)).collect();
    let claim = sum_claim_from_logs(&logs, RUNG_LOG_COLS);
    let keys: std::collections::BTreeSet<(usize, usize)> =
        claim.parts.iter().map(|p| { let (_, c0, len) = super::protocol::part_key_at(p, RUNG_LOG_COLS); (c0, len) }).collect();
    assert_eq!(keys.into_iter().collect::<Vec<_>>(), vec![(0, 256), (0, 512), (0, 1024)], "the three keys memo §9a predicts");
    let err = opening_groups_at(&[claim], RUNG_LOG_COLS).expect_err("three keys must be refused");
    assert_eq!(err, "private block: claim parts with different column weights");
}

/// **S4, the repair's OWN risk (§4.1 condition 1).** The lift makes the three
/// table planes longer than the byte class. If the padded positions carried
/// their own index, the byte range proof would admit `1 << LOG_N` values
/// instead of 256 — a soundness hole created by the fix for a shape bug. The
/// padded entries repeat `i mod U8_LEN`, so the SET of proved values is still
/// exactly the 256 byte rows at any lifted length.
///
/// This test guards the fix, not the bug: it passes trivially at the toy's
/// unlifted length and would fail at a lifted one if the rule were wrong, so
/// it is run at BOTH.
#[test]
fn the_lifted_u8_table_proves_exactly_256_values() {
    let (blk, _) = BlockPublic::synthetic_fixture();
    let (public, ff) = (blk.attention(), blk.feed_forward());
    let (g, beta) = (Fp2::from_u64(7), Fp2::from_u64(11));
    let set = |v: &[Fp2]| v.iter().copied().collect::<std::collections::HashSet<Fp2>>();
    let base_u8 = set(&table_values_u8_at(U8_LEN, g));
    let base_exp = set(&table_values_exp_at(U8_LEN, public, beta, g));
    let base_act = set(&table_values_act_at(U8_LEN, ff, beta, g));
    for len in [U8_LEN, 1usize << RUNG_LOG_COLS, 1usize << 14] {
        let u8_tab = table_values_u8_at(len, g);
        assert_eq!(u8_tab.len(), len, "the table plane is as long as its domain");
        let distinct = set(&u8_tab);
        assert_eq!(distinct.len(), U8_LEN, "a lifted U8 table must still prove exactly {U8_LEN} values, not {len}");
        // and they are the SAME 256 values the unlifted table proves
        assert_eq!(distinct, base_u8, "the lift changed WHICH values the U8 table proves");
        // a value of 300 is not a byte and is in no lifted table
        assert!(!distinct.contains(&Fp2::from_i64(300).add(g)), "300 is not a byte and must not be provable");
        // the two paired tables are lifted by the same rule
        let exp_tab = table_values_exp_at(len, public, beta, g);
        let act_tab = table_values_act_at(len, ff, beta, g);
        assert_eq!((exp_tab.len(), act_tab.len()), (len, len));
        assert_eq!(set(&exp_tab), base_exp, "the lift changed WHICH pairs the exp table proves");
        assert_eq!(set(&act_tab), base_act, "the lift changed WHICH pairs the act table proves");
    }
    // §4.1 condition 2, structurally: the multiplicity planes are as long as
    // `Dom::Tab` but `prove_inner` writes only `0..U8_LEN` into a
    // zero-initialised commitment, so every padded multiplicity is zero.
    assert!(Dom::Tab.len() >= U8_LEN, "the table domain is never shorter than the byte class");
    assert_eq!(a_dom(A_MU8), Dom::Tab);
    assert_eq!(a_dom(A_MEXP), Dom::Tab);
    assert_eq!(a_dom(A_MACT), Dom::Tab);
}

/// **S4 at the toy: a NO-OP, which is what P-8's byte-identity gate needs.**
/// Every toy `H` domain already sits at or above `LOG_N`, so the lift moves
/// nothing, and `SC_TAB`'s and `SC_ZS`'s cubes stay at 8 rounds.
#[test]
fn the_lift_is_a_no_op_at_the_toy() {
    for dom in [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab] {
        assert_eq!(dom.log(), dom.natural_log(), "the lift moved {dom:?} at the toy");
    }
    assert_eq!(Dom::Tab.len(), U8_LEN, "the toy's table domain IS the byte class");
    assert_eq!(SLOTS[SC_TAB].0, 8);
    assert_eq!(SLOTS[SC_ZS].0, 8);
}

// ------------------------------------------------- S5: the shape-driven layout

use super::shape::{ReceiptBytes, Shape, Totals};

/// Every number the shape-driven layout must produce for one shape. The three
/// instances below are transcribed from the INDEPENDENT Python model's output
/// (`results/zk60_block125m_lane/model_{toy,rung,m125}.json`, produced by
/// `scripts/zk60_private_block_layout_model.py`). The two were written from
/// the same memo but not from each other, so an agreement is evidence and a
/// disagreement is a finding.
///
/// **STAGE 20, and its repair in STAGE 21 (review finding F-1).** Stage 20
/// left `main_rounds` and `receipt_total` at their PRE-repair values and
/// adjusted them here by a RUST-computed delta, because the Python model was
/// then outside the lane's write set and still declared the old bilinear
/// schedule. Both sides of the comparison were therefore this module's own
/// arithmetic, which is exactly what an independent model is for. Stage 21
/// repaired the model — it now DERIVES the group rounds and the group `eq`
/// degree from `kv_heads` itself (`group_sumcheck_bits`) — so every figure
/// below is once more the model's own output, transcribed, and no delta is
/// applied. [`s20_bilinear_delta`] survives only where a pin is stated as a
/// MEASURED pre-repair length plus a counted delta.
struct Expected {
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
    /// `sum_s (main + ext)(degree + 1)` — what the prover publishes
    published_round_values: usize,
    /// `sum_s (main + ext)` — what the verifier draws
    challenge_draws: usize,
    /// the two BILINEAR slots' mask lengths `L`, `(SC_SCORE, SC_PV)`: the two
    /// the S19-F1 repair moves and the only ones it moves
    bilinear_lengths: (usize, usize),
    u8_per_domain: [usize; 6],
    u8_lookups: usize,
    exp_pairs: usize,
    act_pairs: usize,
    receipt_total: usize,
}

const MODEL_TOY: Expected = Expected {
    a_planes: 81,
    h_planes: 51,
    a_data_rows: 213,
    h_data_rows: 280,
    a_rows: 455,
    h_rows: 384,
    a_sites: 120,
    h_sites: 51,
    a_groups: 35,
    h_groups: 9,
    largest_slot_length: 50,
    main_rounds: 159,
    extension_rounds: 25,
    published_round_values: 721,
    challenge_draws: 184,
    bilinear_lengths: (12, 16),
    u8_per_domain: [1_024, 19_456, 4_608, 6_656, 3_072, 26_624],
    u8_lookups: 61_440,
    exp_pairs: 2_048,
    act_pairs: 512,
    receipt_total: 2_816_472,
};

const MODEL_RUNG: Expected = Expected {
    a_planes: 83,
    h_planes: 52,
    a_data_rows: 377,
    h_data_rows: 470,
    a_rows: 623,
    h_rows: 576,
    a_sites: 122,
    h_sites: 52,
    a_groups: 36,
    h_groups: 9,
    largest_slot_length: 72,
    main_rounds: 217,
    extension_rounds: 25,
    published_round_values: 1_055,
    challenge_draws: 242,
    bilinear_lengths: (23, 26),
    u8_per_domain: [2_048, 155_648, 73_728, 53_248, 12_288, 122_880],
    u8_lookups: 419_840,
    exp_pairs: 8_192,
    act_pairs: 8_192,
    // the memo's §9a table says 4,173,032; the Python model's extra 176 B is
    // `SC_KVZC`'s support indicator, which §9a's own domain paragraph
    // requires because `Dom::Kv` pads at the rung (lane finding B-F3, open
    // for the security owner).
    //
    // **S11a: +45,056 B on top of the model's 4,173,544 (finding S11-F4).**
    // The model priced the endpoints at the TRUE `(24, 96)` plane — 14 rows
    // at inverse rate 4 — and `SeamSpec::new` refuses that plane outright
    // (both axes must be powers of two). What the frozen seam actually gives
    // is the PADDED `(32, 128)` plane at exactly its 4,096-word ceiling: 16
    // data rows, `16 + MASK_ROWS = 21` commitment rows, and the seam's frozen
    // `INV_RATE = 8`, which is hashed into every `SeamSpec::digest()` and so
    // not editable. The two endpoint openings therefore cost
    // `2 * [(1+1)(256+256)(16) + 256(8 + 21*8 + 32 + 11*32)] = 319,488 B`
    // against the model's 274,432 B. The PYTHON MODEL still prices the FROZEN
    // SEAM rung the memo's way and differs from the Rust by exactly this
    // term; the difference and its cause are recorded in the lane ledger, as
    // the ruling on S11-F4 asks. (`Shape::rung_g` has no such term at all —
    // see `MODEL_RUNG_G`.)
    receipt_total: 4_218_600,
};

/// **STAGE 21.** `Shape::rung_g` — the rung's geometry with the GENERALISED
/// endpoint of S11b, and the profile at which every shaped proof, run and
/// capture of this lane is actually taken. It had no independent model at
/// all until stage 21 added `RUNG_G` to
/// `scripts/zk60_private_block_layout_model.py`; these are that model's own
/// figures, transcribed.
///
/// **And this shape has NO Rust-side correction term.** The frozen seam's
/// endpoint forced +45,056 B at the rung and the padded `Dom::D` cube forced
/// +32,768 B at 125M; the generalised endpoint is priced from the block's own
/// PCS parameters, which the model already models, so the model's 4,234,984 B
/// and the Rust's agree TO THE BYTE with nothing in between.
const MODEL_RUNG_G: Expected = Expected {
    a_planes: 83,
    h_planes: 52,
    a_data_rows: 377,
    h_data_rows: 470,
    a_rows: 623,
    h_rows: 576,
    a_sites: 122,
    h_sites: 52,
    a_groups: 36,
    h_groups: 9,
    largest_slot_length: 72,
    main_rounds: 217,
    extension_rounds: 25,
    published_round_values: 1_055,
    challenge_draws: 242,
    bilinear_lengths: (23, 26),
    u8_per_domain: [2_048, 155_648, 73_728, 53_248, 12_288, 122_880],
    u8_lookups: 419_840,
    exp_pairs: 8_192,
    act_pairs: 8_192,
    receipt_total: 4_234_984,
};

/// **STAGE 22.** `Shape::rung_k4` — rung-G's geometry with the heads recut
/// as twelve query heads of eight over FOUR key-value heads, so `lkv = 2`.
/// These are `scripts/zk60_private_block_layout_model.py`'s own figures at
/// `SHAPES["rung_k4"]`, transcribed, and like rung-G this shape has **NO
/// Rust-side correction term**: its endpoint is the generalised one, priced
/// from the block's own PCS parameters, which the model already models.
///
/// The head axis is the only thing that moves against rung-G, and it moves
/// two things with it: `Dom::S = h_pad * t_pad * t_pad` doubles (sixteen
/// head slots against eight), which is where the extra `A` rows, the extra
/// `S`-domain lookups and most of the extra 508,144 receipt bytes come
/// from; and the two bilinear slots gain one main round each (`lkv` is 2,
/// not 1) while `SC_SCORE`'s inner axis shrinks from `log2(16)` to
/// `log2(8)`, which is why its schedule is rung-G's `(5, 2, 3)` exactly and
/// `SC_PV`'s is `(7, 2, 3)` against `(6, 2, 3)`.
const MODEL_RUNG_K4: Expected = Expected {
    a_planes: 83,
    h_planes: 52,
    a_data_rows: 481,
    h_data_rows: 614,
    a_rows: 727,
    h_rows: 720,
    a_sites: 122,
    h_sites: 52,
    a_groups: 36,
    h_groups: 9,
    largest_slot_length: 77,
    main_rounds: 220,
    extension_rounds: 25,
    published_round_values: 1_070,
    challenge_draws: 245,
    bilinear_lengths: (23, 29),
    u8_per_domain: [2_048, 155_648, 73_728, 53_248, 12_288, 245_760],
    u8_lookups: 542_720,
    exp_pairs: 16_384,
    act_pairs: 8_192,
    receipt_total: 4_743_128,
};

const MODEL_M125: Expected = Expected {
    a_planes: 83,
    h_planes: 50,
    a_data_rows: 5_435,
    h_data_rows: 7_018,
    a_rows: 5_681,
    h_rows: 7_120,
    a_sites: 122,
    h_sites: 50,
    a_groups: 36,
    h_groups: 9,
    largest_slot_length: 117,
    main_rounds: 336,
    extension_rounds: 25,
    published_round_values: 1_554,
    challenge_draws: 361,
    bilinear_lengths: (32, 41),
    u8_per_domain: [32_768, 17_825_792, 9_437_184, 6_815_744, 1_572_864, 62_914_560],
    u8_lookups: 98_598_912,
    exp_pairs: 4_194_304,
    act_pairs: 1_048_576,
    // **S11b: +32,768 B on top of the model's 40,750,584 (finding S11b-F1).**
    // The Python model priced 125M's endpoints at the memo's 29 commitment
    // rows, which come from the TRUE `512 x 768 = 393,216`-word plane. What
    // this module commits is the PADDED `Dom::D` cube, `t_pad * d_pad = 512 *
    // 1024 = 2^19` words — the slice `SC_IO_IN` / `SC_IO_OUT` already claim —
    // so at `endpoint_log_n = 14` the endpoint has 32 data rows and 37
    // commitment rows, and the two openings cost
    // `2 * [(1+1)(16384+256)(16) + 256(8 + 37*8 + 32 + 16*32)] = 1,499,136 B`
    // against the model's 1,466,368 B. The PYTHON MODEL IS UNCHANGED; the
    // difference and its cause are in the lane ledger. Padding is also what
    // removes the need for the memo's C6 `mu`-batched multi-block claim: the
    // padded plane IS a power of two.
    receipt_total: 40_783_352,
};

/// **STAGE 20's COUNTED DELTA (the repair of finding S19-F1).**
///
/// Every `Expected` above, and every frame length this module pins, was
/// COUNTED before the two bilinear attention slots gained the key-value group
/// as a sumcheck variable. The repair moves exactly two slots and moves them
/// by an amount that is a function of the SHAPE'S AXES and of nothing else,
/// so the new figures are DERIVED here rather than re-measured and pasted:
///
/// * `SC_SCORE` had `main = log2(head_dim)`, degree 2; it now has
///   `main = lkv + log2(head_dim)`, degree 3.
/// * `SC_PV` had `main = log2(t_pad)`, degree 2; it now has
///   `main = lkv + log2(t_pad)`, degree 3.
/// * both keep their two extension rounds, their two private terminals and
///   their two claim sites, so nothing else about the layout moves.
///
/// A slot contributes `1 + (main + ext)(degree + 1) + terminals` FIELD WORDS
/// to a frame (`wire::encoded_len`, `Shape::receipt_bytes`), 16 bytes each.
/// With `kv_heads = 1` — the frozen toy — `lkv = 0`, the degree does not
/// move and the delta is `(0, 0)`: the toy pays nothing.
///
/// Returns `(extra main rounds, extra frame bytes)`.
pub(super) fn s20_bilinear_delta(sh: &Shape) -> (usize, usize) {
    let lg = |v: usize| v.trailing_zeros() as usize;
    let lkv = lg(sh.kv_heads);
    if lkv == 0 {
        return (0, 0);
    }
    // (old main, new main) of the two bilinear slots, with ext = 2 throughout
    let moved = [(lg(sh.head_dim), lkv + lg(sh.head_dim)), (lg(sh.t_pad), lkv + lg(sh.t_pad))];
    let rounds: usize = moved.iter().map(|(old, new)| new - old).sum();
    // old degree 2 -> three words a round; new degree 3 -> four
    let words: usize = moved.iter().map(|(old, new)| (new + 2) * 4 - (old + 2) * 3).sum();
    (rounds, 16 * words)
}

/// the counted frame length of one block at a shape whose PRE-stage-20 length
/// was `before`
pub(super) fn s20_frame_bytes(sh: &Shape, before: usize) -> usize {
    before + s20_bilinear_delta(sh).1
}

fn check_against_model(sh: &Shape, want: &Expected) {
    let t: Totals = sh.totals();
    // **STAGE 21, review finding F-1.** No adjustment: `want` is the
    // independent Python model's own output at this shape, the repaired
    // bilinear schedule included, so every assertion below compares the Rust
    // with a count made outside it.
    let sl = sh.slots();
    let published_round_values: usize = sl.iter().map(|(m, e, d)| (m + e) * (d + 1)).sum();
    let challenge_draws: usize = sl.iter().map(|(m, e, _)| m + e).sum();
    let lengths = sh.slot_lengths();
    assert_eq!(t.a_planes, want.a_planes, "{}: A planes", sh.name);
    assert_eq!(t.h_planes, want.h_planes, "{}: H planes", sh.name);
    assert_eq!(t.a_data_rows, want.a_data_rows, "{}: A data rows", sh.name);
    assert_eq!(t.h_data_rows, want.h_data_rows, "{}: H data rows", sh.name);
    assert_eq!(t.a_rows, want.a_rows, "{}: A rows", sh.name);
    assert_eq!(t.h_rows, want.h_rows, "{}: H rows", sh.name);
    assert_eq!(t.m_rows, 50, "{}: M rows", sh.name);
    assert_eq!(t.a_sites, want.a_sites, "{}: A claim sites", sh.name);
    assert_eq!(t.h_sites, want.h_sites, "{}: H claim sites", sh.name);
    assert_eq!(t.a_groups, want.a_groups, "{}: A opening groups", sh.name);
    assert_eq!(t.h_groups, want.h_groups, "{}: H opening groups", sh.name);
    assert_eq!(t.functionals, 34, "{}: functionals", sh.name);
    assert_eq!(t.largest_slot_length, want.largest_slot_length, "{}: largest slot L", sh.name);
    assert!(t.largest_slot_length + 256 <= 512, "{}: the mask budget L + 256 <= 512 is broken", sh.name);
    assert_eq!(t.main_rounds, want.main_rounds, "{}: main rounds", sh.name);
    assert_eq!(t.extension_rounds, want.extension_rounds, "{}: extension rounds", sh.name);
    assert_eq!(published_round_values, want.published_round_values, "{}: published round values", sh.name);
    assert_eq!(challenge_draws, want.challenge_draws, "{}: sumcheck challenge draws per block", sh.name);
    assert_eq!((lengths[SC_SCORE], lengths[SC_PV]), want.bilinear_lengths, "{}: the two bilinear slots' mask lengths", sh.name);
    assert_eq!(t.u8_per_domain, want.u8_per_domain.to_vec(), "{}: U8 lookups per domain", sh.name);
    assert_eq!(t.u8_lookups, want.u8_lookups, "{}: U8 lookups", sh.name);
    assert_eq!(t.exp_pairs, want.exp_pairs, "{}: exp pairs", sh.name);
    assert_eq!(t.act_pairs, want.act_pairs, "{}: act pairs", sh.name);
    assert_eq!(t.receipt_bytes.total, want.receipt_total, "{}: receipt bytes", sh.name);
    // B-3 must be closed at EVERY shape, or that shape produces no receipt
    assert_eq!(t.logup_sum_claim_keys, 1, "{}: the LogUp sum claim raises more than one column-weight key", sh.name);
}

/// **S5, the toy instance.** The shape-driven layout reproduces every number
/// the module's own tests assert about the toy. `Layout::new` already panics
/// if it does not — this test says so where it can be read.
#[test]
fn the_shape_driven_layout_reproduces_the_toy_exactly() {
    let sh = Shape::toy();
    check_against_model(&sh, &MODEL_TOY);
    let lay = Layout::new();
    assert_eq!((lay.a_data_rows, lay.a_rows, lay.h_data_rows, lay.h_rows), (A_DATA_ROWS, A_ROWS, H_DATA_ROWS, H_ROWS));
    assert_eq!(sh.claim_sites(), (A_SITES, H_SITES));
    assert_eq!(sh.slots(), SLOTS);
    assert_eq!(sh.profile, std::str::from_utf8(PROFILE).unwrap(), "the toy shape's profile id is this module's");
    // the two statements of the row rule agree at the toy
    for dom in ALL_DOMS {
        assert_eq!(sh.rows_of(dom), rows_of(dom.log()), "{dom:?}: rows");
        assert_eq!(sh.log(dom), dom.log(), "{dom:?}: log");
        assert_eq!(sh.size(dom), dom.len(), "{dom:?}: size");
    }
    // and the lookup lists: the shape's per-position counts are the layout's
    for dom in LOOKUP_DOMS {
        assert_eq!(sh.lookups_per_position(dom), lookups(dom).len(), "{dom:?}: lookups per position");
        assert_eq!(sh.helpers(dom), helpers(dom).1, "{dom:?}: helper planes");
    }
    // B-F5: `Dom::L` is the ONE domain that already pads at the toy — nine of
    // its sixteen limb sub-planes are used. `SC_LZC` is homogeneous and takes
    // no indicator, so no toy byte moves for it.
    assert_eq!(sh.padded_domains(), vec![Dom::L], "the toy's padded domains");
}

/// **S5, the two new shapes.** Layouts only: nothing is proved at either.
///
/// **STAGE 21 (review finding F-1).** `Shape::rung_g` joined them — it is the
/// profile the lane actually proves at and it had no independent model — and
/// the stage-20 delta adjustment is gone: the Python model derives the
/// repaired bilinear schedule itself now, so these are three independent
/// counts against three Rust ones.
#[test]
fn the_shape_driven_layout_matches_the_python_model_at_the_rung_and_at_125m() {
    check_against_model(&Shape::rung(), &MODEL_RUNG);
    check_against_model(&Shape::rung_g(), &MODEL_RUNG_G);
    // **STAGE 22.** The four-key-value-head shape, against the same
    // independent model, with no delta and no correction term.
    check_against_model(&Shape::rung_k4(), &MODEL_RUNG_K4);
    check_against_model(&Shape::m125(), &MODEL_M125);
}

/// **STAGE 21, review finding F-1, stated as its own test.** The three
/// figures the S19-F1 repair moves are now pinned AS THE MODEL'S OWN OUTPUT
/// at all FIVE shapes, with no counted delta in between — which is the
/// property F-1 says was lost. A disagreement here is a finding about the
/// construction, not a stale literal.
#[test]
fn the_repaired_bilinear_schedule_agrees_with_the_independent_model_at_every_shape() {
    // (shape, model main rounds, model published round values, model draws,
    //  model (L_score, L_pv)) — `scripts/zk60_private_block_layout_model.py`
    let cases: [(Shape, usize, usize, usize, (usize, usize)); 5] = [
        (Shape::toy(), 159, 721, 184, (12, 16)),
        (Shape::rung(), 217, 1_055, 242, (23, 26)),
        (Shape::rung_g(), 217, 1_055, 242, (23, 26)),
        // **STAGE 22**: the first shape in this table with TWO group bits
        // that is small enough to prove and capture
        (Shape::rung_k4(), 220, 1_070, 245, (23, 29)),
        (Shape::m125(), 336, 1_554, 361, (32, 41)),
    ];
    for (sh, main, values, draws, bilinear) in cases {
        let sl = sh.slots();
        assert_eq!(sl.iter().map(|(m, _, _)| m).sum::<usize>(), main, "{}: main rounds", sh.name);
        assert_eq!(sl.iter().map(|(m, e, d)| (m + e) * (d + 1)).sum::<usize>(), values, "{}: published round values", sh.name);
        assert_eq!(sl.iter().map(|(m, e, _)| m + e).sum::<usize>(), draws, "{}: challenge draws", sh.name);
        let l = sh.slot_lengths();
        assert_eq!((l[SC_SCORE], l[SC_PV]), bilinear, "{}: bilinear mask lengths", sh.name);
        // and the toy pays nothing: `lkv == 0` leaves degree 2 and no eq
        let grouped = sh.kv_heads > 1;
        assert_eq!(sl[SC_SCORE].2, if grouped { 3 } else { 2 }, "{}: SC_SCORE degree", sh.name);
        assert_eq!(sl[SC_PV].2, if grouped { 3 } else { 2 }, "{}: SC_PV degree", sh.name);
    }
}

/// **S5, the derived calibration.** The two integer windows and the limb
/// counts they force come from the shape, not from a literal — which is what
/// step S8 will need. The toy's are the module's own constants.
#[test]
fn the_integer_windows_come_from_the_shape() {
    let toy = Shape::toy();
    assert_eq!((toy.norm_wrho, toy.wrho_s), (NORM_WRHO, WRHO_S), "the toy's windows are the module's constants");
    assert_eq!((toy.limbs_norm(), toy.limbs_sigma_s(), toy.limbs_p()), (4, 2, 2));
    assert!(!toy.norm_top_is_full_byte(), "the toy keeps its four `scaled` norm lookups");
    // memo §9a: the rung's honest window is 31 and its softmax needs a THIRD
    // limb, which the toy's 14-bit window does not
    let rung = Shape::rung();
    assert_eq!((rung.norm_wrho, rung.wrho_s), (31, 17));
    assert_eq!((rung.limbs_norm(), rung.limbs_sigma_s()), (4, 3));
    assert!(!rung.norm_top_is_full_byte());
    // memo §3.3: width 768 needs NORM_WRHO = 32, which fills its top limb and
    // so drops the four now-redundant `scaled` lookups (C-6)
    let m125 = Shape::m125();
    assert_eq!((m125.norm_wrho, m125.wrho_s), (32, 18));
    assert_eq!((m125.limbs_norm(), m125.limbs_sigma_s()), (4, 3));
    assert!(m125.norm_top_is_full_byte(), "at 32 bits the top norm limb is exactly full");
    // the Python model's `D_max` for the three shapes, digit for digit
    assert_eq!((toy.d_max, rung.d_max, m125.d_max), (131_068, 321_049, 908_065), "isqrt(1 + width * 32767^2)");
}

/// **S5, the construction refusals.** A shape the construction cannot express
/// is refused BY NAME at construction, not by an assertion deep inside a
/// numeric helper (trap T-2, which is a prover panic today).
#[test]
fn an_inexpressible_shape_is_refused_at_construction_by_name() {
    let mk = |t, d, f, h, dh, kv| Shape::new("probe", "probe/1", t, d, f, h, dh, kv, 8, 8, 9, 7, None, None, None, None);
    // the Q/D coincidence: the padded head slots must tile the padded width
    let err = mk(32, 16, 16, 2, 4, 1).expect_err("d_pad != h_pad * head_dim must be refused");
    assert_eq!(err, "private block shape: d_pad differs from h_pad * head_dim");
    // T-8: the RoPE partner bit is addressed as `log - log2(head_dim)`
    let err = mk(32, 48, 16, 2, 24, 1).expect_err("a non-power-of-two head dimension must be refused");
    assert_eq!(err, "private block shape: the head dimension is not an even power of two");
    // grouped-query attention needs a whole group
    let err = mk(32, 16, 16, 2, 8, 3).expect_err("kv heads that do not divide the query heads must be refused");
    assert_eq!(err, "private block shape: the query heads do not divide into the key-value heads");
    let err = mk(0, 16, 16, 2, 8, 1).expect_err("a zero axis must be refused");
    assert_eq!(err, "private block shape: an axis is zero");
    // **STAGE 21, finding F-2 of the stage-20 review.** A shape whose
    // `Dom::Q`, `Dom::Kv` or `Dom::S` is lifted to the row width by P-3 is
    // one the bilinear attention slots cannot serve — their coordinate lists
    // are written at the NATURAL log — and it is now refused BY NAME at
    // construction instead of by `run_slot`'s generic "slot s table shape"
    // from inside the argument. `T8/H4/dh2/KV4` at `log_cols = 8` is the
    // geometry the stage-20 reviewer actually met.
    let err = mk(8, 8, 8, 4, 2, 4).expect_err("a shape whose bilinear domains are P-3 lifted must be refused");
    assert_eq!(
        err,
        "private block shape: the bilinear attention slots cannot serve a shape whose Q domain is lifted by P-3 (natural log 6, lifted to the row width 8)"
    );
    // the same geometry with a head dimension of 8 lifts nothing and is
    // accepted — which is the reviewer's own workaround, now explained
    let ok = Shape::new("probe", "probe/1", 8, 32, 32, 4, 8, 4, 8, 8, 9, 7, None, None, None, None).expect("dh = 8 lifts no bilinear domain");
    for dom in [Dom::Q, Dom::Kv, Dom::S] {
        assert_eq!(ok.log(dom), ok.natural_log(dom), "{dom:?} must not be lifted at the accepted probe shape");
    }
    // and `Dom::Kv` exactly AT the row width is not a lift: the toy is that case
    assert_eq!(Shape::toy().natural_log(Dom::Kv), 8);
    assert_eq!(Shape::toy().log(Dom::Kv), 8);
    // and the three shapes the lane uses are all accepted
    for sh in [Shape::toy(), Shape::rung(), Shape::m125()] {
        assert_eq!(sh.d_pad, sh.h_pad * sh.head_dim, "{}", sh.name);
    }
}

/// **S5, the profile rule (D17).** Each shape carries its OWN profile id: a
/// new shape is a new profile BESIDE the toy, never an edit of it, because
/// the profile is transcript-bound.
#[test]
fn every_shape_has_its_own_profile_id() {
    let ids: Vec<&str> = [Shape::toy(), Shape::rung(), Shape::m125()].iter().map(|s| s.profile).collect();
    let distinct: std::collections::HashSet<&str> = ids.iter().copied().collect();
    assert_eq!(distinct.len(), ids.len(), "two shapes share a profile id: {ids:?}");
    assert_eq!(ids[0], std::str::from_utf8(PROFILE).unwrap(), "the toy's profile id must not move");
}

/// **S5, the receipt part by part** at 125M, against memo §7.1's table — the
/// figure the whole memory and cost model rests on.
#[test]
fn the_125m_receipt_is_reproduced_part_by_part() {
    let r: ReceiptBytes = Shape::m125().receipt_bytes();
    assert_eq!(r.a_opening, 21_626_880, "A opening");
    assert_eq!(r.h_opening, 17_385_472, "H opening");
    // S11b: 1,499,136 and not the memo's 1,466,368 — the endpoint is the
    // PADDED `2^19`-word `Dom::D` cube (37 commitment rows), not the true
    // 393,216-word plane (29). See `MODEL_M125`.
    assert_eq!(r.endpoint_openings, 1_499_136, "two endpoint openings");
    assert_eq!(r.mask_opening, 243_712, "M opening");
    // STAGE 20: the two bilinear slots' repair is the ONLY part of the frame
    // it touches, and it touches only this part. Counted, not re-measured.
    let (_, d_bytes) = s20_bilinear_delta(&Shape::m125());
    assert_eq!(r.slots, 27_456 + d_bytes, "23 slots (the pre-repair 27,456 plus the stage-20 bilinear delta {d_bytes})");
    assert_eq!(r.header_and_three_roots, 136, "header + three roots");
    assert_eq!(r.total, 40_782_792 + d_bytes, "one 125M block");
    // and the toy's, which the wire format actually produces
    assert_eq!(Shape::toy().receipt_bytes().total, 2_816_472);
}

// ====================================================================
// STEP S8 PREPARATION: the two integer windows, reproduced before the fix
// ====================================================================
//
// S8 widens the norm remainder window (2^29 -> 2^32, memo section 3.8 row 9)
// and the softmax remainder window (2^14 -> 2^18, row 10, +2 planes on
// `Dom::S`). S6 already made the WITNESS and the reference KERNEL take both
// windows from the shape, so the failures below are real and reproducible
// today; what is NOT done is the ARGUMENT side, which still carries the
// toy's coefficients as literals, and the plane table, which cannot hold a
// third `sigma_s` limb.
//
// Nothing here moves a toy byte: every test builds a shape BESIDE the toy.

/// the rung geometry with a chosen softmax calibration and norm window,
/// for exercising one window at a time
fn window_shape(name: &'static str, profile: &'static str, f_e: u32, wrho_s: Option<u32>, norm_wrho: Option<u32>) -> Shape {
    Shape::new(name, profile, 24, 96, 192, 6, 16, 2, 10, 4, f_e, 14, Some(8), Some(4), norm_wrho, wrho_s).expect("a window fixture shape is well formed")
}

// ====================================================================
// STEP S9 / ruling P-2: the padded, head-permuted public statement
// ====================================================================
//
// `AttentionPublic::new_shaped` and `FeedForwardPublic::new_shaped` take the
// ZERO-PADDED, HEAD-PERMUTED matrices and refuse a nonzero entry off the
// destination axis's support. These helpers are what the model-root owner
// would do to an approved true-sized matrix, written HERE (in test code) so
// that the checker in the library is not checking its own output. At the toy
// every padded extent equals its true extent and `head_slot` is the
// identity, so both helpers are the identity there.

/// the padded index of a TRUE `Dom::Q`-axis index `j = h * head_dim + i'`
pub(super) fn q_axis_index(s: &Shape, j: usize) -> usize {
    s.head_slot(j / s.head_dim) * s.head_dim + j % s.head_dim
}

/// Place a true `(outer, inner)` row-major matrix into the padded
/// `(po, pi)` one through the two index maps.
pub(super) fn pad_matrix(w: &[i8], to: usize, ti: usize, po: usize, pi: usize, omap: &dyn Fn(usize) -> usize, imap: &dyn Fn(usize) -> usize) -> Vec<i8> {
    assert_eq!(w.len(), to * ti, "a true-sized matrix");
    let mut out = vec![0i8; po * pi];
    for o in 0..to {
        for i in 0..ti {
            out[omap(o) * pi + imap(i)] = w[o * ti + i];
        }
    }
    out
}

/// `[Wq, Wk, Wv, Wo, gamma_a]`, padded and head-permuted from their true
/// sizes `(d, d)`, `(kvw, d)`, `(kvw, d)`, `(d, d)`, `(d)`.
pub(super) fn pad_attention_weights(s: &Shape, wq: &[i8], wk: &[i8], wv: &[i8], wo: &[i8], gamma_a: &[i8]) -> [Vec<i8>; 5] {
    let (d, dp, kvw) = (s.width, s.d_pad, s.kv_heads * s.head_dim);
    let id = |i: usize| i;
    let q = |j: usize| q_axis_index(s, j);
    [
        pad_matrix(wq, d, d, dp, dp, &q, &id),
        pad_matrix(wk, kvw, d, kvw, dp, &id, &id),
        pad_matrix(wv, kvw, d, kvw, dp, &id, &id),
        pad_matrix(wo, d, d, dp, dp, &id, &q),
        pad_matrix(gamma_a, 1, d, 1, dp, &id, &id),
    ]
}

/// `[gamma_m, Wg, Wu, Wd]`, padded from their true sizes `(d)`, `(d, f)`,
/// `(d, f)`, `(f, d)`. The feed-forward axis carries no head permutation.
pub(super) fn pad_ff_weights(s: &Shape, gamma_m: &[i8], wg_t: &[i8], wu_t: &[i8], wd_t: &[i8]) -> [Vec<i8>; 4] {
    let (d, f, dp, fp) = (s.width, s.hidden, s.d_pad, s.f_pad);
    let id = |i: usize| i;
    [
        pad_matrix(gamma_m, 1, d, 1, dp, &id, &id),
        pad_matrix(wg_t, d, f, dp, fp, &id, &id),
        pad_matrix(wu_t, d, f, dp, fp, &id, &id),
        pad_matrix(wd_t, f, d, fp, dp, &id, &id),
    ]
}

/// a deterministic tame case at a shape: diagonal weights, a modest gain and
/// a modest input, so that every class holds and the only thing that can
/// refuse is a WINDOW
pub(super) fn tame_case(s: &Shape) -> (AttentionPublic, FeedForwardPublic, Vec<i16>) {
    let (d, f, kvw, half) = (s.width, s.hidden, s.kv_heads * s.head_dim, s.head_dim / 2);
    let diag = |outer: usize, inner: usize| -> Vec<i8> { (0..outer * inner).map(|k| if k / inner == k % inner { 64i8 } else { 0 }).collect() };
    let gamma = vec![64i8; d];
    let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
    assert_eq!(cos.len(), s.tokens * half);
    let (exp, _) = crate::tables_attn::exp_member(0, s.head_dim, s.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member");
    let aw = pad_attention_weights(s, &diag(d, d), &diag(kvw, d), &diag(kvw, d), &diag(d, d), &gamma);
    let fw = pad_ff_weights(s, &gamma, &diag(d, f), &diag(d, f), &diag(f, d));
    let public = AttentionPublic::new_shaped(s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("statement");
    let ff = FeedForwardPublic::new_shaped(s, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("feed-forward statement");
    // The input magnitude is chosen, not incidental: the norm denominator is
    // `4096 * isqrt(1 + sum x^2)`, so only a LARGE input makes the remainder
    // window bite. At |x| about 24,000 over 96 columns, `D` is about 235,000
    // and `den - 1` about 9.6e8 — past the toy's 2^29 = 5.37e8 and inside
    // the rung's 2^31. A small input accepts at 29 and proves nothing.
    let input: Vec<i16> = (0..s.tokens * d)
        .map(|k| {
            let base: i64 = if k % 2 == 0 { 24_000 } else { -24_000 };
            (base + ((k * 37 + 11) % 401) as i64 - 200) as i16
        })
        .collect();
    (public, ff, input)
}

/// **WINDOW 1 (memo section 3.8 row 9), reproduced.** At width 96 the norm
/// denominator is `4096 * D` with `D` up to 321,049, so the remainder needs
/// **31** bits. The toy's `NORM_WRHO = 29` is not enough and the honest
/// witness refuses by name; the shape's own 31 accepts the SAME input.
///
/// This is the completeness failure the memo predicts, not an arithmetic
/// one: nothing wraps, the prover simply cannot prove its own honest value.
#[test]
fn the_norm_window_of_the_toy_refuses_an_honest_rung_witness() {
    let narrow = window_shape("rung geometry at the TOY norm window", "hashline-zk-mr1/private-block-rung-norm29/1", 9, None, Some(29));
    let honest = window_shape("rung geometry at its own norm window", "hashline-zk-mr1/private-block-rung-norm31/1", 9, None, None);
    assert_eq!(narrow.norm_wrho, 29);
    assert_eq!(honest.norm_wrho, 31, "the rung's own norm window is 31 = tn + 1 + bits(D_max)");
    // by counting, before any witness is built: 29 cannot hold den - 1
    let den_max = 4096 * honest.d_max - 1;
    assert!(den_max >= (1i128 << 29), "the toy's 29-bit norm window would in fact be enough at width 96");
    assert!(den_max < (1i128 << 31), "31 bits is not enough for the rung's norm remainder");
    // and in the builder
    let (public, ff, input) = tame_case(&narrow);
    // (the witness is never `Debug`: its planes are secret, so `expect_err`
    // is not available and the two outcomes are matched by hand)
    let refused = match super::witness::build_shaped(&narrow, &public, &ff, &input) {
        Err(m) => m,
        Ok(_) => panic!("the toy's norm window must refuse an honest rung witness"),
    };
    assert_eq!(refused, "fixed oracle range refusal: norm quotient/remainder", "the refusal must name the norm window");
    let (public, ff, input) = tame_case(&honest);
    super::witness::build_shaped(&honest, &public, &ff, &input).expect("the rung's own 31-bit norm window accepts the same honest input");
    // the four coefficients S8 has to rewrite, and what they become
    assert_eq!(1i64 << (32 - Shape::toy().norm_wrho), 8, "the toy's `scaled(.., 1 << (32 - wrho))` coefficient");
    assert_eq!(1i64 << (32 - honest.norm_wrho), 2, "the rung's coefficient");
    assert_eq!(Shape::m125().norm_wrho, 32, "125M sits exactly on the four-limb ceiling");
    assert!(Shape::m125().norm_top_is_full_byte(), "at 125M the scaled lookup is redundant and C-6 drops four of them");
    assert!(!honest.norm_top_is_full_byte() && !Shape::toy().norm_top_is_full_byte());
}

/// **WINDOW 2 (memo section 3.8 row 10), reproduced.** The rung's own
/// calibration is `F_E = 12`, at which `Sum <= 24 * 2^12 = 98,304` and the
/// softmax remainder needs **17** bits. At the toy's `WRHO_S = 14` the
/// honest witness refuses by name, while the reference kernel — which takes
/// the window from the shape too — accepts the same case at 17.
#[test]
fn the_softmax_window_of_the_toy_refuses_an_honest_rung_witness() {
    let narrow = window_shape("rung geometry, F_E 12 at the TOY softmax window", "hashline-zk-mr1/private-block-rung-fe12-w14/1", 12, Some(14), None);
    assert_eq!(narrow.limbs_sigma_s(), 2, "two limbs, so the pinned plane table still holds");
    // by counting: Sum can reach 98,304, which does not fit 2^14
    let sum_max = (narrow.tokens as i128) << narrow.f_e;
    assert_eq!(sum_max, 98_304);
    assert!(sum_max > (1i128 << 14), "the toy's 14-bit softmax window would in fact be enough at F_E = 12");
    assert!(sum_max < (1i128 << 18), "18 bits is not enough for the rung's softmax remainder");
    let (public, ff, input) = tame_case(&narrow);
    let refused = match super::witness::build_shaped(&narrow, &public, &ff, &input) {
        Err(m) => m,
        Ok(_) => panic!("the toy's softmax window must refuse an honest rung witness at F_E = 12"),
    };
    assert_eq!(refused, "fixed oracle range refusal: softmax quotient/remainder", "the refusal must name the softmax window");
    // the third limb the fix needs, and the `scaled` coefficient that goes
    // with it: 4 = 1 << (16 - 14) today, 64 = 1 << (24 - 18) at three limbs
    let wide = Shape::rung();
    assert_eq!((wide.f_e, wide.wrho_s, wide.limbs_sigma_s()), (12, 17, 3), "the rung's own softmax calibration");
    assert_eq!(1i64 << (8 * Shape::toy().limbs_sigma_s() as u32 - Shape::toy().wrho_s), 4, "the toy's `scaled(A_SG1, ..)` coefficient");
    assert_eq!(1i64 << (8 * Shape::m125().limbs_sigma_s() as u32 - Shape::m125().wrho_s), 64, "125M's, which is the memo's `scaled(l2, 64)`");
}

/// **THE PLANE-TABLE BOUNDARY, MOVED (step S8, finding S6-F2).** A third
/// `sigma_s` limb adds two planes to `Dom::S` and shifts every `A_*` id above
/// `A_SG1`. S6 could only REFUSE such a shape; S8 MAPS it, through
/// [`Ids`]. This test records exactly what the map does, and that the two
/// boundaries that remain still refuse by name.
#[test]
fn the_plane_id_map_expresses_a_third_sigma_s_limb() {
    let two_limb = window_shape("rung geometry at the toy softmax window", "hashline-zk-mr1/private-block-rung-t24-parity/1", 9, None, None);
    // EVERY named shape now has a map, and it agrees with the shape's own
    // plane list plane for plane (two independent statements of the list)
    for s in [Shape::toy(), two_limb.clone(), Shape::rung(), Shape::m125()] {
        let ids = Ids::new(&s).unwrap_or_else(|m| panic!("{}: {m}", s.name));
        let doms = s.a_plane_doms();
        assert_eq!(ids.n_a(), doms.len(), "{}: plane count", s.name);
        assert!((0..doms.len()).all(|p| ids.dom(p) == doms[p]), "{}: plane list", s.name);
        // every toy plane maps into the right domain, and the map is injective
        assert!((0..N_A).all(|p| ids.dom(ids.at(p)) == a_dom(p)), "{}: a toy plane maps onto another domain", s.name);
        let mut seen: Vec<usize> = (0..N_A).map(|p| ids.at(p)).collect();
        seen.sort_unstable();
        seen.dedup();
        assert_eq!(seen.len(), N_A, "{}: the plane map is not injective", s.name);
    }
    // at the two-limb shapes the map is the IDENTITY, which is why no toy
    // byte can move
    for s in [Shape::toy(), two_limb] {
        let ids = Ids::new(&s).expect("a two-limb shape has a map");
        assert_eq!(ids.n_a(), N_A, "{}: plane count", s.name);
        assert!((0..N_A).all(|p| ids.at(p) == p), "{}: the two-limb map is not the identity", s.name);
        assert_eq!((ids.sr(0), ids.sr(1), ids.sg(0), ids.sg(1)), (A_SR0, A_SR1, A_SG0, A_SG1), "{}", s.name);
    }
    // at three limbs: two extra `Dom::S` planes, `A_SG*` up by one, and
    // everything above `Dom::S` up by two
    for s in [Shape::rung(), Shape::m125()] {
        let ids = Ids::new(&s).expect("a three-limb shape has a map");
        assert_eq!(s.limbs_sigma_s(), 3, "{}: three sigma_s limbs", s.name);
        assert_eq!(ids.n_a(), N_A + 2, "{}: two extra Dom::S planes", s.name);
        assert_eq!((ids.sr(0), ids.sr(1), ids.sr(2)), (A_SR0, A_SR1, A_SR1 + 1), "{}: the rho_s limbs", s.name);
        assert_eq!((ids.sg(0), ids.sg(1), ids.sg(2)), (A_SG0 + 1, A_SG1 + 1, A_SG1 + 2), "{}: the sigma_s limbs", s.name);
        for p in [A_G8, A_RGL, A_A16, A_U16, A_H16, A_RH1, A_MU8, A_MEXP, A_MACT] {
            assert_eq!(ids.at(p), p + 2, "{}: plane {p} above Dom::S did not shift by two", s.name);
        }
        // and NOTHING below `Dom::S` moves — which is what keeps
        // `Witness::output`'s literal `A_X2` correct
        for p in [A_D, A_MX, A_LIMB, A_X, A_Y, A_NR0, A_MS0, A_X2, A_RDL, A_Q8, A_K8, A_S8, A_P, A_PL1, A_SR0] {
            assert_eq!(ids.at(p), p, "{}: plane {p} below the sigma_s limbs moved", s.name);
        }
        assert!(ids.is_multiplicity(ids.at(A_MU8)) && !ids.is_multiplicity(ids.at(A_RH1)), "{}: the histogram boundary moved with the planes", s.name);
    }
    // THE TWO BOUNDARIES THAT REMAIN, each refused by name.
    // (1) a softmax window narrower than the toy's has FEWER planes, which
    // the map cannot express (it maps a toy id onto a plane that is not there)
    let narrow = window_shape("a one-limb softmax window", "hashline-zk-mr1/private-block-ls1/1", 9, Some(8), None);
    assert_eq!(narrow.limbs_sigma_s(), 1);
    assert_eq!(
        Ids::new(&narrow).err(),
        Some("private block: this shape's A plane list is shorter than the pinned one".to_string()),
        "a shorter plane list must be refused by name"
    );
    // (2) a fifth norm limb would move `A_X2`, which `Witness::output` reads
    // as a literal (finding S8-F3)
    let five = window_shape("a five-limb norm window", "hashline-zk-mr1/private-block-ln5/1", 9, None, Some(33));
    assert_eq!(five.limbs_norm(), 5);
    let (public, ff, input) = tame_case(&five);
    let refused = match super::witness::build_shaped(&five, &public, &ff, &input) {
        Err(m) => m,
        Ok(_) => panic!("a shape with a fifth norm limb must be refused"),
    };
    assert_eq!(refused, "private block: this shape's norm remainder needs a different number of byte limbs");
}

/// **THE LOOKUP LIST IS THE SHAPE'S** (step S8 items 2 and 3). `lookups_at`
/// BUILDS the list; `Shape::lookups_per_position` COUNTS it from the memo's
/// §4 without building it. The two were written from the same memo and not
/// from each other, so their agreement at every named shape is the gate on
/// the third limb's `scaled` lookup and on C-6's four dropped ones.
#[test]
fn the_shape_driven_lookup_list_matches_the_counted_one() {
    for s in [Shape::toy(), Shape::rung(), Shape::m125()] {
        let ids = Ids::new(&s).expect("a named shape has a map");
        for dom in LOOKUP_DOMS {
            let built = lookups_at(&s, &ids, dom);
            assert_eq!(built.len(), s.lookups_per_position(dom), "{}: {dom:?} lookup count", s.name);
            // every term names a plane that exists and lies on this domain
            for lk in &built {
                for (p, _) in &lk.terms {
                    assert!(*p < ids.n_a(), "{}: {dom:?} lookup names plane {p}", s.name);
                    assert_eq!(ids.dom(*p), dom, "{}: {dom:?} lookup reads a plane of another domain", s.name);
                }
            }
        }
        // the top-limb `scaled` coefficients, the three numbers S8 moved
        let coef = |v: &[Lk], p: usize| v.iter().find(|l| l.terms.len() == 1 && l.terms[0].0 == p && l.cst == 0 && l.terms[0].1 != 1).map(|l| l.terms[0].1);
        let d = lookups_at(&s, &ids, Dom::D);
        let sdom = lookups_at(&s, &ids, Dom::S);
        let want_norm = if s.norm_top_is_full_byte() { None } else { Some(1i64 << (8 * s.limbs_norm() as u32 - s.norm_wrho)) };
        assert_eq!(coef(&d, ids.nr(ids.ln - 1)), want_norm, "{}: norm rho top-limb coefficient", s.name);
        assert_eq!(coef(&d, ids.ms(ids.ln - 1)), want_norm, "{}: norm_m sigma top-limb coefficient", s.name);
        assert_eq!(coef(&sdom, ids.sg(ids.ls - 1)), Some(1i64 << (8 * s.limbs_sigma_s() as u32 - s.wrho_s)), "{}: sigma_s top-limb coefficient", s.name);
        assert_eq!(coef(&sdom, ids.pl(ids.lp - 1)), Some(64), "{}: the softmax quotient's top-limb coefficient is fixed by F_P", s.name);
    }
    // the exact numbers the memo names
    let (toy, rung, m125) = (Shape::toy(), Shape::rung(), Shape::m125());
    let (it, ir, im) = (Ids::new(&toy).unwrap(), Ids::new(&rung).unwrap(), Ids::new(&m125).unwrap());
    let coef_of = |s: &Shape, ids: &Ids, dom: Dom, p: usize| {
        lookups_at(s, ids, dom).into_iter().find(|l| l.terms.len() == 1 && l.terms[0].0 == p && l.cst == 0 && l.terms[0].1 != 1).map(|l| l.terms[0].1)
    };
    assert_eq!(coef_of(&toy, &it, Dom::D, it.nr(3)), Some(8), "the toy's `scaled(l3, 8)`");
    assert_eq!(coef_of(&rung, &ir, Dom::D, ir.nr(3)), Some(2), "the rung's `scaled(l3, 2)`");
    assert_eq!(coef_of(&m125, &im, Dom::D, im.nr(3)), None, "C-6 drops the four norm `scaled` lookups at 125M");
    assert_eq!(coef_of(&toy, &it, Dom::S, it.sg(1)), Some(4), "the toy's `scaled(l1, 4)`");
    assert_eq!(coef_of(&m125, &im, Dom::S, im.sg(2)), Some(64), "the memo's `scaled(l2, 64)` at 125M");
    assert_eq!(coef_of(&rung, &ir, Dom::S, ir.sg(2)), Some(128), "the rung's 17-bit window in three limbs");
    // C-6 moves the `H` row total, and only at 125M
    assert_eq!((toy.lookups_per_position(Dom::D), rung.lookups_per_position(Dom::D), m125.lookups_per_position(Dom::D)), (38, 38, 34));
    // the third limb adds two byte lookups and one `scaled`, and moves no
    // other domain
    assert_eq!((toy.lookups_per_position(Dom::S), rung.lookups_per_position(Dom::S), m125.lookups_per_position(Dom::S)), (13, 15, 15));
    for dom in [Dom::L, Dom::F, Dom::Q, Dom::Kv] {
        assert_eq!(toy.lookups_per_position(dom), m125.lookups_per_position(dom), "{dom:?} moved with the windows and should not have");
    }
}

/// **WHAT S8 DELIVERS.** At `Shape::rung()` — the rung with its own
/// `F_E = 12`, its 17-bit softmax window, its 31-bit norm window and its
/// three `sigma_s` limbs — an honest witness exists. Before S8 this failed
/// at the door with *"this shape's A plane list differs from the pinned
/// one"* (`s8-ignored-test.log:82`).
#[test]
fn the_rung_at_its_own_calibration_has_an_honest_witness() {
    let s = Shape::rung();
    assert_eq!((s.f_e, s.wrho_s, s.limbs_sigma_s(), s.norm_wrho, s.limbs_norm()), (12, 17, 3, 31, 4), "the rung's own calibration");
    let (public, ff, input) = tame_case(&s);
    let w = match super::witness::build_shaped(&s, &public, &ff, &input) {
        Ok(w) => w,
        Err(m) => panic!("S8: the rung's own calibration must have an honest witness, got `{m}`"),
    };
    assert_eq!(w.planes.len(), s.a_plane_doms().len());
    let ids = Ids::new(&s).expect("the rung has a map");
    // the third limb is REAL: some position's `sigma_s` exceeds 2^16, so its
    // top limb is nonzero — at two limbs that value could not have been
    // written at all, which is the completeness failure S8 removes
    let sup = super::witness::Geom::new(&s).support(Dom::S);
    let top = sup.iter().filter(|i| w.planes[ids.sg(2)][**i] != 0).count();
    assert!(top > 0, "no sigma_s needs its third byte limb, so the rung does not exercise the wider window");
    // and every limb really is a byte, at all three limbs
    for k in 0..3 {
        for p in [ids.sr(k), ids.sg(k)] {
            assert!(w.planes[p].iter().all(|v| (0..256).contains(v)), "plane {p} is not a byte plane");
        }
    }
    // the recomposed remainder pair closes `sigma_s = Sum - 1 - rho_s` on the
    // causal support, over the integers, at the rung's window
    let val = |p: usize, i: usize| w.planes[p][i];
    for h in 0..s.q_heads {
        // S9: the logical head sits at its padded head SLOT (correction C-1)
        let hs = s.head_slot(h);
        for t in 0..s.tokens {
            let sum = w.planes[ids.at(A_SUM)][hs * s.t_pad + t];
            for j in 0..=t {
                let i = (hs * s.t_pad + t) * s.t_pad + j;
                let rho: i64 = (0..3).map(|k| val(ids.sr(k), i) << (8 * k)).sum();
                let sig: i64 = (0..3).map(|k| val(ids.sg(k), i) << (8 * k)).sum();
                assert_eq!(sig + rho + 1, sum, "the rung's softmax remainder pair does not close at ({h}, {t}, {j})");
                assert!(sig < 1i64 << s.wrho_s && rho < 1i64 << s.wrho_s, "a rung remainder leaves the 17-bit window");
            }
        }
    }
}

// ====================================================================
// STEP S9, finding S9-F6: the H plane ids as a function of the shape
// ====================================================================

/// **The H-side analogue of S8's `Ids`.** It must be the IDENTITY at the toy
/// — the `H_*` literals are what `argument.rs` and `protocol.rs` still read,
/// and the toy's transcript rests on them — and it must reproduce each other
/// shape's own list, which moves in BOTH directions: the `Dom::S` block gains
/// one helper at the rung and at 125M (the third `sigma_s` limb), and the
/// `Dom::D` block LOSES two at 125M (C-6 drops four `Dom::D` lookups when the
/// norm window fills its top byte limb exactly).
///
/// The shrinking block is why there is no toy-id map on this side: at 125M
/// `H_D_LAST` names a plane that does not exist. The accessors are by ROLE.
#[test]
fn the_h_plane_ids_are_the_toys_at_the_toy_and_each_shapes_elsewhere() {
    let t = Shape::toy();
    let h = HIds::new(&t).expect("the toy has an H plane map");
    assert_eq!(h.n_h(), N_H, "the toy's H plane count");
    assert_eq!(h.first_helper(Dom::L), H_L);
    assert_eq!(h.first_helper(Dom::D), H_D0);
    assert_eq!(h.helper(Dom::D, 18), H_D_LAST);
    assert_eq!(h.first_helper(Dom::Q), H_Q0);
    assert_eq!(h.first_helper(Dom::Kv), H_KV0);
    assert_eq!(h.first_helper(Dom::S), H_S0);
    assert_eq!(h.first_helper(Dom::F), H_F0);
    assert_eq!(h.sexp(), H_SEXP);
    assert_eq!(h.fact(), H_FACT);
    assert_eq!(h.table_helpers(), [H_GU8, H_GEXP, H_GACT]);
    assert_eq!(h.u(), H_U);
    for p in 0..N_H {
        assert_eq!(h.dom(p), h_dom(p), "H plane {p}'s domain");
        assert_eq!(h.is_table(p), h_is_table(p), "H plane {p}'s table flag");
    }
    // ... and it agrees with the literal accessor block by block
    for dom in LOOKUP_DOMS {
        assert_eq!((h.first_helper(dom), t.helpers(dom)), helpers(dom), "{dom:?}'s helper block at the toy");
    }

    // THE RUNG: one more `Dom::S` helper, so `H_SEXP` and everything above
    // move up by one
    let r = Shape::rung();
    let hr = HIds::new(&r).expect("the rung has an H plane map");
    assert_eq!(hr.n_h(), 52, "the rung's H plane count (section 9a)");
    assert_eq!((hr.first_helper(Dom::S), r.helpers(Dom::S)), (H_S0, 8));
    assert_eq!((hr.sexp(), hr.fact(), hr.u()), (H_SEXP + 1, H_FACT + 1, H_U + 1));
    assert_eq!(hr.first_helper(Dom::D), H_D0, "nothing below Dom::S moves at the rung");

    // 125M: C-6 takes the `Dom::D` block from 19 helpers to 17, so everything
    // above it moves DOWN by two, and the third `sigma_s` limb puts one back
    let m = Shape::m125();
    let hm = HIds::new(&m).expect("125M has an H plane map");
    assert_eq!(hm.n_h(), 50, "125M's H plane count (finding B-F2)");
    assert_eq!((hm.first_helper(Dom::D), m.helpers(Dom::D)), (H_D0, 17));
    assert_eq!(hm.first_helper(Dom::Q), H_Q0 - 2);
    assert_eq!((hm.first_helper(Dom::S), m.helpers(Dom::S)), (H_S0 - 2, 8));
    assert_eq!(hm.u(), H_U - 1);
    // the table helpers are always the last four planes, in that order
    for (s, hi) in [(&t, &h), (&r, &hr), (&m, &hm)] {
        assert_eq!(hi.table_helpers()[0], hi.n_h() - 4, "{}: the table helpers are the last four planes", s.name);
        assert_eq!(hi.u(), hi.n_h() - 1, "{}: the zero-sum pair is the last plane", s.name);
        assert!(hi.is_table(hi.table_helpers()[2]) && !hi.is_table(hi.u()), "{}: only the three table helpers are table helpers", s.name);
    }
}

// ====================================================================
// STEP B of the shaped argument: `Layout::for_shape`
// ====================================================================

/// **The row geometry at any shape, with the TOY as one instance.**
///
/// `Layout::new()` is now `for_shape(&Shape::toy())` plus the frozen
/// assertions, so the whole toy transcript rests on this constructor. Two
/// things are therefore pinned here and nowhere else:
///
/// * the toy's `describe()` is byte-identical, LINE BY LINE, to the text the
///   frozen digest was taken over (`the_toy_schedule_digest_is_frozen`
///   already pins the digest; this pins which line would have moved);
/// * every other shape gets its OWN schedule — its own first line carrying
///   its own profile id, its own row totals — so no two profiles can share a
///   transcript-bound schedule digest.
///
/// It is a LAYOUT test. Nothing here proves anything at the rung or at 125M.
#[test]
fn the_layout_is_built_from_a_shape_and_the_toy_is_one_instance() {
    let toy = Shape::toy();
    let lay = Layout::new();
    let direct = Layout::for_shape(&toy).expect("the toy shape has a layout");
    assert_eq!(direct.describe(), lay.describe(), "`for_shape(toy)` and `new()` describe different schedules");
    assert_eq!(direct.schedule_digest(), TOY_SCHEDULE_DIGEST, "`for_shape(toy)` is not the frozen toy schedule");

    // the toy's six header lines, verbatim. These are the bytes the frozen
    // digest is taken over; a shape-driven rewrite that changed one space
    // would move every toy receipt.
    let d = lay.describe();
    assert_eq!(d[0], "private-block-t32/1: T32 d16 H2 KV1 dh8 F16; n=256 inv_rate=8 Q=256; P1 (weights public, no W commitment); whole block (attention, norm_m, feed-forward, residual 2)");
    assert_eq!(d[1], "A rows=455 data=213 site-pairs=120 prox-pair=(453,454)");
    assert_eq!(d[2], "H rows=384 data=280 site-pairs=51 zero-sum-pair=[278, 279] prox-pair=(382,383)");
    assert_eq!(d[3], "M rows=50 functionals=34 A-groups=35 H-groups=9 collapse=0");
    assert!(d[4].starts_with("calibration: norm tn=11 cn=1024 ceps=1 wrho=29;"), "{}", d[4]);
    assert!(d[4].contains(" fE=9 fP=9 fRo=7 wrhoS=14 mask=-127;"), "{}", d[4]);
    assert!(d[5].starts_with("feed-forward: F=16 shifts gate=7"), "{}", d[5]);
    assert_eq!(d.len(), 6 + N_SLOTS + HOSTS.len(), "the schedule has six header lines, one per slot and one per host");

    // the toy's own accessors, which every existing caller reads
    assert_eq!(lay.n(), N);
    assert_eq!(lay.slots(), &SLOTS);
    assert_eq!(lay.a_sites(), &A_SITES[..]);
    assert_eq!(lay.h_sites(), &H_SITES[..]);
    assert_eq!(lay.shape(), &toy);
    assert_eq!(lay.ids().n_a(), N_A);
    assert_eq!(lay.hids().n_h(), N_H);
    for dom in LOOKUP_DOMS {
        assert_eq!(lay.helpers(dom), helpers(dom), "{dom:?}: the shaped helper block is not the toy's");
        assert_eq!(lay.lookups(dom).len(), lookups(dom).len(), "{dom:?}: the shaped lookup list is not the toy's");
    }
    for dom in [Dom::T, Dom::Ht, Dom::Tab] {
        assert_eq!(lay.helpers(dom), (0, 0), "{dom:?} owns no LogUp helpers at any shape");
    }

    // ---- the other two shapes: a layout each, and it matches the counted
    // model of `Shape::totals` (itself checked against the Python model)
    for sh in [Shape::rung(), Shape::m125()] {
        let l = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("{}: {e}", sh.name));
        let t = sh.totals();
        assert_eq!((l.a_data_rows, l.h_data_rows), (t.a_data_rows, t.h_data_rows), "{}: data rows", sh.name);
        assert_eq!((l.a_rows, l.h_rows), (t.a_rows, t.h_rows), "{}: total rows", sh.name);
        assert_eq!((l.a_off.len(), l.h_off.len()), (t.a_planes, t.h_planes), "{}: plane counts", sh.name);
        assert_eq!(l.n(), 1usize << sh.log_cols, "{}: row width", sh.name);
        assert_eq!(l.a_mask_base, t.a_data_rows, "{}: the site pairs start after the data rows", sh.name);
        assert_eq!(l.a_prox, t.a_data_rows + 2 * t.a_sites, "{}: the proximity pair is last", sh.name);
        assert_eq!(l.h_prox, t.h_data_rows + 2 * t.h_sites, "{}: the H proximity pair is last", sh.name);
        // the last declared site of the last slot resolves; one past it does not
        let last = (0..N_SLOTS).rev().find(|s| l.a_sites()[*s] > 0).expect("some slot raises an A claim");
        assert!(l.a_site(last, l.a_sites()[last] - 1).is_ok(), "{}: the last A site", sh.name);
        assert!(l.a_site(last, l.a_sites()[last]).is_err(), "{}: an undeclared A site is refused", sh.name);
        // its schedule is its own, and carries its own profile id
        assert!(l.describe()[0].starts_with(sh.profile), "{}: the schedule does not name the profile: {}", sh.name, l.describe()[0]);
        assert_ne!(l.schedule_digest(), TOY_SCHEDULE_DIGEST, "{}: a new profile shares the toy's schedule digest", sh.name);
        assert_eq!(l.helpers(Dom::S), (l.hids().first_helper(Dom::S), sh.helpers(Dom::S)), "{}: the Dom::S helper block", sh.name);
        assert_eq!(l.lookups(Dom::S).len(), sh.lookups_per_position(Dom::S), "{}: the Dom::S lookup list", sh.name);
        assert_eq!(l.limb_off(1) - l.limb_off(0), sh.t_pad, "{}: the limb sub-slices are t_pad apart", sh.name);
    }
    // and the two are distinct from each other, not only from the toy
    assert_ne!(
        Layout::for_shape(&Shape::rung()).unwrap().schedule_digest(),
        Layout::for_shape(&Shape::m125()).unwrap().schedule_digest(),
        "the rung and 125M share a schedule digest"
    );
}

// ====================================================================
// STEP C of the shaped argument: `define` over a `Shape`
// ====================================================================

/// **Every slot definition, at the toy AND at the rung.**
///
/// `argument::define` used to carry the toy's geometry as literals; it now
/// reads `ctx.lay`'s shape. This walks all twenty-three slots at both shapes
/// and checks what the definition alone can be held to:
///
/// * it is built at all — `B::finish` refuses unless the slot uses exactly
///   the A and H claim sites the shape's schedule declares;
/// * every PUBLIC table is as long as the slot's cube (this is what caught
///   the dense RoPE tables and the dense causal mask: at the rung they are
///   2,304 and 4,608 entries against cubes of 4,096 and 8,192);
/// * every PRIVATE table's coordinate list is as long as its own domain's
///   log, every free coordinate is inside the slot's cube, and its masking
///   extension round is one the schedule declares;
/// * the private terminal count is the shape's, slot by slot.
///
/// And it pins **trap T-3** where it can be seen: at a shape with grouped
/// query heads, the key-value factor of `SC_SCORE` and of `SC_PV` must be
/// read at the key-value group of the QUERY head the challenge picked.
/// **STAGE 20 restates it for the repaired construction** (finding S19-F1):
/// the group bits are the slot's LEADING SUMCHECK VARIABLES now, not fixed
/// coordinates, so what is pinned is that both private factors read the group
/// at the SAME variables `0 .. lkv` and that the slot's single public `eq`
/// factor carries the head challenge's own group bits — the claim point
/// `p_s` / `p_o` is where those can be read. A factor with group variables of
/// its own, or an `eq` at a point of its own, would prove a different
/// statement exactly as a free fixed coordinate would have. At `kv_heads = 1`
/// (the frozen toy) the test asserts the OPPOSITE: no variable and no public
/// factor at all.
///
/// It is a DEFINITION test: no proof is produced at the rung. Since S9 part 4
/// it also counts the pad rule's public tables slot by slot — the toy must
/// declare none at all, and each of the rung's extra public tables must be an
/// indicator `pad::indicator_slots` names.
#[test]
fn the_slot_definitions_are_built_from_the_shape() {
    use super::argument::{causal_mask, causal_mask_at, define, rope_tables, rope_tables_at, Coord, Ctx, Points, Priv, Tab};
    // the two shape-driven public tables, against the toy's own literals
    let toy = Shape::toy();
    assert_eq!(causal_mask_at(&toy), causal_mask(), "the shaped causal mask is not the toy's table");
    let (public_toy, _, _) = tame_case(&toy);
    for (dom, heads) in [(Dom::Q, toy.q_heads), (Dom::Kv, toy.kv_heads)] {
        assert_eq!(rope_tables_at(&toy, &public_toy, dom), rope_tables(&toy, &public_toy, heads), "the shaped RoPE tables are not the toy's on {dom:?}");
    }
    // the public-table count per slot, toy first, so the rung's EXTRA public
    // tables can be counted against `pad::indicator_slots` (S9 part 4)
    let mut pub_toy: Option<[usize; N_SLOTS]> = None;
    for sh in [Shape::toy(), Shape::rung()] {
        let mut pubs = [0usize; N_SLOTS];
        let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("{}: {e}", sh.name));
        let (public, ff, _input) = tame_case(&sh);
        let ctx = Ctx {
            lay: &lay,
            public: &public,
            ff: &ff,
            alpha: Fp2::from_u64(7).add(Fp2::U),
            beta: Fp2::from_u64(11),
            g_u8: Fp2::from_u64(13),
            g_exp: Fp2::from_u64(17),
            g_act: Fp2::from_u64(19),
        };
        let mut tr = crate::transcript::Transcript::new(sh.profile.as_bytes());
        let mut pts = Points::default();
        let (slots, terms) = (sh.slots(), sh.slot_terms());
        let (lt, lkv) = (sh.t_pad.trailing_zeros() as usize, sh.kv_heads.trailing_zeros() as usize);
        let (mut kv_score, mut kv_pv) = (None, None);
        for s in 0..N_SLOTS {
            let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
            let (main, ext, _) = slots[s];
            let mut n_priv = 0usize;
            // **STAGE 20, the repaired T-3 statement.** The group bits are no
            // longer a FIXED coordinate of either factor: they are the slot's
            // leading sumcheck variables. What has to hold is that BOTH
            // private factors read them at the SAME variables, in the same
            // order — a factor reading the group at variables of its own would
            // prove a different statement exactly as a free fixed coordinate
            // would have.
            let group_at = |p: &Priv, first: usize| -> Vec<usize> {
                (0..lkv)
                    .map(|k| match &p.coords[first + k] {
                        Coord::Rho(v) => *v,
                        c => panic!("{}: slot {s}: group coordinate {k} is {c:?}, not a sumcheck variable", sh.name),
                    })
                    .collect()
            };
            for (i, t) in def.tabs.iter().enumerate() {
                match t {
                    Tab::Pub(v) => assert_eq!(v.len(), 1usize << main, "{}: slot {s} table {i}: a public table is not the slot's cube", sh.name),
                    Tab::Eq { point, start } => assert!(start + point.len() <= main, "{}: slot {s} table {i}: the eq point overruns the cube", sh.name),
                    Tab::Priv(p) => {
                        n_priv += 1;
                        assert_eq!(p.coords.len(), p.log, "{}: slot {s} table {i}: coordinate list", sh.name);
                        assert!(p.ext_round < ext, "{}: slot {s} table {i}: undeclared extension round", sh.name);
                        for c in &p.coords {
                            if let Coord::Rho(kk) | Coord::Flip(kk) = c {
                                assert!(*kk < main, "{}: slot {s} table {i}: free coordinate {kk} outside the cube", sh.name);
                            }
                        }
                        // T-3 as repaired: the shared group variables.
                        // `A_QR8` is `(t, head slot, c)` and `A_KR8` is
                        // `(j, group, c)`, so the group sits at offset `lt` in
                        // both; `A_P` is `(head slot, t, s)` and `A_V8` is
                        // `(s, group, i)`, so at 0 and at `lt`.
                        if lkv > 0 && s == SC_SCORE {
                            let v = group_at(p, lt);
                            match &kv_score {
                                None => kv_score = Some(v),
                                Some(q) => assert_eq!(*q, v, "{}: SC_SCORE reads the key side at group variables of its own", sh.name),
                            }
                        }
                        if lkv > 0 && s == SC_PV {
                            let v = if n_priv == 1 { group_at(p, 0) } else { group_at(p, lt) };
                            match &kv_pv {
                                None => kv_pv = Some(v),
                                Some(q) => assert_eq!(*q, v, "{}: SC_PV reads the value side at group variables of its own", sh.name),
                            }
                        }
                    }
                }
            }
            assert_eq!(n_priv, terms[s], "{}: slot {s}: private terminals", sh.name);
            pubs[s] = def.tabs.iter().filter(|t| matches!(t, Tab::Pub(_))).count();
            // and the PUBLIC factor over those variables is the head
            // challenge's OWN group bits, which is what makes the sum a sum
            // over the query head's group and not over a fresh point: `p_s` is
            // `(r_h, r_t, r_j)` and `p_o` is `(r_t, r_h, r_i)`.
            if lkv > 0 && (s == SC_SCORE || s == SC_PV) {
                let eqs: Vec<(&Vec<Fp2>, usize)> = def.tabs.iter().filter_map(|t| if let Tab::Eq { point, start } = t { Some((point, *start)) } else { None }).collect();
                assert_eq!(eqs.len(), 1, "{}: slot {s} declares {} eq tables, not the one group factor", sh.name, eqs.len());
                let (point, start) = eqs[0];
                assert_eq!((point.len(), start), (lkv, 0), "{}: slot {s}: the group eq is not over the leading {lkv} variables", sh.name);
                let want = if s == SC_SCORE { &pts.p_s()[..lkv] } else { &pts.p_o()[lt..lt + lkv] };
                assert_eq!(point.as_slice(), want, "{}: slot {s}: the group eq carries a point of its own, not the head challenge's group bits", sh.name);
            }
            // the toy is EXEMPT and must stay byte-identical: no variable, no
            // public factor, the same two tables it always had
            if lkv == 0 && (s == SC_SCORE || s == SC_PV) {
                assert_eq!(def.tabs.len(), 2, "{}: slot {s} gained a table at kv_heads = 1", sh.name);
                assert!(def.tabs.iter().all(|t| matches!(t, Tab::Priv(_))), "{}: slot {s} gained a public factor at kv_heads = 1", sh.name);
            }
        }
        assert_eq!(kv_score.is_some(), lkv > 0, "{}: the grouped-head check ran iff the shape groups", sh.name);
        assert_eq!(kv_pv.is_some(), lkv > 0, "{}: the grouped-head check ran iff the shape groups", sh.name);
        if lkv > 0 {
            assert_eq!(kv_score.as_deref(), Some(&(0..lkv).collect::<Vec<usize>>()[..]), "{}: SC_SCORE's group variables are not the slot's leading ones", sh.name);
            assert_eq!(kv_pv.as_deref(), Some(&(0..lkv).collect::<Vec<usize>>()[..]), "{}: SC_PV's group variables are not the slot's leading ones", sh.name);
        }
        match pub_toy {
            None => {
                // the TOY carries no pad machinery at all (finding S9-F1)
                assert_eq!(super::pad::indicator_tables_per_slot(&sh), [0usize; N_SLOTS], "the frozen toy profile declares an indicator table");
                pub_toy = Some(pubs);
            }
            Some(toy_pubs) => {
                // and at the rung every extra public table in a slot is an
                // indicator, one per entry of `pad::indicator_slots`
                let want = super::pad::indicator_tables_per_slot(&sh);
                assert_eq!(want.iter().sum::<usize>(), 12, "the rung materialises twelve indicator tables");
                for s in 0..N_SLOTS {
                    assert_eq!(pubs[s] - toy_pubs[s], want[s], "{}: slot {s} builds {} public tables against the toy's {}, not {} more", sh.name, pubs[s], toy_pubs[s], want[s]);
                }
            }
        }
    }
}

// ---------------------------------------------------- step C part 2: the shaped protocol

/// **STEP C part 2, the freeze half.** `protocol::transcript` no longer
/// absorbs a literal parameter word: it FORMATS one from the layout's shape.
/// The toy's line is transcript-bound, so a single changed character would
/// move every toy byte. This pins it verbatim, exactly as the schedule digest
/// is pinned, and pins the toy profile string the transcript is opened with.
#[test]
fn the_toy_parameter_line_is_the_frozen_literal() {
    assert_eq!(
        super::protocol::parameter_line(&Shape::toy()),
        "T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript"
    );
    assert_eq!(Shape::toy().profile.as_bytes(), PROFILE, "the toy shape's profile is the module's PROFILE constant");
    // every other shape gets its own line AND its own profile id (D17)
    for sh in [Shape::rung(), Shape::m125()] {
        assert_ne!(super::protocol::parameter_line(&sh), super::protocol::parameter_line(&Shape::toy()), "{}: parameter line", sh.name);
        assert_ne!(sh.profile, Shape::toy().profile, "{}: profile id", sh.name);
    }
}

/// **STEP S10.** The PCS parameters are the shape's: at the toy `log_cols 8`,
/// rate 1/8, `Q = 256`; at the development rung `log_cols 10`, rate 1/4,
/// `Q = 256`. The load-bearing invariant checked here is that THE PAD COUNT
/// AND THE NUMBER OF OPENED COLUMNS MOVE TOGETHER: `ZkOpts::standard` takes
/// its `q_pad` from `num_col_checks`, so one cannot be changed without the
/// other, and the hiding clear vector is `n + Q` long at every shape.
#[test]
fn the_pcs_parameters_come_from_the_shape_and_the_pad_count_tracks_the_opened_columns() {
    for (sh, want) in [(Shape::toy(), (8u32, 8usize, 256usize)), (Shape::rung(), (10, 4, 256)), (Shape::m125(), (14, 4, 256))] {
        let p = super::protocol::pcs_params_at(&sh);
        assert_eq!((p.log_cols, p.inv_rate, p.num_col_checks), want, "{}: PCS parameters", sh.name);
        assert_eq!(crate::pcs::ZkOpts::standard(&p).q_pad, p.num_col_checks, "{}: the pad count is the opened-column count", sh.name);
        assert_eq!(p.enc_cols(), (1usize << sh.log_cols) * sh.inv_rate, "{}: encoded row width", sh.name);
    }
}

/// **STEP C part 2, the wire half.** `wire::encoded_len` was four toy
/// literals (the 512-word clear vector, the 2048-column encoding, the 11-step
/// path, the 256 checks) plus `A_GROUPS` / `H_GROUPS` / `ENDPOINT_ROWS`. It
/// now reads all of them off the layout's shape, so it must agree PART FOR
/// PART with `Shape::receipt_bytes` at every shape — including the toy's
/// frozen 2,816,472 bytes and, since S11a, the rung's 4,218,264 (the Python
/// model's 4,173,208 plus the 45,056 B the frozen seam's padded endpoint
/// costs; see `MODEL_RUNG`).
///
/// It also pins the PER-PROFILE wire bound (the S11a ruling): the toy's is
/// the unchanged 4 MiB constant and the toy frame is under it; every other
/// profile's is its own counted length, which the rung frame exceeds 4 MiB
/// to reach and the 125M frame exceeds it many times over.
#[test]
fn the_codec_length_is_the_models_at_every_shape() {
    // STAGE 20: the three pinned lengths are the pre-repair ones plus the
    // COUNTED bilinear delta of `s20_bilinear_delta`; the toy's delta is zero.
    for (sh, want) in [
        (Shape::toy(), s20_frame_bytes(&Shape::toy(), 2_816_472usize)),
        (Shape::rung(), s20_frame_bytes(&Shape::rung(), 4_218_264)),
        (Shape::rung_g(), s20_frame_bytes(&Shape::rung_g(), 4_234_648)),
        (Shape::m125(), Shape::m125().receipt_bytes().total),
    ] {
        let lay = Layout::for_shape(&sh).expect("the shape is well formed");
        assert_eq!(sh.receipt_bytes().total, want, "{}: the model's receipt total", sh.name);
        assert_eq!(super::wire::encoded_len(&lay), want, "{}: the codec's frame length differs from the model", sh.name);
        assert_eq!(super::wire::wire_bound(&lay), if sh.is_frozen_toy() { MAX_WIRE_BYTES } else { want }, "{}: the wire bound", sh.name);
        assert!(want <= super::wire::wire_bound(&lay), "{}: the frame does not fit its own bound", sh.name);
    }
    // the toy's bound is the frozen constant and the toy frame is under it;
    // the rung's frame is 23,960 B OVER that constant, which is why the bound
    // had to become per-profile at all
    let rung_now = s20_frame_bytes(&Shape::rung(), 4_218_264);
    assert!(2_816_472 < MAX_WIRE_BYTES && rung_now > MAX_WIRE_BYTES);
    assert_eq!(rung_now - MAX_WIRE_BYTES, 23_960 + s20_bilinear_delta(&Shape::rung()).1, "the rung frame's overshoot of the toy bound");
    assert!(Shape::m125().receipt_bytes().total <= super::wire::MAX_WIRE_BYTES_ANY, "125M must fit the absolute ceiling");
    // the toy path is unchanged: the public entry point still reports the frozen length
    assert_eq!(encoded_len(), 2_816_472);
}

/// **STEP C part 2, the capability bound.** The module builds ONE NTT table,
/// wide enough for the toy and the development rung (both `2^12`) and for the
/// fixed mask domain. The 125M shape needs `2^16`, and both shaped entry
/// points refuse it BY NAME before anything public exists rather than
/// building a table that is silently too small. This is a capability
/// statement about this lane, not a soundness one.
#[test]
fn a_shape_wider_than_the_ntt_tables_is_refused_by_name() {
    // S11b: the rung-G profile's endpoint encodes over 2^(10 + 2) = 2^12,
    // exactly the module's table — which is one reason its inverse rate is
    // 4 and not the frozen seam's 8, which would need 2^13
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g()] {
        super::protocol::fits_the_ntt_tables(&sh).unwrap_or_else(|e| panic!("{}: {e}", sh.name));
    }
    let g = Shape::rung_g();
    assert_eq!(g.endpoint_log_n + g.endpoint_inv_rate.trailing_zeros() as usize, 12, "the rung-G endpoint's encoding domain");
    // **STAGE 9.** The table is a function of the shape now, so 125M is no
    // longer refused: `max(14 + 2, 12) = 16` for `A` / `H`, and its endpoint
    // builds its own `2^16` table. What is refused is a shape past the
    // prototype ceiling — whichever guard reaches it first.
    super::protocol::fits_the_ntt_tables(&Shape::m125()).expect("125M fits the shape-driven tables");
    let m = Shape::m125();
    assert_eq!(m.log_cols + m.inv_rate.trailing_zeros() as usize, 16, "125M's A / H encoding domain");
    assert_eq!(m.endpoint_log_n + m.endpoint_inv_rate.trailing_zeros() as usize, 16, "125M's endpoint encoding domain");
    let wide = Shape::new("a shape past the prototype ceiling", "hashline-zk-mr1/private-block-too-wide-dev/1", 512, 768, 2048, 12, 64, 4, 19, 4, 9, 37, None, None, None, None);
    match wide {
        Err(e) => eprintln!("a 2^21 shape is refused at construction: {e}"),
        Ok(s) => {
            let err = super::protocol::fits_the_ntt_tables(&s).expect_err("a shape past the ceiling must be refused");
            assert!(err.contains("exceeds the module's ceiling"), "{err}");
        }
    }
}

// ---------------------------------------------- the hash-layer code conditions

/// **CODE CONDITION C-H4 and C-H4'** of the hash-layer disposition, as
/// assertions that cost no proof byte.
///
/// C-H4: a committed column is hashed as `8 * rows` bytes, so no commitment
/// on the block path may have 5 or 8 rows (40 and 64 bytes, the two lengths
/// the randomness refill and an internal Merkle node use). `Layout::for_shape`
/// checks it at construction for EVERY shape; here the four counts are read
/// off all three shapes, and a hand-made shape with a forbidden count is
/// shown to be refused by name.
///
/// C-H4': no domain label of this module may be 28 or 35 bytes long. Rather
/// than list the labels — a list that goes stale the day one is added — this
/// reads THE MODULE'S OWN SOURCE and checks every byte-string literal in the
/// six non-test files of the block path, which is a superset of the labels.
#[test]
fn no_commitment_column_and_no_domain_label_can_be_confused_with_a_hash_input() {
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::m125()] {
        let lay = Layout::for_shape(&sh).expect("the shape is well formed");
        for (what, r) in [("A", lay.a_rows), ("H", lay.h_rows), ("M", M_ROWS), ("endpoint", sh.endpoint_rows)] {
            assert!(r != 5 && r != 8, "{}: the {what} commitment has {r} rows (C-H4)", sh.name);
        }
    }
    // the refusal itself, by name: 8 rows is the 64-byte node format
    let err = super::layout::no_commitment_has_a_node_shaped_column(&[("A", 455), ("probe", 8)]).expect_err("8 rows must be refused");
    assert!(err.contains("C-H4") && err.contains("64 bytes"), "{err}");
    assert!(super::layout::no_commitment_has_a_node_shaped_column(&[("probe", 5)]).is_err(), "5 rows is the 40-byte refill format");

    // C-H4': every byte-string literal of the block path's own source
    let sources: [(&str, &str); 8] = [
        ("argument.rs", include_str!("argument.rs")),
        // S11b: the generalised endpoint's own domain label is on the block
        // path too, so it is scanned with the rest
        ("endpoint_g.rs", include_str!("endpoint_g.rs")),
        ("layout.rs", include_str!("layout.rs")),
        ("protocol.rs", include_str!("protocol.rs")),
        ("wire.rs", include_str!("wire.rs")),
        ("witness.rs", include_str!("witness.rs")),
        ("shape.rs", include_str!("shape.rs")),
        ("private_block.rs", include_str!("../private_block.rs")),
    ];
    let mut seen = 0usize;
    for (name, src) in sources {
        let b = src.as_bytes();
        for i in 0..b.len().saturating_sub(1) {
            if b[i] != b'b' || b[i + 1] != b'"' || (i > 0 && (b[i - 1].is_ascii_alphanumeric() || b[i - 1] == b'_')) {
                continue;
            }
            let (mut j, mut len, mut esc) = (i + 2, 0usize, false);
            while j < b.len() && (esc || b[j] != b'"') {
                esc = !esc && b[j] == b'\\';
                if !esc {
                    len += 1;
                }
                j += 1;
            }
            seen += 1;
            assert!(len != 28 && len != 35, "{name}: a {len}-byte literal is a forbidden domain-label length (C-H4')");
        }
    }
    assert!(seen >= 20, "the source scan found only {seen} byte-string literals; it has stopped working");
}

/// **CODE CONDITION C-H1** of the hash-layer disposition: no Merkle leaf the
/// block path creates is ever built without a salt.
///
/// The block path creates leaves in exactly two calls — `pcs::commit_zk_owned`
/// (the `A`, `H` and two endpoint commitments) and `zk::mask_commit` (the `M`
/// commitment) — and both salt every leaf; that half of the condition lives
/// in `zkp-core`, which this lane does not touch. What is checkable HERE is
/// the published half: every opened column of an honest receipt carries a
/// NONZERO 32-byte salt, the salt is a function of the column index (one
/// leaf, one salt), and two different columns of one commitment never share
/// one. A leaf built without a salt breaks all three. All 1,280 opened
/// columns of a toy receipt are checked (256 each for `A`, `H`, `M` and the
/// two endpoints).
///
/// **FINDING C2-F1, recorded by this test.** The opened-column indices are
/// drawn WITH REPLACEMENT: an honest toy receipt publishes 1,280 columns at
/// only about 1,225 distinct indices — the birthday count for 256 draws from
/// 2,048 (4,096 for `M`). The repeats carry identical salts and identical
/// paths, which is the consistency this test asserts; nothing here says
/// whether the soundness analysis counts drawn or distinct columns.
#[test]
fn every_opened_column_of_an_honest_receipt_carries_its_own_salt() {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let spec = IoSpec::new([9u8; 32], 0, 0).expect("the approved endpoint scales");
    let out = compute_output(&blk, &input).expect("the honest block output");
    let (expected, owners) = prepare_endpoints(spec, &input, &out).expect("endpoint owners");
    let receipt = prove(&blk, &input, &expected, owners).expect("the honest toy proof");
    verify(&blk, &expected, &receipt).expect("it verifies");
    let mut per_commitment = Vec::new();
    let mut total = 0usize;
    let mut distinct = 0usize;
    let mut check = |what: &str, cols: &[(usize, Vec<crate::field::Fp>, [u8; 32], Vec<crate::merkle::Digest>)]| {
        per_commitment.push(cols.len());
        total += cols.len();
        let mut by_index: Vec<(usize, [u8; 32])> = cols.iter().map(|(j, _, s, _)| (*j, *s)).collect();
        by_index.sort_unstable();
        by_index.dedup();
        // one leaf, one salt: after deduplicating (index, salt) pairs no index is left twice
        let mut idx: Vec<usize> = by_index.iter().map(|(j, _)| *j).collect();
        let before = idx.len();
        idx.dedup();
        assert_eq!(idx.len(), before, "{what}: one column index was published with two different salts (C-H1)");
        let mut salts: Vec<[u8; 32]> = by_index.iter().map(|(_, s)| *s).collect();
        assert!(salts.iter().all(|s| *s != [0u8; 32]), "{what}: an opened column was published with a zero salt (C-H1)");
        salts.sort_unstable();
        let n = salts.len();
        salts.dedup();
        assert_eq!(salts.len(), n, "{what}: two different columns share a salt (C-H1)");
        distinct += n;
    };
    check("M", &receipt.mask_open.columns);
    for (what, o) in [("A", &receipt.a_open), ("H", &receipt.h_open), ("input", &receipt.io_open[0]), ("output", &receipt.io_open[1])] {
        check(what, &o.columns);
    }
    assert_eq!(per_commitment, vec![256; 5], "five commitments, each opening Q = 256 columns");
    assert_eq!(total, 1280);
    assert!(distinct < total, "finding C2-F1: the column draws are with replacement, so repeats are expected");
}

/// **CODE CONDITION C-H8**: the pad count is at least — and at these
/// profiles' parameters exactly — the number of opened columns. Both are
/// `sh.opened_cols`, through `ZkOpts::standard`, so they cannot drift apart:
/// `the_pcs_parameters_come_from_the_shape_and_the_pad_count_tracks_the_opened_columns`
/// asserts the equality at all three shapes. This test adds the INEQUALITY as
/// the condition states it, and the consequence the wire depends on: a hiding
/// clear vector is `n + Q` words long, so the pad count is what the codec
/// transports.
#[test]
fn the_pad_count_is_at_least_the_number_of_opened_columns() {
    for sh in [Shape::toy(), Shape::rung(), Shape::m125()] {
        let p = super::protocol::pcs_params_at(&sh);
        let q_pad = crate::pcs::ZkOpts::standard(&p).q_pad;
        assert!(q_pad >= p.num_col_checks, "{}: pad count {q_pad} < opened columns {} (C-H8)", sh.name, p.num_col_checks);
        assert_eq!(q_pad, sh.opened_cols, "{}: at this profile's parameters the two are equal", sh.name);
        let r = sh.receipt_bytes();
        let lay = Layout::for_shape(&sh).expect("the shape is well formed");
        let vec_words = (1usize << sh.log_cols) + q_pad;
        assert_eq!(r.a_opening, (sh.a_groups() + 1) * vec_words * 16 + sh.opened_cols * (8 + lay.a_rows * 8 + 32 + ((1usize << sh.log_cols) * sh.inv_rate).trailing_zeros() as usize * 32), "{}: the A opening's clear vectors are n + Q words", sh.name);
    }
}

// --------------------------------------------- S11b: the generalised endpoint

/// **S11b.** The RUNG-G profile is the rung's geometry with a different
/// endpoint, and nothing else: every counted number of the layout is the
/// rung's, and the receipt differs by the two endpoint openings alone.
#[test]
fn the_rung_g_profile_is_the_rung_with_a_different_endpoint() {
    let (r, g) = (Shape::rung(), Shape::rung_g());
    assert_ne!(r.profile, g.profile, "a new endpoint is a NEW profile, never an edit of one (D17)");
    // the block geometry is identical
    assert_eq!((r.tokens, r.width, r.hidden, r.q_heads, r.head_dim, r.kv_heads), (g.tokens, g.width, g.hidden, g.q_heads, g.head_dim, g.kv_heads));
    assert_eq!((r.log_cols, r.inv_rate, r.opened_cols, r.f_e), (g.log_cols, g.inv_rate, g.opened_cols, g.f_e));
    // the endpoint is not
    assert_eq!((r.endpoint_rows, r.endpoint_log_n, r.endpoint_inv_rate, r.endpoint_general), (21, 8, 8, false), "the frozen-seam rung's endpoint moved");
    assert_eq!((g.endpoint_rows, g.endpoint_log_n, g.endpoint_inv_rate, g.endpoint_general), (9, 10, 4, true), "the rung-G endpoint");
    // MORE THAN ONE data row per endpoint, as 125M will have
    assert_eq!(g.endpoint_rows - 5, 4, "the rung-G endpoint must exercise several data rows");
    assert_eq!(Shape::m125().endpoint_rows - 5, 32, "125M's endpoint data rows");
    // every counted total but the receipt is the rung's
    let (tr, tg) = (r.totals(), g.totals());
    assert_eq!((tr.a_rows, tr.h_rows, tr.a_sites, tr.h_sites, tr.a_groups, tr.h_groups), (tg.a_rows, tg.h_rows, tg.a_sites, tg.h_sites, tg.a_groups, tg.h_groups));
    assert_eq!((tr.main_rounds, tr.extension_rounds, tr.u8_lookups, tr.exp_pairs, tr.act_pairs), (tg.main_rounds, tg.extension_rounds, tg.u8_lookups, tg.exp_pairs, tg.act_pairs));
    let (br, bg) = (tr.receipt_bytes, tg.receipt_bytes);
    assert_eq!((br.slots, br.mask_opening, br.a_opening, br.h_opening), (bg.slots, bg.mask_opening, bg.a_opening, bg.h_opening), "only the endpoint openings may differ");
    assert_eq!((br.endpoint_openings, bg.endpoint_openings), (319_488, 335_872), "the two endpoint opening costs");
    assert_eq!(bg.total - br.total, 16_384, "the rung-G frame's excess over the rung's");
    // and the shaped endpoint statement derives the declared geometry
    let spec = IoSpec::new_shaped(&g, [5u8; 32], 0, 0).expect("the rung-G endpoint spec");
    spec.validate().expect("the declared endpoint rows are what the parameters give");
}

/// **S11b, STEP 5: the 125M shape CONSTRUCTS.** Nothing is proved here and
/// nothing may be: this asserts that the shaped layout, the wire format and
/// the endpoint statement all build at 125M and agree on their counted
/// numbers, and that what still refuses at 125M refuses BY NAME.
#[test]
fn the_125m_shape_constructs_and_what_still_refuses_says_so_by_name() {
    let sh = Shape::m125();
    assert!(sh.endpoint_general, "125M cannot use the frozen seam");
    let lay = Layout::for_shape(&sh).expect("the 125M layout builds");
    // the counted rows
    assert_eq!((lay.a_rows, lay.h_rows), (5_681, 7_120), "125M's committed rows");
    assert_eq!((sh.endpoint_rows, sh.endpoint_log_n, sh.endpoint_inv_rate), (37, 14, 4), "125M's endpoint geometry");
    assert_eq!(super::protocol::endpoint_geometry(&sh).expect("the geometry"), (37, 32, 34), "125M's (rows, data, prox)");
    // the counted receipt, codec and model agreeing
    let r = sh.receipt_bytes();
    assert_eq!(r.endpoint_openings, 1_499_136, "125M's two endpoint openings");
    assert_eq!(r.total, s20_frame_bytes(&sh, 40_782_792), "125M's counted receipt (the pre-repair figure plus the stage-20 bilinear delta)");
    assert_eq!(super::wire::encoded_len(&lay), r.total, "the codec's frame length differs from the model at 125M");
    // the endpoint STATEMENT builds at 125M, with no witness and no proof
    let spec = IoSpec::new_shaped(&sh, [11u8; 32], 0, 0).expect("the 125M endpoint spec builds");
    spec.validate().expect("125M's declared endpoint rows are what its parameters give");
    // **STAGE 9 lifted the one thing that still refused.** The module's NTT
    // table was the constant `2^12` and 125M encodes `A` / `H` over `2^16`;
    // the table is a function of the shape now (`protocol::ntt_log_at`), the
    // toy's and the rung's are unchanged at `2^12` by construction, and this
    // gate passes. The endpoint builds its own table, as it always did.
    super::protocol::fits_the_ntt_tables(&sh).expect("stage 9: 125M fits the shape-driven NTT tables");
    // WHAT STILL REFUSES AT 125M, by name: the frozen seam, which cannot
    // carry the plane at all
    assert!(crate::private_seam::SeamSpec::new([11u8; 32], sh.t_pad, sh.d_pad, 0, 41, 42).is_err(), "the frozen seam must refuse 125M's endpoint plane");
}
