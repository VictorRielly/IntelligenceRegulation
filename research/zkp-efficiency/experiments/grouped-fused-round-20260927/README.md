# Grouped fold / next-round fusion — cycle 0009

Run `20260927T005233Z-ccb9384b`, 2026-09-27. **Exact synthetic algebra and
logical traffic reduction pass. No native, GPU or complete-proof speed result.**

From the research directory:

```sh
python3 experiments/grouped-fused-round-20260927/experiment.py > experiments/grouped-fused-round-20260927/run.log 2>&1
python3 experiments/grouped-fused-round-20260927/validate.py > experiments/grouped-fused-round-20260927/validation.log 2>&1
```

Standard library only, seed **2026092709**, one CPU affinity, nice +10, enforced
59 s wall / 55 s CPU / 512 MiB address-space limits. Estimated experiment memory
40 MiB. Final run: **9.2027 s**, **24,192 KiB RSS**, Intel Core Ultra 9 185H,
WSL2, Python 3.10.12. Exact values, platform, source hash and all cases are in
`result.json`. Proving, verification and complete readiness are **null**.
No build, GPU job, dependency installation or downloaded-code execution.

## Hypothesis and source seam

The current native candidate, `/tmp/zk60-groups-20260926`, selects
`GroupedEqRounds` in `hashline/src/private_block/argument.rs:553` for SC_SZC.
Its descriptors at lines 1784–1786 have three equality points, all starting at
coordinate zero, with bracket degrees `[3,1,1]` or `[4,2,2]`. Its round loop
already shares loaded values across groups. That is the proper baseline.

After current challenge r, form the two endpoints of the next round directly
from old quarters `(0,2)` and `(1,3)`. Store the folded values, then evaluate
the grouped brackets while the values are live. Update each actual group claim
and equality prefix BEFORE building next-round suffix metadata. Keep requested
`pending` and precomputed `ready` polynomials distinct. The last length-two
fold only produces finals. No extra challenge or transcript message is needed.

All three equality tables are retained and folded in their original positions,
just as in the native candidate. The earlier group's research oracle omitted
these physical tables and returned their analytic finals; this experiment adds
them explicitly to the candidate and independent shared-load baseline.
The 26 synthetic tables are **not** an asserted native 125M table inventory.

## Validation and independence

- **37 cases**, row lengths 1/2/4/8/16/32/256, padded/unpadded, base/zero/full
  extension tables, different equality points, short Ht support, ragged tiles
  1/3/7 and reversed tile traversal. Arbitrary inconsistent witnesses included.
- **651 round samples** and **1,953 group samples** match the pinned unfused
  grouped oracle, the current-loop transcription and the fused implementation.
- Every one of the **651 total round samples** also matches an independent
  direct original-cube MLE evaluation plus separately expanded scalar formula.
  The direct oracle skips terms annihilated by the Boolean suffix; it performs
  no folding. **222** small-case points additionally use the old exhaustive
  cube oracle. Independent polynomial-convolution field multiplication is used
  for original-table MLE weights and values. The scalar formula shares Fp2
  arithmetic with the earlier source-derived oracle.
- **962 final MLEs** checked independently, with intermediate table equality,
  group claims/prefixes and bracket counts checked after every round.
- **Six zero-factor fallback group-rounds**: factor-at-one zero and accumulated
  zero prefixes compute explicitly without discarding/resampling challenges.
- **37 synthetic masked-driver comparisons**, **10 negative controls**,
  **12 schedule refusals**, **three malformed fixture refusals**. Controls catch
  stale prefix, wrong suffix, combined host claim, wrong quarters, omitted
  ragged tails, changed limb/challenge/mask, swapped equality finals, and a
  forbidden round after the final fold. These refusals belong to the harness.

The independent references are pinned copies of prior LOCAL research scripts,
`oracle_groups.py` and `oracle_fusion.py`; their main functions are not called.
They are not external downloaded implementations. `source-pins.json` records
their origins and five native read-only source snapshots.

## Traffic and negative result

For initial length N>=2 and k tables, the serial shared-load baseline counts
`(4N-4)k` reads; fused counts `(3N-2)k`. Both write `(N-1)k` elements. These
exclude setup, final reads, masks, scratch/cache/write-allocation, allocators
and driver work. Fp2 elements occupy 16 bytes in the native representation.

At N=256, k=26:

| Count | Separate passes | Fused passes |
|---|---:|---:|
| Table reads | 26,520 | 19,916 |
| Table writes | 6,630 | 6,630 |
| Logical table bytes | 530,400 | 424,736 |
| Padded bracket calls, group 0/1/2 | 1,148 / 638 / 638 | 1,148 / 638 / 638 |
| Unpadded bracket calls, group 0/1/2 | 893 / 383 / 383 | 893 / 383 / 383 |

The byte reduction is **19.9216%**, approaching 20% at larger N. The two-row
case saves nothing. Metadata builds, suffix table construction and weight
products also match. This is neither DRAM traffic nor a timing ratio.

**Preserved negative:** the first passing prototype reduced a separate sum per
tile even on the serial path. It added 11 field additions at the four-row
padded shape, 506 at the 256-row padded tile-three shape, with unchanged useful
bracket work. That unconditional path is rejected. `initial/` preserves its
source/result/log. The final serial implementation uses one accumulator; a
retained `partials=True` negative arm reproduces the extra cost and agrees
algebraically. Native parallel partial reductions still require separate
counting, ownership and timing; this test does not justify serializing them.

`grouped_fused.proposed.rs` is an **uncompiled, unapplied SERIAL helper sketch**.
It preserves the native debug recovery assertion by computing sample one in
debug mode. It is not a full native patch or a substitute for Rayon. Native
large-table ownership/tiling and all protocol integration remain owner work.

## End-to-end context and limits

`bottleneck.json` rechecks four owner logs and the completed grouped A/B marker.
New proving 34.861/33.315 s, witness 5.43/5.76 s, serialization .031/.020 s:
known readiness **40.322/39.095 s**. Internal verification .900/.810 s,
from bytes .91/.82 s, separate. Shared two-thread CPU, synthetic dense 125M
block, extra small-slot oracles; not an enclosing request, GPU, 8B or our run.

The complete softmax slot is 8.601/7.832 s, about 21.3%/20.0% of known
readiness. Deleting the entire slot is only an accounting ceiling. Its fold,
cache-miss and arithmetic shares are unmeasured; do not multiply this ceiling
by the logical traffic reduction to predict a gain. A+H encode/Merkle remains
16.739/16.903 s and is unaffected by this experiment.

Native closure/IR wiring, CFS masking, RNG draws, extension rounds, invalid
witness behavior, fresh/archived receipt verification, production parallel
cutoffs and actual device execution are **untested**. No privacy/soundness
acceptance changes. Prefill does not establish autoregressive decode speed.
The complete private 8B >=50 proved-token/s target remains unachieved.

See the [handoff](../../handoffs/20260927-grouped-fused-round.md),
`source-records.json` and `search-log.json`. No production source was modified.
