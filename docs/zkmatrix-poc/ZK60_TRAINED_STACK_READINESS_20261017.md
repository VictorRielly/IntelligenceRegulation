# Readiness after the first trained block: stack, GPU, privacy gate, 8B shape

2026-10-17, read-only survey by a Claude Explore agent for the orchestrator. No
build, test or proof was run. Paths: **C** = `ops/zkp-mvp/candidate/hashline/src/private_block`,
**G** = `ops/zkp-mvp/candidate/hashline/src/gpu`, **JV** = `/home/victor/wt-zk60-jointview`
(gate worktree), **LANE** = `/home/victor/wt-zk60-block125m`. Items marked
[UNCHECKED] are the surveyor's own arithmetic. Planning input, not a result.

## 1. Multi-block run (stack)

- A run has ONE `Shape` and one profile (C/run.rs:76-88); its header absorbs the
  shape, expected IO, the hash of all block digests, the parameter line, one
  calibration digest and one schedule digest (run.rs:338-356). Stage k absorbs
  its block digest, commits boundary `B_k`, proves the block on the shared
  `Layout`, opens `B_{k-1}`, sinks and drops the segment (run.rs:561-644).
- **Already per block** (inside `BlockPublic` digests, private_block.rs:404-620):
  all weights, `gamma_a`/`gamma_m`, RoPE tables (so the RoPE base), the exp
  table (`e_s`), the 256-entry activation table (SiLU member).
- **Shared by the run:** compiled `NORM_TN/CN/CEPS`, all `SH_*`, `F_P`, `F_RO`
  (layout.rs:61-80) and the shape's `f_e`, `norm_wrho`, `wrho_s`; bound once via
  the schedule digest. No residual rescale exists (all residual shifts 0).
- **Plan:** one set of per-profile constants (D24) for all 22 TinyLlama blocks,
  with per-layer variation folded by calibration into each block's gains and
  weights. Per-block `Cn`/`Ceps` is a small, additive change if measurements
  require it (optional `NormCalib` in the attention/FFN publics, absorbed only
  when present; argument.rs:1237-1238/1466 read it from `ctx`; witness and kernel
  take it as a parameter; per-block list hashed into the calibration digest;
  gate port reads it). **Per-block shifts or a residual rescale are NOT small**:
  each shift fixes a remainder-limb decomposition (layout.rs:650-654), so they
  need per-stage layouts; avoid unless fidelity demands it.
- Memory: one witness at a time, segments sunk and dropped (ruling M-3), two
  boundaries live, verifier streams segments. Measured: 12-block 125M CPU run
  10.15 GiB vs 10.42 GiB one block; 12-block GPU run host 3.94 GiB, VRAM
  2,113 MiB, prove 318.22 s (`results/zk60_mvp_20260929/baseline-stack-gpu-attempt2/`).

## 2. GPU keyed commitment route

- Shape-generic: the backend sees `PcsParams` and flat data (G/mod.rs:655-665),
  chunks above 1 GiB or on allocation failure (cuda.rs:3662-3664, 2080-2130);
  only limit an NTT assert log_n <= 24. Only commitments/openings run on the
  GPU; slots and witness stay on the CPU. Never run at width 2048 or 4096.
- **Hazards to fix before larger T:** (a) a device decline silently falls back
  to the CPU path with fully materialized codewords (mod.rs:664;
  `HL_GPU_REQUIRED` only logs) — 17.75 GiB host at TinyLlama T512; must fail
  closed when GPU mode is claimed. (b) The 64 MiB wire segment cap
  (C/wire.rs:28, 379) refuses TinyLlama T512 (73.7 MB counted) and 8B T512
  (100.3 MB); it is a transport bound, not transcript-bound, so it can be per
  profile. (c) The device memory pool retains allocations.
- Counted floors (`results/zk60_1b_model_20260927/layout_ladder.csv`, five-limb
  tn=11 geometry; D24's four-limb geometry is slightly smaller):

| TinyLlama T / log_cols | VRAM floor | host before H | CPU fallback | block receipt |
|---|---:|---:|---:|---:|
| 32 / 13 | 0.22 GiB | 0.22 GiB | 0.65 GiB | 12.0 MB |
| 64 / 14 | 0.46 GiB | 0.47 GiB | 1.37 GiB | 18.9 MB |
| 128 / 14 | 0.73 GiB | 1.00 GiB | 2.74 GiB | 23.5 MB |
| 256 / 14 | 1.51 GiB | 2.48 GiB | 6.58 GiB | 36.3 MB |
| 512 / 14 | 3.76 GiB | 6.79 GiB | 17.75 GiB | 73.7 MB |

  8B geometry (Mistral probe, same dims as Llama-3-8B): T512 VRAM 5.17 GiB +
  194 MiB scratch, host before H 9.86 GiB, block receipt 100.3 MB; T1024 VRAM
  14.22 GiB, host 27.17 GiB (impossible on the laptop). [UNCHECKED] scaling the
  125M measured/counted VRAM ratio gives ~4.1–4.5 GiB at TinyLlama T512 and
  ~5.7–6.0 GiB at 8B T512.

## 3. Privacy gate at a new shape (runbook)

What ran at 125M (evidence only; D22 still covers only the toy): two-block
captures via `capture_a_125m_run` (C/run_capture_tests.rs:2045-2084; env
`HL_PB_CAPTURE_DIR`, `HL_PB_INPUT=dense|zero`, `HL_PB_CAPTURE_BLOCKS`,
`HL_RUN_CAPTURE_PUBLIC_TABLES=1`, `HL_TEST_SOURCE_COMMIT`; ~31 s proving each at
~10 GiB; bundles 273–281 MB under `/home/victor/zk60-artifacts/`), then the
gate `JV/scripts/zk60_native_rg_m125.py` driving `zk60_native_run_gate.py`
(commands: JV/docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md:1754-1765 and
JV/results/zk60_native_run_gate_block/m125.sh). Stages: replay (27,828
challenges), hash layer (2,304 columns), terminal identity (46/46), rank/
disclosure (A 0, H 2 = public LogUp identity, endpoints 0, boundary 0, M 0),
blinding reproduction (8.26 M entries, 0 differing), CFS mask, joint assignment,
controls, channel table. Costs: L=2 full ~2.2 h at 5.5 GB; L=12 pass A 840 s at
6.8 GB, full pass projected 3.5 h.

For TinyLlama: (1) add `capture_a_tinyllama_run` (helper `capture_a_run_into`,
run_capture_tests.rs:1855, is shape-generic) and port LANE's standalone-block
writer; export `norm_tn`, `norm_cn_a`, `norm_cn_m`, `norm_ceps` in
`run.json["shape"]`. (2) Capture dense and zero bundles at T32 (log_cols 13),
L=2, then a standalone block. (3) Gate: the terminal port reads the constants
from the bundle (JV/scripts/zk60_native_rg_terminals.py:637-645, 1283, 1573);
`zk60_native_rg_predict.py` gets the D24 window formula; re-pin moved source
files; write the prediction first; cross-profile bundle from 125M or rung-K4.
(4) [UNCHECKED] TinyLlama pads only {L, F, Tab} versus 125M's {Ht, L, D, Q, S,
Tab}: re-derive pad controls. (5) Add TinyLlama to the counting scripts'
`SHAPES` tables (`results/zk60_generic_rank_lemma_shaped/`,
`results/zk60_hash_layer_fs_lift_run/run_hash_counts.py`,
`results/zk60_joint_law_composition_run/run_law_counts.py`,
`results/zk60_private_run_multi_block_check/`). [UNCHECKED] At T32 expect
minutes and under 2 GB.

## 4. The 8B shape (Llama-3-8B: 4096 / 14336 / 32q-8kv / dh 128 / 32 blocks)

`Shape::new` and `Layout::for_shape` accept the dims at T512/T1024, log_cols 14.
Needs: D24 with `tn = 9` (D_max 2^21 with -32768 gives a 34-bit window at tn 11);
an 8-KV-head development shape (exists only in LANE `k8_tests.rs`); calibrated
`e_s` and rope base 500000 (driver hard-codes `e_s = 0` and 10000.0,
mvp_driver.rs:172-173); per-profile wire cap; no-wrap premise (layout.rs:610-676)
re-derived for 8B ranges [UNCHECKED estimate: |2·Cn·g·x| ~ 2^33, far below p];
calibration cliffs at width 4096 (`SH_U = 0`, fixed `SH_G`/`SH_Z`, `F_P = 9`
mass loss at large T). Host memory 9.86 GiB before H at T512 is the laptop's
binding limit; the 5090 machine is required for 8B.
