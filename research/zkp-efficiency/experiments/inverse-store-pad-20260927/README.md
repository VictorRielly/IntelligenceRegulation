# Inverse NTT final-store pad/coset fusion — cycle 0012

Run `20260927T035233Z-8a5c6f18`, 2026-09-27 UTC. This is a CPU-only
synthetic arithmetic and source-address experiment. No production source,
receipt, GPU kernel, proof or privacy statement changed.

```sh
python3 experiments/inverse-store-pad-20260927/experiment.py > experiments/inverse-store-pad-20260927/run.log 2>&1
```

Final [machine result](result.json): exit 0, seed **2026092712**, 56 shape/input
cases, 16 multirow chunk comparisons, 816 independently calculated points,
eight controls, 1.3943 seconds, 29,704 KiB peak RSS, one pinned CPU affinity
on Intel Core Ultra 9 185H, Python 3.10.12 on WSL2. The script enforces a
59-second wall alarm, 55 CPU seconds and 512 MiB address-space limit;
estimated peak was <40 MiB. `result.json` pins its own SHA-256 and exact
read-only production hashes for `hashline/src/gpu/{cuda.rs,kernels.cu}` and
`zkp-core/src/{pcs.rs,ntt.rs}`. Synthetic inputs contain no real weights,
activations, prompts or tokens.

## Baseline and proposed seam

The compact chunked hiding path calls `ntt_rows_view(... inverse=true)` into
`coef`, then `k_zk_pad_scale` into `coef2` at row stride `pw=n+q`, then the
forward `k_ntt_p1`. The inverse transform uses `k_ntt_p1` alone for `n<=4096`,
and `k_ntt_p1` followed by in-place `k_ntt_p2` for larger n. Its final pass
already multiplies by `1/n` on store. The proposed final pass writes directly
to the **already allocated, separate** `coef2` at stride `pw`. Each coefficient
store computes `(raw/n - [i<q]pad[i])*h^i`; each inverse block also owns one
contiguous disjoint portion of tail indices `n..n+q`, computing
`(pad[i-n] - [i<q]pad[i])*h^i`. The forward NTT still consumes compact
`coef2` with `n_src=pw` and zero-extends its tail. No pad/mask reuse occurs.

For `n>4096`, the first inverse pass still needs the existing `coef` scratch;
the last pass **reads** it and writes to `coef2`. Thus a separate destination
does not add a buffer, but also does **not** lower the two-buffer scratch peak.
For `n<=4096`, the only inverse pass could write `coef2` directly, making
`coef` unnecessary if callers change allocation lifetimes. Naively aliasing
`coef` and `coef2` with a widened row stride corrupts another row; the test
retains that negative. The current resident path writes `pw=nn`, so this
experiment applies directly to the **compact chunked commit and opening**;
resident integration would need a separate zero-tail/stride decision.

The independent reference computes the small-n inverse by direct DFT and
materializes the polynomial `f(X)+(X^n-1)g(X)` with separate additive loops;
for n<=16 it also evaluates the polynomial directly at coset points. The
candidate transcribes the current staged inverse's last-store ownership and
normalization. n is 2 through 16,384, q spans zero, q<n, q=n and q>n, with
full or dirty allocation tails. Three-row ragged chunk partitions use a
flat compact row stride. Controls catch wrong normalization, either pad sign,
missing coset, dirty-tail consumption, widened-stride aliasing and a legacy
q>n mismatch. At n>32 the inverse arithmetic and reference materialization
share the staged inverse output; only small cases have a fully independent
DFT. No native p2 thread mapping or compiled instructions were checked.

**Retained q>n negative:** `zkp-core/src/pcs.rs::encode_row_zk` accumulates
overlapping terms correctly; current CUDA `k_zk_pad_scale` selects one branch
and loses `-pad[i]` for `n<=i<q`. The candidate agrees with the CPU polynomial
and differs from that legacy GPU branch. q>n needs an explicit native
correctness fix and receipt review before any promotion; q<=n remains the
byte-parity path. The earlier NTT load-fusion sector regression is also
preserved: this design keeps the next p1's compact contiguous source.

## Isolated traffic model

The ledger covers only the inverse **last pass** plus pad/scale and their
scratch interface, per row. For `pw=n+q`:

- Baseline logical words: `2n` inverse read/write, then `n` coefficient
  reads, `2q` pad reads, `pw` power reads and `pw` output writes.
- Fused logical words: `n` inverse reads, `2q` pad reads, `pw` power reads
  and `pw` output writes. It removes exactly `16n` logical bytes per row,
  plus the pad kernel launch; new costs are pad/coset arithmetic and tail
  stores inside the inverse last pass.

| n, q, rows | Baseline bytes | Fused bytes | Removed bytes | Baseline/fused warp-sector requests | Scratch peak delta |
|---|---:|---:|---:|---:|---:|
| 1,024, 256, 1 | 49,152 | 32,768 | 16,384 | 2,304 / 1,792 | 8,192 B, if allocation changed |
| 16,384, 256, 1 | 663,552 | 401,408 | 262,144 | 20,736 / 12,544 | 0 |
| 16,384, 257, 3 | 1,990,752 | 1,204,320 | 786,432 | 63,292 / 38,754 | 0 |
| 16,384, 16,384, 1 | 1,179,648 | 917,504 | 262,144 | 36,864 / 28,672 | 0 |
| 16,384, 16,387, 1 | 1,179,744 | 917,600 | 262,144 | 36,868 / 29,834 | 0; corrected q>n baseline |

The address model counts distinct 32-byte sectors per warp instruction with
512 NTT threads, aligned allocations, separate memory instructions, no
inter-instruction cache reuse and a 32-lane warp. It includes bit-reversed
p1 loads for n<=4096 and p2 tile mapping for larger n. It is **not** DRAM
traffic, occupancy, SASS, transfer time or GPU wall time. For q near n, the
tail adds almost as much work to each last-pass block as its coefficient
store, so a real kernel may lose despite fewer counted sectors. Row-stride
alignment and compiler scheduling remain unmeasured.

## End-to-end consequence and falsification

The current old-arm 125M synthetic T512 CPU measurements spend roughly
16.4–16.8 s in all A/H encode plus Merkle work out of about 41.1–41.5 s
known witness+prove+serialization readiness. Even removing that **entire**
parent phase would save at most roughly 40% of this one-block readiness;
this proposal only removes a subset. GPU inverse-store/pad clocks and a
complete private 8B profile are absent, so the candidate's full-stack
ceiling and its effect on the >=50 proved-tokens/s target are **unknown**.
The newer owner [keyed GPU A/B](../../../../results/zk60_sol_gpu_20260927/attempt-5-dense-ab/report.json)
finished while this cycle ran: two non-warm RTX 4070 Laptop samples per arm
give GPU whole-process 30.055 s and prove 17.13 s versus CPU 39.895/32.95 s;
GPU witness 8.215 s, verification 0.815 s and a **combined** 3.895 s
serialization/other/startup residual. Serialization and startup are not
separately clocked in that report. It is a synthetic 125M single block,
shared two-thread host, fresh process/device per sample, 40,783,352-byte
verified receipts, unknown VRAM peak and no measured steady interval. The
remaining softmax work is roughly half GPU proving, so this narrower encoder
fusion moves below softmax acceleration in expected end-to-end priority.
The test completed zero independently verified complete-model passes and
zero countable proved tokens. Startup fraction, total/steady rates, proof
lag, witness/proof/serialization/verification device clocks and decode rate
are null. The reference 512 positions are one block's test geometry, not
complete-model proved tokens.

Falsify the performance idea if a compiled native q<=n path fails exact
encoded-column/leaf/receipt parity, increases peak memory, or fails to
improve the isolated inverse+pad **and** enclosing complete proof in a
quiesced GPU A/B. Preserve fresh pads/salts, transcript order and fallback;
security/privacy review remains with the main owner. [Handoff](../../handoffs/20260927-inverse-store-pad.md).

Primary search checked NVIDIA cuPQC 0.6.0's staged final-store API,
[its field limit](https://docs.nvidia.com/cuda/cupqc/libraries/cupqc_ntt/cupqc_ntt_feature.html),
[older GPU NTT locality work](https://eprint.iacr.org/2023/1410), and the
[2026 NTT/sumcheck hardware comparison](https://arxiv.org/abs/2606.16146).
cuPQC's custom prime bound `<2^62` excludes this project's Goldilocks
prime; the examples are Apache-2.0, but the required SDK has NVIDIA terms.
Author performance figures were not reproduced. Exact access/date/license/
commit qualifications are in `sources.jsonl` and [search log](search-log.md).
