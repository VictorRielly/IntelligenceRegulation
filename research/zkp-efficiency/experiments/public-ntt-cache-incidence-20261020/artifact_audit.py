"""Final evidence integrity: no candidate imports, no native/GPU work."""
from pathlib import Path
import datetime,hashlib,json,resource,time
E=Path(__file__).resolve().parent;R=E.parents[1];checks=0
def ck(x):
    global checks
    assert x
    checks+=1
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def run():
    t=time.monotonic();pins=json.loads((E/'artifact-hashes.json').read_text())
    for x in pins:ck(sha(E/x['file'])==x['sha256'])
    manifest=json.loads((E/'startup/manifest.json').read_text());changed=[]
    for x in manifest:
        source=Path(x['path']);name=str(source.relative_to(R.parents[1])).replace('/','__')
        ck(sha(E/'startup'/name)==x['sha256'])
        if source.name not in ['STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md']:
            if sha(source)!=x['sha256']:changed.append(str(source))
    original=(E/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
    ck((R/'FINDINGS.md').read_bytes().startswith(original))
    before=(E/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
    ck((R/'sources.jsonl').read_bytes().startswith(before))
    ledger=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()]
    ck(len(ledger)==718 and len(before.splitlines())==709)
    records=json.loads((E/'source-records.json').read_text());ck(ledger[-9:]==records)
    for x in records:
        ck(x['access_date']=='2026-10-20' and x['external_execution'] is False and x['reproduced_performance'] is False)
        ck(x['prior_exact_url_records']==sum(z.get('url')==x['url'] for z in ledger[:709]))
    for x in json.loads((E/'source-pins.json').read_text()):ck(sha(E/x['copy'])==x['sha256'])
    results=[json.loads((E/f).read_text()) for f in ['result.json','validation-result.json','census-result.json']]
    for x in results:ck(x['status']=='PASS')
    probe,ind,census=results
    ck(probe['synthetic_rows']==ind['rows']==192)
    ck(probe['encoded_positions']==ind['positions']==7392)
    ck(len(probe['negative_controls'])==15 and all(probe['negative_controls'].values()))
    ck(ind['capacity_events']==50240 and census['trace_rows']==ind['trace_rows']==145)
    hypotheses=json.loads((E/'hypotheses.json').read_text());ck([x['rank'] for x in hypotheses]==list(range(1,30)))
    old=json.loads((E/'source/prior__dyadic-dd-shards-20261020__hypotheses.json').read_text())
    for a,b in zip(hypotheses[:27],old[:27]):ck(a==b)
    full=json.loads((E/'target-accounting.json').read_text())['full_stack']
    for k in ['proofs','passes','positions']:ck(full[k]==0)
    for k in ['context_length','accelerator','witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_state_proved_positions_per_s','total_workload_proved_positions_per_s']:ck(full[k] is None)
    for x in census['summary_T128_L32_deferred']:
        r=x['passes'];is_cached=x['cached']
        ck(x['device_offered_requests']==97*r and x['public_requests']==129*r)
        ck(x['device_powers_uploaded_B']==(524288 if is_cached else 50855936*r))
        ck(x['cpu_public_words_built']==(65536 if is_cached else 6488064*r))
        ck(x['selected_device_peak_B']==(524288 if is_cached else 2621440))
        ck(x['private_salt_bytes_unchanged']==207618048*r)
    for f in ['STATE.md','PROGRESS.md','progress/20261020T231854Z-2da27679.md']:
        s=(R/f).read_text();ck('20261020T231854Z-2da27679' in s)
        ck('unmeasured' in s and 'unachieved' in s and '0 / 0 / 0' in s)
    report=dict(status='PASS',checks=checks,artifact_pins=len(pins),source_ledger_before=709,source_ledger_after=718,
                preserved_prior_ranked_hypotheses=27,changed_mandatory_public_documents=changed,
                elapsed_s=time.monotonic()-t,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (E/'artifact-audit-result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':run()
