"""Freeze public source only; extract unchanged metadata bodies, not a prover."""
from pathlib import Path
import hashlib, json, re, shutil
D=Path(__file__).resolve().parent
P=Path('/home/victor/IntelligenceRegulation')
N=P/'results/zk60_1b_native_20261017/r13/frozen-tree'
(D/'native').mkdir(exist_ok=True)
files=['hashline/src/private_block/shape.rs','hashline/src/private_block/layout.rs',
       'hashline/src/private_block/argument.rs','hashline/src/private_block/protocol.rs',
       'hashline/src/zk.rs','zkp-core/src/pcs.rs','zkp-core/src/merkle.rs',
       'zkp-core/src/sumcheck/rounds.rs','zkp-core/src/sumcheck/grouped.rs',
       'hashline/src/private_block/argument_accuracy.rs']
pins=[]
for name in files:
    p=N/name; b=p.read_bytes(); dest='native/'+name.replace('/','__')
    (D/dest).write_bytes(b)
    pins.append(dict(path=str(p),snapshot=dest,bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
def body(s,name):
    m=re.search(r'(?m)^\s*(?:pub(?:\([^)]*\))? )?fn '+name+r'\(',s)
    assert m,name
    op=s.index('{',m.end()); depth=0
    for end in range(op,len(s)):
        if s[end]=='{': depth+=1
        elif s[end]=='}':
            depth-=1
            if depth==0:return s[m.start():end+1]
    raise AssertionError(name)
shape=(N/files[0]).read_text(); layout=(N/files[1]).read_text()
names=['f_p','limbs_norm','norm_top_is_full_byte','limbs_sigma_s','limbs_p',
       'q_pad','natural_log','true_size','log','size','rows_of','pads',
       'a_plane_doms','lookups_per_position','helpers','h_plane_doms','a_planes_on',
       'claim_sites','n_slots','m_rows','slots']
parts=[body(shape,name) for name in names]
consts='\n'.join(re.findall(r'pub\(crate\) const (?:SC_\w+|MAX_SLOTS|N_SLOTS): usize = [^;]+;',layout))
base=re.search(r'const BASE_DEGREE:[^=]+=\s*\[[^;]+;',shape).group(0)
indicator=re.search(r'const INDICATOR_SLOT_DOMAIN:[^=]+=\s*\[[^;]+;',shape).group(0)
header='''#[derive(Clone,Copy,Debug,PartialEq,Eq)] enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
impl Dom {fn carries_h_planes(self)->bool {!matches!(self,Dom::T|Dom::Ht)}}
const LIMBS_ISQRT:usize=3; const U8_LEN:usize=256; const F_P:u32=9;
fn clog2(v:usize)->usize {assert!(v>0);v.next_power_of_two().trailing_zeros() as usize}
struct Shape {tokens:usize,width:usize,hidden:usize,q_heads:usize,head_dim:usize,kv_heads:usize,
log_cols:usize,dd_cap:usize,t_pad:usize,d_pad:usize,h_pad:usize,f_pad:usize,
norm_wrho:u32,wrho_s:u32,stack:super::accuracy_precision::Stack}
impl Shape {
fn accuracy_stack(&self)->super::accuracy_precision::Stack {self.stack}
fn carries_pad_rule(&self)->bool {true}
'''
text=header+'\n'.join(parts)+'\n}\n'+consts+'\n'+base+'\n'+indicator+'\n'+body(layout,'domain_log_at')+'\n'
(D/'metadata.rs').write_text(text)
(D/'extraction.json').write_text(json.dumps(dict(methods=[dict(name=n,sha256=hashlib.sha256(p.encode()).hexdigest()) for n,p in zip(names,parts)],scope='21 unchanged shape metadata methods and domain_log_at; minimal Shape/accuracy-stack field stubs. Not native constructor/define/prover.'),indent=2)+'\n')
shutil.copyfile(D.parent/'separate-proof-round-batch-20261030/hypotheses.json',D/'hypotheses.json')
facts=[]
for rel,terms in {
    files[2]:['tb.truncate','std::mem::take(v)','SC_SZC =>','b.eq(&tau','b.eq(&pts.p_ht','b.eq(&pts.p_s','let im = b.public(causal_mask_at','if !sh.carries_pad_rule() || !sh.pads(dom)'],
    files[3]:['data: [a.data.as_slice()','let acc = argument(','let mask_open =','drop(mc);','let a_open =','drop(a);','let h_open =','drop(h);'],
    files[7]:['tb.truncate(half)'],files[8]:['tb.truncate(half)']
}.items():
    for no,line in enumerate((N/rel).read_text().splitlines(),1):
        if any(t in line for t in terms):facts.append(dict(path=rel,line=no,text=line.strip()))
(D/'source-facts.json').write_text(json.dumps(facts,indent=2)+'\n')
print(json.dumps(dict(status='PREPARED',pins=len(pins),metadata_bodies=len(parts)+1,source_facts=len(facts))))
