from pathlib import Path
root=Path('/tmp/zk60-sol-gpu-20260927')
def change(rel,old,new,count=None):
 p=root/rel;s=p.read_text();n=s.count(old)
 if count is not None and n!=count: raise RuntimeError((rel,old[:70],n,count))
 if not n: raise RuntimeError((rel,old[:70]))
 p.write_text(s.replace(old,new))
change('zkp-core/src/pcs/backend.rs','    /// The hiding form: encode', '''    /// The tagged hiding form. A backend must override this separately to
    /// attest that it hashes UNSALTED columns under the supplied public key.
    /// The default declines rather than silently using the unkeyed hook.
    fn try_commit_zk_keyed(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: &[u8; 32]) -> Option<(Self::Store, Vec<Digest>)> {
        let _ = (params, data, pads, pows, ntt, key);
        None
    }

    /// The hiding form: encode''',1)
change('zkp-core/src/pcs.rs','''        Some(_) => None,
    };''','''        Some(key) => backend.try_commit_zk_keyed(params, data_ref, &pads, &pows, ntt, key),
    };''',1)
change('hashline/src/gpu/mod.rs','''        // [UPERF3-ZA] the device path (rung 4):''','''        fn try_commit_zk_keyed(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: &[u8; 32]) -> Option<(DevCommit, Vec<Digest>)> {
            if !enabled() { return None; }
            match cuda::dev_commit_zk_keyed(params, data, pads, pows, ntt, key) {
                Ok(x) => Some(x),
                Err(e) => { eprintln!("[ZK60] keyed gpu zk commit declined ({e}); CPU path"); None }
            }
        }
        // [UPERF3-ZA] the device path (rung 4):''',1)
# CUDA: keyed BLAKE3 is key words in place of IV; KEYED_HASH is ORed into every compression.
p='hashline/src/gpu/kernels.cu'
change(p,'#define B3_ROOT 8u','#define B3_ROOT 8u\n#define B3_KEYED_HASH 16u',1)
change(p,'__device__ void b3_hash_column(const u64* __restrict__ enc, size_t nn, int rows, int j, u32* out) {','__device__ void b3_hash_column(const u64* __restrict__ enc, size_t nn, int rows, int j, u32* out, const u32* key) {',1)
a=(root/p).read_text();start=a.index('__device__ void b3_hash_column(');end=a.index('// leaves[j * 8',start);seg=a[start:end];seg=seg.replace('b3_iv(iv);','if (key) { for (int i = 0; i < 8; i++) iv[i] = key[i]; } else b3_iv(iv);').replace('b3_iv(cv);','if (key) { for (int i = 0; i < 8; i++) cv[i] = key[i]; } else b3_iv(cv);').replace('B3_PARENT, tmp','B3_PARENT | (key ? B3_KEYED_HASH : 0u), tmp').replace('B3_PARENT | (s == 0 ? B3_ROOT : 0u), tmp','B3_PARENT | (s == 0 ? B3_ROOT : 0u) | (key ? B3_KEYED_HASH : 0u), tmp').replace('if (is_last && stack_len == 0 && last_block) flags |= B3_ROOT;','if (is_last && stack_len == 0 && last_block) flags |= B3_ROOT;\n            if (key) flags |= B3_KEYED_HASH;');a=a[:start]+seg+a[end:];(root/p).write_text(a)
change(p,'b3_hash_column(enc, (size_t)nn, rows, j, out);','b3_hash_column(enc, (size_t)nn, rows, j, out, nullptr);',1)
marker='// ---------------------------------------------------------------------------\n// [rung 3]'
insert='''extern "C" __global__ void k_hash_cols_keyed(const u64* __restrict__ enc, u32* __restrict__ leaves, int rows, int nn, const u32* __restrict__ key) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= nn) return;
    u32 out[8];
    b3_hash_column(enc, (size_t)nn, rows, j, out, key);
    #pragma unroll
    for (int w = 0; w < 8; w++) leaves[(size_t)j * 8 + w] = out[w];
}

'''
change(p,marker,insert+marker,1)
# Stream: duplicate kernel via source text to avoid branch changes to established unkeyed path.
a=(root/p).read_text();start=a.index('extern "C" __global__ void k_hash_cols_stream(');end=a.index('// Column gather from a ROW CHUNK',start);seg=a[start:end];seg=seg.replace('k_hash_cols_stream(', 'k_hash_cols_stream_keyed(',1).replace('u32* __restrict__ leaves) {','u32* __restrict__ leaves, const u32* __restrict__ key) {',1).replace('b3_iv(iv);','for (int i = 0; i < 8; i++) iv[i] = key[i];').replace('b3_iv(cv);','for (int i = 0; i < 8; i++) cv[i] = key[i];').replace('B3_PARENT, tmp','B3_PARENT | B3_KEYED_HASH, tmp').replace('B3_PARENT | (s == 0 ? B3_ROOT : 0u), tmp','B3_PARENT | (s == 0 ? B3_ROOT : 0u) | B3_KEYED_HASH, tmp').replace('if (is_last && stack_len == 0 && last_block) flags |= B3_ROOT;','if (is_last && stack_len == 0 && last_block) flags |= B3_ROOT;\n            flags |= B3_KEYED_HASH;');a=a[:end]+seg+a[end:];(root/p).write_text(a)
# q>n overlap: both terms must be applied independently.
change(p,'''    if (i < n) {
        v = coef[(size_t)row * (size_t)n + i];
        if (i < q) v = gl_sub(v, pads[(size_t)row * (size_t)q + i]);
    } else if (i < n + q) {
        v = pads[(size_t)row * (size_t)q + (i - n)];
    }''','''    if (i < n) v = coef[(size_t)row * (size_t)n + i];
    if (i < q) v = gl_sub(v, pads[(size_t)row * (size_t)q + i]);
    if (i >= n && i < n + q) v = gl_add(v, pads[(size_t)row * (size_t)q + (i - n)]);''',1)
