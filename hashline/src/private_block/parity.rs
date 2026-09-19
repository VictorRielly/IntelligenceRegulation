//! WITNESS-VS-KERNEL PARITY of the private block module (disposition
//! condition 6): the integer witness built here must equal
//! `private-block-kernel::run_block` element for element, and must refuse at
//! the same site with the same message, on many deterministic public inputs.
//!
//! Everything generated here is PUBLIC SYNTHETIC test data produced by a
//! fixed-seed integer generator: no OS randomness, no real model, no real
//! input, nothing read from or written to disk, and nothing printed but
//! counts and site names (never a witness value, as the kernel's own
//! `Trace` documentation requires).
//!
//! SCOPE. The witness of this module computes the WHOLE block, so exactly two
//! outcomes are allowed per case: both accept — every plane with a kernel
//! counterpart compared element for element, and every plane without one
//! (the remainder and limb planes, which the kernel keeps no witness for)
//! checked against the kernel's own biased requantization identity — or both
//! refuse with the SAME string (same site, same text). Either one-sided
//! outcome is a failure.

use super::layout::*;
use super::witness::{self, Witness};
use super::{AttentionPublic, BlockPublic, FeedForwardPublic};
use private_block_kernel as kern;
use std::collections::BTreeMap;
use std::sync::OnceLock;

/// generated cases per parity run (the brief's floor is 1,000)
const CASES: usize = 1_200;

// ---------------------------------------------------------------- generator

/// SplitMix64: a fixed, portable integer stream. No OS randomness anywhere.
struct Rng(u64);

impl Rng {
    fn seeded(idx: usize) -> Self {
        // a fixed lane constant mixed with the case index
        Rng(0x7A6B_5C4D_3E2F_1009u64.wrapping_add((idx as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15)))
    }
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    /// uniform-ish in [lo, hi]
    fn pick(&mut self, lo: i64, hi: i64) -> i64 {
        lo + (self.next() % ((hi - lo + 1) as u64)) as i64
    }
}

/// The three PUBLIC tables, generated once: the rope pair and the exp table of
/// the attention calibration, and the frozen int16-output SiLU activation
/// table of the feed-forward half (`(e_in, e_out) = (-3, -11)`, the fixture's).
fn tables() -> &'static (Vec<i64>, Vec<i64>, [i64; 256], [i16; 256]) {
    static TAB: OnceLock<(Vec<i64>, Vec<i64>, [i64; 256], [i16; 256])> = OnceLock::new();
    TAB.get_or_init(|| {
        let (cos, sin) = crate::tables_attn::rope_tables_generate(T, DH, 10000.0, F_RO);
        let (exp, _) = crate::tables_attn::exp_member(0, DH, F_E);
        let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member (-3, -11)");
        (cos, sin, exp, act)
    })
}

/// One generated public case: the same words in the module's statement form
/// and in the kernel's.
pub(crate) struct Case {
    pub public: AttentionPublic,
    /// the feed-forward half's public words, in this module's own form
    pub ff: FeedForwardPublic,
    pub kweights: kern::PublicWeights,
    pub ktables: kern::PublicTables,
    pub input: Vec<i16>,
}

/// `(out, in)` row-major matrix with a fixed diagonal and a signed band of
/// amplitude `mag`; `mag` is what sweeps the cases from well-conditioned
/// (every class holds) to hopeless (an early requant refuses).
fn matrix(r: &mut Rng, outer: usize, inner: usize, diag: i64, mag: i64) -> Vec<i8> {
    (0..outer * inner)
        .map(|k| {
            let (o, i) = (k / inner, k % inner);
            let v = if o == i { diag } else { r.pick(-mag, mag) };
            v.clamp(-127, 127) as i8
        })
        .collect()
}

/// Case `idx` of the deterministic sweep. Same index, same bytes, always.
pub(crate) fn case(idx: usize) -> Case {
    let mut r = Rng::seeded(idx);
    let (cos, sin, exp, act) = tables();
    // Three independent knobs on a 13 x 4 x 7 grid, swept by nested strides so
    // that 1,200 cases cover every grid point (364 of them, 23 sweeps of the
    // inner 52): off-diagonal weight amplitude, norm gain, input amplitude.
    // The large amplitudes are what drives a case into a refusal: with a full
    // band the Q/K/V and score requants leave their int8 class, and with a
    // near-full input residual 1 leaves int16.
    const BAND: [i64; 13] = [0, 1, 3, 8, 20, 48, 80, 100, 110, 118, 124, 127, 127];
    let mag = BAND[idx % 13];
    let gain = [24i64, 64, 96, 127][(idx / 13) % 4];
    let xmag = [1i64, 3, 9, 40, 200, 3_000, 32_767][(idx / 52) % 7];
    // The feed-forward band is swept INDEPENDENTLY (stride 11, which is
    // coprime with 364 = 13 * 4 * 7, so all 1,200 four-tuples are distinct):
    // a case whose attention half is tame can still stress the gate, up,
    // product and down requants, which a shared band would hide behind the
    // score refusals of the high-amplitude region.
    let ffn_mag = BAND[(idx / 11) % 13];

    let wq = matrix(&mut r, D, D, 64, mag);
    let wk = matrix(&mut r, KV, D, 64, mag);
    let wv = matrix(&mut r, KV, D, 64, mag);
    let wo = matrix(&mut r, D, D, 64, mag);
    let gamma_a: Vec<i8> = (0..D).map(|_| r.pick(gain - 8, gain).clamp(-127, 127) as i8).collect();
    let gamma_m: Vec<i8> = (0..D).map(|_| r.pick(gain - 8, gain).clamp(-127, 127) as i8).collect();
    // the feed-forward matrices are `(in, out)` row-major, as the kernel wants
    let wg_t = matrix(&mut r, D, 16, 64, ffn_mag);
    let wu_t = matrix(&mut r, D, 16, 64, ffn_mag);
    let wd_t = matrix(&mut r, 16, D, 64, ffn_mag);
    let input: Vec<i16> = (0..T * D).map(|_| r.pick(-xmag, xmag) as i16).collect();

    let public = AttentionPublic::new(&wq, &wk, &wv, &wo, &gamma_a, cos, sin, exp).expect("generated public statement");
    let ff = FeedForwardPublic::new(&gamma_m, &wg_t, &wu_t, &wd_t, act).expect("generated feed-forward statement");
    let kweights = kern::PublicWeights::from_slices(&wq, &wk, &wv, &wo, &gamma_a, &gamma_m, &wg_t, &wu_t, &wd_t).expect("generated kernel weights");
    let ktables = kern::PublicTables::from_slices(cos, sin, exp, act).expect("generated kernel tables");
    Case { public, ff, kweights, ktables, input }
}

// ---------------------------------------------------------------- comparison

/// Element-for-element equality. Reports the differing COUNT and the first
/// differing INDEX only — never a value, on either side.
fn eq(mine: &[i64], theirs: &[i64], idx: usize, name: &str) {
    assert_eq!(mine.len(), theirs.len(), "case {idx}: plane {name} length {} vs kernel {}", mine.len(), theirs.len());
    let bad = mine.iter().zip(theirs).filter(|(a, b)| a != b).count();
    let first = mine.iter().zip(theirs).position(|(a, b)| a != b);
    assert!(bad == 0, "case {idx}: plane {name} differs from the kernel in {bad} of {} elements (first at index {first:?})", mine.len());
}

/// The planes the kernel records before the attention half can refuse again
/// (it writes them all at once, after the score requant).
fn compare_traced_prefix(w: &Witness, tr: &kern::Trace, idx: usize) {
    eq(&w.planes[A_D], &tr.na_dd, idx, "norm_a D");
    eq(&w.planes[A_Y], &tr.na_y, idx, "norm_a y");
    eq(&w.planes[A_Q8], &tr.q8, idx, "q8");
    eq(&w.planes[A_K8], &tr.k8, idx, "k8");
    eq(&w.planes[A_V8], &tr.v8, idx, "v8");
    eq(&w.planes[A_QR8], &tr.qr8, idx, "qr8");
    eq(&w.planes[A_KR8], &tr.kr8, idx, "kr8");
    eq(&w.planes[A_S8], &tr.s8, idx, "s8");
}

/// Every attention-half plane with a kernel counterpart, plus the derived
/// planes the kernel does not carry (`D^2`, the one-hot selector).
pub(crate) fn compare_attention_half(w: &Witness, tr: &kern::Trace, idx: usize) {
    compare_traced_prefix(w, tr, idx);
    eq(&w.planes[A_MX], &tr.m_row, idx, "row max");
    eq(&w.planes[A_SUM], &tr.sum, idx, "row sum");
    eq(&w.planes[A_P], &tr.p, idx, "softmax p");
    eq(&w.planes[A_O8], &tr.o8, idx, "o8");
    eq(&w.planes[A_AO], &tr.ao8, idx, "ao");
    eq(&w.planes[A_X1], &tr.xres1, idx, "xres1");
    // D^2 is the witness's own plane; the kernel keeps only D
    let dsq: Vec<i64> = tr.na_dd.iter().map(|d| d * d).collect();
    eq(&w.planes[A_DSQ], &dsq, idx, "norm_a D^2");
    // the one-hot selector against the kernel's argmax index
    let mut zsel = vec![0i64; H * T * T];
    for row in 0..H * T {
        zsel[row * T + tr.arg[row] as usize] = 1;
    }
    eq(&w.planes[A_ZSEL], &zsel, idx, "softmax selector");
}

// ---------------------------------------------------------------- the test

/// Every plane the block half adds, against its kernel counterpart. The
/// remainder and limb planes have no kernel counterpart (the kernel keeps no
/// requantization witness), so they are checked against the kernel's own
/// BIASED requantization identity instead, which is the relation the argument
/// will prove: `acc = 2^sh y + r' - 2^(sh-1)` with `r'` the committed plane.
fn compare_block_half(c: &Case, w: &Witness, tr: &kern::Trace, idx: usize) {
    eq(&w.planes[A_DM], &tr.nm_dd, idx, "norm_m D");
    eq(&w.planes[A_YM], &tr.nm_y, idx, "norm_m y (nm)");
    eq(&w.planes[A_G8], &tr.g8, idx, "g8");
    eq(&w.planes[A_A16], &tr.a16, idx, "a16");
    eq(&w.planes[A_U16], &tr.u16, idx, "u16");
    eq(&w.planes[A_H16], &tr.h16, idx, "h16");
    eq(&w.planes[A_Z16], &tr.z16, idx, "z16");
    eq(&w.planes[A_X2], &tr.xres2, idx, "xres2");
    let dsqm: Vec<i64> = tr.nm_dd.iter().map(|d| d * d).collect();
    eq(&w.planes[A_DSQM], &dsqm, idx, "norm_m D^2");
    // the two-limb int16 decompositions, offset 32768
    for (v, l0, l1, name) in [
        (A_U16, A_UL0, A_UL1, "u16 limbs"),
        (A_H16, A_HL0, A_HL1, "h16 limbs"),
        (A_Z16, A_ZL0, A_ZL1, "z16 limbs"),
        (A_X2, A_X2L0, A_X2L1, "xres2 limbs"),
    ] {
        let joined: Vec<i64> = w.planes[l0].iter().zip(w.planes[l1].iter()).map(|(a, b)| a + 256 * b).collect();
        let offset: Vec<i64> = w.planes[v].iter().map(|x| x + 32768).collect();
        eq(&joined, &offset, idx, name);
        assert!(w.planes[l0].iter().chain(w.planes[l1].iter()).all(|l| (0..256).contains(l)), "case {idx}: a limb of {name} is not a byte");
    }
    // the biased requantization identities of the gate, the product and the
    // down matmul, recomputed from the kernel's own inputs
    let gacc: Vec<i64> = (0..T * F)
        .map(|k| {
            let (t, j) = (k / F, k % F);
            (0..D).map(|i| tr.nm_y[t * D + i] * i64::from(c.ff.wg_t[i * F + j])).sum()
        })
        .collect();
    let gid: Vec<i64> = (0..T * F).map(|k| (1i64 << SH_G) * w.planes[A_G8][k] + w.planes[A_RGL][k] - (1i64 << (SH_G - 1))).collect();
    eq(&gid, &gacc, idx, "gate requantization identity");
    assert!(w.planes[A_RGL].iter().all(|r| (0..1 << SH_G).contains(r)), "case {idx}: a gate remainder leaves [0, 2^7)");
    let hacc: Vec<i64> = (0..T * F).map(|k| tr.a16[k] * tr.u16[k]).collect();
    let rh: Vec<i64> = (0..T * F).map(|k| w.planes[A_RH0][k] + 256 * w.planes[A_RH1][k]).collect();
    let hid: Vec<i64> = (0..T * F).map(|k| (1i64 << SH_H_PROD) * w.planes[A_H16][k] + rh[k] - (1i64 << (SH_H_PROD - 1))).collect();
    eq(&hid, &hacc, idx, "product requantization identity");
    assert!(rh.iter().all(|r| (0..1 << SH_H_PROD).contains(r)), "case {idx}: a product remainder leaves [0, 2^14)");
    let zacc: Vec<i64> = (0..T * D)
        .map(|k| {
            let (t, i) = (k / D, k % D);
            (0..F).map(|j| tr.h16[t * F + j] * i64::from(c.ff.wd_t[j * D + i])).sum()
        })
        .collect();
    let zid: Vec<i64> = (0..T * D).map(|k| (1i64 << SH_Z) * w.planes[A_Z16][k] + w.planes[A_RDL][k] - (1i64 << (SH_Z - 1))).collect();
    eq(&zid, &zacc, idx, "down requantization identity");
    assert!(w.planes[A_RDL].iter().all(|r| (0..1 << SH_Z).contains(r)), "case {idx}: a down remainder leaves [0, 2^6)");
    // residual 2 and the classes the kernel refuses outside
    let sum: Vec<i64> = (0..T * D).map(|k| w.planes[A_X1][k] + w.planes[A_Z16][k]).collect();
    eq(&w.planes[A_X2], &sum, idx, "residual 2 (xres2 = xres1 + z16)");
    assert!(w.planes[A_G8].iter().all(|g| (-128..=127).contains(g)), "case {idx}: g8 leaves the kernel's int8 class");
    assert!(w.planes[A_YM].iter().all(|v| (-127..=127).contains(v)), "case {idx}: nm leaves the int8 subset");
}

#[test]
fn the_whole_block_witness_equals_the_reference_kernel() {
    // the layout exists and holds every plane the witness fills
    let lay = Layout::new();
    let (mut both_ok, mut both_refuse) = (0usize, 0usize);
    let mut sites: BTreeMap<String, usize> = BTreeMap::new();
    for idx in 0..CASES {
        let c = case(idx);
        let mut tr = Box::new(kern::Trace::zeroed());
        let kernel = kern::run_block_slice(&c.input, &c.kweights, &c.ktables, Some(&mut *tr));
        let wit = witness::build(&c.public, &c.ff, &c.input);
        match (&kernel, &wit) {
            (Ok(out), Ok(w)) => {
                compare_attention_half(w, &tr, idx);
                compare_block_half(&c, w, &tr, idx);
                let mine = w.output().expect("xres2 is in class once the witness accepted");
                assert_eq!(&mine[..], &out[..], "case {idx}: the block output differs from the kernel's");
                // every plane the grown layout declares is filled at its declared length
                for p in lay.a_planes() {
                    let want = if is_multiplicity(p) { 0 } else { a_dom(p).len() };
                    assert_eq!(w.planes[p].len(), want, "case {idx}: plane {p} length");
                }
                both_ok += 1;
            }
            (Err(e), Err(m)) => {
                assert_eq!(&format!("{e}"), m, "case {idx}: the two refusals differ");
                *sites.entry(m.clone()).or_default() += 1;
                both_refuse += 1;
            }
            (Err(e), Ok(_)) => panic!("case {idx}: the whole-block witness accepted where the kernel refused ({e})"),
            (Ok(_), Err(m)) => panic!("case {idx}: the whole-block witness refused (`{m}`) where the kernel accepted"),
        }
    }
    assert_eq!(both_ok + both_refuse, CASES, "every case is decided the same way by both");
    assert!(both_ok >= 100, "the sweep must exercise accepted blocks: only {both_ok} of {CASES}");
    assert!(both_refuse >= 100, "the sweep must exercise refusals: only {both_refuse} of {CASES}");
    assert!(sites.len() >= 6, "the sweep must reach several refusal sites, it reached {}", sites.len());
    assert!(sites.keys().any(|s| s.contains("residual 2")), "the sweep must reach a block-half refusal");
    eprintln!("private block whole-block parity: {CASES} generated public cases — {both_ok} accepted by both, {both_refuse} refused identically by both");
    for (site, count) in &sites {
        eprintln!("  refusal site `{site}`: {count}");
    }
}

/// The generator itself is deterministic: the same index gives the same bytes,
/// in this process and in any other (no OS randomness, no time, no hashing of
/// pointers). Cheap, so it runs on every build.
#[test]
fn the_case_generator_is_deterministic_and_covers_its_grid() {
    for idx in [0usize, 1, 7, 13, 65, 199, 1_199] {
        let a = case(idx);
        let b = case(idx);
        assert_eq!(a.input, b.input, "case {idx}: input differs between two generations");
        let dg = |c: &Case| BlockPublic::new(c.public.clone(), c.ff.clone()).digest();
        assert_eq!(dg(&a), dg(&b), "case {idx}: public statement differs between two generations");
    }
    let mut seen = std::collections::BTreeSet::new();
    let mut with_ffn = std::collections::BTreeSet::new();
    for idx in 0..CASES {
        seen.insert(((idx % 13), (idx / 13) % 4, (idx / 52) % 7));
        with_ffn.insert(((idx % 13), (idx / 13) % 4, (idx / 52) % 7, (idx / 11) % 13));
    }
    assert!(seen.len() >= 13 * 4 * 7, "the sweep covers {} of the {} grid points", seen.len(), 13 * 4 * 7);
    assert_eq!(with_ffn.len(), CASES, "the (attention band, gain, input, feed-forward band) settings are not all distinct");
    assert_ne!(case(0).input, case(1).input, "two cases share an input");
}
