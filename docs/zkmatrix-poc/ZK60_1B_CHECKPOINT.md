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
- [~] Count actual proof layouts for T32/64/128/256/512, including host and
  device allocations separately, weight residency, witness overlap and scratch.
  2026-10-17 partial: rows and receipt bytes counted at the true TinyLlama
  geometry under D24 (T32 11.6 MB, T64 15.4, T128 23.0, T256 35.5, T512 57.1 MB
  at row width 2^15; at 2^14 T512 is 72.1 MB, over the 64 MiB wire cap);
  `results/zk60_1b_native_20261017/t2-audit-and-ladder.log`. Host/device
  allocations not yet counted separately; GPU floors in
  `ZK60_TRAINED_STACK_READINESS_20261017.md` §2 are pre-D24 counts.
- [x] Import actual checkpoint weights layer by layer; reject malformed,
  missing or unsupported tensors and preserve model/config identity.
  2026-10-17: calibrated per-layer exports (every array sha256-pinned, tables
  regenerated and checked against the native generators) read by the strict
  loader `private_block/trained_block.rs` in `ops/zkp-mvp/trained-1b/`; 14 named
  malformed-export refusals tested.
- [~] Define and validate the complete integer calibration against the
  trained model, including attention, norms, residuals, FFN and layer seams.
  2026-10-17: the Python integer reference is bit-exact with the native
  witness at all 22 layers (export `a`), but export `a` (toy shifts, one set
  of constants) is unusable (held-out top-1 0.136). Best per-profile variant
  `pg_rot1` (one constant set with movable shifts, Hadamard-rotated residual
  basis, per-layer tables): top-1 0.698, perplexity 36.5 vs 29.3 float, 0/36
  refused (T32, licence/docstring text). Native support for its shifts is in
  progress. `results/zk60_1b_calibration_20260929/PROGRESS.md`.
  B4 (2026-10-17, FineWeb-Edu + licence held-out, 36 docs each): one-profile
  `pg+rot` top-1 0.725 (T32) / 0.745 (T128), perplexity 12.67 -> 15.80 at
  T128, 0 refusals; per-layer shifts `dg+rot` 0.803 / 0.809 (needs per-stage
  layouts, deferred). Ladder exports `pg_rot1_b4_{T32_cal128,T64_cal128,T128}`
  share identical weights (hard links) and carry the int16 embedding table;
  token I/O spec `export/TOKEN_IO_SPEC.md`. The ~30% attention-output error
  is upstream score/value precision; an O-site layout change would buy at most
  +0.016 top-1 (not pursued).
  **Llama-3-8B (B5, 2026-10-17, same mechanism, tn 9, RoPE 500000):** held-out
  top-1 0.623 FineWeb / 0.547 licence at T32 (ppl 18.85 -> 37.11 FineWeb), 0.653 /
  0.612 at T128 (ppl 10.59 -> 20.55 FineWeb), 0–1 refusals; one residual scale
  survives in the rotated basis (BOS massive activations +226/-205/-202 from
  layer 1 to 30). Weak spot: layer 1's attention sink forces a coarse score
  scale (isolated cosine 0.73); an int16 score class (layout change) lifts it to
  0.83. Export `results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32`
  (profile sha256 2507fbde…), 32 layers bit-exact on two held-out sequences.
- [x] Bind a separately versioned model/profile/calibration statement into
  the proof; preserve the frozen toy and existing development profiles.
  2026-10-17: trained-model statement schema v2 (model, export, tool and
  per-layer manifest digests; tn/Cn_a/Cn_m/Ceps/sh_ao in the schedule digest);
  frozen pins and archived toy receipts unchanged (518 passed / 0 failed).
  Open: the single-block (non-run) path at a trained profile still absorbs the
  synthetic calibration literal; to be refused.
- [x] Prove one trained block, independently verify its saved receipt and
  pass inconsistent-witness, statement and receipt-mutation controls.
  2026-10-17: layer 0 of export `a`, T32, CPU: parity bit-exact, prove 3.49 s,
  fresh-process verify 0.33 s, 11,627,288 B; 3 inconsistent-witness, 8
  statement and 4 receipt-mutation controls refused. Layers 1–21 also proved
  and verified one at a time (prove 3.2–4.2 s each). [MEASURED, shared box,
  n=1.] Low-fidelity calibration; no privacy acceptance at this shape;
  `results/zk60_1b_native_20261017/t5/`. **Review 2026-10-17:** the D24 norm
  rule is accepted, but the trained loader admitted an unvalidated export
  constant (`f_e`) with which a forged output verified (finding F-1,
  `results/zk60_d24_review_20261017/`); these receipts use the safe value
  `f_e = 9`, but the trained profile is not accepted until F-1 is fixed and
  re-reviewed.
- [x] Prove and independently verify all blocks as one bound stack, with
  bounded live memory and all block-to-block transitions checked.
  2026-10-17 09:47–09:57 UTC: all 22 TinyLlama blocks of export `pg_rot1`
  (held-out top-1 0.698) at T32 as ONE bound run on the CPU: parity bit-exact
  at every layer; sealing 230.6 s + proving 282.6 s (witness rebuild 223.0 s,
  block proofs ~60 s) = 528.9 s; receipt 250,855,088 B in 22 segments;
  fresh-process verify 4.9 s; peak RSS 2.15 GiB; 11 run-level controls refused
  and a prover-side boundary lie fails at the IO-out endpoint equality
  [MEASURED, shared box, n=1]. Statement identity 68ad19c8…, binding the export
  profile digest, every block digest, the calibration, `f_e` and the RoPE base.
  `results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-cpu/`. Conditional on
  the round-2 re-review (running). Blocks only (D13); T32 only.
- [~] Complete the relevant privacy/soundness review. Verification alone
  does not complete this item; D22 currently covers only the CPU toy.
  Soundness: D24 + trained profile/loader accepted after two independent
  review rounds (2026-10-17). Privacy evidence (2026-10-17, gate ported to the
  trained T32 profile, `results/zk60_gate_tinyllama_20261017/`): per-commitment
  disclosure A 0, H 2 (= public LogUp identity), endpoints 0, boundaries 0,
  M 0 at L = 1, 2 and 22 (joint = sum of parts); blinding reproduced from
  all-zero data with 0 differing (2.25 M entries at L = 2); joint assignment 0
  differing; 98,822 challenges re-derived and 22,784 opened columns re-hashed
  at L = 22; every control family fires; port equivalence on a frozen bundle
  (5,261 fields, 0 unexplained). Open before an acceptance can be considered:
  a privacy statement draft with the three arguments re-read at this layout,
  the L = 22 all-zero capture and full joint arm, port of the 125M lane's
  refusal/binding rulings CS-1..CS-9 (CS-6 statement-to-block binding) and
  pinning three prover files (G-1/G-2), Victor's D23 ruling, and an
  independent adversarial review. CPU-path receipts only.
- [~] Run matched CPU/GPU full-stack measurements and the context/pass ladder,
  counting each proved position once, with no silent GPU fallback.
  2026-10-17, T32 only, same 22-block `pg_rot1` stack [MEASURED, shared box,
  n=1]: CPU prove_run 282.6 s (proofs alone 59.6 s), total 528.9 s; GPU
  (RTX 4070 Laptop, header "gpu: ON", 0 declines, GPU mode now fails closed)
  prove_run 296.0 s (proofs alone 68.1 s), total 545.1 s, peak VRAM 1,281 MiB,
  same statement identity, verified by the CPU binary in a fresh process. No
  GPU gain at T32: 86% of wall is the single-threaded witness builder, run twice.
  0.06 proved positions/s total wall. `r2/stack-pg_rot1-ho00-{cpu,gpu}/`.
  **Round 3 (11:03 UTC): witness built once and in parallel (53x per block);
  the ladder on the `pg_rot1_b4` family (identical weights), 22-block stacks,
  each verified in a fresh process with 11 run-level controls refused
  [MEASURED, shared box, n=1, 16 threads]:**

  | T | CPU total | GPU total | proofs only CPU / GPU | positions/s total CPU / GPU | receipt | peak RSS CPU / GPU | peak VRAM |
  |---|---:|---:|---:|---:|---:|---:|---:|
  | 32 | 56.2 s | 60.8 s | 40.2 / 40.8 s | 0.57 / 0.53 | 251 MB | 2.15 / 1.98 GiB | 1.3 GiB |
  | 64 | 84.9 s | 89.3 s | 64.8 / 63.5 s | 0.75 / 0.72 | 333 MB | 2.92 / 2.31 GiB | 2.5 GiB |
  | 128 | 168.6 s | 142.8 s | 136.2 / 107.1 s | 0.76 / 0.90 | 498 MB | 4.82 / 3.03 GiB | 3.1 GiB |

  Proofs now dominate (72% of wall at T32, 81% at T128); the GPU (commitments
  only) helps from T128. T256/T512 not run: one-block peak RSS doubles per
  T doubling (0.85 / 1.64 / 3.39 GiB), projecting ~7 / ~14 GiB per block —
  beyond this laptop; the Mac (256 GB) or the 5090 machine is needed.
  `results/zk60_1b_native_20261017/r3/LADDER.md`.

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

**Updated 2026-10-17 18:35 UTC (Claude, after the 14:59 clean shutdown and
18:21 reboot).** Common rules: `ops/zkp-mvp/LANE_RULES_20261017.md`. Lanes:

- **GPU zero-check (speed plan task 2, go/no-go):** `ops/zkp-mvp/gpu-zerocheck/`
  (copy of frozen review-r3), evidence `results/zk60_gpu_zerocheck_20261017/`.
  Code written 14:00-14:45; first device run pending.
- **Native (R5 suite, task 1 startup cleanup, task 3 8B T64/T128 ladder, then
  an 8B T128 trained stack if green):** `ops/zkp-mvp/trained-1b/`, evidence
  `results/zk60_1b_native_20261017/`.
- **Independent review r3 (Round-4 8B profile changes) verdict:**
  `results/zk60_d24_review_20261017/`.
- **Privacy gate (L22 controls, finding G-10, statement draft):**
  `ops/zkp-mvp/gate-tinyllama/`, `ops/zkp-mvp/trained-1b-gate/`,
  `results/zk60_gate_tinyllama_20261017/`.
- **Calibration 8B B6 (T64 export redo, layer-1 options):**
  `results/zk60_8b_calibration_20261017/`.
- **Token I/O design (paper only; D13's next milestone):**
  `results/zk60_token_io_design_20261017/`.

Earlier list, kept for the record (morning of 2026-10-17): The 2026-09-27 Sol lanes and the 2026-09-30
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
- **Independent review (Claude agent):** D24 + trained profile/loader; round 1
  found F-1 (fixed), round 2 re-review of the frozen copy
  `ops/zkp-mvp/trained-1b-review-r2/`; `results/zk60_d24_review_20261017/`.
- **Privacy gate at the trained shape (Claude agent, from 10:20 UTC):** capture
  writer for the trained profile in `ops/zkp-mvp/trained-1b-gate/`, gate tools
  ported in `ops/zkp-mvp/gate-tinyllama/`, evidence
  `results/zk60_gate_tinyllama_20261017/`; produces evidence only, no
  acceptance.
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
