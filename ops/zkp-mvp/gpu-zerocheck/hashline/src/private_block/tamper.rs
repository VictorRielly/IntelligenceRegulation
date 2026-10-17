//! TAMPER TESTS AT THE VERIFIER for the feed-forward half (stage S3c; T2
//! section G as corrected by errata E-18, E-19 and E-20).
//!
//! The rule the whole suite rests on: a tamper test is worth something only if
//! the VERIFIER rejects. A prover-side assertion, a witness-builder refusal or
//! a `debug_assert` proves nothing about the receipt. So every case here edits
//! the witness planes BEFORE the `A` commitment, lets `prove_inner` run to
//! completion, and asserts `verify_inner(...)` is an error — and, beside every
//! one of them, that the HONEST proof through the same path verifies, so the
//! suite cannot pass on a build that is broken for an unrelated reason
//! (erratum E-20).
//!
//! CONSISTENT, NOT SLOPPY (erratum E-19). Each case names ONE relation and
//! recomputes the whole chain downstream of the tamper so that every other
//! relation, every class proof and every lookup still holds. Four of T2's own
//! rows fire two or three catches at once and therefore cannot show that a
//! particular relation is PRESENT; the cases below recompute the chain exactly
//! so that they can. The one case that is deliberately left with two catches
//! is the int16-class test at the end, which is about a class and says so.
//!
//! BY SLOT INDEX, NEVER BY NAME (erratum E-20). `SLOT_NAMES[SC_DZC]` is a
//! string this very stage changed, so each case asserts the catch by the slot
//! INDEX the verifier prints, or, where the catch is the one value-0 LogUp sum
//! claim on `H`, by the `H:` prefix of the opening that carries it. Naming the
//! catch is the point: a later refactor that moves it somewhere else is a
//! finding, not a silent pass.
//!
//! Every fixture is the PUBLIC SYNTHETIC one; no witness value is printed.

use super::layout::*;
use super::protocol::{prove_inner, verify_inner};
use super::witness::{self, Witness};
use super::*;

fn spec() -> IoSpec {
    IoSpec::new(*blake3::hash(b"private block: public synthetic tamper context").as_bytes(), 0, 0).unwrap()
}

/// where the verifier must catch a tamper
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

// ---------------------------------------------------------------- arithmetic

/// one biased requantization, exactly as `witness::quantize` stores it:
/// `acc = 2^sh y + r' - 2^(sh-1)` with `r'` in `[0, 2^sh)`. It calls the
/// witness's own `requant` rather than repeating it, so the two cannot drift
/// and defect D-2's shift underflow is not duplicated here.
fn requant(acc: i64, sh: u32) -> (i64, i64) {
    let (y, rem) = witness::requant(acc, sh);
    (y, rem + witness::half(sh))
}

fn put_limbs(w: &mut Witness, l0: usize, l1: usize, idx: usize, v: i64) {
    w.planes[l0][idx] = v & 255;
    w.planes[l1][idx] = (v >> 8) & 255;
}

fn in16(v: i64) -> bool {
    (-32768..=32767).contains(&v)
}

/// Recompute `h16`, `rh`, `z16`, `rd`, `xres2` and every limb from `a16` and
/// `u16`, the way the witness builder does. Returns false if any value would
/// leave its class: such a tamper is not consistent, and it would be caught by
/// a range relation rather than by the one the case names.
fn recompute_from_product(w: &mut Witness, ff: &FeedForwardPublic) -> bool {
    for idx in 0..T * F {
        let (h16, rh) = requant(w.planes[A_A16][idx] * w.planes[A_U16][idx], SH_H_PROD);
        if !in16(h16) {
            return false;
        }
        w.planes[A_H16][idx] = h16;
        put_limbs(w, A_HL0, A_HL1, idx, h16 + 32768);
        put_limbs(w, A_RH0, A_RH1, idx, rh);
    }
    recompute_from_h16(w, ff)
}

/// Recompute the WHOLE feed-forward half from `nm`, the way the witness
/// builder does: the gate and its biased remainder, the activation lookup,
/// the up matmul (`SH_U = 0`, so no remainder) and every limb, then the
/// product, the down matmul, residual 2 and their limbs. After it, a tamper on
/// `nm` leaves the norm relation itself as the only thing that can notice.
/// Returns false if any value would leave its class.
fn recompute_from_nm(w: &mut Witness, ff: &FeedForwardPublic) -> bool {
    for t in 0..T {
        for j in 0..F {
            let idx = t * F + j;
            let (mut gacc, mut uacc) = (0i64, 0i64);
            for i in 0..D {
                let nm = w.planes[A_YM][t * D + i];
                gacc += nm * i64::from(ff.wg_t[i * F + j]);
                uacc += nm * i64::from(ff.wu_t[i * F + j]);
            }
            let (g8, rg) = requant(gacc, SH_G);
            // the gate's class is the kernel's I8 and INCLUDES -128 (T2 A.2)
            if !(-128..=127).contains(&g8) || !in16(uacc) {
                return false;
            }
            w.planes[A_G8][idx] = g8;
            w.planes[A_RGL][idx] = rg;
            w.planes[A_A16][idx] = i64::from(ff.act[(g8 + 128) as usize]);
            w.planes[A_U16][idx] = uacc;
            put_limbs(w, A_UL0, A_UL1, idx, uacc + 32768);
        }
    }
    recompute_from_product(w, ff)
}

/// the `k`-th of `count` byte limbs, exactly `witness::limbs`: the top limb
/// carries the sign, so a negative value leaves the byte class THERE and
/// nowhere else
fn limb(v: i64, k: usize, count: usize) -> i64 {
    if k + 1 == count {
        v >> (8 * k)
    } else {
        (v >> (8 * k)) & 255
    }
}

/// the four-limb value of a `Dom::D` remainder plane family at one index
fn l4(w: &Witness, p0: usize, idx: usize) -> i64 {
    (0..4).map(|k| w.planes[p0 + k][idx] << (8 * k)).sum()
}

/// write one three-limb sub-plane triple of `A_LIMBM` (0 = `dm`, 3 = `a1m`,
/// 6 = `a2m`; sixteen 32-entry sub-planes packed into one `Dom::L` plane)
fn put_limbs_m(w: &mut Witness, base: usize, t: usize, v: i64) {
    for k in 0..3 {
        w.planes[A_LIMBM][(base + k) * T + t] = limb(v, k, 3);
    }
}

/// Recompute `norm_m`'s quotient row from the committed `dm`, exactly as
/// `witness::rms_norm` does: `nm = floor(num / den)`, `rho = num mod den`,
/// `sigma = den - 1 - rho` and their four byte limbs each. False if any value
/// would leave its class.
fn recompute_norm_m_row(w: &mut Witness, ff: &FeedForwardPublic, t: usize) -> bool {
    let dm = w.planes[A_DM][t];
    let den = dm << (NORM_TN + 1);
    for i in 0..D {
        let idx = t * D + i;
        let num = 2 * w.planes[A_X1][idx] * i64::from(ff.gamma_m[i]) * NORM_CN + (dm << NORM_TN);
        let (q, rho) = (num.div_euclid(den), num.rem_euclid(den));
        let sigma = den - 1 - rho;
        if !(-127..=127).contains(&q) || rho >= 1 << NORM_WRHO || sigma >= 1 << NORM_WRHO {
            return false;
        }
        w.planes[A_YM][idx] = q;
        for k in 0..4 {
            w.planes[A_MR0 + k][idx] = limb(rho, k, 4);
            w.planes[A_MS0 + k][idx] = limb(sigma, k, 4);
        }
    }
    true
}

/// Recompute `z16`, `rd`, `xres2` and their limbs from `h16`.
fn recompute_from_h16(w: &mut Witness, ff: &FeedForwardPublic) -> bool {
    for t in 0..T {
        for i in 0..D {
            let idx = t * D + i;
            let zacc: i64 = (0..F).map(|j| w.planes[A_H16][t * F + j] * i64::from(ff.wd_t[j * D + i])).sum();
            let (z16, rd) = requant(zacc, SH_Z);
            let x2 = w.planes[A_X1][idx] + z16;
            if !in16(z16) || !in16(x2) {
                return false;
            }
            w.planes[A_Z16][idx] = z16;
            w.planes[A_RDL][idx] = rd;
            w.planes[A_X2][idx] = x2;
            put_limbs(w, A_ZL0, A_ZL1, idx, z16 + 32768);
            put_limbs(w, A_X2L0, A_X2L1, idx, x2 + 32768);
        }
    }
    true
}

// ---------------------------------------------------------------- harness

/// One attempt. The endpoint owner commits the TAMPERED `xres2` — the
/// strongest form, and the one T1-check section 11.3 item 4 asks for: with the
/// output endpoint agreeing with the tampered witness, `SC_IO_OUT` cannot be
/// what rejects, so each case is left with the one relation it names. (When
/// the tamper pushes `xres2` out of int16 there is no such endpoint, and the
/// honest one is committed instead; the only case that needs this is the
/// int16-class test, which is about a class and has two catches anyway.)
fn prove_tampered(edit: impl FnOnce(&FeedForwardPublic, &mut Witness)) -> Result<ProveStats, String> {
    let (blk, input) = BlockPublic::synthetic_fixture();
    prove_tampered_for(&blk, &input, edit)
}

/// The same attempt against a caller-supplied PUBLIC statement, for the one
/// case that needs a public synthetic statement the default fixture does not
/// provide (the `u16 = 0` index of erratum E-22). The prover and the verifier
/// are given the SAME statement, as always.
fn prove_tampered_for(blk: &BlockPublic, input: &[i16], edit: impl FnOnce(&FeedForwardPublic, &mut Witness)) -> Result<ProveStats, String> {
    let mut w = witness::build(blk.attention(), blk.feed_forward(), input).expect("the public synthetic fixture is accepted");
    let honest = w.output().expect("the honest output plane is in class");
    edit(blk.feed_forward(), &mut w);
    let output = w.output().unwrap_or(honest);
    let (expected, owners) = prepare_endpoints(spec(), input, &output).unwrap();
    // the prover does not pre-check any relation: a false witness still yields
    // a receipt, and that receipt must not verify
    let (receipt, stats) = prove_inner(blk, w, &expected, owners)?;
    verify_inner(blk, &expected, &receipt).map(|_| stats)
}

fn expect_rejection(name: &str, catch: Catch, edit: impl FnOnce(&FeedForwardPublic, &mut Witness)) {
    let err = prove_tampered(edit).expect_err(&format!("tamper `{name}` VERIFIED"));
    assert!(catch.matches(&err), "tamper `{name}`: expected the catch at {}, got `{err}`", catch.describe());
}

fn expect_rejection_for(name: &str, blk: &BlockPublic, input: &[i16], catch: Catch, edit: impl FnOnce(&FeedForwardPublic, &mut Witness)) {
    let err = prove_tampered_for(blk, input, edit).expect_err(&format!("tamper `{name}` VERIFIED"));
    assert!(catch.matches(&err), "tamper `{name}`: expected the catch at {}, got `{err}`", catch.describe());
}

/// the first index at which `ok` holds, or a hard failure naming the case
fn pick(name: &str, n: usize, ok: impl Fn(usize) -> bool) -> usize {
    (0..n).find(|k| ok(*k)).unwrap_or_else(|| panic!("tamper `{name}`: no index of the public synthetic fixture admits a consistent tamper"))
}

// ---------------------------------------------------------------- the suite

/// THE TRIPWIRE of T1-check section 11.3 and disposition condition 1, under
/// its required name. `z16` is tampered CONSISTENTLY — `xres2 = xres1 + z16`
/// still holds, both limb pairs are recomputed so every class proof still
/// passes, the whole attention half and `norm_m` are untouched and honest —
/// and the endpoint owner commits the CHOSEN `xres2'`. Under Tier 1 alone
/// every check passed and the block's output was whatever the prover wanted.
/// It must now be the VERIFIER that rejects, at the down requantization that
/// derives `z16` from `nm`. (T1-check's step 3 says to recompute only the
/// `xres2` limbs; T2 section G.1 step 2 corrects that — `A_ZL0`/`A_ZL1` are
/// Tier 2's own planes and must be recomputed too, or `c10` breaks instead.)
#[test]
fn block_output_cannot_be_chosen() {
    expect_rejection("z16 (+1, xres2 and both limb pairs recomputed)", Catch::Slot(SC_DZC), |_, w| {
        let k = pick("z16", T * D, |k| w.planes[A_Z16][k] < 32767 && w.planes[A_X2][k] < 32767);
        w.planes[A_Z16][k] += 1;
        w.planes[A_X2][k] += 1;
        put_limbs(w, A_ZL0, A_ZL1, k, w.planes[A_Z16][k] + 32768);
        put_limbs(w, A_X2L0, A_X2L1, k, w.planes[A_X2][k] + 32768);
    });
    // beside it: the honest proof through the same path verifies (E-20)
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// `g8` moved and the WHOLE chain recomputed from the activation table down:
/// every class, every lookup and every downstream requantization identity
/// still holds, so the only relation left to catch it is `SC_FZC`'s gate host
/// term against `SC_GMM`'s claim. This is the test that `g` is bound to `nm`.
#[test]
fn a_gate_output_not_derived_from_nm_is_rejected() {
    expect_rejection("g8 (+1, a16 and the whole chain recomputed)", Catch::Slot(SC_FZC), |ff, w| {
        let k = pick("g8", T * F, |k| {
            if w.planes[A_G8][k] >= 127 {
                return false;
            }
            let mut probe = Witness { planes: w.planes.clone() };
            probe.planes[A_G8][k] += 1;
            probe.planes[A_A16][k] = i64::from(ff.act[(probe.planes[A_G8][k] + 128) as usize]);
            recompute_from_product(&mut probe, ff)
        });
        w.planes[A_G8][k] += 1;
        w.planes[A_A16][k] = i64::from(ff.act[(w.planes[A_G8][k] + 128) as usize]);
        assert!(recompute_from_product(w, ff));
    });
}

/// `a16` moved off its table row, with the chain recomputed so that every
/// requantization identity and every class still holds. The prover CAN satisfy
/// `f_act` pointwise (it commits `H` after alpha, so it can invert whatever
/// denominator it likes); what it cannot do is make the multiplicity histogram
/// agree, so the one value-0 sum claim on `H` fails. This is the relation
/// erratum E-22 makes a soundness requirement.
#[test]
fn an_activation_value_off_its_table_row_is_rejected() {
    expect_rejection("a16 (+1, the chain recomputed)", Catch::LogUp, |ff, w| {
        let k = pick("a16", T * F, |k| {
            if w.planes[A_A16][k] >= 32767 {
                return false;
            }
            let mut probe = Witness { planes: w.planes.clone() };
            probe.planes[A_A16][k] += 1;
            recompute_from_product(&mut probe, ff)
        });
        w.planes[A_A16][k] += 1;
        assert!(recompute_from_product(w, ff));
    });
}

/// `u16` moved with its limbs and the chain recomputed: the up identity
/// `uacc = u16` (no coefficient and no constant, because `SH_U = 0`) is the
/// only relation left, so `SC_FZC`'s second host term must catch it against
/// `SC_UMM`'s claim. This is the test that `u` is bound to `nm`.
#[test]
fn an_up_output_not_derived_from_nm_is_rejected() {
    expect_rejection("u16 (+1, limbs and the chain recomputed)", Catch::Slot(SC_FZC), |ff, w| {
        let k = pick("u16", T * F, |k| {
            if w.planes[A_U16][k] >= 32767 {
                return false;
            }
            let mut probe = Witness { planes: w.planes.clone() };
            probe.planes[A_U16][k] += 1;
            recompute_from_product(&mut probe, ff)
        });
        w.planes[A_U16][k] += 1;
        put_limbs(w, A_UL0, A_UL1, k, w.planes[A_U16][k] + 32768);
        assert!(recompute_from_product(w, ff));
    });
}

/// `h16` moved with its limbs, `rh` left alone, and everything BELOW it
/// recomputed so that `SC_DMM`'s claim and `SC_DZC`'s host term still agree.
/// The product relation `f0` is then the only one left, and it catches it —
/// T2's point that the product is pinned from both sides.
#[test]
fn a_product_output_not_equal_to_a16_times_u16_is_rejected() {
    expect_rejection("h16 (+1, limbs and the downstream chain recomputed)", Catch::Slot(SC_FZC), |ff, w| {
        let k = pick("h16", T * F, |k| {
            if w.planes[A_H16][k] >= 32767 {
                return false;
            }
            let mut probe = Witness { planes: w.planes.clone() };
            probe.planes[A_H16][k] += 1;
            recompute_from_h16(&mut probe, ff)
        });
        w.planes[A_H16][k] += 1;
        put_limbs(w, A_HL0, A_HL1, k, w.planes[A_H16][k] + 32768);
        assert!(recompute_from_h16(w, ff));
    });
}

/// Each of the three biased remainders, moved WITHIN its own window so that
/// every byte lookup still holds and the only relation that can notice is the
/// requantization identity the remainder appears in. `rg` and `rh` are on the
/// `f` cube and are caught by `SC_FZC`; `rd` is on the `d` cube and is caught
/// by `SC_DZC`.
#[test]
fn every_biased_remainder_is_pinned_by_its_requantization_identity() {
    // rg in [0, 2^7): the gate host term
    expect_rejection("rg (rotated inside [0, 2^7))", Catch::Slot(SC_FZC), |_, w| {
        w.planes[A_RGL][0] = (w.planes[A_RGL][0] + 1) % (1 << SH_G);
    });
    // rh in [0, 2^14), two byte limbs: the product relation f0
    expect_rejection("rh (rotated inside [0, 2^14), limbs recomputed)", Catch::Slot(SC_FZC), |_, w| {
        let rh = (w.planes[A_RH0][0] + 256 * w.planes[A_RH1][0] + 1) % (1 << SH_H_PROD);
        put_limbs(w, A_RH0, A_RH1, 0, rh);
    });
    // rd in [0, 2^6): the down host term
    expect_rejection("rd (rotated inside [0, 2^6))", Catch::Slot(SC_DZC), |_, w| {
        w.planes[A_RDL][0] = (w.planes[A_RDL][0] + 1) % (1 << SH_Z);
    });
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// The CLASS tests, in the only form that isolates the lookups.
///
/// T2's row T-z1 is `z16 + 2^16` with `rd` "compensated". With the whole chain
/// present that no longer reaches a lookup first: `xres2` leaves int16 too, so
/// there is no endpoint an owner could commit to it, and the FIRST catch is
/// the output endpoint equality at slot 22 — measured, not argued. Useful as
/// far as it goes (an out-of-class `z16` cannot be smuggled to the block's
/// output) but it cannot show that the class lookups do anything.
///
/// So the class is tested the way the module already tests it for `x_in`
/// (`tests.rs`, "range only (LogUp)"): shift a two-limb decomposition by
/// `(+256, -1)`. The decomposition relation still holds EXACTLY — `c10`,
/// `f1`, `f2` and `f0` are all satisfied — and the only thing broken is that
/// the low limb has left `[0, 256)` and has no row in the U8 table. Nothing
/// else can catch it, so the one value-0 LogUp sum claim on `H` must, and
/// that is what pins `u16`, `h16`, `z16` to int16 and `rh` to `[0, 2^14)`.
#[test]
fn a_limb_outside_its_byte_range_is_rejected_by_the_lookups() {
    for (name, l0, l1) in [
        ("z16's int16 limbs", A_ZL0, A_ZL1),
        ("u16's int16 limbs", A_UL0, A_UL1),
        ("h16's int16 limbs", A_HL0, A_HL1),
        ("rh's 14-bit limbs", A_RH0, A_RH1),
    ] {
        expect_rejection(name, Catch::LogUp, move |_, w| {
            // l0 + 256 * l1 is unchanged, so every relation still holds
            w.planes[l0][0] += 256;
            w.planes[l1][0] -= 1;
        });
    }
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// The other half of T2's row T-z1, recorded as what it actually is: with the
/// whole chain present, a `z16` outside int16 makes `xres2` outside int16 too,
/// and the first thing that rejects is the block's own output endpoint.
#[test]
fn a_z16_outside_int16_cannot_reach_the_output_endpoint() {
    expect_rejection("z16 (+2^16, rd compensated, limbs shifted: three catches)", Catch::Slot(SC_IO_OUT), |_, w| {
        w.planes[A_Z16][0] += 65536;
        w.planes[A_RDL][0] -= 65536 * (1 << SH_Z);
        w.planes[A_X2][0] += 65536;
        w.planes[A_ZL1][0] += 256;
        w.planes[A_X2L1][0] += 256;
    });
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// The D12 item-3 boundary test T2 section G carries beside the tripwire:
/// an honest receipt presented against an output endpoint committing `xres1`
/// instead of `xres2` must be refused — the block's external output is
/// `xres2` and nothing else.
#[test]
fn an_output_endpoint_committing_xres1_is_refused() {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let w = witness::build(blk.attention(), blk.feed_forward(), &input).unwrap();
    let xres2 = w.output().unwrap();
    let xres1: Vec<i16> = w.planes[A_X1].iter().map(|v| *v as i16).collect();
    assert_ne!(xres1, xres2, "the fixture's two residuals coincide; the test would be vacuous");
    let (expected, owners) = prepare_endpoints(spec(), &input, &xres1).unwrap();
    let (receipt, _) = prove_inner(&blk, w, &expected, owners).unwrap();
    let err = verify_inner(&blk, &expected, &receipt).expect_err("an xres1 output endpoint verified");
    assert!(Catch::Slot(SC_IO_OUT).matches(&err), "expected the output endpoint to reject, got `{err}`");
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

// ------------------------------------------------- the norm_m family (H-1)
//
// The code review of 2026-09-19 found that NOTHING in this module tampered a
// `norm_m` plane at the verifier: T1 section C.1's new material was covered
// only by "the honest proof verifies" and by witness/kernel parity, which
// together cannot show that a relation is PRESENT rather than vacuous. The
// four cases below are the four families, each with the catch worked out from
// `argument.rs` BEFORE it was measured and named in the case's own comment.
// The accepted attention component has no verifier-side `norm_a` tamper to
// mirror (its `tests.rs:122-123` moves `A_D` and `A_Y` inside the loop that
// accepts any error), so these are written from the argument, not copied.

/// (a) `nm` moved by one with the WHOLE feed-forward half recomputed honestly
/// from it — gate, activation lookup, up, product, down, residual 2, every
/// limb and biased remainder — and the endpoint owner committing the resulting
/// output. Every class, every lookup, every requantization identity and both
/// matmul host terms then still hold, so the only relation left is the norm
/// quotient itself.
///
/// PREDICTED (from `argument.rs`): `nm` is read by `SC_GMM` / `SC_UMM`
/// (consistent again after the recompute), by the `sym(A_YM)` class lookup
/// (`+1` stays inside `[-127, 127]`) and by `c6` of `SC_DZC`
/// (`2 Cn gamma_m x1 + 2^11 dm - 2^12 nm dm - rho_m`, under `mu[6]`). `c6` is
/// the one that must break: `Catch::Slot(SC_DZC)`. THIS is the test that `nm`
/// is bound to `xres1`.
#[test]
fn a_norm_m_output_not_derived_from_xres1_is_rejected() {
    expect_rejection("nm (+1, the whole feed-forward half recomputed)", Catch::Slot(SC_DZC), |ff, w| {
        let k = pick("nm", T * D, |k| {
            if w.planes[A_YM][k] >= 127 {
                return false;
            }
            let mut probe = Witness { planes: w.planes.clone() };
            probe.planes[A_YM][k] += 1;
            recompute_from_nm(&mut probe, ff)
        });
        w.planes[A_YM][k] += 1;
        assert!(recompute_from_nm(w, ff));
    });
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// (b) The denominator planes, in three forms of increasing consistency.
///
/// PREDICTED (from `argument.rs:552-583`): `SC_TZC` carries all four of
/// `dsqm - dm^2` (`mu[3]`), `dm - dlm` (`mu[4]`), `2 dm - a1m - a2m`
/// (`mu[5]`) and the host term `dsqm + a1m - Ceps` against `SC_SSM`'s claimed
/// row sum (`nu[1]`), and `dm` is read again by `c6` / `c7` of `SC_DZC`.
///  * `dsqm + 1` alone breaks `mu[3]` and the host term -> `Slot(SC_TZC)`.
///  * `dm + 1` with `dsqm` and `dm`'s three byte limbs recomputed leaves
///    `mu[5]` and the host term broken -> `Slot(SC_TZC)`. (`SC_DZC`'s `c6`
///    and `c7` break too; `SC_TZC` is slot 2 and `SC_DZC` slot 14, so the
///    first catch is `SC_TZC`. Stated, not argued away.)
///  * `dm + 1` made CONSISTENT everywhere it can be — `dsqm = dm^2`, the limbs,
///    `a1m = ss + Ceps - dsqm` and `a2m = 2 dm - a1m` so that all four
///    relations and the host term hold over the integers, then `nm`, `rho_m`,
///    `sigma_m` and the whole feed-forward half recomputed so `SC_DZC` holds
///    too. What is left is the isqrt WINDOW: `a1m = ss + Ceps - (dm+1)^2 < 0`
///    because `a1m <= 2 dm` honestly, and a negative value's top byte limb
///    leaves `[0, 256)`. Nothing but the byte lookup can see it ->
///    `Catch::LogUp`. This is the case that shows `a1m, a2m >= 0` is what
///    pins `dm` to `isqrt(ss)`.
#[test]
fn the_norm_m_denominator_is_pinned_by_its_isqrt_witness() {
    expect_rejection("dsqm (+1)", Catch::Slot(SC_TZC), |_, w| {
        w.planes[A_DSQM][0] += 1;
    });
    expect_rejection("dm (+1, dsqm and dm's byte limbs recomputed)", Catch::Slot(SC_TZC), |_, w| {
        let dm = w.planes[A_DM][0] + 1;
        w.planes[A_DM][0] = dm;
        w.planes[A_DSQM][0] = dm * dm;
        put_limbs_m(w, 0, 0, dm);
    });
    expect_rejection("dm (+1, consistent everywhere the integers allow)", Catch::LogUp, |ff, w| {
        let t = pick("dm", T, |t| {
            let mut probe = Witness { planes: w.planes.clone() };
            shift_norm_m_denominator(&mut probe, t);
            recompute_norm_m_row(&mut probe, ff, t) && recompute_from_nm(&mut probe, ff)
        });
        shift_norm_m_denominator(w, t);
        assert!(recompute_norm_m_row(w, ff, t));
        assert!(recompute_from_nm(w, ff));
    });
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// `dm + 1` on row `t` with `dsqm`, the limbs and the isqrt witness pair
/// `(a1m, a2m)` all moved with it, so that every `SC_TZC` relation and its
/// host term still hold over the integers. `a1m` goes negative, which is
/// exactly the thing the byte class forbids.
fn shift_norm_m_denominator(w: &mut Witness, t: usize) {
    let ss: i64 = NORM_CEPS + (0..D).map(|i| w.planes[A_X1][t * D + i].pow(2)).sum::<i64>();
    let dm = w.planes[A_DM][t] + 1;
    let a1m = ss - dm * dm;
    let a2m = 2 * dm - a1m;
    w.planes[A_DM][t] = dm;
    w.planes[A_DSQM][t] = dm * dm;
    put_limbs_m(w, 0, t, dm);
    put_limbs_m(w, 3, t, a1m);
    put_limbs_m(w, 6, t, a2m);
}

/// (c) One limb of `norm_m`'s isqrt witness shifted by the suite's `(+256, -1)`
/// pattern: `l0 + 256 l1` is unchanged, so `dm - dlm` and `2 dm - a1m - a2m`
/// still hold exactly and the value the relation reads is the same.
///
/// PREDICTED: the only thing broken is that the low limb has left `[0, 256)`
/// and has no row in the U8 table. `A_LIMBM` is read by `byte(A_LIMBM)`
/// (`layout.rs:315`) through `SC_LZC`'s helper, so the one value-0 LogUp sum
/// claim must catch it: `Catch::LogUp`.
#[test]
fn a_norm_m_limb_outside_its_byte_range_is_rejected_by_the_lookups() {
    for (name, base) in [("dm's limbs", 0usize), ("a1m's limbs", 3), ("a2m's limbs", 6)] {
        expect_rejection(name, Catch::LogUp, move |_, w| {
            w.planes[A_LIMBM][base * T] += 256;
            w.planes[A_LIMBM][(base + 1) * T] -= 1;
        });
    }
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// (d) The `rho_m` / `sigma_m` window. `(nm - 1, rho_m + den, sigma_m - den)`
/// with `den = 2^12 dm` satisfies BOTH norm_m relations of `SC_DZC` over the
/// integers — `c6` loses `2^12 dm` on the quotient term and gains it on the
/// remainder, and `c7 = sigma + rho + 1 - 2^12 dm` is unchanged — so the
/// division identity alone does not pin the quotient. The whole feed-forward
/// half is recomputed from `nm - 1`, and `nm - 1` stays inside `sym(A_YM)`.
///
/// PREDICTED: only the WINDOWS are left. `sigma_m - den < 0`, so its top byte
/// limb leaves `[0, 256)` (`byte(A_MS0 + 3)` and `scaled(A_MS0 + 3, 8)`,
/// `layout.rs:330-331`); `rho_m + den` may also leave `[0, 2^29)`. Either way
/// the catch is the one value-0 LogUp sum claim: `Catch::LogUp`. This is the
/// test that the norm_m quotient is pinned by its remainder windows.
#[test]
fn the_norm_m_quotient_is_pinned_by_its_remainder_windows() {
    expect_rejection("nm - 1 with rho_m + den and sigma_m - den", Catch::LogUp, |ff, w| {
        let k = pick("norm_m window", T * D, |k| {
            if w.planes[A_YM][k] <= -127 {
                return false;
            }
            let mut probe = Witness { planes: w.planes.clone() };
            shift_norm_m_quotient(&mut probe, k);
            recompute_from_nm(&mut probe, ff)
        });
        shift_norm_m_quotient(w, k);
        assert!(recompute_from_nm(w, ff));
    });
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}

/// `(nm, rho_m, sigma_m) -> (nm - 1, rho_m + den, sigma_m - den)` at one index.
fn shift_norm_m_quotient(w: &mut Witness, idx: usize) {
    let den = w.planes[A_DM][idx / D] << (NORM_TN + 1);
    let rho = l4(w, A_MR0, idx) + den;
    let sigma = l4(w, A_MS0, idx) - den;
    w.planes[A_YM][idx] -= 1;
    for k in 0..4 {
        w.planes[A_MR0 + k][idx] = limb(rho, k, 4);
        w.planes[A_MS0 + k][idx] = limb(sigma, k, 4);
    }
}

// ------------------------------------- the activation pair lookup (H-2, H-3)

/// ERRATUM E-22's OWN CASE, and the most valuable test in this file: an index
/// where `u16 = 0`. There the product relation `f0 = a16 u16 - 2^14 h16 - rh +
/// 2^13` reads `a16 * 0` and says NOTHING about `a16`; `h16 = 0` and
/// `rh = 2^13` are what they were. `a16` is moved to another legal int16 that
/// is NOT `act[g8 + 128]`, and NOTHING else is recomputed, because nothing
/// else changes.
///
/// PREDICTED: the pair lookup `f_act` (`argument.rs:766`) binds
/// `(g8 + 128, a16)` to a row of the public activation table, and it is the
/// ONLY other relation `a16` appears in. The prover can still invert whatever
/// denominator it likes (it commits `H` after alpha), but the multiplicity
/// histogram it derives counts the miss into entry 0, so the one value-0 sum
/// claim fails: `Catch::LogUp`. If this case ever VERIFIES, `a16` is an
/// unconstrained plane at every zero of `u16` and the int16 premise under the
/// whole no-wraparound argument is unfounded.
#[test]
fn an_activation_value_at_a_zero_up_output_is_rejected_by_the_pair_lookup() {
    let (blk, input, k, how) = a_zero_up_case();
    // MEASURED, and pinned so that a fixture change cannot silently downgrade
    // this to the easy case (erratum H-3): the public synthetic fixture has no
    // index with `u16 = 0`, so the case is built from public weights.
    assert_eq!(how, "column 0 of Wu zeroed, built here from the public synthetic weights", "the fixture now has its own zero of u16: use it and say so");
    expect_rejection_for(&format!("a16 at an index with u16 = 0 ({how})"), &blk, &input, Catch::LogUp, |_, w| {
        assert_eq!(w.planes[A_U16][k], 0, "the case must sit at a zero of u16");
        // a different legal int16, off this index's table row; h16 and rh are
        // unchanged because the product is 0 either way
        let before = (w.planes[A_H16][k], w.planes[A_RH0][k], w.planes[A_RH1][k]);
        w.planes[A_A16][k] = if w.planes[A_A16][k] == 0 { 1 } else { 0 };
        assert_eq!((w.planes[A_H16][k], w.planes[A_RH0][k], w.planes[A_RH1][k]), before);
    });
    prove_tampered_for(&blk, &input, |_, _| {}).expect("the honest proof must verify beside the tamper");
}

/// A public synthetic case with an index where `u16 = 0`, and how it was
/// obtained. If the fixture has no such index, one is BUILT from the public
/// synthetic weights by zeroing one column of `Wu`: the up matmul
/// `u16[t, j] = sum_i nm[t, i] Wu[i, j]` is then 0 in that column for every
/// row, whatever `nm` is. Everything else — the attention half, `gamma_m`,
/// `Wg`, `Wd` and the activation table — is the fixture's own, the statement
/// stays public and digested, and the prover and the verifier are given the
/// same one.
fn a_zero_up_case() -> (BlockPublic, Vec<i16>, usize, &'static str) {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let w = witness::build(blk.attention(), blk.feed_forward(), &input).expect("the public synthetic fixture is accepted");
    if let Some(k) = (0..T * F).find(|k| w.planes[A_U16][*k] == 0) {
        return (blk, input, k, "an index of the public synthetic fixture itself");
    }
    let ff = blk.feed_forward();
    let mut wu = ff.wu_t.clone();
    for i in 0..D {
        wu[i * F] = 0;
    }
    let built = BlockPublic::new(
        blk.attention().clone(),
        FeedForwardPublic::new(&ff.gamma_m, &ff.wg_t, &wu, &ff.wd_t, &ff.act).expect("a zeroed Wu column is a legal public statement"),
    );
    let w = witness::build(built.attention(), built.feed_forward(), &input).expect("the zero-column statement is still provable");
    let k = (0..T * F).find(|k| w.planes[A_U16][*k] == 0).expect("a zero column of Wu gives u16 = 0");
    (built, input, k, "column 0 of Wu zeroed, built here from the public synthetic weights")
}

/// The activation MULTIPLICITY row `A_MACT`, as far as a test can reach it.
///
/// WHAT THIS DOES NOT DO, said plainly: `A_MACT` is not a witness plane.
/// `is_multiplicity` (`layout.rs:218-220`) keeps it out of the committed
/// planes the witness fills (`protocol.rs:270`, `:283-287`) and `prove_inner`
/// DERIVES the row from the witness itself (`:302-312`), so no edit here can
/// set a multiplicity directly; only a modified prover could, and giving one a
/// hook would mean a release-reachable path into `protocol.rs`.
///
/// WHAT IT DOES: it moves one unit of multiplicity from one table row to
/// another through the prover's own bucketing rule, with the total preserved.
/// An activation use whose `(index, value)` pair is off its table row is
/// counted into entry 0 (`protocol.rs:306`), so row `g8 + 128` loses one count
/// and row 0 gains one while `act_lookups` stays 512 — and the denominator
/// column that use contributes has no matching row at all.
///
/// PREDICTED: no relation of `SC_FZC` can see it (the product is recomputed,
/// every class holds), so the one value-0 LogUp sum claim must:
/// `Catch::LogUp`.
#[test]
fn a_moved_activation_multiplicity_is_rejected_by_the_logup_sum_claim() {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let ff = blk.feed_forward();
    let mut w = witness::build(blk.attention(), ff, &input).expect("the public synthetic fixture is accepted");
    let k = pick("a16 (multiplicity)", T * F, |k| {
        if w.planes[A_A16][k] >= 32767 {
            return false;
        }
        let mut probe = Witness { planes: w.planes.clone() };
        probe.planes[A_A16][k] += 1;
        recompute_from_product(&mut probe, ff)
    });
    // the row that loses the count; entry 0 gains it
    let row = w.planes[A_G8][k] + 128;
    assert_ne!(row, 0, "the case must move the count OFF a row other than entry 0");
    w.planes[A_A16][k] += 1;
    assert!(recompute_from_product(&mut w, ff));
    let output = w.output().expect("the tampered output is in class");
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    let (receipt, stats) = prove_inner(&blk, w, &expected, owners).expect("the prover does not pre-check any relation");
    // the TOTAL is preserved: one unit moved between rows, nothing created
    assert_eq!(stats.act_lookups, 512, "the activation histogram totals the Dom::F cube");
    let err = verify_inner(&blk, &expected, &receipt).expect_err("a moved activation multiplicity VERIFIED");
    assert!(Catch::LogUp.matches(&err), "expected {}, got `{err}`", Catch::LogUp.describe());
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}
