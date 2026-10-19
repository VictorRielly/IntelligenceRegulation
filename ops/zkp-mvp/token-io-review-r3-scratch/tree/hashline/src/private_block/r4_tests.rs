//! **NATIVE LANE, ROUND 4: the trained Llama-3-8B profile at T = 32.** TEST
//! CODE ONLY. Public synthetic data only; NOT the trained model (that is
//! the calibration export, R4-3).
//!
//! * the counted layouts of the 8B geometry at every admissible row width,
//!   and the one registered;
//! * the validator derives `tn <= 9` at width 4096 (D24);
//! * the RoPE base is pinned per profile; the 8B profile carries the pinned
//!   Llama-3-8B checkpoint; the Rust table generators reproduce the
//!   calibration lane's 8B table digests (RoPE base 500000, exp head_dim 128);
//! * R4-2 (heavy, release): ONE generic dense block at the true 8B geometry
//!   proves as a bound one-block run, verifies, and every control refuses;
//!   the saved segment verifies in a FRESH process.

use super::layout::*;
use super::shape::{NormCalibration, Shape, LLAMA3_8B_LOG_COLS};
use super::trained_calib_tests::{coefficient_and_receipt_controls, generic_witness_with, inconsistent_witness_controls, llama3_8b, llama3_8b_calibration, prove_bytes, verify_one_bound, Bands, TRAINED_BANDS};
use super::*;

#[test]
fn the_llama3_8b_counted_layouts() {
    let c = llama3_8b_calibration();
    let mut best: Option<(usize, usize)> = None;
    for lc in 11..=16 {
        match Shape::llama3_8b_t32_at(lc, &c, 9) {
            Ok(sh) => match Layout::for_shape(&sh) {
                Ok(lay) => {
                    let tt = sh.totals();
                    assert_eq!((lay.a_rows, lay.h_rows), (tt.a_rows, tt.h_rows));
                    let n = tt.receipt_bytes.total;
                    eprintln!(
                        "R4 8B T32 log_cols {lc}: A {} rows, H {} rows, endpoint rows {}, receipt {n} B, u8 lookups {}, wrho_s {} ({} limbs), wire ceiling {}",
                        tt.a_rows,
                        tt.h_rows,
                        sh.endpoint_rows,
                        tt.u8_lookups,
                        sh.wrho_s,
                        sh.limbs_sigma_s(),
                        super::wire::wire_ceiling(&sh)
                    );
                    assert!(n <= super::wire::wire_ceiling(&sh));
                    if best.map(|(_, b)| n < b).unwrap_or(true) {
                        best = Some((lc, n));
                    }
                }
                Err(e) => eprintln!("R4 8B T32 log_cols {lc}: layout refused: {e}"),
            },
            Err(e) => eprintln!("R4 8B T32 log_cols {lc}: shape refused: {}", e.chars().take(140).collect::<String>()),
        }
    }
    let sh = llama3_8b();
    assert_eq!((sh.log_cols, sh.endpoint_rows, sh.f_pad, sh.h_pad, sh.d_pad, sh.wrho_s), (LLAMA3_8B_LOG_COLS, 21, 16384, 32, 4096, 14));
    assert_eq!(sh.slots_per_kv_group(), 4, "GQA group 4");
    eprintln!("R4 8B T32: registered row width 2^{LLAMA3_8B_LOG_COLS}; smallest counted receipt at 2^{} ({} B)", best.unwrap().0, best.unwrap().1);
}

/// D24 at width 4096: the validator DERIVES `tn <= 9`; `tn = 10` needs a
/// 33-bit window and is refused; the derived window at tn 9 is 32 (C-6).
#[test]
fn the_validator_derives_tn_9_at_width_4096() {
    let c = llama3_8b_calibration();
    assert_eq!(NormCalibration::max_tn_at_width(4096, c.ceps), 9);
    let (d_max, wrho) = c.derive_at_width(4096).expect("tn 9 at width 4096");
    assert_eq!(wrho, 32);
    assert_eq!(d_max, 2_097_152, "isqrt(ceps + 4096 * 32768^2)");
    let e = Shape::llama3_8b_t32_trained(&NormCalibration { tn: 10, ..c }, 9).unwrap_err();
    assert!(e.contains("exceeds four byte limbs") && e.contains("tn must be at most 9"), "{e}");
    let sh = llama3_8b();
    assert!(sh.norm_top_is_full_byte(), "C-6 at the 8B window");
}

/// the RoPE base is pinned per profile, the 8B profile carries its own pin
#[test]
fn the_rope_base_and_the_checkpoint_are_pinned_per_profile() {
    use super::shape::{trained_rope_theta, LLAMA3_8B_T32_TRAINED_PROFILE, TINYLLAMA_T128_TRAINED_PROFILE, TINYLLAMA_T32_TRAINED_PROFILE, TRAINED_CALIB_RUNG_PROFILE};
    use super::trained_statement::*;
    assert_eq!(trained_rope_theta(LLAMA3_8B_T32_TRAINED_PROFILE), Some(500_000.0));
    for p in [TINYLLAMA_T32_TRAINED_PROFILE, TINYLLAMA_T128_TRAINED_PROFILE, TRAINED_CALIB_RUNG_PROFILE] {
        assert_eq!(trained_rope_theta(p), Some(10_000.0), "{p}");
    }
    assert_eq!(trained_rope_theta(super::shape::TOY_PROFILE), None);
    let pin = ModelSource::llama3_8b();
    assert_eq!(super::trained_block::hex(&pin.weights_sha256), "7b8447563053b130bf8e83985a39621983aa250bb59d2b798d718f56d2abf776", "the canonical shard-list digest");
    assert_eq!(ModelSource::pinned_for_profile(LLAMA3_8B_T32_TRAINED_PROFILE), Some(pin.clone()));
    let sh = llama3_8b();
    let rp = super::run::RUN_PROFILE_LLAMA3_8B_T32_TRAINED;
    let mut prov = Provenance::recipe("r4/pin", 5.57e-4, [1; 32], [2; 32]);
    let rec = vec![LayerRecord { index: 0, block_digest: [1; 32], word_sha256: [[2; 32]; 9], table_sha256: [[3; 32]; 3], source_tensors: vec![], manifest_sha256: [4; 32], silu_member: (-3, -11), exp_e_s: 1, sh_s: None }];
    // the TinyLlama base at the 8B profile is refused, the 8B base accepted
    let e = TrainedModelStatement::new(&sh, rp, pin.clone(), IntegerCalibration::as_the_code_proves(&sh, &prov), rec.clone()).unwrap_err();
    assert!(e.contains("RoPE base"), "{e}");
    prov.rope_theta = 500_000.0;
    let st = TrainedModelStatement::new(&sh, rp, pin.clone(), IntegerCalibration::as_the_code_proves(&sh, &prov), rec.clone()).expect("the 8B statement");
    assert_eq!(st.block_profile, LLAMA3_8B_T32_TRAINED_PROFILE);
    // the TinyLlama checkpoint at the 8B profile is refused, and vice versa
    let e = TrainedModelStatement::new(&sh, rp, ModelSource::tinyllama_chat_v1_0(), IntegerCalibration::as_the_code_proves(&sh, &prov), rec.clone()).unwrap_err();
    assert!(e.contains("pinned"), "{e}");
    let t = Shape::tinyllama_t32_trained(&super::trained_calib_tests::pg_calibration(), 9).unwrap();
    let tprov = Provenance::recipe("r4/pin", 1.0, [1; 32], [2; 32]);
    assert!(TrainedModelStatement::new(&t, super::run::RUN_PROFILE_TINYLLAMA_T32_TRAINED, pin, IntegerCalibration::as_the_code_proves(&t, &tprov), rec).unwrap_err().contains("pinned"));
}

/// the Rust generators reproduce the calibration lane's 8B table digests
/// (`results/zk60_8b_calibration_20261017/PROGRESS.md`): RoPE T32 base
/// 500000 head_dim 128 -> d937dca0..., exp head_dim 128 f_e 9 e_s 1 ->
/// a28d4812..., e_s 2 -> 423a43e7...
#[test]
fn the_8b_table_generators_match_the_calibration_lanes_digests() {
    let (c, s) = crate::tables_attn::rope_tables_generate(32, 128, 500_000.0, F_RO);
    let rd = crate::tables_attn::rope_digest(32, 128, 500_000.0, F_RO, &c, &s);
    let (_, e1) = crate::tables_attn::exp_member(1, 128, 9);
    let (_, e2) = crate::tables_attn::exp_member(2, 128, 9);
    eprintln!("R4 8B tables: rope {rd}; exp e_s 1 {e1}; exp e_s 2 {e2}");
    assert!(rd.starts_with("d937dca0"), "rope: {rd}");
    assert!(e1.starts_with("a28d4812"), "exp e_s 1: {e1}");
    assert!(e2.starts_with("423a43e7"), "exp e_s 2: {e2}");
}

// ------------------------------------------------------------- R4-2

/// **The R4-2 generic block's calibration**: the B5 smoke's constants with
/// both norm multipliers raised inside the class (Cn_a 6380, Cn_m 6672), so
/// that a SYNTHETIC block's norm outputs use the int8 class: at width 4096
/// `y ~ Cn g (x / rms) / (2^tn sqrt(4096))`, and the smoke's Cn_m 834 gives
/// max |y_m| 6 on the synthetic recipe (measured; the generic-witness check
/// asks for at least 8). Real calibrated gammas are the export's (R4-3).
fn generic_8b_calibration() -> NormCalibration {
    NormCalibration { cn_a: 6380, cn_m: 6672, ..llama3_8b_calibration() }
}

fn generic_8b() -> Shape {
    Shape::llama3_8b_t32_trained(&generic_8b_calibration(), 9).expect("the generic 8B shape")
}

fn evidence_dir() -> Option<std::path::PathBuf> {
    std::env::var_os("ZK60_NATIVE_R4_DIR").map(std::path::PathBuf::from)
}

/// the dense bands at the 8B geometry: TinyLlama's first, then narrower
/// ones, the FIRST whose witness is admissible (the 8B sums run over twice
/// the width and 2.5x the hidden size)
fn bands_8b(sh: &Shape) -> Bands {
    let cands = [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 4, gate: 6, down: 1, xmag: 4_000, ..TRAINED_BANDS }];
    for b in cands {
        let (blk, input) = super::trained_calib_tests::trained_dense_block_with(sh, b);
        match witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &input) {
            Ok(_) => {
                eprintln!("R4-2 bands at the 8B geometry: {b:?} admissible");
                return b;
            }
            Err(e) => eprintln!("R4-2 bands {b:?}: refused ({e})"),
        }
    }
    panic!("no candidate band is admissible at the 8B geometry");
}

/// **R4-2: ONE GENERIC BLOCK AT THE TRUE Llama-3-8B T32 GEOMETRY** (dense
/// synthetic weights, every query head and all 8 key-value groups live and
/// different, the upper hidden half live, non-toy constants in class), the
/// witness equal to the independent shape-driven kernel, proved as a bound
/// one-block run, verified from bytes, every coefficient / shift / receipt /
/// inconsistent-witness control refusing. With `ZK60_NATIVE_R4_DIR` set the
/// segment, the policy, the block digest and the bands are saved for the
/// fresh-process verifier below.
#[test]
#[ignore = "native lane heavy: one width-4096 Llama-3-8B-geometry block proof (release, guarded)"]
fn native_r4_2_generic_llama3_8b_block_proves_verifies_and_every_control_refuses() {
    let sh = generic_8b();
    let b = bands_8b(&sh);
    let (blk, input, w) = generic_witness_with(&sh, b);
    let hwm_w = super::run::peak_rss_mib();
    let (expected, bytes, prove_s) = prove_bytes(&sh, &blk, w);
    let hwm_p = super::run::peak_rss_mib();
    let t1 = std::time::Instant::now();
    verify_one_bound(&sh, &blk, &expected.to_bytes(), &bytes).expect("verifies from bytes");
    let verify_s = t1.elapsed().as_secs_f64();
    if let Some(dir) = evidence_dir() {
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("r4-segment.bin"), &bytes).unwrap();
        std::fs::write(dir.join("r4-expected.bin"), expected.to_bytes()).unwrap();
        std::fs::write(dir.join("r4-block-digest.hex"), super::trained_block::hex(&blk.digest())).unwrap();
        std::fs::write(dir.join("r4-bands.txt"), format!("{} {} {} {} {} {}\n", b.attn, b.gate, b.down, b.gains.0, b.gains.1, b.xmag)).unwrap();
    }
    eprintln!(
        "NATIVE R4-2 Llama-3-8B trained T32, ONE dense synthetic block: prove {prove_s:.2} s, verify from bytes {verify_s:.2} s, segment {} B, peak RSS after witness {hwm_w:.0} MiB, after prove {hwm_p:.0} MiB, block digest {} on {} rayon threads (shared box; NOT the trained model)",
        bytes.len(),
        &super::trained_block::hex(&blk.digest())[..16],
        rayon::current_num_threads()
    );
    let mk = |c: &NormCalibration| Shape::llama3_8b_t32_trained(c, 9);
    coefficient_and_receipt_controls(&sh, &mk, &blk, &expected, &bytes);
    inconsistent_witness_controls(&sh, &mk, &blk, &input);
}

/// **R4-2, the FRESH-PROCESS verifier**: rebuilds the shape and the public
/// statement from the public recipe alone (the saved bands), checks the
/// block digest, verifies the saved segment, and the wrong-constant
/// verifiers refuse it.
#[test]
#[ignore = "native lane heavy: verifies a saved width-4096 segment in a fresh process"]
fn native_r4_2_verify_the_saved_8b_segment_in_a_fresh_process() {
    let dir = evidence_dir().expect("ZK60_NATIVE_R4_DIR is set");
    let sh = generic_8b();
    let v: Vec<i64> = std::fs::read_to_string(dir.join("r4-bands.txt")).unwrap().split_whitespace().map(|x| x.parse().unwrap()).collect();
    let b = Bands { attn: v[0], gate: v[1], down: v[2], gains: (v[3], v[4]), xmag: v[5] };
    let (w, _) = super::dense_tests::dense_public_words_with(&sh, b.attn, b.gate, b.down, b.gains);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public, ff);
    let want = std::fs::read_to_string(dir.join("r4-block-digest.hex")).unwrap();
    assert_eq!(super::trained_block::hex(&blk.digest()), want.trim(), "the rebuilt public statement is not the prover's");
    let expected = ExpectedIo::from_bytes_at(&sh, &std::fs::read(dir.join("r4-expected.bin")).unwrap()).expect("the expected policy");
    let bytes = std::fs::read(dir.join("r4-segment.bin")).unwrap();
    let t1 = std::time::Instant::now();
    verify_one_bound(&sh, &blk, &expected.to_bytes(), &bytes).expect("the saved 8B segment verifies in a fresh process");
    eprintln!("NATIVE R4-2 fresh-process verify: {:.2} s, {} B, peak RSS {:.0} MiB", t1.elapsed().as_secs_f64(), bytes.len(), super::run::peak_rss_mib());
    let mk = |c: &NormCalibration| Shape::llama3_8b_t32_trained(c, 9);
    coefficient_and_receipt_controls(&sh, &mk, &blk, &expected, &bytes);
}
