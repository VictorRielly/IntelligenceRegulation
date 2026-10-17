# Native generator-7 shift twiddles — cycle0045

Run `20261013T022555Z-d570e67c`, 2026-10-13 UTC. **Exact synthetic
compatibility passes; no measured proving improvement.** No native build,
GPU execution, downloaded-code execution or production modification occurred.

The final one-thread Python validation took **1.324346s, 20,208KiB RSS** on
Intel Core Ultra9 185H, affinity CPU0, nice19. Seed2026101345; enforced59s
wall/CPU and512MiB address-space caps, estimated32MiB. The elapsed number
times this validation script, not an NTT benchmark or witness/proof phase.

## Baseline and question

Current retained evidence remains the two non-warm samples of one **synthetic
125M block**, RTX4070 Laptop, shared host/two CPU threads: mean17.13s proving,
8.215s witness and30.054918s enclosing process wall, verification0.815s.
The3.894918s residual combines serialization and other work, including device
startup; it is neither an isolated serialization nor startup measurement.
Roughly half of GPU-assisted proving remains softmax work. These numbers
are not an accepted complete private8B baseline. The interrupted production
12-block run has no result. All three evidence reports are pinned here.

Native CUDA already caches monotonic stage-major twiddles, fuses the first
up-to12 stages and later stages, prunes supported openings and skips known
zero-pad stages. There is **no new launch saving** in this proposal. Can
public native twiddles eliminate general64x64 products without changing any
canonical output, root, ordering, coset, inverse scaling or masking?

## Tested arithmetic and actual roots

The base field is unchanged: p=2^64-2^32+1. The element2 has exact order192:
2^96=-1 and2^192=1;96 and64 rule out the proper maximal divisors.
After reducing an exponent modulo192 and its sign, e<96. The product a<<e
has at most three u64 limbs. Existing native `gl_reduce(lo,mid)` handles
the bottom128 bits; a high limb contributes **-high*2^32**, since
2^128=-2^32. That high<<32 is exact and canonical for e<96. Negation retains
zero. No u64 shift by64 occurs. `arithmetic.py` models the exact wrap/borrow/
carry semantics and uses no modulo or general product in `shift_mul`.

Native roots for logs0..6 have exponents **0,96,48,120,156,78,39**.
In particular the order8 root differs from the paper's2^24 example. Use
the existing generator7 roots. Every native stage<=6 twiddle is eligible;
at stage>6 precisely k divisible by2^(stage-6) is eligible, with exponent
39*(k>>[stage-6]) modulo192. Inverse tables negate that exponent.
`stage_exponent` is a public metadata plan, not a per-value hash lookup.

## Validation and controls

Final result has38,592 exact-integer shift checks,4,096 arbitrary128-bit native
reducer checks and4,096 general fallbacks. The full forward/inverse max-log12
table supplies8,190 native stage-major entries,8,190 eligibility and dispatch
exponent checks, and24,570 checks each of membership and stage arithmetic.
Stages13..32 have1,280 eligible and1,280 ineligible samples, plus1,280 checks
each of dispatch exponents, arithmetic and fallback. All33 inverse-size
scale exponents are checked. Large lengths are algebraic/sample counts;
they are not materialized or measured transforms.

Forty fixtures through512 elements match the general native-algorithm port
and roundtrip. Forward and inverse outputs have32 direct-DFT comparisons
each through128 elements. Six RS rows use independent Horner evaluation.
Thirty-three hiding rows, n=1..32 and nn=4n, include q=0,n,n+1,2n+1 where
distinct;1,496 encoded values match an independent subgroup-Lagrange
interpolation plus (x^n-1)*pad(x) oracle. Synthetic pads are fixture values;
this never authorizes reusing real masks.

`tiled.py` independently ports `k_ntt_p1` bit-reversed load/zero padding and
`ntt_p2_body<true>` tile/j/t indexing. Three lengths4096/8192/16384 match
the general CPU algorithm, inverse recover all source coefficients and
48 selected evaluations match independent Horner. This is a serial index
model; CUDA synchronization/races, pruned openings, shared-memory swizzles,
PTX and native proofs remain untested.

Eighteen controls cover paper-root substitution, unsafe stage/twiddle
attestation, inverse scale/direction, output permutation, u64 truncation,
lost third limb, exponent sign, legacy q>n overlap, pad mutation, wrong coset,
general fallback, wrong stage/direction and malformed inputs. The legacy
overlap result is already known: current Sonnet code has separate subtraction
and addition gates. This cycle preserves that repair; it does not claim a
new production bug or fix.

One harness failure is retained under `stage-dispatch-control-failure/`.
After stage dispatch was added, the old wrong-root control mutated a supplied
twiddle the eligible candidate branch did not consume. The corrected control
tests the wrong-root general baseline and explicitly detects mismatched
stage/twiddle attestations. **Only the immutable native table constructor
may supply stage/direction provenance.** Arbitrary roots must use the general
path. Initial membership evidence and its byte-identical original sources
are retained; the before-tile report is an intermediate result.

## Removed work, added costs and ceiling

For a full radix2 transform N=2^L, L>=6, baseline source-level butterfly
`gl_mul` calls=NL/2. Eligible calls=7N/2-32; identities=N-1;
nonidentity shifts=5N/2-31. These are operation counts, **not time shares**.

| Transform | General butterfly calls | Eligible, incl identity | Fraction |
|---:|---:|---:|---:|
| 2^12 |24,576|14,304|58.2031%|
| 2^20 |10,485,760|3,669,984|34.9997%|
| 2^24 |201,326,592|58,720,224|29.1667%|

Known inverse scale adds N separately eligible products because1/N=2^-L.
Coset7^i multiplications, table generation/cache, butterflies' adds/subtracts,
all memory traffic, hashing, commitments, opening reconstruction, masks,
serialization, witness and verifier work remain. No memory/transfer saving
is assumed. Source-level identity calls may already optimize in compiled
code; PTX is needed to establish actual eliminated instructions.

Existing zero-padding skip materially shrinks the remaining opportunity:
at L20 with rb2/rb3, eligible fractions of **executed** stages are27.7774%/
23.5291%, not35%. Do not charge removed stages again. First6-only dispatch
changes30% of full L20 butterfly calls, less when early stages are skipped;
later sparse branches account for only another~5% and can diverge warps.

Added costs are public eligibility/index/exponent/sign logic, constant%192,
two/three-word shifts, existing canonical carry reduction, possible third-limb
subtraction/negation, direction/scale metadata and native validation. Registers,
occupancy and instruction/cache effects are unknown. Metadata uses scalars;
no per-private-value admission, dense exponent table or new mask state is
needed. An initial owner candidate should use first6 stages and known inverse
scale only, retaining general fallback and the same kernels.

The enclosing ceiling is Nproved/(Ttotal-Celigible_general+Cshift_dispatch+
Cmetadata_integration). The equivalent Amdahl expression needs a measured
affected **time** fraction and phase speed. No accepted private8B clocks
exist, so neither a numeric complete-stack ceiling nor a50-token/s path is
established. Any changed output/root/order/refusal/receipt rejects correctness;
no affected/enclosing benefit after accounting for dispatch rejects performance.

## Ranked queue

1. Owner GPU actual SZC and recurring witness: highest observed recurring
   scope; high CUDA/parallel/lifetime/native-mask integration cost. Preserve
   generic polynomial, all clauses and fresh transcripts. Reject if enclosing
   full-stack time fails to improve; quantify missing actual8B clocks first.
2. Exact fullK split-int16 FFN-down: moderate/high packing/transfer/workspace
   integration; exact i64/requant/range refusals mandatory. Isolated phase
   share unknown; no end-to-end estimate. Reject overflow/refusal mismatch or
   packing/transfer cost exceeding removed multiply cost.
3. Four-reduction Fp2: low/moderate field-wide compiler/device integration;
   wide carries/headroom/canonical output gates. Benefit bounded by actual
   Fp2 share, not reduction counts. Reject any differential failure or no
   enclosing gain; no change to field/soundness.
4. Symbolic Eq mixed grouped readers: moderate constructor/dependency/
   extension/parallel/census integration; saves prior counted payload/folds,
   adds generic basis reads/scalars. Preserve private extension targets and
   exact generic/final reads. Reject census cost or no native peak/time gain.
5. **REFINED this cycle:** first6 native shift twiddles plus inverse scale.
   Small CUDA seam, exact tested serial arithmetic, no protocol change;
   add dispatch/register cost. Full-stage version demoted until warp/phase
   evidence justifies sparse branches. No numeric full-stack ceiling.
6. Fresh fixed-context resident complete passes: moderate instrumentation/
   cache-lifetime scheduling; eliminates measured startup only, adds fresh
   masks/PCS/drain/verification. Memory/cache contention may worsen slope.
   >20ms recurring time per newly proved position rejects50/s for that
   schedule. Long prefill and authenticated decode are separate workloads.
7. Lookup/softmax, GKR and composition/PCS: highest protocol/integration cost;
   quantize exactness and state binding/joint hiding/soundness before any
   numerical claim. Prior slower fusion, compiler division, small-parent,
   LRU/prefix/reconstruction/privacy negatives remain preserved.

## Sources and next action

LIVE primary searches checked the newly assessed
[2022 Goldilocks note](https://www.ingonyama.com/oldblogs/goldilocks-ntt-trick),
[GPU-NTT paper](https://eprint.iacr.org/2023/1410) and its current repository,
a [September2026 NTT paper](https://arxiv.org/abs/2609.28904), and refreshed
CUDA release negatives. Exact dates, URLs, inspected licenses and failed
fetches are retained in source records. No author performance was reproduced.
The ML-KEM/CGLA paper's modulus3329, FPGA and cyclic driver differ from this
prime and device; it is a scope filter, not an alternative GPU speed claim.

Next LOCAL: add degree/denominator distribution census to the current native
SC_SZC lookup seam, including repeated public-table reciprocal setup versus
private occurrence reads; price plan construction and preserve zero-denominator
refusal. Rotation moves to lookup/softmax, then arithmetic/composition,
sumcheck/memory/batching and GPU commitments.
Next OWNER: inspect and compile the proposed helper under shared heavy/build
locks; public table provenance, native CPU/GPU arithmetic, q>n hiding rows,
frozen receipts, fresh independent verifier, corruption/refusal gates, then
first6/scale affected/enclosing/peak A/B. Main/Claude reviews and integrates.
No heavy job was submitted by this lane.

Accepted complete private8B proofs/passes/tokens **0**. Proof context null,
CPU only. Steady-state/total rates, startup seconds/fraction, witness/proof/
serialization/independent-verification/latency/lag/drain clocks unmeasured.
No long-prefill, resident-pass or decode proof ran. Larger workloads remain
allowed; quadratic attention, complete coverage and fresh masks/privacy stand.

Reproduce from the research directory:

```sh
python3 experiments/native-twiddle-shifts-20261013/experiment.py
```

`result.json`, `cost-accounting.json`, `run.log`, source/startup pins,
`commands.json` and `shift_twiddle.proposed.cuh` retain the review boundary.
