//! **D63 L3 finding F12, checked against the Rust verifier.** `M`'s product-form check
//! certifies its FIRST functional only up to the blinding polynomial's sum over G_512.
//! `combined_weights` starts the theta powers at theta^0 = 1, and nothing verifies
//! `b_512 = -b_0` (the honest prover's zero-sum choice). So a prover that commits a `b` with
//! `sum_{G_512} p_b = delta` can claim functional 0 as `true + delta`, and `mask_verify`
//! accepts (formal/ZK60Formal/SoundMProduct.lean, `mproduct_offset_accepts`).
//!
//! These tests build exactly that commitment and record what the verifier does today.
//! They are the negative test the finding asks for: once the theta offset is fixed, the
//! first test must flip to a rejection.

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

fn open_and_verify(mc: &MaskCommit, fs: &[MaskFunctional], ntt: &NttTables) -> Result<(), String> {
    let mut tp = Transcript::new(b"zk60-f12");
    let op = mask_open(mc, fs, ntt, &mut tp);
    let mut tv = Transcript::new(b"zk60-f12");
    mask_verify(&mc.tree.root(), &mc.specs, fs, &op, ntt, &mut tv)
}

/// **F12, as the verifier stands today:** a commitment whose `b` sums to `delta` over G_512,
/// opened with functional 0 claimed as `true + delta`, is ACCEPTED. When the theta offset is
/// fixed (`combined_weights` starting at `theta^1`), this test must be flipped to expect a
/// rejection.
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
    // the forged value of functional 0 (true + delta) DOES verify
    fs[0].value = truth[0].add(Fp2::from_base(delta));
    let forged = open_and_verify(&mc, &fs, &ntt);
    eprintln!("F12: functional 0 claimed as true + delta (delta = 5) with a commitment whose b sums to delta over G_512: mask_verify -> {forged:?}");
    assert!(forged.is_ok(), "F12 did not reproduce: {forged:?}");
    // the same shift on functional 1 (theta^1) is rejected: only the first functional is unscaled
    fs[0].value = truth[0];
    fs[1].value = truth[1].add(Fp2::from_base(delta));
    assert!(open_and_verify(&mc, &fs, &ntt).is_err(), "a shift on functional 1 verified");
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
