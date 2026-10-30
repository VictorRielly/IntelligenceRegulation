fn offsets(sh:&Shape)->(Vec<usize>,usize){
let a_doms=sh.a_plane_doms();let n=1usize<<sh.log_cols;let mut row=0usize;
        let mut a_off = Vec::with_capacity(a_doms.len());
        for d in &a_doms {
            a_off.push(row * n);
            row += sh.rows_of(*d);
        }
        let a_data_rows = row;
(a_off,a_data_rows)
}
