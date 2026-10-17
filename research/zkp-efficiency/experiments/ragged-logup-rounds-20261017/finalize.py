"""Read-only evidence checks, then research-only checkpoint and hash manifest."""
from pathlib import Path
import datetime,hashlib,json,re
H=Path(__file__).resolve().parent;B=H.parent.parent
def read(name):return json.loads((H/name).read_text())
result=read('result.json');audit=read('audit-result.json');acc=read('accounting.json');commands=read('commands.json')
assert result['status']==audit['status']==acc['status']=='PASS'
assert len(result['negative_controls'])==23 and all(result['negative_controls'].values())
assert len((B/'sources.jsonl').read_bytes().splitlines())==365
assert all(c['exit_code']==0 and c['elapsed_s']<60 for c in commands)
assert (B/'sources.jsonl').read_bytes().startswith((H/'startup/sources.jsonl').read_bytes())
assert (B/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes())
assert result['fixture_sha256']==hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest()
wrapper=(H/'field-only.rs').read_text().split('mod field {',1)[1].rsplit('}',1)[0].strip()
native=(H/'native/field.rs').read_text().split('#[cfg(test)]')[0].strip()
assert wrapper==native.replace('//!','//')
# Earlier exploratory assertion failed because its field-doc normalization was
# missing. Retain it as audit metadata; no arithmetic or test outcome changed.
failure=dict(status='FAILED_ASSERTION_RETAINED',stage='Initial artifact provenance audit',command='inline Python artifact audit, 2026-10-17',error='AssertionError at raw field-prefix equality',reason='Prior captured field module changes inner doc comments //! to ordinary //; wrapper and test removal were already accounted for, this comment transformation was not.',resolution='Exact field-body equality after only the documented //! -> // transformation. Final audit below verifies it.',arithmetic_tests_affected=False)
(H/'artifact-audit-first-error.json').write_text(json.dumps(failure,indent=2)+'\n')
drift=[]
for pin in read('native-pins.json'):
 assert hashlib.sha256((H/pin['capture']).read_bytes()).hexdigest()==pin['sha256']
 current=hashlib.sha256(Path(pin['source']).read_bytes()).hexdigest()
 drift.append(dict(source=pin['source'],captured_sha256=pin['sha256'],current_sha256=current,unchanged=current==pin['sha256']))
(H/'source-drift.json').write_text(json.dumps(drift,indent=2)+'\n')
now=datetime.datetime.now(datetime.timezone.utc);stamp=now.isoformat()
state=(B/'STATE.md').read_text();state=re.sub(r'Checkpoint: 2026-10-17 \d\d:\d\d UTC\.',f'Checkpoint: {now:%Y-%m-%d %H:%M} UTC.',state,count=1);(B/'STATE.md').write_text(state)
checkpoint=dict(status='COMPLETE',cycle='0069',run_id='20261017T222105Z-d6d7aa4d',started_at_utc='2026-10-17T22:21:05.479314+00:00',completed_at_utc=stamp,next_cycle_no_earlier_than_utc='2026-10-17T23:21:05.479314+00:00',no_new_proving_speedup=True,new_target_compliant_proofs=0,new_target_compliant_passes=0,new_target_compliant_positions=0,steady_state_rate=None,total_workload_target_rate=None,report='progress/20261017T222105Z-d6d7aa4d.md',handoff='handoffs/20261017-ragged-logup-rounds.md',all_local_processes_completed=True,no_gpu_or_heavy_job_queued=True,prior_source_and_findings_prefixes_preserved=True,scope='Synthetic arithmetic and counted geometry; no native proof/PCS/GKR/privacy reproduction.')
(H/'checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n')
paths=[p for p in H.rglob('*')if p.is_file()and p.name not in ['artifact-manifest.json','artifact-audit.json']]
paths += [B/x for x in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl','progress/20261017T222105Z-d6d7aa4d.md','handoffs/20261017-ragged-logup-rounds.md']]
manifest=[dict(path=str(p.relative_to(B)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())for p in sorted(paths)]
(H/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for row in manifest:assert hashlib.sha256((B/row['path']).read_bytes()).hexdigest()==row['sha256']
summary=dict(status='PASS',files=len(manifest),all_native_snapshot_hashes_match=True,fixture_hash_matches=True,source_prefix_preserved=True,findings_prefix_preserved=True,native_field_capture_exact_after_documented_comment_conversion=True,completed_commands=len(commands),independent_arithmetic_checks=audit['checks'],source_drift_files=sum(not r['unchanged']for r in drift),initial_provenance_audit_failure_retained=True,scope='Artifact integrity and local arithmetic only; not cryptographic verification.',completed_at_utc=stamp)
(H/'artifact-audit.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
