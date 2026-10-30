use super::shape::{self,Shape,NormCalibration};
use super::layout::*;
use super::accuracy_precision::Stack;

fn calibration(width:usize)->NormCalibration {
    NormCalibration{tn:if width>=3072 {9} else {10},cn_a:100,cn_m:100,ceps:1,sh_ao:7,
        sh_qkv:8,sh_s:6,sh_o:9,sh_g:8,sh_h:14,sh_z:6}
}

#[test]
fn every_r13_profile_builds_exact_role_lookup_helper_and_claim_counts() {
    assert_eq!(shape::ACCURACY_PROFILES.len(),12);
    for spec in &shape::ACCURACY_PROFILES {
        let fe=if spec.tokens==32 {12} else {9};
        let sh=Shape::accuracy_trained(spec.profile,&calibration(spec.width),fe,20).unwrap();
        sh.check_constructed().unwrap();
        assert_eq!(sh.accuracy_stack(),spec.stack);assert_eq!(sh.accuracy_registry(),spec.registry);
        assert_eq!((sh.limbs_norm(),sh.limbs_p(),sh.f_p()),(3,2,12));assert!(sh.norm_top_is_full_byte());
        for dom in [Dom::D,Dom::F,Dom::Q,Dom::Kv,Dom::S] {assert_eq!(sh.log(dom),sh.natural_log(dom));}
        let lay=Layout::for_shape(&sh).unwrap();let ids=lay.ids();let hids=lay.hids();
        assert_eq!(sh.a_plane_doms().len(),ids.n_a());assert_eq!(sh.h_plane_doms().len(),hids.n_h());
        for dom in [Dom::T,Dom::Ht,Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F,Dom::Tab,Dom::Dd] {
            let count=sh.a_plane_doms().iter().filter(|&&d|d==dom).count();
            if dom==Dom::Dd && sh.dd_cap==0 {assert_eq!(count,0);continue}
            let range=ids.domain_range(dom).unwrap();assert_eq!(range.len(),count);
            assert_eq!(lookups_at(&sh,ids,dom).len(),sh.lookups_per_position(dom));
            assert_eq!(sh.helpers(dom),sh.lookups_per_position(dom).div_ceil(2));
        }
        let (a,h)=sh.claim_sites();
        assert_eq!(a[SC_DZC],if spec.stack==Stack::LowH24 {41} else {40});
        assert_eq!((a[SC_QZC],a[SC_KVZC],a[SC_FZC]),(15,15,16));
        assert_eq!((h[SC_QZC],h[SC_KVZC],h[SC_FZC]),(7,7,8));
        assert_eq!(sh.size(Dom::Tab),1usize<<spec.log_cols);assert!(sh.size(Dom::Tab)>=4*4096);
        assert_eq!(ids.at(A_X2),if spec.stack==Stack::LowH24 {44} else {43});
        for old in [A_NR0+3,A_NS0+3,A_MR0+3,A_MS0+3] {assert_eq!(ids.at(old),usize::MAX);}
        assert!(std::panic::catch_unwind(||ids.nr(3)).is_err());
        if sh.dd_cap>0 {assert_eq!(sh.dd_cap,32);sh.check_dd_geometry().unwrap();}
        assert_eq!(shape::trained_rope_theta(sh.profile),shape::trained_rope_theta(spec.legacy));
        assert_eq!(shape::trained_rope_scaling(sh.profile),shape::trained_rope_scaling(spec.legacy));
    }
}

#[test]
fn the_common_gate_shift_is_constructor_checked_reconstructed_and_schedule_bound() {
    for spec in &shape::ACCURACY_PROFILES {
        let cal=calibration(spec.width);
        let first=Shape::accuracy_trained(spec.profile,&cal,9,17).unwrap();
        let second=Shape::accuracy_trained(spec.profile,&cal,9,24).unwrap();
        assert_ne!(Layout::for_shape(&first).unwrap().schedule_digest(),Layout::for_shape(&second).unwrap().schedule_digest());
        for shift in [0,16,25,u32::MAX] {
            assert!(Shape::accuracy_trained(spec.profile,&cal,9,shift).is_err());
            let mut forged=first.clone();forged.accuracy_gate_shift=shift;assert!(forged.check_constructed().is_err());
        }
        assert!(super::BlockPublic::synthetic_fixture().0.check_for_shape(&first).is_err());
    }
    let mut legacy=Shape::toy();legacy.accuracy_gate_shift=17;assert!(legacy.check_constructed().is_err());
    assert!(Shape::toy().with_accuracy_gate_shift(17).is_err());
}

pub(super) fn registered_shapes()->Vec<Shape> {
    shape::ACCURACY_PROFILES.iter().map(|s|Shape::accuracy_trained(s.profile,&calibration(s.width),if s.tokens==32 {12} else {9},20).unwrap()).collect()
}


pub(super) fn registered_runs()->Vec<(&'static str,Shape)> {
    registered_shapes().into_iter().map(|s|(super::run::accuracy_run_profile(s.profile).unwrap(),s)).collect()
}

#[test]
fn accuracy_native_legacy_comparison_census() {
    for spec in &shape::ACCURACY_PROFILES {
        if spec.tokens==32 {continue;}
        let cal=calibration(spec.width);
        let sh=Shape::accuracy_trained(spec.profile,&cal,9,20).unwrap();
        let dd=sh.dd_cap>0;
        let old=match (spec.width,dd) {
            (2048,false)=>Shape::tinyllama_trained(spec.tokens,&cal,9),
            (2048,true)=>Shape::tinyllama_t128_trained_dd(&cal,9),
            (4096,false)=>Shape::llama3_8b_trained(spec.tokens,&cal,9),
            (4096,true)=>Shape::llama3_8b_t128_trained_dd(&cal,9),
            (3072,false)=>Shape::shieldstral_trained(spec.tokens,&cal,9),
            (3072,true)=>Shape::shieldstral_trained_dd(spec.tokens,&cal,9),
            _=>panic!("unclassified trained geometry"),
        }.unwrap();
        let current=Layout::for_shape(&sh).unwrap();let prior=Layout::for_shape(&old).unwrap();
        let ct=sh.totals();let pt=old.totals();
        assert_eq!((current.a_rows,current.h_rows),(ct.a_rows,ct.h_rows));
        assert_eq!((prior.a_rows,prior.h_rows),(pt.a_rows,pt.h_rows));
        let (new_words,old_words)=((current.a_rows+current.h_rows)*current.n(),(prior.a_rows+prior.h_rows)*prior.n());
        eprintln!("R13_NATIVE_COMPARISON {{\"profile\":{:?},\"legacy_profile\":{:?},\"committed_a_h_words\":{},\"legacy_committed_a_h_words\":{},\"receipt_bytes\":{},\"legacy_receipt_bytes\":{},\"byte_queries\":{},\"legacy_byte_queries\":{},\"scope\":\"COUNTED native layouts; FE9 admitted calibration; A+H convention excludes endpoints and M\"}}",
            sh.profile,old.profile,new_words,old_words,ct.receipt_bytes.total,pt.receipt_bytes.total,ct.u8_lookups,pt.u8_lookups);
    }
}

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
