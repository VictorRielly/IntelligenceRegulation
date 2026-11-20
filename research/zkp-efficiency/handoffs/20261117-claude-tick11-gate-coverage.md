# Research handoff: which zero-check pairs are dead because of padding, and what skipping them is worth (2026-11-17, claude-tick 11, queue item 26, from H157)

From Claude, the standing background researcher. Local code reading plus one arithmetic script; no web search.

**Scope.**
- Read: `slot_ir.rs`, `slot_ir_accuracy.rs`, `pad.rs`, `shape.rs`, `accuracy_act.rs`, `argument_accuracy.rs`, `metal_slot.rs`, `gpu/metal_kernels.metal` (all under `ops/zkp-mvp/gpu-metal/hashline/src/`), and the Antigravity breakdown `results/zk60_slot18_14_breakdown_20261117/README.md` (it exists; reviewed status not checked). 0 searches, 0 fetches. Script: `20261117-claude-tick11-gate-coverage.py` (arithmetic only, reads no file).
- **Triage material, not a work order.** The change is prover-side and leaves the transcript and proof bytes unchanged if the test below passes, so it needs no ruling and no profile string. It does need the owner's or a kernel lane's time. Nothing was built or run.
- Labels: COUNTED (file:line), MEASURED (the cited record), DERIVED (arithmetic in the script), ASSUMED.

## 1. Answer in one paragraph

Tick 10's kill condition ("dies if any term is ungated") was the wrong test, and the answer to it is: yes, some terms are ungated. But the skip does not need the gate. It needs the honest padded values to be the same constant on both ends of a pair, because then every table's line value is that constant at every evaluation point, and the term is the zero-check relation evaluated at an honest padded point, which is 0. By that test, at W16R2_8B **only slot 18 has anything to skip (12.5% of its pairs in rounds 0 to 6)**; slots 14, 15, 16, 17 have no padding at all. Worth about 1 to 2 ms of slot 18's 21.3 ms per block, 1.0 to 1.8% of the block's GPU time, about x1.01 to x1.02 on the 8B stream. **At the Shieldstral profile the same skip is worth 4 to 7% of block GPU** because that shape pads width 3,072 to 4,096 and hidden 9,216 to 16,384.

## 2. Which slots pad (COUNTED)

- A domain pads when `size(dom) != true_size(dom)` (`shape.rs:2460-2462`); the gate table exists only then (`slot_ir.rs:693-699`, `supp` returns `None` otherwise), and `gated(None, n)` is the bare node (`slot_ir_accuracy.rs:117-121`).
- W16R2_8B: tokens 128, width 4,096, hidden 14,336, q_heads 32, head_dim 128, kv_heads 8, `log_cols` 14 (`shape.rs:302`). D = 128 x 4,096, Q = 128 x 32 x 128, Kv = 128 x 8 x 128 and S = 32 x 128 x 128 are exact powers of two (`shape.rs:2415-2427` true sizes). **Only F pads: 14,336 of 16,384 columns live, gate-zero fraction 0.125** (script). `Dom::T` and `Dom::Ht` are not lifted (`layout.rs:198-200`) and do not pad at this shape.
- R13/W16R2_SHIELD: width 3,072, hidden 9,216 (`shape.rs:229,301`): **D pads 3,072 of 4,096 (gate-zero 0.25), F pads 9,216 of 16,384 (gate-zero 0.4375)**; Q, Kv, S exact.
- Slot 19 (`Dom::Tab`, 2^14 cube) pads heavily (256 byte-table rows of 2^14) but is dispatch-bound: 0.05 + 0.383 + 1.288 ms of phase time, about 0.3 ms per round, so there is no bandwidth to save (MEASURED, README table 2.2).

## 3. Which terms carry the gate (COUNTED), slot 18 (`fzc_w16`, `slot_ir_accuracy.rs:499-553`) and slot 14 (`dzc_w16`, same shape)

Three top-level terms (`three_terms`, `:102-109`): `eq(tau) * zc`, `nu0 * eq(p_g) * gate * host_g`, `nu1 * eq(p_u) * gate * host_u`. Hosted terms carry the gate and vanish where it is 0. Inside `zc` (`:545-549`), four families:

| Family | Carries the gate? | Value at a padded pair of honest constants |
|---|---|---|
| LogUp helper relations `h d1 d2 - (d1 + d2)` (`logup_subterms`, `slot_ir.rs:870-902`) | **no** | 0: `h` is the inverse sum of the same constant denominators |
| `fa = fact (alpha - query) - 1` (`:543`) | **no** | 0 |
| pad-zero term `(1 - supp) * sum zeta^j plane_j` (`IrPad`, `slot_ir.rs:790-836`) | gate complement | 0: the zero-rule planes are 0 |
| the gated clauses `gate * batch` (`:548`) | yes | 0 by the factor |

So two families of the zero-check have no gate factor; they vanish by value, not by factor.

## 4. Why the honest padded values are constant (COUNTED / DERIVED)

- Zero-rule planes are 0 off support (`pad.rs:290-315`; the witness fills only supported indices, `witness_accuracy.rs:1008-1013`, `a_scaled` stays 0 elsewhere).
- The public activation `group` column is 0 at padded columns (`accuracy_act.rs:53,105,170`) and depends on the column only, so equal across a pair that differs in t.
- LogUp helpers and `fact` are functions of the lookup values at that position only (`argument_accuracy.rs:896-902,913`, the test frame; the relation forces the same in any honest witness). With zero planes and a column-only public input they are one constant per helper. `pad.rs:317-345` says they are non-zero and exempt, which agrees.
- Tables that are not constant across a pair: the eq tables (`tau`, `p_g`, `p_u`), and on D the row-axis slices `id`, `idm`. The eq tables multiply the whole zero-check, and `id`, `idm` appear only inside the gated clauses (`dzc`, `:174-186`). So neither can make a padded pair's term non-zero.
- **Layout fixes which pairs.** Pairs are `(i, i + nhalf)` (`metal_slot.rs:456-465`, `metal_kernels.metal:560-575`, in-place fold), flat index `t * f_pad + j` (`accuracy_act.rs:38`; D likewise, `mvp_driver.rs:630`). The first 7 rounds bind t (128 rows), so a pair keeps its column: **a pair is fully padded exactly when its column is, a fraction 1 - live/pad in every one of rounds 0 to 6**. In the column rounds 7 onward the lo end is always live (`f < half <= live`), so no pair is fully padded (script, exact count 0). Rounds 0 to 6 hold 99.2% of the cube volume.

## 5. Value (DERIVED from the MEASURED solo-block phases; script)

Saveable phases: table build, round 0, rounds 1-4 (bandwidth-bound; rounds 5 and later sit at the 135 to 240 microsecond dispatch floor and save nothing). Realised fraction ASSUMED 0.6 to 1.0 of the gate-zero fraction (row-tail imbalance, the three eq tables still folded because the column rounds read them).

| Profile | slot 18 | slot 14 | both, per block | share of block GPU | per request |
|---|---|---|---|---|---|
| W16R2_8B (117.3 ms/block, 32 layers) | 1.15-2.14 ms of 21.3 (5-10%) | 0 | 1.15-2.14 ms | 1.0-1.8% | 0.04-0.07 s of 3.75 s |
| R13_SHIELD (248.9 ms/block, 26 layers) | 7.05-12.9 ms of 34.8 (20-37%) | 2.97-5.36 ms of 28.0 (11-19%) | 10.0-18.3 ms | 4.0-7.3% | 0.26-0.47 s of 6.47 s |

Committed words per request: none (padded words are still committed; that is a layout change, see item 27 below). Proved tokens per second at the 8B stream: x1.01 to x1.02 if GPU-bound, about half of that on the two-lane cadence (A33 / Antigravity: the stream is paced by the prove call). The Shieldstral solo prove would gain 4 to 7% on GPU time.

## 6. Falsifiable tests

1. **P1, CPU only, no Metal.** For slots 14 and 18 at a padded shape (the Shield profile or the rung, and W16R2_8B slot 18 if memory allows), on an honest witness, take every round-0 pair whose two columns are padded and evaluate the IR (`SlotIr::eval`, `slot_ir.rs:352`, test-only) at the line values for d = 2 to deg. **Pass:** the zero-check term is 0 at every such pair, every table other than the eq tables and `id`, `idm` has lo == hi. **Kill:** any non-zero, or any differing pair (then a plane or helper is not column-constant at padding, and the skip is wrong for that table).
2. **P2, GPU, guarded gpu-class job on a quiesced box (owner or kernel lane).** Remap the round and mat kernels' thread index to live pairs, skip `k_fold_tables` for padded cells of non-eq tables (in-place fold leaves lo == hi unchanged), keep folding the eq tables and materialise the padded `xtabs` cells once. **Pass:** all `part` buffers bit-identical per round on 8B (digest `90003b76...`) and Shield (`5a6193d3...`), and slot 18 on 8B at least 1.0 ms faster batched (about 5%), Shield slots 14 + 18 at least 8 ms. **Kill:** under 0.5 ms on 8B.

## 7. Risks and what was not verified

- Not run: P1 and P2. Constant-ness of the helper planes is derived from the formulas, not read off a dump; a helper written by the real witness path (not the test frame `honest_frame`) was not traced.
- The README's per-phase times are solo-block; under two-lane overlap other lanes backfill idle cores, but the j = 0 to 3 phases are DRAM-saturated (README section 4), so bandwidth saved there should carry over; not measured.
- Whether the Shield numbers matter depends on the owner's priority between the 8B stream and the app profile.
- A skip written wrongly changes round polynomials silently; the test is a per-round bit-identity on both profiles, not one digest.
- The `HL_A27_MULTI` and persistent-tail paths (`k_sc_round` for j >= 1) were not read for the thread-index remap.
