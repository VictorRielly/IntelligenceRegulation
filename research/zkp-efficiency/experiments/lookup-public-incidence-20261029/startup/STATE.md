# ZKP efficiency explorer — durable state

Cycle 0138 COMPLETE: `20261029T075649Z-ff4ec0d7`.
Started 2026-10-29 07:56:49 UTC; checkpoint 08:13:41 UTC.
Deadline 08:16:49 UTC. Next cycle no earlier than 08:56:49 UTC.

No native proving improvement measured. A source-derived census covers all
23 baseline private sumcheck slots and the optional 24th DD slot. In the pinned
T128 four-limb/full-byte norm, sigma3/P2 class, 174 fresh mask-pair evaluations
need 174 Eq builds. One-entry public-tail weights need 33 builds; two entries
need 29. Constructor products: 4,871,844 → 991,678 / 860,614. All 4,872,192
private base-word reads remain. Native define was not executed; these are not
current R13 LOW/h24 calibration measurements.

The one-entry cache retains up to 262,144 B of public weights through extension
work, plus point copies and exact comparisons. Two entries retain up to
524,288 B. Actual peak memory and exclusive time remain unknown. c0, width,
commitment, pair identity and all fresh private words remain site-specific.
No private result, mask, opening, commitment or challenge reuse across proofs.
The Rust proposal preserves original dot arithmetic and selects n_priv > 1;
it is uncompiled and unapplied. Single-site calls retain the original function.

Model PASS: 22,307 checks, 423 fixtures, 35 negative controls; 6,270 site
comparisons and 6,270 independent extension terminals. Probe 2.818003 s /
26,300 KiB; audit 4,856 checks / 57 source anchors, 0.041339 s / 20,596 KiB.
Eight current source pins unchanged. One nice19 pinned Core Ultra9 185H worker;
40 s CPU, 45 s alarm, 50 s parent, 256 MiB address-space cap, 96 MiB estimate.
A source-anchor spelling mistake is retained with its correction. No native
refusal, RNG, transcript, PCS, privacy or independent-receipt gate ran.

Historical R4 TinyLlama T128/L22 whole-extension free-deletion counterfactuals:
~1.116222x CPU and ~1.108591x RTX4070 Laptop-assisted prove_run, from rounded
clocks. The cache removes a subset. Logs were hash-checked, not rerun or
reverified. These bounds do not transfer to R13, 8B or a high-end GPU.

All 56 prior hypotheses retained; 53/55/56 refined; 57 adds public component
sum preparation as an unimplemented, count-only follow-up. Top three remain:
whole-prover GPU with verified resident 1/2/4/8 workloads; admitted DD/fidelity
context scaling; exclusive phase/capacity clocks. Seven LIVE primary records
appended, 909 → 916. Dates, licenses, inspected versus observed commits and
fetch blockers are saved. No foreign code executed. R13 soundness acceptance
and classifier registration do not amend this research target.

Owner next: exclusive Eq/dot/extension/enclosing clocks and actual R13 census,
then baseline/one-entry/two-entry native golden, refusal, RNG/transcript, PCS,
privacy and independent complete-workload verification under current locks.
Whole-prover GPU/resident workloads retain first priority. Local next:
lookup/softmax rotation; read cycle0121/0122 alias and private-PCS negatives,
then inspect actual LOW/h24/DD descriptors before shared U8-source preparation.
No heavy job queued. Main/Claude reviews and integrates; no merge here.

Experiment: experiments/mask-tail-incidence-20261029/README.md.
Handoff: handoffs/20261029-mask-tail-incidence.md.
Dated report: progress/20261029T075649Z-ff4ec0d7.md.

New independently verified full-stack proofs / passes / positions: 0 / 0 / 0.
Actual model context / accelerator: none. Research used one CPU thread.
Witness, proof, serialization, verification, startup/initial-prefill duration
and fraction, proof latency/bytes, steady-state and total-workload rates:
unmeasured. No long prefill, resident-model series or decode ran. Larger
workloads remain allowed; longer attention can grow quadratically. Private 8B
>=50 proved tokens/s on RTX5090 or another named high-end GPU is unachieved.

Historical CPU 8B T128/L32, one 16-thread pass, GPU off, carried only:
total 478.737 s = 0.267370 positions/s; prove_run 393.785 s includes witness
98.348 s / block load 17.595 s. Sealing 84.824 s precedes prove_run; internal
load 27.151 s / witness 80.897 s overlap. Receipt 922,711,264 B; verification
42.709 s + load 13.681 s. Not rerun/reverified; isolated serialization,
startup fraction and steady slope unknown. No historical tokens newly counted.

Prior STATE preserved in experiment startup; FINDINGS and sources append-only.
Only research outside runtime written. No production, Git, receipt, calibration,
safety, instruction or reviewer edits; no build, GPU, install, external write,
message, purchase or escalation. Saved reports do not imply delivery or liveness.
