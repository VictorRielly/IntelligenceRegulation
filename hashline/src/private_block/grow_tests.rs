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

use super::argument::{table_values_act, table_values_exp, table_values_u8};
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
#[ignore = "S4 not yet applied: at the rung the sum claim raises three column-weight keys and check_opening refuses (B-3)"]
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
