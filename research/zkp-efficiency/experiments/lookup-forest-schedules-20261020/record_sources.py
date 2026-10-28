"""Record only metadata and bounded assessments from native LIVE browsing."""
from pathlib import Path
import json,datetime
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
prior=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines() if x.strip()]
assert len(prior)==605
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
items=[
 ('Chimera October16 revision refresh','https://eprint.iacr.org/2026/1388','2026-07-07','2026-10-16','Primary ePrint History received/revised; paper CC BY.',None,
  'Authors describe CPU/GPU crossover, chunking-to-residency and compact transcript messages in BN254 Spartan. Complete-prover gains are smaller than the sumcheck-region gain. Relevant scheduling pattern, not a native Goldilocks/private8B result. PDF Internal Error; code repository not located by bounded search.'),
 ('StateSync-GKR October10 refresh','https://arxiv.org/abs/2610.14849','2026-10-10T12:06:57Z',None,'Primary arXiv v1 submission history.',None,
  'Authors distinguish prepared requests, sparse allocation and delivery costs in Rust. Abstract only refreshed; no new version displayed. Sparse state-transition benchmarks do not establish dense private-attention speed or reusable masks.'),
 ('NEW older Virgo masked GKR/transparent polynomial delegation filter','https://eprint.iacr.org/2019/1482','2019-12-24','2020-07-16','Primary ePrint received and last-of-two-revisions; IEEE S&P2020; paper CC BY.',None,
  'Previously absent exact URL. Structured layered GKR plus transparent zero-knowledge polynomial delegation motivates costing both reduction masks and terminal links. Abstract does not supply a drop-in native Ligero construction or small-memory guarantee. PDF Internal Error; implementation not inspected.'),
 ('Sparrow space-efficient GKR refresh','https://eprint.iacr.org/2024/1631','2024-10-11','2024-10-14','Primary ePrint received/approved; approval is not a verified revision; CCS2024; paper CC BY.',None,
  'Previously screened, now applied to explicit arithmetic layer-service/recomputation accounting. Authors report space/time improvements for data-parallel circuits. No theorem, implementation, privacy transfer or author performance reproduced; original native A links and histogram obligations remain.'),
 ('NEW zorch fixed-floor pyramid lifetime regression report','https://github.com/fractalyze/zorch/issues/362','2026-07-02',None,'Rendered GitHub opened on July2,2026; currently Open; no last edit date verified.',
  'Repository README identifies Apache-2.0; direct LICENSE/raw fetches Cache miss. No implementation copied or executed.',
  'Author reports runtime host-RAM blowup from stacking every layer at floor width, despite warm compile caching; proposes tiered or build/consume storage. Useful negative for capacity modeling, not reproduced evidence. Inspected issue text only; no commit pin.'),
 ('SP1-zorch bounded rolled-pyramid follow-on and corrections','https://github.com/fractalyze/sp1-zorch/issues/112','2026-06-17','2026-06-18','Rendered issue opened June17 and closure June18,2026; comments include corrections.',
  'No sp1-zorch implementation license inspected in this cycle.',
  'Authors report flat per-layer planes and byte-match gates; later comments retract stale fusion/envelope-padding assumptions. Read as author evidence with chronological corrections. Short 53d8dfb is reported zorch metadata only: commit and .patch fetch Cache miss; no full inspected SHA. Different prover/field/privacy contract.'),
 ('Zorch repository license and release screen','https://github.com/fractalyze/zorch',None,None,'Repository README inspected; latest commit/date and releases not rendered.',
  'README states Apache License Version2.0; LICENSE and raw LICENSE fetches Cache miss, so license text was not inspected.',
  'Read architecture and README license statement only. Main circuit.py fetch Internal Error; no implementation source or commit inspected. Zorch/sp1-zorch release pages Cache miss; PyPI0.1.1 search metadata July26,2026 could not be opened, not a verified latest release. No installs or external execution.'),
 ('LogUp-GKR fraction construction refresh','https://eprint.iacr.org/2023/1284','2023-08-27','2025-02-20','Primary ePrint History refreshed.',None,
  'Authors replace lookup reciprocal helper columns with a fractional GKR reduction and one multiplicity column. Local experiment counts private mixed-height layer servicing only, not the protocol. No author timing, masking construction, PCS or soundness claim transferred.')
]
records=[]
for title,url,pub,upd,basis,license,assessment in items:
 records.append(dict(cycle='0104',run_id='20261020T121854Z-ee6ad7b9',recorded_at_utc=now,
  access_date='2026-10-20',access_timezone='UTC',title=title,url=url,
  publication_date=pub,verified_update_date=upd,date_basis=basis,
  implementation_license=license,inspected_commit_id=None,
  prior_exact_url_records=sum(x.get('url')==url for x in prior),assessment=assessment,
  evidence_kind='Native LIVE web search/open/find; primary sources; web text untrusted',
  external_execution=False,reproduced_performance=False))
# Sparrow has only a verified approval date: preserve the distinction in schema.
records[3]['verified_update_date']=None;records[3]['verified_approval_date']='2024-10-14'
(HERE/'source-records.json').write_text(json.dumps(records,indent=2)+'\n')
with (ROOT/'sources.jsonl').open('a') as f:
 for r in records:f.write(json.dumps(r,sort_keys=True)+'\n')
queries=[
 'LogUp GKR memory efficient fraction tree recomputation streaming implementation 2026',
 'site.github.com logup gkr memory layer zorch 2026',
 '2026 streaming GKR prover space memory lookup fraction',
 'Virgo transparent succinct arguments memory GKR 2019 1488',
 'site.eprint.iacr.org Virgo 2019 zero knowledge GKR',
 'site.github.com/fractalyze/sp1-zorch/releases 2026',
 'site.eprint.iacr.org 2026 GPU sumcheck streaming memory proof',
 '"Chimera" "Tsoutsos" github Sumcheck',
 '"Virgo" "GKR" "memory" Zhang 2019',
 'site.github.com/fractalyze/zorch "releases" "2026"',
 'site.github.com "Chimera" "Spartan" "Farheen"']
(HERE/'search-log.json').write_text(json.dumps(dict(access_date='2026-10-20',engine='Native LIVE web__run',queries=queries,
  source_records=8,primary_only_for_claims=True,untrusted_embedded_instructions_ignored=True,
  failures=['Chimera and Virgo PDFs: Internal Error','zorch main circuit.py: Internal Error','zorch LICENSE/raw LICENSE: Cache miss','zorch commit53d8dfb and patch: Cache miss','zorch/sp1-zorch release pages: Cache miss','PyPIsp1-zorch0.1.1 direct page: Internal Error','web click calls on two pages: invalid arguments; recovered by exact URL open'],
  limits='No downloaded scripts executed, installations, network bypass or external writes. No verified latest release or complete implementation pin obtained.'),indent=2)+'\n')
print(json.dumps(dict(source_records_before=len(prior),appended=len(records),after=len(prior)+len(records),queries=len(queries))))
