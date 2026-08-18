# U-PERF2 lane Q — the prover's CPU-side blocks: prove-group (level-h host side, the small-ring GEMM family), commit phase, CRS SHA-256, transport

Status: IN PROGRESS (skeleton, 2026-08-18). Written by lane Q of the
U-PERF2 round 9 (ledger: PROGRESS_UPERF2.md "Lane Q" + "Agent Q
status"). Worktree /home/victor/wt-uperf2-q, branch uperf2-q, opened at
151edc9 (= main after round 8). Box: the WSL box (Intel Core Ultra 9
185H, 22 threads, 15 GB, RTX 4070 Laptop 8 GB; no m125 export except the
`m125_ffn_export_wsl` copy the rigs use). Lane P (descent kernels) runs
concurrently in /home/victor/wt-uperf2-p; every wall-clock number
carries `[WSL-BOX 8T QUIET|NOISY-SHARED]` and `[MEASURED]` /
`[ASSUMED]` / `[MODEL]`.

The rule (unchanged): every optimization is DIFFERENTIAL — the
pre-change body stays reachable as `*_ref` and under
`ZK_UPERF_ORACLE=1`; the outputs are byte-identical; the batteries hold
at ZK_THREADS 1/2/7; freeze-check's 98 on-box rows are identical to the
pre-change capture; the REAL rigs reproduce their digests (3x16
93a98700… / 0ae9cdae…; 12x128 4a3af8c3… / 742d88e1…; 12x512 2f8a92f8… /
4c259008…).

## 0. One paragraph

(to be written at close — final numbers)

## 1. Design (the plan, in the brief's order)

Baseline (the merged tree at 151edc9, 12x512 8T+GPU, QUIET, 34.1 s;
`fp_12x512_NO_gpu.txt`): bg.prove-group 12.30 (bg.level-h 4.61 =
ep.level-h-pairs 4.59 over 17 calls; ep.psi0-factored 2.65 with
m.psi0-ntt 1.74 and m.phi-setup 0.85; bg.fold 1.89 with m.fold-ntt 1.14;
bg.kernel-rows 1.77; bg.matvec-chunks 1.50 with ep.matvec 1.57;
bg.kernel-phi 0.39), bg.commit-phase 5.02 (d.precommit-u0 3.46,
d.chain-derive 1.33, d.digit-witness 1.13), ep.crs-expand 2.76
(m.crs-blocks 1.92, m.crs-walk 0.07), ep.transport 1.95 (m.tr-s 1.17,
m.tr-t5 0.37, m.tr-asm 0.23). Target: these four blocks ~22 s -> ~13 s
[ASSUMED].

1. **level-h host side** (`bg.level-h` 4.6 s): the level-0 h pairs run
   `level_h_pairs_with_block` — per 1024-position u-block a HOST phi fill
   (`Phi0Source::fill`: one PHI_vr per value ring, `poly_scale` per
   limb, into a u64 `Vec<Poly>`), then one `ntt_gemm_modq_small` call
   whose device path re-scans s_max, packs the u64 phi into u32 pinned
   staging, uploads, transforms, GEMMs, flushes and copies the r x r
   table back — 170 calls of 64x64x1024 at 12x512, each with an
   un-overlapped fill + first pack, a per-block flush + d2h, and a host
   `poly_add` accumulation of the 4096 output rings. Design: a
   device-resident LEVEL-H SESSION (`gpu::LevelHStream`): the r x r
   split-halves accumulator stays on the device across the u-blocks of a
   level; the phi fill writes u32 mod-q rings STRAIGHT into the pinned
   staging (`Phi0Source::fill_u32`, the same `poly_scale` residues), the
   w digits are packed i8 alongside; s_max is the level's (one scan of
   the witness store, a bound >= every block's, so the exact-integer
   window is at least as strict); the fill+pack of block i+1 runs on the
   host while the device transforms and multiplies block i (ping-pong
   staging + events, as K's pipeline but across blocks); the flush
   (reduce -> inverse NTT -> center -> mod q -> add) runs once per
   exact-integer window (at level 0 the whole level is one window) and
   the table comes back once. Bit-identity: every accumulated quantity
   is an exact 128-bit split-halves integer of the same products, the
   flush is K's flush on the same u128, and mod-q addition of exact
   partial sums is partition-independent (the CPU body already relies on
   this across its windows / u-blocks). Oracle: the unchanged
   `level_h_pairs_with_block` body (bypass / `ZK_UPERF_ORACLE=1` /
   default build). Expected: 4.6 -> ~2.5 s [ASSUMED] (device time per
   block ~10 ms: fwd 3.0 + gemm 7.2, K's Section 2.3).
2. **the other small-ring contractions on the device**: the "few fixed
   rings x many streamed rings -> one inverse per output" family — the
   quinary fold (`fold_chunks_ntt`, m.fold-ntt 1.14 s: 64 small c_j
   against 64 x chunk small w, exact i64 outputs), the transport's S / T5
   combines (m.tr-s 1.17, m.tr-t5 0.37: 12 / 11 limb-split alphas
   against general operands, mod-q outputs), `compute_psi` (0.24) — as
   ONE device combine kernel (per output ring: K MACs on t-lanes, an
   in-block inverse transform, center -> i64 or center -> mod q). Then
   the psi0 u-major accumulation (m.psi0-ntt 1.74) if the value-ring
   upload volume allows. Measured before/after per item; the ones not
   reached go to Section 5 with their hook shape.
3. **the commit phase** (5.0 s): `d.precommit-u0` 3.5 (attribution
   first: the level-0 CRS A expansion vs the level-0 A matvec on the
   16-row device tile vs Bu), `d.chain-derive` 1.3, `d.digit-witness`
   1.1.
4. **CRS** (2.8 s, m.crs-blocks 1.9): the SHA-256 counter-mode blocks on
   a hand-batched SHA-NI core (4 interleaved single-block compressions
   with `_mm_sha256rnds2_epu32` / `_mm_sha256msg1/2_epu32`, no new
   crate; identical digests by definition, asserted against `sha2` in the
   battery) + a reused stream buffer (no fresh 2 GB of page faults per
   rig). The CRS bytes are the freeze.
5. **transport** (2.0 s): item 2's combine kernel carries m.tr-s /
   m.tr-t5; the assembly (0.23) stays.

Prof ids 80-89 (`q.*`, observation only): q.lh-fill, q.lh-gemm,
q.lh-flush, q.lh-stream (the session's wall), and the rest as needed.

## 2. What landed

(per item: function, oracle, call sites, status)

## 3. Differential evidence

(batteries at ZK_THREADS 1/2/7 in both builds; freeze rows; rig
digests)

## 4. Measurements

(before/after per item with the same command; the rig rows GPU and
CPU-only)

## 5. What is left / honest state

(designed-but-unbuilt items with their hook shape)
