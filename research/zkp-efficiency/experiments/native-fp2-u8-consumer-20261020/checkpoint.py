from pathlib import Path
import datetime,hashlib,json
H=Path(__file__).resolve().parent;ROOT=H.parent.parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
run='20261020T161854Z-f0b8edce';cycle='0108'
probe=json.loads((H/'result.json').read_text());audit=json.loads((H/'validation-result.json').read_text())
build=json.loads((H/'build-result.json').read_text());sources=json.loads((H/'source-records.json').read_text())
assert probe['status']==audit['status']=='PASS' and build['returncode']==0
for pin in json.loads((H/'source-pins.json').read_text()):
    assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256']
assert (ROOT/'sources.jsonl').read_bytes().startswith((H/'startup/sources.jsonl').read_bytes())
assert (ROOT/'FINDINGS.md').read_bytes().startswith((H/'startup/FINDINGS.md').read_bytes())
metrics='''New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; longer context can increase attention work quadratically. The complete
private 8B target of >=50 proved positions/s on RTX 5090 or another named
high-end GPU remains unachieved.'''
historical='''Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verify42.709s
+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown. This is not a high-end GPU result.'''
next_local='''Build a source-pinned claim/mask/PCS site ledger for a prospective private
fraction-tree replacement: both child branches per layer, all83/85 ordered
original U8 links and one global table. Make the LSB consumer to native MSB
point mapping explicit. Reject count-preserving wrong-site merges; keep
unknown private costs unknown before making a net-memory or time claim.'''
next_owner='''Owner next: complete GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and the all-eleven
FZC compiler A/B under shared build/heavy locks. Retain fresh masking and count
only completed, independently verified full-stack receipts.'''
readme=f'''# Native Fp2 ordered U8 consumer prerequisite — cycle0108

Run `{run}`, 2026-10-20 UTC. **No proving speed improvement measured.**
The prior challenge-causal tiled consumer now runs over the actual project
field Fp[u]/(u²−7), p=2^64−2^32+1. This is an unmasked arithmetic prerequisite
for a prospective protocol replacement; it is not a production proof patch.

The baseline already builds a fresh256-entry reciprocal cache once per
attempt. The native U8 table later inverts every table denominator before
multiplicity multiplication. This means a zero denominator at an absent
value still refuses, even if its multiplicity is zero. No new inversion
optimization was discovered. Cross-attempt caching fails a differential control.

`Attempt` retains a challenge-local256-entry denominator table (4096B of Fp2
payload) beside the reciprocal cache. Byte rescans read these denominators;
out-of-range i64 values retain the old individual-inverse arithmetic for
dishonest-witness tests. `OrderedLookup` reads immutable synthetic A planes
with the native wrapping-i64 Lk expression rule. This does not admit invalid
ranges or modify any refusal/timing/draw/absorb policy.

## Result and evidence

- Main: {probe['checks']} checks, {probe['native_helper_entries']} native helper entries,
  {probe['tiled_consumers']} tiled consumers, {probe['native_layer_cases']} native resident-layer cases,
  {len(probe['negative_controls'])} controls. Original leaf sizes2..64, depths1..5,
  prefix rounds0..4; exact0/1 and non-base-field challenges.
- Independent audit: {audit['checks']} checks, {audit['independent_inverse_cases']} inverses via exponent p²−2,
  {audit['original_fixture_cases']} saved original-MLE fixtures, {audit['native_wrapping_reader_values']} native affine/wrapping values,
  every one of256 possible zero table-denominator sites, and
  {audit['additional_tiled_consumers']} more consumers (including256-entry sparse global table, depth8).
  Six unchanged source pins; three source-fragment mutation controls;
  four overflow cases show why unbounded arithmetic is not a drop-in reader.
- Every sampled cubic row, interpolated claim chain, terminal and four
  original MLEs matches independent Boolean-basis evaluation. Compiled native
  field/helper extraction also matches40 materialized resident-layer cases.
  The source is revisited in order0..n−1 exactlyq+1 times and stays immutable.
  The two original helper bodies match their frozen source exactly.

Controls cover absent/present zero denominators, zero numerator, signed fallback,
stale cache, wrong extension polynomial, wrong-site swap that preserves the
root but changes ordered MLEs, bit order, altered sample/terminal, missing
challenge, source drift and degenerate0/0. These are arithmetic/refusal controls,
not a native privacy, soundness, Fiat-Shamir or saved-receipt verifier.

The resident Rust reference is independently written using an unmodified copy
of frozen R9 `zkp-core/src/field.rs` and two inspected pure helper extractions.
It does not compile or run the native prover. No downloaded code executed.
The Python tuple reference uses polynomial convolution and explicit Boolean
basis sums, independently of the candidate field and fold implementation.
The consumer's explicit LSB order is NOT yet a native MSB/profile adapter.

## Costs, ceiling and falsification

Potentially eliminated work is materialized looked-U8 columns and repeated
byte-denominator construction within the prospective consumer. Native H,
commitments and proof work are unchanged. Added costs: the4KiB payload,
every source-expression evaluation/rescan, regeneration, fold, equality table,
ordered-A terminal link, full table checks, private masks/CFS/PCS and review.
The previous68.030->36.022MiB selected-array model is carried evidence only;
this cycle measures no native allocation or fit, and does not reprice it.

If f is the unknown exclusive affected proving-time fraction, even free
deletion has end-to-end speed ceiling<=1/(1−f), before added costs. No numeric
5090 proof rate follows. Falsify on any original helper/MLE/refusal/RNG-order
mismatch, changed source, stale cache, hidden retention/PCS cost erasing savings,
failed privacy/soundness binding, no relevant device capacity cliff, or slower
complete workloads. Unmasked roots and messages cannot be exposed as private
proofs. Paired helper/layout grouping, all source sites, native MSB mapping,
mask sites and terminal openings are still integration obligations.

## Reproduction and limits

```
python3 experiments/native-fp2-u8-consumer-20261020/run_bounded.py build_oracle.py
python3 experiments/native-fp2-u8-consumer-20261020/run_bounded.py probe.py
python3 experiments/native-fp2-u8-consumer-20261020/run_bounded.py validate.py
```

Seed20261020108; independent audit20261020109. Resource runner pins the first
allowed core, nice19; one CPU worker, one Rust codegen unit,59s CPU/alarm,
60s parent and512MiB address space per command. Estimate64MiB for probe/audit,
256MiB for the dependency-free adapter build. Intel Core Ultra9 185H / WSL2;
no accelerator invoked. Final build {build['elapsed_s']:.6f}s / {build['maxrss_KiB']}KiB;
probe {probe['elapsed_s']:.6f}s / {probe['maxrss_KiB']}KiB;
audit {audit['elapsed_s']:.6f}s / {audit['maxrss_KiB']}KiB. These are diagnostic
correctness clocks, not comparable proving benchmarks. All passes succeeded;
the pre-reader stage and earlier audit are preserved under `before-affine-reader/`.

## Sources and ranking

Thirteen native LIVE search queries;11 records appended639->650. Material leads:
[LogUp-GKR](https://eprint.iacr.org/2023/1284),
[Chimera's October16 revision](https://eprint.iacr.org/2026/1388),
[Plonky3 equality/mask/release sources](https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.2),
and newly screened older [OpenSSLNTRU section2.2](https://www.usenix.org/system/files/sec22-bernstein.pdf).
The older batch method already exists in native code. No author speedup was
reproduced. Verified dates, licenses, version/commit scope, fetch failures and
prior assessments are in `source-records.json`. No new external commit diff
was successfully inspected; release listings disagree on cached/latest views.

Twenty ranked hypotheses retained in `hypotheses.json`; rank7 materially refined.
Top three remain complete GPU/resident workload evidence, DD context scaling
after T128's measured null, and actual capacity/exclusive phase tracing.
The all-eleven FZC native compiler A/B remains ahead of this protocol redesign.

{metrics}

{historical}

## Handoff and next action

Actual seams: frozen R9 `protocol::lookup_values_at`,
`u8_denominator_inverses`, `helper_one`, `write_h`; `layout::Lk/lookups_at`;
`argument::helper_sum/SC_TAB`; native `zkp-core::field`. Interfaces are
`OrderedLookup.read(index)->(numerator,denominator)` and
`consumer(...)` yielding a complete cubic row before accepting its challenge.
Research paths: `fp2.py`, `tiled_fp2.py`, `oracle.rs`, `reference.py`.
No production patch is ready. Main/Claude reviews any integration; no merge.

{next_local}

{next_owner}

R9 N-r9-a/b, DD privacy gate, D32 fidelity and narrow D33/D34/D35 scopes remain.
LOW fidelity layout excluded. Only research excluding runtime written; no
production/Git/GPU/install/external writes/messages/purchases/escalation.
Saved reports do not establish external delivery.
'''
(H/'README.md').write_text(readme)
handoff=f'''# Native Fp2 U8 reader and tiled arithmetic reference

Cycle0108 / `{run}`. **No proving speed improvement; no production patch.**

The [experiment](../experiments/native-fp2-u8-consumer-20261020/README.md)
ports the prior tiled consumer to native Goldilocks Fp2 and validates against
a compiled source-pinned Rust arithmetic/helper reference and independent
original Boolean-basis MLEs. Main {probe['checks']} checks /100 consumers /
3168 helper entries; audit {audit['checks']} checks /28 more consumers /
164 wrapping reader values /256 zero sites /6pins. Sixteen main controls plus
four overflow controls pass. Probe0.313s and audit2.925s are CPU correctness
clocks; zero full-stack receipts, no GPU measurement.

Interface and patch location: research-only `fp2.py::Attempt/OrderedLookup`
implements fresh challenge-local denominator/reciprocal caching and immutable
wrapping-i64 Lk reads; `read(index)->(N,D)`. `tiled_fp2.py::consumer` yields
the full four-sample cubic row before receiving the actual challenge, then
hands off four original folded MLEs. `oracle.rs` is a reference harness using
the copied native field and two exact pure helper bodies, NOT a native prover.

Native seams: frozen R9 protocol::lookup_values_at/u8_denominator_inverses/
helper_one/write_h; layout::Lk/lookups_at; argument::helper_sum/SC_TAB and
zkp-core::field. Original source paths/hashes in source-pins.json.

The native256-entry inverse cache already exists; no new inversion saving.
A denominator table adds4096B payload per attempt if retained beside it.
Zero table denominators refuse even for absent values and multiplicity0.
Keep all table rows and original refusal/RNG/draw/absorb order; no retries,
cross-attempt caching or private mask/opening reuse authorized. Out-of-range
i64 fallback tests are dishonest-input arithmetic, never profile admission.

Unresolved: original-A leaf binding and MSB mapping (consumer explicitly LSB),
all83/85 lookup sites and paired helper grouping, one global histogram and
pad constraints, versioned private GKR/CFS/PCS, mask/claim/opening site counts,
soundness/privacy/fidelity reviews, native masked transcripts/refusals/receipts,
actual peak capacity and complete workload time. Wrong-site swaps preserve
the fraction root; an ordered terminal link is mandatory. Unmasked rows/roots
cannot be published as a private proof.

Free-deletion ceiling<=1/(1-f) for unknown exclusive affected fraction f,
before added scans and private proof work. Prior selected-array memory is
not a net native saving. Reject any binding/exactness/refusal/draw mismatch,
stale source/cache, missing private cost or enclosing slowdown.

{next_local}

{next_owner}

Main/Claude reviews and integrates if appropriate; do not merge this lane.
All production/reviewer/instruction/Git/runtime files remain read-only.
'''
(ROOT/'handoffs/20261020-native-fp2-u8-consumer.md').write_text(handoff)
summary=f'''# ZKP efficiency progress

Cycle0108 complete — `{run}` — 2026-10-20 UTC.

**No proving speed improvement measured.** The prospective tiled lookup
consumer now passes exact native Goldilocks Fp2 checks. Its helper reader
matches 3,168 entries against pinned Rust arithmetic; 100 tiny consumers match
every cubic row and terminal MLE. Independent audit adds 28 consumers,
164 affine/wrapping reader values and all 256 possible table zero-denominator
sites, including zero multiplicities. Main 10,386 checks; audit 1,766; all pass.

This is unmasked arithmetic, not a private proof. The native reciprocal cache
already exists. A fresh denominator table adds 4 KiB payload; native proof
memory/time and private masking/PCS costs remain unknown. Probe 0.313s,
audit 2.925s, under 19 MiB RSS; tiny reference build 0.423s/134 MiB, no GPU.

Searched current LogUp-GKR, Chimera October16 and Plonky3 sources; screened
older OpenSSLNTRU batch inversion. Thirteen LIVE queries/11 primary records;
no author speedups reproduced. Twenty hypotheses retained and lookup rank7
refined; complete GPU/resident evidence, DD scaling and capacity clocks lead.

{metrics}

Next local: price private claim/mask/PCS sites and explicit native point mapping
before claiming memory savings. Owner next: verified resident1/2/4/8, DD context
scaling and all-eleven FZC A/B under locks. Privacy/fidelity gates remain.

[Experiment](experiments/native-fp2-u8-consumer-20261020/README.md),
[handoff](handoffs/20261020-native-fp2-u8-consumer.md),
[dated report](progress/{run}.md).
Research-only writes; saved reports do not establish external delivery.
'''
(ROOT/'PROGRESS.md').write_text(summary)
dated=summary.replace('# ZKP efficiency progress',f'# Progress — {run}',1)+f'\n{historical}\n\nCheckpoint UTC: {now}.\n'
dated=dated.replace('](experiments/','](../experiments/').replace('](handoffs/','](../handoffs/').replace('](progress/','](../progress/')
(ROOT/'progress'/f'{run}.md').write_text(dated)
finding=f'''\n\n## Cycle 0108 — native Fp2 ordered U8 consumer prerequisite (2026-10-20)

Run `{run}`. **No proving speed improvement measured.** The prior tiled
fraction-tree consumer now uses the native Goldilocks quadratic extension
Fp[u]/(u²−7), rather than F65537. Every helper, sampled cubic row and terminal
MLE in the tested scope matches a source-pinned native Rust field/helper
reference and independent original Boolean-basis oracle.

Main10386checks,3168 helper entries,100tiny consumers/40native resident-layer
cases,16controls. Independent1766checks:96 exponent inverses,40 original-MLE
fixtures,164native affine/wrapping values,all256 zero table-denominator sites,
28additional consumers including256-row table,6pins/3source mutations and
4overflow controls. Total128unmasked consumer cases; no masked protocol.
Shapes2..64 looked leaves/depth<=5 and256-row table/depth8, prefixq<=4,
0/1/non-base challenges. Original source/order and q+1 rescans checked.
Probe0.313142s/19016KiB; audit2.924653s/17392KiB;
dependency-free native-reference build0.423489s/136596KiB.
Intel Core Ultra9 185H/WSL2, first allowed core/nice19, one CPU worker/codegen
unit;59sCPU/alarm,60sparent,512MiBAS; probe/audit estimate64MiB/build256MiB.
Successful earlier stages preserved; no failed experiment or external code run.

Useful negatives: the256-entry reciprocal cache ALREADY exists per attempt.
An absent byte whose denominator is zero accepts in a looked column that
does not contain it, but later refuses at the global table even with m=0.
Skipping that row changes the refusal domain. All256 placements checked.
Stale cache across changed challenge fails. Naive unbounded Lk arithmetic
differs from native wrapping i64 on four overflow fixtures; these are dishonest
witness controls, not profile admission. Root-preserving wrong-site swap still
changes original MLEs. LSB consumer to native MSB binding remains unimplemented.

Refined rank7: generate original ordered leaves through immutable synthetic
A/affine descriptors and a fresh denominator table (4KiB payload if retained
beside inverse cache). This avoids prospective looked-column materialization
and repeated byte-denominator arithmetic, but removes no production work.
Source scans/regeneration/folds/equality, full table refusals, all83/85 ordered
links, one global histogram, original pad constraints and private masks/CFS/PCS
remain. Do not move refusal/RNG/draw/absorb order or reuse private masks/openings.
Previous68.030->36.022MiB selected-array result is carried evidence only;
no native net-memory, device fit or speed claim. If f is unknown exclusive
affected time, free-deletion ceiling<=1/(1-f) before all new costs. Falsify on
binding/exactness/refusal/order/privacy/soundness drift, hidden retention/PCS
cost erasing savings, absent capacity cliff or enclosing slowdown.

Thirteen LIVE queries/11records639->650. LogUp-GKR and ChimeraOct16 refreshed;
Plonky3 field polynomial, equality/mask PRs and rc2 release scope inspected.
No new external commit diff successfully inspected; failed files/commit fetches
and inconsistent release-list/cache views retained. Older newly screened
OpenSSLNTRU2022 section2.2 shows batch inversion already present natively;
ECC2K2012 abstract/PDF403 retained as a field/hardware applicability blocker.
Prior mu-seek/Jolt/LogUp assessments retained, not labeled new. Verified date,
license, access and claim/reproduction scope in source-records.json. No author
performance or private-proof guarantee reproduced. Twenty hypotheses retained;
top3 wholeGPU+resident1/2/4/8, DDcontext scaling and complete capacity/clocks;
all-eleven FZC compiler A/B remains ahead of protocol redesign.

{metrics}

{historical}

{next_local}

{next_owner}

Only research excluding runtime written; no production/Git/GPU/install/external
writes/messages/purchases/escalation. R9N-r9-a/b, DDprivacy gate, D32 fidelity
and narrow D33/D34/D35 remain; LOW layout excluded. Main/Claude reviews,
no merge. Saved reports do not establish delivery.

[Experiment](experiments/native-fp2-u8-consumer-20261020/README.md),
[handoff](handoffs/20261020-native-fp2-u8-consumer.md).
'''
current=(ROOT/'FINDINGS.md').read_text()
if '## Cycle 0108 —' not in current:(ROOT/'FINDINGS.md').write_text(current+finding)
state=f'''# ZKP efficiency explorer — durable state

Cycle0108 COMPLETE: `{run}`. CheckpointUTC {now}.
Deadline16:38:54UTC; next cycle no earlier than17:18:54UTC.
Evidence: experiments/native-fp2-u8-consumer-20261020/.
Startup memory/project docs, AGENDA,639-record ledger and latest0107 results
read; originals preserved in startup. Prior findings/negative results retained.

No proving speed improvement measured. Prospective tiled consumer now uses
native Goldilocks Fp2.10386checks/100consumers/3168native helpers/40native
resident-layer cases/16controls pass. Independent1766checks/96exponent inverses,
40original-MLE fixtures/164native wrapping reader values/all256table zero sites,
28more consumers/6pins/3source mutations/4overflow controls pass.
Original ordered rows/terminal MLEs, q+1 scans,0/1/non-base challenges tested.
No full native layout/point/MSB adapter, private GKR/CFS/PCS or receipt verification.

Existing native256-entry inverse cache is per attempt. New denominator table
adds4KiBpayload if retained beside it. Unused value/zero multiplicity MUST still
refuse at the global table. Stale cache and naive unbounded Lk arithmetic fail.
Wrong-site root swap requires original ordered-A binding. No refusal/RNG/draw/
absorb timing change, retries, mask/opening reuse or privacy weakening authorized.
Prior36.022MiB selected arrays not native memory/time/fit; no reprice this cycle.

One CPU worker/first allowed core/nice19; one Rust codegen unit;59sCPU+alarm,
60sparent/512MiBAS; estimates64MiBprobe/audit,256MiBtiny reference build.
Probe0.313142s/19016KiB; audit2.924653s/17392KiB;
final reference build0.423489s/136596KiB. No native prover/dependency build.
All stages pass; earlier stage preserved, no failed experiment.

Thirteen native LIVE queries/11records639->650. LogUp-GKR, ChimeraOct16,
Plonky3 field/PR/release refresh; new older OpenSSLNTRU batch method already
native; ECC2KPDF403 and other fetch/version/commit limits explicit. No author
speedups reproduced or external code executed.20ranked hypotheses retained;
top3 wholeGPU+verified resident1/2/4/8, DDcontext scaling, actual phase/capacity.
Rank7 materially refined. All-eleven FZC compiler A/B stays higher priority.
Handoff: handoffs/20261020-native-fp2-u8-consumer.md; main/Claude reviews.

Next local: {next_local}

{next_owner}

{metrics}

{historical}

R9N-r9-a/b, DDprivacy gate, D32 and narrow D33/D34/D35 remain. LOW layout
excluded. Only research excluding runtime written; no production/Git/GPU/
install/external writes/messages/purchases/escalation. No merge.
Saved reports do not establish external delivery.
'''
(ROOT/'STATE.md').write_text(state)
cycle_result={'cycle':cycle,'run_id':run,'checkpoint_utc':now,'status':'COMPLETE',
 'probe':probe,'audit':audit,'build':build,'source_records':len(sources),'hypotheses':20,
 'new_full_stack_proofs':0,'new_passes':0,'new_positions':0,'native_prover_changed':False}
(H/'cycle-result.json').write_text(json.dumps(cycle_result,indent=2)+'\n')
print(json.dumps({'status':'COMPLETE','cycle':cycle,'checkpoint_utc':now,'reports_written':5}))
