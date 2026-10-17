# Owner review: public coefficient plans and blocked3x2 multiplication

Cycle0051, run `20261017T012624Z-ea61e714`. Candidate only; no native change,
Rust build, GPU job or merge. Main/Claude owns review and integration.

Research patch: `experiments/static-poly-plan-20261017/static_plan.py`;
fixed-array sketch `blocked_helper.rs`, uncompiled. Interface
`mul_3x2([Fp2;3],[Fp2;2])->[Fp2;4]`; reverse operands for2x3. Public shape
preflight selects helpers; do not copy the Python global adapter/interpreter.
The existing factory/weighted-driver/compiled-denominator chain must first
be translated and reviewed. Preserve ordinary native round samples/finals.

Actual read-only owner seam: `ops/zkp-mvp/sonnet-hardening/`:

- `hashline/src/private_block/argument.rs:1699` creates SC_SZC;
  groups1783, full bracket1788–1825 and helper894 retain all relations.
- `zkp-core/src/sumcheck/grouped.rs:93` part accumulation; sample107,
  reduction121, recovery132. Keep declared degrees, own running claims,
  zero-factor fallback and final singleton/ragged behavior.
- `zkp-core/src/field.rs:158` pins the existing five-base-product Fp2mul.
  This is a local coefficient helper, not global field replacement.

All10native/measurement source pins match cycle50. Commands,seed2026101751,
source hashes,dimensions,exit0,logs,source provenance and original independent
tuple/cube oracle are in the experiment directory. 100fixtures/600schedules,
5,832round samples,16,272direct finals,400convolution values,40full-clause
extension values,600counter checks and8value-independent schemas pass.
Five mutation detections plus schedule assertion pass. Final actual-opcode
counter run:12.121455s/23,164KiB/one nice19 CoreUltra9CPU thread. Synthetic only.

Compared with cycle50, blocked3x2 uses5mul+3add+2sub versus6mul+2add.
At illustrative hp16/kv4/qh12/T512/3limb, remove30,670,839Fp2mul,add the
same number of adds and61,341,678subs. Counted base products fall3.1541%,
but field API grows1.9542%. Do not convert that to wall-time savings.

Dispatch caveat is decisive: replay replaces226,492,362width tests with the
same number of cursor reads,4,194,303public pattern lookups and1,042,546,425
interpreter opcode steps. Three public pattern traces classify162widths and
also charge61base-scales,482adds,559mul,248subs,90denominator dispatches and
9axis tests. Logical pointer/IR storage1,296+512bytes; actual Python overhead
larger. Kernel liveness model5intermediate words excludes inputs/full-row;
interpreter retains15words per multiplication. Native code size,registers,
spills,peak and enclosing clocks remain unmeasured.

Required owner gates: fixed-array independent extension/cube/final tests;
all shape,pad,refusal/recovery cases; unchanged masked/frozen/tagged bytes,
challenges,RNG continuation,PCS openings and fresh-process independent
verification. No private-value pruning,mask reuse or cross-proof private
opening reuse. P3 weights,joint privacy and whole-proof soundness stay owed.
Under shared build/heavy guards only, measure construction,equality,folds,
reduction,both witness paths,peak and cold/warm enclosing workload clocks.
Reject if additional arithmetic/dispatch/code/spills erase the gain.

Historical entire-SC_SZC-removal ceiling28.317% concerns one125M/T512/onepass
RTX4070Laptop whole-test clock. Actual accepted8B affected clocks and complete
ceiling are unknown. No accepted complete private8B proof/pass/token exists.

Next bounded local refinement: whole-row public expression identity reuse of
affine sums and structural squaring, charging liveness/graph setup against
this plan. Preserve the native slower fold-fusion and added-API negatives.
