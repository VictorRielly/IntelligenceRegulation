"""Research-only durable checkpoint. No production/runtime writes."""
from pathlib import Path
import datetime,hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RUN='20261029T075649Z-ff4ec0d7'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((HERE/'result.json').read_text())
audit=json.loads((HERE/'audit-result.json').read_text())
assert result['status']==audit['status']=='PASS'
hyp=json.loads((HERE/'startup/prior__hypotheses.json').read_text())
for h in hyp:
 if h['rank']==1:
  h['prerequisites']+=' Cycle0138 reread: owner R13 accepted soundness at twelve profiles; real Shieldstral registration underway. The 8B T512 soundness count below95 is still open in owner status. No complete private8B GPU rate or amendment of this research target.'
 if h['rank']==53:
  h.update(title='REFINED TESTED all-slot exact public mask-tail weights; one-entry versus two-entry tradeoff',
   baseline='Pinned baseline four-limb/full-byte norm, sigma3/P2 T128 metadata:174 mask pairs across23 slots,4,871,844 Eq-constructor Fp2 products per block. Native define not executed; no R13 LOW/h24 calibration count claimed.',
   eliminated_work='One-entry:141 Eq/reversed-point builds and3,880,166 Eq products;2-entry:145 builds and4,011,230 products. No private read/dot,mask,commitment,PCS or complete proof work removed in production.',
   added_costs='One retained262144B public Eq vector plus pointcopy/exactcomparison/dispatch; two-entry up to524288B. Extending its lifetime through extension work changes peak. Actual allocation,compiler,parallel and peak/time costs unknown.',
   prerequisites='Owner native baseline/1-entry/2-entry A/B with exclusive Eq/dot/extension/enclosing clocks,actual admitted R13 catalog and all native golden/refusal/RNG/transcript/masking/PCS/privacy/independent receipt gates under current locks.',
   integration_cost='Small uncompiled/unapplied research Rust adapter; broadens selection to n_priv>1. Metadata/source audit does not replace native define/refusal execution.',
   exactness='Actual ordered Fp2 tail including length; c0/cm/width/pair and private rows remain per site. Bilinear family and later zero extensions retained.',
   privacy_soundness='Current-slot public weights only; no mask/value/result/challenge/opening/commitment reuse across proofs. Owner privacy acceptance remains owed.',
   compatibility='Native argument.rs::mask_eval/run_slot. All23 slots plus optional24th DD modeled; single-site fallback retained.',
   end_to_end_ceiling='Unknown target ceiling N/(T-Cremoved+Aadded). Historical R4 free whole-extension deletion only~1.109x GPU-assisted prove_run; candidate removes a subset. No R13/8B/high-endGPU transfer.',
   falsification='Any metadata/value/tail/c0/order/extension/refusal/RNG/transcript/PCS/receipt/privacy mismatch,or no enclosing gain/fit.')
 if h['rank']==55:
  h['added_costs']+=' Cycle0138 source-derived T128 role count:2,436,096 potential paired3 product replacements per baseline block,all4,872,192 private base-word reads remain. This is not an instruction/time fraction; patch here retains original dot arithmetic.'
 if h['rank']==56:
  h['prerequisites']+=' Cycle0138 separately screens Sept5 arXiv2609.06022; univariate rational coefficient preprocessing does not directly replace fresh multivariate masks. The landing/PDF visible details differ; no theorem or author timing reproduced.'
hyp.append({'rank':57,'title':'NEW count-only shared public component sums for paired3 dots after exact-tail incidence',
 'baseline':'Prior paired3 computes a+b once per coefficient per site. Baseline T128 catalog has2,436,096 such sums.',
 'eliminated_work':'If attached to one-entry fresh public weights,public sums count495,872,removing1,940,224 repeat additions per block. Count-only; not implemented or differential-tested.',
 'added_costs':'Up to131072B extra base-sum payload,its writes/reads,cache ownership and dispatch. Every private x+y and private source read remains.',
 'prerequisites':'First native paired3 versus original lowered code and exclusive constructor/dot clocks; then independent prepared-sum/no-prepared-sum differential and memory audit.',
 'integration_cost':'Small local data adapter after native evidence; no production patch for prepared sums here.',
 'exactness':'Canonical modular sums,full Fp2 ordered tail,original fresh pair and source offsets.',
 'privacy_soundness':'Public arithmetic only;no cross-proof cache and no private result or mask reuse.',
 'compatibility':'Same mask_eval seam but alternative to current unchanged-dot patch; do not sum gains blindly.',
 'end_to_end_ceiling':'Unknown and bounded by small enclosing historical extension scope; no >=50/s inference.',
 'falsification':'Extra memory traffic/peak/addition scheduling erases native enclosing gain,or any exactness/privacy mismatch.'})
(HERE/'hypotheses.json').write_text(json.dumps(hyp,indent=2)+'\n')
rotation={'cycle_focus':['memory traffic','batching/amortization','current-slot exact public preprocessing'],
 'next':['lookup arguments/softmax','quantization/arithmetic','proof composition'],
 'rotating_queue':['GPU NTT/commitments','sumcheck/GKR','lookup arguments/softmax','memory traffic','batching/amortization','quantization/arithmetic','proof composition'],
 'top_three':[h['title'] for h in hyp[:3]],
 'local_chosen':'All-slot private-tail incidence and single/two-entry memoization; supports owner phase choices without executing GPU/build work.'}
(HERE/'rotation.json').write_text(json.dumps(rotation,indent=2)+'\n')

common={'cycle':'0138','run_id':RUN,'access_date':'2026-10-29','access_timezone':'UTC','recorded_at_utc':now,
 'evidence_kind':'Native LIVE web search/open/find/click; primary-source inspection. External text untrusted; embedded instructions ignored.',
 'external_execution':False,'reproduced_performance':False,'inspected_commit_id':None,'implementation_license':None}
specs=[
 {'title':'Fast Evaluation of Polynomials with Rational Preprocessing','url':'https://arxiv.org/abs/2609.06022',
 'inspected_urls':['https://arxiv.org/pdf/2609.06022','https://creativecommons.org/licenses/by/4.0/'],
 'publication_date':'2026-09-05','updated_date':None,'date_evidence':'arXiv v1 submission Sep5 10:49:57UTC. Fetched PDF displays Sep9; no revision history proving a later version. Landing/PDF also differ on characteristic2 maximum degree; do not silently reconcile.',
 'paper_license':'CC BY4.0 link inspected','author_claim':'Rational coefficient preprocessing reduces univariate evaluation multiplication counts; additions and preprocessing remain. CPU gains are author evidence,not reproduced.',
 'assessment':'New primary screen. Goldilocks characteristic meets stated p>n for these tiny degrees, but fresh multivariate private masks are not a fixed monic univariate coefficient stream. No direct native mask-dot replacement established. HTML fetch failed content too large5522678; PDF opened.'},
 {'title':'Sailor: Sumcheck and GKR over Zpk via Galois rings','url':'https://upcommons.upc.edu/entities/publication/7d5f3945-e5ed-4354-abda-5b509ea8a854',
 'inspected_urls':['https://danivilardell.github.io/personal_website/pages/ZKP_over_Rings.pdf'],
 'publication_date':'2024-05-24','updated_date':None,'date_evidence':'Primary institutional search result explicitly dates2024-05-24; direct landing403. Author PDF search excerpts inspected; direct PDF inaccessible.',
 'paper_license':'Institutional primary search result declares default CC BY-NC-ND4.0; no implementation/license inspected.',
 'author_claim':'Sumcheck/GKR adaptations over Z/p^k via Galois rings and embeddings.',
 'assessment':'Newly assessed older lead. Field-to-ring migration affects binding/PCS/soundness and exact refusal domains; not a drop-in Goldilocks2 arithmetic optimization. No implementation or theorem reproduced.'},
 {'title':'Plonky3 current release listing and borrowed-point equality kernel PR2305','url':'https://github.com/Plonky3/Plonky3/pull/2305',
 'inspected_urls':['https://github.com/Plonky3/Plonky3/releases','https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.8.0','https://github.com/Plonky3/Plonky3/blob/main/LICENSE-MIT'],
 'publication_date':'2026-09-22','updated_date':'2026-09-23','date_evidence':'Primary PR openingSep22/mergeSep23. Release search lists p3-sumcheck-v0.8.0 Sep23; direct tag fetchCachemiss,so no freshness beyond inspected list.',
 'implementation_license':'MIT body inspected at repository LICENSE-MIT; no code copied/executed.',
 'observed_uninspected_commit_ids':['cdb48a06c1a8fe0b5622ccadebceffc7bba2a1c6'],
 'author_claim':'Unified borrowed-point/packed Eq fill and one-product children; author/reviewer report field-specific gains and small extension-size regression.',
 'assessment':'Refresh of an already recorded cycle0036 lead. Current rowlog14 falls in a size where author tables report a regression; no gain transferred. Commit diff fetchCachemiss; full coordinate observed only,not inspected code pin. Native two-product constructor remains baseline here.'},
 {'title':'arkworks linear-time sumcheck and visible historical commit history','url':'https://github.com/arkworks-rs/sumcheck',
 'inspected_urls':['https://github.com/arkworks-rs/sumcheck/commits/master/','https://github.com/arkworks-rs/sumcheck/commit/d241e9b17f48989831534975eb8e43adc8ec71d3','https://github.com/arkworks-rs/sumcheck/releases','https://github.com/arkworks-rs/sumcheck/blob/master/LICENSE-MIT'],
 'publication_date':None,'updated_date':'2024-10-02','date_evidence':'Newest visible history entryOct2,2024; not evidence of currentHEAD freshness. Release listingv0.3.0 showsJun7 without year; year not inferred.',
 'inspected_commit_id':'d241e9b17f48989831534975eb8e43adc8ec71d3',
 'implementation_license':'Repository README declares MIT OR Apache2.0; LICENSE-MIT page showed chrome without body and raw fetchCachemiss. Full license text uninspected.',
 'observed_uninspected_commit_ids':['ea56f3ae759f57f074d4e9213d30c07de48fdd21','6b8889662665e26c554e2db3f324b83a7a480716'],
 'author_claim':'Academic linear-time product/GKR sumcheck; visible historical prover-state full-randomness correction and sum-loop optimization.',
 'assessment':'Only dependency hashbrown0.14→0.15 diff inspected at pinned commit. Prover-state/sum-loop commits fetchedCachemiss; do not claim inspection or security transfer. Generic CPU BLS12 code does not establish native private8BGPU speed.'},
 {'title':'Interactive Proofs for Batch Polynomial Evaluation','url':'https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITC.2026.3',
 'publication_date':'2026-08-12','updated_date':None,'date_evidence':'Primary DROPS publication date explicitlyAug12.',
 'paper_license':'CC BY4.0 primary metadata inspected','author_claim':'Linear verifier-time batch univariate evaluation protocols and a black-box multi-point-opening transformation.',
 'assessment':'Refresh of prior cycle0026 cost filter. Does not remove all original ordered private claims, mask pairs or native PCS binding. No implementation or speed reproduced.'},
 {'title':'Speeding Up Sum-Check Proving','url':'https://eprint.iacr.org/2025/1117',
 'publication_date':'2025-06-13','updated_date':'2025-06-17','date_evidence':'Primary received/revised history explicitly displayed.',
 'paper_license':'CC BY primary metadata','author_claim':'Small-value/equality-factor techniques for sumcheck.',
 'assessment':'Refresh. Later Fp2 mask/equality tails are general field values; no small-integer premise follows from a quantized witness. Current experiment preserves original dense Eq constructor and every private row read.'},
 {'title':'JoltBook EQ polynomial optimizations','url':'https://jolt.a16zcrypto.com/how/optimizations/eq.html',
 'publication_date':None,'updated_date':None,'date_evidence':'No verified publication/update timestamp on inspected primary book page.',
 'author_claim':'Split Eq factors and recover one endpoint with explicit zero-factor fallbacks.',
 'assessment':'Refreshed methodology. Main-round factoring is already assessed in prior cycles; this experiment only shares exact terminal public weights and tests zero/Boolean points. No Jolt performance/privacy claim reproduced.'},
]
records=[]
for i,s in enumerate(specs,1):records.append({**common,**s,'id':f'cycle0138-source-{i}'})
(HERE/'sources-cycle.json').write_text(json.dumps(records,indent=2)+'\n')
ledger=ROOT/'sources.jsonl';existing=ledger.read_text();old=[json.loads(l) for l in existing.splitlines() if l]
assert len(old)==909,'Do not overwrite concurrent source appends'
with ledger.open('a') as f:
 for x in records:f.write(json.dumps(x,sort_keys=True)+'\n')
blockers={'heavy_work':'User scope forbids GPU/heavy builds; none attempted or queued. No approval needed for remaining local work.',
 'fetch_failures':[
 {'url':'https://arxiv.org/html/2609.06022v1','reason':'400 content too large5522678; primary PDF opened instead'},
 {'url':'https://upcommons.upc.edu/entities/publication/7d5f3945-e5ed-4354-abda-5b509ea8a854','reason':'403 Forbidden; only primary search metadata inspected'},
 {'url':'https://danivilardell.github.io/personal_website/pages/ZKP_over_Rings.pdf','reason':'not accessible through web tool'},
 {'url':'https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.8.0','reason':'Cache miss'},
 {'url':'https://github.com/Plonky3/Plonky3/commit/cdb48a06c1a8fe0b5622ccadebceffc7bba2a1c6','reason':'Cache miss; coordinate observed not code-inspected'},
 {'url':'https://github.com/arkworks-rs/sumcheck/releases/tag/v0.3.0','reason':'Cache miss'},
 {'url':'https://github.com/arkworks-rs/sumcheck/commit/ea56f3ae759f57f074d4e9213d30c07de48fdd21','reason':'Cache miss'},
 {'url':'https://github.com/arkworks-rs/sumcheck/commit/6b8889662665e26c554e2db3f324b83a7a480716','reason':'Cache miss'},
 {'url':'https://raw.githubusercontent.com/arkworks-rs/sumcheck/d241e9b17f48989831534975eb8e43adc8ec71d3/LICENSE-MIT','reason':'Cache miss'},
 {'url':'https://raw.githubusercontent.com/arkworks-rs/sumcheck/d241e9b17f48989831534975eb8e43adc8ec71d3/src/ml_sumcheck/prover.rs','reason':'Cache miss'},
 {'url':'https://raw.githubusercontent.com/arkworks-rs/sumcheck/master/LICENSE-MIT','reason':'Cache miss'},
 {'url':'https://eprint.iacr.org/2026/2668','reason':'not accessible; previous-cycle date evidence not reverified'},
 {'url':'https://github.com/AbdelStark/tessera/issues/485','reason':'Cache miss; third-party lead not accepted as source evidence'},
 {'url':'https://github.com/AbdelStark/tessera/issues/487','reason':'Cache miss; third-party lead not accepted as source evidence'}]}
(HERE/'blockers.json').write_text(json.dumps(blockers,indent=2)+'\n')
account={'new_completed_verified_full_stack_proofs':0,'passes':0,'positions':0,'actual_model_context':None,
 'actual_accelerator':None,'device_count':0,'experiment_device':'one Intel CoreUltra9 185H CPU thread',
 'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,'verification_seconds':None,
 'startup_seconds':None,'initial_prefill_seconds':None,'startup_fraction':None,'steady_interval_seconds':None,
 'total_workload_seconds':None,'steady_state_proved_positions_per_second':None,'total_workload_proved_positions_per_second':None,
 'proof_latency_seconds':None,'proof_bytes':None,'long_context_prefill':False,'resident_model_series':False,'decode':False,
 'target':'Complete private8B >=50 proved tokens/s on RTX5090 or another named high-endGPU; larger workloads allowed; no mask/privacy weakening',
 'status':'unachieved; no new proof tokens counted'}
(HERE/'target-accounting.json').write_text(json.dumps(account,indent=2)+'\n')
clocktext='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context / accelerator: none. One Intel Core Ultra9 185H CPU thread
was used for research checks. Witness, proof, serialization, verification,
startup/initial-prefill duration and fraction, proof latency/bytes, steady-state
and total-workload rates: **unmeasured**. No long-context prefill, resident-model
proof series or decode ran. Larger workloads remain allowed; longer attention
can grow quadratically. Private8B >=50/s on RTX5090 or another named high-end
GPU remains unachieved.
'''
nexttext='''Owner next: exclusive Eq/dot/extension/enclosing clocks and actual R13
catalog census, then native baseline/one-entry/two-entry golden, refusal,
RNG/transcript/PCS/privacy and independently verified complete-workload gates
under current shared locks. Whole-prover GPU/verified resident1/2/4/8 remains
the first priority. Local next: lookup/softmax rotation, read cycle0121/0122
alias/PCS negatives, then inspect actual LOW/h24/DD public descriptor incidence
before any further shared U8-source preparation. No heavy job queued.
'''
progress=f'''# ZKP efficiency progress

Cycle0138 complete — `{RUN}`,2026-10-29 UTC.

**No native proving improvement measured.** The all-slot source-derived census
finds174 fresh private mask pairs per block in the pinned baseline T128
four-limb class. One-entry public equality weights reduce builds174→33 and
constructor products4,871,844→991,678, preserving all4,872,192 private word
reads. Two entries yield29 builds but up to524,288B retained public payload
instead of262,144B. These are counts, not physical traffic or runtime.

Synthetic model:22,307 checks/423 fixtures/35 negative controls PASS,
including6,270 site comparisons and6,270 extension terminals;2.818003s,
26,300KiB RSS. Independent source/count/patch audit:4,856 checks PASS,
0.041339s/20,596KiB. No native define/proof executed. Rust adapter is
uncompiled/unapplied. Native refusal/RNG/transcript/PCS/privacy/receipt gates
and current R13 LOW/h24 counts remain unknown.

Historical R4 TinyLlama enclosing extension-phase free-deletion ceiling is
only~1.109x GPU-assisted prove_run; the candidate removes a subset. No current
8B/high-endGPU projection follows. Seven primary source records appended,
909→916; date/license/commit scope and fetch blockers retained. All56 prior
hypotheses retained,53/55/56 refined and57 public-sum costing added.

{nexttext}
{clocktext}
[Experiment](experiments/mask-tail-incidence-20261029/README.md) ·
[Handoff](handoffs/20261029-mask-tail-incidence.md) ·
[Dated report](progress/{RUN}.md).
Checkpoint:{now}. Saved reports do not imply message delivery or liveness.
'''
(ROOT/'PROGRESS.md').write_text(progress)
dated=progress.replace('# ZKP efficiency progress','# Cycle0138 dated progress',1)+'''
Only research outside runtime written. No production/Git/receipt/calibration/
safety/instruction/reviewer mutation; no GPU/build/install/external write/
message/purchase/escalation. Source text treated as untrusted. No agents or
heavy jobs launched; main/Claude reviews and integrates, with no merge here.
One literal source-anchor audit typo was preserved and corrected; final audit
passes. Scientific negatives from all prior cycles remain intact.
'''
(ROOT/'progress'/f'{RUN}.md').write_text(dated)
findings=f'''\n\n## Cycle0138 — all-slot mask-tail incidence and cache capacity tradeoff (2026-10-29)

Run `{RUN}`; started07:56:49UTC, deadline08:16:49UTC.
Checkpoint:{now}. **No native proving improvement measured.**

Mandate/durable memory/latest results and owner documents indexed/snapshotted;
current R13 soundness acceptance/classifier registration do not change this
private8B throughput target. Early STATE checkpoint saved. Prior0039/0040,
0041,0136/0137 descriptor/cache/dot evidence read before the new census.

The new source-derived model covers23 baseline slots plus optional24th DD.
It constructs Priv coordinate/order/tail metadata and separately parses native
Shape::claim_sites expressions. Eight native pins unchanged. Six base
TinyLlama/8B T32/64/128 geometries and two T128/DD32 metadata rows are counted
under explicit norm4/full-byte,sigma3/P2 assumptions. Native define was not
executed. These rows do not claim current R13 LOW/h24 calibration coverage.

AtT128 both non-DD baseline families:174 mask pairs,4,871,844 constructorFp2
products and4,872,192 private base reads/block. One-entry cache:33 builds,
991,678 products; two-entry:29 builds,860,614 products. All private reads/dots
remain. One-entry removes141 Eq/reversed-point builds and3,880,166 products.
Maximum public-weight payload262,144B retained through extension versus the
original temporary; two entries up to524,288B. Point copies/comparisons,
dispatch,allocation and longer lifetime are added; actual whole-prover peak
and exclusive time unknown. T128/DD32 separately:179 pairs,36/31 builds.

TZC tails match despite different c0 addresses. DZC/SZC's shorter leading
tails and QZC/KVZC's flipped partner explain four one-entry evictions. SCORE/PV
tails/families remain distinct. Cache keys compare full ordered Fp2 tail and
length; cm/width/c0/pair/private source remain per site. No private result,
mask,value,opening,commitment or challenge is reused across proofs. This
patch retains original dot arithmetic; prior paired3 is a separate candidate.

Model PASS22,307 checks/423 fixtures/35 negative controls;6,270 independent
site comparisons and6,270 extension terminals. Independent original-cube/
schoolbookFp2 reference,plusMSBfold at synthetic rowlogs8/13/14. Scaled
fixtures coverallslots,DD,ln2/4/5,sigma2/3,P1/2,partial/fulltops,Boolean,
zero-first and generalFp2,offsets and unequal endpoint widths. Controls catch
source counts/tail/order/flip/width/c0/privatepair/result staleness and dropped
laterzeroextensions. These are synthetic algebra/metadata checks,not native
transcript/refusal/PCS/privacy or receipt tests. Ordered-value digests saved.

Probe2.818003s/26,300KiB RSS; audit4,856 checks/57anchor mutations,
0.041339s/20,596KiB. One pinned nice19 CoreUltra9 CPU worker,seed202610290138;
40sCPU/45salarm/50sparent/256MiBAS/96MiBestimate. Eightpins and in-memory
exactpatchreplay pass. Uncompiled/unapplied Rust patch selectsn_priv>1; single
sites retainoriginal. One literal audit anchor used wrong local variable
spelling; retainedfailurecorrectedfromsource,finalPASS. No scientific negative
was removed. Main/Claude reviews/integrates; no merge or heavy job queued.

HistoricalR4TinyLlamaT128/L22 hashes rechecked,not rerun/reverified. All506
extension rows15.938s/153.072sCPU and13.303s/135.809sRTX4070Laptop-assisted
prove_run,one16threadpass each. Free deletion of the entire phase gives
~1.116222x/~1.108591x proving-only counterfactuals from rounded timers. Cache
removes only a subset. No R13/8B/high-endGPU transfer. Target ceiling remains
N/(T-Cexclusive_removed+Aadded),unknown. Falsify on any value/order/tail/c0/
width/extension/support/refusal/RNG/transcript/PCS/receipt/privacy mismatch,
or no enclosing gain/fit. Raw count fraction is not a time fraction.

All56 prior hypotheses retained,53genericcache/55paired3incidence/56literature
refined;57added public-component-sum preparation(countonly). That follow-up
prices2,436,096→495,872 public additions with extra up to131,072B sum payload,
writes/reads/dispatch; unimplemented/untested,notstacked. Top3 unchanged:
owner wholeproverGPU/verifiedresident1/2/4/8,DD/fidelityscaling,exclusiveclocks.

Seven LIVE primary records appended909→916. Newly screened arXiv2609.06022
rationalpreprocessing andolderSailor2024 institutionalmetadata; refreshed
Plonky3Eq/release,arkworks,ITCbatch,2025sumcheck,JoltBook. Exactdates/licenses/
URLs andfetchfailures retained. Arkworks dependencycommitd241e9b17f48989831534975eb8e43adc8ec71d3
diff inspected; other observed commitcoordinates fetchedCachemiss,notcodepins.
Stalevisiblehistory is not currentHEADfreshness. SeptemberarXivlanding/PDF
visible details differ; no theorem/CPUauthorgain reproduced. Ringmigration
doesnotpreserve native field relation automatically. DirectTesseraissues
inaccessible;thirdpartyleadsnotacceptedasevidence. No foreign code executed.

{nexttext}
{clocktext}
HistoricalCPU8BT128/L32 single16threadpass,GPUoff carriedonly:total478.737s,
0.267370positions/s;prove_run393.785s includeswitness98.348s/blockload17.595s.
Sealing84.824s precedesprove_run;load27.151s/witness80.897s overlapinternally.
Receipt922711264B;verify42.709s+load13.681s. Isolatedserialization,
startupfraction/steadyslopeunknown;notrerun/reverified andnotnewlycounted.

[Experiment](../experiments/mask-tail-incidence-20261029/README.md) ·
[Handoff](../handoffs/20261029-mask-tail-incidence.md).
Onlyresearchoutsideruntimewritten;noproduction/Git/receipt/calibration/safety/
instruction/reviewerchanges,nobuild/GPU/install/externalwrites/messages/
purchases/escalation.Savedreportsarenotdeliveryorsupervisorlivenessevidence.
'''
with (ROOT/'FINDINGS.md').open('a') as f:f.write(findings)
state=f'''# ZKP efficiency explorer — durable state

Cycle0138 COMPLETE: `{RUN}`.
Started2026-10-29 07:56:49UTC; checkpoint{now}; deadline08:16:49UTC.
Next cycle no earlier than2026-10-29 08:56:49UTC.

No native proving gain. Source-derived all23/optional24DD Priv tail census
supports exact public-only current-slot cache. BaselineT128/fourlimb/fullbyte/
sigma3/P2:174pairs,Eqbuilds174→33one-entry/29two-entry,constructorproducts
4,871,844→991,678/860,614. All4,872,192 privatebasewordreads remain.
Source-derived metadata,not executednative define or R13LOW/h24 counts.
Eightcurrentpins unchanged. Actualcomplete clocks/peak unknown.

One-entry262144B Eqpayload retainedthroughextension,pluspointcopy/comparison/
dispatch;twoentries524288B. c0/cm/width/pairprivaterows remain per-site.
No privatevalue/result/mask/challenge/commitment/openingreuseacrossproofs.
RustpatchonlypublicEqprovider,n_priv>1fallback;uncompiled/unapplied.

Probe22,307checks/423fixtures/35controls,6270sitecomparisons+6270extension
terminalsPASS,2.818003s/26300KiB;audit4856checks/57anchorsPASS,
0.041339s/20596KiB. Onepinnednice19CoreUltra9worker,40sCPU/45alarm/50parent/
256MiBAS/96MiBestimate. Nonativerefusal/RNG/transcript/PCS/privacy/receiptgate.
Oneauditliteraltypo retained/corrected; priornegativespreserved.

HistoricalR4TinyLlamaT128/L22 extensionfree-deletionceilings~1.116222xCPU/
1.108591xRTX4070Laptop-assistedprove_run;cachedEqisasubset. Roundedtimers,
notrerun/reverified;noR13/8B/highendGPUtransfer.Targetceilingunknown.

All56priorhypotheses retained,53/55/56refined,57publicsums added(countonly).
Top3:wholeGPU/verifiedresident1/2/4/8,admittedDD/fidelityscaling,exclusive
phase/capacityclocks. SevenLIVEprimaryrecords appended909→916; source
licenses/dates/commitinspection/fetchfailuressaved. Newrationalpreprocessing
andolderSailorleads do notdirectlyreplacefreshmultivariatefieldmaskdots.
CurrentownerR13soundnessacceptance/classifierregistrationdoesnotamendtarget.

{nexttext}
Experiment:experiments/mask-tail-incidence-20261029/README.md.
Handoff:handoffs/20261029-mask-tail-incidence.md.
Datedreport:progress/{RUN}.md.

{clocktext}
HistoricalCPU8BT128/L32/one16threadpassGPUoffcarriedonly:total478.737s=
0.267370/s;prove_run393.785sincludeswitness98.348s/blockload17.595s;
sealing84.824s,internalload27.151s/witness80.897soverlap.Receipt922711264B;
verify42.709s+load13.681s.Notrerun/reverified;serialization/startupfraction/
steadyslopeunknown.Nohistoricaltokensnewlycounted.

PriorSTATEpreservedinstartup;FINDINGS/sourcesappend-only.Onlyresearchoutside
runtimewritten;noproduction/Git/receipt/calibration/safety/instruction/reviewer
edits,build/GPU/install/externalwrites/messages/purchases/escalation.
Savedreportsarenotdeliveryorsupervisorlivenessevidence.Main/Claudeintegrates.
'''
(ROOT/'STATE.md').write_text(state)
commands=[{'command':'python3 experiments/mask-tail-incidence-20261029/prepare_adapter.py','purpose':'Research source adapter generation; no native build'},
 {'command':'python3 experiments/mask-tail-incidence-20261029/run_bounded.py probe.py','seed':result['seed'],'execution':'probe-execution.json'},
 {'command':'python3 experiments/mask-tail-incidence-20261029/run_bounded.py audit.py','execution':'audit-execution.json'},
 {'command':'python3 experiments/mask-tail-incidence-20261029/checkpoint.py','purpose':'Research-only durable reporting'}]
(HERE/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
(HERE/'completion.json').write_text(json.dumps({'run_id':RUN,'status':'COMPLETE','checkpoint':now,'deadline':'2026-10-29T08:16:49Z','source_ledger_before':909,'source_ledger_after':916,'hypotheses':len(hyp),'new_full_stack_proofs':0},indent=2)+'\n')
print(json.dumps({'status':'checkpointed','time':now,'sources':len(records),'hypotheses':len(hyp),'findings_lines':len((ROOT/'FINDINGS.md').read_text().splitlines())}))
