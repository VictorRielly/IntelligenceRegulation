from pathlib import Path
import hashlib,json,shutil
D=Path(__file__).resolve().parent
R=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree')
paths=['zkp-core/src/pcs.rs','zkp-core/src/field.rs','zkp-core/src/mle.rs','hashline/src/private_block/protocol.rs','hashline/src/private_block/argument.rs','hashline/src/private_block/layout.rs','hashline/src/private_block/shape.rs']
pins=[]
for name in paths:
    p=R/name; b=p.read_bytes(); q=D/'native'/name; q.parent.mkdir(parents=True,exist_ok=True); q.write_bytes(b)
    pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
for src,dst in [(R.parent/'NATIVE_LAYOUT_CENSUS.json','native/NATIVE_LAYOUT_CENSUS.json'),(D.parent/'composition-eq-scope-20261029/model.py','model.py'),(D.parent/'composition-eq-scope-20261029/legacy_catalog.py','legacy_catalog.py')]:
    b=src.read_bytes();(D/dst).write_bytes(b);pins.append(dict(path=str(src),snapshot=dst,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
def extract(s,name):
    at=s.index('fn '+name+'('); start=s.rfind('\n',0,at)+1; brace=s.index('{',at); depth=1; i=brace+1
    while depth: depth+=(s[i]=='{')-(s[i]=='}'); i+=1
    return s[start:i]+'\n'
pcs=(R/'zkp-core/src/pcs.rs').read_text();mle=(R/'zkp-core/src/mle.rs').read_text();protocol=(R/'hashline/src/private_block/protocol.rs').read_text()
funcs=[extract(pcs,n) for n in ['zpart_weights','zkey_weights','group_zclaims','zk_rhos']]
(D/'native_groups.rs').write_text('\n'.join(funcs))
eq=extract(mle,'eq_table')+'\n'+extract(mle,'eq_table_msb')
(D/'serial_eq.rs').write_text(eq.replace('.par_iter_mut()', '.iter_mut()'))
audit=extract(protocol,'part_rows')+'\n'+extract(protocol,'audit_claims')
(D/'native_audit.rs').write_text(audit)
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
(D/'extraction.json').write_text(json.dumps(dict(group_functions=['zpart_weights','zkey_weights','group_zclaims','zk_rhos'],audit_functions=['part_rows','audit_claims'],serial_eq_change='par_iter_mut -> iter_mut only',native_audit_sha256=hashlib.sha256(audit.encode()).hexdigest(),transcript='scripted xorshift fresh synthetic draws, not native FS'),indent=2)+'\n')
print('Pinned',len(pins),'files; exact native audit/group/rho helpers extracted; no native prover')
