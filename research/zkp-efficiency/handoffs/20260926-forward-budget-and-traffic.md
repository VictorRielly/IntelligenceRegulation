# 2026-09-26 — 50-token/s forward-pass budget and traffic sensitivity

Standalone research handoff; **no production edits, GPU run, new proof, or
speedup measurement**. This task complements the existing explorer's NTT
layout oracle. Shared `STATE.md`, `FINDINGS.md`, and `sources.jsonl` are unchanged.

**Actionable result:** attach exact per-commitment byte/transfer counts to the
first model-width private profile before extrapolating hardware speed. The
target is **512 / 50 = 10.24 seconds per complete private prefill pass**, with
an average **320 ms/block** for 32 blocks before shared overhead. The earlier
five-second stretch corresponds to 102.4 prefill tokens/s and 156.25 ms/block.
These rates say nothing about autoregressive generated-token throughput.

## Reproducible local experiment

Run from the repository root:

```sh
python3 research/zkp-efficiency/experiments/forward-budget-20260926/experiment.py
```

[Source](../experiments/forward-budget-20260926/experiment.py) and
[retained result](../experiments/forward-budget-20260926/result.json).
Standard library, one CPU thread, 14 checks passed, about 0.001 s in the
experiment's timer and 15,368 KiB peak RSS. Those are script-resource
measurements, **not prover timings**. No dependency, native build, GPU or
private witness was used. Eight scalar-site enumeration checks independently
validate the compact matrix-MAC formulas. Other checks distinguish causal
attention from halving the whole model, one-way from aggregate PCIe bandwidth,
static weight preprocessing from per-proof work, and nearest-rank statistics.
The result pins the script and four existing source records with SHA-256.

The geometry comes from the historical Mistral-7B cost record: 32 layers,
512 positions, width 4096, FFN width 14336, 32 query heads, 8 KV heads,
head width 128. Its dense matrix work counts to 3,642,132,267,008 MACs,
including 2,886,218,022,912 FFN MACs. This does **not** count proof-field
operations, lookup work, norms, RoPE, endpoint handling or an output head.
It cannot be divided by advertised GPU tensor throughput to predict a proof.
It also does not establish the identity or parameter count of a trained 8B
checkpoint. Mistral-7B remains Mistral-7B even where old filenames say `8b`.

## What the retained speed evidence actually supports

The script re-parses the after-arm of
`results/hashline_convert_r3.log`, rather than copying a status summary:

| Historical public Mistral-7B FFN-only clock | Seconds | 512 / seconds |
|---|---:|---:|
| Proof generation | 58.40 | 8.767 tokens/s |
| Internal reported wall | 196.79 | 2.602 tokens/s |
| Enclosing process elapsed (`/usr/bin/time`) | 200.09 | 2.559 tokens/s |

Verification is 1.08 s; proof size is 1,234,936,956 bytes. The 134.50 s
`witness load+chain` clock reads previously exported witnesses. It is not
on-clock model inference. These are historical, shared-laptop measurements,
public IO, attention excluded, and not an accepted private-model result.

58.40 / 10.24 = **5.703125** is a comparison against a time budget only.
It is not the required speedup for the missing full-private 8B implementation.
The experiment deliberately reports that actual target gap as `null`.
Neither the internal wall nor process elapsed includes prior witness export.

## Conditional memory/transfer result — useful, but not an impossibility proof

The old Form-E memo's §G.2 estimates 26,676 attention commitment rows and
counts 17,471 FFN-side rows, including 10,752 public-weight rows. Its uniform
row scenario uses 16,384 base-field words/row, 8 bytes/word and rate-4
encoding. **This is an old architecture scenario, not an emitted 8B layout
or the measured current private-run memory footprint.** Approximately 60%
of its central row count is extrapolated attention. Small mask geometries,
actual buffer lifetimes, reuse, streaming and allocation overhead need native
counts. The experiment varies the attention estimate by 0.5x, 1x and 2x.

| Scenario | Resident/block, GB | Resident if all 32 retained, GB | Encoded pass, GB | One full encoded copy at ideal 64 GB/s |
|---|---:|---:|---:|---:|
| Half estimated attention | 20.19 | 646.11 | 516.89 | 8.08 s |
| Central estimate | 28.93 | 925.83 | 740.66 | 11.57 s |
| Double estimated attention | 46.41 | 1,485.27 | 1,188.21 | 18.57 s |

GB is decimal throughout. NVIDIA documents PCIe Gen5 x16 as **64 GB/s in
each direction**, 128 GB/s combined. Using 128 GB/s for one-way egress would
incorrectly halve the transfer bound. [NVIDIA architecture description](https://developer.nvidia.com/blog/nvidia-hopper-architecture-in-depth/)

Crucial control: after excluding the 10,752 weight rows from this *one-copy
scenario* as if their encoded commitments were reusable setup, the central
nonweight volume is 560.28 GB, giving **8.75 s**, not 11.57 s. Actual weight
opening work remains; preprocessing does not remove it. Moreover a device
need not export all encoded values at all: device-side hashes, retained stores
or selective opening gathers can avoid that transfer. Therefore the 11.57 s
calculation does **not** rule out the target. It rules out a particular
copy-everything strategy under the stated assumptions and highlights what
instrumentation must count.

For NTT memory traffic, the same central uniform-row scenario yields:

| Hypothetical global read+write passes per inverse / forward transform | Ideal HBM time, all rows | Ideal HBM time, nonweight commitment rows only |
|---|---:|---:|
| 14 / 16, one per radix-2 stage | 8.62 s | 6.52 s |
| 2 / 2 | 1.11 s | 0.84 s |
| 1 / 1 | 0.55 s | 0.42 s |

These divide counted traffic by the H100 SXM's advertised **3.35 TB/s**.
They are ideal throughput lower bounds for these hypothetical memory
schedules; even 50% of peak doubles the times. They exclude arithmetic,
hashing, witness generation, helpers, sumcheck, openings and serialization.
No assumption is made that the existing kernel performs one HBM pass per
radix stage. Fused stages are precisely why that model can overstate traffic.
[NVIDIA H100 specifications](https://www.nvidia.com/en-us/data-center/h100/)

## Primary-source refresh

The useful literature finding is an accounting warning, not a new five-second
claim. TensorZKP reports 215.28 ms at 2^25 multiplication gates on H100, with
52.9 GB memory at that scale and out-of-memory above its largest evaluated
size. It uses BabyBear with extension degree 8, HyperPlonk and Brakedown.
Those are different arithmetic and commitment choices from our
Goldilocks/Fp2 hiding-row NTT. Its pipeline/memory scheduling ideas merit
study; its gate rate does not predict this model's proving rate. No code or
timing was reproduced. [TensorZKP, USENIX Security 2026](https://www.usenix.org/system/files/usenixsecurity26-lu-tao.pdf)

The zkLLM authors report LLaMA-2-7B at 620 s prove, 2.36 s verify and 183 kB
proof for sequence length 2048 on an A100 40GB. The corresponding
2048/620 = 3.30 prefill positions/s is an arithmetic restatement of their
reported workload, not decode throughput or a 512-token estimate. Their
protocol/numerical/privacy contract was not audited for substitution here.
[zkLLM, CCS 2024, Table 1 and §8](https://hongyanz.github.io/publications/CCS_zkLLM.pdf)

ZKProphet's authors report that NTT can dominate their studied GPU proving
stacks and emphasize integer-pipeline utilization and memory/computation
overlap. That motivates measuring our actual byte traffic and instruction
mix; it is not evidence that our private model has the same bottleneck.
[ZKProphet, submitted September 17, 2025](https://arxiv.org/abs/2509.22684)

Accessed 2026-09-26. Exact URLs, known dates and access limitations are in
[source records](../experiments/forward-budget-20260926/source-records.json).

## Integration seam and next bounded action

First replace the historical uniform-row model with a **CPU-only layout
inventory** for the proposed actual 8B profile. For each commitment, emit
`profile/checkpoint ID, role, rows, data columns, encoded columns, pad words,
dtype bytes, lifetime interval, static/per-proof, opening strategy` from the
real layout constructor. Keep it diagnostic: no transcript, RNG, masking,
field, query count or statement change. Account for simultaneous buffers
and static weight reuse explicitly. Then the current arithmetic script can
consume exact dimensions in place of the old memo. This is not permission
to introduce a new profile without its existing soundness/privacy gates.

The device follow-up, when the integrator schedules it, should distinguish
actual host-to-device/device-to-host bytes, HBM reads+writes, commitment
encoding, opening re-encoding, and synchronization. Compare the **same**
profile/receipt path and report combined private-block wall time; byte
conformance alone does not establish speed or whole-proof privacy.

For the eventual claim, retain: trained 8B checkpoint/config identity;
every transformer block including attention+FFN; hidden input/output and
activations under P1, with P3 tracked separately; source/build/profile pins;
setup/cold/warm clocks; in-memory-input to serialized-proof time including
witness computation; independent deserialization+verification; proof size;
hardware, power and resident peaks. Report prove-only and ready-to-verify
rates separately. Use the established nearest-rank p50/p95 discipline;
20 warm complete-pass runs are needed for an eventual complete-pass p95
claim, while earlier expensive runs remain labelled single-shot/n-shot.
The D13 MVP scope is transformer blocks; embedding/final norm/head/token
selection remain the separately recorded milestone. This handoff neither
changes that decision nor claims token generation.

Privacy acceptance still applies only to the recorded D22 CPU toy artifact;
this arithmetic experiment closes no broader privacy/security obligation.
No batching across users, hidden-data-dependent sparsity, reused pads,
independently unbound layer receipts or field change is proposed.
