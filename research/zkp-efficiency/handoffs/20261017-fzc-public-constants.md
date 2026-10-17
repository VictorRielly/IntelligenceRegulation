# Review candidate: exact F zero-check constants and support factoring

2026-10-17, cycle 0063, `20261017T132624Z-393ef603`.
Owner integration only; no production patch applied or merge performed.

The current trained lane's `SC_FZC` still captures `p1`, `k_h`, `k_g` as
Fp2 values and repeats support multiplication in three constraints. D's
Stage35 already uses the corresponding base/factor discipline. This candidate
extends that discipline to F while leaving its LogUp/activation arms ungated.

Patch: [argument-candidate.patch](../experiments/fzc-public-constants-20261017/argument-candidate.patch).
Base: `ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs:1634`;
source hashes in [native-pins.json](../experiments/fzc-public-constants-20261017/native-pins.json).
The root checkout's older file is a different source; recompare pins before
applying to any lane. No dependency, API, challenge, table order, mask, PCS,
wire, opening or profile change is proposed.

Interface remains `Fn(&[Fp2]) -> Fp2`. Capture the three public base constants
as `Fp`, use `value.mul_base(constant)`, and compute
`g * (mu0*f0 + mu1*f1 + mu2*f2)`. Keep `mu3*f_act`, `helper_sum`, `pz.eval`
and both existing host support factors exactly where the patch leaves them.
Every folded/private input remains full Fp2. There is no inference-based
base-value branch and no mask or private-opening reuse.

Evidence: 480 fixtures / 2,480 independent Rust/Python comparisons, nine
algebra mutation controls, 45 separate audit checks. Full F body, native field,
native helper and pad/gate code are captured; table construction is a synthetic
11-plane / nine-lookup F layout. Product shifts 0,1,7,8,9,14,16 and gate shifts
0,1,7,8, both pad cases, odd/even/empty helper catalogs, arbitrary extension
supports, ordinary round samples and terminals pass. See
[README](../experiments/fzc-public-constants-20261017/README.md) for commands,
source/seed/compiler/hardware/limits and both retained harness failures.

Executed API calls drop 37 -> 30 unpadded / 49 -> 42 padded general Fp2
products, with five extra `mul_base` calls. Added one Fp2 accumulator and one
addition; no scratch tables/transfers/RNG. Isolated optimized closure storage
shrinks 296 -> 272 B. Six post-warm CPU medians per variant give combined
1.114x / 1.098x; support factoring alone is 0.990x unpadded and 1.022x padded.
Ranges overlap on a shared host; no stable native speed claim follows.

End-to-end limit: earlier 1.1B T128 GPU-assisted F slot 19.484 of 161.857 s;
complete removal would give at most 1.137x, and this changes only a subset.
No 8B F phase profile exists in the inspected receipts; no 5090 projection.
Even deleting all 110.168 / 117.725 s of new 8B CPU/GPU proof-minus-witness-
and-reload work caps those one-shot cold process speedups at 1.402x / 1.430x.
That bound holds other costs fixed and is not an amortized resident result.

Required owner gates before integration: compile the real lane under the shared
resource guard; evaluate old/new complete slot definitions at every registered
shape including absent support and global pad-on/domain-full branches; test
extension rounds and final constraints; require frozen receipt bytes, transcript
and RNG continuation, claim/M functionals and PCS order; independently verify
honest receipts and native tamper/pad controls. Review at the actual 8B shape
remains separate from D24's soundness acceptance and D22's toy privacy scope.
Then measure F and complete process clocks, serialization, verification, memory
and transfers, with both variants separately attributable and a resident pass
sweep if admitted. No heavy/GPU job has been queued by this researcher.

Falsification: any field/terminal/byte/claim/RNG mismatch rejects the patch.
If the real enclosing proof timing is unchanged or slower, demote for speed;
the unpadded support-only negative already forbids assuming operation counts
predict runtime. Compiler behavior here does not establish behavior under the
owner's actual build flags and call path.

Next local question: can F's three equality factors use the existing
`GroupedEqRounds` seam without rebuilding challenge-weighted Eq tables?
Start with a complete three-bracket oracle, exact degree and final-terminal
checks, rather than extrapolating this small arithmetic result to 50 tokens/s.

Final source-drift check: the owner changed `layout.rs` and `shape.rs` during
this cycle, adding CS-8 constructor/layout validation methods. The captured
F closure and field/helper code hashes still agree. The original final audit
correctly failed its live-pin assertion; `initial-artifact-audit-failure.json`,
`pin-drift.json` and the exact owner diffs are retained. Kernel evidence remains
bound to the captured source snapshot. This is not approval of the owner
changes; rebase/review and native validation are required before integration.
