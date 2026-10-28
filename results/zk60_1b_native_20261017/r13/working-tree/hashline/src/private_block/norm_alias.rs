//! THE HALF-p ISQRT ALIAS (security obligation R09) AGAINST THE PRIVATE BLOCK.
//!
//! WHAT R09 IS. In the PUBLIC-IO attention prover (`attention.rs`, `norm.rs`)
//! the RMS-norm denominator `D = isqrt(sum x^2 + Ceps)` is never range-proved
//! directly: it is pinned only through `a2 = 2D - a1` and `SSe = a1 + D^2`.
//! Over `p = 2^64 - 2^32 + 1` (p = 1 mod 4) that leaves an ALIAS. Whenever
//! `a1 + a2` is odd, `D = k + (p-1)/2` satisfies every isqrt relation, the
//! square check and the limb ranges for EVERY input row, and satisfies the
//! division relation with an ALL-ZERO norm output. That profile excludes it
//! only because the alias remainders (~2^42) do not fit two 16-bit limbs;
//! at three or more remainder limbs the verifier ACCEPTS a wrong norm output
//! (`ZK60_FABLE_SECURITY_OBLIGATIONS.md`, R09 and R10).
//!
//! WHY THIS MODULE IS DIFFERENT, AND WHAT THESE CASES MEASURE. This module
//! encodes `d`, `a1` and `a2` as THREE BYTE LIMBS EACH in one packed
//! `Dom::L` plane and pins the reconstruction with its own zero-check term:
//!
//!   (R1) dsq = d * d                                argument.rs:587 `mu[0]`
//!   (R2) d   = l0 + 256 l1 + 65536 l2               argument.rs:587 `mu[1]`
//!   (R3) 2d  = a1 + a2                              argument.rs:587 `mu[2]`
//!   (R4) dsq + a1 - Ceps = SS(r_t)                  argument.rs:591 `nu[0]`
//!
//! with every limb looked up in the 256-entry U8 table (`byte(A_LIMB)`,
//! `byte(A_LIMBM)`, layout.rs:314-315) through `SC_LZC`. (R2) is the range
//! fact `attention.rs` lacks: it forces `d` into `[0, 2^24)` over the
//! integers, and `(p-1)/2 = 2^63 - 2^31` is not in `[0, 2^24)`.
//!
//! So the alias must break something, and the two cases below measure WHICH,
//! in the two forms available to a prover. Both were PREDICTED from
//! `argument.rs` before they were run, and the prediction is recorded in each
//! case's own comment:
//!
//!  * limbs left honest -> `d - dl` is false and NOTHING else in the slot is:
//!    `Catch::Slot(SC_TZC)`, the (R2) pin itself.
//!  * limbs made to RECONSTRUCT the alias (`l0 = d`, `l1 = l2 = 0`) -> every
//!    relation of every slot holds in `F_p`, and the only thing left false is
//!    that `l0` has no row in the U8 table: `Catch::LogUp`.
//!
//! The catch MOVING from `SC_TZC` to the LogUp sum claim between the two is
//! the evidence that (R2) is present and load-bearing rather than decorative.
//!
//! NOT A WIDTH COINCIDENCE, and this is the whole point of the lane: the
//! remainder window does NOT do the work here. `2^tn d = 2^(tn-1)(2k-1)` is a
//! SMALL integer for small `k`, so the alias is an exact division by
//! `2^(tn+1)(k - 1/2)` whose remainders sit inside the honest `[0, 2^29)`
//! window (`results/zk60_private_norm_range/alias_arithmetic.txt`, section 3).
//! Each case therefore leaves the quotient `y` HONEST and re-derives `rho`
//! and `sigma` from (C0) and (C1), so that nothing downstream of the norm
//! changes and the norm's own range facts are the only thing on trial.
//!
//! Every fixture is the PUBLIC SYNTHETIC one; no witness value is printed.
//! These are SOUNDNESS cases: nothing here claims a privacy property.

use super::layout::*;
use super::protocol::{prove_inner, verify_inner};
use super::witness::{self, Witness};
use super::*;
use crate::field::{Fp, P};

fn spec() -> IoSpec {
    IoSpec::new(*blake3::hash(b"private block: half-p isqrt alias context").as_bytes(), 0, 0).unwrap()
}

/// where the verifier must catch a tamper (the harness of `tamper.rs`, whose
/// helpers are private to that file)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Catch {
    /// `sumcheck::verify` rejects inside that slot's claimed sum
    Slot(usize),
    /// the ONE value-0 LogUp sum claim, carried by the `H` opening
    LogUp,
}

impl Catch {
    fn matches(self, err: &str) -> bool {
        match self {
            Catch::Slot(s) => err.starts_with(&format!("slot {s} [")),
            Catch::LogUp => err.starts_with("H: "),
        }
    }
    fn describe(self) -> String {
        match self {
            Catch::Slot(s) => format!("slot {s}"),
            Catch::LogUp => "the value-0 LogUp sum claim on H".to_string(),
        }
    }
}

/// One attempt: edit the witness planes BEFORE the `A` commitment, let
/// `prove_inner` run to completion, and return the VERIFIER's verdict. The
/// endpoint owner commits the tampered output, so `SC_IO_OUT` cannot be what
/// rejects (none of these cases moves the output anyway).
fn prove_tampered(edit: impl FnOnce(&BlockPublic, &mut Witness)) -> Result<(), String> {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let mut w = witness::build(blk.attention(), blk.feed_forward(), &input).expect("the public synthetic fixture is accepted");
    let honest = w.output().expect("the honest output plane is in class");
    edit(&blk, &mut w);
    let output = w.output().unwrap_or(honest);
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    // a CHEATING prover pre-checks no relation: a false witness still yields a
    // receipt (since stage 40, ruling CS-3 — ported in native round 5 — the
    // honest prover refuses a lookup miss by name; the switch turns that off,
    // as a cheater would)
    let _cheating = super::protocol::CheatingProver::on();
    let (receipt, _) = prove_inner(&blk, w, &expected, owners)?;
    verify_inner(&blk, &expected, &receipt).map(|_| ())
}

fn expect_rejection(name: &str, catch: Catch, edit: impl FnOnce(&BlockPublic, &mut Witness)) {
    let err = prove_tampered(edit).expect_err(&format!("the half-p alias `{name}` VERIFIED"));
    assert!(catch.matches(&err), "alias `{name}`: expected the catch at {}, got `{err}`", catch.describe());
}

// ---------------------------------------------------------------- field arithmetic

/// `(p - 1) / 2 = 2^63 - 2^31`, the additive offset of the alias family.
pub(super) fn half_p_minus_one() -> Fp {
    Fp::new((P - 1) / 2)
}

/// The `i64` a witness plane must hold for `Fp::from_i64` (protocol.rs:286) to
/// read back `v`. Every field element is reachable: `v` itself below `2^63`,
/// `v - p` above it.
pub(super) fn to_plane(v: Fp) -> i64 {
    if v.0 < 1u64 << 63 {
        v.0 as i64
    } else {
        (i128::from(v.0) - i128::from(P)) as i64
    }
}

/// One norm site's planes. `norm_a` and `norm_m` are the SAME relation on
/// different planes: one `witness::rms_norm` builds both (witness.rs:219,355)
/// and `SC_TZC` proves both with the same six terms (argument.rs:587-592).
#[derive(Clone, Copy)]
struct Site {
    /// the denominator plane and its square
    d: usize,
    dsq: usize,
    /// the packed limb plane: sub-planes 0..3 `d`, 3..6 `a1`, 6..9 `a2`
    limb: usize,
    /// the quotient class plane
    y: usize,
    /// the first of the four `rho` limb planes, and of the four `sigma` ones
    rho0: usize,
    sig0: usize,
    /// the plane the row sum of squares is taken over
    x: usize,
}

const NORM_A: Site = Site { d: A_D, dsq: A_DSQ, limb: A_LIMB, y: A_Y, rho0: A_NR0, sig0: A_NS0, x: A_X };
const NORM_M: Site = Site { d: A_DM, dsq: A_DSQM, limb: A_LIMBM, y: A_YM, rho0: A_MR0, sig0: A_MS0, x: A_X1 };

/// Write one three-limb sub-plane triple of the packed limb plane so that it
/// RECONSTRUCTS `v` in `F_p` (`l0 = v`, `l1 = l2 = 0`). For a `v` outside
/// `[0, 256)` that is the only decomposition there is, and its `l0` has no row
/// in the U8 table: exactly the trade the alias has to make.
fn put_wide_limbs(w: &mut Witness, limb: usize, base: usize, t: usize, v: Fp) {
    w.planes[limb][base * T + t] = to_plane(v);
    w.planes[limb][(base + 1) * T + t] = 0;
    w.planes[limb][(base + 2) * T + t] = 0;
}

/// THE ALIAS WITNESS, on row `t` of one norm site, with every dependent plane
/// made as consistent as the relations allow.
///
/// `d := k + (p-1)/2` with `k` the honest denominator, then
///   `dsq := d^2`                         so (R1) holds,
///   `a1  := SSe - dsq`                   so (R4) holds,
///   `a2  := 2d - a1`                     so (R3) holds,
/// and, with the quotient `y` LEFT HONEST,
///   `rho   := 2 Cn g x + 2^tn d - 2^(tn+1) y d`   so (C0) holds,
///   `sigma := 2^(tn+1) d - 1 - rho`               so (C1) holds,
/// every one of them in `F_p`. `force_d_limbs` chooses between the two forms
/// the prover has: leave `d`'s own limbs honest (and fail (R2)), or make them
/// reconstruct the alias (and leave the byte class as the only thing false).
/// `a1` and `a2` always follow, so (R3) and the host row-sum term hold either
/// way and the case is not decided by them.
fn write_alias(w: &mut Witness, site: Site, gamma: &[i8], t: usize, force_d_limbs: bool) {
    let honest_d = w.planes[site.d][t];
    let d = Fp::from_i64(honest_d).add(half_p_minus_one());
    let ss: i64 = NORM_CEPS + (0..D).map(|i| w.planes[site.x][t * D + i].pow(2)).sum::<i64>();
    let dsq = d.mul(d);
    let a1 = Fp::from_i64(ss).sub(dsq);
    let a2 = d.double().sub(a1);
    w.planes[site.d][t] = to_plane(d);
    w.planes[site.dsq][t] = to_plane(dsq);
    if force_d_limbs {
        put_wide_limbs(w, site.limb, 0, t, d);
    }
    put_wide_limbs(w, site.limb, 3, t, a1);
    put_wide_limbs(w, site.limb, 6, t, a2);
    let dv = Fp::from_i64(1 << NORM_TN).mul(d);
    let den = Fp::from_i64(1 << (NORM_TN + 1)).mul(d);
    for i in 0..D {
        let idx = t * D + i;
        let y = Fp::from_i64(w.planes[site.y][idx]);
        let num = Fp::from_i64(2 * NORM_CN * w.planes[site.x][idx] * i64::from(gamma[i]));
        let rho = num.add(dv).sub(den.mul(y));
        let sigma = den.sub(Fp::ONE).sub(rho);
        w.planes[site.rho0][idx] = to_plane(rho);
        w.planes[site.sig0][idx] = to_plane(sigma);
        for k in 1..4 {
            w.planes[site.rho0 + k][idx] = 0;
            w.planes[site.sig0 + k][idx] = 0;
        }
    }
}

// ---------------------------------------------------------------- the cases

/// (a) THE ALIAS WITH `d`'s LIMBS LEFT HONEST, on one `norm_a` row and one
/// `norm_m` row.
///
/// PREDICTED (from argument.rs:583-593, before running). `dsq`, `a1`, `a2`,
/// `rho` and `sigma` all follow the alias, so `mu[0]` (`dsq - d*d`), `mu[2]`
/// (`2d - a1 - a2`), the `nu` host term (`dsq + a1 - Ceps` against `SC_SS`'s
/// claimed row sum) and both `SC_DZC` division terms hold in `F_p`. The one
/// relation left false is `mu[1]`, `d - dl`, because `dl` still reconstructs
/// the honest `k`. `SC_TZC` is slot 2, and its claimed sum is a public zero
/// plus the two hosted sums, so `sumcheck::verify` must reject there:
/// `Catch::Slot(SC_TZC)`.
///
/// STATED, NOT ARGUED AWAY: `a1`'s and `a2`'s low limbs now sit outside
/// `[0, 256)`, so the U8 lookups are false too — but that can only be caught
/// by the `H` opening, which runs after all twenty-three slots. Slot 2 is
/// therefore the FIRST catch, and case (b) is what isolates the byte class.
#[test]
fn the_half_p_isqrt_alias_is_refused_by_the_byte_limb_pin_on_the_denominator() {
    expect_rejection("norm_a: d = k + (p-1)/2, d's limbs honest", Catch::Slot(SC_TZC), |blk, w| {
        let gamma = blk.attention().gamma_a.clone();
        write_alias(w, NORM_A, &gamma, 0, false);
    });
    expect_rejection("norm_m: dm = k + (p-1)/2, dm's limbs honest", Catch::Slot(SC_TZC), |blk, w| {
        let gamma = blk.feed_forward().gamma_m.clone();
        write_alias(w, NORM_M, &gamma, 0, false);
    });
    // beside them: the honest proof through the same path verifies (E-20)
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every alias case");
}

/// (b) THE ALIAS WITH THE LIMBS MADE TO FOLLOW IT — the strongest form, and
/// the one that decides whether the exclusion is a RANGE FACT or an accident
/// of widths. `l0 = d`, `l1 = l2 = 0` satisfies (R2) in `F_p` exactly, so
/// every relation of every slot now holds: (R1), (R2), (R3), (R4), `SC_DZC`'s
/// `c0` / `c1` (the quotient is honest and `rho`, `sigma` were re-derived),
/// every other zero-check, every LogUp helper relation pointwise (the prover
/// builds its helpers from the same plane values), the M functionals and both
/// endpoint equalities.
///
/// PREDICTED (before running): the ONLY thing false is that `l0`, and the low
/// limbs of `a1`, `a2`, `rho` and `sigma`, have no row in the 256-entry U8
/// table. The prover counts each miss into entry 0 (protocol.rs:293) so the
/// histogram totals still match; nothing but the one value-0 LogUp sum claim
/// on `H` can see it: `Catch::LogUp`.
///
/// IF THIS CASE EVER VERIFIES, the private block accepts a denominator that is
/// not `isqrt(SSe)` and the norm's exactness is gone. It is the R09
/// counterexample, transposed.
#[test]
fn the_half_p_isqrt_alias_with_reconstructing_limbs_is_refused_by_the_u8_table() {
    expect_rejection("norm_a: d = k + (p-1)/2, limbs reconstruct it", Catch::LogUp, |blk, w| {
        let gamma = blk.attention().gamma_a.clone();
        write_alias(w, NORM_A, &gamma, 0, true);
    });
    expect_rejection("norm_m: dm = k + (p-1)/2, limbs reconstruct it", Catch::LogUp, |blk, w| {
        let gamma = blk.feed_forward().gamma_m.clone();
        write_alias(w, NORM_M, &gamma, 0, true);
    });
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every alias case");
}

// ------------------------------------------------- the arithmetic, on paper

/// THE ALIAS IS ARITHMETICALLY SOUND — which is why only a RANGE fact can stop
/// it. This replays (R1), (R3), (R4), (C0) and (C1) in `F_p` for a family of
/// `k`, with no prover involved, and asserts that the alias satisfies every
/// one of them exactly. If this test failed, the two cases above would be
/// proving nothing (the verifier would be catching broken arithmetic, not a
/// missing range fact).
#[test]
fn the_alias_satisfies_every_norm_relation_in_the_field() {
    let half = half_p_minus_one();
    for k in [0i64, 1, 2, 1023, 131072, (1 << 24) - 1] {
        let d = Fp::from_i64(k).add(half);
        // (R3): 2d = a1 + a2 with a1 + a2 = 2k - 1, the ODD branch
        assert_eq!(d.double(), Fp::from_i64(2 * k - 1), "2d is not the odd integer 2k - 1 at k = {k}");
        // (R1) and the identity d^2 = k^2 - k + inv(4)
        let inv4 = Fp::from_i64(4).inv();
        assert_eq!(d.mul(d), Fp::from_i64(k).mul(Fp::from_i64(k)).sub(Fp::from_i64(k)).add(inv4), "d^2 at k = {k}");
        // (R4): a1 := SSe - d^2 satisfies dsq + a1 = SSe for ANY SSe
        for sse in [1i64, 1000, (1 << 34) + 1] {
            let a1 = Fp::from_i64(sse).sub(d.mul(d));
            assert_eq!(d.mul(d).add(a1), Fp::from_i64(sse), "(R4) at k = {k}, SSe = {sse}");
            // ... and (R3) closes with a2 = 2d - a1
            let a2 = d.double().sub(a1);
            assert_eq!(a1.add(a2), d.double(), "(R3) at k = {k}, SSe = {sse}");
        }
        // (C0) / (C1): the alias is an EXACT division by 2^tn (2k - 1), the
        // half-integer denominator 2^(tn+1) (k - 1/2)
        let den = Fp::from_i64(1 << (NORM_TN + 1)).mul(d);
        let dv = Fp::from_i64(1 << NORM_TN).mul(d);
        assert_eq!(den, Fp::from_i64((1 << NORM_TN) * (2 * k - 1)), "the alias denominator at k = {k}");
        assert_eq!(dv, Fp::from_i64((1 << (NORM_TN - 1)) * (2 * k - 1)), "the alias rounding bias at k = {k}");
        for (y, num) in [(0i64, 0i64), (7, 12345), (-100, -9_000_000)] {
            let rho = Fp::from_i64(num).add(dv).sub(den.mul(Fp::from_i64(y)));
            let sigma = den.sub(Fp::ONE).sub(rho);
            assert_eq!(sigma.add(rho).add(Fp::ONE), den, "(C1) at k = {k}, y = {y}");
            assert_eq!(Fp::from_i64(num).add(dv).sub(den.mul(Fp::from_i64(y))).sub(rho), Fp::ZERO, "(C0) at k = {k}, y = {y}");
        }
    }
}

/// THE EXCLUSION IS A DIRECT RANGE FACT ON `d`, NOT A WIDTH. The alias's `d`
/// is at least `2^62` for every `k`, so no byte-limb count this field can
/// express admits it; the alias's `a1`, by contrast, is only excluded at the
/// three-limb window of the fixed profile and fits a FOUR-limb one — which is
/// exactly the window an int24 residual class at width 4096 needs.
///
/// This is the paper form of the "wider setting" leg: `N_LIMBS` and the
/// three-term `l3` reconstruction of argument.rs:584 are production constants,
/// so a wider profile cannot be reached from a test without changing the
/// prover, and this lane changes no prover behaviour.
#[test]
fn the_denominator_range_fact_excludes_the_alias_at_every_expressible_width() {
    let half = half_p_minus_one();
    // (i) d itself: never below 2^62, whatever k is
    for k in [0u64, 1, 1 << 12, 1 << 24, 1 << 31, (1 << 32) - 1] {
        let d = Fp::new(k).add(half);
        assert!(d.0 >= 1u64 << 62, "the alias d fell below 2^62 at k = {k}");
        // eight byte limbs are not expressible (2^64 > p); seven give 2^56
        assert!(d.0 >= 1u64 << 56, "the alias d fits a seven-byte-limb window at k = {k}");
    }
    // (ii) a1 = SSe - d^2 at the FIXED profile's k window (R3 bounds k by the
    // a1 / a2 limbs): never below 2^61, so three byte limbs refuse it
    let sse_max = 1i64 + 16 * 32768 * 32768;
    for k in [0i64, 1, (1 << 23) as i64, (1 << 24) - 1] {
        let d = Fp::from_i64(k).add(half);
        let a1 = Fp::from_i64(sse_max).sub(d.mul(d));
        assert!(a1.0 >= 1u64 << 61, "the alias a1 fell below 2^61 at k = {k} (three-limb window is 2^24)");
    }
    // (iii) ... but at the k nearest `isqrt((p-1)/4 + SSe)` the same a1 is about
    // 2^30 and DOES fit four byte limbs. The isqrt witness stops excluding the
    // alias exactly when the geometry widens. (`a1(k) - a1(k+1) = 2k ~ 2^32` is
    // the step, so the four-limb window catches one k for almost every SSe; a
    // gap exists only for the few SSe where the step overshoots.)
    let root = witness::isqrt((P - 1) / 4 + sse_max as u64) as i64;
    let mut best = u64::MAX;
    for k in root - 4..=root + 4 {
        let d = Fp::from_i64(k).add(half);
        best = best.min(Fp::from_i64(sse_max).sub(d.mul(d)).0);
    }
    assert!(best < 1u64 << 32, "the alias a1 near k = 2^31 should fit a four-byte-limb window, got 2^{}", 64 - best.leading_zeros());
    assert!(best >= 1u64 << 29, "sanity: it is about 2^30, not small");
}

/// THE HONEST DENOMINATOR AT EACH GEOMETRY, and the limb count it needs. The
/// three limbs of the fixed profile cover an int16 class at width 16 and even
/// at width 4096; an int24 class at width 4096 needs FOUR, and four is also
/// the last count at which `d^2 + a1 < p` still holds (`(2^32 - 1)^2 = p -
/// 2^32`, so `d^2 + a1 <= p - 1` exactly). Five would wrap (R4) and the isqrt
/// argument would collapse for a different reason.
#[test]
fn the_limb_count_the_widened_geometry_needs() {
    let dmax = |width: u64, xmax: u64| witness::isqrt(1 + width * xmax * xmax);
    let limbs = |d: u64| (64 - d.leading_zeros()).div_ceil(8) as usize;
    // the fixed profile: D reaches exactly 2^17 on a saturated int16 row
    assert_eq!(dmax(16, 32768), 1 << 17);
    assert_eq!(limbs(dmax(16, 32768)), 3);
    // width 4096, int16 residual: 2^21, still three limbs
    assert_eq!(dmax(4096, 32768), 1 << 21);
    assert_eq!(limbs(dmax(4096, 32768)), 3);
    // width 4096, int24 residual: 2^29 -> FOUR limbs
    assert_eq!(dmax(4096, 1 << 23), 1 << 29);
    assert_eq!(limbs(dmax(4096, 1 << 23)), 4);
    // a1 <= 2D needs the same count
    assert_eq!(limbs(2 * dmax(4096, 1 << 23)), 4);
    // four limbs is the no-wrap boundary, exactly
    let m = u128::from(u32::MAX);
    assert_eq!(m * m + m, u128::from(P) - 1, "four byte limbs on d and a1 sit exactly at d^2 + a1 = p - 1");
    assert!((u128::from(u64::from(u32::MAX)) + 1).pow(2) > u128::from(P), "five would wrap");
    // the fixed profile's remainder window is saturated: den = 2^(tn+1) D = 2^29
    assert_eq!(dmax(16, 32768) << (NORM_TN + 1), 1 << NORM_WRHO);
}

// ====================================================================
// STEP S8 / RULING P-5 (decision D16 item 6): the alias at the WIDENED
// norm window
// ====================================================================
//
// S8 widens the norm remainder window from the toy's 2^29 to the rung's 2^31
// and 125M's 2^32 (memo section 3.8 row 9). P-5 makes the alias cases above
// the non-negotiable acceptance of that widening, so this section asks the
// question the ruling asks: **does a wider `wrho` re-open the half-p alias?**
//
// AT WHAT LEVEL THIS RUNS, and why it is not the end-to-end form. The two
// cases above call `prove_inner`, which is instantiable only at the toy
// (finding S5-F2): the argument's claim points, tables and row geometry are
// the toy's until steps S10 and S11. The obligation is therefore discharged
// HERE at the level where the relation is decided — the four norm relations
// (R1) .. (R4) of this module's header, evaluated in `F_p` on a REAL honest
// witness built at the new profile — and the end-to-end form is owed again
// at step S12, when a rung receipt exists. That is a smaller claim than
// "the alias tamper tests reject at the new profile", and it is stated as
// the smaller one.

/// **THE EXCLUSION DOES NOT TOUCH THE WINDOW THAT MOVED.** The alias is
/// excluded by (R2), a range fact about `d` held in `LIMBS_ISQRT = 3` byte
/// limbs; `wrho` is a range fact about `rho` and `sigma`, held in
/// `limbs_norm` limbs on different planes. S8 moves the second and not the
/// first, and this test says so in numbers at all three shapes.
#[test]
fn the_widened_norm_window_does_not_re_open_the_alias() {
    use super::shape::{Shape, LIMBS_ISQRT};
    let half = half_p_minus_one();
    let isqrt_window = 1i128 << (8 * LIMBS_ISQRT as u32);
    for s in [Shape::toy(), Shape::rung(), Shape::m125()] {
        // the window really did move, and the limb count that holds it too
        assert!((29..=32).contains(&s.norm_wrho), "{}: wrho {}", s.name, s.norm_wrho);
        assert_eq!(s.limbs_norm(), 4, "{}: the remainder still sits in four limbs", s.name);
        // (R2)'s window did NOT move: three byte limbs, and the honest
        // denominator still fits them at every shape
        assert!(s.d_max < isqrt_window, "{}: D_max {} needs a fourth isqrt limb", s.name, s.d_max);
        assert!(2 * s.d_max < isqrt_window, "{}: a1 = 2D needs a fourth isqrt limb", s.name);
        // and `den = 2^(tn+1) D_max` saturates the shape's own window, which
        // is what makes `wrho` the exact completeness bound of section 3.3
        let den_max = s.d_max << (NORM_TN + 1);
        assert!(den_max <= 1i128 << s.norm_wrho, "{}: den_max {den_max} leaves the 2^{} window", s.name, s.norm_wrho);
        assert!(den_max > 1i128 << (s.norm_wrho - 1), "{}: the window is not tight, so it was not derived from D_max", s.name);
        // THE POINT: the alias `d` is at least 2^62 for every `k` in the
        // honest range, so it is outside (R2)'s three-limb window by 38 bits
        // — and outside every window `wrho` could ever be, since `wrho <= 32`
        for k in [0i64, 1, 1 << 12, i64::try_from(s.d_max).expect("D_max fits i64")] {
            let d = Fp::from_i64(k).add(half);
            assert!(u128::from(d.0) >= 1u128 << 62, "{}: the alias d fell below 2^62 at k = {k}", s.name);
            assert!(u128::from(d.0) >= isqrt_window as u128, "{}: the alias d entered the three-limb window at k = {k}", s.name);
            assert!(u128::from(d.0) >= 1u128 << s.norm_wrho, "{}: the alias d entered the remainder window at k = {k}", s.name);
        }
    }
}

/// **THE SAME VERDICT, ON A REAL WITNESS AT THE NEW PROFILE.** At
/// `Shape::rung()` — the shape S8 exists for — an honest witness is built,
/// and the alias is applied to one `norm_a` row exactly as `write_alias`
/// applies it at the toy. Every relation the alias is designed to satisfy
/// (R1), (R3), (R4) is checked to HOLD in `F_p` at the rung's numbers, so
/// nothing else can be what refuses; and (R2), the byte-limb reconstruction
/// of `d`, is checked to be the one that is false — in both of the prover's
/// two forms, honest limbs (the reconstruction fails) and reconstructing
/// limbs (`l0` leaves the byte class, which is what the U8 table catches).
///
/// This is the toy cases' `Catch::Slot(SC_TZC)` and `Catch::LogUp` at the
/// relation level. The end-to-end rung receipt is step S12's.
#[test]
fn the_alias_still_breaks_exactly_r2_on_a_rung_witness() {
    use super::shape::Shape;
    let s = Shape::rung();
    let ids = Ids::new(&s).expect("the rung has a plane map");
    let (public, ff, input) = super::grow_tests::tame_case(&s);
    let w = witness::build_shaped(&s, &public, &ff, &input).expect("the rung's honest witness");
    let half = half_p_minus_one();
    let (pd, pdsq, plimb) = (ids.at(A_D), ids.at(A_DSQ), ids.at(A_LIMB));
    for t in [0usize, 1, s.tokens - 1] {
        let honest_d = w.planes[pd][t];
        // the honest row, first: (R1) .. (R4) all hold, so the alias is the
        // only thing on trial
        let ss: i64 = NORM_CEPS + (0..s.width).map(|i| w.planes[ids.at(A_X)][t * s.d_pad + i].pow(2)).sum::<i64>();
        assert_eq!(w.planes[pdsq][t], honest_d * honest_d, "row {t}: the honest (R1)");
        let hl: i64 = (0..3).map(|k| w.planes[plimb][k * s.t_pad + t] << (8 * k)).sum();
        assert_eq!(hl, honest_d, "row {t}: the honest (R2)");
        let (ha1, ha2): (i64, i64) =
            ((0..3).map(|k| w.planes[plimb][(3 + k) * s.t_pad + t] << (8 * k)).sum(), (0..3).map(|k| w.planes[plimb][(6 + k) * s.t_pad + t] << (8 * k)).sum());
        assert_eq!(ha1 + ha2, 2 * honest_d, "row {t}: the honest (R3)");
        assert_eq!(honest_d * honest_d + ha1 - NORM_CEPS, ss - NORM_CEPS, "row {t}: the honest (R4)");
        // now the alias
        let d = Fp::from_i64(honest_d).add(half);
        let dsq = d.mul(d);
        let a1 = Fp::from_i64(ss).sub(dsq);
        let a2 = d.double().sub(a1);
        assert_eq!(dsq, d.mul(d), "row {t}: (R1) must hold for the alias");
        assert_eq!(a1.add(a2), d.double(), "row {t}: (R3) must hold for the alias");
        assert_eq!(dsq.add(a1).sub(Fp::from_i64(NORM_CEPS)), Fp::from_i64(ss - NORM_CEPS), "row {t}: (R4) must hold for the alias");
        // form (a): the limbs are left honest, so (R2) is FALSE
        assert_ne!(Fp::from_i64(hl), d, "row {t}: the honest limbs must not reconstruct the alias");
        // form (b): the limbs are made to reconstruct it, so `l0 = d` leaves
        // the byte class by 54 bits
        assert!(u128::from(d.0) >= 1u128 << 62, "row {t}: the alias d must be huge");
        assert!(d.0 >= 256, "row {t}: `l0 = d` must have no row in the 256-entry U8 table");
    }
    // and the rung's WIDER window is not what does it: the alias's d is above
    // 2^62 while the widest window S8 introduces is 2^32
    assert!(1u128 << 62 > 1u128 << Shape::m125().norm_wrho);
}

// ====================================================================
// NATIVE LANE (2026-10-17), D16 item 6 at the TRAINED-CALIBRATION
// profiles: the alias END TO END, through the real prover and verifier
// ====================================================================
//
// The cases above run at the toy (and at the rung at the relation level).
// D16 item 6 makes "the alias tamper tests reject at every widened profile
// BEFORE it is used" binding on the trained TinyLlama profile, whose norm
// relation now reads the shape's `tn`, its two `Cn`, its `Ceps` and a
// derived window. These cases rebuild the alias with THE SHAPE'S constants
// and strides (so a stale global could not make them vacuous), run the real
// `prove_inner_at` / `verify_inner_at` at the shape, and require the same two
// catches as at the toy: `SC_TZC` with honest limbs, the value-0 LogUp claim
// with reconstructing limbs. The honest proof beside them must verify.

/// one norm site at a SHAPE: planes through `Ids`, strides from the shape,
/// and the site's own multiplier
#[derive(Clone, Copy)]
pub(super) struct SiteAt {
    d: usize,
    dsq: usize,
    limb: usize,
    y: usize,
    rho0: usize,
    sig0: usize,
    x: usize,
    cn: i64,
    is_m: bool,
}

pub(super) fn site_a(sh: &super::shape::Shape, ids: &Ids) -> SiteAt {
    SiteAt { d: ids.at(A_D), dsq: ids.at(A_DSQ), limb: ids.at(A_LIMB), y: ids.at(A_Y), rho0: ids.nr(0), sig0: ids.ns(0), x: ids.at(A_X), cn: sh.norm_cn_a, is_m: false }
}

pub(super) fn site_m(sh: &super::shape::Shape, ids: &Ids) -> SiteAt {
    SiteAt { d: ids.at(A_DM), dsq: ids.at(A_DSQM), limb: ids.at(A_LIMBM), y: ids.at(A_YM), rho0: ids.mr(0), sig0: ids.ms(0), x: ids.at(A_X1), cn: sh.norm_cn_m, is_m: true }
}

/// [`write_alias`] at a shape, with the shape's `tn`, `Ceps`, the site's `Cn`,
/// the shape's limb-plane stride `t_pad` and row stride `d_pad`.
pub(super) fn write_alias_at(sh: &super::shape::Shape, w: &mut Witness, site: SiteAt, gamma: &[i8], t: usize, force_d_limbs: bool) {
    let (tp, dp, ln) = (sh.t_pad, sh.d_pad, sh.limbs_norm());
    let honest_d = w.planes[site.d][t];
    let d = Fp::from_i64(honest_d).add(half_p_minus_one());
    let ss: i64 = sh.norm_ceps + (0..sh.width).map(|i| w.planes[site.x][t * dp + i].pow(2)).sum::<i64>();
    let dsq = d.mul(d);
    let a1 = Fp::from_i64(ss).sub(dsq);
    let a2 = d.double().sub(a1);
    w.planes[site.d][t] = to_plane(d);
    w.planes[site.dsq][t] = to_plane(dsq);
    let put = |w: &mut Witness, base: usize, v: Fp| {
        w.planes[site.limb][base * tp + t] = to_plane(v);
        w.planes[site.limb][(base + 1) * tp + t] = 0;
        w.planes[site.limb][(base + 2) * tp + t] = 0;
    };
    if force_d_limbs {
        put(w, 0, d);
    }
    put(w, 3, a1);
    put(w, 6, a2);
    let dv = Fp::from_i64(1i64 << sh.norm_tn).mul(d);
    let den = Fp::from_i64(1i64 << (sh.norm_tn + 1)).mul(d);
    for i in 0..sh.width {
        let idx = t * dp + i;
        let y = Fp::from_i64(w.planes[site.y][idx]);
        let num = Fp::from_i64(2 * site.cn * w.planes[site.x][idx] * i64::from(gamma[i]));
        let rho = num.add(dv).sub(den.mul(y));
        let sigma = den.sub(Fp::ONE).sub(rho);
        w.planes[site.rho0][idx] = to_plane(rho);
        w.planes[site.sig0][idx] = to_plane(sigma);
        for k in 1..ln {
            w.planes[site.rho0 + k][idx] = 0;
            w.planes[site.sig0 + k][idx] = 0;
        }
    }
    let _ = site.is_m;
}

/// One end-to-end attempt at a shape: build the honest witness, edit it,
/// commit the (possibly edited) endpoint planes, prove with the real prover
/// and return the real verifier's verdict.
pub(super) fn prove_tampered_at(sh: &super::shape::Shape, blk: &BlockPublic, input: &[i16], edit: impl FnOnce(&mut Witness)) -> Result<(), String> {
    let ids = Ids::new(sh).expect("the plane map");
    let mut w = witness::build_shaped(sh, blk.attention(), blk.feed_forward(), input).expect("the honest witness at this shape");
    edit(&mut w);
    let _ = ids;
    // ROUND 2 (R2-4): a trained-calibration block proves only inside a run
    // bound to its statement, so the alias is proved and verified that way
    // NATIVE ROUND 5 (ruling CS-3): proved as a CHEATING prover would, with
    // the honest prover's lookup-miss refusal off, so the verifier has to speak
    let cheating = super::protocol::CheatingProver::on();
    let b = super::trained_calib_tests::prove_one_bound(sh, blk, w)?;
    drop(cheating);
    super::trained_calib_tests::verify_one_bound(sh, blk, &b.expected.to_bytes(), &b.seg)
}

/// The four alias cases plus the honest control at a shape; panics on any
/// acceptance or on a catch at the wrong place.
pub(super) fn the_alias_cases_reject_at(sh: &super::shape::Shape, blk: &BlockPublic, input: &[i16]) {
    let ids = Ids::new(sh).expect("the plane map");
    let (ga, gm) = (blk.attention().gamma_a.clone(), blk.feed_forward().gamma_m.clone());
    let row = sh.tokens / 2;
    for (name, site, gamma, force, catch) in [
        ("norm_a, d's limbs honest", site_a(sh, &ids), ga.clone(), false, Catch::Slot(SC_TZC)),
        ("norm_m, dm's limbs honest", site_m(sh, &ids), gm.clone(), false, Catch::Slot(SC_TZC)),
        ("norm_a, limbs reconstruct the alias", site_a(sh, &ids), ga, true, Catch::LogUp),
        ("norm_m, limbs reconstruct the alias", site_m(sh, &ids), gm, true, Catch::LogUp),
    ] {
        let err = prove_tampered_at(sh, blk, input, |w| write_alias_at(sh, w, site, &gamma, row, force)).expect_err(&format!("{}: the half-p alias `{name}` VERIFIED", sh.name));
        assert!(catch.matches(&err), "{}: alias `{name}`: expected the catch at {}, got `{err}`", sh.name, catch.describe());
        eprintln!("D16 item 6 at {}: alias `{name}` rejected at {}", sh.profile, catch.describe());
    }
    prove_tampered_at(sh, blk, input, |_| {}).expect("the honest proof must verify beside every alias case");
}

/// **THE ARITHMETIC AT THE TRAINED PROFILES.** The relation-level facts of
/// `the_widened_norm_window_does_not_re_open_the_alias`, for the trained
/// calibration's own `tn`, `Ceps` and derived window, without changing that
/// test's expected values: the remainder window is four limbs and exactly
/// `tn + 1 + bits(D_max)` with `D_max` from the signed-int16 endpoint 32768,
/// `den_max` saturates it (so it was derived, and every honest remainder
/// fits), the isqrt window is three limbs, and the alias `d` is outside both.
#[test]
fn the_trained_norm_window_does_not_re_open_the_alias() {
    use super::shape::{NormCalibration, Shape, LIMBS_ISQRT};
    let half = half_p_minus_one();
    let isqrt_window = 1i128 << (8 * LIMBS_ISQRT as u32);
    let cal = super::trained_calib_tests::t3_calibration();
    for s in [
        Shape::tinyllama_t32_trained(&cal, 9).expect("the trained TinyLlama shape"),
        Shape::tinyllama_t32_trained(&super::trained_calib_tests::pg_calibration(), 9).expect("the pg TinyLlama shape"),
        Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).expect("the trained rung"),
    ] {
        assert!(s.trained_calibration);
        assert_eq!(s.limbs_norm(), 4, "{}: four remainder limbs", s.name);
        let dmax = super::witness::isqrt((s.norm_ceps as u64) + (s.width as u64) * 32768 * 32768) as i128;
        assert_eq!(s.d_max, dmax, "{}: D_max is not isqrt(ceps + width 32768^2)", s.name);
        assert!(s.d_max < isqrt_window && 2 * s.d_max < isqrt_window, "{}: the isqrt witness needs a fourth limb", s.name);
        assert_eq!(s.norm_wrho, s.norm_tn + 1 + (128 - s.d_max.leading_zeros()), "{}: the window is not derived", s.name);
        let den_max = s.d_max << (s.norm_tn + 1);
        assert!(den_max <= 1i128 << s.norm_wrho, "{}: den_max leaves the window", s.name);
        assert!(den_max > 1i128 << (s.norm_wrho - 1), "{}: the window is not tight", s.name);
        for k in [0i64, 1, 1 << 12, i64::try_from(s.d_max).unwrap()] {
            let d = Fp::from_i64(k).add(half);
            assert!(u128::from(d.0) >= isqrt_window as u128 && u128::from(d.0) >= 1u128 << s.norm_wrho, "{}: the alias d entered a window at k = {k}", s.name);
        }
        let _ = NormCalibration::FROZEN;
    }
}

/// **D16 ITEM 6, END TO END, at the trained-calibration development rung**
/// (`tn = 10`, two multipliers, a large `Ceps`, `sh_ao = 6`; window 31 bits,
/// so the top-limb `scaled` lookup is live). Ordinary filter, seconds.
#[test]
fn the_half_p_alias_is_refused_end_to_end_at_the_trained_calibration_rung() {
    let sh = super::shape::Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).expect("the trained rung");
    let (blk, input) = super::trained_calib_tests::trained_dense_block(&sh);
    the_alias_cases_reject_at(&sh, &blk, &input);
}

/// **D16 ITEM 6, END TO END, at the trained TinyLlama profile** (T32, width
/// 2048, `tn = 10`, window 32 bits = C-6). ROUND 2: at the pg_rot1 export's
/// calibration (Cn 3999 / 3122, Ceps 91255, shifts QKV 8 / AO 3 / G 8 / Z 5).
/// Five width-2048 proofs as bound one-block runs: heavy, run in release.
#[test]
#[ignore = "native lane heavy: five width-2048 TinyLlama proofs"]
fn native_the_half_p_alias_is_refused_end_to_end_at_the_trained_tinyllama_profile() {
    let sh = super::shape::Shape::tinyllama_t32_trained(&super::trained_calib_tests::pg_calibration(), 9).expect("the trained TinyLlama shape");
    let (blk, input) = super::trained_calib_tests::trained_dense_block(&sh);
    the_alias_cases_reject_at(&sh, &blk, &input);
}
