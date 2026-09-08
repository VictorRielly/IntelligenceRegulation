//! The proof object of the non-hiding v3 FFN layer proof, its frozen byte
//! encoding and a shape-directed bounded decoder.
//!
//! `Proof` and `size_bytes` / `to_bytes` are `LayerProofV3` of
//! `hashline/src/layer.rs` (CL20, round 12), unchanged except for the type
//! of the last field: the legacy struct carried
//! `cpcs_open: Option<pcs_compact::BatchOpening>`, the ONE batched opening
//! of hashline's compact-PCS experiment (`--pcs compact`). The core does not
//! name that experiment; the slot is generic, `Proof<X = NoExtra>`, and
//! hashline's `LayerProofV3` is `Proof<pcs_compact::BatchOpening>`, so its
//! consumers and bytes are unchanged while a core proof cannot carry one
//! (`NoExtra` has no values).
//!
//! The encoding has no length prefixes and no envelope: every field's size
//! is a function of `(Statement, Params)` ([`Shape`]), which is what makes
//! [`Proof::from_bytes`] bounded. It reads exactly the shape, and refuses
//! short input, trailing bytes, a commitment whose `rows`/`log_cols` disagree
//! with the layout, a multiplicity table with the wrong tag or length, a
//! column index `>= enc_cols`, and any 8-byte word read as a field element
//! that is not the canonical representative (`>= P`; `Fp::new` would reduce
//! it silently and `to_bytes(from_bytes(b)) != b`). It never panics on
//! input bytes; the statement and parameters are trusted public inputs whose
//! own rule is `Layout::check` / `Params::check`.

use super::statement::{rem_rows, tag_rem_v3, Layout, Params, Statement, TAG_ACT16, TAG_INT16};
use crate::field::{Fp, Fp2, P};
use crate::merkle::Digest;
use crate::pcs::{Commitment, Opening, PcsParams};
use crate::sumcheck::SumcheckProof;
use std::fmt;

/// What the proof's optional extra opening must be able to do: count and
/// write its frozen bytes after the three Ligero openings.
pub trait ExtraOpening {
    fn size_bytes(&self) -> usize;
    fn write_bytes(&self, out: &mut Vec<u8>);
}

/// The core's extra opening: none exists.
#[derive(Clone, Debug)]
pub enum NoExtra {}

impl ExtraOpening for NoExtra {
    fn size_bytes(&self) -> usize {
        match *self {}
    }
    fn write_bytes(&self, _out: &mut Vec<u8>) {
        match *self {}
    }
}

#[derive(Clone, Debug)]
pub struct Proof<X = NoExtra> {
    pub w_com: Option<Commitment>,
    pub a_com: Option<Commitment>,
    pub h_com: Option<Commitment>,
    pub mults: Vec<(u64, Vec<u32>)>,
    pub gu_claims: Vec<Fp2>,
    pub gu_sc: SumcheckProof,
    pub gu_term: Vec<Fp2>,
    pub d_claims: Vec<Fp2>,
    pub d_sc: SumcheckProof,
    pub d_term: Vec<Fp2>,
    pub zcf_sc: SumcheckProof,
    pub zcf_term: Vec<Fp2>,
    pub zcd_sc: SumcheckProof,
    pub zcd_term: Vec<Fp2>,
    pub helper_sums: Vec<Fp2>,
    pub w_open: Opening,
    pub a_open: Opening,
    pub h_open: Opening,
    /// [UPERF3-AF] under hashline's `--pcs compact`: the ONE batched opening of W, A and H
    /// (the three above stay empty). The field keeps its legacy name for those consumers.
    pub cpcs_open: Option<X>,
}

impl<X> Default for Proof<X> {
    fn default() -> Proof<X> {
        Proof {
            w_com: None,
            a_com: None,
            h_com: None,
            mults: Vec::new(),
            gu_claims: Vec::new(),
            gu_sc: SumcheckProof::default(),
            gu_term: Vec::new(),
            d_claims: Vec::new(),
            d_sc: SumcheckProof::default(),
            d_term: Vec::new(),
            zcf_sc: SumcheckProof::default(),
            zcf_term: Vec::new(),
            zcd_sc: SumcheckProof::default(),
            zcd_term: Vec::new(),
            helper_sums: Vec::new(),
            w_open: Opening::default(),
            a_open: Opening::default(),
            h_open: Opening::default(),
            cpcs_open: None,
        }
    }
}

impl<X: ExtraOpening> Proof<X> {
    pub fn size_bytes(&self) -> usize {
        let coms = 3 * (32 + 8 + 4);
        let mults: usize = self.mults.iter().map(|(_, m)| 8 + 4 + m.len() * 4).sum();
        let f2 = |v: &Vec<Fp2>| v.len() * 16;
        coms + mults + f2(&self.gu_claims) + self.gu_sc.size_bytes() + f2(&self.gu_term)
            + f2(&self.d_claims) + self.d_sc.size_bytes() + f2(&self.d_term)
            + self.zcf_sc.size_bytes() + f2(&self.zcf_term) + self.zcd_sc.size_bytes() + f2(&self.zcd_term)
            + f2(&self.helper_sums) + self.w_open.size_bytes() + self.a_open.size_bytes() + self.h_open.size_bytes()
            + self.cpcs_open.as_ref().map(|b| b.size_bytes()).unwrap_or(0)
    }
    /// The flat little-endian encoding `size_bytes` counts (the CPU/GPU byte-identity gate).
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.size_bytes());
        let com = |out: &mut Vec<u8>, c: &Option<Commitment>| {
            let c = c.as_ref().expect("commitment");
            out.extend_from_slice(&c.root);
            out.extend_from_slice(&(c.rows as u64).to_le_bytes());
            out.extend_from_slice(&c.log_cols.to_le_bytes());
        };
        com(&mut out, &self.w_com);
        com(&mut out, &self.a_com);
        com(&mut out, &self.h_com);
        for (tag, m) in &self.mults {
            out.extend_from_slice(&tag.to_le_bytes());
            out.extend_from_slice(&(m.len() as u32).to_le_bytes());
            for v in m { out.extend_from_slice(&v.to_le_bytes()); }
        }
        let f2 = |out: &mut Vec<u8>, v: &Vec<Fp2>| { for x in v { out.extend_from_slice(&x.to_bytes()); } };
        f2(&mut out, &self.gu_claims);
        self.gu_sc.write_bytes(&mut out);
        f2(&mut out, &self.gu_term);
        f2(&mut out, &self.d_claims);
        self.d_sc.write_bytes(&mut out);
        f2(&mut out, &self.d_term);
        self.zcf_sc.write_bytes(&mut out);
        f2(&mut out, &self.zcf_term);
        self.zcd_sc.write_bytes(&mut out);
        f2(&mut out, &self.zcd_term);
        f2(&mut out, &self.helper_sums);
        self.w_open.write_bytes(&mut out);
        self.a_open.write_bytes(&mut out);
        self.h_open.write_bytes(&mut out);
        if let Some(b) = &self.cpcs_open { b.write_bytes(&mut out); } // [UPERF3-AF]
        debug_assert_eq!(out.len(), self.size_bytes());
        out
    }
}

// ---------------------------------------------------------------------------
// the shape: every field length as a function of (Statement, Params)
// ---------------------------------------------------------------------------

/// The matmul sumchecks (`gu`, `d`) are degree 2; the zero-checks degree 4.
pub const MATMUL_DEGREE: usize = 2;
pub const ZEROCHECK_DEGREE: usize = 4;

/// One Ligero opening's shape: its parameters, the committed rows and the
/// number of column-weight groups the claim builder forms (W: the `p3` and
/// `p6` points; A: `rho_f` and `rho_d`; H: `rho_f`, `rho_d` and the sums).
#[derive(Clone, Copy, Debug)]
pub struct OpeningShape {
    pub pcs: PcsParams,
    pub rows: usize,
    pub groups: usize,
}

impl OpeningShape {
    pub fn cols(&self) -> usize { self.pcs.cols() }
    pub fn enc_cols(&self) -> usize { self.pcs.enc_cols() }
    /// Merkle path length over `enc_cols` leaves (a power of two).
    pub fn path_len(&self) -> usize { self.enc_cols().trailing_zeros() as usize }
    pub fn column_bytes(&self) -> usize { 8 + self.rows * 8 + self.path_len() * 32 }
    pub fn bytes(&self) -> usize { (self.groups + 1) * self.cols() * 16 + self.pcs.num_col_checks * self.column_bytes() }
}

/// The proof shape of `(Statement, Params)`.
#[derive(Clone, Debug)]
pub struct Shape {
    /// (tag, entries) of every multiplicity table, in proof order.
    pub mults: Vec<(u64, usize)>,
    pub gu_claims: usize,
    pub gu_rounds: usize,
    pub gu_term: usize,
    pub d_claims: usize,
    pub d_rounds: usize,
    pub d_term: usize,
    pub zcf_rounds: usize,
    pub zcf_term: usize,
    pub zcd_rounds: usize,
    pub zcd_term: usize,
    pub helper_sums: usize,
    pub w: OpeningShape,
    pub a: OpeningShape,
    pub h: OpeningShape,
}

impl Params {
    /// The parameter rule the decoder relies on: `inv_rate` a power of two
    /// (the Merkle tree is over `cols * inv_rate` leaves), `log_cols` and
    /// the product inside `usize`.
    pub fn check(&self) -> Result<(), String> {
        if !self.inv_rate.is_power_of_two() {
            return Err(format!("params: inv_rate {} is not a power of two", self.inv_rate));
        }
        if self.log_cols > 40 || (self.log_cols as usize + self.inv_rate.trailing_zeros() as usize) > 48 {
            return Err(format!("params: log_cols {} / inv_rate {} out of range", self.log_cols, self.inv_rate));
        }
        Ok(())
    }
}

impl Shape {
    pub fn of(st: &Statement, params: &Params) -> Result<Shape, String> {
        Layout::check(st.t_rows, st.d, st.f)?;
        params.check()?;
        let lay = Layout::new(st.t_rows, st.d, st.f);
        let (nb_d, nb_f) = (lay.nb_d, lay.nb_f);
        let w_pcs = params.pcs_for(lay.log_wb);
        let a_pcs = params.pcs_for(lay.log_a_min);
        let h_pcs = params.pcs_for(lay.log_a_min);
        let mut mults = vec![(TAG_ACT16, 256usize), (TAG_INT16, 1usize << 16)];
        for s in st.distinct_shifts() {
            mults.push((tag_rem_v3(s), rem_rows(s)));
        }
        Ok(Shape {
            mults,
            gu_claims: 2 * nb_f,
            gu_rounds: lay.log_db as usize,
            gu_term: nb_d + 2 * nb_d * nb_f,
            d_claims: nb_d,
            d_rounds: lay.log_fb as usize,
            d_term: nb_f + nb_f * nb_d,
            zcf_rounds: (lay.log_t + lay.log_fb) as usize,
            zcf_term: 10 * nb_f,
            zcd_rounds: (lay.log_t + lay.log_db) as usize,
            zcd_term: 4 * nb_d,
            helper_sums: 3 * nb_f + nb_d,
            w: OpeningShape { pcs: w_pcs, rows: lay.w_len / w_pcs.cols(), groups: 2 },
            a: OpeningShape { pcs: a_pcs, rows: lay.a_len / a_pcs.cols(), groups: 2 },
            h: OpeningShape { pcs: h_pcs, rows: lay.h_len / h_pcs.cols(), groups: 3 },
        })
    }

    /// `(field name, start offset)` of every top-level field in proof
    /// order, ending with `("end", total)`: the boundaries a truncation test
    /// walks.
    pub fn field_offsets(&self) -> Vec<(String, usize)> {
        let mut out = Vec::new();
        let mut at = 0usize;
        let mut push = |name: String, len: usize, at: &mut usize| {
            out.push((name, *at));
            *at += len;
        };
        for name in ["w_com", "a_com", "h_com"] {
            push(name.to_string(), 32 + 8 + 4, &mut at);
        }
        for (i, (_, len)) in self.mults.iter().enumerate() {
            push(format!("mults[{i}]"), 8 + 4 + len * 4, &mut at);
        }
        push("gu_claims".into(), self.gu_claims * 16, &mut at);
        push("gu_sc".into(), self.gu_rounds * (MATMUL_DEGREE + 1) * 16, &mut at);
        push("gu_term".into(), self.gu_term * 16, &mut at);
        push("d_claims".into(), self.d_claims * 16, &mut at);
        push("d_sc".into(), self.d_rounds * (MATMUL_DEGREE + 1) * 16, &mut at);
        push("d_term".into(), self.d_term * 16, &mut at);
        push("zcf_sc".into(), self.zcf_rounds * (ZEROCHECK_DEGREE + 1) * 16, &mut at);
        push("zcf_term".into(), self.zcf_term * 16, &mut at);
        push("zcd_sc".into(), self.zcd_rounds * (ZEROCHECK_DEGREE + 1) * 16, &mut at);
        push("zcd_term".into(), self.zcd_term * 16, &mut at);
        push("helper_sums".into(), self.helper_sums * 16, &mut at);
        push("w_open".into(), self.w.bytes(), &mut at);
        push("a_open".into(), self.a.bytes(), &mut at);
        push("h_open".into(), self.h.bytes(), &mut at);
        out.push(("end".into(), at));
        out
    }

    pub fn total_bytes(&self) -> usize {
        self.field_offsets().last().map(|(_, at)| *at).unwrap_or(0)
    }
}

// ---------------------------------------------------------------------------
// the bounded decoder
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DecodeError {
    /// The statement or parameters are outside the supported shape.
    Shape(String),
    /// Fewer bytes than the shape requires at `at`.
    Truncated { at: usize, need: usize, have: usize },
    /// Bytes remain after the last field.
    Trailing { consumed: usize, total: usize },
    /// An 8-byte word read as a field element is not the canonical representative (`>= P`).
    NonCanonical { at: usize },
    /// A commitment's `rows` / `log_cols` disagree with the layout.
    Commitment { which: &'static str, rows: u64, log_cols: u32 },
    /// Multiplicity table `index` has the wrong tag or length.
    Multiplicity { index: usize, tag: u64, len: u32 },
    /// An opened column index is not below the encoded width.
    ColumnIndex { opening: &'static str, column: usize, index: u64, enc_cols: usize },
}

impl fmt::Display for DecodeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DecodeError::Shape(s) => write!(f, "proof decode: {s}"),
            DecodeError::Truncated { at, need, have } => write!(f, "proof decode: truncated at byte {at} (need {need}, have {have})"),
            DecodeError::Trailing { consumed, total } => write!(f, "proof decode: {} trailing bytes after {consumed}", total - consumed),
            DecodeError::NonCanonical { at } => write!(f, "proof decode: non-canonical field element at byte {at}"),
            DecodeError::Commitment { which, rows, log_cols } => write!(f, "proof decode: {which} commitment rows {rows} / log_cols {log_cols} disagree with the layout"),
            DecodeError::Multiplicity { index, tag, len } => write!(f, "proof decode: multiplicity table {index} has tag {tag} / length {len}"),
            DecodeError::ColumnIndex { opening, column, index, enc_cols } => write!(f, "proof decode: {opening} opening column {column} index {index} >= {enc_cols}"),
        }
    }
}

impl std::error::Error for DecodeError {}

struct Reader<'a> {
    b: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], DecodeError> {
        let have = self.b.len().saturating_sub(self.pos);
        if have < n {
            return Err(DecodeError::Truncated { at: self.pos, need: n, have });
        }
        let s = &self.b[self.pos..self.pos + n];
        self.pos += n;
        Ok(s)
    }
    fn u64(&mut self) -> Result<u64, DecodeError> {
        Ok(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    fn u32(&mut self) -> Result<u32, DecodeError> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn fp(&mut self) -> Result<Fp, DecodeError> {
        let at = self.pos;
        let v = self.u64()?;
        if v >= P {
            return Err(DecodeError::NonCanonical { at });
        }
        Ok(Fp(v))
    }
    fn fp2(&mut self) -> Result<Fp2, DecodeError> {
        let c0 = self.fp()?;
        let c1 = self.fp()?;
        Ok(Fp2::new(c0, c1))
    }
    fn fp2_vec(&mut self, n: usize) -> Result<Vec<Fp2>, DecodeError> {
        (0..n).map(|_| self.fp2()).collect()
    }
    fn digest(&mut self) -> Result<Digest, DecodeError> {
        Ok(self.take(32)?.try_into().unwrap())
    }
    fn sumcheck(&mut self, rounds: usize, degree: usize) -> Result<SumcheckProof, DecodeError> {
        let mut out = Vec::with_capacity(rounds);
        for _ in 0..rounds {
            out.push(self.fp2_vec(degree + 1)?);
        }
        Ok(SumcheckProof { rounds: out })
    }
    fn commitment(&mut self, which: &'static str, os: &OpeningShape) -> Result<Commitment, DecodeError> {
        let root = self.digest()?;
        let rows = self.u64()?;
        let log_cols = self.u32()?;
        if rows != os.rows as u64 || log_cols != os.pcs.log_cols {
            return Err(DecodeError::Commitment { which, rows, log_cols });
        }
        Ok(Commitment { root, rows: rows as usize, log_cols })
    }
    fn opening(&mut self, which: &'static str, os: &OpeningShape) -> Result<Opening, DecodeError> {
        let n = os.cols();
        let nn = os.enc_cols();
        let mut group_vecs = Vec::with_capacity(os.groups);
        for _ in 0..os.groups {
            group_vecs.push(self.fp2_vec(n)?);
        }
        let prox_vec = self.fp2_vec(n)?;
        let mut columns = Vec::with_capacity(os.pcs.num_col_checks);
        for column in 0..os.pcs.num_col_checks {
            let index = self.u64()?;
            if index >= nn as u64 {
                return Err(DecodeError::ColumnIndex { opening: which, column, index, enc_cols: nn });
            }
            let mut col = Vec::with_capacity(os.rows);
            for _ in 0..os.rows {
                col.push(self.fp()?);
            }
            let mut path = Vec::with_capacity(os.path_len());
            for _ in 0..os.path_len() {
                path.push(self.digest()?);
            }
            columns.push((index as usize, col, path));
        }
        Ok(Opening { group_vecs, prox_vec, columns })
    }
}

impl<X> Proof<X> {
    /// The proof shape `from_bytes` reads for this statement and parameters.
    pub fn shape(st: &Statement, params: &Params) -> Result<Shape, String> {
        Shape::of(st, params)
    }

    /// Decode the frozen encoding of a proof for `(st, params)`; see the
    /// module doc for what is refused. The extra opening is always `None`:
    /// the encoding of hashline's compact form has no bounded decoder.
    pub fn from_bytes(bytes: &[u8], st: &Statement, params: &Params) -> Result<Proof<X>, DecodeError> {
        let shape = Shape::of(st, params).map_err(DecodeError::Shape)?;
        let mut r = Reader { b: bytes, pos: 0 };
        let w_com = r.commitment("W", &shape.w)?;
        let a_com = r.commitment("A", &shape.a)?;
        let h_com = r.commitment("H", &shape.h)?;
        let mut mults = Vec::with_capacity(shape.mults.len());
        for (index, &(want_tag, want_len)) in shape.mults.iter().enumerate() {
            let tag = r.u64()?;
            let len = r.u32()?;
            if tag != want_tag || len as usize != want_len {
                return Err(DecodeError::Multiplicity { index, tag, len });
            }
            let mut m = Vec::with_capacity(want_len);
            for _ in 0..want_len {
                m.push(r.u32()?);
            }
            mults.push((tag, m));
        }
        let gu_claims = r.fp2_vec(shape.gu_claims)?;
        let gu_sc = r.sumcheck(shape.gu_rounds, MATMUL_DEGREE)?;
        let gu_term = r.fp2_vec(shape.gu_term)?;
        let d_claims = r.fp2_vec(shape.d_claims)?;
        let d_sc = r.sumcheck(shape.d_rounds, MATMUL_DEGREE)?;
        let d_term = r.fp2_vec(shape.d_term)?;
        let zcf_sc = r.sumcheck(shape.zcf_rounds, ZEROCHECK_DEGREE)?;
        let zcf_term = r.fp2_vec(shape.zcf_term)?;
        let zcd_sc = r.sumcheck(shape.zcd_rounds, ZEROCHECK_DEGREE)?;
        let zcd_term = r.fp2_vec(shape.zcd_term)?;
        let helper_sums = r.fp2_vec(shape.helper_sums)?;
        let w_open = r.opening("W", &shape.w)?;
        let a_open = r.opening("A", &shape.a)?;
        let h_open = r.opening("H", &shape.h)?;
        if r.pos != bytes.len() {
            return Err(DecodeError::Trailing { consumed: r.pos, total: bytes.len() });
        }
        Ok(Proof {
            w_com: Some(w_com),
            a_com: Some(a_com),
            h_com: Some(h_com),
            mults,
            gu_claims,
            gu_sc,
            gu_term,
            d_claims,
            d_sc,
            d_term,
            zcf_sc,
            zcf_term,
            zcd_sc,
            zcd_term,
            helper_sums,
            w_open,
            a_open,
            h_open,
            cpcs_open: None,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tables::{int16out_member, Act16Fn};

    fn tiny() -> (Statement, Params) {
        let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
        let st = Statement { l: 0, t_rows: 2, d: 16, f: 16, shifts: (7, 0, 14, 6), act: Act16Fn::Silu, table, table_digest };
        (st, Params { log_cols: 5, inv_rate: 4, num_col_checks: 12 })
    }

    fn next(s: &mut u64) -> u64 {
        *s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        *s >> 33
    }
    fn f2v(s: &mut u64, n: usize) -> Vec<Fp2> {
        (0..n).map(|_| { let a = next(s); let b = next(s); Fp2::new(Fp::new(a), Fp::new(b)) }).collect()
    }
    fn sc(s: &mut u64, rounds: usize, degree: usize) -> SumcheckProof {
        SumcheckProof { rounds: (0..rounds).map(|_| f2v(s, degree + 1)).collect() }
    }
    fn com(os: &OpeningShape, fill: u8) -> Commitment {
        Commitment { root: [fill; 32], rows: os.rows, log_cols: os.pcs.log_cols }
    }
    fn open(s: &mut u64, os: &OpeningShape, fill: u8) -> Opening {
        Opening {
            group_vecs: (0..os.groups).map(|_| f2v(s, os.cols())).collect(),
            prox_vec: f2v(s, os.cols()),
            columns: (0..os.pcs.num_col_checks)
                .map(|c| ((c * 7) % os.enc_cols(), (0..os.rows).map(|i| Fp::new((i + c) as u64)).collect(), vec![[fill; 32]; os.path_len()]))
                .collect(),
        }
    }

    /// A shape-consistent proof with deterministic small filler: not a valid
    /// proof, only its encoding.
    fn dummy(shape: &Shape, seed: u64) -> Proof<NoExtra> {
        let s = &mut seed.clone();
        Proof {
            w_com: Some(com(&shape.w, 1)),
            a_com: Some(com(&shape.a, 2)),
            h_com: Some(com(&shape.h, 3)),
            mults: shape.mults.iter().map(|&(tag, len)| (tag, (0..len as u32).collect())).collect(),
            gu_claims: f2v(s, shape.gu_claims),
            gu_sc: sc(s, shape.gu_rounds, MATMUL_DEGREE),
            gu_term: f2v(s, shape.gu_term),
            d_claims: f2v(s, shape.d_claims),
            d_sc: sc(s, shape.d_rounds, MATMUL_DEGREE),
            d_term: f2v(s, shape.d_term),
            zcf_sc: sc(s, shape.zcf_rounds, ZEROCHECK_DEGREE),
            zcf_term: f2v(s, shape.zcf_term),
            zcd_sc: sc(s, shape.zcd_rounds, ZEROCHECK_DEGREE),
            zcd_term: f2v(s, shape.zcd_term),
            helper_sums: f2v(s, shape.helper_sums),
            w_open: open(s, &shape.w, 4),
            a_open: open(s, &shape.a, 5),
            h_open: open(s, &shape.h, 6),
            cpcs_open: None,
        }
    }

    #[test]
    fn shape_of_the_tiny_and_the_125m_statements() {
        let (st, p) = tiny();
        let sh = Shape::of(&st, &p).unwrap();
        assert_eq!(sh.mults, vec![(TAG_ACT16, 256), (TAG_INT16, 65536), (tag_rem_v3(0), 1), (tag_rem_v3(6), 64), (tag_rem_v3(7), 128), (tag_rem_v3(14), 16384)]);
        assert_eq!((sh.gu_claims, sh.gu_rounds, sh.gu_term, sh.d_claims, sh.d_rounds, sh.d_term), (2, 4, 3, 1, 4, 2));
        assert_eq!((sh.zcf_rounds, sh.zcf_term, sh.zcd_rounds, sh.zcd_term, sh.helper_sums), (5, 10, 5, 4, 4));
        assert_eq!((sh.w.rows, sh.a.rows, sh.h.rows), (24, 10, 8));
        assert_eq!((sh.w.pcs.log_cols, sh.a.pcs.log_cols, sh.w.path_len()), (5, 5, 7));
        let big = Statement { t_rows: 512, d: 768, f: 2048, ..st.clone() };
        let bp = Params { log_cols: 14, inv_rate: 4, num_col_checks: 256 };
        let bs = Shape::of(&big, &bp).unwrap();
        assert_eq!((bs.gu_rounds, bs.d_rounds, bs.zcf_rounds, bs.zcd_rounds), (8, 11, 20, 17));
        assert_eq!((bs.w.pcs.log_cols, bs.a.pcs.log_cols), (14, 14));
        assert!(Shape::of(&Statement { t_rows: 3, ..st.clone() }, &p).is_err());
        assert!(Shape::of(&st, &Params { inv_rate: 3, ..p }).is_err());
    }

    #[test]
    fn dummy_round_trips_and_sizes_agree() {
        let (st, p) = tiny();
        let sh = Shape::of(&st, &p).unwrap();
        let pr = dummy(&sh, 9);
        let bytes = pr.to_bytes();
        assert_eq!(bytes.len(), pr.size_bytes());
        assert_eq!(bytes.len(), sh.total_bytes());
        let back: Proof<NoExtra> = Proof::from_bytes(&bytes, &st, &p).unwrap();
        assert_eq!(back.to_bytes(), bytes);
        assert!(back.cpcs_open.is_none());
    }

    #[test]
    fn malformed_bytes_are_refused_never_panic() {
        let (st, p) = tiny();
        let sh = Shape::of(&st, &p).unwrap();
        let bytes = dummy(&sh, 3).to_bytes();
        let dec = |b: &[u8]| Proof::<NoExtra>::from_bytes(b, &st, &p);
        // truncation at every field boundary and one byte short of each
        for (name, at) in sh.field_offsets() {
            if at == bytes.len() { continue; }
            assert!(matches!(dec(&bytes[..at]), Err(DecodeError::Truncated { .. })), "field {name}");
            if at > 0 { assert!(matches!(dec(&bytes[..at - 1]), Err(DecodeError::Truncated { .. })), "field {name} - 1"); }
        }
        assert!(matches!(dec(&bytes[..bytes.len() - 1]), Err(DecodeError::Truncated { .. })));
        assert!(matches!(dec(&[]), Err(DecodeError::Truncated { at: 0, .. })));
        // one trailing byte
        let mut t = bytes.clone();
        t.push(0);
        assert_eq!(dec(&t).err(), Some(DecodeError::Trailing { consumed: bytes.len(), total: bytes.len() + 1 }));
        // a commitment disagreeing with the layout
        let mut c = bytes.clone();
        c[32..40].copy_from_slice(&(sh.w.rows as u64 + 1).to_le_bytes());
        assert!(matches!(dec(&c), Err(DecodeError::Commitment { which: "W", .. })));
        // the wrong multiplicity tag and the wrong length
        let offs: std::collections::HashMap<String, usize> = sh.field_offsets().into_iter().collect();
        let m1 = offs["mults[1]"];
        let mut m = bytes.clone();
        m[m1..m1 + 8].copy_from_slice(&TAG_ACT16.to_le_bytes());
        assert!(matches!(dec(&m), Err(DecodeError::Multiplicity { index: 1, .. })));
        let mut m = bytes.clone();
        m[m1 + 8..m1 + 12].copy_from_slice(&65535u32.to_le_bytes());
        assert!(matches!(dec(&m), Err(DecodeError::Multiplicity { index: 1, .. })));
        // a non-canonical field element (>= P) in a claim, a sumcheck round and an opened column
        let gu = offs["gu_claims"];
        let mut nc = bytes.clone();
        nc[gu..gu + 8].copy_from_slice(&P.to_le_bytes());
        assert_eq!(dec(&nc).err(), Some(DecodeError::NonCanonical { at: gu }));
        let zc = offs["zcf_sc"] + 16;
        let mut nc = bytes.clone();
        nc[zc..zc + 8].copy_from_slice(&u64::MAX.to_le_bytes());
        assert_eq!(dec(&nc).err(), Some(DecodeError::NonCanonical { at: zc }));
        let col0 = offs["a_open"] + (sh.a.groups + 1) * sh.a.cols() * 16 + 8;
        let mut nc = bytes.clone();
        nc[col0..col0 + 8].copy_from_slice(&(P + 5).to_le_bytes());
        assert_eq!(dec(&nc).err(), Some(DecodeError::NonCanonical { at: col0 }));
        // a column index at and beyond the encoded width
        let idx0 = offs["h_open"] + (sh.h.groups + 1) * sh.h.cols() * 16;
        for bad in [sh.h.enc_cols() as u64, u64::MAX] {
            let mut ci = bytes.clone();
            ci[idx0..idx0 + 8].copy_from_slice(&bad.to_le_bytes());
            assert!(matches!(dec(&ci), Err(DecodeError::ColumnIndex { opening: "H", column: 0, .. })));
        }
        // single-bit flips at sampled offsets decode or refuse, never panic
        for k in (0..bytes.len()).step_by(997) {
            let mut fl = bytes.clone();
            fl[k] ^= 0x80;
            let _ = dec(&fl);
        }
        // the statement's own rule is reported, not panicked
        assert!(matches!(Proof::<NoExtra>::from_bytes(&bytes, &Statement { d: 24, ..st.clone() }, &p), Err(DecodeError::Shape(_))));
    }
}
