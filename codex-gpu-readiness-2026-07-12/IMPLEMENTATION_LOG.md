# Implementation log

## 1. Preserved and recovered Fable's work

The starting branch was `perf/zk-batch-optimizations` at `8a206ae`. Two tracked
documentation files already had uncommitted Fable edits; they were preserved
without modification.

I recovered only the clean commits from Fable's attached worktrees:

- `d1cfa56` — U-K9 baseline ledger, cherry-picked as `792f345`;
- `e8fa777` — packed U-K9 kernel layer, cherry-picked as `ecd2482`; and
- `4d9d0d2` — deterministic lattice tamper tests, cherry-picked as `cf55852`.

The U-K8/U-K9 dispatcher conflict was resolved by retaining both
`self_test_ffn_chain()` and `self_test_uk9()`.

I did **not** take the 32-line uncommitted U-K9 residue in Fable's worktree. It
changes `fold_body`'s signature without updating callers and fails with Rust
error E0061.

## 2. Separated prover entropy from Fiat-Shamir state

Affected files:

- `zkmatrix-rs/src/ring/mod.rs`
- `zkmatrix-rs/src/ring/commit.rs`
- `zkmatrix-rs/src/ring/ct_engine.rs`
- `zkmatrix-rs/src/ring/sigma.rs`
- `zkmatrix-rs/src/ring/gkr_masked.rs`
- `zkmatrix-rs/src/bin/ring_matmul.rs`

The old lookup masks and blinders could be reconstructed from public table or
test seeds. The proof engine also accepted only a 64-bit SplitMix state for
commitment, Gaussian and rejection-sampling randomness.

The fix introduces two explicit interfaces:

- `ProverRng::from_os()` reads a buffered stream from Linux
  `/dev/urandom`. U-K8 `ffn-chain` uses this for commitment randomness,
  lookup masks, blinders, Gaussian masks, ARP masks and rejection coins.
- `ProverRng::from_test_seed()` is a clearly named deterministic SHA-256
  counter stream used only by reproducible batteries.

Mask and blinder draw functions now require `ProverRng`; they no longer accept
`LkpTranscript`. This prevents a public Fiat-Shamir transcript from being
passed to those APIs accidentally. The existing same-object one-use marker is
retained, while independent production sessions obtain independent OS entropy.

Legacy `u64` randomness remains available to old test/demo paths through
`RngSource`; it is not used by the normal U-K8 CLI proof path.

## 3. Closed the verifier-controlled U-K8 lookup prehash

Affected file: `zkmatrix-rs/src/bin/ring_matmul.rs`

Previously, the verifier initialized the lookup transcript from `h0_lkp`
carried in the prover-created tuple. It never recomputed the value implied by
the statement, table digest, link prehash and q31 commitment list.

The verifier now:

1. recomputes `h0_link_v` from its public inputs;
2. recomputes `ctx_lkp_v = H(table_digest, h0_link_v)`;
3. recomputes `expected_h0_lkp = ct_h0(crs, ctx_lkp_v, t1s, t2s)`;
4. rejects if a carried value differs; and
5. derives alpha and every later lookup challenge only from the recomputed
   value.

`ChainTamper::LookupH0` flips a bit in the carried value. The new battery
rejects it while showing that the independently recomputed wave remains valid.

## 4. Froze lookup semantics as integers

Affected files:

- `zkmatrix-rs/src/ring/lookup.rs`
- `zkmatrix-rs/src/manifest.rs`

`silu_int8_table()` previously evaluated `exp()` in `f64` at runtime. That is
not a suitable cross-CPU/GPU protocol definition. The 256 output bytes are now
a static integer array. Their canonical specification digest is:

`768b83d7c01d9beecc645d2646f107df7fc370dc802fee154c0318685c40d297`

Both the lookup freeze battery and the statement validator pin the full digest.
A Lookup can no longer select an arbitrary nonzero table digest.

## 5. Repaired statement and integer semantics

Affected files:

- `zkmatrix-rs/src/manifest.rs`
- `zkmatrix-rs/src/bin/ring_matmul.rs`

The validator now enforces:

- signed positive capacity: a signed `b`-bit destination accepts an absolute
  bound only when it is strictly below `2^(b-1)`;
- the fixed-point rescale equation on every Rescale, even when a Range or
  Lookup proves calibrated narrowing;
- lookup width, signedness **and** `frac_bits = 4` on both operands;
- the canonical frozen SiLU table digest;
- nonempty Add inputs;
- equal orientation for LinkEqual;
- the ByColumns orientation contract for BiasBroadcast; and
- acyclic producer/consumer dataflow.

New negative cases cover all of these rules, including the previously accepted
`(-128) * (-128)` into signed 15-bit output.

The 32-layer statement inventory was corrected rather than grandfathered:

- gate/up accumulators: signed 28-bit, fraction 8;
- gate/up rescale shift: 4;
- Hadamard product: signed 16-bit, fraction 8, with an explicit int8 Range;
- Hadamard rescale shift: 7; and
- down rescale shift: 1.

The corrected inventory validates 737 entries and 736 operations.

## 6. Made U-K9's arithmetic assumptions executable

Affected files:

- `zkmatrix-rs/src/ring/kfield.rs`
- `zkmatrix-rs/src/ring/gkr.rs`
- `zkmatrix-rs/src/bin/ring_matmul.rs`

Added:

- `K9_MAX_LEAVES = 2^25` and pre-allocation capacity checks;
- checked packed-table allocation arithmetic;
- release-mode input/output slice and accumulator layout assertions;
- a hard lazy-accumulator pair-term ceiling;
- exact accumulator-size and masked-constant checks;
- packed eq-table and projective-tree caps;
- forced-portable packed fold and fixed-multiply harnesses; and
- adversarial residue vectors containing `0`, `1`, `q-1`, `q-2`, `q/2`,
  `399`, `q-399`, and `798`, including a partial final lane block.

The battery compares AVX-dispatched packed code, forced-portable packed code
and the independent boxed scalar oracle bit for bit.

## 7. Validation and measurement

The exact evidence is in [TEST_EVIDENCE.md](TEST_EVIDENCE.md). The important
results are:

- full `ring_matmul self-test`: passed in 216.62 seconds;
- corrected transformer statement inventory: passed;
- focused Python protocols: 30/30 passed;
- all Rust targets built and their Cargo test harnesses passed;
- OS-entropy U-K8 proof benchmark: both arms verified; and
- U-K9 lookup-core at `2^18`: 5,247 ns/element prover time, 166,896 KiB RSS.
