// REVIEW SKETCH ONLY. Not compiled or integrated. Python coverage oracle tests
// this public layout algorithm; native Fp/ZkRng/proof-byte gates remain owed.
// Insert in private_block/protocol.rs near prove_core, after the existing
// witness-shape check. The three histograms must already have been computed
// by the existing, unchanged lookup/exp/act code (including bucket-0 fallback).
// No uninitialized length, raw pointer, reused mask, or hidden-value schedule.
// Native port must split the data prefix from mask append so the existing
// cfg(test) moved-multiplicity hook still runs BEFORE the first A mask draw.
fn assemble_a_rows_review(
    lay: &Layout,
    wit: &Witness,
    histograms: [&[u64]; 3],
    rng: &mut ZkRng,
) -> Vec<Fp> {
    let (ids, n) = (lay.ids(), lay.n());
    let total = lay.a_rows * n;
    let mut out = Vec::with_capacity(total);
    let mut histogram_index = 0;
    for p in lay.a_planes() {
        // Layout::for_shape already derives contiguous, row-aligned offsets.
        assert_eq!(out.len(), lay.a_off[p]);
        if ids.is_multiplicity(p) {
            assert_eq!(histograms[histogram_index].len(), U8_LEN);
            out.extend(histograms[histogram_index].iter().copied().map(Fp::new));
            histogram_index += 1;
        } else {
            // Copy every supplied word, including internal domain padding.
            out.extend(wit.planes[p].iter().copied().map(Fp::from_i64));
        }
        let end = if p + 1 < ids.n_a() {
            lay.a_off[p + 1]
        } else {
            lay.a_mask_base * n
        };
        assert!(out.len() <= end);
        // Only row tails and the table's entries >=256 are zero-filled.
        out.resize(end, Fp::ZERO);
    }
    assert_eq!(histogram_index, 3);
    assert_eq!(out.len(), lay.a_mask_base * n);
    // Same row-major draw order and count as the existing A mask/proximity loop.
    while out.len() < total {
        out.push(rng.fp());
    }
    assert_eq!(out.len(), total);
    out
}
