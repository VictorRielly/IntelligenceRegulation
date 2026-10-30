"""Source metadata only; no native constructor, prover or private values."""
from pathlib import Path
import hashlib, json, re, shutil
D=Path(__file__).resolve().parent
N=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree')
(D/'native').mkdir(exist_ok=True)
pins=[]
for name in ['shape.rs','layout.rs','argument.rs','argument_accuracy.rs']:
    p=N/'hashline/src/private_block'/name; data=p.read_bytes()
    (D/'native'/name).write_bytes(data)
    pins.append(dict(path=str(p),snapshot='native/'+name,sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
p=Path('/home/victor/IntelligenceRegulation/zkp-core/src/transcript.rs')
data=p.read_bytes();(D/'native/transcript.rs').write_bytes(data)
pins.append(dict(path=str(p),snapshot='native/transcript.rs',sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')

def extract(text,name):
    m=re.search(r'(?m)^\s*(?:pub(?:\([^)]*\))? )?fn '+name+r'\(',text)
    assert m,name
    start=m.start(); op=text.index('{',m.end()); depth=0
    # Inspected selected bodies contain no brace-bearing string literals.
    for end in range(op,len(text)):
        if text[end]=='{':depth+=1
        elif text[end]=='}':
            depth-=1
            if depth==0:return text[start:end+1]
    raise ValueError(name)

shape=(D/'native/shape.rs').read_text();layout=(D/'native/layout.rs').read_text()
names=['q_pad','natural_log','true_size','log','size','pads','slots','n_slots']
parts=[extract(shape,n) for n in names]
consts='\n'.join(re.findall(r'pub\(crate\) const (?:SC_\w+|MAX_SLOTS|N_SLOTS): usize = [^;]+;',layout))
base=re.search(r'const BASE_DEGREE:[^=]+=\s*\[[^;]+;',shape).group(0)
indicator=re.search(r'const INDICATOR_SLOT_DOMAIN:[^=]+=\s*\[[^;]+;',shape).group(0)
header='''#[derive(Clone,Copy,Debug)] enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
impl Dom {fn carries_h_planes(self)->bool {!matches!(self,Dom::T|Dom::Ht)}}
const LIMBS_ISQRT:usize=3; const U8_LEN:usize=256;
fn clog2(v:usize)->usize {assert!(v>0);v.next_power_of_two().trailing_zeros() as usize}
struct Shape {tokens:usize,width:usize,hidden:usize,q_heads:usize,head_dim:usize,kv_heads:usize,
 log_cols:usize,dd_cap:usize,t_pad:usize,d_pad:usize,h_pad:usize,f_pad:usize,frozen:bool}
impl Shape {fn carries_pad_rule(&self)->bool {!self.frozen}
'''
generated=header+'\n'.join(parts)+'\n}\n'+consts+'\n'+base+'\n'+indicator+'\n'+extract(layout,'domain_log_at')+'\n'
(D/'native_metadata.rs').write_text(generated)
(D/'extraction.json').write_text(json.dumps(dict(methods=[dict(name=n,sha256=hashlib.sha256(p.encode()).hexdigest()) for n,p in zip(names,parts)],scope='Eight unchanged native metadata methods; stub Shape fields/profile gate and Dom. No native constructor/define/prover run.'),indent=2)+'\n')

# Reviewed event ledger: cross-slot Points reads; reads after an in-slot write
# are omitted. r_q is overwritten at WO, so its earlier owner is not reused.
events=[
 (0,[],['r_t']),(1,[],['r_t2']),(2,['r_t','r_t2'],[]),(3,[],[]),
 (4,[],['p_ht','lam_z']),(5,[],['r_q','pq']),(6,['r_q'],['pk']),
 (7,['r_q'],['pv']),(8,[],['p_s']),(9,[],['p_o']),
 (10,[],['r_q','p_a']),(11,[],['r_tf','p_g']),(12,['r_tf'],['p_u']),
 (13,[],['p_z']),(14,['p_a','p_z'],[]),(15,['pq','p_o'],[]),
 (16,['pk','pv'],[]),(17,['lam_z','p_ht','p_s'],[]),
 (18,['p_g','p_u'],[]),(19,[],[]),(20,[],[]),(21,[],[]),(22,[],[]),(23,[],[])]
hostmap={2:[0,1],14:[10,13],15:[5,9],16:[6,7],17:[4,8],18:[11,12]}
owner={};edges=[]
for s,reads,writes in events:
    for key in reads:edges.append((owner[key],s,'point:'+key))
    for key in writes:owner[key]=s
    for src in hostmap.get(s,[]):edges.append((src,s,'host'))
(D/'events.json').write_text(json.dumps(dict(events=events,hostmap=hostmap,edges=edges,scope='Manually reviewed source ledger, not a Rust AST analyzer or execution of define.'),indent=2)+'\n')
(D/'edges.tsv').write_text(''.join(f'{a} {b} {k}\n' for a,b,k in edges))
occ=[]
for name in ['argument.rs','argument_accuracy.rs']:
    for no,line in enumerate((D/'native'/name).read_text().splitlines(),1):
        if 'pts.' in line:occ.append(dict(file=name,line=no,text=line))
(D/'point-source-occurrences.json').write_text(json.dumps(occ,indent=2)+'\n')
shutil.copyfile(D.parent/'same-capture-fold-correlation-20261030/hypotheses.json',D/'hypotheses.json')
print(json.dumps(dict(status='PREPARED',pins=len(pins),metadata_methods=len(parts),typed_dependencies=len(edges),point_source_lines=len(occ))))
