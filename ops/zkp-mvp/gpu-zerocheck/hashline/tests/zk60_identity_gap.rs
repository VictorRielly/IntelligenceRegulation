//! I1 diagnostics at T=2, d=f=16. Explicit seeds are PUBLIC test fixtures.
//! A passing `known_p3_gap_*` test REPRODUCES a missing constraint; it is not
//! evidence that approved private-model identity has been implemented.

use hashline::export_v3::{derive_v3, V3Dims, V3Exps, V3LayerExport, V3Witness};
use hashline::field::{Fp, Fp2};
use hashline::layer::{LayerParams, LayoutV3, StatementV3};
use hashline::model_identity::{ApprovedP1Layer, IdentityError};
use hashline::ntt::NttTables;
use hashline::pcs::{self, Commitment, PcsParams};
use hashline::tables_v3::{int16out_member, Act16Fn};
use hashline::transcript::Transcript;
use hashline::zk::{
    prove_layer_zk_v3, verify_layer_zk_v3, LayerProofZk, OutputClaim, PredicateSpec, ZkConfig,
    ZkPrivacy, ZkStatementMode,
};

const DOMAIN: &[u8] = b"zk60-approved-single-ffn-test";

fn params() -> LayerParams {
    // Deliberately tiny test parameters, NOT a deployment security claim.
    LayerParams {
        log_cols: 5,
        inv_rate: 4,
        num_col_checks: 12,
    }
}

fn mode(privacy: ZkPrivacy) -> ZkStatementMode {
    ZkStatementMode {
        privacy,
        model_id: Some("example-approved-model".into()),
        ..Default::default()
    }
}

fn synth(changed_weights: bool) -> V3Witness {
    let (t, d, f) = (2usize, 16usize, 16usize);
    let mut seed = 1u64;
    let mut next = |m: i64| -> i8 {
        seed = seed
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
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
        exps: V3Exps {
            e_x: 0,
            e_g: -3,
            e_a16: -11,
            e_u16: 0,
            e_h16: 3,
            e_z16: 0,
            e_wg: -10,
            e_wu: 0,
            e_wd: -9,
        },
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
        digest_checks: vec![],
    };
    assert_eq!(export.exps.shifts(), export.shifts);
    let witness = derive_v3(&export, t);
    assert!(witness.range_ok);
    witness
}

fn statement(w: &V3Witness) -> StatementV3 {
    StatementV3 {
        l: w.l,
        t_rows: w.t_rows,
        d: w.dims.d,
        f: w.dims.f,
        shifts: w.shifts,
        act: w.act,
        table: w.table,
        table_digest: w.table_digest.clone(),
    }
}

fn prove(w: &V3Witness, m: &ZkStatementMode, seed: u64, ntt: &NttTables) -> LayerProofZk {
    let cfg = ZkConfig {
        enabled: true,
        seed: Some(seed),
        mode: m.clone(),
    };
    prove_layer_zk_v3(
        w,
        w.t_rows,
        &params(),
        ntt,
        &cfg,
        &mut Transcript::new(DOMAIN),
    )
    .proof
}

/// Independent registration from known public weights, BEFORE candidate proof
/// creation. This deliberately does not call a prover or read any proof root.
fn public_weight_commitment(w: &V3Witness, p: &LayerParams, ntt: &NttTables) -> Commitment {
    let lay = LayoutV3::new(w.t_rows, w.dims.d, w.dims.f);
    let (db, fb) = (1usize << lay.log_db, 1usize << lay.log_fb);
    let mut data = vec![Fp::ZERO; lay.w_len];
    for c in 0..lay.nb_d {
        for b in 0..lay.nb_f {
            for k in 0..db {
                for j in 0..fb {
                    let source = (c * db + k) * w.dims.f + b * fb + j;
                    let within = k * fb + j;
                    data[lay.wg[c * lay.nb_f + b] + within] = Fp::from_i64(w.wg_t[source] as i64);
                    data[lay.wu[c * lay.nb_f + b] + within] = Fp::from_i64(w.wu_t[source] as i64);
                    data[lay.wd[b * lay.nb_d + c] + j * db + k] =
                        Fp::from_i64(w.wd_t[(b * fb + j) * w.dims.d + c * db + k] as i64);
                }
            }
        }
    }
    let pcs = PcsParams {
        log_cols: p.log_cols.min(lay.log_wb),
        inv_rate: p.inv_rate,
        num_col_checks: p.num_col_checks,
    };
    pcs::commit(&pcs, &data, ntt).commitment()
}

fn registered(w: &V3Witness, ntt: &NttTables) -> (ApprovedP1Layer, Commitment) {
    let root = public_weight_commitment(w, &params(), ntt);
    let policy = ApprovedP1Layer::from_trusted_registration(
        statement(w),
        params(),
        root.clone(),
        mode(ZkPrivacy::P1),
        DOMAIN,
    )
    .unwrap();
    (policy, root)
}

#[test]
fn known_p3_gap_same_declared_model_and_input_different_weights_both_verify() {
    let ntt = NttTables::new(12);
    let approved = synth(false);
    let substitute = synth(true);
    assert_eq!(approved.x, substitute.x);
    assert_ne!(approved.wg_t, substitute.wg_t);
    let m = mode(ZkPrivacy::P3);
    // Separate fixed mask seeds make this a reproducible diagnostic without
    // attributing the identity gap to accidental reuse of the mask stream.
    for (w, seed) in [(&approved, 201), (&substitute, 202)] {
        let proof = prove(w, &m, seed, &ntt);
        verify_layer_zk_v3(
            &statement(&approved),
            &proof,
            &params(),
            &ntt,
            &mut Transcript::new(DOMAIN),
            &m,
        )
        .unwrap();
        println!(
            "KNOWN P3 IDENTITY GAP: model={} Wg[0]={} seed={} proof_sha256={}",
            m.model_id.as_deref().unwrap(),
            w.wg_t[0],
            seed,
            hashline::export::sha256_hex(&proof.to_bytes())
        );
    }
}

#[test]
fn approved_p1_accepts_registered_weights_and_rejects_valid_substitute_and_forged_root() {
    let ntt = NttTables::new(12);
    let w = synth(false);
    let (policy, expected_weights) = registered(&w, &ntt);
    let st = statement(&w);
    let m = mode(ZkPrivacy::P1);
    let honest = prove(&w, &m, 301, &ntt);
    policy.verify(&st, &params(), &m, &honest, &ntt).unwrap();
    let mut substitute = prove(&synth(true), &m, 302, &ntt);
    // The ordinary verifier still accepts this internally consistent proof.
    verify_layer_zk_v3(
        &st,
        &substitute,
        &params(),
        &ntt,
        &mut Transcript::new(DOMAIN),
        &m,
    )
    .unwrap();
    assert_eq!(
        policy.verify(&st, &params(), &m, &substitute, &ntt),
        Err(IdentityError::WeightCommitmentMismatch)
    );
    // Relabelling the root cannot defeat the proof relation checked afterward.
    substitute.w_com = Some(expected_weights);
    assert!(matches!(
        policy.verify(&st, &params(), &m, &substitute, &ntt),
        Err(IdentityError::ProofRejected(_))
    ));
    let mut tampered = honest.clone();
    tampered.gu_claim = tampered.gu_claim.add(Fp2::ONE);
    assert!(matches!(
        policy.verify(&st, &params(), &m, &tampered, &ntt),
        Err(IdentityError::ProofRejected(_))
    ));
}

#[test]
fn approved_p1_rejects_every_changed_statement_parameter_mode_and_commitment_field() {
    let ntt = NttTables::new(12);
    let w = synth(false);
    let (policy, _) = registered(&w, &ntt);
    let st = statement(&w);
    let m = mode(ZkPrivacy::P1);
    let proof = prove(&w, &m, 401, &ntt);
    let mut changed = st.clone();
    changed.l += 1;
    assert_eq!(
        policy.verify(&changed, &params(), &m, &proof, &ntt),
        Err(IdentityError::StatementMismatch("layer"))
    );
    let mut changed = st.clone();
    changed.t_rows *= 2;
    assert_eq!(
        policy.verify(&changed, &params(), &m, &proof, &ntt),
        Err(IdentityError::StatementMismatch("t_rows"))
    );
    for width in ["d", "f"] {
        let mut changed = st.clone();
        if width == "d" {
            changed.d *= 2;
        } else {
            changed.f *= 2;
        }
        assert_eq!(
            policy.verify(&changed, &params(), &m, &proof, &ntt),
            Err(IdentityError::StatementMismatch(width))
        );
    }
    for shifts in [(8, 0, 14, 6), (7, 1, 14, 6), (7, 0, 13, 6), (7, 0, 14, 7)] {
        let mut changed = st.clone();
        changed.shifts = shifts;
        assert_eq!(
            policy.verify(&changed, &params(), &m, &proof, &ntt),
            Err(IdentityError::StatementMismatch("shifts"))
        );
    }
    let mut changed = st.clone();
    changed.act = Act16Fn::GeluTanh;
    assert_eq!(
        policy.verify(&changed, &params(), &m, &proof, &ntt),
        Err(IdentityError::StatementMismatch("activation family"))
    );
    let mut changed = st.clone();
    changed.table_digest.push('0');
    assert_eq!(
        policy.verify(&changed, &params(), &m, &proof, &ntt),
        Err(IdentityError::StatementMismatch("table digest"))
    );
    let mut changed = st.clone();
    changed.table[0] += 1;
    assert_eq!(
        policy.verify(&changed, &params(), &m, &proof, &ntt),
        Err(IdentityError::StatementMismatch("table bytes"))
    );
    for changed in [
        LayerParams {
            log_cols: 4,
            ..params()
        },
        LayerParams {
            inv_rate: 2,
            ..params()
        },
        LayerParams {
            num_col_checks: 1,
            ..params()
        },
    ] {
        assert_eq!(
            policy.verify(&st, &changed, &m, &proof, &ntt),
            Err(IdentityError::ParameterMismatch)
        );
    }
    for declared_model in [None, Some("different-model".into())] {
        let mut changed = m.clone();
        changed.model_id = declared_model;
        assert_eq!(
            policy.verify(&st, &params(), &changed, &proof, &ntt),
            Err(IdentityError::ModeMismatch)
        );
    }
    assert!(matches!(
        policy.verify(&st, &params(), &mode(ZkPrivacy::P3), &proof, &ntt),
        Err(IdentityError::UnsupportedPolicy(_))
    ));
    let mut predicate = m.clone();
    predicate.output = OutputClaim::BinaryAcceptable;
    predicate.pred = Some(PredicateSpec {
        row: 0,
        col: 0,
        tau: 0,
    });
    assert!(matches!(
        policy.verify(&st, &params(), &predicate, &proof, &ntt),
        Err(IdentityError::UnsupportedPolicy(_))
    ));
    let mut missing = proof.clone();
    missing.w_com = None;
    assert_eq!(
        policy.verify(&st, &params(), &m, &missing, &ntt),
        Err(IdentityError::MissingWeightCommitment)
    );
    for field in ["root", "rows", "log_cols"] {
        let mut changed = proof.clone();
        let cm = changed.w_com.as_mut().unwrap();
        match field {
            "root" => cm.root[0] ^= 1,
            "rows" => cm.rows += 1,
            _ => cm.log_cols += 1,
        }
        assert_eq!(
            policy.verify(&st, &params(), &m, &changed, &ntt),
            Err(IdentityError::WeightCommitmentMismatch)
        );
    }
}

#[test]
fn approved_p1_rejects_incompatible_ntt_and_replay_under_another_registered_domain() {
    let ntt = NttTables::new(12);
    let w = synth(false);
    let (policy, root) = registered(&w, &ntt);
    let st = statement(&w);
    let m = mode(ZkPrivacy::P1);
    let proof = prove(&w, &m, 501, &ntt);
    let too_small = NttTables::new(11);
    assert_eq!(
        policy.verify(&st, &params(), &m, &proof, &too_small),
        Err(IdentityError::IncompatibleNtt("transform capacity"))
    );
    let mut malformed = NttTables::new(12);
    malformed.max_log = 13;
    assert_eq!(
        policy.verify(&st, &params(), &m, &proof, &malformed),
        Err(IdentityError::IncompatibleNtt(
            "inconsistent table dimensions"
        ))
    );
    let mut malformed = NttTables::new(12);
    malformed.roots.pop();
    assert_eq!(
        policy.verify(&st, &params(), &m, &proof, &malformed),
        Err(IdentityError::IncompatibleNtt(
            "inconsistent table dimensions"
        ))
    );
    let mut malformed = NttTables::new(12);
    malformed.inv_roots[2] = Fp::ZERO;
    assert_eq!(
        policy.verify(&st, &params(), &m, &proof, &malformed),
        Err(IdentityError::IncompatibleNtt("noncanonical roots"))
    );
    let other = ApprovedP1Layer::from_trusted_registration(
        st.clone(),
        params(),
        root,
        m.clone(),
        b"another-application",
    )
    .unwrap();
    assert!(matches!(
        other.verify(&st, &params(), &m, &proof, &ntt),
        Err(IdentityError::ProofRejected(_))
    ));
}

#[test]
fn registration_rejects_unsupported_policy_invalid_shape_table_and_parameters() {
    let ntt = NttTables::new(12);
    let w = synth(false);
    let root = public_weight_commitment(&w, &params(), &ntt);
    let st = statement(&w);
    let make = |s, p, cm, m| ApprovedP1Layer::from_trusted_registration(s, p, cm, m, DOMAIN);
    assert!(matches!(
        make(st.clone(), params(), root.clone(), mode(ZkPrivacy::P3)),
        Err(IdentityError::UnsupportedPolicy(_))
    ));
    let mut predicate = mode(ZkPrivacy::P1);
    predicate.pred = Some(PredicateSpec {
        row: 0,
        col: 0,
        tau: 0,
    });
    assert!(matches!(
        make(st.clone(), params(), root.clone(), predicate),
        Err(IdentityError::UnsupportedPolicy(_))
    ));
    for p in [
        LayerParams {
            log_cols: 17,
            ..params()
        },
        LayerParams {
            inv_rate: 2,
            ..params()
        },
    ] {
        assert!(matches!(
            make(st.clone(), p, root.clone(), mode(ZkPrivacy::P1)),
            Err(IdentityError::UnsupportedPolicy(_))
        ));
    }
    for p in [
        LayerParams {
            num_col_checks: 0,
            ..params()
        },
        LayerParams {
            num_col_checks: 33,
            ..params()
        },
    ] {
        assert!(matches!(
            make(st.clone(), p, root.clone(), mode(ZkPrivacy::P1)),
            Err(IdentityError::InvalidRegistration(_))
        ));
    }
    for field in ["t_rows", "d", "shifts", "table", "digest"] {
        let mut changed = st.clone();
        match field {
            "t_rows" => changed.t_rows = 3,
            "d" => changed.d = 15,
            "shifts" => changed.shifts.0 = 0,
            "table" => changed.table[0] += 1,
            _ => changed.table_digest.push('0'),
        }
        assert!(
            matches!(
                make(changed, params(), root.clone(), mode(ZkPrivacy::P1)),
                Err(IdentityError::InvalidRegistration(_))
            ),
            "{field}"
        );
    }
    let mut wrong_shape = root.clone();
    wrong_shape.rows += 1;
    assert!(matches!(
        make(st.clone(), params(), wrong_shape, mode(ZkPrivacy::P1)),
        Err(IdentityError::InvalidRegistration(_))
    ));
    assert!(matches!(
        ApprovedP1Layer::from_trusted_registration(st, params(), root, mode(ZkPrivacy::P1), b""),
        Err(IdentityError::InvalidRegistration(_))
    ));
}
