# M5-LITE Progress

Tranche: wide-object chunking + real FFN-shape commit-bill measurement + post-R1/E2 recost.
Worktree branch: worktree-agent-a942f7ef8277e847d, based on 6493899 (M4 design round = true tip).
NOTE: worktree was initially cut from a stale ref (7a3e7a0); reset --hard to 9fea0a5, then to
6493899 (contains the R1 engine tranche cf02fa8 whose R1.4' costs the recost must count).

## Status
- [x] Worktree rebased onto 6493899
- [x] Read docs (LLM_SCALE_ESTIMATE, A1_AUX_NTT_REPORT, RING_MULT_BOTTLENECK s6, Q4_LEMMAS R1/R1.4',
      SOUNDNESS_REFERENCE s8, audit H-02, M4_LOOKUP_DESIGN E4 rows, manifest.rs, commit.rs,
      ct_engine r1_pad_count/sample_g_masks, ring_matmul chain_demo/pi2-CE/freeze_check)
- [x] Chunking design settled (prose goes in report)
- [x] Chunking implementation (commit.rs wide_* fns + [M5] self-test battery, commit 0928b41)
- [x] m5-bench subcommand in ring_matmul.rs (registered in main; smoke-tested at 128x256x64)
- [x] Bench runs: 3 sessions at FFN 512x4096x11008 (results/m5_bench_ffn_s{1,2,3}.txt);
      min-over-sessions = s3 row-wise: 1T 10.84s (117 ns/paid el), 22T 1.24s, scaling 8.74x
      (9.12x best within-session s2; s1 loaded 6.9x). Peak RSS 94-95 MB. Digest identical
      across all thread counts and sessions.
- [x] Post-R1/E2 recost (printed by m5-bench + report Section 4): commit bill 1104-1563s 1T,
      126-179s = 2.1-3.0 min 22T MEASURED-AT-RATE; GPU 20x row labeled [ASSUMED]; claim layer
      817 chunks/claim = 0.346s 1T measured, R1 pad = 1 chunk/gate round; E4 [MODEL].
      VERDICT: the 1.6-2.0 min 22T ladder claim did NOT hold (15x MT assumption -> 8.7-9.1x).
- [x] docs/zkmatrix-poc/M5_LITE_REPORT.md written; LLM_SCALE_ESTIMATE.md ladder corrected
      (M5-lite row + update block)
- [ ] 42-test suite green (python3 -m unittest discover -s tests)
- [ ] All work committed, worktree clean

## Build command
PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release (in zkmatrix-rs/)

## Key facts settled by the reading pass (resume from here)
- Frozen FFN point: derive_digits(Pi2, 512, 4096, 11008, 0, Q8, true, e=4) -> kappa=9, N_r=57,
  msg_r=32 (freeze-check row "FFN 512x4096x11008 e=4"). Chunk shape = this msg_r=32 class.
- The 17-121 GB monolithic wide CRS: pi2-CE wide commitments need msg_r = h*inner_r
  (h=128 full group; inner_r=32 at FFN) = 4096, up to 11008 for the wider orientation;
  CRS polys = (kappa+msg_r)*N_r with N_r ~ msg_r+kappa+16, 1 KB/poly -> 17.3 GB (msg_r=4096),
  ~124 GB (msg_r=11008). Chunking: commit wide objects as ceil(len/32) chunks under the ONE
  msg_r=32 CRS (2.3 MB), addressing via the existing g_slot_of convention (chunk=u/32, slot=u%32).
  Claims already address (commitment, slot) pairs -> NO protocol equation changes.
- Commit cost per chunk = (kappa+msg_r)*N_r = 41*57 = 2337 ring-MACs, independent of x content
  (commit GEMM runs over rho; x only enters t2 += x).
- Triple at FFN shape: A(512x4096) by rows = 512 commits; B(4096x11008) by cols = 11008;
  C(512x11008) by cols = 11008 (padded 4->32 slots, waste visible; report used vs paid).
  Total 22528 commits = 52.65M ring-MACs ~ 8.5-10.3 s 1T at the A1 measured rate.
- R1.4' recost inputs: quad-ct rounds pay pad SLOTS in existing g-commitment (3/qct, 2/qr, 3/tq);
  gate-only rounds (pi2-CE round W: 1 TwistedQuadRingClaim) pay ONE fresh commitment+opening —
  under chunking that fresh pad commitment is one msg_r=32 chunk, not a wide object.
  E2 zeta rows: weight computation, not commitment. E4 (lookup landing): 9 CtClaims/pass,
  ~120 KB/pass transcript, ~2.3e7 ring-mults/pass weight expansion [MODEL].
- Ladder anchors to check: 99-111 ns/element 1T; commit bill 1.6-2.0 min 22T (assumed ~15x MT);
  element count 9.4e9 (RING_MULT_BOTTLENECK 6.4a) vs 1.33e10 (A1 report s6) — quote both.
- rayon 1.11 already a dep; A1CommitKernel::commit_column is &self, Sync-safe.
- Peak RSS via /proc/self/status VmHWM; stay under ~12 GB (streaming keeps us <1 GB).

## Notes / resume hints
- Baseline build launched (background task bmuah1hq8).
