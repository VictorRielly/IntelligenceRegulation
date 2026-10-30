# GPU classifier lane (D53), progress ledger

Lane: bring GPU proving and GPU verification to the production classifier path
(Shieldstral T128, `results/zk60_token_io_r1_20261017/frozen-r19b/`), with
receipts byte-identical to the CPU path. Owner: Claude (GPU lane).

Write set: `ops/zkp-mvp/gpu-classifier/` (copy of frozen-r19b without `target/`)
and this directory. No git writes. Every build/test/proof through
`scripts/zk60_resource_guard.py`. Labels: [MEASURED] (shared laptop, n = 1),
[COUNTED], [MODEL].

## Ledger (UTC, read from `date -u`)

- 2026-10-30T20:50:59Z lane start. Read CLAUDE.md, LANE_RULES_20261017.md with
  addenda, ZK60_RESOURCE_PROTOCOL.md, the paused GPU zero-check lane
  (REPORT/NEXT/DESIGN/PROGRESS), speed plan, throughput target, D53.
- 20:51Z results dir created. Read the DeepProve gap study (coordinator relay 20:5xZ): its §1.3 shares are
  TinyLlama T128 + the speed plan's 8B laws; no Shieldstral phase table existed. To be checked against ours.
- 20:55Z inventory by source reading (frozen-r19b): the GPU code in the production tree is the `gpu-cuda`
  feature (cudarc + NVRTC, `hashline/src/gpu/{cuda.rs,kernels.cu,mod.rs}`), runtime `HL_GPU=1`, fail-closed
  `HL_GPU_REQUIRED=1`. On the classifier path it reaches ONLY the commitments (`zkp_core::pcs` Backend seam:
  `try_commit_zk_keyed` = `dev_commit_zk_keyed`, used by A, H, B_k, endpoints, stage IN-C/OUT-C) and the
  openings of device-resident commitments (`EncodedStore::fold_rows/columns`). The sumcheck kernels in
  kernels.cu (`k_sc_round_zc20/zc17`, table zero-check) serve the LEGACY FFN prover (zk.rs) only; the
  private-block slot-18 kernel (`fzc`) exists only in `ops/zkp-mvp/gpu-zerocheck/` (review-r3 base, not
  integrated). Witness, LogUp inverses, zero-checks, extension rounds, matmul slots, verification: CPU only.
  The classify statement carries NO backend field (cli.rs's token statement does), so a GPU receipt can be
  compared to the CPU one on all 30 files.
- 20:57Z lane tree `ops/zkp-mvp/gpu-classifier/` = rsync of frozen-r19b without target/ (306 files, equal to
  manifest_final_r19b: `manifest_init.sha256`).
- 20:58-21:00Z found: `HL_PB_TIMING=1` prints NO phase table on the classifier path (classify_run.rs fills the
  recorder but never calls `report`; only PB-SLOTSTEP lines). Added diagnostic-only hooks in the LANE COPY
  (frozen tree untouched): `ph.mark`s (block load, B_k commit, witness, boundary opening, frame encode, sink)
  + `ph.report` per block in the prove and verify loops; `PB-CLI` lines for the CLI phases (digest pass, tied
  tables, seal_chain, sealing pass, stages, door, gpu stats); all gated by HL_PB_TIMING=1, write-only.
  Plus one ignored lane test `gcl_rung_single_prove_digests_under_fixed_entropy` (classify_r18_tests.rs).
  Patch: `gcl1-vs-frozen-r19b.patch`; manifest `manifest_gcl1.sha256` (3 files changed).
- 21:01-21:04Z builds (guard build class): b1-cpu exit 0 74 s 1.25 GiB; b2-gpu (gpu-cuda) exit 0 85 s 1.35
  GiB. Binaries `bin/zk60_classify.gcl1-{cpu,gpu}.bin` (`bin/binaries.sha256`: fc1f3ea2…, 2ed44258…).
- 21:05Z b3-testbin-gpu (gpu-cuda lib test binary, release) queued for the rung check. Tools written:
  `tools/{phase_a.sh,rung.sh,compare_gcl.py,cleanup_gcl.py,gpu_sampler.sh,gpu_summary.py,wait_turn.py
  (r18's, own HOLD + gcl- label),run_fixed.sh (r18's copy)}`; entropy `~/zk60-artifacts/gpu-classifier/ent/
  job0.bin` = r18/r19b's (2e5b0a0c…).
- 21:05-21:08Z b3-testbin-gpu exit 0 (201 s, 2.28 GiB): `target-gpu/release/deps/hashline-7baed0d320d19f91`.
- 21:08:43-21:08:54Z **RUNG (cheap) PASS** (`tools/rung.sh`, `logs/rung/`): the development-rung classifier
  single prove (L = 1, T = 32) under fixed entropy job0.bin, CPU path (HL_GPU unset, 3.2 s) vs GPU path
  (HL_GPU=1 HL_GPU_REQUIRED=1, 7.3 s incl. CUDA init + NVRTC; peak VRAM 385 MiB): **all 5 files byte-identical**
  (3 segments, statement.json, input.dec; `logs/rung/rung-bytes.json`); "gpu: ON — RTX 4070 Laptop", 0
  declines, 9 keyed GPU commits accepted; each receipt verified in-process; entropy unread 0 both runs.
  Clock during the GPU run: P3/P4, SM 1,605 MHz, reason 0x24 (SW thermal + SW power cap) [3 busy samples].
- 21:10Z Phase A real-scale queue launched (`tools/phase_a.sh`, marker `logs/pa/phase_a.done`).
- 21:10:40-21:18:36Z **p-cpu** (gcl1-cpu binary, HL_PB_TIMING=1, 8 threads, fixed entropy job0.bin): exit 0;
  **bytes-cpu: all 30 files equal round 18's recorded job-0 digests** (single = batch = r16b), receipt
  848,412,096 B: the lane's diagnostic hooks move no byte. Shared box: Sol's light reference job (0.7 GiB) live.
- 21:18:37-21:19:44Z **v-cpu** (fresh verify, lane CPU binary, HL_PB_TIMING=1): exit 0, not-flagged, floor 96,
  verify_seconds 36.6. CPU receipt + owner dir deleted (D46: 29 files 848,417,319 B + input.dec).
- 21:18:50Z **coordinator hold received** (Astra's durable demo post, violence then hate, held before its native
  prove: its preflight waits until no guarded job at all is live). Too late to stop v-cpu (it had launched at
  21:18:37 and ran 67 s; no kill). Created `HOLD` at 21:18:50; phase_a.sh then waited on it before p-gpu.
  21:19:44Z Astra's `pm-classify-prove` (violence) went live. 21:19:48Z `tools/wait_turn.py` extended: every
  launch of this lane now also waits while ANY process of Astra's pipeline exists (`run_durable_app_demo.py`,
  `classifier_pipeline.py`, `finish_durable_demo.py`), so the gap between violence and hate and the finaliser are
  respected. 21:20:13Z HOLD removed (the pipeline check gates p-gpu). p-gpu waits for Astra's demo to finish.
- 21:20-21:30Z written while p-gpu waits for Astra's demo: `GPU_INVENTORY.md` (Phase A item 1),
  `PHASE_PROFILE.md` (item 2: prove 476.1 s = witness ×2 ≈ 30%, commitments 22%, zero-checks 20%, model passes
  ≈ 14%; verify 66.8 s = model passes 74%, crypto ≈ 10 s; vs the gap study's TinyLlama shares), draft
  `GPU_PORT_PLAN.md` (Phase B; §3 and the plain-words block wait for the GPU measurement). Tools:
  `phase_table.py`, `whole_table.py`.
- 21:25:49Z CORRECTION: the waiter that phase_a.sh started at 21:19:43 had loaded the OLD wait_turn.py (the edit
  landed at 21:19:48), so it would not have seen Astra's held hate category. HOLD re-created at 21:25:49 (Astra's
  violence prove still live: no gap missed). `tools/release_hold.py` (detached, bounded 4 h, never signals)
  removes HOLD only after no Astra pipeline process and no astra*/pm-* guard job is seen on 3 checks 30 s apart,
  i.e. after the whole durable demo (violence, hate, finaliser). Every later waiter call loads the new check.
