//! New R14 segment envelope. Reuses native canonical readers and opening
//! encodings; every loop/allocation count is derived from the trusted profile.
use super::*;
use crate::private_block::split_profile::SplitProfile;

const R14_MAGIC: &[u8; 8] = b"HLPR14S1";
const R14_HEADER: usize = 8 + 32 + 32 + 8 + 8 + 32;
pub(crate) struct Geometry<'a> {
    profile: &'a SplitProfile,
    l: usize,
    k: usize,
}
impl<'a> Geometry<'a> {
    pub(crate) fn new(profile: &'a SplitProfile, l: usize, k: usize) -> Result<Self, String> {
        if !(1..=128).contains(&l) || k >= l {
            return Err("R14 wire: invalid trusted stage geometry".into());
        }
        Ok(Self { profile, l, k })
    }
    fn boundary(&self) -> bool {
        self.k + 1 < self.l
    }
    fn output(&self) -> bool {
        self.k + 1 == self.l
    }
    fn incoming(&self) -> (usize, usize) {
        let e = &self.profile.layout().endpoint;
        if self.k == 0 {
            (2, e.external_rows)
        } else {
            (4, e.internal_rows)
        }
    }
    fn dims(&self) -> (Dim, Dim) {
        let s = self.profile.base();
        (
            Dim::new(s.log_cols, s.inv_rate, s.opened_cols),
            Dim::new(s.endpoint_log_n, s.endpoint_inv_rate, s.opened_cols),
        )
    }
    fn groups(&self) -> (usize, usize) {
        let dd = usize::from(self.profile.base().dd_cap > 0);
        (56 + 2 * dd, 11 + dd)
    }
    fn slot_bytes(&self) -> usize {
        self.profile
            .layout()
            .slots
            .iter()
            .map(|s| {
                (1 + (s.main + s.ext) * (s.degree + 1) + s.a_sites + s.h_sites + s.endpoint_sites)
                    * 16
            })
            .sum()
    }
    pub(crate) fn encoded_len(&self) -> usize {
        let s = self.profile.layout();
        let (bd, ed) = self.dims();
        let (ag, hg) = self.groups();
        let (gi, ri) = self.incoming();
        R14_HEADER
            + usize::from(self.boundary()) * 32
            + 3 * 32
            + self.slot_bytes()
            + 2 * MASK_VEC * 16
            + bd.checks * (8 + s.m_rows * 8 + 32 + MASK_PATH * 32)
            + bd.opening_len(ag, s.a_rows)
            + bd.opening_len(hg, s.h_rows)
            + ed.opening_len(gi, ri)
            + usize::from(self.output()) * ed.opening_len(2, s.endpoint.external_rows)
            + RUN_TRAILER
    }
    fn bounded(&self) -> Result<usize, String> {
        let len = self.encoded_len();
        if len > MAX_WIRE_BYTES_TRAINED {
            return Err("R14 wire: segment exceeds bounded transport".into());
        }
        Ok(len)
    }
    fn validate(&self, r: &Segment) -> Result<(), String> {
        let s = self.profile.layout();
        let (bd, ed) = self.dims();
        let (ag, hg) = self.groups();
        let (gi, ri) = self.incoming();
        if r.b_root.is_some() != self.boundary()
            || r.out_open.is_some() != self.output()
            || r.slots.len() != s.slots.len()
        {
            return Err("R14 wire: stage opening or slot count differs".into());
        }
        for (proof, slot) in r.slots.iter().zip(&s.slots) {
            if proof.sc.rounds.len() != slot.main + slot.ext
                || proof
                    .sc
                    .rounds
                    .iter()
                    .any(|round| round.len() != slot.degree + 1)
                || proof.terms.len() != slot.a_sites + slot.h_sites + slot.endpoint_sites
            {
                return Err("R14 wire: argument dimensions differ".into());
            }
        }
        let m = &r.mask_open;
        if m.q.len() != MASK_VEC
            || m.prox.len() != MASK_VEC
            || m.columns.len() != bd.checks
            || m.columns
                .iter()
                .any(|(j, c, _, p)| *j >= MASK_DOM || c.len() != s.m_rows || p.len() != MASK_PATH)
            || !bd.hiding_ok(&r.a_open, ag, s.a_rows)
            || !bd.hiding_ok(&r.h_open, hg, s.h_rows)
            || !ed.hiding_ok(&r.in_open, gi, ri)
            || r.out_open
                .as_ref()
                .is_some_and(|o| !ed.hiding_ok(o, 2, s.endpoint.external_rows))
        {
            return Err("R14 wire: opening dimensions differ".into());
        }
        self.bounded()?;
        Ok(())
    }
}

pub(crate) fn encode(
    seg: &Segment,
    g: &Geometry<'_>,
    binding: &Digest,
    start: &Digest,
    end: &Digest,
) -> Result<Vec<u8>, String> {
    g.validate(seg)?;
    let len = g.bounded()?;
    let mut out = Vec::with_capacity(len);
    out.extend_from_slice(R14_MAGIC);
    out.extend_from_slice(binding);
    out.extend_from_slice(&g.profile.digest());
    out.extend_from_slice(&(g.l as u64).to_le_bytes());
    out.extend_from_slice(&(g.k as u64).to_le_bytes());
    out.extend_from_slice(start);
    if let Some(root) = seg.b_root {
        out.extend_from_slice(&root);
    }
    for root in [seg.a_root, seg.h_root, seg.mask_root] {
        out.extend_from_slice(&root);
    }
    for sp in &seg.slots {
        out.extend_from_slice(&sp.scalar.to_bytes());
        sp.sc.write_bytes(&mut out);
        for t in &sp.terms {
            out.extend_from_slice(&t.to_bytes());
        }
    }
    seg.mask_open.write_bytes(&mut out);
    seg.a_open.write_bytes(&mut out);
    seg.h_open.write_bytes(&mut out);
    seg.in_open.write_bytes(&mut out);
    if let Some(o) = &seg.out_open {
        o.write_bytes(&mut out);
    }
    out.extend_from_slice(end);
    if out.len() != len {
        return Err("R14 wire: serialization differs from native count".into());
    }
    decode(&out, g, binding, start)?;
    Ok(out)
}

pub(crate) fn decode(
    bytes: &[u8],
    g: &Geometry<'_>,
    binding: &Digest,
    start: &Digest,
) -> Result<(Segment, Digest), String> {
    let len = g.bounded()?;
    if bytes.len() != len {
        return Err("R14 wire: segment length differs".into());
    }
    let mut r = Reader { bytes, pos: 0 };
    if &r.take::<8>()? != R14_MAGIC {
        return Err("R14 wire: wrong frame version".into());
    }
    if &r.take::<32>()? != binding {
        return Err("R14 wire: another run binding".into());
    }
    if r.take::<32>()? != g.profile.digest() {
        return Err("R14 wire: another stage profile/calibration".into());
    }
    if u64::from_le_bytes(r.take::<8>()?) != g.l as u64
        || u64::from_le_bytes(r.take::<8>()?) != g.k as u64
    {
        return Err("R14 wire: another stage index/count".into());
    }
    if &r.take::<32>()? != start {
        return Err("R14 wire: another transcript position".into());
    }
    let b_root = if g.boundary() {
        Some(r.take::<32>()?)
    } else {
        None
    };
    let (a_root, h_root, mask_root) = (r.take::<32>()?, r.take::<32>()?, r.take::<32>()?);
    let s = g.profile.layout();
    let (bd, ed) = g.dims();
    let (ag, hg) = g.groups();
    let mut slots = Vec::with_capacity(s.slots.len());
    for slot in &s.slots {
        let scalar = r.fp2()?;
        let rounds = (0..slot.main + slot.ext)
            .map(|_| r.fp2_vec(slot.degree + 1))
            .collect::<Result<Vec<_>, _>>()?;
        let terms = r.fp2_vec(slot.a_sites + slot.h_sites + slot.endpoint_sites)?;
        slots.push(SlotProof {
            scalar,
            sc: SumcheckProof { rounds },
            terms,
        });
    }
    let q = r.fp2_vec(MASK_VEC)?;
    let prox = r.fp2_vec(MASK_VEC)?;
    let columns = (0..bd.checks)
        .map(|_| r.column(s.m_rows, MASK_DOM, MASK_PATH))
        .collect::<Result<Vec<_>, _>>()?;
    let mask_open = MaskOpening { q, prox, columns };
    let a_open = r.hiding(bd, ag, s.a_rows)?;
    let h_open = r.hiding(bd, hg, s.h_rows)?;
    let (gi, ri) = g.incoming();
    let in_open = r.hiding(ed, gi, ri)?;
    let out_open = if g.output() {
        Some(r.hiding(ed, 2, s.endpoint.external_rows)?)
    } else {
        None
    };
    let end = r.take::<32>()?;
    if r.pos != bytes.len() {
        return Err("R14 wire: trailing bytes".into());
    }
    let seg = Segment {
        b_root,
        a_root,
        h_root,
        mask_root,
        slots,
        mask_open,
        a_open,
        h_open,
        in_open,
        out_open,
    };
    g.validate(&seg)?;
    Ok((seg, end))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::shape::{self, NormCalibration, Shape};
    fn profile() -> SplitProfile {
        let cal = NormCalibration {
            tn: 9,
            cn_a: 100,
            cn_m: 100,
            ceps: 1,
            sh_ao: 7,
            sh_qkv: 8,
            sh_s: 6,
            sh_o: 9,
            sh_g: 8,
            sh_h: 14,
            sh_z: 6,
        };
        SplitProfile::new(Shape::accuracy_trained(shape::R13_SHIELD_T128_H24, &cal, 9, 20).unwrap())
            .unwrap()
    }
    fn opening(d: Dim, groups: usize, rows: usize) -> OpeningZk {
        OpeningZk {
            group_vecs: vec![vec![Fp2::ZERO; d.vec]; groups],
            prox_vec: vec![Fp2::ZERO; d.vec],
            columns: (0..d.checks)
                .map(|j| (j, vec![Fp::ZERO; rows], [0; 32], vec![[0; 32]; d.path]))
                .collect(),
        }
    }
    fn fixture(g: &Geometry<'_>) -> Segment {
        // Canonical shaped zero bytes exercise transport only. They are not
        // a valid cryptographic receipt and no verifier acceptance is claimed.
        let s = g.profile.layout();
        let (bd, ed) = g.dims();
        let (ag, hg) = g.groups();
        let (gi, ri) = g.incoming();
        Segment {
            b_root: if g.boundary() { Some([1; 32]) } else { None },
            a_root: [2; 32],
            h_root: [3; 32],
            mask_root: [4; 32],
            slots: s
                .slots
                .iter()
                .map(|s| SlotProof {
                    scalar: Fp2::ZERO,
                    sc: SumcheckProof {
                        rounds: vec![vec![Fp2::ZERO; s.degree + 1]; s.main + s.ext],
                    },
                    terms: vec![Fp2::ZERO; s.a_sites + s.h_sites + s.endpoint_sites],
                })
                .collect(),
            mask_open: MaskOpening {
                q: vec![Fp2::ZERO; MASK_VEC],
                prox: vec![Fp2::ZERO; MASK_VEC],
                columns: (0..bd.checks)
                    .map(|j| {
                        (
                            j,
                            vec![Fp::ZERO; s.m_rows],
                            [0; 32],
                            vec![[0; 32]; MASK_PATH],
                        )
                    })
                    .collect(),
            },
            a_open: opening(bd, ag, s.a_rows),
            h_open: opening(bd, hg, s.h_rows),
            in_open: opening(ed, gi, ri),
            out_open: if g.output() {
                Some(opening(ed, 2, s.endpoint.external_rows))
            } else {
                None
            },
        }
    }
    #[test]
    fn split_wire_exact_shapes_roundtrip_and_hostile_headers_words_and_counts_refuse() {
        let p = profile();
        let (binding, start, end) = ([17; 32], [19; 32], [23; 32]);
        for (l, k) in [(1, 0), (3, 0), (3, 1), (3, 2)] {
            let g = Geometry::new(&p, l, k).unwrap();
            let mut f = fixture(&g);
            let mut bytes = encode(&f, &g, &binding, &start, &end).unwrap();
            assert_eq!(bytes.len(), g.encoded_len());
            let (decoded, tag) = decode(&bytes, &g, &binding, &start).unwrap();
            assert_eq!(tag, end);
            assert_eq!(encode(&decoded, &g, &binding, &start, &end).unwrap(), bytes);
            assert!(decode(&bytes, &g, &[37; 32], &start).is_err());
            assert!(decode(&bytes, &g, &binding, &[41; 32]).is_err());
            for offset in [0, 40, 72, 80] {
                let old = bytes[offset];
                bytes[offset] ^= 1;
                assert!(decode(&bytes, &g, &binding, &start).is_err());
                bytes[offset] = old;
            }
            let scalar = R14_HEADER + usize::from(g.boundary()) * 32 + 3 * 32;
            bytes[scalar..scalar + 8].copy_from_slice(&P.to_le_bytes());
            assert!(decode(&bytes, &g, &binding, &start)
                .err()
                .unwrap()
                .contains("noncanonical"));
            bytes[scalar..scalar + 8].fill(0);
            let column = scalar + g.slot_bytes() + 2 * MASK_VEC * 16;
            bytes[column..column + 8].copy_from_slice(&(MASK_DOM as u64).to_le_bytes());
            assert!(decode(&bytes, &g, &binding, &start)
                .err()
                .unwrap()
                .contains("column index"));
            bytes[column..column + 8].fill(0);
            bytes.push(0);
            assert!(decode(&bytes, &g, &binding, &start).is_err());
            bytes.pop();
            f.slots.pop();
            assert!(encode(&f, &g, &binding, &start, &end).is_err());
        }
        assert!(Geometry::new(&p, 0, 0).is_err());
        assert!(Geometry::new(&p, 129, 0).is_err());
        assert!(Geometry::new(&p, 3, 3).is_err());
    }
}
