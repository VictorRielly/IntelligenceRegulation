//! **STAGE 28 — the performance stage's own equality gates.**
//!
//! Stage 28 makes the 125M prover faster and is allowed to move NOTHING a
//! verifier can see. The two things it changes are arithmetic, so the gate is
//! arithmetic too: for every change, the OLD computation and the NEW one are
//! run on the same inputs in the same test and compared word for word,
//! including on the inputs that must be REFUSED.
//!
//! The old computation is re-derived here from `crate::field` rather than
//! called through the production helper, so this file is an independent
//! oracle and not a second name for the code under test.

use super::argument::table_values_u8_at;
use super::layout::U8_LEN;
use super::protocol::{helper_inverses_u8, u8_denominator_inverses};
use crate::field::{batch_inverse2_checked, Fp2};

/// The refusal both paths owe, verbatim (`protocol.rs`'s `ZERO_DENOMINATOR`).
const REFUSAL: &str = "zero LogUp denominator; discard attempt";

/// A deterministic stream; the same index always gives the same word.
fn xs(seed: u64) -> impl FnMut() -> u64 {
    let mut x = seed | 1;
    move || {
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }
}

fn point(seed: u64) -> Fp2 {
    let mut r = xs(seed);
    Fp2::new(crate::field::Fp::new(r() % crate::field::P), crate::field::Fp::new(r() % crate::field::P))
}

/// **THE OLD PATH**, re-derived from the field API: the whole column of
/// denominators `alpha - (v + g_u8)`, handed to the checked batch inversion,
/// which refuses iff one of THOSE entries is zero.
fn old_path(col: &[i64], alpha: Fp2, g_u8: Fp2) -> Result<Vec<Fp2>, String> {
    let mut den: Vec<Fp2> = col.iter().map(|v| alpha.sub(Fp2::from_i64(*v).add(g_u8))).collect();
    batch_inverse2_checked(&mut den).map_err(|_| REFUSAL.to_string())?;
    Ok(den)
}

fn new_path(col: &[i64], alpha: Fp2, g_u8: Fp2) -> Result<Vec<Fp2>, String> {
    helper_inverses_u8(col, alpha, g_u8, &u8_denominator_inverses(alpha, g_u8))
}

/// A byte column of `len` words, every value in `0..U8_LEN`.
fn byte_column(len: usize, seed: u64) -> Vec<i64> {
    let mut r = xs(seed);
    (0..len).map(|_| (r() % U8_LEN as u64) as i64).collect()
}

/// **THE EQUALITY GATE for the helper inverses.** Random byte columns at four
/// lengths, both sides of the one-thread / many-thread threshold, under
/// several challenge pairs: the two paths return the same `Ok` vector, word
/// for word.
#[test]
fn the_table_path_and_the_batch_inversion_agree_word_for_word_on_byte_columns() {
    let mut checked = 0usize;
    for (si, seed) in [7u64, 1_000_003, 0xDEAD_BEEF].into_iter().enumerate() {
        let (alpha, g_u8) = (point(seed), point(seed ^ 0x5555));
        // 1 and 255 are below the threshold, 16,384 is at it, 70,000 is above
        // it and is several rayon chunks
        for len in [1usize, 255, 1 << 14, 70_000] {
            let col = byte_column(len, seed.wrapping_add(len as u64));
            let old = old_path(&col, alpha, g_u8).expect("random challenges do not hit a table value");
            let new = new_path(&col, alpha, g_u8).expect("the table path agrees that nothing is refused");
            assert_eq!(old.len(), new.len(), "case {si}/{len}: the column length moved");
            for (i, (a, b)) in old.iter().zip(new.iter()).enumerate() {
                assert_eq!(a, b, "case {si}/{len}: word {i} (value {}) differs", col[i]);
            }
            // and the words really are inverses, so neither path is vacuous
            for (i, w) in new.iter().enumerate() {
                assert_eq!(w.mul(alpha.sub(Fp2::from_i64(col[i]).add(g_u8))), Fp2::ONE, "case {si}/{len}: word {i} is not the inverse");
            }
            checked += len;
        }
    }
    assert!(checked > 200_000, "the gate compared only {checked} words");
}

/// **THE EQUALITY GATE for a witness the prover must still handle**: values
/// OUTSIDE `0..U8_LEN`. Only a dishonest or tampered witness carries them (the
/// soundness tests build exactly these), the table cannot serve them, and the
/// new path must fall back to the old arithmetic and produce the old word.
#[test]
fn the_table_path_agrees_on_columns_that_carry_values_outside_the_byte_table() {
    let (alpha, g_u8) = (point(99), point(0xABCD));
    let mut col: Vec<i64> = byte_column(4_096, 31);
    // every kind of out-of-range word a tampered plane can carry
    for (i, v) in [-1i64, -128, 256, 1_000_000, i64::MIN, i64::MAX, -(1 << 40), 1 << 40].into_iter().enumerate() {
        col[i * 37 + 5] = v;
    }
    // and a long one, to cross the parallel threshold with the same values
    let long: Vec<i64> = col.iter().copied().cycle().take(40_000).collect();
    for c in [col, long] {
        let old = old_path(&c, alpha, g_u8).expect("no denominator is zero here");
        let new = new_path(&c, alpha, g_u8).expect("the table path handles the out-of-range words");
        assert_eq!(old, new, "an out-of-range word took a different value through the table path");
    }
}

/// **THE REFUSAL GATE, case 1 — the value IS in the column.** With
/// `alpha = v0 + g_u8` the denominator at `v0` is zero. The old path refuses
/// because that zero is an entry of the column it inverts; the new path
/// refuses because the table entry for `v0` is `None` and the column asks for
/// it. Same `Result`, same string.
#[test]
fn a_zero_denominator_at_a_value_the_column_carries_is_refused_by_both_paths() {
    let g_u8 = point(4_242);
    for v0 in [0i64, 1, 128, 255] {
        let alpha = Fp2::from_i64(v0).add(g_u8);
        // the table's own view: exactly one entry is unusable, and it is v0's
        let tbl = u8_denominator_inverses(alpha, g_u8);
        assert_eq!(tbl.iter().filter(|e| e.is_none()).count(), 1, "v0={v0}: more than one table entry is unusable");
        assert!(tbl[v0 as usize].is_none(), "v0={v0}: the unusable entry is not v0's");
        for len in [1usize, 4_096, 40_000] {
            let mut col = byte_column(len, 5);
            col[len / 2] = v0;
            assert_eq!(old_path(&col, alpha, g_u8), Err(REFUSAL.to_string()), "v0={v0}, len={len}: the old path did not refuse");
            assert_eq!(new_path(&col, alpha, g_u8), Err(REFUSAL.to_string()), "v0={v0}, len={len}: the new path did not refuse");
        }
    }
}

/// **THE REFUSAL GATE, case 2 — the value is NOT in the column.** The same
/// zero denominator, at a byte no column carries: neither path may refuse,
/// and both must produce the same words. This is the case that decides
/// whether the refusal depends on the hidden input at THIS line, and the
/// answer here is that it does — which is why the new path is written value
/// by value and not table-wide. (What happens LATER in the same proof is
/// finding S28-F1, the test below.)
#[test]
fn a_zero_denominator_at_a_value_no_column_carries_is_refused_by_neither_path() {
    let g_u8 = point(777);
    let v0 = 200i64;
    let alpha = Fp2::from_i64(v0).add(g_u8);
    for len in [1usize, 4_096, 40_000] {
        // a column of 0..200 only: v0 is absent by construction
        let mut r = xs(len as u64 + 3);
        let col: Vec<i64> = (0..len).map(|_| (r() % v0 as u64) as i64).collect();
        assert!(!col.contains(&v0), "len={len}: the column carries v0 after all");
        let old = old_path(&col, alpha, g_u8).expect("len: the old path refuses a value the column does not carry");
        let new = new_path(&col, alpha, g_u8).expect("the new path refuses a value the column does not carry");
        assert_eq!(old, new, "len={len}: the two paths disagree when the zero denominator is absent");
    }
}

/// **FINDING S28-F1, as a test.** A zero `U8` denominator refuses the attempt
/// WHATEVER the witness carries, because the three table helpers invert the
/// denominator of EVERY table value a few lines later
/// (`protocol.rs`: `inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?`).
/// So the refusal at a byte value is a function of the public challenges and
/// the public table alone, and not of the hidden input; what the hidden input
/// decides is only WHICH of the two lines refuses first, and both return the
/// same string.
///
/// This test does not change that behaviour and is not a licence to: the
/// security owner rules on it. It records it, with the arithmetic.
#[test]
fn a_zero_u8_denominator_refuses_through_the_table_helpers_even_when_no_column_carries_that_value() {
    let g_u8 = point(31_337);
    for (v0, tab_len) in [(200i64, U8_LEN), (0, 4 * U8_LEN), (255, 8 * U8_LEN)] {
        let alpha = Fp2::from_i64(v0).add(g_u8);
        // the witness side: a column that does NOT carry v0 is accepted
        let col: Vec<i64> = (0..1_024).map(|i| (i % 200) as i64).collect();
        assert!(!col.contains(&v0) || v0 < 200, "the fixture column's range moved");
        if !col.contains(&v0) {
            assert!(new_path(&col, alpha, g_u8).is_ok(), "v0={v0}: the helper line refused a value the column does not carry");
        }
        // the table side, the prover's very next lines: every table value is
        // inverted, v0's among them, so the attempt is refused
        let tv = table_values_u8_at(tab_len, g_u8);
        assert_eq!(tv.len(), tab_len, "the table length moved");
        let mut den: Vec<Fp2> = tv.iter().map(|t| alpha.sub(*t)).collect();
        assert!(den.iter().any(|d| d.is_zero()), "v0={v0}: the table does not carry the value whose denominator is zero");
        assert!(batch_inverse2_checked(&mut den).is_err(), "v0={v0}: the table helper accepted a zero denominator");
        // and the padded copies repeat the true rows, so a longer table is the
        // same set of values and the same verdict
        for (i, t) in tv.iter().enumerate() {
            assert_eq!(*t, tv[i % U8_LEN], "the padded table entry {i} is not its true row's");
        }
    }
}

/// **THREAD-COUNT INVARIANCE.** The parallel path is indexed, so the vector it
/// returns cannot depend on how many threads rayon gives it. Checked rather
/// than argued: the same column through a one-thread pool, a three-thread
/// pool and the ambient pool.
#[test]
fn the_helper_column_is_the_same_vector_whatever_the_thread_count_is() {
    let (alpha, g_u8) = (point(2_026), point(9_21));
    let col = byte_column(70_000, 12_345);
    let ambient = new_path(&col, alpha, g_u8).expect("the ambient pool");
    for threads in [1usize, 3, 8] {
        let pool = rayon::ThreadPoolBuilder::new().num_threads(threads).build().expect("a rayon pool");
        let got = pool.install(|| new_path(&col, alpha, g_u8)).expect("the pinned pool");
        assert_eq!(got, ambient, "{threads} threads produced a different helper column");
    }
    // and the words are the old path's
    assert_eq!(ambient, old_path(&col, alpha, g_u8).expect("the old path"), "the parallel path left the old words");
}
