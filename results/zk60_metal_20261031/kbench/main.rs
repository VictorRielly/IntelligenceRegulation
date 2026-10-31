// time variants of one slot's extension-round kernel on random extension tables
use metal::*;
use std::time::Instant;

#[repr(C)]
struct RoundArgs { half: u64, cap: u64, eval_one: u32, nthreads: u32 }

const P: u64 = 0xFFFF_FFFF_0000_0001;
fn add(a: u64, b: u64) -> u64 { let (r, c) = a.overflowing_add(b); let r = if c { r.wrapping_add(0xFFFF_FFFF) } else { r }; if r >= P { r - P } else { r } }

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let src = std::fs::read_to_string(&a[1]).unwrap();
    let k: usize = a[2].parse().unwrap();
    let d1: usize = a[3].parse::<usize>().unwrap() + 1;
    let log_cap: u32 = a[4].parse().unwrap();
    let names: Vec<&str> = a[5].split(',').collect();
    let per: usize = a.get(6).map(|v| v.parse().unwrap()).unwrap_or(4);
    let cap_log: u32 = a.get(7).map(|v| v.parse().unwrap()).unwrap_or(15);
    let tgmax: u64 = a.get(8).map(|v| v.parse().unwrap()).unwrap_or(256);
    let eval_one: u32 = a.get(9).map(|v| v.parse().unwrap()).unwrap_or(1);
    let cap = 1usize << log_cap;
    let dev = Device::system_default().unwrap();
    let t = Instant::now();
    let lib = dev.new_library_with_source(&src, &CompileOptions::new()).unwrap();
    println!("compile {:.2} s", t.elapsed().as_secs_f64());
    let q = dev.new_command_queue();
    let mut s = 0x9e37_79b9_7f4a_7c15u64;
    let mut rnd = move || { s ^= s << 13; s ^= s >> 7; s ^= s << 17; s % P };
    let tabs: Vec<u64> = (0..k * cap * 2).map(|_| rnd()).collect();
    let cf: Vec<u64> = (0..4096).map(|_| rnd()).collect();
    let tb = dev.new_buffer_with_data(tabs.as_ptr() as *const _, (tabs.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
    let cb_ = dev.new_buffer_with_data(cf.as_ptr() as *const _, (cf.len() * 8) as u64, MTLResourceOptions::StorageModeShared);
    // the rounds of one sumcheck from round 1 on: half = cap/4, cap/8, ... (the buffer keeps stride cap)
    for name in names {
        let f = lib.get_function(name, None).unwrap();
        let pipe = dev.new_compute_pipeline_state_with_function(&f).unwrap();
        let mut best = f64::MAX;
        let mut best_rounds: Vec<f64> = Vec::new();
        let mut sums = vec![0u64; d1 * 2];
        // [M4g] one partials buffer for every round (a fresh buffer's first touch is slow here)
        let part = dev.new_buffer(((cap / 4).max(1) * d1 * 16) as u64, MTLResourceOptions::StorageModeShared);
        for _rep in 0..3 {
        let mut total = 0.0;
        let mut rounds: Vec<f64> = Vec::new();
        sums = vec![0u64; d1 * 2];
        let mut half = cap / 4;
        while half >= 1 {
            let nthreads = (half / per).clamp(1, 1 << cap_log);
            let args = RoundArgs { half: half as u64, cap: cap as u64, eval_one, nthreads: nthreads as u32 };
            let cmd = q.new_command_buffer();
            let enc = cmd.new_compute_command_encoder();
            enc.set_compute_pipeline_state(&pipe);
            enc.set_buffer(0, Some(&tb), 0);
            enc.set_buffer(1, Some(&part), 0);
            enc.set_buffer(2, Some(&cb_), 0);
            enc.set_bytes(3, std::mem::size_of::<RoundArgs>() as u64, &args as *const RoundArgs as *const _);
            // E/F kernels: one thread per (stride, point)
            let np = if eval_one != 0 { d1 } else { d1 - 1 };
            let grid = if name.starts_with("k_vE") || name.starts_with("k_vF") || name == "k_vL" { (nthreads * d1) as u64 }
                else if name.starts_with("k_vG") || name.starts_with("k_vH") || name == "k_vLG" { (nthreads.div_ceil(32) * 32 * np) as u64 }
                else { nthreads as u64 };
            let tg = pipe.max_total_threads_per_threadgroup().min(tgmax).min(grid);
            enc.dispatch_threads(MTLSize::new(grid, 1, 1), MTLSize::new(tg, 1, 1));
            enc.end_encoding();
            let t = Instant::now();
            cmd.commit();
            cmd.wait_until_completed();
            let e = t.elapsed().as_secs_f64();
            total += e;
            rounds.push(e);
            let p = unsafe { std::slice::from_raw_parts(part.contents() as *const u64, nthreads * d1 * 2) };
            for th in p.chunks_exact(d1 * 2) { for j in 0..d1 * 2 { if eval_one != 0 || j / 2 != 1 { sums[j] = add(sums[j], th[j]); } } }
            half /= 2;
        }
        if total < best { best = total; best_rounds = rounds; }
        }
        let total = best;
        let r: Vec<String> = best_rounds.iter().take(6).map(|x| format!("{:.4}", x)).collect();
        println!("  first rounds {} | rest {:.4}", r.join(" "), best_rounds.iter().skip(6).sum::<f64>());
        println!("{name} per {per} cap 2^{cap_log} tg {tgmax}: rounds 1.. {:.4} s  max threads/group {}  eval_one {eval_one} sums {:016x} {:016x}", total, pipe.max_total_threads_per_threadgroup(), sums[0], sums[d1 * 2 - 1]);
    }
}
