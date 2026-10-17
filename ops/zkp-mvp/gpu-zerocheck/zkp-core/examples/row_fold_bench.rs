//! Diagnostic only: synthetic public inputs, no proof or model-speed claim.
use std::hint::black_box;
use std::time::Instant;
use zkp_core::field::{Fp, Fp2};
use zkp_core::mle::{fold_rows_base, fold_rows_i8, fold_rows_i32};

fn measure(mut f: impl FnMut() -> Vec<Fp2>, repeats: usize) -> (f64, f64) {
    for _ in 0..3 { black_box(f()); }
    let mut samples = Vec::with_capacity(repeats);
    for _ in 0..repeats {
        let start = Instant::now();
        black_box(f());
        samples.push(start.elapsed().as_secs_f64());
    }
    samples.sort_by(f64::total_cmp);
    (samples[0], samples[samples.len() / 2])
}

fn main() {
    let args: Vec<_> = std::env::args().collect();
    let threads: usize = args.get(1).map(|s| s.parse().unwrap()).unwrap_or(2);
    let repeats: usize = args.get(2).map(|s| s.parse().unwrap()).unwrap_or(11);
    assert!(threads > 0 && repeats > 0);
    rayon::ThreadPoolBuilder::new().num_threads(threads).build_global().unwrap();
    let rows: usize = 512;
    let weights: Vec<_> = (0..rows).map(|i| Fp2::new(
        Fp::new((i as u64 + 1).wrapping_mul(0xe4d9_38a7_166b_520f)),
        Fp::new((i as u64 + 1).wrapping_mul(0xc359_836d_407a_f18b)),
    )).collect();
    for cols in [768, 2048] {
        for sparse in [false, true] {
            let bytes: Vec<i8> = (0..rows * cols).map(|i| {
                if sparse && i % 100 != 0 { 0 } else { (i.wrapping_mul(151) as u8) as i8 }
            }).collect();
            let ints: Vec<i32> = (0..rows * cols).map(|i| {
                if sparse && i % 100 != 0 { 0 } else { (i.wrapping_mul(40503) as u16) as i16 as i32 }
            }).collect();
            let base_bytes: Vec<_> = bytes.iter().map(|&v| Fp::from_i64(v as i64)).collect();
            let base_ints: Vec<_> = ints.iter().map(|&v| Fp::from_i64(v as i64)).collect();
            assert_eq!(fold_rows_i8(&bytes, rows, cols, &weights), fold_rows_base(&base_bytes, rows, cols, &weights));
            assert_eq!(fold_rows_i32(&ints, rows, cols, &weights), fold_rows_base(&base_ints, rows, cols, &weights));
            let (best, median) = measure(|| fold_rows_i8(black_box(&bytes), rows, cols, black_box(&weights)), repeats);
            println!("{{\"kind\":\"i8\",\"rows\":{rows},\"cols\":{cols},\"sparse\":{sparse},\"threads\":{threads},\"repeats\":{repeats},\"best_s\":{best},\"median_s\":{median},\"reference_equal\":true}}");
            let (best, median) = measure(|| fold_rows_i32(black_box(&ints), rows, cols, black_box(&weights)), repeats);
            println!("{{\"kind\":\"i32\",\"rows\":{rows},\"cols\":{cols},\"sparse\":{sparse},\"threads\":{threads},\"repeats\":{repeats},\"best_s\":{best},\"median_s\":{median},\"reference_equal\":true}}");
        }
    }
}
