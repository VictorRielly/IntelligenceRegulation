# Trained phase accounting — cycle 0059

Run `20261017T092624Z-0a2ee588`, completed 2026-10-17T09:36:09.547899+00:00. **No native speed improvement established.**

Question: are the retained trained TinyLlama clocks sufficient to choose the next
optimization and distinguish reusable setup from recurring work? Baseline: 22
separate T32 trained-block diagnostics, each with a fresh-process verification
record. These were produced by the native owner earlier today, not rerun here.
Calibration export `a_export_T32`, sequence `ho00`, historical t5 CLI; these
clocks do not measure the new `pg_rot1` calibration or current round2 stack.

| Retained diagnostic clock, summed across 22 runs | Seconds | Share of reported main-path total |
|---|---:|---:|
| Model/public load | 16.046 | 3.95% |
| Sequence load + exact native witness + parity | 294.314 | 72.49% |
| prove_run, including encoding | 82.500 | 20.32% |
| In-process verification, including decode | 7.400 | 1.82% |
| Unclassified enclosing remainder | 5.720 | 1.41% |
| Reported total before optional controls | 405.980 | 100% |

Fresh verifier load/read/statement work totals18.822s and its verification/decode
clock totals7.265s, separately from the prover total. Receipt bytes sum255,800,336.
The total above is a **sum of separate process diagnostics**, not a linked-stack
wall time, throughput measurement or a statistically repeated workload.

These times are rounded to1ms. The aggregate unclassified remainder has a worst
case ±0.055s rounding radius (22 x5 independently rounded fields). It includes
endpoint/statement construction, file writes and other gaps. It is **not** a
serialization measurement. Encoding is inside prove_run; disk writes are outside
that timer on the historical one-block CLI and inside it with the current stack
DirSink. Verification's cryptographic phase is not separated from decode.

The archived CLI's witness is built once before its prove timer and consumed by
OneBlock. The **new stack source**, inspected separately, makes a full sealing
witness pass, restarts, then rebuilds each witness for proving. Boundary-plane and
witness calls share one cached witness for each non-final block; the final block
builds at witness(). Do not count an additional rebuild at every boundary. The
sealing pass depends on each new input and retains the witness builder's refusals;
it is not automatically public startup amortizable across independent passes.

Historical RunStats.prove_s says "witness build excluded", but its timer starts
before both source calls and ends after encode and sink. This is established in
both archived t5 and current sources. run-t5.rs and trained_block-t5.rs were
reconstructed without executing them from the retained patch; both exactly match
manifest_final_sources.json. Current round2 files differ from t5 and are not
assigned the old timings.

Idealized accounting ceilings, ONLY for these diagnostic totals: removing all
82.500s of prove_run gives at most1.25504x; removing all16.046s of measured load
only1.04115x. A prove-only denominator understates the reported main-path total
by4.92097x. No such deletion was implemented. There is no complete8B ceiling.

## Bounded experiment and independent references

`python3 experiments/trained-phase-accounting-20261017/experiment.py` passes
16,219 accounting/reference checks, including22 retained verifier pairs and200
synthetic nested traces/16,000 spans, with15 negative controls. Decimal accounting
is compared against a separate integer-ms oracle. Nested span subtraction is
compared against an independent endpoint sweep. Synthetic resident-workload
fixtures verify that amortizing startup cannot beat the recurring slope; they are
not fitted to native logs. Wall0.107200s, RSS17,052KiB, seed2026101759.

`python3 experiments/trained-phase-accounting-20261017/audit.py` passes499
independent timing/provenance/patch checks in0.004319s, RSS15,100KiB. It verifies
the source reconstruction pins and applies all6 diff hunks to a research string.
Both scripts enforce59s CPU/alarm and512MiB AS, one nice19 CPU0 thread. Estimated
memory64MiB/32MiB. No native compile, transcript/RNG/bytes gate, actual GPU profile
or new proof verification occurred.

Controls refuse missing/duplicate events, mismatched bytes/hash/statement,
nonzero completion/guard kills, scope relabelling, impossible/nonfinite/negative
times, overlapping/out-of-parent spans, missing parents and duplicate span IDs.
These check accounting consistency, not cryptographic soundness.

## Integration seam and limits

`phase-probe-candidate.patch` adds aggregate setup/source-witness/encode/sink
clocks to native `private_block/run.rs::RunStats/prove_run` in the research copy.
The source/encode/sink fields are **subsets** of inclusive stage duration.
The patch is uncompiled and adds timing overhead; owner must review/rebase to the
pinned base, choose opt-in diagnostic reporting and verify native frozen bytes,
refusals/RNG/fresh verification and enclosing overhead before use. It does not
split all commitments/core phases or fresh verifier read/decode/crypto costs.

Next owner measurement: linked trained stack with load,sealing witness,endpoint
prepare,run setup,rebuild,core,encode,flush/hash,metadata,decode and fresh verifier
boundaries. Follow with fixed-context resident fresh-mask passes and slope/drain.
Next local experiment: allocation-free source census of witness::build_shaped,
separating exact matmul, requant/range checks and plane/helper materialization;
identify a witness subroutine that can transfer to an existing CUDA seam without
weakening refusal semantics. Keep exact full-K split-int16 work owner-gated.

## Sources and reproducibility

Six LIVE records are in sources-cycle59.json and the append-only sources.jsonl
ledger. Search-queries.json and raw web responses retain primary dates, full
ICICLE commit/license scope and access blockers. New MORPH and older zkMatrix
are architecture/cost filters; TensorZKP/ICICLE/TaSSLE are refreshes. October
Plonky3 exact release/crate fetches failed. No foreign claim was reproduced.

Evidence-pins.json records140 original log/marker/guard/source pins. Only
allowlisted public timings/sizes/proof identity metadata were copied from logs;
no raw private prover logs, tensors, weights, inputs, activations or tokens were
copied. Command/execution/hardware JSON and source copies make this accounting
experiment self-contained. Original source, production/runtime/Git/gates and
reviewer files were not modified; no external write/message or heavy job queued.

Accepted independently verified complete private 8B proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain and proof context: **unmeasured**. This cycle used one Intel Core Ultra 9 185H CPU thread (CPU0, nice19), no GPU. The retained native records are CPU-only T32, 22 separate one-block runs, zero linked complete-model passes; original thread count is not established here. No long-context prefill, resident complete-model workload or decode proof ran. Dense attention work grows approximately quadratically with context. Larger workloads remain allowed, fresh masks and privacy obligations remain unchanged, and the >=50 proved-token/s target remains unachieved.
