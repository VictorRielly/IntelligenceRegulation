// Public coefficient schedules only. No matrix or private value enters planning.
// gap_budget is an uncalibrated extra cost per run start in logical-byte units.
fn gap_plan(base:&[IntervalBatch], sets:&[Vec<bool>], gap_budget:u64)->Vec<IntervalBatch>{
 base.iter().map(|b|{
  let mut out:Vec<Run>=vec![];
  for s in &b.runs{
   let start=(s.word>>4)as usize;let flags=s.word&15;
   let join=out.last().map_or(false,|p|{
    let end=(p.word>>4)as usize+p.len as usize;
    let gap=start-end;
    (p.word&15)==flags && (end..start).all(|r|b.groups.iter().all(|&g|!sets[g][r]))
     && (gap as u64)*(8+16*flags.count_ones()as u64)<8+gap_budget
   });
   if join{let p=out.last_mut().unwrap();p.len=(start+s.len as usize-(p.word>>4)as usize)as u32;}
   else{out.push(s.clone());}
  }
  IntervalBatch{groups:b.groups.clone(),runs:out}
 }).collect()
}

// Independent exhaustive row coverage audit: required support must be retained;
// any extra group/row must have an exactly zero coefficient in BOTH limbs.
fn audit_superset(p:&[IntervalBatch], required:&[Vec<bool>],rho:&[Vec<Fp2>],order:&[usize])->Result<(), &'static str>{
 if required.is_empty()||order.len()!=required.len()||p.len()!=(order.len()+3)/4{return Err("shape");}
 let rows=required[0].len();let mut seen=vec![false;required.len()];
 for(b,gs)in p.iter().zip(order.chunks(4)){
  if b.groups!=gs{return Err("order");}
  for &g in gs{if g>=seen.len()||seen[g]{return Err("groups");}seen[g]=true;}
  let mut decoded=vec![0u32;rows];let mut end=0;
  for s in &b.runs{
   let a=(s.word>>4)as usize;let z=a.checked_add(s.len as usize).ok_or("overflow")?;let f=s.word&15;
   if s.len==0||a<end||z>rows||f==0||f>=1<<gs.len(){return Err("bound/overlap/flags");}
   for v in &mut decoded[a..z]{*v=f;}end=z;
  }
  for r in 0..rows{for(i,&g)in gs.iter().enumerate(){
   let covered=decoded[r]&(1<<i)!=0;let live=rho[g][r].c0!=Fp::ZERO||rho[g][r].c1!=Fp::ZERO;
   if (required[g][r]||live)&&!covered{return Err("missing live or protected support");}
   if covered&&!required[g][r]&&live{return Err("nonzero extra");}
  }}
 }
 if seen.iter().any(|x|!*x){return Err("omitted group");}Ok(())
}

fn gap_stats(p:&[IntervalBatch])->(usize,usize,usize){
 let mut visits=0;let mut macs=0;let mut spans=0;
 for b in p{for s in &b.runs{visits+=s.len as usize;macs+=s.len as usize*(s.word&15).count_ones()as usize;spans+=1;}}
 (visits,macs,spans)
}

fn gap_controls()->usize{
 let rows=9;let mut rho=vec![vec![Fp2::ZERO;rows];2];
 for r in [0,2,8]{rho[0][r]=Fp2::ONE;}
 let req:Vec<Vec<_>>=rho.iter().map(|v|v.iter().map(|x|*x!=Fp2::ZERO).collect()).collect();let order=vec![0,1];
 let base=intervals(&build_plan(&req,&order));let p=gap_plan(&base,&req,10000);
 assert_eq!(p[0].runs.len(),1);audit_superset(&p,&req,&rho,&order).unwrap();let mut checks=1;
 // A newly live unflagged imaginary coefficient must invalidate a stale plan.
 let mut stale=rho.clone();stale[1][1]=Fp2::new(Fp::ZERO,Fp::ONE);
 assert!(audit_superset(&p,&req,&stale,&order).is_err());checks+=1;
 // A real-only zero predicate would silently omit this imaginary coefficient.
 let badsets:Vec<Vec<_>>=stale.iter().map(|v|v.iter().map(|x|x.c0!=Fp::ZERO).collect()).collect();
 let bad=intervals(&build_plan(&badsets,&order));
 assert!(audit_superset(&bad,&badsets,&stale,&order).is_err());checks+=1;
 // A flagged gap becoming live remains algebraically covered, but must refresh
 // the plan's public provenance/required map before it is accepted.
 let mut refreshed=req.clone();refreshed[0][1]=true;let mut current=rho.clone();current[0][1]=Fp2::ONE;
 assert!(audit_superset(&p,&req,&current,&order).is_err());checks+=1;
 audit_superset(&p,&refreshed,&current,&order).unwrap();checks+=1;
 let matrix:Vec<_>=(1..=rows*3).map(|x|Fp::new(x as u64)).collect();
 assert_eq!(dense_reference(&current,&matrix,3),fold_hybrid(&p.iter().cloned().map(Hybrid::Runs).collect::<Vec<_>>(),&current,&matrix,3));checks+=1;
 for change in 0..7{
  let mut b=p.clone();match change{
   0=>b[0].runs[0].len=0,1=>b[0].runs[0].len=u32::MAX,
   2=>b[0].runs[0].word&=!15,3=>b[0].groups.swap(0,1),
   4=>{let s=b[0].runs[0].clone();b[0].runs.push(s);},
   5=>b.clear(),_=>b=omit_row(&p,8),
  }
  assert!(audit_superset(&b,&req,&rho,&order).is_err());checks+=1;
 }
 // Missing protected support is rejected even when its current numeric rho=0.
 let mut protected=req.clone();protected[1][7]=true;
 assert!(audit_superset(&p,&protected,&rho,&order).is_err());checks+=1;
 let protected_plan=gap_plan(&intervals(&build_plan(&protected,&order)),&protected,10000);
 audit_superset(&protected_plan,&protected,&rho,&order).unwrap();checks+=1;
 assert_eq!(dense_reference(&rho,&matrix,3),fold_hybrid(&protected_plan.iter().cloned().map(Hybrid::Runs).collect::<Vec<_>>(),&rho,&matrix,3));checks+=1;
 // Both different flags and intervening required rows prohibit coalescing.
 let mut extra=req.clone();extra[1][1]=true;
 let nojoin=gap_plan(&base,&extra,10000);assert_eq!(nojoin[0].runs.len(),2);checks+=1;
 checks
}

fn run_gap(case:usize,c:&Case,structural:&[Vec<bool>],rho:&[Vec<Fp2>],data:usize,prox:usize,seed:&mut u64)->String{
 let rows=rho[0].len();let width=if c.source{8}else{(1<<c.sh.log_cols)+3};
 let matrix:Vec<_>=(0..rows*width).map(|_|Fp::new(next(seed))).collect();
 let order:Vec<_>=(0..rho.len()).collect();let mut records=vec![];let mut comparisons=0;let mut controls=0;
 if case==0{controls+=gap_controls();}
 for mode in 0..5{
  let mut current=rho.to_vec();
  for g in 0..current.len(){for r in 0..rows{
   if mode==1&&structural[g][r]{current[g][r]=Fp2::new(Fp::ZERO,Fp::new(next(seed)|1));}
   if r<data && ((mode==2&&r%3==0)||(mode==3&&r%2==0)||(mode==4&&r%11<4)){current[g][r]=Fp2::ZERO;}
  }}
  // Do not remove structural mask/proximity support when coefficients cancel.
  let required:Vec<Vec<_>>=current.iter().enumerate().map(|(g,v)|v.iter().enumerate().map(|(r,w)|*w!=Fp2::ZERO||(r>=data&&structural[g][r])).collect()).collect();
  let base=intervals(&build_plan(&required,&order));let expected=dense_reference(&current,&matrix,width);
  let lists=build_plan(&required,&order);let hybrid=select_hybrid(&lists,&base,rows);
  assert_eq!(expected,fold_hybrid(&hybrid,&current,&matrix,width));comparisons+=rho.len()*width;
  let mut stats=vec![];
  for budget in [0u64,16,17,64,65,256,1000000]{
   let t=std::time::Instant::now();let p=gap_plan(&base,&required,budget);let plan_s=t.elapsed().as_secs_f64();
   let t=std::time::Instant::now();audit_superset(&p,&required,&current,&order).unwrap();let audit_s=t.elapsed().as_secs_f64();
   let(v,m,j)=gap_stats(&p);let(bv,bm,bj)=gap_stats(&base);
   if budget==0{assert_eq!((v,m,j),(bv,bm,bj));controls+=1;}
   let out=fold_hybrid(&p.iter().cloned().map(Hybrid::Runs).collect::<Vec<_>>(),&current,&matrix,width);
   assert_eq!(expected,out);comparisons+=rho.len()*width;
   let scalar_bytes=8*v+16*m+8*j;
   assert!(scalar_bytes>=8*bv+16*bm+8*bj); // Each accepted nonempty gap worsens this objective.
   stats.push(format!("{{\"budget\":{budget},\"visits\":{v},\"macs\":{m},\"spans\":{j},\"payload_B\":{},\"logical_B_per_col\":{scalar_bytes},\"extra_visits\":{},\"extra_macs\":{},\"removed_spans\":{},\"plan_s\":{plan_s},\"audit_s\":{audit_s}}}",8*j,v-bv,m-bm,bj-j));
  }
  let mut bad=base.clone();bad[0].runs.remove(0);assert!(audit_superset(&bad,&required,&current,&order).is_err());controls+=1;
  let missing=omit_row(&base,data);assert!(audit_superset(&missing,&required,&current,&order).is_err());controls+=1;
  let missing=omit_row(&base,prox);assert!(audit_superset(&missing,&required,&current,&order).is_err());controls+=1;
  let mut b=base.clone();b[0].groups.swap(0,1);assert!(audit_superset(&b,&required,&current,&order).is_err());controls+=1;
  let hbytes:usize=hybrid.iter().map(|b|match b{Hybrid::Dense(gs)=>rows*(8+16*gs.len()),Hybrid::List(b)=>12*b.words.len()+16*b.words.iter().map(|w|(w&15).count_ones()as usize).sum::<usize>(),Hybrid::Runs(b)=>b.runs.iter().map(|s|8+s.len as usize*(8+16*(s.word&15).count_ones()as usize)).sum()}).sum();
  let supports:Vec<Vec<u32>>=lists.iter().map(|b|b.words.clone()).collect();
  records.push(format!("{{\"mode\":{mode},\"required_words\":{supports:?},\"hybrid_logical_B_per_col\":{hbytes},\"stats\":[{}]}}",stats.join(",")));
 }
 format!("{{\"case\":{case},\"source\":{},\"dd\":{},\"challenge_mode\":{},\"rows\":{rows},\"data_rows\":{data},\"width\":{width},\"groups\":{},\"comparisons\":{comparisons},\"controls\":{controls},\"modes\":[{}]}}",c.source,c.sh.dd_cap>0,c.mode,rho.len(),records.join(","))
}
