#!/usr/bin/env python3
"""Separate accounting/source audit; does not import experiment helpers."""
import hashlib
import json
import os
import resource
import signal
import time
from pathlib import Path
HERE=Path(__file__).resolve().parent

def main():
    t0=time.perf_counter(); os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2)); resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    checks=0; result=json.loads((HERE/'result.json').read_text()); assert result['status']=='pass'; checks+=1
    assert result['executed_source_sha256']==hashlib.sha256((HERE/'run.py').read_bytes()).hexdigest(); checks+=1
    for source,sha in json.loads((HERE/'native-pins.json').read_text()).items():
        assert hashlib.sha256(Path(source).read_bytes()).hexdigest()==sha
        assert hashlib.sha256((HERE/'native'/Path(source).name).read_bytes()).hexdigest()==sha; checks+=2
    meta=json.loads((HERE/'public-calibration.json').read_text()); sh=meta['shifts']
    p=Path(meta['source_path']); assert hashlib.sha256(p.read_bytes()).hexdigest()==meta['source_sha256']; checks+=1
    profile=json.loads(p.read_text()); manifests=[]
    # Only public integer constants and their hashes are retained, never arrays.
    for l in profile['layers']:
        m=p.parent/l['dir']/'manifest.json'; b=m.read_bytes(); x=json.loads(b)
        assert all(x['constants'][k]==v for k,v in sh.items())
        assert x['constants']['f_e']==meta['f_e'] and x['constants']['norm_tn']==meta['norm_tn']; checks+=2
        manifests.append(dict(layer=l['layer'],path=str(m),sha256=hashlib.sha256(b).hexdigest(),shifts={k:x['constants'][k] for k in sh},f_e=x['constants']['f_e'],norm_tn=x['constants']['norm_tn']))
    (HERE/'public-layer-constants.json').write_text(json.dumps(manifests,indent=2)+'\n')
    for row in result['census']:
        # Independent closed-form counts, not the source constructor recognizer.
        ls=row['ls']; t=row['context']; w=(t.bit_length()-1)+9
        counts=dict(L=2,D=34,F=9,Q=13,Kv=12,S=9+2*ls)
        borrowed=dict(L=2,D=28+(sh['sh_ao']==8)+(sh['sh_z']==8),F=7+(sh['sh_g']==8)+(sh['sh_h']==16),Q=4+(sh['sh_qkv']==8)+(sh['sh_o']==16),Kv=3+2*(sh['sh_qkv']==8),S=3+2*ls+(sh['sh_s']==8)+2*(w==8*ls))
        for dom,dc in row['domains'].items():
            assert dc['columns']==counts[dom] and dc['borrowable']==borrowed[dom]; checks+=2
        whole=sum(counts[d]*row['domains'][d]['padded_words']*8 for d in counts)
        avoid=sum(borrowed[d]*row['domains'][d]['padded_words']*8 for d in counts)
        assert whole==row['baseline_looked_bytes'] and avoid==row['borrowed_payload_bytes']
        assert row['remaining_owned_bytes']==whole-avoid and row['fraction']==avoid/whole; checks+=2
    old=(HERE/'native/protocol.rs').read_text(); new=(HERE/'protocol-candidate.rs').read_text()
    # Existing maps and helper functions are byte-identical in the review candidate.
    for first,last in [('pub(super) fn lookup_values(', '/// **STAGE 29 (finding S28-R1).** The word count above which the byte'),('pub(super) fn u8_denominator_inverses(', '// **FINDING F-4 OF THE INDEPENDENT REVIEW')]:
        assert old.split(first)[1].split(last)[0]==new.split(first)[1].split(last)[0]; checks+=1
    assert new.index('drop(looked);')<new.index('drop(wit);'); checks+=1
    assert 'Cow::Borrowed(&wit.planes[*p][..len])' in new and 'Cow::Owned((0..len)' in new; checks+=1
    assert old.count('rng.')==new.count('rng.') and old.count('tr.')==new.count('tr.'); checks+=1
    # Native legacy tests take Vec<Vec<i64>>; generic histogram retains this input.
    assert 'fn byte_histogram_at<C: AsRef<[i64]> + Sync>' in new; checks+=1
    out=dict(status='pass',checks=checks,independent_closed_form_rows=len(result['census']),public_layer_manifests=len(manifests),scope='independent accounting and source-identity audit; no native compile or proof',wall_seconds=time.perf_counter()-t0,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    (HERE/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps(out))

if __name__=='__main__': main()
