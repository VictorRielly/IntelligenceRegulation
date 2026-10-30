# SC_TAB periodic descriptor: source-derived masked conformance

Cycle 0129, run `20261028T225649Z-6db80b72`, 2026-10-28 UTC.
**No proving gain measured.** This closes a synthetic coverage gap left by
cycle 0128; the native adapter and its performance gates remain outstanding.

The candidate retains three freshly encoded 256-row public tables while
preserving the original full cube, dense private/equality/support factors,
six private claims, degree-three polynomial and one trailing extension.
Earlier cycles 0039/0040 and 0128 did not execute CFS masking. Existing native
dense-driver masked tests were inspected; they already cover dense masking,
so this experiment does not claim to supply the first such tests.

Reproduce from this research directory:

```text
python3 -B experiments/sc-tab-mask-conformance-20261028/run_bounded.py probe.py
python3 -B experiments/sc-tab-mask-conformance-20261028/run_bounded.py audit.py
python3 -B experiments/sc-tab-mask-conformance-20261028/run_bounded.py artifact_audit.py
```

The runner pins one allowed CPU at nice19, 45-second CPU/alarm limits,
50-second parent timeout, 256 MiB address space; estimated memory96MiB.
No dependencies, native build or GPU job. Hardware/installed BLAKE3 version,
commands, seed and source hashes are retained. All inputs, masks and keys are
synthetic; deterministic Python RNG is not the native mask RNG.

## Result and limits

817 checks pass in six fixtures, n8/9/10 × unkeyed/keyed, with 60 main plus
extension rounds. They include216 independent original-cube polynomial
coordinates,240 independent original-Boolean-suffix mask coordinates,
332 small-cube mask basis sample coordinates (including the product term),
36 reserved-pair claims, original-order terminal/state/next-squeeze checks
and57 negative-control instances. Dense explicit rounds, recovered periodic
rounds and the independent expanded original-cube polynomial agree.

The CFS model preserves `g=a0+a_product*product(x)+sum(a[j,e]*x[j]^e)`
on n+1 variables. The reference uses separately authored tuple/schoolbook
arithmetic, original Boolean suffix enumeration and direct polynomial
expansion. Independent byte-frame assembly replays keyed/unkeyed BLAKE3;
both implementations use the same preinstalled hash library. Each fixture
has distinct synthetic coefficients and six distinct reserved row pairs.
The private claims are independently evaluated from original data and those
pairs, with the extension selector on data and e on the pair. Both pair
coordinates are retained; A/H claims retain their three-per-owner order.

Controls alter round values/count/degree, scalar, terminal count/order/value,
and the full mask dimension. Deliberately inconsistent standalone witnesses
produce their actual nonzero first-round sum, which contradicts the asserted
scalar; they are not seeded with an invented zero claim. The local source-
derived zero-CFS and e0/e1 guard functions refuse. Those guard checks are
**not native refusal or privacy evidence**; their native ordering before
private-terminal absorption is separately source-audited.

Model clock6.526771s,21588KiB RSS. Source/scope audit83checks,0.002809s,
15552KiB RSS; all nine pinned native files unchanged. These checking clocks
include the reference and are not a baseline/candidate performance A/B.
`synthetic-*-rounds.bin` files contain only synthetic round coordinates,
not native proofs or production receipts.

The domain, prior-slot prelude, arbitrary tagged key and row-width8 mask
fixtures are synthetic, not a native profile/HashTag/RNG or current R12
row-width13/14 execution. Local direct linear-functional equality stands in
for the committed mask opening; no native PCS or hiding commitment is run.
There are no native transcripts, captures, receipts, separate-process proof
verification or privacy acceptance. No larger n13/14 full slot was executed.

## Baseline, eliminated work and ceiling

The baseline remains R12's three fully expanded public SC_TAB factors. At
T128/n14 the logical payload786432B becomes12288B and public fold lerps49149
become765. These are source counts from the prior cycle, not new elapsed or
peak-memory measurements. Full cube16384, six private terminals and all47
CFS coefficients on15 variables remain. T32/T64/n13 retains44 coefficients.
A four-instance control falsifies truncating the lifted slot's mask to nine
variables: its total changes. Public repetition does not justify that shortcut.

Fresh public encoding, short vector storage, typed dispatch, indexing/checks,
bind metadata and native builder/terminal/census adapters add costs. The full
polynomial scan, witness, masks/commitments/PCS, serialization and verification
remain. Constructor savings overlap prior tiling and must not be added twice.
The actual exclusive affected fraction f is unmeasured; even free deletion
is bounded by1/(1-f), before added costs. Negligible native exclusive share,
any field/round/transcript/next-draw/claim/refusal/receipt/privacy mismatch or
an enclosing-time/capacity regression falsifies usefulness. No numeric
private8B GPU ceiling is supported.

## Native seam and handoff

Read-only pins: `native-pins.json`, `native/`. The existing uncompiled sketch
is `../periodic-sc-tab-20261028/candidate-periodic.rs`; this cycle adds no
production patch. Interface: public descriptors expose logical full n,
length/current-bound state, immutable indexed reads, one MSB bind per round
and original-order terminals; native ClosureRounds receives the explicit
full cube. Keep SC_TAB's six private factors and original positions.

Owner must preserve `Tab`/builder/public-length validation on both sides,
`run_slot` standalone initial claim=None, original CfsMask n+ext and degree,
masker install/take, all extension zero targets for public factors,
private reserved-pair claims, mask functionals and final absorb order.
Golden/freeze/next-RNG/refusal/capture/privacy/receipt gates remain mandatory.
First measure exclusive public construction/fold, SC_TAB and enclosing
verified workloads under the current shared build/heavy locks. Main/Claude
reviews and integrates; this lane does not merge or queue a heavy job.

## Ranked queue and primary-source rotation

All42 prior hypotheses are retained in `hypotheses.json`; rank41 refined,
rank43 adds the rejected full-mask truncation shortcut and rank44 adds a
conditional Tensor Core NTT lead. Top priorities remain owner whole-prover
GPU plus fixed-context resident1/2/4/8 verified workloads; DD larger-context/
fidelity scaling after T128's measured null result; complete exclusive phase
and capacity clocks. Their prerequisites, added costs, exactness, privacy,
compatibility, ceilings and falsification conditions are retained.

Ten source records and13 native LIVE batches are retained;840 total durable
records. Newly inspected original [CFS2017](https://eprint.iacr.org/2017/305)
is already referenced by the native implementation, not a newly discovered
optimization. [Libra](https://eprint.iacr.org/2019/317) was already assessed.
The [current Plonky3 module](https://docs.rs/p3-sumcheck/latest/src/p3_sumcheck/zk/mod.rs.html)
distinguishes prelude/simulator and oracle/compiled hiding obligations;
its WHIR architecture is not a CFS drop-in. Current LIVE releases list
v0.9.0-rc.2 rather than the stale v0.8 search excerpt; year is unverified.
MIT/Apache license bodies were inspected; merge diff cache-missed.

A new [Tensor Core NTT](https://github.com/Terminus-IMRC/tensor-core-ntt)
source screen finds an explicit62-bit cap on two friendly paths, rejecting
Goldilocks there. General64-bit arithmetic remains unaudited; this is not a
whole-library incompatibility claim. README/SPDX declareApache2.0; visible
historyJanuary17,2026, but exact commit fetch cache-missed. GPU-NTT and ICICLE
interfaces/licenses were refreshed. Known Bits Under ZK-LLM projection/
small-model scope remains distinct from complete-model evidence. LightZK's
primary DOI is inaccessible; its date and performance remain unverified.
No author performance reproduced, no fetched code executed, no blockers bypassed.

Next LOCAL: inspect Tensor Core NTT's general64-bit reduction/NTT parameter
path, then a bounded researcher-authored carry/reduction differential against
Python big integers at Goldilocks edge values before proposing a native seam.
If unsupported, retain that negative and return to measured native bottlenecks.
Next OWNER: exclusive clocks and native integration gates before promotion.

New independently verified full-stack proofs/passes/positions:0/0/0.
Actual model context/accelerator:none. Witness/proof/serialization/verification,
startup/prefill/startup fraction, latency/bytes, steady and total-workload
rates are unmeasured. No long prefill, resident proof series or decode.
Larger workloads are allowed; dense attention can grow quadratically.
Private8B >=50 proved tokens/s on RTX5090/another named high-end GPU is unachieved.
Only research outside runtime written; no production/reviewer/instruction/
calibration/receipt/gate/Git changes or external messages/writes. Reports are
not evidence of delivery or supervisor liveness.
