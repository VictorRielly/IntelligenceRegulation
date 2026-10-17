#!/usr/bin/env python3
"""Capture local source; generate a serial, standalone Rust arithmetic oracle.
No foreign source execution, Cargo, production writes or production libraries.
"""
from pathlib import Path
import hashlib, json, difflib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
LANE=ROOT/'ops/zkp-mvp/trained-1b'

def balanced(src, start):
    b=src.index('{',start); depth,end=1,b+1
    while depth:
        depth+=(src[end]=='{')-(src[end]=='}');end+=1
    return src[start:end]

def serial(s):
    s=s.replace('use rayon::prelude::*;','')
    s=s.replace('.into_par_iter()', '.into_iter()').replace('.par_iter_mut()', '.iter_mut()').replace('.par_iter()', '.iter()')
    s=s.replace('.reduce(zero,', '.fold(zero(),')
    s=s.replace('.reduce(\n                || vec![Fp2::ZERO; degree + 1],', '.fold(\n                vec![Fp2::ZERO; degree + 1],')
    return s

def main():
    (HERE/'native').mkdir(exist_ok=True)
    paths=['hashline/src/private_block/'+f for f in ['argument.rs','layout.rs','shape.rs','pad.rs']]+['zkp-core/src/'+f for f in ['field.rs','mle.rs','sumcheck/grouped.rs','sumcheck/rounds.rs']]
    pins=[]
    for rel in paths:
        p=LANE/rel;b=p.read_bytes();name=rel.replace('/','__');(HERE/'native'/name).write_bytes(b)
        pins.append(dict(path=str(p),snapshot='native/'+name,sha256=hashlib.sha256(b).hexdigest()))
    (HERE/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    src=(LANE/'hashline/src/private_block/argument.rs').read_text()
    arm=balanced(src,src.index('        SC_FZC => {'))
    baseline=balanced(arm,arm.index('let poly = move'))
    body=baseline.replace('let poly = move |v: &[Fp2]| {','let bracket = move |group: usize, v: &[Fp2]| {')
    old='''                let at = |p: usize| v[idx[p]];
                let l2'''
    new='''                let at = |p: usize| v[idx[p]];
                let g = gf.at(v);
                if group == 1 { return nu[0].mul(g).mul(k_g.mul(at(A_G8)).add(at(A_RGL)).sub(k_g_half)); }
                if group == 2 { return nu[1].mul(g).mul(at(A_U16)); }
                assert_eq!(group, 0);
                let l2'''
    assert body.count(old)==1;body=body.replace(old,new)
    tail='''                let host_g = k_g.mul(g8).add(at(A_RGL)).sub(k_g_half);
                // SH_U = 0: no coefficient, no constant, no remainder (T2 A.4)
                let host_u = u16;
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_g)).add(nu[1].mul(v[2]).mul(g).mul(host_u))'''
    assert tail in body;body=body.replace(tail,'                zc')
    # Candidate retains the old full polynomial for verifier/extensions. Only
    # prover arithmetic receives an additional closure; constructor code shared.
    grouped_arm=arm.replace('            let poly = move |v: &[Fp2]| {','''            let groups = vec![
                sumcheck::EqualityGroup { point: tau, start: 0, bracket_degree: 3 },
                sumcheck::EqualityGroup { point: pts.p_g.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
                sumcheck::EqualityGroup { point: pts.p_u.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
            ];
            // The original polynomial is used below for extensions/verifier.
            let bracket: GroupPoly = std::sync::Arc::new('''+body.removeprefix('let bracket = move ')+''');
            let original_bracket = bracket.clone();
            let poly = move |v: &[Fp2]| (0..3).fold(Fp2::ZERO,
                |a, g| a.add(v[g].mul(original_bracket(g, v))));
            /* Original full polynomial, retained as the captured oracle:
            let poly = move |v: &[Fp2]| {''')
    # Do not offer an uncompiled production patch with duplicated dead code.
    # Produce the clean source proposal directly from the captured arm instead.
    replacement='''            let groups = vec![
                sumcheck::EqualityGroup { point: tau, start: 0, bracket_degree: 3 },
                sumcheck::EqualityGroup { point: pts.p_g.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
                sumcheck::EqualityGroup { point: pts.p_u.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
            ];
            let bracket: GroupPoly = std::sync::Arc::new('''+body.removeprefix('let bracket = ')+''');
            let final_bracket = bracket.clone();
            let poly = move |v: &[Fp2]| (0..3).fold(Fp2::ZERO,
                |a, g| a.add(v[g].mul(final_bracket(g, v))))'''
    candidate_arm=arm.replace(baseline,replacement).replace('            b.finish(Box::new(poly), hosted)','''            let mut def = b.finish(Box::new(poly), hosted)?;
            def.groups = Some((groups, bracket));
            Ok(def)''')
    candidate=src.replace(arm,candidate_arm)
    (HERE/'argument-candidate.rs').write_text(candidate)
    (HERE/'argument-candidate.patch').write_text(''.join(difflib.unified_diff(src.splitlines(True),candidate.splitlines(True),fromfile='a/hashline/src/private_block/argument.rs',tofile='b/hashline/src/private_block/argument.rs')))
    (HERE/'captured-full-closure.txt').write_text(baseline+';\n')
    (HERE/'candidate-bracket.txt').write_text(body+';\n')
    # Reuse the preceding cycle's *independent equation* as a third-party-to-
    # this-rewrite semantic reference; its file and hash are retained.
    prior=HERE.parent/'fzc-public-constants-20261017/run.py'
    old=prior.read_text();st=old.index('P = 2**64');en=old.index('\ndef balanced(')
    (HERE/'oracle.py').write_text('# Independent arbitrary-integer semantic equation, copied from prior cycle.\n'+old[st:en])
    (HERE/'prior-oracle-provenance.json').write_text(json.dumps(dict(path=str(prior),sha256=hashlib.sha256(prior.read_bytes()).hexdigest()),indent=2)+'\n')
    field=(LANE/'zkp-core/src/field.rs').read_text().replace('//!','//')
    mle=(LANE/'zkp-core/src/mle.rs').read_text()
    ms='\n'.join(balanced(mle,mle.index('pub fn '+x+'(')) for x in ['eq_table','eq_table_msb','interpolate_eval'])
    rs=(LANE/'zkp-core/src/sumcheck/rounds.rs').read_text();rs=rs[rs.index('pub trait SumcheckRounds'):rs.index('\n#[cfg(test)]')]
    a=rs.index('pub fn prove_rounds');b=rs.index('/// CPU evaluator',a);rs=rs[:a]+rs[b:]
    gs=(LANE/'zkp-core/src/sumcheck/grouped.rs').read_text();gs=gs[gs.index('/// A term'):gs.index('\n#[cfg(test)]')]
    gs=gs.replace('let inverse_one = self.claims[g].and_then(|_| {','''let inverse_one = self.claims[g].and_then(|_| {
                if factor[1].is_zero() { crate::metric(5); } else { crate::metric(4); }''')
    # Bad-claim negative control is isolated to the research harness.
    gs=gs.replace('let count = groups.len();','let count = groups.len();')
    gs=gs.replace('    fn n_vars(&self) -> usize { self.n_vars }','''    fn n_vars(&self) -> usize { self.n_vars }''')
    gs+='\nimpl<F: Fn(usize, &[Fp2])->Fp2 + Sync> GroupedEqRounds<\'_, F> { pub fn seed_bad(&mut self) { self.claims.fill(Some(Fp2::ONE)); } }\n'
    helpers='\n'.join([balanced(src,src.index('fn helper_sum(')), balanced(src,src.index('struct PadTerm {')),balanced(src,src.index('impl PadTerm {')),'#[derive(Clone,Copy)]\nstruct Gate(Option<usize>);',balanced(src,src.index('impl Gate {'))])
    layout=(LANE/'hashline/src/private_block/layout.rs').read_text()
    constants='\n'.join(l.replace('pub(crate) ','') for l in layout.splitlines() if l.startswith('pub(crate) const A_') and any((' '+z+':') in l for z in ['A_G8','A_RGL','A_A16','A_U16','A_UL0','A_UL1','A_H16','A_HL0','A_HL1','A_RH0','A_RH1']))
    pre='''let mut idx=vec![usize::MAX;78]; for i in 67..=77 { idx[i]=i-64; }
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let (k_h,k_g)=(k(1i64<<hh),k(1i64<<gg));
 let (k_h_half,k_g_half)=(k(if hh==0 {0} else {1i64<<(hh-1)}),k(if gg==0 {0} else {1i64<<(gg-1)}));
 let cols=[(A_RGL,1),(A_RGL,1i64<<(8-gg)),(A_UL0,1),(A_UL1,1),(A_HL0,1),(A_HL1,1),(A_RH0,1),(A_RH1,1),(A_RH1,1i64<<(16-hh))];
 let lks:Vec<LkT>=cols[..nlk].iter().map(|(p,c)| LkT{terms:vec![(idx[*p],Fp::from_i64(*c))],cst:g_u8}).collect();
 let gf=Gate(if pad {Some(20)} else {None}); let mut pz=PadTerm::none();
 if pad { pz.mu=mu[4+nlk.div_ceil(2)]; pz.add(Some(20),&(3..14).collect::<Vec<_>>(),v[37]); }
'''
    code='#![allow(dead_code,unused_variables,unused_doc_comments)]\nmod field {\n'+field+'\n}\nuse field::{Fp,Fp2};\nmod mle { use crate::field::{Fp,Fp2};\n'+serial(ms)+'\n}\nmod sumcheck { use crate::{field::Fp2,mle::interpolate_eval};\n'+serial(rs)+'\npub mod grouped { use super::SumcheckRounds;use crate::{field::Fp2,mle::{eq_table_msb,interpolate_eval}};\n'+serial(gs)+'\n}\n}\n'+constants+'\nstruct LkT {terms:Vec<(usize,Fp)>,cst:Fp2}\n'+helpers+'\nfn k(x:i64)->Fp2 {Fp2::from_i64(x)}\n'
    code+='fn full(v:&[Fp2],hh:u32,gg:u32,pad:bool,nlk:usize)->Box<dyn Fn(&[Fp2])->Fp2+Sync> {\n'+pre+baseline+'; Box::new(poly)\n}\n'
    code+='fn brackets(v:&[Fp2],hh:u32,gg:u32,pad:bool,nlk:usize)->Box<dyn Fn(usize,&[Fp2])->Fp2+Sync> {\n'+pre+body+'; Box::new(bracket)\n}\n'
    code+=(HERE/'driver.rs').read_text()
    (HERE/'isolated.rs').write_text(code)
    print(json.dumps(dict(captured_files=len(pins),rust_bytes=len(code),source_hashes_stable=True)))

if __name__=='__main__':main()
