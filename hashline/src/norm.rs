//! [UPERF3-AE] RMSNorm as an exact integer gadget (ATTENTION_INTEGER_SPEC
//! section 2.1; design memo section 1.2), the value chain and its facts.
//!
//! Declared function of the committed input plane x (T x d, int8 or
//! int16 class at exponent e_x) and the int8 gamma vector g (at e_g):
//!
//!   SS_t   = sum_i x[t,i]^2                    (a degree-2 row-sum sumcheck)
//!   SSe_t  = SS_t + Ceps,  Ceps = max(1, round_half_up(eps * d * 2^-2e_x))
//!   D_t    = isqrt(SSe_t):  a1_t = SSe_t - D_t^2 in [0, 2D_t],
//!                            a2_t = 2 D_t - a1_t >= 0    (the isqrt fact pair)
//!   (tn, Cn) public per site (the window rule: the smallest tn with
//!            Cn = round_half_up(2^(tn + e_g - e_y) * sqrt(d)) >= 2^10)
//!   y[t,i] = floor(x[t,i] * g[i] * Cn / (D_t * 2^tn))   (the division relation:
//!            y * D * 2^tn + rho = x * g * Cn, rho in [0, D * 2^tn))
//!   y narrows to int8 at 2^e_y (a range fact).
//!
//! e_x does NOT appear in (tn, Cn): x carries 2^e_x and D carries 2^-e_x
//! (D ~ sqrt(d) * rms(x) / 2^e_x), so it cancels (the spike's recorded
//! derivation). At d = 4096 sqrt(d) = 64 and Cn is an exact power of two.
//!
//! Facts on the hash line (rung 4): the row sums by one sumcheck whose
//! terminal ties SS~(r_t) to the committed per-row vector; the isqrt pair
//! as two per-row zero-checks + four U16 limb lookups (a1, a2 split into
//! 16-bit limbs: at an int16 input D < 2^21); the division relation as
//! one (t, i) zero-check reading D row-broadcast and g column-broadcast
//! (PW-4), with rho and sigma = D 2^tn - 1 - rho as 16-bit limb pairs
//! (four U16 lookups per element) and y in the INT8 class. The value
//! chain below is what the oracle scripts/attention_hash_ref.py computes
//! (bit-exact digests are the rung-3 gate).

/// The public per-site constants of one norm site.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct NormSite {
    pub d: usize,
    pub e_x: i32,
    pub e_g: i32,
    pub e_y: i32,
    pub tn: u32,
    pub cn: i64,
    pub ceps: i64,
}

#[inline]
pub fn round_half_up(x: f64) -> i64 {
    (x + 0.5).floor() as i64
}

/// The window rule: the smallest tn with Cn >= 2^10 (Cn then lies in [2^10, 2^11]).
pub fn window_rule(e_g: i32, e_y: i32, d: usize) -> (u32, i64) {
    let base = ((e_g - e_y) as f64).exp2() * (d as f64).sqrt();
    let mut tn = 0u32;
    while round_half_up((tn as f64).exp2() * base) < 1 << 10 {
        tn += 1;
        assert!(tn <= 40, "window rule: no tn");
    }
    let cn = round_half_up((tn as f64).exp2() * base);
    assert!((1 << 10..=1 << 11).contains(&cn), "Cn window: {cn}");
    (tn, cn)
}

pub fn ceps_of(eps: f64, d: usize, e_x: i32) -> i64 {
    std::cmp::max(1, round_half_up(eps * d as f64 * ((-2 * e_x) as f64).exp2()))
}

impl NormSite {
    pub fn new(d: usize, eps: f64, e_x: i32, e_g: i32, e_y: i32) -> NormSite {
        let (tn, cn) = window_rule(e_g, e_y, d);
        NormSite { d, e_x, e_g, e_y, tn, cn, ceps: ceps_of(eps, d, e_x) }
    }
}

/// Integer square root (floor) of a nonnegative i64.
pub fn isqrt(v: i64) -> i64 {
    assert!(v >= 0);
    if v < 2 {
        return v;
    }
    let mut r = (v as f64).sqrt() as i64;
    while r * r > v {
        r -= 1;
    }
    while (r + 1) * (r + 1) <= v {
        r += 1;
    }
    r
}

/// The derived witness of one norm site over `t_rows` rows.
pub struct NormWitness {
    pub site: NormSite,
    pub t_rows: usize,
    pub ss: Vec<i64>,  // T: sum of squares (without Ceps)
    pub dd: Vec<i64>,  // T: isqrt(SS + Ceps)
    pub a1: Vec<i64>,  // T: SSe - D^2
    pub a2: Vec<i64>,  // T: 2D - a1
    pub y: Vec<i32>,   // T x d: the int8 output
    pub rho: Vec<i64>, // T x d: the division remainder
    pub sig: Vec<i64>, // T x d: D 2^tn - 1 - rho
    pub range_ok: bool,
}

/// Run the gadget: x (T x d, row-major, any integer class), g (d).
pub fn rmsnorm_int(x: &[i32], g: &[i8], site: &NormSite) -> NormWitness {
    let d = site.d;
    assert_eq!(x.len() % d, 0);
    assert_eq!(g.len(), d);
    let t_rows = x.len() / d;
    let mut ss = vec![0i64; t_rows];
    let mut dd = vec![0i64; t_rows];
    let mut a1 = vec![0i64; t_rows];
    let mut a2 = vec![0i64; t_rows];
    let mut y = vec![0i32; t_rows * d];
    let mut rho = vec![0i64; t_rows * d];
    let mut sig = vec![0i64; t_rows * d];
    let mut ok = true;
    for t in 0..t_rows {
        let row = &x[t * d..(t + 1) * d];
        let s: i64 = row.iter().map(|&v| (v as i64) * (v as i64)).sum();
        let sse = s + site.ceps;
        let r = isqrt(sse);
        ss[t] = s;
        dd[t] = r;
        a1[t] = sse - r * r;
        a2[t] = 2 * r - a1[t];
        ok &= a1[t] >= 0 && a2[t] >= 0;
        let div = r << site.tn;
        for i in 0..d {
            let num = (row[i] as i64) * (g[i] as i64) * site.cn;
            let q = num.div_euclid(div);
            let rr = num - q * div;
            y[t * d + i] = q as i32;
            rho[t * d + i] = rr;
            sig[t * d + i] = div - 1 - rr;
            ok &= (-128..=127).contains(&q) && rr >= 0 && rr < div;
        }
    }
    NormWitness { site: *site, t_rows, ss, dd, a1, a2, y, rho, sig, range_ok: ok }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn window_rule_examples() {
        // d = 4096: sqrt(d) = 64 exact -> Cn a power of two
        let (tn, cn) = window_rule(-6, -3, 4096);
        assert_eq!(cn, 1024);
        assert_eq!(tn, 7);
        let (_, cn) = window_rule(-6, -2, 768);
        assert!((1024..=2048).contains(&cn));
        assert_eq!(isqrt(0), 0);
        assert_eq!(isqrt(15), 3);
        assert_eq!(isqrt(16), 4);
        assert_eq!(isqrt((1i64 << 40) - 1), (1i64 << 20) - 1);
    }

    #[test]
    fn gadget_facts_hold_on_random_rows() {
        let d = 64usize;
        let site = NormSite::new(d, 1e-5, -3, -6, -2);
        let mut s = 7u64;
        let mut x = vec![0i32; 8 * d];
        for v in x.iter_mut() {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            *v = ((s >> 33) % 255) as i32 - 127;
        }
        let g: Vec<i8> = (0..d).map(|i| 49 + (i % 31) as i8).collect();
        let w = rmsnorm_int(&x, &g, &site);
        assert!(w.range_ok);
        for t in 0..8 {
            let sse = w.ss[t] + site.ceps;
            assert!(w.dd[t] * w.dd[t] <= sse && sse < (w.dd[t] + 1) * (w.dd[t] + 1));
            for i in 0..d {
                let num = x[t * d + i] as i64 * g[i] as i64 * site.cn;
                assert_eq!(w.y[t * d + i] as i64 * (w.dd[t] << site.tn) + w.rho[t * d + i], num);
            }
        }
    }
}
