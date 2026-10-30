#![allow(dead_code)]
#[path="../r13/frozen-tree/zkp-core/src/field.rs"] mod field;
use field::{Fp,Fp2};

fn f(a:i64,b:i64)->Fp2 {Fp2{c0:Fp::from_i64(a),c1:Fp::from_i64(b)}}
fn lg(x:usize)->usize {assert!(x.is_power_of_two());x.trailing_zeros() as usize}
fn table(n:usize,seed:usize)->Vec<Fp2> {(0..n).map(|i|f(((i*37+seed*11)%251) as i64-125,((i*19+seed*7)%113) as i64-56)).collect()}

// Fold MSB-first, independent of the direct Boolean-weight evaluator below.
fn eval(a:&[Fp2],point:&[Fp2])->Fp2 {
    assert_eq!(a.len(),1usize<<point.len());let mut a=a.to_vec();
    for &r in point {let h=a.len()/2;for i in 0..h {a[i]=a[i].mul(Fp2::ONE.sub(r)).add(a[i+h].mul(r));}a.truncate(h);}
    a[0]
}
fn direct(a:&[Fp2],point:&[Fp2])->Fp2 {
    a.iter().enumerate().fold(Fp2::ZERO,|acc,(i,&value)| {
        let w=point.iter().enumerate().fold(Fp2::ONE,|w,(j,&r)|w.mul(if i>>(point.len()-1-j)&1==1 {r} else {Fp2::ONE.sub(r)}));
        acc.add(w.mul(value))
    })
}
fn up(a:&[Fp2],tokens:usize,small:usize,large:usize)->Vec<Fp2> {
    assert_eq!(a.len(),tokens*small);let mut v=vec![Fp2::ZERO;tokens*large];
    for t in 0..tokens {v[t*large..t*large+small].copy_from_slice(&a[t*small..(t+1)*small]);}v
}
fn projected(point:&[Fp2],tokens:usize,small:usize,large:usize)->(Fp2,Vec<Fp2>) {
    let t=lg(tokens);let k=lg(large/small);assert_eq!(point.len(),t+lg(large));
    let sigma=point[t..t+k].iter().fold(Fp2::ONE,|a,&r|a.mul(Fp2::ONE.sub(r)));
    let mut tail=point[..t].to_vec();tail.extend_from_slice(&point[t+k..]);(sigma,tail)
}
fn sum_dot(a:&[Fp2],b:&[Fp2])->Fp2 {a.iter().zip(b).fold(Fp2::ZERO,|v,(&a,&b)|v.add(a.mul(b)))}
fn finite_difference(mut v:Vec<Fp2>,order:usize)->Fp2 {
    for _ in 0..order {v=v.windows(2).map(|x|x[1].sub(x[0])).collect();}v[0]
}
fn main() {
    let mut identities=0;let mut degree_checks=0;let mut zero_cases=0;
    for (tokens,large,small) in [(2,8,4),(4,32,4),(4,2048,1024),(2,8192,1024)] {
        let a=table(tokens*large,1);let b=table(tokens*large,2);
        let c=table(tokens*small,3);let d=table(tokens*small,4);
        let cu=up(&c,tokens,small,large);let du=up(&d,tokens,small,large);
        let total=sum_dot(&a,&b).add(sum_dot(&c,&d));
        assert_eq!(total,sum_dot(&a,&b).add(sum_dot(&cu,&du)));identities+=1;
        // A repeated smaller piece counts each source word large/small times.
        let repeated=(large/small) as i64;
        assert_ne!(sum_dot(&c,&d),sum_dot(&c,&d).mul(f(repeated,0)));
        for seed in 0..12 {
            let mut point=(0..lg(tokens*large)).map(|i|f((seed*7+i*3+2) as i64,(i+seed+1) as i64)).collect::<Vec<_>>();
            if seed==0 {point[lg(tokens)]=Fp2::ONE;}
            if seed==1 && large/small==8 {point[lg(tokens)+2]=Fp2::ONE;}
            let (sigma,tail)=projected(&point,tokens,small,large);
            let value=eval(&cu,&point);assert_eq!(value,sigma.mul(eval(&c,&tail)));
            assert_eq!(value,direct(&cu,&point));identities+=2;
            let mask=table(tokens*small,5);let masked=c.iter().zip(&mask).map(|(&a,&m)|a.add(m)).collect::<Vec<_>>();
            let lifted_masked=up(&masked,tokens,small,large);
            assert_eq!(eval(&lifted_masked,&point),sigma.mul(eval(&c,&tail).add(eval(&mask,&tail))));identities+=1;
            if sigma==Fp2::ZERO {assert_eq!(eval(&lifted_masked,&point),Fp2::ZERO);zero_cases+=1;}
            else if sigma!=Fp2::ONE {
                assert_ne!(eval(&lifted_masked,&point),sigma.mul(eval(&c,&tail)).add(eval(&mask,&tail)));
            }
        }
        // Degree checks use modest cubes; the larger cases above check actual
        // 2048/1024 and8192/1024 coordinate extents without allocating a model.
        if large<=32 {
            let mut point=(0..lg(tokens*large)).map(|i|f((i+2) as i64,(i+1) as i64)).collect::<Vec<_>>();
            for axis in 0..point.len() {
                let v=(0..5).map(|j| {point[axis]=f(j,0);eval(&a,&point).mul(eval(&b,&point)).add(eval(&cu,&point).mul(eval(&du,&point)))}).collect::<Vec<_>>();
                assert_eq!(finite_difference(v[..4].to_vec(),3),Fp2::ZERO);degree_checks+=1;
                // Multiplication by a public multilinear equality factor adds
                // at most one to the coordinate degree.
                let v=(0..5).map(|j| {point[axis]=f(j,0);let eq=point.iter().fold(Fp2::ONE,|v,&r|v.mul(Fp2::ONE.add(r)));
                    eq.mul(eval(&a,&point).mul(eval(&b,&point)).add(eval(&cu,&point).mul(eval(&du,&point))))}).collect::<Vec<_>>();
                assert_eq!(finite_difference(v,4),Fp2::ZERO);degree_checks+=1;
            }
            // An axis bit belongs after the token coordinates, not at bit0.
            let map_point=(0..lg(tokens*large)).map(|i|f((i+2) as i64,(i+1) as i64)).collect::<Vec<_>>();
            let mut wrong=map_point.clone();wrong.remove(0);
            if large/small==2 {assert_ne!(eval(&cu,&map_point),Fp2::ONE.sub(map_point[0]).mul(eval(&c,&wrong)));}
        }
    }
    // Half-up rounding is performed once, after the whole accumulator sum.
    let rq=|v:i64|(v+1).div_euclid(2);
    assert_eq!(rq(1+1),1);assert_eq!(rq(1)+rq(1),2);
    println!("{{\"lift_and_mask_identities\":{identities},\"coordinate_degree_checks\":{degree_checks},\"zero_coefficient_cases\":{zero_cases},\"scope\":\"isolated native-field algebra; no PCS/CFS/privacy acceptance or split-layout implementation\"}}");
}
