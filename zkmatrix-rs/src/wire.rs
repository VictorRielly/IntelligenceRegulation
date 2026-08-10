//! [UAGB1-BI] ZKWF v1 — the canonical serialized wire format (audit
//! M-05). Specification: `docs/zkmatrix-poc/WIRE_FORMAT.md` (the spec
//! is the authority; this module implements it byte for byte).
//!
//! Deliberately standalone in the manifest.rs style: shared by
//! `#[path]` inclusion, no dependency on the ring or manifest modules.
//! `Poly` and `KElem` are structurally `Vec<u64>` throughout the
//! engine, so the aliases below interoperate directly; the v1 field
//! constant is pinned here and cross-asserted against `ring::Q8` by
//! the [UAGB1-BI] drivers. Manifest statement bytes are carried
//! VERBATIM (digest neutrality — the wire format can never move a
//! statement digest); full manifest decode/validate on the embedded
//! bytes is the caller's battery obligation, while this module
//! enforces the structural container/version pairing.
//!
//! Determinism contract: one in-memory artifact has exactly one
//! encoding (fixed widths, fixed section order, canonical-minimal
//! signed-integer widths re-checked at decode), so
//! `encode(decode(b)) == b`. Decoding NEVER panics (the release
//! profile is panic=abort): every read is bounds-checked, every field
//! element range-checked, every count cross-checked before an object
//! is built.

#![allow(dead_code)]

/// One R_q ring element: 128 coefficients in [0, WIRE_Q).
pub type WPoly = Vec<u64>;
/// One K = GF(q^16) element: 16 base-field coordinates.
pub type WKElem = Vec<u64>;

pub const WIRE_MAGIC: &[u8; 8] = b"ZKMXWIRE";
pub const WIRE_VERSION: u32 = 1;
/// v1 field id 1 = q8_31 (must equal ring::Q8; cross-asserted by the
/// drivers).
pub const WIRE_FIELD_ID: u8 = 1;
pub const WIRE_Q: u64 = 2_147_483_249; // 2^31 - 399
pub const WD: usize = 128;
pub const WK_DEG: usize = 16;

pub const KIND_EVAL_PROOF: u16 = 1;
pub const KIND_FOLD_TRANSCRIPT: u16 = 2;
pub const KIND_STATEMENT_WRAP: u16 = 3;
pub const KIND_PASS_ARTIFACT: u16 = 4;

// Section tags (spec Section 3).
const SEC_EVAL_META: u16 = 0x0101;
const SEC_EVAL_STATEMENT: u16 = 0x0102;
const SEC_EVAL_SUMCHECK: u16 = 0x0103;
const SEC_EVAL_GROUP: u16 = 0x0104;
const SEC_FOLD_META: u16 = 0x0201;
const SEC_FOLD_STATEMENT: u16 = 0x0202;
const SEC_FOLD_TAGS: u16 = 0x0203;
const SEC_FOLD_SUMCHECK: u16 = 0x0204;
const SEC_FOLD_REVEALS: u16 = 0x0205;
const SEC_FOLD_WAVES: u16 = 0x0206;
const SEC_FOLD_CLOSING: u16 = 0x0207;
const SEC_STMT_META: u16 = 0x0301;
const SEC_STMT_STATEMENT: u16 = 0x0302;
const SEC_PASS_META: u16 = 0x0401;
const SEC_PASS_STATEMENT: u16 = 0x0402;
const SEC_PASS_GROUP_EVAL: u16 = 0x0403;
const SEC_PASS_FOLD_CLAIM: u16 = 0x0404;
const SEC_PASS_RAW: u16 = 0x04FE;

// Manifest container codec versions (structural pairing check only;
// full decode/validate is the caller's obligation).
const MANIFEST_CV1: u32 = 1;
const MANIFEST_CV2: u32 = 2;

// ---------------------------------------------------------------------------
// Errors (spec Section 4).

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WireError {
    BadMagic,
    BadVersion(u32),
    BadKind(u16),
    BadFieldId(u8),
    ReservedNonzero,
    Truncated,
    TrailingBytes,
    SectionOrder { expected: u16, got: u16 },
    SectionLength { tag: u16 },
    BadCount,
    CoeffRange,
    NonCanonicalWidth,
    ValueRange,
    BadName,
    BadStatement,
    BadPairing,
    ShapeMismatch(&'static str),
}

impl std::fmt::Display for WireError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WireError::BadMagic => write!(f, "bad magic"),
            WireError::BadVersion(v) => write!(f, "unknown format version {v}"),
            WireError::BadKind(k) => write!(f, "unknown artifact kind {k}"),
            WireError::BadFieldId(x) => write!(f, "unknown field id {x}"),
            WireError::ReservedNonzero => write!(f, "reserved bytes nonzero"),
            WireError::Truncated => write!(f, "truncated"),
            WireError::TrailingBytes => write!(f, "trailing bytes"),
            WireError::SectionOrder { expected, got } => {
                write!(f, "section order: expected tag {expected:#06x}, got {got:#06x}")
            }
            WireError::SectionLength { tag } => write!(f, "section {tag:#06x} length mismatch"),
            WireError::BadCount => write!(f, "count out of range"),
            WireError::CoeffRange => write!(f, "field element out of canonical range"),
            WireError::NonCanonicalWidth => write!(f, "non-canonical signed-int width"),
            WireError::ValueRange => write!(f, "value out of range"),
            WireError::BadName => write!(f, "bad name string"),
            WireError::BadStatement => write!(f, "bad embedded statement bytes"),
            WireError::BadPairing => write!(f, "statement container/version pairing"),
            WireError::ShapeMismatch(w) => write!(f, "shape mismatch: {w}"),
        }
    }
}

type WResult<T> = Result<T, WireError>;

// ---------------------------------------------------------------------------
// Primitive writer.

struct W {
    buf: Vec<u8>,
}

impl W {
    fn new() -> W {
        W { buf: Vec::new() }
    }
    fn u8(&mut self, v: u8) {
        self.buf.push(v);
    }
    fn u16(&mut self, v: u16) {
        self.buf.extend(v.to_le_bytes());
    }
    fn u32(&mut self, v: u32) {
        self.buf.extend(v.to_le_bytes());
    }
    fn u64(&mut self, v: u64) {
        self.buf.extend(v.to_le_bytes());
    }
    fn bytes(&mut self, b: &[u8]) {
        self.buf.extend_from_slice(b);
    }
    fn poly(&mut self, p: &WPoly) {
        assert_eq!(p.len(), WD, "poly must have {WD} coefficients");
        for &c in p {
            assert!(c < WIRE_Q, "poly coefficient out of canonical range");
            self.u32(c as u32);
        }
    }
    fn polys(&mut self, ps: &[WPoly]) {
        self.u32(ps.len() as u32);
        for p in ps {
            self.poly(p);
        }
    }
    fn kelem(&mut self, k: &WKElem) {
        assert_eq!(k.len(), WK_DEG, "K element must have {WK_DEG} coordinates");
        for &c in k {
            assert!(c < WIRE_Q, "K coordinate out of canonical range");
            self.u32(c as u32);
        }
    }
    fn kvec(&mut self, ks: &[WKElem]) {
        self.u32(ks.len() as u32);
        for k in ks {
            self.kelem(k);
        }
    }
    /// Canonical-minimal-width signed-integer block.
    fn sint(&mut self, vals: &[i64]) {
        let w = sint_min_width(vals);
        self.u32(vals.len() as u32);
        self.u8(w);
        for &v in vals {
            self.buf.extend_from_slice(&v.to_le_bytes()[..w as usize]);
        }
    }
    fn str8(&mut self, s: &str) {
        assert!(s.len() <= 32 && s.bytes().all(|b| (0x20..0x7f).contains(&b)));
        self.u8(s.len() as u8);
        self.bytes(s.as_bytes());
    }
    /// Section framing: tag + reserved + u64 length + body.
    fn section(&mut self, tag: u16, body: W) {
        self.u16(tag);
        self.u16(0);
        self.u64(body.buf.len() as u64);
        self.buf.extend(body.buf);
    }
}

/// Minimal width in {1, 2, 4, 8} representing every value (empty -> 1).
fn sint_min_width(vals: &[i64]) -> u8 {
    let mut w = 1u8;
    for &v in vals {
        let need = if (-128..=127).contains(&v) {
            1
        } else if (-32_768..=32_767).contains(&v) {
            2
        } else if (i32::MIN as i64..=i32::MAX as i64).contains(&v) {
            4
        } else {
            8
        };
        w = w.max(need);
    }
    w
}

// ---------------------------------------------------------------------------
// Primitive reader (every read bounds-checked; never panics).

struct R<'a> {
    b: &'a [u8],
    pos: usize,
}

impl<'a> R<'a> {
    fn new(b: &'a [u8]) -> R<'a> {
        R { b, pos: 0 }
    }
    fn take(&mut self, n: usize) -> WResult<&'a [u8]> {
        if self.b.len() - self.pos < n {
            return Err(WireError::Truncated);
        }
        let s = &self.b[self.pos..self.pos + n];
        self.pos += n;
        Ok(s)
    }
    fn u8(&mut self) -> WResult<u8> {
        Ok(self.take(1)?[0])
    }
    fn u16(&mut self) -> WResult<u16> {
        Ok(u16::from_le_bytes(self.take(2)?.try_into().unwrap()))
    }
    fn u32(&mut self) -> WResult<u32> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn u64(&mut self) -> WResult<u64> {
        Ok(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    fn done(&self) -> bool {
        self.pos == self.b.len()
    }
    /// A count that must also be plausible against the remaining bytes
    /// (each element occupying at least `min_el` bytes) — rejects
    /// absurd counts before any allocation.
    fn count(&mut self, min_el: usize) -> WResult<usize> {
        let n = self.u32()? as usize;
        if min_el > 0 && n > (self.b.len() - self.pos) / min_el.max(1) {
            return Err(WireError::BadCount);
        }
        Ok(n)
    }
    fn poly(&mut self) -> WResult<WPoly> {
        let raw = self.take(WD * 4)?;
        let mut p = Vec::with_capacity(WD);
        for i in 0..WD {
            let c = u32::from_le_bytes(raw[i * 4..i * 4 + 4].try_into().unwrap()) as u64;
            if c >= WIRE_Q {
                return Err(WireError::CoeffRange);
            }
            p.push(c);
        }
        Ok(p)
    }
    fn polys(&mut self) -> WResult<Vec<WPoly>> {
        let n = self.count(WD * 4)?;
        (0..n).map(|_| self.poly()).collect()
    }
    fn kelem(&mut self) -> WResult<WKElem> {
        let raw = self.take(WK_DEG * 4)?;
        let mut k = Vec::with_capacity(WK_DEG);
        for i in 0..WK_DEG {
            let c = u32::from_le_bytes(raw[i * 4..i * 4 + 4].try_into().unwrap()) as u64;
            if c >= WIRE_Q {
                return Err(WireError::CoeffRange);
            }
            k.push(c);
        }
        Ok(k)
    }
    fn kvec(&mut self) -> WResult<Vec<WKElem>> {
        let n = self.count(WK_DEG * 4)?;
        (0..n).map(|_| self.kelem()).collect()
    }
    fn sint(&mut self) -> WResult<Vec<i64>> {
        let n = self.u32()? as usize;
        let w = self.u8()?;
        if !matches!(w, 1 | 2 | 4 | 8) {
            return Err(WireError::NonCanonicalWidth);
        }
        if n == 0 && w != 1 {
            return Err(WireError::NonCanonicalWidth);
        }
        let raw = self.take(n * w as usize)?;
        let mut vals = Vec::with_capacity(n);
        for i in 0..n {
            let s = &raw[i * w as usize..(i + 1) * w as usize];
            let v = match w {
                1 => s[0] as i8 as i64,
                2 => i16::from_le_bytes(s.try_into().unwrap()) as i64,
                4 => i32::from_le_bytes(s.try_into().unwrap()) as i64,
                _ => i64::from_le_bytes(s.try_into().unwrap()),
            };
            vals.push(v);
        }
        if sint_min_width(&vals) != w {
            return Err(WireError::NonCanonicalWidth);
        }
        Ok(vals)
    }
    fn str8(&mut self) -> WResult<String> {
        let n = self.u8()? as usize;
        if n > 32 {
            return Err(WireError::BadName);
        }
        let raw = self.take(n)?;
        if !raw.iter().all(|b| (0x20..0x7f).contains(b)) {
            return Err(WireError::BadName);
        }
        Ok(String::from_utf8(raw.to_vec()).map_err(|_| WireError::BadName)?)
    }
    /// Read a section header, requiring an exact tag; returns a
    /// sub-reader over exactly the section body.
    fn section(&mut self, expect: u16) -> WResult<R<'a>> {
        let tag = self.u16()?;
        if tag != expect {
            return Err(WireError::SectionOrder { expected: expect, got: tag });
        }
        if self.u16()? != 0 {
            return Err(WireError::ReservedNonzero);
        }
        let len = self.u64()? as usize;
        let body = self.take(len)?;
        Ok(R::new(body))
    }
    /// Peek the next section tag without consuming (envelope-aware).
    fn peek_tag(&self) -> WResult<u16> {
        if self.b.len() - self.pos < 2 {
            return Err(WireError::Truncated);
        }
        Ok(u16::from_le_bytes(self.b[self.pos..self.pos + 2].try_into().unwrap()))
    }
    fn end_section(self, tag: u16) -> WResult<()> {
        if !self.done() {
            return Err(WireError::SectionLength { tag });
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Envelope.

fn envelope(kind: u16, sections: W) -> Vec<u8> {
    let mut w = W::new();
    w.bytes(WIRE_MAGIC);
    w.u32(WIRE_VERSION);
    w.u16(kind);
    w.u8(WIRE_FIELD_ID);
    w.u8(0);
    w.u64(sections.buf.len() as u64);
    w.buf.extend(sections.buf);
    w.buf
}

/// Open the envelope: check magic/version/field id, verify the payload
/// length is exact, return (kind, payload reader).
pub fn open_envelope(bytes: &[u8]) -> WResult<(u16, &[u8])> {
    let mut r = R::new(bytes);
    if r.take(8)? != WIRE_MAGIC {
        return Err(WireError::BadMagic);
    }
    let ver = r.u32()?;
    if ver != WIRE_VERSION {
        return Err(WireError::BadVersion(ver));
    }
    let kind = r.u16()?;
    if !matches!(
        kind,
        KIND_EVAL_PROOF | KIND_FOLD_TRANSCRIPT | KIND_STATEMENT_WRAP | KIND_PASS_ARTIFACT
    ) {
        return Err(WireError::BadKind(kind));
    }
    let fid = r.u8()?;
    if fid != WIRE_FIELD_ID {
        return Err(WireError::BadFieldId(fid));
    }
    if r.u8()? != 0 {
        return Err(WireError::ReservedNonzero);
    }
    let plen = r.u64()? as usize;
    if bytes.len() < 24 {
        return Err(WireError::Truncated);
    }
    let payload = &bytes[24..];
    if payload.len() < plen {
        return Err(WireError::Truncated);
    }
    if payload.len() > plen {
        return Err(WireError::TrailingBytes);
    }
    Ok((kind, payload))
}

/// Walk an envelope's section stream: (tag, payload length) in order.
/// Structural only (no per-kind interpretation); used by the drivers'
/// offset arithmetic and the byte tables.
pub fn section_sizes(bytes: &[u8]) -> WResult<Vec<(u16, u64)>> {
    let (_, payload) = open_envelope(bytes)?;
    let mut r = R::new(payload);
    let mut out = Vec::new();
    while !r.done() {
        let tag = r.u16()?;
        if r.u16()? != 0 {
            return Err(WireError::ReservedNonzero);
        }
        let len = r.u64()?;
        r.take(len as usize)?;
        out.push((tag, len));
    }
    Ok(out)
}

/// Structural manifest-container pairing check (bytes[4..8] carry the
/// manifest codec version; full decode/validate is the caller's).
fn statement_container_cv(stmt: &[u8]) -> WResult<u32> {
    if stmt.len() < 8 {
        return Err(WireError::BadStatement);
    }
    Ok(u32::from_le_bytes(stmt[4..8].try_into().unwrap()))
}

// ---------------------------------------------------------------------------
// Shared records.

/// A (scheduled) sumcheck transcript: claim, per-round evaluation
/// vectors, final evaluations.
#[derive(Clone, Debug, PartialEq)]
pub struct WireSumcheck {
    pub v_claim: WKElem,
    pub rounds: Vec<Vec<WKElem>>,
    pub finals: Vec<WKElem>,
}

fn write_sumcheck(w: &mut W, sc: &WireSumcheck) {
    w.kelem(&sc.v_claim);
    w.u32(sc.rounds.len() as u32);
    for r0 in &sc.rounds {
        w.kvec(r0);
    }
    w.kvec(&sc.finals);
}

fn read_sumcheck(r: &mut R) -> WResult<WireSumcheck> {
    let v_claim = r.kelem()?;
    let n = r.count(4)?;
    let mut rounds = Vec::with_capacity(n);
    for _ in 0..n {
        rounds.push(r.kvec()?);
    }
    let finals = r.kvec()?;
    Ok(WireSumcheck { v_claim, rounds, finals })
}

/// Rings-of-128 view of a flat signed block.
fn write_rings(w: &mut W, rings: &[Vec<i64>]) {
    let mut flat = Vec::with_capacity(rings.len() * WD);
    for ring in rings {
        assert_eq!(ring.len(), WD, "ring must have {WD} coefficients");
        flat.extend_from_slice(ring);
    }
    w.sint(&flat);
}

fn read_rings(r: &mut R) -> WResult<Vec<Vec<i64>>> {
    let flat = r.sint()?;
    if flat.len() % WD != 0 {
        return Err(WireError::ShapeMismatch("signed block not ring-aligned"));
    }
    Ok(flat.chunks(WD).map(|c| c.to_vec()).collect())
}

// ---------------------------------------------------------------------------
// Kind 1 — the eval-proof artifact.

#[derive(Clone, Debug, PartialEq)]
pub struct WireTierZ {
    pub images: Vec<WPoly>,
    /// Masked floor response, rings of 128 coefficients. On the wire
    /// this rides the group's FLOOR slot exactly once (the bare floor
    /// is never sent under Tier-Z); the struct mirrors the engine's
    /// (GroupEvalProof.floor == TierZFloor.response) duplication so
    /// conversions are symmetric.
    pub response: Vec<Vec<i64>>,
    pub restarts: u32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct WireEvalGroup {
    pub name: String,
    pub u0: Vec<WPoly>,
    pub ugh0: Vec<WPoly>,
    pub b_rows: Vec<WPoly>,
    pub level_us: Vec<Vec<WPoly>>,
    pub floor_e: u32,
    /// Bare floor digit rings (also present under Tier-Z: the response
    /// REPLACES it on the wire — this holds the response rings then).
    pub floor: Vec<Vec<i64>>,
    pub tierz: Option<WireTierZ>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct WireEvalArtifact {
    pub rows: u32,
    pub inner: u32,
    pub cols: u32,
    pub crs_seed: u64,
    pub tier_z: bool,
    pub forced_levels: u8,
    /// Manifest container bytes, verbatim.
    pub statement: Vec<u8>,
    pub sumcheck: WireSumcheck,
    /// Exactly two groups, weight then act.
    pub groups: Vec<WireEvalGroup>,
}

fn write_eval_group(w: &mut W, g: &WireEvalGroup, tier_z: bool) {
    w.str8(&g.name);
    w.polys(&g.u0);
    w.polys(&g.ugh0);
    w.polys(&g.b_rows);
    w.u32(g.level_us.len() as u32);
    for lu in &g.level_us {
        w.polys(lu);
    }
    assert!(g.floor_e <= 255);
    w.u8(g.floor_e as u8);
    write_rings(w, &g.floor);
    assert_eq!(tier_z, g.tierz.is_some(), "tier-z flag/group mismatch");
    if let Some(tz) = &g.tierz {
        assert_eq!(tz.response, g.floor, "Tier-Z: the floor slot must carry the response");
        w.polys(&tz.images);
        w.u32(tz.restarts);
    }
}

fn read_eval_group(r: &mut R, tier_z: bool) -> WResult<WireEvalGroup> {
    let name = r.str8()?;
    let u0 = r.polys()?;
    let ugh0 = r.polys()?;
    let b_rows = r.polys()?;
    let n_levels = r.count(4)?;
    let mut level_us = Vec::with_capacity(n_levels);
    for _ in 0..n_levels {
        level_us.push(r.polys()?);
    }
    let floor_e = r.u8()? as u32;
    let floor = read_rings(r)?;
    let tierz = if tier_z {
        let images = r.polys()?;
        let restarts = r.u32()?;
        // The floor slot carries the masked response under Tier-Z.
        Some(WireTierZ { images, response: floor.clone(), restarts })
    } else {
        None
    };
    Ok(WireEvalGroup { name, u0, ugh0, b_rows, level_us, floor_e, floor, tierz })
}

pub fn encode_eval_artifact(a: &WireEvalArtifact) -> Vec<u8> {
    assert_eq!(a.groups.len(), 2, "kind-1 carries exactly two groups (W-C)");
    let mut secs = W::new();
    let mut meta = W::new();
    meta.u32(a.rows);
    meta.u32(a.inner);
    meta.u32(a.cols);
    meta.u64(a.crs_seed);
    meta.u8(u8::from(a.tier_z));
    meta.u8(a.forced_levels);
    meta.u16(0);
    secs.section(SEC_EVAL_META, meta);
    let mut st = W::new();
    st.bytes(&a.statement);
    secs.section(SEC_EVAL_STATEMENT, st);
    let mut sc = W::new();
    write_sumcheck(&mut sc, &a.sumcheck);
    secs.section(SEC_EVAL_SUMCHECK, sc);
    for g in &a.groups {
        let mut gw = W::new();
        write_eval_group(&mut gw, g, a.tier_z);
        secs.section(SEC_EVAL_GROUP, gw);
    }
    envelope(KIND_EVAL_PROOF, secs)
}

pub fn decode_eval_artifact(bytes: &[u8]) -> WResult<WireEvalArtifact> {
    let (kind, payload) = open_envelope(bytes)?;
    if kind != KIND_EVAL_PROOF {
        return Err(WireError::BadKind(kind));
    }
    let mut r = R::new(payload);
    let mut meta = r.section(SEC_EVAL_META)?;
    let rows = meta.u32()?;
    let inner = meta.u32()?;
    let cols = meta.u32()?;
    let crs_seed = meta.u64()?;
    let tzf = meta.u8()?;
    if tzf > 1 {
        return Err(WireError::ValueRange);
    }
    let tier_z = tzf == 1;
    let forced_levels = meta.u8()?;
    if meta.u16()? != 0 {
        return Err(WireError::ReservedNonzero);
    }
    meta.end_section(SEC_EVAL_META)?;
    let mut st = r.section(SEC_EVAL_STATEMENT)?;
    let statement = st.take(st.b.len())?.to_vec();
    if statement_container_cv(&statement)? != MANIFEST_CV1 {
        return Err(WireError::BadPairing);
    }
    let mut sc = r.section(SEC_EVAL_SUMCHECK)?;
    let sumcheck = read_sumcheck(&mut sc)?;
    sc.end_section(SEC_EVAL_SUMCHECK)?;
    let mut groups = Vec::with_capacity(2);
    for want in ["weight", "act"] {
        let mut gr = r.section(SEC_EVAL_GROUP)?;
        let g = read_eval_group(&mut gr, tier_z)?;
        gr.end_section(SEC_EVAL_GROUP)?;
        if g.name != want {
            return Err(WireError::ShapeMismatch("group order must be weight, act"));
        }
        groups.push(g);
    }
    if !r.done() {
        return Err(WireError::TrailingBytes);
    }
    Ok(WireEvalArtifact {
        rows,
        inner,
        cols,
        crs_seed,
        tier_z,
        forced_levels,
        statement,
        sumcheck,
        groups,
    })
}

// ---------------------------------------------------------------------------
// Kind 2 — the folded-family transcript.

#[derive(Clone, Debug, PartialEq)]
pub struct WireCtRound {
    pub h: Vec<WPoly>,
    /// Per commitment: kappa mask-image polys.
    pub w1: Vec<Vec<WPoly>>,
    pub w_claim: Vec<WPoly>,
    /// Per commitment: n_r response rings of 128 coefficients.
    pub z: Vec<Vec<Vec<i64>>>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct WireFoldTranscript {
    /// 1 = joint matmul, 2 = stacked zero-check.
    pub family: u8,
    pub layers: u32,
    pub rows: u32,
    pub inner: u32,
    pub cols: u32,
    pub kappa: u8,
    pub msg_r: u8,
    pub n_r: u8,
    pub crs_seed: u64,
    pub statement: Vec<u8>,
    pub t1s: Vec<Vec<WPoly>>,
    pub t2s: Vec<Vec<WPoly>>,
    pub sumcheck: WireSumcheck,
    pub reveals: Vec<Vec<(u32, i64)>>,
    pub waves: Vec<WireCtRound>,
    pub closing: Option<WireCtRound>,
}

fn write_ct_round(w: &mut W, c: &WireCtRound, kappa: usize, n_r: usize) {
    w.polys(&c.h);
    assert_eq!(c.w1.len(), c.z.len(), "ct-round w1/z commitment counts");
    w.u32(c.w1.len() as u32);
    for w1c in &c.w1 {
        assert_eq!(w1c.len(), kappa);
        for p in w1c {
            w.poly(p);
        }
    }
    w.polys(&c.w_claim);
    let mut flat = Vec::with_capacity(c.z.len() * n_r * WD);
    for zc in &c.z {
        assert_eq!(zc.len(), n_r);
        for ring in zc {
            assert_eq!(ring.len(), WD);
            flat.extend_from_slice(ring);
        }
    }
    w.sint(&flat);
}

fn read_ct_round(r: &mut R, kappa: usize, n_r: usize) -> WResult<WireCtRound> {
    let h = r.polys()?;
    let n_cw = r.count(kappa * WD * 4)?;
    let mut w1 = Vec::with_capacity(n_cw);
    for _ in 0..n_cw {
        let mut cm = Vec::with_capacity(kappa);
        for _ in 0..kappa {
            cm.push(r.poly()?);
        }
        w1.push(cm);
    }
    let w_claim = r.polys()?;
    let flat = r.sint()?;
    if flat.len() != n_cw * n_r * WD {
        return Err(WireError::ShapeMismatch("ct-round z block size"));
    }
    let mut z = Vec::with_capacity(n_cw);
    for c in 0..n_cw {
        let mut cm = Vec::with_capacity(n_r);
        for j in 0..n_r {
            let base = (c * n_r + j) * WD;
            cm.push(flat[base..base + WD].to_vec());
        }
        z.push(cm);
    }
    Ok(WireCtRound { h, w1, w_claim, z })
}

pub fn encode_fold_transcript(a: &WireFoldTranscript) -> Vec<u8> {
    assert!(matches!(a.family, 1 | 2));
    assert_eq!(a.t1s.len(), a.t2s.len());
    let mut secs = W::new();
    let mut meta = W::new();
    meta.u8(a.family);
    meta.u32(a.layers);
    meta.u32(a.rows);
    meta.u32(a.inner);
    meta.u32(a.cols);
    meta.u8(a.kappa);
    meta.u8(a.msg_r);
    meta.u8(a.n_r);
    meta.u8(0);
    meta.u64(a.crs_seed);
    secs.section(SEC_FOLD_META, meta);
    let mut st = W::new();
    st.bytes(&a.statement);
    secs.section(SEC_FOLD_STATEMENT, st);
    let mut tags = W::new();
    tags.u32(a.t1s.len() as u32);
    for (t1, t2) in a.t1s.iter().zip(a.t2s.iter()) {
        assert_eq!(t1.len(), a.kappa as usize);
        assert_eq!(t2.len(), a.msg_r as usize);
        for p in t1 {
            tags.poly(p);
        }
        for p in t2 {
            tags.poly(p);
        }
    }
    secs.section(SEC_FOLD_TAGS, tags);
    let mut sc = W::new();
    write_sumcheck(&mut sc, &a.sumcheck);
    secs.section(SEC_FOLD_SUMCHECK, sc);
    let mut rv = W::new();
    rv.u32(a.reveals.len() as u32);
    for claim in &a.reveals {
        rv.u32(claim.len() as u32);
        for &(wave, val) in claim {
            assert!(val.unsigned_abs() <= (WIRE_Q - 1) / 2, "reveal out of centered range");
            rv.u32(wave);
            rv.u32(val as i32 as u32);
        }
    }
    secs.section(SEC_FOLD_REVEALS, rv);
    let mut wv = W::new();
    wv.u32(a.waves.len() as u32);
    for c in &a.waves {
        write_ct_round(&mut wv, c, a.kappa as usize, a.n_r as usize);
    }
    secs.section(SEC_FOLD_WAVES, wv);
    let mut cl = W::new();
    cl.u8(u8::from(a.closing.is_some()));
    if let Some(c) = &a.closing {
        write_ct_round(&mut cl, c, a.kappa as usize, a.n_r as usize);
    }
    secs.section(SEC_FOLD_CLOSING, cl);
    envelope(KIND_FOLD_TRANSCRIPT, secs)
}

pub fn decode_fold_transcript(bytes: &[u8]) -> WResult<WireFoldTranscript> {
    let (kind, payload) = open_envelope(bytes)?;
    if kind != KIND_FOLD_TRANSCRIPT {
        return Err(WireError::BadKind(kind));
    }
    let mut r = R::new(payload);
    let mut meta = r.section(SEC_FOLD_META)?;
    let family = meta.u8()?;
    if !matches!(family, 1 | 2) {
        return Err(WireError::ValueRange);
    }
    let layers = meta.u32()?;
    let rows = meta.u32()?;
    let inner = meta.u32()?;
    let cols = meta.u32()?;
    let kappa = meta.u8()?;
    let msg_r = meta.u8()?;
    let n_r = meta.u8()?;
    if meta.u8()? != 0 {
        return Err(WireError::ReservedNonzero);
    }
    let crs_seed = meta.u64()?;
    if kappa == 0 || msg_r == 0 || n_r == 0 {
        return Err(WireError::ValueRange);
    }
    meta.end_section(SEC_FOLD_META)?;
    let mut st = r.section(SEC_FOLD_STATEMENT)?;
    let statement = st.take(st.b.len())?.to_vec();
    if statement_container_cv(&statement)? != MANIFEST_CV1 {
        return Err(WireError::BadPairing);
    }
    let mut tg = r.section(SEC_FOLD_TAGS)?;
    let n_commits = tg.count((kappa as usize + msg_r as usize) * WD * 4)?;
    let mut t1s = Vec::with_capacity(n_commits);
    let mut t2s = Vec::with_capacity(n_commits);
    for _ in 0..n_commits {
        let mut t1 = Vec::with_capacity(kappa as usize);
        for _ in 0..kappa {
            t1.push(tg.poly()?);
        }
        let mut t2 = Vec::with_capacity(msg_r as usize);
        for _ in 0..msg_r {
            t2.push(tg.poly()?);
        }
        t1s.push(t1);
        t2s.push(t2);
    }
    tg.end_section(SEC_FOLD_TAGS)?;
    let mut sc = r.section(SEC_FOLD_SUMCHECK)?;
    let sumcheck = read_sumcheck(&mut sc)?;
    sc.end_section(SEC_FOLD_SUMCHECK)?;
    let mut rv = r.section(SEC_FOLD_REVEALS)?;
    let n_claims = rv.count(4)?;
    let mut reveals = Vec::with_capacity(n_claims);
    for _ in 0..n_claims {
        let cnt = rv.count(8)?;
        let mut claim = Vec::with_capacity(cnt);
        for _ in 0..cnt {
            let wave = rv.u32()?;
            let val = rv.u32()? as i32 as i64;
            if val.unsigned_abs() > (WIRE_Q - 1) / 2 {
                return Err(WireError::ValueRange);
            }
            claim.push((wave, val));
        }
        reveals.push(claim);
    }
    rv.end_section(SEC_FOLD_REVEALS)?;
    let mut wv = r.section(SEC_FOLD_WAVES)?;
    let n_waves = wv.count(4)?;
    let mut waves = Vec::with_capacity(n_waves);
    for _ in 0..n_waves {
        waves.push(read_ct_round(&mut wv, kappa as usize, n_r as usize)?);
    }
    wv.end_section(SEC_FOLD_WAVES)?;
    let mut cl = r.section(SEC_FOLD_CLOSING)?;
    let present = cl.u8()?;
    if present > 1 {
        return Err(WireError::ValueRange);
    }
    let closing = if present == 1 {
        Some(read_ct_round(&mut cl, kappa as usize, n_r as usize)?)
    } else {
        None
    };
    cl.end_section(SEC_FOLD_CLOSING)?;
    if !r.done() {
        return Err(WireError::TrailingBytes);
    }
    Ok(WireFoldTranscript {
        family,
        layers,
        rows,
        inner,
        cols,
        kappa,
        msg_r,
        n_r,
        crs_seed,
        statement,
        t1s,
        t2s,
        sumcheck,
        reveals,
        waves,
        closing,
    })
}

// ---------------------------------------------------------------------------
// Kind 3 — the statement wrap.

#[derive(Clone, Debug, PartialEq)]
pub struct WireStatementWrap {
    /// Manifest statement version (3 or 4).
    pub version: u8,
    pub statement: Vec<u8>,
}

pub fn encode_statement_wrap(a: &WireStatementWrap) -> Vec<u8> {
    assert!(matches!(a.version, 3 | 4));
    let mut secs = W::new();
    let mut meta = W::new();
    meta.u8(a.version);
    meta.u8(0);
    meta.u8(0);
    meta.u8(0);
    secs.section(SEC_STMT_META, meta);
    let mut st = W::new();
    st.bytes(&a.statement);
    secs.section(SEC_STMT_STATEMENT, st);
    envelope(KIND_STATEMENT_WRAP, secs)
}

pub fn decode_statement_wrap(bytes: &[u8]) -> WResult<WireStatementWrap> {
    let (kind, payload) = open_envelope(bytes)?;
    if kind != KIND_STATEMENT_WRAP {
        return Err(WireError::BadKind(kind));
    }
    let mut r = R::new(payload);
    let mut meta = r.section(SEC_STMT_META)?;
    let version = meta.u8()?;
    if !matches!(version, 3 | 4) {
        return Err(WireError::ValueRange);
    }
    for _ in 0..3 {
        if meta.u8()? != 0 {
            return Err(WireError::ReservedNonzero);
        }
    }
    meta.end_section(SEC_STMT_META)?;
    let mut st = r.section(SEC_STMT_STATEMENT)?;
    let statement = st.take(st.b.len())?.to_vec();
    let cv = statement_container_cv(&statement)?;
    let want = if version == 3 { MANIFEST_CV1 } else { MANIFEST_CV2 };
    if cv != want {
        return Err(WireError::BadPairing);
    }
    if !r.done() {
        return Err(WireError::TrailingBytes);
    }
    Ok(WireStatementWrap { version, statement })
}

// ---------------------------------------------------------------------------
// Kind 4 — the multi-group pass artifact (lane BG's composition
// target; layout reserved, writer/reader landed — deliverable 3).

#[derive(Clone, Debug, PartialEq)]
pub struct PassArtifact {
    /// 0..3 = P0..P3 (Amendment A1 mode declaration).
    pub mode: u8,
    pub layers: u32,
    /// The pass statement bytes, verbatim (v4/cv2 expected).
    pub statement: Vec<u8>,
    /// (group flags, group record); flags bit0 = Tier-Z-masked floor.
    pub groups: Vec<(u8, WireEvalGroup)>,
    /// (family, folded sumcheck, stacked pin values).
    pub fold_claims: Vec<(u8, WireSumcheck, Vec<WKElem>)>,
    /// (subtag, opaque bytes) — BG extension space, preserved exactly.
    pub raw: Vec<(u16, Vec<u8>)>,
}

/// The writer API lane BG's composed pass artifact conforms to.
pub struct PassArtifactWriter {
    art: PassArtifact,
}

impl PassArtifactWriter {
    pub fn new(mode: u8, layers: u32, statement: Vec<u8>) -> PassArtifactWriter {
        assert!(mode <= 3, "mode is P0..P3");
        PassArtifactWriter {
            art: PassArtifact {
                mode,
                layers,
                statement,
                groups: Vec::new(),
                fold_claims: Vec::new(),
                raw: Vec::new(),
            },
        }
    }
    pub fn add_group_eval(&mut self, flags: u8, group: WireEvalGroup) -> &mut Self {
        assert_eq!(flags & !1, 0, "only bit0 (masked) defined");
        assert_eq!(flags & 1 == 1, group.tierz.is_some(), "masked flag vs tier-z record");
        self.art.groups.push((flags, group));
        self
    }
    pub fn add_fold_claim(
        &mut self,
        family: u8,
        sumcheck: WireSumcheck,
        pins: Vec<WKElem>,
    ) -> &mut Self {
        self.art.fold_claims.push((family, sumcheck, pins));
        self
    }
    pub fn add_raw(&mut self, subtag: u16, bytes: Vec<u8>) -> &mut Self {
        self.art.raw.push((subtag, bytes));
        self
    }
    pub fn finish(&self) -> Vec<u8> {
        encode_pass_artifact(&self.art)
    }
}

pub fn encode_pass_artifact(a: &PassArtifact) -> Vec<u8> {
    assert!(a.mode <= 3);
    assert!(a.groups.len() <= 255 && a.fold_claims.len() <= 255 && a.raw.len() <= 255);
    let mut secs = W::new();
    let mut meta = W::new();
    meta.u8(a.mode);
    meta.u32(a.layers);
    meta.u8(0);
    meta.u8(0);
    meta.u8(0);
    secs.section(SEC_PASS_META, meta);
    let mut st = W::new();
    st.bytes(&a.statement);
    secs.section(SEC_PASS_STATEMENT, st);
    for (flags, g) in &a.groups {
        let mut gw = W::new();
        gw.u8(*flags);
        write_eval_group(&mut gw, g, *flags & 1 == 1);
        secs.section(SEC_PASS_GROUP_EVAL, gw);
    }
    for (family, sc, pins) in &a.fold_claims {
        let mut fw = W::new();
        fw.u8(*family);
        write_sumcheck(&mut fw, sc);
        fw.kvec(pins);
        secs.section(SEC_PASS_FOLD_CLAIM, fw);
    }
    for (subtag, bytes) in &a.raw {
        let mut rw = W::new();
        rw.u16(*subtag);
        rw.bytes(bytes);
        secs.section(SEC_PASS_RAW, rw);
    }
    envelope(KIND_PASS_ARTIFACT, secs)
}

pub fn decode_pass_artifact(bytes: &[u8]) -> WResult<PassArtifact> {
    let (kind, payload) = open_envelope(bytes)?;
    if kind != KIND_PASS_ARTIFACT {
        return Err(WireError::BadKind(kind));
    }
    let mut r = R::new(payload);
    let mut meta = r.section(SEC_PASS_META)?;
    let mode = meta.u8()?;
    if mode > 3 {
        return Err(WireError::ValueRange);
    }
    let layers = meta.u32()?;
    for _ in 0..3 {
        if meta.u8()? != 0 {
            return Err(WireError::ReservedNonzero);
        }
    }
    meta.end_section(SEC_PASS_META)?;
    let mut st = r.section(SEC_PASS_STATEMENT)?;
    let statement = st.take(st.b.len())?.to_vec();
    statement_container_cv(&statement)?; // structural presence check only
    let mut groups = Vec::new();
    let mut fold_claims = Vec::new();
    let mut raw = Vec::new();
    // Repeated sections in fixed phase order: GROUP-EVAL*, FOLD-CLAIM*, RAW*.
    let mut phase = SEC_PASS_GROUP_EVAL;
    while !r.done() {
        let tag = r.peek_tag()?;
        if tag != SEC_PASS_GROUP_EVAL && tag != SEC_PASS_FOLD_CLAIM && tag != SEC_PASS_RAW {
            return Err(WireError::SectionOrder { expected: phase, got: tag });
        }
        if tag < phase {
            return Err(WireError::SectionOrder { expected: phase, got: tag });
        }
        phase = tag;
        let mut body = r.section(tag)?;
        match tag {
            SEC_PASS_GROUP_EVAL => {
                if groups.len() >= 255 {
                    return Err(WireError::BadCount);
                }
                let flags = body.u8()?;
                if flags & !1 != 0 {
                    return Err(WireError::ValueRange);
                }
                let g = read_eval_group(&mut body, flags & 1 == 1)?;
                body.end_section(tag)?;
                groups.push((flags, g));
            }
            SEC_PASS_FOLD_CLAIM => {
                if fold_claims.len() >= 255 {
                    return Err(WireError::BadCount);
                }
                let family = body.u8()?;
                let sc = read_sumcheck(&mut body)?;
                let pins = body.kvec()?;
                body.end_section(tag)?;
                fold_claims.push((family, sc, pins));
            }
            _ => {
                if raw.len() >= 255 {
                    return Err(WireError::BadCount);
                }
                let subtag = body.u16()?;
                let bytes = body.take(body.b.len() - body.pos)?.to_vec();
                raw.push((subtag, bytes));
            }
        }
    }
    Ok(PassArtifact { mode, layers, statement, groups, fold_claims, raw })
}

// ---------------------------------------------------------------------------
// Golden sample (freeze row UAGB1-BI-1): a fixed synthetic kind-1
// artifact whose canonical bytes pin the format — any change to the
// envelope, a primitive, section order, or the width rule moves the
// digest. Synthetic data only (no crypto claims); values chosen to
// exercise every width class the format defines.

pub fn golden_sample_kind1() -> WireEvalArtifact {
    let poly = |s: u64| -> WPoly { (0..WD as u64).map(|i| (s * 7_919 + i * 104_729) % WIRE_Q).collect() };
    let kel = |s: u64| -> WKElem { (0..WK_DEG as u64).map(|i| (s * 31 + i * 65_537) % WIRE_Q).collect() };
    let ring1 = |s: i64| -> Vec<i64> { (0..WD as i64).map(|i| ((s + i) % 127) - 63).collect() };
    let ring4 = |s: i64| -> Vec<i64> { (0..WD as i64).map(|i| (s + i) * 65_536 - 40_000).collect() };
    let group = |gname: &str, tz: bool| WireEvalGroup {
        name: gname.to_string(),
        u0: (0..11).map(|i| poly(100 + i)).collect(),
        ugh0: (0..11).map(|i| poly(200 + i)).collect(),
        b_rows: (0..16).map(|i| poly(300 + i)).collect(),
        level_us: vec![(0..11).map(|i| poly(400 + i)).collect()],
        floor_e: 7,
        floor: (0..3).map(|i| if tz { ring4(i) } else { ring1(i) }).collect(),
        tierz: if tz {
            Some(WireTierZ {
                images: (0..4).map(|i| poly(500 + i)).collect(),
                response: (0..3).map(ring4).collect(),
                restarts: 1,
            })
        } else {
            None
        },
    };
    // A tiny synthetic "manifest container" placeholder: 8 bytes with
    // the cv1 marker at [4..8] (the golden sample pins the FRAMING; the
    // real-statement legs live in the driver battery).
    let statement = {
        let mut v = vec![0u8; 8];
        v[4..8].copy_from_slice(&MANIFEST_CV1.to_le_bytes());
        v
    };
    WireEvalArtifact {
        rows: 8,
        inner: 16,
        cols: 8,
        crs_seed: 0xB1_60_1D,
        tier_z: false,
        forced_levels: 0,
        statement,
        sumcheck: WireSumcheck {
            v_claim: kel(1),
            rounds: vec![vec![kel(2), kel(3), kel(4)], vec![kel(5), kel(6), kel(7)]],
            finals: vec![kel(8), kel(9)],
        },
        groups: vec![group("weight", false), group("act", false)],
    }
}
