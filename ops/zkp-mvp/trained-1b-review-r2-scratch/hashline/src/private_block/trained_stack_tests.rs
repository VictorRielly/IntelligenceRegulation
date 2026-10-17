//! **NATIVE LANE, round 2 (R2-3): THE STACK CLI ON A SMALL MULTI-LAYER
//! EXPORT THIS TEST WRITES ITSELF.** TEST CODE ONLY.
//!
//! A three-layer export at the trained-calibration development rung
//! (`geometry: rung-tc-t32-dev`, a SYNTHETIC source): each layer has its own
//! words AND its own per-block tables (exp `e_s` and SiLU member alternate,
//! as in the calibration lane's pg_rot1 export), and the sequence chains
//! (`x_in` of layer k+1 is `x_out` of layer k, from the native witness). The
//! production `stack-prove` / `stack-verify` bridge then proves all layers
//! as ONE bound run, verifies it in a separate call from the directory, and
//! every run-level control refuses; the prover-side `--lie-at-boundary`
//! control fails to verify as it must. Public synthetic data only.

use super::layout::*;
use super::shape::Shape;
use super::trained_block::*;
use super::trained_block_tests::base_dir;
use super::witness;
use super::*;
use std::path::{Path, PathBuf};

fn i8_bytes(v: &[i8]) -> Vec<u8> {
    v.iter().map(|x| *x as u8).collect()
}
fn i16_bytes(v: &[i16]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}
fn i64_bytes(v: &[i64]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

/// the per-block table keys of layer `k` (alternating, all in their classes)
fn keys(k: usize) -> (i32, (i32, i32)) {
    if k % 2 == 0 {
        (0, (-3, -11))
    } else {
        (1, (-4, -12))
    }
}

/// the public statement of nine true-size words with THESE tables
fn statement_with_tables(s: &Shape, w: &[Vec<i8>; 9], e_s: i32, silu: (i32, i32)) -> (AttentionPublic, FeedForwardPublic, Vec<i64>, Vec<i16>) {
    let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
    let (exp, _) = crate::tables_attn::exp_member(e_s, s.head_dim, s.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, silu.0, silu.1).expect("a frozen SiLU member");
    let aw = super::grow_tests::pad_attention_weights(s, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let fw = super::grow_tests::pad_ff_weights(s, &w[5], &w[6], &w[7], &w[8]);
    let public = AttentionPublic::new_shaped(s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("the attention statement");
    let ff = FeedForwardPublic::new_shaped(s, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("the feed-forward statement");
    (public, ff, exp.to_vec(), act.to_vec())
}

/// Write an `n`-layer chained export under `dir/variant/`. Returns the
/// variant directory.
fn write_stack_export(dir: &Path, variant: &str, n: usize) -> PathBuf {
    let cal = super::trained_calib_tests::rung_tc_calibration();
    let sh = Shape::rung_tc(&cal).unwrap();
    let ids = Ids::new(&sh).unwrap();
    let (w0, mut x) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let vdir = dir.join(variant);
    let sdir = vdir.join("seq_s0");
    std::fs::create_dir_all(&sdir).unwrap();
    let (d, f, kvw) = (sh.width, sh.hidden, sh.kv_heads * sh.head_dim);
    let mut layer_objs = Vec::new();
    let mut seq_arrays = Vec::new();
    for k in 0..n {
        // this layer's own words: the dense recipe, rotated per layer
        let mut w = w0.clone();
        for (i, m) in w.iter_mut().enumerate() {
            let len = m.len();
            m.rotate_left((k * (7 + i)) % len);
        }
        let (e_s, silu) = keys(k);
        let (public, ff, exp, act) = statement_with_tables(&sh, &w, e_s, silu);
        let wit = witness::build_shaped(&sh, &public, &ff, &x).unwrap_or_else(|e| panic!("layer {k}: the honest chained witness: {e}"));
        let x_out: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| wit.planes[ids.at(A_X2)][t * sh.d_pad + i] as i16).collect();
        let ldir = vdir.join(format!("layer_{k:02}"));
        std::fs::create_dir_all(&ldir).unwrap();
        let arrays: Vec<(&str, Vec<u8>, &str, String)> = vec![
            ("wq", i8_bytes(&w[0]), "int8", format!("[{d}, {d}]")),
            ("wk", i8_bytes(&w[1]), "int8", format!("[{kvw}, {d}]")),
            ("wv", i8_bytes(&w[2]), "int8", format!("[{kvw}, {d}]")),
            ("wo", i8_bytes(&w[3]), "int8", format!("[{d}, {d}]")),
            ("gamma_a", i8_bytes(&w[4]), "int8", format!("[{d}]")),
            ("gamma_m", i8_bytes(&w[5]), "int8", format!("[{d}]")),
            ("wg_t", i8_bytes(&w[6]), "int8", format!("[{d}, {f}]")),
            ("wu_t", i8_bytes(&w[7]), "int8", format!("[{d}, {f}]")),
            ("wd_t", i8_bytes(&w[8]), "int8", format!("[{f}, {d}]")),
            ("exp", i64_bytes(&exp), "int64", "[256]".into()),
            ("act", i16_bytes(&act), "int16", "[256]".into()),
        ];
        let entries: Vec<String> = arrays
            .iter()
            .map(|(name, bytes, dtype, shape)| {
                std::fs::write(ldir.join(format!("{name}.bin")), bytes).unwrap();
                format!("\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"{dtype}\", \"shape\": {shape}, \"sha256\": \"{}\"}}", hex(&sha256(bytes)))
            })
            .collect();
        let consts = constants(&cal, sh.f_e, e_s, silu);
        let manifest = format!("{{\"layer\": {k}, \"constants\": {consts}, \"arrays\": {{{}}}}}\n", entries.join(", "));
        std::fs::write(ldir.join("manifest.json"), &manifest).unwrap();
        layer_objs.push(format!("{{\"layer\": {k}, \"dir\": \"layer_{k:02}\", \"manifest_sha256\": \"{}\"}}", hex(&sha256(manifest.as_bytes()))));
        let (xi, xo) = (i16_bytes(&x), i16_bytes(&x_out));
        for (name, b) in [(format!("x_in_L{k:02}"), &xi), (format!("x_out_L{k:02}"), &xo)] {
            std::fs::write(sdir.join(format!("{name}.bin")), b).unwrap();
            seq_arrays.push(format!("\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"int16\", \"shape\": [{}, {}], \"sha256\": \"{}\"}}", sh.tokens, sh.width, hex(&sha256(b))));
        }
        x = x_out;
    }
    std::fs::write(sdir.join("manifest.json"), format!("{{\"kind\": \"sequence\", \"id\": \"s0\", \"T\": 32, \"arrays\": {{{}}}}}\n", seq_arrays.join(", "))).unwrap();
    // the profile: run-level constants uniform, the table keys per layer
    let pc = constants(&cal, sh.f_e, 0, (-3, -11)).replace("\"silu_member\": [-3, -11]", "\"silu_member\": null").replace("\"exp_e_s\": 0", "\"exp_e_s\": null");
    let profile = format!(
        "{{\"schema\": \"zk60-trained-profile-export/1\", \"kind\": \"profile\", \"variant\": \"{variant}\", \"geometry\": \"rung-tc-t32-dev\", \"model\": {{\"repo\": \"synthetic/native-stack-export\", \"revision\": \"native-round-2\", \"sha256\": \"{}\"}}, \"calibration_tool\": {{\"path\": \"native-lane\", \"sha256\": {{\"trained_stack_tests.rs\": \"{}\"}}}}, \"T\": 32, \"profile_constants\": {pc}, \"per_layer_constants_differ\": [\"exp_e_s\", \"silu_member\"], \"layers\": [{}], \"sequences\": [\"seq_s0\"]}}\n",
        hex(&sha256(b"synthetic stack words")),
        hex(&sha256(b"the stack writer")),
        layer_objs.join(", ")
    );
    std::fs::write(vdir.join("profile.json"), profile).unwrap();
    vdir
}

fn constants(cal: &super::shape::NormCalibration, f_e: u32, e_s: i32, silu: (i32, i32)) -> String {
    format!(
        "{{\"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_qkv\": {}, \"sh_rope\": 7, \"sh_s\": {}, \"sh_o\": {}, \"sh_ao\": {}, \"sh_g\": {}, \"sh_u\": 0, \"sh_h\": {}, \"sh_z\": {}, \"f_e\": {f_e}, \"f_p\": 9, \"f_ro\": 7, \"sh_r2\": 0, \"silu_member\": [{}, {}], \"exp_e_s\": {e_s}, \"rope_theta\": 10000.0}}",
        cal.tn, cal.cn_a, cal.cn_m, cal.ceps, cal.sh_qkv, cal.sh_s, cal.sh_o, cal.sh_ao, cal.sh_g, cal.sh_h, cal.sh_z, silu.0, silu.1
    )
}

/// **R2-3 in the ordinary filter.** Three chained layers with per-block
/// tables prove as ONE bound run through the production CLI bridge; a
/// separate verify call accepts the directory and every run-level control
/// refuses; a wrong statement pin, a shorter layer range and a foreign file
/// in the run directory are refused; the `--lie-at-boundary` prover control
/// (boundary after block 1 off by one word) fails to verify.
#[test]
fn the_stack_cli_proves_three_chained_layers_as_one_bound_run_and_every_control_refuses() {
    let dir = base_dir("stack");
    let vdir = write_stack_export(&dir, "stack-v1", 3);
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let vd = vdir.display().to_string();
    let out = dir.join("run");
    let od = out.display().to_string();
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &od])), 0, "stack-prove failed");
    let stmt = std::fs::read_to_string(out.join("statement").join("statement.json")).unwrap();
    assert!(stmt.contains("\"blocks\": 3"), "{stmt}");
    assert!(stmt.contains("\"export_variant\": \"stack-v1\""), "{stmt}");
    for k in ["\"exp_e_s\": 0", "\"exp_e_s\": 1", "\"silu_member\": [-4, -12]", "\"sh_qkv\": 8"] {
        assert!(stmt.contains(k), "statement.json does not carry {k}");
    }
    let id = stmt.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string();
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vd, "--artifact", &od, "--expect-statement", &id, "--controls"])), 0, "stack-verify (with controls) failed");
    let wrong = hex(&sha256(b"another statement"));
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vd, "--artifact", &od, "--expect-statement", &wrong])), 1, "a wrong statement pin was accepted");
    // a verifier over a shorter layer range: another statement, another L
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vd, "--artifact", &od, "--expect-statement", &id, "--layers", "0..2"])), 1, "a two-layer verifier accepted the three-layer run");
    // a foreign file in the run directory
    std::fs::write(out.join("notes.txt"), b"x").unwrap();
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vd, "--artifact", &od, "--expect-statement", &id])), 1, "a run directory with a foreign file was accepted");
    std::fs::remove_file(out.join("notes.txt")).unwrap();
    // an existing output directory is never overwritten
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &od])), 1, "an existing run directory was overwritten");
    // the prover-side lie: exit 0 means the run FAILED to verify, as it must
    let lie = dir.join("run-lie");
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &lie.display().to_string(), "--lie-at-boundary", "1"])), 0, "the boundary lie control misbehaved");
    assert!(!lie.join("statement").exists(), "a run that failed to verify retained a statement");
    let _ = std::fs::remove_dir_all(&dir);
}
