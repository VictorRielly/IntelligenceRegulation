//! Fixed-shape bounded transport of the experimental private block receipt.
//! Every count comes from the fixed layout; nothing read from the frame controls
//! an allocation or a loop bound. The envelope is a routing check only:
//! acceptance always requires `verify` against the caller's own statement.

use super::argument::SlotProof;
use super::layout::*;
use super::protocol::ENDPOINT_ROWS;
use super::Receipt;
use crate::field::{Fp, Fp2, P};
use crate::merkle::Digest;
use crate::pcs::OpeningZk;
use crate::sumcheck::SumcheckProof;
use crate::zk::MaskOpening;

const MAGIC: &[u8; 8] = b"HLPBWIP0";
pub(crate) const HEADER: usize = 8 + 32;
const CHECKS: usize = 256;
/// n message + Q pad entries of a hiding clear vector
const VEC: usize = 512;
const ENC_COLS: usize = 2048;
const PATH: usize = 11;
const MASK_VEC: usize = 1024;
const MASK_DOM: usize = 4096;
const MASK_PATH: usize = 12;
pub const MAX_WIRE_BYTES: usize = 4 * 1024 * 1024;

fn opening_len(groups: usize, rows: usize) -> usize {
    (groups + 1) * VEC * 16 + CHECKS * (8 + rows * 8 + 32 + PATH * 32)
}

pub(crate) fn encoded_len(lay: &Layout) -> usize {
    let slots: usize = (0..N_SLOTS).map(|s| (1 + (SLOTS[s].0 + SLOTS[s].1) * (SLOTS[s].2 + 1) + slot_terms(s)) * 16).sum();
    let mask = 2 * MASK_VEC * 16 + CHECKS * (8 + M_ROWS * 8 + 32 + MASK_PATH * 32);
    HEADER + 3 * 32 + slots + mask + opening_len(A_GROUPS, lay.a_rows) + opening_len(H_GROUPS, lay.h_rows) + 2 * opening_len(1, ENDPOINT_ROWS)
}

fn hiding_ok(o: &OpeningZk, groups: usize, rows: usize) -> bool {
    o.group_vecs.len() == groups
        && o.group_vecs.iter().all(|v| v.len() == VEC)
        && o.prox_vec.len() == VEC
        && o.columns.len() == CHECKS
        && o.columns.iter().all(|(j, c, _, p)| *j < ENC_COLS && c.len() == rows && p.len() == PATH)
}

/// Typed shape check (the verifier runs it too: a hand-built receipt gets no other shape).
pub(crate) fn validate(r: &Receipt, lay: &Layout) -> Result<(), String> {
    if r.slots.len() != N_SLOTS {
        return Err("private block wire: slot count".into());
    }
    for (s, sp) in r.slots.iter().enumerate() {
        let (n, e, d) = SLOTS[s];
        if sp.sc.rounds.len() != n + e || sp.sc.rounds.iter().any(|x| x.len() != d + 1) || sp.terms.len() != slot_terms(s) {
            return Err("private block wire: argument shape".into());
        }
    }
    let m = &r.mask_open;
    if m.q.len() != MASK_VEC
        || m.prox.len() != MASK_VEC
        || m.columns.len() != CHECKS
        || m.columns.iter().any(|(j, c, _, p)| *j >= MASK_DOM || c.len() != M_ROWS || p.len() != MASK_PATH)
        || !hiding_ok(&r.a_open, A_GROUPS, lay.a_rows)
        || !hiding_ok(&r.h_open, H_GROUPS, lay.h_rows)
        || r.io_open.iter().any(|o| !hiding_ok(o, 1, ENDPOINT_ROWS))
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
    fn hiding(&mut self, groups: usize, rows: usize) -> Result<OpeningZk, String> {
        let group_vecs = (0..groups).map(|_| self.fp2_vec(VEC)).collect::<Result<Vec<_>, String>>()?;
        let prox_vec = self.fp2_vec(VEC)?;
        let columns = (0..CHECKS).map(|_| self.column(rows, ENC_COLS, PATH)).collect::<Result<Vec<_>, String>>()?;
        Ok(OpeningZk { group_vecs, prox_vec, columns })
    }
}

pub(crate) fn decode(bytes: &[u8], binding: &Digest, lay: &Layout) -> Result<Receipt, String> {
    if bytes.len() != encoded_len(lay) || bytes.len() > MAX_WIRE_BYTES {
        return Err("private block wire: frame length".into());
    }
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
        let (n, e, d) = SLOTS[s];
        let scalar = r.fp2()?;
        let rounds = (0..n + e).map(|_| r.fp2_vec(d + 1)).collect::<Result<Vec<_>, String>>()?;
        let terms = r.fp2_vec(slot_terms(s))?;
        slots.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms });
    }
    let q = r.fp2_vec(MASK_VEC)?;
    let prox = r.fp2_vec(MASK_VEC)?;
    let columns = (0..CHECKS).map(|_| r.column(M_ROWS, MASK_DOM, MASK_PATH)).collect::<Result<Vec<_>, String>>()?;
    let mask_open = MaskOpening { q, prox, columns };
    let a_open = r.hiding(A_GROUPS, lay.a_rows)?;
    let h_open = r.hiding(H_GROUPS, lay.h_rows)?;
    let io_open = [r.hiding(1, ENDPOINT_ROWS)?, r.hiding(1, ENDPOINT_ROWS)?];
    if r.pos != bytes.len() {
        return Err("private block wire: trailing bytes".into());
    }
    Ok(Receipt { a_root, h_root, mask_root, slots, mask_open, a_open, h_open, io_open })
}
