//! REFUSAL-SITE PARITY, site by site (stage S3a; the security owner's answer 1
//! of 2026-09-19 in `ZK60_PRIVATE_BLOCK_IMPL_PROGRESS.md`).
//!
//! `parity.rs` sweeps 1,200 generated cases and reaches nine of the kernel's
//! refusal sites. This module closes the list the other way round: for every
//! site that is REACHABLE it hand-builds the smallest public synthetic
//! statement that forces it and asserts that the witness builder refuses at the
//! same site with the same message; for every site that is UNREACHABLE at this
//! calibration it states the bound that makes it unreachable and asserts the
//! bound's premise, instead of forcing the site by bypassing the builder.
//!
//! Everything here is PUBLIC SYNTHETIC test data: constant-filled weight
//! matrices and a constant input, chosen so that the value which reaches the
//! target site can be computed by hand (each case's arithmetic is in its `why`
//! line). No OS randomness, no real model, no real input, nothing written to
//! disk, and no witness value is ever printed — only the site strings, which
//! are static text of the kernel.
//!
//! WHY IT MATTERS, and what it is not. This is not a soundness question: the
//! range proofs refuse an out-of-class witness whatever the builder does. It is
//! condition 6 of the disposition — a site where the witness builder accepts
//! what the kernel refuses, or the reverse, is a place where the proof would
//! speak about a computation the reference does not define.

use super::layout::*;
use super::witness;
use super::{AttentionPublic, FeedForwardPublic};
use private_block_kernel as kern;

/// the RoPE tables' fixed-point one (`2^F_RO`), the largest legal |cos|, |sin|
const ONE_RO: i64 = 1 << F_RO;
/// the largest `ss = ceps + sum x^2` any row can carry, over the int16 class
/// the verifier enforces on `x_in` and on `xres1` (T2 erratum E-4)
const SS_MAX: i64 = NORM_CEPS + (D as i64) * 32768 * 32768;

/// One hand-built public synthetic statement. Every matrix is a CONSTANT fill
/// and the input is a constant, which is what makes each case's arithmetic a
/// one-line product rather than a simulation.
struct Forced {
    /// the kernel refusal site this case must reach, exactly
    site: &'static str,
    /// the arithmetic that forces it (recorded, not executed)
    why: &'static str,
    gamma_a: i8,
    gamma_m: i8,
    /// wq, wk, wv, wo
    w: [i8; 4],
    /// (cos, sin) at every position `t >= 1`; position 0 is pinned to (2^fRo, 0)
    rope: (i64, i64),
    /// wg_t, wu_t, wd_t
    ff: [i8; 3],
    /// every entry of the 256-row activation table
    act: i16,
    /// every word of the private input
    x: i16,
}

struct Built {
    public: AttentionPublic,
    ff: FeedForwardPublic,
    kweights: kern::PublicWeights,
    ktables: kern::PublicTables,
    input: Vec<i16>,
}

impl Forced {
    fn build(&self) -> Built {
        // the exp table is the calibration's own member; nothing here needs it
        // bent, because every softmax site is unreachable (see below)
        let (exp, _) = crate::tables_attn::exp_member(0, DH, F_E);
        let mut cos = vec![self.rope.0; T * HALF];
        let mut sin = vec![self.rope.1; T * HALF];
        for i in 0..HALF {
            cos[i] = ONE_RO;
            sin[i] = 0;
        }
        let (wq, wk, wv, wo) = (vec![self.w[0]; D * D], vec![self.w[1]; KV * D], vec![self.w[2]; KV * D], vec![self.w[3]; D * D]);
        let gamma_a = vec![self.gamma_a; D];
        let gamma_m = vec![self.gamma_m; D];
        let (wg_t, wu_t, wd_t) = (vec![self.ff[0]; D * F], vec![self.ff[1]; D * F], vec![self.ff[2]; F * D]);
        let act = vec![self.act; 256];
        let input = vec![self.x; T * D];
        Built {
            public: AttentionPublic::new(&wq, &wk, &wv, &wo, &gamma_a, &cos, &sin, &exp).expect("forced public statement"),
            ff: FeedForwardPublic::new(&gamma_m, &wg_t, &wu_t, &wd_t, &act).expect("forced feed-forward statement"),
            kweights: kern::PublicWeights::from_slices(&wq, &wk, &wv, &wo, &gamma_a, &gamma_m, &wg_t, &wu_t, &wd_t).expect("forced kernel weights"),
            ktables: kern::PublicTables::from_slices(&cos, &sin, &exp, &act).expect("forced kernel tables"),
            input,
        }
    }
}

/// The twelve REACHABLE sites, each with the arithmetic that forces it.
///
/// Shared background of every case: with a constant input `x` and a constant
/// `gamma`, one RMSNorm row has `ss = 1 + 16 x^2`, `D = isqrt(ss) = 4|x|` for
/// `|x| >= 1`, and `y_i = floor((x gamma + D) / (2 D))`. So `x = 1, gamma =
/// 127` gives `y = floor(131/8) = 16` and `x = -1, gamma = 127` gives
/// `y = floor(-123/8) = -16`; `gamma = 0` gives `y = floor(D/(2D)) = 0`, which
/// is how a case switches the attention half off and drives the feed-forward
/// directly from `xres1 = x`.
const FORCED: [Forced; 12] = [
    Forced {
        site: "Q",
        why: "y = 16; qacc = 16 * 16 * 127 = 32,512; requant(.,7) = 254 leaves [-127, 127]",
        gamma_a: 127,
        gamma_m: 0,
        w: [127, 0, 0, 0],
        rope: (ONE_RO, 0),
        ff: [0, 0, 0],
        act: 0,
        x: 1,
    },
    Forced {
        site: "K",
        why: "q8 = 0 (wq = 0); kacc = 16 * 16 * 127 = 32,512; requant(.,7) = 254",
        gamma_a: 127,
        gamma_m: 0,
        w: [0, 127, 0, 0],
        rope: (ONE_RO, 0),
        ff: [0, 0, 0],
        act: 0,
        x: 1,
    },
    Forced {
        site: "V",
        why: "q8 = k8 = 0; vacc = 16 * 16 * 127 = 32,512; requant(.,7) = 254",
        gamma_a: 127,
        gamma_m: 0,
        w: [0, 0, 127, 0],
        rope: (ONE_RO, 0),
        ff: [0, 0, 0],
        act: 0,
        x: 1,
    },
    Forced {
        site: "QR",
        why: "qacc = 16 * 16 * 63 = 16,128 -> q8 = 126 (in class); at t >= 1 the rope pair is (128, -128), so c a - s b = 128 * 126 + 128 * 126 = 32,256 -> 252",
        gamma_a: 127,
        gamma_m: 0,
        w: [63, 0, 0, 0],
        rope: (ONE_RO, -ONE_RO),
        ff: [0, 0, 0],
        act: 0,
        x: 1,
    },
    Forced {
        site: "KR",
        why: "wq = 0 so qr8 = 0 (in class); k8 = 126 and the same rope pair gives 32,256 -> 252",
        gamma_a: 127,
        gamma_m: 0,
        w: [0, 63, 0, 0],
        rope: (ONE_RO, -ONE_RO),
        ff: [0, 0, 0],
        act: 0,
        x: 1,
    },
    Forced {
        site: "score",
        why: "identity rope keeps qr8 = kr8 = 126; sacc = 8 * 126 * 126 = 127,008; requant(.,6) = 1,984",
        gamma_a: 127,
        gamma_m: 0,
        w: [63, 63, 0, 0],
        rope: (ONE_RO, 0),
        ff: [0, 0, 0],
        act: 0,
        x: 1,
    },
    Forced {
        site: "residual 1",
        why: "x = 32,767 and y = 16; v8 = 126, sum_j p[j] <= 512 so o8 = 126; aoacc = 16 * 126 * 127 = 256,032 -> ao = 2,000; x + ao = 34,767 leaves int16",
        gamma_a: 127,
        gamma_m: 0,
        w: [0, 0, 63, 127],
        rope: (ONE_RO, 0),
        ff: [0, 0, 0],
        act: 0,
        x: 32767,
    },
    Forced {
        site: "FFN gate",
        why: "gamma_a = 0 so xres1 = x = 1; nm = 16; gacc = 16 * 16 * 127 = 32,512; requant(.,7) = 254 leaves [-128, 127]",
        gamma_a: 0,
        gamma_m: 127,
        w: [0, 0, 0, 0],
        rope: (ONE_RO, 0),
        ff: [127, 0, 0],
        act: 0,
        x: 1,
    },
    Forced {
        site: "FFN up",
        why: "xres1 = -1, nm = -16, wg = 0 so g8 = 0; uacc = 16 * (-16) * (-128) = +32,768, one above the int16 class (SH_U = 0, so there is no requantization at all)",
        gamma_a: 0,
        gamma_m: 127,
        w: [0, 0, 0, 0],
        rope: (ONE_RO, 0),
        ff: [0, -128, 0],
        act: 0,
        x: -1,
    },
    Forced {
        site: "FFN product",
        why: "nm = -16, u16 = 16 * (-16) * 127 = -32,512 (in class), a16 = act[128] = 32,767; hacc = -1,065,320,704; requant(.,14) = -65,023 leaves int16",
        gamma_a: 0,
        gamma_m: 127,
        w: [0, 0, 0, 0],
        rope: (ONE_RO, 0),
        ff: [0, 127, 0],
        act: 32767,
        x: -1,
    },
    Forced {
        site: "FFN down",
        why: "u16 = 16 * (-16) * (-64) = 16,384, a16 = 32,767, hacc = 536,854,528 -> h16 = 32,767 (in class); zacc = 16 * 32,767 * 127 = 66,582,544; requant(.,6) = 1,040,352",
        gamma_a: 0,
        gamma_m: 127,
        w: [0, 0, 0, 0],
        rope: (ONE_RO, 0),
        ff: [0, -64, 127],
        act: 32767,
        x: -1,
    },
    Forced {
        site: "residual 2",
        why: "xres1 = 32,767 and nm = 16; u16 = 256, a16 = 32, hacc = 8,192 -> h16 = 1; zacc = 16 * 4 = 64 -> z16 = 1; xres1 + z16 = 32,768 leaves int16",
        gamma_a: 0,
        gamma_m: 127,
        w: [0, 0, 0, 0],
        rope: (ONE_RO, 0),
        ff: [0, 1, 4],
        act: 32,
        x: 32767,
    },
];

/// Every reachable site, forced, with the witness and the kernel refusing at
/// the same site with the same message. A case that ACCEPTS is a failure too:
/// it would mean the hand-built arithmetic no longer reaches the site and the
/// case has silently stopped testing anything.
#[test]
fn every_reachable_refusal_site_is_forced_and_matches_the_kernel() {
    let mut seen: Vec<&str> = Vec::new();
    for f in &FORCED {
        let b = f.build();
        let kernel = kern::run_block_slice(&b.input, &b.kweights, &b.ktables, None);
        let wit = witness::build(&b.public, &b.ff, &b.input);
        let want = format!("fixed oracle range refusal: {}", f.site);
        match (&kernel, &wit) {
            (Err(e), Err(m)) => {
                assert_eq!(format!("{e}"), want, "site `{}`: the kernel refused elsewhere ({})", f.site, f.why);
                assert_eq!(m, &want, "site `{}`: the witness refused elsewhere ({})", f.site, f.why);
            }
            (Ok(_), _) => panic!("site `{}`: the kernel accepted the forcing case ({})", f.site, f.why),
            (Err(e), Ok(_)) => panic!("site `{}`: the witness accepted where the kernel refused ({e})", f.site),
        }
        assert!(!seen.contains(&f.site), "site `{}` is forced twice", f.site);
        seen.push(f.site);
    }
    assert_eq!(seen.len(), 12);
}

// ---------------------------------------------------------------- unreachable

/// The sites no public synthetic input can reach at this calibration, with the
/// bound that makes each unreachable asserted as a premise rather than assumed.
/// Nothing here forces a site by bypassing the builder (the security owner's
/// answer 1: "do not force it by bypassing the generator").
///
/// | site | why it cannot be reached |
/// |---|---|
/// | `norm denominator` (both norms) | `ss = 1 + sum x^2 <= 1 + 16 * 2^30 < 2^35` over the int16 class the verifier enforces on `x_in` (`c2`) and on `xres1` (`c4`), so `ss > 0` and `D = isqrt(ss) <= 2^17`; `den = 2 D 2^11 >= 2^12 > 0`. The witness's own limb window `D, a1, a2 < 2^24` holds too: `a1 = ss - D^2 <= 2D` and `a2 = 2D - a1 <= 2D`, both `<= 2^18`. |
/// | `norm quotient/remainder` (both norms) | `|x_i| <= D` (because `D = isqrt(ceps + sum x^2) >= isqrt(x_i^2) = |x_i|`) and `|gamma| <= 128`, so `q = floor((x_i gamma + D) / (2 D))` lies in `[-64, 64]`, inside `[-127, 127]`; and `rho, sigma < den = D 2^12 <= 2^29`. |
/// | `causal maximum attainment` | the score class is `[-127, 127]` and `MASK = -127` is its minimum, and the masked max takes the FIRST strict maximum, so index 0 (always `<= t`) is chosen over any later masked position of equal value. |
/// | `exp difference` | `delta = max - masked(j) <= 127 - (-127) = 254 < 256`, and `delta >= 0` because `max` is the maximum. |
/// | `softmax denominator` | `total = sum_{j <= t} exp[delta_j]`, with `exp[0] = 2^9` at `j = arg` and every entry in `[0, 2^9]`, so `2^9 <= total <= 32 * 2^9`. |
/// | `softmax quotient/remainder` | `q = floor(e_j 2^9 / total) <= 2^9` since `e_j <= 2^9 <= total`; `sigma = total - 1 - rho` with `rho < total <= 2^14`, so `sigma` is in `[0, 2^14)`. |
/// | `O` | `sum_j p[j] = sum_j floor(e_j 2^9 / total) <= 2^9` and `|v8| <= 127`, so `|oacc| <= 512 * 127 = 65,024` and `requant(.,9)` lands in `[-127, 127]`. |
/// | `AO` | `|o8| <= 127`, `|Wo| <= 128`, 16 terms, so `|aoacc| <= 260,096` and `requant(.,7)` lands in `[-2032, 2032]`, well inside int16. |
#[test]
fn the_unreachable_refusal_sites_have_their_premises() {
    // --- norm denominator, both norms ---
    let d_max = witness::isqrt(SS_MAX as u64) as i64;
    assert!(SS_MAX > 0 && d_max <= 1 << 17, "D exceeds 2^17: {d_max}");
    assert!(d_max < 1 << 24 && 2 * d_max < 1 << 24, "the witness limb window 2^24 is too small for D or a1/a2");
    assert!(2 * (d_max << NORM_TN) > 0, "den is not positive");
    // --- norm quotient/remainder, both norms: rho and sigma stay below 2^29 ---
    assert!((d_max << (NORM_TN + 1)) <= 1i64 << NORM_WRHO, "den exceeds the rho/sigma window");
    // ... and the quotient stays in the int8 subset, for every |x| <= D and
    // every i8 gain. The closed form is [-63.5, 64.5]; this checks it.
    for d in [1i64, 2, 3, 4, 17, 255, 4096, 65535, d_max] {
        for x in [-d, -d + 1, -1, 0, 1, d - 1, d] {
            for g in [-128i64, -127, 0, 127] {
                let (num, den) = (2 * x * g * NORM_CN + (d << NORM_TN), d << (NORM_TN + 1));
                let q = num.div_euclid(den);
                let rho = num.rem_euclid(den);
                assert!((-127..=127).contains(&q), "norm quotient {q} out of class at d={d} x={x} g={g}");
                assert!(rho < 1 << NORM_WRHO && den - 1 - rho < 1 << NORM_WRHO, "norm remainder window");
            }
        }
    }
    // --- causal maximum attainment ---
    assert_eq!(MASK_SCORE, -127, "the mask is no longer the minimum of the score class");
    // --- exp difference ---
    assert!(127 - MASK_SCORE < 256, "the largest exp difference leaves the table");
    // --- softmax denominator, quotient and remainder ---
    let (one_e, one_p) = (1i64 << F_E, 1i64 << F_P);
    for total in [one_e, one_e + 1, 1_000, (T as i64) * one_e] {
        assert!((one_e..=(T as i64) * one_e).contains(&total));
        for e in [0i64, 1, one_e - 1, one_e] {
            let (q, rho) = ((e << F_P) / total, (e << F_P) % total);
            assert!((0..=one_p).contains(&q), "softmax quotient {q} out of class");
            assert!((0..1i64 << WRHO_S).contains(&(total - 1 - rho)), "softmax sigma out of window");
        }
    }
    // --- O: the softmax weights of one row sum to at most 2^fP ---
    let oacc_max = one_p * 127;
    let requant = |acc: i64, sh: u32| (acc + (1i64 << (sh - 1))) >> sh;
    assert!((-127..=127).contains(&requant(oacc_max, SH_O)) && (-127..=127).contains(&requant(-oacc_max, SH_O)), "the PV accumulator can leave the int8 subset");
    // --- AO ---
    let ao_max = (D as i64) * 127 * 128;
    assert!((-32768..=32767).contains(&requant(ao_max, SH_AO)) && (-32768..=32767).contains(&requant(-ao_max, SH_AO)), "the output projection can leave int16");
}

/// The premise the two norm bounds rest on: `sum_j p[j] <= 2^fP` for every
/// admissible softmax row. Checked over the shapes the exp table can produce
/// rather than assumed.
#[test]
fn the_softmax_weights_of_a_row_sum_to_at_most_one() {
    let one_e = 1i64 << F_E;
    for t in [0usize, 1, 7, 31] {
        for shape in 0..4usize {
            let e: Vec<i64> = (0..=t).map(|j| match shape {
                0 => one_e,
                1 => if j == 0 { one_e } else { 1 },
                2 => one_e - (j as i64 % one_e),
                _ => if j % 2 == 0 { one_e } else { one_e / 2 },
            }).collect();
            let total: i64 = e.iter().sum();
            assert!((one_e..=(T as i64) * one_e).contains(&total));
            let sum_p: i64 = e.iter().map(|v| (v << F_P) / total).sum();
            assert!(sum_p <= 1i64 << F_P, "sum of softmax weights {sum_p} exceeds 2^fP at t={t} shape={shape}");
        }
    }
}
