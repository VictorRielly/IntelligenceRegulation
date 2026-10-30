"""Read-only source pins and public metadata. No production execution."""
from pathlib import Path
import hashlib,json,shutil
D=Path(__file__).resolve().parent
P=Path('/home/victor/IntelligenceRegulation')
N=P/'results/zk60_1b_native_20261017/r13/frozen-tree'
old=D.parent/'public-cohort-admission-20261030'
(D/'native').mkdir(exist_ok=True)
files=['hashline/src/private_block/shape.rs','hashline/src/private_block/layout.rs','hashline/src/private_block/protocol.rs','hashline/src/zk.rs','zkp-core/src/pcs.rs','zkp-core/src/merkle.rs','zkp-core/src/pcs/encode_buffer.rs','zkp-core/src/ntt.rs','zkp-core/src/field.rs','zkp-core/src/sumcheck.rs']
pins=[]
for name in files:
 p=N/name;b=p.read_bytes();dst='native/'+name.replace('/','__');(D/dst).write_bytes(b)
 pins.append(dict(path=str(p),snapshot=dst,bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
for name in ['geometry.json','capacity-projections.json','hypotheses.json']:
 shutil.copyfile(old/name,D/name)
shutil.copyfile(old/'metadata.rs',D/'metadata.rs')
# These native bodies remain unchanged; only the standalone public metadata
# caller is new. Constructors, native define and field arithmetic are absent.
facts=[]
terms={'zkp-core/src/pcs.rs':['let pads =','let salts:','let pows =','let salted:','let tree =','let mut bufs:','let tile ='],
 'zkp-core/src/pcs/encode_buffer.rs':['Vec::with_capacity(len)','let mut coeffs =','ntt.inverse'],
 'zkp-core/src/merkle.rs':['let mut levels =','levels.push(next)'],
 'hashline/src/private_block/protocol.rs':['let mut a_data =','let looked:','let deltas =','let act_idx =','let mut h_data =','drop(looked)','drop(wit)','drop(deltas)','drop(act_idx)','let mut h = pcs::','let mc = zk::'],
 'zkp-core/src/field.rs':['let mut prefix ='],
 'hashline/src/zk.rs':['let mut encoded =','let masks:','let mut a_coefs =','let mut b_re =','let u_re =']}
for rel,needles in terms.items():
 for no,line in enumerate((N/rel).read_text().splitlines(),1):
  if any(s in line for s in needles):facts.append(dict(path=rel,line=no,text=line.strip()))
(D/'source-facts.json').write_text(json.dumps(facts,indent=2)+'\n')
print(json.dumps(dict(status='PREPARED',source_pins=len(pins),public_geometry_cases=len(json.loads((D/'geometry.json').read_text())),facts=len(facts))))
