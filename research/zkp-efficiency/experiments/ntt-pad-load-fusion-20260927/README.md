# Hiding-pad synthesis in the first NTT load — cycle 0010

**Exact arithmetic passes; no runtime improvement found. The large-row address
model weakens the proposed load fusion.** Run `20260927T015233Z-c29b434c`.
All inputs are synthetic. No native build, GPU job or proof ran.

```sh
python3 experiments/ntt-pad-load-fusion-20260927/experiment.py > experiments/ntt-pad-load-fusion-20260927/run.log 2>&1
```

Final run: **4.0622 seconds, 20,300 KiB peak RSS**, one CPU affinity, Intel Core
Ultra 9 185H, Python 3.10.12/WSL2. Seed **2026092710**. Enforced 59-second wall
alarm, 55 CPU seconds, 512 MiB address-space limit; estimated memory 48 MiB.
These are harness resource figures; proving, verification and readiness are null.
The earlier successful narrower run is retained in `initial/`.

## Contract, seam and comparisons

The baseline is the current **compact** `pw=n+q` hiding producer, with full-width
`pw=nn` retained as a control. It performs normalized inverse NTT, materializes
pad/coset-scaled `coef2`, then calls `k_ntt_p1` and the unchanged later stages.
The candidate retains the inverse transform and instead synthesizes at the
bit-reversed index i:

`([i<n] coef[i] - [i<q] pad[i] + [n<=i<n+q] pad[i-n]) * h^i`.

The Rust seam is `hashline/src/gpu/cuda.rs::encode_rows_view_zk[_gather]`;
the CUDA seam is `kernels.cu::k_ntt_p1`'s initial load. The normalized
coefficients are in natural order. Forward scale stays one. Existing p1
butterflies/stores and p2/gather layout must remain unchanged. The source
matches the grouped owner's GPU source at this inspection. Local snapshots
and SHA-256 pins are retained; no Git operation was used.

`fused_load.proposed.cuh` is an **uncompiled, unapplied load-helper sketch**,
not a complete dispatch or allocation patch. It is not recommended as the
default large-row path on this evidence. Its q>n overlap uses independent
contributions; the final pad branch avoids an add-to-zero when no negative
pad overlaps. Predication, branch divergence, occupancy and instruction cost
remain unmeasured.

The independent oracle directly inverts the DFT by summation, then evaluates
`f(x)+(x^n-1)g(x)` as two separate Horner polynomials at every coset point.
It uses no butterflies or candidate coefficient accessor. Existing native
synthetic conformance rows provide a third implementation reference.

- **138 cases, 828 full/compact comparisons, 12,912 direct output points**:
  n=2/8/16/64, q in {0,1,n/2,n,n+1,3n} (unique values), cosets 7/11,
  random/zero/near-prime inputs. Compare complete p1 intermediates and finals
  using stage split 2/3/12. Lowered split is a scalar mathematical check,
  not simulation of p2's native thread mapping.
- **15 native conformance vectors** agree in complete rows and digests.
- **Three sparse polynomial cases** at (n,nn,q)=(1024,4096,17),
  (2048,8192,256), (2048,8192,2051) check all **20,480 outputs** against
  independently generated sparse polynomials at the actual p1 split boundary.
- **16 flat-array chunk/stride comparisons**, seven rows, chunks 1/2/3/7,
  both strides, plus 256 column-byte comparisons and seven unsorted requests
  retaining duplicates. Reordered local loads also reproduce p1/final values.
- **13 negative controls, six malformed-fixture refusals**: absent bit reversal,
  wrong inverse scale, either missing pad sign, missing coset,
  stale chunk offsets, lost duplicates, wrong row order, mutated pads, compact
  stride mismatch and dirty zero tails, plus the legacy overlap counterexample.
  These are harness refusals, not native protocol-refusal coverage.

Current `k_zk_pad_scale` still omits a negative pad contribution for q>n.
For q<=n the source-derived legacy baseline agrees. For q>n the successful
comparison uses the **corrected materialized polynomial**, never claims parity
with the broken branch. The retained minimal n=8/q=9 case requires x^16-x^8;
the old branch gives x^16. This is the prior finding, not a new device result.

## Traffic and the negative result

Counts cover **pad/scale inputs and scratch plus the first NTT pass's data
load/store interface only**. They exclude inverse NTT, twiddles, shared-memory
operations, p2, hashing, uploads, pool behavior and opening work. They cannot
be used as a percentage saving for a whole encoder or proof.

For rows R and compact W=n+q, u64 words are:

- baseline: `R*(n+2q+3W+nn)`;
- fused: `R*(n+2q+W+nn)`;
- removed scratch traffic: `16*R*W` bytes, logical allocation `8*R*W` bytes.

Coefficient, pad and power reads are all included. Both compact arms perform
R*W coset multiplies. Full-width materialization performs R*nn; that earlier
compact-path saving is not credited to this candidate. The memory pool may
retain freed capacity, so removing an allocation is not measured peak-VRAM
reduction.

| Source-address model | Compact logical bytes | Fused logical bytes | Compact sector requests | Fused sector requests |
|---|---:|---:|---:|---:|
| n=1,024, q=256, nn=4,096, one row | 75,776 | 55,296 | 3,328 | 3,840 |
| n=2,048, q=256, nn=8,192, one row | 141,312 | 104,448 | 6,144 | 6,912 |
| n=16,384, q=256, nn=65,536, one row | 1,058,816 | 792,576 | 45,568 | 49,920 |

The final row removes **266,240 logical bytes (25.145%)** and a 133,120-byte
logical allocation, yet increases counted sector requests **9.551%**. Replacing
one scattered `coef2` read by scattered coefficient/pad/power reads explains
the difference. Three rows have the same ratio. q=n raises sector requests
26.316%. Independent closed-form sector formulas check the aligned q=256 row.

The sector model counts distinct aligned 32-byte sectors per source-level warp
memory instruction, assuming separate aligned allocations and no reuse across
instructions/warps. It is **not** compiled SASS, cache misses, DRAM traffic,
measured bandwidth or time. Compiler load merging and power/pad cache reuse
could change the actual cost. NVIDIA's [coalescing documentation](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/)
supports this modeling unit; it does not validate our kernel performance.

Loading in natural local-index order into bit-reversed shared locations lowers
sector counts in the small single-pass model. Against an equally reordered
baseline, n=1,024 falls 2,368 -> 1,728 requests. At nn=65,536 a block still
owns every 16th coefficient, so reordering gives **no** sector improvement.
Shared-memory bank conflicts of that reordering are not priced. The large-row
negative survives this simple attempted remedy.

## End-to-end disposition and next work

The owner dense 125M two-thread CPU logs remain proving 34.861/33.315 s,
witness 5.43/5.76 s, serialization .031/.020 s: known readiness 40.322/39.095 s.
Verification is .900/.810 s internally and .91/.82 s from bytes, separately.
A+H encode/Merkle costs 16.739/16.903 s. Four non-warm logs and the comparison
hash were rechecked, terminal zero; these are not this lane's benchmarks.
The GPU pad/p1 phase has no attribution; even the whole CPU commitment phase
cannot be used as its predicted saving. No complete private 8B timing exists.

Next memory experiment: move pad/coset production to the **normalized inverse
NTT final store**, aiming to eliminate the `coef` pass while retaining compact
`coef2` and forward-load locality. Test separate q<=n and q>n ownership, actual
multi-pass overwrite hazards, normalized scale, ragged chunks and dirty pool
tails. Unlike the present load fusion, the inverse p2 reads/writes in place:
changing its destination stride may require a separate buffer, erasing the
gain. Count all lifetimes and sectors before proposing a native patch.

The rotation next visits lookup/softmax: test direct split-limb H helper writes
at `helper_*_u8_at -> write_h`, against current cached-inverse Vec production.
Keep arbitrary-invalid fallback, full-table denominator refusals and stage order;
test partial private writes on refusal and unchanged row padding. This targets
temporary memory and a ~1.05–1.13 s helper phase, not the entire H commitment.
Native GPU/receipt/privacy review and whole readiness timing belong to main
under shared locks. See the handoff and source records for access limitations.
