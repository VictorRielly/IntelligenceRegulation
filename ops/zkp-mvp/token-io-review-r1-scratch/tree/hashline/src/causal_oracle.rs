//! CPU-only fixed-calibration T32 block WITNESS oracle, not a proof.
//!
//! No exports, adaptive fitting, GPU dispatch, embeddings/head, token choice,
//! variable-length decode or KV cache. Returned tensors are SECRET local
//! witnesses: do not publish them or their digests as private proof artifacts.
//! Attention narrowing uses the current honest builder's [-127,127] subset,
//! deliberately excluding -128 and its interaction with the -127 mask sentinel.

use crate::attention::{AttnLayout, AttnShape, AttnWitness, Cls, NormConsts, Resid2};
use crate::export_v3::{derive_v3, requant_round, V3Dims, V3LayerExport, V3Witness};
use crate::field::Fp;
use crate::layer::LayoutV3;
use crate::merkle::{Digest, MerkleTree};
use crate::norm::{isqrt, rmsnorm_chain, DivMode, NormChain};
use crate::ntt::NttTables;
use crate::pcs::{hash_columns, Commitment};
use crate::private_block_contract::{ApprovedP1BlockContract, BlockRegistration};
use crate::tables_attn::{exp_member, rope_tables_generate};

const T: usize = 32;
const D: usize = 16;
const F: usize = 16;
const H: usize = 2;
const HD: usize = 8;
const KV: usize = 8;

/// Public, deterministic synthetic fixture for tiny CPU arithmetic/proof tests.
/// This is NOT model authorization: all weights, inputs and identities here
/// are deliberately public test data, independently fixed before any proof.
/// The immutable contract retains its P1 policy; using its arithmetic in a P0
/// test does not turn that test into a P1 proof.
pub fn public_synthetic_fixture() -> (ApprovedP1BlockContract, PublicBlockWeights, Vec<i16>) {
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
    // Non-symmetric signed off-diagonal entries expose orientation mistakes.
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
    let (aw, fw) = cpu_weight_commitments(&w).expect("public fixture weights");
    let approved = ApprovedP1BlockContract::from_trusted_public_weights(
        public_synthetic_registration(aw, fw), &w,
    ).expect("public fixture contract");
    let input = (0..T * D)
        .map(|i| ((i / D) % 5) as i16 - 2 + (i % 3) as i16 - 1)
        .collect();
    (approved, w, input)
}

/// Public fixed-fixture metadata only: no weight tensors, witness construction,
/// commitment generation or proving. Callers must independently authenticate
/// the supplied roots. This function does NOT approve a candidate proof.
pub fn public_synthetic_registration(aw: Commitment, fw: Commitment) -> BlockRegistration {
    use crate::attention::{AttnConsts, FullConsts};
    use crate::export_v3::V3Exps;
    use crate::layer::{LayerParams, StatementV3};
    use crate::private_block_contract::AttentionExponents;
    use crate::tables_attn::rope_digest;
    use crate::tables_v3::{int16out_member, Act16Fn};
    use crate::zk::ZkStatementMode;

    let (ct, sn) = rope_tables_generate(T, HD, 10000.0, 7);
    let norm = NormConsts {
        tn: 11,
        cn: 1024,
        ceps: 1,
        wrho: 29,
        n_limbs: 2,
    };
    let (table, table_digest) =
        int16out_member(Act16Fn::Silu, -3, -11).expect("public fixture table");
    let model_identity = *blake3::hash(b"B3 public synthetic signed weights v1").as_bytes();
    BlockRegistration {
        attention: AttnConsts {
            shape: AttnShape {
                t: T,
                d: D,
                f: F,
                heads: H,
                kv_heads: 1,
                head_dim: HD,
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
            exp_digest: exp_member(0, HD, 9).1,
            rope_digest: rope_digest(T, HD, 10000.0, 7, &ct, &sn),
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
            t_rows: T,
            d: D,
            f: F,
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
            model_id: Some(crate::silu::hex(&model_identity)),
            ..Default::default()
        },
        model_identity,
        calibration_identity: *blake3::hash(b"B3 public fixed calibration v1").as_bytes(),
        attention_weights: aw,
        ffn_weights: fw,
    }
}

/// Attention matrices are (output,input); FFN matrices are (input,output),
/// exactly as V3LayerExport's *_t fields. Gamma and weights are public in P1.
#[derive(Clone)]
pub struct PublicBlockWeights {
    pub wq: Vec<i8>,
    pub wk: Vec<i8>,
    pub wv: Vec<i8>,
    pub wo: Vec<i8>,
    pub gamma_a: Vec<i8>,
    pub gamma_m: Vec<i8>,
    pub wg_t: Vec<i8>,
    pub wu_t: Vec<i8>,
    pub wd_t: Vec<i8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OracleError {
    Shape,
    UnapprovedWeights,
    Range(&'static str),
    Relation(&'static str),
}
impl std::fmt::Display for OracleError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Shape => write!(f, "unsupported oracle tensor shape"),
            Self::UnapprovedWeights => write!(f, "oracle weights differ from independent approval"),
            Self::Range(site) => write!(f, "fixed oracle range refusal: {site}"),
            Self::Relation(site) => write!(f, "fixed oracle relation failure: {site}"),
        }
    }
}
impl std::error::Error for OracleError {}

/// Secret witness container; intentionally no Debug/serialization implementation.
pub struct OracleBlock {
    pub contract_digest: Digest,
    pub attention: AttnWitness,
    pub ffn: V3Witness,
    pub residual: Resid2,
}

pub struct FixedCausalOracle {
    registration: BlockRegistration,
    weights: PublicBlockWeights,
    digest: Digest,
}

impl FixedCausalOracle {
    /// Check actual public weights against the independently approved roots.
    /// The approved contract must NOT have been copied from a candidate proof.
    pub fn new(
        contract: &ApprovedP1BlockContract,
        weights: PublicBlockWeights,
    ) -> Result<Self, OracleError> {
        let (aw, fw) = cpu_weight_commitments(&weights)?;
        let registration = contract.registration();
        if !same_root(&aw, &registration.attention_weights)
            || !same_root(&fw, &registration.ffn_weights)
        {
            return Err(OracleError::UnapprovedWeights);
        }
        Ok(Self {
            registration,
            weights,
            digest: contract.public_digest(),
        })
    }

    /// Compute one fixed T32 integer block. A refusal never fits a new shift,
    /// clamps a returned witness or prints supplied values. This proves nothing.
    pub fn build(&self, input: &[i16]) -> Result<OracleBlock, OracleError> {
        if input.len() != T * D {
            return Err(OracleError::Shape);
        }
        let (r, w) = (&self.registration, &self.weights);
        let c = &r.attention;
        let x_in: Vec<i64> = input.iter().map(|v| i64::from(*v)).collect();
        let g_a = widen(&w.gamma_a);
        let g_m = widen(&w.gamma_m);
        let na = checked_norm(&x_in, &g_a, &c.anorm)?;
        let qacc = matmul_out_in(&na.y, &w.wq, D, D);
        let kacc = matmul_out_in(&na.y, &w.wk, D, KV);
        let vacc = matmul_out_in(&na.y, &w.wv, D, KV);
        let (q8, rq) = quantize(&qacc, c.sh_q, -127, 127, "Q")?;
        let (k8, rk) = quantize(&kacc, c.sh_k, -127, 127, "K")?;
        let (v8, rv) = quantize(&vacc, c.sh_v, -127, 127, "V")?;
        let (ctab, stab) = rope_tables_generate(T, HD, c.rope_base, c.f_ro);
        let qracc = rotate(&q8, H, &ctab, &stab);
        let kracc = rotate(&k8, 1, &ctab, &stab);
        let (qr8, rqr) = quantize(&qracc, c.sh_qr, -127, 127, "QR")?;
        let (kr8, rkr) = quantize(&kracc, c.sh_kr, -127, 127, "KR")?;
        let mut sacc = vec![0i64; H * T * T];
        for h in 0..H {
            for t in 0..T {
                for j in 0..T {
                    sacc[(h * T + t) * T + j] = (0..HD)
                        .map(|i| qr8[t * D + h * HD + i] * kr8[j * KV + i])
                        .sum();
                }
            }
        }
        let (s8, rs) = quantize(&sacc, c.sh_s, -127, 127, "score")?;
        let (exp_tab, _) = exp_member(c.e_s_raw, HD, c.f_e);
        let mut dmat = vec![0; H * T * T];
        let mut zsel = vec![0; H * T * T];
        let mut e_t = vec![0; H * T * T];
        let mut p = vec![0; H * T * T];
        let mut rho_s = vec![0; H * T * T];
        let mut sig_s = vec![0; H * T * T];
        let mut m_row = vec![0; H * T];
        let mut sum = vec![0; H * T];
        let mut oacc = vec![0; H * T * HD];
        for h in 0..H {
            for t in 0..T {
                let base = (h * T + t) * T;
                // Matches the existing masked-array max and first-attainer rule.
                let mut best = i64::MIN;
                let mut arg = 0;
                for j in 0..T {
                    let score = if j <= t { s8[base + j] } else { -127 };
                    if score > best {
                        best = score;
                        arg = j;
                    }
                }
                if arg > t {
                    return Err(OracleError::Relation("causal maximum attainment"));
                }
                m_row[h * T + t] = best;
                zsel[base + arg] = 1;
                let mut total = 0;
                for j in 0..T {
                    let score = if j <= t { s8[base + j] } else { -127 };
                    let delta = best - score;
                    if !(0..256).contains(&delta) {
                        return Err(OracleError::Range("exp difference"));
                    }
                    dmat[base + j] = delta;
                    e_t[base + j] = exp_tab[delta as usize];
                    if j <= t {
                        total += e_t[base + j];
                    }
                }
                if !(512..=16384).contains(&total) {
                    return Err(OracleError::Relation("softmax denominator"));
                }
                sum[h * T + t] = total;
                for j in 0..T {
                    if j <= t {
                        let numerator = e_t[base + j] << c.f_p;
                        p[base + j] = numerator / total;
                        rho_s[base + j] = numerator % total;
                        // Existing AttnWitness stores zero sigma off support;
                        // attention::pack reconstructs Sum-1-rho on ALL positions.
                        sig_s[base + j] = total - 1 - rho_s[base + j];
                    }
                    let sigma_fact = total - 1 - rho_s[base + j];
                    if !(0..1i64 << c.wrho_s).contains(&sigma_fact)
                        || !(0..=512).contains(&p[base + j])
                    {
                        return Err(OracleError::Range("softmax quotient/remainder"));
                    }
                }
                for i in 0..HD {
                    oacc[(h * T + t) * HD + i] =
                        (0..=t).map(|j| p[base + j] * v8[j * KV + i]).sum();
                }
            }
        }
        let (oy, or) = quantize(&oacc, c.sh_o, -127, 127, "O")?;
        let mut o8 = vec![0; T * D];
        let mut r_o = vec![0; T * D];
        for h in 0..H {
            for t in 0..T {
                for i in 0..HD {
                    o8[t * D + h * HD + i] = oy[(h * T + t) * HD + i];
                    r_o[t * D + h * HD + i] = or[(h * T + t) * HD + i];
                }
            }
        }
        let aoacc = matmul_out_in(&o8, &w.wo, D, D);
        let (ao8, r_ao) = quantize(&aoacc, c.sh_ao, -32768, 32767, "AO")?;
        let xw1: Vec<i64> = x_in
            .iter()
            .zip(&ao8)
            .map(|(x, a)| (x << c.sh_x1) + (a << c.sh_a1))
            .collect();
        let (xres1, rr1) = quantize(&xw1, c.sh_r1, -32768, 32767, "residual 1")?;
        let nm = checked_norm(&xres1, &g_m, &c.mnorm)?;
        // Scalar precheck precedes derive_v3's internal clamping/assertions.
        let expected = checked_ffn(r, w, &nm.y)?;
        let ex = V3LayerExport {
            l: c.layer,
            dims: V3Dims {
                t: T,
                d: D,
                f: F,
                layers: c.layer + 1,
            },
            x: nm.y.iter().map(|v| *v as i8).collect(),
            wg_t: w.wg_t.clone(),
            wu_t: w.wu_t.clone(),
            wd_t: w.wd_t.clone(),
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
        let ffn = derive_v3(&ex, T);
        let actual = [
            &ffn.g8, &ffn.rg, &ffn.a16, &ffn.u16v, &ffn.ru, &ffn.h16, &ffn.rh, &ffn.z16, &ffn.rd,
        ];
        if !ffn.range_ok
            || actual
                .iter()
                .zip(&expected)
                .any(|(a, b)| a.iter().map(|x| i64::from(*x)).ne(b.iter().copied()))
        {
            return Err(OracleError::Relation(
                "FFN scalar/source oracle disagreement",
            ));
        }
        let z16 = expected[7].clone();
        let xw2: Vec<i64> = xres1
            .iter()
            .zip(&z16)
            .map(|(x, z)| (x << r.residual.sh_x2) + (z << r.residual.sh_z2))
            .collect();
        let (xres2, rr2) = quantize(&xw2, r.residual.sh_r2, -32768, 32767, "residual 2")?;
        let residual = Resid2 {
            c: r.residual.clone(),
            z16,
            xres2,
            rr2,
        };
        let attention = AttnWitness {
            c: c.clone(),
            x_in,
            wq: widen(&w.wq),
            wk: widen(&w.wk),
            wv: widen(&w.wv),
            wo: widen(&w.wo),
            g_a,
            g_m,
            na,
            nm,
            qacc,
            q8,
            rq,
            kacc,
            k8,
            rk,
            vacc,
            v8,
            rv,
            qracc,
            qr8,
            rqr,
            kracc,
            kr8,
            rkr,
            sacc,
            s8,
            rs,
            dmat,
            zsel,
            e_t,
            p,
            rho_s,
            sig_s,
            m_row,
            sum,
            oacc,
            o8,
            r_o,
            aoacc,
            ao8,
            r_ao,
            xw1,
            xres1,
            rr1,
            exp_tab,
            ctab,
            stab,
        };
        Ok(OracleBlock {
            contract_digest: self.digest,
            attention,
            ffn,
            residual,
        })
    }
}

fn widen(v: &[i8]) -> Vec<i64> {
    v.iter().map(|x| i64::from(*x)).collect()
}
fn same_root(a: &Commitment, b: &Commitment) -> bool {
    a.root == b.root && a.rows == b.rows && a.log_cols == b.log_cols
}
fn weight_shapes(w: &PublicBlockWeights) -> Result<(), OracleError> {
    if [
        w.wq.len(),
        w.wo.len(),
        w.wg_t.len(),
        w.wu_t.len(),
        w.wd_t.len(),
    ] != [256; 5]
        || [w.wk.len(), w.wv.len()] != [128; 2]
        || [w.gamma_a.len(), w.gamma_m.len()] != [16; 2]
    {
        Err(OracleError::Shape)
    } else {
        Ok(())
    }
}

/// Compute expected roots from public tiny matrices using CPU-only NTT/hash/
/// Merkle routines. This is computation, NOT approval: the application must
/// independently authorize these weights before registering the returned roots.
pub fn cpu_weight_commitments(
    w: &PublicBlockWeights,
) -> Result<(Commitment, Commitment), OracleError> {
    weight_shapes(w)?;
    let shape = AttnShape {
        t: T,
        d: D,
        f: F,
        heads: H,
        kv_heads: 1,
        head_dim: HD,
    };
    let al = AttnLayout::new(
        &shape,
        Cls::Int16,
        Cls::Int16,
        Cls::Int16,
        Cls::Int16,
        2,
        2,
        8,
    );
    let mut aw = vec![Fp::ZERO; al.w_len];
    for i in 0..D {
        for j in 0..D {
            aw[al.wq + i * D + j] = Fp::from_i64(i64::from(w.wq[j * D + i]));
            aw[al.wo + i * D + j] = Fp::from_i64(i64::from(w.wo[j * D + i]));
        }
    }
    for i in 0..D {
        for j in 0..KV {
            aw[al.wk + i * KV + j] = Fp::from_i64(i64::from(w.wk[j * D + i]));
            aw[al.wv + i * KV + j] = Fp::from_i64(i64::from(w.wv[j * D + i]));
        }
    }
    for i in 0..D {
        aw[al.gpack + i] = Fp::from_i64(i64::from(w.gamma_a[i]));
        aw[al.gpack + D + i] = Fp::from_i64(i64::from(w.gamma_m[i]));
    }
    let fl = LayoutV3::new(T, D, F);
    let mut fw = vec![Fp::ZERO; fl.w_len];
    for i in 0..D {
        for j in 0..F {
            fw[fl.wg[0] + i * F + j] = Fp::from_i64(i64::from(w.wg_t[i * F + j]));
            fw[fl.wu[0] + i * F + j] = Fp::from_i64(i64::from(w.wu_t[i * F + j]));
            fw[fl.wd[0] + j * D + i] = Fp::from_i64(i64::from(w.wd_t[j * D + i]));
        }
    }
    Ok((cpu_commit(&aw), cpu_commit(&fw)))
}

fn cpu_commit(data: &[Fp]) -> Commitment {
    let ntt = NttTables::new(11);
    let mut encoded = Vec::with_capacity(data.len() * 8);
    for row in data.chunks_exact(256) {
        let mut coefficients = row.to_vec();
        ntt.inverse(&mut coefficients);
        coefficients.resize(2048, Fp::ZERO);
        ntt.forward(&mut coefficients);
        encoded.extend(coefficients);
    }
    let rows = data.len() / 256;
    Commitment {
        root: MerkleTree::build(hash_columns(&encoded, rows, 2048)).root(),
        rows,
        log_cols: 8,
    }
}

fn quantize(
    acc: &[i64],
    shift: i32,
    lo: i64,
    hi: i64,
    site: &'static str,
) -> Result<(Vec<i64>, Vec<i64>), OracleError> {
    let (y, r) = requant_round(acc, shift);
    if y.iter().any(|v| !(lo..=hi).contains(v)) {
        return Err(OracleError::Range(site));
    }
    Ok((y, r))
}

fn checked_norm(x: &[i64], gamma: &[i64], n: &NormConsts) -> Result<NormChain, OracleError> {
    for row in x.chunks_exact(D) {
        let ss: i64 = row.iter().map(|v| v * v).sum::<i64>() + n.ceps;
        let d = isqrt(ss);
        let denominator = (d << n.tn) * 2;
        if denominator <= 0 {
            return Err(OracleError::Range("norm denominator"));
        }
        for (x, g) in row.iter().zip(gamma) {
            let numerator = 2 * x * g * n.cn + (d << n.tn);
            let q = numerator.div_euclid(denominator);
            let rho = numerator.rem_euclid(denominator);
            let sigma = denominator - 1 - rho;
            if !(-127..=127).contains(&q) || rho >= 1i64 << n.wrho || sigma >= 1i64 << n.wrho {
                return Err(OracleError::Range("norm quotient/remainder"));
            }
        }
    }
    Ok(rmsnorm_chain(
        x,
        gamma,
        D,
        n.ceps,
        n.tn,
        n.cn,
        DivMode::Round,
    ))
}

fn matmul_out_in(x: &[i64], w: &[i8], inner: usize, outer: usize) -> Vec<i64> {
    (0..T * outer)
        .map(|k| {
            let (t, j) = (k / outer, k % outer);
            (0..inner)
                .map(|i| x[t * inner + i] * i64::from(w[j * inner + i]))
                .sum()
        })
        .collect()
}
fn matmul_in_out(x: &[i64], w: &[i8]) -> Vec<i64> {
    (0..T * D)
        .map(|k| {
            let (t, j) = (k / D, k % D);
            (0..D).map(|i| x[t * D + i] * i64::from(w[i * D + j])).sum()
        })
        .collect()
}
fn rotate(x: &[i64], heads: usize, c: &[i64], s: &[i64]) -> Vec<i64> {
    let mut out = vec![0; x.len()];
    let width = heads * HD;
    for t in 0..T {
        for h in 0..heads {
            for i in 0..HD / 2 {
                let base = t * width + h * HD;
                let at = t * (HD / 2) + i;
                out[base + i] = c[at] * x[base + i] - s[at] * x[base + HD / 2 + i];
                out[base + HD / 2 + i] = s[at] * x[base + i] + c[at] * x[base + HD / 2 + i];
            }
        }
    }
    out
}
fn checked_ffn(
    r: &BlockRegistration,
    w: &PublicBlockWeights,
    x: &[i64],
) -> Result<Vec<Vec<i64>>, OracleError> {
    let shifts = r.ffn.shifts;
    let (g, rg) = quantize(&matmul_in_out(x, &w.wg_t), shifts.0, -128, 127, "FFN gate")?;
    let (u, ru) = quantize(
        &matmul_in_out(x, &w.wu_t),
        shifts.1,
        -32768,
        32767,
        "FFN up",
    )?;
    let a: Vec<i64> = g
        .iter()
        .map(|v| i64::from(r.ffn.table[(v + 128) as usize]))
        .collect();
    let hh: Vec<i64> = a.iter().zip(&u).map(|(a, u)| a * u).collect();
    let (h, rh) = quantize(&hh, shifts.2, -32768, 32767, "FFN product")?;
    let (z, rz) = quantize(
        &matmul_in_out(&h, &w.wd_t),
        shifts.3,
        -32768,
        32767,
        "FFN down",
    )?;
    Ok(vec![g, rg, a, u, ru, h, rh, z, rz])
}
