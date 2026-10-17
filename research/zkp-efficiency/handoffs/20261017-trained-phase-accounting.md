# Handoff: count both witness passes before interpreting prover speed

Cycle0059, `20261017T092624Z-0a2ee588`, 2026-10-17T09:36:09.547899+00:00. Research-only; main agent/Claude reviews and
integrates. No speedup, native compilation or privacy acceptance is established.

Retained trained TinyLlama CPU T32 records show294.314s witness/parity out of
405.980s summed main-path totals (72.49%), versus82.500s prove_run (20.32%).
These are22 separately verified one-block diagnostics, not one bound stack.
They use calibration `a_export_T32` / sequence `ho00` and the historical t5
CLI, not the new `pg_rot1` calibration or current round2 stack.
Removing their entire prove_run clock would have a1.25504x ideal ceiling.
Removing measured model load alone has a1.04115x ceiling. Startup fraction and
8B ceiling are unknown. This changes priority toward recurring exact witnesses.

Historical one-block witness is created before prove_run and consumed once.
The current stack performs a sealing witness pass, then a proving rebuild.
Its source cache prevents another build for the paired boundary/witness calls.
The sealing pass is input-dependent and preserves full witness refusals; simply
labelling it one-time model startup would undercount repeated resident workloads.
No mask, commitment randomness or opening may be reused to improve amortization.

Native seam (read-only owner tree):
`ops/zkp-mvp/trained-1b/hashline/src/private_block/run.rs`, RunStats/prove_run;
`trained_block.rs`, parity/OneBlock/StackSource/stack_prove_inner;
`run_sink.rs`, DirSink::accept; `wire.rs`, encode/decode_segment.
RunStats.prove_s's comment says witness excluded, while its timer encloses source
calls, encoding and sink. DirSink includes write_all,sync_all,rename and SHA256.
Fresh verifier read/decode/crypto clocks still need separation.

Research patch:
[phase-probe-candidate.patch](../experiments/trained-phase-accounting-20261017/phase-probe-candidate.patch),
base run.rs SHA256296aeaafd3bd8a026c93f04f66d5a0dd4c200c81fa31f94e71a86d8d8eebdbe5.
It adds `RunStats.setup_s: f64`, and per-stage `source_witness_s`, `encode_s`,
`sink_s: Vec<f64>`, and corrects the inclusive timer comment. Those three vectors
are subsets of `prove_s`, never additive siblings. Existing `StackSource.busy_s`
is also a subset of prove_run, after restart resets the sealing counter.
Patch has8 exact replacements /6 diff hunks. It is a diagnostic sketch, not an
integrated or compiled implementation. Choose opt-in reporting in owner code;
charge Instant calls/reporting overhead and preserve aggregate-only metadata.

Validation:22 fresh verifier record pairs agree on hash/statement/size and all
markers/guards succeed; no receipt was reverified by the researcher. The archived
CLI/run sources reconstructed from the retained patch match t5 manifest hashes.
16,219 checks include independent integer-ms and interval-sweep references,
200 synthetic traces and15 negative controls. Independent audit499 checks;
all140 evidence pins match. Wall0.1072s and0.00432s, maxRSS17,052KiB, one thread.

Missing gates: native compile/API callers, frozen samples/finals/refusals/RNG/
transcript/proof bytes, source privacy review, independent fresh verification and
all enclosing clocks. Candidate adds no field arithmetic or proof optimization.
No public/trained/model-scale result or >=50/s conclusion follows.

Owner next: complete linked trained receipt with split clocks, then resident
fixed-context fresh-mask passes, actual initialization,lag/drain,peak memory and
fresh independent verification. If recurring complete cost exceeds20ms/new
proved position, startup amortization alone cannot reach50/s for that schedule.
Keep long-context prefill and decode separate. Local next: exact witness source
census to select matmul/requant/materialization work from evidence.

[Experiment, pins and reproduction](../experiments/trained-phase-accounting-20261017/README.md).
