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

/// Pre-Opt-4 reference `mask_open` using `weight_polys` + `poly_mul_512` term-by-term.
fn mask_open_poly_mul_reference(mc: &MaskCommit, functionals: &[MaskFunctional], ntt: &NttTables, tr: &mut Transcript) -> MaskOpening {
    let m = 1usize << MASK_LOG_MSG;
    let dom = 1usize << MASK_LOG_DOM;
    let theta = tr.challenge_fp2();
    let (ws, _v) = combined_weights(&mc.specs, functionals, theta);
    let mut q_re = mc.b.0.clone();
    let mut q_im = mc.b.1.clone();
    for s in 0..mc.masks.len() {
        let (w_re, w_im) = weight_polys(&ws[s], ntt);
        let (a_re, a_im) = (&mc.a_coefs[2 * s], &mc.a_coefs[2 * s + 1]);
        let rr = poly_mul_512(a_re, &w_re, ntt);
        let ii = poly_mul_512(a_im, &w_im, ntt);
        let ri = poly_mul_512(a_re, &w_im, ntt);
        let ir = poly_mul_512(a_im, &w_re, ntt);
        for i in 0..2 * m {
            q_re[i] = q_re[i].add(rr[i]).add(ii[i].mul(Fp::new(7)));
            q_im[i] = q_im[i].add(ri[i]).add(ir[i]);
        }
    }
    let q: Vec<Fp2> = q_re.iter().zip(q_im.iter()).map(|(a, b)| Fp2::new(*a, *b)).collect();
    tr.absorb_fp2(b"mask-q", &q);
    let n_rows = 2 * mc.masks.len() + 2;
    let rs = tr.challenge_fp2_vec(n_rows);
    let mut prox: Vec<Fp2> = (0..2 * m).map(|i| Fp2::new(mc.u.0[i], mc.u.1[i])).collect();
    for (row, r) in rs.iter().enumerate() {
        let coeffs: &[Fp] = if row < 2 * mc.masks.len() { &mc.a_coefs[row] } else if row == 2 * mc.masks.len() { &mc.b.0 } else { &mc.b.1 };
        for (i, c) in coeffs.iter().enumerate() {
            prox[i] = prox[i].add(r.mul_base(*c));
        }
    }
    tr.absorb_fp2(b"mask-prox", &prox);
    let idx = tr.challenge_indices(MASK_Q, dom);
    let n_base = 2 * mc.masks.len() + 4;
    let columns = idx
        .iter()
        .map(|&j| {
            let col: Vec<Fp> = (0..n_base).map(|r| mc.encoded[r * dom + j]).collect();
            (j, col, mc.salts[j], mc.tree.path(j))
        })
        .collect();
    MaskOpening { q, prox, columns }
}

/// **[Opt 4] `mask_open`'s stride-4 coset eval-domain accumulation equals the
/// `poly_mul_512` reference byte-for-byte** across 0, 1, 2, all-zero functionals,
/// partial-row functionals, and 23-mask W16R2-sized specs (both `max_log = 12`
/// and `max_log = 16`): `q`, `prox`, `columns`, `write_bytes`, post-opening
/// transcript state, and `mask_verify`.
#[test]
fn mask_open_stride4_matches_poly_mul_reference_byte_for_byte() {
    let ntt12 = NttTables::new(MASK_LOG_DOM);
    let ntt16 = NttTables::new(16);

    let check = |label: &str, mc: &MaskCommit, fs: &[MaskFunctional], ntt: &NttTables| {
        let mut t_got = Transcript::new(b"zk60-opt4-parity");
        let mut t_want = Transcript::new(b"zk60-opt4-parity");
        let got = mask_open(mc, fs, ntt, &mut t_got);
        let want = mask_open_poly_mul_reference(mc, fs, ntt, &mut t_want);
        assert_eq!(got.q, want.q, "{label}: q differs");
        assert_eq!(got.prox, want.prox, "{label}: prox differs");
        assert_eq!(got.columns, want.columns, "{label}: columns differ");
        let (mut gb, mut wb) = (Vec::new(), Vec::new());
        got.write_bytes(&mut gb);
        want.write_bytes(&mut wb);
        assert_eq!(gb, wb, "{label}: serialized opening bytes differ");
        assert_eq!(t_got.state(), t_want.state(), "{label}: post-opening transcript state differs");
        assert_eq!(t_got.counter(), t_want.counter(), "{label}: post-opening transcript counter differs");
        let mut tv = Transcript::new(b"zk60-opt4-parity");
        mask_verify(&mc.tree.root(), &mc.specs, fs, &got, ntt, &mut tv)
            .unwrap_or_else(|e| panic!("{label}: mask_verify failed: {e}"));
    };

    // 0 masks
    let mut rng = ZkRng::new(0x0400, b"zk60-opt4-0");
    let mc0 = mask_commit(&[], &ntt12, &mut rng);
    check("0 masks, empty functionals", &mc0, &[], &ntt12);

    // 1 mask: empty functionals, explicit all-zero functional, and non-zero Fp2 functional
    let mut rng = ZkRng::new(0x0401, b"zk60-opt4-1");
    let mc1 = mask_commit(&[(4, 3)], &ntt12, &mut rng);
    check("1 mask, empty functionals", &mc1, &[], &ntt12);
    let l1 = CfsMask::len(4, 3);
    let zero_f = vec![MaskFunctional { terms: vec![(0, vec![Fp2::ZERO; l1])], value: Fp2::ZERO }];
    check("1 mask, all-zero functional", &mc1, &zero_f, &ntt12);
    let w1: Vec<Fp2> = (0..l1)
        .map(|j| Fp2::new(Fp::new(7 * j as u64 + 13), Fp::new(11 * j as u64 + 29)))
        .collect();
    let v1 = w1.iter().zip(mc1.masks[0].coeffs.iter()).fold(Fp2::ZERO, |a, (x, c)| a.add(x.mul(*c)));
    check("1 mask, non-zero Fp2 functional", &mc1, &[MaskFunctional { terms: vec![(0, w1)], value: v1 }], &ntt12);

    // 2 masks: partial (row 1 untouched) and multi-term spanning both rows
    let mut rng = ZkRng::new(0x0402, b"zk60-opt4-2");
    let mc2 = mask_commit(&[(3, 2), (5, 4)], &ntt12, &mut rng);
    let (fs2, _) = functionals(&mc2);
    check("2 masks, only row 0 active", &mc2, &fs2[..1], &ntt12);
    let w2_0: Vec<Fp2> = (0..CfsMask::len(3, 2))
        .map(|j| Fp2::new(Fp::new(crate::field::P - 1 - j as u64), Fp::new(19 * j as u64 + 5)))
        .collect();
    let w2_1: Vec<Fp2> = (0..CfsMask::len(5, 4))
        .map(|j| Fp2::new(Fp::new(31 * j as u64 + 3), Fp::new(crate::field::P - 2 - j as u64)))
        .collect();
    let v2 = w2_0
        .iter()
        .zip(mc2.masks[0].coeffs.iter())
        .chain(w2_1.iter().zip(mc2.masks[1].coeffs.iter()))
        .fold(Fp2::ZERO, |a, (x, c)| a.add(x.mul(*c)));
    let multi_f = vec![
        MaskFunctional { terms: vec![(0, w2_0), (1, w2_1)], value: v2 },
        fs2[1].clone(),
    ];
    check("2 masks, multi-term Fp2 functionals", &mc2, &multi_f, &ntt12);

    // 23-mask W16R2-sized spec (at max_log = 16 as in 8B blocks) with mixed active + untouched rows
    let specs23: Vec<(usize, usize)> = (0..23)
        .map(|s| {
            let n_vars = 10 + (s % 11);
            let deg = 2 + (s % 4);
            (n_vars, deg)
        })
        .collect();
    let mut rng = ZkRng::new(0x0423, b"zk60-opt4-23");
    let mc23 = mask_commit(&specs23, &ntt16, &mut rng);
    let mut fs23 = Vec::new();
    for s in 0..23 {
        if s == 7 || s == 19 {
            continue; // leave two masks completely untouched (all-zero ws[s])
        }
        let (nv, deg) = specs23[s];
        let l = CfsMask::len(nv, deg);
        let w: Vec<Fp2> = (0..l)
            .map(|j| Fp2::new(Fp::new((s as u64 * 97 + j as u64 * 13 + 1) % crate::field::P), Fp::new((s as u64 * 53 + j as u64 * 29 + 7) % crate::field::P)))
            .collect();
        let v = w.iter().zip(mc23.masks[s].coeffs.iter()).fold(Fp2::ZERO, |a, (x, c)| a.add(x.mul(*c)));
        fs23.push(MaskFunctional { terms: vec![(s, w)], value: v });
    }
    // Also add a multi-mask functional combining rows 0, 11, and 22
    let mut terms_m = Vec::new();
    let mut val_m = Fp2::ZERO;
    for &s in &[0usize, 11, 22] {
        let (nv, deg) = specs23[s];
        let l = CfsMask::len(nv, deg);
        let w: Vec<Fp2> = (0..l)
            .map(|j| Fp2::new(Fp::new(crate::field::P - 1 - ((j + s) as u64 % 100)), Fp::new((j as u64 + 1) * (s as u64 + 3))))
            .collect();
        val_m = w.iter().zip(mc23.masks[s].coeffs.iter()).fold(val_m, |a, (x, c)| a.add(x.mul(*c)));
        terms_m.push((s, w));
    }
    fs23.push(MaskFunctional { terms: terms_m, value: val_m });
    check("23-mask W16R2-sized spec (max_log=16)", &mc23, &fs23, &ntt16);
}
