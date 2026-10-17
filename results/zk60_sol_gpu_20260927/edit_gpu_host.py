from pathlib import Path
p=Path('/tmp/zk60-sol-gpu-20260927/hashline/src/gpu/cuda.rs'); s=p.read_text()
def rep(a,b,n=1):
 global s
 count=s.count(a)
 if count!=n: raise RuntimeError((a[:90],count,n))
 s=s.replace(a,b)
rep('"k_probe", "k_ntt_p1", "k_ntt_p2", "k_gather_cols", "k_hash_cols",','"k_probe", "k_ntt_p1", "k_ntt_p2", "k_gather_cols", "k_hash_cols", "k_hash_cols_keyed",')
rep('"k_hash_cols_stream", "k_gather_cols_off",','"k_hash_cols_stream", "k_hash_cols_stream_keyed", "k_gather_cols_off",')
# Dedicated key upload only on tagged paths, as 8 little-endian words.
keyfn='''fn key_words(key: &[u8; 32]) -> [u32; 8] {
    std::array::from_fn(|i| u32::from_le_bytes(key[4*i..4*i+4].try_into().unwrap()))
}

'''
pos=s.index('const KSRC:')
s=s[:pos]+keyfn+s[pos:]
# Add key parameter only to zk chunked helper, existing callsites send None.
rep('''                         chunk: usize) -> Result<Vec<Digest>, String> {
        let dev = self.dev.clone();
        let plan = chunk_plan(rows, chunk);''','''                         chunk: usize, key: Option<&[u8; 32]>) -> Result<Vec<Digest>, String> {
        let dev = self.dev.clone();
        let plan = chunk_plan(rows, chunk);''')
a='g.commit_zk_chunked(&d_data, &d_pads, &d_pows, rows, n, q, nn, log_n, log_nn, chunk_rows())?'
rep(a,a[:-2]+', key)?',2)
# all other diagnostic calls stay unkeyed
rep('g.commit_zk_chunked(&d_data, &d_pads, &d_pows, rows, n, q_pad, nn, log_cols, log_nn, chunk)?','g.commit_zk_chunked(&d_data, &d_pads, &d_pows, rows, n, q_pad, nn, log_cols, log_nn, chunk, None)?',2)
# Other calls may share q_pad form and log_cols.
# Stream branch kernel and key retained until synchronous leaves download.
rep('''        let f_hash = dev.get_func(MODULE, "k_hash_cols_stream").ok_or("k_hash_cols_stream missing")?;
        note_vram(self);
        for &(r0, rc) in &plan {''','''        let d_key = key.map(|k| dev.htod_sync_copy(&key_words(k)).map_err(|e| format!("hash key upload: {e}"))).transpose()?;
        let name = if key.is_some() { "k_hash_cols_stream_keyed" } else { "k_hash_cols_stream" };
        let f_hash = dev.get_func(MODULE, name).ok_or("zk column hash kernel missing")?;
        note_vram(self);
        for &(r0, rc) in &plan {''')
rep('''            unsafe { f_hash.clone().launch(cfg, (d_enc.get(), d_state.get_mut(), rc as i32, r0 as i32, rows as i32, nn as i32, &mut d_leaves)) }
                .map_err(|e| format!("k_hash_cols_stream: {e}"))?;
        }
        let words = dev.dtoh_sync_copy(&d_leaves)''','''            if let Some(k) = &d_key {
                unsafe { f_hash.clone().launch(cfg, (d_enc.get(), d_state.get_mut(), rc as i32, r0 as i32, rows as i32, nn as i32, &mut d_leaves, k)) }
                    .map_err(|e| format!("k_hash_cols_stream_keyed: {e}"))?;
            } else {
                unsafe { f_hash.clone().launch(cfg, (d_enc.get(), d_state.get_mut(), rc as i32, r0 as i32, rows as i32, nn as i32, &mut d_leaves)) }
                    .map_err(|e| format!("k_hash_cols_stream: {e}"))?;
            }
        }
        let words = dev.dtoh_sync_copy(&d_leaves)''')
# Hash helper add distinct keyed variant; unkeyed stays untouched.
pos=s.index('\n}\n',s.index('    fn hash_cols(&self,'))+2
s=s[:pos]+'''
    fn hash_cols_keyed(&self, enc: &CudaSlice<u64>, rows: usize, nn: usize, key: &[u8; 32]) -> Result<Vec<Digest>, String> {
        let f = self.dev.get_func(MODULE, "k_hash_cols_keyed").ok_or("k_hash_cols_keyed missing")?;
        let d_key = self.dev.htod_sync_copy(&key_words(key)).map_err(|e| format!("hash key upload: {e}"))?;
        let mut d_leaves = unsafe { self.dev.alloc::<u32>(nn * 8) }.map_err(|e| format!("leaves alloc: {e}"))?;
        note_raw_alloc(nn * 8 * 4);
        let cfg = LaunchConfig::for_num_elems(nn as u32);
        unsafe { f.launch(cfg, (enc, &mut d_leaves, rows as i32, nn as i32, &d_key)) }.map_err(|e| format!("k_hash_cols_keyed: {e}"))?;
        let words = self.dev.dtoh_sync_copy(&d_leaves).map_err(|e| format!("leaves download: {e}"))?;
        let mut leaves = vec![[0u8; 32]; nn];
        for (j, leaf) in leaves.iter_mut().enumerate() {
            for w in 0..8 { leaf[4*w..4*w+4].copy_from_slice(&words[j*8+w].to_le_bytes()); }
        }
        Ok(leaves)
    }
''' + s[pos:]
# Refactor zk from into opt-key worker, retain public unkeyed API.
rep('''pub fn dev_commit_zk_from(params: &PcsParams, d_data: Pooled, rows: usize, pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {''','''pub fn dev_commit_zk_from(params: &PcsParams, d_data: Pooled, rows: usize, pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    dev_commit_zk_from_inner(params, d_data, rows, pads, pows, ntt, None)
}

fn dev_commit_zk_from_inner(params: &PcsParams, d_data: Pooled, rows: usize, pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: Option<&[u8; 32]>) -> Result<(DevCommit, Vec<Digest>), String> {''')
rep('''    let leaves = g.hash_cols(d_enc.get(), rows, nn)?;
    let t3 = Instant::now();
    stats_with(|s| { s.secs_hash += (t3 - t2).as_secs_f64(); s.bytes_d2h += (nn * 32) as u64; });
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc), zk: None }, leaves))''','''    let leaves = match key { Some(k) => g.hash_cols_keyed(d_enc.get(), rows, nn, k)?, None => g.hash_cols(d_enc.get(), rows, nn)? };
    let t3 = Instant::now();
    stats_with(|s| { s.secs_hash += (t3 - t2).as_secs_f64(); s.bytes_d2h += (nn * 32) as u64; });
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc), zk: None }, leaves))''')
# Upload wrapper separate opt-key worker.
rep('''pub fn dev_commit_zk(params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    let g = gpu().ok_or_else(init_err)?;''','''pub fn dev_commit_zk(params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    dev_commit_zk_uploaded(params, data, pads, pows, ntt, None)
}

pub fn dev_commit_zk_keyed(params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: &[u8; 32]) -> Result<(DevCommit, Vec<Digest>), String> {
    dev_commit_zk_uploaded(params, data, pads, pows, ntt, Some(key))
}

fn dev_commit_zk_uploaded(params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: Option<&[u8; 32]>) -> Result<(DevCommit, Vec<Digest>), String> {
    let g = gpu().ok_or_else(init_err)?;''')
rep('''    dev_commit_zk_from(params, d_data, rows, pads, pows, ntt)
}''','''    dev_commit_zk_from_inner(params, d_data, rows, pads, pows, ntt, key)
}''')
p.write_text(s)
