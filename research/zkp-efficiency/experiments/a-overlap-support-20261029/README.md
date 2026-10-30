# Frozen R13 A overlapping support — cycle 0150

Run `20261029T195649Z-795daf31`, October 29, 2026. **No native proving
improvement measured.** This is a public-source component experiment, not
an actual native `define`, Fiat–Shamir, GPU invocation or full proof.
Frozen R13 source geometry is used; R14 split-width geometry differs.

The question was whether A's actual offsets and transformed claim points
support the prior zero-skip kernel, without importing H's disjointness.
Native `AccuracyIds` allocation, `Shape::a_plane_doms`, A offset loop,
`B::a_slice`, `claim_point`, `build_claim`, grouping/rho helpers and audit
were extracted unchanged. Eq iterators are serial. Local Shape/Layout
wrappers and source-read slot schedules supply public metadata. A separate
Python named-plane/interval/symbolic-point model agrees with every emitted
plane name, offset, descriptor, group and support row in all 14 cases.
Native constructor/slot polynomial evaluation and private data were not run.

| A per core, N=16384, context128, generic distinct keys | noDD | DD32 |
|---|---:|---:|
| Rows / data / sites |4577 /4283 /146|4455 /4155 /149|
| Ordinary groups / rho vectors |36 /37|38 /39|
| Dense chunk4 row visits |45,770|44,550|
| Existing-order structural visits |9,654|9,328|
| Dense logical matrix reads, B |5,999,165,440|5,839,257,600|
| Structural upper reads, B |1,265,369,088|1,222,639,616|
| Matrix-read reduction |78.9076%|79.0617%|
| Data rows claimed by >1 evaluation group |508|509|

A is **not** an H-like partition. These overlapping sets include every
reserved mask pair; proximity is dense. Host rowfold already skips zero rho.
The prior device candidate could exploit the source support. This cycle
changes no production work. Counts exclude actual host pads, matrix
construction and every other proof phase; they are not physical DRAM.
Generic counts must not be hardcoded when corner challenges merge keys.

With prior H original-order support, combined A/H logical matrix reads
fall from 7,725,383,680 /7,504,134,144 to upper bounds
2,415,919,104 /2,318,139,392 B, or 68.7275% /69.1085%. No layer multiplier.

A bounded public pair-swap planner gives 5,658 /5,794 A visits, using
7 /10 swaps and 17.9 /27.3 ms in one Python diagnostic. It is a pair-swap
local optimum, **not a global optimum or a device-time optimum**. Full
chunks precede the sole partial chunk. Its A-only read reductions are
87.6382% /86.9944%; combining prior optimally packed H gives
80.9128% /80.6574% fewer logical matrix reads. Actual plans were restored
and checked on source row counts with five synthetic base-field columns,
without materializing the source-sized matrix. Planning, locality, copying,
registers and device time remain separate costs. Simple existing-API rho
clones add 2,709,584 /2,779,920 B; streaming bounds active payload to
292,928 /285,120 B, plus headers, outputs and planner state.

**Denominator check:** the zero-skip kernel still scans every row and loads
every public rho operand. Source per-output-column accounting retains
44,393,824,256 /45,546,209,280 logical rho bytes over all message columns.
Including them, matrix+rho logical-operand reductions are only
9.3938% /8.9843%. This is before compiler/cache/warp broadcast; it is not
physical traffic or a timing bound. The prior source accumulator plus
weights occupies 128 B/thread instead of a 64 B accumulator; compiled
registers, spills and occupancy remain unknown. Structural nonzero MAC
counts decrease 94.21% /94.50%, also without an instruction/time claim.

Validation: 14 Rust cases (two source-sized metadata cases; twelve small
synthetic, unadmitted shapes with zero/one/random points). Independent
schoolbook u128 arithmetic checks 27,540,288 full-cube coefficients;
5,172 restored values include all synthetic message columns plus three
appended synthetic pad columns. Actual PCS pad generation is not executed.
The two source-row/narrow-five-column base-field cases check 380 packed
values. Five small-case control classes run 60 times: wrong scatter,
proximity intrusion, zero terminal mask, false A-disjointness, and changed
point. Two source-plan wrong-scatter controls bring the total to 62.
The independent Python census passes 517 checks; final artifact/source
helper audit passes 64. This is one researcher's independent reference,
not an external review or native receipt validation.

Seed202610290150. Final compile2.6373s /183,748KiB RSS; probe0.6713s
parent (0.6373s internal) /25,748KiB; census0.1663s /17,388KiB;
cost0.0331s /12,564KiB; audit0.0653s /31,120KiB. One CPU affinity,
nice19,40s CPU /45s alarm /50s parent and384MiB address-space caps.
Memory estimates300MiB compile /96MiB remaining stages. Device: Intel Core
Ultra9 185H; Python3.10.12, Rust1.75, WSL2. Rust compiler auxiliary thread
count unmeasured; one affinity/codegen unit bounds CPU use. Worker code is
serial. No GPU or native build. Retained failures: first compile import,
unpadded hidden-axis log, absent census key, and artificial small-row limb
subslice modulo. Corrected runs and the earlier passing result are retained.

Reproduce bounded stages separately from the research directory:

```text
python3 experiments/a-overlap-support-20261029/run_bounded.py prepare
python3 experiments/a-overlap-support-20261029/run_bounded.py compile
python3 experiments/a-overlap-support-20261029/run_bounded.py probe
python3 experiments/a-overlap-support-20261029/run_bounded.py census
python3 experiments/a-overlap-support-20261029/run_bounded.py cost
python3 experiments/a-overlap-support-20261029/run_bounded.py audit
```

`packing_plans.rs` is a retained input from the public census; the audit
checks it against the independently recomputed plans. `native-pins.json`
and `artifact-manifest.json` retain source and artifact hashes. Final
synthetic claims share extension coefficients within slots, including the
two bilinear extension rounds; no native FS or randomness law is claimed.

Integration: `fold_rows_multi_zk -> EncodedStore::fold_rows -> dev_fold_rows
-> k_fold_rows`. Prior unapplied patch:
`../multi-rho-rowfold-20261029/native-public-rho-skip.patch`. A public planner
must restore logical outputs before pad concatenation/absorption/opening.
All masks, pads, fresh randomness, proximity, H sum/U, refusal behavior,
RNG draw order, FS and PCS remain. No private sparsity or result/opening
reuse. Main/Claude reviews and integrates. Native golden/refusal/receipt,
current privacy gates, actual CUDA registers/device and independently
verified complete-workload A/B remain prerequisites under owner locks.

Ceiling: `N/(T-C_removed_exclusive+A_added)`; exclusive native fraction f
is unknown, and free deletion is bounded by `1/(1-f)`. Any native counter,
value/order/refusal/mask/RNG/FS/PCS/privacy mismatch, spill/copy/planner
regression, or no verified enclosing gain falsifies promotion.

LIVE sources searched: [StateSync October26v2](https://arxiv.org/abs/2610.14849),
[efficient-sumcheck](https://github.com/compsec-epfl/efficient-sumcheck),
[MegaZK](https://github.com/THU-HAS/MegaZK), newly assessed
[2025 reordering methodology](https://arxiv.org/abs/2506.10356) and
[2026 HE diagonal objectives](https://arxiv.org/abs/2604.04683). They support
scope/methodology screens, not native performance. Five appended records
(1000→1005) retain exact dates/URLs, null update dates/commits where unknown,
license limits and Cachemiss failures. Eight raw LIVE batches retained.
StateSync current main's BSL1.1 body was inspected; no implementation was
adopted or executed. The search result dated November16,2026 was excluded.

Ranked priorities remain owner whole high-end GPU verified resident1/2/4/8
workloads, admitted context/DD/fidelity scaling, exclusive phase/capacity
clocks. All70 previous hypothesis objects are preserved;71 is the tested A
support,72 asks whether public sorted row-union indices remove empty scans
and rho loads. Such indices would be38,616 /37,312B in original order or
22,632 /23,176B after this packing, including dense proximity. No index
kernel was tested. Next local: bounded exact indexed-loop/base-field model
with malformed index, imaginary-rho, mask/pad/proximity/order controls.
New owner measured bottlenecks take precedence.

Owner state at19:14:14 reports existing held R14 build/observer pipelines;
this is not liveness. Its matched n1 shared-box two-block public sparse
synthetic comparison remains49.2→35.1s noDD and48.7→33.8s DD, excluding
initial fixture/endpoint preparation and later verify. Reviews/privacy are
owed; no full8B high-end GPU conclusion follows. D44/D45/S4 do not amend
this target. R13 8B/T512 remains unregistered at94.48/94.80bits.

New independently verified full-stack proofs / passes / positions: **0/0/0**.
Actual context / accelerator: **none**; modeled context128; one CPU worker.
Witness, proof, serialization, verification, startup/prefill duration and
fraction, proof latency/bytes, steady-state and total-workload rates:
**unmeasured**. No prefill, resident-model series or decode ran. Larger
workloads remain allowed; attention can grow quadratically with context.
Complete private8B **>=50 proved tokens/s remains unachieved**.

Only research outside runtime written; no production/Git/receipt/calibration/
instruction/safety/reviewer edits, installation, foreign execution, external
write/message, GPU job, escalation, purchase or merge. Saved reports do not
establish user-message delivery or supervisor liveness.
