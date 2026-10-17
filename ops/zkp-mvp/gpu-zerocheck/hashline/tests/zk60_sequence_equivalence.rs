//! Fixed-T32 witness causality tests, not token-generation or proof tests.
use hashline::attention::{
    attn_layout_of, pack, AttnConsts, AttnShape, Cls, FullConsts, NormConsts,
};
use hashline::causal_oracle::{
    cpu_weight_commitments, FixedCausalOracle, OracleError, PublicBlockWeights,
};
use hashline::export_v3::V3Exps;
use hashline::layer::{LayerParams, StatementV3};
use hashline::private_block_contract::{
    ApprovedP1BlockContract, AttentionExponents, BlockRegistration,
};
use hashline::tables_attn::{exp_member, rope_digest, rope_tables_generate};
use hashline::tables_v3::{int16out_member, Act16Fn};
use hashline::zk::ZkStatementMode;

fn weights() -> PublicBlockWeights {
    let mut w = PublicBlockWeights {
        wq: vec![0; 256],
        wk: vec![0; 128],
        wv: vec![0; 128],
        wo: vec![0; 256],
        gamma_a: vec![64; 16],
        gamma_m: vec![64; 16],
        wg_t: vec![1; 256],
        wu_t: vec![1; 256],
        wd_t: vec![0; 256],
    };
    for i in 0..16 {
        w.wq[i * 16 + i] = 64;
        w.wo[i * 16 + i] = 64;
        w.wd_t[i * 16 + i] = 64;
    }
    for i in 0..8 {
        w.wk[i * 16 + i] = 64;
        w.wv[i * 16 + i] = 64;
    }
    w
}

fn registration(w: &PublicBlockWeights) -> BlockRegistration {
    let (aw, fw) = cpu_weight_commitments(w).unwrap();
    let (ct, sn) = rope_tables_generate(32, 8, 10000.0, 7);
    let norm = NormConsts {
        tn: 11,
        cn: 1024,
        ceps: 1,
        wrho: 29,
        n_limbs: 2,
    };
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
    let model_identity = *blake3::hash(b"E1 approved toy public weights").as_bytes();
    BlockRegistration {
        attention: AttnConsts {
            shape: AttnShape {
                t: 32,
                d: 16,
                f: 16,
                heads: 2,
                kv_heads: 1,
                head_dim: 8,
            },
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
        },
        residual: FullConsts {
            sh_x2: 0,
            sh_z2: 0,
            sh_r2: 0,
            r2_cls: Cls::Int16,
            e_r2: 0,
            e_z16: 0,
        },
        ffn: StatementV3 {
            l: 0,
            t_rows: 32,
            d: 16,
            f: 16,
            shifts: (7, 0, 14, 6),
            act: Act16Fn::Silu,
            table,
            table_digest,
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
        params: LayerParams {
            log_cols: 8,
            inv_rate: 8,
            num_col_checks: 256,
        },
        mode: ZkStatementMode {
            model_id: Some(hashline::silu::hex(&model_identity)),
            ..Default::default()
        },
        model_identity,
        calibration_identity: *blake3::hash(b"E1 fixed calibration").as_bytes(),
        attention_weights: aw,
        ffn_weights: fw,
    }
}
fn input() -> Vec<i16> {
    (0..512)
        .map(|i| ((i / 16) % 5) as i16 - 2 + (i % 3) as i16 - 1)
        .collect()
}
fn oracle() -> FixedCausalOracle {
    let w = weights();
    let approved = ApprovedP1BlockContract::from_trusted_registration(registration(&w)).unwrap();
    FixedCausalOracle::new(&approved, w).unwrap()
}

#[test]
fn nontrivial_fixed_block_satisfies_integer_relations_and_existing_pack_layout() {
    let b = oracle().build(&input()).unwrap();
    let a = &b.attention;
    assert!(a.s8.iter().any(|v| *v != 0));
    assert!(a.ao8.iter().any(|v| *v != 0));
    assert!(b.ffn.z16.iter().any(|v| *v != 0));
    assert_ne!(b.residual.xres2, a.x_in);
    for t in 0..32 {
        for i in 0..16 {
            let k = t * 16 + i;
            assert_eq!(a.qacc[k], a.na.y[k] * 64);
            assert_eq!(a.qacc[k], 128 * a.q8[k] + a.rq[k]);
            assert_eq!(a.aoacc[k], a.o8[k] * 64);
            assert_eq!(a.aoacc[k], 128 * a.ao8[k] + a.r_ao[k]);
            assert_eq!(a.xres1[k], a.x_in[k] + a.ao8[k]);
            assert_eq!(a.rr1[k], 0);
            assert_eq!(b.residual.xres2[k], a.xres1[k] + i64::from(b.ffn.z16[k]));
            assert_eq!(b.residual.rr2[k], 0);
        }
    }
    for h in 0..2 {
        for t in 0..32 {
            let base = (h * 32 + t) * 32;
            let mut sum = 0;
            let mut selectors = 0;
            for j in 0..32 {
                let k = base + j;
                let sm = if j <= t { a.s8[k] } else { -127 };
                let direct: i64 = (0..8)
                    .map(|i| a.qr8[t * 16 + h * 8 + i] * a.kr8[j * 8 + i])
                    .sum();
                assert_eq!(a.sacc[k], direct);
                assert_eq!(direct, 64 * a.s8[k] + a.rs[k]);
                assert_eq!(a.dmat[k], a.m_row[h * 32 + t] - sm);
                assert_eq!(a.e_t[k], a.exp_tab[a.dmat[k] as usize]);
                assert!([0, 1].contains(&a.zsel[k]));
                selectors += a.zsel[k];
                if a.zsel[k] == 1 {
                    assert_eq!(a.dmat[k], 0);
                    assert!(j <= t);
                }
                if j <= t {
                    sum += a.e_t[k];
                    assert_eq!(a.p[k] * a.sum[h * 32 + t] + a.rho_s[k], 512 * a.e_t[k]);
                    assert_eq!(a.sig_s[k], a.sum[h * 32 + t] - 1 - a.rho_s[k]);
                } else {
                    assert_eq!((a.p[k], a.rho_s[k], a.sig_s[k]), (0, 0, 0));
                }
            }
            assert_eq!(selectors, 1);
            assert_eq!(sum, a.sum[h * 32 + t]);
            for i in 0..8 {
                let direct: i64 = (0..=t).map(|j| a.p[base + j] * a.v8[j * 8 + i]).sum();
                assert_eq!(a.oacc[(h * 32 + t) * 8 + i], direct);
                assert_eq!(
                    direct,
                    512 * a.o8[t * 16 + h * 8 + i] + a.r_o[t * 16 + h * 8 + i]
                );
            }
        }
    }
    let lay = attn_layout_of(&a.c, &b.residual.c, 8);
    let packed = pack(a, &b.residual, &lay);
    assert_eq!(packed.a.len(), lay.a_len);
    assert_eq!(packed.w.len(), lay.w_len);
    for i in 0..16 {
        for j in 0..16 {
            assert_eq!(
                packed.w[lay.wq + i * 16 + j],
                hashline::field::Fp::from_i64(a.wq[j * 16 + i])
            );
            assert_eq!(
                packed.w[lay.wo + i * 16 + j],
                hashline::field::Fp::from_i64(a.wo[j * 16 + i])
            );
        }
    }
    // pack's range checks pass; no prover or verifier was invoked.
}

#[test]
fn future_suffix_mutation_preserves_prefix_at_the_same_fixed_t32() {
    let o = oracle();
    let x = input();
    let a = o.build(&x).unwrap();
    for cut in [1, 7, 16, 31] {
        let mut y = x.clone();
        for v in &mut y[cut * 16..] {
            *v = -*v + 1;
        }
        let b = o.build(&y).unwrap();
        let (aa, bb) = (&a.attention, &b.attention);
        assert_eq!(a.contract_digest, b.contract_digest);
        for (u, v) in [
            (&aa.x_in, &bb.x_in),
            (&aa.na.y, &bb.na.y),
            (&aa.q8, &bb.q8),
            (&aa.qr8, &bb.qr8),
            (&aa.o8, &bb.o8),
            (&aa.ao8, &bb.ao8),
            (&aa.xres1, &bb.xres1),
            (&aa.nm.y, &bb.nm.y),
            (&a.residual.xres2, &b.residual.xres2),
        ] {
            assert_eq!(&u[..cut * 16], &v[..cut * 16]);
        }
        for (u, v) in [(&aa.k8, &bb.k8), (&aa.kr8, &bb.kr8), (&aa.v8, &bb.v8)] {
            assert_eq!(&u[..cut * 8], &v[..cut * 8]);
        }
        for (u, v) in [
            (&aa.na.dd, &bb.na.dd),
            (&aa.na.a1, &bb.na.a1),
            (&aa.nm.dd, &bb.nm.dd),
        ] {
            assert_eq!(&u[..cut], &v[..cut]);
        }
        for (u, v) in [
            (&a.ffn.g8, &b.ffn.g8),
            (&a.ffn.a16, &b.ffn.a16),
            (&a.ffn.u16v, &b.ffn.u16v),
            (&a.ffn.h16, &b.ffn.h16),
            (&a.ffn.z16, &b.ffn.z16),
        ] {
            assert_eq!(&u[..cut * 16], &v[..cut * 16]);
        }
        for h in 0..2 {
            for t in 0..cut {
                let base = (h * 32 + t) * 32;
                // Raw future columns are deliberately excluded; their K values
                // change. The masked softmax witness and outputs must not change.
                assert_eq!(&aa.s8[base..base + cut], &bb.s8[base..base + cut]);
                for (u, v) in [
                    (&aa.dmat, &bb.dmat),
                    (&aa.e_t, &bb.e_t),
                    (&aa.zsel, &bb.zsel),
                    (&aa.p, &bb.p),
                    (&aa.rho_s, &bb.rho_s),
                    (&aa.sig_s, &bb.sig_s),
                ] {
                    assert_eq!(&u[base..base + 32], &v[base..base + 32]);
                }
                assert_eq!(aa.sum[h * 32 + t], bb.sum[h * 32 + t]);
                assert_eq!(aa.m_row[h * 32 + t], bb.m_row[h * 32 + t]);
            }
        }
        assert_ne!(aa.k8, bb.k8);
        assert_ne!(a.residual.xres2, b.residual.xres2);
    }
}

#[test]
fn root_shape_and_input_errors_are_static_and_do_not_autofit() {
    let w = weights();
    let reg = registration(&w);
    let approved = ApprovedP1BlockContract::from_trusted_registration(reg).unwrap();
    let mut changed = w.clone();
    changed.wq[0] += 1;
    assert!(matches!(
        FixedCausalOracle::new(&approved, changed),
        Err(OracleError::UnapprovedWeights)
    ));
    let mut short = w.clone();
    short.wk.pop();
    assert!(matches!(
        cpu_weight_commitments(&short),
        Err(OracleError::Shape)
    ));
    let o = FixedCausalOracle::new(&approved, w).unwrap();
    assert!(matches!(o.build(&[1; 16]), Err(OracleError::Shape)));
    assert!(matches!(
        o.build(&vec![32767; 512]),
        Err(OracleError::Range("residual 1"))
    ));
    let before = approved.public_digest();
    o.build(&input()).unwrap();
    assert_eq!(approved.public_digest(), before);
}

#[test]
fn hostile_norm_is_refused_before_the_source_assertion() {
    let w = weights();
    let mut reg = registration(&w);
    reg.attention_exponents.e_gamma_a = 5;
    reg.attention.anorm = NormConsts {
        tn: 0,
        cn: 1024,
        ceps: 1,
        wrho: 18,
        n_limbs: 2,
    };
    let approved = ApprovedP1BlockContract::from_trusted_registration(reg).unwrap();
    let o = FixedCausalOracle::new(&approved, w).unwrap();
    let error = o.build(&vec![1; 512]).err().unwrap();
    assert_eq!(error, OracleError::Range("norm quotient/remainder"));
    assert!(!error.to_string().contains("16384"));
}

#[test]
fn hostile_ffn_is_refused_before_derive_clamping() {
    let mut w = weights();
    w.gamma_a = vec![127; 16];
    w.gamma_m = vec![127; 16];
    w.wg_t = vec![127; 256];
    let approved = ApprovedP1BlockContract::from_trusted_registration(registration(&w)).unwrap();
    let o = FixedCausalOracle::new(&approved, w).unwrap();
    assert!(matches!(
        o.build(&vec![1; 512]),
        Err(OracleError::Range("FFN gate"))
    ));
}

#[test]
fn causal_maximum_ties_select_an_on_support_first_position() {
    let mut w = weights();
    w.wq.fill(0);
    w.wk.fill(0);
    let approved = ApprovedP1BlockContract::from_trusted_registration(registration(&w)).unwrap();
    let a = FixedCausalOracle::new(&approved, w)
        .unwrap()
        .build(&input())
        .unwrap()
        .attention;
    for h in 0..2 {
        for t in 0..32 {
            let base = (h * 32 + t) * 32;
            assert_eq!(a.zsel[base], 1);
            assert_eq!(a.m_row[h * 32 + t], 0);
            assert_eq!(a.sum[h * 32 + t], 512 * (t + 1) as i64);
            for j in 0..=t {
                assert_eq!(a.p[base + j], 512 / (t + 1) as i64);
            }
        }
    }
}

#[test]
fn asymmetric_signed_weights_pin_matmul_and_commitment_orientations() {
    use hashline::field::Fp;
    use hashline::layer::LayoutV3;
    use hashline::merkle::MerkleTree;
    use hashline::ntt::NttTables;

    // Local scalar rounding, not export_v3::requant_round. Current fixture
    // shifts are nonnegative; Euclidean division gives signed floor semantics.
    fn rq(acc: i128, shift: i32) -> (i128, i128) {
        let scale = 1i128 << shift;
        let q = if shift == 0 {
            acc
        } else {
            (acc + scale / 2).div_euclid(scale)
        };
        (q, acc - q * scale)
    }
    fn cpu_root(values: &[Fp]) -> [u8; 32] {
        let ntt = NttTables::new(11);
        let mut encoded = Vec::new();
        for row in values.chunks_exact(256) {
            let mut coefficients = row.to_vec();
            ntt.inverse(&mut coefficients);
            coefficients.resize(2048, Fp::ZERO);
            ntt.forward(&mut coefficients);
            encoded.extend(coefficients);
        }
        MerkleTree::build(hashline::pcs::hash_columns(
            &encoded,
            values.len() / 256,
            2048,
        ))
        .root()
    }

    let mut w = weights();
    w.wq[3] = 7;
    w.wq[7 * 16 + 2] = -5;
    w.wk[5 * 16 + 14] = 9;
    w.wv[3 * 16 + 11] = -6;
    w.wo[2 * 16 + 9] = 11;
    w.wo[11 * 16 + 4] = -7;
    w.wg_t[16 + 13] = -4;
    w.wg_t[13 * 16 + 1] = 2;
    w.wu_t[4 * 16 + 15] = -3;
    w.wu_t[15 * 16 + 4] = 5;
    w.wd_t[2 * 16 + 11] = 19;
    w.wd_t[11 * 16 + 2] = -13;
    let reg = registration(&w);
    let expected_aw = reg.attention_weights.root;
    let expected_fw = reg.ffn_weights.root;
    let approved = ApprovedP1BlockContract::from_trusted_registration(reg).unwrap();
    let block = FixedCausalOracle::new(&approved, w.clone())
        .unwrap()
        .build(&input())
        .unwrap();
    let a = &block.attention;
    let f = &block.ffn;
    let mut catches_q_transpose = false;
    let mut catches_ffn_transpose = false;
    for t in 0..32 {
        for j in 0..16 {
            let k = t * 16 + j;
            // Attention checkpoint orientation: output row first.
            let q: i128 = (0..16)
                .map(|i| i128::from(a.na.y[t * 16 + i]) * i128::from(w.wq[j * 16 + i]))
                .sum();
            let wrong_q: i128 = (0..16)
                .map(|i| i128::from(a.na.y[t * 16 + i]) * i128::from(w.wq[i * 16 + j]))
                .sum();
            catches_q_transpose |= q != wrong_q;
            assert_eq!(i128::from(a.qacc[k]), q);
            assert_eq!((i128::from(a.q8[k]), i128::from(a.rq[k])), rq(q, 7));
            let o: i128 = (0..16)
                .map(|i| i128::from(a.o8[t * 16 + i]) * i128::from(w.wo[j * 16 + i]))
                .sum();
            assert_eq!(i128::from(a.aoacc[k]), o);
            assert_eq!((i128::from(a.ao8[k]), i128::from(a.r_ao[k])), rq(o, 7));
            // FFN export orientation: input row first. Remainder comparisons
            // detect orientation differences even when rounding hides them.
            let g: i128 = (0..16)
                .map(|i| i128::from(a.nm.y[t * 16 + i]) * i128::from(w.wg_t[i * 16 + j]))
                .sum();
            let wrong_g: i128 = (0..16)
                .map(|i| i128::from(a.nm.y[t * 16 + i]) * i128::from(w.wg_t[j * 16 + i]))
                .sum();
            catches_ffn_transpose |= g != wrong_g;
            assert_eq!((i128::from(f.g8[k]), i128::from(f.rg[k])), rq(g, 7));
            let u: i128 = (0..16)
                .map(|i| i128::from(a.nm.y[t * 16 + i]) * i128::from(w.wu_t[i * 16 + j]))
                .sum();
            assert_eq!((i128::from(f.u16v[k]), i128::from(f.ru[k])), rq(u, 0));
            assert_eq!(f.a16[k], i32::from(f.table[(f.g8[k] + 128) as usize]));
            assert_eq!(
                (i128::from(f.h16[k]), i128::from(f.rh[k])),
                rq(i128::from(f.a16[k]) * u, 14)
            );
            let z: i128 = (0..16)
                .map(|i| i128::from(f.h16[t * 16 + i]) * i128::from(w.wd_t[i * 16 + j]))
                .sum();
            assert_eq!((i128::from(f.z16[k]), i128::from(f.rd[k])), rq(z, 6));
        }
        for j in 0..8 {
            let k = t * 8 + j;
            let key: i128 = (0..16)
                .map(|i| i128::from(a.na.y[t * 16 + i]) * i128::from(w.wk[j * 16 + i]))
                .sum();
            let value: i128 = (0..16)
                .map(|i| i128::from(a.na.y[t * 16 + i]) * i128::from(w.wv[j * 16 + i]))
                .sum();
            assert_eq!(i128::from(a.kacc[k]), key);
            assert_eq!(i128::from(a.vacc[k]), value);
            assert_eq!((i128::from(a.k8[k]), i128::from(a.rk[k])), rq(key, 7));
            assert_eq!((i128::from(a.v8[k]), i128::from(a.rv[k])), rq(value, 7));
        }
    }
    assert!(
        catches_q_transpose && catches_ffn_transpose,
        "fixture must distinguish transposed square matrices"
    );
    let lay = attn_layout_of(&a.c, &block.residual.c, 8);
    let packed = pack(a, &block.residual, &lay);
    assert_eq!(cpu_root(&packed.w), expected_aw);
    for i in 0..16 {
        for j in 0..8 {
            assert_eq!(
                packed.w[lay.wk + i * 8 + j],
                Fp::from_i64(i64::from(w.wk[j * 16 + i]))
            );
            assert_eq!(
                packed.w[lay.wv + i * 8 + j],
                Fp::from_i64(i64::from(w.wv[j * 16 + i]))
            );
        }
    }
    let fl = LayoutV3::new(32, 16, 16);
    assert_eq!((fl.wg[0], fl.wu[0], fl.wd[0], fl.w_len), (0, 256, 512, 768));
    // One block per matrix: the actual LayoutV3 ranges contain the supplied
    // input/output-major arrays directly, without an extra square transpose.
    let fw: Vec<Fp> = w
        .wg_t
        .iter()
        .chain(&w.wu_t)
        .chain(&w.wd_t)
        .map(|v| Fp::from_i64(i64::from(*v)))
        .collect();
    assert_eq!(cpu_root(&fw), expected_fw);
    assert_eq!(f.wg_t, w.wg_t);
    assert_eq!(f.wu_t, w.wu_t);
    assert_eq!(f.wd_t, w.wd_t);
}
