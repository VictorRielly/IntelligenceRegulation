# ZKP efficiency explorer — durable state

Cycle 0071 COMPLETE: `20261018T002105Z-32d7e4fc`.
Checkpoint: 2026-10-18T00:30:38.534462+00:00.
Next cycle no earlier than 2026-10-18 01:21:05 UTC.

AGENDA/current target, durable/project memory and latest three experiment
results consulted. Starting 371 sources parsed; six LIVE records appended,
377 total, original prefix preserved. Startup originals and hashes:
experiments/pending-fold-weighted-round-20261018/startup/.
Full report: progress/20261018T002105Z-32d7e4fc.md.
No native proving speedup found.

PendingRows combines the known previous challenge's row fold with the next
weighted contraction. It passes 132 synthetic fixtures (84 prior), 3,020 round
values, 396 E/S/V terminals, 755 whole-cube masked rounds, 23 controls including
eight lifecycle checks, 3,031 unchanged-message causality checks and 753 final
sensitivities. Independent original-table/convolution/MLE/monomial-mask audit:
7,795 checks. Executed Fp2 API counters: added add/mul zero, sub 3*(W-1).

Main 1.959028 s including compilation/references, RSS 33,392 KiB, compiler
143,700 KiB; audit 7.184318 s / 28,080 KiB; counter 1.370311 s, compiler
144,844 KiB. One Core Ultra 9 185H CPU0 thread, nice 19, seed 2026101871;
each command 59 s / 512 MiB AS. Initial mutable-finish PASS retained. Refined
last fold/zero-variable constructor drain before native immutable finals(&self).
Trait copy matches native; actual native-crate/transcript/RNG/proof-byte gates
unrun. No native proof, GKR, PCS, GPU or privacy theorem result.

Core row reads 4C(N-1) -> C(3N-2), writes C(N-1) unchanged for N>=2;
N1 has no row work, N2 no saving. Prior T32 four-group census:
46,857,908 -> 35,143,514 logical reads, 178.747467 MiB saved; asymptotic
25% reads / 20% reads+writes. Column tail adds 660 reads / 330 Fp2 subs;
23,426,212 suffix multiplications remain. Same V working allocation and
O(logN) DFS. Input copies/common setup/output/original witness/masks/links/
GKR/PCS remain additional. Large groups not executed; caps N32768/NC2^20.
Byte-only core ratio 1.249998x is not runtime or DRAM evidence. Full ceiling
unknown without Caffected/Cadded. Keep all 83 original A/wrapping links,
distinct points, non-Boolean E/S mixture terminals, fresh whole-cube cubic
masks/extensions/H/M/PCS and joint privacy/soundness. Only fixed PUBLIC shapes;
never hidden prompt/selector/private masks or numerical witness sparsity.
All prior singleton/D-C/joint-mask/off-cube/endpoint-history and slower native
fusion negatives remain. Unapplied handoff:
handoffs/20261018-pending-fold-weighted-round.md.

NEW carried functional R5b 8B T128: one cold 32-block CPU pass, 16 threads,
GPU off, shared n=1, fresh verification, 11 controls and honest recheck.
App 606.598 / process 606.728291 s; diagnostic total 0.211013 / 0.210968
positions/s. Seal 105.287 s = 17.356965%; cumulative load 36.570 / witness
103.349 s overlap inside sealing. Inclusive prove 501.126 s includes 32 witness
rebuilds at 122.694 s and reload 21.176 s; serialization unisolated. Fresh load
14.126 + check 43.902 s; reload 18.459 within check, arithmetic remainder
25.443 s. Verifier process 186.088255 s includes controls. Receipt 922,711,264 B;
RSS 6.55 / cgroup 8.47 GiB. Shape privacy acceptance open. Full startup,
prefill, steady slope, latency, lag/drain unknown. Free deletion of direct H
phases 95.882 s -> 1.187740x / 0.250629 diagnostic positions/s, all other work
fixed before added cost. Only that phase-set bound, not new lookup/shared
zero-check/GPU. Do not combine T32 census with T128 phases as measured speed.
Old T32 R5b 191.755 s baseline preserved in earlier findings/reports.

Owner GPU kernel design remains first: 255 registers/spills; lean logical
plan-byte 11.7% including build is not measured DRAM bandwidth. K1-K4 small
gates pass 23:58; trained gates queued 23:59 at capture. No duplicate job.

Ranked hypotheses:
1. OWNER whole-prover GPU kernels and useful continuous work. Charge integer
   dependencies, registers/spills, memory, warm-up, host extension, transfers
   and drain. Reject gate failure or no enclosing gain; 50/s unmeasured.
2. OWNER immutable public residency and fixed-context fresh-pass slopes.
   Charge startup, witness/serialization/verification, lag/drain, identity and
   RAM. Existing typed witness replay budget/privacy findings apply. Reject
   stale data/backlog or >20 ms recurring/new position for a 50/s claim.
   No private opening or mask reuse.
3. TESTED pending factored lookup arithmetic: lower logical reads/parity only.
   Moderate adapter, high new lookup/GKR/PCS cost. Reject mismatch, stale
   final, refusal/privacy change, peak overflow or no enclosing gain.
4. NEW NEXT LOCAL late-stage public NTT root decomposition/consecutive
   products from older Kim2020 OT. Low CPU oracle/census cost; extra Goldilocks
   products may erase cached-word saving. Preserve first-six-stage shift
   candidate, native roots/scale/order, padding skips, swizzles, pruned routes
   and all prior table-cache negatives. Full end-to-end ceiling unknown.
5. Deferred Orion code switching / Hermes FPGA dataflow: high backend
   migration and corrected masks/composition costs; no borrowed speed claim.

Next local: read owner kernel verdict first and rerank if it supersedes the
premise. Otherwise run a bounded exact modular oracle for native forward/
inverse stage-major late-stage root products, with root-word and operation
census versus the existing table. No GPU. Owner next: K1-K4 enclosing verdict
and complete independently verified resident-workload slopes with all clocks.
Native seam: SumcheckRounds/prove_rounds; a new lookup also needs private_block
protocol/argument/shape/layout H/M/PCS. Owner/Claude reviews/integrates.
Rotation next NTT/commitments plus memory/instruction costs; retain lookup/
softmax/GKR, quantization/arithmetic, batching/amortization and composition.

LIVE versioned P3 Sep23 docs versus GitHub main source mismatch; displayed
Oct16 release/Sep9 IDFT PR; new older Kim2020 OT; Hermes2026 U280 FPGA filter;
Valk2026 instruction wall; ICICLE release refresh. Exact dates/licenses/
commit scopes and failed fetches recorded. No foreign code executed.

New target proofs/passes/positions: 0/0/0. Target steady/total rates and proof
clocks unmeasured. No resident repeats, long prefill or decode. Larger workloads
allowed with fresh masks; attention can grow quadratically, decode needs
proved state. >=50/s private 8B high-end-GPU target unchanged/unachieved.
Production/runtime/Git/receipts/calibration/safety/instructions/reviewer files
untouched; no installs/GPU/external writes/messages/escalation. Saved reports
do not establish external delivery.
