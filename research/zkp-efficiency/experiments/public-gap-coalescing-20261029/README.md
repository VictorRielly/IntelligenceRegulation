# Public zero-gap interval coalescing — cycle0153

Run `20261029T225649Z-78d0981c`; checkpoint 2026-10-29T23:07:16.558444+00:00; deadline23:16:49UTC.

**No native proving speedup measured.** The falsifiable local question was
whether fewer run starts/metadata can offset extra work when same-flag
intervals coalesce across a verifier-public all-zero gap within one max4
batch. FrozenR13 8B/T128 A baseline is74/81pure spans and
3.845128192/3.739615232GB logical matrix+rho+metadata operands (noDD/DD).
The prior hybrid fallback is3.844997120/3.739615232GB. No exclusive
native GPU phase time is known, so these byte counts are not a speed model.

Merging a gap of g>=1rows with k>=1member groups saves one8-byte interval
but adds g*(8+16k)logical operand bytes per output column, plus2gk basefield
multiplications and2gk limb additions. Therefore **every nonempty merge
worsens this source operand objective by at least16bytes/column**. We
parameterize an additional run-start cost H in uncalibrated byte-equivalent
units: merge only if g*(8+16k)<8+H. H is a sensitivity parameter, not GPU
time or measured physical bandwidth. Extra arithmetic costs make that
inequality only a necessary condition for a useful complete result.

|FrozenR13 A, original group order, N16384|noDD|DD32|
|---|---:|---:|
|Source rows / rho vectors including proximity|4577 /37|4455 /39|
|Ordinary pure spans, H0→H64|74→73|81→80|
|Ordinary logical operands, H0→H64,GB|3.845128192→3.845390336|3.739615232→3.739877376|
|Ordinary maximum eligible removals, H1,000,000|2|2|
|Protected data-zero-every-third fixture spans,H0→H64|3077→73|2974→80|
|Same fixture pure metadata,B,H0→H64|24,616→584|23,792→640|
|Same fixture logical operands,GB,H0→H64|3.034316800→3.832807424|2.950955008→3.726114816|
|Increase versus exact intervals|26.3153%|26.2681%|
|Increase versus prior hybrid fallback|26.3317%|26.2849%|
|Extra basefield multiplies per modeled core,H64|99,811,328|96,894,976|

The numerical-zero fixture clears **data rows only**, retaining every
structural mask/proximity member even when numericzero. Thus its3077/2974
span counts intentionally differ from the prior all-row-zero fixture's
3242/3134. Those prior results remain valid for their stated different
algebra fixture. Both are synthetic cancellation controls, not admitted
native challenge distributions or authorization to alter mask checks.
Even ordinary H64 saves only8Bpure metadata and adds32,768basefield
multiplies per modeled core. At huge H, the second eligible boundary
bridges thousands of rows; smaller metadata plainly fails as a device-time
objective. All rho uploads2.710/2.780MB, allocations, output/D2H, pads,
encoding/commitments, fresh masks/proximity and other proof phases remain.

Validation:231,200 exact independent schoolbook-u128 modular output
comparisons across14native-helper fixtures, including24,320source-row/
narrow8 comparisons;367controls;185,031independentPython assertions.
An independent immutable-cut formulation reproduces every plan count.
Exhaustive33,362cut partitions over840objectives confirm the threshold
policy's optimum within equal-flag/all-zero-gap chains for the stated
additive cost, not among arbitrary GPU kernels. Five numeric modes and
seven H values include imaginary-only coefficients, alternating and long
zero gaps. Controls cover stale unflagged real/imaginary values, real-only
zero predicates, invalid flags/order/shape/overlap, omitted masks/proximity,
and zero-valued protected support. A newly live flagged gap is algebraically
covered but requires refreshed public provenance before acceptance; the
fresh-map positive control passes. References are independent code by
this researcher, not external review.

The inherited harness pins native field, row/group/audit/claim helpers;
its slot schedule and transcript are synthetic stand-ins. Native define,
real FS, actual PCS pads, CUDA, complete receipts and privacy acceptance
were not run. Source-row matrices have8columns; N16384 only multiplies
source operand counts. Small fixtures add3synthetic columns, not real PCS
pad generation. The candidate is gap.rs; no production patch or uncompiled
new CUDA candidate was prepared. Integration seam remains
fold_rows_multi_zk→EncodedStore::fold_rows→dev_fold_rows→k_fold_rows.
Preserve native assert_mask_sites, all fresh randomness/pads/proximity,
RNG/FS/PCS/order and refusal behavior. No matrix-dependent scheduling or
mask/opening reuse. CurrentR14 split geometry needs a separate repin.

Expected end-to-end ceiling remains N/(T-C_removed_exclusive+A_added);
even free deletion is bounded by1/(1-f), with native exclusive f unknown.
Existing secs_fold encloses CPU flatten,H2D,allocation,kernel,D2H, so it
cannot establish removed kernel cost. All preprocessing/validation and
register/occupancy/cache costs must be charged. **Do not promote gap
coalescing as a memory optimization.** It can be reconsidered only after
measured native run-start savings exceed extra complete costs and all
receipts independently verify with improved enclosing workload time.

Rankings retain76prior hypotheses exactly and add77tested negative and
78currentR14 A/H/endpoint census. Global priorities remain1verified
high-endGPU/resident1/2/4/8 workloads,2admitted context/DD/fidelity scaling,
3exclusive native phase/capacity clocks. The next bounded local experiment
reads/pins current held or frozen R14 public source, independently computes
all A/H/endpoint row bands, reserved masks/proximity and max4 widths, and
compares current native layout census if present. Any mismatch falsifies
transplanting R13 counts. No held owner sources or duplicate builds.

LIVE primary-source search refreshed
[cuPQC0.6](https://nvidia.github.io/cuPQC/releases/v0.6/) and
[cuda-zkp-ntt](https://github.com/Artemarius/cuda-zkp-ntt);
newly assessed [AsyncSparse](https://arxiv.org/abs/2604.17834),
older [SMASH2019](https://arxiv.org/abs/1910.10776), and
[BenX](https://arxiv.org/abs/2609.31087); refreshed
[QingmingHIP](https://github.com/uulong950/qingming-g64-ntt) interface provenance.
Six records append1016→1022; exact URLs, publication/update dates or nulls,
license scope and fetch blockers are in sources-cycle.jsonl. Eleven LIVE
response hashes and search provenance are retained without full page bodies.
No external commit ID was verified and no author performance was reproduced.

The latest owner status is22:50UTC: Shieldstral classifier privacy
statementDRAFT under independent review. Decisions22:23recordsA5one-load
batch READYWITHFIXES, restricted to one post/one process; it is not blanket
cross-post/model/mask cache authority or private8B throughput evidence.
R14 state19:14:14and matched16:53diagnostic are unchanged. The latter's
two-block sharedCPU public-sparse49.2→35.1s noDD/48.7→33.8s DD excludes
initial fixture/endpoint preparation and later verification; reviews remain
owed. R13 8BT512 remains unregistered at94.48/94.80bits. No target amendment.

Seed202610290153; one pinned nice19CoreUltra9CPU. Final standalone
compile3.392s/200,436KiB;probe0.671s/29,548KiB;census0.671s/20,712KiB;audit0.067s/22,636KiB.
Each stage:40sCPU/45salarm/50sparent timeout,384MiB address-space cap;
estimated300MiB compile/96MiB otherwise. Numerical/Python workers one
thread; compiler auxiliary threads unmeasured with oneCPU affinity/codegen
unit. First passing artifacts retained before two additional protected-zero
positive controls.361provenance checks pass:11nativepins,6seams,
6owner documents unchanged; AGENDA unchanged. Search-provenance URL regex
was corrected after inspection; response hashes did not change. An initial
tool metadata diagnostic enumerated string indices and was output-truncated;
no experiment data, command permission or sandbox setting changed.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual context and accelerator: **none**; modeled context T128; one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization,
verification, startup/initial-prefill duration and fraction, proof
latency/bytes, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model series or decode ran. Larger workloads
remain allowed; attention can grow quadratically with context. Complete
private 8B **>=50 proved tokens/s remains unachieved**.

Carried older CPU8B baseline, not rerun/reverified/newly counted:
T128/L32, one16-thread pass, GPU off. Total478.737s=0.267370 positions/s;
prove_run393.785s includes witness98.348s/load17.595s. Sealing84.824s
precedes it, with overlapping load27.151s/witness80.897s. Receipt922,711,264B;
verify42.709s plus load13.681s. Isolated serialization, startup fraction and
steady slope unknown. No GPU conclusion.

Only research outside runtime was written. Production, Git, receipts,
calibration, instructions, safety gates and reviewer files were untouched.
No GPU/native build, dependency install, downloaded script execution,
external write/message, purchase, privilege escalation, Git operation or
merge. Main/Claude reviews/integrates. Saved reports do not imply delivery
or supervisor liveness.

[Handoff](../../handoffs/20261029-public-gap-coalescing.md) · [Dated report](../../progress/20261029T225649Z-78d0981c.md).

Reproduce each serial bounded stage from the research directory:

```text
python3 experiments/public-gap-coalescing-20261029/run_bounded.py compile
python3 experiments/public-gap-coalescing-20261029/run_bounded.py probe
python3 experiments/public-gap-coalescing-20261029/run_bounded.py census
python3 experiments/public-gap-coalescing-20261029/run_bounded.py audit
```

prepare_artifacts.py and finish_reports.py are one-cycle report generators,
not the numerical reproduction commands; avoid rerunning the append report.
