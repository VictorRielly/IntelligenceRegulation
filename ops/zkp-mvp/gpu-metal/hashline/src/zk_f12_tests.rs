//! **D63 L3 finding F12, checked against the Rust verifier, and its fix (D65(1)).** Before the fix `M`'s
//! product-form check certified its FIRST functional only up to the blinding polynomial's sum over G_512:
//! `combined_weights` started the theta powers at theta^0 = 1, and nothing verifies `b_512 = -b_0` (the honest
//! prover's zero-sum choice). So a prover that committed a `b` with `sum_{G_512} p_b = delta` could claim
//! functional 0 as `true + delta`, and `mask_verify` accepted (formal/ZK60Formal/SoundMProduct.lean,
//! `mproduct_offset_accepts`; the reproduction is `results/zk60_h124_witness_20261104/f12_test.log`).
//!
//! The fix starts the powers at theta^1 (`mproduct_sound_shift`). These tests build exactly the forging
//! commitment and check that the verifier now REJECTS it, that the honest control still verifies, and that an
//! opening made under one version is refused by the other in both directions. The pre-F12 version exists only
//! through the test build's hook `set_pre_f12_theta_start_for_tests`.

use super::*;

/// `mask_commit` (untagged) with the blinding polynomial's G_512 sum moved to `delta`:
/// `b_re[m] = -b_re[0] + delta / m`, so `m (b_re[0] + b_re[m]) = delta`. Everything else
/// is drawn and encoded exactly as `mask_commit` does.
fn commit_with_blinding_sum(specs: &[(usize, usize)], ntt: &NttTables, rng: &mut ZkRng, delta: Fp) -> MaskCommit {
    let m = 1usize << MASK_LOG_MSG;
    let dom = 1usize << MASK_LOG_DOM;
    let pows = coset_powers(Fp::new(7), dom);
    let masks: Vec<CfsMask> = specs.iter().map(|&(n, d)| CfsMask::random(rng, n, d)).collect();
    let n_base = 2 * masks.len() + 4;
    let mut encoded = vec![Fp::ZERO; n_base * dom];
    let mut a_coefs = Vec::with_capacity(2 * masks.len());
    for (s, mk) in masks.iter().enumerate() {
        let re: Vec<Fp> = mk.coeffs.iter().map(|c| c.c0).collect();
        let im: Vec<Fp> = mk.coeffs.iter().map(|c| c.c1).collect();
        for (k, part) in [re, im].iter().enumerate() {
            let mut msg = vec![Fp::ZERO; m];
            msg[..part.len()].copy_from_slice(part);
            let pads = rng.fp_vec(MASK_Q);
            msg[part.len()..part.len() + MASK_Q].copy_from_slice(&pads);
            ntt.inverse(&mut msg);
            encode_coeffs_coset(ntt, &msg, &pows, &mut encoded[(2 * s + k) * dom..(2 * s + k + 1) * dom]);
            a_coefs.push(msg);
        }
    }
    let mut b_re = rng.fp_vec(2 * m);
    let mut b_im = rng.fp_vec(2 * m);
    b_re[m] = b_re[0].neg().add(delta.mul(Fp::new(m as u64).inv()));
    b_im[m] = b_im[0].neg();
    let u_re = rng.fp_vec(2 * m);
    let u_im = rng.fp_vec(2 * m);
    let base0 = 2 * masks.len();
    for (k, c) in [&b_re, &b_im, &u_re, &u_im].iter().enumerate() {
        encode_coeffs_coset(ntt, c, &pows, &mut encoded[(base0 + k) * dom..(base0 + k + 1) * dom]);
    }
    let salts: Vec<[u8; 32]> = (0..dom).map(|_| rng.bytes32()).collect();
    let leaves = pcs::hash_columns(&encoded, n_base, dom);
    let salted: Vec<Digest> = leaves.iter().zip(salts.iter()).map(|(l, s)| salt_leaf(l, s)).collect();
    let tree = MerkleTree::build(salted);
    MaskCommit { specs: specs.to_vec(), masks, a_coefs, encoded, b: (b_re, b_im), u: (u_re, u_im), salts, tree }
}

/// two functionals, one per mask row, with simple public weights; their TRUE values
fn functionals(mc: &MaskCommit) -> (Vec<MaskFunctional>, Vec<Fp2>) {
    let mut fs = Vec::new();
    let mut truth = Vec::new();
    for (row, &(n, d)) in mc.specs.iter().enumerate() {
        let l = CfsMask::len(n, d);
        let w: Vec<Fp2> = (0..l).map(|j| Fp2::from_u64(3 * j as u64 + 1 + row as u64)).collect();
        let v = w.iter().zip(mc.masks[row].coeffs.iter()).fold(Fp2::ZERO, |acc, (x, c)| acc.add(x.mul(*c)));
        fs.push(MaskFunctional { terms: vec![(row, w)], value: v });
        truth.push(v);
    }
    (fs, truth)
}

/// Open under one version and verify under another (`true` = the pre-F12 theta^0 start, through the test hook;
/// `false` = this build's theta^1). The hook is reset before returning, whatever happens.
fn open_and_verify_as(mc: &MaskCommit, fs: &[MaskFunctional], ntt: &NttTables, open_pre_f12: bool, verify_pre_f12: bool) -> Result<(), String> {
    struct Reset;
    impl Drop for Reset {
        fn drop(&mut self) {
            set_pre_f12_theta_start_for_tests(false);
        }
    }
    let _reset = Reset;
    let mut tp = Transcript::new(b"zk60-f12");
    set_pre_f12_theta_start_for_tests(open_pre_f12);
    let op = mask_open(mc, fs, ntt, &mut tp);
    let mut tv = Transcript::new(b"zk60-f12");
    set_pre_f12_theta_start_for_tests(verify_pre_f12);
    let r = mask_verify(&mc.tree.root(), &mc.specs, fs, &op, ntt, &mut tv);
    set_pre_f12_theta_start_for_tests(false);
    r
}

fn open_and_verify(mc: &MaskCommit, fs: &[MaskFunctional], ntt: &NttTables) -> Result<(), String> {
    open_and_verify_as(mc, fs, ntt, false, false)
}

/// **F12, after the fix:** a commitment whose `b` sums to `delta` over G_512, opened with functional 0 claimed as
/// `true + delta`, is REJECTED (before D65(1) it was accepted: `f12_the_pre_f12_start_accepts_the_forgery`
/// below keeps that reproduction). The same shift on functional 1 is rejected too, and so are the true values
/// against this commitment.
#[test]
fn f12_the_first_functional_is_certified_only_up_to_the_blinding_sum() {
    let specs = vec![(3usize, 2usize), (2usize, 3usize)];
    let ntt = NttTables::new(MASK_LOG_DOM);
    let delta = Fp::new(5);
    let mut rng = ZkRng::new(0xF12, b"zk60-f12");
    let mc = commit_with_blinding_sum(&specs, &ntt, &mut rng, delta);
    let (mut fs, truth) = functionals(&mc);
    // the honest values do NOT verify against this commitment: its blinding does not sum to zero
    assert!(open_and_verify(&mc, &fs, &ntt).is_err(), "the true values verified against a commitment whose b sums to delta");
    // the forged value of functional 0 (true + delta) is now REJECTED
    fs[0].value = truth[0].add(Fp2::from_base(delta));
    let forged = open_and_verify(&mc, &fs, &ntt);
    eprintln!("F12 (fixed): functional 0 claimed as true + delta (delta = 5) with a commitment whose b sums to delta over G_512: mask_verify -> {forged:?}");
    let e = forged.expect_err("F12 is NOT fixed: the forged first functional verified");
    assert!(e.contains("the product polynomial's sum"), "the forgery was refused, but not by the sum check: {e}");
    // the same shift on functional 1 is rejected
    fs[0].value = truth[0];
    fs[1].value = truth[1].add(Fp2::from_base(delta));
    assert!(open_and_verify(&mc, &fs, &ntt).is_err(), "a shift on functional 1 verified");
    // and a forger cannot compensate the offset on any single functional: whatever delta' it adds to functional
    // i, the residual delta' theta^(i+1) - delta is a nonzero polynomial in theta
    for i in 0..2 {
        for k in [1u64, 5, 7, 512] {
            let mut fs2 = fs.clone();
            fs2[0].value = truth[0];
            fs2[1].value = truth[1];
            fs2[i].value = truth[i].add(Fp2::from_u64(k));
            assert!(open_and_verify(&mc, &fs2, &ntt).is_err(), "functional {i} shifted by {k} verified against an offset b");
        }
    }
}

/// The reproduction as it stood before D65(1), through the test hook: with the pre-F12 theta^0 start on BOTH
/// sides, the same forgery is accepted. This is what the fix removes; no build proves or verifies this way.
#[test]
fn f12_the_pre_f12_start_accepts_the_forgery() {
    let specs = vec![(3usize, 2usize), (2usize, 3usize)];
    let ntt = NttTables::new(MASK_LOG_DOM);
    let delta = Fp::new(5);
    let mut rng = ZkRng::new(0xF12, b"zk60-f12");
    let mc = commit_with_blinding_sum(&specs, &ntt, &mut rng, delta);
    let (mut fs, truth) = functionals(&mc);
    fs[0].value = truth[0].add(Fp2::from_base(delta));
    let pre = open_and_verify_as(&mc, &fs, &ntt, true, true);
    assert!(pre.is_ok(), "the pre-F12 reproduction no longer reproduces: {pre:?}");
    assert!(open_and_verify(&mc, &fs, &ntt).is_err(), "the fixed verifier accepted the forgery");
}

/// Control: an HONEST commitment (b sums to zero) accepts the true values and rejects
/// functional 0 shifted by delta.
#[test]
fn f12_control_an_honest_commitment_rejects_a_shifted_first_functional() {
    let specs = vec![(3usize, 2usize), (2usize, 3usize)];
    let ntt = NttTables::new(MASK_LOG_DOM);
    let mut rng = ZkRng::new(0xF12, b"zk60-f12");
    let mc = commit_with_blinding_sum(&specs, &ntt, &mut rng, Fp::ZERO);
    let (mut fs, truth) = functionals(&mc);
    open_and_verify(&mc, &fs, &ntt).expect("the honest values verify");
    fs[0].value = truth[0].add(Fp2::from_u64(5));
    assert!(open_and_verify(&mc, &fs, &ntt).is_err(), "a shifted first functional verified against an honest commitment");
}

/// **The two versions refuse each other, at `M`.** An honest commitment with its true values: the opening made
/// under this build's theta^1 start verifies under theta^1 and is REFUSED by a pre-F12 (theta^0) verifier, and an
/// opening made the pre-F12 way verifies only the pre-F12 way and is REFUSED by this build's verifier. The
/// receipt-level version of this check is `private_block::f12_version_tests`.
#[test]
fn f12_an_opening_under_one_version_does_not_verify_under_the_other() {
    let specs = vec![(3usize, 2usize), (2usize, 3usize), (4usize, 2usize)];
    let ntt = NttTables::new(MASK_LOG_DOM);
    let mut rng = ZkRng::new(0xF12_2, b"zk60-f12-versions");
    let mc = commit_with_blinding_sum(&specs, &ntt, &mut rng, Fp::ZERO);
    let (fs, _) = functionals(&mc);
    open_and_verify_as(&mc, &fs, &ntt, false, false).expect("new opening, new verifier");
    open_and_verify_as(&mc, &fs, &ntt, true, true).expect("pre-F12 opening, pre-F12 verifier (the hook reproduces the old build)");
    let e = open_and_verify_as(&mc, &fs, &ntt, false, true).expect_err("an opening made under theta^1 verified under the pre-F12 theta^0 start");
    eprintln!("F12 versions: theta^1 opening under the pre-F12 verifier -> {e}");
    let e = open_and_verify_as(&mc, &fs, &ntt, true, false).expect_err("an opening made under the pre-F12 theta^0 start verified under theta^1");
    eprintln!("F12 versions: pre-F12 opening under the theta^1 verifier -> {e}");
    // the hook is per thread and is reset: this thread is back on theta^1
    assert!(!pre_f12_theta_start_for_tests(), "the pre-F12 hook leaked out of the helper");
}
