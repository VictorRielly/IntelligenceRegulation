# ZK60 — conformance vectors for the row encode (the seed of the device harness)

**Written 2026-09-22 13:58 PDT, lane `perf/zk-batch-optimizations`.** Produced
by a THIRD implementation of `encode_row_zk` (`results/zk60_encode_vectors/encode_ref.py`),
written from the Rust source read read-only in the lane worktree
`/home/victor/wt-zk60-block125m` at `a8e4939`. Nothing on this page is a
timing measurement.

Labels: **[COUNTED]** = read off the source text; **[COMPUTED]** = produced by
the script above, reproducible by re-running it; **[MEASURED]** = from a
committed log, with its path.

**Why this exists.** Stage 0.5 measured that the hiding commitment's CPU time
is the row ENCODE, not the column hashing — 3.7 : 1 at 125M and at rung-W14
([MEASURED], `/home/victor/wt-zk60-block125m-review/results/zk60_stage05_commit_split/LEDGER.md`,
read-only; ruled in `ZK60_HIDING_COMMITMENT_ON_DEVICE_DISPOSITION.md`, DC-G(1)).
So the device target inside the commitment is the NTT, and the byte trap the
design memo (§1, "the four ways a device NTT gets this wrong while still
looking right") and its check (§2, "the headline trap") both named is the
transform's ORDERING. A device encode is byte-identical to the CPU's iff it
reproduces the exact output vector; the verifier sees 256 of 65,536 columns,
so a conformance harness is the only total check.

---

## 0. What this is, in one paragraph

A fixed set of 35 inputs to `encode_row_zk` and the encoded row each one must
produce, at the row widths the project actually uses, together with five
deliberately WRONG implementations and the digest each of those produces. A
device (GPU) encode passes iff it reproduces all 35 rows entry for entry. If
it fails, the digest it produced is looked up in the control table and names
the bug. The vectors come from an implementation that has never executed the
Rust: it was written from the source text and validated against the DEFINITION
of the transform (direct O(n²) evaluation at the roots of unity, and a
closed-form Lagrange basis at the production widths), so agreeing with the
Rust is evidence, not a tautology.

Files, all committed:

| path | what |
|---|---|
| `results/zk60_encode_vectors/encode_ref.py` | the third implementation, its self-checks, the generator, the cross-check |
| `results/zk60_encode_vectors/vectors.json` | the 35 vectors: inputs, digests, probe entries |
| `results/zk60_encode_vectors/full_rows.json` | the FULL encoded row for every vector with `nn ≤ 2048` |
| `results/zk60_encode_vectors/negative_controls.json` | the five wrong encodes at three widths |
| `results/zk60_encode_vectors/capture_crosscheck.json` | the check against committed capture bundles |
| `results/zk60_encode_vectors/SELFCHECK.log` | the run that produced all of the above |
| `results/zk60_encode_vectors/rust_test_listing.rs` | §6's listing as a droppable file |

---

## 1. The constants, with `file:line` [COUNTED]

All paths below are `zkp-core/src/…` in `/home/victor/wt-zk60-block125m` at
`a8e4939`.

| thing | value | source |
|---|---|---|
| the field | `p = 2^64 − 2^32 + 1 = 0xFFFF_FFFF_0000_0001` | `field.rs:10` |
| multiplicative generator | `7` | `field.rs:13` |
| two-adicity | `32` | `field.rs:16` |
| the root of unity of order `2^k` | `two_adic_root(k) = (7^((p−1) >> 32))^(2^(32−k))` | `field.rs:81-86` |
| the pinned order-2^32 root | `1753635133440165772` | `field.rs:305` (the crate's own test) |
| extension (not used by the encode) | `F_p[u]/(u² − 7)` | `field.rs:15,163` |
| the twiddle table | ONE shared table of `max_n/2` powers of `ω_{max_n}`, built by repeated multiplication from `1` | `ntt.rs:29-42` |
| twiddle indexing | `tw[k · (max_n / len)]`, `max_n = 2^max_log` of the SHARED table, not of this transform | `ntt.rs:89,93,98` |
| **bit-reversal side** | on the **INPUT**, in place, before the butterflies; the output is in **NATURAL order** | `ntt.rs:76-87` then `:91-107` |
| butterfly | decimation-in-time: `lo = u + v·w`, `hi = u − v·w` | `ntt.rs:96-103` |
| inverse scaling | `× Fp::new(n).inv()` with `n = a.len()` — the size of THAT transform — applied **after** the transform | `ntt.rs:60-67` |
| the coset generator | `h = Fp::new(7)` (`ZkOpts::standard`) | `pcs.rs:580` |
| the coset powers | `pows[i] = h^i`, `i < nn`, by repeated multiplication; asserts `h^nn ≠ 1` | `pcs.rs:642-651` |
| `Q` (pad symbols per row) | `q_pad = num_col_checks = 256` in every production profile | `pcs.rs:580`, `shape.rs:51` |
| column index ↔ transform index | column `j` of the row-major encoded matrix is the natural-order output index `j`; **no permutation sits between the transform and the hashed column layout** | `pcs.rs:157-175`, `:182-202`, `:732-737`, `:789-794` |

**The composition, `encode_row_zk` (`pcs.rs:655-674`)** — and the answer to
"where does the pad go":

| step | operation | line |
|---|---|---|
| 5a | `coeffs = msg.to_vec()` | `:660` |
| 5b | `ntt.inverse(&mut coeffs)` — ONE inverse NTT of size `n` | `:661` |
| 5c | `out[..n] = coeffs`, `out[n..] = 0` | `:662-665` |
| 5d | for `i < Q`: `out[i] −= pad[i]`; `out[n+i] = pad[i]` | `:666-669` |
| 5e | for `i < n+Q`: `out[i] *= pows[i]` | `:670-672` |
| 5f | `ntt.forward(out)` — ONE forward NTT of size `nn` | `:673` |

**The pad is NOT appended to the message and is NOT a separate transform.** It
is mixed into the COEFFICIENT vector between the two transforms: 5d writes
`f = f_data + Z_n · g_pad` with `Z_n(x) = x^n − 1`, the pad coefficients
negated at degrees `0..Q` and positive at degrees `n..n+Q`. 5e is the coset
shift, so 5f evaluates `f` at `h · ω_nn^j`, `j` the natural index. Exactly two
transforms per row.

**The row widths that actually occur** [COUNTED], from the layouts:

| profile | `log_cols` | `inv_rate` | `nn` | source |
|---|---:|---:|---:|---|
| the toy (the only shape that proves anything today) | 8 | 8 | 2^11 | `hashline/src/private_block/shape.rs:432` |
| the frozen seam (both endpoints of the toy and the rung) | 8 | 8 | 2^11 | `hashline/src/private_seam.rs:28,30` |
| the rungs (rung, rung-G, rung-K4, rung-P2, rung-C6, rung-E32) | 10 | 4 | 2^12 | `shape.rs:441,486,546,609,684,825` |
| **rung-W14** | 14 | 4 | **2^16** | `shape.rs:763-781` |
| **125M** | 14 | 4 | **2^16** | `shape.rs:861` |

2^3, 2^4 and 2^6 are not profile widths; they are the definitional sizes at
which the reference is checked against a direct O(n²) evaluation and at which
a device team can print a whole row. The vectors carry both kinds.

---

## 2. The third implementation, and how it is validated [COMPUTED]

`encode_ref.py` is exact integer arithmetic modulo `p` in Python ints — no
floating point anywhere, no dependency outside the standard library. It
re-derives the roots from the generator rather than copying a constant, and it
reproduces the Rust's *incremental* bit-reversal loop rather than a library
permutation.

It is validated against the DEFINITION, not against a transcription of the
Rust. The full run is `results/zk60_encode_vectors/SELFCHECK.log` (exit 0, all
PASS, 2026-09-22):

| check | what it proves |
|---|---|
| **S1** | `p`, the generator, `two_adic_root(k)` has exact order `2^k` for `k ≤ 20`, and the crate's own pinned values (`two_adic_root(32) = 1753635133440165772`, `two_adic_root(1) = p−1`) |
| **S2** | the forward transform equals a direct O(n²) Horner evaluation of the coefficient polynomial at `ω^i`, for `n = 1, 2, 4, 8, 16, 64` |
| **S3** | the inverse equals a direct interpolation `c_i = (1/n) Σ_j v_j ω^{−ij}` — i.e. the `1/n` is by that transform's own size and lands after the butterflies — plus the round trip |
| **S4** | the SHARED table's `max_log` changes no output: the same row over `max_log ∈ {log n, log n + 1, 10, 16}` agrees. (This is what makes `tw[k·(max_n/len)]` a stride and not a constant, and it is why a device may precompute per-size tables — provided it lands on the same values.) |
| **S5** | the zero-padded forward is evaluation at the `nn`-th roots (the property `ntt.rs:157-170` asserts of itself) |
| **S6** | **the whole encode equals `f_data + Z_n · g_pad` evaluated point by point on the coset**, with no NTT on the reference side, at `(n, rate, Q)` = (8,4,4), (16,4,8), (64,4,32), (64,8,64); and the coset is disjoint from `G_n` at each — no systematic column |
| **S7** | interpolate-then-evaluate returns the message (the 5b convention) |
| **S8** | the decimation-in-frequency control really is the SAME transform with its output permuted: `dif(x) == bitrev(dit(x))` at `n = 2^3, 2^4, 2^6, 2^8` |
| **S9** | **at the PRODUCTION widths** (2^8 rate 8, 2^10 rate 4, **2^14 rate 4**) the encode of a unit message `e_k` equals the closed-form Lagrange basis `L_k(x) = ω^k (x^n − 1) / (n (x − ω^k))` evaluated on the coset — no NTT, at `nn = 2^16` |
| **S10** | the PAD path by direct evaluation: with a zero message the encoded row is `Z_n(x) · g_pad(x)` — all 2,048 positions at 2^8 rate 8, 128 sampled positions at 2^14 rate 4 |

S6, S9 and S10 are the ones that matter: they check the composition, not the
butterflies, and S9/S10 do it at the width the device work targets.

---

## 3. The vectors [COMPUTED]

35 vectors: 7 `(width, rate)` profiles × 5 message/pad kinds.

**The profiles** (Q is the pad count; at the small widths Q is reduced so that
`n + Q ≤ nn`, the assertion at `pcs.rs:659`):

| `n` | rate | `nn` | Q | what it is |
|---:|---:|---:|---:|---|
| 2^3 | 4 | 2^5 | 4 | definitional; printable by hand |
| 2^4 | 4 | 2^6 | 8 | definitional |
| 2^6 | 4 | 2^8 | 32 | definitional |
| 2^8 | 4 | 2^10 | 256 | the toy's row width at the rungs' rate |
| **2^8** | **8** | **2^11** | 256 | **the toy and the frozen seam** |
| **2^10** | **4** | **2^12** | 256 | **the rungs** |
| **2^14** | **4** | **2^16** | 256 | **rung-W14 and 125M** |

**The kinds.** `zero` (all-zero message and pads — the encoded row is all
zero); `zero_msg_seeded_pad` (zero message, seeded pads — isolates the pad
path, 5d/5e/5f); `delta0` (a single 1 at index 0); `delta_last` (a single 1 at
index `n−1`); `seeded` (both the message and the pads from the PRNG).

**The PRNG**, so anyone can regenerate the inputs in any language: SplitMix64
with `γ = 0x9E3779B97F4A7C15`, the two standard mix constants
`0xBF58476D1CE4E5B9` and `0x94D049BB133111EB`, final `z ^= z >> 31`; a field
element is one `next_u64()` reduced mod `p`; the seed is
`(0x5A5A5A5A << 32) | (log_n << 16) | (inv_rate << 8) | role`, role 1 =
message, 2 = pad. **The pads are FIXED SYNTHETIC values**, not the prover's:
the prover draws them from `ZkRng` before any branch (`pcs.rs:777`,
`rng.rs:73-77`). The pad DRAW is not part of this contract; the pad's
PLACEMENT is.

**What is stored.** Full input arrays inline for `n ≤ 1024`; for 2^14 the
generation rule plus the SHA-256 of the inputs' little-endian bytes (so a
reader who regenerates them can confirm they have the right array before
blaming the encode). Full encoded rows for `nn ≤ 2048`, in `full_rows.json`.
For every vector: the SHA-256 of the encoded row, its first 8 and last 8
entries, and the entries at indices `1`, `nn/2` and `nn − 1`.

**The digest rule.** SHA-256 over the row's entries, **8 little-endian bytes
each, in natural column order** — the same byte order the column hashing feeds
BLAKE3 (`field.rs:88-90`, `pcs.rs:150`).

A sample of the digests (all 35 are in `vectors.json` and in §6's listing):

| vector | `n` | rate | `nn` | Q | SHA-256 of the encoded row |
|---|---:|---:|---:|---:|---|
| w3r4-seeded | 8 | 4 | 32 | 4 | `ae6ff4f286d0821a33eb0a4a51da60e4677f2a248734ca9935f13a3b8d2901ec` |
| w6r4-seeded | 64 | 4 | 256 | 32 | `36b00bbf2c8ffa5e222993e8cd8dc86be05f3cd955e07a58b84e1c499f022142` |
| w8r8-seeded | 256 | 8 | 2048 | 256 | `a9bc48623fe6e9b28e97770180eef5f6b926efdcdfc175a94a9b5446e847f92e` |
| w10r4-seeded | 1024 | 4 | 4096 | 256 | `de6980b6d74c1024f3ee9dadeb5bc02be843379c3cbf8018251a1880b3b18c0a` |
| **w14r4-seeded** | 16384 | 4 | **65536** | 256 | **`bf144694ffbd31733ee32a4de9f5c1f8bd50a1f4b568dc95dec5c595ab9733c1`** |
| w14r4-delta0 | 16384 | 4 | 65536 | 256 | `6dbf41b067a4d01fe0a913eec0bd6c8986afc090ac7e7490fb0b193f38137baa` |

The 2^14 `seeded` row's probe entries, the ones an ordering bug moves:
index 0 → `3655851916429667015`, index 1 → `3177249528031755686`,
index 2^15 → `15144069108932809041`, index 2^16 − 1 → `4160362776790354634`.

---

## 4. The cross-check against the Rust

**There is no Rust harness yet and this lane cannot build one** (no Rust
builds in this brief). So the vectors are, strictly, an independent PREDICTION
of what `encode_row_zk` produces. Two things were done about that.

### (a) What a capture bundle cannot give, and why

A capture bundle carries, per commitment, the 256 OPENED columns — real
encoded values the Rust prover wrote — but not the rows they came from: the
messages are private, and the pads are drawn from `ZkRng` and never recorded.
Recomputing a column from the bundle is therefore impossible, and no full
encoded row appears anywhere in committed evidence. Solving for the pads does
not help either: `q_pad = num_col_checks = 256`, so 256 opened columns against
256 unknown pad coefficients is an exactly determined system with no residual
— any implementation, right or wrong, "fits". The toy statement's receipt is
byte-frozen but its rows are equally private.

### (b) What a capture bundle CAN give, and what it says [COMPUTED]

The verifier's own column identity is checkable. For every opened column `j`
(`pcs.rs:1100-1145`):

```
  sum_i rho_i · encoded[i][j]  ==  Enc(prox_vec)[j]
```

where `prox_vec` is the CLEAR proximity combination the prover sends (`n`
message entries then `Q` pad entries, in `F_p²`), `rho` its row weights, and
`Enc` is `encode_row_zk` applied to the real and imaginary parts separately.
Both `prox_vec` and `rho` are in the bundle, and so are the 256 columns.
Running **this reference's** encode on `prox_vec` and comparing is a real test
of the reference against bytes the Rust prover wrote.

Result, over the four committed capture bundles in
`results/zk60_native_captures_20260919/captures/` (the toy and the private
attention block, `log_cols 8`, `inv_rate 8`, `nn = 2048`): **16
role-commitments, 256 of 256 opened columns agreeing in every one**
(`results/zk60_encode_vectors/capture_crosscheck.json`).

It is not vacuous. The same check run with each wrong encode, on the first
role (`A`, 455 rows): the conjugate root, the off-by-one stride, the 1/nn
inverse and the `tw[k]` stride agree at **0 of 256** columns; the
decimation-in-frequency ordering agrees at **10 of 256** — the opened columns
that happen to be fixed points of the bit-reversal permutation (at `nn = 2^11`
there are 2^6 = 64 of them among 2,048, so ≈8 of 256 opened columns are
expected to survive an ordering bug). **That 10/256 is the whole argument for
this harness**: the ordering bug is the one the running system is least able
to see.

What this cross-check does NOT cover: the widths above 2^8 (no committed
bundle exists at `log_cols` 10 or 14), and the 99.6% of columns a bundle never
opens.

### (c) The first Rust test of the harness is owed

§6 is the exact test. It belongs on the review branch as
`zkp-core/src/pcs/encode_conformance_tests.rs`. It is **written but not
compiled** — this brief allows no Rust builds — so the lane that drops it in
should expect to fix nothing more than an import, and must treat a *value*
mismatch as a finding against these vectors, not against the crate, until it
is investigated.

---

## 5. The negative controls [COMPUTED]

Five wrong implementations of the encode, each at three widths. They exist so
that a failing device implementation is not merely "wrong" but NAMED.

| # | the bug | what a device does to earn it |
|---|---|---|
| (a) | `dif_output_order` | a decimation-in-frequency (Gentleman–Sande) NTT that returns its output BIT-REVERSED — every value right, every column at the wrong index (S8 proves this control is exactly `bitrev(correct)`) |
| (b) | `conjugate_root` | the other two-adic root: forward and inverse twiddle tables swapped (`ω^{−1}` where the CPU uses `ω`) |
| (c) | `stride_off_by_one` | `tw[k·(max_n/len) + 1]` instead of `tw[k·(max_n/len)]` |
| (d) | `inverse_scaled_by_nn` | the inverse NTT of 5b scaled by `1/nn` instead of `1/n` |
| (bonus) | `stride_one` | the SHARED max-size table indexed as if it were a per-size table: `tw[k]` |

At **2^14 → 2^16**, on the `seeded` vector (correct row
`bf144694ffbd31733ee32a4de9f5c1f8bd50a1f4b568dc95dec5c595ab9733c1`):

| bug | SHA-256 of the wrong row | entries differing from correct |
|---|---|---:|
| (a) dif_output_order | `43c5b6d188567aebcae48fbb137290deed3a3423e1c1eacc8983f153dfce05a0` | 65,280 / 65,536 |
| (b) conjugate_root | `6abd622c06b9c742d7f0ad07ebfa49c6194c192ac7d3638b39ae1525cf2bafa6` | 65,536 / 65,536 |
| (c) stride_off_by_one | `630836315e82f365f48e55de9bcc3267a047941cec0b079ff6850b6288385afd` | 65,536 / 65,536 |
| (d) inverse_scaled_by_nn | `de18aaaf03ec8167ed1234de92b484ea4768228734978615ee0f43d231621b73` | 65,536 / 65,536 |
| (bonus) stride_one | `5c9b895cc6bbda95d410e6b2154591dd1430cd2a4d6c15b203a4818e3f4fb147` | 65,536 / 65,536 |

Five distinct digests, all distinct from the correct one. The same table at
2^6 → 2^8 and 2^3 → 2^5 is in `negative_controls.json` and in §6's listing;
a device team debugging at 2^3 can print the 32-entry wrong row and see it.

The 65,280 in row (a) is the count that says what the ordering bug is: the
bit-reversal permutation on 2^16 points fixes 2^8 = 256 of them, and
`65536 − 256 = 65280`. **A DIF device NTT produces 256 correct columns out of
65,536, and the protocol opens 256 columns at random.**

---

## 6. The Rust test the lane drops in

Same text as `results/zk60_encode_vectors/rust_test_listing.rs`. Drop in as
`zkp-core/src/pcs/encode_conformance_tests.rs` and add
`#[cfg(test)] mod encode_conformance_tests;` beside `mod backend;` in
`zkp-core/src/pcs.rs`. `sha2 = "0.10"` is already a dependency of the crate
(`zkp-core/Cargo.toml`), so nothing new is pulled in. Written, not compiled.

```rust
use super::*;
use crate::field::P;
use crate::ntt::NttTables;
use sha2::{Digest as _, Sha256};

struct SplitMix64(u64);

impl SplitMix64 {
    fn new(seed: u64) -> SplitMix64 { SplitMix64(seed) }
    fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn fp(&mut self) -> Fp { Fp::new(self.next_u64() % P) }
    fn fp_vec(&mut self, n: usize) -> Vec<Fp> { (0..n).map(|_| self.fp()).collect() }
}

fn seed_for(log_n: u32, inv_rate: usize, role: u64) -> u64 {
    (0x5A5A_5A5Au64 << 32) | ((log_n as u64) << 16) | ((inv_rate as u64) << 8) | role
}

fn sha256_hex(row: &[Fp]) -> String {
    let mut h = Sha256::new();
    for v in row { h.update(v.to_bytes()); }
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

const KIND_NAMES: [&str; 5] = ["zero", "zero_msg_seeded_pad", "delta0", "delta_last", "seeded"];

fn inputs(kind: usize, log_n: u32, inv_rate: usize, q: usize) -> (Vec<Fp>, Vec<Fp>) {
    let n = 1usize << log_n;
    match kind {
        0 => (vec![Fp::ZERO; n], vec![Fp::ZERO; q]),
        1 => (vec![Fp::ZERO; n], SplitMix64::new(seed_for(log_n, inv_rate, 2)).fp_vec(q)),
        2 => { let mut m = vec![Fp::ZERO; n]; m[0] = Fp::ONE; (m, vec![Fp::ZERO; q]) }
        3 => { let mut m = vec![Fp::ZERO; n]; m[n - 1] = Fp::ONE; (m, vec![Fp::ZERO; q]) }
        _ => (
            SplitMix64::new(seed_for(log_n, inv_rate, 1)).fp_vec(n),
            SplitMix64::new(seed_for(log_n, inv_rate, 2)).fp_vec(q),
        ),
    }
}

/// `(log_n, inv_rate, Q, the five encoded-row SHA-256s in `KIND_NAMES` order)`.
#[allow(clippy::type_complexity)]
const PROFILES: &[(u32, usize, usize, [&str; 5])] = &[
    (3, 4, 4, [
        "5341e6b2646979a70e57653007a1f310169421ec9bdd9f1a5648f75ade005af1",
        "99f1f74e60240b0adf5e8ebc78b6286ed1945d4562c71696a5c6bbac40af88fe",
        "f58fae79ec4f1c800a5f1f85af09d0dfde316a3cbec42ad33daa7aadb938226b",
        "359e2ccb1fd3979e59a83f532d68e93c6d46686459b6e0fd9b42a763f2714378",
        "ae6ff4f286d0821a33eb0a4a51da60e4677f2a248734ca9935f13a3b8d2901ec",
    ]),
    (4, 4, 8, [
        "076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560",
        "c1fe92e7e2f490be445806acdfe432cc86415d14d3c1479bb41c8bb11d3ee244",
        "62576d7a3aecba7154e698142d62a4e3cc065d22e1553c3fad7b78ac340a18e9",
        "4bd8d9b21bdee39e8ad85d3275243a3bce50714f5d5c780634ccf78f91bec9a9",
        "abdc63baa7193eef169aeb28fa428dda73292ddf2b310794395b4f28722fbdf7",
    ]),
    (6, 4, 32, [
        "e5a00aa9991ac8a5ee3109844d84a55583bd20572ad3ffcd42792f3c36b183ad",
        "1ad55ef90c11c871a73a49a14df45019e8f87893dc29cbaef9fe562dac8b2f4f",
        "21f9ee42e9567b32f61239e12d7402aa2bcdd1b56b4a60ce41d1644bf1b48f2e",
        "f7dc54e71171f8986e2042357c0442eb6f391153ec30c4fceff803400031041e",
        "36b00bbf2c8ffa5e222993e8cd8dc86be05f3cd955e07a58b84e1c499f022142",
    ]),
    (8, 4, 256, [
        "9f1dcbc35c350d6027f98be0f5c8b43b42ca52b7604459c0c42be3aa88913d47",
        "e12602065c6fc4afe04074d3ec0219284a11955d8a83ed9e63f93a80ea05fe8b",
        "0664aa45965f0b601ea2660dc2efe6cefc391cad59629451a2c2b4e3cbc80b72",
        "27214b6c51d8e742c63ec57414156eb41c1ec7be278b6dfbbcec0f14b10f3c7f",
        "70b22dff4b214ced7dc194783a721c705e76613abe3a9b1ad8c68a481c02e568",
    ]),
    (8, 8, 256, [
        "4fe7b59af6de3b665b67788cc2f99892ab827efae3a467342b3bb4e3bc8e5bfe",
        "50dfde443ed404e537cb07fee949d438bd07be7d6cc2784ef955afd50d78394a",
        "a16a54b8383285a9a76b5a94536d7dbc6475604c12d26ab16cad061d6234a5b9",
        "6c0721d2b0a5e68c1fe990eba8e74941f3067d0888d34ba101e18c67f77292c2",
        "a9bc48623fe6e9b28e97770180eef5f6b926efdcdfc175a94a9b5446e847f92e",
    ]),
    (10, 4, 256, [
        "c35020473aed1b4642cd726cad727b63fff2824ad68cedd7ffb73c7cbd890479",
        "70e6389c73652494e8d04e3984fe8953e788569694a7bfdf2ad502f8f72a5074",
        "bddd26c474a25ab21e413c8cfa3817f44349f3fb9a98c213004789ec616d57f4",
        "aa2f7061e1cd15aa06b4d0ff9fd973fb1a73ef622c1660d38be70cd0b3c3e098",
        "de6980b6d74c1024f3ee9dadeb5bc02be843379c3cbf8018251a1880b3b18c0a",
    ]),
    (14, 4, 256, [
        "07854d2fef297a06ba81685e660c332de36d5d18d546927d30daad6d7fda1541",
        "429e9b5db72a44c4d573f863a06e5d788934b21a3507225464e88c88dc106052",
        "6dbf41b067a4d01fe0a913eec0bd6c8986afc090ac7e7490fb0b193f38137baa",
        "79f2366701d3871ec33fa7829b5d0d94cb4068c85c6f9e32f712cc35e7d9024b",
        "bf144694ffbd31733ee32a4de9f5c1f8bd50a1f4b568dc95dec5c595ab9733c1",
    ]),
];

/// A digest here is a NAMED BUG, not a random mismatch: the `seeded` vector's
/// wrong rows at 2^14 -> 2^16, 2^6 -> 2^8 and 2^3 -> 2^5.
const CONTROL_DIGESTS: &[(&str, &str)] = &[
    ("43c5b6d188567aebcae48fbb137290deed3a3423e1c1eacc8983f153dfce05a0",
     "w14: (a) decimation-in-frequency -- your final NTT returns BIT-REVERSED output"),
    ("6abd622c06b9c742d7f0ad07ebfa49c6194c192ac7d3638b39ae1525cf2bafa6",
     "w14: (b) the conjugate two-adic root -- forward and inverse twiddles swapped"),
    ("630836315e82f365f48e55de9bcc3267a047941cec0b079ff6850b6288385afd",
     "w14: (c) an off-by-one twiddle stride -- tw[k*(max_n/len) + 1]"),
    ("de18aaaf03ec8167ed1234de92b484ea4768228734978615ee0f43d231621b73",
     "w14: (d) the inverse NTT scaled by 1/nn instead of 1/n"),
    ("5c9b895cc6bbda95d410e6b2154591dd1430cd2a4d6c15b203a4818e3f4fb147",
     "w14: (bonus) the shared max-size twiddle table indexed as a per-size table, tw[k]"),
    ("975a2b6eb272c06d84719faade776e555962816d9029178eaffaaad25226682f",
     "w6: (a) decimation-in-frequency (bit-reversed output)"),
    ("b509d53ba1d7c22e7525f30defdb2c4b6532b488efcb321e1daa6e4e51d20806",
     "w6: (b) the conjugate two-adic root"),
    ("1df89df5af5f4e0b3a110d109b72d4b6260ce79ab1d088fc583f79c332538327",
     "w6: (c) an off-by-one twiddle stride"),
    ("04c150e35b0faecc01af4b7b1e8af280c46c56ca589bc850b6f2c688cd4bfced",
     "w6: (d) the inverse NTT scaled by 1/nn"),
    ("5ffb585b01b46729508d0abc190b5affce4f6d4f552dc56095da2109d50f8cc8",
     "w6: (bonus) tw[k] instead of tw[k*(max_n/len)]"),
    ("5ada7fa09a9272e8b86a2a779dd9b0894a2965a6c94c56859b4ecb1e5633719b",
     "w3: (a) decimation-in-frequency (bit-reversed output)"),
    ("a13c24bf7eefe7138ec0618d3ceeb195f5fb7b5df9fa22923052accd7f40a349",
     "w3: (b) the conjugate two-adic root"),
    ("f41a39821ba0c89e0c1a5f6af106fd5585f87ac19c8561c31dbb9075724f5495",
     "w3: (c) an off-by-one twiddle stride"),
    ("a8dc9a8c515839ce561c709c1839a61a4a801c6f47eac9de7f94bc53db9b56a7",
     "w3: (d) the inverse NTT scaled by 1/nn"),
    ("f50360b21ff79bedf887e6c18cd5032f4c64be3fa1d4c354f8335e70513e9798",
     "w3: (bonus) tw[k] instead of tw[k*(max_n/len)]"),
];

fn diagnose(digest: &str) -> String {
    for (d, why) in CONTROL_DIGESTS {
        if *d == digest {
            return format!(" -- THIS IS A KNOWN NEGATIVE CONTROL: {why}");
        }
    }
    String::new()
}

fn encode(log_n: u32, inv_rate: usize, msg: &[Fp], pad: &[Fp]) -> Vec<Fp> {
    let n = 1usize << log_n;
    let nn = n * inv_rate;
    let ntt = NttTables::new(nn.trailing_zeros());
    let pows = coset_powers(Fp::new(7), nn); // ZkOpts::standard's coset
    let mut out = vec![Fp::ZERO; nn];
    encode_row_zk(&ntt, msg, pad, &pows, &mut out);
    out
}

/// THE CONFORMANCE TEST. 35 vectors over 7 (width, rate) profiles.
#[test]
fn encode_row_zk_matches_the_third_implementations_conformance_vectors() {
    for (log_n, inv_rate, q, digests) in PROFILES {
        for (kind, want) in digests.iter().enumerate() {
            let (msg, pad) = inputs(kind, *log_n, *inv_rate, *q);
            let got = sha256_hex(&encode(*log_n, *inv_rate, &msg, &pad));
            assert_eq!(
                got.as_str(), *want,
                "vector w{log_n}r{inv_rate}-{}{}",
                KIND_NAMES[kind],
                diagnose(&got)
            );
        }
    }
}

/// The inputs are pinned separately, so a PRNG disagreement is never reported
/// as an encode disagreement.
#[test]
fn the_conformance_inputs_are_the_ones_the_vectors_were_built_from() {
    let cases: &[(u32, usize, usize, &str, &str)] = &[
        (3, 4, 4,
         "e7bd29cbe88d69bed28d44a920ae975b5a1dc5b6ac631f4a1226c78130ed8885",
         "2f897fe5e06d30cbc8ca36b803ffcc6e962c6a0a06cbad7b90007c753b30fa65"),
        (8, 8, 256,
         "0b91544648a1c2c01ef1f1476a0e98fed0764d1b45b55e13ff474384f877ef13",
         "4a13cad453d750a2bd132012615415032c5be76914f37e8a9bb3b1d1f358116e"),
        (10, 4, 256,
         "b1dc9087eb68e96a1df8db6417ce5fc14d60d88d42c816c4024447210478764f",
         "97b537cd5009cdc2495b73f80235057f54a6bab147d31272aeb06591adbdab6c"),
        (14, 4, 256,
         "053da6d19072c3db3b190028a36c64bb750f5a3afe0303d978c7499736e7f1f4",
         "9e0a4b753a0930cf7bd121513d79b9dea7cc34adb01591fd77c4d0c4a3424086"),
    ];
    for (log_n, inv_rate, q, wm, wp) in cases {
        let (msg, pad) = inputs(4, *log_n, *inv_rate, *q); // 4 = `seeded`
        assert_eq!(sha256_hex(&msg).as_str(), *wm, "message of w{log_n}r{inv_rate}-seeded");
        assert_eq!(sha256_hex(&pad).as_str(), *wp, "pads of w{log_n}r{inv_rate}-seeded");
    }
}

/// The smallest vector in full, so a failure is debuggable by eye.
#[test]
fn the_smallest_conformance_vector_matches_entry_by_entry() {
    let (msg, pad) = inputs(4, 3, 4, 4);
    assert_eq!(
        msg.iter().map(|v| v.0).collect::<Vec<u64>>(),
        vec![
            13165580579705175456, 18210882911321197463, 11251177064544540234,
            3854080798751542840, 6950373697262493184, 1653300282129755443,
            11279950891899390549, 6180868182034427927,
        ],
        "the message the PRNG must produce"
    );
    assert_eq!(
        pad.iter().map(|v| v.0).collect::<Vec<u64>>(),
        vec![
            12958305900188953204, 12707502957647800691, 9025898841439606855,
            5612407619606071436,
        ],
        "the pads the PRNG must produce"
    );
    let got: Vec<u64> = encode(3, 4, &msg, &pad).iter().map(|v| v.0).collect();
    assert_eq!(
        got,
        vec![
            17001233229391541759, 9525882795350743510, 10685261833338387181,
            11883848538122421164, 12135637215749084494, 14487658604129027219,
            13956248148305193365, 728841911929532220, 17594403611113277726,
            13323381216430728279, 11952886996136697578, 15462680855146825542,
            6833670393533424550, 10031315790080029380, 17362465940490424173,
            1030025762374198429, 17562784682548004046, 3730969806722800446,
            6172047982576767076, 5693909200286625114, 1859001937226429571,
            15037052584695150825, 9672972197962433396, 1881927289116817088,
            18129160555214809121, 8351872777809323709, 15801800976565837046,
            11592350932643550688, 7886103473328438184, 13884731224812854872,
            11408272210597226156, 4027269886183593974,
        ],
        "the full encoded row at 2^3 -> 2^5"
    );
}

/// The entries an ORDERING bug moves, at the production width.
#[test]
fn the_ordering_probes_at_the_125m_row_width_are_pinned() {
    let (msg, pad) = inputs(4, 14, 4, 256);
    let enc = encode(14, 4, &msg, &pad);
    assert_eq!(enc[0].0, 3655851916429667015, "index 0");
    assert_eq!(enc[1].0, 3177249528031755686, "index 1");
    assert_eq!(enc[1 << 15].0, 15144069108932809041, "index 2^15");
    assert_eq!(enc[(1 << 16) - 1].0, 4160362776790354634, "index 2^16 - 1");
}
```

---

## 7. How the device team uses the harness

1. **Before writing a kernel**, read §1. The five constants that decide the
   bytes are the root, the twiddle indexing, the bit-reversal side, the
   inverse's `1/n`, and the coset. Three of them are invisible in any test
   that only checks "the codeword is a codeword".
2. **Wire the device encode to a tiny driver** that takes `(msg, pad, h, n,
   nn)` and returns the `nn` field elements. Run the 35 vectors. A device that
   passes all 35 reproduces the CPU encode on those inputs exactly.
3. **On a failure, take the SHA-256 and look it up** in §5 / `negative_controls.json`
   before debugging. Four of the five likely bugs are named on sight.
4. **Debug at 2^3 and 2^6**, where `full_rows.json` gives every entry, then
   move up. The widths are ordered so that the first failure is printable.
5. **Re-run the harness on every kernel change**, including changes that
   "cannot" affect the values (tiling, chunking, streams, a pool). Byte
   identity is the property; nothing else is being claimed.
6. **Regenerating the vectors** costs seven seconds:
   `python3 results/zk60_encode_vectors/encode_ref.py all` (stdlib only). The
   run rewrites the JSON and re-runs every self-check, so a vector cannot be
   edited by hand without the self-checks moving.

---

## 8. What this does NOT cover

The harness is the ENCODE, one row at a time. It says nothing about:

* **the pad DRAW** — that the pads are `rng.fp_vec(rows·Q)` drawn FIRST, before
  the salts and before any branch (`pcs.rs:777`, `rng.rs:73-77`). A device that
  encodes correctly from wrong pads passes this harness and produces a wrong
  commitment. That contract is §1 steps 1-2 of the design memo, and it needs
  its own vectors (the RNG's byte order);
* **the salts** (`pcs.rs:778`) and the salted leaf `H(digest ‖ salt)`;
* **the column digest** — the `rows·8` little-endian bytes per column and the
  keyed BLAKE3 recipe. Those have their own vectors, in the design check's
  keyed conformance seed (`ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN_CHECK.md`),
  and they are the other half of this harness;
* **the Merkle layer**, the tree's node hashing and the path order;
* **the opening** — the transcript order of the lambdas and the proximity rho
  (DC-3's correction);
* **privacy**. Nothing here is a statement about what the device leaks; that is
  the buffer review (DC-B).

A whole-commitment harness — the five commitments' roots at the small shapes,
CPU against device — is the natural next rung, and the encode vectors are its
first component.

## 9. What this is not

* **Not a measurement.** No timing number was taken on this lane. The 3.7 : 1
  encode-to-hash ratio quoted in the header is DC-G(1)'s, with its own log.
* **Not a Rust-verified artifact yet.** The vectors are a third
  implementation's prediction, validated against the definition and agreeing
  with the Rust everywhere a committed capture lets them be compared (§4b, 16
  role-commitments, 256/256 columns each, at one width). §6's test is the
  first Rust-side test and it has not been run.
* **Not the prover's randomness.** The pads here are synthetic fixtures with a
  stated seed. No conclusion about the prover's draws may be taken from them.
* **Not a privacy or soundness statement.** Byte identity of one function.
* **Not a device result.** No GPU was involved; no kernel exists to test.
