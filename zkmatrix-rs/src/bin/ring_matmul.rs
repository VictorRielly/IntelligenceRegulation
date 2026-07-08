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
        prove_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &openings, &[], &[], n_wit, &mut rng_a);
    assert_true(
        &format!("[{label}] ct-round verifies, {l} theta claims (attempts = {attempts})"),
        verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &t1s, &t2s, &[], &[], &[], n_wit, &proof),
    );
    assert_true(
        &format!("[{label}] ct-round verifies on the schoolbook path"),
        verify_ct_round(&school, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &t1s, &t2s, &[], &[], &[], n_wit, &proof),
    );
    let (proof_s, attempts_s) =
        prove_ct_round(&school, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &openings, &[], &[], n_wit, &mut rng_b);
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
        verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, claims, &[], &t1s, &t2s, &[], &[], &[], n_wit, p)
    };
    let clone_proof = |p: &ring::ct_engine::CtRoundProof| ring::ct_engine::CtRoundProof {
        h: p.h.clone(),
        w1: p.w1.clone(),
        w1_ajtai: p.w1_ajtai.clone(),
        w_claim: p.w_claim.clone(),
        w_ring: p.w_ring.clone(),
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
        !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0_bad, &claims, &[], &t1s, &t2s, &[], &[], &[], n_wit, &proof),
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
        &a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &openings, &[], &[ajtai_open], n_wit, &mut rng,
    );
    assert_true(
        &format!("ARP: 256 JL ct-claims verify (attempts = {attempts})"),
        verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &claims, &[], &t1s, &t2s, &[], &[], &[&acom], n_wit, &proof),
    );
    // Tampered reveal: claims built with a shifted y must fail.
    let mut y_bad = y.clone();
    y_bad[0] += 1;
    let bad_claims = arp_claims(&zq, &ap, &jl, &msg_slots, 0, &y_bad);
    assert_true(
        "ARP tampered reveal y fails (ct check)",
        !verify_ct_round(&a1_path, &ring_ctx, &rp, None, &crs, &h0, &bad_claims, &[], &t1s, &t2s, &[], &[], &[&acom], n_wit, &proof),
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
            ring::ct_engine::RingClaim { msg_coeffs }
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
        path, ring_ctx, rp, Some(dp), crs, &h0, &[], &claims, &[], &digits, &[], 0, rng,
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
            self_test_ct_engine();
            self_test_pi1();
            println!("\nself-test passed in {:.2}s", t.elapsed().as_secs_f64());
        }
        _ => usage(),
    }
}
