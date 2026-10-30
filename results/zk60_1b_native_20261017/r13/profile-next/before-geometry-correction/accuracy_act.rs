//! Verifier-derived public columns for R13's three-coordinate ACT lookup.
use super::accuracy_public::{AccuracyPublic,Geometry};
use super::layout::Dom;
use super::shape::Shape;
use crate::field::Fp2;

pub(crate) struct ActTable {
    pub(crate) compressed:Vec<Fp2>,
    pub(crate) support:Vec<Fp2>,
    pub(crate) entries:usize,
}

pub(crate) fn table(a:&AccuracyPublic,len:usize,beta:Fp2,tag:Fp2)->Result<ActTable,String> {
    let entries=a.groups().len().checked_mul(4096).ok_or("R13 ACT: table size overflow")?;
    if !len.is_power_of_two() || !(4096..=16384).contains(&entries) || entries>len {
        return Err("R13 ACT: one to four registered tables must fit in exactly one row".into());
    }
    let beta2=beta.mul(beta);
    let zero=Fp2::from_i64(2048).add(tag);
    let mut compressed=vec![zero;len];let mut support=vec![Fp2::ZERO;len];
    for (group,words) in a.scaled_tables().iter().enumerate() {
        if words.len()!=4096 || words[2048]!=0 {return Err("R13 ACT: invalid generated table shape/zero row".into());}
        let group_term=beta2.mul(Fp2::from_i64(group as i64));
        for (gate,&word) in words.iter().enumerate() {
            let i=group*4096+gate;
            compressed[i]=Fp2::from_i64(gate as i64).add(beta.mul(Fp2::from_i64(word))).add(group_term).add(tag);
            support[i]=Fp2::ONE;
        }
    }
    Ok(ActTable{compressed,support,entries})
}

pub(crate) fn group_column(sh:&Shape,a:&AccuracyPublic)->Result<Vec<Fp2>,String> {
    let geometry=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    if geometry!=a.geometry() {return Err("R13 ACT: geometry context mismatch".into());}
    let mut out=vec![Fp2::ZERO;sh.size(Dom::F)];
    for t in 0..sh.tokens {for j in 0..sh.hidden {
        out[t*sh.f_pad+j]=Fp2::from_i64(a.group_ids()[j] as i64);
    }}
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_precision::{Stack,BaseShifts};
    use crate::private_block::accuracy_public::Multipliers;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_tables::silu_table;

    fn fixture()->(Shape,AccuracyPublic) {
        let sh=Shape::new("R13 ACT pad fixture","r13-act-pad-fixture",24,48,6,6,8,2,8,8,9,13,None,None,None,None).unwrap();
        let m=Multipliers{q:vec![1;48],k:vec![1;16],v:vec![1;16],o:vec![1;48],g:vec![1;6],u:vec![1;6],d:vec![1;48]};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-1,e_out:-11}];
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let a=AccuracyPublic::new(Stack::LowH24,Geometry{width:48,query_width:48,kv_width:16,hidden:6},
            BaseShifts{norm_tn:10,qkv:8,score:6,pv:9,ao:7,gate:8,up:0,product:14,down:6},
            (-3,-11),m,groups,vec![0,1,0,1,0,1],tables).unwrap();
        (sh,a)
    }

    #[test]
    fn every_three_coordinate_row_matches_its_generated_scaled_table() {
        let (_,a)=fixture();let beta=Fp2::from_i64(7);let tag=Fp2::from_i64(31);
        let table=table(&a,16384,beta,tag).unwrap();
        assert_eq!(table.entries,8192);
        for group in 0..2 {for index in 0..4096 {
            let expected=Fp2::from_i64(index as i64).add(beta.mul(Fp2::from_i64(a.scaled_tables()[group][index])))
                .add(beta.mul(beta).mul(Fp2::from_i64(group as i64))).add(tag);
            assert_eq!(table.compressed[group*4096+index],expected);
        }}
        assert!(table.support[..8192].iter().all(|&v|v==Fp2::ONE));
        assert!(table.support[8192..].iter().all(|&v|v==Fp2::ZERO));
        assert!(table.compressed[8192..].iter().all(|&v|v==Fp2::from_i64(2048).add(tag)));
        // The ACT-specific support covers entries above 255, while its own
        // zero padding still starts exactly at groups*4096.
        assert_eq!(table.support[256],Fp2::ONE);
    }

    #[test]
    fn group_coordinate_separates_colliding_gate_zero_outputs() {
        let (_,a)=fixture();let beta=Fp2::from_i64(7);
        let t=table(&a,8192,beta,Fp2::ZERO).unwrap();
        assert_eq!(a.scaled_tables()[0][2048],a.scaled_tables()[1][2048]);
        assert_ne!(t.compressed[2048],t.compressed[4096+2048]);
        assert_eq!(t.compressed[4096+2048].sub(t.compressed[2048]),beta.mul(beta));
    }

    #[test]
    fn query_group_padding_is_the_valid_zero_gate_zero_output_group_zero_row() {
        let (sh,a)=fixture();let column=group_column(&sh,&a).unwrap();
        assert_eq!(column.len(),sh.size(Dom::F));
        for t in 0..sh.t_pad {for j in 0..sh.f_pad {
            let expected=if t<sh.tokens && j<sh.hidden {a.group_ids()[j]} else {0};
            assert_eq!(column[t*sh.f_pad+j],Fp2::from_i64(expected as i64));
        }}
        let t=table(&a,16384,Fp2::from_i64(7),Fp2::from_i64(31)).unwrap();
        assert_eq!(t.compressed[2048],t.compressed[t.entries]);
        assert!(table(&a,4096,Fp2::ONE,Fp2::ZERO).is_err());
        assert!(table(&a,8193,Fp2::ONE,Fp2::ZERO).is_err());
    }
}
