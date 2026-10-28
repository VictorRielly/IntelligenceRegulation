// RESEARCH SKETCH ONLY. Never compiled or applied to production.
// In k_ntt_p1, replace ONLY the first load loop with this loop, under an
// explicit owner A/B switch. Keep the barrier, butterflies and stores literal.
// A scalar indexing/zero-tail model passes; actual SASS/shared wavefronts,
// NTT/PCS/masked transcript/receipt bytes, refusals and elapsed cost are owed.
// The logN guard covers tested small cases; >=14 must remain literal:
// a tile's source-word stride is already >=4, so no sector gain is possible
// for an 8-byte aligned scalar load at this unchanged tile ownership.
for (int j = threadIdx.x; j < bs; j += blockDim.x) {
    const bool rotate = (log_n >= 8 && log_n <= 13);
    const int q = rotate ? (((j & 1) << (lb - 1)) | (j >> 1)) : j;
    const int x = blk * bs + q;
    const int r = (int)(__brev((u32)x) >> (32 - log_n));
    sh[q] = (r < n_src) ? s[r] : 0ULL;
}
