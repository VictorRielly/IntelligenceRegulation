pub fn dev_fold_rows(dc: &DevCommit, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let k = rhos.len();
    let rows = dc.rows;
    let n = 1usize << dc.log_n;
    assert!(k >= 1 && k <= 4, "dev_fold_rows: {k} weight vectors (max 4)");
    let mut flat: Vec<u64> = Vec::with_capacity(k * rows * 2);
    for rho in rhos {
        assert_eq!(rho.len(), rows);
        flat.extend(as_u64s_f2(rho));
    }
    let d_rho = dev.htod_sync_copy(&flat).map_err(|e| e.to_string())?;
    let mut d_out = unsafe { dev.alloc::<u64>(k * n * 2) }.map_err(|e| e.to_string())?;
    let f = dev.get_func(MODULE, "k_fold_rows").ok_or("k_fold_rows missing")?;
    let cfg = LaunchConfig::for_num_elems(n as u32);
    unsafe { f.launch(cfg, (dc.data.get(), &d_rho, &mut d_out, rows as i32, n as i32, k as i32)) }.map_err(|e| format!("k_fold_rows: {e}"))?;
    let h = dev.dtoh_sync_copy(&d_out).map_err(|e| e.to_string())?;
    stats_with(|s| { s.secs_fold += t0.elapsed().as_secs_f64(); s.bytes_d2h += (k * n * 16) as u64; });
    Ok((0..k).map(|g| (0..n).map(|j| Fp2::new(Fp(h[(g * n + j) * 2]), Fp(h[(g * n + j) * 2 + 1]))).collect()).collect())
}
