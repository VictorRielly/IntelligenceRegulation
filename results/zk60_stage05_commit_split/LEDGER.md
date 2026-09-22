# Stage 0.5 — where the hiding commitment's CPU time actually goes

**Opened 2026-09-22 13:09 PDT, closed 2026-09-22 13:24 PDT** on the review
worktree `/home/victor/wt-zk60-block125m-review` (branch
`zk60-private-block-125m-review`). Measurement only: **no production line
changes anywhere**, one new `#[cfg(test)]` module, two 125M runs, and this
ledger.

## THE ANSWER, IN ONE SENTENCE

**The ENCODE is the larger half, by about 3.7 to 1, at both commitments and
at both shapes** — at 125M `A` encodes in 1.270 s and hashes in 0.338 s, `H`
encodes in 1.631 s and hashes in 0.438 s; at rung-W14 `A` is 0.118 s against
0.032 s and `H` is 0.097 s against 0.028 s — so the 99.5% of the
compressions that live in the column digests are **13-14% of the seconds**,
and ruling DC-G(1)'s condition ("if the encode is the larger half, *encode
on the device, hash on the host* needs no keyed kernel at all") **is met**.

## Why this exists

Ruling **DC-G(1)** of `ZK60_HIDING_COMMITMENT_ON_DEVICE_DISPOSITION.md`:

> **Stage 0.5, before any kernel: split the measured `A: commit` into encode
> and hash.** Compression counts say hashing dominates the count; nobody has
> measured whether it dominates the TIME. If the encode is the larger half,
> "encode on the device, hash on the host" needs no keyed kernel at all and
> the whole keyed-CUDA question moves down the list.

The count was never in dispute: §2.2 of the memo counts **112,066,560 of
112,590,844** compressions in the column digests, and its check re-derives
them [COUNTED]. A compression count is not a second. That is the whole point
of this page.

---

## 1. What was measured, with which functions

A hiding commitment is `zkp_core::pcs::commit_zk_owned_with_tag`
(`zkp-core/src/pcs.rs:769`), reached through hashline's
`pcs::commit_zk_owned_tagged`. It does six things in this order:

| # | part | the call |
|---|---|---|
| 1 | pads + salts | `rng.fp_vec(rows·Q)`, then `nn` × `rng.bytes32()` |
| 2 | coset powers | `coset_powers(zk.coset, nn)` |
| 3 | allocate + **zero** the encoded matrix | `vec![Fp::ZERO; rows · nn]` |
| 4 | **ENCODE** | `encode_row_zk` per row, in the prover's own rayon loop over `par_chunks_mut(nn)` |
| 5 | **HASH** | `hash_columns_keyed(&encoded, rows, nn, tag.column_key())` |
| 6 | leaves + tree | `salt_leaf_keyed` per leaf, then `MerkleTree::build_keyed` |

The harness calls **those functions**, not replicas, with **each shape's real
parameters** — `protocol::pcs_params_at` (message 2^14, encoded 2^16, inverse
rate 4), `ZkOpts::standard` (`Q = 256`, coset generator 7),
`Shape::hash_tag()` (both shapes are TAGGED profiles, so the column digest is
keyed and ruling T-8 keeps it off the device hasher in any case),
`NttTables::new(protocol::ntt_log_at(sh))` — and with the row counts the real
`Layout::for_shape` produces, asserted against the memo's: **`A` 5,681 and
`H` 7,120 at 125M, 527 and 436 at rung-W14**, endpoints 37 and 9.

**`M` — the fifth commitment — was found and measured, and it is not in this
split.** `M` is `zk::mask_commit_tagged` (`hashline/src/zk.rs:481`), **50
rows over a 2^12 domain** (`2 · 23 masks + 4`, the fixed CFS geometry). It
does **not** go through `commit_zk_owned_with_tag`: it has its own encode
(`encode_coeffs_coset`, with the pads inside the message rather than
appended), so it is reported as a whole and never split. It costs **0.021 s**
— under 0.4% of a 125M block's commitments — and is the same at both shapes
because its geometry is fixed.

**The gate that makes the clocks comparable.** The parts and the whole are
run from two generators at the same seed, so the parts' Merkle root **must**
equal the root the enclosing call returns. That is asserted at every shape,
every commitment and every repetition (`one_rep`, the `parts_root ==
whole_root` assertion). If the harness had reproduced a *different*
computation, the roots would differ and the tests would fail.

**Thread count: `rayon::current_num_threads() = 22`**, printed in every run.

---

## 2. Rung-W14 (527 / 436 / 9 / 50 rows) [MEASURED, 3 runs, shared box, not quiesced]

`results/zk60_stage05_commit_split/rung-w14-split.log`. Seconds, min /
median / max over three repetitions in one process; the share is of the
median whole.

| part | `A` (527 rows) | share | `H` (436 rows) | share |
|---|---|---:|---|---:|
| pads + salts | 0.005 / 0.005 / 0.005 | 1.9% | 0.005 / 0.005 / 0.005 | 2.2% |
| coset powers | 0.000 | 0.1% | 0.000 | 0.2% |
| alloc + zero encoded | 0.079 / **0.080** / 0.083 | 31.1% | 0.067 / **0.067** / 0.069 | 30.7% |
| *(of which: the zero stores)* | *0.022* | *8.6%* | *0.019* | *8.6%* |
| **ENCODE** | 0.117 / **0.118** / 0.158 | **46.0%** | 0.097 / **0.097** / 0.099 | **44.5%** |
| **HASH (columns)** | 0.031 / **0.032** / 0.037 | **12.4%** | 0.027 / **0.028** / 0.028 | **12.6%** |
| leaves + tree | 0.024 / 0.025 / 0.025 | 9.7% | 0.022 / 0.023 / 0.024 | 10.7% |
| **WHOLE (one call)** | 0.248 / **0.256** / 0.269 | 100% | 0.219 / **0.219** / 0.220 | 100% |
| parts sum | 0.260 (**−1.3%**) | | 0.221 (**−0.8%**) | |
| **encode / hash** | **3.71** | | **3.53** | |

Endpoint (9 rows): whole **0.036 s**, of which leaves + tree 0.026 s
(71.3%) — at nine rows the 2^16-leaf tree and its 65,536 salts are the whole
cost and both the encode (0.003 s) and the hash (0.003 s) are noise. That is
the counted fact of §2.3 ("the salt count is `nn`, not `rows`") showing up
as seconds.

`M`: whole **0.0212 s** (0.0199 / 0.0212 / 0.0212), never split.

---

## 3. 125M (5,681 / 7,120 / 37 / 50 rows) [MEASURED, 3 runs, shared box, not quiesced]

Two independent heavy runs, both detached under `flock /tmp/zk-heavy.lock`
in a `systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0` scope
with `MALLOC_MMAP_THRESHOLD_=131072`, one commitment resident at a time, both
exit 0:

* `m125-split.log` / `.done` — run 1
* `m125-split-run2.log` / `.done` — run 2, with the zero-store split added

Run 2's table (run 1's medians in the last column, as the reproducibility
check):

| part | `A` (5,681 rows) | share | `H` (7,120 rows) | share | run 1 `A` / `H` |
|---|---|---:|---|---:|---|
| pads + salts | 0.026 / 0.027 / 0.029 | 1.1% | 0.032 / 0.032 / 0.033 | 1.0% | 0.027 / — |
| coset powers | 0.000 | 0.0% | 0.000 | 0.0% | 0.000 |
| alloc + zero encoded | 0.865 / **0.882** / 1.325 | 35.2% | 1.200 / **1.226** / 1.326 | 38.8% | 0.854 / 1.303 |
| *(of which: the zero stores)* | *0.237* | *9.5%* | *0.302* | *9.6%* | *not measured* |
| **ENCODE** | 1.216 / **1.270** / 1.316 | **50.7%** | 1.610 / **1.631** / 1.677 | **51.6%** | 1.300 / 1.650 |
| **HASH (columns)** | 0.330 / **0.338** / 0.339 | **13.5%** | 0.429 / **0.438** / 0.441 | **13.8%** | 0.332 / 0.430 |
| leaves + tree | 0.024 / 0.025 / 0.029 | 1.0% | 0.007 / 0.019 / 0.027 | 0.6% | 0.023 / 0.024 |
| **WHOLE (one call)** | 2.488 / **2.504** / 2.883 | 100% | 3.145 / **3.161** / 3.488 | 100% | 2.578 / 3.158 |
| parts sum | 2.543 (**−1.5%**) | | 3.346 (**−5.9%**) | | +1.6% / −8.9% |
| **encode / hash** | **3.75** | | **3.73** | | 3.91 / 3.84 |

Endpoint (37 rows, each of two): whole **0.048 s**, again dominated by the
tree (0.027 s, 55.8%). `M`: whole **0.0205 s**.

**A 125M block's five commitments, added up from this table:**
2.504 + 3.161 + 2 × 0.048 + 0.021 = **5.78 s**, against DC-F's 6.50 s for
the commitments in the one-run Amdahl table. Of that 5.78 s, the column
hashing is **0.79 s (13.7%)** and the whole Merkle layer — salted leaves,
inner nodes, all five trees — is **0.12 s (2.0%)**.

**Peak memory of the heavy run: 4.44 GiB (`VmHWM` from `/proc/self/status`,
`run::peak_rss_mib`), against the 8 GiB cap.** No OOM, no swap (swap was
disabled in the scope). That is one encoded matrix (3.48 GiB for `H`) plus
its message rows (0.87 GiB), which is what "one commitment at a time" buys.

---

## 4. Do the parts sum to the whole, and to the prover's phase clock?

**To the whole: yes.** −1.3% and −0.8% at rung-W14, −1.5% and −5.9% at 125M
(run 1: +1.6% and −8.9%). The residues are signed both ways, so they are
run-to-run spread and not a missing part. The single largest contributor to
that spread is part 3: its max exceeded its median by 50% in one `A`
repetition (1.325 s against 0.882 s), which is a cold-page-fault artefact on
a shared box. **Everything the enclosing call does is in the six parts; there
is no seventh.**

**This mattered, and it is worth recording how.** The first version of this
harness allocated the encoded matrix *before* starting the encode timer and
came up **30% short** of the whole. That 30% is not overhead: it is part 3,
and finding it is one of this page's two results (§6).

**To the prover's own phase clock: yes, same order of magnitude on the same
box, at 81% and 90%.**

| | this harness (median) | prover `q28-baseline-dense.log` | prover `q28-m125-final-dense.log` |
|---|---:|---:|---:|
| `A: commit` | **2.504 s** | 3.076 s | 3.069 s |
| `H: commit` | **3.161 s** | 3.499 s | 3.431 s |

Those `PB-TIMING` lines were read from
`/home/victor/wt-zk60-block125m/results/zk60_block125m_lane/` and are one run
each. The harness is below them, which is what should be expected and is not
a discrepancy to explain away: at the moment the prover reaches `A: commit`
it is already holding 5.0 GiB resident and ends `H: commit` at 8.2 GiB (the
`RSS MiB` column of those same lines), while this process never exceeds 4.4
GiB and holds one commitment at a time. More resident memory means more
expensive faults and more cache pressure on exactly the two parts that are
memory-bound. **The split is what this page claims; the absolute seconds are
a lower bound on the prover's.**

---

## 5. Keyed against unkeyed column hashing

At rung-W14, `A`'s encoded matrix (527 × 65,536), three bodies over the same
bytes, three repetitions ([MEASURED], medians):

| body | seconds |
|---|---:|
| `hash_columns_keyed(.., tag.column_key())` — the tagged path | **0.028** |
| `hash_columns_keyed(.., None)` — same body, no key | 0.028 |
| `hash_columns` — the legacy body with BLAKE3's one-shot fast path | 0.027 |

**Keying costs +0.9%: nothing.** The memo is right that the keyed body cannot
use `blake3::hash`'s fast path and builds a hasher per column — and it is
worth under 1% of a phase that is itself 13% of the commitment. The unkeyed
keyed-body and the legacy body are asserted equal digest for digest, and the
keyed one asserted different, so the three are really the three.

**Consequence for the device plan: the keyed mode is not what the column
hash costs.** The reason a keyed CUDA hasher is not worth building first is
not that keying is expensive; it is that *all* the column hashing, keyed or
not, is 13-14% of a commitment.

---

## 6. The answer, and what it means for DC-G

**(a) The encode is the larger half, by about 3.7 to 1, at both shapes.**
DC-G(1)'s stated condition is met. Restating the 125M commitment as shares:
encode 51%, allocate-and-zero 35-39%, column hashing 13-14%, everything else
(pads, salts, powers, salted leaves, all 65,535 inner nodes) under 2%.

A device path that **encodes on the device and hashes on the host** addresses
the 51% (and can address most of the 35-39% too — see (b)) **with no keyed
kernel, no keyed mode and no new key on the device**. A keyed CUDA column
hasher, the item the memo scoped first, addresses **13-14% of a commitment =
about 0.8 s of a 5.78 s commit-commitment total = under 5% of the 17.4 s
prove**. On this measurement **the keyed-CUDA question moves down the list,
exactly as the ruling anticipated.**

Two caveats the integrator owns, neither of which this page measured:

* Today's device entry point (`Backend::try_commit_zk`, and hashline's
  `dev_commit_zk_from`) returns **leaves**, not the encoded matrix: it does
  the encode *and* the hash. "Encode on the device, hash on the host" is a
  **new** entry point that returns the encoded buffer, not a flag on the old
  one.
* It must then move 2.98 GB (`A`) or 3.73 GB (`H`) back across PCIe per
  commitment. At a nominal 10 GB/s that is ~0.3-0.4 s [MODEL, not measured
  here, no GPU was touched] against the 1.27-1.63 s of encode it removes.
  **Whether the arithmetic closes is a measurement nobody has taken**, and it
  should be taken before the kernel is written, for the same reason this page
  exists.

**(b) A second result the brief did not ask for: about 9.5% of every
commitment is dead work, on the host, with no device involved.**

`commit_zk_owned_with_tag` allocates its encoded matrix as
`vec![Fp::ZERO; rows · nn]`. `Fp` is a user struct, so the standard library's
`alloc_zeroed` specialisation does not apply and every one of the
`rows · nn` elements is written with a zero — 2.98 GB for `A`, 3.73 GB for
`H`. `encode_row_zk` then **overwrites every element of every row** before it
transforms (`pcs.rs:661-664`: `out[..n]` copied from the coefficients,
`out[n..]` assigned `Fp::ZERO`, then `ntt.forward(out)` writes the whole
row). The zeros are never read.

That is an argument from reading the source, so the module **proves it
instead**: `stage05_the_zeroing_is_dead_work` encodes the same rows into a
zeroed buffer and into a buffer pre-filled with `0xA5A5…` and asserts the two
outputs equal. They are.

Timing part 3 twice — once cold and once on pages already faulted in —
splits its cost:

| | `A` at 125M | `H` at 125M |
|---|---:|---:|
| part 3, cold (page faults **and** zero stores) | 0.882 s | 1.226 s |
| the zero stores alone | **0.237 s** | **0.302 s** |
| the page faults (not recoverable: they move into the encode) | 0.645 s | 0.924 s |

So **deleting the zeroing recovers about 0.54 s per 125M block** (0.237 +
0.302, plus a millisecond at the endpoints) — 9.3% of the block's 5.78 s of
commitments, 3.1% of the 17.4 s prove — for a change confined to one
allocation in `pcs.rs`, with no device, no kernel and no protocol
consequence. It is the cheapest second on the whole device page.

The other 1.57 s per block is page faults, and those are only avoidable by
**reusing** the encoded buffers across blocks rather than freeing and
re-faulting them (note that `MALLOC_MMAP_THRESHOLD_=131072`, which the lane
pins, *forces* every one of these buffers through `mmap`/`munmap` and so
guarantees the re-fault). Within one block `A` and `H` are both live to the
opening, so a pool needs two buffers of `max(rows) · nn · 8` = 3.48 GiB each,
which collides with the resident-set budget of §3 of the memo. **That is a
design question for the integrator's run driver, alongside DC-G(2)'s
cross-layer pipelining, and this page does not recommend it — it only prices
it at about 1.57 s per block.**

**(c) The Merkle layer is not worth a line of device code, in seconds as
well as in counts.** §2.2 counted the tree at 0.23% of the compressions; it
measures at **0.6-1.0% of a 125M commitment** and 2.0% of the block's five
commitments. The one place it is not negligible is the **endpoints**, where
it is 56-71% of the (tiny) whole, because 37 rows still need 65,536 salts and
a 16-deep tree.

---

## 7. What this is NOT

* **One box, one thread count, one process.** WSL2 laptop, 22 rayon threads,
  shared and **not quiesced** (the standing rule: wall-clock ladders taken
  now are polluted; ~2x run-to-run variance has been measured on this box).
  Every number is min / median / max over three repetitions and nothing here
  extrapolates to another shape or another machine.
* **Synthetic rows, never a witness.** Rows come from a fixed-seed
  `splitmix64` stream. The cost of a Goldilocks NTT and of a BLAKE3 pass over
  a byte buffer does not depend on the values in them, and the control
  `stage05_rung_w14_value_control` measures that directly: uniform rows
  encode within **+1.6%** of byte-like rows (the shape a real `A` plane
  has). If anything uniform rows are the *conservative* choice for the encode
  half. No witness and no private value was generated, logged or committed.
* **No GPU.** `HL_GPU` unset, the `gpu-cuda` feature off, no device touched.
  Nothing on this page is a claim about a GPU, and the ~0.3-0.4 s PCIe figure
  in §6(a) is arithmetic, marked [MODEL], not a measurement.
* **No production change, and no protocol claim.** One `#[cfg(test)]`
  module, registered under `#[cfg(test)]`. No security, privacy or soundness
  property is asserted, affirmed or affected. The dead-zeroing finding of
  §6(b) is a **finding**, not a patch: nothing was changed.
* **Not a receipt.** These are diagnostics, like the `PB-TIMING` lines they
  are compared with.

## Test names

| test | filter |
|---|---|
| rung-W14, the full split | `private_block::stage05_commit_split::stage05_commit_split_rung_w14` |
| 125M, the full split (**`#[ignore]`d, heavy**) | `private_block::stage05_commit_split::stage05_commit_split_m125` |
| keyed against unkeyed against legacy hashing | `private_block::stage05_commit_split::stage05_rung_w14_keyed_vs_unkeyed_hash` |
| the value control | `private_block::stage05_commit_split::stage05_rung_w14_value_control` |
| the zeroing is dead work | `private_block::stage05_commit_split::stage05_the_zeroing_is_dead_work` |

Light (ordinary filter, about 5 s):

```
flock -w 1800 /tmp/zk-build.lock env CARGO_TARGET_DIR=/home/victor/wt-zk60-attention-compile/hashline/target \
  CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 MALLOC_MMAP_THRESHOLD_=131072 \
  /home/victor/.cargo/bin/cargo test --release --offline -j 2 \
  --manifest-path /home/victor/wt-zk60-block125m-review/hashline/Cargo.toml --lib stage05 -- --test-threads=1 --nocapture
```

Heavy (detached, one commitment at a time, peak 4.44 GiB):

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0 \
  env MALLOC_MMAP_THRESHOLD_=131072 <test binary> --ignored --exact --nocapture --test-threads=1 \
  private_block::stage05_commit_split::stage05_commit_split_m125 >> <log> 2>&1; echo $? > <log-stem>.done' >/dev/null 2>&1 &
```
