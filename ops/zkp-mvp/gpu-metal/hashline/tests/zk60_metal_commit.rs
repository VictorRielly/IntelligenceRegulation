//! [ZK60-METAL M0/M1, 2026-10-31] The Apple GPU commitment against the CPU oracle.
//!
//! Run with `cargo test --release --features gpu-metal --test zk60_metal_commit`.
//!
//! Every case compares the device result with zkp-core's own CPU code, never
//! with another device path:
//!   * M0: Goldilocks add / sub / mul on edge and random values (field.rs);
//!   * M1 plain: the column leaves, the Merkle root, gathered columns and
//!     row folds of `pcs::commit`;
//!   * M1 hiding: the salted root of `commit_zk_owned_with` and the complete
//!     `open_zk` bytes under the same RNG seed and transcript, unkeyed and under
//!     a tagged profile's column key (`commit_zk_owned_with_tag`).
//! Shapes cover one-chunk and many-chunk BLAKE3 columns (rows * 8 bytes up to
//! 17 chunks, so the chaining-value stack merges at several depths), several
//! rates, and a q > n pad case.
//!
//! Without the feature this file compiles one test that FAILS under
//! `HL_GPU_REQUIRED=1`, so a CPU-only build cannot pass a device gate vacuously.

#[test]
fn metal_required_gate_refuses_a_build_without_the_feature() {
    let required = std::env::var("HL_GPU_REQUIRED").map(|v| v == "1").unwrap_or(false);
    if !cfg!(feature = "gpu-metal") {
        println!("ZK60_METAL_SUMMARY {{\"executed_cases\":0,\"device\":\"built without --features gpu-metal\"}}");
        assert!(!required, "HL_GPU_REQUIRED=1 but this binary was built WITHOUT --features gpu-metal");
    }
}

#[cfg(feature = "gpu-metal")]
mod device {
    use hashline::field::{Fp, Fp2};
    use hashline::ntt::NttTables;
    use zkp_core::hashtag::HashTag;
    use zkp_core::merkle::MerkleTree;
    use zkp_core::pcs::{self, Cpu, PcsParams, Slice, Store, ZClaim, ZPart, ZkOpts};
    use zkp_core::rng::ZkRng;
    use zkp_core::transcript::Transcript;

    const P: u64 = 0xFFFF_FFFF_0000_0001;

    /// Serializes every Metal device test in this file so process-wide test
    /// overrides (`set_fused_rs_for_test`) and exact `FUSED_RS_CALLS` deltas
    /// cannot race across parallel test threads.
    static METAL_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    struct FusedRsGuard(Option<bool>);
    impl Drop for FusedRsGuard {
        fn drop(&mut self) {
            hashline::gpu::set_fused_rs_for_test(self.0);
        }
    }

    fn lock_device() -> std::sync::MutexGuard<'static, ()> {
        METAL_TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn rnd(seed: u64, len: usize) -> Vec<Fp> {
        let mut s = seed ^ 0x9E37_79B9_7F4A_7C15;
        (0..len)
            .map(|_| {
                s = s.wrapping_add(0x9E37_79B9_7F4A_7C15);
                let mut z = s;
                z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
                z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
                Fp::new((z ^ (z >> 31)) % P)
            })
            .collect()
    }

    fn rnd2(seed: u64, len: usize) -> Vec<Fp2> {
        let a = rnd(seed, len);
        let b = rnd(seed ^ 0x55, len);
        a.into_iter().zip(b).map(|(x, y)| Fp2::new(x, y)).collect()
    }

    fn require_device() {
        // the backend entry points read HL_GPU; the direct calls below do not
        std::env::set_var("HL_GPU", "1");
        if let Err(e) = hashline::gpu::metal_probe_field(&[Fp::ONE], &[Fp::ONE]) {
            panic!("no usable Metal device: {e}");
        }
    }

    #[test]
    fn m0_field_ops_match_the_cpu_on_edges_and_random_values() {
        let _lock = lock_device();
        require_device();
        let edges = [0u64, 1, 2, P - 1, P - 2, 1 << 32, (1 << 32) - 1, (1 << 32) + 1, 1 << 63, (1 << 63) + 5, 0xFFFF_FFFF, P >> 1];
        let mut a = Vec::new();
        let mut b = Vec::new();
        for &x in &edges {
            for &y in &edges {
                a.push(Fp::new(x));
                b.push(Fp::new(y));
            }
        }
        a.extend(rnd(1, 100_000));
        b.extend(rnd(2, 100_000));
        let got = hashline::gpu::metal_probe_field(&a, &b).expect("probe");
        for (i, ((x, y), (s, d, m))) in a.iter().zip(&b).zip(&got).enumerate() {
            assert_eq!(*s, x.add(*y), "add #{i}: {x:?} {y:?}");
            assert_eq!(*d, x.sub(*y), "sub #{i}: {x:?} {y:?}");
            assert_eq!(*m, x.mul(*y), "mul #{i}: {x:?} {y:?}");
        }
        println!("ZK60_METAL_SUMMARY {{\"case\":\"m0-field\",\"pairs\":{}}}", a.len());
    }

    /// (log_cols, inv_rate, rows): rows * 8 bytes per column = 1 .. 17 BLAKE3 chunks.
    const SHAPES: [(u32, usize, usize); 9] =
        [(3, 4, 1), (4, 4, 5), (6, 4, 8), (8, 2, 127), (8, 4, 128), (8, 4, 129), (10, 4, 300), (12, 4, 1100), (6, 8, 2049)];

    fn params(log_cols: u32, inv_rate: usize) -> PcsParams {
        PcsParams { log_cols, inv_rate, num_col_checks: 8 }
    }

    #[test]
    fn m1_plain_commit_leaves_root_columns_and_folds_match_the_cpu() {
        let _lock = lock_device();
        require_device();
        let ntt = NttTables::new(16);
        let sf_on = hashline::gpu::metal_sparse_fold_for_test();
        let dev_fold_on = std::env::var("HL_METAL_DEVICE_FOLD").map(|v| v == "1").unwrap_or(false);
        let sf_before = hashline::gpu::metal_sparse_fold_calls_for_test();
        let fb_before = hashline::gpu::metal_sparse_fold_fallbacks_for_test();
        for (si, &(log_cols, ir, rows)) in SHAPES.iter().enumerate() {
            let p = params(log_cols, ir);
            let (n, nn) = (p.cols(), p.enc_cols());
            let data = rnd(10 + si as u64, rows * n);
            let cpu = pcs::commit(&p, &data, &ntt);
            let encoded = match &cpu.store {
                Store::Host { encoded } => encoded.clone(),
                Store::Device(never) => match *never {},
            };
            let (mc, leaves) = hashline::gpu::metal_commit(&p, &data, &ntt).expect("metal commit");
            assert_eq!(leaves, pcs::hash_columns(&encoded, rows, nn), "shape {si}: leaves");
            assert_eq!(MerkleTree::build(leaves).root(), cpu.tree.root(), "shape {si}: root");
            let idx: Vec<usize> = [0, 1, nn / 2, nn - 1, 7 % nn, (nn / 3) | 1, 0].iter().map(|&j| j % nn).collect();
            let cols = mc.columns(&idx).expect("columns");
            for (c, &j) in cols.iter().zip(&idx) {
                let want: Vec<Fp> = (0..rows).map(|i| encoded[i * nn + j]).collect();
                assert_eq!(*c, want, "shape {si}: column {j}");
            }
            let rhos = vec![rnd2(100 + si as u64, rows), rnd2(200 + si as u64, rows)];
            let got = mc.fold_rows(&rhos).expect("fold");
            for (g, rho) in rhos.iter().enumerate() {
                for j in 0..n {
                    let mut acc = Fp2::ZERO;
                    for i in 0..rows {
                        acc = acc.add(rho[i].mul_base(encoded[i * nn + j * ir]));
                    }
                    assert_eq!(got[g][j], acc, "shape {si}: fold {g} col {j}");
                }
            }
        }
        let sf_delta = hashline::gpu::metal_sparse_fold_calls_for_test() - sf_before;
        let fb_delta = hashline::gpu::metal_sparse_fold_fallbacks_for_test() - fb_before;
        assert_eq!(fb_delta, 0, "m1-plain: unexpected sparse fold fallback");
        if sf_on && !dev_fold_on {
            assert_eq!(sf_delta, SHAPES.len() as u64, "m1-plain: expected exact {} sparse fold dispatches", SHAPES.len());
        } else {
            assert_eq!(sf_delta, 0, "m1-plain: sparse fold dispatched when off");
        }
        println!("ZK60_METAL_SUMMARY {{\"case\":\"m1-plain\",\"shapes\":{},\"sparse_folds\":{sf_delta}}}", SHAPES.len());
    }

    /// claims touching data rows and a mask row through one shared column key,
    /// as `assert_mask_sites` requires; the last three rows are masks.
    fn claims(rows: usize, log_cols: u32, seed: u64) -> Vec<ZClaim> {
        let n = 1usize << log_cols;
        let r = rnd2(seed, log_cols as usize);
        let e = Fp2::new(Fp::new(99991), Fp::new(7));
        vec![
            ZClaim {
                parts: vec![
                    ZPart { slice: Slice { offset: 0, log_size: log_cols }, coef: Fp2::ONE.sub(e), point: r.clone() },
                    ZPart { slice: Slice { offset: (rows - 3) * n, log_size: log_cols }, coef: e, point: r.clone() },
                ],
                value: Fp2::ZERO,
            },
            ZClaim {
                parts: vec![ZPart { slice: Slice { offset: (rows - 2) * n, log_size: log_cols }, coef: Fp2::ONE, point: vec![] }],
                value: Fp2::ZERO,
            },
        ]
    }

    fn zk_pair(tag: Option<&HashTag>) {
        let _lock = lock_device();
        require_device();
        let ntt = NttTables::new(16);
        let backend = hashline::gpu::backend();
        let sf_on = hashline::gpu::metal_sparse_fold_for_test();
        let dev_fold_on = std::env::var("HL_METAL_DEVICE_FOLD").map(|v| v == "1").unwrap_or(false);
        let sf_before = hashline::gpu::metal_sparse_fold_calls_for_test();
        let fb_before = hashline::gpu::metal_sparse_fold_fallbacks_for_test();
        let mut cases = 0usize;
        // q_pad = num_col_checks = 8; the (3, 4, 9) shape has n = 8 < q... see below
        for (si, &(log_cols, ir, rows0)) in SHAPES.iter().enumerate() {
            let rows = rows0.max(4);
            let p = params(log_cols, ir);
            let n = p.cols();
            // q > n happens for log_cols = 3 (n = 8) with q_pad 12: the interleaved pad branch
            let q = if log_cols == 3 { 12 } else { 8 };
            if n + q > p.enc_cols() {
                continue;
            }
            let zk = ZkOpts { q_pad: q, coset: Fp::new(7) };
            let data = rnd(500 + si as u64, rows * n);
            let make = |use_dev: bool| {
                let mut rng = ZkRng::new(42 + si as u64, b"metal-zk-test");
                match (tag, use_dev) {
                    (None, false) => pcs::commit_zk_owned_with(&Cpu, &p, data.clone(), &ntt, &zk, &mut rng),
                    (Some(t), false) => pcs::commit_zk_owned_with_tag(&Cpu, &p, data.clone(), &ntt, &zk, &mut rng, t),
                    _ => unreachable!(),
                }
            };
            let mut cpu = make(false);
            let mut rng = ZkRng::new(42 + si as u64, b"metal-zk-test");
            let mut dev = match tag {
                None => pcs::commit_zk_owned_with(&backend, &p, data.clone(), &ntt, &zk, &mut rng),
                Some(t) => pcs::commit_zk_owned_with_tag(&backend, &p, data.clone(), &ntt, &zk, &mut rng, t),
            };
            assert!(matches!(dev.cm.store, Store::Device(_)), "shape {si}: the Metal backend declined");
            assert_eq!(dev.commitment().root, cpu.commitment().root, "shape {si}: salted root");
            for cm in [&mut cpu.mask_rows, &mut dev.mask_rows] {
                *cm = vec![rows - 3, rows - 2];
            }
            cpu.prox_mask_row = Some(rows - 1);
            dev.prox_mask_row = Some(rows - 1);
            let cl = claims(rows, log_cols, 900 + si as u64);
            let mut t1 = Transcript::new(b"metal-open");
            let mut t2 = Transcript::new(b"metal-open");
            let o1 = pcs::open_zk(&cpu, &cl, &mut t1);
            let o2 = pcs::open_zk(&dev, &cl, &mut t2);
            let (mut b1, mut b2) = (Vec::new(), Vec::new());
            o1.write_bytes(&mut b1);
            o2.write_bytes(&mut b2);
            assert_eq!(b1, b2, "shape {si}: opening bytes");
            assert_eq!(t1.challenge_fp2(), t2.challenge_fp2(), "shape {si}: transcript state after the opening");
            cases += 1;
        }
        assert!(cases >= 8, "too few zk shapes ran: {cases}");
        let sf_delta = hashline::gpu::metal_sparse_fold_calls_for_test() - sf_before;
        let fb_delta = hashline::gpu::metal_sparse_fold_fallbacks_for_test() - fb_before;
        assert_eq!(fb_delta, 0, "m1-zk: unexpected sparse fold fallback");
        if sf_on && !dev_fold_on {
            assert_eq!(sf_delta, cases as u64, "m1-zk: expected exact {cases} sparse fold dispatches");
        } else {
            assert_eq!(sf_delta, 0, "m1-zk: sparse fold dispatched when off");
        }
        println!("ZK60_METAL_SUMMARY {{\"case\":\"m1-zk{}\",\"shapes\":{cases},\"sparse_folds\":{sf_delta}}}", if tag.is_some() { "-keyed" } else { "" });
    }

    #[test]
    fn m1_zk_commit_and_opening_bytes_match_the_cpu() {
        zk_pair(None);
    }

    #[test]
    fn m1_keyed_zk_commit_and_opening_bytes_match_the_cpu() {
        zk_pair(Some(&HashTag::for_profile("hashline-zk-mr1/metal-test/1")));
    }

    /// [OPT-NEXT-1] Fused DIF-INTT -> DIT-FWD zero-gather coset RS encoder
    /// (`HL_METAL_FUSED_RS=1`) matches BOTH the reference 4-pass Metal path and
    /// zkp-core's CPU oracle word-for-word (leaves, roots, sampled encoded
    /// columns, row folds, and complete `OpeningZk` bytes) across:
    ///   * `(log_n=14, inv_rate=2, q=280)` (W16R2 A/H),
    ///   * `(log_n=14, inv_rate=4, q=256)` (R13/B),
    ///   * `(log_n=12, inv_rate=4, q=256)` (Stage A/H, multi-chunk BLAKE3),
    ///   * `(log_n=12/13, inv_rate=2/4)` + high-`q` (`n/2 < q <= n`),
    ///   * `(log_n=14, inv_rate=2, q=0)` (and other plain RS geometries),
    ///   * plus clean fallback on `log_n < 12` and `q > n`.
    #[test]
    fn m1_fused_rs_matches_reference_and_cpu_byte_for_byte() {
        let _lock = lock_device();
        require_device();
        let _guard = FusedRsGuard(hashline::gpu::set_fused_rs_for_test(Some(false)));
        assert!(!hashline::gpu::fused_rs_for_test(), "frs0 override did not disable fused RS");
        assert_eq!(hashline::gpu::set_fused_rs_for_test(Some(true)), Some(false));
        assert!(hashline::gpu::fused_rs_for_test(), "frs1 override did not enable fused RS");
        assert_eq!(hashline::gpu::set_fused_rs_for_test(Some(false)), Some(true));

        let ntt16 = NttTables::new(16);
        let ntt18 = NttTables::new(18);
        let backend = hashline::gpu::backend();
        let tag = HashTag::for_profile("hashline-zk-mr1/metal-test/1");
        let raw_key = [0x5Au8; 32];

        // (log_cols, inv_rate, q, rows, use_ntt18, expect_fused)
        let zk_shapes: [(u32, usize, usize, usize, bool, bool); 14] = [
            (14, 2, 280, 6, true, true),     // W16R2 A/H (k_inv_dif_top_3 + k_inv_fwd_fused_r1, max_log > log_nn)
            (14, 4, 256, 5, false, true),    // R13/B (k_inv_dif_top_3 + k_inv_fwd_fused_r2, max_log == log_nn)
            (12, 4, 256, 130, false, true),  // Stage A/H + multi-chunk BLAKE3 (k_inv_dif_top_1 + k_inv_fwd_fused_r2)
            (12, 2, 256, 5, false, true),    // Stage rate-1/2 (k_inv_dif_top_1 + k_inv_fwd_fused_r1)
            (12, 2, 2500, 4, false, true),   // High-q (n/2 < q <= n): exercises both idx0 < q and idx1 < q
            (12, 2, 4096, 4, false, true),   // Exact boundary q == n (rate-1/2)
            (12, 4, 4096, 4, false, true),   // Exact gate boundary q == n (rate-1/4, exercises k_inv_fwd_fused_r2)
            (13, 2, 280, 5, false, true),    // Mid rate-1/2 (k_inv_dif_top_2 + k_inv_fwd_fused_r1)
            (13, 4, 256, 5, true, true),     // Mid rate-1/4 (k_inv_dif_top_2 + k_inv_fwd_fused_r2)
            (10, 4, 8, 5, false, false),     // Fallback: log_n < 12
            (3, 4, 12, 5, false, false),     // Fallback: log_n < 12 and q > n
            (12, 4, 4097, 4, false, false),  // Fallback: log_n == 12 but q > n
            (15, 2, 256, 4, true, false),    // Fallback: log_n > 14
            (12, 8, 256, 4, false, false),   // Fallback: rate_log == 3 (inv_rate == 8)
        ];

        for (si, &(log_cols, ir, q, rows, use18, expect_fused)) in zk_shapes.iter().enumerate() {
            let ntt = if use18 { &ntt18 } else { &ntt16 };
            let p = params(log_cols, ir);
            let (n, nn) = (p.cols(), p.enc_cols());
            let zk = ZkOpts { q_pad: q, coset: Fp::new(7) };
            let data = rnd(7000 + si as u64, rows * n);
            let pads = rnd(8000 + si as u64, rows * q);
            let pows = pcs::coset_powers(zk.coset, nn);
            let idx: Vec<usize> = [0, 1, 2, 3, 2047 % nn, 2048 % nn, nn / 2, nn - 1, (nn / 3) | 1].into_iter().map(|j| j % nn).collect();
            let rhos = vec![rnd2(9100 + si as u64, rows), rnd2(9200 + si as u64, rows)];
            let want_delta = u64::from(expect_fused);

            // 1. Direct metal_commit_zk: frs0 vs frs1 (leaves, raw encoded columns, folds), unkeyed and keyed.
            for key in [None, Some(&raw_key)] {
                hashline::gpu::set_fused_rs_for_test(Some(false));
                let c0_before = hashline::gpu::fused_rs_calls_for_test();
                let (mc0, leaves0) = hashline::gpu::metal_commit_zk(&p, &data, &pads, &pows, ntt, key).expect("metal_commit_zk frs0");
                assert_eq!(hashline::gpu::fused_rs_calls_for_test() - c0_before, 0, "zk shape {si}: frs0 must not dispatch fused RS");
                hashline::gpu::set_fused_rs_for_test(Some(true));
                let c1_before = hashline::gpu::fused_rs_calls_for_test();
                let (mc1, leaves1) = hashline::gpu::metal_commit_zk(&p, &data, &pads, &pows, ntt, key).expect("metal_commit_zk frs1");
                assert_eq!(
                    hashline::gpu::fused_rs_calls_for_test() - c1_before,
                    want_delta,
                    "zk shape {si}: direct metal_commit_zk fused RS delta"
                );
                assert_eq!(leaves1, leaves0, "zk shape {si} (log_n={log_cols}, ir={ir}, q={q}, keyed={}): leaves", key.is_some());
                assert_eq!(mc1.columns(&idx).expect("cols1"), mc0.columns(&idx).expect("cols0"), "zk shape {si}: encoded columns");
                assert_eq!(mc1.fold_rows(&rhos).expect("fold1"), mc0.fold_rows(&rhos).expect("fold0"), "zk shape {si}: folds");
            }

            // 2. Full commit_zk + open_zk: CPU oracle vs Metal frs0 vs Metal frs1, unkeyed and tagged.
            for maybe_tag in [None, Some(&tag)] {
                let mut r_cpu = ZkRng::new(4200 + si as u64, b"metal-frs-test");
                let mut cpu = match maybe_tag {
                    None => pcs::commit_zk_owned_with(&Cpu, &p, data.clone(), ntt, &zk, &mut r_cpu),
                    Some(t) => pcs::commit_zk_owned_with_tag(&Cpu, &p, data.clone(), ntt, &zk, &mut r_cpu, t),
                };
                hashline::gpu::set_fused_rs_for_test(Some(false));
                let c0_open = hashline::gpu::fused_rs_calls_for_test();
                let mut r_dev0 = ZkRng::new(4200 + si as u64, b"metal-frs-test");
                let mut dev0 = match maybe_tag {
                    None => pcs::commit_zk_owned_with(&backend, &p, data.clone(), ntt, &zk, &mut r_dev0),
                    Some(t) => pcs::commit_zk_owned_with_tag(&backend, &p, data.clone(), ntt, &zk, &mut r_dev0, t),
                };
                assert_eq!(hashline::gpu::fused_rs_calls_for_test() - c0_open, 0, "zk shape {si}: commit_zk frs0 must not dispatch fused RS");
                hashline::gpu::set_fused_rs_for_test(Some(true));
                let c1_open = hashline::gpu::fused_rs_calls_for_test();
                let mut r_dev1 = ZkRng::new(4200 + si as u64, b"metal-frs-test");
                let mut dev1 = match maybe_tag {
                    None => pcs::commit_zk_owned_with(&backend, &p, data.clone(), ntt, &zk, &mut r_dev1),
                    Some(t) => pcs::commit_zk_owned_with_tag(&backend, &p, data.clone(), ntt, &zk, &mut r_dev1, t),
                };
                assert_eq!(
                    hashline::gpu::fused_rs_calls_for_test() - c1_open,
                    want_delta,
                    "zk shape {si}: commit_zk frs1 fused RS delta"
                );
                assert!(matches!(dev0.cm.store, Store::Device(_)), "zk shape {si}: frs0 declined");
                assert!(matches!(dev1.cm.store, Store::Device(_)), "zk shape {si}: frs1 declined");
                assert_eq!(dev1.commitment().root, cpu.commitment().root, "zk shape {si}: frs1 vs CPU salted root");
                assert_eq!(dev1.commitment().root, dev0.commitment().root, "zk shape {si}: frs1 vs frs0 salted root");

                for mr in [&mut cpu.mask_rows, &mut dev0.mask_rows, &mut dev1.mask_rows] {
                    *mr = vec![rows - 3, rows - 2];
                }
                cpu.prox_mask_row = Some(rows - 1);
                dev0.prox_mask_row = Some(rows - 1);
                dev1.prox_mask_row = Some(rows - 1);
                let cl = claims(rows, log_cols, 9500 + si as u64);
                let (mut tc, mut t0, mut t1) = (Transcript::new(b"metal-frs-open"), Transcript::new(b"metal-frs-open"), Transcript::new(b"metal-frs-open"));
                let oc = pcs::open_zk(&cpu, &cl, &mut tc);
                let o0 = pcs::open_zk(&dev0, &cl, &mut t0);
                let o1 = pcs::open_zk(&dev1, &cl, &mut t1);
                let (mut bc, mut b0, mut b1) = (Vec::new(), Vec::new(), Vec::new());
                oc.write_bytes(&mut bc);
                o0.write_bytes(&mut b0);
                o1.write_bytes(&mut b1);
                assert_eq!(b1, bc, "zk shape {si} (log_n={log_cols}, ir={ir}, q={q}): frs1 vs CPU OpeningZk bytes");
                assert_eq!(b1, b0, "zk shape {si} (log_n={log_cols}, ir={ir}, q={q}): frs1 vs frs0 OpeningZk bytes");
                assert_eq!(t1.challenge_fp2(), tc.challenge_fp2(), "zk shape {si}: transcript after opening");
            }
        }

        // 3. Plain RS (q = 0): (log_n=14, inv_rate=2, q=0) and sibling geometries vs CPU and frs0.
        let plain_shapes: [(u32, usize, usize, bool); 4] = [
            (14, 2, 6, true),
            (14, 4, 5, false),
            (13, 2, 5, false),
            (12, 4, 5, false),
        ];
        for (si, &(log_cols, ir, rows, use18)) in plain_shapes.iter().enumerate() {
            let ntt = if use18 { &ntt18 } else { &ntt16 };
            let p = params(log_cols, ir);
            let (n, nn) = (p.cols(), p.enc_cols());
            let data = rnd(12000 + si as u64, rows * n);
            let cpu = pcs::commit(&p, &data, ntt);
            let encoded = match &cpu.store {
                Store::Host { encoded } => encoded.clone(),
                Store::Device(never) => match *never {},
            };
            let cpu_leaves = pcs::hash_columns(&encoded, rows, nn);

            hashline::gpu::set_fused_rs_for_test(Some(false));
            let c0_before = hashline::gpu::fused_rs_calls_for_test();
            let (mc0, leaves0) = hashline::gpu::metal_commit(&p, &data, ntt).expect("metal_commit frs0");
            assert_eq!(hashline::gpu::fused_rs_calls_for_test() - c0_before, 0, "plain shape {si}: frs0 must not dispatch fused RS");
            hashline::gpu::set_fused_rs_for_test(Some(true));
            let c1_before = hashline::gpu::fused_rs_calls_for_test();
            let (mc1, leaves1) = hashline::gpu::metal_commit(&p, &data, ntt).expect("metal_commit frs1");
            assert_eq!(hashline::gpu::fused_rs_calls_for_test() - c1_before, 1, "plain shape {si}: expected exact 1 fused RS dispatch");

            assert_eq!(leaves1, cpu_leaves, "plain shape {si} (log_n={log_cols}, ir={ir}, q=0): frs1 vs CPU leaves");
            assert_eq!(leaves1, leaves0, "plain shape {si} (log_n={log_cols}, ir={ir}, q=0): frs1 vs frs0 leaves");
            assert_eq!(MerkleTree::build(leaves1).root(), cpu.tree.root(), "plain shape {si}: root");

            let idx: Vec<usize> = [0, 1, 2047 % nn, 2048 % nn, nn / 2, nn - 1, (nn / 3) | 1].into_iter().map(|j| j % nn).collect();
            let cols0 = mc0.columns(&idx).expect("plain cols0");
            let cols1 = mc1.columns(&idx).expect("plain cols1");
            assert_eq!(cols1, cols0, "plain shape {si}: frs1 vs frs0 columns");
            for (c, &j) in cols1.iter().zip(&idx) {
                let want: Vec<Fp> = (0..rows).map(|i| encoded[i * nn + j]).collect();
                assert_eq!(*c, want, "plain shape {si}: column {j}");
            }
            let rhos = vec![rnd2(13000 + si as u64, rows), rnd2(13100 + si as u64, rows)];
            assert_eq!(mc1.fold_rows(&rhos).expect("plain fold1"), mc0.fold_rows(&rhos).expect("plain fold0"), "plain shape {si}: folds");
        }

        println!(
            "ZK60_METAL_SUMMARY {{\"case\":\"m1-fused-rs\",\"zk_shapes\":{},\"plain_shapes\":{}}}",
            zk_shapes.len(),
            plain_shapes.len()
        );
    }

    /// [OPT-NEXT-1] Exact installed W16R2 Shieldstral classifier commitment
    /// geometries: A (2,504 rows, log_n=14, inv_rate=2, q=280, keyed),
    /// H (2,606 rows, log_n=14, inv_rate=2, q=280, keyed), traced W16R2
    /// boundary (38 rows, log_n=14, inv_rate=2, q=280, keyed), and R13
    /// boundary (38 rows, log_n=14, inv_rate=4, q=256, keyed). Checks frs1
    /// against BOTH CPU oracle and Metal frs0 on roots, leaves, sampled encoded
    /// columns, row folds, complete `OpeningZk` bytes, and post-opening
    /// transcript challenge, with exact `FUSED_RS_CALLS` delta anti-vacuity.
    #[test]
    fn m1_fused_rs_classifier_exact_shapes() {
        let _lock = lock_device();
        require_device();
        let _guard = FusedRsGuard(hashline::gpu::set_fused_rs_for_test(Some(false)));

        let ntt18 = NttTables::new(18);
        let backend = hashline::gpu::backend();
        let tag = HashTag::for_profile("hashline-zk-mr1/metal-test/1");
        let raw_key = tag.node_key().expect("keyed tag");

        // (label, log_cols, inv_rate, q, rows)
        let cls_shapes: [(&str, u32, usize, usize, usize); 4] = [
            ("w16r2_block_a", 14, 2, 280, 2504),
            ("w16r2_block_h", 14, 2, 280, 2606),
            ("w16r2_boundary_traced", 14, 2, 280, 38),
            ("r13_boundary", 14, 4, 256, 38),
        ];

        for (si, &(label, log_cols, ir, q, rows)) in cls_shapes.iter().enumerate() {
            let p = params(log_cols, ir);
            let (n, nn) = (p.cols(), p.enc_cols());
            let zk = ZkOpts { q_pad: q, coset: Fp::new(7) };
            let data = rnd(21000 + si as u64, rows * n);
            let pads = rnd(22000 + si as u64, rows * q);
            let pows = pcs::coset_powers(zk.coset, nn);
            let idx: Vec<usize> = [0, 1, 2, 2047, 2048, nn / 2, nn - 1, (nn / 3) | 1]
                .into_iter()
                .map(|j| j % nn)
                .collect();
            let rhos = vec![rnd2(23000 + si as u64, rows), rnd2(23100 + si as u64, rows)];

            // 1. Direct keyed metal_commit_zk: frs0 vs frs1 (leaves, columns, row folds) + exact delta.
            hashline::gpu::set_fused_rs_for_test(Some(false));
            let c0_before = hashline::gpu::fused_rs_calls_for_test();
            let (mc0, leaves0) = hashline::gpu::metal_commit_zk(&p, &data, &pads, &pows, &ntt18, Some(&raw_key))
                .expect("metal_commit_zk frs0");
            assert_eq!(hashline::gpu::fused_rs_calls_for_test() - c0_before, 0, "{label}: frs0 dispatched fused RS");

            hashline::gpu::set_fused_rs_for_test(Some(true));
            let c1_before = hashline::gpu::fused_rs_calls_for_test();
            let (mc1, leaves1) = hashline::gpu::metal_commit_zk(&p, &data, &pads, &pows, &ntt18, Some(&raw_key))
                .expect("metal_commit_zk frs1");
            assert_eq!(
                hashline::gpu::fused_rs_calls_for_test() - c1_before,
                1,
                "{label}: expected exact 1 fused RS dispatch"
            );
            assert_eq!(leaves1, leaves0, "{label}: frs1 vs frs0 leaves");
            assert_eq!(mc1.columns(&idx).expect("cols1"), mc0.columns(&idx).expect("cols0"), "{label}: columns");
            assert_eq!(mc1.fold_rows(&rhos).expect("fold1"), mc0.fold_rows(&rhos).expect("fold0"), "{label}: folds");
            drop((mc0, mc1, leaves0, leaves1));

            // 2. Full tagged commit_zk + open_zk: CPU oracle vs Metal frs0 vs Metal frs1.
            let mut r_cpu = ZkRng::new(24000 + si as u64, b"metal-frs-cls");
            let mut cpu = pcs::commit_zk_owned_with_tag(&Cpu, &p, data.clone(), &ntt18, &zk, &mut r_cpu, &tag);

            hashline::gpu::set_fused_rs_for_test(Some(false));
            let c0_open = hashline::gpu::fused_rs_calls_for_test();
            let mut r_dev0 = ZkRng::new(24000 + si as u64, b"metal-frs-cls");
            let mut dev0 = pcs::commit_zk_owned_with_tag(&backend, &p, data.clone(), &ntt18, &zk, &mut r_dev0, &tag);
            assert_eq!(hashline::gpu::fused_rs_calls_for_test() - c0_open, 0, "{label}: commit_zk frs0 dispatched fused RS");

            hashline::gpu::set_fused_rs_for_test(Some(true));
            let c1_open = hashline::gpu::fused_rs_calls_for_test();
            let mut r_dev1 = ZkRng::new(24000 + si as u64, b"metal-frs-cls");
            let mut dev1 = pcs::commit_zk_owned_with_tag(&backend, &p, data, &ntt18, &zk, &mut r_dev1, &tag);
            assert_eq!(
                hashline::gpu::fused_rs_calls_for_test() - c1_open,
                1,
                "{label}: commit_zk_owned_with_tag expected exact 1 fused RS dispatch"
            );
            assert!(matches!(dev0.cm.store, Store::Device(_)), "{label}: frs0 declined");
            assert!(matches!(dev1.cm.store, Store::Device(_)), "{label}: frs1 declined");
            assert_eq!(dev1.commitment().root, cpu.commitment().root, "{label}: frs1 vs CPU salted root");
            assert_eq!(dev1.commitment().root, dev0.commitment().root, "{label}: frs1 vs frs0 salted root");

            for mr in [&mut cpu.mask_rows, &mut dev0.mask_rows, &mut dev1.mask_rows] {
                *mr = vec![rows - 3, rows - 2];
            }
            cpu.prox_mask_row = Some(rows - 1);
            dev0.prox_mask_row = Some(rows - 1);
            dev1.prox_mask_row = Some(rows - 1);
            let cl = claims(rows, log_cols, 25000 + si as u64);
            let (mut tc, mut t0, mut t1) = (
                Transcript::new(b"metal-frs-cls-open"),
                Transcript::new(b"metal-frs-cls-open"),
                Transcript::new(b"metal-frs-cls-open"),
            );
            let oc = pcs::open_zk(&cpu, &cl, &mut tc);
            let o0 = pcs::open_zk(&dev0, &cl, &mut t0);
            let o1 = pcs::open_zk(&dev1, &cl, &mut t1);
            let (mut bc, mut b0, mut b1) = (Vec::new(), Vec::new(), Vec::new());
            oc.write_bytes(&mut bc);
            o0.write_bytes(&mut b0);
            o1.write_bytes(&mut b1);
            assert_eq!(b1, bc, "{label}: frs1 vs CPU OpeningZk bytes");
            assert_eq!(b1, b0, "{label}: frs1 vs frs0 OpeningZk bytes");
            assert_eq!(t1.challenge_fp2(), tc.challenge_fp2(), "{label}: transcript after opening");
        }

        println!(
            "ZK60_METAL_SUMMARY {{\"case\":\"m1-fused-rs-classifier\",\"shapes\":{}}}",
            cls_shapes.len()
        );
    }

    struct SparseFoldGuard(Option<bool>);
    impl Drop for SparseFoldGuard {
        fn drop(&mut self) {
            hashline::gpu::metal_set_sparse_fold_for_test(self.0);
        }
    }

    /// [Opt 1 + OPT-NEXT-1, M4 + L8] Composed sparse-fold + fused-RS byte parity
    /// across installed classifier shapes (holding `METAL_TEST_LOCK`), asserting
    /// exact `SPARSE_FOLD_CALLS`, `SPARSE_FOLD_FALLBACKS`, and `FUSED_RS_CALLS` deltas.
    #[test]
    fn m1_sparse_fold_and_fused_rs_composed_parity() {
        let _lock = lock_device();
        require_device();
        let _frs_guard = FusedRsGuard(hashline::gpu::set_fused_rs_for_test(Some(false)));
        let _sf_guard = SparseFoldGuard(hashline::gpu::metal_set_sparse_fold_for_test(Some(false)));

        let ntt18 = NttTables::new(18);
        let backend = hashline::gpu::backend();
        let tag = HashTag::for_profile("hashline-zk-mr1/metal-test/1");

        // Installed classifier geometries covering log_cols in {8, 12, 14}
        let shapes: [(&str, u32, usize, usize, usize, u64); 5] = [
            ("w16r2_block_a", 14, 2, 280, 2504, 1),
            ("w16r2_block_h", 14, 2, 280, 2606, 1),
            ("w16r2_boundary_traced", 14, 2, 280, 38, 1),
            ("w16r2_log12_76", 12, 4, 256, 76, 1),
            ("w16r2_log8_6", 8, 4, 256, 6, 0),
        ];

        for (si, &(label, log_cols, ir, q, rows, exp_frs)) in shapes.iter().enumerate() {
            let p = params(log_cols, ir);
            let zk = ZkOpts { q_pad: q, coset: Fp::new(7) };
            let data = rnd(31000 + si as u64, rows * p.cols());
            let cl = claims(rows, log_cols, 35000 + si as u64);

            // Reference: CPU oracle
            let mut r_cpu = ZkRng::new(34000 + si as u64, b"metal-sf-frs");
            let mut cpu = pcs::commit_zk_owned_with_tag(&Cpu, &p, data.clone(), &ntt18, &zk, &mut r_cpu, &tag);
            cpu.mask_rows = vec![rows - 3, rows - 2];
            cpu.prox_mask_row = Some(rows - 1);
            let mut t_cpu = Transcript::new(b"metal-sf-frs-open");
            let o_cpu = pcs::open_zk(&cpu, &cl, &mut t_cpu);
            let mut b_cpu = Vec::new();
            o_cpu.write_bytes(&mut b_cpu);
            let tr_cpu = t_cpu.challenge_fp2();

            for (frs_on, sf_on, arm) in [(false, false, "frs0+sf0"), (false, true, "frs0+sf1"), (true, true, "frs1+sf1")] {
                hashline::gpu::set_fused_rs_for_test(Some(frs_on));
                hashline::gpu::metal_set_sparse_fold_for_test(Some(sf_on));
                let frs_before = hashline::gpu::fused_rs_calls_for_test();
                let sf_before = hashline::gpu::metal_sparse_fold_calls_for_test();
                let fb_before = hashline::gpu::metal_sparse_fold_fallbacks_for_test();

                let mut r_dev = ZkRng::new(34000 + si as u64, b"metal-sf-frs");
                let mut dev = pcs::commit_zk_owned_with_tag(&backend, &p, data.clone(), &ntt18, &zk, &mut r_dev, &tag);
                assert!(matches!(dev.cm.store, Store::Device(_)), "{label}/{arm}: Metal declined");
                assert_eq!(dev.commitment().root, cpu.commitment().root, "{label}/{arm}: root mismatch");
                dev.mask_rows = vec![rows - 3, rows - 2];
                dev.prox_mask_row = Some(rows - 1);

                let mut t_dev = Transcript::new(b"metal-sf-frs-open");
                let o_dev = pcs::open_zk(&dev, &cl, &mut t_dev);
                let mut b_dev = Vec::new();
                o_dev.write_bytes(&mut b_dev);

                let frs_delta = hashline::gpu::fused_rs_calls_for_test() - frs_before;
                let sf_delta = hashline::gpu::metal_sparse_fold_calls_for_test() - sf_before;
                let fb_delta = hashline::gpu::metal_sparse_fold_fallbacks_for_test() - fb_before;

                assert_eq!(b_dev, b_cpu, "{label}/{arm}: OpeningZk bytes mismatch");
                assert_eq!(t_dev.challenge_fp2(), tr_cpu, "{label}/{arm}: transcript mismatch");
                assert_eq!(frs_delta, if frs_on { exp_frs } else { 0 }, "{label}/{arm}: FUSED_RS_CALLS delta");
                assert_eq!(fb_delta, 0, "{label}/{arm}: unexpected sparse fold fallback");
                if sf_on {
                    assert_eq!(sf_delta, 1, "{label}/{arm}: expected exact 1 SPARSE_FOLD_CALLS dispatch");
                } else {
                    assert_eq!(sf_delta, 0, "{label}/{arm}: sf0 dispatched sparse fold");
                }
            }
        }
        println!("ZK60_METAL_SUMMARY {{\"case\":\"m1-sparse-fold-composed\",\"shapes\":{}}}", shapes.len());
    }

    /// [ZK60-METAL M2] The keyed hiding commitment at model-block sizes, CPU
    /// against Metal, roots compared, wall clocks printed. A diagnostic, not a
    /// receipt: one run each on a shared box. Shapes: Shieldstral-3B T128's A
    /// commitment (~0.6 GB of planes = 4,608 rows at n = 2^14), and an 8B T512
    /// sized one (rows x 2^15).
    #[test]
    #[ignore = "heavy: multi-GB commitments; run through the resource guard"]
    fn m2_keyed_commit_timing_at_block_sizes() {
        let _lock = lock_device();
        require_device();
        let ntt = NttTables::new(18);
        let tag = HashTag::for_profile("hashline-zk-mr1/metal-bench/1");
        let backend = hashline::gpu::backend();
        for &(log_cols, rows) in &[(14u32, 4608usize), (15, 4608), (15, 9216)] {
            let p = PcsParams { log_cols, inv_rate: 4, num_col_checks: 256 };
            let zk = ZkOpts { q_pad: 256, coset: Fp::new(7) };
            let data = rnd(7 + log_cols as u64, rows * p.cols());
            let t = std::time::Instant::now();
            let mut r1 = ZkRng::new(1, b"bench");
            let cpu = pcs::commit_zk_owned_with_tag(&Cpu, &p, data.clone(), &ntt, &zk, &mut r1, &tag);
            let cpu_s = t.elapsed().as_secs_f64();
            // warm the device path once (pipeline + twiddle upload), then time it
            let _ = hashline::gpu::metal_commit_zk(&p, &data[..p.cols()], &vec![Fp::ZERO; 256], &pcs::coset_powers(Fp::new(7), p.enc_cols()), &ntt, None);
            let t = std::time::Instant::now();
            let mut r2 = ZkRng::new(1, b"bench");
            let dev = pcs::commit_zk_owned_with_tag(&backend, &p, data.clone(), &ntt, &zk, &mut r2, &tag);
            let dev_s = t.elapsed().as_secs_f64();
            assert!(matches!(dev.cm.store, Store::Device(_)));
            assert_eq!(dev.commitment().root, cpu.commitment().root, "root at 2^{log_cols} x {rows}");
            let gb = (rows * p.enc_cols() * 8) as f64 / 1e9;
            println!(
                "ZK60_METAL_BENCH {{\"log_cols\":{log_cols},\"rows\":{rows},\"encoded_gb\":{gb:.2},\"cpu_s\":{cpu_s:.3},\"metal_s\":{dev_s:.3},\"speedup\":{:.2},\"threads\":{}}}",
                cpu_s / dev_s,
                rayon::current_num_threads()
            );
        }
    }

    /// [ZK60-METAL M21] Rate 1/2 against rate 1/4 at the W16 8B block's A
    /// shape (2^14 columns x 2,504 rows). This is the falsification test of the
    /// research handoff `research/zkp-efficiency/handoffs/20261101-gpu-work-per-block.md`:
    /// predicted device total 27 -> 16.7 ms, kill above 19 ms. Roots are checked
    /// CPU = Metal once per rate, then `HL_M21_REPS` warm device commits are
    /// timed. A diagnostic, not a receipt; no proof format changes.
    #[test]
    #[ignore = "heavy: run through the resource guard"]
    fn m21_commit_rate_half_against_quarter_at_the_w16_8b_a_shape() {
        require_device();
        let ntt = NttTables::new(18);
        let tag = HashTag::for_profile("hashline-zk-mr1/metal-bench/1");
        let backend = hashline::gpu::backend();
        let reps: usize = std::env::var("HL_M21_REPS").ok().and_then(|s| s.parse().ok()).unwrap_or(5);
        let rows = 2504usize;
        for &inv_rate in &[4usize, 2, 4, 2] {
            let p = PcsParams { log_cols: 14, inv_rate, num_col_checks: 256 };
            let zk = ZkOpts { q_pad: 256, coset: Fp::new(7) };
            let data = rnd(21 + inv_rate as u64, rows * p.cols());
            let mut r1 = ZkRng::new(1, b"bench");
            let cpu = pcs::commit_zk_owned_with_tag(&Cpu, &p, data.clone(), &ntt, &zk, &mut r1, &tag);
            let _ = hashline::gpu::metal_commit_zk(&p, &data[..p.cols()], &vec![Fp::ZERO; 256], &pcs::coset_powers(Fp::new(7), p.enc_cols()), &ntt, None);
            let mut times = Vec::with_capacity(reps);
            for _ in 0..reps {
                let d = data.clone();
                let mut r2 = ZkRng::new(1, b"bench");
                let t = std::time::Instant::now();
                let dev = pcs::commit_zk_owned_with_tag(&backend, &p, d, &ntt, &zk, &mut r2, &tag);
                times.push(t.elapsed().as_secs_f64() * 1e3);
                assert!(matches!(dev.cm.store, Store::Device(_)));
                assert_eq!(dev.commitment().root, cpu.commitment().root, "root at rate 1/{inv_rate}");
            }
            times.sort_by(|a, b| a.partial_cmp(b).unwrap());
            println!(
                "ZK60_METAL_M21 {{\"inv_rate\":{inv_rate},\"rows\":{rows},\"log_cols\":14,\"enc_cols\":{},\"reps\":{reps},\"min_ms\":{:.2},\"median_ms\":{:.2},\"max_ms\":{:.2}}}",
                p.enc_cols(),
                times[0],
                times[reps / 2],
                times[reps - 1]
            );
        }
    }
}
