//! **NATIVE LANE (2026-10-17): THE EXPORT READER, ON A TINY EXPORT THIS TEST
//! WRITES ITSELF.** TEST CODE ONLY.
//!
//! The calibration lane owns the export WRITER; until a real export exists,
//! this module writes an export in the declared format
//! (`zk60-trained-profile-export/1`) at the trained-calibration development
//! rung (`geometry: rung-tc-t32-dev`, a SYNTHETIC source) — dense public words,
//! a generic hidden input, and `x_out` from the native witness — and drives
//! the reader, its refusals, the parity check and the CLI bridge end to end.
//! With `ZK60_NATIVE_TINY_EXPORT_DIR` set the export (and the CLI artifact)
//! is written there for the record; otherwise into a fresh temporary
//! directory. Public synthetic data only; the hidden input is synthetic.

use super::layout::*;
use super::shape::{NormCalibration, Shape};
use super::trained_block::*;
use super::witness;
use super::*;
use std::path::{Path, PathBuf};

pub(super) fn base_dir(tag: &str) -> PathBuf {
    let root = match std::env::var_os("ZK60_NATIVE_TINY_EXPORT_DIR") {
        Some(d) => PathBuf::from(d),
        None => std::env::temp_dir().join(format!("zk60-native-tiny-{}-{}", std::process::id(), std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos())),
    };
    let d = root.join(tag);
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn i8_bytes(v: &[i8]) -> Vec<u8> {
    v.iter().map(|x| *x as u8).collect()
}
fn i16_bytes(v: &[i16]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}
fn i64_bytes(v: &[i64]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

/// the constants object of `profile.json` / a layer manifest
fn constants_json(cal: &NormCalibration, f_e: u32, overrides: &[(&str, &str)]) -> String {
    let mut kv: Vec<(String, String)> = vec![
        ("norm_tn".into(), cal.tn.to_string()),
        ("norm_cn_a".into(), cal.cn_a.to_string()),
        ("norm_cn_m".into(), cal.cn_m.to_string()),
        ("norm_ceps".into(), cal.ceps.to_string()),
        // ROUND 2: the calibration's own windowed shifts
        ("sh_qkv".into(), cal.sh_qkv.to_string()),
        ("sh_rope".into(), "7".into()),
        ("sh_s".into(), cal.sh_s.to_string()),
        ("sh_o".into(), cal.sh_o.to_string()),
        ("sh_ao".into(), cal.sh_ao.to_string()),
        ("sh_g".into(), cal.sh_g.to_string()),
        ("sh_u".into(), "0".into()),
        ("sh_h".into(), cal.sh_h.to_string()),
        ("sh_z".into(), cal.sh_z.to_string()),
        ("f_e".into(), f_e.to_string()),
        ("f_p".into(), "9".into()),
        ("f_ro".into(), "7".into()),
        ("sh_r2".into(), "0".into()),
        ("silu_member".into(), "[-3, -11]".into()),
        ("exp_e_s".into(), "0".into()),
        ("rope_theta".into(), "10000.0".into()),
    ];
    for (k, v) in overrides {
        kv.iter_mut().find(|(x, _)| x == k).expect("an override of a known key").1 = (*v).to_string();
    }
    format!("{{{}}}", kv.iter().map(|(k, v)| format!("\"{k}\": {v}")).collect::<Vec<_>>().join(", "))
}

/// What the writer was asked to perturb (each refusal test sets one).
#[derive(Default, Clone)]
pub(super) struct Fault {
    pub(super) profile_constant: Vec<(&'static str, &'static str)>,
    pub(super) layer_constant: Vec<(&'static str, &'static str)>,
    pub(super) bad_sha_of: Option<&'static str>,
    pub(super) shape_of_wk: Option<&'static str>,
    pub(super) file_name_of_wo: Option<&'static str>,
    pub(super) model_repo: Option<&'static str>,
    pub(super) geometry: Option<&'static str>,
    pub(super) exp_shift: bool,
    pub(super) rope_offset: bool,
    pub(super) x_out_flip: bool,
    /// write `null` for these profile constants and list them as per-layer
    pub(super) profile_nulls: Vec<&'static str>,
    /// list these in `per_layer_constants_differ` (default: the nulls)
    pub(super) differ_list: Option<Vec<&'static str>>,
    /// a wrong `manifest_sha256` for layer 0 in profile.json
    pub(super) bad_layer_manifest_digest: bool,
    /// write the raw sequence files without the sequence manifest
    pub(super) no_seq_manifest: bool,
    /// the `variant` profile.json names (default: the directory's name)
    pub(super) variant_name: Option<&'static str>,
}

/// Write a tiny export (one layer, one sequence) under `dir/variant/`.
/// Returns the variant directory and the generated words' block digest.
pub(super) fn write_export(dir: &Path, variant: &str, fault: &Fault) -> (PathBuf, Digest) {
    let cal = super::trained_calib_tests::rung_tc_calibration();
    let sh = Shape::rung_tc(&cal).unwrap();
    let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    let wit = witness::build_shaped(&sh, &public, &ff, &input).unwrap();
    let ids = Ids::new(&sh).unwrap();
    let mut x_out: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| wit.planes[ids.at(A_X2)][t * sh.d_pad + i] as i16).collect();
    if fault.x_out_flip {
        x_out[5] = x_out[5].wrapping_add(1);
    }
    let vdir = dir.join(variant);
    let ldir = vdir.join("layer_00");
    let sdir = vdir.join("seq_s0");
    std::fs::create_dir_all(&ldir).unwrap();
    std::fs::create_dir_all(&sdir).unwrap();
    let (d, f, kvw) = (sh.width, sh.hidden, sh.kv_heads * sh.head_dim);
    let mut exp = public.exp.clone();
    if fault.exp_shift {
        // still a valid (monotone) table, but not the member the profile names
        assert_ne!(exp[1], exp[2], "the fault must change the table");
        exp[1] = exp[2];
    }
    let (mut cos, sin) = (public.rope_cos.clone(), public.rope_sin.clone());
    if fault.rope_offset {
        let k = cos.len() - 1;
        cos[k] += if cos[k] < 128 { 1 } else { -1 };
    }
    let arrays: Vec<(&str, Vec<u8>, &str, String)> = vec![
        ("wq", i8_bytes(&w[0]), "int8", format!("[{d}, {d}]")),
        ("wk", i8_bytes(&w[1]), "int8", fault.shape_of_wk.map(String::from).unwrap_or(format!("[{kvw}, {d}]"))),
        ("wv", i8_bytes(&w[2]), "int8", format!("[{kvw}, {d}]")),
        ("wo", i8_bytes(&w[3]), "int8", format!("[{d}, {d}]")),
        ("gamma_a", i8_bytes(&w[4]), "int8", format!("[{d}]")),
        ("gamma_m", i8_bytes(&w[5]), "int8", format!("[{d}]")),
        ("wg_t", i8_bytes(&w[6]), "int8", format!("[{d}, {f}]")),
        ("wu_t", i8_bytes(&w[7]), "int8", format!("[{d}, {f}]")),
        ("wd_t", i8_bytes(&w[8]), "int8", format!("[{f}, {d}]")),
        ("exp", i64_bytes(&exp), "int64", "[256]".into()),
        ("act", i16_bytes(&ff.act), "int16", "[256]".into()),
        ("rope_cos", i64_bytes(&cos), "int64", format!("[{}, {}]", sh.tokens, sh.head_dim / 2)),
        ("rope_sin", i64_bytes(&sin), "int64", format!("[{}, {}]", sh.tokens, sh.head_dim / 2)),
    ];
    let mut entries = Vec::new();
    for (name, bytes, dtype, shape) in &arrays {
        let file = if *name == "wo" { fault.file_name_of_wo.unwrap_or("wo.bin").to_string() } else { format!("{name}.bin") };
        if !file.contains('/') {
            std::fs::write(ldir.join(&file), bytes).unwrap();
        }
        let mut sha = hex(&sha256(bytes));
        if fault.bad_sha_of == Some(*name) {
            sha = hex(&sha256(b"not the file"));
        }
        entries.push(format!("\"{name}\": {{\"file\": \"{file}\", \"dtype\": \"{dtype}\", \"shape\": {shape}, \"sha256\": \"{sha}\"}}"));
    }
    let manifest = format!("{{\"layer\": 0, \"constants\": {}, \"arrays\": {{{}}}}}\n", constants_json(&cal, sh.f_e, &fault.layer_constant), entries.join(", "));
    std::fs::write(ldir.join("manifest.json"), &manifest).unwrap();
    let (xi, xo) = (i16_bytes(&input), i16_bytes(&x_out));
    std::fs::write(sdir.join("x_in_L00.bin"), &xi).unwrap();
    std::fs::write(sdir.join("x_out_L00.bin"), &xo).unwrap();
    if !fault.no_seq_manifest {
        let arr = |name: &str, b: &[u8]| format!("\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"int16\", \"shape\": [{}, {}], \"sha256\": \"{}\"}}", sh.tokens, sh.width, hex(&sha256(b)));
        std::fs::write(sdir.join("manifest.json"), format!("{{\"kind\": \"sequence\", \"id\": \"s0\", \"T\": 32, \"arrays\": {{{}, {}}}}}\n", arr("x_in_L00", &xi), arr("x_out_L00", &xo))).unwrap();
    }
    // the profile, in the calibration lane's writer's shape: profile
    // constants (with `null` where per-layer), the per-layer list, the tool's
    // per-file digests, and layer objects carrying their manifest digest
    let mut pc = constants_json(&cal, sh.f_e, &fault.profile_constant);
    for k in &fault.profile_nulls {
        let start = pc.find(&format!("\"{k}\": ")).unwrap() + k.len() + 4;
        let end = pc[start..].find(", \"").map(|e| start + e).unwrap_or(pc.len() - 1);
        pc.replace_range(start..end, "null");
    }
    let differ: Vec<String> = fault.differ_list.clone().unwrap_or_else(|| fault.profile_nulls.clone()).iter().map(|k| format!("\"{k}\"")).collect();
    let msha = if fault.bad_layer_manifest_digest { hex(&sha256(b"another manifest")) } else { hex(&sha256(manifest.as_bytes())) };
    let profile = format!(
        "{{\"schema\": \"zk60-trained-profile-export/1\", \"kind\": \"profile\", \"variant\": \"{}\", \"geometry\": \"{}\", \"model\": {{\"repo\": \"{}\", \"revision\": \"native-tiny-export\", \"sha256\": \"{}\"}}, \"calibration_tool\": {{\"path\": \"native-lane\", \"sha256\": {{\"trained_block_tests.rs\": \"{}\", \"trained_block.rs\": \"{}\"}}}}, \"T\": 32, \"profile_constants\": {}, \"per_layer_constants_differ\": [{}], \"layers\": [{{\"layer\": 0, \"dir\": \"layer_00\", \"manifest_sha256\": \"{msha}\"}}], \"sequences\": [\"seq_s0\"], \"metadata_out_of_proof\": {{\"residual_scale_s_x\": 0.0053663705198366135}}}}\n",
        fault.variant_name.unwrap_or(variant),
        fault.geometry.unwrap_or("rung-tc-t32-dev"),
        fault.model_repo.unwrap_or("synthetic/native-tiny-export"),
        hex(&sha256(b"synthetic words")),
        hex(&sha256(b"the writer")),
        hex(&sha256(b"the reader")),
        pc,
        differ.join(", ")
    );
    std::fs::write(vdir.join("profile.json"), profile).unwrap();
    (vdir, blk.digest())
}

/// The reader round-trips the export: same shape, same public statement
/// digest, the statement binds the profile and manifest digests, and parity
/// holds.
#[test]
fn the_reader_round_trips_a_tiny_export_and_binds_its_digests() {
    let dir = base_dir("round-trip");
    let (vdir, digest) = write_export(&dir, "tiny-v1", &Fault::default());
    let ex = TrainedExport::load(&vdir).expect("the export loads");
    assert_eq!(ex.geometry, Geometry::RungTcDev);
    let c = ex.run_constants(&[0]).expect("the run's constants");
    let sh = ex.shape_for(&c).expect("the shape");
    assert_eq!(sh, Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap());
    let layer = ex.load_layer(&sh, &c, 0, false).expect("the layer loads");
    assert_eq!(layer.blk.digest(), digest, "the loaded public statement is not the writer's");
    assert!(layer.rope_note.contains("equal to the export's tables"), "{}", layer.rope_note);
    let st = ex.statement(&sh, &c, &[&layer]).expect("the statement");
    assert_eq!(st.calibration.export_profile_sha256, sha256(&std::fs::read(vdir.join("profile.json")).unwrap()));
    assert_eq!(st.layers[0].manifest_sha256, sha256(&std::fs::read(vdir.join("layer_00/manifest.json")).unwrap()));
    // a byte of profile.json that changes nothing the reader parses still
    // moves the statement identity
    let p = std::fs::read_to_string(vdir.join("profile.json")).unwrap();
    std::fs::write(vdir.join("profile.json"), p.replace("{\"schema\"", "{ \"schema\"")).unwrap();
    let ex2 = TrainedExport::load(&vdir).unwrap();
    let st2 = ex2.statement(&sh, &c, &[&ex2.load_layer(&sh, &c, 0, false).unwrap()]).unwrap();
    assert_ne!(st.identity(), st2.identity(), "the profile digest is not bound");
    // parity: the native witness reproduces x_out
    let (x_in, x_out) = ex.load_seq(&sh, "s0", 0).unwrap();
    parity(&sh, &layer.blk, &x_in, &x_out).expect("bit-exact parity");
}

/// Every malformed export is refused, by name.
#[test]
fn every_malformed_export_is_refused_by_name() {
    let dir = base_dir("refusals");
    let cases: Vec<(&str, Fault, &str)> = vec![
        ("a fixed shift other than the code's", Fault { profile_constant: vec![("sh_rope", "8")], ..Default::default() }, "hold it at 7"),
        ("a windowed shift outside its window", Fault { profile_constant: vec![("sh_qkv", "9")], layer_constant: vec![("sh_qkv", "9")], ..Default::default() }, "structure-preserving window"),
        ("a window that needs a fifth limb", Fault { profile_constant: vec![("norm_tn", "12")], layer_constant: vec![("norm_tn", "12")], ..Default::default() }, "exceeds four byte limbs"),
        ("a Cn outside the class", Fault { profile_constant: vec![("norm_cn_m", "2000000")], layer_constant: vec![("norm_cn_m", "2000000")], ..Default::default() }, "outside the declared class"),
        ("layer constants that differ from uniform profile constants", Fault { layer_constant: vec![("norm_cn_a", "1337")], ..Default::default() }, "one calibration per run"),
        ("a null profile constant the per-layer list does not name", Fault { profile_nulls: vec!["norm_cn_a"], differ_list: Some(vec![]), ..Default::default() }, "per_layer_constants_differ names"),
        ("a layer manifest that is not the one profile.json records", Fault { bad_layer_manifest_digest: true, ..Default::default() }, "is not profile.json's"),
        ("a wrong array digest", Fault { bad_sha_of: Some("wd_t"), ..Default::default() }, "SHA-256 mismatch"),
        ("a wrong array shape", Fault { shape_of_wk: Some("[384, 128]"), ..Default::default() }, "expected"),
        ("a traversing file name", Fault { file_name_of_wo: Some("../wo.bin"), ..Default::default() }, "not a plain file name"),
        ("a TinyLlama geometry with a synthetic source", Fault { geometry: Some("tinyllama-1.1b-t32"), ..Default::default() }, "pinned TinyLlama source"),
        ("a rung geometry naming a non-synthetic source", Fault { model_repo: Some("TinyLlama/TinyLlama-1.1B-Chat-v1.0"), ..Default::default() }, "synthetic source"),
        ("an exp table that is not the named member", Fault { exp_shift: true, ..Default::default() }, "exp table is not exp_member"),
        ("RoPE tables off the generator", Fault { rope_offset: true, ..Default::default() }, "--rope-from-export"),
        ("an unknown silu member", Fault { profile_constant: vec![("silu_member", "[-7, -7]")], layer_constant: vec![("silu_member", "[-7, -7]")], ..Default::default() }, "frozen SiLU registry"),
        // review finding F-1 and its general rule: every constant an export
        // chooses has a declared class, refused at the door by name
        ("f_e 50 (the reviewer's forgery value)", Fault { profile_constant: vec![("f_e", "50")], layer_constant: vec![("f_e", "50")], ..Default::default() }, "review finding F-1"),
        ("f_e 8, below the class", Fault { profile_constant: vec![("f_e", "8")], layer_constant: vec![("f_e", "8")], ..Default::default() }, "outside its declared class"),
        ("f_e 17, declared per layer", Fault { profile_nulls: vec!["f_e"], layer_constant: vec![("f_e", "17")], ..Default::default() }, "review finding F-1"),
        ("an exp e_s outside its class", Fault { profile_constant: vec![("exp_e_s", "9")], layer_constant: vec![("exp_e_s", "9")], ..Default::default() }, "exp_e_s 9 is outside its declared class"),
        ("another RoPE base", Fault { profile_constant: vec![("rope_theta", "500000.0")], layer_constant: vec![("rope_theta", "500000.0")], ..Default::default() }, "RoPE base"),
        ("a variant name that is not a plain name (F-4)", Fault { variant_name: Some("../elsewhere"), ..Default::default() }, "variant"),
    ];
    for (k, (name, fault, want)) in cases.into_iter().enumerate() {
        let (vdir, _) = write_export(&dir, &format!("bad-{k}"), &fault);
        let r = TrainedExport::load(&vdir).and_then(|ex| {
            let c = ex.run_constants(&[0])?;
            let sh = ex.shape_for(&c)?;
            ex.load_layer(&sh, &c, 0, false).map(|_| ())
        });
        let e = r.expect_err(&format!("`{name}` was ACCEPTED"));
        assert!(e.contains(want), "`{name}`: the refusal does not say `{want}`: {e}");
        eprintln!("NATIVE loader refusal ({name}): {}", e.chars().take(140).collect::<String>());
    }
    // the RoPE mismatch is accepted only when the caller opts in, and says so
    let (vdir, _) = write_export(&dir, "rope-opt-in", &Fault { rope_offset: true, ..Default::default() });
    let ex = TrainedExport::load(&vdir).unwrap();
    let c = ex.run_constants(&[0]).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    let l = ex.load_layer(&sh, &c, 0, true).expect("opted in");
    assert!(l.rope_note.contains("EXPORT's tables") && l.rope_note.contains("1 entries"), "{}", l.rope_note);
    // per-layer constants (null in the profile, named in the per-layer list):
    // a one-block run takes its layer's manifest constants
    let (vdir, digest) = write_export(&dir, "per-layer", &Fault { profile_nulls: vec!["norm_cn_a", "norm_ceps"], ..Default::default() });
    let ex = TrainedExport::load(&vdir).expect("a per-layer export loads");
    assert!(ex.constants.is_none() && ex.per_layer_differ == vec!["norm_ceps".to_string(), "norm_cn_a".to_string()]);
    let c = ex.run_constants(&[0]).unwrap();
    assert_eq!(c.cal, super::trained_calib_tests::rung_tc_calibration());
    assert_eq!(ex.load_layer(&ex.shape_for(&c).unwrap(), &c, 0, false).unwrap().blk.digest(), digest);
    // the raw sequence files are read when the writer gives no manifest
    let (vdir, _) = write_export(&dir, "no-seq-manifest", &Fault { no_seq_manifest: true, ..Default::default() });
    let ex = TrainedExport::load(&vdir).unwrap();
    let c = ex.run_constants(&[0]).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    let l = ex.load_layer(&sh, &c, 0, false).unwrap();
    let (xi, xo) = ex.load_seq(&sh, "s0", 0).unwrap();
    parity(&sh, &l.blk, &xi, &xo).expect("parity from the raw files");
    // a layer the profile does not list
    let (vdir, _) = write_export(&dir, "no-layer-1", &Fault::default());
    let ex = TrainedExport::load(&vdir).unwrap();
    assert!(ex.run_constants(&[1]).err().expect("layer 1 loaded").contains("not in profile.json's layer list"));
}

/// Parity reports a mismatch by count and position, never by value.
#[test]
fn parity_reports_a_mismatch_by_count_and_position() {
    let dir = base_dir("parity");
    let (vdir, _) = write_export(&dir, "flip", &Fault { x_out_flip: true, ..Default::default() });
    let ex = TrainedExport::load(&vdir).unwrap();
    let c = ex.run_constants(&[0]).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    let layer = ex.load_layer(&sh, &c, 0, false).unwrap();
    let (x_in, x_out) = ex.load_seq(&sh, "s0", 0).unwrap();
    let e = parity(&sh, &layer.blk, &x_in, &x_out).err().expect("a flipped word passed parity");
    assert!(e.contains("in 1 of") && e.contains("token 0, channel 5"), "{e}");
}

/// THE CLI BRIDGE END TO END on the tiny export: prove (with the
/// inconsistent-witness controls), then verify in the same process from the
/// written files with every statement and receipt control; a wrong statement
/// pin is refused.
#[test]
fn the_cli_proves_and_verifies_the_tiny_export_with_every_control() {
    let dir = base_dir("cli");
    let (vdir, _) = write_export(&dir, "tiny-v1", &Fault::default());
    let out = dir.join("artifact");
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let vd = vdir.display().to_string();
    let od = out.display().to_string();
    assert_eq!(trained_prove_command(&s(&["--export", &vd, "--layer", "0", "--seq", "s0", "--out", &od, "--controls"])), 0, "prove failed");
    let stmt = std::fs::read_to_string(out.join("statement.json")).unwrap();
    for k in ["\"norm_tn\": 10", "\"norm_cn_a\": 1336", "\"norm_cn_m\": 2158", "\"norm_ceps\": 33554467", "\"sh_ao\": 6"] {
        assert!(stmt.contains(k), "statement.json does not carry {k}");
    }
    let id = stmt.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string();
    assert_eq!(trained_verify_command(&s(&["--export", &vd, "--layer", "0", "--artifact", &od, "--expect-statement", &id, "--controls"])), 0, "verify failed");
    let wrong = hex(&sha256(b"another statement"));
    assert_eq!(trained_verify_command(&s(&["--export", &vd, "--layer", "0", "--artifact", &od, "--expect-statement", &wrong])), 1, "a wrong statement pin was accepted");
    assert_eq!(trained_prove_command(&s(&["--export", &vd, "--layer", "0", "--seq", "s0", "--out", &od])), 1, "an existing output directory was overwritten");
}

/// **READER COMPATIBILITY WITH A REAL EXPORT'S LAYERS** (heavy, release):
/// for every layer of the variant directory `ZK60_NATIVE_EXPORT_DIR`, the
/// run constants, the shape, every array digest, the table cross-checks and
/// the padded public statement. Then, because a smoke export carries no
/// sequence data, the TRAINED WEIGHTS of the first layer are run on
/// SYNTHETIC hidden inputs of a few magnitudes (admissibility only; which
/// site refuses is reported), and the first admissible one is PROVED and
/// verified from bytes. Synthetic input: NOT the trained-block milestone.
#[test]
#[ignore = "native lane heavy: reads a real export (env ZK60_NATIVE_EXPORT_DIR)"]
fn native_t5_a_real_exports_layers_load_and_its_trained_weights_prove() {
    let dir = PathBuf::from(std::env::var_os("ZK60_NATIVE_EXPORT_DIR").expect("ZK60_NATIVE_EXPORT_DIR"));
    let ex = TrainedExport::load(&dir).expect("the export's profile loads");
    eprintln!("NATIVE T5-pre: {} layers {:?}, per-layer constants {:?}, tool {}", ex.variant, ex.layers, ex.per_layer_differ, hex(&ex.tool_sha256));
    let mut first: Option<(Shape, super::trained_block::TrainedLayer)> = None;
    for &l in &ex.layers.clone() {
        let c = ex.run_constants(&[l]).unwrap_or_else(|e| panic!("layer {l}: {e}"));
        let sh = ex.shape_for(&c).unwrap_or_else(|e| panic!("layer {l}: {e}"));
        let t0 = std::time::Instant::now();
        let layer = ex.load_layer(&sh, &c, l, false).unwrap_or_else(|e| panic!("layer {l}: {e}"));
        eprintln!(
            "NATIVE T5-pre layer {l}: loaded in {:.2} s; calibration {} f_e {} silu {:?} e_s {} window {} D_max {}; rope: {}; block digest {}",
            t0.elapsed().as_secs_f64(),
            c.cal.describe(),
            c.f_e,
            layer.record.silu_member,
            layer.record.exp_e_s,
            sh.norm_wrho,
            sh.d_max,
            layer.rope_note,
            hex(&layer.blk.digest())
        );
        if first.is_none() {
            first = Some((sh, layer));
        }
    }
    let (sh, layer) = first.expect("a layer");
    let ids = Ids::new(&sh).unwrap();
    let mut proved = false;
    for xmag in [64i64, 512, 2048, 8192] {
        let input = super::dense_tests::dense_hidden_input(&sh, xmag);
        match witness::build_shaped(&sh, layer.blk.attention(), layer.blk.feed_forward(), &input) {
            Err(e) => eprintln!("NATIVE T5-pre trained weights, synthetic input |x| <= {xmag}: REFUSED at {e}"),
            Ok(w) => {
                let m = |p: usize| w.planes[ids.at(p)].iter().map(|v| v.abs()).max().unwrap_or(0);
                eprintln!(
                    "NATIVE T5-pre trained weights, synthetic input |x| <= {xmag}: ADMISSIBLE; max|y_a| {} |q8| {} |s8| {} |g8| {} |u16| {} |z16| {} |x2| {}",
                    m(A_Y),
                    m(A_Q8),
                    m(A_S8),
                    m(A_G8),
                    m(A_U16),
                    m(A_Z16),
                    m(A_X2)
                );
                if !proved {
                    // ROUND 2 (R2-4): a one-block run bound to a synthetic
                    // statement (the input is synthetic; the weights are the
                    // export's)
                    let t0 = std::time::Instant::now();
                    let b = super::trained_calib_tests::prove_one_bound(&sh, &layer.blk, w).expect("the trained-weight block proves");
                    let prove_s = t0.elapsed().as_secs_f64();
                    let bytes = b.seg.clone();
                    let t1 = std::time::Instant::now();
                    super::trained_calib_tests::verify_one_bound(&sh, &layer.blk, &b.expected.to_bytes(), &bytes).expect("verifies from bytes");
                    eprintln!(
                        "NATIVE T5-pre PROVED layer {} with TRAINED weights on a SYNTHETIC input (|x| <= {xmag}): prove {prove_s:.2} s, verify {:.2} s, receipt {} B, VmHWM {:.0} MiB",
                        layer.index,
                        t1.elapsed().as_secs_f64(),
                        bytes.len(),
                        super::run::peak_rss_mib()
                    );
                    proved = true;
                }
            }
        }
    }
}
