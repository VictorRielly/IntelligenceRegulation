# Build, test, and measurement evidence

Commands were run on 2026-07-14 in the existing offline environment. The
installed stable Rust toolchain was invoked directly because the default
shell's Snap `cargo` wrapper is not usable in this workspace.

## Static/build checks

### Release check of the principal binary

```bash
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc \
  /home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/cargo \
  check --release --offline --bin ring_matmul
```

Result: **pass**.

### All Rust targets

```bash
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc \
  /home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/cargo \
  check --release --offline --all-targets
```

Result: **pass**, with 19 warnings in `ring_matmul` (unused imports, locals,
helpers, and fields).

```bash
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc \
  /home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/cargo \
  test --release --offline --all-targets
```

Result: **pass compilation**, but the Cargo targets contain **zero Rust unit
tests**. The protocol coverage lives in executable batteries and Python
wrappers, so this green result is not a cryptographic test-suite result.

### Final exact-source rebuild

After the live U-S1 worktree changed, the release binary was rebuilt again
from the final hashes in `SNAPSHOT.md`:

```bash
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc \
  /home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/cargo \
  build --release --offline --bin ring_matmul
```

Result: **pass**, same 19 warnings.

### Whitespace

```bash
git diff --check
```

Result: **pass** before the audit files were added. No implementation
whitespace errors were found.

## Python regression subset

```bash
PATH=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:/usr/bin:/bin \
python3 -m unittest \
  tests/test_zkmatrix_protocol.py \
  tests/test_zkmatrix_link.py \
  tests/test_zk_lattice.py
```

Result: **30/30 passed** in 48.361 seconds.

An initial invocation inherited the unusable Snap Cargo environment and
failed before exercising code. Re-running with the installed toolchain on
`PATH` produced the result above; the first failure is environmental, not a
repository regression.

The complete Python discovery suite was not rerun after the final U-S1 dirty
edit because its native wrapper invokes the entire multi-minute monolithic
`ring_matmul self-test`. The changed functionality was rebuilt and exercised
directly as described below, while the focused protocol suites and principal
committed batteries were run independently.

## Protocol and adversarial batteries

### Freeze check

```bash
./target/release/ring_matmul freeze-check
```

Result: **pass**, including LKP-9.

Interpretation: this proves that the checked constants match their frozen
windows. It does not prove that `ARP_REJ_T = 1.5` meets a statistical-security
target; C-01 shows that it does not under the repository's own lemma.

### Statement inventory

```bash
./target/release/ring_matmul statement-inventory
```

Result: **pass**.

Reported inventory:

```text
737 entries / 736 operations
96 Matmul
128 Rescale
224 Range
224 Binary
32 Lookup
32 Hadamard
8.5249e9 paid commitment coefficients
modeled commitment time: ~1001 s 1T / ~115 s with assumed 22T factor
```

This validates and counts the generated graph; it does not run a composed proof
of those operations.

### U-R per-layer multi-wave battery

```bash
./target/release/ring_matmul ffn-chain layer battery
```

Result: **pass**, 65.60 seconds.

The 4,092-element honest case reported approximately:

```text
commit 0.06 s
prove  3.38 s
verify 0.83 s
3 waves
```

The battery rejected altered partial sums, compensated share changes,
cross-wave mask substitution, off-table lookup values, and a bad Hadamard
output. It establishes sound wiring for those mutations. It has no honest
transcript privacy/recovery test and does not serialize/count the ct proofs.

### Legacy U-K8 chain battery

```bash
./target/release/ring_matmul ffn-chain battery
```

Result: **pass**, 251.29 seconds.

The honest 1,020-element q46/range/lookup/Hadamard block reported:

```text
q46 prove  ~32.35 s
total prove ~33.24 s
verify       ~1.08 s
3 ARP restarts in this run
```

The faster restart result is consistent with the new `t = 1.5` parameter. It
does not resolve the statistical-distance defect in C-01.

### Dirty U-S1 fresh-process harness

After rebuilding the final source:

```bash
./target/release/ring_matmul us1-battery
```

Result: **pass**, about 0.06 seconds inside the executable.

Observed behavior:

```text
honest in-process proof            ACCEPT
honest child-process proof         ACCEPT
free-h0 proof                      REJECT
stale-h0 proof                     REJECT
reconstructible-mask leak model    RECOVERS (expected attack demonstration)
secret-mask leak model             FAILS TO RECOVER
two OS session nonces/masks         DIFFER
```

This is useful plumbing coverage. It does not make the format sound against an
arbitrary byte-producing prover: `us1_verify_bytes` reads its expected
statement/digest from those bytes and calls both descents with mask pinning
disabled. The repository's E3Z-N1 attack battery already demonstrates that a
doctored false lookup accepts under `pin=false` and rejects under `pin=true`.

## Performance evidence used in the decision

The repository's recorded U-R S2 `2^20` arm-A row is:

| Elements | Waves | Commit | Prove | Verify | Peak RSS |
|---:|---:|---:|---:|---:|---:|
| 1,048,572 | 670 | 16.0 us/el | 578.7 us/el | 187.4 us/el | 8.23 GiB |

Multiplying those measured per-element rates gives:

```text
commit = 16.78 s
prove  = 606.81 s
verify = 196.50 s
```

The source prints only:

```text
masked descent bytes + partial reveal count * 12
```

as “masked transcript.” It does not add `CtRoundProof`. Counting the current
dominant arrays for 88,247 openings gives:

```text
z:   88,247 * 26 * 128 * 8 bytes = 2,349,488,128 B = 2,240.65 MiB
w1:  88,247 *  8 * 128 * 8 bytes =   722,919,424 B =   689.43 MiB
sum:                                      2,930.08 MiB = 2.861 GiB
```

This is a fixed-width current-type accounting calculation, not a canonical
wire measurement. Its purpose is to show that the omitted term dominates by
orders of magnitude; Phase 3 has not yet defined the real encoding.

## What the green tests do and do not establish

They establish:

- the reviewed source compiles;
- honest local prover/verifier variable flow is consistent;
- named tamper legs are rejected by the corresponding monolithic rigs; and
- the new range lookup catches the tested out-of-domain value.

They do not establish:

- negligible ZK for `t = 1.5`;
- privacy after revealing per-wave partition sums;
- soundness of arbitrary serialized U-S1 bytes;
- canonical/malformed proof handling;
- the true proof byte count;
- a complete FFN or transformer statement; or
- any GPU latency or host/device transfer result.
