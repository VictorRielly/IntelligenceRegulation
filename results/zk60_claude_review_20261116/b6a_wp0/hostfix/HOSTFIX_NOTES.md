# B6a host fix: prover-side parallel tower and BAT (overlay notes, 2026-11-24)

Written by a Claude subagent from the brief `brief_hostfix.md`. **No speed was measured here**; the GPU/timing test
`zk60_b6a_spike::b6a_w_commit_and_baseline_absorbs` was not run. What is claimed: every changed function gives the same
words as the base, checked by old-vs-new tests, and the crate's tests are green.

## Files

| File | sha256 |
|---|---|
| base `profile-9fbc85292/zkp-core/src/tower.rs` | `a165008774508ecce9534af4e399ba04dcccd478323e98b8e217b9c68cfee5d4` |
| base `profile-9fbc85292/zkp-core/src/pcs/switch.rs` | `f0a24fbf91eaaaaec9d025f7de6db2beddcf9a8fcd19c39c4550c5e9c6b51add` |
| base `profile-9fbc85292/zkp-core/src/pcs/switched.rs` (read, not changed, no overlay) | `213b6a3c8d129c2a5dc6e2e172dc00edf05c6b4f0a898c20e97c84ea6ac8fe63` |
| overlay `overlay/zkp-core/src/tower.rs` (1,574 lines) | `e367ed7f38f0443e9de124664c9e7ae24bd0a551183e2028d13e72f4207d327c` |
| overlay `overlay/zkp-core/src/pcs/switch.rs` (554 lines) | `57dcee50224d0dfcb6fe69250c350a4038ffc62918932ab4f73c130959d10589` |

Each overlay started as a byte copy of its base file. Line numbers below are the overlay's.

## Why reordering sums cannot change a word

`field.rs` keeps every `Fp` canonical (`add` reduces with `Fp::new`, `sub` with borrow lands below p, `mul` through
`reduce128`), and `Fp2` equality is limb equality. So `Fp2` addition is exact, associative and commutative on canonical
words: any split or order of a sum (rayon `reduce`, chunked accumulation) gives the identical word. Each parallel
`collect` keeps element order.

## Changes

1. **Thresholds** (`tower.rs:13-21`, `switch.rs:336-339`): `PAR_MIN = 4096`, `PAR_CHUNK = 1024`, `SWITCH_BATCH = 32`,
   `PAR_ROWS = 64`. Below `PAR_MIN` every new path calls the serial code.
2. **`LinearCode: Sync`** (`tower.rs:39-42`): supertrait so rows can be encoded and generator rows built on the pool.
   The only implementation, `CoefficientRs`, holds `&NttTables` (Sync). No function body of the verifier changes; a
   future non-Sync code would fail to compile, not change bytes.
3. **A2, `Commitment::new`** (`tower.rs:204-290`, prover only): canonical check by parallel `all` (same boolean). Row
   encoding: one task per row writing its own `[2rn, 2(r+1)n)` slice, results collected in row order and the first
   failing row's error returned, as the serial loop did. Salts still drawn serially from `rng` after encoding, in
   position order (no draw on an encode error, as before). Salted leaves by an order-preserving parallel map. Serial
   path when `extent < PAR_MIN` or `rows < 2`. Tests: `hostfix_commitment_matches_base` (6 shapes incl. full W2,
   16 x 1,024 on 32,768), `..._full_shape` (W, 48 x 16,384 on 65,536), `hostfix_commitment_errors_match_base` (encoder
   error before a short row, short row, noncanonical word, wrong length; equal error and equal rng state).
4. **A2, `dot_par`, `fold_in_place_par`, `round_sums`** (`tower.rs:422-481`): prover-only copies; `dot` and
   `fold_in_place` (used by `replay_fold` and `verify_after_bind`) are unchanged. `round_sums` fuses `dot(m0,c0)`,
   `dot(m1,c1)` (first round only) and `s2` into one parallel reduce. Test: `hostfix_fold_in_place_and_dot_match_base`
   (odd lengths, unequal dot lengths, both sides of the threshold).
5. **A1, `prove_fold`** (`tower.rs:497-564`): no separate entry dot. Order of checks kept: unequal lengths ->
   `BaseClaim`; if `padded_extent` fails, the claim dot is still checked first (`BaseClaim` if false, else `Geometry`);
   when no round will run (`size <= width`) or padding would truncate (`len > size`), the entry dot runs as before.
   Otherwise round 1 checks `dot(m0,c0) + dot(m1,c1) == target` before any absorb (zero padding makes this the same
   sum). Rounds >= 2 take `round[1] = running - dot(m0,c0)` with `running = interpolate_eval(&round, r)`, the
   verifier's recurrence; `interpolate_eval` through 0, 1, 2 is exact for the degree-2 round polynomial, so `running`
   equals the folded `dot`. Absorbs, labels, challenges unchanged. Tests: `hostfix_prove_fold_matches_base_below_threshold`
   (6 shapes incl. zero rounds and truncation), `..._above_threshold` (incl. full second fold 16 x 1,024),
   `..._full_shape` (48 x 16,384 padded to 64), each with a false target (BaseClaim, transcript untouched and equal);
   `hostfix_prove_fold_error_paths_match_base` (unequal lengths, refused geometry with true and false claim).
   Rounds, folded message and coefficients, target, point, transcript state, counter and next challenge compared.
6. **A2 + A3, `switch_claim_prover`** (`tower.rs:627-706`, called at `:764`; `switch_claim` at `:596` unchanged and
   still used by the verifier at `:827`): same draw order (carry, then one weight per column before that column's
   generator error/length check), so an error leaves the same transcript. Generator rows of a batch of 32 are built
   on the pool first (pure functions of the public position, no transcript use). Accumulation over 1,024-entry
   chunks of the coefficient row on the pool, column order kept inside each entry. A row whose entries all have
   `c1 == 0` (always, for `CoefficientRs`) uses `weight.mul_base(g.c0)`: for `g = (g0, 0)`, `weight.mul(g)` is
   `(w0 g0 + w1*0*7, w0*0 + w1 g0) = (w0 g0, w1 g0)`, the same words; other rows use `mul`. Falls back to
   `switch_claim` when `width < PAR_MIN` or fewer than 2 columns. Tests: `hostfix_switch_claim_matches_base` (small
   code; a non-base test code with `c1 != 0`; extents below/above the width; error at column 0 and in the second
   batch), `..._full_shape` (16,384 on 65,536, 48 rows, 138/169/280 columns, and an error at column 100).
7. **A4, BAT `opening_claim`** (`switch.rs:225-334`, shared by prover and verifier): the only per-vector error
   (`EvaluationWeightsLength`) is checked up front, after the generator, which is where the old loop would first
   reach it, and it is the same value whichever vector carries it. `combined` by rows in parallel (sum over vectors
   per row), per-vector scaling in parallel and collected in vector order (the `mu*x + alpha*w` of the old two passes
   fused per entry, same word), evaluation term and column term summed separately and added (exact sum). Serial
   paths below the threshold. The rational generator and `pack` are unchanged. Tests:
   `hostfix_opening_claim_matches_base` (6 shapes, both bases), `..._full_shape` (T128: n 16,384, q 280; 2,501 rows x
   37 vectors and 2,602 x 10, 280 samples each), `hostfix_opening_claim_errors_match_base` (row count, short column,
   short evaluation row, sample on the message domain with and without a short evaluation row). The old function is
   kept verbatim as `#[cfg(test)] opening_claim_reference` (`switch.rs:341-403`).
8. **End to end**: `hostfix_tower_proof_matches_base` (5 rows of 17 with switch 3 of 6; 37 rows of 300 with switch
   15 of 20) and `..._full_shape` (48 x 16,384 on 65,536, switch 16 x 1,024 on 32,768, 169 and 120 checks): the base
   `prepare_w` + `prove_after_bind` (kept verbatim in `#[cfg(test)] mod hostfix_reference`, `tower.rs:880-1082`, built
   from the old `prove_fold`, `fold_in_place`, `Commitment::new` and `switch_claim`) against the new; the whole
   `TowerProof` compared by its `Debug` text and by field, transcript state and counter and next challenge, rng
   state, and the unchanged verifier accepts the new proof ending at the prover's transcript state.

Textual check: `replay_fold`, `verify_after_bind`, `verify_openings`, `switch_claim`, `dot`, `fold_in_place`,
`absorb_root`, `check_claim_input`, `bind_w`, `padded_extent` are byte-identical to the base (function-text compare).
`verify_zk_switched` (`switched.rs`) is not in the overlay.

## Guard runs (all `--class build`, label `claude-b6a-hostfix-tests`, `cargo test --release --offline --locked -j 2
--features b6a-spike`, staged with `run_wp0_hostfix.py --stage`)

| Run id | Staging | Exit | Result |
|---|---|---|---|
| `393d4d03329a` | work0: overlay = byte copy of base `tower.rs` and `switch.rs` (baseline) | 0 | lib 98 passed, 3 ignored; integration 2 + 1 + 1 passed; doc 0 |
| `5b8f4c5e46f9` | work1: first overlay | 101 | compile error in a new test (`trailing_zeros` on an untyped integer literal); no test ran |
| `15b7e708b80c` | work2: final overlay (hashes above) | 0 | lib **113 passed**, 0 failed, 3 ignored (98 base + 15 hostfix); integration 2 + 1 + 1 passed; doc 0. Includes `pcs::switched::spike::spike_synthetic_bat_and_tower_agree`, all 6 `pcs::switched::tests`, all 5 `tower::tests` |

Logs: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/hostfix_work/run{0,1,2}.log`
(scratch, not durable).

## Not done

- No timing of any kind; no `--class gpu`; the Metal test was not run. Whether the prover tower and BAT now meet any
  line is for the coordinator's measurement.
- **Stage B (rational switch-step row) not done.** Reasons: (a) the generic `LinearCode` trait does not expose the
  evaluation point `7 omega^pos`, so the rational form needs a new trait method or a `CoefficientRs`-specific path;
  (b) by the tick-56 handoff's own derived figures, the rational form is about 6 to 7 ms serial (11 NTTs), while the
  dense form now runs on the pool with `mul_base`; at 5 threads the dense form may already be below that (an estimate,
  not measured). It would mainly help the verifier, which this brief keeps unchanged.
- `evaluation_claim_rational` (two calls, about 1.85 ms each in the record), `Commitment::open`, `pack`'s copy, the
  bridge prep and the Merkle tree were left as they are.
- The base `b6a_switch_qualification_1000` test stays ignored, as in the base; it was not run.
