# Per-proof split-Eq suffix cache — owner review only

Run `20261012T222555Z-e2cb7a5e`, cycle0041. Synthetic parity passes; **small-count candidate,
no native gain**. [Experiment](../experiments/split-eq-suffix-cache-20261012/README.md)
and [result](../experiments/split-eq-suffix-cache-20261012/result.json).

Interface: `SplitEqSuffixCache::new(point,start,n_vars)` owns two suffix-level
hierarchies for one immutable public proof point. `view(j)` borrows left/right
slices and returns suffix_len/trailing for unchanged pos quotient/remainder.
`after_fold(j)` frees obsolete levels once all row/reduction borrows have ended.
One cache per EqualityGroup, constructed afresh for each proof; no private
witness/mask/opening/transcript/RNG state is cached. Original dense equality
planes, prefix scales,actual group claims,zero-factor fallback,all sample
values/degrees and final-opening positions remain.

Patch seam: candidate `zkp-core/src/sumcheck/grouped.rs` fields/new/round/fold;
`RoundGroup` left/right become borrowed slices. `mle.rs:48` is the rebuilt
reference; `hashline/src/private_block/argument.rs:1783` declares three groups.
Pinned grouped.rs SHA7777a19c8db97694c51e66c78d1a7688573158bddaa7fcb370345ebd14ab669b.
[Python cache](../experiments/split-eq-suffix-cache-20261012/suffix_cache.py) and
[adapter](../experiments/split-eq-suffix-cache-20261012/cached_grouped.py) are
tested. [Rust sketch](../experiments/split-eq-suffix-cache-20261012/suffix_cache.rs)
is uncompiled/unapplied; no production patch or merge. Serial implementation
is illustrative, not a production parallel-scheduling decision.

Final one-thread check 9.878354s/22480KiB RSS,
seed2026101241,Core Ultra9. 184 suffix fixtures/12,036 direct weights,32 SZC
fixtures/64 schedules,2,520 independent subgroup samples,112 offset samples,
318 recoveries,258 explicit zero-factor fallbacks,1,792 finals,5,376 extension
table checks,192 preserved bracket counts and16 controls. Source hashes,
exact commands,logs,dimensions and prior passes retained.

Conditional h_pad16/T512 Eq lengths22/13/22: preparation41,598 ->12,532
multiplications,versus12,582,909 unchanged weight multiplications before
brackets. Only0.2302% of preparation+weight count is removed. Logical peak
100,352 ->200,608B (extra100,256B),metadata/allocator/point copies excluded.
Fixed right half changes locality;two-pass sketch reads tail twice. Native
prep/read/free share and end-to-end value are unknown. No accepted8B numeric
ceiling; only `N/(T-Cprep+Cnew)` is supported.

Owner gate: **measure preparation/read/free/enclosing/peak share before
prioritizing this port**. If warranted, guarded native build and immutable
point/short/offset/zero/schedule/degree/refusal tests; generic masked bytes,
RNG/challenges/finals/extensions,frozen receipt and fresh independent verifier
checks; full privacy/soundness review and complete A/B with all clocks.
Any mismatch or no net enclosing gain rejects. Preserve existing native
parallel thresholds;don't change ordinary mixed-factor messages or private
masks. All private-block acceptance limits remain. No heavy job queued.

Next useful local direction is structural Ht host trailing-j repetition,
with actual row-lift provenance and sabotage controls; other groups and
future-score constraints must remain complete. This is a question,not a
claim of accepted optimization. Checkpoint 2026-10-12T22:36:34.177104+00:00.
