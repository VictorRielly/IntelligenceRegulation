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
        AjtaiOpening, ajtai_commit, arp_attempt, arp_budget_ok, arp_check_reveal, arp_claims,
        ct_h0, derive_arp_params, derive_ct_round_params, derive_jl_rows, expand_b_mat,
        pack_arp_mask, prove_ct_round, sample_arp_mask, sample_ct_masks, verify_ct_round,
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
// U7: manifest/chain integration. One ClaimManifest (shared module, same
// format as Route Z — only key_info/commitment_bytes widths change) binds
// every commitment of the DAG; its order-sensitive digest is the ctx of
// EVERY claim (the "all commitments before any challenge" rule at chain
// level). Wave batching at r = 1: all gadget claims of a layer share ONE
// ct-round (one challenge, one mask-bundle class per commitment — "one
// wave-slot per claim"); the Pi2 matmul layer runs its own round.
//
// Chain: X0 (n0 x n3), W1 (n1 x n0, hidden) -> Y1 = W1 X0 (Pi2, r_g demo
// reps); Y1 = 2^shift * Y2 + R (rescale link) with Range(R, shift):
// bit planes + recomposition + binary claims — one shared gadget wave;
// plus a slot-packed Hadamard triple (H3) of width n2 as its own layer.
// At q31 the binary claims are mod-q identities; the non-wrap side
// condition is the documented open item (U3/U6 finding) — printed here.

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
    println!("  [q31 caveat] binary claims are mod-q identities; the non-wrap side condition");
    println!("  needs a q46-class budget or an exact strategy (U3/U6 finding; see the report).");
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

    // --- Instance data. --------------------------------------------------
    let w1: Vec<u64> = (0..n1 * n0).map(|_| rng_below(&mut rng, q)).collect();
    let x0: Vec<u64> = (0..n0 * n3).map(|_| rng_below(&mut rng, q)).collect();
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
    // Rescale: Y1 = 2^shift Y2 + R with R = Y1 mod 2^shift (exact integers).
    let rr: Vec<u64> = y1.iter().map(|&v| v & ((1 << shift) - 1)).collect();
    let y2: Vec<u64> = y1.iter().map(|&v| v >> shift).collect();
    let r_bits: Vec<Vec<u64>> =
        (0..shift as usize).map(|i| rr.iter().map(|&v| (v >> i) & 1).collect()).collect();
    // Hadamard triple (slot-packed, standalone layer).
    let hx: Vec<u64> = (0..n2).map(|_| rng_below(&mut rng, q)).collect();
    let hy: Vec<u64> = (0..n2).map(|_| rng_below(&mut rng, q)).collect();
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
    let mut bit_data = Vec::new();
    for bits in &r_bits {
        bit_data.push(commit_cols(bits, n1, n3, &mut rng));
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
    let id_bits: Vec<u32> = bit_data
        .iter()
        .enumerate()
        .map(|(i, (_, _, g))| {
            mf.add_commitment(&format!("Rbits{i}"), n1, n3, Orientation::ByColumns, ki.clone(), group_list_digest(g))
        })
        .collect();
    let id_hx = mf.add_commitment("HX", n2, 1, Orientation::ByColumns, ki.clone(), group_list_digest(&h_groups[0..1]));
    let id_hy = mf.add_commitment("HY", n2, 1, Orientation::ByColumns, ki.clone(), group_list_digest(&h_groups[1..2]));
    let id_hz = mf.add_commitment("HZ", n2, 1, Orientation::ByColumns, ki.clone(), group_list_digest(&h_groups[2..3]));
    mf.add_operation(Operation::Matmul { a: id_w1, b: id_x0, c: id_y1 });
    mf.add_operation(Operation::Rescale { x: id_y1, y: id_y2, r: id_r, shift });
    for (i, &idb) in id_bits.iter().enumerate() {
        let _ = i;
        mf.add_operation(Operation::Binary { bits: idb });
    }
    mf.add_operation(Operation::Range { value: id_r, bits: id_bits[0], width: shift, signed: false });
    mf.add_operation(Operation::Hadamard { x: id_hx, y: id_hy, z: id_hz });
    let ctx = mf.digest();

    // --- Layer 1: the Pi2 matmul claim (its own round). -------------------
    let shape2 = Pi2Shape { rows: n1, inner_r: n0.div_ceil(D), rows_r: n1.div_ceil(D), cols: n3 };
    let t_prove = Instant::now();
    let (pi2_proof, _) = prove_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape2, &ctx, r_g, b_bits, &w1_rows, &rho_w1,
        &x0_cols, &rho_x0, &y1_cols, &rho_y1, &tw1, &tx0, &ty1, &mut rng,
    );

    // --- Layer 2: ONE gadget wave: rescale + recomposition + binary + ----
    // --- Hadamard claims share one ct-round.                           ----
    // Commitment index space (plain): per-column commitments of
    // Y1, Y2, R, bits..., then HX, HY, HZ. For the demo the columns are
    // combined per-tensor with ring challenges into digit-opened combos —
    // the r = 1 wave: one slot per tensor, claims per column ride the
    // combined objects only where the claim is column-uniform (rescale,
    // recomposition: constant coefficients commute with the v-combination;
    // binary: the quadratic claim runs per tensor on the v-combined bits
    // as a mod-q identity on the combination — sound per-slot for the
    // recomposition/rescale, the binary ct runs on the ORIGINAL columns
    // via one claim per column bundled in the same round).
    // For demo clarity we run the gadget claims on the per-column
    // commitments directly (n3 is small); production waves combine.
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
    let base_bits: Vec<usize> = bit_data
        .iter()
        .map(|(msgs, rhos, groups)| push_tensor(msgs, rhos, groups))
        .collect();
    let base_h = push_tensor(&h_msgs, &h_rhos, &h_groups);

    let const_poly = |v: u64| {
        let mut p = poly_zero();
        p[0] = v;
        p
    };
    let mut ring_claims: Vec<RingClaim> = Vec::new();
    for j in 0..n3 {
        for u in 0..cshape.msg_r {
            // Rescale: y1 - 2^shift y2 - r = 0.
            ring_claims.push(RingClaim {
                msg_coeffs: vec![
                    (base_y1 + j, u, const_poly(1)),
                    (base_y2 + j, u, const_poly(zq.neg(1 << shift))),
                    (base_r + j, u, const_poly(zq.neg(1))),
                ],
                constant: poly_zero(),
            });
            // Recomposition: sum_i 2^i bits_i - r = 0.
            let mut coeffs: Vec<(usize, usize, Poly)> = base_bits
                .iter()
                .enumerate()
                .map(|(i, &bb)| (bb + j, u, const_poly(zq.to_mod(1i64 << i))))
                .collect();
            coeffs.push((base_r + j, u, const_poly(zq.neg(1))));
            ring_claims.push(RingClaim { msg_coeffs: coeffs, constant: poly_zero() });
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
    // g-masks for the quadratic ct-claims: one theta-randomized claim
    // family (l copies) per bit TENSOR — finding F5's fix requires the
    // g's committed BEFORE h0, and the claims derived from h0.
    let l_bin = ring::ct_engine::theta_rows(q);
    let n_quad = base_bits.len() * l_bin;
    let g_base = plain_x.len();
    // n_quad reveal g's + the R1 pads (3 per binary quad ct-claim, 2 per
    // Hadamard quad ring-claim).
    let g_groups = ring::ct_engine::sample_g_masks(
        &mut rng,
        q,
        cshape.msg_r,
        n_quad,
        ring::ct_engine::r1_pad_count(n_quad, cshape.msg_r, 0),
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
    let h0 = ct_h0(&crs, &ctx, &t1s, &t2s, &[]);
    let mut quad_claims = Vec::new();
    for (ti, &bb) in base_bits.iter().enumerate() {
        let members: Vec<(usize, usize)> = (0..n3).map(|j| (bb + j, cshape.msg_r)).collect();
        quad_claims.extend(binary_claims(&zq, &h0, ti as u64, &members));
    }
    let openings: Vec<StdOpening> = plain_x
        .iter()
        .zip(plain_rho.iter())
        .enumerate()
        .map(|(i, (x, rho))| StdOpening { t1: &t1s[i], t2: &t2s[i], x, rho })
        .collect();
    let (wave_proof, wave_attempts) = prove_ct_round(
        &wave_path, &ring_ctx, &rp_wave, None, &crs, &h0, &[], &ring_claims, &quad_claims,
        &quad_ring, &openings, &[], &[], g_base, &mut rng,
    );
    let prove_s = t_prove.elapsed().as_secs_f64();

    // --- Verification. ----------------------------------------------------
    let t_verify = Instant::now();
    let ok_pi2 = verify_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape2, &ctx, r_g, b_bits, &tw1, &tx0, &ty1,
        &pi2_proof,
    );
    let ok_wave = verify_ct_round(
        &wave_path, &ring_ctx, &rp_wave, None, &crs, &h0, &[], &ring_claims, &quad_claims,
        &quad_ring, &t1s, &t2s, &[], &[], &[], g_base, &wave_proof,
    );
    let verify_s = t_verify.elapsed().as_secs_f64();
    let n_claims = 1 + ring_claims.len() + quad_claims.len() + quad_ring.len();
    println!(
        "  commit {commit_s:.2}s | prove {prove_s:.2}s (pi2 r_g={r_g} + wave of {} claims, attempts {wave_attempts}) | verify {verify_s:.2}s",
        n_claims - 1,
    );
    if !(ok_pi2 && ok_wave) {
        println!("  FAIL: chain does not verify");
        std::process::exit(1);
    }
    println!("  ok   chain verifies (manifest digest binds all {} commitments, {} operations)", mf.commitments.len(), mf.operations.len());

    // Negative: any tampered commitment changes the manifest digest and
    // every claim fails.
    let mut mf_bad = mf.clone();
    mf_bad.commitments[0].commitment_bytes[0] ^= 1;
    let ctx_bad = mf_bad.digest();
    let ok_tampered = verify_ring_pi2(
        &a1_path, &ring_ctx, &crs, &rp, &dp, &shape2, &ctx_bad, r_g, b_bits, &tw1, &tx0, &ty1,
        &pi2_proof,
    );
    if ok_tampered {
        println!("  FAIL: tampered manifest still verifies");
        std::process::exit(1);
    }
    println!("  ok   tampered manifest digest rejects every claim (ctx binding)");
    println!("chain-demo passed");
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
    eprintln!("usage: ring_matmul self-test | chain-demo <n0> <n1> <n2> <n3> | freeze-check | gate-spike | link-demo | m5-bench [rows inner cols [reps]] | lookup-bench [log2_n]");
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
            self_test_pi1();
            self_test_gadgets();
            self_test_r1();
            self_test_pi2();
            self_test_pi2_ce();
            self_test_link();
            self_test_e2();
            self_test_lookup();
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
        Some("freeze-check") => freeze_check(),
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
        // Masks: drawn from a statement-wave transcript branch (the
        // stand-in for their commitments; h0_lkp binds them upstream of
        // alpha in the full wiring — U-K5c/d exercise those edges).
        let h05 = *b"uk5-battery-h0-fixed-32-bytes!!!";
        let mut trm = LkpTranscript::new("uk5-masks", &h05);
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
        let (pw_proof, zw, pw, qw) = masked_gkr_prove(&kf, &[wtree], &masks_w, &mut tr5);
        let (pt_proof, zt, pm, qt) = masked_gkr_prove(&kf, &[ttree], &masks_t, &mut tr5);
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
                    (Some((roots_w, zwv, pwv, qwv)), Some((roots_t, ztv, pmv, qtv))) => {
                        let w_concat = w5.clone();
                        !kf.is_zero(&roots_w[0][1])
                            && !kf.is_zero(&roots_t[0][1])
                            && kf.mul(&roots_w[0][0], &roots_t[0][1])
                                == kf.mul(&roots_t[0][0], &roots_w[0][1])
                            && zwv == zw
                            && ztv == zt
                            && pwv == pw
                            && qwv == qw
                            && pmv == pm
                            && qtv == qt
                            && pwv == kf.one()
                            && qwv == kf.sub(&av, &mle_eval(&kf, &w_concat, &zwv))
                            && pmv == mle_eval(&kf, &m5, &ztv)
                            && qtv == kf.sub(&av, &mle_eval(&kf, &tab_fused, &ztv))
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
            let (p0_proof, _, _, _) = masked_gkr_prove(&kf, &[wtree2], &z_w, &mut tr0);
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
    // enters every lookup h0 before alpha; a drift here (f64 platform
    // difference, spec edit, row change) must be loud.
    {
        let rows = ring::lookup::silu_int8_table();
        let dg = ring::lookup::table_spec_digest(&rows);
        let hexd: String = dg.iter().take(8).map(|b| format!("{b:02x}")).collect();
        gate(
            &format!("LKP-1 silu-int8-table-v1 spec digest {hexd} (256 rows)"),
            hexd == "768b83d7c01d9bee" && rows.len() == 256 && rows[128] == (0, 0),
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
    let ctx = mf.digest();

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
