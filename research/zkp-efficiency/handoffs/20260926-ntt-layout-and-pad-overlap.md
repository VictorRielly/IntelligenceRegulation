# 2026-09-26 — mapped NTT contract and a pad-overlap repair candidate

For main Codex / Claude review. Research-only, no merge, production edit,
native build, GPU run, new receipt or privacy/soundness acceptance.

**Two actionable results:** a small exact oracle for accepting a mapped NTT
behind the existing store interface, and a reviewable CUDA coefficient fix
for q>n. Neither result establishes faster model proving.

## Interface and patch location

The seam is `zkp-core/src/pcs/backend.rs`: `Backend::try_commit_zk` receives
data, pads, coset powers and NTT tables, and returns unsalted column leaves
plus an `EncodedStore`. Its `columns(idx)` promises logical column values in
the request's order, including duplicates; `fold_rows` remains over systematic
data. Keeping an internal permutation is permissible only while preserving
all these returned values and the exact column hash byte streams.

The original prototype is
[`experiment.py`](../experiments/ntt-mapped-layout-20260926/experiment.py):
`mapped_encode(msg,pad,nn,A,h)` returns physical order, with
`physical(k,nn,A)=(k % (nn/A))*A + k/(nn/A)` for logical column k. It tests
input/pad/coset and output layout together. It is an algebra implementation,
not a Qingming port and not a device performance candidate by itself.

**Concrete repair proposal:**
[`cuda-pad-overlap.proposed.patch`](../experiments/ntt-mapped-layout-20260926/cuda-pad-overlap.proposed.patch)
targets `hashline/src/gpu/kernels.cu`, `k_zk_pad_scale`, around line 1402.
Source/proposed hashes are in
[`patch-provenance.json`](../experiments/ntt-mapped-layout-20260926/patch-provenance.json).
No production file was modified.

For each coefficient i the correct value before coset scaling is

```
(i<n ? data_coefficient[i] : 0)
  - (i<q ? pad[i] : 0)
  + (n<=i<n+q ? pad[i-n] : 0)
```

The inspected CUDA branch omits the negative contribution for n<=i<q.
The CPU's sequential pad loop handles the overlap. The inspected device
entry at `cuda.rs:3602` checks n+q<=nn, without q<=n. The chunked and opening
paths call the same kernel. Existing compact-pad tests cover q=n but their
inspected boundary cases do not cover an admitted q>n.

The proposed patch uses three independent conditions, retaining q<=n values.
Minimal counterexample: zero message at n=8, nn=32, q=9, pad[8]=1 and all
other pads zero. Correct x^16-x^8 versus inspected branch x^16, differing
at every coset point. This is source-derived scalar evidence only. Do not
describe accepted production proofs as broken without caller/device evidence.

## Validation and remaining gates

The [experiment report](../experiments/ntt-mapped-layout-20260926/README.md)
records 90 cases, 240 layout comparisons, 10,560 direct points, 360 Lagrange
checks, 15 full pre-existing vectors, nine negative controls and three
malformed-fixture refusals. It also checks all column byte streams of a small
batched/chunked store and unsorted repeated gathers. Final run: 0.5113 s,
16,968 KiB RSS, one CPU thread. Exact commands, seed and source hashes retained.

Owner's next gate for the **repair**: inspect q>n reachability, then reproduce
the minimal vector and n=16/q=19 or 48 through the actual existing GPU oracle
in an approved device slot. Exercise resident/chunked, compact/full pad width,
and opening re-encode routes. Apply the patch only after review; retain q<=n
frozen proof comparisons, leaves/columns parity, and refusal/RNG behavior.
No heavy/device job has been queued by this research lane.

For a **new NTT backend**, first run all 35 conformance vectors and actual
column hashing/gathers at production widths, then complete proof comparisons.
It must keep tagged-hash policy, entropy and pad draws, leaf/salt order,
systematic folds and natural logical query identities unchanged. Wider GPU
privacy acceptance is still owed independently of byte equality.

## Why this is not a speed claim

A replacement that emits mapped output might avoid a restoration copy by
mapping inside hashing/gathers. That condition does not hold for the current
natural-output CUDA encoder: it has no standalone restore to delete and
already has fused opening gathers. Bank/coalescing/occupancy costs can reverse
the proposed advantage. The research establishes compatibility obligations,
not a saving on current kernels. No external benchmark is transferred here.

The complete private 8B/512 prefill target stays <=10.24 s including witness
preparation and serialization, with five seconds a stretch; proving and
verification separate, autoregressive throughput unestablished.
