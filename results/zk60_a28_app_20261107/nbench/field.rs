// A28: the field-arithmetic variants against the tree's (every mismatch counted) and their butterfly rates.
use metal::*;

const P: u64 = 0xFFFF_FFFF_0000_0001;

fn gpu_dt(cb: &CommandBufferRef) -> f64 {
    use objc::Message;
    unsafe {
        let t0: f64 = cb.send_message(objc::runtime::Sel::register("GPUStartTime"), ()).unwrap_or(0.0);
        let t1: f64 = cb.send_message(objc::runtime::Sel::register("GPUEndTime"), ()).unwrap_or(0.0);
        t1 - t0
    }
}

pub fn run(src: &str) {
    let dev = Device::system_default().unwrap();
    let lib = match dev.new_library_with_source(src, &CompileOptions::new()) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("compile: {e}");
            std::process::exit(2);
        }
    };
    let pipe = |name: &str| dev.new_compute_pipeline_state_with_function(&lib.get_function(name, None).unwrap()).unwrap();
    let q_ = dev.new_command_queue();
    let mut s = 0x2545_F491_4F6C_DD1Du64;
    let mut rnd = move || {
        s ^= s << 13;
        s ^= s >> 7;
        s ^= s << 17;
        s
    };
    let edges: Vec<u64> = {
        let mut e = vec![
            0u64, 1, 2, 3, P - 1, P - 2, P - 3, 0xFFFF_FFFF, 0xFFFF_FFFE, 0x1_0000_0000, 0x1_0000_0001, 1 << 63, (1 << 63) - 1, (1 << 63) + 1,
            P - 0xFFFF_FFFF, P - 0x1_0000_0000, 0xFFFF_FFFE_FFFF_FFFF, 0xFFFF_FFFE_0000_0000, 0xFFFF_FFFF_0000_0000, 0x8000_0000, 0x7FFF_FFFF,
            0xFFFF_FFFF_FFFF_FFFF, P, P + 1,
        ];
        for k in 0..64 {
            e.push(1u64 << k);
            e.push((1u64 << k).wrapping_sub(1));
            e.push(P.wrapping_sub(1u64 << k));
        }
        e.sort();
        e.dedup();
        e
    };
    let check = |xs: &[u64], ys: &[u64]| -> [u64; 6] {
        let bx = dev.new_buffer_with_data(xs.as_ptr() as *const _, (xs.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
        let by = dev.new_buffer_with_data(ys.as_ptr() as *const _, (ys.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
        let bo = dev.new_buffer((xs.len() * 4) as u64, MTLResourceOptions::StorageModeShared);
        let p = pipe("k_a28_fcheck");
        let cb = q_.new_command_buffer();
        let enc = cb.new_compute_command_encoder();
        enc.set_compute_pipeline_state(&p);
        enc.set_buffer(0, Some(&bx), 0);
        enc.set_buffer(1, Some(&by), 0);
        enc.set_buffer(2, Some(&bo), 0);
        enc.dispatch_threads(MTLSize::new(xs.len() as u64, 1, 1), MTLSize::new(256, 1, 1));
        enc.end_encoding();
        cb.commit();
        cb.wait_until_completed();
        let o = unsafe { std::slice::from_raw_parts(bo.contents() as *const u32, xs.len()) };
        let mut c = [0u64; 6];
        for &m in o {
            for (b, cc) in c.iter_mut().enumerate() {
                if m & (1 << b) != 0 {
                    *cc += 1;
                }
            }
        }
        c
    };
    // canonical pairs: the canonical edges' cross product, 2^24 random pairs, 2^24 near p / below 2^32
    let ce: Vec<u64> = edges.iter().cloned().filter(|&v| v < P).collect();
    let (mut xs, mut ys) = (Vec::new(), Vec::new());
    for &x in &ce {
        for &y in &ce {
            xs.push(x);
            ys.push(y);
        }
    }
    for _ in 0..(1 << 24) {
        let (x, y) = (rnd() % P, rnd() % P);
        xs.push(x);
        ys.push(y);
        xs.push(P - 1 - (x & 0xFFFF));
        ys.push(y & 0xFFFF_FFFF);
    }
    let c = check(&xs, &ys);
    println!("canonical pairs {}: mismatches add_b {} add_c {} sub_c {} mul_b {} mul_c {} reduce_b {}", xs.len(), c[0], c[1], c[2], c[3], c[4], c[5]);
    let (mut xs, mut ys) = (Vec::new(), Vec::new());
    for &x in &edges {
        for &y in &edges {
            xs.push(x);
            ys.push(y);
        }
    }
    for _ in 0..(1 << 24) {
        xs.push(rnd());
        ys.push(rnd());
    }
    let c = check(&xs, &ys);
    println!(
        "any-u64 pairs {}: mismatches mul_b {} mul_c {} reduce_b {} (add/sub are specified on canonical inputs only: add_b {} add_c {} sub_c {})",
        xs.len(),
        c[3],
        c[4],
        c[5],
        c[0],
        c[1],
        c[2]
    );
    // rates: 2^28 words as 16-word threads, 88 butterflies each
    let words = 1usize << 26;
    let data: Vec<u64> = (0..words).map(|i| (i as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15) % P).collect();
    let tw: Vec<u64> = (0..1024u64).map(|i| (i.wrapping_mul(0xD1B5_4A32_D192_ED03)) % P).collect();
    let bt = dev.new_buffer_with_data(tw.as_ptr() as *const _, (tw.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
    let nb = (words / 16) as f64 * 88.0;
    let mut res = Vec::new();
    for v in 0..3 {
        let p = pipe(&format!("k_a28_falu{v}"));
        let b = dev.new_buffer_with_data(data.as_ptr() as *const _, (words * 8) as u64, MTLResourceOptions::StorageModeShared);
        let mut best = f64::MAX;
        for rep in 0..6 {
            if rep == 1 {
                // the words of one pass from the common start
                res.push(unsafe { std::slice::from_raw_parts(b.contents() as *const u64, words) }.to_vec());
            }
            let cb = q_.new_command_buffer();
            let enc = cb.new_compute_command_encoder();
            enc.set_compute_pipeline_state(&p);
            enc.set_buffer(0, Some(&b), 0);
            enc.set_buffer(1, Some(&bt), 0);
            enc.dispatch_threads(MTLSize::new((words / 16) as u64, 1, 1), MTLSize::new(256, 1, 1));
            enc.end_encoding();
            cb.commit();
            cb.wait_until_completed();
            best = best.min(gpu_dt(cb));
        }
        println!("falu{v}: {:.3} ms for {:.3e} butterflies ({:.1} G/s)", best * 1e3, nb, nb / best * 1e-9);
    }
    println!("falu words after one pass equal: v1 == v0 {}, v2 == v0 {}", res[1] == res[0], res[2] == res[0]);
}
