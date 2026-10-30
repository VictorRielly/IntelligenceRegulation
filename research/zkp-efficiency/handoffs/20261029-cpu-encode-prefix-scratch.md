# R13 CPU encode prefix scratch — review-only candidate

Run `20261029T095649Z-50135f2e`, cycle0140, 2026-10-29T10:10:51.585056+00:00. No native proving improvement measured.
Disposition: **PARK pending actual CPU allocator/enclosing clocks**.

Interface stays initialize_row<'a>(ntt:&NttTables,data:&[Fp],pads:&[Fp],
pows:&[Fp],out:&'a mut[MaybeUninit<Fp>])->&'a mut[Fp]. Source: frozen R13
`results/zk60_1b_native_20261017/r13/frozen-tree/zkp-core/src/pcs/encode_buffer.rs:43`,
sha2563c01433d84507cddadcf5c1387c08948fd3efe853a066d74690c0a6e1ce3dd70.
Frozen tree digestbb9eb212… is not a Git commit.

Patch: [initialize-in-output.patch](../experiments/commitment-width-lifetimes-20261029/initialize-in-output.patch).
It is unapplied. The extracted helper and serial adapter compiled in a std-only
research harness; the full native/Rayon crate did not build or run here.

Baseline: CPU initialize_row allocates data.to_vec, inverts it, then
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
This is a small allocation cleanup, parked behind owner phase measurements.

Compiled local component: **168 fixtures /606 rows /360,882 encoded values**
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
the unchanged encoded allocation. Harness 0.104446s /8,352KiB RSS;
compile 0.973495s /164,336KiB. Source/patch/cost audit:
74checks /4static anchor mutations /11pins PASS,
0.002098s /15,244KiB. Seed202610290140.
One pinned nice19 CPU, one compiler codegen unit; auxiliary OS thread count
not measured. Each experiment has40s CPU /45s alarm /50s parent timeout and
384MiB address-space cap; compile estimate320MiB, harness64MiB. No Cargo,
dependency build/install, GPU or large build. Rustc1.75.0; complete commands,
binary/input hashes and hardware are retained. Initial narrower passing
component results are preserved; no failed experiment occurred.

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

Owner next: confirm actual CPU/fallback incidence and exclusive allocator,
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
First re-read owner updates and the earlier mask-tail incidence negatives.

New independently verified full-stack proofs / model passes / proved positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**; research used one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
longer dense attention may grow quadratically. The complete private 8B
>=50 proved-token/s target on an RTX 5090 or another named high-end GPU remains
unachieved.

Only research outside runtime was written. No production, Git metadata,
receipt, calibration, instruction, safety or reviewer files changed. No large
build, GPU, installation, external write/message, purchase or escalation.
Main/Claude reviews and integrates; patch is unapplied and nothing was merged.
Saved reports do not imply message delivery or supervisor liveness.
