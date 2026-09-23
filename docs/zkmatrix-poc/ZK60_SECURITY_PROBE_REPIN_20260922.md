# Security probe source review at 4751b93 — 2026-09-22

The security probe's source check correctly refused the `zk.rs` change in
`4751b93`. The original run has one failure and one error from that same pin;
its other twelve tests passed, including the four historical capture checks.
See `results/zk60_security_probe_repin_20260922/before.log`.

The round-22 capture manifest remains unchanged, including producer commit
`1f0ff3680c4cda88f1744343e24eb93cdddfcba4` and source hash
`c5b54753d01d85f3469b8fbb873a36c7fcbc91faf15d16004f8cecff019c1310`.
The reviewed current hash is
`ce8cc51648d0da51b56bb08109059171aca95c50828b7245b6b3b19e227de70b`.
The probe records both identities and this review explicitly. It still
refuses any other current hash and refuses a changed producer pin; none of
the old captures is relabelled as produced by the new tree.

## Re-reading the changed code

Reviewed the complete `git diff 1f0ff36 4751b93 -- hashline/src/zk.rs`.
All pre-existing code before line 2277 is unchanged: masking commitments,
openings, functionals, masked rounds, extension rounds and their randomness
order. The private-IO entry, endpoint preparation, transcript and capture
writers are separate unchanged files. The existing v3 verifier body is
unchanged; the new public-endpoint probe is a separate entry/profile.

The changed private prover replaces W/A allocation with a bounded pool,
clears the non-tiled tail on every take, and retires a hiding commitment's
owned data only after its final opening. The prefix is exactly the existing
contiguous block/plane tiling and is fully overwritten by the unchanged
loops before committing. Partial table and predicate writes occur in the
cleared tail. P3's weight masks are appended after the weight-block prefix;
the source-plane folds read only the weight blocks and leave mask terms in
the terminal formula unchanged.

The fused weight fold uses the field identity
`sum_b lambda_b * sum_j eq_j * w_bj` for the old direct plane fold, while
reusing each inner block fold for its terminal. Its block indexing matches
the existing W layout. This changes no claimed value, challenge or refusal
condition. The `/2` preparation still absorbs fresh A and M roots before its
first challenge and uses its caller's OS-seeded stream. The added public
probe does not become a caller of the private-IO entry.

## Supporting execution evidence and limits

The previously completed integration checks include the full dirty-pool
shrink/grow test, P1/P3 private-IO checks under every pool/fold combination
on CPU and under the GPU feature, and frozen proof bytes through twelve
layers. Those logs are retained under
`results/zk60_host_private_20260920/`. This re-pin does not rerun those
unchanged Rust builds or alter them.

The security probe now distinguishes the archived producer from the reviewed
current source. New controls refuse unknown source drift and any attempt to
rewrite the historical producer pin as the current one. The scope remains
the probe's existing diagnostic arithmetic and schedule/refusal checks;
it does not establish whole-proof privacy or close the external-root game.
The D22 toy statement's separate review/pins remain Fable's responsibility.

Validation: all **17 security-probe tests pass** in 6.350 seconds, including
the three new source-identity controls (`after.log`, `after.done = 0`).
The original failure log is retained alongside the successful run.

The requested schema-3 toy capture is also retained in the same evidence
directory. It was reconstructed from the previously accepted `4751b93`
receipt with its pinned verifier binary on the CPU path, then independently
verified and reproduced as canonical JSON. This is capture regeneration,
not a new proof-generation benchmark. `capture-validation.json` pins all
132 source files, the binary and the three bundle files and records the
23-slot/alias checks. It does not extend the toy privacy statement to GPU
execution or to the larger profiles.
