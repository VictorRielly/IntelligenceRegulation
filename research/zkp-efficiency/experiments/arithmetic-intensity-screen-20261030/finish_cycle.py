"""One-time append/checkpoint for this run; refuses duplicate ledger mutation."""
import datetime, hashlib, json
from pathlib import Path
E = Path(__file__).resolve().parent
ROOT = E.parents[1]
RUN = '20261030T154123Z-20600a3e'
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
ledger = ROOT/'sources.jsonl'
old = (E/'startup/sources.jsonl').read_bytes()
assert ledger.read_bytes() == old
assert b'Cycle0167' not in (ROOT/'FINDINGS.md').read_bytes()

sources = [
 dict(title='REFRESH zkDuel SumCheck kernel characterization',
      url='https://arxiv.org/abs/2610.37710', publication_date='2026-10-26',
      date_evidence='Primary arXiv v1 submitted2026-10-26T21:28:29UTC; HTML agrees.',
      supporting_urls=['https://arxiv.org/html/2610.37710v1'],
      author_claim='Matched base-field CUDA/Triton microkernels show reduction structure and launch overhead affect the gap.',
      assessment='Already assessed; refreshed reduction-specific evidence. No native Fp2/private whole-stack inference from standalone kernels. No author result reproduced.'),
 dict(title='REFRESH zkDuel repository and unavailable code/license body',
      url='https://github.com/snarang181/zk-duel', publication_date=None,
      date_evidence='Root exposes one commit without date/hash. History/activity/code fetches unavailable; paper date is not repo update date.',
      implementation_license='MIT repository label/README only; license body fetch Cache miss, terms not inspected.',
      blocked_urls=['https://github.com/snarang181/zk-duel/commits/master/:Cache miss',
                    'https://github.com/snarang181/zk-duel/activity:Cache miss',
                    'https://github.com/snarang181/zk-duel/blob/master/LICENSE:Cache miss',
                    'https://raw.githubusercontent.com/snarang181/zk-duel/master/LICENSE:Cache miss',
                    'https://raw.githubusercontent.com/snarang181/zk-duel/master/cuda/src/field_sumcheck.cu:Cache miss'],
      assessment='README inspected, implementation not inspected or imported; no foreign execution.'),
 dict(title='NEWLY ASSESSED OLDER CUDA11 hardware warp reduction introduction',
      url='https://developer.nvidia.com/blog/cuda-11-features-revealed/',
      publication_date='2020-05-14', date_evidence='Primary article date; reduction description in article body, not generated summary.',
      author_claim='A100 introduces hardware integer warp reduction, exposed by cooperative groups.',
      assessment='New older primitive screen. Native GL needs exact carry-preserving arithmetic rather than ordinary wrapping integer addition.'),
 dict(title='NEWLY ASSESSED OLDER archived Ampere integer reduction guide',
      url='https://docs.nvidia.com/cuda/archive/11.0_GA/ampere-tuning-guide/index.html',
      publication_date=None, verified_update_date='2020-07-02',
      date_evidence='Primary footer explicitly Last updatedJuly2,2020,v11.0.194.',
      assessment='Supports older hardware-reduction availability; not a modern driver/toolchain performance result.'),
 dict(title='NEW primary PTX redux arithmetic and synchronization contract',
      url='https://docs.nvidia.com/cuda/parallel-thread-execution/#parallel-synchronization-and-communication-instructions-redux-sync',
      publication_date=None, date_evidence='Current PTXISA9.4; page-update date not verified. Redux introducedPTX7.0; integer pathsm80+.',
      author_claim='u32/s32 add result truncates32bits; all nonexited named threads execute matching membermask; warp-only operation.',
      assessment='Candidate bounds all three digit sums below2^32. No physical convergence or CUDA test; no memory ordering inferred from collective.'),
 dict(title='NEW CUB WarpReduce hardware path documentation',
      url='https://nvidia.github.io/cccl/unstable/cub/api/classcub_1_1WarpReduce.html',
      publication_date=None, date_evidence='Unstable docs, no verified page-update/commit date.',
      author_claim='Full32thread warps use one redux for32bit integer sum,three for64bit andfive for128bit onSM80+.',
      assessment='Wrapping64bit sum is not a Goldilocks sum; local carry-loss negative demonstrates the boundary. Candidate uses bounded digits, not direct CUB plus.'),
 dict(title='NEW CCCL3.5 release and inspected tag arch_traits fix scope',
      url='https://github.com/NVIDIA/cccl/releases/tag/v3.5.0', publication_date=None,
      date_evidence='Rendered release date07Oct16:11 omits year; no fully verified ISO release/update date. Version/release identity verified.',
      supporting_urls=['https://github.com/NVIDIA/cccl/releases',
          'https://github.com/NVIDIA/cccl/commit/28101b07413743e1dcca8ca8af1cfc63e8cff2d1'],
      inspected_commit_id='28101b07413743e1dcca8ca8af1cfc63e8cff2d1',
      inspected_commit_scope='Two-file arch_traitsSM100 fix and test diff only. WarpReduce implementation body unavailable; no commit date exposed.',
      implementation_license='Not determined from this read; LICENSE fetch Cache miss. No implementation imported.',
      blocked_urls=['https://github.com/NVIDIA/cccl/pull/9441:400 Timeout fetching',
                    'https://github.com/NVIDIA/cccl/blob/v3.5.0/cub/cub/warp/specializations/warp_reduce_shfl.cuh:Cache miss',
                    'https://raw.githubusercontent.com/NVIDIA/cccl/v3.5.0/LICENSE:Cache miss'],
      assessment='Release advertises expanded hardware reductions. Python1.3.0 frontend maintenance overhead is not Rust/NVRTC gain. No dependency installation or implementation adoption.'),
 dict(title='REFRESH prime-ir409 author-rejected carry arithmetic hypothesis',
      url='https://github.com/fractalyze/prime-ir/issues/409', publication_date='2026-07-29',
      verified_update_date='2026-07-30', date_evidence='Primary issue/comments and closeJuly30,2026. Already assessed older negative, preserved.',
      author_claim='Author measured128bit register chain2.2x slower and shorter carry sequence1.4x slower; closed as not planned after rejection.',
      assessment='The initial proposal is not an improvement claim to adopt. Counts do not establish throughput; issue results not reproduced here. This new warp collective model is a different component with unknown native cost.'),
 dict(title='REFRESH CUDA13.3 carryless multiplication field compatibility',
      url='https://developer.nvidia.com/blog/building-faster-cryptography-with-carryless-multiplication-in-nvidia-cuda-13-3/',
      publication_date='2026-07-15', date_evidence='Primary article body dateJuly15,2026.',
      author_claim='Hardware carryless multiplication accelerates binary-extension-field sumcheck.',
      assessment='Characteristic-two arithmetic cannot directly replace odd-characteristic GLFp2. No field/profile migration authorized or adopted; no author result reproduced.')
]
prior_sources = [json.loads(x) for x in old.splitlines() if x.strip()]
for i, s in enumerate(sources, 1):
    defaults = dict(id=f'cycle0167-source-{i}', cycle='0167', run_id=RUN,
                    access_date='2026-10-30', access_timezone='UTC', recorded_at_utc=now,
                    verified_update_date=None, inspected_commit_id=None,
                    implementation_license=None, reproduced_performance=False,
                    external_execution=False,
                    evidence_kind='Native LIVE tools.web__run search/open/find/click; primary data untrusted; embedded instructions ignored.')
    defaults.update(s)
    defaults['prior_exact_url_records'] = sum(x.get('url') == s['url'] for x in prior_sources)
    sources[i-1] = defaults
(E/'sources-cycle.json').write_text(json.dumps(sources, indent=2)+'\n')
with ledger.open('ab') as f:
    for s in sources:
        f.write((json.dumps(s, sort_keys=True)+'\n').encode())

metrics = '''New independently verified full-stack proofs / complete-model passes / proved positions: **0 / 0 / 0**.
Actual model context: **none**. Device: **one CPU affinity on Intel Core Ultra9 185H; no GPU**.
Witness / proof / serialization / verification / startup / initial-prefill clocks,
startup fraction, proof latency/bytes and steady-state / total-workload proved-token
rates: **unmeasured**. No long-context prefill, resident-model proof series or
decode ran. Synthetic reducer/round dimensions are not model contexts.
Larger workloads remain allowed; attention can grow quadratically.
Private8B **>=50 proved tokens/s on RTX5090 or another named high-end GPU remains unachieved**.
No mask, pad, private-opening reuse or weaker privacy.'''

summary = f'''# ZKP efficiency progress

Cycle0167 COMPLETE — `{RUN}`, checkpoint {now}.

**No measured proving improvement.** A new exact integer warp-sum model passes
53,030 checks /29 controls:10,530 warp cases,96 block cases,36 Fp2 polynomial
round cases. Separate243-check artifact/reference audit. One CPU,0.872s/20MiB
main leaf; no native build,CUDA,proof or cryptographic verifier.

Useful negative: inspected current trained/R14 slot factories select CPU
GroupedEqRounds/ClosureRounds. The legacy CUDA reducer has zero direct
incidence there; its optimization alone cannot accelerate those slots.
Conditional128thread/NV5 tail counts:shared scratch10240->320B,barriers8->1,
with added digit/collective/carry/register costs unknown. Uncompiled sketch;
counts are not timing,allocated peak or a proving gain.

{metrics}

Sources searched: refreshed Oct26 zkDuel and its GitHub artifact; newly assessed
CUDA11/Ampere2020 warp reduction,currentPTX/CUB and CCCL3.5; retained prime-ir
carry negative and binary-field CUDA13.3 exclusion. Nine exact-URL/date/license/
commit-scope records appended. Cache misses/timeouts recorded; no bypass.

Next: owner real private SumcheckRounds GPU incidence and exclusive phases,
then complete verified resident1/2/4/8 high-endGPU workloads. Local: inspect
new R14 freeze/phase evidence; source-count its actual grouped evaluator's
arithmetic/traffic before selecting another GPU primitive. No more reducer
variants absent active incidence/materiality. All100 prior hypotheses retained.

[Experiment](experiments/arithmetic-intensity-screen-20261030/README.md) ·
[Handoff](handoffs/20261030-exact-warp-reduction.md) ·
[Dated report](progress/{RUN}.md).
Saved reports do not establish user-message delivery.
'''
(ROOT/'PROGRESS.md').write_text(summary)

detail = f'''# Cycle0167 — exact warp sums and an inactive native seam

Run `{RUN}`; start2026-10-30T15:41:23Z; checkpoint{now}; deadline16:01:23Z.
Next cycle no earlier16:41:23Z. AGENDA,durable state/findings/source ledger,
latest experiment results,CLAUDE,status,decisions,coordination,target read;
early STATE checkpoint and startup/closing source pins retained.

**No measured proving improvement.** NewH101 asks whether exact integer warp
collectives can remove canonical shared-tree reductions. Its arithmetic
prerequisite passes53,030 checks/29 negative controls,with a separate243-check
saved-evidence audit. 27/27/10-bit digit sums fitu32 for32lanes; exact whole
sum is at most69bits,including its final carry. Independent bigint whole
sums and direct-node fullFp2 polynomials agree. Raw noncanonical reducer tests
are not field admission. Both references are locally authored,not external
native review. No CUDA compiler/device/prover/cryptographic verifier executed.

Warp cases10530;block cases96;polynomial round cases36. Physical lanes32;
synthetic CTA32..1024,NV1/3/5/6,degree2..5,half rows1/17/31/32/33/127/128/257/1025.
Four warp,three block,two polynomial fixtures retained. Negative controls
detect wrapping64bit sums,overflowing28bit digits,missing carries/limbs,
wrong membermask/modulus,missing/duplicate lanes/warps,evaluation routing and
shape/canonicality errors. Full-mask CUDA sketch has volatile collectives and
one CTA producer/consumer barrier; it is uncompiled. Arbitrary masks in the
model do not test physical divergence/convergence or memory ordering.

Baseline: current legacy kernels::scg_emit and k_reduce_f2 canonical shared
tree. Conditional128thread/NV5 scratch10240->320B and tail barriers8->1;
1270 scalar modular adds versus50 leader reductions+150 warp redux operations.
These operation types have different costs. Added digit extraction,
reconstruction,register pressure and public fallback are unmeasured. No
global proof bytes,polynomial products,launches or fresh masking removed.
Looped k_reduce_f2 scratch requires another barrier on both paths.

Decisive source negative: current trained and separate finalR14 slot factories
select host GroupedEqRounds/ClosureRounds; neither body invokes the legacy
CUDA zerocheck/reducer. Both grouped implementations use host Vec tables.
Six pinned source facts,not a whole-program security/callgraph audit.
Four R14 public geometry/definition pins match cycle0154; protocol changed.
No redundant geometry rerun,no owner implementation/review duplicated.

Direct current private-slot contribution is1x. Future enclosing ceiling
N/(T-C_reduce_exclusive+A),unknown;necessary50/s conditionT-C+A<=N/50.
Falsify promotion on absent incidence(observed),canonical byte/round/refusal/
carry/membermask/convergence mismatch,negligible reduction fraction or added
occupancy cost>=saved critical time. Native private SumcheckRounds GPU
evaluator,masked-byte/RNG/transcript/fold/terminal/PCS/refusal equivalence,
independent fresh-process verification and current privacy gates are owed.
No private mask/opening reuse or field/protocol migration authorized.

Main process0.871739s/20340KiB RSS;audit0.033100s/16912KiB. One nice19 CPU
affinity,Python3.10.12;30sCPU/40salarm/45sparent/256MiBAS,64MiB estimate.
These are correctness-process clocks. No failure hidden. No GPU/native build,
dependency install,foreign execution,production/Git/receipt/calibration/gate/
instruction/reviewer/runtime changes,external messages/writes or escalation.

{metrics}

HistoricalCPU8B diagnostic carried only,not rerun/reverified/newly counted:
T128/L32,one16thread GPU-off pass,total478.737s=0.267370positions/s.
prove_run393.785s includes witness98.348s/load17.595s;seal84.824s overlaps
load27.151s/witness80.897s. Receipt922711264B;verify42.709s+load13.681s.
Nested clocks cannot be summed;startupfraction/exclusiveserialization/steady
unknown. This is no prediction for a high-endGPU or this component.

LIVE primary sources: [zkDuel](https://arxiv.org/abs/2610.37710) Oct26 refresh,
[artifact](https://github.com/snarang181/zk-duel),new older
[CUDA11](https://developer.nvidia.com/blog/cuda-11-features-revealed/) May14,2020
and [Ampere guide](https://docs.nvidia.com/cuda/archive/11.0_GA/ampere-tuning-guide/index.html)
updatedJuly2,2020; currentPTX/CUB/CCCL3.5. Nine records1113->1122,exact dates/
unknowns/license limits retained. CCCL release rendersOct7 without year;
inspected commit28101b07413743e1dcca8ca8af1cfc63e8cff2d1 is only its arch_traits
fix,not blocked warp-reduction code. zkDuel license is an MIT label only.
GitHub history/code/license cache misses andPR9441 timeout recorded. The
[prime-ir issue](https://github.com/fractalyze/prime-ir/issues/409) closes with
author-rejected arithmetic proposals,not an improvement. CUDA13.3 binary-field
claims stay excluded from direct Goldilocks substitution. No author result
reproduced. No new paper-list-only candidate promoted.

Rank1 complete verified high-endGPU resident1/2/4/8;rank2 admitted context/
DD/fidelity scaling;rank3 native exclusive phases/capacities. H101conditional,
demoted for incidence. All100 prior hypothesis dictionaries/negatives retained.
Next owner: actual private GPU evaluator,exclusive reduction/other clocks and
actual capacities;shared build/heavy locks and independently verified complete
workloads. Next local: read new R14 freeze/phase evidence; count actual
GroupedEqRounds::round arithmetic/traffic at current public slot descriptors,
with independent source/shape controls,before picking another GPU primitive.
Do not duplicate owned R14 implementation or build more reducer variants.

Decision register latest read: tokenR19b review15:45UTC accepts with low fixes;
R19-1..3 closed and gate may re-pin18/19/19b. Classifier privacy acceptance
and the private8B high-endGPU throughput target remain separate scopes.

[Experiment](../experiments/arithmetic-intensity-screen-20261030/README.md) ·
[Integration](../experiments/arithmetic-intensity-screen-20261030/INTEGRATION.md) ·
[Handoff](../handoffs/20261030-exact-warp-reduction.md).
Saved reports do not imply a message was delivered or supervisor liveness.
'''
(ROOT/'progress'/f'{RUN}.md').write_text(detail)
finding = detail.replace('# Cycle0167 — exact warp sums and an inactive native seam',
                         '## Cycle0167 — 20261030T154123Z-20600a3e: exact warp sum, zero direct slot incidence', 1)
with (ROOT/'FINDINGS.md').open('a') as f:
    f.write('\n'+finding+'\n')

state = f'''# ZKP efficiency explorer — durable state

Cycle0167 COMPLETE: `{RUN}`.
Start2026-10-30T15:41:23Z;checkpoint{now};deadline16:01:23Z.
Next cycle no earlier16:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** H101 exact three-digit GL warp sums
pass53030checks/29controls:10530warp,96CTA,36Fp2polynomial-round cases.
Separate243-check saved-evidence audit imports neither candidate nor experiment.
Conditional tail128thread/NV5 shared10240->320B,CTAbarriers8->1; added digits/
collectives/carry/register costs unknown. Zero globalbytes/products/launches/
freshmasks removed. CUDA sketch UNCOMPILED; no device/convergence/nativeproof.

Decisive negative: pinned current trained/R14 private slot factories select
CPU GroupedEqRounds/ClosureRounds. Legacy CUDA reducer has zero direct
incidence there. Six source facts,not globalcallgraph/security review.
Direct contribution1x;futureN/(T-C_exclusive+A)unknown. Falsify absentincidence,
arithmetic/bytes/refusal/convergence mismatch orA>=C. No more reducer variants
until actualprivateGPUevaluator/exclusivephases. FourR14geometry/definition
pins matchcycle0154;protocolchanged. No ownerR14work duplicated.

Top3 remain complete verified high-endGPU resident1/2/4/8;admitted context/DD/
fidelity scaling;native exclusive phases/actual capacities. All100 prior
hypothesis dictionaries and all prior findings/negative results preserved.
NewH101conditional/demoted. NEXT owner:real privateSumcheckRounds GPU seam,
all exclusive proof/witness/transfer/serialize clocks and actual capacities,
then complete verified resident1/2/4/8 under current sharedheavy/buildlocks.
NEXT local:read newR14freeze/phase evidence;source-count actualGroupedEqRounds
round arithmetic/traffic using public descriptors with independent shape/
source controls before choosing another GPU primitive. No toy variants
without incidence/materiality. RotationnextGPU NTT/commitments,lookup/softmax.

{metrics}

HistoricalCPU8B T128/L32,one16threadGPUoffpass,total478.737s=0.267370/s,
carried only:not rerun/reverified/newlycounted. prove_run393.785s includes
witness98.348s/load17.595s;seal84.824s overlapsload27.151s/witness80.897s.
Receipt922711264B;verify42.709s+load13.681s. Nested clocks cannot be summed;
startupfraction/exclusiveserialization/steadyunknown. Classifier3B/R14
diagnostics are distinct;no private8B high-endGPU result follows.

NineLIVEprimaryrecords1113->1122:zkDuelrefresh,newolderCUDA11/Ampere2020,
PTX/CUB/CCCL3.5,prime-ircarrynegative,CUDA13.3binaryfieldexclusion.
Full license bodies unavailable;cachemiss/timeout limits retained.
Commit28101b07413743e1dcca8ca8af1cfc63e8cff2d1 inspected onlyarch_traits diff,
not blockedreductioncode. Releaseyearnotrendered;dateunknown keptnull.
No authorperformance reproduced orforeigncodeexecuted.

Latestownerdecision:tokenR19b review15:45UTC ACCEPTED WITH FIXES(alllow);
R19-1..3closed,gate canre-pin18/19/19b. No classifierprivacy or8Btarget change.
Main0.871739s/20340KiB;audit0.033100s/16912KiB;nice19,oneCPUaffinity,
30sCPU/40salarm/45sparent/256MiBAS/64MiBestimate,Python3.10.12,noGPU.

[Experiment](experiments/arithmetic-intensity-screen-20261030/README.md) ·
[Handoff](handoffs/20261030-exact-warp-reduction.md) ·
[Dated report](progress/{RUN}.md).
Only research outside runtime written. No production/Git/receipts/calibration/
gate/instruction/reviewer changes,build/GPU/install/foreignexecution,external
write/message,purchase/escalation/merge orlivenessaction. Reports are notdelivery.
'''
(ROOT/'STATE.md').write_text(state)
(E/'completion.json').write_text(json.dumps(dict(run_id=RUN,cycle='0167',
             completed_at_utc=now,status='COMPLETE',source_records_before=1113,
             source_records_after=1122,prior_hypotheses=100,current_hypotheses=101,
             new_full_stack_proofs=0,new_proved_positions=0),indent=2)+'\n')
print(json.dumps(dict(status='CHECKPOINTED',utc=now,sources_appended=len(sources))))
