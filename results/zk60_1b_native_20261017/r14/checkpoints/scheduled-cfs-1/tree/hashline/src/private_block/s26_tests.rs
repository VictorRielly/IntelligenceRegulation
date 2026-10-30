//! **STAGE 26 — THE GENERATORS' SEED DERIVATIONS, STRUCTURALLY SEPARATED AT
//! EVERY UNFROZEN PROFILE.**
//!
//! **The finding.** `ZK60_TOY_ROUTE_A_REEXAMINATION.md` **B-1**: a proof
//! makes several randomness generators, each `ZkRng::from_os(domain)`, whose
//! key is `blake3_keyed(32 fresh /dev/urandom bytes,
//! b"hashline-zk-os-rng/v1/" ‖ domain)`. At the frozen toy the TWO ENDPOINT
//! generators are handed a BYTE-IDENTICAL domain, so the two entropy reads
//! are the only thing separating them: were the two reads ever equal, the
//! two endpoint commitments would share every pad, every salt and every mask
//! row, and code condition C-H5 would be false. The toy statement's §9 item
//! 6 records it as a sentence; this stage is the code half of the same
//! ruling, for the profiles that are allowed to move.
//!
//! **The ruling, as implemented.** At every UNFROZEN profile a generator's
//! domain is
//!
//! ```text
//! <versioned use literal> ‖ <role byte or index, fixed width>
//!                         ‖ <a public spec digest, or the profile string>
//! ```
//!
//! built by `hash_domain::{endpoint,boundary,single_block,run}_seed_domain`.
//! The **frozen toy** and the **frozen-seam development rung** keep the bare
//! profile string they have always passed, and `private_seam.rs` is a file
//! this lane may not edit, so their generators do not move by a byte.
//!
//! **Nothing verifier-visible moves, and nothing could.** A generator is
//! prover-side: the verifier never sees one, no domain is absorbed, hashed
//! into a statement or written to a wire, and the draw ORDER and COUNTS from
//! each stream are untouched. What changes is the 22-byte-prefixed input of
//! one keyed BLAKE3 call per generator.
//!
//! **The capture rule.** Every field of every domain is PUBLIC — a fixed
//! literal, a role byte, a boundary index, a profile string, or a STATEMENT
//! digest (`EndpointSpecG::digest`, `BoundarySpec::digest`), which is a
//! function of the context, the shape numbers and the scale. No witness
//! value and no commitment ROOT enters a domain, and
//! [`the_domains_are_built_from_public_fields_and_nothing_else`] checks the
//! layout field by field rather than asserting it in prose.
//!
//! **No privacy and no soundness acceptance is claimed here.** The
//! independence of separate `/dev/urandom` reads is still an assumption
//! (J-2); what this stage adds is that the assumption no longer stands
//! alone at the unfrozen profiles.

use super::boundary::BoundarySpec;
use super::endpoint_g::{self, EndpointRole, EndpointSpecG};
use super::hash_domain;
use super::run::{RunShape, RunStatement, RUN_PROFILE_M125, RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4};
use super::shape::Shape;
use super::{BlockPublic, ExpectedIo, IoSpec};
use crate::merkle::Digest;

// ---------------------------------------------------------------------------
// shared helpers
// ---------------------------------------------------------------------------

/// One of this crate's own source files, read at test time — `s24_tests` and
/// `s25_tests`' resolver, so that all three stages read the same tree.
fn source(name: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(name);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("stage 26: {}: {e}", p.display()))
}

/// The part of a source file above its own `#[cfg(test)] mod tests {`.
fn production_text(src: &str) -> &str {
    let cut = src.find("\n#[cfg(test)]\nmod tests {").map(|k| k + 1).unwrap_or(src.len());
    &src[..cut]
}

fn s26_context() -> Digest {
    *blake3::hash(b"stage 26: the generators' own test context").as_bytes()
}

/// the five registered block shapes
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::m125()]
}

/// the three registered run profiles and the `L` each is registered at
fn every_run() -> Vec<(&'static str, Shape, usize)> {
    vec![(RUN_PROFILE_RUNG_G, Shape::rung_g(), 3), (RUN_PROFILE_RUNG_K4, Shape::rung_k4(), 3), (RUN_PROFILE_M125, Shape::m125(), 12)]
}

/// A REAL `RunStatement`, built with no commitment — `ExpectedIo::from_roots`
/// takes the two external roots as given, so a twelve-block 125M statement
/// costs its twelve public digests and nothing else.
fn run_statement(sh: &Shape, profile: &str, l: usize) -> RunStatement {
    let rs = if profile == RUN_PROFILE_M125 {
        RunShape::m125(l).expect("the 125M run shape")
    } else if profile == RUN_PROFILE_RUNG_K4 {
        RunShape::rung_k4(l).expect("the rung-K4 run shape")
    } else {
        RunShape::rung_g(l).expect("the rung-G run shape")
    };
    let spec = IoSpec::new_shaped(sh, s26_context(), 0, 0).expect("the run's endpoint spec");
    let expected = ExpectedIo::from_roots(spec, [1u8; 32], [2u8; 32]);
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let one = BlockPublic::new(public, ff);
    let blocks: Vec<BlockPublic> = (0..l).map(|_| one.clone()).collect();
    RunStatement::new(rs, s26_context(), expected, &blocks, &vec![(0, 0); l]).expect("the run statement")
}

/// The FIXED 22-byte prefix of every seed derivation, read off
/// `zkp-core/src/rng.rs` (`from_entropy_reader`) rather than retyped from a
/// memo: `blake3::Hasher::new_keyed(&entropy)` then `b"hashline-zk-os-rng/v1/"`
/// then the domain.
const SEED_PREFIX: &[u8] = b"hashline-zk-os-rng/v1/";

/// The bytes the keyed BLAKE3 call actually hashes for a generator with this
/// domain. "Two generators have different derivation inputs" is a statement
/// about THESE bytes, which is why the tests below build them.
fn derivation_input(domain: &[u8]) -> Vec<u8> {
    let mut v = SEED_PREFIX.to_vec();
    v.extend_from_slice(domain);
    v
}

/// Every generator domain ONE single-block proof at this shape uses, named.
/// A single block makes three: the prover's own and one per external
/// endpoint. (The frozen profiles' endpoints are `private_seam.rs`'s, whose
/// domain is that file's private constant; those two are handled separately
/// by [`the_two_frozen_profiles_keep_the_domains_they_have`].)
fn block_domains(sh: &Shape) -> Vec<(String, Vec<u8>)> {
    let mut out = vec![(format!("the single-block prover at `{}`", sh.profile), hash_domain::single_block_seed_domain(sh))];
    if sh.endpoint_general {
        let spec = IoSpec::new_shaped(sh, s26_context(), 0, 0).expect("the endpoint spec");
        let [si, so] = spec.endpoints_g().expect("the two generalised endpoints");
        out.push(("the external INPUT endpoint".to_string(), endpoint_g::seed_domain(&si, EndpointRole::Input)));
        out.push(("the external OUTPUT endpoint".to_string(), endpoint_g::seed_domain(&so, EndpointRole::Output)));
    }
    out
}

/// Every generator domain ONE run uses, named: the run prover's one stream,
/// the two external endpoints, and — although no boundary makes a generator
/// today — the domain each internal boundary WOULD use, which is written and
/// separated now so that it cannot be improvised later (see
/// `boundary::prepare`'s doc comment).
fn run_domains(sh: &Shape, profile: &str, l: usize) -> Vec<(String, Vec<u8>)> {
    let st = run_statement(sh, profile, l);
    let mut out = vec![(format!("the run prover at `{profile}`"), hash_domain::run_seed_domain(profile))];
    let spec = IoSpec::new_shaped(sh, s26_context(), 0, 0).expect("the endpoint spec");
    let [si, so] = spec.endpoints_g().expect("the two generalised endpoints");
    out.push(("the external INPUT endpoint".to_string(), endpoint_g::seed_domain(&si, EndpointRole::Input)));
    out.push(("the external OUTPUT endpoint".to_string(), endpoint_g::seed_domain(&so, EndpointRole::Output)));
    for k in 0..l.saturating_sub(1) {
        let b = st.boundary_spec(k).expect("an internal boundary of this run");
        out.push((format!("internal boundary {}", b.index()), hash_domain::boundary_seed_domain(b.index(), &b.digest())));
    }
    out
}

// ---------------------------------------------------------------------------
// 1 — FINDING B-1 ITSELF: the two endpoints of one statement
// ---------------------------------------------------------------------------

/// **FAILING-FIRST, AND THE POINT OF THE STAGE.** Before this stage
/// `endpoint_g::prepare` seeded BOTH endpoints of a statement with the
/// constant `DOMAIN = b"hashline/private-block/general-endpoint/v1"`, so the
/// two key-derivation inputs were the same 64 bytes and the two
/// `/dev/urandom` reads were the whole separation.
///
/// Three things are asserted, in increasing strength:
///
/// 1. at EVERY profile with a generalised endpoint, the two endpoints' real
///    derivation inputs differ;
/// 2. they differ **even when the two spec digests are equal** — the case
///    the role byte exists for, and the one a geometry with symmetric slot
///    indices would produce. This is checked by handing BOTH roles the SAME
///    digest;
/// 3. and the two inputs are the SAME LENGTH, which is deliberate: the role
///    is a fixed-width byte, so the separation is in the bytes and never in
///    a length a hash-input table would have to carry twice.
#[test]
fn the_two_endpoint_generators_of_one_statement_derive_their_keys_from_different_inputs() {
    for sh in every_shape().into_iter().filter(|s| s.endpoint_general) {
        let spec = IoSpec::new_shaped(&sh, s26_context(), 0, 0).expect("the endpoint spec");
        let [si, so] = spec.endpoints_g().expect("the two generalised endpoints");
        let din = derivation_input(&endpoint_g::seed_domain(&si, EndpointRole::Input));
        let dout = derivation_input(&endpoint_g::seed_domain(&so, EndpointRole::Output));
        assert_ne!(din, dout, "{}: the two endpoint generators derive their keys from BYTE-IDENTICAL inputs (finding B-1)", sh.name);
        assert_eq!(din.len(), dout.len(), "{}: the two endpoint derivation inputs have different LENGTHS; the role is supposed to be fixed-width", sh.name);
        // the role byte alone, with the geometry held equal
        let one = si.digest();
        let a = hash_domain::endpoint_seed_domain(hash_domain::ROLE_ENDPOINT_IN, &one);
        let b = hash_domain::endpoint_seed_domain(hash_domain::ROLE_ENDPOINT_OUT, &one);
        assert_ne!(a, b, "{}: two endpoints of IDENTICAL geometry share a generator domain; the role byte does nothing", sh.name);
        assert_eq!(a.len(), b.len(), "{}: the role is not fixed-width", sh.name);
        // and the pair differs in EXACTLY the role position
        let differing: Vec<usize> = a.iter().zip(b.iter()).enumerate().filter(|(_, (x, y))| x != y).map(|(i, _)| i).collect();
        assert_eq!(differing.len(), 1, "{}: the two role domains differ in {} positions, not one", sh.name, differing.len());
        eprintln!("S26/1 {}: two endpoint derivation inputs, {} B each, differing at domain offset {}", sh.name, din.len(), differing[0]);
    }
}

// ---------------------------------------------------------------------------
// 2 — PAIRWISE DISTINCTNESS, within one proof and within one run
// ---------------------------------------------------------------------------

/// **THE STRUCTURAL PROPERTY THE RULING ASKS FOR: within one proof, no two
/// generators' derivation inputs are equal.** Every domain a three-block run
/// uses is built and the whole set is compared pairwise — the run prover's
/// one stream, the two external endpoints, and the two internal boundaries'
/// — and the same for a single block at every unfrozen profile.
///
/// This FAILED before the stage: the two endpoints shared a domain, and the
/// two boundaries shared the module's spec-digest label.
///
/// The non-vacuity is that the comparison really is over distinct objects:
/// the set is asserted to have the expected SIZE at each profile, so a
/// builder returning an empty vector could not pass.
#[test]
fn no_two_generators_of_one_proof_share_a_derivation_input() {
    let check = |what: &str, domains: &[(String, Vec<u8>)], want: usize| {
        assert_eq!(domains.len(), want, "{what}: {} generator domains, expected {want}", domains.len());
        for i in 0..domains.len() {
            for j in i + 1..domains.len() {
                let (a, b) = (&domains[i], &domains[j]);
                assert_ne!(
                    derivation_input(&a.1),
                    derivation_input(&b.1),
                    "{what}: `{}` and `{}` derive their keys from the SAME input; only the two entropy reads separate them",
                    a.0,
                    b.0
                );
            }
        }
        let lens: Vec<usize> = domains.iter().map(|(_, d)| SEED_PREFIX.len() + d.len()).collect();
        eprintln!("S26/2 {what}: {} generators, pairwise distinct derivation inputs, lengths {lens:?}", domains.len());
    };
    for sh in every_shape().into_iter().filter(|s| s.endpoint_general) {
        check(&format!("one block at {}", sh.name), &block_domains(&sh), 3);
    }
    for (p, sh, l) in every_run() {
        check(&format!("an L={l} run at `{p}`"), &run_domains(&sh, p, l), 3 + (l - 1));
    }
    // and across the two KINDS of proof at one geometry: a single block's
    // prover stream and a run's are not the same stream and must not share a
    // domain either
    for (p, sh, _) in every_run() {
        assert_ne!(
            hash_domain::single_block_seed_domain(&sh),
            hash_domain::run_seed_domain(p),
            "{}: a single block's prover and a run's prover share a generator domain",
            sh.name
        );
    }
}

// ---------------------------------------------------------------------------
// 3 — THE LENGTH TABLE, and the three lengths a derivation input may not have
// ---------------------------------------------------------------------------

/// **EVERY SEED-DERIVATION INPUT LENGTH THIS LANE PRODUCES, PRINTED, WITH THE
/// FOUR CONDITIONS IT MUST MEET.**
///
/// 1. **Not 64** — a salted Merkle leaf and a Merkle inner node are both 64
///    bytes (`zkp-core/src/merkle.rs:14-19`, `pcs.rs:640-645`). The
///    generalised endpoint's derivation input was EXACTLY 64 before this
///    stage (`22 + 42`), which is the sharpest row of the lane's hash
///    function separation table; it is 99 now.
/// 2. **Not 40** — the generator's own refill block, `key(32) ‖ counter(8)`.
/// 3. **Not 47** — a transcript squeeze, `state(32) ‖ "squeeze"(7) ‖
///    counter(8)`.
/// 4. **Never a multiple of eight**, so that the length can never be a
///    committed column's `8 · rows` and no new row count becomes dangerous
///    in the legacy length guard.
///
/// The frozen profiles are printed too, and their numbers are the ones they
/// have always had.
#[test]
fn every_seed_derivation_input_length_is_printed_and_clear_of_the_node_refill_and_squeeze() {
    // the fixed lengths, re-derived from the cited sources and not retyped
    assert_eq!(SEED_PREFIX.len(), 22, "the seed derivation's fixed prefix");
    let rng_src = source("../zkp-core/src/rng.rs");
    assert!(
        rng_src.contains("h.update(b\"hashline-zk-os-rng/v1/\");") && rng_src.contains("blake3::Hasher::new_keyed(&entropy)"),
        "`ZkRng::from_entropy_reader` no longer derives the key the way this stage's arithmetic assumes"
    );
    let forbidden: [(usize, &str); 3] = [(64, "a salted Merkle leaf / a Merkle inner node"), (40, "the generator's refill block"), (47, "a transcript squeeze")];

    let mut rows: Vec<(String, String, usize)> = Vec::new();
    for sh in every_shape() {
        rows.push((sh.name.to_string(), "the single-block prover".to_string(), hash_domain::single_block_seed_input_len(&sh)));
    }
    rows.push(("(any general endpoint)".to_string(), "an external endpoint".to_string(), hash_domain::endpoint_seed_input_len()));
    rows.push(("(any internal boundary)".to_string(), "a boundary, if one ever seeds its own".to_string(), hash_domain::boundary_seed_input_len()));
    for (p, _, _) in every_run() {
        rows.push((p.to_string(), "the run prover".to_string(), hash_domain::run_seed_input_len(p)));
    }
    eprintln!("--- STAGE 26: every seed-derivation input length this lane produces ---");
    for (profile, site, len) in &rows {
        eprintln!("    {len:>5} B   {site:<40} {profile}");
    }

    // (a) the three forbidden lengths, at every UNFROZEN site. The two frozen
    // profiles are exempt by name: their numbers cannot move and 61 / 66 / 50
    // are none of the three anyway, which is asserted rather than assumed.
    for sh in every_shape() {
        let len = hash_domain::single_block_seed_input_len(&sh);
        for (bad, what) in forbidden {
            assert_ne!(len, bad, "{}: the block prover's derivation input is {bad} bytes, the length of {what}", sh.name);
        }
        assert_ne!(len % 8, 0, "{}: the block prover's derivation input is a multiple of eight and would be a column's length", sh.name);
    }
    for (len, what) in [
        (hash_domain::endpoint_seed_input_len(), "the generalised endpoint"),
        (hash_domain::boundary_seed_input_len(), "an internal boundary"),
    ] {
        for (bad, kind) in forbidden {
            assert_ne!(len, bad, "{what}: the derivation input is {bad} bytes, the length of {kind}");
        }
        assert_ne!(len % 8, 0, "{what}: the derivation input is a multiple of eight");
    }
    for (p, _, _) in every_run() {
        let len = hash_domain::run_seed_input_len(p);
        for (bad, kind) in forbidden {
            assert_ne!(len, bad, "{p}: the run prover's derivation input is {bad} bytes, the length of {kind}");
        }
        assert_ne!(len % 8, 0, "{p}: the run prover's derivation input is a multiple of eight");
    }

    // (b) THE PINNED TABLE. The two FROZEN profiles' numbers are the ones the
    // reexamination measured and may not move; the six unfrozen ones are this
    // stage's.
    assert_eq!(hash_domain::single_block_seed_input_len(&Shape::toy()), 61, "the FROZEN toy's block-prover derivation input moved");
    assert_eq!(hash_domain::single_block_seed_input_len(&Shape::rung()), 66, "the FROZEN-SEAM rung's block-prover derivation input moved");
    assert_eq!(hash_domain::single_block_seed_input_len(&Shape::rung_g()), 116, "the rung-G block prover's derivation input");
    assert_eq!(hash_domain::single_block_seed_input_len(&Shape::rung_k4()), 117, "the rung-K4 block prover's derivation input");
    assert_eq!(hash_domain::single_block_seed_input_len(&Shape::m125()), 106, "the 125M block prover's derivation input");
    assert_eq!(hash_domain::endpoint_seed_input_len(), 99, "the generalised endpoint's derivation input");
    assert_eq!(hash_domain::boundary_seed_input_len(), 108, "an internal boundary's derivation input");
    assert_eq!(hash_domain::run_seed_input_len(RUN_PROFILE_RUNG_G), 125, "the rung-G run prover's derivation input");
    assert_eq!(hash_domain::run_seed_input_len(RUN_PROFILE_RUNG_K4), 126, "the rung-K4 run prover's derivation input");
    assert_eq!(hash_domain::run_seed_input_len(RUN_PROFILE_M125), 115, "the 125M run prover's derivation input");

    // (c) WITHIN ONE PROFILE the live seed derivations have DISTINCT lengths
    // too, which is what keeps `R1`'s own row of the hash-function separation
    // table free of an equal-length pair. (Two endpoints of one statement are
    // one KIND at one length, separated by the role byte — clause (a) of the
    // ruling, not a coincidence between two kinds.)
    for sh in every_shape().into_iter().filter(|s| s.endpoint_general) {
        assert_ne!(
            hash_domain::single_block_seed_input_len(&sh),
            hash_domain::endpoint_seed_input_len(),
            "{}: the block prover's and the endpoint's derivation inputs are the same length",
            sh.name
        );
    }
    for (p, _, l) in every_run() {
        let r = hash_domain::run_seed_input_len(p);
        assert_ne!(r, hash_domain::endpoint_seed_input_len(), "{p}: the run prover's and the endpoint's derivation inputs are the same length");
        if l > 1 {
            assert_ne!(r, hash_domain::boundary_seed_input_len(), "{p}: the run prover's and a boundary's derivation inputs are the same length");
        }
    }
    eprintln!("S26/3: 10 seed-derivation input lengths, none 64 / 40 / 47, none a multiple of eight, pairwise distinct within every profile");
}

// ---------------------------------------------------------------------------
// 4 — WHAT IS FROZEN STAYS FROZEN
// ---------------------------------------------------------------------------

/// **THE TWO FROZEN PROFILES DO NOT MOVE, and the frozen seam is not
/// touched.** The ruling applies at UNFROZEN profiles only, and the split is
/// exactly `Shape::hashes_under_the_legacy_rule` — the byte-frozen toy and
/// the frozen-seam development rung.
///
/// Also asserted, because the run builder has no frozen branch and needs one
/// if this ever stops being true: **no registered run profile is legacy.**
#[test]
fn the_two_frozen_profiles_keep_the_domains_they_have() {
    for sh in every_shape().into_iter().filter(|s| s.hashes_under_the_legacy_rule()) {
        assert_eq!(
            hash_domain::single_block_seed_domain(&sh),
            sh.profile.as_bytes().to_vec(),
            "{}: a FROZEN profile's generator domain is no longer the bare profile string",
            sh.name
        );
    }
    // and every UNFROZEN one really did change — otherwise the line above
    // would pass vacuously on a builder that never wraps anything
    for sh in every_shape().into_iter().filter(|s| !s.hashes_under_the_legacy_rule()) {
        assert_ne!(
            hash_domain::single_block_seed_domain(&sh),
            sh.profile.as_bytes().to_vec(),
            "{}: an UNFROZEN profile's generator domain is still the bare profile string",
            sh.name
        );
    }
    // the frozen seam's own generator: a file this lane may not edit, whose
    // 28-byte domain is the one B-1 is about. It is READ here, never changed.
    let seam = source("src/private_seam.rs");
    assert!(seam.contains("const DOMAIN: &[u8] = b\"experimental-private-seam/v1\";"), "the frozen seam's domain constant moved");
    assert_eq!(production_text(&seam).matches("ZkRng::from_os(DOMAIN)").count(), 2, "the frozen seam's two generator sites moved");
    assert_eq!(22 + "experimental-private-seam/v1".len(), 50, "the frozen seam's derivation input is not 50 bytes");
    // the toy's two endpoint generators STILL share their domain, and that is
    // the frozen state this stage deliberately does not repair: the toy's
    // bytes are pinned (D17/D22) and `private_seam.rs` is out of the write
    // set. Finding B-1 stands AT THE TOY and is closed everywhere else.
    assert!(!Shape::toy().endpoint_general, "the frozen toy no longer uses the frozen seam; B-1's scope must be re-read");
    // no registered run profile is legacy, which is why `run_seed_domain` has
    // no frozen branch
    for (p, sh, _) in every_run() {
        assert!(!sh.hashes_under_the_legacy_rule(), "{p}: a LEGACY-rule run profile is registered and `run_seed_domain` has no frozen branch for it");
    }
    eprintln!("S26/4: the toy (61 B) and the frozen-seam rung (66 B) keep the bare profile string; the seam's 28-byte domain and its two sites are untouched; all three run profiles are tagged");
}

// ---------------------------------------------------------------------------
// 5 — THE CAPTURE RULE: public fields only
// ---------------------------------------------------------------------------

/// **A GENERATOR DOMAIN IS A FUNCTION OF PUBLIC DATA ONLY.** Not asserted in
/// prose: each domain is taken apart field by field and shown to be exactly
/// `literal ‖ role-or-index ‖ public tail`, so there is no room in it for
/// anything else — in particular no commitment root and no witness word.
///
/// The two statement digests it does carry are public by construction:
/// `EndpointSpecG::digest` and `BoundarySpec::digest` hash a domain label, a
/// context, the geometry numbers and the scale, and this test reproduces
/// both from those public parameters alone.
#[test]
fn the_domains_are_built_from_public_fields_and_nothing_else() {
    let sh = Shape::rung_g();
    let spec = IoSpec::new_shaped(&sh, s26_context(), 0, 0).expect("the endpoint spec");
    let [si, _so] = spec.endpoints_g().expect("the two generalised endpoints");

    // (a) the ENDPOINT: literal ‖ role(1) ‖ digest(32)
    let d = endpoint_g::seed_domain(&si, EndpointRole::Input);
    assert_eq!(d.len(), 44 + 1 + 32, "the endpoint domain's layout moved");
    assert_eq!(&d[..44], b"hashline-zk-rng/private-block/endpoint-g/v1/", "the endpoint domain's use literal");
    assert_eq!(d[44], hash_domain::ROLE_ENDPOINT_IN, "the endpoint domain's role byte is not at the declared offset");
    assert_eq!(&d[45..], &si.digest()[..], "the endpoint domain's tail is not this endpoint's own spec digest");
    // the digest is REBUILT from public parameters, so "public" is measured
    let same = EndpointSpecG::new_with_tag(s26_context(), sh.t_pad, sh.d_pad, 0, 41, 42, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, &sh.hash_tag())
        .expect("the same endpoint statement from public numbers alone");
    assert_eq!(same.digest(), si.digest(), "the endpoint spec digest is not a function of the public geometry");

    // (b) the BOUNDARY: literal ‖ index(8, LE) ‖ digest(32)
    let st = run_statement(&sh, RUN_PROFILE_RUNG_G, 3);
    let b0 = st.boundary_spec(0).expect("the run's first boundary");
    let db = hash_domain::boundary_seed_domain(b0.index(), &b0.digest());
    assert_eq!(db.len(), 46 + 8 + 32, "the boundary domain's layout moved");
    assert_eq!(&db[..46], b"hashline-zk-rng/private-block/run-boundary/v1/", "the boundary domain's use literal");
    assert_eq!(&db[46..54], &b0.index().to_le_bytes()[..], "the boundary domain's index is not at the declared offset");
    assert_eq!(&db[54..], &b0.digest()[..], "the boundary domain's tail is not this boundary's own spec digest");
    let same_b = BoundarySpec::new_with_tag(s26_context(), sh.t_pad, sh.d_pad, 0, 1, 2, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1, &sh.hash_tag())
        .expect("the same boundary statement from public numbers alone");
    assert_eq!(same_b.digest(), b0.digest(), "the boundary spec digest is not a function of the public geometry");
    // the index really separates two boundaries of one run
    let b1 = st.boundary_spec(1).expect("the run's second boundary");
    assert_ne!(b0.index(), b1.index(), "two boundaries of one run share an index");
    assert_ne!(
        hash_domain::boundary_seed_domain(b0.index(), &b0.digest()),
        hash_domain::boundary_seed_domain(b1.index(), &b1.digest()),
        "two boundaries of one run share a generator domain"
    );

    // (c) the two PROVER streams: literal ‖ role(1) ‖ the profile STRING, all
    // of it printable ASCII, which is the plainest possible statement that no
    // digest of hidden data is in there
    let dbk = hash_domain::single_block_seed_domain(&sh);
    assert_eq!(&dbk[..47], b"hashline-zk-rng/private-block/single-prover/v1/", "the block prover's use literal");
    assert_eq!(dbk[47], hash_domain::ROLE_SINGLE_BLOCK_PROVER, "the block prover's role byte");
    assert_eq!(&dbk[48..], sh.profile.as_bytes(), "the block prover's domain tail is not the profile string");
    let dr = hash_domain::run_seed_domain(RUN_PROFILE_RUNG_G);
    assert_eq!(&dr[..58], b"hashline-zk-rng/private-block/one-stream-per-whole-run/v1/", "the run prover's use literal");
    assert_eq!(dr[58], hash_domain::ROLE_RUN_PROVER, "the run prover's role byte");
    assert_eq!(&dr[59..], RUN_PROFILE_RUNG_G.as_bytes(), "the run prover's domain tail is not the run profile string");

    // (d) THE FOUR ROLE BYTES ARE DISTINCT, so a role can never be read as
    // another use's
    let roles = [
        hash_domain::ROLE_ENDPOINT_IN,
        hash_domain::ROLE_ENDPOINT_OUT,
        hash_domain::ROLE_SINGLE_BLOCK_PROVER,
        hash_domain::ROLE_RUN_PROVER,
    ];
    for i in 0..roles.len() {
        for j in i + 1..roles.len() {
            assert_ne!(roles[i], roles[j], "two generator roles share a byte");
        }
    }
    eprintln!("S26/5: every domain is literal ‖ role-or-index ‖ public tail; both spec digests reproduced from public geometry; four distinct role bytes");
}

// ---------------------------------------------------------------------------
// 6 — THE PRODUCTION CALL SITES REALLY PASS THE BUILDERS
// ---------------------------------------------------------------------------

/// **THE CODE HALF: no production generator is seeded from a bare constant
/// any more.** A domain builder that nothing calls would satisfy every test
/// above, so the three production `ZkRng::from_os` sites this lane owns are
/// read out of the source and each is required to name its builder. The
/// frozen seam's two sites are required to keep naming their own constant.
///
/// The scan is over PRODUCTION text only (everything above the file's own
/// `#[cfg(test)] mod tests {`), and it is keyed by the builder's NAME, not by
/// a line number, so a comment edit cannot break it and a new bare-constant
/// site cannot slip past it.
#[test]
fn every_production_generator_is_seeded_from_a_domain_builder() {
    let want: [(&str, &str); 3] = [
        ("src/private_block/protocol.rs", "single_block_seed_domain"),
        ("src/private_block/run.rs", "run_seed_domain"),
        ("src/private_block/endpoint_g.rs", "seed_domain"),
    ];
    for (path, builder) in want {
        let src = source(path);
        let text = production_text(&src);
        // a doc comment that NAMES `ZkRng::from_os` is prose, not a call —
        // the same classifier `s25_tests`' generator scan uses
        let sites: Vec<&str> = text
            .lines()
            .filter(|l| {
                let t = l.trim_start();
                !t.starts_with("//") && !t.starts_with('*') && l.contains("ZkRng::from_os")
            })
            .collect();
        assert_eq!(sites.len(), 1, "{path}: {} production generator sites, expected exactly one: {sites:?}", sites.len());
        assert!(sites[0].contains(builder), "{path}: the generator is not seeded from `{builder}`: {}", sites[0].trim());
    }
    // the frozen seam, unchanged and named
    let seam = production_text(&source("src/private_seam.rs")).to_string();
    assert_eq!(seam.matches("ZkRng::from_os(DOMAIN)").count(), 2, "the frozen seam's generator sites moved");
    // a boundary still makes NO generator: it takes the run's one stream
    let b = source("src/private_block/boundary.rs");
    assert!(production_text(&b).contains("rng: &mut ZkRng"), "boundary::prepare no longer takes the caller's generator");
    assert!(!production_text(&b).contains("ZkRng::from_os"), "boundary::prepare now makes its own generator; a run would have two streams");
    eprintln!("S26/6: the three production generators name their builders; the frozen seam's two are unchanged; a boundary still makes none");
}

// ---------------------------------------------------------------------------
// 7 — THE LEGACY LENGTH GUARD IS UNMOVED (ruling item (d))
// ---------------------------------------------------------------------------

/// **THE GUARD'S REFUSED ROW COUNTS DO NOT MOVE, and here is why they
/// cannot.** The C-H4 length guard is imposed at LEGACY-rule profiles only
/// (ruling T-3 as amended), and the legacy-rule profiles are exactly the two
/// FROZEN ones, whose generator domains this stage does not touch. The one
/// seed derivation in the SHAPE-FREE set that does move is the generalised
/// endpoint's, and it moves from 64 to 99:
///
/// * 64 stays in the set — it is the Merkle node's and the salted leaf's, and
///   always was — so row count 8 is still refused, by the node;
/// * 99 is not a multiple of eight, so it adds no row count at all.
///
/// Both halves are measured, not argued.
#[test]
fn the_legacy_length_guards_refused_row_counts_are_unmoved() {
    let before: Vec<usize> = hash_domain::shape_free().dangerous_rows().keys().copied().collect();
    let after: Vec<usize> = hash_domain::full_shape_free().dangerous_rows().keys().copied().collect();
    assert_eq!(before, vec![5, 8, 11, 12, 13, 15, 17, 19], "stage 16's shape-free set moved");
    assert_eq!(after, vec![5, 8, 11, 12, 13, 15, 16, 17, 19], "stage 25's completed shape-free set moved");
    // 64 is still refused, and now by the node ALONE
    let d64 = hash_domain::full_shape_free().describe(64).expect("64 bytes still describes something");
    assert!(d64.contains("Merkle"), "the 64-byte class lost the Merkle node: {d64}");
    assert!(hash_domain::full_shape_free().refuse(&[("probe", 8)]).is_err(), "8 rows is no longer refused");
    // the endpoint's seed derivation is where the stage put it
    let len = hash_domain::endpoint_seed_input_len();
    assert!(
        hash_domain::full_shape_free().describe(len).is_some_and(|s| s.contains("generalised endpoint")),
        "the generalised endpoint's seed derivation is not in the shape-free set at {len} bytes"
    );
    // the per-shape sets: every registered profile's block-prover seed is in
    // its own set, at the builder's length, and is never a row count
    for sh in every_shape() {
        let s = hash_domain::full_at_shape(&sh);
        let l = hash_domain::single_block_seed_input_len(&sh);
        assert!(s.describe(l).is_some(), "{}: the block prover's seed derivation is not in the set at {l} bytes", sh.name);
        assert_ne!(l % 8, 0, "{}: the block prover's seed derivation is a multiple of eight", sh.name);
    }
    // **THE COMPLETE ARGUMENT FOR ITEM (d), measured rather than asserted.**
    // The only lengths this stage moves are seed derivations, and a length
    // changes the guard's REFUSED ROW COUNTS only if it is a multiple of
    // eight. Every length this stage retires or introduces is listed here
    // and checked: the old generalised-endpoint 64 IS a multiple of eight
    // and stays in the set anyway, because it is the Merkle node's; every
    // other one, old and new, is not a multiple of eight and so contributes
    // no row count in either direction.
    //
    // The lengths as they were: 61 (toy block prover, FROZEN), 66
    // (frozen-seam rung block prover, FROZEN), 50 (the frozen seam's
    // endpoint, a file this lane may not edit), 64 (the generalised
    // endpoint), 68 / 69 / 58 (the three tagged block provers) and 66 / 67 /
    // 56 (the three run provers). Only TWO of them are multiples of eight,
    // and each is handled by name below.
    for (l, what) in [
        (61usize, "the toy's block prover, FROZEN and unchanged"),
        (66, "the frozen-seam rung's block prover, FROZEN and unchanged"),
        (50, "the frozen seam's endpoint, unchanged"),
        (68, "the rung-G block prover before this stage"),
        (69, "the rung-K4 block prover before this stage"),
        (58, "the 125M block prover before this stage"),
        (66, "the rung-G run prover before this stage"),
        (67, "the rung-K4 run prover before this stage"),
    ] {
        assert_ne!(l % 8, 0, "a length this stage leaves or retires is a multiple of eight: {what}");
    }
    // **64, the generalised endpoint's old derivation input.** A multiple of
    // eight, and row count 8 stays refused — because 64 is the Merkle node's
    // and the salted leaf's too and always was.
    assert_eq!(64 % 8, 0, "the retired endpoint length is not a multiple of eight");
    assert!(
        hash_domain::full_shape_free().describe(64).is_some_and(|s| s.contains("Merkle")),
        "the retired 64 left the set and row count 8 with it"
    );
    // **56, the 125M RUN prover's old derivation input.** Also a multiple of
    // eight (row count 7) — and it was never a refused row count anywhere,
    // because the guard is imposed at LEGACY profiles only and no registered
    // run profile is legacy. Retiring it removes no refusal, which the
    // emptiness of every tagged profile's imposed set below is the check of.
    assert_eq!(56 % 8, 0, "the 125M run profile's old derivation input is not a multiple of eight");
    assert_eq!(22 + RUN_PROFILE_M125.len(), 56, "the 125M run profile string's length moved");
    for l in [
        hash_domain::endpoint_seed_input_len(),
        hash_domain::boundary_seed_input_len(),
        hash_domain::single_block_seed_input_len(&Shape::rung_g()),
        hash_domain::single_block_seed_input_len(&Shape::rung_k4()),
        hash_domain::single_block_seed_input_len(&Shape::m125()),
        hash_domain::run_seed_input_len(RUN_PROFILE_RUNG_G),
        hash_domain::run_seed_input_len(RUN_PROFILE_RUNG_K4),
        hash_domain::run_seed_input_len(RUN_PROFILE_M125),
    ] {
        assert_ne!(l % 8, 0, "a length this stage introduces is a multiple of eight and would add a refused row count: {l}");
    }
    // the two LEGACY profiles' imposed sets, which are the only ones that
    // refuse anything, printed and (for the toy) pinned
    for sh in every_shape().into_iter().filter(|s| s.hashes_under_the_legacy_rule()) {
        let rows: Vec<usize> = hash_domain::imposed_at_shape(&sh).dangerous_rows().keys().copied().collect();
        for r in [5usize, 8, 11, 12, 13, 15, 16, 17, 19] {
            assert!(rows.contains(&r), "{}: row count {r} left the imposed set", sh.name);
        }
        if sh.is_frozen_toy() {
            assert_eq!(rows, vec![5, 8, 11, 12, 13, 15, 16, 17, 19, 1031], "the FROZEN toy's imposed row counts moved");
        } else {
            assert!(rows.contains(&7), "the frozen-seam rung's 56-byte transcript constructor left its imposed set");
        }
        eprintln!("S26/7 {}: imposed refused row counts {rows:?}", sh.name);
    }
    // and the set is still EMPTY at every tagged profile
    for sh in every_shape().into_iter().filter(|s| !s.hashes_under_the_legacy_rule()) {
        assert!(hash_domain::imposed_at_shape(&sh).dangerous_rows().is_empty(), "{}: the guard is imposed at a tagged profile", sh.name);
    }
    eprintln!("S26/7: the shape-free refused row counts are {after:?}, unmoved; 64 is the node's alone and 8 rows is still refused; the endpoint's seed derivation is at {len} B and adds no row count");
}

// ---------------------------------------------------------------------------
// 8 — THE HONEST PROOFS THAT MUST STILL VERIFY, cited by name
// ---------------------------------------------------------------------------

/// **THE FOUR HONEST PROOFS THIS STAGE MUST NOT BREAK**, cited by name so
/// that the citation cannot rot. Every one of them goes through
/// `prepare_endpoints` (both endpoint generators) and through a prover
/// generator this stage re-domained, proves on a GENERIC witness — fully
/// dense public weights and a non-constant hidden input — and verifies under
/// the UNCHANGED verifier, against a PINNED receipt length.
///
/// They are not re-run here: they are in the `private_` gate, which is this
/// stage's acceptance, and re-proving them twice would double the gate's
/// wall clock for no new information. What this test pins is that they still
/// exist and still assert a pinned length, so the ledger's citation is a
/// fact of the source and not a memory.
#[test]
fn the_four_honest_generic_proofs_this_stage_must_not_break_are_where_the_ledger_says() {
    let want: [(&str, &str, &str); 4] = [
        ("src/private_block/dense_tests.rs", "fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_g()", "rung_g_frame_bytes()"),
        ("src/private_block/k4_tests.rs", "fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_k4()", "K4_FRAME_BYTES"),
        ("src/private_block/run_tests.rs", "fn an_honest_three_block_fully_dense_run_verifies_from_its_segments()", "counted_segment_bytes"),
        ("src/private_block/k4_tests.rs", "fn an_honest_three_block_fully_dense_run_verifies_from_its_segments_at_the_rung_k4()", "counted_segment_bytes"),
    ];
    for (path, test, pin) in want {
        let src = source(path);
        let at = src.find(test).unwrap_or_else(|| panic!("{path}: the honest proof `{test}` is gone"));
        let body = &src[at..(at + 4_000).min(src.len())];
        assert!(body.contains(pin), "{path}: `{test}` no longer asserts its pinned length `{pin}`");
        assert!(body.contains("verify"), "{path}: `{test}` no longer verifies");
    }
    // and the run header's byte-identity witness, which pins the rung-G L=3
    // run BINDING and its two boundary digests as literals (stage 21, ruling
    // R-5) — the strongest single statement that nothing public moved
    let rt = source("src/private_block/run_tests.rs");
    assert!(rt.contains("const R5_RUNG_G_L3_BINDING: [u8; 32]"), "the pinned rung-G L=3 run binding is gone");
    assert!(rt.contains("const R5_RUNG_G_L3_BOUNDARIES: [[u8; 32]; 2]"), "the pinned rung-G L=3 boundary digests are gone");
    assert!(
        rt.contains("fn the_run_header_the_approved_scales_bind_is_byte_identical_under_ruling_r5()"),
        "the run header's byte-identity test is gone"
    );
    eprintln!("S26/8: the four honest generic proofs and the R-5 byte-identity witness are all present and still pin their lengths");
}
