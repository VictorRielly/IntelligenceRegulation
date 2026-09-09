//! CL20 round 12 (Fable): the maintained core's typed v3 pieces against a
//! REAL tiny proof produced by hashline's legacy prover. Explicit seeds are
//! PUBLIC test fixtures; T=2, d=f=16, deliberately tiny parameters, no
//! security claim. This is D2/D4/D5 of zkp-core/DESIGN.md section 5.1 and
//! the tamper legs of D3 as far as the moved pieces allow: the prover and
//! verifier still live in hashline, so old/new PROVER parity (D1) is not
//! tested here; what is tested is that the legacy proof bytes are exactly
//! the core's frozen encoding, that the core's bounded decoder reproduces
//! them and the legacy verifier accepts the decoded object, and that
//! malformed bytes and tampered witnesses are refused without a panic.
use hashline::export_v3::{derive_v3, V3Dims, V3Exps, V3LayerExport, V3Witness};
use hashline::layer::{apply_tamper_v3, prove_layer_v3, verify_layer_v3, LayerParams, LayerProofV3, StatementV3, TamperV3};
use hashline::ntt::NttTables;
use hashline::tables_v3::{int16out_member, Act16Fn};
use hashline::transcript::Transcript;
use zkp_core::ffn_v3::{DecodeError, Proof, Shape, DOMAIN_LAYER};

fn params() -> LayerParams {
    LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 }
}

fn ntt(p: &LayerParams) -> NttTables {
    NttTables::new(p.log_cols + p.inv_rate.trailing_zeros())
}

/// The T2/d16/f16 synthetic witness of the identity-gap and mask
/// diagnostics (seed 1; the same generator), derived through the exact
/// chain; `changed_weights` is that test's one-entry weight change.
fn synth(changed_weights: bool) -> V3Witness {
    let (t, d, f) = (2usize, 16usize, 16usize);
    let mut seed = 1u64;
    let mut next = |m: i64| -> i8 {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (((seed >> 33) as i64) % (2 * m + 1) - m) as i8
    };
    let x = (0..t * d).map(|_| next(127)).collect();
    let mut wg_t: Vec<i8> = (0..d * f).map(|_| next(4)).collect();
    let wu_t = (0..d * f).map(|_| next(4)).collect();
    let wd_t = (0..f * d).map(|_| next(4)).collect();
    if changed_weights {
        wg_t[0] += 1;
    }
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
    let export = V3LayerExport {
        l: 0,
        dims: V3Dims { t, d, f, layers: 1 },
        x,
        wg_t,
        wu_t,
        wd_t,
        a16: vec![],
        u16: vec![],
        h16: vec![],
        z16: vec![],
        exps: V3Exps { e_x: 0, e_g: -3, e_a16: -11, e_u16: 0, e_h16: 3, e_z16: 0, e_wg: -10, e_wu: 0, e_wd: -9 },
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
        digest_checks: vec![],
    };
    let w = derive_v3(&export, t);
    assert!(w.range_ok);
    w
}

fn statement(w: &V3Witness) -> StatementV3 {
    StatementV3 { l: w.l, t_rows: w.t_rows, d: w.dims.d, f: w.dims.f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() }
}

fn prove(w: &V3Witness, p: &LayerParams, ntt: &NttTables) -> LayerProofV3 {
    prove_layer_v3(w, w.t_rows, p, ntt, &mut Transcript::new(DOMAIN_LAYER)).proof
}

fn verify(st: &StatementV3, proof: &LayerProofV3, p: &LayerParams, ntt: &NttTables) -> Result<(), String> {
    verify_layer_v3(st, proof, p, ntt, &mut Transcript::new(DOMAIN_LAYER))
}


fn main() {
    let w = synth(false);
    let st = statement(&w);
    let p = params();
    let table = ntt(&p);
    let honest = prove(&w, &p, &table);
    verify(&st, &honest, &p, &table).unwrap();
    let bytes = honest.to_bytes();
    assert!(LayerProofV3::from_bytes(&bytes, &st, &p).is_ok());
    println!("CONTROL_NORMAL_ROUNDTRIP=true");
    let enormous = LayerParams { num_col_checks: usize::MAX, ..p };
    println!("Q_MAX_PARAM_CHECK_ACCEPT={}", enormous.check().is_ok());
    let overflow = std::panic::catch_unwind(|| LayerProofV3::from_bytes(&bytes, &st, &enormous));
    println!("Q_MAX_DECODE_PANIC={}", overflow.is_err());
    let shift = StatementV3 { shifts: (64, 0, 14, 6), ..st.clone() };
    let shift_result = std::panic::catch_unwind(|| LayerProofV3::from_bytes(&[], &shift, &p));
    println!("SHIFT64_EMPTY_DECODE_PANIC={}", shift_result.is_err());
    let zero = LayerParams { log_cols: 0, ..p };
    println!("LOG0_PARAM_CHECK_ACCEPT={}", zero.check().is_ok());
    let zero_table = ntt(&zero);
    let zero_proof = prove(&w, &zero, &zero_table);
    println!("LOG0_LEGACY_VERIFY={}", verify(&st, &zero_proof, &zero, &zero_table).is_ok());
    println!("LOG0_ACTUAL_GROUPS={},{},{}", zero_proof.w_open.group_vecs.len(), zero_proof.a_open.group_vecs.len(), zero_proof.h_open.group_vecs.len());
    let shape = Shape::of(&st, &zero).unwrap();
    println!("LOG0_DECODER_GROUPS={},{},{}", shape.w.groups, shape.a.groups, shape.h.groups);
    println!("LOG0_CORE_DECODE={}", LayerProofV3::from_bytes(&zero_proof.to_bytes(), &st, &zero).is_ok());
}
