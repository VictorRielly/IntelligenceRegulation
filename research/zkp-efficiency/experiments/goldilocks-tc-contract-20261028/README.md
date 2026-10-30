# Goldilocks Tensor Core NTT contract screen — cycle 0130

Run `20261028T235649Z-d1bc0725`; 2026-10-28/29 UTC. **No native proving
improvement measured.** The stock supplied Tensor Core NTT driver is not a
Goldilocks backend. A locally authored carry/scaling adapter contract passes;
its CUDA sketch is uncompiled and unapplied.

The question was whether the general Montgomery helper in the new source
rescued the earlier 62-bit compatibility rejection. It does not rescue the
supplied driver: its `ConstantPrecomputation` still chooses the friendly
reducer, which rejects Goldilocks. Its test has `modulus_bits=64` but a 61-bit
modulus. The separately general multiplier passes arithmetic checks; that
does not establish an arbitrary-64-bit Tensor Core transform or justify
bypassing either guard. These unsupported-port controls are not upstream bugs.

## Evidence and resource limits

`result.json`: **39,179 checks** with seed `202610280130`:

- 12,441 general fixed-multiplier pairs, including full-u64 and canonical
  edge values; 9,309 borrow and 3,132 non-borrow cases. Canonical results and
  low-word cancellation checked independently against bigint arithmetic.
- 18 canonical radix-2 fixtures at n=2/4/8/16/32/64: forward, inverse,
  roundtrip and nonunit coset checks against direct original-input DFTs.
  This is our CPU radix-2 model, not the external Tensor Core implementation.
- 35 byte-dot16 fixtures with explicit overlapping-word carry propagation;
  four scaled/bit-reversed matrix16 fixtures, 64 coordinates checked against
  independent direct DFT. Source scale and output permutation are explicit.
- 54 negative-control instances: lost borrow, wrong Montgomery sign,
  unsupported lazy `2N`, missing intermediate/top carries, wrong roots,
  output order and matrix scaling. Five public guard cases also checked.

Final checker: **0.093988 s**, **15,608 KiB peak RSS**, one pinned nice-19
Intel Core Ultra 9 185H CPU worker. 64 MiB estimated memory; 256 MiB address
space, 40-second CPU and 45-second alarm caps. No threads, GPU, native build,
installation, fetched-code execution or dependency change. Four adaptive
versions ran for new controls; all prior code/results are retained. Their
shorter clocks do not form a performance comparison.

`audit-result.json`: **774 checks**, 0.006968 s, 16,648 KiB. Seven current
native source pins match. Source strings/hashes/counts only; not native tests.
`commands.json`, `native-pins.json`, `startup/read-index.json` and code hashes
in each result retain commands, dimensions, hardware and provenance.

Reproduce only the authored current model:

```text
python3 -I -B /home/victor/IntelligenceRegulation/research/zkp-efficiency/experiments/goldilocks-tc-contract-20261028/run.py
python3 -I -B /home/victor/IntelligenceRegulation/research/zkp-efficiency/experiments/goldilocks-tc-contract-20261028/audit.py
```

## Useful negative and conditional reducer contract

Canonical `P-1` dot16 inputs need **132 bits**, including top carry 15.
Truncating to u128 fails. Replacing the friendly multiplier with the general
one also fails in the source's unsupported lazy butterfly: even inputs
`a=b=0,k=1` produce a nonzero second coordinate after wrapping `2P`.
The source guard prevents that unsupported use.

Eight byte-diagonal accumulators combine into overlapping 16-bit t words.
For dot16, the largest combined word is bounded by
`(7+256*8)*16*255^2 = 2,138,022,000 < 2^31`; the same formula at dot32
exceeds signed32. This is a bound for this decomposition, not a claim that
the source implements a failing radix32 kernel. Source MMA/WMMA execution,
lane packing, transposes, saturation and compiler behavior were not tested.

The authored adapter packs eight t words with explicit u32 carries into
`lo,hi,top`, with `top<=15`. Goldilocks identities give:

```text
2^128 = -2^32 (mod P)
raw = gl_sub(gl_reduce(lo,hi), top << 32)
2^-128 = 2^32 - 1 (mod P)
scaled_result = gl_mul(raw, EPS_GL)
```

The subtraction replaces one generic top-carry product in our research
model. **No existing native instruction or elapsed work has been removed.**
The external matrix stores a `2^128` factor and bit-reversed row exponents;
the model explicitly removes that factor and maps rows to natural outputs.
`candidate-reducer.cuh.txt` is a locally authored, uncompiled interface
sketch requiring the native canonical helpers and a publicly bound modulus.
It is not a complete NTT or a production patch.

## Cost, ceiling and falsification

Baseline: native specialized Goldilocks `gl_mul`, canonical radix-2 batched
row NTT with natural outputs, inverse normalization, coset and hiding pads.
The general fixed helper uses two high and one low 64-bit products, two
precomputed u64 words per twiddle versus native one high/one low and one
twiddle word. Extra precomputation and loads can erase any arithmetic gain.
No general-helper substitution is recommended.

A future Tensor adapter adds digit packing, 64 MMA calls per 16x16 matrix
at eight digits, carry propagation, reduction, output mapping, transpose,
twiddle/preprocessing and register/shared-memory/scratch costs. Full inverse,
coset, q>n, ragged, chunked, keyed hashing, pad and opening semantics remain.
Native elapsed, compiler, memory and whole-proof incidence are unknown.

If f is the unknown exclusive affected NTT critical-path fraction, even
deleting the entire phase for free gives at most `1/(1-f)`, before these
costs. This candidate deletes only potential scalar kernel work. No numerical
8B or GPU throughput forecast follows. Reject on any carry, canonical value,
root, order, inverse, coset, pad, refusal, RNG, transcript, PCS, receipt or
privacy mismatch, or complete verified-workload/capacity regression.

## Sources, integration and next action

Nine source records in `sources-cycle.json`; 849 ledger records after append.
Two LIVE search batches plus 14 retained follow-up batches. Primary immutable
source at `6f407daa8a4cef96331511ae86b922b520d7aa33`: modular and NTT headers
and selected supplied-driver sections. Both complete numbered header
renderings are retained in `web-source-lines.json` (406/339 lines).
Their hashes identify rendered text, **not raw Git blob bytes**. Apache-2.0
SPDX inspected. Immutable arithmetic helper/cache misses and inaccessible DOI
are explicit; current main helper body is unpinned. No entire-tree audit.

New older Bos/Montgomery 2017 reference adds operand-bound/precomputation
context; its PDF403 and Cambridge Cache miss limit reading. Current ICICLE,
GPU-NTT and Plonky3 release pages, known 2026 sumcheck and older Goldilocks
root tricks were refreshed. Release day/month without a rendered year is
not promoted to a verified 2026 date. No author performance was reproduced.

All 44 previous hypotheses retained; 1 and 44 refined, 45/46 added. The top
three remain whole-prover GPU with verified resident workloads; DD/fidelity
context scaling; exclusive complete phase/capacity clocks. This was the
next bounded local arithmetic screen, not a replacement for owner work.

Future integration seam: a distinct Goldilocks `reduction_type` for the
external matrix and native `kernels.cu::k_ntt_p1/p2` through
`cuda.rs::encode_rows_view_zk[_gather]`. Owner first measures actual exclusive
NTT/enclosing costs, then reviews an adapter and runs native/device golden,
masked transcript, next-RNG, refusal, PCS/privacy and independent full-receipt
gates under current shared locks. No heavy job queued here.

Next local question follows a new measured owner cost: R12b reauthenticates
the public 7.7 GB Shieldstral checkpoint (owner note 17–18 s/load) and
rederives tied tables on each call. Inspect previous loader/cache findings,
then test a fully parameter-bound immutable derived-public object against
mutable-file/path/metadata-cache controls using synthetic public bytes only.
This is a 3B classifier seam; its costs do not transfer to 8B. P3 weights,
private masks and openings cannot become cached preprocessing by assumption.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context and accelerator: none. Witness/proof/serialization/
verification, startup/prefill, startup fraction, latency/bytes, steady-state
and total-workload rates: unmeasured. No long prefill, resident proof series
or decode. Larger workloads remain allowed; attention can grow quadratically.
Private 8B at >=50 proved tokens/s remains unachieved.
