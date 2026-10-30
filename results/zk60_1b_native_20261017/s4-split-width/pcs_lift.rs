use hashline::field::{Fp,Fp2};
use hashline::pcs::{self,PcsParams,ZkOpts,ZPart,ZClaim,Slice};
use hashline::ntt::NttTables;
use hashline::transcript::Transcript;
use hashline::zk::ZkRng;

fn f(a:u64,b:u64)->Fp2 {Fp2::new(Fp::new(a),Fp::new(b))}
fn eval(a:&[Fp],point:&[Fp2])->Fp2 {
    let mut v=a.iter().map(|&x|Fp2::new(x,Fp::ZERO)).collect::<Vec<_>>();
    for &r in point {let h=v.len()/2;for i in 0..h {v[i]=v[i].mul(Fp2::ONE.sub(r)).add(v[i+h].mul(r));}v.truncate(h);}v[0]
}
fn normalize(c:ZClaim)->Result<Vec<ZClaim>,String> {
    if c.parts.iter().all(|p|p.coef==Fp2::ZERO) {
        if c.value!=Fp2::ZERO {return Err("zero functional must claim zero".into());}Ok(vec![])
    }else {Ok(vec![c])}
}
fn main() {
    let params=PcsParams{log_cols:4,inv_rate:4,num_col_checks:8};let n=params.cols();
    let zk=ZkOpts::standard(&params);let ntt=NttTables::new(8);
    // Public deterministic fixture only; not a production proof RNG entry.
    let mut rng=ZkRng::new(53,b"s4-pcs-weighted-public-fixture");
    let data=(0..4*n).map(|_|rng.fp()).collect::<Vec<_>>();
    let mut cm=pcs::commit_zk_owned(&params,data.clone(),&ntt,&zk,&mut rng);
    cm.mask_rows=vec![1,2];cm.prox_mask_row=Some(3);
    let root=cm.commitment();let point=vec![f(2,3),f(5,7),f(11,13),f(17,19)];
    let eta=f(23,29);let vp=eval(&data[..n],&point);
    let mask=eta.mul(eval(&data[n..2*n],&point)).add(eta.mul(eta).mul(eval(&data[2*n..3*n],&point)));
    let transcript=||{let mut t=Transcript::new(b"s4-pcs-lift-fixture");t.absorb(b"root",&root.root);t};
    let claim=|sigma:Fp2|ZClaim{parts:vec![
        ZPart{slice:Slice{offset:0,log_size:4},coef:sigma,point:point.clone()},
        ZPart{slice:Slice{offset:n,log_size:4},coef:sigma.mul(eta),point:point.clone()},
        ZPart{slice:Slice{offset:2*n,log_size:4},coef:sigma.mul(eta).mul(eta),point:point.clone()}],
        value:sigma.mul(vp.add(mask))};
    let mut honest=0;let mut rejected=0;
    for sigma in [Fp2::ONE,f(2,5),Fp2::ONE.sub(f(3,7)).mul(Fp2::ONE.sub(f(11,17)))] {
        let c=claim(sigma);let opening=pcs::open_zk(&cm,&[c.clone()],&mut transcript());
        pcs::verify_zk(&params,&zk,&root,&[c.clone()],&opening,&ntt,&mut transcript()).unwrap();honest+=1;
        let mut wrong=c.clone();wrong.value=sigma.mul(vp).add(mask);
        if sigma!=Fp2::ONE {
            assert_ne!(wrong.value,c.value);
            let bad=pcs::open_zk(&cm,&[wrong.clone()],&mut transcript());
            assert!(pcs::verify_zk(&params,&zk,&root,&[wrong],&bad,&ntt,&mut transcript()).is_err());rejected+=1;
        }
        let mut changed=c;changed.value=changed.value.add(Fp2::ONE);
        assert!(pcs::verify_zk(&params,&zk,&root,&[changed],&opening,&ntt,&mut transcript()).is_err());rejected+=1;
    }
    // Preserve the existing assertion. Its zero-group refusal is an observed
    // API requirement; no production code is changed by this experiment.
    assert!(std::panic::catch_unwind(std::panic::AssertUnwindSafe(||
        pcs::open_zk(&cm,&[claim(Fp2::ZERO)],&mut transcript()))).is_err());
    let claims=normalize(claim(Fp2::ZERO)).unwrap();assert!(claims.is_empty());
    let opening=pcs::open_zk(&cm,&claims,&mut transcript());
    pcs::verify_zk(&params,&zk,&root,&claims,&opening,&ntt,&mut transcript()).unwrap();
    let mut bad=claim(Fp2::ZERO);bad.value=Fp2::ONE;assert!(normalize(bad).is_err());
    println!("{{\"honest_weighted_openings\":{honest},\"rejected_bad_claims\":{rejected},\"zero_group_guard_retained\":true,\"checked_zero_normalization\":true,\"scope\":\"native PCS microtest only; CFS/wire/rank/privacy integration not established\"}}");
}
