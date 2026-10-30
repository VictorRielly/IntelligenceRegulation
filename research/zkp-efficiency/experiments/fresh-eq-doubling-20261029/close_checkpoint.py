from pathlib import Path
import json,datetime
H=Path(__file__).resolve().parent;R=H.parent.parent;run='20261029T145649Z-fb1b89ab'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
paths=[H/'README.md',R/'FINDINGS.md',R/'progress'/f'{run}.md']
for p in paths:
 s=p.read_text();old='accounting1.242728s /\n15,824KiB';assert s.count(old)==1
 p.write_text(s.replace(old,'accounting0.958972s /\n16,064KiB'))
# Keep the report generator consistent with the final measured accounting.
p=H/'finish.py';s=p.read_text();s=s.replace('15,824KiB,344checks','16,064KiB,344checks');p.write_text(s)
blockers=json.loads((H/'blockers.json').read_text())
cachemiss=[
'https://github.com/quangvdao/monomial-sumcheck-benchmarks/blob/main/src/lookup_tables.rs',
'https://raw.githubusercontent.com/quangvdao/monomial-sumcheck-benchmarks/main/src/lookup_tables.rs',
'https://github.com/quangvdao/monomial-sumcheck-benchmarks/releases',
'https://github.com/quangvdao/monomial-sumcheck-benchmarks/blob/main/LICENSE',
'https://github.com/EspressoSystems/hyperplonk/blob/main/LICENSE',
'https://raw.githubusercontent.com/EspressoSystems/hyperplonk/main/LICENSE',
'https://github.com/EspressoSystems/hyperplonk/pull/21',
'https://github.com/EspressoSystems/hyperplonk/blob/2a3b55c97ad8a5d6627108a2e7def2aeccb7f3b9/arithmetic/src/virtual_polynomial.rs',
'https://github.com/EspressoSystems/hyperplonk/blob/70b0df5c52fd07a0c63ba397bcd9ed596ef282b3/LICENSE']
blockers['exact_failures']=[dict(url=u,error='Failed to fetch: Cache miss',tool='native LIVE web__run')for u in cachemiss]+[dict(url='https://eprint.iacr.org/archive/versions/2026/762',error='(403) Forbidden',tool='native LIVE web__run')]+[dict(url=u,error='URL is not accessible via this tool',tool='native LIVE web__run')for u in ['https://eprint.iacr.org/2026/2494','https://eprint.iacr.org/2026/2494.pdf']]
(H/'blockers.json').write_text(json.dumps(blockers,indent=2)+'\n')
with (R/'STATE.md').open('a')as f:f.write(f'\nClosing audit {now}:188checks PASS;14native pins and six owner documents unchanged. Prior findings/source bytes and61prior hypotheses preserved. Final accounting records0.958972s/16,064KiB after distinguishing empty Vec construction from nonempty payload allocation; no arithmetic/source patch changed. No new model work.\n')
c=json.loads((H/'completion.json').read_text());c['final_checkpoint_utc']=now;c['final_audit_checks']=188
(H/'completion.json').write_text(json.dumps(c,indent=2)+'\n')
print(json.dumps(dict(final_checkpoint_utc=now,status='complete',source_records=971)))
