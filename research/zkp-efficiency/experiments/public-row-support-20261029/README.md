# Public mask-row support bound — cycle 0148

Run `20261029T175649Z-b41890ba`, October 29, 2026. **No native proving
improvement measured.** This cycle establishes a conservative incidence
bound for the prior public-rho skip candidate and rejects a mask-count-only
batch-packing heuristic. It does not capture actual native rho density.

The pinned frozen R13 `audit_claims` forbids data/claim parts from reaching
the proximity pair, requires exactly one exclusive reserved pair per
ordinary claim, and requires the H sum to avoid every terminal-site row.
`zk_rhos` adds only the group's member weights, followed by one fresh
proximity vector. Therefore every unrelated terminal mask row has exactly
zero group weight, regardless of private matrix values. Algebraic
cancellation can reduce support further; it cannot create support outside
the parts. Every mask, pad, output vector and opening remains required.

Let R be commitment rows, S terminal sites, D = R−2S−2 nonsite rows,
G ordinary groups (including H's sum), C = ceil((G+1)/4), and Sprox the
sites belonging to groups physically batched with proximity. Treat all D
nonsite rows as live in every ordinary group and proximity as fully dense.
The resulting support **superset** has row visits

`Lenv = (C−1)D + 2(S−Sprox) + R`, versus baseline `C R`.

The ordering-independent upper bound replaces S−Sprox with S. This is a
conservative source-work bound for these inspected geometries (C≥3), not
an actual native support distribution, physical DRAM count or time bound.

| R13 8B/T128 per core | Baseline logical A/H matrix reads | Ordering-independent skipped bytes | Symbolic-order skipped bytes |
|---|---:|---:|---:|
| noDD | 7,725,383,680 B | 322,961,408 B (4.1805%) | 322,961,408 B (4.1805%) |
| DD32 | 7,504,134,144 B | 329,777,152 B (4.3946%) | 333,709,312 B (4.4470%) |

Counts are 8-byte base words read by the source kernel if the previous
zero-skip candidate is used. No layer multiplier is applied. The native
kernel currently reads all rows; the host already skips zero rho. Group
ordering uses the previously validated local symbolic catalog and source
metadata; the native constructor was not executed. R14 split-width geometry
is different and is not assigned these counts. Actual nonsite support may
be substantially smaller, but no synthetic assumption supplies that saving.

The extra mask-envelope improvement from packing the largest three site
groups with proximity is only 138/68 row visits (noDD A/H) or 120/52 (DD A/H).
More importantly, this heuristic can harm actual support unions: a retained
synthetic example lowers its envelope 3,298→3,218 row visits while raising
actual visits **2,274→2,706 (+18.997%)**. Mask counts alone are insufficient.
Full public rho support, locality and planning overhead must be measured.

Validation used extracted, unchanged native `part_rows`, `audit_claims`,
`zpart_weights`, `zkey_weights`, `group_zclaims` and `zk_rhos`; equality-table
parallel iterators were made serial. The small standalone Rust program
uses synthetic claims and scripted xorshift challenges, **not native FS**:

- 81 fixtures: sites4/9/17, groups1/3/4, column logs1/3/5, three point modes;
  4,752 reserved-row checks, 405,216 independently enumerated complete-cube
  coefficients, 5,049 independent message-plus-pad fold values, 5,049
  inverse-scattered values, and 81 dense-proximity fixtures pass.
- Three H all-ones sum fixtures pass and have no terminal/proximity support.
- Seven native audit mutations refuse. Four distinct algebra/order control
  classes run 164 times: wrong inverse scatter, omitted proximity, data
  cancellation and an imaginary-only live weight. These are test invocations,
  not 164 distinct attacks or an independent security review.
- Two independently expressed support-accounting routes agree in 38 checks,
  including the packing counterexample. Reference arithmetic uses u128
  modular schoolbook operations independently of native field code.

Seed202610290148. Final Rust compile1.275s/164,904KiB RSS; probe0.0334s
parent (0.02654s internally)/7,792KiB; census0.116s/32,644KiB. One CPU
affinity, nice19,40s CPU/45s alarm/50s parent,384MiB address-space cap;
memory estimates300MiB compile/96MiB others. Intel Core Ultra9 185H,
Rust1.75 opt1/codegen-units1, Python3.10.12, WSL2. Compiler auxiliary
threads unmeasured; one CPU affinity limits concurrent CPU use. No CUDA
compile/device arithmetic/ABI/races/register/occupancy/timing tested. The
pre-H-sum passing run is preserved in `before-h-sum/`; no failure hidden.

Reproduce each bounded stage separately:

```text
python3 experiments/public-row-support-20261029/run_bounded.py prepare
python3 experiments/public-row-support-20261029/run_bounded.py compile
python3 experiments/public-row-support-20261029/run_bounded.py probe
python3 experiments/public-row-support-20261029/run_bounded.py census
python3 experiments/public-row-support-20261029/run_bounded.py audit
```

Added costs and ceiling: the prior candidate adds both-limb zero tests,
branches and rw[4] temporaries; source accumulator+temporary payload grows
64→128B/thread. Compiled registers/spills remain unknown. All rho upload,
output download, host pad folding and proof work remain. A planner would add
support scans/bitsets/permutation. Whole-workload rate remains
`N/(T−Cremoved_exclusive+Aadded)`. Native exclusive rowfold fraction f is
unknown; even free removal is bounded by `1/(1−f)`. No numerical 8B rate
or extrapolation from logical bytes is justified.

LIVE primary sources: [StateSync-GKR Oct26v2](https://arxiv.org/abs/2610.14849)
has sparse gate booking on a different GKR/field/workload; its gains do not
transfer to dense private PCS. The retrieved unpinned `reduce.rs` body uses
per-output equality products and cannot corroborate release1.2 arithmetic.
Current BSL1.1 license was inspected; no external code adopted.
[Newly assessed older2018 SpMM work](https://arxiv.org/abs/1803.08601)
motivates coalesced access and actual support overlap, while native field
arithmetic and operand roles differ. Spartan-WHIR's README supplies useful
relation-identity/privacy-mode and witness-clock distinctions. Six source
records retain exact dates, URLs, null unknowns, licensing and fetch blockers;
12 raw LIVE web batches are saved. No author speedup reproduced.

Global priorities remain1whole-prover named high-endGPU plus verified
resident1/2/4/8workloads;2admitted-context/DD/fidelity scaling;3exclusive
native phases/capacity. All66 prior hypothesis objects remain unchanged;
67 establishes the mask incidence bound,68 rejects mask-only packing.

Integration seam: existing `fold_rows_multi_zk` → `EncodedStore::fold_rows`
→ `dev_fold_rows` → `k_fold_rows`, still batch4. No new native patch here;
the prior unapplied kernel patch is in `multi-rho-rowfold-20261029/`.
Owner next: current public support/union counters and exclusive transfer,
allocation, kernel, pad, open and enclosing clocks, including the previously
identified missing rho-H2D accounting. Main/Claude reviews and integrates.
Only if material, use shared locks for register/spill/device and native
golden/refusal/RNG/FS/PCS/capture/privacy/independent-full-receipt A/B gates.

Next local: extract actual public ZPart offsets/domains and `build_claim`
mapping for current R13, without any witness, and compare exact structural
support with this conservative bound. Do not reuse synthetic placements
as actual native incidence. New owner measured bottlenecks take precedence.

New independently verified full-stack proofs / model passes / proved
positions: **0/0/0**. Actual model context/accelerator:none. Device: one
pinned CPU worker. Witness, proof, serialization, verification, startup/
prefill duration/fraction, proof latency/bytes, steady-state and total-workload
rates: **unmeasured**. No prefill, resident-model proof series or decode ran.
Larger workloads remain allowed; dense attention can grow quadratically
with context. Complete private8B >=50proved tokens/s remains **unachieved**.

Only research outside runtime written; no production/Git/receipt/calibration/
instruction/safety/reviewer edits, GPU, native build, install, foreign source
execution, external writes/messages, purchase, escalation, Git operation or
merge. Saved reports do not imply delivery or supervisor liveness.
