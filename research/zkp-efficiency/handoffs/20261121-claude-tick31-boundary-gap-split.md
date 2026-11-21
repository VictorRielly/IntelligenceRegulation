# Research handoff: what is in the 42.8 ms gap between the boundary-opening gather and the next block's boundary commit (2026-11-21, claude-tick 31, queue item 51)

From Claude, the background researcher. One bounded tick; local reading and arithmetic plus one small timing check (no web, no build, no prover run, no Git). Triage material, not a work order; nothing below changes a committed word, a proof byte or the verifier.

**Question.** Tick 30 found a 42.8 ms host-only gap on a lane's request thread between the 38-row gather (the opening of B(k-1)) and the next block's 38-row commit, and said only the next block's load and boundary prepare are independent of the transcript, with the split not retained. Give each phase's milliseconds from the code and any retained `HL_PB_TIMING` lines at W16R2; if none, say what run gives them.

**What was read, and how (full text of the relevant spans).** `ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io/classify_run.rs:245-315` (the per-block loop), `classify_cli.rs:185-195, 769-800` (the sink closure, `write_private`), `private_block/run_sink.rs:366-395` (`DirSink::accept`), `classify_run.rs:89-107` (`stage_block_kept`); `results/zk60_a24_app_20261107/` (`baseline_b1_gpu_prove.log`, `stream_p1/prover_phases.txt`, README section 3); `apps/proven-media/deploy.json` and `w16r2_runtime.py` for the app's settings. This checkout's `hashline/src` has no `token_io`; the gpu-metal tree is the nearest source, and tick 30 read the same code, so it is the reference here. Script `20261121-claude-tick31-boundary-gap-split.py` (reads the two retained records) and `20261121-claude-tick31-sinkbench.py` (one timing check) give every DERIVED / MEASURED number below.

Labels: COUNTED (file:line), MEASURED (record or this tick's check), DERIVED (script), ASSUMED.

## 0. Headline

1. **No W16R2 record of these phases is retained.** A search of every retained log and phase file for `sink: segment to disk`, `frame: encode segment` and `run: boundary B_(k-1) opening` finds them only at the R13 classifier profile (A24: `baseline_b1_gpu_prove.log`, `stream_p1/prover_phases.txt`) and in the 2026-10 CPU stacks; the W16R2 phase logs (`zk60_h124_witness_20261104/a1_phases.log`) are test-identity block calls with no sink, so they carry only `boundary B_k commitment` (6 to 8 ms for a 524,288-word plane). The app's W16R2 stream trace has buffers only (tick 30).
2. **The disk sink is the largest single piece and tick 30 filed it wrongly.** `DirSink::accept` is a host-only write of already-fixed bytes: create, `write_all`, `sync_all`, rename, then a SHA-256 of the same bytes (`run_sink.rs:385-392`). It needs neither the transcript nor any later device result; only the in-order hand-in (`k == lengths.len()`) matters. At R13 it is 25 ms a block (MEASURED, 26 of 26 blocks, 24 to 35 ms). So the independent part of the gap is most of it, not "partly".
3. **At the app's W16R2 settings the next block's load and statement check should be near zero** (`HL_A26_KEPT=1`, `deploy.json:134,187,240`, `w16r2_runtime.py:23`; `stage_block_kept` takes the kept record, `classify_run.rs:93`), so the gap is mostly sink + encode + opening + the host part of the boundary prepare.
4. **Candidate, same bytes out: hand the finished segment to one writer thread per lane** (bounded depth 1), so the encode-then-write no longer holds the request thread. DERIVED ceiling x1.015 to x1.035 on the lane period; below the 5% rule, not scheduled.

## 1. The phases, in the order they run (COUNTED, `classify_run.rs`)

Within one block iteration: (a) `blocks.block(k)` and `stage_block_kept` (load, CS-1/CS-4/CS-6; line 269-274); (b) `boundary_plane(k)`, convert to field words, `boundary::prepare` (the 38-row commit's host side and its device buffer; lines 276-282); (c) witness (`src.witness`, line 286); then `prove_core_with` (A commit, slots, H commit, openings); (d) `into_opening` of B(k-1) (line 298: this is the "38-row gather" buffer); (e) `encode_segment` (303); (f) `sink` (308); (g) `drop(blk)` (311). The gap tick 30 measured runs from (d)'s gather buffer to (b)'s commit buffer of the next iteration, so it contains: the host rest of (d), (e), (f), (g), then (a) and the host front of (b) of block k+1.

## 2. Milliseconds (R13 classifier; the only profile with the phases)

| Phase | A24 baseline (solo GPU, 26 blocks, median) | A24 stream_p1 (solo lane, 78 blocks, mean) | In the gap? |
|---|---:|---:|---|
| opening of B(k-1), incl. its gather buffer | 2 | 2.3 | host rest only, at most this |
| `frame: encode segment` (32.45 MB) | 3 | 2.8 | yes |
| `sink: segment to disk` | 25 (24 to 35) | 25.8 | yes |
| drop block | 0 | 0.0 | yes |
| block load + statement check (next block) | 61 | 15.3 | yes, unless the kept record is used (the app) |
| `boundary B_k commitment` (plane read, convert, prepare, commit device wait) | 9 (8 to 40) | 8.4 | host front only; the commit's own buffer is not gap |

(DERIVED, script. The baseline's 61 ms load includes reloads that the stream run's resident blocks avoid; A24's README says "the block reloads are gone" at stream_p1, which still shows 15.3 ms, which I take to be mostly `CheckedPublic::check`, ASSUMED, not isolated.) R13 solo sum with the check skipped: 2.3 + 2.8 + 25.8 + at most 8.4 = **at most 39.3 ms**, against tick 30's 42.8 ms at W16R2 under six lanes. The two figures are consistent in size only; tick 30's value is a six-lane, W16R2 measurement, mine a solo R13 one.

**What the sink is made of (MEASURED this tick, `sinkbench.py`, a 32 MB buffer, temp directory on this Mac's disk, shared machine, 8 repetitions each, medians):**

| Writers at once | write | sync (F_FULLFSYNC, as Rust's `sync_all` on macOS) | rename | SHA-256 | total |
|---|---:|---:|---:|---:|---:|
| 1 | 2.9 | 7.3 | 0.1 | 11.1 | 21.4 ms |
| 6 | 11.5 | 35.1 | 0.3 | 12.2 | 59.6 ms |

One writer reproduces A24's 25 ms for 32.45 MB within 15%, so the retained figure is the sink's own cost and not a harness artefact. **Half of it (11 ms) is the digest, a CPU job**; the flush is 7 ms alone and five times that with six writers hitting the disk together. Six simultaneous writers are the worst case; the lanes are staggered 300 ms, so the true contention is between this and the solo figure.

**To W16R2 (ASSUMED, not measured):** the sink's time scales with segment bytes; A24 README says R13 blocks commit about 1.8x W16R2's rows, so a W16R2 segment is about 18 MB (the retained W16R2 receipt size is not in a file I could find) and the sink about 12 to 14 ms alone and about 33 ms with six writers together. That puts the sink at **12 to 33 ms of the 42.8 ms gap**, with encode (about 1.6 ms scaled) and the opening's host rest filling a few ms more.

## 3. What can move, and what it is worth

Independent of the transcript and of block k's later device work, with the bytes unchanged: (i) the sink in full (write, flush, rename, digest) because the segment bytes are final after `encode_segment`; (ii) the next block's plane read and conversion (the `prepare` call takes no transcript, `classify_run.rs:281`, but uses the shared `rng`, so draw order would change, as tick 30 said); (iii) the block load and check where it is not skipped. Dependent: the opening itself and the absorbs.

Mechanism for (i), sketched only: a writer thread per lane owning the `DirSink`, a channel of depth 1, a join before `disk.lengths()` is compared with `st.segment_lens()` (`classify_cli.rs:~790`), and the existing `.incomplete` directory rename already publishes only on success (`classify_cli.rs:~795-798`), so a failed write surfaces at the next hand-in or the join and no half run is published. Host memory +18 MB (W16R2, ASSUMED) per lane. The `segment` event lines carry `elapsed_seconds` stamps that would move to the writer's clock; whether the app's progress driver reads them was not checked.

**Value.** Tick 30's closed-queue model (script of that tick; device as one server, 455 ms think time fitted) gave x1.039 on a block and **x1.032 on the lane period for a 30 ms cut** of the host gap, roughly 0.1% per ms. Applied to 12 to 33 ms: **x1.013 to x1.035** at full pass-through, a ceiling (the model has no memory contention). It is part of tick 30's 59 to 101 ms set and does not add to the before-part-ahead candidate (A36, the core-ahead branch now in test) beyond what both cannot shorten at once. Under the stop rule (5% at the ceiling) it is not scheduled. It is the smallest change on the list and has no protocol, receipt or Lean consequence; it needs only a same-receipt check.

## 4. Test, stated, not scheduled

**S1 (reading only, needs one app stream with the existing switch):** run the app's W16R2 stream with `HL_PB_TIMING=1` (diagnostic, inert otherwise) on one lane of the six; read per block `sink: segment to disk`, `frame: encode segment`, `run: boundary B_(k-1) opening`, `run: boundary B_k commitment` and `run: block load + statement check`. **Pass for the idea:** sink median at least 12 ms (at least 28% of the 42.8 ms gap). **Kill:** under 6 ms (the gain is under x1.006). The same record settles whether the load phase is near zero at the app. A bench of the idea (S2): the writer-thread variant against the inline sink on one lane, same binary, receipts byte-compared; pass is a lanes-full gain of at least 1.5% with identical receipts.

## 5. Risks and what was not verified

- No W16R2 value of any run/frame phase exists; the W16R2 column above is scaling from R13 by an assumed 1.8x byte ratio.
- The source tree is the gpu-metal copy, not necessarily the app's exact binary; `stage_block_kept` and the sink are as tick 30 read them.
- The disk bench ran on a shared Mac with other lanes active, on a temp directory that may sit on the same volume as the app's output but was not checked; macOS caching and the real writers' file sizes differ.
- The 11 ms digest assumes the retained 25 ms includes it, which the code does (`run_sink.rs:392`); it was not separated in the A24 log.
- The model's 0.1% per ms is read off tick 30's four points and assumes the gap shortens by the amount removed; six-lane memory contention could lower it, and a freed request thread could raise device queueing.
- The 15.3 ms load/check remainder at R13 stream_p1 is not isolated.

## Expected effect

Committed words per request: 0. Proved tokens/s: **x1.013 to x1.035 on the lane period at the ceiling** (sink hand-off only, same bytes), not scheduled; it overlaps tick 30's candidates and the A36 branch. Any change here that alters what is committed would need the owner's ruling, a new profile version and re-proving in Lean; this one does not.
