//! Research-only owned CPU evaluator. No CUDA, native transcript, PCS, extensions or full proof.
#[path="native/field.rs"] mod native_field;
mod native_mask;
use native_field::{Fp,Fp2,P};
use native_mask::CfsMask;
use std::collections::{BTreeMap,BTreeSet};
use std::io::{self,BufRead,Write};

#[derive(Clone)]
struct Job { site:u64, generation:u64, round:usize, degree:usize, tabs:Vec<Vec<Fp2>>,
    mask:CfsMask, c:Fp2, prev:Vec<Fp2>, pending:bool }
fn fp(it:&mut std::str::SplitWhitespace)->Result<Fp2,String>{
    let a=num(it)?; let b=num(it)?;
    if a>=P || b>=P {return Err("noncanonical".into())}
    Ok(Fp2::new(Fp(a),Fp(b)))
}
fn num(it:&mut std::str::SplitWhitespace)->Result<u64,String>{it.next().ok_or("missing")?.parse().map_err(|_|"integer".into())}
fn poly(v:&[Fp2],d:usize)->Fp2 {v[..d].iter().fold(Fp2::ONE,|a,x|a.mul(*x)).add(v[d])}
fn evaluate(j:&Job)->Vec<Fp2>{
    let h=j.tabs[0].len()/2; let k=j.tabs.len();
    let mut sums=vec![Fp2::ZERO;j.degree+1]; let mut cur=vec![Fp2::ZERO;k]; let mut diff=cur.clone();
    for i in 0..h {
        for t in 0..k {cur[t]=j.tabs[t][i];diff[t]=j.tabs[t][i+h].sub(cur[t]);}
        for x in 0..=j.degree {
            sums[x]=sums[x].add(poly(&cur,j.degree));
            for t in 0..k {cur[t]=cur[t].add(diff[t]);}
        }
    }
    sums
}
fn tag(it:&mut std::str::SplitWhitespace)->Result<(u64,u64,u64,usize),String>{Ok((num(it)?,num(it)?,num(it)?,num(it)? as usize))}
fn check(j:&Job,s:u64,g:u64,r:usize)->Result<(),String>{
    if (j.site,j.generation,j.round)!=(s,g,r){Err("ownership-or-round".into())}else{Ok(())}
}
fn end(it:&mut std::str::SplitWhitespace)->Result<(),String>{if it.next().is_some(){Err("trailing".into())}else{Ok(())}}
fn command(line:&str,jobs:&mut BTreeMap<u64,Job>,retired:&mut BTreeMap<u64,u64>)->Result<String,String>{
    let mut it=line.split_whitespace(); let op=it.next().ok_or("op")?;
    match op {
      "load"=>{
        let id=num(&mut it)?;let site=num(&mut it)?;let generation=num(&mut it)?;
        let n=num(&mut it)? as usize;let d=num(&mut it)? as usize;
        if jobs.contains_key(&id)||jobs.values().any(|x|x.site==site){return Err("live-owner-or-site".into())}
        if generation<=*retired.get(&id).unwrap_or(&0){return Err("stale-generation".into())}
        if !(1..=8).contains(&n)||!(2..=4).contains(&d){return Err("geometry".into())}
        let c=fp(&mut it)?;if c.is_zero(){return Err("zero-mask-challenge".into())}
        let coeffs=(0..n*d+2).map(|_|fp(&mut it)).collect::<Result<Vec<_>,_>>()?;
        let tabs=(0..=d).map(|_|(0..1usize<<n).map(|_|fp(&mut it)).collect::<Result<Vec<_>,_>>()).collect::<Result<Vec<_>,_>>()?;
        end(&mut it)?;
        jobs.insert(id,Job{site,generation,round:0,degree:d,tabs,mask:CfsMask{n_vars:n,degree:d,coeffs},c,prev:Vec::new(),pending:false});
        Ok("OK".into())
      },
      "eval"=>{
        let count=num(&mut it)? as usize;if count==0||count>4{return Err("batch-count".into())}
        let mut ids=BTreeSet::new();let mut tags=Vec::new();
        for _ in 0..count {
            let (id,s,g,r)=tag(&mut it)?;if !ids.insert(id){return Err("duplicate-owner".into())}
            let j=jobs.get(&id).ok_or("owner")?;check(j,s,g,r)?;
            if j.pending||j.tabs[0].len()==1{return Err("not-ready".into())}
            tags.push((id,s,g,r));
        }end(&mut it)?;
        let mut out=String::from("OK");
        for (id,s,g,r) in tags {
            let j=jobs.get_mut(&id).unwrap();let mut vals=evaluate(j);
            // Driver wrapper, outside the unmasked arithmetic evaluator. The
            // real SumcheckRounds contract leaves this to Transcript's masker.
            let gvals=j.mask.round(j.round,&j.prev);
            for (v,m) in vals.iter_mut().zip(gvals.iter()){*v=v.add(j.c.mul(*m));}
            j.pending=true;
            out.push_str(&format!(" | {id} {s} {g} {r}"));
            for v in vals {out.push_str(&format!(" {} {}",v.c0.0,v.c1.0));}
        }Ok(out)
      },
      "fold"=>{
        let count=num(&mut it)? as usize;if count==0||count>4{return Err("batch-count".into())}
        let mut ids=BTreeSet::new();let mut tags=Vec::new();
        for _ in 0..count {
            let (id,s,g,r)=tag(&mut it)?;let c=fp(&mut it)?;
            if !ids.insert(id){return Err("duplicate-owner".into())}
            let j=jobs.get(&id).ok_or("owner")?;check(j,s,g,r)?;
            if !j.pending{return Err("no-pending-round".into())}tags.push((id,c));
        }end(&mut it)?;
        for (id,c) in tags {
            let j=jobs.get_mut(&id).unwrap();let h=j.tabs[0].len()/2;
            for t in &mut j.tabs {for i in 0..h {t[i]=t[i].add(c.mul(t[i+h].sub(t[i])));}t.truncate(h);}
            j.prev.push(c);j.round+=1;j.pending=false;
        }Ok("OK".into())
      },
      "final"=>{
        let (id,s,g,r)=tag(&mut it)?;end(&mut it)?;let j=jobs.get(&id).ok_or("owner")?;check(j,s,g,r)?;
        if j.pending||j.tabs[0].len()!=1{return Err("not-complete".into())}
        let mut out=String::from("OK");for t in &j.tabs {out.push_str(&format!(" {} {}",t[0].c0.0,t[0].c1.0));}Ok(out)
      },
      "release"=>{
        let (id,s,g,r)=tag(&mut it)?;end(&mut it)?;let j=jobs.get(&id).ok_or("owner")?;check(j,s,g,r)?;
        if j.pending||j.tabs[0].len()!=1{return Err("lease-live".into())}
        jobs.remove(&id);retired.insert(id,g);Ok("OK".into())
      },
      _=>Err("op".into())
    }
}
fn main(){
    let mut jobs=BTreeMap::new();let mut retired=BTreeMap::new();
    for line in io::stdin().lock().lines(){let s=match command(&line.unwrap(),&mut jobs,&mut retired){Ok(s)=>s,Err(e)=>format!("ERR {e}")};println!("{s}");io::stdout().flush().unwrap();}
}
