# BASE affine derivation — cycle 0098

Run `20261020T061854Z-03bda577`, 2026-10-20 UTC.
**No proving speed improvement measured. No native build, GPU or proof ran.**

The active raw round-zero slot-18 kernel calls `fzs_derived_at` separately
for the low and high endpoints. Cycle 0097 tested direct affine value and
homogeneous difference evaluation with fresh public pad preweighting. This
cycle specializes that candidate when the host's existing BASE eligibility
holds: the A inputs and their differences are scalars, so each GL clause is
computed over the base field before multiplying its extension-valued mu.
PL multiplies each extension-valued preweighted coefficient by a scalar.
Derived tables and coefficients retain both coordinates. Keep both global
endpoint stores, reconstruct high = low + difference, and retain the barrier.

The existing host selects BASE only at round zero. Committed `FzcSrc::Base`
planes supply structural eligibility; Pair/Eq sources in relevant positions
disable it. Host/Public variants have existing coordinate checks. This work
adds no scan or dispatch on private zeros and does not broaden those rules.
Any deployment must preserve the reviewed eligibility/privacy boundary;
Python algebra does not accept timing leakage or a new privacy scope.

The bounded Python experiment passes **36 fixtures, 144 rounds, 1,669 checks,
18 negative controls and 90 partial source-cost cases**. Seed `2026102098`;
tables have 8/16/32 entries, support on/off, 0/1/3/8/11 public nonzero pad
weights, base or extension A, extension helpers/coefficient values, and modular
edge values. Kh=2^1/2^20 cases are extra algebraic stress, outside trained
sh_h 9..16; they are not admitted native profiles. A separate schoolbook
quotient-field original SC_FZC polynomial and original-table direct MLE check
canonical round bytes, high stores and final original-table values. Challenges
come from a synthetic hash recurrence, not native Fiat–Shamir. These arbitrary
tables are not valid transformer witnesses. Only 18 first rounds use BASE;
all later rounds and extension fixtures use the paired extension fallback.

Controls detect BASE incorrectly applied to each of eleven extension A
inputs, extension differences and post-challenge folds; truncating derived
imaginary coordinates, stale/unweighted pad coefficients, constants in the
difference and incorrect high stores. Public zero mu_pad remains exact.
The first 17-control result is retained under
`initial-before-extra-difference-control/`; final evidence adds the explicit
extension-difference control. Source validation passes 67 checks; eight
native file hashes match the retained cycle-0097 snapshots and current files.

At illustrative **L=2^21 entries, support on, k=11**, source-call totals in
derived phase 1b (including high endpoint stores) are:

| Variant | Base products | Base adds + subs | Logical shared operand reads |
|---|---:|---:|---:|
| Current two-endpoint source | 111,149,056 | 423,624,704 | 912 MiB |
| Prior paired extension candidate | 104,857,600 | 358,612,992 | 608 MiB |
| BASE paired candidate | 67,108,864 | 76,546,048 | 304 MiB |

Thus BASE removes 44,040,192 products and 347,078,656 additions/subtractions
against the current source; against prior paired it removes 37,748,736 and
282,066,944. These are **source primitive calls before compilation**, not
instructions, hardware transactions, DRAM traffic, timings or proof rates.
Scalar operand-read counts assume dead-code elimination. Parameter loads,
shared/global stores and the common polynomial evaluator are not removed.
Global/capacity bytes saved and added barriers are all zero. A table cube
is not a token context. Compiler zero propagation may already remove some work.

Compared with current source, fresh preweighting adds k host Fp2 products per
sumcheck (11 here), <=176 parameter bytes and per-CTA staging; keep original
parameters for fallbacks and host tail. Compared with cycle 0097, BASE adds
template code but no new coefficient setup, buffer, barrier or scan. Register
pressure, occupancy, cache behavior and enclosing elapsed effect are unknown.
No model-level cache of challenge coefficients or private masks is proposed.
If the exclusive derived phase fraction is f, even deleting that entire phase
permits at most 1/(1-f); this candidate removes part and adds setup. f is
unmeasured. Reject on any parity/refusal/receipt mismatch, invalid eligibility,
compiler elimination of the supposed redundancy, or enclosing regression.

The seam is `fzs_impl<...,BASE>` raw && !FOLD phase 1b in the pinned
`hashline/src/gpu/fzc_kernels.cu`, with inherited host selection at
`cuda.rs:4300` and `cuda.rs:4628`. `candidate_base_pair.cuh` is an uncompiled
adapter sketch depending on the prior paired adapter; it is not an applied
patch. Host fresh preweight preparation belongs in `DevFzcRounds::new`.
Owner validation needs compiler/register evidence, native masked rounds and
next challenges, unchanged complete receipts, fresh independent verification,
all refusal/strict-GPU/CS/H-1 gates and current privacy review. No merge here.

Commands from research root:

```text
python3 experiments/base-affine-fzc-20261020/run_bounded.py probe.py
python3 experiments/base-affine-fzc-20261020/run_bounded.py validate.py
```

Final algebra/cost leaf: 1.555 s, 16,948 KiB RSS, one CPU thread/core 0,
nice 19, Intel Core Ultra 9 185H / WSL2. Every leaf has 59-second CPU/alarm,
60-second parent timeout and 512 MiB address-space caps. Hardware, source/code
hashes, case seeds, commands and logs retained. No dependency or external code ran.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context and accelerator: none. Witness/proof/serialization/
verification clocks, startup fraction, steady-state and total-workload proved
rates: **unmeasured**. No long-context prefill, complete resident-model pass
or decode ran. The complete private 8B >=50 proved tokens/s target remains
unachieved; larger workloads are allowed and attention can grow quadratically.
No mask/opening reuse or privacy weakening. Carried CPU T128/L32/one-pass
478.737 s = 0.267370 positions/s is not rerun/reverified. Its prove_run
393.785 s includes witness 98.348/load 17.595; seal 84.824 overlaps; receipt
922,711,264 B; fresh verify 42.709+13.681 load s; recheck 34.395+10.739 load s.
Carried startup/steady and isolated serialization remain unknown. Owner DD's
478.7 ->474.9 s T128 comparison is n=1/shared-box and explicitly a null result.
The decisions register now records R9 soundness acceptance at three profiles
(05:59 UTC), with N-r9-a/b binding conditions; DD privacy gate remains owed.
D33's frozen R7 TinyLlama T32 privacy acceptance does not cover this candidate.

Six LIVE primary records appended (565 ->571): newly assessed older packed
sumcheck [2025/719](https://eprint.iacr.org/2025/719), including September 14
revision; newly assessed July [prime-ir409 negative](https://github.com/fractalyze/prime-ir/issues/409);
recent [SP1 6.9.0](https://github.com/succinctlabs/sp1/releases/tag/v6.9.0);
[Bits Under ZK-LLM](https://arxiv.org/abs/2609.36437),
[zkLLMPoT v2](https://arxiv.org/abs/2610.08258), and
[extended sumcheck](https://eprint.iacr.org/2026/587). Exact dates, commit/license
scope and Internal Error failures are in `source-records.json`. No author
performance reproduced. Packed matrix challenges require a different protocol
and PCS; they do not authorize truncating the native challenge field. The
upstream carry negative reinforces the missing compiler/occupancy gate.

Next local: compare a BASE GL-only adapter requiring no host preweighting
against the prepared full pair, using original math and sparse-pad source
costs. Next owner: locked tiny native A/B and enclosing clocks. Full ranked
queue and falsification conditions are in `hypotheses.json`; whole GPU and
resident 1/2/4/8 measurements remain higher priorities. Only research excluding
runtime was written. Saved reports do not imply external message delivery.
