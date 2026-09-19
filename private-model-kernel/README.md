# private-model-kernel (EXPERIMENTAL, synthetic)

Exact-integer computation of a fixed **synthetic** ZK60 token model, for a
future separately versioned guest image:

```
32 private token IDs (vocab 32)
  -> embedding gather (public signed i16, (vocab, d) = 32x16)
  -> block 0 -> block 1   (unchanged private-block-kernel run_block, T32 d16 f16,
                           each with its own public weights and lookup tables)
  -> final RMS norm of the LAST row (block kernel's fixed norm calibration)
  -> signed int8 head ((vocab, d) = 32x16), exact checked i64 dot products
  -> greedy next token, lowest index wins ties
```

This is **not** a trained model, **not** a proof, **not** a privacy claim,
**not** 125M/8B coverage and **not** MVP completion. `no_std`, no
allocation, no floats, no I/O, `#![forbid(unsafe_code)]`. The only
dependency is `../private-block-kernel`, used unchanged for both blocks.

## API

- `PublicModel::from_parts(embed: &[i16] /*512*/, block0: PublicBlock,
  block1: PublicBlock, gamma_f: &[i8] /*16*/, head: &[i8] /*512*/)`;
  blocks run in argument order. `PublicBlock { weights: PublicWeights,
  tables: PublicTables }` are the block kernel's types.
  `RawBlock`/`RawModel` hold the raw public words and build these.
- `next_token(&[u32; 32], &PublicModel) -> Result<u32, ModelError>` — the
  default: private tokens in, only the next-token ID out.
- `next_token_traced(.., Option<&mut ModelTrace>)`,
  `next_token_slice(&[u32], ..)` (exactly 32 tokens, else `Shape("tokens")`).
- Helpers: `final_norm_row`, `head_logits`, `greedy`.
- `ModelError::{Shape, Token, Layer(u8, KernelError), Final(KernelError)}`
  carries static sites and a layer index only — never a token value,
  position or activation. `Token` is checked for all 32 IDs before any
  computation.
- `ModelTrace` (tests only; secret embedding/seam/final-norm/logit values,
  no `Debug`). Nothing in the crate prints.
- `synthetic::{synthetic_raw_model, synthetic_model, synthetic_tables,
  SYNTHETIC_LABEL}` — deterministic LCG/integer-formula words, labelled
  SYNTHETIC-ONLY. Its RoPE/exp/activation tables only pass the block
  kernel's structural checks; they are **not** the registered tables.

Nothing consumes caller-claimed activations, logits or tokens. Construction
checks shape/structure only; the caller must authenticate every public
word (weights, tables, embedding, gamma_f, head) against approved
commitments or trusted-image constants.

## Fixed semantics

- Context: exactly 32 tokens, positions 0..31, the block kernel's
  zero-based RoPE. No padding, empty prompt, truncation, KV cache,
  sampling, EOS or multi-token decoding convention is defined here.
- Final norm (`final_norm_row`): `calib::NORM_CEPS/TN/CN/WRHO` exactly as
  the block kernel's round-mode norm, `D = isqrt(sum x^2 + 1)`,
  `y = floor((2 x g 1024 + D 2^11) / (D 2^12))`, `y` in `[-127, 127]` and
  remainder/complement `< 2^29`, else `Final(Range("final norm
  quotient/remainder"))`. For i16 `x` and i8 `g`, `|x_i| <= D` gives
  `|y| <= 64` and `D 2^12 <= 2^29`, so these checks cannot fire today;
  they are kept as the relation's refusal rules.
- Head: `logit[v] = sum_i y[i] * head[v*16 + i]`, checked i64 (max
  magnitude 16*127*128, far from overflow).
- Greedy: strict `>` scan in increasing index (lowest index wins ties).

## Why the synthetic model never refuses

Per block, with gamma in [16, 48]: `|y_i| <= 24` and `||y||_2 <= 36`
(norm output, any input). Q/K rows (diag 48, off-diagonal |w| <= 16) have
L2 norm <= 78.4, so |Q|,|K| <= 23, per-head L2 <= 66 after RoPE (tables
never enlarge a pair), |score| <= 69 (< 127; max - masked <= 196 < 256).
V rows (diag 64, |w| <= 40): |V| <= 48, hence |O| <= 48, |AO| <= 540.
FFN: |gate| <= 34, |up| <= 4320, |act| <= 1400, |h| <= 369, |z| <= 8304
(|wd| <= 90). With embeddings in [-64, 64] the block 1 output is <= 17752
in magnitude. The test fixtures that use larger embeddings (<= 8000) stay
<= 25688. These are hand bounds, not machine-checked.

## Tests (`tests/model.rs`)

Independent i128 reference (own gather, the kernel for blocks, bisection
isqrt final norm, i128 head, max-then-first argmax) over 48 sequences with
trace-plane equality; exact gather against a closed-form embedding;
identity blocks (wo = wd = 0) checked in the kernel; seam
(`layer0 = run_block(embedded)`, `layer1 = run_block(layer0)`, final norm
reads block 1's last row); ablating block 0, block 1, both, and swapping
order each change the token on some of 64 sequences; earlier positions
reach the last row; final norm hand cases, 4000-row i128 sweep, and
equality with the kernel's own `na_dd`/`na_y` planes; head (vocab, d)
orientation and sign; lowest-index ties (unit and end to end); invalid
token (32, 33, 2^16, u32::MAX at several positions) refuses before
computation and before a refusing block; wrong context lengths; layer
index on block refusals; construction shape/table refusals.

```
cargo test --offline --manifest-path private-model-kernel/Cargo.toml
```

## Limitations

- Synthetic words and tables, no training, no canonical tables; no oracle
  (hashline) fixture for the endpoint stages yet — the block stages are
  covered by the block kernel's oracle parity, the endpoint stages only by
  this crate's independent i128 tests.
- No proof, commitment, authentication or guest image; no privacy of the
  output token or of refusal/control flow (not constant time).
- Fixed shape only (T32, vocab 32, two blocks); no prefix-equivalence,
  generation, EOS, sampling or KV-cache relation.
