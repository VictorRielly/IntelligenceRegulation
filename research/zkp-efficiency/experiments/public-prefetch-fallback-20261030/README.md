# Cycle0165 — public prefetch source incidence and refusal boundary

Run `20261030T134123Z-9551f712`, 2026-10-30 UTC. **No measured proving
improvement.** The experiment is source accounting and a tiny real Linux
advisory-I/O correctness projection. It runs no native loader or prover.

The leading local H97 question was whether public-weight prefetch can hide
recurring waits. Inspection found two useful limits: `seal_and_record` already
overlaps the next layer load with witness construction; the active CUDA
commitment adapter waits for field-data upload. A raw public file hint neither
removes fresh per-proof commitment inputs nor makes the CUDA API asynchronous.
Proof-pass `BlockCache::get` still reloads/authenticates on demand.

At public Llama8B geometry D4096/F14336/Fpad16384/Q32/KV8/head128/T128,
the nine returned padded weight arrays plus tables contain 243,411,456 B
(232.135254 MiB). A source-scope subtotal for the next loader is
704,803,840 B (672.153320 MiB): eleven raw arrays, nine padded intermediates
and the returned block. With one old public block retained, this subtotal is
948,215,296 B (904.288574 MiB), before the current witness/proof. This is not
an observed native peak or an admission bound. It omits generated/exported
RoPE source buffers, cast/index/hash temporaries, capacities/headers,
metadata, witness, PCS, run boundaries, page cache, pools and the driver.
It does not allocate real model arrays. Twenty-four public geometries agree
between independent named-array and algebraic formulas.

The new narrower H98 candidate uses bounded WILLNEED hints and retains the
original demand reload. Sixteen synthetic fixtures, thirteen public files
each, four byte styles and five budgets pass **7,107 checks**, including
**5,200 negative controls**. There are 1,248 mutation cases: same-size changes,
truncate/extend, path replacement, deletion and symlink replacement after
advice. Both separately authored loader projections refuse them in full-hash
and rebuilt-binding modes. Reusing the old hydrated snapshot still accepts
the old pin in all 1,248 cases: that changes current-file refusal semantics,
not a proof forgery or a defect claimed against native code. Identity swaps,
file-order changes, malformed advice descriptors and unsupported-hint controls
are included. Concurrent mutation races and native refusal order are untested.

**1,556 actual advisory calls requested 18,536 range bytes**, entirely in
newly authored tiny research files. No actual I/O, residency, cache-memory
bound or latency benefit follows from a successful advisory call. Zero-byte
requests are suppressed because the syscall interprets zero as through EOF.
Hint failure leaves demand acceptance unchanged. The hash projection uses
SHA-256 and a research-only serialization; native BLAKE3, padding, registered
tables, full metadata, randomness, transcripts and privacy are not executed.
Prior cycle0132 holds separate padded-byte evidence; it is not relabeled as
new evidence here. Initial undercount of mutation-phase advisory calls was
corrected; code/PASS/logs are retained in `initial-advice-count-correction/`.

Independent audit: **295 checks PASS**, importing no candidate/experiment
code. Ten native pins and eighteen literal source facts check. Final experiment
process 0.569266 s / 18,392 KiB RSS; audit 0.033306 s / 17,400 KiB. These are
correctness-check process clocks, not proving or I/O benchmark clocks. One
nice19 CPU affinity, 30 s CPU / 40 s alarm / 45 s parent / 256 MiB address-space
cap, 64 MiB estimate; Intel Core Ultra 9 185H, Python3.10.12, no GPU.

Reproduce, sequentially from the research directory:

```
python3 -B experiments/public-prefetch-fallback-20261030/run_bounded.py experiment
python3 -B experiments/public-prefetch-fallback-20261030/run_bounded.py audit
```

`candidate.py`, `reference.py`, source pins, commands, raw logs, seed20261030165,
dimensions, payload and commitment-input ledgers are retained. The bounded
experiment rerun refreshes its snapshots: use saved pins for a historical
audit before running against later owner source. Main/Claude reviews/ports;
no production patch or merge. [Integration boundary](INTEGRATION.md).

H97 is demoted behind native exclusive evidence; H98 is a conditional source
and refusal prerequisite. Baseline is the actual on-demand proving reload,
not an imagined serial sealing pass. Removed field/mask work is zero; only
measured exposed file wait could be hidden. Added syscall, cache pressure,
storage/memory contention and scheduling costs are unknown. Ceiling
N/(T-S+A), necessary >=50 condition T-S+A <= N/50; S/A unmeasured. Falsify on
changed bytes/refusals, absent exposed I/O, hot-cache no-op, capacity regression
or A >= S. Top3 remain complete high-end-GPU resident workloads, admitted
context/fidelity scaling and native exclusive phase/capacity measurements.

New independently verified full-stack proofs / complete-model passes / proved
positions: **0 / 0 / 0**. Actual model context: **none**; device: **one CPU
affinity, no GPU**. Witness/proof/serialization/verification/startup/initial
prefill clocks, startup fraction, proof bytes/latency and steady/total proved
token rates: **unmeasured**. No long-context prefill, resident proof passes or
decode ran. Public geometry T17/32/64/128/256/512 is not an actual workload.
Larger workloads remain allowed; attention can grow quadratically. Private8B
>=50 proved tokens/s on RTX5090 or another named high-end GPU is unachieved.

Only research outside `runtime/` was written. No production/Git/receipt/
calibration/gate/instruction/reviewer mutation, native build, GPU, dependency
installation, foreign-code execution, external write/message, purchase or
escalation. Saved reports do not establish user-message delivery or liveness.
