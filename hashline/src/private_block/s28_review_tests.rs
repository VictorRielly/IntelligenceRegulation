//! **INDEPENDENT ADVERSARIAL REVIEW OF STAGE 28 — test-only.**
//!
//! This file is written by a reviewer who did not write stage 28 and who
//! trusts neither the stage's ledger section nor `s28_tests.rs`. It re-derives
//! the equalities stage 28 claims, on inputs the stage's own gates do not
//! reach: randomised plane descriptors rather than seven hand-written ones,
//! the refusal branch that the stage's gates never take (an out-of-table value
//! whose denominator is zero), every thread count on every parallel path, and
//! a census of which of the stage's five parallel thresholds any non-ignored
//! test actually crosses.
//!
//! The old forms below are copied VERBATIM from the base commit `79f0726`
//! (`git show 79f0726:hashline/src/private_block/argument.rs`) by this
//! reviewer, independently of the copies in `s28_tests.rs`.
//!
//! Report: `docs/zkmatrix-poc/ZK60_BLOCK125M_S28_REVIEW.md`.

use super::argument::{eq_cube, priv_table, table_values_exp_at, table_values_u8_at, Cm, Coord, Priv};
use super::layout::{Dom, Layout, U8_LEN};
use super::protocol::{helper_inverses_u8, helper_pair_inverses_u8, lookup_values, u8_denominator_inverses};
use super::shape::Shape;
use crate::field::{batch_inverse2_checked, Fp, Fp2, P};
use crate::mle::eq_table_msb;

/// the one refusal string of every LogUp denominator on this path
const REFUSAL: &str = "zero LogUp denominator; discard attempt";

/// SplitMix64 — this reviewer's own stream, not the stage's xorshift.
struct R(u64);
impl R {
    fn new(seed: u64) -> R {
        R(seed ^ 0x9E37_79B9_7F4A_7C15)
    }
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
    fn fp(&mut self) -> Fp {
        Fp::new(self.next() % P)
    }
    fn fp2(&mut self) -> Fp2 {
        Fp2::new(self.fp(), self.fp())
    }
}

// ===========================================================================
// R-A. `priv_table`: the walked builder against the bit-permutation builder,
//      on RANDOMISED descriptors.
// ===========================================================================

/// **THE OLD `priv_table`, VERBATIM FROM `79f0726`** (this reviewer's own
/// copy). It is the oracle: it shares no line with the code under test.
fn walked_79f0726(p: &Priv, data: &[Fp], n_vars: usize) -> Vec<Fp2> {
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

/// A random descriptor that respects the ONE invariant `run_slot` enforces
/// before `priv_table` is ever called (`coords.len() == log`, checked at
/// `argument.rs`'s "slot {s} table shape" refusal) and nothing else: indices
/// may repeat, `Flip` and `Rho` may share an index, the plane may be shorter
/// than the cube, the coefficient may or may not be one.
fn random_priv(r: &mut R, n_vars: usize) -> (Priv, &'static str) {
    let log = r.below(n_vars + 1);
    let mut coords: Vec<Coord> = Vec::with_capacity(log);
    let mut shape = "generic";
    // a random injective assignment of challenge indices, then a chance of
    // breaking the injectivity on purpose
    let mut idxs: Vec<usize> = (0..n_vars).collect();
    for i in (1..idxs.len()).rev() {
        idxs.swap(i, r.below(i + 1));
    }
    for j in 0..log {
        let k = idxs[j % n_vars.max(1)];
        match r.below(8) {
            0 | 1 if n_vars > 0 => coords.push(Coord::Flip(k)),
            2 => coords.push(Coord::Fixed(r.fp2())),
            _ if n_vars > 0 => coords.push(Coord::Rho(k)),
            _ => coords.push(Coord::Fixed(r.fp2())),
        }
    }
    // 1 case in 6: duplicate one index (the plain-store path MUST NOT be taken)
    if log >= 2 && r.below(6) == 0 {
        let (a, b) = (r.below(log), r.below(log));
        if a != b {
            if let Some(k) = match &coords[a] {
                Coord::Rho(k) | Coord::Flip(k) => Some(*k),
                Coord::Fixed(_) => None,
            } {
                coords[b] = if r.below(2) == 0 { Coord::Rho(k) } else { Coord::Flip(k) };
                shape = "duplicated index";
            }
        }
    }
    let slices = match r.below(4) {
        0 => vec![(r.below(1 << n_vars), Fp2::ONE)],
        1 => vec![(r.below(1 << n_vars), r.fp2())],
        2 => vec![(r.below(1 << n_vars), Fp2::ONE), (r.below(1 << n_vars), Fp2::U)],
        _ => vec![(r.below(1 << n_vars), r.fp2()), (r.below(1 << n_vars), r.fp2()), (r.below(1 << n_vars), Fp2::ONE)],
    };
    (Priv { cm: Cm::A, slices, log, coords, mask_row: 0, ext_round: 0 }, shape)
}

/// **S28-R review gate 1.** Six hundred randomised descriptors at eight cube
/// widths, against the walked builder of `79f0726`, entry for entry. Covers
/// what the stage's own 21 hand-written cases do not: `log = 0`, `n_vars = 0`,
/// every mixture of fixed / flipped / repeated coordinates, three-slice
/// planes, and data that is all zero, constant, or generic.
#[test]
fn the_private_table_builder_agrees_with_79f0726_on_randomised_descriptors() {
    let mut cases = 0usize;
    let mut with_dup = 0usize;
    let mut with_fixed = 0usize;
    let mut short = 0usize;
    for n_vars in [0usize, 1, 2, 3, 5, 7, 9, 10] {
        for seed in 0..75u64 {
            let mut r = R::new(seed.wrapping_mul(1_000_003).wrapping_add(n_vars as u64 * 7 + 1));
            let (p, shape) = random_priv(&mut r, n_vars);
            // three data flavours: generic, all-zero (the degenerate witness),
            // and constant (every word the same, so a collision is invisible
            // unless the ADD really happens)
            for flavour in 0..3 {
                let len = 8usize << n_vars;
                let data: Vec<Fp> = match flavour {
                    0 => (0..len).map(|_| r.fp()).collect(),
                    1 => vec![Fp::ZERO; len],
                    _ => vec![Fp::new(7); len],
                };
                let old = walked_79f0726(&p, &data, n_vars);
                let new = priv_table(&p, &data, n_vars);
                assert_eq!(old.len(), new.len(), "n_vars={n_vars} seed={seed} flavour={flavour}: the cube length moved");
                for (x, (a, b)) in old.iter().zip(new.iter()).enumerate() {
                    assert_eq!(a, b, "n_vars={n_vars} seed={seed} flavour={flavour} shape={shape}: entry {x} differs (log={}, coords={})", p.log, p.coords.len());
                }
                cases += 1;
            }
            if shape == "duplicated index" {
                with_dup += 1;
            }
            if p.coords.iter().any(|c| matches!(c, Coord::Fixed(_))) {
                with_fixed += 1;
            }
            if p.log < n_vars {
                short += 1;
            }
        }
    }
    eprintln!("S28-REVIEW priv_table: {cases} comparisons, {with_dup} duplicated-index descriptors, {with_fixed} with fixed coordinates, {short} short planes");
    assert!(cases >= 1_800, "only {cases} comparisons");
    assert!(with_dup >= 10, "only {with_dup} duplicated-index descriptors: the collision fallback is barely covered");
    assert!(with_fixed >= 100, "only {with_fixed} descriptors with a fixed coordinate");
    assert!(short >= 100, "only {short} short planes: the broadcast pass is barely covered");
}

// ===========================================================================
// R-B. `eq_cube`, including the degenerate widths.
// ===========================================================================

/// **THE OLD `eq` cube gather, VERBATIM FROM `79f0726`** (inline in
/// `table_of`'s `Tab::Eq` arm there).
/// It takes the POINT, not the `eq` table, because that is what the old arm
/// had in hand: its shift is `n_vars - start - point.len()`, where the new
/// form uses `e.len().trailing_zeros()`. Reading the shift from the point is
/// what makes this an oracle for that substitution too.
fn eq_cube_79f0726(point: &[Fp2], n_vars: usize, start: usize) -> Vec<Fp2> {
    let e = eq_table_msb(point);
    let shift = n_vars - start - point.len();
    (0..1usize << n_vars).map(|x| e[(x >> shift) & (e.len() - 1)]).collect()
}

/// **S28-R review gate 2.** Every `(n_vars, |point|, start)` triple from the
/// empty cube up to 2^13, with random points, against the gather of
/// `79f0726`.
#[test]
fn the_eq_cube_agrees_with_79f0726_at_every_width_including_the_degenerate_ones() {
    let mut r = R::new(0xEEE);
    let mut cases = 0usize;
    for n_vars in 0..=13usize {
        for plen in 0..=n_vars {
            for start in 0..=(n_vars - plen) {
                let point: Vec<Fp2> = (0..plen).map(|_| r.fp2()).collect();
                let e = eq_table_msb(&point);
                let old = eq_cube_79f0726(&point, n_vars, start);
                let new = eq_cube(&e, n_vars, start);
                assert_eq!(old, new, "eq cube at 2^{n_vars}, |point|={plen}, start={start}");
                assert_eq!(new.len(), 1usize << n_vars, "eq cube length at 2^{n_vars}");
                cases += 1;
            }
        }
    }
    eprintln!("S28-REVIEW eq_cube: {cases} (width, |point|, start) triples");
    assert!(cases >= 100, "only {cases} triples");
}

// ===========================================================================
// R-C / R-D. The LogUp helper inverses: the old path, every thread count, and
//            the refusal branch the stage's gates never take.
// ===========================================================================

/// the old helper column, re-derived from the field API exactly as
/// `protocol::inverses` does it
fn old_helper(col: &[i64], alpha: Fp2, g_u8: Fp2) -> Result<Vec<Fp2>, String> {
    let mut den: Vec<Fp2> = col.iter().map(|v| alpha.sub(Fp2::from_i64(*v).add(g_u8))).collect();
    batch_inverse2_checked(&mut den).map_err(|_| REFUSAL.to_string())?;
    Ok(den)
}

fn new_helper(col: &[i64], alpha: Fp2, g_u8: Fp2) -> Result<Vec<Fp2>, String> {
    helper_inverses_u8(col, alpha, g_u8, &u8_denominator_inverses(alpha, g_u8))
}

/// **S28-R review gate 3 — THE BRANCH THE STAGE'S GATES NEVER TAKE.** A
/// witness value OUTSIDE the byte table whose denominator is zero. The stage
/// tests out-of-range values only where no denominator vanishes
/// (`the_table_path_agrees_on_columns_that_carry_values_outside_the_byte_table`
/// asserts `Ok` on both sides), so the `Err` arm of the fallback in
/// `helper_inverses_u8` / `helper_pair_inverses_u8` is never exercised there.
/// Both paths must refuse, with the same string, on both sides of the
/// parallel threshold.
#[test]
fn an_out_of_table_value_whose_denominator_is_zero_is_refused_by_both_paths() {
    let g_u8 = Fp2::new(Fp::new(0x1234_5678_9ABC), Fp::new(7));
    for v0 in [256i64, 300, 65_536, -1, -257, 1 << 40, i64::MIN, i64::MAX] {
        let alpha = Fp2::from_i64(v0).add(g_u8);
        // the 256-entry table itself is sound: no byte value's denominator is zero
        let tbl = u8_denominator_inverses(alpha, g_u8);
        assert_eq!(tbl.iter().filter(|e| e.is_none()).count(), 0, "v0={v0}: an out-of-table value collided with a table entry");
        for len in [1usize, 4_096, 40_000] {
            let mut col: Vec<i64> = (0..len).map(|i| (i % 200) as i64).collect();
            col[len / 2] = v0;
            assert_eq!(old_helper(&col, alpha, g_u8), Err(REFUSAL.to_string()), "v0={v0} len={len}: the OLD path did not refuse");
            assert_eq!(new_helper(&col, alpha, g_u8), Err(REFUSAL.to_string()), "v0={v0} len={len}: the NEW path did not refuse");
            // and in a pair, in either column
            let clean: Vec<i64> = (0..len).map(|i| (i % 199) as i64).collect();
            assert_eq!(helper_pair_inverses_u8(&col, &clean, alpha, g_u8, &tbl), Err(REFUSAL.to_string()), "v0={v0} len={len}: the paired path did not refuse in column a");
            assert_eq!(helper_pair_inverses_u8(&clean, &col, alpha, g_u8, &tbl), Err(REFUSAL.to_string()), "v0={v0} len={len}: the paired path did not refuse in column b");
            // with the value absent, both accept and agree word for word
            assert_eq!(new_helper(&clean, alpha, g_u8).expect("new"), old_helper(&clean, alpha, g_u8).expect("old"), "v0={v0} len={len}");
        }
    }
}

/// **S28-R review gate 4 — every parallel path under one, two and eight
/// threads**, both the accepted vector and the refusal. The stage checks the
/// thread count on ONE function (`helper_inverses_u8`) and one column.
#[test]
fn every_helper_path_gives_the_same_words_and_the_same_refusal_under_one_two_and_eight_threads() {
    let mut r = R::new(0xC0DE);
    let (alpha, g_u8) = (r.fp2(), r.fp2());
    let a: Vec<i64> = (0..70_000).map(|_| r.below(U8_LEN) as i64).collect();
    let b: Vec<i64> = (0..70_000).map(|_| r.below(U8_LEN) as i64).collect();
    let want_a = old_helper(&a, alpha, g_u8).expect("column a");
    let want_pair: Vec<Fp2> = want_a.iter().zip(old_helper(&b, alpha, g_u8).expect("column b").iter()).map(|(x, y)| x.add(*y)).collect();
    // a refusing case: a zero denominator at a byte the column carries, in a
    // column that ALSO carries an out-of-table word, so the refusing pass and
    // the fallback pass run over the same column
    let v_in = a[17];
    let alpha0 = Fp2::from_i64(v_in).add(g_u8);
    let mut mixed = a.clone();
    mixed[50_000] = 1 << 33;
    for threads in [1usize, 2, 8] {
        let pool = rayon::ThreadPoolBuilder::new().num_threads(threads).build().expect("a rayon pool");
        pool.install(|| {
            let tbl = u8_denominator_inverses(alpha, g_u8);
            assert_eq!(helper_inverses_u8(&a, alpha, g_u8, &tbl).expect("single"), want_a, "{threads} threads: the single-column helper moved");
            assert_eq!(helper_pair_inverses_u8(&a, &b, alpha, g_u8, &tbl).expect("pair"), want_pair, "{threads} threads: the paired helper moved");
            let tbl0 = u8_denominator_inverses(alpha0, g_u8);
            assert_eq!(helper_inverses_u8(&mixed, alpha0, g_u8, &tbl0), Err(REFUSAL.to_string()), "{threads} threads: the refusal changed");
            assert_eq!(helper_pair_inverses_u8(&mixed, &b, alpha0, g_u8, &tbl0), Err(REFUSAL.to_string()), "{threads} threads: the paired refusal changed");
        });
    }
}

/// **S28-R review gate 5 — `lookup_values` under one, two and eight
/// threads**, on real witnesses, against the serial map. The stage's gate runs
/// the ambient pool only.
#[test]
fn the_looked_columns_are_the_serial_maps_under_every_thread_count() {
    use super::BlockPublic;
    let mut domains = 0usize;
    for sh in [Shape::toy(), Shape::rung_k4()] {
        let (public, ff, x) = super::grow_tests::tame_case(&sh);
        let blk = BlockPublic::new(public, ff);
        let w = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &x).expect("an honest witness");
        let lay = Layout::for_shape(&sh).expect("a layout");
        for dom in lay.lookup_doms() {
            let len = lay.shape().size(*dom);
            let want: Vec<Vec<i64>> = lay
                .lookups(*dom)
                .iter()
                .map(|l| (0..len).map(|x| l.terms.iter().fold(l.cst, |a, (p, c)| a.wrapping_add(c.wrapping_mul(w.planes[*p][x])))).collect())
                .collect();
            for threads in [1usize, 2, 8] {
                let pool = rayon::ThreadPoolBuilder::new().num_threads(threads).build().expect("a rayon pool");
                let got = pool.install(|| lookup_values(&lay, &w, *dom));
                assert_eq!(got, want, "{}: {dom:?} moved under {threads} threads", sh.name);
            }
            domains += 1;
        }
    }
    assert!(domains >= 12, "only {domains} domains");
}

// ===========================================================================
// R-E. FINDING S28-F1 examined on the real arithmetic.
// ===========================================================================

/// **S28-R review gate 6 — S28-F1 IS TRUE IN ITS FIRST HALF AND FALSE IN ITS
/// SECOND.**
///
/// True: a zero denominator AT A TABLE VALUE refuses the attempt whatever the
/// hidden input carries, because the three table helpers invert every table
/// value a few lines later.
///
/// False: "whether an attempt is refused is therefore a function of the public
/// challenges and the public table alone". A dishonest or tampered witness can
/// carry a value that is NOT in the table, and then the zero denominator
/// exists only where the witness put it: the three table helpers accept and
/// the attempt is refused if and only if the hidden column carries that value.
/// This test exhibits the counterexample for the byte family and for the
/// exponential pair family.
#[test]
fn whether_an_attempt_is_refused_still_depends_on_the_hidden_input_for_off_table_values() {
    // ---- the byte family
    let g_u8 = Fp2::new(Fp::new(918_273_645), Fp::new(11));
    let v_off = 4_096i64; // a byte column of a tampered witness can carry this
    let alpha = Fp2::from_i64(v_off).add(g_u8);
    // the PUBLIC side accepts: no table value's denominator is zero, at any
    // padded table length the shapes use
    for tab_len in [U8_LEN, 2 * U8_LEN, 8 * U8_LEN, 64 * U8_LEN] {
        let mut den: Vec<Fp2> = table_values_u8_at(tab_len, g_u8).iter().map(|t| alpha.sub(*t)).collect();
        assert!(batch_inverse2_checked(&mut den).is_ok(), "tab_len={tab_len}: the table helper refused, so this is not a counterexample");
    }
    // the HIDDEN side decides: carrying the value refuses, not carrying it does not
    let carrying: Vec<i64> = vec![0, 1, 2, v_off, 4];
    let not_carrying: Vec<i64> = vec![0, 1, 2, 3, 4];
    assert_eq!(new_helper(&carrying, alpha, g_u8), Err(REFUSAL.to_string()), "the hidden value did not refuse");
    assert!(new_helper(&not_carrying, alpha, g_u8).is_ok(), "the attempt was refused although nothing carries the value");
    // and the old path agrees on both, so this is not a stage-28 regression
    assert_eq!(old_helper(&carrying, alpha, g_u8), Err(REFUSAL.to_string()));
    assert!(old_helper(&not_carrying, alpha, g_u8).is_ok());

    // ---- the exponential pair family: the same, on the real public table
    let sh = Shape::toy();
    let (public, _ff, _x) = super::grow_tests::tame_case(&sh);
    let (beta, g_exp) = (Fp2::new(Fp::new(31_337), Fp::new(5)), Fp2::new(Fp::new(4_242), Fp::new(9)));
    // a pair (d, e) the table does NOT carry: d = 3 with e = exp[3] + 1
    let d = 3i64;
    let e = public.exp[3] + 1;
    let alpha_e = Fp2::from_i64(d).add(beta.mul(Fp2::from_i64(e))).add(g_exp);
    // the PUBLIC exponential table helper accepts at every padded length
    for tab_len in [U8_LEN, 4 * U8_LEN] {
        let mut den: Vec<Fp2> = table_values_exp_at(tab_len, &public, beta, g_exp).iter().map(|t| alpha_e.sub(*t)).collect();
        assert!(batch_inverse2_checked(&mut den).is_ok(), "tab_len={tab_len}: the exponential table helper refuses, so the pair is on the table after all");
    }
    // while the prover's own `inverses(exp_den)?` line refuses as soon as the
    // hidden column carries that (delta, e) pair, and not otherwise
    let mut carried: Vec<Fp2> = vec![alpha_e.sub(Fp2::from_i64(d).add(beta.mul(Fp2::from_i64(e))).add(g_exp))];
    assert!(batch_inverse2_checked(&mut carried).is_err(), "the exponential pair the witness carries is not a zero denominator");
    let mut absent: Vec<Fp2> = vec![alpha_e.sub(Fp2::from_i64(1).add(beta.mul(Fp2::from_i64(public.exp[1]))).add(g_exp))];
    assert!(batch_inverse2_checked(&mut absent).is_ok(), "an honest exponential pair was refused");
    eprintln!("S28-REVIEW S28-F1: the 'public challenges and public table alone' half is FALSE for off-table witness values (byte family and exponential pair family both exhibited)");
}

// ===========================================================================
// R-F. Which of stage 28's five parallel thresholds any shape crosses.
// ===========================================================================

/// **S28-R review gate 7 — THE THRESHOLD CENSUS.** Stage 28 adds five
/// `if size >= threshold { rayon } else { serial }` switches. A gate that
/// never crosses a threshold never tests the parallel branch. This prints, for
/// every shape the lane defines, which branch each switch takes, and pins the
/// answer so that a later shape change cannot silently move a branch out of
/// the suite's reach.
///
/// The table-build switch (`def.tabs.len() * 2^n >= 2^17`) is reported as a
/// LOWER BOUND: the slot's table count is at least its private-term count, and
/// the definitions are built inside `argument()`, not exposed.
#[test]
fn the_census_of_which_shape_crosses_which_stage_28_parallel_threshold() {
    let mut lines: Vec<String> = Vec::new();
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::m125()] {
        let lay = Layout::for_shape(&sh).expect("a layout");
        let mut lookup_words = 0u64;
        let mut lookup_par = false; // lookup_values: cols * len >= 2^17
        let mut helper_par = false; // helper_inverses_u8: col.len() >= 2^14
        for dom in lay.lookup_doms() {
            let len = lay.shape().size(*dom);
            let cols = lay.lookups(*dom).len();
            lookup_words += (cols * len) as u64;
            lookup_par |= cols > 1 && cols * len >= 1 << 17;
            helper_par |= len >= 1 << 14;
        }
        let hist_par = lookup_words >= 1 << 17;
        let mut tables_par = false; // LOWER BOUND on tabs
        let mut total_par = false; // total: 2^n > 2^14
        let slots = sh.slots();
        let terms_of = sh.slot_terms();
        for (s, (n, _e, _d)) in slots.iter().enumerate() {
            let terms = terms_of[s];
            tables_par |= terms > 1 && (terms << n) >= 1 << 17;
            total_par |= (1usize << n) > 1 << 14;
        }
        lines.push(format!(
            "{:<58} lookup_words {:>12} | histogram {:>5} | lookup_values {:>5} | helper inverses {:>5} | slot tables >= {:>5} | total {:>5}",
            sh.name, lookup_words, hist_par, lookup_par, helper_par, tables_par, total_par
        ));
        if sh.name.starts_with("125M") {
            assert!(hist_par && lookup_par && helper_par && tables_par && total_par, "125M no longer crosses every stage-28 threshold: {}", lines[lines.len() - 1]);
        }
    }
    for l in &lines {
        eprintln!("S28-REVIEW threshold census: {l}");
    }
}

// ===========================================================================
// R-G. The field property the parallel claimed sum rests on (`total` itself is
//      private to `argument`, so it cannot be called from here).
// ===========================================================================

/// **S28-R review gate 8.** `total` is parallelised with a rayon `reduce` over
/// 1,024-entry chunks, and it has NO old-against-new equality gate: the stage
/// argues instead that field addition is exact. The argument needs two things
/// that this test checks on the real `Fp2`: addition is associative and
/// commutative, and the REPRESENTATION is canonical, so that two groupings of
/// the same terms are equal as WORDS and not merely as field elements (the
/// transcript absorbs words).
#[test]
fn field_addition_is_associative_commutative_and_canonical_so_a_chunked_sum_is_the_same_word() {
    let mut r = R::new(0xADD5);
    for case in 0..200 {
        let n = 1 + r.below(3_000);
        let v: Vec<Fp2> = (0..n).map(|_| r.fp2()).collect();
        let serial = v.iter().fold(Fp2::ZERO, |a, b| a.add(*b));
        // the chunked reduction stage 28 performs, at several chunk widths
        for chunk in [1usize, 7, 1_024, 4_096] {
            let parts: Vec<Fp2> = v.chunks(chunk).map(|c| c.iter().fold(Fp2::ZERO, |a, b| a.add(*b))).collect();
            let reduced = parts.iter().fold(Fp2::ZERO, |a, b| a.add(*b));
            assert_eq!(reduced.c0.0, serial.c0.0, "case {case} chunk {chunk}: the chunked sum is a different WORD (c0)");
            assert_eq!(reduced.c1.0, serial.c1.0, "case {case} chunk {chunk}: the chunked sum is a different WORD (c1)");
            // and in the reverse order, which a work-stealing reduce may take
            let rev = parts.iter().rev().fold(Fp2::ZERO, |a, b| a.add(*b));
            assert_eq!(rev, serial, "case {case} chunk {chunk}: the reduction order moved the sum");
        }
        // canonical: every limb this arithmetic produces is below p
        assert!(serial.c0.0 < P && serial.c1.0 < P, "case {case}: a non-canonical limb");
    }
}

// ===========================================================================
// R-H. CROSS-VERSION: a run directory written by the PRE-stage-28 prover,
//      verified by the stage-28 verifier.
// ===========================================================================

/// **S28-R review gate 9 — old prover, new verifier, at the 125M shape.**
/// Ignored by default and driven by `HL_PB_S28_REVIEW_RUN_DIR`: the directory
/// holds the segments and `statement/run-statement.json` of a complete run
/// written before stage 28. `run_statement_file::verify_from_disk` rebuilds
/// the public statement from the file, regenerates the public weights from the
/// recipe, checks every segment's length and SHA-256, and verifies the whole
/// run in a fresh `RunVerifier`.
///
/// If the stage-28 verifier accepted anything the old one did not, or computed
/// one field element differently anywhere on the verifying path, this fails.
#[test]
#[ignore = "S28 review: needs HL_PB_S28_REVIEW_RUN_DIR and about 10 minutes"]
fn a_run_directory_written_before_stage_28_verifies_under_the_stage_28_verifier() {
    let dir = std::env::var("HL_PB_S28_REVIEW_RUN_DIR").expect("set HL_PB_S28_REVIEW_RUN_DIR to a run directory written before stage 28");
    let p = std::path::PathBuf::from(&dir);
    let t = std::time::Instant::now();
    super::run_statement_file::verify_from_disk(&p).unwrap_or_else(|e| panic!("a run written before stage 28 no longer verifies under the stage-28 verifier: {e}"));
    eprintln!("S28-REVIEW cross-version: {dir} VERIFIES under the stage-28 verifier in {:.2} s", t.elapsed().as_secs_f64());
}
