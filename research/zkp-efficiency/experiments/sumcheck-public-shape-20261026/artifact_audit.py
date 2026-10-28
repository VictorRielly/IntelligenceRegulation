"""Final integrity/scope audit. No native build, proof or patch application."""
import hashlib
import json
import re
import resource
import time
from pathlib import Path

P=Path(__file__).resolve().parent
R=P.parents[1]
checks=0


def check(v,label):
    global checks
    assert v,label
    checks+=1


def main():
    start=time.monotonic()
    for name in ['FINDINGS.md','sources.jsonl']:
        check((R/name).read_bytes().startswith((P/'startup'/name).read_bytes()),'prior '+name+' prefix preserved')
    sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
    check(len(sources)==814,'all source records parse')
    check(len([json.loads(x) for x in (P/'source-records.jsonl').read_text().splitlines()])==7,'new source count')
    prior=json.loads((P/'prior-hypotheses.json').read_text())
    current=json.loads((P/'hypotheses.json').read_text())
    check(len(prior)==38 and len(current)==39,'hypothesis inventory')
    for old,new in zip(prior,current):
        check(old['rank']==new['rank'],'rank preserved')
        if old['rank'] not in (1,14):check(old==new,'previous hypothesis unchanged')
    for d in current:
        for field in ['rank','title','baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:
            check(field in d,'hypothesis requirement '+field)
    pins=json.loads((P/'source-manifest.json').read_text())
    for pin in pins:
        data=(P/pin['snapshot']).read_bytes()
        check(hashlib.sha256(data).hexdigest()==pin['sha256'],'retained snapshot pin')
        if '/docs/' not in pin['path']:
            check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],'current tested source pin')
    pin=next(x for x in pins if x['path'].endswith('/trained-1b/zkp-core/src/mle.rs'))
    original=(P/pin['snapshot']).read_text()
    candidate=(P/'candidate-mle.rs').read_text()
    patch=(P/'finite-difference.patch').read_text().splitlines(True)
    # Apply unified diff in memory, verifying every unchanged line and offset.
    old=original.splitlines(True);output=[];cursor=0;i=2
    while i<len(patch):
        match=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',patch[i])
        check(match is not None,'patch hunk syntax')
        at=int(match.group(1))-1
        check(at>=cursor,'patch hunk order')
        output.extend(old[cursor:at]);cursor=at;i+=1
        while i<len(patch) and not patch[i].startswith('@@'):
            line=patch[i];i+=1
            check(line[:1] in (' ','+','-'),'patch line syntax')
            if line[0] in (' ','-'):
                check(old[cursor]==line[1:],'patch source context')
                cursor+=1
            if line[0] in (' ','+'):output.append(line[1:])
    output.extend(old[cursor:])
    check(''.join(output)==candidate,'patch matches retained candidate in memory')
    check(candidate.count('pub fn interpolate_eval(')==1,'one interface')
    check(candidate.count('den.inv()')==original.count('den.inv()'),'generic fallback retained')
    check('if (2..=6).contains(&m)' in candidate,'public sample-count dispatch')
    constants=[int(x) for x in re.findall(r'Fp\((\d+)\)',candidate.split('const INV_FACT:')[1].split('];')[0])]
    import math
    prime=2**64-2**32+1
    check(len(constants)==6,'six Rust public constants')
    for i,v in enumerate(constants):check(v*math.factorial(i)%prime==1,'Rust factorial constant')
    accounting=json.loads((P/'target-accounting.json').read_text())
    for key in ['new_completed_independently_verified_full_stack_proofs','new_completed_passes','new_proved_positions']:
        check(accounting[key]==0,'no unproved work counted')
    for key in ['steady_state_positions_per_second','total_workload_positions_per_second','startup_fraction','witness_seconds','proof_seconds','serialization_seconds','verification_seconds']:
        check(accounting[key] is None,'no invented clock/rate')
    check(not accounting['target_achieved'] and not accounting['private_masks_reused'],'target and privacy limits')
    for name in ['README.md','result.json','audit-result.json','source-drift.json','source-manifest.json','commands.jsonl']:
        check((P/name).is_file(),'required artifact '+name)
    manifests=json.loads((P/'artifact-manifest.json').read_text())
    for row in manifests:
        check(hashlib.sha256((P/row['path']).read_bytes()).hexdigest()==row['sha256'],'immutable artifact hash')
    out={'status':'PASS_FINAL_INTEGRITY_ONLY','checks':checks,'immutable_artifacts':len(manifests),
         'tested_code_pins':15,'retained_coordination_snapshot_pins':1,'patch_applied':'in memory only',
         'new_verified_full_stack_positions':0,'elapsed_seconds':time.monotonic()-start,
         'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
    (P/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out))


if __name__=='__main__':main()
