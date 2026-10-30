    #[test]
    fn every_stack_registry_and_group_count_matches_its_actual_encoded_length() {
        for registry in [Registry::Standard,Registry::Shieldstral] {
            let geo=if registry==Registry::Standard {GEO} else {Geometry{width:3072,query_width:4096,kv_width:1024,hidden:9216}};
            let members=if registry==Registry::Standard {[(-5,-13),(-4,-12),(-3,-11),(-1,-9)]}
                else {[(-5,-13),(-3,-11),(-1,-9),(0,-8)]};
            for stack in [Stack::Low,Stack::LowH24] {for count in 1..=4 {
                let m=Multipliers{q:vec![1;geo.query_width],k:vec![1;geo.kv_width],v:vec![1;geo.kv_width],
                    o:vec![1;geo.width],g:vec![1;geo.hidden],u:vec![1;geo.hidden],d:vec![1;geo.width]};
                let groups:Vec<_>=members[..count].iter().map(|&(e_in,e_out)|Group{e_in,e_out}).collect();
                let tables=groups.iter().map(|g|super::super::accuracy_tables::silu_table_for(registry,g.e_in,g.e_out,12).unwrap()).collect();
                let data=AccuracyPublic::new_with_registry(registry,stack,geo,BASE,(-3,-11),m,groups,
                    (0..geo.hidden).map(|i|i%count).collect(),tables).unwrap();
                assert_eq!(encoded_len(geo,registry,stack,count).unwrap(),data.encode().len(),"{stack:?}/{registry:?}/{count}");
            }}
        }
        assert!(encoded_len(GEO,Registry::Standard,Stack::Legacy,1).is_err());
        assert!(encoded_len(GEO,Registry::Standard,Stack::Low,0).is_err());
        assert!(encoded_len(GEO,Registry::Standard,Stack::Low,5).is_err());
    }
