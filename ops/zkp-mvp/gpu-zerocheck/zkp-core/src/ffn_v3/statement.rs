//! The public statement, the parameters and the committed-vector layout of
//! the non-hiding v3 FFN layer proof.
//!
//! Moved from `hashline/src/layer.rs` (CL20, round 12): `LayerParams` ->
//! [`Params`], `StatementV3` -> [`Statement`], `LayoutV3` -> [`Layout`],
//! `absorb_statement_v3` -> [`absorb_statement`], plus the LogUp tags, the
//! balanced-remainder window helpers, `pow2_signed`, `absorb_com` and
//! `absorb_mults`. Layout arithmetic, tags, absorb labels and order are
//! unchanged; `hashline::layer` re-exports these under the legacy names.
//! The only additions are `Layout::check` (the shape rule as a `Result`,
//! which `Layout::new` still enforces with the same panic text) and `pub`
//! visibility on the slice helpers the prover and claim builder use.

use crate::field::Fp;
use crate::pcs::{Commitment, PcsParams, Slice};
use crate::tables::Act16Fn;
use crate::transcript::Transcript;

/// The Ligero parameters of a layer: `log_cols` is capped per commitment by
/// the smallest slice it holds (`pcs_for`).
#[derive(Clone, Copy, Debug)]
pub struct Params {
    pub log_cols: u32,
    pub inv_rate: usize,
    pub num_col_checks: usize,
}

impl Params {
    pub fn pcs_for(&self, min_log_slice: u32) -> PcsParams {
        PcsParams { log_cols: self.log_cols.min(min_log_slice), inv_rate: self.inv_rate, num_col_checks: self.num_col_checks }
    }
}

pub const TAG_ACT16: u64 = 3;
pub const TAG_INT16: u64 = 4;
/// The supported signed shift window of the remainder tables (`tag_rem_v3`,
/// `rem_rows`, `pow2_signed` are only defined on it; `Statement::check`
/// enforces it before any of them runs).
pub const SHIFT_MIN: i32 = -8;
pub const SHIFT_MAX: i32 = 16;
/// The supported bound of `t_rows`, `d` and `f` (`Layout::check`): with all
/// three at most 2^24 every offset sum `Layout::new` forms stays below
/// 10 * 2^48 and the proof-shape arithmetic is checked on top of that.
/// Real shapes are far smaller (d 4,096, f 14,336, t_rows 512 at 8B).
pub const MAX_DIM: usize = 1 << 24;
/// The balanced-remainder window table of a signed shift (sh in -8..=16).
pub fn tag_rem_v3(sh: i32) -> u64 {
    64 + (sh + 8) as u64
}
pub fn rem_rows(sh: i32) -> usize {
    if sh <= 0 { 1 } else { 1usize << sh }
}
/// Row i of the window table: the remainder value it stands for.
pub fn rem_value(sh: i32, i: usize) -> i64 {
    if sh <= 0 { 0 } else { i as i64 - (1i64 << (sh - 1)) }
}
/// [UPERF3-AD] pub: the v3 ZK form (zk.rs) builds the same multiplicity tables.
pub fn rem_index(sh: i32, r: i32) -> Option<usize> {
    if sh <= 0 {
        if r == 0 { Some(0) } else { None }
    } else {
        let v = r as i64 + (1i64 << (sh - 1));
        if v >= 0 && v < (1i64 << sh) { Some(v as usize) } else { None }
    }
}
/// The public coefficient of y in acc = coef * y + r: 2^sh, or the inverse
/// of 2^-sh at a negative shift (the exact up-scaling branch).
pub fn pow2_signed(sh: i32) -> Fp {
    if sh >= 0 { Fp::new(1u64 << sh) } else { Fp::new(1u64 << (-sh)).inv() }
}

/// The public statement of one layer: index, rows, widths, the four signed
/// requant shifts (gate, up, hadamard, down), the frozen activation table
/// and its spec digest (absorbed as a string).
#[derive(Clone, Debug)]
pub struct Statement {
    pub l: usize,
    pub t_rows: usize,
    pub d: usize,
    pub f: usize,
    pub shifts: (i32, i32, i32, i32),
    pub act: Act16Fn,
    pub table: [i16; 256],
    pub table_digest: String,
}

impl Statement {
    /// The statement's supported domain, checked BEFORE any layout or shape
    /// arithmetic (C20-R2): the layout rule of `Layout::check` and every
    /// shift inside `SHIFT_MIN..=SHIFT_MAX`. Outside it `rem_rows` would
    /// shift by the width or more and `tag_rem_v3` would wrap.
    pub fn check(&self) -> Result<(), String> {
        Layout::check(self.t_rows, self.d, self.f)?;
        for s in [self.shifts.0, self.shifts.1, self.shifts.2, self.shifts.3] {
            if !(SHIFT_MIN..=SHIFT_MAX).contains(&s) {
                return Err(format!("shift {s} outside the supported window {SHIFT_MIN}..={SHIFT_MAX}"));
            }
        }
        Ok(())
    }

    /// The distinct shifts in ascending order: the remainder tables the
    /// proof carries after the ACT16 and INT16 tables, in this order.
    pub fn distinct_shifts(&self) -> Vec<i32> {
        let (sg, su, sh, sz) = self.shifts;
        let mut shifts = vec![sg, su, sh, sz];
        shifts.sort();
        shifts.dedup();
        shifts
    }
}

/// Element offsets of every slice in the three committed vectors (block-structured).
#[derive(Clone, Debug)]
pub struct Layout {
    pub t_rows: usize, pub d: usize, pub f: usize,
    pub log_t: u32, pub log_db: u32, pub nb_d: usize, pub log_fb: u32, pub nb_f: usize,
    pub tfb: usize, pub tdb: usize, pub wb: usize, pub log_wb: u32, pub log_a_min: u32,
    pub g8: Vec<usize>, pub rg: Vec<usize>, pub a16: Vec<usize>, pub u16: Vec<usize>, pub ru: Vec<usize>, pub h16: Vec<usize>, pub rh: Vec<usize>,
    pub x: Vec<usize>, pub z: Vec<usize>, pub rd: Vec<usize>,
    pub a_len: usize,
    pub wg: Vec<usize>, pub wu: Vec<usize>, pub wd: Vec<usize>,
    pub w_len: usize,
    pub hg: Vec<(usize, usize)>, pub hu: Vec<(usize, usize)>, pub hh: Vec<(usize, usize)>, pub hz: Vec<(usize, usize)>,
    pub h_len: usize,
}

impl Layout {
    /// The supported-shape rule of `new`, as a result: `t_rows`, `d`, `f`
    /// at most `MAX_DIM`; `t_rows` a power of two; `d`, `f` multiples of
    /// their blocks `2^min(log2, 12)` with at least 16 | d, f.
    pub fn check(t_rows: usize, d: usize, f: usize) -> Result<(), String> {
        if t_rows > MAX_DIM || d > MAX_DIM || f > MAX_DIM {
            return Err(format!("t_rows {t_rows} / d {d} / f {f}: above the supported bound 2^24"));
        }
        if !t_rows.is_power_of_two() {
            return Err("t_rows must be a power of two".to_string());
        }
        let log_db = d.trailing_zeros().min(12);
        let log_fb = f.trailing_zeros().min(12);
        let (db, fb) = (1usize << log_db, 1usize << log_fb);
        if !(d % db == 0 && f % fb == 0 && log_db >= 4 && log_fb >= 4) {
            return Err(format!("d {d} / f {f}: need >= 16 | d, f"));
        }
        Ok(())
    }

    pub fn new(t_rows: usize, d: usize, f: usize) -> Layout {
        if let Err(e) = Layout::check(t_rows, d, f) {
            panic!("{e}");
        }
        let log_t = t_rows.trailing_zeros();
        let log_db = d.trailing_zeros().min(12);
        let log_fb = f.trailing_zeros().min(12);
        let (db, fb) = (1usize << log_db, 1usize << log_fb);
        let (nb_d, nb_f) = (d / db, f / fb);
        let tfb = t_rows * fb;
        let tdb = t_rows * db;
        let mut off = 0usize;
        let mut vecn = |n: usize, sz: usize| -> Vec<usize> { (0..n).map(|_| { let o = off; off += sz; o }).collect() };
        let g8 = vecn(nb_f, tfb); let rg = vecn(nb_f, tfb); let a16 = vecn(nb_f, tfb); let u16 = vecn(nb_f, tfb);
        let ru = vecn(nb_f, tfb); let h16 = vecn(nb_f, tfb); let rh = vecn(nb_f, tfb);
        let x = vecn(nb_d, tdb); let z = vecn(nb_d, tdb); let rd = vecn(nb_d, tdb);
        let a_len = off;
        let wb = db * fb;
        let log_wb = log_db + log_fb;
        let mut woff = 0usize;
        let mut wvec = |n: usize| -> Vec<usize> { (0..n).map(|_| { let o = woff; woff += wb; o }).collect() };
        let wg = wvec(nb_d * nb_f); let wu = wvec(nb_d * nb_f); let wd = wvec(nb_f * nb_d);
        let w_len = woff;
        let mut hoff = 0usize;
        let mut hvec = |n: usize, sz: usize| -> Vec<(usize, usize)> { (0..n).map(|_| { let o = hoff; hoff += 2 * sz; (o, o + sz) }).collect() };
        let hg = hvec(nb_f, tfb); let hu = hvec(nb_f, tfb); let hh = hvec(nb_f, tfb); let hz = hvec(nb_d, tdb);
        let h_len = hoff;
        Layout {
            t_rows, d, f, log_t, log_db, nb_d, log_fb, nb_f, tfb, tdb, wb, log_wb, log_a_min: log_t + log_db.min(log_fb),
            g8, rg, a16, u16, ru, h16, rh, x, z, rd, a_len, wg, wu, wd, w_len, hg, hu, hh, hz, h_len,
        }
    }
    pub fn s_f(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_t + self.log_fb } }
    pub fn s_d(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_t + self.log_db } }
    pub fn s_w(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_wb } }
}

/// [UPERF3-AD] pub: the v3 ZK form (zk.rs) absorbs the same statement.
pub fn absorb_statement(tr: &mut Transcript, st: &Statement) {
    tr.absorb(b"profile", b"v3-widened/round");
    tr.absorb_u64(b"layer", st.l as u64);
    tr.absorb_u64(b"t_rows", st.t_rows as u64);
    tr.absorb_u64(b"d", st.d as u64);
    tr.absorb_u64(b"f", st.f as u64);
    let mut sb = Vec::with_capacity(32);
    for s in [st.shifts.0, st.shifts.1, st.shifts.2, st.shifts.3] { sb.extend_from_slice(&(s as i64).to_le_bytes()); }
    tr.absorb(b"shifts-signed", &sb);
    tr.absorb(b"act", st.act.spec_name().as_bytes());
    tr.absorb(b"table", st.table_digest.as_bytes());
}

pub fn absorb_com(tr: &mut Transcript, label: &[u8], c: &Commitment) {
    tr.absorb(label, &c.root);
    tr.absorb_u64(label, c.rows as u64);
}

pub fn absorb_mults(tr: &mut Transcript, mults: &[(u64, Vec<u32>)]) {
    let mut bytes = Vec::new();
    for (tag, m) in mults {
        bytes.extend_from_slice(&tag.to_le_bytes());
        bytes.extend_from_slice(&(m.len() as u64).to_le_bytes());
        for v in m {
            bytes.extend_from_slice(&v.to_le_bytes());
        }
    }
    tr.absorb(b"mults", &bytes);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn layout_shape_rule_and_offsets() {
        assert!(Layout::check(2, 16, 16).is_ok());
        assert!(Layout::check(3, 16, 16).is_err());
        assert!(Layout::check(2, 8, 16).is_err());
        assert!(Layout::check(2, 16, 24).is_err());
        let lay = Layout::new(2, 16, 16);
        assert_eq!((lay.nb_d, lay.nb_f, lay.tfb, lay.tdb, lay.wb, lay.log_wb, lay.log_a_min), (1, 1, 32, 32, 256, 8, 5));
        assert_eq!((lay.a_len, lay.w_len, lay.h_len), (10 * 32, 3 * 256, 2 * 4 * 32));
        assert_eq!(lay.s_w(lay.wd[0]).offset, 2 * 256);
        // the 125M shape: 512 x 768 x 2048 -> blocks of 256 and 2048
        let big = Layout::new(512, 768, 2048);
        assert_eq!((big.nb_d, big.nb_f, big.log_db, big.log_fb), (3, 1, 8, 11));
    }

    /// C20-R2: the statement's own rule refuses shifts outside the
    /// remainder-window domain and absurd dimensions before any arithmetic.
    #[test]
    fn statement_check_refuses_unsupported_shifts_and_dimensions() {
        let (table, table_digest) = crate::tables::int16out_member(Act16Fn::Silu, -3, -11).unwrap();
        let st = Statement { l: 0, t_rows: 2, d: 16, f: 16, shifts: (7, 0, 14, 6), act: Act16Fn::Silu, table, table_digest };
        assert!(st.check().is_ok());
        assert!(Statement { shifts: (64, 0, 14, 6), ..st.clone() }.check().is_err());
        assert!(Statement { shifts: (7, -9, 14, 6), ..st.clone() }.check().is_err());
        assert!(Statement { shifts: (-8, 16, 0, 1), ..st.clone() }.check().is_ok());
        assert!(Statement { t_rows: 1 << 40, ..st.clone() }.check().is_err());
        assert!(Statement { f: usize::MAX, ..st.clone() }.check().is_err());
        assert!(Layout::check(1 << 40, 16, 16).is_err());
    }

    #[test]
    fn tags_and_windows() {
        assert_eq!(tag_rem_v3(-8), 64);
        assert_eq!(tag_rem_v3(16), 88);
        assert_eq!(rem_rows(0), 1);
        assert_eq!(rem_rows(7), 128);
        assert_eq!(rem_index(7, -64), Some(0));
        assert_eq!(rem_index(7, 63), Some(127));
        assert_eq!(rem_index(7, 64), None);
        assert_eq!(rem_index(0, 0), Some(0));
        assert_eq!(rem_index(0, 1), None);
        assert_eq!(rem_value(7, 0), -64);
        assert_eq!(pow2_signed(3), Fp::new(8));
        assert_eq!(pow2_signed(-3).mul(Fp::new(8)), Fp::ONE);
    }
}
