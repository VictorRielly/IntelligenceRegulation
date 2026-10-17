// UNCOMPILED, UNAPPLIED INTERFACE SKETCH. Owner integrates and tests natively.
// Rust/CUDA protocol, transcript, RNG and denominator implementations stay owned
// by the main lane. This file illustrates reads only, not a full prover patch.

pub enum PlaneWords<'a> {
    I8(&'a [i8]), U8(&'a [u8]),
    I16(&'a [i16]), U16(&'a [u16]),
    I32(&'a [i32]), U32(&'a [u32]),
    I64(&'a [i64]), // Exact fallback for any representable invalid witness too.
}

impl PlaneWords<'_> {
    pub fn len(&self) -> usize {
        match self {
            Self::I8(x) => x.len(), Self::U8(x) => x.len(),
            Self::I16(x) => x.len(), Self::U16(x) => x.len(),
            Self::I32(x) => x.len(), Self::U32(x) => x.len(),
            Self::I64(x) => x.len(),
        }
    }
    pub fn read(&self, i: usize) -> i64 {
        match self {
            Self::I8(x) => i64::from(x[i]), Self::U8(x) => i64::from(x[i]),
            Self::I16(x) => i64::from(x[i]), Self::U16(x) => i64::from(x[i]),
            Self::I32(x) => i64::from(x[i]), Self::U32(x) => i64::from(x[i]),
            Self::I64(x) => x[i],
        }
    }
}

// An adapter for Layout::lookups(dom)'s existing Lk terms. Resolve plane
// variants once per term, outside the inner loop, in an optimized version.
pub fn read_lookup(words: &[PlaneWords<'_>], constant: i64,
                   terms: &[(usize, i64)], i: usize) -> i64 {
    terms.iter().fold(constant, |acc, &(plane, coefficient)| {
        acc.wrapping_add(coefficient.wrapping_mul(words[plane].read(i)))
    })
}

pub fn read_delta(words: &[PlaneWords<'_>], mx: usize, s8: usize,
                  t_pad: usize, mask_score: i64, i: usize) -> i64 {
    let (ht, j) = (i / t_pad, i % t_pad);
    let score = if j <= ht % t_pad { words[s8].read(i) } else { mask_score };
    words[mx].read(ht).wrapping_sub(score)
}

// In prove_core, replace a_data plane reads with Fp::from_i64(read(i)).
// Keep all lengths, multiplicity exclusions and offsets as derived by Layout.
// For lazy lookups, run indexed reads first for histogram counting, then again
// in the SAME helper-pair order, calling the existing helper_one. Keep each
// helper Vec/Fp2 -> write_h transaction until separately reviewed direct-write
// rules pass. Preserve exp/act full-table inversions, including unused entries.
// The witness stays alive through BOTH helper passes (existing S2 drop seam).
// Packing and metadata are private RAM only. Narrowing must never truncate,
// reject an existing i64 input, or publish admission/hit/variant information.
