# Pair inverse cache — low-priority exactness candidate for main/Claude

Run `20260926T195233Z-cef0b7d6`; research only. **A tested arithmetic idea,
not a tested Rust patch or measured proof improvement.** Production, runtime,
instructions, reviewer files and Git metadata were not modified.

Expected impact is small on current data: latest R2a candidate spends
0.217–0.232 s here, 0.54–0.58% of proving and 0.46–0.48% of accounted
witness+prove+serialization. The comparison is a synthetic dense 125M CPU
block, not the complete private 8B/512-token <=10.24-second target. Native
implementation should not displace the more expensive softmax/commitment work.

## Interface and patch location

Candidate source base:
`/tmp/zk60-groups-20260926/hashline/src/private_block/protocol.rs`, original
exp/activation preparation at lines 908–911. The main production file is an
older toy implementation; this patch is for the **inspected shaped candidate**.
Full source SHA-256 is in
`../experiments/pair-inverse-cache-20260926/patch-provenance.json`.

Unapplied patch:
[pair-helper-cache.proposed.patch](../experiments/pair-inverse-cache-20260926/pair-helper-cache.proposed.patch).
Self-contained proposed functions:
[pair_helpers.proposed.rs](../experiments/pair-inverse-cache-20260926/pair_helpers.proposed.rs).

```rust
fn pair_denominator_inverses(
    table: &[i64], alpha: Fp2, beta: Fp2, tag: Fp2,
) -> Vec<Option<Fp2>>;
fn helper_inverses_pairs(
    indices: &[i64], values: &[i64], table: &[i64],
    alpha: Fp2, beta: Fp2, tag: Fp2,
) -> Result<Vec<Fp2>, String>;
```

The original caller has already validated witness shape. Preserve its zip
behavior. Exp uses `public.exp`; activation widens the existing public
`ff.act` values into 256 i64 entries. Each cache is local to one helper call,
table, tag and challenge triple. No proof-to-proof cache or new challenges.
Keep all three later `inverses` calls and their order exactly as written.
Do not infer that `0 * inverse(0)` may be skipped.

## Validation and limitations

[Experiment/result](../experiments/pair-inverse-cache-20260926/README.md):
76 differential cases, 21,015 independently solved words, 41 phase/refusal
models, 11 negative controls; 0.2075 s and 26,292 KiB RSS on one CPU.
The independent coefficient oracle checks inverse values, table multiplicities
and padding. Canonical helper bytes agree. No native transcript, masks, RNG,
commitments, receipt framing or verifier was executed.

The negative controls establish why an exact-pair test is required: index-only
caching changes invalid witnesses. Beta=0/collisions must be handled without
new assumptions. Eager refusal on an unused public zero changes the stage;
removing whole-table inversions or skipping zero multiplicities changes
acceptance. Invalid/out-of-range pairs must evaluate their original denominator.
The scalar fallback is deliberately simple and can be MUCH slower on dense
invalid witnesses; small valid columns can also lose to cache setup.

Owner's gates before integration, under build/heavy locks as needed:

1. Compile and run differential Rust tests against the unchanged `inverses`
   path, including all malformed and zero/collision cases from the Python
   experiment. Use real public exp/act construction at toy and shaped profiles.
2. Match original helper planes, histogram/table helpers, refusal string/stage,
   RNG consumption and all transcript draws/absorbs, including failed attempts.
3. Same-seed full receipt byte identity, accepted/bad witness behavior,
   archived/fresh cross-verification and existing privacy-source review.
4. Measure helper phase and complete witness/preparation/prove/serialization
   readiness separately from verification. No native/device job was queued here.

The field-operation saving does not reduce H rows, proof bytes, query count
or the privacy/soundness obligations. D22 remains the accepted CPU toy only.
