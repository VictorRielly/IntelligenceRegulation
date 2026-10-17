//! Native unit tests. All data here is PUBLIC synthetic test data.
use super::*;
use std::boxed::Box;
use std::vec::Vec;

/// The public weights of `causal_oracle::public_synthetic_fixture`.
fn fixture_weights_raw() -> [Vec<i8>; 9] {
    let mut wq = std::vec![0i8; 256];
    let mut wk = std::vec![0i8; 128];
    let mut wv = std::vec![0i8; 128];
    let mut wo = std::vec![0i8; 256];
    let ga = std::vec![64i8; 16];
    let gm = std::vec![64i8; 16];
    let mut wg = std::vec![1i8; 256];
    let mut wu = std::vec![1i8; 256];
    let mut wd = std::vec![0i8; 256];
    for i in 0..16 {
        wq[i * 16 + i] = 64;
        wo[i * 16 + i] = 64;
        wd[i * 16 + i] = 64;
    }
    for i in 0..8 {
        wk[i * 16 + i] = 64;
        wv[i * 16 + i] = 64;
    }
    wq[3] = 7;
    wq[7 * 16 + 2] = -5;
    wk[5 * 16 + 14] = 9;
    wv[3 * 16 + 11] = -6;
    wo[2 * 16 + 9] = 11;
    wo[11 * 16 + 4] = -7;
    wg[16 + 13] = -4;
    wg[13 * 16 + 1] = 2;
    wu[4 * 16 + 15] = -3;
    wu[15 * 16 + 4] = 5;
    wd[2 * 16 + 11] = 19;
    wd[11 * 16 + 2] = -13;
    [wq, wk, wv, wo, ga, gm, wg, wu, wd]
}

fn weights(r: &[Vec<i8>; 9]) -> PublicWeights {
    PublicWeights::from_slices(&r[0], &r[1], &r[2], &r[3], &r[4], &r[5], &r[6], &r[7], &r[8]).unwrap()
}

fn fixture_input() -> [i16; X_LEN] {
    core::array::from_fn(|i| ((i / D) % 5) as i16 - 2 + (i % 3) as i16 - 1)
}

/// Synthetic (NOT canonical) tables that pass structural validation; a
/// non-trivial rotation for t >= 1 exercises RoPE orientation.
fn synth_tables_raw() -> (Vec<i64>, Vec<i64>, Vec<i64>, Vec<i16>) {
    let mut c = std::vec![0i64; ROPE_LEN];
    let mut s = std::vec![0i64; ROPE_LEN];
    for t in 0..T {
        for i in 0..HALF {
            let at = t * HALF + i;
            if t == 0 {
                c[at] = 128;
            } else {
                c[at] = 128 - 7 * ((t + i) % 5) as i64 - 40;
                s[at] = ((t * 3 + i) % 9) as i64 * 13 - 52;
            }
        }
    }
    let e: Vec<i64> = (0..256u32).map(|d| 512i64 >> (d / 6).min(10)).collect();
    let a: Vec<i16> = (0..256i16).map(|i| (i - 128) * 37 + 11).collect();
    (c, s, e, a)
}

fn synth_tables() -> PublicTables {
    let (c, s, e, a) = synth_tables_raw();
    PublicTables::from_slices(&c, &s, &e, &a).unwrap()
}

struct Lcg(u64);
impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0 >> 33
    }
    fn range(&mut self, amp: i64) -> i64 {
        (self.next() % (2 * amp as u64 + 1)) as i64 - amp
    }
}

// ------------------------------------------------------------ scalar rules

#[test]
fn requant_signed_and_tie_rounding() {
    // Ties go toward +inf (round half up) on both signs.
    assert_eq!(requant(1, 1, "t"), Ok(1)); // 0.5 -> 1
    assert_eq!(requant(-1, 1, "t"), Ok(0)); // -0.5 -> 0
    assert_eq!(requant(3, 1, "t"), Ok(2)); // 1.5 -> 2
    assert_eq!(requant(-3, 1, "t"), Ok(-1)); // -1.5 -> -1
    assert_eq!(requant(6, 2, "t"), Ok(2)); // 1.5 -> 2
    assert_eq!(requant(-6, 2, "t"), Ok(-1)); // -1.5 -> -1
    assert_eq!(requant(-7, 2, "t"), Ok(-2)); // -1.75 -> -2
    assert_eq!(requant(-5, 2, "t"), Ok(-1)); // -1.25 -> -1
    assert_eq!(requant(191, 7, "t"), Ok(1)); // 1.49
    assert_eq!(requant(192, 7, "t"), Ok(2)); // 1.5
    assert_eq!(requant(-192, 7, "t"), Ok(-1)); // -1.5
    assert_eq!(requant(-193, 7, "t"), Ok(-2));
    // Non-positive shift is exact up-scaling.
    assert_eq!(requant(-5, 0, "t"), Ok(-5));
    assert_eq!(requant(-5, -3, "t"), Ok(-40));
    // Balanced remainder window on a sweep.
    for sh in 1..=14 {
        for a in -70000i64..70000 {
            if a % 97 != 0 && a.abs() > 300 {
                continue;
            }
            let y = requant(a, sh, "t").unwrap();
            let r = a - (y << sh);
            let half = 1i64 << (sh - 1);
            assert!((-half..half).contains(&r), "a={a} sh={sh}");
        }
    }
    assert_eq!(requant(i64::MAX, 1, "t"), Err(KernelError::Overflow("t")));
    assert_eq!(requant(1 << 62, -2, "t"), Err(KernelError::Overflow("t")));
    assert_eq!(requant(1, 63, "t"), Err(KernelError::Overflow("t")));
}

#[test]
fn isqrt_boundaries() {
    for k in 0u64..3000 {
        assert_eq!(isqrt(k * k), k);
        assert_eq!(isqrt(k * k + 2 * k), k);
        if k > 0 {
            assert_eq!(isqrt(k * k - 1), k - 1);
        }
    }
    for k in [131071u64, 131072, 131073, (1 << 31) - 1, 1 << 31, (1 << 32) - 1] {
        assert_eq!(isqrt(k * k), k);
        assert_eq!(isqrt(k * k - 1), k - 1);
        assert_eq!(isqrt(k * k + 2 * k), k);
    }
    assert_eq!(isqrt((1 << 34) + 1), 1 << 17);
    assert_eq!(isqrt(u64::MAX), (1 << 32) - 1);
}

fn norm_one_row(row: [i64; D], gamma: i8) -> Res<(i64, [i64; D])> {
    let mut x = [0i64; X_LEN];
    x[..D].copy_from_slice(&row);
    let mut y = [0i64; X_LEN];
    let mut dd = [0i64; T];
    rms_norm(&x, &[gamma; D], &mut y, &mut dd)?;
    Ok((dd[0], y[..D].try_into().unwrap()))
}

#[test]
fn norm_rounding_signs_and_extremes() {
    // x = 3 alone: D = isqrt(9 + 1) = 3, y = 3 g 1024 / (3 2048) = g / 2.
    let mut row = [0i64; D];
    row[0] = 3;
    assert_eq!(norm_one_row(row, 64).unwrap().1[0], 32);
    assert_eq!(norm_one_row(row, 65).unwrap().1[0], 33); // 32.5 -> 33
    assert_eq!(norm_one_row(row, -65).unwrap().1[0], -32); // -32.5 -> -32
    assert_eq!(norm_one_row(row, -64).unwrap().1[0], -32);
    row[0] = -3;
    assert_eq!(norm_one_row(row, 65).unwrap().1[0], -32);
    assert_eq!(norm_one_row(row, -65).unwrap().1[0], 33);
    // Zero row: D = isqrt(Ceps) = 1, y = 0.
    let (d0, y0) = norm_one_row([0; D], 127).unwrap();
    assert_eq!((d0, y0), (1, [0; D]));
    // Extremes never wrap: D = isqrt(2^34 + 1) = 2^17, y = 16.
    let (dm, ym) = norm_one_row([-32768; D], -128).unwrap();
    assert_eq!((dm, ym[0]), (1 << 17, 16));
    let (_, yp) = norm_one_row([32767; D], 127).unwrap();
    assert_eq!(yp[0], 16);
    // One-hot extreme: |y| = |g| 1024 x / (|x| 2048) ~ 64 at g = -128.
    let mut spike = [0i64; D];
    spike[5] = -32768;
    let (_, ys) = norm_one_row(spike, -128).unwrap();
    assert_eq!(ys[5], 64);
    // Random rows against an i128 reference of the same relation.
    let mut rng = Lcg(11);
    for _ in 0..2000 {
        let row: [i64; D] = core::array::from_fn(|_| rng.range(32768).min(32767));
        let g = rng.range(128).min(127) as i8;
        let (d, y) = norm_one_row(row, g).unwrap();
        let sse: i128 = row.iter().map(|v| (*v as i128) * (*v as i128)).sum::<i128>() + 1;
        assert!((d as i128) * (d as i128) <= sse && sse < (d as i128 + 1) * (d as i128 + 1));
        for i in 0..D {
            let num = 2 * row[i] as i128 * g as i128 * 1024 + ((d as i128) << 11);
            assert_eq!(y[i] as i128, num.div_euclid((d as i128) << 12));
        }
    }
}

// ------------------------------------------------------------ attention row

fn exp_table() -> [i64; 256] {
    synth_tables().exp
}

#[test]
fn softmax_first_attainer_and_causality() {
    let e = exp_table();
    let mut s = [0i64; T];
    s[1] = 50;
    s[3] = 50;
    s[6] = 120; // future for t = 5: must be ignored
    let r = softmax_row(&s, 5, &e).unwrap();
    assert_eq!((r.max, r.arg), (50, 1));
    assert!(r.p[6..].iter().all(|p| *p == 0));
    assert_eq!(r.p[1], r.p[3]);
    // All real scores equal the mask value: the first position wins.
    let low = [-127i64; T];
    let r = softmax_row(&low, 0, &e).unwrap();
    assert_eq!((r.max, r.arg, r.sum, r.p[0]), (-127, 0, 512, 512));
    let r = softmax_row(&low, 9, &e).unwrap();
    assert_eq!((r.arg, r.sum), (0, 10 * 512));
    assert_eq!(r.p[9], 512 * 512 / 5120);
    // Last row, uniform: sum = 32 * 512, p = 16 each.
    let r = softmax_row(&[0; T], T - 1, &e).unwrap();
    assert_eq!(r.sum, 16384);
    assert!(r.p.iter().all(|p| *p == 16));
    // Integer quotient is floor and never exceeds 2^F_P.
    let mut s = [0i64; T];
    s[0] = 127;
    s[1] = -127;
    let r = softmax_row(&s, 1, &e).unwrap();
    assert_eq!(r.sum, 512 + e[254]);
    assert_eq!(r.p[0], (512i64 << 9) / r.sum);
}

#[test]
fn softmax_refusals() {
    let e = exp_table();
    assert_eq!(softmax_row(&[0; T], T, &e).err(), Some(KernelError::Shape("softmax row")));
    let mut s = [0i64; T];
    s[0] = 100;
    s[1] = -200;
    assert_eq!(softmax_row(&s, 1, &e).err(), Some(KernelError::Range("exp difference")));
    // A masked position also contributes a difference: best - MASK >= 256.
    let mut s = [0i64; T];
    s[0] = 129;
    assert_eq!(softmax_row(&s, 0, &e).err(), Some(KernelError::Range("exp difference")));
    let mut bad = e;
    bad[0] = 0;
    assert_eq!(softmax_row(&[0; T], 0, &bad).err(), Some(KernelError::Relation("softmax denominator")));
}

// ------------------------------------------------------------ orientation

#[test]
fn matrix_orientation() {
    let w: [i8; 6] = [1, 2, 3, 4, 5, 6];
    let mut x = [0i64; T * 2];
    x[0] = 1; // row 0 = e_0
    x[3] = 1; // row 1 = e_1
    let mut oi = [0i64; T * 3];
    matmul_out_in(&x, &w, 2, 3, &mut oi).unwrap();
    assert_eq!(&oi[..6], &[1, 3, 5, 2, 4, 6]); // w is (out=3, in=2)
    let mut io = [0i64; T * 3];
    matmul_in_out(&x, &w, 2, 3, &mut io).unwrap();
    assert_eq!(&io[..6], &[1, 2, 3, 4, 5, 6]); // w is (in=2, out=3)
    assert_eq!(matmul_out_in(&x, &w, 3, 2, &mut oi).err(), Some(KernelError::Shape("matmul_out_in")));
    assert_eq!(matmul_in_out(&x[..10], &w, 2, 3, &mut io).err(), Some(KernelError::Shape("matmul_in_out")));
}

#[test]
fn rope_half_split_orientation() {
    let (mut c, mut s, e, a) = synth_tables_raw();
    for i in 0..HALF {
        c[HALF + i] = 0; // t = 1: 90 degree rotation
        s[HALF + i] = 128;
    }
    let tab = PublicTables::from_slices(&c, &s, &e, &a).unwrap();
    let mut x = [0i64; KV_LEN];
    for i in 0..DH {
        x[KV + i] = i as i64 + 1; // t = 1: a = [1..4], b = [5..8]
    }
    let mut out = [0i64; KV_LEN];
    rotate(&x, 1, &tab, &mut out).unwrap();
    assert_eq!(&out[KV..2 * KV], &[-640, -768, -896, -1024, 128, 256, 384, 512]);
}

// ------------------------------------------------------------ rejection

#[test]
fn shape_and_table_rejection() {
    let r = fixture_weights_raw();
    assert_eq!(
        PublicWeights::from_slices(&r[1], &r[1], &r[2], &r[3], &r[4], &r[5], &r[6], &r[7], &r[8]).err(),
        Some(KernelError::Shape("wq"))
    );
    assert_eq!(
        PublicWeights::from_slices(&r[0], &r[1], &r[2], &r[3], &r[4], &r[5], &r[6], &r[7], &r[8][1..]).err(),
        Some(KernelError::Shape("wd_t"))
    );
    let (c, s, e, a) = synth_tables_raw();
    assert_eq!(PublicTables::from_slices(&c[1..], &s, &e, &a).err(), Some(KernelError::Shape("rope_cos")));
    assert_eq!(PublicTables::from_slices(&c, &s, &e, &a[1..]).err(), Some(KernelError::Shape("act")));
    let mut bad = c.clone();
    bad[40] = 129;
    assert_eq!(PublicTables::from_slices(&bad, &s, &e, &a).err(), Some(KernelError::Table("rope range")));
    let mut bad = s.clone();
    bad[1] = 1;
    assert_eq!(PublicTables::from_slices(&c, &bad, &e, &a).err(), Some(KernelError::Table("rope position 0")));
    let mut bad = e.clone();
    bad[0] = 511;
    assert_eq!(PublicTables::from_slices(&c, &s, &bad, &a).err(), Some(KernelError::Table("exp E[0]")));
    let mut bad = e.clone();
    bad[200] = -1;
    assert_eq!(PublicTables::from_slices(&c, &s, &bad, &a).err(), Some(KernelError::Table("exp range")));
    let mut bad = e.clone();
    bad[200] = bad[199] + 1;
    assert_eq!(PublicTables::from_slices(&c, &s, &bad, &a).err(), Some(KernelError::Table("exp monotone")));

    let (w, tab) = (weights(&r), synth_tables());
    let input = fixture_input();
    assert_eq!(run_block_slice(&input[1..], &w, &tab, None).err(), Some(KernelError::Shape("input")));
    assert!(run_block_slice(&input, &w, &tab, None).is_ok());
}

#[test]
fn range_refusals_never_clamp() {
    let tab = synth_tables();
    // Large gamma and Q weights: the Q accumulator leaves [-127,127].
    let mut r = fixture_weights_raw();
    r[4] = std::vec![127; 16];
    r[0] = std::vec![127; 256];
    assert_eq!(run_block(&[100; X_LEN], &weights(&r), &tab, None).err(), Some(KernelError::Range("Q")));
    // V accumulator 254 after requant: refuse, never saturate to 127.
    let mut r = fixture_weights_raw();
    r[4] = std::vec![-128; 16];
    r[2] = std::vec![127; 128];
    assert_eq!(run_block(&[-32768; X_LEN], &weights(&r), &tab, None).err(), Some(KernelError::Range("V")));
    // Fixture weights near i16 limits: residual 1 = x + ao overflows int16.
    let w = weights(&fixture_weights_raw());
    assert_eq!(run_block(&[32767; X_LEN], &w, &tab, None).err(), Some(KernelError::Range("residual 1")));
    assert_eq!(run_block(&[-32768; X_LEN], &w, &tab, None).err(), Some(KernelError::Range("residual 1")));
}

// ------------------------------------------------------------ end to end

/// Independent straightforward i128 reference (different loop structure,
/// rounding via div_euclid); returns the output or the first refusal site.
fn reference(x: &[i16; X_LEN], r: &[Vec<i8>; 9], tabs: &(Vec<i64>, Vec<i64>, Vec<i64>, Vec<i16>)) -> Result<Vec<i128>, &'static str> {
    fn rq(v: i128, sh: i32) -> i128 {
        if sh <= 0 {
            v << (-sh)
        } else {
            (v + (1 << (sh - 1))).div_euclid(1 << sh)
        }
    }
    fn q(v: Vec<i128>, sh: i32, lo: i128, hi: i128, site: &'static str) -> Result<Vec<i128>, &'static str> {
        let y: Vec<i128> = v.into_iter().map(|a| rq(a, sh)).collect();
        if y.iter().all(|v| (lo..=hi).contains(v)) { Ok(y) } else { Err(site) }
    }
    fn norm(x: &[i128], g: &[i8]) -> Result<Vec<i128>, &'static str> {
        let mut y = std::vec![0; X_LEN];
        for t in 0..T {
            let sse: i128 = (0..D).map(|i| x[t * D + i] * x[t * D + i]).sum::<i128>() + 1;
            // Bisection with lo^2 <= sse < hi^2.
            let (mut d, mut hi) = (0i128, 1i128 << 20);
            while hi - d > 1 {
                let mid = (d + hi) / 2;
                if mid * mid <= sse {
                    d = mid;
                } else {
                    hi = mid;
                }
            }
            for i in 0..D {
                let v = (2 * x[t * D + i] * g[i] as i128 * 1024 + (d << 11)).div_euclid(d << 12);
                if !(-127..=127).contains(&v) {
                    return Err("norm quotient/remainder");
                }
                y[t * D + i] = v;
            }
        }
        Ok(y)
    }
    fn lin(x: &[i128], w: &[i8], n_in: usize, n_out: usize, out_in: bool) -> Vec<i128> {
        let mut o = std::vec![0i128; T * n_out];
        for t in 0..T {
            for i in 0..n_in {
                for j in 0..n_out {
                    let wij = if out_in { w[j * n_in + i] } else { w[i * n_out + j] };
                    o[t * n_out + j] += x[t * n_in + i] * wij as i128;
                }
            }
        }
        o
    }
    let (c, s, e, a) = tabs;
    let x: Vec<i128> = x.iter().map(|v| *v as i128).collect();
    let na = norm(&x, &r[4])?;
    let qq = q(lin(&na, &r[0], D, D, true), 7, -127, 127, "Q")?;
    let kk = q(lin(&na, &r[1], D, KV, true), 7, -127, 127, "K")?;
    let vv = q(lin(&na, &r[2], D, KV, true), 7, -127, 127, "V")?;
    let rot = |v: &[i128], width: usize| -> Vec<i128> {
        let mut o = v.to_vec();
        for t in 0..T {
            for hb in (0..width).step_by(DH) {
                for i in 0..HALF {
                    let (cc, ss) = (c[t * HALF + i] as i128, s[t * HALF + i] as i128);
                    let (x0, x1) = (v[t * width + hb + i], v[t * width + hb + HALF + i]);
                    o[t * width + hb + i] = cc * x0 - ss * x1;
                    o[t * width + hb + HALF + i] = ss * x0 + cc * x1;
                }
            }
        }
        o
    };
    let qr = q(rot(&qq[..], D), 7, -127, 127, "QR")?;
    let kr = q(rot(&kk[..], KV), 7, -127, 127, "KR")?;
    let mut sc = std::vec![0i128; SCORE_LEN];
    for h in 0..H {
        for t in 0..T {
            for j in 0..T {
                sc[(h * T + t) * T + j] = (0..DH).map(|i| qr[t * D + h * DH + i] * kr[j * KV + i]).sum();
            }
        }
    }
    let sc = q(sc, 6, -127, 127, "score")?;
    let mut o = std::vec![0i128; X_LEN];
    for h in 0..H {
        for t in 0..T {
            let row = &sc[(h * T + t) * T..][..t + 1];
            // Scores are already in [-127,127], so every difference is < 256.
            let m = *row.iter().max().unwrap();
            let ex: Vec<i128> = row.iter().map(|v| e[(m - v) as usize] as i128).collect();
            let sum: i128 = ex.iter().sum();
            for i in 0..DH {
                o[t * D + h * DH + i] = (0..=t).map(|j| ((ex[j] << 9) / sum) * vv[j * KV + i]).sum();
            }
        }
    }
    let o = q(o, 9, -127, 127, "O")?;
    let ao = q(lin(&o, &r[3], D, D, true), 7, -32768, 32767, "AO")?;
    let x1 = q(x.iter().zip(&ao).map(|(a, b)| a + b).collect(), 0, -32768, 32767, "residual 1")?;
    let nm = norm(&x1, &r[5])?;
    let g = q(lin(&nm, &r[6], D, F, false), 7, -128, 127, "FFN gate")?;
    let u = q(lin(&nm, &r[7], D, F, false), 0, -32768, 32767, "FFN up")?;
    let hh = q(g.iter().zip(&u).map(|(g, u)| a[(g + 128) as usize] as i128 * u).collect(), 14, -32768, 32767, "FFN product")?;
    let z = q(lin(&hh, &r[8], F, D, false), 6, -32768, 32767, "FFN down")?;
    q(x1.iter().zip(&z).map(|(a, b)| a + b).collect(), 0, -32768, 32767, "residual 2")
}

fn site(e: KernelError) -> &'static str {
    match e {
        KernelError::Range(s) | KernelError::Relation(s) => s,
        other => panic!("unexpected kernel error {other:?}"),
    }
}

#[test]
fn end_to_end_matches_independent_reference() {
    let tabs = synth_tables_raw();
    let tab = PublicTables::from_slices(&tabs.0, &tabs.1, &tabs.2, &tabs.3).unwrap();
    let mut rng = Lcg(2026);
    let mut ok = 0;
    let mut refused = 0;
    for case in 0..60 {
        let mut r = fixture_weights_raw();
        if case % 2 == 1 {
            // Perturb every matrix with signed off-diagonal words.
            for m in [0usize, 1, 2, 3, 6, 7, 8] {
                for _ in 0..12 {
                    let at = (rng.next() as usize) % r[m].len();
                    r[m][at] = rng.range(40) as i8;
                }
            }
        }
        let amp = [3i64, 300, 9000, 32767][case % 4];
        let input: [i16; X_LEN] = if case == 0 {
            fixture_input()
        } else {
            core::array::from_fn(|_| rng.range(amp).clamp(-32768, 32767) as i16)
        };
        let w = weights(&r);
        let mut tr = Box::new(Trace::zeroed());
        let got = run_block(&input, &w, &tab, Some(&mut *tr));
        let want = reference(&input, &r, &tabs);
        match (got, want) {
            (Ok(out), Ok(want)) => {
                ok += 1;
                assert!(out.iter().zip(&want).all(|(a, b)| *a as i128 == *b), "case {case}");
                assert!(out.iter().zip(tr.xres2.iter()).all(|(a, b)| *a as i64 == *b));
                for h in 0..H {
                    for t in 0..T {
                        let row = h * T + t;
                        assert!(tr.arg[row] as usize <= t);
                        assert!(tr.p[row * T + t + 1..(row + 1) * T].iter().all(|p| *p == 0));
                        assert_eq!(tr.s8[row * T + tr.arg[row] as usize], tr.m_row[row]);
                    }
                }
                // Deterministic and trace-independent.
                assert_eq!(run_block(&input, &w, &tab, None), Ok(out));
            }
            (Err(e), Err(site_want)) => {
                refused += 1;
                assert_eq!(site(e), site_want, "case {case}");
            }
            (got, want) => panic!("case {case}: kernel ok={} reference ok={}", got.is_ok(), want.is_ok()),
        }
    }
    assert!(ok >= 20, "too few accepted cases: {ok}");
    let _ = refused;
}
