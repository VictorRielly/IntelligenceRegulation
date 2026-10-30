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
- 21:29-21:52Z Astra's demo: violence label 21:29, hate prove from 21:34:45, verify / input-owner, then the
  finaliser's stored-receipt verify (pm-verifypub). 21:52:06Z release_hold.py: demo finished, HOLD removed;
  the queued p-gpu goes through the guard now. (A `gpu-clock-check-2` gpu job, the coordinator's, ran at 21:44.)
- ~21:50Z coordinator: Victor set the laptop to MSI Extreme Performance on mains: under load P0, SM ≈ 2,000 MHz,
  mem 8,000 MHz, 80 W cap (reason 0x4 only), 41–59 °C (was P4 / 1,065 / 6,000 with SW thermal 0x20). Rules
  taken: clocks/P-state/power/temperature sampled with every GPU timing (this lane's sampler: 0.25 s); the slot-18
  kernel and the commitment path re-measured under the new clocks before ranking; a fraction of 256 GB/s quoted
  only at mem 8,000 MHz; any 0x20 / 0x40 flag noted.
- 21:52:16-21:58:03Z **p-gpu** (gcl1-gpu binary, HL_GPU=1 HL_GPU_REQUIRED=1 HL_ZK_CHUNK=force, HL_PB_TIMING=1, 8
  threads, fixed entropy job0.bin): exit 0, "gpu: ON — RTX 4070 Laptop", **0 declines**, 84 chunked device
  commitments; **bytes-gpu: all 30 files equal round 18's recorded job-0 digests** (= the CPU run's). Guard
  child wall **346.6 s vs 476.1 s CPU (1.37×)**; the run 238.3 vs 351.6 s; block walls 225.4 vs 337.5 s;
  **commitments 15.0 s vs 103.3 s (6.9×)**; openings 16.2 vs 14.0 s (device row folds 9.96 s); peak RSS 4.03
  GiB (CPU 8.15), **peak VRAM 1,569 MiB**. Device stats: H2D 31.2 GB in 5.17 s, encode+hash 8.13 s, chunked
  re-encode 3.21 s. Clocks (0.25 s sampler, `logs/pa/p-gpu.gpu.csv`): 158 of 1,089 samples busy (the GPU idles
  between commitments); busy samples P0 90 / P3-P5 64, SM median 2,130 MHz (max 2,520), memory 8,000 MHz in 97
  of 158 busy samples, reasons 0x4 (SW power cap) / 0x0 / 0x1; **no 0x20 or 0x40**; max 47 °C; power limit 80 W.
  First CUDA use (init + NVRTC) inside "stage OUT-C values, endpoint seal": 5.95 vs 3.28 s.
- 21:58:04-21:59:10Z **v-gpu**: the GPU-made receipt verified by the FROZEN production CPU binary 6d65d32e… in a
  fresh process: exit 0, not-flagged, floor 96, verify_seconds 35.7, child 65.2 s. GPU receipt, owner dir and
  the activations / content ids deleted (D46). `logs/pa/phase_a.done` = 0.
- 21:59:39-22:00:15Z **gzc ladder re-measured under the new clocks** (`tools/gzc_measure.sh ladder`, the paused
  lane's round-4 test binary `hashline-5af71eb9341564fc` run read-only, `logs/gzc/ladder.*`): exit 0, peak VRAM
  899 MiB. Kernels only (rounds + fused fold+round), split default: 2^19 5.3 ms, **2^20 ≈ 9.8 ms** (round 4,
  capped: 20.66), 2^21 18.7 ms (39.2). (The ladder's "device body" includes a pageable H2D of host tables,
  1.3–1.9 GB/s: not the body.) Clocks: 95 busy samples, P0 91, SM median 2,355 MHz, **mem 8,000 MHz in 91**,
  reasons 0x4 (power cap) 88; no 0x20 / 0x40; max 53 °C.
- 22:00:36-22:01:42Z **real slot 18, TinyLlama T128 geometry, warm** (`tools/gzc_measure.sh tl128`,
  `logs/gzc/tl128.*`): exit 0, every device == CPU equality held (20 rounds each; dense random and honest data,
  claim none / given), peak VRAM 1,059 MiB. Steady body incl. the device table build: default (split, raw +
  mapped + tail 5) **14.4–14.6 ms** (round 4 capped: 26.5–27.9), split-mat 14.9–15.8 ms (25.9–27.1), lean
  23.4–24.1 ms; kernels only ≈ 10.6–11.5 ms. On the plan figure (72 B × 2^20 × 17 = 1.2835 GB): **89 GB/s =
  34.8% of 256 GB/s** [MEASURED, n = 1; mem 8,000 MHz in 29 of 33 busy samples, 7,000 in 4; P0 28; reasons 0x4
  25; no thermal flag; max 51 °C]. This crosses the speed plan's 25% band on the laptop.
- Commitments in the classifier run (per block, GPU): A 0.393 s = 5.24 ns/word (first device work after the
  2.4 s CPU witness: clock ramp + 0.6 GB upload), H 0.174 s = 2.42 ns/word (GPU still warm); CPU 26.6 / 27.4
  ns/word (8 threads). Openings: A 0.499 s/block on the GPU arm vs 0.249 CPU (the device row fold reads the whole
  A matrix once per 4 weight vectors: `fold_rows_multi_zk` chunks of 4, `k_fold_rows`), H 0.120 vs 0.285. No
  fraction of 256 GB/s is quoted for the commitments: the memory clock was not steady at 8,000 MHz through them
  (the GPU idles between blocks and ramps P5 → P0).
- 22:02-22:05Z `GPU_PORT_PLAN.md` completed (Phase B: re-ranked on the GPU-arm profile: witness ×2 36%,
  zero-checks 24%, model passes 16%, inverses etc. 8%, openings 4.7% (device fold in chunks of 4 is slower than
  the CPU for A), commitments 4.5%; R13 zero-check generator from the slot IR; GPU verification; ownership;
  timeline; 5090; plain words for Victor). The harness refused a `REPORT.md` from this agent (sub-agents return
  reports as text): the report went to the coordinator in the hand-back.
- 22:04Z D46 cleanup: lane `target/` (85 MB) and `target-gpu/` (158 MB) deleted after recording the rung test
  binary's hash (hashline-7baed0d3…: 23056127ee9f…); lane sources unchanged since gcl1 (`manifest_final.sha256`).
  All test receipts, owner dirs, activations and fixtures deleted; only `~/zk60-artifacts/gpu-classifier/ent/
  job0.bin` (64 B, = r18's) is kept. No job of this lane is running or queued.
- **Next concrete step:** step 0 of the plan: the token lane builds and pins a `gpu-cuda` release of the reviewed
  tree (the lane's hooks are not needed for it), the review re-reads only that binary and the decline rule, then
  Sol + this lane start item 1 (GPU witness) and the R13 IR extension in parallel. On resume, rebuild binaries
  with `tools/build.sh` / `tools/build_testbin.sh` (≈ 1.5 / 3.5 min, build class).
