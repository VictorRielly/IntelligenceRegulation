use rayon::prelude::*;
use std::time::Instant;
use zkp_core::field::{Fp, Fp2};

const ZD: &str = "zero denominator";
const PAR_MIN: usize = 1 << 14;

fn helper_one(v: i64, alpha: Fp2, g: Fp2, tbl: &[Option<Fp2>]) -> Result<Fp2, String> {
    match usize::try_from(v) {
        Ok(k) if k < 256 => tbl[k].ok_or_else(|| ZD.to_string()),
        _ => {
            let d = alpha.sub(Fp2::from_i64(v).add(g));
            if d.is_zero() { Err(ZD.to_string()) } else { Ok(d.inv()) }
        }
    }
}

// the M4c production form
fn cur(re: &mut [Fp], im: &mut [Fp], a: &[i64], b: Option<&[i64]>, alpha: Fp2, g: Fp2, tbl: &[Option<Fp2>]) -> Result<(), String> {
    let word = |i: usize| -> Result<Fp2, String> {
        let x = helper_one(a[i], alpha, g, tbl)?;
        match b { Some(b) => Ok(x.add(helper_one(b[i], alpha, g, tbl)?)), None => Ok(x) }
    };
    re.par_iter_mut().zip(im.par_iter_mut()).enumerate().try_for_each(|(i, (r, m))| {
        let v = word(i)?;
        *r = v.c0;
        *m = v.c1;
        Ok(())
    })
}

// chunked, plain inner loop, one flag per chunk
fn chunked(re: &mut [Fp], im: &mut [Fp], a: &[i64], b: Option<&[i64]>, alpha: Fp2, g: Fp2, tbl: &[Option<Fp2>], ch: usize) -> Result<(), String> {
    let fill = |base: usize, r: &mut [Fp], m: &mut [Fp]| -> bool {
        let a = &a[base..base + r.len()];
        match b {
            Some(b) => {
                let b = &b[base..base + r.len()];
                for j in 0..r.len() {
                    let (Ok(x), Ok(y)) = (helper_one(a[j], alpha, g, tbl), helper_one(b[j], alpha, g, tbl)) else { return false };
                    let v = x.add(y);
                    r[j] = v.c0;
                    m[j] = v.c1;
                }
            }
            None => {
                for j in 0..r.len() {
                    let Ok(v) = helper_one(a[j], alpha, g, tbl) else { return false };
                    r[j] = v.c0;
                    m[j] = v.c1;
                }
            }
        }
        true
    };
    let ok = re.par_chunks_mut(ch).zip(im.par_chunks_mut(ch)).enumerate().map(|(c, (r, m))| fill(c * ch, r, m)).reduce(|| true, |x, y| x && y);
    if ok { Ok(()) } else { Err(ZD.to_string()) }
}

fn main() {
    let n = 524288usize;
    let helpers = 17usize;
    let mut s = 12345u64;
    let mut rnd = move || { s ^= s << 13; s ^= s >> 7; s ^= s << 17; s };
    let cols: Vec<Vec<i64>> = (0..2 * helpers).map(|_| (0..n).map(|_| (rnd() % 256) as i64).collect()).collect();
    let alpha = Fp2::new(Fp::new(rnd()), Fp::new(rnd()));
    let g = Fp2::new(Fp::new(rnd()), Fp::new(rnd()));
    let tbl: Vec<Option<Fp2>> = (0..256).map(|v| { let d = alpha.sub(Fp2::from_i64(v).add(g)); if d.is_zero() { None } else { Some(d.inv()) } }).collect();
    println!("threads {}", rayon::current_num_threads());
    let mut h1 = vec![Fp::ZERO; 2 * helpers * n];
    let mut h2 = vec![Fp::ZERO; 2 * helpers * n];
    for rep in 0..3 {
        let t = Instant::now();
        for k in 0..helpers {
            let (re, rest) = h1[2 * k * n..].split_at_mut(n);
            cur(re, &mut rest[..n], &cols[2 * k], Some(&cols[2 * k + 1]), alpha, g, &tbl).unwrap();
        }
        let t1 = t.elapsed().as_secs_f64();
        for ch in [1usize << 10, 1 << 12, 1 << 14] {
            let t = Instant::now();
            for k in 0..helpers {
                let (re, rest) = h2[2 * k * n..].split_at_mut(n);
                chunked(re, &mut rest[..n], &cols[2 * k], Some(&cols[2 * k + 1]), alpha, g, &tbl, ch).unwrap();
            }
            println!("rep {rep}: current {t1:.4} s | chunked {ch} {:.4} s | equal {}", t.elapsed().as_secs_f64(), h1 == h2);
        }
        for ch in [1usize << 12, 1 << 13, 1 << 14] {
            let t = Instant::now();
            let mut items: Vec<(&mut [Fp], &mut [Fp], &[i64], &[i64])> = Vec::new();
            for (k, pair) in h2.chunks_mut(2 * n).enumerate() {
                let (re, im) = pair.split_at_mut(n);
                for (c, (r, m)) in re.chunks_mut(ch).zip(im.chunks_mut(ch)).enumerate() {
                    let base = c * ch;
                    let l = r.len();
                    items.push((r, m, &cols[2 * k][base..base + l], &cols[2 * k + 1][base..base + l]));
                }
            }
            let ok = items.into_par_iter().map(|(r, m, a, b)| {
                for j in 0..r.len() {
                    let (Ok(x), Ok(y)) = (helper_one(a[j], alpha, g, &tbl), helper_one(b[j], alpha, g, &tbl)) else { return false };
                    let v = x.add(y);
                    r[j] = v.c0;
                    m[j] = v.c1;
                }
                true
            }).reduce(|| true, |x, y| x && y);
            println!("rep {rep}: one region, chunk {ch} {:.4} s | ok {ok} equal {}", t.elapsed().as_secs_f64(), h1 == h2);
        }
        let t = Instant::now();
        for k in 0..helpers {
            let (re, rest) = h2[2 * k * n..].split_at_mut(n);
            let a = &cols[2 * k]; let b = &cols[2 * k + 1];
            for j in 0..n { let v = helper_one(a[j], alpha, g, &tbl).unwrap().add(helper_one(b[j], alpha, g, &tbl).unwrap()); re[j] = v.c0; rest[j] = v.c1; }
        }
        println!("rep {rep}: sequential {:.4} s", t.elapsed().as_secs_f64());
        let _ = PAR_MIN;
    }
}
