// A28 commitment-kernel bench (from A27's): the zk commit's kernels at the R13 Shieldstral A shape
// (rows x 2^14 -> 2^16, q = 256), each in its own command buffer, GPU timestamps, best of N. The tree's kernels
// (A27 as pinned: r4 head and tail, the BLAKE3 column hash) against the A28 variants; every variant's output is
// compared word for word with the tree's.
// usage: a28nb <metal_kernels.metal> <variants.metal> [rows]
use metal::*;
mod field;

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
struct HeadArgs { rows: u64, log_n: u32, log_src: u32, mode: u32, max_log: u32, q: u64, scale: u64, apply_scale: u32, use_hw: u32, pow2: u32, r4: u32, prune: u32, pad9: u32 }
#[repr(C)]
struct TailArgs { rows: u64, log_n: u32, max_log: u32, scale: u64, apply_scale: u32, r4: u32 }
#[repr(C)]
struct HashArgs { rows: u64, nn: u64, keyed: u32, pad0: u32, key: [u32; 8] }

fn gpu_dt(cb: &CommandBufferRef) -> f64 {
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
    if a.get(3).map(|v| v == "field").unwrap_or(false) {
        field::run(&src);
        return;
    }
    let rows: usize = a.get(3).map(|v| v.parse().unwrap()).unwrap_or(4577);
    let reps: usize = a.get(4).map(|v| v.parse().unwrap()).unwrap_or(5);
    let (log_n, log_nn, q, max_log) = (14u32, 16u32, 256usize, 16u32);
    let (n, nn) = (1usize << log_n, 1usize << log_nn);
    let dev = Device::system_default().unwrap();
    let lib = match dev.new_library_with_source(&src, &CompileOptions::new()) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("compile: {e}");
            std::process::exit(2);
        }
    };
    let pipe = |name: &str| dev.new_compute_pipeline_state_with_function(&lib.get_function(name, None).unwrap()).unwrap();
    let (head, tail, hash) = (pipe("k_ntt_head"), pipe("k_ntt_tail"), pipe("k_hash_cols"));
    let (h16, h8, t5, t3, hc, hm) = (pipe("k_a28_head16"), pipe("k_a28_head8"), pipe("k_a28_tail_reg5"), pipe("k_a28_tail_reg3"), pipe("k_a28_hash_chunk"), pipe("k_a28_hash_merge"));
    for (nm, p) in [("head16", &h16), ("head8", &h8), ("tail_reg5", &t5), ("tail_reg3", &t3), ("hash_chunk", &hc), ("hash_merge", &hm)] {
        println!("pipeline {nm}: max threads/tg {}, exec width {}, static tg mem {}", p.max_total_threads_per_threadgroup(), p.thread_execution_width(), p.static_threadgroup_memory_length());
    }
    let q_ = dev.new_command_queue();
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
    let newb = |words: usize| dev.new_buffer((words * 8) as u64, MTLResourceOptions::StorageModeShared);
    let (bt0, bt1) = (newb(rows * n), newb(rows * n));
    let (be0, be1, be2) = (newb(rows * nn), newb(rows * nn), newb(rows * nn));
    let n_chunks = (rows * 8 + 1023) / 1024;
    let bcv = dev.new_buffer((nn * n_chunks * 32) as u64, MTLResourceOptions::StorageModeShared);
    let (bl0, bl1) = (dev.new_buffer((nn * 32) as u64, MTLResourceOptions::StorageModeShared), dev.new_buffer((nn * 32) as u64, MTLResourceOptions::StorageModeShared));
    let ninv = powm(n as u64, P - 2);
    let time = |f: &dyn Fn(&ComputeCommandEncoderRef)| -> f64 {
        let mut best = f64::MAX;
        for _ in 0..reps {
            let cb = q_.new_command_buffer();
            let enc = cb.new_compute_command_encoder();
            f(enc);
            enc.end_encoding();
            cb.commit();
            cb.wait_until_completed();
            best = best.min(gpu_dt(cb));
        }
        best * 1e3
    };
    let once = |f: &dyn Fn(&ComputeCommandEncoderRef)| {
        let cb = q_.new_command_buffer();
        let enc = cb.new_compute_command_encoder();
        f(enc);
        enc.end_encoding();
        cb.commit();
        cb.wait_until_completed();
    };
    let set = |enc: &ComputeCommandEncoderRef, i: u64, b: &Buffer| enc.set_buffer(i, Some(b), 0);
    // the tree's head (r4 = 1, the power-of-2 stages as pinned) or a variant
    let head_runp = |enc: &ComputeCommandEncoderRef, p: &ComputePipelineState, srcb: &Buffer, dst: &Buffer, inverse: bool, ln: u32, lsrc: u32, mode: u32, th: u64, pw: u32, r4: u32, scale: Option<u64>, prune: u32| {
        enc.set_compute_pipeline_state(p);
        set(enc, 0, srcb);
        set(enc, 1, &bpad);
        set(enc, 2, &bpow);
        set(enc, 3, dst);
        set(enc, 4, if inverse { &bti } else { &btf });
        set(enc, 6, if inverse { &bhi } else { &bhf });
        set(enc, 7, if inverse { &bxi } else { &bxf });
        let args = HeadArgs { rows: rows as u64, log_n: ln, log_src: lsrc, mode, max_log, q: q as u64, scale: scale.unwrap_or(1), apply_scale: scale.is_some() as u32, use_hw: 1, pow2: pw, r4, prune, pad9: 0 };
        enc.set_bytes(5, std::mem::size_of::<HeadArgs>() as u64, &args as *const HeadArgs as *const _);
        enc.dispatch_thread_groups(MTLSize::new((1u64 << ln) / 2048, rows as u64, 1), MTLSize::new(th, 1, 1));
    };
    let head_run = |enc: &ComputeCommandEncoderRef, p: &ComputePipelineState, srcb: &Buffer, dst: &Buffer, inverse: bool, ln: u32, lsrc: u32, mode: u32, th: u64, pw: u32, r4: u32, scale: Option<u64>| {
        head_runp(enc, p, srcb, dst, inverse, ln, lsrc, mode, th, pw, r4, scale, 0)
    };
    let tail_run = |enc: &ComputeCommandEncoderRef, b: &Buffer, inverse: bool, ln: u32, scale: Option<u64>| {
        enc.set_compute_pipeline_state(&tail);
        set(enc, 0, b);
        set(enc, 1, if inverse { &bti } else { &btf });
        let args = TailArgs { rows: rows as u64, log_n: ln, max_log, scale: scale.unwrap_or(1), apply_scale: scale.is_some() as u32, r4: 1 };
        enc.set_bytes(2, std::mem::size_of::<TailArgs>() as u64, &args as *const TailArgs as *const _);
        enc.dispatch_thread_groups(MTLSize::new(1u64 << (ln - 11), rows as u64, 1), MTLSize::new(512, 1, 1));
    };
    let treg_run = |enc: &ComputeCommandEncoderRef, p: &ComputePipelineState, b: &Buffer, inverse: bool, ln: u32, scale: Option<u64>, tgw: u64| {
        enc.set_compute_pipeline_state(p);
        set(enc, 0, b);
        set(enc, 1, if inverse { &bti } else { &btf });
        let args = TailArgs { rows: rows as u64, log_n: ln, max_log, scale: scale.unwrap_or(1), apply_scale: scale.is_some() as u32, r4: 0 };
        enc.set_bytes(2, std::mem::size_of::<TailArgs>() as u64, &args as *const TailArgs as *const _);
        enc.dispatch_threads(MTLSize::new(2048, rows as u64, 1), MTLSize::new(tgw, 1, 1));
    };
    let hash_args = HashArgs { rows: rows as u64, nn: nn as u64, keyed: 1, pad0: 0, key: [0x1234_5678, 1, 2, 3, 4, 5, 6, 0xdead_beef] };
    let hash_run = |enc: &ComputeCommandEncoderRef, b: &Buffer, l: &Buffer| {
        enc.set_compute_pipeline_state(&hash);
        set(enc, 0, b);
        set(enc, 1, l);
        enc.set_bytes(2, std::mem::size_of::<HashArgs>() as u64, &hash_args as *const HashArgs as *const _);
        enc.dispatch_threads(MTLSize::new(nn as u64, 1, 1), MTLSize::new(256, 1, 1));
    };
    let hash2_run = |enc: &ComputeCommandEncoderRef, b: &Buffer, l: &Buffer, tgw: u64, merge: bool| {
        enc.set_compute_pipeline_state(&hc);
        set(enc, 0, b);
        set(enc, 1, &bcv);
        set(enc, 2, l);
        enc.set_bytes(3, std::mem::size_of::<HashArgs>() as u64, &hash_args as *const HashArgs as *const _);
        enc.dispatch_threads(MTLSize::new(nn as u64, n_chunks as u64, 1), MTLSize::new(tgw, 1, 1));
        if merge {
            enc.set_compute_pipeline_state(&hm);
            set(enc, 0, &bcv);
            set(enc, 1, l);
            enc.set_bytes(2, std::mem::size_of::<HashArgs>() as u64, &hash_args as *const HashArgs as *const _);
            enc.dispatch_threads(MTLSize::new(nn as u64, 1, 1), MTLSize::new(256, 1, 1));
        }
    };
    let words = |b: &Buffer, len: usize| unsafe { std::slice::from_raw_parts(b.contents() as *const u64, len) }.to_vec();

    // ---- correctness: the inverse transform
    once(&|e| head_run(e, &head, &bd, &bt0, true, log_n, log_n, 0, 512, 6, 1, None));
    once(&|e| tail_run(e, &bt0, true, log_n, Some(ninv)));
    once(&|e| head_run(e, &h16, &bd, &bt1, true, log_n, log_n, 0, 128, 0, 0, None));
    once(&|e| treg_run(e, &t3, &bt1, true, log_n, Some(ninv), 256));
    let t_ref = words(&bt0, rows * n);
    println!("inverse words: head16 + tail_reg3 == tree {}", words(&bt1, rows * n) == t_ref);
    once(&|e| head_run(e, &h8, &bd, &bt1, true, log_n, log_n, 0, 256, 0, 0, None));
    once(&|e| treg_run(e, &t3, &bt1, true, log_n, Some(ninv), 256));
    println!("inverse words: head8 + tail_reg3 == tree {}", words(&bt1, rows * n) == t_ref);
    // ---- the forward transform (from the tree's inverse output)
    once(&|e| head_run(e, &head, &bt0, &be0, false, log_nn, log_n, 2, 512, 6, 1, None));
    let fh_ref = words(&be0, rows * nn);
    once(&|e| head_run(e, &h16, &bt0, &be1, false, log_nn, log_n, 2, 128, 0, 0, None));
    println!("forward head words: head16 == tree {}", words(&be1, rows * nn) == fh_ref);
    once(&|e| head_run(e, &h8, &bt0, &be2, false, log_nn, log_n, 2, 256, 0, 0, None));
    println!("forward head words: head8 == tree {}", words(&be2, rows * nn) == fh_ref);
    once(&|e| head_runp(e, &head, &bt0, &be2, false, log_nn, log_n, 2, 512, 6, 1, None, 1));
    println!("forward head words: tree pruned (A28) == tree {}", words(&be2, rows * nn) == fh_ref);
    drop(fh_ref);
    once(&|e| tail_run(e, &be0, false, log_nn, None));
    once(&|e| treg_run(e, &t5, &be1, false, log_nn, None, 256));
    let enc_ref = words(&be0, rows * nn);
    println!("forward tail words: tail_reg5 == tree {}", words(&be1, rows * nn) == enc_ref);
    drop(enc_ref);
    // ---- the hash
    once(&|e| hash_run(e, &be0, &bl0));
    once(&|e| hash2_run(e, &be0, &bl1, 256, true));
    let lw = |b: &Buffer| unsafe { std::slice::from_raw_parts(b.contents() as *const u8, nn * 32) }.to_vec();
    println!("leaves: chunk + merge == tree {} (chunks per column {n_chunks})", lw(&bl1) == lw(&bl0));
    let (thc, thm) = (pipe("k_hash_chunk"), pipe("k_hash_merge"));
    let tree2 = |enc: &ComputeCommandEncoderRef, b: &Buffer, l: &Buffer| {
        enc.set_compute_pipeline_state(&thc);
        set(enc, 0, b);
        set(enc, 1, &bcv);
        set(enc, 2, l);
        enc.set_bytes(3, std::mem::size_of::<HashArgs>() as u64, &hash_args as *const HashArgs as *const _);
        enc.dispatch_threads(MTLSize::new(nn as u64, n_chunks as u64, 1), MTLSize::new(64, 1, 1));
        enc.set_compute_pipeline_state(&thm);
        set(enc, 0, &bcv);
        set(enc, 1, l);
        enc.set_bytes(2, std::mem::size_of::<HashArgs>() as u64, &hash_args as *const HashArgs as *const _);
        enc.dispatch_threads(MTLSize::new(nn as u64, 1, 1), MTLSize::new(256, 1, 1));
    };
    once(&|e| tree2(e, &be0, &bl1));
    println!("leaves: the tree's k_hash_chunk + k_hash_merge (A28) == k_hash_cols {}", lw(&bl1) == lw(&bl0));

    // ---- timings
    let mut out = Vec::new();
    out.push(("inverse head (tree, r4)", time(&|e| head_run(e, &head, &bd, &bt0, true, log_n, log_n, 0, 512, 6, 1, None))));
    out.push(("inverse head16", time(&|e| head_run(e, &h16, &bd, &bt1, true, log_n, log_n, 0, 128, 0, 0, None))));
    out.push(("inverse head8", time(&|e| head_run(e, &h8, &bd, &bt1, true, log_n, log_n, 0, 256, 0, 0, None))));
    out.push(("inverse tail (tree, r4)", time(&|e| tail_run(e, &bt0, true, log_n, Some(ninv)))));
    for tgw in [64u64, 128, 256, 512] {
        let v = time(&|e| treg_run(e, &t3, &bt1, true, log_n, Some(ninv), tgw));
        out.push((Box::leak(format!("inverse tail_reg3 tg {tgw}").into_boxed_str()), v));
    }
    out.push(("forward head (tree, r4)", time(&|e| head_run(e, &head, &bt0, &be0, false, log_nn, log_n, 2, 512, 6, 1, None))));
    out.push(("forward head16", time(&|e| head_run(e, &h16, &bt0, &be1, false, log_nn, log_n, 2, 128, 0, 0, None))));
    out.push(("forward head8", time(&|e| head_run(e, &h8, &bt0, &be2, false, log_nn, log_n, 2, 256, 0, 0, None))));
    out.push(("forward head (tree, r4, A28 pruned)", time(&|e| head_runp(e, &head, &bt0, &be2, false, log_nn, log_n, 2, 512, 6, 1, None, 1))));
    out.push(("forward tail (tree, r4)", time(&|e| tail_run(e, &be0, false, log_nn, None))));
    for tgw in [64u64, 128, 256, 512] {
        let v = time(&|e| treg_run(e, &t5, &be1, false, log_nn, None, tgw));
        out.push((Box::leak(format!("forward tail_reg5 tg {tgw}").into_boxed_str()), v));
    }
    out.push(("hash (tree)", time(&|e| hash_run(e, &be0, &bl0))));
    for tgw in [64u64, 128, 256] {
        let v = time(&|e| hash2_run(e, &be0, &bl1, tgw, true));
        out.push((Box::leak(format!("hash chunk+merge tg {tgw}").into_boxed_str()), v));
    }
    out.push(("hash chunk only tg 256", time(&|e| hash2_run(e, &be0, &bl1, 256, false))));
    out.push(("hash (tree, A28 two passes)", time(&|e| tree2(e, &be0, &bl1))));
    // ALU probes: rows * 2^16 words as 16-word threads, 88 butterflies each
    let nthr = (rows * nn / 16) as u64;
    for (nm, k) in [("alu: butterfly (mul+add+sub)", "k_a28_alu0"), ("alu: add+sub only", "k_a28_alu1"), ("alu: mul only", "k_a28_alu2")] {
        let p = pipe(k);
        let v = time(&|e| {
            e.set_compute_pipeline_state(&p);
            set(e, 0, &be2);
            set(e, 1, &bhf);
            e.dispatch_threads(MTLSize::new(nthr, 1, 1), MTLSize::new(256, 1, 1));
        });
        out.push((nm, v));
    }
    println!("alu probes: {} butterflies each ({} threads x 88)", nthr * 88, nthr);
    for (k, v) in &out {
        println!("{k:<34} {v:8.3} ms");
    }
}
