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
