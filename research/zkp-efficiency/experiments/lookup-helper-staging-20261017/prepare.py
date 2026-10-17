#!/usr/bin/env python3
"""Capture read-only local seams and generate a tiny std-only Rust harness."""
import ast
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path('/home/victor/IntelligenceRegulation')
LANE = ROOT/'ops/zkp-mvp/gpu-zerocheck'

def span(text, marker):
    start = text.index(marker)
    pos = text.index('{', start)
    depth, end = 1, pos+1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

def main():
    dest = HERE/'native'
    dest.mkdir(exist_ok=True)
    files = {
        'protocol.rs': LANE/'hashline/src/private_block/protocol.rs',
        'layout.rs': LANE/'hashline/src/private_block/layout.rs',
        'shape.rs': LANE/'hashline/src/private_block/shape.rs',
        'argument.rs': LANE/'hashline/src/private_block/argument.rs',
        'field.rs': LANE/'zkp-core/src/field.rs',
        'cuda.rs': LANE/'hashline/src/gpu/cuda.rs',
        'fzc.rs': LANE/'hashline/src/gpu/fzc.rs',
        'fzc_kernels.cu': LANE/'hashline/src/gpu/fzc_kernels.cu',
        'pcs.rs': LANE/'hashline/src/pcs.rs',
        'owner-progress.md': ROOT/'results/zk60_gpu_zerocheck_20261017/PROGRESS.md',
        'owner-design.md': ROOT/'results/zk60_gpu_zerocheck_20261017/DESIGN.md',
        'speed-plan.md': ROOT/'docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md',
    }
    pins = []
    for name,p in files.items():
        b=p.read_bytes(); (dest/name).write_bytes(b)
        pins.append(dict(source=str(p),capture='native/'+name,bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
    (HERE/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    # Reviewed previous local parser, copied as source only; no prior main runs.
    prior=HERE.parent/'lookup-borrow-catalog-20261017/run.py'
    ps=prior.read_text(); tree=ast.parse(ps)
    names={'split_args','scalar','source_catalog','reference_catalog'}
    funcs=[ast.get_source_segment(ps,n) for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names]
    assert len(funcs)==4
    (HERE/'catalog.py').write_text("import ast,re\nDOMS=['L','D','F','Q','Kv','S']\n\n"+'\n\n'.join(funcs)+'\n')
    (HERE/'parser-provenance.json').write_text(json.dumps(dict(path=str(prior),sha256=hashlib.sha256(ps.encode()).hexdigest(),functions=sorted(names)),indent=2)+'\n')
    proto=(dest/'protocol.rs').read_text()
    literal=next(l.strip() for l in proto.splitlines() if 'let col = |l: &Lk| -> Vec<i64>' in l)
    assert 'a.wrapping_add(c.wrapping_mul(wit.planes[*p][x]))' in literal
    (HERE/'captured-literal.rs.txt').write_text(literal+'\n')
    literal=literal.replace('wit.planes[*p][x]','raw[*p * len + x]')
    helper=span(proto,'fn helper_one(')
    cache=span(proto,'pub(super) fn u8_denominator_inverses(').replace('pub(super) ','').replace('crate::field::batch_inverse2','field::batch_inverse2')
    writer=span(proto,'fn write_h(')
    field=(dest/'field.rs').read_text().replace('//!','//').split('#[cfg(test)]')[0]
    (HERE/'resident_codec.rs').write_text('''// Research interface, not applied to a native or CUDA caller.
// A residue has two i64 preimages only on [P-2^63, 2^63).
const SIGN: u64 = 1u64 << 63;
const AMBIGUOUS_LO: u64 = field::P - SIGN;
fn ambiguity_bit(v:i64, residue:u64) -> bool {
    v < 0 && residue >= AMBIGUOUS_LO && residue < SIGN
}
fn recover_word(residue:u64, negative_ambiguity:bool) -> u64 {
    // Unsigned word operations deliberately implement Z/(2^64).
    if residue >= SIGN || (residue >= AMBIGUOUS_LO && negative_ambiguity) {
        residue.wrapping_sub(field::P)
    } else { residue }
}
fn resident_lookup(raw:&[i64], a:&[u64], signs:&[u64], len:usize, l:&Lk, mode:u32) -> Vec<Fp> {
    (0..len).map(|x| {
        if mode == 2 {
            // Tempting, incorrect replacement: evaluate affine terms in Fp.
            l.terms.iter().fold(Fp::from_i64(l.cst), |s,(p,c)| s.add(Fp(a[*p*len+x]).mul(Fp::from_i64(*c))))
        } else {
            let mut word=l.cst as u64;
            for (p,c) in &l.terms {
                let j=*p*len+x;
                let bit=(signs[j/64] >> (j%64)) & 1 != 0;
                let v=recover_word(a[j],mode != 3 && bit);
                word=word.wrapping_add((*c as u64).wrapping_mul(v));
            }
            Fp::from_i64(word as i64)
        }
    }).collect()
}
''')
    code='#![allow(dead_code,unused_variables)]\nmod field {\n'+field+'\n}\nuse field::{Fp,Fp2};\nconst U8_LEN:usize=256;\nconst ZERO_DENOMINATOR:&str="zero LogUp denominator; discard attempt";\nstruct Lk {terms:Vec<(usize,i64)>,cst:i64}\n'
    code+=helper+'\n'+cache+'\n'+writer+'\n'+(HERE/'resident_codec.rs').read_text()
    code+='''
#[no_mangle]
pub unsafe extern "C" fn codec(v:*const i64,n:usize,a:*mut u64,bits:*mut u64,out:*mut i64) {
 let raw=std::slice::from_raw_parts(v,n);
 let aa=std::slice::from_raw_parts_mut(a,n);
 let bb=std::slice::from_raw_parts_mut(bits,n.div_ceil(64)); bb.fill(0);
 for (j,&w) in raw.iter().enumerate() {aa[j]=Fp::from_i64(w).0; if ambiguity_bit(w,aa[j]) {bb[j/64] |= 1u64 << (j%64);}}
 for j in 0..n {*out.add(j)=recover_word(aa[j],(bb[j/64]>>(j%64))&1!=0) as i64;}
}
#[no_mangle]
pub unsafe extern "C" fn lookup(v:*const i64,a:*const u64,b:*const u64,n:usize,np:usize,pp:*const usize,cc:*const i64,nt:usize,cst:i64,out:*mut u64,mode:u32) {
 let raw=std::slice::from_raw_parts(v,n*np); let aa=std::slice::from_raw_parts(a,n*np); let bb=std::slice::from_raw_parts(b,(n*np).div_ceil(64));
 let terms=std::slice::from_raw_parts(pp,nt).iter().copied().zip(std::slice::from_raw_parts(cc,nt).iter().copied()).collect();
 let l=Lk{terms,cst}; let len=n;
 LITERAL
 let vals:Vec<Fp>=if mode==0 {col(&l).into_iter().map(Fp::from_i64).collect()} else {resident_lookup(raw,aa,bb,len,&l,mode)};
 for (j,v) in vals.iter().enumerate() {*out.add(j)=v.0;}
}
// Literal helper_one and write_h; serial pairing/caller orchestration only.
// Return 1 for a per-helper zero, 2 for a later whole-public-byte-table zero.
#[no_mangle]
pub unsafe extern "C" fn make_h(cols:*const i64,n:usize,nc:usize,prm:*const u64,h:*mut u64,hlen:usize) -> u32 {
 let w=std::slice::from_raw_parts(prm,4); let alpha=Fp2::new(Fp(w[0]),Fp(w[1]));let tag=Fp2::new(Fp(w[2]),Fp(w[3]));
 let cache=u8_denominator_inverses(alpha,tag);let raw=std::slice::from_raw_parts(cols,n*nc);
 let hwords=std::slice::from_raw_parts_mut(h,hlen);let nh=nc.div_ceil(2);
 // Private buffer snapshot. No commitment, transcript, RNG, or publication.
 let mut planar:Vec<Fp>=hwords.iter().map(|&v|Fp(v)).collect();
 for k in 0..nh {
   let mut col=Vec::with_capacity(n);
   for x in 0..n {
     let first=match helper_one(raw[(2*k)*n+x],alpha,tag,&cache) {Ok(v)=>v,Err(_)=>return 1};
     let z=if 2*k+1<nc {match helper_one(raw[(2*k+1)*n+x],alpha,tag,&cache) {Ok(v)=>first.add(v),Err(_)=>return 1}} else {first}; col.push(z);
   }
   write_h(&mut planar,(3+k*(2*n+2),3+k*(2*n+2)+n+1),&col);
 }
 // Preserve the mandatory whole-table refusal, even for unused zero entries.
 let mut all:Vec<Fp2>=(0..U8_LEN).map(|v|alpha.sub(Fp2::from_i64(v as i64).add(tag))).collect();
 if field::batch_inverse2_checked(&mut all).is_err() {return 2;}
 for (j,v) in planar.iter().enumerate() {hwords[j]=v.0;} 0
}
'''.replace('LITERAL',literal)
    (HERE/'isolated.rs').write_text(code)
    print('captured',len(pins),'files; generated source-only harness')

if __name__=='__main__': main()
