// cost of a fresh shared Metal buffer: allocation, first CPU touch (parallel), a second touch, reuse
use metal::*;
use rayon::prelude::*;
use std::time::Instant;
fn main() {
    let dev = Device::system_default().unwrap();
    for &mb in &[537usize, 973, 2400] {
        let bytes = (mb as u64) << 20;
        for rep in 0..2 {
            let t = Instant::now();
            let b = dev.new_buffer(bytes, MTLResourceOptions::StorageModeShared);
            let ta = t.elapsed().as_secs_f64();
            let n = (bytes / 8) as usize;
            let s = unsafe { std::slice::from_raw_parts_mut(b.contents() as *mut u64, n) };
            let t = Instant::now();
            s.par_chunks_mut(1 << 17).for_each(|c| for x in c.iter_mut() { *x = 7; });
            let t1 = t.elapsed().as_secs_f64();
            let t = Instant::now();
            s.par_chunks_mut(1 << 17).for_each(|c| for x in c.iter_mut() { *x = 9; });
            let t2 = t.elapsed().as_secs_f64();
            let t = Instant::now();
            drop(b);
            let td = t.elapsed().as_secs_f64();
            println!("{mb} MB rep {rep}: new_buffer {ta:.4} s | first parallel write {t1:.4} s | second {t2:.4} s | drop {td:.4} s");
        }
    }
}
