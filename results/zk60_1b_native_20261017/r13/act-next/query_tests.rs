    fn native_query_fixture()->(Shape,AccuracyPublic) {
        let sh=crate::private_block::accuracy_profile_tests::registered_shapes().into_iter()
            .find(|s|s.profile==crate::private_block::shape::R13_RUNG_H24).unwrap();
        let geo=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
        let m=Multipliers{q:vec![1;geo.query_width],k:vec![1;geo.kv_width],v:vec![1;geo.kv_width],o:vec![1;geo.width],
            g:vec![1;geo.hidden],u:vec![1;geo.hidden],d:vec![1;geo.width]};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-1,e_out:-11}];
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let a=AccuracyPublic::new(sh.accuracy_stack(),geo,sh.accuracy_base(),(-3,-11),m,groups,
            (0..geo.hidden).map(|i|i%2).collect(),tables).unwrap();
        assert_eq!(a.folds().gate.shift,sh.accuracy_gate_shift);
        (sh,a)
    }

    #[test]
    fn histogram_and_compressed_queries_count_real_and_padded_groups_without_aliasing() {
        let(sh,a)=native_query_fixture();let gates=vec![0;sh.size(Dom::F)];let outputs=gates.clone();
        let (counts,misses)=histogram(&sh,&a,&gates,&outputs).unwrap();assert_eq!(misses,0);
        let ones=sh.tokens*(sh.hidden/2);
        assert_eq!(counts[4096+2048],ones as u64);assert_eq!(counts[2048],(gates.len()-ones) as u64);
        assert_eq!(counts.iter().sum::<u64>(),gates.len() as u64);
        let beta=Fp2::from_i64(7);let tag=Fp2::from_i64(31);
        let q=query_values(&sh,&a,&gates,&outputs,beta,tag).unwrap();let t=table(&a,sh.size(Dom::Tab),beta,tag).unwrap();
        for (i,&value) in q.iter().enumerate() {let group=query_group(&sh,&a,i);assert_eq!(value,t.compressed[group*4096+2048]);}
    }

    #[test]
    fn signed_endpoints_are_exact_and_invalid_queries_are_counted_without_panics() {
        let(sh,a)=native_query_fixture();let mut gates=vec![0;sh.size(Dom::F)];let mut outputs=gates.clone();
        for gate in [-2048,2047] {
            gates[0]=gate;outputs[0]=a.scaled_tables()[0][(gate+2048) as usize];
            assert_eq!(histogram(&sh,&a,&gates,&outputs).unwrap().1,0);
        }
        for gate in [-2049,2048,i64::MIN,i64::MAX] {
            gates[0]=gate;let (counts,misses)=histogram(&sh,&a,&gates,&outputs).unwrap();
            assert_eq!(misses,1);assert_eq!(counts[0],1);
            // No overflowing gate+2048 integer operation in the field query.
            let values=query_values(&sh,&a,&gates,&outputs,Fp2::from_i64(7),Fp2::ZERO).unwrap();
            assert_eq!(values[0],Fp2::from_i64(gate).add(Fp2::from_i64(2048)).add(Fp2::from_i64(7).mul(Fp2::from_i64(outputs[0]))));
        }
        gates[0]=0;outputs[0]=1;
        assert_eq!(histogram(&sh,&a,&gates,&outputs).unwrap().1,1);
    }
