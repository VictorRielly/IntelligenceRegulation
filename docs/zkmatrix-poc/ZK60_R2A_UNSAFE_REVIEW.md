# ZK60 R2a — review of the two `unsafe` boundaries in the initialize-once encode buffer

Written 2026-09-23 01:23–01:40 PDT by a Claude Opus reviewer lane, for the
integrator (Codex). It answers the request in
`ZK60_CODEX_FABLE_COORDINATION.md` §CURRENT: "Please review the two documented
unsafe boundaries before integration."

## The answer in plain words

**Both `unsafe` boundaries are sound. I found no undefined behaviour and no
latent undefined behaviour.** The new code produces the same matrix as the old
code on every input where the old code produced one, and panics wherever the
old code panicked. It draws no randomness. From a memory-safety standpoint R2a
can be integrated as it is. There are two optional hardening changes (U-1,
U-2) and two scope notes that correct how the change has been described
(U-7, U-8). This review is a reading of the code plus an independent test
harness. **Miri and sanitizers were not run.** Miri is not installed, and the
box has no nightly toolchain for sanitizers.

What R2a is: the tagged hiding commitment used to allocate
`vec![Fp::ZERO; rows·nn]` and then overwrite every element in
`encode_row_zk`. The zero fill is not free, because `Fp` is a user type and
`vec![x; n]` writes each element (only primitive zeros get a lazily zeroed
allocation). R2a instead writes each encoded row once, directly into the
vector's unused capacity (`MaybeUninit<Fp>` slots), and only then marks the
vector's length.

Severity labels used below:
- **UB**: undefined behaviour reachable today.
- **latent UB**: not reachable today, but one plausible edit away.
- **erratum**: a statement in the code, docs or ask that is wrong or misleading, with no memory effect.
- **note**: sound; an observation, a hardening suggestion, or a coverage fact.

## What was reviewed

| file (candidate-v1) | sha256 | matches `validation-1` source hash |
|---|---|---|
| `zkp-core/src/pcs.rs` | `227ecbdd…fdbbb5c` | yes |
| `zkp-core/src/pcs/encode_buffer.rs` | `3c01433d…c3dd70` | yes |
| `zkp-core/src/pcs/encode_buffer/tests.rs` | `41787bbc…93bb2` | yes |
| `zkp-core/src/pcs/encode_conformance_tests.rs` | `fba82900…886df8` | yes |

The copies under `results/zk60_encode_allocation_20260922/candidate-v1/` are
byte-identical to the sandbox sources `/tmp/zk60-encode-20260922/zkp-core/…`
that `validation-1` built and tested. Its `source_hashes_before ==
source_hashes_after` holds, over 181 files.

**The base is not main HEAD.** The candidate's `pcs.rs` is built on the
integration branch `integrate/zk60-shaped-20260920`, whose `pcs.rs` in
`/tmp/wt-zk60-shaped-20260920` has sha256 `6b8d1bfa…`, equal to
`source-changes-v1.json`'s `base_sha256`. Main HEAD's `zkp-core/src/pcs.rs`
(`2d914956…`) has no `commit_zk_owned_with_tag` at all. `diff base candidate`
shows exactly two changes: three module declarations (`mod encode_buffer;`
and `#[cfg(test)] mod encode_conformance_tests;`), and the tagged function's
CPU arm (base `:789-792` → candidate `:792`). `ntt.rs`, `field.rs`,
`Cargo.toml`, `Cargo.lock` and the text of `encode_row_zk` are identical in
main HEAD and the candidate.

Line numbers below refer to `candidate-v1/zkp-core/src/pcs/encode_buffer.rs`
unless stated otherwise.

## Boundary 1 — `initialize_row` turns its row into `&mut [Fp]` (`:70`)

```rust
unsafe { std::slice::from_raw_parts_mut(out.as_mut_ptr().cast::<Fp>(), out.len()) }
```

`slice::from_raw_parts_mut::<Fp>(p, len)` requires each of the following.

1. **`p` non-null and aligned for `Fp`; `len·size_of::<Fp>() ≤ isize::MAX`.**
   `p` comes from a live `&mut [MaybeUninit<Fp>]`, so it is non-null and the
   size bound already holds. `MaybeUninit<T>` is guaranteed to have `T`'s size
   and alignment, and `Fp` is `#[repr(transparent)] struct Fp(pub u64)`
   (`field.rs:18-20`, align 8). ✓
2. **Valid for reads and writes of `len` elements inside one allocation.** It
   is exactly the span of `out`. ✓
3. **All `len` elements initialized with valid `Fp` values.**
   `out` is split into three pieces: `message = out[..n]`,
   `pad = out[n..n+q]` and `zeros = out[n+q..]` (`:53-54`). The split cannot
   fail because `:49-50` assert `out.len() == pows.len()` and `n + q ≤
   out.len()` (with `checked_add`) before any write. Each piece is iterated in
   full, and every slot gets exactly one `MaybeUninit::write` (`:58-66`). The
   three lengths sum to `out.len()`. All indexing inside the loops is bounds-
   checked safe code: `coeffs[i]`/`pows[i]` with `i < n`, `pads[i]` with
   `i < min(n, q)`, `pads[n+i]` only when `n+i < q`, and `pows[n+i]` with
   `n+i < n+q ≤ nn`. So a panic there would happen before the conversion,
   never after it. Every bit pattern of a `u64` is a valid `Fp` (see U-4). ✓
4. **No other access for the returned lifetime `'a`.** The signature ties the
   result to the `&'a mut` borrow of `out`. `out` and its three split pieces
   are not used after the pointer is taken, and the caller (`:32-33`) uses
   only the returned slice. The `out.len()` evaluated after `as_mut_ptr()` is
   a shared reborrow. Under Stacked Borrows that is a read, which removes only
   Unique items above `out`, so the SharedRW raw pointer survives. Tree
   Borrows has no problem with it either. This `from_raw_parts_mut(s.as_mut_ptr().cast(),
   s.len())` idiom is the standard one. ✓

**No reference to an uninitialized `Fp` is formed**, not even briefly. Before
`:70` the only references are `&mut MaybeUninit<Fp>`. The `&mut Fp` that
`MaybeUninit::write` returns points at the value just written. There is no
`Debug` or `assert_eq!` on the row before `:70`.

`initialize_row` is a *safe* private fn, and it is sound for **every** input:
all of its own preconditions are asserted before the first write, so it puts
no obligation on its caller. It also stays sound if `out` already holds
data, because `write` drops nothing and `Fp` has no destructor.

**Verdict: sound.**

## Boundary 2 — `encoded.set_len(len)` (`:39`)

`Vec::set_len(len)` requires (a) `len ≤ capacity` and (b) elements
`[old_len, len)`, here `[0, len)`, to be initialized.

- **(a)** `Vec::with_capacity(len)` (`:22`) guarantees `capacity ≥ len`. It
  panics on byte overflow, and `len` itself is `rows.checked_mul(nn)`
  (`:21`). The code slices `spare_capacity_mut()[..len]` (`:26`), so it would
  also be correct if the allocator returned more than `len`. ✓
- **(b) coverage.** `:14-21` assert that `nn` is a power of two (so `nn ≥ 1`
  and `par_chunks_mut(nn)` cannot hit rayon's zero-chunk assert), that the
  data is nonempty with `data.len() % n == 0`, and that `len = rows·nn`. So
  `par_chunks_mut(nn)` over `[..len]` has exactly `rows` chunks, all of
  length exactly `nn`. There is no partial last chunk, for any `rows` and any
  thread count. Rayon's `par_chunks_mut` hands out pairwise-disjoint
  `&mut [MaybeUninit<Fp>]` chunks. That is part of rayon's *soundness*
  contract, because the API is safe. `enumerate` on this indexed iterator
  gives the true chunk index, and `for_each` calls the closure once per
  chunk. Every call runs `initialize_row`, which returns only after writing
  its whole chunk (Boundary 1), and then the NTT, which only rewrites
  initialized values. If a chunk ever had the wrong length, `:49` would panic
  before anything became visible. ✓ See U-2 for the one trust assumption
  here.
- **(b) ordering.** "Length set only after every worker joins" is **enforced
  by the code's structure, not by convention**.
  `encoded.spare_capacity_mut()` borrows `encoded` mutably for the whole
  expression statement `:26-34`. `set_len` needs `&mut encoded` again, so the
  borrow checker rejects any `set_len` while a chunk borrow is alive. And
  `for_each` is synchronous: because its closures borrow non-`'static` data,
  rayon's safe API must guarantee that no closure is still running when
  `for_each` returns or unwinds. ✓
- **Panic path.** If any worker panics, `rayon_core::join` waits for the
  sibling job before it resumes the unwind (`rayon-core-1.13.0/src/join/mod.rs:175-186`,
  `join_recover_from_panic`). The unwind then leaves `encode_rows` before
  `:39`. `encoded` still has length 0, so dropping it frees the allocation
  and drops no elements: no double drop, and nothing uninitialized is read.
  `Fp: Copy` cannot implement `Drop`, so partially written rows owe no
  cleanup; the memory is simply freed. ✓ (Empirically confirmed; see the
  harness.)

**Verdict: sound**, given rayon's documented `for_each` behaviour. That is a
pinned, `--locked` dependency: rayon 1.12.0 / rayon-core 1.13.0.

## Findings

**U-1 — note (optional simplification), `:70`.** The same conversion is now a
stable std method, `<[MaybeUninit<T>]>::assume_init_mut` (stable since Rust
1.93.0; the WSL box has rustc 1.97.1). `unsafe { out.assume_init_mut() }`
reduces Boundary 1's obligations to one fact, "every slot is initialized",
and drops the pointer, length and alignment reasoning. Adopt it only if every
build box (Mac, 5090 desktop) has toolchain ≥ 1.93. The repo pins no
`rust-version` and has no `rust-toolchain.toml`. The current code is correct
as written.

**U-2 — note (hardening), `:26-39`.** The only thing Boundary 2 trusts beyond
its own lines is a *functional* property of rayon: that `for_each` visits
every chunk. Disjointness is rayon's soundness contract and needs no check;
coverage is merely rayon being correct. A rayon bug that skipped a chunk
without panicking would turn `set_len` into exposure of uninitialized memory.
That would be a severe bug in a core rayon path, so the risk is very small.
But removing the dependency costs almost nothing: have each worker return `1`
through `.map(|(r, row)| { …; 1usize }).sum::<usize>()` (or bump an
`AtomicUsize`), and `assert_eq!(done, rows)` before `set_len`. That is one
add per row, a few hundred per commitment. After that change, the soundness
of `:39` depends on nothing outside this file except rayon's safety
contract.

**U-3 — note, panic safety.** Sound as argued above. In addition, both
`zkp-core/Cargo.toml` and `hashline/Cargo.toml` set `panic = "abort"` in
`[profile.release]`. So in release binaries a worker panic aborts the process
and the unwind path runs only in test and debug builds. Nothing in the
argument depends on this.

**U-4 — note, `Fp` validity.** `Fp` is `#[repr(transparent)] struct Fp(pub
u64)`: `Copy`, no `Drop`, and every bit pattern valid at the language level.
"Canonical (< p)" is a correctness convention, not a safety invariant: the
field is `pub`, and no `unsafe` code relies on it. The only `unsafe` in the
candidate `zkp-core` is the two boundaries plus two test-only `assume_init`
calls. The written values are canonical anyway. Each is produced by the same
`sub`/`mul` sequence on the same operands as the original, and those return
canonical outputs from canonical inputs. The zero tail is `Fp::ZERO`.

**U-5 — note, threads and aliasing.** No raw pointer crosses a thread, and
there is no `unsafe impl Send/Sync`. The closure captures only shared
references to `Sync` data (`&NttTables`, `&[Fp]`) and `usize` values.
Mutable access comes only through rayon's safe disjoint chunks.
`MaybeUninit<Fp>: Send` holds automatically. Clippy's unsafe lints
(`undocumented_unsafe_blocks`, `multiple_unsafe_ops_per_block`, `ptr_as_ptr`,
`cast_ptr_alignment`) raise nothing on the verbatim helper.

**U-6 — note, test-only `unsafe` (`encode_buffer/tests.rs:53-54`).** Sound.
Both `assume_init` calls read sentinels that were created by
`MaybeUninit::new(poison)` and lie outside the slice passed to the helper.

**U-7 — erratum (scope of the change and of its description).** The ask
describes the old allocation as "`commit_zk_owned_with_tag` … (`pcs.rs:732`,
`:789`)". In the base file only `:789` is in the tagged function. `:732` is
the **untagged** `commit_zk_owned_with`, and `:221` is the non-hiding
`commit_with`. The candidate changes **only `:789`**. `:732`, `:221`,
`hashline/src/wcache.rs:314` and the CPU reference buffers in
`hashline/src/gpu/cuda.rs` all keep their zero fill. So the saving applies
only when a *tagged* commitment takes the CPU fallback. Those callers are the
private-block `A`/`H` commitments (`protocol.rs:858, :977`), the boundary
commitment (`boundary.rs:350`) and the general endpoint (`endpoint_g.rs:280`),
which includes the 125M block path. The README says this correctly ("the
untagged commitment function [is] unchanged"). The line reference in the ask
does not.

**U-8 — note, the `q > n` case.** *Semantics:* in the original loop
(`pcs.rs:669-672`, candidate numbering), iteration `i` does `out[i] -=
pad[i]` and then `out[n+i] = pad[i]`. For `n ≤ j < n+q`, the assignment at
iteration `j−n` always comes before the subtraction at iteration `j`
(`n > 0`), and nothing touches `out[j]` in between. So the final
coefficient is `pad[j−n] − pad[j]` when `j < q`, and `pad[j−n]` otherwise.
There is no compounding. For `j < n` it is `coeffs[j] − pad[j]` if `j < q`,
else `coeffs[j]`. `:58-65` compute exactly these values, with the same
operations in the same order, and then multiply by `pows`, as the original
does over `0..n+q`. *Reachability:* `q > n` cannot occur through any
production tagged caller. `boundary.rs:140` and `endpoint_g.rs:165` refuse
`checks > 2^log_n`. `Shape` fixes `Q = COL_CHECKS = 256` (`shape.rs:51,209`),
and ruling S-1 (`shape.rs:295`) forces `log_cols = log(Dom::Tab) ≥
log2(U8_LEN = 256) = 8`, so `q ≤ n` (equality at the toy, `n = 256`).
*Consequence:* the bug in `candidate-initial` was **latent only** on
production shapes. My harness confirms this: the initial candidate passes the
production-width test, then fails the exhaustive test and the
`initialize_row` test at `n=1, q=2, nn=4`. The matrix comparison was the only
gate that could have caught it, and it did. The fixed code is correct for
all `q`.

## Semantics compared with the original (question 3)

- **Same matrix.** Element by element as in U-8. The zero tail is written as
  `Fp::ZERO`; the original zero-filled it and never multiplied it. The
  forward NTT is the same call on the same row.
- **Same refusals.** Every input the new code refuses up front, the old code
  also refused, only later and inside a worker: `q = 0` (rayon's
  `par_chunks(0)` assert, `rayon-1.12.0/src/slice/mod.rs:126`), `n + q > nn`
  (`encode_row_zk`'s assert), `nn` or `n` not a power of two, or `nn` beyond
  the tables (`NttTables::transform` asserts, `ntt.rs:71-73`). Panic messages
  and timing differ; outcomes do not.
- **Same randomness.** Pads and salts are still drawn before the branch, in
  the same order. `encode_rows` takes no RNG.

## What `validation-1` covers, and what it does not

Covered (logs read, not re-run by me):

| gate | shapes | result |
|---|---|---|
| matrix vs `encode_row_zk` (`encode_buffer/tests.rs`) | (n,q,nn) = (1,1,2) (1,7,8) (2,3,8) (4,4,8) (4,12,16) (16,3,64) (64,32,256) (256,256,2048) (1024,256,4096) (16384,256,65536); rows {1,3,7}; threads {1,2} | ok (debug + release) |
| of which `q > n` | (1,7,8) (2,3,8) (4,12,16) | ok |
| of which no zero tail (`n+q = nn`) | (1,1,2) (1,7,8) (4,4,8) (4,12,16) | ok |
| whole tagged commitment: matrix, data, pads, salts, root, next RNG output | (log_n, rows, q) = (4,3,8) (8,17,256) (14,3,256), rate 4, legacy tag and rung-G tag | ok |
| poisoned row (poison `0` and `0xa5a5…`, sentinels) | n=16, q=8, nn=64 | ok |
| invalid shapes refused before allocation | 10 cases | ok |
| 35 third-implementation vectors through `encode_rows` | 7 profiles (2^3 r4 Q4 … 2^14 r4 Q256), **one row each**, all `q ≤ n` | ok |
| hashline lib tests (`stable-weight-storage`, no `gpu-cuda`) | — | 512 passed, 17 ignored |
| native toy block: prove → fresh verify; new receipt under old verifier; old receipt under new verifier; 3 tamper refusals each | t32 profile, n=256 r8 Q=256 (`q = n`) | ACCEPT ×3 |

Not covered by `validation-1`:
- the 125M dense block (the `benchmark.py` A/B is still pending);
- any `gpu-cuda` build;
- `q > n` against the independent vectors (only against the old encoder);
- more than 2 Rayon threads;
- a worker panic *after* allocation (its invalid-shape test panics before
  allocating);
- Miri, ASan, TSan or Valgrind.

The native receipts are compared *functionally*, by cross-verification, not
byte for byte: the prover's randomness is fresh on each run. The untagged
(`:732`) and non-hiding (`:221`) paths are untouched, so their existing
tests say nothing about R2a.

## Independent harness (question 4)

Scratch crate `/tmp/claude-1000/r2a-review/`, outside the repo and lost on
reboot; the test file is reproduced below. `src/helper.rs` is a **byte-identical
copy** of the candidate's `encode_buffer.rs` (sha256 `3c01433d…`, checked).
Its `use super::{Fp, NttTables}` resolves to `zkp_core::field::Fp` and
`zkp_core::ntt::NttTables` from main-tree `zkp-core`, whose `ntt.rs`,
`field.rs`, `Cargo.lock` and `encode_row_zk` are identical to the
candidate's. The oracle is the **original** `zkp_core::pcs::encode_row_zk`
over a zero-filled buffer, and also the original parallel body verbatim.
Dependencies were built offline from the zkp-core lockfile. Commands (plain
`cargo`, under the build lock):

```
flock /tmp/zk-build.lock cargo test --offline --manifest-path /tmp/claude-1000/r2a-review/Cargo.toml -- --test-threads=1 --nocapture
flock /tmp/zk-build.lock cargo test --release --offline --manifest-path /tmp/claude-1000/r2a-review/Cargo.toml -- --nocapture
```

Results: **5/5 pass in debug (overflow checks on) and in release.**

- *Exhaustive small shapes:* every `(n, q, nn)` with `nn ≤ 128` and
  `1 ≤ q ≤ nn − n`. That is 1,291 shapes: 1,044 with `q > n` (including
  `q ≥ 2n` chains and `n = 1`) and 28 with no zero tail. Each runs at rows
  {1, 2, 3, 5, 7, 13} and on pools of {1, 2, 3, 8} threads, so the row
  counts do not divide the thread counts. Always equal to the original.
- *Production widths:* (8,4,32), (256,256,2048), (1024,256,4096) and
  (16384,256,65536), at 1 and 8 threads, equal to both original bodies.
- *`initialize_row` poison invariance:* 522 shapes (`nn ≤ 64`). Two
  different poisons give identical rows, so every slot is written. Sentinels
  on both sides stay intact, so nothing outside the row is written. The
  pre-NTT content equals a transcription of `encode_row_zk` without its final
  NTT, and a separate test ties that transcription to the real function.
- *Worker panic after allocation:* this uses a **modified copy** of
  `encode_rows`, which adds an in-flight counter held by a drop guard and a
  panic injected at row `bad`. Tried on pools {1, 2, 3, 8}, rows {1, 2, 7,
  64} and `bad` ∈ {0, rows/2, rows−1}. `catch_unwind` always returns `Err`,
  the process survives (no abort, no double free), and **in-flight = 0 at the
  catch**: no worker was running when the length-0 vector was dropped.
- *Negative control:* with `candidate-initial`'s `encode_buffer.rs` swapped
  in, the exhaustive test and the `initialize_row` test **fail** (first
  failure at n=1, q=2, nn=4), and the production-width test passes (U-8).
  The v1 file was restored afterwards (hash re-checked) and all 5 tests
  re-passed.
- `cargo clippy` with the four unsafe lints listed in U-5: clean. The one
  style lint, `manual_is_multiple_of` at `:18`, is not a safety issue.

## What I did NOT check

- Miri, AddressSanitizer, ThreadSanitizer and Valgrind: none run. Miri is not
  installed (only the rustup proxy exists), there is no nightly for
  sanitizers, and Valgrind is absent.
- Rayon's internals beyond the `join` panic path and the `par_chunks` assert.
  Chunk disjointness and `for_each` coverage are taken from rayon's API
  contract (U-2).
- I did not re-run `validation-1`, the native suite or the toy block. I read
  their logs and the hash records.
- The `gpu-cuda` build and any interaction between the returned `Vec` and
  pinned-host or pool registration: Codex's buffer inventory is still under
  review.
- The 0.54 s per-block saving and any timing.
- The 35 digests themselves. I relied on the passing
  `initialize_once_buffer_matches_all_35_independent_full_row_vectors` log
  line; the vectors' own provenance is `ZK60_ENCODE_CONFORMANCE_VECTORS.md`.
- `unsafe` code outside this patch.

## Appendix — harness test file (`src/helper/tests.rs`, sha256 `b0e66e14…b5a5`)

```rust
//! Independent edge-size tests of the candidate helper against the ORIGINAL
//! encoder (`zkp_core::pcs::encode_row_zk` over a zero-filled buffer).

use super::*;
use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicUsize, Ordering::SeqCst};
use zkp_core::pcs::{coset_powers, encode_row_zk};

struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn fp_vec(&mut self, len: usize) -> Vec<Fp> {
        (0..len).map(|_| Fp::new(self.next())).collect()
    }
}

/// The original tagged-path body, sequential: zero fill, then encode_row_zk.
fn reference(ntt: &NttTables, data: &[Fp], n: usize, pads: &[Fp], q: usize, pows: &[Fp]) -> Vec<Fp> {
    let nn = pows.len();
    let rows = data.len() / n;
    let mut out = vec![Fp::ZERO; rows * nn];
    for r in 0..rows {
        encode_row_zk(ntt, &data[r * n..(r + 1) * n], &pads[r * q..(r + 1) * q], pows, &mut out[r * nn..(r + 1) * nn]);
    }
    out
}

/// The original tagged-path body verbatim (base pcs.rs:789-792), parallel.
fn original_parallel(ntt: &NttTables, data: &[Fp], n: usize, pads: &[Fp], q: usize, pows: &[Fp]) -> Vec<Fp> {
    let nn = pows.len();
    let rows = data.len() / n;
    let mut encoded = vec![Fp::ZERO; rows * nn];
    encoded.par_chunks_mut(nn).zip(data.par_chunks(n)).zip(pads.par_chunks(q)).for_each(|((erow, drow), prow)| {
        encode_row_zk(ntt, drow, prow, pows, erow);
    });
    encoded
}

/// `encode_row_zk` minus its final forward NTT (a transcription; tied to the
/// real function by `pre_ntt_reference_is_encode_row_zk_before_the_ntt`).
fn pre_ntt_reference(ntt: &NttTables, msg: &[Fp], pad: &[Fp], pows: &[Fp]) -> Vec<Fp> {
    let (n, q, nn) = (msg.len(), pad.len(), pows.len());
    let mut out = vec![Fp::ZERO; nn];
    let mut coeffs = msg.to_vec();
    ntt.inverse(&mut coeffs);
    out[..n].copy_from_slice(&coeffs);
    for i in 0..q {
        out[i] = out[i].sub(pad[i]);
        out[n + i] = pad[i];
    }
    for i in 0..n + q {
        out[i] = out[i].mul(pows[i]);
    }
    out
}

fn pools() -> Vec<(usize, rayon::ThreadPool)> {
    [1usize, 2, 3, 8].iter().map(|&t| (t, rayon::ThreadPoolBuilder::new().num_threads(t).build().unwrap())).collect()
}

/// Every (n, q, nn) with nn <= 128 and n + q <= nn (q > n, q >= 2n, n = 1,
/// empty zero tail all included), rows not divisible by the thread count,
/// 1/2/3/8 threads.
#[test]
fn exhaustive_small_shapes_match_the_original_at_every_thread_count() {
    let ntt = NttTables::new(7);
    let pools = pools();
    let mut rng = Rng(0x52_32_61);
    let (mut shapes, mut q_gt_n, mut no_tail) = (0usize, 0usize, 0usize);
    for log_nn in 1..=7u32 {
        let nn = 1usize << log_nn;
        let pows = coset_powers(Fp::new(7), nn);
        for log_n in 0..log_nn {
            let n = 1usize << log_n;
            for q in 1..=nn - n {
                shapes += 1;
                q_gt_n += (q > n) as usize;
                no_tail += (n + q == nn) as usize;
                for rows in [1usize, 2, 3, 5, 7, 13] {
                    let data = rng.fp_vec(rows * n);
                    let pads = rng.fp_vec(rows * q);
                    let want = reference(&ntt, &data, n, &pads, q, &pows);
                    for (t, pool) in &pools {
                        let got = pool.install(|| encode_rows(&ntt, &data, n, &pads, q, &pows));
                        assert_eq!(got.len(), want.len());
                        assert!(got == want, "n={n} q={q} nn={nn} rows={rows} threads={t}");
                    }
                }
            }
        }
    }
    eprintln!("exhaustive: {shapes} (n,q,nn) shapes, {q_gt_n} with q>n, {no_tail} with n+q=nn; x6 row counts x4 pools");
}

/// The production widths (toy/frozen seam 2^8 r8, rungs 2^10 r4, 125M 2^14
/// r4) against BOTH oracles, 1 and 8 threads.
#[test]
fn production_widths_match_both_original_bodies() {
    let pools = pools();
    let mut rng = Rng(0x125);
    for (n, q, nn, rows_set) in [
        (8usize, 4usize, 32usize, &[5usize][..]),
        (256, 256, 2048, &[3, 9][..]),
        (1024, 256, 4096, &[1, 7][..]),
        (16384, 256, 65536, &[1, 3][..]),
    ] {
        let ntt = NttTables::new(nn.trailing_zeros());
        let pows = coset_powers(Fp::new(7), nn);
        for &rows in rows_set {
            let data = rng.fp_vec(rows * n);
            let pads = rng.fp_vec(rows * q);
            let want = reference(&ntt, &data, n, &pads, q, &pows);
            for (t, pool) in pools.iter().filter(|(t, _)| *t == 1 || *t == 8) {
                let got = pool.install(|| encode_rows(&ntt, &data, n, &pads, q, &pows));
                assert!(got == want, "n={n} q={q} nn={nn} rows={rows} threads={t}");
                let orig = pool.install(|| original_parallel(&ntt, &data, n, &pads, q, &pows));
                assert!(orig == want, "original parallel body n={n} rows={rows} threads={t}");
            }
        }
    }
}

#[test]
fn pre_ntt_reference_is_encode_row_zk_before_the_ntt() {
    let ntt = NttTables::new(6);
    let mut rng = Rng(9);
    for (n, q, nn) in [(1usize, 7usize, 8usize), (2, 3, 8), (4, 12, 16), (16, 8, 64), (8, 8, 16)] {
        let pows = coset_powers(Fp::new(7), nn);
        let (msg, pad) = (rng.fp_vec(n), rng.fp_vec(q));
        let mut pre = pre_ntt_reference(&ntt, &msg, &pad, &pows);
        ntt.forward(&mut pre);
        let mut real = vec![Fp::ZERO; nn];
        encode_row_zk(&ntt, &msg, &pad, &pows, &mut real);
        assert_eq!(pre, real);
    }
}

/// `initialize_row` writes EVERY slot of its row (two different poisons give
/// the same row), writes NOTHING outside it (sentinels intact), and its
/// pre-NTT content is the original encoder's, at every small shape.
#[test]
fn initialize_row_writes_every_slot_and_only_its_row() {
    let ntt = NttTables::new(6);
    let mut rng = Rng(77);
    let (pa, pb) = (Fp(u64::MAX), Fp(0x5555_5555_5555_5555));
    let mut shapes = 0;
    for log_nn in 1..=6u32 {
        let nn = 1usize << log_nn;
        let pows = coset_powers(Fp::new(7), nn);
        for log_n in 0..log_nn {
            let n = 1usize << log_n;
            for q in 1..=nn - n {
                shapes += 1;
                let (msg, pad) = (rng.fp_vec(n), rng.fp_vec(q));
                let mut a = vec![MaybeUninit::new(pa); nn + 2];
                let mut b = vec![MaybeUninit::new(pb); nn + 2];
                let ra = initialize_row(&ntt, &msg, &pad, &pows, &mut a[1..nn + 1]).to_vec();
                let rb = initialize_row(&ntt, &msg, &pad, &pows, &mut b[1..nn + 1]).to_vec();
                assert_eq!(ra, rb, "a slot kept its poison: n={n} q={q} nn={nn}");
                assert!(!ra.contains(&pa) && !rb.contains(&pb));
                assert_eq!(ra, pre_ntt_reference(&ntt, &msg, &pad, &pows), "n={n} q={q} nn={nn}");
                // SAFETY: the sentinels were initialized by MaybeUninit::new
                // and are outside the slice handed to the helper.
                unsafe {
                    assert_eq!((a[0].assume_init(), a[nn + 1].assume_init()), (pa, pa));
                    assert_eq!((b[0].assume_init(), b[nn + 1].assume_init()), (pb, pb));
                }
            }
        }
    }
    eprintln!("initialize_row: {shapes} shapes, poison-invariant, sentinels intact");
}

/// NOT verbatim: `encode_rows` with one added line per worker (an in-flight
/// counter held by a drop guard, and a panic injected at row `bad` after
/// that row's initialize+NTT). Checks that when the panic reaches the caller
/// no worker is still running (so the len-0 Vec is dropped with no writer
/// alive) and that the process survives (no double free / abort).
fn encode_rows_injected(ntt: &NttTables, data: &[Fp], n: usize, pads: &[Fp], q: usize, pows: &[Fp], bad: usize, in_flight: &AtomicUsize, ran: &AtomicUsize) -> Vec<Fp> {
    struct Guard<'a>(&'a AtomicUsize);
    impl Drop for Guard<'_> {
        fn drop(&mut self) {
            self.0.fetch_sub(1, SeqCst);
        }
    }
    let nn = pows.len();
    let rows = data.len() / n;
    let len = rows.checked_mul(nn).expect("PCS encoded size overflow");
    let mut encoded: Vec<Fp> = Vec::with_capacity(len);
    encoded.spare_capacity_mut()[..len]
        .par_chunks_mut(nn)
        .enumerate()
        .for_each(|(r, row)| {
            in_flight.fetch_add(1, SeqCst);
            let _g = Guard(in_flight);
            let input = &data[r * n..(r + 1) * n];
            let pad = &pads[r * q..(r + 1) * q];
            let initialized = initialize_row(ntt, input, pad, pows, row);
            ntt.forward(initialized);
            ran.fetch_add(1, SeqCst);
            if r == bad {
                panic!("injected worker panic at row {r}");
            }
        });
    unsafe { encoded.set_len(len); }
    encoded
}

#[test]
fn a_worker_panic_propagates_only_after_every_worker_has_left() {
    let ntt = NttTables::new(10);
    let (n, q, nn) = (256usize, 256usize, 1024usize);
    let pows = coset_powers(Fp::new(7), nn);
    let mut rng = Rng(5);
    let prev = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    for (t, pool) in pools() {
        for rows in [1usize, 2, 7, 64] {
            for bad in [0, rows / 2, rows - 1] {
                let data = rng.fp_vec(rows * n);
                let pads = rng.fp_vec(rows * q);
                let (in_flight, ran) = (AtomicUsize::new(0), AtomicUsize::new(0));
                let res = std::panic::catch_unwind(AssertUnwindSafe(|| pool.install(|| encode_rows_injected(&ntt, &data, n, &pads, q, &pows, bad, &in_flight, &ran))));
                assert!(res.is_err(), "threads={t} rows={rows} bad={bad}");
                assert_eq!(in_flight.load(SeqCst), 0, "a worker was still running when the panic reached the caller: threads={t} rows={rows} bad={bad}");
                assert!(ran.load(SeqCst) >= 1 && ran.load(SeqCst) <= rows);
            }
        }
    }
    std::panic::set_hook(prev);
}
```
