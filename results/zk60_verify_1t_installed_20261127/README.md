# What one thread of the installed checker spends on a receipt (2026-11-27)

By Claude (co-coordinator). One measured run [MEASURED, this Mac, one run], read by a rule that was pushed to the
coordination file before the run (entry of 2026-11-27T12:04:36Z, commit `3a2b5ef2f`).

## What was run

- **Binary:** a byte-identical copy of the verifier binary the app pins for its profile `shieldstral-mac-fast-w16r2`
  (`zk60_classify.a30a31`; the copy's SHA-256 is compared with `apps/proven-media/deploy.json` before use). The
  installed file is read, never executed. It is the app's pinned binary, older than the head of the repository.
- **Receipt:** a copy of one retained public receipt of the installed profile `W16R2_SHIELD_T128_H24`
  (`6a8ff87cb1ec6e17fcdf4e9c04ae1cb3-c0`: one public 14-token development post, one category, 28 segments,
  669,561,472 bytes, 26 trained blocks).
- **Command:** the app's own `verify` call (seven flags and `--dev-w16r2-public-content-only`), with
  `HL_PB_TIMING=1`, which makes the checker print one time table for every block.
- **One thread:** `RAYON_NUM_THREADS=1`. The command builds no pool of its own, so every row is one thread's work.
- **Guard:** class cpu, 12 GiB asked. The process ran 73.8 s and peaked at 2.29 GiB.
- **Nothing of the app was touched:** the export and the models directory were read in place and their listings
  (path, size, modification time) are the same before and after; the private refusal log was redirected to a
  scratch directory and nothing was written there; no service was contacted.

`run_v1t.py` is the harness, `read_v1t.py` the reader. A smoke at the default pool came first (label `smoke`), read
for its structure only (`structure_smoke.txt`); the guard's record gives 41.0 s for that process.

## The reading (label `t1a`, `reading_t1a.txt`)

All eleven structure checks pass (26 tables of 30 rows, the expected sizes, one `classified` event, no unaccounted
time). Per block, the median over the 26 tables, with least and most, in ms:

| what | median | least to most |
|---|---|---|
| rows of slots 0, 1, 4, 14 to 19 (they hold the public tables) | 52.5 | 50.7 to 69.5 |
| rows of slots 5 to 7 and 10 to 13 (the seven weight folds) | 139.5 | 138.1 to 183.3 |
| the other seven slots | 1.6 | 1.4 to 2.1 |
| setup (transcript header and the A and H roots) | 48.6 | 47.8 to 64.2 |
| opening M | 2.8 | 2.7 to 3.7 |
| opening A | 67.4 | 66.9 to 89.4 |
| opening H | 27.6 | 27.3 to 36.3 |
| **checking a block's proof** (setup, 23 slots, M, A, H) | **338.9** | 337.2 to 444.5 |
| boundary opening | 5.2 | 5.2 to 6.9 |
| block load and statement check | 390.0 | 388.6 to 506.6 |
| frame decode | 5.2 | 5.1 to 6.9 |
| wall of a table | 740.0 | 737.0 to 962.0 |

**By the rule: BELOW THE BAND.** Research ticks 70 and 71 had estimated the rebuilding and evaluation of the public
tables at 85 to 197 ms a block at one thread for this profile (assumed rates). The rows that contain that work, and
more, are 52.5 ms. So the estimate was too high even at its lowest rates. Read as an upper bound, the public tables
cost at most 5.5 ns an entry (52.5 ms over 9,625,600 entries).

## Where the 73.8 seconds went

| part (the names are the binary's own) | seconds |
|---|---|
| `load_export (the digest pass)` | 37.88 |
| `tied classifier tables` | 1.66 |
| `statement door + segment reads` | 0.44 |
| `pre-header stage-shape check (every block loaded once)` | 11.81 |
| the two stage checks | 0.43 |
| 26 tables: block load and statement check rows | 10.96 |
| 26 tables: checking the block proofs | 9.62 |
| 26 tables: boundary and frame rows | 0.29 |

The first, fourth and sixth lines are three passes over the public model export: 60.6 s, 82% of the process. Checking
the 26 block proofs is 9.6 s, 13%. What each pass reads and computes is by the names the binary prints; the code
behind them was not read for this record.

## Limits

- **One run.** Tables 10 to 17 ran about 30% slower than the rest (walls 0.835 to 0.962 s against 0.74 s), eight in a
  row; the cause is not known. The median is not affected.
- **One thread, standalone.** This is not the app's check latency: its check lanes run four threads and keep the
  export resident. It is one thread's work on a cold command.
- **The pinned binary,** not today's code.
- **One receipt** of a 14-token post in one category.
- The rows of slots 0, 1, 4, 14 to 19 hold more than the public tables, so 52.5 ms is an upper bound on them.
- Nothing here moves proved tokens a second: checking happens after the clock.
- The 275.5 ms a block of 25 November (`results/zk60_verify_threads_20261125/`) is another object (8B shape, diagonal
  test weights, a test binary); the two figures are listed side by side, not compared.

## Files

- `run_v1t.py`, `read_v1t.py`
- `structure_smoke.txt`, `reading_t1a.txt`: the reader's outputs
- `raw/`: for each label the checker's log, the guard's record, the runner's results and the guard status before
