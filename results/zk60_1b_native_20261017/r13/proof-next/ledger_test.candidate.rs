#[test]
fn accuracy_native_layout_census_for_review() {
    for spec in &shape::ACCURACY_PROFILES {
        for fe in [9u32,12,16] {
            let sh=Shape::accuracy_trained(spec.profile,&calibration(spec.width),fe,20).unwrap();
            let lay=Layout::for_shape(&sh).unwrap();let ids=lay.ids();
            let byte_queries:u128=lay.lookup_doms().into_iter().map(|d| {
                let emitted=lookups_at(&sh,ids,d).len();assert_eq!(emitted,sh.lookups_per_position(d));
                (sh.size(d) as u128)*(emitted as u128)
            }).sum();
            let (exp,act)=(sh.size(Dom::S) as u128,sh.size(Dom::F) as u128);
            let (ddq,ddt)=if sh.dd_cap>0 {(exp,sh.size(Dom::Dd) as u128)} else {(0,0)};
            let (ac,hc)=sh.claim_sites();
            let (a_sites,h_sites)=(ac.iter().sum::<usize>(),hc.iter().sum::<usize>());
            let sc_degree=sh.slots().iter().take(sh.n_slots()).map(|(main,ext,d)|(main+ext)*d).sum::<usize>();
            let pub_weights=2*sh.q_pad()*sh.d_pad+2*(sh.kv_heads*sh.head_dim)*sh.d_pad+3*sh.d_pad*sh.f_pad+2*sh.d_pad;
            for ng in 1..=4 {
                let act_entries=(4096*ng) as u128;
                let positions=byte_queries+exp+act+ddq+512+act_entries+ddt;
                assert!(positions<(1u128<<63));assert!(act_entries<=sh.size(Dom::Tab) as u128);
                let proposed_lookup_degree=2*(positions-1);
                // Counts come from native Shape/Layout/emitted lookups. The
                // polynomial bound remains a D24 review proposal.
                eprintln!("R13_NATIVE_CENSUS {{\"profile\":{:?},\"f_e\":{},\"groups\":{},\"tokens\":{},\"width\":{},\"query_width\":{},\"hidden\":{},\"dd\":{},\"n\":{},\"a_planes\":{},\"h_planes\":{},\"a_rows\":{},\"h_rows\":{},\"a_mask_base\":{},\"h_mask_base\":{},\"a_sites\":{},\"h_sites\":{},\"a_site_rows\":{},\"h_site_rows\":{},\"m_rows\":{},\"endpoint_rows\":{},\"padded_public_weight_bytes\":{},\"byte_queries\":{},\"exp_queries\":{},\"act_queries\":{},\"act_padding_queries\":{},\"dd_queries\":{},\"dd_table_entries\":{},\"act_table_entries\":{},\"lookup_positions\":{},\"proposed_lookup_degree\":{},\"sumcheck_round_degree_sum\":{},\"scope\":\"COUNTED admitted-calibration example; lookup bound unreviewed\"}}",
                    sh.profile,fe,ng,sh.tokens,sh.width,sh.q_width(),sh.hidden,sh.dd_cap>0,lay.n(),ids.n_a(),lay.hids().n_h(),
                    lay.a_rows,lay.h_rows,lay.a_mask_base,lay.h_mask_base,a_sites,h_sites,lay.a_site_rows().len(),lay.h_site_rows().len(),
                    lay.m_rows(),sh.endpoint_rows,pub_weights,byte_queries,exp,act,act-(sh.tokens*sh.hidden) as u128,
                    ddq,ddt,act_entries,positions,proposed_lookup_degree,sc_degree);
            }
        }
    }
}
