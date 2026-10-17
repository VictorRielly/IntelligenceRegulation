# Token I/O rung R1 — report (2026-10-17, 22:01 UTC)

Saved by the coordinating session from the lane's final report (the lane
could not write this file itself). Ledger: `PROGRESS.md` beside this file.
Not a privacy claim.

## In plain words

Yes, at the tiny rung: one private run now proves a hidden next token —
32 hidden prompt ids -> embedding -> 2 trained-calibration blocks -> final
norm -> per-row int8 head -> greedy argmax, sealed in a hidden output
endpoint — all one transcript.

- Tokens: both test models give the token the independent reference computes
  (R0 model 24, generic model 116; Python's R0 functions agree on both).
- The verifier sees no token and no logit. Each owner rebuilds its token root
  from the private decommitment (rows, pads, salts).
- All 49 controls refused, each at the slot DESIGN §6.1 predicts.
- Fresh process: verifying from the saved bytes in a new process accepts both
  runs and refuses a one-bit change.

Numbers [MEASURED, shared box, n=1, release test binary]: receipt
19,026,480 B in 4 segments, all equal to the counted lengths (stage IN
1,224,328 B; 2 blocks 7,421,464 B each; stage OUT 2,959,224 B); prove
3.2–4.4 s for the whole run (stages 0.15–0.29 s each, blocks 1.4–2.2 s each);
verify 0.59–0.64 s in-process and fresh; peak RSS 1.83 GiB for the test job.

Soundness [COUNTED]: stage commitments 2^-103.69 per opening; token endpoints
and M 2^-106.25. The rung's own blocks and boundaries (development fixture at
row width 2^10) are 2^-96.13 per opening, setting the whole-commitment term at
2^-93.32. No security figure is claimed from this rung.

## What was built

- Working copy `ops/zkp-mvp/token-io/`, copied from the R5 frozen tree (all
  217 files matched `r5/manifest_frozen.json` before editing; baseline list
  `ops/zkp-mvp/token-io/BASELINE.sha256`).
- New code under `hashline/src/private_block/`: `token_io.rs` (tier, door,
  per-row tables, stage layout, schedule-driven `run_slot` copy, wire codec,
  owner check); `token_io/stage_in.rs` (IO-in; query zero-check with LogUp +
  BOS with its own `mu_bos` + pad, fresh coefficients; table zero-check; ZS;
  LogUp sum on `H_in`); `token_io/stage_out.rs` (IO-in at row T−1's fixed
  bits; SS -> TZC; LZC; HEAD -> VZC (A1, A5 host term, helpers, pad); DZC;
  RSEL (A2/A3/A6 with fresh c1/c2/c3); TAB; ZS; IO-out); `token_io/run.rs`
  (statement, header, prover, verifier, honest pipeline); `token_io/tests.rs`;
  `token_io/r0_words.rs` (R0's words, digests checked).
- Additive edits only: `private_block.rs` (`mod token_io;`), `run.rs` (new
  profile `hashline-zk-mr1/private-token-io-run-rung-tc-t32-public-row-dev/1`,
  one CS-7 arm, refusal of that string in blocks-only `RunStatement`s). No
  existing relation, slot or profile string changed.
- Run order: stage IN -> B_in -> block 0 -> B_1 -> block 1 -> B_out -> stage
  OUT. B_in/B_out are two-site boundaries at block geometry (22 rows), each
  opened once after its second claim. Token endpoints: 256 words at 2^8, rate
  1/8, one site, 6 rows. The statement binds the trained-model identity, V,
  BOS, final-norm constants, multiplier class, derived limb count, embedding
  and head digests, variant and mode, and the tier levers.
- D25 T4 per-row head: l_j = m_j (y·W'_j), public m_j in [1, 2^12]; window
  re-derived over that class (45 bits at R1 -> 6 byte limbs; 53 bits at
  TinyLlama and 56 at 8B -> 7 limbs); no-wrap check in the door and its test.
- D27 tier: Q, stage row-width floor and rate, token-endpoint width and rate,
  lookup field degree live in `Tier` (`Tier::R1_MVP`), carried in the
  parameter line; no literal Q, rate or width in the new stages. Limitation:
  the mask commitment's Q is the fixed `MASK_Q` in the shared `zk.rs`.

## Tests (`logs/t1-tests.log`): 10 passed, 0 failed, 2 ignored (the fresh-process pair, run separately as `logs/p1-*`, `logs/p2-*`)

1. Counted layout = counter (`counts/r1_counts.py`, written before the
   construction): stage IN A 10 / H 14 / M 12 rows, 98,304 elements, sites
   A 3 / H 3; stage OUT A 121 / H 50 / M 26 rows, 700,416 elements, sites
   A 47 / H 12, 77,824 byte lookups.
2. Two honest witnesses (R0's model tiled to d384 with multipliers 1; a
   generic model with distinct embedding rows, every head word nonzero, 288
   distinct multipliers, dense blocks with differing heads); owner checks
   rebuild both roots and refuse tampered or misshapen decommitments.
3. The 23-row control table: all 49 sub-controls refused as predicted
   (`logs/controls.md`), including the CHECK2 N-1 forgery (#4) at stage IN's
   query zero-check, the A6-only and A3-only forgeries at RSEL, `e` on a
   padded entry at VZC, the IO-in / IO-out seal forgeries, the final-norm
   forgeries, statement binding (#22, #23) and the door's class refusals.
   #6, #8, #19 (hidden-length) and #20, #21 (two-site endpoint) do not apply
   at the public row; public-row analogues were tested.
4. Pins: NOT YET RUN at hand-off (full existing suite; baseline r5-suite2 688
   passed / 0 failed / 29 ignored).
5. D16 rule-5 audit: every A plane of both stages classified ranged or
   determined; coverage asserted (classification table hand-written); largest
   no-wrap bound 2^48.17 against p/2 = 2^63.

## Design findings

- TF-1: the limb count is derived (ceil(window/8)), not a fixed six; DESIGN
  §3.1 should say so.
- TI-1: a one-row domain (T_out = 1) has an empty claim point that
  `audit_claims` reads as the sum claim; `To` is laid out over 2 entries.
- TF-2: stage OUT IO-in runs over 2^9 (degree 2), TZC has 1 main round; the
  counter's receipt estimate differs slightly; stage OUT has 18 A groups, not
  10.
- TF-3: the "x not int16" control cannot be expressed at run level (x is
  B_out, range-proved by block L−1); the stage's c2 limbs were tested
  instead.
- TF-4: 12-bit multipliers reach 4096, so the class is [1, 2^12].
- TF-5: M's Q is not a tier lever (the `zk.rs` constant).
- Under the refusal-free Cn, max |y| is 11–12 (the C-7 resolution cost);
  logits remain nondegenerate.

## Next

Not built: the hidden-length variant (D26), the G-1..G-7 rank/CFS gate
tooling, R2 at TinyLlama. Evidence: `counts/`, `logs/`, `runs/{r0-model,
generic}/`, `runs/crosscheck_result.json`, `tools/`.
