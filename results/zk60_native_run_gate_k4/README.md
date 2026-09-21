# Evidence: the RUN gate at TWO key-value group bits, 2026-09-20 (round 5)

The RUN gate run on the two bundles stage 22 of the Rust lane took at
**rung-K4** — 24 tokens, width 96, hidden 192, **12 query heads of 8 over 4
key-value heads**, `h_pad = 16`, padded head slots **{3, 7, 11, 15}**, which
is the 125M model's own head geometry. These are **the first captures this
gate has ever read with more than one key-value group bit**: `lkv = 2`, so
the repaired bilinear slots' public factor `eq(r_g, ·)` carries a TWO-element
point and the sum over groups has four terms.

Report: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §9. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`, round 5.

**Nothing here is a privacy acceptance and no file here establishes a
privacy property.** A second development shape is a second development
shape. `privacy_review_complete` is `false` in both bundles and in every
record.

**The gate cannot see the witness.** No capture carries one. "Dense" and
"zero" below are claims about the Rust lane's test that wrote each bundle
(its own README), not something measured here.

## Clock

Written 2026-09-20. The gate runs below were taken between **23:08 and
23:15 PDT** on the shared WSL laptop, CPU only, one at a time under
`flock /tmp/zk-heavy.lock`.

## Input, READ-ONLY and NOT copied here

`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`

| bundle | witness (from the capture's README, not measured) | profile | `total_bytes` | commit |
|---|---|---|---:|---|
| `run-i-dense-k4` | **fully dense public weights, a generic hidden input, all FOUR key-value groups carrying pairwise different rotated keys in every block** | `hashline-zk-mr1/private-run-rung-k4-t24-dev/1` | 46,444,960 | `3247a89` |
| `run-j-zero-k4` | the all-zero hidden input | the same | 46,418,960 | `3247a89` |
| `run-g-dense-s20`, `run-h-zero-s20` | round 4's, at rung-G (`lkv = 1`) | `…/private-run-rung-g-t24-dev/1` | 41.3 / 41.3 MB | `0426ad2` |

### The two pins the new shape moves

| file | rung-G | rung-K4 | what was read |
|---|---|---|---|
| `shape.rs` | `8f734422` | **`07a0547f`** | `git diff 0426ad2 3247a89`: **60 added lines, 0 removed** — a doc comment and `Shape::rung_k4()` calling the UNCHANGED `Shape::new`. Accepted as a read second digest in `zk60_native_rg_terminals.PINNED_IF_PRESENT` |
| `run.rs` | `65d55d25` | **`73f68221`** | **12 added lines, 0 removed** — `RUN_PROFILE_RUNG_K4` and `RunShape::rung_k4`. **Pinned by nothing**: finding K4-F2 |

`argument.rs` is `dd8469cb` on both, so both bundles select the REPAIRED
definition of slots 08 and 09 by their own source pin. `shape_run_diff.txt`
here is the verbatim diff.

## Exact commands

```
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
E=$W/results/zk60_native_run_gate_k4

# the two rung-K4 bundles.  --cross-profile names a bundle of the OTHER
# tagged profile, which is control CH-7's input (round 5)
python3 $W/scripts/zk60_native_run_gate.py --bundle $B/run-i-dense-k4 \
    --other $B/run-j-zero-k4 --old $B/run-a-tame \
    --cross-profile $B/run-g-dense-s20 --evidence $E
python3 $W/scripts/zk60_native_run_gate.py --bundle $B/run-j-zero-k4 \
    --other $B/run-i-dense-k4 --old $B/run-b-zero \
    --cross-profile $B/run-h-zero-s20 --evidence $E

# rounds 1-4's evidence refreshed IN PLACE (the tool bytes moved): the
# eight command lines are in `refresh.sh` here
bash $E/refresh.sh

# each older record diffed leaf by leaf against its committed bytes,
# then classified
python3 $W/scripts/zk60_native_rg_recdiff.py $E/old/prev/<n>.json <refreshed> \
    --out $E/old/<n>.diff.json
python3 $W/scripts/zk60_native_rg_recclass.py $E/old/*.diff.json \
    --out $E/old/old_bundles_unchanged.json

# the two comparisons
python3 $W/scripts/zk60_native_rg_witcmp.py --record ... (two K4 records) \
    --out $E/witness_comparison_k4_dense_vs_zero.json
python3 $W/scripts/zk60_native_rg_witcmp.py --record ... (four records) \
    --out $E/shape_comparison_k4_vs_rungg.json

# the tests
python3 -m unittest discover -s $W/tests -p 'test_zk60_native_run_gate_k4.py' -v
python3 -m unittest discover -s $W/tests -p 'test_zk60_native*.py' -v
```

## Files

| file | what |
|---|---|
| `run-i-dense-k4.json`, `run-j-zero-k4.json` | the whole gate record, ten stages |
| `run-{i,j}-*.log`, `*.done` | each run's stdout and exit code |
| `probe-i.log`, `probe-i.done` | **finding K4-F1's own evidence**: the first probe, which died with `KeyError: 'slot_checks_expected'` on the refusal path, and the same command passing after the repair |
| `shape_run_diff.txt` | the verbatim `shape.rs` / `run.rs` diff between the two capture commits |
| `witness_comparison_k4_dense_vs_zero.json` | **173 figures, 153 identical** — dense against zero at two group bits |
| `shape_comparison_k4_vs_rungg.json` | **173 figures over four records, 134 identical** — rung-K4 against rung-G |
| `old/prev/*.json` | the eight committed records the diffs are taken against |
| `old/*.diff.json`, `old/old_bundles_unchanged.json` | those diffs, classified: **0 unclassified leaves on all eight** |
| `refresh.sh`, `refresh.log`, `refresh.done` | the eight refresh runs |
| `tests_k4.log` | this round's own test file, **36 tests, OK** |
| `tests_native_all.log`, `.done` | the whole native suite |

## The figures, in one place

| what | figure |
|---|---|
| geometry, derived from the shape alone | `lt = 5`, **`lh = 4`**, **`ldh = 3`**, **`lkv = 2`**; padded head slots {3, 7, 11, 15} |
| slot dimensions derived and compared twice | **6 of 6** — slot 08 `(5, 2, 3)`, slot 09 `(7, 2, 3)` |
| the group point, derived from the replay and compared | **6 of 6** points, **12 entries** (was 6 at `lkv = 1`); never consumed |
| both factors' coordinate lists | **12 of 12**, **138 entries**, **66** fixed against a re-derived challenge |
| the replay | run binding reproduced, **375** positions, **6,854** challenges, counter **7,686**, **6 of 6** tags, nothing un-re-derived |
| the segments | 4,575,304 / 4,597,832 / 4,765,736 — **+508,144 B per stage** against rung-G, the same three times |
| the terminal identity | **23 of 23** slots, **69 of 69**, **0** open, both bundles |
| disclosure, UNCHANGED from rung-G | `A` 0, `H` 2, boundaries 0, endpoints 0, `M` 0; `rank_P1` `A` **74**, `H` **20**; non-data rows **246** and **108**; each boundary 10 rows / 6 generators / rank 6 / disclosed 0; three-role joint 0 over 154 generators; whole run **308 × 4,505**, joint **6** = sum 6 |
| dense against zero | **173 compared, 153 identical**; every one of the 20 that differ is a distinct-column count, a pad margin or the pad block's rank — the same twenty classes as at one group bit |
| K4 against rung-G | **173 compared, 134 identical**; every one of the 39 is a size the shape must change, a transcript-drawn column count, or a group figure that scales with `lkv` |
| controls | **13 of 13** group controls (none skipped), **7 of 7** hash-rule controls including the new CH-7, **8 of 8** terminal, **6 of 6** run |
| channels | **25**, 2 constructed, 5 derived, 4 argued, **14 open** — unmoved |
| the eight older records | **0** unclassified differing leaves; **0** bundles whose figures moved |

## Two findings about the gate, not about the bundles

* **K4-F1** — the moved-pin refusal arm of `check_terminals` returned a
  dict without the keys stage 8 and the terminal controls read, so the gate
  died with a traceback instead of reporting the refusal it had correctly
  computed. That path had never been exercised end to end because no bundle
  had ever moved a pin. Repaired; `probe-i.log` is the crash.
* **K4-F2** — `run_capture.rs`, `run.rs` and `boundary.rs` are pinned by no
  run-gate tool, and the tool's own comment claimed they were "checked by
  `zk60_native_rg_bundle`". The K4 bundles' `run.rs` moved and nothing
  noticed. The comment is corrected and the three named with their digests;
  the gap is **not closed**.
