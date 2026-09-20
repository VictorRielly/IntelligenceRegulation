# ZK60 — the P10 gate's open channels: inventory, the mask-commitment port, M's closure

Lane ledger. Worktree `/home/victor/wt-zk60-jointview`, branch
`zk60-native-jointview`, opened 2026-09-20 04:37 PDT off 1857c04.

**Nothing in this lane is a privacy acceptance and nothing here establishes a
privacy property.** The P10 gate is a consistency gate on four captured
receipts at two fixed toy layouts: it replays them with exact linear algebra
and reports, channel by channel, whether a preimage was exhibited. Every
statement below is scoped to those four captures.

## 0. Status

| step | what | state |
|---|---|---|
| S0 | ledger skeleton, lane opened | done |
| S1 | inventory the 10 OPEN channels from the gate's own `channels` array; classify (a)/(b)/(c) | done |
| S2 | port the mask-commitment layout (`hashline/src/zk.rs`) into `scripts/zk60_native_mask_commit.py` with source pins | done |
| S3 | close M's three channels in the gate: disclosed dimension, preimage, M in the joint stage | done |
| S4 | negative controls on M: a pad removed, the functional order permuted, a second functional leaked | done |
| S5 | the owed one-liner: the pad-budget guard into the base small-model class; regenerate the affected evidence | done |
| S6 | report section in `ZK60_NATIVE_JOINT_VIEW.md`; suite green; ledger final | done |

## 1. Commands and logs

**S1, the baseline** (2026-09-20 04:40 PDT, detached under `setsid nohup`):

```
python3 /home/victor/wt-zk60-jointview/scripts/zk60_native_privacy_gate.py \
  --captures /home/victor/wt-zk60-jointview/results/zk60_native_captures_20260919 \
  --evidence /home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate_channels \
  --columns full --controls-on all
```

- `results/zk60_native_privacy_gate_channels/gate_baseline.log`, `.done` = 0,
  192.7 s, four captures, all `ok`.
- `results/zk60_native_privacy_gate_channels/tests_baseline.log`, `.done` = 0:
  `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p
  'test_zk60_native*.py'` — **Ran 139 tests in 185.1 s, OK (skipped=1, expected
  failures=1)**.

## 2. Findings

### F1 — the inventory (S1)

28 channels, **8 CONSTRUCTED / 2 DERIVED / 8 ARGUED / 10 OPEN**, and the
`by_status` count is byte-identical on all four captures. The ten OPEN
channels, with the gate's own reason abbreviated, and this lane's
classification:

| # | channel | § | class | why |
|---|---|---|---|---|
| 1 | the M opening's `q` | 2.1 | **(a)** | the gate does not model M's row layout; "no capture field is missing" |
| 2 | the M proximity vector | 2.1 | **(a)** | same port: the `u` row is not modelled |
| 3 | opened column values (M's own 256 columns) | 2.1 | **(a)** | same port: the a-row pads are not modelled |
| 4 | whether a proof attempt produced a receipt | 2.2 | **(c)** | refusal event; a capture only exists when the proof was ACCEPTED, so no capture can ever show it (ruling C-2) |
| 5 | rejected-but-emitted receipts | 2.2 | **(c)** | procedural condition on the deployment (history item H8); not a linear channel |
| 6 | retained captures | 2.2 | **(c)** | procedural condition (H9); a retained capture IS a published opening |
| 7 | timing, memory, power | 2.2 | **(c)** | out of scope for the first MVP (M-5, C-2); no capture field bears on it |
| 8 | prior proofs by the same prover | 2.2 | **(c)** | multi-receipt composition, chain item 21 / open item U-3b |
| 9 | the integer-range facts the statement implies | 4.2 r16 | **(c)** | chain item 20: information no preimage argument removes |
| 10 | any nonlinear functional of the joint view | 4.2 r17 | **(c)** | the terminal identity is degree 4; this gate is linear |

**No channel is class (b).** Nothing in this inventory needs a capture field
that does not exist, so no field is requested from the integrator, and in
particular no field that is a function of hidden data (the security owner
already refused one such, a slot's unmasked honest rounds).

The (c) channels stay ARGUED-or-OPEN by design. The memos that carry them:
`ZK60_JOINT_LAW_COMPOSITION.md` (revised) for #8 and #10 (the composition of
the channels into one law, and the nonlinear link), and
`ZK60_HASH_LAYER_AND_FS_LIFT.md` (revised) for the refusal-rate counting that
#4 rests on. #5, #6, #7 and #9 are deployment or scope conditions, not
channels a linear model can close.

### F2 — the port (S2)

`scripts/zk60_native_mask_commit.py`, six source pins checked at every entry
point (sha256 and git blob): `hashline/src/zk.rs`,
`hashline/src/private_block/argument.rs`,
`hashline/src/private_attention/argument.rs`, `zkp-core/src/sumcheck.rs`,
`zkp-core/src/ntt.rs`, `zkp-core/src/pcs.rs`. Every ported function's
docstring quotes the Rust it transcribes.

**M's row layout** (`zk.rs::mask_commit`, 430-467), with S slots:

| rows | what | free values |
|---|---|---|
| `0 .. 2S-1` | the a-rows, two per slot (re, im): `[L_s coefficients \| 256 pads \| zeros]` in VALUE form over G_512 | the 256 pads |
| `2S, 2S+1` | `b_re`, `b_im`: 1,024 coefficients each with `b[512] = -b[0]` | 1,023 each |
| `2S+2, 2S+3` | `u_re`, `u_im`: 1,024 coefficients each, no constraint | 1,024 each |

**The declared functional order, taken from the code and pinned** (an earlier
memo had it wrong): for each slot `s` in slot order, a **Standalone** slot's
Gamma comes IMMEDIATELY BEFORE that slot's own evaluation functional, then
the evaluation; a **Host** slot contributes only its evaluation there, its
Gamma deferred; a **Private** slot only its evaluation; and **every Host
slot's Gamma comes LAST, in slot order** (`private_block/argument.rs:361-376`
for the per-slot push, `:924-925` for `acc.fs.extend(hosts)`).

On the block capture (23 slots: 12 Private, 6 Host, 5 Standalone; 34
functionals) the order is checked three ways and all three pass 34 of 34:
POSITION (each functional's term rows), VALUE (against the slot's own
captured `scalar` for a Gamma, `mask_eval` for an evaluation) and WEIGHTS
(recomputed here from `CfsMask::sum_weights * c` / `CfsMask::eval_weights` at
the replayed challenges). Order as the code has it, first six and last seven:
`eval_00 eval_01 eval_02 Gamma_03 eval_03 eval_04 ... eval_22 Gamma_02
Gamma_14 Gamma_15 Gamma_16 Gamma_17 Gamma_18`.

**The solver.** The a-row's value at a sampled node `y` is
`sum_t msg[t] L_t(y)` with `L_t(y) = ((y^512 - 1)/512) g^t / (y - g^t)`, so
over the pad positions the map is a **Cauchy matrix** in the distinct sampled
nodes and 256 consecutive powers of `g` — invertible for distinct nodes, and
solved here in closed form by a rational interpolation rather than a 256^3
elimination. Building a preimage takes 1.9 s per capture and verifying it
0.6 s.

### F3 — M's three channels, closed (S3)

| figure | block profile (23 slots) |
|---|---|
| coefficient unknowns | 1,166 Fp (583 Fp2) |
| blinding unknowns | 15,870 Fp (46x256 pads + 2x1,023 b + 2x1,024 u) |
| **disclosed dimension predicted** | **2 Fp (one Fp2: the theta-batched value V)** |
| **disclosed dimension computed** | **2 Fp** — the exact Fp rank of V over the coefficient unknowns |
| fibre dimension | 1,164 Fp |
| `q` entries recomputed / differing | 1,024 Fp2 / **0** |
| `prox` entries recomputed / differing | 1,024 Fp2 / **0** |
| opened column entries recomputed / differing | **12,800** / **0** |
| distinct opened columns / pads per a-row / margin | 246 / 256 / 10 |

**The preimage, exhibited twice.** Two public seeded coefficient vectors,
each corrected at one position onto the plane `V(a) = 512 (q[0] + q[512])`,
each with a full set of blinding values that reproduces the captured opening
entry by entry. **All 583 coefficient positions differ between the two**, the
two blinding digests differ, and both verify. Off that plane — `V(a)` one
away from the captured batch — **b is inadmissible and the fibre is EMPTY**,
while the 256 columns still match: the disclosure is exactly the one Fp2 and
nothing else.

Honest epistemics, recorded in the gate itself: `q` and `prox` are
reproduced BY CONSTRUCTION (b and u are defined as the residues), so their
zero mismatch counts record that the two arithmetic paths agree. What the `q`
channel actually pins is b's zero-sum admissibility; what the column channel
tests is genuinely independent data, since the pads were solved by rational
interpolation and re-encoded through the NTT path `mask_commit` itself uses.

**M in the joint stage.** M was already in the union of commitments as a
block (`zk60_native_jv_joint.mask_block`: `2S+4` rows, no data row, one
published row combination). Its two figures are now both computed:
`part_fp_over_the_commitment_coordinates = 0` (it commits no witness data)
and `own_disclosed_fp_over_the_coefficients = 2`, the latter cross-checked in
stage 3 against the ported layout's exact rank. Stage 4: **joint 4, sum of
parts 4, equal True** (2 from H's LogUp identity, 2 from M's q).

### F4 — the three controls (S4), each firing on all four captures

| control | honest | perturbed |
|---|---|---|
| **a pad removed from M** — every a-row modelled with 245 pads against 246 distinct opened columns (real budget 256, margin 10) | preimage exhibited | **50 of 12,800 column entries wrong**: exactly one unmet node, on all 50 rows (46 a-rows plus the b and u rows, which inherit it) |
| **the functional order permuted** — functionals 0 and 1 swapped, so each takes the other's power of theta | preimage exhibited | flavour 1 (same coefficients): **b inadmissible**. Flavour 2, which removes b's excuse by forcing the coefficients so the PERMUTED batch still hits the captured `512 (q[0]+q[512])`: **b admissible, and 1,024 of 12,800 column entries wrong** (the four b and u rows at all 256 columns, first at row 46). The order is pinned by the columns, not only by the scalar sum |
| **a second functional leaked** — functionals 0 and 1 published unbatched beside the theta batch | disclosed 2 Fp | **disclosed 6 Fp**, fibre 1,164 -> 1,160 |

### F5 — the base-class pad-budget guard (S5)

`PadBudgetRefusal` now lives in `zk60_native_jv_smallmodel` and
`ToyView.disclosed_reduction` raises it when the distinct opened positions
exceed the pad count; `disclosed_reduction_unguarded` is the way to see what
the reduction would have said. `zk60_native_jv_groups.PadBudgetRefusal` is an
ALIAS of the same class, so every existing `except`/`assertRaises` against
either name catches both paths. One internal caller moved to the unguarded
entry point on purpose and says why in place: `group_pad_freedom` reads only
`k0`, a rank of the row-space generators that has nothing to do with the pad
budget, and is called on the deliberately out-of-budget case (c) of
`pad_boundary`.

### F6 — the runs and the comparisons (S3, S5, S6)

| what | command / log | result |
|---|---|---|
| P10 with M | `zk60_native_privacy_gate.py --captures .../zk60_native_captures_20260919 --evidence .../zk60_native_privacy_gate_channels --columns full --controls-on all`; `gate_with_M.log`, `.done` = 0 | 221.8 s, four captures ok, **8/2/8/10 -> 11/2/8/7** on every capture |
| P10 before/after comparison | `scratchpad/diffgate.py` (key by key, ignoring `seconds`, `tool_sha256`, `version`, the new M keys) | **every one of the 200 differences is inside channels 13-15 or the two `by_status` counters**; nothing else moved |
| groups regenerated | `zk60_native_jv_groups.py --evidence .../zk60_native_small_model_groups`; `regen_groups.log`, `.done` = 0 | 0.6 s; diff vs the committed record ignoring `seconds` + `tool_sha256`: **0 differences** |
| joint view regenerated | `zk60_native_joint_view.py --captures ... --evidence .../zk60_native_joint_view`; `regen_jointview2.log`, `.done` = 0 | 23.5 s, every stage ok; diff: **28 ADDED keys, 0 changed values**. Stage 4 joint 4, sum 4, equal True on all four |
| new tests alone | `tests_mask_only.log`, `.done` = 0 | **21 tests in 40.5 s, OK** |
| full suite | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native*.py'`; `tests_after.log`, `.done` = 0 | **161 tests in 213.1 s, OK (skipped=1, expected failures=1)**; baseline was 139 |

One stumble worth recording: the first joint-view regeneration FAILED,
because `group_pad_freedom` calls the reduction on the deliberately
out-of-budget case (c) of `pad_boundary` and the new base-class guard
refused it. `group_pad_freedom` reads only `k0`, which is a rank of the
row-space generators and has nothing to do with the pad budget, so it now
calls the unguarded entry point and says why in place. The guard caught a
real caller on its first run, which is the right kind of noise.

## NEXT

Nothing owed in this lane. Handing back to the security owner: the port
equals the Rust by THIS LANE'S READING ONLY (six pins, docstring quotes, the
four captures) and has had no second reader; M's hash layer stays ARGUED
under M-2/M-3; the seven remaining OPEN channels of the report's section
14.1 are unchanged and four of them are deployment or scope conditions.
Nothing in this lane is a privacy acceptance.
