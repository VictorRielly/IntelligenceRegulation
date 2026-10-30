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
        assert!(super::BlockPublic::synthetic_fixture().0.check_for_shape(&first).unwrap_err().contains("R13"));
    }
    let mut legacy=Shape::toy();legacy.accuracy_gate_shift=17;assert!(legacy.check_constructed().is_err());
    assert!(Shape::toy().with_accuracy_gate_shift(17).is_err());
}

pub(super) fn registered_shapes()->Vec<Shape> {
    shape::ACCURACY_PROFILES.iter().map(|s|Shape::accuracy_trained(s.profile,&calibration(s.width),if s.tokens==32 {12} else {9},20).unwrap()).collect()
}
