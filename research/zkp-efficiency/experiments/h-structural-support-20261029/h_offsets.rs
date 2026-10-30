fn offsets(sh:&Shape)->(Vec<(usize,usize)>,usize){
let h_doms=sh.h_plane_doms();let n=1usize<<sh.log_cols;
        let mut row = 0usize;
        let mut h_off = Vec::with_capacity(h_doms.len());
        for d in &h_doms {
            let r = sh.rows_of(*d);
            h_off.push((row * n, (row + r) * n));
            row += 2 * r;
        }
        let h_data_rows = row;
(h_off,h_data_rows)
}
