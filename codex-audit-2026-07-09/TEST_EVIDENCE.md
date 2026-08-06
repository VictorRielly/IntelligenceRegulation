# Reproduction and test evidence

## Environment

- Date: 2026-07-09, America/Los_Angeles
- Base commit: `9fea0a5620679aa484dce3edaff9deae65b0def8`
- Branch: `perf/zk-batch-optimizations`
- Rust toolchain used directly: Cargo/Rustc 1.96.0
- System `cargo` resolved through a sandboxed Snap wrapper and was unusable;
  the direct rustup toolchain path was used.

The two Route R files were being edited concurrently. See
[`SNAPSHOT.md`](SNAPSHOT.md) for hashes and scope.

## Commands and results

### Rust release build

```bash
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc /home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/cargo build --release --bins
```

Result: **pass**, with warnings. The initial build reported
`ct_round_challenge` unused; after Fable added the R1 regression battery it was
used and that warning disappeared. The final direct build still reported 13
ordinary unused/dead-code warnings.

### Rust cargo tests

```bash
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc /home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/cargo test --release --all-targets
```

Result: **pass as a compilation check**, but every target reports zero tests.
Behavioral coverage lives in binary self-tests called by Python.

### Full repository suite

```bash
PATH=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc python3 -m unittest discover -s tests -v
```

Initial R1 snapshot result: **42 run; 40 passed; 2 errors; 104.436s**.

Both errors were process aborts:

```text
test_ring_matmul_self_test ... SIGABRT
test_ring_chain_demo       ... SIGABRT
src/bin/../ring/ct_engine.rs:299:5:
C2 (ct round): q too small for the std bundle
```

The self-test aborted in the F5 “new randomized claim” setup. The chain demo
aborted while deriving the R1-expanded gadget wave.

After Fable repaired both capacity problems during the review, the same command
reported **42/42 passed in 134.382s**. Fable then added a further R1 regression
battery; the final source snapshot was rebuilt and checked directly below.

### Freeze check

```bash
zkmatrix-rs/target/release/ring_matmul freeze-check
```

Initial result: **pass despite both integration aborts**. Fable subsequently
added a freeze row pinning the R1 per-family pad-count formula. A remaining
coverage recommendation is to freeze total representative wave counts and
C2/C3/C4 headroom, not just the pad formula.

### Python syntax check

```bash
python3 -m compileall -q .
```

Result: **pass** for project Python sources examined by compileall.

### Algebra/leak harness

```bash
python3 scripts/zk_lemma_check.py
```

Result: **pass**. It confirms the old leak identities, full C recovery in the
checked toy gate, R1 equation completeness, and ARP numeric checks. It does not
constitute a full ZK or soundness proof.

### M4 activation harness

```bash
python3 scripts/silu_piecewise.py
```

Result: **pass**. The recommended int8 table digest matches the document and all
256 input-grid relations enumerate successfully. The same output reports the
modeled +201% pass commitment bill and 15-18s marginal GPU time.

### Route R parameter script

```bash
python3 scripts/route_r_params.py
```

Result: **pass**. Frozen tables and helper-prime paths were reproduced.

## Final live-worktree validation

I first validated candidate repairs in an isolated `/tmp` copy. Fable then
implemented its own live fixes, added the missing R1 battery and freeze row, and
the obsolete diagnostic patch was withdrawn. Fable's files were not edited by
this audit.

### F5 / complete Route R self-test

```bash
./target/release/ring_matmul self-test
```

Result on final snapshot: **pass in 31.86s**. In addition to the existing
battery, all seven new R1 assertions pass: zero pads demonstrate the old leak,
random pads mask the checked combination, pad-after-challenge demonstrates the
ordering attack, and binding the pad commitment in h0 rejects it.

### Chain demo

```bash
./target/release/ring_matmul chain-demo 128 128 16 4
```

Result: **pass**:

```text
commit 0.01s | prove 0.46s (pi2 r_g=4 + wave of 54 claims, attempts 2) | verify 0.07s
chain-demo passed
```

Interpretation: the live packing fix repairs the demo/test parameter capacity.
It does not close the demo's printed q31 non-wrap caveat, E2 slot-constancy gap,
independent R1 review, or large-model performance question.

## Missing tests that should be P0

1. Extend the new R1 leak/order pairs to twisted ct, twisted ring, untwisted
   ring, CE gate, shared batches, abort/salt paths, and statistical distributions.
2. Malicious non-constant CRT slot coordinates are rejected after E2.
3. Modular wraparound witnesses fail every integer/range statement.
4. Manifest validation rejects missing operations, bad IDs, incompatible
   shapes/orientations, duplicate IDs, wrong spec digest, and DAG substitution.
5. Parser fuzzing, allocation limits, truncated proofs, non-canonical field
   elements, and verifier panic freedom.
6. Property tests comparing every optimized ring kernel with schoolbook
   arithmetic over boundary values, not only deterministic random samples.
7. Cross-version and cross-backend transcript replay rejection.
