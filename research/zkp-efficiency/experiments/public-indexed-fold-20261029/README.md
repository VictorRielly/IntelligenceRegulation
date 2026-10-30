# Public indexed rowfold — cycle 0151

Run `20261029T205649Z-c620e79d`, October 29, 2026. **No native proving
improvement measured.** The experiment tests a possible rowfold algorithm
with pinned native field/claim/group helpers and an independent arithmetic
reference. It does not run native define, Fiat–Shamir, CUDA, actual PCS pad
generation, receipts or a complete proof. R13 geometry is frozen; the held
R14 split-width work requires its own census.

The baseline `k_fold_rows` scans every matrix row for each output column
and each physical batch of at most four public rho vectors. The prior
zero-skip candidate can omit zero-row matrix reads but still scans every
row and rho. This experiment instead iterates sorted public row-union
indices. A refinement packs a four-bit group-membership mask beside each
row: `word = row << 4 | flags`. It also avoids rho loads for groups that do
not use that row. No private matrix value enters either plan.

`build_plan` uses the prior independently checked source structural support,
including masks and dense proximity. `build_public_rho_plan` is an alternative
that scans both limbs of the current verifier-reconstructible opening rho;
it can fit inside `dev_fold_rows` without changing the `EncodedStore` trait.
Its public provenance must be reviewed at the native caller. Plans are
rebuilt per call; no cross-proof plan, mask, commitment or opening reuse is
claimed. The frozen native mask-site and refusal checks remain mandatory.

| Frozen R13 A core, 8B/T128, N16384 | noDD | DD32 |
|---|---:|---:|
| Matrix rows / rho vectors including proximity | 4,577 / 37 | 4,455 / 39 |
| Dense chunk4 row visits per column | 45,770 | 44,550 |
| Original-order indexed union visits | 9,654 | 9,328 |
| Union-only rho reads per column | 24,885 | 32,857 |
| Membership rho reads per column | 9,804 | 9,561 |
| Original-order plan upload payload, B | 38,616 | 37,312 |
| Dense matrix + rho logical operands, B | 50,392,989,696 | 51,385,466,880 |
| Union-only matrix + rho + index, B | 8,421,507,072 | 10,447,224,832 |
| Membership matrix + rho + index, B | 4,468,113,408 | 4,340,318,208 |
| Membership logical operand reduction | 91.1335% | 91.5534% |

These are **source logical operand counts before compiler/cache/broadcast**,
not physical DRAM traffic, instruction counts or GPU timing. The source-sized
full matrix was not materialized: full-width accounting uses the public
plans and the source loop. Source-row tests use only eight synthetic columns.
Do not multiply these figures into an 8B proof rate.

Index reads are charged per output column: 632,684,544 / 611,319,808 logical
bytes in original order, despite the small one-time upload. All rho uploads
(2,709,584 / 2,779,920 B), matrix encoding/commitments, allocations, output
D2H, pads, masks, proximity and other phases remain. Cache/broadcast may
greatly reduce physical rho/index traffic already, so these counts do not
establish that index traffic is a native bottleneck.

The previous local pair-swap plans also pass: 5,658 / 5,794 union visits,
22,632 / 23,176 B metadata and 3,682,467,840 / 3,645,505,536 logical operands
with membership. These plans are prior local optima only; their planning and
rho clone/scatter costs remain extra. Reordering is unnecessary for the
original-order candidate.

A useful negative result: reversing noDD groups reduces union visits
9,654 → 9,553, but raises union-only logical operands
8,421,507,072 → 11,868,504,064 B, **+40.9309%**. Dense proximity moves into
a fuller physical batch, increasing rho reads. A matrix-only packing
objective is invalid for the plain union loop. With membership, total rho
reads instead equal the sum of group supports, independent of order.
Neither objective is a device-time optimum.

Validation: 14 fixtures (12 small synthetic unadmitted shapes with
zero/one/random challenge points, two source-sized R13 metadata cases),
109,512 exact base-field-matrix/Fp2 fold comparisons, including three
synthetic pad columns. 16,416 comparisons use source row counts with eight
columns. Three paths are checked against independent schoolbook u128 modular
arithmetic: union-only, structural membership, and current-public-numeric-rho
membership. Native rho, imaginary-only rho, and supported coefficients set
to zero are tested. The latter are linear-algebra fixtures, not claims that
such witnesses pass native mask admission.

376 controls/assertions cover imaginary-only nonzero output, missing,
duplicate, out-of-range and unsorted indices, zero/wrong membership flags,
wrong group/output order, omitted batches, missing reserved mask/proximity
rows and stale order. The Python set-insertion model passes 1,206 checks
against all prior source supports and all emitted plans. References were
authored by this researcher; this is not external independent review.

Seed `202610290151`. Final compile 2.7368 s / 187,744 KiB peak RSS; probe
0.9227 s / 29,116 KiB; independent census 0.0654 s / 18,564 KiB; cost stage
0.0172 s / 10,472 KiB. Original-order Rust plan construction 0.286 / 0.276 ms
and validation 0.285 / 0.289 ms, n=1 on a shared host; these are component
diagnostics, not performance acceptance. Each stage has one CPU affinity,
nice 19, 40 s CPU / 45 s alarm / 50 s parent timeout and 384 MiB address-space
caps. Serial worker, one rustc codegen unit; compiler auxiliary thread count
unmeasured. Device: Intel Core Ultra 9 185H, WSL2, Rust1.75, Python3.10.12.
Estimated memory: 300 MiB compile, 96 MiB other stages. No GPU/native build.
Initial Rust borrow-check failure and the earlier passing result are retained.

Reproduce each bounded stage separately from the research directory:

```text
python3 experiments/public-indexed-fold-20261029/run_bounded.py compile
python3 experiments/public-indexed-fold-20261029/run_bounded.py probe
python3 experiments/public-indexed-fold-20261029/run_bounded.py census
python3 experiments/public-indexed-fold-20261029/run_bounded.py cost
python3 experiments/public-indexed-fold-20261029/run_bounded.py audit
```

The harness was derived from the retained prior wrapper; its actual native
field, allocation, offsets, slice, claim-point, grouping/rho and audit helpers
are pinned and audited. Eq helpers use serial iterators. Public shape/slot
schedules and the transcript stand-in remain synthetic. `memory-index.json`,
`native-pins.json`, `seam-pins.json`, hardware, execution logs and the final
artifact manifest retain provenance. No Git operation was used.

Integration seam: `fold_rows_multi_zk → EncodedStore::fold_rows →
dev_fold_rows → k_fold_rows`, max four. `candidate-kernel.cuh` is an
**uncompiled owner-review sketch**, not a production patch or tested CUDA.
Register its name in the native `FUNCS`, construct/upload a current public
plan inside the adapter, retain its lifetime through synchronized output
copy, and keep existing rho/output layouts. Require rows < 2^28, canonical
unique indices and valid flags, or fall back to the existing dense kernel.
Keep all length audits, native mask checks, fresh masks/pads/proximity,
H sum/U, output order, RNG draw order, FS and PCS. No private sparsity dispatch.
Main/Claude reviews and integrates; no production file was changed.

Before device implementation, the owner should measure actual current
public group/support counters and exclusive rho H2D, allocation, kernel,
D2H, pad/open and enclosing clocks. Existing `secs_fold` encloses multiple
operations; aggregate H2D statistics omit this rho upload. Re-pin R14
separately. If material, use current shared build/heavy locks for native
golden/refusal/RNG/FS/PCS/privacy and independently verified full-receipt and
resident-workload A/B checks, plus CUDA registers/spills/cache counters.
The held owner pipelines were not touched or duplicated.

End-to-end ceiling: `N/(T-C_removed_exclusive+A_added)`; native exclusive
fraction f is unknown, and free deletion is bounded by `1/(1-f)`. Any
value/limb/order/refusal/mask/RNG/FS/PCS/privacy mismatch, altered native
support, overhead erasing gain, or no verified enclosing benefit falsifies
promotion. No numerical high-end-GPU forecast is justified.

The first three ranked hypotheses remain owner whole-prover GPU/resident
workloads, admitted context/DD/fidelity scaling, and exclusive phase/capacity
measurements. The highest feasible local follow-up, prior #72, was tested;
all 72 prior objects are preserved. #73 records the indexed membership
result; #74 asks whether consecutive public row/flag intervals can reduce
index decoding without extra occupancy cost. Next local experiment:
independent run census and interval/list/dense fold differential, with
missing, overlapping, truncated and out-of-range span controls. New owner
measurements take precedence over this queue.

LIVE research newly assessed [October2026 SpMV bottlenecks](https://eprints.gla.ac.uk/396825/),
[August2026 DB-SpMSpV](https://arxiv.org/abs/2608.16308),
[older2024 JIT allocation work](https://ieee-hpec.org/wp-content/uploads/2024/09/140.pdf),
and a [GPU SpMV repository](https://github.com/VSJ001/Cache-Aware-and-GPU-Accelerated-Sparse-Matrix-Vector-Multiplication).
[DeepProve](https://github.com/Lagrange-Labs/deep-prove) was refreshed for
scope, release provenance and its custom license. No foreign implementation
was executed or adopted; no external commit was inspected. Five source
records append 1005 → 1010, with dates/nulls and exact fetch blockers. Native
LIVE search results and opens are retained; crawl dates are not release dates.

New independently verified full-stack proofs / passes / positions: **0/0/0**.
Actual context and accelerator: **none**; modeled T128; one pinned CPU worker.
Witness/proof/serialization/verification/startup/prefill clocks, startup
fraction, proof latency/bytes and steady-state/total-workload rates are
**unmeasured**. No prefill, resident passes or decode ran. Larger workloads
remain allowed; dense attention can grow quadratically with context.
Complete private 8B **>=50 proved tokens/s remains unachieved**.

Only research outside runtime was written. No production/Git/receipt/
calibration/instruction/safety/reviewer edits, GPU job, install, external
write/message, purchase, privilege escalation or merge. Saved reports do not
establish user-message delivery or supervisor liveness.
