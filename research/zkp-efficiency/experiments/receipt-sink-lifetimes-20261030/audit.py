"""Artifact/reference audit. Imports no candidate or experiment code."""
import hashlib,json,time
from pathlib import Path
import reference as ref
E=Path(__file__).resolve().parent
n=0
def check(v):
    global n
    n+=1
    assert v,n
def main():
    start=time.monotonic();r=json.loads((E/'result.json').read_text());check(r['status']=='PASS')
    for pin in json.loads((E/'native-pins.json').read_text()):
        b=(E/pin['snapshot']).read_bytes();check(len(b)==pin['bytes']);check(hashlib.sha256(b).hexdigest()==pin['sha256']);check(Path(pin['path']).read_bytes()==b)
    counts=json.loads((E/'wire-counts.json').read_text());check(len(counts)==126)
    for row in counts:
        check(row['buffer_high']<=row['budget']);check(row['bytes']>=row['buffer_high']);check(row['write_calls']>=row['bytes']//37)
    def hook(x):return bytes.fromhex(x['$bytes']) if list(x)==['$bytes'] else x
    for name in r['saved_fixtures']:
        fixture=json.loads((E/'fixtures'/f'{name}.json').read_text(),object_hook=hook)
        g,s=fixture['g'],fixture['s'];tags=[bytes.fromhex(t) for t in fixture['tags']];b=(E/'fixtures'/f'{name}.bin').read_bytes()
        check(ref.encode(s,g,*tags)==b);check(ref.decode_equal(b,s,g,*tags))
        # Independent transport tests with no use of the emitter.
        for pos in [0,8,40,48,56,len(b)//2,len(b)-1]:
            bad=bytearray(b);bad[pos]^=1
            try:ref.decode_equal(bad,s,g,*tags);caught=False
            except ValueError:caught=True
            check(caught)
        check(len(b)==sum(size if kind=='raw' else 8*(1 if kind=='index' else size) for _,kind,size in ref.schema(g)))
    b=(E/'files/stream.bin').read_bytes();check(b==(E/'files/reference.bin').read_bytes());check(not (E/'files/stream.partial').exists())
    check(r['proofs']==r['complete_model_passes']==r['proved_positions']==0);check(r['actual_peak_or_speed'] is None)
    facts=json.loads((E/'source-facts.json').read_text());check(len(facts)==7);check(all(facts.values()))
    startup=json.loads((E/'startup/read-manifest.json').read_text())
    for pin in startup:
        if Path(pin['path']).name in ['STATE.md','PROGRESS.md']:continue
        b=Path(pin['path']).read_bytes()
        # FINDINGS and sources may have subsequently been append-only updated.
        check(hashlib.sha256(b[:pin['bytes']]).hexdigest()==pin['sha256'])
    result=dict(status='PASS',checks=n,imports_candidate=False,imports_experiment=False,wall_s=time.monotonic()-start)
    (E/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
