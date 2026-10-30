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

// ---------------------------------------------------------------------------
// TASK 2 — the slot table builders
// ---------------------------------------------------------------------------

use super::argument::{eq_cube, priv_table, Cm, Coord, Priv};
use crate::field::Fp;
use crate::mle::eq_table_msb;

/// **THE OLD `priv_table`**, copied verbatim from the tip this stage opened
/// at (`79f0726`), as the oracle the new one is compared against.
// STAGE 29: `pub(super)` so that `s29_tests`' `table_of_79f0726` can call the
// SAME verbatim copy instead of taking a third one.
pub(super) fn priv_table_walked(p: &Priv, data: &[Fp], n_vars: usize) -> Vec<Fp2> {
    let fixed: Vec<Fp2> = p.coords.iter().filter_map(|c| if let Coord::Fixed(f) = c { Some(*f) } else { None }).collect();
    let eqf = eq_table_msb(&fixed);
    let mut used = 0usize;
    for c in &p.coords {
        if let Coord::Rho(k) | Coord::Flip(k) = c {
            used |= 1usize << (n_vars - 1 - *k);
        }
    }
    let mut out = vec![Fp2::ZERO; 1usize << n_vars];
    for idx in 0..1usize << p.log {
        let (mut x, mut z) = (0usize, 0usize);
        for (j, c) in p.coords.iter().enumerate() {
            let b = (idx >> (p.log - 1 - j)) & 1;
            match c {
                Coord::Rho(k) => x |= b << (n_vars - 1 - *k),
                Coord::Flip(k) => x |= (1 - b) << (n_vars - 1 - *k),
                Coord::Fixed(_) => z = (z << 1) | b,
            }
        }
        let mut v = Fp2::ZERO;
        for (off, coef) in &p.slices {
            v = v.add(coef.mul_base(data[*off + idx]));
        }
        out[x] = out[x].add(eqf[z].mul(v));
    }
    for x in 0..out.len() {
        if x & !used != 0 {
            out[x] = out[x & used];
        }
    }
    out
}

/// **THE OLD `eq` cube build**, likewise verbatim.
pub(super) fn eq_cube_gathered(e: &[Fp2], n_vars: usize, start: usize) -> Vec<Fp2> {
    let shift = n_vars - start - e.len().trailing_zeros() as usize;
    (0..1usize << n_vars).map(|x| e[(x >> shift) & (e.len() - 1)]).collect()
}

fn base_data(len: usize, seed: u64) -> Vec<Fp> {
    let mut r = xs(seed);
    (0..len).map(|_| Fp::new(r() % crate::field::P)).collect()
}

/// Deterministic `Priv` descriptors that cover what the schedule builds: a
/// plain plane, a plane with fixed coordinates, one with a flipped
/// coordinate, one that does not depend on every variable (so the broadcast
/// pass runs), an `H` plane with its two slices and the `u` coefficient, and
/// coordinate orders that are not the identity.
fn priv_cases(n_vars: usize, seed: u64) -> Vec<(&'static str, Priv)> {
    let f = |i: u64| Fp2::new(Fp::new(i.wrapping_mul(2_654_435_761) % crate::field::P), Fp::new(i.wrapping_mul(97) % crate::field::P));
    let mut out: Vec<(&'static str, Priv)> = Vec::new();
    // (a) the identity map over every variable, one slice, coefficient one
    out.push((
        "identity, one slice",
        Priv { cm: Cm::A, slices: vec![(0, Fp2::ONE)], log: n_vars, coords: (0..n_vars).map(Coord::Rho).collect(), mask_row: 0, ext_round: 0 },
    ));
    // (b) a permutation of the variables, two slices, the H pair's coefficients
    out.push((
        "permuted, two slices (H pair)",
        Priv {
            cm: Cm::H,
            slices: vec![(0, Fp2::ONE), (1usize << n_vars, Fp2::U)],
            log: n_vars,
            coords: (0..n_vars).map(|k| Coord::Rho((k + 2) % n_vars)).collect(),
            mask_row: 0,
            ext_round: 0,
        },
    ));
    // (c) two FIXED coordinates in the middle, so eqf has four entries
    let mut c = Vec::new();
    for k in 0..n_vars {
        c.push(if k == 1 { Coord::Fixed(f(seed + 1)) } else if k == 3 { Coord::Fixed(f(seed + 2)) } else { Coord::Rho(k) });
    }
    out.push(("two fixed coordinates", Priv { cm: Cm::A, slices: vec![(3, Fp2::ONE)], log: n_vars, coords: c, mask_row: 0, ext_round: 0 }));
    // (d) a FLIPPED coordinate (the RoPE partner half)
    let mut c = Vec::new();
    for k in 0..n_vars {
        c.push(if k == n_vars - 2 { Coord::Flip(k) } else { Coord::Rho(k) });
    }
    out.push(("one flipped coordinate", Priv { cm: Cm::A, slices: vec![(0, f(seed + 3))], log: n_vars, coords: c, mask_row: 0, ext_round: 0 }));
    // (e) a plane SHORTER than the cube: the broadcast pass has work to do
    out.push((
        "short plane, broadcast",
        Priv { cm: Cm::A, slices: vec![(5, Fp2::ONE)], log: n_vars - 2, coords: (0..n_vars - 2).map(Coord::Rho).collect(), mask_row: 0, ext_round: 0 },
    ));
    // (f) short AND fixed AND flipped together, at an odd length
    let mut c: Vec<Coord> = vec![Coord::Fixed(f(seed + 4)), Coord::Rho(n_vars - 1), Coord::Flip(0)];
    for k in 1..n_vars - 1 {
        c.push(Coord::Rho(k));
    }
    let log = c.len() - 1;
    let coords: Vec<Coord> = c.drain(..log).collect();
    out.push(("short, fixed and flipped", Priv { cm: Cm::A, slices: vec![(1, f(seed + 5)), (2, Fp2::ONE)], log, coords, mask_row: 0, ext_round: 0 }));
    out
}

/// A descriptor that uses ONE challenge index TWICE: two `idx` values then
/// land on the same `x` and the walked builder ADDS them. The construction
/// promises this never happens, and the builder counts rather than assumes
/// it, so the fallback is exercised here.
fn duplicated_index_case(n_vars: usize) -> Priv {
    let mut coords: Vec<Coord> = (0..n_vars).map(Coord::Rho).collect();
    coords[n_vars - 1] = Coord::Rho(0);
    Priv { cm: Cm::A, slices: vec![(2, Fp2::ONE)], log: n_vars, coords, mask_row: 0, ext_round: 0 }
}

/// **THE EQUALITY GATE for the slot's private tables.** The walked builder and
/// the bit-permutation builder produce the same cube, entry for entry, at
/// three widths and on six descriptor shapes.
#[test]
fn the_private_table_builder_is_the_walked_one_entry_for_entry() {
    let mut checked = 0usize;
    for n_vars in [4usize, 7, 12] {
        let data = base_data(4 << n_vars, 0xC0FF_EE00 + n_vars as u64);
        for (name, p) in priv_cases(n_vars, 11 * n_vars as u64) {
            let old = priv_table_walked(&p, &data, n_vars);
            let new = priv_table(&p, &data, n_vars);
            assert_eq!(old.len(), new.len(), "{name} at 2^{n_vars}: the cube length moved");
            for (x, (a, b)) in old.iter().zip(new.iter()).enumerate() {
                assert_eq!(a, b, "{name} at 2^{n_vars}: entry {x} differs");
            }
            // non-vacuity: the cube is not all zero and not constant
            assert!(old.iter().any(|v| !v.is_zero()), "{name}: the fixture cube is all zero");
            checked += 1;
        }
        // and the case the fast path must NOT take
        let p = duplicated_index_case(n_vars);
        assert_eq!(priv_table(&p, &data, n_vars), priv_table_walked(&p, &data, n_vars), "a duplicated challenge index at 2^{n_vars} took the plain-store path");
        checked += 1;
    }
    assert_eq!(checked, 21, "the gate compared {checked} cases");
}

/// **THE EQUALITY GATE for the `eq` cube.** The doubling build and the
/// gathered build agree at every `(width, start, |point|)` the slots use.
#[test]
fn the_eq_cube_builder_is_the_gathered_one_entry_for_entry() {
    let mut cases = 0usize;
    for n_vars in [3usize, 6, 11] {
        for plen in 0..=n_vars {
            for start in 0..=(n_vars - plen) {
                let point: Vec<Fp2> = (0..plen).map(|i| Fp2::from_i64((7 * i + 3) as i64)).collect();
                let e = eq_table_msb(&point);
                assert_eq!(eq_cube(&e, n_vars, start), eq_cube_gathered(&e, n_vars, start), "eq cube at 2^{n_vars}, start {start}, |point| {plen}");
                cases += 1;
            }
        }
    }
    assert!(cases >= 60, "the eq gate ran only {cases} cases");
}

/// **THE EQUALITY GATE for the paired helper column.** The prover writes one
/// helper per PAIR of looked columns; building the pair in one pass must give
/// the vector the two separate inversions plus the element-wise add gave, and
/// must refuse exactly where they refused.
#[test]
fn the_paired_helper_column_is_the_two_columns_inverted_and_added() {
    let (alpha, g_u8) = (point(555), point(6_060));
    for len in [1usize, 4_096, 40_000] {
        let a = byte_column(len, 17);
        let b = byte_column(len, 23);
        let want: Vec<Fp2> = old_path(&a, alpha, g_u8)
            .expect("column a")
            .iter()
            .zip(old_path(&b, alpha, g_u8).expect("column b").iter())
            .map(|(x, y)| x.add(*y))
            .collect();
        let got = super::protocol::helper_pair_inverses_u8(&a, &b, alpha, g_u8, &u8_denominator_inverses(alpha, g_u8)).expect("the paired path");
        assert_eq!(got, want, "len={len}: the paired helper column moved");
    }
    // the refusal: a zero denominator in EITHER column of the pair
    let v0 = 77i64;
    let alpha0 = Fp2::from_i64(v0).add(g_u8);
    let tbl = u8_denominator_inverses(alpha0, g_u8);
    for which in 0..2 {
        let mut a = byte_column(4_096, 41);
        let mut b = byte_column(4_096, 42);
        for c in [&mut a, &mut b] {
            c.iter_mut().for_each(|v| {
                if *v == v0 {
                    *v = 0
                }
            });
        }
        if which == 0 {
            a[100] = v0;
        } else {
            b[100] = v0;
        }
        assert_eq!(
            super::protocol::helper_pair_inverses_u8(&a, &b, alpha0, g_u8, &tbl),
            Err(REFUSAL.to_string()),
            "the paired path did not refuse a zero denominator in column {which}"
        );
        // and with v0 in neither column it is accepted, so the refusal is the
        // value's and not the pair's
        let (mut a2, mut b2) = (a.clone(), b.clone());
        a2[100] = 0;
        b2[100] = 0;
        assert!(super::protocol::helper_pair_inverses_u8(&a2, &b2, alpha0, g_u8, &tbl).is_ok(), "the paired path refused a pair that carries no zero denominator");
    }
}

/// **THE EQUALITY GATE for the looked columns.** `lookup_values` now builds
/// the columns of a big domain in parallel; a column is a per-index map, so
/// the words must be the serial map's words. The oracle here is that serial
/// map, written out in the test, on real witnesses at two shapes.
#[test]
fn the_lookup_columns_are_the_serial_per_index_maps_they_were() {
    use super::layout::Layout;
    use super::shape::Shape;
    use super::BlockPublic;
    let mut domains = 0usize;
    for sh in [Shape::toy(), Shape::rung_k4()] {
        let (public, ff, x) = super::grow_tests::tame_case(&sh);
        let blk = BlockPublic::new(public, ff);
        let w = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).expect("an honest witness at this shape");
        let lay = Layout::for_shape(&sh).expect("the layout of this shape");
        for dom in lay.lookup_doms().iter() {
            let len = lay.shape().size(*dom);
            let want: Vec<Vec<i64>> = lay
                .lookups(*dom)
                .iter()
                .map(|l| (0..len).map(|x| l.terms.iter().fold(l.cst, |a, (p, c)| a.wrapping_add(c.wrapping_mul(w.planes[*p][x])))).collect())
                .collect();
            assert_eq!(super::protocol::lookup_values(&lay, &w, *dom), want, "{}: the looked columns of {dom:?} moved", sh.name);
            domains += 1;
        }
    }
    assert!(domains >= 8, "the gate covered only {domains} domains");
}
