// Independently authored CPU model of a possible public-plan CUDA loop.
// Only verifier-public structural support enters the plan. No matrix values do.
#[derive(Clone, Debug)]
struct BatchPlan { groups: Vec<usize>, words: Vec<u32> }

fn build_plan(sets: &[Vec<bool>], order: &[usize]) -> Vec<BatchPlan> {
    assert!(sets[0].len() < (1usize << 28));
    order.chunks(4).map(|gs| {
        let mut words = Vec::new();
        for r in 0..sets[0].len() {
            let flags = gs.iter().enumerate().fold(0u32, |a,(i,g)| a | ((sets[*g][r] as u32) << i));
            if flags != 0 { words.push(((r as u32) << 4) | flags); }
        }
        BatchPlan { groups: gs.to_vec(), words }
    }).collect()
}

fn validate_plan(plan: &[BatchPlan], sets: &[Vec<bool>], order: &[usize]) -> Result<(), &'static str> {
    let rows=sets[0].len();
    let mut seen_groups=vec![false;sets.len()];
    if order.len()!=sets.len() || plan.len()!=(order.len()+3)/4 { return Err("group count"); }
    for (b,gs) in plan.iter().zip(order.chunks(4)) {
        if b.groups!=gs { return Err("logical order"); }
        for g in &b.groups {
            if *g>=sets.len() || seen_groups[*g] { return Err("group identity"); }
            seen_groups[*g]=true;
        }
        let mut decoded=vec![0u8;rows];
        let mut last=None;
        for w in &b.words {
            let r=(*w >> 4) as usize; let flags=(*w & 15) as u8;
            if r>=rows { return Err("row bound"); }
            if last.map_or(false, |x| r<=x) { return Err("sorted unique"); }
            if flags==0 || (flags as usize)>=(1usize<<b.groups.len()) { return Err("flags"); }
            decoded[r]=flags; last=Some(r);
        }
        // A separate membership audit, including every reserved mask/proximity row.
        for (i,g) in b.groups.iter().enumerate() {
            for r in 0..rows {
                if ((decoded[r]>>i)&1 != 0)!=sets[*g][r] { return Err("support mismatch"); }
            }
        }
    }
    if seen_groups.iter().any(|v| !v) { return Err("omitted group"); }
    Ok(())
}

fn indexed_fold(plan: &[BatchPlan], rhos: &[Vec<Fp2>], matrix: &[Fp], width: usize, membership: bool) -> Vec<Vec<Ref>> {
    let mut out=vec![vec![(0,0);width];rhos.len()];
    for b in plan {
        for col in 0..width {
            let mut acc=[Fp2::ZERO;4];
            for word in &b.words {
                let r=(*word>>4) as usize; let flags=*word&15;
                let v=matrix[r*width+col];
                for (i,g) in b.groups.iter().enumerate() {
                    if !membership || flags&(1<<i)!=0 { acc[i]=acc[i].add(rhos[*g][r].mul_base(v)); }
                }
            }
            for (i,g) in b.groups.iter().enumerate() { out[*g][col]=rr(acc[i]); }
        }
    }
    out
}

fn dense_reference(rhos: &[Vec<Fp2>], matrix: &[Fp], width: usize) -> Vec<Vec<Ref>> {
    rhos.iter().map(|rho| (0..width).map(|col| {
        rho.iter().enumerate().fold((0,0),|a,(r,w)| ra(a,rm(rr(*w),(matrix[r*width+col].0,0))))
    }).collect()).collect()
}

fn run_indexed(case:usize,c:&Case,sets:&[Vec<bool>],rhos:&[Vec<Fp2>],data:usize,prox:usize,seed:&mut u64)->String {
    let rows=sets[0].len(); let width=if c.source{8}else{(1<<c.sh.log_cols)+3};
    let matrix:Vec<_>=(0..rows*width).map(|_|Fp::new(next(seed))).collect();
    let original:Vec<_>=(0..sets.len()).collect();
    let mut reverse=original.clone(); reverse.reverse();
    let mut orders=vec![original.clone(),reverse];
    if c.source { orders.push(source_order(c.sh.dd_cap>0)); }
    let(mut values,mut controls,mut plans)=(0usize,0usize,Vec::new());
    for (oi,order) in orders.iter().enumerate() {
        let start=std::time::Instant::now(); let plan=build_plan(sets,order); let construct_s=start.elapsed().as_secs_f64();
        let start=std::time::Instant::now(); validate_plan(&plan,sets,order).unwrap(); let validate_s=start.elapsed().as_secs_f64();
        for mode in 0..3 {
            let mut current=rhos.to_vec();
            if mode==1 { for (g,rho) in current.iter_mut().enumerate(){for r in 0..rows{rho[r]=if sets[g][r]{Fp2::new(Fp::ZERO,Fp::new(next(seed)))}else{Fp2::ZERO};}} }
            if mode==2 { for rho in &mut current {for r in (0..rows).step_by(3){rho[r]=Fp2::ZERO;}} }
            let expected=dense_reference(&current,&matrix,width);
            assert_eq!(expected,indexed_fold(&plan,&current,&matrix,width,false)); values+=sets.len()*width;
            assert_eq!(expected,indexed_fold(&plan,&current,&matrix,width,true)); values+=sets.len()*width;
            if mode==1 {assert!(expected.iter().flatten().any(|x|*x!=(0,0)));controls+=1;}
            // Planning is independent of synthetic private matrix and numerical rho values.
            assert_eq!(plan.iter().map(|b|&b.words).collect::<Vec<_>>(),build_plan(sets,order).iter().map(|b|&b.words).collect::<Vec<_>>());
        }
        let mut reject=|p:Vec<BatchPlan>|{assert!(validate_plan(&p,sets,order).is_err());controls+=1;};
        let mut bad=plan.clone();bad[0].words.remove(0);reject(bad);
        let mut bad=plan.clone();bad[0].words.insert(0,bad[0].words[0]);reject(bad);
        let mut bad=plan.clone();bad[0].words.push(((rows as u32)<<4)|1);reject(bad);
        let mut bad=plan.clone();bad[0].words.swap(0,1);reject(bad);
        let mut bad=plan.clone();bad[0].words[0]&=!15;reject(bad);
        let mut bad=plan.clone();bad[0].words[0]^=1;reject(bad);
        let mut bad=plan.clone();bad[0].groups.swap(0,1);reject(bad);
        let mut bad=plan.clone();bad.pop();reject(bad);
        let mut bad=plan.clone();let b=bad.iter_mut().find(|b|b.words.iter().any(|w|(*w>>4)as usize>=data&&((*w>>4)as usize)<prox)).unwrap();
        let i=b.words.iter().position(|w|(*w>>4)as usize>=data&&((*w>>4)as usize)<prox).unwrap();b.words.remove(i);reject(bad);
        let mut bad=plan.clone();let b=bad.iter_mut().find(|b|b.groups.contains(&(sets.len()-1))).unwrap();let i=b.words.iter().position(|w|(*w>>4)as usize==prox).unwrap();b.words.remove(i);reject(bad);
        // Wrong scatter is observable even though each physical batch computed correctly.
        let expected=dense_reference(rhos,&matrix,width);let mut wrong=indexed_fold(&plan,rhos,&matrix,width,true);let end=wrong.len()-1;wrong.swap(0,end);assert_ne!(expected,wrong);controls+=1;
        // Reusing an original-order plan under a different current grouping is refused.
        if oi>0{assert!(validate_plan(&plan,sets,&original).is_err());controls+=1;}
        let union:usize=plan.iter().map(|b|b.words.len()).sum();
        let rho_union:usize=plan.iter().map(|b|b.groups.len()*b.words.len()).sum();
        let rho_flags:usize=plan.iter().flat_map(|b|&b.words).map(|w|(w&15).count_ones()as usize).sum();
        let words:Vec<_>=plan.iter().map(|b|b.words.clone()).collect();
        plans.push(format!("{{\"order\":{order:?},\"union_visits\":{union},\"rho_union_reads_per_column\":{rho_union},\"rho_membership_reads_per_column\":{rho_flags},\"index_bytes\":{},\"construct_s\":{construct_s},\"validate_s\":{validate_s},\"words\":{words:?}}}",union*4));
    }
    format!("{{\"case\":{case},\"source\":{},\"dd\":{},\"mode\":{},\"rows\":{rows},\"width\":{width},\"rho_vectors\":{},\"checked_values\":{values},\"controls\":{controls},\"plans\":[{}]}}",c.source,c.sh.dd_cap>0,c.mode,rhos.len(),plans.join(","))
}
