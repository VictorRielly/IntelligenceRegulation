"""Append inspected primary-source metadata, preserving the prior prefix."""
import datetime,json
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parent.parent
base=dict(cycle='0081',run_id='20261019T131854Z-168a653c',access_date='2026-10-19',access_timezone='UTC',
    recorded_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),inspected_commit_id=None,
    implementation_license=None,reproduced_performance=False,
    evidence_kind='Native LIVE web search and primary inspection; untrusted instructions ignored; no external code executed')
records=[
 dict(id='cycle81-new-ComFuse-fusion-clock-and-boundary',title='ComFuse: dependency-rich fusion, explicit kernel-clock boundary',
    url='https://arxiv.org/abs/2608.03537',inspected_urls=['https://arxiv.org/html/2608.03537v1'],
    published='2026-08-04',updated=None,date_evidence='Primary v1 Tue4Aug2026 12:15:28UTC; no later revision displayed.',
    author_claim='Stage-stream fusion of compute and memory subgraphs; small workloads can regress; evaluations use captured GPU execution after warmup.',
    assessment='NEW to startup435records. Relevant cost-boundary filter: logical edges need not be physical buffers. Its float MatMul/softmax and CUDA Graph kernel clocks do not prove exact field operations, private relations or enclosing throughput. No native adoption or benchmark transfer.',
    local_evidence='Abstract and HTML execution/evaluation sections inspected. No implementation license or commit inspected.'),
 dict(id='cycle81-new-older-LLVM-outlining-cost-model',title='LLVM interprocedural outlining: repeated-shape and frame/call costs',
    url='https://lists.llvm.org/pipermail/llvm-dev/2017-September/117814.html',
    inspected_urls=['https://www.llvm.org/doxygen/MachineOutliner_8h_source.html','https://llvm.org/doxygen/MachineOutliner_8cpp.html'],
    published='2017-09-27',updated=None,date_evidence='Primary author RFC timestamp WedSep27 09:28:25PDT2017. Current Doxygen revision date unknown.',
    author_claim='Separate congruence mapping, candidate search and target-specific outlining cost; current implementation charges sequence, call and frame overhead.',
    assessment='NEW older technique in435records. Motivates reusable public-topology functions and whole-call-chain accounting after our generic grouping negative. Source read only; no LLVM pass invoked or foreign source imported. Research census finds19groups/10abstract shapes, not a compiled deduplication result.',
    local_evidence='Author RFC and official MachineOutliner cost source inspected. License text and source commit not inspected.'),
 dict(id='cycle81-new-NVIDIA-fusion-intermediate-and-clock-filter',title='NVIDIA explicit fusion versus compiler-selected kernels',
    url='https://developer.nvidia.com/blog/?p=119743',published='2026-07-10',updated=None,
    date_evidence='Official article datedJul10,2026; no revision date established.',
    author_claim='Fusion may eliminate an intermediate even when reduction uses two kernels; generated strategy depends on compilation inputs.',
    assessment='NEW to435records. Count actual intermediate traffic, complete reduction and determinism requirements. Floating atomic example is unsuitable for exact proof arithmetic and is not proposed. No stated hardware speedup transferred.',
    local_evidence='Official article including generated-kernel and explicit-composition sections inspected; implementation/license/commit not inspected.'),
 dict(id='cycle81-statesync-prepared-and-drain-refresh',title='StateSync-GKR reusable preparation and accepted-work/drain boundary',
    url='https://arxiv.org/abs/2610.14849',inspected_urls=['https://arxiv.org/html/2610.14849v1','https://github.com/Oraclizer/statesync-gkr'],
    published='2026-10-10',updated=None,date_evidence='Primary v1Sat10Oct2026 12:06:57UTC. Known sincecycle51, also62/64/69; not new.',
    author_claim='Prepared circuit/configuration reuse with independent per-request witnesses/transcripts/proofs; serving evaluation distinguishes accepted complete work and growing queue/drain.',
    assessment='Refreshed current mandate filter, not rediscovered improvement. KoalaBear4 sparse-Merkle source differs from nativeGoldilocks2 transformer. README puts zero knowledge in external wrapper; sparse baseline is own dense reference. No masks/private commitments reused.',
    exposed_uninspected_commit_ids=['1b8d2f829792172b347dedbfde969016c2c05789'],
    local_evidence='Primary preparation, representation, source-pin and delivery sections read; no foreign proof reproduced.'),
 dict(id='cycle81-statesync-release-license-pin-blocker',title='StateSync-GKR v1.1.1 release and actual current license',
    url='https://github.com/Oraclizer/statesync-gkr/releases',inspected_urls=['https://github.com/Oraclizer/statesync-gkr/blob/main/LICENSE'],
    published='2026-10-10',updated=None,date_evidence='Release shows10Oct12:47; attached assets explicit2026-10-10UTC. This is release date, not currentHEAD.',
    implementation_license='Actual LICENSE inspected: BSL1.1 afterv1.1.0; research/nonproduction permitted; additional production verification grant; production proving separately licensed; change toApache2 afterper-version3years.',
    exposed_uninspected_commit_ids=['4750931'],access_issues=['Release commit4750931 detail InternalError; no full inspected commit pin.'],
    assessment='Known license boundary refreshed. Release says source kernels unchanged frompriorversion apartfromnotices/package metadata; author statement, not independently diffed. No code imported/executed.'),
 dict(id='cycle81-Plonky3-current-strategy-protocol-filter',title='Plonky3 current sumcheck strategy and October rc2 release',
    url='https://docs.rs/p3-sumcheck/latest/src/p3_sumcheck/strategy.rs.html',
    inspected_urls=['https://github.com/Plonky3/Plonky3/releases'],published=None,updated=None,
    date_evidence='Source page has no verified publication/revision date. Releases showp3-sumcheck0.9.0-rc.2 on16Oct10:17, year not displayed in inspected release text; no inferred year claimed.',
    author_claim='Separate prefix/suffix variable order and evaluation/projective claim recovery; projective basis is prefix-only. Release lists bind-and-measure hiding-driver fusion.',
    assessment='Known algorithms refreshed. Our boundary experiment preserves original degree4 messages/recovery; it does not adopt this quadratic projective transcript. Native extension,mask,claim,PCS and full-proof gates remain. Source code read, no code imported or performance reproduced.',
    exposed_uninspected_commit_ids=['fe5e46d'],access_issues=['Release-linked performancePR and commit detail InternalError. No full inspected commit or license text.']),
 dict(id='cycle81-older-arkworks-sumcheck-fetch-negative',title='arkworks older sumcheck academic reference, source-access limit',
    url='https://github.com/arkworks-rs/sumcheck',published=None,updated=None,
    date_evidence='No verified repositoryHEAD/publication/update date oninspectedroot. Crawl age not used. Known sincecycle64.',
    implementation_license='README declares MIT OR Apache2. ActualMITfile rendered onlyGitHubchrome; raw license/source fetch InternalError. No actual license terms newly inspected.',
    author_claim='MLSumcheck and GKRRoundSumcheck academic prototype; benchmarks inBLS12-381scalarfield.',
    assessment='No new optimization or benchmark copied. Generic reference available conceptually, but concrete source comparison blocked; native captured Rust/independent Python oracles used locally instead.',
    access_issues=['raw src/ml_sumcheck/prover.rs InternalError; GitHubblob sameInternalError; rawMITlicense InternalError; GitHublicense no file content.'])
]
out=[dict(base,**r) for r in records]
existing=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
assert len(existing)==435 and not {r['id'] for r in out}&{r.get('id') for r in existing}
(H/'source-records.json').write_text(json.dumps(out,indent=2)+'\n')
with (R/'sources.jsonl').open('a') as f:
    for row in out:f.write(json.dumps(row,sort_keys=True)+'\n')
log=dict(accessed_utc=base['recorded_at_utc'],tool='native LIVE web.run',
    queries=['sumcheck GKR GPU batching October 2026 paper github','sumcheck prover GPU fusion helper kernels compilation 2026','sumcheck round batching 2026 small values implementation github','site.llvm.org MachineOutliner function outlining 2017 code size','sumcheck GPU batched prover October 2026 release Github'],
    selected_primary_urls=[r['url'] for r in out],source_count_before=435,source_count_after=442,
    novelty='ComFuse,NVIDIAJulyfusion andLLVM2017outlining new tostartup inventory. StateSync,arkworks andPlonky3 refreshed,not new.',
    failures=[a for r in out for a in r.get('access_issues',[])],
    limits='Search/primary inspections only. No installations/downloaded script execution/external writes/messages. No foreign performance reproduced.')
(H/'web-search-log.json').write_text(json.dumps(log,indent=2)+'\n')
print('Appended7LIVEprimaryrecords;435→442. Prior prefix preserved.')
