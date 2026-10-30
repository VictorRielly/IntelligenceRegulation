# DD score calibration and row-equality boundaries — cycle0169

Run `20261030T174123Z-29d8a272`. **No measured proving improvement.** H103's
dictionary-softmax grouping remains arithmetically exact across the tested
source-derived calibration boundaries. H104 rejects a direct older lazy-NTT
transplant because native Goldilocks lacks its required word slack.

160 synthetic fixtures cover score shifts1..8, n0..3, every Ht equality
span0..n, full Fp2 and Boolean values/challenges. MX/Sum are row slices lifted
through trailing axes. Generic release/debug, grouped release/debug and an
independent expanded original-cube reference agree on6400 round comparisons,
9360 folded values,4800 final comparisons and960 direct clause values.
344 group recoveries and184 exact-zero fallbacks ran. All54 controls detect
the intended errors. No cryptographic proof or native Rust/CUDA ran.

The standalone ungrouped audit passes27026 checks, imports no candidate or
reference modules, and replays every saved round and ordered terminal with
schoolbook tuple arithmetic. It also checks source pins, lifted row-host
multiplicity, exhaustive small integer lookup bounds and requantization.
Recorded control outputs are audited for inequality, not independently rerun.
The first passing audit outputs are retained before supplemental host and
older-source checks. No failed experiment or failed audit occurred this cycle.

Reproduce from the research directory:

```sh
python3 -B experiments/dd-calibration-boundaries-20261030/run_bounded.py experiment
python3 -B experiments/dd-calibration-boundaries-20261030/run_bounded.py audit
```

Seed20261030169. Python3.10.12, Intel CoreUltra9 185H, one nice19 CPU affinity.
Main checking process2.130617s /23164KiB RSS; final audit1.123707s /17984KiB.
Each child:30s CPU,40s alarm,45s parent,256MiB address space; estimated64MiB.
Commands, exact source hashes, source snapshots and hardware are saved.
`result.json` arithmetic operation counts mix several categories; they are
not a single security-test count or executed-instruction estimate.

[The integration note](INTEGRATION.md) specifies the Rust seam, constants,
remaining costs and native gates. Baseline: DD SC_SZC selects generic rounds,
degree4. Factoring through the existing evaluator removes one expensive
bracket sample and three host samples per row pair, plus an interpolation
step. The previous row scan/fold census remains36 Fp2mul,7 mul_base,47add,
15sub saved per pair. This is a refinement of the same candidate, not another
independent saving. New setup/recovery/degree costs and actual native exclusive
slot fraction remain unknown. No numerical end-to-end ceiling follows.

| Priority | Hypothesis | Prerequisite / falsification |
|---|---|---|
|1|Verified high-endGPU complete fixed-context resident1/2/4/8 workloads|Actual native device path, fit, fresh proofs, exclusive phases and independent verification; fail on backlog/coverage/rate.|
|2|Admitted context/DD/fidelity scaling|Count full quadratic attention and reviewed profile/refusal/privacy costs; fail if added work outweighs amortization.|
|3|Exclusive native phase and capacity evidence|Non-overlapping clocks and actual allocation capacities; fail if instrumentation changes conclusions.|
|4, H103 refined|DD grouping across shifts and row spans|Moderate bracket extraction; native bytes/RNG/transcript/refusal/privacy and whole-cost checks still owed.|
|Demoted, new H104|Older lazy NTT direct64bit substitution|Algorithm3 requires p<2^64/4; native p fails and wrapped canonical-input addition gives a counterexample.|

All103 prior hypothesis dictionaries/negatives are preserved; H103 carries
this cycle's refinement, H104 is added. H102 remains demoted: non-DD liveness
overlaps earlier symbolic-Eq savings. Actual R14 owner measurements/freeze and
classifier privacy findings are separate from private8B GPU performance.

LIVE primary research inspected recent
[zkLLMPoT](https://arxiv.org/abs/2610.08258) (Oct6/Oct11; covered-operator
claims), [p3-sumcheck releases/source](https://docs.rs/crate/p3-sumcheck/latest)
(stableSep23, prereleaseOct11), composition conditions and current DeepProve
preprocessing/accounting. The newly assessed older
[Harvey paper](https://arxiv.org/abs/1205.2926) (2012/2013; JSC2014) provides
the rejected word-slack candidate. Its related FasterNTT README uses smaller
primes. No author performance was reproduced and no external code executed.
Ten qualified source records append1132->1142. Dates/unknowns, custom license
and MIT-label limits, blocked histories/PDFs and uninspected commits are
explicit in `sources-cycle.json`; all inspected commit IDs are null.

New independently verified full-stack proofs / complete-model passes / proved
positions: **0 / 0 / 0**. Actual model context:none; passes0; device:one CPU,
no GPU. Witness/proof/serialization/verification/startup/initial-prefill clocks,
startup fraction, proof latency/bytes, steady-state and total-workload proved
token rates: **unmeasured**. No long-context prefill, resident-model proof
series or decode ran. Synthetic cubes are not model contexts. Larger workloads
remain allowed; attention can grow quadratically. Complete private8B
**>=50 proved tokens/s on RTX5090 or another named high-endGPU remains unachieved**.
No mask/pad/private-opening reuse or weaker privacy.

Only research outside runtime written; no production/Git/receipt/calibration/
gate/instruction/reviewer changes, builds, GPU, installations, external writes/
messages, purchase, escalation, merge, job restart or liveness claim.
Saved reports do not establish message delivery.
