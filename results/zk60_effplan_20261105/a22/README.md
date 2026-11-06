# A22: production's resident-model stream form, `stack-serve` (2026-11-06)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A22. Victor approved it as ruling **D70**
(`docs/zkmatrix-poc/ZK60_DECISIONS.md`). It was built on perf `3f25ef9a` (A20 merged, plus D70). perf `2eb26c7f` (A21
merged) was then merged in. Every measurement here is on the merged tree.

Labels: [MEASURED] a number from a log in this directory; [CODE] read from the source; [INFERRED] derived from measured
numbers; [ESTIMATE] a judgement, not a measurement.

The timing runs:
- shape: W16R2 8B T128, 32 blocks, N = 6 fork workers;
- settings: `HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0`, a witness budget of 32 GiB (the Mac's default);
- forms in force: A13's window off, A19's shared blocks, A20's and A21's defaults;
- each stage was one guarded job on the shared M3 Ultra.

Every timing step waited for a quiet GPU: no running `ds4-bench`, matched by process name. Each step recorded whether
one was running at its end.

The model is the D55 harness's synthetic block: diagonal public weights at the 8B geometry. It is served as a resident
model whose startup load copies the block and hashes its record at every layer. There is no trained 8B export on the
Mac, so the startup of a real 8B export was not measured.

## 1. Plain summary

- **`stack-serve` is production's D55 path as a long-lived process.** It is `stack-prove --d55-workers N` with the
  export loaded and checked once. Each request runs `d55_seal_and_prove` itself, so every step and every refusal is
  `stack-prove`'s, in its order. Request r + 1's sealing pass runs beside request r's fork run, and at most one sealed
  request waits for the prover.
- **The stream** [MEASURED, stage 2 (s2), merged tree, 4 passes, alternating order]:

  | arm | steady tok/s | amortized tok/s | latency of its first request | peak footprint |
  |---|---:|---:|---:|---:|
  | one request (`serve1`) | | 18.27 | 7.01 s | 69.0 GiB |
  | **a stream of 4 (`serve4`)** | **29.23** | 24.88 | 7.45 s | 78.8 GiB |
  | a stream of 8 (`serve8`) | 28.98 | 26.72 | 7.41 s | 78.9 GiB |
  | the harness's stream of 4 (H124d), same tree | 32.53 | 28.61 | 6.09 s | 73.2 GiB |

- **The startup** [MEASURED]: 0.583 s for the synthetic 8B model's 32 layers. The footprint went 1.5 → 8.8 GiB (the
  resident model). A real export's startup also reads and hashes its files, and was not measured.
- **The target of 33 steady was not reached.** The default reaches 29.23 tok/s, 11.3% below the harness's stream.
  - The stream is bound by the prover turn: each request's prove call takes 4.39 s, against the harness's 3.94 s.
  - Where the 0.44 s per request goes (§5.3) [INFERRED]:
    - about 0.20 s is the preflight, mostly CS-6 re-hashing 32 distinct blocks;
    - about 0.21 s is the forks running slower beside production's heavier sealing pass;
    - about 0.03 s is the commit phase.
- **The two forms that are off by default:**
  - `HL_A22_DIGEST_AHEAD` (`dig1`) gives +4.9% steady, 4 of 4 pairs, reaching 30.67 tok/s. Ruling D72 now permits it
    (the argument is in §5.4). It stays off by default in this merge, because stage 9 ran with it off. Lane A23's
    shared blocks supersede it.
  - A13's window at 16 (`ahead16`) gives +1.7% steady, 3 of 4 pairs, at +5.8 GiB. That is inside the noise, so it stays
    off (decision (e)).
- **The bytes** [MEASURED]:
  - Every request's statement identity, statement and frame list are `stack-prove`'s, but for the endpoint policy, which
    is fresh by design.
  - A fresh `stack-verify` accepts every receipt.
  - 85 served 8B receipts are 818,728,672 B each.
  - Heads replay, and interior forks equal whole forks.
  - Two requests on the same input share no salt, mask or frame.
  - A refused request mid-stream creates nothing, and the stream carries on (§4).
- **Acceptance on the final tree:** §6.

## 1a. The headline numbers, labelled

| quantity | value | label |
|---|---:|---|
| steady proved tok/s, a stream of 4 (production's server) | 29.23 (28.58 to 29.51) | MEASURED, s2, 4 passes |
| steady proved tok/s, a stream of 8 | 28.98 (28.84 to 29.07) | MEASURED |
| amortized proved tok/s, 4 / 8 | 24.88 / 26.72 | MEASURED |
| one request's latency (`serve1`, warm) | 7.01 s = 18.27 proved tok/s | MEASURED |
| each later request's own time, sealing turn to result (`serve4`) | 9.04 s | MEASURED |
| the startup (resident model, synthetic 8B, 32 layers) | 0.583 s, footprint +7.3 GiB | MEASURED |
| peak footprint of a stream of 4 / 8 | 78.8 / 78.9 GiB | MEASURED |
| the harness's stream of 4, same tree | 32.53 steady, 28.61 amortized | MEASURED |
| `dig1` in a stream of 4 | 30.67 steady (+4.9%), 25.82 amortized | MEASURED |

## 2. The interface

```
zk60_trained_block stack-serve --export DIR --d55-workers N --d55-test-receipt-not-for-publication
                               [--layers A..B] [--label L] [--rope-from-export] [--dd] [--witness-cache-gib G]
```

- **Flags.** These are `stack-prove`'s model and D55 flags, with no flag for a request.
  - `--d55-workers N` is required.
  - While `run::fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is false, `--d55-test-receipt-not-for-publication` is required too (D60 review F3).
  - `--verify-in-process` is not accepted. A run's statement is published only by `stack-verify`, as with `stack-prove`'s default.
- **Environment.** These are `stack-prove`'s switches, plus two new ones:
  - `stack-prove`'s: `HL_GPU`, `HL_GPU_REQUIRED`, `HL_D55_AHEAD` (A13's window, default 0), `HL_A19_SHARE`, `HL_A20_*`, `HL_A21_*`, `HL_SEAL_POOL`, `HL_D55_FORK_POOL`, and `HL_OWNER_PRIVATE_DIR` (the private refusal log);
  - `HL_A22_LANES`: default 2, range 1 to 4. It is how many requests the stream holds at once;
  - `HL_A22_DIGEST_AHEAD`: default 0. D72 permits 1; it stays off by default in this merge (§5.4).
- **stdin: one request per line.** A request is a JSON object, parsed by the crate's strict parser:
  - `{"out": "/runs/r17", "seq": "public"}`, where `seq` names the export's `seq_<ID>/`;
  - or `{"out": "/runs/r17", "seq_dir": "/owner/private/seq17"}`, a prover-private directory (privacy review P-5);
  - an optional `"id"` (text, at most 256 bytes) is echoed in the result;
  - blank lines are skipped, and a line may be at most 64 KiB;
  - an unknown field, or both or neither of `seq` / `seq_dir`, is a bad request;
  - `out` must not exist, and neither may `<out>.unverified-statement`.
- **stdout: one JSON line per event, in request order.** `request` is the 0-based count of non-blank lines.
  - `{"event":"serve-start", ...}` comes once, after the startup. It gives the variant, layers, blocks, statement identity, startup seconds, workers, budget, lanes, window, digest-ahead and the test-receipt flag.
  - One `{"event":"served","request":q, ...}` line per request:
    - `"status":"proved"` gives `out`, `statement_dir` (`<out>.unverified-statement`), `statement_identity`, `receipt_bytes`, `frames`, and `d55_test_receipt_not_for_publication`. It also gives the seconds of the sealing pass, the prove call, the receipt write, the run directory to the written receipt (`prove_run_seconds`), the wait for the prover, the latency from the line's arrival, and `vmhwm_mib` (`null` on macOS);
    - `"status":"refused"` is D65(2)'s constant refusal, `"command":"stack-serve","error":"refused","detail":"owner-private"`, with the request index and its `id`. The detail goes only to `refusals.log` in the owner's private directory;
    - `"status":"bad-request"`, `"error":<text>`, is an argument error about the line's form. Nothing has been read at that point.
  - `{"event":"serve-end","requests":n,"proved":p,"refused":r,"bad_requests":b, ...}` comes once, at the end of stdin.
- **Exit codes.** 0 after the stream. 1 if the startup is refused (the constant event; the detail in the private log). 2 for bad arguments.
- **A supervisor:**
  1. starts the process and waits for `serve-start`;
  2. writes request lines and reads result lines;
  3. for each `proved` line, publishes with `stack-verify --export <a verifier's copy> --artifact <out> --expect-statement <statement_identity> --d55-workers N`. That command writes `<out>/statement/` itself, as for `stack-prove`;
  4. closes stdin to end the stream.
- **HARD RULE: ONE DATA OWNER PER PROCESS.** This is the security owner's decision (a) of 2026-11-06, and it holds until a ruling.
  - A request's latency reveals how long the request before it held the prover, and whether it was refused early (§7.5).
  - All of one server's requests must therefore come from one data owner. Run one `stack-serve` per owner.
  - The server does not enforce this. The operator must. The CLI help says so too.

## 3. The design

**Startup, once** (`Resident::start`) [CODE]:
- `export_serve_of` makes `stack-prove`'s admission checks in its order, except the per-request ones: the label, the witness budget, the D55 workers, D60 review F3's admission, the GPU's liveness, the export, `--dd`, the layers, `--rope-from-export`, the run constants and the shape.
- Every layer is then loaded with every check of the sealing pass's load: the export's array SHA-256s, the tables, the padded words, the record and its block digest. The loads run 4 at a time, and the first refusal in layer order is returned.
- The model's statement is made from those records.
- The resident model holds each layer's block, record, manifest SHA-256 and RoPE note, and the statement's identity. It holds public data only.
- Any failure refuses the start.
- The GPU context, the sealing pool and the fork pools are the process's own statics, made at first use and kept.

**Each request** (`Resident::prove_one`) [CODE]:
1. The run directory must be new.
2. `trained_block::d55_seal_and_prove` runs unchanged over `Served`, a `StackModel` view:
   - its `load_layer(k)` copies the resident layer's block and record;
   - its `seq` reads the request's own private sequence;
   - its `statement_of_records` refuses a statement that is not the startup's, before the run header;
   - everything else is the startup model's.
3. So every step of the D55 path runs in its order: the sealing pass, the model's statement, the endpoints, the bound statement, D60's door, `Planned::check`, the run directory, the fork run (preflight, commit, forks, join), the receipt write and the not-for-publication marker.
4. Then come `stack-prove`'s steps after its D55 proof: the prover's self-report check, which removes the run if it fails, then the four files of `<out>.unverified-statement/`.

**The stream** (`serve_stream`) [CODE]:
- A reader thread takes the request lines. Lanes take the next request each (`HL_A22_LANES`, default 2).
- **Two turns, each taken in request order:**
  - the **sealing turn**, from the start of the sealing pass to the end of the plan's check;
  - the **prover turn**, from the run directory's creation to the prove call's return.
  - `D55Run.turn` carries them into `d55_seal_and_prove`: `sealed()` just before `create_dir`, `proved()` right after `planned.prove(...)`, whether it returned Ok or not.
- **Overlap.** Request r + 1's sealing pass runs beside request r's fork run. At most one sealed request waits for the prover, and at most two requests are held at once.
- The receipt write, the marker and the statement files are outside both turns, beside the next request's prove call.
- **A refused or bad request** leaves its turns on every path (on drop). The stream carries on.
- The calling thread prints the results in request order.

**What changed in existing code** [CODE]:
- **`d55_seal_and_prove`:** the two turn calls (`D55Run.turn` is `None` for `stack-prove`).
- **`stack_prove_d55`:** its four statement-file writes moved, unchanged, into `write_unverified_statement_files`.
- **`seal_chain`:** one line. `hand.block(k, cur.blk, &digests[k])` hands the record's digest with the block. `SealHand`, `NoHand` and `D55Hand` follow that signature.
- **`StackModel::fresh_digests`:** default `false`.
- **`run_fork::SealedBlocks`:** digest cells, `put_digested`, and `digest_of`, which hashes when no digest is kept, as before.
- **Effect on `stack-prove`:** `turn` is `None` and `fresh` is `false`, so `stack-prove`'s path is the old one, step for step and byte for byte.

**`HL_A22_DIGEST_AHEAD` (off by default; permitted by D72).**
- With it on, `Served::load_layer` digests each request's copy of each block where the copy is made (on the sealing pass's loaders), and carries that digest in the copy's record.
- The request's model statement, made from those records, must still be the startup's.
- The shared blocks keep each digest beside its block, and the preflight's CS-6 compares the kept digest with the statement's instead of hashing the block again.

## 4. The byte evidence [MEASURED]

**Why no byte can move** [CODE]:
- A request runs `d55_seal_and_prove` itself.
- Its model view's loads hand out copies of the very blocks and records the startup's checked loads made. The startup's
  loads are `stack-prove`'s loads (the same `TrainedExport::load_layer`).
- Its private sequence is read by the same `SeqSource::load`.
- So each request's sealing pass reads the same words as `stack-prove`'s on that input. Its statement is the same
  function of the same records. Its fork run is the same code on the same statement.
- What differs between two runs is only the fresh randomness: the endpoint commitments, the boundary commitments and every
  fork's coins. `stack-prove`'s receipts differ from each other in the same way.

**Stage 1, on the merged tree** (`s1.progress`; stage 0 ran the same suite tests on the CPU before the merge):
- **The R13 export through the server**
  (`a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal`): on the CPU and on the
  Metal device, both pass. It covers:
  - **The sealing pass.** The server's equals `stack-prove`'s word for word: identity, block digests, every record, every
    sealed plane, the endpoints, the stage shapes, and every kept witness. This holds at budgets everything and nothing,
    with the digests ahead off and on.
  - **A stream of 10 requests** (§7). The results come out in request order. Both turns are taken in request order, with
    at most 2 requests held at once.
  - **4 proved requests on the same input.** Each is verified by a fresh `stack-verify` (a verifier's copy of the export,
    `--d55-workers`):
    - statement identity `10a8fd14f6e75d8c…`, `stack-prove`'s;
    - `statement.json` byte for byte `stack-prove`'s, but its `expected_io` line;
    - `segments.json`'s names and lengths `stack-prove`'s;
    - each receipt 62,099,008 B, `stack-prove`'s;
    - the not-for-publication marker present.
  - **Seeded lanes**, window 0 and 2 with the digests ahead off, and window 0 and 4 (= L) with them on. In each, proved,
    refused (parity), proved:
    - each receipt is verified by a fresh `stack-verify`;
    - its head equals the commit phase replayed with the seeded generator;
    - both interior forks equal those forks proved whole on the receipt's own statement;
    - the forks parked equal the window;
    - the refused request made 0 or 1 parts and left 0 alive.
- **The resident synthetic W16R2 rung on Metal**
  (`a22_the_resident_synthetic_rung_stream_replays_with_the_window_off_and_on_on_the_device`) passes. Its arms are window
  0/2/4, lanes 1 and 2, digests ahead off and on. The stream is honest, lie at layer 1, honest, honest. In each arm:
  - every receipt (61,301,184 B) verifies from its run directory;
  - every head replays, and the interior forks equal whole forks;
  - the lie is refused before the run header, creates nothing, and leaves 0 parts alive.
- **The resident 8B synthetic stack on Metal** (`a22_the_resident_8b_stream_replays`, L = 4) passes, with the same checks.
  Each receipt is 102,772,480 B.
- **CS-6 with the digests ahead** (`a22_cs6_takes_the_digest_kept_with_its_block_and_refuses_a_wrong_one`, the suite):
  - a fork run over blocks kept with their own digests proves and verifies;
  - a wrong kept digest is refused by the preflight: `private run: ruling CS-6 — block 1 handed to the run is not the
    block the run statement names …; refused before anything is absorbed`.

**Stage 2, the A/B:**
- All 85 served 8B receipts are 818,728,672 B. That is 4 passes of 1 + 4 + 8 + 4 + 4 requests, and the cold request.
- Each arm's first pass, and the cold request, were verified from their run directories: 22 receipts.
- The harness's 4 receipts of its first pass also verified.

**Stage 9** repeats stage 1 on the final tree (§6).

## 5. The measurements [MEASURED, stage 2, `s2_table.md`, `s2_ab.log`]

All are on the merged tree: W16R2 8B T128, 32 blocks, N = 6, 4 passes, the arm order reversed in odd passes, quiet GPU
(no `ds4-bench` at the start or the end).
- One resident model started once: 0.583 s, footprint 1.5 → 8.8 GiB.
- One cold request first: 7.489 s.
- `steady` = (R − 1) · 128 / (the last completion − the first).
- `amortized` = R · 128 / the last completion.
- Every request's line arrives at t = 0.

### 5.1 The arms

| arm | steady tok/s, mean (min, max) | amortized tok/s, mean (min, max) | first request's latency | mean latency from arrival | peak footprint |
|---|---:|---:|---:|---:|---:|
| `serve1` | | 18.27 (17.98, 18.43) | 7.008 s | 7.008 s | 69.0 GiB |
| `serve4` | **29.23** (28.58, 29.51) | 24.88 (24.59, 25.12) | 7.445 s | 14.133 s | 78.8 GiB |
| `serve8` | 28.98 (28.84, 29.07) | 26.72 (26.61, 26.89) | 7.410 s | 18.601 s | 78.9 GiB |
| `harness4` (H124d, the same tree) | 32.53 (32.38, 32.73) | 28.61 (28.40, 28.77) | 6.088 s | 8.845 s* | 73.2 GiB |
| `serve4+dig1` | 30.67 (30.02, 31.14) | 25.82 (25.59, 26.16) | 7.308 s | 13.689 s | 78.7 GiB |
| `serve4+ahead16` | 29.73 (29.41, 30.21) | 25.00 (24.73, 25.27) | 7.562 s | 14.179 s | 84.6 GiB |

\* The harness measures latency from each request's sealing start, not from its arrival (§5.5).

- **The original harness test's stream on this tree, for reference** (`s2_d55.log`): 32.53 steady, 28.56 amortized.
  Proof only: best 3.953 s; one request from its input: best 5.489 s.
- **The footprint** is the process's physical footprint, sampled every 10 ms.
  - It starts each stream at 29 to 31 GiB in pass 0, and at 51 GiB later: the allocator keeps memory freed earlier.
  - The rise over a stream's start, in pass 0, is the comparable figure: `serve1` +19.7, `serve4` +29.1, `serve8` +28.0,
    `harness4` +22.6, `dig1` +29.0 GiB.
  - The server holds about 6.5 GiB more than the harness in a stream of 4 [INFERRED]. That is mostly the request's block
    copies (§5.3(a)).
  - `serve4` and `serve8` peak alike: the stream is bounded at two requests.

### 5.2 Paired changes (4 passes, both orders)

| comparison | steady | amortized |
|---|---|---|
| `serve4` → `harness4` | **+11.3%** (4 of 4; +10.4% / +12.3% by order) | +15.0% (4 of 4) |
| `serve4` → `serve4+dig1` | **+4.9%** (4 of 4; +4.6% / +5.3%) | +3.8% (4 of 4) |
| `serve4` → `serve4+ahead16` | +1.7% (3 of 4; +2.0% / +1.5%) | +0.5% (2 of 4) |
| `serve4` → `serve8` | −0.8% (1 of 4) | +7.4% (4 of 4) |

### 5.3 Where each request's time goes, and the gap to the harness

The means of each request's parts. "Later" means every request of a stream but its first. "After the prover" is the
receipt write, the marker, the statement files and the result line.

| arm | requests | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write | after the prover | own time, sealing turn to result |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `serve1` | 4 | 2.514 | 0 | 4.183 | 0.316 | 0.207 | 3.584 | 0.076 | 0.223 | 0.296 | 7.007 |
| `serve4` | first, 4 | 2.479 | 0 | 4.625 | 0.342 | 0.307 | 3.896 | 0.081 | 0.245 | 0.327 | 7.445 |
| `serve4` | later, 12 | 3.940 | 0.349 | **4.393** | 0.280 | 0.240 | 3.789 | 0.084 | 0.249 | 0.324 | 9.042 |
| `serve4+dig1` | later, 12 | 3.921 | 0.239 | 4.178 | **0.118** | 0.230 | 3.748 | 0.082 | 0.216 | 0.284 | 8.668 |
| `serve4+ahead16` | later, 12 | 4.013 | 0.324 | 4.322 | 0.281 | 0.257 | 3.701 | 0.084 | 0.235 | 0.310 | 9.007 |
| `serve8` | later, 28 | 3.832 | 0.349 | 4.425 | 0.274 | 0.252 | 3.818 | 0.081 | 0.245 | 0.321 | 8.963 |
| the harness, proof only (`s2_d55.log`, 2 passes) | | | | 3.92 to 4.08 | 0.081 to 0.085 | 0.207 to 0.211 | 3.55 to 3.71 | 0.078 to 0.081 | | | |

**The stream is bound by the prover turn** [INFERRED]:
- Every later request waits about 0.35 s for the prover, so the prover is never idle.
- `serve4`'s period, 128 / 29.23 = 4.379 s, is its prove call (4.393 s).
- The harness's period, 128 / 32.53 = 3.935 s, is its own proof-only call.
- The gap is therefore the prove call's: **0.444 s per request**. It splits as follows.

1. **The preflight: +0.20 s** (0.280 against the harness's 0.083).
   - The harness's `RepeatBlock` hashes its one block once. Production's CS-6 hashes 32 distinct blocks in every
     request's preflight, and its CS-1/CS-4 scan reads 32 distinct objects.
   - `dig1` takes the preflight to 0.118 s. So CS-6's re-hash is about 0.16 s of it, and the scan of distinct objects
     the remaining 0.035 s.
   - This part is on the critical path. `dig1` recovers +4.9% (§5.2).
2. **The forks: +0.21 s** (3.789 against 3.584 for `serve1`, whose forks are the harness's 3.55 to 3.71 with nothing
   beside them).
   - The cause is contention with the next request's sealing pass, which runs beside the whole prove call.
   - Production's sealing pass is heavier than the harness's. It takes 2.51 s alone (`serve1`) against 1.53 to 1.57 s,
     and 3.94 s beside the forks against 2.7 to 2.9 s.
   - It does what the harness's pass does not: each layer's copy from the resident model, CS-3's lookup-miss check, the
     parity check and the production builder.
   - Over 4 requests the server used 243 user + 73 system CPU-seconds, against the harness's 189 + 36. That is about +13
     user and +9 system CPU-seconds per request.
3. **The commit phase: +0.03 s** (0.240 against about 0.21). The previous request's receipt write and statement files,
   0.32 s after the prover leaves, run over this request's preflight and commit.

The suspects named:
- **(a) The per-request copies of the resident layers.**
  - Bytes: each request copies 32 blocks of about 243 MB of padded words each [MEASURED by A20: 243,277,824 B; tables
    and accuracy data add under 1%], about 7.8 GB per request [INFERRED].
  - Time: about 3.9 ms per block alone (A20's profile), about 0.125 CPU-seconds per request, on the sealing pass's four
    loader threads, beside the forks [INFERRED].
  - The fresh 7.8 GB is faulted in for every request. That is a likely part of the +9 system CPU-seconds per request and
    of the forks' +0.21 s [INFERRED; not separately measured].
  - The copies are off the critical path (the sealing side has 0.35 s of slack) but share the memory system with the forks.
  - They are also most of the +6.5 GiB of footprint.
- **(b) The CS-6 re-hash: 0.16 s per request, on the critical path, inside the preflight.** `dig1` moves it to the
  loaders: +4.9% steady (§5.2).
- **(c) The receipt write: 0.249 s per request** (16 writers, `F_FULLFSYNC` per frame).
  - It runs outside the prover turn, beside the next request's preflight and commit.
  - The harness writes nothing. Its effect is inside (3): about 0.03 s on the commit, and on the preflight beside it
    [INFERRED].
- **(d) The statement files: about 0.075 s per request** (the marker, the four statement files with their syncs, the
  result line: 0.324 − 0.249). They run outside the prover turn, with (c).
- **(e) The reader and lane threads.**
  - The reader blocks on a channel of 2 lines; it costs nothing measurable.
  - The lanes are the harness's two threads (a sealing side, a prover), plus the sealing pass's four loader threads
    (A20) beside the six fork pools.
  - Their contention is the sealing pass's own CPU, counted in (2) and (a).

**Could the resident blocks be shared instead of copied, without changing a byte?** Yes [CODE].
- Every consumer of a block reads it by shared reference:
  - the witness build (`witness_for_block(&ssh, &cur.blk, &x)`);
  - CS-3's check (`check_lookup_misses(.., &cur.blk, ..)`);
  - the preflight and every fork (`ForkBlocks::get(k) -> &BlockPublic`).
- The copy exists only because of an ownership type. `StackModel::load_layer` returns an owned
  `TrainedLayer { blk: BlockPublic }`, which `seal_chain` moves into `SealHand::block` and on into
  `SealedBlocks`' `OnceLock<BlockPublic>`.
- The change: `TrainedLayer.blk` and the `SealedBlocks` cells become `Arc<BlockPublic>`. A fresh load is wrapped once
  (no copy); the server hands out `Arc::clone` of the resident block. That would read the same words, so no byte can move.
- A13's parts check the blocks object's address, which this does not touch.
- CS-6 could then compare the startup digest of the very object being proved. That is A19 §9's "record kept per manifest
  digest" form and needs the same ruling. The per-request copy, its faults and its 7.8 GB per in-flight request would
  go too.
- [ESTIMATE] `dig1`'s +4.9%, plus a part of the forks' +0.21 s: about +6 to +9% steady, so about 31 to 32 tok/s.
- It is not built here. It changes `TrainedLayer`, which the loader, A19's synthetic model and several tests construct,
  and its CS-6 half needs the ruling.

### 5.4 `dig1`: the equivalence argument (for the security owner's decision (d), ruled as D72)

**Ruled: D72** (the decisions register, perf `17b83cf4`), accepted on this argument.
- D72 allows a kept digest on the prover side when all four of these hold:
  - it is computed by `BlockPublic::digest` over that very object, after the object's last write;
  - it is stored inseparably with the object;
  - the object cannot change afterwards;
  - a mismatch still refuses by CS-6's name.
- The verifier is unchanged.
- `dig1` meets all four (below), so D72 now permits `HL_A22_DIGEST_AHEAD=1`.
- **It stays off by default in this merge**, because the acceptance run (stage 9) ran with it off.
- The next lane (A23) shares the resident blocks by reference, with CS-6 on their startup digests under D72. That form
  supersedes `dig1` (§5.3).

**What is digested, when, and on which thread** [CODE]:
- With `HL_A22_DIGEST_AHEAD=1`, `Served::load_layer(k)` (`trained_block.rs`) runs, for each request and each layer:
  ```
  let blk = r.blk.clone(); let mut record = r.record.clone(); record.block_digest = blk.digest();
  ```
  - `blk` is the request's own copy of resident block `k`.
  - `BlockPublic::digest` is D2: the same function CS-6's default `ForkBlocks::digest_of` calls. On the merged tree it
    is A21's parallel tree under `HL_A21_B3PAR`, with the same bytes.
  - The digest runs right after the copy is made, on the thread running the load: one of the sealing pass's loader threads
    (`LoadAhead`, A20), or the sealing lane itself at `HL_A20_LOADS=0`.
- The copy then moves, by value with no clone, inside the `TrainedLayer` into `seal_chain`.
  - `seal_chain` reads it only by `&` (the witness build, CS-3's check).
  - It then pushes `record.block_digest` to the run's digests, and hands the copy and `digests[k]` (that same value) to
    `D55Hand::block`, which calls `SealedBlocks::put_digested(k, blk, digest)`.
  - `put_digested` sets the block's cell and its digest's cell together. Each is a `OnceLock`, set once; a second set
    is an error.
- The preflight's CS-6 then reads `SealedBlocks::digest_of(k)`, which returns that kept digest.

**Why nothing can change the object between the digest and the preflight** [CODE]:
- From the digest to the `put`, the copy has one owner at a time: the load, then the `TrainedLayer`, then `seal_chain`'s
  `cur`, then the cell. The only uses are moves and `&` borrows. Rust's ownership excludes any other reference, and so
  any write.
- After the `put`, `SealedBlocks` hands out `&BlockPublic` only (`ForkBlocks::get`). `OnceLock` gives no `&mut` without
  `&mut SealedBlocks`, and `d55_seal_and_prove` owns `blocks` and lends only `&blocks`.
- `BlockPublic`'s fields are private plain data:
  - `AttentionPublic`: `Vec<i8>` and `Vec<i64>`;
  - `FeedForwardPublic`: `Vec<i8>` and `[i16; 256]`;
  - `Option<AccuracyPublic>`: `Vec`s, enums and plain structs.

  There is no `Cell`, `RefCell`, `OnceLock`, `Mutex`, atomic or raw pointer in any of them (`accuracy_public.rs` has
  none).
- No `unsafe` code touches a block.
  - `trained_block.rs` has no `unsafe`.
  - `run_fork.rs` has two `unsafe` calls, neither on a block: `clock_gettime` (a thread's CPU clock) and
    `pthread_set_qos_class_self_np` (A13's side workers' QoS).
- A move does not touch the heap buffers the digest read.

**Why CS-6's purpose is still met** [CODE]:
- CS-6's purpose is that the blocks the fork run proves with are the blocks the run statement names.
- With `dig1`, the statement's digest `k` is the request's record's digest, the D2 of the object in the cell.
- That record must also produce the startup's statement identity, which `Served::statement_of_records` checks before the
  run header. The identity covers every record field, the block digest included.
- So the object proved has the startup's digest: D2(the object proved) = the request's record = the startup's record
  (D2 of the resident block as the startup's checked load made it).
- The check is not removed. It moves earlier, before the run header, on the sealing side: a copy that differed from the
  resident block would give a different digest and so a different identity. It would be refused before anything of the
  run exists, with `stack-serve: this request's trained-model statement is not the one the server started with (before
  the run header)`.
- The preflight's comparison still runs on every block, against the statement.
- The verifier is independent of all of this. `stack-verify` hashes its own blocks from the export, and the transcript
  binds the statement's digests.

**What a wrong kept digest does** [MEASURED, the suite test]:
- If a kept digest were not the statement's, the preflight refuses by CS-6's own name before anything is absorbed:
  `private run: ruling CS-6 — block k handed to the run is not the block the run statement names (its public digest
  begins …, the statement's …); refused before anything is absorbed`.
- If a kept digest were right but the cell held another object, which `put_digested` cannot produce, the receipt would
  fail verification.

**What it does not cover:**
- A hardware fault in memory between the digest and the forks' reads. The default has the same exposure between the
  preflight's hash and the forks' reads, which are later still.
- **The cost:** 32 digests per request on the loaders (A21's tree; A21 measured 5.9 ms each).

### 5.5 Latency: queueing, not slower requests

- **The figures.** `serve4`'s mean latency of 14.13 s is measured from each line's arrival, and all four lines arrive at
  t = 0. The harness's 8.85 s is measured from each request's own sealing start.
- **Each request's own time, from entering the sealing turn to its result** [MEASURED]:

  | stream (pass 0) | request 0 | request 1 | request 2 | request 3 |
  |---|---:|---:|---:|---:|
  | `serve4`, own time | 7.47 | 9.47 | 8.90 | 8.51 s |
  | `serve4`, from arrival | 7.47 | 12.02 | 16.37 | 20.53 s |
  | `harness4`, from its sealing start | 6.17 | 8.87 | 9.74 | 10.97 s |

- Over 4 passes, a later `serve4` request's own time is 9.04 s on average. The harness's later requests take 9.76 s from
  their sealing start, because its sealing thread runs ahead and its sealed requests wait in its channel.
- **So each request does not take longer than in the harness.** The 14.1 s is queueing: request q waits for the q
  requests ahead of it. The first request, 7.45 s against the harness's 6.09 s, carries the heavier production sealing
  pass (§5.3(2)) [INFERRED].
- **One request alone** (`serve1`, warm) takes 7.01 s: a sealing pass of 2.51 s, a prove call of 4.18 s, and 0.30 s
  after the prover. Production's one request through `d55_seal_and_prove` after A21 took 7.045 s (A21's measurement).
  At one request the resident model saves little, since A21 made the loads cheap. The stream is where the gain is.

## 6. Acceptance on the final tree

TODO (stage 9).

## 7. H-1 (rulings D29, D68) per request: the argument, and its tests

**The claim.** For every request of a stream:
- every input-provokable refusal comes before that request's run header and creates nothing;
- a refused request gets its refusal line, and the stream carries on;
- a failure after the header removes that request's run directory;
- no request's refusal or failure changes or delays another request's receipt bytes.

1. **The refusals and their order are `stack-prove`'s** [CODE].
   - The request runs `d55_seal_and_prove` itself, so R5b's sealing pass (`seal_chain`) and every check after it run in the same order, with the same strings. Those checks are the statement, the endpoints, the bound statement, D60's door and `Planned::check`. R6's source audit still finds the CS-3 check in `seal_chain` and finds `seal_chain(m, run.budget, &mut hand)` in `d55_seal_and_prove`.
   - The view adds one check before the header: the request's statement must be the startup's. The statement is a pure function of the records, which are copies of the startup's, so an input cannot reach this check.
   - The request line's own checks come before anything is read, as `stack-prove`'s argument errors do. They are its form, a run directory that exists, and a run directory an earlier request of the stream named.
2. **Nothing of a refused request exists** [CODE, tested].
   - The run directory is created only after the prover turn is entered, just before the prove call.
   - A refusal before that point creates nothing.
   - With the window on, its parts are dropped inside `prove_run_with_forks_planned` before it returns, as in A19.
3. **A failure after the header removes its run** [CODE, tested].
   - A failure of the prove call, the receipt write or the marker goes through `fail_run` inside `d55_seal_and_prove`, as in `stack-prove`.
   - A failed self-report check removes the run, as in `stack-prove`.
   - **The one difference from `stack-prove`** (the security owner's decision (c), accepted): if the statement files cannot be written, the server removes the run directory too. `stack-prove` keeps it in that case. A directory someone else made is left as found.
4. **The stream carries on, and no request touches another's bytes** [CODE, tested].
   - Each request has its own `Served` view, its own `SealedBlocks`, its own witnesses, statement, endpoint owners and generators, and its own run directory.
   - The two turns are left on every path, through a drop guard.
   - The prover turn is left as soon as the prove call returns, before any failure is handled, so a failure does not hold the next request.
   - The resident model is read only.
5. **The cross-request timing channel** [CODE; the security owner's decision (a)].
   - A request waits for the request before it to leave the prover turn, so its latency reveals that request's prover time and an early refusal.
   - Within one data owner, that reveals nothing that the earlier request's own result line does not already show.
   - Across owners it would be a new channel, so the server serves one data owner per process until a ruling.
   - The schedule itself reads no hidden value: the turns follow the request order, and each request's timing is `stack-prove`'s.
6. **The tests** (§4) [MEASURED, CPU and Metal, merged tree]. The R13 export's stream of 10 requests:
   - 0: proved;
   - 1: **a refused input in the middle of the stream** (layer 1's reference output off by one word, by `seq_dir`). The
     constant refusal line; the detail was layer 1's parity refusal, `before the run header; ruling H-1`. No run
     directory or statement was created;
   - 2: **a run directory that already exists**. Refused, and the directory and its file were untouched;
   - 3: proved;
   - 4: **an I/O failure after the run header**. A lane hook made the run directory unwritable after the proof, so the
     receipt write failed. The run directory was removed (`prove_run: … (the incomplete run directory was removed)`)
     and no statement was left;
   - 5: a bad request line;
   - 6: a run directory request 0 had named. Refused;
   - 7: proved;
   - 8: **a statement-file failure after the receipt**. Its statement directory was taken by someone else. The run
     directory was removed, and the other directory was left untouched;
   - 9: proved.

   The results came out in request order. Each turn was taken in request order, with at most 2 requests held at once.
   Requests 0, 3, 7 and 9 were each verified by a fresh `stack-verify`. With the window on, a refused request's parts
   were all dropped (0 alive), on the export and on the synthetic rung.

## 8. The cached-record binding

**What a receipt attests** [CODE]:
- **What it binds.** A served receipt's statement binds the layer records the startup made. Those are the records of the export as it was read and checked when the process started.
- **What the proof covers.** The fork run's preflight hashes, for every request, every block the request proves (CS-6) and compares it with the statement's digest. So the receipt attests that the proof is of the weights the process holds, and that those are the weights whose records the statement names.
- **The export file's later state.** The receipt does not attest to it. A running server never reads the export's layer files again. A change on disk after the startup reaches no receipt, until the process is restarted and its startup checks the new files.
- **The cached part.** It is the records, and with them the identity. Each request's statement is made from copies of them and must have the startup's identity. Each block a request proves is a fresh copy of the resident block, hashed again by CS-6.
- **Integrity of the resident copy.** If the resident copy were corrupted in memory, CS-6 would refuse the request before anything is absorbed.

**No API changes the resident model** [CODE]:
- `Resident`'s fields are private to `trained_block.rs`.
- Its methods take `&self` and hand out copies or shared borrows only.
- `Served` holds a shared borrow.
- `BlockPublic` has no interior mutability.

## 9. Fresh randomness, and no carry-over between requests

**Fresh randomness** [CODE, tested]:
- Nothing of a request's randomness is made at startup or kept between requests.
- **The endpoint commitments.** `prepare_endpoints` draws fresh OS randomness on every call, and `d55_seal_and_prove` calls it once per request.
- **The boundary commitments and every fork's coins.** These are the commit phase's generator and one generator per fork. Each is `ZkRng::from_os` under its own domain, made inside `prove_forks_inner`, on the thread that uses it, once per request (run_fork.rs, F4).
- **The scope of that code.** None of it is cached by the server, and s25's census of the two construction sites is unchanged.
- **The test** (§4) proved 4 requests on the same input in one stream, with no seeded generator [MEASURED, CPU and Metal]:
  - no two share their endpoint commitments (`expected.bin`);
  - no two share their head (it carries the 3 boundary roots, each salted and masked);
  - no two share any fork frame (its masks, and the challenges, which follow);
  - no two share the tail;
  - all four verify.

**No carry-over** [CODE]:
- Every buffer of a request lives inside its `prove_one` call: the private sequence, the chain, the witnesses, the sealed planes, the endpoint owners, the boundary owners, the receipt and its blocks' copies. Each is dropped before that request's outcome goes to the printer, so before its result line.
- Between requests, a lane holds nothing.
- The server keeps, across requests:
  - the resident model (public);
  - the set of run-directory paths the stream has seen (public request words);
  - the result lines.
- The private input is read only by the sealing pass, on the lane thread that holds the request: `seal_chain` calls `m.seq(..)` on its own thread. The loaders call only `load_layer`, which copies public data. The reader thread reads request lines only.
- **Zeroization.** The D55 path has none today. The only zeroizing code in the crate is `stable_weight_material.rs` (P3's weight storage, an optional feature). So there is nothing to keep doing.

## 10. For the privacy gate

**The production sources that moved** (SHA-256 of the file: perf `2eb26c7f` → this lane's final tree) [MEASURED]:

| file | perf 2eb26c7f | A22 | what moved |
|---|---|---|---|
| `src/private_block/trained_block.rs` | `301cae66…` | `d3616df5…` | the `[A22]` section; `D55Run.turn` and its two calls in `d55_seal_and_prove`; `write_unverified_statement_files`; `SealHand::block`'s digest argument (`seal_chain`'s one line, `NoHand`, `D55Hand`); `StackModel::fresh_digests`; `D55Proved`'s three accessors |
| `src/private_block/run_fork.rs` | `3cf49cd2…` | `a73edcfd…` | `SealedBlocks`' digest cells, `put_digested`, `digest_of` |
| `src/private_block.rs` | `a8ce361f…` | `612d87c1…` | the re-export of `trained_stack_serve_command` |
| `examples/zk60_trained_block.rs` | `54067edf…` | `b7124684…` | `stack-serve` in the CLI and its header |

- `run_fork.rs` is a source pin of the D55 capture.
- Unchanged: `protocol.rs`, `argument*.rs`, `witness*.rs`, `run.rs`, `run_sink.rs`, `trained_statement.rs`, `gpu/*`,
  zkp-core, `Cargo.toml` and `Cargo.lock`.
- No receipt, statement, record or `stack-prove` event byte moves (§4).
- No new hash call site of s25's census: the server calls `BlockPublic::digest` (D2) only under `dig1`, through the
  method, not an entry point.
- No new absorb label, generator site or `unsafe`.
- s25's call-site and file censuses, the label scan and R6's audit pass (stage 0, and the suite in stage 9).

**New threads** [CODE]:
- **Per stream:** one reader thread (request lines only) and `HL_A22_LANES` lane threads, 2 by default. Each lane runs one request at a time, end to end, and holds that request's private data only while serving it.
- **Pools:** none new. The sealing pass's loaders (A20), the sealing pool (A15), the fork pools (A11) and the window's side workers (A13, off) are the existing ones.

**Known limit: `gpu_declines`** (the security owner's decision (b)) [CODE]:
- The statement's `prover_reported.gpu_declines` is `crate::gpu::declines()`, a count for the whole process.
- In a server it counts every request since the start, not this request's.
- A per-request count would be the correct value: the field means the device calls this proof declined.
- It cannot be taken from the one process-wide counter, because two requests' device work overlaps in a stream (request r + 1's sealing pass beside request r's forks). It would need a counter per request, carried per thread like the fork hooks.
- Today the limit fails closed:
  - on the Metal build the backend is the CPU-build constant, so any decline makes every later request fail `check_prover_reported`, and its run directory is removed;
  - with `HL_GPU_REQUIRED=1`, a decline aborts the process.

`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched. D63 stands: this is the production form, measured, not a deployment.

## 11. What is left

- **The 33 tok/s target**: 29.23 steady by default, 30.67 with `dig1` [MEASURED].
  - **`dig1`**: D72 now permits it, and it measured +4.9% steady. It stays off by default in this merge, because
    stage 9 ran with it off.
  - **The next form, lane A23**: shared resident blocks (`Arc<BlockPublic>` or `&`), with CS-6 on the startup digest
    of the very object, under D72 (§5.3). It removes the per-request copy and the re-hash, and supersedes `dig1`.
    [ESTIMATE] +6 to +9% steady.
  - **The rest of the gap**: the forks' +0.21 s beside production's heavier sealing pass.
    - The sealing side has 0.35 s of slack per request, so a smaller sealing pool in the stream (A15 measured 8 threads
      at one request only) could trade it for the forks' cores. Not measured.
- **Rulings:**
  - ruled: (d) `dig1` (D72; §5.4), whose conditions also cover A23's startup-digest form of CS-6;
  - owed: (a) more than one data owner per process;
  - owed: per-request `gpu_declines` (§10);
  - `F_FULLFSYNC` per frame is `stack-prove`'s durability and is kept.
- **Not measured:**
  - a real trained 8B export's startup (no export on the Mac): it also reads and SHA-256s every array;
  - any machine but this M3 Ultra;
  - streams longer than 8;
  - a supervisor process driving the CLI over a pipe (the A/B drives `serve_stream`, the CLI's own function, in
    process).
- **Not built:** a supervisor. `apps/proven-media` is Astra's lane; §2 documents the interface it would drive.
- **D63 stands**: nothing goes into production before its Lean statements are proved. This is the production form,
  measured, not a deployment.

## 12. Merges

**A21** (perf `2eb26c7f`) was merged into this branch before any measurement (merge commit `96eb9f31`).
- **The only conflict** was the two lanes' appended test blocks at the end of `run_fork_tests.rs`. Both are kept, `[A21]` then `[A22]`.
- **A21's two new `D55Run` literals** gained `turn: None`.
- **Merged cleanly:** `seal_chain`, `SealHand`, `SealedBlocks` and `Served::load_layer`'s call of `BlockPublic::digest`, which is now A21's parallel tree under `HL_A21_B3PAR` (the same bytes).

**Risks for a later lane** [CODE]:
- **`trained_block.rs`:**
  - `SealHand::block` takes the record's digest;
  - `D55Run` has a `turn` field (a struct literal elsewhere needs it);
  - `StackModel` has `fresh_digests`;
  - the new `[A22]` section sits after `UNVERIFIED_TEXT`.
- **`run_fork.rs`:** `SealedBlocks` has a second field.
- **`run_fork_tests.rs`:** the `mod a22 { … }` block is at the end. It is inline because a new file would need s25's file census edited.

## 13. This directory

- **Stage scripts:**
  - `s0.sh` (the build and the quick CPU checks);
  - `s1.sh` (the byte tests: the CPU export stream, then the device tests);
  - `s2.sh` (the A/B);
  - `s9.sh` (the acceptance);
  - `run_stage.py` (A20's runner, with A22's labels);
  - `stream_table.py` (the A/B's tables).
- **Records:**
  - each stage's progress file, guard record and `.done` marker;
  - stage 2: `s2_ab.log` (the A/B's lines, trimmed), `s2_table.md` (its tables), `s2_d55.log` (the original harness's
    stream);
  - stage 9: `s9_ab.log`, `s9_table.md`, `s9_d55.log`, `s9_prod.log`.
- **History:** stage 0 ran before the merge. The first `s1`/`s2` queue entry was stopped while still waiting for the lock (exit 70, never started) so that every measurement would run on the merged tree.
- **Raw logs** stay in `raw/` (not committed).
