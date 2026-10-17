#!/usr/bin/env python3
"""Read-only validation of cycle artifacts and preserved historical prefixes."""
import datetime
import hashlib
import json
import os
import resource
import signal
import time
from pathlib import Path
H=Path(__file__).resolve().parent
B=H.parent.parent

def main():
    begin=time.perf_counter(); os.nice(19); os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2)); resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    checks=0
    def check(b):
        nonlocal checks
        assert b; checks+=1
    source_old=(H/'startup/sources.jsonl').read_bytes(); source_new=(B/'sources.jsonl').read_bytes()
    check(source_new.startswith(source_old)); records=[json.loads(l) for l in source_new.splitlines() if l.strip()]; check(len(records)==320)
    check(len({r['id'] for r in records})==len(records))
    check((B/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes()))
    for f in ['STATE.md','PROGRESS.md','progress/20261017T122624Z-c30acfa0.md']:
        s=(B/f).read_text(); check('20261017T122624Z-c30acfa0' in s); check('unmeasured' in s); check('0 / 0 / 0' in s)
    r=json.loads((H/'result.json').read_text()); check(r['status']=='pass'); check(r['threads']==1); check(len(r['controls'])==11)
    check(r['executed_source_sha256']==hashlib.sha256((H/'run.py').read_bytes()).hexdigest())
    check(r['proof_accounting']['accepted_complete_private_8b_proofs']==r['proof_accounting']['positions']==0)
    check(r['experiment_wall_seconds']<60 and r['peak_rss_kib']<512*1024)
    cm=json.loads((H/'candidate-metadata.json').read_text())
    check(cm['candidate_sha256']==hashlib.sha256((H/'protocol-candidate.rs').read_bytes()).hexdigest())
    check(cm['baseline_sha256']==hashlib.sha256((H/'native/protocol.rs').read_bytes()).hexdigest())
    for meta in ['native-pins.json','phase-source-pins.json']:
        for p,sha in json.loads((H/meta).read_text()).items(): check(hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha)
    source_drift=[]
    diagnostics=[]
    for device in ['cpu','gpu']:
        d=json.loads((H/f'retained/r4-{device}-phases.json').read_text()); p=Path(d['source_path'])
        check(hashlib.sha256(p.read_bytes()).hexdigest()==d['source_sha256'])
        check((p.parent/'prove.done').read_text().strip()=='0')
        check(d['guard']['exit']==d['guard']['child_rc']==0)
        check(d['blocks']==d['proved_event']['blocks']==22)
        check(d['proved_event']['receipt_bytes']==497665904)
        lines=(H/f'retained/r4-{device}-phase-lines.log').read_text().splitlines()
        events=[json.loads(l) for l in lines if l.startswith('{')]
        check(len(events)==1 and events[0]==d['proved_event'])
        walls=[float(l.split('|')[3]) for l in lines if l.startswith('PB-TIMING prove |') and 'WALL CLOCK' in l]
        check(len(walls)==22 and abs(sum(walls)-d['sum_block_wall_s'])<1e-8)
        lookup=d['phases']['A: lookup values + the byte histogram']; wall=d['guard']['child_wall_seconds']
        diagnostics.append(dict(device=device,process_seconds=wall,lookup_hist_seconds=lookup,conditional_direct_delete_mark_multiplier=wall/(wall-lookup),credited_positions=0))
    binary_pins={}
    root=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r3')
    for name in ['zk60_trained_block.release.bin','zk60_trained_block.gpu.release.bin']:
        p=root/name; before=p.stat(); h=hashlib.sha256()
        with p.open('rb') as f:
            while True:
                chunk=f.read(1024*1024)
                if not chunk: break
                h.update(chunk)
        after=p.stat(); check((before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns))
        binary_pins[str(p)]=dict(sha256=h.hexdigest(),bytes=after.st_size,scope='file identity at final inspection; owner launcher names this binary; no reexecution or rebuild')
    (H/'owner-binary-pins.json').write_text(json.dumps(binary_pins,indent=2)+'\n')
    artifact_pins={str(p.relative_to(H)):hashlib.sha256(p.read_bytes()).hexdigest() for p in H.rglob('*') if p.is_file() and p.name not in ['artifact-sha256.json','final-audit.json','final-audit.log']}
    (H/'artifact-sha256.json').write_text(json.dumps(artifact_pins,indent=2)+'\n')
    out=dict(status='pass',checks=checks,source_records=320,historical_prefixes_preserved=True,native_pins_stable=True,artifacts_pinned=len(artifact_pins),owner_phase_diagnostics=diagnostics,newly_credited_positions=0,wall_seconds=time.perf_counter()-begin,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='artifact/source/metadata checks; no native compile, proof, GPU or independent proof verification')
    (H/'final-audit.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps(out))

if __name__=='__main__': main()
