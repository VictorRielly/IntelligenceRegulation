// gadget_link_spike: standalone mechanics prototype for the modulus link
// of GADGET_MODULUS_DECISION.md Section 3 (option (a): q46 bit
// commitments <-> q31 value commitments) — the machinery shared with the
// trace gate's Q-A4.
//
// SCOPE, stated exactly: this bin prototypes the INTEGER-LINK SOUNDNESS
// MECHANICS only — the w_max non-overflow rule, the double ct-assertion
// residue algebra, the per-row 2^-w catch probability for nonzero
// difference vectors (including the pre-committed-g-shift adversary),
// and the load-bearing range gate. It carries NO commitments, openings
// or masks: those layers are the ct-engine's, unchanged by the link.
//
// Standalone by design: no `#[path]` includes of ring/*, no test-suite
// hooks. Run manually:
//   PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" \
//     cargo run --release --bin gadget_link_spike
// Exit code 0 = every check holds.

const Q31: i128 = 2_147_483_249; // q8_31 = 2^31 - 399
const Q46: i128 = 70_368_744_176_561; // q8_46 = 2^46 - 1103
const W_BITS: u32 = 12; // range width of the quantized spec

static mut FAILURES: u32 = 0;

fn check(label: &str, ok: bool) {
    println!("  {} {label}", if ok { "ok  " } else { "FAIL" });
    if !ok {
        unsafe { FAILURES += 1 };
    }
}

fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e37_79b9_7f4a_7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^ (z >> 31)
}

/// Signed uniform w-bit weight: 2^w values in [-2^(w-1), 2^(w-1) - 1]
/// (max point mass of xi * delta mod prime q is exactly 2^-w for
/// delta != 0).
fn xi_weight(rng: &mut u64, w: u32) -> i64 {
    let half = 1i64 << (w - 1);
    ((splitmix64(rng) % (1u64 << w)) as i64) - half
}

fn modp(x: i128, q: i128) -> i128 {
    ((x % q) + q) % q
}

/// w_max rule: largest w with n * 2^(w-1) * (2^W - 1) < q46/2 (the
/// q46-side integer-exactness cap of the decision doc Section 3.3).
fn w_max(n: u64) -> u32 {
    let cap = (Q46 / 2) as f64 / (n as f64 * ((1u64 << W_BITS) - 1) as f64);
    (cap.log2().floor() as u32) + 1
}

fn main() {
    println!("gadget_link_spike: modulus-link soundness mechanics at (q8_31, q8_46)");
    let mut rng = 0x5eed_11a7u64;

    // --- 1. The w_max rule at the decision doc's granularities. ---------
    println!("\n[1] w_max non-overflow rule (n * 2^(w-1) * (2^W - 1) < q46/2)");
    for (name, n) in [("column (msg_r=32)", 4096u64), ("token-block", 2_097_152), ("full FFN tensor", 5_636_096)] {
        let w = w_max(n);
        let worst = n as i128 * (1i128 << (w - 1)) * ((1i128 << W_BITS) - 1);
        let over = n as i128 * (1i128 << w) * ((1i128 << W_BITS) - 1);
        let rows = 256u32.div_ceil(w);
        check(
            &format!("{name}: w_max = {w}, rows = {rows}, worst |y| = 2^{:.1} < 2^{:.1}; w+1 overflows", (worst as f64).log2(), ((Q46 / 2) as f64).log2()),
            worst < Q46 / 2 && over >= Q46 / 2,
        );
    }

    // --- 2. Honest path: double residue assertion at column granularity.
    println!("\n[2] honest path (n = 4096, w = 22, l = 12 rows)");
    let n = 4096usize;
    let w = w_max(n as u64);
    let rows = 256usize.div_ceil(w as usize);
    let vals: Vec<i64> = (0..n).map(|_| (splitmix64(&mut rng) % (1 << W_BITS)) as i64).collect();
    let bits: Vec<Vec<i64>> = (0..W_BITS).map(|i| vals.iter().map(|&v| (v >> i) & 1).collect()).collect();
    let mut all_ok = true;
    let mut max_y: i128 = 0;
    for _l in 0..rows {
        let xi: Vec<i64> = (0..n).map(|_| xi_weight(&mut rng, w)).collect();
        // The revealed integer y = <xi, v>.
        let y: i128 = xi.iter().zip(vals.iter()).map(|(&a, &b)| a as i128 * b as i128).sum();
        max_y = max_y.max(y.abs());
        // q46 side: structured weights xi * 2^i on bit (i, t).
        let mut s46: i128 = 0;
        for (i, plane) in bits.iter().enumerate() {
            for (t, &b) in plane.iter().enumerate() {
                s46 += modp(xi[t] as i128 * (1i128 << i) * b as i128, Q46);
            }
        }
        // q31 side: weights xi on values.
        let s31: i128 = xi.iter().zip(vals.iter()).map(|(&a, &b)| modp(a as i128 * b as i128, Q31)).sum();
        all_ok &= modp(s46, Q46) == modp(y, Q46);
        all_ok &= modp(s31, Q31) == modp(y, Q31);
        all_ok &= y.abs() < Q46 / 2; // the load-bearing range gate
    }
    check(&format!("both residue assertions hold for the same revealed integer y on all {rows} rows"), all_ok);
    check(
        &format!(
            "honest |y| max = 2^{:.1} — inside the load-bearing q46/2 gate (it EXCEEDS q31/2 = 2^30 at this w, as the decision doc's granularity table says: gate on the grounding side only)",
            (max_y as f64).log2()
        ),
        max_y < Q46 / 2 && max_y >= Q31 / 2,
    );

    // --- 3. Catch probability: nonzero difference vectors. --------------
    println!("\n[3] per-row catch probability (2^-w bound), w = 4 for measurability");
    let w_small = 4u32;
    let trials = 1u32 << 17;
    // (a) single nonzero coordinate: delta_t != 0 mod q31.
    let delta_single: i128 = 12_345_678; // arbitrary nonzero mod q31
    let mut miss = 0u32;
    for _ in 0..trials {
        let xi = xi_weight(&mut rng, w_small) as i128;
        if modp(xi * delta_single, Q31) == 0 {
            miss += 1;
        }
    }
    let rate = miss as f64 / trials as f64;
    let bound = (2.0f64).powi(-(w_small as i32));
    check(
        &format!("single-coordinate delta: empirical miss {rate:.5} vs bound 2^-{w_small} = {bound:.5} (ratio {:.2})", rate / bound),
        rate <= 1.25 * bound && rate >= 0.75 * bound, // xi = 0 is the only miss
    );
    // (b) dense random delta over 256 coordinates: mass can only shrink.
    let delta_dense: Vec<i128> = (0..256).map(|_| (splitmix64(&mut rng) % (Q31 as u64)) as i128).collect();
    let mut miss_d = 0u32;
    for _ in 0..trials {
        let s: i128 = delta_dense
            .iter()
            .map(|&d| modp(xi_weight(&mut rng, w_small) as i128 * d, Q31))
            .sum::<i128>();
        if modp(s, Q31) == 0 {
            miss_d += 1;
        }
    }
    let rate_d = miss_d as f64 / trials as f64;
    check(
        &format!("dense random delta: empirical miss {rate_d:.6} <= 1.25 * 2^-{w_small} (convolution shrinks mass)"),
        rate_d <= 1.25 * bound,
    );
    // (c) the pre-committed-g-shift adversary: commit gamma BEFORE xi,
    // succeed iff <xi, delta> = gamma (mod q31). Best strategy: guess the
    // most likely value; still point-mass-bounded.
    let mut best = 0u32;
    for guess in [0i128, delta_single, -delta_single, 2 * delta_single] {
        let mut hit = 0u32;
        let mut r2 = 0xabcd_ef01u64 ^ guess as u64;
        for _ in 0..trials {
            let xi = xi_weight(&mut r2, w_small) as i128;
            if modp(xi * delta_single - guess, Q31) == 0 {
                hit += 1;
            }
        }
        best = best.max(hit);
    }
    let rate_g = best as f64 / trials as f64;
    check(
        &format!("pre-committed g-shift adversary: best empirical success {rate_g:.5} <= 1.25 * 2^-{w_small}"),
        rate_g <= 1.25 * bound,
    );
    // (d) rows compose: l independent rows at w = 4 -> product; verify on
    // a small l that the empirical joint miss is ~2^-(w*l).
    let l_small = 3u32;
    let mut joint_miss = 0u32;
    for _ in 0..trials {
        let mut all_zero = true;
        for _ in 0..l_small {
            let xi = xi_weight(&mut rng, w_small) as i128;
            if modp(xi * delta_single, Q31) != 0 {
                all_zero = false;
            }
        }
        if all_zero {
            joint_miss += 1;
        }
    }
    let exp_joint = (2.0f64).powi(-((w_small * l_small) as i32));
    check(
        &format!("{l_small} independent rows: joint miss {:.2e} vs 2^-{} = {exp_joint:.2e}", joint_miss as f64 / trials as f64, w_small * l_small),
        (joint_miss as f64 / trials as f64) <= 4.0 * exp_joint + 4.0 / trials as f64,
    );

    // --- 4. The range gate is load-bearing. ------------------------------
    println!("\n[4] range-gate necessity (a +q46-shifted reveal)");
    {
        let n4 = 64usize;
        let vals4: Vec<i64> = (0..n4).map(|_| (splitmix64(&mut rng) % (1 << W_BITS)) as i64).collect();
        let xi: Vec<i64> = (0..n4).map(|_| xi_weight(&mut rng, w_max(n4 as u64).min(20)) as i64).collect();
        let y: i128 = xi.iter().zip(vals4.iter()).map(|(&a, &b)| a as i128 * b as i128).sum();
        let y_shift = y + Q46; // same residue mod q46, different integer
        let s46: i128 = xi.iter().zip(vals4.iter()).map(|(&a, &b)| modp(a as i128 * b as i128, Q46)).sum();
        check(
            "shifted y' = y + q46 passes the q46 residue check (residues cannot pin the integer)",
            modp(s46, Q46) == modp(y_shift, Q46),
        );
        check(
            "shifted y' fails ONLY the |y| < q46/2 gate — the gate is load-bearing",
            y_shift.abs() >= Q46 / 2 && y.abs() < Q46 / 2,
        );
        // And the q31 side would then be asserted against the WRONG
        // integer: the shift changes y mod q31 (q46 mod q31 != 0).
        check(
            "the +q46 shift changes y mod q31 (cross-modulus binding of the same integer)",
            modp(y_shift, Q31) != modp(y, Q31),
        );
    }

    let failures = unsafe { FAILURES };
    if failures == 0 {
        println!("\ngadget_link_spike: all checks passed");
    } else {
        println!("\ngadget_link_spike: {failures} check(s) FAILED");
        std::process::exit(1);
    }
}
