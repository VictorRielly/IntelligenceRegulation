# Continuation: Fast, Lightweight Proofs on the Lattice Line

Status: FROZEN operating plan (2026-08-13). Authority: Victor, console
2026-08-13 — stay on this lattice approach; other proving channels
(hash-STARK / DeepProve / zkGPT wrappers) are a fallback only if the
efficiency targets in TARGET_CONTRACT.md prove unreachable after the
sequence below is measured, not a parallel rewrite.

This page is the standing queue after U-AG-B1 wave 4 and the U-PERF
round that ended early on a usage limit (PROGRESS_UPERF.md). It does
not invent new cryptography. It ranks the remaining engineering so
the next agent session does not reopen a design trench.

Companions: TARGET_CONTRACT.md (+ Amendment A1), LLM_POC_ROADMAP.md,
PROGRESS_UPERF.md, PROGRESS_UAGB1.md wave-4 close, M125_PASS_REPORT.md,
U_PERF_WAVE_REPORT.md, ATTENTION_INTEGER_SPEC.md,
AGGREGATION_LITERATURE.md addendum 2026-08-11 (Attestable watch).
**Executable queue: TASK_BOARD.md** (2026-08-17) — small, self-checking
tasks with exact commands and byte-identity acceptance; any agent
starts there.

## 1. What is already true (do not reopen)

Measured on real frugal-lm `ckpt-00009536`, 12 FFN layers, T = 512,
[MAC-BOX ~1T] unless marked:

- Integer FFN pass accepts 12/12 (three matmuls, SiLU lookup, Hadamard,
  requant, range facts) under one v4 statement. P0 and P2 both run.
- Aggregation replaced the opening volume: 7.38 GiB wave-path artifact
  -> 1.44 MiB full-statement P0 (0.48x the P0 pass gate); P2 ~1.02 MiB
  plus T_blind +448 B. Size at 125M is in gate. This is the solved
  half of "lightweight."
- Composed prove ~69.6 min. Layer prove ~250 s post-BF-F3, of which
  waves ~200 s (80%). Matmul sumchecks are 0.9% of layer prove.
- Composed verify 199.6 s post-BH split (was 955 s). Contract line is
  <= 2 s. This is the unsolved half of "lightweight" (cheap to check).
- U-K9 packed-slot kernel is 4.04x on uk9-bench and 0% on the 125M
  rig (finding PA-F1). No end-to-end speed claim may cite the 4.04x.
- Attention/softmax/RMSNorm/RoPE/GQA have a frozen integer spec and
  a green spike (ATTENTION_INTEGER_SPEC.md, 18/18). They are NOT in
  the engine. TARGET_CONTRACT Section 1's "no integer specification"
  sentence is superseded by that file; the "not implemented" sentence
  still holds.
- GPU: no kernel in this repo. Every 5-15 s GPU row stays [ASSUMED]
  (codex-gpu-readiness: GO on prototyping, NO-GO on claims).
- U-PERF PC landed profile counters + harness arms only. O1-O4 were
  not built. That is the first resumption item.

## 2. Dual goal (the clocks)

"Fast and lightweight" is two measured axes, not a slogan:

| Axis | Contract | 125M now | Remaining |
|---|---|---|---|
| Light — artifact size | Amendment A1 Tier Z / P0 gate | 1.44 MiB P0; ~1.02 MiB P2 | Watch at 8B; not the 125M blocker |
| Light — verify | <= 2 s single-thread | 199.6 s | ~100x |
| Fast — prove | 5-15 s p95 on a named <=450 W GPU | ~70 min 1T; GPU unbuilt | CPU minutes, then a measured GPU factor |

Wave/opening work is 69-80% of prove and lives in the same eval-proof
files that dominate verify (CRS expansion, h cross-garbage). One lane
therefore moves both clocks. GPU only multiplies whatever CPU leftover
remains. Attention and 8B multiply the statement; they must not land
on a 70-minute 125M base.

## 3. Channel decision (binding)

The proving channel is the house lattice line (Route R / zkmatrix-rs:
MLWE/MSIS, integer-exact range facts, HVZK for the declared private
set). Rationale, unchanged:

- The 125M FFN pass on real weights already exists on this channel.
- Assumption class is post-quantum and integer-exact — a stricter
  guarantee than vendor hash-STARK claims that approximate float
  nonlinears (Attestable 2026-08-11: Gemma-4-31B at 53-77 tok/s on
  one H100, no paper, no code, [EXTERNAL, UNVERIFIED]).
- Wrapping zkGPT / ezkl / DeepProve would throw away the pass that
  is already proven and change the soundness story.

Fallback rule, explicit: if, after Phases 0-3 below are measured on
the 125M rig and a named GPU, the TARGET_CONTRACT prove/verify lines
are still out of reach by a gap that kernel work cannot close, then
— and only then — evaluate another channel as a parallel prototype
with an honest comparison row. Do not start that evaluation as a
side trench during Phase 0.

Local untracked `ComputationMonitor/zkgpt_poc/` is not on this path
and must not be merged as a substitute engine.

## 4. Sequence (do not reorder)

Phase 0 — U-PERF PC (NEXT). Profile `uperf-pc wave-profile` /
`pass-profile`, then transcript-preserving O1-O4 in measured-share
order: O1 CRS memo (`expand_level_matrix`), O2 h-garbage NTT-MAC,
O3 `matvec_modq_small` NTT-MAC, O4 `prove_ct_round` alloc/borrow
with RNG order preserved. Files: `eval_proof.rs` + `ct_engine.rs`
internals, marked `[UPERF-PC]` in `ring_matmul.rs`,
U_PERF_WAVE_REPORT.md. Gate: freeze digests unmoved, bit-identical
transcripts at fixed seeds, A/B on 125M layer prove and composed
verify. Do not touch kfield/sumcheck/gkr (PA already shipped; 0%
on the rig).

Phase 1 — leftover CPU on the same rig. Convert the masked-descent
call sites uk9-bench missed (PA-F1). Multithread only if the profile
says the leftover is parallel. Target: 125M composed prove in
minutes, verify toward tens of seconds.

Phase 2 — PoC close. Quiesced p50/p95, BL-F2 hiding-tails ruling,
A1 condition reconciliation, Surface-2 T_blind in-path if still
cheap. Size is already in gate. PoC-complete still requires verify
<= 2 s (LLM_POC_ROADMAP.md Section 1(b)) — that number rides Phase
0-1, not a new design.

Phase 3 — GPU. Feature-gated Metal A1 batch-NTT/commit (U-PERF PB
plan, this Mac), bit-identical vs CPU, then CUDA on the named
<=450 W board. The 5-15 s line stays unlabeled until p95 is
measured on that board over >= 20 warm idle runs.

Phase 4 — full transformer at 125M. Build ATTENTION_INTEGER_SPEC.md
into the engine (U-AT-B1). Keep the FFN-only label until that pass
accepts.

Phase 5 — scale, then headline. 7B FFN dims (512x4096x11008, 32
layers); F-O4 relaxed-e0 before any 8B freeze; then 8B extras.
Only then attempt the TARGET_CONTRACT headline.

Park until clocks move: music provenance, new aggregation design
trenches, four parallel worktrees that abort on a usage limit,
microbenchmarks whose call sites are not the 125M rig.

## 5. Operating rule

One lane at a time, on the measured wall, differential bit-identical
floor. A speedup that moves a freeze digest is a bug. Wall-clock
numbers need a quiesced box; design and correctness work do not.
[MODEL] / [MEASURED] / [MAC-BOX] flags stay mandatory.

## 6. Log

- 2026-08-13: page written; lattice-first decision recorded; Phase 0
  opened. O1 CRS memo landed with the continuation commit
  (expand_level_matrix process-global cache; diff-battery leg O1).
  O2-O4 remain.
- 2026-08-17 (Claude, status recalculation — PROGRESS_UPERF.md
  "2026-08-17" section): PATH CORRECTION for Phase 0. The composed
  pass (`bg_pass_run`, the deliverable) never calls `prove_ct_round`;
  the ct-round wave path (ct_engine.rs, `wave-profile`, O4) is the
  legacy per-layer opening the aggregation stack replaced. The
  composed prove is ~83% `bg_prove_group` (level-0 h cross-garbage
  Theta(n_0*r), the two claim-kernel passes, the A matvecs), all on
  the ~2 us `ring_mul_split_kara_fast` primitive while the A1
  NTT-domain kernels already exist in aux_ntt_core. Phase 0 is
  therefore O2 + O3 + the kernel passes as integer GEMMs in
  eval_proof.rs/bg_*, measured by `pass-profile` (with the new
  EVAL-PROOF DIGEST as the differential gate); O4/wave-profile are a
  secondary rig. The executable queue of small tasks is
  TASK_BOARD.md (Section 4 of this page stays the phase order).
  Honest expectation restated: after Phases 0-3, "8B FFN in minutes
  on one GPU"; the 5-15 s line additionally needs TASK_BOARD T11's
  design items — see the ledger's gap arithmetic.
