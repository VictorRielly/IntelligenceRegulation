//! Counted legacy FFN layout facts for A03 interface review, not a pending
//! prover implementation and not evidence that any mask construction is ZK.
use hashline::layer::LayerParams;
use hashline::zk::{mask_specs_v3, ZkLayoutV3};
use std::collections::BTreeSet;

fn tiny(pred: bool) -> ZkLayoutV3 {
    ZkLayoutV3::new(
        32,
        16,
        16,
        &LayerParams {
            log_cols: 8,
            inv_rate: 8,
            num_col_checks: 256,
        },
        (7, 0, 14, 6),
        pred,
    )
}

#[test]
fn legacy_tiny_counts_pin_the_real_retained_commitment_budget() {
    let z = tiny(false);
    assert_eq!((z.a_n, z.w_n, z.lay.nb_d, z.lay.nb_f), (256, 256, 1, 1));
    assert_eq!(
        (z.lay.a_len / 256, z.lay.h_len / 256, z.lay.w_len / 256),
        (20, 16, 3)
    );
    assert_eq!(
        z.tabs.iter().map(|t| t.rows).collect::<Vec<_>>(),
        [1, 256, 1, 1, 64, 1]
    );
    assert_eq!((z.a_len / 256, z.h_len / 256), (681, 1325));
    // Data + full coset encoding alone, excluding padding/salts, Merkle trees,
    // proof vectors, temporary buffers, allocator/pool retention and attention.
    let data_plus_code_bytes = (z.a_len + z.h_len) * 8 * (1 + 8);
    assert_eq!(data_plus_code_bytes, 36_974_592);
    // n=256,Q=256,N=2048: the hiding dimension is n+Q=512, NOT n.
    assert_eq!((256 + 256) * 4, 256 * 8);
}

#[test]
fn actual_boundary_slices_are_not_terminal_mask_rows() {
    for (t, d, f, log_cols) in [(32, 16, 16, 8), (32, 768, 2048, 14), (32, 4096, 14336, 14)] {
        // Metadata-sized allocations only: no model tensor, proof or NTT table.
        let z = ZkLayoutV3::new(
            t,
            d,
            f,
            &LayerParams {
                log_cols,
                inv_rate: 8,
                num_col_checks: 256,
            },
            (7, 0, 14, 6),
            false,
        );
        let l = &z.lay;
        assert_eq!(l.x.len(), l.nb_d);
        assert_eq!(l.z.len(), l.nb_d);
        assert_eq!(z.a_md.len(), 3 * l.nb_d);
        assert_eq!(l.tdb, t * (1usize << l.log_db));
        let mut slices = Vec::new();
        for c in 0..l.nb_d {
            for off in [l.x[c], l.z[c]] {
                assert_eq!(off % z.a_n, 0);
                assert!(off + l.tdb <= l.a_len);
                slices.push((off, off + l.tdb));
            }
            assert!(z.a_md[3 * c] * z.a_n >= l.a_len);
            assert!(z.a_md[3 * c + 1] * z.a_n >= l.a_len);
            assert_ne!(z.a_md[3 * c], z.a_md[3 * c + 1]);
        }
        slices.sort_unstable();
        assert!(slices.windows(2).all(|s| s[0].1 <= s[1].0));
        assert_eq!(l.log_t + l.log_db, l.tdb.trailing_zeros());
        assert!(l.log_t + l.log_db >= z.log_n as u32);
    }
    // At the approved tiny shape, data has a 9-variable point but a terminal
    // mask row only has 8. The row-variable/tail mapping must be preserved.
    let z = tiny(false);
    assert_eq!((z.lay.log_t + z.lay.log_db, z.log_n), (9, 8));
}

#[test]
fn legacy_reservations_have_no_free_terminal_or_histogram_rows() {
    let z = tiny(false);
    let mut used = BTreeSet::new();
    for r in 0..z.lay.a_len / z.a_n {
        assert!(used.insert(r));
    }
    for r in z.a_mf.iter().chain(&z.a_md).chain(&z.a_mgu).chain(&z.a_mdd) {
        assert!(used.insert(*r));
    }
    assert!(used.insert(z.a_prox));
    for t in &z.tabs {
        for start in [t.a_row, t.a_mask] {
            for r in start..start + t.rows {
                assert!(used.insert(r));
            }
        }
    }
    assert_eq!(used.len(), z.a_len / z.a_n);
    assert_eq!(*used.last().unwrap() + 1, used.len());
    // A proposal adding independent X/Z boundary sites must use a NEW layout
    // and commitment root. Existing rows cannot silently become fresh masks.
    let proposed_extra_pair_rows = 2 * 2 * z.lay.nb_d;
    assert_eq!(proposed_extra_pair_rows, 4);
    // This does NOT count a complete repair of existing masks/proximity rows.
}

#[test]
fn legacy_cfs_manifest_distinguishes_modes_and_has_no_seam_polynomials() {
    let z = tiny(false);
    assert_eq!(
        mask_specs_v3(&z, false),
        [(5, 2), (5, 2), (10, 4), (10, 4), (9, 2), (17, 3)]
    );
    assert_eq!(
        mask_specs_v3(&z, true),
        [(6, 2), (6, 2), (10, 4), (10, 4), (9, 2), (17, 3)]
    );
    let p = tiny(true);
    let mut with_pred = mask_specs_v3(&z, false);
    with_pred.push((10, 3));
    assert_eq!(mask_specs_v3(&p, false), with_pred);
    assert_eq!(p.a_len - z.a_len, 3 * z.a_n);
    assert_eq!(p.h_len, z.h_len);
    assert_eq!((p.a_pb, p.a_pmb, p.a_pmz), (681, 682, 683));
}
