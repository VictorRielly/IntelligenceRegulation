"""Read-only native extraction. No Cargo, downloaded code, or production writes."""
from pathlib import Path
import hashlib, json
HERE=Path(__file__).resolve().parent
NATIVE=Path('/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b')
out=HERE/'native';out.mkdir(exist_ok=True)
paths=['zkp-core/src/field.rs','zkp-core/src/mle.rs','hashline/src/private_block/argument.rs',
       'hashline/src/private_block/shape.rs','hashline/src/private_block/layout.rs',
       'hashline/src/private_block/protocol.rs','hashline/src/sumcheck.rs','hashline/src/zk.rs']
pins=[]
for rel in paths:
 p=NATIVE/rel;b=p.read_bytes();name=rel.replace('/','__');(out/name).write_bytes(b)
 pins.append(dict(path=str(p),snapshot='native/'+name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(HERE/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
mle=(NATIVE/paths[1]).read_text(); eq=mle[mle.index('pub fn eq_table('):mle.index('/// eq(r, s)')]
eq=eq.replace('.par_iter_mut()', '.iter_mut()')
(HERE/'serial_eq.rs').write_text(eq)
arg=(NATIVE/paths[2]).read_text();start=arg.index('fn mask_eval(');end=arg.index('\n/// `cd * plane',start)
(HERE/'baseline_mask.rs').write_text(arg[start:end].replace('fn mask_eval(', 'fn baseline_mask_eval(',1)+'\n')
print(json.dumps({'pins':len(pins),'eq_adapter':'only par_iter_mut -> iter_mut; extracted constructors','mask_adapter':'only function name changed; stub types in harness'}))
