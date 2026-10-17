# Trained approximately 1B intermediate checkpoint

Victor requested this checkpoint on 2026-09-27 UTC: use the available RTX
4070 Laptop GPU (8,188 MiB VRAM) and roughly 15.4 GiB host RAM to establish
complete-model CPU/GPU measurements before the larger target. The final
goal remains a private trained 8B transformer-stack proof at >=50 proved
tokens/s on the 5090 or a named high-end GPU. This checkpoint does not
replace that goal or expand any existing privacy acceptance.

The candidate family is TinyLlama 1.1B, subject to source/config/header and
memory gates. The intended experiment proves every transformer block of
one pinned trained checkpoint, with private input, output and activations;
weights may be public. Following D13, embedding, final normalization, output
head and token selection remain separately identified subsequent coverage.
The exact parameter count of the checkpoint and of its proved stack must
both be reported. Never describe a single block as a complete-model pass.

## Checkmarks and acceptance evidence

- [x] Local device baseline: CPU/GPU synthetic one-block comparison verifies;
  evidence in `results/zk60_sol_gpu_20260927/dense125m_ab_analysis.md`.
- [x] Pin a compatible trained checkpoint, exact parameter count, license,
  immutable source revision, tensor-file digest and architecture semantics.
  2026-09-29 UTC: TinyLlama-1.1B-Chat-v1.0 rev fe8a4ea1 fetched to
  `~/models/tinyllama-1.1b-chat-fe8a4ea1/` (2,200,119,864 B, local sha256
  matches pin 6e6001da…); importer inventory passes, 201 tensors, exit 0
  (`results/zk60_1b_checkpoint_20260927/`: `inventory_20260929.json`,
  `importer_zk60_1b_checkpoint.py`). Closed 2026-09-30 00:17 UTC, evidence
  in `results/zk60_1b_pins_20260929/` (each script's `.log` ends `exit=0`):
  **parameters** from the header (sha256 matches the inventory):
  1,100,048,384 in 201 BF16 tensors (= provider total); **proved stack**
  (22 blocks x 44,044,288) 968,974,336 = 88.08 %, of which 90,112 are
  RMSNorm weights; outside it, embedding 65,536,000 + output head
  65,536,000 + final norm 2,048 (`param_count.py`). **License** Apache-2.0,
  declared in the model card at the pinned revision (saved card's git blob
  matches the pinned blobId 9737c9ce…); the repo has no LICENSE file and
  uses the Llama 2 tokenizer (`license_note.md`). **Architecture**: config
  (blob 4ea05f1b…), generation/tokenizer config and `tokenizer.model` match
  the revision (`sidecar_pins.py`); the importer admits only untied, bias-free
  SiLU Llama with plain RoPE, and the header shapes give d 2,048, f 5,632,
  32 query / 4 KV heads, dh 64. **Tile reads** (`tile_read_check.py`):
  one row each of layer 0 q_proj and layer 21 down_proj pass the recorded
  whole-tensor digest and equal a direct file read; 8/8 negative controls
  are refused. Scope: source identity only. `tokenizer.json`,
  `special_tokens_map.json` and `eval_results.json` were not fetched. No
  calibration or proof exists yet.
- [ ] Count actual proof layouts for T32/64/128/256/512, including host and
  device allocations separately, weight residency, witness overlap and scratch.
- [ ] Import actual checkpoint weights layer by layer; reject malformed,
  missing or unsupported tensors and preserve model/config identity.
- [ ] Define and validate the complete integer calibration against the
  trained model, including attention, norms, residuals, FFN and layer seams.
- [ ] Bind a separately versioned model/profile/calibration statement into
  the proof; preserve the frozen toy and existing development profiles.
- [ ] Prove one trained block, independently verify its saved receipt and
  pass inconsistent-witness, statement and receipt-mutation controls.
- [ ] Prove and independently verify all blocks as one bound stack, with
  bounded live memory and all block-to-block transitions checked.
- [ ] Complete the relevant privacy/soundness review. Verification alone
  does not complete this item; D22 currently covers only the CPU toy.
- [ ] Run matched CPU/GPU full-stack measurements and the context/pass ladder,
  counting each proved position once, with no silent GPU fallback.

Completed checks need a retained command, source/artifact pins, exit status
and their exact scope. Small synthetic parser or polynomial tests complete
their own implementation checks, not the trained-model proof checkmarks.

## Measurement contract

Start with the smallest feasible context, then grow only after a memory
gate. A 1B checkpoint fitting as BF16 inference weights does not establish
that its proof fits. CPU materialized commitments and streamed GPU
commitments have different live sets. Stream model layers if that bounds
memory, while proving every layer and charging recurring loads/transfers.

Use the same trained checkpoint, integer calibration, tokens, complete-stack
coverage and build inputs for CPU/GPU comparisons. Record witness work,
initialization, proof, serialization, independent verification, enclosing
wall, peak host RAM/VRAM, device dispatch, proof bytes and failures. Separate
cold processes from resident repeated passes, and prefill from KV-cached
decode. More layers never multiply the number of proved token positions.

The first matched runs may be shared-machine diagnostics. Stable scaling
claims need an isolated measurement period and enough samples to expose
variation. No GPU latency or 50-token/s forecast follows from layout counts.

## Active isolated work

**Updated 2026-10-17 (Claude).** The 2026-09-27 Sol lanes and the 2026-09-30
B2/C2 lanes stopped when the box went down on 2026-09-29 18:38 PDT; nothing
native ran between then and 2026-10-17. Current lanes:

- **Native trained profile (Claude agent):** TinyLlama profile with per-profile
  norm constants (proposed D24: `NORM_TN` 10 instead of a fifth limb), trained
  block loader, then one trained block at T32. Durable copy
  `ops/zkp-mvp/trained-1b/` (candidate + recovered lane-C patch); evidence
  `results/zk60_1b_native_20261017/`.
- **Calibration (Claude agent, lane B3):** fidelity ladder of native
  restrictions (profile-uniform constants, per-layer norm constants, per-layer
  residual rescale, per-layer shifts) and calibrated block exports with
  bit-exact reference inputs/outputs; `results/zk60_1b_calibration_20260929/`.
- **Main (Claude):** coordination, the Llama-3-8B shard download
  (`results/zk60_mvp_20260929/llama3-8b/resume-20261017.*`), status documents.
- Earlier, stopped (results retained, not resumed): model/memory ladder
  `results/zk60_1b_model_20260927/`, streaming importer
  `results/zk60_1b_import_20260927/`, softmax device-boundary oracle
  `results/zk60_softmax_boundary_20260927/`. Frozen CUDA source unchanged.

The hourly researcher must read these assignments before choosing its next
experiment. It should study complementary questions rather than duplicate
the owned native softmax boundary test. Progress is reported in active chat
updates and retained in project/research status files.
