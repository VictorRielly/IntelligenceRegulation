# The quantization measurement campaign — consolidated report

Orchestrator, 2026-08-26. This report consolidates every measurement
of the 7B+ quantization question (2026-08-24 .. 08-26) and carries
the outstanding report deliverables of agents V and Z. Companion
docs: QUANTIZATION_CONTRACT_DESIGN.md (the contract + §8 amendment),
PROGRESS_UPERF3.md (the day-by-day record), U_PERF3_M8B_SMOOTH_
REPORT.md (agent U's fold experiment in full). Every number
[MEASURED WSL-BOX NT] at seed 1337, 8 cal + 8 val windows x 512
tokens of the same FineWeb-Edu text, unless labeled otherwise.

## 0. The answer

Modern pretrained 7B+ transformers cannot be represented faithfully
by the frozen TARGET_CONTRACT §2 chain (static per-tensor
power-of-two int8 everywhere): Mistral-7B fails at +8.18 nats /
14,531 held-out range violations, Gemma-4-12B-QAT at +17.60 /
116,852. The cause is NOT range coverage but RESOLUTION: a few
outlier channels stretch the per-tensor ranges 40-6000x, collapsing
the bulk signal into a handful of int8 levels at two-to-four
specific chain sites, compounding across layers. Every
range-covering mechanism (exact per-channel folds, margins,
per-column requant scales at every site family, int16-range-only
widenings at hot layers) reduces violations to O(10-100) and moves
quality by nearly nothing — three independent mechanism families
measured on Mistral, three variants on Gemma.

**The fix — measured, cheap, model-agnostic ("the widened stack"):**
1. the activation-table OUTPUT at int16 resolution (exponent
   e_A - 8; the table keeps its 256-row int8 domain);
2. int16 classes at the u (up-output), h (Hadamard), z (down-output)
   sites — all elementwise or post-accumulator;
3. round-to-nearest requant (the m125-documented mode: the SAME
   proven floor relation applied to a publicly pre-shifted value);
4. X and the gate/up matmul inputs STAY int8.

| checkpoint | frozen spec | best prior static | widened stack |
|---|---|---|---|
| Mistral-7B-v0.1 (SwiGLU) | +8.1773 / 14,531 | +7.32 | **+0.2157 / 32** |
| Gemma-4-12B-QAT (GeGLU) | +17.6029 / 116,852 | +17.57 | **+0.0353 / 14** |

Gemma's +0.035 sits BELOW its weights-only floor (+0.136);
Mistral's +0.216 is a 38x recovery. Residual violations are one
margin-bit-class fix from zero (§4). Weights stay int8 everywhere —
"no more than 8-bit models" holds for the model-size story; the
proof carries 16-bit resolution only at four named ACTIVATION sites.

## 1. How the answer was found (the method, for the record)

1. Qualification gates (the C4 mechanism) on both checkpoints ->
   both FAIL with structurally different profiles.
2. Range-mechanism sweeps: agent U's exact per-channel folds
   (violations 14,531 -> 3, quality unmoved); agent V's per-column
   requant scales + 16-bit gate domain (1,106-1,789 viols, +7.3-7.6);
   per-column and int16-range z on Gemma (87-116 viols, +17.6-18.1).
   CONCLUSION: range was never the disease.
3. Per-site noise ATTRIBUTION (quantize exactly one site of the fp
   chain): Gemma first-order deltas W +0.07, X +0.27, gate +0.38,
   u +0.12, **h +2.77, z +3.64** — the killers named, at ALL layers.
4. Exact-chain class-widening curve (the sanity leg reproduced the
   baseline BIT-EXACTLY: 24.8396 / 116,852): h16+z16 floor +1.37 /
   round +0.79; +u16 +0.71; gate-DOMAIN16 neutral; X16 +0.60;
   **+a16-OUT +0.0353**; X16 on top unnecessary (+0.0518).
5. Mistral cross-check of the winning stack: +0.2157. Two
   architectures, one amendment.

## 2. Engine and statement bill (what the amendment costs)

E1 Witness width: the a/u/h/z activation tensors carry int16-class
   digit witnesses (one extra base-2^e digit level per value) —
   activation-side only; weights (the dominant 8B witness mass)
   untouched.
E2 ONE limb-split matmul input: h16 into the down matmul (two int8
   limbs, shift-recombine — the A1LimbCommitKernel/
   ring_mul_q_limbsplit pattern already in the engine). The gate/up
   matmuls (the two big ones) are UNTOUCHED (X stays int8).
E3 Table registry (C5): int16-out members — 256-row tables, one per
   (function, e_gate, e_A-8): Mistral's silu set and Gemma's 6 gelu
   members regenerate at the finer output exponent; manifest.rs
   freeze = Victor's ruling.
E4 Round-mode requant: a statement-semantics selector (the relation
   is the proven floor form on acc + 2^(shift-1); m125 line 139-151
   documents it); no new soundness obligation, one freeze-row note.
E5 Range-fact classes: u/z at 2^15, h at 2^30 (= 32767 x 32767; the
   v4 CLS_ACC <= 31 cap covers it), requant remainders unchanged
   (max shifts measured 9 — inside CLS_REM 16).
Statement data: the per-site width flags + exponents (bytes-level).
Rough build size [ASSUMED]: E1 export/loader/digit plumbing 2-3 d,
E2 2-3 d, E3 0.5 d + ruling, E4 0.5 d, E5 0.5 d, statement v3
selector + migration battery 2-3 d -> ~1.5-2 lane-weeks to a
qualifying witness proof at the 32x16 rung.

## 3. Design choices (the discipline Victor asked for)

D1 Widen RESOLUTION, not range (exponent e-8 at the same absmax
   coverage): the attribution showed range was covered; the
   information deficit was step size.
D2 Widen the FEWEST sites that measure faithful: the curve was
   walked site-by-site; X16 measured unnecessary — so the two big
   matmuls stay int8 and there is exactly ONE limb-split.
D3 Round-nearest as the default requant profile: floor costs
   +0.5-4.9 nats of pure bias across the curve; round is the same
   proven relation on shifted operands.
D4 Per-channel machinery (C2 vectors) REMAINS in the contract as an
   optional site mechanism but is NOT REQUIRED by either measured
   checkpoint under the widened stack — measured guidance, not a
   removal.
D5 The qualification gate (C4) stays the arbiter: the widened stack
   is the default QUALIFICATION PROFILE, not a per-model tweak —
   any checkpoint runs the same gate under the same profile.

## 4. Limitations and open items

L1 Residual violations are not zero yet: Mistral 32 (X_clip 8,
   gate 7, u 1, h 16, z 2 -> 0 across variants), Gemma 14. These
   are margin-bit items (+1 bit on the affected per-tensor
   exponents) — mechanical, measured next round; a nonzero count
   still FAILS C4(i) as written.
L2 One data distribution: the gate ran on FineWeb-Edu val windows;
   C4 does not certify fidelity elsewhere (standard calibration
   caveat, recorded on the statement).
L3 The Gemma loss numbers use plain text through an -it- model
   (absolute losses read high; deltas are the meaningful figure —
   lane Y's template finding stands for decode-class evals).
L4 Chain semantics measured in the exact-integer float64 simulator
   (proven bit-exact against the baseline chain at the sanity leg);
   the Rust engine build (E1-E5) must reproduce it under the same
   differential discipline as every prior change.
L5 Costs above are semantics/witness accounting; measured prove/
   verify walls come from the engine round on the rungs.
L6 The attention statement (MVP-2) inherits the same site logic;
   its own hot sites get the same attribution treatment when built
   (U_PERF3_ATTENTION_STATEMENT_DESIGN.md §6 already anticipates
   the softmax/norm classes).

## 5. Artifacts

results/m8b_int8_calibration_wsl.json (Mistral baseline),
results/m8b_gemma4_calibration.json (Gemma baseline),
results/m8b_smooth_experiment_wsl*.json (folds, r1-r4),
results/m8b_blite_experiment_wsl.json (per-column round 1),
results/m8b_gemma4_zfix_wsl*.json (z-site rounds),
results/m8b_gemma4_attrib_wsl.json (attribution + the widening
curve), results/m8b_widen_attrib_wsl.json (the Mistral
confirmation). Scripts: m8b_smooth_experiment.py (U/V),
m8b_gemma4_zfix.py (Z), m8b_gemma4_attrib.py, m8b_widen_attrib.py
(orchestrator).
