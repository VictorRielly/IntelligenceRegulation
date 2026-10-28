"""Final append-only evidence, source pins, reports and logical-unit audit."""
import hashlib, json, pathlib, resource, time
ROOT=pathlib.Path(__file__).resolve().parent;RESEARCH=ROOT.parent.parent
t0=time.monotonic();checks=0
def check(ok):
    global checks
    checks+=1
    if not ok:raise AssertionError(checks)
def read(n):return json.loads((ROOT/n).read_text())
manifest=read('artifact-manifest.json')
for item in manifest:
    data=(ROOT/item['path']).read_bytes()
    check(len(data)==item['bytes']);check(hashlib.sha256(data).hexdigest()==item['sha256'])
for pin in read('source-manifest.json'):
    check(hashlib.sha256(pathlib.Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    check(hashlib.sha256((ROOT/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
prior_sources=(ROOT/'startup/sources.jsonl').read_bytes()
prior_findings=(ROOT/'startup/FINDINGS.md').read_bytes()
new_sources=(ROOT/'source-records.jsonl').read_bytes()
check((RESEARCH/'sources.jsonl').read_bytes()==prior_sources+new_sources)
check((RESEARCH/'FINDINGS.md').read_bytes().startswith(prior_findings))
check(len(prior_sources.splitlines())==773);check(len(prior_findings.splitlines())==10447)
check(len(new_sources.splitlines())==9)
for line in (prior_sources+new_sources).splitlines():
    item=json.loads(line);check(bool(item.get('url')))
for item in (json.loads(x) for x in new_sources.splitlines()):
    check(item['run_id']=='20261021T061854Z-553803c5')
    check(item['access_date']=='2026-10-21')
    check(item['external_execution'] is False)
    check(item['reproduced_performance'] is False)
    for key in ('publication_date','verified_update_date','implementation_license','inspected_commit_id'):
        check(key in item)
prior=read('prior-hypotheses.json');current=read('hypotheses.json')
check(len(prior)==34);check(len(current)==35)
check([x['rank'] for x in current]==list(range(1,36)))
for a,b in zip(prior,current):
    check(a['rank']==b['rank'])
    if a['rank']!=25:check(a==b)
    for key in ('baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification'):
        check(key in b)
check(current[:4]==prior[:4])
check(read('result.json')['checks']==872684)
check(read('result.json')['control_types']==26)
check(read('audit-result.json')['checks']==219)
check(read('audit-result.json')['pinned_native_files']==6)
telemetry=read('target-accounting.json')
for k in ('proofs','passes','positions'):check(telemetry[k]==0)
for k in ('actual_model_context','actual_accelerator','witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_rate','total_workload_rate'):
    check(telemetry[k] is None)
for k in ('long_context_prefill','resident_model_proof_series','decode','counted_T512_profile_admitted'):
    check(telemetry[k] is False)
for x in read('cost-result.json'):
    check(x['source_shared_bit_data_bytes']>4*x['native_u8_helper_data_bytes'])
    data=sum(d['size']*d['source_bit_widths']*8 for d in x['domains'])
    check(data==x['source_shared_bit_data_bytes'])
for x in read('dedup-row-cost.json'):
    n=1<<x['log_cols']
    check(x['removed_H_total_data_and_mask_bytes']==x['removed_H_total_rows']*n*8)
    check(x['candidate_H_rows']==x['baseline_H_rows']-x['removed_H_total_rows'])
    if x['T']==512:check(x['removed_H_total_rows']==0)
    else:check(x['removed_H_reserved_mask_rows']==2)
    check(x['full_receipt_bytes_saved'] is None)
    check(x['actual_HWM_or_elapsed_saving'] is None)
for name in ('STATE.md','PROGRESS.md','progress/20261021T061854Z-553803c5.md','handoffs/20261021-affine-u8-sharing.md'):
    text=(RESEARCH/name).read_text()
    check('20261021T061854Z-553803c5' in text)
    check(len(text)>500)
for record in read('startup/manifest.json'):
    # Read-only project files and mandate must still match; state/progress and
    # append-only research findings/sources were intentionally changed above.
    path=pathlib.Path(record['path'])
    if path.name in ('STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl'):continue
    check(hashlib.sha256(path.read_bytes()).hexdigest()==record['sha256'])
result=dict(status='PASS',checks=checks,immutable_artifacts=len(manifest),
            native_source_pins=6,prior_sources_preserved=773,appended_sources=9,
            prior_findings_lines_preserved=10447,prior_hypotheses_preserved=34,
            final_hypotheses=35,measured_script_seconds=time.monotonic()-t0,
            rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
(ROOT/'artifact-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
