# Exact pair-table inverse cache — cycle 0004

Run `20260926T195233Z-cef0b7d6`, 2026-09-26. **Exact synthetic arithmetic
candidate, with a small end-to-end ceiling on current CPU measurements.**
No native/GPU proof, verification, or complete-readiness timing was measured.
The target remains this run's complete private 8B attention-plus-FFN proof at
50 proved tokens/s: 512-token prefill in <=10.24 s including witness preparation,
per-proof preparation and serialization; five seconds is a stretch. This is
not a decode experiment. Newer project notes permit larger workloads, but
this cycle does not replace its explicitly assigned comparison contract.

## What was tested

The source seam is the shaped candidate at
`/tmp/zk60-groups-20260926/hashline/src/private_block/protocol.rs:908`.
It already caches the 256 U8 inverses. Exp and activation still batch-invert
every witness word. For a pair `(i,v)`, the helper is exactly
`1 / (alpha - (i + beta*v + gamma*tag))` over Goldilocks Fp2, `u²=7`.

The candidate builds a 256-entry inverse table once for each helper, storing
`None` at zero denominators without refusing. It uses the cache only when
the signed index is in bounds AND the value equals the public table entry.
Every other pair follows the old field arithmetic, including zero-denominator
refusal. Exp precedes activation. The later inversions of ALL entries in ALL
three public tables remain unchanged, including unused and padded rows.
Histograms still route invalid pairs to bucket zero; the optimization does
not repair a dishonest witness or add a new relation.

The reference transcribes the existing checked batch inversion. The independent
oracle expands both field coefficients directly and uses Python's Euclidean
modular inverse instead of the batch routine or candidate inverse. It checks
the multiplication equations. A separate tuple-indexed histogram and direct
coefficient oracle checks all modeled table-helper outputs, including padded
repeated public pairs with zero-padded multiplicities. Canonical 16-byte helper
words are compared. These are helper encodings, not native receipt bytes.

## Reproduce and results

From the research directory:

```sh
python3 experiments/pair-inverse-cache-20260926/experiment.py > experiments/pair-inverse-cache-20260926/run.log 2>&1
python3 experiments/pair-inverse-cache-20260926/validate.py > experiments/pair-inverse-cache-20260926/validation.log 2>&1
```

The experiment sets one-CPU affinity, a 55-second CPU limit, 59-second wall
alarm, and 512 MiB address-space limit; estimated memory is 64 MiB. No packages,
native builds, downloaded code, GPU jobs or Git commands are used.

Seed **2026092604**; Intel Core Ultra 9 185H / WSL2 / Python 3.10.12.
**76 differential cases, 21,015 directly solved helper words, 41 schedule
cases, and 11 negative controls pass.** Table lengths 1/4/16/256; columns
0/1/31/257 and one 16,384-word case; full-extension challenges, beta=0,
compression collisions, used/unused zeros, negative/out-of-range/i64-extreme
indices, altered values and arbitrary invalid witnesses. Schedule cases use
four-entry synthetic tables, public table lengths 4/16, and the source's
U8→exp→act helper/table order. This models stage identity, not actual native
draws, absorbs, allocations or first failing word within a batch.

Final script: **0.2075 s, 26,292 KiB RSS**. This is experiment overhead, not
proving speed. The initial narrower successful check is retained in `initial/`;
the final version adds an independent table-helper oracle and two padding/
multiplicity controls. No initial failure is hidden. A second successful pre-tag-pin snapshot is
retained in `before_native_tag_pin/`; final schedule tests pin native
U8/EXP/ACT tags 133/129/134 directly from `tables_attn.rs`.

At 16,384 valid words and a 256-entry table, counted batch multiplications
fall **49,152 → 768**, with one field inversion in both paths. Input scans,
comparisons, helper output, H writing/commitment and all later table inversions
remain. `work-counts.json` labels production-shape arithmetic separately from
the executed small case. The eliminated prefix has 16*N payload bytes; Rust
cache layout and actual traffic have not been measured.

Two negative performance findings: a 31-word valid column with a 256-entry
cache uses 768 batch multiplies versus 93; 257 invalid words require 258
candidate inversions versus one reference inversion. No universal speedup.

## End-to-end relevance and handoff boundary

`bottleneck.json` pins earlier R1d logs and the latest R2a logs separately.
The latest non-warm candidate helper phase is **0.217–0.232 s**, 0.54–0.58% of
39.733/40.095 s proving. Witness preparation is 8.35/7.26 s, serialization
0.024/0.027 s, verification internal clocks 0.964/0.976 s (from-bytes totals
0.98/0.99 s in the retained logs). The known witness+prove+serialization sums
are 48.107/47.382 s, not enclosing request-wall measurements. Removing the
ENTIRE helper phase would save less than 0.5% of those sums; this candidate
retains work and will save less, if any. Shared two-thread CPU data, compilation
overlap; no 8B/GPU extrapolation. Grouped A/B remains waiting for the heavy lock.

`pair-helper-cache.proposed.patch` inserts two Rust helpers and replaces only
the exp/activation inverse preparation in the inspected candidate. It is
**unapplied, uncompiled and untested in Rust**. Source pins, excerpts, patch
hashes and in-memory application validation are retained. Main/Claude owns
review, native masked/RNG/receipt parity, malformed-witness/refusal gates and
any eventual measurement under shared locks. D22/D19b/D23 status is unchanged.

Native LIVE search and access issues are in `search-log.json` and five dated
source records. No paper/release speed was reproduced. Next local rotation:
fuse sumcheck fold and next-round accumulation while preserving the existing
`SumcheckRounds::fold/round` contract; first count saved reads and the scratch
required for the MSB-order pairing. Do not duplicate the queued grouped A/B.
