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
use ring::{
    D, Poly, Q8, RingCtx, XofReader, crt_merge, crt_split, ct_coeff, digit_decompose,
    digit_split_witness, ls18_margin, poly_add, poly_conj, poly_from_small, poly_inv_g,
    poly_mul_g, poly_mul_small, poly_zero, polys_bytes, ring_ctx_q8, ring_matvec_small_g,
    ring_mul_split, ring_mul_split_kara_fast, rng_below, rng_ternary_poly, splitmix64,
    vec_norm_sq_i64,
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
            println!("self-test passed in {:.2}s", t.elapsed().as_secs_f64());
        }
        _ => usage(),
    }
}
