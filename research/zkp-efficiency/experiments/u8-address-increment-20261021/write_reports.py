from pathlib import Path
import datetime, hashlib, json, platform

E=Path(__file__).resolve().parent
W=E.parent.parent
RUN='20261021T051854Z-3d9d2756'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((E/'result.json').read_text())
a=json.loads((E/'source-audit-result.json').read_text())
cost=json.loads((E/'cost-result.json').read_text())
cpu=next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown')
hardware=dict(cpu=cpu,kernel=platform.release(),threads=1,gpu_invoked=False,
              estimated_experiment_memory_mib=64,address_space_limit_mib=256)
(E/'hardware.json').write_text(json.dumps(hardware,indent=2)+'\n')
measurement=dict(proofs=0,passes=0,positions=0,actual_model_context=None,actual_accelerator=None,
                 research_device=cpu,worker_threads=1,witness_s=None,proof_s=None,
                 serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,
                 steady_rate=None,total_workload_rate=None,long_context_prefill=False,
                 resident_model_proof_series=False,decode=False,
                 counted_geometries=[128,512],counted_T512_profile_admitted=False)
(E/'target-accounting.json').write_text(json.dumps(measurement,indent=2)+'\n')
scope=f'''New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one {cpu}
CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, repeated resident-model proof passes or decode ran.
T128/T512 are symbolic geometries; T512 is unregistered counted-only, not an
admitted workload. Longer workloads remain allowed; increasing context can
increase attention work quadratically. The complete private8B >=50 proved
tokens/s target on RTX5090 or another named high-end GPU remains unachieved.
'''
table='''| Counted 8B geometry | Native U8 helper data MiB | Dense factored d4/d8 data GiB | Virtual-complement bits GiB |
|---|---:|---:|---:|
'''
for x in cost:
    if x['d']==4:
        table+=f"| T{x['T']} {'DD' if x['dd'] else 'nonDD'}{' counted-only' if x['T']==512 else ''} | {x['native_u8_helper_data_bytes']/2**20:.2f} | {x['dense_data_bytes']/2**30:.6f} | {x['virtual_complement_bit_data_bytes']/2**30:.6f} |\n"
finding=f'''## Cycle 0121 — ordered U8 one-hot contracts and dense PCS negative, 2026-10-21

Run `{RUN}`. Checkpoint UTC:{now}. AGENDA and required durable/project
files read and snapshotted. Prior10,319 findings lines/760source records preserved;
13primary records append->773. All34 hypotheses retained; rank25 materially
refined/tested, owner top-four unchanged. Latest MVP status adds a media-app demo
whose classifier labels remain a stand-in; it does not amend this lane's private8B
target. Current LOW/HIGH fidelity layouts are excluded from this frozenR9 census.

**No proving improvement measured.** The exact diagnostic contracts pass
**{r['checks']} checks**, with128ordered synthetic sources,512factored fixtures,
128virtual-complement fixtures and48dense MLE cases. There are
{r['negative_control_types']}control types. Independent direct-index/dense-matrix
reference imports no candidate code; it was written by this researcher, not an
external reviewer. Separate source audit passes{a['checks']}checks,19fragment
mutations and6live/copy pins. No native build, proof or privacy experiment ran.

Useful negative: native U8H pairs two looked inverses in oneFp2 helper. Direct
one-hot factors atd1/2/4/8 require256/32/16/16 base words per query; onlyd nonzeros
do not make native dense row encoding/hashing sparse. AtT128nonDD the smallest
tested dense factor variant is6.19140625GiB versus420.25MiB original U8H,
**15.086258x** logical DATA. Virtualizing complementary entries [1-b,b] leaves
8bit words per query,3.095703125GiB,**7.543129x**. These are selected layouts,
not universal lower bounds on private/sparse protocols, actual capacity, DRAM
traffic, proof size or runtime. Encoded payload multiplies by frozen rate4;
masks/padding/trees/scratch/other owners remain excluded and cannot be set tozero.

{table}

The compact event contract checks ordered public site keys against synthetic
original-source values, increments repeated-address counts and compares the final
histogram. Drop/duplicate/out-of-range, stale increments and tampered histograms
refuse. A histogram-preserving query permutation is accepted by histogram-only
checking, but refused by the ordered source link. One-hot Booleanity/sum alone
also fails to bind original order. A linear sum/address check without Booleanity
admitsq256 via a non-Boolean row. In characteristic251,252ones pass a modular
sum-one/address check; this caveat does not affect the native Goldilocks contract.
Read-only U8 lookup does NOT require the extra increment trace: it is a control
contract, not mandatory Shout cost or an implementation of Twist.

The factored/sparse/bit MLE evaluators agree with dense sums. Additional control:
at a non-Boolean time point, multiplying separate factor MLEs disagrees with the
MLE of their row-wise product (d2/4/8). Thus a private virtualization reduction
cannot be silently omitted. Evaluating a single fixed point can miss a changed
query; the diagnostic evaluator supplies no succinct input consistency or proof.

Native seam: frozenR9 `protocol.rs::u8_denominator_inverses/write_h`,
`layout.rs::lookups_at`, `argument.rs::helper_sum/SC_TAB`; dense PCS path
`core-pcs.rs::encode_row_zk/commit_zk_owned_with_tag`. A thenM precede alpha;
every row receives fresh pads and every encoded column receives fresh salt.
Native denominators/table/refusal/nonU8 relations and fresh masks cannot simply
be deleted. New private commitment/mask-site/PCS-group counts remain **null**:
no private protocol exists to price them. No numeric GPU ceiling follows.

Baseline: frozen normwindow32/fE9/fP9/DDcap32. Potential eliminated work: gross
recurring U8H data processing only, under a complete reviewed replacement; native
work eliminated this cycle:none. Added costs: new private representation,
Booleanity, ordered affine source links, virtualization/reduction claims,
fresh masks/CFS/PCS, all refusals, encoding and launches. If unknownf is the
exclusive removable elapsed fraction, free deletion gives at most1/(1-f)
before added costs. Reject any changed source/order/MLE/range/refusal/privacy,
unresolved binding, or slower enclosing verified full workload. The selected
dense layouts already fail a logical-byte improvement condition.

Rank1 remains complete high-endGPU/verified resident1/2/4/8 clocks; rank2 larger
admitted-context DD with cheapest passing fidelity; rank3 actual private phase/
capacity telemetry; rank4 native all-elevenFZC A/B. Their prerequisites and
obligations remain in hypotheses.json. Rank25 direct dense hashing is demoted;
sparse/private virtualization is unresolved rather than disproved universally.

Nine LIVE queries plus primary opens/clicks cover Twist/Shout October17 revision,
current Jolt architecture/backend privacy, Logup*, Atlas, Chimera and NTT/GPU
release filters. Newly assessed older Shout tensor and Twist write-value
virtualization explain the additional reduction and why read-only cost should
not include a mandatory counter-memory proof. Current Jolt BlindFold docs say
Akita lacksZK; lattice performance is no private-proof evidence. RootMIT/Apache
license bodies inspected; no crate-specific audit/fullcommit inferred. Tag
fd3ffb6 abbreviated only; release year unknown. PDF403/timeout, inaccessibleAPI
and cache misses retained; no bypass. Author performance/security not reproduced.

Probe/source diagnostic clocks:{r['wall_seconds']:.6f}/{a['wall_seconds']:.6f}s;
RSS{r['rss_kib']}/{a['rss_kib']}KiB. Seed202610210121;oneCPU/nice19,
30sCPU/alarm,35sparent,256MiBAS,estimated64MiB. Model-sized arrays never
allocated. Initial successful sensitivity-inclusive accounting preserved under
initial-with-labelled-parameter-sensitivities; final census selects32/fE9 only.
Later successful refinements add complement,DDsite and MLE-product controls;
commands.jsonl retains every pass. Clocks measure research checking only.

{scope}

Next local: inspect the actual affine byte/symmetric/scaled descriptor catalog;
can one source-bound bit decomposition serve multiple affine U8 queries without
weakening symmetric endpoints, scaled top bits, padding support or refusals?
Independently enumerate tiny signed/scaled domains and count distinct source
bitplanes, then all new private claims/masks before considering a patch. Do not
repeat dense one-hot storage or assume private commitments reusable. Owner next
remains complete GPU phase/capacity clocks and verified fixed-context resident
1/2/4/8 under shared heavy/build locks. Interface/cost review note:
`handoffs/20261021-u8-onehot-contract.md`. Main/Claude reviews; no merge.
Only research outside runtime written; no production/Git/receipt/calibration/
instruction/reviewer edits,GPU,build,install,downloaded-codeexecution,external
write/message,purchase or escalation. Saved reports do not establish delivery.
'''
readme=f'''# U8 ordered one-hot address/increment contracts — cycle0121

Run `{RUN}`. **No proving speedup measured.** The diagnostic passes
{r['checks']}checks/512factor fixtures/128complement fixtures/48dense MLE cases;
{r['negative_control_types']}control types. Source audit:{a['checks']}checks,
6pinned native files. These are independent reference implementations authored
here, not an external review or native prover.

The selected native-hashing transplant fails the DATA-byte test. Native U8H
pairs two inverse columns perFp2. Factoring a256-way onehot row into d1/2/4/8
parts costs256/32/16/16 basewords per query. Virtual complementary bit entries
reduce this to8words, still7.54x original U8H at frozen8B T128nonDD. Nonzero
counts alone do not reduce dense PCS encoded payload. No general sparse/private
lower bound is claimed and no actual memory peak or runtime is measured.

{table}

`candidate.py::check_factors/check_bits/check_events` are direct validators of
synthetic witnesses. `reference.py` independently indexes tables and expands
dense matrices; no imports from candidate. `sparse_mle/factored_mle/bits_mle`
match explicit dense sums. A product of factor MLEs at a nonBoolean time differs
from the MLE of the product: a reviewed private reduction remains necessary.
Histogram-only and source-unlinked one-hot checks admit reordered queries.
The event/increment trace is an optional diagnostic, not mandatory for read-only
Shout. No commitments, masks, transcript, native refusal, PCS, receipt or verifier.

See [cost-result.json](cost-result.json), [source-anchors.json](source-anchors.json),
[ranked queue](hypotheses.json) and [owner review note](../../handoffs/20261021-u8-onehot-contract.md).
Source hashes/commands/seed/hardware retained. Unknown mask/commitment/group costs
are null, never zero. Baseline excludes newer fidelity LOW/HIGH layouts.

Reproduce sequentially from research root:

```text
python3 experiments/u8-address-increment-20261021/run_bounded.py probe.py
python3 experiments/u8-address-increment-20261021/run_bounded.py source_audit.py
python3 experiments/u8-address-increment-20261021/run_bounded.py artifact_audit.py
```

Seed202610210121,oneCPU/nice19,30sCPU/alarm,35sparent,256MiBAS,
64MiB estimate. Probe/source audit {r['wall_seconds']:.6f}/{a['wall_seconds']:.6f}s,
RSS{r['rss_kib']}/{a['rss_kib']}KiB on {cpu}. These are script clocks.
Artifact auditing requires the retained final manifest/reports and checks the
append-only prefixes and independent logical/native-anchor formulas.

Search: [Twist/Shout](https://eprint.iacr.org/2025/105) revised2026-10-17;
[JoltBook virtualization](https://jolt.a16zcrypto.com/how/twist-shout.html);
[current privacy boundary](https://jolt.a16zcrypto.com/how/blindfold.html).
Akita docs currently excludeZK; no announced lattice speed is a private8B result.
Other searched primary URLs/dates/licenses/fetch failures are in13source records.
Nine LIVE queries; no foreign code executed or upstream performance reproduced.

{scope}

Next: original affine-source sharing census with exact symmetric/scaled/support
refusal controls before any bitplane protocol. Top owner priorities unchanged.
Free-deletion ceiling1/(1-f),unknownf,precedes all added private proof costs.
Only research written; main/Claude reviews and integrates; no merge.
'''
(E/'README.md').write_text(readme)
handoff=f'''# Owner review note: avoid direct dense one-hot U8 transplant

Cycle0121 `{RUN}` — {now}. **Negative cost result; no native patch.**

`experiments/u8-address-increment-20261021/candidate.py` exposes synthetic
`check_factors(source,witness,d)`, `check_bits(source,witness)`,
`check_events(source,events,histogram)` and three equivalent MLE evaluators.
`source` is an ordered list of((domain,column,row),canonicalFieldValue), not a
published witness. Supported domains includeDd. All data here are synthetic.
This interface is reviewable contract evidence, not a private proof adapter.

Validation:{r['checks']}checks,512factor/128complement fixtures,48dense MLE
cases,51controls; source/order audit51checks/6pins. Independent reference by
same researcher; no external review. Seed202610210121;oneCPU,under2seconds
final diagnostic,estimated64MiB. Logs and hashes retained. No build/GPU.

FrozenR9 seams and exact anchors are in source-manifest/anchors.json:
- protocol.rs:u8_denominator_inverses, paired helper loop/write_h; A/M beforealpha.
- layout.rs:lookups_at owns byte/symmetric/scaled affine source obligations.
- argument.rs:helper_sum andSC_TAB own reciprocal/global histogram relations.
- zkp-core pcs.rs:encode_row_zk andcommit_zk_owned_with_tag draw freshpads/salts,
  encode every dense row and hash all encoded columns in the selected host path.

Native U8H already uses two base coordinates per paired query-column group.
Direct d4/d8 factor data costs6.19140625GiB at8B T128nonDD versus420.25MiB
original U8H; virtual complement bitplanes3.095703125GiB. These15.086x/7.543x
DATA ratios reject only these layouts as logical-byte improvements. Do not
substitute sparse nonzero counts for actual dense encoded capacity/work.
Other owners, padding,masks/PCS/scratch and actual device capacity are omitted.
T512 is counted-only/unregistered. New LOW/HIGH fidelity shapes are excluded.

Obligations: bind every ordered affine original-A source and padding support;
Booleanity/range/symmetric endpoints/scaled top bits; private virtualization
sumcheck and its claims; fresh masking/PCS/CFS/current whole-run soundness;
retain native nonU8/table/denominator refusal policy unless a new relation is
explicitly reviewed. New private commitment/mask/group counts are unknown,
not zero. All current privacy gates are owed for any new protocol.

Controls: same histogram permits wrong order; one-hot without source link also
permits it; sum/address without Booleanity permitsq256; characteristic251 admits
252hot rows (not native field); product of factor MLEs at a nonBoolean time is
wrong. A single fixed-point evaluator is no source-binding proof. Counter
increments are a diagnostic contract; read-only Shout does not require them.
Current Jolt docs sayAkita lacksZK, so lattice benchmark claims do not validate
this private target. No unmasked traces/roots should enter public receipts.

Next local: count shared original affine sources, independently enumerate exact
byte/symmetric/scaled ranges and support, and price distinct bitplanes/private
claims. Reject any binding/refusal/privacy drift or enclosing workload regression.
Owner next: complete GPU exclusive/enclosing clocks, actualcapacity, verified
resident1/2/4/8. Amdahl free-deletion ceiling<=1/(1-f),unknownf,before addedcosts.
Main/Claude reviews/integrates; no merge or permission to launch heavy jobs.

{scope}
'''
(W/'handoffs/20261021-u8-onehot-contract.md').write_text(handoff)
old_findings=(E/'startup/research__zkp-efficiency__FINDINGS.md').read_text()
assert (W/'FINDINGS.md').read_text()==old_findings
with (W/'FINDINGS.md').open('a') as f:f.write('\n\n'+finding)
(W/'progress'/f'{RUN}.md').write_text(finding)
progress=f'''# ZKP efficiency progress

Cycle0121 complete — `{RUN}` — 2026-10-21 UTC.

**No proving speedup measured.** Ordered U8 one-hot contracts pass{r['checks']}
synthetic checks,512factor/128complement fixtures,48dense MLE cases and51control
types. Source/order audit51checks/6pins. Direct dense factor data costs15.09x
native paired U8H at frozen8B T128; deriving complementary bit entries still
costs7.54x. This rejects those storage layouts, not all sparse/private protocols.
Histogram-only and product-of-factor-MLE shortcuts fail controls. No native proof.

All34 hypotheses retained; rank25 refined/demoted, owner topfour unchanged.
Nine LIVE queries/13primary records appended. Newly inspected Shout virtualization
needs an extra reduction; currentJolt Akita docs lackZK. No author rate reproduced.

{scope}

Next: exact affine-source sharing census for byte/symmetric/scaled U8 checks;
charge fresh private claims/masks. Owner GPU phases/capacity and verified fixed-
context resident1/2/4/8 remain first. No masks/openings reused.

[Experiment](experiments/u8-address-increment-20261021/README.md),
[dated report](progress/{RUN}.md),
[owner note](handoffs/20261021-u8-onehot-contract.md).
Saved reports do not establish delivered messages or supervisor liveness.
'''
(W/'PROGRESS.md').write_text(progress)
state=f'''# ZKP efficiency explorer — durable state

Cycle0121 COMPLETE: `{RUN}`. Checkpoint UTC:{now}.
Started05:18:54UTC;deadline05:38:54UTC. Next cycle no earlier than2026-10-21T06:18:54Z.
AGENDA read at startup and checkpoint. Required files/latest0120 results read.
Startup:experiments/u8-address-increment-20261021/startup/. Preserved10,319prior
findings lines/760sources;13append->773. All34hypotheses retained;rank25 refined.

No proving improvement measured. One-hot contract:{r['checks']}checks,
128ordered syntheticsources,512factorfixtures,128complementfixtures,48denseMLE
cases,51controltypes. Source/order audit51checks/6pins. Independent reference
authored here,not externalreview. Final script clocks{r['wall_seconds']:.6f}/
{a['wall_seconds']:.6f}s,RSS{r['rss_kib']}/{a['rss_kib']}KiB. OneCPU/nice19,
seed202610210121,30sCPU/alarm,35sparent,256MiBAS,64MiBestimate. No native/GPU.

NativeU8H pairs two inverse columns/Fp2. Dense d1/2/4/8 costs256/32/16/16
basewords/query. Smallest tested factorDATA6.19140625GiB vs420.25MiB U8H at
frozen8B T128nonDD (15.086258x). Virtual complements8bitwords/query yield
3.095703125GiB (7.543129x). These selected dense layouts are rejected for
logical-byte gain; not all sparse/private protocols. Native hashPCS encodes
dense rows with fresh pads/salts. No numeric time/peak/GPU ceiling follows.

Histogram-only permits wrongorder; Booleanity/source/range/increments controls
fire. Product of factorMLEs at nonBoolean time differs from productMLE,so
private reduction cannot be skipped. Read-onlyShout needs no diagnostic count
increments; do not charge them as mandatory. Commitments/masks/PCSgroups/CFS
unresolved,null rather thanzero; originalsource/refusal/privacy obligations stay.

Topfour: fullGPU+verifiedresident1/2/4/8; larger-contextDD+cheapestpassingfidelity;
privatephase/capacitytelemetry; nativeall-elevenFZC A/B. Scratchpool stillparked.
D41/classifierapp and05:00stand-in demo do not amend private8B target. Current
LOW/HIGH layouts are outside frozenR9 normwindow32/fE9/fP9/DDcap32 census.

{scope}

Next local: rank25 actuallayout affinebyte/symmetric/scaled source catalog.
Ask whether one source-bound bit decomposition can serve relatedqueries without
weakening signedendpoints,scaledtopbits,paddingsupport or refusals. Independent
tiny signed/scaled enumeration,distinctbitplane accounting,and every new private
claim/mask before any native patch. Do not repeat naive dense onehot storage.
Owner next: completeGPU exclusive/enclosing phases,actualcapacity and verified
fixedcontext resident1/2/4/8 under shared heavy/build locks.

NineLIVEqueries/13primaryrecords. Twist/Shout Oct17; newlyassessedolderShout
tensor/Twistwv virtualization; currentJolt docsAkita lacksZK. RootMIT/Apache
licensesinspected; nofullcommit,tagfd3ffb6 onlyabbreviated,releaseyearunknown.
PDF403/timeout,APIinaccessible/cachemiss retained; no bypass/upstreamreproduction.

Carried historical nonDD8B T128,L32,one16threadCPU pass,GPUoff,total478.737s
=0.267370positions/s;prove_run393.785s includeswitness98.348s/load17.595s;
seal84.824s overlaps. Receipt922711264B. Freshverify42.709s+load13.681s;
recheck34.395s+load10.739s. Startupfraction/isolatedserialization/steadyslope
unknown. Not rerun/reverified here; not a highendGPU baseline.

Review note:handoffs/20261021-u8-onehot-contract.md. Main/Claude reviews and
integrates; no merge. Only research outside runtime written; no production/Git/
receipt/calibration/instruction/reviewer changes,build,GPU,install,externalwrite/
message,purchase or escalation. Saved reports do not establish delivery/liveness.
'''
(W/'STATE.md').write_text(state)
(E/'checkpoint-updates.json').write_text(json.dumps(dict(run_id=RUN,checkpoint_utc=now,
    result_checks=r['checks'],sources_before=760,sources_after=773,hypotheses=34),indent=2)+'\n')
print(json.dumps(dict(run_id=RUN,checkpoint=now,checks=r['checks'],source_records=13)))
