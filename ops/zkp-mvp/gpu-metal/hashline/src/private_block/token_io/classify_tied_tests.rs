//! **TOKEN I/O ROUND 13, RUNG R-C2: THE CLASSIFIER'S TABLES TIED TO THE
//! PINNED TENSOR.** TEST CODE ONLY, public synthetic data (the development
//! rung's pinned tensor and tiny exports), plus one ignored, guarded test on
//! the actual Shieldstral export through native R12b.
//!
//! Written FAILING-FIRST against R-C1's CLI (its loader trusted each table's
//! own manifest; run b1, 2026-10-28 23:13, 4 red): a doctored margin row, a
//! doctored embedding, a doctored final norm or BOS, each shipped with a
//! CONSISTENT manifest, must be refused by the prover and the verifier;
//! `--min-bits` below the profile's floor (D27: 93 only at the development
//! rung, 95 elsewhere) must be refused. Then the reviewer's R-C2 requirements
//! (REVIEW_R12B §5), each test naming the ones it covers:
//! (1) ids / scale / threshold only from the bound profile's
//! `classifier_margin_parameters`; (2) the profile digest is the statement's
//! `export_profile_sha256`; (3) the recomputed row, never the file; (4) the
//! |m| > 32767 refusal propagates; (5) the final-norm weights and the rotation
//! are folded into `w` once. The honest fixture still proves and verifies
//! (`classify_cli_tests`' e2e).

use super::classify::*;
use super::classify_cli::{load_classifier_tables, load_export, read_classifier_files};
use super::classify_cli_tests::{add_classifier_parameters, policy_rung_dev_swapped, write_classifier_tables, Cc, POLICY_RUNG_DEV};
use super::classify_tied::*;
use super::tests::norm;
use super::*;
use super::super::run_sink;
use super::super::trained_block::{sha256, TrainedExport};
use super::super::trained_block_tests::{write_export, Fault};
use std::path::{Path, PathBuf};

/// the rung's block width
const D: usize = 384;

/// change a table file and REHASH its manifest: a self-consistent tables
/// directory whose table is not the model's (the R12-F1 classifier attack)
fn rehash(dir: &Path, file: &str, manifest: &str, edit: impl FnOnce(&mut Vec<u8>)) {
    let fp = dir.join(file);
    let mut b = std::fs::read(&fp).unwrap();
    let old = hex(&sha256(&b));
    edit(&mut b);
    let new = hex(&sha256(&b));
    assert_ne!(old, new, "the edit changes the table");
    std::fs::write(&fp, &b).unwrap();
    let mp = dir.join(manifest);
    let m = std::fs::read_to_string(&mp).unwrap();
    assert_eq!(m.matches(&old).count(), 1, "{manifest} names the table's digest once");
    std::fs::write(&mp, m.replace(&old, &new)).unwrap();
}

fn tied_err(export: &Path, tables: &Path, policy: &Policy) -> String {
    let p = load_export(export).unwrap();
    match load_tied_classifier_tables(&p, export, tables, policy) {
        Ok(_) => panic!("R-C2's loader accepted doctored tables"),
        Err(e) => e,
    }
}

/// a dev-rung recompute under the export's own profile digest
fn dev(export: &Path, tables: &Path, pol: &Policy) -> Result<TiedClassifier, String> {
    let x = TrainedExport::load(export).unwrap();
    recompute_tied_classifier(TiedSource::DevRung, export, tables, pol, x.residual_unit, D, &x.profile_sha256)
}

/// **The pinned tensor and the derivation** against the independent Python
/// reference (`r13/tools/dev_tied_reference.py` -> `r13/dev_tied_reference.json`):
/// the generator reproduces the pin; the derived embedding and margin row have
/// the reference's digests (the reference folds `g` in exactly once, no
/// rotation: requirement 5); BOS and the final norm are the export's
/// `token_io_parameters`; refused by name: a changed or short tensor, an export
/// without either parameter block, a rotation, a profile that is not the
/// statement's (requirement 2), an unregistered block profile.
#[test]
fn rc2_the_dev_tensor_is_pinned_and_the_tables_derive_with_r12bs_quantizer() {
    let t = dev_tied_tensor_bytes();
    assert_eq!(t.len(), 2 * (DEV_TIED_V * DEV_TIED_D + DEV_TIED_D));
    assert_eq!(hex(&sha256(&t)), DEV_TIED_TENSOR_SHA256, "the generator reproduces the pinned tensor");
    let cc = Cc::new("rc2-pin");
    let p = load_export(&cc.export).unwrap();
    assert_eq!(TiedSource::of(p.sh.profile).unwrap(), TiedSource::DevRung);
    let tied = dev(&cc.export, &cc.tables, &policy_rung_dev()).unwrap();
    assert_eq!(hex(&tied.emb_sha256), "c0e816c9f41a251df8560c5532d3f24c3b753ceb6ad712adcc7a893f71bfa475", "the embedding digest (Python reference)");
    let wb: Vec<u8> = tied.w.iter().flat_map(|x| x.to_le_bytes()).collect();
    assert_eq!(hex(&sha256(&wb)), "24e6ff4ca67bac45c810f78b72d967894b6806615206c5571842055ce20ef3c1", "the margin row's digest (Python reference)");
    assert_eq!(&tied.w[..8], &[740, -6269, -463, 1445, -12, 36, -43, -2606]);
    assert_eq!((tied.bos, tied.norm), (1, norm()), "BOS and the final norm are the export's token_io_parameters");
    assert_eq!(tied.margin, MarginParameters { yes: 40, no: 41, scale_bits: (1.0f64 / 256.0).to_bits(), c: 0 }, "the bound profile's classifier_margin_parameters");
    assert_eq!(tied.profile_sha256, p.model.calibration.export_profile_sha256, "the derivation read the statement's profile.json");
    // the honest files load through R-C2 and carry the recomputed row
    let b = load_tied_classifier_tables(&p, &cc.export, &cc.tables, &policy_rung_dev()).unwrap();
    assert_eq!((b.tables().w_delta.clone(), b.bos(), b.norm()), (tied.w.clone(), 1, norm()));
    assert!(b.is_derived() && b.model_identity() == p.model.identity() && b.profile_sha256() == p.model.calibration.export_profile_sha256, "round 14: bound to the export's trained statement");
    // the swapped export: the other row from the same tensor (about -w)
    let neg = dev(&cc.export_neg, &cc.tables_neg, &policy_rung_dev_swapped()).unwrap();
    assert_eq!(neg.emb_sha256, tied.emb_sha256);
    assert!(neg.w.iter().zip(&tied.w).all(|(a, b)| (i32::from(*a) + i32::from(*b)).abs() <= 1), "swapping yes / no negates the row (up to a half-up tie)");
    // requirement 2: a profile digest other than the statement's
    let x = TrainedExport::load(&cc.export).unwrap();
    let mut other = x.profile_sha256;
    other[0] ^= 1;
    let e = recompute_tied_classifier(TiedSource::DevRung, &cc.export, &cc.tables, &policy_rung_dev(), x.residual_unit, D, &other).unwrap_err();
    assert!(e.contains("not the profile the trained statement binds"), "{e}");
    // the tensor's pin, then its length
    let tp = cc.tables.join(DEV_TIED_TENSOR_FILE);
    let mut b = std::fs::read(&tp).unwrap();
    b[1001] ^= 1;
    std::fs::write(&tp, &b).unwrap();
    let e = dev(&cc.export, &cc.tables, &policy_rung_dev()).unwrap_err();
    assert!(e.contains("not the pinned development tensor"), "{e}");
    std::fs::write(&tp, &b[..b.len() - 2]).unwrap();
    assert!(dev(&cc.export, &cc.tables, &policy_rung_dev()).is_err(), "a short tensor is refused");
    std::fs::write(&tp, &t).unwrap();
    // both parameter blocks are required, and the rung has no rotation
    let bare = cc.root.join("bare");
    let (bare_export, _) = write_export(&bare, "tiny", &Fault::default());
    let e = dev(&bare_export, &cc.tables, &policy_rung_dev()).unwrap_err();
    assert!(e.contains("must supply classifier_margin_parameters"), "{e}");
    let pp = bare_export.join("profile.json");
    let text = std::fs::read_to_string(&pp).unwrap();
    let prefix = text.trim_end().strip_suffix('}').unwrap().to_string();
    std::fs::write(&pp, format!("{prefix}, \"classifier_margin_parameters\": {{\"yes_id\": 40, \"no_id\": 41, \"public_scale\": 0.00390625, \"threshold_c\": 0}}}}\n")).unwrap();
    let e = dev(&bare_export, &cc.tables, &policy_rung_dev()).unwrap_err();
    assert!(e.contains("must supply token_io_parameters"), "{e}");
    std::fs::write(&pp, text.replacen("\"metadata_out_of_proof\": {", "\"metadata_out_of_proof\": {\"rotation\": {\"kind\": \"block-hadamard\"}, ", 1)).unwrap();
    add_classifier_parameters(&bare_export, 1, norm(), &policy_rung_dev());
    // (the export loader is not asked: the derivation's own refusal is the point)
    let rot_sha = sha256(&std::fs::read(&pp).unwrap());
    let e = recompute_tied_classifier(TiedSource::DevRung, &bare_export, &cc.tables, &policy_rung_dev(), x.residual_unit, D, &rot_sha).unwrap_err();
    assert!(e.contains("no rotation"), "{e}");
    // an unregistered block profile has no tied source
    assert!(TiedSource::of("hashline-zk-mr1/no-such-block/1").unwrap_err().contains("no tied source"));
    eprintln!("TOKEN-IO R-C2 | req 2, 5 | dev tensor pinned (bba6d094…), embedding c0e816c9…, margin 24e6ff4c… = the Python reference | refused: another profile digest, changed / short tensor, missing parameter blocks, a rotation, an unregistered profile");
}

/// **Requirement 1: the ids, the scale and the threshold come only from the
/// bound profile.** A registered policy that disagrees with the export's
/// `classifier_margin_parameters` is refused (the swapped policy on the dev
/// export; a test policy with another scale; another c); a `classifier.json`
/// copy of a parameter that is not the profile's is refused even when the
/// tables are honest; at the CLI the prover refuses the swapped policy on the
/// dev export.
#[test]
fn rc2_the_margin_parameters_come_only_from_the_bound_profile() {
    let cc = Cc::new("rc2-params");
    let e = tied_err(&cc.export, &cc.tables_neg, &policy_rung_dev_swapped());
    assert!(e.contains("is not the export profile's classifier_margin_parameters"), "{e}");
    for pol in [Policy { id: "rc2-other-scale/1".into(), margin_scale_bits: (1.0f64 / 512.0).to_bits(), ..policy_rung_dev() }, Policy { id: "rc2-other-c/1".into(), c: 5, ..policy_rung_dev() }] {
        register_test_policy(pol.clone());
        let e = tied_err(&cc.export, &cc.tables, &pol);
        assert!(e.contains("is not the export profile's classifier_margin_parameters"), "{}: {e}", pol.id);
    }
    // classifier.json's copies: outside the profile digest, never an authority
    let cj = cc.tables.join("classifier.json");
    let honest = std::fs::read_to_string(&cj).unwrap();
    for (from, to) in [("\"yes_id\": 40", "\"yes_id\": 42"), ("\"no_id\": 41", "\"no_id\": 43"), ("\"threshold_c\": 0", "\"threshold_c\": 1"), ("\"scale\": 0.00390625", "\"scale\": 0.0078125")] {
        assert!(honest.contains(from), "{from} in {honest}");
        std::fs::write(&cj, honest.replacen(from, to, 1)).unwrap();
        let e = tied_err(&cc.export, &cc.tables, &policy_rung_dev());
        assert!(e.contains("is not the export profile's classifier_margin_parameters (the file is outside the profile digest"), "{from}: {e}");
    }
    std::fs::write(&cj, &honest).unwrap();
    let out = cc.root.join("run-swapped-on-dev");
    let cf = cc.content_file(&cc.content);
    let od = cc.owner_dir(&out);
    let code = super::classify_cli::classify_prove_command(&[
        "--export", cc.export.to_str().unwrap(), "--tables", cc.tables_neg.to_str().unwrap(), "--policy", super::classify_cli_tests::POLICY_RUNG_DEV_SWAPPED,
        "--content-file", cf.to_str().unwrap(), "--seq", "s0", "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap(),
    ].map(String::from));
    assert_eq!(code, 1, "a policy whose ids are not the export profile's is refused at the prover");
    assert!(!out.exists());
    eprintln!("TOKEN-IO R-C2 | req 1 | refused: a policy disagreeing with classifier_margin_parameters (ids, scale, c); classifier.json copies of yes_id / no_id / threshold_c / scale that are not the profile's");
}

/// **A doctored MARGIN ROW with a consistent manifest** (one word changed,
/// `classifier.json` rehashed): R-C1's reader accepts it (the gap); R-C2's
/// loader, the prover and the verifier refuse it; nothing is published.
/// Requirement 3.
#[test]
fn rc2_a_doctored_margin_row_with_a_consistent_manifest_is_refused() {
    let cc = Cc::new("rc2-margin");
    let honest = cc.root.join("run-honest");
    assert_eq!(cc.prove(&honest, &cc.tables), 0, "the honest dev rung proves");
    rehash(&cc.tables, "margin_int16.bin", "classifier.json", |b| b[10] ^= 0x04);
    assert!(load_classifier_tables(&cc.tables, D).is_ok(), "R-C1's reader accepts it: the manifest is consistent");
    let e = tied_err(&cc.export, &cc.tables, &policy_rung_dev());
    assert!(e.contains("margin_int16.bin is not the margin row recomputed"), "{e}");
    let forged = cc.root.join("run-forged");
    assert_eq!(cc.prove(&forged, &cc.tables), 1, "the prover refuses a margin row that is not the model's");
    assert!(!forged.exists() && !cc.owner_dir(&forged).exists(), "every claimed directory removed");
    assert_eq!(cc.verify(&honest, &cc.tables), 1, "a verifier handed the doctored tables refuses");
    assert!(!honest.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    eprintln!("TOKEN-IO R-C2 | req 3 | doctored margin row + rehashed classifier.json: R-C1 reader accepts; R-C2 loader, prover and verifier refuse");
}

/// **A doctored EMBEDDING with a consistent manifest** (a word of a row the
/// item never uses, `token_io.json` rehashed, so R-C1's parity still holds):
/// R-C1's reader accepts it; R-C2 refuses it at the prover and the verifier.
#[test]
fn rc2_a_doctored_embedding_with_a_consistent_manifest_is_refused() {
    let cc = Cc::new("rc2-emb");
    let honest = cc.root.join("run-honest");
    assert_eq!(cc.prove(&honest, &cc.tables), 0);
    rehash(&cc.tables, "embedding_int16.bin", "token_io.json", |b| b[200 * D * 2] ^= 0x01);
    assert!(load_classifier_tables(&cc.tables, D).is_ok(), "R-C1's reader accepts it");
    let e = tied_err(&cc.export, &cc.tables, &policy_rung_dev());
    assert!(e.contains("embedding_int16.bin is not the table derived from the pinned tied tensor"), "{e}");
    let forged = cc.root.join("run-forged");
    assert_eq!(cc.prove(&forged, &cc.tables), 1, "the prover refuses an embedding that is not the model's");
    assert_eq!(cc.verify(&honest, &cc.tables), 1, "the verifier refuses it");
    assert!(!honest.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    eprintln!("TOKEN-IO R-C2 | doctored embedding row 200 + rehashed token_io.json: R-C1 reader accepts; R-C2 prover and verifier refuse");
}

/// **A doctored FINAL NORM or BOS in `classifier.json`**: the authority is
/// the export's `token_io_parameters`; a different (in-class) `cn` or BOS is
/// refused by name at the prover. Moving the EXPORT's parameters instead
/// moves the trained statement identity, so the pinned verifier refuses
/// (requirement 2: the parameters live in the statement-bound profile).
#[test]
fn rc2_a_doctored_final_norm_or_bos_is_refused() {
    let cc = Cc::new("rc2-norm");
    let cj = cc.tables.join("classifier.json");
    let honest = std::fs::read_to_string(&cj).unwrap();
    assert!(honest.contains("\"cn\": 2048") && honest.contains("\"bos\": 1,"), "{honest}");
    std::fs::write(&cj, honest.replacen("\"cn\": 2048", "\"cn\": 2047", 1)).unwrap();
    assert!(load_classifier_tables(&cc.tables, D).is_ok(), "R-C1's reader accepts an in-class final norm");
    let e = tied_err(&cc.export, &cc.tables, &policy_rung_dev());
    assert!(e.contains("final_norm is not the export's token_io_parameters.classifier_final_norm"), "{e}");
    let forged = cc.root.join("run-cn");
    assert_eq!(cc.prove(&forged, &cc.tables), 1, "the prover refuses a final norm that is not the export's");
    std::fs::write(&cj, honest.replacen("\"bos\": 1,", "\"bos\": 2,", 1)).unwrap();
    let e = tied_err(&cc.export, &cc.tables, &policy_rung_dev());
    assert!(e.contains("bos 2 is not the export's token_io_parameters.bos 1"), "{e}");
    std::fs::write(&cj, &honest).unwrap();
    // the export's own parameters are statement-bound: a moved cn moves the identity
    let same = cc.root.join("same");
    let (sexp, _) = write_export(&same, "tiny", &Fault::default());
    add_classifier_parameters(&sexp, 1, norm(), &policy_rung_dev());
    assert_eq!(hex(&load_export(&sexp).unwrap().model.identity()), cc.identity, "the same parameters give the pinned identity");
    let moved = cc.root.join("moved");
    let (mexp, _) = write_export(&moved, "tiny", &Fault::default());
    add_classifier_parameters(&mexp, 1, FinalNorm { cn: 2047, ..norm() }, &policy_rung_dev());
    assert_ne!(hex(&load_export(&mexp).unwrap().model.identity()), cc.identity, "token_io_parameters are inside the trained statement identity the verifier pins");
    let moved_c = cc.root.join("moved-c");
    let (cexp, _) = write_export(&moved_c, "tiny", &Fault::default());
    add_classifier_parameters(&cexp, 1, norm(), &Policy { c: 5, ..policy_rung_dev() });
    assert_ne!(hex(&load_export(&cexp).unwrap().model.identity()), cc.identity, "classifier_margin_parameters are inside it too");
    eprintln!("TOKEN-IO R-C2 | req 2 | refused: classifier.json cn 2047 / bos 2 against the export's token_io_parameters; a moved export parameter (cn, c) moves the pinned identity");
}

/// **Requirement 4: a margin word beyond 32767 is a refusal, never a clamp**,
/// and it reaches the caller: an export whose bound scale is 2^-12 (the row's
/// largest word, 15305 at 2^-8, becomes about 244,880) is refused by the
/// derivation, the loader and the prover (R12b's own `quantize` message).
#[test]
fn rc2_a_margin_word_beyond_int16_is_refused_never_clamped() {
    let cc = Cc::new("rc2-overflow");
    let fine = Policy { id: "rc2-overflow-scale/1".into(), margin_scale_bits: (1.0f64 / 4096.0).to_bits(), ..policy_rung_dev() };
    register_test_policy(fine.clone());
    let root = cc.root.join("x-fine");
    let (export, _) = write_export(&root, "tiny", &Fault::default());
    add_classifier_parameters(&export, 1, norm(), &fine);
    let e = dev(&export, &cc.tables, &fine).unwrap_err();
    assert!(e.contains("quantization overflow (no clipping is permitted)"), "{e}");
    // the loader with honest-looking files (the dev row) propagates the same refusal
    let p = load_export(&export).unwrap();
    let e = load_tied_classifier_tables(&p, &export, &cc.tables, &fine).unwrap_err();
    assert!(e.contains("quantization overflow"), "{e}");
    let tables = cc.root.join("tables-fine");
    std::fs::create_dir_all(&tables).unwrap();
    std::fs::write(tables.join(DEV_TIED_TENSOR_FILE), dev_tied_tensor_bytes()).unwrap();
    let w = dev(&cc.export, &cc.tables, &policy_rung_dev()).unwrap().w;
    write_classifier_tables(&tables, &cc.t, &w, 1, norm(), &fine);
    super::classify_cli_tests::write_seq_files(&export, &cc.t.emb, &export.join("seq_s0"), &(1..=32).collect::<Vec<u64>>());
    let out = cc.root.join("run-overflow");
    let cf = cc.content_file(&cc.content);
    let od = cc.owner_dir(&out);
    let code = super::classify_cli::classify_prove_command(&["--export", export.to_str().unwrap(), "--tables", tables.to_str().unwrap(), "--policy", &fine.id, "--content-file", cf.to_str().unwrap(), "--seq", "s0", "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()].map(String::from));
    assert_eq!(code, 1, "the prover refuses (fail-closed)");
    assert!(!out.exists());
    eprintln!("TOKEN-IO R-C2 | req 4 | a bound scale 2^-12 overflows int16: refused by the derivation, the loader and the prover; never clamped");
}

/// **D27 at the classifier CLI**: `--min-bits` below the profile's floor is
/// refused (93 only at the development rung; 95 at every other profile).
#[test]
fn rc2_min_bits_below_the_profile_floor_is_refused() {
    assert_eq!(min_bits_floor(super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC), 93);
    assert_eq!(min_bits_floor("hashline-zk-mr1/private-classify-run-shieldstral-3b-t128/2"), 95, "production profiles: 95 (D27)");
    let cc = Cc::new("rc2-bits");
    let out = cc.root.join("run");
    assert_eq!(cc.prove(&out, &cc.tables), 0);
    assert_eq!(cc.verify_with(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &out, &cc.identity, "92"), 1, "below the development rung's floor");
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    assert_eq!(cc.verify_with(&cc.verifier_copy, &cc.tables, POLICY_RUNG_DEV, &out, &cc.identity, "93"), 0, "the rung's floor itself");
    eprintln!("TOKEN-IO R-C2 | --min-bits 92 refused at the rung (floor 93, dev only); production floor 95");
}

/// **The Shieldstral path through native R12b's `recompute_tied_tables`**
/// on the ACTUAL export (`ZK60_RC2_SHIELDSTRAL_EXPORT`: Astra's
/// `dg_r12b_t256`, read-only; its `token_io/` is the classifier tables
/// directory). One pass over the pinned 7.7 GB checkpoint with the card policy
/// (round 12's registered one; test-only since token round 16b, REVIEW_R16
/// F-1: the derivation does not consult the registry), whose ids, scale and c must equal the export profile's
/// `classifier_margin_parameters` (requirement 1): the embedding digest is
/// R12b's `reference_tables.json`, the row is R12b's
/// `policy_margin_reference.json` (requirements 3 / 5: the native row, the
/// final-norm weights and rotation folded in once), every file of the export's
/// tables equals the derivation; doctored copies are refused in memory.
#[test]
#[ignore = "streams the pinned 7.7 GB Shieldstral checkpoint through native R12b; run guarded with ZK60_RC2_SHIELDSTRAL_EXPORT"]
fn rc2_the_shieldstral_export_tables_are_recomputed_through_native_r12b() {
    let export = PathBuf::from(std::env::var_os("ZK60_RC2_SHIELDSTRAL_EXPORT").expect("ZK60_RC2_SHIELDSTRAL_EXPORT is not set"));
    let tables = export.join("token_io");
    assert_eq!(TiedSource::of(super::super::shape::SHIELDSTRAL_T256_TRAINED_PROFILE).unwrap(), TiedSource::Shieldstral);
    assert_eq!(TiedSource::of(super::super::shape::SHIELDSTRAL_T128_DD_TRAINED_PROFILE).unwrap(), TiedSource::Shieldstral);
    // the digest the trained statement would bind (sha256 of the profile bytes)
    let bound = sha256(&std::fs::read(export.join("profile.json")).unwrap());
    let card = policy_shieldstral_card();
    let t = std::time::Instant::now();
    let tied = recompute_tied_classifier(TiedSource::Shieldstral, &export, &tables, &card, 0.0, 3072, &bound).unwrap();
    let wsha = |w: &[i16]| hex(&sha256(&w.iter().flat_map(|x| x.to_le_bytes()).collect::<Vec<u8>>()));
    println!("RC2-SHIELDSTRAL card({},{}) scale {:e} emb {} margin {} min {} max {} bos {} norm {:?} in {:.1} s", card.yes, card.no, card.margin_scale(), hex(&tied.emb_sha256), wsha(&tied.w), tied.w.iter().min().unwrap(), tied.w.iter().max().unwrap(), tied.bos, tied.norm, t.elapsed().as_secs_f64());
    assert_eq!(tied.margin, MarginParameters { yes: 13059, no: 2649, scale_bits: 4.08288030735373e-6f64.to_bits(), c: 0 });
    assert_eq!(hex(&tied.emb_sha256), "baff04d2385ad49dcf9704384de268ce5aa5e16749d2af62c2101676538b5afe", "R12b reference_tables.json embedding");
    assert_eq!(wsha(&tied.w), "1f5cb3468ff4142fe5eee6afd989b2626afa9c12a2d49c877164a0ef7d7eb45f", "R12b policy_margin_reference.json");
    assert_eq!((*tied.w.iter().min().unwrap(), *tied.w.iter().max().unwrap()), (-32767, 31800), "R12b's counted span: zero refusals");
    assert_eq!((tied.bos, tied.norm), (1, FinalNorm { g0: 127, cn: 1024, tn: 10, ceps: 2439 }), "the export profile's token_io_parameters");
    // the export's own classifier tables, read by R-C1's reader, then compared
    let cj = super::super::trained_block::parse_json(&std::fs::read(tables.join("classifier.json")).unwrap()).unwrap();
    tied.margin.check_copies(&cj).expect("classifier.json's copies are the profile's");
    let (files, bos, nm, emb_sha) = read_classifier_files(&tables, 3072).unwrap();
    check_files_against(&tied, &files.w_delta, &emb_sha, bos, nm).expect("the export's tables are the derivation");
    let mut w = files.w_delta.clone();
    w[0] ^= 1;
    assert!(check_files_against(&tied, &w, &emb_sha, bos, nm).unwrap_err().contains("margin_int16.bin is not the margin row recomputed"));
    let mut e = emb_sha;
    e[0] ^= 1;
    assert!(check_files_against(&tied, &files.w_delta, &e, bos, nm).unwrap_err().contains("embedding_int16.bin is not the table derived"));
    assert!(check_files_against(&tied, &files.w_delta, &emb_sha, 2, nm).unwrap_err().contains("bos 2"));
    assert!(check_files_against(&tied, &files.w_delta, &emb_sha, bos, FinalNorm { cn: 1023, ..nm }).unwrap_err().contains("final_norm"));
    let other = Policy { id: "rc2-shieldstral-other-scale/1".into(), margin_scale_bits: 4.0e-6f64.to_bits(), ..policy_shieldstral_card() };
    let err = recompute_tied_classifier(TiedSource::Shieldstral, &export, &tables, &other, 0.0, 3072, &bound).unwrap_err();
    assert!(err.contains("is not the export profile's classifier_margin_parameters"), "{err} (refused before any checkpoint read)");
    println!("RC2-SHIELDSTRAL honest export tables PASS; doctored margin / embedding digest / bos / final norm and another scale REFUSED");
}

/// **ROUND 14 (REVIEW_R13 N-r13-2): the POST-derivation profile digest check
/// is load-bearing.** At Shieldstral the token lane reads `profile.json` once
/// (the statement's digest), then native R12b's recompute reads it AGAIN with
/// the checkpoint. A recompute that read another profile (here a stub standing
/// in for R12b, returning a calibration whose `profile_sha256` is another
/// file's: the file swapped between the two reads) must be refused, even
/// though the first read was the bound one; the same stub returning the bound
/// digest is accepted. Removing the check (classify_tied.rs, "requirement 2,
/// after the derivation's own read") turns this test red (round-14 mutation
/// run `mut-n2`).
#[test]
fn r14_the_post_derivation_profile_digest_check_refuses_a_derivation_that_read_another_profile() {
    use super::super::tied_tables::{RecomputedTiedTables, TiedFinalNorm, TiedTokenCalibration};
    let root = super::classify_cli_tests::fixture_root().join(format!("r14-n2-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    let (export, tables) = (root.join("export"), root.join("tables"));
    std::fs::create_dir_all(&export).unwrap();
    std::fs::create_dir_all(&tables).unwrap();
    let card = policy_shieldstral_card();
    let profile = format!("{{\"kind\": \"r14-n2-stub-profile\", \"classifier_margin_parameters\": {{\"yes_id\": {}, \"no_id\": {}, \"public_scale\": {:?}, \"threshold_c\": {}}}}}\n", card.yes, card.no, card.margin_scale(), card.c);
    std::fs::write(export.join("profile.json"), &profile).unwrap();
    let bound = sha256(profile.as_bytes());
    let mut swapped = bound;
    swapped[0] ^= 1;
    let stub = |profile_sha256: [u8; 32]| -> Box<dyn Fn(&Path, (u32, u32, f64)) -> Result<RecomputedTiedTables, String>> {
        Box::new(move |_export: &Path, m: (u32, u32, f64)| {
            assert_eq!(m, (13059, 2649, 4.08288030735373e-6), "the recompute is asked for the bound profile's margin parameters");
            let fnm = TiedFinalNorm { g0: 127, cn: 1024, tn: 10, ceps: 2439 };
            Ok(RecomputedTiedTables { embedding_sha256: [3; 32], head_sha256: [4; 32], multipliers_sha256: [5; 32], margin: Some(vec![7i16; 3072]), calibration: TiedTokenCalibration { bos: 1, classifier_final_norm: fnm.clone(), head_final_norm: fnm, profile_sha256 } })
        })
    };
    {
        let _g = stub_shieldstral_recompute(stub(swapped));
        let e = recompute_tied_classifier(TiedSource::Shieldstral, &export, &tables, &card, 0.0, 3072, &bound).err().expect("A DERIVATION THAT READ ANOTHER profile.json WAS ACCEPTED (N-r13-2)");
        assert!(e.contains("the derivation read a profile.json other than the one the trained statement binds"), "{e}");
    }
    {
        let _g = stub_shieldstral_recompute(stub(bound));
        let t = recompute_tied_classifier(TiedSource::Shieldstral, &export, &tables, &card, 0.0, 3072, &bound).expect("the same stub with the bound digest");
        assert_eq!((t.w.len(), t.profile_sha256, t.bos), (3072, bound, 1));
    }
    let _ = std::fs::remove_dir_all(&root);
    eprintln!("TOKEN-IO R14 | N-r13-2 | a Shieldstral-path derivation that read another profile.json is refused by the post-derivation check; the bound one is accepted");
}
