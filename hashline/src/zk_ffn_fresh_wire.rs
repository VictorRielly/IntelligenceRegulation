//! Fixed-shape transport for the experimental fresh FFN, not the registered
//! block format. Counts come ONLY from the checked, caller-supplied statement.
//! The envelope is a routing check; acceptance always requires `verify_bytes`.
use super::*;
use crate::field::P;

const MAGIC: &[u8; 8] = b"HFFNMR1\x01";
const HEADER: usize = 8 + 1 + 32;
const CHECKS: usize = 256;
const TERMINALS: [usize; 6] = [3, 2, 10, 4, 1, 12];
pub const MAX_WIRE_BYTES: usize = 32 * 1024 * 1024;
pub const MAX_CONTEXT_BYTES: usize = 4096;

struct Shape {
    private: bool,
    rows: [usize; 3], // W, A, H
    specs: Vec<(usize, usize)>,
}

impl Shape {
    fn new(st: &StatementV3, weights: WeightStatement) -> Result<Self, String> {
        preflight(st)?;
        if st.table_digest.len() > 256 {
            return Err("fresh FFN wire: table digest label too long".into());
        }
        let private = matches!(weights, WeightStatement::FreshPrivate);
        let zl = ZkLayoutV3::with_masks(32, 16, 16, &parameters(), st.shifts, false, true);
        Ok(Self {
            private,
            rows: [
                if private { zl.w_len_p3 } else { zl.lay.w_len } / zl.w_n,
                zl.a_len / zl.a_n,
                zl.h_len / zl.a_n,
            ],
            specs: mask_specs_v3(&zl, private),
        })
    }

    fn len(&self) -> Result<usize, String> {
        // Fixed T32/d16/f16 and checked shifts -8..=16 bound every term.
        // Even four maximum-size remainder tables fit the global frame cap.
        let opening = |groups: usize, rows: usize, hiding: bool| {
            (groups + 1) * if hiding { 512 } else { 256 } * 16
                + CHECKS * (8 + rows * 8 + if hiding { 32 } else { 0 } + 11 * 32)
        };
        let arguments: usize = self
            .specs
            .iter()
            .zip(TERMINALS)
            .map(|(&(rounds, degree), terms)| (1 + rounds * (degree + 1) + terms) * 16)
            .sum();
        let masks = 2 * 1024 * 16 + CHECKS * (8 + 16 * 8 + 32 + 12 * 32);
        let len = HEADER
            + 3 * 44
            + 32
            + arguments
            + masks
            + opening(2, self.rows[0], self.private)
            + opening(5, self.rows[1], true)
            + opening(5, self.rows[2], true);
        if len > MAX_WIRE_BYTES {
            return Err("fresh FFN wire: frame exceeds bound".into());
        }
        Ok(len)
    }

    fn validate(&self, p: &LayerProofZk) -> Result<(), String> {
        for (cm, rows) in [&p.w_com, &p.a_com, &p.h_com].into_iter().zip(self.rows) {
            let cm = cm.as_ref().ok_or("fresh FFN wire: missing commitment")?;
            if cm.rows != rows || cm.log_cols != 8 {
                return Err("fresh FFN wire: commitment shape".into());
            }
        }
        for ((sc, terms), (&(rounds, degree), count)) in [
            (&p.gu_sc, p.gu_term.len()),
            (&p.d_sc, p.d_term.len()),
            (&p.zc20_sc, p.zc20_term.len()),
            (&p.zc17_sc, p.zc17_term.len()),
            (&p.zs_sc, 1),
            (&p.tab_sc, p.tab_term.len()),
        ]
        .into_iter()
        .zip(self.specs.iter().zip(TERMINALS))
        {
            if terms != count
                || sc.rounds.len() != rounds
                || sc.rounds.iter().any(|r| r.len() != degree + 1)
            {
                return Err("fresh FFN wire: argument shape".into());
            }
        }
        let groups = |g: &[Vec<Fp2>], prox: &[Fp2], count, width| {
            g.len() == count && g.iter().all(|v| v.len() == width) && prox.len() == width
        };
        let hiding = |o: &OpeningZk, count, rows| {
            groups(&o.group_vecs, &o.prox_vec, count, 512)
                && o.columns.len() == CHECKS
                && o.columns
                    .iter()
                    .all(|(j, c, _, p)| *j < 2048 && c.len() == rows && p.len() == 11)
        };
        let plain_empty = p.w_open.group_vecs.is_empty()
            && p.w_open.prox_vec.is_empty()
            && p.w_open.columns.is_empty();
        let hiding_empty = p.w_open_zk.group_vecs.is_empty()
            && p.w_open_zk.prox_vec.is_empty()
            && p.w_open_zk.columns.is_empty();
        let w_ok = if self.private {
            plain_empty && hiding(&p.w_open_zk, 2, self.rows[0])
        } else {
            hiding_empty
                && groups(&p.w_open.group_vecs, &p.w_open.prox_vec, 2, 256)
                && p.w_open.columns.len() == CHECKS
                && p.w_open
                    .columns
                    .iter()
                    .all(|(j, c, p)| *j < 2048 && c.len() == self.rows[0] && p.len() == 11)
        };
        if p.pred.is_some()
            || !w_ok
            || !hiding(&p.a_open, 5, self.rows[1])
            || !hiding(&p.h_open, 5, self.rows[2])
            || p.mask_open.q.len() != 1024
            || p.mask_open.prox.len() != 1024
            || p.mask_open.columns.len() != CHECKS
            || p.mask_open
                .columns
                .iter()
                .any(|(j, c, _, p)| *j >= 4096 || c.len() != 16 || p.len() != 12)
        {
            return Err("fresh FFN wire: opening shape".into());
        }
        Ok(())
    }
}

fn mode(weights: WeightStatement) -> u8 {
    match weights {
        WeightStatement::Public(_) => 1,
        WeightStatement::FreshPrivate => 3,
    }
}

fn binding(st: &StatementV3, weights: WeightStatement, context: &[u8]) -> Result<Digest, String> {
    if context.len() > MAX_CONTEXT_BYTES {
        return Err("fresh FFN wire: request context too long".into());
    }
    let mut tr = Transcript::new(b"fresh-ffn-wire/1");
    tr.absorb(b"profile", PROFILE);
    absorb_statement_v3(&mut tr, st);
    let table: Vec<_> = st.table.iter().flat_map(|x| x.to_le_bytes()).collect();
    tr.absorb(b"table-values", &table);
    tr.absorb(b"request-context", context);
    tr.absorb(b"weight-policy", &[mode(weights)]);
    if let WeightStatement::Public(root) = weights {
        tr.absorb(b"expected-public-W", &root);
    }
    Ok(tr.state())
}

/// Exact frame length for a checked caller-selected statement and weight mode.
pub fn encoded_len(st: &StatementV3, weights: WeightStatement) -> Result<usize, String> {
    Shape::new(st, weights)?.len()
}

impl Proof {
    /// Encode a canonical frame. This checks representation, not proof validity.
    /// The recipient must independently supply these same expectations and verify.
    pub fn to_bytes(
        &self,
        st: &StatementV3,
        weights: WeightStatement,
        context: &[u8],
    ) -> Result<Vec<u8>, String> {
        let shape = Shape::new(st, weights)?;
        let expected = binding(st, weights, context)?;
        shape.validate(&self.inner)?;
        let mut bytes = Vec::with_capacity(shape.len()?);
        bytes.extend_from_slice(MAGIC);
        bytes.push(mode(weights));
        bytes.extend_from_slice(&expected);
        bytes.extend_from_slice(&self.inner.to_bytes());
        // The decoder checks every field word for canonicality. Its fixed shapes
        // also provide a second check on the legacy flat payload's byte count.
        Self::from_bytes(st, weights, &bytes, context)?;
        Ok(bytes)
    }

    /// Decode only; successful parsing does NOT mean cryptographic acceptance.
    /// No value or count in the file controls allocation or loop bounds.
    pub fn from_bytes(
        st: &StatementV3,
        weights: WeightStatement,
        bytes: &[u8],
        context: &[u8],
    ) -> Result<Self, String> {
        let shape = Shape::new(st, weights)?;
        if bytes.len() != shape.len()? {
            return Err("fresh FFN wire: wrong frame length".into());
        }
        let mut r = Reader { bytes, pos: 0 };
        if r.take::<8>()? != *MAGIC || r.take::<1>()?[0] != mode(weights) {
            return Err("fresh FFN wire: wrong profile or weight mode".into());
        }
        if r.take::<32>()? != binding(st, weights, context)? {
            return Err("fresh FFN wire: expected statement/context mismatch".into());
        }
        let mut p = LayerProofZk {
            w_com: Some(r.commitment(shape.rows[0])?),
            a_com: Some(r.commitment(shape.rows[1])?),
            mask_root: r.take()?,
            h_com: Some(r.commitment(shape.rows[2])?),
            ..Default::default()
        };
        (p.gu_claim, p.gu_sc, p.gu_term) = r.argument(shape.specs[0], 3)?;
        (p.d_claim, p.d_sc, p.d_term) = r.argument(shape.specs[1], 2)?;
        (p.gamma20, p.zc20_sc, p.zc20_term) = r.argument(shape.specs[2], 10)?;
        (p.gamma17, p.zc17_sc, p.zc17_term) = r.argument(shape.specs[3], 4)?;
        let (gamma, sc, terms) = r.argument(shape.specs[4], 1)?;
        p.gamma_zs = gamma;
        p.zs_sc = sc;
        p.zs_term = terms[0];
        (p.gamma_tab, p.tab_sc, p.tab_term) = r.argument(shape.specs[5], 12)?;
        p.mask_open = MaskOpening {
            q: r.fp2_vec(1024)?,
            prox: r.fp2_vec(1024)?,
            columns: r.columns(16, 12)?,
        };
        if shape.private {
            p.w_open_zk = r.hiding(2, shape.rows[0])?;
        } else {
            p.w_open = r.plain(shape.rows[0])?;
        }
        p.a_open = r.hiding(5, shape.rows[1])?;
        p.h_open = r.hiding(5, shape.rows[2])?;
        if r.pos != bytes.len() {
            return Err("fresh FFN wire: trailing bytes".into());
        }
        Ok(Self { inner: p })
    }
}

/// Cryptographic acceptance from bounded bytes; no witness or producer state.
pub fn verify_bytes(
    st: &StatementV3,
    weights: WeightStatement,
    bytes: &[u8],
    context: &[u8],
) -> Result<(), String> {
    let proof = Proof::from_bytes(st, weights, bytes, context)?;
    verify(st, weights, &proof, context)
}

struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
}
impl Reader<'_> {
    fn take<const N: usize>(&mut self) -> Result<[u8; N], String> {
        let end = self
            .pos
            .checked_add(N)
            .ok_or("fresh FFN wire: cursor overflow")?;
        let slice = self
            .bytes
            .get(self.pos..end)
            .ok_or("fresh FFN wire: truncated frame")?;
        self.pos = end;
        Ok(slice
            .try_into()
            .map_err(|_| "fresh FFN wire: internal width")?)
    }
    fn u64(&mut self) -> Result<u64, String> {
        Ok(u64::from_le_bytes(self.take()?))
    }
    fn fp(&mut self) -> Result<Fp, String> {
        let x = self.u64()?;
        if x >= P {
            return Err("fresh FFN wire: noncanonical field word".into());
        }
        Ok(Fp(x))
    }
    fn fp2(&mut self) -> Result<Fp2, String> {
        Ok(Fp2::new(self.fp()?, self.fp()?))
    }
    fn fp2_vec(&mut self, n: usize) -> Result<Vec<Fp2>, String> {
        (0..n).map(|_| self.fp2()).collect()
    }
    fn commitment(&mut self, expected_rows: usize) -> Result<Commitment, String> {
        let root = self.take()?;
        let rows = self.u64()?;
        let log_cols = u32::from_le_bytes(self.take()?);
        if rows != expected_rows as u64 || log_cols != 8 {
            return Err("fresh FFN wire: commitment shape".into());
        }
        Ok(Commitment {
            root,
            rows: expected_rows,
            log_cols,
        })
    }
    fn argument(
        &mut self,
        (rounds, degree): (usize, usize),
        terms: usize,
    ) -> Result<(Fp2, SumcheckProof, Vec<Fp2>), String> {
        let claim = self.fp2()?;
        let rounds = (0..rounds)
            .map(|_| self.fp2_vec(degree + 1))
            .collect::<Result<_, _>>()?;
        Ok((claim, SumcheckProof { rounds }, self.fp2_vec(terms)?))
    }
    fn column(&mut self, rows: usize, depth: usize) -> Result<(usize, Vec<Fp>), String> {
        let j = self.u64()?;
        if j >= (1u64 << depth) {
            return Err("fresh FFN wire: column index out of bounds".into());
        }
        Ok((
            j as usize,
            (0..rows).map(|_| self.fp()).collect::<Result<_, _>>()?,
        ))
    }
    fn path(&mut self, depth: usize) -> Result<Vec<Digest>, String> {
        (0..depth).map(|_| self.take()).collect()
    }
    fn columns(
        &mut self,
        rows: usize,
        depth: usize,
    ) -> Result<Vec<(usize, Vec<Fp>, [u8; 32], Vec<Digest>)>, String> {
        (0..CHECKS)
            .map(|_| {
                let (j, col) = self.column(rows, depth)?;
                Ok((j, col, self.take()?, self.path(depth)?))
            })
            .collect()
    }
    fn hiding(&mut self, groups: usize, rows: usize) -> Result<OpeningZk, String> {
        Ok(OpeningZk {
            group_vecs: (0..groups)
                .map(|_| self.fp2_vec(512))
                .collect::<Result<_, _>>()?,
            prox_vec: self.fp2_vec(512)?,
            columns: self.columns(rows, 11)?,
        })
    }
    fn plain(&mut self, rows: usize) -> Result<Opening, String> {
        Ok(Opening {
            group_vecs: (0..2)
                .map(|_| self.fp2_vec(256))
                .collect::<Result<_, _>>()?,
            prox_vec: self.fp2_vec(256)?,
            columns: (0..CHECKS)
                .map(|_| {
                    let (j, col) = self.column(rows, 11)?;
                    Ok((j, col, self.path(11)?))
                })
                .collect::<Result<_, String>>()?,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixed_wire_bounds_cover_all_allowed_table_sizes() {
        let mut st = StatementV3 {
            l: 0,
            t_rows: 32,
            d: 16,
            f: 16,
            shifts: (16, 16, 16, 16),
            act: crate::tables_v3::Act16Fn::Silu,
            table: [0; 256],
            table_digest: String::new(),
        };
        for weights in [
            WeightStatement::Public([0; 32]),
            WeightStatement::FreshPrivate,
        ] {
            let shape = Shape::new(&st, weights).unwrap();
            let max = shape.len().unwrap();
            assert!(max < MAX_WIRE_BYTES);
            // Exercise the decoder at the largest allocation boundary with a
            // canonical but invalid all-zero proof. Only bounded public counts
            // are synthesized here; no expensive witness/proving work is needed.
            let mut bytes = vec![0; max];
            bytes[..8].copy_from_slice(MAGIC);
            bytes[8] = mode(weights);
            bytes[9..41].copy_from_slice(&binding(&st, weights, b"").unwrap());
            for (offset, rows) in [41, 85, 161].into_iter().zip(shape.rows) {
                bytes[offset + 32..offset + 40].copy_from_slice(&(rows as u64).to_le_bytes());
                bytes[offset + 40..offset + 44].copy_from_slice(&8u32.to_le_bytes());
            }
            let p = Proof::from_bytes(&st, weights, &bytes, b"").unwrap();
            assert_eq!(p.to_bytes(&st, weights, b"").unwrap(), bytes);
            assert!(verify_bytes(&st, weights, &bytes, b"").is_err());
            for shift in -8..=16 {
                // Each table's size is monotone in its shift; the all-maximum
                // case above bounds every mixed combination as well.
                st.shifts = (shift, shift, shift, shift);
                assert!(encoded_len(&st, weights).unwrap() <= max);
            }
            st.shifts = (16, 16, 16, 16);
            assert!(
                Proof::from_bytes(&st, weights, &bytes, &vec![0; MAX_CONTEXT_BYTES + 1]).is_err()
            );
            for shifts in [(-9, 0, 0, 0), (0, 17, 0, 0), (0, 0, i32::MAX, 0)] {
                st.shifts = shifts;
                assert!(encoded_len(&st, weights).is_err());
            }
            st.shifts = (16, 16, 16, 16);
            st.f = usize::MAX;
            assert!(encoded_len(&st, weights).is_err());
            st.f = 16;
            st.table_digest = "x".repeat(257);
            assert!(encoded_len(&st, weights).is_err());
            st.table_digest.clear();
        }
    }
}
