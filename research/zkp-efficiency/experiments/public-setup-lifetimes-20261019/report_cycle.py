#!/usr/bin/env python3
"""Write research-only cycle reports after successful bounded checks."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import resource
import signal

resource.setrlimit(resource.RLIMIT_AS, (512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU, (59,59))
signal.alarm(59)
os.nice(19)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
E = Path(__file__).resolve().parent
R = E.parent.parent
RUN = '20261019T161854Z-4bc2599e'
REL = E.relative_to(R).as_posix()
read = lambda name: json.loads((E/name).read_text())
r,a,t = read('result.json'),read('audit-result.json'),read('target-accounting.json')
assert r['status']==a['status']=='PASS'
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
records=read('source-records.json')
sources=R/'sources.jsonl'
prior=(E/'startup/sources.jsonl').read_bytes()
before=sources.read_bytes()
assert before.startswith(prior),'Prior source prefix changed'
existing={json.loads(x).get('title') for x in before.decode().splitlines() if json.loads(x).get('run_id')==RUN}
with sources.open('a') as f:
    for x in records:
        if x['title'] not in existing:f.write(json.dumps(x,sort_keys=True)+'\n')
source_before=len(prior.splitlines());source_after=len(sources.read_bytes().splitlines())

hypotheses=[
 dict(rank=1,hypothesis='Owner: whole-prover GPU and independently verified fixed-context resident1/2/4/8 complete passes',
      baseline='R8 CPU8B T128 one32-block pass478.737s; no accepted GPU steady slope.',
      eliminated_work='Broad recurring CPU arithmetic/traffic and genuine once-per-process work, only after actual device integration.',
      added_costs='Device transfers, persistent memory, synchronization, complete commitments/serialization and pipeline drain.',
      expected_end_to_end_ceiling='Unknown on named high-end GPU; no kernel-derived token forecast.',
      prerequisites='Owner admitted profile, actual named high-end device, shared heavy locks, fresh masks and independent verification.',
      integration_cost='High',exactness='All relations, field, calibration, refusals, PCS/finals and transcript unchanged.',
      privacy_soundness='Only completed independently verified full-stack positions count; no opening/mask reuse.',
      falsification='Failed native/receipt/privacy gate, growing proof backlog, peak overflow or no enclosing gain.'),
 dict(rank=2,hypothesis='NEW tested policy filter: fixed public pinned subset across sealing/proving scans, rather than partial LRU',
      baseline='Two ordered32-layer public loads per pass, separate sealing and one-current-block proving cache.',
      eliminated_work='Synthetic fixed-context R8 trace: pin4 of32 gives60/512 requests hit over8passes; any LRU capacity1..31 gives0hits.',
      added_costs='4 public padded blocks=0.906778GiB payload, immutable owner/complete identity checks, possible cold validation and peak/eviction costs.',
      expected_end_to_end_ceiling=f'Unmeasured candidate gain. Deleting ALL sealing-load and proof-block-load tasks at zero cost bounds only this CPU diagnostic at {t["all_load_zero_cost_upper_speedup"]:.6f}x; overlap lowers gain. No GPU/steady forecast.',
      prerequisites='Retain authenticated immutable public blocks across both scopes; bind model/manifest/block/layer/geometry/table/RoPE identity; measure exclusive saved load costs and actual peak.',
      integration_cost='Moderate/high: BlockCache and seal loader shared owner API, no owner implementation here.',
      exactness='All native per-layer admission/digest/CS checks and H-1 sealing still run; synthetic trace is not native proof equivalence.',
      privacy_soundness='P1 public weights only; fixed public subset. No witness/RNG/challenge/endpoint/opening cache; P3 private weights require separate review.',
      falsification='Native refusals/identity differ, constructor work not actually avoided, retention peak fails, or costs outweigh exclusive saved wall time.'),
 dict(rank=3,hypothesis='Owner: avoid measured repeated witness work with reviewed memory-bounded same-attempt retention/replay',
      baseline='R8 T128 sealing witness tasks80.897s, prove witness hand-over98.348s includes17.595s block reload; cache0 at8B.',
      eliminated_work='Only retained layers second witness builds, previously assessed suffix-replay boundary.',
      added_costs='Private retained payload/packing/readback/checksums and lifetime overlap.',
      expected_end_to_end_ceiling='Unmeasured saved witness subset; do not add nested/overlapped clocks.',
      prerequisites='Revisit prior cycle0016 result before any native port; realistic full peak and D29/H-1 preservation.',
      integration_cost='High native reader/lifetime work',exactness='All planes, deterministic output/refusals and original fold/finals must match.',
      privacy_soundness='Same-attempt only; no public private-cache metadata or randomness reuse.',
      falsification='Memory/copy costs exceed recomputation, changed refusal domain or joint privacy/proof mismatch.'),
 dict(rank=4,hypothesis='Owner: D30 dictionary/architecture under separately admitted profile',
      baseline='Unbuilt counted alternative, no speed result.',eliminated_work='Only independently reviewed constrained committed-plane/lookup work.',
      added_costs='Helper binding, rank/hiding, composition and calibration/fidelity gates.',expected_end_to_end_ceiling='Unknown',
      prerequisites='All D30 slot/cap/binding conditions; D32 float-fidelity target retained.',integration_cost='High',
      exactness='Exact division and every true-row slot constrained.',privacy_soundness='New soundness and joint-view gates, no D10/privacy weakening.',
      falsification='Unconstrained slot, late multiplicity, cap failure or failed soundness/privacy/fidelity gate.'),
 dict(rank=5,hypothesis='Tested/demoted: immutable CPU NTT and layout residency',
      baseline='Already1 NTT per run body,1 for both endpoints, monotonic GPU twiddle cache; sealing deduplicates layouts.',
      eliminated_work='CPU NTT2R->1 constructors in ideal fixed-context owner; layout base construction only if complete Shape key and fresh IO overlay.',
      added_costs='524560B T128 Fp backing payload retained across sealing; layout clone/overlay/key/ownership overhead unknown.',
      expected_end_to_end_ceiling='T/(T-s+a), s and a unisolated. No extra GPU upload removed. No measured speed gain.',
      prerequisites='Canonical field/domain/capacity key, context identity on device, full checked Shape; keep CS8 independently rebuilt and mutable row tamper refusals.',
      integration_cost='Moderate API split; no production patch.',exactness='24 public NTT fixtures,6 RS fixtures,full twiddle oracle and222 IO-site checks; no native admission.',
      privacy_soundness='No caching of masks, RNG, challenge-weighted values, endpoints, A/H/M or transcript.',
      falsification='Stale field/domain/capacity/Shape/site key, native mismatch or enclosing regression.'),
 dict(rank=6,hypothesis='ELIMINATED shortcuts: geometry-only calibration key; whole-stage Layout cached by Shape; partial LRU for cyclic full scan',
      baseline='Synthetic/source-backed controls fail shortcuts before integration.',eliminated_work='None authorized',added_costs='Incorrect constants/sites or zero hits.',
      expected_end_to_end_ceiling='No correct improvement established',prerequisites='A different design and new evidence required.',integration_cost='Reject unchanged designs',
      exactness='105 wrong synthetic stage maps; native31 base-shape layers have6 table-key combinations.',
      privacy_soundness='Boundary pair separation and layer/model binding remain mandatory.',falsification='Already falsified within stated synthetic scopes.')]
(E/'hypotheses.json').write_text(json.dumps(hypotheses,indent=2)+'\n')

boundaries=[
 dict(object='CPU NttTables',key='Compile/source/field-modulus/generator/representation/table-format identity plus capacity; immutable. No model or input key needed for this object.',lifetime='One endpoint-preparation scope and one run-body scope today; candidate process public owner.',retained_bytes_T128=524560,limits='Backing Fp elements only; no allocator/Vec header or Python-object claim.'),
 dict(object='GPU stage-major twiddles',key='Existing device owner and monotonic max_log in this fixed-field build; future backend/context generation/table-format identity if generalized.',lifetime='Already process resident under OnceLock/Mutex; never shrinks.',retained_bytes_T128=1048560,limits='No upload saving from new CPU cache; no GPU run.'),
 dict(object='Layout base',key='Complete checked native Shape (35 public fields) plus source/relation identity. Sole calibration key valid only within current sealing fixed-shape scope.',lifetime='Existing sealing calibration cache dropped at return; stage_layout rebuilds.',retained_bytes_T128=None,limits='Layout backing bytes and clone/overlay costs unmeasured. CS8 reconstruction stays.'),
 dict(object='Stage IO site overlay',key='Derive from validated RunStatement every use; incoming/outgoing rows and segment position are not interchangeable.',lifetime='Stage-local public overlay; internal incoming pair=data_rows+2, outgoing=data_rows.',retained_bytes_T128=None,limits='Do not reuse whole Layout by Shape alone.'),
 dict(object='Immutable P1 public layer block',key='Authenticated model/manifest/block digest/layer and geometry/table/RoPE/source identity; selected layer range controls run base and derived Shape.',lifetime='Current proving BlockCache holds one layer; candidate fixed pinned subset spans sealing and proving.',retained_bytes_T128=243411456,limits='Per layer exact backing payload. All32=7789166592B; no model bytes read/copied, no memory admission.'),
 dict(object='SealedChain/Witness/input-output boundaries',key='Input/attempt-specific; never part of immutable public context.',lifetime='Sealing then consume/rebuild in that attempt; H-1 refusals before header preserved.',retained_bytes_T128=None,limits='Prior same-attempt private replay is a different hypothesis.'),
 dict(object='Prepared endpoints/boundaries,A/H/M,RNG,transcript,challenge denominators',key='Fresh proof-local identity, not reusable public setup.',lifetime='Fresh per attempt/stage per existing protocol; owners consumed once.',retained_bytes_T128=None,limits='No new opening, mask or private randomness reuse authorized.')]
(E/'reuse-boundaries.json').write_text(json.dumps(boundaries,indent=2)+'\n')

clocktext=f'''Carried owner R8 CPU 8B diagnostic, T128 /32 blocks /one16-thread pass,
GPU off, n=1: total478.737s, diagnostic128/478.737={t['diagnostic_positions_per_second']:.6f}
positions/s. Prove_run393.785s includes witness hand-over98.348s, itself
including block loads17.595s. Sealing wall84.824s includes overlapping load
tasks27.151s and witness tasks80.897s. **The JSON load_seconds field is
seal.load_s only**, not all loads. These nested/overlapped clocks must not be
added. Receipt922711264B. Fresh verify42.709s plus initial load13.681s;
recheck34.395s plus load10.739s. Verification control time is separate from
the basic verify clock. Startup fraction, isolated serialization and steady
slope are unmeasured. Researcher did not reverify any receipt.'''
scope='''New target proofs/passes/positions **0/0/0**, device none. Target
steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No long prefill, resident proof series or
decode ran. Synthetic pass counts are constructor requests, not proved work.
Larger workloads remain allowed; attention may grow quadratically. Complete
private8B / >=50 proved positions/s on5090/named high-end GPU remains
unchanged/unachieved.'''
next_action='''Next local: build a public-only immutable-layer-owner trace with
synthetic contents and full model/manifest/layer/table identity, then test
fixed pinned admission against stale exports, layer-range/base changes,
cross-model swaps and peak lifetime overlap. Retain every native CS/H-1 check;
compare a streaming no-cache oracle. First derive where a retained Arc can
replace reconstruction at seal_and_record and BlockCache::get. Do not launch
a model build/proof or repeat the disproven partial-LRU policy. Owner request:
isolate public construction, CS rechecks, witness and serialization clocks,
then independently verify fixed-context resident1/2/4/8 workloads under locks.'''

readme=f'''# Public setup lifetimes across reviewed R8 sealing/proving

Cycle0084 — `{RUN}` — 2026-10-19 UTC.

**No speed improvement measured.** Source inspection rejects a supposed
per-layer NTT cost: the run already shares one table. GPU twiddle uploads are
already monotonic/process resident. Partial LRU also fails the ordered public
layer trace. A fixed public pinned subset remains a conditional owner candidate.

The experiment pins11 source files against the reviewed R8 manifest and4
public evidence files. Frozen tree7f64276abeceff666ff1269754bec83e0b0867b5d2812ae469bf76324d92ffb9.
R8 is soundness accepted by the review; no privacy acceptance inferred. No
production/model/private data were changed, read as a witness, or copied.

## Reproduced scope and negatives

- Main PASS:{r['checks']} checks,24 NTT fixtures (random/boundary/zero,
  sizes1..128),6 RS fixtures,all32768 forward/inverse capacity16 twiddles,
  222 IO allocation checks,35 descriptor-field mutations and13 controls.
  A direct big-integer Vandermonde/Horner reference checks every small output.
- Separate audit PASS:{a['checks']} checks,5 controls,24 direct monomial DFT
  comparisons and32 fresh norm-coefficient counterexamples. It imports no
  candidate code. Source/public clock/payload/site checks are independent.
- A shape-only whole-stage Layout cache gives105 wrong stage maps over the
  synthetic1/2/4/32-block cases atT32/64/128. Internal incoming starts at
  data_rows+2; outgoing atdata_rows. AtT128 those are34 and32. Always rebuild
  the stage overlay from the validated RunStatement. No native attack/proof
  or accepted changed Shape was tested.
- Geometry alone omits calibration. Full Shape is a Layout key, not a public
  table key: the real public R8 report's31 base-shape layers have6 distinct
  exp/SiLU key combinations. No private contents were inspected.
- Across72 synthetic public request schedules, LRU capacities1/4/16/31
  yield0hits when scanning32 layers repeatedly. A fixed public pinned4 gives
  60hits/512 requests for8 complete sealing/proving scan pairs. It retains
  973645824B=0.906778GiB backing payload; all32 need7789166592B=7.254227GiB.
  A per-block243411456B count includes padded FFN width16384, two norm vectors,
  RoPE i64 and256-entry tables. Ignoring FFN padding undercounts0.75GiB/stack.
  Counts allocate no real weights and are not RAM/VRAM admission or timings.
- T128 CPU NTT table payload524560B. Ideal fixed-context process owner2R->1
  constructors (16->1 atR8), not32R->1. Both external endpoints already share
  one constructor; the body shares one across all stages/boundaries. Existing
  GPU tables use1048560B backing and persist; this saves0additional uploads.

## Baseline, savings, costs and ceiling

Baseline is current separate sealing/proving public ownership. Remove only
actually avoided public loads/reconstruction and CPU table construction.
Add authenticated immutable ownership, complete object-specific keys,
retention/capacity/eviction, native CS rechecks and layout copy/IO overlays.
No witness/refusal, sumcheck, commitments, masking, serialization or verification
work is removed by calling it setup. Existing sealing layout deduplication
and every CS8 reconstruction remain.

Candidate end-to-end ceiling is not numerically identifiable:
T/(T-s+a), exclusive saved public work s and all new costs a unmeasured.
For orientation only, deleting **all**27.151+17.595s reported load tasks at
zero cost bounds this CPU diagnostic at{t['all_load_zero_cost_upper_speedup']:.6f}x;
overlap reduces the actual benefit. That is a generous load-only upper bound,
not the pinned4/NTT candidate's speed or a GPU forecast. The target needs
broad recurring-work improvement. Falsify on stale identity/site/calibration,
changed native refusals, private state in a public owner, failed receipt or
privacy gates, peak regression, or overhead >=exclusive saved wall time.

{clocktext}

## Interface and owner gates

Read source-census.json and reuse-boundaries.json. Actual seams:
private_block.rs:prepare_endpoints; run.rs:prove_run_with/stage_layout;
trained_block.rs:seal_and_record/BlockCache::get; Layout::check_is_for_shape.
No Rust/CUDA patch emitted. Layout does not currently offer this immutable
base/overlay API; implementing it needs owner review. CS8 independently
rebuilds mutable public row fields; caching must not silently skip it.
Keep fresh OS streams, endpoint roles, one-use owners, transcripts, original
PCS/finals, H-1 early refusals and independently verified complete receipts.
P3 private-weight reuse needs its own review. Main/Claude owns integration;
no merge or heavy/GPU work launched.

## Reproduction and retained evidence

`python3 -B {REL}/experiment.py`
`python3 -B {REL}/audit.py`

Exact argv/exit/stdout/stderr are in commands.json and*.log. Seed2026101984;
audit fresh seed2026101985. Main{r['wall_seconds']:.6f}s/{r['rss_kib']}KiB;
audit{a['wall_seconds']:.6f}s/{a['rss_kib']}KiB. One nice19 CoreUltra9 185H
CPU0,Python3.10.12,WSL2; each59s CPU/wall and512MiB AS,64MiB estimate.
No build,GPU,dependency install,Git or downloaded-code execution. Source
snapshots, pins, fixtures, exact payload/schedule ledgers and public-only
clock-event extraction retained. Initial CPU-only census retained separately;
later GPU-source inspection narrowed the claim; no failing harness run.

Seven LIVE primary records{source_before}->{source_after}; see search-log.md.
Newly assessed older cuZK, refreshed October StateSync/P3 releases and ICICLE
domain lifecycle. Pipelonk DOI/ACM403 and inaccessible Zenodo remain an
unassessed lead. Licenses/date/commit scope and fetch failures are explicit;
no author performance reproduced. Ranked queue in hypotheses.json.

{next_action}

{scope}
'''
(E/'README.md').write_text(readme)

handoff=f'''# Unapplied R8 public setup/residency handoff — 2026-10-19

**Conditional candidate, no measured speed gain.** Experiment:
[{REL}](../{REL}/README.md),run`{RUN}`. No Rust/CUDA patch or merge.

Interface: an immutable public layer-owner shared by seal_and_record and
BlockCache::get, with a fixed public pinned subset and streaming fallback.
Bind model approval identity, manifest SHA, actual block digest, layer,
geometry, per-layer exp/SiLU keys, RoPE mode and reviewed source format.
Authenticate cold contents and preserve every CS1/3/4/6/8/9 check and H-1
refusal ordering. Never carry witness/input-derived state through this owner.
Main/Claude reviews implementation in owned production lane under locks.

The source's ordered32-layer trace thrashes every partial LRU tested;
pinned4 gives60/512 request hits over8 scan pairs at0.906778GiB public payload.
All32 public padded blocks need7.254227GiB before proof buffers. These are
synthetic request/count results, not native load savings or GPU fit.

Smaller seam: pass one canonical immutable NttTables owner through
prepare_endpoints and prove_run_with. T128 payload524560B,ideal2R->1 CPU
constructors; device twiddles already cached,0extra uploads removed. Public
field/representation/domain/capacity key suffices for this object. Preserve
frozen-seam exact-domain refusal as well as generalized-endpoint capacity rules.

Do not cache a whole stage Layout by Shape: internal incoming/outgoing IO
rows differ. Split full checked Shape/source keyed public base from per-use
RunStatement-derived IO overlay; preserve CS8 fresh rebuild/tamper checks.
Layout-only full Shape key cannot identify public layer tables. API is not
implemented and clone/overlay/layout bytes are unmeasured.

Validation:{r['checks']} checks/13 controls; separate{a['checks']}-check audit/
5 controls. Exact small-field outputs and public source/payload/site evidence,
not native Shape/admission/fold/final/transcript/receipt/privacy equivalence.
No masks,RNG,challenge denominators,A/H/M,prepared endpoints/boundaries or
private openings reused. Freshness and joint privacy gates remain required.

{clocktext}

Exclusive public construction and CS recheck clocks are missing. Candidate
ceiling unknown. Zero-cost removal of all reported load tasks gives only
{t['all_load_zero_cost_upper_speedup']:.6f}x on this CPU diagnostic and overstates
wall saving where tasks overlap. Reject if saved construction <=key/ownership/
retention/transfer cost, peak fails, or any identity/refusal/privacy/proof
gate differs. Whole-prover GPU and independently verified resident1/2/4/8
workloads outrank NTT/layout micro-optimization.

{next_action}
'''
(R/'handoffs/20261019-public-setup-lifetimes.md').write_text(handoff)

progress=f'''# ZKP efficiency progress

Cycle0084 — `{RUN}` — 2026-10-19 UTC.

**No speed improvement measured.** The reviewed R8 source already shares
NTT tables across blocks and caches GPU twiddle uploads. Public setup reuse
has a narrower scope than per-layer costs would suggest.

The bounded experiment rejects partial LRU for repeated ordered32-layer
scans: capacities1..31 give0hits. Fixed public pinned4 gives60/512 synthetic
request hits at8passes,retaining0.907GiB payload; all32 need7.254GiB before
proof buffers. A Shape-only whole-stage layout cache also uses wrong boundary
mask rows; its per-stage IO overlay must be rebuilt. No native cache/proof
or speed comparison was run.

PASS:{r['checks']} source/public-field/site/schedule checks,13 controls;
independent audit{a['checks']} checks/5 controls. Main/audit
{r['wall_seconds']:.3f}/{a['wall_seconds']:.3f}s,peak{max(r['rss_kib'],a['rss_kib'])}KiB,
one nice19 CoreUltra9 185H CPU core. Seven LIVE records append
{source_before}->{source_after}; recent StateSync/P3 and ICICLE plus older
cuZK; Pipelonk full-text/artifact access blocked. No external gain reproduced.

{clocktext}

Seam:shared immutable public owner between seal_and_record and BlockCache::get,
with complete identity and unchanged CS/H-1 gates. Native clocks/memory and
proof/privacy tests remain blocked on owner work. Next:public-only pinned-owner
trace with stale-key/identity/peak controls; owner verified resident1/2/4/8
GPU passes remain first. [Experiment]({REL}/README.md),
[handoff](handoffs/20261019-public-setup-lifetimes.md),
[dated report](progress/{RUN}.md).

{scope}
Only research files written; no runtime/production/Git/receipt/calibration/
safety/instruction/reviewer changes. Saved reports do not establish delivery.
'''
(R/'PROGRESS.md').write_text(progress)
(R/'progress'/f'{RUN}.md').write_text(progress+f'\nCheckpoint UTC:{now}.\n\n'+next_action+'\n')
finding=f'''\n\n## Cycle0084 — 2026-10-19 — public setup lifetime and partial-LRU negatives

Run`{RUN}`. **No speed improvement measured.** Read/pinned11 reviewed R8
sources and4 public evidence files. NTT is already shared across all blocks;
one other construction serves both external endpoints. Device twiddles are
already monotonic/process resident. Ideal CPU public owner2R->1 constructions
retains524560B atT128;0additional GPU uploads removed. Sealing already
deduplicates layouts by full calibration within fixed shape; CS8 independently
rebuilds each caller-provided layout and cannot silently be cached away.

Whole-stage layout caching by Shape fails105 synthetic stage maps over
1/2/4/32 blocks,T32/64/128; incoming/outgoing internal pairs begin at34/32
atT128. Use full checked Shape for public Layout base and freshly derive IO
overlay from RunStatement. Geometry omits calibration; full Shape also does
not identify a layer's public tables:31 real public R8 base-shape layers use
6 exp/SiLU key combinations. No native Shape/admission or exploit test.

72 public request traces: partial LRU capacity1/4/16/31 has0hits across
ordered32-layer scans. Fixed public pinned4 yields60/512 hits over8 sealing/
proving scan pairs. Retained4 payload973645824B=0.906778GiB; per block
243411456B,all32=7789166592B=7.254227GiB. Padded FFN16384 (true14336)
matters: dropping padding undercounts0.75GiB/stack. Allocation-free public
counts only,no model bytes retained,no actual peak/DRAM/runtime or GPU fit.

PASS:{r['checks']} checks,24 random/boundary/zero NTT fixtures,6 RS fixtures,
32768 full-capacity twiddles,222 IO-site checks,35 descriptor mutations,
13 controls. Separate audit{a['checks']} checks/5 controls,24 direct monomial
DFTs and32 fresh norm-coefficient counterexamples;no candidate import.
Main{r['wall_seconds']:.6f}s/{r['rss_kib']}KiB,audit{a['wall_seconds']:.6f}s/
{a['rss_kib']}KiB,one nice19 CoreUltra9 185H CPU0,Python3.10.12,WSL2;
59s CPU/wall/512MiB AS caps,64MiB estimate. No build/GPU/install/foreign
execution. Initial CPU-only census preserved; later GPU-source inspection
narrowed scope,no failing harness. Fifteen source/evidence pins rechecked.

{clocktext}

Baseline/eliminated/added/ceiling: remove only truly avoided immutable public
construction/reloads; add authenticated complete keys,fixed retention,
eviction/peak and layout copy/overlay costs. No per-input sealing/witness,
refusal,sumcheck,masking,commitment,serialization or verification removed.
Candidate ceiling T/(T-s+a),s/a unisolated. Deleting all reported load tasks
at zero cost gives only{t['all_load_zero_cost_upper_speedup']:.6f}x on this CPU
diagnostic; overlap makes this optimistic,not a pinned4/NTT/GPU forecast.
Falsify stale identity/calibration/site,private dependence,gate mismatch,
peak failure or no enclosing gain.

Ranked:(1)owner whole-prover GPU+verified resident1/2/4/8;(2)NEW fixed public
pinned owner,partial LRU rejected;(3)owner reviewed bounded same-attempt
witness retention,prior cycle0016 limits retained;(4)owner D30 architecture;
(5)CPU NTT/layout residency demoted;(6)stale keys/partialLRU eliminated.
Full hypotheses and prerequisites/exactness/privacy/cost criteria saved.
[Experiment]({REL}/README.md),[unapplied handoff](handoffs/20261019-public-setup-lifetimes.md).
Seams seal_and_record/BlockCache::get and prepare_endpoints/prove_run_with;
no native patch. All owner admission,CS/H-1,fresh role-separated OS streams,
PCS/finals,receipt and joint privacy gates remain. No opening/mask reuse.

Seven LIVE records{source_before}->{source_after}: current October StateSync
paper/release,P3 rc2,ICICLE domain lifecycle,and newly assessed older cuZK
paper/author repo. Inspected88e3295cada379abe06240df23ec6c9fc0f648b2 is a
README-only historical change. Date/license scope qualified. Pipelonk
DOI/ACM403,Zenodo inaccessible,license/commit fetch failures retained;lead
unassessed,no external performance reproduced. Rotation batching/public
setup->lookup/softmax catalogs->quantization/arithmetic/composition; retain
NTT/commitments,sumcheck/GKR,memory.

{next_action}

{scope}
Only research files written;runtime/production/Git/receipts/calibration/
safety/instructions/reviewer files untouched. Saved reports do not prove
message delivery.
'''
findings=R/'FINDINGS.md'
assert findings.read_bytes().startswith((E/'startup/FINDINGS.md').read_bytes())
if f'## Cycle0084 —' not in findings.read_text():
    with findings.open('a') as f:f.write(finding)
state=f'''# ZKP efficiency explorer — durable state

Cycle0084 COMPLETE:`{RUN}`,2026-10-19 UTC.
Next cycle no earlier than **17:18:54 UTC**. Deadline16:38:54 UTC.
[Dated report](progress/{RUN}.md).
Startup memory:{REL}/startup/.

**No speed improvement measured.** NTT already shared across blocks and GPU
uploads already cached. Candidate CPU table owner removes2R->1 constructs
only;T128 backing524560B,no extra device upload avoided. CS8 and sealing
layout deduplication retained. Whole-stage Shape-only cache fails IO rows;
incoming/outgoing internal starts34/32 atT128. Full Shape !=public layer key:
31 real public base-shape layers have6 distinct table-key combinations.

NEW public residency result: partial LRU1..31 layers thrashes repeated ordered
32-layer scans (0hits). Fixed public pinned4 gives60/512 synthetic request
hits at8passes,0.906778GiB payload. Per block243411456B,all32=7.254227GiB
before proof buffers. Unpadding FFN undercounts0.75GiB. No native cache or
actual load/peak/runtime gain; source/cost policy handoff only.

Main PASS{r['checks']} checks/13 controls,24 NTT+6RS fixtures,32768twiddles,
222IO checks,35 Shape descriptor mutations. Independent audit{a['checks']}/
5controls,24DFTs+32new coefficients. Main/audit{r['wall_seconds']:.3f}/
{a['wall_seconds']:.3f}s,peak{max(r['rss_kib'],a['rss_kib'])}KiB,one nice19 CPU0,
CoreUltra9 185H,Python3.10.12,WSL2;59s/512MiB caps. Fifteen pins recheck,
11sources match reviewed R8 manifest. No build/GPU/install/foreign execution.
[Handoff](handoffs/20261019-public-setup-lifetimes.md). Main/Claude integrates;
no Rust/CUDA patch or merge. Native CS/H-1/fresh RNG/endpoint/PCS/finals/
receipt/joint privacy gates still required. R8 soundness accepted;not privacy.

Ranked hypotheses (full {REL}/hypotheses.json):
1.Owner whole-prover GPU+independently verified fixed-context resident1/2/4/8.
2.New fixed public pinned owner across sealing/proving;complete model/manifest/
layer/table/geometry identity,immutable bytes and honest peak/copy accounting.
3.Owner bounded same-attempt witness retention;prior cycle0016 negatives stand.
4.Owner D30 architecture,all gates/D32 fidelity retained.
5.CPU NTT/layout residency demoted;clocks unisolated.
6.Geometry-only/whole-stage Shape keys and partial LRU eliminated in tested scope.

{next_action}

{clocktext}

Seven LIVE records{source_before}->{source_after};older cuZK newly assessed;
StateSync/P3 October updates,ICICLE lifecycle refreshed. Historical inspected
cuZK88e3295... README-only;actual license fetch failures qualified. Pipelonk
403/Zenodo access blocker,no bypass. No external gains reproduced.

{scope}
Only research files written;runtime/production/Git/receipts/calibration/
safety/instructions/reviewer files untouched. Saved reports do not imply
message delivery. Checkpoint{now}.
'''
(R/'STATE.md').write_text(state)
print(json.dumps(dict(reports='written',source_records_before=source_before,source_records_after=source_after,checkpoint=now)))
