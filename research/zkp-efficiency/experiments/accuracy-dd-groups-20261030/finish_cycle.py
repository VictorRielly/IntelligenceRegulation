"""Write research-only cycle0171 metadata and durable reports."""
from pathlib import Path
import datetime,hashlib,json,re

E=Path(__file__).resolve().parent
ROOT=E.parents[1]
RUN='20261030T194123Z-776cb104'
NOW=datetime.datetime.now(datetime.timezone.utc).isoformat()
prior=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines() if x.strip()]
records=[]
def source(title,url,pub,upd,date,claim,assessment,issues=None,license=None,urls=None):
    records.append(dict(id=f'cycle0171-source-{len(records)+1}',cycle='0171',run_id=RUN,title=title,url=url,
        access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=NOW,publication_date=pub,verified_update_date=upd,
        date_evidence=date,author_claim=claim,assessment=assessment,implementation_license=license,inspected_commit_id=None,
        inspected_urls=urls or [url],access_issues=issues or [],prior_exact_url_records=sum(x.get('url')==url for x in prior),
        evidence_kind='Native LIVE tools.web__run search/open/find/click; untrusted web instructions ignored',
        external_execution=False,reproduced_performance=False))

source('NEW older ideal-cache transpose/FFT hierarchy screen',
 'https://www.fftw.org/~athena/abstracts/abstract12.html','1999-10','2019-09-16',
 'Author page identifies FOCS99 Oct17-18 conference interval, not exact publication day; page itself last updated Sep16,2019.',
 'Cache-oblivious transpose/FFT achieve ideal-cache bounds under stated tall-cache assumptions.',
 'New URL/method assessment after1150 records. Native4096element two-pass shared tiles and fused gather already avoid materialization. Ideal-cache bounds are not GPU sector/occupancy or native NTT time. H106queued for additional-traffic census only.',
 ['Full-text link unsupported application/octet-stream FrigoLePr99.ps.gz; first click used invalid ref and was corrected.'],
 urls=['https://www.fftw.org/~athena/abstracts/abstract12.html','https://www.fftw.org/~athena/papers/FrigoLePr99.ps.gz'])
source('NEW older shape-only FFT planner/setup-versus-execution treatment',
 'https://fftw.org/fftw-paper-ieee.pdf','2005',None,
 'Author preprint footer identifies ProcIEEE93(2)216-231,2005. Exact publication day and PDF update unverified.',
 'Planner takes array shape/layout without input data, recursively selects plans through timing, and pays separate planning cost.',
 'SectionsI/II newly inspected. Public-dimension planning lead, not copying floating complex DFT code into Goldilocks NTT. Charge plan search/startup,transpose buffers,launch/occupancy and transfers. No software code/license inspected.',
 urls=['https://fftw.org/fftw-paper-ieee.pdf','https://www.fftw.org/'])
source('REFRESH equality-factor cost and scope','https://eprint.iacr.org/2024/1210','2024-07-27',None,
 'Primary history receivedJul27/approvedJul29,2024; approval is not revision.',
 'Reduce equality-factor prover multiplication count for eq(w,x) times products of multilinears.',
 'Author percentage is not native masked18-table DD or complete8B GPU timing. Local algebra/counts independently authored; no implementation adopted.')
source('REFRESH Efficient Sumcheck implementation and unreleased wire boundary',
 'https://github.com/compsec-epfl/efficient-sumcheck',None,None,
 'Current canonical rewrite explicitly Unreleased; stable0.0.2 changelog2026-02-11 is not current repo update date.',
 'EqFactoredProver/MSB variants; unreleased rewrite uses EvalsInfty,d values per round and changed transcript API.',
 'Native sends degree+1 ordered samples and retains original verifier/extension oracle; wire format cannot be imported. README/changelog only, no foreign code executed.',
 ['LICENSE-MIT Cache miss; no commit body inspected.'],'Apache2/MIT repository labels only; full license body unavailable',
 ['https://github.com/compsec-epfl/efficient-sumcheck','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/CHANGELOG.md','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/LICENSE-MIT'])
source('REFRESH October26 StateSync-GKR complete-result serving boundary','https://arxiv.org/abs/2610.14849','2026-10-10','2026-10-26',
 'Primary arXiv v1Oct10 12:06:57,v2Oct26 07:25:00UTC.',
 'Separate prepared arithmetic and bounded request queue/reply paths with complete accepted proofs.',
 'CPU sparse-Merkle workloads and different privacy wrapper do not establish private8B GPU throughput. Retain drain and independent verification.')
source('REFRESH October Longfellow composition field/masking scope',
 'https://datatracker.ietf.org/doc/draft-irtf-cfrg-longfellow/','2026-10-19','2026-10-22',
 'Draft00 body datedOct19; datatracker explicitly last updatedOct22,2026. Work in progress,no formal IETF standing.',
 'Deferred verification of one-time-pad-encrypted sumcheck plus Ligero; published profiles p256/GF2^128.',
 'Prior Eq-order/fresh-pad screen retained. Sections5/6 show distinct commitment/composition/field construction, not drop-in GoldilocksFp2 grouping. No randomness reuse/privacy transfer.',
 ['Mailarchive announcement Cache miss; canonical datatracker accessible.'],
 'Specification legal notice only; no standalone implementation adopted')
source('REFRESH Sparrow architecture; full-text access remains limited',
 'https://eprint.iacr.org/2024/1631','2024-10-11',None,
 'Primary receivedOct11/approvedOct14,2024; ACM publication separatelyDec9,2024. Approval not revision.',
 'Streaming sumcheck/data-parallel GKR reduce memory; search-indexed primary section3.1 mentions streaming oracles and a buffer.',
 'Known abstract screen. Search snippet available but fullPDF403 and repo Cache miss; no new detailed theorem/algorithm/license assessment or port.',
 ['PDF403Forbidden','Author repo Cache miss'],urls=['https://eprint.iacr.org/2024/1631','https://eprint.iacr.org/2024/1631.pdf','https://github.com/ChristodoulosPappas/Sparrow-Full-Version','https://doi.org/10.1145/3658644.3690318'])
source('REFRESH older GPU GKR residency/reduction boundary','https://arxiv.org/abs/1202.1350','2012-02-07','2012-02-22',
 'Primary arXiv v1Feb7 04:42:49,v3Feb22 04:15:37UTC,2012.',
 'Gate-independent sum contributions parallelize with reductions; author reports older GPU speedups.',
 'Already assessedcycle0107; no rediscovery of residency. Full18table relation,original field/transcript/private PCS remain required; no oldGPUratio transferred.',
 urls=['https://arxiv.org/abs/1202.1350','https://www.usenix.org/system/files/conference/hotcloud12/hotcloud12-final8.pdf'])

assert len(prior)==1150 and not any(x.get('run_id')==RUN for x in prior)
(E/'sources-cycle.json').write_text(json.dumps(records,indent=2)+'\n')
with (ROOT/'sources.jsonl').open('a') as out:
    for x in records:out.write(json.dumps(x,sort_keys=True)+'\n')

hyp=json.loads((E.parent/'dd-group-scaffold-cost-20261030/hypotheses.json').read_text())
assert len(hyp)==105
h=next(x for x in hyp if x['rank']==103)
h['cycle0171_refinement']=dict(
 selected_path='argument_accuracy.rs::szc_dd after non-Legacy dispatch',
 baseline='Host first round5samples,subsequent generic4. Unpadded18tables/14private,6lookups/3helpers,3Rs limbs,derived score17..20.',
 eliminated_work='Reduced equality-weighted bracket samples and one cur-table interpolation step; all original18folds/finals retained.',
 added_costs='All scalar Eq/prefix/split/inverse/recovery/completion/group-claim arithmetic counted. Setup clones/Arc/dispatch/parallel reduction/cache/enclosing time unknown.',
 exactness='48arbitrary synthetic fixtures:840roundvalues/864orderedfinals per arm vs independent original-cube expanded Fp2 equations;96literal count matches;10controls reexecuted. No native/masked/extension/PCS/privacy validation.',
 counts='n19/span12 469514108->334407627 expanded baseproducts(-28.7758%); allzero fallback381323556(-18.7834%). n7 nonzero -0.527%,allfallback +6.780%. Counts,not timing.',
 patch='Uncompiled/unapplied accuracy_dd_groups.uncompiled.diff; original verifier/extension poly byte-identical; explicit unpadded guard and generic fallback.',
 ceiling='N/(T-C+A) unknown without exclusive native critical clocks/full workloads.',
 falsification='Any table/lookup/host/degree/fold/final/masked-byte/RNG/transcript/refusal/PCS/privacy mismatch; absent material selected-path incidence; A>=C.',
 next='Owner release-mode native parity/exclusive clocks; local extension/masker boundary accounting.')
hyp.append(dict(rank=106,priority=5,
 title='NEW older recursive locality/public-shape NTT plan screen; additional traffic unestablished',
 baseline='Pinned CUDA4096element shared blocks already use two NTT passes,bit-reversed gather load and fused sampled-column output.',
 eliminated_work='Only additional critical sector/cache/cross-stage traffic beyond existing eliminations; not established.',
 added_costs='Recursive transpositions/buffers,twiddle/index changes,plan search,launch/occupancy and transfers.',
 prerequisites='Public shape/stride-only plan; canonical field/permutation/twiddle/query/output mapping; owner device/exclusive phase evidence.',
 integration_cost='Potentially large CUDA redesign; no foreign implementation adopted.',
 exactness='Literature/source screen only; bounded CPU NTT/traffic differential is future work.',
 privacy_soundness='No private data in plan/timing choices; no field migration or mask/pad/opening reuse.',
 compatibility='hashline/src/gpu/kernels.cu k_ntt_p1/ntt_p2_body/ntt_p2_gather_body; ideal-cache bounds are not GPU sector bounds.',
 end_to_end_ceiling='Unknown; existing two-pass/fused path means no free pass deletion. Need N/(T-C+A).',
 falsification='No additional critical traffic,canonical mapping mismatch or plan/transpose/launch cost>=saving.',
 disposition='Queued below actual DD native validation and whole-prover measurements.'))
(E/'hypotheses.json').write_text(json.dumps(hyp,indent=2)+'\n')
(E/'ranking-current.json').write_text(json.dumps(dict(top3=[1,2,3],conditional_priority4=103,new_priority5=106,total=106,
 prior_records_preserved=105,refinement='H103current18table exact algebra only; no native speed'),indent=2)+'\n')
rot=json.loads((E.parent/'dd-group-scaffold-cost-20261030/rotation-queue.json').read_text())
updates={
 'sumcheck/GKR':'Current accuracy-DD48fixture algebra/counts PASS; owner native masked/transcript/refusal/PCS and exclusive clocks NEXT.',
 'lookup arguments and softmax':'Six ordered lookups/three helpers and three Rs limbs checked in projection; native bindings/privacy owed.',
 'quantization/arithmetic':'Source range derived17..20 tested; arbitrary synthetic equations,not trained fidelity acceptance.',
 'memory traffic':'H106new older cache-oblivious/public-shape planning screen; existing two-pass/fused gather overlap prevents free pass deletion. Next rotation if native clocks justify.'}
for x in rot:
    if x['topic'] in updates:x['status']=updates[x['topic']]
(E/'rotation-queue.json').write_text(json.dumps(rot,indent=2)+'\n')
(E/'orchestration-note.json').write_text(json.dumps(dict(issue='One JS orchestration call failed parsing before execution; no command or writes ran.',impact='No experiment data affected; split into a standalone reviewed Python metadata writer.'),indent=2)+'\n')
print(json.dumps(dict(sources_before=len(prior),sources_after=len(prior)+len(records),hypotheses=len(hyp),checkpoint=NOW)))
