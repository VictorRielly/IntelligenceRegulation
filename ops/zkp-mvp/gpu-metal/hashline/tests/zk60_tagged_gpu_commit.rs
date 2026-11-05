//! Exact tagged GPU commitment oracle. Run once each with HL_ZK_CHUNK=off
//! and HL_ZK_CHUNK=force; require HL_GPU=1 HL_GPU_REQUIRED=1 on a device.
#![cfg(feature = "gpu-cuda")]

use hashline::{field::Fp, gpu, ntt::NttTables, pcs};
use zkp_core::{hashtag::HashTag, pcs::{Cpu, EncodedStore, PcsParams, Store, ZkOpts}, rng::ZkRng};

#[test]
fn tagged_column_hashes_and_full_commitment_match_cpu() {
    let required = std::env::var("HL_GPU_REQUIRED").map(|v| v == "1").unwrap_or(false);
    if !gpu::enabled() {
        assert!(!required, "HL_GPU_REQUIRED=1 but CUDA backend is unavailable");
        eprintln!("SKIP tagged GPU oracle: device unavailable");
        return;
    }
    let p = PcsParams { log_cols: 8, inv_rate: 4, num_col_checks: 2 };
    let ntt = NttTables::new(10);
    let tag = HashTag::for_profile("hashline-zk-mr1/private-block-m125/2");
    let key = tag.column_key().unwrap();
    let n = p.cols();
    let nn = p.enc_cols();
    // 128 -> 129 crosses BLAKE3's first parent/chunk boundary. q>n
    // exercises the overlap of -pad[i] and +pad[i-n] in the CUDA pad kernel.
    for &(rows, q) in &[(37, 16), (128, 16), (129, 257), (257, 257)] {
        let data: Vec<Fp> = (0..rows*n).map(|i| Fp::new((i as u64 * 137 + 7) % 65521)).collect();
        let pads: Vec<Fp> = (0..rows*q).map(|i| Fp::new((i as u64 * 103 + 11) % 65521)).collect();
        let pows = pcs::coset_powers(Fp::new(7), nn);
        let mut encoded = vec![Fp::ZERO; rows*nn];
        for r in 0..rows {
            pcs::encode_row_zk(&ntt, &data[r*n..(r+1)*n], &pads[r*q..(r+1)*q], &pows, &mut encoded[r*nn..(r+1)*nn]);
        }
        let cpu_leaves = pcs::hash_columns_keyed(&encoded, rows, nn, Some(key));
        let (store, leaves) = gpu::dev_commit_zk_keyed(&p, &data, &pads, &pows, &ntt, key).expect("keyed device commit");
        assert_eq!(leaves, cpu_leaves, "all tagged leaves, rows={rows}, q={q}");
        let wrong = HashTag::for_profile("hashline-zk-mr1/wrong-profile/1");
        let wrong_leaves = pcs::hash_columns_keyed(&encoded, rows, nn, wrong.column_key());
        assert_ne!(leaves, wrong_leaves, "wrong profile key accepted, rows={rows}, q={q}");
        if rows == 129 {
            let (_, wrong_device) = gpu::dev_commit_zk_keyed(&p, &data, &pads, &pows, &ntt, wrong.column_key().unwrap())
                .expect("wrong-key device commit ran");
            assert_eq!(wrong_device, wrong_leaves, "GPU ignored the supplied wrong key");
            assert_ne!(wrong_device, leaves, "different profile keys produced identical leaves");
        }
        let indices = [0, nn-1, 13, 13, nn/2];
        let got = store.columns(&indices).expect("device opening columns");
        for (i, &col) in indices.iter().enumerate() {
            let want: Vec<Fp> = (0..rows).map(|r| encoded[r*nn+col]).collect();
            assert_eq!(got[i], want, "opened column {col}, rows={rows}, q={q}");
        }
    }
    let zk = ZkOpts::standard(&p);
    let rows = 129;
    let data: Vec<Fp> = (0..rows*n).map(|i| Fp::new((i as u64 * 31 + 17) % 65521)).collect();
    let mut r_gpu = ZkRng::new(2309, b"tagged-gpu-oracle");
    let mut r_cpu = ZkRng::new(2309, b"tagged-gpu-oracle");
    let gpu_cm = pcs::commit_zk_owned_tagged(&p, data.clone(), &ntt, &zk, &mut r_gpu, &tag);
    assert!(matches!(gpu_cm.cm.store, Store::Device(_)), "tagged call fell back to CPU");
    let cpu_cm = zkp_core::pcs::commit_zk_owned_with_tag(&Cpu, &p, data, &ntt, &zk, &mut r_cpu, &tag);
    assert_eq!(gpu_cm.commitment().root, cpu_cm.commitment().root);
    assert_eq!(gpu_cm.pads, cpu_cm.pads);
    assert_eq!(gpu_cm.salts, cpu_cm.salts);
    assert_eq!(r_gpu.fp(), r_cpu.fp(), "tagged GPU moved RNG continuation");
}
