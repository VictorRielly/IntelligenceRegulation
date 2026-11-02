//! Fixed-shape bounded transport of the experimental private block receipt.
//! Every count comes from the fixed layout; nothing read from the frame controls
//! an allocation or a loop bound. The envelope is a routing check only:
//! acceptance always requires `verify` against the caller's own statement.

use super::argument::SlotProof;
use super::layout::*;
use super::Receipt;
use crate::field::{Fp, Fp2, P};
use crate::merkle::Digest;
use crate::pcs::{OpeningZk, PcsParams};
use crate::sumcheck::SumcheckProof;
use crate::zk::MaskOpening;

const MAGIC: &[u8; 8] = b"HLPBLOK1";
pub(crate) const HEADER: usize = 8 + 32;
/// **The masking commitment `M`'s frame geometry, from `zk.rs`'s OWN
/// constants** (W16R2 review F5 (d), 2026-11-02; value-identical to the
/// literals 1024 / 4096 / 12 they replace): its two clear vectors (`q'` and
/// the proximity combination) are `2 * 2^MASK_LOG_MSG` Fp2 words, its
/// encoding has `2^MASK_LOG_DOM` columns, and its tree is `MASK_LOG_DOM` deep
/// (`zk::mask_open` / `zk::mask_verify_tagged`). No block shape enters.
const MASK_VEC: usize = 2 << crate::zk::MASK_LOG_MSG;
const MASK_DOM: usize = 1 << crate::zk::MASK_LOG_DOM;
const MASK_PATH: usize = crate::zk::MASK_LOG_DOM as usize;
/// **D59: the masking commitment's OWN opened-column count** (`zk::MASK_Q`).
/// Until the W16R2 profiles it was read as the block's `Dim::checks`, which
/// was the same 256 at every profile; at a W16R2 profile the block opens 260
/// columns and `M` still opens 256, so `M`'s count is its own constant. The
/// value is 256 at every profile, so no frame length or byte moves.
const MASK_CHECKS: usize = crate::zk::MASK_Q;
/// **THE TOY'S wire bound, unchanged in name and value for every existing
/// caller.** A toy frame over 4 MiB is refused exactly as it always was.
pub const MAX_WIRE_BYTES: usize = 4 * 1024 * 1024;

/// The absolute ceiling any profile's frame must fit, whatever its shape
/// says: nothing beyond this is ever length-checked, let alone allocated.
/// 125M's counted receipt is about 40.7 MB, so this leaves headroom without
/// letting a shape ask for an unbounded frame.
pub(crate) const MAX_WIRE_BYTES_ANY: usize = 64 * 1024 * 1024;

/// **ROUND 2 (R2-5): the ceiling of a TRAINED-CALIBRATION profile.** The
/// TinyLlama T512 block counts 72.1 MB at row width 2^14 (57.1 MB at 2^15),
/// over the 64 MiB ceiling every development profile keeps. A trained profile
/// is still bounded by its own counted length (which decode requires
/// exactly); this only lifts the absolute transport ceiling, for those
/// profiles alone. It is absorbed into no transcript and moves no byte of any
/// registered profile.
pub(crate) const MAX_WIRE_BYTES_TRAINED: usize = 256 * 1024 * 1024;

/// the absolute ceiling of one frame or segment at this shape
pub(crate) fn wire_ceiling(sh: &super::shape::Shape) -> usize {
    if sh.trained_calibration {
        MAX_WIRE_BYTES_TRAINED
    } else {
        MAX_WIRE_BYTES_ANY
    }
}

/// **THE WIRE BOUND, PER PROFILE (the S11a ruling).** `MAX_WIRE_BYTES` is the
/// TOY's and stays exactly what it is. Every other profile is bounded by its
/// OWN shape's counted receipt length — the number `decode` already requires
/// equality with — capped by [`MAX_WIRE_BYTES_ANY`]. The bound is a transport
/// limit and is absorbed into no transcript: the padded rung endpoint puts
/// the rung frame 23,960 B over 4 MiB and the 125M frame far past it, and a
/// fixed constant would refuse a correctly formed receipt for no reason a
/// verifier could state.
pub(crate) fn wire_bound(lay: &Layout) -> usize {
    let sh = lay.shape();
    if sh.is_frozen_toy() {
        MAX_WIRE_BYTES
    } else {
        std::cmp::min(sh.receipt_bytes().total, wire_ceiling(sh))
    }
}

/// **STEP C part 2.** The four numbers that fix the transport of ONE hiding
/// opening, as a function of the shape: how many columns are opened, the
/// length of a clear vector (`n` message words plus `Q` pads — the pad count
/// and the number of opened columns move together), the encoded row width and
/// the Merkle path length. `Dim::block` is the `A` / `H` commitments'; the
/// endpoints have their own PCS parameters and so their own `Dim`.
#[derive(Clone, Copy)]
struct Dim {
    checks: usize,
    vec: usize,
    enc_cols: usize,
    path: usize,
}

impl Dim {
    fn new(log_n: usize, inv_rate: usize, opened_cols: usize) -> Dim {
        let n = 1usize << log_n;
        let enc_cols = n * inv_rate;
        Dim { checks: opened_cols, vec: n + opened_cols, enc_cols, path: enc_cols.next_power_of_two().trailing_zeros() as usize }
    }
    fn block(lay: &Layout) -> Dim {
        let sh = lay.shape();
        Dim::new(sh.log_cols, sh.inv_rate, sh.opened_cols)
    }
    fn endpoint(lay: &Layout) -> Dim {
        let sh = lay.shape();
        Dim::new(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols)
    }
    fn opening_len(&self, groups: usize, rows: usize) -> usize {
        (groups + 1) * self.vec * 16 + self.checks * (8 + rows * 8 + 32 + self.path * 32)
    }
    fn hiding_ok(&self, o: &OpeningZk, groups: usize, rows: usize) -> bool {
        o.group_vecs.len() == groups
            && o.group_vecs.iter().all(|v| v.len() == self.vec)
            && o.prox_vec.len() == self.vec
            && o.columns.len() == self.checks
            && o.columns.iter().all(|(j, c, _, p)| *j < self.enc_cols && c.len() == rows && p.len() == self.path)
    }
}

/// **T-4.** The Merkle tree depth of a commitment with these PCS parameters
/// — `log2` of its encoded column count, which is exactly the number of path
/// entries a frame carries for it. This is the ONE expression: the frame
/// format reads its path count from `Dim::path`, and
/// `hash_domain::paths_are_the_tree_depth` checks the verifier's structures
/// against the same value through this function, so the two can never drift.
pub(crate) fn path_len(params: &PcsParams) -> usize {
    Dim::new(params.log_cols as usize, params.inv_rate, params.num_col_checks).path
}

/// **T-4.** The masking commitment's tree depth. `zk::mask_commit` builds its
/// tree over the `2^MASK_LOG_DOM` columns of the masking encoding, and this
/// is the same constant the frame's column reader uses.
pub(crate) const MASK_PATH_LEN: usize = MASK_PATH;

pub(crate) fn encoded_len(lay: &Layout) -> usize {
    let sh = lay.shape();
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    let sl = lay.slots();
    let slots: usize = (0..lay.n_slots()).map(|s| (1 + (sl[s].0 + sl[s].1) * (sl[s].2 + 1) + lay.slot_terms(s)) * 16).sum();
    let mask = 2 * MASK_VEC * 16 + MASK_CHECKS * (8 + lay.m_rows() * 8 + 32 + MASK_PATH * 32);
    HEADER + 3 * 32 + slots + mask + bd.opening_len(sh.a_groups(), lay.a_rows) + bd.opening_len(sh.h_groups(), lay.h_rows) + 2 * ed.opening_len(1, sh.endpoint_rows)
}

/// Typed shape check (the verifier runs it too: a hand-built receipt gets no other shape).
pub(crate) fn validate(r: &Receipt, lay: &Layout) -> Result<(), String> {
    let sh = lay.shape();
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    if r.slots.len() != lay.n_slots() {
        return Err("private block wire: slot count".into());
    }
    for (s, sp) in r.slots.iter().enumerate() {
        let (n, e, d) = lay.slots()[s];
        if sp.sc.rounds.len() != n + e || sp.sc.rounds.iter().any(|x| x.len() != d + 1) || sp.terms.len() != lay.slot_terms(s) {
            return Err("private block wire: argument shape".into());
        }
    }
    let m = &r.mask_open;
    if m.q.len() != MASK_VEC
        || m.prox.len() != MASK_VEC
        || m.columns.len() != MASK_CHECKS
        || m.columns.iter().any(|(j, c, _, p)| *j >= MASK_DOM || c.len() != lay.m_rows() || p.len() != MASK_PATH)
        || !bd.hiding_ok(&r.a_open, sh.a_groups(), lay.a_rows)
        || !bd.hiding_ok(&r.h_open, sh.h_groups(), lay.h_rows)
        || r.io_open.iter().any(|o| !ed.hiding_ok(o, 1, sh.endpoint_rows))
    {
        return Err("private block wire: opening shape".into());
    }
    Ok(())
}

pub(crate) fn encode(r: &Receipt, binding: &Digest, lay: &Layout) -> Result<Vec<u8>, String> {
    validate(r, lay)?;
    let len = encoded_len(lay);
    if len > wire_bound(lay) {
        return Err("private block wire: frame exceeds bound".into());
    }
    let mut out = Vec::with_capacity(len);
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(binding);
    for root in [&r.a_root, &r.h_root, &r.mask_root] {
        out.extend_from_slice(root);
    }
    for sp in &r.slots {
        out.extend_from_slice(&sp.scalar.to_bytes());
        sp.sc.write_bytes(&mut out);
        for t in &sp.terms {
            out.extend_from_slice(&t.to_bytes());
        }
    }
    r.mask_open.write_bytes(&mut out);
    r.a_open.write_bytes(&mut out);
    r.h_open.write_bytes(&mut out);
    for o in &r.io_open {
        o.write_bytes(&mut out);
    }
    // the decoder re-checks every field word for canonicality and the exact length
    decode(&out, binding, lay)?;
    Ok(out)
}

struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
}

impl Reader<'_> {
    fn take<const K: usize>(&mut self) -> Result<[u8; K], String> {
        let end = self.pos.checked_add(K).filter(|e| *e <= self.bytes.len()).ok_or("private block wire: truncated frame")?;
        let out: [u8; K] = self.bytes[self.pos..end].try_into().map_err(|_| "private block wire: truncated frame")?;
        self.pos = end;
        Ok(out)
    }
    fn fp(&mut self) -> Result<Fp, String> {
        let v = u64::from_le_bytes(self.take()?);
        if v >= P {
            return Err("private block wire: noncanonical field word".into());
        }
        Ok(Fp(v))
    }
    fn fp2(&mut self) -> Result<Fp2, String> {
        Ok(Fp2::new(self.fp()?, self.fp()?))
    }
    fn fp2_vec(&mut self, n: usize) -> Result<Vec<Fp2>, String> {
        (0..n).map(|_| self.fp2()).collect()
    }
    fn column(&mut self, rows: usize, bound: usize, path: usize) -> Result<(usize, Vec<Fp>, [u8; 32], Vec<Digest>), String> {
        let j = u64::from_le_bytes(self.take()?);
        if j >= bound as u64 {
            return Err("private block wire: column index".into());
        }
        let col = (0..rows).map(|_| self.fp()).collect::<Result<Vec<Fp>, String>>()?;
        let salt = self.take::<32>()?;
        let path = (0..path).map(|_| self.take::<32>()).collect::<Result<Vec<Digest>, String>>()?;
        Ok((j as usize, col, salt, path))
    }
    fn hiding(&mut self, d: Dim, groups: usize, rows: usize) -> Result<OpeningZk, String> {
        let group_vecs = (0..groups).map(|_| self.fp2_vec(d.vec)).collect::<Result<Vec<_>, String>>()?;
        let prox_vec = self.fp2_vec(d.vec)?;
        let columns = (0..d.checks).map(|_| self.column(rows, d.enc_cols, d.path)).collect::<Result<Vec<_>, String>>()?;
        Ok(OpeningZk { group_vecs, prox_vec, columns })
    }
}

pub(crate) fn decode(bytes: &[u8], binding: &Digest, lay: &Layout) -> Result<Receipt, String> {
    if bytes.len() != encoded_len(lay) || bytes.len() > wire_bound(lay) {
        return Err("private block wire: frame length".into());
    }
    let sh = lay.shape();
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    let mut r = Reader { bytes, pos: 0 };
    if &r.take::<8>()? != MAGIC {
        return Err("private block wire: frame profile".into());
    }
    if &r.take::<32>()? != binding {
        return Err("private block wire: expected statement mismatch".into());
    }
    let (a_root, h_root, mask_root) = (r.take::<32>()?, r.take::<32>()?, r.take::<32>()?);
    let mut slots = Vec::with_capacity(lay.n_slots());
    for s in 0..lay.n_slots() {
        let (n, e, d) = lay.slots()[s];
        let scalar = r.fp2()?;
        let rounds = (0..n + e).map(|_| r.fp2_vec(d + 1)).collect::<Result<Vec<_>, String>>()?;
        let terms = r.fp2_vec(lay.slot_terms(s))?;
        slots.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms });
    }
    let q = r.fp2_vec(MASK_VEC)?;
    let prox = r.fp2_vec(MASK_VEC)?;
    let columns = (0..MASK_CHECKS).map(|_| r.column(lay.m_rows(), MASK_DOM, MASK_PATH)).collect::<Result<Vec<_>, String>>()?;
    let mask_open = MaskOpening { q, prox, columns };
    let a_open = r.hiding(bd, sh.a_groups(), lay.a_rows)?;
    let h_open = r.hiding(bd, sh.h_groups(), lay.h_rows)?;
    let io_open = [r.hiding(ed, 1, sh.endpoint_rows)?, r.hiding(ed, 1, sh.endpoint_rows)?];
    if r.pos != bytes.len() {
        return Err("private block wire: trailing bytes".into());
    }
    Ok(Receipt { a_root, h_root, mask_root, slots, mask_open, a_open, h_open, io_open })
}

// ---------------------------------------------------------------- STAGE 12: the run's segments

/// A run's segment frame. A block receipt's magic is `HLPBLOK1`; a segment is
/// never a block receipt and never decodes as one.
const RUN_MAGIC: &[u8; 8] = b"HLPRUNS1";

/// magic (8) + the run's binding digest (32) + `L` (8) + the segment index (8)
/// + the transcript POSITION TAG the verifier must already be at (32).
///
/// **RULING M-6 and the check's OMITTED CONDITION 5.** The header and the
/// trailer are OUTSIDE the Fiat-Shamir chain: they are never absorbed (a
/// state cannot hash itself), they are COMPARED and never adopted, and the
/// real binding between segments is the chain itself. The position tag is a
/// challenge squeezed from a CLONE of the transcript, which is a function of
/// the 32-byte state AND the squeeze counter — `zkp-core`'s `Transcript`
/// publishes no counter accessor and is a file this lane does not edit, so a
/// tag is how both are compared with 32 bytes (finding U-3).
pub(crate) const RUN_HEADER: usize = 8 + 32 + 8 + 8 + 32;
/// the position tag at the end of the stage
pub(crate) const RUN_TRAILER: usize = 32;

/// One stage's bytes: the existing per-block frame with the endpoint openings
/// replaced by the openings a run's stage actually performs.
pub(crate) struct Segment {
    /// the internal boundary this stage COMMITS (`B_k`), absent on the last
    pub b_root: Option<Digest>,
    pub a_root: Digest,
    pub h_root: Digest,
    pub mask_root: Digest,
    pub slots: Vec<SlotProof>,
    pub mask_open: MaskOpening,
    pub a_open: OpeningZk,
    pub h_open: OpeningZk,
    /// the opening of the commitment this stage CLOSES: `B_{k-1}` with its two
    /// claims for `k > 0`, the run's external input endpoint for `k = 0`
    pub in_open: OpeningZk,
    /// the external OUTPUT endpoint's opening; the last stage only
    pub out_open: Option<OpeningZk>,
}

/// The geometry of segment `k` of an `L`-stage run. Every number here is a
/// function of the VERIFIER'S OWN statement — `L`, the shape, the boundary
/// construction — and none of it is ever read from a frame.
#[derive(Clone, Copy)]
pub(crate) struct SegGeom {
    pub l: usize,
    pub k: usize,
    /// an internal boundary's DERIVED row count
    pub boundary_rows: usize,
    /// how many claim sites an internal boundary has (its opening's groups)
    pub sites: usize,
}

impl SegGeom {
    /// does this stage commit an internal boundary?
    pub(crate) fn commits_boundary(&self) -> bool {
        self.k + 1 < self.l
    }
    /// does this stage close the run's external output endpoint?
    pub(crate) fn closes_output(&self) -> bool {
        self.k + 1 == self.l
    }
    /// `(groups, rows)` of the opening this stage closes
    fn incoming(&self, endpoint_rows: usize) -> (usize, usize) {
        if self.k == 0 {
            (1, endpoint_rows)
        } else {
            (self.sites, self.boundary_rows)
        }
    }
}

/// The exact byte length of segment `k`. Three lengths occur in a run — the
/// first (which closes the external input endpoint), the interior ones (which
/// close a two-group boundary) and the last (which closes a boundary AND the
/// external output endpoint) — and each is counted here, never measured.
pub(crate) fn segment_len(lay: &Layout, g: SegGeom) -> usize {
    let sh = lay.shape();
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    let sl = lay.slots();
    let slots: usize = (0..lay.n_slots()).map(|s| (1 + (sl[s].0 + sl[s].1) * (sl[s].2 + 1) + lay.slot_terms(s)) * 16).sum();
    let mask = 2 * MASK_VEC * 16 + MASK_CHECKS * (8 + lay.m_rows() * 8 + 32 + MASK_PATH * 32);
    let (gi, ri) = g.incoming(sh.endpoint_rows);
    RUN_HEADER
        + usize::from(g.commits_boundary()) * 32
        + 3 * 32
        + slots
        + mask
        + bd.opening_len(sh.a_groups(), lay.a_rows)
        + bd.opening_len(sh.h_groups(), lay.h_rows)
        + ed.opening_len(gi, ri)
        + usize::from(g.closes_output()) * ed.opening_len(1, sh.endpoint_rows)
        + RUN_TRAILER
}

/// The typed shape check of one segment, run by the prover's encoder and by
/// the verifier's decoder alike.
fn validate_segment(s: &Segment, lay: &Layout, g: SegGeom) -> Result<(), String> {
    let sh = lay.shape();
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    if s.slots.len() != lay.n_slots() {
        return Err("private run wire: slot count".into());
    }
    for (i, sp) in s.slots.iter().enumerate() {
        let (n, e, d) = lay.slots()[i];
        if sp.sc.rounds.len() != n + e || sp.sc.rounds.iter().any(|x| x.len() != d + 1) || sp.terms.len() != lay.slot_terms(i) {
            return Err("private run wire: argument shape".into());
        }
    }
    if s.b_root.is_some() != g.commits_boundary() || s.out_open.is_some() != g.closes_output() {
        return Err("private run wire: this segment's parts are not the run schedule's".into());
    }
    let m = &s.mask_open;
    let (gi, ri) = g.incoming(sh.endpoint_rows);
    if m.q.len() != MASK_VEC
        || m.prox.len() != MASK_VEC
        || m.columns.len() != MASK_CHECKS
        || m.columns.iter().any(|(j, c, _, p)| *j >= MASK_DOM || c.len() != lay.m_rows() || p.len() != MASK_PATH)
        || !bd.hiding_ok(&s.a_open, sh.a_groups(), lay.a_rows)
        || !bd.hiding_ok(&s.h_open, sh.h_groups(), lay.h_rows)
        || !ed.hiding_ok(&s.in_open, gi, ri)
        || s.out_open.as_ref().is_some_and(|o| !ed.hiding_ok(o, 1, sh.endpoint_rows))
    {
        return Err("private run wire: opening shape".into());
    }
    Ok(())
}

/// `binding` is the run transcript's state after its HEADER — the one value
/// every segment of one run shares and no segment of another does.
pub(crate) fn encode_segment(s: &Segment, lay: &Layout, g: SegGeom, binding: &Digest, start_tag: &[u8; 32], end_tag: &[u8; 32]) -> Result<Vec<u8>, String> {
    validate_segment(s, lay, g)?;
    let len = segment_len(lay, g);
    if len > wire_ceiling(lay.shape()) {
        return Err("private run wire: segment exceeds bound".into());
    }
    let mut out = Vec::with_capacity(len);
    out.extend_from_slice(RUN_MAGIC);
    out.extend_from_slice(binding);
    out.extend_from_slice(&(g.l as u64).to_le_bytes());
    out.extend_from_slice(&(g.k as u64).to_le_bytes());
    out.extend_from_slice(start_tag);
    if let Some(r) = &s.b_root {
        out.extend_from_slice(r);
    }
    for root in [&s.a_root, &s.h_root, &s.mask_root] {
        out.extend_from_slice(root);
    }
    for sp in &s.slots {
        out.extend_from_slice(&sp.scalar.to_bytes());
        sp.sc.write_bytes(&mut out);
        for t in &sp.terms {
            out.extend_from_slice(&t.to_bytes());
        }
    }
    s.mask_open.write_bytes(&mut out);
    s.a_open.write_bytes(&mut out);
    s.h_open.write_bytes(&mut out);
    s.in_open.write_bytes(&mut out);
    if let Some(o) = &s.out_open {
        o.write_bytes(&mut out);
    }
    out.extend_from_slice(end_tag);
    if out.len() != len {
        return Err(format!("private run wire: segment {} is {} B, the counted length is {len}", g.k, out.len()));
    }
    Ok(out)
}

/// Decode segment `k`. The header is COMPARED against the verifier's own run
/// binding, its own `L`, its own index and its own transcript position, and
/// none of it is absorbed or adopted (ruling M-6). The trailer is returned for
/// the caller to compare once the stage has been replayed.
pub(crate) fn decode_segment(bytes: &[u8], lay: &Layout, g: SegGeom, binding: &Digest, start_tag: &[u8; 32]) -> Result<(Segment, [u8; 32]), String> {
    let sh = lay.shape();
    let len = segment_len(lay, g);
    if bytes.len() != len || len > wire_ceiling(sh) {
        return Err(format!("private run wire: segment {} is {} B, the counted length is {len}", g.k, bytes.len()));
    }
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    let mut r = Reader { bytes, pos: 0 };
    if &r.take::<8>()? != RUN_MAGIC {
        return Err("private run wire: segment profile".into());
    }
    if &r.take::<32>()? != binding {
        return Err("private run wire: this segment belongs to another run".into());
    }
    if u64::from_le_bytes(r.take::<8>()?) != g.l as u64 || u64::from_le_bytes(r.take::<8>()?) != g.k as u64 {
        return Err(format!("private run wire: segment {} is not the {}-segment run's segment {}", g.k, g.l, g.k));
    }
    if &r.take::<32>()? != start_tag {
        return Err(format!("private run wire: segment {}'s header is not the verifier's own transcript position", g.k));
    }
    let b_root = if g.commits_boundary() { Some(r.take::<32>()?) } else { None };
    let (a_root, h_root, mask_root) = (r.take::<32>()?, r.take::<32>()?, r.take::<32>()?);
    let mut slots = Vec::with_capacity(lay.n_slots());
    for s in 0..lay.n_slots() {
        let (n, e, d) = lay.slots()[s];
        let scalar = r.fp2()?;
        let rounds = (0..n + e).map(|_| r.fp2_vec(d + 1)).collect::<Result<Vec<_>, String>>()?;
        let terms = r.fp2_vec(lay.slot_terms(s))?;
        slots.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms });
    }
    let q = r.fp2_vec(MASK_VEC)?;
    let prox = r.fp2_vec(MASK_VEC)?;
    let columns = (0..MASK_CHECKS).map(|_| r.column(lay.m_rows(), MASK_DOM, MASK_PATH)).collect::<Result<Vec<_>, String>>()?;
    let mask_open = MaskOpening { q, prox, columns };
    let a_open = r.hiding(bd, sh.a_groups(), lay.a_rows)?;
    let h_open = r.hiding(bd, sh.h_groups(), lay.h_rows)?;
    let (gi, ri) = g.incoming(sh.endpoint_rows);
    let in_open = r.hiding(ed, gi, ri)?;
    let out_open = if g.closes_output() { Some(r.hiding(ed, 1, sh.endpoint_rows)?) } else { None };
    let end_tag = r.take::<32>()?;
    if r.pos != bytes.len() {
        return Err("private run wire: trailing bytes".into());
    }
    let seg = Segment { b_root, a_root, h_root, mask_root, slots, mask_open, a_open, h_open, in_open, out_open };
    validate_segment(&seg, lay, g)?;
    Ok((seg, end_tag))
}

// D55 (2026-11-01), registered by D60 (2026-11-02): the frames of a "commit,
// fork, join" receipt, production code since D60; see `run_fork_wire.rs`.
#[path = "run_fork_wire.rs"]
pub(crate) mod fork;
