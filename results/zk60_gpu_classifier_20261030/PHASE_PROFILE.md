# Where the seconds go: one real Shieldstral T128 classifier prove and one fresh verify, CPU path (Phase A, item 2)

Measured 2026-10-30 21:10–21:20 UTC by the GPU classifier lane (D53). Labels: [MEASURED] = one run on the shared
laptop (Core Ultra 9 185H, 8 rayon threads as the app runs it, a 0.7 GiB light job of Sol's beside it), n = 1;
[COUNTED]; [MODEL]. Raw logs: `logs/pa/p-cpu.log`, `logs/pa/v-cpu.log`; aggregated: `profile_prove_cpu.json`,
`profile_verify_cpu.json` (`tools/phase_table.py`, `tools/whole_table.py`).

## What ran

- **Job:** category `shieldstral-1.0-3b-moderate-sexual/1`, chunk 0 of Astra's public 17-id test sentence (the
  token lane's job 0), export `results/zk60_shieldstral_export_20261026/native_low_h24_t128`, 26 blocks, T = 128.
- **Binary:** the lane's CPU build `bin/zk60_classify.gcl1-cpu.bin` (fc1f3ea2…) = frozen-r19b plus diagnostic
  hooks only (`gcl1-vs-frozen-r19b.patch`: phase marks and a per-block `report` in `classify_run.rs`, `PB-CLI`
  lines in `classify_cli.rs`, all inert unless `HL_PB_TIMING=1`). The frozen tree's `HL_PB_TIMING=1` prints no
  phase table on this path (the recorder is filled but never reported), which is why the hooks were needed.
- **Fixed public entropy** (r18's `job0.bin`, through r18's `run_fixed.sh`): **the receipt equals round 18's
  recorded job-0 digests on all 30 files** (`logs/pa/bytes-cpu.json`), so the hooks moved no byte and the profile
  is of the production proof. The receipt was deleted after the record (D46).
- **Prove:** guard child wall **476.1 s**, peak RSS 8.15 GiB (cgroup 9.94 incl. page cache). The frozen binary's
  own run of the same job took 442.9 s (token round 19b, 2026-10-30 14:56 UTC, no timing hooks): the hooks and
  the shared box cost about 7% here, so read the shares, not the absolute seconds.
- **Verify:** fresh process, guard child wall **66.8 s**, peak RSS 2.32 GiB, `verify_seconds` 36.6, not-flagged,
  floor 96.

## Prove: the whole process (476.1 s)

| phase | seconds | share | runs on |
|---|---:|---:|---|
| model digest pass (`load_export`: every layer loaded, SHA-256) | 30.75 | 6.5% | CPU |
| tied tables, stage IN-C inputs, OUT-C values, endpoint seal | 7.40 | 1.6% | CPU |
| **seal_chain**: every block loaded + **witness pass 1** + int16 + parity + CS-3 | 86.32 | 18.1% | CPU |
| run sealing pass: every block loaded again + statement checks | 10.39 | 2.2% | CPU |
| stage IN-C prove (vocabulary LogUp) | 3.56 | 0.7% | CPU |
| **26 blocks** | **337.48** | **70.9%** | |
| — commit A + H + M (encode + Merkle) | 103.34 | 21.7% | CPU (GPU-capable) |
| — **witness pass 2** (`CliSource::witness`) | 70.13 | 14.7% | CPU |
| — zero-check slot 18 (F) | 44.61 | 9.4% | CPU |
| — zero-check slot 14 (D) | 30.17 | 6.3% | CPU |
| — zero-checks slots 15, 17, 16 (Q, softmax, KV) | 22.17 | 4.7% | CPU |
| — LogUp helper inverses (H rows) | 14.74 | 3.1% | CPU |
| — openings A + H + M + boundary | 14.20 | 3.0% | CPU (device folds/gathers when committed on the GPU) |
| — block load + statement check | 12.86 | 2.7% | CPU |
| — A planes → committed rows | 8.60 | 1.8% | CPU |
| — matmul slots 05–13, norms, lookups, endpoints, slot 04 | 9.86 | 2.1% | CPU |
| — A/H lookup values, histograms, mask and zero-sum rows | 4.53 | 1.0% | CPU |
| — frame encode + segment to disk, boundary B_k commit | 2.25 | 0.7% | CPU |
| stage OUT-C prove, owner file, rename, exit | 0.29 | 0.1% | CPU |

Per block (13.0 s average): commit 3.97 s, witness 2.70 s, zero-checks 3.73 s, inverses 0.57 s, openings 0.55 s.
The A commitment is 74,989,568 words and H 71,925,760 words per block [COUNTED by the recorder]; the five
zero-checks carry 67.1 M (D), 28.3 M (Q), 7.1 M (KV), 29.4 M (S) and 121.6 M (F) element-terms per block.

**Inside the zero-checks** (`PB-SLOTSTEP`, 26 blocks): masked sumcheck bodies 82.8 s (slot 18 38.5, 14 26.4,
15 7.6, 17 6.8, 16 3.5), table builds 6.7 s (slot 18 4.3), extension rounds 6.3 s (slot 14 2.4; 7.7 s over all 23 slots).

**Grouped the way the GPU port is ranked:**

| group | seconds | share of the prove |
|---|---:|---:|
| witness, both passes (≈ 70 s in seal_chain [MODEL: its block loads at the run's 0.49 s/block] + 70.1 s) | ≈ 144 | ≈ 30% |
| commitments A + H + M + B_k | 104.3 | 21.9% |
| the five element-wise zero-checks (incl. table builds, extension rounds) | 97.0 | 20.4% |
| model weights: digest pass + three block loads per block (seal_chain ≈ 12, sealing pass 10.4, run 12.9) | ≈ 66 | ≈ 14% |
| LogUp inverses + A-row conversion + lookup values / histograms / masks | 27.9 | 5.9% |
| openings | 14.2 | 3.0% |
| everything else (small slots, stages, frames, tables) | ≈ 22 | ≈ 5% |

## Verify: the whole process (66.8 s)

| phase | seconds | share |
|---|---:|---:|
| model digest pass (`load_export`) | 25.77 | 38.6% |
| tied tables re-derived from the checkpoint | 0.95 | 1.4% |
| statement door + reading the 28 segments (848 MB) | 3.42 | 5.1% |
| pre-header stage-shape check: every block loaded again | 11.79 | 17.6% |
| 26 blocks: block load + statement check (the third load) | 11.57 | 17.3% |
| 26 blocks: PCS verification (A 2.02, H 0.66, M 0.10, boundary 0.16) | 2.94 | 4.4% |
| 26 blocks: matmul slots (public weight folds) | 2.48 | 3.7% |
| 26 blocks: zero-check checks (slot 18 1.81: its public group column and support at the point; 14 0.44; 15 0.38; 17 0.16; 16 0.14) | 2.93 | 4.4% |
| 26 blocks: transcript, norms, lookups, slot 04, frame decode | 1.81 | 2.7% |
| stages IN-C + OUT-C | 0.30 | 0.4% |
| other inside the run, statement publish, exit | 3.08 | 4.6% |

**Three quarters of the verify (49 s of 67 s) is reading and hashing the public model three times.** The
cryptographic checks are about 10 s (0.39 s per block). GPU verification can only reach that 10 s; the model
passes are a run-hygiene item (load once, hash in parallel or from a pinned digest cache).

## Against the DeepProve gap study's assumptions (`results/zk60_deepprove_gap_20261030/GAP_ANALYSIS.md` §1.3)

The study used the TinyLlama T128 table (`r4/PHASES_T128.md`, 16 threads, block walls only) because no Shieldstral
table existed. Ours, as shares of the **block walls** (337.5 s) to compare like with like:

| item | study (TinyLlama T128) | ours (Shieldstral T128, 8 threads) | where they differ |
|---|---:|---:|---|
| five element-wise zero-checks | 45.3% | **28.7%** | the R13 accuracy-stack relations and a small score domain at T128; still the largest protocol phase after the commitments |
| commit + inverses + openings (A and H) | 34.0% (19.7 + 14.3) | **39.1%** (30.6 + 4.4 + 4.1) | commitments are the largest block phase here |
| witness (and A allocation) | 11.6% (8.7% witness) | **20.8%** in the blocks, plus a second full witness pass outside them (seal_chain) | the study's table started inside the block; the classifier CLI builds every witness twice |
| hiding: extension rounds, mask rows, M, endpoint slots | 12.1% | **3.5%** (11.8 s: extension rounds of all slots 7.7, A/H mask rows 2.6, M commit + open 0.4, endpoint slots 1.2) | smaller at this profile; the study's "hiding is not the gap" holds even more strongly |
| matmul slots | 0.6% | 1.4% | — |
| outside the blocks (digest pass, seal_chain, sealing pass, stages) | not in the table | **29% of the whole prove** | the run-hygiene items (speed plan L1) are a quarter of the classifier's wall clock |

The study's ranking (whole prover on the GPU first) stands. Two corrections for the classifier: the witness and the
model passes together are about 44% of the process and are not in its table, and the commitments, not the
zero-checks, are the largest block phase. Its items 2–4 (masked LogUp-GKR, wider limbs, derived linear planes) are
separate design rounds and are not part of this byte-identical port.
