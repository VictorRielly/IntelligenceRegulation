from pathlib import Path
import hashlib,json
D=Path(__file__).resolve().parent;B=D.parent.parent
checks=0
def check(v,why=''):
    global checks
    assert v,why
    checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pins=json.loads((D/'native-pins.json').read_text())
for pin in pins:
    check(sha(D/pin['snapshot'])==pin['sha256'],'frozen snapshot')
    check(sha(Path(pin['path']))==pin['sha256'],'native source unchanged')
for pin in json.loads((D/'lineage.json').read_text()):
    check(sha(Path(pin['source']))==pin['prior_sha256'],'prior helper unchanged')
    check(sha(Path(pin['target']))==pin['sha256'],'current helper hash')
    if not pin['modified']:check(pin['sha256']==pin['prior_sha256'],'copied helper exact')
for pin in json.loads((D/'seam-pins.json').read_text()):
    check(sha(Path(pin['path']))==pin['sha256'],'seam changed since current snapshot')
    check(sha(D/pin['snapshot'])==pin['sha256'],'seam snapshot')
    check(pin['unchanged'],'seam changed since last cycle; no promotion')
docs=[]
for pin in json.loads((D/'startup-documents.json').read_text()):
    docs.append(dict(path=pin['path'],unchanged=sha(Path(pin['path']))==pin['sha256'],current_sha256=sha(Path(pin['path']))))
(D/'owner-document-recheck.json').write_text(json.dumps(docs,indent=2)+'\n')
prior=json.loads((D/'prior-hypotheses.json').read_text());hs=json.loads((D/'hypotheses.json').read_text())
check(hs[:len(prior)]==prior,'prior hypotheses preserved')
check(len(hs)==len(prior)+2)
check([x['rank'] for x in json.loads((D/'ranking-current.json').read_text())['owner_priorities']]==[1,2,3])
for name in ['FINDINGS.md','sources.jsonl']:
    check((B/name).read_bytes().startswith((D/('prior-'+name)).read_bytes()),'append only')
check((B/'AGENDA.md').read_bytes()==(D/'prior-AGENDA.md').read_bytes(),'mandate changed: reread')
r=json.loads((D/'result.json').read_text());c=json.loads((D/'census-result.json').read_text())
check(r['status']==c['status']=='PASS')
check(len(r['profiles'])==14)
check(c['exact_comparisons']==sum(5*8*p['groups']*p['width'] for p in r['profiles']),'value subtotal accounting')
check(c['controls']==367 and c['source_row_narrow_comparisons']==24320)
check(c['exhaustive_objectives']==840 and c['exhaustive_partition_candidates']==33362)
for p in c['source_profiles']:
    base=p['policies'][0]
    for s in p['policies']:
        check(s['logical_B']==p['n']*(8*s['visits']+16*s['macs']+8*s['spans']))
        check(s['logical_B']>=base['logical_B'])
        check(s['extra_basefield_multiplications']==2*p['n']*s['extra_macs'])
for stage in ['compile','probe','census']:
    e=json.loads((D/(stage+'-execution.json')).read_text())
    check(e['exit_code']==0 and e['wall_s']<60)
    check(e['max_rss_kib']<512*1024 and e['address_space_mib']==384)
    check(e['one_cpu_affinity'] and not e['gpu'])
ss=[json.loads(x) for x in (D/'sources-cycle.jsonl').read_text().splitlines()]
check(len(ss)==6)
for s in ss:
    check(s['access_date']=='2026-10-29' and s['url'].startswith('https://'))
    check('publication_date' in s and 'verified_update_date' in s and 'implementation_license' in s and 'inspected_commit_id' in s)
    check(not s['reproduced_performance'] and not s['external_execution'])
for p in D.glob('web*-provenance.json'):
    s=json.loads(p.read_text());check(len(s['response_sha256'])==64 and s['response_bytes']>0)
    check(all(' ' not in u and '\n' not in u for u in s['urls']))
check(len(list(D.glob('web*-provenance.json')))==11)
target=json.loads((D/'target-accounting.json').read_text())
check(target['new_independently_verified_full_stack_proofs']==target['proved_positions']==target['completed_model_passes']==0)
check(not target['target_achieved'] and target['accelerator'] is None)
out=dict(status='PASS',checks=checks,native_pins=len(pins),seams=6,prior_hypotheses_preserved=len(prior),hypotheses=len(hs),
    owner_documents=docs,full_stack_proofs=0,model_passes=0,proved_positions=0)
(D/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
