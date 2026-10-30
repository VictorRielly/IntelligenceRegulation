

## Cycle0155 — Exact five-vector tail fold and conditional scan ceiling

Run `20261030T005649Z-506c4db2`, October30,2026 UTC.
**No native proving improvement measured; complete private8B >=50 proved tokens/s remains unachieved.**

The leading hypothesis tests whether a fresh proximity vector that leaves
4+1 at the end of a public rho list can ride in a dedicated final5 batch.
The current PCS sends chunks4 and the current CUDA adapter asserts max4.
The research planner changes only k>=5,k mod4=1, keeps all output positions
ordered, and retains the final proximity vector. The candidate source copies
the exact current `k_fold_rows` body with max5 and a separate
`k_fold_rows_tail5` symbol. No production patch applied or CUDA compilation.
Ordinary max4 calls should keep their original symbol; merely changing the
PCS chunk size violates the existing backend contract. An optional
whole-opening backend method defaulting to chunks4 is a proposed interface,
not an implemented or accepted change.

Baseline: each max4 call flattens/uploads rho,allocates output,launches,
downloads/converts and rereads the systematic matrix. Eliminated work is
conditionally one complete matrix scan,launch and per-call allocation/
submission pair. No native work has actually been removed. Total rho
coefficients/upload bytes,output download bytes,base-field multiply-adds,
synthetic/native pad folds,all masks/proximity,commitments,serialization and
verification remain. Added cost is the fifth Fp2 accumulator:80B source
payload versus64B, not a compiled register count. The largest affected
per-call rho+output device scratch increases25%; spills,occupancy,cache
behavior,peak overlap and complete device runtime remain unknown.

| Conditional f_e9 standalone generic core | Baseline matrix source B | Candidate B | Fewer source B |
|---|---:|---:|---:|
| T128,noDD |8209432576|7748452352|460980224 (5.61525%)|
| T128,DD |8316649472|7908229120|408420352 (4.91088%)|
| T256,noDD |19128909824|18063294464|1065615360 (5.57071%)|
| T256,DD |17947164672|17041719296|905445376 (5.04506%)|

These are explicit Shieldstral3072/9216 layouts and historical generic
claim groups, including two external endpoints. They are not current
native grouping, a multi-block/classifier/full-run count, or8B R14 geometry.
Four historical builder producer files still differ from the current held
source, as preserved by cycle0154. Current internal endpoint grouping is
unmeasured. A four-group internal endpoint would have5rhos and might also
benefit; no full-run multiplier is applied. Rho reads are warp-uniform and
may hit cache, so logical operands are not physical DRAM traffic or time.
Correction to prior shorthand: T128/f_e9 A3517*16384*8 is460980224B;
461373440B corresponds to3520rows. Prior files are retained; their exact
layout differential is unaffected.

612Rust synthetic fixtures compare the unchanged native scalar Goldilocks
field and serial-adapted extracted host fold against source-loop emulation
and an independent schoolbook-u128 modular oracle.228780scalar limbs,
including3synthetic pad columns,agree. Rows0/1/3/33 and actual layout row
counts3517/3272/3395/3116; columns1/7/17; rho counts0/1/2/4/5/9/12/13/57/59.
Dense,sparse,pure-imaginary,modulus-boundary and protected-tail inputs are
covered.141controls=130public planner cases+3shape refusals+8fault checks
for lost imaginary values,omitted proximity,changed protected rows,
reordering and fresh-call state. Large-row fixtures use7columns; no large
matrix allocation. Zero/odd shapes are primitive algebra edges,not admitted
native profiles. Synthetic source rows cover every physical row; they do
not reproduce native claim-derived weights or certify masking discipline.

375C++ fixtures compile the exact extracted max4/max5 kernel loops under a
CPU control-flow/u128-arithmetic shim:30750scalar limbs agree,with guarded
outputs and overlaunch on every fixture.25public vector fixtures also match
1050independent Python bigint limbs using one reduction after each full dot
product.1817Python assertions include cost/source/arithmetic checks.
The independent references were authored by this researcher,not externally
reviewed. This is not CUDA arithmetic/ABI/register/race evidence; actual
FS,claims/groups,mask assertions,generated PCS pads,encoding,proof bytes,
privacy and independent native receipt verification remain unrun.

Expected complete ceiling remains N/(T-C_removed_exclusive+A_added), with
free deletion bounded by1/(1-f) for unknown exclusive f. If every elapsed
unit were proportional only to the counted matrix operands,the conditional
T128 ratio would be1.059493x/noDD or1.051645x/DD. That assumption is unmeasured
and false as a description of the full prover; these ratios are not a GPU
throughput prediction. `secs_fold` encloses flatten,H2D,alloc,launch,D2H and
conversion and cannot identify saved exclusive kernel cost. Preserve its
known omission of rho uploads from local H2D byte accounting as an owner
telemetry issue. Falsify promotion on any native limb/order/refusal/RNG/FS/
PCS/privacy mismatch,no actual4m+1tail,capacity/spill regression,or slower
enclosing independently verified workload.

All80prior hypotheses are retained exactly;81records this test and82adds a
new question: can one-opening public-rho/output staging remove repeated
allocation/submission calls while keeping max4? All bytes/scans and fresh
randomness remain charged. Next local experiment: independent ordered
slice/descriptor/lifetime/peak accounting for full staging and bounded ring
staging,including partial-failure cleanup,unchanged default max4 and fresh
calls. No persistent private cache is proposed. Global rankings remain
1owner verified high-endGPU resident1/2/4/8 workloads,2admitted context/DD/
fidelity scaling,3exclusive phase/capacity clocks.

LIVE primary searches covered memory traffic,GPU commitments/NTT and
quantization/arithmetic. Newly assessed older [exactSpMV2010](https://arxiv.org/abs/1004.3719)
provides bounded modular-reduction and repeated-matrix preprocessing
methodology. Local arithmetic controls reject its small-modulus floating/
uncarried accumulation as a full-width Goldilocks replacement; two maximum
products already exceed u128. Newly assessed [Karatsuba–NTT2026](https://link.springer.com/article/10.1007/s44443-026-00722-6)
supports measuring occupancy alongside fusion; no hiding-PCS compatibility
or implementation license was established from its repository listing.
Refreshed [cuda-zkp-ntt](https://github.com/Artemarius/cuda-zkp-ntt/releases)
retains an invalid full hierarchical transform despite attractive timing;
keep it excluded. Refreshed [zkDuel](https://github.com/snarang181/zk-duel)
reinforces independent arithmetic and register/wall-clock separation.
Refreshed [StateSync](https://arxiv.org/abs/2610.14849) October26v2/v1.2.1
preserves the distinction between prepared service performance and completed
verified request delivery; no private8B result transfers. Five records
append1027->1032. Exact dates/nulls,license boundaries,fetch failures and
nineLIVEbatch response hashes/provenance retained. No external commit
content or author performance reproduced; no foreign code executed.

Required six project docs match prior snapshots. Owner CURRENT_DEV_STATE
advanced to00:28:47UTC,recording retired old waiters and a detached recovery
intent; this does not independently establish liveness. Source holds remain
in force; no duplicate build launched. The classifier privacy draft is still
NOT ACCEPTABLE YET under the23:13independent review,with gate round22 and
wording/application conditions owed. A5 public-table reuse is onepost/
oneprocess,not generic cross-post/model/mask cache authority. No target
amendment. All30pinned source/document/owner files stayed unchanged after
preparation. Neither source equality nor constructor arithmetic certifies
current full-run proof/privacy acceptance.

Seed202610300155;one nice19/pinned Intel Core Ultra9 185H CPU worker.
Rust compile1.084s/158288KiB;probe0.317s/8824KiB. C++compile0.633s/
76496KiB;probe0.066s/7600KiB. Final audit0.036s/15240KiB;shared-host
correctness diagnostics. Each leaf40sCPU/45salarm/50sparent timeout,
384MiB address cap;estimates300MiB Rust compile,128MiB C++ compile,96MiB
other stages. Compiler auxiliary threads unmeasured;oneCPU affinity and
oneRust codegen unit. Two audit coding mistakes were corrected with both
failed logs retained: only f_e9 fixtures carry historical group records;
P-1 is exactly representable in binary64,so use P-2 and the full product
as controls. No candidate/kernel result changed. One tool metadata diagnostic
printed character indices;no experiment data,permission or limit changed.

New independently verified full-stack proofs / passes / positions: **0/0/0**.
Actual context and accelerator:none;modeled T128/T256;oneCPU worker.
Witness,proof,serialization,verification,startup/initial-prefill clocks,
startup fraction,proof latency/bytes,steady-state and total-workload rates:
**unmeasured**. No long-context prefill,resident-model series or decode ran.
Larger workloads remain allowed; attention can grow quadratically.

Carried older CPU8B baseline,not rerun/reverified/newly counted:T128/L32,
one16-thread pass,GPUoff.Total478.737s=0.267370positions/s;prove_run
393.785s includes witness98.348/load17.595. Sealing84.824s precedes it,
with overlapping load27.151/witness80.897. Receipt922711264B;verification
42.709+load13.681s. Isolated serialization,startup fraction,steady slope
unknown. No GPU conclusion.

Only research outside runtime written. Production,Git,receipts,calibration,
instructions,safety gates and reviewer files untouched. No GPU/native build,
install,downloaded script execution,external write/message,purchase,
escalation,Git operation or merge. Main/Claude reviews and integrates.
Saved reports do not imply delivery or supervisor liveness.

[Experiment](experiments/five-rho-tail-20261030/README.md) ·
[Handoff](handoffs/20261030-five-rho-tail.md) ·
[Dated report](progress/20261030T005649Z-506c4db2.md).
