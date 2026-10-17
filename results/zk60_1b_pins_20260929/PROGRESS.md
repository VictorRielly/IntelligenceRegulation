# Lane A: pin-checkpoint closure for TinyLlama-1.1B-Chat rev fe8a4ea1

Owner: lane A (Claude subagent). Writes only under this directory plus the
`[~] Pin …` checkmark block of `docs/zkmatrix-poc/ZK60_1B_CHECKPOINT.md`.
No git writes, no GPU runs.

Checkpoint: `/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1/model.safetensors`
(2,200,119,864 B, sha256 6e6001da2106d4757498752a021df6c2bdc332c650aae4bae6b0c004dcf14933,
already verified by main).

## Tasks

1. [x] Exact parameter count from safetensors headers (201 tensors); proved-stack
   count (22 blocks, excluding embed / lm_head / final norm).
2. [x] License from the pinned revision's model card / metadata.
3. [x] Bounded tile read via the importer against the recorded tensor digest,
   one layer-0 tensor and one layer-21 tensor.
4. [x] Refresh T32..T512 host vs device layout table against the real geometry.

## Log (times UTC, from `date -u` and file mtimes)

- 2026-09-30T00:08Z (2026-09-29 PDT): lane opened; read importer, inventory,
  provider metadata, layout ladder, probe log.
- 00:10Z task 1 done: `python3 param_count.py` exit 0 (`param_count.log`,
  `param_count.json`). Header sha256 matches the inventory pin. 201 BF16
  tensors, 1,100,048,384 parameters (= provider safetensors total, payload
  2,200,096,768 B = 2 x params, file = 8 + header + payload). Proved stack
  (22 blocks x 44,044,288) = 968,974,336 (88.08 %), of which 90,112 are
  RMSNorm weights and 968,884,224 matrix weights. Outside the stack:
  embed 65,536,000 + lm_head 65,536,000 + final norm 2,048 = 131,074,048.
- 00:12Z task 2 done: pinned-revision README fetched (curl + WebFetch), git
  blob SHA-1 matches the pinned blobId 9737c9ce…; `license: apache-2.0`.
  No LICENSE file in the model repo; tokenizer is Llama 2's (card). See
  `license_note.md`, `README_fe8a4ea1.md`.
- 00:12-00:15Z task 3 done: `python3 tile_read_check.py` exit 0
  (`tile_read_check.log`, `.json`). Importer `_shard` + `TensorRef.read_tile`
  with digests taken from `inventory_20260929.json` (importer sha256
  73339779…, inventory sha256 58a7492a…). Layer 0 q_proj row 1000 (4,096 B)
  and layer 21 down_proj row 2047 (11,264 B) both pass the whole-tensor
  digest recheck, equal a direct file read, decode to finite nonzero BF16.
  8/8 negative controls refused (wrong digest, past end, >1 MiB, odd offset;
  the alignment control's first run hit the bounds check on the last row,
  so it was moved to offset 1 and rerun).
- 00:14Z housekeeping: the first tile run wrote
  `results/zk60_1b_checkpoint_20260927/__pycache__/importer_…pyc` (outside
  this lane). Removed that file and the empty directory; both scripts now set
  `sys.dont_write_bytecode`; reran tile check, exit 0; no new caches.
- 00:15Z task 4 done: `python3 layout_refresh.py` exit 0
  (`layout_refresh.log/.json/.csv`, table in `layout_refresh.md`). 11/11
  checks: header geometry = probe geometry on all 14 lines, counter
  constants = header bytes, counter reproduces the stored ladder exactly.
  Numbers unchanged; regrouped by route (CPU materialized host; GPU chunked
  host H-build / host retained / device) plus 22-block receipt totals.
  T512 CPU route 17.7 GiB > 15.39 GiB RAM; GPU route T512 host 6.84 GiB,
  device 3.75 GiB (floors). Unresolved: the TinyLlama Rust probe harness
  was only in /tmp (gone); only its log survives.
- 00:16Z extra pin: `python3 sidecar_pins.py` exit 0 (`sidecar_pins.log`,
  `.json`): config.json, generation_config.json, tokenizer_config.json
  (git blob SHA-1) and tokenizer.model (LFS SHA-256 9e556afd…) all match
  rev fe8a4ea1. config sha256 486bedda… = inventory config_sha256.
  tokenizer.json, special_tokens_map.json, eval_results.json not fetched.
- 00:17Z edited only the `[~] Pin …` checkmark block of
  `docs/zkmatrix-poc/ZK60_1B_CHECKPOINT.md` -> `[x]` with evidence and
  scope. The `[x] Local device baseline` block and all other text untouched.
- Lane A complete. No git writes, no GPU runs.
