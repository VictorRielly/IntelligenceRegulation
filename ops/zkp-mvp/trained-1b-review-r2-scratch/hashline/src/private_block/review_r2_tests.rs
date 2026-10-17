//! **REVIEWER SCRATCH, D24 review ROUND 2 (2026-10-17).** Test code only, in
//! the reviewer's scratch copy. Public synthetic data only.
//!
//! * `r2_1` (fast): a shape built WITHOUT the door under a trained profile
//!   string (flag false, frozen calibration, f_e 50): does anything refuse it?
//! * `r2_2` (fast): the shift windows at their edges at the rung, end to end.
//! * `r2_3` (heavy): the TinyLlama profile at the f_e class edge (16), honest
//!   proof, the wrapping forgery (not applicable), the naive forgery (slot 17).
//! * `r2_4` (heavy): writes a TinyLlama export at f_e 16 with every shift at
//!   the top of its window and the honest x_out, for the production CLI.

use super::layout::*;
use super::review_d24_tests::{forged_count, set_forge, Forge};
use super::shape::{NormCalibration, Shape, TRAINED_CALIB_RUNG_PROFILE};
use super::trained_calib_tests::{pg_calibration, prove_one_bound, rung_tc_calibration, trained_dense_words, verify_one_bound, Bands, TRAINED_BANDS};
use super::witness;
use super::*;

fn x2_true(sh: &Shape, w: &witness::Witness) -> Vec<i16> {
    let ids = Ids::new(sh).unwrap();
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| w.planes[ids.at(A_X2)][t * sh.d_pad + i] as i16).collect()
}

fn plane16(w: &witness::Witness, p: usize) -> Vec<i16> {
    w.planes[p].iter().map(|v| *v as i16).collect()
}

// ------------------------------------------------------------------ 1

#[test]
fn r2_1_a_non_door_shape_under_a_trained_profile_string() {
    let sh = Shape::new("reviewer: non-door shape under the trained rung string", TRAINED_CALIB_RUNG_PROFILE, 32, 384, 512, 12, 32, 4, 10, 4, 50, 21, None, None, None, None).expect("Shape::new");
    eprintln!("REVIEW-R2-1 shape: trained_calibration {}, calibration frozen {}, f_e {}, wrho_s {}", sh.trained_calibration, sh.norm_calibration() == NormCalibration::FROZEN, sh.f_e, sh.wrho_s);
    let lay = Layout::for_shape(&sh);
    eprintln!("REVIEW-R2-1 Layout::for_shape: {}", match &lay { Ok(_) => "ACCEPTED".to_string(), Err(e) => format!("refused: {e}") });
    eprintln!("REVIEW-R2-1 single_block_profile_allowed: {:?}", super::protocol::single_block_profile_allowed(&sh));
    if lay.is_err() {
        return;
    }
    let (mut w, input) = trained_dense_words(&sh, TRAINED_BANDS);
    for v in w[1].iter_mut() {
        *v = 0;
    }
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    let honest = match witness::build_shaped(&sh, &public, &ff, &input) {
        Ok(x) => x,
        Err(e) => {
            eprintln!("REVIEW-R2-1 honest witness refused: {e}");
            return;
        }
    };
    let xh = x2_true(&sh, &honest);
    drop(honest);
    set_forge(Some(Forge { h: 0, t: 31, j: 0, delta: 511, k: 1, naive: false }));
    let fw = witness::build_shaped(&sh, &public, &ff, &input);
    let n = forged_count();
    set_forge(None);
    let fw = match fw {
        Ok(x) => x,
        Err(e) => {
            eprintln!("REVIEW-R2-1 forged witness refused downstream: {e}");
            return;
        }
    };
    let xf = x2_true(&sh, &fw);
    let ndiff = xf.iter().zip(xh.iter()).filter(|(a, b)| a != b).count();
    let ids = Ids::new(&sh).unwrap();
    let ctx = *blake3::hash(b"review r2-1").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &plane16(&fw, ids.at(A_X)), &plane16(&fw, ids.at(A_X2))).unwrap();
    let verdict = match super::protocol::prove_inner_at(&sh, &blk, fw, &expected, owners) {
        Err(e) => Err(format!("prover: {e}")),
        Ok((r, _)) => r.to_bytes_at(&sh, &blk, &expected).and_then(|b| verify_bytes_at(&sh, &blk, &expected, &b)).map_err(|e| format!("verifier: {e}")),
    };
    eprintln!(
        "REVIEW-R2-1 RESULT: wrap forgery applied {n} time(s); output differs in {ndiff} of {} words; single-block verdict at the non-door shape: {}",
        xh.len(),
        match &verdict { Ok(()) => "ACCEPTED".to_string(), Err(e) => format!("rejected: {}", e.chars().take(160).collect::<String>()) }
    );
    // and a door-built verifier of the same profile string cannot be pointed at it
    let door = Shape::rung_tc(&rung_tc_calibration()).unwrap();
    eprintln!("REVIEW-R2-1 the door-built rung-TC shape refuses single-block verification: {:?}", super::protocol::single_block_profile_allowed(&door).err().map(|e| e.chars().take(80).collect::<String>()));
}

// ------------------------------------------------------------------ 2

fn edge_case(name: &str, cal: NormCalibration, bands: Bands) {
    let sh = match Shape::rung_tc(&cal) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("REVIEW-R2-2 [{name}] the door REFUSES: {e}");
            return;
        }
    };
    let (w, input) = trained_dense_words(&sh, bands);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    let wit = match witness::build_shaped(&sh, &public, &ff, &input) {
        Ok(x) => x,
        Err(e) => {
            eprintln!("REVIEW-R2-2 [{name}] honest witness not admissible with this recipe (completeness note only): {e}");
            return;
        }
    };
    let b = prove_one_bound(&sh, &blk, wit).expect("the edge proves");
    let eb = b.expected.to_bytes();
    verify_one_bound(&sh, &blk, &eb, &b.seg).expect("the edge verifies");
    eprintln!("REVIEW-R2-2 [{name}] honest bound run verifies ({} B)", b.seg.len());
    let nud = |v: u32, lo: u32, hi: u32| if v < hi { v + 1 } else { v - 1 };
    let mut refused = 0;
    for (sname, v) in [
        ("sh_qkv", NormCalibration { sh_qkv: nud(cal.sh_qkv, 1, 8), ..cal }),
        ("sh_s", NormCalibration { sh_s: nud(cal.sh_s, 1, 8), ..cal }),
        ("sh_o", NormCalibration { sh_o: nud(cal.sh_o, 9, 16), ..cal }),
        ("sh_g", NormCalibration { sh_g: nud(cal.sh_g, 1, 8), ..cal }),
        ("sh_h", NormCalibration { sh_h: nud(cal.sh_h, 9, 16), ..cal }),
        ("sh_z", NormCalibration { sh_z: nud(cal.sh_z, 1, 8), ..cal }),
        ("sh_ao", NormCalibration { sh_ao: nud(cal.sh_ao, 0, 8), ..cal }),
    ] {
        let other = Shape::rung_tc(&v).unwrap();
        assert!(verify_one_bound(&other, &blk, &eb, &b.seg).is_err(), "[{name}] a verifier with {sname} moved ACCEPTED");
        // a witness honest under the moved shift, proved under the declared one
        if let Ok(ow) = witness::build_shaped(&other, &public, &ff, &input) {
            let verdict = prove_one_bound(&sh, &blk, ow).and_then(|b2| verify_one_bound(&sh, &blk, &b2.expected.to_bytes(), &b2.seg));
            match verdict {
                Ok(()) => panic!("[{name}] a witness honest under {sname} moved VERIFIED"),
                Err(e) => eprintln!("REVIEW-R2-2 [{name}] witness honest under {sname} moved: rejected: {}", e.chars().take(90).collect::<String>()),
            }
        } else {
            eprintln!("REVIEW-R2-2 [{name}] witness under {sname} moved is itself refused; verifier control only");
        }
        refused += 1;
    }
    eprintln!("REVIEW-R2-2 [{name}] {refused} moved-shift verifiers refuse");
}

#[test]
fn r2_2_shift_window_edges_at_the_rung() {
    let base = rung_tc_calibration();
    let tops = NormCalibration { sh_qkv: 8, sh_s: 8, sh_o: 16, sh_g: 8, sh_h: 16, sh_z: 8, sh_ao: 8, ..base };
    edge_case("tops", tops, TRAINED_BANDS);
    let bottoms = NormCalibration { sh_qkv: 1, sh_s: 1, sh_o: 9, sh_g: 1, sh_h: 9, sh_z: 1, sh_ao: 0, ..base };
    edge_case("bottoms, trained bands", bottoms, TRAINED_BANDS);
    edge_case("bottoms, tiny bands", bottoms, Bands { attn: 1, gate: 1, down: 1, gains: (1, 1), xmag: 40 });
    let mixed = NormCalibration { sh_qkv: 8, sh_s: 1, sh_o: 9, sh_g: 8, sh_h: 9, sh_z: 1, sh_ao: 0, ..base };
    edge_case("mixed", mixed, Bands { attn: 1, gate: 1, down: 1, gains: (1, 1), xmag: 40 });
    // outside the windows: the door refuses by name
    for (sname, v) in [
        ("sh_qkv 0", NormCalibration { sh_qkv: 0, ..base }),
        ("sh_qkv 9", NormCalibration { sh_qkv: 9, ..base }),
        ("sh_o 8", NormCalibration { sh_o: 8, ..base }),
        ("sh_o 17", NormCalibration { sh_o: 17, ..base }),
        ("sh_h 17", NormCalibration { sh_h: 17, ..base }),
        ("sh_z 9", NormCalibration { sh_z: 9, ..base }),
        ("sh_ao 9", NormCalibration { sh_ao: 9, ..base }),
    ] {
        let e = Shape::rung_tc(&v).err().unwrap_or_else(|| panic!("the door ADMITTED {sname}"));
        eprintln!("REVIEW-R2-2 door refuses {sname}: {}", e.chars().take(110).collect::<String>());
    }
}

// ------------------------------------------------------------------ 3

#[test]
#[ignore = "review r2 heavy: TinyLlama f_e 16 witnesses x3 + proofs x2"]
fn r2_3_the_f_e_class_edge_at_the_trained_tinyllama_profile() {
    let sh = Shape::tinyllama_t32_trained(&pg_calibration(), 16).expect("f_e 16 is admitted");
    eprintln!("REVIEW-R2-3 shape f_e {} wrho_s {} sigma limbs {}", sh.f_e, sh.wrho_s, sh.limbs_sigma_s());
    let (mut w, input) = trained_dense_words(&sh, TRAINED_BANDS);
    for v in w[1].iter_mut() {
        *v = 0; // all scores equal: the largest Sum a row can have, 32 * 2^16
    }
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    let honest = witness::build_shaped(&sh, &public, &ff, &input).expect("the honest witness at f_e 16");
    let b = prove_one_bound(&sh, &blk, honest).expect("f_e 16 proves");
    verify_one_bound(&sh, &blk, &b.expected.to_bytes(), &b.seg).expect("f_e 16 verifies");
    eprintln!("REVIEW-R2-3 honest bound run at f_e 16 verifies ({} B)", b.seg.len());
    // the round-1 wrapping forgery: no remainder in [0, Sum) exists, so the hook declines
    let mut applied = 0;
    for (delta, k) in [(511i64, 1i128), (1023, 1), (-16, -1), (1, 1), (1, -1)] {
        set_forge(Some(Forge { h: 0, t: 31, j: 0, delta, k, naive: false }));
        let r = witness::build_shaped(&sh, &public, &ff, &input);
        applied += forged_count();
        set_forge(None);
        drop(r);
        if applied > 0 {
            break;
        }
    }
    eprintln!("REVIEW-R2-3 wrapping forgeries applicable at f_e 16: {applied}");
    assert_eq!(applied, 0);
    // the naive forgery is rejected at slot 17
    set_forge(Some(Forge { h: 0, t: 31, j: 0, delta: 1, k: 0, naive: true }));
    let fw = witness::build_shaped(&sh, &public, &ff, &input);
    let n = forged_count();
    set_forge(None);
    let fw = fw.expect("the naive forged witness builds");
    assert_eq!(n, 1);
    let e = prove_one_bound(&sh, &blk, fw).and_then(|b2| verify_one_bound(&sh, &blk, &b2.expected.to_bytes(), &b2.seg)).err().expect("the naive forgery VERIFIED at f_e 16");
    eprintln!("REVIEW-R2-3 naive forgery at f_e 16: rejected: {}", e.chars().take(140).collect::<String>());
    assert!(e.contains("slot 17"), "{e}");
}

// ------------------------------------------------------------------ 4

fn i8b(v: &[i8]) -> Vec<u8> {
    v.iter().map(|x| *x as u8).collect()
}
fn i16b(v: &[i16]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}
fn i64b(v: &[i64]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

/// A TinyLlama export (r2 format: `variant`, per-profile shifts, table keys)
/// at the f_e class edge with every shift at the top of its window and the
/// HONEST x_out, written under `ZK60_REVIEW_DIR` for the production CLI.
#[test]
#[ignore = "review r2 heavy: one TinyLlama witness; writes an export"]
fn r2_4_write_an_edge_export_for_the_production_cli() {
    use super::trained_block::{hex, sha256};
    let cal = NormCalibration { sh_qkv: 8, sh_s: 8, sh_o: 16, sh_g: 8, sh_h: 16, sh_z: 8, sh_ao: 8, ..pg_calibration() };
    let f_e = 16u32;
    let sh = Shape::tinyllama_t32_trained(&cal, f_e).expect("the edge is admitted");
    let (w, input) = trained_dense_words(&sh, TRAINED_BANDS);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let wit = witness::build_shaped(&sh, &public, &ff, &input).expect("the honest edge witness");
    let x_out = x2_true(&sh, &wit);
    let root = std::path::PathBuf::from(std::env::var_os("ZK60_REVIEW_DIR").expect("ZK60_REVIEW_DIR"));
    let vdir = root.join("export-edge").join("review-edge-dir");
    let _ = std::fs::remove_dir_all(root.join("export-edge"));
    let (ldir, sdir) = (vdir.join("layer_00"), vdir.join("seq_s0"));
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
        ("exp", i64b(&public.exp), "int64", "[256]".into()),
        ("act", i16b(&ff.act), "int16", "[256]".into()),
    ];
    let mut entries = Vec::new();
    for (name, bytes, dtype, shape) in &arrays {
        std::fs::write(ldir.join(format!("{name}.bin")), bytes).unwrap();
        entries.push(format!("\"{name}\": {{\"file\": \"{name}.bin\", \"dtype\": \"{dtype}\", \"shape\": {shape}, \"sha256\": \"{}\"}}", hex(&sha256(bytes))));
    }
    let consts = format!(
        "{{\"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_qkv\": {}, \"sh_rope\": 7, \"sh_s\": {}, \"sh_o\": {}, \"sh_ao\": {}, \"sh_g\": {}, \"sh_u\": 0, \"sh_h\": {}, \"sh_z\": {}, \"f_e\": {f_e}, \"f_p\": 9, \"f_ro\": 7, \"sh_r2\": 0, \"silu_member\": [-3, -11], \"exp_e_s\": 0, \"rope_theta\": 10000.0}}",
        cal.tn, cal.cn_a, cal.cn_m, cal.ceps, cal.sh_qkv, cal.sh_s, cal.sh_o, cal.sh_ao, cal.sh_g, cal.sh_h, cal.sh_z
    );
    let manifest = format!("{{\"layer\": 0, \"constants\": {consts}, \"arrays\": {{{}}}}}\n", entries.join(", "));
    std::fs::write(ldir.join("manifest.json"), &manifest).unwrap();
    std::fs::write(sdir.join("x_in_L00.bin"), i16b(&input)).unwrap();
    std::fs::write(sdir.join("x_out_L00.bin"), i16b(&x_out)).unwrap();
    let pin = super::trained_statement::ModelSource::tinyllama_chat_v1_0();
    let profile = format!(
        "{{\"schema\": \"zk60-trained-profile-export/1\", \"kind\": \"profile\", \"variant\": \"review-edge\", \"geometry\": \"tinyllama-1.1b-t32\", \"model\": {{\"repo\": \"{}\", \"revision\": \"{}\", \"sha256\": \"{}\"}}, \"calibration_tool\": {{\"path\": \"reviewer\", \"sha256\": \"{}\"}}, \"T\": 32, \"profile_constants\": {consts}, \"layers\": [{{\"layer\": 0, \"dir\": \"layer_00\", \"manifest_sha256\": \"{}\"}}], \"sequences\": [\"seq_s0\"]}}\n",
        pin.repo,
        pin.revision,
        hex(&pin.weights_sha256),
        hex(&sha256(b"reviewer round 2: a synthetic edge export, not a calibration")),
        hex(&sha256(manifest.as_bytes()))
    );
    std::fs::write(vdir.join("profile.json"), profile).unwrap();
    eprintln!("REVIEW-R2-4 wrote {}", vdir.display());
}
