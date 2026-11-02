# W16R2 (D59): W16 at code rate 1/2, counted at the Reed–Solomon unique-decoding radius

Status (2026-11-01): **built as opt-in, unregistered profiles; gated; measured.** No independent review has
been done (D59 condition 4), and no privacy re-check (condition 5). The accounting recount is written
(`ACCOUNTING.md`, condition 2) but not yet independently re-checked. Nothing registers these profiles and no
receipt uses them.

## What was built (gpu-metal tree, `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`)

The pattern is W16's (D54): new profile strings beside the existing ones, and no existing byte moves.

**`shape.rs`.**
- `W16R2_PROFILES` has three entries: `W16R2_RUNG_H24`, `W16R2_SHIELD_T128_H24` and `W16R2_8B_T128_H24`.
  - Each is its W16 sibling's geometry under a new string of the sibling's length, so each has its own
    transcript domain and four keys.
  - Their regular commitments (`A`, `H`, every boundary, both endpoints) are at rate 1/2 with Q = 260 and 260
    pads per row.
  - `M` keeps its `zk.rs` constants.
- `Shape::build` derives `opened_cols` from the profile. It refuses, by name ("D59 —"), a W16R2 string at any
  other rate, row width or endpoint geometry. So a shape cannot carry the profile at another geometry, and
  CS-8's rebuild catches a field write.
- `ColumnRegime` (D15 δ/3 or D59 δ/2) is a profile fact, alongside `column_term_log2`.
- `receipt_bytes` counts the shape's own Q.

**`wire.rs`, `run_fork_wire.rs`, `run_capture.rs`.** The masking commitment's column count is now its own
`zk::MASK_Q`. The wire used to read it as the block's Q. That was harmless while both were 256, but it
refused a W16R2 run segment. The value is unchanged at every profile.

**Tests.**
- `w16r2_tests.rs` (new) holds:
  - the profile facts;
  - D59 malicious controls (a) to (e);
  - W16's limb controls and review F3's four controls, ported;
  - the rung golden;
  - the lemma's invariants;
  - the accounting inputs;
  - the A/B.
- `range16_tests.rs`: W16's controls take a profile.
- `s24`/`s25` scans: the opt-in list and `TEST_ONLY_FILES`.
- `w16_privacy_gate_tests.rs`: test-only run identities for the W16R2 rung and 8B.
- The M4, M10 and D55 harnesses accept W16R2 names.

## Malicious controls (each REJECTED; the exact verifier errors)

The source is `w16r2_tests.rs`, and the printed lines are in `logs/w16r2_tests_nocapture.log`.

How the controls are run:
- **PCS-level controls** run at the W16R2 profile's own PCS parameters: n = 2^14, N = 2^15, Q = q_pad = 260,
  under its keys.
- They go through `zkp_core::pcs::verify_zk_tagged`, which is the function that `verify_core` calls for A and
  H, and that a run calls for every boundary and endpoint.
- The cheating opener replicates `open_zk`'s transcript order. Before any cheat runs, the test asserts that the
  honest replica is byte-identical to `open_zk`.
- **Block-level controls** edit real W16R2 rung core proofs.

**(a) A far matrix.**
- **Setup:** 8,063 = e + 1 of 32,768 encoded columns are off the code, and the cheater opens the honest clear
  vectors.
- **Result:** `pcs zk: column 13662 disagrees with clear vector 0`. 60 of the 260 sampled columns hit the far
  set.
- **Toy rate-1/2 geometry** (n = 16, N = 32, Q = 4, e = 6): 1,429 of 4,000 far matrices were accepted, a rate
  of 0.357. The lemma's (1 − (e+1)/N)^Q is 0.3725, and for this attack it is exact; σ = 0.0076.

**(b) A wrong opened column.**
- **PCS level, one entry changed:** `pcs zk: Merkle path for column 30562 fails`.
- **PCS level, a committed column at an undrawn index:** `pcs zk: column index 0 != sampled 30562`.
- **Rung block, A:** `A: pcs zk: Merkle path for column 6417 fails`; with two columns swapped,
  `A: pcs zk: column index 26973 != sampled 6417`.
- **Rung block, H:** `H: pcs zk: Merkle path for column 4241 fails`; with two columns swapped,
  `H: pcs zk: column index 7429 != sampled 4241`.

**(c) A column set chosen before the challenge.**
- **Setup:** 260 indices are fixed with no transcript. The matrix is honest on them and off the code on the
  other 32,508 columns.
- **Result:** `pcs zk: column index 28887 != sampled 21361`.
- **Positive control:** on the preset set, every per-column check passes (keyed Merkle path, and
  ρᵀcol = Enc(v)[j] for both vectors). The index derivation is therefore the only objection. 254 of the 260
  drawn columns were off the code.

**(d) A forged pad (hiding) half.**
- **Setup:** the first pad entry of a clear vector gets + 1. The forged vector is absorbed and the columns are
  redrawn. `<v[..n], c>` never reads the pads, so the claim check passes.
- **Group vector:** `pcs zk: column 29897 disagrees with clear vector 0`.
- **Proximity vector:** `pcs zk: column 28847 disagrees with clear vector 1`.
- **Toy geometry:** 0 of 4,000 accepted, against a bound of 0.3725.
- **Rung block:** `A: pcs zk: column index 6417 != sampled 17663`. Here the redrawn indices object first.

**(e) Another rate or Q under a W16R2 string.**
- **Construction:** `Shape::new` at rate 1/4 is refused with `private block shape: D59 — the W16R2 profile
  "hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/1" fixes rate 1/2 and Q = 260 at log_cols 14 for A, H,
  the boundaries and both endpoints; the shape declares rate 1/4 at log_cols 14, endpoints rate 1/4 at log_n
  14`.
- **Field writes:** `ruling CS-8 — ... Shape::new refuses its own parameters (private block shape: D59 —
  ...)` at rate 1/4, and `ruling CS-8 — ... its opened_cols differ from what Shape::new derives` at Q 256.
  Neither shape reaches a prover or a verifier.
- **The honest rate-1/4 W16 proof of the same block, under the W16R2 verifier:** `private block: opened
  column 0 of the A commitment carries a Merkle path of 16 entries; this commitment's tree is 15 deep (T-4)`.
- **W16R2 proof, one A column dropped (Q 259) or added (Q 261):** `A: pcs zk: wrong number of columns`.
- **W16R2 proof, every A vector cut to n + 256:** `A: pcs zk: group vector 0 has length 16640`.
- **Re-proved honest openings under W16R2's verifier:**
  - at rate 1/2, Q 256: `pcs zk: group vector 0 has length 16640`;
  - at rate 1/2, Q 259 with 260 pads: `pcs zk: wrong number of columns`;
  - at rate 1/4, Q 260: `pcs zk: opened column 0 carries a Merkle path of 16 entries; this commitment's tree
    is 15 deep`.

**W16's own controls, ported to the W16R2 rung.**
- **The seven out-of-range limb cases:** every one is rejected with `H: pcs zk: group 8: <v, c> != combined
  claim`, at the LogUp sum claim.
- **F3 (a) a width misfiled:** rejected the same way. With the range tags collapsed, the same cheat is
  ACCEPTED, so the tag fold is what refuses it.
- **F3 (b) U = +32768:** rejected at the LogUp sum.
- **F3 (c) a count in a narrow family's padded copy:** rejected for every narrow family (widths 1, 2, 3, 4,
  5, 7, 12, 13) with `slot 19 [TAB table helper zero-check]: sumcheck round 0: s(0) + s(1) != claim`.
- **F3 (d) P = 2^13:** rejected at the LogUp sum.
- In each case the honest prover refuses first, under CS-3.

## Gates

- **Chain:** `logs/chain/w16r2_gates.sh`, whose template is `results/zk60_metal_20261031/logs/m27d55/`.
- **Exit code:** `logs/chain/chain_full.done`. The first run, on the binary the A/B used, is under
  `logs/chain/run1/`.
- Both runs **exit 0**: run 1 on binary `97ed46f4…` (the A/B's), run 2 on the final tree's binary `99eba5da…`
  (`logs/chain/binary.sha256`). Every digest below is the same in both runs.
- After the chain, `logs/w16r2_tests_nocapture.log` re-ran the 15 W16R2 tests on the final binary with their
  output (15 of 15 ok), and `logs/accounting_inputs.log` is extracted from it.

What the runs show:
- **Build:** the gpu-metal test build passes, and so does the no-feature `cargo check --tests`. The warning
  count is 134 on run 2; run 1 had 136, two of them from an unused variable that is now removed.
- **Scans:** 58 of 58 pass. The W-2 census measures all three W16R2 profiles.
- **Existing bytes and tests are unchanged:**
  - zkp-core passes;
  - the D55 tests pass 10/10 on the CPU and with Metal;
  - the D55 capture passes 20/20;
  - the D12a run passes;
  - the dev bytes are `01fa1b2e/992034f8/371e6b00/3ab090df` in both modes;
  - the trained digests are R13 `2b0d04bb/678953f6` and W16 `01a6d51d/c5e0bdac`;
  - the r13 run test passes;
  - golden is 8/8.
- **The W16R2 rung golden is `334e168f`, CPU = Metal**, in both batch-tail modes.
- **W16R2 trained digests, CPU = Metal** at every pass (recorded, not pinned): 8B `5343008a`, Shieldstral
  `e0bb5917`, rung (trained recipe) `d6879fae`.
- **Unit tests:** 114 of 114 in both modes, the 15 W16R2 tests among them.
- **A W16R2 rung run** (L = 3, its boundaries and endpoints at rate 1/2) proves and verifies under the D12a
  serial verifier and under the D55 fork verifier.
- **Full lib suite:** 872 passed, 6 failed, 84 ignored. The six failures are exactly the known Mac-only ones.

## A/B on one binary (W16 against W16R2, 8B T128)

Setup: `logs/ab/w16r2_ab.sh`, logs in `logs/ab/m_*.log`, binary `97ed46f4…` (chain run 1). Conditions:
`HL_PB_ORACLE=0`, synthetic diagonal weights (M4's recipe), arms interleaved, a quiet Mac. [MEASURED]

| | W16 (rate 1/4, Q 256) | W16R2 (rate 1/2, Q 260) | |
|---|---:|---:|---:|
| block prove core, warm n = 5, median (order A then B) | 0.373 s | 0.336 s | ×1.11 |
| the same, order reversed | 0.374 s | 0.337 s | ×1.11 |
| GPU commit time per block, A + H (`HL_METAL_TIMING=1`, attribution only, warm) | 0.034–0.038 + 0.035 s | 0.021–0.022 + 0.020 s | about −30 ms |
| block verify core, CPU, n = 3, median (both orders) | 0.227 / 0.232 s | 0.221 / 0.224 s | about −3% |
| block core bytes (A, H, M openings, slots, roots) | 23,531,376 | 23,685,680 | +0.66% |
| one endpoint or boundary opening (counted) | 749,568 | 744,768 | −0.6% |
| **one request, 32 blocks, D55 forks N = 6, best (ABBA)** | **6.360 / 6.148 s = 20.1 / 20.8 tok/s** | **5.542 / 5.579 s = 23.1 / 22.9 tok/s** | ×1.12 |
| one request, D12a serial, best (ABBA) | 12.26 / 12.07 s = 10.4 / 10.6 tok/s | 11.28 / 11.06 s = 11.3 / 11.6 tok/s | ×1.09 |
| 32-block receipt | 786,061,536 B | 790,843,840 B | +0.61% |
| verify of the 32-block run (D12a serial, one thread) | 4.98 / 4.85 s | 4.79 / 4.66 s | |

Notes on the measurement:
- The commit saving (about 30 ms of GPU time, consistent with M21's 28 → 17 ms per commit) accounts for most
  of the 37 ms core saving. The rest is the smaller Merkle tree and salt work (2^15 leaves against 2^16) and
  the cheaper opening.
- The receipt grows because each of the 260 opened columns carries every row (+4 columns × about 20 KB at
  A/H). The shorter paths (15 entries against 16) win back only 32 B per column.

## Still owed (D59)

- Condition (2): an independent re-check of `ACCOUNTING.md`.
- Condition (4): an independent D24-class review of this implementation.
- Condition (5): a privacy re-check of the changed code and padding.
  - `W16_TEST_RUN_PROFILES` now carries the W16R2 rung, so the W16 gate's `gate_at` can be pointed at it.
  - The capture writer's `mask_domain` column count is now M's own.
  - **Done 2026-11-02, no leak found:** `PRIVACY_RECHECK_20261102.md`.
    - It holds the theory from the code, and the Rust gate at W16R2 on the CPU and Metal (rung and 8B),
      plus PG-R2, the pad block's exact rank.
    - It also holds the v25 Python gate on the W16R2 captures and on four D55 captures (D60's
      prerequisite).
    - It is a mechanical re-check, not a privacy acceptance. The older W16 gate items it lists in §5 are
      still owed.
- Victor's registration ruling.
