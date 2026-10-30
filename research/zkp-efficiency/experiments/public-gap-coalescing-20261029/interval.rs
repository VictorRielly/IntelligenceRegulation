// Independently authored public-plan model; no private matrix values enter planning.
#[derive(Clone,Debug)]
#[repr(C)]
struct Run { word:u32, len:u32 }
#[derive(Clone,Debug)]
struct IntervalBatch { groups:Vec<usize>, runs:Vec<Run> }
#[derive(Clone,Debug)]
enum Hybrid { Dense(Vec<usize>), List(BatchPlan), Runs(IntervalBatch) }

fn intervals(p:&[BatchPlan])->Vec<IntervalBatch> {
 p.iter().map(|b| {
  let mut runs:Vec<Run>=vec![];
  for &word in &b.words {
   let extend=runs.last().map_or(false,|s| (s.word&15)==(word&15) && (s.word>>4)+s.len==(word>>4));
   if extend {runs.last_mut().unwrap().len+=1;}else{runs.push(Run{word,len:1});}
  }
  IntervalBatch{groups:b.groups.clone(),runs}
 }).collect()
}

fn validate_intervals(p:&[IntervalBatch],sets:&[Vec<bool>],order:&[usize])->Result<(), &'static str> {
 let rows=sets[0].len();
 if rows >= 1usize<<28 || order.len()!=sets.len() || p.len()!=(order.len()+3)/4 {return Err("shape");}
 let mut seen=vec![false;sets.len()];
 for (b,gs) in p.iter().zip(order.chunks(4)) {
  if b.groups!=gs {return Err("order");}
  for &g in gs {if g>=sets.len()||seen[g]{return Err("groups");} seen[g]=true;}
  let mut decoded=vec![0u32;rows]; let mut last_end=0;let mut last_flags=0;
  for s in &b.runs {
   let start=(s.word>>4)as usize;let len=s.len as usize;let flags=s.word&15;
   let end=start.checked_add(len).ok_or("overflow")?;
   if len==0 || end>rows || start<last_end {return Err("span bound/overlap");}
   if flags==0 || flags >= 1u32<<gs.len(){return Err("flags");}
   if start==last_end && flags==last_flags {return Err("noncanonical");}
   for x in &mut decoded[start..end] {*x=flags;}
   last_end=end;last_flags=flags;
  }
  // Independently audit all rows, including masks and dense proximity.
  for r in 0..rows {for (i,&g) in gs.iter().enumerate(){
   if (decoded[r]&(1<<i)!=0)!=sets[g][r]{return Err("support");}
  }}
 }
 if seen.iter().any(|x|!*x){return Err("omitted group");} Ok(())
}

fn select_hybrid(lists:&[BatchPlan],runs:&[IntervalBatch],rows:usize)->Vec<Hybrid> {
 lists.iter().zip(runs).map(|(b,s)|{
  let union=b.words.len();let members:usize=b.words.iter().map(|w|(w&15).count_ones()as usize).sum();
  let dense=rows*(8+16*b.groups.len());
  let list=union*12+16*members;
  let run=union*8+16*members+s.runs.len()*8;
  // Source logical operands only, not a calibrated device-time optimum.
  if dense<=list && dense<=run{Hybrid::Dense(b.groups.clone())}
  else if list<=run{Hybrid::List(b.clone())}else{Hybrid::Runs(s.clone())}
 }).collect()
}

fn fold_hybrid(p:&[Hybrid],rhos:&[Vec<Fp2>],matrix:&[Fp],width:usize)->Vec<Vec<Ref>> {
 let mut out=vec![vec![(0,0);width];rhos.len()];let rows=rhos[0].len();
 for b in p {
  let gs=match b{Hybrid::Dense(g)=>g,Hybrid::List(b)=>&b.groups,Hybrid::Runs(b)=>&b.groups};
  for col in 0..width {
   let mut acc=[Fp2::ZERO;4];
   let mut visit=|r:usize,flags:u32|{
    let v=matrix[r*width+col];
    for(i,&g)in gs.iter().enumerate(){if flags&(1<<i)!=0{acc[i]=acc[i].add(rhos[g][r].mul_base(v));}}
   };
   match b {
    Hybrid::Dense(_)=>for r in 0..rows{visit(r,(1<<gs.len())-1);},
    Hybrid::List(b)=>for &w in &b.words{visit((w>>4)as usize,w&15);},
    Hybrid::Runs(b)=>for s in &b.runs{let start=(s.word>>4)as usize;for r in start..start+s.len as usize{visit(r,s.word&15);}},
   }
   for(i,&g)in gs.iter().enumerate(){out[g][col]=rr(acc[i]);}
  }
 }
 out
}

fn omit_row(p:&[IntervalBatch],row:usize)->Vec<IntervalBatch>{
 let mut p=p.to_vec();
 let b=p.iter_mut().find(|b|b.runs.iter().any(|s|{let a=(s.word>>4)as usize;a<=row&&row<a+s.len as usize})).unwrap();
 let i=b.runs.iter().position(|s|{let a=(s.word>>4)as usize;a<=row&&row<a+s.len as usize}).unwrap();
 let s=b.runs.remove(i);let a=(s.word>>4)as usize;let end=a+s.len as usize;let flags=s.word&15;
 let mut pieces=vec![];
 if a<row{pieces.push(Run{word:s.word,len:(row-a)as u32});}
 if row+1<end{pieces.push(Run{word:(((row+1)as u32)<<4)|flags,len:(end-row-1)as u32});}
 b.runs.splice(i..i,pieces);p
}

fn stress(seed:&mut u64)->(usize,usize){
 let(mut checks,mut controls)=(0,0);
 for k in 1..=9 {for pattern in 0..5 {
  let rows=41;let width=5;
  let sets:Vec<Vec<bool>>=(0..k).map(|g|(0..rows).map(|r|match pattern{
   0=>false,1=>true,2=>(r+g)%2==0,3=>r>=g&&r<g+3,_=>next(seed)%5==0,
  }).collect()).collect();
  let rhos:Vec<Vec<_>>=sets.iter().map(|s|s.iter().map(|v|if *v{random(seed)}else{Fp2::ZERO}).collect()).collect();
  let matrix:Vec<_>=(0..rows*width).map(|_|Fp::new(next(seed))).collect();let order:Vec<_>=(0..k).collect();
  let list=build_plan(&sets,&order);let runs=intervals(&list);validate_intervals(&runs,&sets,&order).unwrap();
  let hybrid=select_hybrid(&list,&runs,rows);
  let expected=dense_reference(&rhos,&matrix,width);
  assert_eq!(expected,fold_hybrid(&hybrid,&rhos,&matrix,width));checks+=k*width;
  let allruns:Vec<_>=runs.iter().cloned().map(Hybrid::Runs).collect();
  assert_eq!(expected,fold_hybrid(&allruns,&rhos,&matrix,width));checks+=k*width;
  if pattern==1{assert!(hybrid.iter().all(|b|matches!(b,Hybrid::Dense(_))));controls+=1;}
  if pattern==2&&k>=2{assert!(hybrid.iter().any(|b|matches!(b,Hybrid::List(_))));controls+=1;}
  if pattern==0{assert!(runs.iter().all(|b|b.runs.is_empty()));controls+=1;}
 }}
 (checks,controls)
}

fn run_interval(case:usize,c:&Case,sets:&[Vec<bool>],rhos:&[Vec<Fp2>],data:usize,prox:usize,seed:&mut u64)->String {
 assert_eq!(std::mem::size_of::<Run>(),8);
 let rows=sets[0].len();let width=if c.source{8}else{(1<<c.sh.log_cols)+3};
 let matrix:Vec<_>=(0..rows*width).map(|_|Fp::new(next(seed))).collect();
 let original:Vec<_>=(0..sets.len()).collect();let mut reverse=original.clone();reverse.reverse();
 let mut orders=vec![original.clone(),reverse];if c.source{orders.push(source_order(c.sh.dd_cap>0));}
 let(mut values,mut controls,mut summaries)=(0usize,0usize,vec![]);
 if case==0{let(v,k)=stress(seed);values+=v;controls+=k;}
 for(oi,order)in orders.iter().enumerate(){
  let lists=build_plan(sets,order);
  let t=std::time::Instant::now();let runs=intervals(&lists);let construct_s=t.elapsed().as_secs_f64();
  let t=std::time::Instant::now();validate_intervals(&runs,sets,order).unwrap();let validate_s=t.elapsed().as_secs_f64();
  let hybrid=select_hybrid(&lists,&runs,rows);
  let allruns:Vec<_>=runs.iter().cloned().map(Hybrid::Runs).collect();
  let dense:Vec<_>=order.chunks(4).map(|g|Hybrid::Dense(g.to_vec())).collect();
  let mut numeric_stats=vec![];
  for mode in 0..3{
   let mut current=rhos.to_vec();
   if mode==1{for(g,rho)in current.iter_mut().enumerate(){for r in 0..rows{rho[r]=if sets[g][r]{Fp2::new(Fp::ZERO,Fp::new(next(seed)))}else{Fp2::ZERO};}}}
   if mode==2{for rho in &mut current{for r in(0..rows).step_by(3){rho[r]=Fp2::ZERO;}}}
   let expected=dense_reference(&current,&matrix,width);
   assert_eq!(expected,indexed_fold(&lists,&current,&matrix,width,true));values+=sets.len()*width;
   for p in [&allruns,&hybrid,&dense]{assert_eq!(expected,fold_hybrid(p,&current,&matrix,width));values+=sets.len()*width;}
   let numeric=build_public_rho_plan(&current,order);let numeric_runs=intervals(&numeric);
   let numeric_sets:Vec<Vec<bool>>=current.iter().map(|rho|rho.iter().map(|w|rr(*w)!=(0,0)).collect()).collect();
   validate_intervals(&numeric_runs,&numeric_sets,order).unwrap();
   let numeric_modes=select_hybrid(&numeric,&numeric_runs,rows);
   let numeric_words:usize=numeric.iter().map(|b|b.words.len()).sum();
   let numeric_spans:usize=numeric_runs.iter().map(|b|b.runs.len()).sum();
   let numeric_payload:usize=numeric_modes.iter().map(|b|match b{Hybrid::Dense(_)=>0,Hybrid::List(b)=>4*b.words.len(),Hybrid::Runs(b)=>8*b.runs.len()}).sum();
   numeric_stats.push(format!("{{\"mode\":{mode},\"words\":{numeric_words},\"runs\":{numeric_spans},\"hybrid_payload_B\":{numeric_payload}}}"));
   assert_eq!(expected,fold_hybrid(&select_hybrid(&numeric,&numeric_runs,rows),&current,&matrix,width));values+=sets.len()*width;
   if mode==1{assert!(expected.iter().flatten().any(|v|*v!=(0,0)));controls+=1;}
  }
  let mut reject=|p:Vec<IntervalBatch>|{assert!(validate_intervals(&p,sets,order).is_err());controls+=1;};
  let mut bad=runs.clone();bad[0].runs.remove(0);reject(bad);
  let mut bad=runs.clone();bad[0].runs[0].len=0;reject(bad);
  let mut bad=runs.clone();bad[0].runs[0].len=u32::MAX;reject(bad);
  let mut bad=runs.clone();let first=bad[0].runs[0].clone();bad[0].runs.insert(0,first);reject(bad);
  let mut bad=runs.clone();bad[0].runs[0].word=((rows as u32)<<4)|1;reject(bad);
  let mut bad=runs.clone();bad[0].runs[0].word&=!15;reject(bad);
  let mut bad=runs.clone();bad[0].runs[0].word^=1;reject(bad);
  let mut bad=runs.clone();bad[0].groups.swap(0,1);reject(bad);
  let mut bad=runs.clone();bad.pop();reject(bad);
  reject(omit_row(&runs,data));reject(omit_row(&runs,prox));
  let mut bad=runs.clone();let bi=bad.iter().position(|b|b.runs.iter().any(|r|r.len>1)).unwrap();let ri=bad[bi].runs.iter().position(|r|r.len>1).unwrap();bad[bi].runs[ri].len-=1;reject(bad);
  if oi>0{assert!(validate_intervals(&runs,sets,&original).is_err());controls+=1;}
  let expected=dense_reference(rhos,&matrix,width);let mut wrong=fold_hybrid(&hybrid,rhos,&matrix,width);let last=wrong.len()-1;wrong.swap(0,last);assert_ne!(expected,wrong);controls+=1;
  let spans:Vec<Vec<(u32,u32)>>=runs.iter().map(|b|b.runs.iter().map(|s|(s.word,s.len)).collect()).collect();
  let modes:Vec<_>=hybrid.iter().map(|b|match b{Hybrid::Dense(_)=>0,Hybrid::List(_)=>1,Hybrid::Runs(_)=>2}).collect();
  let counts:Vec<_>=lists.iter().zip(&runs).map(|(b,s)|{
   let members:usize=b.words.iter().map(|w|(w&15).count_ones()as usize).sum();
   format!("{{\"groups\":{},\"union\":{},\"members\":{},\"runs\":{}}}",b.groups.len(),b.words.len(),members,s.runs.len())
  }).collect();
  summaries.push(format!("{{\"order\":{order:?},\"spans\":{},\"modes\":{modes:?},\"batches\":[{}],\"numeric_stats\":[{}],\"construct_s\":{construct_s},\"validate_s\":{validate_s}}}",format!("{spans:?}").replace('(',"[").replace(')',"]"),counts.join(","),numeric_stats.join(",")));
 }
 format!("{{\"case\":{case},\"source\":{},\"dd\":{},\"mode\":{},\"rows\":{rows},\"width\":{width},\"rho_vectors\":{},\"checked_values\":{values},\"controls\":{controls},\"plans\":[{}]}}",c.source,c.sh.dd_cap>0,c.mode,rhos.len(),summaries.join(","))
}
