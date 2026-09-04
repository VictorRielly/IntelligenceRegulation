# The 60 tokens/s plan: a rigorous zero-knowledge PoC, and the factor budget that gets there

Status: LIVE, written 2026-09-04 (orchestrator, Claude) at Victor's
request: "a plan that proceeds to a proof of concept in a way most
likely to meet the 60 token per second goal while being a rigorous
ZKP". It supersedes the lane-by-lane menu; the levers below are
complementary and the plan runs them together, because the arithmetic
in §2 says no single one of them is sufficient.

Labels as everywhere in this repository: [MEASURED] = a run happened
on a named machine; [COUNTED] = arithmetic over measured pieces;
[MODEL] = an estimate with stated assumptions; [EXTERNAL] = someone
else's unverified claim. Sources: `U_PERF3_ROUTE_B_THROUGHPUT.md`
(lane YY, the throughput memo), `TARGET_CONTRACT.md`, and the round
12/13 lane results in `PROGRESS_UPERF3.md` (AC, AD, AE, AF, AG, AH,
AI).

---

## 0. The finding, in one paragraph

The goal is 60 proven tokens per second for a 30B-class model on one
GPU. The fastest thing ever measured in this project is **5.36 proven
tok/s** — the 8B feed-forward statement, 32 layers x 512 tokens, on
the laptop's RTX 4070, without attention and without zero knowledge
[MEASURED, lane AH]. Reaching 60 tok/s at 30B is a **61.6x** gap in
proven MAC/s. That gap is closable on paper by hardware alone, but
only for a statement that is not the product: **completing the
statement costs 3.55x** — attention 2.87x [COUNTED, lane AE, at 8B
and T = 512], zero knowledge in mode P1 1.047x [MEASURED, lane AD],
and the range facts the contract still owes 1.18x [MODEL]. Applying
that divisor to the throughput memo's own H100 cells gives the
result this plan is built around:

| cell, 30B prefill on one H100 | FFN-only, no ZK | **honest statement (attention + ZK P1 + range facts)** |
|---|---:|---:|
| by scaled constants [MODEL] | 8.3-60 tok/s | **2.3-17 tok/s** |
| at the counted spec-sheet floor [COUNTED] | 47-138 tok/s | **13-39 tok/s** |

**60 tok/s at 30B is outside even the counted floor once the
statement is honest.** No amount of kernel work reaches it, because
the floor is set by hashing 311 GB of encoded activations per proof.
The same divisor applied at 8B tells a different story:

| cell, 8B prefill on one H100 | FFN-only, no ZK | **honest statement** |
|---|---:|---:|
| by scaled constants [MODEL] | 26-187 tok/s | **7.3-53 tok/s** |
| at the counted floor [COUNTED] | 140-400 tok/s | **40-113 tok/s** |

So the plan is: **make 8B the proof-of-concept target, where 60 tok/s
sits inside the counted floor and the whole distance is kernel
quality; and treat the hashed-byte volume as the one design change
that decides whether 30B ever follows.** Everything else — the host
marshalling, the attention port, claim folding, batching — is
necessary and none of it is sufficient.

---

## 1. What "60 tokens per second" has to mean

Three workloads, three different answers. The plan must say which one
the PoC claims.

| workload | what one proof covers | reachable at 60 tok/s? |
|---|---|---|
| **512-token prefill** (one proof per 512-token window) | the weight side is amortised over 512 tokens: 0.3-0.6% of the budget | **yes at 8B** [COUNTED floor 40-113]; no at 30B [13-39] |
| **batched decode, B >= 4-16 requests per proof** | the weight side is amortised over B tokens | plausible at 8B; at 30B the counted floor is 28-100 tok/s FFN-only, i.e. 8-28 honest |
| **batch-1 decode** (one proof per generated token) | the full 21.5 GB weight pass per token | **no, on any counted assumption**: the linear weight opening alone is 25-60 ms against a 20 ms budget at 30B, and every hash-based PCS keeps it linear [COUNTED, memo R1] |

The competitor's headline (53 tok/s at batch 1, 30B-class, weights
private) [EXTERNAL, VENDOR-CLAIMED, unverified] sits 1.5-4x above our
counted floor for batch-1 decode. Either their per-token weight side
is sublinear by a structure not known to this repository, or the
figure is amortised. **This plan does not target batch-1 decode**,
and any published number must name its workload.

**Recommended PoC claim**: *60 proven tokens per second, 8B-class
model, complete transformer layers, zero knowledge for the inputs
(mode P1), 512-token prefill, one H100, p95 over 20 warm runs.* It is
inside the counted floor, it is a complete and rigorous statement,
and it beats the competitor's rate on a workload we can define
precisely. 30B follows from §5, or it does not follow.

---

## 2. The factor budget

Required: 1.86e12 proven MAC/s (60 tok/s x 3.1e10 MACs per 30B
token). Measured today: **3.02e10** [MEASURED, AH]. Gap 61.6x.

Every lever, with what it multiplies and how well it is known:

| # | lever | factor | evidence class |
|---|---|---:|---|
| L1 | laptop RTX 4070 -> one H100 | **4.7-33.6x** (central ~13x on HBM bandwidth 256 GB/s -> 3.35 TB/s) | [MODEL]; never measured on any board |
| L2 | the four host marshalling items | **2.4-2.9x** | [MEASURED share]: 56-63 s of the 95.5 s pass is host work with known byte-preserving fixes |
| L3 | kernel quality toward the counted floor | **1.5-5x** | [COUNTED]: the scaled cells carry ~10x on streaming loops, 3.5x on the small zero-check |
| L4 | halve/quarter the hashed bytes (rate 1/2, and/or a 31-32-bit field) | **2-4x** | [MODEL]: moves the activation floor from 7-21 to 2-10 ms/token; the dominant floor term |
| L5 | fold the claims (AG's item 1 + the batched-evaluation reduction) | bytes **x0.44-0.50**, time **x1.05-1.15** | [COUNTED bytes, MODEL time] — a byte lever, a slight time cost |
| L6 | reduce attention's T^2 committed planes | up to **1.6x** on the statement divisor | [MODEL]; unexplored |
| L7 | batching B >= 4-16 | decode only; nothing at prefill | [COUNTED] |
| D1 | attention in the statement | **/2.87** at 8B, T = 512 (less at 30B: the surcharge shrinks with width) | [COUNTED, AE]; AG measured 1.17x at T = 16 and 1.61x at T = 64 |
| D2 | zero knowledge, mode P1 | **/1.047** | [MEASURED, AD, at 8B width] |
| D3 | the range facts the contract owes | **/1.15-1.20** | [MODEL] |

Composed, at 30B, honest statement:

```
3.02e10  x 13 (L1)  x 2.5 (L2)              = 9.8e11   -> 31.6 tok/s FFN-only
         / 2.5 (D1) / 1.047 (D2) / 1.18 (D3) =          ->  10.2 tok/s honest
         x 3 (L4)   x (2.5/1.75) (L6)        =          ->  43.7 tok/s
         x 1.5 (L3)                          =          ->  65.5 tok/s
```

**Read that honestly: 60 tok/s at 30B needs essentially every lever
to land at or above its midpoint.** It is not a plan with slack. The
same composition at 8B clears the bar with L1 + L2 + L3 alone, which
is why the PoC targets 8B.

---

## 3. The plan: five tracks, run together

The tracks touch disjoint files and map onto the repository's
existing lane discipline (sibling worktrees, `OWNS:` blocks, the four
byte gates green at every rung). They are ordered within a track and
parallel across tracks.

### Track A — the statement (this is what makes it a rigorous ZKP)

Nothing else in this plan means anything if the proof covers half a
transformer. Today's 8B proof is feed-forward only: no attention, no
norms, no embeddings, and each layer's input committed from the
export rather than derived from the previous layer.

- **A1. Merge lane AG at its rung-5 head, re-run the floors.** AG
  built and measured the full-layer proof — attention, norms,
  residual, and the layer-to-layer seam — with the 12-layer 125M
  full-model pass accepting at 94.54 s and 10/10 tamper legs
  rejecting on a full Mistral layer. It is 8 commits behind the trunk
  and overlaps it in `PROGRESS_UPERF3.md`, `PROVING_CHANNEL_OPTIONS.md`
  and `layer.rs` (additive by design). Its byte gates were green on a
  pre-AH tree, so the floors must be re-run on the merged tree.
- **A2. Merge lane AI at rung 2 only** (`67519d3`), leaving the
  rung-3 crash-recovery commit on the branch: rungs 0-2 are measured
  and byte-identical, the rung-3 code compiles but was never
  measured, and unmeasured code does not belong on the trunk.
- **A3. The 32-layer 8B full-model pass**, on the Mac (256 GB): the
  FFN-only row alone peaks at 14.0 GB on the 15 GB WSL box. This
  produces the project's first honest end-to-end 8B number and
  replaces D1's [COUNTED] 2.87x with a measurement.
- **A4. Close the M3 gap: the X/W range facts.** The target contract
  says plainly that input-token and weight ranges are *declared* in
  the statement, not range-proven, and that "the contract's soundness
  story is complete only once those facts are added". +15-20%
  [MODEL] — that is D3, and it is not optional for a rigorous claim.
- **A5. Zero knowledge for the attention half.** Lane ZA's pads and
  mask rows apply plane for plane; the one new object is the fused
  (d, E) LogUp row, whose degree-2 l1 raises the CFS mask degree by
  one.
- **A6. The chained-transcript simulator argument.** Today's ZK
  guarantee is per-subprotocol; the contract flags that chain-wide
  composition carries its own analysis. A written simulator argument
  for the 12/32-layer chained transcript is owed before any ZK claim
  is published.

### Track B — everything device-resident (the measured 2.4-2.9x, L2)

The 8B GPU pass is 95.5 s, of which **56-63 s is host work that is
not a shape problem** — lane AH removed the shape problem entirely.
This is the highest-certainty lever in the plan because the share is
measured and each fix is byte-preserving.

- **B1. Plane -> Fp conversion and its pageable upload** (~13-20 s):
  convert on the device, pin the staging buffers, overlap with
  compute.
- **B2. The encode NTT on the device** (15.8 s).
- **B3. The opening's chunked re-encode** (14.3 s).
- **B4. Merkle levels and serialization of a 1.23 GB proof** (~13 s)
  — note this term largely *disappears* under Track C rather than
  being optimised.
- **B5. Lane AI rung 3: the 32-layer 8B ZK pass on the GPU** — the
  product number under the P1 ruling. Code written, compiles,
  unmeasured; also fixes `--wcache` being a silent no-op on the ZK
  path.
- **B6. Port the attention zero-checks to the GPU.** The attention
  half is CPU-only. Its zero-checks have the same shape as the v3
  ones, so AH's shape-general kernels should apply directly; the
  S-domain check (13 tables, degree 5, hp T^2 rows) is 40-50% of the
  attention wall at T = 512 and is the first kernel to port.
- **B7. Witness inference on the device**: 10-30 s on 8 CPU threads
  at 8B, milliseconds on tensor cores [MODEL].

### Track C — the bytes, which are also the time (L4, L5)

Proof size is not a cosmetic concern here: hashing the encoded
activations *is* the counted floor, and serializing 1.23 GB is
already ~13 s of the measured pass.

- **C1. Fold the claims** (AG's item 1): the attention half opens
  A/W/H at ~20 points where the v3 prover opens at two; folding
  removes ~8 MB of the 27.3 MB per 125M layer. No soundness change,
  no new machinery — the same nu-weighted eq terms the zero-checks
  already carry.
- **C2. The batched-evaluation reduction and one merged commitment**:
  every claim reduced to one point, W/A/H merged, n re-optimised.
  Bytes -50 to -56%, prover +5-15%, verifier -50% [COUNTED bytes].
- **C3. A device-resident, *hiding* WHIR/STIR-class PCS.** Lane AF
  proved the size lever is real — one Mistral layer 38.7 MB -> 1.94
  MB, 19.9x — but its compact form **is not device-resident** (34.96
  s on the GPU, slower than CPU) and **is not hiding** (`--pcs
  compact --zk` is refused). Under the P1 ruling the product needs
  ZK, so today's compact PCS cannot serve it. The PoC needs a PCS
  that is all three: small, device-resident, hiding.
- **C4. Rate 1/2 and/or a 31-32-bit field.** This is L4 and the one
  change that moves the 30B floor. It trades soundness bookkeeping
  and proof bytes for hash volume, and it is the design choice the
  competitor's Circle-STARK lineage already made. **It needs a
  ruling** — see §5.

### Track D — attention's quadratic planes (L6)

D1's 2.87x is the largest single divisor in the budget, and it is
quadratic in context: 1.17x at T = 16, 1.61x at T = 64, 2.87x at
T = 512 [MEASURED at 8B for the first two, COUNTED for the third].
The six committed H x T x T planes are the cause. Unexplored options:
head-restricted claims (already noted as cheap — ~hp claims in one
PCS group), windowed or block-sparse attention as a proven structure,
and committing the planes at a lower rate than the value tensors.
Opens after A3 gives the measured T = 512 number.

### Track E — hardware, measured early (L1)

Every device column in this plan divides a laptop row by a factor
nobody has run. **This should happen early, not last, because it
decides whether Track C's ruling is optional or mandatory.** A rented
H100 block for a day, running the existing 12x512 and 8B statements
with 20 warm runs, converts L1 from [MODEL] to [MEASURED] and tells
us which of L3/L4/L6 we actually need. A purchased 4090/5090-class
board additionally lifts the 15 GB ceiling that currently forces A3
onto the Mac.

---

## 4. Order of work

**Now, in parallel (they touch disjoint files):**

1. A1 + A2 — merge and consolidate, floors re-run. Days.
2. B5 — the 8B GPU ZK pass. The code exists; this is a measurement.
3. B1-B4 — the host wall. One lane, the biggest certain lever.
4. B6 — attention on the GPU. One lane, unblocks Track D's numbers.
5. C1 — fold the claims. One lane, additive.
6. E — book the H100 time. A decision, then a day of work.

**Next, once A1-A2 and E have landed:**

7. A3 — the 32-layer 8B full-model pass on the Mac. Replaces the
   plan's largest [COUNTED] divisor with a measurement.
8. A4 — the range facts. Rigor, and D3's real cost.
9. C2 — the batched-evaluation reduction.
10. Track D opens on A3's numbers.

**Gated on the §5 ruling:**

11. C3 + C4 — the PCS and the field/rate. Two lane-months of the
    hardest work in the plan, and the only route to 30B.

**Before any published claim:**

12. A5 + A6 — ZK for attention, and the chained simulator argument.
13. The adversarial-testing phase already scoped in
    `ADVERSARIAL_TESTING_PLAN.md`.

---

## 5. What genuinely needs a ruling

These are not a menu to choose one from; they are the three places
where the plan cannot pick for you.

1. **The PoC's target shape.** This plan recommends *60 tok/s, 8B,
   full statement, ZK P1, 512-token prefill, one H100* because it is
   inside the counted floor and honest. Targeting 30B instead means
   committing to C4 (the field/rate change) up front, with its
   soundness bookkeeping, as a precondition rather than a follow-on.
2. **Hashed bytes: rate 1/2 and/or a 31-32-bit field (C4).** The only
   lever that moves the 30B floor. It changes the soundness
   accounting and every frozen digest in the repository. Worth
   opening a costed design memo before anyone writes code.
3. **Hardware (E).** Rent an H100 block for the measurement pass, buy
   a 4090/5090-class board for capacity, or neither. Every [MODEL]
   column in §2 and every cell in §0 waits on this. Cheapest
   information in the plan.

A fourth, already answered and recorded here so it is not reopened:
**the privacy mode is P1** (private inputs, public weights), ruled
2026-09-03. Private weights (T18) remain a ~2 lane-week build whose
only counted design that preserves throughput is "never send the
sampled weight columns"; under P2/P3 no counted cell reaches even 50
tok/s, so the plan assumes P1 throughout.

---

## 6. What this plan does not claim

- No number here is measured on any board other than the WSL laptop.
  L1 is the plan's largest single factor and its least known.
- D1's 2.87x is counted, not measured, at T = 512; A3 fixes that.
- The 30B architecture is a stand-in shape, not a chosen model.
- L3's "kernel quality" factor is the distance between scaled
  constants and a spec-sheet floor. Closing it is ordinary
  engineering, but nobody has done it on this codebase for a device.
- The composed 65.5 tok/s at 30B in §2 is [MODEL on MODEL] and every
  factor in it sits at or above its midpoint. It is a demonstration
  that the goal is not arithmetically impossible, not a forecast.
