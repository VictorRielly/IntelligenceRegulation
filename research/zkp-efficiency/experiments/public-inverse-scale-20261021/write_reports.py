"""Checkpoint research-only reports from the retained final evidence."""
from pathlib import Path
import datetime,json
E=Path(__file__).resolve().parent
R=E.parent.parent
RUN='20261021T001854Z-77f04b06'
p=json.loads((E/'result.json').read_text())
a=json.loads((E/'validation-result.json').read_text())
c=json.loads((E/'census-result.json').read_text())
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
account='''New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: Intel Core Ultra 9 185H CPU,
one worker, no GPU. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic row lengths
1..32 and conditional T32/T64/T128, L1/L2/L32, 1/2/4/8-pass schedules are diagnostics.
Larger workloads remain allowed; attention can grow quadratically with context.
The complete private 8B >=50 proved tokens/s target remains unachieved.'''
history='''Historical CPU diagnostic, carried without rerun/reverification: non-DD 8B T128,
32 layers, one 16-thread CPU pass, GPU off; total478.737s =0.267370positions/s.
prove_run393.785s includes witness98.348s and load17.595s. Seal84.824s contains
overlapping subwork; do not add clocks. Receipt922,711,264B; fresh verify42.709s
+public load13.681s; recheck34.395s +load10.739s. Isolated serialization, startup
fraction and steady slope unknown. This is not a high-end GPU baseline.'''
direction='''The concurrent public decisions update is retained under end-read/ and listed in
concurrent-document-updates.json. D32 now records <=1.02x held-out perplexity and
zero refusals; >=98% LAMBADA is explicitly the coordinating session's reading of
Victor's 1–2% allowance. D37 adds the classifier/media-app product direction, owned
by the main lane. D33's token-lane frozen-r9 extension and D36's named TinyLlama
T32 CPU next-token acceptance do not cover native DD R9, 8B, GPU or accuracy-fix
profiles. Preserve D30 N-r9-a/b and the outstanding DD privacy gate. No ruling
or instruction was edited here.'''
next_action='''Next local experiment: count download/pack/synchronization incidence around the
EXISTING DevFzcRounds host-tail policy (FZC_TAIL_DEFAULT=5), then use an independent
challenge/fold schedule oracle at thresholds0/5/8/10. Charge the one-time tail copy,
remaining host rounds and fused-round boundaries; do not invent a crossover time.
Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.'''
readme=f'''# Public inverse-size scaling — cycle0116

Run `{RUN}`; checkpoint {now}. **No proving improvement measured.**

The experiment refines last cycle's public NTT preprocessing question. Source pins
separately cover native DD R9, root sources and the dedicated gpu-zerocheck owner.
Every inspected CPU NttTables::inverse computes 1/n by Fermat exponentiation once
per row. Every inspected device NTT wrapper computes it once per row batch; the
normalization already rides on the final kernel store. Six definitions per source
include one benchmark and five wrappers; definitions are not execution counts.

For Goldilocks p=2^64-2^32+1 and0<=k<=32, n=2^k divides p-1, hence
`inverse(n) = p - ((p-1) >> k)`: multiplying by n gives1 modulo p. A public scale
table is also exact (33entries/264B); the closed form needs no table. Its guard
precedes the shift. The table's Python halving recurrence uses arbitrary precision;
it is not a safe native u64 addition algorithm. candidate.rs is UNCOMPILED.

Baseline: one literal pow(P-2),127 source-level multiplies (64squares+63accumulator
products), per CPU row or admitted GPU batch. Eliminated: that scalar calculation.
Added: validated public-log guard and shift/subtract (or table lookup/storage).
All row scale multiplications, kernels, transfers, bytes, pads, salts and masks
remain. Compilers may reduce/fold source work:127 is not an instruction count.

At n16384, rate4, q256, inverse calculation is0.018895% of counted CPU row-encode
multiplications; the corresponding inverse-only share is0.096800%. Counts omit
adds, memory and all other proof phases and are NOT elapsed-time ceilings. GPU
host work cannot be priced as device arithmetic. A4096-row resident batch has1
host inverse, not4096; chunk size1 has4096. Conditional T128/L32 resident-commit
offers imply97scalar inverses/pass,776over8passes, excluding openings/fallbacks.
No native launch incidence, elapsed saving, actual fit or admission was observed.
If f is the unknown exclusive scale-calculation elapsed fraction, even free
removal is bounded by1/(1-f), before costs. No numerical full-prover rate follows.
Falsify any speed claim if existing compilation folds the constant, exclusive
time is negligible, or enclosing proof slows. Any byte/refusal change rejects it.

Reproduction, one child at a time:

    python3 -B experiments/public-inverse-scale-20261021/run_bounded.py probe.py
    python3 -B experiments/public-inverse-scale-20261021/run_bounded.py census.py
    python3 -B experiments/public-inverse-scale-20261021/run_bounded.py audit.py

Probe: {p['checks']}checks,200synthetic rows,6900encoded positions,33scale entries,
15negative controls PASS; {p['wall_seconds']:.6f}s/{p['rss_kib']}KiB RSS.
Census: {c['checks']}checks,144synthetic batch cases,36conditional schedules,
18source definitions and5controls PASS; {c['wall_seconds']:.6f}s/{c['rss_kib']}KiB.
Independent audit: {a['checks']}checks,200rows/6900positions (30q>n overlap rows),
144batch cases,36schedules and18source pins PASS; {a['wall_seconds']:.6f}s/{a['rss_kib']}KiB.
The audit imports no producer code: Euclid and Fermat check scales; direct DFT
on original messages plus explicit `(X^n-1)g` polynomials checks hiding encodes.
CPU overlap semantics are tested; no native CUDA q>n admission/equivalence follows.
No BLAKE3 leaf, native transcript, receipt or independent native verifier ran.
Controls detect invalid log33, missing guards, wrong scale/root/direction,
double normalization, changed pads and invalid coset/capacity. Source mutations
reject changed modulus/inversion/store snippets; they are census checks only.

Seed202610210116. Each experiment: one worker/core,nice19,59sCPU+alarm,60sparent,
512MiB address-space cap. Estimate64MiBprobe/audit,128MiBcensus. All logs and
command exit codes retained; initial results preserved before stronger controls
and inclusion of the dedicated GPU owner source. No native build or GPU ran.

Nine native LIVE queries/nine primary source records append718->727. Sources
include [cuPQC0.6](https://nvidia.github.io/cuPQC/releases/v0.6/) (dated2026-08-28),
its [staged inverse example](https://nvidia.github.io/cuPQC/applications/ntt-staged-transform/),
[GPU-NTT](https://github.com/Alisah-Ozcan/GPU-NTT),
[Chimera](https://eprint.iacr.org/2026/1388) (revised2026-10-16), and newly assessed
older [NTTFusion](https://www.hourui-arch.net/publication/nttfusion-efficient-number-theoretic-transform-acceleration-on-gpus/)
(author page2023-10-06). The official cuPQC feature table limits custom p<2^62,
so uint64 storage does not make native Goldilocks compatible. Sample/docs and
GPU-NTT Apache2.0 bodies inspected; SDK license separate. Commit history429,
NTTFusion PDF InternalError and AG-skip primary inaccessible are retained, with
null unverified dates/commits. No upstream code executed or author speed reproduced.

31ranked hypotheses preserve the prior29. Tested inverse scaling is rank30,
demoted by small arithmetic reach; NTTFusion methodology is rank31 because the
suggested normalization fusion is already present. See hypotheses.json.

{direction}

{account}

{history}

{next_action}

Integration: core field helper/NttTables::inverse and device ntt_rows/_view;
research candidate.rs only. Main/Claude reviews/integrates; no merge. See
../../handoffs/20261021-public-inverse-scale.md. Production, Git, calibration,
reviewer, receipt, instructions and runtime were not edited. Saved reports do
not establish message delivery or supervisor liveness.
'''
(E/'README.md').write_text(readme)
handoff=f'''# Public inverse-length helper — low priority, exact synthetic result

Cycle0116 `{RUN}`. **Small cleanup candidate; no measured proving gain.**

Interface: `inverse_power_of_two(log_n: u32) -> Fp` in
experiments/public-inverse-scale-20261021/candidate.rs (UNCOMPILED). For the
fixed Goldilocks field only, return `Fp(P-((P-1)>>log_n))` after the public
log<=32 guard. Existing transform power-of-two/max_log guards must execute
first. Forward scale stays1; row multiplications/RNG/transcript stay unchanged.

Placement: zkp-core/src/field.rs helper; zkp-core/src/ntt.rs inverse's scalar
calculation; hashline/src/gpu/cuda.rs ntt_rows/ntt_rows_view and related
wrappers. Source pins include nativeR9,root,dedicatedgpu-zerocheck separately.
This is not a proposal to change NTT kernels or fold normalization elsewhere.

200synthetic hiding rows/6900encoded positions,33scales and15producer controls
pass. Independent Euclid/Fermat/direct-DFT/original-polynomial audit passes
{a['checks']}checks, including30CPU q>n overlap rows,144batch cases,36conditional
schedules and18source pins. Commands/seed/dimensions/hashes/logs retained in
the experiment folder. No native build, masked round/receipt, privacy gate or
independent native verification ran. The Rust helper is a placement sketch.

The literal scalar inverse costs127source field multiplies per CPU row or
GPU batch; normalized row multiplies remain. GPU scaling already runs in the
last store: zero launches/transfers/bytes disappear. At illustrative n16384,
rate4,q256, the removed CPU row-encode multiply share is0.018895%; this is
not runtime. Actual GPU host-scale fraction and compiler constant folding
are unknown. Charge guard/call overhead and any table storage if used.

Owner validation before promotion: exact current native field/NTT/PCS row
and opening bytes, all shape/max_log/refusal cases including n1, forward1,
unchanged masked transcript/RNG/next challenge/receipt, independent verification,
and exclusive/enclosing clocks under the existing resource locks. Preserve
fresh pads/salts/masks and all D30 N-r9-a/b bindings. No acceptance transfers
from the named D33/D36 token artifacts to GPU/DD/8B/new fidelity profiles.
Reject any mismatch or enclosing regression; discard a speed claim if the
compiler already folds the scalar or the exclusive clock is negligible.
The unknown free-removal elapsed ceiling remains1/(1-f), not a token rate.

Main/Claude owns integration; no production patch/merge. Whole-GPU complete
proof measurements retain priority over this helper. Source search and
access/license limits are in source-records.json and README.md.
'''
(R/'handoffs/20261021-public-inverse-scale.md').write_text(handoff)
entry=f'''\n\n## Cycle0116 — 2026-10-21 — inverse-length scaling: exact small cleanup, GPU fusion already present

Run `{RUN}`; checkpoint {now}. **No proving improvement measured.**

Read AGENDA,current durable memory/source ledger718records,latest0115/0114results,
project CLAUDE/target/MVP/decisions/active coordination, and current CPU/CUDA seams.
{direction}

CPU NttTables::inverse calculates one public1/n per row; GPU calculates one per
row-batch wrapper, with scale already fused in final store. Separately pinned
nativeR9,root and gpu-zerocheck copies agree: six definitions each (one benchmark,
five wrappers), not observed invocations. The proposed Goldilocks-only identity
`(2^k)^-1=p-((p-1)>>k)` holds exactly for0<=k<=32. A33entry/264B scale table is
also exact; closed form needs no table. Retain validation before shifts and all
row multiplies. No private preprocessing, pad/mask/salt or opening reuse.

Baseline: literal pow(P-2) costs127source-level field multiplies; compiler may
optimize them. Removed: that calculation per actual inverse invocation. Added:
guard plus public shift/subtract (or table costs). GPU launches/transfers/bytes
removed:0. Illustrative n16384,rate4,q256 CPU row-encode multiply share0.018895%;
inverse-only share0.096800%. Neither is a time bound. A4096row resident batch has
one host inverse; size1chunks have4096. Conditional T128/L32 resident commit
offers imply97inverses/pass,776over8passes, excluding openings/fallbacks. No
actual incidence, elapsed saving, admission, native memory peak or GPU rate.
Unknown exclusive elapsed fractionf gives only the free-removal bound1/(1-f).
Falsification: byte/refusal mismatch, compile-folded existing inverse, negligible
exclusive time or enclosing slowdown. This demotes inverse scaling to rank30.

Probe {p['checks']}checks/200rows/6900encoded positions/15controls PASS. Census
{c['checks']}checks/144batch cases/36schedules/18definitions/5controls PASS. Separate
audit {a['checks']}checks/200rows/30CPUoverlap rows/144batch cases/36schedules/18pins
PASS; no producer imports. Euclid/Fermat, direct DFT and original polynomial
oracle agree. Probe{p['wall_seconds']:.6f}s, census{c['wall_seconds']:.6f}s,
audit{a['wall_seconds']:.6f}s; maxRSS{max(p['rss_kib'],a['rss_kib'],c['rss_kib'])}KiB.
One worker,nice19,first allowed core,59sCPU/alarm,60sparent,512MiBAS; estimated
64MiBprobe/audit,128MiBcensus. Seed202610210116. Source/Rust sketch/commands/logs
retained. No native NTT, mask, BLAKE3 leaf, transcript, receipt or verifier ran.

Nine LIVE queries/nine primary records append718->727. Dated cuPQC0.6Aug28 and
ChimeraOct16 refreshed. cuPQC custom p<2^62 excludes full Goldilocks despite
uint64 storage. Newly assessed older NTTFusion author pageOct6,2023 informs
stage fusion, already present for normalization (rank31). GPU-NTT and NVIDIA
sample/docs Apache2.0 bodies inspected; SDK license distinct. Commit429,
NTTFusionPDF InternalError and AG-skip inaccessible recorded without bypass;
unverified dates/commits null. No author performance reproduced. Prior29ranked
hypotheses and every earlier negative remain. Top4owner priorities unchanged.

{account}

{history}

{next_action}

[Experiment](experiments/public-inverse-scale-20261021/README.md),
[low-priority handoff](handoffs/20261021-public-inverse-scale.md).
Only research excluding runtime written; no build/GPU/install/downloaded-code,
external write/message/purchase/escalation/Git/production edits. Main/Claude
reviews/integrates. Saved reports do not establish delivery or liveness.
'''
findings=R/'FINDINGS.md'
if f'## Cycle0116 —' not in findings.read_text():
    with findings.open('a') as f:f.write(entry)
progress=f'''# ZKP efficiency progress

Cycle0116 complete — `{RUN}` — 2026-10-21 UTC.

**No proving speedup measured.** An exact Goldilocks inverse-size helper passes
200 synthetic rows and an independent {a['checks']}-check audit. It removes 127
source-level field multiplies per actual host inverse; GPU already calculates
once per batch and fuses row normalization. Zero device launches/transfers/bytes
disappear. The illustrative CPU row-encode multiply share is0.018895%, not time.
This is a low-priority cleanup. Nine LIVE queries/nine source records retained;
31 ranked hypotheses preserve prior negatives.

{account}

Next: assess the existing sumcheck CPU-tail policy's pack/copy/round schedule.
Owner whole-GPU clocks and verified resident1/2/4/8 workloads remain priorities.
D32's amended fidelity bar and D37's classifier direction were read; narrow
D33/D36 token-lane acceptance does not cover 8B/GPU/DD/new fidelity profiles.

[Experiment](experiments/public-inverse-scale-20261021/README.md),
[dated report](progress/{RUN}.md),
[handoff](handoffs/20261021-public-inverse-scale.md). Saved files do not establish external delivery.
'''
(R/'PROGRESS.md').write_text(progress)
(R/'progress'/f'{RUN}.md').write_text(f'# Cycle0116 progress — {RUN}\n\nCheckpoint {now}.\n'+entry.split('\n\n',2)[2])
state=f'''# ZKP efficiency explorer — durable state

Cycle0116 COMPLETE: `{RUN}`. Checkpoint UTC {now}.
Started00:18:54UTC; deadline00:38:54UTC. Next cycle no earlier than2026-10-21T01:18:54UTC.
Prior state/findings/source ledger and required documents retained under
experiments/public-inverse-scale-20261021/startup/. Concurrent decisions update
preserved under end-read/; only research copies written.

**No proving improvement measured.** Goldilocks public inverse-size identity
p-((p-1)>>k),0<=k<=32, passes exact scalar/row checks. CPU repeats per row;
GPU repeats per batch and already fuses row scale.127source-level field multiplies
per inverse removed;0device launches/transfers/bytes removed. Illustrative CPU
n16384,rate4,q256 row-encode multiply share0.018895%, not elapsed time.
33entry scale table264B alternative; closed form no table. Compiler folding,
exclusive host time and complete-proof benefit unmeasured. Candidate demoted.

Probe{p['checks']}checks/200rows/6900encoded positions/15controls PASS;
census{c['checks']}checks/144batch cases/36schedules/18definitions PASS;
independent{a['checks']}checks/30CPUq>n rows/18pins PASS. Clocks probe
{p['wall_seconds']:.6f}s,census{c['wall_seconds']:.6f}s,audit{a['wall_seconds']:.6f}s;
maxRSS{max(p['rss_kib'],a['rss_kib'],c['rss_kib'])}KiB,oneCPUworker,nice19,59sCPU/alarm,
60sparent,512MiBAS. Seed202610210116. No native build/GPU/proof. Rust sketch
candidate.rs UNCOMPILED; handoff20261021-public-inverse-scale.md for main review.

Nine LIVE queries/nine primary records append718->727. Refreshed cuPQC0.6 dated
Aug28/ChimeraOct16/GPU-NTT; new olderNTTFusion screened. cuPQC p<2^62 excludes
nativeGoldilocks. Commit429,paper inaccessible errors retained; no bypass or
upstream execution.31ranked hypotheses preserve prior29; top4unchanged.

{direction}

{next_action}

{account}

{history}

No production,reviewer,calibration,instruction,receipt,Git or runtime edits;
no build/GPU/install/downloaded-code/external writes/messages/purchases/escalation.
Saved reports do not establish delivery or supervisor liveness.
'''
(R/'STATE.md').write_text(state)
(E/'development-notes.md').write_text('''Read-only exploration initially used the absent sumcheck/*.rs glob; corrected to
sumcheck.rs and the dedicated gpu-zerocheck owner. Initial tests pinned R9/root;
five owner source pins were added and source census/independent audit repeated.
Initial passing evidence retained before stronger source/count controls. No
test failures, permission escalation, network bypass or native execution.
''')
print(json.dumps(dict(checkpoint_utc=now,run_id=RUN,reports_written=True)))
