# Audit snapshot and scope

## Git boundary

- Branch: `perf/zk-batch-optimizations`
- HEAD: `9fea0a5620679aa484dce3edaff9deae65b0def8`
- HEAD subject: `Merge the M4 activation tranche: piecewise SiLU designed, priced — and the verdict is the lookup track`
- HEAD timestamp: `2026-07-09T15:47:12-07:00`

## Dirty worktree boundary

Two pre-existing modified files belonged to Fable/the user and were preserved:

- `zkmatrix-rs/src/bin/ring_matmul.rs`
- `zkmatrix-rs/src/ring/ct_engine.rs`

The changes implement an in-progress R1 garbage-image masking tranche. The
files changed while this audit was running, including small cleanup after the
main tests. Important observed hashes were:

```text
ring_matmul.rs  78f95a956bf5bbf88d42e8958d63d5a229d9fe3a6e69eb971d62c926a5889d1a
ring_matmul.rs  e95182df5365dbf74d57ddc3c4030fddd9bc4aa95a6f3c32e53d16edf3be6c81  (later cleanup snapshot)
ring_matmul.rs  e277dbc295334518fff3c6108d9daf2cec6228ee6330be67ae06746888f319e5  (R1 battery/final direct-test snapshot)
ct_engine.rs    dbd3ff6b836dd2753c0ec0c2f096137a6adebe83177dd17bebed0f2c00d0487d
```

The first 42-test run was performed against the initial R1 snapshot and exposed
two C2 failures. Fable repaired those live; a subsequent 42-test run passed in
134.382s. Fable then added the explicit R1 leak/order battery; the final listed
snapshot passed the complete Route R self-test directly in 31.86s and the chain
demo in 0.46s prove / 0.07s verify. Concurrent edits are why results in this
audit are timestamped rather than described as a released revision.

## Review scope

Reviewed:

- root project/documentation and history;
- Python zkMatrix and lattice references;
- C and Rust native backends;
- Route R ring, commitment, Sigma, ct-engine, links, manifest, Pi1/Pi2 demos;
- M0-M4 reports, transformer plan, soundness/Q4 documents, estimator and cost
  notes;
- tests, parameter scripts, algebra harness, activation harness;
- build/test behavior and current worktree diff;
- external primary papers needed to calibrate paper/benchmark claims.

Not performed:

- a formal proof or full line-by-line cryptographic audit;
- side-channel measurement;
- native Sage estimator rerun;
- GPU measurement (no proof GPU backend exists);
- multi-machine benchmarks;
- PDF theorem-by-theorem verification;
- destructive changes, commits, or edits to Fable's working files.

## Independence caveat

This is an engineering and cryptographic-risk review, not a certification. New
protocols require review by specialists with enough time to reproduce the full
proof, reductions, parameter generation, and implementation behavior.
