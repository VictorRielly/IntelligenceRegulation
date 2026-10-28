# Public inverse-size scaling — cycle0116

Run `20261021T001854Z-77f04b06`; checkpoint 2026-10-21T00:29:38.730899+00:00. **No proving improvement measured.**

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

Probe: 515checks,200synthetic rows,6900encoded positions,33scale entries,
15negative controls PASS; 0.126729s/15028KiB RSS.
Census: 381checks,144synthetic batch cases,36conditional schedules,
18source definitions and5controls PASS; 0.134015s/82684KiB.
Independent audit: 1601checks,200rows/6900positions (30q>n overlap rows),
144batch cases,36schedules and18source pins PASS; 0.404522s/24524KiB.
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

The concurrent public decisions update is retained under end-read/ and listed in
concurrent-document-updates.json. D32 now records <=1.02x held-out perplexity and
zero refusals; >=98% LAMBADA is explicitly the coordinating session's reading of
Victor's 1–2% allowance. D37 adds the classifier/media-app product direction, owned
by the main lane. D33's token-lane frozen-r9 extension and D36's named TinyLlama
T32 CPU next-token acceptance do not cover native DD R9, 8B, GPU or accuracy-fix
profiles. Preserve D30 N-r9-a/b and the outstanding DD privacy gate. No ruling
or instruction was edited here.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: Intel Core Ultra 9 185H CPU,
one worker, no GPU. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic row lengths
1..32 and conditional T32/T64/T128, L1/L2/L32, 1/2/4/8-pass schedules are diagnostics.
Larger workloads remain allowed; attention can grow quadratically with context.
The complete private 8B >=50 proved tokens/s target remains unachieved.

Historical CPU diagnostic, carried without rerun/reverification: non-DD 8B T128,
32 layers, one 16-thread CPU pass, GPU off; total478.737s =0.267370positions/s.
prove_run393.785s includes witness98.348s and load17.595s. Seal84.824s contains
overlapping subwork; do not add clocks. Receipt922,711,264B; fresh verify42.709s
+public load13.681s; recheck34.395s +load10.739s. Isolated serialization, startup
fraction and steady slope unknown. This is not a high-end GPU baseline.

Next local experiment: count download/pack/synchronization incidence around the
EXISTING DevFzcRounds host-tail policy (FZC_TAIL_DEFAULT=5), then use an independent
challenge/fold schedule oracle at thresholds0/5/8/10. Charge the one-time tail copy,
remaining host rounds and fused-round boundaries; do not invent a crossover time.
Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.

Integration: core field helper/NttTables::inverse and device ntt_rows/_view;
research candidate.rs only. Main/Claude reviews/integrates; no merge. See
../../handoffs/20261021-public-inverse-scale.md. Production, Git, calibration,
reviewer, receipt, instructions and runtime were not edited. Saved reports do
not establish message delivery or supervisor liveness.
