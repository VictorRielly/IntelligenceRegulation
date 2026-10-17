# Borrow identity lookup columns — cycle 0062

Run `20261017T122624Z-c30acfa0`, 2026-10-17 UTC. Research-only, CPU-light.
No native speedup, peak-memory improvement, profile admission or private 8B
performance result is established.

The current `ops/zkp-mvp/trained-1b/hashline/src/private_block/protocol.rs`
materializes every U8 lookup column over its padded domain. The columns stay
alive across A/M commitment and H-helper construction. Identity lookups
(`cst == 0`, one term with coefficient 1) can instead borrow witness slices.
Scaled columns whose public calibration coefficient is 1 qualify too.
All other lookups retain the original wrapping-i64 materialization.

The candidate uses `Cow<'a, [i64]>`, preserves indexed column order and the
existing slice-taking H helpers, and generalizes the histogram over
`AsRef<[i64]>`. The old materialization functions remain as native references.
The full padded prefix `[..len]` is borrowed; an oversized suffix remains
ignored, as it is in the original map. No witness lifetime is extended beyond
the old `drop(looked); drop(wit);` boundary. This is per-proof borrowing;
no private state is reused between proofs.

Commands, also recorded with source hashes and exit codes in `execution.json`:

```
python3 experiments/lookup-borrow-catalog-20261017/run.py
python3 experiments/lookup-borrow-catalog-20261017/prepare_candidate.py
python3 experiments/lookup-borrow-catalog-20261017/audit.py
```

Seed 2026101762. Experiment and audit set one CPU affinity, nice 19,
59-second CPU/wall bounds and 512 MiB address-space cap. Estimated experiment
memory is below 64 MiB. Local device: Intel Core Ultra 9 185H, CPU0, no GPU.
Final experiment: 1.050006 s, 17,464 KiB RSS. Separate audit: 0.011948 s,
14,904 KiB RSS. These timings are diagnostic test costs.

The restricted source recognizer fails on unknown constructor grammar and
matches a separately written semantic catalog at 48 synthetic configurations.
The current native catalog has only single-plane terms. Differential evaluation
checks 288 domains, 4,176 columns, 23,834 i64 words and 12,328 Fp2 helper
values. The reference uses ctypes signed conversion and direct Fermat/norm
inversion; the candidate uses wrapping arithmetic and the byte inverse cache.
Both retain invalid-value bucket-0 fallback. Eleven negative controls cover
incorrect borrow classification, padding, saturating arithmetic, clamping,
present/absent/out-of-range zero denominators, helper order and source drift.
Five extra synthetic columns exercise affine/multiterm/constant fallback.
This is a Python semantic experiment; it does not execute native Rayon paths.

The 235-check independent audit checks all 12 census rows with closed-form
counts, source pins, unchanged helper functions and the public shift constants
of all 22 layer manifests. It never copies model arrays or private fixtures.
An initial audit used a comment as a span delimiter and included the inserted
function; its failed assertion and source are retained under
`initial-audit-span/`. Balanced function spans corrected the audit.

| TinyLlama context | All materialized lookup payload MiB | Borrowable MiB | Remaining owned MiB |
|---:|---:|---:|---:|
| 32 | 45.5625 | 34.625 | 10.9375 |
| 64 | 97.625 | 72.750 | 24.875 |
| 128 | 221.250 | 167.500 | 53.750 |

These are allocation-free source counts per block, not measured RSS or bus
traffic. At T128, 57 of 83 descriptors borrow; 75.706% of lookup payload is
avoided. Witness, A/H commitments, masks, H outputs and proof bytes are unchanged
by the proposal. The final witness storage is also unchanged. Bigger context
rows and all Llama3-8B rows are hypothetical counted geometries with the same
public shifts, not admitted or timed profiles; `result.json` labels this.
Attention score work grows quadratically with context.

An owner CPU phase run completed during this cycle. Filtered public phase
lines and the original source hash are in `retained/`. Across 22 TinyLlama
blocks at T128, lookup construction plus histogram is 0.517 s of a
175.258632-second guarded process. Removing the entire enclosing mark would
yield at most 1.002959x directly for this diagnostic, conditional on all other
work staying fixed. Cache/allocator effects on other phases remain unknown.
H U8 helpers take 6.911 s and keep their arithmetic in this proposal. D/F
zero-checks take 27.501/17.631 s; softmax zero-check takes 11.531 s.
This instrumented run has in-process verification but no fresh-verifier
evidence inspected here; it contributes zero credited positions. Its CPU
shares cannot establish GPU shares. Existing R3 verified diagnostics are
retained separately in the prior cycle.

Added costs: public classification, Cow descriptors, generic histogram plumbing,
possible allocation/task-balance/compiler effects. Eliminated work: payload
allocation and construction of identity columns. There is no extra affine
recomputation or extra scan. Physical traffic and native enclosing savings
need owner measurement. Complete 8B ceiling remains unknown:
`N / (total - removed critical-path work + added costs)`.

`protocol-candidate.patch` is **uncompiled and unapplied**. The owner must
recompare pins, compile under shared build/heavy admission, compare serial and
Rayon paths on real layouts, preserve malformed-input refusals/padding,
RNG/transcript/frozen bytes and independently verify complete receipts.
Actual allocator/peak/workload measurements decide capacity and speed claims.
Any mismatch rejects correctness; unchanged or worse native enclosing cost
rejects a speed claim. No GPU/build/proof was launched here.

The GPU-assisted phase run subsequently completed during this cycle. It took
161.857226 s process time on one RTX 4070 Laptop, including 15.899 s witness
work and 10.148 s in-process verification. Prove run minus witness is
119.910 s and still includes boundaries/serialization/sink. Startup and
serialization are unisolated; no fresh-verifier evidence was inspected.
Receipt size is 497,665,904 B; one cold T128 pass, 22 trained 1.1B blocks,
16 Rayon threads, n=1. It contributes zero credited positions. Guard peak
VRAM is 3,105 MiB and host RSS 3.07 GiB. Filtered phase evidence is retained.

GPU D/F zero-checks take 25.353/19.484 s, versus softmax 11.834 s; D/F masked
sumcheck substeps take 19.860/16.457 s. Lookup plus histogram is 0.748 s,
giving a conditional direct full-mark deletion ceiling of 1.004643x. These
new measurements reinforce demoting borrowing for speed. They are not a
controlled A/B against earlier runs, nor a complete private 8B result.

Next local: capture the exact current `SC_FZC` closure in `argument.rs:1602`
and census/differential public base-constant multiplication shortcuts, with
full-extension, helper, pad and hosted-term controls. D and softmax already
have related Stage35 work; the F closure still has extension multiplication
by public `p1`, `k_h` and `k_g`. The compiler may already simplify these.
Native enclosing benefit remains a gate. Exact duplicate histogram descriptors
(2,424,832 repeated word visits, 8.36% of T128 histogram input) are demoted
because their measured parent phase is small. No duplicate H term is removed.
