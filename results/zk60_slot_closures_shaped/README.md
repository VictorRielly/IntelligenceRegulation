# Evidence for `ZK60_SLOT_CLOSURES_SHAPED.md`

Drafted by a delegated Opus agent for the security owner, 2026-09-21.
Everything here reads the private-block lane `/home/victor/wt-zk60-block125m`
at commit **`8c5922b`** and writes nothing back to it.

Exact arithmetic throughout: Goldilocks `Fp`, `Fp2 = Fp[u]/(u^2 - 7)`,
Gaussian elimination over `Fp2`. No floating point, no statistical test, no
witness value from any real proof, **no privacy claim**.

## Files

| file | what it is | run time |
|---|---|---|
| `fp2.py` | `Fp`/`Fp2` and exact linear algebra, ported from `zkp-core/src/field.rs:10,129-200` and `mle.rs:252-266` | — |
| `slot_table.py` | an independent hand port of the SHAPE-driven slot schedule (`shape.rs`, `layout.rs`, `pad.rs`), and a cross-check against the lane's own Python model | < 1 s |
| `slot_table.json` | its output: the 23 slots at toy / rung-G / rung-K4 / 125M | — |
| `mask_dof.py` | Fact 2.1 recomputed at the SHAPED `(N, d)` of every slot: `rank R_s`, `dim ker R_s`, and `Im R_s ⊆ C_s` | 21 s |
| `mask_dof.json` | its output | — |
| `closure_miniatures.py` | generic-instance miniatures of the shaped closures: the two repaired bilinear slots, a pad-zero zero-check, `SC_TAB`'s two-commitment pad-zero group, `SC_SZC`'s two indicators, plus seven controls | < 2 s |
| `closure_miniatures.json` | its output | — |

## How to reproduce

```
python3 /home/victor/IntelligenceRegulation/results/zk60_slot_closures_shaped/slot_table.py
python3 /home/victor/IntelligenceRegulation/results/zk60_slot_closures_shaped/mask_dof.py
python3 /home/victor/IntelligenceRegulation/results/zk60_slot_closures_shaped/closure_miniatures.py
```

`slot_table.py` reads the lane's model JSONs for its cross-check if
`MODEL_DIR` points at a directory holding `model_{toy,rung_g,rung_k4,m125}.json`
(extract them with `git --no-pager -C /home/victor/wt-zk60-block125m show
8c5922b:results/zk60_block125m_lane/model_<name>.json`). Without it the
cross-check lines say "skipped" and nothing else changes.

## Headline figures

* `slot_table.py`: **138 of 138** counted figures per shape equal to the
  lane's independently written Python model, at all four shapes, 0 different.
  Main rounds 217 (rung-G), 220 (rung-K4), 336 (125M); largest mask length
  72 / 77 / 117, all inside the `L + 256 <= 512` budget.
* `mask_dof.py`: **92 of 92** (23 slots x 4 shapes) have
  `rank R_s = N_s d_s + 1 = dim C_s` and `dim ker R_s = 1` at three
  independent challenge vectors each, and the mask's own rounds satisfy the
  verifier's chain at each.
* `closure_miniatures.py`: **17 of 17** miniatures pass P1..P6 (construction
  premise zero at every extension round; the verifier's chain accepts the
  unmasked transcript for arbitrary reserved-pair values; the rank identity;
  the derived-value identity; the terminal decomposition with non-zero
  coefficients; disclosed dimension 0 of the sumcheck channel against a
  genuinely varying witness). Seven controls behave as they must, including
  the one that shows a degenerate witness cannot decide the bilinear clause.

## What these scripts do NOT model

One slot's published field values at FIXED challenges. Not the PCS openings
(group vectors, proximity vectors, opened columns), not the mask commitment
`M`, not the hash layer, not a run, not the real prover's randomness. They
therefore say nothing about (H1) / gap G-R1, about (H3), or about any
privacy property of a block or a run.
