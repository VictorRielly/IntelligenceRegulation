//! **STAGE 17, ruling T-6 (as amended): the tag is load-bearing, not
//! decorative.** The isolated layer controls live in `zkp-core` (the column
//! digest, the salted leaf, the Merkle node and the transcript, each under
//! the right key, another role's key and no key); what is here is the
//! profile-level half: WHICH shapes are tagged, WHAT their keys are, and that
//! a proof made under one rule is refused under the other, in both
//! directions, at a real profile.
//!
//! Nothing in this file is a privacy or a soundness acceptance. It pins the
//! separation the disposition asks for and nothing beyond it.

use super::shape::Shape;
use super::witness;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::{prepare_endpoints, BlockPublic, ExpectedIo, IoSpec, Receipt};
use super::layout::{Ids, A_X, A_X2};
use zkp_core::hashtag::HashTag;

fn hex(d: &[u8; 32]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

/// The forced-legacy hook of `shape.rs`, with a `Drop` that clears it. The
/// suite runs `--test-threads=1`, so a test that panicked with the hook still
/// set would poison every later test on the same thread; this cannot.
pub(super) struct ForcedLegacy;

impl ForcedLegacy {
    pub(super) fn on() -> ForcedLegacy {
        super::shape::set_force_legacy_hash_rule(true);
        ForcedLegacy
    }
}

impl Drop for ForcedLegacy {
    fn drop(&mut self) {
        super::shape::set_force_legacy_hash_rule(false);
    }
}

fn ctx() -> [u8; 32] {
    *blake3::hash(b"stage 17: the hash tag's own test context").as_bytes()
}

/// An honest rung-G block, proved under whatever rule is in force NOW.
fn rung_g_proof() -> (Shape, BlockPublic, ExpectedIo, Receipt) {
    let sh = Shape::rung_g();
    let (public, ff, input) = super::grow_tests::tame_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-G honest witness");
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect() };
    let (pin, pout) = (plane(ids.at(A_X)), plane(ids.at(A_X2)));
    let spec = IoSpec::new_shaped(&sh, ctx(), 0, 0).expect("the rung-G endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout).expect("the rung-G endpoint owners");
    let blk = BlockPublic::new(public, ff);
    let (receipt, _) = prove_inner_at(&sh, &blk, w, &expected, owners).expect("the rung-G block proves");
    (sh, blk, expected, receipt)
}

/// **WHICH PROFILES ARE TAGGED, and their eight keys.** The two legacy-rule
/// profiles are named by the ruling and are the only two: the byte-frozen toy
/// (D19 records its deviation, D22 rests on its bytes) and the frozen-seam
/// development rung, which keeps the legacy rule WHOLLY because its endpoint
/// is committed inside `private_seam.rs` and a profile is never a mixture
/// (ruling T-2 as amended).
///
/// The eight hex literals are the same numbers the Python tools must
/// re-derive; they are pinned in `zkp_core::hashtag`'s own tests too, and
/// this test is the one that ties them to the SHAPES.
#[test]
fn the_toy_and_the_frozen_seam_rung_are_legacy_and_the_other_two_are_tagged() {
    for sh in [Shape::toy(), Shape::rung()] {
        let t = sh.hash_tag();
        assert!(t.is_legacy(), "{} must hash under the legacy rule", sh.name);
        assert_eq!(t.rule_name(), "legacy");
        assert!(sh.hashes_under_the_legacy_rule(), "{}", sh.name);
        assert!(t.transcript_key().is_none() && t.column_key().is_none() && t.leaf_key().is_none() && t.node_key().is_none());
    }
    let g = Shape::rung_g();
    assert!(!g.hashes_under_the_legacy_rule(), "rung-G must be tagged");
    let t = g.hash_tag();
    assert_eq!(t.rule_name(), "blake3-keyed/1");
    assert_eq!(hex(t.transcript_key().expect("keyed")), "51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe");
    assert_eq!(hex(t.column_key().expect("keyed")), "2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c");
    assert_eq!(hex(t.leaf_key().expect("keyed")), "fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032");
    assert_eq!(hex(t.node_key().expect("keyed")), "8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc");
    // **STAGE 22.** The four-key-value-head development shape is a NEW
    // profile (D17) and is therefore TAGGED, with a key set of its own that
    // shares nothing with rung-G's although the two shapes differ only in
    // the head axis: the tag is keyed off the PROFILE STRING, so a new shape
    // cannot exist without a new key set.
    let k4 = Shape::rung_k4();
    assert!(!k4.hashes_under_the_legacy_rule(), "rung-K4 must be tagged");
    assert_eq!(k4.hash_tag().rule_name(), "blake3-keyed/1");
    assert_eq!(k4.hash_tag(), HashTag::for_profile(k4.profile));
    assert_ne!(k4.hash_tag(), g.hash_tag(), "rung-K4 and rung-G share a key set");
    let m = Shape::m125();
    assert!(!m.hashes_under_the_legacy_rule(), "125M must be tagged");
    let t = m.hash_tag();
    assert_eq!(hex(t.transcript_key().expect("keyed")), "125f9b4d44ac3c46712a35419cdeda6c1428db443ccaf58da67f35b15b37291c");
    assert_eq!(hex(t.column_key().expect("keyed")), "d5fc391cc58eed85631b4c3dabc7d377477eb1a0a725aeccaec0f4d10061b135");
    assert_eq!(hex(t.leaf_key().expect("keyed")), "1dc6f7146ad501ede6d90b3071da2f3251d38137303ffcc0a6a48b7f89effe83");
    assert_eq!(hex(t.node_key().expect("keyed")), "798eb64ff187f6f3e8e889ac4c4742607ac71a71fa09e2944a0ecc5e8a42026b");
    // the tag is a function of the PROFILE STRING and of nothing else, so a
    // new shape cannot exist without a new key set (the memo's option D)
    assert_eq!(g.hash_tag(), HashTag::for_profile(g.profile));
    assert_eq!(m.hash_tag(), HashTag::for_profile(m.profile));
    assert_ne!(g.hash_tag(), m.hash_tag(), "two profiles share a key set");
    assert_ne!(k4.hash_tag(), m.hash_tag(), "two profiles share a key set");
}

/// The hook can only ever weaken to the LEGACY rule, so it cannot tag the
/// frozen toy and cannot move one of its bytes even if a test leaked it.
#[test]
fn the_test_hook_can_only_force_the_legacy_rule() {
    let guard = ForcedLegacy::on();
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::m125()] {
        assert!(sh.hash_tag().is_legacy(), "{}: the hook produced a tag", sh.name);
    }
    drop(guard);
    assert!(Shape::toy().hash_tag().is_legacy(), "the toy moved");
    assert!(!Shape::rung_g().hash_tag().is_legacy(), "the hook did not clear");
}

/// **THE TEST THAT MAKES THE TAG LOAD-BEARING (ruling T-6 as amended):
/// cross-rule rejection at rung-G, in BOTH directions.** Whatever the first
/// refusal is, is what is asserted and what the ledger records — a
/// full-profile mismatch changes the transcript's very first hash, so
/// Fiat–Shamir consistency objects long before any Merkle check does. The
/// layers themselves are pinned separately by the isolated controls in
/// `zkp-core`.
#[test]
fn a_rung_g_proof_is_refused_under_the_other_hash_rule_in_both_directions() {
    // STAGE 41 (ruling CS-4): an endpoint policy's spec carries the hash tag
    // it was made under, and every verifier entry now refuses a spec whose
    // tag is not its own shape's BY NAME, before anything is hashed. So that
    // this test still reaches the hashing layer it exists to exercise, each
    // verifier is handed the policy of ITS OWN rule over the same two roots
    // (the absorbed policy bytes are identical: the tag is not in them), and
    // the refusal is asserted not to be CS-4's.
    let own_policy = |e: &ExpectedIo| ExpectedIo::from_roots(IoSpec::new_shaped(&Shape::rung_g(), ctx(), 0, 0).expect("the rung-G endpoint spec"), e.input_root(), e.output_root());
    // (1) proved TAGGED, verified under the LEGACY rule
    let (sh, blk, expected, receipt) = rung_g_proof();
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the tagged rung-G proof verifies under its own tag");
    let e1 = {
        let _g = ForcedLegacy::on();
        let legacy_policy = own_policy(&expected);
        assert_eq!(legacy_policy.to_bytes(), expected.to_bytes(), "the policy bytes carry the hash rule");
        verify_inner_at(&sh, &blk, &legacy_policy, &receipt).expect_err("a TAGGED rung-G proof verified under the LEGACY rule")
    };
    // (2) proved under the LEGACY rule, verified TAGGED
    let (sh2, blk2, expected2, receipt2) = {
        let _g = ForcedLegacy::on();
        let made = rung_g_proof();
        verify_inner_at(&made.0, &made.1, &made.2, &made.3).expect("the legacy-rule rung-G proof verifies under the legacy rule");
        made
    };
    let e2 = verify_inner_at(&sh2, &blk2, &own_policy(&expected2), &receipt2).expect_err("a LEGACY-rule rung-G proof verified under the TAG");
    eprintln!("STAGE 17 cross-rule refusals at rung-G:\n  tagged proof, legacy verifier: {e1}\n  legacy proof, tagged verifier: {e2}");
    assert!(!e1.is_empty() && !e2.is_empty());
    assert!(!e1.contains("ruling CS-4") && !e2.contains("ruling CS-4"), "the cross-rule refusal stopped at the policy check, not the hashing layer");
    // and the policy of the OTHER rule is refused by ruling CS-4's name,
    // before anything is hashed
    let e3 = {
        let _g = ForcedLegacy::on();
        verify_inner_at(&sh, &blk, &expected, &receipt).expect_err("a TAGGED policy verified under the LEGACY rule")
    };
    assert!(e3.starts_with("private block: ruling CS-4 — the endpoint policy does not fit the shape it is proved at: its hash tag"), "the tagged policy under the legacy rule: {e3}");
    // and the toy, which is never tagged, is untouched by either direction
    assert!(Shape::toy().hash_tag().is_legacy(), "the toy must never be tagged");
}
