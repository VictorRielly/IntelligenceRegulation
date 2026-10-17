//! Canonical bounded wire codec for the fixed tiny PUBLIC P0 Ligero block.
//! New framing, NOT a decoder for the ambiguous legacy flat serializers.
//! Parsing/structural acceptance is not proof verification, privacy, or approval.
use crate::attention::AttnProof;
use crate::field::{Fp, Fp2, P};
use crate::layer::LayerProofV3;
use crate::merkle::Digest;
use crate::pcs::{Commitment, Opening};
use crate::public_block_oracle::PublicBlockProof;
use crate::sumcheck::SumcheckProof;

pub const MAX_WIRE_BYTES: usize = 8 * 1024 * 1024;
/// Requested decoded Vec payload capacity, including nested Vec/tuple headers.
/// Excludes the caller-owned input and allocator bookkeeping/rounding.
pub const MAX_DECODED_ALLOCATION: usize = 16 * 1024 * 1024;
pub const MAGIC: &[u8; 8] = b"ZKPBWIRE";
pub const VERSION: u16 = 1;
const MAX_TABLES: usize = 16;
const MAX_TABLE_ROWS: usize = 65536;
const MAX_GROUPS: usize = 32;
const MAX_ROWS: usize = 256;
const COLS: usize = 256;
const QUERIES: usize = 256;
const PATH: usize = 11;
const ATTN_SC: [(usize, usize); 12] = [
    (9, 4),
    (5, 4),
    (9, 5),
    (9, 5),
    (8, 5),
    (11, 6),
    (11, 4),
    (8, 5),
    (4, 3),
    (3, 4),
    (5, 4),
    (4, 3),
];
fn need(ok: bool, message: &'static str) -> Result<(), String> {
    if ok {
        Ok(())
    } else {
        Err(message.into())
    }
}
fn com(c: &Option<Commitment>, rows: usize) -> Result<&Commitment, String> {
    let c = c.as_ref().ok_or("wire: missing commitment")?;
    need(
        c.log_cols == 8 && c.rows == rows,
        "wire: unsupported commitment shape",
    )?;
    Ok(c)
}
fn sc_shape(sc: &SumcheckProof, rounds: usize, width: usize) -> Result<(), String> {
    need(
        sc.rounds.len() == rounds && sc.rounds.iter().all(|r| r.len() == width),
        "wire: unsupported sumcheck shape",
    )
}
fn mult_shape(tables: &[(u64, Vec<u32>)]) -> Result<(), String> {
    need(
        !tables.is_empty() && tables.len() <= MAX_TABLES,
        "wire: table count",
    )?;
    let mut previous = 0;
    for (tag, rows) in tables {
        need(
            *tag > previous && *tag <= 400,
            "wire: noncanonical or unsupported table tag order",
        )?;
        previous = *tag;
        need(
            !rows.is_empty() && rows.len() <= MAX_TABLE_ROWS,
            "wire: table row count",
        )?;
        let total: u64 = rows.iter().map(|v| u64::from(*v)).sum();
        need(total <= 65536, "wire: tiny multiplicity budget")?;
    }
    Ok(())
}
fn opening_shape(o: &Opening, rows: usize) -> Result<(), String> {
    need(
        !o.group_vecs.is_empty() && o.group_vecs.len() <= MAX_GROUPS,
        "wire: opening group count",
    )?;
    need(
        o.group_vecs.iter().all(|v| v.len() == COLS) && o.prox_vec.len() == COLS,
        "wire: opening vector length",
    )?;
    need(o.columns.len() == QUERIES, "wire: opening query count")?;
    for (index, column, path) in &o.columns {
        need(
            *index < 2048 && column.len() == rows && path.len() == PATH,
            "wire: column index, length or authentication depth",
        )?;
    }
    Ok(())
}
fn shapes(p: &PublicBlockProof) -> Result<(), String> {
    let a = &p.attention;
    need(
        a.helper_sums.is_empty(),
        "wire: unused attention helper_sums must be empty",
    )?;
    need(
        matches!(a.vals.len(), 133 | 135),
        "wire: unsupported attention claim count",
    )?;
    need(
        a.sc.len() == 12 && a.collapse.len() == 4,
        "wire: attention argument/folding count",
    )?;
    for (s, (rounds, width)) in a.sc.iter().zip(ATTN_SC) {
        sc_shape(s, rounds, width)?;
    }
    for ((s, _), rounds) in a.collapse.iter().zip([14, 13, 11, 10]) {
        sc_shape(s, rounds, 3)?;
    }
    mult_shape(&a.mults)?;
    for (c, o, rows) in [
        (&a.w_com, &a.w_open, 4),
        (&a.a_com, &a.a_open, 108),
        (&a.h_com, &a.h_open, 106),
    ] {
        com(c, rows)?;
        opening_shape(o, rows)?;
    }
    let f = &p.ffn;
    need(f.cpcs_open.is_none(), "wire: compact backend unsupported")?;
    for (v, n) in [
        (&f.gu_claims, 2),
        (&f.gu_term, 3),
        (&f.d_claims, 1),
        (&f.d_term, 2),
        (&f.zcf_term, 10),
        (&f.zcd_term, 4),
        (&f.helper_sums, 4),
    ] {
        need(v.len() == n, "wire: FFN claim/terminal/helper count")?;
    }
    for (s, rounds, width) in [
        (&f.gu_sc, 4, 3),
        (&f.d_sc, 4, 3),
        (&f.zcf_sc, 9, 5),
        (&f.zcd_sc, 9, 5),
    ] {
        sc_shape(s, rounds, width)?;
    }
    mult_shape(&f.mults)?;
    for (c, o, rows) in [
        (&f.w_com, &f.w_open, 3),
        (&f.a_com, &f.a_open, 20),
        (&f.h_com, &f.h_open, 16),
    ] {
        com(c, rows)?;
        opening_shape(o, rows)?;
    }
    Ok(())
}

/// Independent fixed-profile shape/canonicality preflight, without a prover,
/// transcript replay, witness or candidate-derived safety bounds. Allows B3's
/// 133 claims OR the receipt's 135; the receipt must require its own exact mode,
/// independently approved calibration/table totals/roots/context and verification.
pub fn validate_structure(proof: &PublicBlockProof) -> Result<(), String> {
    encoded_len(proof).map(|_| ())
}
fn encoded_len(proof: &PublicBlockProof) -> Result<usize, String> {
    shapes(proof)?;
    let mut w = Writer {
        bytes: None,
        len: 0,
    };
    encode_body(proof, &mut w)?;
    Ok(w.len)
}
pub fn encode_components(proof: &PublicBlockProof) -> Result<Vec<u8>, String> {
    let length = encoded_len(proof)?;
    let mut bytes = Vec::new();
    bytes
        .try_reserve_exact(length)
        .map_err(|_| "wire: output allocation refused")?;
    let mut w = Writer {
        bytes: Some(bytes),
        len: 0,
    };
    encode_body(proof, &mut w)?;
    Ok(w.bytes.unwrap())
}
struct Writer {
    bytes: Option<Vec<u8>>,
    len: usize,
}
impl Writer {
    fn put(&mut self, b: &[u8]) -> Result<(), String> {
        self.len = self
            .len
            .checked_add(b.len())
            .ok_or("wire: byte length overflow")?;
        need(self.len <= MAX_WIRE_BYTES, "wire: byte budget exceeded")?;
        if let Some(bytes) = &mut self.bytes {
            bytes.extend_from_slice(b);
        }
        Ok(())
    }
    fn byte(&mut self, x: u8) -> Result<(), String> {
        self.put(&[x])
    }
    fn count(&mut self, x: usize) -> Result<(), String> {
        let x = u32::try_from(x).map_err(|_| "wire: count overflow")?;
        self.put(&x.to_le_bytes())
    }
    fn fp(&mut self, x: Fp) -> Result<(), String> {
        need(x.0 < P, "wire: noncanonical base field")?;
        self.put(&x.0.to_le_bytes())
    }
    fn fp2(&mut self, x: Fp2) -> Result<(), String> {
        self.fp(x.c0)?;
        self.fp(x.c1)
    }
    fn vector(&mut self, v: &[Fp2]) -> Result<(), String> {
        self.count(v.len())?;
        for x in v {
            self.fp2(*x)?;
        }
        Ok(())
    }
    fn sc(&mut self, s: &SumcheckProof) -> Result<(), String> {
        self.count(s.rounds.len())?;
        for r in &s.rounds {
            self.vector(r)?;
        }
        Ok(())
    }
    fn commitment(&mut self, c: &Option<Commitment>) -> Result<(), String> {
        let c = c.as_ref().ok_or("wire: missing commitment")?;
        self.byte(0xc0)?;
        self.put(&c.root)?;
        self.count(c.rows)?;
        self.byte(c.log_cols as u8)
    }
    fn mults(&mut self, m: &[(u64, Vec<u32>)]) -> Result<(), String> {
        self.count(m.len())?;
        for (tag, rows) in m {
            self.put(&tag.to_le_bytes())?;
            self.count(rows.len())?;
            for v in rows {
                self.put(&v.to_le_bytes())?;
            }
        }
        Ok(())
    }
    fn opening(&mut self, tag: u8, o: &Opening) -> Result<(), String> {
        self.byte(tag)?;
        self.count(o.group_vecs.len())?;
        for v in &o.group_vecs {
            self.vector(v)?;
        }
        self.vector(&o.prox_vec)?;
        self.count(o.columns.len())?;
        for (index, col, path) in &o.columns {
            self.count(*index)?;
            self.count(col.len())?;
            for x in col {
                self.fp(*x)?;
            }
            self.count(path.len())?;
            for d in path {
                self.put(d)?;
            }
        }
        Ok(())
    }
    fn begin(&mut self, tag: u8) -> Result<usize, String> {
        self.byte(tag)?;
        let at = self.len;
        self.count(0)?;
        Ok(at)
    }
    fn end(&mut self, at: usize) {
        let size = (self.len - at - 4) as u32;
        if let Some(bytes) = &mut self.bytes {
            bytes[at..at + 4].copy_from_slice(&size.to_le_bytes());
        }
    }
}
fn encode_body(p: &PublicBlockProof, w: &mut Writer) -> Result<(), String> {
    w.put(MAGIC)?;
    w.put(&VERSION.to_le_bytes())?;
    w.byte(0)?; // P0 Ligero only
    w.byte(1)?; // fixed tiny profile, version 1
    w.put(&p.contract_digest)?;
    let at = w.begin(0xa1)?;
    let a = &p.attention;
    for c in [&a.w_com, &a.a_com, &a.h_com] {
        w.commitment(c)?;
    }
    w.mults(&a.mults)?;
    w.vector(&a.vals)?;
    w.count(a.sc.len())?;
    for s in &a.sc {
        w.sc(s)?;
    }
    w.vector(&a.helper_sums)?;
    w.count(a.collapse.len())?;
    for (s, terminal) in &a.collapse {
        w.sc(s)?;
        w.fp2(*terminal)?;
    }
    for (tag, o) in [(0xb1, &a.w_open), (0xb2, &a.a_open), (0xb3, &a.h_open)] {
        w.opening(tag, o)?;
    }
    w.end(at);
    let at = w.begin(0xf3)?;
    let f = &p.ffn;
    for c in [&f.w_com, &f.a_com, &f.h_com] {
        w.commitment(c)?;
    }
    w.mults(&f.mults)?;
    w.vector(&f.gu_claims)?;
    w.sc(&f.gu_sc)?;
    w.vector(&f.gu_term)?;
    w.vector(&f.d_claims)?;
    w.sc(&f.d_sc)?;
    w.vector(&f.d_term)?;
    w.sc(&f.zcf_sc)?;
    w.vector(&f.zcf_term)?;
    w.sc(&f.zcd_sc)?;
    w.vector(&f.zcd_term)?;
    w.vector(&f.helper_sums)?;
    for (tag, o) in [(0xb1, &f.w_open), (0xb2, &f.a_open), (0xb3, &f.h_open)] {
        w.opening(tag, o)?;
    }
    w.byte(0)?; // cpcs_open MUST be None, explicitly encoded
    w.end(at);
    w.byte(0xee)
}

struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
    limit: usize,
    allocated: usize,
}
impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], String> {
        let end = self.at.checked_add(n).ok_or("wire: read overflow")?;
        need(end <= self.limit, "wire: truncated section")?;
        let b = &self.bytes[self.at..end];
        self.at = end;
        Ok(b)
    }
    fn byte(&mut self) -> Result<u8, String> {
        Ok(self.take(1)?[0])
    }
    fn tag(&mut self, expected: u8) -> Result<(), String> {
        let tag = self.byte()?;
        need(tag == expected, "wire: wrong type/backend/version tag")
    }
    fn u32(&mut self) -> Result<u32, String> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn u64(&mut self) -> Result<u64, String> {
        Ok(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    fn count(&mut self, max: usize) -> Result<usize, String> {
        let n = self.u32()? as usize;
        need(n <= max, "wire: count exceeds fixed bound")?;
        Ok(n)
    }
    fn reserve<T>(&mut self, n: usize, min_wire: usize) -> Result<Vec<T>, String> {
        let wire = n
            .checked_mul(min_wire)
            .ok_or("wire: count multiplication overflow")?;
        need(
            wire <= self.limit - self.at,
            "wire: truncated vector before allocation",
        )?;
        let allocation = n
            .checked_mul(std::mem::size_of::<T>())
            .ok_or("wire: allocation overflow")?;
        self.allocated = self
            .allocated
            .checked_add(allocation)
            .ok_or("wire: allocation overflow")?;
        need(
            self.allocated <= MAX_DECODED_ALLOCATION,
            "wire: decoded allocation budget exceeded",
        )?;
        let mut result = Vec::new();
        result
            .try_reserve_exact(n)
            .map_err(|_| "wire: allocation refused")?;
        Ok(result)
    }
    fn fp(&mut self) -> Result<Fp, String> {
        let word = self.u64()?;
        need(word < P, "wire: noncanonical base field")?;
        Ok(Fp(word))
    }
    fn fp2(&mut self) -> Result<Fp2, String> {
        Ok(Fp2::new(self.fp()?, self.fp()?))
    }
    fn vector(&mut self, max: usize) -> Result<Vec<Fp2>, String> {
        let n = self.count(max)?;
        let mut out = self.reserve(n, 16)?;
        for _ in 0..n {
            out.push(self.fp2()?);
        }
        Ok(out)
    }
    fn sc(&mut self) -> Result<SumcheckProof, String> {
        let n = self.count(16)?;
        let mut rounds = self.reserve(n, 4)?;
        for _ in 0..n {
            rounds.push(self.vector(6)?);
        }
        Ok(SumcheckProof { rounds })
    }
    fn commitment(&mut self) -> Result<Option<Commitment>, String> {
        self.tag(0xc0)?;
        let root = self.take(32)?.try_into().unwrap();
        let rows = self.count(MAX_ROWS)?;
        let log_cols = u32::from(self.byte()?);
        need(
            rows > 0 && log_cols == 8,
            "wire: unsupported commitment shape",
        )?;
        Ok(Some(Commitment {
            root,
            rows,
            log_cols,
        }))
    }
    fn mults(&mut self) -> Result<Vec<(u64, Vec<u32>)>, String> {
        let n = self.count(MAX_TABLES)?;
        let mut out = self.reserve(n, 12)?;
        let mut previous = 0;
        for _ in 0..n {
            let tag = self.u64()?;
            need(
                tag > previous && tag <= 400,
                "wire: noncanonical or unsupported table tag order",
            )?;
            previous = tag;
            let count = self.count(MAX_TABLE_ROWS)?;
            let mut rows = self.reserve(count, 4)?;
            let mut total = 0u64;
            for _ in 0..count {
                let value = self.u32()?;
                total += u64::from(value);
                need(total <= 65536, "wire: tiny multiplicity budget")?;
                rows.push(value);
            }
            out.push((tag, rows));
        }
        Ok(out)
    }
    fn opening(&mut self, tag: u8) -> Result<Opening, String> {
        self.tag(tag)?;
        let n = self.count(MAX_GROUPS)?;
        let mut group_vecs = self.reserve(n, 4)?;
        for _ in 0..n {
            group_vecs.push(self.vector(COLS)?);
        }
        let prox_vec = self.vector(COLS)?;
        let n = self.count(QUERIES)?;
        let mut columns = self.reserve(n, 12)?;
        for _ in 0..n {
            let index = self.count(2047)?;
            let n = self.count(MAX_ROWS)?;
            let mut col = self.reserve(n, 8)?;
            for _ in 0..n {
                col.push(self.fp()?);
            }
            let n = self.count(PATH)?;
            let mut path = self.reserve::<Digest>(n, 32)?;
            for _ in 0..n {
                path.push(self.take(32)?.try_into().unwrap());
            }
            columns.push((index, col, path));
        }
        Ok(Opening {
            group_vecs,
            prox_vec,
            columns,
        })
    }
    fn enter(&mut self, tag: u8) -> Result<usize, String> {
        self.tag(tag)?;
        let n = self.count(MAX_WIRE_BYTES)?;
        let old = self.limit;
        let limit = self
            .at
            .checked_add(n)
            .ok_or("wire: section length overflow")?;
        need(limit <= old, "wire: section exceeds enclosing input")?;
        self.limit = limit;
        Ok(old)
    }
    fn leave(&mut self, old: usize) -> Result<(), String> {
        need(self.at == self.limit, "wire: unconsumed section bytes")?;
        self.limit = old;
        Ok(())
    }
}

pub fn decode_components(bytes: &[u8]) -> Result<PublicBlockProof, String> {
    need(bytes.len() <= MAX_WIRE_BYTES, "wire: byte budget exceeded")?;
    let mut r = Reader {
        bytes,
        at: 0,
        limit: bytes.len(),
        allocated: 0,
    };
    need(r.take(8)? == MAGIC, "wire: wrong magic")?;
    need(
        r.take(2)? == VERSION.to_le_bytes(),
        "wire: unsupported version",
    )?;
    r.tag(0)?;
    r.tag(1)?;
    let contract_digest = r.take(32)?.try_into().unwrap();
    let old = r.enter(0xa1)?;
    let mut a = AttnProof {
        w_com: r.commitment()?,
        a_com: r.commitment()?,
        h_com: r.commitment()?,
        ..Default::default()
    };
    a.mults = r.mults()?;
    a.vals = r.vector(135)?;
    let n = r.count(12)?;
    a.sc = r.reserve(n, 4)?;
    for _ in 0..n {
        a.sc.push(r.sc()?);
    }
    a.helper_sums = r.vector(0)?;
    let n = r.count(4)?;
    a.collapse = r.reserve(n, 20)?;
    for _ in 0..n {
        a.collapse.push((r.sc()?, r.fp2()?));
    }
    a.w_open = r.opening(0xb1)?;
    a.a_open = r.opening(0xb2)?;
    a.h_open = r.opening(0xb3)?;
    r.leave(old)?;
    let old = r.enter(0xf3)?;
    let mut f = LayerProofV3 {
        w_com: r.commitment()?,
        a_com: r.commitment()?,
        h_com: r.commitment()?,
        ..Default::default()
    };
    f.mults = r.mults()?;
    f.gu_claims = r.vector(2)?;
    f.gu_sc = r.sc()?;
    f.gu_term = r.vector(3)?;
    f.d_claims = r.vector(1)?;
    f.d_sc = r.sc()?;
    f.d_term = r.vector(2)?;
    f.zcf_sc = r.sc()?;
    f.zcf_term = r.vector(10)?;
    f.zcd_sc = r.sc()?;
    f.zcd_term = r.vector(4)?;
    f.helper_sums = r.vector(4)?;
    f.w_open = r.opening(0xb1)?;
    f.a_open = r.opening(0xb2)?;
    f.h_open = r.opening(0xb3)?;
    r.tag(0)?; // unsupported compact form is never ignored
    r.leave(old)?;
    r.tag(0xee)?;
    need(r.at == bytes.len(), "wire: trailing bytes")?;
    let p = PublicBlockProof {
        contract_digest,
        attention: a,
        ffn: f,
    };
    validate_structure(&p)?;
    Ok(p)
}
