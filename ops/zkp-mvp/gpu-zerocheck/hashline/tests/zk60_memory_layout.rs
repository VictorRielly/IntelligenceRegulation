//! Keep the pure Python planner's P3 weight examples tied to the real layout.
use hashline::layer::LayerParams;
use hashline::zk::ZkLayoutV3;

#[test]
fn p3_weight_planner_examples_match_rust_layout_without_large_tensors() {
    let params = LayerParams { log_cols: 14, inv_rate: 4, num_col_checks: 256 };
    for (t, d, f, log_n, data_rows, mask_rows) in [
        (2, 16, 16, 8, 3, 3),
        (512, 768, 2048, 14, 288, 9),
        (512, 4096, 14336, 14, 10752, 21),
    ] {
        let layout = ZkLayoutV3::new(t, d, f, &params, (7, 0, 14, 6), false);
        assert_eq!(layout.log_wn, log_n);
        assert_eq!(layout.lay.w_len / layout.w_n, data_rows);
        assert_eq!(layout.w_mgu.len() + layout.w_mdd.len(), mask_rows);
        assert_eq!(layout.w_len_p3 / layout.w_n, data_rows + mask_rows + 1);
    }
}
