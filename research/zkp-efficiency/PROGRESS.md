# ZKP efficiency progress

## 2026-11-03 — Claude researcher cycle (rtx5090-projection-20261103)

**No measured proving improvement.** This cycle projected today's stack onto an RTX 5090 from the Mac's measured
profile, and re-ranked what is left.

**The projection** (W16R2 at Q = 280 + D55, one 8B request of 128 tokens; arithmetic on measured parts and spec
sheets):
- **Counting only the proof**, as the Mac's 22.9 tokens/s does: about **54–82 proved tokens/s** with today's code
  around the proof, **69–117** after two small byte-identical fixes, and about 40 if the port is done badly.
- **The GPU is not what limits it.** The host work each concurrent block proof still does is the limit, because 32 GB of
  VRAM fits only about 8 of them at once.

**The bigger finding: the witness is outside every clock so far.**
- **What it costs.** The test harness spends about 8.6 s per request building the 32 layers' witnesses before the timer
  starts. That is about 0.27 s per layer, more than the 0.17 s per layer of proving. The figure is inferred from the
  test's wall clocks, not timed directly.
- **Why it adds.** D55 needs every layer's output before any block proof starts, so this time adds directly to one
  request.
- **Counted the way the target counts:**
  - the Mac is at about **9 tokens/s**, not 23;
  - a 5090 with today's witness code would be about **6–11**;
  - with an exact integer forward pass on the GPU, **48–76** (86% of the model's range clears 50).

**What to do, in order:**
1. Time the witness directly.
2. Replace the witness's scalar matrix products with exact int8 SIMD or GPU products (byte-identical).
3. Two small fixes to the serial start of a request:
   - check the weights once per loaded model, not once per request (0.38 s);
   - commit the 31 layer boundaries in parallel (0.23 s).
4. On the 5090, move the host work into the GPU port, not just the kernels.

**The remaining kernel and commitment levers.**
- On the Mac they are worth 1–11% each. The byte-preserving ones together give about 26–28 tokens/s; with the
  format-changing ones (coefficient-form rows, batched zero-checks, a non-power-of-two FFN domain), about 31–37.
- **Coefficient-form rows** keep the hiding and soundness arguments, but change every byte. They need Victor's call:
  join W16R2 before it registers, or wait for a later profile.

**For ≥ 50 proved tokens/s on the complete private 8B:**
- The Mac cannot reach it on any lever found.
- A 5090 plausibly can, but only with a fast exact witness forward **and** the host work moved onto the device or kept
  under about 0.2 s per concurrent block.
- It remains **unachieved**. New full-stack proofs, passes and proved positions: **0 / 0 / 0**.

[Experiment](experiments/rtx5090-projection-20261103/README.md) ·
[Handoff](handoffs/20261103-rtx5090-projection.md) ·
[Dated report](progress/20261103-claude-rtx5090-projection.md).

## 2026-11-01 — Claude researcher cycle (logup-gkr-20261101)

**No measured proving improvement.** This cycle settled the LogUp-GKR question with a measurement instead of an
estimate.

**What ran.** A streamed LogUp-GKR prover and verifier for W16's 16-bit tagged range lookups. It runs on the CPU and
matches an independent reference prover. One lookup outside the table breaks the identity and is refused.

**Measured on one block's worth of lookups (2^25)** (shared Mac, n = 5, diagnostic):
- The GKR proof takes **0.160 s**.
- The committed-helper path it would replace spends **0.183 s** just writing and committing the helpers.
- The GKR touches more memory per lookup (187 B against about 132 B).
- The kill rule therefore does **not** fire, because GKR is cheaper once the helpers' share of the zero-checks is
  counted. That share is an estimate.

**What it is worth on the Metal GPU (projection):**
- **×1.00–1.15 per block** for the range lookups alone;
- **×1.07–1.25** if every lookup moves into the tree and the `H` commitment disappears.
- That is not enough to justify a new proof format on its own.
- A one-page zero-knowledge design is written, unreviewed. Its main open risk is the joint-view simulation.

**Bigger, cheaper levers found while decomposing the gap after W16** (estimates):
1. About a third of today's block is host-CPU work. Overlapping it with the next block's GPU work could raise
   throughput ×1.3–1.6 without changing any proof byte.
2. Each GPU sumcheck round has a fixed cost of about 0.3 ms, about 0.06 s per block.
3. The exp/activation helper inverses could use precomputed table inverses, saving about 0.02 s byte-identically.

**For ≥ 50 proved tokens/s on the complete private 8B.**
- The target needs ×5.9 from today's 0.47 s block.
- On the estimates above, it is plausible only if all of these land together:
  - the byte-identical levers;
  - host/GPU overlap;
  - committing less;
  - a ≥ ×3 device speedup from the RTX 5090.
- It remains **unachieved**. New full-stack proofs, passes and proved positions: **0 / 0 / 0**.

[Experiment](experiments/logup-gkr-20261101/README.md) ·
[ZK note](experiments/logup-gkr-20261101/ZK_DESIGN_NOTE.md) ·
[Handoff](handoffs/20261101-logup-gkr-w16.md).

## Previous report

Cycle 0173 complete — 20261030T214123Z-4c34fc82, 2026-10-30 UTC.

**No measured proving improvement.** The streamed lookup arithmetic matches
independent references through 65,536 synthetic lookups. It is not a GKR proof.
The main experiment passed 247,337 checks and 13 controls; the separate audit
passed 179 checks, including three additional controls.

The useful negative: cancelling fractions that share a random denominator
leak a property of hidden lookups. An unequal-denominator variant hides the
root denominator in the tested marginal distribution, but still needs a
complete privacy construction and constraints on its new leaves.

A public table recurrence replaces 65,536 extension-field multiplications
with one multiplication plus 65,535 subtractions. All 196,608 tested entries
match. Table storage and gathers remain, and including setup made root
construction slower in 11 of 12 final diagnostic cases. No proof speedup follows.

One low-priority CPU affinity on Intel Core Ultra 9 185H; no GPU. Main:
2.131 s / 19,992 KiB RSS; audit: 0.167 s / 15,400 KiB; recurrence:
1.730 s / 20,716 KiB. Every experiment stayed below 60 s and 512 MiB.

New independently verified full-stack proofs / passes / proved positions:
**0 / 0 / 0**. Actual model context: **none**. Witness, proof, serialization,
verification, startup and prefill clocks, startup fraction, proof latency and
bytes, and steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. The complete
private 8B / >=50 proved-token/s target remains unachieved. Larger workloads
remain allowed; attention can grow quadratically. No masks or openings are reused.

Eight LIVE source records cover LogUp-GKR, Libra, DeepProve, Logup*, recent
GPU-kernel work and older finite-difference mathematics. Access failures,
dates, licences and unverified commit details are retained. All 108 prior
hypotheses remain; H107 was refined and H109/H110 were added.

Next: adapt the existing tiny top-down fraction-layer consumer to an explicit
hidden-root and leaf-mask contract. Count every new message, binding, mask
and opening group, then test the joint view before larger arrays. Main/Claude
reviews the handoff; native proof and GPU measurements remain with their owners.

[Experiment](experiments/streamed-logup-root-blinding-20261030/README.md) ·
[Design note](experiments/streamed-logup-root-blinding-20261030/ZK_DESIGN_NOTE.md) ·
[Handoff](handoffs/20261030-streamed-logup-root-blinding.md) ·
[Dated report](progress/20261030T214123Z-4c34fc82.md).
Saved reports do not establish message delivery.
