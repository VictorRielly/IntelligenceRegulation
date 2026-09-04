// [UPERF3-AL] microbenchmark: is the 1.4 GB w_data build dominated by page
// faults on a fresh allocation, or by the stores themselves?
use std::time::Instant;

const N: usize = 176_160_768; // Mistral w_len (21 blocks x 4096 x 2048)
const SRC: usize = 58_720_256; // one d x f int8 plane

fn fill(dst: &mut [u64], src: &[i8], threads: usize) {
    let chunk = (dst.len() + threads - 1) / threads;
    std::thread::scope(|s| {
        for (ti, part) in dst.chunks_mut(chunk).enumerate() {
            let src = &src;
            s.spawn(move || {
                let base = ti * chunk;
                for (i, o) in part.iter_mut().enumerate() {
                    let v = src[(base + i) % SRC] as i64;
                    *o = if v >= 0 { v as u64 } else { (0xFFFF_FFFF_0000_0001u64).wrapping_add(v as u64) };
                }
            });
        }
    });
}

fn main() {
    let threads: usize = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(8);
    let src: Vec<i8> = (0..SRC).map(|i| (i % 251) as i8).collect();
    // A: fresh allocation each round (what prove_layer_v3 does today)
    for r in 0..3 {
        let t = Instant::now();
        let mut v = vec![0u64; N];
        let ta = t.elapsed().as_secs_f64();
        fill(&mut v, &src, threads);
        println!("A fresh alloc  round {r}: alloc {ta:.4} s  fill {:.4} s  total {:.4} s (sum {})", t.elapsed().as_secs_f64() - ta, t.elapsed().as_secs_f64(), v[N - 1]);
        drop(v);
    }
    // B: one buffer reused
    let mut v = vec![0u64; N];
    for r in 0..3 {
        let t = Instant::now();
        fill(&mut v, &src, threads);
        println!("B reused       round {r}: fill {:.4} s (sum {})", t.elapsed().as_secs_f64(), v[N - 1]);
    }
}
