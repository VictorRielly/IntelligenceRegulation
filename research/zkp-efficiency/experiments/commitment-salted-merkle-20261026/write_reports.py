"""Research-only durable checkpoint. Prior findings/sources remain prefixes."""
from pathlib import Path
import datetime,json
E=Path(__file__).resolve().parent;R=E.parent.parent
run='20261026T172925Z-dd337876';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((E/'result.json').read_text());audit=json.loads((E/'audit-result.json').read_text())
clock=f"Model {result['diagnostic_wall_seconds']:.6f}s / {result['rss_kib']:,}KiB RSS; audit {audit['diagnostic_wall_seconds']:.6f}s / {audit['rss_kib']:,}KiB RSS."
target=dict(run_id=run,new_completed_independently_verified_full_stack_proofs=0,new_completed_passes=0,new_proved_positions=0,
            actual_model_context=None,device='One Intel Core Ultra9 185H CPU worker; no accelerator',device_count=0,
            witness_seconds=None,proof_seconds=None,serialization_seconds=None,verification_seconds=None,
            startup_seconds=None,initial_prefill_seconds=None,startup_fraction=None,proof_latency_seconds=None,proof_bytes=None,
            steady_state_positions_per_second=None,total_workload_positions_per_second=None,
            long_context_prefill_run=False,resident_model_proof_passes=0,decode_run=False,
            counted_geometries='FrozenR9 nonDD/DD T128/T512 A/H only; T512 unregistered; LOW/HIGH excluded',
            target_achieved=False,private_masks_reused=False,
            historical_baseline=dict(scope='Carried prior CPU8B T128/L32 nonDD; not rerun/reverified this cycle; noGPU/8Bprivacy acceptance',passes=1,positions=128,threads=16,gpu=False,total_s=478.737,total_positions_per_s=128/478.737,prove_run_s=393.785,witness_within_prove_run_s=98.348,load_within_prove_run_s=17.595,seal_overlapping_s=84.824,receipt_bytes=922711264,fresh_verify_s=42.709,fresh_verify_load_s=13.681,recheck_s=34.395,recheck_load_s=10.739,startup_fraction=None,serialization_s=None,steady_state_positions_per_s=None))
(E/'target-accounting.json').write_text(json.dumps(target,indent=2)+'\n')
body=f'''Cycle0125 — {run} — {now}

No proving speedup measured. The synthetic CPU model fuses salted-leaf construction
with the first Merkle parent level while retaining every salted leaf and every
internal node. It matches the installed independent BLAKE3 implementation in
**{result['checks']:,} checks, {result['fixtures']} cases, all {result['path_positions']:,} paths and {result['control_types']} control types**.
Both the model and the separate reference-tree/path code were authored by this
researcher; the cryptographic implementation is independently implemented installed
Python blake3 1.0.9. The separate interval/cost/source audit passes **{audit['checks']:,}
checks**, twelve explicit tree sizes up to2048 leaves, {audit['source_pins']} source pins and five
accounting controls. {clock} These are diagnostic clocks, not proof clocks.
Every leaf command uses one-core affinity, nice19,30sCPU/alarm,35s parent timeout,
256MiB address-space limit and64MiB estimated experiment memory.

For N encoded columns, baseline salting costs N BLAKE3 compressions and the external
binary tree N-1. These are **ordinary64-byte BLAKE3 messages**, flags CHUNK_START|
CHUNK_END|ROOT, plus KEYED_HASH under a tagged role; using BLAKE3's internal PARENT
mode is wrong and is caught. Native COLUMN, LEAF and NODE keys remain distinct;
fresh salts, their RNG draw order and all pads/masks stay unchanged. There is no
cross-proof private reuse. Fresh synthetic salts change the root as expected.

For N>=2, fusion removes exactly32N logical bytes of leaf reloads and one parallel
pass boundary. It removes **zero compressions, zero stored tree bytes and zero
required path entries**. The stored tree is32*(2N-1) bytes. Logical host salt+tree
reads/writes change from192N-96 to160N-96 bytes, before library/compiler/task costs;
these are source-level counts, not DRAM or cache measurements. N=1 has no saving.

| FrozenR9 one A or H commitment | Encoded columns | Logical reads avoided | Retained tree |
|---|---:|---:|---:|
|T128 nonDD/DD|65,536|2MiB|4MiB-32B|
|T512 nonDD/DD|131,072|4MiB|8MiB-32B|

Only A/H geometry is counted, not M/endpoints/token stages or the LOW/HIGH fidelity
profiles. T512 is not an admitted trained profile. Per-column BLAKE3 compression
count is ceil(rows/8)+ceil(rows/128)-1; salted leaves+external nodes are only
0.136%–0.457% of total hash compressions across these eight geometries. CPU/GPU
placement differs, so this ratio is **not an elapsed-time fraction**.

Two useful negative findings constrain integration. First, naive safe zero-filled
salted and first-parent buffers add48N logical writes, more than the32N reloads
avoided. The uncompiled Rust candidate instead uses indexed Rayon
unzip_into_vecs and Vec::into_flattened (stable1.80) to fill two outputs and reuse
the pair allocation. Current local Rayon1.12 and standard-library sources were
inspected and pinned. Compiler codegen, task width (three hashes per pair),
register/cache pressure and actual capacities remain unmeasured. Second, moving
salting+the entire tree to GPU while keeping today's host tree.path contract
downloads32*(2N-1) tree bytes and uploads32N salt bytes, versus today's32N digest
download. This adds64N-32 combined transfer bytes:4MiB-32B atT128 or8MiB-32B
atT512 per commitment. This comparison assumes all current host tree levels are
returned; device-resident path gathering would be a separate API/lifetime design.
A root-only frontier cannot replace retained levels without charged regeneration
or retained-device paths after transcript queries. No root-only speed claim.

Integration seam: active ops/zkp-mvp/gpu-zerocheck/zkp-core/src/pcs.rs::
commit_zk_owned_with_tag -> MerkleTree::build_salted_keyed in merkle.rs. The
source-pinned salt-first-parent.patch adds the helper and replaces one tagged
commit callsite, leaving existing entrypoint bodies intact. It is **unapplied and
uncompiled**. The existing backend still returns its unsalted Vec<Digest>; no GPU
hook changes. Internal helper shape checks apply to generated valid arrays only;
native failure/refusal equivalence, RNG, all roots/paths, complete receipt bytes,
fresh independent verification, current privacy gates and owner review remain owed.

End-to-end ceiling: if f is the unknown truly removable critical-path fraction,
even free deletion is bounded by1/(1-f), before added costs. No numerical complete
GPU speed forecast follows. Falsify on any digest/node/path/key/flag/order/RNG/
receipt/refusal/privacy mismatch, implicit clears/copies/reloads erasing savings,
absent native incidence, or a slower enclosing independently verified workload.
All37 previous ranked hypotheses are retained;36/37 refined and38 added. The
whole-prover GPU,resident1/2/4/8,DD-context and exclusive-FZC owner priorities stay
above this bounded continuation. Hash micro-optimizations are parked for clocks.

Ten LIVE search queries and primary open/find/click inspection yielded eight
source records (including partial/inaccessible leads). The newly assessed older
merklize-blake3 README separates kernel and transfer costs and requires>=2^20
leaves; GitHub verifies its2023-01-13 archive date, while publication/update/commit
and license-body/code inspection are unavailable (cache misses). cuPQC's April9
article has the wrong hash/field for substitution. Chimera's October16 revision
charges complete Spartan proving. The new IOPP2026/391 screen is HVZK for a
different protocol and gives no license to remove native masking. ICICLEv4.0.0
version commit6c77775961b0e4dc2be359feec1ac11536c18043 and MIT license body were
inspected; release year is not exposed. A same-day turboblake1.8.7 date is from
primary registry search metadata only; direct code/license/commit access failed,
so its CLI compatibility and performance are unverified. BLAKE3's1.8.7 release
date is now verified as2026-08-20 from the primary crate page, resolving prior
unknown-year records without altering them. FlatMerkle's primary URL failed;
mirror claims are not credited. No author benchmark reproduced, foreign code
executed, dependency installed, or access blocker bypassed.

New completed, independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. Device: one Intel
Core Ultra9 185H CPU worker. Witness/proof/serialization/verification clocks,
startup and initial-prefill duration, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain authorized;
attention can grow quadratically with context. The complete private8B >=50 proved
tokens/s target on RTX5090 or a named high-end GPU remains unachieved.

Carried historical baseline, not rerun/reverified: nonDD8B T128/L32, one16-thread
CPU pass, GPUoff,total478.737s=0.267370positions/s;prove_run393.785s includes
witness98.348s/load17.595s. Seal84.824s overlaps, not additive. Receipt922711264B;
freshverify42.709s+load13.681s;recheck34.395s+load10.739s. Startup fraction,
isolatedserialization and steady slope unknown. No high-endGPU or8B privacy claim.

Next owner action: measure column-hash completion,D2H,salt,first-level,upper-tree
and path-gather exposed clocks with enclosing commitment and whole verified pass;
then the fixed-context resident1/2/4/8 sweep under shared build/heavy locks. Test
this patch only if a material removable salt/first-level fraction exists.
Next local action rotates to sumcheck/GKR: pin the five native slot constructors
and audit which public-shape preprocessing is repeated per proof versus already
resident, preserving fresh CFS masks/challenges. First consult prior metadata
and fraction-tree negatives; avoid rediscovering existing caches. Record removed
public work and added staging, and gate any native timing behind owner locks.

Only research outside runtime written; no production/Git/receipt/calibration/
instruction/reviewer mutation, native build,GPU,install,external write/message,
purchase or escalation. Main/Claude reviews and integrates; no merge here.
Saved reports are not evidence of user-message delivery or supervisor liveness.
'''
(E/'README.md').write_text('# Salted Merkle first-level fusion — CPU model and cost census\n\n'+body+'\nReproduce from the research directory:\n\n```sh\npython3 experiments/commitment-salted-merkle-20261026/run_bounded.py probe.py\npython3 experiments/commitment-salted-merkle-20261026/run_bounded.py audit.py\n```\n')
dated=R/'progress'/f'{run}.md';dated.write_text('# ZKP efficiency cycle report\n\n'+body)
prior=(E/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
f=R/'FINDINGS.md';assert f.read_bytes()==prior
with f.open('a') as out:out.write('\n## Cycle0125 — salted Merkle fusion: exact model, small counts and transfer negative\n\n'+body)
handoff=f'''# Salted Merkle fusion — review candidate, parked for native clocks

Run `{run}`, {now}. No native proving speedup measured.

Interface and location: add `MerkleTree::build_salted_keyed(&[Digest], &[Digest],
Option<&Digest>, Option<&Digest>) -> MerkleTree` in active GPU lane core merkle.rs;
replace the salting/build pair in core pcs.rs::commit_zk_owned_with_tag. Patch:
`../experiments/commitment-salted-merkle-20261026/salt-first-parent.patch`.
It is unapplied/uncompiled. Python model is not a Rust/CUDA implementation.

Validation: {result['checks']:,} checks,120syntheticcases/all3825paths/17controls against
installed independent blake3; separate interval/source/cost audit{audit['checks']:,}
checks/12pins/5controls. One core;{clock}
Model uses64-byte message flags, never internal PARENT. Correct role keys and all
stored leaves/levels/path bytes are mandatory. Native RNG schedule is untouched
in the patch, but no native byte/refusal/privacy equivalence has been established.

Counted benefit:2MiB(T128) or4MiB(T512) logical reloads per frozenR9 A/Hcommit;
no hashes or retained bytes removed. No LOW/HIGH profile count or peak/rate claim.
Added paired-task/dependency/compiler/cache costs can exceed saving. Initialized
output buffers lose; candidate uses indexed-unzip and zero-copy array flattening
as established in pinned local library source (Rust>=1.80); actual codegen untested.
GPU full-tree offload is a transfer negative with current host paths; root-only
hash timing omits opening obligations. No privacy/mask reuse is authorized.

Before promotion: native leaf/node/all-path byte parity for keyed+legacy tags,
one-leaf/boundary cases, wrong-role/flag/path controls, same RNG/tamper/refusal,
full receipts+fresh independent verification and current profile privacy gates.
Review panic/allocation/failure behavior, inspect no extra clears/copies/reloads,
and measure instrumentation-off/on plus exclusive hash/D2H/salt/firstlevel/upper/
paths and enclosing complete verified workload under shared build/heavy locks.
If f is unknown removable time fraction, no numeric speed forecast is justified;
even free deletion <=1/(1-f). Falsify on parity/privacy drift or enclosing regression.

Priority: park until native clocks show useful incidence. Preserve higher-priority
whole-prover GPU,DDcontext and FZC accounting work. Main/Claude reviews/integrates;
this research lane does not merge. See the experiment README and dated report.
'''
(R/'handoffs/20261026-salted-merkle-fusion.md').write_text(handoff)
short=f'''# ZKP efficiency progress

Cycle0125 complete — `{run}` — 2026-10-26 UTC.

**No proving speedup measured.** A CPU model preserves keyed/unkeyed salted Merkle
roots, every stored node and all3,825paths while fusing leaf salting and first
parents. It passes19,952checks/120cases/17controls against installed independent
BLAKE3; separate cost/source audit passes{audit['checks']:,}checks/12pins. {clock}

The counted saving is2MiB(T128) or4MiB(T512) logical reads per frozenR9 A/Hcommit.
No hash or retained tree bytes disappear. Naive zero-filled outputs erase the
saving. GPU full-tree offload adds transfers with today's host paths. An
uncompiled,unapplied Rust patch/handoff is saved and parked pending native clocks.
Ten LIVE queries produced eight source records; all37prior hypotheses retained,
two refined,one added. Whole-prover GPU and verified resident sweeps remain first.

New verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model
context / accelerator: **none**; one Intel Core Ultra9 185H CPU worker. Witness,
proof,serialization,verification/startup/initial-prefill clocks,startup fraction,
proof latency/bytes,steady-state and total-workload rates: **unmeasured**.
No long-context prefill,resident-model proof series or decode ran. T128/T512 are
geometry counts only; T512 unregistered,LOW/HIGH excluded. Larger workloads remain
allowed; attention can grow quadratically. Private8B >=50 proved tokens/s on a
named high-endGPU remains unachieved.

Next owner: exposed salt/tree/path/transfer clocks and verified resident1/2/4/8
workloads under shared locks. Next local: sumcheck/GKR public-preprocessing
incidence census, consulting prior cache and fraction-tree negatives first.

[Experiment](experiments/commitment-salted-merkle-20261026/README.md),
[dated report](progress/{run}.md),
[handoff](handoffs/20261026-salted-merkle-fusion.md).
Saved reports do not establish message delivery or supervisor liveness.
'''
(R/'PROGRESS.md').write_text(short)
state=f'''# ZKP efficiency explorer — durable state

Cycle0125 COMPLETE: `{run}`. CheckpointUTC:{now}.
Started17:29:26UTC; harddeadline17:49:26UTC; nextcycle no earlier than18:29:26UTC.
AGENDA/required durable memory and prior state/findings/all799sources snapshotted
under experiments/commitment-salted-merkle-20261026/startup/. Prior evidence kept.

No proving gain. Keyed/unkeyed salted-leaf/first-parent fusion model passes
19,952checks/120cases/all3,825paths/17controls against installed independent
blake31.0.9; separate interval/cost/source audit{audit['checks']:,}checks/12pins/5controls.
{clock} One core,nice19,30sCPU/alarm,35s timeout,256MiBAS,64MiBestimate.

Ncolumns: Nsalt+(N-1)nodecompressions unchanged; fulltree32*(2N-1) bytes retained.
Fusion removes32Nlogical readbytes,2/4MiBper countedT128/T512AorHcommitment.
Naive cleared outputs add48Nwrites, erasing saving. Unapplied,uncompiled Rust
salt-first-parent.patch uses indexedunzip/Vec::into_flattened, owner gates owed.
GPU fulltree+salts adds64N-32 transferbytes versus currentdigestdownload with
hosttree.path. Root-onlyfrontier omits later paths. No elapsed/peak benefit known.
Eightprimarysourcerecords from10LIVEqueries; all37hypotheses preserved,36/37refined,
38added. Hashmicro-optimizations parked pending native exclusive/enclosing clocks.
No nativebuild/GPU/proof/install/Git/externalmessage/production/runtime write.

New completed independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context / accelerator: **none**. Device:one Intel
CoreUltra9 185H CPU worker. Witness/proof/serialization/verification/startup/
initial-prefill clocks,startupfraction,prooflatency/bytes,steady-state and
total-workload rates: **unmeasured**. No long-contextprefill,residentmodelpass
series or decode. T128/T512 frozenR9counts only;T512unregistered,LOW/HIGHexcluded.
Larger workloads allowed; attention can growquadratically. Private8B >=50proved
tokens/s on RTX5090 or a namedhigh-endGPU remains unachieved.

Next local: rotate sumcheck/GKR. Pin five native slot constructors and identify
public-shape preprocessing repeated perproof versus already cached; consult
prior metadata/fractiontree negatives first. Preserve every fresh CFS mask,
challenge,opening and refusal. Differential-test one narrow eligible seam.
Owner next: actual hash/D2H/salt/firstlevel/upper/path exposed clocks, native
patch byte/receipt/failure/privacy gates only if useful; completeGPUclocked,
independently verified fixed-context resident1/2/4/8 under sharedbuild/heavylocks.
Handoff:handoffs/20261026-salted-merkle-fusion.md. Main/Claude integrates,no merge.

Historical baseline not rerun/reverified: nonDD8B T128/L32,one16threadCPUpass,
GPUoff,total478.737s=0.267370positions/s;prove_run393.785s includeswitness98.348s/
load17.595s;seal84.824s overlaps. Receipt922711264B;freshverify42.709s+load13.681s;
recheck34.395s+load10.739s. Startupfraction,serialization,steady slope unknown.
No high-endGPU or8B privacy acceptance. CurrentD33/D36 remain narrow CPU
TinyLlama; D37–D41applicationdirection does not replace this8B researchtarget.
Saved reports do not establish message delivery/liveness. Final audit follows.
'''
(R/'STATE.md').write_text(state)
(E/'completion.json').write_text(json.dumps(dict(status='COMPLETE_RESEARCH_CYCLE_NO_PROVING_GAIN',run_id=run,checkpoint_utc=now,experiment='commitment-salted-merkle-20261026',no_native_build=True,no_gpu=True,no_external_writes=True),indent=2)+'\n')
print('Saved STATE,PROGRESS,FINDINGS append,dated report,handoff,README,target accounting at',now)
