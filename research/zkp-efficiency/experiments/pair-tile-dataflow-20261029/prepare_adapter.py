"""Copy unchanged public native field; serial Eq traversal; pin dependencies."""
import hashlib,json,pathlib
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parent.parent;PRIOR=ROOT/'experiments/public-mask-component-sums-20261029'
def sha(b):return hashlib.sha256(b).hexdigest()
pins=json.loads((HERE/'native-pins.json').read_text());extra=[]
for item in json.loads((PRIOR/'native-pins.json').read_text())[:2]:
 p=pathlib.Path(item['path']);b=p.read_bytes();assert sha(b)==item['sha256'];(HERE/item['snapshot']).write_bytes(b);extra.append(item)
(HERE/'native-pins.json').write_text(json.dumps(pins+extra,indent=2)+'\n')
copies=[]
for old,new in [(PRIOR/'serial_eq.rs','serial_eq.rs'),(ROOT/'experiments/current-profile-mask-census-20261029/model.py','model.py'),(ROOT/'experiments/current-profile-mask-census-20261029/legacy_catalog.py','legacy_catalog.py')]:
 b=old.read_bytes();(HERE/new).write_bytes(b);copies.append(dict(path=str(old),snapshot=new,sha256=sha(b)))
(HERE/'research-pins.json').write_text(json.dumps(copies,indent=2)+'\n')
source=(HERE/'native/argument.rs').read_text();begin=source.index('fn mask_eval(');brace=source.index('{',begin);depth=1;i=brace+1
while depth:
 depth+=(source[i]=='{')-(source[i]=='}');i+=1
original=source[begin:i];adapted=original.replace('fn mask_eval(', 'fn baseline_mask_eval(',1)
(HERE/'baseline_mask.rs').write_text(adapted+'\n')
(HERE/'extraction.json').write_text(json.dumps(dict(native_file='native/argument.rs',original=original,original_sha256=sha(original.encode()),adaptation='Only rename mask_eval to baseline_mask_eval; Shape/Priv metadata accessors are harness stubs. No native define/constructor/prover.'),indent=2)+'\n')
print(json.dumps(dict(native_pins=len(pins+extra),research_pins=len(copies),baseline_bytes=len(original))))
