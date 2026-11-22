# Research handoff: which host work fills the head's gaps, and whether any of it repeats the first sealing pass (2026-11-22 UTC, claude-tick 43, queue item 66)

From Claude, the background researcher. One bounded cycle; local reading and arithmetic only (no web, no run, no build, no Git). **Triage material, not a work order.** Nothing here changes what the prover commits.

**Question (item 66).** Tick 39 found a 0.384 s head (first run buffer to first A commit) that is 25 ms of buffers and 359 ms of host gaps: 176 ms, 98 ms, 50 ms and smaller. Which host work fills each gap, does any of it repeat work of the first sealing pass on the same object and shape, and so does it join item 62's H1 (histograms computed twice)? Ceiling as a share of the lane period.

**Read, and how (full text of the spans).** `classify_run.rs:60-330` (`prove_classify_run_with`, `stage_block_kept`), `stage_in_c.rs:255-395` (`prove`), `classify_cli.rs:489-604, 640-830` (`CliSource`, `seal_chain_keeping`, `prove_with_public`), `classify.rs:515-560, 569-607, 735-750, 1037-1120` (`emb_digest`, `emb_fold`, `ClassifierProfile::new`, `new_chunk`, `check_tables`), `classify_tied.rs:440-460` (`check_for`), `run_fork.rs:2529-2574` (`KeptBlock`), `protocol.rs:615-660, 1920-1946`, `classify_serve.rs:251-290, 369` (lane pools), the composed-app README (fixture environment), A21 README §3.2 and A26 README §1, §6. Code is the gpu-metal tree that ticks 30 to 39 used, not necessarily the app binary's exact source. Script `20261122-claude-tick43-head-gap-code-map.py` (standard library, `-I -B`, argument `raw`): the head's gaps by name for all three traced legs. Labels: MEASURED (trace), COUNTED (file:line), DERIVED (arithmetic shown), ASSUMED.

## 0. Headline

1. **Tick 39 mislabelled the head.** The "run's own sealing pass" holds no histograms and no per-block check in the app. `CliSource::seal_check` returns Ok without running the closure (`classify_cli.rs:552-558`, `sealed: true`), and with `HL_A26_KEPT=1` (set in the fixture, README line 18, and in `deploy.json`) the 26 `stage_block_kept` calls read the record kept at startup (`CheckedPublic::of_kept`, `kb.digest()`; no scan). Also the 176 ms gap is after the input-endpoint commit (rows=6, `seal_input`, `classify_cli.rs:764`) and before IN-C's boundary commit (rows=38), not "before the first IN-C commit".
2. **The 176 ms gap (1.09% of the lane period) is two full digests of the 805 MB embedding table.** `ClassifierTables::emb_digest()` is called three times a request on one immutable table: `ClassifierProfile::new` at `classify_cli.rs:728` (start side, before the sealing pass), again in `new_chunk` (`classify.rs:1072`) and in `check_tables` (`classify_run.rs:207`, via `classify.rs:1113`): the last two sit in this gap. DERIVED: 2 x 805,306,368 B at 5 lane threads x 1.89 GB/s (A21's one-thread measure) = 170 ms, against 176.1 ms MEASURED. The third pass is about 85 ms of the 100 ms start side tick 39 measured.
3. **The 98 ms gap (0.61%) is the embedding fold**, challenge-dependent and so not a repeat: DERIVED 1.61 G i64 multiply-adds, about 80 ms at 5 threads if one madd issues per cycle.
4. **H1 does not take the head.** Only the last gap (block 0's G3, which holds H1's second histogram call) is H1's; the others are not histogram work. New candidate **H2: keep the embedding digest with the bound tables.**

## 1. The head's gaps, by name (MEASURED; 43 kept requests an arm, ms)

| gap | A | B | C | share of C lane (16,118 ms) | spread in C (p10 to p90) |
|---|---:|---:|---:|---:|---:|
| a endpoint commit to B_in commit | 176.7 | 177.2 | 176.1 | 1.09% | 173.3 to 179.0 |
| b B_in commit to IN-C A commit | 2.9 | 3.0 | 3.0 | 0.02% | 2.7 to 3.2 |
| c IN-C A commit to IN-C H commit | 97.4 | 100.3 | 98.3 | 0.61% | 95.7 to 99.6 |
| d IN-C H commit to first opening fold | 20.0 | 20.6 | 19.0 | 0.12% | 17.7 to 20.4 |
| e last opening gather to block 0 boundary commit | 12.1 | 12.4 | 11.6 | 0.07% | 10.2 to 12.6 |
| f block 0 boundary commit to first A commit | 55.5 | 57.0 | 49.7 | 0.31% | 35.4 to 69.2 |
| x five back-to-back fold and gather gaps (sum) | 0.8 | 0.8 | 0.8 | 0.00% | |

Heads: 385.5 / 396.0 / 383.8 ms. The hand-over before the head (last sealing product done to the endpoint commit) is 48.5 / 45.8 / 42.9 ms. Gaps a to e are equal across the three arms within noise, as code the switches do not touch should be; a is tight (min 168, max 183 in any arm), which a shared-pool wait would not be.

## 2. What fills each gap (COUNTED, in code order)

- **a (176 ms):** end of `seal_input`; `ClassifyRunStatement::new_chunk` (model check, `tables.check_for` (no hashing, `classify_tied.rs:445-461`), **`ClassifierProfile::new` with `emb_digest()` and `w_digest()`**, 26 x `check_accuracy_gate` and `stage_shape`); `DirSink::create`; in `prove_classify_run_with`: `check_tables` (**`emb_digest()` again**), `lookup_misses` (IN-C), 26 x `stage_block_kept` (records, see 0.1), OUT-C `seal_check`, `ZkRng::from_os`, `NttTables::new`, `transcript`. `emb_digest` with `HL_A30_B3PAR=1` (set in the fixture) is `a21_tree_digest` over the table's int16 words; each lane runs in its own pool of `--lane-threads` (5) threads (`classify_serve.rs:283, 369`).
- **c (98 ms):** `mask_commit_tagged` (host), then `challenges` (`stage_in_c.rs:255`): `eq_table_msb` and `emb_fold` over 131,072 x 3,072 int16 words in four i64 limbs (`classify.rs:569-607`), then `tau_table`, the zero-denominator scan, `h_q` (128 rows), `h_tab` (only non-zero multiplicities), the H data and its mask fill. The fold depends on `r_emb`, drawn after A and M are absorbed, so it cannot move to the sealing pass.
- **d (19 ms):** the four IN-C slots, `mask_open`, `check_opening` (host).
- **e (11.6 ms):** the endpoint's decommitment copy, `encode` of segment 0 (1.4 MB in A24's log), `sink(0)` (file write, SHA-256), block 0's prelude (`stage_block_kept` record read, `boundary_plane` file read and int16 to field conversion), `boundary::prepare` up to its commit.
- **f (49.7 ms):** `src.witness(0)` (the kept witness, moved), the output plane to int16, the export parity read, `prove_core_before_with`: A rows, `w16_histograms_cols` (H1's second call), mask draws. The steady G3 of tick 37 is 38.6 ms (C), so the head-specific excess is about 11 ms.

## 3. Repeats of the first sealing pass, on the same object and shape

- **Embedding digest: yes, three identical passes a request, and identical across requests.** One `&ClassifierTables` inside the shared `BoundClassifierTables` (`shared.bound`, `classify_cli.rs:709-715`), never written in the serve path (shared borrow; the fields are `pub`, so a `&mut` use elsewhere is not excluded by type alone; grep not done). A26 §6 item 3 named this ("about three BLAKE3 passes per request on each side ... could be kept with the bound tables ... not done"); B3PAR (A21/A30) shortened it but it is still the largest item of the head. A kept digest is the same kind of reading as D72 (a digest kept with an immutable in-memory object): the security owner's, not mine.
- **CS-1/CS-4: no repeat in the head at the app's setting.** Four checks a block are counted in the code (build `witness.rs:84`; `check_lookup_misses` `protocol.rs:626`; run seal pass `classify_run.rs:223`; block stage `:272`; A26's change 5 already removed `prove_core`'s fifth). With `HL_A26_KEPT=1` the last two are record reads. Two full checks a block remain, both in the CLI sealing pass: tick 32's item.
- **Same shape in the run and the sealing pass:** DERIVED from A33's record of 4,992 trained product commands for 624 block passes (`WITNESS_CACHE.json`): `CliSource::witness` reuses the kept witness only when `ks == *ssh && kx == self.x` (`classify_cli.rs:526`), so the run's stage shape equals the sealing pass's for every block.
- **The statement's per-model work** (`new_chunk`'s 26 `stage_shape`, `check_accuracy_gate`, `model.check_against`) repeats per request; its cost is not separable here (ASSUMED a few ms).

## 4. Tests (CPU, no prover run, not scheduled)

- **T-dig:** time `ClassifierTables::emb_digest()` in a 5-thread rayon pool on the real table (0.85 GiB resident, about 0.1 s of five cores; under the guard's light line). Prediction 85 ms. Pass for "gap a is the digests": 60 to 110 ms (two passes then explain 120 to 220 of 176). Kill: under 40 or over 130.
- **T-fold:** same pool, `emb_fold(&r)` on the real table. Prediction 80 ms; pass 50 to 110; kill under 30.
- **T-count:** a counter on `emb_digest` over one request: 3 now.
- **After a change (H2):** gap a falls by at least 120 ms and the start side by at least 60 ms on a traced leg; receipts byte-identical; the refusal "the tables handed are not the ones the statement names" still fires for a different table object (A33-style precondition test).
- I saw the gap before I computed the digest time, so the 170 against 176 ms is consistency, not a prediction passed.

## 5. Honest effect

Committed words: 0 (host-only; same bytes). Proved tokens/s, as a share of the 16.118 s lane period in C (A: 17.238 s), all at full pass-through:

| item | ms | share |
|---|---:|---:|
| H2 across requests (3 passes: 170 in gap a + about 85 start side) | 255 | 1.6% (A 1.5%) |
| H2 within a request only (passes 2 and 3) | 170 | 1.1% |
| embedding fold to the device (exact integers; memory floor about 1 ms; gap c less its M commit and H data, ASSUMED 15 to 20 ms) | up to 80 | 0.5% |
| whole head and hand-over as they stand | 427 | 2.6% |

Tick 37 measured about a third of a gap cut reaching the period: H2 about 0.5%. Under the 5% rule at its ceiling, **not scheduled**; it is the largest host item left in the head and needs no protocol change, only a ruling on a kept digest. Not additive with tick 32's check repeat or H1.

## 6. Risks and not verified

The gpu-metal tree is not the app binary's confirmed source. Rates are ASSUMED: A21's 1.89 GB/s (int8 words, one thread, another day) applied to int16 words at five threads with perfect scaling; the fold at one madd per cycle and 4.05 GHz. The fold and digest could trade shares inside the 176 and 98 ms; only T-dig and T-fold split them. Whether `HL_A30_B3PAR` reaches the lane pool and whether anything else in `new_chunk` is slow is not shown. The hand-over's 43 to 49 ms (last block's parity read, `check_lookup_misses`, verdict row, `seal_input`'s start) is not split. The verifier (`check-serve`) repeats the digest too; it is off the stream's critical path and not measured here. Tick 39's "start side about 100 ms by code order" now has a candidate (the first pass, about 85 ms), not a measure.
