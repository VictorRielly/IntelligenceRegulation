//! FA9 — arithmetic and registrar obligations of the fixed T32/d16/f16 block,
//! packaged as CPU-light adversarial tests (independent reviewer, Claude Fable).
//!
//! Every proof here is the tiny public P0 fixture (T=32, d=f=16, log_cols 8,
//! inverse rate 8, 256 column checks): a correctness fixture, not a security
//! level. No GPU, no export, no private block, no throughput claim.
//!
//! Convention (from zk60_identity_gap.rs): a PASSING `known_*_gap_*` test
//! REPRODUCES a missing constraint; its assertion documents the false
//! acceptance and must be flipped when the fix lands. Setting the named
//! environment flag (FA9_R09_FIX / FA9_R32_FIX) makes the same test assert the
//! refusal instead, so a locally applied patch is verified by identical code.
//!
//! Tamper mode is a process-global flag: every test takes one lock so the
//! `known_*` legs never run beside an honest control.
#![cfg(not(feature = "gpu-cuda"))]
use hashline::attention as at;
use hashline::attention::{AttnConsts, AttnProof, AttnWitness, FullConsts, NormConsts, Resid2};
use hashline::causal_oracle::{
    public_synthetic_fixture, FixedCausalOracle, OracleBlock, PublicBlockWeights,
};
use hashline::export_v3::{derive_v3, requant_round, V3Dims, V3LayerExport};
use hashline::field::{Fp, Fp2};
use hashline::layer::{prove_layer_v3, v3_zcd_point, LayerParams};
use hashline::norm::NormChain;
use hashline::ntt::NttTables;
use hashline::pcs::{self, PcsParams};
use hashline::private_block_contract::ApprovedP1BlockContract;
use hashline::public_block_oracle::{
    lift_public_weight_claims, public_block_transcript, verify_public_block, PublicBlockError,
    PublicBlockOracle, PublicBlockProof,
};
use hashline::public_block_wire::validate_structure;
use hashline::sumcheck::SumcheckProof;
use hashline::transcript::Transcript;
use std::sync::{Mutex, MutexGuard};

const DOMAIN: &[u8] = b"zk60-fable-fa9-standalone-attention";
const D: usize = 16;
const T: usize = 32;

static SERIAL: Mutex<()> = Mutex::new(());

fn serial() -> MutexGuard<'static, ()> {
    SERIAL.lock().unwrap_or_else(|e| e.into_inner())
}

/// Tamper mode on while held; off again on drop (also on a failed assertion).
struct Tamper(#[allow(dead_code)] MutexGuard<'static, ()>);
impl Tamper {
    fn on() -> Tamper {
        let g = serial();
        at::set_tamper_mode(true);
        Tamper(g)
    }
}
impl Drop for Tamper {
    fn drop(&mut self) {
        at::set_tamper_mode(false);
    }
}

fn flag(name: &str) -> bool {
    std::env::var_os(name).is_some_and(|s| !s.is_empty())
}

fn params() -> LayerParams {
    LayerParams {
        log_cols: 8,
        inv_rate: 8,
        num_col_checks: 256,
    }
}

fn honest_block() -> (ApprovedP1BlockContract, PublicBlockWeights, Vec<i16>, OracleBlock) {
    let (approved, weights, input) = public_synthetic_fixture();
    let block = FixedCausalOracle::new(&approved, weights.clone())
        .unwrap()
        .build(&input)
        .unwrap();
    (approved, weights, input, block)
}

// ---- the standalone attention argument (the real prover and verifier, no FFN/seam) ----

fn prove_standalone(wit: &AttnWitness, r2: &Resid2) -> AttnProof {
    let ntt = NttTables::new(11);
    let mut tr = Transcript::new(DOMAIN);
    let (mut proof, mut pending, _) = at::prove_attn(wit, r2, &params(), &ntt, &mut tr);
    lift_public_weight_claims(&pending.lay, &mut pending.cc).unwrap();
    at::attn_open(pending, &mut proof, &mut tr);
    proof
}

fn verify_standalone(proof: &AttnProof, c: &AttnConsts, fc: &FullConsts) -> Result<(), String> {
    let ntt = NttTables::new(11);
    let mut tr = Transcript::new(DOMAIN);
    let (lay, mut cc) = at::verify_attn(proof, c, fc, &params(), &mut tr)?;
    lift_public_weight_claims(&lay, &mut cc).map_err(|e| e.to_string())?;
    at::verify_attn_open(proof, &lay, &cc, &params(), &ntt, &mut tr)
}

// ---- the typed B3 block proof from a hand-built witness (the honest oracle's own steps) ----

fn prove_typed(approved: &ApprovedP1BlockContract, b: &OracleBlock) -> PublicBlockProof {
    let r = approved.registration();
    let ntt = NttTables::new(11);
    let mut tr = public_block_transcript(approved);
    let (mut attention, mut pending, _) =
        at::prove_attn(&b.attention, &b.residual, &r.params, &ntt, &mut tr);
    let before = Transcript::clone_state(&tr);
    let ffn = prove_layer_v3(&b.ffn, T, &r.params, &ntt, &mut tr).proof;
    let rho = v3_zcd_point(&r.ffn, &ffn, &before);
    at::attn_seam(
        &mut pending.cc,
        &mut tr,
        &pending.lay,
        Some(&pending.a_data),
        &[rho],
        &ffn.zcd_term[..1],
        &ffn.zcd_term[1..2],
    )
    .unwrap();
    lift_public_weight_claims(&pending.lay, &mut pending.cc).unwrap();
    at::attn_open(pending, &mut attention, &mut tr);
    PublicBlockProof {
        contract_digest: approved.public_digest(),
        attention,
        ffn,
    }
}

/// Recompute the FFN half and the residual-2 edge from the (possibly tampered)
/// mlp-norm output plane, exactly as the oracle does for an honest one.
fn rebuild_ffn_and_residual(
    approved: &ApprovedP1BlockContract,
    weights: &PublicBlockWeights,
    b: &mut OracleBlock,
) {
    let r = approved.registration();
    let export = V3LayerExport {
        l: 0,
        dims: V3Dims {
            t: T,
            d: D,
            f: 16,
            layers: 1,
        },
        x: b.attention.nm.y.iter().map(|v| *v as i8).collect(),
        wg_t: weights.wg_t.clone(),
        wu_t: weights.wu_t.clone(),
        wd_t: weights.wd_t.clone(),
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
    b.ffn = derive_v3(&export, T);
    let z16: Vec<i64> = b.ffn.z16.iter().map(|v| i64::from(*v)).collect();
    let xw2: Vec<i64> = b
        .attention
        .xres1
        .iter()
        .zip(&z16)
        .map(|(x, z)| (x << r.residual.sh_x2) + (z << r.residual.sh_z2))
        .collect();
    let (xres2, rr2) = requant_round(&xw2, r.residual.sh_r2);
    b.residual = Resid2 {
        c: r.residual.clone(),
        z16,
        xres2,
        rr2,
    };
}

// ---- FA5 R09: the half-p isqrt alias of one norm row ----------------------

/// D = 2^63 = k + (p-1)/2 with k = 2^31, written as the i64 that
/// `Fp::from_i64` maps to 2^63 (2^63 - p).
const ALIAS_D: i64 = -9_223_372_032_559_808_513;
/// D^2 = 2^126 = -2^30 (mod p) (because 2^64 = 2^32 - 1 and 2^128 = -2^32).
const ALIAS_DSQ: i64 = -(1 << 30);

struct AliasRow {
    sse: i64,
    a1: i64,
    a2: i64,
    /// D 2^tn (mod p) = (2^32 - 1) 2^(tn-1), an integer for tn >= 1
    d_tn: i64,
    /// D 2^(tn+1) (mod p) = (2^32 - 1) 2^tn
    d_2tn: i64,
    rho: Vec<i64>,
    sig: Vec<i64>,
}

/// Overwrite row `t` of a norm chain with FA5's alias: every isqrt/SS/Square
/// relation and both limb pairs hold in F_p, NormDiv holds with y = 0 on every
/// element, and the remainders are about 2^(31+tn).
fn apply_alias(ch: &mut NormChain, x: &[i64], g: &[i64], n: &NormConsts, t: usize) -> AliasRow {
    assert!(n.tn >= 1, "the alias needs tn >= 1 (FA5: at tn = 0 the D 2^0 term is huge)");
    let row = &x[t * D..(t + 1) * D];
    let sse: i64 = row.iter().map(|v| v * v).sum::<i64>() + n.ceps;
    assert!(sse < 3 * (1i64 << 30), "k = 2^31 needs SSe < 3 * 2^30");
    let a1 = sse + (1 << 30);
    let a2 = (1i64 << 32) - 1 - a1;
    let d_tn = ((1i64 << 32) - 1) << (n.tn - 1);
    let d_2tn = ((1i64 << 32) - 1) << n.tn;
    let rho: Vec<i64> = (0..D).map(|i| 2 * n.cn * row[i] * g[i] + d_tn).collect();
    let sig: Vec<i64> = rho.iter().map(|r| d_2tn - 1 - r).collect();
    ch.sse[t] = sse;
    ch.dd[t] = ALIAS_D;
    ch.dsq[t] = ALIAS_DSQ;
    ch.a1[t] = a1;
    ch.a2[t] = a2;
    for i in 0..D {
        ch.y[t * D + i] = 0;
        ch.rho[t * D + i] = rho[i];
        ch.sig[t * D + i] = sig[i];
    }
    AliasRow {
        sse,
        a1,
        a2,
        d_tn,
        d_2tn,
        rho,
        sig,
    }
}

/// Replay, in F_p, every relation the verifier checks on that row except the
/// remainder limb WIDTH (the only thing that depends on n_limbs).
fn alias_satisfies_every_field_relation(a: &AliasRow, x: &[i64], g: &[i64], n: &NormConsts) {
    let f = Fp2::from_i64;
    let pow2 = |k: u32| Fp::new(1u64 << k);
    let dd = f(ALIAS_D);
    let dsq = f(ALIAS_DSQ);
    // SS row-sum claim: a1 + Dsq - ceps = sum x^2
    assert_eq!(f(a.a1).add(dsq).sub(f(n.ceps)), f(a.sse - n.ceps));
    // isqrt pin: a2 = 2D - a1; Square: Dsq = D D
    assert_eq!(f(a.a2), dd.mul_base(pow2(1)).sub(f(a.a1)));
    assert_eq!(dsq, dd.mul(dd));
    // a1, a2 as two U16 limbs each
    for v in [a.a1, a.a2] {
        assert!((0..1i64 << 32).contains(&v));
        assert_eq!(f(v), f(v & 0xffff).add(f(v >> 16).mul_base(pow2(16))));
    }
    // the ROUND division relation with y = 0, and sigma = 2 div - 1 - rho
    let div = dd.mul_base(pow2(n.tn));
    let two_div = dd.mul_base(pow2(n.tn + 1));
    assert_eq!(div, f(a.d_tn));
    assert_eq!(two_div, f(a.d_2tn));
    for i in 0..D {
        let num = f(x[i]).mul(f(g[i])).mul_base(Fp::from_i64(2 * n.cn));
        let y = Fp2::ZERO;
        assert_eq!(y.mul(two_div).add(f(a.rho[i])).sub(num).sub(div), Fp2::ZERO);
        assert_eq!(f(a.sig[i]).add(f(a.rho[i])).add(Fp2::ONE), two_div);
        // y = 0 is in the Int8 table; the remainders are positive integers
        assert!(a.rho[i] > 0 && a.sig[i] > 0);
    }
}

/// The two-limb encoding of a value: what `pack` commits ((v >> 16k) & 0xffff).
fn two_limbs(v: i64) -> i64 {
    (v & 0xffff) | (((v >> 16) & 0xffff) << 16)
}

#[test]
fn fixed_profile_honest_witness_verifies_standalone_and_typed() {
    let _s = serial();
    assert!(!at::tamper_mode());
    let (approved, _, _, b) = honest_block();
    let proof = prove_standalone(&b.attention, &b.residual);
    assert_eq!(verify_standalone(&proof, &b.attention.c, &b.residual.c), Ok(()));
    let typed = prove_typed(&approved, &b);
    assert_eq!(verify_public_block(&approved, &typed), Ok(()));
    let lay = at::attn_layout_of(&b.attention.c, &b.residual.c, 8);
    let bytes = typed.attention.to_bytes();
    use sha2::Digest;
    println!(
        "FA9 HONEST fixed profile: A rows {} H rows {} log_lm {} vals(standalone) {} vals(typed) {} sc {} attention_bytes {} sha256 {}",
        lay.a_len / 256,
        lay.h_len / 256,
        lay.log_lm,
        proof.vals.len(),
        typed.attention.vals.len(),
        typed.attention.sc.len(),
        bytes.len(),
        hashline::silu::hex(&sha2::Sha256::digest(&bytes))
    );
}

/// R09 at the FIXED profile (n_limbs = 2, tn = 11): the alias satisfies every
/// relation in F_p but its remainders (~2^42) have no two-U16-limb encoding.
/// The prover's masked limbs carry rho mod 2^32, so the division relation
/// fails inside the D zero-check. That is the ONLY exclusion.
#[test]
fn r09_alias_is_refused_at_the_fixed_profile_only_by_the_two_limb_remainder_width() {
    let _t = Tamper::on();
    let (approved, weights, _, mut b) = honest_block();
    let n = b.attention.c.mnorm;
    assert_eq!((n.tn, n.cn, n.ceps, n.wrho, n.n_limbs), (11, 1024, 1, 29, 2));
    let honest_y: Vec<i64> = b.attention.nm.y[..D].to_vec();
    assert!(honest_y.iter().any(|v| *v != 0));
    // the mlp-norm site (xm8): no downstream consumer inside the attention argument
    let alias = apply_alias(&mut b.attention.nm, &b.attention.xres1, &b.attention.g_m, &n, 0);
    alias_satisfies_every_field_relation(&alias, &b.attention.xres1[..D], &b.attention.g_m, &n);
    // the class-wide margin: every element's remainder lies in [2^42 - 2^10 - 2^33, 2^42 - 2^10 + 2^33]
    let lo = (1i64 << 42) - (1 << 10) - (1 << 33);
    let hi = (1i64 << 42) - (1 << 10) + (1 << 33);
    for v in alias.rho.iter().chain(&alias.sig) {
        assert!((lo..=hi).contains(v), "{v}");
        assert!(*v >= 1 << 32, "no two-limb encoding");
        assert!(*v < 1 << 48, "a three-limb encoding exists");
        assert_ne!(two_limbs(*v), *v);
    }
    let proof = prove_standalone(&b.attention, &b.residual);
    let err = verify_standalone(&proof, &b.attention.c, &b.residual.c).unwrap_err();
    if flag("FA9_R09_FIX") {
        assert!(err.starts_with("isqrt: D limbs"), "with the D range fact the pin refuses first: {err}");
    } else {
        assert!(err.starts_with("zero-check D"), "the truncated remainder breaks NormDiv: {err}");
    }
    println!("FA9 R09 fixed profile standalone refusal: {err}");
    // the approved contract's own typed verifier (FFN rebuilt on the aliased X plane)
    rebuild_ffn_and_residual(&approved, &weights, &mut b);
    let typed = prove_typed(&approved, &b);
    assert_eq!(
        verify_public_block(&approved, &typed),
        Err(PublicBlockError::Verification("attention argument"))
    );
}

/// R09 at a WIDER profile: three remainder limbs (wrho 48) and tn = 11 admit the
/// alias's ~2^42 remainders, and the verifier accepts an all-zero norm output
/// row. KNOWN GAP (FA5 R09, HIGH for deployment profiles): no range fact binds
/// D to a small integer. Flip the assertion when the D limb range fact lands
/// (FA9_R09_FIX=1 asserts the refusal for a locally applied patch).
#[test]
fn known_r09_gap_wider_profile_three_limbs_accepts_an_all_zero_norm_row() {
    let _t = Tamper::on();
    let (_, _, _, mut b) = honest_block();
    let wide = NormConsts {
        tn: 11,
        cn: 1024,
        ceps: 1,
        wrho: 48,
        n_limbs: 3,
    };
    b.attention.c.anorm = wide;
    b.attention.c.mnorm = wide;
    // control: the honest witness verifies at the wider profile (third limb zero)
    let proof = prove_standalone(&b.attention, &b.residual);
    assert_eq!(verify_standalone(&proof, &b.attention.c, &b.residual.c), Ok(()));
    let honest_y: Vec<i64> = b.attention.nm.y[..D].to_vec();
    assert!(honest_y.iter().any(|v| *v != 0));
    let alias = apply_alias(&mut b.attention.nm, &b.attention.xres1, &b.attention.g_m, &wide, 0);
    alias_satisfies_every_field_relation(&alias, &b.attention.xres1[..D], &b.attention.g_m, &wide);
    assert!(b.attention.nm.y[..D].iter().all(|v| *v == 0));
    let proof = prove_standalone(&b.attention, &b.residual);
    let result = verify_standalone(&proof, &b.attention.c, &b.residual.c);
    println!("FA9 R09 wider profile (3 limbs): honest y row {honest_y:?} -> alias y row all zero; verifier says {result:?}");
    if flag("FA9_R09_FIX") {
        let err = result.expect_err("R09 fix applied: the alias must be refused");
        assert!(err.starts_with("isqrt: D limbs"), "{err}");
    } else {
        assert_eq!(
            result,
            Ok(()),
            "KNOWN GAP (FA5 R09): the wider profile accepts D = k + (p-1)/2; flip when the D range fact lands"
        );
    }
}

/// R10: the statement advertises `wrho`, the proof enforces 2^(16 n_limbs).
/// (a) an honest witness whose remainders exceed 2^20 verifies under a
/// statement that advertises wrho = 20 (the oracle's host check would refuse
/// it); (b) a remainder in [2^29, 2^32) that keeps the division relation is
/// refused only through sigma's limbs (it needs a negative sigma), i.e. the
/// bound rho < 2 D 2^tn is enforced by sigma given D, never by wrho.
#[test]
fn known_r10_gap_advertised_remainder_width_is_a_label_not_a_proven_range() {
    let _t = Tamper::on();
    let (approved, weights, _) = public_synthetic_fixture();
    let input: Vec<i16> = (0..T * D)
        .map(|i| ((i * 7919) % 16001) as i16 - 8000)
        .collect();
    let mut b = FixedCausalOracle::new(&approved, weights)
        .unwrap()
        .build(&input)
        .unwrap();
    let max_rho = *b.attention.na.rho.iter().max().unwrap();
    assert!(max_rho >= 1 << 20, "{max_rho}");
    assert!(max_rho < 1 << 29);
    // (a) the same honest witness, statement label wrho = 20 on both sides
    b.attention.c.anorm.wrho = 20;
    b.attention.c.mnorm.wrho = 20;
    let proof = prove_standalone(&b.attention, &b.residual);
    assert_eq!(
        verify_standalone(&proof, &b.attention.c, &b.residual.c),
        Ok(()),
        "KNOWN GAP (FA5 R10): remainders >= 2^20 verify under an advertised width of 20"
    );
    // wrho IS transcript-bound: the same proof under the label 29 is refused (a label, not a range)
    let mut c29 = b.attention.c.clone();
    c29.anorm.wrho = 29;
    c29.mnorm.wrho = 29;
    assert!(verify_standalone(&proof, &c29, &b.residual.c).is_err());
    // (b) rho' = rho + j (2 D 2^tn), y' = y - j keeps NormDiv; sigma' < 0 has no limb encoding
    let n = b.attention.c.mnorm;
    let dvp = 2 * (b.attention.nm.dd[0] << n.tn);
    let j = ((1i64 << 29) - b.attention.nm.rho[0] + dvp - 1) / dvp;
    let rho2 = b.attention.nm.rho[0] + j * dvp;
    assert!(rho2 >= 1 << 29 && rho2 < 1 << 32, "{rho2}");
    b.attention.nm.rho[0] = rho2;
    b.attention.nm.y[0] -= j;
    assert!((-128..=127).contains(&b.attention.nm.y[0]));
    b.attention.nm.sig[0] -= j * dvp;
    assert!(b.attention.nm.sig[0] < 0);
    let proof = prove_standalone(&b.attention, &b.residual);
    let err = verify_standalone(&proof, &b.attention.c, &b.residual.c).unwrap_err();
    assert!(err.starts_with("norm: sigma = 2 div - 1 - rho"), "{err}");
    println!("FA9 R10: max honest rho {max_rho} (2^{:.1}) accepted under wrho=20; rho' = rho + {j} (2 D 2^tn) = 2^{:.1} with y' = y - {j} refused by: {err}",
             (max_rho as f64).log2(), (rho2 as f64).log2());
}

/// R31: the registrar precheck accepts ANY root of the right shape; the words
/// behind it are not provably int8. A root over a Wq word 2^40 is approved,
/// and a proof against that approval verifies (the activation column that
/// meets the word is zero, so every relation holds over the integers).
/// KNOWN GAP (FA5 R31): the int8 range of W/gamma is a registrar obligation.
#[test]
fn known_r31_gap_registrar_approves_a_root_over_out_of_class_words_and_the_proof_verifies() {
    let _s = serial();
    assert!(!at::tamper_mode());
    const J0: usize = 5; // output row
    const I0: usize = 9; // input column
    let (approved, weights, input) = public_synthetic_fixture();
    assert_eq!(weights.wq[J0 * D + I0], 0);
    let r = approved.registration();
    let lay = at::attn_layout_of(&r.attention, &r.residual, 8);
    // replicate cpu_weight_commitments' packing with i64 words
    let pack_w = |wq_word: i64| -> Vec<Fp> {
        let mut aw = vec![Fp::ZERO; lay.w_len];
        for i in 0..D {
            for j in 0..D {
                aw[lay.wq + i * D + j] = Fp::from_i64(i64::from(weights.wq[j * D + i]));
                aw[lay.wo + i * D + j] = Fp::from_i64(i64::from(weights.wo[j * D + i]));
            }
            for j in 0..8 {
                aw[lay.wk + i * 8 + j] = Fp::from_i64(i64::from(weights.wk[j * D + i]));
                aw[lay.wv + i * 8 + j] = Fp::from_i64(i64::from(weights.wv[j * D + i]));
            }
            aw[lay.gpack + i] = Fp::from_i64(i64::from(weights.gamma_a[i]));
            aw[lay.gpack + D + i] = Fp::from_i64(i64::from(weights.gamma_m[i]));
        }
        aw[lay.wq + I0 * D + J0] = Fp::from_i64(wq_word);
        aw
    };
    let pp = PcsParams {
        log_cols: 8,
        inv_rate: 8,
        num_col_checks: 256,
    };
    let ntt = NttTables::new(11);
    let root_of = |aw: &[Fp]| pcs::commit(&pp, aw, &ntt).commitment();
    let honest_root = root_of(&pack_w(0));
    assert_eq!(honest_root.root, r.attention_weights.root, "packing replicates the fixture root");
    let wide_root = root_of(&pack_w(1 << 40));
    assert_ne!(wide_root.root, honest_root.root);
    let mut reg = approved.registration();
    reg.attention_weights = wide_root.clone();
    let wide = ApprovedP1BlockContract::from_trusted_registration(reg)
        .expect("KNOWN GAP (FA5 R31): the precheck accepts any well-shaped root");
    assert_ne!(wide.public_digest(), approved.public_digest());
    // the proof path: zero the activation column that meets the word, then swap the word in
    let mut input0 = input.clone();
    for t in 0..T {
        input0[t * D + I0] = 0;
    }
    let mut b = FixedCausalOracle::new(&approved, weights.clone())
        .unwrap()
        .build(&input0)
        .unwrap();
    assert!((0..T).all(|t| b.attention.na.y[t * D + I0] == 0));
    b.attention.wq[J0 * D + I0] = 1 << 40;
    let proof = prove_typed(&wide, &b);
    assert_eq!(proof.attention.w_com.as_ref().unwrap().root, wide_root.root);
    assert_eq!(
        verify_public_block(&wide, &proof),
        Ok(()),
        "KNOWN GAP (FA5 R31): no relation range-checks the approved W words"
    );
    // the original approval refuses it, but only because the ROOT differs
    let mut relabelled = proof.clone();
    relabelled.contract_digest = approved.public_digest();
    assert_eq!(
        verify_public_block(&approved, &relabelled),
        Err(PublicBlockError::AttentionWeights)
    );
    println!("FA9 R31: root over Wq[{J0}][{I0}] = 2^40 approved and proven (typed B3): Ok");
}

/// R32: the typed B3 API ignores extra trailing `proof.sc` entries and a
/// non-empty (unused) `helper_sums`; the B4/B5 structural gate refuses both.
/// KNOWN GAP (FA5 R32, no soundness impact found). FA9_R32_FIX=1 asserts the
/// typed refusal for a locally applied verifier patch.
#[test]
fn known_r32_gap_typed_b3_api_ignores_extra_data_that_the_wire_gate_refuses() {
    let _s = serial();
    assert!(!at::tamper_mode());
    let (approved, weights, input) = public_synthetic_fixture();
    let proof = PublicBlockOracle::new(&approved, weights)
        .unwrap()
        .prove(&input)
        .unwrap();
    assert_eq!(verify_public_block(&approved, &proof), Ok(()));
    validate_structure(&proof).unwrap();
    let mut extra_sc = proof.clone();
    extra_sc.attention.sc.push(SumcheckProof::default());
    let mut extra_hs = proof.clone();
    extra_hs.attention.helper_sums.push(Fp2::ONE);
    assert!(validate_structure(&extra_sc).is_err());
    assert!(validate_structure(&extra_hs).is_err());
    let fix = flag("FA9_R32_FIX");
    for (name, bad) in [("extra trailing attention sumcheck", &extra_sc), ("non-empty attention helper_sums", &extra_hs)] {
        let result = verify_public_block(&approved, bad);
        println!("FA9 R32 typed B3 with {name}: {result:?}");
        if fix {
            assert_eq!(result, Err(PublicBlockError::Verification("attention argument")), "{name}");
        } else {
            assert_eq!(result, Ok(()), "KNOWN GAP (FA5 R32): typed B3 accepts {name}; flip when the refusal lands");
        }
    }
    // the neighbours that ARE exact-count in the typed API (recorded, not gaps)
    let mut extra_vals = proof.clone();
    extra_vals.attention.vals.push(Fp2::ZERO);
    assert!(verify_public_block(&approved, &extra_vals).is_err());
    let mut extra_collapse = proof.clone();
    extra_collapse.attention.collapse.push((SumcheckProof::default(), Fp2::ZERO));
    assert!(verify_public_block(&approved, &extra_collapse).is_err());
    // probes on the FFN half's vectors (outcomes printed for the review record)
    let probes: Vec<(&str, PublicBlockProof)> = vec![
        ("ffn.gu_claims", {
            let mut p = proof.clone();
            p.ffn.gu_claims.push(Fp2::ZERO);
            p
        }),
        ("ffn.gu_term", {
            let mut p = proof.clone();
            p.ffn.gu_term.push(Fp2::ZERO);
            p
        }),
        ("ffn.d_claims", {
            let mut p = proof.clone();
            p.ffn.d_claims.push(Fp2::ZERO);
            p
        }),
        ("ffn.d_term", {
            let mut p = proof.clone();
            p.ffn.d_term.push(Fp2::ZERO);
            p
        }),
        ("ffn.zcf_term", {
            let mut p = proof.clone();
            p.ffn.zcf_term.push(Fp2::ZERO);
            p
        }),
        ("ffn.zcd_term", {
            let mut p = proof.clone();
            p.ffn.zcd_term.push(Fp2::ZERO);
            p
        }),
        ("ffn.helper_sums", {
            let mut p = proof.clone();
            p.ffn.helper_sums.push(Fp2::ZERO);
            p
        }),
    ];
    for (name, p) in &probes {
        println!(
            "FA9 R32 probe: typed B3 with one extra trailing {name} entry -> {:?}; wire gate -> {}",
            verify_public_block(&approved, p),
            if validate_structure(p).is_ok() { "accepts" } else { "refuses" }
        );
    }
}
