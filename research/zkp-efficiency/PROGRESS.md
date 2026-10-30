# ZKP efficiency progress

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
