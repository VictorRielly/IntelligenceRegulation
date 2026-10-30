fn query_context(sh:&Shape,a:&AccuracyPublic,gates:&[i64],outputs:&[i64])->Result<(),String> {
    let geometry=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    if geometry!=a.geometry() || gates.len()!=sh.size(Dom::F) || outputs.len()!=gates.len()
        || a.groups().len()*4096>sh.size(Dom::Tab) {
        return Err("R13 ACT: query geometry or one-row table bound mismatch".into());
    }
    Ok(())
}

fn query_group(sh:&Shape,a:&AccuracyPublic,index:usize)->usize {
    if index/sh.f_pad<sh.tokens && index%sh.f_pad<sh.hidden {a.group_ids()[index%sh.f_pad]} else {0}
}

/// Histogram includes every query, including padding. A miss is counted and
/// filed in bucket0, like the existing protocol; the caller's ordinary
/// refusal and test-only cheating-prover switch retain their meanings.
pub(crate) fn histogram(sh:&Shape,a:&AccuracyPublic,gates:&[i64],outputs:&[i64])->Result<(Vec<u64>,usize),String> {
    query_context(sh,a,gates,outputs)?;
    let mut counts=vec![0;a.groups().len()*4096];let mut misses=0;
    for (i,(&gate,&output)) in gates.iter().zip(outputs).enumerate() {
        let group=query_group(sh,a,i);
        let key=gate.checked_add(2048).filter(|&v|(0..4096).contains(&v)).map(|v|v as usize);
        let hit=key.filter(|&key|a.scaled_tables()[group][key]==output);
        let bucket=match hit {Some(key)=>group*4096+key,None=>{misses+=1;0}};
        counts[bucket]+=1;
    }
    Ok((counts,misses))
}

/// Field expression matches the ACT3 host polynomial even on a forged i64
/// gate: addition happens in the field, never through wrapping signed i64.
pub(crate) fn query_values(sh:&Shape,a:&AccuracyPublic,gates:&[i64],outputs:&[i64],beta:Fp2,tag:Fp2)->Result<Vec<Fp2>,String> {
    query_context(sh,a,gates,outputs)?;let beta2=beta.mul(beta);
    Ok(gates.iter().zip(outputs).enumerate().map(|(i,(&gate,&output))|
        Fp2::from_i64(gate).add(Fp2::from_i64(2048)).add(beta.mul(Fp2::from_i64(output)))
            .add(beta2.mul(Fp2::from_i64(query_group(sh,a,i) as i64))).add(tag)).collect())
}

