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
        let all_x = [pack8(&xv), pack8(&yv), pack8(&zv)];
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
            &a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &[], &claims, &openings, &[], &[], 3,
            &mut rng,
        );
        assert_true(
            &format!("Hadamard x o y = z verifies (H3, {n_vals} slot values, attempts = {attempts})"),
            verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &[], &[], &[], &claims, &t1s, &t2s, &[], &[], &[], 3, &proof),
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
                &[], &[], 3, &mut rng,
            );
            assert_true(
                "Hadamard wrong product fails",
                !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0b, &[], &[], &[], &claims, &t1s_bad, &t2s_bad, &[], &[], &[], 3, &bad),
            );
        }
    }

    // --- B: the binary gadget at q46 (where the ARP budget closes). -----
    println!("\n[U6b] binary gadget (quadratic ct-claim + ARP side condition) at q8_46");
    {
        use ring::ct_engine::{
            AjtaiOpening, ajtai_commit, arp_attempt, arp_budget_ok, arp_claims, derive_arp_params,
            derive_jl_rows, expand_b_mat, pack_arp_mask, sample_arp_mask, sample_ct_masks,
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
        // g's: 256 ARP ct-claims + 1 quadratic binary claim.
        let n_claims_g = ap.rows + ring::ct_engine::theta_rows(q);
        let g_groups = sample_ct_masks(&mut rng, q, shape.msg_r, n_claims_g);
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
            QuadCtClaim, StdOpening, ct_h0, derive_ct_round_params, prove_ct_round,
            sample_ct_masks, theta_rows, verify_ct_round,
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
            let mut g_groups = sample_ct_masks(&mut rng, q, shape.msg_r, 1);
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
            let mut g_groups = sample_ct_masks(&mut rng, q, shape.msg_r, l);
            for gi in 0..g_groups.len() {
                for s in 0..shape.msg_r {
                    g_groups[gi][s][0] = zq.to_mod(-2); // craft every g's ct
                }
            }
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
    use ring::ct_engine::{DigitOpening, prove_ct_round, sample_ct_masks};
    let zq = &ring_ctx.zq;
    let msg_r = crs.shape.msg_r;

    // g-masks (one per gate repetition), committed before challenges.
    let g_groups = sample_ct_masks(rng, crs.q, msg_r, r_g);
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
    if proof.g_t1.len() != r_g.div_ceil(crs.shape.msg_r) || proof.salt > 64 {
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
    let cshape = CommitShape { kappa: p.kappa, n_r: p.n_r, msg_r: p.msg_r };
    let crs = expand_crs(cshape, q, 20_000);
    let dp = derive_digit_params(q, cshape.kappa, cshape.n_r, e_dig, l_dig, w_u.ceil() as i64);
    println!(
        "  params: kappa={} N_r={} msg_r={} gate digits (e={}, L={}), digit sigma=2^{:.1}",
        cshape.kappa, cshape.n_r, cshape.msg_r, e_dig, l_dig, (dp.sigma as f64).log2()
    );
    let g_count = r_g.div_ceil(cshape.msg_r);
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
    let cshape = CommitShape { kappa: p.kappa, n_r: p.n_r, msg_r: p.msg_r };
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
    let rp = derive_ct_round_params(q, cshape, n_gadget_commits + r_g, 0, 0, true);
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
    let g_groups = ring::ct_engine::sample_ct_masks(&mut rng, q, cshape.msg_r, n_quad);
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
    }

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

    // Statement hash binds ALL 12 commitments (0=A 1=B 2=C 3=YA 4=YB
    // 5=YC 6=MA 7=NA 8=MB 9=NB 10=MC 11=NC); the full-entropy psi
    // challenges derive from it — strictly after the masks.
    let t1s = [
        t1a.clone(), t1b.clone(), t1c.clone(), t1ya.clone(), t1yb.clone(), t1yc.clone(),
        t1ma.clone(), t1na.clone(), t1mb.clone(), t1nb.clone(), t1mc.clone(), t1nc.clone(),
    ];
    let t2s = [
        t2a.clone(), t2b.clone(), t2c.clone(), t2ya.clone(), t2yb.clone(), t2yc.clone(),
        t2ma.clone(), t2na.clone(), t2mb.clone(), t2nb.clone(), t2mc.clone(), t2nc.clone(),
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
    ];
    let rhos = [
        rhoa.clone(), rhob.clone(), rhoc.clone(), rhoya.clone(), rhoyb.clone(), rhoyc.clone(),
        rhoma.clone(), rhona.clone(), rhomb.clone(), rhonb.clone(), rhomc.clone(), rhonc.clone(),
    ];
    let n_com = 12usize;
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
        &openings, &[], &[], n_com, &mut rng,
    );
    let prove_ms = t0.elapsed().as_secs_f64() * 1e3;
    let t1v: Vec<Vec<Poly>> = t1s.to_vec();
    let t2v: Vec<Vec<Poly>> = t2s.to_vec();
    let tvr = Instant::now();
    let ok = verify_ct_round_tq(
        &path, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[], &gate_claims, &t1v,
        &t2v, &[], &[], &[], n_com, &proof,
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
        &gate_claims, &openings, &[], &[], n_com, &mut rng_school,
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
        verify_ct_round_tq(&KernelPath::School, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[], &gate_claims, &t1v, &t2v, &[], &[], &[], n_com, &proof),
    );

    // U-B3 junk-injection: every prover-supplied image is load-bearing —
    // tampering any of (Ga, Gb, G0, W_tq, W_ring) must be rejected.
    let reverify = |p: &ring::ct_engine::CtRoundProof| -> bool {
        verify_ct_round_tq(&path, &ring_ctx, &rp, None, &crs, &h0f, &[], &tie_claims, &[], &[], &gate_claims, &t1v, &t2v, &[], &[], &[], n_com, p)
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
    println!("  CE gate + tie round ~{kb:.0} KB (r = 1; 12 commitments incl. 3 executions + 6 tie masks, 3 F reveals, 6 tie claims + 1 twisted quad claim)");
    // The MARGINAL cost of gate + tie (what Appendix B prices): the 3 Y
    // and 6 mask objects, the F reveals, and the claim images; A/B/C
    // commitments and openings exist anyway.
    let obj_com_kb = 9.0 * (cshape.kappa + cshape.msg_r) as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    let obj_z_kb = 9.0 * cshape.n_r as f64 * D as f64 * sigma_bits / 8.0 / 1024.0;
    let f_kb = 3.0 * h as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    let img_kb = (4 + 6) as f64 * D as f64 * 31.0 / 8.0 / 1024.0;
    println!(
        "  CE gate + tie marginal ~{:.0} KB (9 commitments {obj_com_kb:.0} + 9 openings {obj_z_kb:.0} + F reveals {f_kb:.0} + claim images {img_kb:.0})",
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
        let t1n = [t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t110, t111];
        let t2n = [t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t210, t211];
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
        let xn = [x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11];
        let rhon = [rho0, rho1, rho2, rho3, rho4, rho5, rho6, rho7, rho8, rho9, rho10, rho11];
        let opn: Vec<StdOpening> = (0..n_com)
            .map(|i| StdOpening { t1: &t1n[i], t2: &t2n[i], x: &xn[i], rho: &rhon[i] })
            .collect();
        let (proof_n, _) = prove_ct_round_tq(
            &path, &ring_ctx, &rp, None, &crs, &h0fn, &[], &ties, &[], &[], &gates, &opn, &[],
            &[], n_com, &mut rng,
        );
        let t1nv: Vec<Vec<Poly>> = t1n.to_vec();
        let t2nv: Vec<Vec<Poly>> = t2n.to_vec();
        verify_ct_round_tq(
            &path, &ring_ctx, &rp, None, &crs, &h0fn, &[], &ties, &[], &[], &gates, &t1nv,
            &t2nv, &[], &[], &[], n_com, &proof_n,
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
    eprintln!("usage: ring_matmul self-test | chain-demo <n0> <n1> <n2> <n3> | freeze-check | gate-spike | link-demo");
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
            self_test_pi2();
            self_test_pi2_ce();
            self_test_link();
            println!("\nself-test passed in {:.2}s", t.elapsed().as_secs_f64());
        }
        Some("chain-demo") if args.len() == 5 => {
            let dims: Vec<usize> = args[1..5].iter().map(|s| s.parse().expect("dim")).collect();
            chain_demo(dims[0], dims[1], dims[2], dims[3]);
        }
        Some("freeze-check") => freeze_check(),
        Some("gate-spike") => gate_spike(),
        Some("link-demo") => {
            let t = Instant::now();
            self_test_link();
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
    all_ok
}
