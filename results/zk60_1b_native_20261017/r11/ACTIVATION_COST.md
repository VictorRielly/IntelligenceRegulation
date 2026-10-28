# Activation-side levers: what they cost the proof (native R11)

Native lane, round 11, 2026-10-20. **Paper and counting only.** No prover
code was written and nothing was built or proved. This is **not a soundness or
privacy acceptance**: every option here is a new profile, owing the re-reads
listed in §7.

Labels:
- **[COUNTED]**: exact, on the R9 replica of round 10.
- **[MODEL]**: an estimate. Prove time scales each measured R9 phase by its
  own counted size; the measurements behind it come from a shared box, n=1.

Files, all in this directory:
- `r11_activation_cost.py`, the counting script. It imports
  `../r10/r10_weight_range_cost.py` and re-runs its anchor, which asserts that
  the replica reproduces every size the R9 prover printed in HL_PB_TIMING.
- `r11_activation_cost.json` and `r11_activation_cost.out`, its outputs. The
  `.out` also shows every window the calculator chose.

## 1. The answer: the full-parity range

Rows are cumulative over R9 without DD, per block. Each cell gives
**committed elements / byte lookups / zero-check element-terms** in %, then
the [MODEL] prove time. At T512 only the argument-phase time is given, since
there is no T512 run to measure.

| stack | TinyLlama T128 | Llama-3-8B T128 | Llama-3-8B T512 |
|---|---|---|---|
| (c2) alone (R10) | +8.72 / +13.79 / +6.98; time +7.4% | +10.06 / +15.65 / +8.08; time +6.4% (argument +8.8%) | +7.05 / +10.61 / +5.48; argument +6.3% |
| **LOW**: (c2) + smallest plausible activation widths | **+20.98** / +21.92 / +19.26; time +18.7% | **+22.35** / +22.71 / +20.88; time **+15.1%** (argument +20.6%) | **+17.88** / +21.06 / +15.86; argument **+17.4%** |
| **MID**: LOW + SiLU output 4 bits finer (product remainder three bytes) | +25.68 / +25.54 / +22.68; time +21.6% | **+27.74** / +26.75 / +24.74; time +17.8% (argument +24.4%) | **+21.70** / +23.80 / +18.48; argument +20.0% |
| **HIGH**: MID + attention words int16, product output h int24, score word int12 | +27.74 / +28.25 / +24.81; time +23.6% | **+29.16** / +28.77 / +26.19; time +18.9% (argument +25.9%) | **+26.10** / +25.68 / +22.65; argument +23.8% |
| HIGH + residual int24 (no measured gain) | +32.67 / +32.77 / +27.79; time +28.3% | +35.36 / +34.83 / +30.53; time +23.1% | +28.46 / +27.73 / +23.63; argument +25.8% |

What each stack contains:
- **LOW** is (c2) plus:
  - norm outputs int16 (tn route);
  - F_P 12;
  - attention words at int12 or int16, whichever is cheaper at that shape and
    base. That is int16 everywhere except 8B T512 without DD, where it is
    int12. MID makes the same choice.
  - per-channel-group SiLU;
  - SiLU input int12.
- **HIGH**: the score word int12 makes DD infeasible (§3.2), so its DD form
  leaves that step out.
- **HIGH + residual**: the fidelity lane measured no gain from a wider
  residual.

**One line to quote** [COUNTED for elements, MODEL for time]. Full parity
means the weight lever plus every activation lever at the smallest plausible
width. Against R9 that is:
- **Llama-3-8B T128:** committed **+22% to +29%**; prove time about
  **+15% to +19%**, or +21% to +26% for the argument phases alone.
- **Llama-3-8B T512:** committed **+18% to +26%**; argument time about
  **+17% to +24%**.
- For comparison, the weight lever alone is +10% / +7%.

Which widths are actually needed is for the fidelity lane to measure. The
range runs from LOW to HIGH.

**Against R9 with DD** (same cell format):

| stack | TinyLlama T128 | Llama-3-8B T128 | Llama-3-8B T512 |
|---|---|---|---|
| (c2) | +9.34 / +15.70 / +7.34; time +7.7% | +10.47 / +16.79 / +8.31; time +6.5% | +8.91 / +14.79 / +6.47; argument +7.6% |
| LOW | +22.48 / +24.97 / +20.26; time +19.4% | +23.25 / +24.37 / +21.48; time +15.3% | +24.51 / +27.20 / +20.19; argument +21.7% |
| MID | +27.51 / +29.09 / +23.84; time +22.4% | +28.86 / +28.71 / +25.45; time +18.1% | +29.33 / +31.02 / +23.28; argument +24.9% |
| HIGH, DD form | +27.97 / +30.12 / +24.29; time +23.0% | +29.35 / +29.79 / +25.95; time +18.5% | +29.74 / +31.97 / +23.67; argument +25.4% |

How DD changes the picture:
- The percentages are higher on DD's smaller base, but DD stays cheaper in
  absolute terms. For example, 8B T512 LOW comes to 653.9 M committed
  elements per block with DD against 781.8 M without.
- At 8B T512 with DD, the wider score window (from the wider attention words)
  opens a third LogUp helper on the large score domain. DD's S block has only
  four lookups per position. The non-DD S block (15 lookups) fills a half-used
  helper instead.

## 2. Lever (1): norm outputs from int8 to int12 or int16

Today the outputs y (norm_a) and nm (norm_m) are `sym` int8 words: one plane
and two byte lookups each, with no limbs. The relation is
`y = floor((2 cn γ x + D 2^tn) / (2^(tn+1) D))`. Its remainder ρ is held in
four limbs below `den = 2^(tn+1) D`, so the window is
`tn + 1 + bits(D_max) = 32`. There are two ways to give y and nm 4 or 8 more
bits:

- **Multiply cn by 16 or 256 (the "cn route").** The window does not move,
  because ρ < den does not depend on cn.
  - For int12, each word becomes two limb planes plus `byte, byte,
    scaled(l1, 16)`: +4 planes and +2 lookups for the two norms (N12).
  - The largest cn in the exports, 3,583 (TinyLlama), times 256 is 917,248.
    That is still below `TRAINED_CN_MAX = 2^20`, but narrowly.
- **Lower tn by 8 for int16 (N16, the "tn route").** On 8B, tn goes from 9
  to 1; on TinyLlama, from 10 to 2.
  - y and nm become int16 with two offset limbs each, like x, ao and z16
    today: +4 planes, +0 lookups.
  - The **norm window shrinks 32 → 24**, so ρ and σ drop to **three limbs per
    norm**: −4 planes and −4 lookups.
  - **The norms themselves therefore cost nothing net (0 planes, −4
    lookups).** int16 is cheaper than int12.
- In both routes there is **no new slot**. Each limb decomposition is one new
  clause in `SC_DZC`, under its own challenge; c0 and c6 change only their
  constants.

What does cost is downstream. y feeds the Q, K and V matmuls and nm feeds the
gate and up matmuls, so their shifts grow by the same 4 or 8 bits.

| | N12 (cn route) | N16 (tn route) | N16 (cn route) |
|---|---|---|---|
| forced windows on R9 alone | q, k, v, g two bytes (shift 12); up new one byte | q, k, v, g two bytes (16); up one byte (8) | same as N16 |
| forced windows on (c2), keeping its multiplier bits | q, k, v, g **three bytes** (18–20); up **two bytes** | q, k, v, g three bytes (22–24); up two bytes | same |
| alone, vs R9 non-DD [COUNTED] | +9.58/+13.79/+7.83 · +11.01/+15.65/+9.05 · +7.71/+10.61/+6.13 | **+5.41/+8.36/+4.85 · +6.37/+9.59/+5.67 · +4.48/+6.51/+3.84** | +8.77/… · +10.09/… · +7.06/… |
| added on top of (c2) | +9.56 · +10.83 · +7.80 committed | **+5.73 · +6.62 · +4.78** | +8.81 · +10.00 · +7.20 |

Within each cell the three entries are TinyLlama T128 · 8B T128 · 8B T512.
The DD columns are in the JSON.

## 3. Lever (2): the attention core

### 3.1 Softmax precision F_P from 9 to 10, 11 or 12: zero cost [COUNTED]

- **The quotient keeps two limbs.** p ∈ [0, 2^F_P] needs `lp = ⌈(F_P+1)/8⌉`
  byte limbs, which stays **2 up to F_P = 15**. Only the top pin's
  coefficient changes: `2^(15 − F_P)` is 64 at 9 and 8 at 12.
- **The softmax remainders do not move.** ρ_s and σ_s are below Sum ≤ T·2^f_e,
  and their window `clog2(T) + f_e` does not depend on F_P.
- **The PV shift moves inside its window.** sh_o equals F_P today (9, the
  bottom of the two-limb class 9..=16). At F_P 12 it is 12, still in the
  class, so RO keeps two limbs.
- No plane, lookup, table or slot changes; only constants do.
- F_P is fixed at 9 in `shape.rs`, "coupled to the p limbs". Making it a
  per-profile constant is a D24 item (§7).

**How F_P meets DD.**
- The dictionary's quotient `P_dict = floor(e·2^F_P/Sum)` uses the same `lp`
  limbs and pin, so the Dd plane count is unchanged up to F_P = 15. At
  F_P ≥ 16 a third P limb would be needed: +1 plane and +1 lookup at every
  dictionary slot with DD, or at every score entry without it.
- **The cap does not depend on F_P.** n_col = |{0} ∪ exp outputs| depends only
  on the exp table (f_e and e_s).
- What would break DD is a finer **exp table** (§3.2), not F_P.

### 3.2 The score window, the PV remainder, and wider attention words [COUNTED]

The shifts involved:
- the score shift: `sh_s` (5–8 in the exports) + Δq + Δk − Δs;
- the PV shift: `sh_o = F_P + Δv − Δo`;
- RoPE is unchanged, because its output keeps its input's scale (SH_ROPE 7).

The options:

- **A12: q, qr, o (Dom Q) and k, kr, v (Dom Kv) at int12.**
  - The words themselves: +12 limb planes, +6 lookups.
  - Score window: 13–16 → **two bytes** (RSL +1 S plane, +1 lookup).
  - PV: v and o widen together, so it is unchanged.
  - ao: its input o is 4 bits wider. On R9 alone ao needs 7–12 (two bytes,
    union pin); on (c2) it needs 15–20 (three bytes, union pin).
  - The q, k and v production shifts fall by 4 and keep their windows.
- **A16: the same words at int16.**
  - The words: +12 planes, +0 lookups.
  - Score window: 21–24 → **three bytes** (S +2 planes, +2 lookups).
  - ao: two bytes on R9, three on (c2).
  - **The q, k and v remainders shrink.** On (c2) they need 6–8 → one byte,
    where (c2) had two.
  - At T128 A16 is cheaper than A12. At T512 the score domain is 2^23 and
    A12 is cheaper.
- **PV alone:** v at int16 with o left at int8 needs 20 → three limbs (Q +1
  plane, +1 lookup). Otherwise RO stays as it is.
- **S12: the score word at int12 with a 4096-row exp table.**
  - Score: +2 S planes, +1 lookup; its shift falls by 4.
  - The exp table fits inside Dom::Tab, which is already lifted to 2^14 or
    2^15, so it adds 0 rows.
  - **DD becomes infeasible**, so S12 has no DD figure. With 16× finer steps,
    n_col grows from 8–24 toward roughly 128–384 distinct outputs [MODEL]
    (the hard bound is 513). That is far above cap 32, and any cap of at
    least T makes the dictionary no smaller than the score domain.

Each cell is committed / U8 / element-terms in %; within it, TinyLlama T128 ·
8B T128 · 8B T512.

| lever | alone, vs R9 non-DD | added on top of (c2) |
|---|---|---|
| F_P 12 | 0 · 0 · 0 | 0 · 0 · 0 |
| A12 | +6.32/+6.67/+5.12 · +6.95/+6.81/+5.79 · +5.71/+6.68/+4.90 | +6.57 · +7.15 · +5.93 committed |
| A16 | +7.62/+4.52/+6.29 · +6.92/+3.03/+6.03 · +8.55/+6.16/+7.03 | +6.30 · +5.38 · +7.36 committed |
| S12 (non-DD only) | +1.63 · +0.95 · +2.55 committed | +1.50 · +0.86 · +2.38 committed |

## 4. Lever (3): gate, SiLU and the gate × up product

- **Per-channel-group SiLU with registry-only members (SG).** The fidelity
  lane's claim of **0 planes is correct** [COUNTED]: 0 committed planes and
  0 byte lookups. It is not free:
  - The activation lookup needs the group id as a third tuple component,
    which is **one public column**. In `SC_FZC` (the F cube) and in `SC_TAB`
    it is one more table, about **+1.7% to +2.0% element-terms**
    (+1.3% at T512).
  - That cost goes away if the group id, a function of the channel-index
    bits, is evaluated symbolically, as eq is.
  - The table holds groups × 256 rows, which must be at most 2^log_cols:
    64 groups at T128 and 128 at T512.
  - The per-group output scale folds into the down projection's public
    columns at no cost.
- **SiLU input int12 (SI12): 0 planes, 0 lookups, 0 element-terms.**
  - The 4096-row activation table fits inside Dom::Tab. g's range comes from
    the table itself, and the gate shift falls by 4.
  - With groups it needs groups × 4096 ≤ 2^log_cols, which allows at most 4
    groups at T128 and 8 at T512. Beyond that, Dom::Tab grows past the row
    width and every Tab plane grows with it.
- **A wider SiLU output class** is free in planes, since a16's range comes
  from the public table. A finer output still feeds the product
  `a16·u16 >> sh_h`, and **sh_h already reaches its window top of 16** in
  3 + 3 layers of the dg exports.
  - With output 4 bits finer the shift needs 17–20, so the product remainder
    rh goes to **three bytes** (+1 F plane, +1 lookup; RH3).
  - Because F is the largest domain, that is expensive: **+4.3% / +4.9% /
    +3.6% committed on top of (c2)**. It is the step from LOW to MID.
- **Product output h at int24 (H24)** adds a third limb on F (+1 plane,
  +1 lookup).
  - The product shift falls by 8, so rh shrinks: one byte alone, or two with
    RH3.
  - The down input grows by 8 bits, so z needs two bytes on R9 and three on
    (c2).
  - Cost on top of (c2): +1.15 · +1.26 · +0.90 committed.

| lever | alone, vs R9 non-DD | added on top of (c2) |
|---|---|---|
| SG | 0/0/+1.73 · 0/0/+1.95 · 0/0/+1.31 | 0/0/+1.62 · 0/0/+1.80 · 0/0/+1.24 |
| SI12 | 0 · 0 · 0 | 0 · 0 · 0 |
| RH3 | +1.58/+3.62/+1.71 · +1.81/+4.04/+1.93 · +1.27/+2.74/+1.31 | +4.32 · +4.90 · +3.56 committed |
| H24 | +1.25 · +1.39 · +0.97 committed | +1.15 · +1.26 · +0.90 committed |

## 5. Lever (4): residual from int16 to int24. Not cheap, not in LOW or MID

The pieces:
- x, x1 and x2 each gain a third limb: +3 D planes, +3 lookups. ao and z16
  can stay int16, added with a public 2^8.
- D_max grows by 8 bits, so the norm window becomes 40 bits, which is **five
  limbs** per remainder: +4 planes, +4 lookups.
- The isqrt witnesses go from three limbs to four: `SC_TZC` gains +6 sites
  and +6 tables.

Cost alone: **+6.56 / +7.14 / +4.91% committed**. Two further strikes against
it:
- The five-limb norm breaks D16's "at most four limbs each" and reopens the
  choice D24 made against a fifth remainder limb.
- The fidelity lane measured no gain.

Combined with the tn route of N16, the same tn − 8 serves both, and the norm
window returns to 32 bits (four limbs). That is the "HIGH + residual" row
(+6 to +7 points over HIGH).

## 6. The windows the stacks choose (8B T128) [COUNTED]

Each entry gives the shift interval it must admit, then byte limbs / top pins.

| | q, k | v | ao | g | up | z | score RSL | PV RO | product RH | norm window |
|---|---|---|---|---|---|---|---|---|---|---|
| R9 | 8 → 1/1 | 8 → 1/1 | 3–8 → 1/1 | 8 → 1/1 | none | 4–8 → 1/1 | 5–8 → 1/1 | 9 → 2/1 | 13–16 → 2/1 | 32 b, 4 limbs |
| (c2) | 14–16 → 2/1 | 15–16 → 2/1 | 11–16 → 2/1 | 14–16 → 2/1 | 4–8 → 1/1 | 10–16 → 2/1 | 1/1 | 2/1 | 2/1 | 32 b, 4 limbs |
| LOW (A16, the T128 form) | 14–16 → 2/1 | 15–16 → 2/1 | 19–24 → 3/1 | 18–20 → 3/1 | 12–16 → 2/1 | 2/1 | 21–24 → 3/1 | 12 → 2/1 | 2/1 | 24 b, 3 limbs |
| LOW (A12, the T512 form) | 18–20 → 3/1 | 19–20 → 3/1 | 15–20 → 3/2 | 18–20 → 3/1 | 12–16 → 2/1 | 2/1 | 13–16 → 2/1 | 12 → 2/1 | 2/1 | 24 b, 3 limbs |
| MID | as LOW | | | | | | | | 17–20 → 3/1 | |
| HIGH | 2/1 | 2/1 | 3/1 | 3/1 | 2/1 | 18–24 → 3/1 | 17–20 → 3/1 | 2/1 | 9–12 → 2/1 | 24 b, 3 limbs |

How the windows are chosen:
- An L-limb remainder with one top pin admits shifts [8(L−1), 8L]; one limb
  admits [0, 8]. A second pin (the union window) is needed when the interval
  starts lower.
- Every layer keeps the full (c2) multiplier width at its weight site.
- A site that has a remainder in R9 keeps at least one byte.

## 7. What must be re-read

None of this has been done.

- **D24 (per-profile constants and windows), for every lever.** The items:
  - every new window class: three bytes at q, k, v, g, ao, z, score and rh;
    two bytes at up and score;
  - the tn route of N16, which gives three norm limbs and a 24-bit window
    (the code today refuses any tn that changes the limb count);
  - the cn class margin of N16 by the cn route (917,248 against 2^20);
  - F_P as a per-profile constant;
  - the no-wrap bounds at the new classes. All are far below p ≈ 2^64 but
    must be re-derived:
    - y int16 into the Q/K/V accumulator, scaled: about 2^42;
    - the norm's c0 with y int16: about 2^39 by the tn route and 2^47 by
      the cn route;
    - scores with int16 q and k: about 2^37;
    - the product with a finer SiLU output: about 2^35;
  - D31's identical pairs at window tops.
- **D16 (norm range pins).**
  - N16 by the tn route keeps an exact 24-bit window in three limbs, which is
    within D16.
  - The residual alone needs a fifth norm limb, which D16 forbids. Only the
    form combined with the tn route fits.
- **D12 and D12a.** They state that the second norm's **int8** range proof is
  mandatory, at both ends of every boundary. N12 and N16 change nm's class to
  int12 or int16, still range-proved by limbs. The rule's wording and its
  reason (the FFN proves no input range of its own) must be restated for the
  wider class.
- **D30 (DD).**
  - F_P 10–12 changes only the division coefficient and P_dict's pin. The
    sentence in condition (5) that accepts P's range by membership must be
    re-read with P < 2^(F_P+1).
  - The cap is unaffected.
  - A12 and A16 add S planes (RSL limbs) under DD too. The tuple and the
    order (Dd below the histograms) are unchanged.
  - **S12 makes DD infeasible** because of the cap.
  - The lookup term that depends on N must be recounted.
- **The SiLU tuple (SG).** A three-component LogUp tuple with a public column
  needs the same tag and challenge-power discipline that D30 B-2 set for the
  dictionary tuple.
- **D27.** N grows by about 21–23% for LOW, so the derived whole-run lookup
  bound falls by at most about 0.3 bit [MODEL].
- **Privacy.** Every option is a new profile, so D33 does not cover it.

## 8. Method

- **The replica.** It is round 10's, with the anchor re-asserted. The empty
  configuration reproduces R9 exactly, and `c2=True` reproduces R10's `a3_1`
  exactly; both are checked in the script.
- **The window calculator.**
  - Weight-site shift intervals come from `r10/r10_word_use.json`: the union
    over the 8B dg, TinyLlama dg and 8B b7voc0 exports.
  - Non-weight intervals come from the export constants: sh_s 5–8, sh_o 9 and
    sh_h 13–16 in every export.
- **Word-class costs:**
  - int8 `sym`: 1 plane, 2 lookups;
  - int12: 2 more limb planes, byte, byte and a pin (+1 lookup);
  - int16: 2 more limb planes, 2 bytes (+0 lookups), the pattern x, ao, x1,
    x2, z16, u16 and h16 use today.
- **Prove time** is the round-10 model: each measured R9 phase scaled by its
  own counted size. At T512 only the argument phases are modelled, using the
  8B T128 cost per unit.
- **To reproduce:** `python3 r11_activation_cost.py` (pure Python, about a
  second).
