# Exact finite-difference interpolation research model

Run `20261026T182925Z-b116a67c`. **No native proof or speed claim.**

The model tests a candidate for `trained-1b/zkp-core/src/mle.rs::interpolate_eval`.
Read [the dated report](../../progress/20261026T182925Z-b116a67c.md) for counts, source limits,
failures, current target accounting and the handoff.

Reproduce from the research directory, one command at a time:

```text
python3 experiments/sumcheck-public-shape-20261026/run_bounded.py probe.py
python3 experiments/sumcheck-public-shape-20261026/run_bounded.py audit.py
```

`run_bounded.py` enforces one-core affinity, nice19, 30-second CPU/alarm,
35-second parent timeout and 256MiB AS; estimate64MiB. No dependencies.
Seed202610260126. Hardware is in `hardware.json`; exact commands and entry
hashes in `commands.jsonl`; all dependency hashes in the artifact manifest.
`reference.py` uses Vandermonde elimination and direct original-cube products.
The SHA256 chain is a mock, not the native transcript. The candidate and
oracle are separately authored locally. `result.json` and `audit-result.json`
measure arithmetic/count correctness only. Initial results/failures are kept.

`finite-difference.patch` and `candidate-mle.rs` are **uncompiled, unapplied**.
Do not execute web code or promote this patch without owner gates/clocks.
