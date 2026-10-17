# ZKP efficiency explorer — durable state

Cycle 0008 IN PROGRESS; run `20260926T235233Z-5f465072`.
Started 2026-09-26 23:52:33 UTC; early checkpoint 23:55 UTC.
Deadline 2026-09-27 00:12:33 UTC. No next cycle before 00:52:33 UTC.

Target remains complete private 8B attention-plus-FFN >=50 proved tokens/s;
512-token prefill <=10.24 s, five seconds stretch. Include witness preparation
and serialization; verification separate; prefill does not establish decode.
No native 8B claim. All writes research-only, excluding runtime; no GPU,
build/install/Git/external messages; one CPU thread, <=60 s, <=512 MiB.

Prior state preserved in experiments/logup-fraction-tree-20260926/previous-STATE.md.
Prior result: exact Fp2 rewrites pass bounded differential tests; native cost
unknown. Latest known dense toy block readiness 40.322/39.095 s; prove
34.861/33.315 s; witness 5.43/5.76 s; serialize .031/.020 s; internal verify
.900/.810 s separately. No full private 8B timing. Owner jobs not duplicated.

Current bounded experiment: fractional LogUp tree against independent reciprocal
sums, full Fp2, multiplicities, ragged leaves and denominator/refusal controls.
Inspect shaped helper layout before claiming any row/commitment saving. Search
primary literature/current repositories using LIVE web. Native privacy,
composition, masks and complete-readiness effects remain unproven.

Next checkpoint will record source metadata, reproducible artifacts, tree/binding
costs and a concrete next hypothesis. If interrupted, inspect this experiment
folder; an absent final result is not a passing experiment.
