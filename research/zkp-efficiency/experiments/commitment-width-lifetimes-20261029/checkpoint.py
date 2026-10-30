"""Write this bounded cycle's research-only durable reports, preserving prior records."""
from pathlib import Path
import datetime,hashlib,json
H=Path(__file__).resolve().parent;R=H.parent.parent
run='20261029T095649Z-50135f2e';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((H/'result.json').read_text());a=json.loads((H/'audit-result.json').read_text());c=json.loads((H/'compile-execution.json').read_text())
elapsed=f"{r['elapsed_s']:.6f}";rss=r['max_rss_kib']
sources=(H/'sources-cycle.jsonl').read_bytes();prior=(H/'startup/sources.jsonl').read_bytes()
actual=(R/'sources.jsonl').read_bytes()
if actual==prior:
 with (R/'sources.jsonl').open('ab') as f:f.write(sources)
else:assert actual==prior+sources,'Unexpected source log change: do not overwrite it'
account='''New independently verified full-stack proofs / model passes / proved positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**; research used one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
longer dense attention may grow quadratically. The complete private 8B
>=50 proved-token/s target on an RTX 5090 or another named high-end GPU remains
unachieved.'''
historical='''Carried historical CPU 8B T128/L32, one 16-thread pass, GPU off:
total478.737s =0.267370positions/s; prove_run393.785s includes witness98.348s
and blockload17.595s. Sealing84.824s precedes prove_run; its internal load27.151s
and witness80.897s overlap. Receipt922711264B; verify42.709s plus load13.681s.
Not rerun/reverified or newly counted. Isolated serialization, startup fraction
and steady-state slope remain unknown. These are older-profile measurements.'''
scope=f'''Compiled local component: **168 fixtures /606 rows /360,882 encoded values**
agree with the exact extracted baseline. **29,106 values** also agree with an
independently written O(n²) inverse-DFT/direct-polynomial oracle using generic
u128 modular arithmetic. Widths1..32 and256/4096/16384; rates2/4/8; q1/n/nn−n;
rows1/3/7. The larger rows use the pinned native Fp/NTT in both paths; the direct
oracle covers small rows. Poison/guards, q>n overlap, changed witness+pads in
the same output arena, and five complete serial matrix/column cases pass.
Ten original public-shape refusal cases and ten output/algebra negative
controls pass. This is algorithmic independence within one researcher, not
external review. Full native Rayon, CFS, RNG, transcript, PCS, receipt and
privacy gates remain unexecuted. Value tests do not prove Rust alias safety.

Measured row-call allocations: **606 →0**, requesting713,448B →0 cumulatively;
this is not peak memory. Matrix cases assert rows+1 →1 allocations, including
the unchanged encoded allocation. Harness {elapsed}s /{rss:,}KiB RSS;
compile {c['elapsed_s']:.6f}s /{c['max_rss_kib']:,}KiB. Source/patch/cost audit:
{a['checks']}checks /{a['mutations']}static anchor mutations /{a['pins']}pins PASS,
{a['elapsed_s']:.6f}s /{a['max_rss_kib']:,}KiB. Seed202610290140.
One pinned nice19 CPU, one compiler codegen unit; auxiliary OS thread count
not measured. Each experiment has40s CPU /45s alarm /50s parent timeout and
384MiB address-space cap; compile estimate320MiB, harness64MiB. No Cargo,
dependency build/install, GPU or large build. Rustc1.75.0; complete commands,
binary/input hashes and hardware are retained. Initial narrower passing
component results are preserved; no failed experiment occurred.'''
contract='''Baseline: CPU initialize_row allocates data.to_vec, inverts it, then
writes the final row. Candidate: initialize only the final row's first n values,
form an Fp slice over that initialized prefix, invert and scale in place, then
initialize hiding-pad and zero tails before forming the complete Fp slice.
The outer checked shapes, length-zero panic ownership, row order, outputs,
fresh pad/salt schedule and caller interface stay unchanged in the patch.
The module safety comment was corrected to describe prefix initialization.

Eliminated work: one coefficient Vec allocation/free per row and8*n bytes
of live coefficient payload per active worker. At n16384 this is128KiB/worker,
or2MiB with16 active workers. Counting all rows*n as simultaneous scratch is
wrong. No encoded-matrix bytes, NTT butterflies, padding, salts or nominal
data-copy words are removed. Added costs/risks: an initialized-prefix unsafe
borrow argument and changed cache/locality behavior. Allocator RSS/physical
traffic and production release performance were not measured.

Expected end-to-end ceiling: unknown, N/(T−C_exclusive_allocator+A_added).
Even free deletion of a measured exclusive fraction f gives at most1/(1−f);
f is unknown. The CUDA backend is tried before this CPU path, so an accepted
CUDA commitment has zero direct incidence. Reject promotion on any value,
q-overlap, tail/order, refusal, safety, RNG/transcript/receipt/privacy mismatch,
absent CPU incidence, or no gain in an enclosing independently verified workload.
This is a small allocation cleanup, parked behind owner phase measurements.'''
literature='''Eight LIVE primary source records append924→932. Known ICICLE/Blackwell
reorder and Qingming layout contracts were refreshed; ICICLE issue1047 is a
newly inspected primary coordinate. Known GPIR and cuda-zkp-ntt release/negative
results reinforce layout/transfer/cache-pressure accounting; partial DFT-stage
ratios are not complete-transform gains. Newly assessed DESILO2.0 explicitly
dates October15,2026: its GL is Gentry-Lee FHE, not Goldilocks, and its inspected
license is a restricted binary license. Newly screened older IEEE in-place NTT
hardware metadata (publication January15,2025) is not a native CPU/CUDA adapter;
direct access hits robot verification. The2022 HE mixed-radix/shared-memory
paper is a known lead. No external code was executed or author timing reproduced.
Release rows without a year remain undated; observed commit7b1e6b9ce865ea45f6c601a33118512dd98e1149
fetched Cachemiss and is not an inspected code pin. License/commit/page blockers,
access dates, exact URLs and dispositions are retained in sources-cycle.jsonl.

Selected primary sources: [ICICLE1046](https://github.com/ingonyama-zk/icicle/issues/1046),
[ICICLE1047](https://github.com/ingonyama-zk/icicle/issues/1047),
[GPIR](https://arxiv.org/abs/2604.04696),
[DESILO2.0](https://fhe.desilo.dev/2.0.0/release_notes/),
[older in-place hardware](https://ieeexplore.ieee.org/document/10843144/).
Their claims are screening evidence, not reproductions here.'''
nextstep='''Owner next: confirm actual CPU/fallback incidence and exclusive allocator,
encoding, hash, witness, proof, serialization and enclosing clocks. If material,
review the unsafe prefix argument, run native1/2-thread R2a and available memory
safety gates, then golden/refusal/RNG/transcript/PCS/privacy and independently
verified full-workload gates under current shared locks. No heavy job queued.
Whole-prover high-end GPU and verified fixed-context resident1/2/4/8 workloads
remain the first priority. S4 split-width protocol/layout work remains its
owner's lane and was only read as context.

Next local experiment (sumcheck/GKR rotation): test hypothesis57's per-call
public component-sum preparation against existing paired3 mask dots at the
actual R13 terminal seam, with general Fp2/zero/Boolean tails, original ordered
mask pairs, changed challenges and offsets. Charge every extra scan, byte,
write/read and dispatch. No private mask or result caching across proofs.
First re-read owner updates and the earlier mask-tail incidence negatives.'''
restriction='''Only research outside runtime was written. No production, Git metadata,
receipt, calibration, instruction, safety or reviewer files changed. No large
build, GPU, installation, external write/message, purchase or escalation.
Main/Claude reviews and integrates; patch is unapplied and nothing was merged.
Saved reports do not imply message delivery or supervisor liveness.'''
readme=f'''# R13 CPU hiding-row output-prefix scratch

Run `{run}`, cycle0140; checkpoint{now}.
**Exact compiled local allocation reduction; no native proving speedup measured.**

{contract}

{scope}

The compiled matrix adapters differ from the native outer functions only by
removing the Rayon import and changing par_chunks_mut to chunks_mut. They
retain the checked entry and length-zero allocation ownership. This exercises
the native helper with copied native field/NTT code; it is not a full prover build.
The direct oracle and ten negative controls are in harness.rs. The standalone
allocator counter measures requested allocations; it excludes test preparation.

Reproduce from the research directory:

```
python3 experiments/commitment-width-lifetimes-20261029/prepare.py
python3 experiments/commitment-width-lifetimes-20261029/run_bounded.py compile
python3 experiments/commitment-width-lifetimes-20261029/run_bounded.py probe
python3 experiments/commitment-width-lifetimes-20261029/run_bounded.py audit
```

Integration: frozen R13 zkp-core/src/pcs/encode_buffer.rs:43, initialize_row.
Review-only initialize-in-output.patch; candidate helper candidate_row.rs;
exact source pins native-pins.json; full handoff../../handoffs/20261029-cpu-encode-prefix-scratch.md.

{literature}

{nextstep}

{account}

{historical}

{restriction}
'''
(H/'README.md').write_text(readme)
handoff=f'''# R13 CPU encode prefix scratch — review-only candidate

Run `{run}`, cycle0140, {now}. No native proving improvement measured.
Disposition: **PARK pending actual CPU allocator/enclosing clocks**.

Interface stays initialize_row<'a>(ntt:&NttTables,data:&[Fp],pads:&[Fp],
pows:&[Fp],out:&'a mut[MaybeUninit<Fp>])->&'a mut[Fp]. Source: frozen R13
`results/zk60_1b_native_20261017/r13/frozen-tree/zkp-core/src/pcs/encode_buffer.rs:43`,
sha2563c01433d84507cddadcf5c1387c08948fd3efe853a066d74690c0a6e1ce3dd70.
Frozen tree digestbb9eb212… is not a Git commit.

Patch: [initialize-in-output.patch](../experiments/commitment-width-lifetimes-20261029/initialize-in-output.patch).
It is unapplied. The extracted helper and serial adapter compiled in a std-only
research harness; the full native/Rayon crate did not build or run here.

{contract}

{scope}

Safety review obligations: the outer caller requires n>0 power-of-two,
rows>0 and exact lengths; it allocates Vec<Fp> with length0 until successful
worker join. Every prefix Fp is written before prefix casting; Fp is Copy,
repr(transparent), aligned and has no destructor. The mutable prefix borrow
ends before full-row casting; the pad and zero regions are disjoint and fully
written first. A panic must never expose uninitialized Fp or set the vector
length. These are the intended arguments, not a formal aliasing proof.
Native Rayon scheduling, Miri/sanitizer checks where available, all hash/RNG,
CFS/PCS/receipt/refusal/privacy and compiler/allocator performance gates remain.
All private values are recomputed per invocation; no private reuse introduced.

{nextstep}

{account}

{restriction}
'''
(R/'handoffs/20261029-cpu-encode-prefix-scratch.md').write_text(handoff)
body=f'''## Cycle0140 — final-output prefix removes CPU row scratch; impact bounded

Run `{run}`; checkpoint{now}. AGENDA/current target, durable memory,
all924 prior source records, latest results, project CLAUDE/MVP/decisions/active
coordination and owner S4 design were read/scanned and pinned. Early checkpoint
was written at approximately09:57:34UTC (the initial nominal10:00 label is
corrected here from snapshot mtime). A concurrent10:06UTC decisions update
adds token round16's accepted-with-fixes soundness review; it changes neither
the8B target nor privacy scope. The review's D45 policy-list fix is its owner's
task. No review file or owner candidate was edited.

**No native proving improvement measured.** New hypothesis59 tests the CPU
commitment helper's coefficient allocation. All58 prior hypotheses remain;
1/12/34 were refined. Top three remain complete-prover high-endGPU/verified
resident1/2/4/8, DD/fidelity context scaling, and exclusive phase/capacity clocks.
R13 actualL00 public-synthetic proofs and classifier3B results are not8B target
evidence. The owner split-width design is unintegrated and was not duplicated.

{contract}

{scope}

{literature}

{nextstep}

{account}

{historical}

[Experiment](experiments/commitment-width-lifetimes-20261029/README.md) ·
[Handoff](handoffs/20261029-cpu-encode-prefix-scratch.md).

{restriction}
'''
priorfindings=(H/'startup/FINDINGS.md').read_bytes();actual=(R/'FINDINGS.md').read_bytes()
if actual==priorfindings:
 with (R/'FINDINGS.md').open('ab') as f:f.write(('\n\n'+body).encode())
else:assert f'Run `{run}`'.encode() in actual and actual.startswith(priorfindings),'Unexpected findings edit'
(R/'progress'/f'{run}.md').write_text(f'# ZKP efficiency cycle0140 —2026-10-29 UTC\n\n'+body)
progress=f'''# ZKP efficiency progress

Cycle0140 complete — `{run}`, {now}.

**No native proving speedup measured.** A compiled local CPU encoder candidate
uses its final output prefix for coefficient scratch. It removes one allocation
per row while preserving all encoded values. At width16,384 this avoids128KiB
of live coefficient payload per active worker, or2MiB for16 workers. The encoded
matrix and NTT work remain. The accepted CUDA route has zero direct incidence.

Validation:168fixtures /606rows /360,882encoded values agree;29,106values
have an independent direct-DFT reference. Five serial matrices, ten refusals
and ten negative controls pass. Harness{elapsed}s /{rss:,}KiB RSS. A74-check
source/patch/cost audit passes. Full native Rayon, safety, RNG/transcript/PCS,
receipt and privacy gates remain owed. One CPU; no GPU or large build.

Eight primary source records appended;59hypotheses retained. Owner next:
exclusive CPU allocator/encoding and enclosing clocks before deciding whether
native integration is useful. Whole-prover high-end GPU and verified resident
workloads remain first. Next local: fresh public component sums for mask dots.

{account}

[Experiment](experiments/commitment-width-lifetimes-20261029/README.md) ·
[Handoff](handoffs/20261029-cpu-encode-prefix-scratch.md) ·
[Dated report](progress/{run}.md).
Saved reports do not imply message delivery or supervisor liveness.
'''
(R/'PROGRESS.md').write_text(progress)
state=f'''# ZKP efficiency explorer — durable state

Cycle0140 COMPLETE: `{run}`.
Started2026-10-29 09:56:49UTC; early checkpoint09:57:34UTC;
final checkpoint{now}. Deadline10:16:49UTC.
Next cycle no earlier than10:56:49UTC.

No native proving improvement measured. New hypothesis59's compiled local
CPU encoder reuses only its own final output prefix for inverse-NTT scratch.
606row calls allocate606→0 coefficient vectors;713448→0B cumulatively.
Live coefficient payload saved8*n per active worker;128KiB at n16384,
at most2MiB for16active workers. Do not count rows*n as simultaneous savings.
Encoded matrix, NTT butterflies, pads/salts and nominal copies remain.
Accepted CUDA commitments have zero direct incidence. No mask/private reuse.

168fixtures/606rows/360882encoded values pass;29106direct-DFT values;
five serial matrices/ten refusals/ten negative controls. Harness{elapsed}s,
{rss}KiB RSS. Source audit74checks/four static mutations/11pins PASS.
Std-only local component compiled against copied frozen Fp/NTT; matrix
adapters replace Rayon traversal with serial only. No full native/Cargo build.
One pinned nice19 CPU;40sCPU/45salarm/50sparent/384MiBAS caps.
Full native Rayon, alias safety, RNG/transcript/CFS/PCS/receipt/privacy gates owed.

All58prior hypotheses remain;1/12/34refined;59added and PARKED behind
exclusive native allocator/enclosing clocks. Global top3: complete-prover named
high-endGPU with independently verified resident1/2/4/8; DD/fidelity context
scaling; exclusive phase/capacity clocks. Eight LIVE primary records924→932:
ICICLE1046/1047,GPIR,Artemarius releases,DESILO2.0,older in-place hardware,
2022HE NTT,Qingming. Verified dates/licenses/access blockers saved. No foreign
code executed or author speed reproduced. D45/token16 concurrent review
accepted-with-fixes is separate and does not change private8B target/privacy.

Owner next: CPU/fallback incidence and exclusive allocator/encoding/hash/
enclosing clocks; safety/native goldens if useful. Whole-prover GPU/resident
measurements retain priority. Owner S4 split-width design was only read;
no protocol/layout implementation or heavy job queued. Main/Claude integrates.
Next local: sumcheck/GKR hypothesis57 public component-sum preparation versus
existing paired3, with general/zero/Boolean Fp2 tails, ordered offsets,
changed challenges and full added scan/traffic/storage/dispatch accounting.

Experiment: experiments/commitment-width-lifetimes-20261029/README.md.
Patch: initialize-in-output.patch in that experiment; unapplied.
Handoff: handoffs/20261029-cpu-encode-prefix-scratch.md.
Dated report: progress/{run}.md.

{account.replace('**','')}

{historical}

Prior STATE and early checkpoint preserved under startup. FINDINGS/sources
appended only. Only research outside runtime written; no production/Git/
receipt/calibration/instruction/safety/reviewer changes. No GPU, large build,
install, external write/message, purchase or escalation. Saved reports are
not delivery or supervisor liveness evidence.
'''
(R/'STATE.md').write_text(state)
(H/'completion.json').write_text(json.dumps({'run_id':run,'cycle':'0140','status':'COMPLETE_LOCAL_COMPONENT_ONLY','checkpoint_utc':now,'source_records_before':924,'source_records_after':932,'hypotheses':59,'production_modified':False,'gpu':False,'full_prover_build':False,'local_std_only_compile':True,'target_achieved':False,'full_stack_proofs':0,'passes':0,'proved_positions':0},indent=2)+'\n')
print(json.dumps({'checkpoint_utc':now,'sources':932,'hypotheses':59,'experiment_status':r['status'],'proof_tokens':0}))
