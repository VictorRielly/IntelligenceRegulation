"""Bounded final report/provenance audit. Writes only this research folder."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time

HERE=Path(__file__).resolve().parent
BASE=HERE.parents[1]


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024*1024,512*1024*1024))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59);os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});start=time.perf_counter();checks=0
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    r=json.loads((HERE/'result.json').read_text());a=json.loads((HERE/'audit.json').read_text())
    assert r['status']==a['status']=='pass';checks+=1
    assert json.loads((HERE/'execution.json').read_text())['exit_code']==0;checks+=1
    for name,want in json.loads((HERE/'command.json').read_text())['source_sha256'].items():
        assert sha(HERE/name)==want,name;checks+=1
    assert (BASE/'FINDINGS.md').read_bytes().startswith((HERE/'startup/FINDINGS.md').read_bytes());checks+=1
    old=(HERE/'startup/sources.jsonl').read_bytes();new=(BASE/'sources.jsonl').read_bytes()
    assert new.startswith(old);checks+=1
    records=[json.loads(x) for x in new.decode().splitlines()]
    additions=json.loads((HERE/'sources-cycle57.json').read_text())
    assert records[-len(additions):]==additions and len(records)==292;checks+=1
    oldids={x.get('id') for x in records[:-len(additions)]}
    newids=[x['id'] for x in additions];assert len(newids)==len(set(newids));checks+=1
    assert not oldids.intersection(newids);checks+=1
    for p in json.loads((HERE/'native-pins.json').read_text()):
        assert sha(Path(p['path']))==p['sha256'];checks+=1
    owner=[]
    for p in json.loads((HERE/'startup-manifest.json').read_text()):
        path=Path(p['path'])
        if path.is_relative_to(BASE):continue
        assert sha(path)==p['sha256'];checks+=1;owner.append(str(path))
    for name in ('initial-negative-control-refusal','initial-within-pair-control-assumption'):
        assert json.loads((HERE/name/'execution.json').read_text())['exit_code']!=0;checks+=1
        assert (HERE/name/'run.log').stat().st_size>0;checks+=1
    for p in [BASE/'STATE.md',BASE/'PROGRESS.md',BASE/'progress/20261017T072624Z-c38c878c.md',
              HERE/'README.md',BASE/'handoffs/20261017-native-capture-adapter.md']:
        s=p.read_text();assert '20261017T072624Z-c38c878c' in s;checks+=1
        for word in ['unmeasured','0/0/0','50','CPU','native']:
            assert word.lower() in s.lower(),(p,word);checks+=1
    assert (BASE/'PROGRESS.md').read_bytes()==(BASE/'progress/20261017T072624Z-c38c878c.md').read_bytes();checks+=1
    accounting=r['proof_accounting']
    for k in ('completed_independently_verified_8b_proofs','completed_passes','proved_tokens'):
        assert accounting[k]==0;checks+=1
    for k in ('context_length','steady_state_tokens_per_second','total_workload_tokens_per_second','startup_seconds','startup_fraction',
              'witness_seconds','proof_seconds','serialization_seconds','verification_seconds','proof_latency_seconds'):
        assert accounting[k] is None;checks+=1
    assert r['wall_seconds']<59 and r['max_rss_kib']<512*1024;checks+=1
    assert len(list((HERE/'generated').glob('*.py')))==96;checks+=1
    assert a['checks']==13047;checks+=1
    result={'status':'pass','checks':checks,'checked_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'wall_seconds':time.perf_counter()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'native_and_measurement_pins':12,'owner_memory_files':len(owner),'historical_source_count':288,'new_source_count':4,
            'historical_prefixes_preserved':True,'complete_private_8b_token_credit':0}
    (HERE/'checkpoint-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))


if __name__=='__main__':main()
