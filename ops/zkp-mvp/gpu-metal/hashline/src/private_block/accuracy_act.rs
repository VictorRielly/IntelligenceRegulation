//! Verifier-derived public columns for R13's three-coordinate ACT lookup.
use super::accuracy_public::{AccuracyPublic,Geometry};
use super::layout::Dom;
use super::shape::Shape;
use crate::field::{Fp,Fp2};

pub(crate) struct ActTable {
    pub(crate) compressed:Vec<Fp2>,
    pub(crate) support:Vec<Fp2>,
    pub(crate) entries:usize,
}

pub(crate) fn table(a:&AccuracyPublic,len:usize,beta:Fp2,tag:Fp2)->Result<ActTable,String> {
    let entries=a.groups().len().checked_mul(4096).ok_or("R13 ACT: table size overflow")?;
    if !len.is_power_of_two() || !(4096..=16384).contains(&entries) || entries>len {
        return Err("R13 ACT: one to four registered tables must fit in exactly one row".into());
    }
    let beta2=beta.mul(beta);
    let zero=Fp2::from_i64(2048).add(tag);
    let mut compressed=vec![zero;len];let mut support=vec![Fp2::ZERO;len];
    for (group,words) in a.scaled_tables().iter().enumerate() {
        if words.len()!=4096 || words[2048]!=0 {return Err("R13 ACT: invalid generated table shape/zero row".into());}
        let group_term=beta2.mul(Fp2::from_i64(group as i64));
        for (gate,&word) in words.iter().enumerate() {
            let i=group*4096+gate;
            compressed[i]=Fp2::from_i64(gate as i64).add(beta.mul(Fp2::from_i64(word))).add(group_term).add(tag);
            support[i]=Fp2::ONE;
        }
    }
    Ok(ActTable{compressed,support,entries})
}

pub(crate) fn group_column(sh:&Shape,a:&AccuracyPublic)->Result<Vec<Fp2>,String> {
    let geometry=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    if geometry!=a.geometry() {return Err("R13 ACT: geometry context mismatch".into());}
    let mut out=vec![Fp2::ZERO;sh.size(Dom::F)];
    for t in 0..sh.tokens {for j in 0..sh.hidden {
        out[t*sh.f_pad+j]=Fp2::from_i64(a.group_ids()[j] as i64);
    }}
    Ok(out)
}

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
/// [ZK60-METAL M15] counted over 64 Ki-query chunks in parallel and summed:
/// counts and misses are integers, so the totals are the sequential loop's.
pub(crate) fn histogram(sh:&Shape,a:&AccuracyPublic,gates:&[i64],outputs:&[i64])->Result<(Vec<u64>,usize),String> {
    use rayon::prelude::*;
    query_context(sh,a,gates,outputs)?;
    const CH:usize=1<<16;
    let nb=a.groups().len()*4096;
    let (counts,misses)=gates.par_chunks(CH).zip(outputs.par_chunks(CH)).enumerate().map(|(ci,(gs,os))| {
        let mut counts=vec![0u64;nb];let mut misses=0usize;
        for (k,(&gate,&output)) in gs.iter().zip(os).enumerate() {
            let group=query_group(sh,a,ci*CH+k);
            let key=gate.checked_add(2048).filter(|&v|(0..4096).contains(&v)).map(|v|v as usize);
            let hit=key.filter(|&key|a.scaled_tables()[group][key]==output);
            let bucket=match hit {Some(key)=>group*4096+key,None=>{misses+=1;0}};
            counts[bucket]+=1;
        }
        (counts,misses)
    }).reduce(||(vec![0u64;nb],0usize),|(mut x,mx),(y,my)| {for (a,b) in x.iter_mut().zip(y) {*a+=b;} (x,mx+my)});
    Ok((counts,misses))
}

/// Field expression matches the ACT3 host polynomial even on a forged i64
/// gate: addition happens in the field, never through wrapping signed i64.
/// [ZK60-METAL M5b, researcher H114] an INDEXED parallel map: every query is
/// the same element at the same index as the sequential form (one per F-cube
/// position, 2^21 at the trained T128 shapes), so no byte moves.
pub(crate) fn query_values(sh:&Shape,a:&AccuracyPublic,gates:&[i64],outputs:&[i64],beta:Fp2,tag:Fp2)->Result<Vec<Fp2>,String> {
    use rayon::prelude::*;
    query_context(sh,a,gates,outputs)?;let beta2=beta.mul(beta);
    Ok(gates.par_iter().zip(outputs.par_iter()).enumerate().map(|(i,(&gate,&output))|
        Fp2::from_i64(gate).add(Fp2::from_i64(2048)).add(beta.mul(Fp2::from_i64(output)))
            .add(beta2.mul(Fp2::from_i64(query_group(sh,a,i) as i64))).add(tag)).collect())
}

/// **[ZK60-METAL M15]** `alpha - query_values(..)[i]` for every query, in
/// ONE parallel pass over the F domain's rows: the group term `beta^2 *
/// group` is formed once per column (`query_group` is `group_ids[j]` on a row
/// `t < tokens` and a column `j < hidden`, else 0), so no element pays the two
/// divisions `query_group` makes, and no intermediate vector is collected. The
/// same field expression per element (field addition is exact), so the same
/// words; the same context refusal.
pub(crate) fn denominators(sh:&Shape,a:&AccuracyPublic,gates:&[i64],outputs:&[i64],alpha:Fp2,beta:Fp2,tag:Fp2)->Result<Vec<Fp2>,String> {
    use rayon::prelude::*;
    query_context(sh,a,gates,outputs)?;let beta2=beta.mul(beta);
    let fp=sh.f_pad;
    if fp==0 || gates.len()%fp!=0 {return Err("R13 ACT: query rows".into());}
    let col:Vec<Fp2>=(0..fp).map(|j| if j<sh.hidden {beta2.mul(Fp2::from_i64(a.group_ids()[j] as i64))} else {beta2.mul(Fp2::from_i64(0))}).collect();
    let zero_group=beta2.mul(Fp2::from_i64(0));
    let mut out=vec![Fp2::ZERO;gates.len()];
    out.par_chunks_mut(fp).zip(gates.par_chunks(fp)).zip(outputs.par_chunks(fp)).enumerate().for_each(|(t,((o,g),u))| {
        let live=t<sh.tokens;
        for j in 0..fp {
            let grp=if live {col[j]} else {zero_group};
            let q=Fp2::from_i64(g[j]).add(Fp2::from_i64(2048)).add(beta.mul(Fp2::from_i64(u[j]))).add(grp).add(tag);
            o[j]=alpha.sub(q);
        }
    });
    Ok(out)
}

/// **[HOST-FAST H1]** Write `1 / (alpha - query_values(..)[i])` directly into
/// `H`'s `(re, im)` slices from the pre-inverted active table `act_inv`
/// (`act_inv[k] = 1 / (alpha - table.compressed[k])` for `k < table.entries`).
///
/// Precondition (enforced by caller): [`histogram`] returned `misses == 0` on
/// the same `(sh, a, gates, outputs)`. That guarantees every `(t, j)` in
/// `Dom::F` has `key = (gates[t * f_pad + j] + 2048)` in `0..4096`,
/// `group = if t < tokens && j < hidden { group_ids[j] } else { 0 }`, and
/// `outputs[t * f_pad + j] == scaled_tables[group][key]`, so
/// `alpha - query_values(..)[i] == alpha - table.compressed[group * 4096 + key]`
/// identically. All shape/context checks match [`denominators`].
pub(crate) fn write_helpers_from_inv(
    sh: &Shape,
    a: &AccuracyPublic,
    gates: &[i64],
    outputs: &[i64],
    act_inv: &[Fp2],
    re: &mut [Fp],
    im: &mut [Fp],
) -> Result<(), String> {
    use rayon::prelude::*;
    query_context(sh, a, gates, outputs)?;
    let fp = sh.f_pad;
    let need = a.groups().len() * 4096;
    if fp == 0
        || gates.len() % fp != 0
        || re.len() != gates.len()
        || im.len() != gates.len()
        || act_inv.len() < need
    {
        return Err("R13 ACT: query rows".into());
    }
    let live_cols = sh.hidden.min(fp);
    let group_bases: Vec<usize> = a.group_ids()[..live_cols].iter().map(|&g| g * 4096).collect();
    let fill_row = |t: usize, r: &mut [Fp], m: &mut [Fp], g: &[i64]| {
        if t < sh.tokens {
            for j in 0..live_cols {
                let v = act_inv[group_bases[j] + (g[j] + 2048) as usize];
                r[j] = v.c0;
                m[j] = v.c1;
            }
            for j in live_cols..fp {
                let v = act_inv[(g[j] + 2048) as usize];
                r[j] = v.c0;
                m[j] = v.c1;
            }
        } else {
            for j in 0..fp {
                let v = act_inv[(g[j] + 2048) as usize];
                r[j] = v.c0;
                m[j] = v.c1;
            }
        }
    };
    if gates.len() >= 1 << 14 {
        re.par_chunks_mut(fp)
            .zip(im.par_chunks_mut(fp))
            .zip(gates.par_chunks(fp))
            .enumerate()
            .for_each(|(t, ((r, m), g))| fill_row(t, r, m, g));
    } else {
        for (t, ((r, m), g)) in re.chunks_mut(fp).zip(im.chunks_mut(fp)).zip(gates.chunks(fp)).enumerate() {
            fill_row(t, r, m, g);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_precision::{Stack,BaseShifts};
    use crate::private_block::accuracy_public::Multipliers;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_tables::silu_table;

    fn fixture()->(Shape,AccuracyPublic) {
        let sh=Shape::new("R13 ACT pad fixture","r13-act-pad-fixture",24,48,6,6,8,2,8,8,9,13,None,None,None,None).unwrap();
        let m=Multipliers{q:vec![1;48],k:vec![1;16],v:vec![1;16],o:vec![1;48],g:vec![1;6],u:vec![1;6],d:vec![1;48]};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-1,e_out:-11}];
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let a=AccuracyPublic::new(Stack::LowH24,Geometry{width:48,query_width:48,kv_width:16,hidden:6},
            BaseShifts{norm_tn:10,qkv:8,score:6,pv:9,ao:7,gate:8,up:0,product:14,down:6},
            (-3,-11),m,groups,vec![0,1,0,1,0,1],tables).unwrap();
        (sh,a)
    }

    #[test]
    fn every_three_coordinate_row_matches_its_generated_scaled_table() {
        let (_,a)=fixture();let beta=Fp2::from_i64(7);let tag=Fp2::from_i64(31);
        let table=table(&a,16384,beta,tag).unwrap();
        assert_eq!(table.entries,8192);
        for group in 0..2 {for index in 0..4096 {
            let expected=Fp2::from_i64(index as i64).add(beta.mul(Fp2::from_i64(a.scaled_tables()[group][index])))
                .add(beta.mul(beta).mul(Fp2::from_i64(group as i64))).add(tag);
            assert_eq!(table.compressed[group*4096+index],expected);
        }}
        assert!(table.support[..8192].iter().all(|&v|v==Fp2::ONE));
        assert!(table.support[8192..].iter().all(|&v|v==Fp2::ZERO));
        assert!(table.compressed[8192..].iter().all(|&v|v==Fp2::from_i64(2048).add(tag)));
        // The ACT-specific support covers entries above 255, while its own
        // zero padding still starts exactly at groups*4096.
        assert_eq!(table.support[256],Fp2::ONE);
    }

    #[test]
    fn group_coordinate_separates_colliding_gate_zero_outputs() {
        let (_,a)=fixture();let beta=Fp2::from_i64(7);
        let t=table(&a,8192,beta,Fp2::ZERO).unwrap();
        assert_eq!(a.scaled_tables()[0][2048],a.scaled_tables()[1][2048]);
        assert_ne!(t.compressed[2048],t.compressed[4096+2048]);
        assert_eq!(t.compressed[4096+2048].sub(t.compressed[2048]),beta.mul(beta));
    }

    #[test]
    fn query_group_padding_is_the_valid_zero_gate_zero_output_group_zero_row() {
        let (sh,a)=fixture();let column=group_column(&sh,&a).unwrap();
        assert_eq!(column.len(),sh.size(Dom::F));
        for t in 0..sh.t_pad {for j in 0..sh.f_pad {
            let expected=if t<sh.tokens && j<sh.hidden {a.group_ids()[j]} else {0};
            assert_eq!(column[t*sh.f_pad+j],Fp2::from_i64(expected as i64));
        }}
        let t=table(&a,16384,Fp2::from_i64(7),Fp2::from_i64(31)).unwrap();
        assert_eq!(t.compressed[2048],t.compressed[t.entries]);
        assert!(table(&a,4096,Fp2::ONE,Fp2::ZERO).is_err());
        assert!(table(&a,8193,Fp2::ONE,Fp2::ZERO).is_err());
    }
    /// [M15] the parallel histogram is the sequential count, misses included
    #[test]
    fn m15_parallel_histogram_equals_the_sequential_count() {
        let (sh,a)=native_query_fixture();
        let n=sh.size(Dom::F);
        // gates in and out of the table's range, outputs that hit and miss
        let gates:Vec<i64>=(0..n).map(|i|((i*37+11)%5000) as i64-2400).collect();
        let outputs:Vec<i64>=(0..n).map(|i| {
            let g=((i*37+11)%5000) as i64-2400;
            let key=g+2048;
            if i%3!=0 && (0..4096).contains(&key) {a.scaled_tables()[query_group(&sh,&a,i)][key as usize]} else {(i as i64)%977-400}
        }).collect();
        let mut counts=vec![0u64;a.groups().len()*4096];let mut misses=0usize;
        for (i,(&gate,&output)) in gates.iter().zip(&outputs).enumerate() {
            let group=query_group(&sh,&a,i);
            let key=gate.checked_add(2048).filter(|&v|(0..4096).contains(&v)).map(|v|v as usize);
            let hit=key.filter(|&key|a.scaled_tables()[group][key]==output);
            let bucket=match hit {Some(key)=>group*4096+key,None=>{misses+=1;0}};
            counts[bucket]+=1;
        }
        assert!(misses>0 && counts.iter().filter(|c|**c>0).count()>1, "the fixture hits and misses");
        assert_eq!(histogram(&sh,&a,&gates,&outputs).unwrap(),(counts,misses));
    }

    /// [M15] the fused denominators are `alpha - query_values`, word for word,
    /// on the padded native fixture (padding rows and columns included)
    #[test]
    fn m15_fused_denominators_equal_alpha_minus_the_queries() {
        let (sh,a)=native_query_fixture();
        let n=sh.size(Dom::F);
        let gates:Vec<i64>=(0..n).map(|i|((i*37+11)%4096) as i64-2048).collect();
        let outputs:Vec<i64>=(0..n).map(|i|((i*101+7)%9000) as i64-4500).collect();
        let (alpha,beta,tag)=(Fp2::new(crate::field::Fp::new(123_456_789),crate::field::Fp::new(42)),Fp2::from_i64(7),Fp2::from_i64(31));
        let want:Vec<Fp2>=query_values(&sh,&a,&gates,&outputs,beta,tag).unwrap().into_iter().map(|q|alpha.sub(q)).collect();
        assert!(denominators(&sh,&a,&gates,&outputs,alpha,beta,tag).unwrap()==want);
    }
    fn native_query_fixture()->(Shape,AccuracyPublic) {
        let sh=crate::private_block::accuracy_profile_tests::registered_shapes().into_iter()
            .find(|s|s.profile==crate::private_block::shape::R13_RUNG_H24).unwrap();
        let geo=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
        let m=Multipliers{q:vec![1;geo.query_width],k:vec![1;geo.kv_width],v:vec![1;geo.kv_width],o:vec![1;geo.width],
            g:vec![1;geo.hidden],u:vec![1;geo.hidden],d:vec![1;geo.width]};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-1,e_out:-11}];
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let a=AccuracyPublic::new(sh.accuracy_stack(),geo,sh.accuracy_base(),(-3,-11),m,groups,
            (0..geo.hidden).map(|i|i%2).collect(),tables).unwrap();
        assert_eq!(a.folds().gate.shift,sh.accuracy_gate_shift);
        (sh,a)
    }

    #[test]
    fn histogram_and_compressed_queries_count_real_and_padded_groups_without_aliasing() {
        let(sh,a)=native_query_fixture();let gates=vec![0;sh.size(Dom::F)];let outputs=gates.clone();
        let (counts,misses)=histogram(&sh,&a,&gates,&outputs).unwrap();assert_eq!(misses,0);
        let ones=sh.tokens*(sh.hidden/2);
        assert_eq!(counts[4096+2048],ones as u64);assert_eq!(counts[2048],(gates.len()-ones) as u64);
        assert_eq!(counts.iter().sum::<u64>(),gates.len() as u64);
        let beta=Fp2::from_i64(7);let tag=Fp2::from_i64(31);
        let q=query_values(&sh,&a,&gates,&outputs,beta,tag).unwrap();let t=table(&a,sh.size(Dom::Tab),beta,tag).unwrap();
        for (i,&value) in q.iter().enumerate() {let group=query_group(&sh,&a,i);assert_eq!(value,t.compressed[group*4096+2048]);}
    }

    #[test]
    fn signed_endpoints_are_exact_and_invalid_queries_are_counted_without_panics() {
        let(sh,a)=native_query_fixture();let mut gates=vec![0;sh.size(Dom::F)];let mut outputs=gates.clone();
        for gate in [-2048,2047] {
            gates[0]=gate;outputs[0]=a.scaled_tables()[0][(gate+2048) as usize];
            assert_eq!(histogram(&sh,&a,&gates,&outputs).unwrap().1,0);
        }
        for gate in [-2049,2048,i64::MIN,i64::MAX] {
            gates[0]=gate;let (counts,misses)=histogram(&sh,&a,&gates,&outputs).unwrap();
            assert_eq!(misses,1);assert_eq!(counts[0],1);
            // No overflowing gate+2048 integer operation in the field query.
            let values=query_values(&sh,&a,&gates,&outputs,Fp2::from_i64(7),Fp2::ZERO).unwrap();
            assert_eq!(values[0],Fp2::from_i64(gate).add(Fp2::from_i64(2048)).add(Fp2::from_i64(7).mul(Fp2::from_i64(outputs[0]))));
        }
        gates[0]=0;outputs[0]=1;
        assert_eq!(histogram(&sh,&a,&gates,&outputs).unwrap().1,1);
    }

    #[test]
    fn h1_write_helpers_from_inv_matches_denominators_and_inverses() {
        let (sh, a) = native_query_fixture();
        {
            let n = sh.size(Dom::F);
            // Cover endpoints (-2048, 2047), arbitrary valid gates, and nonzero
            // valid gates on padded rows/columns (t >= tokens or j >= hidden).
            let gates: Vec<i64> = (0..n)
                .map(|i| match i {
                    0 => -2048,
                    1 => 2047,
                    _ => ((i * 73 + 19) % 4096) as i64 - 2048,
                })
                .collect();
            let outputs: Vec<i64> = (0..n)
                .map(|i| {
                    let group = query_group(&sh, &a, i);
                    a.scaled_tables()[group][(gates[i] + 2048) as usize]
                })
                .collect();
            assert_eq!(histogram(&sh, &a, &gates, &outputs).unwrap().1, 0);
            let alpha = Fp2::new(Fp::new(987_654_321_012_345), Fp::new(1_234_567));
            let beta = Fp2::new(Fp::new(77), Fp::new(13));
            let tag = Fp2::new(Fp::new(31), Fp::new(5));

            let mut want = denominators(&sh, &a, &gates, &outputs, alpha, beta, tag).unwrap();
            crate::field::batch_inverse2_checked(&mut want).unwrap();

            let tbl = table(&a, sh.size(Dom::Tab), beta, tag).unwrap();
            let mut act_inv: Vec<Fp2> = tbl.compressed[..tbl.entries].iter().map(|t| alpha.sub(*t)).collect();
            crate::field::batch_inverse2_checked(&mut act_inv).unwrap();

            let mut re = vec![Fp::ZERO; n];
            let mut im = vec![Fp::ZERO; n];
            write_helpers_from_inv(&sh, &a, &gates, &outputs, &act_inv, &mut re, &mut im).unwrap();
            for i in 0..n {
                assert_eq!(Fp2::new(re[i], im[i]), want[i], "mismatch at i={i}");
            }

            // Shape/slice length guards refuse cleanly.
            let mut short = vec![Fp::ZERO; n - 1];
            assert!(write_helpers_from_inv(&sh, &a, &gates, &outputs, &act_inv, &mut short, &mut im).is_err());
            assert!(write_helpers_from_inv(&sh, &a, &gates, &outputs, &act_inv[..tbl.entries - 1], &mut re, &mut im).is_err());
        }
    }

}
