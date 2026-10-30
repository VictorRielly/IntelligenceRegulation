# Fresh Eq complement doubling — cycle0145

Run `20261029T145649Z-fb1b89ab`; checkpoint 2026-10-29T15:10:33.803189+00:00; deadline15:16:49UTC.

**A fresh Eq arithmetic candidate passes bounded checks; no native proving
improvement measured.** The exact identity replaces `(e*(1-r),e*r)` with
`(e-hi,hi)`, `hi=e*r`, on every fresh invocation. It preserves field, basis,
table order, geometry and all mask work.

Validation passes 234 Eq fixtures, 2,691,054 compared entries, 14,094
independently computed direct weights and 198 independent MLE evaluations;
600 priv_table cases /608,976 output words and600 fresh mask cases also
match. Eight controls detect stale points, MSB/LSB confusion, swapped or
corrupted entries, wrong complement sign, empty behavior and changed input.
Fixtures cover logs0..10/14/17 for Eq, log0..7/13/14 table geometries, zero,
one, alternating Boolean, maximal canonical base/extension values, U,
random base/extension coordinates, coordinate flips/permutations/fixed
coordinates, broadcasts and multi-slice coefficients/offsets.

The references are unchanged extracted R13 priv_table/claim_point/mask_eval,
canonical native field arithmetic and a same-researcher independent literal
coordinate walk / schoolbook-u128 modular product / MSB half-fold. Full Eq
vectors are compared with native serial arithmetic; independent direct
weights cover all entries through log8 and selected entries above that.
Independent full-vector MLE folds cover logs0..10. These are algorithmically
independent checks by one researcher, not independent external/native review.
No native constructor/whole sumcheck/transcript/PCS/refusal/receipt/privacy
suite ran. The unchanged native parallel branch is represented by a serial
iterator adapter; the proposed native Rayon patch has not been compiled.

Final correctness+diagnostic probe: 0.541017s, 21,144KiB RSS.
Serial helper medians improve in5/6 sizes; nonempty logs4/8/14/17/20 show
1.257..1.744 native/candidate ratios. Empty log0 is55ns versus61ns, noise-scale
regression. Three alternating-arm samples per case are retained; shared box,
Rust1.75.0 opt1, allocations/reversal/init/drop included, inputs prepared
outside timing. No p50/p95 native or GPU result follows. Initial run before
adding mask-seam tests is retained and is not counted as extra model work.
Its retained harness corresponds to that initial execution; main.rs was
snapshotted during the subsequent seam expansion and is not its generator.
Final compile1.527793s /167,440KiB; accounting0.958972s /
16,064KiB,344checks/23 literal operation traces through log22; audit
566checks /14native pins/3unchanged extracted functions passes.
Each experiment command has oneCPU0 affinity, nice19,40s CPU,45s alarm,
50s parent timeout and384MiB address-space cap; estimates128MiB experiment /
320MiB compile. Compiler auxiliary threads are unmeasured; one codegen unit
and one CPU affinity. No Cargo, dependencies, GPU or large build.

For one n-coordinate table, let B=2^n-1. Native source performs 2B Fp2
products and n Fp2 complement subtractions; candidate performs B products
and B subtractions. Net added subtractions are B-n. Native Fp2::mul expands
to five base products and two base additions, including multiplication by
constant7; these are source API counts, not compiler instructions. Every
table initialization, reverse-vector allocation/copy, node load and both
stores remain. No private-data read, fresh mask draw, CFS term, commitment,
opening, attention operation or serialization work is removed. There is no
cache, modified challenge distribution, basis change or reduced field width.

|8B T128 metadata per block|Sites|Fixed Eq products removed|Mask Eq products removed|PCS data-row Eq products removed (partial)|
|---|---:|---:|---:|---:|
|no DD, f_E9|201|2165|2878263|9027|
|no DD, f_E12/16|204|2165|2927412|9151|
|DD32, f_E9|206|2165|2947890|8733|
|DD32, f_E12/16|209|2165|2997039|8761|

These are inherited/source-checked public catalog counts, not executed
constructors, profile admission, clocks, full model totals or physical
traffic. The original144 census rows reduce to36 distinct geometry/f_E
pairs. No32-layer multiplier is applied. Fixed Eq-only optimization is
demoted by its tiny incidence. Mask Eq is larger and recurring once per
declared site in run_slot's extension loop. All146,930,688..153,742,336
private base-word reads per modeled block remain. PCS row accounting omits
mask log0 table calls and unique column-key Eq; public Tab::Eq, weight folds,
general MLE and grouped-sumcheck Eq, verifier and token stages are uncounted.
No total-prover fraction is inferred.

End-to-end ceiling: `N/(T-C_removed_exclusive+A_added)`. With affected
exclusive fraction f and actual native phase ratio k, whole-workload speedup
is `1/((1-f)+f/k)`; neither f nor k is measured here. Even free deletion of
that whole fraction has ceiling `1/(1-f)`. Serial helper ratios and operation
counts cannot supply those missing native terms.

LIVE primary searches assessed the [author September sumcheck post](https://www.cs.cmu.edu/~csd-phd-blog/2026/sumcheck-proving/),
[monomial-basis paper](https://eprint.iacr.org/2026/762) and
[benchmark implementation/methodology](https://github.com/quangvdao/monomial-sumcheck-benchmarks),
the older [HyperPlonk Eq helper](https://github.com/EspressoSystems/hyperplonk/blob/main/arithmetic/src/virtual_polynomial.rs),
and the new [October Longfellow draft](https://datatracker.ietf.org/doc/draft-irtf-cfrg-longfellow/).
The monomial collector diff was inspected at
b2e6df5bb19a2af5313e7abe8fbd51313e30e6a1 (September4,2026). Its Eq kernel
and license fetches failed; no license is asserted. HyperPlonk's commented
sequential complement technique is relevant, but the active per-output
parallel loop recomputes its product. Its ordering/empty convention differs.
Main file commit pin failed; separate history commits2a3b55c97ad8a5d6627108a2e7def2aeccb7f3b9
and70b0df5c52fd07a0c63ba397bcd9ed596ef282b3 were inspected. MIT is named in
headers/open-source diff; full license fetch blocked. No code was adopted.
Longfellow draft00 body is October19; datatracker update October22. It is
work in progress. Section6.2 warns that truncated Eq binding need not
compose with later binding;6.5 keeps pads fresh. This is a composition
guardrail, not a speed/privacy result for the native stack.

The new algebraic-geometry sumcheck lead2026/2494 was inaccessible at both
primary HTML/PDF; no technical claim or mirror date was adopted. Other exact
Cache-miss/403 failures remain in web01..09 and blockers.json. Seven source
records append964->971. Publication/update dates are verified where possible
and otherwise null; HyperPlonk release year is explicitly inferred, not
verified. Foreign source text stayed untrusted; no foreign code/script,
author benchmark or proof was executed/reproduced.

Owner next: inspect native-eq-doubling.patch, measure exclusive Eq
construction versus pair-dot/extension/table and enclosing-proof clocks,
then use shared build/heavy locks for native correctness/receipt A/B only
if its phase share warrants integration. Keep full native refusal, draw,
transcript, frozen-byte and current privacy gates. Any arithmetic/order/
empty/freshness/refusal/receipt mismatch or erased enclosing benefit
falsifies promotion. Main/Claude owns review and integration; no merge here.

Global ranking remains1whole-prover named high-end GPU and independently
verified resident1/2/4/8 workloads;2admitted context/DD/fidelity scaling;
3exclusive phase/capacity clocks. Prior61 hypotheses are unchanged;62 is
added. This local result is conditional and does not outrank the measured
whole-prover bottleneck. Next local proof-composition rotation: audit the
actual R13 group_zclaims/n_groups_zk/open_zk call graph for repeated public
Eq preparation within one invocation, including mask-pair/column keys.
Compare with prior fresh-tail-cache findings before proposing reuse. New
native phase evidence takes precedence; never retain private masks/openings
or stale points across passes.

New independently verified full-stack proofs / completed model passes / proved
positions: **0 / 0 / 0**. Actual model context / accelerator: **none**. Research
device: one pinned Intel Core Ultra 9 185H CPU worker, no GPU. Witness, proof,
serialization, verification, startup and initial-prefill clocks, startup
fraction, proof latency/bytes, steady-state and total-workload token rates:
**unmeasured**. No long-context prefill, resident-model proof series or decode
ran. Synthetic helper dimensions are not model contexts or completed passes.
Larger workloads remain permitted; dense attention can grow quadratically
with context. Complete private 8B >=50 proved tokens/s on an RTX 5090 or
another named high-end GPU remains **unachieved**.

Carried older-profile CPU 8B baseline: T128/L32, one 16-thread pass, GPU off.
Total 478.737s = 0.267370 positions/s; prove_run393.785s includes witness
98.348s and block load17.595s. Sealing84.824s precedes prove_run; sealing
load27.151s and witness80.897s overlap. Receipt922,711,264B; verification
42.709s plus load13.681s. Not rerun/reverified or newly counted. Isolated
serialization, startup fraction and steady-state slope remain unknown.
Newer Shieldstral classifier results and S4 design rules are separate scope;
they establish neither this candidate's native behavior nor private8B GPU
throughput. Current owner notes keep the 8B T512 whole-run soundness floor open.

Only research outside runtime was written. Production, Git metadata,
receipts, calibration, instructions, safety and reviewer files are untouched.
No external write/message, install, purchase, Git operation, escalation,
GPU, large build or merge. Saved reports do not imply message delivery or
supervisor liveness.


Reproduce sequentially from research root (no setup/install required):

```text
python3 -B experiments/fresh-eq-doubling-20261029/run_bounded.py compile
python3 -B experiments/fresh-eq-doubling-20261029/run_bounded.py probe
python3 -B experiments/fresh-eq-doubling-20261029/run_bounded.py account
python3 -B experiments/fresh-eq-doubling-20261029/run_bounded.py audit
```

Seed202610290145. Commands, hardware, pins, initial result and raw sample
arrays are retained. Candidate interface: `eq_table(&[Fp2])->Vec<Fp2>` and
`eq_table_msb(&[Fp2])->Vec<Fp2>` in candidate.rs. Proposed native patch stays
in this directory and is not applied to production.
