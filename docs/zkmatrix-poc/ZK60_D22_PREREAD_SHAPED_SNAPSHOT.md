# The D22 condition-7 PRE-READ of the integrator's shaped snapshot

**Status: OPEN (skeleton).** Opened 2026-09-23 01:13 PDT on
`perf/zk-batch-optimizations` (main tree). Written by one delegated Opus
reviewer for the security owner. Python and `git show` only — no Rust build.

**What this is.** The integrator (Codex) assembled the block lane at
`fee1a8d` onto main `4751b93` plus two additive hash-tag patches as a FIXED,
uncommitted source snapshot:
`results/zk60_shaped_integration_20260922/reviewed-source.tar.gz`
(SHA-256 `c794360a…`), with `review-snapshot.json` (179 per-file hashes).
Condition 7 of the toy profile's accepted privacy statement (register D22):
*a change to any pinned file suspends step 3 until re-read and re-pinned.*
This page is the reading, against exactly that archive.

**What this is NOT.** Not the re-pin (only the security owner moves a pin of
D22; no pin table or gate was edited). Not a privacy acceptance. Not a
review of the snapshot's non-toy code except where it touches the toy path.

## 0. Status

| # | item | state |
|---|---|---|
| W0 | skeleton | this commit |
| W1 | archive verified, every file hash against `review-snapshot.json` | pending |
| W2 | the 37-file pin set, snapshot digest vs pin(s) of record | pending |
| W3 | every moved pin: diff vs `4751b93`, hunk by hunk | pending |
| W4 | the two Cargo manifests: can the observers reach a release build? | pending |
| W5 | conclusion for condition 7 | pending |
