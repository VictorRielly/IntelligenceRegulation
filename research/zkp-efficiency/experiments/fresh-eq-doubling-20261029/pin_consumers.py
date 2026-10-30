from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent
F=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree')
pins=json.loads((H/'native-pins.json').read_text())
new=[]
for rel in ['zkp-core/src/mle.rs','zkp-core/src/field.rs','zkp-core/src/pcs.rs','hashline/src/mle.rs','hashline/Cargo.toml']:
 p=F/rel;b=p.read_bytes();dst='consumers/'+rel.replace('/','__');(H/'consumers').mkdir(exist_ok=True);(H/dst).write_bytes(b)
 new.append(dict(path=str(p),snapshot=dst,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
for n in ['mle','field']:
 assert (H/f'consumers/zkp-core__src__{n}.rs').read_bytes()==(H/f'native/zkp-core__src__{n}.rs').read_bytes()
(H/'consumer-pins.json').write_text(json.dumps(new,indent=2)+'\n')
initial=H/'before-mask-seam';initial.mkdir(exist_ok=True)
for n in ['result.json','probe-execution.json','probe.stdout.log','harness.rs','main.rs']:
 (initial/n).write_bytes((H/n).read_bytes())
print('5 actual frozen R13 consumer pins, field/mle bytes match prior adapter; initial run retained')
