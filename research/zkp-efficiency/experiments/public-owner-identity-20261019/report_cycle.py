#!/usr/bin/env python3
"""Write cycle0085's local evidence, append-only ledgers and checkpoint."""
import datetime
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RUN='20261019T171854Z-d589849d'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()


def dump(name,value):
    (HERE/name).write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')


main=json.loads((HERE/'result.json').read_text())
audit=json.loads((HERE/'audit-result.json').read_text())
assert main['status']==audit['status']=='PASS'
baseline='''Carried owner R8 CPU 8B diagnostic: T128, 32 blocks, one 16-thread
pass, GPU off, n=1. Total 478.737 s; diagnostic quotient
128/478.737 = 0.267370 positions/s. Prove_run 393.785 s includes witness
hand-over 98.348 s, itself including block loads 17.595 s. Sealing wall
84.824 s includes overlapping load tasks 27.151 s and witness tasks 80.897 s.
The JSON load_seconds is sealing load tasks only. Do not add these nested or
overlapped clocks. Receipt 922,711,264 B. Fresh verify 42.709 s plus initial
load 13.681 s; recheck 34.395 s plus load 10.739 s. The fresh verifier's
guard wall 165.982 s also includes control work, not just basic verification.
Startup fraction, isolated serialization and steady slope are unmeasured.
Researcher did not reverify a receipt and awards no new target credit.'''
target='''New independently verified target proofs/passes/positions: **0/0/0**;
device none. Target steady-state and total-workload rates, startup fraction,
witness/proof/serialization/verification clocks: unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic scan
pairs are public constructor requests, not proof passes or proved positions.
Larger workloads remain allowed; longer context can increase attention work
quadratically. Complete private 8B / >=50 proved positions/s on one RTX 5090
or a named high-end GPU remains unchanged and unachieved.'''
next_action='''Next local experiment: account for the R8 public loader's raw arrays,
aw/fw padded vectors and new_shaped-owned copies over the full constructor
lifetime. Compare borrowed-copy versus checked ownership-transfer on small
synthetic shapes with true-head permutation, zero pads and invalid-support
controls; derive a conservative public peak including current/next loads and
retained pins, without allocating model data. Preserve every constructor/CS
check and native reload/refusal. This closes a memory exclusion in the present
ledger. Cycle0027 already completed canonical public digest streaming/cache;
do not repeat it or claim a second stage hash from single-block wrappers.
Owner priority remains whole-prover GPU plus independently verified fixed-
context resident1/2/4/8 complete workloads under shared heavy locks.'''

hypotheses=[
dict(rank=1,hypothesis='Owner: complete GPU prover and verified resident workload sweep',
 baseline='Carried R8 CPU T128 478.737s; no high-end GPU steady slope.',
 eliminated_work='Dominant recurring CPU proof arithmetic/commitment traffic and genuine once-only setup.',
 added_costs='Transfers, device buffers, synchronization, serialization and pipeline drain.',
 end_to_end_ceiling='Unknown until complete verified GPU workload; no kernel-to-token extrapolation.',
 prerequisites='Actual named device, all exactness/privacy/soundness gates, heavy lock admission.',
 integration_cost='High, owner only',exactness='Unchanged full attention+FFN relation and calibration.',
 privacy_soundness='Fresh masks/openings, independent receipt verification; D33 does not cover GPU/8B.',
 falsification='Any proof/privacy/fidelity gate failure, unbounded backlog or no enclosing gain.'),
dict(rank=2,hypothesis='REFINED: revalidated public owner with lease-aware admission, construction-only savings',
 baseline='Separate seal loader and one-current-block proving cache; mandatory current-byte digest on reload.',
 eliminated_work='Synthetic pin4 over8 scan pairs avoids60/512 padded constructors; guarded variant removes0/512 raw read observations.',
 added_costs='Source fingerprint/identity checks, immutable retention and live leases, raw scans; actual native cost unknown.',
 end_to_end_ceiling='T/(T-s+a), exclusive avoided construction s and all extra costs a unmeasured. No measured improvement.',
 prerequisites='19-field synthetic identity is conservative, not native key specification; owner must preserve all native CS/H-1 gates and mutable-source refusals.',
 integration_cost='Moderate/high typed public owner shared by seal_and_record and BlockCache::get; no native patch.',
 exactness='Synthetic padding/identity/outcomes only. Key-only hit fails source-mutation refusal semantics.',
 privacy_soundness='P1 public weights only; no witness, RNG, endpoints, challenge or private-opening owner reuse. No P3 authorization.',
 falsification='Any changed native refusal/receipt/privacy result, uncharged lease, peak limit failure, or overhead >=exclusive saved work.'),
dict(rank=3,hypothesis='NEW next local: remove per-call public digest conversion temporary while preserving every input byte',
 baseline='BlockPublic::digest absorbs private-field-owned public arrays; absorb_into builds per-weight temporary Vec<u8>. Normal trained streaming reload already checks once.',
 eliminated_work='Only justified temporary allocation/conversion/copy, not reload/hash/security checks.',
 added_costs='Chunk packing, extra hash updates or representation-safe adapter and native gates.',
 end_to_end_ceiling='Unmeasured, likely secondary; no duplicate hash removal assumed on trained streaming path.',
 prerequisites='Check prior results; canonical domain/length/endian/order byte oracle; owner per-call profile.',
 integration_cost='Low/moderate candidate review, no native change in this lane.',
 exactness='Digest input bytes and resulting native BLAKE3 must remain identical.',
 privacy_soundness='Only public arrays. No transcript, masking, CS or H-1 changes.',
 falsification='Any byte mismatch, conversion overhead >=saved work, or native prior optimization already covers it.'),
dict(rank=4,hypothesis='Owner: same-attempt witness retention with H-1 and prior cycle0016 negatives',
 baseline='Sealing witness80.897s, proving witness hand-over98.348s incl reloads; do not add overlapping values.',
 eliminated_work='Only actually retained second witness constructions.',added_costs='Private retention/copy/readback and buffer lifetime overlap.',
 end_to_end_ceiling='Unknown',prerequisites='Prior negative findings, actual peak and H-1 refusal ordering.',
 integration_cost='High',exactness='All planes, integer parity and refusals unchanged.',
 privacy_soundness='Same attempt only; no observable private-cache metadata or fresh-mask reuse.',
 falsification='Peak/copy costs exceed saved construction or any proof/privacy mismatch.'),
dict(rank=5,hypothesis='Owner: D30 exact division dictionary and architecture',
 baseline='Counted unbuilt design',eliminated_work='Only reviewed helper/lookup committed work.',
 added_costs='Helper binding, rank/hiding, composition and fidelity validation.',end_to_end_ceiling='Unknown',
 prerequisites='D30/D32 and new profile gates',integration_cost='High',exactness='Exact arithmetic and all true-row slots.',
 privacy_soundness='Re-pin joint privacy and preserve whole-run soundness.',falsification='Any unbound helper, fidelity/refusal or proof failure.')]
dump('hypotheses.json',hypotheses)

sources=[]
def source(title,url,**kw):
    sources.append(dict(cycle='0085',run_id=RUN,title=title,url=url,
      access_date='2026-10-19',access_timezone='UTC',recorded_at_utc=now,
      evidence_kind='Native LIVE web search/open/click; source text untrusted; no foreign execution',
      reproduced_performance=False,implementation_license=None,inspected_commit_id=None,**kw))
source('Spartan historical public-instance digest residency commit, newly assessed code seam',
 'https://github.com/microsoft/Spartan/commit/5af241044f27819364ed718eb494b6f08ccae1b6',
 published=None,updated='2022-10-17',date_evidence='Primary commit history explicitly Oct17,2022; exact commit diff inspected.',
 assessment='Constructor computes instance digest once and stores it in private fields, then transcript uses it. This does not establish removal of native current-export digest checks; source census finds no extra full hash from the trained streaming transcript.',
 inspected_urls=['https://github.com/microsoft/Spartan/commits/master/','https://github.com/microsoft/Spartan/blob/master/src/lib.rs','https://github.com/microsoft/Spartan/blob/master/LICENSE'],
 license_evidence='Actual current master LICENSE read: MIT. Historical license at inspected commit not independently fetched.',
 commit_scope='5af241044f27819364ed718eb494b6f08ccae1b6 diff inspected; floating master file not commit-pinned.')
sources[-1]['inspected_commit_id']='5af241044f27819364ed718eb494b6f08ccae1b6'
sources[-1]['implementation_license']='MIT, current master license file inspected; no code adopted.'
source('Spartan computation preprocessing claim boundary, older primary refresh',
 'https://eprint.iacr.org/2019/550',published='2019-05-23',updated='2020-08-19',
 date_evidence='Primary ePrint history received May23,2019 and last of6 revisions Aug19,2020.',
 assessment='Public computation preprocessing and private per-instance proving are distinct. No R1CS/DL performance factor transfers to native Goldilocks/Fp2 model proofs.',
 paper_license='CC BY; separate from implementation license.')
source('Magnetar October paper and announcement: composition implementation boundary',
 'https://www.microsoft.com/en-us/research/wp-content/uploads/2026/10/magnetar-1.pdf',
 published='2026-10-05',updated=None,
 date_evidence='PDF cover Oct5,2026; Microsoft primary announcement explicitly published Oct15,2026. No revision date inferred.',
 inspected_urls=['https://www.microsoft.com/en-us/research/blog/proof-based-general-purpose-computing-with-magnetar/','https://www.microsoft.com/en-us/research/publication/magnetar-high-speed-post-quantumrv64-zkvm-from-standard-hashes/'],
 author_claim='Hash-based RV64 proving and an efficient-recursion design; reported CPU workload benchmarks.',
 assessment='PDF p8 says proposed chunked recursive composition not implemented. Do not count a composition throughput gain or translate processor cycles to complete private8B tokens. Implementation repository/license not located in inspected primary pages.')
source('StateSync-GKR October reusable preparation refresh',
 'https://arxiv.org/abs/2610.14849',published='2026-10-10',updated=None,
 date_evidence='Primary v1 history Oct10,2026 12:06:57UTC; no later revision displayed.',
 author_claim='Reusable sparse preparation with explicit delivered-proof cost accounting.',
 assessment='Motivates separating owner construction, request scans and complete delivery. Different relation/field/privacy boundary; no author gain reproduced. Implementation license not re-inspected.')
source('BatchZK dynamic loading and full pipeline boundary, known older lead refreshed',
 'https://eprint.iacr.org/2024/1862',published='2024-11-15',updated=None,
 date_evidence='Primary history received Nov14 and approved Nov15,2024; ASPLOS2025 minor revision noted without exact revision day.',
 author_claim='Dynamic loading and multi-stream overlap increase proof throughput on its workloads.',
 assessment='A pinned public subset and source revalidation must still charge full resident/prefetch overlap. Proofs/s is not model positions/s; no code found by the inspected search, no implementation license claim.',
 paper_license='CC BY, not an implementation license.')
source('ZKProphet whole-workload bottleneck scope refresh',
 'https://arxiv.org/abs/2509.22684',published='2025-09-17',updated=None,
 date_evidence='Primary v1 Sep17,2025 22:52:19UTC; no later version displayed.',
 assessment='Paper bottlenecks are for its GPU proof workloads. Current local native CPU measurements instead rank commitments, witness and zero-checks. Do not assume NTT dominates this stack.')
source('cuda-zkp-ntt v5 invalid full transform filter and license refresh',
 'https://github.com/Artemarius/cuda-zkp-ntt/releases',published=None,updated=None,
 date_evidence='Release displays March16 21:42 without year in retrieved text. License copyright2026 is not proof of release year. No exact date/currentHEAD asserted.',
 inspected_urls=['https://github.com/Artemarius/cuda-zkp-ntt/blob/main/README.md','https://github.com/Artemarius/cuda-zkp-ntt/blob/main/LICENSE','https://github.com/Artemarius/cuda-zkp-ntt/commits/main/'],
 access_issues=['commits/main InternalError'],
 assessment='Prior negative retained: hierarchical transform outputs invalid despite attractive time. Stage-only/full-transform ratio cannot prove a whole transform or complete-model gain. Actual current LICENSE read, MIT; no code executed/adopted.')
sources[-1]['implementation_license']='MIT, actual current main LICENSE inspected.'
source('Plonky3 current rc2 release: mask RNG guard and public compiled components',
 'https://github.com/Plonky3/Plonky3/releases',published=None,updated=None,
 date_evidence='Retrieved release lists October16 at10:17/10:31; year not explicit in text. Prior cycle records2026; no new year verification orHEAD claim.',
 displayed_uninspected_commit='fe5e46d',
 assessment='Release lists cryptographic RNG requirement for HVZK masks and reused compiled components. Only public preparation is a reuse lead; never masks or private openings. License not re-inspected.')
dump('source-records.json',sources)
ledger=ROOT/'sources.jsonl'; before=(HERE/'startup/sources.jsonl').read_bytes()
assert ledger.read_bytes()==before,'Ledger changed concurrently; stop instead of overwriting.'
with ledger.open('a') as out:
    for s in sources: out.write(json.dumps(s,sort_keys=True)+'\n')

dump('target-accounting.json',dict(new_target_proofs=0,new_target_passes=0,new_target_positions=0,
    target_total_workload_positions_per_second=None,target_steady_state_positions_per_second=None,
    startup_fraction=None,witness_seconds=None,proof_seconds=None,serialization_seconds=None,
    verification_seconds=None,device=None,context_length=None,workload='No proof workload ran',
    synthetic_scan_pairs=[1,2,4,8],synthetic_layer_count=32,synthetic_payload_count_context=128,
    carried_owner=dict(context_length=128,passes=1,blocks=32,threads=16,device='CPU; GPU off',
      total_seconds=478.737,diagnostic_positions_per_second=128/478.737,
      prove_run_seconds=393.785,sealing_wall_seconds=84.824,witness_handover_seconds_in_prove=98.348,
      block_load_seconds_within_handover=17.595,sealing_load_task_seconds=27.151,
      sealing_witness_task_seconds=80.897,serialization_seconds=None,startup_fraction=None,
      steady_state_positions_per_second=None,receipt_bytes=922711264,
      fresh_verify_seconds=42.709,fresh_verify_initial_load_seconds=13.681,
      fresh_verify_control_inclusive_guard_wall_seconds=165.98196530342102,
      researcher_independent_verification=False,target_credit=0)))

census=[dict(file='hashline/src/private_block/trained_block.rs',lines=[909,917,1807,1812,1813,2034,2066,2587],
    finding='Full seal load, reduced reload then actual block digest; current Arc already shared between witness and block source. Seal prefetch has current+next overlap.'),
 dict(file='hashline/src/private_block.rs',lines=[592,710,733,757],
    finding='Private owned public fields, immutable getters; digest streams canonical words but allocates i8->u8 vectors. Construction-only candidate; no runtime call count assumed.'),
 dict(file='hashline/src/private_block/run.rs',lines=[573,818,863,914,933],
    finding='In-memory source hashes blocks in CS6; trained CacheBlocks uses digest-list check instead. Native run transcript uses already bound digests.'),
 dict(file='hashline/src/private_block/protocol.rs',lines=[113,121,846,1362],
    finding='Full public.digest transcript call is a single-block wrapper, not another hash in trained streaming prove_core path.')]
dump('source-census.json',census)

readme=f'''# Public owner identity, source freshness and live leases

Cycle0085 — `{RUN}` — 2026-10-19 UTC.

**No speed improvement measured.** A complete cache key does not observe
changed backing arrays. The key-only owner fails the streaming oracle's
source-mutation refusal semantics. A guarded owner matches the tested
outcomes but retains every raw source read observation; only construction
is avoided. This does not demonstrate an unsound proof: retained original
bytes still name the original model. It is a native behavior/compatibility
failure if silently substituted for the existing mutable-export loader.

The native seam is seal_and_record -> shared public owner -> BlockCache::get.
The frozen R8 source (15 source/evidence pins,11 matching its manifest) already
shares the current Arc between witness and proving. Full seal validation,
reduced reload, actual block digest checks, CS1/3/4/6/8/9 and H-1 remain owner
port gates. No native patch or merge. D33 covers only trained TinyLlama T32
pg_rot1 CPU R7; R8 needs re-pin, and 8B/GPU/token stages are outside it.
D32 fidelity thresholds remain binding.

The bounded synthetic experiment uses32 public fixtures,13 arrays per layer,
seven5x3 matrices padded8x4 and six1x3 vectors padded1x4. Each layer has123 raw
bytes; these are seeded random public miniatures, not model arrays or field
arithmetic. A tuple-of-bytes owner is immutable. The full19-field identity
includes model/checkpoint/approval/profile/manifest/layer, axes, context,
ordered layer selection, base/own calibration, exp/SiLU keys, RoPE and source
format. This conservative synthetic key is not an admitted native key.

Main PASS: {main['checks']} assertions,4800 synthetic requests,8 controls.
Row-copy construction is compared byte-for-byte to independent elementwise
padding on every request. Mutations to all19 descriptor fields refuse.
All13 raw-array mutations under the ORIGINAL expected identity demonstrate
the key-only stale-source counterexample; guard rejects them. Length,
manifest, table and RoPE changes also refuse. No concurrent-writer/atomic
snapshot guarantee follows from sequential in-memory revalidation.

Separate audit PASS: {audit['checks']} assertions,32 fixtures,416 independent
content-mutation controls and64 fresh asymmetric padding fixtures. It imports
no candidate code. The fresh fixtures validate the audit's padding oracle;
they are not additional candidate differential cases. Main/audit clocks
{main['wall_seconds']:.6f}/{audit['wall_seconds']:.6f}s; peaks
{main['rss_kib']}/{audit['rss_kib']}KiB. One nice19 CoreUltra9 185H CPU0,
Python3.10.12,WSL2;59s CPU/wall,512MiB address space,64MiB estimate per command.
Exact argv/exits/stdout/stderr are retained in commands.json and*.log.
Seeds2026101985 (main),2026101986 (audit).

Pin4 across8 ordered sealing/proving scan pairs gives60/512 constructor
hits,452 constructions, but512/512 source-read observations remain with
strict revalidation. Public padded native T128 payload count:
243411456B/block. Pinned4 retention973645824B=0.906778GiB; plus current/next
envelope1460468736B=1.360168GiB. These logical counts allocate no model data
and exclude raw decode/pad temporary buffers, private witnesses, proof/device
buffers, allocator and runtime. They are not peak-RSS/VRAM admission.

On an abstract model-generation change, two old blocks remain borrowed.
Charging registry entries only admits four new pins and reaches8 logical
blocks1947291648B=1.813557GiB against a six-block budget. Charging the union
of live owners plus two streaming reserves admits2 and denies2, capped at6.
This is a lifetime stress model, not an observed native concurrency trace.
Eviction is not a deallocation guarantee while Arc borrowers remain.

Baseline is current separate ownership. Removed work: only authenticated
public padding/construction on actual hits. Added costs: all guarded source
reads/hashes, complete identity checks, retained ownership/admission and
temporary overlap. Exclusive construction clocks are absent. End-to-end
ceiling T/(T-s+a), saved exclusive wall s and extra a, is unknown. Do not use
hit ratios as time savings or transfer prior generous all-load deletion bounds
to this guard. Falsify if native refusal/receipt/privacy behavior changes,
memory budget fails, or extra work costs at least the saved construction.

Spartan's inspected historical digest-owner commit is a useful comparison,
not a license to cache native current-file checks. Source census also rules
out an apparent second full digest from protocol::transcript in the trained
streaming route: that call belongs to single-block wrappers. Preserve it.

{baseline}

Eight qualified LIVE primary records append sources462->470: newly assessed
Spartan digest-residency commit, older paper boundary, recent Magnetar paper
and announcement, StateSync, BatchZK, ZKProphet, cuda-zkp-ntt and P3 release
filters. Licenses/verified dates/commit scope and access failures are explicit
in source-records.json/search-log.md. No external performance reproduced.

{next_action}

{target}

Only research files written. No runtime, production, Git, receipt, calibration,
safety, instruction or reviewer files changed. No GPU/build/install/downloaded
code execution, external write/message, purchase or escalation. Saved reports
do not establish delivery. See hypotheses.json and the unapplied handoff.
'''
(HERE/'README.md').write_text(readme)

handoff=f'''# Unapplied public owner compatibility handoff — 2026-10-19

Run `{RUN}`. Conditional construction-only candidate; no native speed gain.
Research patch: experiments/public-owner-identity-20261019/experiment.py,
PublicPool/Owner and lifetime_trace; independent audit.py. No Rust/CUDA patch.

Native interface for the owner to review: accept an authenticated public layer
request, return an immutable Arc<BlockPublic> lease, and charge allocation
identity until every borrower releases it. Share ownership across
trained_block.rs:seal_and_record (2034) and BlockCache::get (1797); caller
construction at2587 currently starts a separate cache. Admit a fixed public
pinned subset with native streaming fallback. Cache key must bind full model,
manifest,actual bytes,layer/table/geometry/RoPE/source identity, with the actual
layer-range/base-calibration selection. Synthetic19-field key is conservative,
not a checked native schema. Preserve all actual CS checks and H-1 ordering.

Key-only hits do NOT preserve source-change refusals:13/13 changed backing
arrays are accepted by retained owner, refused by streaming. This is NOT an
accepted proof of different weights; the owner still carries original bytes.
Under existing mutable-export semantics use independent current-source
validation, or retain native reload. Do not silently substitute snapshot
semantics. A future explicit immutable-source backend could define a reviewed
source contract, but its mutation/control behavior and native gates need owner
review; this cycle gives no authorization to change them.

Guarded synthetic hits leave512/512 source reads at8 scan pairs; pin4 avoids
60/512 padded constructors. New hashing/validation may exceed native reload
cost because current reload intentionally skips per-array SHA and recomputes
the actual block digest. No savings inferred without clocks.

Pin4 native-sized public backing0.906778GiB; with current/next envelope
1.360168GiB before all raw/padding/proof/private/device memory. On model change,
two old leases + four new pins + two streaming reserves is1.813557GiB;
registry-only accounting exceeds the stated six-block budget. Charge union
of distinct live allocations, pending admissions and temporary buffers.
Stress model only; no native peak or GPU-fit measurement.

Main{main['checks']} assertions/8 controls; independent audit{audit['checks']}
assertions/416 content mutations/64 fresh oracle fixtures. Scope is synthetic
public byte padding, identity, guard outcomes and count accounting. Native
CS/H-1/receipt/refusal/transcript/PCS/final/privacy equivalence remains owed.
No witness,RNG,masks,challenge denominators,endpoints or openings in this owner.
P1 public weights only; P3 private-weight reuse requires a separate review.
D33 R7 TinyLlama acceptance does not transfer to R8/8B/GPU; D32 remains.

{baseline}

Measure exclusive public read/hash/parse/padding/construction clocks and actual
live-allocation peak; reject if new cost >=avoided construction or any gate
differs. Whole-prover GPU and independently verified resident1/2/4/8 complete
workloads remain the first owner action. Main/Claude reviews and integrates;
researcher performs no native build/proof/merge.

{next_action}

{target}
'''
(ROOT/'handoffs/20261019-public-owner-identity.md').write_text(handoff)

progress=f'''# ZKP efficiency progress

Cycle0085 — `{RUN}` — 2026-10-19 UTC.

**No speed improvement measured.** A full public cache key misses changed
backing arrays. The bounded experiment rejected a key-only cache on13/13
source mutations. Revalidation caught them, but retained all512 source-read
observations; pin4 avoided60/512 synthetic constructors over8 scan pairs.
Eviction also leaves borrowed allocations live: registry-only accounting
reached8 blocks against a6-block limit in the generation-overlap stress model.

Main{main['checks']} assertions/8 controls; independent audit{audit['checks']}
assertions with416 content mutations and64 fresh asymmetric oracle fixtures.
{main['wall_seconds']:.3f}/{audit['wall_seconds']:.3f}s, peaks
{main['rss_kib']}/{audit['rss_kib']}KiB, one nice19 CPU core; no native proof/GPU.
These measure synthetic byte/identity/lease behavior, not private-model speed.
15 source/evidence pins unchanged. Eight LIVE records appended462->470.

{baseline}

Seam: immutable public lease between seal_and_record and BlockCache::get,
with preserved source-mutation refusals, every CS check and H-1. Exclusive
construction/revalidation clocks and actual complete memory remain unknown.
{next_action}

{target}

[Experiment](experiments/public-owner-identity-20261019/README.md),
[handoff](handoffs/20261019-public-owner-identity.md),
[dated report](progress/{RUN}.md).
Only research files changed; saved reports do not imply message delivery.
'''
(ROOT/'PROGRESS.md').write_text(progress)
(ROOT/'progress'/f'{RUN}.md').write_text(progress.replace('# ZKP efficiency progress',f'# Cycle0085 progress — {now}'))
findings=ROOT/'FINDINGS.md'; old=(HERE/'startup/FINDINGS.md').read_bytes()
assert findings.read_bytes()==old,'Findings changed concurrently; stop instead of overwriting.'
with findings.open('a') as f:
    f.write('\n\n## Cycle0085 — 2026-10-19: public owner freshness and live leases\n\n')
    f.write(readme.split('\n\n',1)[1])

state=f'''# ZKP efficiency explorer — durable state

Cycle0085 COMPLETE: `{RUN}`, 2026-10-19 UTC.
Next cycle no earlier than **18:18:54 UTC**. Deadline17:38:54 UTC.
[Dated report](progress/{RUN}.md).
Startup memory:experiments/public-owner-identity-20261019/startup/.

**No speed improvement measured.** Key-only public owner fails source-change
refusal behavior for13/13 backing-array mutations even with full identity.
It still carries original committed model bytes; no soundness attack claimed.
Revalidation preserves tested outcomes but removes0/512 raw read observations.
Pin4 avoids60/512 public constructors at8 synthetic scan pairs, not proof work.
Native current Arc already shared. Do not claim a second full digest from
single-block transcript wrappers in trained streaming. All native CS/H-1
gates and mutable-source refusal semantics remain owed in any owner port.

Native-sized public payload:243411456B/block. Pin4 retention0.906778GiB;
current/next envelope1.360168GiB before raw/pad/proof/private/device buffers.
Logical generation overlap2old leases+4newpins+2streams=8blocks1.813557GiB;
six-block admission charging live union permits2newpins, denies2. Model only,
no actual peak/fit or source IO measurement. Key-only and registry-only
shortcuts rejected. Native cold per-array hashing already reduced on reload;
guard overhead may exceed avoided construction. Candidate ceiling unknown.

MainPASS{main['checks']} assertions/8controls/4800 syntheticrequests,19keyfields.
Independent audit{audit['checks']} assertions,416mutations,64fresh oracle cases.
Main/audit{main['wall_seconds']:.6f}/{audit['wall_seconds']:.6f}s,
peaks{main['rss_kib']}/{audit['rss_kib']}KiB,one nice19 CPU0,CoreUltra9 185H,
Python3.10.12,WSL2;59s/512MiB caps.15 pins unchanged,11R8 manifest matches.
[Handoff](handoffs/20261019-public-owner-identity.md). No native patch/merge.

Ranked hypotheses (full experiment hypotheses.json):
1.Owner whole-prover GPU + independently verified resident1/2/4/8 workloads.
2.Refined guarded immutable public owner, construction-only savings and live leases.
3.New public digest temporary conversion/copy reduction, canonical bytes unchanged.
4.Owner same-attempt witness retention, prior0016 negatives and H-1 retained.
5.Owner D30 architecture with D32 fidelity and all privacy/soundness gates.

{next_action}

{baseline}

New mandate evidence: D33 privacy accepted for trained TinyLlama T32 pg_rot1
CPU R7 only; R8 needs gate re-pin. Does not cover8B/GPU/token/per-layer exports.
Eight LIVE records462->470; specific older Spartan digest-owner commit
5af241044f27819364ed718eb494b6f08ccae1b6 inspected,current MIT license read.
Magnetar PDF datedOct5/blogOct15,2026: proposed recursive chunk composition
not implemented, no token throughput transfer. Current P3/cuda release date
and license qualification explicit. External gains reproduced:none.
Rotation:memory/batching/public setup this cycle; next lookup/softmax and
quantization/arithmetic; retain GPU NTT/commitments,sumcheck/GKR,composition.

{target}

Only research files written; no runtime/production/Git/receipt/calibration/
safety/instruction/reviewer changes. Saved reports do not establish delivery.
Checkpoint{now}.
'''
(ROOT/'STATE.md').write_text(state)
print(json.dumps(dict(status='checkpointed',sources_before=462,sources_after=470,
    main_checks=main['checks'],audit_checks=audit['checks'],time=now)))
