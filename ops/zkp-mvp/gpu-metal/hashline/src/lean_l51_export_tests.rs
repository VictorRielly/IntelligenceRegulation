//! **D63 Lean lane L51 (2026-11-10): the classify run HEADER on a REAL classifier receipt.** TEST ONLY: a child of the
//! test-only `private_block/token_io/classify_capture_tests.rs` (declared there by one `#[cfg(test)]` line; the file
//! lives in `src/`, not `src/private_block/`, as lanes L10's, L18's and L29's do, so `s25_tests`' `TEST_ONLY_FILES`
//! needs no entry). No prover or verifier source changes; nothing here is reachable from a production build.
//!
//! What it does, on the development rung's classifier fixture (`classify_capture_tests::fx`, one block):
//! 1. proves an honest classifier run (`honest_run`) and verifies it with the production `verify_classify_run`;
//! 2. REBUILDS the run header (`ClassifyRunStatement::transcript`, classify.rs:1275-1291) from the public words the
//!    test-only capture header copies out of the statement (`capture_header`), absorb by absorb, in the source's order,
//!    on a fresh tagged transcript of the run profile, and ASSERTS that it ends on the production header's state (the
//!    run binding) and counter; the eight absorbs (label, data) are then the production header's;
//! 3. asserts the `expected-IO` absorb is `"classify-expected/v1" ‖ in_spec.digest() ‖ in_root` (classify.rs:1147-1153);
//! 4. decodes segment 0 (stage IN-C) at the binding, as the production verifier does, for the roots stage IN-C absorbs
//!    (`B_in`, `A`, `H`, `M`) and the embedding digest of its frame;
//! 5. writes the records to `LEAN_L51_CORPUS`, for `formal/ZK60Formal/RunAbsCheck.lean`, which rebuilds the header with
//!    the Lean model (`clsHdrOps`), replays it under BLAKE3 in Lean, and checks where the input root is absorbed.
//!
//! Every value is public: the fixture's public synthetic data, the statement's public words, the receipt's roots, the
//! transcript's states (no witness value, no mask, no RNG state is written).
use super::super::super::protocol;
use super::super::stage_in_c;
use super::{fx, honest_run, POLICY_93};
use crate::transcript::Transcript;
use std::fmt::Write as _;

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// `classify_run::position_tag`, replayed: two `challenge_fp2` of a clone.
fn tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

#[test]
fn lean_l51_export_the_classify_header() {
    let f = fx(1);
    let r = honest_run(&f, "1", None);
    let st = &r.st;
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    let segs = &r.segs;
    assert_eq!(segs.len(), l + 2, "a classifier run has L + 2 segments");
    super::super::classify_run::verify_classify_run(st, &f.blocks, &r.bound, segs, POLICY_93)
        .expect("the production verifier accepts the honest classifier run");
    // the production run header (the binding is its state)
    let prod = st.transcript().expect("the run header");
    let binding = prod.state();
    // the public words the test-only capture header copies out of the statement
    let h = st.capture_header().expect("the capture header");
    let cf = h.classify.as_ref().expect("a classifier run's capture facts");
    assert_eq!(cf.input_root, st.in_root(), "the capture's input root is the statement's");
    assert_eq!(cf.verdict, st.verdict(), "the capture's verdict is the statement's");
    let mut shape = Vec::with_capacity(8 * h.run_shape_words.len());
    for v in &h.run_shape_words {
        shape.extend_from_slice(&v.to_le_bytes());
    }
    let chunk: Vec<u8> = cf.chunk.iter().flat_map(|v| (*v as u64).to_le_bytes()).collect();
    // the eight absorbs of `ClassifyRunStatement::transcript`, in the source's order
    let items: Vec<(&[u8], Vec<u8>)> = vec![
        (&b"run-shape"[..], shape),
        (&b"expected-IO"[..], h.expected_bytes.clone()),
        (&b"public-statement"[..], h.public_statement.to_vec()),
        (&b"parameters"[..], h.parameter_line.as_bytes().to_vec()),
        (&b"calibration"[..], h.calibration.to_vec()),
        (&b"schedule"[..], h.schedule_digest.to_vec()),
        (&b"classify-verdict"[..], vec![cf.verdict]),
        (&b"classify-chunk"[..], chunk),
    ];
    let mut rt = protocol::tagged_transcript(sh, st.profile().as_bytes());
    let fresh = rt.state();
    for (lab, data) in &items {
        rt.absorb(lab, data);
    }
    assert_eq!(rt.state(), binding, "the header rebuilt from the capture's words ends on the production header's state");
    assert_eq!(rt.counter(), prod.counter(), "and on its squeeze counter");
    assert_eq!(rt.fs_key(), prod.fs_key(), "under the production header's Fiat-Shamir key");
    // the expected-IO absorb's structure (classify.rs:1147-1153)
    let want: Vec<u8> = [&b"classify-expected/v1"[..], &st.in_spec.digest()[..], &st.in_root()[..]].concat();
    assert_eq!(items[1].1, want, "expected-IO is the tag, the input endpoint spec's digest, the input root");
    // a negative control on the rebuild: one input-root byte changed moves the state
    let mut bad = want.clone();
    let last = bad.len() - 1;
    bad[last] ^= 1;
    let mut rb = protocol::tagged_transcript(sh, st.profile().as_bytes());
    for (i, (lab, data)) in items.iter().enumerate() {
        rb.absorb(lab, if i == 1 { &bad } else { data });
    }
    assert_ne!(rb.state(), binding, "a header with another input root is another binding");

    // stage IN-C's roots, decoded at the binding as the production verifier decodes segment 0
    let in_lay = stage_in_c::layout(sh, cp);
    let start = tag(&prod);
    let (seg, _end) = st.in_geom(&in_lay).decode(&segs[0], &binding, &start).expect("segment 0 decodes");
    let b_root = seg.b_root.expect("stage IN-C's segment carries B_in's root");

    let mut out = String::new();
    writeln!(out, "L51 HEADER {} L={l} segments={}", st.profile(), segs.len()).unwrap();
    writeln!(out, "KEY {}", prod.fs_key().map(|k| hex(&k)).unwrap_or_else(|| "-".into())).unwrap();
    writeln!(out, "DOMAIN {}", hex(st.profile().as_bytes())).unwrap();
    writeln!(out, "FRESH {}", hex(&fresh)).unwrap();
    writeln!(out, "BINDING {} {}", hex(&binding), prod.counter()).unwrap();
    writeln!(out, "INROOT {}", hex(&st.in_root())).unwrap();
    writeln!(out, "INSPECDIG {}", hex(&st.in_spec.digest())).unwrap();
    writeln!(out, "VERDICT {}", st.verdict()).unwrap();
    writeln!(out, "HDRN {}", items.len()).unwrap();
    for (i, (lab, data)) in items.iter().enumerate() {
        writeln!(out, "HDR {i} {} {}", hex(lab), hex(data)).unwrap();
    }
    writeln!(out, "INROOTS {} {} {} {}", hex(&b_root), hex(&seg.a_root), hex(&seg.h_root), hex(&seg.mask_root)).unwrap();
    writeln!(out, "INEMBDIG {}", hex(&cp.emb_digest)).unwrap();
    writeln!(out, "END").unwrap();
    eprintln!("LEAN-L51 | the classify run header rebuilt on the production binding (rung, L = {l}, verdict {}): corpus {} B", st.verdict(), out.len());
    if let Ok(path) = std::env::var("LEAN_L51_CORPUS") {
        std::fs::write(&path, &out).unwrap_or_else(|e| panic!("writing {path}: {e}"));
        eprintln!("LEAN-L51 | wrote {path}");
    }
}
