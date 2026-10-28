# FZC phase accounting — 2026-10-21, cycle 0120

Run `20261021T041854Z-cfd5ba2e`. **No proving speedup measured.** This is a
measurement prerequisite for the existing scratch reuse hypothesis. Source audit
finds that current successful FZC totals omit pre-body and post-report work;
the CPU-tail timer stops before local buffer destruction. Errors can return
without successful aggregation. The magnitudes are unknown, and this does not
establish an omission from enclosing complete-proof clocks.

The proposed strict public-metadata schema passes **6,829 checks** over **1,500
synthetic nested traces**, including clocks above 2^53, and **400 dependency
graphs**. There are **21 control types**. A separately implemented integer-tick
reference imports no candidate code; a recursive path reference checks max-plus
DAG results. These are independent references by the same researcher, not an
external review. A separate source/order/role audit passes **59 checks** and
matches three current source hashes. No native instrumented adapter exists.

Useful negative: the same allocation API duration, 8 units in a 30-unit
synthetic workload, yields either 0 or 8 units saved when removed, depending on
dependencies. Counts and API fractions do not determine end-to-end benefit.
Parent and child times must not be added; parallel thread-wall is not workload
elapsed; host ranges are not device durations. Mandatory clearing/binding/fences
remain costs of safe pooling. Runtime pooling is parked pending materiality data.

Research code: `accounting.py::summarize`, `family_thread_wall`, `critical_path`;
independent oracle: `reference.py`; source obligations: `source_audit.py`.
The [measurement proposal](MEASUREMENT.md) gives source seams, role sizes,
exactness/privacy obligations, full-workload gates and a falsifier. No production
code, transcript order, arithmetic, masking or receipts changed.

Reproduce sequentially from the research directory:

```
python3 experiments/fzc-phase-accounting-20261021/run_bounded.py probe.py
python3 experiments/fzc-phase-accounting-20261021/run_bounded.py source_audit.py
python3 experiments/fzc-phase-accounting-20261021/run_bounded.py artifact_audit.py
```

Seed 202610210120. Each child: one worker, first allowed CPU, nice19, 30s
CPU/alarm, 35s parent timeout, 256MiB address space, estimated <=32MiB memory.
Final probe/source-audit diagnostics: 0.880925 / 0.031524 s; RSS 12,344 /
18,636 KiB on Intel Core Ultra 9 185H. These are checking-script clocks. Earlier
successful probe refinement is recorded in commands.jsonl; final files supersede it.

Eight native LIVE queries and nine primary records cover current GPU integration,
profiling, releases and lookup/composition filters. The newly assessed older
2020 NVIDIA overhead article supports checking trace perturbation and overlap;
current Nsight docs warn of event-tracing overhead/dependencies. No upstream
performance was reproduced. NVTX commit and separate Rust license fetches
cache-missed; root Apache-2.0+LLVM-exceptions body was inspected, without a
crate-specific license conclusion. Exact URLs/dates and null commit IDs are
retained. The repeated nonlinear lookup source does not overturn the prior
negative that native public tables already have 256 entries.

New completed, independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. Research device:
one CPU worker. Witness, proof, serialization, verification, startup duration /
fraction, steady-state throughput and total-workload throughput: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic
traces are not model passes. Longer workloads remain allowed; longer contexts
can increase attention work quadratically. The private 8B >=50-token/s target
remains unachieved.

All 34 hypotheses are preserved. Rank3 is materially refined; owner top four
remain complete GPU/resident clocks, larger-context DD, private lifetime/phase
telemetry and native all-eleven FZC A/B. D41 classifier chunking is recorded as
separate product direction, without amending this lane's private8B target.
Next local experiment: rank25 sparse one-hot U8 address/increment contract,
independent ordered-query/histogram controls and dense256-way cost accounting.
Do not repeat table-size preprocessing or scratch safety without new evidence.

Only research files outside runtime/ written. No production/Git/build/GPU/
installation/downloaded-code execution/external writes/messages/escalation.
Main/Claude reviews and integrates; no merge. Saved files are not notifications
or evidence of supervisor liveness.
