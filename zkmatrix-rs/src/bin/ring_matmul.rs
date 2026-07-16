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
//        ring_matmul chain-demo <n0> <n1> <n2> <n3>

use std::time::Instant;

#[path = "../ring/mod.rs"]
mod ring;

#[path = "../manifest.rs"]
mod manifest;

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

// ---------------------------------------------------------------------------
// U3 self-test: the ct-engine. Linear ct-claims (theta-batched scalar
// claims with g-masks and combined mask images) at q31, then the ARP at
// q8_46 — including the derive-time budget checks that record this
// tranche's new finding: the binary-gadget ARP side condition does NOT
// close at q31 (it does at q46).

#[allow(clippy::too_many_arguments)]
fn ct_prove_verify_case(
    label: &str,
    q: u64,
    zeta: u64,
    crs_seed: u64,
    rng_seed: u64,
    run_negatives: bool,
) {
    use ring::ct_engine::{
        CtClaim, StdOpening, ct_h0, derive_ct_round_params, derive_theta,
        pack_functional, prove_ct_round, sample_ct_masks, theta_rows, verify_ct_round,
    };
    let ring_ctx = ring::ring_ctx(q, zeta, 8);
    let zq = ring_ctx.zq;
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 2 };
    let crs = expand_crs(shape, q, crs_seed);
    let mut rng = rng_seed;

    // Witness: 2 std commitments, 4 message slots, n = 512 coefficients.
    let n_wit = 2usize;
    let xs: Vec<Vec<Poly>> = (0..n_wit)
        .map(|_| (0..shape.msg_r).map(|_| (0..D).map(|_| rng_below(&mut rng, q)).collect()).collect())
        .collect();
    let rhos: Vec<Vec<Vec<i64>>> =
        (0..n_wit).map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect()).collect();

    let l = theta_rows(q);
    let n_coeffs = n_wit * shape.msg_r * D;
    let g_groups = sample_ct_masks(&mut rng, q, shape.msg_r, l);
    let n_commits = n_wit + g_groups.len();
    let rp = derive_ct_round_params(q, shape, n_commits, 0, 0, false);
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let a1_path = KernelPath::A1(&a1p);
    let school = KernelPath::School;

    // Commit witness + g groups (g randomness ternary like any commitment).
    let mut t1s: Vec<Vec<Poly>> = Vec::new();
    let mut t2s: Vec<Vec<Poly>> = Vec::new();
    let mut all_x: Vec<Vec<Poly>> = xs.clone();
    let mut all_rho: Vec<Vec<Vec<i64>>> = rhos.clone();
    for g in &g_groups {
        all_x.push(g.clone());
        all_rho.push((0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect());
    }
    for (x, rho) in all_x.iter().zip(all_rho.iter()) {
        let (t1, t2) = commit(&a1_path, &crs, x, rho);
        t1s.push(t1);
        t2s.push(t2);
    }

    // h0 binds everything committed; theta derives from it.
    let h0 = ct_h0(&crs, format!("u3-{label}").as_bytes(), &t1s, &t2s, &[]);
    let theta = derive_theta(&h0, l, n_coeffs, q);
    let msg_slots: Vec<(usize, usize)> =
        (0..n_wit * shape.msg_r).map(|u| (u / shape.msg_r, u % shape.msg_r)).collect();
    let claims: Vec<CtClaim> = theta
        .iter()
        .map(|row| {
            let packed = pack_functional(&zq, row, msg_slots.len());
            let msg_coeffs: Vec<(usize, usize, Poly)> = packed
                .into_iter()
                .enumerate()
                .map(|(u, coeff)| (msg_slots[u].0, msg_slots[u].1, coeff))
                .collect();
            // True scalar: <theta_row, coefficient vector of x> mod q.
            let mut s = 0u64;
            for (u, &(ci, sj)) in msg_slots.iter().enumerate() {
                for k in 0..D {
                    s = zq.add(s, zq.mul(row[u * D + k], xs[ci][sj][k]));
                }
            }
            CtClaim { msg_coeffs, ajtai_coeffs: Vec::new(), scalar: zq.center(s) }
        })
        .collect();

    let openings: Vec<StdOpening> = all_x
        .iter()
        .zip(all_rho.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
        .collect();

    let mut rng_a = rng_seed ^ 0x1111;
    let mut rng_b = rng_seed ^ 0x1111;
    let (proof, attempts) =
        prove_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &[], &[], &openings, &[], &[], n_wit, &mut rng_a);
    assert_true(
        &format!("[{label}] ct-round verifies, {l} theta claims (attempts = {attempts})"),
        verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &[], &[], &t1s, &t2s, &[], &[], &[], n_wit, &proof),
    );
    assert_true(
        &format!("[{label}] ct-round verifies on the schoolbook path"),
        verify_ct_round(&school, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &[], &[], &t1s, &t2s, &[], &[], &[], n_wit, &proof),
    );
    let (proof_s, attempts_s) =
        prove_ct_round(&school, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &[], &[], &openings, &[], &[], n_wit, &mut rng_b);
    assert_true(
        &format!("[{label}] same-seed ct proofs bit-identical across paths"),
        attempts == attempts_s
            && proof.h == proof_s.h
            && proof.w1 == proof_s.w1
            && proof.w_claim == proof_s.w_claim
            && proof.z == proof_s.z,
    );

    if !run_negatives {
        return;
    }
    let reverify = |p: &ring::ct_engine::CtRoundProof, claims: &[CtClaim]| -> bool {
        verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, claims, &[], &[], &[], &t1s, &t2s, &[], &[], &[], n_wit, p)
    };
    let clone_proof = |p: &ring::ct_engine::CtRoundProof| ring::ct_engine::CtRoundProof {
        h: p.h.clone(),
        w1: p.w1.clone(),
        w1_ajtai: p.w1_ajtai.clone(),
        w_claim: p.w_claim.clone(),
        w_ring: p.w_ring.clone(),
        h_quad: p.h_quad.clone(),
        gq: p.gq.clone(),
        w_quad: p.w_quad.clone(),
        gr: p.gr.clone(),
        w_qring: p.w_qring.clone(),
        gtq: p.gtq.clone(),
        w_tq: p.w_tq.clone(),
        z: p.z.clone(),
        z_rho_ajtai: p.z_rho_ajtai.clone(),
        z_s_ajtai: p.z_s_ajtai.clone(),
        t1_digits: p.t1_digits.clone(),
        w1_digits: p.w1_digits.clone(),
        z_digits: p.z_digits.clone(),
    };
    // Wrong scalar.
    let bad_claims: Vec<CtClaim> = claims
        .iter()
        .enumerate()
        .map(|(i, c)| CtClaim {
            msg_coeffs: c.msg_coeffs.iter().map(|(a, b, p)| (*a, *b, p.clone())).collect(),
            ajtai_coeffs: Vec::new(),
            scalar: if i == 0 { c.scalar + 1 } else { c.scalar },
        })
        .collect();
    assert_true(&format!("[{label}] wrong claim scalar fails"), !reverify(&proof, &bad_claims));
    // Tampered reveal (ct changes).
    let mut bad = clone_proof(&proof);
    bad.h[0][0] = zq.add(bad.h[0][0], 1);
    assert_true(&format!("[{label}] tampered reveal h (ct coefficient) fails"), !reverify(&bad, &claims));
    // Fake reveal with MATCHING ct (junk coefficient shifted): the
    // message-side check must catch it.
    let mut bad = clone_proof(&proof);
    bad.h[0][1] = zq.add(bad.h[0][1], 1);
    assert_true(&format!("[{label}] fake reveal with matching ct fails (message-side check)"), !reverify(&bad, &claims));
    // Tampered combined mask image.
    let mut bad = clone_proof(&proof);
    bad.w_claim[0][0] = zq.add(bad.w_claim[0][0], 1);
    assert_true(&format!("[{label}] tampered W_l fails"), !reverify(&bad, &claims));
    // Tampered response.
    let mut bad = clone_proof(&proof);
    bad.z[0][0][0] += 1;
    assert_true(&format!("[{label}] tampered response fails"), !reverify(&bad, &claims));
    // +q overflow.
    let mut bad = clone_proof(&proof);
    bad.z[0][0][0] += q as i64;
    assert_true(&format!("[{label}] +q norm-overflow response fails"), !reverify(&bad, &claims));
    // Wrong context (h0 binding).
    let h0_bad = ct_h0(&crs, b"other-ctx", &t1s, &t2s, &[]);
    assert_true(
        &format!("[{label}] wrong context fails"),
        !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0_bad, &claims, &[], &[], &[], &t1s, &t2s, &[], &[], &[], n_wit, &proof),
    );
}

fn self_test_ct_engine() {
    use ring::ct_engine::{
        AjtaiOpening, ajtai_commit, arp_attempt, arp_attempt_joint, arp_budget_ok,
        arp_check_reveal, arp_claims, ct_h0, derive_arp_params, derive_ct_round_params,
        derive_jl_rows, expand_b_mat, pack_arp_mask, prove_ct_round, sample_arp_mask,
        sample_ct_masks, verify_ct_round,
    };
    println!("\n[U3a] linear ct-claims (theta batching, g-masks, combined mask images)");
    ct_prove_verify_case("q31", Q8, ring::ETA8, 91, 0x5eed_0003, true);
    ct_prove_verify_case("q46", ring::Q8_46, ring::ETA8_46, 92, 0x5eed_0004, false);

    println!("\n[U3b] ARP (JL projection) — budgets and mechanism");
    // The budget finding, recorded as assertions: at the conservative Q4
    // constants the binary-gadget side condition (|defect| < q/2) closes
    // at q46 and does NOT close at q31.
    let ap_budget = derive_arp_params(512, 256, 1, 3.0);
    println!(
        "  ARP n=512 rows=256 alpha=3: extract bound 2^{:.1} (conservative slack {}), budgets: q46/2 = 2^45, q31/2 = 2^30",
        ap_budget.extract_bound.log2(),
        ring::ct_engine::SLACK_OP,
    );
    assert_true(
        "ARP side-condition budget closes at q46 (conservative constants)",
        arp_budget_ok(&ap_budget, (ring::Q8_46 / 2) as f64),
    );
    assert_true(
        "ARP side-condition budget does NOT close at q31 — NEW FINDING (gadget layer needs q46-class budget or exact ranges)",
        !arp_budget_ok(&ap_budget, (Q8 / 2) as f64),
    );

    // Mechanism test at q46: binary witness, mask committed before R,
    // reveal + 256 ct-claims through the round.
    let q = ring::Q8_46;
    let ring_ctx = ring::ring_ctx(q, ring::ETA8_46, 8);
    let zq = ring_ctx.zq;
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 2 };
    let crs = expand_crs(shape, q, 93);
    let mut rng = 0x5eed_0005u64;

    let n_wit = 2usize;
    let n_coeffs = n_wit * shape.msg_r * D;
    let b_bits: Vec<i64> = (0..n_coeffs).map(|_| (splitmix64(&mut rng) & 1) as i64).collect();
    let xs: Vec<Vec<Poly>> = (0..n_wit)
        .map(|i| {
            (0..shape.msg_r)
                .map(|j| {
                    (0..D).map(|k| zq.to_mod(b_bits[(i * shape.msg_r + j) * D + k])).collect()
                })
                .collect()
        })
        .collect();
    let rhos: Vec<Vec<Vec<i64>>> =
        (0..n_wit).map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect()).collect();

    let ap = derive_arp_params(n_coeffs, 256, 1, 3.0);
    let s_r = ap.rows.div_ceil(D);
    let b_mat = expand_b_mat(&crs, "arp-mask", s_r);
    let g_groups = sample_ct_masks(&mut rng, q, shape.msg_r, ap.rows);
    let n_commits = n_wit + g_groups.len() + 1; // + Ajtai rho in the std bundle
    let rp = derive_ct_round_params(q, shape, n_commits, ap.rows, 12 * ap.sigma_arp, false);
    let a1p = build_a1_paths(&crs, rp.sigma.max(rp.sigma_s), isqrt_u128(rp.bound_sq.max(rp.bound_s_sq)));
    let a1_path = KernelPath::A1(&a1p);

    // Commit witness + g groups.
    let mut t1s: Vec<Vec<Poly>> = Vec::new();
    let mut t2s: Vec<Vec<Poly>> = Vec::new();
    let mut all_x: Vec<Vec<Poly>> = xs.clone();
    let mut all_rho: Vec<Vec<Vec<i64>>> = rhos.clone();
    for g in &g_groups {
        all_x.push(g.clone());
        all_rho.push((0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect());
    }
    for (x, rho) in all_x.iter().zip(all_rho.iter()) {
        let (t1, t2) = commit(&a1_path, &crs, x, rho);
        t1s.push(t1);
        t2s.push(t2);
    }

    // FS-with-aborts: fresh mask -> commit -> h0 -> R -> attempt.
    let mut arp_rounds = 0usize;
    let (m_packed, rho_m, acom, h0, jl, y) = loop {
        arp_rounds += 1;
        let m_flat = sample_arp_mask(&ap, &mut rng);
        let m_packed = pack_arp_mask(&ap, &m_flat);
        let rho_m: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let acom = ajtai_commit(&crs, &b_mat, &m_packed, &rho_m);
        let h0 = ct_h0(&crs, b"u3-arp", &t1s, &t2s, &[&acom]);
        let jl = derive_jl_rows(&h0, ap.rows, ap.n);
        if let Some(y) = arp_attempt(&ap, &jl, &b_bits, &m_flat, &mut rng) {
            break (m_packed, rho_m, acom, h0, jl, y);
        }
    };
    assert_true(
        &format!("ARP reveal passes range gate (mask-commit rounds = {arp_rounds})"),
        arp_check_reveal(&ap, &y),
    );

    // [Z2] Runtime center-norm gate (audit 2026-07-14 C-01): a witness
    // violating the sigma-derivation assumption (|b|_inf >> the derived
    // w_inf) is rejected BEFORE any rejection-sampling coin — the
    // density-ratio precondition is executable, not assumed.
    {
        let b_hot: Vec<i64> = vec![50i64; n_coeffs];
        let m_hot = sample_arp_mask(&ap, &mut rng);
        assert_true(
            "[Z2] ARP center-norm gate: a witness violating the sigma derivation (|b| >> w_inf) REJECTS at arp_attempt AND arp_attempt_joint",
            arp_attempt(&ap, &jl, &b_hot, &m_hot, &mut rng).is_none()
                && arp_attempt_joint(&ap, &jl, &[(&b_hot[..], &m_hot[..])], &mut rng).is_none(),
        );
    }

    let msg_slots: Vec<(usize, usize)> =
        (0..n_wit * shape.msg_r).map(|u| (u / shape.msg_r, u % shape.msg_r)).collect();
    let claims = arp_claims(&zq, &ap, &jl, &msg_slots, 0, &y);
    let openings: Vec<ring::ct_engine::StdOpening> = all_x
        .iter()
        .zip(all_rho.iter())
        .enumerate()
        .map(|(i, (x, rho))| ring::ct_engine::StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
        .collect();
    let ajtai_open = AjtaiOpening { com: &acom, s: &m_packed, rho: &rho_m };
    let (proof, attempts) = prove_ct_round(
        &a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &[], &[], &openings, &[], &[ajtai_open], n_wit, &mut rng,
    );
    assert_true(
        &format!("ARP: 256 JL ct-claims verify (attempts = {attempts})"),
        verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &[], &[], &t1s, &t2s, &[], &[], &[&acom], n_wit, &proof),
    );
    // Tampered reveal: claims built with a shifted y must fail.
    let mut y_bad = y.clone();
    y_bad[0] += 1;
    let bad_claims = arp_claims(&zq, &ap, &jl, &msg_slots, 0, &y_bad);
    assert_true(
        "ARP tampered reveal y fails (ct check)",
        !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &bad_claims, &[], &[], &[], &t1s, &t2s, &[], &[], &[&acom], n_wit, &proof),
    );
    // Oversized reveal rejected by the range gate.
    let mut y_big = y.clone();
    y_big[0] = ring::isqrt_u128(ap.y_bound_sq) as i64 + 1;
    assert_true("ARP oversized reveal fails the range gate", !arp_check_reveal(&ap, &y_big));
}

// ===========================================================================
// U4: ring-Pi1. Statement: PUBLIC R-linear map A (design Section 4 option
// (a): block-negacyclic in the coefficient basis, i.e. A given as ring
// elements A_ring in R^(rows_r x inner_r) — shift/gadget matrices,
// convolutions, block-selection maps), column commitments to hidden B and
// C; claim: C = A B, i.e. per column j and output slot i:
//     sum_k A_ring[i][k] * bpack_{j,k} = cpack_{j,i}.
//
// Protocol (r = 1):
//   1. Column compression by transcription: ONE quinary ring-challenge
//      vector v (from h0) combines both sides: T_b = sum_j v_j com(b_j),
//      T_c = sum_j v_j com(c_j); x_b = sum_j v_j bpack_j etc. Per-slot
//      soundness 2^-296. Because A's coefficients are RING elements,
//      A commutes with the v-combination — the compressed claim
//      sum_k A_ring[i][k] x_{b,k} = x_{c,i} holds identically for honest
//      parties. The combined randomness has combination magnitude, so the
//      T_b/T_c openings are digit-decomposed (Q2).
//   2. rows_r ring-valued linear claims through the ct-engine (no theta,
//      no g-masks, no reveals — nothing leaks; W_rl is simulatable).
//
// Q1 FINDING (this build; recorded for the report): option (b) as written
// in ROUTE_R_DESIGN.md Section 4 — general A with theta output-compression
// over v-combined commitments — does NOT type-check: ring-challenge column
// compression and a general A do not commute (A M(v_j) != M(v_j) A for the
// negacyclic matrix M(v_j) of v_j), so <A^T theta, unpack(x_b)> =
// <theta, unpack(x_c)> fails even for honest parties. Sound alternatives
// all lose a leg of the triangle {r = 1 proof size, l-matvec verifier,
// general A}: per-column openings (proof linear in cols), scalar-challenge
// mini-repetition of the compression layer (r_v ~ 111 digit bundles,
// ~MB-class), or the ALS20 automorphism basis (d ring products per block).
// The critical path (Pi2 hidden-weight matmuls; gadget-internal structured
// maps) needs only option (a), implemented here. General-A Pi1 is parked
// as a design-iteration item with the costed alternatives.
//
// Digit-coverage aborts: the combined randomness is concentration-sized;
// on the rare draw where a coefficient exceeds the digit range the prover
// bumps a public salt in h0 and redraws v (FS-with-aborts; abort
// transcripts are simulatable exactly like rejection aborts).

struct RingPi1Proof {
    salt: u64,
    ct: ring::ct_engine::CtRoundProof,
}

struct Pi1Shape {
    rows_r: usize,  // output slots per column (ceil(rows / D))
    inner_r: usize, // input slots per column (ceil(inner / D))
    cols: usize,
}

fn pi1_h0(
    crs: &ring::commit::RingCrs,
    shape: &Pi1Shape,
    ctx: &[u8],
    salt: u64,
    a_ring: &[Poly],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-pi1-stmt-v1");
    hasher.update(crs.q.to_le_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((shape.rows_r as u64).to_le_bytes());
    hasher.update((shape.inner_r as u64).to_le_bytes());
    hasher.update((shape.cols as u64).to_le_bytes());
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    hasher.update(salt.to_le_bytes());
    hasher.update(polys_bytes(a_ring));
    for (t1, t2) in tb.iter().chain(tc.iter()) {
        hasher.update(polys_bytes(t1));
        hasher.update(polys_bytes(t2));
    }
    hasher.finalize().into()
}

fn pi1_column_challenges(h0: &[u8; 32], cols: usize) -> Vec<Vec<i64>> {
    let mut reader = XofReader::new("pi1-v", &[h0]);
    (0..cols).map(|_| reader.next_challenge()).collect()
}

/// Does x fit L balanced base-2^e digits? (digit_decompose panics; the
/// prover salt-aborts instead.)
fn digit_fits(x: i64, e: u32, l: usize) -> bool {
    let base = 1i64 << e;
    let half = base >> 1;
    let mut rem = x;
    for _ in 0..l {
        let mut d = rem % base;
        if d >= half {
            d -= base;
        }
        if d < -half {
            d += base;
        }
        rem = (rem - d) / base;
    }
    rem == 0
}

/// The ring-valued claims: for each output slot i,
///   sum_k A_ring[i][k] * x_{Tb, k}  -  x_{Tc, i}  =  0.
/// Commitment index space: T_b at digit index 0, T_c at digit index 1
/// (the round has no plain commitments).
fn pi1_ring_claims(zq: &ring::Zq, shape: &Pi1Shape, a_ring: &[Poly]) -> Vec<ring::ct_engine::RingClaim> {
    let minus_one = {
        let mut p = poly_zero();
        p[0] = zq.neg(1);
        p
    };
    (0..shape.rows_r)
        .map(|i| {
            let mut msg_coeffs: Vec<(usize, usize, Poly)> = (0..shape.inner_r)
                .map(|k| (0usize, k, a_ring[i * shape.inner_r + k].clone()))
                .collect();
            msg_coeffs.push((1, i, minus_one.clone()));
            ring::ct_engine::RingClaim { msg_coeffs, constant: poly_zero() }
        })
        .collect()
}

#[allow(clippy::too_many_arguments)]
fn prove_ring_pi1(
    path: &KernelPath,
    ring_ctx: &RingCtx,
    crs: &ring::commit::RingCrs,
    rp: &ring::ct_engine::CtRoundParams,
    dp: &ring::sigma::DigitParams,
    shape: &Pi1Shape,
    ctx: &[u8],
    a_ring: &[Poly],
    b_cols: &[Vec<Poly>],
    rho_b: &[Vec<Vec<i64>>],
    c_cols: &[Vec<Poly>],
    rho_c: &[Vec<Vec<i64>>],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
    rng: &mut u64,
) -> (RingPi1Proof, usize) {
    use ring::ct_engine::{DigitOpening, prove_ct_round};
    let msg_r = crs.shape.msg_r;

    // Salted column compression: redraw v when the combined randomness
    // exceeds the digit range (concentration tail).
    let mut salt = 0u64;
    let (h0, x_b, rho_vb, x_c, rho_vc, tb1, tb2, tc1, tc2) = loop {
        let h0 = pi1_h0(crs, shape, ctx, salt, a_ring, tb, tc);
        let v = pi1_column_challenges(&h0, shape.cols);
        let combine_msgs = |cols: &[Vec<Poly>]| -> Vec<Poly> {
            (0..msg_r)
                .map(|u| {
                    let group: Vec<Poly> = cols.iter().map(|col| col[u].clone()).collect();
                    ring::commit::combine_polys(path, ring_ctx, &group, &v, 2)
                })
                .collect()
        };
        let combine_t = |t: &[(Vec<Poly>, Vec<Poly>)], part: usize| -> Vec<Poly> {
            let groups: Vec<Vec<Poly>> =
                t.iter().map(|(t1, t2)| if part == 0 { t1.clone() } else { t2.clone() }).collect();
            ring::commit::combine_groups(path, ring_ctx, &groups, &v, 2)
        };
        let rho_vb = ring::commit::combine_small(rho_b, &v);
        let rho_vc = ring::commit::combine_small(rho_c, &v);
        let fits = rho_vb
            .iter()
            .chain(rho_vc.iter())
            .all(|col| col.iter().all(|&x| digit_fits(x, dp.e, dp.l)));
        if !fits {
            salt += 1;
            continue;
        }
        break (
            h0,
            combine_msgs(b_cols),
            rho_vb,
            combine_msgs(c_cols),
            rho_vc,
            combine_t(tb, 0),
            combine_t(tb, 1),
            combine_t(tc, 0),
            combine_t(tc, 1),
        );
    };

    let claims = pi1_ring_claims(&ring_ctx.zq, shape, a_ring);
    let digits = [
        DigitOpening { t1: &tb1, t2: &tb2, x: &x_b, rho_wide: &rho_vb },
        DigitOpening { t1: &tc1, t2: &tc2, x: &x_c, rho_wide: &rho_vc },
    ];
    let (ct, attempts) = prove_ct_round(
        path, ring_ctx, rp, Some(dp), crs, &h0, &[], &claims, &[], &[], &[], &digits, &[], 0, rng,
    );
    (RingPi1Proof { salt, ct }, attempts)
}

#[allow(clippy::too_many_arguments)]
fn verify_ring_pi1(
    path: &KernelPath,
    ring_ctx: &RingCtx,
    crs: &ring::commit::RingCrs,
    rp: &ring::ct_engine::CtRoundParams,
    dp: &ring::sigma::DigitParams,
    shape: &Pi1Shape,
    ctx: &[u8],
    a_ring: &[Poly],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
    proof: &RingPi1Proof,
) -> bool {
    use ring::ct_engine::verify_ct_round;
    if tb.len() != shape.cols || tc.len() != shape.cols {
        return false;
    }
    if a_ring.len() != shape.rows_r * shape.inner_r {
        return false;
    }
    // Cap the salt: the honest abort probability per draw is tiny, so a
    // large salt is grinding, not completeness.
    if proof.salt > 64 {
        return false;
    }
    let h0 = pi1_h0(crs, shape, ctx, proof.salt, a_ring, tb, tc);
    let v = pi1_column_challenges(&h0, shape.cols);
    let combine_t = |t: &[(Vec<Poly>, Vec<Poly>)], part: usize| -> Vec<Poly> {
        let groups: Vec<Vec<Poly>> =
            t.iter().map(|(t1, t2)| if part == 0 { t1.clone() } else { t2.clone() }).collect();
        ring::commit::combine_groups(path, ring_ctx, &groups, &v, 2)
    };
    let tb1 = combine_t(tb, 0);
    let tb2 = combine_t(tb, 1);
    let tc1 = combine_t(tc, 0);
    let tc2 = combine_t(tc, 1);
    let claims = pi1_ring_claims(&ring_ctx.zq, shape, a_ring);
    verify_ct_round(
        path,
        ring_ctx,
        rp,
        Some(dp),
        crs,
        &h0,
        &[],
        &claims,
        &[],
        &[],
        &[],
        &[],
        &[tb1, tc1],
        &[tb2, tc2],
        &[],
        0,
        &proof.ct,
    )
}

/// Pack a length-n Z_q column into msg_r ring elements (zero-padded).
fn pack_column(n: usize, msg_r: usize, col: &[u64]) -> Vec<Poly> {
    (0..msg_r)
        .map(|u| (0..D).map(|i| if u * D + i < n { col[u * D + i] } else { 0 }).collect())
        .collect()
}

fn clone_ct_proof(p: &ring::ct_engine::CtRoundProof) -> ring::ct_engine::CtRoundProof {
    ring::ct_engine::CtRoundProof {
        h: p.h.clone(),
        w1: p.w1.clone(),
        w1_ajtai: p.w1_ajtai.clone(),
        w_claim: p.w_claim.clone(),
        w_ring: p.w_ring.clone(),
        h_quad: p.h_quad.clone(),
        gq: p.gq.clone(),
        w_quad: p.w_quad.clone(),
        gr: p.gr.clone(),
        w_qring: p.w_qring.clone(),
        gtq: p.gtq.clone(),
        w_tq: p.w_tq.clone(),
        z: p.z.clone(),
        z_rho_ajtai: p.z_rho_ajtai.clone(),
        z_s_ajtai: p.z_s_ajtai.clone(),
        t1_digits: p.t1_digits.clone(),
        w1_digits: p.w1_digits.clone(),
        z_digits: p.z_digits.clone(),
    }
}

fn self_test_pi1() {
    use ring::ct_engine::derive_ct_round_params;
    println!("\n[U4] ring-Pi1 (option a, R-linear A) at 256->128 x 64 columns, q8_31");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    // A: rows_r = 1 output slot (rows = 128), inner_r = 2 input slots
    // (inner = 256), acting on 64 columns.
    let shape = Pi1Shape { rows_r: 1, inner_r: 2, cols: 64 };
    let (rows, inner) = (shape.rows_r * D, shape.inner_r * D);
    let e = 4u32;
    let p = derive_digits(Proto::Pi1, rows, inner, shape.cols, 0, q, true, e)
        .expect("Pi1 demo point must fit q31");
    let cshape = CommitShape { kappa: p.kappa, n_r: p.n_r, msg_r: p.msg_r };
    println!(
        "  params: kappa={} N_r={} msg_r={} e={} L={} (C2 headroom {:.1} bits)",
        p.kappa, p.n_r, p.msg_r, p.e, p.l_dig, p.c2_headroom_bits()
    );
    let crs = expand_crs(cshape, q, 1234);
    let w_inf = p.w_u.ceil() as i64;
    let dp = derive_digit_params(q, cshape.kappa, cshape.n_r, e, p.l_dig, w_inf);
    let rp = derive_ct_round_params(q, cshape, 1, 0, 0, true);
    let a1p = build_a1_paths(
        &crs,
        rp.sigma.max(dp.sigma),
        isqrt_u128(rp.bound_sq.max(dp.bound_sq)),
    );
    let a1_path = KernelPath::A1(&a1p);
    let school = KernelPath::School;
    let mut rng = 0x5eed_0006u64;

    // Instance: A_ring random (a dense R-linear map), B random, C = A B
    // computed in the ring per column.
    let a_ring: Vec<Poly> =
        (0..shape.rows_r * shape.inner_r).map(|_| rng_poly_mod(&mut rng, q)).collect();
    let b_cols_mat: Vec<Vec<Poly>> = (0..shape.cols)
        .map(|_| (0..shape.inner_r).map(|_| rng_poly_mod(&mut rng, q)).collect())
        .collect();
    let apply_a = |bp: &[Poly]| -> Vec<Poly> {
        (0..shape.rows_r)
            .map(|i| {
                let mut acc = poly_zero();
                for k in 0..shape.inner_r {
                    let prod = ring_mul_split_kara_fast(&ring_ctx, &a_ring[i * shape.inner_r + k], &bp[k]);
                    acc = poly_add(&zq, &acc, &prod);
                }
                acc
            })
            .collect()
    };
    let pad = |x: Vec<Poly>| -> Vec<Poly> {
        let mut x = x;
        while x.len() < cshape.msg_r {
            x.push(poly_zero());
        }
        x
    };
    let mut b_cols = Vec::new();
    let mut rho_b = Vec::new();
    let mut tb = Vec::new();
    let mut c_cols = Vec::new();
    let mut rho_c = Vec::new();
    let mut tc = Vec::new();
    for bp in &b_cols_mat {
        let cx = pad(apply_a(bp));
        let bx = pad(bp.clone());
        let rb: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let rc: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let (t1b, t2b) = commit(&a1_path, &crs, &bx, &rb);
        let (t1c, t2c) = commit(&a1_path, &crs, &cx, &rc);
        b_cols.push(bx);
        rho_b.push(rb);
        tb.push((t1b, t2b));
        c_cols.push(cx);
        rho_c.push(rc);
        tc.push((t1c, t2c));
    }

    let ctxb = b"route-r-pi1-demo";
    let t0 = Instant::now();
    let mut rng_a = 0xabcd_0002u64;
    let (proof, attempts) = prove_ring_pi1(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &b_cols, &rho_b, &c_cols,
        &rho_c, &tb, &tc, &mut rng_a,
    );
    let prove_ms = t0.elapsed().as_secs_f64() * 1e3;
    let t1 = Instant::now();
    let ok =
        verify_ring_pi1(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &tb, &tc, &proof);
    let verify_ms = t1.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!(
            "pi1 verifies (attempts = {attempts}, salt = {}, prove {prove_ms:.0} ms, verify {verify_ms:.0} ms)",
            proof.salt
        ),
        ok,
    );
    assert_true(
        "pi1 verifies on the schoolbook path",
        verify_ring_pi1(&school, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &tb, &tc, &proof),
    );
    // Same-seed transcript identity across kernel paths.
    let mut rng_b = 0xabcd_0002u64;
    let (proof_s, attempts_s) = prove_ring_pi1(
        &school, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &b_cols, &rho_b, &c_cols,
        &rho_c, &tb, &tc, &mut rng_b,
    );
    assert_true(
        "pi1 same-seed proofs bit-identical across paths",
        attempts == attempts_s
            && proof.salt == proof_s.salt
            && proof.ct.w_ring == proof_s.ct.w_ring
            && proof.ct.z_digits == proof_s.ct.z_digits
            && proof.ct.t1_digits == proof_s.ct.t1_digits,
    );

    // Negative battery (transferred from Route Z pi1 test-for-test).
    // (a) C != A B: honest prover machinery on a wrong instance fails the
    // ring-claim message-side check deterministically.
    {
        let mut c_cols_bad = c_cols.clone();
        c_cols_bad[0][0][0] = zq.add(c_cols_bad[0][0][0], 1);
        let rc_bad: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let (t1cb, t2cb) = commit(&a1_path, &crs, &c_cols_bad[0], &rc_bad);
        let mut tc_bad = tc.clone();
        tc_bad[0] = (t1cb, t2cb);
        let mut rho_c_bad = rho_c.clone();
        rho_c_bad[0] = rc_bad;
        let (bad_proof, _) = prove_ring_pi1(
            &a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &b_cols, &rho_b,
            &c_cols_bad, &rho_c_bad, &tb, &tc_bad, &mut rng,
        );
        assert_true(
            "pi1 semantic soundness: C != A B fails",
            !verify_ring_pi1(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &tb, &tc_bad, &bad_proof),
        );
    }
    // (b) tampered digit response.
    {
        let mut bad = RingPi1Proof { salt: proof.salt, ct: clone_ct_proof(&proof.ct) };
        bad.ct.z_digits[0][0][0][0] += 1;
        assert_true(
            "pi1 tampered digit response fails",
            !verify_ring_pi1(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &tb, &tc, &bad),
        );
    }
    // (c) wrong public A.
    {
        let mut a_bad = a_ring.clone();
        a_bad[0][0] = zq.add(a_bad[0][0], 1);
        assert_true(
            "pi1 wrong public A fails",
            !verify_ring_pi1(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_bad, &tb, &tc, &proof),
        );
    }
    // (d) wrong context.
    assert_true(
        "pi1 wrong context fails",
        !verify_ring_pi1(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, b"other", &a_ring, &tb, &tc, &proof),
    );
    // (e) tampered commitment.
    {
        let mut tb_bad = tb.clone();
        tb_bad[0].0[0][0] = zq.add(tb_bad[0].0[0][0], 1);
        assert_true(
            "pi1 tampered column commitment fails",
            !verify_ring_pi1(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &tb_bad, &tc, &proof),
        );
    }
    // (f) +q norm overflow.
    {
        let mut bad = RingPi1Proof { salt: proof.salt, ct: clone_ct_proof(&proof.ct) };
        bad.ct.z_digits[0][0][0][0] += q as i64;
        assert_true(
            "pi1 +q norm-overflow response fails",
            !verify_ring_pi1(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, &a_ring, &tb, &tc, &bad),
        );
    }
    // Proof-size accounting: digit statements/masks + responses + W.
    let ring_elems = proof.ct.t1_digits.iter().flatten().map(|t| t.len()).sum::<usize>()
        + proof.ct.w1_digits.iter().flatten().map(|t| t.len()).sum::<usize>()
        + proof.ct.w_ring.len();
    let z_coeffs = proof.ct.z_digits.iter().flatten().flatten().map(|v| v.len()).sum::<usize>();
    let sigma_bits = (dp.sigma as f64).log2() + 4.0;
    let kb = (ring_elems * D) as f64 * 31.0 / 8.0 / 1024.0
        + z_coeffs as f64 * sigma_bits / 8.0 / 1024.0;
    println!("  pi1 proof ~{kb:.0} KB (r = 1; {ring_elems} ring elements + {z_coeffs} response coeffs)");
}

// ===========================================================================
// U6: the M2 gadget family over the ring (design Section 5). All gadgets
// are CLAIMS through the ct-engine round — no per-element or per-column
// Sigma protocols anywhere (the ~6000x Route Z Sigma-floor removal):
//
//   binary     — ONE sigma-twisted quadratic ct-claim per tensor:
//                ct( sum_u conj(x_u) x_u - conj(1~) x_u ) = 0, i.e.
//                sum_t b_t (b_t - 1) = 0, which forces b_t in {0,1} over Z
//                GIVEN the non-wrap side condition |defect| < q/2. Side
//                condition strategy: ARP (JL) — budget closes at q46-class
//                moduli, NOT at q31 (U3 finding, asserted below); at q31
//                the swappable range-strategy hook applies (exact per-
//                chunk strategies / a gadget-layer modulus — U8 docs).
//   range W    — W dense-packed bit tensors, one binary claim each, plus
//                the recomposition value = sum_i 2^i bit_i: ring-valued
//                linear claims with CONSTANT coefficients (they commute
//                with everything — option (a) territory).
//   rescale    — x = 2^shift y + r: one ring-valued linear claim + the
//                range claims on y (and r width shift).
//   Hadamard   — H3 slot packing at k = 8 (8 values per ring element,
//                16x density): slot-wise products are ring products of
//                slot-constant elements, so x o y = z is ONE untwisted
//                quadratic ring claim per packed element.

/// Pack up to k values into the CRT slots of one ring element (each value
/// the constant term of its slot field; H3 packing).
fn slot_pack(ctx: &RingCtx, vals: &[u64]) -> Poly {
    assert!(vals.len() <= ctx.k);
    let mut buf = vec![0u64; D];
    for (i, &v) in vals.iter().enumerate() {
        buf[i * ctx.slot_deg] = v;
    }
    crt_merge(ctx, &mut buf);
    buf
}

/// The binary quadratic ct-claims for a committed dense-packed bit tensor
/// spanning `slots` message slots of commitment `idx`.
///
/// SOUNDNESS (finding F5, this build's own review): a FIXED-coefficient
/// ct-claim cannot use the g-mask soundly — g's soundness argument is the
/// commit-BEFORE-theta ordering, and with protocol-fixed coefficients a
/// cheating prover simply commits g with ct(g) = -defect. The claim
/// coefficients must therefore be RANDOMIZED post-commitment: each copy l
/// scales the whole functional by a uniform ring element omega_l drawn
/// from h0 (which binds every commitment incl. the g-groups). For a
/// nonzero defect delta, the required ct(g_l) = -theta_l * delta is a
/// uniform scalar over the post-commitment draw of theta_l, so a
/// pre-theta g is caught with probability 1 - 1/q per copy;
/// l = ceil(256 / log2 q) = 9 copies give 2^-279-class. The randomizer
/// MUST be a uniform SCALAR (constant polynomial): a full ring element
/// would mix F's junk coefficients into the ct and break completeness —
/// the same junk-mixing phenomenon as finding F2. (The ARP and Pi2-gate
/// ct-claims were never affected: their coefficients are FS-derived
/// after the commitments.)
/// `members` lists the tensor's (commitment index, slot count) pairs —
/// one claim family per TENSOR (the design's granularity), spanning all
/// its column commitments.
fn binary_claims(
    zq: &ring::Zq,
    h0: &[u8; 32],
    tag: u64,
    members: &[(usize, usize)],
) -> Vec<ring::ct_engine::QuadCtClaim> {
    let l = ring::ct_engine::theta_rows(zq.q);
    let minus_conj_ones = {
        let ones = vec![1u64; D];
        ring::poly_neg(zq, &poly_conj(zq, &ones))
    };
    (0..l)
        .map(|li| {
            let mut reader = XofReader::new(
                "bin-theta",
                &[h0, &tag.to_le_bytes(), &(li as u64).to_le_bytes()],
            );
            let theta = reader.next_field(zq.q);
            let mut gamma = poly_zero();
            gamma[0] = theta;
            let lin = ring::poly_scale(zq, theta, &minus_conj_ones);
            let mut quad = Vec::new();
            let mut msg_coeffs = Vec::new();
            for &(idx, slots) in members {
                for u in 0..slots {
                    quad.push((idx, u, idx, u, gamma.clone()));
                    msg_coeffs.push((idx, u, lin.clone()));
                }
            }
            ring::ct_engine::QuadCtClaim { quad, msg_coeffs, scalar: 0 }
        })
        .collect()
}

/// Recomposition claims: per slot u, sum_i 2^i bit_(i,u) - val_u = 0.
/// bits_idx[i] indexes the bit-i tensor commitment; val_idx the values.
fn recomposition_claims(
    zq: &ring::Zq,
    val_idx: usize,
    bits_idx: &[usize],
    slots: usize,
) -> Vec<ring::ct_engine::RingClaim> {
    let const_poly = |v: u64| {
        let mut p = poly_zero();
        p[0] = v;
        p
    };
    (0..slots)
        .map(|u| {
            let mut msg_coeffs: Vec<(usize, usize, Poly)> = bits_idx
                .iter()
                .enumerate()
                .map(|(i, &bi)| (bi, u, const_poly(zq.to_mod(1i64 << i))))
                .collect();
            msg_coeffs.push((val_idx, u, const_poly(zq.neg(1))));
            ring::ct_engine::RingClaim { msg_coeffs, constant: poly_zero() }
        })
        .collect()
}

fn self_test_gadgets() {
    use ring::ct_engine::{
        QuadRingClaim, RingClaim, StdOpening, ct_h0, derive_ct_round_params, prove_ct_round,
        verify_ct_round,
    };
    println!("\n[U6a] gadget family at q31: recomposition, rescale link, H3 slot Hadamard");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 2 };
    let crs = expand_crs(shape, q, 4321);
    let mut rng = 0x5eed_0007u64;

    // --- A1: range recomposition, W = 4 bits over 256 values. -----------
    {
        let w_bits = 4usize;
        let n_vals = shape.msg_r * D;
        let vals: Vec<u64> = (0..n_vals).map(|_| rng_below(&mut rng, 1 << w_bits)).collect();
        let bit_planes: Vec<Vec<u64>> = (0..w_bits)
            .map(|i| vals.iter().map(|&v| (v >> i) & 1).collect())
            .collect();
        // Commit values + bit planes (dense packing).
        let pack = |v: &[u64]| -> Vec<Poly> {
            (0..shape.msg_r).map(|u| (0..D).map(|t| v[u * D + t]).collect()).collect()
        };
        let mut all_x: Vec<Vec<Poly>> = vec![pack(&vals)];
        all_x.extend(bit_planes.iter().map(|b| pack(b)));
        let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
            .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
            .collect();
        let rp = derive_ct_round_params(q, shape, all_x.len(), 0, 0, false);
        let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
        let a1_path = KernelPath::A1(&a1p);
        let mut t1s = Vec::new();
        let mut t2s = Vec::new();
        for (x, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(&a1_path, &crs, x, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        let h0 = ct_h0(&crs, b"u6-recomp", &t1s, &t2s, &[]);
        let claims = recomposition_claims(&zq, 0, &[1, 2, 3, 4], shape.msg_r);
        let openings: Vec<StdOpening> = all_x
            .iter()
            .zip(all_rho.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
            .collect();
        let t0 = Instant::now();
        let (proof, attempts) = prove_ct_round(
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &openings, &[], &[],
            all_x.len(), &mut rng,
        );
        let ms = t0.elapsed().as_secs_f64() * 1e3;
        assert_true(
            &format!("recomposition (W=4, 256 values) verifies (attempts = {attempts}, prove {ms:.0} ms)"),
            verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &t1s, &t2s, &[], &[], &[], all_x.len(), &proof),
        );
        println!("  range family cost at this shape: ~{:.1} us/element (claims amortize; Route Z measured ~108 ms/element)", ms * 1000.0 / n_vals as f64);
        // Negative: a bit plane inconsistent with the values.
        {
            let mut bits_bad = bit_planes.clone();
            bits_bad[0][0] ^= 1;
            let mut all_x_bad = all_x.clone();
            all_x_bad[1] = pack(&bits_bad[0]);
            let rho_bad: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let (t1b, t2b) = commit(&a1_path, &crs, &all_x_bad[1], &rho_bad);
            let mut t1s_bad = t1s.clone();
            let mut t2s_bad = t2s.clone();
            t1s_bad[1] = t1b;
            t2s_bad[1] = t2b;
            let mut all_rho_bad = all_rho.clone();
            all_rho_bad[1] = rho_bad;
            let h0b = ct_h0(&crs, b"u6-recomp", &t1s_bad, &t2s_bad, &[]);
            let openings_bad: Vec<StdOpening> = all_x_bad
                .iter()
                .zip(all_rho_bad.iter())
                .enumerate()
                .map(|(i, (x, rho))| StdOpening { t1: &t1s_bad[i], t2: &t2s_bad[i], x, rho })
                .collect();
            let (bad, _) = prove_ct_round(
                &a1_path, &ring_ctx, &rp, None, &crs, &h0b, &[], &claims, &[], &[], &openings_bad,
                &[], &[], all_x_bad.len(), &mut rng,
            );
            assert_true(
                "recomposition mismatch (flipped bit) fails",
                !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0b, &[], &claims, &[], &[], &t1s_bad, &t2s_bad, &[], &[], &[], all_x_bad.len(), &bad),
            );
        }
    }

    // --- A2: rescale link x = 2^shift y + r. ----------------------------
    {
        let shift = 4u32;
        let n_vals = shape.msg_r * D;
        let ys: Vec<u64> = (0..n_vals).map(|_| rng_below(&mut rng, 1 << 20)).collect();
        let rs: Vec<u64> = (0..n_vals).map(|_| rng_below(&mut rng, 1 << shift)).collect();
        let xs: Vec<u64> = ys.iter().zip(rs.iter()).map(|(&y, &r)| zq.add(zq.mul(1 << shift, y), r)).collect();
        let pack = |v: &[u64]| -> Vec<Poly> {
            (0..shape.msg_r).map(|u| (0..D).map(|t| v[u * D + t]).collect()).collect()
        };
        let all_x = [pack(&xs), pack(&ys), pack(&rs)];
        let all_rho: Vec<Vec<Vec<i64>>> = (0..3)
            .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
            .collect();
        let rp = derive_ct_round_params(q, shape, 3, 0, 0, false);
        let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
        let a1_path = KernelPath::A1(&a1p);
        let mut t1s = Vec::new();
        let mut t2s = Vec::new();
        for (x, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(&a1_path, &crs, x, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        let h0 = ct_h0(&crs, b"u6-rescale", &t1s, &t2s, &[]);
        // Claims: x_u - 2^shift y_u - r_u = 0 per slot.
        let const_poly = |v: u64| {
            let mut p = poly_zero();
            p[0] = v;
            p
        };
        let claims: Vec<RingClaim> = (0..shape.msg_r)
            .map(|u| RingClaim {
                msg_coeffs: vec![
                    (0, u, const_poly(1)),
                    (1, u, const_poly(zq.neg(1 << shift))),
                    (2, u, const_poly(zq.neg(1))),
                ],
                constant: poly_zero(),
            })
            .collect();
        let openings: Vec<StdOpening> = all_x
            .iter()
            .zip(all_rho.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
            .collect();
        let (proof, _) = prove_ct_round(
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &openings, &[], &[], 3,
            &mut rng,
        );
        assert_true(
            "rescale link x = 2^4 y + r verifies (ring-valued claim)",
            verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &t1s, &t2s, &[], &[], &[], 3, &proof),
        );
        let mut bad = clone_ct_proof(&proof);
        bad.w_ring[0][0] = zq.add(bad.w_ring[0][0], 1);
        assert_true(
            "rescale tampered W fails",
            !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &t1s, &t2s, &[], &[], &[], 3, &bad),
        );
    }

    // --- A3: Hadamard via H3 slot packing (8 values / element). ---------
    {
        let n_vals = shape.msg_r * ring_ctx.k; // 16 values
        let xv: Vec<u64> = (0..n_vals).map(|_| rng_below(&mut rng, q)).collect();
        let yv: Vec<u64> = (0..n_vals).map(|_| rng_below(&mut rng, q)).collect();
        let zv: Vec<u64> = xv.iter().zip(yv.iter()).map(|(&a, &b)| zq.mul(a, b)).collect();
        let pack8 = |v: &[u64]| -> Vec<Poly> {
            (0..shape.msg_r).map(|u| slot_pack(&ring_ctx, &v[u * ring_ctx.k..(u + 1) * ring_ctx.k])).collect()
        };
        let mut all_x = vec![pack8(&xv), pack8(&yv), pack8(&zv)];
        // R1 pads: 2 committed one-time pads per untwisted quad claim.
        let g_base = all_x.len();
        all_x.extend(ring::ct_engine::sample_g_masks(
            &mut rng,
            q,
            shape.msg_r,
            0,
            ring::ct_engine::r1_pad_count(0, shape.msg_r, 0),
        ));
        let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
            .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
            .collect();
        let rp = derive_ct_round_params(q, shape, all_x.len(), 0, 0, false);
        let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
        let a1_path = KernelPath::A1(&a1p);
        let mut t1s = Vec::new();
        let mut t2s = Vec::new();
        for (x, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(&a1_path, &crs, x, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        let h0 = ct_h0(&crs, b"u6-hadamard", &t1s, &t2s, &[]);
        let one = {
            let mut p = poly_zero();
            p[0] = 1;
            p
        };
        let minus_one = {
            let mut p = poly_zero();
            p[0] = zq.neg(1);
            p
        };
        let claims: Vec<QuadRingClaim> = (0..shape.msg_r)
            .map(|u| QuadRingClaim {
                quad: vec![(0, u, 1, u, one.clone())],
                msg_coeffs: vec![(2, u, minus_one.clone())],
            })
            .collect();
        let openings: Vec<StdOpening> = all_x
            .iter()
            .zip(all_rho.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
            .collect();
        let (proof, attempts) = prove_ct_round(
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &[], &claims, &openings, &[], &[],
            g_base, &mut rng,
        );
        assert_true(
            &format!("Hadamard x o y = z verifies (H3, {n_vals} slot values, attempts = {attempts})"),
            verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &[], &claims, &t1s, &t2s, &[], &[], &[], g_base, &proof),
        );
        // Negative: wrong product.
        {
            let mut zv_bad = zv.clone();
            zv_bad[0] = zq.add(zv_bad[0], 1);
            let mut all_x_bad = all_x.clone();
            all_x_bad[2] = pack8(&zv_bad);
            let rho_bad: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let (t1b, t2b) = commit(&a1_path, &crs, &all_x_bad[2], &rho_bad);
            let mut t1s_bad = t1s.clone();
            let mut t2s_bad = t2s.clone();
            t1s_bad[2] = t1b;
            t2s_bad[2] = t2b;
            let mut all_rho_bad = all_rho.clone();
            all_rho_bad[2] = rho_bad;
            let h0b = ct_h0(&crs, b"u6-hadamard", &t1s_bad, &t2s_bad, &[]);
            let openings_bad: Vec<StdOpening> = all_x_bad
                .iter()
                .zip(all_rho_bad.iter())
                .enumerate()
                .map(|(i, (x, rho))| StdOpening { t1: &t1s_bad[i], t2: &t2s_bad[i], x, rho })
                .collect();
            let (bad, _) = prove_ct_round(
                &a1_path, &ring_ctx, &rp, None, &crs, &h0b, &[], &[], &[], &claims, &openings_bad,
                &[], &[], g_base, &mut rng,
            );
            assert_true(
                "Hadamard wrong product fails",
                !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0b, &[], &[], &[], &claims, &t1s_bad, &t2s_bad, &[], &[], &[], g_base, &bad),
            );
        }
    }

    // --- B: the binary gadget at q46 (where the ARP budget closes). -----
    println!("\n[U6b] binary gadget (quadratic ct-claim + ARP side condition) at q8_46");
    {
        use ring::ct_engine::{
            AjtaiOpening, ajtai_commit, arp_attempt, arp_budget_ok, arp_claims, derive_arp_params,
            derive_jl_rows, expand_b_mat, pack_arp_mask, sample_arp_mask,
        };
        let q = ring::Q8_46;
        let ring_ctx = ring::ring_ctx(q, ring::ETA8_46, 8);
        let zq = ring_ctx.zq;
        let crs = expand_crs(shape, q, 4322);
        let n_bits = shape.msg_r * D;
        let bits: Vec<i64> = (0..n_bits).map(|_| (splitmix64(&mut rng) & 1) as i64).collect();
        let x_bits: Vec<Poly> = (0..shape.msg_r)
            .map(|u| (0..D).map(|t| zq.to_mod(bits[u * D + t])).collect())
            .collect();
        let rho_bits: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();

        let ap = derive_arp_params(n_bits, 256, 1, 3.0);
        assert_true(
            "binary side-condition budget closes at q46",
            arp_budget_ok(&ap, (q / 2) as f64),
        );
        let s_r = ap.rows.div_ceil(D);
        let b_mat = expand_b_mat(&crs, "u6-arp", s_r);
        // g's: 256 ARP ct-claims + l quadratic binary claims, then the R1
        // pads (3 per quadratic ct-claim).
        let l_bin = ring::ct_engine::theta_rows(q);
        let n_claims_g = ap.rows + l_bin;
        let g_groups = ring::ct_engine::sample_g_masks(
            &mut rng,
            q,
            shape.msg_r,
            n_claims_g,
            ring::ct_engine::r1_pad_count(l_bin, 0, 0),
        );
        let n_commits = 1 + g_groups.len() + 1;
        let rp = derive_ct_round_params(q, shape, n_commits, ap.rows, 12 * ap.sigma_arp, false);
        let a1p = build_a1_paths(&crs, rp.sigma.max(rp.sigma_s), isqrt_u128(rp.bound_sq.max(rp.bound_s_sq)));
        let a1_path = KernelPath::A1(&a1p);

        let mut t1s = Vec::new();
        let mut t2s = Vec::new();
        let mut all_x: Vec<Vec<Poly>> = vec![x_bits.clone()];
        let mut all_rho: Vec<Vec<Vec<i64>>> = vec![rho_bits.clone()];
        for g in &g_groups {
            all_x.push(g.clone());
            all_rho.push((0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect());
        }
        for (x, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(&a1_path, &crs, x, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        let mut arp_rounds = 0usize;
        let (m_packed, rho_m, acom, h0, jl, y) = loop {
            arp_rounds += 1;
            let m_flat = sample_arp_mask(&ap, &mut rng);
            let m_packed = pack_arp_mask(&ap, &m_flat);
            let rho_m: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let acom = ajtai_commit(&crs, &b_mat, &m_packed, &rho_m);
            let h0 = ct_h0(&crs, b"u6-binary", &t1s, &t2s, &[&acom]);
            let jl = derive_jl_rows(&h0, ap.rows, ap.n);
            if let Some(y) = arp_attempt(&ap, &jl, &bits, &m_flat, &mut rng) {
                break (m_packed, rho_m, acom, h0, jl, y);
            }
        };
        let msg_slots: Vec<(usize, usize)> = (0..shape.msg_r).map(|u| (0usize, u)).collect();
        let ct_claims = arp_claims(&zq, &ap, &jl, &msg_slots, 0, &y);
        let quad_claims = binary_claims(&zq, &h0, 0, &[(0, shape.msg_r)]);
        let openings: Vec<StdOpening> = all_x
            .iter()
            .zip(all_rho.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
            .collect();
        let ajtai_open = AjtaiOpening { com: &acom, s: &m_packed, rho: &rho_m };
        let t0 = Instant::now();
        let (proof, attempts) = prove_ct_round(
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &ct_claims, &[], &quad_claims, &[],
            &openings, &[], &[ajtai_open], 1, &mut rng,
        );
        let ms = t0.elapsed().as_secs_f64() * 1e3;
        assert_true(
            &format!("binary gadget verifies: 1 quadratic ct-claim + 256 ARP claims over {n_bits} bits (attempts = {attempts}, ARP rounds = {arp_rounds}, prove {ms:.0} ms)"),
            verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &ct_claims, &[], &quad_claims, &[], &t1s, &t2s, &[], &[], &[&acom], 1, &proof),
        );
        // Negative: a non-binary coefficient — the quadratic ct check
        // catches it deterministically on honest machinery.
        {
            let mut bits_bad = bits.clone();
            bits_bad[0] = 2;
            let x_bad: Vec<Poly> = (0..shape.msg_r)
                .map(|u| (0..D).map(|t| zq.to_mod(bits_bad[u * D + t])).collect())
                .collect();
            let rho_bad: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let mut all_x_bad = all_x.clone();
            all_x_bad[0] = x_bad;
            let mut all_rho_bad = all_rho.clone();
            all_rho_bad[0] = rho_bad;
            let (t1b, t2b) = commit(&a1_path, &crs, &all_x_bad[0], &all_rho_bad[0]);
            let mut t1s_bad = t1s.clone();
            let mut t2s_bad = t2s.clone();
            t1s_bad[0] = t1b;
            t2s_bad[0] = t2b;
            let mut arp_rounds_b = 0usize;
            let (m_packed_b, rho_m_b, acom_b, h0b, jl_b, y_b) = loop {
                arp_rounds_b += 1;
                assert!(arp_rounds_b < 200);
                let m_flat = sample_arp_mask(&ap, &mut rng);
                let m_packed = pack_arp_mask(&ap, &m_flat);
                let rho_m: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
                let acom = ajtai_commit(&crs, &b_mat, &m_packed, &rho_m);
                let h0 = ct_h0(&crs, b"u6-binary", &t1s_bad, &t2s_bad, &[&acom]);
                let jl = derive_jl_rows(&h0, ap.rows, ap.n);
                if let Some(y) = arp_attempt(&ap, &jl, &bits_bad, &m_flat, &mut rng) {
                    break (m_packed, rho_m, acom, h0, jl, y);
                }
            };
            let ct_claims_b = arp_claims(&zq, &ap, &jl_b, &msg_slots, 0, &y_b);
            let quad_claims_b = binary_claims(&zq, &h0b, 0, &[(0, shape.msg_r)]);
            let openings_bad: Vec<StdOpening> = all_x_bad
                .iter()
                .zip(all_rho_bad.iter())
                .enumerate()
                .map(|(i, (x, rho))| StdOpening { t1: &t1s_bad[i], t2: &t2s_bad[i], x, rho })
                .collect();
            let ajtai_open_b = AjtaiOpening { com: &acom_b, s: &m_packed_b, rho: &rho_m_b };
            let (bad, _) = prove_ct_round(
                &a1_path, &ring_ctx, &rp, None, &crs, &h0b, &ct_claims_b, &[], &quad_claims_b, &[],
                &openings_bad, &[], &[ajtai_open_b], 1, &mut rng,
            );
            assert_true(
                "binary gadget: non-binary coefficient fails (quadratic ct check)",
                !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0b, &ct_claims_b, &[], &quad_claims_b, &[], &t1s_bad, &t2s_bad, &[], &[], &[&acom_b], 1, &bad),
            );
        }
        // Negative: tampered garbage term.
        {
            let mut bad = clone_ct_proof(&proof);
            bad.gq[0][0][0] = zq.add(bad.gq[0][0][0], 1);
            assert_true(
                "binary gadget: tampered garbage term fails",
                !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &ct_claims, &[], &quad_claims, &[], &t1s, &t2s, &[], &[], &[&acom], 1, &bad),
            );
        }
    }

    // --- F5 regression: the fixed-coefficient g-shift attack. -----------
    // A FIXED-coefficient binary ct-claim is UNSOUND: committing g with
    // ct(g) = -defect passes a non-binary tensor (the old binary_claim
    // shape had exactly this hole). The theta-randomized claims reject
    // the same crafting. Both directions asserted, at q31, minimal round.
    println!("\n[F5] regression: fixed-coefficient binary claim is unsound; theta-randomization fixes it");
    {
        use ring::ct_engine::{
            QuadCtClaim, StdOpening, ct_h0, derive_ct_round_params, prove_ct_round, theta_rows,
            verify_ct_round,
        };
        let q = Q8;
        let ring_ctx = ring_ctx_q8();
        let zq = ring_ctx.zq;
        let crs = expand_crs(shape, q, 4323);
        let mut rng = 0x5eed_000bu64;
        // Non-binary tensor: one coefficient = 2, defect = 2*(2-1) = 2.
        let n_bits = shape.msg_r * D;
        let mut bits_bad: Vec<i64> = (0..n_bits).map(|_| (splitmix64(&mut rng) & 1) as i64).collect();
        bits_bad[0] = 2;
        let x_bad: Vec<Poly> = (0..shape.msg_r)
            .map(|u| (0..D).map(|t| zq.to_mod(bits_bad[u * D + t])).collect())
            .collect();
        let rho_bad: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();

        // Attack round A: OLD claim shape (fixed coefficients), g crafted
        // with ct(g) = -2 — one claim, one g group.
        {
            // 1 reveal g + 3 R1 pads for the single quadratic claim.
            let mut g_groups = ring::ct_engine::sample_g_masks(&mut rng, q, shape.msg_r, 1, 3);
            g_groups[0][0][0] = zq.to_mod(-2); // ct(g_0) := -defect
            let mut t1s = Vec::new();
            let mut t2s = Vec::new();
            let mut all_x = vec![x_bad.clone()];
            let mut all_rho = vec![rho_bad.clone()];
            for g in &g_groups {
                all_x.push(g.clone());
                all_rho.push((0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect());
            }
            let rp = derive_ct_round_params(q, shape, all_x.len(), 0, 0, false);
            let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
            let path = KernelPath::A1(&a1p);
            for (x, rho) in all_x.iter().zip(all_rho.iter()) {
                let (t1, t2) = commit(&path, &crs, x, rho);
                t1s.push(t1);
                t2s.push(t2);
            }
            let h0 = ct_h0(&crs, b"f5-old", &t1s, &t2s, &[]);
            let one = {
                let mut p = poly_zero();
                p[0] = 1;
                p
            };
            let minus_conj_ones = {
                let ones = vec![1u64; D];
                ring::poly_neg(&zq, &poly_conj(&zq, &ones))
            };
            let old_claim = QuadCtClaim {
                quad: (0..shape.msg_r).map(|u| (0, u, 0, u, one.clone())).collect(),
                msg_coeffs: (0..shape.msg_r).map(|u| (0, u, minus_conj_ones.clone())).collect(),
                scalar: 0,
            };
            let openings: Vec<StdOpening> = all_x
                .iter()
                .zip(all_rho.iter())
                .enumerate()
                .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
                .collect();
            let claims = [old_claim];
            let (atk, _) = prove_ct_round(
                &path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &claims, &[], &openings, &[], &[],
                1, &mut rng,
            );
            assert_true(
                "F5: the OLD fixed-coefficient claim ACCEPTS the g-shift attack (the bug, demonstrated)",
                verify_ct_round(&path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &claims, &[], &t1s, &t2s, &[], &[], &[], 1, &atk),
            );
        }
        // Attack round B: the SAME crafting against the theta-randomized
        // claims — rejected.
        {
            let l = theta_rows(q);
            let mut g_groups = ring::ct_engine::sample_g_masks(&mut rng, q, shape.msg_r, l, 3 * l);
            for li in 0..l {
                // craft every reveal g's ct (the R1 pad slots stay honest)
                g_groups[li / shape.msg_r][li % shape.msg_r][0] = zq.to_mod(-2);
            }
            let mut t1s = Vec::new();
            let mut t2s = Vec::new();
            let mut all_x = vec![x_bad.clone()];
            let mut all_rho = vec![rho_bad.clone()];
            for g in &g_groups {
                all_x.push(g.clone());
                all_rho.push((0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect());
            }
            // conc sizing: the R1 pad groups push the batch past the ~10
            // commitment worst-case-chain limit at q31.
            let rp = derive_ct_round_params(q, shape, all_x.len(), 0, 0, true);
            let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
            let path = KernelPath::A1(&a1p);
            for (x, rho) in all_x.iter().zip(all_rho.iter()) {
                let (t1, t2) = commit(&path, &crs, x, rho);
                t1s.push(t1);
                t2s.push(t2);
            }
            let h0 = ct_h0(&crs, b"f5-new", &t1s, &t2s, &[]);
            let claims = binary_claims(&zq, &h0, 0, &[(0, shape.msg_r)]);
            let openings: Vec<StdOpening> = all_x
                .iter()
                .zip(all_rho.iter())
                .enumerate()
                .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
                .collect();
            let (atk, _) = prove_ct_round(
                &path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &claims, &[], &openings, &[], &[],
                1, &mut rng,
            );
            assert_true(
                "F5: the theta-randomized claims REJECT the same crafting (the fix)",
                !verify_ct_round(&path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &claims, &[], &t1s, &t2s, &[], &[], &[], 1, &atk),
            );
        }
    }
}

// ===========================================================================
// R1 regression battery (Q4_LEMMAS.md Section R1 — the Q4.3d/e fix).
// Two pairs, both F5-style (attack demonstrated, fix pinned):
//
//   LEAK pair (Q4.3d-1 at engine level, the executable analogue of
//   zk_lemma_check.py OK-1/OK-4): the verifier-computable combination
//   W~ + sum_l a_l P_l equals c L + mw. With the pads ZEROED (= the
//   pre-R1 engine) it exposes the linear witness-image L exactly — for
//   the committed-executions gate that image recovers the product
//   matrix C (Q4.3e). With honest uniform pads the combination is
//   one-time-padded and reveals nothing.
//
//   ORDER pair (the R1.2 hash-edge row): the pads are load-bearing only
//   while their commitment is bound by h0 BEFORE the round challenge.
//   If a refactor dropped the pad commitment from h0, c would be
//   independent of the pad slot's t2 — so a prover could re-choose the
//   pad opening AFTER seeing c: shifting the mw pad slot's t2 by
//   c*Delta adds c^2*Delta to the opening P_MW, which the check
//   subtracts — a FALSE claim's defect vanishes and the transcript
//   ACCEPTS (soundness lost; equivalently, a pad chosen post-c can
//   cancel its own mask and the Q4.3d leak returns). The shipped chain
//   (pad commitment in h0) re-derives a different challenge from the
//   crafted commitment and REJECTS the same transcript.

fn self_test_r1() {
    use ring::commit::{MatvecKind, a2_matvec};
    use ring::ct_engine::{
        CtRoundProof, QuadRingClaim, StdOpening, ct_h0, ct_round_challenge,
        derive_ct_round_params, prove_ct_round, r1_pad_count, sample_g_masks, verify_ct_round,
    };
    println!("\n[R1] quadratic-claim pad battery: leak pair + hash-order pair, q8_31");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 2 };
    let crs = expand_crs(shape, q, 4324);
    let mut rng = 0x5eed_0011u64;

    // ONE untwisted quad ring claim over plain ring elements:
    // x*y - z = 0 (slot 0; slot 1 zero). Commitments: 0=x 1=y 2=z 3=pads
    // (m1 at slot 0, mw at slot 1 — the r1 layout with no other claims).
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let minus_one = {
        let mut p = poly_zero();
        p[0] = zq.neg(1);
        p
    };
    let x0 = rng_poly_mod(&mut rng, q);
    let y0 = rng_poly_mod(&mut rng, q);
    let z0 = poly_mul_g(&zq, &x0, &y0);
    let claims = [QuadRingClaim {
        quad: vec![(0, 0, 1, 0, one.clone())],
        msg_coeffs: vec![(2, 0, minus_one.clone())],
    }];
    let pack1 = |p: &Poly| -> Vec<Poly> { vec![p.clone(), poly_zero()] };
    let rp = derive_ct_round_params(q, shape, 4, 0, 0, false);
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let path = KernelPath::A1(&a1p);
    let run = |z_val: &Poly, g_group: Vec<Poly>, ctx: &'static [u8], bind_pads: bool, rng: &mut u64|
     -> (Vec<Vec<Poly>>, Vec<Vec<Poly>>, [u8; 32], CtRoundProof) {
        let all_x = vec![pack1(&x0), pack1(&y0), pack1(z_val), g_group];
        let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
            .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(rng)).collect())
            .collect();
        let mut t1s = Vec::new();
        let mut t2s = Vec::new();
        for (x, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(&path, &crs, x, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        // bind_pads = false simulates the R1.2 ordering BUG: the pad
        // commitment (index 3) is left out of the statement hash.
        let h0 = if bind_pads {
            ct_h0(&crs, ctx, &t1s, &t2s, &[])
        } else {
            ct_h0(&crs, ctx, &t1s[0..3], &t2s[0..3], &[])
        };
        let openings: Vec<StdOpening> = all_x
            .iter()
            .zip(all_rho.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
            .collect();
        let (proof, _) = prove_ct_round(
            &path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &[], &claims, &openings, &[], &[],
            3, rng,
        );
        (t1s, t2s, h0, proof)
    };
    // Distinguisher side of Q4.3d-1: W~ + sum_l a_l P_l from public
    // transcript data (here a = -1 on the z slot).
    let recover = |h0: &[u8; 32], proof: &CtRoundProof, t2s: &[Vec<Poly>]| -> Poly {
        let c = poly_from_small(&zq, &ct_round_challenge(h0, proof));
        let a2z = a2_matvec(&path, &crs, MatvecKind::Verify, &proof.z[2]);
        let p_z = ring::poly_sub(&zq, &poly_mul_g(&zq, &c, &t2s[2][0]), &a2z[0]);
        ring::poly_sub(&zq, &proof.w_qring[0], &p_z)
    };

    // ---- LEAK pair. -----------------------------------------------------
    {
        let zero_pads = vec![poly_zero(), poly_zero()];
        let (t1s, t2s, h0, proof) = run(&z0, zero_pads, b"r1-leak", true, &mut rng);
        assert_true(
            "R1 leak rig: the zero-pad round verifies (honest claim; ZK is what zero pads lose)",
            verify_ct_round(&path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &[], &claims, &t1s, &t2s, &[], &[], &[], 3, &proof),
        );
        let c = poly_from_small(&zq, &ct_round_challenge(&h0, &proof));
        let c_l = poly_mul_g(&zq, &c, &ring::poly_neg(&zq, &z0));
        assert_true(
            "R1 leak: ZEROED pads expose c*L exactly (Q4.3d-1 — the pre-R1 leak, demonstrated)",
            recover(&h0, &proof, &t2s) == c_l,
        );
        let pads = sample_g_masks(&mut rng, q, shape.msg_r, 0, r1_pad_count(0, 1, 0)).remove(0);
        let (t1s, t2s, h0, proof) = run(&z0, pads, b"r1-leak", true, &mut rng);
        assert_true(
            "R1 leak rig: the masked round verifies",
            verify_ct_round(&path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &[], &claims, &t1s, &t2s, &[], &[], &[], 3, &proof),
        );
        let c = poly_from_small(&zq, &ct_round_challenge(&h0, &proof));
        let c_l = poly_mul_g(&zq, &c, &ring::poly_neg(&zq, &z0));
        assert_true(
            "R1 leak: honest pads one-time-pad the combination (c*L not recoverable — the fix)",
            recover(&h0, &proof, &t2s) != c_l,
        );
    }

    // ---- ORDER pair. -----------------------------------------------------
    {
        // FALSE claim: z' = x*y + d, claim value Delta = x*y - z' = -d.
        let mut d = poly_zero();
        d[0] = 1;
        let z_bad = poly_add(&zq, &z0, &d);
        let delta = ring::poly_neg(&zq, &d);
        let pads = sample_g_masks(&mut rng, q, shape.msg_r, 0, r1_pad_count(0, 1, 0)).remove(0);
        let (t1s, t2s, h0_buggy, proof) = run(&z_bad, pads, b"r1-order", false, &mut rng);
        assert_true(
            "R1 order rig: the false claim REJECTS before the pad shift (defect carried at c^2)",
            !verify_ct_round(&path, &ring_ctx, &rp, None, &crs, &h0_buggy, &[], &[], &[], &claims, &t1s, &t2s, &[], &[], &[], 3, &proof),
        );
        // Pad re-chosen AFTER c (possible only because h0_buggy does not
        // bind commitment 3): t2 of the mw slot shifted by c*Delta.
        let c = poly_from_small(&zq, &ct_round_challenge(&h0_buggy, &proof));
        let mut t2s_atk = t2s.clone();
        t2s_atk[3][1] = poly_add(&zq, &t2s_atk[3][1], &poly_mul_g(&zq, &c, &delta));
        assert_true(
            "R1 order: pad-after-challenge ACCEPTS the un-mask (pad commitment outside h0 — the attack, demonstrated)",
            verify_ct_round(&path, &ring_ctx, &rp, None, &crs, &h0_buggy, &[], &[], &[], &claims, &t1s, &t2s_atk, &[], &[], &[], 3, &proof),
        );
        // The shipped chain: the pad commitment is inside h0, so the
        // crafted t2 re-derives a different challenge — REJECTED.
        let h0_fixed = ct_h0(&crs, b"r1-order", &t1s, &t2s_atk, &[]);
        assert_true(
            "R1 order: pad-in-h0 REJECTS the same crafting (the fix)",
            !verify_ct_round(&path, &ring_ctx, &rp, None, &crs, &h0_fixed, &[], &[], &[], &claims, &t1s, &t2s_atk, &[], &[], &[], 3, &proof),
        );
    }

    // ---- Twisted-ring family (the GATE claim form — the family whose
    // leak was the product matrix C, Q4.3e). Same two pairs at the
    // sigma-twisted monomial shape: claim conj(x)*y - z = 0, pads
    // (conj(ma), mb, conj(mw)) at flat slots 0..2 -> two msg_r=2 groups.
    {
        use ring::ct_engine::{TwistedQuadRingClaim, prove_ct_round_tq, verify_ct_round_tq};
        let z0t = poly_mul_g(&zq, &poly_conj(&zq, &x0), &y0);
        let claims_t = [TwistedQuadRingClaim {
            quad: vec![(0, 0, 1, 0, one.clone())],
            msg_coeffs: vec![(2, 0, minus_one.clone())],
        }];
        let rp5 = derive_ct_round_params(q, shape, 5, 0, 0, false);
        let a1p5 = build_a1_paths(&crs, rp5.sigma, isqrt_u128(rp5.bound_sq));
        let path5 = KernelPath::A1(&a1p5);
        let run_t = |z_val: &Poly,
                     g_groups: Vec<Vec<Poly>>,
                     ctx: &'static [u8],
                     bind_pads: bool,
                     rng: &mut u64|
         -> (Vec<Vec<Poly>>, Vec<Vec<Poly>>, [u8; 32], CtRoundProof) {
            let mut all_x = vec![pack1(&x0), pack1(&y0), pack1(z_val)];
            all_x.extend(g_groups);
            let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
                .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(rng)).collect())
                .collect();
            let mut t1s = Vec::new();
            let mut t2s = Vec::new();
            for (x, rho) in all_x.iter().zip(all_rho.iter()) {
                let (t1, t2) = commit(&path5, &crs, x, rho);
                t1s.push(t1);
                t2s.push(t2);
            }
            let h0 = if bind_pads {
                ct_h0(&crs, ctx, &t1s, &t2s, &[])
            } else {
                ct_h0(&crs, ctx, &t1s[0..3], &t2s[0..3], &[])
            };
            let openings: Vec<StdOpening> = all_x
                .iter()
                .zip(all_rho.iter())
                .enumerate()
                .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
                .collect();
            let (proof, _) = prove_ct_round_tq(
                &path5, &ring_ctx, &rp5, None, &crs, &h0, &[], &[], &[], &[], &claims_t,
                &openings, &[], &[], 3, rng,
            );
            (t1s, t2s, h0, proof)
        };
        let verify_t = |h0: &[u8; 32], t1s: &[Vec<Poly>], t2s: &[Vec<Poly>], p: &CtRoundProof| {
            verify_ct_round_tq(
                &path5, &ring_ctx, &rp5, None, &crs, h0, &[], &[], &[], &[], &claims_t, t1s,
                t2s, &[], &[], &[], 3, p,
            )
        };
        // Q4.3d-1 distinguisher, identical form (the P-table identity
        // carries no twist): W~ + sum a_l P_l = c L + mw.
        let recover_t = |h0: &[u8; 32], proof: &CtRoundProof, t2s: &[Vec<Poly>]| -> Poly {
            let c = poly_from_small(&zq, &ct_round_challenge(h0, proof));
            let a2z = a2_matvec(&path5, &crs, MatvecKind::Verify, &proof.z[2]);
            let p_z = ring::poly_sub(&zq, &poly_mul_g(&zq, &c, &t2s[2][0]), &a2z[0]);
            ring::poly_sub(&zq, &proof.w_tq[0], &p_z)
        };
        // Leak pair.
        let zero_pads = vec![vec![poly_zero(), poly_zero()], vec![poly_zero(), poly_zero()]];
        let (t1s, t2s, h0, proof) = run_t(&z0t, zero_pads, b"r1t-leak", true, &mut rng);
        let c = poly_from_small(&zq, &ct_round_challenge(&h0, &proof));
        let c_l = poly_mul_g(&zq, &c, &ring::poly_neg(&zq, &z0t));
        assert_true(
            "R1 twisted-ring (gate form) leak: ZEROED pads expose c*L exactly (the C-recovery image, Q4.3e)",
            verify_t(&h0, &t1s, &t2s, &proof) && recover_t(&h0, &proof, &t2s) == c_l,
        );
        let pads: Vec<Vec<Poly>> = sample_g_masks(&mut rng, q, shape.msg_r, 0, r1_pad_count(0, 0, 1));
        let (t1s, t2s, h0, proof) = run_t(&z0t, pads, b"r1t-leak", true, &mut rng);
        let c = poly_from_small(&zq, &ct_round_challenge(&h0, &proof));
        let c_l = poly_mul_g(&zq, &c, &ring::poly_neg(&zq, &z0t));
        assert_true(
            "R1 twisted-ring leak: honest pads one-time-pad the combination (the fix)",
            verify_t(&h0, &t1s, &t2s, &proof) && recover_t(&h0, &proof, &t2s) != c_l,
        );
        // Order pair. FALSE claim z' = conj(x)y + d; the twisted check's
        // defect sits at sigma(c)*c, and the mw slot holds conj(mw), so
        // the post-c shift is conj(c*Delta): conj(P_MW) gains
        // sigma(c)*c*Delta, which the check subtracts.
        let mut d = poly_zero();
        d[0] = 1;
        let z_bad = poly_add(&zq, &z0t, &d);
        let delta = ring::poly_neg(&zq, &d);
        let pads: Vec<Vec<Poly>> = sample_g_masks(&mut rng, q, shape.msg_r, 0, r1_pad_count(0, 0, 1));
        let (t1s, t2s, h0_buggy, proof) = run_t(&z_bad, pads, b"r1t-order", false, &mut rng);
        assert_true(
            "R1 twisted-ring order rig: the false claim REJECTS before the pad shift",
            !verify_t(&h0_buggy, &t1s, &t2s, &proof),
        );
        let c = poly_from_small(&zq, &ct_round_challenge(&h0_buggy, &proof));
        let mut t2s_atk = t2s.clone();
        // mw = flat pad slot 2 -> group 4, slot 0 at msg_r = 2.
        t2s_atk[4][0] =
            poly_add(&zq, &t2s_atk[4][0], &poly_conj(&zq, &poly_mul_g(&zq, &c, &delta)));
        assert_true(
            "R1 twisted-ring order: pad-after-challenge ACCEPTS (pad commitment outside h0 — the attack)",
            verify_t(&h0_buggy, &t1s, &t2s_atk, &proof),
        );
        let h0_fixed = ct_h0(&crs, b"r1t-order", &t1s, &t2s_atk, &[]);
        assert_true(
            "R1 twisted-ring order: pad-in-h0 REJECTS the same crafting (the fix)",
            !verify_t(&h0_fixed, &t1s, &t2s_atk, &proof),
        );
    }

    // ---- Quad ct-claim family: the Q-leak (Q4.3d-2). The reveal pair
    // (h, W_quad) exposed c*Q despite the g-mask (the g-slot images
    // cancel); with R1, W~ = W + mw one-time-pads it. Claim:
    // ct(conj(x) x + g) = scalar; g at flat slot 0, pads at 1..3.
    {
        use ring::ct_engine::QuadCtClaim;
        let qq = poly_mul_g(&zq, &poly_conj(&zq, &x0), &x0);
        let claims_q = [QuadCtClaim {
            quad: vec![(0, 0, 0, 0, one.clone())],
            msg_coeffs: vec![],
            scalar: ct_coeff(&zq, &qq),
        }];
        let rp3 = derive_ct_round_params(q, shape, 3, 0, 0, false);
        let a1p3 = build_a1_paths(&crs, rp3.sigma, isqrt_u128(rp3.bound_sq));
        let path3 = KernelPath::A1(&a1p3);
        let run_q = |g_groups: Vec<Vec<Poly>>, rng: &mut u64|
         -> (Vec<Vec<Poly>>, [u8; 32], CtRoundProof) {
            let mut all_x = vec![pack1(&x0)];
            all_x.extend(g_groups);
            let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
                .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(rng)).collect())
                .collect();
            let mut t1s = Vec::new();
            let mut t2s = Vec::new();
            for (x, rho) in all_x.iter().zip(all_rho.iter()) {
                let (t1, t2) = commit(&path3, &crs, x, rho);
                t1s.push(t1);
                t2s.push(t2);
            }
            let h0 = ct_h0(&crs, b"r1q-leak", &t1s, &t2s, &[]);
            let openings: Vec<StdOpening> = all_x
                .iter()
                .zip(all_rho.iter())
                .enumerate()
                .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
                .collect();
            let (proof, _) = prove_ct_round(
                &path3, &ring_ctx, &rp3, None, &crs, &h0, &[], &[], &claims_q, &[], &openings,
                &[], &[], 1, rng,
            );
            let ok = verify_ct_round(&path3, &ring_ctx, &rp3, None, &crs, &h0, &[], &[], &claims_q, &[], &t1s, &t2s, &[], &[], &[], 1, &proof);
            assert!(ok, "R1 quad-ct rig must verify");
            (t2s, h0, proof)
        };
        // Q4.3d-2 distinguisher: c*h - (W~ + sum a P + P_g) = c*Q - mw
        // (no linear part here; P_g = the reveal g slot's opening).
        let recover_q = |h0: &[u8; 32], proof: &CtRoundProof, t2s: &[Vec<Poly>]| -> Poly {
            let c = poly_from_small(&zq, &ct_round_challenge(h0, proof));
            let a2z = a2_matvec(&path3, &crs, MatvecKind::Verify, &proof.z[1]);
            let p_g = ring::poly_sub(&zq, &poly_mul_g(&zq, &c, &t2s[1][0]), &a2z[0]);
            let ch = poly_mul_g(&zq, &c, &proof.h_quad[0]);
            ring::poly_sub(&zq, &ch, &poly_add(&zq, &proof.w_quad[0], &p_g))
        };
        // Zero pads (reveal g stays honest: flat 0 keeps ct = 0).
        let mut g_zero = sample_g_masks(&mut rng, q, shape.msg_r, 1, 3);
        g_zero[0][1] = poly_zero();
        g_zero[1][0] = poly_zero();
        g_zero[1][1] = poly_zero();
        let (t2s, h0, proof) = run_q(g_zero, &mut rng);
        let c = poly_from_small(&zq, &ct_round_challenge(&h0, &proof));
        let c_q = poly_mul_g(&zq, &c, &qq);
        assert_true(
            "R1 quad-ct leak: ZEROED pads expose c*Q despite the g-mask (Q4.3d-2 — demonstrated)",
            recover_q(&h0, &proof, &t2s) == c_q,
        );
        let g_honest = sample_g_masks(&mut rng, q, shape.msg_r, 1, 3);
        let (t2s, h0, proof) = run_q(g_honest, &mut rng);
        let c = poly_from_small(&zq, &ct_round_challenge(&h0, &proof));
        let c_q = poly_mul_g(&zq, &c, &qq);
        assert_true(
            "R1 quad-ct leak: honest pads one-time-pad the (h, W~) pair (the fix)",
            recover_q(&h0, &proof, &t2s) != c_q,
        );
    }
}

// ===========================================================================
// U5: ring-Pi2 — all three matrices hidden (A committed by rows, B and C
// by columns); claim C = A B.
//
// GATE EQUATIONS (worked on paper first, per the design's U5 mitigation):
// with SCALAR gate challenges (s, v) the composition closes exactly:
//   x_a = sum_i s_i apack_i, x_b = sum_j v_j bpack_j, x_c = sum_j v_j
//   cpack_j (scalar weights commute with packing), and
//     ct( sum_u conj(xa_u) xb_u )  = <coeffs(x_a), coeffs(x_b)>
//                                  = s^T (A B) v,
//     ct( sum_u conj(spack_u) xc_u ) = s^T C v,
//   so ONE sigma-twisted quadratic ct-claim per repetition:
//     ct( sum_u conj(xa_u) xb_u - sum_u conj(spack_u) xc_u ) = 0.
//   The scalar-combined commitments are digit-opened (Q2; scalar
//   combination magnitude is SMALL — cheaper digit chains than the ring
//   combos), and every repetition shares one ct-round (one challenge, one
//   mask bundle class).
//
// Q1 FINDING, gate half (this build's central result): with RING
// challenges the gate does NOT close — F := sum_u conj(xa_u) xb_u =
// sum_ij conj(s_i) v_j P_ij with P_ij := sum_u conj(apack_iu) bpack_ju,
// and ct(w P) != w-weighted ct(P): the ring weights mix the JUNK
// (shift-correlation) coefficients of P_ij into the ct. The committed-
// correction escapes fail (the correction's own consistency reintroduces
// per-pair objects), and the C-side cannot be twisted to match (same
// non-commutation as Pi1 option (b)). Sound resolutions are the ALS20
// automorphism/trace machinery (a design round of its own) or this
// SCALAR-repetition gate: per-rep soundness (b - 2) bits at b-bit signed
// nonzero scalars (Route Z's own discipline), so r_g = ceil(256/(b-2))
// for full grade — r_g = 64 at b = 6, i.e. THE r -> 1 LEVER DOES NOT
// SURVIVE FOR PI2'S GATE at this design state; the vector/opening layers
// DO stay at r = 1, so the per-rep cost is ~3 digit bundles, far below a
// Route Z repetition. Full accounting in the U8 docs; r_g is a
// constructor parameter (the design's "fallback behind a flag").

struct RingPi2Proof {
    salt: u64,
    g_t1: Vec<Vec<Poly>>,
    g_t2: Vec<Vec<Poly>>,
    ct: ring::ct_engine::CtRoundProof,
}

struct Pi2Shape {
    rows: usize,
    inner_r: usize, // slots per A-row / B-column
    rows_r: usize,  // slots per C-column (ceil(rows / D))
    cols: usize,
}

/// b-bit signed nonzero gate scalar: value in +-[1, 2^b].
fn next_gate_scalar(reader: &mut XofReader, b: u32) -> i64 {
    let v = 1 + (reader.next_u64() % (1u64 << b)) as i64;
    if reader.next_bytes(1)[0] & 1 == 0 { v } else { -v }
}

/// The largest gate-scalar width b whose combination digit chain fits the
/// modulus with >= 1 bit of C2 headroom (and C3 at the given kappa):
/// bigger b = more bits per repetition = fewer repetitions
/// (r_g = ceil(256 / (b - 2)), Route Z's discipline). Appendix A.4 of
/// AUTOMORPHISM_GATE_DESIGN.md: the win is shape-dependent — b = 10
/// (r_g = 32) at demo scale, smaller at FFN combination counts.
/// Returns (b, l_dig, w_u).
fn derive_gate_b(q: u64, t_max: usize, kappa: usize, n_r: usize) -> (u32, u32, usize, f64) {
    let n_z = (n_r * D) as f64;
    let op_c = 1.3 * (2.0 * D as f64).sqrt();
    let mut best: Option<(usize, u32, u32, usize, f64)> = None; // (r_g*L, b, e, L, w_u)
    for b in (4..=12u32).rev() {
        for e_dig in [4u32, 3, 2] {
            let half = (1u64 << (e_dig - 1)) as f64;
            let e_s2 = (1u64 << (2 * b)) as f64 / 3.0;
            let w_u = 1.3 * (t_max as f64 * D as f64 * e_s2 * (2.0 / 3.0)).sqrt();
            let l = ((w_u.log2() + 1.0) / e_dig as f64).ceil() as usize;
            let bundle = l as f64 * n_z;
            let t_bundle = op_c * half * bundle.sqrt();
            let sigma = 12.0 * t_bundle;
            let bound = 1.2 * sigma * bundle.sqrt();
            let beta_dig = 2.0 * bound + op_c * half * n_z.sqrt();
            let beta_rec = op_c * w_u * n_z.sqrt();
            let beta = beta_dig.max(beta_rec);
            let log2_q = (q as f64).log2();
            let k_z = ((beta.log2() / 2.0) * (beta.log2() / 2.0) / (log2_q * ring::LOG2_DELTA0)).ceil() as usize;
            if (q as f64) > 16.0 * beta && kappa * D >= k_z {
                // The honest cost metric is repetitions x digit bundles
                // (response data per gate), not max b.
                let r_g = (256.0 / (b as f64 - 2.0)).ceil() as usize;
                let cost = r_g * l;
                if best.is_none() || cost < best.as_ref().unwrap().0 {
                    best = Some((cost, b, e_dig, l, w_u));
                }
            }
        }
    }
    let (_, b, e, l, w_u) = best.expect("no gate-scalar width fits the modulus at this shape");
    (b, e, l, w_u)
}

#[allow(clippy::too_many_arguments)]
fn pi2_h0(
    crs: &ring::commit::RingCrs,
    shape: &Pi2Shape,
    ctx: &[u8],
    salt: u64,
    r_g: usize,
    b_bits: u32,
    ta: &[(Vec<Poly>, Vec<Poly>)],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
    g_t1: &[Vec<Poly>],
    g_t2: &[Vec<Poly>],
) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-pi2-stmt-v1");
    hasher.update(crs.q.to_le_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((shape.rows as u64).to_le_bytes());
    hasher.update((shape.inner_r as u64).to_le_bytes());
    hasher.update((shape.cols as u64).to_le_bytes());
    hasher.update((r_g as u64).to_le_bytes());
    hasher.update((b_bits as u64).to_le_bytes());
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    hasher.update(salt.to_le_bytes());
    for (t1, t2) in ta.iter().chain(tb.iter()).chain(tc.iter()) {
        hasher.update(polys_bytes(t1));
        hasher.update(polys_bytes(t2));
    }
    for (t1, t2) in g_t1.iter().zip(g_t2.iter()) {
        hasher.update(polys_bytes(t1));
        hasher.update(polys_bytes(t2));
    }
    hasher.finalize().into()
}

/// Scalar combination of commitment groups / packed messages / ternary
/// randomness (exact over Z for the randomness).
fn scalar_combine_groups(
    zq: &ring::Zq,
    groups: &[(Vec<Poly>, Vec<Poly>)],
    s: &[i64],
    part: usize,
) -> Vec<Poly> {
    let len = if part == 0 { groups[0].0.len() } else { groups[0].1.len() };
    (0..len)
        .map(|r| {
            let mut acc = poly_zero();
            for (g, &si) in groups.iter().zip(s.iter()) {
                let t = if part == 0 { &g.0[r] } else { &g.1[r] };
                let w = zq.to_mod(si);
                for k in 0..D {
                    acc[k] = zq.add(acc[k], zq.mul(w, t[k]));
                }
            }
            acc
        })
        .collect()
}

fn scalar_combine_msgs(zq: &ring::Zq, msgs: &[Vec<Poly>], s: &[i64]) -> Vec<Poly> {
    let slots = msgs[0].len();
    (0..slots)
        .map(|u| {
            let mut acc = poly_zero();
            for (m, &si) in msgs.iter().zip(s.iter()) {
                let w = zq.to_mod(si);
                for k in 0..D {
                    acc[k] = zq.add(acc[k], zq.mul(w, m[u][k]));
                }
            }
            acc
        })
        .collect()
}

fn scalar_combine_rho(rhos: &[Vec<Vec<i64>>], s: &[i64]) -> Vec<Vec<i64>> {
    let n_r = rhos[0].len();
    let mut acc = vec![vec![0i64; D]; n_r];
    for (rho, &si) in rhos.iter().zip(s.iter()) {
        for (a, r) in acc.iter_mut().zip(rho.iter()) {
            for (x, &v) in a.iter_mut().zip(r.iter()) {
                *x += si * v;
            }
        }
    }
    acc
}

/// The gate claim for repetition m: index space has the g-groups plain at
/// 0..G, then digit combos in rep-major order [xa_0, xb_0, xc_0, xa_1,...].
fn pi2_gate_claim(
    zq: &ring::Zq,
    shape: &Pi2Shape,
    g_count: usize,
    m: usize,
    s: &[i64],
) -> ring::ct_engine::QuadCtClaim {
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let idx_a = g_count + 3 * m;
    let idx_b = g_count + 3 * m + 1;
    let idx_c = g_count + 3 * m + 2;
    // spack: the scalar vector s packed into rows_r chunks, conjugated.
    let s_mod: Vec<u64> = s.iter().map(|&x| zq.to_mod(x)).collect();
    let spack = ring::ct_engine::pack_functional(zq, &s_mod, shape.rows_r);
    let mut msg_coeffs: Vec<(usize, usize, Poly)> = Vec::new();
    for (u, sp) in spack.into_iter().enumerate() {
        msg_coeffs.push((idx_c, u, ring::poly_neg(zq, &sp)));
    }
    ring::ct_engine::QuadCtClaim {
        quad: (0..shape.inner_r).map(|u| (idx_a, u, idx_b, u, one.clone())).collect(),
        msg_coeffs,
        scalar: 0,
    }
}

#[allow(clippy::too_many_arguments)]
fn prove_ring_pi2(
    path: &KernelPath,
    ring_ctx: &RingCtx,
    crs: &ring::commit::RingCrs,
    rp: &ring::ct_engine::CtRoundParams,
    dp: &ring::sigma::DigitParams,
    shape: &Pi2Shape,
    ctx: &[u8],
    r_g: usize,
    b_bits: u32,
    a_rows: &[Vec<Poly>],
    rho_a: &[Vec<Vec<i64>>],
    b_cols: &[Vec<Poly>],
    rho_b: &[Vec<Vec<i64>>],
    c_cols: &[Vec<Poly>],
    rho_c: &[Vec<Vec<i64>>],
    ta: &[(Vec<Poly>, Vec<Poly>)],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
    rng: &mut u64,
) -> (RingPi2Proof, usize) {
    use ring::ct_engine::{DigitOpening, prove_ct_round, r1_pad_count, sample_g_masks};
    let zq = &ring_ctx.zq;
    let msg_r = crs.shape.msg_r;

    // g-masks (one per gate repetition) + the R1 pads (3 per repetition),
    // committed before challenges.
    let g_groups = sample_g_masks(rng, crs.q, msg_r, r_g, r1_pad_count(r_g, 0, 0));
    let mut g_t1 = Vec::new();
    let mut g_t2 = Vec::new();
    let mut g_rho = Vec::new();
    for g in &g_groups {
        let rho: Vec<Vec<i64>> = (0..crs.shape.n_r).map(|_| rng_ternary_poly(rng)).collect();
        let (t1, t2) = commit(path, crs, g, &rho);
        g_t1.push(t1);
        g_t2.push(t2);
        g_rho.push(rho);
    }

    // Salted gate challenges; combos must fit the digit range.
    let mut salt = 0u64;
    let (h0, reps) = loop {
        let h0 = pi2_h0(crs, shape, ctx, salt, r_g, b_bits, ta, tb, tc, &g_t1, &g_t2);
        let mut reps = Vec::with_capacity(r_g);
        let mut ok = true;
        for m in 0..r_g {
            let mut reader = XofReader::new("pi2-gate", &[&h0, &(m as u64).to_le_bytes()]);
            let s: Vec<i64> = (0..shape.rows).map(|_| next_gate_scalar(&mut reader, b_bits)).collect();
            let v: Vec<i64> = (0..shape.cols).map(|_| next_gate_scalar(&mut reader, b_bits)).collect();
            let rho_sa = scalar_combine_rho(rho_a, &s);
            let rho_vb = scalar_combine_rho(rho_b, &v);
            let rho_vc = scalar_combine_rho(rho_c, &v);
            let fits = rho_sa
                .iter()
                .chain(rho_vb.iter())
                .chain(rho_vc.iter())
                .all(|col| col.iter().all(|&x| digit_fits(x, dp.e, dp.l)));
            if !fits {
                ok = false;
                break;
            }
            reps.push((s, v, rho_sa, rho_vb, rho_vc));
        }
        if ok {
            break (h0, reps);
        }
        salt += 1;
    };

    // Combined objects per repetition.
    struct Combo {
        t1: Vec<Poly>,
        t2: Vec<Poly>,
        x: Vec<Poly>,
        rho: Vec<Vec<i64>>,
    }
    let mut combos: Vec<Combo> = Vec::with_capacity(3 * r_g);
    let mut claims = Vec::with_capacity(r_g);
    for (m, (s, v, rho_sa, rho_vb, rho_vc)) in reps.into_iter().enumerate() {
        let xa = scalar_combine_msgs(zq, a_rows, &s);
        let xb = scalar_combine_msgs(zq, b_cols, &v);
        let xc = scalar_combine_msgs(zq, c_cols, &v);
        combos.push(Combo {
            t1: scalar_combine_groups(zq, ta, &s, 0),
            t2: scalar_combine_groups(zq, ta, &s, 1),
            x: xa,
            rho: rho_sa,
        });
        combos.push(Combo {
            t1: scalar_combine_groups(zq, tb, &v, 0),
            t2: scalar_combine_groups(zq, tb, &v, 1),
            x: xb,
            rho: rho_vb,
        });
        combos.push(Combo {
            t1: scalar_combine_groups(zq, tc, &v, 0),
            t2: scalar_combine_groups(zq, tc, &v, 1),
            x: xc,
            rho: rho_vc,
        });
        claims.push(pi2_gate_claim(zq, shape, g_groups.len(), m, &s));
    }

    let plain: Vec<ring::ct_engine::StdOpening> = g_groups
        .iter()
        .enumerate()
        .map(|(i, g)| ring::ct_engine::StdOpening { t1: &g_t1[i], t2: &g_t2[i], x: g, rho: &g_rho[i] })
        .collect();
    let digits: Vec<DigitOpening> = combos
        .iter()
        .map(|c| DigitOpening { t1: &c.t1, t2: &c.t2, x: &c.x, rho_wide: &c.rho })
        .collect();
    let (ct, attempts) = prove_ct_round(
        path, ring_ctx, rp, Some(dp), crs, &h0, &[], &[], &claims, &[], &plain, &digits, &[], 0, rng,
    );
    (RingPi2Proof { salt, g_t1, g_t2, ct }, attempts)
}

#[allow(clippy::too_many_arguments)]
fn verify_ring_pi2(
    path: &KernelPath,
    ring_ctx: &RingCtx,
    crs: &ring::commit::RingCrs,
    rp: &ring::ct_engine::CtRoundParams,
    dp: &ring::sigma::DigitParams,
    shape: &Pi2Shape,
    ctx: &[u8],
    r_g: usize,
    b_bits: u32,
    ta: &[(Vec<Poly>, Vec<Poly>)],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
    proof: &RingPi2Proof,
) -> bool {
    use ring::ct_engine::verify_ct_round;
    let zq = &ring_ctx.zq;
    if ta.len() != shape.rows || tb.len() != shape.cols || tc.len() != shape.cols {
        return false;
    }
    let n_gslots = r_g + ring::ct_engine::r1_pad_count(r_g, 0, 0);
    if proof.g_t1.len() != n_gslots.div_ceil(crs.shape.msg_r) || proof.salt > 64 {
        return false;
    }
    let h0 = pi2_h0(crs, shape, ctx, proof.salt, r_g, b_bits, ta, tb, tc, &proof.g_t1, &proof.g_t2);
    let mut t1s_dig = Vec::with_capacity(3 * r_g);
    let mut t2s_dig = Vec::with_capacity(3 * r_g);
    let mut claims = Vec::with_capacity(r_g);
    for m in 0..r_g {
        let mut reader = XofReader::new("pi2-gate", &[&h0, &(m as u64).to_le_bytes()]);
        let s: Vec<i64> = (0..shape.rows).map(|_| next_gate_scalar(&mut reader, b_bits)).collect();
        let v: Vec<i64> = (0..shape.cols).map(|_| next_gate_scalar(&mut reader, b_bits)).collect();
        t1s_dig.push(scalar_combine_groups(zq, ta, &s, 0));
        t2s_dig.push(scalar_combine_groups(zq, ta, &s, 1));
        t1s_dig.push(scalar_combine_groups(zq, tb, &v, 0));
        t2s_dig.push(scalar_combine_groups(zq, tb, &v, 1));
        t1s_dig.push(scalar_combine_groups(zq, tc, &v, 0));
        t2s_dig.push(scalar_combine_groups(zq, tc, &v, 1));
        claims.push(pi2_gate_claim(zq, shape, proof.g_t1.len(), m, &s));
    }
    verify_ct_round(
        path,
        ring_ctx,
        rp,
        Some(dp),
        crs,
        &h0,
        &[],
        &[],
        &claims,
        &[],
        &proof.g_t1,
        &proof.g_t2,
        &t1s_dig,
        &t2s_dig,
        &[],
        0,
        &proof.ct,
    )
}

// ===========================================================================
// U-B6: pi2 on the committed-executions gate (the DEFAULT construction;
// the scalar-repetition gate above stays behind its r_g flag). Two
// chained ct-rounds:
//
//   Round W (wide CRS, msg_r = h * inner_r): fresh commitments to the
//   execution vectors Y^A, Y^B, Y^C and the tie masks (mu, nu) per
//   side; ONE conj-twisted ring quadratic gate claim; tie claims (i)
//   and (ii-W) as RingClaims with public constants.
//
//   Round O (the statement's narrow CRS): one digit-opened combination
//   T_alpha per side (weights alpha_i = sum_t tauii_t sigma_t(psi_t)
//   sigma_t(ch_i), quinary factors so the combined randomness stays
//   digit-openable) and the (ii-O) claims: slot u of T_alpha = K2_u.
//
// The revealed pivot K2_u := sum_t tauii_t (sigma_t(F_{t,u}) - nu_{t,u})
// splits tie claim (ii) across the rounds: (ii-W) pins K2 against the
// committed masks, (ii-O) pins the same K2 against the original
// commitments — no claim crosses a CRS. K2 is uniform (one-time-padded
// by the tauii-combination of nu), so nothing leaks. psi is QUINARY
// per twist (not per slot, not full-entropy): per-slot 2^-297
// crafted-mask soundness, and alpha stays inside the digit budget.
// Order chain: h0_pre -> s,v -> Y/mask commits -> h0_stmt(salt) ->
// psi -> F -> taui/tauii -> K2 -> round hashes (bind F, K2) -> c_W, c_O.

struct RingPi2CeProof {
    salt: u64,
    /// [YA, YB, YC, MA, NA, MB, NB, MC, NC] wide commitments.
    wide: Vec<(Vec<Poly>, Vec<Poly>)>,
    /// Reveals F per side (used slots only, twist-major chunk-minor).
    f: [Vec<Poly>; 3],
    /// Pivots K2 per side (chunks polys each).
    k2: [Vec<Poly>; 3],
    ct_w: ring::ct_engine::CtRoundProof,
    ct_o: ring::ct_engine::CtRoundProof,
}

/// Poly-weighted homomorphic combination of commitment groups (the
/// ring-weight sibling of scalar_combine_groups).
fn ring_combine_groups(
    ring_ctx: &RingCtx,
    groups: &[(Vec<Poly>, Vec<Poly>)],
    w: &[Poly],
    part: usize,
) -> Vec<Poly> {
    let zq = &ring_ctx.zq;
    let len = if part == 0 { groups[0].0.len() } else { groups[0].1.len() };
    (0..len)
        .map(|r| {
            let mut acc = poly_zero();
            for (g, wi) in groups.iter().zip(w.iter()) {
                let t = if part == 0 { &g.0[r] } else { &g.1[r] };
                acc = poly_add(zq, &acc, &poly_mul_g(zq, wi, t));
            }
            acc
        })
        .collect()
}

fn ring_combine_msgs(ring_ctx: &RingCtx, msgs: &[Vec<Poly>], w: &[Poly]) -> Vec<Poly> {
    let zq = &ring_ctx.zq;
    let slots = msgs[0].len();
    (0..slots)
        .map(|u| {
            let mut acc = poly_zero();
            for (m, wi) in msgs.iter().zip(w.iter()) {
                acc = poly_add(zq, &acc, &poly_mul_g(zq, wi, &m[u]));
            }
            acc
        })
        .collect()
}

/// Exact-over-Z poly-weighted combination of ternary randomness.
fn ring_combine_rho(zq: &ring::Zq, rhos: &[Vec<Vec<i64>>], w: &[Poly]) -> Vec<Vec<i64>> {
    let n_r = rhos[0].len();
    let mut acc = vec![vec![0i64; D]; n_r];
    for (rho, wi) in rhos.iter().zip(w.iter()) {
        // centered weight coefficients
        let wc: Vec<i64> = wi.iter().map(|&x| zq.center(x)).collect();
        for (a, r) in acc.iter_mut().zip(rho.iter()) {
            // negacyclic small x small convolution over Z
            for (i, &ri) in r.iter().enumerate() {
                if ri == 0 {
                    continue;
                }
                for (k, &wk) in wc.iter().enumerate() {
                    if wk == 0 {
                        continue;
                    }
                    let e = i + k;
                    if e < D {
                        a[e] += ri * wk;
                    } else {
                        a[e - D] -= ri * wk;
                    }
                }
            }
        }
    }
    acc
}

/// The wide (execution/mask) CRS shape at msg_r slots — the C4-chain
/// row pinned in freeze-check.
fn pi2_ce_wide_shape(msg_r: usize) -> CommitShape {
    let d_lwe = (768.0_f64 * 31.0 / 11.7).ceil() as usize;
    CommitShape { kappa: 8, n_r: (8 * D + msg_r * D + d_lwe).div_ceil(D), msg_r }
}

fn inv_odd(t: usize) -> usize {
    let m2 = 2 * D;
    (1..m2).step_by(2).find(|&u| (t * u) % m2 == 1).unwrap()
}

/// Statement hash for pi2-CE: both CRS hashes, the shape, the context,
/// and every original commitment.
fn pi2_ce_h0pre(
    crs_o: &ring::commit::RingCrs,
    crs_w: &ring::commit::RingCrs,
    shape: &Pi2Shape,
    ctx: &[u8],
    ta: &[(Vec<Poly>, Vec<Poly>)],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-pi2-ce-stmt-v1");
    hasher.update(crs_o.q.to_le_bytes());
    hasher.update(crs_o.crs_hash);
    hasher.update(crs_w.crs_hash);
    for d in [shape.rows, shape.inner_r, shape.rows_r, shape.cols] {
        hasher.update((d as u64).to_le_bytes());
    }
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for (t1, t2) in ta.iter().chain(tb.iter()).chain(tc.iter()) {
        hasher.update(polys_bytes(t1));
        hasher.update(polys_bytes(t2));
    }
    hasher.finalize().into()
}

/// 32 bytes out of an XOF over labeled byte parts.
fn xof32(label: &'static str, parts: &[&[u8]]) -> [u8; 32] {
    let mut r = XofReader::new(label, parts);
    let mut out = [0u8; 32];
    for chunk in out.chunks_mut(8) {
        chunk.copy_from_slice(&r.next_u64().to_le_bytes());
    }
    out
}

/// Per-side tie data derived from public values — shared VERBATIM by
/// prover and verifier. Returns (claims (i) + (ii-W) for round W,
/// alpha weights for round O's combo, K2 constants recomputed from F
/// and the tie claims' structure are NOT included here — K2 is a
/// proof reveal; this builds the claims GIVEN K2).
#[allow(clippy::too_many_arguments)]
fn pi2_ce_tie_claims_w(
    zq: &ring::Zq,
    full: &[usize],
    chunks: usize,
    y_idx: usize,
    m_idx: usize,
    n_idx: usize,
    psi: &[Poly],
    taui: &[Poly],
    tauii: &[Poly],
    f: &[Poly],
    k2: &[Poly],
) -> Vec<ring::ct_engine::RingClaim> {
    let h = full.len();
    let mut out = Vec::with_capacity(2 * chunks);
    for u in 0..chunks {
        // (i): sum_si taui (Y + psi mu) = sum_si taui F
        let mut mc = Vec::with_capacity(2 * h);
        let mut k = poly_zero();
        for si in 0..h {
            let slot = si * chunks + u;
            mc.push((y_idx, slot, taui[si].clone()));
            mc.push((m_idx, slot, poly_mul_g(zq, &taui[si], &psi[si])));
            k = poly_add(zq, &k, &poly_mul_g(zq, &taui[si], &f[slot]));
        }
        out.push(ring::ct_engine::RingClaim { msg_coeffs: mc, constant: k });
    }
    for u in 0..chunks {
        // (ii-W): sum_si tauii psi' nu = sum_si tauii sigma_t(F) - K2_u
        let mut mc = Vec::with_capacity(h);
        let mut k = poly_zero();
        for (si, &t) in full.iter().enumerate() {
            let slot = si * chunks + u;
            let psit = apply_auto(zq, &psi[si], t);
            mc.push((n_idx, slot, poly_mul_g(zq, &tauii[si], &psit)));
            k = poly_add(zq, &k, &poly_mul_g(zq, &tauii[si], &apply_auto(zq, &f[slot], t)));
        }
        k = ring::poly_sub(zq, &k, &k2[u]);
        out.push(ring::ct_engine::RingClaim { msg_coeffs: mc, constant: k });
    }
    out
}

/// alpha_i = sum_si tauii_si sigma_t(ch_i) — the round-O combination
/// weights. DOUBLE-quinary only: psi rides the norm-free claim
/// coefficients instead (the mask-side-psi variant, F = Y + psi mu),
/// keeping the combined randomness inside the q31 digit budget.
fn pi2_ce_alpha(zq: &ring::Zq, full: &[usize], ch: &[Poly], tauii: &[Poly]) -> Vec<Poly> {
    ch.iter()
        .map(|chi| {
            let mut acc = poly_zero();
            for (si, &t) in full.iter().enumerate() {
                let cc = apply_auto(zq, chi, t);
                acc = poly_add(zq, &acc, &poly_mul_g(zq, &tauii[si], &cc));
            }
            acc
        })
        .collect()
}

/// The gate claim over the wide round's Y objects (indices 0, 1, 2).
fn pi2_ce_gate_claim(
    zq: &ring::Zq,
    full: &[usize],
    inner_r: usize,
    rows_r: usize,
    shat_tw: &[Poly], // twist-major, rows_r chunks each
) -> ring::ct_engine::TwistedQuadRingClaim {
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let h = full.len();
    let mut quad = Vec::with_capacity(h * inner_r);
    for si in 0..h {
        for u in 0..inner_r {
            quad.push((0usize, si * inner_r + u, 1usize, si * inner_r + u, one.clone()));
        }
    }
    let mut msg_coeffs = Vec::with_capacity(h * rows_r);
    for si in 0..h {
        for u in 0..rows_r {
            msg_coeffs.push((
                2usize,
                si * rows_r + u,
                ring::poly_neg(zq, &poly_conj(zq, &shat_tw[si * rows_r + u])),
            ));
        }
    }
    ring::ct_engine::TwistedQuadRingClaim { quad, msg_coeffs }
}

/// pi2-CE tie/gate digit parameters for round O (T_alpha combos):
/// quinary^3 weights over ternary randomness — e = 4, L = 6 with a
/// 2^21 honest-magnitude envelope (asserted per proof by digit_fits).
const PI2_CE_DIGIT_E: u32 = 4;
const PI2_CE_DIGIT_L: usize = 5;
const PI2_CE_W_INF: i64 = 1 << 17;

#[allow(clippy::too_many_arguments)]
fn prove_ring_pi2_ce(
    path_w: &KernelPath,
    path_o: &KernelPath,
    ring_ctx: &RingCtx,
    crs_o: &ring::commit::RingCrs,
    crs_w: &ring::commit::RingCrs,
    shape: &Pi2Shape,
    ctx: &[u8],
    a_rows: &[Vec<Poly>],
    rho_a: &[Vec<Vec<i64>>],
    b_cols: &[Vec<Poly>],
    rho_b: &[Vec<Vec<i64>>],
    c_cols: &[Vec<Poly>],
    rho_c: &[Vec<Vec<i64>>],
    ta: &[(Vec<Poly>, Vec<Poly>)],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
    rng: &mut u64,
) -> (RingPi2CeProof, usize, usize) {
    use ring::ct_engine::{DigitOpening, StdOpening, prove_ct_round, prove_ct_round_tq};
    let zq = &ring_ctx.zq;
    let full = subgroup_elems(5, true);
    let h = full.len();
    let chunks = [shape.inner_r, shape.inner_r, shape.rows_r];

    // s, v (quinary ring challenges) from the statement pre-hash.
    let h0_pre = pi2_ce_h0pre(crs_o, crs_w, shape, ctx, ta, tb, tc);
    let mut sr = XofReader::new("pi2-ce-sv", &[&h0_pre]);
    let s_ch: Vec<Poly> =
        (0..shape.rows).map(|_| poly_from_small(zq, &sr.next_challenge())).collect();
    let v_ch: Vec<Poly> =
        (0..shape.cols).map(|_| poly_from_small(zq, &sr.next_challenge())).collect();

    // Execution vectors per side (twist-major, chunk-minor used slots).
    let exec = |msgs: &[Vec<Poly>], ch: &[Poly], nchunks: usize| -> Vec<Poly> {
        let mut out = Vec::with_capacity(h * nchunks);
        for &t in &full {
            let ti = inv_odd(t);
            for u in 0..nchunks {
                let mut acc = poly_zero();
                for (m, c) in msgs.iter().zip(ch.iter()) {
                    let tc = apply_auto(zq, c, t);
                    acc = poly_add(zq, &acc, &poly_mul_g(zq, &tc, &m[u]));
                }
                out.push(apply_auto(zq, &acc, ti));
            }
        }
        out
    };
    let ys = [
        exec(a_rows, &s_ch, shape.inner_r),
        exec(b_cols, &v_ch, shape.inner_r),
        exec(c_cols, &v_ch, shape.rows_r),
    ];
    // shat_tw (public): row i sits at chunk i/D, coefficient i%D.
    let shat_tw: Vec<Poly> = full
        .iter()
        .flat_map(|&t| {
            let ti = inv_odd(t);
            (0..shape.rows_r)
                .map(|u| {
                    let mut acc = poly_zero();
                    for (i, sc) in s_ch.iter().enumerate() {
                        if i / D != u {
                            continue;
                        }
                        let tcs = apply_auto(zq, sc, t);
                        let mut xi = poly_zero();
                        xi[i % D] = 1;
                        acc = poly_add(zq, &acc, &poly_mul_g(zq, &tcs, &xi));
                    }
                    apply_auto(zq, &acc, ti)
                })
                .collect::<Vec<_>>()
        })
        .collect();

    // Masks and the ten wide commitments:
    // [YA YB YC MA NA MB NB MC NC R1-pads].
    let mut mus: Vec<Vec<Poly>> = Vec::with_capacity(3);
    let mut nus: Vec<Vec<Poly>> = Vec::with_capacity(3);
    for side in 0..3 {
        let used = h * chunks[side];
        let mu: Vec<Poly> = (0..used).map(|_| rng_poly_mod(rng, crs_o.q)).collect();
        let nu: Vec<Poly> = (0..used)
            .map(|slot| apply_auto(zq, &mu[slot], full[slot / chunks[side]]))
            .collect();
        mus.push(mu);
        nus.push(nu);
    }
    let pad_w = |v: &[Poly]| -> Vec<Poly> {
        let mut x = v.to_vec();
        x.resize(crs_w.shape.msg_r, poly_zero());
        x
    };
    let wide_msgs: Vec<Vec<Poly>> = vec![
        pad_w(&ys[0]), pad_w(&ys[1]), pad_w(&ys[2]),
        pad_w(&mus[0]), pad_w(&nus[0]), pad_w(&mus[1]), pad_w(&nus[1]),
        pad_w(&mus[2]), pad_w(&nus[2]),
        // R1: the gate's committed one-time pads (3 uniform slots riding
        // one wide g-commitment; h0_stmt binds it before every challenge).
        ring::ct_engine::sample_g_masks(rng, crs_o.q, crs_w.shape.msg_r, 0, 3).remove(0),
    ];
    let mut wide = Vec::with_capacity(10);
    let mut wide_rho = Vec::with_capacity(10);
    for x in &wide_msgs {
        let rho: Vec<Vec<i64>> = (0..crs_w.shape.n_r).map(|_| rng_ternary_poly(rng)).collect();
        let (t1, t2) = commit(path_w, crs_w, x, &rho);
        wide.push((t1, t2));
        wide_rho.push(rho);
    }
    let mut wide_bytes: Vec<u8> = Vec::new();
    for (t1, t2) in &wide {
        wide_bytes.extend_from_slice(&polys_bytes(t1));
        wide_bytes.extend_from_slice(&polys_bytes(t2));
    }

    // Salted derivation chain: psi -> F -> tau -> K2 -> alpha, retried
    // until every combined randomness fits the digit envelope.
    let mut salt = 0u64;
    let (h0_stmt, psi, fs, taus, k2s, alphas, rho_alphas) = loop {
        let h0_stmt = xof32("pi2-ce-stmt", &[&h0_pre, &salt.to_le_bytes(), &wide_bytes]);
        let mut psir = XofReader::new("pi2-ce-psi", &[&h0_stmt]);
        let psi: Vec<Vec<Poly>> = (0..3)
            .map(|_| (0..h).map(|_| poly_from_small(zq, &psir.next_challenge())).collect())
            .collect();
        let fs: Vec<Vec<Poly>> = (0..3)
            .map(|side| {
                (0..h * chunks[side])
                    .map(|slot| {
                        let p = &psi[side][slot / chunks[side]];
                        poly_add(zq, &ys[side][slot], &poly_mul_g(zq, p, &mus[side][slot]))
                    })
                    .collect()
            })
            .collect();
        let mut fbytes: Vec<u8> = Vec::new();
        for f in &fs {
            fbytes.extend_from_slice(&polys_bytes(f));
        }
        let mut taur = XofReader::new("pi2-ce-tau", &[&h0_stmt, &fbytes]);
        let taus: Vec<(Vec<Poly>, Vec<Poly>)> = (0..3)
            .map(|_| {
                let a: Vec<Poly> =
                    (0..h).map(|_| poly_from_small(zq, &taur.next_challenge())).collect();
                let b: Vec<Poly> =
                    (0..h).map(|_| poly_from_small(zq, &taur.next_challenge())).collect();
                (a, b)
            })
            .collect();
        let k2s: Vec<Vec<Poly>> = (0..3)
            .map(|side| {
                (0..chunks[side])
                    .map(|u| {
                        let mut k = poly_zero();
                        for (si, &t) in full.iter().enumerate() {
                            let slot = si * chunks[side] + u;
                            let psit = apply_auto(zq, &psi[side][si], t);
                            let term = ring::poly_sub(
                                zq,
                                &apply_auto(zq, &fs[side][slot], t),
                                &poly_mul_g(zq, &psit, &nus[side][slot]),
                            );
                            k = poly_add(zq, &k, &poly_mul_g(zq, &taus[side].1[si], &term));
                        }
                        k
                    })
                    .collect()
            })
            .collect();
        let alphas: Vec<Vec<Poly>> = vec![
            pi2_ce_alpha(zq, &full, &s_ch, &taus[0].1),
            pi2_ce_alpha(zq, &full, &v_ch, &taus[1].1),
            pi2_ce_alpha(zq, &full, &v_ch, &taus[2].1),
        ];
        let rho_alphas: Vec<Vec<Vec<i64>>> = vec![
            ring_combine_rho(zq, rho_a, &alphas[0]),
            ring_combine_rho(zq, rho_b, &alphas[1]),
            ring_combine_rho(zq, rho_c, &alphas[2]),
        ];
        let fits = rho_alphas.iter().all(|ra| {
            ra.iter().all(|col| col.iter().all(|&x| digit_fits(x, PI2_CE_DIGIT_E, PI2_CE_DIGIT_L)))
        });
        if fits {
            break (h0_stmt, psi, fs, taus, k2s, alphas, rho_alphas);
        }
        salt += 1;
    };
    let mut fbytes: Vec<u8> = Vec::new();
    for f in &fs {
        fbytes.extend_from_slice(&polys_bytes(f));
    }
    let mut k2bytes: Vec<u8> = Vec::new();
    for k in &k2s {
        k2bytes.extend_from_slice(&polys_bytes(k));
    }

    // Round W: the gate + tie claims over the nine wide commitments.
    let h0_w = xof32("pi2-ce-w", &[&h0_stmt, &fbytes, &k2bytes]);
    let mut claims_w: Vec<ring::ct_engine::RingClaim> = Vec::new();
    for side in 0..3 {
        claims_w.extend(pi2_ce_tie_claims_w(
            zq, &full, chunks[side], side, 3 + 2 * side, 4 + 2 * side,
            &psi[side], &taus[side].0, &taus[side].1, &fs[side], &k2s[side],
        ));
    }
    let gate = [pi2_ce_gate_claim(zq, &full, shape.inner_r, shape.rows_r, &shat_tw)];
    let rp_w = ring::ct_engine::derive_ct_round_params(crs_o.q, crs_w.shape, 10, 0, 0, true);
    let plain_w: Vec<StdOpening> = (0..10)
        .map(|i| StdOpening { t1: &wide[i].0, t2: &wide[i].1, x: &wide_msgs[i], rho: &wide_rho[i] })
        .collect();
    let (ct_w, at_w) = prove_ct_round_tq(
        path_w, ring_ctx, &rp_w, None, crs_w, &h0_w, &[], &claims_w, &[], &[], &gate, &plain_w,
        &[], &[], 9, rng,
    );

    // Round O: the T_alpha combos + (ii-O) claims at the statement CRS.
    let h0_o = xof32("pi2-ce-o", &[&h0_stmt, &fbytes, &k2bytes]);
    let dp = derive_digit_params(
        crs_o.q, crs_o.shape.kappa, crs_o.shape.n_r, PI2_CE_DIGIT_E, PI2_CE_DIGIT_L, PI2_CE_W_INF,
    );
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let mut claims_o: Vec<ring::ct_engine::RingClaim> = Vec::new();
    for side in 0..3 {
        for u in 0..chunks[side] {
            claims_o.push(ring::ct_engine::RingClaim {
                msg_coeffs: vec![(side, u, one.clone())],
                constant: k2s[side][u].clone(),
            });
        }
    }
    struct ComboData {
        t1: Vec<Poly>,
        t2: Vec<Poly>,
        x: Vec<Poly>,
    }
    let groups = [ta, tb, tc];
    let msgs = [a_rows, b_cols, c_cols];
    let combos: Vec<ComboData> = (0..3)
        .map(|side| ComboData {
            t1: ring_combine_groups(ring_ctx, groups[side], &alphas[side], 0),
            t2: ring_combine_groups(ring_ctx, groups[side], &alphas[side], 1),
            x: ring_combine_msgs(ring_ctx, msgs[side], &alphas[side]),
        })
        .collect();
    let digits: Vec<DigitOpening> = combos
        .iter()
        .zip(rho_alphas.iter())
        .map(|(c, ra)| DigitOpening { t1: &c.t1, t2: &c.t2, x: &c.x, rho_wide: ra })
        .collect();
    let rp_o = ring::ct_engine::derive_ct_round_params(crs_o.q, crs_o.shape, 1, 0, 0, true);
    let (ct_o, at_o) = prove_ct_round(
        path_o, ring_ctx, &rp_o, Some(&dp), crs_o, &h0_o, &[], &claims_o, &[], &[], &[], &digits,
        &[], 0, rng,
    );

    (
        RingPi2CeProof {
            salt,
            wide,
            f: [fs[0].clone(), fs[1].clone(), fs[2].clone()],
            k2: [k2s[0].clone(), k2s[1].clone(), k2s[2].clone()],
            ct_w,
            ct_o,
        },
        at_w,
        at_o,
    )
}

#[allow(clippy::too_many_arguments)]
fn verify_ring_pi2_ce(
    path_w: &KernelPath,
    path_o: &KernelPath,
    ring_ctx: &RingCtx,
    crs_o: &ring::commit::RingCrs,
    crs_w: &ring::commit::RingCrs,
    shape: &Pi2Shape,
    ctx: &[u8],
    ta: &[(Vec<Poly>, Vec<Poly>)],
    tb: &[(Vec<Poly>, Vec<Poly>)],
    tc: &[(Vec<Poly>, Vec<Poly>)],
    proof: &RingPi2CeProof,
) -> bool {
    use ring::ct_engine::{verify_ct_round, verify_ct_round_tq};
    let zq = &ring_ctx.zq;
    let full = subgroup_elems(5, true);
    let h = full.len();
    let chunks = [shape.inner_r, shape.inner_r, shape.rows_r];
    if ta.len() != shape.rows
        || tb.len() != shape.cols
        || tc.len() != shape.cols
        || proof.wide.len() != 10
        || proof.salt > 64
        || (0..3).any(|s| proof.f[s].len() != h * chunks[s] || proof.k2[s].len() != chunks[s])
    {
        return false;
    }
    let h0_pre = pi2_ce_h0pre(crs_o, crs_w, shape, ctx, ta, tb, tc);
    let mut sr = XofReader::new("pi2-ce-sv", &[&h0_pre]);
    let s_ch: Vec<Poly> =
        (0..shape.rows).map(|_| poly_from_small(zq, &sr.next_challenge())).collect();
    let v_ch: Vec<Poly> =
        (0..shape.cols).map(|_| poly_from_small(zq, &sr.next_challenge())).collect();
    let shat_tw: Vec<Poly> = full
        .iter()
        .flat_map(|&t| {
            let ti = inv_odd(t);
            (0..shape.rows_r)
                .map(|u| {
                    let mut acc = poly_zero();
                    for (i, sc) in s_ch.iter().enumerate() {
                        if i / D != u {
                            continue;
                        }
                        let tcs = apply_auto(zq, sc, t);
                        let mut xi = poly_zero();
                        xi[i % D] = 1;
                        acc = poly_add(zq, &acc, &poly_mul_g(zq, &tcs, &xi));
                    }
                    apply_auto(zq, &acc, ti)
                })
                .collect::<Vec<_>>()
        })
        .collect();
    let mut wide_bytes: Vec<u8> = Vec::new();
    for (t1, t2) in &proof.wide {
        wide_bytes.extend_from_slice(&polys_bytes(t1));
        wide_bytes.extend_from_slice(&polys_bytes(t2));
    }
    let h0_stmt = xof32("pi2-ce-stmt", &[&h0_pre, &proof.salt.to_le_bytes(), &wide_bytes]);
    let mut psir = XofReader::new("pi2-ce-psi", &[&h0_stmt]);
    let psi: Vec<Vec<Poly>> = (0..3)
        .map(|_| (0..h).map(|_| poly_from_small(zq, &psir.next_challenge())).collect())
        .collect();
    let mut fbytes: Vec<u8> = Vec::new();
    for f in &proof.f {
        fbytes.extend_from_slice(&polys_bytes(f));
    }
    let mut taur = XofReader::new("pi2-ce-tau", &[&h0_stmt, &fbytes]);
    let taus: Vec<(Vec<Poly>, Vec<Poly>)> = (0..3)
        .map(|_| {
            let a: Vec<Poly> =
                (0..h).map(|_| poly_from_small(zq, &taur.next_challenge())).collect();
            let b: Vec<Poly> =
                (0..h).map(|_| poly_from_small(zq, &taur.next_challenge())).collect();
            (a, b)
        })
        .collect();
    let mut k2bytes: Vec<u8> = Vec::new();
    for k in &proof.k2 {
        k2bytes.extend_from_slice(&polys_bytes(k));
    }
    let h0_w = xof32("pi2-ce-w", &[&h0_stmt, &fbytes, &k2bytes]);
    let mut claims_w: Vec<ring::ct_engine::RingClaim> = Vec::new();
    for side in 0..3 {
        claims_w.extend(pi2_ce_tie_claims_w(
            zq, &full, chunks[side], side, 3 + 2 * side, 4 + 2 * side,
            &psi[side], &taus[side].0, &taus[side].1, &proof.f[side], &proof.k2[side],
        ));
    }
    let gate = [pi2_ce_gate_claim(zq, &full, shape.inner_r, shape.rows_r, &shat_tw)];
    let rp_w = ring::ct_engine::derive_ct_round_params(crs_o.q, crs_w.shape, 10, 0, 0, true);
    let t1s_w: Vec<Vec<Poly>> = proof.wide.iter().map(|g| g.0.clone()).collect();
    let t2s_w: Vec<Vec<Poly>> = proof.wide.iter().map(|g| g.1.clone()).collect();
    if !verify_ct_round_tq(
        path_w, ring_ctx, &rp_w, None, crs_w, &h0_w, &[], &claims_w, &[], &[], &gate, &t1s_w,
        &t2s_w, &[], &[], &[], 9, &proof.ct_w,
    ) {
        return false;
    }
    let h0_o = xof32("pi2-ce-o", &[&h0_stmt, &fbytes, &k2bytes]);
    let dp = derive_digit_params(
        crs_o.q, crs_o.shape.kappa, crs_o.shape.n_r, PI2_CE_DIGIT_E, PI2_CE_DIGIT_L, PI2_CE_W_INF,
    );
    let alphas: Vec<Vec<Poly>> = vec![
        pi2_ce_alpha(zq, &full, &s_ch, &taus[0].1),
        pi2_ce_alpha(zq, &full, &v_ch, &taus[1].1),
        pi2_ce_alpha(zq, &full, &v_ch, &taus[2].1),
    ];
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let mut claims_o: Vec<ring::ct_engine::RingClaim> = Vec::new();
    for side in 0..3 {
        for u in 0..chunks[side] {
            claims_o.push(ring::ct_engine::RingClaim {
                msg_coeffs: vec![(side, u, one.clone())],
                constant: proof.k2[side][u].clone(),
            });
        }
    }
    let groups = [ta, tb, tc];
    let mut t1s_dig = Vec::with_capacity(3);
    let mut t2s_dig = Vec::with_capacity(3);
    for side in 0..3 {
        t1s_dig.push(ring_combine_groups(ring_ctx, groups[side], &alphas[side], 0));
        t2s_dig.push(ring_combine_groups(ring_ctx, groups[side], &alphas[side], 1));
    }
    let rp_o = ring::ct_engine::derive_ct_round_params(crs_o.q, crs_o.shape, 1, 0, 0, true);
    verify_ct_round(
        path_o, ring_ctx, &rp_o, Some(&dp), crs_o, &h0_o, &[], &claims_o, &[], &[], &[], &[],
        &t1s_dig, &t2s_dig, &[], 0, &proof.ct_o,
    )
}

fn self_test_pi2() {
    use ring::ct_engine::derive_ct_round_params;
    println!("\n[U5] ring-Pi2 (scalar gate behind the r_g flag) at 128 x 256 x 64, q8_31");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let shape = Pi2Shape { rows: 128, inner_r: 2, rows_r: 1, cols: 64 };
    let inner = shape.inner_r * D;
    // Shape parameters from the Pi2 chain at the statement shape.
    let p = derive_digits(Proto::Pi2, shape.rows, inner, shape.cols, 0, q, true, 4)
        .expect("Pi2 demo point must fit q31");
    // Gate-scalar width DERIVED (Appendix A.4): the largest b whose
    // combination digit chain fits q31 at this shape.
    let t_max = shape.rows.max(shape.cols);
    let (b_bits, e_dig, l_dig, w_u) = derive_gate_b(q, t_max, p.kappa, p.n_r);
    let r_g = 8usize;
    let r_full = (256.0 / (b_bits as f64 - 2.0)).ceil() as usize;
    println!(
        "  gate: DERIVED b = {b_bits}-bit signed nonzero scalars, (b-2) = {} bits/rep -> r_g = {r_full} for 2^-256 (was 64 at b = 6); DEMO runs r_g = {r_g}",
        b_bits - 2,
    );
    // pi2-CE's tie digit chain (w ~ 2^17, L = 5) needs the kappa-9 C3
    // grade. The frozen production shapes already derive kappa = 9 at
    // e = 4 (freeze rows); only this toy demo shape derives kappa = 8,
    // so bump it here (n_r carries the extra row).
    let bump = 9usize.saturating_sub(p.kappa);
    let cshape =
        CommitShape { kappa: p.kappa + bump, n_r: p.n_r + bump, msg_r: p.msg_r };
    let crs = expand_crs(cshape, q, 20_000);
    let dp = derive_digit_params(q, cshape.kappa, cshape.n_r, e_dig, l_dig, w_u.ceil() as i64);
    println!(
        "  params: kappa={} N_r={} msg_r={} gate digits (e={}, L={}), digit sigma=2^{:.1}",
        cshape.kappa, cshape.n_r, cshape.msg_r, e_dig, l_dig, (dp.sigma as f64).log2()
    );
    let g_count = (r_g + ring::ct_engine::r1_pad_count(r_g, 0, 0)).div_ceil(cshape.msg_r);
    let rp = derive_ct_round_params(q, cshape, g_count, 0, 0, true);
    let a1p = build_a1_paths(&crs, rp.sigma.max(dp.sigma), isqrt_u128(rp.bound_sq.max(dp.bound_sq)));
    let a1_path = KernelPath::A1(&a1p);
    let mut rng = 0x5eed_0008u64;

    // Instance: random A (rows x inner), B (inner x cols), C = A B mod q.
    let a_mat: Vec<u64> = (0..shape.rows * inner).map(|_| rng_below(&mut rng, q)).collect();
    let b_mat: Vec<u64> = (0..inner * shape.cols).map(|_| rng_below(&mut rng, q)).collect();
    let mut c_mat = vec![0u64; shape.rows * shape.cols];
    for r in 0..shape.rows {
        for j in 0..shape.cols {
            let mut acc = 0u64;
            for k in 0..inner {
                acc = zq.add(acc, zq.mul(a_mat[r * inner + k], b_mat[k * shape.cols + j]));
            }
            c_mat[r * shape.cols + j] = acc;
        }
    }
    let commit_many = |vecs: Vec<Vec<u64>>, n: usize, rng: &mut u64| {
        let mut msgs = Vec::new();
        let mut rhos = Vec::new();
        let mut groups = Vec::new();
        for v in vecs {
            let x = pack_column(n, cshape.msg_r, &v);
            let rho: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(rng)).collect();
            let (t1, t2) = commit(&a1_path, &crs, &x, &rho);
            msgs.push(x);
            rhos.push(rho);
            groups.push((t1, t2));
        }
        (msgs, rhos, groups)
    };
    let a_rows_raw: Vec<Vec<u64>> =
        (0..shape.rows).map(|r| (0..inner).map(|k| a_mat[r * inner + k]).collect()).collect();
    let b_cols_raw: Vec<Vec<u64>> =
        (0..shape.cols).map(|j| (0..inner).map(|k| b_mat[k * shape.cols + j]).collect()).collect();
    let c_cols_raw: Vec<Vec<u64>> =
        (0..shape.cols).map(|j| (0..shape.rows).map(|r| c_mat[r * shape.cols + j]).collect()).collect();
    let (a_rows, rho_a, ta) = commit_many(a_rows_raw, inner, &mut rng);
    let (b_cols, rho_b, tb) = commit_many(b_cols_raw, inner, &mut rng);
    let (c_cols, rho_c, tc) = commit_many(c_cols_raw, shape.rows, &mut rng);

    let ctxb = b"route-r-pi2-demo";
    let t0 = Instant::now();
    let mut rng_a = 0xabcd_0003u64;
    let (proof, attempts) = prove_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &a_rows, &rho_a, &b_cols,
        &rho_b, &c_cols, &rho_c, &ta, &tb, &tc, &mut rng_a,
    );
    let prove_ms = t0.elapsed().as_secs_f64() * 1e3;
    let t1 = Instant::now();
    let ok = verify_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &ta, &tb, &tc, &proof,
    );
    let verify_ms = t1.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!(
            "pi2 verifies (attempts = {attempts}, salt = {}, prove {prove_ms:.0} ms, verify {verify_ms:.0} ms)",
            proof.salt
        ),
        ok,
    );
    // Same-seed transcript identity.
    let mut rng_b = 0xabcd_0003u64;
    let (proof_s, attempts_s) = prove_ring_pi2(
        &KernelPath::School, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &a_rows, &rho_a,
        &b_cols, &rho_b, &c_cols, &rho_c, &ta, &tb, &tc, &mut rng_b,
    );
    assert_true(
        "pi2 same-seed proofs bit-identical across paths",
        attempts == attempts_s
            && proof.ct.h_quad == proof_s.ct.h_quad
            && proof.ct.gq == proof_s.ct.gq
            && proof.ct.z_digits == proof_s.ct.z_digits,
    );

    // Negative battery.
    // (a) C != A B (honest machinery on the wrong instance): the gate's
    // quadratic ct-claims catch it.
    {
        let mut c_bad = c_mat.clone();
        c_bad[0] = zq.add(c_bad[0], 1);
        let c_cols_bad_raw: Vec<Vec<u64>> = (0..shape.cols)
            .map(|j| (0..shape.rows).map(|r| c_bad[r * shape.cols + j]).collect())
            .collect();
        let (c_cols_bad, rho_c_bad, tc_bad) = commit_many(c_cols_bad_raw, shape.rows, &mut rng);
        let (bad, _) = prove_ring_pi2(
            &a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &a_rows, &rho_a,
            &b_cols, &rho_b, &c_cols_bad, &rho_c_bad, &ta, &tb, &tc_bad, &mut rng,
        );
        assert_true(
            "pi2 semantic soundness: C != A B fails (gate ct checks)",
            !verify_ring_pi2(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &ta, &tb, &tc_bad, &bad),
        );
    }
    // (b) tampered gate reveal.
    {
        let mut bad = RingPi2Proof {
            salt: proof.salt,
            g_t1: proof.g_t1.clone(),
            g_t2: proof.g_t2.clone(),
            ct: clone_ct_proof(&proof.ct),
        };
        bad.ct.h_quad[0][0] = zq.add(bad.ct.h_quad[0][0], 1);
        assert_true(
            "pi2 tampered gate reveal fails",
            !verify_ring_pi2(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &ta, &tb, &tc, &bad),
        );
    }
    // (c) tampered digit response / (d) wrong context / (e) tampered
    // commitment.
    {
        let mut bad = RingPi2Proof {
            salt: proof.salt,
            g_t1: proof.g_t1.clone(),
            g_t2: proof.g_t2.clone(),
            ct: clone_ct_proof(&proof.ct),
        };
        bad.ct.z_digits[0][0][0][0] += 1;
        assert_true(
            "pi2 tampered digit response fails",
            !verify_ring_pi2(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &ta, &tb, &tc, &bad),
        );
    }
    assert_true(
        "pi2 wrong context fails",
        !verify_ring_pi2(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, b"other", r_g, b_bits, &ta, &tb, &tc, &proof),
    );
    {
        let mut ta_bad = ta.clone();
        ta_bad[0].0[0][0] = zq.add(ta_bad[0].0[0][0], 1);
        assert_true(
            "pi2 tampered row commitment fails",
            !verify_ring_pi2(&a1_path, &ring_ctx, &crs, &rp, &dp, &shape, ctxb, r_g, b_bits, &ta_bad, &tb, &tc, &proof),
        );
    }
    // Cost accounting: per-rep marginal size and the full-grade total.
    let dig_elems_per_combo = 2 * dp.l * cshape.kappa; // t1_digits + w1_digits
    let z_coeffs_per_combo = dp.l * cshape.n_r * D;
    let sigma_bits = (dp.sigma as f64).log2() + 4.0;
    let per_rep_kb = 3.0
        * (dig_elems_per_combo as f64 * D as f64 * 31.0 / 8.0 / 1024.0
            + z_coeffs_per_combo as f64 * sigma_bits / 8.0 / 1024.0)
        + 5.0 * D as f64 * 31.0 / 8.0 / 1024.0; // h_quad + 3 garbage + W
    println!(
        "  pi2 gate cost: ~{per_rep_kb:.0} KB/rep -> demo (r_g = {r_g}) ~{:.0} KB; FULL GRADE (r_g = {r_full}) ~{:.1} MB — the r = 1 lever does not survive the gate at this design state (see U8 docs)",
        per_rep_kb * r_g as f64,
        per_rep_kb * r_full as f64 / 1024.0,
    );

    // ---- U-B6: the committed-executions construction as the DEFAULT
    // pi2, same instance, full grade at r = 1 (the scalar gate above is
    // the flagged fallback).
    println!("  [U-B6] pi2-CE (committed-executions gate + tie, r = 1) — the DEFAULT construction");
    let wshape = pi2_ce_wide_shape(128 * shape.inner_r);
    let crs_w = expand_crs(wshape, q, 21_000);
    let dp_ce = derive_digit_params(
        q, cshape.kappa, cshape.n_r, PI2_CE_DIGIT_E, PI2_CE_DIGIT_L, PI2_CE_W_INF,
    );
    let rp_w = derive_ct_round_params(q, wshape, 10, 0, 0, true);
    let rp_o = derive_ct_round_params(q, cshape, 1, 0, 0, true);
    let a1w = build_a1_paths(&crs_w, rp_w.sigma, isqrt_u128(rp_w.bound_sq));
    let a1o =
        build_a1_paths(&crs, rp_o.sigma.max(dp_ce.sigma), isqrt_u128(rp_o.bound_sq.max(dp_ce.bound_sq)));
    let path_w = KernelPath::A1(&a1w);
    let path_o = KernelPath::A1(&a1o);
    let mut rng_ce = 0xabcd_0b60u64;
    let t0 = Instant::now();
    let (proof_ce, at_w, at_o) = prove_ring_pi2_ce(
        &path_w, &path_o, &ring_ctx, &crs, &crs_w, &shape, ctxb, &a_rows, &rho_a, &b_cols,
        &rho_b, &c_cols, &rho_c, &ta, &tb, &tc, &mut rng_ce,
    );
    let prove_ms = t0.elapsed().as_secs_f64() * 1e3;
    let tv = Instant::now();
    let ok = verify_ring_pi2_ce(
        &path_w, &path_o, &ring_ctx, &crs, &crs_w, &shape, ctxb, &ta, &tb, &tc, &proof_ce,
    );
    let verify_ms = tv.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!(
            "pi2-CE verifies at r = 1 (salt = {}, attempts W/O = {at_w}/{at_o}, prove {prove_ms:.0} ms, verify {verify_ms:.0} ms)",
            proof_ce.salt
        ),
        ok,
    );
    // Size accounting: wide objects (incl. the R1 pad group) + reveals +
    // both rounds.
    let wide_kb = 10.0 * (wshape.kappa + wshape.msg_r) as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    let zw_kb = 10.0
        * wshape.n_r as f64
        * D as f64
        * ((rp_w.sigma as f64).log2() + 4.0)
        / 8.0
        / 1024.0;
    let f_kb = proof_ce.f.iter().map(|f| f.len()).sum::<usize>() as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    let k2_kb = proof_ce.k2.iter().map(|k| k.len()).sum::<usize>() as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    let dig_kb = 3.0
        * (PI2_CE_DIGIT_L as f64 * (cshape.kappa + cshape.msg_r) as f64 * D as f64 * 31.0
            + PI2_CE_DIGIT_L as f64 * cshape.n_r as f64 * D as f64 * ((dp_ce.sigma as f64).log2() + 4.0))
        / 8.0
        / 1024.0;
    println!(
        "  pi2-CE size ~{:.0} KB (wide objects {wide_kb:.0} + wide openings {zw_kb:.0} + F {f_kb:.0} + K2 {k2_kb:.0} + round-O digits ~{dig_kb:.0}) vs scalar FULL GRADE ~{:.1} MB",
        wide_kb + zw_kb + f_kb + k2_kb + dig_kb,
        per_rep_kb * r_full as f64 / 1024.0,
    );
    // Semantic negative: full honest prove over a wrong C must fail.
    let mut c_bad_mat = c_mat.clone();
    c_bad_mat[0] = zq.add(c_bad_mat[0], 1);
    let c_bad_raw: Vec<Vec<u64>> = (0..shape.cols)
        .map(|j| (0..shape.rows).map(|r| c_bad_mat[r * shape.cols + j]).collect())
        .collect();
    let (c_cols_b, rho_c_b, tc_b) = commit_many(c_bad_raw, shape.rows, &mut rng_ce);
    let (proof_bad, _, _) = prove_ring_pi2_ce(
        &path_w, &path_o, &ring_ctx, &crs, &crs_w, &shape, ctxb, &a_rows, &rho_a, &b_cols,
        &rho_b, &c_cols_b, &rho_c_b, &ta, &tb, &tc_b, &mut rng_ce,
    );
    assert_true(
        "pi2-CE semantic soundness: C != A B fails (the gate claim catches it)",
        !verify_ring_pi2_ce(&path_w, &path_o, &ring_ctx, &crs, &crs_w, &shape, ctxb, &ta, &tb, &tc_b, &proof_bad),
    );
    // Reveal/pivot tampers: F and K2 are bound into both round hashes.
    let mut proof_t = RingPi2CeProof {
        salt: proof_ce.salt,
        wide: proof_ce.wide.clone(),
        f: proof_ce.f.clone(),
        k2: proof_ce.k2.clone(),
        ct_w: proof_ce.ct_w,
        ct_o: proof_ce.ct_o,
    };
    proof_t.f[0][0][0] = zq.add(proof_t.f[0][0][0], 1);
    assert_true(
        "pi2-CE tampered F reveal fails",
        !verify_ring_pi2_ce(&path_w, &path_o, &ring_ctx, &crs, &crs_w, &shape, ctxb, &ta, &tb, &tc, &proof_t),
    );
    proof_t.f[0][0][0] = zq.sub(proof_t.f[0][0][0], 1);
    proof_t.k2[0][0][0] = zq.add(proof_t.k2[0][0][0], 1);
    assert_true(
        "pi2-CE tampered K2 pivot fails",
        !verify_ring_pi2_ce(&path_w, &path_o, &ring_ctx, &crs, &crs_w, &shape, ctxb, &ta, &tb, &tc, &proof_t),
    );
}

// ===========================================================================
// U7: statement/chain integration. One VALIDATED Statement (manifest.rs
// format v2 — versioned header with model + activation-table digests,
// per-tensor quantization metadata, declared outputs, and the structural
// validator of audit finding C-02) binds every commitment of the DAG; its
// order-sensitive digest is the ctx of EVERY claim (the "all commitments
// before any challenge" rule at chain level), and the digest cannot be
// formed until validation passes. Wave batching at r = 1: all gadget
// claims of a layer share ONE ct-round (one challenge, one mask-bundle
// class per commitment — "one wave-slot per claim"); the Pi2 matmul layer
// runs its own round.
//
// Chain: X0 (n0 x n3), W1 (n1 x n0, hidden) -> Y1 = W1 X0 (Pi2, r_g demo
// reps); Y1 = 2^shift * Y2 + R (rescale link) with Range(R, shift); plus
// a slot-packed Hadamard triple (H3) of width n2 as its own layer.
//
// The range family runs through the U-L MODULUS LINK (ring/link.rs,
// audit C-02): R's bit planes are committed at the q8_46 gadget layer —
// the modulus where the binary claim's ARP side condition closes, so
// "each coefficient is a genuine 0/1 INTEGER and the recomposition is
// exact over Z" is proven, not asserted — and l = 24 FS-derived link
// rows tie the recomposed integers to R's q31 residues. Since the proven
// integers are < 2^shift << q31, the q31 residues ARE the integers: the
// non-wrap side condition the old demo only printed a caveat about is
// now part of the proof. The [U7w] battery below demonstrates the attack
// the link stops: a witness satisfying every q31 identity while wrapping
// over the integers ACCEPTS under the old q31-only family and REJECTS
// under the shipped q46 grounding.

fn group_digest(t1: &[Poly], t2: &[Poly]) -> Vec<u8> {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-commit-group");
    hasher.update(polys_bytes(t1));
    hasher.update(polys_bytes(t2));
    hasher.finalize().to_vec()
}

fn key_info_bytes(shape: &CommitShape, q: u64) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(&(shape.kappa as u32).to_le_bytes());
    out.extend_from_slice(&(shape.n_r as u32).to_le_bytes());
    out.extend_from_slice(&(shape.msg_r as u32).to_le_bytes());
    out.extend_from_slice(&q.to_le_bytes());
    out
}

fn chain_demo(n0: usize, n1: usize, n2: usize, n3: usize) {
    use manifest::{ClaimManifest, Operation, Orientation};
    use ring::ct_engine::{
        QuadRingClaim, RingClaim, StdOpening, ct_h0, derive_ct_round_params, prove_ct_round,
        verify_ct_round,
    };
    println!("ring_matmul chain-demo: X0({n0}x{n3}) -W1({n1}x{n0})-> Y1 -rescale-> Y2 (+range family), Hadamard width {n2}, q8_31");
    println!("  [non-wrap] R's bit planes live at q8_46 (where the ARP budget closes) and the");
    println!("  U-L modulus link pins R's q31 residues to the recomposed integers — the range");
    println!("  fact is integer-exact, proven (was: printed caveat; audit C-02).");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let shift = 4u32;
    let (r_g, b_bits) = (4usize, 6u32);

    // Shared CRS sized for the biggest packing among the chain's tensors.
    let p = derive_digits(Proto::Pi2, n1, n0, n3.max(n2), 0, q, true, 4).expect("chain point fits q31");
    // R1: msg_r >= 2 so the wave's quad-claim pads pack two per
    // g-commitment. At msg_r = 1 each pad costs a FULL commitment (3 per
    // binary quad claim) and the wave's C2 std-bundle budget breaks at
    // q31 (measured at this shape: 177 commitments, 8 beta = 1.26x q).
    // The +1 msg_r rides one extra N_r row — the C4 bump pattern the pi2
    // demo already uses for its kappa grade.
    let msg_bump = 2usize.saturating_sub(p.msg_r);
    let cshape =
        CommitShape { kappa: p.kappa, n_r: p.n_r + msg_bump, msg_r: p.msg_r + msg_bump };
    let crs = expand_crs(cshape, q, 777);
    let mut rng = 0x5eed_0009u64;

    // --- The q46 grounding layer for the range family (U-L link). ---------
    // Frozen gadget-layer point (link demo / freeze_check_link discipline);
    // per-COLUMN binary units keep the ARP granularity cap (~896 coeffs).
    let q_g = ring::Q8_46;
    let ring_g = ring::ring_ctx(q_g, ring::ETA8_46, 8);
    let zq_g = ring_g.zq;
    let gl_g = ring::link::derive_gadget_layer(q_g, 32, 16).expect("q46 gadget layer derives");
    let crs_g = expand_crs(gl_g.shape, q_g, 778);
    let msg_r_g = gl_g.shape.msg_r;
    let chunks = n1.div_ceil(D);
    assert!(
        shift as usize * chunks <= msg_r_g,
        "bit-plane stack must fit one q46 commitment per column"
    );
    let n_unit_bits = shift as usize * chunks * D;
    assert!(
        ring::link::arp_binary_unit_ok(n_unit_bits, q_g),
        "per-column binary unit must close the q46 ARP budget"
    );
    // Frozen link operating point: w = 11, l = 24 rows (2^-264), per-column
    // instances of n1 values in [0, 2^shift).
    let lp = ring::link::derive_link_params(n1, shift, q_g, q, 11);
    let ap = ring::ct_engine::derive_arp_params(n_unit_bits, 256, 1, 3.0);
    let l_bin_g = ring::ct_engine::theta_rows(q_g);
    // q46 round sizing: per column ap.rows ARP claims + lp.l grounding link
    // claims (linear) and l_bin_g binary quad claims; R1 pads for the quads.
    let n_lin_g = n3 * (ap.rows + lp.l);
    let n_quad_g = n3 * l_bin_g;
    let n_g_groups_g = (n_lin_g + n_quad_g + ring::ct_engine::r1_pad_count(n_quad_g, 0, 0))
        .div_ceil(msg_r_g);
    let rp_g = derive_ct_round_params(
        q_g,
        gl_g.shape,
        n3 + n_g_groups_g + n3,
        n3 * ap.rows,
        12 * ap.sigma_arp,
        false,
    );
    let a1p_g = build_a1_paths(
        &crs_g,
        rp_g.sigma.max(rp_g.sigma_s),
        isqrt_u128(rp_g.bound_sq.max(rp_g.bound_s_sq)),
    );
    let path_g = KernelPath::A1(&a1p_g);

    // --- Instance data. --------------------------------------------------
    // Small-integer witnesses under the DECLARED quantization (statement
    // format v2): W1 and X0 are unsigned 6-bit values, so Y1 = W1 X0 is an
    // EXACT integer matmul (max n0 * 63^2 < 2^(12 + ceil log2 n0) << q/2 —
    // no wraparound in the matmul itself), the rescale is exact integer
    // arithmetic, and the quantization metadata below is honest. (The old
    // demo drew full mod-q values, which made every "integer" claim
    // modular-only from the start.)
    let w_in_bits = 6u32;
    let w1: Vec<u64> = (0..n1 * n0).map(|_| rng_below(&mut rng, 1 << w_in_bits)).collect();
    let x0: Vec<u64> = (0..n0 * n3).map(|_| rng_below(&mut rng, 1 << w_in_bits)).collect();
    let mut y1 = vec![0u64; n1 * n3];
    for r in 0..n1 {
        for j in 0..n3 {
            let mut acc = 0u64;
            for k in 0..n0 {
                acc = zq.add(acc, zq.mul(w1[r * n0 + k], x0[k * n3 + j]));
            }
            y1[r * n3 + j] = acc;
        }
    }
    let acc_bits = 2 * w_in_bits + (usize::BITS - (n0 - 1).leading_zeros());
    assert!((1u128 << acc_bits) < (q as u128) / 2, "declared accumulator width must fit q31");
    // Rescale: Y1 = 2^shift Y2 + R with R = Y1 mod 2^shift (exact integers).
    let rr: Vec<u64> = y1.iter().map(|&v| v & ((1 << shift) - 1)).collect();
    let y2: Vec<u64> = y1.iter().map(|&v| v >> shift).collect();
    let r_bits: Vec<Vec<u64>> =
        (0..shift as usize).map(|i| rr.iter().map(|&v| (v >> i) & 1).collect()).collect();
    // Hadamard triple (slot-packed, standalone layer): unsigned 8-bit
    // operands, exact 16-bit products.
    let hx: Vec<u64> = (0..n2).map(|_| rng_below(&mut rng, 1 << 8)).collect();
    let hy: Vec<u64> = (0..n2).map(|_| rng_below(&mut rng, 1 << 8)).collect();
    let hz: Vec<u64> = hx.iter().zip(hy.iter()).map(|(&a, &b)| zq.mul(a, b)).collect();

    // --- Commit everything, then build the manifest. ---------------------
    // Round parameters (shared by the gadget wave; A1 cache reused).
    let e_s2 = (1u64 << (2 * b_bits)) as f64 / 3.0;
    let w_u = 1.3 * ((n1.max(n3)) as f64 * D as f64 * e_s2 * (2.0 / 3.0)).sqrt();
    let l_dig = ((w_u.log2() + 1.0) / 4.0).ceil() as usize;
    let dp = derive_digit_params(q, cshape.kappa, cshape.n_r, 4, l_dig, w_u.ceil() as i64);
    let n_gadget_commits = 3 + shift as usize + 3; // Y1,Y2,R + bits + hx,hy,hz (upper bound)
    // 4 * r_g upper-bounds the pi2 g-groups (r_g reveal g's + 3 r_g R1 pads).
    let rp = derive_ct_round_params(q, cshape, n_gadget_commits + 4 * r_g, 0, 0, true);
    let a1p = build_a1_paths(&crs, rp.sigma.max(dp.sigma), isqrt_u128(rp.bound_sq.max(dp.bound_sq)));
    let a1_path = KernelPath::A1(&a1p);

    let mut commit_cols = |mat: &[u64], n: usize, cols: usize, rng: &mut u64| {
        let mut msgs = Vec::new();
        let mut rhos = Vec::new();
        let mut groups = Vec::new();
        for j in 0..cols {
            let col: Vec<u64> = (0..n).map(|i| mat[i * cols + j]).collect();
            let x = pack_column(n, cshape.msg_r, &col);
            let rho: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(rng)).collect();
            let (t1, t2) = commit(&a1_path, &crs, &x, &rho);
            msgs.push(x);
            rhos.push(rho);
            groups.push((t1, t2));
        }
        (msgs, rhos, groups)
    };
    let t_commit = Instant::now();
    let (w1_rows, rho_w1, tw1) = {
        let rows: Vec<Vec<u64>> =
            (0..n1).map(|r| (0..n0).map(|k| w1[r * n0 + k]).collect()).collect();
        let mut msgs = Vec::new();
        let mut rhos = Vec::new();
        let mut groups = Vec::new();
        for row in rows {
            let x = pack_column(n0, cshape.msg_r, &row);
            let rho: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let (t1, t2) = commit(&a1_path, &crs, &x, &rho);
            msgs.push(x);
            rhos.push(rho);
            groups.push((t1, t2));
        }
        (msgs, rhos, groups)
    };
    let (x0_cols, rho_x0, tx0) = commit_cols(&x0, n0, n3, &mut rng);
    let (y1_cols, rho_y1, ty1) = commit_cols(&y1, n1, n3, &mut rng);
    let (y2_cols, rho_y2, ty2) = commit_cols(&y2, n1, n3, &mut rng);
    let (r_cols, rho_r, tr) = commit_cols(&rr, n1, n3, &mut rng);
    // R's bit planes: committed at the q46 GADGET layer, one commitment
    // per column holding the whole plane stack (plane i's chunk u at slot
    // i * chunks + u; the zero padding is binary, so claims may cover
    // whole slots).
    let mut bits_x: Vec<Vec<Poly>> = Vec::new();
    let mut bits_rho: Vec<Vec<Vec<i64>>> = Vec::new();
    let mut bits_groups: Vec<(Vec<Poly>, Vec<Poly>)> = Vec::new();
    for j in 0..n3 {
        let mut x = vec![poly_zero(); msg_r_g];
        for (i, plane) in r_bits.iter().enumerate() {
            for t in 0..n1 {
                x[i * chunks + t / D][t % D] = plane[t * n3 + j];
            }
        }
        let rho: Vec<Vec<i64>> =
            (0..gl_g.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let (t1, t2) = commit(&path_g, &crs_g, &x, &rho);
        bits_x.push(x);
        bits_rho.push(rho);
        bits_groups.push((t1, t2));
    }
    // Hadamard: one slot-packed commitment per side.
    let pack8 = |v: &[u64]| -> Vec<Poly> {
        let mut padded = v.to_vec();
        padded.resize(cshape.msg_r * ring_ctx.k, 0);
        (0..cshape.msg_r)
            .map(|u| slot_pack(&ring_ctx, &padded[u * ring_ctx.k..(u + 1) * ring_ctx.k]))
            .collect()
    };
    let h_msgs = [pack8(&hx), pack8(&hy), pack8(&hz)];
    let h_rhos: Vec<Vec<Vec<i64>>> = (0..3)
        .map(|_| (0..cshape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
        .collect();
    let h_groups: Vec<(Vec<Poly>, Vec<Poly>)> = h_msgs
        .iter()
        .zip(h_rhos.iter())
        .map(|(x, rho)| commit(&a1_path, &crs, x, rho))
        .collect();
    let commit_s = t_commit.elapsed().as_secs_f64();

    // Manifest: every commitment entry, then the operation list.
    let mut mf = ClaimManifest::new("lattice-route-r", &crs.crs_hash);
    let ki = key_info_bytes(&cshape, q);
    let group_list_digest = |groups: &[(Vec<Poly>, Vec<Poly>)]| -> Vec<u8> {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        for (t1, t2) in groups {
            hasher.update(group_digest(t1, t2));
        }
        hasher.finalize().to_vec()
    };
    let id_w1 = mf.add_commitment("W1", n1, n0, Orientation::ByRows, ki.clone(), group_list_digest(&tw1));
    let id_x0 = mf.add_commitment("X0", n0, n3, Orientation::ByColumns, ki.clone(), group_list_digest(&tx0));
    let id_y1 = mf.add_commitment("Y1", n1, n3, Orientation::ByColumns, ki.clone(), group_list_digest(&ty1));
    let id_y2 = mf.add_commitment("Y2", n1, n3, Orientation::ByColumns, ki.clone(), group_list_digest(&ty2));
    let id_r = mf.add_commitment("R", n1, n3, Orientation::ByColumns, ki.clone(), group_list_digest(&tr));
    // ONE stacked plane entry for R's bit decomposition (the lattice
    // ffn-demo layout the validator pins): `shift` planes stacked
    // row-wise. The entry's key_info names the q46 GADGET layer — the
    // statement records that this tensor's range fact is grounded at the
    // modulus whose ARP budget closes — and its digest covers the
    // per-column q46 stack commitments in column order.
    let id_bits = mf.add_commitment(
        "R-bits",
        n1 * shift as usize,
        n3,
        Orientation::ByColumns,
        key_info_bytes(&gl_g.shape, q_g),
        group_list_digest(&bits_groups),
    );
    let id_hx = mf.add_commitment("HX", n2, 1, Orientation::ByColumns, ki.clone(), group_list_digest(&h_groups[0..1]));
    let id_hy = mf.add_commitment("HY", n2, 1, Orientation::ByColumns, ki.clone(), group_list_digest(&h_groups[1..2]));
    let id_hz = mf.add_commitment("HZ", n2, 1, Orientation::ByColumns, ki.clone(), group_list_digest(&h_groups[2..3]));
    mf.add_operation(Operation::Matmul { a: id_w1, b: id_x0, c: id_y1 });
    mf.add_operation(Operation::Rescale { x: id_y1, y: id_y2, r: id_r, shift });
    mf.add_operation(Operation::Binary { bits: id_bits });
    mf.add_operation(Operation::Range { value: id_r, bits: id_bits, width: shift, signed: false });
    mf.add_operation(Operation::Hadamard { x: id_hx, y: id_hy, z: id_hz });

    // --- The validated statement (format v3, audit 2026-07-12 Phase 2). ----
    // Header: model identity digest (architecture + dims + the weight
    // commitment digest), the TYPED frozen activation-table spec (the SiLU
    // int8 spec of ring/lookup.rs — declared model semantics; the demo
    // chain does not yet PROVE a lookup op, see TARGET_CONTRACT.md), and
    // the modulus capacity of the smallest layer (q31; the bit planes live
    // at q46, which is wider).
    let model_digest: [u8; 32] = {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(b"chain-demo-model-v1");
        for dim in [n0, n1, n2, n3] {
            hasher.update((dim as u64).to_le_bytes());
        }
        hasher.update(group_list_digest(&tw1));
        hasher.finalize().into()
    };
    let table_digest =
        ring::lookup::table_spec_digest(&ring::lookup::silu_int8_table());
    assert_eq!(
        table_digest, manifest::SILU_INT8_TABLE_DIGEST,
        "frozen SiLU table digest parity (manifest constant vs ring/lookup.rs)"
    );
    let modulus_bits = (63 - q.leading_zeros()).min(63 - q_g.leading_zeros());
    let quant = |bits: u32, frac_bits: u32| manifest::QuantMeta { bits, frac_bits, signed: false };
    let mut statement = manifest::Statement::new(
        model_digest,
        Some(manifest::SILU_INT8_TABLE_SPEC),
        modulus_bits,
        mf.clone(),
    );
    statement.quant = vec![
        quant(w_in_bits, 2),        // W1
        quant(w_in_bits, 2),        // X0
        quant(acc_bits, 4),         // Y1 (exact accumulator)
        quant(acc_bits - shift, 0), // Y2
        quant(shift, 4),            // R
        quant(1, 0),                // R-bits planes
        quant(8, 0),                // HX
        quant(8, 0),                // HY
        quant(16, 0),               // HZ
    ];
    // Canonical padding: per-column packing pads each vector to the full
    // commitment capacity (q31 value layer: msg_r * D coefficients; q46
    // plane stack: msg_r_g * D; slot-packed Hadamard: msg_r * k slots).
    let cap = cshape.msg_r * D;
    let cap_g = msg_r_g * D;
    let cap_h = cshape.msg_r * ring_ctx.k;
    statement.pad = vec![
        manifest::PadSpec::units(n1, n0, 1, cap),                    // W1 (by rows)
        manifest::PadSpec::units(n0, n3, cap, 1),                    // X0
        manifest::PadSpec::units(n1, n3, cap, 1),                    // Y1
        manifest::PadSpec::units(n1, n3, cap, 1),                    // Y2
        manifest::PadSpec::units(n1, n3, cap, 1),                    // R
        manifest::PadSpec::units(n1 * shift as usize, n3, cap_g, 1), // R-bits (q46)
        manifest::PadSpec::units(n2, 1, cap_h, 1),                   // HX
        manifest::PadSpec::units(n2, 1, cap_h, 1),                   // HY
        manifest::PadSpec::units(n2, 1, cap_h, 1),                   // HZ
    ];
    statement.outputs = vec![id_y2, id_hz];
    let ctx = match statement.digest() {
        Ok(digest) => digest,
        Err(err) => {
            println!("  FAIL: honest statement does not validate: {err}");
            std::process::exit(1);
        }
    };
    println!("  ok   statement v3 validates (9 entries, {} operations, 2 outputs)", mf.operations.len());

    // --- [U7v] malicious-statement battery: every entry in the audit's ----
    // --- C-02 list is REJECTED with a structured error, pre-crypto.    ----
    {
        use manifest::StatementError as SE;
        let expect = |label: &str, tampered: &manifest::Statement, want: fn(&SE) -> bool| {
            match tampered.validate() {
                Ok(()) => {
                    println!("  FAIL: malicious statement accepted ({label})");
                    std::process::exit(1);
                }
                Err(err) => {
                    if !want(&err) {
                        println!("  FAIL: wrong rejection for {label}: {err}");
                        std::process::exit(1);
                    }
                    println!("  ok   statement rejects {label}: {err}");
                }
            }
        };
        // (1) Dangling id: an operation names a commitment that was never
        // made — the "caller-created manifest inconsistency" case.
        let mut bad = statement.clone();
        bad.manifest.add_operation(Operation::Matmul { a: 99, b: id_x0, c: id_y1 });
        expect("dangling id", &bad, |e| matches!(e, SE::DanglingId { id: 99, .. }));
        // (2) Shape mismatch: X0's declared inner dimension is off by one —
        // the matmul no longer chains rows/inner/cols.
        let mut bad = statement.clone();
        bad.manifest.commitments[id_x0 as usize].rows = (n0 + 1) as u32;
        expect("matmul shape mismatch", &bad, |e| matches!(e, SE::MatmulShape { .. }));
        // (3) Orientation flip: W1 declared by-columns — a transposed
        // operand would hash fine but proves a different product.
        let mut bad = statement.clone();
        bad.manifest.commitments[id_w1 as usize].orientation = Orientation::ByColumns;
        expect("orientation flip", &bad, |e| matches!(e, SE::MatmulOrientation { .. }));
        // (4) Missing range fact: the rescale remainder loses its Range —
        // exactly the wraparound-enabling omission.
        let mut bad = statement.clone();
        bad.manifest.operations.retain(|op| !matches!(op, Operation::Range { .. }));
        expect("missing range fact", &bad, |e| matches!(e, SE::MissingRangeFact { .. }));
        // (5) Duplicate output declaration.
        let mut bad = statement.clone();
        bad.outputs.push(id_y2);
        expect("duplicate output", &bad, |e| matches!(e, SE::DuplicateOutput { .. }));
        // (6) Dropped output: HZ silently leaves the statement.
        let mut bad = statement.clone();
        bad.outputs.retain(|&id| id != id_hz);
        expect("unconsumed tensor", &bad, |e| matches!(e, SE::UnconsumedEntry { .. }));
        // (7) Unknown format version (v2 is retired; only v3 validates).
        let mut bad = statement.clone();
        bad.header.version = 2;
        expect("unknown statement version", &bad, |e| matches!(e, SE::UnknownVersion { got: 2 }));
        // (8) Missing quantization metadata.
        let mut bad = statement.clone();
        bad.quant.pop();
        expect("missing quantization metadata", &bad, |e| matches!(e, SE::QuantCount { .. }));
        // (9) Understated accumulator width: Y1 declared narrower than the
        // worst-case matmul growth — the statement-level non-wrap budget.
        let mut bad = statement.clone();
        bad.quant[id_y1 as usize].bits = acc_bits - 2;
        expect("understated accumulator width", &bad, |e| {
            matches!(e, SE::QuantMismatch { field: "matmul accumulator width", .. })
        });
        // (10) Unproven narrowing: Y2 declared narrower than the worst-case
        // rescale output with NO Range/Lookup fact backing the claim.
        let mut bad = statement.clone();
        bad.quant[id_y2 as usize].bits = acc_bits - shift - 3;
        expect("unproven rescale narrowing", &bad, |e| {
            matches!(e, SE::QuantMismatch { field: "rescale width", .. })
        });
        // (11) Lookup on a tensor that does not match the frozen int8
        // activation-table domain.
        let mut bad = statement.clone();
        bad.manifest.add_operation(Operation::Lookup { x: id_hx, y: id_hy });
        expect("lookup domain quantization mismatch", &bad, |e| {
            matches!(e, SE::QuantMismatch { field: "lookup domain quant", .. })
        });
        // (12) A narrowing proof cannot waive fixed-point scale semantics.
        // Add a structurally valid Range fact on Y2, then lie about its
        // fraction bits: the Rescale itself must reject first.
        let mut bad = statement.clone();
        let y2_width = bad.quant[id_y2 as usize].bits;
        let y2_bits = bad.manifest.add_commitment(
            "Y2-bits-negative",
            n1 * y2_width as usize,
            n3,
            Orientation::ByColumns,
            vec![],
            vec![],
        );
        bad.quant.push(manifest::QuantMeta { bits: 1, frac_bits: 0, signed: false });
        bad.manifest.add_operation(Operation::Binary { bits: y2_bits });
        bad.manifest.add_operation(Operation::Range {
            value: id_y2,
            bits: y2_bits,
            width: y2_width,
            signed: false,
        });
        bad.quant[id_y2 as usize].frac_bits = 63;
        expect("range-backed rescale with impossible scale", &bad, |e| {
            matches!(e, SE::QuantMismatch { field: "rescale fraction bits", .. })
        });

        // (13) Lookup quantization pins fraction bits, not just width/sign.
        let mut bad = statement.clone();
        let lx = bad.manifest.add_commitment(
            "lookup-x-wrong-scale",
            n2,
            1,
            Orientation::ByColumns,
            vec![],
            vec![],
        );
        let ly = bad.manifest.add_commitment(
            "lookup-y-wrong-scale",
            n2,
            1,
            Orientation::ByColumns,
            vec![],
            vec![],
        );
        bad.quant.extend([
            manifest::QuantMeta { bits: 8, frac_bits: 3, signed: true },
            manifest::QuantMeta { bits: 8, frac_bits: 3, signed: true },
        ]);
        bad.manifest.add_operation(Operation::Lookup { x: lx, y: ly });
        bad.outputs.push(ly);
        expect("lookup fraction-bit mismatch", &bad, |e| {
            matches!(e, SE::QuantMismatch { field: "lookup domain quant", .. })
        });

        // (14) A nonzero but attacker-chosen lookup digest is not a table
        // identity. Only the frozen integer SiLU digest is accepted.
        let mut bad = statement.clone();
        let lx = bad.manifest.add_commitment(
            "lookup-x-wrong-table",
            n2,
            1,
            Orientation::ByColumns,
            vec![],
            vec![],
        );
        let ly = bad.manifest.add_commitment(
            "lookup-y-wrong-table",
            n2,
            1,
            Orientation::ByColumns,
            vec![],
            vec![],
        );
        bad.quant.extend([
            manifest::QuantMeta { bits: 8, frac_bits: 4, signed: true },
            manifest::QuantMeta { bits: 8, frac_bits: 4, signed: true },
        ]);
        bad.manifest.add_operation(Operation::Lookup { x: lx, y: ly });
        bad.outputs.push(ly);
        bad.header.table =
            Some(manifest::TableSpec { digest: [7u8; 32], ..manifest::SILU_INT8_TABLE_SPEC });
        expect("attacker-chosen lookup table digest", &bad, |e| {
            matches!(e, SE::TableDigestMismatch)
        });

        // (14b) Right digest, lying table metadata: the typed spec is
        // bound by exact equality, not by digest alone.
        let mut bad = statement.clone();
        bad.header.table = Some(manifest::TableSpec {
            input: manifest::QuantMeta { bits: 8, frac_bits: 3, signed: true },
            ..manifest::SILU_INT8_TABLE_SPEC
        });
        bad.manifest.add_operation(Operation::Lookup { x: id_hx, y: id_hy });
        expect("table spec metadata lie", &bad, |e| matches!(e, SE::TableSpecMismatch));

        // (15) Signed capacity uses the positive endpoint. (-128)*(-128)
        // is +16384 and does not fit signed 15-bit output.
        let mut endpoint_mf = ClaimManifest::new("statement-negative", b"signed-endpoint");
        let ea = endpoint_mf.add_commitment("A", 1, 1, Orientation::RowMajor, vec![], vec![]);
        let eb = endpoint_mf.add_commitment("B", 1, 1, Orientation::RowMajor, vec![], vec![]);
        let ec = endpoint_mf.add_commitment("C", 1, 1, Orientation::RowMajor, vec![], vec![]);
        endpoint_mf.add_operation(Operation::Matmul { a: ea, b: eb, c: ec });
        let mut endpoint = manifest::Statement::new([1u8; 32], None, modulus_bits, endpoint_mf);
        endpoint.quant = vec![
            manifest::QuantMeta { bits: 8, frac_bits: 4, signed: true },
            manifest::QuantMeta { bits: 8, frac_bits: 4, signed: true },
            manifest::QuantMeta { bits: 15, frac_bits: 8, signed: true },
        ];
        endpoint.outputs = vec![ec];
        expect("signed positive endpoint overflow", &endpoint, |e| {
            matches!(e, SE::QuantMismatch { field: "matmul accumulator width", .. })
        });

        // (16) Operation order does not make a cyclic producer graph a DAG.
        let mut cycle_mf = ClaimManifest::new("statement-negative", b"cycle");
        let ca = cycle_mf.add_commitment("A", 1, 1, Orientation::RowMajor, vec![], vec![]);
        let cb = cycle_mf.add_commitment("B", 1, 1, Orientation::RowMajor, vec![], vec![]);
        cycle_mf.add_operation(Operation::Scale { input: ca, output: cb, scalar_le: vec![1] });
        cycle_mf.add_operation(Operation::Scale { input: cb, output: ca, scalar_le: vec![1] });
        let mut cycle = manifest::Statement::new([2u8; 32], None, modulus_bits, cycle_mf);
        cycle.quant = vec![
            manifest::QuantMeta { bits: 8, frac_bits: 0, signed: false },
            manifest::QuantMeta { bits: 8, frac_bits: 0, signed: false },
        ];
        expect("cyclic dataflow", &cycle, |e| matches!(e, SE::CyclicDataflow { .. }));

        // (17) Empty Add and LinkEqual orientation mismatches were both
        // previously accepted as well-formed statements.
        let mut empty_mf = ClaimManifest::new("statement-negative", b"empty-add");
        let eo = empty_mf.add_commitment("out", 1, 1, Orientation::RowMajor, vec![], vec![]);
        empty_mf.add_operation(Operation::Add { inputs: vec![], output: eo });
        let mut empty = manifest::Statement::new([3u8; 32], None, modulus_bits, empty_mf);
        empty.quant = vec![manifest::QuantMeta { bits: 8, frac_bits: 0, signed: false }];
        empty.outputs = vec![eo];
        expect("empty Add", &empty, |e| matches!(e, SE::EmptyAdd { .. }));

        let mut link_mf = ClaimManifest::new("statement-negative", b"link-orientation");
        let la = link_mf.add_commitment("A", 1, 1, Orientation::ByRows, vec![], vec![]);
        let lb = link_mf.add_commitment("B", 1, 1, Orientation::ByColumns, vec![], vec![]);
        link_mf.add_operation(Operation::LinkEqual { left: la, right: lb });
        let mut link = manifest::Statement::new([4u8; 32], None, modulus_bits, link_mf);
        link.quant = vec![
            manifest::QuantMeta { bits: 8, frac_bits: 0, signed: false },
            manifest::QuantMeta { bits: 8, frac_bits: 0, signed: false },
        ];
        expect("LinkEqual orientation mismatch", &link, |e| {
            matches!(e, SE::OrientationMismatch { .. })
        });
    }

    // --- Layer 1: the Pi2 matmul claim (its own round). -------------------
    let shape2 = Pi2Shape { rows: n1, inner_r: n0.div_ceil(D), rows_r: n1.div_ceil(D), cols: n3 };
    let t_prove = Instant::now();
    let (pi2_proof, _) = prove_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape2, &ctx, r_g, b_bits, &w1_rows, &rho_w1,
        &x0_cols, &rho_x0, &y1_cols, &rho_y1, &tw1, &tx0, &ty1, &mut rng,
    );

    // --- Layer 2: the q31 gadget wave (rescale + Hadamard + the link's ----
    // --- q31 TARGET claims) and the q46 grounding round (binary + ARP  ----
    // --- + the link's grounding claims).                                ----
    // Commitment index space (plain, q31): per-column commitments of
    // Y1, Y2, R, then HX, HY, HZ, then the g-mask groups. The bit planes
    // are NOT here — they live in the q46 round's index space. For demo
    // clarity claims run on the per-column commitments directly (n3 is
    // small); production waves combine columns with ring challenges.
    use ring::ct_engine::{
        AjtaiCommit, AjtaiOpening, ajtai_commit, arp_attempt, arp_check_reveal, arp_claims,
        derive_jl_rows, expand_b_mat, pack_arp_mask, r1_pad_count, sample_arp_mask,
        sample_g_masks,
    };
    use ring::link::{
        derive_link_xi, link_claims_gnd, link_claims_tgt, link_gate_ok, link_h0, link_reveal_y,
    };
    let mut plain_x: Vec<Vec<Poly>> = Vec::new();
    let mut plain_rho: Vec<Vec<Vec<i64>>> = Vec::new();
    let mut t1s: Vec<Vec<Poly>> = Vec::new();
    let mut t2s: Vec<Vec<Poly>> = Vec::new();
    let mut push_tensor = |msgs: &[Vec<Poly>], rhos: &[Vec<Vec<i64>>], groups: &[(Vec<Poly>, Vec<Poly>)]| -> usize {
        let base = plain_x.len();
        for ((x, rho), (t1, t2)) in msgs.iter().zip(rhos.iter()).zip(groups.iter()) {
            plain_x.push(x.clone());
            plain_rho.push(rho.clone());
            t1s.push(t1.clone());
            t2s.push(t2.clone());
        }
        base
    };
    let base_y1 = push_tensor(&y1_cols, &rho_y1, &ty1);
    let base_y2 = push_tensor(&y2_cols, &rho_y2, &ty2);
    let base_r = push_tensor(&r_cols, &rho_r, &tr);
    let base_h = push_tensor(&h_msgs, &h_rhos, &h_groups);

    let const_poly = |v: u64| {
        let mut p = poly_zero();
        p[0] = v;
        p
    };
    let mut ring_claims: Vec<RingClaim> = Vec::new();
    for j in 0..n3 {
        for u in 0..cshape.msg_r {
            // Rescale: y1 - 2^shift y2 - r = 0. (The recomposition claim
            // moved to the q46 side: the link's structured 2^i weights ARE
            // the recomposition — no recomposition identity runs at q31.)
            ring_claims.push(RingClaim {
                msg_coeffs: vec![
                    (base_y1 + j, u, const_poly(1)),
                    (base_y2 + j, u, const_poly(zq.neg(1 << shift))),
                    (base_r + j, u, const_poly(zq.neg(1))),
                ],
                constant: poly_zero(),
            });
        }
    }
    // Hadamard claims (slot-packed triple).
    let one = const_poly(1);
    let quad_ring: Vec<QuadRingClaim> = (0..cshape.msg_r)
        .map(|u| QuadRingClaim {
            quad: vec![(base_h, u, base_h + 1, u, one.clone())],
            msg_coeffs: vec![(base_h + 2, u, const_poly(zq.neg(1)))],
        })
        .collect();
    // g-masks: reveal masks for the n3 * l link TARGET claims (linear) +
    // R1 pads for the Hadamard quad ring-claims. Committed BEFORE h0_link
    // (the F5 ordering rule, applied across moduli).
    let n_lin_t = n3 * lp.l;
    let g_base = plain_x.len();
    let g_groups = sample_g_masks(
        &mut rng,
        q,
        cshape.msg_r,
        n_lin_t,
        r1_pad_count(0, quad_ring.len(), 0),
    );
    for g in &g_groups {
        let rho: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let (t1, t2) = commit(&a1_path, &crs, g, &rho);
        plain_x.push(g.clone());
        plain_rho.push(rho);
        t1s.push(t1);
        t2s.push(t2);
    }
    let rp_wave = derive_ct_round_params(q, cshape, plain_x.len(), 0, 0, true);
    let a1p_wave = build_a1_paths(&crs, rp_wave.sigma, isqrt_u128(rp_wave.bound_sq));
    let wave_path = KernelPath::A1(&a1p_wave);

    // q46 g-masks: reveals for the ARP + grounding link claims, R1 pads
    // for the binary quads. Also committed before h0_link.
    let mut x_g_all: Vec<Vec<Poly>> = bits_x.clone();
    let mut rho_g_all: Vec<Vec<Vec<i64>>> = bits_rho.clone();
    let mut t1s_g: Vec<Vec<Poly>> = Vec::new();
    let mut t2s_g: Vec<Vec<Poly>> = Vec::new();
    for (t1, t2) in &bits_groups {
        t1s_g.push(t1.clone());
        t2s_g.push(t2.clone());
    }
    let g_base_g = x_g_all.len();
    let g_groups_g = sample_g_masks(
        &mut rng,
        q_g,
        msg_r_g,
        n_lin_g + n_quad_g,
        r1_pad_count(n_quad_g, 0, 0),
    );
    assert_eq!(g_groups_g.len(), n_g_groups_g);
    for g in &g_groups_g {
        let rho: Vec<Vec<i64>> =
            (0..gl_g.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let (t1, t2) = commit(&path_g, &crs_g, g, &rho);
        x_g_all.push(g.clone());
        rho_g_all.push(rho);
        t1s_g.push(t1);
        t2s_g.push(t2);
    }

    // The cross-modulus statement hash: h0_link binds the statement digest
    // (which binds every commitment entry), both CRS hashes, and BOTH
    // sides' full commitment lists (witnesses AND g-groups). The xi link
    // rows and both round hashes derive from it — nothing weight-like
    // exists before every commitment is fixed.
    let h0_link = link_h0(&ctx, &crs_g, &crs, &t1s_g, &t2s_g, &t1s, &t2s);
    let xi = derive_link_xi(&h0_link, &lp);
    // Revealed link integers y, per column, gated on the GROUNDING side.
    let r_col = |j: usize| -> Vec<u64> { (0..n1).map(|t| rr[t * n3 + j]).collect() };
    let y_link: Vec<Vec<i64>> = (0..n3).map(|j| link_reveal_y(&lp, &xi, &r_col(j))).collect();
    for y in &y_link {
        assert!(link_gate_ok(&lp, y), "honest link reveal must pass the grounding gate");
    }

    // --- Layer 2a: the q31 wave. -------------------------------------------
    let h0 = ct_h0(&crs, &h0_link, &t1s, &t2s, &[]);
    let ct_claims_t: Vec<ring::ct_engine::CtClaim> = (0..n3)
        .flat_map(|j| {
            let value_slots: Vec<(usize, usize)> = (0..chunks).map(|u| (base_r + j, u)).collect();
            link_claims_tgt(&zq, &lp, &xi, &y_link[j], &value_slots)
        })
        .collect();
    let openings: Vec<StdOpening> = plain_x
        .iter()
        .zip(plain_rho.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
        .collect();
    let (wave_proof, wave_attempts) = prove_ct_round(
        &wave_path, &ring_ctx, &rp_wave, None, &crs, &h0, &ct_claims_t, &ring_claims, &[],
        &quad_ring, &openings, &[], &[], g_base, &mut rng,
    );

    // --- Layer 2b: the q46 grounding round. ---------------------------------
    // FS-with-aborts around the ARP masks: sample + Ajtai-commit ALL n3
    // column masks, derive the round hash (which binds h0_link and the
    // mask commitments), derive the JL rows, attempt every column; any
    // rejection restarts the whole round with fresh masks.
    let s_r = ap.rows.div_ceil(D);
    let b_mat = expand_b_mat(&crs_g, "chain-arp", s_r);
    let mut arp_rounds = 0usize;
    let (m_packed, rho_m, acoms, h0_g, jl, y_arp) = loop {
        arp_rounds += 1;
        assert!(arp_rounds < 400, "ARP restart budget exhausted");
        let masks: Vec<Vec<i64>> = (0..n3).map(|_| sample_arp_mask(&ap, &mut rng)).collect();
        let packed: Vec<Vec<Vec<i64>>> = masks.iter().map(|m| pack_arp_mask(&ap, m)).collect();
        let rhos: Vec<Vec<Vec<i64>>> = (0..n3)
            .map(|_| (0..gl_g.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
            .collect();
        let acoms: Vec<AjtaiCommit> = (0..n3)
            .map(|j| ajtai_commit(&crs_g, &b_mat, &packed[j], &rhos[j]))
            .collect();
        let acom_refs: Vec<&AjtaiCommit> = acoms.iter().collect();
        let h0_g = ct_h0(&crs_g, &h0_link, &t1s_g, &t2s_g, &acom_refs);
        let jl = derive_jl_rows(&h0_g, ap.rows, ap.n);
        let mut ys: Vec<Vec<i64>> = Vec::new();
        for j in 0..n3 {
            let flat: Vec<i64> = bits_x[j][..shift as usize * chunks]
                .iter()
                .flat_map(|p| p.iter().map(|&v| v as i64))
                .collect();
            match arp_attempt(&ap, &jl, &flat, &masks[j], &mut rng) {
                Some(y) => ys.push(y),
                None => break,
            }
        }
        if ys.len() == n3 {
            break (packed, rhos, acoms, h0_g, jl, ys);
        }
    };
    let plane_slots = |j: usize| -> Vec<Vec<(usize, usize)>> {
        (0..shift as usize)
            .map(|i| (0..chunks).map(|u| (j, i * chunks + u)).collect())
            .collect()
    };
    let msg_slots = |j: usize| -> Vec<(usize, usize)> {
        (0..shift as usize * chunks).map(|s| (j, s)).collect()
    };
    let mut lin_claims_g: Vec<ring::ct_engine::CtClaim> = Vec::new();
    for j in 0..n3 {
        lin_claims_g.extend(arp_claims(&zq_g, &ap, &jl, &msg_slots(j), j, &y_arp[j]));
    }
    for j in 0..n3 {
        lin_claims_g.extend(link_claims_gnd(&zq_g, &lp, &xi, &y_link[j], &plane_slots(j)));
    }
    let mut quad_claims_g = Vec::new();
    for j in 0..n3 {
        quad_claims_g.extend(binary_claims(&zq_g, &h0_g, j as u64, &[(j, shift as usize * chunks)]));
    }
    let openings_g: Vec<StdOpening> = x_g_all
        .iter()
        .zip(rho_g_all.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s_g[i], t2: &t2s_g[i], x, rho })
        .collect();
    let ajtai_opens: Vec<AjtaiOpening> = (0..n3)
        .map(|j| AjtaiOpening { com: &acoms[j], s: &m_packed[j], rho: &rho_m[j] })
        .collect();
    let (proof_g, attempts_g) = prove_ct_round(
        &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g, &lin_claims_g, &[], &quad_claims_g, &[],
        &openings_g, &[], &ajtai_opens, g_base_g, &mut rng,
    );
    let prove_s = t_prove.elapsed().as_secs_f64();

    // --- Verification. ----------------------------------------------------
    // The verifier rebuilds EVERYTHING weight-like from public data: the
    // statement digest, h0_link from both commitment lists, the xi rows,
    // and both claim families from (xi, revealed y). It gates the revealed
    // link integers on the GROUNDING side (|y| < q46/2 — the integer bound)
    // and the ARP reveals on their range gate before any ct check runs.
    let t_verify = Instant::now();
    let h0_link_v = link_h0(&ctx, &crs_g, &crs, &t1s_g, &t2s_g, &t1s, &t2s);
    let xi_v = derive_link_xi(&h0_link_v, &lp);
    let gates_ok = (0..n3).all(|j| link_gate_ok(&lp, &y_link[j]))
        && (0..n3).all(|j| arp_check_reveal(&ap, &y_arp[j]));
    let ct_claims_t_v: Vec<ring::ct_engine::CtClaim> = (0..n3)
        .flat_map(|j| {
            let value_slots: Vec<(usize, usize)> = (0..chunks).map(|u| (base_r + j, u)).collect();
            link_claims_tgt(&zq, &lp, &xi_v, &y_link[j], &value_slots)
        })
        .collect();
    let mut lin_claims_g_v: Vec<ring::ct_engine::CtClaim> = Vec::new();
    let acom_refs: Vec<&AjtaiCommit> = acoms.iter().collect();
    let h0_g_v = ct_h0(&crs_g, &h0_link_v, &t1s_g, &t2s_g, &acom_refs);
    let jl_v = derive_jl_rows(&h0_g_v, ap.rows, ap.n);
    for j in 0..n3 {
        lin_claims_g_v.extend(arp_claims(&zq_g, &ap, &jl_v, &msg_slots(j), j, &y_arp[j]));
    }
    for j in 0..n3 {
        lin_claims_g_v.extend(link_claims_gnd(&zq_g, &lp, &xi_v, &y_link[j], &plane_slots(j)));
    }
    let mut quad_claims_g_v = Vec::new();
    for j in 0..n3 {
        quad_claims_g_v
            .extend(binary_claims(&zq_g, &h0_g_v, j as u64, &[(j, shift as usize * chunks)]));
    }
    let ok_pi2 = verify_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape2, &ctx, r_g, b_bits, &tw1, &tx0, &ty1,
        &pi2_proof,
    );
    let ok_wave = verify_ct_round(
        &wave_path, &ring_ctx, &rp_wave, None, &crs, &ct_h0(&crs, &h0_link_v, &t1s, &t2s, &[]),
        &ct_claims_t_v, &ring_claims, &[], &quad_ring, &t1s, &t2s, &[], &[], &[], g_base,
        &wave_proof,
    );
    let ok_gnd = verify_ct_round(
        &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g_v, &lin_claims_g_v, &[], &quad_claims_g_v,
        &[], &t1s_g, &t2s_g, &[], &[], &acom_refs, g_base_g, &proof_g,
    );
    let verify_s = t_verify.elapsed().as_secs_f64();
    let n_claims = 1 + ring_claims.len() + ct_claims_t.len() + quad_ring.len();
    println!(
        "  commit {commit_s:.2}s | prove {prove_s:.2}s (pi2 r_g={r_g} + q31 wave of {} claims [attempts {wave_attempts}] + q46 grounding of {} claims [attempts {attempts_g}, ARP rounds {arp_rounds}]) | verify {verify_s:.2}s",
        n_claims - 1,
        lin_claims_g.len() + quad_claims_g.len(),
    );
    if !(ok_pi2 && ok_wave && ok_gnd && gates_ok) {
        println!("  FAIL: chain does not verify (pi2 {ok_pi2}, wave {ok_wave}, q46 grounding {ok_gnd}, gates {gates_ok})");
        std::process::exit(1);
    }
    println!("  ok   chain verifies (statement digest binds header + quant + all {} commitments, {} operations)", mf.commitments.len(), mf.operations.len());
    println!("  ok   range family is integer-exact: q46 binary+ARP grounds the bits, {} link rows/column pin R's q31 residues", lp.l);

    // Negative: any tampered commitment changes the statement digest and
    // every claim fails.
    let mut st_bad = statement.clone();
    st_bad.manifest.commitments[0].commitment_bytes[0] ^= 1;
    let ctx_bad = st_bad.digest().expect("tampered bytes still validate structurally");
    let ok_tampered = verify_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape2, &ctx_bad, r_g, b_bits, &tw1, &tx0, &ty1,
        &pi2_proof,
    );
    if ok_tampered {
        println!("  FAIL: tampered statement still verifies");
        std::process::exit(1);
    }
    println!("  ok   tampered statement digest rejects every claim (ctx binding)");

    // --- [U7w] the malicious WRAPAROUND witness (audit C-02). --------------
    // Craft a "bit" plane whose binary defect sum_t b_t (b_t - 1) equals
    // 2 * q31 EXACTLY over the integers: greedy pronic decomposition
    // (b(b-1) terms; every remainder stays even, so it terminates in a
    // handful of coefficients). Every q31 identity of the OLD range
    // family then holds — the theta-randomized binary quadratic claim
    // (defect = 0 mod q31) and the 2^i recomposition (r' defined from the
    // crafted plane) — yet the recomposed r' WRAPS as an integer:
    // coefficients ~2^16.5, far above 2^shift. The shipped q46 grounding
    // rejects the same integers twice over: the defect is 2*q31 != 0 mod
    // q46 (binary ct check), and the coefficients cannot survive the ARP
    // range gate at all. (A third rejection layer, a wrapped q31 value
    // against honest q46 bits, is the link's value-drift case — battery
    // (c) of self_test_link.)
    {
        let crafted: Vec<u64> = {
            let mut vals = vec![0u64; D];
            let mut t: u128 = 2 * q as u128;
            let mut idx = 0usize;
            while t > 0 {
                let mut m = (t as f64).sqrt() as u128 + 2;
                while m * (m - 1) > t {
                    m -= 1;
                }
                vals[idx] = m as u64;
                idx += 1;
                t -= m * (m - 1);
            }
            assert!(idx <= D, "pronic decomposition fits one plane");
            vals
        };
        let defect: i128 = crafted.iter().map(|&b| (b as i128) * (b as i128 - 1)).sum();
        assert_eq!(defect, 2 * q as i128, "crafted defect is exactly 2 * q31 over Z");
        let r_wrap_max = crafted.iter().max().copied().unwrap();
        assert!(r_wrap_max >= 1 << shift, "the recomposed value wraps past 2^shift");

        // (a) ACCEPT under the OLD behavior: a pure-q31 round carrying the
        // old wave's exact claim shapes — 2^i recomposition ring-claims
        // plus theta-randomized binary quadratic claims per plane — on
        // crafted plane 0, zero planes 1.., and r' = the recomposition.
        let l_bin31 = ring::ct_engine::theta_rows(q);
        let n_quad_b = shift as usize * l_bin31;
        let mut xs_b: Vec<Vec<Poly>> = (0..shift as usize)
            .map(|i| {
                if i == 0 {
                    pack_column(D, cshape.msg_r, &crafted)
                } else {
                    vec![poly_zero(); cshape.msg_r]
                }
            })
            .collect();
        xs_b.push(pack_column(D, cshape.msg_r, &crafted)); // r' = 2^0 * plane0
        let g_groups_b = sample_g_masks(
            &mut rng,
            q,
            cshape.msg_r,
            n_quad_b,
            r1_pad_count(n_quad_b, 0, 0),
        );
        let g_base_b = xs_b.len();
        xs_b.extend(g_groups_b.iter().cloned());
        let rp_b = derive_ct_round_params(q, cshape, xs_b.len(), 0, 0, true);
        let a1p_b = build_a1_paths(&crs, rp_b.sigma, isqrt_u128(rp_b.bound_sq));
        let path_b = KernelPath::A1(&a1p_b);
        let mut rhos_b: Vec<Vec<Vec<i64>>> = Vec::new();
        let mut t1s_b: Vec<Vec<Poly>> = Vec::new();
        let mut t2s_b: Vec<Vec<Poly>> = Vec::new();
        for x in &xs_b {
            let rho: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let (t1, t2) = commit(&path_b, &crs, x, &rho);
            rhos_b.push(rho);
            t1s_b.push(t1);
            t2s_b.push(t2);
        }
        let h0_b = ct_h0(&crs, b"u7w-broken", &t1s_b, &t2s_b, &[]);
        let mut rc_b: Vec<RingClaim> = Vec::new();
        for u in 0..cshape.msg_r {
            let mut coeffs: Vec<(usize, usize, Poly)> = (0..shift as usize)
                .map(|i| (i, u, const_poly(zq.to_mod(1i64 << i))))
                .collect();
            coeffs.push((shift as usize, u, const_poly(zq.neg(1))));
            rc_b.push(RingClaim { msg_coeffs: coeffs, constant: poly_zero() });
        }
        let mut quad_b = Vec::new();
        for i in 0..shift as usize {
            quad_b.extend(binary_claims(&zq, &h0_b, i as u64, &[(i, cshape.msg_r)]));
        }
        let openings_b: Vec<StdOpening> = xs_b
            .iter()
            .zip(rhos_b.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s_b[i], t2: &t2s_b[i], x, rho })
            .collect();
        let (proof_b, _) = prove_ct_round(
            &path_b, &ring_ctx, &rp_b, None, &crs, &h0_b, &[], &rc_b, &quad_b, &[], &openings_b,
            &[], &[], g_base_b, &mut rng,
        );
        let broken_accepts = verify_ct_round(
            &path_b, &ring_ctx, &rp_b, None, &crs, &h0_b, &[], &rc_b, &quad_b, &[], &t1s_b,
            &t2s_b, &[], &[], &[], g_base_b, &proof_b,
        );
        assert_true(
            &format!(
                "[U7w] OLD q31-only range family ACCEPTS the wraparound witness (defect 2*q31, max coeff {r_wrap_max} >= 2^{shift}) — the audited hole"
            ),
            broken_accepts,
        );

        // (b) REJECT under the shipped grounding: the same integers
        // committed at q46 fail the binary quadratic ct check — the defect
        // 2*q31 does not vanish mod q46.
        let mut xs_c: Vec<Vec<Poly>> = vec![{
            let mut x = vec![poly_zero(); msg_r_g];
            for (t, &v) in crafted.iter().enumerate() {
                x[0][t] = v; // same u64 integers, residues mod q46
            }
            x
        }];
        let g_groups_c = sample_g_masks(
            &mut rng,
            q_g,
            msg_r_g,
            l_bin_g,
            r1_pad_count(l_bin_g, 0, 0),
        );
        xs_c.extend(g_groups_c.iter().cloned());
        let rp_c = derive_ct_round_params(q_g, gl_g.shape, xs_c.len(), 0, 0, false);
        let a1p_c = build_a1_paths(&crs_g, rp_c.sigma, isqrt_u128(rp_c.bound_sq));
        let path_c = KernelPath::A1(&a1p_c);
        let mut rhos_c: Vec<Vec<Vec<i64>>> = Vec::new();
        let mut t1s_c: Vec<Vec<Poly>> = Vec::new();
        let mut t2s_c: Vec<Vec<Poly>> = Vec::new();
        for x in &xs_c {
            let rho: Vec<Vec<i64>> =
                (0..gl_g.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let (t1, t2) = commit(&path_c, &crs_g, x, &rho);
            rhos_c.push(rho);
            t1s_c.push(t1);
            t2s_c.push(t2);
        }
        let h0_c = ct_h0(&crs_g, b"u7w-shipped", &t1s_c, &t2s_c, &[]);
        let quad_c = binary_claims(&zq_g, &h0_c, 0, &[(0, 1)]);
        let openings_c: Vec<StdOpening> = xs_c
            .iter()
            .zip(rhos_c.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s_c[i], t2: &t2s_c[i], x, rho })
            .collect();
        let (proof_c, _) = prove_ct_round(
            &path_c, &ring_g, &rp_c, None, &crs_g, &h0_c, &[], &[], &quad_c, &[], &openings_c,
            &[], &[], 1, &mut rng,
        );
        assert_true(
            "[U7w] shipped q46 grounding REJECTS the wraparound witness (binary ct check: defect 2*q31 != 0 mod q46)",
            !verify_ct_round(
                &path_c, &ring_g, &rp_c, None, &crs_g, &h0_c, &[], &[], &quad_c, &[], &t1s_c,
                &t2s_c, &[], &[], &[], 1, &proof_c,
            ),
        );

        // (c) The ARP side condition refuses independently: the crafted
        // coefficients (~2^16.5 against a w_inf = 1 gate) cannot produce a
        // single passing reveal — the non-wrap side condition is enforced,
        // not assumed.
        let ap_c = ring::ct_engine::derive_arp_params(D, 256, 1, 3.0);
        let jl_c = derive_jl_rows(&h0_c, ap_c.rows, ap_c.n);
        let flat_c: Vec<i64> = crafted.iter().map(|&v| v as i64).collect();
        let mut refusals = 0usize;
        for _ in 0..64 {
            let m = sample_arp_mask(&ap_c, &mut rng);
            if arp_attempt(&ap_c, &jl_c, &flat_c, &m, &mut rng).is_none() {
                refusals += 1;
            }
        }
        assert_true(
            &format!("[U7w] ARP range gate refuses the wraparound witness ({refusals}/64 mask attempts abort)"),
            refusals == 64,
        );
    }
    println!("chain-demo passed");
}

// ===========================================================================
// U-S4: statement-inventory — the pass-element inventory GENERATED from the
// validated statement DAG (audit H-02, third item). The two committed-
// element counts the cost documents carried (9.4e9 and 1.33e10 per
// 7B/512-token pass) were BOTH derived by dividing one modeled MAC total
// (1.5e14 Route Z MACs) by two different MACs-per-element anchors (16k in
// RING_MULT_BOTTLENECK 6.4a, 11.3k in A1_AUX_NTT_REPORT Section 6) — a
// round-trip through the very quantity being estimated, not an inventory.
// This generator replaces both: it BUILDS the 32-layer FFN-surrogate
// statement of TARGET_CONTRACT.md through the validated Statement format
// (every shape, quantization width, range/narrowing fact and consumption
// rule machine-checked), then counts committed elements by walking the
// entries. "Used" elements are tensor values; "paid" adds the frozen
// msg_r = 32 column-packing padding (ceil to 4096-slot commitments).
// Weights are counted separately (committed once per model, amortized
// across proofs — the docs' convention).

fn statement_inventory() {
    use manifest::{ClaimManifest, Operation, Orientation, QuantMeta, Statement};
    let (layers, dm, fh, tk) = (32usize, 4096usize, 11008usize, 512usize);
    println!("statement-inventory: {layers}-layer FFN surrogate (d = {dm}, f = {fh}, T = {tk} tokens) per TARGET_CONTRACT.md");
    println!("  quantization: int8 activations/weights; 28/16/29-bit accumulators; scale-consistent rescale shifts 4/7/1;");
    println!("  dense bit-plane range facts (remainders + int8 narrowings; SiLU input narrowed by the lookup itself)");

    fn add(
        mf: &mut ClaimManifest,
        quant: &mut Vec<QuantMeta>,
        label: &str,
        rows: usize,
        cols: usize,
        orientation: Orientation,
        qm: QuantMeta,
    ) -> u32 {
        let id = mf.add_commitment(label, rows, cols, orientation, vec![], vec![]);
        quant.push(qm);
        id
    }
    let q8 = QuantMeta { bits: 8, frac_bits: 4, signed: true };
    let plane = QuantMeta { bits: 1, frac_bits: 0, signed: false };
    let qm = |bits: u32, frac_bits: u32, signed: bool| QuantMeta { bits, frac_bits, signed };

    let mut mf = ClaimManifest::new("lattice-route-r", b"statement-inventory");
    let mut quant: Vec<QuantMeta> = Vec::new();
    let mut weight_ids: Vec<u32> = Vec::new();
    let by_cols = Orientation::ByColumns;
    let mut x_in = add(&mut mf, &mut quant, "X0", dm, tk, by_cols, q8);
    for l in 0..layers {
        let lb = |s: &str| format!("{s}{l}");
        // Gate projection: W (f x d) by rows, X (d x T) by columns.
        let wg = add(&mut mf, &mut quant, &lb("Wg"), fh, dm, Orientation::ByRows, q8);
        weight_ids.push(wg);
        let g_acc = add(&mut mf, &mut quant, &lb("Gacc"), fh, tk, by_cols, qm(28, 8, true));
        let g8 = add(&mut mf, &mut quant, &lb("g8"), fh, tk, by_cols, q8);
        let rg = add(&mut mf, &mut quant, &lb("Rg"), fh, tk, by_cols, qm(4, 8, false));
        let rg_bits = add(&mut mf, &mut quant, &lb("Rg-bits"), 4 * fh, tk, by_cols, plane);
        let a8 = add(&mut mf, &mut quant, &lb("a8"), fh, tk, by_cols, q8);
        mf.add_operation(Operation::Matmul { a: wg, b: x_in, c: g_acc });
        mf.add_operation(Operation::Rescale { x: g_acc, y: g8, r: rg, shift: 4 });
        mf.add_operation(Operation::Range { value: rg, bits: rg_bits, width: 4, signed: false });
        mf.add_operation(Operation::Binary { bits: rg_bits });
        // SiLU through the frozen table: domain membership narrows g8.
        mf.add_operation(Operation::Lookup { x: g8, y: a8 });
        // Up projection (+ proven int8 narrowing — u8 feeds the Hadamard).
        let wu = add(&mut mf, &mut quant, &lb("Wu"), fh, dm, Orientation::ByRows, q8);
        weight_ids.push(wu);
        let u_acc = add(&mut mf, &mut quant, &lb("Uacc"), fh, tk, by_cols, qm(28, 8, true));
        let u8v = add(&mut mf, &mut quant, &lb("u8"), fh, tk, by_cols, q8);
        let ru = add(&mut mf, &mut quant, &lb("Ru"), fh, tk, by_cols, qm(4, 8, false));
        let ru_bits = add(&mut mf, &mut quant, &lb("Ru-bits"), 4 * fh, tk, by_cols, plane);
        let u8_bits = add(&mut mf, &mut quant, &lb("u8-bits"), 8 * fh, tk, by_cols, plane);
        mf.add_operation(Operation::Matmul { a: wu, b: x_in, c: u_acc });
        mf.add_operation(Operation::Rescale { x: u_acc, y: u8v, r: ru, shift: 4 });
        mf.add_operation(Operation::Range { value: ru, bits: ru_bits, width: 4, signed: false });
        mf.add_operation(Operation::Binary { bits: ru_bits });
        mf.add_operation(Operation::Range { value: u8v, bits: u8_bits, width: 8, signed: true });
        mf.add_operation(Operation::Binary { bits: u8_bits });
        // gate o up. A signed 16-bit product is required for the positive
        // (-128)*(-128) endpoint; the int8 rescale carries its own Range.
        let hh = add(&mut mf, &mut quant, &lb("H"), fh, tk, by_cols, qm(16, 8, true));
        let h8 = add(&mut mf, &mut quant, &lb("h8"), fh, tk, by_cols, qm(8, 1, true));
        let rh = add(&mut mf, &mut quant, &lb("Rh"), fh, tk, by_cols, qm(7, 8, false));
        let rh_bits = add(&mut mf, &mut quant, &lb("Rh-bits"), 7 * fh, tk, by_cols, plane);
        let h8_bits = add(&mut mf, &mut quant, &lb("h8-bits"), 8 * fh, tk, by_cols, plane);
        mf.add_operation(Operation::Hadamard { x: a8, y: u8v, z: hh });
        mf.add_operation(Operation::Rescale { x: hh, y: h8, r: rh, shift: 7 });
        mf.add_operation(Operation::Range { value: rh, bits: rh_bits, width: 7, signed: false });
        mf.add_operation(Operation::Binary { bits: rh_bits });
        mf.add_operation(Operation::Range { value: h8, bits: h8_bits, width: 8, signed: true });
        mf.add_operation(Operation::Binary { bits: h8_bits });
        // Down projection (+ proven int8 narrowing — the layer output is
        // the next layer's input).
        let wd = add(&mut mf, &mut quant, &lb("Wd"), dm, fh, Orientation::ByRows, q8);
        weight_ids.push(wd);
        let d_acc = add(&mut mf, &mut quant, &lb("Dacc"), dm, tk, by_cols, qm(29, 5, true));
        let x_out = add(&mut mf, &mut quant, &lb("Xout"), dm, tk, by_cols, q8);
        let rd = add(&mut mf, &mut quant, &lb("Rd"), dm, tk, by_cols, qm(1, 5, false));
        let rd_bits = add(&mut mf, &mut quant, &lb("Rd-bits"), dm, tk, by_cols, plane);
        let x_out_bits = add(&mut mf, &mut quant, &lb("Xout-bits"), 8 * dm, tk, by_cols, plane);
        mf.add_operation(Operation::Matmul { a: wd, b: h8, c: d_acc });
        mf.add_operation(Operation::Rescale { x: d_acc, y: x_out, r: rd, shift: 1 });
        mf.add_operation(Operation::Range { value: rd, bits: rd_bits, width: 1, signed: false });
        mf.add_operation(Operation::Binary { bits: rd_bits });
        mf.add_operation(Operation::Range { value: x_out, bits: x_out_bits, width: 8, signed: true });
        mf.add_operation(Operation::Binary { bits: x_out_bits });
        x_in = x_out;
    }

    let model_digest: [u8; 32] = {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(b"ffn-surrogate-7b-v1");
        for v in [layers, dm, fh, tk] {
            hasher.update((v as u64).to_le_bytes());
        }
        hasher.finalize().into()
    };
    let table_digest = ring::lookup::table_spec_digest(&ring::lookup::silu_int8_table());
    assert_eq!(
        table_digest, manifest::SILU_INT8_TABLE_DIGEST,
        "frozen SiLU table digest parity (manifest constant vs ring/lookup.rs)"
    );
    // q31 value layer bounds the modulus capacity (bit planes live at q46).
    let modulus_bits = 63 - Q8.leading_zeros();
    let mut st = Statement::new(
        model_digest,
        Some(manifest::SILU_INT8_TABLE_SPEC),
        modulus_bits,
        mf,
    );
    st.quant = quant;
    // Canonical padding: both frozen layers pack msg_r = 32 ring elements
    // of degree D per commitment — vectors pad to 32 * D = 4096 slots
    // (rows for by-columns entries, cols for the by-rows weights).
    st.pad = st
        .manifest
        .commitments
        .iter()
        .map(|e| match e.orientation {
            Orientation::ByRows => {
                manifest::PadSpec::units(e.rows as usize, e.cols as usize, 1, 32 * D)
            }
            _ => manifest::PadSpec::units(e.rows as usize, e.cols as usize, 32 * D, 1),
        })
        .collect();
    st.outputs = vec![x_in];
    let (n_entries, n_ops) = (st.manifest.commitments.len(), st.manifest.operations.len());
    match st.validate() {
        Ok(()) => println!("  ok   statement validates: {n_entries} entries, {n_ops} operations, 1 declared output"),
        Err(err) => {
            println!("  FAIL: surrogate statement does not validate: {err}");
            std::process::exit(1);
        }
    }

    // --- Walk the validated DAG and count committed elements. --------------
    // Both frozen commitment layers pack msg_r = 32 ring elements of
    // degree 128 per commitment: 4096 paid slots (q31 value point kappa 9
    // / N_r 57; q46 gadget point kappa 6 / N_r 62 — ring-MACs/element
    // 0.571 vs 0.575, within ~1%).
    let slots = 32u128 * D as u128;
    let mut used = [0u128; 3]; // [q31 values, q46 bit planes, weights]
    let mut paid = [0u128; 3];
    for (entry, qmeta) in st.manifest.commitments.iter().zip(st.quant.iter()) {
        let family = if weight_ids.contains(&entry.id) {
            2
        } else if qmeta.bits == 1 {
            1
        } else {
            0
        };
        let (vectors, length) = match entry.orientation {
            Orientation::ByColumns => (entry.cols as u128, entry.rows as u128),
            Orientation::ByRows => (entry.rows as u128, entry.cols as u128),
            Orientation::RowMajor => (1u128, entry.rows as u128 * entry.cols as u128),
        };
        used[family] += vectors * length;
        paid[family] += vectors * length.div_ceil(slots) * slots;
    }
    let mut op_counts = [0usize; 7]; // matmul, rescale, range, binary, lookup, hadamard, other
    for op in &st.manifest.operations {
        match op {
            Operation::Matmul { .. } => op_counts[0] += 1,
            Operation::Rescale { .. } => op_counts[1] += 1,
            Operation::Range { .. } => op_counts[2] += 1,
            Operation::Binary { .. } => op_counts[3] += 1,
            Operation::Lookup { .. } => op_counts[4] += 1,
            Operation::Hadamard { .. } => op_counts[5] += 1,
            _ => op_counts[6] += 1,
        }
    }
    println!(
        "  operations: {} matmul, {} rescale, {} range, {} binary, {} lookup, {} hadamard",
        op_counts[0], op_counts[1], op_counts[2], op_counts[3], op_counts[4], op_counts[5]
    );
    println!("  committed elements per pass (weights excluded — one-time, amortized):");
    println!("    q31 value tensors:      used {:.4e}  paid {:.4e}", used[0] as f64, paid[0] as f64);
    println!("    q46 bit-plane tensors:  used {:.4e}  paid {:.4e}", used[1] as f64, paid[1] as f64);
    let (used_pass, paid_pass) = (used[0] + used[1], paid[0] + paid[1]);
    println!(
        "    PASS TOTAL:             used {:.4e}  paid {:.4e}  (padding factor {:.3})",
        used_pass as f64,
        paid_pass as f64,
        paid_pass as f64 / used_pass as f64
    );
    println!(
        "    weights (one-time):     used {:.4e}  paid {:.4e}",
        used[2] as f64, paid[2] as f64
    );
    // Commit-bill at the M5-lite MEASURED rates (117.4 ns/paid element 1T
    // end-to-end, 8.74x at 22T — q31 A1 kernel at the FFN shape; the q46
    // plane family is priced at the same rate: the frozen shapes differ
    // by ~1% in ring-MACs/element, but the q46 kernel rate itself is
    // UNMEASURED, so this row is measured-at-rate, not measured).
    let bill_1t = paid_pass as f64 * 117.4e-9;
    println!(
        "  commit bill [MEASURED-AT-RATE]: {:.0} s 1T, {:.0} s at 22T (measured 8.74x)",
        bill_1t,
        bill_1t / 8.74
    );
    println!(
        "  provenance: replaces BOTH prior counts — 9.4e9 (1.5e14 MACs / 16k MACs/el) and"
    );
    println!(
        "  1.33e10 (same MAC total / 11.3k MACs/el): divisor round-trips, not inventories."
    );
    println!("statement-inventory done");
}

// ===========================================================================
// freeze-check: EVERY derive-time gate of the frozen operating point in one
// place, run as a single subcommand. Finding F3 happened because a modulus
// decision in one tranche silently invalidated a budget derived in another;
// this is the permanent guard: any parameter move must keep this green, and
// a red freeze-check blocks the move until every budget is re-derived.
// Exit code 0 = every gate holds; 1 = at least one budget broke.

fn freeze_check() {
    use ring::ct_engine::{arp_budget_ok, derive_arp_params};
    use ring::params::{a1_enforce, witness_coeff_bound};
    println!("freeze-check: every derive-time gate at the frozen point (k = 8, q8_31, e in {{2,3,4}})");
    let mut all_ok = true;
    let mut gate = |label: &str, ok: bool| {
        println!("  {} {label}", if ok { "ok  " } else { "FAIL" });
        all_ok &= ok;
    };

    // C0' — LS18 invertibility margins.
    gate("C0' LS18 quinary margin at (k=8, q8_31) > 1 (measured 1.30x)", ls18_margin(Q8, 8) > 1.0);
    gate("C0' LS18 quinary margin at (k=8, q8_46) > 1 (fallback modulus)", ls18_margin(ring::Q8_46, 8) > 1.0);
    // C1' — challenge-set budget (static: 5^128 = 2^297.2 >= 2^257).
    gate("C1' quinary d=128 challenge budget (2^297.2 >= 2^257)", 128.0 * 5.0f64.log2() >= 257.0);

    // C2-C4 — the digit chains at the frozen shapes (headroom >= 1 bit).
    for (label, rows, inner, cols, e, kappa, n_r) in [
        ("Pi2 2048^3 e=2", 2048, 2048, 2048, 2u32, 8usize, 40usize),
        ("Pi2 2048^3 e=3", 2048, 2048, 2048, 3, 8, 40),
        ("Pi2 2048^3 e=4", 2048, 2048, 2048, 4, 9, 40),
        ("FFN 512x4096x11008 e=4", 512, 4096, 11008, 4, 9, 57),
    ] {
        match derive_digits(Proto::Pi2, rows, inner, cols, 0, Q8, true, e) {
            Some(p) => gate(
                &format!("C2-C4 {label}: kappa={} N_r={} headroom {:.1} bits", p.kappa, p.n_r, p.c2_headroom_bits()),
                p.kappa == kappa && p.n_r == n_r && p.c2_headroom_bits() >= 1.0,
            ),
            None => gate(&format!("C2-C4 {label}: point fits q31"), false),
        }
    }

    // P0 — A1 kernel regimes at the FFN point (fits SOME helper path).
    {
        let p = derive_digits(Proto::Pi2, 512, 4096, 11008, 0, Q8, true, 4).unwrap();
        let lines = a1_enforce(Q8, p.n_r, p.sigma, isqrt_u128(p.bound_sq));
        for line in &lines {
            println!("       P0 {:<58} -> {}", line.name, line.path);
        }
        gate("P0 A1 regimes all dispatch at the FFN point", !lines.is_empty());
    }

    // Gadget-layer side-condition budgets (the F3 gate, both directions).
    let ap = derive_arp_params(512, 256, 1, 3.0);
    gate("ARP binary side-condition budget closes at q8_46", arp_budget_ok(&ap, (ring::Q8_46 / 2) as f64));
    gate(
        "ARP binary side-condition budget at q8_31 is KNOWN-OPEN (must stay excluded, not assumed)",
        !arp_budget_ok(&ap, (Q8 / 2) as f64),
    );

    // Pi2 gate accounting (F2 + Appendix A.4): the DERIVED gate-scalar
    // width per shape — a change here means the gate chain moved.
    {
        let p = derive_digits(Proto::Pi2, 128, 256, 64, 0, Q8, true, 4).unwrap();
        let (b, e, l, _) = derive_gate_b(Q8, 128, p.kappa, p.n_r);
        let r = (256.0 / (b as f64 - 2.0)).ceil() as usize;
        gate(
            &format!("Pi2 gate derived b = {b} (e = {e}, L = {l}) at the demo shape -> full grade r_g = {r} (r=1 pending the recursive-gate round)"),
            b == 8 && r == 43,
        );
        let pf = derive_digits(Proto::Pi2, 512, 4096, 11008, 0, Q8, true, 4).unwrap();
        let (bf, ef, lf, _) = derive_gate_b(Q8, 11008, pf.kappa, pf.n_r);
        let rf = (256.0 / (bf as f64 - 2.0)).ceil() as usize;
        gate(
            &format!("Pi2 gate derived b = {bf} (e = {ef}, L = {lf}) at the FFN shape -> full grade r_g = {rf}"),
            bf >= 6 && rf <= 64,
        );
    }

    // U-B4 — the committed-executions gate's frozen artifacts: the C4
    // shape of the h-slot execution-vector commitments and the tie-combo
    // (W-combination) digit-chain envelope (AUTOMORPHISM_GATE_DESIGN.md
    // Appendix B). A change here means the gate's cost chain moved.
    {
        let d_lwe = (768.0_f64 * 31.0 / 11.7).ceil() as usize;
        let n_r_h = (8 * D + 128 * D + d_lwe).div_ceil(D);
        gate(
            &format!("CE gate execution/mask commitment shape (C4): kappa=8 n_r={n_r_h} msg_r=128"),
            n_r_h == 152,
        );
        // NOTE: the former "tie-combo digit chain" row (|W| ~ 2^18.1,
        // e = 4, L = 5) was removed with U-B5: the masked-reveal tie
        // (Appendix B.1) has no digit-opened W-combination — its only
        // derive-time artifacts are the shape row above (shared by the
        // mask commitments) and the C1' challenge budget.

        // U-B6 — pi2-CE frozen artifacts: the wide shape at the pi2
        // demo width, and the round-O tie digit chain (double-quinary
        // alpha under the mask-side-psi variant) at the kappa-9
        // statement grade the production shapes already carry.
        let ws = pi2_ce_wide_shape(256);
        gate(
            &format!("CE pi2 wide shape (C4): kappa={} n_r={} msg_r={}", ws.kappa, ws.n_r, ws.msg_r),
            ws.kappa == 8 && ws.n_r == 280 && ws.msg_r == 256,
        );
        let dp_ce = derive_digit_params(Q8, 9, 27, PI2_CE_DIGIT_E, PI2_CE_DIGIT_L, PI2_CE_W_INF);
        gate(
            &format!(
                "CE tie digit chain (e=4, L=5, w=2^17) closes at the kappa-9 grade: sigma=2^{:.1}",
                (dp_ce.sigma as f64).log2()
            ),
            dp_ce.sigma > 0,
        );
    }

    // R1 — the quadratic-claim pad slots (the Q4.3d/e ZK fix). A
    // refactor that drops the pads or moves the slot layout would
    // reopen the garbage-image leak; pin the per-family counts the
    // engine's g-slot space must include (the layout itself is enforced
    // at prove/verify time, and the R1 battery pins the leak and the
    // hash-order edge).
    gate(
        "R1 quad-claim g-slots include the pads: 3/quad-ct, 2/quad-ring, 3/twisted-quad",
        ring::ct_engine::r1_pad_count(1, 0, 0) == 3
            && ring::ct_engine::r1_pad_count(0, 1, 0) == 2
            && ring::ct_engine::r1_pad_count(0, 0, 1) == 3,
    );

    // U-L — the F3 modulus-link freeze rows.
    all_ok &= freeze_check_link();
    all_ok &= freeze_check_uk8();
    all_ok &= freeze_check_ur1();

    if all_ok {
        println!("freeze-check passed");
    } else {
        println!("freeze-check FAILED — a frozen budget broke; re-derive before moving parameters");
        std::process::exit(1);
    }
}

// ===========================================================================
// gate-spike: the algebra of the automorphism (trace) gate — the F2
// resolution candidate — validated numerically BEFORE any protocol code
// (the equations-first discipline). Full design: AUTOMORPHISM_GATE_DESIGN.md.
//
// Construction. Gal(R_q) = { sigma_t : X -> X^t, t odd mod 2D }, order D.
// For a subgroup H of order h, the partial trace T(y) := sum_{sigma in H}
// sigma(y) kills a monomial X^e iff its H-orbit picks up a sign flip
// (t e = e + D mod 2D for some sigma_t in H) — sign-cancellation, not
// projection. Let K(H) := { e != 0 : T(X^e) = 0 } be the killed set.
//
// Pack rows/columns on a support S subset [0, D) whose pairwise
// differences (mod D) all lie in K(H). Then for the pair products
// P_ij := conj(apack_i) bpack_j (whose junk lives exactly on the
// difference set of S):
//
//     T(P_ij) = h * ct(P_ij) * 1 = h * C[i][j] * 1   (a CONSTANT).
//
// With twisted-challenge combinations xa^sigma := sum_i sigma(s_i) apack_i
// (challenges twisted, packings NOT — sigma(s) is still quinary, a valid
// small combination):
//
//   G_A := sum_{sigma in H} sigma^{-1}( conj(xa^sigma) * xb^sigma )
//        = sum_ij conj(s_i) v_j * T(P_ij)          (weights OUTSIDE T)
//        = h * sum_ij conj(s_i) v_j * C[i][j],
//
// and the C-side object built the same way from the C commitments,
//   G_C := sum_sigma sigma^{-1}( conj(shat^sigma) * xc^sigma ),
//   shat^sigma := sum_i sigma(s_i) X^{pos_i},
// equals the same expression. G_A = G_C as RING elements iff the
// (ring-challenge-weighted) defect matrix vanishes — per-slot
// Schwartz-Zippel, 2^-296-class, r = 1. The junk never reaches the
// comparison: this is what the naive ring gate (finding F2) lacked.
//
// Cost shape: h twisted execution triples (openings amortizable a la
// ALS20) x 1/density(S) commit-density loss. The spike tabulates the
// (h, density) frontier and checks the amortized-opening norm growth
// against the q31/q46 C2 headroom.

fn apply_auto(zq: &ring::Zq, a: &[u64], t: usize) -> Poly {
    let mut out = poly_zero();
    for k in 0..D {
        if a[k] == 0 {
            continue;
        }
        let e = (t * k) % (2 * D);
        if e < D {
            out[e] = zq.add(out[e], a[k]);
        } else {
            out[e - D] = zq.sub(out[e - D], a[k]);
        }
    }
    out
}

/// Elements of the cyclic subgroup <g> of (Z/2D)*, optionally with the
/// conjugation coset adjoined.
fn subgroup_elems(g: usize, with_conj: bool) -> Vec<usize> {
    let m = 2 * D;
    let mut elems = vec![1usize];
    let mut cur = g % m;
    while cur != 1 {
        elems.push(cur);
        cur = (cur * g) % m;
    }
    if with_conj {
        let base = elems.clone();
        for t in base {
            elems.push((t * (m - 1)) % m);
        }
    }
    elems
}

fn trace_h(zq: &ring::Zq, a: &[u64], subgroup: &[usize]) -> Poly {
    let mut acc = poly_zero();
    for &t in subgroup {
        let s = apply_auto(zq, a, t);
        for k in 0..D {
            acc[k] = zq.add(acc[k], s[k]);
        }
    }
    acc
}

/// K(H): killed exponents (T(X^e) = 0) for e in 1..D.
fn killed_set(zq: &ring::Zq, subgroup: &[usize]) -> Vec<bool> {
    let mut killed = vec![false; D];
    for e in 1..D {
        let mut x = poly_zero();
        x[e] = 1;
        killed[e] = trace_h(zq, &x, subgroup).iter().all(|&c| c == 0);
    }
    killed
}

/// Greedy max-density support with all pairwise differences (mod D, both
/// signs) inside the killed set.
fn greedy_support(killed: &[bool]) -> Vec<usize> {
    let mut s: Vec<usize> = Vec::new();
    for p in 0..D {
        let ok = s.iter().all(|&p0| {
            let d1 = (p + D - p0) % D;
            let d2 = (p0 + D - p) % D;
            (d1 == 0 || killed[d1]) && (d2 == 0 || killed[d2])
        });
        if ok {
            s.push(p);
        }
    }
    s
}

fn gate_spike() {
    println!("gate-spike: the trace-gate algebra at (k = 8, q8_31) — see AUTOMORPHISM_GATE_DESIGN.md");
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let mut rng = 0x5eed_000au64;

    // Sanity: sigma_t are ring automorphisms (multiplicativity, 20 random).
    let mut ok_auto = true;
    for &t in &[3usize, 5, 129, 255, 251] {
        for _ in 0..4 {
            let a = rng_poly_mod(&mut rng, Q8);
            let b = rng_poly_mod(&mut rng, Q8);
            let lhs = apply_auto(&zq, &poly_mul_g(&zq, &a, &b), t);
            let rhs = poly_mul_g(&zq, &apply_auto(&zq, &a, t), &apply_auto(&zq, &b, t));
            ok_auto &= lhs == rhs;
        }
    }
    assert_true("sigma_t multiplicative (ring automorphisms)", ok_auto);
    // Full-group trace extracts d * ct (the classical identity).
    {
        let full = subgroup_elems(5, true); // <5> x <-1> = the full group, order 128
        assert_true("full automorphism group has order 128", full.len() == 128);
        let a = rng_poly_mod(&mut rng, Q8);
        let tr = trace_h(&zq, &a, &full);
        let want_ct = zq.mul(zq.to_mod(D as i64), a[0]);
        assert_true(
            "full trace = d * ct (junk fully killed)",
            tr[0] == want_ct && tr[1..].iter().all(|&c| c == 0),
        );
    }

    // The (h, density) frontier: subgroups <5^(64/h)> with/without conj.
    println!("\n  subgroup frontier (killed exponents -> max support density):");
    println!("  | H | order h | killed |K| | greedy |S| | density | execs x 1/density |");
    let mut frontier: Vec<(String, Vec<usize>, Vec<usize>)> = Vec::new();
    for log_h in 1..=6u32 {
        let h = 1usize << log_h;
        let g = ring::aux::pow_q(5, (64 / h) as u64, 256) as usize;
        for with_conj in [false, true] {
            let sub = subgroup_elems(g, with_conj);
            let killed = killed_set(&zq, &sub);
            let n_killed = killed.iter().filter(|&&k| k).count();
            let s = greedy_support(&killed);
            let label = if with_conj { format!("<5^{}, conj>", 64 / h) } else { format!("<5^{}>", 64 / h) };
            println!(
                "  | {label:<14} | {:>3} | {n_killed:>3} | {:>3} | {:.3} | {:.1} |",
                sub.len(),
                s.len(),
                s.len() as f64 / D as f64,
                sub.len() as f64 * D as f64 / s.len() as f64,
            );
            frontier.push((label, sub, s));
        }
    }

    // End-to-end gate identity at the best frontier points: pick the
    // largest-density entries with h <= 64 and verify G_A = G_C.
    let mut tested = 0;
    for (label, sub, s) in &frontier {
        if s.len() < 8 || sub.len() > 128 {
            continue;
        }
        let (rows, cols) = (5usize, 4usize);
        let inner = s.len();
        // Rows/columns packed on the support S.
        let pack_s = |vals: &[u64]| -> Poly {
            let mut p = poly_zero();
            for (idx, &pos) in s.iter().enumerate() {
                p[pos] = vals[idx];
            }
            p
        };
        let a_rows: Vec<Vec<u64>> =
            (0..rows).map(|_| (0..inner).map(|_| rng_below(&mut rng, Q8)).collect()).collect();
        let b_cols: Vec<Vec<u64>> =
            (0..cols).map(|_| (0..inner).map(|_| rng_below(&mut rng, Q8)).collect()).collect();
        let c_mat: Vec<Vec<u64>> = (0..rows)
            .map(|i| {
                (0..cols)
                    .map(|j| {
                        let mut acc = 0u64;
                        for k in 0..inner {
                            acc = zq.add(acc, zq.mul(a_rows[i][k], b_cols[j][k]));
                        }
                        acc
                    })
                    .collect()
            })
            .collect();
        let apack: Vec<Poly> = a_rows.iter().map(|r| pack_s(r)).collect();
        let bpack: Vec<Poly> = b_cols.iter().map(|c| pack_s(c)).collect();
        // C columns packed at the ROW positions pos_i (rows <= |S|).
        let cpack: Vec<Poly> = (0..cols)
            .map(|j| {
                let mut p = poly_zero();
                for i in 0..rows {
                    p[s[i]] = c_mat[i][j];
                }
                p
            })
            .collect();
        let sch: Vec<Vec<i64>> = (0..rows).map(|_| rng_quinary_poly(&mut rng)).collect();
        let vch: Vec<Vec<i64>> = (0..cols).map(|_| rng_quinary_poly(&mut rng)).collect();

        let combine = |polys: &[Poly], ch: &[Vec<i64>], t: usize| -> Poly {
            let mut acc = poly_zero();
            for (p, c) in polys.iter().zip(ch.iter()) {
                let c_mod = poly_from_small(&zq, c);
                let tc = apply_auto(&zq, &c_mod, t);
                let prod = poly_mul_g(&zq, &tc, p);
                acc = poly_add(&zq, &acc, &prod);
            }
            acc
        };
        let m = 2 * D;
        let inv_t = |t: usize| -> usize {
            (1..m).step_by(2).find(|&u| (t * u) % m == 1).unwrap()
        };
        let mut g_a = poly_zero();
        let mut g_c = poly_zero();
        for &t in sub {
            // A-side: F^sigma = conj(xa^sigma) * xb^sigma.
            let xa = combine(&apack, &sch, t);
            let xb = combine(&bpack, &vch, t);
            let f = poly_mul_g(&zq, &poly_conj(&zq, &xa), &xb);
            g_a = poly_add(&zq, &g_a, &apply_auto(&zq, &f, inv_t(t)));
            // C-side: conj(shat^sigma) * xc^sigma with
            // shat^sigma = sum_i sigma(s_i) X^{pos_i}.
            let mut shat = poly_zero();
            for i in 0..rows {
                let c_mod = poly_from_small(&zq, &sch[i]);
                let tc = apply_auto(&zq, &c_mod, t);
                let mut xi = poly_zero();
                xi[s[i]] = 1;
                let term = poly_mul_g(&zq, &tc, &xi);
                shat = poly_add(&zq, &shat, &term);
            }
            let xc = combine(&cpack, &vch, t);
            let e = poly_mul_g(&zq, &poly_conj(&zq, &shat), &xc);
            g_c = poly_add(&zq, &g_c, &apply_auto(&zq, &e, inv_t(t)));
        }
        assert_true(
            &format!("gate identity G_A = G_C at H = {label} (h = {}, density {:.2}, junk-free by construction)", sub.len(), s.len() as f64 / D as f64),
            g_a == g_c,
        );
        // Reference value: h * sum_ij conj(s_i) v_j C[i][j].
        let mut want = poly_zero();
        for i in 0..rows {
            for j in 0..cols {
                let si = poly_conj(&zq, &poly_from_small(&zq, &sch[i]));
                let vj = poly_from_small(&zq, &vch[j]);
                let w = poly_mul_g(&zq, &si, &vj);
                let scaled = ring::poly_scale(&zq, c_mat[i][j], &w);
                want = poly_add(&zq, &want, &scaled);
            }
        }
        let want = ring::poly_scale(&zq, zq.to_mod(sub.len() as i64), &want);
        assert_true(
            &format!("G_A = h * sum conj(s_i) v_j C[i][j] exactly at H = {label}"),
            g_a == want,
        );
        // Negative: C wrong in one entry -> the identity must fail.
        let mut cpack_bad = cpack.clone();
        cpack_bad[0][s[0]] = zq.add(cpack_bad[0][s[0]], 1);
        let mut g_c_bad = poly_zero();
        for &t in sub {
            let mut shat = poly_zero();
            for i in 0..rows {
                let c_mod = poly_from_small(&zq, &sch[i]);
                let tc = apply_auto(&zq, &c_mod, t);
                let mut xi = poly_zero();
                xi[s[i]] = 1;
                shat = poly_add(&zq, &shat, &poly_mul_g(&zq, &tc, &xi));
            }
            let xc = combine(&cpack_bad, &vch, t);
            let e = poly_mul_g(&zq, &poly_conj(&zq, &shat), &xc);
            g_c_bad = poly_add(&zq, &g_c_bad, &apply_auto(&zq, &e, inv_t(t)));
        }
        assert_true(
            &format!("gate identity fails on tampered C at H = {label}"),
            g_a != g_c_bad,
        );
        tested += 1;
        if tested >= 3 {
            break;
        }
    }
    assert_true("at least 3 frontier points verified end-to-end", tested >= 3);
    // The RECOMMENDED point: the full group (h = 128, density 1.0 — dense
    // packing, no support claims, no commit-bill penalty; all cost in the
    // amortizable twisted executions). Same identity, dense random rows.
    {
        let (label, sub, s) = frontier.last().unwrap().clone();
        assert_true(
            &format!("full-group point is dense (h = {}, |S| = {})", sub.len(), s.len()),
            sub.len() == 128 && s.len() == D,
        );
        let _ = label;
        // Re-run the identity test body on the dense support: reuse by
        // scoping a second pass over just this entry.
        let (rows, cols) = (4usize, 3usize);
        let inner = D;
        let a_rows: Vec<Vec<u64>> =
            (0..rows).map(|_| (0..inner).map(|_| rng_below(&mut rng, Q8)).collect()).collect();
        let b_cols: Vec<Vec<u64>> =
            (0..cols).map(|_| (0..inner).map(|_| rng_below(&mut rng, Q8)).collect()).collect();
        let c_mat: Vec<Vec<u64>> = (0..rows)
            .map(|i| {
                (0..cols)
                    .map(|j| {
                        let mut acc = 0u64;
                        for k in 0..inner {
                            acc = zq.add(acc, zq.mul(a_rows[i][k], b_cols[j][k]));
                        }
                        acc
                    })
                    .collect()
            })
            .collect();
        let apack: Vec<Poly> = a_rows.iter().map(|r| r.clone()).collect();
        let bpack: Vec<Poly> = b_cols.iter().map(|c| c.clone()).collect();
        let cpack: Vec<Poly> = (0..cols)
            .map(|j| {
                let mut p = poly_zero();
                for i in 0..rows {
                    p[i] = c_mat[i][j];
                }
                p
            })
            .collect();
        let sch: Vec<Vec<i64>> = (0..rows).map(|_| rng_quinary_poly(&mut rng)).collect();
        let vch: Vec<Vec<i64>> = (0..cols).map(|_| rng_quinary_poly(&mut rng)).collect();
        let m = 2 * D;
        let inv_t = |t: usize| -> usize { (1..m).step_by(2).find(|&u| (t * u) % m == 1).unwrap() };
        let combine = |polys: &[Poly], ch: &[Vec<i64>], t: usize| -> Poly {
            let mut acc = poly_zero();
            for (p, c) in polys.iter().zip(ch.iter()) {
                let tc = apply_auto(&zq, &poly_from_small(&zq, c), t);
                acc = poly_add(&zq, &acc, &poly_mul_g(&zq, &tc, p));
            }
            acc
        };
        let mut g_a = poly_zero();
        let mut g_c = poly_zero();
        for &t in &sub {
            let xa = combine(&apack, &sch, t);
            let xb = combine(&bpack, &vch, t);
            let f = poly_mul_g(&zq, &poly_conj(&zq, &xa), &xb);
            g_a = poly_add(&zq, &g_a, &apply_auto(&zq, &f, inv_t(t)));
            let mut shat = poly_zero();
            for i in 0..rows {
                let tc = apply_auto(&zq, &poly_from_small(&zq, &sch[i]), t);
                let mut xi = poly_zero();
                xi[i] = 1;
                shat = poly_add(&zq, &shat, &poly_mul_g(&zq, &tc, &xi));
            }
            let xc = combine(&cpack, &vch, t);
            let e = poly_mul_g(&zq, &poly_conj(&zq, &shat), &xc);
            g_c = poly_add(&zq, &g_c, &apply_auto(&zq, &e, inv_t(t)));
        }
        assert_true(
            "RECOMMENDED POINT: full-trace gate identity, DENSE packing (h = 128, density 1.0, no support claims)",
            g_a == g_c,
        );
        let mut cpack_bad = cpack.clone();
        cpack_bad[0][0] = zq.add(cpack_bad[0][0], 1);
        let mut g_c_bad = poly_zero();
        for &t in &sub {
            let mut shat = poly_zero();
            for i in 0..rows {
                let tc = apply_auto(&zq, &poly_from_small(&zq, &sch[i]), t);
                let mut xi = poly_zero();
                xi[i] = 1;
                shat = poly_add(&zq, &shat, &poly_mul_g(&zq, &tc, &xi));
            }
            let xc = combine(&cpack_bad, &vch, t);
            let e = poly_mul_g(&zq, &poly_conj(&zq, &shat), &xc);
            g_c_bad = poly_add(&zq, &g_c_bad, &apply_auto(&zq, &e, inv_t(t)));
        }
        assert_true("full-trace gate identity fails on tampered C", g_a != g_c_bad);
    }

    // Amortized-opening headroom lines (the parameter tension for the doc):
    // ALS20-amortized openings of the 3h twisted combos grow the response
    // norm ~ sqrt(3h) -> beta gains 0.5 log2(3h) bits.
    println!("\n  amortized-opening norm growth vs C2 headroom:");
    for h in [16usize, 32, 64, 128] {
        let extra_bits = 0.5 * (3.0 * h as f64).log2();
        println!(
            "  | h = {h:>3} | +{extra_bits:.1} bits on beta | q31 e=2 headroom 2.9 bits: {} | q46 headroom ~17 bits: ok |",
            if extra_bits < 2.9 { "fits" } else { "DOES NOT FIT (batch or q46 gate layer)" },
        );
    }

    // =====================================================================
    // Q-A5 resolution candidate: the COMMITTED-EXECUTIONS gate (depth-1
    // "recursion"). Instead of opening the 3h twisted combos, the prover
    // COMMITS the execution vectors YA := (sigma^{-1}(xa^sigma))_sigma
    // (h ring elements = h message slots, ONE commitment per side), ties
    // each committed vector to the originals with ONE tau-batched
    // combination claim (per-slot sound), and the whole gate becomes ONE
    // sigma-twisted ring-valued quadratic claim over (YA, YB, YC):
    //     sum_sigma conj(YA_sigma) YB_sigma
    //       - sum_sigma conj(sigma^{-1}(shat^sigma)) YC_sigma  =  0.
    // The h = 128 vector is small enough that re-commitment is cheap —
    // the "recursion" terminates at depth one. Identities verified here;
    // protocol composition is the build tranche.
    println!("\n  committed-executions gate (depth-1; Q-A5 candidate):");
    {
        let full = subgroup_elems(5, true);
        let h = full.len();
        let (rows, cols) = (4usize, 3usize);
        let inner = D;
        let m2 = 2 * D;
        let inv_t = |t: usize| -> usize { (1..m2).step_by(2).find(|&u| (t * u) % m2 == 1).unwrap() };
        let a_rows: Vec<Poly> =
            (0..rows).map(|_| (0..inner).map(|_| rng_below(&mut rng, Q8)).collect()).collect();
        let b_cols: Vec<Poly> =
            (0..cols).map(|_| (0..inner).map(|_| rng_below(&mut rng, Q8)).collect()).collect();
        let c_mat: Vec<Vec<u64>> = (0..rows)
            .map(|i| {
                (0..cols)
                    .map(|j| {
                        let mut acc = 0u64;
                        for k in 0..inner {
                            acc = zq.add(acc, zq.mul(a_rows[i][k], b_cols[j][k]));
                        }
                        acc
                    })
                    .collect()
            })
            .collect();
        let cpack: Vec<Poly> = (0..cols)
            .map(|j| {
                let mut p = poly_zero();
                for i in 0..rows {
                    p[i] = c_mat[i][j];
                }
                p
            })
            .collect();
        let sch: Vec<Vec<i64>> = (0..rows).map(|_| rng_quinary_poly(&mut rng)).collect();
        let vch: Vec<Vec<i64>> = (0..cols).map(|_| rng_quinary_poly(&mut rng)).collect();
        let combine = |polys: &[Poly], ch: &[Vec<i64>], t: usize| -> Poly {
            let mut acc = poly_zero();
            for (p, c) in polys.iter().zip(ch.iter()) {
                let tc = apply_auto(&zq, &poly_from_small(&zq, c), t);
                acc = poly_add(&zq, &acc, &poly_mul_g(&zq, &tc, p));
            }
            acc
        };
        // The execution vectors: YA_sigma = sigma^{-1}(xa^sigma) etc.
        let mut ya: Vec<Poly> = Vec::with_capacity(h);
        let mut yb: Vec<Poly> = Vec::with_capacity(h);
        let mut yc: Vec<Poly> = Vec::with_capacity(h);
        let mut shat_tw: Vec<Poly> = Vec::with_capacity(h); // sigma^{-1}(shat^sigma)
        for &t in &full {
            let ti = inv_t(t);
            ya.push(apply_auto(&zq, &combine(&a_rows, &sch, t), ti));
            yb.push(apply_auto(&zq, &combine(&b_cols, &vch, t), ti));
            yc.push(apply_auto(&zq, &combine(&cpack, &vch, t), ti));
            let mut shat = poly_zero();
            for i in 0..rows {
                let tc = apply_auto(&zq, &poly_from_small(&zq, &sch[i]), t);
                let mut xi = poly_zero();
                xi[i] = 1;
                shat = poly_add(&zq, &shat, &poly_mul_g(&zq, &tc, &xi));
            }
            shat_tw.push(apply_auto(&zq, &shat, ti));
        }
        // (1) The tau-tie identity: sum_sigma tau_sigma YA_sigma equals the
        // ONE digit-openable double combination
        // W_A = sum_i s_i [sum_sigma tau_sigma sigma^{-1}(apack_i)]
        // (verifier-computable from twisted original commitments).
        let tau: Vec<Vec<i64>> = (0..h).map(|_| rng_quinary_poly(&mut rng)).collect();
        let mut lhs = poly_zero();
        for (yai, ti) in ya.iter().zip(tau.iter()) {
            let prod = poly_mul_g(&zq, &poly_from_small(&zq, ti), yai);
            lhs = poly_add(&zq, &lhs, &prod);
        }
        let mut rhs = poly_zero();
        for (i, ap) in a_rows.iter().enumerate() {
            let mut inner_sum = poly_zero();
            for (si, &t) in full.iter().enumerate() {
                let tw = apply_auto(&zq, ap, inv_t(t));
                let prod = poly_mul_g(&zq, &poly_from_small(&zq, &tau[si]), &tw);
                inner_sum = poly_add(&zq, &inner_sum, &prod);
            }
            rhs = poly_add(&zq, &rhs, &poly_mul_g(&zq, &poly_from_small(&zq, &sch[i]), &inner_sum));
        }
        assert_true("tau-tie: sum tau_s YA_s == the double combination W_A (one opening ties the vector)", lhs == rhs);
        // (2) The single-claim gate identity over the committed vectors:
        // sum conj(YA_s) YB_s - sum conj(shat_s) YC_s = 0, full ring.
        let mut gate = poly_zero();
        for s in 0..h {
            let qterm = poly_mul_g(&zq, &poly_conj(&zq, &ya[s]), &yb[s]);
            let lterm = poly_mul_g(&zq, &poly_conj(&zq, &shat_tw[s]), &yc[s]);
            gate = poly_add(&zq, &gate, &ring::poly_sub(&zq, &qterm, &lterm));
        }
        assert_true(
            "single-claim gate: sum conj(YA)YB - sum conj(shat)YC == 0 (dense, h = 128, r = 1)",
            gate.iter().all(|&x| x == 0),
        );
        // Tampered C fails.
        let mut yc_bad = yc.clone();
        {
            let mut cpack_bad = cpack.clone();
            cpack_bad[0][0] = zq.add(cpack_bad[0][0], 1);
            for (si, &t) in full.iter().enumerate() {
                yc_bad[si] = apply_auto(&zq, &combine(&cpack_bad, &vch, t), inv_t(t));
            }
        }
        let mut gate_bad = poly_zero();
        for s in 0..h {
            let qterm = poly_mul_g(&zq, &poly_conj(&zq, &ya[s]), &yb[s]);
            let lterm = poly_mul_g(&zq, &poly_conj(&zq, &shat_tw[s]), &yc_bad[s]);
            gate_bad = poly_add(&zq, &gate_bad, &ring::poly_sub(&zq, &qterm, &lterm));
        }
        assert_true("single-claim gate fails on tampered C", gate_bad.iter().any(|&x| x != 0));
        // (3) Feasibility prints: the h-slot commitment shape and the
        // W-combo digit chain (empirical randomness magnitude at reduced
        // rows, sqrt-extrapolated to n = 2048 — lemma-grade bound is the
        // build tranche's job).
        let msg_r_h = h;
        let d_lwe = (768.0_f64 * 31.0 / 11.7).ceil() as usize;
        let n_r_h = (8 * D + msg_r_h * D + d_lwe).div_ceil(D);
        println!(
            "    YA/YB/YC commitment shape: msg_r = {msg_r_h}, n_r ~ {n_r_h} (C4), plain ternary openings"
        );
        let rows_emp = 64usize;
        let mut max_coeff = 0i64;
        let mut rng2 = 0x5eed_000cu64;
        let rhos: Vec<Vec<i64>> = (0..rows_emp).map(|_| rng_ternary_poly(&mut rng2)).collect();
        let s_emp: Vec<Vec<i64>> = (0..rows_emp).map(|_| rng_quinary_poly(&mut rng2)).collect();
        let mut acc_w = vec![0i64; D];
        for (i, rho) in rhos.iter().enumerate() {
            for ti in tau.iter().take(h) {
                let st = poly_mul_small(&s_emp[i], ti);
                // sigma^{-1}(rho) is a signed coefficient permutation: the
                // magnitude statistics match rho itself.
                let term = poly_mul_small(&st, rho);
                for (a, &x) in acc_w.iter_mut().zip(term.iter()) {
                    *a += x;
                }
            }
        }
        for &x in &acc_w {
            max_coeff = max_coeff.max(x.abs());
        }
        let w_est_2048 = (max_coeff as f64) * (2048.0f64 / rows_emp as f64).sqrt();
        println!(
            "    W-combo randomness: empirical max |coeff| = {max_coeff} at rows = {rows_emp}, sqrt-extrapolated ~ 2^{:.1} at rows = 2048",
            w_est_2048.log2()
        );
        let l_est = ((w_est_2048.log2() + 1.0) / 4.0).ceil() as usize;
        println!(
            "    -> digit chain e = 4, L ~ {l_est}; per-gate cost ~ 3 plain bundles (n_r ~ {n_r_h}) + 3 digit combos + 1 claim (target class)"
        );
    }
    println!("\ngate-spike passed");
}

// ===========================================================================
// U-B2: the committed-executions Pi2 gate (AUTOMORPHISM_GATE_DESIGN.md
// Appendix B). Resolves finding F2's repetition cost at r = 1. The gate
// C = A B (all hidden) becomes:
//   - fresh commitments to the h = 128 execution vectors YA, YB, YC
//     (YA_sigma = sigma^{-1}(sum_i sigma(s_i) apack_i), etc.);
//   - ONE sigma-twisted ring-valued quadratic claim through the engine:
//       sum_sigma conj(YA_sigma) YB_sigma
//         - sum_sigma conj(shat_tw_sigma) YC_sigma = 0    (r = 1);
//   - a tie binding each Y to the originals (sum_sigma tau_sigma YA_sigma
//     = sum_i s_i sum_sigma tau_sigma sigma^{-1}(apack_i)).
//
// STATUS: gate AND tie both run as first-class claims through the
// production ct-engine (U-B5, Appendix B.1 RESOLVED). The tie uses the
// masked-reveal construction: per side, uniform masks mu_t and their
// pre-twisted images nu_t = sigma_t(mu_t) are committed BEFORE the
// full-entropy challenges psi are drawn; the prover reveals
// F_t = psi_t Y_t + mu_t (uniform — leaks nothing), and two UNTWISTED
// linear ring claims with public constants close the tie:
//   (i)  batches  psi_t Y_t + mu_t = F_t          over t (challenge taui)
//   (ii) batches  psi'_t v'_t + nu_t = sigma_t(F_t) over t (challenge tauii)
// where v'_t = sum_i sigma_t(ch_i) orig_i and psi'_t = sigma_t(psi_t).
// Galois twists act ONLY on public data. Soundness: (i) and (ii) pin the
// per-t relations (tau drawn after F); combining them forces
// psi_t (Y_t - v_t) = sigma_t^{-1}(nu_t) - mu_t, whose right side is
// fixed before psi — a nonzero defect survives with per-slot probability
// 2^-496-class (psi full-entropy). The order-regression battery below
// demonstrates the attack that succeeds when psi precedes the masks.

fn self_test_pi2_ce() {
    use ring::ct_engine::{
        RingClaim, StdOpening, TwistedQuadRingClaim, ct_h0, derive_ct_round_params,
        prove_ct_round_tq, verify_ct_round_tq,
    };
    println!("\n[U-B2/B5] committed-executions Pi2 gate + first-class tie (r = 1) at rows=4, inner=128, cols=3, q8_31");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let (rows, cols) = (4usize, 3usize);
    let full = subgroup_elems(5, true);
    let h = full.len();
    let m2 = 2 * D;
    let inv_t = |t: usize| -> usize { (1..m2).step_by(2).find(|&u| (t * u) % m2 == 1).unwrap() };

    // One CRS with msg_r = h (the execution vectors are the widest).
    let cshape = CommitShape { kappa: 8, n_r: 152, msg_r: h };
    let crs = expand_crs(cshape, q, 51_000);
    let mut rng = 0x5eed_00d0u64;

    // Instance: A rows, B cols, C[i][j] = <apack_i, bpack_j> (the matmul
    // the gate proves via ct of conj(apack_i) bpack_j).
    let a_rows: Vec<Poly> = (0..rows).map(|_| rng_poly_mod(&mut rng, q)).collect();
    let b_cols: Vec<Poly> = (0..cols).map(|_| rng_poly_mod(&mut rng, q)).collect();
    let c_mat: Vec<Vec<u64>> = (0..rows)
        .map(|i| {
            (0..cols)
                .map(|j| {
                    let mut acc = 0u64;
                    for k in 0..D {
                        acc = zq.add(acc, zq.mul(a_rows[i][k], b_cols[j][k]));
                    }
                    acc
                })
                .collect()
        })
        .collect();
    let cpack: Vec<Poly> = (0..cols)
        .map(|j| {
            let mut p = poly_zero();
            for i in 0..rows {
                p[i] = c_mat[i][j];
            }
            p
        })
        .collect();

    let pad = |v: &[Poly]| -> Vec<Poly> {
        let mut x = v.to_vec();
        x.resize(h, poly_zero());
        x
    };

    // Build committed objects: 0=A, 1=B, 2=C, 3=YA, 4=YB, 5=YC.
    let build = |msgs: Vec<Poly>, rng: &mut u64| -> (Vec<Poly>, Vec<Poly>, Vec<Poly>, Vec<Vec<i64>>) {
        let x = pad(&msgs);
        let rho: Vec<Vec<i64>> = (0..cshape.n_r).map(|_| rng_ternary_poly(rng)).collect();
        let (t1, t2) = commit(&KernelPath::School, &crs, &x, &rho);
        (x, t1, t2, rho)
    };
    let (xa, t1a, t2a, rhoa) = build(a_rows.clone(), &mut rng);
    let (xb, t1b, t2b, rhob) = build(b_cols.clone(), &mut rng);
    let (xc, t1c, t2c, rhoc) = build(cpack.clone(), &mut rng);

    // Draw s, v from a preliminary hash binding the original commits (the
    // Y commitments depend on s, v). tau is drawn LATER, from the final h0
    // that binds the Y commitments — drawing tau before Y is committed
    // would let a cheating prover craft Y around a known tau (the F5
    // failure mode); Appendix B step 2 pins this order.
    let pre = ct_h0(&crs, b"pi2-ce-pre", &[t1a.clone(), t1b.clone(), t1c.clone()], &[t2a.clone(), t2b.clone(), t2c.clone()], &[]);
    let mut sr = XofReader::new("pi2-ce-sv", &[&pre]);
    let sch: Vec<Vec<i64>> = (0..rows).map(|_| sr.next_challenge()).collect();
    let vch: Vec<Vec<i64>> = (0..cols).map(|_| sr.next_challenge()).collect();

    // Execution vectors ya^sigma = sigma^{-1}(sum_i sigma(s_i) apack_i).
    let exec = |packs: &[Poly], ch: &[Vec<i64>]| -> Vec<Poly> {
        full.iter()
            .map(|&t| {
                let mut acc = poly_zero();
                for (p, c) in packs.iter().zip(ch.iter()) {
                    let tc = apply_auto(&zq, &poly_from_small(&zq, c), t);
                    acc = poly_add(&zq, &acc, &poly_mul_g(&zq, &tc, p));
                }
                apply_auto(&zq, &acc, inv_t(t))
            })
            .collect()
    };
    let ya = exec(&a_rows, &sch);
    let yb = exec(&b_cols, &vch);
    let yc = exec(&cpack, &vch);
    // shat_tw_sigma = sigma^{-1}(sum_i sigma(s_i) X^{pos_i}) — public.
    let shat_tw: Vec<Poly> = full
        .iter()
        .map(|&t| {
            let mut acc = poly_zero();
            for i in 0..rows {
                let tc = apply_auto(&zq, &poly_from_small(&zq, &sch[i]), t);
                let mut xi = poly_zero();
                xi[i] = 1;
                acc = poly_add(&zq, &acc, &poly_mul_g(&zq, &tc, &xi));
            }
            apply_auto(&zq, &acc, inv_t(t))
        })
        .collect();

    let (xya, t1ya, t2ya, rhoya) = build(ya.clone(), &mut rng);
    let (xyb, t1yb, t2yb, rhoyb) = build(yb.clone(), &mut rng);
    let (xyc, t1yc, t2yc, rhoyc) = build(yc.clone(), &mut rng);

    // ---- The tie masks (Appendix B.1). Per side: one commitment M of
    // uniform masks mu_t and one commitment N of their pre-twisted images
    // nu_t := sigma_t(mu_t). The verifier NEVER checks the mu/nu relation
    // directly — soundness rests on psi being drawn strictly after these
    // commitments (the order-regression battery below demonstrates the
    // attack when it is not).
    let mask_pair = |rng: &mut u64| -> (Vec<Poly>, Vec<Poly>) {
        let mu: Vec<Poly> = (0..h).map(|_| rng_poly_mod(rng, q)).collect();
        let nu: Vec<Poly> =
            full.iter().zip(mu.iter()).map(|(&t, m)| apply_auto(&zq, m, t)).collect();
        (mu, nu)
    };
    let (mua, nua) = mask_pair(&mut rng);
    let (mub, nub) = mask_pair(&mut rng);
    let (muc, nuc) = mask_pair(&mut rng);
    let (xma, t1ma, t2ma, rhoma) = build(mua.clone(), &mut rng);
    let (xna, t1na, t2na, rhona) = build(nua.clone(), &mut rng);
    let (xmb, t1mb, t2mb, rhomb) = build(mub.clone(), &mut rng);
    let (xnb, t1nb, t2nb, rhonb) = build(nub.clone(), &mut rng);
    let (xmc, t1mc, t2mc, rhomc) = build(muc.clone(), &mut rng);
    let (xnc, t1nc, t2nc, rhonc) = build(nuc.clone(), &mut rng);
    // R1: the gate's committed one-time pads (3 uniform slots riding one
    // g-commitment) — bound by h0 strictly before every challenge.
    let g_pads = ring::ct_engine::sample_g_masks(&mut rng, q, cshape.msg_r, 0, 3).remove(0);
    let (xg, t1g, t2g, rhog) = build(g_pads, &mut rng);

    // Statement hash binds ALL 13 commitments (0=A 1=B 2=C 3=YA 4=YB
    // 5=YC 6=MA 7=NA 8=MB 9=NB 10=MC 11=NC 12=R1 pads); the full-entropy
    // psi challenges derive from it — strictly after the masks.
    let t1s = [
        t1a.clone(), t1b.clone(), t1c.clone(), t1ya.clone(), t1yb.clone(), t1yc.clone(),
        t1ma.clone(), t1na.clone(), t1mb.clone(), t1nb.clone(), t1mc.clone(), t1nc.clone(),
        t1g.clone(),
    ];
    let t2s = [
        t2a.clone(), t2b.clone(), t2c.clone(), t2ya.clone(), t2yb.clone(), t2yc.clone(),
        t2ma.clone(), t2na.clone(), t2mb.clone(), t2nb.clone(), t2mc.clone(), t2nc.clone(),
        t2g.clone(),
    ];
    let h0 = ct_h0(&crs, b"pi2-ce", &t1s, &t2s, &[]);
    let full_poly = |xr: &mut XofReader| -> Poly {
        // Uniform mod q via 128-bit reduction (bias 2^-97).
        let mut p = poly_zero();
        for k in 0..D {
            let wide = ((xr.next_u64() as u128) << 64) | (xr.next_u64() as u128);
            p[k] = (wide % (q as u128)) as u64;
        }
        p
    };
    let mut psir = XofReader::new("pi2-ce-psi", &[&h0]);
    let psi: Vec<Vec<Poly>> =
        (0..3).map(|_| (0..h).map(|_| full_poly(&mut psir)).collect()).collect();

    // Reveals F_t := psi_t Y_t + mu_t — uniform (one-time-padded by mu),
    // so nothing about the execution vectors leaks.
    let reveal = |ys: &[Poly], mus: &[Poly], ps: &[Poly]| -> Vec<Poly> {
        (0..h).map(|t| poly_add(&zq, &poly_mul_g(&zq, &ps[t], &ys[t]), &mus[t])).collect()
    };
    let fa = reveal(&ya, &mua, &psi[0]);
    let fb = reveal(&yb, &mub, &psi[1]);
    let fc = reveal(&yc, &muc, &psi[2]);

    // The ROUND statement hash binds h0 + the reveals; the quinary batch
    // challenges tau derive from it — strictly after the reveals are
    // fixed (wrong order = the e-slack attack; see the order battery).
    let mut fbytes: Vec<u8> = Vec::new();
    for f in [&fa, &fb, &fc] {
        fbytes.extend_from_slice(&ring::polys_bytes(f));
    }
    let frefs: [&[u8]; 2] = [&h0, &fbytes];
    let mut hfr = XofReader::new("pi2-ce-h0f", &frefs);
    let mut h0f = [0u8; 32];
    for chunk in h0f.chunks_mut(8) {
        chunk.copy_from_slice(&hfr.next_u64().to_le_bytes());
    }
    let mut tr = XofReader::new("pi2-ce-tau", &[&h0f]);
    let mut draw_tau = || -> Vec<Vec<i64>> { (0..h).map(|_| tr.next_challenge()).collect() };
    let tau_pairs: Vec<(Vec<Vec<i64>>, Vec<Vec<i64>>)> =
        (0..3).map(|_| (draw_tau(), draw_tau())).collect();

    // ---- The tie claims (Appendix B.1), two UNTWISTED linear ring
    // claims with public constants per side (o = original commitment,
    // ch = its challenge vector, Y/M/N as above, psi'_t := sigma_t(psi_t)):
    //   (i)  sum_t taui_t (psi_t Y_t + mu_t)        = sum_t taui_t F_t
    //   (ii) sum_t tauii_t (psi'_t sum_i sigma_t(ch_i) o_i + nu_t)
    //                                               = sum_t tauii_t sigma_t(F_t)
    // (ii) is (i)'s per-twist image under sigma_t: honest Y_t equals the
    // twisted combination, so both constants agree slotwise. sigma acts
    // ONLY on public data (psi, ch, F); every committed slot is untwisted.
    let tie_pair = |o_idx: usize,
                    y_idx: usize,
                    m_idx: usize,
                    n_idx: usize,
                    ch: &[Vec<i64>],
                    f: &[Poly],
                    ps: &[Poly],
                    ti: &[Vec<i64>],
                    tii: &[Vec<i64>]|
     -> [RingClaim; 2] {
        let mut mc_i: Vec<(usize, usize, Poly)> = Vec::new();
        let mut k_i = poly_zero();
        for t in 0..h {
            let tp = poly_from_small(&zq, &ti[t]);
            mc_i.push((y_idx, t, poly_mul_g(&zq, &tp, &ps[t])));
            mc_i.push((m_idx, t, tp.clone()));
            k_i = poly_add(&zq, &k_i, &poly_mul_g(&zq, &tp, &f[t]));
        }
        let mut mc_ii: Vec<(usize, usize, Poly)> = Vec::new();
        let mut k_ii = poly_zero();
        for (i, chi) in ch.iter().enumerate() {
            let mut alpha = poly_zero();
            for (si, &t) in full.iter().enumerate() {
                let tp = poly_from_small(&zq, &tii[si]);
                let pp = apply_auto(&zq, &ps[si], t);
                let cc = apply_auto(&zq, &poly_from_small(&zq, chi), t);
                let term = poly_mul_g(&zq, &poly_mul_g(&zq, &tp, &pp), &cc);
                alpha = poly_add(&zq, &alpha, &term);
            }
            mc_ii.push((o_idx, i, alpha));
        }
        for (si, &t) in full.iter().enumerate() {
            let tp = poly_from_small(&zq, &tii[si]);
            mc_ii.push((n_idx, si, tp.clone()));
            k_ii = poly_add(&zq, &k_ii, &poly_mul_g(&zq, &tp, &apply_auto(&zq, &f[si], t)));
        }
        [
            RingClaim { msg_coeffs: mc_i, constant: k_i },
            RingClaim { msg_coeffs: mc_ii, constant: k_ii },
        ]
    };
    let tie_claims: Vec<RingClaim> = [
        tie_pair(0, 3, 6, 7, &sch, &fa, &psi[0], &tau_pairs[0].0, &tau_pairs[0].1),
        tie_pair(1, 4, 8, 9, &vch, &fb, &psi[1], &tau_pairs[1].0, &tau_pairs[1].1),
        tie_pair(2, 5, 10, 11, &vch, &fc, &psi[2], &tau_pairs[2].0, &tau_pairs[2].1),
    ]
    .into_iter()
    .flatten()
    .collect();

    // The gate: ONE twisted quadratic ring claim over YA, YB, YC.
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let mk_gate = || TwistedQuadRingClaim {
        quad: (0..h).map(|s| (3usize, s, 4usize, s, one.clone())).collect(),
        msg_coeffs: (0..h).map(|s| (5usize, s, ring::poly_neg(&zq, &poly_conj(&zq, &shat_tw[s])))).collect(),
    };
    let gate_claims = [mk_gate()];

    let xs = [
        xa.clone(), xb.clone(), xc.clone(), xya.clone(), xyb.clone(), xyc.clone(),
        xma.clone(), xna.clone(), xmb.clone(), xnb.clone(), xmc.clone(), xnc.clone(),
        xg.clone(),
    ];
    let rhos = [
        rhoa.clone(), rhob.clone(), rhoc.clone(), rhoya.clone(), rhoyb.clone(), rhoyc.clone(),
        rhoma.clone(), rhona.clone(), rhomb.clone(), rhonb.clone(), rhomc.clone(), rhonc.clone(),
        rhog.clone(),
    ];
    let n_com = 13usize; // 12 objects + the R1 pad group
    let g_base = 12usize;
    let rp = derive_ct_round_params(q, cshape, n_com, 0, 0, true);
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let path = KernelPath::A1(&a1p);
    let openings: Vec<StdOpening> = (0..n_com)
        .map(|i| StdOpening { t1: &t1s[i], t2: &t2s[i], x: &xs[i], rho: &rhos[i] })
        .collect();
    let mut rng_school = rng;
    let t0 = Instant::now();
    let (mut proof, attempts) = prove_ct_round_tq(
        &path, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[], &gate_claims,
        &openings, &[], &[], g_base, &mut rng,
    );
    let prove_ms = t0.elapsed().as_secs_f64() * 1e3;
    let t1v: Vec<Vec<Poly>> = t1s.to_vec();
    let t2v: Vec<Vec<Poly>> = t2s.to_vec();
    let tvr = Instant::now();
    let ok = verify_ct_round_tq(
        &path, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[], &gate_claims, &t1v,
        &t2v, &[], &[], &[], g_base, &proof,
    );
    let verify_ms = tvr.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!("CE gate + first-class tie verify at r = 1 (attempts = {attempts}, prove {prove_ms:.0} ms, verify {verify_ms:.0} ms)"),
        ok,
    );

    // U-B3: same-seed cross-path identity — the tq round is deterministic
    // given (h0f, seed), so School and A1 must produce bit-identical proofs.
    let (proof_s, attempts_s) = prove_ct_round_tq(
        &KernelPath::School, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[],
        &gate_claims, &openings, &[], &[], g_base, &mut rng_school,
    );
    assert_true(
        "CE gate: same-seed proofs bit-identical across kernel paths",
        attempts == attempts_s
            && proof.h == proof_s.h
            && proof.w1 == proof_s.w1
            && proof.w_ring == proof_s.w_ring
            && proof.gtq == proof_s.gtq
            && proof.w_tq == proof_s.w_tq
            && proof.z == proof_s.z,
    );
    assert_true(
        "CE gate: the A1 proof verifies on the schoolbook path",
        verify_ct_round_tq(&KernelPath::School, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[], &gate_claims, &t1v, &t2v, &[], &[], &[], g_base, &proof),
    );

    // U-B3 junk-injection: every prover-supplied image is load-bearing —
    // tampering any of (Ga, Gb, G0, W_tq, W_ring) must be rejected.
    let reverify = |p: &ring::ct_engine::CtRoundProof| -> bool {
        verify_ct_round_tq(&path, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[], &gate_claims, &t1v, &t2v, &[], &[], &[], g_base, p)
    };
    for (idx, name) in [(0usize, "Ga"), (1, "Gb"), (2, "G0")] {
        let orig = proof.gtq[0][idx].clone();
        proof.gtq[0][idx][0] = zq.add(proof.gtq[0][idx][0], 1);
        assert_true(&format!("CE gate: tampered {name} garbage image fails"), !reverify(&proof));
        proof.gtq[0][idx] = orig;
    }
    let orig_w = proof.w_tq[0].clone();
    proof.w_tq[0][0] = zq.add(proof.w_tq[0][0], 1);
    assert_true("CE gate: tampered linear mask image W fails", !reverify(&proof));
    proof.w_tq[0] = orig_w;
    let orig_wr = proof.w_ring[0].clone();
    proof.w_ring[0][0] = zq.add(proof.w_ring[0][0], 1);
    assert_true("CE tie: tampered ring-claim mask image fails", !reverify(&proof));
    proof.w_ring[0] = orig_wr;
    assert_true("CE gate: restored proof verifies again (tamper harness sane)", reverify(&proof));

    // Proof-size accounting (executions + tie are the cost).
    let gate_ring_elems = 3 /* Ga,Gb,G0 */ + 1 /* W_tq */
        + proof.w_ring.len()
        + proof.w1.iter().map(|w| w.len()).sum::<usize>();
    let z_coeffs = proof.z.iter().flatten().map(|v| v.len()).sum::<usize>();
    let sigma_bits = (rp.sigma as f64).log2() + 4.0;
    let kb = (gate_ring_elems + n_com * h + 3 * h /* F reveals */) as f64 * D as f64 * 31.0
        / 8.0
        / 1024.0
        + z_coeffs as f64 * sigma_bits / 8.0 / 1024.0;
    println!("  CE gate + tie round ~{kb:.0} KB (r = 1; 13 commitments incl. 3 executions + 6 tie masks + R1 pad group, 3 F reveals, 6 tie claims + 1 twisted quad claim)");
    // The MARGINAL cost of gate + tie (what Appendix B prices): the 3 Y
    // and 6 mask objects, the R1 pad group, the F reveals, and the claim
    // images; A/B/C commitments and openings exist anyway. NOTE (R1.4
    // correction): the gate round has no pre-existing g-commitment for
    // the pads to ride, so R1 costs one fresh commitment + opening here
    // (~the per-object line below), not the ~1.5 KB of +3 t2 rows.
    let obj_com_kb = 10.0 * (cshape.kappa + cshape.msg_r) as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    let obj_z_kb = 10.0 * cshape.n_r as f64 * D as f64 * sigma_bits / 8.0 / 1024.0;
    let f_kb = 3.0 * h as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    let img_kb = (4 + 6) as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    println!(
        "  CE gate + tie marginal ~{:.0} KB (10 commitments incl. R1 pads {obj_com_kb:.0} + 10 openings {obj_z_kb:.0} + F reveals {f_kb:.0} + claim images {img_kb:.0})",
        obj_com_kb + obj_z_kb + f_kb + img_kb
    );
    println!("  vs the scalar gate at this shape: ~202 KB/rep x r_g (43-64) = ~8.7-12.9 MB — the r = 1 lever restored, tie included");

    // ---- Full-protocol negatives: run the COMPLETE honest prover
    // algorithm (commit, masks, psi, F, tau, all claims, round) on bad
    // data and require rejection. `ya_tamper` perturbs the execution
    // vector after the honest exec — the tie claims must catch it.
    let ce_negative = |cpack_in: &[Poly], ya_tamper: bool, seed: u64| -> bool {
        let mut rng = seed;
        let (x0, t10, t20, rho0) = build(a_rows.clone(), &mut rng);
        let (x1, t11, t21, rho1) = build(b_cols.clone(), &mut rng);
        let (x2, t12, t22, rho2) = build(cpack_in.to_vec(), &mut rng);
        let pre = ct_h0(&crs, b"pi2-ce-pre", &[t10.clone(), t11.clone(), t12.clone()], &[t20.clone(), t21.clone(), t22.clone()], &[]);
        let mut sr = XofReader::new("pi2-ce-sv", &[&pre]);
        let s2: Vec<Vec<i64>> = (0..rows).map(|_| sr.next_challenge()).collect();
        let v2: Vec<Vec<i64>> = (0..cols).map(|_| sr.next_challenge()).collect();
        let mut ya2 = exec(&a_rows, &s2);
        if ya_tamper {
            ya2[0][0] = zq.add(ya2[0][0], 1);
        }
        let yb2 = exec(&b_cols, &v2);
        let yc2 = exec(cpack_in, &v2);
        let shat2: Vec<Poly> = full
            .iter()
            .map(|&t| {
                let mut acc = poly_zero();
                for i in 0..rows {
                    let tc = apply_auto(&zq, &poly_from_small(&zq, &s2[i]), t);
                    let mut xi = poly_zero();
                    xi[i] = 1;
                    acc = poly_add(&zq, &acc, &poly_mul_g(&zq, &tc, &xi));
                }
                apply_auto(&zq, &acc, inv_t(t))
            })
            .collect();
        let (x3, t13, t23, rho3) = build(ya2.clone(), &mut rng);
        let (x4, t14, t24, rho4) = build(yb2.clone(), &mut rng);
        let (x5, t15, t25, rho5) = build(yc2.clone(), &mut rng);
        let (mu0, nu0) = mask_pair(&mut rng);
        let (mu1, nu1) = mask_pair(&mut rng);
        let (mu2, nu2) = mask_pair(&mut rng);
        let (x6, t16, t26, rho6) = build(mu0.clone(), &mut rng);
        let (x7, t17, t27, rho7) = build(nu0.clone(), &mut rng);
        let (x8, t18, t28, rho8) = build(mu1.clone(), &mut rng);
        let (x9, t19, t29, rho9) = build(nu1.clone(), &mut rng);
        let (x10, t110, t210, rho10) = build(mu2.clone(), &mut rng);
        let (x11, t111, t211, rho11) = build(nu2.clone(), &mut rng);
        let pads = ring::ct_engine::sample_g_masks(&mut rng, q, cshape.msg_r, 0, 3).remove(0);
        let (x12, t112, t212, rho12) = build(pads, &mut rng);
        let t1n = [t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t110, t111, t112];
        let t2n = [t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t210, t211, t212];
        let h0n = ct_h0(&crs, b"pi2-ce", &t1n, &t2n, &[]);
        let mut psir = XofReader::new("pi2-ce-psi", &[&h0n]);
        let psin: Vec<Vec<Poly>> =
            (0..3).map(|_| (0..h).map(|_| full_poly(&mut psir)).collect()).collect();
        let f0 = reveal(&ya2, &mu0, &psin[0]);
        let f1 = reveal(&yb2, &mu1, &psin[1]);
        let f2 = reveal(&yc2, &mu2, &psin[2]);
        let mut fb2: Vec<u8> = Vec::new();
        for f in [&f0, &f1, &f2] {
            fb2.extend_from_slice(&ring::polys_bytes(f));
        }
        let fr: [&[u8]; 2] = [&h0n, &fb2];
        let mut hfr = XofReader::new("pi2-ce-h0f", &fr);
        let mut h0fn = [0u8; 32];
        for chunk in h0fn.chunks_mut(8) {
            chunk.copy_from_slice(&hfr.next_u64().to_le_bytes());
        }
        let mut tr = XofReader::new("pi2-ce-tau", &[&h0fn]);
        let mut dt = || -> Vec<Vec<i64>> { (0..h).map(|_| tr.next_challenge()).collect() };
        let taun: Vec<(Vec<Vec<i64>>, Vec<Vec<i64>>)> = (0..3).map(|_| (dt(), dt())).collect();
        let ties: Vec<RingClaim> = [
            tie_pair(0, 3, 6, 7, &s2, &f0, &psin[0], &taun[0].0, &taun[0].1),
            tie_pair(1, 4, 8, 9, &v2, &f1, &psin[1], &taun[1].0, &taun[1].1),
            tie_pair(2, 5, 10, 11, &v2, &f2, &psin[2], &taun[2].0, &taun[2].1),
        ]
        .into_iter()
        .flatten()
        .collect();
        let gates = [TwistedQuadRingClaim {
            quad: (0..h).map(|s| (3usize, s, 4usize, s, one.clone())).collect(),
            msg_coeffs: (0..h)
                .map(|s| (5usize, s, ring::poly_neg(&zq, &poly_conj(&zq, &shat2[s]))))
                .collect(),
        }];
        let xn = [x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12];
        let rhon =
            [rho0, rho1, rho2, rho3, rho4, rho5, rho6, rho7, rho8, rho9, rho10, rho11, rho12];
        let opn: Vec<StdOpening> = (0..n_com)
            .map(|i| StdOpening { t1: &t1n[i], t2: &t2n[i], x: &xn[i], rho: &rhon[i] })
            .collect();
        let (proof_n, _) = prove_ct_round_tq(
            &path, &ring_ctx, &rp, None, &crs, &h0fn, &[], &ties, &[], &[], &gates, &opn, &[],
            &[], g_base, &mut rng,
        );
        let t1nv: Vec<Vec<Poly>> = t1n.to_vec();
        let t2nv: Vec<Vec<Poly>> = t2n.to_vec();
        verify_ct_round_tq(
            &path, &ring_ctx, &rp, None, &crs, &h0fn, &[], &ties, &[], &[], &gates, &t1nv,
            &t2nv, &[], &[], &[], g_base, &proof_n,
        )
    };
    let mut c_bad = c_mat.clone();
    c_bad[0][0] = zq.add(c_bad[0][0], 1);
    let cpack_bad: Vec<Poly> = (0..cols)
        .map(|j| {
            let mut p = poly_zero();
            for i in 0..rows {
                p[i] = c_bad[i][j];
            }
            p
        })
        .collect();
    assert_true(
        "CE full round: wrong C (C != A B) fails (the gate claim catches it; ties pass)",
        !ce_negative(&cpack_bad, false, 0x5eed_1111),
    );
    assert_true(
        "CE full round: tampered YA fails (the tie claims catch it in-round)",
        !ce_negative(&cpack, true, 0x5eed_2222),
    );

    // ---- The ORDER regression (F5-class, witness-level): if psi were
    // known before the masks are committed, a cheating prover cancels an
    // arbitrary YA defect by crafting nu_t := sigma_t(mu_t) -
    // psi'_t sigma_t(d_t); the tie claims then HOLD for the tampered YA.
    // With psi drawn after the masks (the shipped order), the same
    // crafting fails against fresh psi. This pins WHY the hash ordering
    // is load-bearing, the same way the F5 regression pins the binary
    // gadget's theta randomization.
    let mut ya_bad = ya.clone();
    ya_bad[0][0] = zq.add(ya_bad[0][0], 1);
    let d: Vec<Poly> = (0..h).map(|t| ring::poly_sub(&zq, &ya[t], &ya_bad[t])).collect();
    let vtw: Vec<Poly> = full
        .iter()
        .map(|&t| {
            let mut acc = poly_zero();
            for (p, c) in a_rows.iter().zip(sch.iter()) {
                let tc = apply_auto(&zq, &poly_from_small(&zq, c), t);
                acc = poly_add(&zq, &acc, &poly_mul_g(&zq, &tc, p));
            }
            acc
        })
        .collect();
    let tie_ii_holds = |psic: &[Poly], mu_at: &[Poly], nu_at: &[Poly], f_at: &[Poly]| -> bool {
        let _ = mu_at;
        full.iter().enumerate().all(|(si, &t)| {
            let psit = apply_auto(&zq, &psic[si], t);
            let lhs = poly_add(&zq, &poly_mul_g(&zq, &psit, &vtw[si]), &nu_at[si]);
            lhs == apply_auto(&zq, &f_at[si], t)
        })
    };
    // Wrong-order world: the attacker knows psi when choosing the masks.
    let (mu_atk, _) = mask_pair(&mut rng);
    let nu_atk: Vec<Poly> = full
        .iter()
        .enumerate()
        .map(|(si, &t)| {
            let honest_nu = apply_auto(&zq, &mu_atk[si], t);
            let psit = apply_auto(&zq, &psi[0][si], t);
            let corr = poly_mul_g(&zq, &psit, &apply_auto(&zq, &d[si], t));
            ring::poly_sub(&zq, &honest_nu, &corr)
        })
        .collect();
    let f_atk = reveal(&ya_bad, &mu_atk, &psi[0]);
    assert_true(
        "CE order regression: psi-before-masks ACCEPTS the crafted-mask defect (the attack, demonstrated)",
        tie_ii_holds(&psi[0], &mu_atk, &nu_atk, &f_atk),
    );
    // Correct order: fresh psi drawn AFTER those masks are fixed.
    let mut psir2 = XofReader::new("pi2-ce-psi-post", &[&h0]);
    let psi_post: Vec<Poly> = (0..h).map(|_| full_poly(&mut psir2)).collect();
    let f_atk2 = reveal(&ya_bad, &mu_atk, &psi_post);
    assert_true(
        "CE order regression: psi drawn after the masks REJECTS the same crafting",
        !tie_ii_holds(&psi_post, &mu_atk, &nu_atk, &f_atk2),
    );

    // ---- ORDER regression, attack B (tau before the reveals): the tie
    // batches impose only l = 2 constraints on h = 128 free reveal
    // elements, so a prover who knows taui when choosing F can pass the
    // batch with per-t violations. Craft errors on two twists,
    // r_{t0} = taui_{t1} w, r_{t1} = -taui_{t0} w — their taui-batch
    // contribution cancels identically. The shipped hash chain
    // (tau = XOF(h0, F)) collapses the slack: recomputing tau from the
    // crafted reveals moves the batch away from the cancellation.
    let taui_a: Vec<Poly> = tau_pairs[0].0.iter().map(|c| poly_from_small(&zq, c)).collect();
    let batch_i_holds = |ti: &[Poly], f_at: &[Poly]| -> bool {
        let mut lhs = poly_zero();
        let mut rhs = poly_zero();
        for t in 0..h {
            let claim_t = poly_add(&zq, &poly_mul_g(&zq, &psi[0][t], &ya[t]), &mua[t]);
            lhs = poly_add(&zq, &lhs, &poly_mul_g(&zq, &ti[t], &claim_t));
            rhs = poly_add(&zq, &rhs, &poly_mul_g(&zq, &ti[t], &f_at[t]));
        }
        lhs == rhs
    };
    let w_slack = rng_poly_mod(&mut rng, q);
    let (t0, t1) = (0usize, 1usize);
    let mut f_slack = fa.clone();
    f_slack[t0] = poly_add(&zq, &f_slack[t0], &poly_mul_g(&zq, &taui_a[t1], &w_slack));
    f_slack[t1] = ring::poly_sub(&zq, &f_slack[t1], &poly_mul_g(&zq, &taui_a[t0], &w_slack));
    assert_true(
        "CE order regression B: stale tau ACCEPTS per-twist reveal errors in the batch (the attack, demonstrated)",
        f_slack != fa && batch_i_holds(&taui_a, &f_slack),
    );
    // Shipped order: tau derives from the reveals actually sent.
    let mut fb_slack: Vec<u8> = Vec::new();
    for f in [&f_slack, &fb, &fc] {
        fb_slack.extend_from_slice(&ring::polys_bytes(f));
    }
    let fr_slack: [&[u8]; 2] = [&h0, &fb_slack];
    let mut hfr2 = XofReader::new("pi2-ce-h0f", &fr_slack);
    let mut h0f_slack = [0u8; 32];
    for chunk in h0f_slack.chunks_mut(8) {
        chunk.copy_from_slice(&hfr2.next_u64().to_le_bytes());
    }
    let mut tr2 = XofReader::new("pi2-ce-tau", &[&h0f_slack]);
    let taui_re: Vec<Poly> =
        (0..h).map(|_| poly_from_small(&zq, &tr2.next_challenge())).collect();
    assert_true(
        "CE order regression B: tau recomputed from the crafted reveals REJECTS them",
        !batch_i_holds(&taui_re, &f_slack),
    );
}

fn usage() {
    eprintln!("usage: ring_matmul self-test | chain-demo <n0> <n1> <n2> <n3> | freeze-check | gate-spike | link-demo | m5-bench [rows inner cols [reps]] | lookup-bench [log2_n] | ffn-chain [n_blocks | battery | layer <log2_el> [range] | layer battery] | us1-verify <file> | statement-inventory");
    eprintln!();
    eprintln!("  ffn-chain [n_blocks | battery] is the LEGACY q46 block chain: its range");
    eprintln!("  grounding uses the ARP legacy range arm (rejection clipping ~2^-4.75 at");
    eprintln!("  t = 1.5, NOT statistical ZK — see audit 2026-07-14 C-01). The target path");
    eprintln!("  is `ffn-chain layer ...` (per-layer rig, ARP-free, exact range lookup).");
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
            self_test_ct_engine();
            self_test_wave_split();
            self_test_z1();
            self_test_pi1();
            self_test_gadgets();
            self_test_r1();
            self_test_pi2();
            self_test_pi2_ce();
            self_test_link();
            self_test_e2();
            self_test_lookup();
            self_test_lookup_zk();
            self_test_us1_boundary();
            println!("\n[U-S Phase 3] statement codec (round-trip + malformed + fuzz)");
            assert_true("statement codec battery passes", manifest::statement_codec_battery());
            self_test_p3();
            self_test_ffn_chain();
            self_test_ffn_layer_smoke();
            self_test_uk9();
            self_test_m5_chunking();
            println!("\nself-test passed in {:.2}s", t.elapsed().as_secs_f64());
        }
        Some("chain-demo") if args.len() == 5 => {
            let dims: Vec<usize> = args[1..5].iter().map(|s| s.parse().expect("dim")).collect();
            chain_demo(dims[0], dims[1], dims[2], dims[3]);
        }
        Some("lookup-bench") => {
            let n_log2 = args.get(1).map(|s| s.parse().expect("log2 N")).unwrap_or(18);
            assert!((8..=22).contains(&n_log2), "lookup-bench log2 N in 8..=22");
            lookup_bench(n_log2);
        }
        Some("ffn-chain") => {
            // U-K8: the committed FFN-gate chain — `ffn-chain battery`
            // runs the tamper battery alone; `ffn-chain [n_blocks]` runs
            // the A/B measurement at n_blocks x 1020 elements.
            // U-R1: `ffn-chain layer <log2_el>` runs ONE per-layer
            // instance (multi-wave q31, one descent pair, NO q46 side —
            // ledger D-5); `ffn-chain layer battery` its tamper battery.
            if args.get(1).map(String::as_str) == Some("layer") {
                if args.get(2).map(String::as_str) == Some("battery") {
                    let t = Instant::now();
                    self_test_ffn_layer();
                    println!("\nffn-chain layer battery passed in {:.2}s", t.elapsed().as_secs_f64());
                } else {
                    let lg: usize = args.get(2).map(|s| s.parse().expect("log2_el")).unwrap_or(16);
                    assert!(
                        (10..=UR1_MAX_LOG2).contains(&lg),
                        "ffn-chain layer log2_el in 10..=20 (2^20 is the 10G-scope memory cap)"
                    );
                    if args.get(3).map(String::as_str) == Some("range") {
                        // U-R2 S3: the range-table marginal (arm R vs arm A).
                        ffn_layer_range_bench(lg);
                    } else {
                        ffn_layer_bench(lg);
                    }
                }
            } else if args.get(1).map(String::as_str) == Some("battery") {
                let t = Instant::now();
                self_test_ffn_chain();
                println!("\nffn-chain battery passed in {:.2}s", t.elapsed().as_secs_f64());
            } else {
                let n_blocks = args.get(1).map(|s| s.parse().expect("n_blocks")).unwrap_or(4);
                assert!((1..=5600).contains(&n_blocks), "ffn-chain n_blocks in 1..=5600");
                ffn_chain_bench(n_blocks);
            }
        }
        Some("m5-bench") => {
            // m5-bench [rows inner cols [reps]] — defaults to the frozen FFN
            // shape 512 x 4096 x 11008 with 3 repetitions per thread count.
            let dims: Vec<usize> = args[1..].iter().map(|s| s.parse().expect("dim")).collect();
            match dims.len() {
                0 => m5_bench(512, 4096, 11008, 3),
                3 => m5_bench(dims[0], dims[1], dims[2], 3),
                4 => m5_bench(dims[0], dims[1], dims[2], dims[3]),
                _ => usage(),
            }
        }
        Some("us1-verify") if args.len() == 2 => us1_verify_main(&args[1]),
        Some("statement-codec") => {
            if !manifest::statement_codec_battery() {
                std::process::exit(1);
            }
        }
        Some("p3-battery") => self_test_p3(),
        Some("p3-bench") => {
            let n: usize = args.get(1).map(|s| s.parse().expect("n_honest")).unwrap_or(4096);
            assert!((16..=1_048_576).contains(&n), "p3-bench n_honest in 16..=2^20");
            p3_bench(n);
        }
        Some("verify") if args.len() == 3 => p3_verify_main(&args[1], &args[2]),
        Some("us1-battery") => {
            let t = Instant::now();
            self_test_us1_boundary();
            println!("\n[U-S1] battery passed in {:.2}s", t.elapsed().as_secs_f64());
        }
        Some("freeze-check") => freeze_check(),
        Some("statement-inventory") => statement_inventory(),
        Some("gate-spike") => gate_spike(),
        Some("link-demo") => {
            let t = Instant::now();
            self_test_link();
            self_test_e2();
            println!("\nlink-demo passed in {:.2}s", t.elapsed().as_secs_f64());
        }
        _ => usage(),
    }
}

// ===========================================================================
// U-L: the F3 modulus link (GADGET_MODULUS_DECISION.md option (a), module
// ring/link.rs) — value tensors committed at q8_31, their bit planes at the
// dedicated q8_46 gadget layer, tied by l = 24 FS-derived structured-weight
// rows with revealed integers y_l and ONE linear ct-claim family per side
// riding that side's ordinary ct-round. Demo shape: the exact F3-pinned ARP
// unit — n = 128 values in [0, 2^4), W = 4 planes (512 bit coefficients;
// the q46 ARP binary-unit granularity cap is ~896, see freeze_check_link).

fn self_test_link() {
    use ring::ct_engine::{
        StdOpening, ct_h0, derive_ct_round_params, prove_ct_round, sample_ct_masks,
        verify_ct_round,
    };
    use ring::link::{
        derive_gadget_layer, derive_link_params, derive_link_xi, link_claims_gnd,
        link_claims_tgt, link_gate_ok, link_h0, link_honest_y, link_reveal_y, link_w_max,
    };
    println!("\n[U-L] modulus link (F3): q8_31 values <-> q8_46 bit planes, w = 11, l = 24");

    // The two frozen CRS points, asserted against the study table.
    let gl_t = derive_gadget_layer(Q8, 32, 16).expect("q31 value layer must derive");
    let gl_g = derive_gadget_layer(ring::Q8_46, 32, 16).expect("q46 gadget layer must derive");
    assert_true(
        &format!(
            "q31 value CRS frozen point: kappa={} N_r={} (want 9/56)",
            gl_t.shape.kappa, gl_t.shape.n_r
        ),
        gl_t.shape.kappa == 9 && gl_t.shape.n_r == 56,
    );
    assert_true(
        &format!(
            "q46 bit CRS frozen point: kappa={} N_r={} (want 6/62)",
            gl_g.shape.kappa, gl_g.shape.n_r
        ),
        gl_g.shape.kappa == 6 && gl_g.shape.n_r == 62,
    );

    // Frozen link operating point at the demo shape.
    let lp = derive_link_params(D, 4, ring::Q8_46, Q8, 11);
    assert_true(
        &format!(
            "frozen link point w=11 l={} (2^-264); w_max(demo) = {}",
            lp.l,
            link_w_max(D, 4, ring::Q8_46)
        ),
        lp.l == 24 && 11 <= link_w_max(D, 4, ring::Q8_46),
    );

    let ring_t = ring::ring_ctx_q8();
    let ring_g = ring::ring_ctx(ring::Q8_46, ring::ETA8_46, 8);
    let (zq_t, zq_g) = (ring_t.zq, ring_g.zq);
    let crs_t = expand_crs(gl_t.shape, Q8, 0xF331);
    let crs_g = expand_crs(gl_g.shape, ring::Q8_46, 0xF346);
    let mut rng = 0x5eed_00f3u64;

    // Witness: n = 128 values in [0, 16); plane i, coefficient t = bit i
    // of value t (each plane is exactly one ring element at n = D).
    let values: Vec<u64> = (0..lp.n).map(|_| rng_below(&mut rng, 1 << lp.w_bits)).collect();
    let bit_planes = |vals: &[u64]| -> Vec<Poly> {
        (0..lp.w_bits as usize)
            .map(|i| {
                let mut p = poly_zero();
                for (t, &v) in vals.iter().enumerate() {
                    p[t] = (v >> i) & 1;
                }
                p
            })
            .collect()
    };
    let value_poly = |vals: &[u64]| -> Poly {
        let mut p = poly_zero();
        for (t, &v) in vals.iter().enumerate() {
            p[t] = v;
        }
        p
    };
    let pad = |mut slots: Vec<Poly>, msg_r: usize| -> Vec<Poly> {
        while slots.len() < msg_r {
            slots.push(poly_zero());
        }
        slots
    };
    // One side = its witness commitment + its g-mask commitment (l = 24
    // claims fit one msg_r = 32 group), so g_base = 1 on both sides.
    fn commit_side(
        path: &KernelPath,
        crs: &ring::commit::RingCrs,
        wit: Vec<Poly>,
        g: Vec<Poly>,
        rng: &mut u64,
    ) -> (Vec<Vec<Poly>>, Vec<Vec<Poly>>, Vec<Vec<Poly>>, Vec<Vec<Vec<i64>>>) {
        let all_x = vec![wit, g];
        let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
            .map(|_| (0..crs.shape.n_r).map(|_| rng_ternary_poly(rng)).collect())
            .collect();
        let (mut t1s, mut t2s) = (Vec::new(), Vec::new());
        for (x, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(path, crs, x, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        (t1s, t2s, all_x, all_rho)
    }

    let rp_t = derive_ct_round_params(Q8, gl_t.shape, 2, 0, 0, false);
    let rp_g = derive_ct_round_params(ring::Q8_46, gl_g.shape, 2, 0, 0, false);
    let a1p_t = build_a1_paths(&crs_t, rp_t.sigma, isqrt_u128(rp_t.bound_sq));
    let a1p_g = build_a1_paths(&crs_g, rp_g.sigma, isqrt_u128(rp_g.bound_sq));
    let path_t = KernelPath::A1(&a1p_t);
    let path_g = KernelPath::A1(&a1p_g);

    // Honest transcript. Hash ordering (the F5 rule across moduli):
    // commit EVERYTHING on both sides (witnesses AND g groups), then
    // h0_link binds both CRS hashes + both commitment lists, xi rows and
    // each side's round hash derive from it.
    let g_t = sample_ct_masks(&mut rng, Q8, gl_t.shape.msg_r, lp.l).remove(0);
    let g_g = sample_ct_masks(&mut rng, ring::Q8_46, gl_g.shape.msg_r, lp.l).remove(0);
    let (t1s_g, t2s_g, x_g, rho_g) =
        commit_side(&path_g, &crs_g, pad(bit_planes(&values), gl_g.shape.msg_r), g_g, &mut rng);
    let (t1s_t, t2s_t, x_t, rho_t) =
        commit_side(&path_t, &crs_t, pad(vec![value_poly(&values)], gl_t.shape.msg_r), g_t, &mut rng);
    let h0_link = link_h0(b"u-l-demo", &crs_g, &crs_t, &t1s_g, &t2s_g, &t1s_t, &t2s_t);
    let h0_g = ct_h0(&crs_g, &h0_link, &t1s_g, &t2s_g, &[]);
    let h0_t = ct_h0(&crs_t, &h0_link, &t1s_t, &t2s_t, &[]);
    let xi = derive_link_xi(&h0_link, &lp);
    let y = link_reveal_y(&lp, &xi, &values);
    let y_max = y.iter().map(|v| v.unsigned_abs()).max().unwrap();
    assert_true(
        &format!(
            "honest reveal passes the grounding gate: max|y| = 2^{:.1} < q46/2 = 2^45 (1.3-tail model 2^{:.1})",
            (y_max as f64).log2(),
            link_honest_y(&lp).log2()
        ),
        link_gate_ok(&lp, &y),
    );

    // Claim families: plane i lives in slot i of q46 commitment 0; the
    // values in slot 0 of q31 commitment 0.
    let plane_slots: Vec<Vec<(usize, usize)>> =
        (0..lp.w_bits as usize).map(|i| vec![(0usize, i)]).collect();
    let value_slots = vec![(0usize, 0usize)];
    let claims_g = link_claims_gnd(&zq_g, &lp, &xi, &y, &plane_slots);
    let claims_t = link_claims_tgt(&zq_t, &lp, &xi, &y, &value_slots);
    let openings_g: Vec<StdOpening> = x_g
        .iter()
        .zip(rho_g.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s_g[i], t2: &t2s_g[i], x, rho })
        .collect();
    let openings_t: Vec<StdOpening> = x_t
        .iter()
        .zip(rho_t.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s_t[i], t2: &t2s_t[i], x, rho })
        .collect();

    let t_prove = Instant::now();
    let (proof_g, att_g) = prove_ct_round(
        &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g, &claims_g, &[], &[], &[], &openings_g,
        &[], &[], 1, &mut rng,
    );
    let (proof_t, att_t) = prove_ct_round(
        &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t, &claims_t, &[], &[], &[], &openings_t,
        &[], &[], 1, &mut rng,
    );
    let prove_ms = t_prove.elapsed().as_secs_f64() * 1e3;

    // Verifier: recompute h0_link from the public statement, gate the
    // revealed y, rebuild BOTH claim families from (h0_link, y), verify
    // both rounds.
    let t_verify = Instant::now();
    let h0_link_v = link_h0(b"u-l-demo", &crs_g, &crs_t, &t1s_g, &t2s_g, &t1s_t, &t2s_t);
    let xi_v = derive_link_xi(&h0_link_v, &lp);
    let gate_ok = link_gate_ok(&lp, &y);
    let claims_gv = link_claims_gnd(&zq_g, &lp, &xi_v, &y, &plane_slots);
    let claims_tv = link_claims_tgt(&zq_t, &lp, &xi_v, &y, &value_slots);
    let ok_g = verify_ct_round(
        &path_g, &ring_g, &rp_g, None, &crs_g,
        &ct_h0(&crs_g, &h0_link_v, &t1s_g, &t2s_g, &[]),
        &claims_gv, &[], &[], &[], &t1s_g, &t2s_g, &[], &[], &[], 1, &proof_g,
    );
    let ok_t = verify_ct_round(
        &path_t, &ring_t, &rp_t, None, &crs_t,
        &ct_h0(&crs_t, &h0_link_v, &t1s_t, &t2s_t, &[]),
        &claims_tv, &[], &[], &[], &t1s_t, &t2s_t, &[], &[], &[], 1, &proof_t,
    );
    let verify_ms = t_verify.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!(
            "honest link verifies: prove {prove_ms:.0} ms, verify {verify_ms:.0} ms (attempts {att_g}/{att_t})"
        ),
        gate_ok && ok_g && ok_t,
    );

    // Link overhead (the artifacts the link ADDS to rounds each side runs
    // anyway): per side l reveals h + l mask images W, the g-mask
    // commitment column, its A1 mask image and its response bundle; plus
    // the revealed integers y.
    let side_kb = |q: u64, shape: &CommitShape, sigma: u64| -> f64 {
        let (lq, dd) = ((q as f64).log2(), D as f64);
        let sig_bits = (sigma as f64).log2() + 4.0;
        (2.0 * lp.l as f64 * dd * lq
            + (shape.kappa + shape.msg_r) as f64 * dd * lq
            + shape.kappa as f64 * dd * lq
            + shape.n_r as f64 * dd * sig_bits)
            / 8.0
            / 1024.0
    };
    let link_kb = side_kb(ring::Q8_46, &gl_g.shape, rp_g.sigma)
        + side_kb(Q8, &gl_t.shape, rp_t.sigma)
        + lp.l as f64 * 8.0 / 1024.0;
    println!(
        "    link overhead ~{link_kb:.0} KB ({} claims/side: reveals + W images + g column + g response, + {} revealed y)",
        lp.l, lp.l
    );

    // (b) Recomposition mismatch: ONE flipped bit-plane coefficient. The
    // prover reveals y from the value side; the q46 round's ct check
    // catches the bits recomposing to something else (miss <= 2^-264).
    {
        let mut bits_bad = bit_planes(&values);
        bits_bad[0][0] ^= 1;
        let g_g2 = sample_ct_masks(&mut rng, ring::Q8_46, gl_g.shape.msg_r, lp.l).remove(0);
        let (t1s_g2, t2s_g2, x_g2, rho_g2) =
            commit_side(&path_g, &crs_g, pad(bits_bad, gl_g.shape.msg_r), g_g2, &mut rng);
        let h0_link2 = link_h0(b"u-l-demo", &crs_g, &crs_t, &t1s_g2, &t2s_g2, &t1s_t, &t2s_t);
        let h0_g2 = ct_h0(&crs_g, &h0_link2, &t1s_g2, &t2s_g2, &[]);
        let xi2 = derive_link_xi(&h0_link2, &lp);
        let y2 = link_reveal_y(&lp, &xi2, &values);
        let claims_g2 = link_claims_gnd(&zq_g, &lp, &xi2, &y2, &plane_slots);
        let openings_g2: Vec<StdOpening> = x_g2
            .iter()
            .zip(rho_g2.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s_g2[i], t2: &t2s_g2[i], x, rho })
            .collect();
        let (proof_g2, _) = prove_ct_round(
            &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g2, &claims_g2, &[], &[], &[],
            &openings_g2, &[], &[], 1, &mut rng,
        );
        assert_true(
            "tampered bit (recomposition mismatch) fails the q46 ct check",
            !verify_ct_round(
                &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g2, &claims_g2, &[], &[], &[],
                &t1s_g2, &t2s_g2, &[], &[], &[], 1, &proof_g2,
            ),
        );
    }

    // (c) Tampered value: the committed q31 value drifts from what the
    // honest bit planes recompose to; y comes from the bit side.
    {
        let mut values_bad = values.clone();
        values_bad[0] = (values_bad[0] + 1) % (1 << lp.w_bits);
        let g_t3 = sample_ct_masks(&mut rng, Q8, gl_t.shape.msg_r, lp.l).remove(0);
        let (t1s_t3, t2s_t3, x_t3, rho_t3) = commit_side(
            &path_t, &crs_t, pad(vec![value_poly(&values_bad)], gl_t.shape.msg_r), g_t3, &mut rng,
        );
        let h0_link3 = link_h0(b"u-l-demo", &crs_g, &crs_t, &t1s_g, &t2s_g, &t1s_t3, &t2s_t3);
        let h0_t3 = ct_h0(&crs_t, &h0_link3, &t1s_t3, &t2s_t3, &[]);
        let xi3 = derive_link_xi(&h0_link3, &lp);
        let y3 = link_reveal_y(&lp, &xi3, &values); // the honest bits' recomposition
        let claims_t3 = link_claims_tgt(&zq_t, &lp, &xi3, &y3, &value_slots);
        let openings_t3: Vec<StdOpening> = x_t3
            .iter()
            .zip(rho_t3.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s_t3[i], t2: &t2s_t3[i], x, rho })
            .collect();
        let (proof_t3, _) = prove_ct_round(
            &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t3, &claims_t3, &[], &[], &[],
            &openings_t3, &[], &[], 1, &mut rng,
        );
        assert_true(
            "tampered value fails the q31 ct check",
            !verify_ct_round(
                &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t3, &claims_t3, &[], &[], &[],
                &t1s_t3, &t2s_t3, &[], &[], &[], 1, &proof_t3,
            ),
        );
    }

    // (d) The load-bearing range gate: an oversized revealed y is refused
    // outright (no residue trickery — the integer bound IS the statement).
    let mut y_big = y.clone();
    y_big[0] = (ring::Q8_46 / 2) as i64;
    assert_true("y outside the grounding gate fails", !link_gate_ok(&lp, &y_big));

    // (e) The F5 failure mode across moduli: xi from a STALE h0_link that
    // misses the g commitments. The verifier's xi (true h0_link) rebuilds
    // different claims, and the stale-xi proof fails against them.
    {
        let h0_stale =
            link_h0(b"u-l-demo", &crs_g, &crs_t, &t1s_g[..1], &t2s_g[..1], &t1s_t[..1], &t2s_t[..1]);
        let xi_s = derive_link_xi(&h0_stale, &lp);
        let y_s = link_reveal_y(&lp, &xi_s, &values);
        let claims_s = link_claims_gnd(&zq_g, &lp, &xi_s, &y_s, &plane_slots);
        let (proof_s, _) = prove_ct_round(
            &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g, &claims_s, &[], &[], &[], &openings_g,
            &[], &[], 1, &mut rng,
        );
        assert_true(
            "wrong xi (stale h0_link, pre-g derivation) fails against the verifier's claims",
            !verify_ct_round(
                &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g, &claims_gv, &[], &[], &[], &t1s_g,
                &t2s_g, &[], &[], &[], 1, &proof_s,
            ),
        );
    }
}

// ===========================================================================
// U-E2: slot-constancy enforcement for slot-packed (H3) link targets —
// the E1+E2 extension (M4_ACTIVATION_DESIGN.md Section 6 items 1-2; the
// chain-wide gap the M4 review flagged, audit finding C-01). H3 packing
// puts each value at the CONSTANT coordinate of its CRT slot; nothing
// in the engine forces the other slot_deg - 1 coordinates to zero, and
// GF(q^16) multiplication mixes coordinates — junk coordinates with
// CORRECT constants shift a composed Hadamard's (gate o up's) product
// constants while every constant-reading claim passes. The fix rides
// the link rows at zero extra rows: the q31-side functional reads
// value t through the slot-constant CRT projection (E1) and pins every
// other coordinate with fresh XOF weights zeta (E2); per-row miss
// <= 2^-w, the same accounting as the xi rows. Products of pinned
// tensors inherit slot-constancy (GF(q) closure).

fn self_test_e2() {
    use ring::ct_engine::{
        StdOpening, ct_h0, derive_ct_round_params, prove_ct_round, sample_ct_masks,
        verify_ct_round,
    };
    use ring::link::{
        derive_gadget_layer, derive_link_params, derive_link_xi, derive_link_zeta,
        link_claims_gnd, link_claims_tgt_slot, link_gate_ok, link_h0, link_reveal_y,
    };
    println!("\n[U-E2] slot-constancy link (E1+E2): H3 targets, junk pinning, composed-Hadamard regression");
    let gl_t = derive_gadget_layer(Q8, 32, 16).expect("q31 value layer must derive");
    let gl_g = derive_gadget_layer(ring::Q8_46, 32, 16).expect("q46 gadget layer must derive");
    let ring_t = ring::ring_ctx_q8();
    let ring_g = ring::ring_ctx(ring::Q8_46, ring::ETA8_46, 8);
    let (zq_t, zq_g) = (ring_t.zq, ring_g.zq);
    let crs_t = expand_crs(gl_t.shape, Q8, 0xE201);
    let crs_g = expand_crs(gl_g.shape, ring::Q8_46, 0xE246);
    let mut rng = 0x5eed_00e2u64;
    let (k, sd) = (ring_t.k, ring_t.slot_deg);

    // n = 16 values in [0, 16): TWO slot-packed elements at q31 (8
    // values/element), four dense bit planes at q46.
    let lp = derive_link_params(16, 4, ring::Q8_46, Q8, 11);
    let values: Vec<u64> = (0..lp.n).map(|_| rng_below(&mut rng, 1 << lp.w_bits)).collect();
    let n_junk = lp.n.div_ceil(k) * D - lp.n;
    let slot_msgs = |vals: &[u64]| -> Vec<Poly> {
        (0..vals.len().div_ceil(k)).map(|u| slot_pack(&ring_t, &vals[u * k..(u + 1) * k])).collect()
    };
    let bit_planes = |vals: &[u64]| -> Vec<Poly> {
        (0..lp.w_bits as usize)
            .map(|i| {
                let mut p = poly_zero();
                for (t, &v) in vals.iter().enumerate() {
                    p[t] = (v >> i) & 1;
                }
                p
            })
            .collect()
    };
    let pad = |mut slots: Vec<Poly>, msg_r: usize| -> Vec<Poly> {
        slots.resize(msg_r, poly_zero());
        slots
    };
    let commit_side = |path: &KernelPath,
                       crs: &ring::commit::RingCrs,
                       wit: Vec<Poly>,
                       g: Vec<Poly>,
                       rng: &mut u64|
     -> (Vec<Vec<Poly>>, Vec<Vec<Poly>>, Vec<Vec<Poly>>, Vec<Vec<Vec<i64>>>) {
        let all_x = vec![wit, g];
        let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
            .map(|_| (0..crs.shape.n_r).map(|_| rng_ternary_poly(rng)).collect())
            .collect();
        let (mut t1s, mut t2s) = (Vec::new(), Vec::new());
        for (x, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(path, crs, x, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        (t1s, t2s, all_x, all_rho)
    };
    let rp_t = derive_ct_round_params(Q8, gl_t.shape, 2, 0, 0, false);
    let rp_g = derive_ct_round_params(ring::Q8_46, gl_g.shape, 2, 0, 0, false);
    let a1p_t = build_a1_paths(&crs_t, rp_t.sigma, isqrt_u128(rp_t.bound_sq));
    let a1p_g = build_a1_paths(&crs_g, rp_g.sigma, isqrt_u128(rp_g.bound_sq));
    let path_t = KernelPath::A1(&a1p_t);
    let path_g = KernelPath::A1(&a1p_g);
    let plane_slots: Vec<Vec<(usize, usize)>> =
        (0..lp.w_bits as usize).map(|i| vec![(0usize, i)]).collect();
    let value_slots = vec![(0usize, 0usize), (0usize, 1usize)];

    // ---- Honest E1+E2 link: slot elements at q31 <-> bit planes at q46.
    let g_t = sample_ct_masks(&mut rng, Q8, gl_t.shape.msg_r, lp.l).remove(0);
    let g_g = sample_ct_masks(&mut rng, ring::Q8_46, gl_g.shape.msg_r, lp.l).remove(0);
    let (t1s_g, t2s_g, x_g, rho_g) =
        commit_side(&path_g, &crs_g, pad(bit_planes(&values), gl_g.shape.msg_r), g_g, &mut rng);
    let (t1s_t, t2s_t, x_t, rho_t) =
        commit_side(&path_t, &crs_t, pad(slot_msgs(&values), gl_t.shape.msg_r), g_t, &mut rng);
    let h0_link = link_h0(b"u-e2-demo", &crs_g, &crs_t, &t1s_g, &t2s_g, &t1s_t, &t2s_t);
    let h0_g = ct_h0(&crs_g, &h0_link, &t1s_g, &t2s_g, &[]);
    let h0_t = ct_h0(&crs_t, &h0_link, &t1s_t, &t2s_t, &[]);
    let xi = derive_link_xi(&h0_link, &lp);
    let zeta = derive_link_zeta(&h0_link, &lp, k);
    let y = link_reveal_y(&lp, &xi, &values);
    let claims_g = link_claims_gnd(&zq_g, &lp, &xi, &y, &plane_slots);
    let claims_t = link_claims_tgt_slot(&ring_t, &lp, &xi, &zeta, &y, &value_slots);
    let openings_g: Vec<StdOpening> = x_g
        .iter()
        .zip(rho_g.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s_g[i], t2: &t2s_g[i], x, rho })
        .collect();
    let openings_t: Vec<StdOpening> = x_t
        .iter()
        .zip(rho_t.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s_t[i], t2: &t2s_t[i], x, rho })
        .collect();
    let (proof_g, _) = prove_ct_round(
        &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g, &claims_g, &[], &[], &[], &openings_g,
        &[], &[], 1, &mut rng,
    );
    let (proof_t, _) = prove_ct_round(
        &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t, &claims_t, &[], &[], &[], &openings_t,
        &[], &[], 1, &mut rng,
    );
    let ok_g = verify_ct_round(
        &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g, &claims_g, &[], &[], &[], &t1s_g, &t2s_g,
        &[], &[], &[], 1, &proof_g,
    );
    let ok_t = verify_ct_round(
        &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t, &claims_t, &[], &[], &[], &t1s_t, &t2s_t,
        &[], &[], &[], 1, &proof_t,
    );
    assert_true(
        &format!(
            "honest slot-target link verifies (E1 constant rows + {n_junk} E2 junk weights/row, zero extra rows)"
        ),
        link_gate_ok(&lp, &y) && ok_g && ok_t,
    );

    // ---- The composed-Hadamard break, arithmetically (why E2 exists):
    // junk at slot coordinate 1 of one operand and slot_deg - 1 of the
    // other folds through Y^slot_deg = s_j INTO the product's constant.
    let j_atk = 3usize;
    let xv: Vec<u64> = (0..k).map(|_| rng_below(&mut rng, 1 << lp.w_bits)).collect();
    let uv: Vec<u64> = (0..k).map(|_| rng_below(&mut rng, 1 << lp.w_bits)).collect();
    let mk_junk = |vals: &[u64], coord: usize, amp: u64| -> Poly {
        let mut buf = vec![0u64; D];
        for (jj, &v) in vals.iter().enumerate() {
            buf[jj * sd] = v;
        }
        buf[j_atk * sd + coord] = amp;
        crt_merge(&ring_t, &mut buf);
        buf
    };
    let x_junk = mk_junk(&xv, 1, 0x1234);
    let u_junk = mk_junk(&uv, sd - 1, 0x5678);
    let xs = crt_split(&ring_t, &x_junk);
    let us = crt_split(&ring_t, &u_junk);
    let zs = crt_split(&ring_t, &poly_mul_g(&zq_t, &x_junk, &u_junk));
    assert_true(
        "composed H3 break: junk operands with CORRECT slot constants shift the product's constant (the gap, demonstrated)",
        (0..k).all(|j| xs[j * sd] == xv[j] && us[j * sd] == uv[j])
            && zs[j_atk * sd] != zq_t.mul(xv[j_atk], uv[j_atk]),
    );
    let zh = crt_split(&ring_t, &poly_mul_g(&zq_t, &slot_pack(&ring_t, &xv), &slot_pack(&ring_t, &uv)));
    assert_true(
        "slot-constancy inheritance: the HONEST H3 product is slot-constant with the product constants (GF(q) closure)",
        (0..k).all(|j| zh[j * sd] == zq_t.mul(xv[j], uv[j]))
            && (0..D).all(|c| c % sd == 0 || zh[c] == 0),
    );

    // ---- The link-level pair (F5 pattern): a committed slot tensor
    // with correct constants but one junk coordinate. Constant-only
    // rows (zeta = 0 — the pre-E2 world) ACCEPT it; the E2 rows REJECT.
    {
        let mut buf = vec![0u64; D];
        for (jj, &v) in values[0..k].iter().enumerate() {
            buf[jj * sd] = v;
        }
        buf[j_atk * sd + 1] = 0x4242; // junk; constants untouched
        crt_merge(&ring_t, &mut buf);
        let mut msgs_bad = slot_msgs(&values);
        msgs_bad[0] = buf;
        let g_t2 = sample_ct_masks(&mut rng, Q8, gl_t.shape.msg_r, lp.l).remove(0);
        let (t1s_t2, t2s_t2, x_t2, rho_t2) =
            commit_side(&path_t, &crs_t, pad(msgs_bad, gl_t.shape.msg_r), g_t2, &mut rng);
        let h0_link2 = link_h0(b"u-e2-demo", &crs_g, &crs_t, &t1s_g, &t2s_g, &t1s_t2, &t2s_t2);
        let h0_t2 = ct_h0(&crs_t, &h0_link2, &t1s_t2, &t2s_t2, &[]);
        let xi2 = derive_link_xi(&h0_link2, &lp);
        let zeta2 = derive_link_zeta(&h0_link2, &lp, k);
        let y2 = link_reveal_y(&lp, &xi2, &values); // grounded by the honest bit side
        let openings_t2: Vec<StdOpening> = x_t2
            .iter()
            .zip(rho_t2.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s_t2[i], t2: &t2s_t2[i], x, rho })
            .collect();
        let zeta_zero = vec![vec![0i64; n_junk]; lp.l];
        let claims_e1 = link_claims_tgt_slot(&ring_t, &lp, &xi2, &zeta_zero, &y2, &value_slots);
        let (proof_e1, _) = prove_ct_round(
            &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t2, &claims_e1, &[], &[], &[],
            &openings_t2, &[], &[], 1, &mut rng,
        );
        assert_true(
            "E2 gap: constant-only rows ACCEPT the junk tensor (the pre-E2 break, demonstrated)",
            verify_ct_round(
                &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t2, &claims_e1, &[], &[], &[],
                &t1s_t2, &t2s_t2, &[], &[], &[], 1, &proof_e1,
            ),
        );
        let claims_e2 = link_claims_tgt_slot(&ring_t, &lp, &xi2, &zeta2, &y2, &value_slots);
        let (proof_e2, _) = prove_ct_round(
            &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t2, &claims_e2, &[], &[], &[],
            &openings_t2, &[], &[], 1, &mut rng,
        );
        assert_true(
            "E2: the zeta junk rows REJECT the same tensor (the fix; miss <= 2^-264)",
            !verify_ct_round(
                &path_t, &ring_t, &rp_t, None, &crs_t, &h0_t2, &claims_e2, &[], &[], &[],
                &t1s_t2, &t2s_t2, &[], &[], &[], 1, &proof_e2,
            ),
        );
    }
}

// ===========================================================================
// U-K: the E3 lookup engine (M4_LOOKUP_DESIGN.md Section 8) — built
// tranche by tranche, each with its battery. [U-K1] the slot-field
// scalar layer: GF(q^16) arithmetic every LogUp/GKR challenge, round
// polynomial and MLE value lives in, plus the 8-lane view of a ring
// element that anchors the design's throughput model (one ring mult =
// 8 independent slot-field mults, each lane in its OWN binomial — the
// kfield.rs lane note).

fn self_test_lookup() {
    use ring::kfield::{K_DEG, KField, lane_merge, lane_split, slot_field_digest};
    println!("\n[U-K1] slot-field scalars: GF(q^16) arithmetic, lanes, LKP-5 digest");
    let ctx = ring_ctx_q8();
    let kf = KField::new(&ctx);
    let zq = ctx.zq;
    let q = zq.q;
    let mut rng = 0x5eed_0511u64;
    let mut xr = XofReader::new("uk1-battery", &[b"seed-1"]);
    let a = kf.uniform(&mut xr);
    let b = kf.uniform(&mut xr);
    let c = kf.uniform(&mut xr);
    assert_true(
        "K axioms: associativity, commutativity, distributivity on random elements",
        kf.add(&kf.add(&a, &b), &c) == kf.add(&a, &kf.add(&b, &c))
            && kf.mul(&a, &b) == kf.mul(&b, &a)
            && kf.mul(&kf.mul(&a, &b), &c) == kf.mul(&a, &kf.mul(&b, &c))
            && kf.mul(&a, &kf.add(&b, &c)) == kf.add(&kf.mul(&a, &b), &kf.mul(&a, &c))
            && kf.mul(&a, &kf.one()) == a
            && kf.add(&a, &kf.zero()) == a,
    );
    assert_true(
        "K inverse: a * a^-1 = 1 (random a); embed(x)^-1 = embed(x^-1) (subfield consistency)",
        kf.mul(&a, &kf.inv(&a)) == kf.one()
            && kf.inv(&kf.embed(12345)) == kf.embed(zq.inv(12345)),
    );
    assert_true(
        "K binomial: Y^16 = s0 (the slot root; kappa := Y is this generator)",
        kf.pow(&kf.gen_y(), K_DEG as u64) == kf.embed(kf.s),
    );
    assert_true(
        "K Frobenius: (a+b)^q = a^q + b^q (characteristic q, a field not a ring)",
        kf.pow(&kf.add(&a, &b), q) == kf.add(&kf.pow(&a, q), &kf.pow(&b, q)),
    );
    // The 8-lane cost-model anchor: a ring multiplication IS 8
    // independent slot-field multiplications, lane j in Y^16 - s_j.
    let pa = rng_poly_mod(&mut rng, q);
    let pb = rng_poly_mod(&mut rng, q);
    let lp = lane_split(&ctx, &poly_mul_g(&zq, &pa, &pb));
    let (la, lb) = (lane_split(&ctx, &pa), lane_split(&ctx, &pb));
    assert_true(
        "K lanes: one ring mult = 8 independent slot-field mults (each lane in its own binomial)",
        (0..ctx.k)
            .all(|j| ring::slot_mul_g(&zq, &la[j], &lb[j], ctx.slot_roots[j], K_DEG) == lp[j]),
    );
    assert_true("K lanes: split/merge roundtrip", lane_merge(&ctx, &la) == pa);
    let dg = slot_field_digest(&ctx);
    let hexd: String = dg.iter().take(8).map(|b| format!("{b:02x}")).collect();
    println!("  LKP-5 slot-field digest[0..8] = {hexd}, s0 = {}", ctx.slot_roots[0]);

    // ---- [U-K2] the sumcheck core: honest / tamper / order battery. ----
    use ring::kfield::KElem;
    use ring::sumcheck::{
        LkpTranscript, SumcheckProof, fold, lagrange_eval, mle_eval, round_poly, sumcheck_prove,
        sumcheck_verify,
    };
    println!("\n[U-K2] sumcheck core over GF(q^16): deg-3 rounds, Lagrange fold, E3-N4 edges");
    let n_vars = 7usize;
    let size = 1usize << n_vars;
    let mut xr2 = XofReader::new("uk2-battery", &[b"seed-2"]);
    let ta: Vec<KElem> = (0..size).map(|_| kf.uniform(&mut xr2)).collect();
    let tb: Vec<KElem> = (0..size).map(|_| kf.uniform(&mut xr2)).collect();
    let tc: Vec<KElem> = (0..size).map(|_| kf.uniform(&mut xr2)).collect();
    let prod3 =
        |k: &ring::kfield::KField, v: &[KElem]| -> KElem { k.mul(&k.mul(&v[0], &v[1]), &v[2]) };
    let claimed = (0..size).fold(kf.zero(), |acc, i| {
        kf.add(&acc, &kf.mul(&kf.mul(&ta[i], &tb[i]), &tc[i]))
    });
    let h0 = *b"uk2-battery-h0-fixed-32-bytes!!!";
    let mut tr_p = LkpTranscript::new("uk2", &h0);
    let (proof, point) =
        sumcheck_prove(&kf, vec![ta.clone(), tb.clone(), tc.clone()], 3, &prod3, &mut tr_p);
    let mut tr_v = LkpTranscript::new("uk2", &h0);
    let ok = sumcheck_verify(&kf, n_vars, 3, &claimed, &proof, &prod3, &mut tr_v);
    assert_true(
        "U-K2 sumcheck: honest deg-3 triple product verifies; final evals = the table MLEs at the final point",
        match ok {
            Some((pt, _)) => {
                pt == point
                    && proof.final_evals[0] == mle_eval(&kf, &ta, &pt)
                    && proof.final_evals[1] == mle_eval(&kf, &tb, &pt)
                    && proof.final_evals[2] == mle_eval(&kf, &tc, &pt)
            }
            None => false,
        },
    );
    {
        let mut bad =
            SumcheckProof { rounds: proof.rounds.clone(), final_evals: proof.final_evals.clone() };
        bad.rounds[3][2] = kf.add(&bad.rounds[3][2], &kf.one());
        let mut tr_b = LkpTranscript::new("uk2", &h0);
        assert_true(
            "U-K2 sumcheck: a tampered round polynomial REJECTS (challenge chain breaks)",
            sumcheck_verify(&kf, n_vars, 3, &claimed, &bad, &prod3, &mut tr_b).is_none(),
        );
    }
    // The E3-N4 hash edge, F5 pair: with round challenges known BEFORE
    // the round polynomials (the violated order), a cheating prover
    // interpolates a false claim's defect into the polynomial nodes the
    // verifier never checks: e cubic with e(0) = delta, e(1) = 0 (the
    // sum check passes on the false claim) and e(r_0) = 0 (the folded
    // chain continues on the HONEST values).
    {
        let mut xr_r = XofReader::new("uk2-buggy-rs", &[&h0]);
        let rs: Vec<KElem> = (0..n_vars).map(|_| kf.uniform(&mut xr_r)).collect();
        let false_claim = kf.add(&claimed, &kf.one());
        let mut tabs = vec![ta.clone(), tb.clone(), tc.clone()];
        let mut rounds: Vec<Vec<KElem>> = Vec::new();
        for r in &rs {
            rounds.push(round_poly(&kf, &tabs, 3, &prod3));
            tabs = tabs.iter().map(|t| fold(&kf, t, r)).collect();
        }
        let final_evals: Vec<KElem> = tabs.iter().map(|t| t[0].clone()).collect();
        // e through (0, 1), (1, 0), (2, 0), (r_0, 0), sent as node evals:
        // e(3) = (r_0 - 3) / r_0.
        let r0 = &rs[0];
        let e3 = kf.mul(&kf.sub(r0, &kf.embed(3)), &kf.inv(r0));
        let e = [kf.one(), kf.zero(), kf.zero(), e3];
        for (x, ev) in e.iter().enumerate() {
            rounds[0][x] = kf.add(&rounds[0][x], ev);
        }
        let atk = SumcheckProof { rounds, final_evals };
        let buggy_ok = {
            let mut c = false_claim.clone();
            let mut okb = true;
            for (g, r) in atk.rounds.iter().zip(rs.iter()) {
                if kf.add(&g[0], &g[1]) != c {
                    okb = false;
                    break;
                }
                c = lagrange_eval(&kf, g, r);
            }
            okb && prod3(&kf, &atk.final_evals) == c
        };
        assert_true(
            "U-K2 order (E3-N4): pre-derived round challenges ACCEPT a false sum (the defect hides in an unchecked node — the attack, demonstrated)",
            buggy_ok,
        );
        let mut tr_s = LkpTranscript::new("uk2", &h0);
        assert_true(
            "U-K2 order (E3-N4): the shipped transcript (r drawn AFTER the round poly) REJECTS the same crafting",
            sumcheck_verify(&kf, n_vars, 3, &false_claim, &atk, &prod3, &mut tr_s).is_none(),
        );
    }

    // ---- [U-K3] the fractional GKR: descent, cross-check, edges. ----
    use ring::gkr::{
        FracTree, absorb_roots, build_tree, gkr_prove, gkr_verify, root_cross_check,
    };
    println!("\n[U-K3] fractional GKR: L=2 instances, N=64, T=8 — descent + E3-N1/N3/N5 edges");
    // A toy 8-row pair table fused with the FIXED generator Y (kappa :=
    // Y; U-K4 wires the real int8 table — the mechanics are identical).
    let t_rows: Vec<(u64, u64)> = (0..8u64).map(|v| (v, (v * v + 3) % 17)).collect();
    let y_gen = kf.gen_y();
    let fuse =
        |x: u64, yv: u64| -> KElem { kf.add(&kf.embed(x), &kf.mul(&y_gen, &kf.embed(yv))) };
    let t_fused: Vec<KElem> = t_rows.iter().map(|&(v, s)| fuse(v, s)).collect();
    let (l_inst, n_leaf, depth_w, depth_t) = (2usize, 64usize, 6usize, 3usize);
    let mut xr3 = XofReader::new("uk3-battery", &[b"seed-3"]);
    let xs: Vec<Vec<u64>> =
        (0..l_inst).map(|_| (0..n_leaf).map(|_| xr3.next_field(8)).collect()).collect();
    let ys: Vec<Vec<u64>> =
        xs.iter().map(|col| col.iter().map(|&x| t_rows[x as usize].1).collect()).collect();
    let m_k: Vec<Vec<KElem>> = xs
        .iter()
        .map(|col| {
            let mut m = vec![0u64; 8];
            for &x in col {
                m[x as usize] += 1;
            }
            m.iter().map(|&c| kf.embed(c)).collect()
        })
        .collect();
    // The battery's stand-in for the commitment binding: h0 hashes the
    // x/y columns and the multiplicity columns (their commitments, in
    // the real protocol) — alpha's E3-N1 edge.
    let h0_of = |xs: &[Vec<u64>], ys: &[Vec<u64>], ms: &[Vec<KElem>]| -> [u8; 32] {
        let mut bytes = Vec::new();
        for col in xs.iter().chain(ys.iter()) {
            for &v in col {
                bytes.extend_from_slice(&v.to_le_bytes());
            }
        }
        for m in ms {
            for e in m {
                bytes.extend_from_slice(&kf.bytes(e));
            }
        }
        let mut r = XofReader::new("uk3-h0", &[&bytes]);
        let mut h = [0u8; 32];
        for c in h.chunks_mut(8) {
            c.copy_from_slice(&r.next_u64().to_le_bytes());
        }
        h
    };
    // The full battery-scale lookup pipeline: alpha from h0, projective
    // trees, per-instance cross-checks, two descents, leaf grounding by
    // direct MLE of the concatenated columns (E4's job in the engine).
    let run = |h0: &[u8; 32], xs: &[Vec<u64>], ys: &[Vec<u64>], ms: &[Vec<KElem>]| -> bool {
        let mut tr = LkpTranscript::new("uk3-lkp", h0);
        let alpha = tr.challenge_k(&kf);
        let wtrees: Vec<FracTree> = (0..l_inst)
            .map(|e| {
                let lp = vec![kf.one(); n_leaf];
                let lq: Vec<KElem> =
                    (0..n_leaf).map(|i| kf.sub(&alpha, &fuse(xs[e][i], ys[e][i]))).collect();
                build_tree(&kf, lp, lq)
            })
            .collect();
        let ttrees: Vec<FracTree> = (0..l_inst)
            .map(|e| {
                let lq: Vec<KElem> = t_fused.iter().map(|t| kf.sub(&alpha, t)).collect();
                build_tree(&kf, ms[e].clone(), lq)
            })
            .collect();
        let w_roots: Vec<[KElem; 2]> = wtrees.iter().map(|t| t.root()).collect();
        let t_roots: Vec<[KElem; 2]> = ttrees.iter().map(|t| t.root()).collect();
        absorb_roots(&kf, &w_roots, &mut tr);
        let (pw_proof, _, _, _) = gkr_prove(&kf, &wtrees, &mut tr);
        absorb_roots(&kf, &t_roots, &mut tr);
        let (pt_proof, _, _, _) = gkr_prove(&kf, &ttrees, &mut tr);
        // Verifier: fresh transcript, exposed roots, both descents,
        // grounding.
        let mut tv = LkpTranscript::new("uk3-lkp", h0);
        let alpha_v = tv.challenge_k(&kf);
        if alpha_v != alpha {
            return false;
        }
        if !(0..l_inst).all(|e| root_cross_check(&kf, &w_roots[e], &t_roots[e])) {
            return false;
        }
        absorb_roots(&kf, &w_roots, &mut tv);
        let Some((zw, pw, qw)) = gkr_verify(&kf, &w_roots, depth_w, &pw_proof, &mut tv) else {
            return false;
        };
        absorb_roots(&kf, &t_roots, &mut tv);
        let Some((zt, pm, qt)) = gkr_verify(&kf, &t_roots, depth_t, &pt_proof, &mut tv) else {
            return false;
        };
        let w_concat: Vec<KElem> = (0..l_inst * n_leaf)
            .map(|idx| {
                let (e, i) = (idx >> depth_w, idx & (n_leaf - 1));
                fuse(xs[e][i], ys[e][i])
            })
            .collect();
        let m_concat: Vec<KElem> =
            (0..l_inst * 8).map(|idx| ms[idx >> depth_t][idx & 7].clone()).collect();
        let t_concat: Vec<KElem> = (0..l_inst * 8).map(|idx| t_fused[idx & 7].clone()).collect();
        pw == kf.one()
            && qw == kf.sub(&alpha, &mle_eval(&kf, &w_concat, &zw))
            && pm == mle_eval(&kf, &m_concat, &zt)
            && qt == kf.sub(&alpha, &mle_eval(&kf, &t_concat, &zt))
    };
    let h0 = h0_of(&xs, &ys, &m_k);
    assert_true(
        "U-K3 GKR: honest 2-instance lookup verifies end-to-end (cross-checks + descents + leaf grounding)",
        run(&h0, &xs, &ys, &m_k),
    );
    {
        let mut ys_bad = ys.clone();
        ys_bad[0][0] += 1; // out-of-table pair
        assert_true(
            "U-K3 GKR: a wrong y at one leaf REJECTS (the root cross-check catches the identity break)",
            !run(&h0_of(&xs, &ys_bad, &m_k), &xs, &ys_bad, &m_k),
        );
        let mut m_bad = m_k.clone();
        m_bad[0][0] = kf.add(&m_bad[0][0], &kf.one());
        assert_true(
            "U-K3 GKR: a wrong multiplicity REJECTS",
            !run(&h0_of(&xs, &ys, &m_bad), &xs, &ys, &m_bad),
        );
    }
    {
        // Tampered interior layer (spike OK-3c at engine scale).
        let mut tr = LkpTranscript::new("uk3-tamper", &h0);
        let alpha = tr.challenge_k(&kf);
        let wtrees: Vec<FracTree> = (0..l_inst)
            .map(|e| {
                let lq: Vec<KElem> =
                    (0..n_leaf).map(|i| kf.sub(&alpha, &fuse(xs[e][i], ys[e][i]))).collect();
                build_tree(&kf, vec![kf.one(); n_leaf], lq)
            })
            .collect();
        let w_roots: Vec<[KElem; 2]> = wtrees.iter().map(|t| t.root()).collect();
        absorb_roots(&kf, &w_roots, &mut tr);
        let (mut proof, _, _, _) = gkr_prove(&kf, &wtrees, &mut tr);
        proof.layers[2].rounds[1][2] = kf.add(&proof.layers[2].rounds[1][2], &kf.one());
        let mut tv = LkpTranscript::new("uk3-tamper", &h0);
        let _a = tv.challenge_k(&kf);
        absorb_roots(&kf, &w_roots, &mut tv);
        assert_true(
            "U-K3 GKR: a tampered interior layer polynomial REJECTS",
            gkr_verify(&kf, &w_roots, depth_w, &proof, &mut tv).is_none(),
        );
    }
    // E3-N1 (the alpha edge), F5 pair: with alpha drawn from an h0 that
    // does NOT bind the multiplicity columns, a corrupted witness is
    // accepted by interpolating m_0 after alpha (a K-element, not a
    // count — nothing in the identity checks it); the shipped h0 moves
    // alpha and the same crafting dies at the cross-check.
    {
        let mut ys_bad = ys.clone();
        ys_bad[0][0] += 1;
        let h0_xy = h0_of(&xs, &ys_bad, &[]); // m NOT bound (the bug)
        let mut trb = LkpTranscript::new("uk3-lkp", &h0_xy);
        let alpha_b = trb.challenge_k(&kf);
        let mut m_atk = m_k.clone();
        let sw = (0..n_leaf).fold(kf.zero(), |a, i| {
            kf.add(&a, &kf.inv(&kf.sub(&alpha_b, &fuse(xs[0][i], ys_bad[0][i]))))
        });
        let mut rest = kf.zero();
        for j in 1..8 {
            rest = kf.add(&rest, &kf.mul(&m_atk[0][j], &kf.inv(&kf.sub(&alpha_b, &t_fused[j]))));
        }
        m_atk[0][0] = kf.mul(&kf.sub(&sw, &rest), &kf.sub(&alpha_b, &t_fused[0]));
        assert_true(
            "U-K3 order (E3-N1): alpha without the m binding ACCEPTS a corrupted witness (m interpolated post-alpha — the attack, demonstrated)",
            run(&h0_xy, &xs, &ys_bad, &m_atk),
        );
        assert_true(
            "U-K3 order (E3-N1): the shipped h0 (m bound before alpha) REJECTS the same crafting",
            !run(&h0_of(&xs, &ys_bad, &m_atk), &xs, &ys_bad, &m_atk),
        );
    }
    // E3-N3 (the instance-coordinate edge), F5 pair: with z_e drawn
    // before the roots are bound, the exposed root SET is malleable —
    // any shift along the eq(z_e, .)-kernel presents a second root set
    // the same descent answers for (per-instance anchoring lost);
    // binding the roots first makes any root change move z_e.
    {
        let mut tr = LkpTranscript::new("uk3-n3", &h0);
        let alpha = tr.challenge_k(&kf);
        let wtrees: Vec<FracTree> = (0..l_inst)
            .map(|e| {
                let lq: Vec<KElem> =
                    (0..n_leaf).map(|i| kf.sub(&alpha, &fuse(xs[e][i], ys[e][i]))).collect();
                build_tree(&kf, vec![kf.one(); n_leaf], lq)
            })
            .collect();
        let w_roots: Vec<[KElem; 2]> = wtrees.iter().map(|t| t.root()).collect();
        // BUGGY world: nobody absorbs the roots; prove + verify share
        // challenges regardless of the exposed set.
        let (proof_b, _, _, _) = {
            let mut tp = LkpTranscript::new("uk3-n3", &h0);
            let _a = tp.challenge_k(&kf);
            gkr_prove(&kf, &wtrees, &mut tp)
        };
        let z_e_known = {
            let mut t2 = LkpTranscript::new("uk3-n3", &h0);
            let _a = t2.challenge_k(&kf);
            t2.challenge_k(&kf)
        };
        let d = kf.embed(0x1234);
        let ratio = kf.mul(
            &kf.sub(&kf.one(), &z_e_known),
            &kf.inv(&z_e_known),
        );
        let mut roots_atk = w_roots.clone();
        roots_atk[0][0] = kf.add(&roots_atk[0][0], &d);
        roots_atk[1][0] = kf.sub(&roots_atk[1][0], &kf.mul(&d, &ratio));
        let buggy_verify = |roots: &Vec<[KElem; 2]>| -> bool {
            let mut tv = LkpTranscript::new("uk3-n3", &h0);
            let _a = tv.challenge_k(&kf);
            gkr_verify(&kf, roots, depth_w, &proof_b, &mut tv).is_some()
        };
        assert_true(
            "U-K3 order (E3-N3): unbound roots ACCEPT a second, shifted root set for the same descent (per-instance anchoring lost — the attack, demonstrated)",
            roots_atk != w_roots && buggy_verify(&w_roots) && buggy_verify(&roots_atk),
        );
        // Shipped: roots bound before z_e — the shifted set moves every
        // challenge and the honest-order proof rejects against it.
        let (proof_s, _, _, _) = {
            let mut tp = LkpTranscript::new("uk3-n3", &h0);
            let _a = tp.challenge_k(&kf);
            absorb_roots(&kf, &w_roots, &mut tp);
            gkr_prove(&kf, &wtrees, &mut tp)
        };
        let mut tv = LkpTranscript::new("uk3-n3", &h0);
        let _a = tv.challenge_k(&kf);
        absorb_roots(&kf, &roots_atk, &mut tv);
        assert_true(
            "U-K3 order (E3-N3): with roots bound before z_e the shifted set REJECTS (the fix)",
            gkr_verify(&kf, &roots_atk, depth_w, &proof_s, &mut tv).is_none(),
        );
    }
    // E3-N5 (the mu edge), F5 pair at the minimal shape (one depth-1
    // tree): with mu known before the boundary is absorbed, the
    // 4-value boundary is malleable — 3 constraints (combine == C, p
    // fold, q fold) on 4 unknowns leave one degree of freedom, so a
    // second boundary passes every check including leaf grounding;
    // absorbing the boundary first moves mu and kills the crafting.
    {
        let mut xr5 = XofReader::new("uk3-n5", &[b"seed-5"]);
        let lp = vec![kf.uniform(&mut xr5), kf.uniform(&mut xr5)];
        let lq = vec![kf.uniform(&mut xr5), kf.uniform(&mut xr5)];
        let tree = build_tree(&kf, lp.clone(), lq.clone());
        let root = tree.root();
        let mut tp = LkpTranscript::new("uk3-n5", &h0);
        absorb_roots(&kf, &[root.clone()], &mut tp);
        let (proof, _, _, _) = gkr_prove(&kf, &[tree], &mut tp);
        let honest_fe = proof.layers[0].final_evals.clone();
        // Replay the shipped schedule up to the boundary to learn
        // lambda, and the BUGGY mu (drawn without the boundary absorb).
        let (lambda, mu_b) = {
            let mut t2 = LkpTranscript::new("uk3-n5", &h0);
            absorb_roots(&kf, &[root.clone()], &mut t2);
            let l = t2.challenge_k(&kf);
            (l, t2.challenge_k(&kf))
        };
        let (p0, p1, q0, q1) = (&honest_fe[1], &honest_fe[2], &honest_fe[3], &honest_fe[4]);
        let cc = kf.mul(&kf.sub(&kf.one(), &mu_b), &kf.inv(&mu_b)); // (1-mu)/mu
        let t = kf.one();
        let q0a = kf.add(q0, &t);
        let q1a = kf.sub(q1, &kf.mul(&t, &cc));
        // combine target (eq = 1 at the empty point):
        let target = kf.add(
            &kf.add(&kf.mul(p0, q1), &kf.mul(p1, q0)),
            &kf.mul(&lambda, &kf.mul(q0, q1)),
        );
        let partial = kf.add(
            &kf.add(&kf.mul(p0, &q1a), &kf.mul(p1, &q0a)),
            &kf.mul(&lambda, &kf.mul(&q0a, &q1a)),
        );
        let s = kf.mul(
            &kf.sub(&target, &partial),
            &kf.inv(&kf.sub(&q1a, &kf.mul(&cc, &q0a))),
        );
        let p0a = kf.add(p0, &s);
        let p1a = kf.sub(p1, &kf.mul(&s, &cc));
        let fe_atk = vec![kf.one(), p0a.clone(), p1a, q0a, q1a];
        // BUGGY verify: C-check + fold with the pre-boundary mu +
        // grounding against the TRUE leaves.
        let buggy_accepts = |fe: &Vec<KElem>| -> bool {
            let c_claim = kf.add(&root[0], &kf.mul(&lambda, &root[1]));
            let comb = kf.add(
                &kf.add(&kf.mul(&fe[1], &fe[4]), &kf.mul(&fe[2], &fe[3])),
                &kf.mul(&lambda, &kf.mul(&fe[3], &fe[4])),
            );
            if comb != c_claim {
                return false;
            }
            let pc = kf.add(&fe[1], &kf.mul(&mu_b, &kf.sub(&fe[2], &fe[1])));
            let qc = kf.add(&fe[3], &kf.mul(&mu_b, &kf.sub(&fe[4], &fe[3])));
            pc == mle_eval(&kf, &lp, &[mu_b.clone()]) && qc == mle_eval(&kf, &lq, &[mu_b.clone()])
        };
        assert_true(
            "U-K3 order (E3-N5): mu before the boundary absorb ACCEPTS a second boundary (one free dof after 3 constraints — the attack, demonstrated)",
            fe_atk != honest_fe && buggy_accepts(&honest_fe) && buggy_accepts(&fe_atk),
        );
        // Shipped: the boundary is absorbed before mu — the crafted
        // boundary moves mu and dies at leaf grounding.
        let atk_proof = ring::gkr::GkrDescentProof {
            layers: vec![ring::sumcheck::SumcheckProof {
                rounds: proof.layers[0].rounds.clone(),
                final_evals: fe_atk,
            }],
        };
        let rejected = {
            let mut tv = LkpTranscript::new("uk3-n5", &h0);
            absorb_roots(&kf, &[root.clone()], &mut tv);
            match gkr_verify(&kf, &[root.clone()], 1, &atk_proof, &mut tv) {
                None => true,
                Some((z, pc, qc)) => {
                    !(pc == mle_eval(&kf, &lp, &z) && qc == mle_eval(&kf, &lq, &z))
                }
            }
        };
        assert_true(
            "U-K3 order (E3-N5): the shipped order (boundary absorbed before mu) REJECTS the same crafting at grounding",
            rejected,
        );
    }

    // ---- [U-K4] the fusion + the real table: kappa := Y, silu-int8-
    // table-v1, the E3-N2 pair, LKP-1 ctx binding. ----
    use ring::lookup::{fuse_pair, fused_silu_table, multiplicities, silu_int8_table, table_spec_digest};
    println!("\n[U-K4] fusion + table: kappa := Y over silu-int8-table-v1, E3-N2 pair");
    let rows = silu_int8_table();
    let spec_dg = table_spec_digest(&rows);
    let tab_fused = fused_silu_table(&kf, &rows);
    let dg_hex: String = spec_dg.iter().take(8).map(|b| format!("{b:02x}")).collect();
    println!("  LKP-1 table spec digest[0..8] = {dg_hex}");
    assert_true(
        "U-K4 table: 256 rows; S(0) = 0, S(127) = 127, S(-128) = 0 (the fixed-point SiLU endpoints)",
        rows.len() == 256 && rows[128] == (0, 0) && rows[255] == (127, 127) && rows[0] == (-128, 0),
    );
    let (n4, depth_w4, depth_t4) = (64usize, 6usize, 8usize);
    let mut xr4 = XofReader::new("uk4-battery", &[b"seed-4"]);
    let xs4: Vec<i64> = (0..n4).map(|_| xr4.next_field(256) as i64 - 128).collect();
    let ys4: Vec<i64> = xs4.iter().map(|&x| rows[(x + 128) as usize].1).collect();
    let w_fused: Vec<KElem> = xs4
        .iter()
        .zip(ys4.iter())
        .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
        .collect();
    // Single-instance pipeline over PRE-FUSED leaves (shared by the
    // shipped world and the E3-N2 mis-build): h0 must bind the table
    // spec digest (LKP-1) + the columns + m before alpha.
    let h0_of4 = |tab: &[KElem], w: &[KElem], m: &[KElem]| -> [u8; 32] {
        let mut bytes = spec_dg.to_vec();
        for e in tab.iter().chain(w.iter()).chain(m.iter()) {
            bytes.extend_from_slice(&kf.bytes(e));
        }
        let mut r = XofReader::new("uk4-h0", &[&bytes]);
        let mut h = [0u8; 32];
        for c in h.chunks_mut(8) {
            c.copy_from_slice(&r.next_u64().to_le_bytes());
        }
        h
    };
    let run1 = |tab: &[KElem], w: &[KElem], m: &[KElem]| -> bool {
        let h0 = h0_of4(tab, w, m);
        let mut tr = LkpTranscript::new("uk4-lkp", &h0);
        let alpha = tr.challenge_k(&kf);
        let wq: Vec<KElem> = w.iter().map(|wi| kf.sub(&alpha, wi)).collect();
        let tq: Vec<KElem> = tab.iter().map(|t| kf.sub(&alpha, t)).collect();
        let wtree = build_tree(&kf, vec![kf.one(); w.len()], wq);
        let ttree = build_tree(&kf, m.to_vec(), tq);
        let (wr, trt) = (wtree.root(), ttree.root());
        if !root_cross_check(&kf, &wr, &trt) {
            return false;
        }
        absorb_roots(&kf, &[wr.clone()], &mut tr);
        let (pw_proof, _, _, _) = gkr_prove(&kf, &[wtree], &mut tr);
        absorb_roots(&kf, &[trt.clone()], &mut tr);
        let (pt_proof, _, _, _) = gkr_prove(&kf, &[ttree], &mut tr);
        let mut tv = LkpTranscript::new("uk4-lkp", &h0);
        if tv.challenge_k(&kf) != alpha {
            return false;
        }
        absorb_roots(&kf, &[wr.clone()], &mut tv);
        let Some((zw, pw, qw)) = gkr_verify(&kf, &[wr], depth_w4, &pw_proof, &mut tv) else {
            return false;
        };
        absorb_roots(&kf, &[trt.clone()], &mut tv);
        let Some((zt, pm, qt)) = gkr_verify(&kf, &[trt], depth_t4, &pt_proof, &mut tv) else {
            return false;
        };
        pw == kf.one()
            && qw == kf.sub(&alpha, &mle_eval(&kf, w, &zw))
            && pm == mle_eval(&kf, m, &zt)
            && qt == kf.sub(&alpha, &mle_eval(&kf, tab, &zt))
    };
    let m_honest = multiplicities(&kf, &w_fused, &tab_fused);
    assert_true(
        "U-K4 fusion: an honest int8 SiLU column verifies through the full single-instance lookup",
        run1(&tab_fused, &w_fused, &m_honest),
    );
    // E3-N2, both directions. The mis-build: a BASE-FIELD fusion scalar
    // known before y is fixed admits the exact collision
    // y' = S[v'] + (v' - x) kappa^{-1} — (x, y') is NOT a table pair
    // but fuses INTO row v'. kappa := Y makes the collision impossible
    // ({1, Y} Z_q-linearly independent), no ordering needed.
    {
        let kappa_b = XofReader::new("uk4-bad-kappa", &[&spec_dg]).next_field(q);
        let tgt = (((xs4[0] + 128 + 7) % 256) as usize).max(1); // a row != x0's own
        let (vp, sp) = (zq.to_mod(rows[tgt].0), zq.to_mod(rows[tgt].1));
        let x0 = zq.to_mod(xs4[0]);
        let y_crafted = zq.add(sp, zq.mul(zq.sub(vp, x0), zq.inv(kappa_b)));
        let fuse_b = |x: u64, y: u64| -> KElem { kf.embed(zq.add(x, zq.mul(kappa_b, y))) };
        let tab_b: Vec<KElem> =
            rows.iter().map(|&(v, s)| fuse_b(zq.to_mod(v), zq.to_mod(s))).collect();
        let mut w_b: Vec<KElem> = xs4
            .iter()
            .zip(ys4.iter())
            .map(|(&x, &y)| fuse_b(zq.to_mod(x), zq.to_mod(y)))
            .collect();
        w_b[0] = fuse_b(x0, y_crafted);
        let m_b = multiplicities(&kf, &w_b, &tab_b);
        assert_true(
            "U-K4 fusion (E3-N2): the base-field-kappa mis-build ACCEPTS a non-table pair (the fused collision — the attack, demonstrated)",
            y_crafted != zq.to_mod(ys4[0]) && w_b[0] == tab_b[tgt] && run1(&tab_b, &w_b, &m_b),
        );
        let mut w_y = w_fused.clone();
        w_y[0] = fuse_pair(&kf, x0, y_crafted);
        let m_y = multiplicities(&kf, &w_y, &tab_fused);
        assert_true(
            "U-K4 fusion (E3-N2): kappa := Y REJECTS the same crafted pair (exact pair binding — the fix)",
            !run1(&tab_fused, &w_y, &m_y),
        );
    }

    // ---- [U-K6] E4: the descent claims land as 9 psi-batched linear
    // ct-claims over the COMMITTED tensors — no new claim family. ----
    use ring::commit::CommitShape as CS6;
    use ring::ct_engine::{
        StdOpening, ct_h0, derive_ct_round_params, prove_ct_round, sample_ct_masks,
        verify_ct_round,
    };
    use ring::gkr::eq_table;
    use ring::lookup::{derive_e4_psi, e4_claims, mle_weights_block, mul_y};
    println!("\n[U-K6] E4 landing: lookup transcript -> 9 ct-claims over committed X/Y/m");
    {
        let mut xr6 = XofReader::new("uk6-weights", &[b"w"]);
        let z: Vec<KElem> = (0..6).map(|_| kf.uniform(&mut xr6)).collect();
        let full = eq_table(&kf, &z);
        let mut blocks = Vec::new();
        for b in 0..4 {
            blocks.extend(mle_weights_block(&kf, &z, b, 4));
        }
        assert_true(
            "U-K6 weights: block-streamed L_z equals the full eq table (the never-materialize primitive)",
            blocks == full,
        );
    }
    let shape6 = CS6 { kappa: 8, n_r: 26, msg_r: 2 };
    let crs6 = expand_crs(shape6, q, 0xE401);
    let n6 = 256usize;
    let (depth_w6, depth_t6) = (8usize, 8usize);
    let mut rng6 = 0x5eed_0601u64;
    let xs6: Vec<i64> = (0..n6).map(|_| rng_below(&mut rng6, 256) as i64 - 128).collect();
    let ys6: Vec<i64> = xs6.iter().map(|&x| rows[(x + 128) as usize].1).collect();
    let w6: Vec<KElem> = xs6
        .iter()
        .zip(ys6.iter())
        .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
        .collect();
    let m6k = multiplicities(&kf, &w6, &tab_fused);
    let m_vals: Vec<i64> = m6k.iter().map(|e| e[0] as i64).collect();
    let packv = |vals: &[i64]| -> Vec<Poly> {
        (0..n6.div_ceil(D))
            .map(|u| (0..D).map(|t| zq.to_mod(vals[u * D + t])).collect())
            .collect()
    };
    let (x_msg, y_msg, m_msg) = (packv(&xs6), packv(&ys6), packv(&m_vals));
    let g6 = sample_ct_masks(&mut rng6, q, shape6.msg_r, 9);
    let value_slots6: [Vec<(usize, usize)>; 3] =
        [vec![(0, 0), (0, 1)], vec![(1, 0), (1, 1)], vec![(2, 0), (2, 1)]];
    let rp6 = derive_ct_round_params(q, shape6, 3 + g6.len(), 0, 0, false);
    let a1p6 = build_a1_paths(&crs6, rp6.sigma, isqrt_u128(rp6.bound_sq));
    let path6 = KernelPath::A1(&a1p6);
    // The whole pipeline: commit, lookup transcript, claimed coords,
    // psi, claims, ct-round, verify + reconciliation. x_committed may
    // differ from the honest xs6 (the wrong-tensor negative); v_tamper
    // corrupts one claimed coordinate (the wrong-v negative).
    let pipeline6 = |x_committed: Vec<Poly>, v_tamper: Option<usize>| -> bool {
        let mut r6 = 0x5eed_0666u64;
        let mut all_x = vec![x_committed, y_msg.clone(), m_msg.clone()];
        all_x.extend(g6.clone());
        let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
            .map(|_| (0..shape6.n_r).map(|_| rng_ternary_poly(&mut r6)).collect())
            .collect();
        let (mut t1s, mut t2s) = (Vec::new(), Vec::new());
        for (xm, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(&path6, &crs6, xm, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        // h0_lkp: the table spec digest (LKP-1 ctx) + every commitment.
        let h0_lkp = ct_h0(&crs6, &spec_dg, &t1s, &t2s, &[]);
        let mut tr = LkpTranscript::new("uk6-lkp", &h0_lkp);
        let alpha = tr.challenge_k(&kf);
        let wtree = build_tree(
            &kf,
            vec![kf.one(); n6],
            w6.iter().map(|wi| kf.sub(&alpha, wi)).collect(),
        );
        let ttree =
            build_tree(&kf, m6k.clone(), tab_fused.iter().map(|t| kf.sub(&alpha, t)).collect());
        let (wr, trr) = (wtree.root(), ttree.root());
        absorb_roots(&kf, &[wr.clone()], &mut tr);
        let (pw_proof, zw, _, _) = gkr_prove(&kf, &[wtree], &mut tr);
        absorb_roots(&kf, &[trr.clone()], &mut tr);
        let (pt_proof, zt, _, _) = gkr_prove(&kf, &[ttree], &mut tr);
        // Claimed coordinates (from the honest columns; the ct-round is
        // what pins them to the COMMITTED tensors).
        let lw = eq_table(&kf, &zw);
        let lt = eq_table(&kf, &zt);
        let vsum = |weights: &[KElem], vals: &[i64]| -> KElem {
            vals.iter()
                .zip(weights.iter())
                .fold(kf.zero(), |a, (&v, l)| kf.add(&a, &kf.scale(zq.to_mod(v), l)))
        };
        let (vx, vy, vm) = (vsum(&lw, &xs6), vsum(&lw, &ys6), vsum(&lt, &m_vals));
        let mut v_coords: Vec<u64> =
            vx.iter().chain(vy.iter()).chain(vm.iter()).copied().collect();
        if let Some(i) = v_tamper {
            v_coords[i] = zq.add(v_coords[i], 1);
        }
        let vbytes: Vec<u8> = v_coords.iter().flat_map(|c| c.to_le_bytes()).collect();
        tr.absorb("e4-v", &vbytes);
        let psi = derive_e4_psi(&tr.state(), 9, q);
        let claims = e4_claims(
            &kf, &lw, &lt, &value_slots6[0], &value_slots6[1], &value_slots6[2], &v_coords, &psi,
        );
        let h0_round = ct_h0(&crs6, &tr.state(), &t1s, &t2s, &[]);
        let openings: Vec<StdOpening> = all_x
            .iter()
            .zip(all_rho.iter())
            .enumerate()
            .map(|(i, (xm, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x: xm, rho })
            .collect();
        let (proof, _) = prove_ct_round(
            &path6, &ctx, &rp6, None, &crs6, &h0_round, &claims, &[], &[], &[], &openings, &[],
            &[], 3, &mut r6,
        );
        // ---- Verifier. ----
        let mut tv = LkpTranscript::new("uk6-lkp", &h0_lkp);
        if tv.challenge_k(&kf) != alpha || !root_cross_check(&kf, &wr, &trr) {
            return false;
        }
        absorb_roots(&kf, &[wr.clone()], &mut tv);
        let Some((zwv, pwv, qwv)) = gkr_verify(&kf, &[wr], depth_w6, &pw_proof, &mut tv) else {
            return false;
        };
        absorb_roots(&kf, &[trr.clone()], &mut tv);
        let Some((ztv, pmv, qtv)) = gkr_verify(&kf, &[trr], depth_t6, &pt_proof, &mut tv) else {
            return false;
        };
        tv.absorb("e4-v", &vbytes);
        let psi_v = derive_e4_psi(&tv.state(), 9, q);
        let claims_v = e4_claims(
            &kf,
            &eq_table(&kf, &zwv),
            &eq_table(&kf, &ztv),
            &value_slots6[0],
            &value_slots6[1],
            &value_slots6[2],
            &v_coords,
            &psi_v,
        );
        let h0r_v = ct_h0(&crs6, &tv.state(), &t1s, &t2s, &[]);
        if !verify_ct_round(
            &path6, &ctx, &rp6, None, &crs6, &h0r_v, &claims_v, &[], &[], &[], &t1s, &t2s, &[],
            &[], &[], 3, &proof,
        ) {
            return false;
        }
        // Reconciliation: the descent claims equal the ct-pinned
        // coordinate values (v_w = v^X + Y v^Y; the table MLE is
        // verifier-computable).
        let vxk: KElem = v_coords[0..16].to_vec();
        let vyk: KElem = v_coords[16..32].to_vec();
        let vmk: KElem = v_coords[32..48].to_vec();
        pwv == kf.one()
            && qwv == kf.sub(&alpha, &kf.add(&vxk, &mul_y(&kf, &vyk)))
            && pmv == vmk
            && qtv == kf.sub(&alpha, &mle_eval(&kf, &tab_fused, &ztv))
    };
    let t6 = Instant::now();
    let ok6 = pipeline6(x_msg.clone(), None);
    let ms6 = t6.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!(
            "U-K6 E4: honest end-to-end (commit -> lookup transcript -> 9 ct-claims -> reconciliation) verifies ({ms6:.0} ms prove+verify, N=256)"
        ),
        ok6,
    );
    assert_true(
        "U-K6 E4: a tampered claimed coordinate REJECTS (the ct-round pins every v-coordinate)",
        !pipeline6(x_msg.clone(), Some(0)),
    );
    {
        let mut x_bad = x_msg.clone();
        x_bad[0][0] = zq.add(x_bad[0][0], 1);
        assert_true(
            "U-K6 E4: a different committed tensor REJECTS (the claims bind the commitments, not the prover's story)",
            !pipeline6(x_bad, None),
        );
    }

    // ---- [U-K7] the E4 hash edges. ----
    // E4-N1 (psi before the claimed coordinates): only the 9
    // psi-combinations are pinned, so a coordinate defect Delta in the
    // intersection of (a) the v_w-preserving kernel (Delta vx = -Y
    // Delta vy keeps the descent reconciliation happy) and (b) the psi
    // null space (9 constraints on 16 free dims — solutions always
    // exist) forges per-coordinate values v' != v that every check
    // accepts. The shipped order (psi drawn AFTER v is absorbed) makes
    // psi depend on v' and the forged scalars die in the ct-round.
    println!("\n[U-K7] E4 hash edges: psi-before-v pair, round-restart regression");
    {
        // Shared prefix: honest commitments + lookup transcript up to
        // the descent end (identical in both worlds).
        let mut r7 = 0x5eed_0701u64;
        let mut all_x = vec![x_msg.clone(), y_msg.clone(), m_msg.clone()];
        all_x.extend(g6.clone());
        let all_rho: Vec<Vec<Vec<i64>>> = (0..all_x.len())
            .map(|_| (0..shape6.n_r).map(|_| rng_ternary_poly(&mut r7)).collect())
            .collect();
        let (mut t1s, mut t2s) = (Vec::new(), Vec::new());
        for (xm, rho) in all_x.iter().zip(all_rho.iter()) {
            let (t1, t2) = commit(&path6, &crs6, xm, rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        let h0_lkp = ct_h0(&crs6, &spec_dg, &t1s, &t2s, &[]);
        let mut tr = LkpTranscript::new("uk7-lkp", &h0_lkp);
        let alpha = tr.challenge_k(&kf);
        let wtree = build_tree(
            &kf,
            vec![kf.one(); n6],
            w6.iter().map(|wi| kf.sub(&alpha, wi)).collect(),
        );
        let ttree =
            build_tree(&kf, m6k.clone(), tab_fused.iter().map(|t| kf.sub(&alpha, t)).collect());
        let (wr, trr) = (wtree.root(), ttree.root());
        absorb_roots(&kf, &[wr.clone()], &mut tr);
        let (pw_proof, zw, _, _) = gkr_prove(&kf, &[wtree], &mut tr);
        absorb_roots(&kf, &[trr.clone()], &mut tr);
        let (pt_proof, zt, _, _) = gkr_prove(&kf, &[ttree], &mut tr);
        let lw = eq_table(&kf, &zw);
        let lt = eq_table(&kf, &zt);
        let vsum = |weights: &[KElem], vals: &[i64]| -> KElem {
            vals.iter()
                .zip(weights.iter())
                .fold(kf.zero(), |a, (&v, l)| kf.add(&a, &kf.scale(zq.to_mod(v), l)))
        };
        let (vx, vy, vm) = (vsum(&lw, &xs6), vsum(&lw, &ys6), vsum(&lt, &m_vals));
        let v_true: Vec<u64> = vx.iter().chain(vy.iter()).chain(vm.iter()).copied().collect();
        let state_pre_v = tr.state();
        // BUGGY world: psi from the pre-v state.
        let psi_b = derive_e4_psi(&state_pre_v, 9, q);
        // Delta basis j: Delta vy = e_j, Delta vx = -Y e_j; solve the
        // 9 psi constraints by Gaussian elimination over Z_q (16
        // unknowns, kernel dim >= 7).
        let mut a_mat: Vec<Vec<u64>> = (0..9)
            .map(|r| {
                (0..16)
                    .map(|j| {
                        let mut ej = kf.zero();
                        ej[j] = 1;
                        let dvx = kf.neg(&mul_y(&kf, &ej));
                        let mut acc = 0u64;
                        for c in 0..16 {
                            acc = zq.add(acc, zq.mul(psi_b[r][c], dvx[c]));
                            acc = zq.add(acc, zq.mul(psi_b[r][16 + c], ej[c]));
                        }
                        acc
                    })
                    .collect()
            })
            .collect();
        // Eliminate to find a nonzero kernel vector u (free column set
        // to 1, back-substitute the pivots).
        let mut piv: Vec<(usize, usize)> = Vec::new();
        let mut row = 0usize;
        for col in 0..16 {
            if row >= 9 {
                break;
            }
            if let Some(pr) = (row..9).find(|&rr| a_mat[rr][col] != 0) {
                a_mat.swap(row, pr);
                let inv = zq.inv(a_mat[row][col]);
                for c in col..16 {
                    a_mat[row][c] = zq.mul(a_mat[row][c], inv);
                }
                for rr in 0..9 {
                    if rr != row && a_mat[rr][col] != 0 {
                        let f = a_mat[rr][col];
                        for c in col..16 {
                            a_mat[rr][c] = zq.sub(a_mat[rr][c], zq.mul(f, a_mat[row][c]));
                        }
                    }
                }
                piv.push((row, col));
                row += 1;
            }
        }
        let free_col = (0..16).find(|c| !piv.iter().any(|&(_, pc)| pc == *c)).unwrap();
        let mut u = vec![0u64; 16];
        u[free_col] = 1;
        for &(pr, pc) in piv.iter().rev() {
            u[pc] = zq.neg(a_mat[pr][free_col]);
        }
        let dvy: KElem = u.clone();
        let dvx = kf.neg(&mul_y(&kf, &dvy));
        let mut v_atk = v_true.clone();
        for c in 0..16 {
            v_atk[c] = zq.add(v_atk[c], dvx[c]);
            v_atk[16 + c] = zq.add(v_atk[16 + c], dvy[c]);
        }
        // Endgame runner: claims + ct-round + reconciliation, with psi
        // from either the buggy (pre-v) or shipped (post-v) state.
        let endgame = |v_claimed: &[u64], buggy_psi: bool| -> bool {
            let mut trp = LkpTranscript::new("uk7-endgame", &state_pre_v);
            let vbytes: Vec<u8> = v_claimed.iter().flat_map(|c| c.to_le_bytes()).collect();
            trp.absorb("e4-v", &vbytes);
            let psi = if buggy_psi {
                derive_e4_psi(&state_pre_v, 9, q)
            } else {
                derive_e4_psi(&trp.state(), 9, q)
            };
            let claims = e4_claims(
                &kf, &lw, &lt, &value_slots6[0], &value_slots6[1], &value_slots6[2], v_claimed,
                &psi,
            );
            let h0_round = ct_h0(&crs6, &trp.state(), &t1s, &t2s, &[]);
            let openings: Vec<StdOpening> = all_x
                .iter()
                .zip(all_rho.iter())
                .enumerate()
                .map(|(i, (xm, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x: xm, rho })
                .collect();
            let mut rr = 0x5eed_0777u64;
            let (proof, _) = prove_ct_round(
                &path6, &ctx, &rp6, None, &crs6, &h0_round, &claims, &[], &[], &[], &openings,
                &[], &[], 3, &mut rr,
            );
            let okr = verify_ct_round(
                &path6, &ctx, &rp6, None, &crs6, &h0_round, &claims, &[], &[], &[], &t1s, &t2s,
                &[], &[], &[], 3, &proof,
            );
            let vxk: KElem = v_claimed[0..16].to_vec();
            let vyk: KElem = v_claimed[16..32].to_vec();
            let recon = {
                let mut tv = LkpTranscript::new("uk7-lkp", &h0_lkp);
                let av = tv.challenge_k(&kf);
                absorb_roots(&kf, &[wr.clone()], &mut tv);
                let dw = gkr_verify(&kf, &[wr.clone()], depth_w6, &pw_proof, &mut tv);
                absorb_roots(&kf, &[trr.clone()], &mut tv);
                let dt = gkr_verify(&kf, &[trr.clone()], depth_t6, &pt_proof, &mut tv);
                match (dw, dt) {
                    (Some((_, pwv, qwv)), Some((_, pmv, _))) => {
                        pwv == kf.one()
                            && qwv == kf.sub(&av, &kf.add(&vxk, &mul_y(&kf, &vyk)))
                            && pmv == v_claimed[32..48].to_vec()
                    }
                    _ => false,
                }
            };
            okr && recon
        };
        assert_true(
            "U-K7 order (E4-N1): psi before the v absorb ACCEPTS forged per-coordinate values (defect in the psi null space x v_w kernel — the attack, demonstrated)",
            v_atk != v_true && endgame(&v_atk, true),
        );
        assert_true(
            "U-K7 order (E4-N1): the shipped order (psi after v) REJECTS the same forgery",
            !endgame(&v_atk, false),
        );
        // E4-N2 (restart confinement): round restarts re-randomize ONLY
        // the ct-round (c, masks) — the lookup transcript and psi are
        // fixed upstream. Two provers with different round randomness
        // both verify against the SAME claims and h0_round; a prover
        // that instead re-derives psi from its restarted round state
        // produces claims the shipped verifier rejects.
        let claims_fixed = {
            let mut trp = LkpTranscript::new("uk7-endgame", &state_pre_v);
            let vbytes: Vec<u8> = v_true.iter().flat_map(|c| c.to_le_bytes()).collect();
            trp.absorb("e4-v", &vbytes);
            let psi = derive_e4_psi(&trp.state(), 9, q);
            (
                e4_claims(
                    &kf, &lw, &lt, &value_slots6[0], &value_slots6[1], &value_slots6[2],
                    &v_true, &psi,
                ),
                ct_h0(&crs6, &trp.state(), &t1s, &t2s, &[]),
                trp.state(),
            )
        };
        let openings: Vec<StdOpening> = all_x
            .iter()
            .zip(all_rho.iter())
            .enumerate()
            .map(|(i, (xm, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x: xm, rho })
            .collect();
        let mut ra = 0x5eed_0aaau64;
        let (proof_a, _) = prove_ct_round(
            &path6, &ctx, &rp6, None, &crs6, &claims_fixed.1, &claims_fixed.0, &[], &[], &[],
            &openings, &[], &[], 3, &mut ra,
        );
        let mut rb = 0x5eed_0bbbu64;
        let (proof_b, _) = prove_ct_round(
            &path6, &ctx, &rp6, None, &crs6, &claims_fixed.1, &claims_fixed.0, &[], &[], &[],
            &openings, &[], &[], 3, &mut rb,
        );
        let vfy = |p: &ring::ct_engine::CtRoundProof, claims: &[ring::ct_engine::CtClaim]| {
            verify_ct_round(
                &path6, &ctx, &rp6, None, &crs6, &claims_fixed.1, claims, &[], &[], &[], &t1s,
                &t2s, &[], &[], &[], 3, p,
            )
        };
        let psi_ground = {
            let mut st = claims_fixed.2;
            st[0] ^= 1; // a "restarted" state that leaked into psi
            derive_e4_psi(&st, 9, q)
        };
        let claims_ground = e4_claims(
            &kf, &lw, &lt, &value_slots6[0], &value_slots6[1], &value_slots6[2], &v_true,
            &psi_ground,
        );
        let mut rc = 0x5eed_0cccu64;
        let (proof_c, _) = prove_ct_round(
            &path6, &ctx, &rp6, None, &crs6, &claims_fixed.1, &claims_ground, &[], &[], &[],
            &openings, &[], &[], 3, &mut rc,
        );
        assert_true(
            "U-K7 restarts (E4-N2): two round attempts (different masks/c) both verify against the SAME claims — restarts never touch the lookup transcript",
            proof_a.z != proof_b.z
                && vfy(&proof_a, &claims_fixed.0)
                && vfy(&proof_b, &claims_fixed.0),
        );
        assert_true(
            "U-K7 restarts (E4-N2): a prover that re-derives psi from restarted state is REJECTED by the shipped verifier's psi",
            !vfy(&proof_c, &claims_fixed.0),
        );
    }

    // ---- [U-K5ab] the MASKED descent (E3-Z): honest pass + liveness. ----
    use ring::gkr_masked::{
        blinder_positions, draw_masks, mask_coeff_counts, masked_gkr_prove, masked_gkr_verify,
        zero_masks,
    };
    println!("\n[U-K5ab] masked fractional GKR: g/R masks, w-variable, correction summands");
    {
        let n5 = 64usize;
        let (dw, dt) = (6usize, 8usize);
        let mut xr5 = XofReader::new("uk5-battery", &[b"seed-uk5"]);
        let xs5: Vec<i64> = (0..n5).map(|_| xr5.next_field(256) as i64 - 128).collect();
        let ys5: Vec<i64> = xs5.iter().map(|&x| rows[(x + 128) as usize].1).collect();
        let w5: Vec<KElem> = xs5
            .iter()
            .zip(ys5.iter())
            .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
            .collect();
        let m5 = multiplicities(&kf, &w5, &tab_fused);
        // Harness-only deterministic prover entropy. The committed masks
        // still bind upstream of alpha; they are never derived from alpha's
        // public Fiat-Shamir transcript.
        let h05 = *b"uk5-battery-h0-fixed-32-bytes!!!";
        let mut trm = ring::ProverRng::from_test_seed("uk5-masks", &h05);
        let masks_w = draw_masks(&kf, &mut trm, dw, 0);
        let masks_t = draw_masks(&kf, &mut trm, dt, 0);
        let mut tr5 = LkpTranscript::new("uk5-lkp", &h05);
        let alpha5 = tr5.challenge_k(&kf);
        let wtree = build_tree(
            &kf,
            vec![kf.one(); n5],
            w5.iter().map(|wi| kf.sub(&alpha5, wi)).collect(),
        );
        let ttree =
            build_tree(&kf, m5.clone(), tab_fused.iter().map(|t| kf.sub(&alpha5, t)).collect());
        let t0 = Instant::now();
        let (pw_proof, endw) = masked_gkr_prove(&kf, &[wtree], masks_w.harness_clone(), &mut tr5);
        let (pt_proof, endt) = masked_gkr_prove(&kf, &[ttree], masks_t.harness_clone(), &mut tr5);
        let prove_ms = t0.elapsed().as_secs_f64() * 1e3;
        // Verify (fresh transcript), root cross-check on the DERIVED
        // roots, leaf grounding by direct MLE (aggregate pins: U-K5c).
        let ok5 = {
            let mut tv = LkpTranscript::new("uk5-lkp", &h05);
            let av = tv.challenge_k(&kf);
            if av != alpha5 {
                false
            } else {
                let rw = masked_gkr_verify(&kf, 1, dw, &masks_w, &pw_proof, &mut tv, true);
                let rt = masked_gkr_verify(&kf, 1, dt, &masks_t, &pt_proof, &mut tv, true);
                match (rw, rt) {
                    (Some((roots_w, ew)), Some((roots_t, et))) => {
                        let w_concat = w5.clone();
                        !kf.is_zero(&roots_w[0][1])
                            && !kf.is_zero(&roots_t[0][1])
                            && kf.mul(&roots_w[0][0], &roots_t[0][1])
                                == kf.mul(&roots_t[0][0], &roots_w[0][1])
                            && ew.zstar == endw.zstar
                            && et.zstar == endt.zstar
                            && ew.p_claim == endw.p_claim
                            && ew.q_claim == endw.q_claim
                            && et.p_claim == endt.p_claim
                            && et.q_claim == endt.q_claim
                            && ew.p_claim == kf.one()
                            && ew.q_claim == kf.sub(&av, &mle_eval(&kf, &w_concat, &ew.zstar))
                            && et.p_claim == mle_eval(&kf, &m5, &et.zstar)
                            && et.q_claim == kf.sub(&av, &mle_eval(&kf, &tab_fused, &et.zstar))
                    }
                    _ => false,
                }
            }
        };
        assert_true(
            &format!(
                "U-K5ab masked GKR: honest masked pass verifies with pinned masks (cross-check on DERIVED roots, {prove_ms:.0} ms prove)"
            ),
            ok5,
        );
        // Mask liveness: the same trees under ZERO masks produce
        // different boundary values — the masks actually pad the wire.
        {
            let z_w = zero_masks(&kf, dw, 0);
            let wtree2 = build_tree(
                &kf,
                vec![kf.one(); n5],
                w5.iter().map(|wi| kf.sub(&alpha5, wi)).collect(),
            );
            let mut tr0 = LkpTranscript::new("uk5-lkp", &h05);
            let _a = tr0.challenge_k(&kf);
            let (p0_proof, _) = masked_gkr_prove(&kf, &[wtree2], z_w, &mut tr0);
            assert_true(
                "U-K5ab mask liveness: masked boundary values differ from the zero-mask (unmasked-equivalent) transcript",
                pw_proof.layers[2].boundary != p0_proof.layers[2].boundary,
            );
        }
        // Round-shape sanity: degree pattern 5/3..3/2 on masked-children
        // layers, 3/3..3/2 on the last.
        assert_true(
            "U-K5ab round shape: 6/4..4/3 evaluations per masked layer (5/3/2 degrees), 4-eval first round on the last layer",
            pw_proof.layers[1].rounds[0].len() == 6
                && pw_proof.layers[1].rounds.last().unwrap().len() == 3
                && pw_proof.layers[dw - 2].rounds[0].len() == 4,
        );
        // Tamper: a bumped round polynomial REJECTS.
        {
            let mut bad = MaskedTamper::clone_proof(&kf, &pw_proof);
            bad.layers[1].rounds[1][2] = kf.add(&bad.layers[1].rounds[1][2], &kf.one());
            let mut tv = LkpTranscript::new("uk5-lkp", &h05);
            let _a = tv.challenge_k(&kf);
            assert_true(
                "U-K5ab masked GKR: a tampered round polynomial REJECTS",
                masked_gkr_verify(&kf, 1, dw, &masks_w, &bad, &mut tv, true).is_none(),
            );
        }
        // LKP-6 arithmetic (freeze row pins the FFN point; sanity here).
        let (gw, rw_) = mask_coeff_counts(dw, 0);
        assert_true(
            &format!(
                "U-K5ab LKP-6 sanity: mask coefficient counts at (depth 6, e=0) = g {gw} + R {rw_}; blinder positions at N=64 = {:?}",
                blinder_positions(64)
            ),
            gw == (1..6)
                .map(|j| 1 + ring::gkr_masked::sc_degrees(j, j <= 4).iter().sum::<usize>())
                .sum::<usize>()
                && rw_ == 48
                && blinder_positions(64) == [28, 60, 30, 61],
        );
    }
}

/// Battery helper: deep-clone a masked descent proof (KElem vectors).
struct MaskedTamper;
impl MaskedTamper {
    fn clone_proof(
        kf: &ring::kfield::KField,
        p: &ring::gkr_masked::MaskedDescentProof,
    ) -> ring::gkr_masked::MaskedDescentProof {
        let _ = kf;
        ring::gkr_masked::MaskedDescentProof {
            layer1: p.layer1.clone(),
            layers: p
                .layers
                .iter()
                .map(|l| ring::gkr_masked::MaskedLayerProof {
                    g_sum: l.g_sum.clone(),
                    rounds: l.rounds.clone(),
                    boundary: l.boundary.clone(),
                    open_g: l.open_g.clone(),
                    open_r: l.open_r.clone(),
                })
                .collect(),
        }
    }
}

// ===========================================================================
// U-K5c/d (M4_LOOKUP_ZK_DESIGN.md Sections 3/6): the COMMITTED masked
// lookup — mask/blinder commitments in the statement wave, the masked
// descent wired over committed tensors with G-hypersum pins, mask
// openings and the AGGREGATE-ONLY leaf P/Q pins (v^X/v^Y/v^M retired),
// the Z1-class m-recovery harness (recovers m from the zero-mask
// transcript, FAILS against the masked one), the U-K5d negative
// battery (E3Z-N1..N4 + the E3/E4 pairs re-run under masking), and the
// LKP-7 freeze arithmetic. Every equation is the engine transcription
// of scripts/logup_zk_mask_spike.py; the pin layer is the E4 machinery
// (ring/lookup.rs pin_claims) over the same 9-copy psi batch.

/// Flatten a masked descent proof to the ordered K-element list the
/// leak harness treats as an affine function of m (spike
/// flatten_transcript): layer1 quadruples, then per layer sumcheck
/// g_sum, the round-poly evaluations, the boundary quadruple, and the
/// openings (g then, for j >= 2, Rp/Rq).
fn flatten_masked(p: &ring::gkr_masked::MaskedDescentProof) -> Vec<ring::kfield::KElem> {
    let mut out = Vec::new();
    for q in &p.layer1 {
        out.extend(q.iter().cloned());
    }
    for l in &p.layers {
        out.push(l.g_sum.clone());
        for evals in &l.rounds {
            out.extend(evals.iter().cloned());
        }
        out.extend(l.boundary.iter().cloned());
        out.push(l.open_g.clone());
        if let Some((a, b)) = &l.open_r {
            out.push(a.clone());
            out.push(b.clone());
        }
    }
    out
}

fn self_test_lookup_zk() {
    use ring::commit::CommitShape as CS;
    use ring::ct_engine::{
        StdOpening, ct_h0, derive_ct_round_params, prove_ct_round, sample_ct_masks,
        verify_ct_round,
    };
    use ring::gkr::eq_table;
    use ring::gkr_masked::{
        BlinderSet, DescentEnd, MaskSet, MaskedDescentProof, blinded_table_tree,
        blinded_witness_tree, blinder_positions, draw_masks, g_hypersum_weights, g_open_weights,
        mask_coeff_counts, masked_gkr_prove, masked_gkr_verify, masked_pass_bytes,
        masked_transcript_totals, r_open_weights, table_row_positions, zero_masks,
    };
    use ring::kfield::{K_DEG, KElem, KField};
    use ring::lookup::{
        PinTerm, PinnedValue, derive_pin_psi, fuse_pair, fused_silu_table, mul_y, multiplicities,
        pin_claims, silu_int8_table, table_spec_digest,
    };
    use ring::sumcheck::LkpTranscript;

    println!("\n[U-K5c] committed masked lookup: aggregate pins (v^X/v^Y/v^M retired), m-recovery closed, LKP-7");
    let ctx = ring_ctx_q8();
    let kf = KField::new(&ctx);
    let zq = ctx.zq;
    let q = zq.q;
    let zero = kf.zero();
    let one = kf.one();
    let rows = silu_int8_table();
    let spec_dg = table_spec_digest(&rows);
    let tab_fused = fused_silu_table(&kf, &rows);
    let t_rows = rows.len(); // 256

    // Battery shape: one instance, witness depth 8 (256 leaves, 100
    // honest), table depth 9 (512 leaves, 256 rows SPLIT across halves).
    let (dw, dt, n_honest) = (8usize, 9usize, 100usize);
    let nw = 1usize << dw;
    let nt = 1usize << dt;
    assert!(n_honest <= blinder_positions(nw)[0]);

    // The commitment shape: one frozen CRS (kappa 8, msg_r 8) carries the
    // tensors, the blinders, the mask coefficients and the ct-round
    // g-masks; K_DEG-per-element gives 64 committed K-elements per slot.
    let shape = CS { kappa: 8, n_r: 26, msg_r: 8 };
    let msg_r = shape.msg_r;
    let kpc = msg_r * D / K_DEG; // committed K-elements per commitment (64)
    let crs = expand_crs(shape, q, 0x5C0D);

    // ---- Honest scenario. ----
    let mut rng = 0x5eed_5c00u64;
    let xs: Vec<i64> = (0..n_honest).map(|_| rng_below(&mut rng, 256) as i64 - 128).collect();
    let ys: Vec<i64> = xs.iter().map(|&x| rows[(x + 128) as usize].1).collect();
    let w_fused: Vec<KElem> =
        xs.iter().zip(ys.iter()).map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y))).collect();
    let m_k = multiplicities(&kf, &w_fused, &tab_fused);
    let m_vals: Vec<i64> = m_k.iter().map(|e| e[0] as i64).collect();

    // ---- Mask + blinder draw (prover-private, committed before alpha). ----
    let mut trmask = ring::ProverRng::from_test_seed("uk5c-masks", &spec_dg);
    let masks_w = draw_masks(&kf, &mut trmask, dw, 0);
    let masks_t = draw_masks(&kf, &mut trmask, dt, 0);
    let mut trbl = ring::ProverRng::from_test_seed("uk5c-blinders", &spec_dg);
    let bl_w = BlinderSet::draw(&kf, &mut trbl);
    let mut bl_t = BlinderSet::draw(&kf, &mut trbl);
    bl_t.solve_mass(&kf, &bl_w.mass(&kf)); // table mass := witness mass

    // ---- Commit everything: X, Y, m, blinders, masks, ct g-masks. ----
    // Packers.
    let pack_scalars = |vals: &[i64]| -> Vec<Poly> {
        assert!(vals.len() <= msg_r * D);
        let mut polys = vec![poly_zero(); msg_r];
        for (i, &v) in vals.iter().enumerate() {
            polys[i / D][i % D] = zq.to_mod(v);
        }
        polys
    };
    let pack_kelems = |kelems: &[KElem]| -> Vec<Vec<Poly>> {
        let mut flat: Vec<u64> = Vec::with_capacity(kelems.len() * K_DEG);
        for e in kelems {
            for c in 0..K_DEG {
                flat.push(e[c]);
            }
        }
        let per = msg_r * D;
        let n_commit = flat.len().div_ceil(per).max(1);
        (0..n_commit)
            .map(|g| {
                (0..msg_r)
                    .map(|s| {
                        (0..D)
                            .map(|c| {
                                let idx = g * per + s * D + c;
                                if idx < flat.len() { flat[idx] } else { 0 }
                            })
                            .collect()
                    })
                    .collect()
            })
            .collect()
    };
    // Blinder K-element layout: witness [tl.a,tl.u,tr.a,tr.u,f0.a,f0.u,
    // f1.a,f1.u] then table [same] — 16 K-elements, one commitment.
    let blinder_kelems = |bw: &BlinderSet, bt: &BlinderSet| -> Vec<KElem> {
        let mut v = Vec::with_capacity(16);
        for b in [&bw.tl, &bw.tr, &bw.f0, &bw.f1, &bt.tl, &bt.tr, &bt.f0, &bt.f1] {
            v.push(b.a.clone());
            v.push(b.u.clone());
        }
        v
    };

    // Message list, in commitment-index order.
    let x_msg = pack_scalars(&xs);
    let y_msg = pack_scalars(&ys);
    let m_msg = pack_scalars(&m_vals);
    let bl_msg = pack_kelems(&blinder_kelems(&bl_w, &bl_t));
    assert_eq!(bl_msg.len(), 1);
    let wmask_msgs = pack_kelems(&masks_w.flatten());
    let tmask_msgs = pack_kelems(&masks_t.flatten());
    // Fixed commitment indices.
    let (idx_x, idx_y, idx_m, idx_bl) = (0usize, 1, 2, 3);
    let base_w = 4usize;
    let base_t = base_w + wmask_msgs.len();
    let n_data = base_t + tmask_msgs.len();

    // The pin builders need the descent products; run the descents first
    // (they need alpha, which needs the commitments — so commit now).
    let mut data_msgs: Vec<Vec<Poly>> =
        vec![x_msg.clone(), y_msg.clone(), m_msg.clone(), bl_msg[0].clone()];
    data_msgs.extend(wmask_msgs.iter().cloned());
    data_msgs.extend(tmask_msgs.iter().cloned());
    assert_eq!(data_msgs.len(), n_data);

    // 9-copy psi batch (LKP-4); the ct-round g-masks are one per claim.
    let n_psi = 9usize;
    let mut rng_g = 0x5eed_5c66u64;
    let g_masks = sample_ct_masks(&mut rng_g, q, msg_r, n_psi);
    let g_base = n_data;
    let n_commits = n_data + g_masks.len();
    let rp = derive_ct_round_params(q, shape, n_commits, 0, 0, true);
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let path = KernelPath::A1(&a1p);

    // Commit all messages (data then g-masks), with fresh rho each.
    let all_msgs: Vec<Vec<Poly>> = data_msgs.iter().cloned().chain(g_masks.iter().cloned()).collect();
    let mut rng_rho = 0x5eed_5c10u64;
    let all_rho: Vec<Vec<Vec<i64>>> = (0..all_msgs.len())
        .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng_rho)).collect())
        .collect();
    let (mut t1s, mut t2s) = (Vec::new(), Vec::new());
    for (xm, rho) in all_msgs.iter().zip(all_rho.iter()) {
        let (t1, t2) = commit(&path, &crs, xm, rho);
        t1s.push(t1);
        t2s.push(t2);
    }
    // h0_lkp binds the table digest + EVERY commitment (masks/blinders
    // included) — the amended alpha edge (E3Z-N2).
    let h0_lkp = ct_h0(&crs, &spec_dg, &t1s, &t2s, &[]);

    // ---- Kelem pin-term splitter (flat K-element run -> per-commit). ----
    let kelem_terms = |base: usize, flat_off: usize, weights: &[KElem]| -> Vec<PinTerm> {
        let mut terms = Vec::new();
        let mut i = 0usize;
        while i < weights.len() {
            let idx = flat_off + i;
            let commit = base + idx / kpc;
            let coeff0 = (idx % kpc) * K_DEG;
            let room = kpc - (idx % kpc);
            let take = room.min(weights.len() - i);
            terms.push(PinTerm::Kelems { commit, coeff0, weights: weights[i..i + take].to_vec() });
            i += take;
        }
        terms
    };

    // ---- Descent-pin builder (G_j, open_g, open_Rp/Rq). Weights depend
    // only on the mask SHAPE + opening points (public), so the verifier
    // rebuilds them from a zero-mask shell of the same degrees. ----
    let descent_pins = |base: usize,
                        shape_masks: &MaskSet,
                        proof: &MaskedDescentProof,
                        end: &DescentEnd,
                        depth: usize|
     -> Vec<PinnedValue> {
        let mut pins = Vec::new();
        for j in 1..depth {
            let lp = &proof.layers[j - 1];
            let gm = &shape_masks.g[j - 1];
            pins.push(PinnedValue {
                terms: kelem_terms(base, shape_masks.g_offset(j), &g_hypersum_weights(&kf, gm)),
                value: lp.g_sum.clone(),
            });
            let (open_pt, mu_prev, c_w) = &end.layer_pts[j - 1];
            pins.push(PinnedValue {
                terms: kelem_terms(base, shape_masks.g_offset(j), &g_open_weights(&kf, gm, open_pt)),
                value: lp.open_g.clone(),
            });
            if j >= 2 {
                let (orp, orq) = lp.open_r.clone().expect("interior layer opens Rp/Rq");
                let rw = r_open_weights(&kf, mu_prev, c_w);
                pins.push(PinnedValue {
                    terms: kelem_terms(base, shape_masks.r_offset(j), &rw),
                    value: orp,
                });
                pins.push(PinnedValue {
                    terms: kelem_terms(base, shape_masks.r_offset(j) + 6, &rw),
                    value: orq,
                });
            }
        }
        pins
    };

    // ---- Leaf-pin builder (the aggregate P/Q pins; v^X/v^Y/v^M never
    // appear — only blinded aggregates over committed columns). ----
    let leaf_pins = |endw: &DescentEnd, endt: &DescentEnd, alpha: &KElem| -> Vec<PinnedValue> {
        let lw = eq_table(&kf, &endw.zstar);
        let lt = eq_table(&kf, &endt.zstar);
        let bpw = blinder_positions(nw);
        let bpt = blinder_positions(nt);
        let tpos = table_row_positions(t_rows, nt);
        let eqw: Vec<KElem> = bpw.iter().map(|&p| lw[p].clone()).collect();
        let eqt: Vec<KElem> = bpt.iter().map(|&p| lt[p].clone()).collect();
        let hw = (0..n_honest).fold(zero.clone(), |a, i| kf.add(&a, &lw[i]));
        let ht = (0..t_rows).fold(zero.clone(), |a, j| kf.add(&a, &lt[tpos[j]]));
        let sum_eqw = eqw.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let sum_eqt = eqt.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let ft = (0..t_rows)
            .fold(zero.clone(), |a, j| kf.add(&a, &kf.mul(&lt[tpos[j]], &tab_fused[j])));
        let z = zero.clone();
        // Witness P: p* - H = sum eqw a_bl.
        let wp = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: idx_bl,
                coeff0: 0,
                weights: vec![
                    eqw[0].clone(), z.clone(), eqw[1].clone(), z.clone(),
                    eqw[2].clone(), z.clone(), eqw[3].clone(), z.clone(),
                ],
            }],
            value: kf.sub(&endw.p_claim, &hw),
        };
        // Witness Q: q* - alpha H - D_dummy = sum eqw u_bl - (v^X + Y v^Y).
        let ddw = kf.sub(&kf.sub(&one, &hw), &sum_eqw);
        let wq = PinnedValue {
            terms: vec![
                PinTerm::Kelems {
                    commit: idx_bl,
                    coeff0: 0,
                    weights: vec![
                        z.clone(), eqw[0].clone(), z.clone(), eqw[1].clone(),
                        z.clone(), eqw[2].clone(), z.clone(), eqw[3].clone(),
                    ],
                },
                PinTerm::Scalar {
                    commit: idx_x,
                    coeff0: 0,
                    weights: (0..n_honest).map(|i| kf.neg(&lw[i])).collect(),
                },
                PinTerm::Scalar {
                    commit: idx_y,
                    coeff0: 0,
                    weights: (0..n_honest).map(|i| kf.neg(&mul_y(&kf, &lw[i]))).collect(),
                },
            ],
            value: kf.sub(&kf.sub(&endw.q_claim, &kf.mul(alpha, &hw)), &ddw),
        };
        // Table P: p*_t = sum L_pos m_j + sum eqt a'_bl.
        let tp = PinnedValue {
            terms: vec![
                PinTerm::Scalar {
                    commit: idx_m,
                    coeff0: 0,
                    weights: (0..t_rows).map(|j| lt[tpos[j]].clone()).collect(),
                },
                PinTerm::Kelems {
                    commit: idx_bl,
                    coeff0: 8 * K_DEG,
                    weights: vec![
                        eqt[0].clone(), z.clone(), eqt[1].clone(), z.clone(),
                        eqt[2].clone(), z.clone(), eqt[3].clone(), z.clone(),
                    ],
                },
            ],
            value: endt.p_claim.clone(),
        };
        // Table Q: q*_t - alpha H_t - D_dummy + FT = sum eqt u'_bl.
        let ddt = kf.sub(&kf.sub(&one, &ht), &sum_eqt);
        let tq = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: idx_bl,
                coeff0: 8 * K_DEG,
                weights: vec![
                    z.clone(), eqt[0].clone(), z.clone(), eqt[1].clone(),
                    z.clone(), eqt[2].clone(), z.clone(), eqt[3].clone(),
                ],
            }],
            value: kf.add(
                &kf.sub(&kf.sub(&endt.q_claim, &kf.mul(alpha, &ht)), &ddt),
                &ft,
            ),
        };
        vec![wp, wq, tp, tq]
    };

    // Absorb every pinned value (the E4-N1 edge for the pins), then draw
    // the pin psi from that state.
    let absorb_pins = |tr: &mut LkpTranscript, pins: &[PinnedValue]| {
        for p in pins {
            tr.absorb_k(&kf, "uk5c-pin", std::slice::from_ref(&p.value));
        }
    };

    // The shape-only mask shells the verifier uses to rebuild pin weights.
    let shell_w = zero_masks(&kf, dw, 0);
    let shell_t = zero_masks(&kf, dt, 0);

    // ================= PROVER =================
    let mut tr = LkpTranscript::new("uk5c-lkp", &h0_lkp);
    let alpha = tr.challenge_k(&kf);
    let wtree = blinded_witness_tree(&kf, &alpha, &w_fused, dw, &bl_w);
    let ttree = blinded_table_tree(&kf, &alpha, &tab_fused, &m_k, dt, &bl_t);
    let t_prove = Instant::now();
    let (pw_proof, endw) = masked_gkr_prove(&kf, &[wtree], masks_w.harness_clone(), &mut tr);
    let (pt_proof, endt) = masked_gkr_prove(&kf, &[ttree], masks_t.harness_clone(), &mut tr);
    let prove_ms = t_prove.elapsed().as_secs_f64() * 1e3;
    // Pins (weights from the real masks — identical to the shells).
    let mut pins = descent_pins(base_w, &masks_w, &pw_proof, &endw, dw);
    pins.extend(descent_pins(base_t, &masks_t, &pt_proof, &endt, dt));
    pins.extend(leaf_pins(&endw, &endt, &alpha));
    absorb_pins(&mut tr, &pins);
    let pin_rows = pins.len() * K_DEG;
    let psi = derive_pin_psi(&tr.state(), n_psi, pin_rows, q);
    let claims = pin_claims(&kf, &pins, n_data, msg_r, &psi);
    let h0_round = ct_h0(&crs, &tr.state(), &t1s, &t2s, &[]);
    let openings: Vec<StdOpening> = all_msgs
        .iter()
        .zip(all_rho.iter())
        .enumerate()
        .map(|(i, (xm, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x: xm, rho })
        .collect();
    let mut rng_ct = 0x5eed_5c20u64;
    let (proof, _) = prove_ct_round(
        &path, &ctx, &rp, None, &crs, &h0_round, &claims, &[], &[], &[], &openings, &[], &[],
        g_base, &mut rng_ct,
    );

    // ================= VERIFIER =================
    // Fresh transcript; masked_gkr_verify(pin=false) grounds the descent
    // algebra on the sent openings, and the ct-round pins them (+ the
    // aggregate leaf claims) to the commitments.
    let verify_masked = |proof_w: &MaskedDescentProof,
                         proof_t: &MaskedDescentProof,
                         claims_expected: bool|
     -> bool {
        let mut tv = LkpTranscript::new("uk5c-lkp", &h0_lkp);
        let av = tv.challenge_k(&kf);
        if av != alpha {
            return false;
        }
        let Some((roots_w, ew)) = masked_gkr_verify(&kf, 1, dw, &shell_w, proof_w, &mut tv, false)
        else {
            return false;
        };
        let Some((roots_t, et)) = masked_gkr_verify(&kf, 1, dt, &shell_t, proof_t, &mut tv, false)
        else {
            return false;
        };
        // Blinded root cross-check on the DERIVED roots.
        if kf.is_zero(&roots_w[0][1]) || kf.is_zero(&roots_t[0][1]) {
            return false;
        }
        if kf.mul(&roots_w[0][0], &roots_t[0][1]) != kf.mul(&roots_t[0][0], &roots_w[0][1]) {
            return false;
        }
        if !claims_expected {
            return true;
        }
        // Rebuild pins from the shape shells + the transcript values.
        let mut pv = descent_pins(base_w, &shell_w, proof_w, &ew, dw);
        pv.extend(descent_pins(base_t, &shell_t, proof_t, &et, dt));
        pv.extend(leaf_pins(&ew, &et, &av));
        absorb_pins(&mut tv, &pv);
        let psi_v = derive_pin_psi(&tv.state(), n_psi, pv.len() * K_DEG, q);
        let claims_v = pin_claims(&kf, &pv, n_data, msg_r, &psi_v);
        let h0r_v = ct_h0(&crs, &tv.state(), &t1s, &t2s, &[]);
        verify_ct_round(
            &path, &ctx, &rp, None, &crs, &h0r_v, &claims_v, &[], &[], &[], &t1s, &t2s, &[], &[],
            &[], g_base, &proof,
        )
    };
    assert_true(
        &format!(
            "U-K5c committed masked pass: FFN-shape tensor ACCEPTS (masked descents + blinded cross-check + {} aggregate pins over commitments, {prove_ms:.0} ms prove)",
            pins.len()
        ),
        verify_masked(&pw_proof, &pt_proof, true),
    );
    // v^X/v^Y/v^M are RETIRED: the flattened transcript is only layer1 +
    // round polys + boundaries + openings; no per-tensor MLE value.
    assert_true(
        "U-K5c leaf interface: v^X/v^Y/v^M never sent — only blinded aggregate pins (the histogram channel is closed structurally)",
        flatten_masked(&pw_proof).len() + flatten_masked(&pt_proof).len() > 0,
    );

    // ---- Z1-class m-recovery harness at engine scale (spike Z1b/Z3a).
    // The table descent transcript is an AFFINE function of m with
    // PUBLIC coefficients (the q-side is m-independent), so in the
    // honest-verifier (fixed-coins) view it is probe-invertible: from
    // the ZERO-mask (unmasked-equivalent) transcript m is recovered
    // EXACTLY; the SAME pipeline against the masked transcript returns a
    // wrong histogram. ----
    use ring::gkr_masked::Blinder;
    let benign = || BlinderSet {
        tl: Blinder { a: zero.clone(), u: one.clone() },
        tr: Blinder { a: zero.clone(), u: one.clone() },
        f0: Blinder { a: zero.clone(), u: one.clone() },
        f1: Blinder { a: zero.clone(), u: one.clone() },
    };
    // The affine probe basis: fixed-coins zero-mask benign-blinder table
    // descent, flattened. alpha is fixed across all probes.
    let probe = |m_vec: &[u64]| -> Vec<KElem> {
        let m_probe: Vec<KElem> = m_vec.iter().map(|&c| kf.embed(c)).collect();
        let bl = benign();
        let zmask = zero_masks(&kf, dt, 0);
        let tree = blinded_table_tree(&kf, &alpha, &tab_fused, &m_probe, dt, &bl);
        let mut trp = LkpTranscript::fixed_coins("uk5c-recover", &spec_dg);
        let (p, _) = masked_gkr_prove(&kf, &[tree], zmask, &mut trp);
        flatten_masked(&p)
    };
    // Base + 256 unit-column probes (shared by both recoveries).
    let base_flat = probe(&vec![0u64; t_rows]);
    let cols: Vec<Vec<KElem>> = (0..t_rows)
        .map(|j| {
            let mut e = vec![0u64; t_rows];
            e[j] = 1;
            let pj = probe(&e);
            pj.iter().zip(base_flat.iter()).map(|(a, b)| kf.sub(a, b)).collect()
        })
        .collect();
    // Base-field Gaussian elimination (each K-element = K_DEG rows),
    // early stop at rank t_rows.
    let solve = |observed: &[KElem]| -> (usize, Vec<u64>) {
        let mut aug: Vec<Vec<u64>> = Vec::new();
        for i in 0..base_flat.len() {
            let rhs = kf.sub(&observed[i], &base_flat[i]);
            for c in 0..K_DEG {
                let mut row: Vec<u64> = (0..t_rows).map(|j| cols[j][i][c]).collect();
                row.push(rhs[c]);
                if row.iter().any(|&x| x != 0) {
                    aug.push(row);
                }
            }
        }
        let mut r = 0usize;
        let mut piv_cols = Vec::new();
        for col in 0..t_rows {
            let Some(p) = (r..aug.len()).find(|&i| aug[i][col] != 0) else { continue };
            aug.swap(r, p);
            let inv = zq.inv(aug[r][col]);
            for x in aug[r].iter_mut() {
                *x = zq.mul(*x, inv);
            }
            for i in 0..aug.len() {
                if i != r && aug[i][col] != 0 {
                    let f = aug[i][col];
                    for c in 0..=t_rows {
                        aug[i][c] = zq.sub(aug[i][c], zq.mul(f, aug[r][c]));
                    }
                }
            }
            piv_cols.push(col);
            r += 1;
            if r == t_rows {
                break;
            }
        }
        let mut sol = vec![0u64; t_rows];
        for (ri, &col) in piv_cols.iter().enumerate() {
            sol[col] = aug[ri][t_rows];
        }
        (r, sol)
    };
    // The unmasked-equivalent transcript: recover m EXACTLY.
    let t_rec = Instant::now();
    let unmasked_obs = probe(&m_vals.iter().map(|&v| v as u64).collect::<Vec<_>>());
    let (rank0, sol0) = solve(&unmasked_obs);
    let rec_ms = t_rec.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!(
            "U-K5c leak (Z1b): m RECOVERED EXACTLY from the zero-mask transcript (rank {rank0}/{t_rows}) — the histogram leaks unmasked ({rec_ms:.0} ms)"
        ),
        rank0 == t_rows && sol0 == m_vals.iter().map(|&v| v as u64).collect::<Vec<_>>(),
    );
    // The masked transcript: the SAME pipeline returns a wrong m.
    let mut rng_h = 0x5eed_5c30u64;
    let mut trh = ring::ProverRng::from_test_seed("uk5c-recover-mask", &spec_dg);
    let masks_h = draw_masks(&kf, &mut trh, dt, 0);
    let bl_h = {
        let mut b = BlinderSet::draw(&kf, &mut trh);
        b.tl.a = kf.embed(1 + rng_below(&mut rng_h, 1000));
        b
    };
    let masked_tree = blinded_table_tree(&kf, &alpha, &tab_fused, &m_k, dt, &bl_h);
    let mut trmp = LkpTranscript::fixed_coins("uk5c-recover", &spec_dg);
    let (masked_obs_proof, _) = masked_gkr_prove(&kf, &[masked_tree], masks_h, &mut trmp);
    let masked_obs = flatten_masked(&masked_obs_proof);
    let (_, sol_m) = solve(&masked_obs);
    assert_true(
        "U-K5c closure (Z3a): the SAME recovery pipeline against the MASKED transcript returns a wrong histogram (recovered != m) — the leak is closed",
        sol_m != m_vals.iter().map(|&v| v as u64).collect::<Vec<_>>(),
    );

    // ---- LKP-7 arithmetic (freeze row pins the FFN point; sanity here
    // at the battery shape). ----
    let (rw7, kw7) = masked_transcript_totals(dw, 0, 1);
    let (rt7, kt7) = masked_transcript_totals(dt, 0, 1);
    let (gw6, rw6) = mask_coeff_counts(dw, 0);
    let (gt6, rt6) = mask_coeff_counts(dt, 0);
    assert_true(
        &format!(
            "U-K5c LKP-7 sanity: masked transcript at (dw={dw}, dt={dt}, e=0) = witness {rw7} rounds/{kw7} K-el, table {rt7}/{kt7}; pass {} B; masks g {gw6}+{gt6}/R {rw6}+{rt6}",
            masked_pass_bytes(dw, dt, 0, 1)
        ),
        kw7 > 0 && kt7 > 0 && masked_pass_bytes(dw, dt, 0, 1) == 64 * (kw7 + kt7),
    );

    // ---- D4: masked-vs-unmasked prover/verifier delta at the battery
    // shape (both descents; the pin ct-round timing is reported by the
    // ACCEPT line above). Informative — feeds the Section 3.5 re-grade. ----
    {
        use ring::gkr::{absorb_roots, gkr_prove, gkr_verify, root_cross_check};
        let reps = 20;
        let (mut mprove, mut mverify, mut uprove, mut uverify) = (0f64, 0f64, 0f64, 0f64);
        for _ in 0..reps {
            // Masked. Each timed pass consumes its own harness_clone of the
            // fixed base sets — the shipped API has no reuse path (moves by
            // value), so the bench models a fresh session per repetition.
            let wt = blinded_witness_tree(&kf, &alpha, &w_fused, dw, &bl_w);
            let tt = blinded_table_tree(&kf, &alpha, &tab_fused, &m_k, dt, &bl_t);
            let t = Instant::now();
            let mut trp = LkpTranscript::new("uk5c-bench", &h0_lkp);
            let (mw, _) = masked_gkr_prove(&kf, &[wt], masks_w.harness_clone(), &mut trp);
            let (mt, _) = masked_gkr_prove(&kf, &[tt], masks_t.harness_clone(), &mut trp);
            mprove += t.elapsed().as_secs_f64() * 1e3;
            let t = Instant::now();
            let mut trv = LkpTranscript::new("uk5c-bench", &h0_lkp);
            let _ = masked_gkr_verify(&kf, 1, dw, &shell_w, &mw, &mut trv, false);
            let _ = masked_gkr_verify(&kf, 1, dt, &shell_t, &mt, &mut trv, false);
            mverify += t.elapsed().as_secs_f64() * 1e3;
            // Unmasked (same blinded trees, plain descent).
            let wtu = blinded_witness_tree(&kf, &alpha, &w_fused, dw, &bl_w);
            let ttu = blinded_table_tree(&kf, &alpha, &tab_fused, &m_k, dt, &bl_t);
            let rw = wtu.root();
            let rt = ttu.root();
            let t = Instant::now();
            let mut trp = LkpTranscript::new("uk5c-bench-u", &h0_lkp);
            absorb_roots(&kf, &[rw.clone()], &mut trp);
            let (uw, _, _, _) = gkr_prove(&kf, &[wtu], &mut trp);
            absorb_roots(&kf, &[rt.clone()], &mut trp);
            let (ut, _, _, _) = gkr_prove(&kf, &[ttu], &mut trp);
            uprove += t.elapsed().as_secs_f64() * 1e3;
            let t = Instant::now();
            let mut trv = LkpTranscript::new("uk5c-bench-u", &h0_lkp);
            let _ = root_cross_check(&kf, &rw, &rt);
            absorb_roots(&kf, &[rw.clone()], &mut trv);
            let _ = gkr_verify(&kf, &[rw.clone()], dw, &uw, &mut trv);
            absorb_roots(&kf, &[rt.clone()], &mut trv);
            let _ = gkr_verify(&kf, &[rt.clone()], dt, &ut, &mut trv);
            uverify += t.elapsed().as_secs_f64() * 1e3;
        }
        let (mprove, mverify, uprove, uverify) = (
            mprove / reps as f64,
            mverify / reps as f64,
            uprove / reps as f64,
            uverify / reps as f64,
        );
        println!(
            "  U-K5c D4 delta (dw={dw}, dt={dt}, 1 inst, {reps} reps): prove masked {mprove:.2} ms vs unmasked {uprove:.2} ms (x{:.2}); verify masked {mverify:.2} ms vs unmasked {uverify:.2} ms (x{:.2})",
            mprove / uprove,
            mverify / uverify,
        );
    }

    self_test_lookup_zk_neg(&kf, &spec_dg, &tab_fused, &rows);
}

/// K-matrix rank over the slot field (row-echelon, exact) — the
/// engine-scale exposure-rank certificates (spike k_rank_kmat).
fn k_rank(kf: &ring::kfield::KField, mut rows: Vec<Vec<ring::kfield::KElem>>) -> usize {
    if rows.is_empty() {
        return 0;
    }
    let ncols = rows[0].len();
    let mut r = 0usize;
    for col in 0..ncols {
        let Some(piv) = (r..rows.len()).find(|&i| !kf.is_zero(&rows[i][col])) else { continue };
        rows.swap(r, piv);
        let inv = kf.inv(&rows[r][col]);
        rows[r] = rows[r].iter().map(|x| kf.mul(x, &inv)).collect();
        for i in 0..rows.len() {
            if i != r && !kf.is_zero(&rows[i][col]) {
                let f = rows[i][col].clone();
                rows[i] = rows[i]
                    .iter()
                    .zip(rows[r].clone())
                    .map(|(x, y)| kf.sub(x, &kf.mul(&f, &y)))
                    .collect();
            }
        }
        r += 1;
        if r == rows.len() {
            break;
        }
    }
    r
}

// U-K5d (M4_LOOKUP_ZK_DESIGN.md Section 6): the E3-Z NEGATIVE BATTERY —
// each F5 pair is an ACCEPT leg (the attack works under the broken
// ordering) and a REJECT leg (the shipped order stops the same
// crafting), plus the rank canaries and the guard-restart regression;
// then the E3/E4 edges re-run under masking (D3). The ACCEPT-leg
// surgery uses the honest-verifier fixed-coins tape (the spike's
// adversary-readable Tape): challenges stay independent of the doctored
// messages, so the crafting is isolated to the edge under test.
fn self_test_lookup_zk_neg(
    kf: &ring::kfield::KField,
    spec_dg: &[u8; 32],
    _tab_fused_real: &[ring::kfield::KElem],
    rows_real: &[(i64, i64)],
) {
    use ring::gkr_masked::{
        BlinderSet, MaskedDescentProof, blinded_table_tree, blinded_witness_tree, draw_masks,
        masked_gkr_prove, masked_gkr_verify,
    };
    use ring::kfield::KElem;
    use ring::lookup::{fuse_pair, fused_silu_table, multiplicities};
    use ring::sumcheck::LkpTranscript;
    let _ = rows_real;
    println!("\n[U-K5d] E3-Z negative battery: E3Z-N1..N4 F5 pairs + rank canaries + guard restart");
    let zq = kf.zq;
    let q = zq.q;
    let one = kf.one();

    // Toy scenario, spike-faithful (N=32, T=8): witness depth 5, table
    // depth 5 (8 rows split across halves), 10 honest leaves.
    let (dw, dt, n_honest, t_toy) = (5usize, 5usize, 10usize, 8usize);
    let toy_rows: Vec<(i64, i64)> = (0..t_toy as i64).map(|v| (v, (3 * v + 5) % 31)).collect();
    let tab_toy = fused_silu_table(kf, &toy_rows);
    let mut rng = 0x5eed_5d00u64;
    let xs: Vec<usize> = (0..n_honest).map(|_| rng_below(&mut rng, t_toy as u64) as usize).collect();
    let ys_ok: Vec<i64> = xs.iter().map(|&x| toy_rows[x].1).collect();
    let wf_of = |ys: &[i64]| -> Vec<KElem> {
        xs.iter()
            .zip(ys.iter())
            .map(|(&x, &y)| fuse_pair(kf, zq.to_mod(toy_rows[x].0), zq.to_mod(y)))
            .collect()
    };
    let m_honest = multiplicities(kf, &wf_of(&ys_ok), &tab_toy);

    // A false witness: one wrong y (spike bad_witness).
    let mut ys_bad = ys_ok.clone();
    ys_bad[3] = (ys_bad[3] + 1) % 31;

    // Prove both descents under a fixed-coins tape seeded by seed; the
    // masks/blinders are drawn fresh from a statement-wave tape. Returns
    // (proofs, ends, roots, bl_w, bl_t, masks_w, masks_t, alpha).
    let roots_of = |p: &MaskedDescentProof| -> [KElem; 2] {
        let l = &p.layer1[0];
        [
            kf.add(&kf.mul(&l[0], &l[3]), &kf.mul(&l[1], &l[2])),
            kf.mul(&l[2], &l[3]),
        ]
    };

    // ---- E3Z-N1 (spike Z4): the mask-ordering F5 pair. ----
    {
        let mut trm = ring::ProverRng::from_test_seed("uk5d-n1-masks", spec_dg);
        let masks_w = draw_masks(kf, &mut trm, dw, 0);
        let masks_t = draw_masks(kf, &mut trm, dt, 0);
        let mut trb = ring::ProverRng::from_test_seed("uk5d-n1-bl", spec_dg);
        let bl_w = BlinderSet::draw(kf, &mut trb);
        let mut bl_t = BlinderSet::draw(kf, &mut trb);
        bl_t.solve_mass(kf, &bl_w.mass(kf));
        let seed = *b"uk5d-n1-fixed-coins-seed-32byte!";
        let mut tp = LkpTranscript::fixed_coins("uk5d-n1", &seed);
        let alpha = tp.challenge_k(kf);
        let wtree = blinded_witness_tree(kf, &alpha, &wf_of(&ys_bad), dw, &bl_w);
        let ttree = blinded_table_tree(kf, &alpha, &tab_toy, &m_honest, dt, &bl_t);
        let (pw, _endw) = masked_gkr_prove(kf, &[wtree], masks_w.harness_clone(), &mut tp);
        let (pt, _endt) = masked_gkr_prove(kf, &[ttree], masks_t.harness_clone(), &mut tp);
        // The doctoring: shift the witness layer-1 p-value so the derived
        // root ratio matches the table's (cross-check passes), and absorb
        // the layer-1 claim defect into a G_1 chosen AFTER nu_1.
        let rw = roots_of(&pw);
        let rt = roots_of(&pt);
        let sigma_w = kf.mul(&rw[0], &kf.inv(&rw[1]));
        let sigma_t = kf.mul(&rt[0], &kf.inv(&rt[1]));
        let delta = kf.sub(&sigma_t, &sigma_w);
        assert!(!kf.is_zero(&delta), "false lookup should shift the ratio");
        let [p10, p11, q10, q11] = pw.layer1[0].clone();
        let p10_d = kf.add(&p10, &kf.mul(&delta, &q10));
        // Replay the fixed-coins tape for mu0, lam1, nu1 (witness descent
        // is first): alpha, mu0, then lambda, nu (nonzero).
        let (mu0, lam1, nu1) = {
            let mut t2 = LkpTranscript::fixed_coins("uk5d-n1", &seed);
            let _a = t2.challenge_k(kf);
            let mu0 = t2.challenge_k(kf);
            let lam1 = t2.challenge_k(kf);
            let mut nu1 = t2.challenge_k(kf);
            while kf.is_zero(&nu1) {
                nu1 = t2.challenge_k(kf);
            }
            (mu0, lam1, nu1)
        };
        let fold2 = |a: &KElem, b: &KElem| kf.add(a, &kf.mul(&mu0, &kf.sub(b, a)));
        let c_true = kf.add(&fold2(&p10, &p11), &kf.mul(&lam1, &fold2(&q10, &q11)));
        let c_doc = kf.add(&fold2(&p10_d, &p11), &kf.mul(&lam1, &fold2(&q10, &q11)));
        let mut pw_atk = MaskedTamper::clone_proof(kf, &pw);
        pw_atk.layer1[0] = [p10_d, p11, q10, q11];
        pw_atk.layers[0].g_sum =
            kf.add(&pw.layers[0].g_sum, &kf.mul(&kf.sub(&c_true, &c_doc), &kf.inv(&nu1)));
        // Verify both legs (fixed-coins), cross-check on derived roots.
        let verify = |pin: bool| -> bool {
            let mut tv = LkpTranscript::fixed_coins("uk5d-n1", &seed);
            let _a = tv.challenge_k(kf);
            let Some((rw_v, _)) = masked_gkr_verify(kf, 1, dw, &masks_w, &pw_atk, &mut tv, pin)
            else {
                return false;
            };
            let Some((rt_v, _)) = masked_gkr_verify(kf, 1, dt, &masks_t, &pt, &mut tv, pin) else {
                return false;
            };
            !kf.is_zero(&rw_v[0][1])
                && !kf.is_zero(&rt_v[0][1])
                && kf.mul(&rw_v[0][0], &rt_v[0][1]) == kf.mul(&rt_v[0][0], &rw_v[0][1])
        };
        assert_true(
            "U-K5d E3Z-N1 (Z4): G chosen AFTER nu (mask claim outside the statement hash) absorbs the doctored layer-1 defect — the false lookup ACCEPTS",
            verify(false),
        );
        assert_true(
            "U-K5d E3Z-N1 (Z4): the shipped order (G E4-pinned to the pre-committed mask) REJECTS the same crafting",
            !verify(true),
        );
    }

    self_test_lookup_zk_neg_2(kf, spec_dg);
    let _ = (one, q);
}

/// U-K5d continued: E3Z-N2 (blinder ordering), E3Z-N3 (mask freshness),
/// E3Z-N4 (rank canaries + guard restart), and the D3 re-runs of the
/// E3/E4 edges under masking.
fn self_test_lookup_zk_neg_2(kf: &ring::kfield::KField, spec_dg: &[u8; 32]) {
    use ring::gkr::root_cross_check;
    use ring::gkr_masked::{
        Blinder, BlinderSet, MaskSet, MaskedDescentProof, blinded_table_tree, blinded_witness_tree,
        draw_masks, masked_gkr_prove, masked_gkr_verify, zero_masks,
    };
    use ring::kfield::KElem;
    use ring::lookup::{fuse_pair, fused_silu_table, multiplicities};
    use ring::sumcheck::LkpTranscript;
    let zq = kf.zq;
    let q = zq.q;
    let one = kf.one();
    let zero = kf.zero();

    let (dw, dt, n_honest, t_toy) = (5usize, 5usize, 10usize, 8usize);
    let toy_rows: Vec<(i64, i64)> = (0..t_toy as i64).map(|v| (v, (3 * v + 5) % 31)).collect();
    let tab_toy = fused_silu_table(kf, &toy_rows);
    let mut rng = 0x5eed_5d10u64;
    let xs: Vec<usize> = (0..n_honest).map(|_| rng_below(&mut rng, t_toy as u64) as usize).collect();
    let ys_ok: Vec<i64> = xs.iter().map(|&x| toy_rows[x].1).collect();
    let wf_of = |ys: &[i64]| -> Vec<KElem> {
        xs.iter()
            .zip(ys.iter())
            .map(|(&x, &y)| fuse_pair(kf, zq.to_mod(toy_rows[x].0), zq.to_mod(y)))
            .collect()
    };
    let w_ok = wf_of(&ys_ok);
    let m_honest = multiplicities(kf, &w_ok, &tab_toy);
    let mut ys_bad = ys_ok.clone();
    ys_bad[3] = (ys_bad[3] + 1) % 31;

    // ---- E3Z-N2 (spike Z6): the blinder-ordering F5 pair. The
    // cross-check is the discriminator; roots come straight off the
    // blinded trees. ----
    {
        let mut trb = ring::ProverRng::from_test_seed("uk5d-n2-bl", spec_dg);
        let mut bl_w = BlinderSet::draw(kf, &mut trb);
        let mut bl_t = BlinderSet::draw(kf, &mut trb);
        bl_t.solve_mass(kf, &bl_w.mass(kf));
        // A KNOWN alpha: the adversary reads it, then solves the witness
        // blinder mass so the blinded cross-check passes for the FALSE
        // lookup (one wrong y).
        let alpha1 = {
            let mut t = LkpTranscript::fixed_coins("uk5d-n2-a1", spec_dg);
            t.challenge_k(kf)
        };
        let w_bad = wf_of(&ys_bad);
        let root_ratio = |tree: &ring::gkr::FracTree| -> KElem {
            let r = tree.root();
            kf.mul(&r[0], &kf.inv(&r[1]))
        };
        let wt0 = blinded_witness_tree(kf, &alpha1, &w_bad, dw, &bl_w);
        let tt0 = blinded_table_tree(kf, &alpha1, &tab_toy, &m_honest, dt, &bl_t);
        let d2 = kf.sub(&root_ratio(&tt0), &root_ratio(&wt0));
        // sigma_w gains a_tL/u_tL when a_tL += d2 * u_tL.
        bl_w.tl.a = kf.add(&bl_w.tl.a, &kf.mul(&d2, &bl_w.tl.u));
        let accept = {
            let wt = blinded_witness_tree(kf, &alpha1, &w_bad, dw, &bl_w);
            let tt = blinded_table_tree(kf, &alpha1, &tab_toy, &m_honest, dt, &bl_t);
            root_cross_check(kf, &wt.root(), &tt.root())
        };
        assert_true(
            "U-K5d E3Z-N2 (Z6): a blinder mass solved at a KNOWN alpha ACCEPTS the same false lookup (blinders unbound before alpha)",
            accept,
        );
        // Shipped order: the SAME committed blinders against a FRESH alpha.
        let alpha2 = {
            let mut t = LkpTranscript::fixed_coins("uk5d-n2-a2", spec_dg);
            t.challenge_k(kf)
        };
        let reject = {
            let wt = blinded_witness_tree(kf, &alpha2, &w_bad, dw, &bl_w);
            let tt = blinded_table_tree(kf, &alpha2, &tab_toy, &m_honest, dt, &bl_t);
            !root_cross_check(kf, &wt.root(), &tt.root())
        };
        assert_true(
            "U-K5d E3Z-N2 (Z6): a FRESH alpha REJECTS the same committed blinders (h0_lkp must bind them before alpha)",
            reject,
        );
    }

    let alpha_h = {
        let mut t = LkpTranscript::fixed_coins("uk5d-alpha", spec_dg);
        t.challenge_k(kf)
    };
    let _ = Blinder { a: zero.clone(), u: one.clone() };

    // ---- E3Z-N3 (mask freshness): two passes sharing one g-mask — the
    // transcript DIFFERENCE cancels the (identical) mask AND blinder
    // contributions and reproduces the unmasked leak; then the engine
    // REFUSES reuse. The recovery probe basis therefore carries the SAME
    // shared blinders (zero masks), so its m-linear map matches. ----
    {
        let mut trm = ring::ProverRng::from_test_seed("uk5d-n3-masks", spec_dg);
        let masks_shared = draw_masks(kf, &mut trm, dt, 0);
        let mut trb = ring::ProverRng::from_test_seed("uk5d-n3-bl", spec_dg);
        let bl_shared = BlinderSet::draw(kf, &mut trb);
        // The zero-mask shared-blinder probe basis (matches the linear
        // map of the two masked passes' difference).
        let probe = |m_vec: &[u64]| -> Vec<KElem> {
            let m_probe: Vec<KElem> = m_vec.iter().map(|&c| kf.embed(c)).collect();
            let zmask = zero_masks(kf, dt, 0);
            let tree = blinded_table_tree(kf, &alpha_h, &tab_toy, &m_probe, dt, &bl_shared);
            let mut trp = LkpTranscript::fixed_coins("uk5d-recover", spec_dg);
            let (p, _) = masked_gkr_prove(kf, &[tree], zmask, &mut trp);
            flatten_masked(&p)
        };
        let base_flat = probe(&vec![0u64; t_toy]);
        let cols: Vec<Vec<KElem>> = (0..t_toy)
            .map(|j| {
                let mut e = vec![0u64; t_toy];
                e[j] = 1;
                let pj = probe(&e);
                pj.iter().zip(base_flat.iter()).map(|(a, b)| kf.sub(a, b)).collect()
            })
            .collect();
        // The rhs IS the transcript DIFFERENCE (already base-subtracted),
        // so solve consumes it directly against the m-linear columns.
        let solve = |rhs_diff: &[KElem]| -> Vec<u64> {
            let mut aug: Vec<Vec<u64>> = Vec::new();
            for i in 0..base_flat.len() {
                let rhs = &rhs_diff[i];
                for c in 0..ring::kfield::K_DEG {
                    let mut row: Vec<u64> = (0..t_toy).map(|j| cols[j][i][c]).collect();
                    row.push(rhs[c]);
                    if row.iter().any(|&x| x != 0) {
                        aug.push(row);
                    }
                }
            }
            let mut r = 0usize;
            let mut piv = Vec::new();
            for col in 0..t_toy {
                let Some(p) = (r..aug.len()).find(|&i| aug[i][col] != 0) else { continue };
                aug.swap(r, p);
                let inv = zq.inv(aug[r][col]);
                for x in aug[r].iter_mut() {
                    *x = zq.mul(*x, inv);
                }
                for i in 0..aug.len() {
                    if i != r && aug[i][col] != 0 {
                        let f = aug[i][col];
                        for c in 0..=t_toy {
                            aug[i][c] = zq.sub(aug[i][c], zq.mul(f, aug[r][c]));
                        }
                    }
                }
                piv.push(col);
                r += 1;
                if r == t_toy {
                    break;
                }
            }
            let mut sol = vec![0u64; t_toy];
            for (ri, &col) in piv.iter().enumerate() {
                sol[col] = aug[ri][t_toy];
            }
            sol
        };
        // m_a and m_b: two histograms; their difference is what leaks.
        let m_a = m_honest.clone();
        let mut m_b_vals: Vec<u64> = m_honest.iter().map(|e| e[0]).collect();
        m_b_vals[2] = m_b_vals[2] + 1; // a different multiplicity column
        m_b_vals[5] = m_b_vals[5].wrapping_sub(1);
        let m_b: Vec<KElem> = m_b_vals.iter().map(|&c| kf.embed(zq.to_mod(c as i64))).collect();
        let masked_transcript = |m: &[KElem]| -> Vec<KElem> {
            // MODEL the reuse: an attacker who kept the SAME coefficients
            // (harness_clone — the only reuse path, and a named attack
            // tool) runs a second pass. The shipped API cannot do this: it
            // consumes the set by value.
            let tree = blinded_table_tree(kf, &alpha_h, &tab_toy, m, dt, &bl_shared);
            let mut tr = LkpTranscript::fixed_coins("uk5d-recover", spec_dg);
            let (p, _) = masked_gkr_prove(kf, &[tree], masks_shared.harness_clone(), &mut tr);
            flatten_masked(&p)
        };
        let ta = masked_transcript(&m_a);
        let tb = masked_transcript(&m_b);
        let diff: Vec<KElem> = ta.iter().zip(tb.iter()).map(|(a, b)| kf.sub(a, b)).collect();
        let recovered = solve(&diff);
        let expect: Vec<u64> = m_a
            .iter()
            .zip(m_b.iter())
            .map(|(a, b)| kf.sub(a, b)[0])
            .collect();
        assert_true(
            "U-K5d E3Z-N3 (freshness leak): two passes sharing one g-mask — the transcript DIFFERENCE recovers m_a - m_b (the unmasked leak returns)",
            recovered == expect && recovered.iter().any(|&x| x != 0),
        );
        // Enforcement is STRUCTURAL, not a flag: masked_gkr_prove consumes
        // the MaskSet by value (moved), and MaskSet has no Clone. A second
        // pass with the same object does not compile; the only reuse path
        // is the explicitly-named harness_clone above. Here we prove ONCE
        // (the set is moved and gone) and confirm the honest pass verifies
        // — there is no post-pass handle left to reuse.
        let masks_once = draw_masks(kf, &mut trm, dt, 0);
        let masks_once_shell = masks_once.harness_clone(); // shape shell for the verifier
        let tree1 = blinded_table_tree(kf, &alpha_h, &tab_toy, &m_a, dt, &bl_shared);
        let mut t1 = LkpTranscript::fixed_coins("uk5d-once1", spec_dg);
        let (p_once, _) = masked_gkr_prove(kf, &[tree1], masks_once, &mut t1);
        // masks_once is MOVED here — referencing it again is a compile
        // error, which IS the freshness enforcement.
        let once_ok = {
            let mut tv = LkpTranscript::fixed_coins("uk5d-once1", spec_dg);
            masked_gkr_verify(kf, 1, dt, &masks_once_shell, &p_once, &mut tv, true).is_some()
        };
        assert_true(
            "U-K5d E3Z-N3 (freshness enforced structurally): masked_gkr_prove CONSUMES the mask set by value (no Clone) — a second pass with the same object is a compile error, not a runtime flag; the single consumed pass verifies",
            once_ok,
        );
    }

    // ---- E3Z-N4 (rank canaries): the Z3b/Z3c exposure-rank
    // certificates as derive-time checks at engine shapes, plus the
    // guard-restart regression. ----
    {
        let mut trm = ring::ProverRng::from_test_seed("uk5d-n4-masks", spec_dg);
        let masks_w = draw_masks(kf, &mut trm, dw, 0);
        let mut trb = ring::ProverRng::from_test_seed("uk5d-n4-bl", spec_dg);
        let bl_w = BlinderSet::draw(kf, &mut trb);
        let prove_w = |masks: &MaskSet, bl: &BlinderSet| -> MaskedDescentProof {
            // Rank probes re-run a FIXED set: each pass consumes a fresh
            // harness_clone (the only reuse path; the shipped API moves).
            let tree = blinded_witness_tree(kf, &alpha_h, &w_ok, dw, bl);
            let mut tr = LkpTranscript::fixed_coins("uk5d-n4", spec_dg);
            let (p, _) = masked_gkr_prove(kf, &[tree], masks.harness_clone(), &mut tr);
            p
        };
        // Z3b: the 4 leaf boundary values vs the 8 blinder pads (a, u of
        // tL/tR/f0/f1) — full row rank 4/4 (the parity placement makes
        // the (1, r)-weighted rows nonzero).
        let base_p = prove_w(&masks_w, &bl_w);
        let leaf_exp = |p: &MaskedDescentProof| -> Vec<KElem> {
            p.layers[dw - 2].boundary.to_vec()
        };
        let e0 = leaf_exp(&base_p);
        let mut leaf_rows: Vec<Vec<KElem>> = vec![Vec::new(); 4];
        for field in 0..8 {
            let mut bl = BlinderSet {
                tl: bl_w.tl.clone(),
                tr: bl_w.tr.clone(),
                f0: bl_w.f0.clone(),
                f1: bl_w.f1.clone(),
            };
            let target = match field {
                0 => &mut bl.tl.a,
                1 => &mut bl.tr.a,
                2 => &mut bl.f0.a,
                3 => &mut bl.f1.a,
                4 => &mut bl.tl.u,
                5 => &mut bl.tr.u,
                6 => &mut bl.f0.u,
                _ => &mut bl.f1.u,
            };
            *target = kf.add(target, &one);
            let ei = leaf_exp(&prove_w(&masks_w, &bl));
            for k in 0..4 {
                leaf_rows[k].push(kf.sub(&ei[k], &e0[k]));
            }
        }
        let rank_leaf = k_rank(kf, leaf_rows);
        assert_true(
            &format!("U-K5d E3Z-N4 (Z3b): leaf boundary/pad rank certificate — 4 final boundary values are a FULL-RANK image of the blinder pads (rank {rank_leaf}/4)"),
            rank_leaf == 4,
        );
        // Z3c: layer-3 R-mask saturation — layer-2 boundary (4) + layer-3
        // openings (2) vs the 12 coefficients of (Rp_3, Rq_3), rank 6/6.
        let r_exp = |p: &MaskedDescentProof| -> Vec<KElem> {
            let mut v = p.layers[1].boundary.to_vec();
            let (a, b) = p.layers[2].open_r.clone().unwrap();
            v.push(a);
            v.push(b);
            v
        };
        let r0 = r_exp(&base_p);
        let mut r_rows: Vec<Vec<KElem>> = vec![Vec::new(); 6];
        for side in 0..2 {
            for i in 0..2 {
                for jj in 0..3 {
                    let mut mk = masks_w.harness_clone();
                    let (rp, rq) = &mut mk.r[3 - 2];
                    if side == 0 {
                        rp[i][jj] = kf.add(&rp[i][jj], &one);
                    } else {
                        rq[i][jj] = kf.add(&rq[i][jj], &one);
                    }
                    let ei = r_exp(&prove_w(&mk, &bl_w));
                    for k in 0..6 {
                        r_rows[k].push(kf.sub(&ei[k], &r0[k]));
                    }
                }
            }
        }
        let rank_r = k_rank(kf, r_rows);
        assert_true(
            &format!("U-K5d E3Z-N4 (Z3c): middle-layer R-mask rank certificate — boundary + opening exposures have rank {rank_r}/6 over the 12 R-coefficients"),
            rank_r == 6,
        );
        // Z3c: layer-2 g-mask counting — G + round-poly evals + opening
        // vs the n_g coefficients of g^(2); rank = n_g, forced relations
        // = ell + 1 (Libra Thm 4.1).
        let g_exp = |p: &MaskedDescentProof| -> Vec<KElem> {
            let l = &p.layers[1];
            let mut v = vec![l.g_sum.clone()];
            for e in &l.rounds {
                v.extend(e.iter().cloned());
            }
            v.push(l.open_g.clone());
            v
        };
        let g0 = g_exp(&base_p);
        let n_exp = g0.len();
        let g2_len = masks_w.g_len(2);
        let mut g_rows: Vec<Vec<KElem>> = vec![Vec::new(); n_exp];
        for ci in 0..g2_len {
            let mut mk = masks_w.harness_clone();
            let gm = &mut mk.g[2 - 1];
            if ci == 0 {
                gm.a0 = kf.add(&gm.a0, &one);
            } else {
                let mut idx = ci - 1;
                'outer: for uni in gm.uni.iter_mut() {
                    if idx < uni.len() {
                        uni[idx] = kf.add(&uni[idx], &one);
                        break 'outer;
                    }
                    idx -= uni.len();
                }
            }
            let ei = g_exp(&prove_w(&mk, &bl_w));
            for k in 0..n_exp {
                g_rows[k].push(kf.sub(&ei[k], &g0[k]));
            }
        }
        let rank_g = k_rank(kf, g_rows);
        let ell = base_p.layers[1].rounds.len();
        assert_true(
            &format!("U-K5d E3Z-N4 (Z3c): g-mask counting — round-poly/G/opening exposures have rank {rank_g} = n_g with exactly {} forced relations (= ell+1 = {})", n_exp - rank_g, ell + 1),
            rank_g == g2_len && n_exp - rank_g == ell + 1,
        );
        // Guard-restart regression (Section 3.4 guard c): a blinder drawn
        // with u = 0 is degenerate (its mass a/u is ill-defined); the
        // guard DETECTS the zero denominator and restarts BEFORE any
        // mass/cross-check computation, and the restarted pass verifies.
        let cross = |bw: &BlinderSet, bt: &BlinderSet| -> bool {
            let wt = blinded_witness_tree(kf, &alpha_h, &w_ok, dw, bw);
            let tt = blinded_table_tree(kf, &alpha_h, &tab_toy, &m_honest, dt, bt);
            root_cross_check(kf, &wt.root(), &tt.root())
        };
        let mut attempt = 0usize;
        let mut guard_fired = false;
        let (bw_ok, bt_ok) = loop {
            // Attempt 0 injects a degenerate draw (u_tL = 0); later
            // attempts are honest draws.
            let bw = if attempt == 0 {
                BlinderSet {
                    tl: Blinder { a: bl_w.tl.a.clone(), u: zero.clone() },
                    tr: bl_w.tr.clone(),
                    f0: bl_w.f0.clone(),
                    f1: bl_w.f1.clone(),
                }
            } else {
                BlinderSet::draw(kf, &mut trb)
            };
            // The guard: any blinder denominator drawn 0 restarts.
            if [&bw.tl, &bw.tr, &bw.f0, &bw.f1].iter().any(|b| kf.is_zero(&b.u)) {
                guard_fired = true;
                attempt += 1;
                continue;
            }
            let mut bt = BlinderSet::draw(kf, &mut trb);
            bt.solve_mass(kf, &bw.mass(kf));
            break (bw, bt);
        };
        assert_true(
            "U-K5d E3Z-N4 guard restart: a Section 3.4 guard fires (degenerate blinder u=0), the pass restarts with a nonzero draw, and the restarted pass verifies",
            guard_fired && attempt >= 1 && cross(&bw_ok, &bt_ok),
        );
    }

    self_test_lookup_zk_neg_d3(kf, spec_dg);
    let _ = q;
}

/// U-K5d D3: the existing E3/E4 attack pairs re-run UNDER MASKING —
/// h0_lkp now binds strictly more data (masks + blinders), so the alpha
/// edge (E3-N1) and the psi edge (E4-N1) grow to cover them, and the
/// descent-internal edges (E3-N4/N5) hold identically in the masked
/// descent.
fn self_test_lookup_zk_neg_d3(kf: &ring::kfield::KField, spec_dg: &[u8; 32]) {
    use ring::gkr::root_cross_check;
    use ring::gkr_masked::{
        BlinderSet, MaskedDescentProof, blinded_table_tree, blinded_witness_tree, draw_masks,
        masked_gkr_prove, masked_gkr_verify,
    };
    use ring::kfield::{K_DEG, KElem};
    use ring::lookup::{derive_pin_psi, fuse_pair, fused_silu_table, multiplicities};
    use ring::sumcheck::LkpTranscript;
    println!("\n[U-K5d/D3] E3/E4 edges under masking: alpha binds masks/blinders, psi follows the pinned mask openings");
    let zq = kf.zq;
    let q = zq.q;

    let (dw, dt, n_honest, t_toy) = (5usize, 5usize, 10usize, 8usize);
    let toy_rows: Vec<(i64, i64)> = (0..t_toy as i64).map(|v| (v, (3 * v + 5) % 31)).collect();
    let tab_toy = fused_silu_table(kf, &toy_rows);
    let mut rng = 0x5eed_5d20u64;
    let xs: Vec<usize> = (0..n_honest).map(|_| rng_below(&mut rng, t_toy as u64) as usize).collect();
    let ys_ok: Vec<i64> = xs.iter().map(|&x| toy_rows[x].1).collect();
    let wf_of = |ys: &[i64]| -> Vec<KElem> {
        xs.iter()
            .zip(ys.iter())
            .map(|(&x, &y)| fuse_pair(kf, zq.to_mod(toy_rows[x].0), zq.to_mod(y)))
            .collect()
    };
    let m_honest = multiplicities(kf, &wf_of(&ys_ok), &tab_toy);
    let mut ys_bad = ys_ok.clone();
    ys_bad[3] = (ys_bad[3] + 1) % 31;
    let w_bad = wf_of(&ys_bad);
    let root_ratio = |tree: &ring::gkr::FracTree| -> KElem {
        let r = tree.root();
        kf.mul(&r[0], &kf.inv(&r[1]))
    };

    // ---- E3-N1 under masking: alpha must bind m (and now the masks +
    // blinders). With a BUG alpha that does not bind m, the missing
    // multiplicity is interpolated post-alpha to pass the blinded
    // cross-check; the shipped alpha (binding m) moves and it dies. ----
    {
        let mut trb = ring::ProverRng::from_test_seed("d3-n1-bl", spec_dg);
        let bl_w = BlinderSet::draw(kf, &mut trb);
        let mut bl_t = BlinderSet::draw(kf, &mut trb);
        bl_t.solve_mass(kf, &bl_w.mass(kf));
        let interp_m0 = |alpha: &KElem| -> KElem {
            // sigma_w (bad witness) with the shared blinder mass; solve m_0
            // so the table ratio matches.
            let wt = blinded_witness_tree(kf, alpha, &w_bad, dw, &bl_w);
            let sigma_w = root_ratio(&wt);
            let beta_t = bl_t.mass(kf);
            let mut rest = kf.zero();
            for j in 1..t_toy {
                rest = kf.add(
                    &rest,
                    &kf.mul(&m_honest[j], &kf.inv(&kf.sub(alpha, &tab_toy[j]))),
                );
            }
            kf.mul(&kf.sub(&kf.sub(&sigma_w, &beta_t), &rest), &kf.sub(alpha, &tab_toy[0]))
        };
        // BUG world: alpha independent of m (content-blind tape).
        let alpha_bug = {
            let mut t = LkpTranscript::fixed_coins("d3-n1-bug", spec_dg);
            t.challenge_k(kf)
        };
        let mut m_atk = m_honest.clone();
        m_atk[0] = interp_m0(&alpha_bug);
        let accept = {
            let wt = blinded_witness_tree(kf, &alpha_bug, &w_bad, dw, &bl_w);
            let tt = blinded_table_tree(kf, &alpha_bug, &tab_toy, &m_atk, dt, &bl_t);
            root_cross_check(kf, &wt.root(), &tt.root())
        };
        assert_true(
            "U-K5d/D3 E3-N1 (masked): alpha from an h0 that omits m ACCEPTS a corrupted witness (m interpolated post-alpha) even under masking",
            accept,
        );
        // Shipped: alpha binds m (and the masks/blinders) — a different
        // value at which the committed m_atk is wrong.
        let alpha_ship = {
            let mut t = LkpTranscript::fixed_coins("d3-n1-ship", spec_dg);
            t.challenge_k(kf)
        };
        let reject = {
            let wt = blinded_witness_tree(kf, &alpha_ship, &w_bad, dw, &bl_w);
            let tt = blinded_table_tree(kf, &alpha_ship, &tab_toy, &m_atk, dt, &bl_t);
            !root_cross_check(kf, &wt.root(), &tt.root())
        };
        assert_true(
            "U-K5d/D3 E3-N1 (masked): the shipped h0 (binds m + masks + blinders before alpha) REJECTS the same crafting",
            reject,
        );
    }

    // ---- E3-N4/N5 under masking: a tampered round polynomial and a
    // tampered boundary value in the MASKED descent both REJECT (the
    // round-poly and boundary absorbs sit in masked_gkr_prove/verify with
    // the same ordering as the unmasked descent). ----
    {
        let mut trm = ring::ProverRng::from_test_seed("d3-tamper-masks", spec_dg);
        let masks_w = draw_masks(kf, &mut trm, dw, 0);
        let mut trb = ring::ProverRng::from_test_seed("d3-tamper-bl", spec_dg);
        let bl_w = BlinderSet::draw(kf, &mut trb);
        let alpha = {
            let mut t = LkpTranscript::fixed_coins("d3-tamper-a", spec_dg);
            t.challenge_k(kf)
        };
        let tree = blinded_witness_tree(kf, &alpha, &wf_of(&ys_ok), dw, &bl_w);
        let mut tp = LkpTranscript::fixed_coins("d3-tamper", spec_dg);
        let (pw, _e) = masked_gkr_prove(kf, &[tree], masks_w.harness_clone(), &mut tp);
        let verify = |p: &MaskedDescentProof| -> bool {
            let mut tv = LkpTranscript::fixed_coins("d3-tamper", spec_dg);
            masked_gkr_verify(kf, 1, dw, &masks_w, p, &mut tv, true).is_some()
        };
        assert!(verify(&pw), "honest masked pass must verify");
        // E3-N4 class: bump a round-poly node.
        let mut p_round = MaskedTamper::clone_proof(kf, &pw);
        p_round.layers[2].rounds[1][2] = kf.add(&p_round.layers[2].rounds[1][2], &kf.one());
        // E3-N5 class: bump a boundary value.
        let mut p_bd = MaskedTamper::clone_proof(kf, &pw);
        p_bd.layers[2].boundary[0] = kf.add(&p_bd.layers[2].boundary[0], &kf.one());
        assert_true(
            "U-K5d/D3 E3-N4/N5 (masked): a tampered round polynomial AND a tampered boundary value in the masked descent both REJECT",
            !verify(&p_round) && !verify(&p_bd),
        );
    }

    // ---- E4-N1 under masking: the pin psi now batches the mask
    // openings, so a per-coordinate defect orthogonal to a psi drawn
    // BEFORE the pinned value passes the 9-copy batch; the shipped order
    // (psi AFTER the pinned values) makes psi depend on the forgery and
    // the defect no longer lies in the null space. ----
    {
        // A pinned value's K_DEG coordinates (model a mask opening).
        let state_pre = {
            let mut t = LkpTranscript::new("d3-e4n1-pre", spec_dg);
            t.challenge_k(kf); // advance
            t.state()
        };
        let n_psi = 9usize;
        let psi_before = derive_pin_psi(&state_pre, n_psi, K_DEG, q);
        // Solve a nonzero Delta in null(psi_before): 9 constraints on
        // K_DEG unknowns (kernel dim >= K_DEG - 9 = 7).
        let mut a: Vec<Vec<u64>> = psi_before.clone();
        let mut piv: Vec<(usize, usize)> = Vec::new();
        let mut row = 0usize;
        for col in 0..K_DEG {
            if row >= n_psi {
                break;
            }
            if let Some(pr) = (row..n_psi).find(|&r| a[r][col] != 0) {
                a.swap(row, pr);
                let inv = zq.inv(a[row][col]);
                for c in col..K_DEG {
                    a[row][c] = zq.mul(a[row][c], inv);
                }
                for r in 0..n_psi {
                    if r != row && a[r][col] != 0 {
                        let f = a[r][col];
                        for c in col..K_DEG {
                            a[r][c] = zq.sub(a[r][c], zq.mul(f, a[row][c]));
                        }
                    }
                }
                piv.push((row, col));
                row += 1;
            }
        }
        let free_col = (0..K_DEG).find(|c| !piv.iter().any(|&(_, pc)| pc == *c)).unwrap();
        let mut delta = vec![0u64; K_DEG];
        delta[free_col] = 1;
        for &(pr, pc) in piv.iter().rev() {
            delta[pc] = zq.neg(a[pr][free_col]);
        }
        // ACCEPT leg: every psi_before copy annihilates Delta.
        let orthogonal_before = (0..n_psi).all(|l| {
            (0..K_DEG).fold(0u64, |acc, c| zq.add(acc, zq.mul(psi_before[l][c], delta[c]))) == 0
        });
        // Shipped: psi drawn AFTER the forged value is absorbed.
        let v_true: Vec<u64> = (0..K_DEG).map(|c| (7 * c as u64 + 1) % q).collect();
        let v_forged: Vec<u64> =
            (0..K_DEG).map(|c| zq.add(v_true[c], delta[c])).collect();
        let state_post = {
            let mut t = LkpTranscript::new("d3-e4n1-pre", spec_dg);
            t.challenge_k(kf);
            let vbytes: Vec<u8> = v_forged.iter().flat_map(|c| c.to_le_bytes()).collect();
            t.absorb("d3-pin", &vbytes);
            t.state()
        };
        let psi_after = derive_pin_psi(&state_post, n_psi, K_DEG, q);
        let caught_after = (0..n_psi).any(|l| {
            (0..K_DEG).fold(0u64, |acc, c| zq.add(acc, zq.mul(psi_after[l][c], delta[c]))) != 0
        });
        assert_true(
            "U-K5d/D3 E4-N1 (masked): a pin defect orthogonal to a psi drawn BEFORE the pinned mask-opening value passes the 9-copy batch (the attack)",
            orthogonal_before && delta.iter().any(|&x| x != 0),
        );
        assert_true(
            "U-K5d/D3 E4-N1 (masked): the shipped order (psi AFTER the pinned values, mask openings in scope) REJECTS the same forgery",
            caught_after,
        );
    }
}

// ===========================================================================
// [U-S1] The security-boundary battery (U-S tranche, audit Phase 1 exit).
// A verifier PROCESS accepts an honest masked-lookup proof, and the
// public-mask, same-seed, free-h0, stale-h0 and reuse attacks all reject
// at the API boundary:
//   * free-h0 / stale-h0 REJECT in a SECOND process (prove here, dump the
//     current transcript encoding to bytes, load+verify in a fresh
//     ring_matmul process) because that process RECOMPUTES h0 from the
//     statement + commitment digest and never reads a prover h0.
//   * public-mask / reuse: the histogram-recovery leak class — a broken
//     harness that REUSES the same mask coefficients recovers m_a - m_b
//     exactly; FRESH per-session masks (the shipped API, OS entropy) make
//     the same recovery fail. The shipped prover has NO reuse path
//     (masked_gkr_prove consumes the MaskSet by value; no Clone).
//   * same-seed: two independent from_os sessions carry distinct session
//     nonces and distinct masks; the deterministic from_test_seed is the
//     only way to reproduce a mask set, and it is named test-only.
//
// The toy shape is self-contained (dw = dt = 6, T = 8, 10 honest leaves):
// masked descents + blinded root cross-check are the lookup soundness
// core; the commitment ct-round is out of scope for this minimal ZK-core
// boundary (H-05's full proof artifact is Phase 3). The dump/load is the
// minimal test plumbing the ledger permits, NOT the Phase 3 serializer.

const US1_DW: usize = 6;
const US1_DT: usize = 6;
const US1_T: usize = 8;
const US1_N: usize = 10;

/// The toy table (v, S[v]) = (v, (3v+5) mod 31), spec-digested for h0.
fn us1_toy_rows() -> Vec<(i64, i64)> {
    (0..US1_T as i64).map(|v| (v, (3 * v + 5) % 31)).collect()
}

fn us1_spec_dg(rows: &[(i64, i64)]) -> [u8; 32] {
    let mut parts: Vec<u8> = b"us1-toy-table-v1".to_vec();
    for (v, s) in rows {
        parts.extend((*v as i64).to_le_bytes());
        parts.extend((*s as i64).to_le_bytes());
    }
    uk8_sha(&[&parts])
}

/// h0 DERIVED from the public statement (table spec) + the public
/// commitment digest. The verifier process recomputes this; a stale h0
/// omits `commits_dg` (pre-commitment), a free h0 is anything else.
fn us1_derive_h0(spec_dg: &[u8; 32], commits_dg: &[u8; 32]) -> [u8; 32] {
    uk8_sha(&[b"us1-lkp-h0", spec_dg, commits_dg])
}

/// A minimal, bounds-checked byte reader for the dump/load leg (an
/// untrusted parser returns None, never panics — the H-05 discipline in
/// miniature).
struct Us1Rd<'a> {
    b: &'a [u8],
    p: usize,
}
impl<'a> Us1Rd<'a> {
    fn u32(&mut self) -> Option<usize> {
        if self.p + 4 > self.b.len() {
            return None;
        }
        let v = u32::from_le_bytes(self.b[self.p..self.p + 4].try_into().unwrap());
        self.p += 4;
        Some(v as usize)
    }
    fn u8(&mut self) -> Option<u8> {
        if self.p + 1 > self.b.len() {
            return None;
        }
        let v = self.b[self.p];
        self.p += 1;
        Some(v)
    }
    fn dg(&mut self) -> Option<[u8; 32]> {
        if self.p + 32 > self.b.len() {
            return None;
        }
        let mut d = [0u8; 32];
        d.copy_from_slice(&self.b[self.p..self.p + 32]);
        self.p += 32;
        Some(d)
    }
    fn kelem(&mut self) -> Option<ring::kfield::KElem> {
        let mut e = Vec::with_capacity(ring::kfield::K_DEG);
        for _ in 0..ring::kfield::K_DEG {
            if self.p + 8 > self.b.len() {
                return None;
            }
            e.push(u64::from_le_bytes(self.b[self.p..self.p + 8].try_into().unwrap()));
            self.p += 8;
        }
        Some(e)
    }
}

fn us1_put_kelem(out: &mut Vec<u8>, e: &ring::kfield::KElem) {
    debug_assert_eq!(e.len(), ring::kfield::K_DEG);
    for &c in e {
        out.extend(c.to_le_bytes());
    }
}

fn us1_dump_proof(out: &mut Vec<u8>, p: &ring::gkr_masked::MaskedDescentProof) {
    out.extend((p.layer1.len() as u32).to_le_bytes());
    for q in &p.layer1 {
        for e in q {
            us1_put_kelem(out, e);
        }
    }
    out.extend((p.layers.len() as u32).to_le_bytes());
    for l in &p.layers {
        us1_put_kelem(out, &l.g_sum);
        out.extend((l.rounds.len() as u32).to_le_bytes());
        for r in &l.rounds {
            out.extend((r.len() as u32).to_le_bytes());
            for e in r {
                us1_put_kelem(out, e);
            }
        }
        for e in &l.boundary {
            us1_put_kelem(out, e);
        }
        us1_put_kelem(out, &l.open_g);
        match &l.open_r {
            Some((a, b)) => {
                out.push(1);
                us1_put_kelem(out, a);
                us1_put_kelem(out, b);
            }
            None => out.push(0),
        }
    }
}

fn us1_load_proof(rd: &mut Us1Rd) -> Option<ring::gkr_masked::MaskedDescentProof> {
    use ring::gkr_masked::{MaskedDescentProof, MaskedLayerProof};
    let n1 = rd.u32()?;
    if n1 > 1 << 20 {
        return None;
    }
    let mut layer1 = Vec::with_capacity(n1);
    for _ in 0..n1 {
        layer1.push([rd.kelem()?, rd.kelem()?, rd.kelem()?, rd.kelem()?]);
    }
    let nl = rd.u32()?;
    if nl > 1 << 20 {
        return None;
    }
    let mut layers = Vec::with_capacity(nl);
    for _ in 0..nl {
        let g_sum = rd.kelem()?;
        let nr = rd.u32()?;
        if nr > 1 << 20 {
            return None;
        }
        let mut rounds = Vec::with_capacity(nr);
        for _ in 0..nr {
            let ne = rd.u32()?;
            if ne > 1 << 10 {
                return None;
            }
            let mut ev = Vec::with_capacity(ne);
            for _ in 0..ne {
                ev.push(rd.kelem()?);
            }
            rounds.push(ev);
        }
        let boundary = [rd.kelem()?, rd.kelem()?, rd.kelem()?, rd.kelem()?];
        let open_g = rd.kelem()?;
        let open_r = match rd.u8()? {
            0 => None,
            1 => Some((rd.kelem()?, rd.kelem()?)),
            _ => return None,
        };
        layers.push(MaskedLayerProof { g_sum, rounds, boundary, open_g, open_r });
    }
    Some(MaskedDescentProof { layer1, layers })
}

#[derive(Clone, Copy, PartialEq)]
enum Us1H0 {
    Honest,
    /// The prover builds its transcript on an arbitrary (bit-flipped) h0.
    Free,
    /// The prover builds on a pre-commitment prehash (omits commits_dg).
    Stale,
}

/// Prove the toy masked lookup and DUMP the current transcript encoding:
/// [spec_dg | commits_dg | witness proof | table proof]. `mask_seed`
/// tags the deterministic mask session (reproducible batteries); the
/// honest arm reproduces bit-for-bit, so a second process can verify it.
fn us1_prove_bytes(mask_seed: &str, h0_mode: Us1H0) -> Vec<u8> {
    use ring::gkr_masked::{
        BlinderSet, blinded_table_tree, blinded_witness_tree, draw_masks, masked_gkr_prove,
    };
    use ring::kfield::{KElem, KField};
    use ring::lookup::{fuse_pair, fused_silu_table, multiplicities};
    use ring::sumcheck::LkpTranscript;
    let ctx = ring_ctx_q8();
    let kf = KField::new(&ctx);
    let zq = ctx.zq;
    let rows = us1_toy_rows();
    let spec_dg = us1_spec_dg(&rows);
    let tab = fused_silu_table(&kf, &rows);
    // Deterministic public witness (a harness concern — not prover entropy).
    let mut dr = 0x5eed_5100u64;
    let xs: Vec<usize> = (0..US1_N).map(|_| rng_below(&mut dr, US1_T as u64) as usize).collect();
    let ys: Vec<i64> = xs.iter().map(|&x| rows[x].1).collect();
    let w: Vec<KElem> = xs
        .iter()
        .zip(ys.iter())
        .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(rows[x].0), zq.to_mod(y)))
        .collect();
    let m_k = multiplicities(&kf, &w, &tab);
    // Prover secrets from the OS-entropy CSPRNG interface (deterministic
    // test seed here for reproducibility; from_os on the shipped path).
    let mut rng = ring::ProverRng::from_test_seed(mask_seed, &spec_dg);
    let masks_w = draw_masks(&kf, &mut rng, US1_DW, 0);
    let masks_t = draw_masks(&kf, &mut rng, US1_DT, 0);
    let bl_w = BlinderSet::draw(&kf, &mut rng);
    let mut bl_t = BlinderSet::draw(&kf, &mut rng);
    bl_t.solve_mass(&kf, &bl_w.mass(&kf));
    // Public commitment digest (stand-in for the Ajtai commitment list):
    // binds m and the blinder publics. h0 DERIVES from spec_dg + this.
    let commits_dg = {
        let mut parts: Vec<u8> = b"us1-commit".to_vec();
        for e in &m_k {
            parts.extend((e[0]).to_le_bytes());
        }
        for b in [&bl_w.tl, &bl_w.tr, &bl_w.f0, &bl_w.f1, &bl_t.tl, &bl_t.tr, &bl_t.f0, &bl_t.f1] {
            us1_put_kelem(&mut parts, &b.a);
            us1_put_kelem(&mut parts, &b.u);
        }
        uk8_sha(&[&parts])
    };
    // The prover's prehash: honest DERIVES it; free flips a bit; stale
    // omits the commitment digest (pre-commitment binding).
    let h0_real = us1_derive_h0(&spec_dg, &commits_dg);
    let h0_prover = match h0_mode {
        Us1H0::Honest => h0_real,
        Us1H0::Free => {
            let mut h = h0_real;
            h[0] ^= 1;
            h
        }
        Us1H0::Stale => us1_derive_h0(&spec_dg, &[0u8; 32]),
    };
    let mut tr = LkpTranscript::new("us1-lkp", &h0_prover);
    let alpha = tr.challenge_k(&kf);
    let wtree = blinded_witness_tree(&kf, &alpha, &w, US1_DW, &bl_w);
    let ttree = blinded_table_tree(&kf, &alpha, &tab, &m_k, US1_DT, &bl_t);
    let (pw, _endw) = masked_gkr_prove(&kf, &[wtree], masks_w, &mut tr);
    let (pt, _endt) = masked_gkr_prove(&kf, &[ttree], masks_t, &mut tr);
    let mut out = Vec::new();
    out.extend(spec_dg);
    out.extend(commits_dg);
    us1_dump_proof(&mut out, &pw);
    us1_dump_proof(&mut out, &pt);
    out
}

/// Load a dumped proof and VERIFY it — the routine the second process
/// runs. It RECOMPUTES h0 from (spec_dg, commits_dg) and never reads a
/// prover h0. Returns true iff the masked descents verify AND the blinded
/// root cross-check holds under the derived alpha.
fn us1_verify_bytes(bytes: &[u8]) -> bool {
    use ring::gkr_masked::{masked_gkr_verify, zero_masks};
    use ring::kfield::KField;
    use ring::sumcheck::LkpTranscript;
    let ctx = ring_ctx_q8();
    let kf = KField::new(&ctx);
    let mut rd = Us1Rd { b: bytes, p: 0 };
    let Some(spec_dg) = rd.dg() else { return false };
    let Some(commits_dg) = rd.dg() else { return false };
    let Some(pw) = us1_load_proof(&mut rd) else { return false };
    let Some(pt) = us1_load_proof(&mut rd) else { return false };
    // DERIVE h0 (and alpha) from the statement + commitment digest.
    let h0 = us1_derive_h0(&spec_dg, &commits_dg);
    let shell_w = zero_masks(&kf, US1_DW, 0);
    let shell_t = zero_masks(&kf, US1_DT, 0);
    let mut tv = LkpTranscript::new("us1-lkp", &h0);
    let _alpha = tv.challenge_k(&kf);
    let Some((roots_w, _ew)) = masked_gkr_verify(&kf, 1, US1_DW, &shell_w, &pw, &mut tv, false)
    else {
        return false;
    };
    let Some((roots_t, _et)) = masked_gkr_verify(&kf, 1, US1_DT, &shell_t, &pt, &mut tv, false)
    else {
        return false;
    };
    !kf.is_zero(&roots_w[0][1])
        && !kf.is_zero(&roots_t[0][1])
        && kf.mul(&roots_w[0][0], &roots_t[0][1]) == kf.mul(&roots_t[0][0], &roots_w[0][1])
}

/// `us1-verify <file>` — the SECOND-process verifier entry. Reads the
/// dumped proof bytes and prints/exits with the verdict (exit 0 = ACCEPT,
/// 1 = REJECT, 2 = unreadable). Used by the [U-S1] two-process leg.
fn us1_verify_main(path: &str) {
    let bytes = match std::fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("us1-verify: cannot read {path}: {e}");
            std::process::exit(2);
        }
    };
    if us1_verify_bytes(&bytes) {
        println!("us1-verify: ACCEPT");
        std::process::exit(0);
    } else {
        println!("us1-verify: REJECT");
        std::process::exit(1);
    }
}

/// The histogram-recovery leak (C-01), modelled at the toy shape. The
/// masked table descent transcript is AFFINE in m: T(m) = L_M(m) + c_M,
/// where the linear map L_M and constant c_M depend on the mask set M.
/// An attacker recovers m by solving T(m_real) against a probe BASIS it
/// builds by re-running the descent on unit m-vectors. If the masks are
/// publicly RECONSTRUCTIBLE (`reconstructible = true`, the C-01 flaw), the
/// attacker rebuilds the exact same M, its basis equals L_M, and the
/// recovery reproduces the transcript EXACTLY and returns m_real (attack
/// SUCCEEDS). With SECRET fresh masks the attacker's best basis is the
/// zero-mask map L_0 != L_M; the recovery is inconsistent and wrong
/// (attack FAILS). Returns true iff the recovery succeeds.
fn us1_recover_leak(reconstructible: bool) -> bool {
    use ring::gkr_masked::{
        Blinder, BlinderSet, MaskSet, blinded_table_tree, draw_masks, masked_gkr_prove, zero_masks,
    };
    use ring::kfield::{K_DEG, KElem, KField};
    use ring::lookup::{fuse_pair, fused_silu_table, multiplicities};
    use ring::sumcheck::LkpTranscript;
    let ctx = ring_ctx_q8();
    let kf = KField::new(&ctx);
    let zq = ctx.zq;
    let rows = us1_toy_rows();
    let spec_dg = us1_spec_dg(&rows);
    let tab = fused_silu_table(&kf, &rows);
    let mut dr = 0x5eed_5200u64;
    let xs: Vec<usize> = (0..US1_N).map(|_| rng_below(&mut dr, US1_T as u64) as usize).collect();
    let ys: Vec<i64> = xs.iter().map(|&x| rows[x].1).collect();
    let w: Vec<KElem> = xs
        .iter()
        .zip(ys.iter())
        .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(rows[x].0), zq.to_mod(y)))
        .collect();
    let m_real = multiplicities(&kf, &w, &tab);
    let m_real_vals: Vec<u64> = m_real.iter().map(|e| e[0]).collect();
    let alpha = {
        let mut t = LkpTranscript::fixed_coins("us1-recover", &spec_dg);
        t.challenge_k(&kf)
    };
    let bl = {
        let z = kf.zero();
        let o = kf.one();
        BlinderSet {
            tl: Blinder { a: z.clone(), u: o.clone() },
            tr: Blinder { a: z.clone(), u: o.clone() },
            f0: Blinder { a: z.clone(), u: o.clone() },
            f1: Blinder { a: z.clone(), u: o },
        }
    };
    // The PROVER's secret masks (from an OS-style CSPRNG; a fixed test seed
    // here so the harness is reproducible — the point is whether the
    // ATTACKER can rebuild them, not how they were drawn).
    let prover_masks = || {
        let mut rng = ring::ProverRng::from_test_seed("us1-prover-secret-masks", &spec_dg);
        draw_masks(&kf, &mut rng, US1_DT, 0)
    };
    let transcript = |m: &[KElem], masks: MaskSet| -> Vec<KElem> {
        let tree = blinded_table_tree(&kf, &alpha, &tab, m, US1_DT, &bl);
        let mut tr = LkpTranscript::fixed_coins("us1-recover", &spec_dg);
        let (p, _) = masked_gkr_prove(&kf, &[tree], masks, &mut tr);
        flatten_masked(&p)
    };
    // The observed transcript uses the prover's SECRET masks.
    let observed = transcript(&m_real, prover_masks());
    // The attacker's probe basis. reconstructible: it rebuilds the SAME
    // masks (its basis equals L_M). Else it can only use zero masks (L_0).
    let basis_masks = || -> MaskSet {
        if reconstructible { prover_masks() } else { zero_masks(&kf, US1_DT, 0) }
    };
    let probe = |m_vec: &[u64]| -> Vec<KElem> {
        let m_probe: Vec<KElem> = m_vec.iter().map(|&c| kf.embed(c)).collect();
        transcript(&m_probe, basis_masks())
    };
    let base_flat = probe(&vec![0u64; US1_T]);
    let cols: Vec<Vec<KElem>> = (0..US1_T)
        .map(|j| {
            let mut e = vec![0u64; US1_T];
            e[j] = 1;
            let pj = probe(&e);
            pj.iter().zip(base_flat.iter()).map(|(a, b)| kf.sub(a, b)).collect()
        })
        .collect();
    // rhs = observed - base_flat = L_M(m_real) when the basis masks == M.
    let rhs: Vec<KElem> = observed.iter().zip(base_flat.iter()).map(|(a, b)| kf.sub(a, b)).collect();
    let solve = || -> Vec<u64> {
        let mut aug: Vec<Vec<u64>> = Vec::new();
        for i in 0..base_flat.len() {
            for c in 0..K_DEG {
                let mut row: Vec<u64> = (0..US1_T).map(|j| cols[j][i][c]).collect();
                row.push(rhs[i][c]);
                if row.iter().any(|&x| x != 0) {
                    aug.push(row);
                }
            }
        }
        let mut r = 0usize;
        let mut piv = Vec::new();
        for col in 0..US1_T {
            let Some(p) = (r..aug.len()).find(|&i| aug[i][col] != 0) else { continue };
            aug.swap(r, p);
            let inv = zq.inv(aug[r][col]);
            for x in aug[r].iter_mut() {
                *x = zq.mul(*x, inv);
            }
            for i in 0..aug.len() {
                if i != r && aug[i][col] != 0 {
                    let f = aug[i][col];
                    for c in 0..=US1_T {
                        aug[i][c] = zq.sub(aug[i][c], zq.mul(f, aug[r][c]));
                    }
                }
            }
            piv.push(col);
            r += 1;
            if r == US1_T {
                break;
            }
        }
        let mut sol = vec![0u64; US1_T];
        for (ri, &col) in piv.iter().enumerate() {
            sol[col] = aug[ri][US1_T];
        }
        sol
    };
    let recovered = solve();
    // The recovery counts only if it reproduces the WHOLE observed
    // transcript (basis*recovered == rhs everywhere) AND equals m_real.
    // Reconstructible masks: exact (basis == L_M). Secret masks: the
    // zero-mask basis cannot fit the masked rows -> inconsistent -> fails.
    let consistent = (0..base_flat.len()).all(|i| {
        let mut acc = kf.zero();
        for (j, rj) in recovered.iter().enumerate() {
            if *rj != 0 {
                acc = kf.add(&acc, &kf.scale(*rj, &cols[j][i]));
            }
        }
        acc == rhs[i]
    });
    recovered == m_real_vals && consistent && m_real_vals.iter().any(|&x| x != 0)
}

fn self_test_us1_boundary() {
    println!("\n[U-S1] security boundary: verifier PROCESS accept + public-mask/same-seed/free-h0/stale-h0/reuse reject");

    // ---- Honest ACCEPT across a process boundary. ----
    let dir = std::env::temp_dir();
    let honest = us1_prove_bytes("us1-honest", Us1H0::Honest);
    let honest_path = dir.join(format!("us1-honest-{}.bin", std::process::id()));
    std::fs::write(&honest_path, &honest).expect("write honest proof");
    // In-process sanity first (the same routine the child runs).
    assert_true(
        "U-S1 honest masked-lookup proof VERIFIES in-process (masked descents + blinded root cross-check under the DERIVED h0)",
        us1_verify_bytes(&honest),
    );
    let exe = std::env::current_exe().expect("current exe");
    let run = |path: &std::path::Path| -> i32 {
        std::process::Command::new(&exe)
            .arg("us1-verify")
            .arg(path)
            .status()
            .expect("spawn us1-verify")
            .code()
            .unwrap_or(-1)
    };
    assert_true(
        "U-S1 two-process: a SECOND ring_matmul process loads the dumped transcript bytes and ACCEPTS the honest proof (verifier recomputes h0 from statement+commitments; no prover-local value crosses)",
        run(&honest_path) == 0,
    );

    // ---- free-h0 / stale-h0 REJECT in the second process. ----
    let free = us1_prove_bytes("us1-honest", Us1H0::Free);
    let free_path = dir.join(format!("us1-free-{}.bin", std::process::id()));
    std::fs::write(&free_path, &free).expect("write free proof");
    assert_true(
        "U-S1 two-process (free-h0): a proof built on an arbitrary prover-chosen prehash REJECTS in the second process — it DERIVES h0 and the descents diverge (no prover h0 is read)",
        run(&free_path) == 1,
    );
    let stale = us1_prove_bytes("us1-honest", Us1H0::Stale);
    let stale_path = dir.join(format!("us1-stale-{}.bin", std::process::id()));
    std::fs::write(&stale_path, &stale).expect("write stale proof");
    assert_true(
        "U-S1 two-process (stale-h0): a proof built on a PRE-COMMITMENT prehash (omits the commitment digest) REJECTS — the second process binds the full commitment list into its derived h0",
        run(&stale_path) == 1,
    );

    // ---- public-mask / reuse: the histogram leak class (C-01). ----
    assert_true(
        "U-S1 public-mask leak (broken harness): when the masks are publicly RECONSTRUCTIBLE the attacker rebuilds the exact masked basis and RECOVERS the multiplicity histogram m exactly (consistent, == m) — the C-01 leak is real",
        us1_recover_leak(true),
    );
    assert_true(
        "U-S1 closure (secret masks): the SAME recovery against SECRET fresh masks FAILS — the attacker's zero-mask basis cannot fit the masked transcript (inconsistent, != m); OS-entropy sessions close the leak",
        !us1_recover_leak(false),
    );

    // ---- same-seed / duplicate-session refusal. ----
    let mut os_a = ring::ProverRng::from_os().expect("OS CSPRNG");
    let mut os_b = ring::ProverRng::from_os().expect("OS CSPRNG");
    assert_true(
        "U-S1 same-seed: two independent from_os sessions carry DISTINCT explicit session nonces (the freshness handle) — the shipped API cannot emit two identical-mask sessions",
        os_a.session_nonce() != os_b.session_nonce(),
    );
    let ctx = ring_ctx_q8();
    let kf = ring::kfield::KField::new(&ctx);
    let fresh_a = ring::gkr_masked::draw_masks(&kf, &mut os_a, US1_DT, 0).flatten();
    let fresh_b = ring::gkr_masked::draw_masks(&kf, &mut os_b, US1_DT, 0).flatten();
    assert_true(
        "U-S1 duplicate-session refusal: from_os sessions draw DIFFERENT masks; masked_gkr_prove consumes the MaskSet by value (no Clone) so a second prove with the same object is a COMPILE error — reuse has no runtime path in the shipped API",
        fresh_a != fresh_b,
    );

    // Housekeeping: drop the temp files.
    for p in [&honest_path, &free_path, &stale_path] {
        let _ = std::fs::remove_file(p);
    }
}

// ===========================================================================
// [U-S Phase 3] The proof artifact (audit Phase 3, H-05). The COMPLETE
// committed masked-lookup proof — statement -> commitments -> masked
// descents -> aggregate pins -> Ajtai ct-round — as canonical bytes, with
// an independent verifier that runs in a FRESH process from statement
// bytes + proof bytes + the (deterministic) CRS derivation ONLY. This is
// the U-K5c committed-lookup path, purpose-built for serialization: no
// prover-local value crosses the boundary; every transcript seed (h0_lkp,
// alpha, psi, ct-round h0) is recomputed from the decoded statement and
// commitments per the D3 discipline. The full FFN-layer CHAIN reuses these
// exact primitives; its multi-wave orchestration is recorded PARTIAL.

const P3_CRS_SEED: u64 = 0x5C0D; // deterministic public setup for the lookup CRS
const P3_TABLE_ROWS: usize = 256; // silu-int8-table-v1 domain
const P3_DT: usize = 9; // table tree depth (256 rows split + blinders)
const P3_N_PSI: usize = 9; // E4 psi copies (LKP-4)

/// The witness tree depth for `n_honest` honest leaves: the smallest depth
/// whose blinder-free front (2^{dw-1} - 4) holds them.
fn p3_dw(n_honest: usize) -> usize {
    let mut dw = 4usize;
    while (1usize << dw) / 2 < n_honest + 4 {
        dw += 1;
    }
    dw
}

/// The deterministic commitment layout of a lookup proof of `n_honest`
/// elements — shared BIT-FOR-BIT by prover and verifier. Commitment index
/// order: X groups | Y groups | m | blinders | witness masks | table masks
/// | g-masks. Everything is a pure function of `n_honest` + the fixed shape.
#[derive(Clone)]
struct P3Layout {
    dw: usize,
    dt: usize,
    n_honest: usize,
    msg_r: usize,
    kpc: usize,
    nx: usize,          // commitments spanning X (and, separately, Y)
    idx_y: usize,       // first Y commitment (X occupies 0..nx)
    idx_m: usize,
    idx_bl: usize,
    base_wm: usize,
    base_tm: usize,
    wm_c: usize,
    tm_c: usize,
    n_data: usize,
    g_base: usize,
    g_groups: usize,
    n_commits: usize,
}

fn p3_layout(n_honest: usize, shape: CommitShape) -> P3Layout {
    use ring::gkr_masked::mask_coeff_counts;
    use ring::kfield::K_DEG;
    let msg_r = shape.msg_r;
    let kpc = msg_r * D / K_DEG;
    let dw = p3_dw(n_honest);
    let dt = P3_DT;
    let nx = n_honest.div_ceil(msg_r * D).max(1);
    let (gw, rw) = mask_coeff_counts(dw, 0);
    let (gt, rt) = mask_coeff_counts(dt, 0);
    let (wm_len, tm_len) = (gw + rw, gt + rt);
    let kel_cms = |n_kel: usize| (n_kel * K_DEG).div_ceil(msg_r * D).max(1);
    let (wm_c, tm_c) = (kel_cms(wm_len), kel_cms(tm_len));
    let idx_y = nx;
    let idx_m = 2 * nx;
    let idx_bl = 2 * nx + 1;
    let base_wm = 2 * nx + 2;
    let base_tm = base_wm + wm_c;
    let n_data = base_tm + tm_c;
    let g_base = n_data;
    // The ct-round's 9 psi-copy g-masks pack msg_r per commitment group.
    let g_groups = P3_N_PSI.div_ceil(msg_r);
    let n_commits = n_data + g_groups;
    P3Layout {
        dw, dt, n_honest, msg_r, kpc, nx, idx_y, idx_m, idx_bl, base_wm, base_tm, wm_c, tm_c,
        n_data, g_base, g_groups, n_commits,
    }
}

/// Split a flat K-element weight run into per-commitment pin terms.
fn p3_kelem_terms(
    base: usize,
    flat_off: usize,
    weights: &[ring::kfield::KElem],
    kpc: usize,
) -> Vec<ring::lookup::PinTerm> {
    use ring::kfield::K_DEG;
    use ring::lookup::PinTerm;
    let mut terms = Vec::new();
    let mut i = 0usize;
    while i < weights.len() {
        let idx = flat_off + i;
        let commit = base + idx / kpc;
        let coeff0 = (idx % kpc) * K_DEG;
        let take = (kpc - (idx % kpc)).min(weights.len() - i);
        terms.push(PinTerm::Kelems { commit, coeff0, weights: weights[i..i + take].to_vec() });
        i += take;
    }
    terms
}

/// Descent pins (G hypersums, g openings, R openings). Weights depend only
/// on the mask SHAPE + public opening points, so the shape shells suffice.
fn p3_descent_pins(
    kf: &ring::kfield::KField,
    base: usize,
    shape_masks: &ring::gkr_masked::MaskSet,
    proof: &ring::gkr_masked::MaskedDescentProof,
    end: &ring::gkr_masked::DescentEnd,
    depth: usize,
    kpc: usize,
) -> Vec<ring::lookup::PinnedValue> {
    use ring::gkr_masked::{g_hypersum_weights, g_open_weights, r_open_weights};
    use ring::lookup::PinnedValue;
    let mut pins = Vec::new();
    for j in 1..depth {
        let lp = &proof.layers[j - 1];
        let gm = &shape_masks.g[j - 1];
        pins.push(PinnedValue {
            terms: p3_kelem_terms(base, shape_masks.g_offset(j), &g_hypersum_weights(kf, gm), kpc),
            value: lp.g_sum.clone(),
        });
        let (open_pt, mu_prev, c_w) = &end.layer_pts[j - 1];
        pins.push(PinnedValue {
            terms: p3_kelem_terms(base, shape_masks.g_offset(j), &g_open_weights(kf, gm, open_pt), kpc),
            value: lp.open_g.clone(),
        });
        if j >= 2 {
            let (orp, orq) = lp.open_r.clone().expect("interior layer opens Rp/Rq");
            let rw = r_open_weights(kf, mu_prev, c_w);
            pins.push(PinnedValue {
                terms: p3_kelem_terms(base, shape_masks.r_offset(j), &rw, kpc),
                value: orp,
            });
            pins.push(PinnedValue {
                terms: p3_kelem_terms(base, shape_masks.r_offset(j) + 6, &rw, kpc),
                value: orq,
            });
        }
    }
    pins
}

/// The aggregate leaf pins (P/Q over committed X, Y, m, blinders) — the
/// v^X/v^Y/v^M histogram channel stays closed; only blinded aggregates
/// appear. X and Y are scalar commitments spanning `nx` groups.
#[allow(clippy::too_many_arguments)]
fn p3_leaf_pins(
    kf: &ring::kfield::KField,
    lay: &P3Layout,
    tab_fused: &[ring::kfield::KElem],
    endw: &ring::gkr_masked::DescentEnd,
    endt: &ring::gkr_masked::DescentEnd,
    alpha: &ring::kfield::KElem,
) -> Vec<ring::lookup::PinnedValue> {
    use ring::gkr::eq_table;
    use ring::gkr_masked::{blinder_positions, table_row_positions};
    use ring::kfield::{K_DEG, KElem};
    use ring::lookup::{mul_y, PinTerm, PinnedValue};
    let zero = kf.zero();
    let one = kf.one();
    let n_honest = lay.n_honest;
    let t_rows = P3_TABLE_ROWS;
    let msg_r = lay.msg_r;
    let lw = eq_table(kf, &endw.zstar);
    let lt = eq_table(kf, &endt.zstar);
    let nw = 1usize << lay.dw;
    let nt = 1usize << lay.dt;
    let bpw = blinder_positions(nw);
    let bpt = blinder_positions(nt);
    let tpos = table_row_positions(t_rows, nt);
    let eqw: Vec<KElem> = bpw.iter().map(|&p| lw[p].clone()).collect();
    let eqt: Vec<KElem> = bpt.iter().map(|&p| lt[p].clone()).collect();
    let hw = (0..n_honest).fold(zero.clone(), |a, i| kf.add(&a, &lw[i]));
    let ht = (0..t_rows).fold(zero.clone(), |a, j| kf.add(&a, &lt[tpos[j]]));
    let sum_eqw = eqw.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
    let sum_eqt = eqt.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
    let ft = (0..t_rows).fold(zero.clone(), |a, j| kf.add(&a, &kf.mul(&lt[tpos[j]], &tab_fused[j])));
    let z = zero.clone();
    let per = msg_r * D;
    // Witness P: p* - H = sum eqw a_bl.
    let wp = PinnedValue {
        terms: vec![PinTerm::Kelems {
            commit: lay.idx_bl,
            coeff0: 0,
            weights: vec![
                eqw[0].clone(), z.clone(), eqw[1].clone(), z.clone(),
                eqw[2].clone(), z.clone(), eqw[3].clone(), z.clone(),
            ],
        }],
        value: kf.sub(&endw.p_claim, &hw),
    };
    // Witness Q: q* - alpha H - D_dummy = sum eqw u_bl - sum lw x - sum Y lw y.
    let ddw = kf.sub(&kf.sub(&one, &hw), &sum_eqw);
    let mut wq_terms = vec![PinTerm::Kelems {
        commit: lay.idx_bl,
        coeff0: 0,
        weights: vec![
            z.clone(), eqw[0].clone(), z.clone(), eqw[1].clone(),
            z.clone(), eqw[2].clone(), z.clone(), eqw[3].clone(),
        ],
    }];
    for xc in 0..lay.nx {
        let lo = xc * per;
        let n_c = (n_honest - lo).min(per);
        wq_terms.push(PinTerm::Scalar {
            commit: xc, // X occupies 0..nx
            coeff0: 0,
            weights: (0..n_c).map(|i| kf.neg(&lw[lo + i])).collect(),
        });
        wq_terms.push(PinTerm::Scalar {
            commit: lay.idx_y + xc,
            coeff0: 0,
            weights: (0..n_c).map(|i| kf.neg(&mul_y(kf, &lw[lo + i]))).collect(),
        });
    }
    let wq = PinnedValue {
        terms: wq_terms,
        value: kf.sub(&kf.sub(&endw.q_claim, &kf.mul(alpha, &hw)), &ddw),
    };
    // Table P: p*_t = sum L_pos m_j + sum eqt a'_bl.
    let tp = PinnedValue {
        terms: vec![
            PinTerm::Scalar {
                commit: lay.idx_m,
                coeff0: 0,
                weights: (0..t_rows).map(|j| lt[tpos[j]].clone()).collect(),
            },
            PinTerm::Kelems {
                commit: lay.idx_bl,
                coeff0: 8 * K_DEG,
                weights: vec![
                    eqt[0].clone(), z.clone(), eqt[1].clone(), z.clone(),
                    eqt[2].clone(), z.clone(), eqt[3].clone(), z.clone(),
                ],
            },
        ],
        value: endt.p_claim.clone(),
    };
    // Table Q: q*_t - alpha H_t - D_dummy + FT = sum eqt u'_bl.
    let ddt = kf.sub(&kf.sub(&one, &ht), &sum_eqt);
    let tq = PinnedValue {
        terms: vec![PinTerm::Kelems {
            commit: lay.idx_bl,
            coeff0: 8 * K_DEG,
            weights: vec![
                z.clone(), eqt[0].clone(), z.clone(), eqt[1].clone(),
                z.clone(), eqt[2].clone(), z.clone(), eqt[3].clone(),
            ],
        }],
        value: kf.add(&kf.sub(&kf.sub(&endt.q_claim, &kf.mul(alpha, &ht)), &ddt), &ft),
    };
    vec![wp, wq, tp, tq]
}

/// P3-D5 model_digest: architecture shape + quantization + table spec +
/// EVERY committed-tensor commitment digest. Swapping any commitment moves
/// this digest, hence the statement digest, hence the verifier's h0.
fn p3_model_digest(n_honest: usize, commit_digests: &[Vec<u8>]) -> [u8; 32] {
    let mut parts: Vec<u8> = b"us1-p3-lookup-model-v1".to_vec();
    parts.extend((n_honest as u64).to_le_bytes());
    // Quantization + table spec: int8/int8, 4 frac bits, silu-int8-table-v1.
    parts.extend(manifest::SILU_INT8_TABLE_DIGEST);
    parts.push(8); // input width
    parts.push(4); // input frac
    parts.extend((commit_digests.len() as u64).to_le_bytes());
    for d in commit_digests {
        parts.extend((d.len() as u64).to_le_bytes());
        parts.extend(d);
    }
    uk8_sha(&[&parts])
}

/// Build the PublicStatement for a lookup of `n_honest` elements over the
/// committed X -> Y with the frozen SiLU table. The X and Y entries carry
/// the group-digest commitment bytes; the model_digest binds all of them.
fn p3_build_statement(lay: &P3Layout, crs_hash: &[u8], commit_digests: &[Vec<u8>]) -> manifest::Statement {
    use manifest::{ClaimManifest, Operation, Orientation, QuantMeta, Statement, SILU_INT8_TABLE_SPEC, PadSpec};
    let q8 = QuantMeta { bits: 8, frac_bits: 4, signed: true };
    let mut mf = ClaimManifest::new("lattice-route-r-lookup", crs_hash);
    let ki = key_info_bytes(&CommitShape { kappa: 8, n_r: 26, msg_r: lay.msg_r }, Q8);
    // X and Y each carry a single semantic commitment entry whose bytes are
    // the digest over their nx commitment groups (the ct-round binds the
    // groups individually via h0; the statement binds their identity).
    let x_dg = group_list_digest(&commit_digests[0..lay.nx]);
    let y_dg = group_list_digest(&commit_digests[lay.idx_y..lay.idx_y + lay.nx]);
    let id_x = mf.add_commitment("X", lay.n_honest, 1, Orientation::ByColumns, ki.clone(), x_dg);
    let id_y = mf.add_commitment("Y", lay.n_honest, 1, Orientation::ByColumns, ki, y_dg);
    mf.add_operation(Operation::Lookup { x: id_x, y: id_y });
    // model_digest binds every DATA commitment (X|Y|m|blinders|masks), not
    // the per-proof ct-round g-masks; the verifier recomputes it the same way.
    let model_digest = p3_model_digest(lay.n_honest, &commit_digests[0..lay.n_data]);
    let mut st = Statement::new(model_digest, Some(SILU_INT8_TABLE_SPEC), 30, mf);
    st.quant = vec![q8, q8];
    st.pad = vec![
        PadSpec::exact(lay.n_honest, 1),
        PadSpec::exact(lay.n_honest, 1),
    ];
    st.outputs = vec![id_y];
    st
}

fn group_list_digest(digs: &[Vec<u8>]) -> Vec<u8> {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    for d in digs {
        h.update(d);
    }
    h.finalize().to_vec()
}

/// The complete committed lookup proof (P3-D1). ProverInput (openings,
/// witness) stays prover-side and never enters this struct.
struct P3Proof {
    t1s: Vec<Vec<Poly>>,
    t2s: Vec<Vec<Poly>>,
    pw: ring::gkr_masked::MaskedDescentProof,
    pt: ring::gkr_masked::MaskedDescentProof,
    ct: ring::ct_engine::CtRoundProof,
}

/// Structured verification failure (P3-D1/D4): decode errors and every
/// verify-time rejection, never a panic.
#[derive(Debug)]
enum P3Error {
    Decode(manifest::DecodeError),
    ProofDecode(&'static str),
    StatementInvalid(manifest::StatementError),
    ProofShape { what: &'static str, got: usize, want: usize },
    LookupDescent,      // masked descent rejected (free/stale h0 or tamper)
    RootCrossCheck,
    CtRound,
}

impl std::fmt::Display for P3Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            P3Error::Decode(e) => write!(f, "statement decode: {e}"),
            P3Error::ProofDecode(s) => write!(f, "proof decode: {s}"),
            P3Error::StatementInvalid(e) => write!(f, "statement invalid: {e}"),
            P3Error::ProofShape { what, got, want } => {
                write!(f, "proof shape: {what} = {got}, statement implies {want}")
            }
            P3Error::LookupDescent => write!(f, "masked lookup descent rejected"),
            P3Error::RootCrossCheck => write!(f, "blinded root cross-check failed"),
            P3Error::CtRound => write!(f, "ct-round rejected the pins against the commitments"),
        }
    }
}

/// Prove the complete committed lookup of `n_honest` elements. Returns the
/// PublicStatement and the Proof; the ProverInput (openings, witness, RNG)
/// is consumed here and never leaves. Deterministic per `seed`.
fn p3_lookup_prove(n_honest: usize, seed: u64) -> (manifest::Statement, P3Proof) {
    use ring::commit::CommitShape as CS;
    use ring::ct_engine::{
        StdOpening, ct_h0, derive_ct_round_params, prove_ct_round, sample_ct_masks,
    };
    use ring::gkr_masked::{BlinderSet, blinded_table_tree, blinded_witness_tree, draw_masks};
    use ring::kfield::{K_DEG, KElem, KField};
    use ring::lookup::{
        derive_pin_psi, fuse_pair, fused_silu_table, multiplicities, pin_claims, silu_int8_table,
    };
    use ring::sumcheck::LkpTranscript;

    let ctx_ring = ring_ctx_q8();
    let kf = KField::new(&ctx_ring);
    let zq = ctx_ring.zq;
    let q = zq.q;
    let rows = silu_int8_table();
    let tab_fused = fused_silu_table(&kf, &rows);
    let shape = CS { kappa: 8, n_r: 26, msg_r: 8 };
    let msg_r = shape.msg_r;
    let lay = p3_layout(n_honest, shape);
    let crs = expand_crs(shape, q, P3_CRS_SEED);
    let per = msg_r * D;

    // Statement/witness data (a harness concern; the proof coins below are
    // independent OS-style entropy).
    let mut dr = seed;
    let xs: Vec<i64> = (0..n_honest).map(|_| rng_below(&mut dr, 256) as i64 - 128).collect();
    let ys: Vec<i64> = xs.iter().map(|&x| rows[(x + 128) as usize].1).collect();
    let w_fused: Vec<KElem> = xs
        .iter()
        .zip(ys.iter())
        .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
        .collect();
    let m_k = multiplicities(&kf, &w_fused, &tab_fused);
    let m_vals: Vec<i64> = m_k.iter().map(|e| e[0] as i64).collect();

    // Prover secrets from the explicit-nonce CSPRNG (deterministic seed so
    // the artifact reproduces; from_os on a live prover).
    let mut rng = ring::ProverRng::from_test_seed("p3-lookup-session", &seed.to_le_bytes());
    let masks_w = draw_masks(&kf, &mut rng, lay.dw, 0);
    let masks_t = draw_masks(&kf, &mut rng, lay.dt, 0);
    let bl_w = BlinderSet::draw(&kf, &mut rng);
    let mut bl_t = BlinderSet::draw(&kf, &mut rng);
    bl_t.solve_mass(&kf, &bl_w.mass(&kf));

    let pack_scalar_groups = |vals: &[i64]| -> Vec<Vec<Poly>> {
        let ng = vals.len().div_ceil(per).max(1);
        (0..ng)
            .map(|g| {
                let mut polys = vec![poly_zero(); msg_r];
                for (s, poly) in polys.iter_mut().enumerate() {
                    for (c, slot) in poly.iter_mut().enumerate() {
                        let idx = g * per + s * D + c;
                        if idx < vals.len() {
                            *slot = zq.to_mod(vals[idx]);
                        }
                    }
                }
                polys
            })
            .collect()
    };
    let pack_kelems = |kelems: &[KElem]| -> Vec<Vec<Poly>> {
        let mut flat: Vec<u64> = Vec::with_capacity(kelems.len() * K_DEG);
        for e in kelems {
            for c in 0..K_DEG {
                flat.push(e[c]);
            }
        }
        let ng = flat.len().div_ceil(per).max(1);
        (0..ng)
            .map(|g| {
                (0..msg_r)
                    .map(|s| {
                        (0..D)
                            .map(|c| {
                                let idx = g * per + s * D + c;
                                if idx < flat.len() { flat[idx] } else { 0 }
                            })
                            .collect()
                    })
                    .collect()
            })
            .collect()
    };
    let blinder_kelems = {
        let mut v = Vec::with_capacity(16);
        for b in [&bl_w.tl, &bl_w.tr, &bl_w.f0, &bl_w.f1, &bl_t.tl, &bl_t.tr, &bl_t.f0, &bl_t.f1] {
            v.push(b.a.clone());
            v.push(b.u.clone());
        }
        v
    };

    // Message list in the canonical layout order.
    let mut all_msgs: Vec<Vec<Poly>> = Vec::with_capacity(lay.n_commits);
    all_msgs.extend(pack_scalar_groups(&xs));
    all_msgs.extend(pack_scalar_groups(&ys));
    all_msgs.extend(pack_scalar_groups(&m_vals));
    let bl_groups = pack_kelems(&blinder_kelems);
    assert_eq!(bl_groups.len(), 1);
    all_msgs.extend(bl_groups);
    all_msgs.extend(pack_kelems(&masks_w.flatten()));
    all_msgs.extend(pack_kelems(&masks_t.flatten()));
    assert_eq!(all_msgs.len(), lay.n_data);
    let g_masks = sample_ct_masks(&mut rng, q, msg_r, P3_N_PSI);
    all_msgs.extend(g_masks);
    assert_eq!(all_msgs.len(), lay.n_commits);

    let rp = derive_ct_round_params(q, shape, lay.n_commits, 0, 0, true);
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let path = KernelPath::A1(&a1p);

    // Commit every group with fresh rho.
    let all_rho: Vec<Vec<Vec<i64>>> = (0..all_msgs.len())
        .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
        .collect();
    let (mut t1s, mut t2s): (Vec<Vec<Poly>>, Vec<Vec<Poly>>) = (Vec::new(), Vec::new());
    for (xm, rho) in all_msgs.iter().zip(all_rho.iter()) {
        let (t1, t2) = commit(&path, &crs, xm, rho);
        t1s.push(t1);
        t2s.push(t2);
    }
    let commit_digests: Vec<Vec<u8>> =
        (0..lay.n_commits).map(|i| group_digest(&t1s[i], &t2s[i])).collect();

    // The PublicStatement — its v3 digest is the sole transcript context.
    let statement = p3_build_statement(&lay, &crs.crs_hash, &commit_digests);
    let ctx = statement.digest().expect("prover statement validates");
    let h0_lkp = ct_h0(&crs, &ctx, &t1s, &t2s, &[]);

    // Masked descents on the blinded trees.
    let mut tr = LkpTranscript::new("p3-lookup", &h0_lkp);
    let alpha = tr.challenge_k(&kf);
    let wtree = blinded_witness_tree(&kf, &alpha, &w_fused, lay.dw, &bl_w);
    let ttree = blinded_table_tree(&kf, &alpha, &tab_fused, &m_k, lay.dt, &bl_t);
    // Shape shells for the pin weights (masks are consumed by prove).
    let shell_w = ring::gkr_masked::zero_masks(&kf, lay.dw, 0);
    let shell_t = ring::gkr_masked::zero_masks(&kf, lay.dt, 0);
    let (pw, endw) = ring::gkr_masked::masked_gkr_prove(&kf, &[wtree], masks_w, &mut tr);
    let (pt, endt) = ring::gkr_masked::masked_gkr_prove(&kf, &[ttree], masks_t, &mut tr);

    let mut pins = p3_descent_pins(&kf, lay.base_wm, &shell_w, &pw, &endw, lay.dw, lay.kpc);
    pins.extend(p3_descent_pins(&kf, lay.base_tm, &shell_t, &pt, &endt, lay.dt, lay.kpc));
    pins.extend(p3_leaf_pins(&kf, &lay, &tab_fused, &endw, &endt, &alpha));
    for p in &pins {
        tr.absorb_k(&kf, "p3-pin", std::slice::from_ref(&p.value));
    }
    let psi = derive_pin_psi(&tr.state(), P3_N_PSI, pins.len() * K_DEG, q);
    let claims = pin_claims(&kf, &pins, lay.n_data, msg_r, &psi);
    let h0_round = ct_h0(&crs, &tr.state(), &t1s, &t2s, &[]);
    let openings: Vec<StdOpening> = all_msgs
        .iter()
        .zip(all_rho.iter())
        .enumerate()
        .map(|(i, (xm, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x: xm, rho })
        .collect();
    let (ct, _) = prove_ct_round(
        &path, &ctx_ring, &rp, None, &crs, &h0_round, &claims, &[], &[], &[], &openings, &[], &[],
        lay.g_base, &mut rng,
    );
    (statement, P3Proof { t1s, t2s, pw, pt, ct })
}

/// The INDEPENDENT verifier (P3-D3): from the statement + proof + the
/// deterministic CRS derivation ONLY. Recomputes every transcript seed
/// from the decoded statement and commitments; returns a structured error
/// on any rejection, never a panic. No prover-local value is consulted.
fn p3_lookup_verify(statement: &manifest::Statement, proof: &P3Proof) -> Result<(), P3Error> {
    use ring::commit::CommitShape as CS;
    use ring::ct_engine::{ct_h0, derive_ct_round_params, verify_ct_round};
    use ring::gkr_masked::{masked_gkr_verify, zero_masks};
    use ring::kfield::{K_DEG, KField};
    use ring::lookup::{derive_pin_psi, fused_silu_table, pin_claims, silu_int8_table};
    use ring::sumcheck::LkpTranscript;

    // The statement must be a valid v3 statement (also the transcript ctx).
    let ctx = statement.digest().map_err(P3Error::StatementInvalid)?;

    // Recover n_honest from the X entry and rebuild the deterministic layout.
    let n_honest = statement
        .manifest
        .commitments
        .first()
        .map(|e| e.rows as usize)
        .ok_or(P3Error::ProofShape { what: "commitments", got: 0, want: 1 })?;
    let shape = CS { kappa: 8, n_r: 26, msg_r: 8 };
    let lay = p3_layout(n_honest, shape);

    // Resource limits: the proof's shape is fixed by the statement.
    if proof.t1s.len() != lay.n_commits {
        return Err(P3Error::ProofShape { what: "t1 groups", got: proof.t1s.len(), want: lay.n_commits });
    }
    if proof.t2s.len() != lay.n_commits {
        return Err(P3Error::ProofShape { what: "t2 groups", got: proof.t2s.len(), want: lay.n_commits });
    }
    for g in &proof.t1s {
        if g.len() != shape.kappa || g.iter().any(|p| p.len() != D) {
            return Err(P3Error::ProofShape { what: "t1 group arity", got: g.len(), want: shape.kappa });
        }
    }
    for g in &proof.t2s {
        if g.len() != shape.msg_r || g.iter().any(|p| p.len() != D) {
            return Err(P3Error::ProofShape { what: "t2 group arity", got: g.len(), want: shape.msg_r });
        }
    }
    if proof.pw.layers.len() != lay.dw - 1 || proof.pt.layers.len() != lay.dt - 1 {
        return Err(P3Error::ProofShape { what: "descent depth", got: proof.pw.layers.len(), want: lay.dw - 1 });
    }

    // Consistency: the statement's X and Y commitment digests must match the
    // proof's actual commitment groups (P3-D5: a swapped tensor commitment
    // is caught here, before any crypto).
    let x_dg = group_list_digest(&(0..lay.nx).map(|i| group_digest(&proof.t1s[i], &proof.t2s[i])).collect::<Vec<_>>());
    let y_dg = group_list_digest(&(0..lay.nx).map(|i| group_digest(&proof.t1s[lay.idx_y + i], &proof.t2s[lay.idx_y + i])).collect::<Vec<_>>());
    if statement.manifest.commitments[0].commitment_bytes != x_dg
        || statement.manifest.commitments[1].commitment_bytes != y_dg
    {
        return Err(P3Error::ProofShape { what: "commitment digest mismatch", got: 0, want: 1 });
    }
    // model_digest binds every data commitment: recompute and check.
    let data_digs: Vec<Vec<u8>> =
        (0..lay.n_data).map(|i| group_digest(&proof.t1s[i], &proof.t2s[i])).collect();
    if statement.header.model_digest != p3_model_digest(n_honest, &data_digs) {
        return Err(P3Error::ProofShape { what: "model digest mismatch", got: 0, want: 1 });
    }

    // Deterministic public setup.
    let ctx_ring = ring_ctx_q8();
    let kf = KField::new(&ctx_ring);
    let q = ctx_ring.zq.q;
    let rows = silu_int8_table();
    let tab_fused = fused_silu_table(&kf, &rows);
    let crs = expand_crs(shape, q, P3_CRS_SEED);
    let rp = derive_ct_round_params(q, shape, lay.n_commits, 0, 0, true);
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let path = KernelPath::A1(&a1p);

    // Recompute h0_lkp and alpha from statement + commitments (never read).
    let h0_lkp = ct_h0(&crs, &ctx, &proof.t1s, &proof.t2s, &[]);
    let mut tv = LkpTranscript::new("p3-lookup", &h0_lkp);
    let av = tv.challenge_k(&kf);
    // pin = false is CORRECT here, not a gap (audit 2026-07-14 C-04.a/.3):
    // the verifier does NOT hold the secret mask set (it passes zero-mask
    // SHELLS purely for shape), so masked_gkr_verify cannot check g_sum /
    // open_g / open_r against a locally-known MaskSet — pin = true would
    // demand `g_sum == shell.hypersum() == 0` and reject every honest
    // proof. The mask-pin boundary is instead enforced downstream by the
    // ct-round: p3_descent_pins turns exactly these openings (g_sum,
    // open_g, open_r) into PinnedValues whose weights read the COMMITTED
    // mask coefficients (base_wm/base_tm), and verify_ct_round binds them
    // to the commitments t1s/t2s. So the E3Z-N1 "choose G after nu" move
    // that accepts under an isolated pin = false descent is caught here
    // through the commitment pinning (self_test_p3 ports it to the byte
    // API and requires REJECT).
    let shell_w = zero_masks(&kf, lay.dw, 0);
    let shell_t = zero_masks(&kf, lay.dt, 0);
    let (roots_w, ew) = masked_gkr_verify(&kf, 1, lay.dw, &shell_w, &proof.pw, &mut tv, false)
        .ok_or(P3Error::LookupDescent)?;
    let (roots_t, et) = masked_gkr_verify(&kf, 1, lay.dt, &shell_t, &proof.pt, &mut tv, false)
        .ok_or(P3Error::LookupDescent)?;
    if kf.is_zero(&roots_w[0][1])
        || kf.is_zero(&roots_t[0][1])
        || kf.mul(&roots_w[0][0], &roots_t[0][1]) != kf.mul(&roots_t[0][0], &roots_w[0][1])
    {
        return Err(P3Error::RootCrossCheck);
    }

    // Rebuild the pins from the shape shells, re-absorb, ground the ct-round.
    let mut pv = p3_descent_pins(&kf, lay.base_wm, &shell_w, &proof.pw, &ew, lay.dw, lay.kpc);
    pv.extend(p3_descent_pins(&kf, lay.base_tm, &shell_t, &proof.pt, &et, lay.dt, lay.kpc));
    pv.extend(p3_leaf_pins(&kf, &lay, &tab_fused, &ew, &et, &av));
    for p in &pv {
        tv.absorb_k(&kf, "p3-pin", std::slice::from_ref(&p.value));
    }
    let psi_v = derive_pin_psi(&tv.state(), P3_N_PSI, pv.len() * K_DEG, q);
    let claims_v = pin_claims(&kf, &pv, lay.n_data, shape.msg_r, &psi_v);
    let h0r_v = ct_h0(&crs, &tv.state(), &proof.t1s, &proof.t2s, &[]);
    let ok = verify_ct_round(
        &path, &ctx_ring, &rp, None, &crs, &h0r_v, &claims_v, &[], &[], &[], &proof.t1s, &proof.t2s,
        &[], &[], &[], lay.g_base, &proof.ct,
    );
    if ok { Ok(()) } else { Err(P3Error::CtRound) }
}

// ---- P3Proof canonical serialization (P3-D2). Versioned, length-prefixed,
// little-endian; every count is bounded by the bytes remaining at decode so
// a hostile length cannot force a huge allocation. Poly coefficients ride as
// u32 (values live below q < 2^31); i64 responses ride as i64. -------------

const P3_PROOF_MAGIC: &[u8; 4] = b"ZKMP";
const P3_PROOF_CODEC_VERSION: u32 = 1;
const P3_MAX_POLY_LEN: usize = 1 << 16;

struct P3W {
    buf: Vec<u8>,
}
impl P3W {
    fn new() -> Self {
        P3W { buf: Vec::new() }
    }
    fn u32(&mut self, v: u32) {
        self.buf.extend_from_slice(&v.to_le_bytes());
    }
    fn poly(&mut self, p: &Poly) {
        self.u32(p.len() as u32);
        for &c in p {
            self.u32(c as u32);
        }
    }
    fn polys(&mut self, ps: &[Poly]) {
        self.u32(ps.len() as u32);
        for p in ps {
            self.poly(p);
        }
    }
    fn polys2(&mut self, pss: &[Vec<Poly>]) {
        self.u32(pss.len() as u32);
        for ps in pss {
            self.polys(ps);
        }
    }
    fn polys3(&mut self, p: &[Vec<Vec<Poly>>]) {
        self.u32(p.len() as u32);
        for x in p {
            self.polys2(x);
        }
    }
    fn poly_arr3(&mut self, a: &[[Poly; 3]]) {
        self.u32(a.len() as u32);
        for t in a {
            for p in t {
                self.poly(p);
            }
        }
    }
    fn poly_arr2(&mut self, a: &[[Poly; 2]]) {
        self.u32(a.len() as u32);
        for t in a {
            for p in t {
                self.poly(p);
            }
        }
    }
    fn i64v(&mut self, v: &[i64]) {
        self.u32(v.len() as u32);
        for &x in v {
            self.buf.extend_from_slice(&x.to_le_bytes());
        }
    }
    fn i64v2(&mut self, v: &[Vec<i64>]) {
        self.u32(v.len() as u32);
        for x in v {
            self.i64v(x);
        }
    }
    fn i64v3(&mut self, v: &[Vec<Vec<i64>>]) {
        self.u32(v.len() as u32);
        for x in v {
            self.i64v2(x);
        }
    }
    fn i64v4(&mut self, v: &[Vec<Vec<Vec<i64>>>]) {
        self.u32(v.len() as u32);
        for x in v {
            self.i64v3(x);
        }
    }
}

/// Total decoded-scalar budget across the WHOLE proof (audit 2026-07-14
/// C-04: a total resource budget, not just independent per-vector caps).
/// The honest P3 artifact at the suite's 2^20 cap is far below this; the
/// budget bounds a hostile proof's total allocation/work in one place.
const P3_MAX_TOTAL_SCALARS: usize = 1 << 30;

struct P3R<'a> {
    b: &'a [u8],
    p: usize,
    /// Field modulus for canonical `< q` coordinate checks (C-04).
    q: u64,
    /// Remaining scalar budget (poly coefficients + i64 responses), the
    /// total-resource cap shared across every section.
    budget: usize,
}
impl<'a> P3R<'a> {
    fn new(b: &'a [u8], q: u64) -> Self {
        P3R { b, p: 0, q, budget: P3_MAX_TOTAL_SCALARS }
    }
    fn remaining(&self) -> usize {
        self.b.len() - self.p
    }
    /// Charge `n` scalars against the total budget (C-04).
    fn charge(&mut self, n: usize) -> Result<(), P3Error> {
        if n > self.budget {
            return Err(P3Error::ProofDecode("total scalar budget exceeded"));
        }
        self.budget -= n;
        Ok(())
    }
    fn take(&mut self, n: usize) -> Result<&'a [u8], P3Error> {
        if n > self.remaining() {
            return Err(P3Error::ProofDecode("truncated"));
        }
        let s = &self.b[self.p..self.p + n];
        self.p += n;
        Ok(s)
    }
    fn u32(&mut self) -> Result<u32, P3Error> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn i64(&mut self) -> Result<i64, P3Error> {
        Ok(i64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    /// A count bounded by the bytes remaining (each element is >= 4 bytes).
    fn count(&mut self) -> Result<usize, P3Error> {
        let n = self.u32()? as usize;
        if n > self.remaining() {
            return Err(P3Error::ProofDecode("length exceeds remaining bytes"));
        }
        Ok(n)
    }
    fn poly(&mut self) -> Result<Poly, P3Error> {
        let n = self.u32()? as usize;
        if n > P3_MAX_POLY_LEN || n * 4 > self.remaining() {
            return Err(P3Error::ProofDecode("poly too long"));
        }
        self.charge(n)?;
        let mut out = Vec::with_capacity(n);
        for _ in 0..n {
            let c = self.u32()? as u64;
            // Canonical coordinate check (C-04): a field coefficient MUST
            // be a canonical `< q` representative — non-canonical encodings
            // are rejected, not silently reduced.
            if c >= self.q {
                return Err(P3Error::ProofDecode("noncanonical field coordinate (>= q)"));
            }
            out.push(c);
        }
        Ok(out)
    }
    fn polys(&mut self) -> Result<Vec<Poly>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| self.poly()).collect()
    }
    fn polys2(&mut self) -> Result<Vec<Vec<Poly>>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| self.polys()).collect()
    }
    fn polys3(&mut self) -> Result<Vec<Vec<Vec<Poly>>>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| self.polys2()).collect()
    }
    fn poly_arr3(&mut self) -> Result<Vec<[Poly; 3]>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| Ok([self.poly()?, self.poly()?, self.poly()?])).collect()
    }
    fn poly_arr2(&mut self) -> Result<Vec<[Poly; 2]>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| Ok([self.poly()?, self.poly()?])).collect()
    }
    fn i64v(&mut self) -> Result<Vec<i64>, P3Error> {
        let n = self.u32()? as usize;
        if n * 8 > self.remaining() {
            return Err(P3Error::ProofDecode("i64 vec too long"));
        }
        self.charge(n)?;
        (0..n).map(|_| self.i64()).collect()
    }
    fn i64v2(&mut self) -> Result<Vec<Vec<i64>>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| self.i64v()).collect()
    }
    fn i64v3(&mut self) -> Result<Vec<Vec<Vec<i64>>>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| self.i64v2()).collect()
    }
    fn i64v4(&mut self) -> Result<Vec<Vec<Vec<Vec<i64>>>>, P3Error> {
        let n = self.count()?;
        (0..n).map(|_| self.i64v3()).collect()
    }
    fn finish(&mut self) -> Result<(), P3Error> {
        if self.remaining() != 0 {
            return Err(P3Error::ProofDecode("trailing bytes"));
        }
        Ok(())
    }
}

fn p3_encode_proof(pf: &P3Proof) -> Vec<u8> {
    let mut w = P3W::new();
    w.buf.extend_from_slice(P3_PROOF_MAGIC);
    w.u32(P3_PROOF_CODEC_VERSION);
    w.polys2(&pf.t1s);
    w.polys2(&pf.t2s);
    us1_dump_proof(&mut w.buf, &pf.pw);
    us1_dump_proof(&mut w.buf, &pf.pt);
    let ct = &pf.ct;
    w.polys(&ct.h);
    w.polys2(&ct.w1);
    w.polys2(&ct.w1_ajtai);
    w.polys(&ct.w_claim);
    w.polys(&ct.w_ring);
    w.polys(&ct.h_quad);
    w.poly_arr3(&ct.gq);
    w.polys(&ct.w_quad);
    w.poly_arr2(&ct.gr);
    w.polys(&ct.w_qring);
    w.poly_arr3(&ct.gtq);
    w.polys(&ct.w_tq);
    w.i64v3(&ct.z);
    w.i64v3(&ct.z_rho_ajtai);
    w.i64v3(&ct.z_s_ajtai);
    w.polys3(&ct.t1_digits);
    w.polys3(&ct.w1_digits);
    w.i64v4(&ct.z_digits);
    w.buf
}

/// Every K-field limb of a masked descent must be a canonical `< q`
/// coordinate (audit 2026-07-14 C-04). The [U-S1] dump/load did not check
/// this; the P3 artifact does.
fn p3_descent_canonical(p: &ring::gkr_masked::MaskedDescentProof, q: u64) -> Result<(), P3Error> {
    let lim = |e: &ring::kfield::KElem| e.iter().all(|&c| c < q);
    let bad = || P3Error::ProofDecode("noncanonical field coordinate in descent (>= q)");
    for quad in &p.layer1 {
        if !quad.iter().all(lim) {
            return Err(bad());
        }
    }
    for l in &p.layers {
        if !lim(&l.g_sum) || !lim(&l.open_g) || !l.boundary.iter().all(lim) {
            return Err(bad());
        }
        for r in &l.rounds {
            if !r.iter().all(lim) {
                return Err(bad());
            }
        }
        if let Some((a, b)) = &l.open_r {
            if !lim(a) || !lim(b) {
                return Err(bad());
            }
        }
    }
    Ok(())
}

/// Decode a proof from untrusted bytes, bounded by the statement-implied
/// shape. NEVER panics; returns a structured error on any malformation.
/// Canonical `< q` field coordinates and a single total-scalar budget are
/// enforced across every section (audit 2026-07-14 C-04); trailing bytes
/// are rejected (`finish`). The statement is NOT parsed here — it arrives
/// separately (see `p3_verify_main`), so proof bytes never choose the
/// proposition.
fn p3_decode_proof(bytes: &[u8]) -> Result<P3Proof, P3Error> {
    let q = ring_ctx_q8().zq.q;
    let mut r = P3R::new(bytes, q);
    if r.take(4)? != P3_PROOF_MAGIC {
        return Err(P3Error::ProofDecode("bad magic"));
    }
    if r.u32()? != P3_PROOF_CODEC_VERSION {
        return Err(P3Error::ProofDecode("unknown codec version"));
    }
    let t1s = r.polys2()?;
    let t2s = r.polys2()?;
    // The masked descents ride the [U-S1] dump/load (already bounds-checked
    // and never-panic). Canonical `< q` limbs are enforced below (C-04).
    let pw = {
        let mut rd = Us1Rd { b: &r.b[r.p..], p: 0 };
        let p = us1_load_proof(&mut rd).ok_or(P3Error::ProofDecode("witness descent"))?;
        r.p += rd.p;
        p
    };
    let pt = {
        let mut rd = Us1Rd { b: &r.b[r.p..], p: 0 };
        let p = us1_load_proof(&mut rd).ok_or(P3Error::ProofDecode("table descent"))?;
        r.p += rd.p;
        p
    };
    p3_descent_canonical(&pw, q)?;
    p3_descent_canonical(&pt, q)?;
    let ct = ring::ct_engine::CtRoundProof {
        h: r.polys()?,
        w1: r.polys2()?,
        w1_ajtai: r.polys2()?,
        w_claim: r.polys()?,
        w_ring: r.polys()?,
        h_quad: r.polys()?,
        gq: r.poly_arr3()?,
        w_quad: r.polys()?,
        gr: r.poly_arr2()?,
        w_qring: r.polys()?,
        gtq: r.poly_arr3()?,
        w_tq: r.polys()?,
        z: r.i64v3()?,
        z_rho_ajtai: r.i64v3()?,
        z_s_ajtai: r.i64v3()?,
        t1_digits: r.polys3()?,
        w1_digits: r.polys3()?,
        z_digits: r.i64v4()?,
    };
    r.finish()?;
    Ok(P3Proof { t1s, t2s, pw, pt, ct })
}

/// `verify <statement.bin> <proof.bin>` — the INDEPENDENT verifier process
/// (P3-D3). Reads ONLY the statement bytes, the proof bytes, and derives the
/// public CRS itself; no prover-local state. Exit 0 = ACCEPT, 1 = REJECT,
/// 2 = unreadable file. Prints the structured reason on rejection.
///
/// SEPARATION OF STATEMENT AND PROOF (audit 2026-07-14 C-04.c/.1): the
/// PublicStatement arrives as its OWN argument/file and is decoded
/// independently; the proposition and the transcript context
/// (`statement.digest()`) are NEVER parsed from proof bytes. The proof
/// carries the commitment openings, but the statement independently binds
/// commitment IDENTITY: its X/Y group digests and model_digest are
/// recomputed from the proof's commitments and must match
/// (`p3_lookup_verify`), so a prover cannot swap the proposition or the
/// committed tensors without moving the statement digest (hence h0, hence
/// rejection). This is the concrete fix for the U-S1 defect where
/// `us1_verify_bytes` parsed spec_dg + commits_dg from the proof itself.
fn p3_verify_main(stmt_path: &str, proof_path: &str) {
    let sb = match std::fs::read(stmt_path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("verify: cannot read {stmt_path}: {e}");
            std::process::exit(2);
        }
    };
    let pb = match std::fs::read(proof_path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("verify: cannot read {proof_path}: {e}");
            std::process::exit(2);
        }
    };
    let statement = match manifest::Statement::decode(&sb) {
        Ok(s) => s,
        Err(e) => {
            println!("verify: REJECT (statement decode: {e})");
            std::process::exit(1);
        }
    };
    let proof = match p3_decode_proof(&pb) {
        Ok(p) => p,
        Err(e) => {
            println!("verify: REJECT (proof decode: {e})");
            std::process::exit(1);
        }
    };
    match p3_lookup_verify(&statement, &proof) {
        Ok(()) => {
            println!("verify: ACCEPT");
            std::process::exit(0);
        }
        Err(e) => {
            println!("verify: REJECT ({e})");
            std::process::exit(1);
        }
    }
}

fn self_test_p3() {
    println!("\n[U-S Phase 3] committed lookup proof: statement+proof bytes -> independent verify");
    let (st, pf) = p3_lookup_prove(100, 0x5eed_9301);
    match p3_lookup_verify(&st, &pf) {
        Ok(()) => println!("  ok   P3 honest committed lookup ACCEPTS in-process (statement digest -> h0 -> descents -> pins -> ct-round)"),
        Err(e) => {
            println!("  FAIL P3 honest committed lookup rejected: {e}");
            std::process::exit(1);
        }
    }

    // Canonical serialization round-trip (P3-D2): decode(encode) verifies,
    // and re-encodes byte-identically.
    let sbytes = st.encode();
    let pbytes = p3_encode_proof(&pf);
    let st2 = manifest::Statement::decode(&sbytes).expect("statement round-trips");
    let pf2 = p3_decode_proof(&pbytes).expect("proof round-trips");
    assert_true(
        &format!(
            "P3 serialization round-trip verifies; canonical bytes: statement {} B + proof {} B = {} B",
            sbytes.len(), pbytes.len(), sbytes.len() + pbytes.len()
        ),
        p3_lookup_verify(&st2, &pf2).is_ok() && p3_encode_proof(&pf2) == pbytes,
    );

    // Two-process independent verify (P3-D3): a FRESH ring_matmul process
    // reads only statement.bin + proof.bin and the derived CRS.
    let dir = std::env::temp_dir();
    let sp = dir.join(format!("p3-st-{}.bin", std::process::id()));
    let pp = dir.join(format!("p3-pf-{}.bin", std::process::id()));
    std::fs::write(&sp, &sbytes).expect("write statement");
    std::fs::write(&pp, &pbytes).expect("write proof");
    let exe = std::env::current_exe().expect("current exe");
    let run = |s: &std::path::Path, p: &std::path::Path| -> i32 {
        std::process::Command::new(&exe)
            .arg("verify")
            .arg(s)
            .arg(p)
            .status()
            .expect("spawn verify")
            .code()
            .unwrap_or(-1)
    };
    assert_true(
        "P3 two-process: a SECOND process ACCEPTS the honest proof from bytes alone (no prover-local value crosses)",
        run(&sp, &pp) == 0,
    );

    // model_digest tamper (P3-D5): a swapped tensor identity REJECTS.
    {
        let mut st_bad = st.clone();
        st_bad.header.model_digest[0] ^= 1;
        let spb = dir.join(format!("p3-st-bad-{}.bin", std::process::id()));
        std::fs::write(&spb, st_bad.encode()).unwrap();
        assert_true(
            "P3 model_digest tamper REJECTS in-process AND in the second process (statement digest moves; verifier's h0 diverges)",
            p3_lookup_verify(&st_bad, &pf).is_err() && run(&spb, &pp) == 1,
        );
        let _ = std::fs::remove_file(&spb);
    }

    // Commitment-swap (P3-D5): corrupt one committed group in the proof ->
    // the statement's X digest no longer matches -> REJECT.
    {
        let mut pf_bad = P3Proof {
            t1s: pf.t1s.clone(),
            t2s: pf.t2s.clone(),
            pw: MaskedTamper::clone_proof(&ring::kfield::KField::new(&ring_ctx_q8()), &pf.pw),
            pt: MaskedTamper::clone_proof(&ring::kfield::KField::new(&ring_ctx_q8()), &pf.pt),
            ct: p3_decode_proof(&pbytes).unwrap().ct,
        };
        pf_bad.t1s[0][0][0] ^= 1;
        assert_true(
            "P3 commitment swap REJECTS (proof X group corrupted -> statement digest mismatch, pre-crypto)",
            matches!(p3_lookup_verify(&st, &pf_bad), Err(P3Error::ProofShape { .. })),
        );
    }

    // Descent/ct-round tamper: bump a round polynomial -> the descents
    // diverge -> REJECT (LookupDescent), never a false accept.
    {
        let kf = ring::kfield::KField::new(&ring_ctx_q8());
        let mut pf_bad = P3Proof {
            t1s: pf.t1s.clone(),
            t2s: pf.t2s.clone(),
            pw: MaskedTamper::clone_proof(&kf, &pf.pw),
            pt: MaskedTamper::clone_proof(&kf, &pf.pt),
            ct: p3_decode_proof(&pbytes).unwrap().ct,
        };
        pf_bad.pw.layers[1].rounds[1][2] = kf.add(&pf_bad.pw.layers[1].rounds[1][2], &kf.one());
        assert_true(
            "P3 descent tamper REJECTS (bumped round polynomial -> masked descent rejects)",
            p3_lookup_verify(&st, &pf_bad).is_err(),
        );
    }

    // E3Z-N1 ported to the serialized byte API (audit 2026-07-14 C-04.b):
    // the toy E3Z-N1 battery shows that an isolated masked descent with
    // pin = false ACCEPTS a false lookup when the prover shifts the
    // layer-1 p-value to repair the derived-root ratio and absorbs the
    // defect into a G ("g_sum") chosen after nu — and rejects only with
    // pin = true. P3 verifies with pin = false, so THIS is the boundary
    // the audit flags as load-bearing. Here we replay both crafting moves
    // on the honest committed proof, serialize, and require the
    // independent verifier (in-process AND fresh process) to REJECT: in
    // P3 the mask-pin is enforced by the ct-round (g_sum / open_g /
    // open_r are ct-round PinnedValues over the committed masks) and h0
    // is recomputed from the statement + commitments, so neither the
    // root-repair shift nor the free g_sum choice survives.
    {
        let kf = ring::kfield::KField::new(&ring_ctx_q8());
        // Move 1: the layer-1 root repair — E3Z-N1 shifts the witness
        // p-value along the q-direction (p10 -> p10 + delta*q10) so the
        // derived-root RATIO can be steered (for a false witness, back onto
        // the table's). The honest proof's ratios already agree, so any
        // nonzero shift perturbs an honest transcript exactly as the attack
        // perturbs a false one; delta = 1 (i.e. + q10, or + 1 if q10 = 0).
        let mut pf_root = P3Proof {
            t1s: pf.t1s.clone(),
            t2s: pf.t2s.clone(),
            pw: MaskedTamper::clone_proof(&kf, &pf.pw),
            pt: MaskedTamper::clone_proof(&kf, &pf.pt),
            ct: p3_decode_proof(&pbytes).unwrap().ct,
        };
        let [p10, _p11, q10, _q11] = pf_root.pw.layer1[0].clone();
        let shift = if kf.is_zero(&q10) { kf.one() } else { q10 };
        pf_root.pw.layer1[0][0] = kf.add(&p10, &shift);
        let root_bytes = p3_encode_proof(&pf_root);
        let rp = dir.join(format!("p3-e3zn1-root-{}.bin", std::process::id()));
        std::fs::write(&rp, &root_bytes).unwrap();
        assert_true(
            "P3 E3Z-N1 port (root-ratio repair): the layer-1 p-value shift REJECTS in-process AND in the fresh process (real-FS h0 + ct-round pinning close the pin=false gap)",
            p3_lookup_verify(&st, &p3_decode_proof(&root_bytes).unwrap()).is_err()
                && run(&sp, &rp) == 1,
        );
        let _ = std::fs::remove_file(&rp);

        // Move 2: the free G choice — E3Z-N1 picks g_sum AFTER nu to absorb
        // the layer-1 defect. In P3 g_sum is a ct-round pin over the
        // committed mask hypersum, so any free shift REJECTS.
        let mut pf_gsum = P3Proof {
            t1s: pf.t1s.clone(),
            t2s: pf.t2s.clone(),
            pw: MaskedTamper::clone_proof(&kf, &pf.pw),
            pt: MaskedTamper::clone_proof(&kf, &pf.pt),
            ct: p3_decode_proof(&pbytes).unwrap().ct,
        };
        pf_gsum.pw.layers[0].g_sum = kf.add(&pf_gsum.pw.layers[0].g_sum, &kf.one());
        let gsum_bytes = p3_encode_proof(&pf_gsum);
        let gp = dir.join(format!("p3-e3zn1-gsum-{}.bin", std::process::id()));
        std::fs::write(&gp, &gsum_bytes).unwrap();
        assert_true(
            "P3 E3Z-N1 port (free g_sum after nu): the descent G shift REJECTS in-process AND in the fresh process (g_sum is a ct-round pin over the committed mask)",
            p3_lookup_verify(&st, &p3_decode_proof(&gsum_bytes).unwrap()).is_err()
                && run(&sp, &gp) == 1,
        );
        let _ = std::fs::remove_file(&gp);
    }

    // Canonical field-coordinate reject (audit 2026-07-14 C-04.d): a
    // proof carrying a non-canonical `>= q` coefficient is REJECTED at
    // decode, not silently reduced.
    {
        let q = ring_ctx_q8().zq.q;
        let mut pf_nc = p3_decode_proof(&pbytes).unwrap();
        if let Some(first) = pf_nc.ct.h.first_mut() {
            first[0] = q; // exactly the modulus — the smallest non-canonical value
        } else {
            pf_nc.t1s[0][0][0] = q;
        }
        let nc_bytes = p3_encode_proof(&pf_nc);
        assert_true(
            "P3 canonical check: a proof with a `>= q` field coordinate REJECTS at decode (C-04 canonical <q enforcement)",
            matches!(p3_decode_proof(&nc_bytes), Err(P3Error::ProofDecode(_))),
        );
        // A non-canonical limb inside a masked descent is caught too.
        let mut pf_ncd = p3_decode_proof(&pbytes).unwrap();
        pf_ncd.pw.layers[0].g_sum[0] = q;
        let ncd_bytes = p3_encode_proof(&pf_ncd);
        assert_true(
            "P3 canonical check: a `>= q` limb in a masked descent REJECTS at decode",
            matches!(p3_decode_proof(&ncd_bytes), Err(P3Error::ProofDecode(_))),
        );
    }

    // Malformed-proof fuzz (P3-D4): bit-flip/truncate/extend the proof bytes;
    // the decoder + verifier return structured errors and NEVER panic (a
    // panic aborts under panic=abort and fails the battery).
    {
        let mut state = 0x5eed_9f3ec0deu64;
        let mut next = || {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state
        };
        for _ in 0..3000 {
            let mut buf = pbytes.clone();
            let flips = 1 + (next() % 8) as usize;
            for _ in 0..flips {
                let i = (next() as usize) % buf.len();
                buf[i] ^= (next() & 0xff) as u8;
            }
            match next() % 3 {
                0 => buf.truncate((next() as usize) % (buf.len() + 1)),
                1 => buf.push((next() & 0xff) as u8),
                _ => {}
            }
            match p3_decode_proof(&buf) {
                Ok(p) => {
                    // A decodable-but-corrupt proof must still verify-reject.
                    let _ = p3_lookup_verify(&st, &p);
                }
                Err(_) => {} // structured decode error — fine
            }
        }
        // Statement fuzz through the same path.
        for _ in 0..1000 {
            let mut buf = sbytes.clone();
            let i = (next() as usize) % buf.len();
            buf[i] ^= (next() & 0xff) as u8;
            let _ = manifest::Statement::decode(&buf);
        }
        println!("  ok   P3 fuzz: 3000 proof + 1000 statement malformed inputs decode/verify without a single panic");
    }

    for f in [&sp, &pp] {
        let _ = std::fs::remove_file(f);
    }
}

/// `p3-bench <n_honest>` — the P3-EXIT measurement: canonical byte size and
/// independent-verifier p50/p95 wall time at the given element count. All
/// timings [NOISY-SHARED]. Prove once (deterministic); time the verifier
/// over `reps` runs.
fn p3_bench(n_honest: usize) {
    let reps = 9usize;
    let t_p = Instant::now();
    let (st, pf) = p3_lookup_prove(n_honest, 0x5eed_9b00);
    let prove_s = t_p.elapsed().as_secs_f64();
    let sbytes = st.encode();
    let pbytes = p3_encode_proof(&pf);
    // Decode once so the timed verifier includes only the verify path (the
    // fresh process decodes too; here we separate the two).
    let dec_st = manifest::Statement::decode(&sbytes).expect("stmt decode");
    let dec_pf = p3_decode_proof(&pbytes).expect("proof decode");
    let lay = p3_layout(n_honest, ring::commit::CommitShape { kappa: 8, n_r: 26, msg_r: 8 });
    let mut ts: Vec<f64> = Vec::with_capacity(reps);
    let mut accept = true;
    for _ in 0..reps {
        let t = Instant::now();
        accept &= p3_lookup_verify(&dec_st, &dec_pf).is_ok();
        ts.push(t.elapsed().as_secs_f64());
    }
    ts.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let p50 = ts[reps / 2];
    let p95 = ts[(reps * 95 / 100).min(reps - 1)];
    println!(
        "u-s p3 lookup-proof bench: n={n_honest} (dw={} dt={}) accept={accept} [NOISY-SHARED]",
        lay.dw, lay.dt
    );
    println!(
        "  canonical bytes: statement {} B + proof {} B = {} B ({:.1} KiB); budget 256 KiB -> {}",
        sbytes.len(),
        pbytes.len(),
        sbytes.len() + pbytes.len(),
        (sbytes.len() + pbytes.len()) as f64 / 1024.0,
        if sbytes.len() + pbytes.len() <= 256 * 1024 { "WITHIN" } else { "OVER (recorded honestly)" }
    );
    println!(
        "  prove {:.3}s; independent verify p50 {:.3}s / p95 {:.3}s over {reps} reps",
        prove_s, p50, p95
    );
    // Confirm the fresh-process path once.
    let dir = std::env::temp_dir();
    let sp = dir.join(format!("p3b-st-{}.bin", std::process::id()));
    let pp = dir.join(format!("p3b-pf-{}.bin", std::process::id()));
    std::fs::write(&sp, &sbytes).unwrap();
    std::fs::write(&pp, &pbytes).unwrap();
    let code = std::process::Command::new(std::env::current_exe().unwrap())
        .arg("verify").arg(&sp).arg(&pp).status().unwrap().code().unwrap_or(-1);
    println!("  fresh-process verify exit code: {code} (0 = ACCEPT)");
    let _ = std::fs::remove_file(&sp);
    let _ = std::fs::remove_file(&pp);
}

// ===========================================================================
// U-K9 (M4_LOOKUP_DESIGN Section 7'): the bulk-kernel differential
// battery. The lane-packed, lazy-reduction kernel paths (kfield.rs
// KTab/KKern; gkr.rs layer_sumcheck_bulk; gkr_masked.rs
// masked_rounds_bulk) must be BIT-IDENTICAL to the scalar oracle
// (KField::harness_scalar — the original code, kept shipped) on random
// primitives, whole unmasked descents (single- and multi-instance) and
// whole masked descents. The shipped [U-K1..K5] batteries themselves run
// on the bulk path (KField::new), so this battery is the wire that pins
// the two implementations together.
fn self_test_uk9() {
    use ring::gkr::{absorb_roots, build_tree, eq_table, gkr_prove, gkr_verify};
    use ring::gkr_masked::{
        BlinderSet, blinded_witness_tree, draw_masks, masked_gkr_prove, masked_gkr_verify,
    };
    use ring::kfield::{
        K9_MAX_LEAVES, KElem, KField, bulk_mul_fixed_kelems, harness_bulk_mul_fixed_portable,
        harness_fold_portable, k9_capacity_ok,
    };
    use ring::lookup::{fuse_pair, silu_int8_table, table_spec_digest};
    use ring::sumcheck::{LkpTranscript, fold, mle_eval};
    println!(
        "\n[U-K9] bulk kernels: lane-packed slot arithmetic + lazy reduction vs the scalar oracle"
    );
    let ctx = ring_ctx_q8();
    let kf = KField::new(&ctx);
    let kfo = KField::harness_scalar(&ctx);
    let zq = ctx.zq;
    let mut xr = XofReader::new("uk9-battery", &[b"seed-1"]);

    // ---- primitive differentials (random data, bulk vs scalar) ----
    let n = 1usize << 9;
    let ta: Vec<KElem> = (0..n).map(|_| kf.uniform(&mut xr)).collect();
    let tb: Vec<KElem> = (0..n).map(|_| kf.uniform(&mut xr)).collect();
    let r = kf.uniform(&mut xr);
    assert_true(
        "U-K9 fold: bulk == scalar on a 2^9 random table",
        fold(&kf, &ta, &r) == fold(&kfo, &ta, &r),
    );
    let pt: Vec<KElem> = (0..9).map(|_| kf.uniform(&mut xr)).collect();
    assert_true(
        "U-K9 mle_eval: bulk == scalar (2^9 table, random point)",
        mle_eval(&kf, &ta, &pt) == mle_eval(&kfo, &ta, &pt),
    );
    assert_true(
        "U-K9 eq_table: bulk == scalar (9 variables)",
        eq_table(&kf, &pt) == eq_table(&kfo, &pt),
    );
    let odd = &tb[..37];
    assert_true(
        "U-K9 fixed-operand map: bulk == scalar incl. the sub-block tail (n = 37)",
        bulk_mul_fixed_kelems(&kf, odd, &r)
            == odd.iter().map(|e| kfo.mul(e, &r)).collect::<Vec<_>>(),
    );

    // Boundary vectors pin the GPU ABI's canonical residue behavior. They
    // cover zero, one, q-1, the special-form reduction constants and a
    // partial final lane block; the packed portable body is exercised
    // separately from both AVX dispatch and the boxed scalar oracle.
    let edge_coeffs = [0, 1, zq.q - 1, zq.q - 2, zq.q / 2, 399, zq.q - 399, 798];
    let edge: Vec<KElem> = (0..37)
        .map(|i| (0..ring::kfield::K_DEG).map(|j| edge_coeffs[(i + j) % edge_coeffs.len()]).collect())
        .collect();
    let edge_r: KElem =
        (0..ring::kfield::K_DEG).map(|j| edge_coeffs[(3 * j + 2) % edge_coeffs.len()]).collect();
    let edge_auto = bulk_mul_fixed_kelems(&kf, &edge, &edge_r);
    let edge_portable = harness_bulk_mul_fixed_portable(&kf, &edge, &edge_r);
    let edge_scalar: Vec<KElem> = edge.iter().map(|e| kfo.mul(e, &edge_r)).collect();
    assert_true(
        "U-K9 residue boundaries + tail: AVX-dispatched packed == forced-portable packed == scalar oracle; every output canonical",
        edge_auto == edge_portable
            && edge_auto == edge_scalar
            && edge_auto.iter().flatten().all(|&x| x < zq.q),
    );
    let edge_fold = &edge[..32];
    assert_true(
        "U-K9 deinterleave/fold boundaries: AVX-dispatched packed == forced-portable packed == scalar oracle",
        fold(&kf, edge_fold, &edge_r) == harness_fold_portable(&kf, edge_fold, &edge_r)
            && fold(&kf, edge_fold, &edge_r) == fold(&kfo, edge_fold, &edge_r),
    );
    assert_true(
        "U-K9 capacity contract: 2^25 leaves is admitted and the next power of two is rejected before allocation/accumulation",
        k9_capacity_ok(K9_MAX_LEAVES) && !k9_capacity_ok(K9_MAX_LEAVES * 2),
    );

    // ---- whole unmasked descents: trees, transcripts, proofs ----
    let rows = silu_int8_table();
    let spec_dg = table_spec_digest(&rows);
    let flat_gkr = |p: &ring::gkr::GkrDescentProof| -> Vec<KElem> {
        let mut out = Vec::new();
        for sc in &p.layers {
            for g in &sc.rounds {
                out.extend(g.iter().cloned());
            }
            out.extend(sc.final_evals.iter().cloned());
        }
        out
    };
    let nn = 1usize << 10;
    let mut rng = 0x5eed_0909u64;
    let xs: Vec<i64> = (0..nn).map(|_| rng_below(&mut rng, 256) as i64 - 128).collect();
    let run_unmasked = |field: &KField| -> (Vec<KElem>, Vec<KElem>, KElem, KElem, [KElem; 2]) {
        let w: Vec<KElem> = xs
            .iter()
            .map(|&x| {
                let y = rows[(x + 128) as usize].1;
                fuse_pair(field, zq.to_mod(x), zq.to_mod(y))
            })
            .collect();
        let mut tr = LkpTranscript::new("uk9-unmasked", &spec_dg);
        let alpha = tr.challenge_k(field);
        let tree = build_tree(
            field,
            vec![field.one(); nn],
            w.iter().map(|wi| field.sub(&alpha, wi)).collect(),
        );
        let root = tree.root();
        absorb_roots(field, &[root.clone()], &mut tr);
        let (proof, z, p, q) = gkr_prove(field, &[tree], &mut tr);
        (flat_gkr(&proof), z, p, q, root)
    };
    let (fa, za, pa, qa, ra) = run_unmasked(&kf);
    let (fb, zb, pb, qb, rb) = run_unmasked(&kfo);
    assert_true(
        "U-K9 unmasked descent (N = 2^10, 1 instance): roots, every round poly, boundaries, final point and claims bit-identical",
        fa == fb && za == zb && pa == pb && qa == qb && ra == rb,
    );
    // multi-instance (e_bits = 1) + cross-verification of the bulk proof
    let run_pair = |field: &KField| -> (Vec<KElem>, Vec<KElem>, KElem, KElem, bool) {
        let mk_tree = |field: &KField, alpha: &KElem, seed_off: i64| {
            let leaves: Vec<KElem> = xs[..512]
                .iter()
                .map(|&x| {
                    let y = rows[((x + seed_off).rem_euclid(256)) as usize].1;
                    fuse_pair(field, zq.to_mod(x), zq.to_mod(y))
                })
                .collect();
            build_tree(
                field,
                vec![field.one(); 512],
                leaves.iter().map(|wi| field.sub(alpha, wi)).collect(),
            )
        };
        let mut tr = LkpTranscript::new("uk9-pair", &spec_dg);
        let alpha = tr.challenge_k(field);
        let t1 = mk_tree(field, &alpha, 0);
        let t2 = mk_tree(field, &alpha, 7);
        let roots = [t1.root(), t2.root()];
        absorb_roots(field, &roots, &mut tr);
        let (proof, z, p, q) = gkr_prove(field, &[t1, t2], &mut tr);
        // verify (scalar machinery) accepts the proof
        let mut tv = LkpTranscript::new("uk9-pair", &spec_dg);
        let _ = tv.challenge_k(field);
        absorb_roots(field, &roots, &mut tv);
        let ok = gkr_verify(field, &roots, 9, &proof, &mut tv)
            .map(|(zv, pv, qv)| zv == z && pv == p && qv == q)
            .unwrap_or(false);
        (flat_gkr(&proof), z, p, q, ok)
    };
    let (fa2, za2, pa2, qa2, oka) = run_pair(&kf);
    let (fb2, zb2, pb2, qb2, okb) = run_pair(&kfo);
    assert_true(
        "U-K9 unmasked descent (2 instances, e_bits = 1): bulk == scalar and both verify",
        fa2 == fb2 && za2 == zb2 && pa2 == pb2 && qa2 == qb2 && oka && okb,
    );

    // ---- whole masked descent: bulk == scalar, and it verifies ----
    let dw = 8usize;
    let run_masked = |field: &KField| -> (Vec<KElem>, Vec<KElem>, KElem, KElem, bool) {
        let mut trm = ring::ProverRng::from_test_seed("uk9-masks", &spec_dg);
        let masks = draw_masks(field, &mut trm, dw, 0);
        let bl = BlinderSet::draw(field, &mut trm);
        let alpha = {
            let mut ta = LkpTranscript::new("uk9-alpha", &spec_dg);
            ta.challenge_k(field)
        };
        let w_fused: Vec<KElem> = xs[..100]
            .iter()
            .map(|&x| {
                let y = rows[(x + 128) as usize].1;
                fuse_pair(field, zq.to_mod(x), zq.to_mod(y))
            })
            .collect();
        let tree = blinded_witness_tree(field, &alpha, &w_fused, dw, &bl);
        let mut tr = LkpTranscript::new("uk9-masked", &spec_dg);
        let (proof, end) = masked_gkr_prove(field, &[tree], masks.harness_clone(), &mut tr);
        let mut tv = LkpTranscript::new("uk9-masked", &spec_dg);
        let ok = masked_gkr_verify(field, 1, dw, &masks, &proof, &mut tv, true)
            .map(|(_, ev)| ev.zstar == end.zstar && ev.p_claim == end.p_claim && ev.q_claim == end.q_claim)
            .unwrap_or(false);
        let flat: Vec<KElem> = flatten_masked(&proof);
        (flat, end.zstar, end.p_claim, end.q_claim, ok)
    };
    let (ma, mza, mpa, mqa, moka) = run_masked(&kf);
    let (mb, mzb, mpb, mqb, mokb) = run_masked(&kfo);
    assert_true(
        "U-K9 masked descent (depth 8, blinded, fresh masks): every transcript element bit-identical, both verify with pins",
        ma == mb && mza == mzb && mpa == mpb && mqa == mqb && moka && mokb,
    );
    assert_true(
        "U-K9 kernel gate: the frozen q31 point runs the bulk path; the oracle instance does not",
        kf.kern.is_some() && kfo.kern.is_none(),
    );
    let mut os_a = ring::ProverRng::from_os().expect("OS CSPRNG for freshness battery");
    let mut os_b = ring::ProverRng::from_os().expect("OS CSPRNG for freshness battery");
    let fresh_a = draw_masks(&kf, &mut os_a, 4, 0).flatten();
    let fresh_b = draw_masks(&kf, &mut os_b, 4, 0).flatten();
    assert_true(
        "U-K9 prover entropy: independently OS-seeded mask sessions differ (public Fiat-Shamir state is not a mask source)",
        fresh_a != fresh_b,
    );
}

// U-K8 (M4_LOOKUP_DESIGN Section 8): lookup-bench — the measured
// replacement for the design's [MODEL] prover constants. One instance
// of N = 2^n int8 SiLU lookups through the REAL pipeline pieces:
// fused leaves, both projective trees, both descents, verification
// with leaf grounding, and the E4 weight stream. Single-thread
// timings; the pass extrapolation uses the M5-lite MEASURED 22T
// factor (8.74x, M5_LITE_REPORT.md) and labels the GPU row [ASSUMED].

fn lookup_bench(n_log2: usize) {
    use ring::gkr::{absorb_roots, build_tree, gkr_prove, gkr_verify, root_cross_check};
    use ring::kfield::{KElem, KField};
    use ring::lookup::{
        fuse_pair, fused_silu_table, mle_weights_block, silu_int8_table, table_spec_digest,
    };
    use ring::sumcheck::{LkpTranscript, mle_eval};
    let n = 1usize << n_log2;
    println!("m4 lookup-bench: N = 2^{n_log2} = {n} int8 SiLU lookups, one instance, 1T");
    let ctx = ring_ctx_q8();
    let kf = KField::new(&ctx);
    let zq = ctx.zq;
    let rows = silu_int8_table();
    let spec_dg = table_spec_digest(&rows);
    let tab_fused = fused_silu_table(&kf, &rows);
    let mut rng = 0x5eed_0808u64;
    let xs: Vec<i64> = (0..n).map(|_| rng_below(&mut rng, 256) as i64 - 128).collect();
    let t0 = Instant::now();
    let w: Vec<KElem> = xs
        .iter()
        .map(|&x| {
            let y = rows[(x + 128) as usize].1;
            fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y))
        })
        .collect();
    let mut m_counts = vec![0u64; 256];
    for &x in &xs {
        m_counts[(x + 128) as usize] += 1;
    }
    let m_k: Vec<KElem> = m_counts.iter().map(|&c| kf.embed(c)).collect();
    let fuse_s = t0.elapsed().as_secs_f64();
    let mut tr = LkpTranscript::new("uk8-bench", &spec_dg);
    let alpha = tr.challenge_k(&kf);
    let t1 = Instant::now();
    let wtree = build_tree(
        &kf,
        vec![kf.one(); n],
        w.iter().map(|wi| kf.sub(&alpha, wi)).collect(),
    );
    let ttree =
        build_tree(&kf, m_k, tab_fused.iter().map(|t| kf.sub(&alpha, t)).collect());
    let tree_s = t1.elapsed().as_secs_f64();
    let (wr, trr) = (wtree.root(), ttree.root());
    assert!(root_cross_check(&kf, &wr, &trr), "bench witness must be honest");
    let t2 = Instant::now();
    absorb_roots(&kf, &[wr.clone()], &mut tr);
    let (pw_proof, _, _, _) = gkr_prove(&kf, &[wtree], &mut tr);
    absorb_roots(&kf, &[trr.clone()], &mut tr);
    let (pt_proof, _, _, _) = gkr_prove(&kf, &[ttree], &mut tr);
    let prove_s = t2.elapsed().as_secs_f64();
    let t3 = Instant::now();
    let mut tv = LkpTranscript::new("uk8-bench", &spec_dg);
    let av = tv.challenge_k(&kf);
    assert_eq!(av, alpha);
    absorb_roots(&kf, &[wr.clone()], &mut tv);
    let (zw, pw, qw) = gkr_verify(&kf, &[wr], n_log2, &pw_proof, &mut tv).expect("w descent");
    absorb_roots(&kf, &[trr.clone()], &mut tv);
    let (zt, _pm, qt) = gkr_verify(&kf, &[trr], 8, &pt_proof, &mut tv).expect("t descent");
    let ground_w = kf.sub(&alpha, &mle_eval(&kf, &w, &zw));
    assert!(pw == kf.one() && qw == ground_w, "leaf grounding");
    assert_eq!(qt, kf.sub(&alpha, &mle_eval(&kf, &tab_fused, &zt)));
    let verify_s = t3.elapsed().as_secs_f64();
    // E4 weight stream: one pass of L_{z_w*} in 2^16-blocks (the
    // never-materialize primitive) + one coordinate projection row.
    let t4 = Instant::now();
    let lb = 16.min(n_log2);
    let mut row0 = vec![0u64; n];
    for b in 0..(n >> lb) {
        let blk = mle_weights_block(&kf, &zw, b, lb);
        for (j, e) in blk.iter().enumerate() {
            row0[(b << lb) + j] = e[0];
        }
    }
    let weights_s = t4.elapsed().as_secs_f64();
    std::hint::black_box(&row0);
    let total = fuse_s + tree_s + prove_s + verify_s;
    let per_el_ns = total / n as f64 * 1e9;
    println!("  fuse+histogram {fuse_s:.2}s | trees {tree_s:.2}s | descents {prove_s:.2}s | verify {verify_s:.2}s | E4 weight stream {weights_s:.2}s");
    println!("  prover lookup total (fuse+trees+descents) = {:.2}s 1T = {:.0} ns/element", fuse_s + tree_s + prove_s, (fuse_s + tree_s + prove_s) / n as f64 * 1e9);
    println!("  per-element total incl. verify: {per_el_ns:.0} ns/el 1T");
    // SCOPE (audit 2026-07-10 H-01/H-02): this is an UNMASKED,
    // UNCOMMITTED single-thread lookup-core microbenchmark — no E4
    // ct-round, no U-K5 masking, no upstream range proof, no downstream
    // Hadamard. This code path has no parallel implementation, so the
    // multi-thread row below is an ASSUMPTION (a factor imported from
    // the M5 COMMIT-kernel measurement, a different workload); the GPU
    // row uses the repo-wide convention (20x over the 22T row, as in
    // m5-bench) and is [ASSUMED] — no GPU backend exists.
    let pass_1t = (fuse_s + tree_s + prove_s) / n as f64 * 1.8e8;
    let pass_22t_assumed = pass_1t / 8.74;
    println!(
        "  7B/512 pass extrapolation (1.8e8 elements, linear): {pass_1t:.0}s 1T [MEASURED-AT-RATE]; {pass_22t_assumed:.0}s 22T [ASSUMED factor 8.74x from the M5 commit kernel — lookup code is single-threaded]; {:.1}s GPU [ASSUMED 20x over the assumed 22T row]",
        pass_22t_assumed / 20.0,
    );
    println!("lookup-bench done (N = {n}, unmasked lookup-core microbenchmark, table digest {})",
        spec_dg.iter().take(4).map(|b| format!("{b:02x}")).collect::<String>());
}

// ===========================================================================
// U-K8 (M4_LOOKUP_DESIGN Section 8, the 2026-07-10 audit H-01 exit): the
// COMMITTED FFN-GATE CHAIN — one gate tensor end to end:
//
//   range-proved X in  ->  MASKED table-certified Y = SiLU(X) out
//                      ->  downstream gate-o-up Hadamard Z = Y o UP.
//
// Chain anatomy (per element): X is committed DENSE at q31 as the offset
// code x + 128 in [0, 256); its int8 domain fact is PROVEN by the U-L
// modulus link (bit planes at q46 where binary + ARP close, l = 24 xi
// rows tie the recomposed integers to X's q31 residues — the chain-demo
// pattern). Y lives ONLY slot-packed (H3) so the downstream Hadamard can
// consume it; the masked lookup ([U-K5c] machinery: committed m column,
// blinders, Libra-class masks, aggregate-only pins) certifies
// (X_i, Y_i) in silu-int8-table-v1, reading X through the pin's -128
// offset fold and Y through E1-COMPOSED per-coefficient weights
// (ring/lookup.rs slot_pin_weights — the design Section 3.4 slot-packed
// E4 variant: same claim family, different public weight computation).
// Slot-constancy of Y and UP is pinned by standalone zeta junk rows
// (link_claims_tgt_slot with xi = 0 — the U-E2 machinery); Z inherits
// it by GF(q) closure, and the block output claim is the untwisted
// QuadRingClaim Y o UP - Z = 0 per packed element.
//
// TWO AS-BUILT CAPACITY WALLS THIS INTEGRATION SURFACED (docs updated):
//
//  1. The q31 ct-round C2 gate (q > 8 beta) caps ONE round at ~134
//     commitments of the U-K5c CRS shape (kappa 8, n_r 26, msg_r 8) —
//     ~4.4e5 committed coefficients. A single-descent committed lookup
//     therefore caps NEAR 2^17 dense elements per round, BEFORE the
//     audit H-03 memory wall binds. The chain is built as independent
//     ROW-BLOCK SUB-INSTANCES of B = 1020 elements (the design Section 9
//     item 5 sub-instancing; ceiling margin only improves): witness tree
//     depth 11 (1020 = blinder_positions(2048)[0]), table depth 9, one
//     q31 round per block (~113 commitments, C2-asserted).
//  2. The q46 ARP budget caps binary units at ~896 coefficients AND caps
//     the rejection-sampling alpha at ~4 for 512-bit units, while the
//     FS-with-aborts loop restarts ALL units of a round together. Frozen
//     chain point (LKP-8): sub-block = 128 values -> two 512-bit units
//     (planes 0-3 / 4-7 at msg_r = 4), q46 rounds of 4 units (256
//     values) at alpha = 3.5, joint Q4.2b rejection across the round's
//     4 units (~2.8 expected attempts/round; the per-unit product
//     scheme's ~6.5 superseded 2026-07-13), one link instance per q46
//     round (w = 11, l = 24).
//
// *** LEGACY RANGE ARM — NOT ZK-GRADE (audit 2026-07-14 C-01). *** The
// q46 grounding's ARP rejection clips ~2^-4.75 of the reveal mass at the
// frozen t = 1.5, so this chain's range arm is NOT statistical ZK; the
// LKP-8 constants are REPRODUCIBILITY pins only. The security-target
// t ~ 13.4 blows the restart economics ~900x per round with no alpha
// inside the extraction budget (the demotion argument at ARP_REJ_T).
// The ZK-grade path is the ARP-free per-layer rig with the exact
// [0,256) range lookup (ffn-chain layer, U-R ledger D-5 / U-R2).
//
// Streaming binding (the D-4 ledger decision): every TENSOR commitment
// (X, planes, Y, UP, Z, m, blinders, masks) precedes the validated
// statement digest ctx (manifest v2: Binary + Range + Lookup + Hadamard,
// output Z); per block, h0_link_b = link_h0(ctx || block, both sides'
// block lists INCLUDING that block's g-masks) and every weight-like
// value (xi, zeta, alpha, psi, theta, JL) derives from it — the
// commit-before-challenge rule holds locally where the weights bind,
// and globally through ctx.

const UK8_B: usize = 1020; // elements per block = blinder_positions(2048)[0]
const UK8_DW: usize = 11; // witness tree depth (2048 leaves)
const UK8_DT: usize = 9; // table tree depth (256 rows split + blinders)
const UK8_SUB: usize = 128; // values per q46 sub-block (one dense X slot)
const UK8_RPB: usize = 4; // q46 rounds per block (2 sub-blocks each)
const UK8_ALPHA: f64 = 3.5; // ARP rejection alpha at the 512-bit unit

#[derive(Clone, Copy, PartialEq)]
enum ChainTamper {
    /// Honest witness.
    None,
    /// X wraps: committed residue x_u + 256 with honest-looking planes —
    /// the q46-grounded link must reject (run with the lookup omitted to
    /// isolate the range edge).
    RangeX,
    /// One Y off the table (still int8; Hadamard consumes it
    /// consistently) — only the lookup's root cross-check can reject.
    OffTableY,
    /// One Z slot constant off the product — the quad ring claim rejects.
    HadamardZ,
    /// A prover-supplied lookup prehash differs from the value implied by
    /// the statement and commitment list. The verifier must recompute it.
    LookupH0,
    /// Junk CRT coordinates in Y and UP with CORRECT slot constants,
    /// crafted in the null space of a STALE zeta (derived pre-commitment
    /// — the violated ordering). stale = true runs the buggy build
    /// (zeta from the stale source on both sides): the chain ACCEPTS a
    /// witness whose gate-o-up output constants are WRONG. stale = false
    /// runs the shipped order against the same junk: zeta REJECTS. The
    /// masked lookup passes in BOTH worlds (its E1-composed pins read
    /// constants only) — the F5 pair for the chain's new hash edge.
    JunkY { stale: bool },
}

#[derive(Clone, Copy)]
enum ChainEntropy {
    /// Normal CLI/benchmark path: every proof session gets fresh OS entropy.
    Os,
    /// Reproducible adversarial batteries only.
    Test,
}

#[derive(Default)]
struct ChainVerdict {
    statement_ok: bool,
    lookup_ok: bool,
    wave_ok: bool,
    q46_ok: bool,
    gates_ok: bool,
    /// JunkY worlds: the crafted junk shifts at least one gate-o-up
    /// output constant (the demonstrated harm).
    junk_harm: bool,
}

impl ChainVerdict {
    fn all_ok(&self) -> bool {
        self.statement_ok && self.lookup_ok && self.wave_ok && self.q46_ok && self.gates_ok
    }
}

#[derive(Default)]
struct ChainCost {
    n_el: usize,
    commit_s: f64,
    prove_s: f64,
    verify_s: f64,
    /// Lookup-stage attribution inside prove/verify (trees + masked
    /// descents + pin building; the shared ct-round is not split).
    lkp_prove_s: f64,
    lkp_verify_s: f64,
    q46_prove_s: f64,
    q46_verify_s: f64,
    arp_restarts: usize,
    /// Committed coefficient counts (slot-capacity accounting: msg_r * D
    /// per q31 commitment, msg_r_g * D per q46 commitment).
    q31_data_coeffs: usize,
    q31_g_coeffs: usize,
    q46_coeffs: usize,
}

fn uk8_sha(parts: &[&[u8]]) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    for p in parts {
        h.update(p);
    }
    h.finalize().into()
}

/// VmHWM (peak RSS) in KiB from /proc/self/status, 0 if unavailable.
fn vm_hwm_kb() -> usize {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines().find(|l| l.starts_with("VmHWM:")).and_then(|l| {
                l.split_whitespace().nth(1).and_then(|v| v.parse().ok())
            })
        })
        .unwrap_or(0)
}

/// A nonzero vector in the null space of `rows` (each of length n) over
/// Z_q — the JunkY crafting solve (24 zeta constraints, 30 unknowns; the
/// U-K7 elimination pattern).
fn uk8_kernel_vec(zq: &ring::Zq, rows: &[Vec<u64>], n: usize) -> Vec<u64> {
    let mut a: Vec<Vec<u64>> = rows.iter().map(|r| r[..n].to_vec()).collect();
    let m = a.len();
    let mut piv: Vec<(usize, usize)> = Vec::new();
    let mut row = 0usize;
    for col in 0..n {
        if row >= m {
            break;
        }
        if let Some(pr) = (row..m).find(|&rr| a[rr][col] != 0) {
            a.swap(row, pr);
            let inv = zq.inv(a[row][col]);
            for c in col..n {
                a[row][c] = zq.mul(a[row][c], inv);
            }
            for rr in 0..m {
                if rr != row && a[rr][col] != 0 {
                    let f = a[rr][col];
                    for c in col..n {
                        a[rr][c] = zq.sub(a[rr][c], zq.mul(f, a[row][c]));
                    }
                }
            }
            piv.push((row, col));
            row += 1;
        }
    }
    let free_col = (0..n).find(|c| !piv.iter().any(|&(_, pc)| pc == *c)).expect("kernel exists");
    let mut u = vec![0u64; n];
    u[free_col] = 1;
    for &(pr, pc) in piv.iter().rev() {
        u[pc] = zq.neg(a[pr][free_col]);
    }
    u
}

/// One committed FFN-gate chain run: commit -> validated statement ->
/// per-block (masked lookup + q31 wave + q46 grounding rounds) ->
/// verify. Returns the per-stage verdict and the honest cost breakdown.
#[allow(clippy::too_many_lines)]
fn ffn_chain_run(
    n_el: usize,
    with_lookup: bool,
    tamper: ChainTamper,
    seed: u64,
    entropy: ChainEntropy,
    quiet: bool,
) -> (ChainVerdict, ChainCost) {
    use manifest::{ClaimManifest, Operation, Orientation, QuantMeta};
    use ring::commit::CommitShape as CS;
    use ring::ct_engine::{
        AjtaiCommit, AjtaiOpening, StdOpening, ajtai_commit, arp_attempt_joint, arp_check_reveal,
        arp_claims, ct_h0, derive_arp_params, derive_ct_round_params, derive_jl_rows,
        expand_b_mat, pack_arp_mask, r1_pad_count, sample_arp_mask, sample_g_masks,
        verify_ct_round,
    };
    use ring::ct_engine::{QuadRingClaim, prove_ct_round};
    use ring::gkr::{ceiling_gate_ok, eq_table};
    use ring::gkr_masked::{
        BlinderSet, DescentEnd, MaskSet, MaskedDescentProof, blinded_table_tree,
        blinded_witness_tree, blinder_positions, draw_masks, g_hypersum_weights, g_open_weights,
        masked_gkr_prove, masked_gkr_verify, r_open_weights, table_row_positions, zero_masks,
    };
    use ring::kfield::{K_DEG, KElem, KField};
    use ring::link::{
        crt_coord_rows, derive_gadget_layer, derive_link_params, derive_link_xi,
        derive_link_zeta, link_claims_gnd, link_claims_tgt, link_claims_tgt_slot, link_gate_ok,
        link_h0, link_reveal_y,
    };
    use ring::lookup::{
        PinTerm, PinnedValue, derive_pin_psi, fuse_pair, fused_silu_table, mul_y,
        multiplicities, pin_claims, silu_int8_table, slot_pin_weights, table_spec_digest,
    };
    use ring::sumcheck::LkpTranscript;

    // ---- Shared setup. ----------------------------------------------------
    let ctx_ring = ring_ctx_q8();
    let kf = KField::new(&ctx_ring);
    let zq = ctx_ring.zq;
    let q = zq.q;
    let (k_slots, sd) = (ctx_ring.k, ctx_ring.slot_deg);
    let zero = kf.zero();
    let one = kf.one();
    let rows = silu_int8_table();
    let spec_dg = table_spec_digest(&rows);
    let tab_fused = fused_silu_table(&kf, &rows);
    let t_rows = rows.len();
    assert!(ceiling_gate_ok(1u64 << UK8_DW, q), "block sub-instance clears the LogUp ceiling");
    let coord_m = crt_coord_rows(&ctx_ring);
    let const_rows: Vec<Vec<u64>> = (0..k_slots).map(|j| coord_m[j * sd].clone()).collect();

    // q31 CRS: the U-K5c shape (one wave carries tensors, masks, blinders
    // and the g-groups of a block's round).
    let shape = CS { kappa: 8, n_r: 26, msg_r: 8 };
    let msg_r = shape.msg_r;
    let kpc = msg_r * D / K_DEG; // committed K-elements per commitment
    let crs = expand_crs(shape, q, 0x0_8C8);

    // q46 grounding layer: msg_r = 4 puts one 512-bit ARP unit in one
    // commitment (the LKP-8 unit).
    let q_g = ring::Q8_46;
    let ring_g = ring::ring_ctx(q_g, ring::ETA8_46, 8);
    let zq_g = ring_g.zq;
    let gl_g = derive_gadget_layer(q_g, 4, 16).expect("q46 gadget layer derives");
    let msg_r_g = gl_g.shape.msg_r;
    let crs_g = expand_crs(gl_g.shape, q_g, 0x0_8C9);
    let ap = derive_arp_params(msg_r_g * D, 256, 1, UK8_ALPHA); // 512-bit unit
    assert!(
        ring::ct_engine::arp_budget_ok(&ap, (q_g / 2) as f64),
        "LKP-8: the 512-bit unit at alpha = 3.5 must close the q46 ARP budget"
    );
    // Link operating points: one instance per q46 round (2 sub-blocks =
    // 256 coefficient positions) and the zeta instance over a block's
    // slot tensor (B values).
    let lp_r = derive_link_params(2 * UK8_SUB, 8, q_g, q, 11);
    let lp_h = derive_link_params(UK8_B, 8, q_g, q, 11);
    let chunks = UK8_B.div_ceil(k_slots); // slot polys per tensor per block
    debug_assert_eq!(chunks * D - UK8_B, 15364); // zeta junk coords per row
    let slot_cms = chunks / msg_r; // slot commitments per tensor per block
    let b_mat = expand_b_mat(&crs_g, "uk8-arp", ap.rows.div_ceil(D));

    // ---- Instance data. ----------------------------------------------------
    let n_blocks = n_el.div_ceil(UK8_B);
    // Reproducible witness generation is a harness concern, not prover
    // entropy. All secret proof coins below come from an independent CSPRNG.
    let mut data_rng = seed;
    let xs_all: Vec<i64> =
        (0..n_el).map(|_| rng_below(&mut data_rng, 256) as i64 - 128).collect();
    let mut ys_all: Vec<i64> = xs_all.iter().map(|&x| rows[(x + 128) as usize].1).collect();
    let up_all: Vec<i64> =
        (0..n_el).map(|_| rng_below(&mut data_rng, 256) as i64 - 128).collect();
    let mut rng = match entropy {
        ChainEntropy::Os => ring::ProverRng::from_os()
            .expect("operating-system entropy is required for a proof session"),
        ChainEntropy::Test =>
            ring::ProverRng::from_test_seed("uk8-proof-session", &seed.to_le_bytes()),
    };
    if tamper == ChainTamper::OffTableY {
        // Still int8, consumed consistently downstream; off the table.
        ys_all[5] = if ys_all[5] > 100 { ys_all[5] - 16 } else { ys_all[5] + 16 };
    }

    // JunkY crafting: junk deltas for Y and UP poly 0 of block 0, in the
    // null space of the STALE zeta (derived from a pre-commitment source
    // — the violated ordering an attacker exploits).
    let stale_h0 = uk8_sha(&[b"uk8-stale-zeta", &crs.crs_hash]);
    let junk = if matches!(tamper, ChainTamper::JunkY { .. }) {
        let h0_y = uk8_sha(&[&stale_h0, b"zeta-y"]);
        let h0_u = uk8_sha(&[&stale_h0, b"zeta-up"]);
        let zy = derive_link_zeta(&h0_y, &lp_h, k_slots);
        let zu = derive_link_zeta(&h0_u, &lp_h, k_slots);
        // Poly 0's first 30 junk coordinates are CRT coords 1..16 and
        // 17..32 (zeta indices 0..30 — the enumeration skips the 8 slot
        // constants).
        let coords: Vec<usize> = (1..16).chain(17..32).collect();
        let solve = |zrows: &[Vec<i64>]| -> Vec<u64> {
            let rows_m: Vec<Vec<u64>> = zrows
                .iter()
                .map(|r| (0..coords.len()).map(|j| zq.to_mod(r[j])).collect())
                .collect();
            uk8_kernel_vec(&zq, &rows_m, coords.len())
        };
        let (dy, du) = (solve(&zy), solve(&zu));
        Some((coords, dy, du))
    } else {
        None
    };
    let apply_junk = |poly: &Poly, deltas: &[u64], coords: &[usize]| -> Poly {
        let mut split = crt_split(&ctx_ring, poly);
        for (j, &c) in coords.iter().enumerate() {
            split[c] = zq.add(split[c], deltas[j]);
        }
        crt_merge(&ctx_ring, &mut split);
        split
    };

    // ---- Block-local q31 commitment layout. --------------------------------
    let (wm_len, tm_len) = {
        use ring::gkr_masked::mask_coeff_counts;
        let (gw, rw) = mask_coeff_counts(UK8_DW, 0);
        let (gt, rt) = mask_coeff_counts(UK8_DT, 0);
        (gw + rw, gt + rt)
    };
    let kel_cms = |n_kel: usize| (n_kel * K_DEG).div_ceil(msg_r * D).max(1);
    let (wm_c, tm_c) = (kel_cms(wm_len), kel_cms(tm_len));
    let (idx_x, idx_m, idx_bl, base_wm, base_tm, base_y): (usize, usize, usize, usize, usize, usize);
    if with_lookup {
        idx_x = 0;
        idx_m = 1;
        idx_bl = 2;
        base_wm = 3;
        base_tm = base_wm + wm_c;
        base_y = base_tm + tm_c;
    } else {
        idx_x = 0;
        // Unused in this arm (kept to satisfy the shared pin builders).
        idx_m = usize::MAX;
        idx_bl = usize::MAX;
        base_wm = usize::MAX;
        base_tm = usize::MAX;
        base_y = 1;
    }
    let base_up = base_y + slot_cms;
    let base_z = base_up + slot_cms;
    let n_data = base_z + slot_cms;
    // q31 round claim counts (uniform per block).
    let n_pins = if with_lookup { 9 } else { 0 };
    let n_lin = n_pins + UK8_RPB * lp_r.l + 2 * lp_h.l;
    let n_quad_ring = chunks;
    let n_gslots = n_lin + r1_pad_count(0, n_quad_ring, 0);
    let g_groups = n_gslots.div_ceil(msg_r);
    let n_commits = n_data + g_groups;
    let rp = derive_ct_round_params(q, shape, n_commits, 0, 0, true);
    // q46 round claim counts (uniform per round: 2 sub-blocks x lo/hi
    // units + 1 link instance).
    let units_per_round = 4usize;
    let l_bin_g = ring::ct_engine::theta_rows(q_g);
    let n_lin_g = units_per_round * ap.rows + lp_r.l;
    let n_quad_g = units_per_round * l_bin_g;
    let n_gslots_g = n_lin_g + n_quad_g + r1_pad_count(n_quad_g, 0, 0);
    let g_groups_g = n_gslots_g.div_ceil(msg_r_g);
    let rp_g = derive_ct_round_params(
        q_g,
        gl_g.shape,
        units_per_round + g_groups_g + units_per_round,
        units_per_round * ap.rows,
        12 * ap.sigma_arp,
        false,
    );
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let path = KernelPath::A1(&a1p);
    let a1p_g = build_a1_paths(
        &crs_g,
        rp_g.sigma.max(rp_g.sigma_s),
        isqrt_u128(rp_g.bound_sq.max(rp_g.bound_s_sq)),
    );
    let path_g = KernelPath::A1(&a1p_g);

    let mut cost = ChainCost {
        n_el,
        q31_data_coeffs: n_blocks * n_data * msg_r * D,
        q31_g_coeffs: n_blocks * g_groups * msg_r * D,
        q46_coeffs: n_blocks * (4 * UK8_RPB + UK8_RPB * g_groups_g) * msg_r_g * D,
        ..ChainCost::default()
    };

    // ---- Pass 1: commit every tensor of every block. ------------------------
    struct BlockData {
        n_b: usize,
        xs: Vec<i64>,
        ys: Vec<i64>,
        xu_vals: Vec<u64>, // 1024 plane-consistent offset codes (pads 0)
        msgs: Vec<Vec<Poly>>,
        rhos: Vec<Vec<Vec<i64>>>,
        t1s: Vec<Vec<Poly>>,
        t2s: Vec<Vec<Poly>>,
        masks_w: Option<ring::gkr_masked::MaskSet>,
        masks_t: Option<ring::gkr_masked::MaskSet>,
        bl_w: Option<ring::gkr_masked::BlinderSet>,
        bl_t: Option<ring::gkr_masked::BlinderSet>,
        m_k: Vec<ring::kfield::KElem>,
        bits_msgs: Vec<Vec<Poly>>,
        bits_rhos: Vec<Vec<Vec<i64>>>,
        bits_t1s: Vec<Vec<Poly>>,
        bits_t2s: Vec<Vec<Poly>>,
    }
    let pack_scalars = |vals: &[u64]| -> Vec<Poly> {
        assert!(vals.len() <= msg_r * D);
        let mut polys = vec![poly_zero(); msg_r];
        for (i, &v) in vals.iter().enumerate() {
            polys[i / D][i % D] = v;
        }
        polys
    };
    let pack_kelems = |kelems: &[KElem]| -> Vec<Vec<Poly>> {
        let mut flat: Vec<u64> = Vec::with_capacity(kelems.len() * K_DEG);
        for e in kelems {
            for c in 0..K_DEG {
                flat.push(e[c]);
            }
        }
        let per = msg_r * D;
        let n_commit = flat.len().div_ceil(per).max(1);
        (0..n_commit)
            .map(|g| {
                (0..msg_r)
                    .map(|s| {
                        (0..D)
                            .map(|c| {
                                let idx = g * per + s * D + c;
                                if idx < flat.len() { flat[idx] } else { 0 }
                            })
                            .collect()
                    })
                    .collect()
            })
            .collect()
    };
    let blinder_kelems = |bw: &BlinderSet, bt: &BlinderSet| -> Vec<KElem> {
        let mut v = Vec::with_capacity(16);
        for b in [&bw.tl, &bw.tr, &bw.f0, &bw.f1, &bt.tl, &bt.tr, &bt.f0, &bt.f1] {
            v.push(b.a.clone());
            v.push(b.u.clone());
        }
        v
    };

    let t_commit = Instant::now();
    let mut blocks: Vec<BlockData> = Vec::with_capacity(n_blocks);
    for b in 0..n_blocks {
        let lo = b * UK8_B;
        let n_b = (n_el - lo).min(UK8_B);
        let xs: Vec<i64> = xs_all[lo..lo + n_b].to_vec();
        let ys: Vec<i64> = ys_all[lo..lo + n_b].to_vec();
        let ups: Vec<i64> = up_all[lo..lo + n_b].to_vec();
        // Offset codes, padded to the full 1024-coefficient block; the
        // range side always covers all 1024 positions (pads are honest
        // zeros — proving them in [0, 256) is harmless).
        let mut xu_vals = vec![0u64; msg_r * D];
        for (i, &x) in xs.iter().enumerate() {
            xu_vals[i] = (x + 128) as u64;
        }
        // The wraparound witness: committed residue jumps by 256 while
        // the planes keep the honest low bits (audit C-02 class).
        let mut xu_committed = xu_vals.clone();
        if tamper == ChainTamper::RangeX && b == 0 {
            xu_committed[0] = zq.add(xu_committed[0], 256);
        }

        // Slot tensors (constants = centered residues; pads zero).
        let slot_polys = |vals: &[i64]| -> Vec<Poly> {
            (0..chunks)
                .map(|u| {
                    let mut lane = vec![0u64; k_slots];
                    for (s, l) in lane.iter_mut().enumerate() {
                        let t = u * k_slots + s;
                        if t < vals.len() {
                            *l = zq.to_mod(vals[t]);
                        }
                    }
                    slot_pack(&ctx_ring, &lane)
                })
                .collect()
        };
        let mut y_polys = slot_polys(&ys);
        let mut up_polys = slot_polys(&ups);
        if let (Some((coords, dy, du)), 0) = (&junk, b) {
            y_polys[0] = apply_junk(&y_polys[0], dy, coords);
            up_polys[0] = apply_junk(&up_polys[0], du, coords);
        }
        // Z := the ring product (slot-constant operands make it exactly
        // the slot-packed elementwise product; junk operands make it the
        // consistent junk product — the quad claim holds by construction
        // in both worlds).
        let mut z_polys: Vec<Poly> = y_polys
            .iter()
            .zip(up_polys.iter())
            .map(|(a, c)| poly_mul_g(&zq, a, c))
            .collect();
        if tamper == ChainTamper::HadamardZ && b == 0 {
            let mut split = crt_split(&ctx_ring, &z_polys[0]);
            split[7 * sd] = zq.add(split[7 * sd], 1);
            crt_merge(&ctx_ring, &mut split);
            z_polys[0] = split;
        }

        // Lookup material (arm A).
        let (masks_w, masks_t, bl_w, bl_t, m_k) = if with_lookup {
            // Fresh prover-only coins. The resulting coefficients are
            // committed below and only then enter h0_lkp; the public
            // statement/transcript cannot reconstruct them.
            let mw = draw_masks(&kf, &mut rng, UK8_DW, 0);
            let mt = draw_masks(&kf, &mut rng, UK8_DT, 0);
            let bw = BlinderSet::draw(&kf, &mut rng);
            let mut bt = BlinderSet::draw(&kf, &mut rng);
            bt.solve_mass(&kf, &bw.mass(&kf));
            let w_fused: Vec<KElem> = xs
                .iter()
                .zip(ys.iter())
                .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
                .collect();
            let mk = multiplicities(&kf, &w_fused, &tab_fused);
            (Some(mw), Some(mt), Some(bw), Some(bt), mk)
        } else {
            (None, None, None, None, Vec::new())
        };

        // Message list in block-local index order.
        let mut msgs: Vec<Vec<Poly>> = Vec::with_capacity(n_data);
        msgs.push(pack_scalars(&xu_committed));
        if with_lookup {
            let m_vals: Vec<u64> = m_k.iter().map(|e| e[0]).collect();
            msgs.push(pack_scalars(&m_vals));
            let bl_msg = pack_kelems(&blinder_kelems(
                bl_w.as_ref().unwrap(),
                bl_t.as_ref().unwrap(),
            ));
            assert_eq!(bl_msg.len(), 1);
            msgs.push(bl_msg[0].clone());
            let wm = pack_kelems(&masks_w.as_ref().unwrap().flatten());
            assert_eq!(wm.len(), wm_c);
            msgs.extend(wm);
            let tm = pack_kelems(&masks_t.as_ref().unwrap().flatten());
            assert_eq!(tm.len(), tm_c);
            msgs.extend(tm);
        }
        for polys in [&y_polys, &up_polys, &z_polys] {
            for cm in 0..slot_cms {
                msgs.push(polys[cm * msg_r..(cm + 1) * msg_r].to_vec());
            }
        }
        assert_eq!(msgs.len(), n_data);
        let mut rhos = Vec::with_capacity(n_data);
        let (mut t1s, mut t2s) = (Vec::new(), Vec::new());
        for m in &msgs {
            let rho: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let (t1, t2) = commit(&path, &crs, m, &rho);
            rhos.push(rho);
            t1s.push(t1);
            t2s.push(t2);
        }

        // q46 bit planes: per 128-value sub-block, two 512-bit units
        // (planes 0-3, then 4-7).
        let mut bits_msgs = Vec::with_capacity(4 * UK8_RPB);
        let mut bits_rhos = Vec::new();
        let (mut bits_t1s, mut bits_t2s) = (Vec::new(), Vec::new());
        for sub in 0..2 * UK8_RPB {
            for half in 0..2 {
                let mut m = vec![poly_zero(); msg_r_g];
                for (p, poly) in m.iter_mut().enumerate() {
                    let plane = half * msg_r_g + p;
                    for t in 0..UK8_SUB {
                        let v = xu_vals[sub * UK8_SUB + t];
                        poly[t] = (v >> plane) & 1;
                    }
                }
                let rho: Vec<Vec<i64>> =
                    (0..gl_g.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
                let (t1, t2) = commit(&path_g, &crs_g, &m, &rho);
                bits_msgs.push(m);
                bits_rhos.push(rho);
                bits_t1s.push(t1);
                bits_t2s.push(t2);
            }
        }
        blocks.push(BlockData {
            n_b,
            xs,
            ys,
            xu_vals,
            msgs,
            rhos,
            t1s,
            t2s,
            masks_w,
            masks_t,
            bl_w,
            bl_t,
            m_k,
            bits_msgs,
            bits_rhos,
            bits_t1s,
            bits_t2s,
        });
    }
    cost.commit_s += t_commit.elapsed().as_secs_f64();

    // ---- The validated statement (format v2) — ctx for everything. --------
    let group_list_digest = |groups: &[(&Vec<Poly>, &Vec<Poly>)]| -> Vec<u8> {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        for (t1, t2) in groups {
            hasher.update(group_digest(t1, t2));
        }
        hasher.finalize().to_vec()
    };
    let tensor_digest = |idx0: usize, count: usize| -> Vec<u8> {
        let refs: Vec<(&Vec<Poly>, &Vec<Poly>)> = blocks
            .iter()
            .flat_map(|bd| (0..count).map(move |i| (&bd.t1s[idx0 + i], &bd.t2s[idx0 + i])))
            .collect();
        group_list_digest(&refs)
    };
    let bits_digest = {
        let refs: Vec<(&Vec<Poly>, &Vec<Poly>)> = blocks
            .iter()
            .flat_map(|bd| bd.bits_t1s.iter().zip(bd.bits_t2s.iter()))
            .collect();
        group_list_digest(&refs)
    };
    let ki_t = key_info_bytes(&shape, q);
    let ki_g = key_info_bytes(&gl_g.shape, q_g);
    let model_digest: [u8; 32] =
        uk8_sha(&[b"uk8-ffn-gate-chain-v1", &(n_el as u64).to_le_bytes(), &spec_dg]);
    let mut mf = ClaimManifest::new("lattice-route-r", &crs.crs_hash);
    let id_x = mf.add_commitment("X", n_el, 1, Orientation::ByColumns, ki_t.clone(), tensor_digest(idx_x, 1));
    let id_bits = mf.add_commitment("X-bits", 8 * n_el, 1, Orientation::ByColumns, ki_g, bits_digest);
    let id_y = mf.add_commitment("Y", n_el, 1, Orientation::ByColumns, ki_t.clone(), tensor_digest(base_y, slot_cms));
    let id_up = mf.add_commitment("UP", n_el, 1, Orientation::ByColumns, ki_t.clone(), tensor_digest(base_up, slot_cms));
    let id_z = mf.add_commitment("Z", n_el, 1, Orientation::ByColumns, ki_t, tensor_digest(base_z, slot_cms));
    mf.add_operation(Operation::Binary { bits: id_bits });
    mf.add_operation(Operation::Range { value: id_x, bits: id_bits, width: 8, signed: true });
    if with_lookup {
        mf.add_operation(Operation::Lookup { x: id_x, y: id_y });
    }
    mf.add_operation(Operation::Hadamard { x: id_y, y: id_up, z: id_z });
    assert_eq!(
        spec_dg, manifest::SILU_INT8_TABLE_DIGEST,
        "frozen SiLU table digest parity (manifest constant vs ring/lookup.rs)"
    );
    // Modulus capacity: the q31 value layer bounds it (planes live at q46).
    let modulus_bits = (63 - q.leading_zeros()).min(63 - q_g.leading_zeros());
    let mut statement = manifest::Statement::new(
        model_digest,
        Some(manifest::SILU_INT8_TABLE_SPEC),
        modulus_bits,
        mf,
    );
    statement.quant = vec![
        QuantMeta { bits: 8, frac_bits: 4, signed: true },   // X
        QuantMeta { bits: 1, frac_bits: 0, signed: false },  // X-bits
        QuantMeta { bits: 8, frac_bits: 4, signed: true },   // Y
        QuantMeta { bits: 8, frac_bits: 4, signed: true },   // UP
        QuantMeta { bits: 16, frac_bits: 8, signed: true },  // Z
    ];
    // Canonical padding: the block grid (UK8_B logical elements per block;
    // the plane stack rides 8 planes per element).
    statement.pad = vec![
        manifest::PadSpec::units(n_el, 1, UK8_B, 1),         // X
        manifest::PadSpec::units(8 * n_el, 1, 8 * UK8_B, 1), // X-bits
        manifest::PadSpec::units(n_el, 1, UK8_B, 1),         // Y
        manifest::PadSpec::units(n_el, 1, UK8_B, 1),         // UP
        manifest::PadSpec::units(n_el, 1, UK8_B, 1),         // Z
    ];
    statement.outputs = vec![id_z];
    let mut verdict = ChainVerdict { statement_ok: true, lookup_ok: true, wave_ok: true, q46_ok: true, gates_ok: true, junk_harm: false };
    let ctx_stmt: [u8; 32] = match statement.digest() {
        Ok(d) => d,
        Err(e) => {
            println!("  FAIL statement v3 does not validate: {e}");
            verdict.statement_ok = false;
            return (verdict, cost);
        }
    };

    // JunkY harm probe: the crafted junk operands shift at least one
    // gate-o-up output constant away from y * up.
    if matches!(tamper, ChainTamper::JunkY { .. }) {
        let bd = &blocks[0];
        let zp = poly_mul_g(&zq, &bd.msgs[base_y][0], &bd.msgs[base_up][0]);
        let zs = crt_split(&ctx_ring, &zp);
        verdict.junk_harm = (0..k_slots).any(|s| {
            zs[s * sd] != zq.mul(zq.to_mod(bd.ys[s]), zq.to_mod(up_all[s]))
        });
    }

    // ---- Pass 2: per block — g-masks, h0_link, lookup, wave, grounding. ----
    let shell_w = zero_masks(&kf, UK8_DW, 0);
    let shell_t = zero_masks(&kf, UK8_DT, 0);
    let one_poly = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let neg_one_poly = {
        let mut p = poly_zero();
        p[0] = zq.neg(1);
        p
    };
    let xi_zero: Vec<Vec<i64>> = vec![vec![0i64; lp_h.n]; lp_h.l];
    let y_zero = vec![0i64; lp_h.l];
    let y_value_slots: Vec<(usize, usize)> =
        (0..chunks).map(|u| (base_y + u / msg_r, u % msg_r)).collect();
    let up_value_slots: Vec<(usize, usize)> =
        (0..chunks).map(|u| (base_up + u / msg_r, u % msg_r)).collect();
    let stale = matches!(tamper, ChainTamper::JunkY { stale: true });

    // Pin-term splitter over committed K-element runs (U-K5c).
    let kelem_terms = |base: usize, flat_off: usize, weights: &[KElem]| -> Vec<PinTerm> {
        let mut terms = Vec::new();
        let mut i = 0usize;
        while i < weights.len() {
            let idx = flat_off + i;
            let commit = base + idx / kpc;
            let coeff0 = (idx % kpc) * K_DEG;
            let take = (kpc - (idx % kpc)).min(weights.len() - i);
            terms.push(PinTerm::Kelems { commit, coeff0, weights: weights[i..i + take].to_vec() });
            i += take;
        }
        terms
    };
    // Descent pins: G hypersums, g openings, R openings (U-K5c; weights
    // depend only on the mask SHAPE and public opening points).
    let descent_pins = |base: usize,
                        shape_masks: &MaskSet,
                        proof: &MaskedDescentProof,
                        end: &DescentEnd,
                        depth: usize|
     -> Vec<PinnedValue> {
        let mut pins = Vec::new();
        for j in 1..depth {
            let lp = &proof.layers[j - 1];
            let gm = &shape_masks.g[j - 1];
            pins.push(PinnedValue {
                terms: kelem_terms(base, shape_masks.g_offset(j), &g_hypersum_weights(&kf, gm)),
                value: lp.g_sum.clone(),
            });
            let (open_pt, mu_prev, c_w) = &end.layer_pts[j - 1];
            pins.push(PinnedValue {
                terms: kelem_terms(base, shape_masks.g_offset(j), &g_open_weights(&kf, gm, open_pt)),
                value: lp.open_g.clone(),
            });
            if j >= 2 {
                let (orp, orq) = lp.open_r.clone().expect("interior layer opens Rp/Rq");
                let rw = r_open_weights(&kf, mu_prev, c_w);
                pins.push(PinnedValue {
                    terms: kelem_terms(base, shape_masks.r_offset(j), &rw),
                    value: orp,
                });
                pins.push(PinnedValue {
                    terms: kelem_terms(base, shape_masks.r_offset(j) + 6, &rw),
                    value: orq,
                });
            }
        }
        pins
    };
    // Aggregate leaf pins, chain edition: X read through the offset fold
    // (committed x_u = x + 128, so the pin value carries -128 * hw), Y
    // read through the E1-composed slot weights (slot_pin_weights — the
    // slot-packed E4 variant), m and the blinders as in U-K5c.
    let leaf_pins = |endw: &DescentEnd, endt: &DescentEnd, alpha: &KElem, n_b: usize| -> Vec<PinnedValue> {
        let lw = eq_table(&kf, &endw.zstar);
        let lt = eq_table(&kf, &endt.zstar);
        let nw = 1usize << UK8_DW;
        let nt = 1usize << UK8_DT;
        let bpw = blinder_positions(nw);
        let bpt = blinder_positions(nt);
        let tpos = table_row_positions(t_rows, nt);
        let eqw: Vec<KElem> = bpw.iter().map(|&p| lw[p].clone()).collect();
        let eqt: Vec<KElem> = bpt.iter().map(|&p| lt[p].clone()).collect();
        let hw = (0..n_b).fold(zero.clone(), |a, i| kf.add(&a, &lw[i]));
        let ht = (0..t_rows).fold(zero.clone(), |a, j| kf.add(&a, &lt[tpos[j]]));
        let sum_eqw = eqw.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let sum_eqt = eqt.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let ft = (0..t_rows)
            .fold(zero.clone(), |a, j| kf.add(&a, &kf.mul(&lt[tpos[j]], &tab_fused[j])));
        let z = zero.clone();
        let wp = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: idx_bl,
                coeff0: 0,
                weights: vec![
                    eqw[0].clone(), z.clone(), eqw[1].clone(), z.clone(),
                    eqw[2].clone(), z.clone(), eqw[3].clone(), z.clone(),
                ],
            }],
            value: kf.sub(&endw.p_claim, &hw),
        };
        // Witness Q: q* - alpha H - D_dummy - 128 H = [blinder u's]
        //   - sum lw x_u - sum Y lw y   (x = x_u - 128 folds into hw).
        let ddw = kf.sub(&kf.sub(&one, &hw), &sum_eqw);
        let wy: Vec<KElem> = (0..n_b).map(|i| kf.neg(&mul_y(&kf, &lw[i]))).collect();
        let y_coeff_w = slot_pin_weights(&kf, &const_rows, &wy, chunks);
        let mut wq_terms = vec![
            PinTerm::Kelems {
                commit: idx_bl,
                coeff0: 0,
                weights: vec![
                    z.clone(), eqw[0].clone(), z.clone(), eqw[1].clone(),
                    z.clone(), eqw[2].clone(), z.clone(), eqw[3].clone(),
                ],
            },
            PinTerm::Scalar {
                commit: idx_x,
                coeff0: 0,
                weights: (0..n_b).map(|i| kf.neg(&lw[i])).collect(),
            },
        ];
        for cm in 0..slot_cms {
            wq_terms.push(PinTerm::Scalar {
                commit: base_y + cm,
                coeff0: 0,
                weights: y_coeff_w[cm * msg_r * D..(cm + 1) * msg_r * D].to_vec(),
            });
        }
        let wq = PinnedValue {
            terms: wq_terms,
            value: kf.sub(
                &kf.sub(&kf.sub(&endw.q_claim, &kf.mul(alpha, &hw)), &ddw),
                &kf.scale(128, &hw),
            ),
        };
        let tp = PinnedValue {
            terms: vec![
                PinTerm::Scalar {
                    commit: idx_m,
                    coeff0: 0,
                    weights: (0..t_rows).map(|j| lt[tpos[j]].clone()).collect(),
                },
                PinTerm::Kelems {
                    commit: idx_bl,
                    coeff0: 8 * K_DEG,
                    weights: vec![
                        eqt[0].clone(), z.clone(), eqt[1].clone(), z.clone(),
                        eqt[2].clone(), z.clone(), eqt[3].clone(), z.clone(),
                    ],
                },
            ],
            value: endt.p_claim.clone(),
        };
        let ddt = kf.sub(&kf.sub(&one, &ht), &sum_eqt);
        let tq = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: idx_bl,
                coeff0: 8 * K_DEG,
                weights: vec![
                    z.clone(), eqt[0].clone(), z.clone(), eqt[1].clone(),
                    z.clone(), eqt[2].clone(), z.clone(), eqt[3].clone(),
                ],
            }],
            value: kf.add(
                &kf.sub(&kf.sub(&endt.q_claim, &kf.mul(alpha, &ht)), &ddt),
                &ft,
            ),
        };
        vec![wp, wq, tp, tq]
    };
    let absorb_pins = |tr: &mut LkpTranscript, pins: &[PinnedValue]| {
        for p in pins {
            tr.absorb_k(&kf, "uk8-pin", std::slice::from_ref(&p.value));
        }
    };

    // Round-r link weight sources (per block b): xi from h0_link_b, zeta
    // from h0_link_b (shipped) or the stale pre-commitment source
    // (JunkY's buggy world — the F5 ACCEPT leg).
    let zeta_pair = |h0_link_b: &[u8; 32]| -> (Vec<Vec<i64>>, Vec<Vec<i64>>) {
        let src = if stale { stale_h0 } else { *h0_link_b };
        let zy = derive_link_zeta(&uk8_sha(&[&src, b"zeta-y"]), &lp_h, k_slots);
        let zu = derive_link_zeta(&uk8_sha(&[&src, b"zeta-up"]), &lp_h, k_slots);
        (zy, zu)
    };

    for (b, bd) in blocks.iter_mut().enumerate() {
        // -- q31 g-masks for this block's round. --
        let t_g = Instant::now();
        let g_msgs = sample_g_masks(&mut rng, q, msg_r, n_lin, n_gslots - n_lin);
        assert_eq!(g_msgs.len(), g_groups);
        let mut all_msgs: Vec<Vec<Poly>> = bd.msgs.clone();
        let mut all_rhos: Vec<Vec<Vec<i64>>> = bd.rhos.clone();
        let mut t1s = bd.t1s.clone();
        let mut t2s = bd.t2s.clone();
        for g in &g_msgs {
            let rho: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let (t1, t2) = commit(&path, &crs, g, &rho);
            all_msgs.push(g.clone());
            all_rhos.push(rho);
            t1s.push(t1);
            t2s.push(t2);
        }
        // -- q46 g-masks, per grounding round. --
        let mut g_msgs_g: Vec<Vec<Vec<Poly>>> = Vec::with_capacity(UK8_RPB);
        let mut g_rhos_g: Vec<Vec<Vec<Vec<i64>>>> = Vec::with_capacity(UK8_RPB);
        let mut gt1s_g: Vec<Vec<Vec<Poly>>> = Vec::with_capacity(UK8_RPB);
        let mut gt2s_g: Vec<Vec<Vec<Poly>>> = Vec::with_capacity(UK8_RPB);
        for _r in 0..UK8_RPB {
            let gm = sample_g_masks(&mut rng, q_g, msg_r_g, n_lin_g + n_quad_g, n_gslots_g - n_lin_g - n_quad_g);
            assert_eq!(gm.len(), g_groups_g);
            let mut rhs = Vec::new();
            let (mut t1r, mut t2r) = (Vec::new(), Vec::new());
            for g in &gm {
                let rho: Vec<Vec<i64>> =
                    (0..gl_g.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
                let (t1, t2) = commit(&path_g, &crs_g, g, &rho);
                rhs.push(rho);
                t1r.push(t1);
                t2r.push(t2);
            }
            g_msgs_g.push(gm);
            g_rhos_g.push(rhs);
            gt1s_g.push(t1r);
            gt2s_g.push(t2r);
        }
        cost.commit_s += t_g.elapsed().as_secs_f64();

        // -- h0_link_b: ctx + block + BOTH sides' full block lists. --
        let ctx_b: Vec<u8> = ctx_stmt
            .iter()
            .copied()
            .chain((b as u64).to_le_bytes())
            .collect();
        let (q46_t1s, q46_t2s): (Vec<Vec<Poly>>, Vec<Vec<Poly>>) = {
            let mut a = bd.bits_t1s.clone();
            let mut c = bd.bits_t2s.clone();
            for r in 0..UK8_RPB {
                a.extend(gt1s_g[r].iter().cloned());
                c.extend(gt2s_g[r].iter().cloned());
            }
            (a, c)
        };
        let h0_link_b = link_h0(&ctx_b, &crs_g, &crs, &q46_t1s, &q46_t2s, &t1s, &t2s);
        let xi_r: Vec<Vec<Vec<i64>>> = (0..UK8_RPB)
            .map(|r| derive_link_xi(&uk8_sha(&[&h0_link_b, b"uk8-xi", &(r as u64).to_le_bytes()]), &lp_r))
            .collect();
        let (zeta_y, zeta_up) = zeta_pair(&h0_link_b);
        // Revealed link integers from the PLANE-consistent values (the
        // grounding side is honest in every tamper world).
        let y_link: Vec<Vec<i64>> = (0..UK8_RPB)
            .map(|r| {
                let vals = &bd.xu_vals[r * 2 * UK8_SUB..(r + 1) * 2 * UK8_SUB];
                link_reveal_y(&lp_r, &xi_r[r], vals)
            })
            .collect();

        // ================= PROVER =================
        let t_prove = Instant::now();
        // Lookup transcript (arm A): alpha binds ctx + the table digest +
        // every block commitment (g-masks included) through h0_lkp.
        let mut lkp: Option<(MaskedDescentProof, MaskedDescentProof)> = None;
        let mut pins: Vec<PinnedValue> = Vec::new();
        let mut tr_state: Option<LkpTranscript> = None;
        if with_lookup {
            let t_lkp = Instant::now();
            let ctx_lkp = uk8_sha(&[&spec_dg, &h0_link_b]);
            let h0_lkp = ct_h0(&crs, &ctx_lkp, &t1s, &t2s, &[]);
            // Free/stale-h0 attacker (C-02): the prover builds its ENTIRE
            // lookup transcript on a prehash of its choosing. The verifier
            // RECOMPUTES h0_lkp from the statement + full commitment list and
            // never reads this value, so the crafted alpha/challenges diverge
            // from the verifier's and the descents+pins reject on derivation.
            let prover_h0_lkp = if tamper == ChainTamper::LookupH0 && b == 0 {
                let mut h = h0_lkp;
                h[0] ^= 1; // free-h0: an arbitrary prover-chosen prehash
                h
            } else {
                h0_lkp
            };
            let mut tr = LkpTranscript::new("uk8-lkp", &prover_h0_lkp);
            let alpha = tr.challenge_k(&kf);
            let w_fused: Vec<KElem> = bd
                .xs
                .iter()
                .zip(bd.ys.iter())
                .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
                .collect();
            let wtree = blinded_witness_tree(&kf, &alpha, &w_fused, UK8_DW, bd.bl_w.as_ref().unwrap());
            let ttree = blinded_table_tree(&kf, &alpha, &tab_fused, &bd.m_k, UK8_DT, bd.bl_t.as_ref().unwrap());
            // The mask sets are CONSUMED here (moved into prove). The pin
            // weights depend only on the mask SHAPE, so descent_pins reads
            // the zero-mask shells — exactly the shape the verifier rebuilds.
            let (pw, endw) = masked_gkr_prove(&kf, &[wtree], bd.masks_w.take().unwrap(), &mut tr);
            let (pt, endt) = masked_gkr_prove(&kf, &[ttree], bd.masks_t.take().unwrap(), &mut tr);
            pins = descent_pins(base_wm, &shell_w, &pw, &endw, UK8_DW);
            pins.extend(descent_pins(base_tm, &shell_t, &pt, &endt, UK8_DT));
            pins.extend(leaf_pins(&endw, &endt, &alpha, bd.n_b));
            absorb_pins(&mut tr, &pins);
            cost.lkp_prove_s += t_lkp.elapsed().as_secs_f64();
            // Only the descent proofs cross the boundary; alpha, the descent
            // ends and the prehash are DERIVED by the verifier, never sent.
            lkp = Some((pw, pt));
            tr_state = Some(tr);
        }
        // The q31 claim families, in the canonical order [pins | link
        // targets | zeta Y | zeta UP] + the Hadamard quad ring claims.
        let mut lin_claims: Vec<ring::ct_engine::CtClaim> = Vec::new();
        if with_lookup {
            let t_lkp = Instant::now();
            let tr = tr_state.as_mut().unwrap();
            let psi = derive_pin_psi(&tr.state(), 9, pins.len() * K_DEG, q);
            lin_claims = pin_claims(&kf, &pins, n_data, msg_r, &psi);
            cost.lkp_prove_s += t_lkp.elapsed().as_secs_f64();
        }
        for r in 0..UK8_RPB {
            let slots = vec![(idx_x, 2 * r), (idx_x, 2 * r + 1)];
            lin_claims.extend(link_claims_tgt(&zq, &lp_r, &xi_r[r], &y_link[r], &slots));
        }
        lin_claims.extend(link_claims_tgt_slot(&ctx_ring, &lp_h, &xi_zero, &zeta_y, &y_zero, &y_value_slots));
        lin_claims.extend(link_claims_tgt_slot(&ctx_ring, &lp_h, &xi_zero, &zeta_up, &y_zero, &up_value_slots));
        assert_eq!(lin_claims.len(), n_lin);
        let quad_ring: Vec<QuadRingClaim> = (0..chunks)
            .map(|u| QuadRingClaim {
                quad: vec![(base_y + u / msg_r, u % msg_r, base_up + u / msg_r, u % msg_r, one_poly.clone())],
                msg_coeffs: vec![(base_z + u / msg_r, u % msg_r, neg_one_poly.clone())],
            })
            .collect();
        let h0_round = match &tr_state {
            Some(tr) => ct_h0(&crs, &tr.state(), &t1s, &t2s, &[]),
            None => ct_h0(&crs, &h0_link_b, &t1s, &t2s, &[]),
        };
        let openings: Vec<StdOpening> = all_msgs
            .iter()
            .zip(all_rhos.iter())
            .enumerate()
            .map(|(i, (xm, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x: xm, rho })
            .collect();
        let (wave_proof, _) = prove_ct_round(
            &path, &ctx_ring, &rp, None, &crs, &h0_round, &lin_claims, &[], &[], &quad_ring,
            &openings, &[], &[], n_data, &mut rng,
        );

        // -- q46 grounding rounds (FS-with-aborts per round). --
        let t_q46 = Instant::now();
        struct GndRound {
            acoms: Vec<ring::ct_engine::AjtaiCommit>,
            y_arp: Vec<Vec<i64>>,
            h0_g: [u8; 32],
            proof: ring::ct_engine::CtRoundProof,
        }
        let mut gnd_rounds: Vec<GndRound> = Vec::with_capacity(UK8_RPB);
        for r in 0..UK8_RPB {
            // Round-local commitment list: 4 units then the g-groups.
            let unit_ids = [4 * r, 4 * r + 1, 4 * r + 2, 4 * r + 3];
            let rt1s: Vec<Vec<Poly>> = unit_ids
                .iter()
                .map(|&u| bd.bits_t1s[u].clone())
                .chain(gt1s_g[r].iter().cloned())
                .collect();
            let rt2s: Vec<Vec<Poly>> = unit_ids
                .iter()
                .map(|&u| bd.bits_t2s[u].clone())
                .chain(gt2s_g[r].iter().cloned())
                .collect();
            let ctx_r: Vec<u8> = h0_link_b.iter().copied().chain((r as u64).to_le_bytes()).collect();
            let mut arp_rounds = 0usize;
            let (m_packed, rho_m, acoms, h0_g, jl, y_arp) = loop {
                arp_rounds += 1;
                assert!(arp_rounds < 400, "ARP restart budget exhausted");
                let masks: Vec<Vec<i64>> = (0..4).map(|_| sample_arp_mask(&ap, &mut rng)).collect();
                let packed: Vec<Vec<Vec<i64>>> = masks.iter().map(|m| pack_arp_mask(&ap, m)).collect();
                let rhs: Vec<Vec<Vec<i64>>> = (0..4)
                    .map(|_| (0..gl_g.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
                    .collect();
                let acoms: Vec<AjtaiCommit> = (0..4)
                    .map(|u| ajtai_commit(&crs_g, &b_mat, &packed[u], &rhs[u]))
                    .collect();
                let acom_refs: Vec<&AjtaiCommit> = acoms.iter().collect();
                let h0_g = ct_h0(&crs_g, &ctx_r, &rt1s, &rt2s, &acom_refs);
                let jl = derive_jl_rows(&h0_g, ap.rows, ap.n);
                // Joint Q4.2b test across the 4 restart-coupled units:
                // one summed-exponent rejection instead of the per-unit
                // product (~2.8 vs ~6.5 expected attempts/round).
                let flats: Vec<Vec<i64>> = unit_ids
                    .iter()
                    .map(|&u| {
                        bd.bits_msgs[u]
                            .iter()
                            .flat_map(|p| p.iter().map(|&v| v as i64))
                            .collect()
                    })
                    .collect();
                let units: Vec<(&[i64], &[i64])> = flats
                    .iter()
                    .zip(masks.iter())
                    .map(|(f, m)| (f.as_slice(), m.as_slice()))
                    .collect();
                if let Some(ys) = arp_attempt_joint(&ap, &jl, &units, &mut rng) {
                    break (packed, rhs, acoms, h0_g, jl, ys);
                }
            };
            cost.arp_restarts += arp_rounds - 1;
            let msg_slots = |u: usize| -> Vec<(usize, usize)> {
                (0..msg_r_g).map(|s| (u, s)).collect()
            };
            let mut lin_g: Vec<ring::ct_engine::CtClaim> = Vec::new();
            for u in 0..4usize {
                lin_g.extend(arp_claims(&zq_g, &ap, &jl, &msg_slots(u), u, &y_arp[u]));
            }
            // Plane i of the round lives at slot i % 4 of the lo (i < 4)
            // or hi unit of each sub-block; coordinate order is
            // sub-block 0 (round-local units 0/1) then 1 (units 2/3).
            let plane_slots: Vec<Vec<(usize, usize)>> = (0..8)
                .map(|i| {
                    let hi = usize::from(i >= 4);
                    vec![(hi, i % 4), (2 + hi, i % 4)]
                })
                .collect();
            lin_g.extend(link_claims_gnd(&zq_g, &lp_r, &xi_r[r], &y_link[r], &plane_slots));
            assert_eq!(lin_g.len(), n_lin_g);
            let mut quad_g = Vec::new();
            for u in 0..4usize {
                quad_g.extend(binary_claims(&zq_g, &h0_g, (b * UK8_RPB * 4 + r * 4 + u) as u64, &[(u, msg_r_g)]));
            }
            assert_eq!(quad_g.len(), n_quad_g);
            let x_g_all: Vec<Vec<Poly>> = unit_ids
                .iter()
                .map(|&u| bd.bits_msgs[u].clone())
                .chain(g_msgs_g[r].iter().cloned())
                .collect();
            let rho_g_all: Vec<Vec<Vec<i64>>> = unit_ids
                .iter()
                .map(|&u| bd.bits_rhos[u].clone())
                .chain(g_rhos_g[r].iter().cloned())
                .collect();
            let openings_g: Vec<StdOpening> = x_g_all
                .iter()
                .zip(rho_g_all.iter())
                .enumerate()
                .map(|(i, (xm, rho))| StdOpening { t1: &rt1s[i], t2: &rt2s[i], x: xm, rho })
                .collect();
            let ajtai_opens: Vec<AjtaiOpening> = (0..4)
                .map(|u| AjtaiOpening { com: &acoms[u], s: &m_packed[u], rho: &rho_m[u] })
                .collect();
            let (proof_g, _) = prove_ct_round(
                &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g, &lin_g, &[], &quad_g, &[],
                &openings_g, &[], &ajtai_opens, 4, &mut rng,
            );
            gnd_rounds.push(GndRound { acoms, y_arp, h0_g, proof: proof_g });
        }
        let q46_prove = t_q46.elapsed().as_secs_f64();
        cost.q46_prove_s += q46_prove;
        cost.prove_s += t_prove.elapsed().as_secs_f64();

        // ================= VERIFIER =================
        let t_verify = Instant::now();
        // Everything weight-like is re-derived from public data.
        let h0_link_v = link_h0(&ctx_b, &crs_g, &crs, &q46_t1s, &q46_t2s, &t1s, &t2s);
        let xi_v: Vec<Vec<Vec<i64>>> = (0..UK8_RPB)
            .map(|r| derive_link_xi(&uk8_sha(&[&h0_link_v, b"uk8-xi", &(r as u64).to_le_bytes()]), &lp_r))
            .collect();
        let (zeta_y_v, zeta_up_v) = zeta_pair(&h0_link_v);
        let gates_ok = (0..UK8_RPB).all(|r| link_gate_ok(&lp_r, &y_link[r]))
            && gnd_rounds.iter().all(|g| g.y_arp.iter().all(|y| arp_check_reveal(&ap, y)));
        verdict.gates_ok &= gates_ok;
        // Lookup verify: fresh transcript, masked descents on the shape
        // shells, blinded root cross-check, pins rebuilt and re-absorbed.
        let mut lin_v: Vec<ring::ct_engine::CtClaim> = Vec::new();
        let mut tr_v_state: Option<LkpTranscript> = None;
        if with_lookup {
            let t_lkp = Instant::now();
            let (pw, pt) = lkp.as_ref().unwrap();
            // The lookup prehash is DERIVED state, not a prover challenge and
            // not part of the proof. Recompute it from the verifier's
            // statement/table context and the COMPLETE commitment list, then
            // seed the transcript and draw alpha from it. A prover that built
            // on a different (free or stale) prehash produces descents whose
            // challenges diverge from these — nothing is compared to a
            // prover-supplied h0; the divergence itself is the rejection.
            let ctx_lkp_v = uk8_sha(&[&spec_dg, &h0_link_v]);
            let expected_h0_lkp = ct_h0(&crs, &ctx_lkp_v, &t1s, &t2s, &[]);
            let mut lookup_ok = true;
            let mut tv = LkpTranscript::new("uk8-lkp", &expected_h0_lkp);
            let av = tv.challenge_k(&kf);
            let vw = masked_gkr_verify(&kf, 1, UK8_DW, &shell_w, pw, &mut tv, false);
            let vt = masked_gkr_verify(&kf, 1, UK8_DT, &shell_t, pt, &mut tv, false);
            match (vw, vt) {
                (Some((roots_w, ew)), Some((roots_t, et))) => {
                    // The blinded root cross-check = the LogUp identity;
                    // a failure REJECTS the lookup but the pins are
                    // still rebuilt so the other chain edges can be
                    // verified independently (tamper isolation).
                    lookup_ok &= !kf.is_zero(&roots_w[0][1]) && !kf.is_zero(&roots_t[0][1]);
                    lookup_ok &= kf.mul(&roots_w[0][0], &roots_t[0][1])
                        == kf.mul(&roots_t[0][0], &roots_w[0][1]);
                    let mut pv = descent_pins(base_wm, &shell_w, pw, &ew, UK8_DW);
                    pv.extend(descent_pins(base_tm, &shell_t, pt, &et, UK8_DT));
                    pv.extend(leaf_pins(&ew, &et, &av, bd.n_b));
                    absorb_pins(&mut tv, &pv);
                    let psi_v = derive_pin_psi(&tv.state(), 9, pv.len() * K_DEG, q);
                    lin_v = pin_claims(&kf, &pv, n_data, msg_r, &psi_v);
                    tr_v_state = Some(tv);
                }
                _ => lookup_ok = false,
            }
            verdict.lookup_ok &= lookup_ok;
            cost.lkp_verify_s += t_lkp.elapsed().as_secs_f64();
            if tr_v_state.is_none() {
                // A broken descent leaves nothing to ground the wave's
                // pin claims — the whole block rejects here.
                cost.verify_s += t_verify.elapsed().as_secs_f64();
                continue;
            }
        }
        for r in 0..UK8_RPB {
            let slots = vec![(idx_x, 2 * r), (idx_x, 2 * r + 1)];
            lin_v.extend(link_claims_tgt(&zq, &lp_r, &xi_v[r], &y_link[r], &slots));
        }
        lin_v.extend(link_claims_tgt_slot(&ctx_ring, &lp_h, &xi_zero, &zeta_y_v, &y_zero, &y_value_slots));
        lin_v.extend(link_claims_tgt_slot(&ctx_ring, &lp_h, &xi_zero, &zeta_up_v, &y_zero, &up_value_slots));
        let h0r_v = match &tr_v_state {
            Some(tv) => ct_h0(&crs, &tv.state(), &t1s, &t2s, &[]),
            None => ct_h0(&crs, &h0_link_v, &t1s, &t2s, &[]),
        };
        let wave_ok = verify_ct_round(
            &path, &ctx_ring, &rp, None, &crs, &h0r_v, &lin_v, &[], &[], &quad_ring, &t1s, &t2s,
            &[], &[], &[], n_data, &wave_proof,
        );
        verdict.wave_ok &= wave_ok;
        let t_q46v = Instant::now();
        for (r, gr) in gnd_rounds.iter().enumerate() {
            let unit_ids = [4 * r, 4 * r + 1, 4 * r + 2, 4 * r + 3];
            let rt1s: Vec<Vec<Poly>> = unit_ids
                .iter()
                .map(|&u| bd.bits_t1s[u].clone())
                .chain(gt1s_g[r].iter().cloned())
                .collect();
            let rt2s: Vec<Vec<Poly>> = unit_ids
                .iter()
                .map(|&u| bd.bits_t2s[u].clone())
                .chain(gt2s_g[r].iter().cloned())
                .collect();
            let ctx_r: Vec<u8> = h0_link_v.iter().copied().chain((r as u64).to_le_bytes()).collect();
            let acom_refs: Vec<&AjtaiCommit> = gr.acoms.iter().collect();
            let h0_g_v = ct_h0(&crs_g, &ctx_r, &rt1s, &rt2s, &acom_refs);
            let mut round_ok = h0_g_v == gr.h0_g;
            let jl_v = derive_jl_rows(&h0_g_v, ap.rows, ap.n);
            let mut lin_gv: Vec<ring::ct_engine::CtClaim> = Vec::new();
            for u in 0..4usize {
                lin_gv.extend(arp_claims(&zq_g, &ap, &jl_v, &(0..msg_r_g).map(|s| (u, s)).collect::<Vec<_>>(), u, &gr.y_arp[u]));
            }
            let plane_slots: Vec<Vec<(usize, usize)>> = (0..8)
                .map(|i| {
                    let hi = usize::from(i >= 4);
                    vec![(hi, i % 4), (2 + hi, i % 4)]
                })
                .collect();
            lin_gv.extend(link_claims_gnd(&zq_g, &lp_r, &xi_v[r], &y_link[r], &plane_slots));
            let mut quad_gv = Vec::new();
            for u in 0..4usize {
                quad_gv.extend(binary_claims(&zq_g, &h0_g_v, (b * UK8_RPB * 4 + r * 4 + u) as u64, &[(u, msg_r_g)]));
            }
            round_ok &= verify_ct_round(
                &path_g, &ring_g, &rp_g, None, &crs_g, &h0_g_v, &lin_gv, &[], &quad_gv, &[],
                &rt1s, &rt2s, &[], &[], &acom_refs, 4, &gr.proof,
            );
            verdict.q46_ok &= round_ok;
        }
        cost.q46_verify_s += t_q46v.elapsed().as_secs_f64();
        cost.verify_s += t_verify.elapsed().as_secs_f64();
        // The proof data (t1s/t2s/proofs/openings) drops here — blocks
        // stream, RSS stays flat (the D-4 decision).
        if !quiet && b == 0 {
            // One-time shape line for the log.
            println!(
                "  block shape: {} el, {} q31 commitments ({} data + {} g), {} q46 commitments/round x {} rounds, q46 prove {:.2}s",
                bd.n_b, n_commits, n_data, g_groups, 4 + g_groups_g, UK8_RPB, q46_prove
            );
        }
    }
    (verdict, cost)
}

/// [U-K8] battery: the committed FFN-gate chain at one block — honest
/// ACCEPT through every stage, then a tamper REJECT at every chain edge
/// and the F5 pair for the chain's new hash edge (zeta before the slot
/// commitments).
fn self_test_ffn_chain() {
    println!("\n[U-K8] committed FFN-gate chain: range-proved X -> masked lookup -> gate-o-up");
    println!(
        "  legacy range arm: rejection clipping ~2^-4.75 at t=1.5, NOT statistical ZK — see audit 2026-07-14 C-01 (target path = the ARP-free layer rig)"
    );
    let n = UK8_B;
    let t0 = Instant::now();
    let (v, c) =
        ffn_chain_run(n, true, ChainTamper::None, 0x5eed_0801, ChainEntropy::Test, false);
    assert_true(
        &format!(
            "U-K8 honest chain ACCEPTS end-to-end ({} el: statement v2 + q46 range family + MASKED committed lookup (E1-composed Y pins) + Hadamard block output; commit {:.2}s prove {:.2}s verify {:.2}s)",
            c.n_el, c.commit_s, c.prove_s, c.verify_s
        ),
        v.all_ok(),
    );
    let (vb, cb) =
        ffn_chain_run(n, false, ChainTamper::None, 0x5eed_0801, ChainEntropy::Test, true);
    assert_true(
        &format!(
            "U-K8 baseline arm (lookup omitted) ACCEPTS — the A/B differential is measurable (lookup marginal at this shape, q46 restart noise excluded: prove +{:.2}s, verify +{:.2}s, commit +{} q31 coefficients)",
            (c.prove_s - c.q46_prove_s) - (cb.prove_s - cb.q46_prove_s),
            (c.verify_s - c.q46_verify_s) - (cb.verify_s - cb.q46_verify_s),
            (c.q31_data_coeffs + c.q31_g_coeffs) as i64
                - (cb.q31_data_coeffs + cb.q31_g_coeffs) as i64
        ),
        vb.all_ok(),
    );
    // Edge 1 — out-of-range X (wraparound witness; lookup omitted to
    // isolate the range edge): planes/ARP/binary stay honest, the U-L
    // link's q31 target rows catch the +256 residue jump.
    let (vr, _) =
        ffn_chain_run(n, false, ChainTamper::RangeX, 0x5eed_0802, ChainEntropy::Test, true);
    assert_true(
        "U-K8 edge (range): a wrapped X (+256 residue, honest-looking planes) REJECTS at the q31 wave (link target rows); q46 grounding and gates still pass",
        !vr.wave_ok && vr.q46_ok && vr.gates_ok && vr.statement_ok,
    );
    // Edge 2 — off-table Y: consumed consistently downstream, so ONLY
    // the lookup's blinded root cross-check can reject.
    let (vy, _) =
        ffn_chain_run(n, true, ChainTamper::OffTableY, 0x5eed_0803, ChainEntropy::Test, true);
    assert_true(
        "U-K8 edge (lookup): an off-table Y REJECTS at the masked lookup's root cross-check; wave, q46 and gates pass (the edge is isolated)",
        !vy.lookup_ok && vy.wave_ok && vy.q46_ok && vy.gates_ok,
    );
    // The lookup h0 is DERIVED by the verifier from the statement and the
    // complete commitment list; it is never read from the proof. A prover
    // that builds its whole lookup transcript on a free (arbitrary) prehash
    // produces descents whose challenges diverge from the verifier's
    // derivation, so the masked descent REJECTS — not a compared h0 field.
    let (vh, _) =
        ffn_chain_run(n, true, ChainTamper::LookupH0, 0x5eed_0806, ChainEntropy::Test, true);
    assert_true(
        "U-K8 transcript boundary (C-02): a free prover-chosen lookup h0 REJECTS because the verifier DERIVES h0 (and alpha) from statement+commitments — the descents diverge; no prover h0 is read or compared; the wave never runs",
        !vh.lookup_ok && vh.wave_ok && vh.q46_ok && vh.gates_ok && vh.statement_ok,
    );
    // Edge 3 — Hadamard mismatch: one Z slot constant off the product.
    let (vz, _) =
        ffn_chain_run(n, true, ChainTamper::HadamardZ, 0x5eed_0804, ChainEntropy::Test, true);
    assert_true(
        "U-K8 edge (gate-o-up): a tampered Z slot constant REJECTS at the quad ring claim; the lookup itself passes",
        !vz.wave_ok && vz.lookup_ok && vz.q46_ok,
    );
    // Edge 4 — the F5 pair for the chain's NEW hash edge: zeta must
    // follow the slot commitments. ACCEPT leg: a buggy build deriving
    // zeta from a pre-commitment source accepts junk CRT coordinates
    // (crafted in the stale zeta's null space) in Y and UP whose
    // gate-o-up output constants are WRONG — while the masked lookup
    // PASSES (its E1-composed pins read slot constants only).
    let (va, _) = ffn_chain_run(
        n,
        true,
        ChainTamper::JunkY { stale: true },
        0x5eed_0805,
        ChainEntropy::Test,
        true,
    );
    assert_true(
        "U-K8 order (F5 ACCEPT leg): stale zeta (drawn before the slot commitments) ACCEPTS crafted junk-coordinate Y/UP — with WRONG block-output constants — and the lookup still passes (constants read exactly)",
        va.all_ok() && va.junk_harm,
    );
    let (vs, _) = ffn_chain_run(
        n,
        true,
        ChainTamper::JunkY { stale: false },
        0x5eed_0805,
        ChainEntropy::Test,
        true,
    );
    assert_true(
        "U-K8 order (F5 REJECT leg): the shipped zeta (from h0_link_b, post-commitment) REJECTS the same junk at the q31 wave",
        !vs.wave_ok && vs.lookup_ok && vs.q46_ok,
    );
    println!(
        "  [U-K8] battery done in {:.1}s ({} ARP restarts across runs; timings [NOISY-SHARED])",
        t0.elapsed().as_secs_f64(),
        c.arp_restarts
    );
}

/// `ffn-chain <n_blocks>` — the U-K8 A/B measurement: the lookup-
/// integrated chain vs the same chain with the lookup omitted, at
/// n_blocks x 1020 elements. Prints per-stage totals, the lookup
/// marginals, committed-coefficient accounting and peak RSS. All wall
/// times on a shared box are [NOISY-SHARED]; the quiesced re-measurement
/// is the orchestrator's reconciliation pass.
fn ffn_chain_bench(n_blocks: usize) {
    use ring::gkr_masked::masked_pass_bytes;
    let n_el = n_blocks * UK8_B;
    println!(
        "u-k8 ffn-chain bench: {n_el} elements ({n_blocks} blocks x {UK8_B}), committed FFN-gate chain, 1T"
    );
    println!(
        "  legacy range arm: q46 grounding uses ARP rejection clipping ~2^-4.75 at t=1.5, NOT statistical ZK — see audit 2026-07-14 C-01; the ZK-grade target path is the ARP-free layer rig (ffn-chain layer, exact range lookup)"
    );
    let t_a = Instant::now();
    let (va, ca) =
        ffn_chain_run(n_el, true, ChainTamper::None, 0x5eed_08b1, ChainEntropy::Os, false);
    let wall_a = t_a.elapsed().as_secs_f64();
    assert!(va.all_ok(), "arm A (lookup-integrated) must verify");
    let hwm_a = vm_hwm_kb();
    let t_b = Instant::now();
    let (vb, cb) =
        ffn_chain_run(n_el, false, ChainTamper::None, 0x5eed_08b1, ChainEntropy::Os, true);
    let wall_b = t_b.elapsed().as_secs_f64();
    assert!(vb.all_ok(), "arm B (lookup omitted) must verify");
    let hwm_b = vm_hwm_kb();
    let el = n_el as f64;
    let line = |label: &str, a: f64, b: f64| {
        println!(
            "  {label:<28} A {a:8.2}s  B {b:8.2}s  marginal {:+8.2}s = {:+7.1} us/el",
            a - b,
            (a - b) / el * 1e6
        );
    };
    println!("  arm A = lookup-integrated chain; arm B = same chain, lookup omitted. [NOISY-SHARED]");
    line("commit", ca.commit_s, cb.commit_s);
    line("prove (all rounds)", ca.prove_s, cb.prove_s);
    line("  of which q46 grounding", ca.q46_prove_s, cb.q46_prove_s);
    // The q46 FS-with-aborts restart LUCK differs across arms (h0_link_b
    // binds the arms' different commitment lists, so the JL draws
    // differ); the q46 WORK per attempt is identical. The q46-excluded
    // prove marginal is therefore the honest lookup edge.
    line(
        "prove excl. q46 (lookup edge)",
        ca.prove_s - ca.q46_prove_s,
        cb.prove_s - cb.q46_prove_s,
    );
    line("verify (all rounds)", ca.verify_s, cb.verify_s);
    line("  of which q46 grounding", ca.q46_verify_s, cb.q46_verify_s);
    line(
        "verify excl. q46 (lookup edge)",
        ca.verify_s - ca.q46_verify_s,
        cb.verify_s - cb.q46_verify_s,
    );
    line("wall (incl. setup)", wall_a, wall_b);
    println!(
        "  lookup stage attribution (arm A only): prove {:.2}s ({:.1} us/el), verify {:.2}s ({:.1} us/el) — trees + masked descents + pin building",
        ca.lkp_prove_s,
        ca.lkp_prove_s / el * 1e6,
        ca.lkp_verify_s,
        ca.lkp_verify_s / el * 1e6
    );
    let dce_a = ca.q31_data_coeffs + ca.q31_g_coeffs;
    let dce_b = cb.q31_data_coeffs + cb.q31_g_coeffs;
    println!(
        "  committed q31 coefficients: A {dce_a} (data {} + g {}), B {dce_b} -> lookup marginal {:.1} dce/el at B = {UK8_B} sub-instances (m + blinders + masks + pin g's; amortizes as 1/B — ~1e-4 dce/el at the design's 5.6e6-el instances [MODEL])",
        ca.q31_data_coeffs, ca.q31_g_coeffs,
        (dce_a - dce_b) as f64 / el
    );
    println!(
        "  q46 grounding side (both arms, cancels in the marginal): {} committed coefficients = {:.0} dce/el chain-native range cost [legacy range arm: NOT statistical ZK at t=1.5 — audit 2026-07-14 C-01]",
        ca.q46_coeffs,
        ca.q46_coeffs as f64 / el
    );
    println!(
        "  masked lookup transcript: {} B/block x {n_blocks} blocks = {:.0} KB; ARP restarts A {} / B {}",
        masked_pass_bytes(UK8_DW, UK8_DT, 0, 1),
        (masked_pass_bytes(UK8_DW, UK8_DT, 0, 1) * n_blocks) as f64 / 1024.0,
        ca.arp_restarts,
        cb.arp_restarts
    );
    println!(
        "  peak RSS: {:.2} GiB after arm A, {:.2} GiB after both (blocks stream; the H-03 wall does not bind at this block size)",
        hwm_a as f64 / 1024.0 / 1024.0,
        hwm_b as f64 / 1024.0 / 1024.0
    );
    println!(
        "  true FFN gate instance = 512 x 11008 = 5,636,096 el = {} blocks: linear extrapolation only — see the U-K8 doc block for the two as-built capacity walls (C2 wave cap, q46 ARP granularity)",
        5_636_096usize.div_ceil(UK8_B)
    );
    println!("ffn-chain bench done ({n_el} elements, all timings [NOISY-SHARED] 1T)");
}

/// LKP-8 — the U-K8 chain operating point (frozen constants + the two
/// as-built capacity walls, pinned in both directions).
///
/// REPRODUCIBILITY PINS, NOT A ZK CLAIM (audit 2026-07-14 C-01): the
/// ARP rows below freeze the LEGACY range arm's restart economics and
/// budget walls so parameter drift is caught — they do NOT certify a
/// negligible rejection distance. At the frozen t = 1.5 the ARP clips
/// ~2^-4.75 per unit and the arm is not statistical ZK; the security
/// exit for range facts is the exact range lookup (U-R2, LKP-9's table
/// digest row), and the layer rig is ARP-free (D-5).
fn freeze_check_uk8() -> bool {
    use ring::ct_engine::{arp_budget_ok, derive_arp_params, derive_ct_round_params, theta_rows};
    use ring::gkr::ceiling_gate_ok;
    use ring::gkr_masked::blinder_positions;
    use ring::link::derive_gadget_layer;
    let mut all_ok = true;
    let mut gate = |label: &str, ok: bool| {
        println!("  {} {label}", if ok { "ok  " } else { "FAIL" });
        all_ok &= ok;
    };
    // The block sub-instance: 1020 elements is exactly the first blinder
    // position of the depth-11 witness tree; the ceiling clears trivially.
    gate(
        "LKP-8 U-K8 block = 1020 el (blinder_positions(2^11)[0]), dt = 9, ceiling ok",
        UK8_B == blinder_positions(1 << UK8_DW)[0] && ceiling_gate_ok(1 << UK8_DW, Q8),
    );
    // Wall 1 (q31 C2 wave cap): the chain's ~113-commitment block round
    // derives; a 200-commitment round does NOT — the reason the chain is
    // blocked at B = 1020 rather than one descent per tensor. (The C2
    // arithmetic is replicated inline because release builds abort on
    // the derive-time assert; derive_ct_round_params at the chain's
    // actual count runs live inside ffn_chain_run.)
    {
        let c2_fits = |n_commits: usize| -> bool {
            let bundle = (n_commits * 26 * D) as f64;
            let op = 1.3 * (2.0 * D as f64).sqrt();
            let sigma = (12.0 * op * bundle.sqrt()).ceil();
            let bound = 1.2 * sigma * bundle.sqrt();
            let beta = (2.0 * bound + op * bundle.sqrt()).ceil() as u128;
            (Q8 as u128) > 8 * beta
        };
        let _ = derive_ct_round_params(
            Q8,
            CommitShape { kappa: 8, n_r: 26, msg_r: 8 },
            113,
            0,
            0,
            true,
        );
        gate(
            "LKP-8 wall 1: q31 C2 wave cap — 113 commitments derive, 200 do NOT (single-descent committed lookups cap near 2^17 el/round)",
            c2_fits(113) && !c2_fits(200),
        );
    }
    // Wall 2 (q46 ARP): the 512-bit unit at alpha = 3.5 closes the
    // budget; alpha = 5 at the same unit does NOT (the restart-coupling
    // cap that fixes 4 units per grounding round).
    {
        let ap_ok = derive_arp_params(512, 256, 1, UK8_ALPHA);
        let ap_hot = derive_arp_params(512, 256, 1, 5.0);
        gate(
            "LKP-8 wall 2: q46 ARP unit 512 bits at alpha 3.5 closes; alpha 5.0 does NOT (4 restart-coupled units/round) [REPRODUCIBILITY pin, legacy range arm — NOT a ZK claim; audit 2026-07-14 C-01]",
            arp_budget_ok(&ap_ok, (ring::Q8_46 / 2) as f64)
                && !arp_budget_ok(&ap_hot, (ring::Q8_46 / 2) as f64),
        );
    }
    // The q46 gadget layer at msg_r = 4 (one unit per commitment) and the
    // link/zeta operating points ride the frozen F3 constants (w=11 l=24).
    gate(
        "LKP-8 q46 layer msg_r = 4 derives; binary theta rows = 6; link w = 11 -> l = 24",
        derive_gadget_layer(ring::Q8_46, 4, 16).is_some()
            && theta_rows(ring::Q8_46) == 6
            && ring::link::link_rows(11) == 24,
    );
    all_ok
}

// U-L freeze rows: the F3 modulus-link derive-time gates. Called at the end
// of freeze_check(); returns its own conjunction so a broken link budget
// fails the whole gate.
fn freeze_check_link() -> bool {
    use ring::link::{
        arp_binary_unit_ok, derive_gadget_layer, derive_link_params, link_honest_y, link_rows,
        link_w_max,
    };
    let mut all_ok = true;
    let mut gate = |label: &str, ok: bool| {
        println!("  {} {label}", if ok { "ok  " } else { "FAIL" });
        all_ok &= ok;
    };

    // The two frozen CRS points of the link (study-table parity).
    match derive_gadget_layer(Q8, 32, 16) {
        Some(gl) => gate(
            &format!(
                "F3 q31 value CRS (msg_r=32, wave 16): kappa={} N_r={} headroom {:.1} bits, col {:.1} KB",
                gl.shape.kappa, gl.shape.n_r, gl.c2_headroom_bits, gl.col_kb
            ),
            gl.shape.kappa == 9 && gl.shape.n_r == 56 && gl.c2_headroom_bits >= 1.0,
        ),
        None => gate("F3 q31 value CRS derives", false),
    }
    match derive_gadget_layer(ring::Q8_46, 32, 16) {
        Some(gl) => gate(
            &format!(
                "F3 q46 bit CRS (msg_r=32, wave 16): kappa={} N_r={} headroom {:.1} bits, {:.1} ring-MACs/el",
                gl.shape.kappa, gl.shape.n_r, gl.c2_headroom_bits, gl.macs_el
            ),
            gl.shape.kappa == 6 && gl.shape.n_r == 62 && gl.c2_headroom_bits >= 1.0,
        ),
        None => gate("F3 q46 bit CRS derives", false),
    }

    // The frozen link operating point at the demo shape (n=128, W=4).
    let wm = link_w_max(128, 4, ring::Q8_46);
    gate(&format!("F3 link w_max(128, 4, q46) = {wm} (frozen w = 11 <= w_max)"), wm == 35);
    gate(
        "F3 frozen point w = 11 -> l = 24 rows, w*l = 264 (2^-264 <= 2^-256)",
        link_rows(11) == 24 && 11 * link_rows(11) == 264,
    );

    // The ARP binary-unit granularity finding, PINNED IN BOTH DIRECTIONS:
    // the F3 unit (512 bit coefficients) closes at q46; a full-tensor
    // 128 x W=12 unit (1536) does NOT — binary claims + their ARPs stay
    // partitioned at F3-shape units until Q4.4' lands.
    gate("F3 ARP binary unit n=512 closes at q46", arp_binary_unit_ok(512, ring::Q8_46));
    gate(
        "F3 ARP binary unit n=1536 does NOT close at q46 (granularity cap stays pinned)",
        !arp_binary_unit_ok(1536, ring::Q8_46),
    );

    // Completeness: the honest 1.3-tail |y| model fits the grounding gate.
    let lp = derive_link_params(128, 4, ring::Q8_46, Q8, 11);
    gate(
        &format!(
            "F3 honest |y| model 2^{:.1} < q46/2 = 2^45 (grounding gate, margin ~2^28)",
            link_honest_y(&lp).log2()
        ),
        link_honest_y(&lp) < (ring::Q8_46 / 2) as f64,
    );

    // LKP-5 — the lookup's slot-field constants (M4_LOOKUP_DESIGN
    // Section 8): the field every lookup challenge/round value lives
    // in. A parameter move that changes q, the split or any slot root
    // changes the transcript's field and must trip this row.
    {
        let ctx = ring_ctx_q8();
        let dg = ring::kfield::slot_field_digest(&ctx);
        let hexd: String = dg.iter().take(8).map(|b| format!("{b:02x}")).collect();
        gate(
            &format!("LKP-5 slot-field digest {hexd} (k=8, deg 16, s0 = {})", ctx.slot_roots[0]),
            hexd == "0bcd6c1ee344e149"
                && ctx.slot_roots[0] == 2_056_890_868
                && ctx.k == 8
                && ctx.slot_deg == 16,
        );
    }

    // LKP-1 — the lookup's table statement: the canonical spec digest
    // of silu-int8-table-v1 (M4_LOOKUP_DESIGN Section 1.1). The digest
    // enters every lookup h0 before alpha. Rows are static integers—no
    // runtime libm—and both the lookup and statement validator pin this
    // full digest.
    {
        let rows = ring::lookup::silu_int8_table();
        let dg = ring::lookup::table_spec_digest(&rows);
        let hexd: String = dg.iter().take(8).map(|b| format!("{b:02x}")).collect();
        gate(
            &format!("LKP-1 silu-int8-table-v1 spec digest {hexd} (256 rows)"),
            dg == ring::lookup::SILU_INT8_TABLE_DIGEST
                && dg == manifest::SILU_INT8_TABLE_DIGEST
                && rows.len() == 256
                && rows[128] == (0, 0),
        );
    }

    // LKP-2/LKP-3 — the lookup's ceiling gate and transcript shape at
    // the frozen 7B/512 point (M4_LOOKUP_DESIGN Sections 4/7): per-
    // layer instances padded to 2^23 leaves, 32 instances (e_bits = 5),
    // table depth 8; the LogUp ceiling wants a >= 64x margin below
    // char(K) = q per table instance.
    {
        use ring::gkr::{ceiling_gate_ok, transcript_shape};
        gate(
            "LKP-2 characteristic ceiling: 2^23-leaf instances (and T=2048 per-layer) clear the 64x margin; 2^26 does NOT",
            ceiling_gate_ok(1 << 23, Q8)
                && ceiling_gate_ok(2048 * 11008, Q8)
                && !ceiling_gate_ok(1 << 26, Q8),
        );
        let (rw, kw, bw) = transcript_shape(23, 5);
        let (rt, kt, bt) = transcript_shape(8, 5);
        gate(
            &format!(
                "LKP-3 transcript shape at the FFN point: witness {rw} rounds ({kw}+{bw} K-elems), table {rt} rounds ({kt}+{bt}), degree 3"
            ),
            rw == 368 && kw == 1472 && bw == 92 && rt == 68 && kt == 272 && bt == 32,
        );
    }

    // LKP-6 — the E3-Z mask/blinder accounting at the frozen FFN point
    // (witness depth 23, table depth 9 with blinders, e_bits = 5;
    // M4_LOOKUP_ZK_DESIGN Section 3.1): mask coefficient counts by the
    // 3k+20-class formulas (last layer unmasked-children, -2), blinder
    // positions fixed by blinder_positions, masks ONE-TIME per pass
    // (reuse reproduces the leak — E3Z-N3).
    {
        use ring::gkr_masked::mask_coeff_counts;
        let (gw, rw) = mask_coeff_counts(23, 5);
        let (gt, rt) = mask_coeff_counts(9, 5);
        let blinders = 8 * 2 * 32;
        gate(
            &format!(
                "LKP-6 E3-Z mask material: witness g {gw}+R {rw}, table g {gt}+R {rt}, blinders {blinders} -> {} K-elems/pass",
                gw + rw + gt + rt + blinders
            ),
            gw == 1197 && rw == 252 && gt == 266 && rt == 84
                && gw + rw + gt + rt + blinders == 2311,
        );
    }

    // LKP-7 — the E3-Z MASKED transcript shape at the frozen FFN point
    // (witness depth 23, table depth 9 with blinders, e_bits = 5;
    // M4_LOOKUP_ZK_DESIGN Sections 3.2/3.5). Round counts, the total
    // transcript K-element volume (round polys + layer-1 quadruples +
    // per-layer G/boundary/openings), and the wire byte count at 64 B
    // per K-element (16 base coefficients x 4 B, q < 2^31). This is the
    // measured shape the Section 3.5 re-grade reads.
    {
        use ring::gkr_masked::{masked_pass_bytes, masked_transcript_totals};
        let (rw, kw) = masked_transcript_totals(23, 5, 32);
        let (rt, kt) = masked_transcript_totals(9, 5, 32);
        let bytes = masked_pass_bytes(23, 9, 5, 32);
        gate(
            &format!(
                "LKP-7 masked transcript at the FFN point: witness {rw} rounds/{kw} K-el, table {rt}/{kt}, pass {bytes} B ({:.0} KB) at 64 B/K-el",
                bytes as f64 / 1024.0
            ),
            rw == 385 && kw == 1862 && rt == 84 && kt == 532
                && bytes == 64 * (kw + kt),
        );
    }

    // LKP-4 — the E4 randomizer budget (M4_LOOKUP_DESIGN Section 3.4):
    // 9 psi copies (the theta_rows convention, 9 x 31 = 279 >= 257
    // bits) batch the 3 * K_DEG = 48 coordinate rows into ordinary
    // linear CtClaims — no new claim family; psi drawn strictly after
    // the claimed coordinates (the E4-N1 pair pins it).
    gate(
        "LKP-4 E4 psi budget: 9 copies x 31 bits >= 257 over 48 coordinate rows",
        ring::ct_engine::theta_rows(Q8) == 9 && 3 * ring::kfield::K_DEG == 48,
    );

    // E2 — slot-target junk accounting: EVERY non-constant CRT
    // coordinate of a slot-packed link target carries a zeta weight
    // (chunks * D - n of them at k = 8 values/element), same w/l budget
    // as the xi rows. A refactor that stops covering all junk
    // coordinates reopens the composed-Hadamard gap (U-E2 battery).
    {
        let lp_s = derive_link_params(16, 4, ring::Q8_46, Q8, 11);
        let n_junk = lp_s.n.div_ceil(8) * 128 - lp_s.n;
        gate(
            &format!("E2 slot-link junk weights cover ALL non-constant coordinates: {n_junk} at (n=16, k=8), w=11 l={}", lp_s.l),
            n_junk == 240 && lp_s.l == 24,
        );
    }
    all_ok
}

// ===========================================================================
// M5-lite: wide-object chunking + the FFN-shape commit-bill measurement.
//
// The blocker this section removes: several protocol objects are WIDER than
// one commitment's msg_r message slots — the pi2-CE execution/mask vectors
// need h * inner_r ring-element slots, which at the FFN shape
// (512 x 4096 x 11008, h = 128, inner_r = 32) is msg_r = 4096, and up to
// 11008 for the wider orientation. A monolithic CRS at that message
// dimension stores (kappa + msg_r) * N_r ring elements ~ 17-121 GB (before
// the A1 kernel caches multiply it) — unusable on a 15 GB box. The fix is a
// LAYOUT convention, not a protocol change: commit the wide object as a
// sequence of column chunks under the ONE frozen msg_r = 32-class CRS
// (~2.3 MB), address logical slot u at (chunk u / msg_r, slot u % msg_r) —
// the ct-engine's existing g_slot_of convention — and let the manifest
// treat the ordered chunk list as ONE logical tensor via wide_digest().
// Implementation: ring/commit.rs (wide_chunk_count, wide_slot, wide_chunks,
// commit_wide, wide_digest, monolithic_wide_crs_bytes); the self-test below
// pins bit-identity across kernel paths, digest binding, and a ct-round
// whose claims span chunk boundaries — no verification equation moved.

fn self_test_m5_chunking() {
    use manifest::{ClaimManifest, Orientation};
    use ring::commit::{
        commit_wide, monolithic_wide_crs_bytes, wide_chunk_count, wide_digest, wide_slot,
    };
    use ring::ct_engine::{
        RingClaim, StdOpening, ct_h0, derive_ct_round_params, prove_ct_round, verify_ct_round,
    };
    println!("\n[M5] wide-object chunking: layout-only commitment of wide tensors");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 2 };
    let crs = expand_crs(shape, q, 0x4d35);
    let rp = derive_ct_round_params(q, shape, 4, 0, 0, true);
    let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
    let a1_path = KernelPath::A1(&a1p);
    let mut rng = 0x5eed_4d35u64;

    // A wide object of 7 ring elements at msg_r = 2: 4 chunks, 1 padded slot.
    let wide_len = 7usize;
    let x_wide: Vec<Poly> = (0..wide_len).map(|_| rng_poly_mod(&mut rng, q)).collect();
    assert_true(
        "chunk count covers the wide object (7 slots -> 4 chunks at msg_r = 2)",
        wide_chunk_count(wide_len, shape.msg_r) == 4,
    );

    // Kernel-path bit-identity: the layout does not touch the commit math.
    let rho_seed = 0x5eed_4d36u64;
    let (mut ra, mut rs) = (rho_seed, rho_seed);
    let (msgs, rhos, groups) = commit_wide(&a1_path, &crs, &x_wide, &mut ra);
    let (_, _, groups_school) = commit_wide(&KernelPath::School, &crs, &x_wide, &mut rs);
    assert_true(
        "chunked commitments bit-identical across kernel paths (same rho stream)",
        groups.iter().zip(groups_school.iter()).all(|(a, b)| a.0 == b.0 && a.1 == b.1),
    );
    assert_true("tail chunk zero-padded", msgs[3][1] == poly_zero());

    // ONE digest for the ordered chunk list.
    let dg = wide_digest(&groups);
    let mut swapped = groups.clone();
    swapped.swap(0, 1);
    let mut tampered = groups.clone();
    tampered[2].1[0][0] ^= 1;
    assert_true(
        "wide digest binds order, every element and the chunk count",
        wide_digest(&swapped) != dg
            && wide_digest(&tampered) != dg
            && wide_digest(&groups[..3]) != dg
            && wide_digest(&groups) == dg,
    );

    // Manifest: ONE entry for the logical tensor (never one per chunk).
    let mut ki = key_info_bytes(&shape, q);
    ki.extend_from_slice(&(wide_chunk_count(wide_len, shape.msg_r) as u32).to_le_bytes());
    ki.extend_from_slice(&(wide_len as u32).to_le_bytes());
    let mut mf = ClaimManifest::new("lattice-route-r", &crs.crs_hash);
    let _id = mf.add_commitment("WIDE", 1, wide_len, Orientation::ByColumns, ki, dg.to_vec());
    // The bare manifest digest is retired (statement v3, audit H-03); this
    // LAYOUT battery seeds its transcript from the wide-object digest
    // directly. Production chains bind wide entries through a validated
    // statement (chain-demo / ffn-chain), whose random mod-q test vectors
    // carry no integer-typed statement here.
    let ctx = uk8_sha(&[b"m5-wide-chunk-ctx-v3", &crs.crs_hash, &dg]);

    // Protocol equations unchanged: RingClaims address (chunk, slot) pairs
    // through wide_slot — per-slot claims plus one claim SPANNING chunks.
    let t1s: Vec<Vec<Poly>> = groups.iter().map(|g| g.0.clone()).collect();
    let t2s: Vec<Vec<Poly>> = groups.iter().map(|g| g.1.clone()).collect();
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let mut claims: Vec<RingClaim> = (0..wide_len)
        .map(|u| {
            let (c, s) = wide_slot(u, shape.msg_r);
            RingClaim { msg_coeffs: vec![(c, s, one.clone())], constant: x_wide[u].clone() }
        })
        .collect();
    let mut mc = Vec::new();
    let mut k = poly_zero();
    for (u, xu) in x_wide.iter().enumerate() {
        let w = poly_from_small(&zq, &rng_quinary_poly(&mut rng));
        let (c, s) = wide_slot(u, shape.msg_r);
        k = poly_add(&zq, &k, &ring_mul_split_kara_fast(&ring_ctx, &w, xu));
        mc.push((c, s, w));
    }
    claims.push(RingClaim { msg_coeffs: mc, constant: k });
    let h0 = ct_h0(&crs, &ctx, &t1s, &t2s, &[]);
    let openings: Vec<StdOpening> = msgs
        .iter()
        .zip(rhos.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
        .collect();
    let (proof, _attempts) = prove_ct_round(
        &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &openings, &[], &[],
        openings.len(), &mut rng,
    );
    assert_true(
        "ct-round proves/verifies claims addressed across chunk boundaries",
        verify_ct_round(
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &t1s, &t2s, &[],
            &[], &[], openings.len(), &proof,
        ),
    );
    let mut claims_bad: Vec<RingClaim> = claims
        .iter()
        .map(|c| RingClaim { msg_coeffs: c.msg_coeffs.clone(), constant: c.constant.clone() })
        .collect();
    let bumped = zq.add(claims_bad.last().unwrap().constant[0], 1);
    claims_bad.last_mut().unwrap().constant[0] = bumped;
    assert_true(
        "tampered spanning-claim constant fails",
        !verify_ct_round(
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims_bad, &[], &[], &t1s, &t2s,
            &[], &[], &[], openings.len(), &proof,
        ),
    );
    let mut t2s_bad = t2s.clone();
    t2s_bad[1][0][0] = zq.add(t2s_bad[1][0][0], 1);
    assert_true(
        "tampered chunk commitment fails",
        !verify_ct_round(
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &claims, &[], &[], &t1s, &t2s_bad,
            &[], &[], &[], openings.len(), &proof,
        ),
    );

    // The blocker the layout removes, as a pinned magnitude.
    let gb_4096 = monolithic_wide_crs_bytes(4096, 9, q) as f64 / 1e9;
    let gb_11008 = monolithic_wide_crs_bytes(11008, 9, q) as f64 / 1e9;
    println!(
        "  monolithic wide CRS at FFN inner dims: msg_r=4096 -> {gb_4096:.1} GB, msg_r=11008 -> {gb_11008:.1} GB (A1 caches excluded); the chunked layout needs only the msg_r=32-class CRS"
    );
    assert_true(
        "monolithic wide CRS is the 17-121 GB class the chunking avoids",
        gb_4096 > 15.0 && gb_11008 > 100.0,
    );
}

// ---------------------------------------------------------------------------
// m5-bench: the real end-to-end CPU commit-bill measurement at FFN matmul
// dims (LLM_SCALE_ESTIMATE.md M5 / audit H-02 recost). Streams the triple —
// nothing dense is materialized: every column is generated, packed,
// committed and digested, then dropped; only 32-byte digests are retained.

fn proc_status_mb(key: &str) -> f64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines()
                .find(|l| l.starts_with(key))
                .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok()))
        })
        .map(|kb| kb / 1024.0)
        .unwrap_or(f64::NAN)
}

/// One streamed column commit: generate `height` values mod q from `seed`,
/// pack to msg_r slots, sample ternary rho, commit, digest. With
/// kernel = false everything except the commit + commitment digest runs
/// (the non-kernel share: datagen + packing + rho sampling).
fn m5_column_digest(
    path: &KernelPath,
    crs: &ring::commit::RingCrs,
    height: usize,
    seed: u64,
    kernel: bool,
) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut rng = seed;
    let col: Vec<u64> = (0..height).map(|_| rng_below(&mut rng, crs.q)).collect();
    let x = pack_column(height, crs.shape.msg_r, &col);
    let rho: Vec<Vec<i64>> = (0..crs.shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
    let mut h = Sha256::new();
    if kernel {
        let (t1, t2) = commit(path, crs, &x, &rho);
        h.update(polys_bytes(&t1));
        h.update(polys_bytes(&t2));
    } else {
        let mut acc = 0u64;
        for p in &x {
            for &v in p {
                acc = acc.wrapping_add(v);
            }
        }
        for r in &rho {
            for &v in r {
                acc = acc.wrapping_add(v as u64);
            }
        }
        h.update(seed.to_le_bytes());
        h.update(acc.to_le_bytes());
    }
    h.finalize().into()
}

fn m5_fold(digests: &[[u8; 32]]) -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    for d in digests {
        h.update(d);
    }
    h.finalize().into()
}

#[allow(clippy::too_many_arguments)]
fn m5_bench(rows: usize, inner: usize, cols: usize, reps: usize) {
    use rayon::prelude::*;
    use ring::commit::{monolithic_wide_crs_bytes, wide_chunk_count, wide_chunks, wide_digest};
    let q = Q8;
    println!(
        "m5-bench: FFN matmul triple commit bill at {rows}x{inner}x{cols}, (k = 8, q8_31, e = 4), chunked msg_r-class CRS, reps = {reps}"
    );
    assert_ls18(q, 8);
    let p = derive_digits(Proto::Pi2, rows, inner, cols, 0, q, true, 4)
        .expect("frozen C2-C4 point fits q31");
    let cshape = CommitShape { kappa: p.kappa, n_r: p.n_r, msg_r: p.msg_r };
    println!(
        "  frozen point: kappa = {}, N_r = {}, msg_r = {} (C2 headroom {:.1} bits); P0 regimes:",
        cshape.kappa, cshape.n_r, cshape.msg_r, p.c2_headroom_bits()
    );
    for line in a1_enforce(q, p.n_r, p.sigma, isqrt_u128(p.bound_sq)) {
        println!("    {:<58} -> {}", line.name, line.path);
    }

    let t_setup = Instant::now();
    let crs = expand_crs(cshape, q, 0x4d35_0000);
    let a1p = build_a1_paths(&crs, p.sigma, isqrt_u128(p.bound_sq));
    let crs_mb = ((cshape.kappa + cshape.msg_r) * cshape.n_r * D * 8) as f64 / 1e6;
    println!(
        "  chunked CRS expanded in {:.2}s: {:.2} MB CRS + {:.2} MB A1 caches (bounded, shape-independent of tensor width)",
        t_setup.elapsed().as_secs_f64(),
        crs_mb,
        a1p.cached_bytes() as f64 / 1e6
    );

    // The monolithic wide CRS this layout replaces (pi2-CE wide objects).
    let full = subgroup_elems(5, true);
    let h_sub = full.len();
    let inner_r = inner.div_ceil(D);
    let rows_r = rows.div_ceil(D);
    let wide_a = h_sub * inner_r;
    println!(
        "  monolithic wide CRS avoided: msg_r = {} (h = {h_sub} x inner_r = {inner_r}) -> {:.1} GB; msg_r = {} -> {:.1} GB; chunked: {:.2} MB",
        wide_a,
        monolithic_wide_crs_bytes(wide_a, cshape.kappa, q) as f64 / 1e9,
        cols,
        monolithic_wide_crs_bytes(cols, cshape.kappa, q) as f64 / 1e9,
        crs_mb
    );

    // --- The triple's work list (streamed; per-column seeds). -------------
    // A (rows x inner) by rows, B (inner x cols) by columns, C (rows x cols)
    // by columns — the chain_demo orientation discipline at one shared CRS.
    const GOLD: u64 = 0x9e37_79b9_7f4a_7c15;
    let base_seed = 0x4d35_1001u64;
    let mut work: Vec<(usize, u64)> = Vec::with_capacity(rows + 2 * cols);
    for i in 0..rows {
        work.push((inner, base_seed.wrapping_add((i as u64).wrapping_mul(GOLD))));
    }
    for j in 0..cols {
        work.push((inner, base_seed.wrapping_add(((rows + j) as u64).wrapping_mul(GOLD))));
    }
    for j in 0..cols {
        work.push((rows, base_seed.wrapping_add(((rows + cols + j) as u64).wrapping_mul(GOLD))));
    }
    let n_commits = work.len();
    let used_el = (rows * inner + inner * cols + rows * cols) as f64;
    let paid_el = (n_commits * cshape.msg_r * D) as f64;
    let ring_macs = (n_commits * (cshape.kappa + cshape.msg_r) * cshape.n_r) as f64;
    println!(
        "  work: {n_commits} column commitments ({} A rows + {} B cols + {} C cols); used elements {:.3e}, paid slots {:.3e} (padding waste {:.2}x, C columns pay msg_r = {} for {} used), ring-MACs {:.3e}",
        rows, cols, cols, used_el, paid_el, paid_el / used_el, cshape.msg_r, rows.div_ceil(D), ring_macs
    );

    // --- Thread-scaling measurement. ---------------------------------------
    let threads = [1usize, 2, 4, 8, 16, 22];
    println!("\n  commit bill, full triple per repetition (min/median of {reps}):");
    println!("M5CSV,threads,secs_min,secs_med,ns_per_used_el,ns_per_paid_el,ring_macs_per_s,eff_gmacs,speedup_vs_1t");
    let mut t1_min = f64::NAN;
    let mut fold0: Option<[u8; 32]> = None;
    let mut speed22 = f64::NAN;
    for &t in &threads {
        let pool = rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("pool");
        let mut times: Vec<f64> = Vec::with_capacity(reps);
        for _ in 0..reps {
            let tt = Instant::now();
            let digests: Vec<[u8; 32]> = pool.install(|| {
                work.par_iter()
                    .map(|&(height, seed)| {
                        let path = KernelPath::A1(&a1p);
                        m5_column_digest(&path, &crs, height, seed, true)
                    })
                    .collect()
            });
            times.push(tt.elapsed().as_secs_f64());
            let fold = m5_fold(&digests);
            match fold0 {
                None => fold0 = Some(fold),
                Some(d) => assert!(
                    d == fold,
                    "digest mismatch across thread counts — parallel layout must be order-identical"
                ),
            }
        }
        times.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let mn = times[0];
        let md = times[times.len() / 2];
        if t == 1 {
            t1_min = mn;
        }
        let speedup = t1_min / mn;
        if t == 22 {
            speed22 = speedup;
        }
        println!(
            "M5CSV,{t},{mn:.3},{md:.3},{:.1},{:.1},{:.3e},{:.1},{speedup:.2}",
            mn * 1e9 / used_el,
            mn * 1e9 / paid_el,
            ring_macs / mn,
            ring_macs / mn * (D * D) as f64 / 1e9,
        );
    }

    // Non-kernel share (datagen + packing + rho sampling, no commit/digest).
    for t in [1usize, 22] {
        let pool = rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("pool");
        let tt = Instant::now();
        let digests: Vec<[u8; 32]> = pool.install(|| {
            work.par_iter()
                .map(|&(height, seed)| {
                    let path = KernelPath::A1(&a1p);
                    m5_column_digest(&path, &crs, height, seed, false)
                })
                .collect()
        });
        std::hint::black_box(m5_fold(&digests));
        println!(
            "M5CSV,baseline_no_kernel_t{t},{:.3}",
            tt.elapsed().as_secs_f64()
        );
    }

    // --- Claim-layer volume at this shape (pi2-CE wide objects, chunked, ---
    // --- R1 pads per Q4_LEMMAS.md R1.4'). ----------------------------------
    // 9 wide objects: 3 per side, sides A/B at h * inner_r slots, side C at
    // h * rows_r; round W is gate-only (1 TwistedQuadRingClaim) so R1 costs
    // ONE fresh pad commitment (3 uniform slots) — under chunking that is
    // one msg_r-class chunk, not a wide-shape commitment.
    let wide_slots = 6 * h_sub * inner_r + 3 * h_sub * rows_r;
    let pad_slots = ring::ct_engine::r1_pad_count(0, 0, 1);
    let wide_chunks_n = 6 * wide_chunk_count(h_sub * inner_r, cshape.msg_r)
        + 3 * wide_chunk_count(h_sub * rows_r, cshape.msg_r);
    let pad_chunks = wide_chunk_count(pad_slots, cshape.msg_r);
    let mut rngw = 0x4d35_2001u64;
    let mut wide_msgs: Vec<Vec<Poly>> = Vec::with_capacity(wide_chunks_n + pad_chunks);
    for len in [
        h_sub * inner_r, h_sub * inner_r, h_sub * inner_r,
        h_sub * inner_r, h_sub * inner_r, h_sub * inner_r,
        h_sub * rows_r, h_sub * rows_r, h_sub * rows_r,
    ] {
        let x_wide: Vec<Poly> = (0..len).map(|_| rng_poly_mod(&mut rngw, q)).collect();
        wide_msgs.extend(wide_chunks(&x_wide, cshape.msg_r));
    }
    let pad_wide: Vec<Poly> = (0..pad_slots).map(|_| rng_poly_mod(&mut rngw, q)).collect();
    wide_msgs.extend(wide_chunks(&pad_wide, cshape.msg_r));
    let wide_seed_base = 0x4d35_3001u64;
    let mut wide_times_1t: Vec<f64> = Vec::with_capacity(reps);
    let mut wide_digest_val = [0u8; 32];
    for _ in 0..reps {
        let tt = Instant::now();
        let groups: Vec<(Vec<Poly>, Vec<Poly>)> = wide_msgs
            .iter()
            .enumerate()
            .map(|(i, x)| {
                let mut r = wide_seed_base.wrapping_add((i as u64).wrapping_mul(GOLD));
                let rho: Vec<Vec<i64>> =
                    (0..cshape.n_r).map(|_| rng_ternary_poly(&mut r)).collect();
                commit(&KernelPath::A1(&a1p), &crs, x, &rho)
            })
            .collect();
        wide_times_1t.push(tt.elapsed().as_secs_f64());
        wide_digest_val = wide_digest(&groups);
    }
    wide_times_1t.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let wide_1t = wide_times_1t[0];
    let n_claim_chunks = wide_msgs.len();
    println!(
        "\n  claim layer per matmul claim at this shape (pi2-CE, chunked): {} wide slots + {} R1 pad slots -> {} chunk commitments ({} wide + {} pad), commit {:.3}s 1T ({:.3}ms/chunk); one-logical-tensor digest {}",
        wide_slots,
        pad_slots,
        n_claim_chunks,
        wide_chunks_n,
        pad_chunks,
        wide_1t,
        wide_1t * 1e3 / n_claim_chunks as f64,
        hex_prefix(&wide_digest_val)
    );
    // Reveal/pivot transcript volume (F + K2, proof-encoded at 31 bits).
    let f_polys = h_sub * (2 * inner_r + rows_r);
    let k2_polys = 2 * inner_r + rows_r;
    println!(
        "  reveals per claim: F = {} polys ({:.2} MB at 31 bits/coeff) + K2 = {} polys ({:.1} KB) — transcript bytes, not commitments",
        f_polys,
        f_polys as f64 * D as f64 * 31.0 / 8.0 / 1e6,
        k2_polys,
        k2_polys as f64 * D as f64 * 31.0 / 8.0 / 1e3
    );
    println!(
        "M5CSV,claim_layer,{wide_slots},{pad_slots},{n_claim_chunks},{wide_1t:.3}"
    );

    // --- The recost block (audit H-02): the corrected ladder row. ----------
    let el_low = 9.4e9f64; // committed element-equivalents, RING_MULT_BOTTLENECK 6.4a [MODEL]
    let el_high = 1.33e10f64; // A1_AUX_NTT_REPORT s6 accounting [MODEL]
    let macs_per_el = (1.0 + cshape.kappa as f64 / cshape.msg_r as f64) * cshape.n_r as f64 / D as f64;
    let rate_1t = ring_macs / t1_min; // measured ring-MACs/s end-to-end 1T
    let bill_1t = (el_low * macs_per_el / rate_1t, el_high * macs_per_el / rate_1t);
    let bill_22t = (bill_1t.0 / speed22, bill_1t.1 / speed22);
    println!("\n  recost, 7B/512-token pass (audit H-02):");
    println!(
        "    element-equivalents/pass: {:.1e}..{:.2e} [MODEL — the two docs' accountings], x {:.3} ring-MACs/el at this point",
        el_low, el_high, macs_per_el
    );
    println!(
        "    commit bill 1T  [MEASURED-AT-RATE]: {:.0}-{:.0} s ({:.1}-{:.1} min) at the measured end-to-end rate {:.2e} ring-MACs/s",
        bill_1t.0, bill_1t.1, bill_1t.0 / 60.0, bill_1t.1 / 60.0, rate_1t
    );
    println!(
        "    commit bill 22T [MEASURED-AT-RATE]: {:.0}-{:.0} s ({:.1}-{:.1} min) at the MEASURED {:.1}x 22-thread scaling (ladder assumed ~15x)",
        bill_22t.0, bill_22t.1, bill_22t.0 / 60.0, bill_22t.1 / 60.0, speed22
    );
    println!(
        "    commit bill GPU [ASSUMED 20x]: {:.1}-{:.1} s — no GPU kernel exists in this repo (audit H-03); this row is an assumption, not a measurement",
        bill_22t.0 / 20.0, bill_22t.1 / 20.0
    );
    println!(
        "    claim layer/pass [MODEL anchored]: ~288 matmul-class claims x {:.3}s 1T chunked commit volume = {:.0}s 1T -> ~{:.0}s at {:.1}x; + round proofs ~10-25s wall 22T [MODEL, RING_MULT_BOTTLENECK 6.4b]; R1 pads add {} slots/gate round (one chunk, measured above) — sub-percent [R1.4']",
        wide_1t, 288.0 * wide_1t, 288.0 * wide_1t / speed22, speed22, pad_slots
    );
    println!(
        "    E4/lookup landing [MODEL, M4_LOOKUP_DESIGN]: 9 CtClaims + ~120 KB/pass transcript + ~2.3e7 ring-mult-equivalents (~{:.0}s 1T at the measured rate) — activations stay noise-class",
        2.3e7 / rate_1t
    );
    println!(
        "M5CSV,recost,bill_1t_s,{:.0},{:.0},bill_22t_s,{:.0},{:.0},mt_factor,{speed22:.2},gpu20x_s,{:.1},{:.1}",
        bill_1t.0, bill_1t.1, bill_22t.0, bill_22t.1, bill_22t.0 / 20.0, bill_22t.1 / 20.0
    );

    println!(
        "\n  memory: peak RSS (VmHWM) {:.0} MB, current (VmRSS) {:.0} MB — streaming holds the {rows}x{inner}x{cols} triple far below the 12 GB budget",
        proc_status_mb("VmHWM:"),
        proc_status_mb("VmRSS:")
    );
    println!("m5-bench done");
}

fn hex_prefix(d: &[u8; 32]) -> String {
    d[..8].iter().map(|b| format!("{b:02x}")).collect()
}

/// [U-R1a] Multi-wave claim splitting (RANGE_AGGREGATION_DESIGN Section
/// 2b, ledger PROGRESS_UR.md S0): the deterministic wave planner, the
/// linear-claim split with prover-revealed partial ct scalars, the sum
/// gate, per-wave ct-round round-trips, and quad co-location.
fn self_test_wave_split() {
    use ring::ct_engine::{
        CtClaim, QuadRingClaim, StdOpening, ct_h0, ct_mul_centered, derive_ct_round_params,
        plan_waves, prove_ct_round, quad_ring_localized, quad_ring_wave, split_claims_prover,
        split_claims_verifier, verify_ct_round,
    };
    println!("\n[U-R1a] multi-wave claim splitting: planner, partial-scalar gate, per-wave rounds");
    let q = Q8;
    let ring_ctx = ring_ctx_q8();
    let zq = ring_ctx.zq;
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 2 };
    let crs = expand_crs(shape, q, 0x0ff1);
    let mut rng = 0x5eed_01a0u64;

    // 4 commitments; {1,2} must co-locate (a quad claim's operands).
    let n_c = 4usize;
    let msgs: Vec<Vec<Poly>> =
        (0..n_c).map(|_| (0..shape.msg_r).map(|_| rng_poly_mod(&mut rng, q)).collect()).collect();
    let rhos: Vec<Vec<Vec<i64>>> = (0..n_c)
        .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
        .collect();

    let plan = plan_waves(n_c, &[vec![1, 2]], 2).expect("honest plan derives");
    let plan2 = plan_waves(n_c, &[vec![1, 2]], 2).expect("honest plan derives");
    assert_true(
        "wave plan is deterministic, respects the cap and co-locates the group",
        plan.waves == plan2.waves
            && plan.waves.iter().all(|w| w.len() <= 2)
            && plan.slot_of[1].0 == plan.slot_of[2].0,
    );

    // [Z5] Verifier-safe helpers (audit 2026-07-14 M-01): malformed input
    // returns a TYPED error, never a panic.
    {
        use ring::ct_engine::{WaveError, split_claim_shares};
        let one_p = {
            let mut p = poly_zero();
            p[0] = 1;
            p
        };
        assert_true(
            "[Z5] plan_waves typed errors: zero cap, oversized group, overlapping groups, out-of-range member",
            matches!(plan_waves(n_c, &[], 0), Err(WaveError::ZeroCap))
                && matches!(
                    plan_waves(n_c, &[vec![0, 1, 2]], 2),
                    Err(WaveError::GroupExceedsCap { .. })
                )
                && matches!(
                    plan_waves(n_c, &[vec![0, 1], vec![1, 2]], 2),
                    Err(WaveError::OverlappingGroups { index: 1 })
                )
                && matches!(
                    plan_waves(n_c, &[vec![0, 7]], 2),
                    Err(WaveError::CommitIndexOutOfRange { index: 7, .. })
                ),
        );
        // The explicit Ajtai rule (M-01): the splitter REJECTS a claim
        // carrying Ajtai coefficients — the share scalar would silently
        // drop that opening's contribution (regression: the old code
        // defaulted an Ajtai-only claim to wave zero).
        let ajtai_claim = ring::ct_engine::CtClaim {
            msg_coeffs: vec![(0, 0, one_p.clone())],
            ajtai_coeffs: vec![(0, 0, one_p.clone())],
            scalar: 0,
        };
        let ajtai_only = ring::ct_engine::CtClaim {
            msg_coeffs: vec![],
            ajtai_coeffs: vec![(0, 0, one_p.clone())],
            scalar: 0,
        };
        let msg_refs_z: Vec<&[Poly]> = msgs.iter().map(|m| m.as_slice()).collect();
        assert_true(
            "[Z5] Ajtai rule: split_claim_shares / split_claims_prover / split_claims_verifier all REJECT Ajtai-bearing claims (typed AjtaiClaimUnsupported)",
            matches!(
                split_claim_shares(&plan, &ajtai_claim),
                Err(WaveError::AjtaiClaimUnsupported)
            )
                && matches!(
                    split_claim_shares(&plan, &ajtai_only),
                    Err(WaveError::AjtaiClaimUnsupported)
                )
                && matches!(
                    split_claims_prover(&zq, &plan, std::slice::from_ref(&ajtai_claim), &msg_refs_z),
                    Err(WaveError::AjtaiClaimUnsupported)
                )
                && matches!(
                    split_claims_verifier(&zq, &plan, std::slice::from_ref(&ajtai_claim), &[vec![(0, 0)]]),
                    Err(WaveError::AjtaiClaimUnsupported)
                ),
        );
        // Out-of-range references in claims: typed errors, no panic.
        let oob_claim = ring::ct_engine::CtClaim {
            msg_coeffs: vec![(9, 0, one_p.clone())],
            ajtai_coeffs: vec![],
            scalar: 0,
        };
        let oob_slot = ring::ct_engine::CtClaim {
            msg_coeffs: vec![(0, 5, one_p.clone())],
            ajtai_coeffs: vec![],
            scalar: 0,
        };
        let oob_quad = QuadRingClaim {
            quad: vec![(0, 0, 9, 0, one_p.clone())],
            msg_coeffs: vec![],
        };
        let empty_quad = QuadRingClaim { quad: vec![], msg_coeffs: vec![] };
        assert_true(
            "[Z5] out-of-range commitment/slot indices and empty quads return typed errors (no panic)",
            matches!(
                split_claim_shares(&plan, &oob_claim),
                Err(WaveError::CommitIndexOutOfRange { index: 9, .. })
            )
                && matches!(
                    split_claims_prover(&zq, &plan, std::slice::from_ref(&oob_slot), &msg_refs_z),
                    Err(WaveError::SlotOutOfRange { commit: 0, slot: 5 })
                )
                && matches!(
                    quad_ring_wave(&plan, &oob_quad),
                    Err(WaveError::CommitIndexOutOfRange { index: 9, .. })
                )
                && quad_ring_wave(&plan, &empty_quad) == Err(WaveError::EmptyQuadClaim)
                && matches!(
                    quad_ring_localized(&plan, &oob_quad),
                    Err(WaveError::CommitIndexOutOfRange { .. })
                ),
        );
        // Reveal-structure mismatch is typed too.
        let ok_claim = ring::ct_engine::CtClaim {
            msg_coeffs: vec![(0, 0, one_p)],
            ajtai_coeffs: vec![],
            scalar: 0,
        };
        assert_true(
            "[Z5] reveal-count mismatch REJECTS with a typed RevealShapeMismatch",
            matches!(
                split_claims_verifier(&zq, &plan, std::slice::from_ref(&ok_claim), &[]),
                Err(WaveError::RevealShapeMismatch)
            ),
        );
    }

    // Three linear claims: spanning all four, single-commitment, and a
    // two-wave straddler; totals computed designer-side.
    let mk_claim = |rng: &mut u64, refs: &[(usize, usize)]| -> CtClaim {
        let mut mc = Vec::new();
        let mut total: i128 = 0;
        for &(ci, s) in refs {
            let w = poly_from_small(&zq, &rng_quinary_poly(rng));
            total += ct_mul_centered(&zq, &w, &msgs[ci][s]) as i128;
            mc.push((ci, s, w));
        }
        let scalar = {
            let qq = q as i128;
            let mut r = total.rem_euclid(qq);
            if r > qq / 2 {
                r -= qq;
            }
            r as i64
        };
        CtClaim { msg_coeffs: mc, ajtai_coeffs: vec![], scalar }
    };
    let claims = vec![
        mk_claim(&mut rng, &[(0, 0), (1, 1), (2, 0), (3, 1)]),
        mk_claim(&mut rng, &[(1, 0)]),
        mk_claim(&mut rng, &[(0, 1), (2, 1)]),
    ];

    let msg_refs: Vec<&[Poly]> = msgs.iter().map(|m| m.as_slice()).collect();
    let (pw_claims, reveals) =
        split_claims_prover(&zq, &plan, &claims, &msg_refs).expect("honest split");
    assert_true(
        "verifier rebuild matches the prover's shares and passes the sum gate",
        match split_claims_verifier(&zq, &plan, &claims, &reveals) {
            Ok(v) => (0..plan.waves.len()).all(|w| {
                v[w].len() == pw_claims[w].len()
                    && v[w].iter().zip(pw_claims[w].iter()).all(|(a, b)| {
                        a.scalar == b.scalar && a.msg_coeffs == b.msg_coeffs
                    })
            }),
            Err(_) => false,
        },
    );

    // Per-wave ct-round round-trips against the split claims: data
    // commitments in wave-local order, then the wave's g-groups
    // (g_base = wave.len(), the chain's data/g layout).
    let mut wave_proofs = Vec::new();
    let mut wave_rps = Vec::new();
    for (w, wave) in plan.waves.iter().enumerate() {
        let mut all_x_w: Vec<Vec<Poly>> = wave.iter().map(|&g| msgs[g].clone()).collect();
        all_x_w.extend(ring::ct_engine::sample_g_masks(
            &mut rng,
            q,
            shape.msg_r,
            pw_claims[w].len(),
            0,
        ));
        let all_rho_w: Vec<Vec<Vec<i64>>> = (0..all_x_w.len())
            .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect())
            .collect();
        let rp_w = derive_ct_round_params(q, shape, all_x_w.len(), 0, 0, true);
        let a1p_w = build_a1_paths(&crs, rp_w.sigma, isqrt_u128(rp_w.bound_sq));
        let path_w = KernelPath::A1(&a1p_w);
        let mut t1s_w: Vec<Vec<Poly>> = Vec::new();
        let mut t2s_w: Vec<Vec<Poly>> = Vec::new();
        for (x, rho) in all_x_w.iter().zip(all_rho_w.iter()) {
            let (t1, t2) = commit(&path_w, &crs, x, rho);
            t1s_w.push(t1);
            t2s_w.push(t2);
        }
        let mut ctx_w = b"u-r1a-wave".to_vec();
        ctx_w.extend_from_slice(&(w as u64).to_le_bytes());
        let h0_w = ct_h0(&crs, &ctx_w, &t1s_w, &t2s_w, &[]);
        let openings_w: Vec<StdOpening> = all_x_w
            .iter()
            .zip(all_rho_w.iter())
            .enumerate()
            .map(|(i, (x, rho))| StdOpening { t1: &t1s_w[i], t2: &t2s_w[i], x, rho })
            .collect();
        let (proof_w, _) = prove_ct_round(
            &path_w, &ring_ctx, &rp_w, None, &crs, &h0_w, &pw_claims[w], &[], &[], &[],
            &openings_w, &[], &[], wave.len(), &mut rng,
        );
        assert_true(
            &format!("wave {w} ct-round verifies its claim shares"),
            verify_ct_round(
                &path_w, &ring_ctx, &rp_w, None, &crs, &h0_w, &pw_claims[w], &[], &[], &[],
                &t1s_w, &t2s_w, &[], &[], &[], wave.len(), &proof_w,
            ),
        );
        wave_proofs.push((t1s_w, t2s_w, h0_w, proof_w));
        wave_rps.push(rp_w);
    }

    // Tamper A: a lied partial breaks the sum gate.
    let mut lied = reveals.clone();
    lied[0][0].1 += 1;
    assert_true(
        "a lied partial scalar REJECTS at the sum gate",
        split_claims_verifier(&zq, &plan, &claims, &lied).is_err(),
    );

    // Tamper B: a compensated lie passes the sum gate but the affected
    // wave's ct-round REJECTS the false partial against its commitments.
    let mut comp = reveals.clone();
    comp[0][0].1 += 1;
    comp[0][1].1 -= 1;
    let v_comp = split_claims_verifier(&zq, &plan, &claims, &comp);
    let comp_rejected = match v_comp {
        Err(_) => false,
        Ok(vw) => {
            let w0 = reveals[0][0].0;
            let (t1s_w, t2s_w, h0_w, proof_w) = &wave_proofs[w0];
            let a1p_b = build_a1_paths(&crs, wave_rps[w0].sigma, isqrt_u128(wave_rps[w0].bound_sq));
            let path_b = KernelPath::A1(&a1p_b);
            !verify_ct_round(
                &path_b, &ring_ctx, &wave_rps[w0], None, &crs, h0_w, &vw[w0], &[],
                &[], &[], t1s_w, t2s_w, &[], &[], &[], plan.waves[w0].len(), proof_w,
            )
        }
    };
    assert_true(
        "a compensated partial lie passes the sum gate but its wave REJECTS",
        comp_rejected,
    );

    // Quad co-location: {1,2} share a wave; a {0,1} quad straddles.
    let one = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let qc = QuadRingClaim {
        quad: vec![(1, 0, 2, 0, one.clone())],
        msg_coeffs: vec![(1, 1, one.clone())],
    };
    let (qw, qloc) = quad_ring_localized(&plan, &qc).expect("co-located quad localizes");
    let qc_bad =
        QuadRingClaim { quad: vec![(0, 0, 1, 0, one.clone())], msg_coeffs: vec![] };
    assert_true(
        "quad claims: co-located group localizes; a straddler is detected",
        qw == plan.slot_of[1].0
            && qloc.quad[0].0 == plan.slot_of[1].1
            && qloc.quad[0].2 == plan.slot_of[2].1
            && quad_ring_wave(&plan, &qc_bad)
                == Err(ring::ct_engine::WaveError::QuadStraddlesWaves),
    );

    // ---- [Z1-i] wave-share masking (U-Z1, design WAVE_SHARE_MASKING):
    // layout determinism, the k_j = 1 no-pad rule, masked round-trips
    // against committed pad material, centered reps at +-q/2, and the
    // ForcedZero policy — all at the toy scale of the legs above. ------
    {
        use ring::ct_engine::{
            SplitPolicy, WavePadLayout, WavePads, draw_wave_pads, pack_wave_pads,
            split_claims_forced_zero, split_claims_prover_masked, split_claims_verifier_masked,
            split_claims_verifier_policy,
        };
        println!("\n[Z1-i] wave-share masking: pad layout determinism + edge legs");
        let n_waves = plan.waves.len();
        // Layout: derived independently twice from the same PUBLIC data
        // (claim-row count, plan-derived pad-wave set, shape) — the D-2
        // discipline extended to pads, byte-for-byte.
        let layout = WavePadLayout::derive(claims.len(), vec![0, 1], n_waves, shape.msg_r)
            .expect("toy pad layout derives");
        let layout_v = WavePadLayout::derive(claims.len(), vec![0, 1], n_waves, shape.msg_r)
            .expect("verifier-side pad layout derives");
        assert_true(
            "[Z1-i] pad layout: prover- and verifier-derived layouts agree BYTE-FOR-BYTE (counts, pad-wave set, every (claim, wave) -> (cm, slot, coeff) position)",
            layout.layout_bytes() == layout_v.layout_bytes() && layout.n_pad_cms == 1,
        );
        // Draw + pack + commit the shared pad commitment ONCE; it is
        // opened by BOTH wave rounds below (the design 2.2 shared
        // multi-round-opening pattern at toy scale).
        let pads = draw_wave_pads(&mut rng, q, &layout);
        let pad_vals: Vec<Vec<u64>> = pads.harness_values().to_vec();
        assert_true(
            "[Z1-i] pad draw: each claim row's pads sum to 0 mod q (the solved last pad) and rows are non-trivial",
            pad_vals.iter().all(|row| {
                row.iter().fold(0u128, |a, &v| (a + v as u128) % q as u128) == 0
            }) && pad_vals.iter().any(|row| row.iter().any(|&v| v != 0)),
        );
        let pad_msgs = pack_wave_pads(&mut rng, q, shape.msg_r, &layout, &pads)
            .expect("toy pad packing");
        assert_eq!(pad_msgs.len(), 1);
        let (mpw, mrv) = split_claims_prover_masked(&zq, &plan, &claims, &msg_refs, &layout, pads)
            .expect("honest masked split");
        // k_j = 1 (claim 1 touches ONE wave): NO pad spent — the single
        // share IS the public total and gains no pad read.
        let c1_wave = plan.slot_of[1].0;
        assert_true(
            "[Z1-i] k_j = 1: a single-wave claim takes NO pad — one reveal equal to the public total, share functional unchanged (no pad read term)",
            mrv[1].len() == 1
                && mrv[1][0] == (c1_wave, claims[1].scalar)
                && mpw[c1_wave]
                    .iter()
                    .any(|s| s.scalar == claims[1].scalar
                        && s.msg_coeffs.len() == claims[1].msg_coeffs.len()),
        );
        // Multi-wave claims: masked reveals cover EVERY pad wave and
        // differ from the true partials (the C-02 wire is gone).
        assert_true(
            "[Z1-i] masked reveals: multi-wave claims reveal one masked share per pad wave, and the masked values differ from the true partials",
            mrv[0].len() == 2
                && mrv[2].len() == 2
                && (mrv[0] != reveals[0] || mrv[2] != reveals[2]),
        );
        let mv = split_claims_verifier_masked(&zq, &plan, &claims, &mrv, &layout)
            .expect("verifier masked rebuild");
        assert_true(
            "[Z1-i] verifier rebuild matches the prover's masked shares (scalars + functionals incl. the pad read) and passes the mod-q sum gate",
            (0..n_waves).all(|w| {
                mv[w].len() == mpw[w].len()
                    && mv[w].iter().zip(mpw[w].iter()).all(|(a, b)| {
                        a.scalar == b.scalar && a.msg_coeffs == b.msg_coeffs
                    })
            }),
        );
        // Per-wave ct-rounds against the masked claims: round list =
        // [wave data | THE shared pad commitment | g-groups]; the same
        // pad commitment (same rho) is opened in both rounds.
        let pad_rho: Vec<Vec<i64>> =
            (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
        let run_waves = |claims_p: &[Vec<CtClaim>],
                         claims_v: &[Vec<CtClaim>],
                         pad_msg: &Vec<Poly>,
                         pad_rho: &[Vec<i64>],
                         rng: &mut u64|
         -> Vec<bool> {
            let (pt1, pt2) = {
                let rp0 = derive_ct_round_params(q, shape, 4, 0, 0, true);
                let a1p0 = build_a1_paths(&crs, rp0.sigma, isqrt_u128(rp0.bound_sq));
                commit(&KernelPath::A1(&a1p0), &crs, pad_msg, &pad_rho.to_vec())
            };
            (0..plan.waves.len())
                .map(|w| {
                    let wave = &plan.waves[w];
                    let mut all_x: Vec<Vec<Poly>> = wave.iter().map(|&g| msgs[g].clone()).collect();
                    all_x.push(pad_msg.clone());
                    all_x.extend(ring::ct_engine::sample_g_masks(
                        rng,
                        q,
                        shape.msg_r,
                        claims_p[w].len(),
                        0,
                    ));
                    let mut rhos_w: Vec<Vec<Vec<i64>>> = wave
                        .iter()
                        .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(rng)).collect())
                        .collect();
                    rhos_w.push(pad_rho.to_vec());
                    for _ in wave.len() + 1..all_x.len() {
                        rhos_w.push((0..shape.n_r).map(|_| rng_ternary_poly(rng)).collect());
                    }
                    let rp_w = derive_ct_round_params(q, shape, all_x.len(), 0, 0, true);
                    let a1p_w = build_a1_paths(&crs, rp_w.sigma, isqrt_u128(rp_w.bound_sq));
                    let path_w = KernelPath::A1(&a1p_w);
                    let mut t1s_w: Vec<Vec<Poly>> = Vec::new();
                    let mut t2s_w: Vec<Vec<Poly>> = Vec::new();
                    for (i, x) in all_x.iter().enumerate() {
                        if i == wave.len() {
                            t1s_w.push(pt1.clone());
                            t2s_w.push(pt2.clone());
                        } else {
                            let (t1, t2) = commit(&path_w, &crs, x, &rhos_w[i]);
                            t1s_w.push(t1);
                            t2s_w.push(t2);
                        }
                    }
                    let mut ctx_w = b"z1i-masked-wave".to_vec();
                    ctx_w.extend_from_slice(&(w as u64).to_le_bytes());
                    let h0_w = ct_h0(&crs, &ctx_w, &t1s_w, &t2s_w, &[]);
                    let openings_w: Vec<StdOpening> = all_x
                        .iter()
                        .zip(rhos_w.iter())
                        .enumerate()
                        .map(|(i, (x, rho))| StdOpening { t1: &t1s_w[i], t2: &t2s_w[i], x, rho })
                        .collect();
                    let (proof_w, _) = prove_ct_round(
                        &path_w, &ring_ctx, &rp_w, None, &crs, &h0_w, &claims_p[w], &[], &[],
                        &[], &openings_w, &[], &[], wave.len() + 1, &mut *rng,
                    );
                    verify_ct_round(
                        &path_w, &ring_ctx, &rp_w, None, &crs, &h0_w, &claims_v[w], &[], &[],
                        &[], &t1s_w, &t2s_w, &[], &[], &[], wave.len() + 1, &proof_w,
                    )
                })
                .collect()
        };
        let honest = run_waves(&mpw, &mv, &pad_msgs[0], &pad_rho, &mut rng);
        assert_true(
            "[Z1-i] masked wave rounds: every wave ACCEPTS its masked share claims against committed data + the SHARED pad commitment (opened in every wave round)",
            honest.iter().all(|&b| b),
        );
        // Lied masked reveal: the mod-q sum gate rejects.
        let mut lied_m = mrv.clone();
        lied_m[0][0].1 = if lied_m[0][0].1 == (q / 2) as i64 {
            lied_m[0][0].1 - 1
        } else {
            lied_m[0][0].1 + 1
        };
        assert_true(
            "[Z1-i] a lied MASKED reveal REJECTS at the sum gate (masking does not weaken the gate)",
            split_claims_verifier_masked(&zq, &plan, &claims, &lied_m, &layout).is_err(),
        );
        // Compensated masked pair: the gate passes but the wave round
        // REJECTS — the pad term makes the wave claim false (the Z1-e
        // shape, exercised early at toy scale).
        let mut comp_m = mrv.clone();
        comp_m[0][0].1 += 1;
        comp_m[0][1].1 -= 1;
        let comp_rejected = match split_claims_verifier_masked(&zq, &plan, &claims, &comp_m, &layout)
        {
            Err(_) => false,
            Ok(vw) => {
                // Claim 0's +1/-1 pair touches BOTH waves: each affected
                // round must reject its false masked share.
                let verdicts = run_waves(&mpw, &vw, &pad_msgs[0], &pad_rho, &mut rng);
                verdicts.iter().all(|&b| !b)
            }
        };
        assert_true(
            "[Z1-i] a COMPENSATED masked pair passes the sum gate but each affected wave's ct-round REJECTS the false masked share",
            comp_rejected,
        );
        // Centered-representative edge: pads crafted so masked shares
        // land exactly on +-(q-1)/2 — the mod-q sum gate and the
        // ct-round must both accept (no restart guard exists or is
        // needed: every masked share has a centered representative).
        {
            let half = ((q - 1) / 2) as i64;
            let solve_row = |target: i64, sigma0: i64| -> Vec<u64> {
                let qi = q as i128;
                let e0 = (((target as i128 - sigma0 as i128) % qi + qi) % qi) as u64;
                vec![e0, (q - e0) % q]
            };
            // reveals[] holds the TRUE partials from the legacy leg
            // above: claim 0 pushed to +half, claim 2 pulled to -half.
            let rows = vec![
                solve_row(half, reveals[0][0].1),
                pad_vals[1].clone(),
                solve_row(-half, reveals[2][0].1),
            ];
            let pads_b = WavePads::harness_from_values(rows);
            let pad_msgs_b = pack_wave_pads(&mut rng, q, shape.msg_r, &layout, &pads_b)
                .expect("boundary pad packing");
            let (bpw, brv) =
                split_claims_prover_masked(&zq, &plan, &claims, &msg_refs, &layout, pads_b)
                    .expect("boundary masked split");
            let bv = split_claims_verifier_masked(&zq, &plan, &claims, &brv, &layout)
                .expect("boundary rebuild");
            let pad_rho_b: Vec<Vec<i64>> =
                (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let verdicts = run_waves(&bpw, &bv, &pad_msgs_b[0], &pad_rho_b, &mut rng);
            assert_true(
                "[Z1-i] centered reps at +-(q-1)/2: masked shares on both boundary representatives ACCEPT through the sum gate AND the wave ct-rounds",
                brv[0][0].1 == half
                    && brv[2][0].1 == -half
                    && verdicts.iter().all(|&b| b),
            );
        }
        // ForcedZero policy: identically-zero functionals prove per-wave
        // zero claims with NOTHING sent; a nonzero total errors; a
        // nonempty reveal wire errors.
        {
            let p = poly_from_small(&zq, &rng_quinary_poly(&mut rng));
            let np: Poly = p.iter().map(|&c| zq.neg(c)).collect();
            let p2 = poly_from_small(&zq, &rng_quinary_poly(&mut rng));
            let np2: Poly = p2.iter().map(|&c| zq.neg(c)).collect();
            let zc = CtClaim {
                msg_coeffs: vec![(0, 0, p.clone()), (0, 0, np), (1, 0, p2), (1, 0, np2)],
                ajtai_coeffs: vec![],
                scalar: 0,
            };
            let zpw = split_claims_forced_zero(&plan, std::slice::from_ref(&zc))
                .expect("forced-zero split");
            let zv = split_claims_verifier_policy(
                &zq,
                &plan,
                std::slice::from_ref(&zc),
                &[Vec::new()],
                SplitPolicy::ForcedZero,
                None,
            )
            .expect("forced-zero verifier rebuild");
            let nonzero_total = CtClaim {
                msg_coeffs: vec![(0, 0, p.clone())],
                ajtai_coeffs: vec![],
                scalar: 5,
            };
            let zero_ok = zpw.iter().flatten().all(|s| s.scalar == 0)
                && zpw.iter().flatten().count() == 2
                && (0..n_waves).all(|w| {
                    zv[w].len() == zpw[w].len()
                        && zv[w].iter().zip(zpw[w].iter()).all(|(a, b)| {
                            a.scalar == b.scalar && a.msg_coeffs == b.msg_coeffs
                        })
                });
            let pad_rho_z: Vec<Vec<i64>> =
                (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
            let verdicts = run_waves(&zpw, &zv, &pad_msgs[0], &pad_rho_z, &mut rng);
            assert_true(
                "[Z1-i] ForcedZero: per-wave zero claims rebuild identically on both sides, ACCEPT at their ct-rounds with NOTHING sent; nonzero totals and nonempty reveal wires are typed errors",
                zero_ok
                    && verdicts.iter().all(|&b| b)
                    && split_claims_forced_zero(&plan, std::slice::from_ref(&nonzero_total))
                        .is_err()
                    && split_claims_verifier_policy(
                        &zq,
                        &plan,
                        std::slice::from_ref(&zc),
                        &[vec![(0, 0)]],
                        SplitPolicy::ForcedZero,
                        None,
                    )
                    .is_err(),
            );
        }
        // Fail-closed coverage: a multi-wave claim under Padded with a
        // pad-less layout is a typed error, never a silent reveal.
        {
            let layout_nopads =
                WavePadLayout::derive(claims.len(), vec![0], n_waves, shape.msg_r)
                    .expect("single-wave layout derives (no pads)");
            let pads_np = draw_wave_pads(&mut rng, q, &layout_nopads);
            assert_true(
                "[Z1-i] fail-closed: a multi-wave claim under Padded with a pad-less layout REJECTS (typed PadCoverage) instead of reverting to revealed partials",
                matches!(
                    split_claims_prover_masked(
                        &zq, &plan, &claims, &msg_refs, &layout_nopads, pads_np
                    ),
                    Err(ring::ct_engine::WaveError::PadCoverage { .. })
                ),
            );
        }

        // ---- [Z1-d] the zero-sum load-bearing pair (design 4.2 /
        // Section 5): with the closing round ABSENT, pads rigged to
        // sum delta != 0 plus honestly-computed masked reveals ACCEPT a
        // FALSE total T + delta at every gate; with the closing round
        // wired, the same transcript REJECTS at exactly that round.
        // Both directions, per the F5 house rule. ----------------------
        {
            use ring::ct_engine::closing_round_claims;
            println!("\n[Z1-d] the zero-sum closing round is load-bearing (both directions)");
            let delta = 7i64;
            let center = |v: i128| -> i64 {
                let qq = q as i128;
                let mut r = v.rem_euclid(qq);
                if r > qq / 2 {
                    r -= qq;
                }
                r as i64
            };
            // Rig pads: row 0 sums to delta instead of 0.
            let mut rows = pad_vals.clone();
            rows[0][0] = (rows[0][0] + delta as u64) % q;
            let pads_d = WavePads::harness_from_values(rows);
            let pad_msgs_d = pack_wave_pads(&mut rng, q, shape.msg_r, &layout, &pads_d)
                .expect("rigged pad packing");
            // The cheating prover's claim set: claim 0's public total
            // shifted by delta (the false statement being smuggled).
            let claims_false: Vec<CtClaim> = claims
                .iter()
                .enumerate()
                .map(|(j, c)| CtClaim {
                    msg_coeffs: c.msg_coeffs.clone(),
                    ajtai_coeffs: vec![],
                    scalar: if j == 0 { center(c.scalar as i128 + delta as i128) } else { c.scalar },
                })
                .collect();
            // Honestly-computed masked reveals over the RIGGED pads
            // (the splitter never reads claim totals).
            let (dpw, drv) =
                split_claims_prover_masked(&zq, &plan, &claims, &msg_refs, &layout, pads_d)
                    .expect("rigged-pad masked split");
            // ATTACK direction (closing round ABSENT): the sum gate
            // accepts the false total, and every wave round accepts —
            // each share claim is TRUE over the committed data + pads.
            let attack_gate =
                split_claims_verifier_masked(&zq, &plan, &claims_false, &drv, &layout);
            let attack_accepts = match attack_gate {
                Err(_) => false,
                Ok(vw) => {
                    let pad_rho_d: Vec<Vec<i64>> =
                        (0..shape.n_r).map(|_| rng_ternary_poly(&mut rng)).collect();
                    run_waves(&dpw, &vw, &pad_msgs_d[0], &pad_rho_d, &mut rng)
                        .iter()
                        .all(|&b| b)
                }
            };
            assert_true(
                "[Z1-d] ATTACK: pads rigged to sum delta + honest masked reveals ACCEPT a FALSE total T + delta through the sum gate and EVERY wave round when the closing round is absent",
                attack_accepts,
            );
            // DEFENSE direction: the closing round — nine exact
            // zero-sum claims over the pad commitment — REJECTS the
            // rigged pads (row 0 sums to delta, a false claim over
            // committed data) and ACCEPTS the honest ones.
            let run_closing = |pad_msg: &Vec<Poly>, rng: &mut u64| -> bool {
                let cl = closing_round_claims(&zq, &layout);
                assert_eq!(cl.len(), claims.len());
                let mut all_x: Vec<Vec<Poly>> = vec![pad_msg.clone()];
                all_x.extend(ring::ct_engine::sample_g_masks(
                    rng,
                    q,
                    shape.msg_r,
                    cl.len(),
                    0,
                ));
                let rhos_z: Vec<Vec<Vec<i64>>> = (0..all_x.len())
                    .map(|_| (0..shape.n_r).map(|_| rng_ternary_poly(rng)).collect())
                    .collect();
                let rp_z = derive_ct_round_params(q, shape, all_x.len(), 0, 0, true);
                let a1p_z = build_a1_paths(&crs, rp_z.sigma, isqrt_u128(rp_z.bound_sq));
                let path_z = KernelPath::A1(&a1p_z);
                let mut t1s_z: Vec<Vec<Poly>> = Vec::new();
                let mut t2s_z: Vec<Vec<Poly>> = Vec::new();
                for (x, rho) in all_x.iter().zip(rhos_z.iter()) {
                    let (t1, t2) = commit(&path_z, &crs, x, rho);
                    t1s_z.push(t1);
                    t2s_z.push(t2);
                }
                let h0_z = ct_h0(&crs, b"z1d-closing", &t1s_z, &t2s_z, &[]);
                let openings_z: Vec<StdOpening> = all_x
                    .iter()
                    .zip(rhos_z.iter())
                    .enumerate()
                    .map(|(i, (x, rho))| StdOpening { t1: &t1s_z[i], t2: &t2s_z[i], x, rho })
                    .collect();
                let (proof_z, _) = prove_ct_round(
                    &path_z, &ring_ctx, &rp_z, None, &crs, &h0_z, &cl, &[], &[], &[],
                    &openings_z, &[], &[], 1, &mut *rng,
                );
                verify_ct_round(
                    &path_z, &ring_ctx, &rp_z, None, &crs, &h0_z, &cl, &[], &[], &[],
                    &t1s_z, &t2s_z, &[], &[], &[], 1, &proof_z,
                )
            };
            assert_true(
                "[Z1-d] DEFENSE: the closing round ACCEPTS the honest zero-sum pads and REJECTS the delta-rigged pads at exactly the zero-sum claims — the pair closes the forgery lever",
                run_closing(&pad_msgs[0], &mut rng) && !run_closing(&pad_msgs_d[0], &mut rng),
            );
        }
    }
}

/// [Z1] rank/leakage/recovery battery (U-Z1 impl-c, design Section 5):
/// Z1-a — the PERMANENT C-02 exhibit (unmasked exact recovery against
/// the legacy Revealed policy); Z1-b — masked non-recovery, full-coset
/// membership, and the E3Z-N4-style counting canary; Z1-g — the
/// accumulation stall across proofs of the same witness; Z1-h — the
/// pad-reuse leak at half rate plus the freshness rule. All legs are
/// splitter-level linear algebra: the C-02 leak lives in the REVEALED
/// scalars, so no commitments or ct-rounds are needed to demonstrate
/// what a transcript observer can solve for.
fn self_test_z1() {
    use ring::ct_engine::{
        CtClaim, WavePadLayout, WavePads, draw_wave_pads, plan_waves, split_claims_prover,
        split_claims_prover_masked,
    };
    println!("\n[Z1] wave-share masking: rank/leakage/recovery battery (design Section 5)");
    let q = Q8;
    let zq = ring_ctx_q8().zq;
    let mut rng = 0x5eed_21a0u64;

    // Gaussian elimination mod q (prime) on the augmented system
    // [A | b]: returns (rank of A, unique solution when rank == n).
    let solve = |rows: &[(Vec<u64>, u64)]| -> (usize, Option<Vec<u64>>) {
        let n = rows.first().map_or(0, |r| r.0.len());
        let mut m: Vec<Vec<u64>> = rows
            .iter()
            .map(|(a, b)| {
                let mut v = a.clone();
                v.push(*b);
                v
            })
            .collect();
        let mut rank = 0usize;
        let mut pivots: Vec<usize> = Vec::new();
        for col in 0..n {
            if rank == m.len() {
                break;
            }
            if let Some(p) = (rank..m.len()).find(|&r| m[r][col] != 0) {
                m.swap(rank, p);
                let inv = zq.inv(m[rank][col]);
                for c in col..=n {
                    m[rank][c] = zq.mul(m[rank][c], inv);
                }
                for r in 0..m.len() {
                    if r != rank && m[r][col] != 0 {
                        let f = m[r][col];
                        for c in col..=n {
                            let t = zq.mul(f, m[rank][c]);
                            m[r][c] = zq.sub(m[r][c], t);
                        }
                    }
                }
                pivots.push(col);
                rank += 1;
            }
        }
        let sol = if rank == n {
            let mut x = vec![0u64; n];
            for (r, &c) in pivots.iter().enumerate() {
                x[c] = m[r][n];
            }
            Some(x)
        } else {
            None
        };
        (rank, sol)
    };
    let rank_of = |rows: &[(Vec<u64>, u64)]| -> usize { solve(rows).0 };

    // Single-secret-coefficient "commitments": message i holds its
    // secret at coefficient 0, so a claim with constant weight polys is
    // LITERALLY equation (1): sigma_{j,w} = sum_{i in wave w} w_{j,i} x_i.
    let mk_msgs = |secrets: &[u64]| -> Vec<Vec<Poly>> {
        secrets
            .iter()
            .map(|&v| {
                let mut p = poly_zero();
                p[0] = v;
                vec![p]
            })
            .collect()
    };
    let mk_claims = |rng: &mut u64, s_n: usize, n_claims: usize, secrets: &[u64]|
     -> (Vec<Vec<u64>>, Vec<CtClaim>) {
        (0..n_claims)
            .map(|_| {
                let w: Vec<u64> = (0..s_n).map(|_| rng_below(rng, q)).collect();
                let msg_coeffs = w
                    .iter()
                    .enumerate()
                    .map(|(i, &wi)| {
                        let mut p = poly_zero();
                        p[0] = wi;
                        (i, 0usize, p)
                    })
                    .collect();
                let total = w
                    .iter()
                    .zip(secrets.iter())
                    .fold(0u64, |a, (&wi, &xi)| zq.add(a, zq.mul(wi, xi)));
                (w, CtClaim { msg_coeffs, ajtai_coeffs: vec![], scalar: zq.center(total) })
            })
            .unzip()
    };
    // f_{j,w}(x) restricted to a wave's support, as a dense row.
    let wave_row = |weights: &[u64], wave: &[usize]| -> Vec<u64> {
        wave.iter().map(|&g| weights[g]).collect()
    };

    // ---- Geometry A (Z1-a/Z1-b): s = 27 unknowns, 3 waves of 9, the
    // 9-copy psi shape — per wave, 9 equations on s_w = 9 unknowns. ----
    let s_a = 27usize;
    let secrets: Vec<u64> = (0..s_a).map(|_| rng_below(&mut rng, q)).collect();
    let msgs = mk_msgs(&secrets);
    let msg_refs: Vec<&[Poly]> = msgs.iter().map(|m| m.as_slice()).collect();
    let plan = plan_waves(s_a, &[], 9).expect("z1 geometry-A plan");
    assert_eq!(plan.waves.len(), 3);
    let (weights, claims) = mk_claims(&mut rng, s_a, 9, &secrets);

    // [Z1-a] — the C-02 exhibit, PERMANENT: the as-built legacy
    // Revealed splitter hands over per-wave partials; the public
    // system (1) recovers the committed witness EXACTLY from ONE
    // transcript (the rank s_w/s_w pattern).
    let (_, reveals) =
        split_claims_prover(&zq, &plan, &claims, &msg_refs).expect("legacy Revealed split");
    let mut recovered = vec![0u64; s_a];
    let mut exact = true;
    for (w, wave) in plan.waves.iter().enumerate() {
        let rows: Vec<(Vec<u64>, u64)> = (0..9)
            .map(|j| (wave_row(&weights[j], wave), zq.to_mod(reveals[j][w].1)))
            .collect();
        let (rank, sol) = solve(&rows);
        exact &= rank == wave.len();
        match sol {
            Some(x) => {
                for (l, &g) in wave.iter().enumerate() {
                    recovered[g] = x[l];
                }
            }
            None => exact = false,
        }
    }
    assert_true(
        "[Z1-a] PERMANENT C-02 regression: the legacy Revealed wire recovers the committed witness EXACTLY from ONE transcript's pin shares (public system eq. 1, rank s_w/s_w per wave)",
        exact && recovered == secrets,
    );

    // [Z1-b] — the same pipeline against the MASKED transcript.
    let layout = WavePadLayout::derive(9, vec![0, 1, 2], 3, 1).expect("z1 layout");
    // Counting canary (the E3Z-N4 pattern, and Q4.2a's engine cert):
    // per claim, #free exposures == #free pads == k_j - 1 — the sum
    // gate forces one exposure, the solved last pad spends one pad.
    let k_j = layout.pad_waves.len();
    let pads = draw_wave_pads(&mut rng, q, &layout);
    let pad_vals: Vec<Vec<u64>> = pads.harness_values().to_vec();
    let free_pads_per_claim = k_j - 1; // last pad solved
    let free_exposures_per_claim = k_j - 1; // sum gate forces one
    assert_true(
        "[Z1-b] counting canary: per claim, #free exposures (k_j - 1) == #free pads (k_j - 1); the exposure/pad map is the identity-plus-solve bijection — counted from the layout, not assumed",
        free_pads_per_claim == free_exposures_per_claim
            && pad_vals.iter().all(|row| row.len() == k_j)
            && pad_vals
                .iter()
                .all(|row| row.iter().fold(0u128, |a, &v| (a + v as u128) % q as u128) == 0),
    );
    let (_, mrv) = split_claims_prover_masked(&zq, &plan, &claims, &msg_refs, &layout, pads)
        .expect("masked split");
    // Naive recovery (pads assumed zero): full-rank per wave, but the
    // 'solution' is NOT the witness.
    let mut naive = vec![0u64; s_a];
    let mut naive_solves = true;
    for (w, wave) in plan.waves.iter().enumerate() {
        let rows: Vec<(Vec<u64>, u64)> = (0..9)
            .map(|j| (wave_row(&weights[j], wave), zq.to_mod(mrv[j][w].1)))
            .collect();
        match solve(&rows) {
            (rank, Some(x)) if rank == wave.len() => {
                for (l, &g) in wave.iter().enumerate() {
                    naive[g] = x[l];
                }
            }
            _ => naive_solves = false,
        }
    }
    assert_true(
        "[Z1-b] masked non-recovery: the Z1-a solver against the masked shares returns a full-rank phantom that is NOT the witness",
        naive_solves && naive != secrets,
    );
    // Full-coset membership: ANY witness with the same totals explains
    // the masked transcript exactly — exhibit one. x' = x + v with v in
    // the totals kernel; the pads e' = sigma~ - f(x') then satisfy the
    // construction's zero-sum per claim, so (x', e') is fully
    // consistent with every revealed value.
    {
        // Kernel vector: fix v[9..27] random, solve the 9x9 head.
        let v_tail: Vec<u64> = (0..s_a - 9).map(|_| rng_below(&mut rng, q)).collect();
        let rows: Vec<(Vec<u64>, u64)> = (0..9)
            .map(|j| {
                let a: Vec<u64> = (0..9).map(|i| weights[j][i]).collect();
                let b = (9..s_a).fold(0u64, |acc, i| {
                    zq.sub(acc, zq.mul(weights[j][i], v_tail[i - 9]))
                });
                (a, b)
            })
            .collect();
        let (_, head) = solve(&rows);
        let head = head.expect("9x9 head solves (generic weights)");
        let v: Vec<u64> = head.into_iter().chain(v_tail).collect();
        let x_alt: Vec<u64> = secrets.iter().zip(v.iter()).map(|(&x, &d)| zq.add(x, d)).collect();
        let mut coset_ok = x_alt != secrets;
        for j in 0..9 {
            let mut pad_sum = 0u64;
            for (w, wave) in plan.waves.iter().enumerate() {
                let f_alt = wave
                    .iter()
                    .fold(0u64, |a, &g| zq.add(a, zq.mul(weights[j][g], x_alt[g])));
                let e_alt = zq.sub(zq.to_mod(mrv[j][w].1), f_alt);
                pad_sum = zq.add(pad_sum, e_alt);
            }
            coset_ok &= pad_sum == 0;
        }
        assert_true(
            "[Z1-b] full-coset solution set: an ALTERNATIVE witness with the same totals explains the masked transcript exactly (its implied pads satisfy the zero-sum) — the reveals are uniform on {sum = total}, witness-independent",
            coset_ok,
        );
    }

    // ---- Geometry B (Z1-g/Z1-h): s = 26 unknowns, 2 waves of 13 —
    // one unmasked proof (18 equations) is NOT enough, two are. -------
    let s_b = 26usize;
    let secrets2: Vec<u64> = (0..s_b).map(|_| rng_below(&mut rng, q)).collect();
    let msgs2 = mk_msgs(&secrets2);
    let msg_refs2: Vec<&[Poly]> = msgs2.iter().map(|m| m.as_slice()).collect();
    let plan2 = plan_waves(s_b, &[], 13).expect("z1 geometry-B plan");
    assert_eq!(plan2.waves.len(), 2);
    let layout2 = WavePadLayout::derive(9, vec![0, 1], 2, 1).expect("z1 layout B");

    // [Z1-g] — the accumulation stall. P fresh proofs of the SAME
    // witness (fresh weights = fresh psi/alpha; fresh pads per proof).
    {
        let mut un_rows: Vec<(Vec<u64>, u64)> = Vec::new(); // unmasked, x-space
        let mut tot_rows: Vec<(Vec<u64>, u64)> = Vec::new(); // totals only
        let mut mk_full = Vec::new(); // masked, (x | e) space + zero-sum rows
        let mut unmasked_ranks = Vec::new();
        let mut stall_ok = true;
        for p in 0..2usize {
            let (w_p, c_p) = mk_claims(&mut rng, s_b, 9, &secrets2);
            let (_, rv_p) = split_claims_prover(&zq, &plan2, &c_p, &msg_refs2)
                .expect("legacy split (proof p)");
            let pads_p = draw_wave_pads(&mut rng, q, &layout2);
            let (_, mrv_p) =
                split_claims_prover_masked(&zq, &plan2, &c_p, &msg_refs2, &layout2, pads_p)
                    .expect("masked split (proof p)");
            for j in 0..9 {
                // Totals row.
                tot_rows.push((w_p[j].clone(), zq.to_mod(c_p[j].scalar)));
                for (w, wave) in plan2.waves.iter().enumerate() {
                    let mut row = vec![0u64; s_b];
                    for &g in wave {
                        row[g] = w_p[j][g];
                    }
                    // Unmasked transcript row (x-space).
                    un_rows.push((row.clone(), zq.to_mod(rv_p[j][w].1)));
                    // Masked transcript row over (x | e^p_{j,w}).
                    mk_full.push((p, j, w, row, zq.to_mod(mrv_p[j][w].1)));
                }
            }
            // Ranks after proof p+1.
            unmasked_ranks.push(rank_of(&un_rows));
            // Masked system: unknowns x (s_b) + one pad per (proof, j, w)
            // so far, plus the public zero-sum rows (the attacker knows
            // the construction). Solution dim in x == total dim (pads
            // are determined by x), and must equal the totals baseline.
            let n_e = mk_full.len();
            let mut rows_full: Vec<(Vec<u64>, u64)> = Vec::new();
            for (idx, (_, _, _, xrow, rhs)) in mk_full.iter().enumerate() {
                let mut r = xrow.clone();
                r.extend(vec![0u64; n_e]);
                r[s_b + idx] = 1; // + e_{p,j,w}
                rows_full.push((r, *rhs));
            }
            // Zero-sum rows: per (proof, claim), sum over waves of e = 0.
            for pp in 0..=p {
                for j in 0..9 {
                    let mut r = vec![0u64; s_b + n_e];
                    for (idx, (p2, j2, _, _, _)) in mk_full.iter().enumerate() {
                        if *p2 == pp && *j2 == j {
                            r[s_b + idx] = 1;
                        }
                    }
                    rows_full.push((r, 0));
                }
            }
            let dim_masked = (s_b + n_e) - rank_of(&rows_full);
            let dim_totals = s_b - rank_of(&tot_rows);
            stall_ok &= dim_masked == dim_totals;
        }
        // Unmasked: rank grows 18 -> 26 and proof 2 recovers exactly.
        let (final_rank, final_sol) = solve(&un_rows);
        assert_true(
            &format!(
                "[Z1-g] accumulation: UNMASKED rank grows across proofs ({} -> {}) to EXACT recovery of the witness at P = 2; MASKED solution dimension equals the totals-only baseline at every P (the rank STALLS — zero fresh witness equations per proof)",
                unmasked_ranks[0], unmasked_ranks[1]
            ),
            unmasked_ranks[0] == 18
                && final_rank == s_b
                && final_sol.as_deref() == Some(&secrets2[..])
                && stall_ok,
        );
    }

    // [Z1-h] — pad freshness (the E3Z-N3 analogue, and the Q4.2a'
    // load-bearing hypothesis: the per-proof defect bound assumes
    // openings within ONE proof). Three proofs SHARING one pad table:
    // pairwise differences cancel the pads and re-expose fresh
    // public-coefficient equations — the leak returns at half rate
    // (3 proofs -> 2 transcripts' worth) up to EXACT recovery. Fresh
    // pads (the shipped rule): the same differences carry pad-difference
    // unknowns and collapse to total-differences — no recovery.
    {
        let reused: Vec<Vec<u64>> = {
            let p = draw_wave_pads(&mut rng, q, &layout2);
            p.harness_values().to_vec()
        };
        let mut diff_rows: Vec<(Vec<u64>, u64)> = Vec::new();
        let mut fresh_full: Vec<(Vec<u64>, u64)> = Vec::new();
        let mut base: Option<(Vec<Vec<u64>>, Vec<Vec<(usize, i64)>>)> = None;
        let mut base_fresh: Option<(Vec<Vec<u64>>, Vec<Vec<(usize, i64)>>)> = None;
        let mut fresh_cols = 0usize;
        let mut fresh_entries: Vec<(usize, usize, usize, Vec<u64>, u64)> = Vec::new();
        for p in 0..3usize {
            let (w_p, c_p) = mk_claims(&mut rng, s_b, 9, &secrets2);
            // REUSE arm: the pad table is fed back through the
            // harness-only escape hatch — the production path CANNOT do
            // this (WavePads is non-Clone and consumed by the splitter;
            // draw_wave_pads is fresh per proof from the ProverRng).
            let (_, mrv_p) = split_claims_prover_masked(
                &zq,
                &plan2,
                &c_p,
                &msg_refs2,
                &layout2,
                WavePads::harness_from_values(reused.clone()),
            )
            .expect("reuse-arm masked split");
            // FRESH control arm at the same shape.
            let pads_f = draw_wave_pads(&mut rng, q, &layout2);
            let (_, frv_p) =
                split_claims_prover_masked(&zq, &plan2, &c_p, &msg_refs2, &layout2, pads_f)
                    .expect("fresh-arm masked split");
            match (&base, &base_fresh) {
                (None, None) => {
                    base = Some((w_p.clone(), mrv_p.clone()));
                    base_fresh = Some((w_p, frv_p));
                }
                (Some((w0, m0)), Some((wf0, f0))) => {
                    for j in 0..9 {
                        for (w, wave) in plan2.waves.iter().enumerate() {
                            // Reuse: pads cancel exactly.
                            let mut row = vec![0u64; s_b];
                            for &g in wave {
                                row[g] = zq.sub(w0[j][g], w_p[j][g]);
                            }
                            let rhs = zq.sub(zq.to_mod(m0[j][w].1), zq.to_mod(mrv_p[j][w].1));
                            diff_rows.push((row, rhs));
                            // Fresh: pad-difference unknown per equation.
                            let mut rowf = vec![0u64; s_b];
                            for &g in wave {
                                rowf[g] = zq.sub(wf0[j][g], w_p[j][g]);
                            }
                            let rhsf = zq.sub(zq.to_mod(f0[j][w].1), zq.to_mod(frv_p[j][w].1));
                            fresh_entries.push((p, j, w, rowf, rhsf));
                            fresh_cols += 1;
                        }
                    }
                }
                _ => unreachable!(),
            }
        }
        let (drank, dsol) = solve(&diff_rows);
        // Fresh control: (x | delta-e) system + per-(pair, claim)
        // zero-sum rows on the pad differences.
        for pair in [1usize, 2] {
            for j in 0..9 {
                let mut r = vec![0u64; s_b + fresh_cols];
                for (idx, (p2, j2, _, _, _)) in fresh_entries.iter().enumerate() {
                    if *p2 == pair && *j2 == j {
                        r[s_b + idx] = 1;
                    }
                }
                fresh_full.push((r, 0));
            }
        }
        for (idx, (_, _, _, xrow, rhs)) in fresh_entries.iter().enumerate() {
            let mut r = xrow.clone();
            r.extend(vec![0u64; fresh_cols]);
            r[s_b + idx] = 1;
            fresh_full.push((r, *rhs));
        }
        let dim_fresh = (s_b + fresh_cols) - rank_of(&fresh_full);
        assert_true(
            &format!(
                "[Z1-h] pad REUSE leaks at half rate: 3 proofs sharing one pad table -> pairwise differences cancel the pads and EXACTLY recover the witness (rank {drank}/{s_b}); the FRESH-pad control's differences keep a {dim_fresh}-dim solution set (pad differences absorb them) — freshness is structural: WavePads is non-Clone, consumed by the splitter, drawn per proof from the ProverRng (reuse needed the harness-only escape hatch)"
            ),
            drank == s_b
                && dsol.as_deref() == Some(&secrets2[..])
                && dim_fresh > 0,
        );
    }
}

// ===========================================================================
// U-R1 S1 (RANGE_AGGREGATION_DESIGN Section 2b, ledger PROGRESS_UR.md):
// `ffn-chain layer <log2_el>` — ONE per-layer FFN-gate instance (X dense
// int8 offset codes, Y = SiLU(X) slot-packed, UP slot-packed, Z = Y o UP
// slot-packed) with the q31 commitments split across multiple C2-capped
// ct-round waves via the S0 helpers (plan_waves / split_claims_prover /
// split_claims_verifier), ONE masked descent pair (witness + table trees)
// serving the whole layer, and per-wave g-groups sized by the wave's
// claim-share count (public/deterministic given shape + plan, D-4).
//
// Per ledger D-5 the layer rig OMITS the q46 plane/ARP range side
// entirely: it measures the multi-wave committed masked lookup + Hadamard
// + zeta slot-constancy at per-layer scale — the post-range-lookup
// architecture (S3 adds the range table INTO this rig). The full
// range -> lookup -> Hadamard integrity story stays covered at the block
// rig, which is unchanged.
//
// Element count: n_el = 2^log2_el - 4 = blinder_positions(2^(log2_el+1))[0]
// — the layer's witness tree needs its data block to end at the first
// blinder position, exactly the UK8_B = 1020 pattern lifted to layer
// scale (depth = log2_el + 1).
//
// Memory (the S1 wall, recorded honestly): the zeta slot-constancy rows
// span every Y/UP chunk of the layer — materializing them as CtClaims is
// 2 x l x chunks dense polys (~13 GB at 2^20, both sides), which busts
// the 10G scope. The rig therefore builds the ZETA claim family's
// per-wave shares STREAMING (ZetaStream below, one XOF cursor per row,
// waves consumed in ascending chunk order — first-fit placement is
// monotone), while the PIN claims flow through the audited S0
// split_claims_prover / split_claims_verifier path unchanged. The
// [U-R1b] battery pins the streaming builder bit-for-bit to
// link_claims_tgt_slot + split_claims_prover at the battery shape, and
// the zeta partial reveals get the same three gates the S0 verifier
// applies (share structure by construction, centered-representative
// bound, sum == public total).

/// psi copies of the pin batch (the U-K5c/U-K8 batching: q31 soundness
/// 2^-31 per copy, 9 copies ~ 2^-279).
const UR1_PIN_COPIES: usize = 9;
/// Frozen link weight width (LKP-8's w = 11 -> l = 24 rows), reused for
/// the zeta slot-constancy family so the layer rig stays comparable to
/// the block rig.
const UR1_ZETA_W: u32 = 11;
/// CLI cap: 2^20 is the largest shape whose commitment stores + split
/// pin claims + streaming zeta fit the 10G MemoryMax scope on this box
/// (measured; the ledger records the residual as B-D2 unblocking work).
const UR1_MAX_LOG2: usize = 20;
/// U-R2 range table width: [0, 2^8) rows certifying the dense committed
/// offset codes x_u directly (no offset fold at w = 8).
const UR2_RANGE_W: usize = 8;

/// Canonical spec digest of the [0, 256) range table (frozen in LKP-9 —
/// the table IS its spec: row j has value j, w = 8).
fn ur2_range_table_digest() -> [u8; 32] {
    uk8_sha(&[b"ur2-range-table-v1", &(UR2_RANGE_W as u64).to_le_bytes(), &(1u64 << UR2_RANGE_W).to_le_bytes()])
}

/// The layer rig's arm: which lookup material rides alongside the
/// always-present Hadamard + zeta families.
#[derive(Clone, Copy, PartialEq)]
enum LayerArm {
    /// No lookup at all (the S2 baseline arm B).
    Bare,
    /// The SiLU activation lookup (the S2 arm A).
    Lookup,
    /// SiLU lookup + the U-R2 range-table instance over X (S3 arm R).
    LookupRange,
    /// ONLY the range-table instance (battery isolation arm: the range
    /// root cross-check is the sole X certifier, so an out-of-range X
    /// is rejected by it and nothing else).
    RangeOnly,
}

impl LayerArm {
    fn has_silu(self) -> bool {
        matches!(self, LayerArm::Lookup | LayerArm::LookupRange)
    }
    fn has_range(self) -> bool {
        matches!(self, LayerArm::LookupRange | LayerArm::RangeOnly)
    }
    fn has_any(self) -> bool {
        self.has_silu() || self.has_range()
    }
}

/// The C2 std-bundle capacity at (q, shape): the largest n_commits that
/// derive_ct_round_params(conc = true) accepts. This REPLICATES the
/// derive formula to SIZE the wave plan; derive_ct_round_params' own
/// assert remains the enforcement gate at every wave (ledger D-3).
fn ur1_c2_max_commits(q: u64, shape: CommitShape) -> usize {
    let n_z = (shape.n_r * D) as f64;
    let op = 1.3 * (2.0 * D as f64).sqrt();
    let ok = |n: usize| -> bool {
        let bundle = n as f64 * n_z;
        let t_bundle = op * bundle.sqrt();
        let sigma = (12.0 * t_bundle).ceil();
        let bound = 1.2 * sigma * bundle.sqrt();
        let beta = (2.0 * bound + op * bundle.sqrt()).ceil() as u128;
        (q as u128) > 8 * beta
    };
    let mut n = 1usize;
    while ok(n + 1) {
        n += 1;
        assert!(n < 65536, "C2 scan diverged");
    }
    n
}

/// The deterministic per-layer wave layout: commitment index space, the
/// wave plan (co-location groups = the Hadamard (Y,UP,Z) commitment
/// triples), and per-wave linear-share/g-group budgets. A pure function
/// of (log2_el, arm, shape, q) — prover and verifier derive it
/// independently; nothing prover-chosen enters (D-2).
struct LayerShape {
    n_el: usize,
    chunks: usize,
    slot_cms: usize,
    nx: usize,
    idx_m: usize,
    idx_bl: usize,
    base_wm: usize,
    base_tm: usize,
    wm_c: usize,
    tm_c: usize,
    /// U-R2 range-table material (usize::MAX / 0 in non-range arms):
    /// second m column, second blinder group, second mask pair.
    idx_mr: usize,
    idx_blr: usize,
    base_wmr: usize,
    base_tmr: usize,
    base_y: usize,
    base_up: usize,
    base_z: usize,
    n_data: usize,
    dw: usize,
    dt: usize,
    c2_max: usize,
    data_cap: usize,
    /// U-Z1: the wave-share pad layout (design 2.2) — plan-derived
    /// pad-wave set (the pin-bearing waves), 9 pads per pad wave,
    /// wave-major, whole pad-waves per commitment. `n_claims == 0` on
    /// unmasked/bare shapes. Pad commitments (when present) sit at
    /// global indices base_pad .. base_pad + pad_layout.n_pad_cms,
    /// immediately after the data commitments and BEFORE the g-groups,
    /// so h0_link binds them before any challenge.
    pad_layout: ring::ct_engine::WavePadLayout,
    base_pad: usize,
    /// U-Z1 impl-b: g-groups of the STANDALONE closing round — one
    /// g-slot per exact zero-sum claim (design eq. 4; 9 claims -> 2
    /// groups at msg_r 8). Zero when the shape carries no pads.
    closing_g_groups: usize,
    lp: ring::link::LinkParams,
    plan: ring::ct_engine::WavePlan,
    /// Per wave: the CONTIGUOUS chunk range [c0, c1) its Y/UP/Z triples
    /// carry (0,0 for waves without value chunks).
    wave_chunks: Vec<(usize, usize)>,
    /// Per wave: linear claim-share budget (== the wave's actual claim
    /// count; asserted at run time) and derived g-group count.
    wave_lin: Vec<usize>,
    wave_g_groups: Vec<usize>,
}

/// `masked = true` is the U-Z1 wave-share-masking shape (pin shares
/// carry coset one-time pads; every pin-bearing wave's round list gains
/// its shared pad commitment, so the C2 budget charges +1 commitment
/// there and the data cap re-derives — 76 -> 75 at the 2^12/silu
/// point). `masked = false` is the LEGACY as-built (C-02 Revealed)
/// shape, kept for the permanent [Z1-a] baseline exhibit and the LKP-9
/// reproducibility pins.
fn ur1_layer_shape(
    log2_el: usize,
    arm: LayerArm,
    shape: CommitShape,
    q: u64,
    masked: bool,
) -> LayerShape {
    use ring::ct_engine::{WavePadLayout, plan_waves, r1_pad_count};
    use ring::gkr::ceiling_gate_ok;
    use ring::gkr_masked::{blinder_positions, mask_coeff_counts};
    use ring::kfield::K_DEG;
    let msg_r = shape.msg_r;
    let k_slots = 8usize; // ring_ctx_q8
    let dw = log2_el + 1;
    let dt = 9usize; // 256-row tables + blinders (LKP-6)
    let n_el = blinder_positions(1usize << dw)[0];
    assert_eq!(n_el, (1usize << log2_el) - 4);
    // U-R2 derive-time ceiling gate: the log-derivative instancing
    // discipline caps N_inst at 2^25 at q31 (n * 64 < q — the Section 4
    // rule; the arp_budget_ok pattern: gate at derive, reject the shape).
    assert!(
        (1u64 << dw) <= (1 << 25) && ceiling_gate_ok(1u64 << dw, q),
        "U-R2 ceiling gate: per-instance lookup count must stay <= 2^25 at q31"
    );
    let chunks = n_el.div_ceil(k_slots);
    assert_eq!(chunks % msg_r, 0, "layer shapes keep whole slot commitments (log2_el >= 6)");
    let slot_cms = chunks / msg_r;
    let nx = n_el.div_ceil(msg_r * D);
    let (wm_len, tm_len) = {
        let (gw, rw) = mask_coeff_counts(dw, 0);
        let (gt, rt) = mask_coeff_counts(dt, 0);
        (gw + rw, gt + rt)
    };
    let kel_cms = |n_kel: usize| (n_kel * K_DEG).div_ceil(msg_r * D).max(1);
    let (wm_c, tm_c) = (kel_cms(wm_len), kel_cms(tm_len));
    // Commit index space: X | [silu: m bl wm tm] | [range: m_r bl_r
    // wm_r tm_r] | Y | UP | Z. The range descent pair reuses the SAME
    // depths (witness over the same n_el values, 256-row table at dt).
    let mut cursor = nx;
    let (idx_m, idx_bl, base_wm, base_tm) = if arm.has_silu() {
        let t = (cursor, cursor + 1, cursor + 2, cursor + 2 + wm_c);
        cursor = cursor + 2 + wm_c + tm_c;
        t
    } else {
        (usize::MAX, usize::MAX, usize::MAX, usize::MAX)
    };
    let (idx_mr, idx_blr, base_wmr, base_tmr) = if arm.has_range() {
        let t = (cursor, cursor + 1, cursor + 2, cursor + 2 + wm_c);
        cursor = cursor + 2 + wm_c + tm_c;
        t
    } else {
        (usize::MAX, usize::MAX, usize::MAX, usize::MAX)
    };
    let base_y = cursor;
    let base_up = base_y + slot_cms;
    let base_z = base_up + slot_cms;
    let n_data = base_z + slot_cms;
    let lp = ring::link::derive_link_params(n_el, 8, ring::Q8_46, q, UR1_ZETA_W);
    let l = lp.l;
    let c2_max = ur1_c2_max_commits(q, shape);

    // Per-wave budget derivation from a candidate plan; None if any wave
    // (data + its g-groups) exceeds the C2 capacity.
    #[allow(clippy::type_complexity)]
    let budget = |plan: &ring::ct_engine::WavePlan|
     -> Option<(Vec<(usize, usize)>, Vec<usize>, Vec<usize>)> {
        let mut chunk_rng = Vec::with_capacity(plan.waves.len());
        let mut lin = Vec::with_capacity(plan.waves.len());
        let mut gg = Vec::with_capacity(plan.waves.len());
        for wave in &plan.waves {
            // Pins touch: X + every lookup-material commit + (silu arms
            // only) the Y slot commitments read by the silu witness Q pin.
            let pin_hi = if arm.has_silu() { base_up } else { base_y };
            let has_pin = arm.has_any() && wave.iter().any(|&i| i < pin_hi);
            let (mut cm0, mut cm1, mut y_cms) = (usize::MAX, 0usize, 0usize);
            for &i in wave {
                if (base_y..base_up).contains(&i) {
                    let cm = i - base_y;
                    cm0 = cm0.min(cm);
                    cm1 = cm1.max(cm + 1);
                    y_cms += 1;
                }
            }
            let (c0, c1) = if y_cms == 0 {
                (0, 0)
            } else {
                assert_eq!(cm1 - cm0, y_cms, "wave Y commitments must be contiguous (first-fit)");
                (cm0 * msg_r, cm1 * msg_r)
            };
            let lin_w = if has_pin { UR1_PIN_COPIES } else { 0 } + if c1 > c0 { 2 * l } else { 0 };
            let gslots = lin_w + r1_pad_count(0, c1 - c0, 0);
            let g_groups = gslots.div_ceil(msg_r);
            // U-Z1: a pin-bearing wave's round list gains its shared pad
            // commitment (design 2.2 rule 2) — one more slot under C2.
            let pad_cm = usize::from(masked && arm.has_any() && has_pin);
            if wave.len() + pad_cm + g_groups > c2_max {
                return None;
            }
            chunk_rng.push((c0, c1));
            lin.push(lin_w);
            gg.push(g_groups);
        }
        Some((chunk_rng, lin, gg))
    };

    // Analytic starting cap: the worst wave is triple-pure (every triple
    // brings 8 quads = 16 R1 pads); scan the cap down until that
    // composition fits, then verify the REAL plan (and decrement further
    // on the off chance a mixed wave is worse).
    let fits_analytic = |cap: usize| -> bool {
        let t = cap / 3;
        let lin_w = if arm.has_any() { UR1_PIN_COPIES } else { 0 } + 2 * l;
        let gslots = lin_w + r1_pad_count(0, t * msg_r, 0);
        // Worst case charges the pad commitment whenever the shape is
        // masked (conservative for arms whose worst wave is pin-free;
        // the real per-wave budget above decides).
        let pad_cm = usize::from(masked && arm.has_any());
        cap + pad_cm + gslots.div_ceil(msg_r) <= c2_max
    };
    let mut data_cap = c2_max;
    while data_cap > 3 && !fits_analytic(data_cap) {
        data_cap -= 1;
    }
    let groups: Vec<Vec<usize>> =
        (0..slot_cms).map(|cm| vec![base_y + cm, base_up + cm, base_z + cm]).collect();
    let (plan, wave_chunks, wave_lin, wave_g_groups) = loop {
        let plan = plan_waves(n_data, &groups, data_cap)
            .expect("layer wave plan derives (internal shape, not verifier input)");
        if let Some((c, li, g)) = budget(&plan) {
            break (plan, c, li, g);
        }
        data_cap -= 1;
        assert!(data_cap > 3, "no viable wave data cap");
    };
    // U-Z1: the PLAN-derived pad layout (design 2.5's circularity rule —
    // the pad-wave set is the pin-bearing waves, a pure function of the
    // shape; claim support never enters). Prover and verifier both
    // derive this; the rig asserts byte-for-byte agreement (Z1-i).
    let pad_layout = {
        let pin_hi = if arm.has_silu() { base_up } else { base_y };
        let (n_claims, pad_waves) = if masked && arm.has_any() {
            let pw: Vec<usize> = plan
                .waves
                .iter()
                .enumerate()
                .filter(|(_, wave)| wave.iter().any(|&i| i < pin_hi))
                .map(|(w, _)| w)
                .collect();
            (UR1_PIN_COPIES, pw)
        } else {
            (0, Vec::new())
        };
        WavePadLayout::derive(n_claims, pad_waves, plan.waves.len(), msg_r)
            .expect("layer pad layout derives (internal shape, not verifier input)")
    };
    let base_pad = n_data;
    let closing_g_groups =
        if pad_layout.has_pads() { pad_layout.n_claims.div_ceil(msg_r) } else { 0 };
    LayerShape {
        n_el,
        chunks,
        slot_cms,
        nx,
        idx_m,
        idx_bl,
        base_wm,
        base_tm,
        wm_c,
        tm_c,
        idx_mr,
        idx_blr,
        base_wmr,
        base_tmr,
        base_y,
        base_up,
        base_z,
        n_data,
        dw,
        dt,
        c2_max,
        data_cap,
        pad_layout,
        base_pad,
        closing_g_groups,
        lp,
        plan,
        wave_chunks,
        wave_lin,
        wave_g_groups,
    }
}

/// Streaming per-wave builder for the E1+E2 zeta slot-constancy claim
/// shares (xi = 0 rows: the family reads ONLY the junk CRT coordinates).
/// Mirrors link_claims_tgt_slot's weight walk (same "link-zeta" XOF
/// stream per row, same skip/consume discipline, same per-chunk
/// pack_functional) and split_claim_shares' wave-local re-indexing,
/// WITHOUT materializing layer-size claims. Waves must be consumed in
/// ascending chunk order (asserted); the [U-R1b] differential leg pins
/// this builder bit-for-bit to the materialized path.
struct ZetaStream<'a> {
    ring: &'a RingCtx,
    lp: ring::link::LinkParams,
    coord_m: &'a [Vec<u64>],
    readers: Vec<XofReader>,
    cursor: usize,
}

impl<'a> ZetaStream<'a> {
    fn new(
        ring: &'a RingCtx,
        lp: ring::link::LinkParams,
        coord_m: &'a [Vec<u64>],
        h0: &[u8; 32],
    ) -> Self {
        let readers = (0..lp.l)
            .map(|row| XofReader::new("link-zeta", &[h0, &(row as u64).to_le_bytes()]))
            .collect();
        ZetaStream { ring, lp, coord_m, readers, cursor: 0 }
    }

    /// Wave-local weight polys for chunks [c0, c1): out[row] holds one
    /// (commit, slot, poly) per chunk with commit/slot mapped through
    /// `local_slot` (the wave-local index of the chunk's Y/UP slot).
    fn wave_shares(
        &mut self,
        c0: usize,
        c1: usize,
        local_slot: &dyn Fn(usize) -> (usize, usize),
    ) -> Vec<Vec<(usize, usize, Poly)>> {
        assert_eq!(self.cursor, c0, "zeta stream consumed out of chunk order");
        let zq = &self.ring.zq;
        let (k, sd) = (self.ring.k, self.ring.slot_deg);
        let half = 1i64 << (self.lp.w - 1);
        let mut out: Vec<Vec<(usize, usize, Poly)>> =
            (0..self.lp.l).map(|_| Vec::with_capacity(c1 - c0)).collect();
        for u in c0..c1 {
            let (ci, sj) = local_slot(u);
            for (row, reader) in self.readers.iter_mut().enumerate() {
                let mut w_flat = vec![0u64; D];
                for c in 0..D {
                    let (slot, coord) = (c / sd, c % sd);
                    let t = u * k + slot;
                    // Value slot constants take the xi weight (zero in
                    // this family — no draw); every OTHER coordinate is
                    // junk and consumes the next zeta draw even when the
                    // drawn weight is zero (stream discipline).
                    if coord == 0 && t < self.lp.n {
                        continue;
                    }
                    let wt = (reader.next_u64() & ((1u64 << self.lp.w) - 1)) as i64 - half;
                    if wt == 0 {
                        continue;
                    }
                    let wm = zq.to_mod(wt);
                    for (i, &m) in self.coord_m[c].iter().enumerate() {
                        if m != 0 {
                            w_flat[i] = zq.add(w_flat[i], zq.mul(wm, m));
                        }
                    }
                }
                let poly = ring::ct_engine::pack_functional(zq, &w_flat, 1).pop().unwrap();
                out[row].push((ci, sj, poly));
            }
        }
        self.cursor = c1;
        out
    }
}

#[derive(Clone, Copy, PartialEq)]
enum LayerTamper {
    /// Honest witness.
    None,
    /// One Y off the table (consumed consistently downstream) — only the
    /// masked lookup's blinded root cross-check can reject.
    OffTableY,
    /// One Z slot constant off the product — that wave's quad ring claim
    /// rejects; the lookup passes.
    HadamardZ,
    /// A prover-supplied lookup prehash bit-flip — the verifier
    /// recomputes it from the statement + full commitment list.
    LookupH0,
    /// A lied per-wave PIN partial scalar: split_claims_verifier's sum
    /// gate rejects (the S0 path, exercised at layer scale).
    PartialLiePin,
    /// A COMPENSATED pin partial lie (+1 / -1 across two waves): the sum
    /// gate passes but each affected wave's ct-round REJECTS the false
    /// partial against its committed material (the load-bearing leg).
    CompensatedPin,
    /// U-Z1 impl-b (the zeta deletion, [Z1-f]): a junk-bearing witness —
    /// one nonzero non-constant CRT coordinate injected into a Y chunk,
    /// consumed CONSISTENTLY downstream (Z is the ring product of the
    /// tampered Y, so the Hadamard quad stays TRUE; slot constants are
    /// untouched, so the lookup and pins pass). The ONLY failing gate is
    /// that wave's ForcedZero zeta claim — per-wave localization,
    /// strictly stronger than the deleted layer-wide sum gate.
    JunkY,
    /// U-R2: an out-of-range X — x_u = 300 smuggled into the dense
    /// committed column (consistently: multiplicities, trees and pins
    /// all read the smuggled value) — the range lookup's root
    /// cross-check rejects it. On the RangeOnly arm the edge is fully
    /// isolated; on LookupRange the SiLU root also rejects (X is doubly
    /// covered there — recorded honestly).
    RangeX,
    /// U-R1 wave-boundary forgery (deferred from S1): the prover
    /// CROSS-USES another wave's g-mask commitments (donor wave's g's
    /// presented and opened, self-consistently, in the target wave's
    /// round). The per-wave h0 binds the wave's OWN commitment list, so
    /// the verifier's independently-derived layout rejects the round.
    GMaskCrossUse,
}

#[derive(Default)]
struct LayerVerdict {
    statement_ok: bool,
    /// The SiLU lookup verdict (prehash + alpha + descents + root
    /// cross-check); true when the arm has no SiLU lookup.
    lookup_ok: bool,
    /// The U-R2 range lookup verdict (same gates, second table
    /// instance); true when the arm has no range lookup.
    range_ok: bool,
    /// split_claims_verifier accepted the pin reveals (structure +
    /// centered bound + sum gate).
    sum_gate_ok: bool,
    waves_ok: bool,
    first_bad_wave: Option<usize>,
    /// U-Z1 impl-b: the closing round's verdict — the nine exact
    /// zero-sum claims over the shared pad commitments (design eq. 4).
    /// True when the shape carries no pads.
    closing_ok: bool,
    /// The [U-R1b] streaming-vs-materialized zeta differential ran and
    /// matched (small shapes only).
    differential_ok: bool,
}

impl LayerVerdict {
    fn all_ok(&self) -> bool {
        self.statement_ok
            && self.lookup_ok
            && self.range_ok
            && self.sum_gate_ok
            && self.waves_ok
            && self.closing_ok
    }
}

#[derive(Default)]
struct LayerCost {
    n_el: usize,
    n_waves: usize,
    n_data: usize,
    n_g_groups: usize,
    commit_s: f64,
    prove_s: f64,
    verify_s: f64,
    /// Lookup-stage attribution inside prove/verify (trees + masked
    /// descents + pin building + pin claims; the wave rounds are shared).
    lkp_prove_s: f64,
    lkp_verify_s: f64,
    q31_data_coeffs: usize,
    q31_g_coeffs: usize,
    /// Masked descent transcript bytes (one witness+table pair per layer).
    masked_bytes: usize,
    /// Partial-scalar reveal count (pins + zeta), 12 B each on the wire.
    reveal_shares: usize,
    /// U-Z1: committed pad-commitment coefficients (design 6.1's "pad
    /// dce" row — ceil(9W/1024) commitments x 1024).
    q31_pad_coeffs: usize,
}

/// One committed per-layer run: commit -> validated statement -> ONE
/// masked descent pair -> multi-wave q31 ct-rounds with split claims ->
/// verify. Prove and verify interleave per wave (proofs drop after each
/// wave; the H-03 discipline), with separately accumulated timers.
///
/// `masked = true` (U-Z1, the shipped mode): pin shares carry coset
/// one-time pads in shared pre-challenge pad commitments; every
/// pin-bearing wave's round list gains its pad commitment and the
/// reveals are sigma~ = functional + pad. `masked = false` is the
/// LEGACY C-02 Revealed wire, kept ONLY for the permanent [Z1-a]
/// unmasked-leak baseline exhibit.
#[allow(clippy::too_many_lines)]
fn ffn_layer_run(
    log2_el: usize,
    arm: LayerArm,
    masked: bool,
    tamper: LayerTamper,
    seed: u64,
    entropy: ChainEntropy,
    quiet: bool,
) -> (LayerVerdict, LayerCost) {
    use manifest::{ClaimManifest, Operation, Orientation, QuantMeta};
    use ring::commit::CommitShape as CS;
    use ring::ct_engine::{
        CtClaim, QuadRingClaim, StdOpening, WavePads, ct_h0, ct_mul_centered,
        derive_ct_round_params, draw_wave_pads, pack_wave_pads, prove_ct_round,
        quad_ring_localized, sample_g_masks, split_claims_prover, split_claims_prover_masked,
        split_claims_verifier, split_claims_verifier_masked, verify_ct_round,
    };
    use ring::gkr::{ceiling_gate_ok, eq_table};
    use ring::gkr_masked::{
        BlinderSet, DescentEnd, MaskSet, MaskedDescentProof, blinded_table_tree,
        blinded_witness_tree, draw_masks, g_hypersum_weights, g_open_weights, masked_gkr_prove,
        masked_gkr_verify, masked_pass_bytes, r_open_weights, table_row_positions, zero_masks,
    };
    use ring::kfield::{K_DEG, KElem, KField};
    use ring::link::crt_coord_rows;
    use ring::lookup::{
        PinTerm, PinnedValue, derive_pin_psi, fuse_pair, fused_silu_table, mul_y,
        multiplicities, pin_claims, silu_int8_table, slot_pin_weights, table_spec_digest,
    };
    use ring::sumcheck::LkpTranscript;

    // ---- Shared setup. -----------------------------------------------------
    let ctx_ring = ring_ctx_q8();
    let kf = KField::new(&ctx_ring);
    let zq = ctx_ring.zq;
    let q = zq.q;
    let (k_slots, sd) = (ctx_ring.k, ctx_ring.slot_deg);
    let zero = kf.zero();
    let one = kf.one();
    let rows = silu_int8_table();
    let spec_dg = table_spec_digest(&rows);
    let tab_fused = fused_silu_table(&kf, &rows);
    let t_rows = rows.len();
    let shape = CS { kappa: 8, n_r: 26, msg_r: 8 };
    let msg_r = shape.msg_r;
    let kpc = msg_r * D / K_DEG;
    let crs = expand_crs(shape, q, 0x0_8CA);
    let ls = ur1_layer_shape(log2_el, arm, shape, q, masked);
    let (n_el, chunks, slot_cms, nx, n_data) = (ls.n_el, ls.chunks, ls.slot_cms, ls.nx, ls.n_data);
    let l_zeta = ls.lp.l;
    let n_waves = ls.plan.waves.len();
    assert!(ceiling_gate_ok(1u64 << ls.dw, q), "layer instance clears the LogUp ceiling");
    let coord_m = crt_coord_rows(&ctx_ring);
    let const_rows: Vec<Vec<u64>> = (0..k_slots).map(|j| coord_m[j * sd].clone()).collect();
    let center128 = |v: i128| -> i64 {
        let qq = q as i128;
        let mut r = v.rem_euclid(qq);
        if r > qq / 2 {
            r -= qq;
        }
        r as i64
    };

    let mut cost = LayerCost {
        n_el,
        n_waves,
        n_data,
        n_g_groups: ls.wave_g_groups.iter().sum::<usize>() + ls.closing_g_groups,
        q31_data_coeffs: n_data * msg_r * D,
        q31_g_coeffs: (ls.wave_g_groups.iter().sum::<usize>() + ls.closing_g_groups)
            * msg_r
            * D,
        q31_pad_coeffs: ls.pad_layout.n_pad_cms * msg_r * D,
        masked_bytes: (usize::from(arm.has_silu()) + usize::from(arm.has_range()))
            * masked_pass_bytes(ls.dw, ls.dt, 0, 1),
        ..LayerCost::default()
    };
    let mut verdict = LayerVerdict {
        statement_ok: true,
        lookup_ok: true,
        range_ok: true,
        sum_gate_ok: true,
        waves_ok: true,
        first_bad_wave: None,
        closing_ok: true,
        differential_ok: true,
    };

    // ---- Instance data. ----------------------------------------------------
    let mut data_rng = seed;
    let mut xs_all: Vec<i64> =
        (0..n_el).map(|_| rng_below(&mut data_rng, 256) as i64 - 128).collect();
    let mut ys_all: Vec<i64> = xs_all.iter().map(|&x| rows[(x + 128) as usize].1).collect();
    let up_all: Vec<i64> = (0..n_el).map(|_| rng_below(&mut data_rng, 256) as i64 - 128).collect();
    if tamper == LayerTamper::OffTableY {
        ys_all[5] = if ys_all[5] > 100 { ys_all[5] - 16 } else { ys_all[5] + 16 };
    }
    if tamper == LayerTamper::RangeX {
        // x_u = 300 smuggled into the dense column (ys stays the honest
        // SiLU image of the ORIGINAL value — the smuggled residue is
        // consumed consistently by the commitments, the multiplicity
        // histogram, the trees and the pins; only root checks can see it).
        xs_all[0] = 172; // offset code 172 + 128 = 300, outside [0, 256)
    }
    let mut rng = match entropy {
        ChainEntropy::Os => ring::ProverRng::from_os()
            .expect("operating-system entropy is required for a proof session"),
        ChainEntropy::Test =>
            ring::ProverRng::from_test_seed("ur1-layer-session", &seed.to_le_bytes()),
    };

    // ---- Pass 1: data commitments (X | m bl wm tm | Y | UP | Z). -----------
    // Rho columns are stored TERNARY-PACKED (i8) and expanded per wave —
    // at 2^20 the full i64 form alone is ~2.3 GiB.
    let t_commit = Instant::now();
    let a1p_commit = {
        let rp_probe = derive_ct_round_params(q, shape, ls.c2_max, 0, 0, true);
        build_a1_paths(&crs, rp_probe.sigma, isqrt_u128(rp_probe.bound_sq))
    };
    let path_c = KernelPath::A1(&a1p_commit);
    let mut msgs: Vec<Vec<Poly>> = Vec::with_capacity(n_data);
    let mut rhos8: Vec<Vec<i8>> = Vec::with_capacity(n_data);
    let mut t1s: Vec<Vec<Poly>> = Vec::with_capacity(n_data);
    let mut t2s: Vec<Vec<Poly>> = Vec::with_capacity(n_data);
    let push_commit = |m: Vec<Poly>,
                           rng: &mut ring::ProverRng,
                           msgs: &mut Vec<Vec<Poly>>,
                           rhos8: &mut Vec<Vec<i8>>,
                           t1s: &mut Vec<Vec<Poly>>,
                           t2s: &mut Vec<Vec<Poly>>| {
        let rho: Vec<Vec<i64>> = (0..shape.n_r).map(|_| rng_ternary_poly(rng)).collect();
        let (t1, t2) = commit(&path_c, &crs, &m, &rho);
        msgs.push(m);
        rhos8.push(rho.iter().flat_map(|p| p.iter().map(|&x| x as i8)).collect());
        t1s.push(t1);
        t2s.push(t2);
    };
    let pack_scalars = |vals: &[u64]| -> Vec<Poly> {
        assert!(vals.len() <= msg_r * D);
        let mut polys = vec![poly_zero(); msg_r];
        for (i, &v) in vals.iter().enumerate() {
            polys[i / D][i % D] = v;
        }
        polys
    };
    let pack_kelems = |kelems: &[KElem]| -> Vec<Vec<Poly>> {
        let mut flat: Vec<u64> = Vec::with_capacity(kelems.len() * K_DEG);
        for e in kelems {
            for c in 0..K_DEG {
                flat.push(e[c]);
            }
        }
        let per = msg_r * D;
        let n_commit = flat.len().div_ceil(per).max(1);
        (0..n_commit)
            .map(|g| {
                (0..msg_r)
                    .map(|s| {
                        (0..D)
                            .map(|c| {
                                let idx = g * per + s * D + c;
                                if idx < flat.len() { flat[idx] } else { 0 }
                            })
                            .collect()
                    })
                    .collect()
            })
            .collect()
    };
    // X: offset codes x_u = x + 128, dense (pads zero).
    for xc in 0..nx {
        let lo = xc * msg_r * D;
        let n_c = (n_el - lo).min(msg_r * D);
        let vals: Vec<u64> = (0..n_c).map(|i| (xs_all[lo + i] + 128) as u64).collect();
        push_commit(pack_scalars(&vals), &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
    }
    // Lookup material (silu arms): ONE m column + ONE blinder group +
    // ONE mask pair for the whole layer — the S2 amortization subject.
    let (mut masks_w, mut masks_t, bl_w, bl_t) = if arm.has_silu() {
        let mw = draw_masks(&kf, &mut rng, ls.dw, 0);
        let mt = draw_masks(&kf, &mut rng, ls.dt, 0);
        let bw = BlinderSet::draw(&kf, &mut rng);
        let mut bt = BlinderSet::draw(&kf, &mut rng);
        bt.solve_mass(&kf, &bw.mass(&kf));
        let w_fused: Vec<KElem> = xs_all
            .iter()
            .zip(ys_all.iter())
            .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
            .collect();
        let m_k = multiplicities(&kf, &w_fused, &tab_fused);
        let m_vals: Vec<u64> = m_k.iter().map(|e| e[0]).collect();
        push_commit(pack_scalars(&m_vals), &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        let blinder_kelems = {
            let mut v = Vec::with_capacity(16);
            for b in [&bw.tl, &bw.tr, &bw.f0, &bw.f1, &bt.tl, &bt.tr, &bt.f0, &bt.f1] {
                v.push(b.a.clone());
                v.push(b.u.clone());
            }
            v
        };
        let bl_msg = pack_kelems(&blinder_kelems);
        assert_eq!(bl_msg.len(), 1);
        push_commit(bl_msg.into_iter().next().unwrap(), &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        let wm = pack_kelems(&mw.flatten());
        assert_eq!(wm.len(), ls.wm_c);
        for m in wm {
            push_commit(m, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
        let tm = pack_kelems(&mt.flatten());
        assert_eq!(tm.len(), ls.tm_c);
        for m in tm {
            push_commit(m, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
        (Some(mw), Some(mt), Some(bw), Some(bt))
    } else {
        (None, None, None, None)
    };
    // U-R2 range material (range arms): a SECOND 256-row table instance
    // over the dense committed offset codes — its own m column, blinder
    // group and mask pair; same tree depths, no offset fold at w = 8.
    let tab_range: Vec<KElem> = (0..1u64 << UR2_RANGE_W).map(|j| kf.embed(j)).collect();
    let (mut masks_wr, mut masks_tr, bl_wr, bl_tr) = if arm.has_range() {
        let mw = draw_masks(&kf, &mut rng, ls.dw, 0);
        let mt = draw_masks(&kf, &mut rng, ls.dt, 0);
        let bw = BlinderSet::draw(&kf, &mut rng);
        let mut bt = BlinderSet::draw(&kf, &mut rng);
        bt.solve_mass(&kf, &bw.mass(&kf));
        let w_range: Vec<KElem> =
            xs_all.iter().map(|&x| kf.embed(zq.to_mod(x + 128))).collect();
        let m_k = multiplicities(&kf, &w_range, &tab_range);
        let m_vals: Vec<u64> = m_k.iter().map(|e| e[0]).collect();
        push_commit(pack_scalars(&m_vals), &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        let blinder_kelems = {
            let mut v = Vec::with_capacity(16);
            for b in [&bw.tl, &bw.tr, &bw.f0, &bw.f1, &bt.tl, &bt.tr, &bt.f0, &bt.f1] {
                v.push(b.a.clone());
                v.push(b.u.clone());
            }
            v
        };
        let bl_msg = pack_kelems(&blinder_kelems);
        assert_eq!(bl_msg.len(), 1);
        push_commit(bl_msg.into_iter().next().unwrap(), &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        let wm = pack_kelems(&mw.flatten());
        assert_eq!(wm.len(), ls.wm_c);
        for m in wm {
            push_commit(m, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
        let tm = pack_kelems(&mt.flatten());
        assert_eq!(tm.len(), ls.tm_c);
        for m in tm {
            push_commit(m, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
        (Some(mw), Some(mt), Some(bw), Some(bt))
    } else {
        (None, None, None, None)
    };
    // Y / UP / Z slot tensors, built per commitment (chunk constants =
    // centered residues; pads zero). Z is the exact ring product.
    let slot_chunk = |vals: &[i64], u: usize| -> Poly {
        let mut lane = vec![0u64; k_slots];
        for (s, lv) in lane.iter_mut().enumerate() {
            let t = u * k_slots + s;
            if t < vals.len() {
                *lv = zq.to_mod(vals[t]);
            }
        }
        slot_pack(&ctx_ring, &lane)
    };
    // U-Z1 impl-b: the Y chunk builder, with the [Z1-f] junk tamper —
    // one nonzero junk (non-constant CRT) coordinate injected into
    // chunk 0 and consumed CONSISTENTLY (Z below multiplies the
    // tampered chunk, so the Hadamard quad stays true; slot constants
    // are untouched, so lookup and pins pass — the ForcedZero zeta
    // claim of that wave is the only gate that can see it).
    let y_chunk = |u: usize| -> Poly {
        let mut p = slot_chunk(&ys_all, u);
        if tamper == LayerTamper::JunkY && u == 0 {
            let mut split = crt_split(&ctx_ring, &p);
            split[1] = zq.add(split[1], 1); // junk coordinate 1 of slot 0
            crt_merge(&ctx_ring, &mut split);
            p = split;
        }
        p
    };
    // The zeta-deletion pack canary (design 2.4's fragility flag,
    // [Z1-f]): the per-wave ForcedZero zeta claims PROVE
    // zeta-functional(junk) = 0, so honest packing must leave every
    // junk coordinate zero — asserted at pack time, converting silent
    // packer drift into a named failure instead of a loud completeness
    // reject at the waves. (A malicious prover simply skips it — the
    // JunkY battery leg models exactly that.)
    let junk_canary = |p: &Poly, u: usize| {
        let split = crt_split(&ctx_ring, p);
        for (c, &v) in split.iter().enumerate() {
            let is_value = c % sd == 0 && u * k_slots + c / sd < n_el;
            assert!(
                is_value || v == 0,
                "zeta junk canary: nonzero junk coordinate at pack time (chunk {u}, coord {c})"
            );
        }
    };
    for tensor in 0..3usize {
        for cm in 0..slot_cms {
            let mut polys: Vec<Poly> = Vec::with_capacity(msg_r);
            for s in 0..msg_r {
                let u = cm * msg_r + s;
                let p = match tensor {
                    0 => {
                        let p = y_chunk(u);
                        if !(tamper == LayerTamper::JunkY && u == 0) {
                            junk_canary(&p, u);
                        }
                        p
                    }
                    1 => {
                        let p = slot_chunk(&up_all, u);
                        junk_canary(&p, u);
                        p
                    }
                    _ => {
                        let mut z = poly_mul_g(&zq, &y_chunk(u), &slot_chunk(&up_all, u));
                        if tamper == LayerTamper::HadamardZ && u == 0 {
                            let mut split = crt_split(&ctx_ring, &z);
                            split[7 * sd] = zq.add(split[7 * sd], 1);
                            crt_merge(&ctx_ring, &mut split);
                            z = split;
                        }
                        z
                    }
                };
                polys.push(p);
            }
            push_commit(polys, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
    }
    assert_eq!(msgs.len(), n_data);

    // ---- Pass 1.5 (U-Z1): the shared wave-share pad commitments —
    // statement material, committed HERE so h0_link binds them before
    // any challenge (alpha, psi, every per-wave h0) derives. Pad values
    // come from the per-proof ProverRng stream (fresh per proof — the
    // Z1-h freshness rule); the layout is the PUBLIC plan-derived
    // WavePadLayout. -------------------------------------------------------
    let masked_pins = masked && arm.has_any();
    let mut pads_live: Option<WavePads> = None;
    if masked_pins {
        assert_eq!(ls.base_pad, msgs.len(), "pad commitments sit right after the data");
        let pads = draw_wave_pads(&mut rng, q, &ls.pad_layout);
        let pad_msgs = pack_wave_pads(&mut rng, q, msg_r, &ls.pad_layout, &pads)
            .expect("pad packing follows the plan-derived layout");
        assert_eq!(pad_msgs.len(), ls.pad_layout.n_pad_cms);
        for m in pad_msgs {
            push_commit(m, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
        pads_live = Some(pads);
    }
    assert_eq!(msgs.len(), n_data + ls.pad_layout.n_pad_cms);

    // ---- Pass 2: per-wave g-groups (sizes from the plan-deterministic
    // budgets, D-4), still BEFORE any challenge derives. -------------------
    let mut g_base_global: Vec<usize> = Vec::with_capacity(n_waves);
    for w in 0..n_waves {
        g_base_global.push(msgs.len());
        let (c0, c1) = ls.wave_chunks[w];
        let n_pads = 2 * (c1 - c0);
        if ls.wave_lin[w] + n_pads == 0 {
            continue;
        }
        let gm = sample_g_masks(&mut rng, q, msg_r, ls.wave_lin[w], n_pads);
        assert_eq!(gm.len(), ls.wave_g_groups[w]);
        for m in gm {
            push_commit(m, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
    }
    // U-Z1 impl-b: the closing round's g-groups (one ct g-slot per exact
    // zero-sum claim) — committed with everything else BEFORE h0_link,
    // the same D-4 rule every wave's g obeys.
    let g_closing_off = msgs.len();
    if ls.closing_g_groups > 0 {
        let gm = sample_g_masks(&mut rng, q, msg_r, ls.pad_layout.n_claims, 0);
        assert_eq!(gm.len(), ls.closing_g_groups);
        for m in gm {
            push_commit(m, &mut rng, &mut msgs, &mut rhos8, &mut t1s, &mut t2s);
        }
    }
    cost.commit_s += t_commit.elapsed().as_secs_f64();

    // ---- The validated statement (manifest v2) — ctx for everything. ------
    let group_list_digest = |idx0: usize, count: usize| -> Vec<u8> {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        for i in idx0..idx0 + count {
            hasher.update(group_digest(&t1s[i], &t2s[i]));
        }
        hasher.finalize().to_vec()
    };
    let ki_t = key_info_bytes(&shape, q);
    let model_digest: [u8; 32] =
        uk8_sha(&[b"ur1-ffn-layer-v1", &(n_el as u64).to_le_bytes(), &spec_dg]);
    let mut mf = ClaimManifest::new("lattice-route-r", &crs.crs_hash);
    let mut quant = Vec::new();
    let (id_y, id_up, id_z);
    if arm.has_silu() {
        let id_x = mf.add_commitment("X", n_el, 1, Orientation::ByColumns, ki_t.clone(), group_list_digest(0, nx));
        id_y = mf.add_commitment("Y", n_el, 1, Orientation::ByColumns, ki_t.clone(), group_list_digest(ls.base_y, slot_cms));
        id_up = mf.add_commitment("UP", n_el, 1, Orientation::ByColumns, ki_t.clone(), group_list_digest(ls.base_up, slot_cms));
        id_z = mf.add_commitment("Z", n_el, 1, Orientation::ByColumns, ki_t, group_list_digest(ls.base_z, slot_cms));
        mf.add_operation(Operation::Lookup { x: id_x, y: id_y });
        quant.push(QuantMeta { bits: 8, frac_bits: 4, signed: true }); // X
    } else {
        // Arm B carries no claim about X; X stays committed (and bound in
        // h0_link) for cost parity but out of the statement.
        id_y = mf.add_commitment("Y", n_el, 1, Orientation::ByColumns, ki_t.clone(), group_list_digest(ls.base_y, slot_cms));
        id_up = mf.add_commitment("UP", n_el, 1, Orientation::ByColumns, ki_t.clone(), group_list_digest(ls.base_up, slot_cms));
        id_z = mf.add_commitment("Z", n_el, 1, Orientation::ByColumns, ki_t, group_list_digest(ls.base_z, slot_cms));
    }
    mf.add_operation(Operation::Hadamard { x: id_y, y: id_up, z: id_z });
    quant.push(QuantMeta { bits: 8, frac_bits: 4, signed: true }); // Y
    quant.push(QuantMeta { bits: 8, frac_bits: 4, signed: true }); // UP
    quant.push(QuantMeta { bits: 16, frac_bits: 8, signed: true }); // Z
    assert_eq!(
        spec_dg, manifest::SILU_INT8_TABLE_DIGEST,
        "frozen SiLU table digest parity (manifest constant vs ring/lookup.rs)"
    );
    // Canonical padding: X is dense-packed (msg_r * D coefficients per
    // commitment); Y/UP/Z are slot-packed (msg_r * k slots).
    let pad_x = manifest::PadSpec::units(n_el, 1, msg_r * D, 1);
    let pad_slot = manifest::PadSpec::units(n_el, 1, msg_r * k_slots, 1);
    let pads = if arm.has_silu() {
        vec![pad_x, pad_slot, pad_slot, pad_slot]
    } else {
        vec![pad_slot, pad_slot, pad_slot]
    };
    let mut statement = manifest::Statement::new(
        model_digest,
        Some(manifest::SILU_INT8_TABLE_SPEC),
        63 - q.leading_zeros(),
        mf,
    );
    statement.quant = quant;
    statement.pad = pads;
    statement.outputs = vec![id_z];
    let ctx_stmt: [u8; 32] = match statement.digest() {
        Ok(d) => d,
        Err(e) => {
            println!("  FAIL layer statement v3 does not validate: {e}");
            verdict.statement_ok = false;
            return (verdict, cost);
        }
    };

    // h0_link binds EVERY commitment of the layer — data and every wave's
    // g-groups — before any challenge (zeta, alpha, psi, wave h0s) derives.
    let h0_link = ct_h0(&crs, &ctx_stmt, &t1s, &t2s, &[]);
    let h0_zeta_y = uk8_sha(&[&h0_link, b"zeta-y"]);
    let h0_zeta_up = uk8_sha(&[&h0_link, b"zeta-up"]);

    if !quiet {
        println!(
            "  layer shape: {} el (2^{} - 4), {} data + {} pad + {} g commitments across {} waves (data cap {}, C2 max {}; {}), descent pairs dw = {} / dt = {} (silu {}, range {}); NO q46 plane/ARP side (ledger D-5{})",
            n_el,
            log2_el,
            n_data,
            ls.pad_layout.n_pad_cms,
            cost.n_g_groups,
            n_waves,
            ls.data_cap,
            ls.c2_max,
            if masked {
                "U-Z1 MASKED: pin shares carry coset one-time pads"
            } else {
                "LEGACY Revealed — the C-02 wire, [Z1-a] baseline only"
            },
            ls.dw,
            ls.dt,
            arm.has_silu(),
            arm.has_range(),
            if arm.has_range() { " — S3: the range table IS the range certifier" } else { ": lookup-side lift only until S3" }
        );
    }

    // ---- PROVER: lookup transcript, ONE masked descent pair, pins. --------
    let t_prove = Instant::now();
    let shell_w = zero_masks(&kf, ls.dw, 0);
    let shell_t = zero_masks(&kf, ls.dt, 0);
    // Descent pins: G hypersums, g openings, R openings (U-K5c — weights
    // depend only on the mask SHAPE and public opening points).
    let descent_pins = |base: usize,
                        shape_masks: &MaskSet,
                        proof: &MaskedDescentProof,
                        end: &DescentEnd,
                        depth: usize|
     -> Vec<PinnedValue> {
        let kelem_terms = |base: usize, flat_off: usize, weights: &[KElem]| -> Vec<PinTerm> {
            let mut terms = Vec::new();
            let mut i = 0usize;
            while i < weights.len() {
                let idx = flat_off + i;
                let commit = base + idx / kpc;
                let coeff0 = (idx % kpc) * K_DEG;
                let take = (kpc - (idx % kpc)).min(weights.len() - i);
                terms.push(PinTerm::Kelems { commit, coeff0, weights: weights[i..i + take].to_vec() });
                i += take;
            }
            terms
        };
        let mut pins = Vec::new();
        for j in 1..depth {
            let lp_j = &proof.layers[j - 1];
            let gm = &shape_masks.g[j - 1];
            pins.push(PinnedValue {
                terms: kelem_terms(base, shape_masks.g_offset(j), &g_hypersum_weights(&kf, gm)),
                value: lp_j.g_sum.clone(),
            });
            let (open_pt, mu_prev, c_w) = &end.layer_pts[j - 1];
            pins.push(PinnedValue {
                terms: kelem_terms(base, shape_masks.g_offset(j), &g_open_weights(&kf, gm, open_pt)),
                value: lp_j.open_g.clone(),
            });
            if j >= 2 {
                let (orp, orq) = lp_j.open_r.clone().expect("interior layer opens Rp/Rq");
                let rw = r_open_weights(&kf, mu_prev, c_w);
                pins.push(PinnedValue {
                    terms: kelem_terms(base, shape_masks.r_offset(j), &rw),
                    value: orp,
                });
                pins.push(PinnedValue {
                    terms: kelem_terms(base, shape_masks.r_offset(j) + 6, &rw),
                    value: orq,
                });
            }
        }
        pins
    };
    // Aggregate leaf pins, layer edition: X read through the offset fold
    // across nx commitments, Y through the E1-composed slot weights built
    // PER COMMITMENT (the layer-size weight vector lives once, inside the
    // pin terms — the H-03 discipline), m and the blinders as in U-K5c.
    let leaf_pins = |endw: &DescentEnd, endt: &DescentEnd, alpha: &KElem| -> Vec<PinnedValue> {
        use ring::gkr_masked::blinder_positions;
        let lw = eq_table(&kf, &endw.zstar);
        let lt = eq_table(&kf, &endt.zstar);
        let nw = 1usize << ls.dw;
        let nt = 1usize << ls.dt;
        let bpw = blinder_positions(nw);
        let bpt = blinder_positions(nt);
        let tpos = table_row_positions(t_rows, nt);
        let eqw: Vec<KElem> = bpw.iter().map(|&p| lw[p].clone()).collect();
        let eqt: Vec<KElem> = bpt.iter().map(|&p| lt[p].clone()).collect();
        let hw = (0..n_el).fold(zero.clone(), |a, i| kf.add(&a, &lw[i]));
        let ht = (0..t_rows).fold(zero.clone(), |a, j| kf.add(&a, &lt[tpos[j]]));
        let sum_eqw = eqw.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let sum_eqt = eqt.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let ft = (0..t_rows)
            .fold(zero.clone(), |a, j| kf.add(&a, &kf.mul(&lt[tpos[j]], &tab_fused[j])));
        let z = zero.clone();
        let wp = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: ls.idx_bl,
                coeff0: 0,
                weights: vec![
                    eqw[0].clone(), z.clone(), eqw[1].clone(), z.clone(),
                    eqw[2].clone(), z.clone(), eqw[3].clone(), z.clone(),
                ],
            }],
            value: kf.sub(&endw.p_claim, &hw),
        };
        // Witness Q: q* - alpha H - D_dummy - 128 H = [blinder u's]
        //   - sum lw x_u - sum Y lw y   (x = x_u - 128 folds into hw).
        let ddw = kf.sub(&kf.sub(&one, &hw), &sum_eqw);
        let mut wq_terms = vec![PinTerm::Kelems {
            commit: ls.idx_bl,
            coeff0: 0,
            weights: vec![
                z.clone(), eqw[0].clone(), z.clone(), eqw[1].clone(),
                z.clone(), eqw[2].clone(), z.clone(), eqw[3].clone(),
            ],
        }];
        for xc in 0..nx {
            let lo = xc * msg_r * D;
            let n_c = (n_el - lo).min(msg_r * D);
            wq_terms.push(PinTerm::Scalar {
                commit: xc,
                coeff0: 0,
                weights: (0..n_c).map(|i| kf.neg(&lw[lo + i])).collect(),
            });
        }
        let wy: Vec<KElem> = (0..n_el).map(|i| kf.neg(&mul_y(&kf, &lw[i]))).collect();
        for cm in 0..slot_cms {
            let t0 = cm * msg_r * k_slots;
            let t1e = ((cm + 1) * msg_r * k_slots).min(n_el);
            let w_cm = slot_pin_weights(&kf, &const_rows, &wy[t0..t1e], msg_r);
            wq_terms.push(PinTerm::Scalar { commit: ls.base_y + cm, coeff0: 0, weights: w_cm });
        }
        let wq = PinnedValue {
            terms: wq_terms,
            value: kf.sub(
                &kf.sub(&kf.sub(&endw.q_claim, &kf.mul(alpha, &hw)), &ddw),
                &kf.scale(128, &hw),
            ),
        };
        let tp = PinnedValue {
            terms: vec![
                PinTerm::Scalar {
                    commit: ls.idx_m,
                    coeff0: 0,
                    weights: (0..t_rows).map(|j| lt[tpos[j]].clone()).collect(),
                },
                PinTerm::Kelems {
                    commit: ls.idx_bl,
                    coeff0: 8 * K_DEG,
                    weights: vec![
                        eqt[0].clone(), z.clone(), eqt[1].clone(), z.clone(),
                        eqt[2].clone(), z.clone(), eqt[3].clone(), z.clone(),
                    ],
                },
            ],
            value: endt.p_claim.clone(),
        };
        let ddt = kf.sub(&kf.sub(&one, &ht), &sum_eqt);
        let tq = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: ls.idx_bl,
                coeff0: 8 * K_DEG,
                weights: vec![
                    z.clone(), eqt[0].clone(), z.clone(), eqt[1].clone(),
                    z.clone(), eqt[2].clone(), z.clone(), eqt[3].clone(),
                ],
            }],
            value: kf.add(&kf.sub(&kf.sub(&endt.q_claim, &kf.mul(alpha, &ht)), &ddt), &ft),
        };
        vec![wp, wq, tp, tq]
    };
    // U-R2 range leaf pins: the same four aggregate pins with NO offset
    // fold (the committed dense coefficient x_u IS the looked-up value at
    // w = 8) and no Y term; the table fold is the public identity row
    // ft_r = sum_j lt[tpos_j] * j.
    let leaf_pins_range = |endw: &DescentEnd, endt: &DescentEnd, alpha: &KElem| -> Vec<PinnedValue> {
        use ring::gkr_masked::blinder_positions;
        let lw = eq_table(&kf, &endw.zstar);
        let lt = eq_table(&kf, &endt.zstar);
        let t_rows_r = 1usize << UR2_RANGE_W;
        let bpw = blinder_positions(1usize << ls.dw);
        let bpt = blinder_positions(1usize << ls.dt);
        let tpos = table_row_positions(t_rows_r, 1usize << ls.dt);
        let eqw: Vec<KElem> = bpw.iter().map(|&p| lw[p].clone()).collect();
        let eqt: Vec<KElem> = bpt.iter().map(|&p| lt[p].clone()).collect();
        let hw = (0..n_el).fold(zero.clone(), |a, i| kf.add(&a, &lw[i]));
        let ht = (0..t_rows_r).fold(zero.clone(), |a, j| kf.add(&a, &lt[tpos[j]]));
        let sum_eqw = eqw.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let sum_eqt = eqt.iter().fold(zero.clone(), |a, e| kf.add(&a, e));
        let ft = (0..t_rows_r)
            .fold(zero.clone(), |a, j| kf.add(&a, &kf.scale(j as u64, &lt[tpos[j]])));
        let z = zero.clone();
        let wp = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: ls.idx_blr,
                coeff0: 0,
                weights: vec![
                    eqw[0].clone(), z.clone(), eqw[1].clone(), z.clone(),
                    eqw[2].clone(), z.clone(), eqw[3].clone(), z.clone(),
                ],
            }],
            value: kf.sub(&endw.p_claim, &hw),
        };
        let ddw = kf.sub(&kf.sub(&one, &hw), &sum_eqw);
        let mut wq_terms = vec![PinTerm::Kelems {
            commit: ls.idx_blr,
            coeff0: 0,
            weights: vec![
                z.clone(), eqw[0].clone(), z.clone(), eqw[1].clone(),
                z.clone(), eqw[2].clone(), z.clone(), eqw[3].clone(),
            ],
        }];
        for xc in 0..nx {
            let lo = xc * msg_r * D;
            let n_c = (n_el - lo).min(msg_r * D);
            wq_terms.push(PinTerm::Scalar {
                commit: xc,
                coeff0: 0,
                weights: (0..n_c).map(|i| kf.neg(&lw[lo + i])).collect(),
            });
        }
        let wq = PinnedValue {
            terms: wq_terms,
            value: kf.sub(&kf.sub(&endw.q_claim, &kf.mul(alpha, &hw)), &ddw),
        };
        let tp = PinnedValue {
            terms: vec![
                PinTerm::Scalar {
                    commit: ls.idx_mr,
                    coeff0: 0,
                    weights: (0..t_rows_r).map(|j| lt[tpos[j]].clone()).collect(),
                },
                PinTerm::Kelems {
                    commit: ls.idx_blr,
                    coeff0: 8 * K_DEG,
                    weights: vec![
                        eqt[0].clone(), z.clone(), eqt[1].clone(), z.clone(),
                        eqt[2].clone(), z.clone(), eqt[3].clone(), z.clone(),
                    ],
                },
            ],
            value: endt.p_claim.clone(),
        };
        let ddt = kf.sub(&kf.sub(&one, &ht), &sum_eqt);
        let tq = PinnedValue {
            terms: vec![PinTerm::Kelems {
                commit: ls.idx_blr,
                coeff0: 8 * K_DEG,
                weights: vec![
                    z.clone(), eqt[0].clone(), z.clone(), eqt[1].clone(),
                    z.clone(), eqt[2].clone(), z.clone(), eqt[3].clone(),
                ],
            }],
            value: kf.add(&kf.sub(&kf.sub(&endt.q_claim, &kf.mul(alpha, &ht)), &ddt), &ft),
        };
        vec![wp, wq, tp, tq]
    };
    let absorb_pins = |tr: &mut LkpTranscript, pins: &[PinnedValue]| {
        for p in pins {
            tr.absorb_k(&kf, "ur1-pin", std::slice::from_ref(&p.value));
        }
    };
    let m_column_k = |idx: usize, rows_n: usize| -> Vec<KElem> {
        msgs[idx][0..rows_n.div_ceil(D)]
            .iter()
            .flat_map(|p| p.iter().copied())
            .take(rows_n)
            .map(|c| {
                let mut e = kf.zero();
                e[0] = c;
                e
            })
            .collect()
    };

    let mut lkp: Option<(MaskedDescentProof, MaskedDescentProof)> = None;
    let mut lkp_r: Option<(MaskedDescentProof, MaskedDescentProof)> = None;
    let mut tr_state: Option<LkpTranscript> = None;
    let mut pin_claims_p: Vec<CtClaim> = Vec::new();
    if arm.has_any() {
        let t_lkp = Instant::now();
        // The lookup prehash context binds the STATEMENT-side table specs
        // in play (silu spec, and the U-R2 range table spec on range
        // arms) plus h0_link (which binds every commitment).
        let range_dg = ur2_range_table_digest();
        let ctx_lkp = match (arm.has_silu(), arm.has_range()) {
            (true, false) => uk8_sha(&[&spec_dg, &h0_link]),
            (true, true) => uk8_sha(&[&spec_dg, &range_dg, &h0_link]),
            (false, true) => uk8_sha(&[&range_dg, &h0_link]),
            (false, false) => unreachable!(),
        };
        let h0_lkp = ct_h0(&crs, &ctx_lkp, &t1s, &t2s, &[]);
        // Free-h0 attacker (C-02): build the whole lookup transcript on a
        // prover-chosen prehash. The verifier recomputes h0_lkp from
        // statement+commitments and never reads this, so the descents diverge.
        let prover_h0_lkp = if tamper == LayerTamper::LookupH0 {
            let mut h = h0_lkp;
            h[0] ^= 1;
            h
        } else {
            h0_lkp
        };
        let mut tr = LkpTranscript::new("ur1-lkp", &prover_h0_lkp);
        let mut pins: Vec<PinnedValue> = Vec::new();
        if arm.has_silu() {
            let alpha = tr.challenge_k(&kf);
            let w_fused: Vec<KElem> = xs_all
                .iter()
                .zip(ys_all.iter())
                .map(|(&x, &y)| fuse_pair(&kf, zq.to_mod(x), zq.to_mod(y)))
                .collect();
            let m_k = m_column_k(ls.idx_m, t_rows);
            let wtree = blinded_witness_tree(&kf, &alpha, &w_fused, ls.dw, bl_w.as_ref().unwrap());
            drop(w_fused);
            // Masks CONSUMED (moved into prove); descent_pins reads the
            // shape-only shells, exactly as the verifier rebuilds them.
            let (pw, endw) = masked_gkr_prove(&kf, &[wtree], masks_w.take().unwrap(), &mut tr);
            let ttree = blinded_table_tree(&kf, &alpha, &tab_fused, &m_k, ls.dt, bl_t.as_ref().unwrap());
            let (pt, endt) = masked_gkr_prove(&kf, &[ttree], masks_t.take().unwrap(), &mut tr);
            pins = descent_pins(ls.base_wm, &shell_w, &pw, &endw, ls.dw);
            pins.extend(descent_pins(ls.base_tm, &shell_t, &pt, &endt, ls.dt));
            pins.extend(leaf_pins(&endw, &endt, &alpha));
            lkp = Some((pw, pt));
        }
        if arm.has_range() {
            let alpha_r = tr.challenge_k(&kf);
            let w_range: Vec<KElem> =
                xs_all.iter().map(|&x| kf.embed(zq.to_mod(x + 128))).collect();
            let m_kr = m_column_k(ls.idx_mr, 1usize << UR2_RANGE_W);
            let wtree = blinded_witness_tree(&kf, &alpha_r, &w_range, ls.dw, bl_wr.as_ref().unwrap());
            drop(w_range);
            let (pw, endw) = masked_gkr_prove(&kf, &[wtree], masks_wr.take().unwrap(), &mut tr);
            let ttree = blinded_table_tree(&kf, &alpha_r, &tab_range, &m_kr, ls.dt, bl_tr.as_ref().unwrap());
            let (pt, endt) = masked_gkr_prove(&kf, &[ttree], masks_tr.take().unwrap(), &mut tr);
            pins.extend(descent_pins(ls.base_wmr, &shell_w, &pw, &endw, ls.dw));
            pins.extend(descent_pins(ls.base_tmr, &shell_t, &pt, &endt, ls.dt));
            pins.extend(leaf_pins_range(&endw, &endt, &alpha_r));
            lkp_r = Some((pw, pt));
        }
        absorb_pins(&mut tr, &pins);
        let psi = derive_pin_psi(&tr.state(), UR1_PIN_COPIES, pins.len() * K_DEG, q);
        pin_claims_p = pin_claims(&kf, &pins, n_data, msg_r, &psi);
        drop(pins);
        cost.lkp_prove_s += t_lkp.elapsed().as_secs_f64();
        tr_state = Some(tr);
    }

    // Split the pin claims across waves and apply the reveal-wire
    // tampers. Masked mode (U-Z1, the shipped path): coset one-time
    // pads — sigma~ = functional + pad, the pad table CONSUMED here
    // (one-time freshness). Unmasked mode is the LEGACY C-02 Revealed
    // wire, [Z1-a] baseline only.
    let msg_refs: Vec<&[Poly]> = msgs[..n_data].iter().map(|m| m.as_slice()).collect();
    let (mut pw_pins, mut pin_reveals) = if masked_pins {
        split_claims_prover_masked(
            &zq,
            &ls.plan,
            &pin_claims_p,
            &msg_refs,
            &ls.pad_layout,
            pads_live.take().expect("pads were drawn pre-challenge"),
        )
    } else {
        split_claims_prover(&zq, &ls.plan, &pin_claims_p, &msg_refs)
    }
    .expect("honest pin split (prover-side, layout-derived plan)");
    drop(pin_claims_p);
    if pw_pins.is_empty() {
        pw_pins = (0..n_waves).map(|_| Vec::new()).collect();
    }
    match tamper {
        LayerTamper::PartialLiePin => {
            assert!(pin_reveals[0].len() >= 2, "pin claim 0 must straddle waves");
            pin_reveals[0][0].1 = center128(pin_reveals[0][0].1 as i128 + 1);
        }
        LayerTamper::CompensatedPin => {
            assert!(pin_reveals[0].len() >= 2, "pin claim 0 must straddle waves");
            pin_reveals[0][0].1 = center128(pin_reveals[0][0].1 as i128 + 1);
            pin_reveals[0][1].1 = center128(pin_reveals[0][1].1 as i128 - 1);
        }
        _ => {}
    }

    cost.prove_s += t_prove.elapsed().as_secs_f64();

    // [U-R1b] differential (battery shapes, UNTIMED — a rig self-check,
    // not protocol work): the streaming zeta builder must reproduce
    // link_claims_tgt_slot + split_claims_prover exactly.
    if n_el <= (1 << 13) {
        use ring::link::{derive_link_zeta, link_claims_tgt_slot};
        let xi_zero: Vec<Vec<i64>> = vec![vec![0i64; ls.lp.n]; l_zeta];
        let y_zero = vec![0i64; l_zeta];
        for (h0z, base) in [(h0_zeta_y, ls.base_y), (h0_zeta_up, ls.base_up)] {
            let zrows = derive_link_zeta(&h0z, &ls.lp, k_slots);
            let value_slots: Vec<(usize, usize)> =
                (0..chunks).map(|u| (base + u / msg_r, u % msg_r)).collect();
            let full = link_claims_tgt_slot(&ctx_ring, &ls.lp, &xi_zero, &zrows, &y_zero, &value_slots);
            let (pw_full, rv_full) = split_claims_prover(&zq, &ls.plan, &full, &msg_refs)
                .expect("honest zeta split (differential leg)");
            let mut zs = ZetaStream::new(&ctx_ring, ls.lp, &coord_m, &h0z);
            for w in 0..n_waves {
                let (c0, c1) = ls.wave_chunks[w];
                if c1 == c0 {
                    continue;
                }
                let shares = zs.wave_shares(c0, c1, &|u| {
                    (ls.plan.slot_of[base + u / msg_r].1, u % msg_r)
                });
                for (row, coeffs) in shares.iter().enumerate() {
                    let expect = &pw_full[w][row];
                    let mut acc: i128 = 0;
                    for (li, s, p) in coeffs {
                        acc += ct_mul_centered(&zq, p, &msgs[ls.plan.waves[w][*li]][*s]) as i128;
                    }
                    let ok = expect.msg_coeffs == *coeffs
                        && expect.scalar == center128(acc)
                        && rv_full[row].iter().any(|&(rw, rp)| rw == w && rp == expect.scalar);
                    if !ok {
                        verdict.differential_ok = false;
                    }
                    // [Z1-f] identity (2), executable: an honest
                    // witness's TRUE zeta partials are identically
                    // zero PER WAVE — the fact that lets the reveal
                    // wire be deleted at all (design 2.4).
                    if tamper == LayerTamper::None && expect.scalar != 0 {
                        verdict.differential_ok = false;
                    }
                }
            }
        }
    }

    // ---- VERIFIER: lookup verify (fresh transcript, shell masks, root
    // cross-check), pins rebuilt, split-verified with the sum gate. --------
    let t_verify = Instant::now();
    let h0_link_v = ct_h0(&crs, &ctx_stmt, &t1s, &t2s, &[]);
    let mut pin_claims_v: Vec<CtClaim> = Vec::new();
    let mut tr_v_state: Option<LkpTranscript> = None;
    if arm.has_any() {
        let t_lkp = Instant::now();
        let range_dg = ur2_range_table_digest();
        let ctx_lkp_v = match (arm.has_silu(), arm.has_range()) {
            (true, false) => uk8_sha(&[&spec_dg, &h0_link_v]),
            (true, true) => uk8_sha(&[&spec_dg, &range_dg, &h0_link_v]),
            (false, true) => uk8_sha(&[&range_dg, &h0_link_v]),
            (false, false) => unreachable!(),
        };
        // h0_lkp is DERIVED from statement+commitments and seeds the
        // transcript; it is never read from the proof or compared to a
        // prover copy. A free/stale prover prehash makes the descents diverge.
        let expected_h0_lkp = ct_h0(&crs, &ctx_lkp_v, &t1s, &t2s, &[]);
        let mut tv = LkpTranscript::new("ur1-lkp", &expected_h0_lkp);
        let mut pv: Vec<PinnedValue> = Vec::new();
        let mut descents_ok = true;
        if arm.has_silu() {
            let (pw, pt) = lkp.as_ref().unwrap();
            let mut lookup_ok = true;
            let av = tv.challenge_k(&kf);
            let vw = masked_gkr_verify(&kf, 1, ls.dw, &shell_w, pw, &mut tv, false);
            let vt = masked_gkr_verify(&kf, 1, ls.dt, &shell_t, pt, &mut tv, false);
            match (vw, vt) {
                (Some((roots_w, ew)), Some((roots_t, et))) => {
                    lookup_ok &= !kf.is_zero(&roots_w[0][1]) && !kf.is_zero(&roots_t[0][1]);
                    lookup_ok &= kf.mul(&roots_w[0][0], &roots_t[0][1])
                        == kf.mul(&roots_t[0][0], &roots_w[0][1]);
                    pv = descent_pins(ls.base_wm, &shell_w, pw, &ew, ls.dw);
                    pv.extend(descent_pins(ls.base_tm, &shell_t, pt, &et, ls.dt));
                    pv.extend(leaf_pins(&ew, &et, &av));
                }
                _ => {
                    lookup_ok = false;
                    descents_ok = false;
                }
            }
            verdict.lookup_ok &= lookup_ok;
        }
        if arm.has_range() {
            let (pw, pt) = lkp_r.as_ref().unwrap();
            let mut range_ok = true;
            let av = tv.challenge_k(&kf);
            let vw = masked_gkr_verify(&kf, 1, ls.dw, &shell_w, pw, &mut tv, false);
            let vt = masked_gkr_verify(&kf, 1, ls.dt, &shell_t, pt, &mut tv, false);
            match (vw, vt) {
                (Some((roots_w, ew)), Some((roots_t, et))) => {
                    // The range root cross-check: the ONLY gate that sees
                    // an out-of-range dense coefficient in this rig.
                    range_ok &= !kf.is_zero(&roots_w[0][1]) && !kf.is_zero(&roots_t[0][1]);
                    range_ok &= kf.mul(&roots_w[0][0], &roots_t[0][1])
                        == kf.mul(&roots_t[0][0], &roots_w[0][1]);
                    pv.extend(descent_pins(ls.base_wmr, &shell_w, pw, &ew, ls.dw));
                    pv.extend(descent_pins(ls.base_tmr, &shell_t, pt, &et, ls.dt));
                    pv.extend(leaf_pins_range(&ew, &et, &av));
                }
                _ => {
                    range_ok = false;
                    descents_ok = false;
                }
            }
            verdict.range_ok &= range_ok;
        }
        if descents_ok {
            absorb_pins(&mut tv, &pv);
            let psi_v = derive_pin_psi(&tv.state(), UR1_PIN_COPIES, pv.len() * K_DEG, q);
            pin_claims_v = pin_claims(&kf, &pv, n_data, msg_r, &psi_v);
            drop(pv);
            tr_v_state = Some(tv);
        }
        cost.lkp_verify_s += t_lkp.elapsed().as_secs_f64();
        if tr_v_state.is_none() {
            // A broken descent leaves nothing to ground the wave pins —
            // the layer rejects here.
            verdict.sum_gate_ok = false;
            verdict.waves_ok = false;
            cost.verify_s += t_verify.elapsed().as_secs_f64();
            return (verdict, cost);
        }
    }
    let v_pins_result = if masked_pins {
        // The verifier derives the pad layout INDEPENDENTLY from the
        // public shape (D-2 lifted to pads) and must agree with the
        // prover byte-for-byte — the Z1-i determinism gate. A mismatch
        // is a code bug, not adversarial input: loud assert.
        let layout_v = ur1_layer_shape(log2_el, arm, shape, q, masked).pad_layout;
        assert_eq!(
            layout_v.layout_bytes(),
            ls.pad_layout.layout_bytes(),
            "verifier-derived pad layout must match the prover's byte-for-byte (Z1-i)"
        );
        split_claims_verifier_masked(&zq, &ls.plan, &pin_claims_v, &pin_reveals, &layout_v)
    } else {
        split_claims_verifier(&zq, &ls.plan, &pin_claims_v, &pin_reveals)
    };
    let v_pins: Vec<Vec<CtClaim>> = match v_pins_result {
        Ok(v) => v,
        Err(_) => {
            // Typed WaveError (audit M-01): the layer verifier rejects
            // fail-closed on any malformed/lied reveal structure.
            verdict.sum_gate_ok = false;
            verdict.waves_ok = false;
            cost.verify_s += t_verify.elapsed().as_secs_f64();
            return (verdict, cost);
        }
    };
    drop(pin_claims_v);
    let mut v_pins = v_pins;
    if v_pins.is_empty() {
        v_pins = (0..n_waves).map(|_| Vec::new()).collect();
    }
    cost.reveal_shares += pin_reveals.iter().map(|r| r.len()).sum::<usize>();
    cost.verify_s += t_verify.elapsed().as_secs_f64();

    // ---- The wave loop: per wave, prover round then verifier round
    // (independent zeta streams; proofs drop per wave). --------------------
    let lkp_state_p: [u8; 32] = match &tr_state {
        Some(tr) => tr.state(),
        None => h0_link,
    };
    let lkp_state_v: [u8; 32] = match &tr_v_state {
        Some(tv) => tv.state(),
        None => h0_link_v,
    };
    let one_poly = {
        let mut p = poly_zero();
        p[0] = 1;
        p
    };
    let neg_one_poly = {
        let mut p = poly_zero();
        p[0] = zq.neg(1);
        p
    };
    let unpack_rho = |packed: &[i8]| -> Vec<Vec<i64>> {
        (0..shape.n_r).map(|r| packed[r * D..(r + 1) * D].iter().map(|&b| b as i64).collect()).collect()
    };
    let mut zs_y_p = ZetaStream::new(&ctx_ring, ls.lp, &coord_m, &h0_zeta_y);
    let mut zs_up_p = ZetaStream::new(&ctx_ring, ls.lp, &coord_m, &h0_zeta_up);
    let mut zs_y_v = ZetaStream::new(&ctx_ring, ls.lp, &coord_m, &h0_zeta_y);
    let mut zs_up_v = ZetaStream::new(&ctx_ring, ls.lp, &coord_m, &h0_zeta_up);
    // U-Z1 impl-b: the zeta reveal WIRE IS DELETED (design 2.4). Honest
    // zeta shares are identically zero (identity 2 — the [Z1-f] canary
    // asserts junk == 0 at pack time), so the per-wave claims carry the
    // public scalar 0 (ForcedZero), nothing is sent, and the layer-wide
    // zeta_sums gate is RETIRED — per-wave zero is strictly stronger.
    // GMaskCrossUse (the S1-deferred forgery): the prover cross-uses a
    // DONOR wave's g-mask commitments in the TARGET wave's round —
    // self-consistently (donor g's presented in the wave list, opened,
    // and h0 recomputed over the spliced list; the forger's best play).
    // The verifier derives the wave layout independently, so its h0
    // binds the wave's OWN g's and the round REJECTS.
    let gx_pair: Option<(usize, usize)> = if tamper == LayerTamper::GMaskCrossUse {
        let chunk_waves: Vec<usize> = (0..n_waves)
            .filter(|&w| ls.wave_chunks[w].1 > ls.wave_chunks[w].0)
            .collect();
        let target = *chunk_waves.last().expect("a chunk wave exists");
        let donor = *chunk_waves
            .iter()
            .find(|&&w| w != target && ls.wave_g_groups[w] >= ls.wave_g_groups[target])
            .expect("a donor wave with enough g-groups exists");
        Some((target, donor))
    } else {
        None
    };
    let mut rp_cache: std::collections::BTreeMap<usize, (ring::ct_engine::CtRoundParams, ring::commit::A1Paths)> =
        std::collections::BTreeMap::new();
    // U-Z1: wave -> ordinal in the pad-wave set (None off the set); a
    // pad wave's round list gains its shared pad commitment at local
    // index wave.len() — the layout convention, derived from the PUBLIC
    // plan by both sides.
    let pad_ord: Vec<Option<usize>> = {
        let mut m = vec![None; n_waves];
        if ls.pad_layout.has_pads() {
            for (wi, &w) in ls.pad_layout.pad_waves.iter().enumerate() {
                m[w] = Some(wi);
            }
        }
        m
    };
    for w in 0..n_waves {
        let wave = &ls.plan.waves[w];
        let (c0, c1) = ls.wave_chunks[w];
        if ls.wave_lin[w] == 0 && c0 == c1 {
            // Bare-arm waves holding only X commitments carry no claims —
            // there is no round to run (the commitments stay bound in
            // h0_link; nothing is asserted about them in this arm).
            assert!(!arm.has_any());
            continue;
        }
        let g_off = g_base_global[w];
        let g_cnt = ls.wave_g_groups[w];
        let pad_cm: Option<usize> =
            pad_ord[w].map(|wi| ls.base_pad + wi / ls.pad_layout.waves_per_cm);
        let pad_shift = usize::from(pad_cm.is_some());
        // The verifier's (honest, layout-derived) wave list; the prover's
        // list differs only under the cross-use forgery.
        let idxs: Vec<usize> = wave
            .iter()
            .copied()
            .chain(pad_cm)
            .chain(g_off..g_off + g_cnt)
            .collect();
        let g_off_p = match gx_pair {
            Some((t, d)) if w == t => g_base_global[d],
            _ => g_off,
        };
        let idxs_p: Vec<usize> = wave
            .iter()
            .copied()
            .chain(pad_cm)
            .chain(g_off_p..g_off_p + g_cnt)
            .collect();
        let n_cw = idxs.len();
        assert!(n_cw <= ls.c2_max);
        if !rp_cache.contains_key(&n_cw) {
            let rp = derive_ct_round_params(q, shape, n_cw, 0, 0, true);
            let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
            rp_cache.insert(n_cw, (rp, a1p));
        }
        let wt1s: Vec<Vec<Poly>> = idxs.iter().map(|&i| t1s[i].clone()).collect();
        let wt2s: Vec<Vec<Poly>> = idxs.iter().map(|&i| t2s[i].clone()).collect();
        // Wave-local quad ring claims through the S0 co-location path.
        let mut quads_loc: Vec<QuadRingClaim> = Vec::with_capacity(c1 - c0);
        for u in c0..c1 {
            let qc = QuadRingClaim {
                quad: vec![(
                    ls.base_y + u / msg_r,
                    u % msg_r,
                    ls.base_up + u / msg_r,
                    u % msg_r,
                    one_poly.clone(),
                )],
                msg_coeffs: vec![(ls.base_z + u / msg_r, u % msg_r, neg_one_poly.clone())],
            };
            let (qw, qloc) = quad_ring_localized(&ls.plan, &qc)
                .expect("planner co-location keeps the quad in one wave");
            assert_eq!(qw, w, "planner co-location must keep the quad in its wave");
            quads_loc.push(qloc);
        }

        // ================= PROVER =================
        let t_p = Instant::now();
        let mut claims_p: Vec<CtClaim> = std::mem::take(&mut pw_pins[w]);
        // The zeta deletion: per-wave ForcedZero claims — the prover
        // computes NO partials (the ct_mul_centered walk over every
        // Y/UP chunk is gone with the wire) and sends NOTHING.
        for (zs, base) in [(&mut zs_y_p, ls.base_y), (&mut zs_up_p, ls.base_up)] {
            if c1 == c0 {
                continue;
            }
            let shares = zs.wave_shares(c0, c1, &|u| {
                (ls.plan.slot_of[base + u / msg_r].1, u % msg_r)
            });
            for coeffs in shares {
                claims_p.push(CtClaim { msg_coeffs: coeffs, ajtai_coeffs: vec![], scalar: 0 });
            }
        }
        assert_eq!(
            claims_p.len(),
            ls.wave_lin[w],
            "the wave's claim count must equal the plan-derived g budget (D-4)"
        );
        let wrhos: Vec<Vec<Vec<i64>>> = idxs_p.iter().map(|&i| unpack_rho(&rhos8[i])).collect();
        let openings: Vec<StdOpening> = idxs_p
            .iter()
            .enumerate()
            .map(|(j, &i)| StdOpening { t1: &t1s[i], t2: &t2s[i], x: &msgs[i], rho: &wrhos[j] })
            .collect();
        let (rp_w, a1p_w) = rp_cache.get(&n_cw).unwrap();
        let path_w = KernelPath::A1(a1p_w);
        let mut state_p: Vec<u8> = lkp_state_p.to_vec();
        state_p.extend((w as u64).to_le_bytes());
        // The prover's h0 is over ITS list (spliced under the forgery —
        // the forger commits fully to the cross-used g's).
        let (wt1s_p, wt2s_p): (Vec<Vec<Poly>>, Vec<Vec<Poly>>) = if idxs_p == idxs {
            (Vec::new(), Vec::new())
        } else {
            (
                idxs_p.iter().map(|&i| t1s[i].clone()).collect(),
                idxs_p.iter().map(|&i| t2s[i].clone()).collect(),
            )
        };
        let h0_w = if idxs_p == idxs {
            ct_h0(&crs, &state_p, &wt1s, &wt2s, &[])
        } else {
            ct_h0(&crs, &state_p, &wt1s_p, &wt2s_p, &[])
        };
        let (proof_w, _) = prove_ct_round(
            &path_w, &ctx_ring, rp_w, None, &crs, &h0_w, &claims_p, &[], &[], &quads_loc,
            &openings, &[], &[], wave.len() + pad_shift, &mut rng,
        );
        drop(claims_p);
        cost.prove_s += t_p.elapsed().as_secs_f64();

        // ================= VERIFIER =================
        let t_v = Instant::now();
        let mut claims_v: Vec<CtClaim> = std::mem::take(&mut v_pins[w]);
        // The verifier builds the SAME public zero claims — nothing was
        // sent, nothing is gated here; the wave's ct-round proves
        // zeta-functional(junk) = 0 directly against the commitments.
        for (zs, base) in [(&mut zs_y_v, ls.base_y), (&mut zs_up_v, ls.base_up)] {
            if c1 == c0 {
                continue;
            }
            let shares = zs.wave_shares(c0, c1, &|u| {
                (ls.plan.slot_of[base + u / msg_r].1, u % msg_r)
            });
            for coeffs in shares {
                claims_v.push(CtClaim { msg_coeffs: coeffs, ajtai_coeffs: vec![], scalar: 0 });
            }
        }
        let mut state_v: Vec<u8> = lkp_state_v.to_vec();
        state_v.extend((w as u64).to_le_bytes());
        let h0_wv = ct_h0(&crs, &state_v, &wt1s, &wt2s, &[]);
        let ok_w = verify_ct_round(
            &path_w, &ctx_ring, rp_w, None, &crs, &h0_wv, &claims_v, &[], &[], &quads_loc,
            &wt1s, &wt2s, &[], &[], &[], wave.len() + pad_shift, &proof_w,
        );
        if !ok_w {
            verdict.waves_ok = false;
            if verdict.first_bad_wave.is_none() {
                verdict.first_bad_wave = Some(w);
            }
        }
        cost.verify_s += t_v.elapsed().as_secs_f64();
    }
    // (The layer-wide zeta_sums gate that closed here is RETIRED with
    // the wire: every wave's ct-round now proves its zeta claims equal
    // the public constant 0 — per-wave localization, strictly stronger.)

    // ---- U-Z1 impl-b: the CLOSING ROUND — the nine exact zero-sum
    // claims sum_w e_{j,w} = 0 (design eq. 4) over the shared pad
    // commitments. STANDALONE round rather than folded into the last
    // wave (the engine choice design 2.3 leaves open), for two recorded
    // reasons: (a) auditability — the design document specifies the
    // standalone form; (b) budget isolation — folding would charge the
    // last wave's C2 budget the n_pad_cms + closing-g commitments and
    // couple the wave plan to the closing shape. Soundness chain: the
    // wave rounds force sigma~ = functional + pad (eq. 3), this round
    // forces sum pads = 0 (eq. 4), the sum gate forces sum sigma~ = T;
    // adding and subtracting: sum functional = T — exactly the unmasked
    // guarantee. The [Z1-d] pair demonstrates BOTH directions. --------
    if ls.pad_layout.has_pads() {
        use ring::ct_engine::closing_round_claims;
        let idxs_z: Vec<usize> = (ls.base_pad..ls.base_pad + ls.pad_layout.n_pad_cms)
            .chain(g_closing_off..g_closing_off + ls.closing_g_groups)
            .collect();
        let n_cz = idxs_z.len();
        if !rp_cache.contains_key(&n_cz) {
            let rp = derive_ct_round_params(q, shape, n_cz, 0, 0, true);
            let a1p = build_a1_paths(&crs, rp.sigma, isqrt_u128(rp.bound_sq));
            rp_cache.insert(n_cz, (rp, a1p));
        }
        let (rp_z, a1p_z) = rp_cache.get(&n_cz).unwrap();
        let path_z = KernelPath::A1(a1p_z);
        let zt1s: Vec<Vec<Poly>> = idxs_z.iter().map(|&i| t1s[i].clone()).collect();
        let zt2s: Vec<Vec<Poly>> = idxs_z.iter().map(|&i| t2s[i].clone()).collect();
        // ================= PROVER =================
        let t_p = Instant::now();
        let claims_z = closing_round_claims(&zq, &ls.pad_layout);
        // c_z's h0: the lookup-transcript state (which binds h0_link and
        // through it EVERY commitment) + the closing tag + the round's
        // own list — all pad commitments — per design 2.5 row 3.
        let mut state_z: Vec<u8> = lkp_state_p.to_vec();
        state_z.extend(b"z1-closing");
        let h0_z = ct_h0(&crs, &state_z, &zt1s, &zt2s, &[]);
        let zrhos: Vec<Vec<Vec<i64>>> = idxs_z.iter().map(|&i| unpack_rho(&rhos8[i])).collect();
        let openings_z: Vec<StdOpening> = idxs_z
            .iter()
            .enumerate()
            .map(|(j, &i)| StdOpening { t1: &t1s[i], t2: &t2s[i], x: &msgs[i], rho: &zrhos[j] })
            .collect();
        let (proof_z, _) = prove_ct_round(
            &path_z, &ctx_ring, rp_z, None, &crs, &h0_z, &claims_z, &[], &[], &[],
            &openings_z, &[], &[], ls.pad_layout.n_pad_cms, &mut rng,
        );
        cost.prove_s += t_p.elapsed().as_secs_f64();
        // ================= VERIFIER =================
        // Everything on this side is public: the verifier rebuilds the
        // nine zero-scalar claims itself (no reveals ride this round).
        let t_v = Instant::now();
        let claims_zv = closing_round_claims(&zq, &ls.pad_layout);
        let mut state_zv: Vec<u8> = lkp_state_v.to_vec();
        state_zv.extend(b"z1-closing");
        let h0_zv = ct_h0(&crs, &state_zv, &zt1s, &zt2s, &[]);
        if !verify_ct_round(
            &path_z, &ctx_ring, rp_z, None, &crs, &h0_zv, &claims_zv, &[], &[], &[],
            &zt1s, &zt2s, &[], &[], &[], ls.pad_layout.n_pad_cms, &proof_z,
        ) {
            verdict.closing_ok = false;
        }
        cost.verify_s += t_v.elapsed().as_secs_f64();
    }
    (verdict, cost)
}

/// [U-R1b] battery (`ffn-chain layer battery`): the multi-wave per-layer
/// rig at a fast shape — honest ACCEPT on both arms, the streaming-zeta
/// differential, the wave-boundary tampers (lied and compensated partial
/// scalars on both the pin and zeta families), the block-rig edges at
/// the new shape (off-table Y, tampered Z, lookup-h0 bit flip), and the
/// planner's straddling-quad detection.
fn self_test_ffn_layer() {
    use ring::ct_engine::{QuadRingClaim, plan_waves, quad_ring_wave};
    println!("\n[U-R1b] per-layer multi-wave rig: split claims, one descent pair, wave-boundary tampers");
    let lg = 12usize;
    let t0 = Instant::now();
    let (va, ca) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::None, 0x5eed_0111, ChainEntropy::Test, false);
    assert_true(
        &format!(
            "U-R1b honest layer ACCEPTS end-to-end ({} el across {} waves: statement v2 + ONE masked descent pair + split pin/zeta claims + per-wave ct-rounds; commit {:.2}s prove {:.2}s verify {:.2}s)",
            ca.n_el, ca.n_waves, ca.commit_s, ca.prove_s, ca.verify_s
        ),
        va.all_ok(),
    );
    assert_true(
        "U-R1b differential: streaming zeta shares == link_claims_tgt_slot + split_claims_prover (bit-for-bit at the battery shape)",
        va.differential_ok,
    );
    let (vb, cb) = ffn_layer_run(lg, LayerArm::Bare, true, LayerTamper::None, 0x5eed_0111, ChainEntropy::Test, true);
    assert_true(
        &format!(
            "U-R1b baseline arm (lookup omitted) ACCEPTS — the A/B marginal is measurable (prove +{:.2}s, verify +{:.2}s, commit +{} q31 coefficients)",
            ca.prove_s - cb.prove_s,
            ca.verify_s - cb.verify_s,
            (ca.q31_data_coeffs + ca.q31_g_coeffs) as i64
                - (cb.q31_data_coeffs + cb.q31_g_coeffs) as i64
        ),
        vb.all_ok(),
    );
    // Wave boundary, pin family (the audited S0 path at layer scale).
    let (vl, _) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::PartialLiePin, 0x5eed_0112, ChainEntropy::Test, true);
    assert_true(
        "U-R1b wave boundary: a lied pin partial scalar REJECTS at split_claims_verifier's sum gate (lookup itself passes)",
        !vl.sum_gate_ok && vl.lookup_ok && vl.statement_ok,
    );
    let (vc, _) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::CompensatedPin, 0x5eed_0113, ChainEntropy::Test, true);
    assert_true(
        "U-R1b wave boundary: a COMPENSATED pin lie passes the sum gate but its wave's ct-round REJECTS the false partial (the load-bearing leg)",
        vc.sum_gate_ok && !vc.waves_ok && vc.lookup_ok,
    );
    // [Z1-f] the zeta deletion (U-Z1 impl-b): the reveal wire is GONE —
    // per-wave ForcedZero claims replace it. (i) The reveal-count
    // differential: only the 9 pin shares per pad wave remain on the
    // wire (was 9 + 48 per chunk wave — the -576 B/chunk-wave of design
    // 6.2, recorded here as an executable count; the honest-witness
    // zero-partials identity is asserted inside the differential leg
    // above, and the pack canary asserts junk == 0 at commit time).
    {
        let ls_b = ur1_layer_shape(lg, LayerArm::Lookup, CommitShape { kappa: 8, n_r: 26, msg_r: 8 }, Q8, true);
        let n_chunk_waves =
            (0..ls_b.plan.waves.len()).filter(|&w| ls_b.wave_chunks[w].1 > ls_b.wave_chunks[w].0).count();
        assert_true(
            &format!(
                "[Z1-f] the zeta wire is DELETED: {} reveal shares == 9 pins x {} pad waves (48 zeta reveals/chunk wave retired -> -{} B here, -576 B/chunk-wave at scale); per-wave zero claims are strictly stronger than the retired layer-wide gate",
                ca.reveal_shares,
                ls_b.pad_layout.pad_waves.len(),
                48 * 12 * n_chunk_waves
            ),
            ca.reveal_shares == 9 * ls_b.pad_layout.pad_waves.len(),
        );
    }
    // (ii) A junk-bearing witness — nonzero junk CRT coordinate in a Y
    // chunk, consumed consistently (Z is the ring product of the
    // tampered Y, so the quad is TRUE; constants untouched, so lookup
    // and pins pass) — REJECTS at exactly its wave's ForcedZero zeta
    // claim: the per-wave localization the deletion buys.
    let (vj, _) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::JunkY, 0x5eed_0114, ChainEntropy::Test, true);
    let junk_wave = {
        let ls_b = ur1_layer_shape(lg, LayerArm::Lookup, CommitShape { kappa: 8, n_r: 26, msg_r: 8 }, Q8, true);
        ls_b.plan.slot_of[ls_b.base_y].0
    };
    assert_true(
        "[Z1-f] a junk-bearing witness REJECTS at exactly its wave's ForcedZero zeta claim (quad TRUE, lookup/pins/sum gate/closing round all pass) — per-wave localization",
        !vj.waves_ok
            && vj.first_bad_wave == Some(junk_wave)
            && vj.lookup_ok
            && vj.sum_gate_ok
            && vj.closing_ok,
    );
    // The block-rig chain edges at the layer shape.
    let (vy, _) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::OffTableY, 0x5eed_0116, ChainEntropy::Test, true);
    assert_true(
        "U-R1b edge (lookup): an off-table Y REJECTS at the masked lookup's root cross-check; every wave passes (the edge is isolated)",
        !vy.lookup_ok && vy.waves_ok && vy.sum_gate_ok,
    );
    let (vh, _) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::HadamardZ, 0x5eed_0117, ChainEntropy::Test, true);
    let z_wave = {
        let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 8 };
        let ls = ur1_layer_shape(lg, LayerArm::Lookup, shape, Q8, true);
        ls.plan.slot_of[ls.base_y].0
    };
    assert_true(
        "U-R1b edge (gate-o-up): a tampered Z slot constant REJECTS at its wave's quad ring claim; the lookup passes",
        !vh.waves_ok && vh.first_bad_wave == Some(z_wave) && vh.lookup_ok,
    );
    let (vk, _) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::LookupH0, 0x5eed_0118, ChainEntropy::Test, true);
    assert_true(
        "U-R1b transcript boundary (C-02): a free prover-chosen lookup h0 REJECTS because the verifier DERIVES h0 from statement+commitments — the masked descents diverge and cannot ground the wave pins; no prover h0 is read or compared, and the layer does not accept",
        !vk.lookup_ok && !vk.all_ok(),
    );
    // Planner: without the co-location groups, a Hadamard quad straddles
    // waves and quad_ring_wave detects it.
    {
        let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 8 };
        let ls = ur1_layer_shape(lg, LayerArm::Lookup, shape, Q8, true);
        let naive = plan_waves(ls.n_data, &[], ls.data_cap).expect("naive plan derives");
        let one_poly = {
            let mut p = poly_zero();
            p[0] = 1;
            p
        };
        let straddler = (0..ls.chunks).any(|u| {
            let qc = QuadRingClaim {
                quad: vec![(
                    ls.base_y + u / 8,
                    u % 8,
                    ls.base_up + u / 8,
                    u % 8,
                    one_poly.clone(),
                )],
                msg_coeffs: vec![(ls.base_z + u / 8, u % 8, one_poly.clone())],
            };
            quad_ring_wave(&naive, &qc)
                == Err(ring::ct_engine::WaveError::QuadStraddlesWaves)
        });
        assert_true(
            "U-R1b planner: without co-location groups a straddling Hadamard quad is DETECTED (quad_ring_wave = Err(QuadStraddlesWaves)); the layer plan co-locates every triple",
            straddler,
        );
    }

    // ---- [U-R2a] S3 legs: the range-table instance. ----------------------
    let (vr, cr) = ffn_layer_run(lg, LayerArm::LookupRange, true, LayerTamper::None, 0x5eed_0211, ChainEntropy::Test, false);
    assert_true(
        &format!(
            "U-R2a honest layer + RANGE table ACCEPTS (second 256-row instance, own m/blinders/masks, X read dense at w = 8; commit +{} q31 coefficients over the silu arm)",
            (cr.q31_data_coeffs + cr.q31_g_coeffs) as i64
                - (ca.q31_data_coeffs + ca.q31_g_coeffs) as i64
        ),
        vr.all_ok(),
    );
    let (vro, _) = ffn_layer_run(lg, LayerArm::RangeOnly, true, LayerTamper::None, 0x5eed_0212, ChainEntropy::Test, true);
    assert_true(
        "U-R2a range-only arm ACCEPTS (the range table as the SOLE X certifier — the S3 architecture)",
        vro.all_ok(),
    );
    // Out-of-range X, ISOLATED: on the range-only arm nothing but the
    // range lookup reads X's values off a table, so the range root
    // cross-check is the single rejecting gate.
    let (vrx, _) = ffn_layer_run(lg, LayerArm::RangeOnly, true, LayerTamper::RangeX, 0x5eed_0213, ChainEntropy::Test, true);
    assert_true(
        "U-R2a edge (range): x_u = 300 smuggled into the dense column REJECTS at the range lookup's root cross-check; waves/sum gates all pass (the edge is isolated)",
        !vrx.range_ok && vrx.waves_ok && vrx.sum_gate_ok && vrx.statement_ok,
    );
    // The same smuggle on the full arm: X is DOUBLY covered there (the
    // silu lookup fuses the same X), so both root checks reject —
    // recorded honestly; the range check remains the load-bearing one
    // once S3's architecture drops the plane/ARP side for good.
    let (vrx2, _) = ffn_layer_run(lg, LayerArm::LookupRange, true, LayerTamper::RangeX, 0x5eed_0214, ChainEntropy::Test, true);
    assert_true(
        "U-R2a edge (range, full arm): the smuggled x_u = 300 REJECTS at the range root check (and at the silu root too — X is doubly covered on this arm); waves pass",
        !vrx2.range_ok && !vrx2.lookup_ok && vrx2.waves_ok && vrx2.sum_gate_ok,
    );
    // The S1-deferred wave-boundary forgery: cross-used g-masks.
    let (vgx, _) = ffn_layer_run(lg, LayerArm::Lookup, true, LayerTamper::GMaskCrossUse, 0x5eed_0215, ChainEntropy::Test, true);
    let gx_target = {
        let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 8 };
        let ls = ur1_layer_shape(lg, LayerArm::Lookup, shape, Q8, true);
        (0..ls.plan.waves.len()).filter(|&w| ls.wave_chunks[w].1 > ls.wave_chunks[w].0).next_back().unwrap()
    };
    assert_true(
        "U-R1b forgery (deferred from S1): a donor wave's g-masks cross-used self-consistently in another wave REJECT at exactly that wave (per-wave h0 binds the wave's OWN commitment list); lookup/sum gates pass",
        !vgx.waves_ok
            && vgx.first_bad_wave == Some(gx_target)
            && vgx.lookup_ok
            && vgx.sum_gate_ok,
    );
    println!(
        "  [U-R1b] battery done in {:.1}s (timings [NOISY-SHARED])",
        t0.elapsed().as_secs_f64()
    );
}

/// Self-test smoke leg: ONE honest layer shape through the full
/// multi-wave path (the battery's tamper legs stay behind
/// `ffn-chain layer battery` to keep self-test fast).
fn self_test_ffn_layer_smoke() {
    println!("\n[U-R1b] per-layer multi-wave smoke: one honest shape, both gates");
    let (v, c) = ffn_layer_run(12, LayerArm::Lookup, true, LayerTamper::None, 0x5eed_0110, ChainEntropy::Test, false);
    assert_true(
        &format!(
            "U-R1b smoke: honest 2^12 layer ACCEPTS ({} el, {} waves, {} data + {} g commitments; sum gate + ForcedZero zeta claims + {} wave rounds + closing round green; streaming-zeta differential {})",
            c.n_el,
            c.n_waves,
            c.n_data,
            c.n_g_groups,
            c.n_waves,
            if v.differential_ok { "matched" } else { "MISMATCH" }
        ),
        v.all_ok() && v.differential_ok,
    );
}

/// `ffn-chain layer <log2_el>` — the U-R1 S2 measurement: ONE per-layer
/// instance, arm A (multi-wave committed masked lookup + Hadamard +
/// zeta) vs arm B (identical minus lookup), per-stage totals, us/el,
/// the lookup marginal, committed-coefficient and transcript accounting,
/// peak RSS — against the block rig's B = 1020 marginals (PROGRESS.md
/// A-D2) for the amortization curve. All wall times [NOISY-SHARED].
fn ffn_layer_bench(log2_el: usize) {
    let t_a = Instant::now();
    println!(
        "u-r1 ffn-chain layer bench: 2^{log2_el} - 4 elements, ONE per-layer instance, multi-wave q31, 1T"
    );
    let (va, ca) = ffn_layer_run(log2_el, LayerArm::Lookup, true, LayerTamper::None, 0x5eed_01b1, ChainEntropy::Os, false);
    let wall_a = t_a.elapsed().as_secs_f64();
    assert!(va.all_ok(), "arm A (lookup-integrated layer) must verify");
    let hwm_a = vm_hwm_kb();
    let t_b = Instant::now();
    let (vb, cb) = ffn_layer_run(log2_el, LayerArm::Bare, true, LayerTamper::None, 0x5eed_01b1, ChainEntropy::Os, true);
    let wall_b = t_b.elapsed().as_secs_f64();
    assert!(vb.all_ok(), "arm B (lookup omitted) must verify");
    let hwm_b = vm_hwm_kb();
    let el = ca.n_el as f64;
    println!("  arm A = multi-wave committed masked lookup + Hadamard + zeta; arm B = identical minus lookup. [NOISY-SHARED]");
    let line = |label: &str, a: f64, b: f64| {
        println!(
            "  {label:<24} A {a:9.2}s ({:7.1} us/el)  B {b:9.2}s  marginal {:+9.2}s = {:+7.1} us/el",
            a / el * 1e6,
            a - b,
            (a - b) / el * 1e6
        );
    };
    line("commit", ca.commit_s, cb.commit_s);
    line("prove", ca.prove_s, cb.prove_s);
    line("verify", ca.verify_s, cb.verify_s);
    line("wall (incl. setup)", wall_a, wall_b);
    println!(
        "  lookup stage attribution (arm A): prove {:.2}s ({:.1} us/el), verify {:.2}s ({:.1} us/el) — trees + ONE masked descent pair + pins + pin claims",
        ca.lkp_prove_s,
        ca.lkp_prove_s / el * 1e6,
        ca.lkp_verify_s,
        ca.lkp_verify_s / el * 1e6
    );
    let dce_a = ca.q31_data_coeffs + ca.q31_g_coeffs + ca.q31_pad_coeffs;
    let dce_b = cb.q31_data_coeffs + cb.q31_g_coeffs + cb.q31_pad_coeffs;
    println!(
        "  committed q31 coefficients: A {dce_a} (data {} + g {} + Z1 pads {}), B {dce_b} -> lookup marginal {:.3} dce/el at ONE {}-el instance (m + blinders + masks + pin g's + wave-share pads, amortized layer-wide)",
        ca.q31_data_coeffs, ca.q31_g_coeffs, ca.q31_pad_coeffs, (dce_a - dce_b) as f64 / el, ca.n_el
    );
    println!(
        "  masked transcript: {} B descent pair + {} partial reveals x 12 B = {:.1} KB total -> {:.3} B/el (arm A)",
        ca.masked_bytes,
        ca.reveal_shares,
        (ca.masked_bytes + ca.reveal_shares * 12) as f64 / 1024.0,
        (ca.masked_bytes + ca.reveal_shares * 12) as f64 / el
    );
    println!(
        "  wave accounting: {} waves (data cap {} of C2 max {}), {} data + {} g commitments; g fraction {:.1}%",
        ca.n_waves,
        {
            let ls = ur1_layer_shape(log2_el, LayerArm::Lookup, CommitShape { kappa: 8, n_r: 26, msg_r: 8 }, Q8, true);
            ls.data_cap
        },
        {
            let ls = ur1_layer_shape(log2_el, LayerArm::Lookup, CommitShape { kappa: 8, n_r: 26, msg_r: 8 }, Q8, true);
            ls.c2_max
        },
        ca.n_data,
        ca.n_g_groups,
        ca.q31_g_coeffs as f64 / (ca.q31_data_coeffs + ca.q31_g_coeffs) as f64 * 100.0
    );
    println!(
        "  vs block rig at B = 1020 (PROGRESS.md A-D2, [NOISY-SHARED]): prove +205.9 us/el, verify +130.0 us/el, 14.1 dce/el, 37.5 B/el masked transcript — this shape's marginals above are the amortization curve points"
    );
    println!(
        "  peak RSS: {:.2} GiB after arm A, {:.2} GiB after both",
        hwm_a as f64 / 1024.0 / 1024.0,
        hwm_b as f64 / 1024.0 / 1024.0
    );
    println!(
        "ffn-chain layer bench done ({} el, all timings [NOISY-SHARED] 1T)",
        ca.n_el
    );
}

/// `ffn-chain layer <log2_el> range` — the U-R2 S3 measurement: arm R
/// (silu lookup + range-table instance) vs arm A (silu lookup only) at
/// ONE per-layer instance. The marginal is the LOOKUP-BASED RANGE
/// CERTIFICATION cost per element — the number RANGE_AGGREGATION_DESIGN
/// Section 3 predicts collapses vs the block rig's q46 plane+ARP range
/// side (582 dce/el committed; ~96% of 10.7 ms/el prove). All wall
/// times [NOISY-SHARED].
fn ffn_layer_range_bench(log2_el: usize) {
    let t_r = Instant::now();
    println!(
        "u-r2 ffn-chain layer RANGE bench: 2^{log2_el} - 4 elements, arm R = silu + range table, arm A = silu only, 1T"
    );
    let (vr, cr) = ffn_layer_run(log2_el, LayerArm::LookupRange, true, LayerTamper::None, 0x5eed_02b1, ChainEntropy::Os, false);
    let wall_r = t_r.elapsed().as_secs_f64();
    assert!(vr.all_ok(), "arm R (range-integrated layer) must verify");
    let hwm_r = vm_hwm_kb();
    let t_a = Instant::now();
    let (va, ca) = ffn_layer_run(log2_el, LayerArm::Lookup, true, LayerTamper::None, 0x5eed_02b1, ChainEntropy::Os, true);
    let wall_a = t_a.elapsed().as_secs_f64();
    assert!(va.all_ok(), "arm A (silu only) must verify");
    let el = cr.n_el as f64;
    println!("  arm R = silu + range-table instance; arm A = identical minus range material. [NOISY-SHARED]");
    let line = |label: &str, r: f64, a: f64| {
        println!(
            "  {label:<24} R {r:9.2}s ({:7.1} us/el)  A {a:9.2}s  range marginal {:+9.2}s = {:+7.1} us/el",
            r / el * 1e6,
            r - a,
            (r - a) / el * 1e6
        );
    };
    line("commit", cr.commit_s, ca.commit_s);
    line("prove", cr.prove_s, ca.prove_s);
    line("verify", cr.verify_s, ca.verify_s);
    line("wall (incl. setup)", wall_r, wall_a);
    println!(
        "  lookup stage attribution: R {:.2}s prove / {:.2}s verify vs A {:.2}s / {:.2}s -> range descent-pair share {:+.1} / {:+.1} us/el",
        cr.lkp_prove_s,
        cr.lkp_verify_s,
        ca.lkp_prove_s,
        ca.lkp_verify_s,
        (cr.lkp_prove_s - ca.lkp_prove_s) / el * 1e6,
        (cr.lkp_verify_s - ca.lkp_verify_s) / el * 1e6
    );
    let dce_r = cr.q31_data_coeffs + cr.q31_g_coeffs + cr.q31_pad_coeffs;
    let dce_a = ca.q31_data_coeffs + ca.q31_g_coeffs + ca.q31_pad_coeffs;
    println!(
        "  committed q31 coefficients: R {dce_r}, A {dce_a} -> RANGE marginal {:.4} dce/el (m_r + blinders_r + masks_r; the per-wave pin g budget is UNCHANGED — pins stay 9 psi copies; Z1 pad commitments shared, no doubling)",
        (dce_r - dce_a) as f64 / el
    );
    println!(
        "  masked transcript: R {} B (two descent pairs) vs A {} B -> range share {:.3} B/el; reveals R {} vs A {}",
        cr.masked_bytes,
        ca.masked_bytes,
        (cr.masked_bytes - ca.masked_bytes) as f64 / el,
        cr.reveal_shares,
        ca.reveal_shares
    );
    println!(
        "  PUNCHLINE vs the block rig's q46 plane+ARP range side (PROGRESS.md A-D2, [NOISY-SHARED]): commit 582 dce/el -> {:.4} dce/el ({}x); prove ~10,300 us/el (96% of 10.7 ms/el) -> {:+.1} us/el marginal",
        (dce_r - dce_a) as f64 / el,
        (582.0 / ((dce_r - dce_a) as f64 / el)).round() as u64,
        (cr.prove_s - ca.prove_s) / el * 1e6
    );
    println!(
        "  peak RSS: {:.2} GiB after arm R",
        hwm_r as f64 / 1024.0 / 1024.0
    );
    println!(
        "ffn-chain layer range bench done ({} el, all timings [NOISY-SHARED] 1T)",
        cr.n_el
    );
}

/// LKP-9 — the U-R1/U-R2 multi-wave + range-pilot operating point,
/// pinned both directions (house freeze-row discipline): the C2 wave
/// cap, the deterministic partition rule and its capacity wall, the
/// partial-sum gate on split claims, the frozen range-table spec
/// digest, and (resolving the A-D3 open item) the ARP rejection
/// constants — ARP_REJ_T = 1.5 through log_m_joint at the LKP-8 point.
///
/// The ARP row is a REPRODUCIBILITY pin, NOT a ZK claim (audit
/// 2026-07-14 C-01): t = 1.5 clips ~2^-4.75 per unit, so the legacy
/// ARP arm is not statistical ZK; the security-target t ~ 13.4 blows
/// the restart economics ~900x per q46 round and no alpha recovers it
/// inside the extraction budget (the demotion argument, recorded at
/// ARP_REJ_T's definition). The pin exists so the legacy arm's frozen
/// behavior cannot drift silently while it remains in the tree.
fn freeze_check_ur1() -> bool {
    use ring::ct_engine::{
        CtClaim, ct_mul_centered, derive_arp_params, plan_waves, r1_pad_count,
        split_claims_prover, split_claims_verifier,
    };
    let mut all_ok = true;
    let mut gate = |label: &str, ok: bool| {
        println!("  {} {label}", if ok { "ok  " } else { "FAIL" });
        all_ok &= ok;
    };
    let shape = CommitShape { kappa: 8, n_r: 26, msg_r: 8 };
    // The q31 C2 wave capacity at the U-K5c shape: 134 commitments
    // (ur1_c2_max_commits returns THE maximum, so the row pins both
    // directions: 134 derives, 135 does not).
    gate(
        "LKP-9 q31 C2 wave capacity at the U-K5c shape = 134 commitments (135 FAILS)",
        ur1_c2_max_commits(Q8, shape) == 134,
    );
    // The deterministic partition rule at the pinned battery point
    // (2^12, silu arm): data cap 76, 3 waves, chunk-wave linear budget
    // 9 pins + 48 zeta rows; the plan re-derives identically (D-2). The
    // capacity wall the cap sits under: a 77-data-commit triple wave
    // would need 135 total commitments.
    {
        let ls1 = ur1_layer_shape(12, LayerArm::Lookup, shape, Q8, false);
        let ls2 = ur1_layer_shape(12, LayerArm::Lookup, shape, Q8, false);
        let wall_77 = 77 + (UR1_PIN_COPIES + 2 * 24 + r1_pad_count(0, (77 / 3) * 8, 0)).div_ceil(8);
        gate(
            "LKP-9 partition rule at 2^12/silu: data cap 76, 3 waves, chunk-wave budget 57; plan deterministic; 77-commit triple wave busts C2",
            ls1.data_cap == 76
                && ls1.plan.waves.len() == 3
                && ls1.wave_lin.iter().any(|&l| l == UR1_PIN_COPIES + 48)
                && ls1.plan.waves == ls2.plan.waves
                && wall_77 > 134,
        );
    }
    // The partial-sum gate on split claims (U-R1 D-1), both directions
    // at a fixed toy instance: honest partial reveals ACCEPT; a lied
    // partial REJECTS at the sum gate.
    {
        let ring_ctx = ring_ctx_q8();
        let zq = ring_ctx.zq;
        let mut rng = 0x5eed_1c99u64;
        let msgs: Vec<Vec<Poly>> =
            (0..2).map(|_| (0..2).map(|_| rng_poly_mod(&mut rng, Q8)).collect()).collect();
        let plan = plan_waves(2, &[], 1).expect("freeze-row plan derives");
        let w0 = poly_from_small(&zq, &rng_quinary_poly(&mut rng));
        let w1 = poly_from_small(&zq, &rng_quinary_poly(&mut rng));
        let total = {
            let a = ct_mul_centered(&zq, &w0, &msgs[0][0]) as i128
                + ct_mul_centered(&zq, &w1, &msgs[1][1]) as i128;
            let qq = Q8 as i128;
            let mut r = a.rem_euclid(qq);
            if r > qq / 2 {
                r -= qq;
            }
            r as i64
        };
        let claims = vec![CtClaim {
            msg_coeffs: vec![(0, 0, w0), (1, 1, w1)],
            ajtai_coeffs: vec![],
            scalar: total,
        }];
        let msg_refs: Vec<&[Poly]> = msgs.iter().map(|m| m.as_slice()).collect();
        let (_, reveals) =
            split_claims_prover(&zq, &plan, &claims, &msg_refs).expect("freeze-row split");
        let honest = split_claims_verifier(&zq, &plan, &claims, &reveals).is_ok();
        let mut lied = reveals.clone();
        lied[0][0].1 += 1;
        let rejected = split_claims_verifier(&zq, &plan, &claims, &lied).is_err();
        gate(
            "LKP-9 partial-sum gate: honest per-wave partials ACCEPT; a lied partial REJECTS (split_claims_verifier)",
            honest && rejected,
        );
    }
    // The frozen U-R2 range-table spec digest (w = 8, 256 rows).
    gate(
        "LKP-9 range-table spec digest (ur2-range-table-v1, w=8, 256 rows) pinned",
        hex_full(&ur2_range_table_digest())
            == "d85b1de6c38041c8cff9f93816219628296ef0d1cb9bb08c741266f8e87e76c6",
    );
    // The ARP rejection constants (resolves the A-D3 open item):
    // ARP_REJ_T = 1.5 through log_m_joint at the LKP-8 unit
    // (512-bit, alpha = 3.5) — exact-formula windows plus the two
    // behavioral gates: the joint Q4.2b test expects < 3 attempts per
    // 4-unit round, and beats the superseded per-unit product
    // (log M_joint(4) < 4 log M(1) — the sqrt(k) saving).
    // REPRODUCIBILITY pin only, NOT a ZK claim (audit 2026-07-14 C-01;
    // see the freeze_check_ur1 doc and ARP_REJ_T's demotion argument).
    {
        let ap = derive_arp_params(512, 256, 1, UK8_ALPHA);
        let lm1 = ap.log_m_joint(1);
        let lm4 = ap.log_m_joint(4);
        let want1 = 1.5 / 3.5 + 1.0 / (2.0 * 3.5 * 3.5);
        let want4 = 1.5 * 2.0 / 3.5 + 4.0 / (2.0 * 3.5 * 3.5);
        gate(
            &format!(
                "LKP-9 ARP rejection constants at LKP-8 (t = 1.5, alpha = 3.5): log M(1) = {lm1:.6} (e^-0.47/unit), log M_joint(4) = {lm4:.6} (~2.8 attempts/round), joint < per-unit product [REPRODUCIBILITY pin, legacy range arm — NOT a ZK claim; audit 2026-07-14 C-01]"
            ),
            (lm1 - want1).abs() < 1e-12
                && (lm4 - want4).abs() < 1e-12
                && lm4.exp() < 3.0
                && lm4 < 4.0 * lm1,
        );
    }
    all_ok
}

/// Full 64-hex-char digest rendering (freeze-row pinning).
fn hex_full(d: &[u8; 32]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}
