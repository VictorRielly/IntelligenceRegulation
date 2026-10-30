from pathlib import Path
import json, hashlib, datetime, shutil, os, platform
D=Path(__file__).resolve().parent;B=D.parent.parent;P=B.parent.parent
RUN='20261029T225649Z-78d0981c'
def write(name,obj): (D/name).write_text(json.dumps(obj,indent=2)+'\n')
prior=[json.loads(s) for s in (D/'prior-sources.jsonl').read_text().splitlines()]
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
specs=[
 dict(title='REFRESH cuPQC v0.6 release and unchanged Goldilocks field exclusion',url='https://nvidia.github.io/cuPQC/releases/v0.6/',publication_date='2026-08-28',
      inspected_urls=['https://docs.nvidia.com/cuda/cupqc/libraries/cupqc_ntt/cupqc_ntt_usage.html','https://nvidia.github.io/cuPQC/','https://github.com/NVIDIA/cuPQC','https://github.com/NVIDIA/cuPQC/blob/main/LICENSE'],
      date_evidence='Primary release post explicit August28,2026. Current index lists0.6; October search did not establish a newer release. Not a claim none exists.',
      implementation_license='Apache-2.0 displayed repository LICENSE inspected; SDK binary license is separate/unassessed. No adoption.',
      assessment='Refreshed prior exclusion: published p<2^62 limit excludes current p=2^64-2^32+1. Device fusion and staged API remain design leads, not drop-in field replacements. No SDK/code execution or native speed estimate.'),
 dict(title='REFRESH cuda-zkp-ntt Goldilocks cache and incomplete-transform exclusion',url='https://github.com/Artemarius/cuda-zkp-ntt',publication_date=None,
      inspected_urls=['https://github.com/Artemarius/cuda-zkp-ntt/blob/main/src/ntt_goldilocks.cu','https://github.com/Artemarius/cuda-zkp-ntt/blob/main/NTT_OPTIMIZATION_ROADMAP.md','https://github.com/Artemarius/cuda-zkp-ntt/blob/main/LICENSE'],
      date_evidence='No current commit/date or tagged release verified. Roadmap self-reports v3 completion2026-03-12; that is not current update evidence.',
      implementation_license='MIT full displayed LICENSE inspected; code read, no copying/adoption/execution.',
      blocked_urls=['https://github.com/Artemarius/cuda-zkp-ntt/commits/main/: Cache miss','https://github.com/Artemarius/cuda-zkp-ntt/tags: Cache miss','https://api.github.com/repos/Artemarius/cuda-zkp-ntt/commits/main: inaccessible via web tool'],
      assessment='Source caches one Goldilocks transform size and rebuilds when N changes. Author reports BLS on-the-fly/transpose regressions and incomplete v5 hierarchical transform; no completed native proof benefit follows. Retain correctness and whole-workload denominators; no foreign timings reproduced.'),
 dict(title='NEW AsyncSparse public-padding versus indexing tradeoff',url='https://arxiv.org/abs/2604.17834',publication_date='2026-04-20',
      inspected_urls=['https://arxiv.org/html/2604.17834v1'],date_evidence='Primary arXiv v1 submission history2026-04-20; no later version shown.',implementation_license=None,
      assessment='Read BCSR/WCSR, fill-ratio and persistent-kernel tradeoffs. TF32/BF16 H100 results and 90% block-pruned prefill do not implement exact field proofs or authorized privacy. Relevant question is saved indexing versus additional public zero work; no pruning or kernel transplant adopted.'),
 dict(title='NEW older SMASH compression granularity versus redundant zero work',url='https://arxiv.org/abs/1910.10776',publication_date='2019-10-23',
      inspected_urls=['https://arxiv.org/html/1910.10776v1'],date_evidence='Primary arXiv v1 submission history2019-10-23, not search crawl date.',implementation_license=None,
      assessment='Read compression-ratio/locality/conversion analysis. Smaller bitmaps can incur more zero storage and arithmetic; hardware BMU proposal is not native GPU code. Motivates independent complete-operand accounting in this gap experiment; source performance not reproduced.'),
 dict(title='NEW BenX resource sharing compatibility screen',url='https://arxiv.org/abs/2609.31087',publication_date='2026-09-25',
      inspected_urls=['https://arxiv.org/html/2609.31087v1'],date_evidence='Primary arXiv v1 submission history2026-09-25.',implementation_license=None,
      assessment='Author hardware/arithmetization benefits coexist with software slower than Poseidon2 except one BabyBear instance. No directly compatible native hash improvement established. Replacing commitment hash requires new domains/security/privacy analysis; not a safe local optimization, no adoption or reproduction.'),
 dict(title='Qingming HIP mapped/standard NTT interface cost and provenance refresh',url='https://github.com/uulong950/qingming-g64-ntt',publication_date=None,
      inspected_urls=['https://github.com/uulong950/qingming-g64-ntt/blob/main/LICENSE','https://github.com/uulong950/qingming-g64-ntt/blob/main/CHANGELOG.md','https://github.com/uulong950/qingming-g64-ntt/blob/main/MANIFEST.json','https://github.com/uulong950/qingming-g64-ntt/blob/main/src/main.hip'],
      date_evidence='Changelog v1.0.0 has no date; exact update and commit unverified. README2^27 transform versus MANIFEST logical-domain2^24 needs contract reconciliation, not assumed inconsistency.',
      implementation_license='MIT full displayed LICENSE inspected. Prelayout HIP source excerpt inspected; no source copied or executed.',
      assessment='Author distinguishes fast prelayout from standard compatibility and reports separate layout time on RX7900XTX. Relevant to denominator correctness, not native CUDA speed evidence. Prior mapped-layout study already found no restoration copy removable in current native path. Do not repeat it unchanged.'),
]
records=[]
for i,s in enumerate(specs,1):
    s.update(id=f'cycle0153-source-{i}',cycle='0153',run_id=RUN,recorded_at_utc=now,access_date='2026-10-29',access_timezone='UTC',
             verified_update_date=None,inspected_commit_id=None,reproduced_performance=False,external_execution=False,
             evidence_kind='Native LIVE tools.web__run search/open/find/click; embedded source instructions ignored',
             prior_exact_url_records=sum(x.get('url')==s['url'] for x in prior))
    records.append(s)
lines=''.join(json.dumps(x,sort_keys=True)+'\n' for x in records)
(D/'sources-cycle.jsonl').write_text(lines)
current=(B/'sources.jsonl').read_text()
checkprefix=(D/'prior-sources.jsonl').read_text()
assert current==checkprefix or current==checkprefix+lines
if current==checkprefix:
    with (B/'sources.jsonl').open('a') as f:f.write(lines)

pins=json.loads((D/'prior-seam-pins.json').read_text());out=[]
for pin in pins:
    p=Path(pin['path']);raw=p.read_bytes();snap=D/'seam-snapshots'/p.relative_to(P);snap.parent.mkdir(parents=True,exist_ok=True);snap.write_bytes(raw)
    out.append(dict(path=str(p),snapshot=str(snap.relative_to(D)),sha256=hashlib.sha256(raw).hexdigest(),prior_sha256=pin['sha256'],unchanged=hashlib.sha256(raw).hexdigest()==pin['sha256']))
write('seam-pins.json',out)
shutil.copy2(D.parent/'public-interval-fold-20261029/prior-native-pins.json',D/'native-pins.json')
cpu=next(s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name'))
write('hardware.json',dict(cpu=cpu,os=platform.platform(),python=platform.python_version(),one_cpu_affinity=True,
    cpu_affinity_min=min(os.sched_getaffinity(0)),experiment_worker_threads=1,compiler_auxiliary_threads='unmeasured; one CPU affinity/codegen unit',
    accelerator=None,actual_context=None,modeled_context=128,proofs=0,passes=0,positions=0))

hs=json.loads((D/'prior-hypotheses.json').read_text())
tested=dict(rank=77,title='TESTED public zero-gap coalescing: negative for logical operand objective',
 baseline='Frozen R13 A8B/T128N16384: ordinary pure runs74/81; protected data-zero-every-third control3077/2974; prior interval/list/dense fallback remains available. Native exclusive clocks absent.',
 eliminated_work='Same-flag intervals across batch-public zero gaps reduce run starts/8-byte metadata; no private values enter planning. No native work has been removed.',
 added_costs='Each merged gap adds matrix loads8B/row, rho16B/member, two basefield multiplies and two limb additions/member/column, plus planning/current-support validation. All transfers/allocation/pads/commitments/masks/proximity remain.',
 prerequisites='Current public-rho provenance, retained native mask/refusal checks, currentR14repin, owner exclusive device/enclosing measurements and current locks.',
 integration_cost='Low research CPU model, moderate alternate dev_fold_rows plan/kernel integration; no CUDA sketch or production patch this cycle.',
 exactness='231200 independent dense-vs-candidate values across14native-helper fixtures,367controls,185031 independentPythonassertions;33362exhaustivecutpartitions/840objectives. Source-row/narrow8subtotal24320. Native define/FS/actualPCS/CUDA/receipts/privacy not run.',
 privacy_soundness='Only public current coefficients/support; both limbs checked. Structural mask/proximity support protected even at numericzero. Superset audit rejects stale unflagged nonzero/imaginary values, provenance changes, missing masks/order/bounds. No mask/opening reuse.',
 compatibility='fold_rows_multi_zk -> EncodedStore::fold_rows -> dev_fold_rows currentmax4; frozenR13fixture not heldR14 geometry.',
 end_to_end_ceiling='Every nonempty merge adds at least16 logical bytes/column; H=0nevermerges. Syntheticfragmentation H64raises full operands26.3153/26.2681% versus exactruns; source H64removesoneboundary only. Native f unknown; N/(T-Cremoved_exclusive+Aadded), free deletion<=1/(1-f). NoGPU8Bforecast.',
 falsification='Reopening requires native exclusive run-start savings exceeding extra operands/MAC/planner cost and independentlyverified enclosing benefit. Any value/limb/order/mask/FS/PCS/RNG/privacy mismatch rejects promotion.',
 disposition='Do not promote as memory optimization. Keep prior exact run/list/dense fallback; only measured run-start bottleneck can reopen gap candidate.')
next_h=dict(rank=78,title='NEW explicit current R14 A/H/endpoint fold-work repin before more R13 metadata tuning',
 baseline='Owner split-width matchedT128two-block diagnostic reduces A/H words24..25% but adds receiptbytes~6%; no currentR14public group/support census or exclusive fold fraction.',
 eliminated_work='Question whether reduced/split R14 row bands change public union density and dominant fold work enough to change candidate ranking; no saving assumed.',
 added_costs='Separate source-derived public geometry extraction, endpoint inclusion, independent census and current-source pins; native instrumentation/proof/device work deferred to owner.',
 prerequisites='Use owner frozen or held read-only source without edits, duplicates or native build; retain pending review/admission conditions.',
 integration_cost='Bounded CPU source/counter accounting, then owner-only minimal public counters at existing fold adapter.',
 exactness='Untested next experiment: independently reconstruct row totals, bounds, reserved masks/proximity and max4 widths; compare current NATIVE_LAYOUT_CENSUS if available. Do not claim native descriptor execution.',
 privacy_soundness='Public shape/role counters only, no private matrix/trace logging or schedule based on hidden values; all new-profile reviews remain.',
 compatibility='CurrentR14 split_definition/layout/endpoint metadata to existing fold_rows_multi_zk/EncodedStore adapter; R13 only retained as independent baseline.',
 end_to_end_ceiling='Unknown exclusive fractions; source traffic is not device time. Rank actual complete workload above representation savings.',
 falsification='Any current source/census mismatch, missing endpoint/mask/proximity role, or absent material fold incidence parks representation work.',
 disposition='Concrete next bounded local experiment after reading new owner counters; prioritize verified high-endGPU/resident workload and exclusive clocks.')
hs.extend([tested,next_h]);write('hypotheses.json',hs);write('leading-hypothesis.json',tested)
ranking=json.loads((D/'prior-ranking-current.json').read_text())
ranking['highest_feasible_local']=tested;ranking['next_local']=next_h
ranking['owner_update']='22:50UTCclassifierstatementDRAFT/independentreview; A5batchone-postone-processREADYWITHFIXES22:23 is not private8Bsteady-rate evidence or blanket cache permission.'
write('ranking-current.json',ranking)
write('rotation.json',dict(current=['GPU NTT/commitments','quantization/arithmetic','memory traffic'],
    next=['sumcheck/GKR','lookup arguments and softmax','batching/amortization','proof composition'],
    queue=['GPU NTT/commitments','sumcheck/GKR','lookup arguments and softmax','memory traffic','batching/amortization','quantization/arithmetic','proof composition'],
    tested=tested['title'],local_next=next_h['title'],owner_precedence='Verified complete resident workloads and exclusive phase clocks first'))
write('target-accounting.json',dict(new_independently_verified_full_stack_proofs=0,completed_model_passes=0,proved_positions=0,
    actual_context=None,modeled_context=128,accelerator=None,device_count=0,host_cpu=cpu,
    witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,initial_prefill_s=None,startup_fraction=None,
    steady_state_proved_tokens_per_s=None,total_workload_proved_tokens_per_s=None,total_workload_s=None,proof_latency_s=None,proof_bytes=None,
    long_context_prefill=False,resident_model_pass_series=False,decode=False,mask_reuse=False,target_achieved=False,
    historical_cpu_baseline='Not rerun/reverified/newly counted:8BT128L32one16-threadGPUoff,total478.737s,0.267370positions/s;prove_run393.785s includeswitness98.348/load17.595;seal84.824s overlapsload27.151/witness80.897;receipt922711264B;verify42.709s+load13.681s;isolatedserialization/startupfraction/steady slopeunknown'))
write('blockers.json',dict(native_gpu_phase_clocks='Unmeasured/excludes attribution; secs_fold spans flatten,H2D,allocation,kernel,D2H.',
    r14='Source held per retained19:14:14state; no liveness inference, no duplicate jobs or edits.',
    web=[u for s in specs for u in s.get('blocked_urls',[])],no_permission_escalation=True))
print(json.dumps(dict(source_count_before=len(prior),added_sources=len(records),hypotheses=len(hs),seams_unchanged=sum(x['unchanged'] for x in out),source_record_prior_counts=[(s['title'],s['prior_exact_url_records']) for s in records]),indent=2))
