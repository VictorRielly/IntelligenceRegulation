//! **STAGE 29 — BOTH BRANCHES OF EVERY STAGE-28 SIZE THRESHOLD, AGAINST THE
//! OLD FORM (ruling V-4, findings S28-R1 and S28-R6).**
//!
//! Stage 28 introduced five size thresholds. Its own gates and the
//! independent review's gates reached both sides of two of them and one side
//! of three, and the three that were reached on one side only were reached on
//! the other side by nothing but the `#[ignore]`d 125M run. The review's
//! finding S28-R1 says so; the security owner's ruling V-4 says to close it.
//!
//! **The means, and why it does not change the production path.** Each
//! threshold became an ARGUMENT of an inner function (`*_at`) whose production
//! wrapper passes the constant stage 28 chose. No `cfg(test)` constant changes
//! which branch any other test takes: every other test in the filter runs the
//! same branch it ran at `db28728`, and
//! [`the_five_thresholds_are_the_constants_the_production_path_passes`] pins
//! the five constants so that a later edit cannot move one silently.
//!
//! **The oracles.** Every gate here compares against the text at `79f0726` —
//! the tip stage 28 opened at — taken verbatim by `git show`, with the ONE
//! exception recorded at [`table_of_79f0726`]. The old forms are re-derived
//! from `crate::field` / `crate::mle` and share no helper with the code under
//! test, so they are oracles and not second names for it.

use super::argument::{build_tables_at, eq_cube, total_at, Cm, Coord, Poly, Priv, ProverData, Tab, TABLES_PAR_MIN, TOTAL_PAR_MIN};
use super::layout::{Dom, Layout, U8_LEN};
use super::protocol::{byte_histogram_at, helper_inverses_u8_at, helper_pair_inverses_u8_at, lookup_values_at, u8_denominator_inverses, HELPER_PAR_MIN, HISTOGRAM_PAR_MIN, LOOKUP_PAR_MIN};
use super::s28_tests::{eq_cube_gathered, priv_table_walked};
use super::shape::Shape;
use super::BlockPublic;
use crate::field::{batch_inverse2_checked, Fp, Fp2};
use crate::mle::eq_table_msb;

/// The refusal both helper paths owe, verbatim (`protocol.rs`'s
/// `ZERO_DENOMINATOR`).
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

fn fp(v: u64) -> Fp {
    Fp::new(v % crate::field::P)
}

fn fp2(seed: u64) -> Fp2 {
    let mut r = xs(seed);
    Fp2::new(fp(r()), fp(r()))
}

/// the two pinned pools plus the ambient one, so a gate can be run at 1, 2 and
/// 8 threads from inside the test as well as from the environment
fn in_pools<T: PartialEq + std::fmt::Debug + Send>(what: &str, f: impl Fn() -> T + Sync + Send) {
    let ambient = f();
    for threads in [1usize, 2, 8] {
        let pool = rayon::ThreadPoolBuilder::new().num_threads(threads).build().expect("a rayon pool");
        assert_eq!(pool.install(&f), ambient, "{what}: {threads} threads gave a different answer");
    }
}

// ---------------------------------------------------------------------------
// THE FIVE THRESHOLDS, PINNED
// ---------------------------------------------------------------------------

/// **THE PIN.** The five constants the production wrappers pass are the five
/// stage 28 chose and measured. A later edit that moves one has to move this
/// line too, and then the ledger's census of which shape crosses which branch
/// (finding S28-R6) has to be re-derived.
#[test]
fn the_five_thresholds_are_the_constants_the_production_path_passes() {
    assert_eq!(TOTAL_PAR_MIN, 1 << 14, "the claimed sum's threshold moved");
    assert_eq!(TABLES_PAR_MIN, 1 << 17, "the slot table build's threshold moved");
    assert_eq!(LOOKUP_PAR_MIN, 1 << 17, "the looked columns' threshold moved");
    assert_eq!(HISTOGRAM_PAR_MIN, 1 << 17, "the byte histogram's threshold moved");
    assert_eq!(HELPER_PAR_MIN, 1 << 14, "the helper inverses' threshold moved");
}

// ---------------------------------------------------------------------------
// 1. `total` — the claimed sum (the finding's headline: no gate at all)
// ---------------------------------------------------------------------------

/// **THE OLD CLAIMED SUM**, copied verbatim from
/// `git show 79f0726:hashline/src/private_block/argument.rs`.
fn total_79f0726(tables: &[Vec<Fp2>], poly: &Poly) -> Fp2 {
    let mut row = vec![Fp2::ZERO; tables.len()];
    let mut acc = Fp2::ZERO;
    for x in 0..tables[0].len() {
        for (r, t) in row.iter_mut().zip(tables.iter()) {
            *r = t[x];
        }
        acc = acc.add(poly(&row));
    }
    acc
}

fn cube(len: usize, seed: u64) -> Vec<Fp2> {
    let mut r = xs(seed);
    (0..len).map(|_| Fp2::new(fp(r()), fp(r()))).collect()
}

/// **THE EQUALITY GATE for the claimed sum (S28-R1).** The serial fold, the
/// chunked parallel reduction and the `79f0726` fold agree word for word, on
/// cubes below, at and above the production threshold, with a polynomial that
/// multiplies as the slots' do — and the parallel branch is crossed by this
/// test in the ORDINARY filter, which is what the finding asks for.
#[test]
fn the_claimed_sum_is_the_79f0726_fold_through_both_branches_of_its_threshold() {
    // a degree-3 polynomial in four tables, in the shape of a zero-check slot's
    let poly: Poly = Box::new(|v: &[Fp2]| v[0].mul(v[1]).mul(v[2]).add(v[3].mul(v[0])).sub(v[2]));
    let mut crossed_parallel = 0usize;
    for (li, len) in [16usize, 1 << 10, 1 << 14, (1 << 14) + 1, 1 << 15].into_iter().enumerate() {
        let tables: Vec<Vec<Fp2>> = (0..4).map(|k| cube(len, 900 + 31 * k as u64 + li as u64)).collect();
        let want = total_79f0726(&tables, &poly);
        // FORCED SERIAL and FORCED PARALLEL on the same input
        let serial = total_at(&tables, &poly, usize::MAX);
        let parallel = total_at(&tables, &poly, 0);
        assert_eq!(serial, want, "len={len}: the serial fold left the 79f0726 word");
        assert_eq!(parallel, want, "len={len}: the chunked parallel reduction left the 79f0726 word");
        // and what the PRODUCTION constant does at this length
        assert_eq!(total_at(&tables, &poly, TOTAL_PAR_MIN), want, "len={len}: the production threshold left the 79f0726 word");
        if len > TOTAL_PAR_MIN {
            crossed_parallel += 1;
        }
        // the sum is not vacuous
        assert!(!want.is_zero(), "len={len}: the fixture sums to zero");
        // and the parallel branch does not depend on the thread count
        in_pools(&format!("the claimed sum at len={len}"), || total_at(&tables, &poly, 0));
    }
    assert!(crossed_parallel >= 2, "only {crossed_parallel} lengths were above the production threshold");
}

// ---------------------------------------------------------------------------
// 2. the slot table build, and the MOVED public table
// ---------------------------------------------------------------------------

/// **THE OLD `table_of`**, copied verbatim from
/// `git show 79f0726:hashline/src/private_block/argument.rs`, with its one
/// call to `priv_table` pointed at [`priv_table_walked`] — `s28_tests`' own
/// verbatim copy of the `79f0726` `priv_table` — so that no line of the code
/// under test appears in the oracle. It CLONES a public table, where the new
/// form moves it.
fn table_of_79f0726(tab: &Tab, n_vars: usize, pd: &ProverData) -> Vec<Fp2> {
    match tab {
        Tab::Eq { point, start } => {
            let e = eq_table_msb(point);
            let shift = n_vars - *start - point.len();
            (0..1usize << n_vars).map(|x| e[(x >> shift) & (e.len() - 1)]).collect()
        }
        Tab::Pub(v) => v.clone(),
        Tab::Priv(p) => priv_table_walked(p, pd.data[p.cm as usize], n_vars),
    }
}

/// **THE OLD TABLE SET**, likewise verbatim: one serial pass in table order.
fn build_tables_79f0726(tabs: &[Tab], n_vars: usize, pd: &ProverData) -> Vec<Vec<Fp2>> {
    tabs.iter().map(|t| table_of_79f0726(t, n_vars, pd)).collect()
}

/// A table set in the shape of a zero-check slot's: a challenge-weighted `eq`,
/// a public table, plain `A` planes, a short `A` plane that needs the
/// broadcast, an `H` pair with the `u` coefficient, and a plane with a fixed
/// coordinate. Built fresh on every call, because the production build MOVES
/// the public payload out of the definition.
fn tabs_case(n_vars: usize, count: usize, seed: u64) -> Vec<Tab> {
    let mut out: Vec<Tab> = Vec::new();
    out.push(Tab::Eq { point: (0..n_vars / 2).map(|i| fp2(seed + 7 + i as u64)).collect(), start: 0 });
    out.push(Tab::Pub(cube(1usize << n_vars, seed + 101)));
    out.push(Tab::Priv(Priv { cm: Cm::A, slices: vec![(0, Fp2::ONE)], log: n_vars, coords: (0..n_vars).map(Coord::Rho).collect(), mask_row: 0, ext_round: 0 }));
    out.push(Tab::Priv(Priv {
        cm: Cm::H,
        slices: vec![(0, Fp2::ONE), (1usize << n_vars, Fp2::U)],
        log: n_vars,
        coords: (0..n_vars).map(|k| Coord::Rho((k + 1) % n_vars)).collect(),
        mask_row: 0,
        ext_round: 0,
    }));
    out.push(Tab::Priv(Priv {
        cm: Cm::A,
        slices: vec![(3, Fp2::ONE)],
        log: n_vars - 1,
        coords: (0..n_vars - 1).map(Coord::Rho).collect(),
        mask_row: 0,
        ext_round: 0,
    }));
    let mut c: Vec<Coord> = (0..n_vars).map(Coord::Rho).collect();
    c[1] = Coord::Fixed(fp2(seed + 55));
    out.push(Tab::Priv(Priv { cm: Cm::A, slices: vec![(1, Fp2::ONE)], log: n_vars, coords: c, mask_row: 0, ext_round: 0 }));
    // pad with plain planes until the set is the requested size, so that
    // `tabs.len() << n_vars` can be driven across the production threshold
    let mut k = 0usize;
    while out.len() < count {
        out.push(Tab::Priv(Priv {
            cm: Cm::A,
            slices: vec![(k % 4, Fp2::ONE)],
            log: n_vars,
            coords: (0..n_vars).map(Coord::Rho).collect(),
            mask_row: 0,
            ext_round: 0,
        }));
        k += 1;
    }
    out.truncate(count.max(6));
    out
}

/// **THE EQUALITY GATE for the slot table build and for the MOVED PUBLIC
/// TABLE (S28-R1).** Both branches of the `tabs * 2^n >= 2^17` threshold, on
/// the same table set, against the `79f0726` serial build that CLONES the
/// public table — so the gate also says that moving the payload in instead of
/// copying it leaves the same words in the same table order.
#[test]
fn the_slot_table_set_is_the_79f0726_one_through_both_branches_of_its_threshold() {
    let mut crossed = (0usize, 0usize);
    // the last two sizes are above the production threshold (`tabs << n_vars`
    // of 163,840 and 262,144 against 131,072), the first three below it
    for (ci, (n_vars, count)) in [(4usize, 6usize), (9, 6), (12, 8), (14, 10), (15, 8)].into_iter().enumerate() {
        let seed = 4_000 + 17 * ci as u64;
        let a_data: Vec<Fp> = {
            let mut r = xs(seed);
            (0..(4usize << n_vars)).map(|_| fp(r())).collect()
        };
        let h_data: Vec<Fp> = {
            let mut r = xs(seed ^ 0xF0F0);
            (0..(4usize << n_vars)).map(|_| fp(r())).collect()
        };
        let masks = Vec::new();
        let pd = ProverData { data: [&a_data, &h_data, &a_data, &h_data], masks: &masks };
        let want = build_tables_79f0726(&tabs_case(n_vars, count, seed), n_vars, &pd);
        // FORCED SERIAL and FORCED PARALLEL on the same table set
        let mut serial_tabs = tabs_case(n_vars, count, seed);
        let serial = build_tables_at(&mut serial_tabs, n_vars, &pd, usize::MAX);
        let mut par_tabs = tabs_case(n_vars, count, seed);
        let parallel = build_tables_at(&mut par_tabs, n_vars, &pd, 0);
        assert_eq!(serial.len(), want.len(), "2^{n_vars} x {count}: the table count moved");
        for (i, (got, w)) in serial.iter().zip(want.iter()).enumerate() {
            assert_eq!(got, w, "2^{n_vars} x {count}: serial table {i} differs from the 79f0726 build");
        }
        for (i, (got, w)) in parallel.iter().zip(want.iter()).enumerate() {
            assert_eq!(got, w, "2^{n_vars} x {count}: parallel table {i} differs from the 79f0726 build");
        }
        // what the PRODUCTION constant does at this size, and which branch it is
        let mut prod_tabs = tabs_case(n_vars, count, seed);
        assert_eq!(build_tables_at(&mut prod_tabs, n_vars, &pd, TABLES_PAR_MIN), want, "2^{n_vars} x {count}: the production threshold left the 79f0726 build");
        if (count << n_vars) >= TABLES_PAR_MIN {
            crossed.1 += 1;
        } else {
            crossed.0 += 1;
        }
        // the public table really was MOVED on the new path and CLONED on the old
        let moved = matches!(&par_tabs[1], Tab::Pub(v) if v.is_empty());
        assert!(moved, "2^{n_vars} x {count}: the public payload was not moved out of the definition");
        // and the words of that table are the payload the definition carried
        assert_eq!(parallel[1], want[1], "2^{n_vars} x {count}: the moved public table is not the cloned one");
        // non-vacuity: at least the eq table and one private cube are not zero
        assert!(want[0].iter().any(|v| !v.is_zero()) && want[2].iter().any(|v| !v.is_zero()), "2^{n_vars}: the fixture is degenerate");
        // thread-count invariance of the parallel branch
        in_pools(&format!("the table build at 2^{n_vars} x {count}"), || {
            let mut t = tabs_case(n_vars, count, seed);
            build_tables_at(&mut t, n_vars, &pd, 0)
        });
    }
    assert!(crossed.0 >= 2 && crossed.1 >= 2, "the production threshold was crossed {crossed:?} (below, above)");
}

// ---------------------------------------------------------------------------
// 3. the looked columns and the byte histogram, on real witnesses
// ---------------------------------------------------------------------------

/// **THE OLD LOOKED COLUMNS**, verbatim from
/// `git show 79f0726:hashline/src/private_block/protocol.rs`.
fn lookup_values_79f0726(lay: &Layout, wit: &super::witness::Witness, dom: Dom) -> Vec<Vec<i64>> {
    let len = lay.shape().size(dom);
    lay.lookups(dom)
        .iter()
        .map(|l| (0..len).map(|x| l.terms.iter().fold(l.cst, |a, (p, c)| a.wrapping_add(c.wrapping_mul(wit.planes[*p][x])))).collect())
        .collect()
}

/// **THE OLD BYTE HISTOGRAM**, verbatim from the same file.
fn byte_histogram_79f0726(looked: &[(Dom, Vec<Vec<i64>>)]) -> Vec<u64> {
    let mut m_u8 = vec![0u64; U8_LEN];
    for (_, cols) in looked {
        for v in cols.iter().flatten() {
            // a value outside the table counts into entry 0: only the LogUp identity can catch it
            m_u8[if (0..U8_LEN as i64).contains(v) { *v as usize } else { 0 }] += 1;
        }
    }
    m_u8
}

/// **THE EQUALITY GATE for the looked columns (S28-R1, both branches).** The
/// same real witness through the forced-serial and the forced-parallel form
/// of `lookup_values_at`, both against the `79f0726` serial map, at a shape
/// below the production threshold (toy) and a shape above it (rung-K4).
#[test]
fn the_looked_columns_are_the_79f0726_serial_maps_through_both_branches() {
    let mut crossed = (0usize, 0usize);
    for sh in [Shape::toy(), Shape::rung_k4()] {
        let (public, ff, x) = super::grow_tests::tame_case(&sh);
        let blk = BlockPublic::new(public, ff);
        let w = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).expect("an honest witness at this shape");
        let lay = Layout::for_shape(&sh).expect("the layout of this shape");
        for dom in lay.lookup_doms().iter() {
            let want = lookup_values_79f0726(&lay, &w, *dom);
            assert_eq!(lookup_values_at(&lay, &w, *dom, usize::MAX), want, "{} {dom:?}: the forced-serial columns moved", sh.name);
            assert_eq!(lookup_values_at(&lay, &w, *dom, 0), want, "{} {dom:?}: the forced-parallel columns moved", sh.name);
            assert_eq!(lookup_values_at(&lay, &w, *dom, LOOKUP_PAR_MIN), want, "{} {dom:?}: the production threshold moved a column", sh.name);
            let words = lay.lookups(*dom).len() * lay.shape().size(*dom);
            if lay.lookups(*dom).len() > 1 && words >= LOOKUP_PAR_MIN {
                crossed.1 += 1;
            } else {
                crossed.0 += 1;
            }
            in_pools(&format!("{} {dom:?}", sh.name), || lookup_values_at(&lay, &w, *dom, 0));
        }
    }
    assert!(crossed.0 >= 4 && crossed.1 >= 1, "the production threshold was crossed {crossed:?} (below, above)");
}

/// **THE EQUALITY GATE for the byte histogram (S28-R1, both branches).** The
/// real looked columns of two shapes, and a synthetic set that carries the
/// out-of-table values only a tampered witness has, through the chunked form
/// and the serial form, both against the `79f0726` loop.
#[test]
fn the_byte_histogram_is_the_79f0726_serial_count_through_both_branches() {
    let mut crossed = (0usize, 0usize);
    for sh in [Shape::toy(), Shape::rung_k4()] {
        let (public, ff, x) = super::grow_tests::tame_case(&sh);
        let blk = BlockPublic::new(public, ff);
        let w = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).expect("an honest witness at this shape");
        let lay = Layout::for_shape(&sh).expect("the layout of this shape");
        let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, lookup_values_79f0726(&lay, &w, *d))).collect();
        let words: u64 = looked.iter().map(|(d, cols)| (cols.len() * lay.shape().size(*d)) as u64).sum();
        let want = byte_histogram_79f0726(&looked);
        assert_eq!(byte_histogram_at(&looked, words, u64::MAX), want, "{}: the forced-serial histogram moved", sh.name);
        assert_eq!(byte_histogram_at(&looked, words, 0), want, "{}: the chunked histogram moved", sh.name);
        assert_eq!(byte_histogram_at(&looked, words, HISTOGRAM_PAR_MIN), want, "{}: the production threshold moved the histogram", sh.name);
        assert_eq!(want.iter().sum::<u64>(), words, "{}: the histogram does not count every looked word", sh.name);
        if words >= HISTOGRAM_PAR_MIN {
            crossed.1 += 1;
        } else {
            crossed.0 += 1;
        }
        in_pools(&format!("the histogram at {}", sh.name), || byte_histogram_at(&looked, words, 0));
    }
    assert!(crossed.0 >= 1 && crossed.1 >= 1, "the production threshold was crossed {crossed:?} (below, above)");
    // the bucket-0 fallback, in both branches: values a tampered plane can
    // carry and no table row can serve
    let mut r = xs(77);
    let mut cols: Vec<Vec<i64>> = (0..3).map(|_| (0..(1usize << 16)).map(|_| (r() % U8_LEN as u64) as i64).collect()).collect();
    for (i, v) in [-1i64, 256, 1 << 40, i64::MIN, i64::MAX, -(1 << 30)].into_iter().enumerate() {
        cols[i % 3][i * 1_009 + 3] = v;
    }
    let looked = vec![(Dom::Tab, cols)];
    let words = 3 * (1u64 << 16);
    let want = byte_histogram_79f0726(&looked);
    assert_eq!(byte_histogram_at(&looked, words, u64::MAX), want, "the serial histogram moved on out-of-table values");
    assert_eq!(byte_histogram_at(&looked, words, 0), want, "the chunked histogram moved on out-of-table values");
    assert!(words >= HISTOGRAM_PAR_MIN, "the out-of-table fixture does not cross the production threshold");
}

// ---------------------------------------------------------------------------
// 4. the helper inverses — the SAME column through both branches
// ---------------------------------------------------------------------------

/// **THE OLD HELPER COLUMN**, re-derived from the field API: the whole column
/// of denominators handed to the checked batch inversion.
fn old_helper(col: &[i64], alpha: Fp2, g_u8: Fp2) -> Result<Vec<Fp2>, String> {
    let mut den: Vec<Fp2> = col.iter().map(|v| alpha.sub(Fp2::from_i64(*v).add(g_u8))).collect();
    batch_inverse2_checked(&mut den).map_err(|_| REFUSAL.to_string())?;
    Ok(den)
}

/// **THE EQUALITY GATE for the helper threshold (S28-R1, the same input
/// through both branches).** Stage 28's gates crossed this threshold by
/// changing the LENGTH of the column; this one holds the column fixed and
/// changes only the branch, accepted columns and refused ones, single and
/// paired.
#[test]
fn the_helper_columns_are_the_same_words_through_both_branches_of_their_threshold() {
    let (alpha, g_u8) = (fp2(31_337), fp2(2_909));
    let tbl = u8_denominator_inverses(alpha, g_u8);
    for len in [1usize, 255, 4_096, 1 << 14, 40_000] {
        let mut r = xs(len as u64 + 5);
        let a: Vec<i64> = (0..len).map(|_| (r() % U8_LEN as u64) as i64).collect();
        let b: Vec<i64> = (0..len).map(|_| (r() % U8_LEN as u64) as i64).collect();
        let want = old_helper(&a, alpha, g_u8).expect("random challenges do not hit a table value");
        assert_eq!(helper_inverses_u8_at(&a, alpha, g_u8, &tbl, usize::MAX).expect("forced serial"), want, "len={len}: the forced-serial helper moved");
        assert_eq!(helper_inverses_u8_at(&a, alpha, g_u8, &tbl, 0).expect("forced parallel"), want, "len={len}: the forced-parallel helper moved");
        assert_eq!(helper_inverses_u8_at(&a, alpha, g_u8, &tbl, HELPER_PAR_MIN).expect("production"), want, "len={len}: the production threshold moved the helper");
        let want_pair: Vec<Fp2> = want.iter().zip(old_helper(&b, alpha, g_u8).expect("column b").iter()).map(|(x, y)| x.add(*y)).collect();
        for par_min in [usize::MAX, 0, HELPER_PAR_MIN] {
            assert_eq!(helper_pair_inverses_u8_at(&a, &b, alpha, g_u8, &tbl, par_min).expect("the paired helper"), want_pair, "len={len}, par_min={par_min}: the paired helper moved");
        }
    }
    // the refusal, through both branches of both forms, at one length
    let v0 = 200i64;
    let alpha0 = Fp2::from_i64(v0).add(g_u8);
    let tbl0 = u8_denominator_inverses(alpha0, g_u8);
    let mut r = xs(4_242);
    let mut a: Vec<i64> = (0..4_096).map(|_| (r() % U8_LEN as u64) as i64).collect();
    a.iter_mut().for_each(|v| {
        if *v == v0 {
            *v = 0
        }
    });
    let b = a.clone();
    a[1_000] = v0;
    assert_eq!(old_helper(&a, alpha0, g_u8), Err(REFUSAL.to_string()), "the old form did not refuse");
    for par_min in [usize::MAX, 0, HELPER_PAR_MIN] {
        assert_eq!(helper_inverses_u8_at(&a, alpha0, g_u8, &tbl0, par_min), Err(REFUSAL.to_string()), "par_min={par_min}: the single helper did not refuse");
        assert_eq!(helper_pair_inverses_u8_at(&a, &b, alpha0, g_u8, &tbl0, par_min), Err(REFUSAL.to_string()), "par_min={par_min}: the paired helper did not refuse on column a");
        assert_eq!(helper_pair_inverses_u8_at(&b, &a, alpha0, g_u8, &tbl0, par_min), Err(REFUSAL.to_string()), "par_min={par_min}: the paired helper did not refuse on column b");
        assert!(helper_pair_inverses_u8_at(&b, &b, alpha0, g_u8, &tbl0, par_min).is_ok(), "par_min={par_min}: a pair that carries no zero denominator was refused");
    }
}

// ---------------------------------------------------------------------------
// 5. `eq_cube`'s precondition (S28-R7)
// ---------------------------------------------------------------------------

/// **THE AGREEMENT GATE on every ADMITTED triple (S28-R7).** Every
/// `(n_vars <= 13, |point|, start)` with `start + |point| <= n_vars` — the
/// review's 560 — through the doubling build and the `79f0726` gather. Where
/// the precondition holds the two forms are the same cube; where it does not,
/// the test below says the new form panics instead of diverging silently.
#[test]
fn the_eq_cube_agrees_with_the_79f0726_gather_on_every_admitted_triple() {
    let mut cases = 0usize;
    for n_vars in 0..=13usize {
        for plen in 0..=n_vars {
            for start in 0..=(n_vars - plen) {
                let point: Vec<Fp2> = (0..plen).map(|i| fp2(1_000 + 13 * i as u64 + n_vars as u64)).collect();
                let e = eq_table_msb(&point);
                assert_eq!(
                    eq_cube(&e, n_vars, start),
                    eq_cube_gathered(&e, n_vars, start),
                    "the admitted triple (n_vars {n_vars}, |point| {plen}, start {start}) built two different cubes"
                );
                cases += 1;
            }
        }
    }
    assert_eq!(cases, 560, "the gate ran {cases} triples, not the review's 560");
}

/// **THE PRECONDITION IS NOW LOUD (S28-R7).** `start + |point| > n_vars` is
/// unreachable from the schedule — the triple is public and shape-driven —
/// but on it the doubling build and the old gather DIVERGE, so the build
/// refuses to compute rather than return a cube nobody checked.
#[test]
#[should_panic(expected = "eq_cube precondition start + |point| <= n_vars violated")]
fn a_violated_eq_cube_precondition_panics_by_name() {
    let point: Vec<Fp2> = (0..3).map(|i| fp2(70 + i as u64)).collect();
    let e = eq_table_msb(&point);
    // |point| = 3 and start = 2 need five variables; this cube has four
    let _ = eq_cube(&e, 4, 2);
}

/// The same for the other way to violate it: a point wider than the cube.
#[test]
#[should_panic(expected = "eq_cube precondition start + |point| <= n_vars violated")]
fn an_eq_point_wider_than_the_cube_panics_by_name() {
    let point: Vec<Fp2> = (0..5).map(|i| fp2(80 + i as u64)).collect();
    let e = eq_table_msb(&point);
    let _ = eq_cube(&e, 3, 0);
}
