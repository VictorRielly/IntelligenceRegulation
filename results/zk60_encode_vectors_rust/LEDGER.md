# The encode conformance vectors, compiled and run in Rust — ledger

**Lane** `zk60-private-block-125m-review` (worktree
`/home/victor/wt-zk60-block125m-review`), opened from `81c519a`.
**Opened 2026-09-22 14:05 PDT.**

## What this lane is for

`docs/zkmatrix-poc/ZK60_ENCODE_CONFORMANCE_VECTORS.md` §4(c) says the Rust
test of the conformance vectors is owed: the vectors were produced by a THIRD
implementation of `encode_row_zk` that has never executed the Rust, and the
only cross-check that existed was against committed capture bundles at ONE
width (2^8 rate 8, `nn = 2048`) and only on the 256 opened columns of each
commitment. The production widths — 2^10 rate 4 (the rungs) and **2^14 rate 4
(rung-W14 and 125M)** — had no check of any kind.

This lane compiles the test the third-implementation agent wrote but could not
build, and runs it against the real `zkp-core::pcs::encode_row_zk`.

## Status

- [ ] test file dropped in and compiling
- [ ] the four tests run
- [ ] results recorded below

## Results

_pending_

## Findings

_pending_
