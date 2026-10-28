#!/usr/bin/env python3
"""Checkpoint cycle 0083; only research-owned outputs, old prefixes preserved."""
import datetime
import json
from pathlib import Path

H = Path(__file__).resolve().parent
R = H.parent.parent
RUN = '20261019T151854Z-4f2eec2a'
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(name, obj):
    (H/name).write_text(json.dumps(obj, indent=2)+'\n')


def main():
    r = json.loads((H/'result.json').read_text())
    a = json.loads((H/'audit-result.json').read_text())
    assert r['status'] == a['status'] == 'PASS'
    save('hypotheses.json', [
      dict(rank=1, hypothesis='Owner: whole-prover GPU D/A and independently verified resident 1/2/4/8 passes',
           expected_end_to_end_impact='Broad recurring scope; no measured GPU saving or steady slope.',
           prerequisites='Admitted profile, named high-end device, shared heavy locks and owner-run complete proofs.',
           integration_cost='High: device arithmetic, layouts, transfer/lifetime/PCS and phase instrumentation.',
           exactness='Same field, relations, masks, degree, refusals and original folds/finals.',
           privacy_soundness='Fresh masks/openings per proof; independent verification; all recurring work and pipeline drain counted.',
           falsification='Enclosing regression, proof backlog, failed verification or privacy gate.'),
      dict(rank=2, hypothesis='Refined: immutable public setup reuse across R8 sealing/restart and resident passes',
           expected_end_to_end_impact='Remove only repeated immutable public construction/load/reencoding. Cost and lifetime census first; total ceiling unknown.',
           baseline='Current per-input sealing plus restarted proving, with per-layer calibration/manifest binding. Witness and sealing are recurring, not public startup.',
           eliminated_work='Only source-identified repeated public setup; retain all witness/refusal work and fresh proof-local scalars.',
           added_costs='Complete cache keys, identity checks, retained bytes, eviction/reload and transfer/peak overlap.',
           prerequisites='Read/hash reviewed R8 constructors and StackSource call sites; distinguish run base, layer identity, override and proof-local lifetime.',
           integration_cost='Small local source/cost census, moderate owner cache integration if useful duplication exists.',
           exactness='No altered plane list, field, calibration/refusals or stale per-layer parameters.',
           privacy_soundness='Immutable public data only; no witness, mask, challenge, private opening or transcript reuse. D29 refusal-before-header stays.',
           falsification='No repeated immutable construction, a missing key component, private dependence, higher peak cost or no verified workload gain.',
           next_local='Produce a public-vs-attempt-vs-layer lifetime ledger and synthetic stale-key controls; no build or model data.'),
      dict(rank=3, hypothesis='Owner: D30 dictionary and proof architecture comparison',
           expected_end_to_end_impact='Broader committed-plane/lookup scope; counted/unbuilt, no performance forecast.',
           prerequisites='Separately versioned profile, all D30 slot/cap/binding conditions, independent written-relation review and calibration census.',
           integration_cost='High: layout, relation, commitment, rank/hiding and composition work.',
           exactness='Exact division; every true-row slot constrained; accepted float-fidelity direction D32 remains.',
           privacy_soundness='New NL-1/blinding/joint captures and independent verification; no relaxed D10 or privacy requirement.',
           falsification='Unconstrained slots, late multiplicities, missing helper sum claim, cap overflow or failed privacy/fidelity/soundness gate.'),
      dict(rank=4, hypothesis='Tested narrow option: parameter/base translations retaining raw and scratch maps',
           expected_end_to_end_impact='At most removes198 logical index bytes/row from shared9162; no field work removed, no runtime/DRAM result. Low priority.',
           baseline='Shared10 templates/19 calls/884 field primitives; previous shared CPU timing loss retained.',
           eliminated_work='99 u16 parameter/base index requests; all raw and scratch maps retained.',
           added_costs='18 nonzero typed pointer adjustments; compiler/stack/register costs unknown.',
           prerequisites='Reviewed lowering, effective load bounds, native sampler/parameter binding and enclosing proof gates.',
           integration_cost='Moderate emitter change; no new kernel emitted this cycle.',
           exactness='2888 symbolic checks and33 synthetic fixtures support exact addresses/values on the captured graph; original59 tables/folds/finals retained.',
           privacy_soundness='Public topology only; rebind proof-local parameters at every layer/attempt; no additional opening or private randomness reuse.',
           falsification='Invalid effective address/alias, native coefficient/final/transcript/RNG mismatch, no resource benefit or enclosing regression.'),
      dict(rank=5, hypothesis='ELIMINATED: single raw-pointer shift per repeated helper',
           expected_end_to_end_impact='Incorrect; do not implement.',
           evidence='All9 non-reference instances nonuniform. Minimum raw translation groups2 and3. Full naive candidate can exceed118 endpoints; in-bounds first error changes24/24 random fixtures.',
           prerequisites='Would need a different multi-pointer/general-map hypothesis and new cost justification.',
           integration_cost='Rejected before lowering.', exactness='Fails exact source address mapping.',
           privacy_soundness='Changing checked endpoints is not authorized.',
           falsification='Already falsified by source lineage and numerical controls.')])
    accounting = json.loads((H/'prior-target-accounting.json').read_text())
    accounting['run_id'] = RUN
    accounting['synthetic_experiment'] = dict(
        kind='Public address census and arbitrary synthetic Fp2 values, not a full proof',
        seed=r['seed'], raw_fp2_endpoints=118, proof_local_fp2_parameters=129,
        canonical_base_parameters=36, coefficients=5, dag_nodes=1167,
        catalog_origin='Prior captured public D graph; no new admitted profile/context exercised',
        fixtures=33, native_field_scalar_oracle_fixtures=36,
        original_tables=59, whole_D_folds_finals_tested_this_cycle=False,
        wall_seconds=r['wall_seconds'], audit_seconds=a['wall_seconds'],
        rss_kib=r['rss_kib'], audit_rss_kib=a['rss_kib'], device=r['cpu_model'],
        cpu_affinity=[0], threads=1, model_passes=0, full_stack_proofs=0,
        tokens=0, context_tokens=None, lowered_kernel_runtime_seconds=None,
        physical_DRAM_bytes=None, proposed_index_byte_reduction=198)
    accounting['carried_evidence_pin_recheck']='All20 source and evidence hashes match; receipts not reverified by this researcher.'
    save('target-accounting.json', accounting)
    (H/'audit.log').write_text((H/'audit-result.json').read_text())
    save('execution-notes.json', dict(
      run_id=RUN, command_sequence=[
       'python3 experiments/dzc-affine-address-census-20261019/run.py',
       'python3 experiments/dzc-affine-address-census-20261019/audit.py',
       'python3 experiments/dzc-affine-address-census-20261019/record_sources.py',
       'python3 experiments/dzc-affine-address-census-20261019/checkpoint.py',
       'python3 experiments/dzc-affine-address-census-20261019/validate.py'],
      seeds=dict(main=2026101983, native_field_audit=2026101984),
      initial_failures='initial-harness-failure.txt retains both safe assertions and corrections',
      field='Goldilocks p=2^64-2^32+1;Fp2[u]/(u^2-7)',
      estimated_experiment_memory_mib=64, enforced_address_space_mib=512,
      one_thread=True, nice=19, cpu_wall_limit_seconds=59,
      heavy_builds=0, gpu_jobs=0, installed_dependencies=0, foreign_code_executed=False,
      oracle='Own prior research binary/source, hash matched to prior manifest; no new compile.',
      incorrect_read_paths='Initial searches for zkp-core/src/private_block/argument.rs and flat private_stack/stack_source.rs found no file; actual hashline/private_block seam located read-only.',
      touched_scope='Only research directory excluding runtime. No production/Git/receipts/calibration/safety/instruction/reviewer writes or external messages.'))
    progress = f'''# ZKP efficiency progress

Cycle 0083 — `{RUN}`, 2026-10-19 UTC.

**No speed improvement found.** A single shifted raw pointer is incorrect in
all nine repeated non-reference D helpers. The two helper families need at
least two and three raw pointer groups. This shortcut is rejected.

A narrower parameter/base translation passes 2,888 address checks and 33
synthetic fixtures. It could remove 198 logical index bytes per row, adding
18 pointer shifts; no lowered kernel, DRAM or runtime gain was measured.
A separate 187-check audit and 36-fixture native-field scalar comparison
(180 coefficients) pass. Main/audit: 0.254/0.098 s, peak 20,532 KiB RSS,
one nice-19 Core Ultra 9 185H CPU core. No build or GPU work.

Seven LIVE primary-source records append 448→455: MLIR/Polygeist address
legality, BatchZK scheduling, and refreshed sumcheck/zkLLMPoT sources. Dates,
license/commit scope and fetch failures are retained; no external gain was
reproduced. [Experiment](experiments/dzc-affine-address-census-20261019/README.md),
[handoff](handoffs/20261019-dzc-affine-address-census.md),
[dated report](progress/{RUN}.md).

Seam: `SC_DZC` / `SumcheckRounds`; partial address plan only, no production
patch. Helper tuning is demoted. Next local action: classify immutable public
setup lifetimes across R8 sealing/restart with complete per-layer cache keys.
Owner whole-prover GPU and verified resident 1/2/4/8 passes remain first.

Carried CPU 8B diagnostic: T128, 32 blocks, one 16-thread pass, GPU off;
471.580 s total; proof region 370.137 s includes witness 94.021 s and loading
17.408 s; sealing 101.279 s; D 44.833 s. Fresh verification 34.587+load
11.599 s. Serialization, startup fraction and steady slope unisolated.
Delete-all-D ceiling only 1.105058× on that diagnostic; no receipt reverified
here.

New target proofs / passes / positions **0 / 0 / 0**, device none. Target
context, steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No prefill, resident series or decode ran.
Larger workloads remain allowed; attention may grow quadratically. The
complete private 8B / ≥50 proved positions/s GPU target is unchanged and
unachieved. Saved reports do not establish message delivery.
'''
    (R/'PROGRESS.md').write_text(progress)
    findings = f'''

## Cycle 0083 — 2026-10-19 — single raw-pointer translation falsified

Run `{RUN}`. **No speed improvement found.** The two repeated D
helper families do not admit one uniform raw-pointer translation: all nine
non-reference instances fail exact source-address equality. Family 3 needs
two raw pointer groups, family 6 three (including a group-14 exception).
E.g. `[18,19,20,21,88,89]` becomes `[22,23,24,25,90,91]`, requiring shifts
`[4,4,4,4,2,2]`. The full naive proposal can request slot124 from118
endpoints; no invalid pointer was executed. Stop this lowering. This is not
a rejection of general affine maps or a multi-pointer alternative.

Partial parameter/base translation is exact on the captured graph. Retain
raw and scratch maps; remove only77+22 u16 index requests=198 logical
bytes/row (634→436 map bytes), add18 nonzero typed pointer shifts with the
same helper arguments. Proposed shared row requests9162→8964 (2.16%);
scalar4320 and unique8528 remain historical. No field work removed:
same1167-node DAG,884 primitives,59 original tables/folds/finals,208B
scratch. No lowered kernel, code/stack/runtime or physical DRAM measurement.
Previous negative grouped CPU timing stands; partial option is low priority.

PASS:2888 symbolic checks,33 arbitrary synthetic fixtures (24 random,
8 boundary,1 zero),165 coefficients per candidate arm,seed2026101983,
8 controls. Wrong in-bounds raw shift changes24/24 random and7/8 boundary
fixtures; zero values conceal it. Independent audit187 checks/3 controls
derives source matrices/minimal groups/byte costs and compares36 new fixtures,
180 coefficients to the retained own-research scalar native-field oracle.
Oracle source/binary match prior artifact manifest. Wrong extension polynomial
breaks35/36 fixtures. No new whole-D/catalog/native profile/fold/final/proof
or privacy gate. Two initial safe harness/control assertions and corrections
retained. All20 carried source/evidence pins recheck.

Main0.254043s/18980KiB; audit0.098289s/20532KiB. One nice19 Core Ultra9
185H CPU0,Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps,64MiB estimate.
No build,GPU,install or foreign execution. Native field oracle reused prior
rustc1.97.1/LLVM22.1.6 binary; no new compiler benchmark.
[Experiment](experiments/dzc-affine-address-census-20261019/README.md),
[unapplied handoff](handoffs/20261019-dzc-affine-address-census.md).
Native seam SC_DZC / SumcheckRounds; research translated_plan/partial JSON
could feed the previous grouping emitter. Fresh parameter/alpha/g_u8 binding,
native admission/RNG/refusals,masked extension/PCS/finals,independent receipt
verification,joint privacy and enclosing clocks remain owner gates. No new
opening or mask reuse. Main/Claude reviews integration; no production patch.

Baseline/eliminated/added/ceiling: shared maps versus99 fewer index requests,
18 added pointer shifts; no arithmetic/proof cost removed. Candidate
end-to-end gain unknown. Carried R6/b7 8B CPU T128,32 blocks,one16-thread
pass,GPUoff:471.580s total,proof370.137 includes witness94.021/load17.408,
sealing101.279,D44.833,receipt922711264B. Delete-all-D ceiling1.105058×,
0.271428→0.299944 diagnostic positions/s only; strict-subset candidate
cannot claim that gain. Fresh verify34.587+load11.599,recheck32.311+9.903.
Serialization,startup fraction,steady slope unisolated; sealing is recurring
input work. Researcher did not reverify receipts. T32 next-token clocks kept
separate in target-accounting.json.

Ranked queue:(1) owner whole-prover GPU D/A + verified resident1/2/4/8;
(2) refined immutable public setup lifecycle across R8 sealing/restart,
with full layer/calibration/manifest keys;(3) owner D30 dictionary, separate
unbuilt profile;(4) tested partial parameter/base translation,low priority;
(5) uniform raw translation,ELIMINATED. Full cost/prerequisite/exactness/
privacy/falsification criteria in hypotheses.json. D32 fidelity direction
and pending numeric thresholds stand. Next local: source-only public setup
lifetime ledger and synthetic stale-key controls. Prior witness-suffix replay
and its memory limits are known; do not relabel sealing as startup.

Seven LIVE primary records448→455: new MLIR,older Polygeist legality paper/
repository,older BatchZK scheduling; refreshed known super-sumcheck,
efficient-sumcheck and recent zkLLMPoT v2. Verified dates/license scope,
inspected Polygeist77c04bb2a7a2406ca9480bcc9e729b07d2c8d077 (ctz builtins,
not this optimization),cached-history limits and InternalError/Cache miss
retained. No current HEAD inferred from crawl dates; no external gain
reproduced. Rotation public setup/batching,then NTT/commitments,lookup/
softmax,quantization and composition; retain sumcheck/GKR and memory.

New target proofs/passes/positions0/0/0,device none. Target context,
steady/total rates,startup fraction,witness/proof/serialization/verification
unmeasured. No long prefill,resident series or decode; larger workloads
allowed,attention may grow quadratically. Complete private8B≥50 proved
positions/s GPU target unchanged/unachieved. Only research files written;
no runtime,production,Git,receipts,calibration,safety,instruction or reviewer
writes. Saved reports do not establish delivery.
'''
    old = (H/'startup/FINDINGS.md').read_text()
    current = (R/'FINDINGS.md').read_text()
    assert current in (old, old+findings), 'Unexpected findings changes; preserve and review.'
    if current == old:
        with (R/'FINDINGS.md').open('a') as f:
            f.write(findings)
    dated = progress.replace('(experiments/', '(../experiments/').replace('(handoffs/', '(../handoffs/').replace('(progress/', '(') + '''
The raw-pointer shortcut is disproved before lowering. The small remaining
option changes address-index work only. No end-to-end estimate is justified;
the carried delete-all-D ceiling is deliberately optimistic for a much
broader phase than this candidate. Initial harness failures and all negative
controls are retained rather than hidden.

The independent field oracle is the prior research scalar coefficient kernel,
not an actual native proof verifier. This cycle tests arbitrary synthetic
field arrays rather than new admitted TinyLlama/Llama profile witnesses.
All 59 tables/folds/finals are structurally preserved, but those operations
were not newly executed or reverified as a proof here.

Current R8 soundness review was read: eleven per-layer constants use one
checked door and may not move the plane list. Cached public setup must bind
the full identity and per-layer calibration. No privacy acceptance follows.
The source-only next experiment must first show which public work actually
repeats; prior lossless suffix-witness reuse is already known and memory
limited, and is not authorization to cache masks/openings or write private
witness material to disk.

Blockers/unknowns: no authorized GPU or heavy benchmark in this lane;
whole-prover device clocks, startup partition, resident slope, serialization,
physical memory traffic and lowered partial-kernel costs remain absent.
Several web commit/license/release/PDF fetches returned InternalError or
Cache miss; exact URLs and evidence limits are retained. No approval-dependent
command, network bypass or installation was attempted.

Source assessments: [search notes](../experiments/dzc-affine-address-census-20261019/search-notes.md).
Commands, seeds, dimensions, machine and source hashes are retained in the
experiment; artifact validation is recorded separately. The main agent/Claude
must review any integration. This local report is not an external message.
'''
    (R/'progress'/f'{RUN}.md').write_text(dated)
    state = f'''# ZKP efficiency explorer — durable state

Cycle 0083 COMPLETE: `{RUN}`, 2026-10-19 UTC.
Next cycle no earlier than **16:18:54 UTC**. Deadline 15:38:54 UTC.
[Dated report](progress/{RUN}.md).
Startup memory: `experiments/dzc-affine-address-census-20261019/startup/`.

**No speed improvement found. Uniform raw-pointer translation is falsified**
in all9 non-reference helper instances. Families need2 and3 raw pointer
groups. Partial parameter/base translations preserve raw/scratch maps:
could remove198 logical index bytes/row (634→436), add18 pointer shifts,
no extra helper arguments. Proposed shared logical bytes9162→8964;
scalar4320/unique8528 historical. No lowered kernel, measured runtime,
code/stack or physical DRAM result. Prior shared timing loss stands.
Same1167-node graph/884 field primitives/59 tables/folds/finals/208B scratch.

PASS:2888 symbolic checks;33 synthetic fixtures/165 coefficients per arm,
seed2026101983,8 controls. Wrong raw shift changes24/24 random,7/8 boundary;
zero values conceal it. Independent audit187 checks/3 controls,36 fixtures/
180 coefficients vs prior own-research native-field scalar oracle. No new
whole-D/catalog/fold/final/proof/privacy gate. Two initial safe harness/control
assertions and fixes retained. All20 source/evidence pins recheck.
Main0.254043s/18980KiB,audit0.098289s/20532KiB;one nice19 CoreUltra9 185H
CPU0,Python3.10.12,WSL2,59s/512MiB caps;no build/GPU/install/foreign execution.

Seam: SC_DZC / SumcheckRounds; `translated_plan` and partial JSON can guide
the prior grouping emitter. ABI118 Fp2 endpoints,129 proof-local Fp2 params,
36 canonical u64 params,five coefficients. Native admission/challenges/
alpha/g_u8,per-layer freshness,RNG/refusals,masks,PCS/finals,receipt/tamper,
joint privacy and enclosing clocks remain owner gates. No extra opening or
private randomness reuse. [Handoff](handoffs/20261019-dzc-affine-address-census.md).
Main/Claude owns integration;no production patch or merge.

Ranked queue (full hypotheses.json in this experiment):

1. Owner whole-prover GPU D/A plus independently verified fixed-context
   resident passes1/2/4/8; charge transfers,PCS,serialization and drain.
2. Refined immutable public setup across R8 sealing/restart. Source/cost census
   first; cache keys must bind complete identity/layer calibration. No witness,
   challenge,mask/opening or transcript reuse. Falsify no repeated immutable
   work,stale keys,private dependence,peak regression or no verified gain.
3. Owner D30 dictionary/architecture, separate unbuilt profile and all
   soundness/hiding/composition gates. D32 float-fidelity target stands.
4. Tested partial parameter/base translation,low priority;198 index bytes only.
5. Single raw-pointer shift ELIMINATED; do not reimplement unchanged.

NEXT LOCAL: read/hash reviewed R8 source and classify public setup constructors
and StackSource sealing/restart lifetimes; produce exact key/lifetime/retained-
byte ledger plus synthetic stale-key controls. Native R8 is soundness-accepted
(review verdict read),not privacy-accepted. Prior suffix witness replay and
long-context memory limits already assessed in cycle0016; do not rediscover
or relabel input-dependent sealing as startup. No GPU/build run authorized.
Rotation: public setup/batching,next NTT/commitments,lookup/softmax,
quantization/arithmetic,composition; retain sumcheck/GKR/memory.

Carried R6/b7 CPU8B diagnostic:T128,32blocks,one16-thread pass,GPUoff;
471.580s total,proof370.137 includes witness94.021/load17.408;seal101.279,
D44.833,receipt922711264B. Delete-all-D ceiling1.105058×,
0.271428→0.299944 diagnostic positions/s only; candidate strict subset,
gain unknown. Fresh verify34.587+load11.599,recheck32.311+9.903.
Serialization,startup fraction and steady slope unisolated. No receipts
reverified by researcher. SeparateT32 next-token clocks in target-accounting.

Seven LIVE records448→455:new MLIR,older Polygeist paper/repository,older
BatchZK;refreshed super-sumcheck,efficient-sumcheck,October zkLLMPoT v2.
Verified dates,actual/declared licenses,inspected Polygeist ctz commit and
cached-history/fetch limits retained. No external performance reproduced.
Prior findings/source prefixes preserved;all required reports saved.

New target proofs/passes/positions **0/0/0**,device none. Target context,
steady/total rates,startup fraction,witness/proof/serialization/verification
unmeasured. No long prefill,resident series or decode. Larger workloads
allowed;attention can grow quadratically. Complete private8B≥50 proved
positions/s on5090/namedhigh-endGPU unchanged/unachieved. Only research
files written;runtime,production,Git,receipts,calibration,safety,instructions
and reviewer files untouched. Saved reports do not establish delivery.
Checkpoint {NOW}.
'''
    (R/'STATE.md').write_text(state)
    (H/'final-state.md').write_text(state)
    print('Cycle0083 checkpointed; validation remains. '+NOW)


if __name__ == '__main__':
    main()
