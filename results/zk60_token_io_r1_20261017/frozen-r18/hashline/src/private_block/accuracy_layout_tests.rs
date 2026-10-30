use crate::private_block::accuracy_layout::{AccuracyIds,Limbs};
use crate::private_block::accuracy_precision::{derive,BaseShifts,Stack};
use crate::private_block::layout::*;

const BASE:BaseShifts=BaseShifts{norm_tn:10,qkv:8,score:6,pv:9,ao:7,gate:8,up:0,product:14,down:6};

fn dom(name:&str)->Dom {match name {"T"=>Dom::T,"Ht"=>Dom::Ht,"L"=>Dom::L,"D"=>Dom::D,"Q"=>Dom::Q,
    "Kv"=>Dom::Kv,"S"=>Dom::S,"F"=>Dom::F,"Tab"=>Dom::Tab,"Dd"=>Dom::Dd,_=>panic!("unknown domain")}}

#[test]
fn every_allocated_role_and_lookup_count_matches_the_independent_inventory() {
    let mut checked=0;
    for row in include_str!("r13_vectors/roles.tsv").lines() {
        let v:Vec<_>=row.split('\t').collect();
        let stack=if v[0]=="low" {Stack::Low} else {Stack::LowH24};
        let dd=v[1]=="1"; let ls:usize=v[2].parse().unwrap(); let d=dom(v[3]);
        let ids=AccuracyIds::new(stack,dd,ls).unwrap();
        let roles:Vec<_>=ids.names.iter().zip(&ids.doms).filter(|(_,pd)| **pd==d).map(|(n,_)| n.as_str()).collect();
        assert_eq!(roles.join(","),v[4],"{row}");
        let precision=derive(stack,BASE).unwrap();
        let lookups=ids.lookups(d,&precision,18,if ls==2 {16} else {17}).unwrap();
        assert_eq!(lookups.len(),v[5].parse::<usize>().unwrap(),"{row}");
        assert_eq!(ids.map[A_X2],v[6].parse::<usize>().unwrap());
        checked+=1;
    }
    assert_eq!(checked,76);
}

#[test]
fn removed_norm_limbs_are_absent_and_every_other_legacy_role_is_unique() {
    for stack in [Stack::Low,Stack::LowH24] {for dd in [false,true] {for ls in [2,3] {
        let ids=AccuracyIds::new(stack,dd,ls).unwrap();
        let absent=[A_NR0+3,A_NS0+3,A_MR0+3,A_MS0+3];
        for i in absent {assert_eq!(ids.map[i],usize::MAX);}
        let mut present:Vec<_>=ids.map.iter().copied().filter(|&p| p!=usize::MAX).collect();
        let n=present.len();present.sort();present.dedup();assert_eq!(present.len(),n);
        assert_eq!(n,N_A-4);
        for group in [Limbs::Nr,Limbs::Ns,Limbs::Mr,Limbs::Ms] {assert_eq!(ids.count(group),3);}
        assert_ne!(ids.map[A_X2],A_X2);
        assert_eq!(ids.names[ids.map[A_X2]],"X2");
        if dd {assert_eq!(ids.names[ids.pdict],"PDICT");assert_eq!(ids.names[ids.mdd],"MDD");}
    }}}
}

#[test]
fn every_remainder_top_pin_enforces_its_exact_window_including_full_bytes() {
    for stack in [Stack::Low,Stack::LowH24] {for dd in [false,true] {for ls in [2,3] {
        let ids=AccuracyIds::new(stack,dd,ls).unwrap(); let p=derive(stack,BASE).unwrap();
        let wrho=if ls==2 {16} else {24};
        for (group,d,bits) in [(Limbs::Rq,Dom::Q,p.q),(Limbs::Rk,Dom::Kv,p.k),(Limbs::Rv,Dom::Kv,p.v),
            (Limbs::Rqr,Dom::Q,SH_ROPE),(Limbs::Rkr,Dom::Kv,SH_ROPE),(Limbs::Ro,Dom::Q,p.pv),
            (Limbs::Rao,Dom::D,p.ao),(Limbs::Rd,Dom::D,p.down),(Limbs::Rs,Dom::S,p.score),
            (Limbs::Rg,Dom::F,18),(Limbs::Ru,Dom::F,p.up),
            (Limbs::P,if dd {Dom::Dd} else {Dom::S},p.f_p+1),
            (Limbs::Sr,if dd {Dom::Dd} else {Dom::S},wrho),(Limbs::Sg,if dd {Dom::Dd} else {Dom::S},wrho)] {
            let lookups=ids.lookups(d,&p,18,wrho).unwrap();
            let n=ids.count(group); let top=ids.limb(group,n-1); let factor=1i64<<(8*n as u32-bits);
            assert!(lookups.iter().any(|l| l.cst==0 && l.terms==vec![(top,factor)]));
            for word in [0u64,(1u64<<bits)-1,1u64<<bits] {
                let reconstructed:u64=(0..n).map(|k| ((word>>(8*k))&255)<<(8*k)).sum();
                let accepted=reconstructed==word
                    && (0..n).all(|k| ((word>>(8*k))&255)<256)
                    && (((word>>(8*(n-1)))&255) as i64)*factor<256;
                assert_eq!(accepted,word<(1u64<<bits),"{group:?} word {word} bits {bits}");
            }
        }
    }}}
}

#[test]
fn malformed_lookup_context_is_refused_before_any_lookup_is_used() {
    assert!(AccuracyIds::new(Stack::Legacy,false,2).is_err());
    assert!(AccuracyIds::new(Stack::Low,false,1).is_err());
    let ids=AccuracyIds::new(Stack::Low,false,2).unwrap(); let p=derive(Stack::Low,BASE).unwrap();
    assert!(ids.lookups(Dom::D,&p,18,17).is_err());
    assert!(ids.lookups(Dom::F,&p,16,16).is_err());
    let mut wrong=p; wrong.f_p=9; assert!(ids.lookups(Dom::S,&wrong,18,16).is_err());
    let mut wrong=p; wrong.stack=Stack::Legacy; assert!(ids.lookups(Dom::Q,&wrong,18,16).is_err());
}
