// gl_mul variants on the Apple GPU: equal outputs? time per variant.
use metal::*;
use std::time::Instant;

const VARIANTS: &str = r#"
inline void mul_b(ulong a, ulong b, thread ulong &lo, thread ulong &hi) {
    uint a0 = uint(a), a1 = uint(a >> 32);
    uint b0 = uint(b), b1 = uint(b >> 32);
    ulong p00 = (ulong(mulhi(a0, b0)) << 32) | ulong(a0 * b0);
    ulong p01 = (ulong(mulhi(a0, b1)) << 32) | ulong(a0 * b1);
    ulong p10 = (ulong(mulhi(a1, b0)) << 32) | ulong(a1 * b0);
    ulong p11 = (ulong(mulhi(a1, b1)) << 32) | ulong(a1 * b1);
    ulong mid = (p00 >> 32) + (p01 & 0xFFFFFFFFUL) + (p10 & 0xFFFFFFFFUL);
    lo = (p00 & 0xFFFFFFFFUL) | (mid << 32);
    hi = p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32);
}
inline ulong gl_mul_b(ulong a, ulong b) { ulong lo, hi; mul_b(a, b, lo, hi); return gl_reduce128(lo, hi); }
inline ulong gl_mul_c(ulong a, ulong b) { return gl_reduce128(a * b, mulhi(a, b)); }
#define CHAIN 256
kernel void k_a(device ulong *x [[buffer(0)]], uint gid [[thread_position_in_grid]]) {
    ulong v = x[2 * gid], w = x[2 * gid + 1];
    for (uint i = 0; i < CHAIN; i++) { v = gl_mul(v, w); w = gl_add(w, v); }
    x[2 * gid] = v; x[2 * gid + 1] = w;
}
kernel void k_b(device ulong *x [[buffer(0)]], uint gid [[thread_position_in_grid]]) {
    ulong v = x[2 * gid], w = x[2 * gid + 1];
    for (uint i = 0; i < CHAIN; i++) { v = gl_mul_b(v, w); w = gl_add(w, v); }
    x[2 * gid] = v; x[2 * gid + 1] = w;
}
kernel void k_c(device ulong *x [[buffer(0)]], uint gid [[thread_position_in_grid]]) {
    ulong v = x[2 * gid], w = x[2 * gid + 1];
    for (uint i = 0; i < CHAIN; i++) { v = gl_mul_c(v, w); w = gl_add(w, v); }
    x[2 * gid] = v; x[2 * gid + 1] = w;
}
"#;

fn main() {
    let src = std::fs::read_to_string("/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal_kernels.metal").unwrap();
    let end = src.find("// ------------------------------------------------------------- field probe").unwrap();
    let full = format!("{}\n{}", &src[..end], VARIANTS);
    let dev = Device::system_default().unwrap();
    let lib = dev.new_library_with_source(&full, &CompileOptions::new()).unwrap();
    let q = dev.new_command_queue();
    let n: usize = 1 << 21;
    // inputs: arbitrary 64-bit words, edge values mixed in
    let p: u64 = 0xFFFF_FFFF_0000_0001;
    let mut s = 0x1234_5678_9abc_def0u64;
    let init: Vec<u64> = (0..2 * n).map(|i| { s ^= s << 13; s ^= s >> 7; s ^= s << 17; match i % 97 { 0 => p - 1, 1 => 0, 2 => 1, 3 => 0xFFFF_FFFF, _ => s % p } }).collect();
    let mut outs = Vec::new();
    for name in ["k_a", "k_b", "k_c"] {
        let f = lib.get_function(name, None).unwrap();
        let pipe = dev.new_compute_pipeline_state_with_function(&f).unwrap();
        let mut best = f64::MAX;
        let mut out = Vec::new();
        for _ in 0..5 {
            let buf = dev.new_buffer_with_data(init.as_ptr() as *const _, (init.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
            let cb = q.new_command_buffer();
            let enc = cb.new_compute_command_encoder();
            enc.set_compute_pipeline_state(&pipe);
            enc.set_buffer(0, Some(&buf), 0);
            enc.dispatch_threads(MTLSize::new(n as u64, 1, 1), MTLSize::new(256, 1, 1));
            enc.end_encoding();
            let t = Instant::now();
            cb.commit();
            cb.wait_until_completed();
            best = best.min(t.elapsed().as_secs_f64());
            out = unsafe { std::slice::from_raw_parts(buf.contents() as *const u64, 2 * n) }.to_vec();
        }
        println!("{name}: {:.4} s for {} muls ({:.2} Gmul/s), max threads/group {}", best, n * 256, (n * 256) as f64 / best / 1e9, pipe.max_total_threads_per_threadgroup());
        outs.push(out);
    }
    println!("b == a: {}  c == a: {}", outs[1] == outs[0], outs[2] == outs[0]);
}
