//! **STAGE 33 — the closures the security owner ruled after reading stage
//! 32.** Two of them live here.
//!
//! * **Ruling J-7a (task 1).** Stage 32 DECLARED a 60-byte coincidence inside
//!   the transcript function — `Transcript::new`'s input at the 48-byte
//!   rung-W14 profile against an absorb of `rows` with eight bytes of data —
//!   and separated the pair with an argument whose premise ("a profile string
//!   is ASCII and has no NUL") was stated only in a comment. Here the premise
//!   is CHECKED over the whole registry, and the separation is proved as a
//!   LEMMA over every registered profile length and every absorb layout of
//!   that length, not only the one pair that happened to collide.
//! * **Ruling S-6 (task 2).** `Shape::a_groups`'s first arm is reached by no
//!   registered shape. The family that reaches it becomes a NAMED shape
//!   refusal, so the arm is unreachable after validation rather than merely
//!   unreached, and both halves of that statement are tested.
//!
//! Neither task proves anything: no witness, no receipt and no timing. What
//! they add is a check where stage 32 had a comment, and a refusal where the
//! opening-group structure had a branch nothing tests.

use super::hash_domain;
use super::layout::Dom;
use super::run::{RUN_PROFILE_M125, RUN_PROFILE_RUNG_C6, RUN_PROFILE_RUNG_E32, RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4, RUN_PROFILE_RUNG_P2, RUN_PROFILE_RUNG_W14};
use super::shape::{Shape, LIMBS_ISQRT};

// ---------------------------------------------------------------------------
// shared: the registry, read two ways
// ---------------------------------------------------------------------------

/// the nine shapes this module builds — stage 25's `every_shape`, which the
/// registry guards already require to be the whole block registry
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()]
}

/// the seven RUN profiles
fn every_run_profile() -> Vec<&'static str> {
    vec![RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4, RUN_PROFILE_RUNG_P2, RUN_PROFILE_RUNG_C6, RUN_PROFILE_RUNG_W14, RUN_PROFILE_RUNG_E32, RUN_PROFILE_M125]
}

/// One of this crate's own source files, read at test time (stage 24's and
/// stage 25's reader, so all three stages read the registry the same way).
fn source(name: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(name);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("stage 33: {}: {e}", p.display()))
}

/// every `"hashline-zk-mr1/…"` STRING LITERAL in a source file
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

/// The whole registry as STRINGS, read out of the two source files that hold
/// it, so a profile added to `shape.rs` or `run.rs` is covered here whether or
/// not anyone remembers this file.
fn registry_profiles() -> Vec<String> {
    let mut v = profile_literals(&source("src/private_block/shape.rs"));
    v.extend(profile_literals(&source("src/private_block/run.rs")));
    v.sort();
    v.dedup();
    v
}

// ---------------------------------------------------------------------------
// TASK 1 — ruling J-7a: the separator of stage 32's declared pair, CHECKED
// ---------------------------------------------------------------------------

/// `Transcript::new` (`zkp-core/src/transcript.rs:29-34`) hashes
/// `b"hashline-v1/" ‖ domain`. Twelve bytes of fixed prefix, then the profile.
const CTOR_PREFIX: &[u8] = b"hashline-v1/";

/// `Transcript::absorb` (`:59-68`) hashes
/// `state(32) ‖ le64(|label|) ‖ label ‖ le64(|data|) ‖ data`, so an absorb
/// input costs `48 + |label| + |data|` bytes and its two LENGTH FIELDS sit at
/// fixed offsets: bytes `32..40` and bytes `40+|label| .. 48+|label|`.
const STATE: usize = 32;

/// The byte positions of an absorb input that are FORCED to `0x00` by the two
/// little-endian `u64` length fields — the positions no label content, no data
/// content and no transcript state can move, because both fields' VALUES are
/// fixed by the layout alone.
fn forced_nul_positions(label_len: usize, data_len: usize) -> Vec<usize> {
    let mut out: Vec<usize> = Vec::new();
    for (base, v) in [(STATE, label_len as u64), (STATE + 8 + label_len, data_len as u64)] {
        for (k, b) in v.to_le_bytes().iter().enumerate() {
            if *b == 0 {
                out.push(base + k);
            }
        }
    }
    out
}

/// The positions at which `b"hashline-v1/" ‖ profile` and an absorb input of
/// the SAME total length are forced to differ: a position inside one of the
/// two length fields whose absorb byte is `0x00` and whose constructor byte is
/// a PROFILE byte that is not `0x00`.
///
/// Nothing about the absorb's label content, data content or incoming state
/// enters, which is why one such position settles the whole pair rather than
/// one instance of it.
fn separating_positions(profile: &[u8], label_len: usize, data_len: usize) -> Vec<usize> {
    let n = CTOR_PREFIX.len() + profile.len();
    assert_eq!(48 + label_len + data_len, n, "the layout is not of the constructor input's length");
    forced_nul_positions(label_len, data_len)
        .into_iter()
        .filter(|p| *p >= CTOR_PREFIX.len() && *p < n && profile[*p - CTOR_PREFIX.len()] != 0)
        .collect()
}

/// A printable-ASCII defect, or `None`. `0x20..=0x7E` and nothing else: no
/// NUL, no control byte, no byte above 127 (so no multi-byte UTF-8 either).
fn ascii_defect(s: &str) -> Option<String> {
    for (i, b) in s.as_bytes().iter().enumerate() {
        if !(0x20..=0x7E).contains(b) {
            return Some(format!("byte {i} is 0x{b:02x}"));
        }
    }
    None
}

/// **RULING J-7a, THE PREMISE.** Stage 32's declared pair is separated by "a
/// profile string is ASCII and contains no NUL at any offset". That is a
/// statement about the REGISTRY, and until this test it was a comment.
///
/// Everything the census hashes as a fixed literal is checked, not only the
/// profile strings: the four `derive_key` context literals (they are hash
/// inputs in their own right, and one declared 49-byte pair is separated by
/// their CONTENT), every transcript absorb LABEL the path carries, and the
/// constructor's own twelve-byte prefix. The registry is read BOTH from the
/// shapes and runs this module builds AND out of the two source files, and the
/// two lists must agree, so a profile nobody added here cannot escape.
#[test]
fn every_registered_profile_context_and_label_is_printable_ascii_with_no_nul() {
    // ---- the registry, from the objects and from the source
    let mut built: Vec<String> = every_shape().iter().map(|sh| sh.profile.to_string()).collect();
    built.extend(every_run_profile().iter().map(|p| p.to_string()));
    // NATIVE LANE: the trained-calibration profiles
    built.extend(super::trained_calib_tests::registered_trained_shapes().iter().map(|sh| sh.profile.to_string()));
    built.extend(super::accuracy_profile_tests::registered_shapes().iter().map(|sh|sh.profile.to_string()));
    built.extend(super::trained_calib_tests::registered_trained_runs().iter().map(|(p, _)| p.to_string()));
    // TOKEN I/O R1 LANE: the token-I/O run profile(s)
    built.extend(super::token_io::registered_token_runs().iter().map(|(p, _)| p.to_string()));
    // TOKEN I/O ROUND 12: the classifier run profile(s)
    built.extend(super::token_io::classify::registered_classify_runs().iter().map(|(p, _)| p.to_string()));
    built.extend(super::accuracy_profile_tests::registered_runs().iter().map(|(p,_)|p.to_string()));
    built.sort();
    built.dedup();
    assert_eq!(built, registry_profiles(), "the registry read from the source and the registry built here disagree");
    let n_profiles = built.len();

    // ---- every string that is hashed as a fixed literal on the path
    let mut strings: Vec<(String, String)> = built.iter().map(|p| (format!("profile `{p}`"), p.clone())).collect();
    for (role, ctx) in [
        ("transcript", zkp_core::hashtag::CTX_TRANSCRIPT),
        ("column", zkp_core::hashtag::CTX_COLUMN),
        ("leaf", zkp_core::hashtag::CTX_LEAF),
        ("node", zkp_core::hashtag::CTX_NODE),
    ] {
        strings.push((format!("the {role} key's derive_key context"), ctx.to_string()));
    }
    let mut labels: Vec<String> = Vec::new();
    for sh in every_shape() {
        // both sides of the block/run split, so every label the census knows
        // is covered whatever a shape's own path carries
        for line in [None, Some("a run parameter line")] {
            for u in hash_domain::path_labels(&sh, line) {
                labels.push(u.label.to_string());
            }
        }
    }
    labels.sort();
    labels.dedup();
    let n_labels = labels.len();
    strings.extend(labels.iter().map(|l| (format!("the transcript label `{l}`"), l.clone())));
    strings.push(("the transcript constructor's fixed prefix".to_string(), String::from_utf8(CTOR_PREFIX.to_vec()).expect("ASCII")));
    strings.push(("the transcript squeeze literal".to_string(), "squeeze".to_string()));

    for (what, s) in &strings {
        assert!(!s.is_empty(), "{what}: the literal is empty");
        if let Some(d) = ascii_defect(s) {
            panic!("{what} is not printable ASCII: {d} (`{s}`)");
        }
        assert!(!s.as_bytes().contains(&0u8), "{what} contains a NUL byte");
    }
    eprintln!("S33 J-7a: {} literals checked printable ASCII with no NUL — {n_profiles} registered profiles, 4 derive_key contexts, {n_labels} transcript labels, 2 fixed transcript literals", strings.len());
}

/// **THE CONTROL THAT MAKES THE PREMISE TEST BITE.** A premise that holds
/// everywhere cannot be reproduced as a failing test on the real registry, so
/// the check is run against deliberately BAD strings instead: each is what a
/// future profile would have to look like for stage 32's separator to fail,
/// and each is rejected.
#[test]
fn the_ascii_premise_check_rejects_a_profile_with_a_nul_or_a_non_ascii_byte() {
    let bad: Vec<(&str, String)> = vec![
        ("a NUL inside the profile", "hashline-zk-mr1/private-block-\u{0}-dev/1".to_string()),
        ("a NUL at the very end", "hashline-zk-mr1/private-block-dev/1\u{0}".to_string()),
        ("a non-ASCII byte (two UTF-8 bytes)", "hashline-zk-mr1/private-block-café-dev/1".to_string()),
        ("a control byte below the printable range", "hashline-zk-mr1/private-block\t-dev/1".to_string()),
        ("DEL, the byte just above the printable range", "hashline-zk-mr1/private-block\u{7f}-dev/1".to_string()),
    ];
    for (what, s) in &bad {
        assert!(ascii_defect(s).is_some(), "the ASCII check accepted a profile with {what}");
    }
    // and it accepts every real one, so it is not rejecting everything
    for sh in every_shape() {
        assert!(ascii_defect(sh.profile).is_none(), "{}: a registered profile was rejected", sh.name);
    }
    eprintln!("S33 J-7a control: {} deliberately bad profile strings rejected by the ASCII check, all 8 registered ones accepted", bad.len());
}

/// **RULING J-7a, THE LEMMA.** Stage 32 declared ONE pair at ONE profile
/// length. The argument it gave is general, and a general argument belongs in
/// a test that will still be there when the next profile is registered:
///
/// > for every registered profile, the input `b"hashline-v1/" ‖ profile` that
/// > `Transcript::new` hashes can equal NO absorb input of the same total
/// > length, whatever the absorb's label, data or incoming state.
///
/// The proof is by position, and the positions are COMPUTED here rather than
/// taken from stage 32's "offset 32": for each total length `n` the test
/// enumerates EVERY absorb layout of that length — every `(|label|, |data|)`
/// with `48 + |label| + |data| = n`, which is every layout the absorb function
/// can produce, whether or not any label of that length exists — and requires
/// at least one byte position inside one of the two `le64` LENGTH FIELDS that
/// is forced to `0x00` while the constructor carries a profile byte there.
///
/// **A layout with no such position would be a FINDING**, because stage 32's
/// declared row would then rest on a coincidence rather than on a separation.
/// The test reports the worst case it finds; the ledger records it.
#[test]
fn no_transcript_constructor_input_can_equal_an_absorb_input_of_the_same_length() {
    let profiles = registry_profiles();
    assert!(!profiles.is_empty(), "the registry is empty");
    let mut worst = usize::MAX;
    let mut worst_at = String::new();
    let mut layouts_total = 0usize;
    for p in &profiles {
        let bytes = p.as_bytes();
        assert!(ascii_defect(p).is_none(), "`{p}` is not ASCII — the lemma's premise is the other test's");
        let n = CTOR_PREFIX.len() + bytes.len();
        if n < 48 {
            // no absorb input is this short, so there is nothing to separate
            eprintln!("    {n:>4} B  `{p}` — below the shortest absorb input (48 B): no layout of this length exists");
            continue;
        }
        let mut here = usize::MAX;
        let mut first = 0usize;
        for label_len in 0..=(n - 48) {
            let data_len = n - 48 - label_len;
            let sep = separating_positions(bytes, label_len, data_len);
            assert!(
                !sep.is_empty(),
                "FINDING: at `{p}` ({n} B) the absorb layout |label| = {label_len}, |data| = {data_len} has NO byte position forced to 0x00 inside a length field where the constructor carries a profile byte — stage 32's declared pair would rest on a coincidence"
            );
            layouts_total += 1;
            if sep.len() < here {
                here = sep.len();
                first = sep[0];
            }
        }
        eprintln!("    {n:>4} B  `{p}` — {} layouts, at least {here} separating positions each, the first at offset {first}", n - 47);
        if here < worst {
            worst = here;
            worst_at = p.clone();
        }
    }
    eprintln!("S33 J-7a lemma: {} registered profiles, {layouts_total} absorb layouts, EVERY one separated; the thinnest is {worst} forced-NUL positions at `{worst_at}`", profiles.len());
    assert!(worst >= 1, "some profile length has a layout with no separating position");
}

/// **STAGE 32's OWN PAIR, re-derived and made concrete.** The general lemma
/// above covers it, but the declared row names a length, a layout and an
/// offset, and those are worth pinning by themselves: if the rung-W14 profile
/// string is ever re-spelled at another length the declared row stops
/// describing anything and this test says so.
///
/// The pair is also demonstrated on REAL BYTES: both inputs are built exactly
/// as `Transcript::new` and `Transcript::absorb` build them — with an absorb
/// state chosen adversarially, as the first 32 bytes of the constructor input
/// itself, which is the best an adversary can do at the positions the argument
/// does not use — and they differ at every position the argument names.
#[test]
fn the_declared_sixty_byte_pair_is_separated_at_the_positions_the_record_names() {
    let w14 = Shape::rung_w14();
    assert_eq!(w14.profile.len(), 48, "the rung-W14 profile string is no longer 48 bytes, so stage 32's declared row describes nothing");
    let ctor: Vec<u8> = CTOR_PREFIX.iter().chain(w14.profile.as_bytes()).copied().collect();
    assert_eq!(ctor.len(), 60, "the constructor input is not 60 bytes");
    // the declared partner: `rows`, eight bytes of data (`protocol.rs:130`)
    let (label, data_len) = (b"rows".to_vec(), 8usize);
    assert_eq!(48 + label.len() + data_len, ctor.len(), "the declared partner is not of the constructor input's length");

    let sep = separating_positions(w14.profile.as_bytes(), label.len(), data_len);
    // the first length field is `le64(4)`: one byte of value and SEVEN NULs,
    // all seven of them over profile bytes (the profile begins at offset 12)
    let in_first: Vec<usize> = sep.iter().copied().filter(|p| (32..40).contains(p)).collect();
    assert_eq!(in_first, vec![33, 34, 35, 36, 37, 38, 39], "the first length field's forced NULs are not where the record says");
    // and the second, `le64(8)` at offset 44, gives seven more
    let in_second: Vec<usize> = sep.iter().copied().filter(|p| (44..52).contains(p)).collect();
    assert_eq!(in_second, vec![45, 46, 47, 48, 49, 50, 51], "the second length field's forced NULs are not where the record says");
    assert_eq!(sep.len(), 14, "the declared pair's separating positions moved");

    // ---- the same thing on real bytes, with the state chosen adversarially
    let state: Vec<u8> = ctor[..32].to_vec();
    let mut absorb: Vec<u8> = Vec::new();
    absorb.extend_from_slice(&state);
    absorb.extend_from_slice(&(label.len() as u64).to_le_bytes());
    absorb.extend_from_slice(&label);
    absorb.extend_from_slice(&(data_len as u64).to_le_bytes());
    absorb.extend_from_slice(&[0xffu8; 8]);
    assert_eq!(absorb.len(), ctor.len(), "the two inputs are not the same length after all");
    assert_ne!(absorb, ctor, "the declared pair's two inputs are EQUAL");
    for p in &sep {
        assert_eq!(absorb[*p], 0u8, "offset {p} is not a forced NUL of the absorb input");
        assert_ne!(ctor[*p], 0u8, "offset {p} of the constructor input is a NUL");
        assert_ne!(absorb[*p], ctor[*p], "offset {p} does not separate the pair");
    }
    eprintln!(
        "S33 J-7a: the declared 60-byte pair is separated at {} positions — {:?} in le64(|label|) and {:?} in le64(|data|); the record's 'six NUL bytes' is an undercount (S33-F1)",
        sep.len(),
        in_first,
        in_second
    );
}

/// **THE LEMMA'S OWN CONTROL.** The separation is not a property of the
/// transcript's framing alone — it needs the profile bytes at those positions
/// to be non-NUL, which is exactly what the ASCII premise gives. A test-local
/// profile of the SAME length whose bytes at the forced-NUL positions are
/// themselves NUL has no separating position at the declared layout: the
/// lemma reports zero, so it is known to bite rather than to be vacuous.
#[test]
fn the_separation_lemma_collapses_on_a_deliberately_bad_profile() {
    // 48 bytes, of which offsets 20..28 and 32..40 (the profile's own indices
    // under the two length fields at the declared layout) are NUL
    let mut bad = vec![b'x'; 48];
    for i in 20..28 {
        bad[i] = 0;
    }
    for i in 32..40 {
        bad[i] = 0;
    }
    assert_eq!(separating_positions(&bad, 4, 8), Vec::<usize>::new(), "the bad profile still has a separating position");
    // one printable byte back in each field is enough to separate it again
    bad[21] = b'a';
    assert_eq!(separating_positions(&bad, 4, 8), vec![33], "one restored profile byte does not restore the separation");
    // and the real profile of that length has fourteen
    assert_eq!(separating_positions(Shape::rung_w14().profile.as_bytes(), 4, 8).len(), 14);
    eprintln!("S33 J-7a control: a 48-byte profile whose bytes under the two length fields are NUL has NO separating position at the declared layout; one printable byte restores one");
}

// ---------------------------------------------------------------------------
// TASK 2 — ruling S-6: the dead arm of `Shape::a_groups`, as a named refusal
// ---------------------------------------------------------------------------

/// **RULING S-6, the positive half.** No registered shape has a padded token
/// count at or above the row width, so no registered shape reaches
/// `Shape::a_groups`'s first arm. Stages 31 and 32 recorded that as an
/// observation; here it is a test, at every shape, with the margin printed.
#[test]
fn no_registered_shape_reaches_the_first_arm_of_a_groups() {
    for sh in every_shape() {
        assert!(
            sh.natural_log(Dom::T) < sh.log_cols,
            "{}: Dom::T's natural log {} reaches the row width 2^{} — the first arm of a_groups is live at a registered shape",
            sh.name,
            sh.natural_log(Dom::T),
            sh.log_cols
        );
        eprintln!("S33 S-6 [{}]: Dom::T at 2^{} against a row width of 2^{} — {} bits of margin", sh.name, sh.natural_log(Dom::T), sh.log_cols, sh.log_cols - sh.natural_log(Dom::T));
    }
}

/// **RULING S-6, the refusal.** A shape whose PADDED token count reaches the
/// row width is refused at construction, by name.
///
/// **It was constructible, and this is the shape that did it** (recorded
/// failing-first in `results/zk60_block125m_lane/w33-s6-failing-first.log`,
/// exit 101): the toy's axes with 256 tokens instead of 32, at the toy's own
/// row width of `2^8`. Every other construction check is satisfied — the three
/// bilinear domains sit far above the row width so ruling F-2 does not fire,
/// `Dom::Tab` is exactly at it so ruling S-1 does not, the head dimension is
/// five bits below it so ruling S-3 does not, and its longest mask is far
/// inside ruling C-4's budget — and before this stage `Shape::new` returned it
/// happily, with `a_groups()` reading **28** out of the FIRST arm (the toy's
/// own count is 35, out of the second).
#[test]
fn a_shape_whose_padded_token_count_reaches_the_row_width_is_refused_by_name() {
    // the toy's axes at 256 tokens: `t_pad = 2^8`, the row width
    let r = Shape::new("S-33 probe: the toy at a token count that reaches the row width", "hashline-zk-mr1/private-block-s33-probe/1", 256, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None);
    let e = match r {
        Ok(sh) => panic!(
            "a shape whose padded token count reaches the row width was ACCEPTED: t_pad = {}, Dom::T at 2^{} against a row width of 2^{}, a_groups() = {} out of the FIRST arm",
            sh.t_pad,
            sh.natural_log(Dom::T),
            sh.log_cols,
            sh.a_groups()
        ),
        Err(e) => e,
    };
    assert!(e.contains("ruling S-6"), "the refusal does not name the ruling: {e}");
    assert!(e.contains("token count"), "the refusal does not name the axis: {e}");
    assert!(e.contains("a_groups"), "the refusal does not say which branch it is about: {e}");
    // THE CONTROL: the same axes at half the tokens construct, and the shape
    // that results takes the second arm — so the refusal reacts to the token
    // count alone and the boundary is where it is said to be
    let ok = Shape::new("S-33 probe control: half the tokens", "hashline-zk-mr1/private-block-s33-probe/1", 128, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None)
        .expect("the control at half the tokens is well formed");
    assert!(ok.natural_log(Dom::T) < ok.log_cols, "the control is in the refused family after all");
    // the refusal is about the PADDED count, so one token above the control's
    // power of two is already refused
    let e2 = Shape::new("S-33 probe: one token above the control", "hashline-zk-mr1/private-block-s33-probe/1", 129, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None)
        .expect_err("129 tokens pad to 256 and must be refused");
    assert!(e2.contains("ruling S-6"), "the padded count is not what the refusal reads: {e2}");
    // **WHERE THE REFUSAL SITS IN THE ORDER, and the one test it moved.**
    // Stage 24's mask-budget probe (2^20 − 1 tokens at a row width of 2^14)
    // was in this family, its CONTROL first of all, so stage 33 moved that
    // probe's row width to 2^21 and left its `Dom::S` alone. The geometry it
    // had until today is refused here, by ruling S-6 and not by ruling C-4,
    // which is the order: S-6 is checked before the mask budget.
    let old = Shape::new("S-33: stage 24's mask probe as it used to be", "hashline-zk-mr1/private-block-s33-probe/1", (1 << 20) - 1, 16_384, 16_384, 2_048, 8, 1, 14, 4, 9, 37, None, None, None, None)
        .expect_err("stage 24's old mask-budget geometry is in the refused family");
    assert!(old.contains("ruling S-6"), "the old mask-budget geometry is refused by something else: {old}");
    eprintln!("S33 S-6 refusal: 256 tokens at a row width of 2^8 is refused by name, 129 too (it pads to 256), 128 constructs; stage 24's old mask probe is refused by S-6 before C-4");
}

/// **WHERE THE BOUNDARY IS, and which refusal owns each side.** A sweep of the
/// token count at the toy's other axes: below the row width the shape
/// constructs and `a_groups` takes its second arm; at and above it ruling S-6
/// owns the refusal and no other refusal reaches those shapes first.
#[test]
fn the_s6_refusal_is_exactly_the_padded_token_counts_at_or_above_the_row_width() {
    // 32 tokens is the toy's own count and the smallest at which none of the
    // OLDER refusals fires at these axes (below it `Dom::Kv = 8 · t_pad` drops
    // under the row width and ruling F-2 owns the shape), so the sweep is a
    // statement about ruling S-6 alone.
    let toy = Shape::toy();
    for tokens in [32usize, 64, 128, 129, 192, 256, 257, 512, 4096] {
        let r = Shape::new("S-33 sweep", "hashline-zk-mr1/private-block-s33-sweep/1", tokens, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None);
        let padded_reaches = tokens.next_power_of_two() >= 1usize << 8;
        match (padded_reaches, r) {
            (true, Ok(sh)) => panic!("{tokens} tokens (t_pad {}) was accepted at a row width of 2^8", sh.t_pad),
            (true, Err(e)) => assert!(e.contains("ruling S-6"), "{tokens} tokens is refused by something else: {e}"),
            (false, Ok(sh)) => {
                assert!(sh.natural_log(Dom::T) < sh.log_cols);
                // the live arm's own count, re-derived here: the accepted
                // shape's `A` group total moves with `SC_TZC`'s offsets and
                // with nothing else, so it is the toy's plus the difference
                let offsets = |t_pad: usize| -> usize {
                    let mut o: Vec<usize> = (0..3 * LIMBS_ISQRT).map(|k| (k * t_pad) % 256).collect();
                    o.push(0);
                    o.sort_unstable();
                    o.dedup();
                    o.len()
                };
                assert_eq!(
                    sh.a_groups() as i64 - toy.a_groups() as i64,
                    offsets(sh.t_pad) as i64 - offsets(toy.t_pad) as i64,
                    "{tokens} tokens: the A opening's group count does not follow SC_TZC's offsets"
                );
                eprintln!("    {tokens:>5} tokens (t_pad {}): accepted, {} A opening groups, SC_TZC at {}", sh.t_pad, sh.a_groups(), offsets(sh.t_pad));
            }
            (false, Err(e)) => panic!("{tokens} tokens was refused below the row width: {e}"),
        }
    }
    assert_eq!(toy.a_groups(), 35, "the toy's own A opening group count moved");
    eprintln!("S33 S-6 sweep: the refusal is exactly `t_pad >= 2^log_cols` at the toy's axes, and every accepted shape's group count comes from the live arm");
}

/// **WHAT THE REFUSED ARM WOULD HAVE COMPUTED, and why keeping it costs
/// nothing.** The first arm returns 1 for `SC_TZC`. So does the second arm on
/// exactly those shapes: `t_pad` is a power of two (T-2), so `t_pad >= 2^log_cols`
/// makes every offset `k · t_pad mod 2^log_cols` zero and the deduplicated set
/// `{0}`. The arm is therefore a SHORTCUT and not a special case — it is dead
/// after this stage's refusal, and it was never a second behaviour even before
/// it. That is the whole reason the arm may stay in place, documented, instead
/// of being turned into a panic on a path the prover reaches.
#[test]
fn the_refused_arm_and_the_live_arm_agree_wherever_both_are_defined() {
    for log_cols in 2..=16usize {
        let n = 1usize << log_cols;
        for e in log_cols..=(log_cols + 4) {
            let t_pad = 1usize << e;
            let mut offs: Vec<usize> = (0..3 * LIMBS_ISQRT).map(|k| (k * t_pad) % n).collect();
            offs.push(0);
            offs.sort_unstable();
            offs.dedup();
            assert_eq!(offs.len(), 1, "at t_pad = 2^{e} and a row width of 2^{log_cols} the live arm gives {} groups, not the constant arm's 1", offs.len());
        }
    }
    // and the constant `3 * LIMBS_ISQRT` the arm folds over is the one the
    // shape uses: the toy's own second-arm count is stable
    assert_eq!(Shape::toy().a_groups(), 35);
    eprintln!("S33 S-6: the two arms of a_groups coincide on every (row width, padded token count) pair the refused family contains — the first arm is a shortcut, not a second behaviour");
}
