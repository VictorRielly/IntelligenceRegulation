// A27 commitment-kernel bench: the zk commit's kernels at the R13 Shieldstral A shape (rows x 2^14 -> 2^16, q = 256),
// each in its own command buffer, GPU timestamps, best of 3: the inverse head and tail, the forward head (as is,
// without the power-of-2 stages, two stages per barrier), the forward tail, the column hash, and a head floor
// (loads and stores only). The head variants' outputs are compared word for word.
// usage: nb <metal_kernels.metal> <variants.metal> [rows]
use metal::*;

const P: u64 = 0xFFFF_FFFF_0000_0001;
fn mulm(a: u64, b: u64) -> u64 {
    ((a as u128 * b as u128) % P as u128) as u64
}
fn powm(mut a: u64, mut e: u64) -> u64 {
    let mut r = 1u64;
    while e > 0 {
        if e & 1 == 1 {
            r = mulm(r, a);
        }
        a = mulm(a, a);
        e >>= 1;
    }
    r
}

#[repr(C)]
struct HeadArgs { rows: u64, log_n: u32, log_src: u32, mode: u32, max_log: u32, q: u64, scale: u64, apply_scale: u32, use_hw: u32, pow2: u32, pad1: u32 }
#[repr(C)]
struct TailArgs { rows: u64, log_n: u32, max_log: u32, scale: u64, apply_scale: u32, pad0: u32 }
#[repr(C)]
struct HashArgs { rows: u64, nn: u64, keyed: u32, pad0: u32, key: [u32; 8] }

fn gpu_times(cb: &CommandBufferRef) -> f64 {
    use objc::Message;
    unsafe {
        let t0: f64 = cb.send_message(objc::runtime::Sel::register("GPUStartTime"), ()).unwrap_or(0.0);
        let t1: f64 = cb.send_message(objc::runtime::Sel::register("GPUEndTime"), ()).unwrap_or(0.0);
        t1 - t0
    }
}

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let src = format!("{}\n{}", std::fs::read_to_string(&a[1]).unwrap(), std::fs::read_to_string(&a[2]).unwrap());
    let rows: usize = a.get(3).map(|v| v.parse().unwrap()).unwrap_or(4577);
    let (log_n, log_nn, q, max_log) = (14u32, 16u32, 256usize, 16u32);
    let (n, nn) = (1usize << log_n, 1usize << log_nn);
    let dev = Device::system_default().unwrap();
    let lib = dev.new_library_with_source(&src, &CompileOptions::new()).unwrap();
    let pipe = |name: &str| dev.new_compute_pipeline_state_with_function(&lib.get_function(name, None).unwrap()).unwrap();
    let (head, head4, floor, tail, hash) = (pipe("k_ntt_head"), pipe("k_ntt_head_r4"), pipe("k_ntt_head_floor"), pipe("k_ntt_tail"), pipe("k_hash_cols"));
    let q_ = dev.new_command_queue();
    // twiddles: omega a primitive 2^max_log root (7 generates the multiplicative group)
    let om = powm(7, (P - 1) >> max_log);
    let omi = powm(om, P - 2);
    let tf: Vec<u64> = (0..(1u64 << max_log)).map(|i| powm(om, i)).collect();
    let ti: Vec<u64> = (0..(1u64 << max_log)).map(|i| powm(omi, i)).collect();
    let pick = |t: &[u64]| -> Vec<u64> { (0..1024usize).map(|m| t[m << (max_log - 11)]).collect() };
    let (hf, hi) = (pick(&tf), pick(&ti));
    let mut pow2 = std::collections::HashMap::new();
    let mut x = 1u64;
    for e in 0..192u32 {
        pow2.insert(x, e);
        x = mulm(x, 2);
    }
    let ex = |h: &[u64]| -> Vec<u32> { (0..32).map(|j| *pow2.get(&h[32 * j]).expect("a power of 2")).collect() };
    let (xf, xi) = (ex(&hf), ex(&hi));
    let mut s = 0x9e37_79b9_7f4a_7c15u64;
    let mut rnd = move || {
        s ^= s << 13;
        s ^= s >> 7;
        s ^= s << 17;
        s % P
    };
    let d: Vec<u64> = (0..rows * n).map(|_| rnd()).collect();
    let pads: Vec<u64> = (0..rows * q).map(|_| rnd()).collect();
    let pows: Vec<u64> = (0..nn).map(|_| rnd()).collect();
    let buf_u64 = |v: &[u64]| dev.new_buffer_with_data(v.as_ptr() as *const _, (v.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
    let buf_u32 = |v: &[u32]| dev.new_buffer_with_data(v.as_ptr() as *const _, (v.len() * 4) as u64, MTLResourceOptions::StorageModeShared);
    let (bd, bpad, bpow, btf, bti, bhf, bhi, bxf, bxi) = (buf_u64(&d), buf_u64(&pads), buf_u64(&pows), buf_u64(&tf), buf_u64(&ti), buf_u64(&hf), buf_u64(&hi), buf_u32(&xf), buf_u32(&xi));
    let bt = dev.new_buffer((rows * n * 8) as u64, MTLResourceOptions::StorageModeShared);
    let be: Vec<Buffer> = (0..4).map(|_| dev.new_buffer((rows * nn * 8) as u64, MTLResourceOptions::StorageModeShared)).collect();
    let bl = dev.new_buffer((nn * 32) as u64, MTLResourceOptions::StorageModeShared);
    let ninv = powm(n as u64, P - 2);
    let time = |f: &dyn Fn(&ComputeCommandEncoderRef)| -> f64 {
        let mut best = f64::MAX;
        for _ in 0..3 {
            let cb = q_.new_command_buffer();
            let enc = cb.new_compute_command_encoder();
            f(enc);
            enc.end_encoding();
            cb.commit();
            cb.wait_until_completed();
            best = best.min(gpu_times(cb));
        }
        best
    };
    let set = |enc: &ComputeCommandEncoderRef, i: u64, b: &Buffer| enc.set_buffer(i, Some(b), 0);
    let head_run = |enc: &ComputeCommandEncoderRef, p: &ComputePipelineState, srcb: &Buffer, dst: &Buffer, inverse: bool, ln: u32, lsrc: u32, mode: u32, pw: u32, th: u64| {
        enc.set_compute_pipeline_state(p);
        set(enc, 0, srcb);
        set(enc, 1, &bpad);
        set(enc, 2, &bpow);
        set(enc, 3, dst);
        set(enc, 4, if inverse { &bti } else { &btf });
        set(enc, 6, if inverse { &bhi } else { &bhf });
        set(enc, 7, if inverse { &bxi } else { &bxf });
        let args = HeadArgs { rows: rows as u64, log_n: ln, log_src: lsrc, mode, max_log, q: q as u64, scale: 1, apply_scale: 0, use_hw: 1, pow2: pw, pad1: 0 };
        enc.set_bytes(5, std::mem::size_of::<HeadArgs>() as u64, &args as *const HeadArgs as *const _);
        enc.dispatch_thread_groups(MTLSize::new((1u64 << ln) / 2048, rows as u64, 1), MTLSize::new(th, 1, 1));
    };
    let tail_run = |enc: &ComputeCommandEncoderRef, b: &Buffer, inverse: bool, ln: u32, scale: Option<u64>| {
        enc.set_compute_pipeline_state(&tail);
        set(enc, 0, b);
        set(enc, 1, if inverse { &bti } else { &btf });
        let args = TailArgs { rows: rows as u64, log_n: ln, max_log, scale: scale.unwrap_or(1), apply_scale: scale.is_some() as u32, pad0: 0 };
        enc.set_bytes(2, std::mem::size_of::<TailArgs>() as u64, &args as *const TailArgs as *const _);
        enc.dispatch_thread_groups(MTLSize::new(1u64 << (ln - 11), rows as u64, 1), MTLSize::new(1024, 1, 1));
    };
    let words = |b: &Buffer| unsafe { std::slice::from_raw_parts(b.contents() as *const u64, rows * nn) }.to_vec();
    let t_ih = time(&|e| head_run(e, &head, &bd, &bt, true, log_n, log_n, 0, 6, 1024));
    let t_ih0 = time(&|e| head_run(e, &head, &bd, &bt, true, log_n, log_n, 0, 0, 1024));
    let t_it = time(&|e| tail_run(e, &bt, true, log_n, Some(ninv)));
    // (t now holds an inverse-transformed matrix, scaled several times over: any field words do for timing)
    let t_fh = time(&|e| head_run(e, &head, &bt, &be[0], false, log_nn, log_n, 2, 6, 1024));
    let t_fh0 = time(&|e| head_run(e, &head, &bt, &be[1], false, log_nn, log_n, 2, 0, 1024));
    let t_fh4 = time(&|e| head_run(e, &head4, &bt, &be[2], false, log_nn, log_n, 2, 6, 512));
    let t_fl = time(&|e| head_run(e, &floor, &bt, &be[3], false, log_nn, log_n, 2, 0, 1024));
    let (w0, w1, w2) = (words(&be[0]), words(&be[1]), words(&be[2]));
    println!("forward head words: pow2 == plain {}, radix-4 == plain {}", w0 == w1, w2 == w1);
    // the tails: be[1] and be[2] hold the same head output as be[0]; the original tail runs on be[1] once, the
    // radix-4 tail on be[2] once (compared), then each is timed on its own buffer (in place, any words do)
    let tail4 = pipe("k_ntt_tail_r4");
    let once = |f: &dyn Fn(&ComputeCommandEncoderRef)| {
        let cb = q_.new_command_buffer();
        let enc = cb.new_compute_command_encoder();
        f(enc);
        enc.end_encoding();
        cb.commit();
        cb.wait_until_completed();
    };
    let tail_with = |enc: &ComputeCommandEncoderRef, p: &ComputePipelineState, b: &Buffer, th: u64| {
        enc.set_compute_pipeline_state(p);
        set(enc, 0, b);
        set(enc, 1, &btf);
        let args = TailArgs { rows: rows as u64, log_n: log_nn, max_log, scale: 1, apply_scale: 0, pad0: 0 };
        enc.set_bytes(2, std::mem::size_of::<TailArgs>() as u64, &args as *const TailArgs as *const _);
        enc.dispatch_thread_groups(MTLSize::new(1u64 << (log_nn - 11), rows as u64, 1), MTLSize::new(th, 1, 1));
    };
    once(&|e| tail_with(e, &tail, &be[1], 1024));
    once(&|e| tail_with(e, &tail4, &be[2], 512));
    println!("forward tail words: radix-4 == plain {}", words(&be[1]) == words(&be[2]));
    let t_ft4 = time(&|e| tail_with(e, &tail4, &be[2], 512));
    println!("forward tail radix-4 {:.2} ms", t_ft4 * 1e3);
    let t_ft = time(&|e| tail_run(e, &be[0], false, log_nn, None));
    let t_h = time(&|e| {
        e.set_compute_pipeline_state(&hash);
        set(e, 0, &be[0]);
        set(e, 1, &bl);
        let args = HashArgs { rows: rows as u64, nn: nn as u64, keyed: 0, pad0: 0, key: [0; 8] };
        e.set_bytes(2, std::mem::size_of::<HashArgs>() as u64, &args as *const HashArgs as *const _);
        e.dispatch_threads(MTLSize::new(nn as u64, 1, 1), MTLSize::new(256, 1, 1));
    });
    println!("rows {rows}: inverse head {:.2} ms (pow2 off {:.2}), inverse tail {:.2}; forward head {:.2} ms (pow2 off {:.2}, radix-4 {:.2}, loads+stores floor {:.2}), forward tail {:.2}; hash {:.2} ms",
        t_ih * 1e3, t_ih0 * 1e3, t_it * 1e3, t_fh * 1e3, t_fh0 * 1e3, t_fh4 * 1e3, t_fl * 1e3, t_ft * 1e3, t_h * 1e3);
}
