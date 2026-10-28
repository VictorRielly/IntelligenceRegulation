# FZC allocation materiality: measurement handoff

Cycle `20261021T041854Z-cfd5ba2e`, 2026-10-21 UTC. Research-only code and proposal;
main/Claude reviews and integrates. No production patch, build, GPU job or merge.

No proving improvement measured. Source audit identifies missing pre-body,
post-report and tail-local-drop scopes, plus success-only FZC aggregation.
These omissions do not establish a material cost or a missing complete-proof
clock. The build timer already combines allocations, transfers, module work and
sync; its full duration cannot be attributed to scratch allocation.

Interface and patch location: research
`experiments/fzc-phase-accounting-20261021/accounting.py::summarize`,
`family_thread_wall`, `reference.py` and `MEASUREMENT.md`. Intended owner seams:
`gpu/fzc.rs::prove`, `gpu/cuda.rs::DevFzcRounds::{new,try_round,try_fold,report}`,
`PinBuf::{new_read,drop}` and `FzcMapped::{new,drop}`. Exact current hashes and
source anchors are in `source-pins.json` and `source-audit-result.json`.
There is no compiled Rust/CUDA adapter to promote.

Validation: 6,829 synthetic checks, 1,500 differential nested traces and 400
dependency graphs; 21 control types include nested double-counting, mixed
clock domains, large integer timestamps, failures, cleanup omissions and
parallel thread-wall. The independent integer-tick and recursive-path references
import no candidate helpers. Separate source/role audit passes 59 checks and
checks three live-source hashes. This is independent reference code by the
same researcher, not external review. No CUDA behavior or proof was exercised.

Two artificial 30-unit workloads have the same 8-unit allocation API cost;
free deletion saves either 0 or 8 units depending on overlap. Hence counts or
API fractions cannot predict complete-proof gain. Keep device time separate,
charge mandatory clearing/binding/fences, and compare instrumentation off/on.
Use an outer caller scope that survives error returns and evaluator destruction.

Unresolved: native incidence, actual driver allocation/free/mapping clocks,
critical-path relevance, instrumentation overhead, physical pinned capacity,
retirement fences and complete current-profile parity/privacy/refusal gates.
No masks/openings/challenges/private preprocessing are reused. See the preceding
scratch/error retirement handoffs for completion/quarantine constraints.

Next owner action: complete workload/phase measurements under shared locks;
only promote a bounded pool if safely removable cost is material and enclosing
verified workload improves. Keep complete high-end GPU 8B clocks and verified
fixed-context resident 1/2/4/8 ahead of this micro-optimization. Next local lane
rotates to source-backed exact nonlinear lookup work; scratch runtime promotion
is parked pending native materiality evidence.
