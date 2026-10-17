//! **REVIEWER SCRATCH (D24 independent adversarial review, 2026-10-17).**
//! TEST CODE ONLY, in the reviewer's scratch copy; never in the frozen copy
//! or the author's tree. Public synthetic data only.
//!
//! * `review_a_*`: which `f_e` the trained TinyLlama door admits (fast).
//! * `review_b_*`: an UNBOUND run at the trained-calibration rung profile
//!   constructs and absorbs the synthetic calibration literal (fast).
//! * `review_c_*`: `RunStatement::new_bound` accepts a trained-model
//!   statement at a FROZEN profile (fast).
//! * `review_d_*`: the trained statement identity and the run context depend
//!   on the export's local DIRECTORY NAME (fast).
//! * `review_e_*` (heavy, ignored): a softmax field-wrap forgery at an
//!   admitted `f_e`, end to end through the production CLI bridge.
//! * `review_f_*` (heavy, ignored): the naive (non-wrapping) forgery of the
//!   same quotient is rejected at the same profile (control).

use super::layout::*;
use super::shape::{NormCalibration, Shape};
use super::witness;
use super::*;
use std::sync::Mutex;

const P: i128 = 0xffff_ffff_0000_0001;

/// `(head, token, source token, delta, k)`: replace the quotient `p` at that
/// softmax position by `p + delta` and the remainder by `rho - delta*Sum + k*P`
/// (`k = 0` with `naive`: remainder and complement left as they are)
#[derive(Clone, Copy, Debug)]
pub(super) struct Forge {
    pub h: usize,
    pub t: usize,
    pub j: usize,
    pub delta: i64,
    pub k: i128,
    pub naive: bool,
}

static FORGE: Mutex<Option<Forge>> = Mutex::new(None);

fn set_forge(v: Option<Forge>) {
    *FORGE.lock().unwrap() = v;
}

/// the hook `witness::build_shaped` calls (scratch edit, `cfg(test)` only)
pub(super) fn forge_softmax(h: usize, t: usize, j: usize, total: i64, q: i64, rho: i64, sigma: i64) -> (i64, i64, i64) {
    let f = *FORGE.lock().unwrap();
    match f {
        Some(f) if f.h == h && f.t == t && f.j == j => {
            if f.naive {
                eprintln!("REVIEW naive forge at (h {h}, t {t}, j {j}): p {q} -> {}", q + f.delta);
                return (q + f.delta, rho, sigma);
            }
            let q2 = q as i128 + f.delta as i128;
            let r2 = rho as i128 - f.delta as i128 * total as i128 + f.k * P;
            assert!(r2 >= 0 && r2 < total as i128, "the forged remainder {r2} is outside [0, {total})");
            let s2 = total as i128 - 1 - r2;
            let c2 = (q as i128 * total as i128 + rho as i128) - q2 * total as i128 - r2;
            eprintln!(
                "REVIEW forge at (h {h}, t {t}, j {j}): Sum {total}, p {q} -> {q2}, sr {rho} -> {r2}, sg {sigma} -> {s2}; c2 over the integers = {c2} = {} * P",
                c2 / P
            );
            assert_eq!(c2 % P, 0);
            (q2 as i64, r2 as i64, s2 as i64)
        }
        _ => (q, rho, sigma),
    }
}

fn t3() -> NormCalibration {
    super::trained_calib_tests::t3_calibration()
}

fn x2_true(sh: &Shape, w: &witness::Witness) -> Vec<i16> {
    let ids = Ids::new(sh).unwrap();
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| w.planes[ids.at(A_X2)][t * sh.d_pad + i] as i16).collect()
}

// ------------------------------------------------------------------ A

/// Which `f_e` does the trained TinyLlama door admit (shape + layout + exp
/// table + attention statement)? The reference kernel refuses `f_e >= 32`;
/// the softmax quotient clause wraps the field from `f_e = 49` at `T = 32`
/// (reviewer_nowrap.py).
#[test]
fn review_a_f_e_admission_at_the_trained_tinyllama_profile() {
    let cal = t3();
    let mut admitted = Vec::new();
    for f_e in 0..=64u32 {
        let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| -> Result<(u32, usize, usize, usize), String> {
            let sh = Shape::tinyllama_t32_trained(&cal, f_e)?;
            let lay = Layout::for_shape(&sh)?;
            let (exp, _) = crate::tables_attn::exp_member(0, sh.head_dim, f_e);
            let (cos, sin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, 10000.0, F_RO);
            let z = |n: usize| vec![0i8; n];
            let kvw = sh.kv_heads * sh.head_dim;
            AttentionPublic::new_shaped(&sh, &z(sh.d_pad * sh.d_pad), &z(kvw * sh.d_pad), &z(kvw * sh.d_pad), &z(sh.d_pad * sh.d_pad), &z(sh.d_pad), &cos, &sin, &exp)?;
            Ok((sh.wrho_s, sh.limbs_sigma_s(), lay.a_rows, sh.receipt_bytes().total))
        }));
        match r {
            Ok(Ok((ws, ls, a, rb))) => {
                admitted.push(f_e);
                eprintln!("REVIEW-A f_e {f_e:2}: ADMITTED (wrho_s {ws}, sigma_s limbs {ls}, A rows {a}, receipt {rb} B)");
            }
            Ok(Err(e)) => eprintln!("REVIEW-A f_e {f_e:2}: refused: {}", e.chars().take(140).collect::<String>()),
            Err(_) => eprintln!("REVIEW-A f_e {f_e:2}: PANIC"),
        }
    }
    eprintln!("REVIEW-A admitted f_e at the trained TinyLlama profile: {admitted:?}");
    // the kernel's own class
    let k = super::parity::kernel_shape(&Shape::tinyllama_t32_trained(&cal, 50).unwrap());
    eprintln!("REVIEW-A the shape-driven reference kernel at f_e 50: {:?}", k.check().err());
    // and the trained-model statement at f_e = 50 constructs, naming the
    // pinned TinyLlama checkpoint
    let sh = Shape::tinyllama_t32_trained(&cal, 50).unwrap();
    let (w, _) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public, ff);
    use super::trained_statement::*;
    let prov = Provenance::recipe("review/f_e-50", 1.0, [1; 32], [2; 32]);
    let st = TrainedModelStatement::new(&sh, super::run::RUN_PROFILE_TINYLLAMA_T32_TRAINED, ModelSource::tinyllama_chat_v1_0(), IntegerCalibration::as_the_code_proves(&sh, &prov), vec![LayerRecord::of_block(0, &blk, vec![])]);
    eprintln!("REVIEW-A trained-model statement at f_e 50 (HF checkpoint source): {}", match &st { Ok(s) => format!("CONSTRUCTS, identity {}", super::trained_block::hex(&s.identity())), Err(e) => format!("refused: {e}") });
    assert!(admitted.contains(&50), "f_e = 50 is not admitted (the finding would not hold)");
    assert!(st.is_ok());
}

// ------------------------------------------------------------------ B

/// An UNBOUND run at the trained-calibration RUNG profile constructs and
/// absorbs the synthetic calibration literal, although its shape carries a
/// non-frozen calibration (the guard in `RunStatement::new` is a substring
/// test on "tinyllama").
#[test]
fn review_b_an_unbound_run_at_the_trained_rung_takes_the_synthetic_literal() {
    let sh = Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap();
    assert!(sh.trained_calibration && sh.norm_calibration() != NormCalibration::FROZEN);
    let (blk, _) = super::trained_calib_tests::trained_dense_block(&sh);
    let ctx = *blake3::hash(b"review b").as_bytes();
    let expected = ExpectedIo::from_roots(IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap(), [1; 32], [2; 32]);
    let st = super::run::RunStatement::new(super::run::RunShape::rung_tc(sh.clone(), 1).unwrap(), ctx, expected, &[blk], &[(0, 0)]);
    match &st {
        Ok(s) => {
            let h = s.capture_header().unwrap();
            eprintln!(
                "REVIEW-B unbound run at {} CONSTRUCTS; its calibration absorb == calibration_identity() (the synthetic literal): {}",
                super::run::RUN_PROFILE_RUNG_TC,
                h.calibration == calibration_identity()
            );
            assert_eq!(h.calibration, calibration_identity());
        }
        Err(e) => panic!("refused (the finding would not hold): {e}"),
    }
}

// ------------------------------------------------------------------ C

/// `RunStatement::new_bound` at a FROZEN profile (rung-G) with a trained-model
/// statement that names the pinned TinyLlama checkpoint as its source.
#[test]
fn review_c_new_bound_accepts_a_frozen_profile() {
    use super::trained_statement::*;
    let sh = Shape::rung_g();
    let (public, ff, _) = super::dense_tests::dense_case(&sh);
    let blk = BlockPublic::new(public, ff);
    let prov = Provenance::recipe("review/c", 1.0, [1; 32], [2; 32]);
    let st = TrainedModelStatement::new(&sh, super::run::RUN_PROFILE_RUNG_G, ModelSource::tinyllama_chat_v1_0(), IntegerCalibration::as_the_code_proves(&sh, &prov), vec![LayerRecord::of_block(0, &blk, vec![])]);
    let st = match st {
        Ok(s) => s,
        Err(e) => {
            eprintln!("REVIEW-C the statement is refused: {e}");
            return;
        }
    };
    let ctx = *blake3::hash(b"review c").as_bytes();
    let expected = ExpectedIo::from_roots(IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap(), [1; 32], [2; 32]);
    let r = super::run::RunStatement::new_bound(super::run::RunShape::rung_g(1).unwrap(), ctx, expected, &[blk], &[(0, 0)], &st);
    eprintln!("REVIEW-C new_bound at the FROZEN rung-G profile with a statement naming the TinyLlama checkpoint: {}", match &r { Ok(_) => "CONSTRUCTS".to_string(), Err(e) => format!("refused: {e}") });
}

// ------------------------------------------------------------------ D

/// The trained statement identity (and the run context) depend on the export
/// directory's NAME: the same bytes under two names give two identities.
#[test]
fn review_d_the_statement_identity_depends_on_the_export_directory_name() {
    let root = std::env::temp_dir().join(format!("zk60-review-d-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();
    let f = super::trained_block_tests::Fault::default();
    let (v1, _) = super::trained_block_tests::write_export(&root.join("a"), "tiny-v1", &f);
    let (v2, _) = super::trained_block_tests::write_export(&root.join("b"), "tiny-v1-copy", &f);
    let same = std::fs::read(v1.join("profile.json")).unwrap() == std::fs::read(v2.join("profile.json")).unwrap() && std::fs::read(v1.join("layer_00/manifest.json")).unwrap() == std::fs::read(v2.join("layer_00/manifest.json")).unwrap();
    let id = |v: &std::path::Path| {
        let ex = super::trained_block::TrainedExport::load(v).unwrap();
        let c = ex.run_constants(&[0]).unwrap();
        let sh = ex.shape_for(&c).unwrap();
        let l = ex.load_layer(&sh, &c, 0, false).unwrap();
        ex.statement(&sh, &c, &[&l]).unwrap().identity()
    };
    let (i1, i2) = (id(&v1), id(&v2));
    eprintln!("REVIEW-D identical profile.json and manifest bytes: {same}; identities equal: {}", i1 == i2);
    let _ = std::fs::remove_dir_all(&root);
    assert!(same);
    assert_ne!(i1, i2, "the identity does not depend on the directory name (finding would not hold)");
}

// ------------------------------------------------------------------ G

/// **The class CORNER end to end at the trained rung** (control, fast):
/// `tn 10, Cn_a = Cn_m = 2^20, Ceps = 2^40, sh_ao = 8` (window 32 = C-6 at
/// width 384). Gains are set to +-1 so the int8 output class holds. The honest
/// block proves and verifies from bytes; a verifier one unit off any constant
/// refuses; a witness honest under neighbouring constants is rejected.
#[test]
fn review_g_the_class_corner_proves_and_its_controls_refuse() {
    let corner = NormCalibration { tn: 10, cn_a: 1 << 20, cn_m: 1 << 20, ceps: 1 << 40, sh_ao: 8 };
    let sh = Shape::rung_tc(&corner).expect("the class corner is admitted at width 384");
    eprintln!("REVIEW-G corner shape: wrho {} D_max {} limbs {} top-full {}", sh.norm_wrho, sh.d_max, sh.limbs_norm(), sh.norm_top_is_full_byte());
    let (mut w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    for (k, g) in w[4].iter_mut().enumerate() {
        *g = if k % 3 == 0 { -1 } else { 1 };
    }
    for (k, g) in w[5].iter_mut().enumerate() {
        *g = if k % 5 == 0 { -1 } else { 1 };
    }
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    let wit = match witness::build_shaped(&sh, &public, &ff, &input) {
        Ok(x) => x,
        Err(e) => {
            eprintln!("REVIEW-G the corner witness is refused (completeness note, not a soundness result): {e}");
            return;
        }
    };
    let ids = Ids::new(&sh).unwrap();
    let ya = wit.planes[ids.at(A_Y)].iter().map(|v| v.abs()).max().unwrap();
    let dmax_seen = wit.planes[ids.at(A_D)].iter().max().unwrap();
    eprintln!("REVIEW-G corner witness: max|y_a| {ya}, max D {dmax_seen}");
    let plane = |w: &witness::Witness, p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| *v as i16).collect() };
    let ctx = *blake3::hash(b"review g").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &plane(&wit, ids.at(A_X)), &plane(&wit, ids.at(A_X2))).unwrap();
    let (r, _) = super::protocol::prove_inner_at(&sh, &blk, wit, &expected, owners).expect("the corner proves");
    let bytes = r.to_bytes_at(&sh, &blk, &expected).unwrap();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the corner verifies from bytes");
    eprintln!("REVIEW-G corner: honest receipt {} B verifies", bytes.len());
    for (name, v) in [
        ("cn_a - 1", NormCalibration { cn_a: corner.cn_a - 1, ..corner }),
        ("cn_m - 1", NormCalibration { cn_m: corner.cn_m - 1, ..corner }),
        ("ceps - 1", NormCalibration { ceps: corner.ceps - 1, ..corner }),
        ("tn - 1", NormCalibration { tn: corner.tn - 1, ..corner }),
        ("sh_ao - 1", NormCalibration { sh_ao: corner.sh_ao - 1, ..corner }),
    ] {
        let other = Shape::rung_tc(&v).unwrap();
        let e = verify_bytes_at(&other, &blk, &expected, &bytes).expect_err(&format!("a verifier with {name} ACCEPTED"));
        eprintln!("REVIEW-G corner: verifier with {name} refuses: {}", e.chars().take(80).collect::<String>());
        // and a witness honest under the neighbouring constants, proved under the corner
        let ow = match witness::build_shaped(&other, &public, &ff, &input) {
            Ok(x) => x,
            Err(e) => {
                eprintln!("REVIEW-G corner: the {name} witness is refused: {e}");
                continue;
            }
        };
        let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
        let (ex2, own2) = prepare_endpoints(spec, &plane(&ow, ids.at(A_X)), &plane(&ow, ids.at(A_X2))).unwrap();
        let verdict = match super::protocol::prove_inner_at(&sh, &blk, ow, &ex2, own2) {
            Err(e) => Err(e),
            Ok((r2, _)) => verify_inner_at_shape(&sh, &blk, &ex2, &r2),
        };
        let e = verdict.expect_err(&format!("a witness honest under {name} VERIFIED at the corner"));
        eprintln!("REVIEW-G corner: witness honest under {name} rejected: {}", e.chars().take(80).collect::<String>());
    }
}

/// **H (fast): the class is checked ONCE, at the door.** A trained shape
/// whose fields are edited after `with_trained_calibration` (pub fields) is
/// accepted by `Layout::for_shape`, which re-checks only "not trained and not
/// frozen". Defence in depth only: production builds shapes through the door.
#[test]
fn review_h_layout_does_not_re_validate_a_trained_shape() {
    let mut sh = Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap();
    sh.norm_cn_a = 1 << 40;
    sh.norm_ceps = 1 << 50;
    let r = Layout::for_shape(&sh);
    eprintln!("REVIEW-H Layout::for_shape on a trained shape edited to cn_a 2^40, ceps 2^50 (outside the class): {}", match &r { Ok(_) => "ACCEPTED".to_string(), Err(e) => format!("refused: {e}") });
    eprintln!("REVIEW-H derive_at_width on the edited constants: {:?}", sh.norm_calibration().derive_at_width(sh.width).err());
}

fn verify_inner_at_shape(sh: &Shape, blk: &BlockPublic, ex: &ExpectedIo, r: &Receipt) -> Result<(), String> {
    super::protocol::verify_inner_at(sh, blk, ex, r).map(|_| ())
}

// ------------------------------------------------------------------ E

fn review_dir() -> std::path::PathBuf {
    std::path::PathBuf::from(std::env::var_os("ZK60_REVIEW_DIR").expect("ZK60_REVIEW_DIR"))
}

fn i8b(v: &[i8]) -> Vec<u8> {
    v.iter().map(|x| *x as u8).collect()
}
fn i16b(v: &[i16]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}
fn i64b(v: &[i64]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

/// Write a TinyLlama-geometry export (schema `zk60-trained-profile-export/1`,
/// the pinned model strings, SYNTHETIC words) at the given `f_e`.
fn write_tinyllama_export(vdir: &std::path::Path, cal: &NormCalibration, f_e: u32, w: &[Vec<i8>; 9], exp: &[i64], act: &[i16], x_in: &[i16], x_out: &[i16]) {
    use super::trained_block::{hex, sha256};
    let ldir = vdir.join("layer_00");
    let sdir = vdir.join("seq_s0");
    std::fs::create_dir_all(&ldir).unwrap();
    std::fs::create_dir_all(&sdir).unwrap();
    let (d, f, kvw) = (2048usize, 5632usize, 256usize);
    let arrays: Vec<(&str, Vec<u8>, &str, String)> = vec![
        ("wq", i8b(&w[0]), "int8", format!("[{d}, {d}]")),
        ("wk", i8b(&w[1]), "int8", format!("[{kvw}, {d}]")),
        ("wv", i8b(&w[2]), "int8", format!("[{kvw}, {d}]")),
        ("wo", i8b(&w[3]), "int8", format!("[{d}, {d}]")),
        ("gamma_a", i8b(&w[4]), "int8", format!("[{d}]")),
        ("gamma_m", i8b(&w[5]), "int8", format!("[{d}]")),
        ("wg_t", i8b(&w[6]), "int8", format!("[{d}, {f}]")),
        ("wu_t", i8b(&w[7]), "int8", format!("[{d}, {f}]")),
        ("wd_t", i8b(&w[8]), "int8", format!("[{f}, {d}]")),
        ("exp", i64b(exp), "int64", "[256]".into()),
        ("act", i16b(act), "int16", "[256]".into()),
    ];
    let mut entries = Vec::new();
    for (name, bytes, dtype, shape) in &arrays {
        std::fs::write(ldir.join(format!("{name}.bin")), bytes).unwrap();
        entries.push(format!("\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"{dtype}\", \"shape\": {shape}, \"sha256\": \"{}\"}}", hex(&sha256(bytes))));
    }
    let consts = format!(
        "{{\"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_qkv\": 7, \"sh_rope\": 7, \"sh_s\": 6, \"sh_o\": 9, \"sh_ao\": {}, \"sh_g\": 7, \"sh_u\": 0, \"sh_h\": 14, \"sh_z\": 6, \"f_e\": {f_e}, \"f_p\": 9, \"f_ro\": 7, \"sh_r2\": 0, \"silu_member\": [-3, -11], \"exp_e_s\": 0, \"rope_theta\": 10000.0}}",
        cal.tn, cal.cn_a, cal.cn_m, cal.ceps, cal.sh_ao
    );
    let manifest = format!("{{\"layer\": 0, \"constants\": {consts}, \"arrays\": {{{}}}}}\n", entries.join(", "));
    std::fs::write(ldir.join("manifest.json"), &manifest).unwrap();
    let (xi, xo) = (i16b(x_in), i16b(x_out));
    std::fs::write(sdir.join("x_in_L00.bin"), &xi).unwrap();
    std::fs::write(sdir.join("x_out_L00.bin"), &xo).unwrap();
    let pin = super::trained_statement::ModelSource::tinyllama_chat_v1_0();
    let profile = format!(
        "{{\"schema\": \"zk60-trained-profile-export/1\", \"kind\": \"profile\", \"geometry\": \"tinyllama-1.1b-t32\", \"model\": {{\"repo\": \"{}\", \"revision\": \"{}\", \"sha256\": \"{}\"}}, \"calibration_tool\": {{\"path\": \"reviewer\", \"sha256\": \"{}\"}}, \"T\": 32, \"profile_constants\": {consts}, \"layers\": [{{\"layer\": 0, \"dir\": \"layer_00\", \"manifest_sha256\": \"{}\"}}], \"sequences\": [\"seq_s0\"]}}\n",
        pin.repo,
        pin.revision,
        hex(&pin.weights_sha256),
        hex(&sha256(b"reviewer: a synthetic export, not a calibration")),
        hex(&sha256(manifest.as_bytes()))
    );
    std::fs::write(vdir.join("profile.json"), profile).unwrap();
}

/// **THE FINDING, END TO END.** At the trained TinyLlama profile with
/// `f_e = 50` (admitted by the door and by the loader; the statement names
/// the pinned TinyLlama checkpoint), one softmax quotient is forged by
/// `+511` with the remainder moved by `-511 Sum + P`, so the quotient clause
/// `mask e 2^9 - p Sum - sr` is `-P` over the integers: zero in the field.
/// Everything downstream is recomputed honestly from the forged quotient, so
/// the claimed block output differs from the honest one. The production CLI
/// bridge proves it and verifies it; the fresh-process verify of the saved
/// artifact is run separately with the AUTHOR'S saved release binary.
#[test]
#[ignore = "review heavy: TinyLlama witness x3 + one proof"]
fn review_e_softmax_field_wrap_forgery_through_the_trained_cli() {
    let cal = t3();
    let f_e = 50u32;
    let sh = Shape::tinyllama_t32_trained(&cal, f_e).expect("f_e 50 is admitted");
    let (mut w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    // Wk = 0: every score is 0, so every causal e is 2^f_e and the last row's
    // Sum is 32 * 2^50 = 2^55
    for v in w[1].iter_mut() {
        *v = 0;
    }
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let (exp, act) = (public.exp.clone(), ff.act.to_vec());
    let blk = BlockPublic::new(public.clone(), ff.clone());
    set_forge(None);
    let honest = witness::build_shaped(&sh, &public, &ff, &input).expect("the honest witness");
    let x_honest = x2_true(&sh, &honest);
    drop(honest);
    // find a position whose forged o8 stays in class
    let mut chosen: Option<(Forge, Vec<i16>)> = None;
    for h in [0usize, 1, 5, 17] {
        for j in [0usize, 7, 31] {
            let f = Forge { h, t: 31, j, delta: 511, k: 1, naive: false };
            set_forge(Some(f));
            match witness::build_shaped(&sh, &public, &ff, &input) {
                Ok(fw) => {
                    let x = x2_true(&sh, &fw);
                    let n = x.iter().zip(x_honest.iter()).filter(|(a, b)| a != b).count();
                    eprintln!("REVIEW-E forged witness at {f:?}: builds; block output differs from the honest one in {n} of {} words", x.len());
                    if n > 0 {
                        chosen = Some((f, x));
                        break;
                    }
                }
                Err(e) => eprintln!("REVIEW-E forged witness at {f:?}: refused downstream: {e}"),
            }
        }
        if chosen.is_some() {
            break;
        }
    }
    let (f, x_forged) = chosen.expect("no forged position stayed in class");
    let ndiff = x_forged.iter().zip(x_honest.iter()).filter(|(a, b)| a != b).count();
    let root = review_dir();
    let vdir = root.join("export-fe50").join("review-fe50");
    let _ = std::fs::remove_dir_all(root.join("export-fe50"));
    std::fs::create_dir_all(&vdir).unwrap();
    // the export claims x_out = the FORGED output (the CLI's parity check is
    // against the prover's own witness, which the hook forges)
    write_tinyllama_export(&vdir, &cal, f_e, &w, &exp, &act, &input, &x_forged);
    std::fs::write(root.join("x_out_honest_L00.bin"), i16b(&x_honest)).unwrap();
    let art = root.join("artifact-fe50");
    let _ = std::fs::remove_dir_all(&art);
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let (vd, od) = (vdir.display().to_string(), art.display().to_string());
    set_forge(Some(f));
    let prove_rc = super::trained_block::trained_prove_command(&s(&["--export", &vd, "--layer", "0", "--seq", "s0", "--out", &od]));
    set_forge(None);
    eprintln!("REVIEW-E CLI prove (forged witness at {f:?}) exit {prove_rc}");
    assert_eq!(prove_rc, 0, "the CLI refused the forged witness");
    let stmt = std::fs::read_to_string(art.join("statement.json")).unwrap();
    let id = stmt.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string();
    std::fs::write(root.join("statement-identity-fe50.hex"), &id).unwrap();
    let verify_rc = super::trained_block::trained_verify_command(&s(&["--export", &vd, "--layer", "0", "--artifact", &od, "--expect-statement", &id]));
    eprintln!(
        "REVIEW-E RESULT: the trained CLI verifier (hook OFF) on the forged artifact: exit {verify_rc} ({}); the claimed output differs from the honest block output in {ndiff} of {} words; statement identity {id}",
        if verify_rc == 0 { "ACCEPTED: SOUNDNESS FAILURE" } else { "rejected" },
        x_honest.len()
    );
    assert_eq!(verify_rc, 0, "the forged artifact was rejected");
}

/// **CONTROL for E**: the same position with a NAIVE forgery (`p + 1`, the
/// remainder untouched: the quotient clause is nonzero in the field) is
/// rejected at the same `f_e = 50` profile.
#[test]
#[ignore = "review heavy: TinyLlama witness + one proof"]
fn review_f_naive_quotient_forgery_is_rejected_at_the_same_profile() {
    let cal = t3();
    let sh = Shape::tinyllama_t32_trained(&cal, 50).unwrap();
    let (mut w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    for v in w[1].iter_mut() {
        *v = 0;
    }
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    set_forge(Some(Forge { h: 0, t: 31, j: 0, delta: 1, k: 0, naive: true }));
    let fw = witness::build_shaped(&sh, &public, &ff, &input).expect("the naive forged witness builds");
    set_forge(None);
    let ids = Ids::new(&sh).unwrap();
    let plane = |p: usize| -> Vec<i16> { fw.planes[p].iter().map(|v| *v as i16).collect() };
    let ctx = *blake3::hash(b"review f").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &plane(ids.at(A_X)), &plane(ids.at(A_X2))).unwrap();
    let verdict = match super::protocol::prove_inner_at(&sh, &blk, fw, &expected, owners) {
        Err(e) => Err(format!("prover: {e}")),
        Ok((r, _)) => {
            let bytes = r.to_bytes_at(&sh, &blk, &expected).unwrap();
            verify_bytes_at(&sh, &blk, &expected, &bytes).map_err(|e| format!("verifier: {e}"))
        }
    };
    eprintln!("REVIEW-F naive forgery (p + 1, no wrap) at f_e 50: {}", match &verdict { Ok(()) => "ACCEPTED".to_string(), Err(e) => format!("rejected: {}", e.chars().take(160).collect::<String>()) });
    assert!(verdict.is_err(), "the naive forgery was accepted");
}
