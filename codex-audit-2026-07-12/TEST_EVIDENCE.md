# Test and benchmark evidence

All commands were run on 2026-07-12 in the repository's existing environment.
No dependencies were downloaded. Rust commands used the installed stable
toolchain directly because the default shell PATH did not expose it.

## Current U-K8 HEAD

Snapshot: `8a206aec09f15f8eb203354eeaa02c15258abe68`, including the two live
documentation edits (which do not affect tests).

Command:

```bash
python3 -m unittest discover -s tests -v
```

Result:

- **42/42 tests passed**
- elapsed reported by unittest: **209.000 seconds**
- `ring_matmul self-test`: **108.80 seconds**
- U-K8 battery within that self-test: **72.5 seconds**
- honest 1,020-element U-K8 run printed approximately:
  - commit: 0.15 s
  - prove: 8.84 s
  - verify: 1.10 s

The green suite establishes honest-path regression behavior for the monolithic
harness. It does not address C-01 (public masks), C-02 (trusted prover hash), or
an independent proof parser/verifier.

## Executable Statement v2 negative probe

I compiled a temporary bin against the reviewed `manifest.rs` in the `/tmp`
snapshot. It was not added to the repository. The probe constructed five
statements that a strict validator should reject. Actual results:

```text
arbitrary lookup scales: Ok(())
narrowed impossible rescale scale: Ok(())
signed 8x8 product accepted in signed 15 bits: Ok(())
cyclic graph: Ok(())
empty add: Ok(())
```

The narrowed case used `x.frac_bits=2`, `shift=4`, and
`y.frac_bits=63`; adding a valid range fact on `y` made the validator bypass
the impossible scale transition. The signed case used two signed 8-bit inputs
and a signed 15-bit Hadamard output, demonstrating the positive-endpoint issue.
This converts C-03 and two H-03 structural gaps from code inspection into
reproduced acceptance behavior.

## Executable mask reconstruction probe

A second temporary `/tmp` bin instantiated the real `KField`, table digest,
`LkpTranscript`, `draw_masks`, and `BlinderSet::draw` twice from the same public
seed and domain. It created two independent Rust objects. Actual output:

```text
independently reconstructed masks equal: true
independently reconstructed blinders equal: true
both freshness flags initially clear: true
```

This directly reproduces C-01: the concrete coefficients are public/repeatable,
and the in-object freshness marker cannot detect reconstruction.

## Clean U-K9 commit

Snapshot: archive of `e8fa7772d445e1d8a05a558a9f28f325d7e3bd5a`, excluding its worktree's
later uncommitted edit.

Commands:

```bash
cargo build --release
./target/release/ring_matmul self-test
python3 -m unittest discover -s tests -v
```

Results:

- release build: **passed**
- dedicated U-K9 self-test: **passed**, including packed/scalar equality for
  fold, MLE, eq table, fixed multiplication, unmasked descent, two-instance
  descent, and masked descent
- full suite: **42/42 tests passed**
- elapsed reported by unittest: **133.903 seconds**
- `ring_matmul self-test`: 35.34 seconds in the full run (34.22 seconds in a
  standalone run)

This snapshot is internally green against its pre-U-K8 base. No combined
U-K8+U-K9 source tree was built or tested because the branches have not been
merged and have a real conflict.

## Interrupted U-K9 worktree residue

Worktree HEAD: `e8fa777`; live edit: 32 lines in `ring/kfield.rs`.

Command:

```bash
cargo build --release
```

Result: **failed (exit 101)** with Rust E0061 twice. `fold_body` was changed
from five arguments to four, while the `k9_fold_blocks` macro wrapper still
supplies `src` and `dst` separately. The new `eq_double_body` is not wired.

This is useful interrupted work, but it is not a buildable patch.

## Deterministic-test commit

Snapshot: `4d9d0d2076c1033221b312d7ddf5a33cde3c1c05`.

Command:

```bash
python3 -m unittest \
  tests.test_zk_lattice.Pi1Tests.test_rejects_tampered_responses \
  tests.test_zk_lattice.Pi2Tests.test_rejects_tampered_responses -v
```

Result: **2/2 passed**. The patch scopes a seeded `random.Random` adapter to the
two tests; production Python sampling continues to use `secrets`.

The patch converts probabilistic negative tests into fixed known-answer cases.
It should be retained, but supplemented with a separate statistical/multi-seed
test because an 8-bit toy Fiat–Shamir challenge has a real collision
probability rather than a deterministic rejection guarantee.

## Same-machine U-K9 benchmark differential

Commands, run sequentially for each snapshot:

```bash
/usr/bin/time -v ./target/release/ring_matmul lookup-bench 18
/usr/bin/time -v ./target/release/ring_matmul lookup-bench 20
/usr/bin/time -v ./target/release/ring_matmul lookup-bench 22
```

These are explicitly the repository's **unmasked, uncommitted, single-threaded
lookup-core** benchmark. They are useful for reviewing U-K9's kernel and memory
work; they are not end-to-end proof measurements.

| N | Current ns/el | U-K9 ns/el | Speedup | Current max RSS | U-K9 max RSS | RSS reduction |
|---:|---:|---:|---:|---:|---:|---:|
| 2^18 | 9,665 | 5,142 | 1.88x | 393,912 KiB | 167,212 KiB | 2.36x |
| 2^20 | 10,235 | 5,364 | 1.91x | 1,566,020 KiB | 658,588 KiB | 2.38x |
| 2^22 | 11,064 | 5,751 | 1.92x | 6,254,184 KiB | 2,657,840 KiB | 2.35x |

At `2^22`, clean U-K9 completed in 28.06 seconds wall time and used about
2.54 GiB peak RSS. The current implementation completed in 51.99 seconds and
used about 5.96 GiB. This is solid progress, but below the planned 5–10x speed
gain and not measured at `2^23` or inside the committed U-K8 chain.

The benchmark itself prints 22-thread and GPU rows by multiplying assumed
8.74x and 20x factors. No lookup parallelism or GPU kernel implements those
rows, so they remain assumptions.

## Formatting and static hygiene

Commands:

```bash
cargo fmt --all -- --check
git diff --check 7da16f2..e8fa777
git diff --check 7da16f2..4d9d0d2
git diff --check HEAD
```

Results:

- `cargo fmt --check`: **failed** on both current and clean U-K9 snapshots with
  extensive repository-wide formatting differences.
- all three `git diff --check` commands: **passed** (no whitespace errors in
  the reviewed deltas).
- release builds emit numerous existing warnings; U-K9 adds unused kernel
  helpers and one unused local.

Formatting failure is not a cryptographic blocker, but it makes a 6,000-line
security-sensitive delta harder to review and should be normalized before an
external audit.

## Snapshot hashes

Selected live U-K8 files:

```text
cc0ab6ebcedb049d163424a5e0cd354eeaded406baa56300eff30d5d0a899b25  PROGRESS.md
07d81f679563a8acb1edf52c5c61c4c19a145e96522d368ad765598f5037ff69  docs/zkmatrix-poc/M4_LOOKUP_DESIGN.md
a5a2117b9134ed2153ce2ec4078f5bad3a5730a395fee75700cb2b54576c592e  zkmatrix-rs/src/manifest.rs
6451ee144c2ac966161ddb6f5fc494881961d74ecb37cf8996f7f4568a9c7187  zkmatrix-rs/src/bin/ring_matmul.rs
05053b7e0f578054fb578873883495157e2da67c17bdea98edb9ac0145c60be2  zkmatrix-rs/src/ring/gkr_masked.rs
d9642f4ff9d9b718778aaf8253357035173feb1077b27cd8c5fe402d5095ebd1  zkmatrix-rs/src/ring/lookup.rs
```

Clean U-K9 source hashes:

```text
8216bc4946d7f9fa477881a580fcbbea8440f5455ab83b485fc29a939054f5c1  zkmatrix-rs/src/ring/kfield.rs
5fd943c652260f83acd5dd65cf264bc52946ffe608a80a4f72faae1ef74d6c79  zkmatrix-rs/src/ring/gkr.rs
29127a1588dcadc8c6e3ac8144f744d55ba66429393f809ab454a9b18e743178  zkmatrix-rs/src/ring/gkr_masked.rs
c99edb46e7cb2d763288fad2bd4966a5acd562335469cfa0b5afe516ec75a9f9  zkmatrix-rs/src/bin/ring_matmul.rs
```

The live interrupted `kfield.rs` hash is
`344f33b202104f8524185839f902eab2ab31137696d4a5768990d2ffc0d51f0e`.
