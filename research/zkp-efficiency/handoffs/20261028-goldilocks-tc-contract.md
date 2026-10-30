# Goldilocks Tensor Core contract — cycle 0130 handoff

Research-only; no merge, build or GPU job. **No proving speedup measured.**
Run `20261028T235649Z-d1bc0725`; completed 2026-10-29 UTC.

The stock external driver selects a friendly <=62-bit reducer and rejects
Goldilocks, even though `modulus_bits=64`. The general Montgomery multiplier
has a broader arithmetic contract, but swapping it into lazy `2N` butterflies
still fails. These are unsupported-port controls, not upstream defects.

The useful deliverable is a separately authored dot16 reducer contract:
eight overlapping u32 t words -> canonical Goldilocks output, with explicit
carry propagation, `2^128=-2^32` and fixed scale inverse `2^32-1`. Canonical
P-1 inputs require top carry 15; a u128 truncation is insufficient. Dot16
combined accumulators fit signed32 under the inspected decomposition;
extending the same construction to32 would require new bounds.

Patch/sketch location:
`experiments/goldilocks-tc-contract-20261028/candidate-reducer.cuh.txt`.
It requires native `gl_reduce/gl_sub/gl_mul`, public binding to P_GL, a
compatible host annotation and the source matrix's factor128 contract.
It is uncompiled/unapplied, with no lane/MMA/WMMA simulation or complete NTT.
Python adapter/reference are `candidate.py`, `reference.py`; run `run.py`.

Validation: 39,179 synthetic checks, 12,441 products, 18 radix2 n2..64
fixtures, 35 dot16 fixtures, four scaled/bit-reversed matrix16 cases and
54 controls. Independent bigint/direct DFT references. 0.093988 s /15,608 KiB
RSS, one CPU thread. Separate774-check source/provenance audit passes;
seven native pins unchanged. All old source/results and negative findings
are retained. Not native compilation, receipt, verification or privacy evidence.

Primary source: immutable
`https://github.com/Terminus-IMRC/tensor-core-ntt/commit/6f407daa8a4cef96331511ae86b922b520d7aa33`.
Apache-2.0 SPDX inspected in immutable modular/NTT headers and driver.
Full numbered header renderings retained, not byte-exact Git blob hashes.
Immutable arithmetic helper fetch failed; main helper body only. No foreign
code executed, whole-tree audit or author benchmark reproduction.

Integration seam: distinct custom `reduction_type` at external
`NttForward16x16Coalesced` / WMMA and native batched row encoding through
`hashline/src/gpu/{kernels.cu::k_ntt_p1/p2,cuda.rs::encode_rows_view_zk[_gather]}`.
Native canonical field, root/output order, inverse normalization, coset,
zero-extension stride, hiding pads including q>n, keyed hashing and opening
bytes must remain. Preserve fresh mask/pad/salt draws, refusal and transcript
ordering, all claims and full attention+FFN coverage.

Owner gate before investment: exclusive inverse/forward NTT, encoding and
enclosing verified-workload clocks with actual eligible geometry. A custom
Tensor adapter adds packing,64MMA/matrix,carry/scaling,transpose,registers and
scratch. General scalar helper also doubles twiddle parameter bytes and adds
a high product versus the native special-prime multiply. No numeric GPU or
whole-model ceiling: free whole-phase deletion <=1/(1-f), f unknown.
If material, compile and perform required device/CPU/golden/masked/next-RNG/
refusal/PCS/privacy and independent full-receipt gates under current locks.
Reject any mismatch, no eligible incidence or enclosing workload regression.

No further carry-only arithmetic refinements ahead of native measurements.
Next bounded local action: inspect R12b `tied_tables/derive.rs` residency
contract and previous loader findings, then synthetic changed-public-file /
parameter tests for a fully bound immutable derived object. The new owner
17–18 s/load note is Shieldstral3B, not an 8B startup/throughput measurement.
Top owner priorities remain whole-prover GPU/resident1/2/4/8, DD/fidelity
scaling and complete clocks. Main/Claude reviews and integrates.
