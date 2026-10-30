import copy, datetime, hashlib, json, pathlib, subprocess
D=pathlib.Path(__file__).resolve().parent
R=D.parent.parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
run='20261030T064123Z-6637fd3d'
old=json.loads((D/'prior-hypotheses.json').read_text())
tested=copy.deepcopy(old[-1]);tested.update(rank=87,
 title='TESTED direct explicit-limb packing removes instrumented temporary allocations',
 baseline='Current root dev_fold_rows holds the GPU mutex, reserves k*rows*2 limbs and extends one newly allocated as_u64s_f2 temporary per rho, k=1..4. Baseline extracted verbatim; /usr/bin/rustc1.75.0 opt-level2, counted System allocator.',
 eliminated_work='Nonempty pack-stage allocation requests k+1 -> 1; cumulative requested bytes32*k*rows ->16*k*rows; requested packing peak16*rows*(k+1) ->16*k*rows. No GPU allocations, transfers, launches, arithmetic, sync or proof serialization changed. Logical temporary stores/copy removed, hardware memory traffic unmeasured.',
 added_costs='Direct scalar limb stores and existing push capacity checks. Destination staging length/capacity and original shape assertions retained. No new persistent cache, preflight reordering, ABI change or runtime dependency.',
 prerequisites='Owner native GPU/CPU byte gates plus actual current group census, exclusive packing and enclosing complete independently verified workload clocks. Optimized instrumented helper evidence is not production allocation/performance evidence.',
 integration_cost='Small review-only single-hunk direct-pack-review-only.patch in hashline/src/gpu/cuda.rs::dev_fold_rows. No production patch applied, no GPU/native build run.',
 exactness='168Rust fixtures,458160compared limbs,120 exact serial native-host-fold cases,11Rust negative controls.40 exported fixtures match4000Python serialization limbs and1600Python bigint fold-output limbs;49 overflow/capacity plans. Canonical and raw noncanonical representation-preservation cases are distinct; invalid field elements are not admitted by this test.',
 privacy_soundness='Explicit c0.0 then c1.0 preserving ordered supplied vectors. Fresh call-local buffer; no data-dependent dispatch, mask/pad/proximity/opening reuse or FS/RNG change. Three synthetic tail columns are stand-ins only. Pack-stage shape panics tested, not whole native refusal/initialization/poison/error/receipt/privacy behavior.',
 compatibility='Root field and extracted pack/host bodies pinned. Fp2 has no repr(C); no struct-byte cast. Candidate retains native unchecked shape multiplication; separate checked length oracle does not repair/admit native launch dimensions.',
 end_to_end_ceiling='N/(T-C_pack_exclusive+A_added); perfect removal of exclusive fraction f <=1/(1-f). f unknown. Historical A57 T128 grouping:72 ->15 host pack allocation requests,not a GPU/private8B rate.',
 falsification='Production optimizer/toolchain removes allocations already, exclusive packing negligible, direct stores slow more than removed copy/allocation, or any native byte/order/refusal/receipt/privacy mismatch.',
 disposition='Correctness and instrumented allocation candidate; no measured proving gain. Owner review only; park further packing/staging variations pending measured exclusive bottleneck.')
new=dict(rank=88,title='NEW mutex/timer boundary: can host packing placement reduce uncounted contention?',
 baseline='Source dev_fold_rows obtains gpu(), locks g and clones dev before Instant::now. Existing secs_fold excludes init/mutex wait while containing host packing and synchronous copy waits.',
 eliminated_work='Hypothesis: after preserved successful GPU initialization and reviewed failure ordering, doing immutable host packing outside the device mutex may shorten lock hold and reduce concurrent proof waiting. It eliminates no required packing/bytes/arithmetic; contention may be zero.',
 added_costs='Potential earlier host allocation and coexistence of multiple staging buffers; reordered shape/poison/OOM error timing; ownership/lock handoff and fail-closed review. Do not move work based only on secs_fold.',
 prerequisites='First owner instrument init,mutex-wait,lock-hold,packing,H2D,kernel,D2H,conversion and enclosing elapsed with actual concurrency and no double count. No concurrency experiment or device job authorized in this lane.',
 integration_cost='Moderate only if real contention: source-ordered callback/mock control then native owner review. Global priority3 measurement refinement, not a scheduling patch.',
 exactness='Source/timer observation only; outside-mutex variant not implemented/tested.',
 privacy_soundness='No mask/private opening reuse; preserve initialization/shape/poison/failure/publication behavior and fresh call-local buffer lifetime. More concurrent private buffers increase capacity obligations.',
 compatibility='Existing Rust/CUDA GPU mutex seam; no new API/dependency needed for instrumentation. Locks do not imply useful overlap.',
 end_to_end_ceiling='Unknown; max measured exclusive wait/hold saving, overlap-adjusted, minus added memory/packing costs.',
 falsification='No mutex contention, proof work serialized for other reasons, memory cost excessive, or error-order/privacy/native-byte mismatch.',
 disposition='Measurement request only. Do not implement a lock move until actual whole-workload evidence supports it.')
h=old+[tested,new]
(D/'hypotheses.json').write_text(json.dumps(h,indent=2)+'\n')
(D/'leading-hypothesis.json').write_text(json.dumps(tested,indent=2)+'\n')
ranking=json.loads((D/'startup/14-ranking-current.json').read_text())
ranking['global_priority'][2]['cycle0158_refinement']=new
ranking.update(local_tested_rank=87,local_next_rank=88,local_priority_order=[3,87,88],
 rationale='Verified complete-GPU workloads,context/DD/fidelity and exclusive phase clocks remain above this small host packing candidate. No further staging variants without native evidence.',
 not_a_gpu_or_proving_speed_claim=True)
(D/'ranking-current.json').write_text(json.dumps(ranking,indent=2)+'\n')
rotation=dict(current=['sumcheck/GKR','memory traffic','batching/amortization'],next=['lookup arguments and softmax','GPU NTT/commitments','quantization/arithmetic','proof composition'],
 queue=['GPU NTT/commitments','sumcheck/GKR','lookup arguments and softmax','memory traffic','batching/amortization','quantization/arithmetic','proof composition'],tested=87,next_local=88)
(D/'rotation.json').write_text(json.dumps(rotation,indent=2)+'\n')
records=[]
def source(title,url,pub,updated,evidence,assessment,license=None,commit=None,urls=None,blocked=None):
    records.append(dict(id='cycle0158-source-'+str(len(records)+1),cycle='0158',run_id=run,access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=now,
      title=title,url=url,publication_date=pub,verified_update_date=updated,date_evidence=evidence,assessment=assessment,
      implementation_license=license,inspected_commit_id=commit,inspected_urls=urls or [],blocked_urls=blocked or [],
      evidence_kind='Native LIVE tools.web__run search/open/find/click; source instructions treated as untrusted and ignored',reproduced_performance=False,external_execution=False))
source('NEW assessed older Vec extension specialization and direct append',
 'https://doc.rust-lang.org/src/alloc/vec/spec_extend.rs.html',None,None,
 'No publication/update day or source commit displayed; dynamic rustdoc is not the tested compiler1.75 source pin.',
 'Source specialization appends an IntoIter slice then deallocates it. A preallocated destination does not justify assuming the temporary allocation vanishes. This motivated local optimized allocation counters; those counters, not current rustdoc, establish the1.75 artifact results.',
 'Rust root LICENSE-MIT at1.85.0 inspected; no source copied/executed from web, no blanket third-party audit.',
 urls=['https://github.com/rust-lang/rust/blob/main/library/alloc/src/vec/spec_extend.rs','https://github.com/rust-lang/rust/blob/1.85.0/LICENSE-MIT'],
 blocked=['https://github.com/rust-lang/rust/blob/1.85.0/library/alloc/src/vec/spec_extend.rs','https://raw.githubusercontent.com/rust-lang/rust/1.85.0/library/alloc/src/vec/spec_extend.rs','https://doc.rust-lang.org/1.85.0/src/alloc/vec/spec_extend.rs.html'])
source('REFRESH ICICLE v4 release and inspected version-bump commit',
 'https://github.com/ingonyama-zk/icicle/releases/tag/v4.0.0',None,None,
 'Release UI displays11Jul05:36 without year; commit body inspected but no full timestamp displayed. No year inferred.',
 'Release changes field/Program interfaces. Inspected two-file commit only changes version/harness metadata; it does not prove kernel compatibility or speed. Extension sumcheck and Goldilocks release bullets require field,transcript,masking and device lifetime review; no drop-in or reproduced result.',
 'MIT root LICENSE on main inspected; optional backends/subcomponents not audited.',
 '6c77775961b0e4dc2be359feec1ac11536c18043',
 urls=['https://github.com/ingonyama-zk/icicle/commit/6c77775961b0e4dc2be359feec1ac11536c18043','https://github.com/ingonyama-zk/icicle/releases','https://github.com/ingonyama-zk/icicle/blob/main/LICENSE'],
 blocked=['https://api.github.com/repos/ingonyama-zk/icicle/releases/tags/v4.0.0','https://raw.githubusercontent.com/ingonyama-zk/icicle/main/wrappers/rust/icicle-core/src/sumcheck/mod.rs','https://github.com/ingonyama-zk/icicle/blob/v4.0.0/wrappers/rust/icicle-core/src/sumcheck/mod.rs','https://github.com/ingonyama-zk/icicle/blob/v4.0.0/wrappers/rust/icicle-core/src/sumcheck/config.rs'])
source('REFRESH October26 StateSync-GKR complete-result and preparation boundary',
 'https://arxiv.org/abs/2610.14849','2026-10-10','2026-10-26',
 'Primary arXiv history v1Oct10,v2Oct26,2026;v2 fulltext explicitly compares release1.2.0 with1.1.',
 'Authors separate core arithmetic from serving,queue/reply costs and verified acceptance; bounded queues and request identifiers are material to claimed completed throughput. CPU sparse-Merkle workloads do not establish private8B GPU throughput or authorize mask reuse. Current v2,not v1,used for assessment; no author speed reproduced.',
 urls=['https://arxiv.org/html/2610.14849v1','https://arxiv.org/html/2610.14849v2'])
source('REFRESH October11 zkLLMPoT forward-audit scope',
 'https://arxiv.org/abs/2610.08258','2026-10-06','2026-10-11',
 'Primary arXiv page submittedOct6,last revisedOct11,2026.',
 'Certifies selected trained-checkpoint properties by forward evaluation rather than the optimization trajectory. Sumcheck/lookup coverage and privacy contract still differ from this exact private attentionFFN target. Abstract refreshed only; prior detailed arithmetic boundaries remain, no implementation or author performance reproduced.')
sources=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()]
for s in records:s['prior_exact_url_records']=sum(v.get('url')==s['url'] for v in sources)
with (R/'sources.jsonl').open('a') as f:
    for s in records:f.write(json.dumps(s,sort_keys=True)+'\n')
(D/'sources-cycle.json').write_text(json.dumps(records,indent=2)+'\n')
blockers=[dict(url=u,blocker=('URL not accessible via this tool' if 'api.github.com' in u or '/1.85.0/src/' in u else 'Failed to fetch: Cache miss'),workaround='No bypass,installation or external code execution; independent local packing experiment completed.') for s in records for u in s['blocked_urls']]
(D/'blockers.json').write_text(json.dumps(blockers,indent=2)+'\n')
cases=[]
prior=json.loads((D/'startup/16-cost-study.json').read_text())
for v in prior['cases']:
    rows=v['rows'];k=v['rhos_including_proximity'];b=(k+3)//4;H=16*k*rows
    cases.append(dict(label=v['label'],context=v['context'],rows=rows,k=k,chunks=b,baseline_host_pack_alloc_requests=k+b,direct_host_pack_alloc_requests=b,
      baseline_host_pack_cumulative_requested_B=2*H,direct_host_pack_cumulative_requested_B=H,
      baseline_pack_peak_requested_B=16*rows*(min(k,4)+1),direct_pack_peak_requested_B=16*rows*min(k,4),
      unchanged_h2d_payload_B=H,unchanged_d2h_payload_B=16*k*v['columns'],scope='Conditional historical T128 standalone R14f_e9 group; not current8B/full workload or GPU peak'))
(D/'cost-study.json').write_text(json.dumps(dict(cases=cases,excludes='Input Fp2 vectors,output/download/device allocations,matrix,pads,allocator overhead and runtime. Requested packing scopes only; no measured transfer or elapsed saving.',ceiling='N/(T-C_pack_exclusive+A_added);perfect removal f ->speedup<=1/(1-f),f unknown'),indent=2)+'\n')
account=json.loads((D/'startup/15-target-accounting.json').read_text())
account['modeled_context']=128;account['scope']='Packing and synthetic scalar host-fold; no complete proofs or GPU'
(D/'target-accounting.json').write_text(json.dumps(account,indent=2)+'\n')
version=subprocess.run(['/usr/bin/rustc','-vV'],capture_output=True,text=True,check=True).stdout
(D/'compiler-version.txt').write_text(version)
(D/'history-audit.json').write_text(json.dumps(dict(prior_hypotheses=len(old),all_prior_exactly_preserved=h[:len(old)]==old,new_ranks=[87,88],prior_source_count=len(sources),new_source_count=len(sources)+len(records)),indent=2)+'\n')
print(json.dumps(dict(status='PASS',hypotheses=len(h),sources_appended=len(records),history_preserved=h[:len(old)]==old,cost_cases=len(cases))))
