#![allow(dead_code)]
#[path="../working-tree/hashline/src/private_block/accuracy.rs"] mod accuracy;
#[path="../working-tree/hashline/src/private_block/accuracy_precision.rs"] mod accuracy_precision;
#[path="accuracy_tables.green.rs"] mod accuracy_tables;
#[path="accuracy_groups.green.rs"] mod accuracy_groups;
#[path="accuracy_aligned.green.rs"] mod accuracy_aligned;

#[test]
fn both_shieldstral_stacks_match_2016_independent_fraction_vectors() {
    use accuracy_precision::Stack;
    use accuracy_tables::{Registry, SILU_MEMBERS};
    use accuracy_groups::Group;
    let members:Vec<_>=SILU_MEMBERS.into_iter().chain([(0,-8)]).collect();
    let mut count=0;
    for row in include_str!("../shieldstral_product_vectors.tsv").lines() {
        if row.starts_with("stack") {continue}
        let v:Vec<_>=row.split('\t').collect();
        let stack=match v[0] {"low"=>Stack::Low,"low-h24"=>Stack::LowH24,other=>panic!("{other}")};
        let base_h:u32=v[1].parse().unwrap();
        let delta:i32=v[2].parse().unwrap();
        let base=if delta>=0 {(-5,-13)} else {(0,-8)};
        let member=*members.iter().find(|m| m.1==base.1+delta).unwrap();
        let aligned=accuracy_aligned::derive_aligned_for(Registry::Shieldstral,stack,&[Group{e_in:member.0,e_out:member.1}],&[0],&[1],base.0,base.1,8,base_h).unwrap();
        let exponent:u32=v[3].parse().unwrap();
        assert_eq!(aligned.folds.product.multipliers[0],1<<exponent);
        let a:i128=v[4].parse().unwrap(); let up:i128=v[5].parse().unwrap(); let expected:i64=v[6].parse().unwrap();
        let rounded=accuracy::requant(a*up,1<<exponent,aligned.folds.product.shift).unwrap();
        assert_eq!(rounded.word,expected,"{row}");
        count+=1;
    }
    assert_eq!(count,2016);
}

#[test]
fn shieldstral_actual_l25_four_groups_fit_and_standard_refuses_them() {
    use accuracy_groups::Group;
    use accuracy_tables::Registry;
    let groups=[Group{e_in:-3,e_out:-11},Group{e_in:-2,e_out:-11},Group{e_in:-1,e_out:-9},Group{e_in:0,e_out:-8}];
    let a=accuracy_aligned::derive_aligned_for(Registry::Shieldstral,accuracy_precision::Stack::LowH24,&groups,&[0,1,2,3],&[1;4],-1,-9,8,15).unwrap();
    assert_eq!(a.tables.len()*4096,16384);
    assert_eq!(a.folds.product.multipliers,vec![128,128,512,1024]);
    assert!(accuracy_aligned::derive_aligned(accuracy_precision::Stack::LowH24,&groups,&[0,1,2,3],&[1;4],-1,-9,8,15).is_err());
}

#[test]
fn zero_direct_shift_preserves_negative_values_exactly() {
    use accuracy_tables::Registry;
    let g=[accuracy_groups::Group{e_in:0,e_out:-8}];
    let folded=accuracy_groups::group_folds_for(Registry::Shieldstral,&g,&[0],&[1],-5,-13,8,13).unwrap();
    assert_eq!(folded.product.shift,1);
    assert_eq!(folded.product.multipliers,vec![2]);
    for n in [-100000i128,-3,-1,0,1,3,100000] {assert_eq!(accuracy::requant(n,2,1).unwrap().word,n as i64);}
}
