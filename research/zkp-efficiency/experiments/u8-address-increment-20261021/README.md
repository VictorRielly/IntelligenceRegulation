# U8 ordered one-hot address/increment contracts — cycle0121

Run `20261021T051854Z-3d9d2756`. **No proving speedup measured.** The diagnostic passes
3337checks/512factor fixtures/128complement fixtures/48dense MLE cases;
51control types. Source audit:51checks,
6pinned native files. These are independent reference implementations authored
here, not an external review or native prover.

The selected native-hashing transplant fails the DATA-byte test. Native U8H
pairs two inverse columns perFp2. Factoring a256-way onehot row into d1/2/4/8
parts costs256/32/16/16 basewords per query. Virtual complementary bit entries
reduce this to8words, still7.54x original U8H at frozen8B T128nonDD. Nonzero
counts alone do not reduce dense PCS encoded payload. No general sparse/private
lower bound is claimed and no actual memory peak or runtime is measured.

| Counted 8B geometry | Native U8 helper data MiB | Dense factored d4/d8 data GiB | Virtual-complement bits GiB |
|---|---:|---:|---:|
| T128 nonDD | 420.25 | 6.191406 | 3.095703 |
| T128 DD | 390.25 | 5.769531 | 2.884766 |
| T512 nonDD counted-only | 2480.50 | 36.507812 | 18.253906 |
| T512 DD counted-only | 1760.50 | 26.195312 | 13.097656 |


`candidate.py::check_factors/check_bits/check_events` are direct validators of
synthetic witnesses. `reference.py` independently indexes tables and expands
dense matrices; no imports from candidate. `sparse_mle/factored_mle/bits_mle`
match explicit dense sums. A product of factor MLEs at a nonBoolean time differs
from the MLE of the product: a reviewed private reduction remains necessary.
Histogram-only and source-unlinked one-hot checks admit reordered queries.
The event/increment trace is an optional diagnostic, not mandatory for read-only
Shout. No commitments, masks, transcript, native refusal, PCS, receipt or verifier.

See [cost-result.json](cost-result.json), [source-anchors.json](source-anchors.json),
[ranked queue](hypotheses.json) and [owner review note](../../handoffs/20261021-u8-onehot-contract.md).
Source hashes/commands/seed/hardware retained. Unknown mask/commitment/group costs
are null, never zero. Baseline excludes newer fidelity LOW/HIGH layouts.

Reproduce sequentially from research root:

```text
python3 experiments/u8-address-increment-20261021/run_bounded.py probe.py
python3 experiments/u8-address-increment-20261021/run_bounded.py source_audit.py
python3 experiments/u8-address-increment-20261021/run_bounded.py artifact_audit.py
```

Seed202610210121,oneCPU/nice19,30sCPU/alarm,35sparent,256MiBAS,
64MiB estimate. Probe/source audit 1.209593/0.005457s,
RSS12268/14840KiB on Intel(R) Core(TM) Ultra 9 185H. These are script clocks.
Artifact auditing requires the retained final manifest/reports and checks the
append-only prefixes and independent logical/native-anchor formulas.

Search: [Twist/Shout](https://eprint.iacr.org/2025/105) revised2026-10-17;
[JoltBook virtualization](https://jolt.a16zcrypto.com/how/twist-shout.html);
[current privacy boundary](https://jolt.a16zcrypto.com/how/blindfold.html).
Akita docs currently excludeZK; no announced lattice speed is a private8B result.
Other searched primary URLs/dates/licenses/fetch failures are in13source records.
Nine LIVE queries; no foreign code executed or upstream performance reproduced.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel(R) Core(TM) Ultra 9 185H
CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, repeated resident-model proof passes or decode ran.
T128/T512 are symbolic geometries; T512 is unregistered counted-only, not an
admitted workload. Longer workloads remain allowed; increasing context can
increase attention work quadratically. The complete private8B >=50 proved
tokens/s target on RTX5090 or another named high-end GPU remains unachieved.


Next: original affine-source sharing census with exact symmetric/scaled/support
refusal controls before any bitplane protocol. Top owner priorities unchanged.
Free-deletion ceiling1/(1-f),unknownf,precedes all added private proof costs.
Only research written; main/Claude reviews and integrates; no merge.

Checkpoint amendment, 2026-10-21 05:32 UTC: live decisions changed during this
cycle. D30 now records the completed DD gate:13/13 staged records PASS,zero
unexplained leaves,on the DD dev rung and TinyLlama T128 L1/2. This is gate
evidence only; no privacy statement yet covers a DD profile. It is not8B/GPU
privacy acceptance. Rank2 prerequisite/status updated; top-four order unchanged.
The exact live decision copy/diff is retained; no owner evidence reproduced.
