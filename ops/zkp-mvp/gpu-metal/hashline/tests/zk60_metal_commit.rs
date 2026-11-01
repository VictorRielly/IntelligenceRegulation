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
        require_device();
        let ntt = NttTables::new(16);
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
        println!("ZK60_METAL_SUMMARY {{\"case\":\"m1-plain\",\"shapes\":{}}}", SHAPES.len());
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
        require_device();
        let ntt = NttTables::new(16);
        let backend = hashline::gpu::backend();
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
        println!("ZK60_METAL_SUMMARY {{\"case\":\"m1-zk{}\",\"shapes\":{cases}}}", if tag.is_some() { "-keyed" } else { "" });
    }

    #[test]
    fn m1_zk_commit_and_opening_bytes_match_the_cpu() {
        zk_pair(None);
    }

    #[test]
    fn m1_keyed_zk_commit_and_opening_bytes_match_the_cpu() {
        zk_pair(Some(&HashTag::for_profile("hashline-zk-mr1/metal-test/1")));
    }

    /// [ZK60-METAL M2] The keyed hiding commitment at model-block sizes, CPU
    /// against Metal, roots compared, wall clocks printed. A diagnostic, not a
    /// receipt: one run each on a shared box. Shapes: Shieldstral-3B T128's A
    /// commitment (~0.6 GB of planes = 4,608 rows at n = 2^14), and an 8B T512
    /// sized one (rows x 2^15).
    #[test]
    #[ignore = "heavy: multi-GB commitments; run through the resource guard"]
    fn m2_keyed_commit_timing_at_block_sizes() {
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
