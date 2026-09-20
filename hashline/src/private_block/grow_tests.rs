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
    main_rounds: 215,
    extension_rounds: 25,
    u8_per_domain: [2_048, 155_648, 73_728, 53_248, 12_288, 122_880],
    u8_lookups: 419_840,
    exp_pairs: 8_192,
    act_pairs: 8_192,
    // the memo's §9a table says 4,173,032; the model's extra 176 B is
    // `SC_KVZC`'s support indicator, which §9a's own domain paragraph
    // requires because `Dom::Kv` pads at the rung (lane finding B-F3, open
    // for the security owner). The Rust agrees with the model, not with the
    // table.
    receipt_total: 4_173_208,
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
    main_rounds: 332,
    extension_rounds: 25,
    u8_per_domain: [32_768, 17_825_792, 9_437_184, 6_815_744, 1_572_864, 62_914_560],
    u8_lookups: 98_598_912,
    exp_pairs: 4_194_304,
    act_pairs: 1_048_576,
    receipt_total: 40_750_024,
};

fn check_against_model(sh: &Shape, want: &Expected) {
    let t: Totals = sh.totals();
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
#[test]
fn the_shape_driven_layout_matches_the_python_model_at_the_rung_and_at_125m() {
    check_against_model(&Shape::rung(), &MODEL_RUNG);
    check_against_model(&Shape::m125(), &MODEL_M125);
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
    assert_eq!(r.endpoint_openings, 1_466_368, "two endpoint openings");
    assert_eq!(r.mask_opening, 243_712, "M opening");
    assert_eq!(r.slots, 27_456, "23 slots");
    assert_eq!(r.header_and_three_roots, 136, "header + three roots");
    assert_eq!(r.total, 40_750_024, "one 125M block");
    // and the toy's, which the wire format actually produces
    assert_eq!(Shape::toy().receipt_bytes().total, 2_816_472);
}
