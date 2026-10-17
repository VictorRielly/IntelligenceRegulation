// Research sketch only: UNCOMPILED, UNAPPLIED, NO DEVICE VALIDATION.
// Not recommended as the default large-row path: see result.json's sector model.
// Existing gl_add/gl_sub/gl_mul and u64 definitions are required.
// Caller validates canonical inputs, powers, n+q<=nn, nonaliasing and lengths.
// coef_row: n NATURAL-ORDER coefficients AFTER normalized inverse NTT.
// pads_row: q existing pads, with unchanged lifetime and randomness draws.
// pows: at least n+q existing powers of the same public coset h.
__device__ __forceinline__ u64 zk_coefficient_at(
    const u64* __restrict__ coef_row,
    const u64* __restrict__ pads_row,
    const u64* __restrict__ pows,
    int i, int n, int q) {
    if (i >= n + q) return 0ULL;
    u64 v = i < n ? coef_row[i] : 0ULL;
    if (i < q) v = gl_sub(v, pads_row[i]);
    // Independent from i<q: the two pad contributions overlap when q>n.
    if (i >= n) {
        u64 shifted = pads_row[i - n];
        v = i < q ? gl_add(v, shifted) : shifted;
    }
    return gl_mul(v, pows[i]);
}

// Proposed additive k_ntt_p1_zk interface:
// (coef, pads, pows, dst, stage_major_forward_tw, log_nn, n, q)
// Inside the EXISTING bit-reversed load loop, after computing row and r:
// sh[local] = zk_coefficient_at(coef + (size_t)row*n,
//                               pads + (size_t)row*q, pows, r, n, q);
// Forward scale stays 1. All p1 butterflies/stores and p2/gather stay identical.
// Host seam: encode_rows_view_zk and encode_rows_view_zk_gather in cuda.rs.
// Keep ntt_rows_view(..., inverse=true), then use the additive producer instead
// of k_zk_pad_scale followed by ordinary k_ntt_p1. Remove coef2 only on that
// explicit path. Existing fallbacks, compact/full overrides and tagged-device
// refusal stay intact. Re-audit scratch lifetimes and pool reuse independently.
