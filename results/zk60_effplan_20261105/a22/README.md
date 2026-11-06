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

TODO (numbers from stages 1, 2 and 9).

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
  - `HL_A22_DIGEST_AHEAD`: default 0. It stays off by the security owner's decision (d).
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

TODO: the measured parts.

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

**`HL_A22_DIGEST_AHEAD` (off; the security owner's decision (d)).**
- With it on, `Served::load_layer` digests each request's copy of each block where the copy is made (on the sealing pass's loaders), and carries that digest in the copy's record.
- The request's model statement, made from those records, must still be the startup's.
- The shared blocks keep each digest beside its block, and the preflight's CS-6 compares the kept digest with the statement's instead of hashing the block again.

## 4. The byte evidence

TODO (stages 1 and 9).

## 5. The measurements

TODO (stage 2: the A/B on the merged tree; stage 9: the confirmation run).

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
6. **The tests** (§4): TODO.

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
- The test (§4) proves 4 requests on the same input in one stream. TODO: the result.

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

TODO (source digests at the final commit).

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

TODO.

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
- **Records:** each stage's progress file, guard record and `.done` marker; `s2_ab.log` and `s2_table.md`; stage 9's files.
- **History:** stage 0 ran before the merge. The first `s1`/`s2` queue entry was stopped while still waiting for the lock (exit 70, never started) so that every measurement would run on the merged tree.
- **Raw logs** stay in `raw/` (not committed).
