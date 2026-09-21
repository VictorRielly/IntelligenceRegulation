# Evidence: the RUN gate on a NON-DEGENERATE witness, 2026-09-20 (round 4)

The RUN gate run on the two bundles stage 20 of the Rust lane re-took under
the **repaired bilinear attention argument** (finding S19-F1) — and
`run-g-dense-s20` is **the first capture this gate has ever read that was
made on a witness which is not degenerate**. Tool:
`scripts/zk60_native_run_gate.py`, with round 4's two new modules
`zk60_native_rg_gqa.py` (the group factor: the geometry, the dimensions,
the point and both factors' coordinate lists, all derived) and
`zk60_native_rg_gcontrols.py` (GQ-1 … GQ-6), plus
`zk60_native_rg_witcmp.py` (the witness comparison, not part of the gate's
`TOOLS`). Report: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §8. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`, round 4.

**Nothing here is a privacy acceptance and no file here establishes a
privacy property.** A dense witness makes the gate's figures *worth more*
than a degenerate one did; it does not turn a rank of a stated linear model
into a privacy property. `privacy_review_complete` is `false` in both
bundles and in every record.

**The gate cannot see the witness.** No capture carries one. "Dense" and
"zero" below are claims about the Rust lane's test that wrote each bundle
(its own README), not something measured here.

## Clock

Written 2026-09-20. The eight gate runs below were taken between **21:23
and 21:27 PDT** on the shared WSL laptop, CPU only, one at a time under
`flock /tmp/zk-heavy.lock`; the lane's twelve-block dense 125M measurement
had finished at 21:09 (`m125-run-l12-dense.done`), so nothing heavy was
competing.

## Input, READ-ONLY and NOT copied here

`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`

| bundle | witness (from the capture's README, not measured) | argument | `manifest.json` SHA-256 (of the file) | `total_bytes` | commit |
|---|---|---|---|---:|---|
| `run-g-dense-s20` | **fully dense public weights, a non-constant hidden input, the two key-value groups carrying different data in every block** | **repaired (stage 20)** | `62673b03ad3ec621fb6aefb8a3e9c2e872fd441b7273374984d204d86701013a` | 41,296,268 | `0426ad2` |
| `run-h-zero-s20` | the all-zero hidden input | **repaired (stage 20)** | `d1c19b98fc46163605e88df9bda9e1ef91ca70c7eedfacae068545483d8a4fa2` | 41,270,047 | `0426ad2` |
| `run-a` … `run-f` | the lane fixture (identical in every head) / all zero | pre-repair | rounds 1–3's READMEs | 38.5–41.3 MB | `cb27845` / `aff891d` / `facc057` |

### The source pins, and what selects the definition

The new bundles pin `argument.rs dd8469cb` where the stage-18 ones pin
`909670c9`. **That digest is what selects which definition of slots 08 and
09 the port evaluates** — not the presence of an `eq` table in the bundle,
which would be consuming the prover's own claim. Both digests are
definitions this port has READ
(`zk60_native_rg_gqa.ARGUMENT_DEFINITIONS`); anything else still makes
every slot NOT CHECKED.

`layout.rs`, `protocol.rs` and `plane_index.rs` are byte-identical to the
stage-18 pins. Two files moved and each diff was read:

* `argument.rs` (`git diff facc057 0426ad2`): the two bilinear slots, the
  `B::group_eq` helper and one `#[cfg(test)]` accessor. **No other slot's
  polynomial moved.**
* `shape.rs` `8f734422`: the two slots' dims become `lkv + clog2(...)` main
  rounds and degree `2 + indicator + group_eq`, and `Shape::new` gains
  finding F-2's named refusal for a P-3-lifted `Dom::Q`/`Dom::Kv`/`Dom::S`.
  Both are **derived independently** in `zk60_native_rg_gqa.Geometry` and
  compared with the shape's own `slots` array, so the port does not take
  the moved file's word for either.

## Exact commands

```
cd /home/victor/wt-zk60-jointview
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
E=results/zk60_native_run_gate_s20

# the two REPAIRED bundles
python3 scripts/zk60_native_run_gate.py --bundle $B/run-g-dense-s20 \
    --other $B/run-h-zero-s20 --old $B/run-a-tame --evidence $E
python3 scripts/zk60_native_run_gate.py --bundle $B/run-h-zero-s20 \
    --other $B/run-g-dense-s20 --old $B/run-b-zero --evidence $E

# rounds 1-3's evidence refreshed IN PLACE (the tool bytes moved)
python3 scripts/zk60_native_run_gate.py --bundle $B/run-a-tame --other $B/run-b-zero \
    --old $B/run-b-zero --evidence results/zk60_native_run_gate
  ... and run-b-zero, run-c-tame, run-d-zero into .../_planeindex,
      run-e-tame-tagged, run-f-zero-tagged into .../_tagged

# each diffed leaf by leaf against its committed record, then classified
python3 scripts/zk60_native_rg_recdiff.py $E/old/prev/<n>.json <the refreshed> \
    --out $E/old/<n>.diff.json
python3 scripts/zk60_native_rg_recclass.py $E/old/*.diff.json \
    --out $E/old/old_bundles_unchanged.json

# the witness comparison, two ways
python3 scripts/zk60_native_rg_witcmp.py --record ... --label ... --witness ... \
    --out $E/witness_comparison_dense_vs_zero.json
python3 scripts/zk60_native_rg_witcmp.py (four records) \
    --out $E/witness_comparison_round4_vs_round3.json

# the tests
python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate_s20.py' -v
python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate*.py' -v
python3 -m unittest discover -s tests -p 'test_zk60_native*.py' -v
```

`--old` names a bundle written BEFORE the plane index table (stage 15); it
is control CT-4's input. `$E/old/prev/` holds the committed records the
diffs are taken against, captured with `git show HEAD:results/...` before
the refresh.

## Files

| file | what |
|---|---|
| `run-g-dense-s20.json`, `run-h-zero-s20.json` | the whole gate record, ten stages |
| `run-{g,h}-*.log`, `*.done` | each run's stdout and exit code |
| `witness_comparison_dense_vs_zero.json` | **the headline**: 173 figures, dense against zero |
| `witness_comparison_round4_vs_round3.json` | the same four ways, against round 3's `e`/`f` |
| `old/prev/*.json` | the six committed records the diffs are taken against |
| `old/*.diff.json` | each older bundle re-run and diffed leaf by leaf |
| `old/old_bundles_unchanged.json` | those diffs classified: **0 unclassified leaves** |
| `refresh.log` | the six refresh runs' stdout |
| `tests_s20.log` | this round's own test file, **29 tests, OK** |
| `tests_run_gate_all.log` | the four RUN-gate test files, **123 tests, OK** |
| `tests_native_all.log`, `.done` | the whole native suite |

## The figures (MEASURED 2026-09-20, both new bundles, 16.5 s each)

### The group factor, derived (stage 10 — new)

| | both bundles |
|---|---|
| definition in force | **`repaired`**, selected by the bundle's own `argument.rs` pin `dd8469cb` |
| geometry, from the shape alone | `lt = lg(t_pad) = 5`, `lh = lg(h_pad) = 3`, `ldh = lg(head_dim) = 4`, **`lkv = clog2(kv_heads) = 1`** |
| slot dimensions derived and compared (against the slot AND against the shape's `slots`) | **6 of 6** — slot 08 `(5, 2, 3)`, slot 09 `(6, 2, 3)` |
| definition-draw counts derived and compared | **6 of 6** — 13 for slot 08, 12 for slot 09 |
| group points `r_g = r_h[..lkv]` derived from the REPLAY and compared with the bundle's `Tab::Eq` | **6 of 6**, 6 entries |
| coordinate lists of both private factors re-derived and compared | **12 of 12**, **135** coordinate entries, of which **69** fixed coordinates compared with a re-derived challenge |
| refusals, failures | none |

### The replay under the repaired schedule (stage 2)

| | round 3 | round 4 |
|---|---|---|
| run binding | reproduced | **reproduced** |
| transcript positions as (state, next challenge) | 375 | **375** |
| challenges re-derived and compared | 6,086 | **6,092** |
| final transcript counter | 6,918 | **6,924** |
| segment position tags, from a discarded clone | 6 of 6 | **6 of 6** |
| challenges NOT re-derived | none | **none** |
| segment byte lengths | 4,066,824 / 4,089,352 / 4,257,256 | **4,067,160 / 4,089,688 / 4,257,592** |

`+6` challenges is exactly `lkv` per bilinear slot per stage (1 × 2 × 3),
and `+336` bytes per stage is exactly the figure the S19-F1 disposition
counted.

### The terminal identity (stage 8)

**23 of 23** slots, **69 of 69** checks equal and matching the capture's own
`terminal_polynomial`, **0** open; 93 carried public tables checked against
the capture's own `len` and SHA-256, 16 per stage rebuilt, 45 structure
checks; **6** derived group points used and compared.

### THE HEADLINE — dense against zero

`witness_comparison_dense_vs_zero.json`: **173 figures compared, 153
identical.** Every one of the 20 that differ is a count of DISTINCT sampled
columns (or the pad margin, which is 256 minus it, or the pad block's exact
rank, which equals it). Those columns are drawn from the transcript, so
they move with the randomness and not with the witness.

**Not one** rank, disclosed dimension, joint figure, boundary figure,
preimage figure, terminal check, public-table count, hash-layer count,
channel count or control figure differs between the dense and the zero
witness. Against round 3's `e`/`f` the only further differences are the
repair's own cost (the six challenges, the counter, the 336 bytes) and the
group-factor figures, which exist only under the repair.

| figure | `g` (dense) | `h` (zero) | `e` (fixture) | `f` (zero) |
|---|---|---|---|---|
| `A` disclosed, each stage | 0 | 0 | 0 | 0 |
| `H` disclosed, each stage | 2 | 2 | 2 | 2 |
| boundaries / endpoints / `M` disclosed | 0 | 0 | 0 | 0 |
| `rank_P1`: `A` 74, `H` 20, endpoints 4/6 | same | same | same | same |
| each boundary on its reserved rows | 10 rows, 6 generators, rank 6, disclosed **0** | same | same | same |
| three-role joint (parts 0,0,0) | 0 = sum | 0 = sum | 0 = sum | 0 = sum |
| the whole run | 308 × 3,761, joint **6** = sum 6 | same | same | same |
| distinct opened columns (0:A) | 252 | 250 | 250 | 242 |
| pad block: distinct columns = exact rank | 249 | 248 | 248 | 246 |
| zero-data preimage, message half | 4 commitments, 0 free `Fp`/position | same | same | same |
| channels | 25, 14 open | 25, 14 open | 25, 14 open | 25, 14 open |

> **Ruling R-3** travels with every joint figure above and is in the
> records as `ruling_R3`: `joint == sum of the parts` is a CONSISTENCY
> CHECK of this model's coordinate classes, **not** evidence that the
> commitments' blinding is independent. Two distinct blinding rows whose
> values coincide score exactly like an honest run while disclosing 1,024
> field elements at this shape.

### Round 4's controls (stage 10)

**Six, all firing on both bundles** (four on a pre-repair bundle, which has
no group table to perturb):

| control | what | fires |
|---|---|---|
| **GQ-1** | stage 0, slot 08, terminal 0 changed by +1 | fails at exactly that slot and stage |
| **GQ-2** | stage 2, slot 09, terminal 1 changed by +1 | the same |
| **GQ-3** | the bundle's DECLARED eq point changed | refused by name ("the declared eq point is not `r_g = r_h[..lkv]` re-derived from the transcript"); the slot is not evaluated |
| **GQ-4** | the point THIS TOOL derived perturbed, the bundle untouched | refused too — the comparison is two-sided and neither side is the authority |
| **GQ-5** | the other definition forced on these bytes | both slots refused in every stage on the derived dims, the missing/extra group table and the coordinate lists; the other 21 slots unaffected (63 of 69 still check) |
| **GQ-6** | the PRE-REPAIR polynomial `X·Y` measured beside `eq·X·Y` | the repaired one holds 6 of 6, the pre-repair one **0 of 6**; no group factor is 1 and no terminal product is 0 |

Plus, unchanged and all firing on both bundles: the 8 terminal controls
(CT-1 … CT-8), the 6 hash-rule controls (CH-1 … CH-6) and the 6 run
controls (C1 … C6).

### What GQ-6 does NOT show, and it matters

It gives the **same** answer on the dense bundle and on the zero bundle.
That is the honest limit: finding S19-F1 is a disagreement between the
prover's CLAIM and the true sum over key-value groups, and both sides of
that need a witness, which no capture carries. What GQ-6 measures is the
arithmetic weight of the group factor in the verifier's own final check —
real on both witnesses. **From the gate's side the defect is invisible on
every witness, not only a degenerate one**, and the reason the degeneracy
hid it (prover and verifier sharing one wrong definition) is not something
a capture reader can reach.

## The six older bundles

`old/old_bundles_unchanged.json`: **0 unclassified differing leaves** on
all six, with 2,512 / 2,512 / 3,159 / 3,160 / 3,480 / 3,479 identical
leaves. Every difference is a wall clock, a tool SHA-256, the new stage 10
block, ruling R-3's note beside a joint figure, the terminal port naming
which definition is in force, the one channel reason that gained R-3's
sentence, or the `what_it_does_not_show` wording. **No rank, disclosed
dimension, challenge count, slot check or control figure moved.**
