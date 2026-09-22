# The encode conformance vectors, compiled and run in Rust — ledger

**Lane** `zk60-private-block-125m-review` (worktree
`/home/victor/wt-zk60-block125m-review`), opened from `81c519a`.
**Opened 2026-09-22 14:05 PDT, closed 2026-09-22 14:10 PDT.**

## Headline

**The vectors are correct. The Rust agrees with the third implementation on
all 35 vectors at all seven profiles, including the two production widths that
had never been checked by anything — 2^10 rate 4 (the rungs) and 2^14 rate 4
(rung-W14 and 125M). The test compiled and passed on the FIRST build with zero
fixes to the listing.**

`ZK60_ENCODE_CONFORMANCE_VECTORS.md` §9 said "not a Rust-verified artifact
yet". That sentence is now out of date: it is one.

## What this lane was for

The vectors were produced by a THIRD implementation of `encode_row_zk`
(`results/zk60_encode_vectors/encode_ref.py`) written from the Rust source text
without ever executing it. Before today the only cross-check against bytes the
Rust prover actually wrote was §4(b): 16 role-commitments in four committed
capture bundles, at ONE width (2^8 rate 8, `nn = 2048`), and only on the 256
opened columns of each — 12.5% of each row, at a width no rung uses. The
production widths had no check of any kind. §4(c) called the Rust test owed.

## What was compiled

| thing | value |
|---|---|
| file dropped in | `zkp-core/src/pcs/encode_conformance_tests.rs` |
| registered by | `#[cfg(test)] mod encode_conformance_tests;` in `zkp-core/src/pcs.rs`, beside `mod backend;` — **the only line touched in a production file, and it is `cfg(test)`** |
| `sha2` a real dependency of `zkp-core`? | **yes** (`zkp-core/Cargo.toml`, `sha2 = "0.10"`), so the vectors' SHA-256 digests are computed in Rust directly; no fallback hashing route was needed |
| JSON needed at runtime? | **no** — the listing embeds every digest, probe entry and full small row as a literal, so nothing was copied out of `results/zk60_encode_vectors/` into the crate |
| build | `cargo test --release --offline -j 2 --lib`, shared target dir, LTO off, codegen-units 8, under `/tmp/zk-build.lock`; ~8 s each time (deps were warm) |
| fixes to the listing | **none.** `diff` of the committed listing against the dropped-in file has **zero deleted lines** (`listing-to-dropped-in.diff`); every difference is an addition made after the four original tests were already green |

Every API the listing guessed at was right: `Fp(pub u64)` with `.0`, `Fp::ZERO`
/ `Fp::ONE` / `Fp::new` / `to_bytes`, `crate::field::P`, `NttTables::new`,
`pcs::coset_powers`, `pcs::encode_row_zk`, and the `Digest as _` import that
keeps `sha2::Digest` from colliding with `crate::merkle::Digest` pulled in by
`use super::*`.

## The tests and their results

Run `results/zk60_encode_vectors_rust/run3-six-tests.log` (the four as written
plus two added here); `run1.log` is the first build, the four as written.

| # | test name (`pcs::encode_conformance_tests::…`) | result |
|---|---|---|
| 1 | `encode_row_zk_matches_the_third_implementations_conformance_vectors` | **ok** |
| 2 | `the_conformance_inputs_are_the_ones_the_vectors_were_built_from` | **ok** |
| 3 | `the_smallest_conformance_vector_matches_entry_by_entry` | **ok** |
| 4 | `the_ordering_probes_at_the_125m_row_width_are_pinned` | **ok** |
| 5 | `the_named_negative_controls_are_all_distinct_from_the_real_encode` | **ok** (added by this lane) |
| 6 | `the_ordering_control_is_the_real_rows_bit_reversal` | **ok** (added by this lane) |

`test result: ok. 6 passed; 0 failed`, 0.03 s. The whole `zkp-core` library
suite with the module in it: **62 passed, 0 failed, no warnings**
(`run5-full-lib-suite.log`) — 56 that were there before plus these 6.

## What was compared, at each width

The digest rule is SHA-256 over **every** entry of the encoded row, 8
little-endian bytes each, in natural column order. So a digest match is a
whole-row comparison, not a sample: at 2^14 it pins all 65,536 entries at once.

| profile | `nn` | what was compared |
|---|---:|---|
| 2^3 rate 4 | 32 | full row **entry by entry, in the clear** (test 3), plus the message and pads entry by entry, plus the digests of all 5 kinds, plus the bit-reversed row's digest and its 24 moved entries (test 6) |
| 2^4 rate 4 | 64 | digests of all 5 kinds (full row, via SHA-256) |
| 2^6 rate 4 | 256 | digests of all 5 kinds; bit-reversed row's digest and its 240 moved entries (test 6) |
| 2^8 rate 4 | 1024 | digests of all 5 kinds |
| 2^8 rate 8 (the toy, the frozen seam) | 2048 | digests of all 5 kinds; input digests (test 2) |
| **2^10 rate 4 (the rungs)** | **4096** | **digests of all 5 kinds — the full row each time; input digests. Nothing had ever checked this width** |
| **2^14 rate 4 (rung-W14, 125M)** | **65536** | **digests of all 5 kinds — the full 65,536 entries each time; input digests; the four ordering sentinels at indices 0, 1, 2^15 and 2^16−1 asserted as bare `u64`s in the clear (test 4); the bit-reversed row's digest and its 65,280 moved entries (test 6)** |

35 of 35 vectors matched. Test 2 pins the PRNG separately at four profiles, so
a disagreement in the SplitMix64 fixtures could never have been mis-reported as
an encode disagreement — and it did not fire.

## The negative controls, in Rust

The controls are WRONG ENCODES; nothing in this crate implements them and none
was implemented here. Two Rust-side statements were made instead.

**Test 5 — distinctness.** At each of the three widths the control table covers
(2^3, 2^6, 2^14), the digest the real `encode_row_zk` produces equals the
CORRECT digest and equals **none of the five** control digests at that width.
The test also asserts that exactly five controls are listed per width, so the
table cannot silently lose an entry. All fifteen named-bug digests — DIF
ordering, conjugate root, off-by-one twiddle stride, inverse scaled by `1/nn`,
`tw[k]` — are therefore confirmed distinct from what this crate does.

**Test 6 — the ordering control reproduced from the real row.** The reference's
self-check S8 says control (a) is exactly `bitrev(correct)`. Permuting the row
*this crate really produced* by the bit-reversal on `log2(nn)` bits hashes to
control (a)'s published digest at all three widths, and the number of entries
the permutation moves is exactly the published count: **24 of 32, 240 of 256,
and 65,280 of 65,536**. The last is the number that states the danger — a DIF
device NTT leaves 256 of 65,536 columns correct and the protocol opens 256
columns. That diagnosis is now a Rust-side fact rather than a Python
prediction.

## The non-vacuity probe

A passing conformance test is worthless if it would pass anyway. One constant
was perturbed in the TEST's own helper — the coset generator, `Fp::new(7)` →
`Fp::new(11)`, nothing in production touched — and the suite was re-run
(`run4-mutation-probe.log`, cargo exit 101):

* **5 of the 6 tests FAILED**, at 2^3 and at 2^14, on digests, on the full row
  and on the sentinels;
* test 2, the input pinning, **stayed green** — exactly the separation it was
  designed for: the PRNG fixtures are unaffected by an encode change, so a
  future failure that trips test 2 is a fixture problem and one that spares it
  is an encode problem;
* the failure printed the wrong digest and, correctly, did **not** name a
  negative control for it (a wrong coset is not one of the five named bugs),
  so `diagnose()` neither misfires nor stays silent when it should speak.

The generator was reverted immediately and the green run above
(`run5-full-lib-suite.log`, 62 passed) is of the committed tree.

## Findings

**No mismatch of any kind.** There is nothing to report against either side:
not one entry, at any width, differs between the Rust and the vectors. The
brief's first-rank finding did not occur.

Two smaller observations, neither a defect:

1. **The listing needed no fix at all** — no import, no field name, no API.
   That is unusual for code written without a compiler, and it is itself a
   small piece of evidence that the third implementation read the source
   carefully rather than approximately.
2. **A source-mtime gate is downstream of this.**
   `scripts/hashline_cl_5090_preflight.py` treats every file under
   `zkp-core/src` as an input of the binary it qualifies and requires the
   binary to be newer than the newest source. Adding this file bumps that
   newest-source time, so the 5090 preflight will want a rebuild before it
   qualifies a binary again. That is the gate working as designed, not damage;
   it is recorded here so nobody debugs it twice.

## What this does and does not now establish

It establishes that `zkp-core::pcs::encode_row_zk`, as it stands at `81c519a`,
reproduces the 35 published vectors exactly, including at the 125M row width,
so a device (GPU) NTT can be qualified against those vectors alone with no
appeal to the CPU being present. §7 of the memo — the device team's procedure —
is now backed by a Rust-side contract.

It establishes nothing about the pad DRAW, the salts, the column digest, the
Merkle layer, the opening order, or privacy. §8 of the memo still holds in
full; this is byte identity of one function.

## For the lane to carry

Test names, exactly:

```
pcs::encode_conformance_tests::encode_row_zk_matches_the_third_implementations_conformance_vectors
pcs::encode_conformance_tests::the_conformance_inputs_are_the_ones_the_vectors_were_built_from
pcs::encode_conformance_tests::the_smallest_conformance_vector_matches_entry_by_entry
pcs::encode_conformance_tests::the_ordering_probes_at_the_125m_row_width_are_pinned
pcs::encode_conformance_tests::the_named_negative_controls_are_all_distinct_from_the_real_encode
pcs::encode_conformance_tests::the_ordering_control_is_the_real_rows_bit_reversal
```

The command, from a clean tree:

```
flock -w 1800 /tmp/zk-build.lock env CARGO_TARGET_DIR=<shared target> \
  CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 \
  ~/.cargo/bin/cargo test --release --offline -j 2 \
  --manifest-path <worktree>/zkp-core/Cargo.toml --lib encode_conformance_tests \
  -- --test-threads=1
```

## Files

| path | what |
|---|---|
| `run1.log`, `run1.done` | the first build and run: the four tests as written, all ok, exit 0 |
| `run2-with-control-test.log` | five tests (control distinctness added), all ok |
| `run3-six-tests.log` | **the headline run**: six tests, all ok |
| `run4-mutation-probe.log` | the deliberate perturbation (coset 7 → 11, reverted): 5 of 6 fail, test 2 correctly survives |
| `run5-full-lib-suite.log` | the whole `zkp-core` lib suite with the module in it: 62 passed, 0 failed |
| `listing-to-dropped-in.diff` | the committed listing vs. the file in the crate: additions only, zero deleted lines |
