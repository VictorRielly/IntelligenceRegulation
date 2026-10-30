//! **STAGE 25 — THE LANE'S SHARE OF THE QUERY-CLASS WORK LIST.** The items
//! of `docs/zkmatrix-poc/ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §8 whose
//! "whose file" column says **the lane**, as the security owner's
//! disposition (`…_DISPOSITION.md`, rulings J-3, J-5, J-6, J-7) leaves them:
//!
//! * **W-2, generalised** — every transcript-class and statement-class hash
//!   input KIND of every registered profile, printed with its exact length;
//!   per hash FUNCTION no two different kinds share a length unless the
//!   memo's table records the pair and names the fixed literal that separates
//!   them; and every pair within ONE BYTE listed, because "one byte away" is
//!   a class here and not a curiosity (ruling H-8's margin is one member).
//! * **W-3** — the refusal replay re-issues exactly the challenge points the
//!   live chain draws next, and leaves the live transcript's observable state
//!   untouched, on real openings at `Shape::rung_k4` with a generic dense
//!   witness.
//! * **W-4** — the LEGACY length guard gains the statement digests' input
//!   lengths and the seed derivation's `22 + |domain|`, so a 16-row
//!   commitment (the frozen seam's 128-byte spec digest) is refused by name.
//! * **W-6, as changed by J-7** — the per-slot `pb-term` absorb lengths at
//!   every registered shape, printed and RECORDED; slot 19's six terminals
//!   and their 151 bytes, which equal the internal boundary's spec digest
//!   input ACROSS profiles and are therefore never live together.
//! * **W-7** — stage 24's twelve-key test still covers every tagged profile.
//! * **W-8, assertions 5 and 7 only** — the two of the memo's §3.1 that need
//!   no consumption accessor in `zkp-core/src/rng.rs`. Assertions 1–4 and 6
//!   are blocked on the integrator's test-only accessor, asked for on
//!   2026-09-21 03:25.
//! * **W-11** — the source scan that covers absorb LABELS, extended to hash
//!   CALL SITES.
//!
//! **Nothing here is a privacy or a soundness acceptance**, and no accepted
//! profile moves a byte: the one production change of this stage is a guard
//! set that grows, on legacy-rule profiles only, over geometries no profile
//! has.
//!
//! **Every number taken from the memo is re-derived here from the code.**
//! Where the code and the memo differ the code wins and the difference is a
//! finding, reported in the ledger's stage 25 section.

use super::hash_domain::{self, RunFacts};
use super::layout::{Layout, M_ROWS, N_SLOTS, SC_IO_IN, SC_TAB};
use super::run::{RunShape, RunStatement, RUN_PROFILE_M125, RUN_PROFILE_RUNG_C6, RUN_PROFILE_RUNG_E32, RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4, RUN_PROFILE_RUNG_P2, RUN_PROFILE_RUNG_W14};
use super::shape::Shape;
use super::{BlockPublic, ExpectedIo, IoSpec};
use crate::field::{Fp, Fp2};
use crate::merkle::Digest;
use crate::transcript::Transcript;

// ---------------------------------------------------------------------------
// shared helpers
// ---------------------------------------------------------------------------

/// One of this crate's own source files, read at test time, exactly as
/// `s24_tests::source` resolves it: the crate manifest's directory, so a test
/// that reads source cannot read another tree's copy.
fn source(name: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(name);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("stage 25: {}: {e}", p.display()))
}

/// Every `"hashline-zk-mr1/…"` STRING LITERAL in a source file — stage 24's
/// registry reader, reused so that both stages read the registry the same way.
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

/// the five shapes this module builds
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()]
}

/// The three RUN profiles and the `L` each is registered at: the two
/// development runs this lane proves at three blocks, and the twelve-block
/// 125M run stage 13 prepared.
fn every_run() -> Vec<(&'static str, Shape, usize)> {
    vec![
        (RUN_PROFILE_RUNG_G, Shape::rung_g(), 3),
        (RUN_PROFILE_RUNG_K4, Shape::rung_k4(), 3),
        (RUN_PROFILE_RUNG_P2, Shape::rung_p2(), 3),
        (RUN_PROFILE_RUNG_C6, Shape::rung_c6(), 3),
        (RUN_PROFILE_RUNG_W14, Shape::rung_w14(), 3),
        (RUN_PROFILE_RUNG_E32, Shape::rung_e32(), 3),
        (RUN_PROFILE_M125, Shape::m125(), 12),
    ]
}

fn s25_context() -> Digest {
    *blake3::hash(b"stage 25: the query-class work list's own context").as_bytes()
}

/// A REAL `RunStatement` at this shape and `L`, built with no commitment:
/// `ExpectedIo::from_roots` takes the two external roots as given (they are
/// public words of the statement and this test reads only LENGTHS), so a
/// twelve-block 125M run statement costs its twelve public digests and
/// nothing else. Every string this test measures — the run's parameter line,
/// its stage lines, its layout description — is the one `RunStatement` itself
/// hashes.
fn run_statement(sh: &Shape, profile: &str, l: usize) -> RunStatement {
    let rs = if profile == RUN_PROFILE_M125 {
        RunShape::m125(l).expect("the 125M run shape")
    } else if profile == RUN_PROFILE_RUNG_K4 {
        RunShape::rung_k4(l).expect("the rung-K4 run shape")
    } else if profile == RUN_PROFILE_RUNG_P2 {
        RunShape::rung_p2(l).expect("the rung-P2 run shape")
    } else if profile == RUN_PROFILE_RUNG_C6 {
        RunShape::rung_c6(l).expect("the rung-C6 run shape")
    } else if profile == RUN_PROFILE_RUNG_W14 {
        RunShape::rung_w14(l).expect("the rung-W14 run shape")
    } else if profile == RUN_PROFILE_RUNG_E32 {
        RunShape::rung_e32(l).expect("the rung-E32 run shape")
    } else {
        RunShape::rung_g(l).expect("the rung-G run shape")
    };
    let spec = IoSpec::new_shaped(sh, s25_context(), 0, 0).expect("the run's endpoint spec");
    let expected = ExpectedIo::from_roots(spec, [1u8; 32], [2u8; 32]);
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let one = BlockPublic::new(public, ff);
    let blocks: Vec<BlockPublic> = (0..l).map(|_| one.clone()).collect();
    RunStatement::new(rs, s25_context(), expected, &blocks, &vec![(0, 0); l]).expect("the run statement")
}

// ---------------------------------------------------------------------------
// W-2 — every hash input kind of every registered profile, with its length
// ---------------------------------------------------------------------------

/// One hash input kind on one profile's path.
#[derive(Clone, Debug)]
struct Kind {
    /// plain words, and the only thing a coincidence is declared against
    what: String,
    /// which BLAKE3 FUNCTION hashes it — the same mode AND the same key.
    /// `F_U` unkeyed, `F_T` the transcript key, `F_C` the column key, `F_L`
    /// the leaf key, `F_N` the node key, `R1` the generator's seed derivation
    /// (keyed under 32 raw `/dev/urandom` bytes, convention V-2), `K` the
    /// `derive_key` mode that makes the four tag keys.
    func: &'static str,
    len: usize,
}

/// Which profiles absorb a label: a BLOCK's own header words, a RUN's own
/// header words, or both. **The test asserts this table covers exactly the
/// labels `hash_domain::path_labels` carries**, so a new label on the path
/// cannot be measured without someone deciding which side it is on.
///
/// The two asymmetries are real and are re-derived from the code, not
/// assumed: a run's header (`run.rs`'s `RunStatement::transcript`) absorbs
/// `run-shape` and its own `parameters` line, and each of its stages absorbs
/// `pb-run-stage`, `pb-run-block` and — when it commits one — the `B` root;
/// a BLOCK inside a run never absorbs its own `parameters` line, because
/// `prove_core` is handed the run's transcript and `protocol::transcript` is
/// not called (`run.rs:510-530`).
const LABEL_SCOPE: [(&str, &str); 22] = [
    ("run-shape", "run"),
    ("expected-IO", "both"),
    ("public-statement", "both"),
    ("parameters", "both"),
    ("calibration", "both"),
    ("schedule", "both"),
    ("A", "both"),
    ("H", "both"),
    ("B", "run"),
    ("M", "both"),
    ("rows", "both"),
    ("log-cols", "both"),
    ("pb-run-stage", "run"),
    ("pb-run-block", "run"),
    ("pb-slot", "both"),
    ("pb-scalar", "both"),
    ("sc-round", "both"),
    ("mask-q", "both"),
    ("mask-prox", "both"),
    ("pcs-vec", "both"),
    ("pcs-prox", "both"),
    ("pb-term", "both"),
];

/// **D2, the block's public/weights digest, by arithmetic**
/// (`private_block.rs:519-524` and the two `absorb_into` bodies at `:400` and
/// `:480`). `BlockPublic::digest` hashes a 31-byte literal, then five
/// attention tensors and four feed-forward tensors each framed by a
/// little-endian `u64` length and written ONE BYTE per `i8` entry, then three
/// attention tables and the activation table framed the same way with eight
/// bytes per `i64` and two per `i16`.
///
/// It is arithmetic because the 125M weights are about 9 MB and no guard can
/// build them; `the_block_public_digest_input_length_formula_is_the_code_s`
/// checks it BYTE FOR BYTE against two real statements.
fn block_public_digest_input_len(sh: &Shape) -> usize {
    let (d, f, kv, half) = (sh.d_pad, sh.f_pad, sh.kv_heads * sh.head_dim, sh.head_dim / 2);
    let framed_i8 = |n: usize| 8 + n;
    let framed_i64 = |n: usize| 8 + 8 * n;
    31 + framed_i8(sh.q_pad() * d)            // wq
        + framed_i8(kv * d)          // wk
        + framed_i8(kv * d)          // wv
        + framed_i8(d * sh.q_pad())           // wo
        + framed_i8(d)               // gamma_a
        + framed_i64(sh.tokens * half) // rope_cos
        + framed_i64(sh.tokens * half) // rope_sin
        + framed_i64(256)            // exp
        + framed_i8(d)               // gamma_m
        + framed_i8(d * f)           // wg_t
        + framed_i8(d * f)           // wu_t
        + framed_i8(f * d)           // wd_t
        + 8 + 2 * 256 // the activation table, [i16; 256]
}

fn block_public_digest_input_lengths(sh:&Shape)->Vec<usize> {
    let base=block_public_digest_input_len(sh);
    if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {return vec![base]}
    let geo=super::accuracy_public::Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    let registry=sh.accuracy_registry();let stack=sh.accuracy_stack();
    (1..=4).map(|groups| {
        // Independent transcription of the framing, not the production
        // helper's expression. Its inputs are all constructor-bounded.
        let prefix=19+4+registry.name().len()+4+stack.export_name().unwrap().len();
        let axes=7*8+2*(sh.q_width()+2*sh.kv_heads*sh.head_dim+2*sh.width+2*sh.hidden);
        let context=32+36+8;
        let members=8+groups*8;let ids=8+sh.hidden*8;let tables=groups*(8+8192);
        let encoded=prefix+context+axes+members+ids+tables;
        assert_eq!(encoded,super::accuracy_public::encoded_len(geo,registry,stack,groups).unwrap());
        base+12+8+encoded
    }).collect()
}

/// **D3 / D5, a schedule digest's input**: the domain literal, then every
/// line framed by a little-endian `u64` length (`layout.rs:1288-1296`,
/// `run.rs:285-299`).
fn schedule_digest_input_len(literal: usize, lines: &[String]) -> usize {
    literal + lines.iter().map(|l| 8 + l.len()).sum::<usize>()
}

/// Every hash input kind on one profile's path, with its length and the
/// function that hashes it. `run` is `Some` for a RUN profile.
fn kinds_of(sh: &Shape, run: Option<(&str, usize, &RunStatement)>) -> Vec<Kind> {
    let legacy = sh.hashes_under_the_legacy_rule();
    let (transcript_f, column_f, leaf_f, node_f) = if legacy { ("F_U", "F_U", "F_U", "F_U") } else { ("F_T", "F_C", "F_L", "F_N") };
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let mut out: Vec<Kind> = Vec::new();
    let mut push = |what: String, func: &'static str, len: usize| out.push(Kind { what, func, len });

    // (1) THE TRANSCRIPT CLASS.
    let domain = match run {
        Some((p, _, _)) => p,
        None => sh.profile,
    };
    push(format!("the transcript constructor at `{domain}`"), transcript_f, 12 + domain.len());
    push("a transcript squeeze".to_string(), transcript_f, 47);
    // A run's own public words, from the statement's own capture header —
    // the same strings `RunStatement::transcript` absorbs and
    // `schedule_digest` hashes, never a second formatting of them.
    let header = run.map(|(_, _, st)| st.capture_header().expect("the run's capture header"));
    let run_line = header.as_ref().map(|h| h.parameter_line.clone());
    let entries = hash_domain::path_labels(sh, run_line.as_deref());
    let scope: std::collections::BTreeMap<&str, &str> = LABEL_SCOPE.iter().copied().collect();
    let mut covered: Vec<&str> = Vec::new();
    for u in &entries {
        let s = *scope.get(u.label).unwrap_or_else(|| panic!("the label `{}` is on the path and LABEL_SCOPE does not carry it", u.label));
        covered.push(u.label);
        if s == "run" && run.is_none() {
            continue;
        }
        for d in &u.data {
            // a run absorbs its OWN parameter line and never the block's
            if u.label == "parameters" && run.is_some() && *d != run_line.as_ref().expect("a run line").len() {
                continue;
            }
            if u.label == "parameters" && run.is_none() && run_line.is_some() {
                continue;
            }
            push(format!("the transcript absorb of `{}` with {d} bytes of data", u.label), transcript_f, 48 + u.label.len() + d);
        }
    }
    covered.sort_unstable();
    covered.dedup();
    let mut declared: Vec<&str> = LABEL_SCOPE.iter().map(|(l, _)| *l).collect();
    declared.sort_unstable();
    assert_eq!(covered, declared, "{}: LABEL_SCOPE and the label table of hash_domain.rs disagree", sh.name);

    // (2) THE GENERATOR. The refill is unkeyed at every rule; the seed
    // derivation is keyed under 32 raw `/dev/urandom` bytes.
    push("the generator's refill block".to_string(), "F_U", 40);
    // **STAGE 26.** Every seed derivation's length is taken from the DOMAIN
    // BUILDER `hash_domain` now owns, so this table cannot drift from the
    // bytes the call sites pass. At the two FROZEN profiles the builder
    // returns the bare profile string and the numbers are unchanged.
    match run {
        None => push(format!("the generator's seed derivation at `{}` (protocol.rs)", sh.profile), "R1", hash_domain::single_block_seed_input_len(sh)),
        Some((p, _, _)) => push(format!("the generator's seed derivation at `{p}` (run.rs)"), "R1", hash_domain::run_seed_input_len(p)),
    }
    if sh.endpoint_general {
        push(
            "the generator's seed derivation at the generalised endpoint, either role (endpoint_g.rs)".to_string(),
            "R1",
            hash_domain::endpoint_seed_input_len(),
        );
    } else {
        push("the generator's seed derivation at the frozen seam (private_seam.rs:196)".to_string(), "R1", 22 + 28);
    }

    // (3) THE STATEMENT CLASS — unkeyed at every rule.
    push("the calibration identity digest (D1)".to_string(), "F_U", 30);
    for (index,len) in block_public_digest_input_lengths(sh).into_iter().enumerate() {
        let label=if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {"the block's public/weights digest (D2)".to_string()}
            else {format!("the block's public/weights digest (D2, R13 groups={})",index+1)};
        push(label,"F_U",len);
    }
    push("the block's schedule digest (D3)".to_string(), "F_U", schedule_digest_input_len(33, &lay.describe()));
    if sh.endpoint_general {
        push("the generalised endpoint's spec digest (D6)".to_string(), "F_U", 142);
    } else {
        push("the frozen seam's spec digest (D8)".to_string(), "F_U", 128);
    }
    if let Some((_, l, _)) = run {
        let h = header.as_ref().expect("a run has a header");
        // `RunStatement::schedule_digest` (run.rs:294-305) frames the run's
        // parameter line, then the layout's description, then one stage line
        // per block, under a 31-byte literal.
        let mut lines = vec![h.parameter_line.clone()];
        lines.extend(h.layout_description.iter().cloned());
        lines.extend(h.stage_lines.iter().cloned());
        push(format!("the run's public statement digest over {l} blocks (D4)"), "F_U", 29 + 32 * l);
        push("the run's schedule digest (D5)".to_string(), "F_U", schedule_digest_input_len(31, &lines));
        if l > 1 {
            push("an internal boundary's spec digest (D7)".to_string(), "F_U", 151);
        }
    }

    // (4) THE COMMITMENTS' COLUMN DIGESTS, and the two 64-byte tree hashes.
    push("the A commitment's column digest".to_string(), column_f, 8 * lay.a_rows);
    push("the H commitment's column digest".to_string(), column_f, 8 * lay.h_rows);
    push("the M commitment's column digest".to_string(), column_f, 8 * M_ROWS);
    push("an external endpoint's column digest".to_string(), column_f, 8 * sh.endpoint_rows);
    if let Some((_, l, st)) = run {
        if l > 1 {
            push("an internal boundary's column digest".to_string(), column_f, 8 * st.boundary_spec(0).expect("the run's first boundary").commitment_rows());
        }
    }
    push("a salted Merkle leaf".to_string(), leaf_f, 64);
    push("a Merkle inner node".to_string(), node_f, 64);

    // (5) THE TAG KEY DERIVATION, at a tagged profile only: BLAKE3's third
    // mode, one call per role, over the profile string under a context.
    if !legacy {
        for (role, ctx) in [
            ("transcript", zkp_core::hashtag::CTX_TRANSCRIPT),
            ("column", zkp_core::hashtag::CTX_COLUMN),
            ("leaf", zkp_core::hashtag::CTX_LEAF),
            ("node", zkp_core::hashtag::CTX_NODE),
        ] {
            push(format!("the {role} key's derive_key context"), "K", ctx.len());
        }
    }
    out
}

/// **W-2, GENERALISED (the memo's §8 work list, as ruling J-7 rewrites it).**
///
/// Ruling H-8's one-line test — "no registered profile's constructor input
/// has the squeeze length" — is one row of a table, and §7 of the memo lists
/// five more margins of one byte. **The class is the test**: for every
/// profile the lane registers, runs included, this prints every hash input
/// KIND with its exact length, asserts the memo's table, asserts per hash
/// FUNCTION that no two different kinds are the same length unless the pair
/// is DECLARED with the fixed literal that separates them, and LISTS every
/// pair within one byte.
///
/// **What "per hash function" means.** Two kinds of equal length are a
/// coincidence only if the same function hashes them. Under the LEGACY rule
/// there is one unkeyed function and everything is in it; under a tag the
/// transcript, column, leaf and node keys make four, the statement digests
/// and the refill stay unkeyed, and the generator's seed derivation is keyed
/// under entropy the adversary does not have (convention V-2). So the same
/// table means different things at the two rules, and this test computes the
/// grouping rather than assuming it.
#[test]
fn every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length() {
    // The DECLARED coincidences: pairs of kinds of equal length inside one
    // function, each with what separates them. Anything else fails.
    // `(length, a, b, the separating literal)` — `a` and `b` are substrings
    // of the kinds' plain-words names.
    const DECLARED: [(usize, &str, &str, &str); 8] = [
        // **STAGE 32, at the rung-W14 profile.** Its profile string is 48
        // bytes, so `Transcript::new`'s input — `b"hashline-v1/" ‖ profile`
        // — is 60 bytes, which is exactly what an absorb of the 4-byte
        // label `rows` with 8 bytes of data costs (`32 + 8 + 4 + 8 + 8`).
        // Both are hashed by the transcript function, so the pair has to be
        // declared. What separates them is a FIXED, CHECKABLE difference
        // inside the two `le64` LENGTH FIELDS: at offset 32 the absorb has
        // `le64(4)` — one value byte and SEVEN NULs, at offsets 33..39 —
        // and at offset 44 `le64(8)`, seven more at 45..51, while the
        // constructor carries the profile string's own ASCII bytes at all
        // fourteen positions, and a profile string is ASCII with no NUL at
        // any offset. The two inputs can therefore never be equal at ANY
        // profile of this length, which is a stronger statement than the
        // coincidence being unlikely.
        //
        // **STAGE 33, ruling J-7a — this row is now CHECKED and not
        // declared on trust.** `s33_tests` asserts the premise over the
        // whole registry (every profile, every `derive_key` context and
        // every absorb label is printable ASCII with no NUL), proves the
        // separation as a LEMMA over every registered profile length and
        // EVERY absorb layout of that length with the positions computed
        // rather than written down, and demonstrates this pair on real
        // bytes. **Finding S33-F1**: the sentence below said "six NUL
        // bytes" until stage 33; the count is seven in that field and
        // fourteen over the two.
        (
            60,
            "the transcript constructor at",
            "the transcript absorb of `rows`",
            "le64(4) ‖ \"rows\" ‖ le64(8) — fourteen positions forced to NUL inside the two length fields (33..39 and 45..51), where the constructor carries the profile string's own ASCII bytes (stage 32, a 48-byte profile; CHECKED as a lemma over every profile length and every layout by stage 33's s33_tests, ruling J-7a)",
        ),
        (
            49,
            "the transcript key's derive_key context",
            "the leaf key's derive_key context",
            "the context strings THEMSELVES: a derive_key context input IS a fixed public literal, and `…fiat-shamir transcript` and `…pcs salted merkle leaf` differ byte for byte although both are 49 bytes long",
        ),
        (
            64,
            "a salted Merkle leaf",
            "a Merkle inner node",
            "NOTHING — both are blake3(32 ‖ 32) under the legacy rule (the memo's claim B-7, ruling L-7, priced 2^-484.83); under a tag the leaf and node keys separate them and this pair does not arise",
        ),
        (64, "`log-cols`", "a salted Merkle leaf", "le64(8) ‖ \"log-cols\" ‖ le64(8), 24 fixed bytes at offset 32"),
        (64, "`log-cols`", "a Merkle inner node", "le64(8) ‖ \"log-cols\" ‖ le64(8), 24 fixed bytes at offset 32"),
        (81, "the transcript absorb of `", "the transcript absorb of `", "the one-byte label at offset 40, after the state and le64(1)"),
        (171, "`expected-IO`", "`parameters`", "le64(11) ‖ \"expected-IO\" against le64(10) ‖ \"parameters\", at offset 32"),
        (295, "`parameters`", "`pb-term`", "le64(10) ‖ \"parameters\" against le64(7) ‖ \"pb-term\", at offset 32 (the check's B-7, recorded by ruling J-7)"),
    ];
    let declared = |len: usize, a: &str, b: &str| -> Option<&'static str> {
        DECLARED
            .iter()
            .find(|(l, x, y, _)| *l == len && ((a.contains(x) && b.contains(y)) || (a.contains(y) && b.contains(x))))
            .map(|(_, _, _, why)| *why)
    };

    let mut profiles: Vec<(String, Shape, Option<(&'static str, usize, RunStatement)>)> = Vec::new();
    for sh in every_shape() {
        profiles.push((sh.profile.to_string(), sh, None));
    }
    for (p, sh, l) in every_run() {
        let st = run_statement(&sh, p, l);
        profiles.push((p.to_string(), sh, Some((p, l, st))));
    }
    // NATIVE LANE: the trained-calibration profiles — the blocks, and each
    // run bound to its trained-model statement, at L = 1 (what is proved
    // first) and at the whole TinyLlama stack's L = 22
    for sh in super::trained_calib_tests::registered_trained_shapes().into_iter().chain(super::accuracy_profile_tests::registered_shapes()) {
        profiles.push((sh.profile.to_string(), sh, None));
    }
    for (p, sh) in super::trained_calib_tests::registered_trained_runs() {
        for l in [1usize, 22] {
            let spec = IoSpec::new_shaped(&sh, s25_context(), 0, 0).expect("the run's endpoint spec");
            let st = super::trained_calib_tests::trained_run_statement(&sh, p, l, s25_context(), ExpectedIo::from_roots(spec, [1u8; 32], [2u8; 32]));
            profiles.push((p.to_string(), sh.clone(), Some((p, l, st))));
        }
    }
    // the registry, read out of the source exactly as stage 24 reads it
    let mut in_source = profile_literals(&source("src/private_block/shape.rs"));
    in_source.extend(profile_literals(&source("src/private_block/run.rs")));
    in_source.sort();
    in_source.dedup();
    let mut measured: Vec<String> = profiles.iter().map(|(p, _, _)| p.clone()).collect();
    measured.sort();
    measured.dedup();
    assert_eq!(in_source, measured, "a profile in the source registry has no hash-input table here (or vice versa)");

    let mut one_byte_rows: Vec<String> = Vec::new();
    let mut margin_families: std::collections::BTreeSet<String> = std::collections::BTreeSet::new();
    let mut total_kinds = 0usize;
    for (name, sh, run) in &profiles {
        let kinds = kinds_of(sh, run.as_ref().map(|(p, l, st)| (*p, *l, st)));
        total_kinds += kinds.len();
        // ---- the printout, in length order
        let mut sorted = kinds.clone();
        sorted.sort_by_key(|k| (k.len, k.what.clone()));
        eprintln!("--- {name} ({}), {} kinds, rule {} ---", sh.name, kinds.len(), if sh.hashes_under_the_legacy_rule() { "legacy" } else { "tagged" });
        for k in &sorted {
            eprintln!("    {:>9} B  {:<4} {}", k.len, k.func, k.what);
        }
        // ---- (a) per FUNCTION, no two DIFFERENT kinds of equal length
        let mut by: std::collections::BTreeMap<(&str, usize), Vec<String>> = std::collections::BTreeMap::new();
        for k in &kinds {
            let e = by.entry((k.func, k.len)).or_default();
            if !e.contains(&k.what) {
                e.push(k.what.clone());
            }
        }
        for ((func, len), whats) in &by {
            for i in 0..whats.len() {
                for j in i + 1..whats.len() {
                    let why = declared(*len, &whats[i], &whats[j]).unwrap_or_else(|| {
                        panic!("{name}: {func} hashes two DIFFERENT kinds at {len} bytes and the memo's table does not record the pair: `{}` and `{}`", whats[i], whats[j])
                    });
                    assert!(!why.is_empty());
                }
            }
        }
        // ---- (b) every pair within ONE BYTE, printed and not failed
        let mut flat: Vec<&Kind> = kinds.iter().collect();
        flat.sort_by_key(|k| k.len);
        for i in 0..flat.len() {
            for j in i + 1..flat.len() {
                if flat[j].len == flat[i].len + 1 {
                    one_byte_rows.push(format!("{name}: {} B {} ({}) vs {} B {} ({})", flat[i].len, flat[i].what, flat[i].func, flat[j].len, flat[j].what, flat[j].func));
                    margin_families.insert(format!("{}|{}", flat[i].len, flat[j].len));
                }
            }
        }
    }
    eprintln!("--- every pair of hash input kinds within ONE BYTE, per profile ({} rows) ---", one_byte_rows.len());
    for r in &one_byte_rows {
        eprintln!("    {r}");
    }
    // the memo's §7 table of six one-byte margins, each re-derived above and
    // required to appear in the printout
    for (lo, hi, what) in [
        (63usize, 64usize, "`pb-slot` against `log-cols`"),
        (71, 72, "`pb-term`(1) against the rung-G / rung-K4 endpoint column"),
        (87, 88, "`pb-term`(2) against `schedule`"),
        (151, 152, "`pb-term`(6) against `sc-round` at degree 5"),
        (50, 51, "the toy's seam seed derivation against the toy's constructor"),
        (46, 47, "the 125M run profile's constructor against the squeeze — ruling H-8's"),
    ] {
        assert!(margin_families.contains(&format!("{lo}|{hi}")), "the memo's one-byte margin {lo} vs {hi} ({what}) is not in the printout");
    }
    eprintln!("S25 W-2: {} profiles, {total_kinds} hash input kinds, {} pairs within one byte, {} declared equal-length pairs", profiles.len(), one_byte_rows.len(), DECLARED.len());
}

/// **The memo's §5 and §5.1 tables, re-derived from the code.** Every fixed
/// length the memo lists, every per-shape length, and the two the code
/// contradicts, which are findings and not assertions of the memo's numbers.
#[test]
fn the_memos_length_table_is_re_derived_from_the_code() {
    // ---- the lengths that are the same at every shape (§5.1's last block)
    let entries = hash_domain::path_labels(&Shape::m125(), None);
    let data_of = |label: &str| -> Vec<usize> { entries.iter().find(|u| u.label == label).unwrap_or_else(|| panic!("`{label}` left the table")).data.clone() };
    let absorb = |label: &str, data: usize| 48 + label.len() + data;
    for (label, data, want) in [
        ("rows", 8usize, 60usize),
        ("pb-slot", 8, 63),
        ("log-cols", 8, 64),
        ("pb-run-stage", 8, 68),
        ("pb-scalar", 16, 73),
        ("A", 32, 81),
        ("H", 32, 81),
        ("B", 32, 81),
        ("M", 32, 81),
        ("schedule", 32, 88),
        ("pb-run-block", 32, 92),
        ("public-statement", 32, 96),
        ("run-shape", 56, 113),
        ("expected-IO", 112, 171),
        ("mask-q", 16384, 16438),
        ("mask-prox", 16384, 16441),
    ] {
        assert_eq!(absorb(label, data), want, "the memo's fixed length for `{label}`");
        assert!(data_of(label).contains(&data), "`{label}` no longer absorbs {data} bytes of data");
    }
    // `sc-round` at degrees 2..5, the memo's 104 / 120 / 136 / 152
    let sc: Vec<usize> = data_of("sc-round").iter().map(|d| absorb("sc-round", *d)).collect();
    assert_eq!(sc, vec![104, 120, 136, 152], "the `sc-round` absorb lengths moved");
    // `pb-term` is `55 + 16k`, and never a multiple of eight (the memo's
    // "7 mod 16" argument, re-derived over the whole reachable range)
    for k in 0..=56usize {
        assert_eq!(absorb("pb-term", 16 * k), 55 + 16 * k);
        assert_eq!((55 + 16 * k) % 16, 7, "a pb-term absorb of {k} terminals is not 7 mod 16");
    }
    // the fixed non-transcript lengths
    assert_eq!(32 + 7 + 8, 47, "the squeeze");
    assert_eq!(32 + 8, 40, "the refill");
    assert_eq!(28 + 32 + 8 * 8 + 4, 128, "the frozen seam's spec digest");
    assert_eq!(42 + 32 + 8 * 8 + 4, 142, "the generalised endpoint's spec digest");
    assert_eq!(43 + 32 + 9 * 8 + 4, 151, "the internal boundary's spec digest");
    assert_eq!("B3 public fixed calibration v1".len(), 30, "the calibration identity's preimage");

    // ---- §5.1's per-shape table
    // **STAGE 26 moved the `block seed` column at the three UNFROZEN
    // profiles** — 68 / 69 / 58 were `22 + |profile|`; they are now
    // `22 + |use literal| + 1 + |profile|` under the ruling on finding B-1.
    // The two FROZEN profiles' 61 and 66 are the reexamination's own numbers
    // and may not move.
    // **STAGE 30 adds the rung-P2 row**, and it is a row of coincidences
    // worth reading: its profile string is exactly as long as rung-K4's (47
    // bytes), so the constructor input and the block seed are rung-K4's 59
    // and 117 to the byte; its padded layout IS rung-K4's, so the A and H
    // column digests are the same 5,816 and 5,760; and its row width and
    // opened-column count are the rungs', so the `pcs-vec` block is the
    // same 20,535. Nothing about the pad rule reaches a hash INPUT LENGTH,
    // which is the point of the row being identical.
    // **STAGE 31 adds the rung-C6 row.** Its profile string is again 47
    // bytes, so the constructor input and the block seed are rung-K4's 59
    // and 117 once more, and its row width and opened-column count are the
    // rungs', so the `pcs-vec` block is the same 20,535. The two columns
    // that DO move are the A and H column digests, and they move for two
    // reasons at once: the head dimension is 32 rather than 8, so `Dom::D`,
    // `Dom::Q` and `Dom::Kv` are four times as tall; and correction C-6
    // drops two `Dom::D` helper planes, which is why `H` is 11,264 rather
    // than the 11,584 that nineteen helpers would give. Its endpoint column
    // is 168 — the frozen-seam rung's number, at sixteen data rows of a
    // GENERALISED endpoint rather than sixteen of the seam's.
    // **STAGE 32 adds the rung-W14 row**, and it is the first row whose
    // `pcs-vec` block is not a rung's: that absorb is
    // `48 + 7 + 16 (2^log_cols + Q)` and knows nothing else about the shape,
    // so at `log_cols = 14` with 256 opened columns it is 125M's own
    // **266,295**. Its profile string is 48 bytes — one longer than the
    // three 47-byte ones — so the constructor input is 60 and the block seed
    // 118. The A and H column digests are `8 · rows`, and the ROW COUNT is
    // what a wider row makes small: 527 and 436 against rung-C6's 1,337 and
    // 1,408 and 125M's 5,681 and 7,120, hence 4,216 and 3,488 — the smallest
    // of any shape but the toy, at the largest row width. The endpoint
    // column is 72: nine commitment rows, four of them data, because the
    // padded `Dom::D` cube is 2^16 words at an endpoint log of 14.
    // **STAGE 33 adds the rung-E32 row.** Its profile string is 48 bytes, as
    // rung-W14's is, so the constructor input is 60 and the block seed 118
    // again; its `pcs-vec` block is back to a rung's 20,535, because that
    // absorb knows only the row width and this shape's is 10. What is new in
    // the row is the ENDPOINT column: `8 · 37 = 296`, **125M's own**, at
    // thirty-two data rows of a 2^10-wide endpoint. Its A and H column
    // digests are the largest of any development shape (2,209 and 2,416
    // rows), which is what 125M's head axis costs at a narrow row.
    let want: [(&str, usize, usize, usize, usize, usize, usize); 9] = [
        // (name, constructor, A column, H column, endpoint column, block seed, pcs-vec block)
        ("toy", 51, 3640, 3072, 56, 61, 8247),
        ("rung", 56, 4984, 4608, 168, 66, 20535),
        ("rung-g", 58, 4984, 4608, 72, 116, 20535),
        ("rung-k4", 59, 5816, 5760, 72, 117, 20535),
        ("rung-p2", 59, 5816, 5760, 72, 117, 20535),
        ("rung-c6", 59, 10696, 11264, 168, 117, 20535),
        ("rung-w14", 60, 4216, 3488, 72, 118, 266295),
        ("rung-e32", 60, 17672, 19328, 296, 118, 20535),
        ("m125", 48, 45448, 56960, 296, 106, 266295),
    ];
    for (sh, (name, ctor, a, h, e, seed, vec_len)) in every_shape().into_iter().zip(want) {
        let lay = Layout::for_shape(&sh).expect("a registered shape has a layout");
        assert_eq!(12 + sh.profile.len(), ctor, "{name}: the transcript constructor's input");
        assert_eq!(8 * lay.a_rows, a, "{name}: the A column digest");
        assert_eq!(8 * lay.h_rows, h, "{name}: the H column digest");
        assert_eq!(8 * M_ROWS, 400, "{name}: the M column digest");
        assert_eq!(8 * sh.endpoint_rows, e, "{name}: the endpoint column digest");
        assert_eq!(hash_domain::single_block_seed_input_len(&sh), seed, "{name}: the block prover's seed derivation");
        assert_eq!(48 + "pcs-vec".len() + 16 * ((1usize << sh.log_cols) + sh.opened_cols), vec_len, "{name}: the `pcs-vec` absorb at the block geometry");
        // STAGE 26: the generalised endpoint's is 99 (the use literal, the
        // role byte and the spec digest) where it was 64 — the leaf and node
        // length. The frozen seam's 50 is unchanged, in a file this lane may
        // not edit.
        assert_eq!(
            if sh.endpoint_general { hash_domain::endpoint_seed_input_len() } else { 22 + 28 },
            if sh.endpoint_general { 99 } else { 50 },
            "{name}: the endpoint's seed derivation"
        );
    }
    // the run constructors and public statements of §5.1's last two lines.
    // **STAGE 30**: the rung-P2 run's 57 is the rung-K4 run's, because the
    // two profile strings are the same length, and its public statement
    // digest input is the same 125 at `L = 3` — that input is `29 + 32 L`
    // and knows nothing about the shape.
    // **STAGE 32**: the rung-W14 run's constructor input is 58, one more
    // than the three 45-byte run profiles', and its public statement digest
    // input is again 125 — that input is `29 + 32 L` and knows nothing about
    // the shape.
    // **STAGE 33**: the rung-E32 run profile is 46 bytes as rung-W14's is, so
    // its constructor input is 58 too, and its public statement digest input
    // is again 125 at `L = 3`.
    for ((p, _, l), (ctor, public)) in every_run().into_iter().zip([(56usize, 125usize), (57, 125), (57, 125), (57, 125), (58, 125), (58, 125), (46, 413)]) {
        assert_eq!(12 + p.len(), ctor, "{p}: the run transcript constructor's input");
        assert_eq!(29 + 32 * l, public, "{p}: the run public statement digest's input");
    }

    // ---- THE TWO THE CODE CONTRADICTS (findings, recorded in the ledger)
    // (1) the `calibration` absorb is 91 bytes and is in no list of the memo's
    assert_eq!(absorb("calibration", 32), 91, "the calibration absorb");
    // (2) the four derive_key CONTEXT lengths are 49 / 44 / 49 / 48, each one
    // byte more than the memo's 48 / 43 / 48 / 47
    let ctx = [
        zkp_core::hashtag::CTX_TRANSCRIPT.len(),
        zkp_core::hashtag::CTX_COLUMN.len(),
        zkp_core::hashtag::CTX_LEAF.len(),
        zkp_core::hashtag::CTX_NODE.len(),
    ];
    assert_eq!(ctx, [49, 44, 49, 48], "the four derive_key contexts");
    // and the two 49-byte contexts are separated by the literal itself
    let ctxs = [zkp_core::hashtag::CTX_TRANSCRIPT, zkp_core::hashtag::CTX_COLUMN, zkp_core::hashtag::CTX_LEAF, zkp_core::hashtag::CTX_NODE];
    for i in 0..4 {
        for j in i + 1..4 {
            assert_ne!(ctxs[i], ctxs[j], "two derive_key contexts are the same string");
        }
    }
    eprintln!("S25 W-2: the memo's table re-derived; two differences — the `calibration` absorb at 91 B is in no list, and the derive_key contexts are 49/44/49/48 and not 48/43/48/47");
}

/// **D2's length formula is the code's, byte for byte.** The 125M block's
/// public digest hashes about 9 MB and no guard can build those weights, so
/// [`block_public_digest_input_len`] is arithmetic — and arithmetic about a
/// hash input is worth nothing unless it is checked against the hasher. Two
/// REAL statements are re-walked here, tensor by tensor, in
/// `BlockPublic::digest`'s own order.
#[test]
fn the_block_public_digest_input_length_formula_is_the_codes() {
    for sh in [Shape::toy(), Shape::rung_g()] {
        let blk = if sh.is_frozen_toy() {
            BlockPublic::synthetic_fixture().0
        } else {
            let (public, ff, _) = super::grow_tests::tame_case(&sh);
            BlockPublic::new(public, ff)
        };
        let a = blk.attention();
        let f = blk.feed_forward();
        let mut walked = 31usize;
        for n in [a.wq.len(), a.wk.len(), a.wv.len(), a.wo.len(), a.gamma_a.len()] {
            walked += 8 + n;
        }
        for n in [a.rope_cos.len(), a.rope_sin.len(), a.exp.len()] {
            walked += 8 + 8 * n;
        }
        for n in [f.gamma_m.len(), f.wg_t.len(), f.wu_t.len(), f.wd_t.len()] {
            walked += 8 + n;
        }
        walked += 8 + 2 * f.act.len();
        assert_eq!(walked, block_public_digest_input_len(&sh), "{}: the D2 formula is not the tensors the digest hashes", sh.name);
    }
    eprintln!(
        "S25 W-2: D2's input is {} B at the toy, {} B at rung-G and {} B at 125M [COMPUTED]",
        block_public_digest_input_len(&Shape::toy()),
        block_public_digest_input_len(&Shape::rung_g()),
        block_public_digest_input_len(&Shape::m125())
    );
}

// ---------------------------------------------------------------------------
// W-3 — the refusal replay, on real openings
// ---------------------------------------------------------------------------

/// One claim of exactly the shape `argument::build_claim` raises on a
/// boundary, with its TRUE value computed from the committed matrix: the data
/// slice over the whole padded plane, plus the reserved pair of site `s` with
/// weights `(cm, cm·U)`. The three parts share one column key — the point's
/// last `log_n` coordinates — which is what makes them ONE opening group.
/// Written out here from the spec's own public accessors (`log_n`, `len`,
/// `mask_row`), so this file adds no visibility to any production type.
fn true_boundary_claim(spec: &super::boundary::BoundarySpec, data: &[Fp], site: usize, point: &[Fp2], cm: Fp2) -> crate::pcs::ZClaim {
    use crate::mle::eq_table_msb;
    use crate::pcs::{Slice, ZPart};
    let (log_n, log_len) = (spec.log_n(), spec.len().trailing_zeros() as usize);
    let n = 1usize << log_n;
    let mask_row = spec.mask_row(site).expect("a declared claim site");
    let tail = point[log_len - log_n..].to_vec();
    let mut parts = vec![ZPart { slice: Slice { offset: 0, log_size: log_len as u32 }, coef: Fp2::ONE, point: point.to_vec() }];
    for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
        parts.push(ZPart { slice: Slice { offset: (mask_row + k) * n, log_size: log_n as u32 }, coef: cm.mul(u), point: tail.clone() });
    }
    let col = eq_table_msb(&tail);
    let fold = |r: usize| (0..n).fold(Fp2::ZERO, |a, c| a.add(col[c].mul_base(data[r * n + c])));
    let eq_r = eq_table_msb(&point[..log_len - log_n]);
    let mut value = eq_r.iter().enumerate().fold(Fp2::ZERO, |a, (i, e)| a.add(e.mul(fold(i))));
    for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
        value = value.add(cm.mul(u).mul(fold(mask_row + k)));
    }
    crate::pcs::ZClaim { parts, value }
}

/// **W-3 — THE REFUSAL REPLAY (the memo's claim B-6, ruling J-6).**
///
/// **What the family is.** Before every opening the prover and the verifier
/// both run `protocol::check_opening`, which CLONES the transcript and draws
/// `Σ members + rows` challenges to test them for the two discard conditions
/// (`protocol.rs:305-306`); `pcs::open_zk` then draws *the same* `Σ members +
/// rows` challenges from the LIVE transcript (`zk_rhos`,
/// `zkp-core/src/pcs.rs:941-963`). The memo: *"These are not two near-misses;
/// they are the same oracle points, queried twice, by design"* — and §8's
/// "what pins it" column against that row said **nothing**.
///
/// **What is pinned here, on a REAL rung-K4 internal boundary** — the
/// geometry a real three-block rung-K4 run commits, taken from the run
/// statement's own `boundary_spec(0)`, committed over a NON-CONSTANT plane
/// with fresh operating-system randomness, opened by the real
/// `PreparedBoundary::into_opening` (which is `check_opening` then
/// `pcs::open_zk`, with nothing between them):
///
/// 1. **The live transcript's observable state is unchanged by the replay.**
///    `check_opening` takes the transcript by SHARED reference and the state
///    before and after are equal — and so is the next challenge the live
///    chain would draw, which is the strongest observation available (finding
///    U-3: `zkp-core` publishes no squeeze-counter accessor and this lane does
///    not edit it, so the (state, next-challenge) pair stands in for the
///    counter).
/// 2. **The replay's points ARE the live chain's next points.** The values the
///    replay consumes, recorded through `check_opening_challenges`' injectable
///    draw, equal element for element the values a clone at the same state
///    produces in `zk_rhos`' own order (`challenge_fp2_vec(members)` per
///    group, then `challenge_fp2_vec(rows)`).
/// 3. **And the live chain really is that clone**: after the REAL opening, a
///    clone that drew exactly those challenges and then absorbed the opening's
///    own vectors reproduces the live transcript's state exactly, and the
///    column indices it samples are the opening's own. If the replay had
///    disturbed the live transcript, or had drawn different points, neither
///    would hold.
/// 4. **Non-vacuity**: a clone that draws ONE challenge more before the
///    absorbs ends somewhere else, and the honest opening verifies.
///
/// **The one observation that would need a production hook, NOT added**: the
/// live evaluation order *inside* `check_opening_challenges` (a
/// `#[cfg(test)] fn observe(condition, draw_index)` beside the two refusals,
/// which ruling GS-2 declined) and a counter accessor on `Transcript`. What
/// replaces them is (1)–(3), which are measurements on the real objects.
#[test]
fn the_refusal_replay_re_issues_the_live_chains_next_points_and_leaves_it_untouched() {
    use crate::ntt::NttTables;
    use crate::pcs::{self, ZkOpts};
    use crate::zk::ZkRng;
    let sh = Shape::rung_k4();
    let st = run_statement(&sh, RUN_PROFILE_RUNG_K4, 3);
    let spec = st.boundary_spec(0).expect("the rung-K4 run's first internal boundary");
    assert_eq!(spec.commitment_rows(), sh.endpoint_rows + 1, "the boundary geometry is not the run's own");
    let ntt = NttTables::new(spec.enc_log());
    let mut rng = ZkRng::from_os(b"stage 25: the refusal replay's own commitment").expect("fresh operating-system randomness");
    // a NON-CONSTANT plane: every word different, none zero
    let values: Vec<Fp> = (0..spec.len()).map(|i| Fp::from_i64(((i as i64 * 2_654_435_761) % 65_521) - 32_760)).collect();
    assert!(values.windows(2).any(|w| w[0] != w[1]), "the committed plane is constant");
    let owner = super::boundary::prepare(&spec, &values, &ntt, &mut rng, &sh.hash_tag()).expect("the boundary commits");
    let cm = owner.commitment();
    let point = |seed: u64| -> Vec<Fp2> {
        (0..spec.len().trailing_zeros() as u64).map(|i| Fp2::new(Fp::from_i64((7 + seed * 131 + i * 17) as i64), Fp::from_i64((11 + seed * 53 + i * 29) as i64))).collect()
    };
    let claims = vec![true_boundary_claim(&spec, owner.data(), 0, &point(1), Fp2::ONE), true_boundary_claim(&spec, owner.data(), 1, &point(2), Fp2::U)];

    // the live transcript, at a real state: the run's own header, then this
    // boundary's root, exactly as `prove_run` absorbs it
    let mut live = super::protocol::tagged_transcript(&sh, RUN_PROFILE_RUNG_K4.as_bytes());
    live.absorb(b"pb-run-stage", &0u64.to_le_bytes());
    super::protocol::absorb_root(&mut live, b"B", &owner.root(), spec.commitment_rows(), spec.log_n());
    let mirror = Transcript::clone_state(&live);

    // (1) THE LIVE TRANSCRIPT IS UNCHANGED BY THE REPLAY
    let before = live.state();
    let next_before = Transcript::clone_state(&live).challenge_fp2();
    super::boundary::check_opening(&spec, &claims, &live).expect("the honest boundary opening passes the refusal replay");
    assert_eq!(live.state(), before, "the refusal replay moved the live transcript's state");
    assert_eq!(Transcript::clone_state(&live).challenge_fp2(), next_before, "the refusal replay moved the live transcript's squeeze counter");

    // (2) THE REPLAY'S POINTS ARE THE LIVE CHAIN'S NEXT POINTS
    let members = vec![1usize, 1];
    let rows = spec.commitment_rows();
    let mut replay_tr = Transcript::clone_state(&live);
    let mut replayed: Vec<Fp2> = Vec::new();
    super::protocol::check_opening_challenges(&members, rows, spec.prox_row(), || {
        let v = replay_tr.challenge_fp2();
        replayed.push(v);
        v
    })
    .expect("the honest replay is accepted");
    let mut chain = Transcript::clone_state(&live);
    let mut next: Vec<Fp2> = Vec::new();
    for m in &members {
        next.extend(chain.challenge_fp2_vec(*m));
    }
    next.extend(chain.challenge_fp2_vec(rows));
    assert_eq!(replayed.len(), members.iter().sum::<usize>() + rows, "the replay drew a different number of challenges than the opening will");
    assert_eq!(replayed, next, "the refusal replay's challenges are not the ones the live chain draws next");

    // (3) AND THE LIVE CHAIN IS THAT CLONE: the real opening, then the clone
    // continued with the opening's own words
    let opening = owner.into_opening(&spec, &claims, &mut live).expect("the one opening");
    assert_eq!(opening.group_vecs.len(), 2, "two claims at two points did not form two groups");
    for v in &opening.group_vecs {
        chain.absorb_fp2(b"pcs-vec", v);
    }
    chain.absorb_fp2(b"pcs-prox", &opening.prox_vec);
    let idx = chain.challenge_indices(spec.params().num_col_checks, spec.params().enc_cols());
    assert_eq!(idx, opening.columns.iter().map(|c| c.0).collect::<Vec<_>>(), "the clone that drew the replay's challenges samples other columns than the opening did");
    assert_eq!(chain.state(), live.state(), "the live transcript is not the clone that drew exactly the replay's points");
    assert_ne!(live.state(), before, "the opening did not move the live transcript at all");

    // (4) NON-VACUITY, in test code alone: one extra challenge before the
    // absorbs and the reproduction fails
    let mut off = Transcript::clone_state(&mirror);
    for m in &members {
        let _ = off.challenge_fp2_vec(*m);
    }
    let _ = off.challenge_fp2_vec(rows);
    let _ = off.challenge_fp2();
    for v in &opening.group_vecs {
        off.absorb_fp2(b"pcs-vec", v);
    }
    off.absorb_fp2(b"pcs-prox", &opening.prox_vec);
    assert_ne!(off.state(), live.state(), "a clone that drew one challenge too many reproduced the live transcript");

    // and the opening is an HONEST one: the verifier's own audit and
    // `pcs::verify_zk` accept it from the mirror transcript
    let mut vtr = mirror;
    super::boundary::check_opening(&spec, &claims, &vtr).expect("the verifier's own refusal replay");
    let params = spec.params();
    // rung-K4 is a TAGGED profile, so the verifier of record is the tagged
    // one, under the shape's own hash tag — the same call `run.rs:716` makes
    // for a boundary
    pcs::verify_zk_tagged(&params, &ZkOpts::standard(&params), &cm, &claims, &opening, &ntt, &mut vtr, &sh.hash_tag()).expect("the honest boundary opening verifies");
    assert_eq!(vtr.state(), live.state(), "the verifier's transcript is not the prover's after the opening");
    eprintln!(
        "S25 W-3: rung-K4 boundary of {rows} rows, 2 groups: the replay drew {} challenges, equal to the live chain's next {} and leaving its state and next squeeze unmoved; the continued clone reproduces the live state and the opening's {} sampled columns",
        replayed.len(),
        next.len(),
        idx.len()
    );
}

// ---------------------------------------------------------------------------
// W-4 — the statement digests and the seed derivations enter the LEGACY guard
// ---------------------------------------------------------------------------

/// **The statement-class lengths this stage added to the guard are the ones
/// the code hashes.** `hash_domain.rs` retypes three `DOMAIN` literals,
/// because a sibling module cannot see a private `const` and one of the three
/// modules (`private_seam.rs`) is outside this lane's write set entirely. So
/// each is pinned to its SOURCE TEXT, exactly as stage 16 pins the three
/// `zkp-core` hasher bodies — and, like those, this pins the text and not the
/// behaviour, which is said here rather than left to be discovered.
#[test]
fn the_statement_class_lengths_are_the_ones_the_code_hashes() {
    // the three spec-digest domains, by their literals
    for (file, literal, len) in [
        ("src/private_block/endpoint_g.rs", "const DOMAIN: &[u8] = b\"hashline/private-block/general-endpoint/v1\";", 42usize),
        ("src/private_block/boundary.rs", "const DOMAIN: &[u8] = b\"hashline/private-block/internal-boundary/v1\";", 43),
        ("src/private_seam.rs", "const DOMAIN: &[u8] = b\"experimental-private-seam/v1\";", 28),
    ] {
        let src = source(file);
        assert!(src.contains(literal), "{file}: the domain literal moved: {literal}");
        let quoted = literal.split('"').nth(1).expect("a quoted literal");
        assert_eq!(quoted.len(), len, "{file}: the domain is not {len} bytes");
    }
    // the generator's seed derivation: prefix and key
    let rng = source("../zkp-core/src/rng.rs");
    assert!(
        rng.contains("let mut h = blake3::Hasher::new_keyed(&entropy);\n        h.update(b\"hashline-zk-os-rng/v1/\");\n        h.update(domain);"),
        "ZkRng::from_entropy_reader no longer hashes a 22-byte prefix and the domain under the entropy key"
    );
    assert_eq!("hashline-zk-os-rng/v1/".len(), 22, "the seed derivation's fixed prefix");
    // the four digest bodies whose input lengths the guard now carries
    for (file, needle) in [
        ("src/private_block.rs", "*blake3::hash(b\"B3 public fixed calibration v1\").as_bytes()"),
        ("src/private_block/endpoint_g.rs", "h.update(DOMAIN);\n        h.update(&self.context);"),
        ("src/private_block/boundary.rs", "h.update(DOMAIN);\n        h.update(&self.context);"),
        ("src/private_seam.rs", "h.update(DOMAIN);\n        h.update(&self.context);"),
    ] {
        assert!(source(file).contains(needle), "{file}: the digest body moved");
    }
    // and the arithmetic the guard is built from
    for (len, want) in [(hash_domain::full_shape_free().describe(128), "frozen seam"), (hash_domain::full_shape_free().describe(142), "generalised endpoint"), (hash_domain::full_shape_free().describe(151), "internal boundary")] {
        let d = len.unwrap_or_else(|| panic!("the set does not describe the {want} digest"));
        assert!(d.contains(want), "{d} does not name the {want}");
    }
    eprintln!("S25 W-4: the three spec-digest domains (42 / 43 / 28 B), the 22-byte seed prefix and the calibration literal are pinned to their source");
}

/// **W-4 (ruling J-7 keeps it although the check's B-9.3 narrows the
/// hazard).** The length guard stage 16 completed was built from the
/// TRANSCRIPT class alone — the constructor, the absorbs, the squeeze, the
/// refill and the node — and the memo's claim B-9 found what that leaves out:
/// a commitment of **16 rows** hashes its column to 128 bytes, which is the
/// frozen seam's spec digest, and nothing refused it. The seed derivation's
/// `22 + |domain|` was missing for the same reason, and at the generalised
/// endpoint it is **64** — the leaf and node length.
///
/// **THE FAILING-FIRST IS A LIVE ASSERTION, not a transient log.**
/// [`hash_domain::shape_free`] is the guard exactly as stage 16 left it and is
/// still pinned by stage 16's own tests; it ACCEPTS a 16-row commitment here,
/// in this test, every time it runs. [`hash_domain::full_shape_free`] is what
/// the two bare statement constructors now impose, and it refuses the same
/// count by name. The two assertions sit side by side so the "before" cannot
/// rot.
///
/// **Nothing an accepted profile has moves.** Both legacy geometries are
/// asserted to pass, by hand: the byte-frozen toy's 455 / 384 / 50 / 7 and the
/// frozen-seam rung's 623 / 576 / 50 / 21.
#[test]
fn the_legacy_length_guard_now_carries_the_statement_digests_and_the_seed_derivations() {
    use zkp_core::hashtag::HashTag;
    // (1) FAILING FIRST: stage 16's set accepts a 16-row commitment.
    hash_domain::shape_free().refuse(&[("internal boundary", 16)]).expect("stage 16's set accepted 16 rows; the 'before' of this stage has changed");
    assert!(hash_domain::at_shape(&Shape::toy()).refuse(&[("internal boundary", 16)]).is_ok(), "stage 16's per-shape set already refused 16 rows at the toy");

    // (2) AND THE COMPLETED SET REFUSES IT, BY NAME, naming the collision.
    let e = hash_domain::full_shape_free().refuse(&[("internal boundary", 16)]).expect_err("a 16-row commitment must be refused under the legacy rule");
    assert!(e.contains("16 rows") && e.contains("128 bytes") && e.contains("C-H4"), "{e}");
    assert!(e.contains("frozen seam"), "the refusal does not name the collision: {e}");
    // at both legacy profiles' own shape-driven sets, and at the two bare
    // statement constructors, which is where a boundary and an endpoint
    // really are built
    for sh in [Shape::toy(), Shape::rung()] {
        let e = hash_domain::imposed_at_shape(&sh).refuse(&[("internal boundary", 16)]).expect_err("16 rows must be refused at a legacy profile");
        assert!(e.contains("128 bytes"), "{}: {e}", sh.name);
    }
    let e = super::layout::no_commitment_has_a_node_shaped_column_under(&[("internal boundary", 16)], &HashTag::legacy()).expect_err("the bare constructors must refuse 16 rows under the legacy rule");
    assert!(e.contains("128 bytes"), "{e}");
    // A REAL CONSTRUCTOR: a synthetic legacy internal boundary of 16 rows —
    // a `32 x 128` plane over a `2^10` row width is 4 data rows, and five
    // claim sites give `4 + 2*5 + 2 = 16`.
    let ctx = s25_context();
    let e = super::boundary::BoundarySpec::new_with_tag(ctx, 32, 128, 0, 1, 3, 9, 4, 256, 16, &HashTag::legacy()).expect_err("a 16-row legacy boundary must be refused");
    assert!(e.contains("16 rows") && e.contains("128 bytes") && e.contains("C-H4"), "{e}");
    // the SAME geometry constructs under a tag, exactly as stage 18's amended
    // rule requires: three different functions, so the length means nothing
    super::boundary::BoundarySpec::new_with_tag(ctx, 32, 128, 0, 1, 3, 9, 4, 256, 16, &Shape::rung_g().hash_tag()).expect("a TAGGED 16-row boundary must still construct");

    // (3) NO ACCEPTED GEOMETRY MOVES.
    for (sh, want) in [(Shape::toy(), [455usize, 384, 50, 7]), (Shape::rung(), [623, 576, 50, 21])] {
        let lay = Layout::for_shape(&sh).expect("a legacy profile's layout still builds");
        assert_eq!([lay.a_rows, lay.h_rows, M_ROWS, sh.endpoint_rows], want, "{}: the legacy geometry moved", sh.name);
        hash_domain::imposed_at_shape(&sh)
            .refuse(&[("A", lay.a_rows), ("H", lay.h_rows), ("M", M_ROWS), ("endpoint", sh.endpoint_rows)])
            .unwrap_or_else(|e| panic!("{}: the completed guard refuses an accepted geometry: {e}", sh.name));
    }
    // and the generalised endpoint's and the boundary's reachable counts are
    // clear of the new member too
    for r in [6usize, 7, 9, 13, 21, 37] {
        let refused = hash_domain::full_shape_free().refuse(&[("general endpoint", r)]).is_err();
        assert_eq!(refused, r == 13, "the shape-free verdict on {r} endpoint rows changed for a reason other than 13's `sc-round`");
    }
    for r in [10usize, 38] {
        hash_domain::full_shape_free().refuse(&[("internal boundary", r)]).unwrap_or_else(|e| panic!("{r} boundary rows: {e}"));
    }

    // (4) THE SET IS STILL EMPTY AT A TAGGED PROFILE (ruling T-3 as amended,
    // which J-7 does not reopen).
    for sh in [Shape::rung_g(), Shape::rung_k4(), Shape::m125()] {
        for r in [5usize, 8, 11, 12, 13, 15, 16, 17, 19] {
            hash_domain::imposed_at_shape(&sh).refuse(&[("probe", r)]).unwrap_or_else(|e| panic!("{}: the guard fired at a tagged profile: {e}", sh.name));
        }
    }

    // (5) WHAT THE NEW MEMBERS ARE, and the only new DANGEROUS row count.
    let before: Vec<usize> = hash_domain::shape_free().dangerous_rows().keys().copied().collect();
    let after: Vec<usize> = hash_domain::full_shape_free().dangerous_rows().keys().copied().collect();
    assert_eq!(before, vec![5, 8, 11, 12, 13, 15, 17, 19], "stage 16's shape-free set moved");
    assert_eq!(after, vec![5, 8, 11, 12, 13, 15, 16, 17, 19], "the completed shape-free set is not stage 16's plus 16");
    // **STAGE 26 took the generalised endpoint's seed derivation OUT of the
    // 64-byte class** — that was the whole point of re-domaining it — so 64
    // is the Merkle node's and the salted leaf's alone again, and row count
    // 8 is still refused by them.
    let d = hash_domain::full_shape_free().describe(64).expect("64 bytes describes something");
    assert!(d.contains("Merkle"), "the 64-byte class lost the Merkle node: {d}");
    assert!(!d.contains("generalised endpoint"), "the generalised endpoint's seed derivation is back in the 64-byte class: {d}");
    assert!(
        hash_domain::full_shape_free().describe(hash_domain::endpoint_seed_input_len()).is_some_and(|s| s.contains("generalised endpoint")),
        "the endpoint's seed derivation is not in the set at its own length"
    );
    // and the per-shape sets gain the block prover's own seed derivation,
    // which is not a multiple of eight at any registered profile
    for sh in every_shape() {
        let s = hash_domain::full_at_shape(&sh);
        let seed = hash_domain::single_block_seed_input_len(&sh);
        assert!(s.describe(seed).is_some(), "{}: the block prover's seed derivation is not in the set", sh.name);
        assert_ne!(seed % 8, 0, "{}: the seed derivation is a multiple of eight and would be a row count", sh.name);
    }
    eprintln!("S25 W-4: the legacy shape-free dangerous row counts are {before:?} -> {after:?}; 16 refused by name at both legacy profiles and at the two bare constructors, clear under a tag");
}

/// **The run's own set gains the run's statement class**, and the run facts
/// really reach it: a run's public statement digest, its boundary's spec
/// digest and the generator its own profile seeds are in the set that
/// `RunStatement::new` imposes.
#[test]
fn a_runs_imposed_set_carries_the_runs_own_statement_class() {
    // a LEGACY run is the only case in which the set is non-empty, and no
    // registered run profile is legacy — so this is checked on the
    // description, which is the same function without the rule gate
    let sh = Shape::rung();
    let facts = RunFacts { profile: "hashline-zk-mr1/private-run-rung-t24-dev/1", l: 3, parameter_line: "a synthetic run parameter line" };
    let set = hash_domain::full_at_shape_with(&sh, Some(&facts));
    assert!(set.describe(29 + 32 * 3).is_some(), "the run's public statement digest is not in the run's set");
    assert!(set.describe(151).is_some(), "the internal boundary's spec digest is not in the run's set");
    assert!(set.describe(hash_domain::run_seed_input_len(facts.profile)).is_some(), "the run's own seed derivation is not in the run's set");
    // and a RUN's block prover makes no generator of its own (the check's
    // B-9.2): the block profile's seed derivation is in a BLOCK's set and not
    // in a RUN's
    let block_seed = hash_domain::single_block_seed_input_len(&sh);
    assert!(hash_domain::full_at_shape(&sh).describe(block_seed).is_some(), "a block's set has no seed derivation");
    assert!(set.describe(block_seed).is_none(), "a run's set carries the BLOCK prover's seed derivation, which a run never makes");
    // the three registered runs all pass their own imposed set, which is
    // empty because all three are tagged
    for (p, sh, l) in every_run() {
        let st = run_statement(&sh, p, l);
        let lay = Layout::for_shape(&sh).expect("the run's block layout");
        let rows = st.boundary_spec(0).expect("the first boundary").commitment_rows();
        hash_domain::imposed_at_shape(&sh)
            .refuse(&[("A", lay.a_rows), ("H", lay.h_rows), ("M", M_ROWS), ("external endpoint", sh.endpoint_rows), ("internal boundary", rows)])
            .unwrap_or_else(|e| panic!("{p}: {e}"));
    }
    eprintln!("S25 W-4: a run's set carries D4, D7 and its own seed derivation, and not the block prover's");
}

// ---------------------------------------------------------------------------
// W-6 — the per-slot `pb-term` lengths, printed and RECORDED (ruling J-7)
// ---------------------------------------------------------------------------

/// **W-6, AS CHANGED BY RULING J-7.** The memo's claim B-8 asked whether any
/// slot's `pb-term` absorb really carries six terminals, because `48 + 7 +
/// 16·6 = 151` is exactly the internal boundary's spec-digest input. The
/// answer is YES, at every shape — and the ruling is **record it, do not
/// guard it**, because the pair is never live inside one profile.
///
/// What is printed and recorded here, from the real definitions:
///
/// * every shape's distinct per-slot terminal counts and the absorb length
///   each gives (`Shape::slot_terms`, which is
///   `a_sites[s] + h_sites[s] + (s >= SC_IO_IN)`);
/// * **slot 19 = `SC_TAB` has 3 + 3 terminals at every registered shape**, so
///   the 151-byte absorb exists everywhere, once per proof;
/// * 151 is the internal boundary's spec-digest input, and the two are NEVER
///   the same function inside one profile: a legacy profile has no internal
///   boundary at all, and at a tagged profile the absorb is `F_T` and the
///   digest `F_U`. That is asserted per profile, and it is why this is a
///   record and not a refusal;
/// * the within-function 295-byte coincidence the check found (B-7): at a
///   rung-G or rung-K4 run with `2 <= L <= 9` the RUN's `parameters` absorb
///   and a **15**-terminal `pb-term` absorb are both 295 bytes, in the same
///   function and the same execution, separated by the label literal and its
///   length prefix at a fixed offset. Deterministic, nothing broken.
#[test]
fn the_per_slot_terminal_absorb_lengths_are_printed_and_recorded_at_every_shape() {
    let absorb = |label: &str, data: usize| 48 + label.len() + data;
    for sh in every_shape() {
        let terms = sh.slot_terms();
        let (a, h) = sh.claim_sites();
        // the definition, re-derived rather than taken from the accessor
        for s in 0..N_SLOTS {
            assert_eq!(terms[s], a[s] + h[s] + usize::from(s >= SC_IO_IN), "{}: slot {s}'s terminal count is not a + h + (s >= SC_IO_IN)", sh.name);
        }
        assert_eq!((a[SC_TAB], h[SC_TAB]), (3, 3), "{}: slot 19 (SC_TAB) no longer has 3 + 3 claim sites", sh.name);
        assert!(SC_TAB < SC_IO_IN, "SC_TAB is no longer below SC_IO_IN, so slot 19's count gains the IO terminal");
        assert_eq!(terms[SC_TAB], 6, "{}: slot 19's terminal count", sh.name);
        assert_eq!(absorb("pb-term", 16 * terms[SC_TAB]), 151, "{}: the six-terminal absorb is not 151 bytes", sh.name);
        let mut distinct: Vec<usize> = terms.to_vec();
        distinct.sort_unstable();
        distinct.dedup();
        let lens: Vec<usize> = distinct.iter().map(|k| absorb("pb-term", 16 * k)).collect();
        assert!(distinct.contains(&6), "{}: no slot carries six terminals", sh.name);
        eprintln!("    {:<10} slot_terms {distinct:?} -> pb-term absorbs {lens:?}", sh.name);
    }
    // 151 IS the boundary spec digest's input, and the two never meet inside
    // one profile: this is the RECORD ruling J-7 asks for.
    assert_eq!(43 + 32 + 9 * 8 + 4, 151, "the internal boundary's spec digest input");
    let mut profiles: Vec<(String, Shape, Option<(&'static str, usize, RunStatement)>)> = every_shape().into_iter().map(|s| (s.profile.to_string(), s, None)).collect();
    for (p, sh, l) in every_run() {
        let st = run_statement(&sh, p, l);
        profiles.push((p.to_string(), sh, Some((p, l, st))));
    }
    for (name, sh, run) in &profiles {
        let kinds = kinds_of(sh, run.as_ref().map(|(p, l, st)| (*p, *l, st)));
        let at_151: Vec<&Kind> = kinds.iter().filter(|k| k.len == 151).collect();
        let mut funcs: Vec<&str> = at_151.iter().map(|k| k.func).collect();
        funcs.sort_unstable();
        funcs.dedup();
        assert_eq!(funcs.len(), at_151.len(), "{name}: two 151-byte inputs share a function: {at_151:?}");
        let has_absorb = at_151.iter().any(|k| k.what.contains("pb-term"));
        let has_digest = at_151.iter().any(|k| k.what.contains("boundary"));
        assert!(has_absorb, "{name}: the six-terminal absorb is missing");
        assert_eq!(has_digest, run.as_ref().map(|(_, l, _)| *l > 1).unwrap_or(false), "{name}: an internal boundary's digest exists exactly in a multi-block run");
        if has_digest {
            assert!(!sh.hashes_under_the_legacy_rule(), "{name}: a legacy profile has an internal boundary, and then 151 WOULD be a live pair");
        }
    }
    // THE 295-BYTE WITHIN-FUNCTION COINCIDENCE, at every development run.
    //
    // **STAGE 31 made this a two-case record instead of one.** The run's
    // `parameters` line carries the shape's axes IN DECIMAL
    // (`protocol::parameter_line`) plus `L`, the boundary row count and the
    // external row count (`run::parameter_line`), so its LENGTH is a
    // property of the shape. Three quantities move with `L` and nothing
    // else does: the boundary row count is `0` at `L = 1` and two digits
    // above it, and `L` itself gains a digit at 10. So every run profile's
    // absorb is `base` at `L = 1`, `base + 1` at `2 <= L <= 9` and
    // `base + 2` at `10 <= L <= 12` — asserted here as a curve rather than
    // as three literals.
    //
    // `base` is **294** at the three 96-wide development runs, so their
    // `base + 1` is exactly the 295 that a fifteen-terminal `pb-term`
    // absorb also produces: the coincidence this block records. `base` is
    // **298** at rung-C6, whose width (384), head dimension (32) and
    // endpoint rows (21) are each one decimal digit longer — so the
    // coincidence DOES NOT ARISE there at all, at any `L`. That is a
    // record, not a regression: the pair 295 / 295 is what ruling J-7 wants
    // separated, and this shape separates it by construction.
    let (mut narrow, mut wide) = (0usize, 0usize);
    for (p, sh, _) in every_run() {
        if p == RUN_PROFILE_M125 {
            continue;
        }
        let terms = sh.slot_terms();
        assert!(terms.contains(&15), "{p}: no slot carries fifteen terminals, so 295 has no partner");
        assert_eq!(absorb("pb-term", 16 * 15), 295, "a fifteen-terminal absorb is not 295 bytes");
        let mut hits: Vec<usize> = Vec::new();
        let mut lens: Vec<usize> = Vec::new();
        let mut rows_at: Vec<usize> = Vec::new();
        for l in 1..=12usize {
            let st = run_statement(&sh, p, l);
            let line = st.capture_header().expect("the run's header").parameter_line;
            let len = absorb("parameters", line.len());
            if len == 295 {
                hits.push(l);
            }
            lens.push(len);
            rows_at.push(if l > 1 { st.boundary_spec(0).expect("the run's first boundary").commitment_rows() } else { 0 });
        }
        let base = lens[0];
        // **STAGE 32 makes the curve fully derived.** Stage 31 wrote it as
        // `base / base + 1 / base + 2`, which silently assumed the boundary
        // row count is TWO decimal digits — true of every shape then
        // registered (9 or 21 rows, and `0` at `L = 1`). rung-W14 has NINE
        // boundary rows, one digit, so its line does not grow at all between
        // `L = 1` and `L = 2` and the old literal curve was wrong at it. The
        // honest statement is the one below: exactly two quantities of the
        // line move with `L` — the boundary row count (`0` at `L = 1`) and
        // `L` itself — so the absorb grows by their DECIMAL WIDTHS and by
        // nothing else.
        let digits = |v: usize| v.to_string().len();
        let want: Vec<usize> = (1..=12usize).map(|l| base + (digits(rows_at[l - 1]) - digits(0)) + (digits(l) - digits(1))).collect();
        assert_eq!(lens, want, "{p}: the parameters absorb is not the decimal width of the boundary row count plus that of L");
        if base == 294 {
            assert_eq!(hits, (2..=9).collect::<Vec<usize>>(), "{p}: the 295-byte parameters absorb is not exactly at 2 <= L <= 9");
            assert_eq!((lens[0], lens[11]), (294, 296), "{p}: the one- and twelve-block absorbs");
            narrow += 1;
        } else {
            // **STAGE 33 records a third wide run, rung-E32 at 299**, and its
            // two extra bytes over rung-W14's 297 are exactly locatable: the
            // ENDPOINT ROW COUNT appears TWICE in a run's parameter line —
            // once as the block's `endpoint-…-rows` and once as the run's
            // `external-rows` — and 37 is one decimal digit longer than
            // rung-W14's 9 in both places. Every other field is the same
            // width (`T32` against `T64`, `log_cols10` against `log_cols14`,
            // the same width, hidden and head axis), so the difference is
            // that one number, counted twice.
            assert!([297, 298, 299].contains(&base), "{p}: an unrecorded parameter-line length {base}; this test knows 294 (the 96-wide runs), 297 (rung-W14), 298 (rung-C6) and 299 (rung-E32)");
            assert!(hits.is_empty(), "{p}: a 295-byte parameters absorb appeared at a shape whose base is {base}: {hits:?}");
            wide += 1;
        }
        eprintln!("    {p}: parameters absorb {base} at L = 1, boundary rows {}, span {:?}; 295 collisions at L = {hits:?}", rows_at[1], (lens[0], lens[11]));
    }
    // every registered run but 125M's (stage 31: four of them, three narrow
    // and one wide; stage 32: five, three and two; stage 33: six, three and
    // three), derived from the registry and never a literal
    assert_eq!(narrow + wide, every_run().len() - 1, "the 295-byte coincidence was checked at fewer than every development run");
    assert_eq!((narrow, wide), (3, 3), "the split between the runs that CAN collide at 295 and those that cannot moved");
    // and what separates them, at a fixed offset inside the input
    let a = [&(10u64).to_le_bytes()[..], b"parameters"].concat();
    let b = [&(7u64).to_le_bytes()[..], b"pb-term"].concat();
    assert_ne!(a[..8], b[..8], "the two labels' length prefixes are equal");
    assert_ne!(a, b, "the two label literals do not differ");
    eprintln!("S25 W-6: slot 19 carries six terminals at every shape (151 B, = the boundary spec digest's input, never in one function inside one profile); the 295-byte `parameters`/`pb-term`(15) pair is live at {narrow} of the {} development runs for 2 <= L <= 9 and cannot arise at the other {wide} (rung-C6's parameter line is four bytes longer than the 96-wide runs', rung-W14's three, rung-E32's five — its 37-row endpoint is written twice)", narrow + wide);
}

// ---------------------------------------------------------------------------
// W-7 — stage 24's twelve-key test still covers every tagged profile
// ---------------------------------------------------------------------------

/// **W-7 — ALREADY DONE IN STAGE 24, confirmed and cited.** The work list
/// asks for "the twelve-key pairwise distinctness test of ruling H-4". It is
/// `s24_tests::every_registered_profile_is_covered_and_every_tagged_ones_keys_
/// are_pairwise_distinct`, which reads the profile registry OUT OF THE SOURCE
/// and so cannot go stale. Nothing is added here; what is checked is that the
/// coverage still holds after this stage's registry read, and the test is
/// cited by name so the work list's row has an answer.
#[test]
fn stage_24s_twelve_key_test_still_covers_every_tagged_profile() {
    use zkp_core::hashtag::HashTag;
    let cited = "every_registered_profile_is_covered_and_every_tagged_ones_keys_are_pairwise_distinct";
    assert!(source("src/private_block/s24_tests.rs").contains(&format!("fn {cited}()")), "stage 24's H-4 test is gone; W-7 has no owner");
    let mut in_source = profile_literals(&source("src/private_block/shape.rs"));
    in_source.extend(profile_literals(&source("src/private_block/run.rs")));
    in_source.sort();
    in_source.dedup();
    let mut keys: Vec<[u8; 32]> = Vec::new();
    let (mut legacy, mut tagged) = (0usize, 0usize);
    let mut all_shapes = every_shape();
    all_shapes.extend(super::trained_calib_tests::registered_trained_shapes());
    all_shapes.extend(super::accuracy_profile_tests::registered_shapes());
    for sh in all_shapes.iter().cloned() {
        let t = sh.hash_tag();
        if sh.hashes_under_the_legacy_rule() {
            legacy += 1;
            assert!(t.is_legacy(), "{}: a legacy-rule profile carries a tag", sh.name);
            continue;
        }
        tagged += 1;
        assert_eq!(t, HashTag::for_profile(sh.profile), "{}: the tag is not a function of the profile string", sh.name);
        for k in [t.transcript_key(), t.column_key(), t.leaf_key(), t.node_key()] {
            keys.push(*k.expect("a tagged profile carries all four keys"));
        }
    }
    assert_eq!(legacy, 2, "the two legacy-rule profiles are the frozen toy and the frozen-seam rung, and there are no others");
    assert_eq!(tagged, all_shapes.len() - legacy, "the registry's legacy / tagged split moved");
    // STAGE 30: four keys per tagged block profile, DERIVED from the
    // registry. It was the literal 12 while there were three tagged
    // profiles; a sixth shape made it 16, and a literal here would have
    // said only that the number moved.
    assert_eq!(keys.len(), 4 * tagged, "a tagged profile did not produce four keys");
    for i in 0..keys.len() {
        for j in i + 1..keys.len() {
            assert_ne!(keys[i], keys[j], "two of the live keys collide");
        }
    }
    assert_eq!(in_source.len(), all_shapes.len() + every_run().len() + super::trained_calib_tests::registered_trained_runs().len(), "the source registry holds a profile this test does not measure (or vice versa)");
    eprintln!(
        "S25 W-7: {} profiles in the registry, {legacy} legacy, {tagged} tagged, {} live keys pairwise distinct — covered by s24_tests::{cited}",
        in_source.len(),
        keys.len()
    );
}

// ---------------------------------------------------------------------------
// W-8 — assertions 5 and 7 of the memo's §3.1 (the two with no hook)
// ---------------------------------------------------------------------------

/// Every production source of this module, plus the parent, plus the one
/// file outside it that the block's endpoints go through. The list is PARSED
/// from `private_block.rs`'s own `mod` lines (a `#[cfg(test)]` module is a
/// test module), so a production module added tomorrow is scanned without
/// anybody remembering to add it.
fn production_sources() -> Vec<(String, String)> {
    let parent = source("src/private_block.rs");
    let lines: Vec<&str> = parent.lines().collect();
    let mut out: Vec<(String, String)> = Vec::new();
    for (i, l) in lines.iter().enumerate() {
        let Some(rest) = l.trim().strip_prefix("mod ").or_else(|| l.trim().strip_prefix("pub mod ")) else { continue };
        let Some(name) = rest.strip_suffix(';') else { continue };
        if i > 0 && lines[i - 1].trim() == "#[cfg(test)]" {
            continue;
        }
        let path = format!("src/private_block/{name}.rs");
        let text = source(&path);
        out.push((path, text));
    }
    out.push(("src/private_block.rs".to_string(), parent));
    // R12b's public wrapper has one production child. Scan it too, and fail
    // closed if another child is added without extending this enumeration.
    let tied=source("src/private_block/tied_tables.rs");
    let children=tied.lines().take_while(|line| line.trim()!="#[cfg(test)]")
        .filter_map(|line| line.trim().strip_prefix("mod ").or_else(|| line.trim().strip_prefix("pub mod ")))
        .collect::<Vec<_>>();
    assert_eq!(children,vec!["derive;"],"the tied-table production module enumeration moved");
    out.push(("src/private_block/tied_tables/derive.rs".to_string(),source("src/private_block/tied_tables/derive.rs")));
    for (parent,child) in [("trained_block.rs","trained_accuracy.rs"),("witness.rs","witness_accuracy.rs"),("argument.rs","argument_accuracy.rs")] {
        let text=source(&format!("src/private_block/{parent}"));
        assert!(text.contains(&format!(r#"#[path = "{child}"]"#)),"{parent}: accuracy child path changed");
        let declarations=text.lines().filter_map(|line| line.trim().strip_prefix("mod "))
            .filter(|rest| rest.ends_with(';')).collect::<Vec<_>>();
        assert_eq!(declarations,vec!["accuracy;"],"{parent}: production child enumeration changed");
        out.push((format!("src/private_block/{child}"),source(&format!("src/private_block/{child}"))));
    }

    // the frozen seam is the toy's and the frozen-seam rung's endpoint and is
    // therefore on the block's path, although it lives outside this module
    // and outside this lane's write set
    out.push(("src/private_seam.rs".to_string(), source("src/private_seam.rs")));
    out
}

/// The part of a source file above its own `#[cfg(test)] mod tests {` — the
/// production text. Every scan below is over this and never over a test.
fn production_text(src: &str) -> &str {
    let cut = src.find("\n#[cfg(test)]\nmod tests {").map(|k| k + 1).unwrap_or(src.len());
    &src[..cut]
}

/// **W-8, ASSERTION 7 of the memo's §3.1 — "the key is fresh".** This is the
/// accepted toy statement's **condition 6** (*"Fresh operating-system
/// randomness per proof; no seeded configuration on this profile's path"*)
/// turned into a test, and ruling J-5 puts it on the lane because it needs no
/// accessor: it is a source scan and a reachability assertion.
///
/// **Why it is needed.** `ZkRng::new(seed, domain)`
/// (`zkp-core/src/rng.rs:20`) is a deterministic fixture generator, and it is
/// reachable through `ZkConfig::rng` (`hashline/src/zk.rs:334-340`) whenever
/// `ZkConfig.seed` is `Some`. A deterministically seeded generator IS one
/// generator, is never cloned, has perfect offsets, and would pass every
/// position-level assertion of the owed draw-accounting test while making
/// every proof of every witness identical. Nothing in those assertions looks
/// at where the key came from.
///
/// **What is asserted.**
///
/// 1. Every `ZkRng::` CONSTRUCTOR call in the production text of every
///    production module of this path is `from_os` — the block prover's
///    (`protocol.rs`), the run's (`run.rs`), the generalised endpoint's
///    (`endpoint_g.rs`) and the frozen seam's (`private_seam.rs`); everything
///    else that names `ZkRng` names the TYPE, in a `&mut ZkRng` parameter or
///    a `use`.
/// 2. **`ZkRng::new` appears nowhere on the path**, and neither does
///    `ZkConfig` in any form — so `zk.rs:336`'s seeded branch is not
///    reachable from `prove_inner_at`, `prove_run`, `endpoint_g::prepare`,
///    `boundary::prepare` or `private_seam::prepare`: none of them mentions
///    the type that owns the branch, and a call chain cannot pass through a
///    file that never names it.
/// 3. `boundary::prepare` makes NO generator: it takes `&mut ZkRng` from the
///    caller, which is the run's one stream (the memo's A-20 item 2).
/// 4. **NON-VACUITY**, in test code alone: the scan finds the four real
///    constructor calls, and a synthetic line with `ZkRng::new` is rejected by
///    the same classifier.
#[test]
fn no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system() {
    /// every `ZkRng::<something>` in a text, with the member it names
    fn zkrng_members(text: &str) -> Vec<String> {
        let mut out = Vec::new();
        for line in text.lines() {
            // a doc comment that NAMES `ZkRng::refill` is prose, not a call
            let t = line.trim_start();
            if t.starts_with("//") || (t.starts_with('*') && (t.len() < 2 || t.as_bytes()[1] == b' ' || t.as_bytes()[1] == b'/')) {
                continue;
            }
            let mut rest = line;
            while let Some(i) = rest.find("ZkRng::") {
                let after = &rest[i + "ZkRng::".len()..];
                let end = after.find(|c: char| !(c.is_ascii_alphanumeric() || c == '_')).unwrap_or(after.len());
                out.push(after[..end].to_string());
                rest = &after[end..];
            }
        }
        out
    }
    let mut from_os_sites: Vec<String> = Vec::new();
    for (path, src) in production_sources() {
        let text = production_text(&src);
        for m in zkrng_members(text) {
            assert_eq!(m, "from_os", "{path}: the path constructs a generator with `ZkRng::{m}`, which is not the operating system's");
        }
        for (n, line) in text.lines().enumerate() {
            let t = line.trim_start();
            if t.starts_with("//") || t.starts_with('*') {
                continue;
            }
            if line.contains("ZkRng::from_os") {
                from_os_sites.push(format!("{path}:{}", n + 1));
            }
            assert!(!line.contains("ZkConfig"), "{path}:{}: the path names ZkConfig, whose `rng` method reaches the seeded constructor", n + 1);
        }
    }
    // THE GENERATOR SITES, and the one the memo's A-6 does not list.
    // A-6 names four: `protocol.rs:486` (the block prover), `run.rs:516`
    // (the run), `endpoint_g.rs:224` (the generalised endpoint) and
    // `private_seam.rs:196` (the frozen seam's `prepare`). The scan finds a
    // FIFTH, `private_seam.rs:349`, inside `private_seam::prove` — the
    // experimental standalone seam proof, which is NOT on this path: the
    // private block reaches the seam through `private_seam::prepare` alone
    // (`private_block.rs:776`) and no production file of this path names
    // `private_seam::prove`. That is checked here, not assumed.
    assert_eq!(from_os_sites.len(), 5, "the scan's generator constructions moved: {from_os_sites:?}");
    for want in ["protocol.rs", "run.rs", "endpoint_g.rs", "private_seam.rs"] {
        assert!(from_os_sites.iter().any(|s| s.contains(want)), "{want} no longer constructs a generator; the enumeration has moved");
    }
    assert_eq!(from_os_sites.iter().filter(|s| s.starts_with("src/private_seam.rs")).count(), 2, "the frozen seam's two generator sites moved");
    for (path, src) in production_sources() {
        if path == "src/private_seam.rs" {
            continue;
        }
        assert!(
            !production_text(&src).contains("private_seam::prove"),
            "{path} reaches `private_seam::prove`, so its generator is on this path too and A-6's enumeration of four is short by one"
        );
    }
    let on_path: Vec<&String> = from_os_sites.iter().filter(|s| s.as_str() != "src/private_seam.rs:349").collect();
    assert_eq!(on_path.len(), 4, "the path's generators are no longer four: {on_path:?}");
    // `boundary::prepare` takes the caller's stream and makes none
    let boundary = source("src/private_block/boundary.rs");
    let btext = production_text(&boundary);
    assert!(btext.contains("rng: &mut ZkRng"), "boundary::prepare no longer takes the caller's generator");
    assert!(!btext.contains("ZkRng::from_os"), "boundary::prepare now makes its own generator; a run would have two streams");
    // and the seeded constructor really is the thing being excluded
    let rng_src = source("../zkp-core/src/rng.rs");
    assert!(rng_src.contains("pub fn new(seed: u64, domain: &[u8]) -> ZkRng"), "ZkRng::new is gone; this test guards nothing");
    let zk_src = source("src/zk.rs");
    assert!(zk_src.contains("Some(seed) => ZkRng::new(seed, domain),"), "ZkConfig::rng's seeded branch moved; the reachability claim must be re-read");
    // NON-VACUITY: the classifier rejects a seeded construction
    assert_eq!(zkrng_members("    let mut rng = ZkRng::new(7, b\"x\");"), vec!["new".to_string()], "the scan does not see a seeded construction");
    assert_eq!(zkrng_members("fn f(rng: &mut ZkRng) {}"), Vec::<String>::new(), "the scan mistakes a type mention for a construction");
    eprintln!("S25 W-8(7): the path's four generators are all `ZkRng::from_os` ({on_path:?}); a fifth site, src/private_seam.rs:349 in `private_seam::prove`, is off this path and no file on it names that function; no production file names ZkConfig");
}

/// **W-8, ASSERTION 5 of the memo's §3.1** — *"the generator is never cloned,
/// forked or serialised, and `prove_run` constructs exactly one"* (ruling
/// R-2's condition, which until now was a READING of `run.rs:510`).
///
/// Two independent halves:
///
/// * **A TYPE-LEVEL fact.** `ZkRng` implements no `Clone` and no `Copy`, so
///   "never cloned" is not a discipline anybody has to keep — it does not
///   compile. The probe below is the inherent-impl trick (an inherent method
///   whose impl requires `T: Clone`, with a blanket trait method as the
///   fallback), and it carries its own two controls so that a probe that
///   stopped working would say so instead of passing vacuously.
/// * **A SOURCE fact.** Each of the two provers constructs exactly one
///   generator, counted inside its own function body: `prove_run`
///   (`run.rs`) and `prove_inner_at` (`protocol.rs`). Neither body contains a
///   second construction, a `.clone()` of the generator, or a serialisation
///   of it; the stage loop takes `&mut rng`.
#[test]
fn the_generator_is_never_cloned_and_each_prover_constructs_exactly_one() {
    use crate::zk::ZkRng;
    use std::marker::PhantomData;
    struct Probe<T>(PhantomData<T>);
    trait NotCloneFallback {
        fn is_clone(&self) -> bool {
            false
        }
    }
    impl<T> NotCloneFallback for Probe<T> {}
    impl<T: Clone> Probe<T> {
        fn is_clone(&self) -> bool {
            true
        }
    }
    struct NeverClone;
    // the two controls first: the probe answers YES for a Clone type and NO
    // for one that is not, so its answer for `ZkRng` means something
    assert!(Probe::<u64>(PhantomData).is_clone(), "the Clone probe cannot see Clone; it proves nothing about ZkRng");
    assert!(!Probe::<NeverClone>(PhantomData).is_clone(), "the Clone probe answers yes for a non-Clone type");
    assert!(!Probe::<ZkRng>(PhantomData).is_clone(), "ZkRng is Clone: the generator can be forked and assertion 5 is false");

    // the source half: no derive, no impl, no serialisation
    let rng = production_text(&source("../zkp-core/src/rng.rs")).to_string();
    for forbidden in ["impl Clone for ZkRng", "derive(Clone", "derive(Copy", "Serialize", "Deserialize"] {
        assert!(!rng.contains(forbidden), "zkp-core/src/rng.rs carries `{forbidden}`");
    }
    // exactly one construction per prover, counted inside the function body
    for (path, signature, what) in [
        // ROUND 4: `prove_run` delegates to `prove_run_with` (the blocks from a
        // `BlockSource`), which is where the run's ONE generator is made
        ("src/private_block/run.rs", "pub(crate) fn prove_run_with(", "prove_run_with"),
        ("src/private_block/protocol.rs", "pub(crate) fn prove_inner_at(", "prove_inner_at"),
    ] {
        let src = source(path);
        let start = src.find(signature).unwrap_or_else(|| panic!("{path}: `{signature}` is gone"));
        let body = &src[start..];
        // to the next item at column zero, which is the end of this function
        let end = body[1..].find("\n}\n").map(|i| i + 2).unwrap_or(body.len());
        let body = &body[..end];
        assert_eq!(body.matches("ZkRng::from_os").count(), 1, "{what} does not construct exactly one generator");
        assert_eq!(body.matches("ZkRng::new").count(), 0, "{what} constructs a seeded generator");
        assert_eq!(body.matches("rng.clone()").count(), 0, "{what} clones its generator");
        assert!(body.contains("&mut rng"), "{what} does not hand its one generator on by mutable reference");
    }
    eprintln!("S25 W-8(5): ZkRng implements neither Clone nor Copy (type-level, with controls); prove_run and prove_inner_at construct exactly one generator each and pass it on by &mut");
}

/// **What W-8 still OWES, and to whom** — so that the work list's row is not
/// read as closed. Assertions 1–4 and 6 of the memo's §3.1 need a
/// consumption accessor on `ZkRng` (`counter·8192 + pos`), which is
/// `zkp-core/src/rng.rs` and another engineer's file; the request went out on
/// 2026-09-21 03:25. This test records the blockage AS A FACT of the code —
/// the fields are private and there is no accessor — so that the day one
/// lands, this test fails and the four assertions get written.
#[test]
fn the_draw_accounting_assertions_are_still_blocked_on_the_generators_accessor() {
    let rng = source("../zkp-core/src/rng.rs");
    assert!(rng.contains("pub struct ZkRng {\n    key: [u8; 32],\n    counter: u64,\n    buf: Vec<u8>,\n    pos: usize,\n}"), "ZkRng's fields moved; re-read what is observable before trusting this");
    for accessor in ["pub fn consumed", "pub fn pos(", "pub fn counter(", "pub(crate) fn consumed"] {
        assert!(!rng.contains(accessor), "the integrator's consumption accessor (`{accessor}`) has landed: assertions 1-4 and 6 of the memo's §3.1 are no longer blocked and are owed on this lane");
    }
    eprintln!("S25 W-8: assertions 1-4 and 6 remain BLOCKED — `ZkRng`'s four fields are private and it publishes no consumption accessor (requested of the integrator 2026-09-21 03:25)");
}

// ---------------------------------------------------------------------------
// W-11 — the source scan, from absorb LABELS to hash CALL SITES
// ---------------------------------------------------------------------------

/// **THE CALL-KIND TABLE (W-11).** Every BLAKE3 or SHA-256 entry point in the
/// lane's own sources, with the call kind of the memo's §5 it belongs to. The
/// key is `(file, entry point, how many times)` rather than a line number, so
/// that the table does not rot every time a comment moves — and so that a
/// NEW call site changes a count and fails this test until somebody
/// classifies it.
///
/// The scanned set is the production modules (parsed from `private_block.rs`,
/// so a new one is scanned automatically), the parent module, the frozen seam
/// — and the three `cfg(test)` modules that WRITE a retained bundle, because
/// a retained capture counts as publishing and its digests are call sites
/// like any other.
const CALL_SITES: [(&str, &str, usize, &str); 16] = [
    // NATIVE LANE: the trained-block CLI's request context, an unkeyed hash of
    // public words (variant, label, layer); its file digests are SHA-256 via
    // `Sha256::digest`, not an entry point of this table
    ("src/private_block/trained_block.rs", "blake3::hash(", 2, "driver-side, outside the protocol: the trained-block CLI's and the trained-stack CLI's request contexts, unkeyed hashes of public length-prefixed words (variant, label, layer indices)"),
    // R12b moves bounded public-file hashing out of trained_block.rs and
    // authenticates/recomputes the tied tables. These SHA-256 operations
    // share no oracle with BLAKE3 and consume no private witness value.
    ("src/private_block/tied_tables.rs", "Sha256::new(", 1, "C1 — bounded public token-file SHA-256, checked against the manifest and checkpoint derivation; its public digest is bound through D9"),
    ("src/private_block/tied_tables/derive.rs", "Sha256::new(", 5, "C1 — public checkpoint authentication, consumed tied-tensor bytes, derived embedding, head and multiplier table SHA-256; public digests bound through D9, outside the proof's BLAKE3 oracle classes"),
    // NATIVE LANE: the driver overlay's CLI bridge (pre-existing in the
    // candidate; this table had not been told about it): D4 recomputed to
    // check a policy's model root, the CLI's context derivation, and an
    // in-process seal check of the output plane that never leaves the process
    // and enters no transcript or commitment
    ("src/private_block/mvp_driver.rs", "blake3::Hasher::new(", 3, "driver-side, outside the protocol: the run's public-statement digest D4 recomputed (model root), the CLI's context derivation, and an in-process seal-check digest that is compared and dropped"),
    // NATIVE LANE (from the lane-C prototype): the trained-model statement's
    // identity, which a bound run absorbs as its `"calibration"` word
    ("src/private_block/trained_statement.rs", "blake3::Hasher::new(", 1, "D9 — the trained-model statement identity, unkeyed, over a 47-byte versioned domain literal and the length-prefixed statement fields"),
    ("src/private_block.rs", "blake3::hash(", 1, "D1 — the calibration identity, an unkeyed hash of a 30-byte public literal"),
    ("src/private_block.rs", "blake3::Hasher::new(", 1, "D2 — the block's public/weights digest, unkeyed, over a 31-byte literal and the framed public tensors"),
    ("src/private_block/layout.rs", "blake3::Hasher::new(", 1, "D3 — the block's schedule digest, unkeyed, over a 33-byte literal and the framed description lines"),
    ("src/private_block/run.rs", "blake3::Hasher::new(", 2, "D4 and D5 — the run's public statement digest and its schedule digest, both unkeyed"),
    ("src/private_block/endpoint_g.rs", "blake3::Hasher::new(", 1, "D6 — the generalised endpoint's spec digest, unkeyed, 142 bytes"),
    ("src/private_block/boundary.rs", "blake3::Hasher::new(", 1, "D7 — the internal boundary's spec digest, unkeyed, 151 bytes"),
    ("src/private_seam.rs", "blake3::Hasher::new(", 1, "D8 — the frozen seam's spec digest, unkeyed, 128 bytes"),
    ("src/private_block/run_sink.rs", "sha256_hex(", 1, "C1 — a segment file's digest. SHA-256 (`sha2`), NOT BLAKE3: it shares no oracle with anything above"),
    // STAGE 27 added the sixth: `ArrayStore::put`'s CONTENT digest, which
    // both names an array in `arrays.bin` and is the key the store
    // deduplicates on. Same kind as the other five — SHA-256 (`sha2`) over
    // bytes the bundle publishes anyway, sharing no oracle with any BLAKE3
    // call above, and deciding no proof byte and no challenge.
    ("src/private_block/run_capture.rs", "sha256_hex(", 6, "C1 — the capture writer's file, public-word and array-store content digests, SHA-256"),
    ("src/private_block/run_statement_file.rs", "sha256_hex(", 5, "C1 — the retained run statement's file digests, SHA-256"),
    ("src/private_block/plane_index.rs", "sha256_hex(", 0, "no hash of its own: the plane index table is public layout data the capture writer digests"),
];

/// Hash entry points the scan looks for. Anything matched must be classified
/// by [`CALL_SITES`]; anything not in this list is not a hash call at all.
const ENTRY_POINTS: [&str; 13] = [
    "blake3::hash(",
    "blake3::Hasher::new(",
    "blake3::Hasher::new_keyed(",
    "blake3::Hasher::new_derive_key(",
    "blake3::derive_key(",
    "blake3::keyed_hash(",
    "finalize_xof(",
    "hashtag::hasher(",
    "hash_pair(",
    "hash_columns(",
    "salt_leaf(",
    "Sha256::new(",
    "sha256_hex(",
];

/// **THE OTHER ENGINEER'S FILES, READ-ONLY** — the call kinds of the memo's
/// §5 that live outside this lane's write set, with the `file:line` the memo
/// records at `8c5922b`. They are NOT scanned: those files may change under
/// integration and a count pinned here would fail for reasons this lane
/// cannot fix. They are listed so that the table is an enumeration of the
/// PATH and not only of the lane.
const READ_ONLY_SITES: [(&str, &str); 14] = [
    ("zkp-core/src/transcript.rs:30", "T1 — the transcript constructor, legacy (unkeyed)"),
    ("zkp-core/src/transcript.rs:41", "T2 — the transcript constructor, tagged (keyed)"),
    ("zkp-core/src/transcript.rs:61", "T3 — a transcript absorb, state ‖ label ‖ data"),
    ("zkp-core/src/transcript.rs:103", "T4a — a transcript squeeze, 47 bytes"),
    ("zkp-core/src/transcript.rs:156-162", "T4b/T4c — `clone_state`, which the position tag and the refusal replay squeeze from"),
    ("zkp-core/src/pcs.rs:139, :149", "P1 — a column digest, single (verify side)"),
    ("zkp-core/src/pcs.rs:171, :196", "P2 — column digests, bulk (commit side)"),
    ("zkp-core/src/pcs.rs:678, :692", "P3 — a salted leaf, blake3(column digest ‖ salt)"),
    ("zkp-core/src/merkle.rs:15, :28", "P4 — a Merkle inner node, blake3(left ‖ right)"),
    ("hashline/src/zk.rs:689, :697", "P5 — the M commitment's column digest"),
    ("zkp-core/src/rng.rs:47", "R1 — the generator's seed derivation (keyed under 32 raw /dev/urandom bytes)"),
    ("zkp-core/src/rng.rs:54", "R2 — the generator's refill, unkeyed, XOF"),
    ("zkp-core/src/hashtag.rs:95-98", "K — the four tag keys, BLAKE3's derive_key mode"),
    ("hashline/src/gpu/kernels.cu:512, :1429", "G1/G2 — the two hand-written CUDA BLAKE3 column kernels (ruling J-3: outside the accepted toy statement's scope; agreement pinned by the differential probe `dev_hash_check`, cuda.rs:2783, and the proof-byte parity gates, NOT by the domain argument)"),
];

/// **W-11 (the check's B-17, ruling J-7; GAP-QC-1's test).**
///
/// `every_absorb_label_on_the_path_is_in_the_table` scans the lane's sources
/// for absorb LABELS. It says nothing about a hash that is not a transcript
/// absorb — and §5.3 of the memo found six in-process hash sites that were in
/// neither the call-kind table nor the "checked clean" list, three of them
/// unkeyed BLAKE3 reachable from a constructor that is not `#[cfg(test)]`.
/// The enumeration must be done by a tool.
///
/// **What this asserts.** Every hash ENTRY POINT in the production text of
/// every scanned file is accounted for by [`CALL_SITES`], per file and per
/// entry point, with its call kind written beside it; and every row of the
/// table is really in the source. A new hash call site changes a count and
/// fails here until it is classified.
///
/// **What it cannot see, said plainly.** (i) A call through a helper in a
/// file it does not scan — the read-only list above is prose, not a
/// measurement. (ii) Anything inside a `#[cfg(test)] mod tests` block of a
/// scanned file: test fixtures hash public literals for contexts and pinning
/// them here would make every new test edit this table. (iii) The CUDA
/// kernels, which are not Rust and are ruling J-3's, on the GPU lane's side
/// (W-9).
#[test]
fn every_hash_call_site_in_the_lanes_own_sources_is_classified() {
    /// is the match at `idx` inside a string literal on this line?
    fn in_string(line: &str, idx: usize) -> bool {
        let b = line.as_bytes();
        let (mut i, mut q) = (0usize, 0usize);
        while i < idx {
            match b[i] {
                b'\\' => i += 1,
                b'"' => q += 1,
                _ => {}
            }
            i += 1;
        }
        q % 2 == 1
    }
    fn count_sites(text: &str, pat: &str) -> usize {
        let mut n = 0usize;
        for line in text.lines() {
            let t = line.trim_start();
            if t.starts_with("//") || (t.starts_with('*') && (t.len() < 2 || t.as_bytes()[1] == b' ' || t.as_bytes()[1] == b'/')) {
                continue;
            }
            let mut from = 0usize;
            while let Some(i) = line[from..].find(pat) {
                let at = from + i;
                if !in_string(line, at) {
                    n += 1;
                }
                from = at + pat.len();
            }
        }
        n
    }

    let mut scanned: Vec<(String, String)> = production_sources();
    for extra in ["src/private_block/run_capture.rs", "src/private_block/run_statement_file.rs", "src/private_block/plane_index.rs"] {
        scanned.push((extra.to_string(), source(extra)));
    }
    let mut found = 0usize;
    let mut classified = 0usize;
    for (path, src) in &scanned {
        let text = production_text(src);
        for pat in ENTRY_POINTS {
            let n = count_sites(text, pat);
            let want = CALL_SITES.iter().find(|(f, p, _, _)| f == path && *p == pat).map(|(_, _, c, _)| *c).unwrap_or(0);
            assert_eq!(
                n, want,
                "{path}: {n} call(s) of `{pat}` and the stage-25 call-kind table declares {want}. A new hash call site must be classified in CALL_SITES with its kind from the memo's §5 before this test passes."
            );
            found += n;
        }
    }
    // every row of the table is real, and every row has a reason
    for (path, pat, want, why) in CALL_SITES {
        assert!(scanned.iter().any(|(f, _)| f == path), "{path} is in the call-kind table and is not scanned");
        assert!(why.len() > 30, "{path}'s `{pat}` row has no call kind: {why}");
        classified += want;
    }
    assert_eq!(found, classified, "the scan and the table disagree on how many sites there are");
    assert!(found >= 18, "the call-site scan found only {found} sites; it has stopped working");
    // the read-only half is an enumeration and is not scanned
    assert_eq!(READ_ONLY_SITES.len(), 14, "the read-only call-kind list moved");
    for (site, kind) in READ_ONLY_SITES {
        assert!(site.contains(':'), "a read-only entry carries no file:line: {site}");
        assert!(kind.len() > 20, "a read-only entry carries no kind: {site}");
    }
    // NON-VACUITY, in test code alone: the scanner sees a real call, skips a
    // comment and skips a string literal
    assert_eq!(count_sites("    let h = blake3::Hasher::new();", "blake3::Hasher::new("), 1);
    assert_eq!(count_sites("    // let h = blake3::Hasher::new();", "blake3::Hasher::new("), 0);
    assert_eq!(count_sites("    let s = \"the unkeyed blake3::Hasher::new()\";", "blake3::Hasher::new("), 0);
    // and the LABEL scan it extends is still there
    assert!(
        source("src/private_block/hash_domain_tests.rs").contains("fn every_absorb_label_on_the_path_is_in_the_table()"),
        "the absorb-label scan this test extends is gone"
    );
    eprintln!("S25 W-11: {found} hash call sites in {} scanned lane sources, every one classified; {} read-only sites listed with file:line", scanned.len(), READ_ONLY_SITES.len());
}
