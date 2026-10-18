//! **STAGE 24 — THE ENFORCEMENT BATCH.** Nine items that three of the
//! security owner's dispositions of 2026-09-21 leave on this lane:
//!
//! * `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` — **H-1** (an
//!   inadmissible chain is refused before the header), **H-4** (every tagged
//!   profile's keys pairwise distinct), **H-5** (the trailer/next-header
//!   property), **H-8** (no profile's constructor input has the squeeze
//!   length);
//! * `ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md` — **C-2** (ruling S-3
//!   protects slots 15 and 16 too), **C-3** (host discipline at every shape),
//!   **C-4** (the mask budget as a named shape refusal), **C-7** (the closure
//!   polynomial on extension-round-supported vectors, gap S-C1);
//! * `ZK60_NATIVE_RUN_GATE.md` §10 — the capture writer's source pins (the
//!   change itself is in `run_capture.rs`; what is here is the test that the
//!   list covers the run's path).
//!
//! **Every one of these turns something that was TRUE into something that is
//! CHECKED.** Nothing here is a privacy or a soundness acceptance, no
//! existing profile moves a byte, and the one new refusal
//! ([`the_mask_budget_holds_at_every_shape`]) is asserted FALSE at all five
//! shapes before it is forced on a synthetic one.

use super::argument::{define, Coord, Ctx, Points, Priv, SlotDef, Tab};
use super::layout::*;
use super::run::{self, RunShape, RunStatement, RunWitnessSource, RUN_PROFILE_M125, RUN_PROFILE_RUNG_C6, RUN_PROFILE_RUNG_E32, RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4, RUN_PROFILE_RUNG_P2, RUN_PROFILE_RUNG_W14};
use super::run_sink::{DirSink, SegmentSink};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::field::{Fp, Fp2};
use crate::transcript::Transcript;
use zkp_core::hashtag::HashTag;

/// the five shapes this module builds, and the only ones anything is ever
/// proved, captured or counted at
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()]
}

/// `clog2`, as `Shape::natural_log` uses it
fn clog2(v: usize) -> usize {
    (usize::BITS - (v - 1).leading_zeros()) as usize
}

/// Are two claim coordinates the SAME function of the slot's challenges?
/// (`Coord` carries an `Fp2` and derives no `PartialEq`, so this is written
/// out; a `Fixed` coordinate is compared by value.)
fn same_coord(a: &Coord, b: &Coord) -> bool {
    match (a, b) {
        (Coord::Rho(x), Coord::Rho(y)) | (Coord::Flip(x), Coord::Flip(y)) => x == y,
        (Coord::Fixed(x), Coord::Fixed(y)) => x == y,
        _ => false,
    }
}

/// SplitMix64: this file never reads OS randomness and never uses the
/// module's own generator, so every value below is reproducible from its seed.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn fp2(&mut self) -> Fp2 {
        Fp2::new(Fp::new(self.next() >> 2), Fp::new(self.next() >> 2))
    }
}

/// One of this crate's own source files, read at test time. The path is the
/// crate manifest's, exactly as `run_capture::source_pins` resolves its pins,
/// so a test that reads the source cannot read another tree's copy.
fn source(name: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(name);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("stage 24: {}: {e}", p.display()))
}

/// Every `"hashline-zk-mr1/…"` STRING LITERAL in a source file, in order. The
/// opening quote is part of the pattern, so a profile named in a comment is
/// not picked up and a profile written as a literal cannot be missed.
fn profile_literals(text: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    let mut rest = text;
    while let Some(i) = rest.find("\"hashline-zk-mr1/") {
        let after = &rest[i + 1..];
        let end = after.find('"').expect("a profile literal has a closing quote");
        out.push(after[..end].to_string());
        rest = &after[end..];
    }
    out
}

/// Drive the REAL `argument::define` over the whole slot order at `sh` and
/// hand each definition to `f` — which is the hook the stage-20 reviewer built
/// and the only way to see what a slot actually declares. Each definition is
/// DROPPED before the next is built: at 125M a single public table on
/// `Dom::S` is 2^22 field elements, so holding all twenty-three would be
/// hundreds of megabytes for no reason.
fn walk_definitions(sh: &Shape, mut f: impl FnMut(&SlotDef)) {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let ctx = Ctx {
        lay: &lay,
        public: &public,
        ff: &ff,
        alpha: Fp2::from_u64(7).add(Fp2::U),
        beta: Fp2::from_u64(11),
        g_u8: Fp2::from_u64(13),
        g_exp: Fp2::from_u64(17),
        g_act: Fp2::from_u64(19),
    };
    let mut tr = Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    for s in 0..N_SLOTS {
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
        f(&def);
    }
}

// ---------------------------------------------------------------------------
// ITEM 1 — ruling H-4: every tagged profile's four keys, pairwise distinct
// ---------------------------------------------------------------------------

/// **RULING H-4.** The tag's model costs "the probability that two derived
/// keys collide, about 2^-251 for the keys that exist — zero today, by a test
/// that pins them distinct; that test is extended to EVERY tagged profile."
///
/// `zkp-core`'s own test pins eight keys by hex literal (rung-G and 125M),
/// which was every tagged profile when it was written. The lane has had a
/// third since stage 22, and a hand list is exactly the thing that goes stale
/// — so the profile registry is READ OUT OF THE SOURCE here: every
/// `"hashline-zk-mr1/…"` string literal in `shape.rs` and `run.rs`, compared
/// with what the constructors give. **A profile added to either file without
/// being covered fails this test at that comparison**, before a key is
/// derived.
///
/// What is then asserted:
///
/// * the two LEGACY profiles (the frozen toy, the frozen-seam rung) carry no
///   key at all, in any role;
/// * every other BLOCK profile's four keys are `HashTag::for_profile`'s, and
///   all of them are pairwise distinct — across the four roles and across the
///   profiles;
/// * **the RUN profiles use their block shape's keys** (the disposition's
///   "confirm"): `protocol::tagged_transcript` keys a run's transcript with
///   `sh.hash_tag()`, the BLOCK shape's, and passes the run profile string as
///   the transcript's DOMAIN. So a run profile derives no key set of its own,
///   and there are twelve keys in this lane, not twenty-four. That is
///   measured on the transcript state rather than read off the source;
/// * and as a FORWARD GUARD, the keys the three run profile strings WOULD
///   derive are distinct from the twelve and from each other, so that a
///   future decision to tag a run in its own right cannot collide silently.
#[test]
fn every_registered_profile_is_covered_and_every_tagged_ones_keys_are_pairwise_distinct() {
    // (1) THE REGISTRY, read out of the source.
    let mut in_source = profile_literals(&source("src/private_block/shape.rs"));
    in_source.extend(profile_literals(&source("src/private_block/run.rs")));
    in_source.sort();
    in_source.dedup();
    // (2) THE REGISTRY, as the constructors give it.
    // NATIVE LANE: the two trained-calibration block profiles and their two
    // run profiles are in the registry too
    let mut shapes = every_shape();
    shapes.extend(super::trained_calib_tests::registered_trained_shapes());
    let mut runs = vec![RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4, RUN_PROFILE_RUNG_P2, RUN_PROFILE_RUNG_C6, RUN_PROFILE_RUNG_W14, RUN_PROFILE_RUNG_E32, RUN_PROFILE_M125];
    runs.extend(super::trained_calib_tests::registered_trained_runs().into_iter().map(|(p, _)| p));
    let mut covered: Vec<String> = shapes.iter().map(|s| s.profile.to_string()).collect();
    covered.extend(runs.iter().map(|r| r.to_string()));
    covered.sort();
    covered.dedup();
    assert_eq!(in_source, covered, "a profile string in shape.rs or run.rs is not covered by this test (or vice versa)");
    // NON-VACUITY, in test code alone: the hand list this test replaces —
    // every profile but the stage-22 one — does NOT satisfy the comparison
    // above, so the comparison has teeth.
    let stale: Vec<String> = covered.iter().filter(|p| !p.contains("rung-k4")).cloned().collect();
    assert_ne!(stale, covered, "the stale hand list is the live one; the registry check cannot fail");
    assert_eq!(stale.len() + 2, covered.len(), "rung-K4 contributes exactly two profile strings, a block and a run");

    // (3) THE KEYS OF EVERY TAGGED PROFILE.
    let mut keys: Vec<(String, &'static str, [u8; 32])> = Vec::new();
    let mut legacy = 0usize;
    for sh in &shapes {
        let t = sh.hash_tag();
        if sh.hashes_under_the_legacy_rule() {
            legacy += 1;
            assert!(t.is_legacy(), "{}: a legacy-rule profile carries a tag", sh.name);
            assert!(
                t.transcript_key().is_none() && t.column_key().is_none() && t.leaf_key().is_none() && t.node_key().is_none(),
                "{}: a legacy-rule profile carries a key",
                sh.name
            );
            continue;
        }
        assert_eq!(t, HashTag::for_profile(sh.profile), "{}: the tag is not a function of the profile string", sh.name);
        for (role, k) in [("transcript", t.transcript_key()), ("column", t.column_key()), ("leaf", t.leaf_key()), ("node", t.node_key())] {
            keys.push((sh.profile.to_string(), role, *k.expect("a tagged profile carries all four keys")));
        }
    }
    assert_eq!(legacy, 2, "the two legacy-rule profiles are the frozen toy and the frozen-seam rung, and there are no others");
    assert_eq!(keys.len(), 4 * (shapes.len() - legacy), "a tagged profile did not produce four keys");
    for i in 0..keys.len() {
        for j in i + 1..keys.len() {
            assert_ne!(keys[i].2, keys[j].2, "the {} key of {} collides with the {} key of {}", keys[i].1, keys[i].0, keys[j].1, keys[j].0);
        }
    }

    // (4) THE RUN PROFILES USE THEIR BLOCK SHAPE'S KEYS.
    let mut run_shapes = vec![
        (RUN_PROFILE_RUNG_G, Shape::rung_g()),
        (RUN_PROFILE_RUNG_K4, Shape::rung_k4()),
        (RUN_PROFILE_RUNG_P2, Shape::rung_p2()),
        (RUN_PROFILE_RUNG_C6, Shape::rung_c6()),
        (RUN_PROFILE_RUNG_W14, Shape::rung_w14()),
        (RUN_PROFILE_RUNG_E32, Shape::rung_e32()),
        (RUN_PROFILE_M125, Shape::m125()),
    ];
    run_shapes.extend(super::trained_calib_tests::registered_trained_runs());
    for (rp, sh) in run_shapes {
        let live = super::protocol::tagged_transcript(&sh, rp.as_bytes()).state();
        let block_key = *sh.hash_tag().transcript_key().expect("a tagged block profile carries a transcript key");
        assert_eq!(live, Transcript::new_tagged(rp.as_bytes(), block_key).state(), "{rp}: the run's transcript is not keyed by its BLOCK shape's key");
        let own_key = *HashTag::for_profile(rp).transcript_key().expect("derivable");
        assert_ne!(live, Transcript::new_tagged(rp.as_bytes(), own_key).state(), "{rp}: the run's transcript is keyed by the run profile's own key");
        assert_ne!(block_key, own_key, "{rp}: the run profile derives its block shape's key");
    }
    // (5) THE FORWARD GUARD: the run profiles' would-be keys, beside the twelve.
    let mut all: Vec<(String, &'static str, [u8; 32])> = keys.clone();
    for rp in runs.iter().copied() {
        let t = HashTag::for_profile(rp);
        for (role, k) in [("transcript", t.transcript_key()), ("column", t.column_key()), ("leaf", t.leaf_key()), ("node", t.node_key())] {
            all.push((rp.to_string(), role, *k.expect("derivable")));
        }
    }
    // four roles per tagged block profile, plus four per run profile's
    // would-be set — derived from the registry, never a literal that a new
    // profile could leave stale (stage 30 added a sixth shape and a fourth
    // run profile and this line did not move)
    assert_eq!(all.len(), 4 * (shapes.len() - legacy) + 4 * runs.len());
    for i in 0..all.len() {
        for j in i + 1..all.len() {
            assert_ne!(all[i].2, all[j].2, "the {} key of {} collides with the {} key of {}", all[i].1, all[i].0, all[j].1, all[j].0);
        }
    }
    eprintln!(
        "S24 H-4: {} profiles registered in the source, {} legacy, {} tagged; {} live keys pairwise distinct, {} with the run profiles' would-be sets",
        covered.len(),
        legacy,
        shapes.len() - legacy,
        keys.len(),
        all.len()
    );
}

// ---------------------------------------------------------------------------
// ITEM 2 — ruling H-5: the trailer of a segment IS the next segment's header
// ---------------------------------------------------------------------------

/// **RULING H-5, THE PROPERTY AND NOT THE COINCIDENCE.** The disposition
/// measured on all ten bundles that a segment's 32-byte trailer equals the
/// next segment's 32-byte header, and ruled: the wire format stays as it is,
/// and **what is pinned is the property** — no transcript operation occurs
/// between a segment's END position tag and the next segment's START position
/// tag.
///
/// **This is a property of the STAGE LOOP, not a wire-format requirement.** A
/// stage's end tag is taken at `run.rs`'s `let end_tag = position_tag(&tr);`
/// and the next stage's start tag at `let start_tag = position_tag(&tr);` —
/// the two lines named in the ledger's stage-24 section, with nothing between
/// them but `wire::encode_segment`, the sink call and three pushes into
/// `RunStats`, none of which touches the transcript. If a later change
/// absorbed anything there, THIS test fails and the format does not: the
/// verifier would still accept, because it would recompute both tags the same
/// way. Nothing anywhere may be made to depend on the equality.
///
/// The observation is the 32-byte tag itself. A tag is two `Fp2` squeezed from
/// a DISCARDED clone, and `Transcript::clone_state` copies the 32-byte state
/// AND the squeeze counter, both of which are hashed into every squeeze — so
/// equal tags mean an equal (state, counter) pair up to a hash collision.
/// `zkp-core` publishes no counter accessor and is a file this lane does not
/// edit, which is finding U-3 and is why the tag is the strongest observation
/// available here.
///
/// A GENERIC three-block run at `Shape::rung_k4`: the fully dense recipe, a
/// non-constant hidden input, four live key-value groups. The run is VERIFIED
/// first, so the tags compared are an accepted run's.
#[test]
fn a_segments_end_tag_is_the_next_segments_start_tag_in_a_rung_k4_run() {
    const L: usize = 3;
    let (mut c, blocks) = super::k4_tests::k4_dense_chain(L);
    let (st, owners) = super::k4_tests::k4_statement_of(&c, L, &blocks);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&st, &blocks, &mut c, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest three-block fully dense rung-K4 run proves");
    run::verify_run(&st, &blocks, &segs).expect("the honest three-block fully dense rung-K4 run verifies");
    assert_eq!(segs.len(), L);
    // the two 32-byte fields, at the offsets `wire.rs` writes them: the start
    // tag ends the run header, the end tag is the trailer
    let start = |k: usize| -> [u8; 32] { segs[k][super::wire::RUN_HEADER - 32..super::wire::RUN_HEADER].try_into().expect("32 bytes") };
    let end = |k: usize| -> [u8; 32] {
        let s = &segs[k];
        s[s.len() - super::wire::RUN_TRAILER..].try_into().expect("32 bytes")
    };
    for k in 0..L - 1 {
        assert_eq!(end(k), start(k + 1), "stage {k}'s end tag is not stage {}'s start tag: the stage loop touched the transcript between them", k + 1);
    }
    // THE LAST SEGMENT'S END TAG HAS NO SUCCESSOR — it is the run's final
    // transcript position and equals nothing else in the receipt.
    let last = end(L - 1);
    for k in 0..L {
        assert_ne!(last, start(k), "the last segment's end tag is some segment's start tag");
        if k + 1 < L {
            assert_ne!(last, end(k), "two segments share an end tag");
        }
    }
    // NON-VACUITY: a stage MOVES the transcript, so its own two tags differ,
    // and the three start tags are pairwise different. Without this the
    // equality above could hold because nothing ever changes.
    for k in 0..L {
        assert_ne!(start(k), end(k), "stage {k} begins and ends at the same transcript position");
    }
    for a in 0..L {
        for b in a + 1..L {
            assert_ne!(start(a), start(b), "stages {a} and {b} begin at the same transcript position");
        }
    }
    eprintln!("S24 H-5: rung-K4 L={L}, end tag of stage k == start tag of stage k+1 for k in 0..{}, and the last has no successor", L - 1);
}

// ---------------------------------------------------------------------------
// ITEM 3 — ruling H-8: a constructor input is never a squeeze input's length
// ---------------------------------------------------------------------------

/// **RULING H-8.** Inside the transcript's (keyed or unkeyed) BLAKE3 function
/// a CONSTRUCTOR input could only equal a SQUEEZE input if it spelled the word
/// `squeeze` at a fixed offset after a 32-byte state — and it cannot even be
/// the same LENGTH. The disposition asks for "a one-line test that no
/// registered profile's constructor input has the squeeze length, so the
/// margin is watched rather than argued".
///
/// **The two lengths, derived and not copied.**
///
/// * A constructor hashes `b"hashline-v1/" ‖ domain`
///   (`zkp-core/src/transcript.rs`, `Transcript::new` / `new_tagged`), so its
///   input is `12 + profile.len()` bytes.
/// * A squeeze hashes `state ‖ b"squeeze" ‖ counter`
///   (`Transcript::squeeze_bytes`), so its input is `32 + 7 + 8 = 47` bytes,
///   whatever the profile and whatever the counter.
///
/// Both layouts are REPRODUCED from outside the type rather than read: the
/// state after construction is recomputed here from the two updates, and the
/// state after one challenge is recomputed from the three. If either layout
/// moved, this test fails at the reproduction and not at the arithmetic.
#[test]
fn no_registered_profiles_constructor_input_has_the_squeeze_length() {
    const PREFIX: &[u8] = b"hashline-v1/";
    const SQUEEZE_LABEL: &[u8] = b"squeeze";
    // 32 (the running state) + 7 (the label) + 8 (the counter, little endian)
    let squeeze_len = 32 + SQUEEZE_LABEL.len() + std::mem::size_of::<u64>();
    assert_eq!(squeeze_len, 47, "the squeeze input length is not what the layout gives");

    let shapes = every_shape();
    let mut profiles: Vec<&'static str> = shapes.iter().map(|s| s.profile).collect();
    profiles.extend([RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4, RUN_PROFILE_M125]);
    let mut lens: Vec<(usize, &'static str)> = Vec::new();
    for p in &profiles {
        let ctor_len = PREFIX.len() + p.len();
        assert_ne!(ctor_len, squeeze_len, "profile {p} has a constructor input of exactly the squeeze length");
        lens.push((ctor_len, p));
    }
    // the layouts, reproduced from outside `Transcript`
    let key = *Shape::rung_g().hash_tag().transcript_key().expect("a tagged profile carries a transcript key");
    for (domain, k) in [(Shape::toy().profile, None), (Shape::rung_g().profile, Some(key))] {
        let mut h = zkp_core::hashtag::hasher(k.as_ref());
        h.update(PREFIX);
        h.update(domain.as_bytes());
        let want: [u8; 32] = *h.finalize().as_bytes();
        let mut tr = match k {
            None => Transcript::new(domain.as_bytes()),
            Some(kk) => Transcript::new_tagged(domain.as_bytes(), kk),
        };
        assert_eq!(tr.state(), want, "{domain}: the constructor's input layout is not `hashline-v1/` ‖ domain");
        // one challenge, and the state it leaves IS the squeeze output
        let mut h2 = zkp_core::hashtag::hasher(k.as_ref());
        h2.update(&want);
        h2.update(SQUEEZE_LABEL);
        h2.update(&0u64.to_le_bytes());
        let want2: [u8; 32] = *h2.finalize().as_bytes();
        let _ = tr.challenge_fp2();
        assert_eq!(tr.state(), want2, "{domain}: the squeeze's input layout is not state ‖ `squeeze` ‖ counter");
    }
    // NON-VACUITY: the check is not empty of content — a profile string of 35
    // characters would hit the squeeze length exactly, and none of ours is 35.
    assert_eq!(PREFIX.len() + 35, squeeze_len, "35 is no longer the profile length that would collide");
    assert!(!profiles.iter().any(|p| p.len() == 35), "a registered profile is 35 characters long");
    lens.sort();
    eprintln!("S24 H-8: constructor input lengths, against the squeeze's {squeeze_len}: {lens:?}");
}

// ---------------------------------------------------------------------------
// ITEM 4 — round 6 of the native run gate: the capture writer's source pins
// ---------------------------------------------------------------------------

/// **ROUND 6's ASK TO THIS LANE** (`ZK60_NATIVE_RUN_GATE.md` §10.2, §10.8).
/// The run gate's pin mechanism is bundle-side — "a file can be pinned there
/// only if the WRITER pins it" — and four files on the run's path were in no
/// bundle's `source_pins`: `wire.rs`, `run_sink.rs`, `endpoint_g.rs` and
/// `hash_domain.rs`. The round could name them but not close it; closing it
/// is a Rust-lane change, and this is the test that keeps it closed.
///
/// **The rule the list now follows**: every PRODUCTION module of
/// `private_block`, plus the parent module file itself, plus the two
/// `cfg(test)` modules that write a bundle, is either a source pin or is
/// named in `NOT_ON_THE_RUNS_PATH` with a reason. The module list is PARSED
/// from `private_block.rs`, so a module added tomorrow fails this test until
/// somebody decides which side it is on.
#[test]
fn the_capture_writer_pins_every_run_layer_source_it_depends_on() {
    let parent = source("src/private_block.rs");
    let lines: Vec<&str> = parent.lines().collect();
    let mut production: Vec<String> = Vec::new();
    for (i, l) in lines.iter().enumerate() {
        let Some(rest) = l.trim().strip_prefix("mod ") else { continue };
        let Some(name) = rest.strip_suffix(';') else { continue };
        if i > 0 && lines[i - 1].trim() == "#[cfg(test)]" {
            continue;
        }
        production.push(format!("src/private_block/{name}.rs"));
    }
    production.push("src/private_block.rs".to_string());
    production.sort();
    assert_eq!(
        production,
        [
            "src/private_block.rs",
            "src/private_block/argument.rs",
            "src/private_block/boundary.rs",
            "src/private_block/endpoint_g.rs",
            "src/private_block/hash_domain.rs",
            "src/private_block/layout.rs",
            "src/private_block/mvp_driver.rs",
            "src/private_block/pad.rs",
            "src/private_block/protocol.rs",
            "src/private_block/run.rs",
            "src/private_block/run_sink.rs",
            "src/private_block/shape.rs",
            "src/private_block/timing.rs",
            "src/private_block/trained_block.rs",
            "src/private_block/trained_statement.rs",
            "src/private_block/wire.rs",
            "src/private_block/witness.rs",
        ],
        "the production module list of private_block has moved"
    );
    let pinned: Vec<&str> = super::run_capture::source_files();
    let excused: Vec<&str> = super::run_capture::NOT_ON_THE_RUNS_PATH.iter().map(|(f, _)| *f).collect();
    // (a) the partition: every production file on exactly one side
    for f in &production {
        let (a, b) = (pinned.contains(&f.as_str()), excused.contains(&f.as_str()));
        assert!(a || b, "{f} is a production module of private_block and is neither pinned nor excused by name");
        assert!(!(a && b), "{f} is both pinned and excused");
    }
    for (f, why) in super::run_capture::NOT_ON_THE_RUNS_PATH {
        assert!(production.contains(&f.to_string()), "{f} is excused and is not a production module");
        assert!(why.len() > 40, "{f}'s reason is not a reason: {why}");
    }
    // (b) THE FOUR ROUND 6 NAMED, by name
    for f in ["src/private_block/wire.rs", "src/private_block/run_sink.rs", "src/private_block/endpoint_g.rs", "src/private_block/hash_domain.rs"] {
        assert!(pinned.contains(&f), "{f} — named by round 6 as unpinnable from a bundle — is still not a source pin");
    }
    // (c) and they really are on the RUN's path, read out of `run.rs` rather
    // than asserted: it imports the first three and calls into the fourth
    let runs = source("src/private_block/run.rs");
    for m in ["wire", "run_sink", "endpoint_g", "hash_domain"] {
        assert!(runs.contains(&format!("{m}::")), "run.rs does not reach `{m}`; the pin would be for nothing");
    }
    // (d) the two bundle WRITERS are pinned although they are test-only
    for f in ["src/private_block/run_capture.rs", "src/private_block/plane_index.rs"] {
        assert!(pinned.contains(&f), "{f} writes a bundle and is not pinned");
    }
    // (d2) NATIVE R5b (review r4 note N-r4-d, the privacy-gate lane): the
    // trained loader and its table registries are pinned, and the GPU-only
    // and older-prover files are deliberately NOT, each with its reason in
    // the list's comment
    for f in ["src/private_block/trained_block.rs", "src/gpu/mod.rs", "src/tables_v3.rs", "../zkp-core/src/tables.rs"] {
        assert!(pinned.contains(&f), "{f} — N-r4-d — is not a source pin");
    }
    let rc = source("src/private_block/run_capture.rs");
    for f in ["src/gpu/cuda.rs", "src/gpu/kernels.cu", "src/layer.rs", "src/wcache.rs"] {
        assert!(!pinned.contains(&f), "{f} is pinned; N-r4-d keeps it off the list");
    }
    for why in ["`gpu/cuda.rs` and `gpu/kernels.cu`", "`gpu-cuda` feature", "`layer.rs` / `wcache.rs`"] {
        assert!(rc.contains(why), "run_capture.rs no longer gives the reason for an N-r4-d exclusion ({why})");
    }
    // (e) no duplicates, and every pin resolves to a file with a digest
    let mut sorted = pinned.clone();
    sorted.sort();
    let n = sorted.len();
    sorted.dedup();
    assert_eq!(sorted.len(), n, "a file is pinned twice");
    let pins = super::run_capture::source_pins().expect("every source pin resolves to a file");
    assert_eq!(pins.len(), n, "a pin was dropped between the list and the digests");
    assert!(pins.iter().all(|(_, sha)| sha.len() == 64 && sha.chars().all(|c| c.is_ascii_hexdigit())), "a source pin is not a SHA-256");
    eprintln!("S24 run-gate §10: {n} source pins ({} production modules, the parent, and 2 test-only writers), {} excused by name", production.len() - excused.len(), excused.len());
}

// ---------------------------------------------------------------------------
// ITEM 5 — ruling C-2: ruling S-3's refusal protects slots 15 and 16 too
// ---------------------------------------------------------------------------

/// **RULING C-2.** Clause C1 of the closure property — "every private plane
/// raises exactly one claim" — is FALSE for slots 15 (`SC_QZC`) and 16
/// (`SC_KVZC`): the rotary partner makes the SAME plane (`A_Q8`, `A_K8`) raise
/// TWO claims, at points differing in ONE FLIPPED COORDINATE
/// (`argument.rs`'s `SC_QZC | SC_KVZC` arm: `cf[log - ldh] = Coord::Flip(..)`,
/// trap T-8). All the properties still hold, and the checker built the
/// miniature that says so — but only because the two claims' COLUMN KEYS
/// separate, and they separate only because `log2(head_dim) <= log_cols`.
///
/// That is exactly what ruling S-3's refusal enforces, for slot 08's sake,
/// with two bits to spare at every shape. **So S-3 protects three slots, not
/// one**, and this test says it explicitly.
///
/// **What a column key is** (`protocol::part_key_at`, the PCS's own rule): the
/// LAST `log_cols` entries of the claim's point. The flipped coordinate sits
/// at index `log - log2(head_dim)` of a point of length `log`, so it is inside
/// that tail exactly when `log2(head_dim) <= log_cols`. Above it the two
/// claims would share a key, land in ONE opening group, and
/// `opening_groups_at` would return fewer groups than the schedule declares —
/// the same liveness cliff S-3 names for the score slot.
///
/// A margin remains that this test does NOT close and that S-3 does not
/// either: at a challenge with `rho_k = 1/2` the flipped and unflipped
/// coordinates are equal AS FIELD ELEMENTS, and the two keys coincide for that
/// one draw. That is a 2^-128 liveness event on an honest run, not a
/// structural collision, and it is recorded here rather than repaired.
#[test]
fn the_s3_refusal_also_separates_the_two_rotary_claims_of_slots_15_and_16() {
    for sh in every_shape() {
        let ldh = clog2(sh.head_dim);
        let mut seen = 0usize;
        walk_definitions(&sh, |def| {
            if def.slot != SC_QZC && def.slot != SC_KVZC {
                return;
            }
            seen += 1;
            let dom = if def.slot == SC_QZC { Dom::Q } else { Dom::Kv };
            let log = sh.log(dom);
            // the table of this slot that carries a FLIPPED coordinate, and
            // the table on the SAME PLANE that does not
            let privs: Vec<&Priv> = def.tabs.iter().filter_map(|t| if let Tab::Priv(p) = t { Some(p) } else { None }).collect();
            let flipped: Vec<usize> = (0..privs.len()).filter(|i| privs[*i].coords.iter().any(|c| matches!(c, Coord::Flip(_)))).collect();
            assert_eq!(flipped.len(), 1, "{}: slot {}: not exactly one flipped claim", sh.name, def.slot);
            let f = privs[flipped[0]];
            let partners: Vec<usize> = (0..privs.len()).filter(|i| *i != flipped[0] && privs[*i].slices == f.slices).collect();
            assert_eq!(partners.len(), 1, "{}: slot {}: the flipped claim's plane is not claimed exactly twice", sh.name, def.slot);
            let s = privs[partners[0]];
            // TWO CLAIMS ON ONE PLANE, at points differing in ONE coordinate
            assert_eq!(f.cm as usize, s.cm as usize, "{}: slot {}: the two claims are on different commitments", sh.name, def.slot);
            assert_eq!((f.log, s.log), (log, log), "{}: slot {}: a rotary claim is not on the slot's own domain", sh.name, def.slot);
            assert_eq!(f.coords.len(), s.coords.len(), "{}: slot {}: the two coordinate lists differ in length", sh.name, def.slot);
            let differ: Vec<usize> = (0..log).filter(|k| !same_coord(&f.coords[*k], &s.coords[*k])).collect();
            assert_eq!(differ, vec![log - ldh], "{}: slot {}: the two claims do not differ in exactly the RoPE partner bit", sh.name, def.slot);
            assert!(matches!(f.coords[log - ldh], Coord::Flip(_)) && matches!(s.coords[log - ldh], Coord::Rho(_)), "{}: slot {}: the differing coordinate is not the flip", sh.name, def.slot);
            // THE KEY-DETERMINING PART: the last `log_cols` entries. The
            // differing position must be inside it, or the two keys are equal.
            assert!(log >= sh.log_cols, "{}: slot {}: the claim point is shorter than a column key", sh.name, def.slot);
            let tail_from = log - sh.log_cols;
            assert!(
                differ[0] >= tail_from,
                "{}: slot {}: the flipped coordinate at {} is OUTSIDE the column-key tail [{tail_from}, {log}); the two claims share a column key",
                sh.name,
                def.slot,
                differ[0]
            );
            // and the margin is ruling S-3's own, stated as the inequality
            // that puts it inside
            assert!(ldh <= sh.log_cols, "{}: slot {}: log2(head_dim) has reached the row width", sh.name, def.slot);
            assert!(ldh + 2 <= sh.log_cols, "{}: slot {}: the rotary claims are within two bits of sharing a column key", sh.name, def.slot);
        });
        assert_eq!(seen, 2, "{}: the two rotary slots were not both defined", sh.name);
        // NON-VACUITY, arithmetic and in test code alone: a HYPOTHETICAL head
        // dimension of one bit MORE than the row width would put the flipped
        // coordinate at `log - (log_cols + 1)`, BELOW the tail's first index
        // `log - log_cols` — so the test above really does distinguish the
        // violating case from the live one.
        let log = sh.log(Dom::Q);
        let hypothetical = sh.log_cols + 1;
        assert!(log >= hypothetical && log - hypothetical < log - sh.log_cols, "{}: the column-key tail test cannot distinguish a violating head dimension", sh.name);
        eprintln!("S24 C-2 [{}]: slots 15 and 16 each raise two claims on one plane, differing at coordinate log-{ldh} inside the last {} of the point", sh.name, sh.log_cols);
    }
    // AND THE VIOLATING GEOMETRY IS REFUSED BEFORE IT COULD MATTER. Ruling
    // S-3 fires at `head_dim >= 2^log_cols`, which is strictly stronger than
    // the `log2(head_dim) <= log_cols` slots 15 and 16 need: both the
    // boundary case and everything above it are refused by name.
    for (name, width, head_dim) in [("at the row width", 256usize, 256usize), ("above the row width", 512, 512)] {
        let e = Shape::new("S-24 probe: the rotary claims' column keys", "hashline-zk-mr1/private-block-s24-probe/1", 16, width, 256, 1, head_dim, 1, 8, 4, 9, 21, None, None, None, None)
            .expect_err("a head dimension that merges the rotary claims' column keys was accepted");
        assert!(e.contains("ruling S-3"), "{name}: the refusal does not name the ruling: {e}");
    }
}

// ---------------------------------------------------------------------------
// ITEM 6 — ruling C-3: host discipline, at every shape
// ---------------------------------------------------------------------------

/// **RULING C-3.** "Host discipline is checked by nothing at the shaped
/// layouts. No test and no production check compares the hosted lists written
/// literally in the slot definitions with the host table; the existing
/// assertions are test-only and against the toy's constants. A mismatch would
/// be a SOUNDNESS defect — a hosted claim consumed twice or never."
///
/// **What this uses, and what it does not.** `argument::define` returns the
/// hosted list it built — `SlotDef::hosted`, `(hosted slot, nu·kappa)` — so
/// the literals ARE observable through the existing test path
/// (`walk_definitions`, the hook the stage-20 reviewer built). No production
/// hook is added. What is compared is the whole map, in both directions, at
/// every shape:
///
/// * every slot's hosted list is exactly `layout::HOSTS`'s entry for it, in
///   order, and every non-host slot hosts nothing;
/// * every private slot appears under exactly ONE host, and every standalone
///   slot under none;
/// * the host of a slot runs AFTER it, which is what makes `acc.cs[hosted]`
///   and `acc.scalars[hosted]` available when the host's arm reads them
///   (`argument.rs`'s host fold).
#[test]
fn every_slot_hosts_exactly_what_the_host_table_says_at_every_shape() {
    for sh in every_shape() {
        let mut hosted_by: Vec<Vec<usize>> = vec![Vec::new(); N_SLOTS];
        walk_definitions(&sh, |def| {
            hosted_by[def.slot] = def.hosted.iter().map(|(s, _)| *s).collect();
        });
        // (a) the literals are the table, slot by slot
        for s in 0..N_SLOTS {
            let want: Vec<usize> = HOSTS.iter().find(|(h, _)| *h == s).map(|(_, l)| l.to_vec()).unwrap_or_default();
            assert_eq!(hosted_by[s], want, "{}: slot {s} [{}] hosts {:?}, the host table says {want:?}", sh.name, SLOT_NAMES[s], hosted_by[s]);
            assert_eq!(
                hosted_by[s].is_empty(),
                SLOT_KINDS[s] != SlotKind::Host,
                "{}: slot {s} [{}] is a {:?} slot and hosts {:?}",
                sh.name,
                SLOT_NAMES[s],
                SLOT_KINDS[s],
                hosted_by[s]
            );
        }
        // (b) every private slot hosted exactly once, nothing else hosted
        let mut times = vec![0usize; N_SLOTS];
        for (host, list) in hosted_by.iter().enumerate() {
            for s in list {
                times[*s] += 1;
                assert!(*s < host, "{}: slot {s} is hosted by slot {host}, which runs BEFORE it", sh.name);
            }
        }
        for s in 0..N_SLOTS {
            assert_eq!(
                times[s],
                usize::from(SLOT_KINDS[s] == SlotKind::Private),
                "{}: slot {s} [{}] is hosted {} times and it is a {:?} slot",
                sh.name,
                SLOT_NAMES[s],
                times[s],
                SLOT_KINDS[s]
            );
        }
        let (hosts, pairs) = (hosted_by.iter().filter(|l| !l.is_empty()).count(), hosted_by.iter().map(|l| l.len()).sum::<usize>());
        assert_eq!((hosts, pairs), (HOSTS.len(), HOSTS.iter().map(|(_, l)| l.len()).sum::<usize>()), "{}: the host map is not the table's size", sh.name);
        eprintln!("S24 C-3 [{}]: {hosts} hosts, {pairs} hosted claims, every private slot hosted exactly once", sh.name);
    }
    // NON-VACUITY, in test code alone: the SAME comparison against a host
    // table with two hosted slots exchanged must FAIL, or the comparison is
    // not a comparison. (`SC_QZC` hosts `[SC_QMM, SC_PV]` and `SC_KVZC` hosts
    // `[SC_KMM, SC_VMM]`; exchanging `SC_PV` and `SC_VMM` keeps every count
    // and every kind, and changes only which host consumes which claim —
    // exactly the soundness defect ruling C-3 is about.)
    let mut broken: Vec<(usize, Vec<usize>)> = HOSTS.iter().map(|(h, l)| (*h, l.to_vec())).collect();
    for (h, l) in broken.iter_mut() {
        if *h == SC_QZC {
            *l = vec![SC_QMM, SC_VMM];
        }
        if *h == SC_KVZC {
            *l = vec![SC_KMM, SC_PV];
        }
    }
    let mut live: Vec<Vec<usize>> = vec![Vec::new(); N_SLOTS];
    walk_definitions(&Shape::rung_g(), |def| live[def.slot] = def.hosted.iter().map(|(s, _)| *s).collect());
    let mismatches = broken.iter().filter(|(h, l)| live[*h] != *l).count();
    assert_eq!(mismatches, 2, "the exchanged host table is not detected by the comparison this test runs");
}

// ---------------------------------------------------------------------------
// ITEM 7 — ruling C-4: the mask budget as a named `Shape::new` refusal
// ---------------------------------------------------------------------------

/// **RULING C-4, the positive half.** Every slot's masked sumcheck message
/// `L_s = (main + ext)·degree + 2` must leave room for the masking
/// commitment's 256 random pads inside its 512-position message row:
/// `L_s + 256 <= 512`. Today that is an ASSERTION inside the prover
/// (`zk::mask_commit`: `part.len() + MASK_Q <= m`) — a panic, deep in a
/// numeric helper, on a shape a caller had already been given.
///
/// Every shape in scope passes with room. This records by how much, so that a
/// shape that came near it would fail HERE rather than at construction.
#[test]
fn the_mask_budget_holds_at_every_shape() {
    for sh in every_shape() {
        let l = sh.slot_lengths();
        let (worst, at) = l.iter().enumerate().fold((0usize, 0usize), |(m, a), (s, v)| if *v > m { (*v, s) } else { (m, a) });
        for (s, v) in l.iter().enumerate() {
            assert!(v + 256 <= 512, "{}: slot {s} [{}] needs {v} + 256 message positions of 512", sh.name, SLOT_NAMES[s]);
        }
        eprintln!("S24 C-4 [{}]: the longest mask is slot {at} [{}] at {worst} + 256 = {} of 512", sh.name, SLOT_NAMES[at], worst + 256);
    }
}

/// **RULING C-4, the refusal.** A shape whose longest masked message leaves no
/// room for the pads is refused BY NAME at construction, where a caller can
/// read it, instead of panicking inside the prover's masking commitment.
///
/// **It IS constructible today, and the probe below is how far you have to
/// go.** The longest mask of every shape is `SC_SZC`'s, whose main round count
/// is `log(Dom::S) = log2(h_pad) + 2·log2(t_pad)` and whose degree is 5 where
/// that domain pads; `L = (log(Dom::S) + 1)·5 + 2` passes 256 at
/// `log(Dom::S) = 51`. The probe is 2^20 − 1 tokens over 2,048 query heads of
/// 8 — every other construction check satisfied (`d_pad = h_pad · head_dim`,
/// the three bilinear domains far above the row width so ruling F-2 does not
/// fire, `Dom::Tab` lifted onto the row width so S-1 does not, a head
/// dimension far below the row width so S-3 does not) — and before this
/// commit `Shape::new` returned it happily. Its CONTROL, the same geometry
/// with one bit fewer of tokens, sits at 252 + 256 and constructs.
///
/// **STAGE 33: the probe's ROW WIDTH moved from 2^14 to 2^21, and nothing
/// else.** Ruling S-6 refuses a padded token count at or above the row width,
/// and at 2^20 tokens the old probe and its control were both in that family
/// — the control, which has to CONSTRUCT, first of all. A wider row puts both
/// back outside it without touching `Dom::S`, which is what this test is
/// about: `log(Dom::S) = log2(h_pad) + 2·log2(t_pad)` has no `log_cols` in it,
/// so the two mask lengths are still 262 and 252 and both are asserted below.
#[test]
fn a_shape_whose_mask_leaves_no_room_for_the_pads_is_refused_by_name() {
    // 2^20 - 1 tokens: `t_pad = 2^20`, `Dom::S = 2^(11 + 20 + 20) = 2^51`, and
    // `Dom::S` PADS (the true size is `q_heads · tokens^2 < 2^51`), so the
    // support indicator takes `SC_SZC`'s degree to 5 and its mask to
    // `(51 + 1)·5 + 2 = 262`. The row width is 2^21, one bit above the padded
    // token count, so ruling S-6 does not fire at either the probe or the
    // control (stage 33).
    let probe = |tokens: usize| Shape::new("S-24 probe: the mask budget", "hashline-zk-mr1/private-block-s24-probe/1", tokens, 16_384, 16_384, 2_048, 8, 1, 21, 4, 9, 37, None, None, None, None);
    let e = probe((1 << 20) - 1).expect_err("a shape whose mask leaves no room for the masking pads was accepted");
    assert!(e.contains("ruling C-4"), "the refusal does not name the ruling: {e}");
    assert!(e.contains("masking commitment"), "the refusal does not name what is short: {e}");
    assert!(e.contains("262"), "the refusal does not state the length it refused: {e}");
    // THE CONTROL: one bit fewer of tokens is `Dom::S = 2^49` and a mask of
    // `(49 + 1)·5 + 2 = 252`, which fits with four positions to spare.
    let ok = probe((1 << 19) - 1).expect("the control one bit below the budget is well formed");
    let worst = *ok.slot_lengths().iter().max().expect("slots");
    assert_eq!(worst, 252, "the control's longest mask moved");
    assert!(worst + 256 <= 512);
    eprintln!("S24 C-4 refusal: 2^20-1 tokens gives a 262-position mask and is refused by name; 2^19-1 gives 252 and constructs");
}

// ---------------------------------------------------------------------------
// ITEM 8 — ruling C-7 (gap S-C1): the closure on extension-round vectors
// ---------------------------------------------------------------------------

/// **RULING C-7, gap S-C1.** The construction premise of the closure property
/// is that a slot's closure, evaluated on the vector `run_slot` builds for
/// extension round `m` — every table that is NOT a private table of that round
/// hard-zeroed (`argument.rs`'s `exts`: `Tab::Priv(p) if p.ext_round == m =>
/// …, _ => Fp2::ZERO`) — is zero. The disposition takes it up as a Rust test
/// at every shape, and says it should hold for ARBITRARY values in the private
/// positions, not only honest ones, because at the shaped layouts every
/// monomial carries a public factor.
///
/// **What this test asserts, and the two mechanisms it separates.**
///
/// 1. **The premise itself**, at every slot, at every shape, at every declared
///    extension round, at three seeds of arbitrary field values in the private
///    positions: the closure is ZERO. Arbitrary values, so this is an identity
///    and not a statement about honest data.
/// 2. **Which mechanism produces it.** Zeroing only the PUBLIC tables and
///    giving every private table an arbitrary value distinguishes them: if
///    every monomial carries a public factor the closure is still zero, and if
///    a monomial is a product of private factors alone it is not. At the four
///    SHAPED layouts that probe gives zero for all 23 slots — the disposition's
///    stronger statement, `poly(exts)` is the ZERO POLYNOMIAL. At the frozen
///    TOY it gives zero for 21 slots and NON-ZERO for slots 08 and 09, whose
///    monomial at `lkv = 0` is the bare product of the two private factors:
///    there the premise holds by the SECOND mechanism, the other private
///    factor being zeroed because it is extended in the other round. That is
///    exactly the one place the checker's reading says it is needed, and the
///    non-zero value is what makes part 1 non-vacuous.
#[test]
fn the_closure_vanishes_on_every_extension_round_vector_at_every_shape() {
    for sh in every_shape() {
        let lkv = clog2(sh.kv_heads);
        let mut public_only_nonzero: Vec<usize> = Vec::new();
        let mut checked = 0usize;
        walk_definitions(&sh, |def| {
            let (_, ext, _) = sh.slots()[def.slot];
            for m in 0..ext {
                for seed in [0x5C10_5024u64, 0x0BAD_C0DE, 0xDEAD_BEEF] {
                    let mut r = Rng(seed ^ ((def.slot as u64) << 32) ^ (m as u64));
                    let vals: Vec<Fp2> = def
                        .tabs
                        .iter()
                        .map(|t| match t {
                            Tab::Priv(p) if p.ext_round == m => r.fp2(),
                            _ => Fp2::ZERO,
                        })
                        .collect();
                    assert!(
                        (def.poly)(&vals).is_zero(),
                        "{}: slot {} [{}]: the closure is NOT zero on an extension-round-{m} vector (seed {seed:#x})",
                        sh.name,
                        def.slot,
                        SLOT_NAMES[def.slot]
                    );
                    checked += 1;
                }
            }
            // the mechanism probe: every private table arbitrary, every public
            // table zero
            let mut r = Rng(0x0C10_5024 ^ (def.slot as u64));
            let vals: Vec<Fp2> = def
                .tabs
                .iter()
                .map(|t| match t {
                    Tab::Priv(_) => r.fp2(),
                    _ => Fp2::ZERO,
                })
                .collect();
            if !(def.poly)(&vals).is_zero() {
                public_only_nonzero.push(def.slot);
            }
        });
        assert!(checked >= 23 * 3, "{}: only {checked} closure evaluations", sh.name);
        let want: Vec<usize> = if lkv == 0 { vec![SC_SCORE, SC_PV] } else { vec![] };
        assert_eq!(
            public_only_nonzero, want,
            "{}: the slots whose closure survives zeroing every PUBLIC table are {public_only_nonzero:?}, expected {want:?}",
            sh.name
        );
        eprintln!(
            "S24 C-7 [{}]: {checked} evaluations, all zero; with only the public tables zeroed {} slot(s) survive ({}), so the mechanism is {}",
            sh.name,
            public_only_nonzero.len(),
            if public_only_nonzero.is_empty() { "none".to_string() } else { format!("{public_only_nonzero:?}") },
            if public_only_nonzero.is_empty() { "a public factor in every monomial" } else { "the other private factor, for the two bilinear slots" }
        );
    }
}

// ---------------------------------------------------------------------------
// ITEM 9 — ruling H-1: an inadmissible chain is refused before any segment
// ---------------------------------------------------------------------------

fn s24_context() -> Digest {
    *blake3::hash(b"private block: stage 24, ruling H-1's sealing pass").as_bytes()
}

/// one committed plane of a witness, as the `int16` words an IO commitment
/// carries
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// the TRUE `tokens x width` hidden state inside a padded `(t_pad, d_pad)` plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// **THE SEALING PASS OF RULING H-1.** A run's witness source, built the way
/// the ruling says a production caller must build one: block by block through
/// `witness::build_shaped`, **with its refusals**, so that the external output
/// endpoint plane exists only if every block of the chain is admissible. It is
/// the lane's own run harness (`run_tests::Chain::from_parts`,
/// `k4_tests::K4Chain::build`) with one difference: those `expect` a witness,
/// because they are used where the chain is known good, and this one returns
/// the refusal so a test can see WHERE it happened.
struct SealedChain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl SealedChain {
    fn seal(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> Result<SealedChain, String> {
        let ids = Ids::new(sh)?;
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).map_err(|e| format!("block {} of {l}: {e}", k + 1))?;
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output()?);
        }
        Ok(SealedChain { sh: sh.clone(), public, ff, inputs, planes })
    }
}

impl RunWitnessSource for SealedChain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// A production-shaped caller: SEAL the endpoints with the witness builder's
/// own pass, then make the run directory, then prove. `entered` is set on the
/// line before `prove_run`, so a test can say whether the prover was reached
/// at all.
fn seal_then_prove(sh: &Shape, l: usize, down: i64, dir: &std::path::Path, entered: &mut bool) -> Result<(Vec<usize>, usize), String> {
    use super::dense_tests::{dense_words_with, statement_of_words, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    let (words, x0) = dense_words_with(sh, BAND_ATTN, BAND_GATE, down, GAIN, INPUT_MAG);
    let (public, ff) = statement_of_words(sh, &words);
    // THE PASS THAT SEALS THE ENDPOINTS. Ruling H-1: it is the witness
    // builder's own, refusals included, and it runs before the header exists.
    let mut chain = SealedChain::seal(sh, l, public.clone(), ff.clone(), x0)?;
    let blocks: Vec<BlockPublic> = (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect();
    let rs = RunShape::rung_g(l)?;
    let spec = IoSpec::new_shaped(sh, s24_context(), 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &chain.planes[0], &chain.planes[l])?;
    let st = RunStatement::new(rs, s24_context(), expected, &blocks, &vec![(0, 0); l])?;
    let rows = st.boundary_spec(0)?.commitment_rows();
    std::fs::create_dir_all(dir).map_err(|e| format!("the test's run directory {}: {e}", dir.display()))?;
    let mut disk = DirSink::create(dir, l)?;
    *entered = true;
    let stats = run::prove_run(&st, &blocks, &mut chain, owners, &mut |k, bytes| disk.accept(k, bytes))?;
    Ok((stats.segment_bytes, rows))
}

/// A directory of the machine's temporary space, removed when the test leaves.
struct TempDir(std::path::PathBuf);

impl TempDir {
    fn new(tag: &str) -> TempDir {
        let n = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
        let p = std::env::temp_dir().join(format!("hl-s24-{tag}-{}-{n}", std::process::id()));
        std::fs::create_dir_all(&p).unwrap_or_else(|e| panic!("the test's temporary directory {}: {e}", p.display()));
        TempDir(p)
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// **RULING H-1.** The run header absorbs the expected-IO bytes, which carry
/// BOTH external endpoint commitment roots, before any challenge exists — so
/// the prover has already run the whole forward pass before the header, and
/// the ruling's new rule for a production caller is that **the pass which
/// seals the endpoints is the witness builder's own, with its refusals**. Then
/// an inadmissible chain is refused before the header and no partial run
/// directory can arise from that cause. (Rule M-9, the statement writer that
/// publishes only after the whole run verifies, stays as the second line.)
///
/// This is that rule, exercised. A three-block rung-G chain at the
/// single-block dense band — one band above the measured chain band — is
/// inadmissible at a LATER BLOCK, `fixed oracle range refusal: residual 2`,
/// because `z16`'s spread compounds along the chain (stage 21's finding).
/// **MEASURED, 2026-09-21: at rung-G, band 48, it is the THIRD block of
/// three** — not the second, which is where the 125M band search hit it at
/// every refused band (stage 21, `u4-s21-m125-band.log`). The block index is
/// PARSED out of the refusal rather than assumed, and what the test requires
/// is that it is not the first: the whole point is that only a pass over the
/// WHOLE chain can see it. At rung-G it is the last block, whose output plane
/// is exactly what the external output endpoint seals, so a caller that had
/// not run the whole pass could not even have formed the statement.
///
/// The sealing pass returns that refusal, and:
///
/// * `prove_run` is NEVER ENTERED — the flag set on the line before the call
///   is still false;
/// * the run directory does NOT EXIST — it is created after the seal, so
///   there is no directory, no segment and no `.partial`;
/// * and the refusal names the block, so a caller knows which one.
///
/// **The positive control is the same function**, at the measured chain band:
/// it reaches the prover and leaves exactly three segment files of the counted
/// lengths. Without it this test would pass on a harness that could never
/// prove anything.
#[test]
fn an_inadmissible_chain_is_refused_before_the_run_directory_exists() {
    use super::dense_tests::{band_down, band_down_run};
    let sh = Shape::rung_g();
    let tmp = TempDir::new("h1");
    let (admissible, inadmissible) = (band_down_run(&sh), band_down(&sh));
    assert!(inadmissible > admissible, "the single-block band is not above the measured chain band; this test has nothing to force");

    // (1) THE INADMISSIBLE CHAIN.
    let dir = tmp.0.join("refused");
    let mut entered = false;
    let e = seal_then_prove(&sh, 3, inadmissible, &dir, &mut entered).expect_err("an inadmissible three-block chain was proved");
    assert!(e.contains("fixed oracle range refusal: residual 2"), "the chain was not refused at the residual: {e}");
    // WHICH block, parsed from the refusal and not assumed
    let which: usize = e.strip_prefix("block ").and_then(|s| s.split(' ').next()).and_then(|s| s.parse().ok()).unwrap_or_else(|| panic!("the refusal does not name the block: {e}"));
    assert!(which >= 2, "the chain was refused at its FIRST block, so no pass over the chain was needed to see it: {e}");
    assert_eq!(which, 3, "MEASURED 2026-09-21: at rung-G, band {inadmissible} is refused at the THIRD block of three; it has moved");
    assert!(!entered, "prove_run was entered although the sealing pass had refused");
    assert!(!dir.exists(), "a run directory was created for a chain that never reached the prover");

    // (2) THE POSITIVE CONTROL, the same function at the measured band.
    let ok_dir = tmp.0.join("proved");
    let mut entered_ok = false;
    let t0 = std::time::Instant::now();
    let (lens, rows) = seal_then_prove(&sh, 3, admissible, &ok_dir, &mut entered_ok).expect("the admissible three-block chain proves");
    assert!(entered_ok, "the control never reached prove_run");
    assert_eq!(lens, super::run_tests::counted_segment_bytes(&sh, 3, rows), "a control segment is not the counted length");
    let mut names = super::run_sink::dir_entry_names(&ok_dir).expect("the control's run directory");
    names.sort();
    assert_eq!(names, vec!["segment-000.bin".to_string(), "segment-001.bin".to_string(), "segment-002.bin".to_string()], "the control's run directory holds something else");
    eprintln!(
        "S24 H-1: band {inadmissible} refused at block {which} of 3 before the header (no directory, no segment); band {admissible} sealed and proved 3 segments {lens:?} B in {:.2} s",
        t0.elapsed().as_secs_f64()
    );
}
