# Unapplied candidate: lazy D original endpoints

Cycle0078, `20261019T101854Z-3562a78f`, 2026-10-19. Main/Claude reviews and integrates;
no merge, production edit, device run or native performance result here.

Interface: [run.py](../experiments/dzc-lazy-endpoints-20261019/run.py),
`lazy_row(raw,p,lazy=True)` at line130. `raw[j]=(lo,hi)` for the current
MSB row pair; proof-local `p` from `prior-run.py::plan`; output five Fp2
coefficients, then common round reduction and `convert` to unchanged ordered
`0..=degree` unmasked evaluations. The driver retains recovery/pending,
transcript absorption, fresh masks/challenges and original folds/finals.

Patch location: source-pinned owner tree
`ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/argument.rs::SC_DZC`
(line1551 in captured source), behind
`zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`. All six live source hashes
are in `source-pins.json`; snapshots in `native/`. No patch is applied.

Validation:30fixtures,N2/8/32,seed2026101978; current public T128 catalogs
for TinyLlama/Llama3 plus generic padding/limb/helper controls. All tested
coefficients/messages/original finals agree with captured full Rust closure,
independent Python clauses/direct cube and prior coefficient plan. Eight
synthetic controls and221independent audit checks pass. These are not native
proof acceptance/refusal/privacy gates. Main8.612566s/RSS47748KiB;
compiler138144KiB; audit0.260665s/RSS24352KiB, one nice19 CPU0 thread,
59s/512MiB limits. Commands/status retained alongside the code.

Counted result: complete logical peak129→77Fp2words with identical arithmetic,
118endpointreads/59differences, every59originalfold/final retained. Includes
endpoint high-value transient and round accumulator; excludes primitive scalar
scratch/plan/allocator/native registers and enclosing original tables/proof.
This saves52logicalwords/832bytes per active row worker, not VRAM per row.
Python graph/dictionary deliberately retains values; no RSS saving measured.
A direct source port retaining the cache until function end loses the gain
(136words); a port rematerializing on every use adds reads118→198 and
subtractions59→99. Static named locals/actual compiler liveness are required
before treating the count as native-resource evidence. Dynamic array indexing
can cause local-memory traffic even when the logical schedule is good.

Owner prerequisites: actual profile/challenges and bound g_u8, complete degree
and all padded/generic branches/aliases; seeded bytes and RNG schedule,
original sampler/refusals/extension/mask/final-opening order; all native finals,
fresh receipt verification/tamper controls and joint-view privacy gate. No
mask/opening reuse, extra private claim, helper commitment deletion or degree
weakening. D30dictionary source/census is different and remains unimplemented.

Impact ceiling:8B affected D time and native gain unknown. Benchmark enclosing
D construction, reads/reduction/conversion/folds, launch/synchronization,
transcript/PCS, serialization and fresh verification, then complete-stack
workload startup/resident slopes; do not infer target throughput from52words.
Native builds/GPU runs belong to owner shared build/heavy locks. Reject any
incorrectness/privacy change, extra uncharged work or enclosing regression.

Next local experiment: interleave each affine term with its endpoint's first
non-affine consumer, accumulating each public aliased table's combined weight
exactly once. Baseline77words;54endpointwords remain live at the peak. Charge
all scheduling/accumulators/reads and preserve sample/final/recovery equality.
No benefit if complete peak does not fall or rereads/hidden dispatch increase.
