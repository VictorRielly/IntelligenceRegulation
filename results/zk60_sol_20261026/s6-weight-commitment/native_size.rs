//! Count the native public PCS Opening layout, not an S6 proof.
use hashline::field::{Fp,Fp2};
use hashline::pcs::Opening;
fn main() {
    let args=std::env::args().skip(1).map(|s|s.parse::<usize>().unwrap()).collect::<Vec<_>>();
    assert_eq!(args.len(),3);let(log_n,rows,groups)=(args[0],args[1],args[2]);
    let n=1usize<<log_n;let q=256;let depth=log_n+2;
    let op=Opening{group_vecs:vec![vec![Fp2::ZERO;n];groups],prox_vec:vec![Fp2::ZERO;n],
        columns:(0..q).map(|j|(j,vec![Fp::ZERO;rows],vec![[0u8;32];depth])).collect()};
    let formula=(groups+1)*n*16+q*(8+rows*8+depth*32);
    assert_eq!(op.size_bytes(),formula);
    let mut encoded=Vec::with_capacity(formula);op.write_bytes(&mut encoded);assert_eq!(encoded.len(),formula);
    println!("{{\"log_cols\":{log_n},\"rows\":{rows},\"groups\":{groups},\"native_size_bytes\":{formula},\"wire_bytes_match\":true,\"scope\":\"COUNTED empty native Opening structure size only; not an S6 proof\"}}");
}
