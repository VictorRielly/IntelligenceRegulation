//! The exact integer FFN chain (TARGET_CONTRACT section 2, floor
//! requant, the frozen v2 SiLU member), reproduced from the export bins
//! in plain Rust and checked against the sidecar's per-layer z digests.
//! This is the witness every proof below is about; nothing in the
//! proving code recomputes semantics — it consumes these planes.
//!
//!   gacc = X . WgT (exact, |gacc| < 2^24)     uacc = X . WuT
//!   g8 = gacc >> sh_g, rg = gacc & (2^sh_g - 1)    (floor requant; g8 in [-128,127])
//!   u8 = uacc >> sh_u, ru = ...                     (u8 in [-128,127])
//!   a8 = S[g8 + 128]                                (the 256-row member table)
//!   hh = a8 * u8 (|hh| <= 128*128)
//!   h8 = hh >> sh_h, rh = ...                       (h8 in [-128,127])
//!   dacc = h8 . WdT (exact, |dacc| < 2^26)
//!   z = dacc >> sh_z, rd = ...                      (z in [-128,127])

use crate::export::{i8_digest, LayerExport, D, F, T};
use rayon::prelude::*;

pub struct LayerWitness {
    pub l: usize,
    pub shifts: (u32, u32, u32, u32),
    pub table: [i8; 256],
    pub table_digest: String,
    pub e_gate: i32,
    pub e_act: i32,
    // planes (row-major)
    pub x: Vec<i8>,    // T x D
    pub wg_t: Vec<i8>, // D x F
    pub wu_t: Vec<i8>, // D x F
    pub wd_t: Vec<i8>, // F x D
    pub g8: Vec<i32>,  // T x F
    pub rg: Vec<i32>,
    pub a8: Vec<i32>,
    pub u8v: Vec<i32>,
    pub ru: Vec<i32>,
    pub h8: Vec<i32>,
    pub rh: Vec<i32>,
    pub z: Vec<i32>,   // T x D
    pub rd: Vec<i32>,
    pub range_ok: bool,
    pub z_digest: String,
}

/// c[i][j] = sum_k a[i][k] * b_t[k][j]; a rows x inner (i8), b_t inner x cols (i8).
/// Exact in i32 for inner <= 2^15 with int8 inputs.
pub fn matmul_i8_i32(a: &[i8], b_t: &[i8], rows: usize, inner: usize, cols: usize) -> Vec<i32> {
    let mut c = vec![0i32; rows * cols];
    c.par_chunks_mut(cols).enumerate().for_each(|(i, crow)| {
        for k in 0..inner {
            let av = a[i * inner + k] as i32;
            if av == 0 { continue; }
            let brow = &b_t[k * cols..(k + 1) * cols];
            for (cv, &bv) in crow.iter_mut().zip(brow.iter()) {
                *cv += av * bv as i32;
            }
        }
    });
    c
}

pub fn matmul_i32_i8_i32(a: &[i32], b_t: &[i8], rows: usize, inner: usize, cols: usize) -> Vec<i32> {
    let mut c = vec![0i32; rows * cols];
    c.par_chunks_mut(cols).enumerate().for_each(|(i, crow)| {
        for k in 0..inner {
            let av = a[i * inner + k];
            if av == 0 { continue; }
            let brow = &b_t[k * cols..(k + 1) * cols];
            for (cv, &bv) in crow.iter_mut().zip(brow.iter()) {
                *cv += av * bv as i32;
            }
        }
    });
    c
}

#[inline]
fn floor_requant(acc: &[i32], shift: u32) -> (Vec<i32>, Vec<i32>) {
    let mask = (1i32 << shift) - 1;
    let y: Vec<i32> = acc.iter().map(|&a| a >> shift).collect();
    let r: Vec<i32> = acc.iter().map(|&a| a & mask).collect();
    (y, r)
}

fn in_i8(v: &[i32]) -> bool {
    v.iter().all(|&a| (-128..=127).contains(&a))
}

/// Derive the chain. `table_override` swaps the member table (tamper legs).
pub fn derive(ex: &LayerExport) -> LayerWitness {
    let (table, table_digest) = crate::silu::silu_v2_member(ex.e_gate, ex.e_act);
    derive_with_table(ex, table, table_digest)
}

pub fn derive_with_table(ex: &LayerExport, table: [i8; 256], table_digest: String) -> LayerWitness {
    let (sh_g, sh_u, sh_h, sh_z) = ex.shifts;
    let gacc = matmul_i8_i32(&ex.x, &ex.wg_t, T, D, F);
    let uacc = matmul_i8_i32(&ex.x, &ex.wu_t, T, D, F);
    let (g8, rg) = floor_requant(&gacc, sh_g);
    let (u8v, ru) = floor_requant(&uacc, sh_u);
    drop(gacc);
    drop(uacc);
    let g_ok = in_i8(&g8);
    let u_ok = in_i8(&u8v);
    let a8: Vec<i32> = g8.iter().map(|&g| table[((g as i32 + 128).clamp(0, 255)) as usize] as i32).collect();
    let hh: Vec<i32> = a8.iter().zip(u8v.iter()).map(|(&a, &u)| a * u).collect();
    let (h8, rh) = floor_requant(&hh, sh_h);
    let h_ok = in_i8(&h8);
    let dacc = matmul_i32_i8_i32(&h8, &ex.wd_t, T, F, D);
    let (z, rd) = floor_requant(&dacc, sh_z);
    let z_ok = in_i8(&z);
    let z_i8: Vec<i8> = z.iter().map(|&v| v as i8).collect();
    let z_digest = i8_digest(&z_i8);
    LayerWitness {
        l: ex.l,
        shifts: ex.shifts,
        table,
        table_digest,
        e_gate: ex.e_gate,
        e_act: ex.e_act,
        x: ex.x.clone(),
        wg_t: ex.wg_t.clone(),
        wu_t: ex.wu_t.clone(),
        wd_t: ex.wd_t.clone(),
        g8, rg, a8, u8v, ru, h8, rh, z, rd,
        range_ok: g_ok && u_ok && h_ok && z_ok,
        z_digest,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn floor_requant_is_euclidean() {
        for &s in &[1u32, 5, 7, 10] {
            let m = 1i32 << s;
            let acc: Vec<i32> = (-5000..5000).collect();
            let (y, r) = floor_requant(&acc, s);
            for (i, &a) in acc.iter().enumerate() {
                assert_eq!(y[i], a.div_euclid(m));
                assert_eq!(r[i], a.rem_euclid(m));
                assert_eq!(a, y[i] * m + r[i]);
            }
        }
    }

    #[test]
    fn matmul_small() {
        let a: Vec<i8> = vec![1, 2, 3, 4, 5, 6]; // 2 x 3
        let b: Vec<i8> = vec![7, 8, 9, 10, 11, 12]; // 3 x 2
        let c = matmul_i8_i32(&a, &b, 2, 3, 2);
        assert_eq!(c, vec![58, 64, 139, 154]);
    }
}
