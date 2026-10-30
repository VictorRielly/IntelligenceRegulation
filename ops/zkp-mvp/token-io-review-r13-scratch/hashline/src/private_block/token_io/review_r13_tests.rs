//! **REVIEW OF TOKEN ROUND 13 (R-C2): the reviewer's own attacks.** TEST CODE
//! ONLY, in the reviewer's scratch copy (`ops/zkp-mvp/token-io-review-r13-scratch`);
//! never part of a frozen tree. Public synthetic data (the development rung's
//! fixture `Cc`). Each test names the brief's item it covers. Digests marked
//! "reviewer reference" come from `results/zk60_token_io_review_r1_20261017/r13/
//! rv13_dev_tied_reference.json`, written without the lane's code.

use super::classify::*;
use super::classify_cli::{classify_input_owner_command, classify_label_command, classify_prove_command, classify_verify_command, load_export, read_classifier_files};
use super::classify_cli_tests::{policy_rung_dev_swapped, write_seq_files, Cc, POLICY_RUNG_DEV, POLICY_RUNG_DEV_SWAPPED};
use super::classify_tied::*;
use super::super::run_sink;
use super::super::tied_tables;
use super::super::trained_block::{hex, parse_json, sha256, TrainedExport, J};
use std::path::{Path, PathBuf};

const D: usize = 384;
/// reviewer reference digests (rv13_dev_tied_reference.json)
const REF_TENSOR: &str = "bba6d094831861aa0b207ae5ca46938e2115e02c81215ba95e27e2bad1cc1dd6";
const REF_EMB: &str = "c0e816c9f41a251df8560c5532d3f24c3b753ceb6ad712adcc7a893f71bfa475";
const REF_W: &str = "24e6ff4ca67bac45c810f78b72d967894b6806615206c5571842055ce20ef3c1";
const REF_W_SWAPPED: &str = "b4a059cd95f793398e92c334491e46878d7a155dc02a3ae79f0e7a4448a827d3";

fn s(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

fn sib(p: &Path, suffix: &str) -> PathBuf {
    let mut o = p.as_os_str().to_owned();
    o.push(suffix);
    PathBuf::from(o)
}

fn le(w: &[i16]) -> Vec<u8> {
    w.iter().flat_map(|x| x.to_le_bytes()).collect()
}

fn copy_dir(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for e in std::fs::read_dir(from).unwrap() {
        let e = e.unwrap();
        let (src, dst) = (e.path(), to.join(e.file_name()));
        if e.file_type().unwrap().is_dir() {
            copy_dir(&src, &dst);
        } else {
            std::fs::copy(&src, &dst).unwrap();
        }
    }
}

/// a copy of the honest dev tables directory
fn tables_copy(cc: &Cc, name: &str) -> PathBuf {
    let t = cc.root.join(format!("rv-tables-{name}"));
    copy_dir(&cc.tables, &t);
    t
}

/// replace `file`'s bytes and rehash `manifest` (the old digest named once)
fn replace_rehashed(dir: &Path, file: &str, manifest: &str, bytes: &[u8]) {
    let fp = dir.join(file);
    let old = hex(&sha256(&std::fs::read(&fp).unwrap()));
    let new = hex(&sha256(bytes));
    assert_ne!(old, new, "{file}: the attack changes the table");
    std::fs::write(&fp, bytes).unwrap();
    let mp = dir.join(manifest);
    let m = std::fs::read_to_string(&mp).unwrap();
    assert_eq!(m.matches(&old).count(), 1, "{manifest} names {file}'s digest once");
    std::fs::write(&mp, m.replace(&old, &new)).unwrap();
}

fn edit(path: &Path, from: &str, to: &str) {
    let t = std::fs::read_to_string(path).unwrap();
    assert!(t.contains(from), "{from:?} not in {}", path.display());
    std::fs::write(path, t.replacen(from, to, 1)).unwrap();
}

fn verify(export: &Path, tables: &Path, policy: &str, out: &Path, pin: &str, bits: &str) -> i32 {
    classify_verify_command(&s(&["--export", export.to_str().unwrap(), "--tables", tables.to_str().unwrap(), "--policy", policy, "--artifact", out.to_str().unwrap(), "--expect-statement", pin, "--min-bits", bits]))
}

fn prove(cc: &Cc, export: &Path, tables: &Path, policy: &str, out: &Path) -> i32 {
    let cf = cc.content_file(&cc.content);
    let od = cc.owner_dir(out);
    classify_prove_command(&s(&["--export", export.to_str().unwrap(), "--tables", tables.to_str().unwrap(), "--policy", policy, "--content-file", cf.to_str().unwrap(), "--seq", "s0", "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]))
}

fn nothing_claimed(cc: &Cc, out: &Path) -> bool {
    !out.exists() && !sib(out, ".incomplete").exists() && !sib(out, ".unverified-statement").exists() && !cc.owner_dir(out).exists()
}

fn published(out: &Path) -> bool {
    out.join(run_sink::STATEMENT_DIR).exists()
}

fn unverified(out: &Path) -> PathBuf {
    sib(out, ".unverified-statement").join("statement.json")
}

fn stmt_json(path: &Path) -> J {
    parse_json(&std::fs::read(path).unwrap()).unwrap()
}

/// a run directory and its unverified statement, copied (so it can be
/// verified or recombined without touching the original)
fn copy_run(from: &Path, to: &Path) {
    copy_dir(from, to);
    copy_dir(&sib(from, ".unverified-statement"), &sib(to, ".unverified-statement"));
}

fn loader_err(cc: &Cc, tables: &Path) -> String {
    let p = load_export(&cc.export).unwrap();
    match load_tied_classifier_tables(&p, &cc.export, tables, &policy_rung_dev()) {
        Ok(_) => panic!("R-C2's loader accepted {}", tables.display()),
        Err(e) => e,
    }
}

/// **Item 5 (margin row) and item 4 (reference digests).** The honest
/// derivation equals the reviewer reference for both exports; four doctored
/// margin rows, each written with a REHASHED `classifier.json`, are accepted
/// by R-C1's reader and refused by R-C2's loader, the prover (nothing
/// claimed) and the verifier (nothing published).
#[test]
fn rv13_r1_doctored_margin_rows_with_rehashed_manifests_are_refused() {
    let cc = Cc::new("rv13-r1");
    assert_eq!(hex(&sha256(&dev_tied_tensor_bytes())), REF_TENSOR, "reviewer reference: tensor pin");
    let p = load_export(&cc.export).unwrap();
    let (t, _, _) = load_tied_classifier_tables(&p, &cc.export, &cc.tables, &policy_rung_dev()).unwrap();
    assert_eq!(hex(&sha256(&le(&t.w_delta))), REF_W, "reviewer reference: dev margin row");
    assert_eq!(hex(&sha256(&le(&t.emb))), REF_EMB, "reviewer reference: embedding");
    let pn = load_export(&cc.export_neg).unwrap();
    let (tn, _, _) = load_tied_classifier_tables(&pn, &cc.export_neg, &cc.tables_neg, &policy_rung_dev_swapped()).unwrap();
    assert_eq!(hex(&sha256(&le(&tn.w_delta))), REF_W_SWAPPED, "reviewer reference: the swapped export's row");
    assert!(t.w_delta.iter().zip(&tn.w_delta).all(|(a, b)| matches!(i32::from(*a) + i32::from(*b), 0 | 1)), "w + w' in {{0, 1}} (half-up ties)");
    let honest = cc.root.join("run-honest");
    assert_eq!(cc.prove(&honest, &cc.tables), 0);
    let w = t.w_delta.clone();
    let mut one = w.clone();
    one[17] = if one[17] < 32767 { one[17] + 1 } else { one[17] - 1 };
    let variants: Vec<(&str, Vec<i16>)> = vec![
        ("swapped-honest-row", tn.w_delta.clone()),
        ("all-zero", vec![0; D]),
        ("doubled-clamped", w.iter().map(|x| (i32::from(*x) * 2).clamp(-32767, 32767) as i16).collect()),
        ("one-word", one),
    ];
    for (name, row) in variants {
        let tab = tables_copy(&cc, name);
        replace_rehashed(&tab, "margin_int16.bin", "classifier.json", &le(&row));
        assert!(read_classifier_files(&tab, D).is_ok(), "{name}: R-C1's reader accepts it (consistent manifest)");
        let e = loader_err(&cc, &tab);
        assert!(e.contains("margin_int16.bin is not the margin row recomputed"), "{name}: {e}");
        let out = cc.root.join(format!("run-{name}"));
        assert_eq!(prove(&cc, &cc.export, &tab, POLICY_RUNG_DEV, &out), 1, "{name}: the prover refuses");
        assert!(nothing_claimed(&cc, &out), "{name}: every claimed directory removed");
        assert_eq!(verify(&cc.verifier_copy, &tab, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 1, "{name}: the verifier refuses");
        assert!(!published(&honest), "{name}: nothing published");
    }
    assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 0, "the honest tables still verify");
    eprintln!("RV13 R1 | reference digests tensor/emb/w/w' match | refused (loader, prover, verifier): swapped-honest-row, all-zero, doubled-clamped, one-word margin rows with rehashed classifier.json");
}

/// **Item 5 (embedding).** Three doctored embeddings with a REHASHED
/// `token_io.json`: a content token's row, the BOS row, and the whole table
/// re-quantized at a scale 0.1% off (a plausible alternative export). Each is
/// refused by name at the loader, and by the prover and the verifier.
#[test]
fn rv13_r2_doctored_embeddings_with_rehashed_manifests_are_refused() {
    let cc = Cc::new("rv13-r2");
    let honest = cc.root.join("run-honest");
    assert_eq!(cc.prove(&honest, &cc.tables), 0);
    let base = std::fs::read(cc.tables.join("embedding_int16.bin")).unwrap();
    let mut content_row = base.clone();
    content_row[9 * D * 2] ^= 0x01;
    let mut bos_row = base.clone();
    bos_row[(D + 5) * 2] ^= 0x02;
    let ru = TrainedExport::load(&cc.export).unwrap().residual_unit;
    let vals = tied_tables::bf16(&dev_tied_tensor_bytes()).unwrap();
    let rows = &vals[..DEV_TIED_V * DEV_TIED_D];
    let requant: Vec<u8> = tied_tables::quantize(rows, ru * 1.001, -32768, 32767).unwrap().into_iter().flat_map(|q| (q as i16).to_le_bytes()).collect();
    for (name, bytes) in [("content-row-9", content_row), ("bos-row", bos_row), ("requantized-0.1pct", requant)] {
        let tab = tables_copy(&cc, name);
        replace_rehashed(&tab, "embedding_int16.bin", "token_io.json", &bytes);
        assert!(read_classifier_files(&tab, D).is_ok(), "{name}: R-C1's reader accepts it");
        let e = loader_err(&cc, &tab);
        assert!(e.contains("embedding_int16.bin is not the table derived from the pinned tied tensor"), "{name}: {e}");
        let out = cc.root.join(format!("run-{name}"));
        assert_eq!(prove(&cc, &cc.export, &tab, POLICY_RUNG_DEV, &out), 1, "{name}: the prover refuses");
        assert!(nothing_claimed(&cc, &out));
        assert_eq!(verify(&cc.verifier_copy, &tab, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 1, "{name}: the verifier refuses");
        assert!(!published(&honest));
    }
    eprintln!("RV13 R2 | refused (loader, prover, verifier): content row 9, BOS row, whole table re-quantized at s_x*1.001, each with rehashed token_io.json");
}

/// **Item 5 (head).** The classifier never reads the head: an honest run
/// verifies byte for byte with a doctored head (and multipliers) whose
/// manifest was rehashed, so the head is outside the classifier statement by
/// design (recorded, not a finding; at Shieldstral the native loader derives
/// the export's own head).
#[test]
fn rv13_r3_a_doctored_head_is_outside_the_classifier_statement() {
    let cc = Cc::new("rv13-r3");
    let honest = cc.root.join("run-honest");
    assert_eq!(cc.prove(&honest, &cc.tables), 0);
    let tab = tables_copy(&cc, "head");
    let mut h = std::fs::read(tab.join("head_int8_perrow.bin")).unwrap();
    h[123] ^= 0x10;
    replace_rehashed(&tab, "head_int8_perrow.bin", "head_manifest.json", &h);
    let mut m = std::fs::read(tab.join("head_mult12.bin")).unwrap();
    m[8] ^= 0x01;
    replace_rehashed(&tab, "head_mult12.bin", "head_manifest.json", &m);
    assert_eq!(verify(&cc.verifier_copy, &tab, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 0, "the head is not read by the classifier");
    eprintln!("RV13 R3 | doctored head + multipliers (rehashed head_manifest.json): an honest run verifies byte for byte: the head is outside the classifier statement (by design)");
}

/// **Item 2 / item 5 (BOS, final norm).** A BOS changed CONSISTENTLY in
/// `classifier.json` and `token_io.json`, and in-class final-norm edits, are
/// refused; the export's own `token_io_parameters` edited in the verifier's
/// copy is refused at the identity pin, and pinned to its own identity it is
/// refused before any segment (the statement and the door).
#[test]
fn rv13_r4_bos_and_final_norm_doctored_consistently_are_refused() {
    let cc = Cc::new("rv13-r4");
    let honest = cc.root.join("run-honest");
    assert_eq!(cc.prove(&honest, &cc.tables), 0);
    let tab = tables_copy(&cc, "bos2");
    edit(&tab.join("classifier.json"), "\"bos\": 1,", "\"bos\": 2,");
    edit(&tab.join("token_io.json"), "{\"embedding_table\"", "{\"bos\": 2, \"embedding_table\"");
    assert!(read_classifier_files(&tab, D).is_ok(), "R-C1's reader accepts a consistent BOS 2");
    let e = loader_err(&cc, &tab);
    assert!(e.contains("bos 2 is not the export's token_io_parameters.bos 1"), "{e}");
    assert_eq!(prove(&cc, &cc.export, &tab, POLICY_RUNG_DEV, &cc.root.join("run-bos2")), 1);
    for (name, from, to) in [("g0", "\"g0\": 127", "\"g0\": 126"), ("ceps", "\"ceps\": 33554467", "\"ceps\": 33554468"), ("tn", "\"tn\": 11", "\"tn\": 12")] {
        let tab = tables_copy(&cc, name);
        edit(&tab.join("classifier.json"), from, to);
        let e = loader_err(&cc, &tab);
        assert!(e.contains("final_norm is not the export's token_io_parameters.classifier_final_norm"), "{name}: {e}");
        assert_eq!(verify(&cc.verifier_copy, &tab, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 1, "{name}");
    }
    // the export's own parameter, edited in the verifier's copy
    let vc = cc.root.join("vc-bos2");
    copy_dir(&cc.verifier_copy, &vc);
    edit(&vc.join("profile.json"), "\"token_io_parameters\": {\"bos\": 1,", "\"token_io_parameters\": {\"bos\": 2,");
    assert_eq!(verify(&vc, &cc.tables, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 1, "refused at the identity pin");
    let own = hex(&load_export(&vc).unwrap().model.identity());
    assert_ne!(own, cc.identity);
    assert_eq!(verify(&vc, &tab_bos2(&cc), POLICY_RUNG_DEV, &honest, &own, "93"), 1, "pinned to itself: refused before any segment");
    let vcn = cc.root.join("vc-cn");
    copy_dir(&cc.verifier_copy, &vcn);
    edit(&vcn.join("profile.json"), "\"classifier_final_norm\": {\"g0\": 127, \"cn\": 2048", "\"classifier_final_norm\": {\"g0\": 127, \"cn\": 2047");
    let own = hex(&load_export(&vcn).unwrap().model.identity());
    let tcn = tables_copy(&cc, "cn2047");
    edit(&tcn.join("classifier.json"), "\"cn\": 2048", "\"cn\": 2047");
    assert_eq!(verify(&vcn, &tcn, POLICY_RUNG_DEV, &honest, &own, "93"), 1, "a consistently moved cn (export + tables + pin): the run's statement is not re-rendered");
    assert!(!published(&honest));
    eprintln!("RV13 R4 | refused: consistent BOS 2 (classifier.json + token_io.json), g0/ceps/tn edits; export token_io_parameters bos 2 at the pin and pinned to itself; a consistently moved cn");
}

fn tab_bos2(cc: &Cc) -> PathBuf {
    let tab = tables_copy(cc, "bos2-for-own");
    edit(&tab.join("classifier.json"), "\"bos\": 1,", "\"bos\": 2,");
    tab
}

/// **Item 5 (yes / no, threshold in classifier.json only).** The copies are
/// never an authority: swapped ids, a swapped id pair WITH the swapped
/// policy's honest row (rehashed), threshold_c and the scale edited — each
/// refused at the loader and the verifier. Absent copies carry no authority
/// either way: with the honest row the run verifies; with the swapped row it
/// is refused by the row comparison.
#[test]
fn rv13_r5_yes_no_or_threshold_edited_in_classifier_json_only_are_refused() {
    let cc = Cc::new("rv13-r5");
    let honest = cc.root.join("run-honest");
    assert_eq!(cc.prove(&honest, &cc.tables), 0);
    let neg_row = std::fs::read(cc.tables_neg.join("margin_int16.bin")).unwrap();
    let cases: [(&str, &str, &str, bool); 6] = [
        ("ids-swapped", "\"yes_id\": 40, \"no_id\": 41", "\"yes_id\": 41, \"no_id\": 40", false),
        ("ids-and-row-swapped", "\"yes_id\": 40, \"no_id\": 41", "\"yes_id\": 41, \"no_id\": 40", true),
        ("c-plus-1", "\"threshold_c\": 0", "\"threshold_c\": 1", false),
        ("c-minus-1", "\"threshold_c\": 0", "\"threshold_c\": -1", false),
        ("scale", "\"scale\": 0.00390625", "\"scale\": 0.0078125", false),
        ("scale-same-value-other-text", "\"scale\": 0.00390625", "\"scale\": 0.0039062500000000001", false),
    ];
    for (name, from, to, row) in cases {
        let tab = tables_copy(&cc, name);
        if row {
            replace_rehashed(&tab, "margin_int16.bin", "classifier.json", &neg_row);
        }
        edit(&tab.join("classifier.json"), from, to);
        let p = load_export(&cc.export).unwrap();
        let r = load_tied_classifier_tables(&p, &cc.export, &tab, &policy_rung_dev());
        if name == "scale-same-value-other-text" {
            // the same binary64 value written differently: not a disagreement
            assert!(r.is_ok(), "{name}: {:?}", r.err());
            continue;
        }
        let e = r.err().unwrap_or_else(|| panic!("{name}: accepted"));
        assert!(e.contains("is not the export profile's classifier_margin_parameters"), "{name}: {e}");
        assert_eq!(verify(&cc.verifier_copy, &tab, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 1, "{name}: the verifier refuses");
        assert!(!published(&honest));
    }
    // no copies at all
    let strip = |tab: &Path| {
        let cj = tab.join("classifier.json");
        edit(&cj, ", \"scale\": 0.00390625", "");
        edit(&cj, ", \"yes_id\": 40, \"no_id\": 41, \"threshold_c\": 0", "");
    };
    let bare = tables_copy(&cc, "no-copies");
    strip(&bare);
    let bare_neg = tables_copy(&cc, "no-copies-swapped-row");
    replace_rehashed(&bare_neg, "margin_int16.bin", "classifier.json", &neg_row);
    strip(&bare_neg);
    let e = loader_err(&cc, &bare_neg);
    assert!(e.contains("margin_int16.bin is not the margin row recomputed"), "{e}");
    assert_eq!(verify(&cc.verifier_copy, &bare_neg, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 1, "no copies + the swapped row: refused by the row");
    assert_eq!(verify(&cc.verifier_copy, &bare, POLICY_RUNG_DEV, &honest, &cc.identity, "93"), 0, "no copies + the honest row: verifies (the profile is the authority)");
    eprintln!("RV13 R5 | refused: ids swapped, ids+row swapped (rehashed), c +1/-1, scale; accepted: the same scale value in other text, no copies with the honest row; refused: no copies with the swapped row");
}

/// **Item 5 (a profile from another export; statement fields).** (a) the
/// other export's `profile.json` in the verifier's copy, at the pinned
/// identity; (b) at its own identity with the dev policy; (c) with the
/// other export's inputs, a run whose statement names the dev policy;
/// (d) two honest runs recombined (A's segments with B's statement, B's
/// segments with A's); (e) the derivation asked for the statement's digest
/// while the export holds another profile (the window between reads);
/// (f) statement fields `margin_scale` / `tied_source` edited.
#[test]
fn rv13_r6_another_exports_profile_and_edited_statement_fields_are_refused() {
    let cc = Cc::new("rv13-r6");
    let (a, b) = (cc.root.join("run-a"), cc.root.join("run-b"));
    assert_eq!(cc.prove(&a, &cc.tables), 0);
    assert_eq!(cc.prove(&b, &cc.tables_neg), 0);
    let (a2, b2) = (cc.root.join("run-a2"), cc.root.join("run-b2"));
    copy_run(&a, &a2);
    copy_run(&b, &b2);
    // (a) / (b)
    let vc = cc.root.join("vc-other-profile");
    copy_dir(&cc.verifier_copy, &vc);
    std::fs::copy(cc.export_neg.join("profile.json"), vc.join("profile.json")).unwrap();
    assert_eq!(verify(&vc, &cc.tables, POLICY_RUNG_DEV, &a, &cc.identity, "93"), 1, "(a) refused at the identity pin");
    assert_eq!(hex(&load_export(&vc).unwrap().model.identity()), cc.identity_neg, "the copy is now the other export");
    assert_eq!(verify(&vc, &cc.tables, POLICY_RUNG_DEV, &a, &cc.identity_neg, "93"), 1, "(b) its parameters are not the dev policy's");
    // (c)
    assert_eq!(verify(&cc.verifier_copy_neg, &cc.tables_neg, POLICY_RUNG_DEV_SWAPPED, &a, &cc.identity_neg, "93"), 1, "(c) a dev-policy run under the swapped inputs");
    assert!(!published(&a));
    // (d) recombined honest runs
    let c = cc.root.join("run-c");
    copy_dir(&a, &c);
    copy_dir(&sib(&b, ".unverified-statement"), &sib(&c, ".unverified-statement"));
    assert_eq!(verify(&cc.verifier_copy_neg, &cc.tables_neg, POLICY_RUNG_DEV_SWAPPED, &c, &cc.identity_neg, "93"), 1, "(d) A's segments under B's statement");
    let dd = cc.root.join("run-d");
    copy_dir(&b, &dd);
    copy_dir(&sib(&a, ".unverified-statement"), &sib(&dd, ".unverified-statement"));
    assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &dd, &cc.identity, "93"), 1, "(d) B's segments under A's statement");
    assert!(!published(&c) && !published(&dd));
    // (e) the window between the statement's read and the derivation's
    let x = TrainedExport::load(&cc.export).unwrap();
    let swapped_dir = cc.root.join("export-profile-swapped");
    copy_dir(&cc.verifier_copy, &swapped_dir);
    std::fs::copy(cc.export_neg.join("profile.json"), swapped_dir.join("profile.json")).unwrap();
    let e = recompute_tied_classifier(TiedSource::DevRung, &swapped_dir, &cc.tables, &policy_rung_dev(), x.residual_unit, D, &x.profile_sha256).unwrap_err();
    assert!(e.contains("not the profile the trained statement binds"), "(e) {e}");
    // (f) statement fields
    let st = std::fs::read_to_string(unverified(&a2)).unwrap();
    let j = stmt_json(&unverified(&a2));
    let scale_line = format!("\"margin_scale\": {:e}", 1.0f64 / 256.0);
    assert!(st.contains(&scale_line), "{st}");
    assert!(j.get("tied_source").and_then(J::str).unwrap().starts_with("tied-source=dev-rung-synthetic-bf16"));
    for (name, from, to) in [
        ("margin_scale", scale_line.clone(), format!("\"margin_scale\": {:e}", 1.0f64 / 128.0)),
        ("tied_source", "tied-source=dev-rung-synthetic-bf16".to_string(), "tied-source=shieldstral-checkpoint".to_string()),
        ("margin_vector_digest", hex(&j.get("margin_vector_digest").and_then(J::str).map(|s| { let mut b = super::super::trained_block::unhex32(s).unwrap(); b[0] ^= 1; b }).unwrap()), "x".into()),
    ] {
        let r = cc.root.join(format!("run-f-{name}"));
        copy_run(&a2, &r);
        if name == "margin_vector_digest" {
            let old = j.get("margin_vector_digest").and_then(J::str).unwrap().to_string();
            edit(&unverified(&r), &old, &from);
        } else {
            edit(&unverified(&r), &from, &to);
        }
        assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &r, &cc.identity, "93"), 1, "(f) {name} edited");
        assert!(!published(&r));
    }
    // the untouched copies still verify
    assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &a2, &cc.identity, "93"), 0);
    assert_eq!(verify(&cc.verifier_copy_neg, &cc.tables_neg, POLICY_RUNG_DEV_SWAPPED, &b2, &cc.identity_neg, "93"), 0);
    eprintln!("RV13 R6 | refused: other export's profile at the pin / at its identity, dev-policy run under swapped inputs, A/B recombined both ways, profile swapped before the derivation, statement margin_scale / tied_source / margin digest edited; untouched copies verify");
}

/// **Item 6 / 7 (schema /1 in process).** An R-C2 statement rewritten as an
/// R-C1 statement (schema /1, the two new fields removed, the R-C1 scope
/// sentence) is refused by the r13 verifier before any segment is read.
#[test]
fn rv13_r7_a_schema_1_statement_is_refused_by_the_r13_verifier() {
    let cc = Cc::new("rv13-r7");
    let a = cc.root.join("run-a");
    assert_eq!(cc.prove(&a, &cc.tables), 0);
    let st = std::fs::read_to_string(unverified(&a)).unwrap();
    let rc2 = "a classifier proof (DESIGN_CLASSIFIER v2, rung R-C2): the approved integer model's verdict on hidden content under a pre-registered policy; the margin row and the embedding re-derived from the pinned tied tensor; one external endpoint; the verdict bit is public; NOT a privacy acceptance";
    let rc1 = "a classifier proof (DESIGN_CLASSIFIER v2, rung R-C1): the approved integer model's verdict on hidden content under a pre-registered policy; one external endpoint; the verdict bit is public; NOT a privacy acceptance";
    assert!(st.contains(rc2) && st.contains("\"schema\": \"zk60-classify-run/2\""));
    let only_schema = st.replacen("zk60-classify-run/2", "zk60-classify-run/1", 1);
    let full_rc1: String = only_schema.replacen(rc2, rc1, 1).lines().filter(|l| !l.starts_with(" \"margin_scale\"") && !l.starts_with(" \"tied_source\"")).map(|l| format!("{l}\n")).collect();
    assert_ne!(full_rc1, only_schema);
    for (name, text) in [("schema-only", only_schema), ("full-rc1-shape", full_rc1)] {
        let r = cc.root.join(format!("run-{name}"));
        copy_run(&a, &r);
        std::fs::write(unverified(&r), &text).unwrap();
        assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &r, &cc.identity, "93"), 1, "{name}");
        assert!(!published(&r));
    }
    assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &a, &cc.identity, "93"), 0);
    eprintln!("RV13 R7 | refused by the r13 verifier: schema /1 alone, and the full R-C1 statement shape; the original verifies");
}

fn bin_run(bin: &str, args: &[&str]) -> (i32, String, String) {
    let o = std::process::Command::new(bin).args(args).output().unwrap();
    (o.status.code().unwrap_or(-1), String::from_utf8_lossy(&o.stdout).to_string(), String::from_utf8_lossy(&o.stderr).to_string())
}

/// **Item 6 across binaries** (ignored; set RV13_R12_BIN and RV13_R13_BIN to
/// the lane's frozen r12 and r13 release binaries): the r12 binary's receipt
/// (schema /1) on the same honest fixture, and on DOCTORED tables (R-C1's gap),
/// is refused by the r13 binary and by this tree's verifier; the r13 binary's
/// receipt is refused by the r12 binary. Each binary verifies its own.
#[test]
#[ignore = "runs the lane's r12 and r13 release binaries; set RV13_R12_BIN and RV13_R13_BIN"]
fn rv13_r7b_receipts_do_not_cross_between_the_r12_and_r13_binaries() {
    let r12 = std::env::var("RV13_R12_BIN").expect("RV13_R12_BIN");
    let r13 = std::env::var("RV13_R13_BIN").expect("RV13_R13_BIN");
    let cc = Cc::new("rv13-r7b");
    let ex = cc.export.to_str().unwrap().to_string();
    let vc = cc.verifier_copy.to_str().unwrap().to_string();
    let prove_with = |bin: &str, tables: &Path, out: &Path| {
        let cf = cc.content_file(&cc.content);
        let od = cc.owner_dir(out);
        bin_run(bin, &["prove", "--export", &ex, "--tables", tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--seq", "s0", "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()])
    };
    let verify_pin = |bin: &str, tables: &Path, out: &Path, pin: &str| bin_run(bin, &["verify", "--export", &vc, "--tables", tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--artifact", out.to_str().unwrap(), "--expect-statement", pin, "--min-bits", "93"]);
    let verify_with = |bin: &str, tables: &Path, out: &Path| verify_pin(bin, tables, out, &cc.identity);
    // the "loaded" event's trained_statement_identity (each binary computes its own)
    let identity_of = |stdout: &str| -> String {
        let l = stdout.lines().find(|l| l.contains("\"event\":\"loaded\"")).unwrap_or_else(|| panic!("no loaded event: {stdout}"));
        let k = "\"trained_statement_identity\":\"";
        let at = l.find(k).unwrap() + k.len();
        l[at..at + 64].to_string()
    };
    // the r13 binary on the honest fixture
    let o13 = cc.root.join("run-r13");
    let (c, out, err) = prove_with(&r13, &cc.tables, &o13);
    assert_eq!(c, 0, "r13 prove: {out} {err}");
    assert_eq!(identity_of(&out), cc.identity, "the r13 binary computes this tree's identity");
    let o13b = cc.root.join("run-r13-copy");
    copy_run(&o13, &o13b);
    let (c12v, out12v, _) = verify_with(&r12, &cc.tables, &o13);
    eprintln!("RV13 R7b | r12 binary verifying an r13 receipt: exit {c12v} {}", out12v.lines().last().unwrap_or(""));
    assert_eq!(c12v, 1, "the r12 binary refuses an r13 (schema /2) receipt");
    assert!(!published(&o13));
    let (c13v, _, _) = verify_with(&r13, &cc.tables, &o13b);
    assert_eq!(c13v, 0, "the r13 binary verifies its own receipt");
    // the r12 binary on the honest fixture
    let o12 = cc.root.join("run-r12");
    let (c, out, err) = prove_with(&r12, &cc.tables, &o12);
    eprintln!("RV13 R7b | r12 prove on the R-C2 fixture: exit {c} {}", out.lines().last().unwrap_or(""));
    if c != 0 {
        eprintln!("RV13 R7b | the r12 binary does not prove on this fixture: {err}");
        return;
    }
    let id12 = identity_of(&out);
    eprintln!("RV13 R7b | identity under r12 {id12}, under r13 {} (equal: {})", cc.identity, id12 == cc.identity);
    let (c, o, _) = verify_pin(&r12, &cc.tables, &o13, &id12);
    eprintln!("RV13 R7b | r12 binary verifying the r13 receipt at the r12 pin: exit {c} {}", o.lines().last().unwrap_or(""));
    assert_eq!(c, 1, "refused at the r12 pin too");
    assert!(!published(&o13));
    let st = std::fs::read_to_string(unverified(&o12)).unwrap();
    assert!(st.contains("\"schema\": \"zk60-classify-run/1\""), "{st}");
    let o12b = cc.root.join("run-r12-copy");
    copy_run(&o12, &o12b);
    let (c, out, _) = verify_with(&r13, &cc.tables, &o12);
    eprintln!("RV13 R7b | r13 binary verifying an r12 receipt: exit {c} {}", out.lines().last().unwrap_or(""));
    assert_eq!(c, 1, "the r13 binary refuses an R-C1 receipt");
    assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &o12, &cc.identity, "93"), 1, "and so does this tree's verifier");
    assert!(!published(&o12));
    // an "upgrade": the R-C1 receipt's segments under an R-C2 statement (the r13
    // run's statement with the r12 run's input root): re-renders, refused by the proof
    let root12 = stmt_json(&unverified(&o12)).get("input_token_endpoint_root").and_then(J::str).unwrap().to_string();
    let root13 = stmt_json(&unverified(&o13)).get("input_token_endpoint_root").and_then(J::str).unwrap().to_string();
    let up = cc.root.join("run-r12-upgraded");
    copy_dir(&o12, &up);
    std::fs::create_dir_all(sib(&up, ".unverified-statement")).unwrap();
    std::fs::write(unverified(&up), std::fs::read_to_string(unverified(&o13)).unwrap().replacen(&root13, &root12, 1)).unwrap();
    let up2 = cc.root.join("run-r12-upgraded-2");
    copy_run(&up, &up2);
    let (c, o, _) = verify_with(&r13, &cc.tables, &up);
    eprintln!("RV13 R7b | r13 binary verifying R-C1 segments under an R-C2 statement: exit {c} {}", o.lines().last().unwrap_or(""));
    assert_eq!(c, 1, "an R-C1 receipt cannot be upgraded to schema /2");
    assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &up2, &cc.identity, "93"), 1, "nor in process");
    assert!(!published(&up) && !published(&up2));
    let (c, out, err) = verify_pin(&r12, &cc.tables, &o12b, &id12);
    assert_eq!(c, 0, "the r12 binary re-checks its own R-C1 receipt: {out} {err}");
    let (c, _, _) = verify_pin(&r13, &cc.tables, &o12, &id12);
    assert_eq!(c, 1, "the r13 binary refuses it at the r12 pin too");
    // R-C1's gap with the r12 binary: a doctored row (rehashed) proves; r13 refuses it
    let tab = tables_copy(&cc, "r12-doctored");
    let neg_row = std::fs::read(cc.tables_neg.join("margin_int16.bin")).unwrap();
    replace_rehashed(&tab, "margin_int16.bin", "classifier.json", &neg_row);
    let od = cc.root.join("run-r12-doctored");
    let (c, out, _) = prove_with(&r12, &tab, &od);
    eprintln!("RV13 R7b | r12 prove with a doctored (rehashed) margin row: exit {c} {}", out.lines().last().unwrap_or(""));
    if c == 0 {
        let odb = cc.root.join("run-r12-doctored-copy");
        copy_run(&od, &odb);
        let (c12, _, _) = verify_pin(&r12, &tab, &od, &id12);
        eprintln!("RV13 R7b | r12 verify of the doctored-row receipt with the doctored tables: exit {c12} (R-C1's gap)");
        let (c13, _, _) = verify_with(&r13, &tab, &odb);
        assert_eq!(c13, 1, "the r13 binary refuses it with the doctored tables");
        let (c13h, _, _) = verify_with(&r13, &cc.tables, &odb);
        assert_eq!(c13h, 1, "and with the honest tables");
    }
    eprintln!("RV13 R7b | PASS: no receipt crosses between the r12 and r13 binaries");
}

/// **Item 2 (`--min-bits`).** Below the rung's floor, malformed, and above
/// the run's own figure: refused at verify, input-owner and label; 93
/// verifies; the default (95) is recorded against the run's floor.
#[test]
fn rv13_r8_min_bits_edges_at_every_verifying_command() {
    let cc = Cc::new("rv13-r8");
    let a = cc.root.join("run-a");
    assert_eq!(cc.prove(&a, &cc.tables), 0);
    let floor_bits = stmt_json(&unverified(&a)).get("whole_run_floor_bits").and_then(J::f64).unwrap();
    for bits in ["92", "0", "-1", "abc", "200"] {
        assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &a, &cc.identity, bits), 1, "--min-bits {bits}");
        assert!(!published(&a));
    }
    let dec = cc.owner_dir(&a).join("input.dec");
    let cf = cc.content_file(&cc.content);
    let owner = |bits: &str| classify_input_owner_command(&s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--artifact", a.to_str().unwrap(), "--expect-statement", &cc.identity, "--decommitment", dec.to_str().unwrap(), "--content-file", cf.to_str().unwrap(), "--min-bits", bits]));
    let label = |bits: &str| classify_label_command(&s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--runs", a.to_str().unwrap(), "--expect-statement", &cc.identity, "--min-bits", bits]));
    assert_eq!(owner("92"), 1, "input-owner below the floor");
    assert_eq!(label("92"), 1, "label below the floor");
    let default = classify_verify_command(&s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--artifact", a.to_str().unwrap(), "--expect-statement", &cc.identity]));
    eprintln!("RV13 R8 | the rung run's whole_run_floor_bits {floor_bits}; verify with the default --min-bits (95): exit {default}");
    assert_eq!(default, if floor_bits >= 95.0 { 0 } else { 1 });
    assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &a, &cc.identity, "93"), 0, "93 at the rung");
    assert_eq!(owner("93"), 0);
    assert_eq!(label("93"), 0);
    assert_eq!(min_bits_floor("hashline-zk-mr1/any-other-profile/1"), 95);
    eprintln!("RV13 R8 | refused: 92, 0, -1, abc, 200 (verify), 92 (input-owner, label); 93 verifies everywhere");
}

/// **Item 4 (the pinned tensor file).** A symbolic link to the honest tensor,
/// a same-length tensor with every sign flipped, one with only the final-norm
/// weights changed, and one two bytes long: all refused at the loader.
#[test]
fn rv13_r9_the_dev_tensor_file_attacks_are_refused() {
    let cc = Cc::new("rv13-r9");
    let t = dev_tied_tensor_bytes();
    let link = tables_copy(&cc, "link");
    let elsewhere = cc.root.join("honest-tensor.bin");
    std::fs::write(&elsewhere, &t).unwrap();
    std::fs::remove_file(link.join(DEV_TIED_TENSOR_FILE)).unwrap();
    std::os::unix::fs::symlink(&elsewhere, link.join(DEV_TIED_TENSOR_FILE)).unwrap();
    let e = loader_err(&cc, &link);
    assert!(e.contains("not a regular file"), "symlink: {e}");
    let n = DEV_TIED_V * DEV_TIED_D;
    let flipped: Vec<u8> = t.chunks_exact(2).enumerate().flat_map(|(k, c)| { let w = u16::from_le_bytes([c[0], c[1]]); (if k < n { w ^ 0x8000 } else { w }).to_le_bytes() }).collect();
    let mut gonly = t.clone();
    gonly[2 * n + 7] ^= 0x01;
    let mut long = t.clone();
    long.extend_from_slice(&[0, 0]);
    for (name, bytes, want) in [("signs-flipped", flipped, "not the pinned development tensor"), ("norm-weights", gonly, "not the pinned development tensor"), ("two-bytes-long", long, "the expected length")] {
        let tab = tables_copy(&cc, name);
        std::fs::write(tab.join(DEV_TIED_TENSOR_FILE), &bytes).unwrap();
        let e = loader_err(&cc, &tab);
        assert!(e.contains(want), "{name}: {e}");
    }
    eprintln!("RV13 R9 | refused: symlinked tensor, signs flipped, norm weights changed, two bytes long");
}

/// **Item 4 (both verdicts reachable).** Under the PRODUCTION development
/// policy alone (no test policy), contents chosen by the reviewer: each
/// proves and verifies; both verdicts occur among them. And under the
/// swapped (test-only) policy the fixture's content gets the other verdict.
#[test]
fn rv13_r10_both_verdicts_are_reachable_under_the_production_dev_policy() {
    let cc = Cc::new("rv13-r10");
    let pol = policy_rung_dev();
    let mut seen = Vec::new();
    for start in [9u64, 60, 120, 180, 240, 270] {
        let content: Vec<u64> = (start..start + 23).collect();
        let tokens = item_tokens(&pol, &content);
        let sd = cc.owners.join(format!("rv-seq-{start}"));
        write_seq_files(&cc.export, &cc.t.emb, &sd, &tokens);
        let text = content.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
        let cf = cc.content_file(&text);
        let out = cc.root.join(format!("run-{start}"));
        let od = cc.owner_dir(&out);
        let code = classify_prove_command(&s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--seq-dir", sd.to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]));
        assert_eq!(code, 0, "content {start}..: proves");
        let bit = stmt_json(&unverified(&out)).get("verdict_bit").and_then(J::i64).unwrap();
        assert_eq!(verify(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &out, &cc.identity, "93"), 0, "content {start}..: verifies");
        seen.push((start, bit));
    }
    eprintln!("RV13 R10 | production dev policy, contents (start, verdict_bit): {seen:?}");
    let a = cc.root.join("run-fixture");
    let b = cc.root.join("run-fixture-swapped");
    assert_eq!(cc.prove(&a, &cc.tables), 0);
    assert_eq!(cc.prove(&b, &cc.tables_neg), 0);
    let (va, vb) = (stmt_json(&unverified(&a)).get("verdict_bit").and_then(J::i64).unwrap(), stmt_json(&unverified(&b)).get("verdict_bit").and_then(J::i64).unwrap());
    eprintln!("RV13 R10 | the fixture content: dev policy verdict {va}, swapped policy verdict {vb}");
    assert_ne!(va, vb);
    // recorded, not required (first run 00:08Z: all six contents gave verdict 0
    // under the production policy; the second verdict needs the test-only policy)
    eprintln!("RV13 R10 | both verdicts under the production dev policy alone: {}", seen.iter().any(|x| x.1 == 0) && seen.iter().any(|x| x.1 == 1));
}

/// **Item 1 (final-norm weights and rotation exactly once), end to end.** On
/// the fixture's honest item: OUT-C's own integer margin (the run's recomputed
/// row, the final hidden state of the block, the uniform g0 gain only) against
/// the FLOAT logit difference of the same tensor, L = sum_i g_i (E_yes - E_no)_i
/// xhat_i with xhat = x sqrt(d) / sqrt(sum x^2 + ceps), scaled by
/// k = g0 cn / (2^tn sqrt(d)) / scale. With g folded once the integer margin
/// is k L up to rounding; the hypotheses "g twice" and "no g" fit worse. The
/// proved verdict is the integer margin's (Delta > c).
#[test]
fn rv13_r11_the_margin_is_the_float_logit_difference_with_g_folded_once() {
    let cc = Cc::new("rv13-r11");
    let pol = policy_rung_dev();
    let p = load_export(&cc.export).unwrap();
    let (tables, bos, nm) = load_tied_classifier_tables(&p, &cc.export, &cc.tables, &pol).unwrap();
    let t = p.sh.tokens;
    let xo = std::fs::read(cc.export.join("seq_s0").join("x_out_L00.bin")).unwrap();
    let row: Vec<i64> = xo[(t - 1) * D * 2..t * D * 2].chunks_exact(2).map(|c| i64::from(i16::from_le_bytes([c[0], c[1]]))).collect();
    let n = t - pol.prefix.len() - pol.suffix.len();
    let cp = ClassifierProfile::new(&p.sh, &tables, bos, nm, &pol, n, super::Tier::R1_MVP).unwrap();
    let ov = super::stage_out_c::out_values(&cp, &tables, &row, true).unwrap();
    let vals = tied_tables::bf16(&dev_tied_tensor_bytes()).unwrap();
    let (rows, g) = vals.split_at(DEV_TIED_V * DEV_TIED_D);
    let ss: f64 = row.iter().map(|x| (*x as f64) * (*x as f64)).sum::<f64>() + nm.ceps as f64;
    let xhat: Vec<f64> = row.iter().map(|x| *x as f64 * (D as f64).sqrt() / ss.sqrt()).collect();
    let (yes, no) = (pol.yes as usize, pol.no as usize);
    let diff = |i: usize| rows[yes * D + i] - rows[no * D + i];
    let l = |gp: &dyn Fn(usize) -> f64| (0..D).map(|i| gp(i) * diff(i) * xhat[i]).sum::<f64>();
    let (once, twice, none) = (l(&|i| g[i]), l(&|i| g[i] * g[i]), l(&|_| 1.0));
    let k = nm.g0 as f64 * nm.cn as f64 / (2f64.powi(nm.tn as i32) * (D as f64).sqrt()) / pol.margin_scale();
    let m = ov.margin as f64;
    let (e1, e2, e0) = ((m - k * once).abs(), (m - k * twice).abs(), (m - k * none).abs());
    // rounding: |y_i| error <= 1/2 (plus the isqrt floor), |w_i| error <= 1/2
    let wabs: f64 = tables.w_delta.iter().map(|w| (*w as f64).abs()).sum();
    let yabs: f64 = ov.y.iter().map(|y| (*y as f64).abs()).sum();
    let bound = 0.5 * wabs + 0.5 * yabs + 0.01 * m.abs();
    eprintln!("RV13 R11 | integer margin {} | k*L: g once {:.1} (err {:.1}), g twice {:.1} (err {:.1}), no g {:.1} (err {:.1}) | rounding bound {:.1} | k {:.3} | verdict {}", ov.margin, k * once, e1, k * twice, e2, k * none, e0, bound, k, ov.verdict);
    assert!(e1 <= bound, "the integer margin is the float logit difference with g once, within rounding");
    assert!(e1 < e2 && e1 < e0, "g once fits better than twice or none");
    assert_eq!(ov.verdict, u8::from(ov.margin > pol.c));
    assert_eq!((once > 0.0) as u8, ov.verdict, "the float verdict (c = 0) agrees");
    // and the proved run states that verdict
    let a = cc.root.join("run-a");
    assert_eq!(cc.prove(&a, &cc.tables), 0);
    assert_eq!(stmt_json(&unverified(&a)).get("verdict_bit").and_then(J::i64).unwrap(), i64::from(ov.verdict));
}
