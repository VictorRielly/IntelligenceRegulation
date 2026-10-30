use super::accuracy_groups::Group;
use super::accuracy_precision::BaseShifts;
use super::accuracy_public::{AccuracyPublic, Geometry, Multipliers};
use super::*;

fn public(multiplier: u16) -> AccuracyPublic {
    let base = BaseShifts { norm_tn: 10, qkv: 8, score: 6, pv: 9, ao: 7, gate: 8, up: 0, product: 14, down: 6 };
    let geo = Geometry { width: 16, query_width: 16, kv_width: 8, hidden: 16 };
    let multipliers = Multipliers { q: vec![multiplier; 16], k: vec![1; 8], v: vec![1; 8],
        o: vec![1; 16], g: vec![1; 16], u: vec![1; 16], d: vec![1; 16] };
    AccuracyPublic::new(accuracy_precision::Stack::LowH24, geo, base, (-3, -11), multipliers, vec![Group { e_in: -3, e_out: -11 }],
                       vec![0; 16], vec![accuracy_tables::silu_table(-3, -11, 12).unwrap()]).unwrap()
}

#[test]
fn the_accuracy_data_is_attached_and_changes_the_actual_block_digest() {
    let (legacy, _) = BlockPublic::synthetic_fixture();
    let first = legacy.clone().with_accuracy(public(1));
    let second = legacy.clone().with_accuracy(public(2));
    assert!(first.accuracy().is_some());
    assert_ne!(legacy.digest(), first.digest());
    assert_ne!(first.digest(), second.digest());
}

#[test]
fn a_legacy_profile_refuses_accuracy_data_instead_of_ignoring_it() {
    let (legacy, _) = BlockPublic::synthetic_fixture();
    legacy.check_for_shape(&shape::Shape::toy()).unwrap();
    let error = legacy.with_accuracy(public(1)).check_for_shape(&shape::Shape::toy()).unwrap_err();
    assert!(error.contains("R13"), "{error}");
}
