fn direct_weight(r:&[Fp2],idx:usize)->R {
    r.iter().enumerate().fold((1,0),|acc,(j,x)|mul(acc,if (idx>>(r.len()-1-j))&1==1{rr(*x)}else{sub((1,0),rr(*x))}))
}
fn independent_fold(mut v:Vec<R>,r:&[Fp2])->R {
    for &x in r {let half=v.len()/2;for i in 0..half{v[i]=add(mul(sub((1,0),rr(x)),v[i]),mul(rr(x),v[i+half]));}v.truncate(half);}v[0]
}
fn main(){
 let begin=Instant::now();let mut seed=202610290145u64;
 let(mut cases,mut entries,mut direct,mut mles,mut tables,mut tablewords,mut masks,mut controls,mut digest)=(0,0,0,0,0,0,0,0,0u64);
 for log in (0..=10usize).chain([14,17]){for pattern in 0..9{for _ in 0..2{
  let r:Vec<Fp2>=(0..log).map(|j|match pattern{
    0=>Fp2::ZERO,1=>Fp2::ONE,2=>if j%2==0{Fp2::ZERO}else{Fp2::ONE},
    3=>Fp2::new(Fp(field::P-1),Fp(field::P-1)),4=>Fp2::from_base(fp(&mut seed)),
    5=>Fp2::U,6=>Fp2::new(Fp(1),Fp(field::P-1)),7=>Fp2::new(Fp(field::P-2),Fp(2)),_=>fp2(&mut seed)
  }).collect();
  let old=eq_table_msb(&r);let got=candidate::eq_table_msb(&r);assert_eq!(old,got);entries+=got.len();
  let n=got.len();let indices:Vec<usize>=if log<=8{(0..n).collect()}else{let mut ix=vec![0,1,n/2,n-1];for _ in 0..64{ix.push(next(&mut seed)as usize%n);}ix};
  for i in indices{assert_eq!(rr(got[i]),direct_weight(&r,i));direct+=1;}
  assert_eq!(got.iter().copied().fold(Fp2::ZERO,|a,b|a.add(b)),Fp2::ONE);
  if log<=10{let v:Vec<R>=(0..n).map(|_|(fp(&mut seed).0,fp(&mut seed).0)).collect();let eval=got.iter().zip(&v).fold((0,0),|a,(b,c)|add(a,mul(rr(*b),*c)));assert_eq!(eval,independent_fold(v,&r));mles+=1;}
  for x in got{digest=digest.rotate_left(3)^x.c0.0^x.c1.0;}cases+=1;
 }}}
 // Exercise the actual R13 priv_table seam with fresh data/points, not Eq alone.
 for log in (0..=7usize).chain([13,14]){for pattern in [0,2,3,4,6]{for kind in 0..3{
  let(mut p,nv)=fixture(log,pattern,kind,&mut seed);
  for pass in 0..4{refresh(&mut p,&mut seed);for c in &mut p.coords{if let Coord::Fixed(f)=c{if pass==0{*f=Fp2::ZERO;}if pass==1{*f=Fp2::ONE;}}}
   let data:Vec<Fp>=(0..2*(1<<log)+4).map(|_|fp(&mut seed)).collect();let got=changed_priv_table(&p,&data,nv);let old=native_priv_table(&p,&data,nv);
   assert_eq!(got,old);assert_eq!(got.iter().copied().map(rr).collect::<Vec<_>>(),reference(&p,&data,nv));tablewords+=got.len();tables+=1;
   let row=log.min(7);let sh=Shape{log_cols:row,endpoint_log_n:row};let mut pm=p.clone();pm.slices=vec![(0,Fp2::ONE)];
   let md:Vec<Fp>=(0..4*(1<<row)).map(|_|fp(&mut seed)).collect();let rho:Vec<Fp2>=(0..nv).map(|_|fp2(&mut seed)).collect();let point=native_claim_point(&pm,&rho);
   let oldmask=native_mask_eval(&sh,&pm,&md,&point);let gotmask=changed_mask_eval(&sh,&pm,&md,&point);assert_eq!(oldmask,gotmask);assert_eq!(rr(gotmask),mask_reference(&pm,&md,&point,row));masks+=1;
  }
 }}}
 let r:Vec<Fp2>=vec![Fp2::from_u64(2),Fp2::U,Fp2::new(Fp(5),Fp(6))];let table=candidate::eq_table_msb(&r);
 let mut changed=r.clone();changed[1]=changed[1].add(Fp2::ONE);assert_ne!(table,candidate::eq_table_msb(&changed));controls+=1;
 assert_ne!(table,candidate::eq_table(&r));controls+=1; // MSB/LSB error
 let mut swapped=table.clone();swapped.swap(0,7);assert_ne!(swapped,eq_table_msb(&r));controls+=1;
 let mut bad=table.clone();bad[3]=bad[3].add(Fp2::ONE);assert_ne!(bad,eq_table_msb(&r));controls+=1;
 // Faulty complement hi-e must be detected even though the upper arm is correct.
 let e=Fp2::new(Fp(11),Fp(13));let hi=e.mul(r[2]);assert_ne!(hi.sub(e),e.mul(Fp2::ONE.sub(r[2])));controls+=1;
 assert_eq!(candidate::eq_table_msb(&[]),vec![Fp2::ONE]);assert_ne!(candidate::eq_table_msb(&[]),Vec::<Fp2>::new());controls+=1;
 let v:Vec<R>=(0..8).map(|i|(i+1,3*i+2)).collect();let a=independent_fold(v.clone(),&r);let mut v2=v;v2[0]=add(v2[0],(1,0));assert_ne!(a,independent_fold(v2,&r));controls+=1;
 let mut changed2=r.clone();changed2[0]=Fp2::ZERO;assert_ne!(table,candidate::eq_table_msb(&changed2));controls+=1;
 let mut bench=Vec::new();
 for log in [0usize,4,8,14,17,20]{
  let points:Vec<Vec<Fp2>>=(0..3).map(|_|(0..log).map(|_|fp2(&mut seed)).collect()).collect();let(mut nt,mut ct)=(Vec::new(),Vec::new());
  for rep in 0..3{for step in 0..2{let arm=(rep+step)%2;let t=Instant::now();if arm==0{black_box(eq_table_msb(black_box(&points[rep])));nt.push(t.elapsed().as_nanos());}else{black_box(candidate::eq_table_msb(black_box(&points[rep])));ct.push(t.elapsed().as_nanos());}}}
  bench.push(format!("{{\"log\":{},\"entries\":{},\"native_ns\":{:?},\"candidate_ns\":{:?}}}",log,1<<log,nt,ct));
 }
 println!("{{\"status\":\"PASS\",\"seed\":202610290145,\"eq_cases\":{},\"eq_entries_compared\":{},\"independent_direct_weights\":{},\"independent_mle_evaluations\":{},\"priv_table_cases\":{},\"priv_table_words_compared\":{},\"fresh_mask_cases\":{},\"negative_controls\":{},\"digest\":\"{:016x}\",\"elapsed_s\":{},\"bench\":[{}],\"bench_scope\":\"Serial helper, allocation/reverse/init/drop included; shared CPU diagnostics; no native Rayon, proof or GPU rate\",\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",cases,entries,direct,mles,tables,tablewords,masks,controls,digest,begin.elapsed().as_secs_f64(),bench.join(","));
}
