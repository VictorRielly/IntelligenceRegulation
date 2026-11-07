// A27 kernel bench (from M4's kbench): time one slot's round kernel variants on random extension tables,
// every round from `start_half` down to 1 (one command buffer per round, GPU timestamps), best of `reps`.
// usage: kb <library.metal> <kmax tables> <degree> <log2 cap> <eval_one> <name:np,name:np,...> [reps]
use metal::*;
use std::time::Instant;

#[repr(C)]
struct RoundArgs {
    half: u64,
    cap: u64,
    eval_one: u32,
    nthreads: u32,
}

const P: u64 = 0xFFFF_FFFF_0000_0001;

fn gpu_times(cb: &CommandBufferRef) -> (f64, f64) {
    use objc::Message;
    unsafe {
        let t0: f64 = cb.send_message(objc::runtime::Sel::register("GPUStartTime"), ()).unwrap_or(0.0);
        let t1: f64 = cb.send_message(objc::runtime::Sel::register("GPUEndTime"), ()).unwrap_or(0.0);
        (t0, t1)
    }
}

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let src = std::fs::read_to_string(&a[1]).unwrap();
    let k: usize = a[2].parse().unwrap();
    let d1: usize = a[3].parse::<usize>().unwrap() + 1;
    let log_cap: u32 = a[4].parse().unwrap();
    let eval_one: u32 = a[5].parse().unwrap();
    let names: Vec<(String, usize)> = a[6].split(',').map(|s| {
        let mut it = s.split(':');
        (it.next().unwrap().to_string(), it.next().unwrap().parse().unwrap())
    }).collect();
    let reps: usize = a.get(7).map(|v| v.parse().unwrap()).unwrap_or(3);
    let start_div: usize = a.get(8).map(|v| v.parse().unwrap()).unwrap_or(4);
    let cap = 1usize << log_cap;
    let dev = Device::system_default().unwrap();
    let t = Instant::now();
    let lib = dev.new_library_with_source(&src, &CompileOptions::new()).unwrap();
    println!("compile {:.2} s", t.elapsed().as_secs_f64());
    let q = dev.new_command_queue();
    let mut s = 0x9e37_79b9_7f4a_7c15u64;
    let mut rnd = move || {
        s ^= s << 13;
        s ^= s >> 7;
        s ^= s << 17;
        s % P
    };
    let tabs: Vec<u64> = (0..k * cap * 2).map(|_| rnd()).collect();
    let cf: Vec<u64> = (0..8192).map(|_| rnd()).collect();
    let tb = dev.new_buffer_with_data(tabs.as_ptr() as *const _, (tabs.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
    let cb_ = dev.new_buffer_with_data(cf.as_ptr() as *const _, (cf.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
    let part = dev.new_buffer(((cap / 2).max(1).min(1 << 17) * d1 * 16) as u64, MTLResourceOptions::StorageModeShared);
    for (name, np) in names {
        let f = lib.get_function(&name, None).unwrap();
        let pipe = dev.new_compute_pipeline_state_with_function(&f).unwrap();
        let mut best = f64::MAX;
        let mut best_rounds: Vec<f64> = Vec::new();
        for _rep in 0..reps {
            let mut rounds = Vec::new();
            let mut half = cap / start_div;
            while half >= 1 {
                let nthreads = half.clamp(1, 1 << 17);
                let args = RoundArgs { half: half as u64, cap: cap as u64, eval_one, nthreads: nthreads as u32 };
                let cmd = q.new_command_buffer();
                let enc = cmd.new_compute_command_encoder();
                enc.set_compute_pipeline_state(&pipe);
                enc.set_buffer(0, Some(&tb), 0);
                enc.set_buffer(1, Some(&part), 0);
                enc.set_buffer(2, Some(&cb_), 0);
                enc.set_bytes(3, std::mem::size_of::<RoundArgs>() as u64, &args as *const RoundArgs as *const _);
                let grid = (nthreads.div_ceil(32) * 32 * np) as u64;
                let tg = pipe.max_total_threads_per_threadgroup().min(64).min(grid);
                enc.dispatch_threads(MTLSize::new(grid, 1, 1), MTLSize::new(tg, 1, 1));
                enc.end_encoding();
                cmd.commit();
                cmd.wait_until_completed();
                let (g0, g1) = gpu_times(cmd);
                rounds.push(g1 - g0);
                half /= 2;
            }
            let total: f64 = rounds.iter().sum();
            if total < best {
                best = total;
                best_rounds = rounds;
            }
        }
        let r: Vec<String> = best_rounds.iter().take(5).map(|x| format!("{:.4}", x)).collect();
        println!("{name:<10} np {np}: rounds from cap/{start_div}: {best:.4} s GPU (first {} | rest {:.4}) regs/tg max {}", r.join(" "), best_rounds.iter().skip(5).sum::<f64>(), pipe.max_total_threads_per_threadgroup());
    }
}
