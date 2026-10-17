//! Bounded, CPU-only witness matmul A/B. No model exports or proof work.
//! Run release builds under `flock /tmp/zk-heavy.lock ... --threads 1|8`.
//! Every cell keeps increasing-k accumulation; no arithmetic reassociation.
//! The blocked functions are experimental: local A/B did not justify replacing
//! either production loop. Keeping them here makes that decision reproducible.

use rayon::prelude::*;
use std::hint::black_box;
use std::io::Write;
use std::time::{Duration, Instant};

macro_rules! blocked {
    ($name:ident, $input:ty, $output:ty) => {
        fn $name(a: &[$input], b: &[i8], rows: usize, inner: usize, cols: usize) -> Vec<$output> {
            let mut c = vec![0; rows * cols];
            c.par_chunks_mut(4 * cols).enumerate().for_each(|(tile, crows)| {
                let first = tile * 4;
                if crows.len() != 4 * cols {
                    for (r, crow) in crows.chunks_mut(cols).enumerate() {
                        for k in 0..inner {
                            let av = a[(first + r) * inner + k] as $output;
                            if av == 0 { continue; }
                            for (cv, &bv) in crow.iter_mut().zip(&b[k * cols..(k + 1) * cols]) {
                                *cv += av * bv as $output;
                            }
                        }
                    }
                    return;
                }
                let (c0, rest) = crows.split_at_mut(cols);
                let (c1, rest) = rest.split_at_mut(cols);
                let (c2, c3) = rest.split_at_mut(cols);
                for j0 in (0..cols).step_by(128) {
                    let end = (j0 + 128).min(cols);
                    for k in 0..inner {
                        let a0 = a[first * inner + k] as $output;
                        let a1 = a[(first + 1) * inner + k] as $output;
                        let a2 = a[(first + 2) * inner + k] as $output;
                        let a3 = a[(first + 3) * inner + k] as $output;
                        if a0 == 0 && a1 == 0 && a2 == 0 && a3 == 0 { continue; }
                        let weights = &b[k * cols + j0..k * cols + end];
                        for ((((c0, c1), c2), c3), &bv) in c0[j0..end].iter_mut()
                            .zip(&mut c1[j0..end]).zip(&mut c2[j0..end]).zip(&mut c3[j0..end]).zip(weights) {
                            let bv = bv as $output;
                            *c0 += a0 * bv;
                            *c1 += a1 * bv;
                            *c2 += a2 * bv;
                            *c3 += a3 * bv;
                        }
                    }
                }
            });
            c
        }
    };
}
blocked!(blocked_i8, i8, i32);
blocked!(blocked_i32, i32, i64);

// Independently ordered scalar oracle; i128 is wide enough for all these
// bounded synthetic inputs. It does not duplicate the blocked loop structure.
fn oracle<T: Copy + Into<i128>>(a: &[T], b: &[i8], rows: usize, inner: usize, cols: usize) -> Vec<i128> {
    (0..rows).flat_map(|r| (0..cols).map(move |j| {
        let mut sum = 0i128;
        for k in 0..inner { sum += a[r * inner + k].into() * i128::from(b[k * cols + j]); }
        sum
    })).collect()
}

fn random(state: &mut u64) -> u64 {
    *state = state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    *state >> 32
}

fn median(values: &[f64]) -> f64 {
    let mut ordered = values.to_vec();
    ordered.sort_by(f64::total_cmp);
    ordered[(ordered.len() - 1) / 2]
}

fn measure<T: PartialEq + std::fmt::Debug>(mut f: impl FnMut() -> Vec<T>, expected: &[T]) -> f64 {
    let start = Instant::now();
    let result = black_box(f());
    let elapsed = start.elapsed().as_secs_f64();
    assert_eq!(result, expected, "A/B output mismatch");
    elapsed
}

fn record(log: &mut Option<std::fs::File>, line: String) {
    println!("{line}");
    if let Some(file) = log { writeln!(file, "{line}").unwrap(); }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut threads = 8;
    let mut reps = 5;
    let mut log_path = None;
    for pair in args.chunks(2) {
        assert_eq!(pair.len(), 2, "options: --threads 1..8 --reps 1..9 --log NEW_PATH");
        match pair[0].as_str() {
            "--threads" => threads = pair[1].parse::<usize>().unwrap(),
            "--reps" => reps = pair[1].parse::<usize>().unwrap(),
            "--log" => log_path = Some(pair[1].clone()),
            _ => panic!("unknown option {}", pair[0]),
        }
    }
    assert!((1..=8).contains(&threads) && (1..=9).contains(&reps));
    let mut log = log_path.map(|path| std::fs::OpenOptions::new().write(true).create_new(true).open(path).unwrap());
    let cpu = std::fs::read_to_string("/proc/cpuinfo").unwrap_or_default();
    record(&mut log, format!("ZK60_WITNESS_BENCH threads={threads} reps={reps} cpu={:?} rustflags={:?}",
             cpu.lines().find(|line| line.starts_with("model name")).unwrap_or("unavailable"), std::env::var("RUSTFLAGS")));
    record(&mut log, "Scope: synthetic CPU matmul only, allocation included, comparisons excluded; no 8B or complete-witness throughput claim.".into());
    let pool = rayon::ThreadPoolBuilder::new().num_threads(threads).build().unwrap();
    let start = Instant::now();
    pool.install(|| {
        let mut state = 42;
        for &(rows, inner, cols) in &[(32, 768, 2048), (64, 1024, 2048), (17, 769, 2049), (32, 2048, 768), (64, 2048, 1024), (17, 2049, 769)] {
            let weights: Vec<i8> = (0..inner * cols).map(|_| random(&mut state) as i8).collect();
            let a: Vec<i8> = (0..rows * inner).map(|i| if i % 11 == 0 { 0 } else { random(&mut state) as i8 }).collect();
            let a32: Vec<i32> = (0..rows * inner).map(|i| if i % 11 == 0 { 0 } else { random(&mut state) as i16 as i32 }).collect();
            let expected = hashline::chain::matmul_i8_i32(&a, &weights, rows, inner, cols);
            let expected64 = hashline::export_v3::matmul_i32_i8_i64(&a32, &weights, rows, inner, cols);
            assert!(expected.iter().zip(oracle(&a, &weights, rows, inner, cols)).all(|(&x, y)| i128::from(x) == y));
            assert!(expected64.iter().zip(oracle(&a32, &weights, rows, inner, cols)).all(|(&x, y)| i128::from(x) == y));
            let (mut baseline, mut candidate, mut baseline64, mut candidate64) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
            // One untimed invocation warms both paths before alternating A/B order.
            assert_eq!(blocked_i8(&a, &weights, rows, inner, cols), expected);
            assert_eq!(blocked_i32(&a32, &weights, rows, inner, cols), expected64);
            for rep in 0..reps {
                if start.elapsed() > Duration::from_secs(30) { panic!("bounded benchmark deadline exceeded; reduce --reps"); }
                let mut run_base = || {
                    baseline.push(measure(|| hashline::chain::matmul_i8_i32(&a, &weights, rows, inner, cols), &expected));
                    baseline64.push(measure(|| hashline::export_v3::matmul_i32_i8_i64(&a32, &weights, rows, inner, cols), &expected64));
                };
                let mut run_candidate = || {
                    candidate.push(measure(|| blocked_i8(&a, &weights, rows, inner, cols), &expected));
                    candidate64.push(measure(|| blocked_i32(&a32, &weights, rows, inner, cols), &expected64));
                };
                if rep % 2 == 0 { run_base(); run_candidate(); } else { run_candidate(); run_base(); }
            }
            for (kind, b, c) in [("i8xi8_i32", baseline, candidate), ("i32xi8_i64", baseline64, candidate64)] {
                record(&mut log, format!("AB kind={kind} shape={rows}x{inner}x{cols} baseline_s={:.6} blocked_s={:.6} speedup={:.3} equal=true samples_baseline={b:?} samples_blocked={c:?}", median(&b), median(&c), median(&b) / median(&c)));
            }
        }
    });
    record(&mut log, format!("DONE elapsed_s={:.3} independent_scalar_oracle=true", start.elapsed().as_secs_f64()));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn witness_blocked_candidates_match_independent_oracle_with_tails() {
        for &(rows, inner, cols) in &[(0, 3, 5), (1, 0, 7), (1, 1, 1), (3, 7, 5),
                                     (4, 9, 127), (5, 13, 128), (7, 17, 129), (9, 33, 259)] {
            let values = [i8::MIN, -127, -1, 0, 1, i8::MAX];
            let wide = [i32::MIN, i32::MAX, -32768, 32767, -1, 0, 1];
            let a: Vec<i8> = (0..rows * inner).map(|i| values[(i * 5 + 1) % values.len()]).collect();
            let a32: Vec<i32> = (0..rows * inner).map(|i| wide[(i * 3 + 1) % wide.len()]).collect();
            let b: Vec<i8> = (0..inner * cols).map(|i| values[(i * 7 + 2) % values.len()]).collect();
            let expected: Vec<i32> = oracle(&a, &b, rows, inner, cols).into_iter().map(|v| i32::try_from(v).unwrap()).collect();
            let expected64: Vec<i64> = oracle(&a32, &b, rows, inner, cols).into_iter().map(|v| i64::try_from(v).unwrap()).collect();
            assert_eq!(blocked_i8(&a, &b, rows, inner, cols), expected);
            assert_eq!(blocked_i32(&a32, &b, rows, inner, cols), expected64);
            assert_eq!(blocked_i8(&vec![0; a.len()], &b, rows, inner, cols), vec![0; rows * cols]);
            assert_eq!(blocked_i32(&vec![0; a32.len()], &b, rows, inner, cols), vec![0; rows * cols]);
            assert_eq!(blocked_i8(&a, &vec![0; b.len()], rows, inner, cols), vec![0; rows * cols]);
            assert_eq!(blocked_i32(&a32, &vec![0; b.len()], rows, inner, cols), vec![0; rows * cols]);
        }
    }

    #[test]
    fn witness_blocked_candidate_preserves_prefix_overflow_behavior() {
        let checked = std::panic::catch_unwind(|| black_box(i32::MAX) + 1).is_err();
        let inner = 131073;
        let a = vec![i8::MIN; 4 * inner];
        for last in [i8::MIN, i8::MAX] {
            let mut b = vec![i8::MIN; inner];
            b[inner - 1] = last;
            let result = std::panic::catch_unwind(|| blocked_i8(&a, &b, 4, inner, 1));
            if checked {
                assert!(result.is_err());
            } else {
                assert_eq!(result.unwrap(), vec![(131072i64 * 16384 + i64::from(i8::MIN) * i64::from(last)) as i32; 4]);
            }
        }
    }

    #[test]
    fn witness_blocked_candidates_keep_zero_column_rejection() {
        assert!(std::panic::catch_unwind(|| blocked_i8(&[], &[], 0, 0, 0)).is_err());
        assert!(std::panic::catch_unwind(|| blocked_i32(&[], &[], 0, 0, 0)).is_err());
    }
}
