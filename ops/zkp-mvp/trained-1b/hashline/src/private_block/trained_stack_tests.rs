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
    write_stack_export_with(dir, variant, n, None)
}

/// NATIVE R6: the block output of the INDEPENDENT shape-driven reference
/// kernel (`private-block-kernel-shaped`) at `sh` (its shifts included), on
/// the true-size words and this block's own tables
fn kernel_out(sh: &Shape, w: &[Vec<i8>; 9], x: &[i16], exp: &[i64], act: &[i16]) -> Vec<i16> {
    use private_block_kernel_shaped as k;
    let (cos, sin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, 10000.0, F_RO);
    let ksh = super::parity::kernel_shape(sh);
    let mut scratch = vec![0i64; ksh.scratch_len()];
    let mut out = vec![0i16; ksh.x_len()];
    let wr = k::WeightsRef { wq: &w[0], wk: &w[1], wv: &w[2], wo: &w[3], gamma_a: &w[4], gamma_m: &w[5], wg_t: &w[6], wu_t: &w[7], wd_t: &w[8] };
    let tr = k::TablesRef { rope_cos: &cos, rope_sin: &sin, exp, act };
    k::run_shaped(&ksh, x, &wr, &tr, &mut scratch, None, &mut out).unwrap_or_else(|e| panic!("the reference kernel refuses: {e:?}"));
    out
}

/// The same, with a PER-LAYER score shift (NATIVE R6): `per_layer_sh_s`
/// names each layer's `sh_s`; every layer's `x_out` is then the INDEPENDENT
/// reference kernel's output at that layer's shifts (cross-checked against
/// the native witness here, and against it again by `stack-prove`'s parity),
/// the layer manifests carry their own `sh_s`, and `profile.json` names `sh_s`
/// per layer (`null` in `profile_constants`, listed in
/// `per_layer_constants_differ`) — the export format the calibration lane
/// writes for a per-layer score shift.
fn write_stack_export_with(dir: &Path, variant: &str, n: usize, per_layer_sh_s: Option<&dyn Fn(usize) -> u32>) -> PathBuf {
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
        let lsh_s = per_layer_sh_s.map(|f| f(k)).unwrap_or(cal.sh_s);
        let lsh = if lsh_s == cal.sh_s { sh.clone() } else { sh.with_score_shift(lsh_s).unwrap() };
        let lcal = super::shape::NormCalibration { sh_s: lsh_s, ..cal };
        let wit = witness::build_shaped(&lsh, &public, &ff, &x).unwrap_or_else(|e| panic!("layer {k}: the honest chained witness: {e}"));
        let mut x_out: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| wit.planes[ids.at(A_X2)][t * sh.d_pad + i] as i16).collect();
        if per_layer_sh_s.is_some() {
            // the export's x_out is the INDEPENDENT reference's (the parity
            // reference), and it must equal the native witness's output
            let reference = kernel_out(&lsh, &w, &x, &exp, &act);
            assert_eq!(x_out, reference, "layer {k} (sh_s {lsh_s}): the native witness and the reference kernel disagree");
            x_out = reference;
        }
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
        let consts = constants(&lcal, sh.f_e, e_s, silu);
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
    let mut pc = constants(&cal, sh.f_e, 0, (-3, -11)).replace("\"silu_member\": [-3, -11]", "\"silu_member\": null").replace("\"exp_e_s\": 0", "\"exp_e_s\": null");
    let mut differ = "\"exp_e_s\", \"silu_member\"".to_string();
    if per_layer_sh_s.is_some() {
        pc = pc.replace(&format!("\"sh_s\": {}", cal.sh_s), "\"sh_s\": null");
        differ.push_str(", \"sh_s\"");
    }
    let profile = format!(
        "{{\"schema\": \"zk60-trained-profile-export/1\", \"kind\": \"profile\", \"variant\": \"{variant}\", \"geometry\": \"rung-tc-t32-dev\", \"model\": {{\"repo\": \"synthetic/native-stack-export\", \"revision\": \"native-round-2\", \"sha256\": \"{}\"}}, \"calibration_tool\": {{\"path\": \"native-lane\", \"sha256\": {{\"trained_stack_tests.rs\": \"{}\"}}}}, \"T\": 32, \"profile_constants\": {pc}, \"per_layer_constants_differ\": [{differ}], \"layers\": [{}], \"sequences\": [\"seq_s0\"]}}\n",
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
    // R5b (P-5): the verifier's copy of the export holds no seq_* entry
    let vc = super::trained_block_tests::verifier_copy(&vdir);
    let vcd = vc.display().to_string();
    let out = dir.join("run");
    let od = out.display().to_string();
    let unverified = dir.join("run.unverified-statement");
    // R5b (P-3 / C-R4): a free --label is refused before anything exists
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &od, "--label", "per-request-label"])), 1, "a free --label was accepted");
    assert!(!out.exists() && !unverified.exists(), "the refused prover wrote something");
    // the default (no in-process verify): the prover's statement is written
    // BESIDE the run, unverified (P-1 / M-9)
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &od, "--witness-cache-gib", "0"])), 0, "stack-prove failed");
    assert!(!out.join("statement").exists(), "an unverified run carries a statement/ directory");
    assert!(unverified.join("UNVERIFIED.txt").exists(), "no unverified statement beside the run");
    let stmt = std::fs::read_to_string(unverified.join("statement.json")).unwrap();
    assert!(stmt.contains("\"blocks\": 3"), "{stmt}");
    assert!(stmt.contains("\"export_variant\": \"stack-v1\""), "{stmt}");
    for k in ["\"exp_e_s\": 0", "\"exp_e_s\": 1", "\"silu_member\": [-4, -12]", "\"sh_qkv\": 8", "\"prover_reported\": {\"backend\": \"gpu: off", "\"statement_written_by\": \"stack-prove, WITHOUT a verification"] {
        assert!(stmt.contains(k), "statement.json does not carry {k}");
    }
    let id = stmt.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string();
    // R5b (P-5): a verifier refuses the export that holds seq_s0
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vd, "--artifact", &od, "--expect-statement", &id])), 1, "a verifier accepted an export holding seq_s0");
    assert!(!out.join("statement").exists(), "a refused verification promoted the statement");
    // a wrong pin and a shorter layer range refuse, and promote nothing
    let wrong = hex(&sha256(b"another statement"));
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &wrong])), 1, "a wrong statement pin was accepted");
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--layers", "0..2"])), 1, "a two-layer verifier accepted the three-layer run");
    assert!(unverified.exists() && !out.join("statement").exists(), "a refused verification promoted the statement");
    // a tampered unverified segments.json: the run verifies, the promotion
    // is refused (the statement stays unverified)
    let sj = std::fs::read_to_string(unverified.join("segments.json")).unwrap();
    std::fs::write(unverified.join("segments.json"), sj.replacen("\"bytes\":", "\"bytes\":1", 1)).unwrap();
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 1, "a tampered segments.json was promoted");
    assert!(unverified.exists() && !out.join("statement").exists());
    std::fs::write(unverified.join("segments.json"), &sj).unwrap();
    // the fresh-process verification (with every control) PROMOTES it
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--controls"])), 0, "stack-verify (with controls) failed");
    assert!(out.join("statement").join("statement.json").exists() && !unverified.exists(), "the verified statement was not promoted");
    assert!(!out.join("statement").join("UNVERIFIED.txt").exists());
    // NATIVE R6 (r5_A): the published statement is the VERIFIER'S rendering
    let pub_stmt = std::fs::read_to_string(out.join("statement").join("statement.json")).unwrap();
    assert!(pub_stmt.contains("\"statement_written_by\": \"stack-verify, after its fresh-process verification"), "{pub_stmt}");
    assert!(pub_stmt.contains("\"schema\": \"zk60-trained-stack-run/2\""), "{pub_stmt}");
    // and the promoted run verifies again from its own statement/
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 0, "the promoted run no longer verifies");
    // a free --label at the verifier
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--label", "per-request-label"])), 1, "a verifier accepted a free --label");
    // a foreign file in the run directory
    std::fs::write(out.join("notes.txt"), b"x").unwrap();
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 1, "a run directory with a foreign file was accepted");
    std::fs::remove_file(out.join("notes.txt")).unwrap();
    // REVIEW r3_6 (verifier DoS): a segment that is a symbolic link to
    // /dev/zero, a FIFO, or one byte too long is refused by the CLI verifier
    // and by its --controls reader without being read (a read of either of
    // the first two would never return), and the honest run verifies again
    {
        let seg0 = out.join(super::run_sink::segment_file_name(0));
        let honest = std::fs::read(&seg0).unwrap();
        let restore = || {
            let _ = std::fs::remove_file(&seg0);
            std::fs::write(&seg0, &honest).unwrap();
        };
        std::fs::remove_file(&seg0).unwrap();
        std::os::unix::fs::symlink("/dev/zero", &seg0).unwrap();
        assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 1, "a /dev/zero segment was accepted");
        restore();
        std::fs::remove_file(&seg0).unwrap();
        assert!(std::process::Command::new("mkfifo").arg(&seg0).status().map(|x| x.success()).unwrap_or(false), "mkfifo");
        assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 1, "a FIFO segment was accepted");
        restore();
        std::fs::OpenOptions::new().write(true).open(&seg0).and_then(|f| f.set_len(honest.len() as u64 + 1)).unwrap();
        assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 1, "a segment one byte too long was accepted");
        restore();
        // the --controls reader is the same bounded reader: the verify fails
        // first, and the controls never read the FIFO
        std::fs::remove_file(&seg0).unwrap();
        assert!(std::process::Command::new("mkfifo").arg(&seg0).status().map(|x| x.success()).unwrap_or(false), "mkfifo");
        assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--controls"])), 1, "a FIFO segment was accepted with --controls");
        restore();
        assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 0, "the restored honest run no longer verifies");
    }
    // an existing output directory is never overwritten
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &od])), 1, "an existing run directory was overwritten");
    // --verify-in-process writes statement/ itself, nothing beside the run;
    // the hidden input from a prover-private --seq-dir outside the export
    // proves the same statement
    let pseq = super::trained_block_tests::private_seq_copy(&vdir);
    let o2 = dir.join("run-in-process");
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vcd, "--seq-dir", &pseq.display().to_string(), "--out", &o2.display().to_string(), "--verify-in-process"])), 0, "stack-prove --verify-in-process failed");
    assert!(o2.join("statement").join("statement.json").exists() && !dir.join("run-in-process.unverified-statement").exists());
    let s2 = std::fs::read_to_string(o2.join("statement").join("statement.json")).unwrap();
    assert!(s2.contains(&format!("\"trained_statement_identity\": \"{id}\"")) && s2.contains("\"statement_written_by\": \"stack-prove, after its in-process verification"), "{s2}");
    // NATIVE R6 (r5_A): an in-process statement/ is checked byte for byte by
    // a fresh verifier and accepted as it stands
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &o2.display().to_string(), "--expect-statement", &id])), 0, "a fresh verifier refused the in-process statement/");
    // R5b (P-1, ruling H-1): an inadmissible chain — layer 1's parity fails —
    // is refused by the sealing pass BEFORE the run header: no run directory,
    // no statement, and the refusal carries no count or position (P-6)
    let bad = super::trained_block_tests::private_seq_copy(&vdir).with_file_name("stack-v1-private-seq-bad");
    std::fs::create_dir_all(&bad).unwrap();
    for e in std::fs::read_dir(&pseq).unwrap() {
        let e = e.unwrap();
        std::fs::copy(e.path(), bad.join(e.file_name())).unwrap();
    }
    let mut xo = std::fs::read(bad.join("x_out_L01.bin")).unwrap();
    xo[10] ^= 1;
    std::fs::write(bad.join("x_out_L01.bin"), &xo).unwrap();
    let o3 = dir.join("run-bad");
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vcd, "--seq-dir", &bad.display().to_string(), "--out", &o3.display().to_string()])), 1, "a chain whose layer-1 parity fails was proved");
    assert!(!o3.exists() && !dir.join("run-bad.unverified-statement").exists(), "a refused chain left a run directory or a statement");
    // the prover-side lie: exit 0 means the run FAILED to verify, as it must
    let lie = dir.join("run-lie");
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &lie.display().to_string(), "--lie-at-boundary", "1"])), 0, "the boundary lie control misbehaved");
    assert!(!lie.join("statement").exists() && !dir.join("run-lie.unverified-statement").exists(), "a run that failed to verify retained a statement");
    let _ = std::fs::remove_dir_all(&dir);
}

/// **NATIVE R6: A PER-LAYER SCORE SHIFT.** Three chained layers, layer 1 at
/// `sh_s` 6 where the run's (layers 0 and 2) is 5, each layer's `x_out` the
/// INDEPENDENT reference kernel's at that layer's shifts. The production CLI
/// proves them as ONE bound run with parity bit-exact at every layer (so the
/// native witness at layer 1's own shift equals the reference), the
/// statement records layer 1's own `sh_s`, the fresh-process verifier
/// accepts with every run-level control refusing and promotes the
/// statement; and a verifier whose export says layer 1 runs at the run's
/// shift — same words, same block digests, its own statement pinned — is
/// refused by the run binding, so the per-layer value is bound.
#[test]
fn a_per_layer_score_shift_proves_verifies_and_is_bound() {
    let dir = base_dir("stack-sh-s");
    let per_layer = |k: usize| if k == 1 { 6 } else { 5 };
    let vdir = write_stack_export_with(&dir, "stack-shs", 3, Some(&per_layer));
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let vd = vdir.display().to_string();
    let vc = super::trained_block_tests::verifier_copy(&vdir);
    let vcd = vc.display().to_string();
    let out = dir.join("run");
    let od = out.display().to_string();
    assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &od, "--witness-cache-gib", "0"])), 0, "stack-prove of the per-layer export failed");
    let unverified = dir.join("run.unverified-statement");
    let stmt = std::fs::read_to_string(unverified.join("statement.json")).unwrap();
    assert!(stmt.contains("\"layer\": 1,") && stmt.contains("\"exp_e_s\": 1, \"sh_s\": 6}"), "layer 1's own sh_s is not in statement.json: {stmt}");
    assert!(stmt.contains("\"sh_s\": 5,"), "the run's sh_s is not 5: {stmt}");
    assert_eq!(stmt.matches("\"sh_s\": 6").count(), 1, "{stmt}");
    let id = stmt.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string();
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--controls"])), 0, "stack-verify of the per-layer run failed");
    assert!(out.join("statement").join("statement.json").exists(), "the verified per-layer statement was not promoted");
    // the binding: an export identical but for layer 1's manifest, which
    // says the run's shift (5); its own statement is pinned, so the refusal
    // is the run's, not the pin's
    let flat = vc.with_file_name("stack-shs-flat");
    super::trained_block_tests::copy_tree_for_tests(&vc, &flat);
    let m1 = flat.join("layer_01").join("manifest.json");
    let m = std::fs::read_to_string(&m1).unwrap();
    assert!(m.contains("\"sh_s\": 6"), "{m}");
    let m_flat = m.replace("\"sh_s\": 6", "\"sh_s\": 5");
    std::fs::write(&m1, &m_flat).unwrap();
    let p = std::fs::read_to_string(flat.join("profile.json")).unwrap();
    let p_flat = p.replace(&hex(&sha256(m.as_bytes())), &hex(&sha256(m_flat.as_bytes())));
    assert_ne!(p, p_flat, "layer 1's manifest digest is not in profile.json");
    std::fs::write(flat.join("profile.json"), &p_flat).unwrap();
    let flat_id = hex(&super::trained_block::stack_identity_for_tests(&flat).expect("the flat export's statement"));
    assert_ne!(flat_id, id, "dropping layer 1's own sh_s did not move the statement");
    assert_eq!(trained_stack_verify_command(&s(&["--export", &flat.display().to_string(), "--artifact", &od, "--expect-statement", &flat_id])), 1, "a run proved with layer 1 at sh_s 6 VERIFIED as a run with layer 1 at 5");
    // and the honest verifier still accepts the promoted run
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id])), 0, "the promoted per-layer run no longer verifies");
    let _ = std::fs::remove_dir_all(&dir);
}

/// **NATIVE R6: REVIEW r5 FINDING r5_A — THE PUBLISHED STATEMENT IS BOUND TO
/// WHAT WAS VERIFIED.** The reviewer's regression tests r5_3 (b), (c) and (d)
/// (scratch `ops/zkp-mvp/trained-1b-review-r5-scratch/`, `review_r5_inner`),
/// ported to the R6 rule — `stack-verify` writes `<run>/statement/` itself,
/// from its own rendering and the hashes of the bytes it verified, into a
/// fresh directory — plus the byte-for-byte check of an existing
/// `statement/`. Two-layer rung-TC stack, public synthetic data.
#[test]
fn review_r5_3_the_published_statement_is_bound_to_what_was_verified() {
    let dir = base_dir("r5-3");
    let vdir = write_stack_export(&dir, "promo", 2);
    let vc = super::trained_block_tests::verifier_copy(&vdir);
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let (vd, vcd) = (vdir.display().to_string(), vc.display().to_string());
    let prove = |name: &str| -> (PathBuf, PathBuf, String) {
        let out = dir.join(name);
        assert_eq!(trained_stack_prove_command(&s(&["--export", &vd, "--seq", "s0", "--out", &out.display().to_string(), "--witness-cache-gib", "0"])), 0, "stack-prove {name}");
        let un = dir.join(format!("{name}.unverified-statement"));
        let stmt = std::fs::read_to_string(un.join("statement.json")).unwrap();
        let id = stmt.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string();
        (out, un, id)
    };
    let verify = |out: &Path, id: &str| trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &out.display().to_string(), "--expect-statement", id]));
    let seg = |out: &Path, k: usize| out.join(super::run_sink::segment_file_name(k));
    let sha = |b: &[u8]| hex(&sha256(b));
    let entries = |d: &Path| -> Vec<String> {
        let mut v: Vec<String> = std::fs::read_dir(d).unwrap().map(|e| e.unwrap().file_name().to_string_lossy().to_string()).collect();
        v.sort();
        v
    };

    // run B: another transcript of the same statement (segment 1: the same
    // counted length, other bytes)
    let (b, _, _) = prove("run-b");
    let b1 = std::fs::read(seg(&b, 1)).unwrap();
    let (a, ua, id) = prove("run-a");
    let a1 = std::fs::read(seg(&a, 1)).unwrap();
    assert_eq!(a1.len(), b1.len());
    assert_ne!(a1, b1);
    let (a1h, b1h) = (sha(&a1), sha(&b1));

    // (b) THE RACE, at its point: after A verifies, segment 1 := B's and A's
    //     unverified segments.json is rewritten to name it -> refused, and
    //     nothing is published or removed
    {
        let (seg1, sj, b1c, from, to) = (seg(&a, 1), ua.join("segments.json"), b1.clone(), a1h.clone(), b1h.clone());
        after_verify_hook_for_tests(Box::new(move || {
            std::fs::write(&seg1, &b1c).unwrap();
            let t = std::fs::read_to_string(&sj).unwrap();
            let t2 = t.replace(&from, &to);
            assert_ne!(t, t2);
            std::fs::write(&sj, t2).unwrap();
        }));
    }
    assert_eq!(verify(&a, &id), 1, "r5_3 (b): a segment swapped after the verification, named by a rewritten segments.json, was published");
    assert!(!a.join("statement").exists() && ua.join("UNVERIFIED.txt").exists(), "r5_3 (b): a refused publication changed the statement directories");
    std::fs::write(seg(&a, 1), &a1).unwrap();
    let t = std::fs::read_to_string(ua.join("segments.json")).unwrap();
    std::fs::write(ua.join("segments.json"), t.replace(&b1h, &a1h)).unwrap();
    // (b') the swap alone: the verifier publishes the hashes of the bytes it
    //      VERIFIED, so the published statement never names the swapped file,
    //      and a later verification of the swapped run fails
    {
        let (seg1, b1c) = (seg(&a, 1), b1.clone());
        after_verify_hook_for_tests(Box::new(move || std::fs::write(&seg1, &b1c).unwrap()));
    }
    assert_eq!(verify(&a, &id), 0, "r5_3 (b'): the honest verification was refused");
    let published = std::fs::read_to_string(a.join("statement").join("segments.json")).unwrap();
    assert!(published.contains(&a1h) && !published.contains(&b1h), "r5_3 (b'): the published segments.json does not name the verified bytes");
    assert!(!ua.exists(), "the prover's unverified directory was not removed after the publication");
    assert_eq!(verify(&a, &id), 1, "r5_3 (b'): a run whose segment was swapped after the publication re-verified");
    std::fs::write(seg(&a, 1), &a1).unwrap();
    assert_eq!(verify(&a, &id), 0, "the restored run no longer verifies from its published statement");

    // (c) the CONTENT: the reviewer's forgery (false scope / backend / block
    //     count and a DUPLICATE zero identity key), a quieter one-field
    //     forgery, an extra prover file, a symbolic link inside: each refused
    let (cr, uc, idc) = prove("run-c");
    let honest = std::fs::read_to_string(uc.join("statement.json")).unwrap();
    let forged = honest.replacen("{\n", "{\n \"scope\": \"FORGED: a full Llama-3-8B model pass, privacy accepted\",\n \"backend\": \"FORGED\",\n \"blocks\": 99,\n", 1).replacen("\n}\n", ",\n \"trained_statement_identity\": \"0000000000000000000000000000000000000000000000000000000000000000\",\n \"verified_by\": \"FORGED\"\n}\n", 1);
    assert_ne!(forged, honest);
    std::fs::write(uc.join("statement.json"), &forged).unwrap();
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (c): the reviewer's forged statement.json was published");
    let quiet = honest.replace("\"blocks\": 2,", "\"blocks\": 3,");
    assert_ne!(quiet, honest);
    std::fs::write(uc.join("statement.json"), &quiet).unwrap();
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (c): a statement.json with one field moved was published");
    std::fs::write(uc.join("statement.json"), &honest).unwrap();
    std::fs::write(uc.join("EXTRA-prover-file.txt"), b"anything the prover likes").unwrap();
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (c): an extra prover file was accepted");
    std::fs::remove_file(uc.join("EXTRA-prover-file.txt")).unwrap();
    let away = dir.join("expected-elsewhere.bin");
    std::fs::rename(uc.join("expected.bin"), &away).unwrap();
    std::os::unix::fs::symlink(&away, uc.join("expected.bin")).unwrap();
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (c): a symbolic link inside the unverified statement was accepted");
    std::fs::remove_file(uc.join("expected.bin")).unwrap();
    std::fs::rename(&away, uc.join("expected.bin")).unwrap();
    assert!(!cr.join("statement").exists(), "r5_3 (c): a refused publication left a statement/");
    // the honest content publishes the VERIFIER's rendering, nothing else
    assert_eq!(verify(&cr, &idc), 0, "r5_3 (c): the honest run was refused");
    let sp = cr.join("statement").join("statement.json");
    let pubd = std::fs::read_to_string(&sp).unwrap();
    assert!(!pubd.contains("FORGED") && pubd.contains("\"statement_written_by\": \"stack-verify, after its fresh-process verification") && pubd.contains("\"prover_reported\": {\"backend\": \"gpu: off"), "{pubd}");
    assert_eq!(entries(&cr.join("statement")), vec!["expected.bin", "segments.json", "statement.json"]);

    // (e) an EXISTING statement/ is checked byte for byte, never trusted
    let restore = |p: &Path, b: &str| std::fs::write(p, b).unwrap();
    restore(&sp, &pubd.replace("\"blocks\": 2,", "\"blocks\": 99,"));
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (e): an edited statement/statement.json was accepted");
    restore(&sp, &pubd.replace("stack-verify, after its fresh-process verification of the run directory, from its own data and the hashes of the bytes it verified", "stack-prove, WITHOUT a verification (unverified: only stack-verify publishes a statement for this run)"));
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (e): a statement/ naming the unverified writer was accepted");
    restore(&sp, &pubd);
    let segp = cr.join("statement").join("segments.json");
    let segs = std::fs::read_to_string(&segp).unwrap();
    restore(&segp, &segs.replacen(" {", "  {", 1));
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (e): an edited statement/segments.json was accepted");
    restore(&segp, &segs);
    std::fs::write(cr.join("statement").join("notes.txt"), b"x").unwrap();
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (e): an extra file in statement/ was accepted");
    std::fs::remove_file(cr.join("statement").join("notes.txt")).unwrap();
    let held = dir.join("statement-held");
    std::fs::rename(cr.join("statement"), &held).unwrap();
    std::os::unix::fs::symlink(&held, cr.join("statement")).unwrap();
    assert_eq!(verify(&cr, &idc), 1, "r5_3 (e): a statement/ that is a symbolic link was accepted");
    std::fs::remove_file(cr.join("statement")).unwrap();
    std::fs::rename(&held, cr.join("statement")).unwrap();
    assert_eq!(verify(&cr, &idc), 0, "the restored statement/ no longer verifies");

    // (d) <run>.unverified-statement as a SYMLINK to a directory elsewhere:
    //     refused before anything is read; nothing published, the link's
    //     target untouched
    let (dr, ud, idd) = prove("run-d");
    let elsewhere = dir.join("elsewhere-dir");
    std::fs::rename(&ud, &elsewhere).unwrap();
    std::os::unix::fs::symlink(&elsewhere, &ud).unwrap();
    assert_eq!(verify(&dr, &idd), 1, "r5_3 (d): a symlinked unverified statement directory was accepted");
    assert!(std::fs::symlink_metadata(dr.join("statement")).is_err(), "r5_3 (d): a statement/ appeared");
    assert!(elsewhere.join("UNVERIFIED.txt").exists() && std::fs::symlink_metadata(&ud).map(|m| m.file_type().is_symlink()).unwrap_or(false), "r5_3 (d): the link or its target was changed");
    eprintln!("REVIEW r5_3 (R6): (b) race refused, (b') verified hashes published, (c) four forgeries refused and the verifier's rendering published, (e) five edits of an existing statement/ refused, (d) symlinked directory refused");
    let _ = std::fs::remove_dir_all(&dir);
}
