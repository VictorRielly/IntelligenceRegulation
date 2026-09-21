# Evidence for `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_CHECK.md`

Independent adversarial check, 2026-09-21, 03:15 PDT (`date` read at 02:58 and
03:15 on the WSL box). One script, no dependency outside the standard library,
no network, no build, nothing heavy, exact integers and `fractions.Fraction`
throughout (floats only inside a printed `log2`).

```
python3 recheck.py        # ~1 s ; ends ALL ASSERTIONS PASSED or exits 1
```

* `recheck.py` — the whole check
* `recheck.out` — its output, saved

Nothing here is imported from `results/zk60_joint_sentence_query_classes/`.
Every constant was read independently from the lane worktree
`/home/victor/wt-zk60-block125m` at commit **`8c5922b`**, and every figure the
memo carries from another document is re-derived **in the form in which the
memo uses it**, not copied.

## What each section establishes

| § | what | memo claims touched |
|---|---|---|
| 1 | the sampler: `TV = 2^-96.0000000003`, `Pr[rej] = 2^-64.0000000007`, `p − r = 2^32` exactly, the 32.000-bit gap, the optimality of `r/N` brute-forced on six small analogues, and one analogue where the event form is the smaller | A-12, A-13, A-14 |
| 2 | the eleven-segment block-body schedule rebuilt from `Shape`/`Layout` constants at five shapes; all five `fp()` totals and both byte totals reproduce | A-4, A-5 |
| 3 | the endpoint / boundary / seam segments and the run totals; D9's 327,052 and ruling H-6's 2,093,340 / 2,283,876 / 109,728,784 all reproduce; `C(47,2) = 1,081` | A-5, A-6, A-7, A-11 |
| 4 | the flag's price: `C(N_leaf,2)·2^-256 = 2^-229.83`, `N_overlap·2^-256 = 2^-241.42`, `N_node·N_leaf·2^-512 = 2^-484.83`, and **the q-term `q·2^-242.415` that A-17 drops**, which overtakes the collision term at `q = 6,144 = 2^12.58` | A-16, A-17 |
| 5 | every BLAKE3 input length per profile, by function family; every within-family clash and cross-family coincidence, computed, not read off a prior table; the 1-byte margins | B-2, B-3, B-4 |
| 6 | `Shape::slot_terms()` per shape: **a six-terminal `pb-term` absorb exists at every shape (slot 19 = `SC_TAB`)**, settling the memo's `[UNVERIFIED]` | B-8, GAP-QC-4, W-6 |
| 7 | both counterexamples reimplemented from scratch mod 101, six seeds each, and the two value-level defects the memo's five owed assertions cannot catch | A-18, A-19, §3.1 |

## Where the code constants come from (all at `8c5922b`)

| constant | file:line |
|---|---|
| `p = 2^64 − 2^32 + 1` | `zkp-core/src/field.rs:10` |
| `fp()` = two `next_u64` = 16 B; `bytes32()` = 32 B; `RNG_BLOCK = 8192` | `zkp-core/src/rng.rs:73-77, :93-99, :16` |
| refill unkeyed `blake3(key(32) ‖ le64(ctr))`, XOF | `zkp-core/src/rng.rs:53-61` |
| seed derivation keyed, `"hashline-zk-os-rng/v1/"` (22 B) ‖ domain | `zkp-core/src/rng.rs:44-51` |
| pads `fp_vec(rows·Q)` then salts `nn × bytes32`, before the backend offer | `zkp-core/src/pcs.rs:777-778` (tagged), `:724-725` (legacy) |
| `MASK_LOG_MSG 9`, `MASK_LOG_DOM 12`, `MASK_Q 256` | `hashline/src/zk.rs:373-375` |
| `CfsMask::len = n_vars·degree + 2`; `fp2_vec` = 2 `fp` | `zkp-core/src/sumcheck.rs:190, :201-202` |
| `N_SLOTS 23`, `M_ROWS 50` | `hashline/src/private_block/layout.rs:797, :930` |
| `a_rows/a_mask_base/h_rows/h_mask_base` per shape | `layout.rs:1063-1097` |
| `mask_specs()` per shape | `shape.rs:756-807` → `layout.rs:1183` |
| `slot_terms()` = `a_sites + h_sites + (s ≥ SC_IO_IN)` | `shape.rs:704-742` |
| profile string lengths 39 / 44 / 46 / 47 / 36 | `shape.rs:33, :41, :384, :444, :478` |
| run profile lengths 44 / 45 / 34 | `run.rs:52, :57, :58` |
| `parameter_line` lengths 113 / 152 / 152 / 152 / 157 | `protocol.rs:128-148` |
| run `parameter_line` (+84 / +85 / +86 by `L`) | `run.rs:234-246` |
| `EXPECTED_BYTES = 112` | `hashline/src/private_block.rs:213` |
| endpoint mask rows 5; boundary mask rows `2·sites + 2 = 6` | `endpoint_g.rs:52`; `boundary.rs:180-182` with `BOUNDARY_SITES = 2` (`run.rs:50`) |
| boundary rows `endpoint_rows + 1` | `run.rs:211-217` |
| seam `LOG_COLS 8`, `INV_RATE 8`, `MASK_ROWS 5`, `DOMAIN` 28 B | `private_seam.rs:26-36` |
| spec digests 128 / 142 / 151 B | `private_seam.rs:116`, `endpoint_g.rs:158`, `boundary.rs:211` |
| `degree_range() = (2, 5)` | `shape.rs:826-830` over `BASE_DEGREE` (`:58`) |

## What is NOT here

* No Rust was compiled, no test run, no proof produced. Every code claim is a
  reading at `8c5922b`.
* `D2`'s (`private_block.rs:513`) and `D3`/`D5`'s (`layout.rs:1289`,
  `run.rs:286`) input lengths are `31 + w` / `33 + Σ` / `31 + Σ` and were not
  evaluated: the weight serialisation and the `describe()` line set were not
  enumerated. Their lengths are therefore missing from §5's sets, as they are
  from the memo's.
* Nothing here establishes a privacy property of anything.
