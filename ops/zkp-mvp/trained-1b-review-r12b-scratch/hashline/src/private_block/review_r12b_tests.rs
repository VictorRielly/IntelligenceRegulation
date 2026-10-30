//! **D24 REVIEW ROUND 11 (independent review lane, 2026-10-28): the short fix
//! check of native R12b (tree 51de5b83).** TEST CODE ONLY, in the reviewer's
//! scratch copy; public data only (the pinned public checkpoint and public
//! synthetic exports). Not a privacy review.
//!
//! * D' (R12-F1/F2, no checkpoint): R12's attack D — short tables with
//!   consistent manifests, no dtype/shape — and every mis-declared dtype /
//!   shape are refused before any derivation;
//! * D2' (R12-F2, no checkpoint): a table that is a symbolic link (to a file
//!   elsewhere, to /dev/zero), a FIFO, or a name that leaves token_io/ is
//!   refused by name, and the FIFO does not block;
//! * C' (R12-F3): the `--rope-from-export` opt-in is refused at every
//!   Shieldstral geometry on both load paths (load_layer and the stack
//!   verifier's reload_block), before any layer read;
//! * F1 (ignored; ZK60_REVIEW_R12B_FIXTURE = the reviewer's own honest fixture
//!   written by results/zk60_d24_review_20261017/r12b/r12b_tied_reference.py):
//!   the honest tables are accepted with the digests of my independent
//!   transcription; one-byte embedding / head / multiplier forgeries with
//!   rehashed manifests, a plausible uniform multiplier table, an all-zero
//!   embedding of the exact size, and a moved embedding scale are refused as
//!   not derived; every token_io_parameters class / BOS / TOCTOU / checkpoint
//!   path attack is refused; the public API's policy margin equals my
//!   transcription and half the scale refuses (no clamp).

use super::shape::SHIELDSTRAL_T128_TRAINED_PROFILE;
use super::trained_block::{hex, parse_json, sha256, tied_of, Geometry, TrainedExport};
use super::trained_statement::{tied_tensor_for_profile, ModelSource};
use std::path::{Path, PathBuf};

const EMB: &str = "baff04d2385ad49dcf9704384de268ce5aa5e16749d2af62c2101676538b5afe";
const HEAD: &str = "786f02bc011e3f23c4e9ac480772a0413d39f8d10c7259000929ada771d0ce95";
const MULT: &str = "f43790f32bd4cf4b252aafaa08e9b788937a0878594d2756f73248b0dfdc0464";
const POLICY_MARGIN: &str = "1f5cb3468ff4142fe5eee6afd989b2626afa9c12a2d49c877164a0ef7d7eb45f";
const POLICY: (u32, u32, f64) = (13059, 2649, 4.08288030735373e-06);
const EMB_LEN: u64 = 131072 * 3072 * 2;
const HEAD_LEN: u64 = 131072 * 3072;
const MULT_LEN: u64 = 131072 * 8;

fn pin_profile() -> (String, String, String) {
    let (name, digest) = tied_tensor_for_profile(SHIELDSTRAL_T128_TRAINED_PROFILE).unwrap();
    let dg = hex(&digest);
    let p = format!(r#"{{"tied_embeddings": {{"tensor": "{name}", "sha256": "{dg}"}}}}"#);
    (name.to_string(), dg, p)
}

/// write the two manifests; `meta` = (embedding, head, multiplier) dtype/shape
/// JSON fragments (empty = none, as in R12's attack D)
fn manifests(td: &Path, name: &str, dg: &str, emb_file: &str, sha: (&str, &str, &str), meta: (&str, &str, &str)) {
    std::fs::write(td.join("token_io.json"), format!(r#"{{"embedding_table": {{"file": "{emb_file}", {} "sha256": "{}", "source_tensor": {{"name": "{name}", "sha256": "{dg}"}}}}}}"#, meta.0, sha.0)).unwrap();
    std::fs::write(td.join("head_manifest.json"), format!(r#"{{"head_int8_perrow.bin": {{{} "sha256": "{}"}}, "head_mult12.bin": {{{} "sha256": "{}"}}, "source_tensor": {{"name": "{name}", "sha256": "{dg}"}}}}"#, meta.1, sha.1, meta.2, sha.2)).unwrap();
}

const GOOD_META: (&str, &str, &str) = (r#""dtype": "int16", "shape": [131072, 3072],"#, r#""dtype": "int8", "shape": [131072, 3072],"#, r#""dtype": "int64", "shape": [131072],"#);

// ------------------------------------------------------------------ D'

#[test]
fn review_r12b_d_short_or_misdeclared_tables_are_refused_before_derivation() {
    let (name, dg, pj) = pin_profile();
    let profile = parse_json(pj.as_bytes()).unwrap();
    let src = ModelSource::shieldstral_1_0_3b();
    let root = super::trained_block_tests::base_dir("review-r12b-d");
    let td = root.join("token_io");
    std::fs::create_dir_all(&td).unwrap();
    let (e, h, m): (&[u8], &[u8], &[u8]) = (b"not emb", b"head1", b"mlt");
    std::fs::write(td.join("embedding_int16.bin"), e).unwrap();
    std::fs::write(td.join("head_int8_perrow.bin"), h).unwrap();
    std::fs::write(td.join("head_mult12.bin"), m).unwrap();
    let sha = (hex(&sha256(e)), hex(&sha256(h)), hex(&sha256(m)));
    let s = (sha.0.as_str(), sha.1.as_str(), sha.2.as_str());
    let mut seen = Vec::new();
    // R12's attack D verbatim (no dtype/shape), then each mis-declaration
    let cases: [(&str, (&str, &str, &str), &str); 6] = [
        ("R12 attack D (no dtype/shape)", ("", "", ""), "dtype"),
        ("declared right, 7/5/3-byte files", GOOD_META, "expected exactly 805306368"),
        ("embedding shape 131072x3071", (r#""dtype": "int16", "shape": [131072, 3071],"#, GOOD_META.1, GOOD_META.2), "dtype/shape"),
        ("embedding dtype int8", (r#""dtype": "int8", "shape": [131072, 3072],"#, GOOD_META.1, GOOD_META.2), "dtype/shape"),
        ("head dtype int16", (GOOD_META.0, r#""dtype": "int16", "shape": [131072, 3072],"#, GOOD_META.2), "dtype/shape"),
        ("multipliers shape 131071", (GOOD_META.0, GOOD_META.1, r#""dtype": "int64", "shape": [131071],"#), "dtype/shape"),
    ];
    for (what, meta, want) in cases {
        manifests(&td, &name, &dg, "embedding_int16.bin", s, meta);
        for g in [Geometry::Shieldstral(128), Geometry::ShieldstralDd(256)] {
            let err = tied_of(&root, &profile, g, &src).err().unwrap_or_else(|| panic!("{what}: accepted at {g:?}"));
            assert!(err.contains(want), "{what}: {err}");
            seen.push(format!("{what}: {}", err.chars().take(110).collect::<String>()));
        }
    }
    // R12's second step: the head swapped for other bytes, manifest updated
    std::fs::write(td.join("head_int8_perrow.bin"), b"HEAD2").unwrap();
    let h2 = hex(&sha256(b"HEAD2"));
    manifests(&td, &name, &dg, "embedding_int16.bin", (s.0, h2.as_str(), s.2), GOOD_META);
    assert!(tied_of(&root, &profile, Geometry::ShieldstralDd(128), &src).is_err(), "the swapped head loaded");
    let _ = std::fs::remove_dir_all(&root);
    for l in &seen {
        eprintln!("REVIEW-R12B D refused: {l}");
    }
    eprintln!("REVIEW-R12B D: {} short / mis-declared table cases refused at Shieldstral T128 and T256-DD; the R12 swapped head refused", seen.len());
}

// ------------------------------------------------------------------ D2'

#[test]
fn review_r12b_d2_links_fifos_devices_and_escaping_names_are_refused_without_blocking() {
    let (name, dg, pj) = pin_profile();
    let src = ModelSource::shieldstral_1_0_3b();
    let root = super::trained_block_tests::base_dir("review-r12b-d2");
    let td = root.join("token_io");
    std::fs::create_dir_all(&td).unwrap();
    let elsewhere = root.join("elsewhere.bin");
    std::fs::write(&elsewhere, b"outside token_io").unwrap();
    std::fs::write(td.join("head_int8_perrow.bin"), b"h").unwrap();
    std::fs::write(td.join("head_mult12.bin"), b"m").unwrap();
    let any = hex(&sha256(b"outside token_io"));
    let (hh, mh) = (hex(&sha256(b"h")), hex(&sha256(b"m")));
    let emb = td.join("embedding_int16.bin");
    let reset = || {
        let _ = std::fs::remove_file(&emb);
    };
    let run = |what: &str, want: &str, file: &str| -> String {
        manifests(&td, &name, &dg, file, (any.as_str(), hh.as_str(), mh.as_str()), GOOD_META);
        let (r, p) = (root.clone(), pj.clone());
        let src2 = src.clone();
        let h = std::thread::spawn(move || tied_of(&r, &parse_json(p.as_bytes()).unwrap(), Geometry::Shieldstral(256), &src2).map(|_| ()));
        let t0 = std::time::Instant::now();
        while !h.is_finished() && t0.elapsed().as_secs_f64() < 3.0 {
            std::thread::sleep(std::time::Duration::from_millis(20));
        }
        let finished = h.is_finished();
        if !finished && Path::new(&td.join(file)).exists() {
            // release a blocked FIFO reader so the test can end, then fail
            let _ = std::fs::OpenOptions::new().write(true).open(td.join(file));
        }
        let res = h.join().unwrap();
        assert!(finished, "{what}: the loader blocked for 3 s");
        let err = res.err().unwrap_or_else(|| panic!("{what}: accepted"));
        assert!(err.contains(want), "{what}: {err}");
        format!("{what} -> {} ({:.3} s)", err.chars().take(120).collect::<String>(), t0.elapsed().as_secs_f64())
    };
    let mut seen = Vec::new();
    reset();
    std::os::unix::fs::symlink(&elsewhere, &emb).unwrap();
    seen.push(run("a symbolic link to a file outside token_io/", "not a regular file", "embedding_int16.bin"));
    reset();
    std::os::unix::fs::symlink("/dev/zero", &emb).unwrap();
    seen.push(run("a symbolic link to /dev/zero", "not a regular file", "embedding_int16.bin"));
    reset();
    assert!(std::process::Command::new("mkfifo").arg(&emb).status().map(|s| s.success()).unwrap_or(false), "mkfifo");
    seen.push(run("a FIFO", "not a regular file", "embedding_int16.bin"));
    reset();
    std::fs::write(root.join("escape.bin"), b"outside token_io").unwrap();
    seen.push(run("a file name that leaves token_io/", "", "../escape.bin"));
    let _ = std::fs::remove_dir_all(&root);
    for l in &seen {
        eprintln!("REVIEW-R12B D2 refused: {l}");
    }
}

// ------------------------------------------------------------------ C'

#[test]
fn review_r12b_c_rope_opt_in_is_refused_at_every_shieldstral_geometry_on_both_load_paths() {
    use super::rope::RopeScaling;
    use super::trained_block_tests::{base_dir, write_export, Fault};
    let geos = [Geometry::Shieldstral(128), Geometry::Shieldstral(256), Geometry::ShieldstralDd(128), Geometry::ShieldstralDd(256)];
    for g in geos {
        assert_eq!(g.rope_scaling(), RopeScaling::shieldstral(), "{g:?}: the pin is not YaRN");
    }
    let dir = base_dir("review-r12b-rope");
    // an export whose RoPE tables are OFF the generator (R12's attack C)
    let (vdir, _) = write_export(&dir, "rope-off", &Fault { rope_offset: true, ..Default::default() });
    let mut ex = TrainedExport::load(&vdir).expect("the export loads");
    let c = ex.run_constants(&[0]).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    // unscaled profile: the opt-in still proves the export's tables (R12 C,
    // pre-existing since R2 for the base; residual, see the review)
    assert!(ex.load_layer(&sh, &c, 0, true).is_ok());
    // with the pinned Shieldstral transform the opt-in is refused on both paths
    ex.rope_scaling = RopeScaling::shieldstral();
    let e1 = ex.load_layer(&sh, &c, 0, true).err().expect("load_layer accepted the opt-in at a pinned transform");
    let e2 = ex.reload_block(&sh, &c, 0, true).err().expect("reload_block accepted the opt-in at a pinned transform");
    assert!(e1.contains("pinned RoPE transform") && e2.contains("pinned RoPE transform"), "{e1} / {e2}");
    // without the opt-in the loader compares with the generator as before
    let e3 = ex.load_layer(&sh, &c, 0, false).err().expect("tables off the generator loaded without the opt-in");
    assert!(e3.contains("--rope-from-export"), "{e3}");
    eprintln!("REVIEW-R12B C: the four Shieldstral geometries pin YaRN; the opt-in is refused on load_layer and reload_block ({e1}); without it the generator comparison stands");
}

// ------------------------------------------------------------------ F1 (fixture)

fn fixture() -> PathBuf {
    PathBuf::from(std::env::var_os("ZK60_REVIEW_R12B_FIXTURE").expect("ZK60_REVIEW_R12B_FIXTURE"))
}

fn flip(path: &Path, offset: u64) -> u8 {
    use std::io::{Read, Seek, SeekFrom, Write};
    let mut f = std::fs::OpenOptions::new().read(true).write(true).open(path).unwrap();
    let mut b = [0u8];
    f.seek(SeekFrom::Start(offset)).unwrap();
    f.read_exact(&mut b).unwrap();
    f.seek(SeekFrom::Start(offset)).unwrap();
    f.write_all(&[b[0] ^ 1]).unwrap();
    b[0]
}

fn put(path: &Path, offset: u64, v: &[u8]) {
    use std::io::{Seek, SeekFrom, Write};
    let mut f = std::fs::OpenOptions::new().write(true).open(path).unwrap();
    f.seek(SeekFrom::Start(offset)).unwrap();
    f.write_all(v).unwrap();
}

fn replace_once(text: &str, old: &str, new: &str) -> String {
    assert_eq!(text.matches(old).count(), 1, "`{old}` is not unique");
    text.replacen(old, new, 1)
}

/// a variant export: its own profile text, everything else hard-linked to the
/// fixture (regular files, no copy); `emb` replaces the embedding table
fn variant(fx: &Path, tag: &str, profile: &str, emb: Option<&dyn Fn(&Path)>) -> PathBuf {
    let v = fx.parent().unwrap().join("variants").join(tag);
    let _ = std::fs::remove_dir_all(&v);
    std::fs::create_dir_all(v.join("token_io")).unwrap();
    std::fs::write(v.join("profile.json"), profile).unwrap();
    std::fs::hard_link(fx.join("rotation_sign.bin"), v.join("rotation_sign.bin")).unwrap();
    for f in ["head_int8_perrow.bin", "head_mult12.bin", "head_manifest.json", "token_io.json", "embedding_int16.bin"] {
        if f == "embedding_int16.bin" && emb.is_some() {
            continue;
        }
        std::fs::hard_link(fx.join("token_io").join(f), v.join("token_io").join(f)).unwrap();
    }
    if let Some(write) = emb {
        std::fs::remove_file(v.join("token_io/token_io.json")).unwrap();
        write(&v.join("token_io"));
    }
    v
}

#[test]
#[ignore = "full pinned checkpoint reads (nine derivation passes); run guarded with ZK60_REVIEW_R12B_FIXTURE"]
fn review_r12b_f1_derivation_accepts_my_honest_tables_and_refuses_every_forgery() {
    use super::tied_tables::{hash_regular_exact, recompute_tied_tables, tied_token_calibration};
    let fx = fixture();
    let src = ModelSource::shieldstral_1_0_3b();
    let g = Geometry::Shieldstral(256);
    let text = std::fs::read_to_string(fx.join("profile.json")).unwrap();
    let profile = parse_json(text.as_bytes()).unwrap();
    let t0 = std::time::Instant::now();
    let mut log: Vec<String> = Vec::new();
    let mut note = |s: String| {
        eprintln!("REVIEW-R12B F1 [{:7.1} s] {s}", t0.elapsed().as_secs_f64());
        log.push(s);
    };

    // 1. my independently written honest tables are accepted, digests = mine = Sol's = Astra's
    let t = tied_of(&fx, &profile, g, &src).expect("my honest fixture").expect("a record");
    assert_eq!((hex(&t.embedding_table_sha256), hex(&t.head_table_sha256), hex(&t.head_mult_sha256)), (EMB.to_string(), HEAD.to_string(), MULT.to_string()));
    assert_eq!(t.tensor_sha256, tied_tensor_for_profile(SHIELDSTRAL_T128_TRAINED_PROFILE).unwrap().1);
    note(format!("honest accepted: {} {} {}", &EMB[..8], &HEAD[..8], &MULT[..8]));

    // 2-5. one-byte / plausible forgeries with their manifest digests updated
    let td = fx.join("token_io");
    let forge = |file: &str, manifest: &str, len: u64, old_hex: &str, edit: &dyn Fn(&Path) -> Vec<u8>| -> String {
        let path = td.join(file);
        let man = td.join(manifest);
        let original_manifest = std::fs::read_to_string(&man).unwrap();
        let undo = edit(&path);
        let new_hex = hex(&hash_regular_exact(&path, len).unwrap());
        assert_ne!(new_hex, old_hex);
        std::fs::write(&man, replace_once(&original_manifest, old_hex, &new_hex)).unwrap();
        let r = tied_of(&fx, &profile, g, &src);
        // restore before asserting
        if undo.len() == len as usize {
            std::fs::write(&path, &undo).unwrap();
        } else {
            put(&path, u64::from_le_bytes(undo[..8].try_into().unwrap()), &undo[8..]);
        }
        std::fs::write(&man, &original_manifest).unwrap();
        assert_eq!(hex(&hash_regular_exact(&path, len).unwrap()), old_hex, "{file} not restored");
        let e = r.err().unwrap_or_else(|| panic!("{file}: a rehashed forgery was accepted"));
        assert!(e.contains("not derived from the pinned tensor"), "{file}: {e}");
        e
    };
    let at = |offset: u64| -> Box<dyn Fn(&Path) -> Vec<u8>> {
        Box::new(move |p: &Path| {
            let old = flip(p, offset);
            let mut u = offset.to_le_bytes().to_vec();
            u.push(old);
            u
        })
    };
    let e = forge("embedding_int16.bin", "token_io.json", EMB_LEN, EMB, &*at(EMB_LEN - 2));
    note(format!("embedding: last word of the last row flipped, manifest rehashed -> {e}"));
    let e = forge("head_int8_perrow.bin", "head_manifest.json", HEAD_LEN, HEAD, &*at(12_345 * 3072 + 7));
    note(format!("head: one byte of row 12345 flipped, manifest rehashed -> {e}"));
    let e = forge("head_mult12.bin", "head_manifest.json", MULT_LEN, MULT, &|p: &Path| {
        let off = 4242 * 8;
        let b = std::fs::read(p).unwrap();
        let m = i64::from_le_bytes(b[off..off + 8].try_into().unwrap());
        put(p, off as u64, &(m + 1).to_le_bytes());
        let mut u = (off as u64).to_le_bytes().to_vec();
        u.extend_from_slice(&b[off..off + 8]);
        u
    });
    note(format!("multipliers: row 4242 m -> m+1, manifest rehashed -> {e}"));
    let e = forge("head_mult12.bin", "head_manifest.json", MULT_LEN, MULT, &|p: &Path| {
        let b = std::fs::read(p).unwrap();
        let uniform: Vec<u8> = (0..131072).flat_map(|_| 4096i64.to_le_bytes()).collect();
        std::fs::write(p, uniform).unwrap();
        b
    });
    note(format!("multipliers: a plausible uniform table (all 4096), manifest rehashed -> {e}"));

    // 6. an all-zero embedding of the exact size (R12's attack D at the right size)
    let zero_emb = |vtd: &Path| {
        let f = std::fs::File::create(vtd.join("embedding_int16.bin")).unwrap();
        f.set_len(EMB_LEN).unwrap();
        let z = hex(&hash_regular_exact(&vtd.join("embedding_int16.bin"), EMB_LEN).unwrap());
        let ti = std::fs::read_to_string(fx.join("token_io/token_io.json")).unwrap();
        std::fs::write(vtd.join("token_io.json"), replace_once(&ti, EMB, &z)).unwrap();
    };
    let v = variant(&fx, "zero-embedding", &text, Some(&zero_emb as &dyn Fn(&Path)));
    let e = tied_of(&v, &profile, g, &src).err().expect("an all-zero embedding with a consistent manifest was accepted");
    assert!(e.contains("tied embedding") && e.contains("not derived"), "{e}");
    note(format!("all-zero embedding of exact size, consistent manifest -> {e}"));

    // 7. the embedding scale moved in the profile: the tables no longer derive
    let moved = {
        let i = text.find("\"residual_scales_in\"").unwrap();
        let j = i + text[i..].find("0.0035486477726047977").unwrap();
        format!("{}0.0035487{}", &text[..j], &text[j + "0.0035486477726047977".len()..])
    };
    let v = variant(&fx, "moved-scale", &moved, None);
    let e = tied_of(&v, &parse_json(moved.as_bytes()).unwrap(), g, &src).err().expect("tables accepted under another embedding scale");
    assert!(e.contains("tied embedding") && e.contains("not derived"), "{e}");
    note(format!("residual_scales_in[0] 0.0035486477726047977 -> 0.0035487 (relative 6.4e-6) -> {e}"));

    // 8. token_io_parameters: absence, BOS, class and consistency attacks (refused before the checkpoint)
    let tail = text.find("\"token_io_parameters\"").unwrap();
    let edit_tail = |old: &str, new: &str| -> String {
        let (a, b) = text.split_at(tail);
        assert!(b.contains(old), "{old}");
        format!("{a}{}", b.replacen(old, new, 1))
    };
    let cut = text.find(",\n  \"token_io_parameters\"").unwrap();
    let cases: Vec<(&str, String, &str)> = vec![
        ("token_io_parameters absent", format!("{}\n}}\n", &text[..cut]), "must supply token_io_parameters"),
        ("bos 2", edit_tail("\"bos\": 1", "\"bos\": 2"), "BOS"),
        ("classifier tn 9", edit_tail("\"tn\": 10", "\"tn\": 9"), "classifier_final_norm requires tn=10"),
        ("head tn 8 (export norm_tn 9)", edit_tail("\"tn\": 9", "\"tn\": 8"), "differ from the export calibration"),
        ("classifier g0 126", edit_tail("\"g0\": 127", "\"g0\": 126"), "outside its declared class"),
        ("head ceps 2440", edit_tail("\"ceps\": 2439\n    }\n  }", "\"ceps\": 2440\n    }\n  }"), "differ from the export calibration"),
        ("classifier cn 0", edit_tail("\"cn\": 1024", "\"cn\": 0"), "outside its declared class"),
    ];
    for (k, (what, ptext, want)) in cases.iter().enumerate() {
        let v = variant(&fx, &format!("params-{k}"), ptext, None);
        let e = tied_of(&v, &parse_json(ptext.as_bytes()).unwrap(), g, &src).err().unwrap_or_else(|| panic!("{what}: accepted"));
        assert!(e.contains(want), "{what}: {e}");
        note(format!("{what} -> {e}"));
    }
    // TOCTOU: the parsed profile the statement was built from differs from the file
    let bos2 = edit_tail("\"bos\": 1", "\"bos\": 2");
    let e = tied_of(&fx, &parse_json(bos2.as_bytes()).unwrap(), g, &src).err().expect("a profile differing from the file was accepted");
    assert!(e.contains("changed before tied-table derivation"), "{e}");
    note(format!("statement profile != file -> {e}"));

    // 10. checkpoint path attacks (refused before any tensor read)
    let real = "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors";
    let base = fx.parent().unwrap().join("variants");
    std::fs::create_dir_all(&base).unwrap();
    let link = base.join("model-link.safetensors");
    let _ = std::fs::remove_file(&link);
    std::os::unix::fs::symlink(real, &link).unwrap();
    let sparse = base.join("sparse.safetensors");
    std::fs::File::create(&sparse).unwrap().set_len(7_698_241_104).unwrap();
    let decl = "\"tensor\": \"language_model.model.embed_tokens.weight\",";
    for (k, (what, path, want)) in [
        ("a symbolic link to the real checkpoint", link.display().to_string(), "not a regular file"),
        ("another real file (consolidated.safetensors, 7,698,234,952 B)", "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/consolidated.safetensors".to_string(), "expected exactly 7698241104"),
        ("a sparse file of the exact length", sparse.display().to_string(), "header length out of bounds"),
        ("a missing path", base.join("missing").display().to_string(), "No such file"),
    ].iter().enumerate() {
        let ptext = replace_once(&text, decl, &format!("{decl}\n    \"checkpoint_file\": \"{path}\","));
        let v = variant(&fx, &format!("ckpt-{k}"), &ptext, None);
        let e = tied_of(&v, &parse_json(ptext.as_bytes()).unwrap(), g, &src).err().unwrap_or_else(|| panic!("{what}: accepted"));
        assert!(e.contains(want), "{what}: {e}");
        note(format!("checkpoint_file = {what} -> {e}"));
    }
    std::fs::remove_file(&sparse).unwrap();
    std::fs::remove_file(&link).unwrap();

    // 11. the public API: policy margin = my transcription; calibration is the profile's
    let r = recompute_tied_tables(&fx, Some(POLICY)).expect("the policy margin");
    assert_eq!((hex(&r.embedding_sha256), hex(&r.head_sha256), hex(&r.multipliers_sha256)), (EMB.to_string(), HEAD.to_string(), MULT.to_string()));
    let margin = r.margin.clone().unwrap();
    let mb: Vec<u8> = margin.iter().flat_map(|x| x.to_le_bytes()).collect();
    assert_eq!(mb, std::fs::read(fx.join("token_io/margin_policy_int16.bin")).unwrap(), "the native margin is not my transcription");
    assert_eq!(hex(&sha256(&mb)), POLICY_MARGIN);
    assert_eq!((margin.iter().min().copied(), margin.iter().max().copied()), (Some(-32767), Some(31800)));
    assert_eq!(r.calibration.profile_sha256, sha256(text.as_bytes()));
    assert_eq!(r.calibration.bos, 1);
    let cal = tied_token_calibration(&fx).unwrap();
    assert_eq!(cal, r.calibration);
    assert_eq!((cal.classifier_final_norm.g0, cal.classifier_final_norm.cn, cal.classifier_final_norm.tn, cal.classifier_final_norm.ceps), (127, 1024, 10, 2439));
    assert_eq!((cal.head_final_norm.g0, cal.head_final_norm.cn, cal.head_final_norm.tn, cal.head_final_norm.ceps), (127, 512, 9, 2439));
    note(format!("API margin (13059, 2649, 4.08288030735373e-6) = my transcription {} (min -32767, max 31800); calibration = profile (bos 1, cls 127/1024/10/2439, head 127/512/9/2439)", &POLICY_MARGIN[..8]));
    // 12. fail closed: half the scale refuses, never clamps
    let e = recompute_tied_tables(&fx, Some((POLICY.0, POLICY.1, POLICY.2 / 2.0))).err().expect("half the scale was accepted (clamped?)");
    assert!(e.contains("no clipping"), "{e}");
    note(format!("API margin at half the scale -> {e}"));
    // 13. argument refusals (before the checkpoint)
    for (what, m) in [("yes == no", (13059, 13059, POLICY.2)), ("yes out of vocabulary", (131072, 2649, POLICY.2)), ("scale 0", (13059, 2649, 0.0)), ("scale -1", (13059, 2649, -1.0)), ("scale NaN", (13059, 2649, f64::NAN)), ("scale inf", (13059, 2649, f64::INFINITY))] {
        let e = recompute_tied_tables(&fx, Some(m)).err().unwrap_or_else(|| panic!("{what}: accepted"));
        note(format!("API {what} -> {e}"));
    }
    let _ = std::fs::remove_dir_all(fx.parent().unwrap().join("variants"));
    // the fixture is back to my honest bytes
    assert_eq!(hex(&hash_regular_exact(&td.join("embedding_int16.bin"), EMB_LEN).unwrap()), EMB);
    assert_eq!(hex(&hash_regular_exact(&td.join("head_int8_perrow.bin"), HEAD_LEN).unwrap()), HEAD);
    assert_eq!(hex(&hash_regular_exact(&td.join("head_mult12.bin"), MULT_LEN).unwrap()), MULT);
    eprintln!("REVIEW-R12B F1: {} checks passed in {:.1} s", log.len(), t0.elapsed().as_secs_f64());
}
