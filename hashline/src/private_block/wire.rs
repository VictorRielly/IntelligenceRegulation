//! Fixed-shape bounded transport of the experimental private block receipt.
//! Every count comes from the fixed layout; nothing read from the frame controls
//! an allocation or a loop bound. The envelope is a routing check only:
//! acceptance always requires `verify` against the caller's own statement.

use super::argument::SlotProof;
use super::layout::*;
use super::Receipt;
use crate::field::{Fp, Fp2, P};
use crate::merkle::Digest;
use crate::pcs::OpeningZk;
use crate::sumcheck::SumcheckProof;
use crate::zk::MaskOpening;

const MAGIC: &[u8; 8] = b"HLPBLOK1";
pub(crate) const HEADER: usize = 8 + 32;
const MASK_VEC: usize = 1024;
const MASK_DOM: usize = 4096;
const MASK_PATH: usize = 12;
pub const MAX_WIRE_BYTES: usize = 4 * 1024 * 1024;

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

pub(crate) fn encoded_len(lay: &Layout) -> usize {
    let sh = lay.shape();
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    let sl = lay.slots();
    let slots: usize = (0..N_SLOTS).map(|s| (1 + (sl[s].0 + sl[s].1) * (sl[s].2 + 1) + lay.slot_terms(s)) * 16).sum();
    let mask = 2 * MASK_VEC * 16 + bd.checks * (8 + M_ROWS * 8 + 32 + MASK_PATH * 32);
    HEADER + 3 * 32 + slots + mask + bd.opening_len(sh.a_groups(), lay.a_rows) + bd.opening_len(sh.h_groups(), lay.h_rows) + 2 * ed.opening_len(1, sh.endpoint_rows)
}

/// Typed shape check (the verifier runs it too: a hand-built receipt gets no other shape).
pub(crate) fn validate(r: &Receipt, lay: &Layout) -> Result<(), String> {
    let sh = lay.shape();
    let (bd, ed) = (Dim::block(lay), Dim::endpoint(lay));
    if r.slots.len() != N_SLOTS {
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
        || m.columns.len() != bd.checks
        || m.columns.iter().any(|(j, c, _, p)| *j >= MASK_DOM || c.len() != M_ROWS || p.len() != MASK_PATH)
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
    if len > MAX_WIRE_BYTES {
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
    if bytes.len() != encoded_len(lay) || bytes.len() > MAX_WIRE_BYTES {
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
    let mut slots = Vec::with_capacity(N_SLOTS);
    for s in 0..N_SLOTS {
        let (n, e, d) = lay.slots()[s];
        let scalar = r.fp2()?;
        let rounds = (0..n + e).map(|_| r.fp2_vec(d + 1)).collect::<Result<Vec<_>, String>>()?;
        let terms = r.fp2_vec(lay.slot_terms(s))?;
        slots.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms });
    }
    let q = r.fp2_vec(MASK_VEC)?;
    let prox = r.fp2_vec(MASK_VEC)?;
    let columns = (0..bd.checks).map(|_| r.column(M_ROWS, MASK_DOM, MASK_PATH)).collect::<Result<Vec<_>, String>>()?;
    let mask_open = MaskOpening { q, prox, columns };
    let a_open = r.hiding(bd, sh.a_groups(), lay.a_rows)?;
    let h_open = r.hiding(bd, sh.h_groups(), lay.h_rows)?;
    let io_open = [r.hiding(ed, 1, sh.endpoint_rows)?, r.hiding(ed, 1, sh.endpoint_rows)?];
    if r.pos != bytes.len() {
        return Err("private block wire: trailing bytes".into());
    }
    Ok(Receipt { a_root, h_root, mask_root, slots, mask_open, a_open, h_open, io_open })
}
