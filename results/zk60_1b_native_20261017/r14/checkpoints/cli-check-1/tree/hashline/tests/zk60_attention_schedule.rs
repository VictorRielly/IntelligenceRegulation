//! Bounded public P0 executed-schedule tests. No GPU, exports or private proof.
use hashline::attention_schedule::{Capture, Event, FixedReference, Trace};
use hashline::causal_oracle::public_synthetic_fixture;
use hashline::public_block_oracle::{verify_public_block, PublicBlockOracle};

#[test]
fn executed_fixed_a00_schedule_replays_and_preserves_public_proof_bytes() {
    assert!(
        std::env::var("HL_GPU").unwrap_or_default().is_empty(),
        "unset HL_GPU for this CPU gate"
    );
    assert!(
        std::env::var("HL_FOLD").unwrap_or_default().is_empty(),
        "default folding only"
    );
    assert!(
        std::env::var("HL_NO_FOLD").unwrap_or_default().is_empty(),
        "default folding only"
    );
    assert!(!hashline::attention::tamper_mode(), "honest gate only");
    let (approved, weights, input) = public_synthetic_fixture();
    let oracle = PublicBlockOracle::new(&approved, weights).unwrap();
    let off = Capture::begin(false).unwrap();
    let plain = oracle.prove(&input).unwrap();
    assert!(off.finish().events.is_empty());
    verify_public_block(&approved, &plain).unwrap();
    let capture = Capture::begin(true).unwrap();
    let profiled = oracle.prove(&input).unwrap();
    let proved = capture.finish();
    assert_eq!(plain.attention.to_bytes(), profiled.attention.to_bytes());
    assert_eq!(plain.ffn.to_bytes(), profiled.ffn.to_bytes());
    let capture = Capture::begin(true).unwrap();
    verify_public_block(&approved, &profiled).unwrap();
    let replayed = capture.finish();
    proved.shared().ensure_matches(&replayed.shared()).unwrap();
    proved
        .check_fixed_reference(FixedReference::PublicProve)
        .unwrap();
    replayed
        .check_fixed_reference(FixedReference::PublicReplay)
        .unwrap();
    proved
        .shared()
        .check_fixed_reference(FixedReference::Shared)
        .unwrap();
    assert_eq!(
        (
            proved.events.len(),
            replayed.events.len(),
            proved.shared().events.len()
        ),
        (593, 586, 562)
    );
    assert_eq!(proved.count("sumcheck"), 12);
    assert_eq!(proved.count("terms"), 12);
    assert_eq!(proved.count("seam"), 1); // both X/Z internal equalities, no cross-layer proof
    assert_eq!(proved.count("helper_build"), proved.count("helper_sum"));
    assert_eq!(replayed.count("helper_build"), 0);
    assert_eq!(
        proved.count("take"),
        proved.count("claim_A")
            + proved.count("claim_W")
            + proved.count("claim_H")
            + proved.count("helper_sum")
    );
    assert_eq!(replayed.count("check"), proved.count("check") + 12);
    assert!(proved.count("lookup") > 0 && proved.count("histogram_visit") > 0);
    assert!(proved.count("collapse_sumcheck") > 0);
    println!(
        "A01 PUBLIC METADATA prove={} replay={} shared={} counts={}/{}/{} proof_bytes={}",
        proved.fingerprint(),
        replayed.fingerprint(),
        proved.shared().fingerprint(),
        proved.events.len(),
        replayed.events.len(),
        proved.shared().events.len(),
        profiled.payload_size_bytes()
    );
    println!(
        "A01 COUNTS {:?}",
        [
            "claim_A",
            "claim_W",
            "claim_H",
            "helper_sum",
            "take",
            "check",
            "term",
            "lookup",
            "histogram_shape",
            "histogram_visit",
            "collapse_range",
            "collapse_sumcheck"
        ]
        .map(|k| (k, proved.count(k)))
    );
    // Optional LOCAL public-metadata evidence; no proof tensors/evaluations.
    if let Some(directory) = std::env::var_os("A01_TRACE_DIR") {
        let directory = std::path::PathBuf::from(directory);
        assert!(
            directory.is_dir(),
            "create a new local artifact directory first"
        );
        for (name, trace) in [
            ("prove", &proved),
            ("replay", &replayed),
            ("shared", &proved.shared()),
        ] {
            use std::io::Write;
            let mut file = std::fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(directory.join(format!("{name}.txt")))
                .unwrap();
            writeln!(
                file,
                "A01 metadata-only {} events {}\n{}",
                trace.events.len(),
                trace.fingerprint(),
                trace.listing()
            )
            .unwrap();
        }
    }

    // Exact comparison rejects malformed/missing/extra/reordered trace data.
    let mut wrong = proved.clone();
    wrong.events.pop();
    assert!(wrong.ensure_matches(&proved).is_err());
    let mut wrong = proved.clone();
    wrong.events.swap(0, 1);
    assert!(wrong.ensure_matches(&proved).is_err());
    let mut wrong = proved.clone();
    wrong.events.push(proved.events[0].clone());
    assert!(wrong.ensure_matches(&proved).is_err());
    let mut wrong = proved.clone();
    wrong
        .events
        .iter_mut()
        .find(|e| e.kind == "claim_A")
        .unwrap()
        .fields[1]
        .1 += 1;
    assert!(wrong.ensure_matches(&proved).is_err());
    assert!(wrong
        .check_fixed_reference(FixedReference::PublicProve)
        .is_err());
    let mut wrong = proved.clone();
    wrong.events[0].kind = "unknown";
    assert!(wrong.ensure_matches(&proved).is_err());
    assert!(Trace::default().ensure_matches(&Trace::default()).is_err());

    let mut truncated = profiled.clone();
    truncated.attention.vals.pop();
    let capture = Capture::begin(true).unwrap();
    assert!(verify_public_block(&approved, &truncated).is_err());
    assert!(capture.finish().ensure_matches(&replayed).is_err());
    let mut reordered = profiled.clone();
    reordered.attention.sc.swap(0, 1);
    assert!(verify_public_block(&approved, &reordered).is_err());
}

#[test]
fn cross_layer_hook_is_observed_with_synthetic_replay_not_a_two_layer_proof() {
    use hashline::attention::{attn_layout_of, layer_seam, Cc};
    use hashline::field::Fp2;
    use hashline::transcript::Transcript;
    let (approved, _, _) = public_synthetic_fixture();
    let r = approved.registration();
    let lay = attn_layout_of(&r.attention, &r.residual, r.params.log_cols);
    let point = vec![Fp2::ZERO; lay.log_d as usize];
    let mut prev = Cc::new(false, vec![Fp2::ZERO]);
    let mut next = Cc::new(false, vec![Fp2::ZERO]);
    let capture = Capture::begin(true).unwrap();
    layer_seam(
        &mut prev,
        &mut next,
        &mut Transcript::new(b"A01 synthetic seam"),
        &lay,
        &lay,
        None,
        None,
        &point,
    )
    .unwrap();
    let trace = capture.finish();
    assert_eq!(trace.count("seam"), 1);
    assert_eq!(trace.count("claim_A"), 2);
    assert_eq!(trace.count("take"), 2);
    assert_eq!(trace.count("check"), 1);
    assert!(trace.events.iter().all(|e| e.role == "cross-layer seam"));
    let mut prev = Cc::new(false, vec![Fp2::ONE]);
    let mut next = Cc::new(false, vec![Fp2::ZERO]);
    assert!(layer_seam(
        &mut prev,
        &mut next,
        &mut Transcript::new(b"A01 synthetic seam"),
        &lay,
        &lay,
        None,
        None,
        &point
    )
    .is_err());
}

#[test]
fn capture_lifetime_is_explicit_and_metadata_encoding_is_framed() {
    let capture = Capture::begin(true).unwrap();
    assert!(Capture::begin(true).is_err());
    assert!(Capture::begin(false).unwrap().finish().events.is_empty());
    drop(capture);
    assert!(Capture::begin(true).unwrap().finish().events.is_empty());
    let a = Trace {
        events: vec![Event {
            kind: "a",
            role: "bc",
            site: "x",
            fields: vec![("offset", 1)],
        }],
    };
    let b = Trace {
        events: vec![Event {
            kind: "ab",
            role: "c",
            site: "x",
            fields: vec![("offset", 1)],
        }],
    };
    assert_ne!(a.fingerprint(), b.fingerprint());
    assert!(a.listing().contains("offset"));
}

#[test]
fn source_hook_inventory_cannot_silently_lose_a_recorder_family() {
    // Conservative independent source drift alarm, not a semantic/security hash.
    // Even unrelated formatting requires explicit review and snapshot approval.
    let source = include_str!("../src/attention.rs");
    use sha2::Digest;
    assert_eq!(hashline::silu::hex(&sha2::Sha256::digest(source.as_bytes())),
        // Round12 R32: only unused-message refusal branches were added;
        // recorder calls, roles, sumchecks and fixed trace pins are unchanged.
        "c5ae80ddc909aae40b9ec6b9766e5634cf3dc13172e8902f8f2dc33c77cdf979",
        "attention source changed: review instrumentation/argument coverage before accepting a new snapshot");
    for family in [
        "take",
        "claim_A",
        "claim_W",
        "claim_H",
        "helper_sum",
        "helper_build",
        "terms",
        "term",
        "sumcheck",
        "histogram_visit",
        "collapse_range",
        "collapse_sumcheck",
        "opening_slice",
    ] {
        assert_eq!(
            source
                .matches(&format!("attention_schedule::record(\"{family}\""))
                .count(),
            1,
            "hook family {family}"
        );
    }
    assert_eq!(source.matches("ctx.sc(").count(), 12);
    assert_eq!(source.matches("attention_schedule::role(").count(), 19);
}
