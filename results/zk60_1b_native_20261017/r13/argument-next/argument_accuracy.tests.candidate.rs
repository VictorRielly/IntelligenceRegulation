#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_public::{AccuracyPublic,Geometry,Multipliers};
    use crate::private_block::accuracy_tables::silu_table;
    use crate::private_block::shape::{Shape,NormCalibration};

    fn case(mut sh:Shape,ng:usize)->(Shape,AccuracyPublic,crate::private_block::AttentionPublic,crate::private_block::FeedForwardPublic) {
        let geometry=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
        let sequence=|n,max| (0..n).map(|i|1+(i%max) as u16).collect();
        let m=Multipliers{q:sequence(geometry.query_width,32),k:sequence(geometry.kv_width,32),
            v:sequence(geometry.kv_width,64),o:sequence(geometry.width,256),
            g:sequence(geometry.hidden,64),u:sequence(geometry.hidden,16),d:sequence(geometry.width,64)};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-3,e_out:-12},Group{e_in:-2,e_out:-11},Group{e_in:-1,e_out:-9}][..ng].to_vec();
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let data=AccuracyPublic::new(sh.accuracy_stack(),geometry,sh.accuracy_base(),(-3,-11),m,groups,
            (0..geometry.hidden).map(|i|i%ng).collect(),tables).unwrap();
        sh=sh.with_accuracy_gate_shift(data.folds().gate.shift).unwrap();
        let (public,ff,_)=crate::private_block::grow_tests::tame_case(&sh);
        (sh,data,public,ff)
    }

    fn visit(sh:&Shape,data:&AccuracyPublic,public:&crate::private_block::AttentionPublic,ff:&crate::private_block::FeedForwardPublic,mut f:impl FnMut(SlotDef)) {
        let lay=crate::private_block::layout::Layout::for_shape(sh).unwrap();
        let ctx=Ctx{accuracy:Some(data),lay:&lay,public,ff,alpha:k(7).add(Fp2::U),beta:k(11),g_u8:k(13),g_exp:k(17),g_act:k(19),g_dd:k(23)};
        let mut pts=Points::default();let mut tr=Transcript::new(sh.profile.as_bytes());
        for slot in 0..sh.n_slots() {
            f(define(slot,&ctx,&mut pts,&mut tr).unwrap_or_else(|e|panic!("{} slot{slot}: {e}",sh.name)));
        }
    }

    fn development_shapes()->Vec<Shape> {
        crate::private_block::accuracy_profile_tests::registered_shapes().into_iter().filter(|s|s.tokens==32).collect()
    }

    #[test]
    fn accuracy_native_definitions_match_claim_schedules_for_both_stacks_dd_and_all_group_counts() {
        let mut definitions=0;
        for sh in development_shapes() {for ng in 1..=4 {
            let(sh,data,public,ff)=case(sh.clone(),ng);let(a,h)=sh.claim_sites();
            visit(&sh,&data,&public,&ff,|def| {
                let n=sh.slots()[def.slot].0;let mut counts=[0;4];let mut masks=std::collections::HashSet::new();
                for tab in &def.tabs {match tab {
                    Tab::Eq{point,start}=>assert!(start+point.len()<=n),
                    Tab::Pub(values)=>assert_eq!(values.len(),1usize<<n,"{} slot{} public support",sh.name,def.slot),
                    Tab::Priv(p)=>{
                        counts[p.cm as usize]+=1;
                        assert_eq!(p.coords.len(),p.log);
                        assert!(masks.insert((p.cm as usize,p.mask_row)),"a private claim reuses a mask pair");
                        for c in &p.coords {if let Coord::Rho(i)|Coord::Flip(i)=c {assert!(*i<n);}}
                    },
                }}
                assert_eq!((counts[0],counts[1]),(a[def.slot],h[def.slot]));
                assert_eq!(def.hosted.iter().map(|(s,_)|*s).collect::<Vec<_>>(),
                    HOSTS.iter().find(|(s,_)|*s==def.slot).map(|(_,slots)|slots.to_vec()).unwrap_or_default());
                definitions+=1;
            });
        }}
        assert_eq!(definitions,8*(23+24));
    }

    #[test]
    fn accuracy_native_polynomials_obey_declared_degree_and_extension_zero_property() {
        for sh in development_shapes() {
            let(sh,data,public,ff)=case(sh,4);
            visit(&sh,&data,&public,&ff,|def| {
                let(_,extensions,degree)=sh.slots()[def.slot];
                for seed in [3i64,17,71] {
                    for round in 0..extensions {
                        let values:Vec<_>=def.tabs.iter().enumerate().map(|(i,t)|match t {
                            Tab::Priv(p) if p.ext_round==round=>k(seed+13*i as i64).add(Fp2::U.mul(k(i as i64+1))),
                            _=>Fp2::ZERO,
                        }).collect();
                        assert_eq!((def.poly)(&values),Fp2::ZERO,"{} slot{} extension{round}",sh.name,def.slot);
                    }
                    let mut line:Vec<_>=(0..degree+2).map(|t| {
                        let values:Vec<_>=(0..def.tabs.len()).map(|i|k(seed+7*i as i64).add(k(t as i64).mul(k(11+3*i as i64).add(Fp2::U)))).collect();
                        (def.poly)(&values)
                    }).collect();
                    for _ in 0..=degree {line=line.windows(2).map(|w|w[1].sub(w[0])).collect();}
                    assert_eq!(line,vec![Fp2::ZERO],"{} slot{} exceeds declared degree{degree}",sh.name,def.slot);
                }
            });
        }
    }
}
