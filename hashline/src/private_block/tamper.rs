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
    IoSpec::new(*blake3::hash(b"private block: public synthetic tamper context").as_bytes(), -3, -3).unwrap()
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

/// one biased requantization, exactly as `witness.rs` does it:
/// `acc = 2^sh y + r' - 2^(sh-1)` with `r'` in `[0, 2^sh)`
fn requant(acc: i64, sh: u32) -> (i64, i64) {
    let y = (acc + (1i64 << (sh - 1))) >> sh;
    (y, acc - (y << sh) + (1i64 << (sh - 1)))
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

/// One attempt: honest witness, honest endpoints (the output endpoint commits
/// the HONEST value, fixed before the edit, exactly as an endpoint owner
/// would), then the edit, then a full proof and a full verification.
fn prove_tampered(edit: impl FnOnce(&FeedForwardPublic, &mut Witness)) -> Result<(), String> {
    let (public, input) = AttentionPublic::synthetic_fixture();
    let ff = FeedForwardPublic::synthetic_fixture();
    let mut w = witness::build(&public, &ff, &input).expect("the public synthetic fixture is accepted");
    let output = w.output().expect("the honest output plane is in class");
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    edit(&ff, &mut w);
    // the prover does not pre-check any relation: a false witness still yields
    // a receipt, and that receipt must not verify
    let (receipt, _) = prove_inner(&public, &ff, &w, &expected, owners)?;
    verify_inner(&public, &ff, &expected, &receipt).map(|_| ())
}

fn expect_rejection(name: &str, catch: Catch, edit: impl FnOnce(&FeedForwardPublic, &mut Witness)) {
    let err = prove_tampered(edit).expect_err(&format!("tamper `{name}` VERIFIED"));
    assert!(catch.matches(&err), "tamper `{name}`: expected the catch at {}, got `{err}`", catch.describe());
}

/// the first index at which `ok` holds, or a hard failure naming the case
fn pick(name: &str, n: usize, ok: impl Fn(usize) -> bool) -> usize {
    (0..n).find(|k| ok(*k)).unwrap_or_else(|| panic!("tamper `{name}`: no index of the public synthetic fixture admits a consistent tamper"))
}

// ---------------------------------------------------------------- the suite

/// T2 section G.1, the test the whole of Tier 2 exists for: with `z16`
/// tampered CONSISTENTLY — `xres2 = xres1 + z16` still holds and every class
/// proof still passes — the verifier must still reject, because `z16` is now
/// derived from `nm` through the three matmuls, the activation lookup and the
/// product. Under Tier 1 alone this receipt verified and the block's output
/// was whatever the prover chose.
#[test]
fn a_consistently_tampered_z16_is_rejected_at_the_down_requantization() {
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

/// T2 row T-z1, the int16 CLASS test, kept with its two catches and labelled
/// as such (erratum E-19): `z16 + 2^16` with `rd` "compensated" pushes `rd`
/// out of its window AND `A_ZL1` out of `[0, 256)`, so both lookups have no
/// row and the one value-0 sum claim on `H` fails. It cannot isolate a single
/// relation and is not used to show one is present; it shows the class is
/// enforced at all.
#[test]
fn a_z16_outside_int16_is_rejected_by_the_lookups() {
    expect_rejection("z16 (+2^16 with rd compensated: two independent catches)", Catch::LogUp, |_, w| {
        w.planes[A_Z16][0] += 65536;
        w.planes[A_RDL][0] -= 65536 * (1 << SH_Z);
        w.planes[A_X2][0] += 65536;
        // the limbs are recomputed from the out-of-class values, which is
        // exactly what makes A_ZL1 leave [0, 256) in the field
        w.planes[A_ZL1][0] += 256;
        w.planes[A_X2L1][0] += 256;
    });
    prove_tampered(|_, _| {}).expect("the honest proof must verify beside every tamper");
}
