# Public loader decode-temporary statement scopes

Cycle0090, run `20261019T221854Z-a20c7a9f`. No speed improvement measured.

Review-only candidate: [patch](../experiments/decode-statement-scopes-20261019/review-only-statement-scopes.patch).
The production loader diff is **UNBUILT/UNAPPLIED**. Only a small authored,
dependency-free language-rule probe was compiled; no production build or merge.

Interface: retain `TrainedExport::load_layer_mode` and `pad_matrix` signatures.
In frozen R8 `hashline/src/private_block/trained_block.rs` (~1037), give each
of the nine pad calls its own `let` statement owning the returned padded Vec,
then move those results into the same aw/fw arrays. Calls and their order are
unchanged. Do not bind references to the decoded temporaries: the probe's
negative shows that this extends lifetimes. Actual baseline tree:
`ops/zkp-mvp/trained-1b-review-r8/`; source SHA256
`cc401eb4be9d8e8a723894bac837442e01fe96bc67df22461e42582ecd3feec8`.
Candidate SHA256 `b75862ad51823466c7e088c73b817cc261e158daef6d4a093aae9fafe160ca69`.

Validation: authored Rust1.90/edition2021 Drop probe tracked decode peak
1216->400B, same outputs; reference-binding negative1872B. Its wrapper makes
Drop observable and does not establish original Vec allocation behavior.
Python48 synthetic byte fixtures,78 prior-path comparisons and480 new
premature-release/injected-error controls pass. Independent audit2411 checks,
432 corruptions,432 first-error expectations. No native malformed loader,
record wire,CS/H-1,receipt or proof checks ran. All surrounding Rust source
outside the aw/fw initializer region is byte-identical in the proposed diff.

Allocation-free public model,8B T128: padding envelope638116864->520672256B,
112.003906MiB lower. **Standalone loader full/reload peak saving0B.** With
prior checked public constructor moves plus postconstructor raw release,
16 hash workers and current+next+four distinct pinned public blocks,
1.727765560->1.618386745GiB. Those are composed,unintegrated proposals,
not measured RSS/VRAM,full-model fit or elapsed gain. Private/device state,
allocator slack,page cache and extra evicted live leases are excluded.
Same218112000 decoded bytes,nine allocations and all proof work remain.

Owner gate: review the diff,then use shared build/heavy locks for native
full/reload byte/record/malformed/paired-first-refusal/receipt/CS/H-1 checks
and exclusive requested-allocation/HWM/enclosing clocks,alone and composed.
Falsify on original Vec overlap already eliminated,any changed byte/refusal/
receipt,live read beyond lifetime,other phases removing capacity benefit,
or moved frees regressing enclosing time. Preserve freshness and reload
digest checks. No private/P3 cache or mask/opening reuse is authorized.
D33's R7 TinyLlama T32 acceptance does not cover R8/8B/GPU/new-file changes.

Next local: original Vec/System-allocator probe with preallocated logs and
independent event formulas,under the same CPU-light limits. Whole-prover GPU
and independently verified fixed-context resident1/2/4/8 remain the throughput
priority; no new full-stack proof or credited token was produced here.

[Evidence and exact commands](../experiments/decode-statement-scopes-20261019/README.md).
