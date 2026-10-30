    #[test]
    fn both_accuracy_stacks_assign_all_words_to_distinct_native_planes_and_recover_the_output() {
        use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
        for stack in [Stack::Low,Stack::LowH24] {
            let (sh,public,ff,data,input)=fixture(stack);
            let trace=build(&sh,&public,&ff,&data,&input).unwrap();
            let expected=trace.x2.clone();
            let mut witness=assign(&sh,&public,&data,trace).unwrap();
            let ids=AccuracyIds::new(stack,false,sh.limbs_sigma_s()).unwrap();
            let g=Geom::new(&sh);
            for (old,role,bias) in [(A_X,L::X,32768),(A_Y,L::Y,32768),(A_YM,L::Ym,32768),(A_Q8,L::Q,32768),
                (A_K8,L::K,32768),(A_V8,L::V,32768),(A_QR8,L::Qr,32768),(A_KR8,L::Kr,32768),
                (A_O8,L::O,32768),(A_AO,L::Ao,32768),(A_X1,L::X1,32768),(A_U16,L::Up,32768),
                (A_H16,L::H,1i64<<(data.precision().product_bits-1)),(A_Z16,L::Z,32768),(A_X2,L::X2,32768)] {
                for i in g.support(ids.doms[ids.map[old]]) {
                    let reconstructed:i64=(0..ids.count(role)).map(|k|witness.planes[ids.limb(role,k)][i]<<(8*k)).sum();
                    assert_eq!(witness.planes[ids.map[old]][i]+bias,reconstructed,"{role:?}[{i}]");
                }
            }
            for dom in [Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F] {
                let lookups=ids.lookups(dom,data.precision(),data.folds().gate.shift,sh.wrho_s).unwrap();
                for lk in lookups {for i in 0..g.len(dom) {
                    let value=lk.terms.iter().fold(lk.cst,|s,&(p,c)|s+c*witness.planes[p][i]);
                    assert!((0..256).contains(&value),"{dom:?} position {i}");
                }}
            }
            for &old in &[A_MU8,A_MEXP,A_MACT] {assert!(witness.planes[ids.map[old]].is_empty());}
            assert_eq!(witness.output().unwrap(),expected.iter().map(|&v|v as i16).collect::<Vec<_>>());
            assert_ne!(ids.map[A_X2],A_X2);
            witness.planes[A_X2].fill(12345);
            assert_eq!(witness.output().unwrap(),expected.iter().map(|&v|v as i16).collect::<Vec<_>>());
        }
    }

    #[test]
    fn dictionary_assignment_uses_fp12_on_every_slot_including_repeated_padding_zeros() {
        use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
        for stack in [Stack::Low,Stack::LowH24] {
            let (mut sh,mut public,ff,data,input)=fixture(stack);
            sh.dd_cap=32;
            public.exp=vec![512;256];
            let trace=build(&sh,&public,&ff,&data,&input).unwrap();
            let expected=trace.p.clone();let totals=trace.sum.clone();
            let witness=assign(&sh,&public,&data,trace).unwrap();
            let ids=AccuracyIds::new(stack,true,sh.limbs_sigma_s()).unwrap();
            let column=public.dd_e_column(sh.dd_cap).unwrap();let g=Geom::new(&sh);
            assert!(column.iter().filter(|&&v|v==0).count()>1);
            for h in 0..g.hq {for t in 0..g.t {
                let hs=g.slot(h);let base=(hs*g.t_pad+t)*sh.dd_cap;let total=totals[g.htix(hs,t)];
                assert_eq!(witness.planes[ids.mdd][base..base+sh.dd_cap].iter().sum::<i64>(),g.t_pad as i64);
                for (k,&e) in column.iter().enumerate() {
                    let q=witness.planes[ids.pdict][base+k];
                    let read=|role| (0..ids.count(role)).map(|j|witness.planes[ids.limb(role,j)][base+k]<<(8*j)).sum::<i64>();
                    let (rho,sigma)=(read(L::Sr),read(L::Sg));
                    assert_eq!(q,read(L::P));assert_eq!(q*total+rho,e<<12);assert_eq!(rho+sigma+1,total);
                    if e==0 && k>0 {assert_eq!(witness.planes[ids.mdd][base+k],0);}
                }
                for j in 0..g.t {assert_eq!(witness.planes[ids.map[A_P]][g.six(hs,t,j)],expected[g.six(hs,t,j)]);}
            }}
        }
    }
