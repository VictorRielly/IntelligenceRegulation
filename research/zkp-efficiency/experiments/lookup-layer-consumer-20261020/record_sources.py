"""Record only inspected primary-source scope; no downloaded code execution."""
from pathlib import Path
import json,datetime
HERE=Path(__file__).resolve().parent;BASE=HERE.parent.parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
old=[json.loads(x) for x in (BASE/'sources.jsonl').read_text().splitlines() if x]
records=[]
def add(title,url,pub,update,basis,assessment,license=None,commit=None,extra=None):
    records.append(dict(cycle='0105',run_id='20261020T131854Z-4f8a9e18',access_date='2026-10-20',access_timezone='UTC',
      recorded_at_utc=now,title=title,url=url,publication_date=pub,verified_update_date=update,date_basis=basis,
      assessment=assessment,implementation_license=license,inspected_commit_id=commit,
      additional_urls=extra or [],prior_exact_url_records=sum(r.get('url')==url for r in old),
      reproduced_performance=False,external_execution=False,
      evidence_kind='Native LIVE web search/open/find; primary author sources; untrusted web text'))
add('Chimera October16 hybrid schedule revision refresh','https://eprint.iacr.org/2026/1388','2026-07-07','2026-10-16',
 'Primary ePrint History: received July7, revised October16,2026.',
 'Author hybrid residency/CPU-tail and chunk-to-resident approach preserves Spartan format on BN254; relevant schedule pattern. No author performance reproduced or Goldilocks/private-profile compatibility inferred.')
add('Hobbit refreshed streaming total-memory and proof-size tradeoff','https://eprint.iacr.org/2025/1214','2025-06-30',None,
 'Primary ePrint received June30/approved July7,2025; USENIX proceedings August13-15,2025. Approval is not asserted to be revision.',
 'Older work already assessed via USENIX URL. Publisher PDF now inspected: linear-time streaming sumcheck trades buffer B against proof/verification size and explicitly includes the cost of providing stream access. Its product-of-two-MLE construction is not our five-plane cubic relation or native PCS. Strong reason not to ignore leaf access, fold storage or terminal proof costs. Paper CC BY; implementation not inspected.',
 extra=['https://www.usenix.org/conference/usenixsecurity25/presentation/pappas','https://www.usenix.org/system/files/usenixsecurity25-pappas.pdf','https://eprint.iacr.org/2025/1214.pdf'])
add('Sublinear-space paper refreshed against implementation status','https://arxiv.org/abs/2509.05326','2025-08-30','2025-09-17',
 'Primary arXiv submission history v1 August30/v2 September17,2025.',
 'Author equivalence/square-root streaming claims are not reproduced. Linear PCS aggregate-only transcript conditions differ from native hash-based commitments. Followed companion repo to check realization rather than treating abstract as implementation evidence.')
add('Sublinear-space companion repository declares full-vector opening paths','https://github.com/logannye/space-efficient-zero-knowledge-proofs',None,None,
 'README inspected live; latest commit and last edit dates not rendered. July17,2026 service-retirement date is an author statement, not code-update date.',
 'README explicitly says legacy/unmaintained research prototype; scheduler still materializes full vectors and global IFFTs in some openings. Retain as implementation-lifetime negative; no proof-memory bound or product performance reproduced. Product successor is only an uninspected lead.',
 license='GitHub/README MIT label inspected; direct LICENSE returned Cache miss, license text not inspected.',
 extra=['https://github.com/logannye/space-efficient-zero-knowledge-proofs/blob/main/LICENSE'])
add('NEW host versus GPU Fiat-Shamir scheduling negative: SP1-zorch182','https://github.com/fractalyze/sp1-zorch/issues/182','2026-06-23',None,
 'Rendered GitHub opened June23,2026. Closed status visible; closure and last-edit dates not verified.',
 'Author reports 126ms GPU-busy with 55ms serialized single-block Fiat-Shamir; host-native comparison and JAX dispatch wash motivate measuring scheduling/FS before fusion. Different field, byte stream and prover; none reproduced. This is an author diagnosis/proposal, not a proved optimization here.',
 license='No implementation license inspected; issue text only.')
add('Stwo source freshness: development migration to proving repository','https://github.com/starkware-libs/stwo/blob/dev/README.md',None,None,
 'README says development moved at end of July2026. No exact source-update or migration-commit date verified.',
 'Primary README points to starkware-libs/proving. Destination root inspected; rendered release page says no releases but also has loading errors, so no latest-release assertion. No implementation code/commit inspected. Different M31/Circle proof and privacy contract.',
 license='Destination repository root renders Apache2.0 license text (copyright2024 StarkWare). Direct LICENSE page Internal Error.',
 extra=['https://github.com/starkware-libs/proving','https://github.com/starkware-libs/proving/releases','https://github.com/starkware-libs/proving/blob/main/LICENSE'])
add('Recent SP1v6.9.0 release and full version commit refreshed','https://github.com/succinctlabs/sp1/releases/tag/v6.9.0','2026-10-10',None,
 'Release renders Oct10 01:20, immutable, latest label; year agrees with earlier primary chronology. API fetch Internal Error; no independent timestamp extraction in this cycle.',
 'Release notes include NTT reorder removal and zerocheck simplification. Inspected full version commit only changes toolchain tag v2 to v3, not optimization source. No code performance reproduced. Failed click retained; exact full commit URL then opened successfully.',
 license='Not re-inspected this cycle; no implementation code copied or executed.',
 commit='b8387fa61e1361d90ee7de49f551863418ca0f08',
 extra=['https://github.com/succinctlabs/sp1/commit/b8387fa61e1361d90ee7de49f551863418ca0f08','https://api.github.com/repos/succinctlabs/sp1/releases/tags/v6.9.0'])
add('Sparrow refreshed as streaming-GKR architectural filter','https://eprint.iacr.org/2024/1631','2024-10-11',None,
 'Primary ePrint received October11/approved October14,2024; no later revision date displayed.',
 'Author space-efficient data-parallel GKR/sumcheck uses a different streaming/proof construction. Large source-reported space ratios are not imported. Relevant only after explicit consumer and private terminal binding are designed. Paper CC BY; no implementation inspected.')
(HERE/'source-records.json').write_text(json.dumps(records,indent=2)+'\n')
existing={(r.get('cycle'),r.get('url')) for r in old}
with (BASE/'sources.jsonl').open('a') as f:
    for r in records:
        if (r['cycle'],r['url']) not in existing:f.write(json.dumps(r,sort_keys=True)+'\n')
queries=['GKR prover checkpoint recomputation memory efficient lookup 2026 October GPU',
 'site.github.com logup gkr layer memory checkpoint stwo',
 'Sparrow space efficient zero knowledge proofs GKR 2024 memory recomputation',
 'GPU zero knowledge prover sumcheck release October 2026',
 'site:eprint.iacr.org/2026 October GKR memory sumcheck GPU',
 'site:github.com stwo releases October 2026 v2',
 'Hobbit space efficient zkSNARK github Pappas Papadopoulos code',
 'site:eprint.iacr.org Hobbit space efficient 2024']
(HERE/'search-log.json').write_text(json.dumps(dict(date='2026-10-20',native_live=True,queries=queries,
 inspected_urls=[u for r in records for u in [r['url']]+r['additional_urls']],
 blockers=['Hobbit ePrint PDF Internal Error; publisher PDF accessible.',
 'proving LICENSE Internal Error; root rendered license text accessible.',
 'companion repository LICENSE Cache miss.',
 'SP1 release API Internal Error.',
 'Release commit click rejected invalid arguments; full direct commit URL succeeded.',
 'Repository latest commit/update dates not rendered; do not substitute crawl dates.'],
 no_external_code_execution=True),indent=2)+'\n')
print(json.dumps({'before':len(old),'added':len(records),'after':len(old)+len(records)}))
