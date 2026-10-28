# FZC tail fold/pack — owner handoff — 2026-10-21

No proving speedup measured. Run `20261021T011854Z-d7ab1017`; candidate is low priority.
Research patch: `experiments/fzc-tail-boundary-20261021/candidate_fold_pack.cuh`
(UNCOMPILED). See the experiment README for measurements, limits and source pins.

The interface takes immutable dense-strided Fp2 tables, original table count k,
stride, half length, current challenge r and a fresh disjoint k*half output buffer.
It reads MSB pairs i/i+half at t*stride and writes t*half+i, retaining both coordinates.
It omits the derived tables because the host evaluates the original FzcDesc polynomial.
Original tables stay internal; no masks, openings or randomness are reused.

The active seam is `ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/cuda.rs`,
`DevFzcRounds::try_fold` (existing to_host branch, around line 4730), together with
`fzc_kernels.cu` and fzc_module's function-registration lists. Replace boundary
k_sc_fold + k_fzc_pack with fold_pack into the same packed allocation; retain profile
sync discipline, copy/sync, host-table construction and logical-length update.
Preserve module source-key invalidation and every constructor/raw/layout/range gate.
The root currently has a separate GPU implementation; this is not an integrated patch.

At illustrative n21/k21/kd23/half32: remove one launch, 24 KiB logical device traffic
and 64 derived folds. Retain 10.5 KiB copy, pinned allocation, synchronization, host
work and the minimum 736 MiB arena request. Native time and actual VRAM are unknown.
Keep threshold 5; thresholds 8/10 cost 8x/32x copy and introduce Rayon regions.
No numeric end-to-end rate follows; free removal of unknown exclusive fraction f
bounds total speedup by 1/(1-f), while this removes only part.

Synthetic evidence: 859 checks, 48 FZC cases / 160 rounds, 80 boundary cases and nine
controls; independent 55,423-check audit of 6,144 schedules, 11 pins and six controls.
Full Fp2, original table order, MSB pairs and all eleven geometric pad powers retained.
No native masked proof or verifier ran.

Before integration, the owner must test the actual device with k20/21, degree4/5,
threshold0/5/8/10, n1..11 boundary cases, split/fused/raw switches, BASE and extension
inputs, all pad powers, dirty scratch/shrink/grow, fallback and failure paths.
The existing raw gate prevents consuming unmaterialized original rows after round0;
retain it. Compare canonical unmasked rounds, masked messages, next challenges,
terminals, RNG counts, whole receipt bytes and refusals. Independently verify receipts.
Reject on any mismatch, stale/raw read, later derived-table use or enclosing slowdown.
Measure exclusive boundary and full workload with profiling off; profiling adds syncs.
Owner builds/device runs require the shared heavy/build locks. None ran here.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research ran on one Intel Core Ultra 9
185H CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration and fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Synthetic table
lengths 2–2,048 and modeled cube logs 1–26 are diagnostics, not model context lengths.
Larger workloads remain allowed; increasing context can raise attention work quadratically.
The complete private 8B target of >=50 proved tokens/s remains unachieved.

Next local experiment: count recurring FzcMapped/PinBuf allocation and mapping
calls per slot attempt, including the fallback PinBuf allocated even when mapping
succeeds. Test an independent lease/sequence oracle across changed degree/support,
shrink/grow, failure, stale matching sequence and incomplete device work. Reuse only
storage; preserve fresh contents, challenges, masks, openings and every fallback.
No native adapter or runtime saving is justified until owner phase evidence supports it.

Owner priorities remain complete high-end GPU phase/capacity clocks, independently
verified fixed-context resident 1/2/4/8 workloads, fidelity/refusal fixes and the
all-eleven FZC native A/B under shared heavy/build locks.

Only research files outside runtime/ were written. No production, reviewer,
instruction, calibration, Git or receipt edits; no native build, GPU job, installation,
downloaded-code execution, external write/message, purchase or escalation. Main/Claude
reviews and integrates. Saved reports do not establish delivery or supervisor liveness.
