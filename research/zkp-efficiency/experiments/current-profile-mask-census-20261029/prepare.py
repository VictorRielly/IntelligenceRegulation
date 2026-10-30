"""Extract metadata methods only; no native prover, registry or private data."""
from pathlib import Path
import hashlib,json,re,shutil
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
NATIVE=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree')
(HERE/'native').mkdir(exist_ok=True)
pins=[]
for name in ['shape.rs','layout.rs','argument.rs','argument_accuracy.rs','accuracy_layout.rs','accuracy_precision.rs']:
 p=NATIVE/'hashline/src/private_block'/name;data=p.read_bytes();target=HERE/'native'/name;target.write_bytes(data)
 pins.append(dict(path=str(p),snapshot=str(target.relative_to(HERE)),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
p=NATIVE.parent/'NATIVE_LAYOUT_CENSUS.json';data=p.read_bytes();(HERE/'native/NATIVE_LAYOUT_CENSUS.json').write_bytes(data)
pins.append(dict(path=str(p),snapshot='native/NATIVE_LAYOUT_CENSUS.json',sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
(HERE/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
for src,dst in [('catalog.py','legacy_catalog.py'),('candidate.py','cache.py'),('source_reference.py','algebra_reference.py')]:
 shutil.copyfile(ROOT/'experiments/mask-tail-incidence-20261029'/src,HERE/dst)

def method(text,name):
 match=re.search(r'(?m)^    (?:pub\(crate\) )?fn '+name+r'\(',text)
 if not match:raise ValueError(name)
 start=match.start();op=text.index('{',match.end());depth=0
 # These seven inspected methods have no string literal containing a brace.
 for end in range(op,len(text)):
  if text[end]=='{':depth+=1
  if text[end]=='}':
   depth-=1
   if depth==0:return text[start:end+1]
 raise ValueError('unterminated method')

shape=(HERE/'native/shape.rs').read_text();layout=(HERE/'native/layout.rs').read_text()
names=['a_plane_doms','lookups_per_position','helpers','h_plane_doms','a_planes_on','claim_sites']
parts=[method(shape,n) for n in names]
constants='\n'.join(re.findall(r'pub\(crate\) const (?:SC_\w+|MAX_SLOTS): usize = [^;]+;',layout))
header='''#![allow(dead_code)]
mod extracted {
 pub mod accuracy_precision {#[derive(Clone,Copy,PartialEq,Eq)] pub enum Stack {Legacy,Low,LowH24}}
 pub mod shape {
 use super::accuracy_precision::Stack;
 #[derive(Clone,Copy,Debug,PartialEq,Eq)] pub enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
 const LIMBS_ISQRT:usize=3;
'''
stub='''
pub struct Shape {pub h24:bool,pub dd_cap:usize,pub ls:usize}
impl Shape {
 fn accuracy_stack(&self)->Stack {if self.h24 {Stack::LowH24} else {Stack::Low}}
 fn limbs_norm(&self)->usize {3}
 fn limbs_p(&self)->usize {2}
 fn limbs_sigma_s(&self)->usize {self.ls}
 fn norm_top_is_full_byte(&self)->bool {true}
'''
footer='''
}}}
fn main() {
 use extracted::shape::{Shape,Dom};
 let doms=[Dom::T,Dom::Ht,Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F,Dom::Tab,Dom::Dd];
 for h24 in [false,true] {for dd in [0,32] {for ls in [2,3] {
 let sh=Shape{h24,dd_cap:dd,ls};let(a,h)=sh.claim_sites();let ap=sh.a_plane_doms();let hp=sh.h_plane_doms();
 let ac:Vec<_>=doms.iter().map(|d|ap.iter().filter(|x|*x==d).count()).collect();
 let hc:Vec<_>=doms.iter().map(|d|hp.iter().filter(|x|*x==d).count()).collect();
 let look:Vec<_>=doms.iter().map(|d|sh.lookups_per_position(*d)).collect();
 println!("{}|{}|{}|{:?}|{:?}|{:?}|{:?}|{:?}",u8::from(h24),dd,ls,a,h,ac,hc,look);
 }}}
}
'''
(HERE/'metadata.rs').write_text(header+constants+stub+'\n'.join(parts)+footer)
(HERE/'extraction.json').write_text(json.dumps(dict(methods=[dict(name=n,sha256=hashlib.sha256(p.encode()).hexdigest(),bytes=len(p)) for n,p in zip(names,parts)],scope='Six unchanged native metadata methods; stub Shape accessors, Dom and stack. Native constructor/define/refusal/prover not executed.'),indent=2)+'\n')
print(json.dumps(dict(status='PREPARED',source_pins=len(pins),unchanged_metadata_methods=len(parts))))
