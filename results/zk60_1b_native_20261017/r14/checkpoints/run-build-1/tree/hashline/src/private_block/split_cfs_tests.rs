//! Native scheduled-CFS component microproof. Not a registered R14 profile.
use super::*;
use crate::ntt::NttTables;
use crate::pcs::{self,PcsParams,ZkOpts};
use crate::zk::{self,ZkRng};

#[derive(Clone,Copy,PartialEq)]
enum Variant { Honest, OmitGate, SeparateGate }

fn definition(variant:Variant)->SlotDef {
    let rt=vec![Fp2::from_u64(3),Fp2::new(Fp::new(5),Fp::new(7))];
    let mut gated=rt.clone();gated.extend_from_slice(&[Fp2::ZERO;3]);
    let mut tabs=vec![Tab::Eq{point:rt.clone(),start:0},Tab::Eq{point:if variant==Variant::Honest {gated}else{rt},start:0},
        Tab::Priv(Priv{cm:Cm::A,slices:vec![(0,Fp2::ONE)],log:8,coords:rho(0..8),mask_row:2,ext_round:0}),
        Tab::Priv(Priv{cm:Cm::A,slices:vec![(256,Fp2::ONE)],log:5,coords:rho(0..2).into_iter().chain(rho(5..8)).collect(),mask_row:4,ext_round:0})];
    if variant==Variant::SeparateGate {tabs.push(Tab::Eq{point:vec![Fp2::ZERO;3],start:2});}
    SlotDef{slot:30,tabs,groups:None,hosted:vec![],sh:Shape::toy(),poly:Box::new(move|v:&[Fp2]| {
        let small=if variant==Variant::SeparateGate {v[1].mul(v[4])}else{v[1]};
        v[0].mul(v[2].mul(v[2])).add(small.mul(v[3].mul(v[3])))
    })}
}

fn plan()->Vec<SlotSchedule> {
    vec![SlotSchedule{main:8,ext:1,degree:3,terminals:2,kind:SlotKind::Private,name:"R14 norm component at physical slot30".into()};31]
}

fn initial_acc()->Acc {
    // Only physical slot30 is exercised here. The preceding public placeholders
    // check index handling, not a fictitious31-slot completed proof.
    Acc{cs:vec![Fp2::ONE;30],scalars:vec![Fp2::ZERO;30],..Acc::default()}
}

fn fixture(variant:Variant)->Result<(),String> {
    let ntt=NttTables::new(13);
    let params=PcsParams{log_cols:8,inv_rate:4,num_col_checks:8};let zko=ZkOpts::standard(&params);
    let mut rng=ZkRng::new(130,b"R14 scheduled CFS public fixture only");
    let data=rng.fp_vec(8*256);let mut cm=pcs::commit_zk_owned(&params,data,&ntt,&zko,&mut rng);
    cm.mask_rows=vec![2,3,4,5];cm.prox_mask_row=Some(6);let root=cm.commitment();
    let schedule=plan();let specs=schedule.iter().map(SlotSchedule::mask_spec).collect::<Vec<_>>();
    let mc=zk::mask_commit(&specs,&ntt,&mut rng);let mroot=mc.tree.root();
    let transcript=||{let mut tr=Transcript::new(b"R14 scheduled CFS component, not native profile");tr.absorb(b"A",&root.root);tr.absorb(b"M",&mroot);tr};
    let pd=ProverData{data:[&cm.data,&[],&[],&[]],masks:&mc.masks};
    let honest=definition(Variant::Honest);
    let tables=honest.tabs.iter().map(|t|table_of(t,8,&pd)).collect::<Vec<_>>();let expected=total(&tables,&honest.poly);
    let mut side=Side::Prove{pd,out:vec![]};let mut acc=initial_acc();let mut tr=transcript();
    run_slot_scheduled(&mut side,&mut acc,definition(variant),&mut tr,&schedule)?;
    let gamma=|a:&Acc|MaskFunctional{terms:vec![(30,schedule_sum_weights(&schedule,30).iter().map(|w|w.mul(a.cs[30])).collect())],value:a.scalars[30].sub(expected)};
    acc.fs.push(gamma(&acc));
    let opening=pcs::open_zk(&cm,&acc.claims[Cm::A as usize],&mut tr);
    let masks=zk::mask_open(&mc,&acc.fs,&ntt,&mut tr);
    let produced=match side {Side::Prove{out,..}=>out,_=>unreachable!()};assert_eq!(produced.len(),1);
    let mut slots=vec![SlotProof::default();30];slots.push(produced[0].clone());
    let mut side=Side::Verify{slots:&slots};let mut checked=initial_acc();let mut tr=transcript();
    run_slot_scheduled(&mut side,&mut checked,definition(Variant::Honest),&mut tr,&schedule)?;
    checked.fs.push(gamma(&checked));
    // All variants emit commitment-consistent native private terminals. The
    // forged public gate/degree must reach the M coupling check to be refused.
    pcs::verify_zk(&params,&zko,&root,&checked.claims[Cm::A as usize],&opening,&ntt,&mut tr).unwrap();
    zk::mask_verify(&mroot,&specs,&checked.fs,&masks,&ntt,&mut tr)
}

#[test]
fn split_scheduled_native_cfs_pcs_m_accepts_public_factor_lift_at_slot30() {
    fixture(Variant::Honest).unwrap();
}

#[test]
fn split_scheduled_native_cfs_emitted_gate_forgeries_reach_m_and_refuse() {
    for v in [Variant::OmitGate,Variant::SeparateGate] {
        let error=fixture(v).expect_err("scheduled native CFS accepted wrong public gate/degree");
        assert!(error.starts_with("mask:"),"forgery failed before native M verification: {error}");
    }
}
