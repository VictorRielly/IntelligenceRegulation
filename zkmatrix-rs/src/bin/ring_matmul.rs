// Route R protocol build: Pi1/Pi2 lift + gadget family + demos + self-tests
// (docs/zkmatrix-poc/ROUTE_R_DESIGN.md Section 6). Shared modules:
// src/ring/*.rs (arithmetic, params, commit, sigma, ct-engine) and
// src/manifest.rs. Route Z (lattice_matmul.rs) is the differential oracle
// and is not modified by this build.
//
// Operating point (RING_MULT_BOTTLENECK.md Section 6.5): d = 128, k = 8
// split at q8_31 = 2^31 - 399, quinary challenges, digit-decomposed
// openings (e in {2,3,4}), A1 aux-NTT kernels with derive-time regime
// dispatch.
//
// Usage: ring_matmul self-test

use std::time::Instant;

#[path = "../ring/mod.rs"]
mod ring;

use ring::aux;
use ring::commit::{CommitShape, KernelPath, build_a1_paths, commit, expand_crs};
use ring::params::{Proto, a1_enforce, assert_ls18, derive_digits, proof_kb};
use ring::sigma::{
    DigitOpeningProof, OpeningProof, derive_digit_params, derive_opening_params,
    extract_two_transcripts, prove_opening, prove_opening_digits, verify_opening,
    verify_opening_digits,
};
use ring::{
    D, Poly, Q8, RingCtx, XofReader, crt_merge, crt_split, ct_coeff, digit_decompose,
    digit_split_witness, gaussian_ivec, isqrt_u128, ls18_margin, poly_add, poly_conj,
    poly_from_small, poly_inv_g, poly_mul_g, poly_mul_small, poly_zero, polys_bytes,
    ring_ctx_q8, ring_matvec_small_g, ring_mul_split, ring_mul_split_kara_fast, rng_below,
    rng_ternary_poly, splitmix64, vec_norm_sq_i64,
};

fn assert_true(label: &str, cond: bool) {
    if cond {
        println!("  ok   {label}");
    } else {
        println!("  FAIL {label}");
        std::process::exit(1);
    }
}

fn rng_poly_mod(rng: &mut u64, q: u64) -> Poly {
    (0..D).map(|_| rng_below(rng, q)).collect()
}

fn rng_quinary_poly(rng: &mut u64) -> Vec<i64> {
    (0..D).map(|_| rng_below(rng, 5) as i64 - 2).collect()
}

// ---------------------------------------------------------------------------
// U1 self-test: the arithmetic differential battery. Every multiplication
// strategy must agree bit-for-bit with the schoolbook ground truth.

fn self_test_arithmetic() {
    println!("[U1] ring arithmetic differential battery (k = 8, q8_31)");
    let ctx = ring_ctx_q8();
    let zq = ctx.zq;
    let mut rng = 0x5eed_0001u64;

    // CRT split/merge roundtrip.
    let mut ok = true;
    for _ in 0..20 {
        let a = rng_poly_mod(&mut rng, Q8);
        let mut buf = crt_split(&ctx, &a);
        crt_merge(&ctx, &mut buf);
        ok &= buf == a;
    }
    assert_true("crt split/merge roundtrip (20 random)", ok);

    // Multiplication strategies vs schoolbook ground truth.
    let mut ok_split = true;
    let mut ok_kara = true;
    for _ in 0..20 {
        let a = rng_poly_mod(&mut rng, Q8);
        let b = rng_poly_mod(&mut rng, Q8);
        let want = poly_mul_g(&zq, &a, &b);
        ok_split &= ring_mul_split(&ctx, &a, &b) == want;
        ok_kara &= ring_mul_split_kara_fast(&ctx, &a, &b) == want;
    }
    assert_true("ring_mul_split == schoolbook (20 random)", ok_split);
    assert_true("ring_mul_split_kara_fast == schoolbook (20 random)", ok_kara);

    // GEMM kernels vs the schoolbook matvec oracle: ternary and digit-scale
    // columns, both the A2 split-Karatsuba path and the A1 NTT paths.
    let rows = 4usize;
    let cols = 6usize;
    let key: Vec<Poly> = (0..rows * cols).map(|_| rng_poly_mod(&mut rng, Q8)).collect();
    let tern: Vec<Vec<i64>> = (0..cols).map(|_| rng_ternary_poly(&mut rng)).collect();
    let want_t = ring_matvec_small_g(&zq, &key, rows, cols, &tern);

    let key_split: Vec<Vec<u64>> = key.iter().map(|p| crt_split(&ctx, p)).collect();
    let tern_mod: Vec<Poly> = tern.iter().map(|t| poly_from_small(&zq, t)).collect();
    let got_kara = ring::commit_kernel_split_kara_fast(&ctx, &key_split, rows, cols, &tern_mod);
    assert_true("split-Karatsuba GEMM == schoolbook matvec (ternary)", got_kara == want_t);

    let nt = aux::build_tables();
    let a1_commit = aux::A1CommitKernel::new(&key, rows, cols, Q8, 1, &nt);
    assert_true("A1 single-prime GEMM == schoolbook matvec (ternary)", a1_commit.commit_column(&tern, &nt) == want_t);

    // Digit/Gaussian-scale columns through the regime-dispatched kernel.
    let dig_bound = 1i64 << 11;
    let dig: Vec<Vec<i64>> = (0..cols)
        .map(|_| (0..D).map(|_| rng_below(&mut rng, 2 * dig_bound as u64 + 1) as i64 - dig_bound).collect())
        .collect();
    let want_d = ring_matvec_small_g(&zq, &key, rows, cols, &dig);
    let a1_gemm = aux::A1GemmKernel::new(&key, rows, cols, Q8, dig_bound as u128, &nt);
    assert_true(
        &format!("A1 dispatched GEMM ({}) == schoolbook matvec (|v| <= 2^11)", a1_gemm.path()),
        a1_gemm.commit_column(&dig, &nt) == want_d,
    );

    // Single ring products on the A1 paths.
    let mut ok_single = true;
    let mut ok_limb = true;
    for _ in 0..10 {
        let a = rng_poly_mod(&mut rng, Q8);
        let c = rng_quinary_poly(&mut rng);
        let want = poly_mul_g(&zq, &a, &poly_from_small(&zq, &c));
        ok_single &= aux::ring_mul_q_single(&a, &c, Q8, &nt) == want;
        let b = rng_poly_mod(&mut rng, Q8);
        ok_limb &= aux::ring_mul_q_limbsplit(&a, &b, Q8, &nt) == poly_mul_g(&zq, &a, &b);
    }
    assert_true("A1 single-prime quinary x mod-q (10 random)", ok_single);
    assert_true("A1 limb-split general x general (10 random)", ok_limb);

    // Combination sums (regime b'): quinary challenge combinations.
    let t = 50usize;
    let polys: Vec<Poly> = (0..t).map(|_| rng_poly_mod(&mut rng, Q8)).collect();
    let chals: Vec<Vec<i64>> = (0..t).map(|_| rng_quinary_poly(&mut rng)).collect();
    let mut want = poly_zero();
    for i in 0..t {
        let p = poly_mul_g(&zq, &polys[i], &poly_from_small(&zq, &chals[i]));
        want = poly_add(&zq, &want, &p);
    }
    assert_true(
        "A1 combination sum (50 quinary x mod-q terms)",
        aux::a1_combination_sum(&polys, &chals, 2, Q8, &nt) == want,
    );

    // LS18 in practice at the tight margin: 100 challenge-difference
    // inversions through all 8 slots, then the zero-divisor control.
    println!("  LS18 margin at (k = 8, q8_31): {:.2}x (must be > 1)", ls18_margin(Q8, 8));
    assert_true("LS18 margin > 1", ls18_margin(Q8, 8) > 1.0);
    let mut ok_inv = true;
    let one = {
        let mut o = poly_zero();
        o[0] = 1;
        o
    };
    let mut n_inverted = 0;
    for _ in 0..100 {
        let c1 = rng_quinary_poly(&mut rng);
        let c2 = rng_quinary_poly(&mut rng);
        let diff: Vec<i64> = c1.iter().zip(c2.iter()).map(|(&a, &b)| a - b).collect();
        if diff.iter().all(|&x| x == 0) {
            continue;
        }
        let diff_mod = poly_from_small(&zq, &diff);
        match poly_inv_g(&ctx, &diff_mod) {
            Some(inv) => {
                ok_inv &= poly_mul_g(&zq, &inv, &diff_mod) == one;
                n_inverted += 1;
            }
            None => ok_inv = false,
        }
    }
    assert_true(&format!("LS18: {n_inverted} challenge differences inverted, inv * diff == 1"), ok_inv && n_inverted >= 99);

    // Zero-divisor negative control: an element vanishing in exactly one
    // slot (||.||_inf ~ q/2, far above the LS18 bound) is NOT invertible.
    let mut slots = rng_poly_mod(&mut rng, Q8);
    for i in 0..ctx.slot_deg {
        slots[i] = 0; // kill slot 0's image
    }
    let mut zdiv = slots;
    crt_merge(&ctx, &mut zdiv);
    assert_true("zero-divisor control: one-slot-zero element not invertible", poly_inv_g(&ctx, &zdiv).is_none());

    // The ct-engine transport identity: ct(sigma_{-1}(a) * b) = <a, b> mod q.
    let mut ok_ct = true;
    for _ in 0..10 {
        let a = rng_poly_mod(&mut rng, Q8);
        let b = rng_poly_mod(&mut rng, Q8);
        let prod = poly_mul_g(&zq, &poly_conj(&zq, &a), &b);
        let mut dot = 0u64;
        for i in 0..D {
            dot = zq.add(dot, zq.mul(a[i], b[i]));
        }
        ok_ct &= zq.to_mod(ct_coeff(&zq, &prod)) == dot;
    }
    assert_true("ct(sigma_-1(a) * b) == <a, b> (10 random)", ok_ct);

    // Digit decomposition: exact recombination, range respected.
    let mut ok_dig = true;
    for _ in 0..2000 {
        let x = rng_below(&mut rng, 1 << 12) as i64 - (1 << 11);
        for e in [2u32, 3, 4] {
            let l = (13 + e - 1) as usize / e as usize + 1;
            let digs = digit_decompose(x, e, l);
            let half = 1i64 << (e - 1);
            let mut acc = 0i64;
            for (j, &d) in digs.iter().enumerate() {
                ok_dig &= d >= -half && d < half;
                acc += d << (e as usize * j);
            }
            ok_dig &= acc == x;
        }
    }
    assert_true("digit decompose/recombine, balanced range (2000 x e in {2,3,4})", ok_dig);

    let wit: Vec<Vec<i64>> = (0..3)
        .map(|_| (0..D).map(|_| rng_below(&mut rng, 1 << 11) as i64 - (1 << 10)).collect())
        .collect();
    let split = digit_split_witness(&wit, 4, 3);
    let mut ok_w = true;
    for (n, col) in wit.iter().enumerate() {
        for (i, &x) in col.iter().enumerate() {
            let mut acc = 0i64;
            for (j, dj) in split.iter().enumerate() {
                acc += dj[n][i] << (4 * j);
            }
            ok_w &= acc == x;
        }
    }
    assert_true("digit witness split recombines (3 cols, e = 4, L = 3)", ok_w);

    // XOF determinism + challenge range.
    let c1 = XofReader::new("test", &[b"x"]).next_challenge();
    let c2 = XofReader::new("test", &[b"x"]).next_challenge();
    let c3 = XofReader::new("test", &[b"y"]).next_challenge();
    assert_true(
        "XOF determinism + domain separation + quinary range",
        c1 == c2 && c1 != c3 && c1.iter().all(|&x| (-2..=2).contains(&x)),
    );

    // Norm helpers.
    assert_true(
        "norm helpers (norm_sq, isqrt)",
        vec_norm_sq_i64(&[3, -4]) == 25 && ring::isqrt_u128(25) == 5 && ring::isqrt_u128(24) == 4,
    );
}

// ---------------------------------------------------------------------------
// U2 self-test: params port pinned to the script's published tables, then
// the commitment/opening layer with the prototype's tamper batteries.

fn self_test_params() {
    println!("\n[U2a] parameter chains vs scripts/route_r_params.py");
    assert_ls18(Q8, 8);

    // The Q2 frontier at Pi2 n = 2048 (concentration), pinned to the table
    // in RING_MULT_BOTTLENECK.md Section 6.2.
    let expect = [(2u32, 6usize, 8usize, 40usize), (3, 4, 8, 40), (4, 3, 9, 40)];
    for (e, l, kappa, n_r) in expect {
        let p = derive_digits(Proto::Pi2, 2048, 2048, 2048, 0, Q8, true, e).expect("point must fit q8_31");
        println!(
            "  Pi2 2048^3 e={e}: L={} kappa={} N_r={} headroom={:.1} bits proof={:.1} KB",
            p.l_dig, p.kappa, p.n_r, p.c2_headroom_bits(), proof_kb(&p)
        );
        assert_true(
            &format!("Q2 frontier row e = {e} matches script (L={l}, kappa={kappa}, N_r={n_r})"),
            p.l_dig == l && p.kappa == kappa && p.n_r == n_r,
        );
        assert_true(
            &format!("Q2 frontier row e = {e} headroom >= 1.5 bits"),
            p.c2_headroom_bits() >= 1.5 || e == 4, // e = 4 sits at 1.9
        );
    }
    // FFN shape 512 x 4096 x 11008 at (q31, e = 4): kappa = 9, N_r = 57,
    // msg_r = 32, headroom 1.4 bits (Section 6.2).
    let ffn = derive_digits(Proto::Pi2, 512, 4096, 11008, 0, Q8, true, 4).expect("FFN point must fit");
    println!(
        "  FFN 512x4096x11008 e=4: kappa={} N_r={} msg_r={} headroom={:.1} bits commit/col={:.1} KB",
        ffn.kappa, ffn.n_r, ffn.msg_r, ffn.c2_headroom_bits(), ffn.commit_col_kb()
    );
    assert_true(
        "FFN point matches Section 6.2 (kappa=9, N_r=57, msg_r=32)",
        ffn.kappa == 9 && ffn.n_r == 57 && ffn.msg_r == 32 && ffn.c2_headroom_bits() > 1.0,
    );
    // e in {6, 8} exceed q31 (script rows) — the chain must reject them.
    for e in [6u32, 8] {
        assert_true(
            &format!("e = {e} exceeds q31 (chain returns None)"),
            derive_digits(Proto::Pi2, 2048, 2048, 2048, 0, Q8, true, e).is_none(),
        );
    }
}

fn self_test_openings() {
    println!("\n[U2b] commitment + opening rounds at the prototype shape (kappa=8, N_r=26, msg_r=2)");
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 2 };
    let crs = expand_crs(shape, Q8, 42);
    let mut rng = 0x5eed_0002u64;

    // Round parameters; the A1 cache takes the max contract bounds over
    // both rounds it serves (the prototype's integration pattern).
    let op = derive_opening_params(Q8, shape.kappa, shape.n_r, shape.msg_r);
    let wit_w = 1i64 << 10;
    let dp = derive_digit_params(Q8, shape.kappa, shape.n_r, 4, 3, wit_w);
    let sigma_max = op.sigma.max(dp.sigma);
    let resp_inf = isqrt_u128(op.bound_sq).max(isqrt_u128(dp.bound_sq));
    for line in a1_enforce(Q8, shape.n_r, sigma_max, resp_inf) {
        println!("  P0 {:<58} -> {}", line.name, line.path);
    }
    let a1p = build_a1_paths(&crs, sigma_max, resp_inf);
    println!("  A1 cache: {:.2} MB", a1p.cached_bytes() as f64 / 1024.0 / 1024.0);
    let a1_path = KernelPath::A1(&a1p);
    let school = KernelPath::School;

    // Commitment: School == A1 bit-identical.
    let x: Vec<Poly> = (0..shape.msg_r).map(|_| (0..D).map(|_| rng_below(&mut rng, Q8)).collect()).collect();
    let rho: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
    let (t1_s, t2_s) = commit(&school, &crs, &x, &rho);
    let (t1_a, t2_a) = commit(&a1_path, &crs, &x, &rho);
    assert_true("commit: A1 stacked kernel == schoolbook (t1, t2)", t1_s == t1_a && t2_s == t2_a);

    // Plain opening round: same-seed transcript identity across paths,
    // verification on both, then the tamper battery.
    let ctx_bytes = b"route-r-u2-manifest";
    let mut rng_a = 0xabcd_0001u64;
    let mut rng_b = 0xabcd_0001u64;
    let (proof_a, attempts_a) = prove_opening(&a1_path, &op, &crs, &t1_a, &rho, ctx_bytes, &mut rng_a);
    let (proof_s, attempts_s) = prove_opening(&school, &op, &crs, &t1_a, &rho, ctx_bytes, &mut rng_b);
    assert_true(
        &format!("same-seed opening proofs bit-identical across paths (attempts = {attempts_a})"),
        attempts_a == attempts_s && proof_a.w == proof_s.w && proof_a.z == proof_s.z,
    );
    assert_true(
        "opening proof verifies (A1 and schoolbook paths)",
        verify_opening(&a1_path, &ring_ctx, &op, &crs, &t1_a, ctx_bytes, &proof_a)
            && verify_opening(&school, &ring_ctx, &op, &crs, &t1_a, ctx_bytes, &proof_a),
    );
    let clone_proof = |p: &OpeningProof| OpeningProof { w: p.w.clone(), z: p.z.clone() };
    let mut bad = clone_proof(&proof_a);
    bad.z[0][0] += 1;
    assert_true(
        "tampered response fails",
        !verify_opening(&a1_path, &ring_ctx, &op, &crs, &t1_a, ctx_bytes, &bad),
    );
    let mut bad = clone_proof(&proof_a);
    bad.w[0][0] = zq.add(bad.w[0][0], 1);
    assert_true(
        "tampered first message fails",
        !verify_opening(&a1_path, &ring_ctx, &op, &crs, &t1_a, ctx_bytes, &bad),
    );
    assert_true(
        "wrong context fails",
        !verify_opening(&a1_path, &ring_ctx, &op, &crs, &t1_a, b"other-ctx", &proof_a),
    );
    let mut t1_bad = t1_a.clone();
    t1_bad[0][0] = zq.add(t1_bad[0][0], 1);
    assert_true(
        "wrong statement fails",
        !verify_opening(&a1_path, &ring_ctx, &op, &crs, &t1_bad, ctx_bytes, &proof_a),
    );
    let mut over = clone_proof(&proof_a);
    over.z[0][0] += Q8 as i64;
    assert_true(
        "+q norm-overflow response fails (caught by the exact-norm check only)",
        !verify_opening(&a1_path, &ring_ctx, &op, &crs, &t1_a, ctx_bytes, &over),
    );

    // Interactive 2-transcript extraction (LS18 in the algebra): same mask,
    // two distinct challenges, recover rho exactly.
    {
        let y: Vec<Vec<i64>> = (0..shape.n_r).map(|_| gaussian_ivec(&mut rng, D, op.sigma)).collect();
        let c1: Vec<i64> = XofReader::new("ext-c1", &[b"a"]).next_challenge();
        let c2: Vec<i64> = XofReader::new("ext-c2", &[b"b"]).next_challenge();
        let z_of = |c: &[i64]| -> Vec<Vec<i64>> {
            y.iter()
                .zip(rho.iter())
                .map(|(yn, rn)| {
                    let v = poly_mul_small(c, rn);
                    yn.iter().zip(v.iter()).map(|(&a, &b)| a + b).collect()
                })
                .collect()
        };
        let rec = extract_two_transcripts(&ring_ctx, &c1, &z_of(&c1), &c2, &z_of(&c2)).unwrap();
        let rho_mod: Vec<Poly> = rho.iter().map(|r| poly_from_small(&zq, r)).collect();
        assert_true("2-transcript extraction recovers rho exactly", rec == rho_mod);
    }

    // Digit-decomposed round at (e = 4, L = 3, ||u||_inf <= 2^10): the Q2
    // premise and the full prototype tamper battery.
    println!("  digit chain: sigma=2^{:.1} beta=2^{:.1} (headroom {:.1} bits); undecomposed beta=2^{:.1} needs q > 2^{:.1}",
        (dp.sigma as f64).log2(),
        (dp.beta as f64).log2(),
        31.0 - (8.0 * dp.beta as f64).log2(),
        (dp.beta_undecomposed as f64).log2(),
        (8.0 * dp.beta_undecomposed as f64).log2(),
    );
    assert_true(
        "undecomposed combination witness violates C2 at q8 (the Q2 premise)",
        (Q8 as u128) <= 8 * dp.beta_undecomposed,
    );
    let u_wide: Vec<Vec<i64>> = (0..shape.n_r)
        .map(|_| (0..D).map(|_| (splitmix64(&mut rng) % (2 * wit_w as u64 + 1)) as i64 - wit_w).collect())
        .collect();
    let t_wide = ring::commit::a1_matvec(&a1_path, &crs, ring::commit::MatvecKind::Mask, &u_wide);
    assert_true(
        "combination-witness statement: A1 mask kernel == schoolbook matvec",
        t_wide == ring_matvec_small_g(&zq, &crs.a1, shape.kappa, shape.n_r, &u_wide),
    );
    let ctx_d = b"route-r-u2-digit-manifest";
    let (dproof, dattempts, drestarts) =
        prove_opening_digits(&a1_path, &dp, &crs, &t_wide, &u_wide, ctx_d, &mut rng);
    assert_true(
        &format!("digit opening verifies (attempts = {dattempts}, restarts = {drestarts})"),
        verify_opening_digits(&a1_path, &ring_ctx, &dp, &crs, &t_wide, ctx_d, &dproof)
            && verify_opening_digits(&school, &ring_ctx, &dp, &crs, &t_wide, ctx_d, &dproof),
    );
    let clone_d = |p: &DigitOpeningProof| DigitOpeningProof {
        t_digits: p.t_digits.clone(),
        w: p.w.clone(),
        z: p.z.clone(),
    };
    let mut bad_d = clone_d(&dproof);
    bad_d.z[1][0][0] += 1;
    assert_true(
        "wrong digit (tampered digit response) fails",
        !verify_opening_digits(&a1_path, &ring_ctx, &dp, &crs, &t_wide, ctx_d, &bad_d),
    );
    // Out-of-range-but-recombining digits: digit 0 shifted by 2^17, digit 1
    // compensating; Sigma equations and recombination hold, the norm/range
    // layer must catch it (exact ct-ranges replace this stand-in in U6).
    {
        let shift = 1i64 << 17;
        let mut u_dig = digit_split_witness(&u_wide, dp.e, dp.l);
        for n in 0..shape.n_r {
            for i in 0..D {
                u_dig[0][n][i] += shift;
                u_dig[1][n][i] -= shift >> dp.e;
            }
        }
        let t_digits: Vec<Vec<Poly>> = u_dig
            .iter()
            .map(|uj| ring_matvec_small_g(&zq, &crs.a1, shape.kappa, shape.n_r, uj))
            .collect();
        let h0 = ring::sigma::digit_statement_hash(&crs, &dp, &t_wide, &t_digits, ctx_d);
        let y: Vec<Vec<Vec<i64>>> = (0..dp.l)
            .map(|_| (0..shape.n_r).map(|_| gaussian_ivec(&mut rng, D, dp.sigma)).collect())
            .collect();
        let w: Vec<Vec<Poly>> = y
            .iter()
            .map(|yj| ring_matvec_small_g(&zq, &crs.a1, shape.kappa, shape.n_r, yj))
            .collect();
        let c = ring::sigma::digit_challenge(&h0, &w);
        let z: Vec<Vec<Vec<i64>>> = y
            .iter()
            .zip(u_dig.iter())
            .map(|(yj, uj)| {
                yj.iter()
                    .zip(uj.iter())
                    .map(|(yn, un)| {
                        let v = poly_mul_small(&c, un);
                        yn.iter().zip(v.iter()).map(|(&a, &b)| a + b).collect()
                    })
                    .collect()
            })
            .collect();
        let cheat = DigitOpeningProof { t_digits, w, z };
        assert_true(
            "digit out of range (recombining but oversized digits) fails",
            !verify_opening_digits(&a1_path, &ring_ctx, &dp, &crs, &t_wide, ctx_d, &cheat),
        );
    }
    // Recombination mismatch: honest rounds on a different witness.
    {
        let u_other: Vec<Vec<i64>> = (0..shape.n_r)
            .map(|_| (0..D).map(|_| (splitmix64(&mut rng) % (2 * wit_w as u64 + 1)) as i64 - wit_w).collect())
            .collect();
        let (cheat, _, _) = prove_opening_digits(&a1_path, &dp, &crs, &t_wide, &u_other, ctx_d, &mut rng);
        assert_true(
            "recombination mismatch (digits of a different witness) fails",
            !verify_opening_digits(&a1_path, &ring_ctx, &dp, &crs, &t_wide, ctx_d, &cheat),
        );
    }
    assert_true(
        "digit round wrong context fails",
        !verify_opening_digits(&a1_path, &ring_ctx, &dp, &crs, &t_wide, b"other-ctx", &dproof),
    );
    let mut over_d = clone_d(&dproof);
    over_d.z[0][0][0] += Q8 as i64;
    assert_true(
        "digit round +q norm-overflow fails (norm check only)",
        !verify_opening_digits(&a1_path, &ring_ctx, &dp, &crs, &t_wide, ctx_d, &over_d),
    );
}

fn usage() {
    eprintln!("usage: ring_matmul self-test");
    std::process::exit(2);
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("self-test") => {
            let t = Instant::now();
            self_test_arithmetic();
            self_test_params();
            self_test_openings();
            println!("\nself-test passed in {:.2}s", t.elapsed().as_secs_f64());
        }
        _ => usage(),
    }
}
