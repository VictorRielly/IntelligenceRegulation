# Lane B progress: TinyLlama-1.1B full-block integer calibration

Owner: lane B subagent (Claude). Writes only under this directory. No native
edits, no git operations. Times are UTC (`date -u`).

Scope: design and implement, in Python/numpy, a per-layer FULL-BLOCK integer
calibration and bit-exact integer reference forward for the pinned trained
checkpoint `TinyLlama/TinyLlama-1.1B-Chat-v1.0` rev `fe8a4ea1`, validate it
against a float32 reference on held-out token sequences, and document where
the native kernel's fixed toy constants would have to change. Not a proof,
not a privacy claim, not proof readiness.

## Log

- 2026-09-30 00:17 UTC: lane opened. Read CLAUDE.md, ZK60_1B_CHECKPOINT.md,
  import README, `hashline/src/private_block.rs` + `witness.rs` + `layout.rs`
  (main tree, toy), the SHAPED block in `~/wt-zk60-block125m/hashline/src/
  private_block/{shape.rs,witness.rs}` and `private_block.rs` (padding and head
  permutation, ruling P-2), and `~/wt-zk60-block125m/private-block-kernel-shaped/
  src/lib.rs` (the shape-generic reference kernel; `private-block-kernel-shaped`
  is not in the main tree). Pinned inputs: importer sha256 7333977…ec23,
  config.json 486bedd…e9, tokenizer.model 9e556af…347; model sha256 pin
  6e6001da… (re-verified by the importer at every run).
- 00:20: `sentencepiece` is not installed and transformers' converter needs
  it; wrote `spm_bpe.py` (stdlib protobuf reader + SentencePiece-BPE merge
  rule, byte fallback). Self-check passes on two known Llama-2 id sequences
  and a UTF-8 round trip.
- 00:40: `tlcalib.py` (float reference, exact integer block with every
  calibration constant a parameter, per-layer solver, native export) and
  `explore.py` written. Float exploration, 9 calibration sequences x T128,
  log `logs/explore_T128.log`. Findings that decide the design:
  * embedding absmax 0.149, rms 0.0149; layer-0 input median |x| 0.005;
  * MASSIVE ACTIVATIONS: layer 2's FFN writes ~140 into channels 624/1661
    (BOS-type tokens), ~186 from layer 7 on, removed by layer 21
    (final absmax 42.8). One int16 residual scale for the whole stack is
    therefore ~0.007 per LSB, while layer 0-2 inputs are below 1.0;
  * gamma_a of layer 0 spans [-0.58, 0.77] with 1,826 of 2,048 entries below
    max/64 (int8 gains would be 0/+-1 without the fold used here); several
    gamma_m have tiny negative entries;
  * raw q.k up to 374 (logit 47) at layer 8, 130-275 elsewhere; gate up to
    30, FFN product up to 182 at the massive-activation layers (2, 7, 21).
- 00:43: naive BPE was O(n^2) per document (5 min); switched to exact
  word-chunked BPE (no vocab piece contains U+2581 after a non-U+2581, checked:
  0 such pieces) with a cache; chunked == whole-string on two 4 kB samples.
- (box froze 2026-09-29 17:40 PDT = 2026-09-30 00:40 UTC; lane B agent died.
  Its smoke run `runs/smoke/` survived; no log of it was retained.)

## Lane B2 (continuation, Claude Opus agent), from 2026-09-30 01:27 UTC

Every python job runs through `scripts/zk60_resource_guard.py` (class
`light`), logs + `.done` + `.guard.json` under `logs/`.

- 01:29 UTC: smoke re-run under the guard as `runs/smoke_b2/`
  (`logs/b2-smoke.{log,done,guard.json}`): exit 0, 14 s, **peak RSS 1.31 GiB**
  (cgroup high-water 3.45 GiB incl. the 2.2 GB model page cache). Numbers
  are identical to the pre-crash `runs/smoke/` (L0 iso cos 0.97335, L1 dcos
  0.8868, L2 dcos 0.8513): the code is deterministic.
