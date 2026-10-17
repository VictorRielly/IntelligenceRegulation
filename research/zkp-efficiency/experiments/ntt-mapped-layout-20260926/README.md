# Mapped hiding-row encode — 2026-09-26, cycle 0003

**Exact layout compatibility passes; no runtime improvement established.** A
source-derived CUDA pad-overlap discrepancy is also isolated. This is a CPU
arithmetic experiment, not a native/device test or a reproduced upstream NTT.

Run from `research/zkp-efficiency`:

```sh
python3 experiments/ntt-mapped-layout-20260926/experiment.py > experiments/ntt-mapped-layout-20260926/run.log 2>&1
```

Standard library only. Seed `20260926`; one thread pinned to CPU 0; 59-second
alarm, 55-second CPU limit, 512 MiB address-space cap, estimated memory 32 MiB.
Final run: **0.5113 s**, **16,968 KiB** peak RSS on Intel Core Ultra 9 185H,
WSL2 Linux, Python 3.10.12. These are experiment-resource figures, not proving
or verification clocks. Both proof clocks and complete readiness are null.

## Contract and independent checks

The logical output at column k is `f_data(x) + (x^n-1)*g_pad(x)`, where
`x = h*omega_nn^k`; `f_data` interpolates the message on the n-point subgroup.
Values use canonical Goldilocks representatives and eight little-endian bytes.

The candidate uses an inverse DIF transform with bit-reversed coefficients,
an address accessor that adds both pad contributions, and a two-factor DFT:
`nn=A*B`, input index `j=j0+A*j1`, output frequency `k=k1+B*k0`. It performs
B-point transforms, applies the cross twiddle, then A-point transforms. It
retains output at physical index `p=k1*A+k0`. The column adapter maps logical
`k` to `(k % B)*A + k/B`; non-square splits test direction mistakes.

The independent oracle uses direct inverse-DFT summation and separate Horner
evaluation of the data/pad polynomials, without any butterfly or output map.
A second oracle evaluates the closed-form Lagrange basis at four points per
case. A source-derived CPU DIT follows the shared-table twiddle convention.

- 90 cases: n=8/16/64, rate 4; q=0,n/2,n,n+3,3n; zero/random/edge values;
  h=7/11. These are algebra fixtures, not authorized security profiles.
- 240 mapped-layout comparisons; 10,560 direct output points; 360 Lagrange
  checks. Shared CPU twiddle table has twice the output domain size.
- All **15** existing conformance vectors at n<=64 match full arrays and
  digests. No production-width transform or claim about all 35 vectors.
- Five-row store: all 64 logical column byte strings and 64 chunked byte
  streams match, including a partial last chunk. Seven unsorted opening
  requests retain duplicates and order. No actual BLAKE3 kernel executed.
- Nine negative controls detected: wrong order, inverse permutation, absent
  coset, wrong inverse scale, absent cross twiddle, pad overlap, pad mutation,
  lost duplicates, reversed rows. Three malformed algebra fixtures refused.

## New boundary finding

The inspected `k_zk_pad_scale` uses mutually exclusive data/pad branches.
For q>n it omits `-pad[i]` at n<=i<q. Its caller checks n+q<=nn, which does
not exclude this overlap. The source-derived branch agrees at q=0/8/16 and
differs at every column for n=16, nn=64, q=19/48 in this experiment.

Minimal synthetic counterexample: n=8, nn=32, q=9, zero message, only
pad[8]=1. The required polynomial is x^16-x^8; the branch gives x^16.
The difference x^8 is nonzero at all 32 coset points. This is an algebraic
source finding, **not actual-device reproduction or evidence of an affected
accepted receipt**. Tested ordinary profile widths have q<=n; broader caller
reachability and device handling remain for the owner to inspect.

`cuda-pad-overlap.proposed.patch` expresses the three contributions with
independent conditions. It is NOT applied or compiled. `patch-provenance.json`
pins its read-only source and proposed result. Review/native/device work belongs
to main under the shared locks.

## Impact limits

Avoiding a separate mapped-to-natural restoration copy would remove
`16*rows*nn` counted bytes (one u64 read and write). At nn=65,536 this is
1,048,576 bytes per row, **conditional on an alternative that otherwise makes
that copy**. The current CUDA forward already stores natural order directly
and already has opening gather fusion; its measured saving here is none.
Mapped access may worsen coalescing. Hash tags, salts, RNG, fold semantics,
opening schedule, verifier and transcript were not exercised.

See [handoff](../../handoffs/20260926-ntt-layout-and-pad-overlap.md),
`result.json`, `validation.json`, `source-records.json` and `search-log.json`.
