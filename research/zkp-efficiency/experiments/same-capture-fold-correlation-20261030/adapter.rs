// Research-only normalized DRIVER trace adapter. No CUDA, proof or private values.
use std::collections::{BTreeMap, BTreeSet};
use std::io::{self, Read};

#[derive(Clone, Debug)]
struct Row { tag: String, v: Vec<u64> }

fn union(mut ranges: Vec<(u64,u64)>) -> Result<u64,String> {
    ranges.sort_unstable();
    let mut last = None; let mut total = 0u64;
    for (s,e) in ranges {
        match last {
            None => last=Some((s,e)),
            Some((a,b)) if s <= b => last=Some((a,b.max(e))),
            Some((a,b)) => {total=total.checked_add(b-a).ok_or("overflow")?; last=Some((s,e));}
        }
    }
    if let Some((a,b))=last {total=total.checked_add(b-a).ok_or("overflow")?;}
    Ok(total)
}

fn analyze(input: &str) -> Result<String,String> {
    let mut rows=Vec::new();
    for line in input.lines().filter(|x|!x.trim().is_empty()) {
        let mut it=line.split_whitespace(); let tag=it.next().ok_or("parse")?.to_string();
        let count=match tag.as_str(){"M"=>8,"C"=>10,"H"=>12,"A"=>13,"E"=>4,"G"=>12,_=>return Err("unknown record".into())};
        let v=it.map(|x|x.parse::<u64>().map_err(|_|"parse".to_string())).collect::<Result<Vec<_>,_>>()?;
        if v.len()!=count {return Err("arity".into());}
        rows.push(Row{tag,v});
    }
    let ms:Vec<_>=rows.iter().filter(|r|r.tag=="M").collect();
    if ms.len()!=1 || ms[0].v[0]==0 || ms[0].v[1]!=0 || ms[0].v[2]!=1 {return Err("capture completeness".into());}
    let cap=ms[0].v[0];
    if rows.iter().any(|r|r.v[0]!=cap) {return Err("mixed capture".into());}
    for (i,tag) in ["C","H","A","E","G"].iter().enumerate() {
        if rows.iter().filter(|r|r.tag==*tag).count() as u64 != ms[0].v[3+i] {return Err("manifest count".into());}
    }
    let mut calls=BTreeMap::new(); let mut hs=BTreeMap::new(); let mut apis=BTreeMap::new(); let mut es=BTreeMap::new(); let mut gs=Vec::new(); let mut ids=BTreeSet::new();
    for r in &rows { let v=&r.v; match r.tag.as_str() {
        // C cap pid fold tid device context stream rows n k; success/nonempty only
        "C"=>{
            if v[1..4].contains(&0) || v[5]==0 || v[7]==0 || !v[8].is_power_of_two() || !(1..=4).contains(&v[9]) {return Err("call metadata".into());}
            if calls.insert((v[1],v[2]),r).is_some(){return Err("duplicate call".into());}
        },
        // H cap pid external fold tid role device context stream host_start host_end reserved
        "H"=>{
            if v[1..6].contains(&0) || !(1..=3).contains(&v[5]) || v[7]==0 || v[9]>=v[10] || v[11]!=0 {return Err("host metadata".into());}
            if hs.insert((v[1],v[2]),r).is_some(){return Err("duplicate external".into());}
        },
        // A cap pid corr tid kind device context stream host_start host_end api_mode graph reserved
        "A"=>{
            if v[1..4].contains(&0) || !(1..=3).contains(&v[4]) || v[6]==0 || v[8]>=v[9] || v[10]!=1 || v[11]!=0 || v[12]!=0 {return Err("api metadata/unsupported mode".into());}
            if apis.insert((v[1],v[2]),r).is_some(){return Err("duplicate api".into());}
        },
        // E cap pid corr external (one configured external-correlation kind only)
        "E"=>{
            if v[1..].contains(&0) || es.insert((v[1],v[2]),v[3]).is_some(){return Err("duplicate/invalid mapping".into());}
        },
        // G cap pid activity corr kind device context stream gpu_start gpu_end graph reserved
        "G"=>{
            if v[1..4].contains(&0) || !(1..=3).contains(&v[4]) || v[6]==0 || v[8]==0 || v[8]>=v[9] || v[10]!=0 || v[11]!=0 {return Err("activity metadata/unsupported graph".into());}
            if !ids.insert((v[1],v[2])) {return Err("duplicate activity".into());}
            gs.push(r);
        }, "M"=>{}, _=>unreachable!()
    }}
    if hs.is_empty() || apis.is_empty() || gs.is_empty() || apis.len()!=es.len() {return Err("incomplete join".into());}
    let mut roster=BTreeSet::new(); let mut scopes:BTreeMap<_,Vec<_>>=BTreeMap::new();
    for h in hs.values() {
        let v=&h.v; let c=calls.get(&(v[1],v[3])).ok_or("unknown call")?; let cv=&c.v;
        if v[4]!=cv[3] || v[6..9]!=cv[4..7] || !roster.insert((v[1],v[3],v[5])) {return Err("call/phase mismatch".into());}
        scopes.entry((v[1],v[4])).or_default().push((v[9],v[10]));
    }
    if roster.len()!=calls.len()*3 {return Err("missing required phase".into());}
    for rs in scopes.values_mut() {
        rs.sort_unstable();
        if rs.windows(2).any(|w| w[0].1>w[1].0) {return Err("overlapping host scopes".into());}
    }
    let mut host_seen=BTreeSet::new(); let mut api_seen=BTreeSet::new(); let mut out=Vec::new();
    let mut host_ranges:BTreeMap<_,Vec<_>>=BTreeMap::new(); let mut device_ranges:BTreeMap<_,Vec<_>>=BTreeMap::new(); let mut role_ranges:BTreeMap<_,Vec<_>>=BTreeMap::new();
    for (key,a) in &apis {
        let ext=es.get(key).ok_or("missing mapping")?;
        let h=hs.get(&(key.0,*ext)).ok_or("unknown external")?;
        let av=&a.v; let hv=&h.v;
        if av[3]!=hv[4] || av[4]!=hv[5] || av[5..8]!=hv[6..9] || av[8]<hv[9] || av[9]>hv[10] {return Err("api/host mismatch".into());}
        host_seen.insert((key.0,*ext));
        host_ranges.entry((key.0,av[3])).or_default().push((av[8],av[9]));
    }
    if host_seen.len()!=hs.len() {return Err("unmatched host".into());}
    // Multiple activities per API and multiple APIs per wrapper are deliberate.
    for g in &gs {
        let v=&g.v; let key=(v[1],v[3]); let a=apis.get(&key).ok_or("orphan activity")?; let av=&a.v;
        if v[4..8]!=av[4..8] {return Err("activity/api mismatch".into());}
        let ext=es.get(&key).ok_or("missing mapping")?; let h=hs.get(&(key.0,*ext)).ok_or("unknown external")?;
        api_seen.insert(key);
        out.push((v[1],v[2],h.v[3],h.v[5],v[3]));
        device_ranges.entry(v[5]).or_default().push((v[8],v[9]));
        role_ranges.entry((v[5],h.v[5])).or_default().push((v[8],v[9]));
    }
    if api_seen.len()!=apis.len() {return Err("api without activity".into());}
    out.sort_unstable(); let mut s=String::new();
    for (pid,id,fold,role,corr) in out {s+=&format!("J {pid} {id} {fold} {role} {corr}\n");}
    for ((pid,tid),rs) in host_ranges {s+=&format!("H {pid} {tid} {}\n",union(rs)?);}
    for (dev,rs) in device_ranges {s+=&format!("D {dev} {}\n",union(rs)?);}
    for ((dev,role),rs) in role_ranges {s+=&format!("R {dev} {role} {}\n",union(rs)?);}
    Ok(s)
}
fn main(){
    let mut s=String::new(); io::stdin().read_to_string(&mut s).unwrap();
    // Each case is independent; failure retains the fixture and no joined totals.
    for (i,part) in s.split("\n---\n").enumerate(){
        match analyze(part){Ok(x)=>print!("CASE {i} OK\n{x}END\n"),Err(e)=>println!("CASE {i} ERR {e}\nEND")}
    }
}
