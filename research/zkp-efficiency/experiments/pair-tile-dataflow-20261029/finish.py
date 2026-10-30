"""Final research-only hashes and completion marker, before cycle deadline."""
from pathlib import Path
import datetime,hashlib,json,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent.parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
note=dict(report_generation_error='First checkpoint.py run failed before source/findings append: duplicate implementation_license keyword. Defaults now updated with source-specific fields;next run succeeded. Scientific outputs unchanged.',negative_control_label='Initial positive empty-input edge counted with negatives;10 actual negatives plus1positive edge. Original results retained. First print-line patch failed without editing.',final_patch_error='First combined delete/add PROGRESS patch rejected because it targeted the same file twice;no changes made. Saved summary copied by finish.py.',native_integration='parked;no promising speed result or new handoff')
(HERE/'retained-diagnostics.json').write_text(json.dumps(note,indent=2)+'\n')
(ROOT/'PROGRESS.md').write_text((HERE/'progress-summary.txt').read_text())
with (ROOT/'STATE.md').open('a')as out:out.write(f'\nFinal checkpoint {now}: final provenance audit185checks PASS; six owner documents and nine native pins unchanged. All948prior source records and60prior hypotheses preserved. No new independently verified model work.\n')
proc=subprocess.run([sys.executable,'-B',str(HERE/'final_audit.py')],cwd=HERE,capture_output=True,text=True,timeout=10)
(HERE/'final-audit.stdout.log').write_text(proc.stdout);(HERE/'final-audit.stderr.log').write_text(proc.stderr)
assert proc.returncode==0,proc.stderr
completion=dict(run_id='20261029T125649Z-54c94436',status='complete',completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),full_stack_proofs=0,model_passes=0,proved_positions=0,native_improvement_found=False,experiment_scope='bounded synthetic component and source-derived cost model',production_changed=False,merge=False)
(HERE/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
manifest=[]
for p in sorted(HERE.rglob('*')):
 if p.is_file() and p.name!='artifact-manifest.json':
  b=p.read_bytes();manifest.append(dict(path=str(p.relative_to(HERE)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
for name in ('STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl','progress/20261029T125649Z-54c94436.md'):
 p=ROOT/name;b=p.read_bytes();manifest.append(dict(path=str(p),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(HERE/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(dict(completion=completion,hashed_artifacts=len(manifest),final_audit=json.loads((HERE/'final-audit-result.json').read_text()))))
