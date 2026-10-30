//! True-axis scalar checks, directly importing frozen R13 arithmetic modules.
//! This does not implement split private-block layouts, endpoints or wire receipts.
#![allow(dead_code)]
#[path="../r13/frozen-tree/hashline/src/private_block/accuracy.rs"] mod accuracy;
#[path="../r13/frozen-tree/hashline/src/private_block/accuracy_tables.rs"] mod accuracy_tables;
#[path="../r13/frozen-tree/hashline/src/private_block/accuracy_groups.rs"] mod accuracy_groups;
#[path="../r13/frozen-tree/hashline/src/private_block/accuracy_precision.rs"] mod accuracy_precision;
#[path="../r13/frozen-tree/hashline/src/private_block/accuracy_aligned.rs"] mod accuracy_aligned;
use accuracy::requant;
use accuracy_groups::Group;
use accuracy_precision::Stack;
use accuracy_tables::Registry;

fn cm(site:usize,j:usize,bits:u32)->u64 { ((j/3+j%7+site*11)%(1usize<<bits)+1) as u64 }
fn gid(j:usize)->usize {(j/37+j%5)%4}
fn weight(site:usize,i:usize,j:usize)->i128 {((i*17+j*31+i*j%13+site*11)%255) as i128-127}
fn input(t:usize,i:usize)->i128 {((i*23+t*7)%15) as i128-7}
fn isqrt(n:u128)->u128 { if n<2{return n;} let mut x=n;let mut y=(x+1)/2;while y<x {x=y;y=(x+n/x)/2;}x }
fn main() {
    let groups=[Group{e_in:-4,e_out:-13},Group{e_in:-3,e_out:-12},Group{e_in:-1,e_out:-9},Group{e_in:0,e_out:-8}];
    let ids=(0..9216).map(gid).collect::<Vec<_>>();let gate=(0..9216).map(|j|cm(4,j,6)).collect::<Vec<_>>();
    let a=accuracy_aligned::derive_aligned_for(Registry::Shieldstral,Stack::LowH24,&groups,&ids,&gate,-3,-11,8,15).unwrap();
    let mut exact=0;let mut bad_c2=0;let mut bad_group=0;let mut rounding=0;let mut mapped=0;
    for (width,cut) in [(3072,2048),(9216,8192)] {
        let mut seen=vec![false;width];
        for global in 0..width {
            let(piece,local)=if global<cut {(0,global)}else{(1,global-cut)};
            let reconstructed=if piece==0 {local}else{cut+local};
            assert_eq!(global,reconstructed);assert!(!seen[reconstructed]);seen[reconstructed]=true;mapped+=1;
        }
        assert!(seen.into_iter().all(|x|x));
    }
    // Site, input width, optional inner cut, output width/cut, c2 bits, shift.
    // Q/K/V are output-row matrices; gate/up/down use output columns. Both
    // orientations compute the same explicitly indexed global scalar here.
    for (site,inner,inner_cut,outputs,out_cut,bits,shift) in [
        (0,3072,2048,4096,4096,5,15),(1,3072,2048,1024,1024,5,15),
        (2,3072,2048,1024,1024,6,16),(3,4096,4096,3072,2048,8,21),
        (4,3072,2048,9216,8192,6,a.folds.gate.shift),(5,3072,2048,9216,8192,4,12),
        (6,9216,8192,3072,2048,6,20)] {
        let mut channels=vec![0,1,outputs-2,outputs-1];
        if out_cut<outputs {channels.extend([out_cut-2,out_cut-1,out_cut,out_cut+1,out_cut+7,out_cut+31]);}
        channels.sort_unstable();channels.dedup();
        for t in 0..2 {for &j in &channels {
            let unsplit=(0..inner).map(|i|input(t,i)*weight(site,i,j)).sum::<i128>();
            let p0=(0..inner_cut).map(|i|input(t,i)*weight(site,i,j)).sum::<i128>();
            let p1=(inner_cut..inner).map(|i|input(t,i)*weight(site,i,j)).sum::<i128>();
            assert_eq!(unsplit,p0+p1);
            let m=if site==4 {a.folds.gate.multipliers[j]}else{cm(site,j,bits)};
            let honest=requant(unsplit,m,shift).unwrap();let split=requant(p0+p1,m,shift).unwrap();assert_eq!(honest,split);
            // Independent Euclidean division reference, including the remainder.
            let numerator=unsplit*m as i128+(1i128<<(shift-1));let denom=1i128<<shift;
            assert_eq!(honest.word as i128,numerator.div_euclid(denom));assert_eq!(honest.remainder as i128,numerator.rem_euclid(denom));exact+=1;
            if j>=out_cut {
                let local=j-out_cut;let wrong=if site==4 {a.folds.gate.multipliers[local]}else{cm(site,local,bits)};
                if wrong!=m && unsplit!=0 {assert_ne!(requant(unsplit,wrong,shift).unwrap(),honest);bad_c2+=1;}
            }
        }}
        if inner_cut<inner {
            // Same legal shift, with a minimal counterexample to rounding partials.
            let x=1i128<<(shift-1);
            let joint=requant(x+x,1,shift).unwrap().word;
            let separately=requant(x,1,shift).unwrap().word*2;
            assert_eq!(joint,1);assert_eq!(separately,2);rounding+=1;
        }
    }
    // The F1 local index never selects group metadata. Use boundary channels
    // with differing global and incorrectly reset IDs; validate actual native
    // scaled tables and the single H24 product rounding.
    for j in 8192..9216 {
        let wrong=gid(j-8192);let correct=ids[j];if wrong==correct{continue;}
        let gate_word=57+(j%43) as i64;let up=1234i128;
        let good=a.tables[correct][(gate_word+2048) as usize];let bad=a.tables[wrong][(gate_word+2048) as usize];
        if good==bad{continue;}
        assert_ne!(requant(good as i128*up,1,16).unwrap(),requant(bad as i128*up,1,16).unwrap());bad_group+=1;
    }
    assert!(bad_c2>=8&&bad_group>=128);assert_eq!(mapped,12288);
    // A common row denominator must be derived from the complete true row.
    let s0=2048u128;let s1=1024u128*4;let sigma=isqrt(s0+s1);
    assert_eq!(sigma,78);assert_ne!(isqrt(s0),sigma);assert_ne!(isqrt(s1),sigma);
    assert_ne!(isqrt(s0)+isqrt(s1),sigma);
    println!("{{\"native_scalar_piece_equivalences\":{exact},\"true_axis_words_mapped_bijectively\":{mapped},\"wrong_global_c2_counterexamples\":{bad_c2},\"wrong_global_group_counterexamples\":{bad_group},\"per_piece_rounding_counterexamples\":{rounding},\"shared_norm_denominator_counterexamples\":3,\"scope\":\"isolated native scalar arithmetic and global-index checks, not a full split block or proof\"}}");
}
