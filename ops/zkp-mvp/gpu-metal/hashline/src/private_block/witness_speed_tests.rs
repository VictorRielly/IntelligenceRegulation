//! **ROUND 3 (R3-1): the parallel witness products equal the sequential
//! ones.** TEST CODE ONLY. The witness builder's matrix products became
//! parallel (rayon) and cache-friendly; they are exact integer sums, so the
//! planes cannot move. This module checks it directly against the round-2
//! sequential products (`witness::matmul_reference`, verbatim), on random
//! words of every class the call sites see (int8 and int16 inputs, zeros,
//! and inputs outside the i32 fast path), at the trained rung's dimensions in
//! the ordinary filter and at TinyLlama's in release (ignored). The whole
//! witness's bit-exactness is also held by the frozen receipts, the slot-IR
//! digests and the kernel parity tests of the suite, which this round leaves
//! unchanged.

use super::shape::Shape;
use super::witness;

/// a small deterministic generator (xorshift64*)
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }
    fn range(&mut self, lo: i64, hi: i64) -> i64 {
        lo + (self.next() % ((hi - lo + 1) as u64)) as i64
    }
}

/// one product at a shape's real dimensions, parallel against sequential
#[allow(clippy::too_many_arguments)]
fn check(sh: &Shape, r: &mut Rng, xs: usize, inner: usize, outer: usize, os: usize, in_out: bool, xlo: i64, xhi: i64) {
    let rows = sh.t_pad;
    let mut x = vec![0i64; rows * xs];
    for t in 0..sh.tokens {
        for i in 0..inner {
            // a sprinkling of zeros exercises the skip on the in-out path
            x[t * xs + i] = if r.next() % 7 == 0 { 0 } else { r.range(xlo, xhi) };
        }
    }
    let w: Vec<i8> = (0..inner * outer).map(|_| r.range(-128, 127) as i8).collect();
    let out_len = rows * os;
    let want = witness::matmul_reference(sh.tokens, &x, xs, &w, inner, outer, os, out_len, in_out);
    let got = witness::matmul_parallel(sh, &x, xs, &w, inner, outer, os, out_len, in_out);
    assert_eq!(got, want, "{}: {} product {inner} -> {outer} (x in [{xlo}, {xhi}]) differs from the sequential one", sh.name, if in_out { "in-out" } else { "out-in" });
}

/// every product the builder makes at `sh`, with every input class
fn every_product(sh: &Shape, seed: u64) {
    let mut r = Rng(seed);
    let (dp, fp, kvw) = (sh.d_pad, sh.f_pad, sh.kv_heads * sh.head_dim);
    // H124: (-32767, 32767) is the i16 fast path at its edge; (-32768, 32767) and
    // (-(2^23 - 1), 2^23 - 1) take the i32 path; +-2^40 takes the i64 path
    for (xlo, xhi) in [(-127i64, 127i64), (-32767, 32767), (-32768, 32767), (-(1i64 << 23) + 1, (1i64 << 23) - 1), (-(1i64 << 40), 1i64 << 40)] {
        // Wq, Wo (d -> d), Wk / Wv (d -> kvw): out-in
        check(sh, &mut r, dp, dp, dp, dp, false, xlo, xhi);
        check(sh, &mut r, dp, dp, kvw, kvw, false, xlo, xhi);
        // Wg / Wu (d -> f), Wd (f -> d): in-out
        check(sh, &mut r, dp, dp, fp, fp, true, xlo, xhi);
        check(sh, &mut r, fp, fp, dp, dp, true, xlo, xhi);
    }
}

/// **H124: the i16 path is exact at its worst case.** Every product at its
/// largest magnitude (|x| = 2^15 - 1, w = -128 or 127, one sign throughout),
/// so each i32 block sum sits at its bound; at inner widths that span several
/// blocks and end on a partial one.
#[test]
fn the_i16_products_are_exact_at_their_extremes() {
    let sh = Shape::rung_c6();
    for &(xv, wv) in &[(32767i64, -128i8), (-32767, -128), (32767, 127), (-32767, 127)] {
        for &(inner, outer, in_out) in &[(1000usize, 7usize, false), (1000, 7, true), (513, 300, false), (513, 300, true)] {
            let rows = sh.t_pad;
            let mut x = vec![0i64; rows * inner];
            for t in 0..sh.tokens {
                for i in 0..inner {
                    x[t * inner + i] = xv;
                }
            }
            let w = vec![wv; inner * outer];
            let out_len = rows * outer;
            let want = witness::matmul_reference(sh.tokens, &x, inner, &w, inner, outer, outer, out_len, in_out);
            let got = witness::matmul_parallel(&sh, &x, inner, &w, inner, outer, outer, out_len, in_out);
            assert_eq!(got, want, "x = {xv}, w = {wv}, {inner} -> {outer}, in_out {in_out}");
        }
    }
}

#[test]
fn the_parallel_products_equal_the_sequential_ones_at_the_trained_rung() {
    every_product(&Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap(), 0x5233_0001);
    every_product(&Shape::rung_c6(), 0x5233_0002);
}

/// the TinyLlama dimensions (heavy only because the SEQUENTIAL reference is
/// slow: two products of 2048 x 8192 per input class)
#[test]
#[ignore = "release: the sequential reference at TinyLlama's dimensions"]
fn the_parallel_products_equal_the_sequential_ones_at_the_tinyllama_dimensions() {
    every_product(&super::trained_calib_tests::tinyllama_at(64), 0x5233_0003);
}

/// **The per-block witness time** at the trained TinyLlama shapes (generic
/// dense witness), printed for the record with the thread count. Release.
#[test]
#[ignore = "release timing: TinyLlama witnesses at T32, T64 and T128"]
fn native_witness_time_per_block_at_the_trained_tinyllama_shapes() {
    for t in [32usize, 64, 128] {
        let sh = super::trained_calib_tests::tinyllama_at(t);
        let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
        let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
        let mut best = f64::MAX;
        for _ in 0..3 {
            let t0 = std::time::Instant::now();
            let wit = witness::build_shaped(&sh, &public, &ff, &input).expect("the generic witness");
            best = best.min(t0.elapsed().as_secs_f64());
            drop(wit);
        }
        eprintln!("NATIVE R3-1 witness T{t}: best of 3 {best:.3} s per block on {} rayon threads (dense synthetic words; shared box)", rayon::current_num_threads());
    }
}

/// **H124c acceptance: the parallelized builder equals its sequential reference on
/// every plane, and refuses exactly as it does.** Six profiles cover:
/// - the R13 byte-limb and the W16 16-bit assignments;
/// - the DD dictionary branch;
/// - the rungs (the small sizes that stay sequential in `quantized`);
/// - T128 and T256;
/// - the 8B block the clock is measured on.
/// For each, the first few synthetic inputs are built both ways. The inadmissible ones
/// among them must return the same error.
#[test]
fn h124c_the_parallel_builder_equals_the_sequential_one_on_every_plane() {
    use super::range16_tests::{built, case};
    use super::shape::{ACCURACY_PROFILES, W16R2_PROFILES, W16_PROFILES};
    for name in ["R13_TINY_T128_LOW", "R13_8B_T128_H24_DD", "R13_RUNG_H24", "W16R2_RUNG_H24", "W16_SHIELD_T256_H24", "W16R2_8B_T128_H24"] {
        let spec = ACCURACY_PROFILES.iter().chain(W16_PROFILES.iter()).chain(W16R2_PROFILES.iter()).find(|s| s.name == name).expect("a listed profile");
        let (sh, data, public, ff) = case(built(spec.profile), 3);
        let build = |x: &[i16]| witness::build_accuracy(&sh, &public, &ff, &data, x);
        let (mut admissible, mut refused) = (0usize, 0usize);
        for s in 0..4usize {
            let x: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
            match (build(&x), witness::with_sequential(|| build(&x))) {
                (Ok(a), Ok(b)) => {
                    assert_eq!(a.planes.len(), b.planes.len(), "{name} input {s}: plane count");
                    for (k, (pa, pb)) in a.planes.iter().zip(b.planes.iter()).enumerate() {
                        assert!(pa == pb, "{name} input {s}: plane {k} differs between the parallel and sequential builders");
                    }
                    assert_eq!(a.output_plane, b.output_plane, "{name} input {s}: output plane");
                    admissible += 1;
                }
                (Err(a), Err(b)) => {
                    assert_eq!(a, b, "{name} input {s}: the two builders refuse differently");
                    refused += 1;
                }
                (a, b) => panic!("{name} input {s}: parallel {:?} against sequential {:?}", a.err(), b.err()),
            }
        }
        // the D55 fixture's synthetic inputs are inadmissible at the DD profile (its dictionary
        // column): there the check is that both builders refuse every one identically
        assert!(admissible > 0 || name.ends_with("_DD"), "{name}: no admissible input among the four");
        eprintln!("H124c {name}: {admissible} admissible inputs equal on every plane, {refused} refused identically");
    }
}

/// **H124c: a steady load for a sampling profiler.** Builds the W16R2 8B T128
/// witness `HL_H124_LOOPS` times (default 60) on all threads and prints each
/// build's wall, so `sample <pid>` can attach and see where the builder's
/// remainder spends its time.
#[test]
#[ignore = "profiling load (H124c): W16R2 8B T128 witness builds in a loop"]
fn h124c_witness_build_loop_for_sampling() {
    use super::range16_tests::{built, case};
    let (sh, data, public, ff) = case(built(super::shape::W16R2_8B_T128_H24), 3);
    let build = |x: &[i16]| witness::build_accuracy(&sh, &public, &ff, &data, x);
    let mut s = 0usize;
    let input = loop {
        let x: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
        match build(&x) {
            Ok(_) => break x,
            Err(_) if s < 6 => s += 1,
            Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
        }
    };
    let loops: usize = std::env::var("HL_H124_LOOPS").ok().and_then(|v| v.parse().ok()).unwrap_or(60);
    eprintln!("H124c: pid {} building {loops} witnesses", std::process::id());
    for i in 0..loops {
        let t0 = std::time::Instant::now();
        drop(build(&input).unwrap());
        eprintln!("H124c build {i}: {:.3} s", t0.elapsed().as_secs_f64());
    }
}

/// **H124: one block's witness time at the W16R2 8B T128 shape, and how much of it is
/// the seven weight products.**
///
/// - The block is the D55 A/B fixture's: public synthetic data at the true geometry
///   (`range16_tests::case`), with M10's admissible input.
/// - It times `build_accuracy` on the global rayon pool and on a one-thread pool (CPU seconds).
/// - It then times the seven weight products alone (q, k, v, o, gate, up, down) at the same
///   sizes, through the builder's own parallel products on random words.
///
/// Release; the box is shared, so read the numbers as an estimate.
#[test]
#[ignore = "release timing (H124): the W16R2 8B T128 witness, all threads and one thread, and the weight products alone"]
fn h124_witness_time_per_block_at_w16r2_8b_t128() {
    use super::range16_tests::{built, case};
    let (sh, data, public, ff) = case(built(super::shape::W16R2_8B_T128_H24), 3);
    let build = |x: &[i16]| witness::build_accuracy(&sh, &public, &ff, &data, x);
    let mut s = 0usize;
    let input = loop {
        let x: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
        match build(&x) {
            Ok(_) => break x,
            Err(_) if s < 6 => s += 1,
            Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
        }
    };
    let best = |f: &dyn Fn()| {
        let mut b = f64::MAX;
        for _ in 0..3 {
            let t0 = std::time::Instant::now();
            f();
            b = b.min(t0.elapsed().as_secs_f64());
        }
        b
    };
    let threads = rayon::current_num_threads();
    let all = best(&|| drop(build(&input).unwrap()));
    let one_pool = rayon::ThreadPoolBuilder::new().num_threads(1).build().unwrap();
    let one = one_pool.install(|| best(&|| drop(build(&input).unwrap())));

    let (t, d, qw, kv, h) = (sh.tokens, sh.width, sh.q_width(), sh.kv_heads * sh.head_dim, sh.hidden);
    let mut r = Rng(0x9e37_79b9_7f4a_7c15);
    let words = |r: &mut Rng, n: usize, m: i64| -> Vec<i64> { (0..n).map(|_| r.range(-m, m)).collect() };
    let weights = |r: &mut Rng, n: usize| -> Vec<i8> { (0..n).map(|_| r.range(-127, 127) as i8).collect() };
    // (inner, outer, in_out): the projections in the attention orientation, the feed-forward in its own
    let shapes = [(d, qw, false), (d, kv, false), (d, kv, false), (qw, d, false), (d, h, true), (d, h, true), (h, d, true)];
    let operands: Vec<(Vec<i64>, Vec<i8>, usize, usize, bool)> =
        shapes.iter().map(|&(inner, outer, in_out)| (words(&mut r, t * inner, 100), weights(&mut r, inner * outer), inner, outer, in_out)).collect();
    let products = || {
        for (x, w, inner, outer, in_out) in &operands {
            drop(witness::matmul_parallel(&sh, x, *inner, w, *inner, *outer, *outer, t * *outer, *in_out));
        }
    };
    let prod_all = best(&products);
    let prod_one = one_pool.install(|| best(&products));
    let macs: usize = shapes.iter().map(|&(i, o, _)| t * i * o).sum();
    eprintln!(
        "H124 {} witness per block: {all:.3} s on {threads} threads, {one:.3} s on 1 thread (CPU s); \
         seven weight products alone: {prod_all:.3} s on {threads} threads, {prod_one:.3} s on 1 thread ({:.2} G MACs); \
         rest (all threads) {:.3} s; a 32-block request at this rate: {:.1} s on all threads, {:.1} CPU s",
        sh.name,
        macs as f64 / 1e9,
        all - prod_all,
        32.0 * all,
        32.0 * one
    );
}

// ---------------------------------------------------------------------------
// A4 (2026-11-05): the weight products on the Metal GPU, word for word
// ---------------------------------------------------------------------------

/// **A4, every build: forcing the products onto the device never changes one.**
/// On a gpu-metal build this is the device; on any other build the request
/// falls back to the CPU (`gpu::witness_product` is `Ok(None)` there). Either way
/// the plane equals the sequential reference, and the count of device products
/// made says which ran.
#[test]
fn a4_forcing_the_device_never_changes_a_product() {
    let sh = Shape::rung_c6();
    let mut r = Rng(0xa4a4_0000);
    let (dp, fp) = (sh.d_pad, sh.f_pad);
    let x: Vec<i64> = (0..sh.t_pad * dp).map(|_| r.range(-32768, 32767)).collect();
    let w: Vec<i8> = (0..dp * fp).map(|_| r.range(-128, 127) as i8).collect();
    let made = witness::device_products_made();
    for in_out in [false, true] {
        let want = witness::matmul_reference(sh.tokens, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, in_out);
        let got = witness::with_device_products(true, || witness::matmul_parallel(&sh, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, in_out));
        assert!(got == want, "in_out {in_out}: a product forced onto the device differs from the sequential one");
    }
    let on_device = witness::device_products_made() - made;
    assert_eq!(on_device, if cfg!(all(feature = "gpu-metal", not(feature = "gpu-cuda"))) { 2 } else { 0 }, "device products made");
}

#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
mod a4 {
    use super::super::shape::Shape;
    use super::super::witness;
    use super::Rng;
    use crate::gpu::{with_witness_options, witness_product_stats, witness_product_with, WITNESS_ROUTES as ROUTES};

    /// one product: the sequential reference, the builder's CPU path (at a real
    /// shape, whose token count is `t`), and the device on every route with the
    /// weights and the result plane both mapped and copied: all the same words
    #[allow(clippy::too_many_arguments)]
    fn agree(what: &str, sh: Option<&Shape>, t: usize, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize, in_out: bool) {
        let want = witness::matmul_reference(t, x, xs, w, inner, outer, os, out_len, in_out);
        if let Some(sh) = sh {
            assert_eq!(sh.tokens, t);
            let cpu = witness::with_device_products(false, || witness::matmul_parallel(sh, x, xs, w, inner, outer, os, out_len, in_out));
            assert!(cpu == want, "{what}: the CPU product differs from the sequential one");
        }
        for route in ROUTES {
            for view in [true, false] {
                let got = witness_product_with(route, view, t, x, xs, w, inner, outer, os, out_len, in_out).expect("the device product runs").expect("the activations fit i16");
                assert!(got == want, "{what}: the {route:?} device product ({}) differs from the CPU's: {inner} -> {outer}, {t} rows, in_out {in_out}", if view { "mapped" } else { "copied" });
            }
        }
    }

    /// **A4: the device products equal the CPU's on every input class.** On every route, random words
    /// of each class the builder can pass (int8; i16 at ±32767; the full i16 range
    /// with -32768; with and without a sprinkling of zeros; all zeros) times random
    /// int8 weights in [-128, 127], both weight layouts, at sizes with partial tiles
    /// in every dimension and several float slabs (512 terms) and int partials (256),
    /// the last one partial; row strides wider than the rows, and weights at an odd
    /// offset inside a longer buffer (the page view's offset). Then every product the
    /// builder makes at the two rung shapes, through its own CPU path too.
    #[test]
    fn a4_the_device_products_equal_the_cpu_ones_on_every_input_class() {
        let mut r = Rng(0xa4a4_0001);
        let dims = [(1usize, 1usize, 1usize), (5, 7, 3), (64, 32, 64), (65, 33, 65), (128, 256, 64), (128, 513, 70), (100, 1000, 300), (128, 1537, 129), (7, 2049, 8)];
        // (lo, hi, one in `zeros` is zero; 0 = no forced zeros)
        let classes: [(i64, i64, u64); 6] = [(-127, 127, 7), (-32767, 32767, 7), (-32768, 32767, 7), (-32768, 32767, 0), (-32768, -32768, 3), (0, 0, 1)];
        for &(t, inner, outer) in &dims {
            for &(lo, hi, zeros) in &classes {
                for in_out in [false, true] {
                    let (xs, os) = (inner + 3, outer + 5);
                    let x: Vec<i64> = (0..t * xs).map(|_| if zeros > 0 && r.next() % zeros == 0 { 0 } else { r.range(lo, hi) }).collect();
                    let wbig: Vec<i8> = (0..inner * outer + 18).map(|_| r.range(-128, 127) as i8).collect();
                    agree(&format!("class [{lo}, {hi}]"), None, t, &x, xs, &wbig[13..13 + inner * outer], inner, outer, os, t * os, in_out);
                }
            }
        }
        let rung_tc = Shape::rung_tc(&super::super::trained_calib_tests::rung_tc_calibration()).unwrap();
        for sh in [Shape::rung_c6(), rung_tc] {
            let (dp, fp, kvw) = (sh.d_pad, sh.f_pad, sh.kv_heads * sh.head_dim);
            for (lo, hi) in [(-127i64, 127i64), (-32767, 32767), (-32768, 32767)] {
                for (xs, inner, outer, in_out) in [(dp, dp, dp, false), (dp, dp, kvw, false), (dp, dp, fp, true), (fp, fp, dp, true)] {
                    let x: Vec<i64> = (0..sh.t_pad * xs).map(|i| if i / xs >= sh.tokens || i % 7 == 0 { 0 } else { r.range(lo, hi) }).collect();
                    let w: Vec<i8> = (0..inner * outer).map(|_| r.range(-128, 127) as i8).collect();
                    agree(&format!("{} [{lo}, {hi}]", sh.name), Some(&sh), sh.tokens, &x, xs, &w, inner, outer, outer, sh.t_pad * outer, in_out);
                }
            }
        }
    }

    /// **A4: the device products are exact at their extremes.** Every product at
    /// its largest magnitude and one sign throughout, so each float slab sum sits
    /// at its bound (x = 32,767 or -1: low byte 255; x = -32,768: high byte -128;
    /// w = -128), and the int64 recombination is exercised far above 2^31 (2,049
    /// terms of 32,767 x -128 is -8,593,883,136).
    #[test]
    fn a4_the_device_products_are_exact_at_their_extremes() {
        for &(xv, wv) in &[(32767i64, -128i8), (-1, -128), (255, -128), (-32768, -128), (-32768, 127), (32767, 127), (-32767, -127), (-32768, -127)] {
            for &(t, inner, outer) in &[(65usize, 512usize, 7usize), (128, 1100, 65), (64, 2049, 64)] {
                for in_out in [false, true] {
                    let x = vec![xv; t * inner];
                    let w = vec![wv; inner * outer];
                    agree(&format!("x = {xv}, w = {wv}"), None, t, &x, inner, &w, inner, outer, outer, t * outer, in_out);
                }
            }
        }
    }

    /// **A4: what the device does not take stays on the CPU, unchanged.** An
    /// activation outside i16 (one word of 32,768, -32,769 or 2^40) makes the device
    /// return `None` on every route, before any device work, and the builder's
    /// product, though forced onto the device, is the CPU's: the sequential sums.
    #[test]
    fn a4_activations_outside_i16_stay_on_the_cpu() {
        let sh = Shape::rung_c6();
        let mut r = Rng(0xa4a4_0003);
        let (dp, fp) = (sh.d_pad, sh.f_pad);
        for bad in [32768i64, -32769, 1 << 40] {
            let mut x: Vec<i64> = (0..sh.t_pad * dp).map(|_| r.range(-32768, 32767)).collect();
            x[(sh.tokens - 1) * dp + 5] = bad;
            let w: Vec<i8> = (0..dp * fp).map(|_| r.range(-128, 127) as i8).collect();
            for in_out in [false, true] {
                for route in ROUTES {
                    assert!(witness_product_with(route, true, sh.tokens, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, in_out).expect("no device failure").is_none(), "{route:?}: an activation of {bad} went to the device");
                }
                let made = witness::device_products_made();
                let want = witness::matmul_reference(sh.tokens, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, in_out);
                let got = witness::with_device_products(true, || witness::matmul_parallel(&sh, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, in_out));
                assert!(got == want, "an activation of {bad}: the builder's product differs from the sequential one");
                // [A26] an activation outside i16 but inside i32 now goes to the device as two
                // exact i16 halves (`witness::on_device_split`): two device products, the same
                // words; outside i32 (2^40) the CPU path, no device product
                let halves = if bad.unsigned_abs() < 1 << 31 { 2 } else { 0 };
                assert_eq!(witness::device_products_made() - made, halves, "an activation of {bad}: device products made");
            }
        }
    }

    /// **[A26] activations outside i16 on the device as two exact i16 halves.** Words of
    /// R13 LOW+h24's FFN product class (24-bit: `[-2^23, 2^23)`) in the leading input columns
    /// and zeros in the trailing ones (the padded hidden width, which the split skips), then
    /// words across the whole i32 range: each product, forced onto the device, is the
    /// sequential sums word for word, in both weight layouts, and was made as two device
    /// products. A word whose upper half leaves i16 (`i32::MAX`) is declined by the device's
    /// own pack check and stays on the CPU (the same words, no device product).
    #[test]
    fn a26_out_of_i16_activations_split_into_two_exact_device_halves() {
        let sh = Shape::rung_c6();
        let mut r = Rng(0xa26a_0001);
        let (dp, fp) = (sh.d_pad, sh.f_pad);
        for (case, lim, used) in [("24-bit, padded tail", 1i64 << 23, dp / 2 + 3), ("i32", (1i64 << 31) - (1 << 16), dp)] {
            let x: Vec<i64> = (0..sh.t_pad * dp).map(|i| if i % dp < used { r.range(-lim, lim - 1) } else { 0 }).collect();
            let w: Vec<i8> = (0..dp * fp).map(|_| r.range(-128, 127) as i8).collect();
            for in_out in [false, true] {
                let want = witness::matmul_reference(sh.tokens, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, in_out);
                let made = witness::device_products_made();
                let got = witness::with_device_products(true, || witness::matmul_parallel(&sh, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, in_out));
                assert!(got == want, "{case}, in_out {in_out}: the split device product differs from the sequential one");
                assert_eq!(witness::device_products_made() - made, 2, "{case}, in_out {in_out}: two device halves");
            }
        }
        let mut x: Vec<i64> = (0..sh.t_pad * dp).map(|_| r.range(-(1 << 20), 1 << 20)).collect();
        x[3] = i64::from(i32::MAX);
        let w: Vec<i8> = (0..dp * fp).map(|_| r.range(-128, 127) as i8).collect();
        let want = witness::matmul_reference(sh.tokens, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, true);
        let made = witness::device_products_made();
        let got = witness::with_device_products(true, || witness::matmul_parallel(&sh, &x, dp, &w, dp, fp, fp, sh.t_pad * fp, true));
        assert!(got == want, "i32::MAX: the CPU product differs from the sequential one");
        assert_eq!(witness::device_products_made() - made, 0, "i32::MAX: no device product (its upper half leaves i16)");
        eprintln!("A26 | out-of-i16 activations: 24-bit (padded tail) and i32 words split into two exact device halves, both layouts; i32::MAX declined to the CPU; every product the sequential sums");
    }

    /// **A4 acceptance: the builder with its products on the device equals the CPU
    /// builder on every plane, and refuses exactly as it does.** The six profiles of
    /// the H124c test (R13 byte limbs and W16 16-bit planes, the DD dictionary branch,
    /// the rungs, T128 and T256, and the W16R2 8B T128 block the clock is measured
    /// on), every device route, every product of every build forced onto the device
    /// (all seven, counted). The inadmissible inputs (all four at the DD profile)
    /// must return the same error.
    #[test]
    fn a4_the_device_builder_equals_the_cpu_one_on_every_plane() {
        use super::super::range16_tests::{built, case};
        use super::super::shape::{ACCURACY_PROFILES, W16R2_PROFILES, W16_PROFILES};
        for name in ["R13_TINY_T128_LOW", "R13_8B_T128_H24_DD", "R13_RUNG_H24", "W16R2_RUNG_H24", "W16_SHIELD_T256_H24", "W16R2_8B_T128_H24"] {
            let spec = ACCURACY_PROFILES.iter().chain(W16_PROFILES.iter()).chain(W16R2_PROFILES.iter()).find(|s| s.name == name).expect("a listed profile");
            let (sh, data, public, ff) = case(built(spec.profile), 3);
            let build = |x: &[i16]| witness::build_accuracy(&sh, &public, &ff, &data, x);
            let (mut admissible, mut refused) = (0usize, 0usize);
            for s in 0..4usize {
                let x: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
                let cpu = witness::with_device_products(false, || build(&x));
                for route in ROUTES {
                    let made = witness::device_products_made();
                    let dev = with_witness_options(route, true, || witness::with_device_products(true, || build(&x)));
                    let made = witness::device_products_made() - made;
                    match (&cpu, &dev) {
                        (Ok(a), Ok(b)) => {
                            assert_eq!(made, 7, "{name} input {s} {route:?}: the device made {made} of the seven products");
                            assert_eq!(a.planes.len(), b.planes.len(), "{name} input {s}: plane count");
                            for (k, (pa, pb)) in a.planes.iter().zip(b.planes.iter()).enumerate() {
                                assert!(pa == pb, "{name} input {s} {route:?}: plane {k} differs between the device and CPU products");
                            }
                            assert_eq!(a.output_plane, b.output_plane, "{name} input {s}: output plane");
                        }
                        (Err(a), Err(b)) => assert_eq!(a, b, "{name} input {s} {route:?}: the device and CPU builders refuse differently"),
                        (a, b) => panic!("{name} input {s} {route:?}: CPU {:?} against device {:?}", a.as_ref().err(), b.as_ref().err()),
                    }
                }
                if cpu.is_ok() {
                    admissible += 1;
                } else {
                    refused += 1;
                }
            }
            assert!(admissible > 0 || name.ends_with("_DD"), "{name}: no admissible input among the four");
            eprintln!("A4 {name}: {admissible} admissible inputs equal on every plane on all {} device routes, {refused} refused identically", ROUTES.len());
        }
    }

    /// **A4: one block's witness time, CPU products against device products, end to
    /// end** (W16R2 8B T128, the D55 fixture's block and admissible input, as H124).
    /// Each arm is the whole `build_accuracy` (packing, transfers and scatters
    /// included), best of 5 after a warm-up; then the seven products alone at the
    /// same sizes; and the device time split into packing the activations,
    /// presenting the weights, the command buffer and scattering the outputs.
    /// Release; read the numbers as a shared-box estimate.
    #[test]
    #[ignore = "release timing (A4): the W16R2 8B T128 witness with CPU and device products"]
    fn a4_witness_time_per_block_cpu_against_the_device() {
        use super::super::range16_tests::{built, case};
        let (sh, data, public, ff) = case(built(super::super::shape::W16R2_8B_T128_H24), 3);
        let build = |x: &[i16]| witness::build_accuracy(&sh, &public, &ff, &data, x);
        let mut s = 0usize;
        let input = loop {
            let x: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
            match build(&x) {
                Ok(_) => break x,
                Err(_) if s < 6 => s += 1,
                Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
            }
        };
        let reps: usize = std::env::var("HL_A4_REPS").ok().and_then(|v| v.parse().ok()).unwrap_or(5);
        let best = |f: &dyn Fn()| {
            f();
            let mut b = f64::MAX;
            for _ in 0..reps {
                let t0 = std::time::Instant::now();
                f();
                b = b.min(t0.elapsed().as_secs_f64());
            }
            b
        };
        let (t, d, qw, kv, h) = (sh.tokens, sh.width, sh.q_width(), sh.kv_heads * sh.head_dim, sh.hidden);
        let mut r = Rng(0x9e37_79b9_7f4a_7c15);
        let shapes = [(d, qw, false), (d, kv, false), (d, kv, false), (qw, d, false), (d, h, true), (d, h, true), (h, d, true)];
        // dense words at the CPU's i16 fast path (|x| < 2^15; -32768 would send the CPU to its i32 path)
        let operands: Vec<(Vec<i64>, Vec<i8>, usize, usize, bool)> =
            shapes.iter().map(|&(inner, outer, in_out)| ((0..t * inner).map(|_| r.range(-32767, 32767)).collect(), (0..inner * outer).map(|_| r.range(-127, 127) as i8).collect(), inner, outer, in_out)).collect();
        let products = || {
            for (x, w, inner, outer, in_out) in &operands {
                drop(witness::matmul_parallel(&sh, x, *inner, w, *inner, *outer, *outer, t * *outer, *in_out));
            }
        };
        let macs: usize = shapes.iter().map(|&(i, o, _)| t * i * o).sum();
        let threads = rayon::current_num_threads();
        let cpu_all = witness::with_device_products(false, || best(&|| drop(build(&input).unwrap())));
        let cpu_prod = witness::with_device_products(false, || best(&products));
        eprintln!("A4 {} on {threads} threads, best of {reps}: CPU products: whole witness {cpu_all:.4} s, the seven products alone {cpu_prod:.4} s ({:.2} G MACs), the rest {:.4} s", sh.name, macs as f64 / 1e9, cpu_all - cpu_prod);
        for (route, view) in ROUTES.iter().flat_map(|&r| [(r, true), (r, false)]) {
            let (all, prod, (in_place, calls), split) = with_witness_options(route, view, || {
                witness::with_device_products(true, || {
                    let all = best(&|| drop(build(&input).unwrap()));
                    let (n0, p0, s0) = witness_product_stats();
                    let prod = best(&products);
                    let (n1, p1, s1) = witness_product_stats();
                    let calls = (n1 - n0) as f64 / 7.0;
                    (all, prod, (p1 - p0, n1 - n0), std::array::from_fn::<f64, 7, _>(|i| (s1[i] - s0[i]) / calls))
                })
            });
            let phases: Vec<String> = crate::gpu::WITNESS_PRODUCT_PHASES.iter().zip(split).map(|(p, s)| format!("{p} {:.2} ms", s * 1e3)).collect();
            eprintln!(
                "A4 {} device {route:?}, {}: whole witness {all:.4} s ({:.2}x the CPU's), the seven products alone {prod:.4} s ({:.1}x, {:.0} G MACs/s; {in_place} of {calls} written in place); per block of seven: {}",
                sh.name,
                if view { "weights and outputs mapped" } else { "weights and outputs copied" },
                cpu_all / all,
                cpu_prod / prod,
                macs as f64 / prod / 1e9,
                phases.join(", ")
            );
        }
    }
}
