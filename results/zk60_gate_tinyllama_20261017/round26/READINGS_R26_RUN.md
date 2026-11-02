# Gate round 26: the run-level pins, read (frozen-r19b → HEAD 8b78aabd)

Run-level reader, 2026-11-02. **Not a privacy acceptance.** P1 is not reopened. The block-level pins are
another reader's; they are not read here. No source file and no gate script was edited. No cargo run.

## In plain words

* **Every run-level, wire, capture and file-reading pin that moved since r19b is read: 12 capture pins, plus
  2 unpinned files read for context. No finding.** 141 hunks or sections: 14 are test-only, 52 are production
  but privacy-neutral, and 75 are privacy-relevant. All 75 were decided safe, each with its argument and the
  HEAD line numbers.
* **The new D55 fork run reveals nothing a D12a run does not.** The join absorbs only words the verifier
  computes itself. Each commitment is opened the same number of times as in D12a, with as many opened columns
  as it has pads. A fork frame carries no IO claim. The randomness is L + 1 fresh OS draws.
* **The capture writer writes nothing on its `not_in_a_capture` list.** The allow-list has no hunk, and every
  key the fork writers emit is already on it. The recorder sees only the verifier.
* **Both digests are read for the five files the D60 bundles pin at dd81ab4f.** Those are `run.rs`,
  `run_capture.rs`, `trained_block.rs`, `run_fork.rs` and `run_fork_wire.rs`. With both, the coordinator can
  re-classify the D60 records without a new capture. The block reader's 14 files still decide whether DEV-PASS
  can become PASS.

## The files (HEAD digests)

| file | r19b | HEAD | D60 bundles | hunks / sections: test / neutral / relevant | verdict |
|---|---|---|---|---|---|
| `run.rs` | `3dc5393d` | `0a8f2615` | `604b65b1` (read) | 8: 1 / 3 / 4 | read, safe |
| `run_fork.rs` (new) | — | `e2cb6328` | `e7b58ff7` (read) | 31 sections: 3 / 12 / 16 | read, safe |
| `run_fork_wire.rs` (new) | — | `08d93ecf` | `a2dbc6f1` (read) | 13 sections: 0 / 4 / 9 | read, safe |
| `run_capture.rs` (test-only module) | `cce0fc2a` | `cbb78dc0` | `5d5fdfcc` (read) | 28: 8 / 0 / 20 | read, safe |
| `plane_index.rs` (test-only module) | `ce79803c` | `702fa81a` | = HEAD | 5: 1 / 0 / 4 | read, safe |
| `wire.rs` | `f3120678` | `b4377c6e` | = HEAD | 8: 0 / 1 / 7 | read, safe |
| `hash_domain.rs` | `20121421` | `a777ebd0` | = HEAD | 1: 0 / 1 / 0 | read, safe |
| `private_block.rs` | `96c1cd16` | `7ec8b855` | = HEAD | 3: 1 / 2 / 0 | read, safe |
| `trained_block.rs` | `dc6e8772` | `9909e883` | `4d1e24bd` (read) | 18: 0 / 4 / 14 | read, safe |
| `tied_tables.rs` | `45fc3f0f` | `4b8f215c` | = r19b | 2: 0 / 2 / 0 | read, safe |
| `token_io/load.rs` | `67307f09` | `56bb29a4` | = r19b | 2: 0 / 2 / 0 | read, safe |
| `token_io/classify_run.rs` (classifier pin) | `8abbf72f` | `44550938` | not pinned | 10: 0 / 10 / 0 | read, safe |
| `token_io/classify_batch.rs` (not a pin) | `707c8db2` | `55bfb418` | — | 1: 0 / 0 / 1 | read, safe |
| `token_io/classify_cli.rs` (not a pin) | `616e33b9` | `9c464aa2` | — | 11: 0 / 11 / 0 | read, safe |

Of the 33 pins that moved r19b → HEAD (78 pins: 44 own + 29 shared + 5 classifier), 12 are read here and 7
were already read at their HEAD digests in `W16_READINGS` (zkp-core and `gpu/mod.rs`). The other 14 are the
block reader's.

## The points asked about

* **What `run_capture.rs` writes, checked against `not_in_a_capture`** (:3288):
  * run.json is `write_run`'s output. It carries the same not-in-a-capture list.
  * Each fork stage file is an ordinary stage record, without boundary or IO openings.
  * The tail holds S1 and the B_k and endpoint openings, written the way D12a's IO openings are written:
    masked vectors, Q opened columns, published salts, and claims the verifier computed.
  * `arrays.bin` holds the merged per-fork stores. `absorb_store` copies only arrays that are already stored.
  * `receipt/` holds the receipt's own frames.
  * `ALLOWED_KEYS` (:4035-4360) is unchanged.
* **Fork randomness.** Each run builds L + 1 generators, each with `ZkRng::from_os`:
  * one for the commit phase (run_fork.rs:1095), dropped at :1107 before any fork starts;
  * one per fork, created inside its worker (:1022).
  * Each `from_os` call keys BLAKE3 with 32 fresh bytes from `/dev/urandom` (rng.rs:44-65).
  * `ZkRng` cannot be cloned, and the file has no seeded `ZkRng::new`.
* **The D55 join** (:864-871) absorbs three things per fork: k, the fork transcript's state and squeeze
  counter, and the slot-21 and slot-22 claim lists. The verifier absorbs its own values (:1284-1290,
  :1391-1394). So the prover can only absorb words the verifier recomputes from the receipt, and no frame
  carries the claims (`ForkFrame` :47-55).
* **The F3 marker.**
  * The constant is `false` (:101), and `stack-prove --d55-workers` refuses to run without the
    acknowledgement flag.
  * The marker is fixed text, written with create_new and then renamed. It is absorbed nowhere and is in no
    frame or statement. The reader admits it only as exactly that text.
  * `stack-verify` prints `not_for_publication = marked || !gate`.
* **Reader error messages.** They carry only paths, directory entry names, lengths, k and L, and OS errors.
  The verifier holds no witness, and the batch request's content is never echoed. Prover errors go to the
  prover's stderr. `fail_run` writes no file. A release build aborts on panic (Cargo.toml:63), as D12a does.
* **Timing.** No new code branches on secret data. The new timers are gated by HL_PB_TIMING and only write.

## Info notes (none is a privacy defect)

* **R1:** the D60 bundles' dd81ab4f digests are read as well: HEAD minus commit ed519548's hunks. Those hunks
  are F3, F4, F7, F8 and the run.json text.
* **R2:** the capture's join takes the claims from the verifier. Python D55-IO derives them independently.
* **R3:** the F3 marker is an operating control, not a cryptographic one.
* **R4:** prover stdout gains per-fork `prove_core` seconds, plus HL_PB_TIMING diagnostics. Under P-6 that
  output is prover-private.
* **R5:** F4 lets `prove-batch` read its request on macOS. That path is still outside D58, and R18-1 is
  still open.
* **R6:** the text of `classify_cli::door` changed, by diagnostic lines only (not a pin).
* **R7 (not privacy):** `write_fork_receipt` uses `File::create` for its `.partial` files, as `DirSink` does.

## Records

* `READINGS_R26_RUN.json` (sha256 `e095191c…`): trees, pins, diffs, per-hunk readings, wiring table.
* Diffs: `readings/run-r19b-head-*.diff` (14 files), plus `readings/run-r19b-dd81ab4f-*.diff` and
  `readings/run-dd81ab4f-head-*.diff` (5 files each).
* Generator: `readings_run.py` (`python3 readings_run.py`).
* Tree check: frozen-r19b manifest `cfae2d1e…`. 302 of the 306 files re-hash equal. The other 4 are binary
  receipts under `frozen-r19b/results/`, left on the laptop and listed in
  `SNAPSHOT_20261017_EXCLUDED_LARGE_FILES.json`. Every hashline/ and zkp-core/ source file matches.
