# Deferred levers

Levers that were judged worth doing but were put off on purpose. Each entry says who deferred it and why, what it is
expected to buy, and what has to happen before it can land. Read this when planning a new profile (for example W16R3)
or when the bottleneck moves. Remove an entry when it lands or is dropped for good.

## 1. Coefficient-form rows (H117b): deferred by Victor, 2026-11-03

- **Ruling:** Victor, console, 2026-11-03: "Go ahead and skip the different commitment encoding for now, but document
  it for later." Recorded in the D59 row of `docs/zkmatrix-poc/ZK60_DECISIONS.md`.
- **What it is:** each committed row's n values are read directly as the coefficients of the message polynomial,
  instead of as its evaluations. That drops the inverse NTT from every commitment. It is the half of H117 that W16R2
  (rate 1/2) did not take.
- **Expected gain** [MODEL unless marked]:
  - the inverse NTT is about 5 ms of a 25 ms rate-1/2 commit at the W16 8B A shape [MEASURED, M21,
    `results/zk60_metal_20261031/README.md`];
  - about ×1.09 on the Mac's one-request proof-only rate, because the Mac is GPU-bound;
  - about ×1.01 on the RTX 5090, where each fork's host work, not the GPU, is the modelled limit
    (`handoffs/20261103-rtx5090-projection.md`, table row 6).
- **Why it was deferred:**
  - it changes every commitment root and receipt byte, so it needs its own full gate cycle;
  - the 5090, the target box, gains only about 1%;
  - the witness build (H124: about 8.6 s per request against 5.6 s of proving on the Mac [INFERRED]) is the larger
    lever and needs no ruling.
- **Already checked on paper** (`experiments/rtx5090-projection-20261103/README.md`, the section "Coefficient-form
  rows: does the hiding encoding allow it"):
  - the rows stay f = d̃ + Z_n·g; the pad term is still a nonzero diagonal times a Vandermonde block, whatever the
    message encoding;
  - the encoder stays a one-to-one map onto polynomials of degree below n + Q;
  - it satisfies the condition in §7 of the δ/2 lemma check (`handoffs/20261101-delta-half-lemma-check.md`).
- **Before it can land:**
  - a new opt-in profile (W16R3 or later) under its own profile strings; W16R2 keeps today's row encoding at
    Q = 280;
  - new goldens with CPU = Metal digests, and the malicious controls ported;
  - the privacy gate's exact-rank checks rerun with the new encoder: PG-R2, the Python rank lemma and the run-level
    joint rank;
  - an independent review, and Victor's ruling to register it.
- **Reconsider when:** a new profile is being cut anyway (folding it in then avoids a second gate cycle), or
  measurement on the 5090 shows the GPU, not the host, is the limit.

## Also deferred (pointers only)

- **D56, a 31-bit field (Mersenne-31 or BabyBear):** Victor, "not now". The cost study found the exact arithmetic
  needs Goldilocks' 64-bit headroom, and carrying the wide relations as digits makes a block slower
  (`results/zk60_metal_20261031/D56_FIELD_SWITCH_STUDY.md`).
