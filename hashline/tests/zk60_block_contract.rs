//! CPU-only metadata/host-oracle tests. No private block proof is constructed.
use hashline::attention::{attn_layout_of, AttnConsts, AttnShape, Cls, FullConsts, NormConsts};
use hashline::export_v3::{derive_v3, V3Dims, V3Exps, V3LayerExport};
use hashline::field::Fp;
use hashline::layer::{LayerParams, LayoutV3, StatementV3};
use hashline::norm::{rmsnorm_chain, window_rule, DivMode};
use hashline::ntt::NttTables;
use hashline::pcs::{self, PcsParams};
use hashline::private_block_contract::{
    ApprovedP1BlockContract, AttentionExponents, BlockRegistration, ContractError,
};
use hashline::tables_attn::{exp_member, rope_digest, rope_tables_generate};
use hashline::tables_v3::{int16out_member, Act16Fn};
use hashline::transcript::Transcript;
use hashline::zk::{PredicateSpec, ZkPrivacy, ZkStatementMode};
use std::sync::OnceLock;

fn fixture() -> BlockRegistration {
    static FIXTURE: OnceLock<BlockRegistration> = OnceLock::new();
    FIXTURE
        .get_or_init(|| {
            let shape = AttnShape {
                t: 32,
                d: 16,
                f: 16,
                heads: 2,
                kv_heads: 1,
                head_dim: 8,
            };
            let (ct, sn) = rope_tables_generate(32, 8, 10000.0, 7);
            let norm = NormConsts {
                tn: 11,
                cn: 1024,
                ceps: 1,
                wrho: 29,
                n_limbs: 2,
            };
            let c = AttnConsts {
                shape,
                layer: 0,
                f_e: 9,
                f_p: 9,
                f_ro: 7,
                rope_base: 10000.0,
                norm_round: true,
                x_cls: Cls::Int16,
                e_r: 0,
                e_xn: -3,
                e_r1: 0,
                e_ao: 0,
                e_xm: -3,
                sh_q: 7,
                sh_k: 7,
                sh_v: 7,
                sh_qr: 7,
                sh_kr: 7,
                sh_s: 6,
                e_s_raw: 0,
                sh_o: 9,
                sh_ao: 7,
                ao_cls: Cls::Int16,
                sh_x1: 0,
                sh_a1: 0,
                sh_r1: 0,
                r1_cls: Cls::Int16,
                anorm: norm,
                mnorm: norm,
                exp_digest: exp_member(0, 8, 9).1,
                rope_digest: rope_digest(32, 8, 10000.0, 7, &ct, &sn),
                wrho_s: 14,
            };
            let residual = FullConsts {
                sh_x2: 0,
                sh_z2: 0,
                sh_r2: 0,
                r2_cls: Cls::Int16,
                e_r2: 0,
                e_z16: 0,
            };
            let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
            let ffn = StatementV3 {
                l: 0,
                t_rows: 32,
                d: 16,
                f: 16,
                shifts: (7, 0, 14, 6),
                act: Act16Fn::Silu,
                table,
                table_digest,
            };
            let params = LayerParams {
                log_cols: 8,
                inv_rate: 8,
                num_col_checks: 256,
            };
            let pp = PcsParams {
                log_cols: 8,
                inv_rate: 8,
                num_col_checks: 256,
            };
            let ntt = NttTables::new(11);
            // Independent public weights: projections zero, gamma=64, Wg=Wu=1,
            // Wd=0. Roots are computed directly BEFORE any candidate is supplied.
            let al = attn_layout_of(&c, &residual, params.log_cols);
            assert_eq!(al.cols_log, 8);
            let mut aw = vec![Fp::ZERO; al.w_len];
            for i in 0..16 {
                aw[al.gpack + i] = Fp::new(64);
                aw[al.gpack + 16 + i] = Fp::new(64);
            }
            let attention_weights = pcs::commit(&pp, &aw, &ntt).commitment();
            let fl = LayoutV3::new(32, 16, 16);
            let mut fw = vec![Fp::ZERO; fl.w_len];
            for i in 0..256 {
                fw[fl.wg[0] + i] = Fp::ONE;
                fw[fl.wu[0] + i] = Fp::ONE;
            }
            let ffn_weights = pcs::commit(&pp, &fw, &ntt).commitment();
            let model_identity =
                *blake3::hash(b"A00 independently approved toy public weights").as_bytes();
            let calibration_identity = *blake3::hash(b"A00 fixed calibration v1").as_bytes();
            BlockRegistration {
                attention: c,
                residual,
                ffn,
                params,
                attention_weights,
                ffn_weights,
                model_identity,
                calibration_identity,
                mode: ZkStatementMode {
                    model_id: Some(hashline::silu::hex(&model_identity)),
                    ..Default::default()
                },
                attention_exponents: AttentionExponents {
                    e_wq: -7,
                    e_wk: -7,
                    e_wv: -7,
                    e_wo: -4,
                    e_q: -3,
                    e_k: -3,
                    e_v: -3,
                    e_qr: -3,
                    e_kr: -3,
                    e_o: -3,
                    e_gamma_a: -6,
                    e_gamma_m: -6,
                },
                ffn_exponents: V3Exps {
                    e_x: -3,
                    e_g: -3,
                    e_a16: -11,
                    e_u16: 0,
                    e_h16: 3,
                    e_z16: 0,
                    e_wg: -7,
                    e_wu: 3,
                    e_wd: -9,
                },
            }
        })
        .clone()
}

#[test]
fn honest_fixed_registration_matches_actual_layout_and_tables() {
    let r = fixture();
    let a = ApprovedP1BlockContract::from_trusted_registration(r.clone()).unwrap();
    a.preflight_candidate(&r).unwrap();
    assert_eq!(
        a.public_digest(),
        ApprovedP1BlockContract::from_trusted_registration(fixture())
            .unwrap()
            .public_digest()
    );
    assert_eq!(
        (r.attention.anorm.tn, r.attention.anorm.cn),
        window_rule(-6, -3, 16)
    );
    let bound = a.host_arithmetic_envelope();
    assert_eq!(bound.norm_square_sum_with_epsilon, 17_179_869_185);
    assert_eq!(bound.max_norm_d, 131_072);
    assert_eq!(bound.max_round_norm_denominator, 536_870_912);
    assert_eq!(bound.max_doubled_norm_numerator, 8_589_934_592);
    assert_eq!(bound.max_scaled_residual_sum, 65_536);
}

#[test]
fn fixed_norm_and_ffn_have_an_honest_exact_integer_fixture_without_fitting() {
    let r = fixture();
    let input: Vec<i64> = (0..512)
        .map(|i| if i / 16 % 2 == 0 { 1 } else { -1 })
        .collect();
    let gamma = vec![64; 16];
    let n = &r.attention.anorm;
    let witness = rmsnorm_chain(&input, &gamma, 16, n.ceps, n.tn, n.cn, DivMode::Round);
    for row in 0..32 {
        assert_eq!(witness.sse[row], 17);
        assert_eq!(witness.dd[row], 4);
        assert_eq!(witness.dsq[row], 16);
        assert_eq!(witness.a1[row], 1);
        assert_eq!(witness.a2[row], 7);
        for col in 0..16 {
            let k = row * 16 + col;
            assert_eq!(witness.xsq[k], 1);
            assert_eq!(witness.y[k], input[k] * 8);
            assert_eq!(witness.rho[k], 8192);
            assert_eq!(witness.sig[k], 8191);
        }
    }
    // Zero attention output projection makes residual 1 exactly input. The
    // second norm uses the same fixed constants and therefore the same y.
    let m = &r.attention.mnorm;
    let mlp = rmsnorm_chain(&input, &gamma, 16, m.ceps, m.tn, m.cn, DivMode::Round);
    let export = V3LayerExport {
        l: 0,
        dims: V3Dims {
            t: 32,
            d: 16,
            f: 16,
            layers: 1,
        },
        x: mlp.y.iter().map(|v| *v as i8).collect(),
        wg_t: vec![1; 256],
        wu_t: vec![1; 256],
        wd_t: vec![0; 256],
        a16: vec![],
        u16: vec![],
        h16: vec![],
        z16: vec![],
        exps: r.ffn_exponents,
        shifts: r.ffn.shifts,
        act: r.ffn.act,
        table: r.ffn.table,
        table_digest: r.ffn.table_digest.clone(),
        digest_checks: vec![],
    };
    let w = derive_v3(&export, 32);
    assert!(w.range_ok);
    for row in 0..32 {
        let acc = input[row * 16] * 128;
        let gate = (acc + 64).div_euclid(128);
        let activation = i64::from(r.ffn.table[(gate + 128) as usize]);
        let hh = activation * acc;
        let h = (hh + 8192).div_euclid(16384);
        for col in 0..16 {
            let k = row * 16 + col;
            assert_eq!(i64::from(w.g8[k]), gate);
            assert_eq!(w.rg[k], 0);
            assert_eq!(i64::from(w.a16[k]), activation);
            assert_eq!(i64::from(w.u16v[k]), acc);
            assert_eq!(w.ru[k], 0);
            assert_eq!(i64::from(w.h16[k]), h);
            assert_eq!(i64::from(w.rh[k]), hh - h * 16384);
            assert_eq!(w.z16[k], 0);
            assert_eq!(w.rd[k], 0);
        }
    }
    // No claim here that attention/FFN/seams were cryptographically proved.
}

type Mutation = (&'static str, fn(&mut BlockRegistration));

#[test]
fn hostile_public_fields_fail_closed_without_panics_or_value_disclosure() {
    let changes: &[Mutation] = &[
        ("rows", |r| r.attention.shape.t = usize::MAX),
        ("zero rows", |r| r.attention.shape.t = 0),
        ("T4", |r| r.attention.shape.t = 4),
        ("width", |r| r.attention.shape.d = usize::MAX),
        ("ffn width", |r| r.ffn.f = usize::MAX),
        ("heads", |r| r.attention.shape.heads = 3),
        ("kv zero", |r| r.attention.shape.kv_heads = 0),
        ("head dim", |r| r.attention.shape.head_dim = 0),
        ("layer", |r| r.attention.layer = usize::MAX),
        ("ffn layer", |r| r.ffn.l = 1),
        ("floor", |r| r.attention.norm_round = false),
        ("int24", |r| r.attention.x_cls = Cls::Int24),
        ("output class", |r| r.residual.r2_cls = Cls::Int8),
        ("shift", |r| r.attention.sh_q = i32::MAX),
        ("negative shift", |r| r.attention.sh_q = -1),
        ("exponent", |r| r.ffn_exponents.e_h16 = i32::MIN),
        ("norm tn", |r| r.attention.anorm.tn = u32::MAX),
        ("norm cn", |r| r.attention.anorm.cn = i64::MAX),
        ("norm epsilon", |r| r.attention.anorm.ceps = -1),
        ("norm limb count", |r| {
            r.attention.anorm.n_limbs = usize::MAX
        }),
        ("witness fitted norm width", |r| r.attention.anorm.wrho = 14),
        ("softmax width", |r| r.attention.wrho_s = 40),
        ("resolution", |r| r.attention.f_e = u32::MAX),
        ("nan rope", |r| r.attention.rope_base = f64::NAN),
        ("infinite rope", |r| r.attention.rope_base = f64::INFINITY),
        ("rope digest", |r| {
            r.attention.rope_digest = "private-value-12345".into()
        }),
        ("exp digest", |r| r.attention.exp_digest.clear()),
        ("activation table", |r| r.ffn.table[5] ^= 1),
        ("activation digest", |r| r.ffn.table_digest.clear()),
        ("unapproved input scale", |r| r.ffn_exponents.e_x += 1),
        ("output scale", |r| r.residual.e_z16 += 1),
        ("residual scale", |r| r.residual.sh_x2 = u32::MAX),
        ("attention W shape", |r| {
            r.attention_weights.rows = usize::MAX
        }),
        ("FFN W shape", |r| r.ffn_weights.log_cols = 0),
        ("PCS inverse rate", |r| r.params.inv_rate = 4),
        ("PCS checks", |r| r.params.num_col_checks = 12),
        ("PCS width", |r| r.params.log_cols = u32::MAX),
        ("P3", |r| r.mode.privacy = ZkPrivacy::P3),
        ("predicate", |r| {
            r.mode.pred = Some(PredicateSpec {
                row: 0,
                col: 0,
                tau: 0,
            })
        }),
        ("model declaration", |r| {
            r.mode.model_id = Some("private-value-12345".into())
        }),
        ("missing model", |r| r.model_identity = [0; 32]),
        ("missing calibration", |r| r.calibration_identity = [0; 32]),
    ];
    for (name, change) in changes {
        let mut bad = fixture();
        change(&mut bad);
        let result =
            std::panic::catch_unwind(|| ApprovedP1BlockContract::from_trusted_registration(bad));
        let error = result
            .unwrap_or_else(|_| panic!("unexpected panic in {name}"))
            .err()
            .unwrap_or_else(|| panic!("accepted {name}"));
        assert!(!error.to_string().contains("private-value-12345"));
    }
}

#[test]
fn valid_metadata_changes_still_require_new_independent_approval() {
    let approved = ApprovedP1BlockContract::from_trusted_registration(fixture()).unwrap();
    let changes: &[Mutation] = &[
        ("attention root", |r| r.attention_weights.root[0] ^= 1),
        ("ffn root", |r| r.ffn_weights.root[0] ^= 1),
        ("calibration ID", |r| r.calibration_identity[0] ^= 1),
        ("model ID", |r| {
            r.model_identity[0] ^= 1;
            r.mode.model_id = Some(hashline::silu::hex(&r.model_identity));
        }),
        ("layer", |r| {
            r.attention.layer = 1;
            r.ffn.l = 1;
        }),
        ("epsilon", |r| r.attention.anorm.ceps = 2),
        ("FFN table member", |r| {
            r.ffn_exponents.e_g = -2;
            r.ffn.shifts.0 = 8;
            let (t, d) = int16out_member(r.ffn.act, -2, -11).unwrap();
            r.ffn.table = t;
            r.ffn.table_digest = d;
        }),
    ];
    for (name, change) in changes {
        let mut candidate = fixture();
        change(&mut candidate);
        let new = ApprovedP1BlockContract::from_trusted_registration(candidate.clone())
            .unwrap_or_else(|_| panic!("invalid test mutation {name}"));
        assert_ne!(new.public_digest(), approved.public_digest(), "{name}");
        assert_eq!(
            approved.preflight_candidate(&candidate),
            Err(ContractError::UnapprovedMetadata),
            "{name}"
        );
    }
    // Registering the changed root above does not authenticate it; that would
    // be a NEW application authorization operation, not proof verification.
}

#[test]
fn registration_snapshot_cannot_mutate_approved_state_and_digest_binds_transcript() {
    let a = ApprovedP1BlockContract::from_trusted_registration(fixture()).unwrap();
    let before = a.public_digest();
    let mut snapshot = a.registration();
    snapshot.calibration_identity[2] ^= 1;
    assert_eq!(a.public_digest(), before);
    a.preflight_candidate(&fixture()).unwrap();
    let b = ApprovedP1BlockContract::from_trusted_registration(snapshot).unwrap();
    let mut ta = Transcript::new(b"A00 transcript test");
    let mut tb = Transcript::new(b"A00 transcript test");
    a.bind_public_statement(&mut ta);
    b.bind_public_statement(&mut tb);
    assert_ne!(ta.challenge_fp2(), tb.challenge_fp2());
}

#[test]
fn adjacent_boundary_preflight_checks_order_identity_and_scale_but_not_values() {
    let a = ApprovedP1BlockContract::from_trusted_registration(fixture()).unwrap();
    let mut next = fixture();
    next.attention.layer = 1;
    next.ffn.l = 1;
    let b = ApprovedP1BlockContract::from_trusted_registration(next.clone()).unwrap();
    a.preflight_next_boundary(&b).unwrap();
    assert!(a.preflight_next_boundary(&a).is_err());
    assert!(b.preflight_next_boundary(&a).is_err());
    next.calibration_identity[0] ^= 1;
    let different = ApprovedP1BlockContract::from_trusted_registration(next).unwrap();
    assert_eq!(
        a.preflight_next_boundary(&different),
        Err(ContractError::BoundaryMismatch(
            "approved model/calibration"
        ))
    );
    // Consistent metadata alone must not be mistaken for a residual equality proof.
}

#[test]
fn equivalent_integer_words_with_changed_boundary_scale_are_not_equal_values() {
    let a = ApprovedP1BlockContract::from_trusted_registration(fixture()).unwrap();
    let mut next = fixture();
    next.attention.layer = 1;
    next.ffn.l = 1;
    next.attention.e_r = 1;
    next.attention.sh_x1 = 1;
    let b = ApprovedP1BlockContract::from_trusted_registration(next).unwrap();
    assert_eq!(
        a.preflight_next_boundary(&b),
        Err(ContractError::BoundaryMismatch("residual scale/class"))
    );
}
