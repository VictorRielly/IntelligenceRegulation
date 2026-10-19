//! Tests of the two hash-domain guards (rulings T-3 and T-4). Nothing here
//! proves at a large shape: the only proof any of these runs is the toy
//! block's, which the suite already proves several times over.

use crate::pcs::PcsParams;
use crate::private_block::layout::{Layout, M_ROWS};
use crate::private_block::shape::Shape;
use crate::private_block::{compute_output, prepare_endpoints, prove_with_stats, verify_bytes, BlockPublic, ExpectedIo, IoSpec, Receipt};

fn shapes() -> [Shape; 4] {
    [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::m125()]
}

// =====================================================================  T-3

/// **The formulas this module is built on are still `zkp-core`'s.** The
/// length set is arithmetic over three hashers in files this lane does not
/// edit; if one of them changes shape, every number here is wrong and the
/// guard silently stops guarding. So the three bodies are pinned by their own
/// source text. This is the weakest link in T-3 and it is named as such in
/// the ledger: it pins the TEXT of the hashers, not their behaviour.
#[test]
fn the_length_formulas_are_still_the_ones_zkp_core_hashes() {
    let tr = include_str!("../../../zkp-core/src/transcript.rs");
    // Transcript::new -> 12 + |domain|
    assert!(tr.contains("h.update(b\"hashline-v1/\");\n        h.update(domain);"), "Transcript::new no longer hashes the 12-byte prefix then the domain");
    // absorb -> 32 + 8 + |label| + 8 + |data|
    assert!(
        tr.contains("h.update(&self.state);\n        h.update(&(label.len() as u64).to_le_bytes());\n        h.update(label);\n        h.update(&(data.len() as u64).to_le_bytes());\n        h.update(data);"),
        "Transcript::absorb no longer hashes state | label len | label | data len | data"
    );
    // squeeze -> 32 + 7 + 8
    assert!(tr.contains("h.update(&self.state);\n        h.update(b\"squeeze\");\n        h.update(&self.counter.to_le_bytes());"), "the squeeze no longer hashes state | \"squeeze\" | counter");
    let rng = include_str!("../../../zkp-core/src/rng.rs");
    assert!(rng.contains("h.update(&self.key);\n        h.update(&self.counter.to_le_bytes());"), "ZkRng::refill no longer hashes a 40-byte block");
    let mk = include_str!("../../../zkp-core/src/merkle.rs");
    assert!(mk.contains("pub fn hash_pair(a: &Digest, b: &Digest) -> Digest"), "the Merkle node is no longer blake3 over two digests");
    let pcs = include_str!("../../../zkp-core/src/pcs.rs");
    assert!(pcs.contains("fn salt_leaf"), "the salted leaf is gone from pcs.rs");
    // and the constants this module derives from them
    assert_eq!(super::ABSORB_FIXED, 48);
    assert_eq!(super::NEW_FIXED, 12);
    assert_eq!(super::SQUEEZE_LEN, 47);
    assert_eq!(super::REFILL_LEN, 40);
    assert_eq!(super::NODE_LEN, 64);
    assert_eq!(super::EXPECTED_IO_BYTES, 112);
}

/// **The shape-free set is the memo's "at every shape" row** — `{5, 8, 11,
/// 12, 13, 15, 17, 19}` — and it is what the two statement constructors that
/// hold no profile string can check for themselves.
#[test]
fn the_shape_free_dangerous_row_counts_are_the_memos_eight() {
    let got: Vec<usize> = super::shape_free().dangerous_rows().keys().copied().collect();
    assert_eq!(got, vec![5, 8, 11, 12, 13, 15, 17, 19], "the shape-free dangerous row counts moved");
    // and each one names the input it would be confused with
    let set = super::shape_free();
    for (r, want) in [(5usize, "refill"), (8, "Merkle"), (11, "schedule"), (12, "public-statement"), (13, "sc-round"), (15, "sc-round"), (17, "sc-round"), (19, "sc-round")] {
        let d = set.describe(8 * r).unwrap_or_else(|| panic!("{r} rows describes nothing"));
        assert!(d.contains(want), "{r} rows: {d} does not mention {want}");
    }
}

/// **THE SWEEP (T-3).** At every shape, every dangerous row count the guard
/// computes is refused BY NAME, and the refusal carries the commitment's
/// name, its row count, its column's byte length and the condition's id. The
/// memo's own table is asserted where it overlaps: 5, 8, 11, 12, 13, 15, 17
/// and 19 at every shape, 6 at 125M, 7 at the frozen-seam rung.
#[test]
fn every_dangerous_row_count_is_refused_by_name_at_every_shape() {
    for sh in shapes() {
        let set = super::at_shape(&sh);
        let rows = set.dangerous_rows();
        // the memo's "at every shape" eight
        for r in [5usize, 8, 11, 12, 13, 15, 17, 19] {
            assert!(rows.contains_key(&r), "{}: {r} rows is not in the computed set", sh.name);
        }
        // the memo's per-shape two
        assert_eq!(rows.contains_key(&6), sh.profile == Shape::m125().profile, "{}: 6 rows", sh.name);
        assert_eq!(rows.contains_key(&7), sh.profile == Shape::rung().profile, "{}: 7 rows", sh.name);
        // every one of them refuses, by name
        for (r, collides) in &rows {
            let e = set.refuse(&[("A", 455), ("probe", *r)]).expect_err(&format!("{}: {r} rows was accepted", sh.name));
            assert!(e.contains("the probe commitment"), "{e}");
            assert!(e.contains(&format!("has {r} rows")), "{e}");
            assert!(e.contains(&format!("{} bytes", 8 * r)), "{e}");
            assert!(e.contains("C-H4"), "{e}");
            assert!(e.contains(collides.as_str()), "{}: the refusal does not name the collision: {e}", sh.name);
        }
        // the existing callers' message shape is unchanged for 8 rows
        let e = super::super::layout::no_commitment_has_a_node_shaped_column(&[("A", 455), ("probe", 8)]).expect_err("8 rows must be refused");
        assert!(e.contains("C-H4") && e.contains("64 bytes"), "{e}");
    }
}

/// **THE FAILING TEST OF T-3, written before the fix.** The guard the two
/// statement constructors call — `EndpointSpecG::new` and
/// `BoundarySpec::new`, which hold no profile string — must refuse every
/// shape-free dangerous count, not only the two the hard-coded `{5, 8}` knew
/// about. Against the old body this fails at 11 rows.
#[test]
fn the_constructors_guard_refuses_every_shape_free_dangerous_count() {
    for r in [5usize, 8, 11, 12, 13, 15, 17, 19] {
        let e = super::super::layout::no_commitment_has_a_node_shaped_column(&[("general endpoint", r)]).expect_err(&format!("{r} rows was accepted by the constructors' guard"));
        assert!(e.contains("C-H4") && e.contains(&format!("{} bytes", 8 * r)), "{e}");
    }
    // and the real counts still pass
    super::super::layout::no_commitment_has_a_node_shaped_column(&[("A", 455), ("H", 384), ("M", 50), ("endpoint", 7), ("general endpoint", 9), ("internal boundary", 10), ("endpoint", 37), ("internal boundary", 38)])
        .expect("no accepted geometry is refused");
}

/// **The exact set at each of the four shapes**, so that a change to a label,
/// to a profile string or to a geometry cannot move it silently. The large
/// entries are the `pcs-prox` clear vector (`56 + 16 (n + Q)` bytes, always a
/// multiple of eight); they are listed because the set is computed and not
/// curated, and no commitment is remotely near them.
#[test]
fn the_computed_length_set_is_pinned_at_every_shape() {
    let eight = [5usize, 8, 11, 12, 13, 15, 17, 19];
    let want: [(&str, Vec<usize>); 4] = [
        ("toy", vec![1031]),
        ("rung", vec![7, 1031, 2567]),
        ("rung-g", vec![2567]),
        ("m125", vec![6, 33287]),
    ];
    for (sh, (name, extra)) in shapes().into_iter().zip(want) {
        let mut expect: Vec<usize> = eight.to_vec();
        expect.extend(extra);
        expect.sort_unstable();
        expect.dedup();
        let got: Vec<usize> = super::at_shape(&sh).dangerous_rows().keys().copied().collect();
        assert_eq!(got, expect, "{name} ({}): the dangerous row counts moved", sh.name);
    }
    // the two shape-dependent lengths the memo counted, re-derived here
    for (sh, new_len, param_len) in [(Shape::toy(), 51usize, 171usize), (Shape::rung(), 56, 210), (Shape::rung_g(), 58, 210), (Shape::m125(), 48, 215)] {
        assert_eq!(super::NEW_FIXED + sh.profile.len(), new_len, "{}: the transcript constructor's input length", sh.name);
        assert_eq!(super::ABSORB_FIXED + "parameters".len() + super::super::protocol::parameter_line(&sh).len(), param_len, "{}: the parameters absorb length", sh.name);
    }
}

/// **The four shapes' real commitments are all clear of their own sets** —
/// which is why T-3 moves no byte of any profile. The toy's 455, 384, 50 and
/// 7 are asserted by hand as well, because they are the frozen ones.
#[test]
fn no_commitment_of_any_shape_collides_and_the_toy_is_clear() {
    for sh in shapes() {
        let lay = Layout::for_shape(&sh).expect("the shape is well formed");
        super::at_shape(&sh)
            .refuse(&[("A", lay.a_rows), ("H", lay.h_rows), ("M", M_ROWS), ("endpoint", sh.endpoint_rows)])
            .unwrap_or_else(|e| panic!("{}: {e}", sh.name));
    }
    let toy = Shape::toy();
    let lay = Layout::for_shape(&toy).expect("the toy");
    assert_eq!((lay.a_rows, lay.h_rows, M_ROWS, toy.endpoint_rows), (455, 384, 50, 7), "the toy's frozen row counts moved");
    super::at_shape(&toy).refuse(&[("A", 455), ("H", 384), ("M", 50), ("endpoint", 7)]).expect("the toy's four commitments are clear of the toy's own length set");
    // the rung-G boundary and the 125M boundary, which `Layout` does not carry
    super::at_shape(&Shape::rung_g()).refuse(&[("internal boundary", 10)]).expect("the rung-G boundary");
    super::at_shape(&Shape::m125()).refuse(&[("internal boundary", 38)]).expect("the 125M boundary");
}

/// The run adds one absorb whose length no block has — its own `parameters`
/// word, which moves with `L` — so the run's set is computed from the run's
/// line and not from the block's.
#[test]
fn the_runs_own_parameter_line_enters_the_length_set() {
    let sh = Shape::m125();
    let line = "x".repeat(246);
    let with = super::at_shape_with(&sh, Some(line.as_str()));
    let without = super::at_shape(&sh);
    let len = super::ABSORB_FIXED + "parameters".len() + line.len();
    assert_eq!(len % 8, 0, "the probe line was chosen to make a multiple of eight");
    assert!(with.describe(len).is_some(), "the run's parameter line is not in the run's set");
    assert!(without.describe(len).is_none(), "a block's set carries the run's parameter line");
    assert!(with.refuse(&[("internal boundary", len / 8)]).is_err(), "the run's set does not refuse a commitment of that column length");
}

/// **FINDING S16-F1, as a test.** The completed guard is not decorative: the
/// generalised endpoint's reachable commitment row counts are
/// `2^k + MASK_ROWS` = 6, 7, 9, 13, 21, 37, ... and three of them are in the
/// set. 13 is refused at every profile (its column is 104 bytes, a degree-2
/// `sc-round` absorb); 6 is refused at the 125M profile and 7 at the
/// frozen-seam rung (their transcript constructors, 48 and 56 bytes). An
/// internal boundary's counts are `2^k + 2 s + 2`, which reaches 12 at
/// `s = 3` on a four-data-row plane — the `public-statement` absorb. Two
/// existing statement fixtures had to move off 13 and 12 for this stage;
/// neither is a geometry any accepted profile uses.
#[test]
fn the_completed_guard_refuses_geometries_the_constructions_can_actually_reach() {
    let reachable_endpoint: Vec<usize> = (0..6).map(|k| (1usize << k) + 5).collect();
    assert_eq!(reachable_endpoint, vec![6, 7, 9, 13, 21, 37]);
    let free = super::shape_free();
    for r in &reachable_endpoint {
        let refused = free.refuse(&[("general endpoint", *r)]).is_err();
        assert_eq!(refused, *r == 13, "the shape-free guard's verdict on {r} endpoint rows changed");
    }
    // 6 and 7 need the profile string to be seen at all
    assert!(super::at_shape(&Shape::m125()).refuse(&[("general endpoint", 6)]).is_err(), "6 rows is clear at the 125M profile");
    assert!(super::at_shape(&Shape::rung()).refuse(&[("general endpoint", 7)]).is_err(), "7 rows is clear at the frozen-seam rung");
    assert!(super::at_shape(&Shape::toy()).refuse(&[("general endpoint", 7)]).is_ok(), "the toy's own 7-row endpoint must stay accepted");
    // a boundary at three claim sites on a four-data-row plane
    assert!(free.refuse(&[("internal boundary", 4 + 2 * 3 + 2)]).is_err(), "12 boundary rows is clear");
    assert!(free.refuse(&[("internal boundary", 4 + 2 * 4 + 2)]).is_ok(), "14 boundary rows must stay accepted");
}

// ------------------------- STAGE 18: T-3 AS AMENDED AT THE TWO BARE CONSTRUCTORS

/// The two geometries stage 17 recorded as its deviation, spelled once so
/// that both halves of the test below use exactly the same numbers.
///
/// * a GENERALISED ENDPOINT of 13 rows: a `32 x 32` plane over a `2^7` row
///   width is `2^3 = 8` data rows, plus `MASK_ROWS = 5`. Its column is 104
///   bytes, which is a degree-2 `sc-round` absorb.
/// * an INTERNAL BOUNDARY of 12 rows: the same plane over a `2^8` row width
///   is `2^2 = 4` data rows, plus `2 * 3` reserved rows at three claim sites
///   plus the proximity pair. Its column is 96 bytes, which is the
///   `public-statement` absorb.
fn s18_ctx() -> crate::merkle::Digest {
    *blake3::hash(b"stage 18: T-3 amended at the two bare statement constructors").as_bytes()
}

/// **THE FAILING TEST OF STAGE 18 ITEM 1, written before the fix.**
///
/// Ruling T-3 as amended imposes the completed length guard on LEGACY-RULE
/// profiles only, because on a tagged profile a transcript absorb, a column
/// digest, a salted leaf and a Merkle node are four different members of the
/// BLAKE3 family and a coincidence of input lengths between two of them means
/// nothing. Stage 17 could not carry that through
/// `EndpointSpecG::new` and `BoundarySpec::new`: they hold no profile string,
/// so they kept refusing the shape-free eight at every profile, which stage 17
/// recorded as a deviation from the letter of the amended ruling.
///
/// This test states the amended rule at those two constructors: the two
/// geometries above CONSTRUCT under a tag and are still REFUSED BY NAME under
/// the legacy rule. Against stage 17's code the two tagged constructions fail.
#[test]
fn the_length_guard_does_not_fire_at_a_tagged_profiles_statement_constructors() {
    use crate::private_block::boundary::BoundarySpec;
    use crate::private_block::endpoint_g::EndpointSpecG;
    use zkp_core::hashtag::HashTag;
    let tag = Shape::rung_g().hash_tag();
    assert!(!tag.is_legacy(), "rung-G must be tagged for this test to mean anything");
    let legacy = HashTag::legacy();
    let c = s18_ctx();

    // (1) THE TAGGED SIDE: both geometries construct, and their row counts
    // are the ones the amended ruling is about.
    let ep = EndpointSpecG::new_with_tag(c, 32, 32, 0, 41, 42, 7, 2, 32, &tag).expect("a TAGGED 13-row generalised endpoint must construct (T-3 amended)");
    assert_eq!(ep.commitment_rows(), 13, "the fixture is not the 2^3 + 5 geometry");
    let b = BoundarySpec::new_with_tag(c, 32, 32, 0, 1, 3, 8, 2, 32, 12, &tag).expect("a TAGGED 12-row internal boundary must construct (T-3 amended)");
    assert_eq!(b.commitment_rows(), 12, "the fixture is not the 4 + 2*3 + 2 geometry");

    // (2) THE LEGACY SIDE: the SAME geometries, refused by name, exactly as
    // after stage 16. Both the explicit legacy tag and the bare constructor.
    for (what, e) in [
        ("an explicitly legacy 13-row endpoint", EndpointSpecG::new_with_tag(c, 32, 32, 0, 41, 42, 7, 2, 32, &legacy).expect_err("13 endpoint rows must be refused under the legacy rule")),
        ("a bare-constructor 13-row endpoint", EndpointSpecG::new(c, 32, 32, 0, 41, 42, 7, 2, 32).expect_err("13 endpoint rows must be refused by the bare constructor")),
    ] {
        assert!(e.contains("C-H4"), "{what}: {e}");
        assert!(e.contains("104 bytes"), "{what}: {e}");
        assert!(e.contains("13 rows"), "{what}: {e}");
        assert!(e.contains("sc-round"), "{what}: the refusal does not name the collision: {e}");
    }
    for (what, e) in [
        ("an explicitly legacy 12-row boundary", BoundarySpec::new_with_tag(c, 32, 32, 0, 1, 3, 8, 2, 32, 12, &legacy).expect_err("12 boundary rows must be refused under the legacy rule")),
        ("a bare-constructor 12-row boundary", BoundarySpec::new(c, 32, 32, 0, 1, 3, 8, 2, 32, 12).expect_err("12 boundary rows must be refused by the bare constructor")),
    ] {
        assert!(e.contains("C-H4"), "{what}: {e}");
        assert!(e.contains("96 bytes"), "{what}: {e}");
        assert!(e.contains("12 rows"), "{what}: {e}");
        assert!(e.contains("public-statement"), "{what}: the refusal does not name the collision: {e}");
    }

    // (3) EVERY OTHER CHECK OF BOTH CONSTRUCTORS IS UNCHANGED UNDER A TAG.
    // The tag switches off the length guard and nothing else: ruling M-1's
    // declared-row check, the plane's power-of-two axes, the row geometry and
    // the pad count all still refuse, by their own names, under the tag.
    let e = BoundarySpec::new_with_tag(c, 32, 32, 0, 1, 3, 8, 2, 32, 13, &tag).expect_err("ruling M-1's declared-row check must still fire under a tag");
    assert!(e.contains("declares 13 rows") && e.contains("give 12"), "{e}");
    let e = EndpointSpecG::new_with_tag(c, 24, 32, 0, 41, 42, 7, 2, 32, &tag).expect_err("a non-power-of-two axis must still be refused under a tag");
    assert!(e.contains("power-of-two axes"), "{e}");
    let e = EndpointSpecG::new_with_tag(c, 32, 32, 0, 41, 42, 7, 2, 0, &tag).expect_err("a zero pad count must still be refused under a tag");
    assert!(e.contains("pad count"), "{e}");
    let e = BoundarySpec::new_with_tag(c, 32, 32, 0, 1, 9, 8, 2, 32, 12, &tag).expect_err("nine claim sites must still be refused under a tag");
    assert!(e.contains("claim sites"), "{e}");

    // (4) AND NO ACCEPTED PROFILE'S REAL GEOMETRY MOVED. rung-G's endpoint is
    // 9 rows and its boundary 10; 125M's are 37 and 38. None is in the set, so
    // this change makes no difference to any profile that exists today — which
    // is why stage 17 could record it as a deviation and leave it.
    for r in [9usize, 37] {
        assert!(super::shape_free().refuse(&[("general endpoint", r)]).is_ok(), "{r} endpoint rows is in the shape-free set");
    }
    for r in [10usize, 38] {
        assert!(super::shape_free().refuse(&[("internal boundary", r)]).is_ok(), "{r} boundary rows is in the shape-free set");
    }
}

/// **THE GUARD IS STILL WHOLE ON THE PATH THAT REACHES IT IN PRODUCTION.**
/// Item 1 changes WHICH profiles the two bare constructors impose the length
/// set on; it changes nothing about the set, and nothing about the other two
/// sites that impose it — `Layout::for_shape` and `RunStatement::new`, which
/// hold a shape and were already legacy-only after stage 17. This test pins
/// that the legacy-rule profiles still have the whole shape-free eight at the
/// constructors, which is what stage 16 landed.
#[test]
fn the_constructors_guard_is_unchanged_under_the_legacy_rule() {
    use zkp_core::hashtag::HashTag;
    let legacy = HashTag::legacy();
    assert!(legacy.is_legacy());
    for r in [5usize, 8, 11, 12, 13, 15, 17, 19] {
        let e = super::super::layout::no_commitment_has_a_node_shaped_column_under(&[("general endpoint", r)], &legacy).expect_err(&format!("{r} rows was accepted under the legacy rule"));
        assert!(e.contains("C-H4") && e.contains(&format!("{} bytes", 8 * r)), "{e}");
        // and the same count is CLEAR under a tag
        super::super::layout::no_commitment_has_a_node_shaped_column_under(&[("general endpoint", r)], &Shape::rung_g().hash_tag()).unwrap_or_else(|e| panic!("{r} rows was refused under a tag: {e}"));
    }
    // the two legacy-rule profiles' own commitments are still checked and
    // still pass, at the constructors' shape-free half
    super::super::layout::no_commitment_has_a_node_shaped_column(&[("A", 455), ("H", 384), ("M", 50), ("endpoint", 7)]).expect("the toy's own counts are refused");
}

// -------------------------------------------- the label table's own coverage

/// Every line of the lane's own non-test sources that calls an `absorb` with
/// a literal byte-string label, one label per line.
fn absorb_labels(src: &str) -> Vec<String> {
    let cut = src.find("\n#[cfg(test)]\nmod tests {").map(|k| k + 1).unwrap_or(src.len());
    let mut out = Vec::new();
    for line in src[..cut].lines() {
        let t = line.trim_start();
        if t.starts_with("//") || t.starts_with('*') || !line.contains("absorb") {
            continue;
        }
        let after = &line[line.find("absorb").expect("present")..];
        let Some(s) = after.find("b\"") else { continue };
        let rest = &after[s + 2..];
        let Some(e) = rest.find('"') else { continue };
        out.push(rest[..e].to_string());
    }
    out
}

/// **THE TABLE'S COVERAGE TEST (T-3).** `Transcript` lives in a crate this
/// lane may not edit, so no recording wrapper can be installed; the label set
/// is pinned instead by SCANNING SOURCE.
///
/// How strong this is, said plainly:
///
/// * The lane's own files are scanned exhaustively, and any `absorb` with a
///   LITERAL label that the table does not carry fails this test. A call with
///   a VARIABLE label is invisible to it; there are two on the path
///   (`protocol::absorb_root` at `protocol.rs:129` and `zk::absorb_com` at
///   `zk.rs:867-868`) and both are covered because their CALLERS spell the
///   literal, which the scan does see.
/// * `hashline/src/zk.rs`, `zkp-core/src/pcs.rs` and
///   `zkp-core/src/sumcheck.rs` are scanned too, with an explicit list of the
///   labels of theirs that are NOT on the private block's path (they belong
///   to the feed-forward layer prover). If one of those files grows a new
///   label, this test fails and someone has to decide which list it joins.
/// * What it cannot see: a label reached through a call chain into a fourth
///   file, and any absorb whose label is computed. Neither exists today.
#[test]
fn every_absorb_label_on_the_path_is_in_the_table() {
    let entries = super::path_labels(&Shape::m125(), None);
    for u in &entries {
        assert!(!u.label.is_empty() && !u.site.is_empty() && !u.data.is_empty(), "the table entry for `{}` is incomplete", u.label);
    }
    let table: Vec<String> = entries.iter().map(|u| u.label.to_string()).collect();
    let lane: [(&str, &str); 18] = [
        ("argument.rs", include_str!("argument.rs")),
        ("boundary.rs", include_str!("boundary.rs")),
        ("endpoint_g.rs", include_str!("endpoint_g.rs")),
        ("layout.rs", include_str!("layout.rs")),
        ("pad.rs", include_str!("pad.rs")),
        ("plane_index.rs", include_str!("plane_index.rs")),
        ("protocol.rs", include_str!("protocol.rs")),
        ("run.rs", include_str!("run.rs")),
        ("run_capture.rs", include_str!("run_capture.rs")),
        ("run_sink.rs", include_str!("run_sink.rs")),
        ("shape.rs", include_str!("shape.rs")),
        ("wire.rs", include_str!("wire.rs")),
        ("witness.rs", include_str!("witness.rs")),
        ("private_block.rs", include_str!("../private_block.rs")),
        // TOKEN I/O R1 LANE: the token-I/O run's sources (they absorb only
        // labels the table already carries: the block run's own)
        ("token_io.rs", include_str!("token_io.rs")),
        ("token_io/stage_in.rs", include_str!("token_io/stage_in.rs")),
        ("token_io/stage_out.rs", include_str!("token_io/stage_out.rs")),
        ("token_io/run.rs", include_str!("token_io/run.rs")),
    ];
    let mut seen = 0usize;
    for (name, src) in lane {
        for l in absorb_labels(src) {
            seen += 1;
            assert!(table.contains(&l), "{name} absorbs `{l}`, which the label table of hash_domain.rs does not carry");
        }
    }
    assert!(seen >= 40, "the lane source scan found only {seen} labelled absorbs; it has stopped working");
    // this module never touches a transcript
    assert!(!include_str!("hash_domain.rs").contains(".absorb"), "hash_domain.rs has grown an absorb");

    // the three foreign files, with the labels that are NOT on this path
    const NOT_ON_THE_BLOCK_PATH: [&str; 24] = [
        "W", "d-claim", "d-term", "gamma-pred", "gamma-tab", "gamma-zs", "gamma17", "gamma20", "gammaD", "gammaF", "gu-claim", "gu-term", "layer", "pred-term", "shifts", "t_rows", "tab-term", "table", "zc17-term",
        "zc20-term", "zcD-term", "zcF-term", "zk", "zs-term",
    ];
    let foreign: [(&str, &str); 3] = [
        ("hashline/src/zk.rs", include_str!("../zk.rs")),
        ("zkp-core/src/pcs.rs", include_str!("../../../zkp-core/src/pcs.rs")),
        ("zkp-core/src/sumcheck.rs", include_str!("../../../zkp-core/src/sumcheck.rs")),
    ];
    let mut foreign_seen = 0usize;
    for (name, src) in foreign {
        for l in absorb_labels(src) {
            foreign_seen += 1;
            assert!(
                table.contains(&l) || NOT_ON_THE_BLOCK_PATH.contains(&l.as_str()),
                "{name} absorbs `{l}`: it is neither in hash_domain.rs's label table nor in the list of labels this path does not use"
            );
        }
    }
    assert!(foreign_seen >= 40, "the foreign source scan found only {foreign_seen} labelled absorbs; it has stopped working");
    // the five labels this path uses that no lane file spells
    for l in ["sc-round", "mask-q", "mask-prox", "pcs-vec", "pcs-prox"] {
        assert!(table.contains(&l.to_string()), "`{l}` left the table");
    }
}

// =====================================================================  T-4

/// The tree depth the guard uses is the one the FRAME uses, at every
/// geometry this module builds — one expression, not two.
#[test]
fn the_tree_depth_is_the_wire_formats_own_number() {
    for sh in shapes() {
        let block = super::super::protocol::pcs_params_at(&sh);
        let endpoint = super::super::protocol::endpoint_pcs_params(&sh);
        assert_eq!(super::tree_depth(&block), sh.log_cols + sh.inv_rate.trailing_zeros() as usize, "{}: the block tree depth", sh.name);
        assert_eq!(super::tree_depth(&endpoint), sh.endpoint_log_n + sh.endpoint_inv_rate.trailing_zeros() as usize, "{}: the endpoint tree depth", sh.name);
    }
    // the masking commitment's own tree, and the wire's count of its entries
    assert_eq!(super::super::wire::MASK_PATH_LEN, crate::zk::MASK_LOG_DOM as usize);
    assert_eq!(super::super::wire::MASK_PATH_LEN, 12);
    // the toy: 2^8 columns at rate 1/8 is a 2,048-leaf tree, 11 deep
    assert_eq!(super::tree_depth(&PcsParams { log_cols: 8, inv_rate: 8, num_col_checks: 256 }), 11);
}

fn toy_receipt() -> (BlockPublic, ExpectedIo, Receipt) {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let output = compute_output(&blk, &input).expect("the fixture computes");
    let spec = IoSpec::new(*blake3::hash(b"private block: T-4 path-length probe").as_bytes(), 0, 0).expect("the approved scales");
    let (expected, owners) = prepare_endpoints(spec, &input, &output).expect("the endpoints commit");
    let (receipt, _) = prove_with_stats(&blk, &input, &expected, owners).expect("the toy proves");
    (blk, expected, receipt)
}

/// Run the lane's CORE verifier on an in-memory receipt, without the frame
/// shape check — the path a hand-built structure takes.
fn verify_core_on(blk: &BlockPublic, expected: &ExpectedIo, r: &Receipt) -> Result<(), String> {
    let sh = Shape::toy();
    let lay = Layout::for_shape(&sh)?;
    let ntt = crate::ntt::NttTables::new(super::super::protocol::ntt_log_at(&sh));
    let mut tr = super::super::protocol::transcript(blk, expected, &lay);
    let mut ph = super::super::timing::Phases::start();
    let view = super::super::protocol::CoreView {
        a_root: r.a_root,
        h_root: r.h_root,
        mask_root: r.mask_root,
        slots: &r.slots,
        mask_open: &r.mask_open,
        a_open: &r.a_open,
        h_open: &r.h_open,
    };
    super::super::protocol::verify_core(&sh, &lay, blk, view, &ntt, &mut tr, &mut ph).map(|_| ())
}

/// One opened column's Merkle path, shortened or lengthened by one entry, on
/// one of the five commitments a toy receipt carries.
fn with_path_length_changed(r: &Receipt, which: usize, longer: bool) -> Receipt {
    let mut a = r.a_open.clone();
    let mut h = r.h_open.clone();
    let mut m = r.mask_open.clone();
    let mut io = r.io_open.clone();
    {
        let p: &mut Vec<crate::merkle::Digest> = match which {
            0 => &mut a.columns[0].3,
            1 => &mut h.columns[3].3,
            2 => &mut m.columns[7].3,
            3 => &mut io[0].columns[0].3,
            _ => &mut io[1].columns[255].3,
        };
        if longer {
            let last = *p.last().expect("a nonempty path");
            p.push(last);
        } else {
            p.pop();
        }
    }
    Receipt { a_root: r.a_root, h_root: r.h_root, mask_root: r.mask_root, slots: r.slots.clone(), mask_open: m, a_open: a, h_open: h, io_open: io }
}

const WHICH: [&str; 5] = ["A", "H", "M", "endpoint 0", "endpoint 1"];

/// **THE T-4 NEGATIVE AT THE CORE VERIFIER**, on a genuine receipt structure
/// that never went through a wire — the three commitments `verify_core`
/// handles, each with an opened column whose path is one entry short and,
/// separately, one entry long.
///
/// **What happened here BEFORE this stage** (recorded because it is the point
/// of the ruling): the refusal came from inside the core verifier as
/// `"A: pcs zk: Merkle path for column <j> fails"`, AFTER the column had been
/// hashed and only because the folded root happened not to match.
/// `pcs::verify_zk` never checks the length; it folds whatever it is handed.
#[test]
fn a_short_or_long_merkle_path_is_refused_by_the_core_verifier_by_name() {
    let (blk, expected, receipt) = toy_receipt();
    verify_core_on(&blk, &expected, &receipt).expect("the honest receipt verifies through the core");
    for which in 0..3 {
        for longer in [false, true] {
            let bad = with_path_length_changed(&receipt, which, longer);
            let e = verify_core_on(&blk, &expected, &bad).expect_err("the core accepted a wrong path length");
            assert!(e.contains("(T-4)"), "{}/{longer}: the core's refusal is not the lane's own: {e}", WHICH[which]);
            assert!(!e.contains("pcs zk"), "{}/{longer}: the core verifier was reached: {e}", WHICH[which]);
        }
    }
    let bad = with_path_length_changed(&receipt, 0, false);
    let e = verify_core_on(&blk, &expected, &bad).expect_err("refused");
    assert_eq!(e, "private block: opened column 0 of the A commitment carries a Merkle path of 10 entries; this commitment's tree is 11 deep (T-4)", "{e}");
}

/// **THE T-4 NEGATIVE THROUGH THE WHOLE BLOCK VERIFIER**, all five
/// commitments including the two external endpoints.
///
/// **What happened here BEFORE this stage**: the refusal came from the frame
/// SHAPE check, `"private block wire: opening shape"` — which says nothing
/// about paths, names no commitment, and does not apply at all to a structure
/// that never went through a wire. The check is now the lane's own and runs
/// before the frame check.
#[test]
fn a_short_or_long_merkle_path_is_refused_by_the_whole_verifier_by_name() {
    let (blk, expected, receipt) = toy_receipt();
    super::super::protocol::verify_inner_at(&Shape::toy(), &blk, &expected, &receipt).expect("the honest receipt verifies");
    for which in 0..5 {
        for longer in [false, true] {
            let bad = with_path_length_changed(&receipt, which, longer);
            let e = super::super::protocol::verify_inner_at(&Shape::toy(), &blk, &expected, &bad).expect_err("a wrong path length was accepted");
            assert!(e.contains("(T-4)"), "{}/{longer}: the refusal is not the lane's own: {e}", WHICH[which]);
            assert!(e.contains("Merkle path of") && e.contains("deep"), "{}/{longer}: {e}", WHICH[which]);
        }
    }
    // the refusal carries public numbers only: the commitment's name, the
    // opening's position in the frame, and the two lengths
    let bad = with_path_length_changed(&receipt, 4, true);
    let e = super::super::protocol::verify_inner_at(&Shape::toy(), &blk, &expected, &bad).expect_err("refused");
    assert_eq!(e, "private block: opened column 255 of the endpoint 1 commitment carries a Merkle path of 12 entries; this commitment's tree is 11 deep (T-4)", "{e}");
}

/// **The wire-level half of T-4**, pinned rather than added: a frame whose
/// byte length is that of a shorter path is refused at DECODE, before
/// anything is read, because `decode` requires the exact counted length and
/// `Reader::column` reads a fixed number of path entries out of the layout
/// (`wire.rs:178-193`). Thirty-two bytes is exactly one path entry.
#[test]
fn a_frame_one_path_entry_short_is_refused_at_decode() {
    let (blk, expected, receipt) = toy_receipt();
    let bytes = receipt.to_bytes(&blk, &expected).expect("the honest frame");
    assert_eq!(bytes.len(), 2_816_472, "the frozen toy receipt length moved");
    verify_bytes(&blk, &expected, &bytes).expect("the honest frame verifies");
    let short = &bytes[..bytes.len() - 32];
    let e = verify_bytes(&blk, &expected, short).expect_err("a frame one path entry short was accepted");
    assert_eq!(e, "private block wire: frame length", "{e}");
    let mut long = bytes.clone();
    long.extend_from_slice(&[0u8; 32]);
    let e = verify_bytes(&blk, &expected, &long).expect_err("a frame one path entry long was accepted");
    assert_eq!(e, "private block wire: frame length", "{e}");
}
