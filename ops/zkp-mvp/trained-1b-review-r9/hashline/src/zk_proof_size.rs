//! Counts the actual fields written by LayerProofZk::to_bytes, without encoding
//! another proof or inspecting field values. This is size accounting, not proof
//! validation, privacy evidence, or a measurement of serialization time.

use super::{LayerProofZk, MaskOpening};
use crate::pcs::{Opening, OpeningZk};
use crate::sumcheck::SumcheckProof;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ColumnBytes {
    pub indices: usize,
    pub values: usize,
    pub salts: usize,
    pub authentication_paths: usize,
}

impl ColumnBytes {
    pub fn total_bytes(&self) -> usize {
        self.indices + self.values + self.salts + self.authentication_paths
    }

    fn json(&self) -> String {
        format!(
            "{{\"indices\":{},\"values\":{},\"salts\":{},\"authentication_paths\":{}}}",
            self.indices, self.values, self.salts, self.authentication_paths
        )
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct OpeningBytes {
    pub group_vectors: usize,
    pub proximity_vector: usize,
    pub columns: ColumnBytes,
}

impl OpeningBytes {
    pub fn total_bytes(&self) -> usize {
        self.group_vectors + self.proximity_vector + self.columns.total_bytes()
    }

    fn plain(op: &Opening) -> Self {
        Self {
            group_vectors: op.group_vecs.iter().map(|v| v.len() * 16).sum(),
            proximity_vector: op.prox_vec.len() * 16,
            columns: ColumnBytes {
                indices: op.columns.len() * 8,
                values: op.columns.iter().map(|(_, c, _)| c.len() * 8).sum(),
                salts: 0,
                authentication_paths: op.columns.iter().map(|(_, _, p)| p.len() * 32).sum(),
            },
        }
    }

    fn hiding(op: &OpeningZk) -> Self {
        Self {
            group_vectors: op.group_vecs.iter().map(|v| v.len() * 16).sum(),
            proximity_vector: op.prox_vec.len() * 16,
            columns: salted_columns(&op.columns),
        }
    }

    fn json(&self) -> String {
        format!(
            "{{\"group_vectors\":{},\"proximity_vector\":{},\"columns\":{}}}",
            self.group_vectors,
            self.proximity_vector,
            self.columns.json()
        )
    }
}

// MaskOpening and OpeningZk use the same serialized column tuple.
fn salted_columns(
    columns: &[(
        usize,
        Vec<crate::field::Fp>,
        [u8; 32],
        Vec<crate::merkle::Digest>,
    )],
) -> ColumnBytes {
    ColumnBytes {
        indices: columns.len() * 8,
        values: columns.iter().map(|(_, c, _, _)| c.len() * 8).sum(),
        salts: columns.len() * 32,
        authentication_paths: columns.iter().map(|(_, _, _, p)| p.len() * 32).sum(),
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct MaskOpeningBytes {
    /// The mask opening's q response; not a PCS group vector.
    pub functional_vector: usize,
    pub proximity_vector: usize,
    pub columns: ColumnBytes,
}

impl MaskOpeningBytes {
    pub fn total_bytes(&self) -> usize {
        self.functional_vector + self.proximity_vector + self.columns.total_bytes()
    }

    fn count(op: &MaskOpening) -> Self {
        Self {
            functional_vector: op.q.len() * 16,
            proximity_vector: op.prox.len() * 16,
            columns: salted_columns(&op.columns),
        }
    }

    fn json(&self) -> String {
        format!(
            "{{\"functional_vector\":{},\"proximity_vector\":{},\"columns\":{}}}",
            self.functional_vector,
            self.proximity_vector,
            self.columns.json()
        )
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ArgumentBytes {
    name: &'static str,
    pub claim_or_challenge: usize,
    pub round_evaluations: usize,
    pub terminals: usize,
}

impl ArgumentBytes {
    pub fn name(&self) -> &'static str {
        self.name
    }

    pub fn total_bytes(&self) -> usize {
        self.claim_or_challenge + self.round_evaluations + self.terminals
    }

    fn count(name: &'static str, sc: &SumcheckProof, terminals: usize) -> Self {
        Self {
            name,
            claim_or_challenge: 16,
            round_evaluations: sc.rounds.iter().map(|r| r.len() * 16).sum(),
            terminals: terminals * 16,
        }
    }

    fn json(&self) -> String {
        // Labels originate only in count() calls below, not witness input.
        format!("{{\"name\":\"{}\",\"claim_or_challenge\":{},\"round_evaluations\":{},\"terminals\":{}}}",
            self.name, self.claim_or_challenge, self.round_evaluations, self.terminals)
    }
}

/// Byte categories, not contiguous wire offsets. Column values, salts and
/// paths are interleaved in the existing format. No category is a residual.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProofSizeBreakdown {
    pub commitment_headers: usize,
    pub mask_root: usize,
    pub arguments: [ArgumentBytes; 6],
    pub mask_opening: MaskOpeningBytes,
    pub w_plain: OpeningBytes,
    pub w_hiding: OpeningBytes,
    pub a: OpeningBytes,
    pub h: OpeningBytes,
    pub predicate: Option<ArgumentBytes>,
}

impl ProofSizeBreakdown {
    pub fn total_bytes(&self) -> usize {
        self.commitment_headers
            + self.mask_root
            + self
                .arguments
                .iter()
                .map(ArgumentBytes::total_bytes)
                .sum::<usize>()
            + self.mask_opening.total_bytes()
            + self.w_plain.total_bytes()
            + self.w_hiding.total_bytes()
            + self.a.total_bytes()
            + self.h.total_bytes()
            + self
                .predicate
                .as_ref()
                .map_or(0, ArgumentBytes::total_bytes)
    }

    /// A diagnostic JSON object with byte units. Does not include a claim of
    /// verification or privacy mode: the caller must supply that context.
    pub fn to_json(&self) -> String {
        let arguments = self
            .arguments
            .iter()
            .map(ArgumentBytes::json)
            .collect::<Vec<_>>()
            .join(",");
        let predicate = self
            .predicate
            .as_ref()
            .map_or_else(|| "null".into(), ArgumentBytes::json);
        format!(
            concat!(
                "{{\"total_bytes\":{},\"commitment_headers\":{},\"mask_root\":{},",
                "\"arguments\":[{}],\"mask_opening\":{},\"w_plain\":{},\"w_hiding\":{},",
                "\"a\":{},\"h\":{},\"predicate\":{}}}"
            ),
            self.total_bytes(),
            self.commitment_headers,
            self.mask_root,
            arguments,
            self.mask_opening.json(),
            self.w_plain.json(),
            self.w_hiding.json(),
            self.a.json(),
            self.h.json(),
            predicate
        )
    }
}

impl LayerProofZk {
    /// Inspect a complete proof's serialized field lengths. This does not
    /// verify the proof. Missing mandatory commitments are refused, matching
    /// to_bytes's requirement; all present fields are counted even if they
    /// form a semantically invalid proof (e.g. both W opening variants).
    pub fn size_breakdown(&self) -> Result<ProofSizeBreakdown, &'static str> {
        if self.w_com.is_none() || self.a_com.is_none() || self.h_com.is_none() {
            return Err("proof-size accounting requires W, A and H commitments");
        }
        Ok(ProofSizeBreakdown {
            commitment_headers: 3 * (32 + 8 + 4),
            mask_root: 32,
            arguments: [
                ArgumentBytes::count("gu", &self.gu_sc, self.gu_term.len()),
                ArgumentBytes::count("d", &self.d_sc, self.d_term.len()),
                ArgumentBytes::count("zc20", &self.zc20_sc, self.zc20_term.len()),
                ArgumentBytes::count("zc17", &self.zc17_sc, self.zc17_term.len()),
                ArgumentBytes::count("zs", &self.zs_sc, 1),
                ArgumentBytes::count("table", &self.tab_sc, self.tab_term.len()),
            ],
            mask_opening: MaskOpeningBytes::count(&self.mask_open),
            w_plain: OpeningBytes::plain(&self.w_open),
            w_hiding: OpeningBytes::hiding(&self.w_open_zk),
            a: OpeningBytes::hiding(&self.a_open),
            h: OpeningBytes::hiding(&self.h_open),
            predicate: self
                .pred
                .as_ref()
                .map(|p| ArgumentBytes::count("predicate", &p.sc, p.term.len())),
        })
    }
}
