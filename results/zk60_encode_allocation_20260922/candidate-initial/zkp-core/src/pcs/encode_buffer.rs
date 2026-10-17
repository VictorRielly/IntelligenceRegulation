//! R2a: initialize each encoded row once, directly in its final allocation.
//! No `Fp` reference is formed until every element of that row was written.

use super::{Fp, NttTables};
use rayon::prelude::*;
use std::mem::MaybeUninit;

/// Return the same matrix as the zero-filled-buffer + `encode_row_zk` path.
/// The caller has already drawn pads/salts. This function draws no randomness.
pub(super) fn encode_rows(
    ntt: &NttTables, data: &[Fp], n: usize, pads: &[Fp], q: usize, pows: &[Fp],
) -> Vec<Fp> {
    let nn = pows.len();
    assert!(n.is_power_of_two() && nn.is_power_of_two());
    assert!(q > 0, "PCS encode requires nonempty pad rows");
    assert!(n.checked_add(q).is_some_and(|end| end <= nn), "PCS encode pad capacity");
    assert!(nn.trailing_zeros() <= ntt.max_log, "PCS encode NTT capacity");
    assert!(!data.is_empty() && data.len() % n == 0, "PCS encode data rows");
    let rows = data.len() / n;
    assert_eq!(pads.len(), rows.checked_mul(q).expect("PCS pad size overflow"));
    let len = rows.checked_mul(nn).expect("PCS encoded size overflow");
    let mut encoded: Vec<Fp> = Vec::with_capacity(len);
    // The vector still has length zero. A panic in a row worker therefore
    // drops only the allocation, never an unwritten element. Fp is Copy and
    // has no destructor, so partially initialized rows need no drop cleanup.
    encoded.spare_capacity_mut()[..len]
        .par_chunks_mut(nn)
        .enumerate()
        .for_each(|(r, row)| {
            let input = &data[r * n..(r + 1) * n];
            let pad = &pads[r * q..(r + 1) * q];
            let initialized = initialize_row(ntt, input, pad, pows, row);
            ntt.forward(initialized);
        });
    // SAFETY: len <= capacity. nn divides len, so the parallel iterator
    // covers every element in exactly one disjoint row. Each successful
    // worker initialized its entire row before the NTT; for_each has joined
    // all workers. A panic skips this set_len and no Fp destructor is owed.
    unsafe { encoded.set_len(len); }
    encoded
}

fn initialize_row<'a>(
    ntt: &NttTables, data: &[Fp], pads: &[Fp], pows: &[Fp],
    out: &'a mut [MaybeUninit<Fp>],
) -> &'a mut [Fp] {
    let n = data.len();
    let q = pads.len();
    assert_eq!(out.len(), pows.len());
    assert!(n.checked_add(q).is_some_and(|end| end <= out.len()));
    let mut coeffs = data.to_vec();
    ntt.inverse(&mut coeffs);
    let (message, tail) = out.split_at_mut(n);
    let (pad, zeros) = tail.split_at_mut(q);
    // These disjoint slices cover ALL of out, including the padding tail.
    // Preserve the existing encoder's overwrite order even when q > n.
    for (i, v) in message.iter_mut().enumerate() {
        let x = if i < q { coeffs[i].sub(pads[i]) } else { coeffs[i] };
        v.write(x.mul(pows[i]));
    }
    for (i, v) in pad.iter_mut().enumerate() {
        v.write(pads[i].mul(pows[n + i]));
    }
    for v in zeros { v.write(Fp::ZERO); }
    // SAFETY: the three loops above initialized every element. MaybeUninit<T>
    // has the same size/alignment as T. The returned slice borrows exactly
    // this initialized, exclusive row, not any other worker's storage.
    unsafe { std::slice::from_raw_parts_mut(out.as_mut_ptr().cast::<Fp>(), out.len()) }
}

#[cfg(test)]
mod tests;
