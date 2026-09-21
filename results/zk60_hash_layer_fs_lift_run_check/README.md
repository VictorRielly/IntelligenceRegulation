# Evidence for `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_CHECK.md`

Written 2026-09-21, 00:45 – 01:05 PDT, by the independent adversarial checker
of `docs/zkmatrix-poc/ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md`.

**Nothing here was built, proved, verified or benchmarked.** Four Python
scripts, exact integer / `Fraction` arithmetic, no dependencies, under two
seconds in total. They were written from the Rust at lane commit **`8c5922b`**
(`/home/victor/wt-zk60-block125m`, read-only) *before* reading the draft's own
script, so the agreements below are between two independent derivations.

## What they read

* the Rust source at `8c5922b`, quoted as constants with `file:line` in each
  script's header — no source file is parsed, every number is transcribed and
  attributed;
* the committed capture bundles under
  `/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-*`,
  and only their **public** members: `start_tag`, `end_tag` (32-byte
  transcript positions the verifier re-derives and compares), `profile`,
  `transcript_domain`, `transcript_program`, `opening_order`, and each role's
  `groups` / `claims` counts;
* the run gate's JSON counters under
  `/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_{tagged,s20,k4}/`
  (`final_counter`, `challenges_checked`).

**No witness, salt, pad, blinding row, private plane or receipt byte was
read.** Ruling D21 governs what a retained bundle may contain; this check read
published transcript positions and public geometry and nothing else.

## The files

| file | what it establishes |
|---|---|
| `tag_chain_recheck.py` → `tag_chain_recheck.txt` | **F-1 CONFIRMED** on all ten bundles: `end_tag(k) == start_tag(k+1)`, 6 tag fields carrying 4 distinct values at `L = 3`, tags non-constant. Plus **F-1d** (new): two runs of one profile that differ only in the hidden input have *different* `start_tag(0)`, because the header absorbs the endpoint roots — so the tags are carried by Lemma H^run, not by "the tag is public". Plus the constructor-length table for F-2 / C-R2: 46 / 48 / 51 / 56 / 57 / 58 / 59, none at the dangerous 47 (`|domain| = 35`) |
| `residuals_recount.py` → `residuals_recount.txt`, `.json` | the sampler draw counts (**687,028 / 750,540 / 9,029,804** per block; **2,093,340 / 2,283,876 / 109,728,784** per run) with the PRE-repair control reproducing the run memo's 686,990 / 2,093,226 and 9,029,742 / 109,728,040; `N_leaf` 53,248 / 53,248 / **2,473,984**; the whole residual table; the gap from the sampler to the next term (**37.30 / 37.42 / 37.47 bits**); the corrected many-runs row (10^6, not 2^20); the tree-occupancy table |
| `absorb_count_validation.py` → `absorb_count_validation.txt` | the draft's **unvalidated** absorb count re-derived from the capture's own `transcript_program` plus the pinned models plus the measured group counts: **1,129 / 1,138 / 5,932, all three exact**. Also the squeeze-channel model against the gate's measurement (325 unmodelled definition draws per stage at rung-G) and the sizing of the 125M allowance (**2.1× generous**) |
| `gate_squeeze_control.py` → `gate_squeeze_control.txt` | control **C7** re-derived on all six gate bundles: `final_counter − challenges_checked = 832 = 64·(4L+1)` at `L = 3`, exactly, everywhere; and the dense/all-zero pairs give identical counters at both rungs |

## How to re-run

```
python3 results/zk60_hash_layer_fs_lift_run_check/tag_chain_recheck.py
python3 results/zk60_hash_layer_fs_lift_run_check/residuals_recount.py
python3 results/zk60_hash_layer_fs_lift_run_check/absorb_count_validation.py
python3 results/zk60_hash_layer_fs_lift_run_check/gate_squeeze_control.py
```

Each prints its own verdict line. They depend on the two worktrees named above
and on nothing else.

## Limits, stated

* The tree figures are **expectations** over the 256 index draws with
  replacement; realised counts on real bundles move by a few per cent.
* The 125M squeeze figure is a **bound**, not a count; nothing at 125M is
  measured, here or in the draft.
* `absorb_count_validation.py` models the absorb program; it agrees with the
  draft's independent model exactly, which is evidence that both read the same
  code correctly, not a proof that the code is what either says.
* These scripts **prove nothing**. They evaluate formulas and re-read public
  fields.
