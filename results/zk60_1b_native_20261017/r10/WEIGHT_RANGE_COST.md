# Weight-range levers: what they cost the proof (native R10)

Native lane, round 10, 2026-10-20 ~05:20 UTC. **Paper and counting only.** No
prover code was written or changed, and nothing was built or proved. This is
**not a soundness or privacy acceptance**: every option below is a new profile
that would need the reviews named in §8.

Labels:
- **[COUNTED]**: exact, on a replica of the R9 layout. The replica reproduces
  every size the R9 prover printed (§9).
- **[MODEL]**: an estimate. The prove-time column scales each measured R9
  phase by its own counted size. The measurements behind it come from a
  shared box, n=1.

Files, all in this directory:
- `r10_weight_range_cost.py` (the counting script) and its outputs
  `r10_weight_range_cost.json` and `r10_weight_range_cost.out`;
- `r10_word_use.py` and its output `r10_word_use.json`: the bits each site
  needs, read from the three current exports (a 29 s light guarded job).

## 1. The answer: X for each option

X is the growth of each count over R9 without DD, per block. Each cell gives
**committed elements / byte lookups / zero-check element-terms**, all
[COUNTED]. Element-terms use the runtime's convention (sumcheck cube × tables,
as HL_PB_TIMING prints them).

| option | TinyLlama T128 | Llama-3-8B T128 | Llama-3-8B T512 |
|---|---|---|---|
| **(a) exact need** (`a_need`) | +8.29 / +13.79 / +6.55 | **+9.59** / +15.65 / +7.60 | **+6.73** / +10.61 / +5.15 |
| (a) without the up site (`a1z`) | +3.59 / +6.55 / +3.14 | +4.20 / +7.57 / +3.74 | +2.91 / +5.14 / +2.53 |
| (a) the earlier count's set (`a1`) | +3.59 / +5.65 / +3.14 | +4.20 / +6.56 / +3.74 | +2.91 / +4.45 / +2.53 |
| **(c2) narrow per-channel multipliers** (`a3_1`) | +8.72 / +13.79 / +6.98 | **+10.06** / +15.65 / +8.08 | **+7.05** / +10.61 / +5.48 |
| (c3) int12 words, two-byte windows | +9.53 / +14.69 / +7.41 | +10.98 / +16.66 / +8.56 | +7.70 / +11.30 / +5.80 |
| **(b) 12-bit multipliers, exact need** (`b_need`) | +19.07 / +24.86 / +14.81 | **+21.96** / +28.26 / +17.13 | **+15.39** / +19.17 / +11.61 |
| (b) conservative: three bytes everywhere (`b3`) | +22.95 / +27.57 / +17.80 | +26.44 / +31.29 / +20.51 | +18.57 / +21.23 / +13.90 |
| (b) four-byte sensitivity (`b4`) | +31.66 / +37.74 / +24.78 | +36.50 / +42.90 / +28.59 | +25.62 / +29.10 / +19.37 |

What each option is:
- **(a) exact need**: every weight matmul uses the full per-tensor int8 range
  in all three current exports.
- **(a) without the up site**: q, k, v, g and z only.
- **(a) the earlier count's set**: q, k, v, g and z with one pin. It refuses
  the layers where sh_z is below 8.
- **(c2)**: the same windows as (a), plus ao at two bytes, with narrow
  per-channel multipliers riding in those windows.
- **(b) 12-bit multipliers, exact need**: what the current exports require.
- **(b) four-byte sensitivity**: every site at four bytes, as an upper bound.

**Against R9 with DD.** The changes in absolute terms are identical, because
none of these options touches the S or Dd planes. The percentages are a little
larger because the base is smaller.

| option | TinyLlama T128 | Llama-3-8B T128 | Llama-3-8B T512 |
|---|---|---|---|
| (a) exact need | +8.88 / +15.70 / +6.89 | +9.98 / +16.79 / +7.82 | +8.50 / +14.79 / +6.08 |
| (a) without up | +3.85 / +7.46 / +3.31 | +4.37 / +8.12 / +3.85 | +3.68 / +7.16 / +2.99 |
| (c2) narrow multipliers | +9.34 / +15.70 / +7.34 | +10.47 / +16.79 / +8.31 | +8.91 / +14.79 / +6.47 |
| (c3) int12 words | +10.21 / +16.73 / +7.79 | +11.42 / +17.87 / +8.81 | +9.72 / +15.75 / +6.86 |
| (b) exact need | +20.43 / +28.31 / +15.58 | +22.84 / +30.33 / +17.62 | +19.44 / +26.72 / +13.71 |
| (b) three bytes everywhere | +24.58 / +31.40 / +18.72 | +27.50 / +33.58 / +21.09 | +23.45 / +29.59 / +16.42 |

**Prove time and receipt, against R9 without DD.** Prove time is [MODEL]; the
receipt change per block is [COUNTED].

| option | time, TL T128 | time, 8B T128 | time, 8B T512 | receipt, TL T128 | receipt, 8B T128 | receipt, 8B T512 |
|---|---|---|---|---|---|---|
| (a) exact need | +6.9% (+7.2%) | +6.0% (+8.3%) | (+5.9%) | +708,752 B (+3.13%) | +1,413,264 B (+4.90%) | +2,789,520 B |
| (a) without up | +3.7% (+3.9%) | +3.1% (+4.3%) | (+3.1%) | +307,312 B (+1.36%) | +618,608 B (+2.15%) | +1,208,432 B |
| (c2) narrow multipliers | +7.4% (+7.7%) | +6.4% (+8.8%) | (+6.3%) | +745,632 B (+3.30%) | +1,482,912 B (+5.14%) | +2,924,704 B |
| (c3) int12 words | +8.0% (+8.3%) | +6.9% (+9.5%) | (+6.8%) | +815,280 B (+3.60%) | +1,618,096 B (+5.61%) | +3,190,960 B |
| (b) exact need | +15.7% (+16.3%) | +13.6% (+18.6%) | (+13.3%) | +1,630,560 B (+7.21%) | +3,236,192 B (+11.22%) | +6,381,920 B |
| (b) three bytes everywhere | +18.0% (+18.8%) | +15.8% (+21.7%) | (+15.5%) | +1,962,352 B (+8.67%) | +3,895,664 B (+13.51%) | +7,696,752 B |

How to read the time columns:
- The first figure is the whole prove run.
- The figure in brackets counts only the argument phases, the ones whose size
  the layout sets. It excludes the phases with no layout term, which together
  are 27% of the 8B T128 prove and 4% of the TinyLlama prove:
  - block load and witness;
  - the exp/act histograms;
  - the mask commit.
- At T512 only the argument figure is given. It applies the 8B T128 cost per
  unit to the T512 sizes, because there is no T512 run to measure.

The receipt percentage is relative to the measured R8 run receipt. The counted
change per block carries over to the run receipt exactly: DD's +235,008 B per
block moved both measured runs by exactly blocks × 235,008.

**One line for Victor** [COUNTED for elements, MODEL for time]: letting every
weight matmul use the full int8 range grows the proof by about **10%** at 8B
T128: committed elements +9.6%, prove time about +6% overall and +8% in the
argument. At T512 the growth is about **7%**. The pieces:
- Leaving the up projection out halves the cost (+4.2% / +2.9%) and leaves its
  1–4 unused bits in place.
- Adding narrow per-channel multipliers on top (c2) costs only 0.3–0.5 points
  more, at +10.1% / +7.1%.
- Full 12-bit multipliers (b) cost about **22%** at T128 and **15%** at T512.

## 2. How the weights enter the proof, and why only remainders grow

In P1 the weights are public, so no plane of the layout holds a weight word.
Each of the seven block matmuls works in the same three steps. The matmuls
are Q, K, V, the output projection (`WO`), gate, up and down.

1. **The matmul slot** (`argument.rs` `SC_QMM .. SC_DMM`) proves
   `claim = Σ_i x̃(r, i) · W̃(r_j, i)`.
   - `x` is a committed activation plane (`A_Y`, `A_O8`, `A_YM` or `A_H16`).
   - `W̃(r_j, ·)` is the verifier's own fold of the public int8 matrix
     (`fold_rows_i8` / `fold_cols_i8`).
   - The accumulator itself is never committed.
2. **A domain zero-check hosts the claim** (`SC_QZC`, `SC_KVZC`, `SC_DZC`,
   `SC_FZC`). It proves the requantisation
   `2^sh · y + r − 2^(sh−1) = acc` at the matmul's point.
   - `y` is the output plane, range-checked by its own limbs.
   - `r` is the biased remainder, held in **byte limbs plus one top pin**
     (`layout.rs` `lookups_at`: `byte(l_i)` for each limb and
     `scaled(top, 2^(8L − sh))`).
3. **The up projection is the exception.** It has `sh_u = 0` and no remainder
   at all (`host_u = u16`), so its output is the exact accumulator,
   range-checked as int16.

How many bits the weight words use appears nowhere in the relation:
- The worst-case accumulator class already assumes |w| ≤ 128
  (`nowrap_check.py`).
- Fuller words make the honest accumulator larger, so the calibration must use
  a larger `sh`. A larger `sh` needs **more remainder limbs**.

Every lever below therefore changes only:
- the remainder planes of the weight-matmul sites (`A_RQL` Q, `A_RKL` and
  `A_RVL` KV, `A_RAL` D, `A_RGL` F, `A_RDL` D, and a new up remainder on F);
- their byte lookups and LogUp helpers;
- the claim sites and zero-check tables that follow from those.

No slot is added and no degree changes. The number of mask rows,
functionals and opening groups stays the same.

The rule for windows: an L-limb remainder with **one** top pin admits shifts
in `[8(L−1), 8L]`, and one limb admits `[0, 8]`.
- At the lower end the pin coefficient is 2^8, which forces the top limb to 0.
  The O and product sites use `9..=16` today. Extending a window down to its
  lower end must be confirmed in the D24 re-read (§8).
- A **union window** `[1, 8L]` needs a second pin, `scaled(l0, 2^(8 − sh))`.
  That is one more byte lookup per position at that site.

## 3. Which windows the current exports need [COUNTED from the arrays]

`r10_word_use.py` reads every weight array of three exports:
`llama3_8b_dg_rot1_voc0_T128`, `tinyllama_dg_rot1_T128` and
`llama3_8b_pg_rot1_b7voc0_T128`. For each layer and site it computes:
- `tmax`, the tensor's largest |W8|;
- `k_t = floor(log2(127/tmax))`, the whole bits a per-tensor power-of-two
  rescale could add while every word stays in int8;
- the shift that option (a) needs, `sh_a = sh_R9 + k_t`;
- the shift that option (b) needs, `s_b = sh_a + 12`. This assumes 12-bit
  multipliers normalised to the largest channel.

The table gives ranges over layers, with the union over the three exports
in the last two columns.

| site | tmax | unused bits k_t | sh in R9 | (a) needs sh_a | (b) needs s_b | window (a) | window (b) |
|---|---|---|---|---|---|---|---|
| q | 9–40 | 1–3 | 8 | 9–11 | 21–23 | 2 bytes | 3 bytes |
| k | 10–49 | 1–3 | 8 | 9–11 | 21–23 | 2 bytes | 3 bytes |
| v | 37–76 | 0–1 | 8 | 8–9 | 20–21 | 2 bytes | 3 bytes |
| ao (wo) | 8–125 | 0 (dg), 0–3 (b7voc0) | 3–8 | 3–8 | 15–20 | **1 byte, unchanged** | 3 bytes, union (s = 15) |
| g | 18–122 | 0–2 | 8 | 8–10 | 20–22 | 2 bytes | 3 bytes |
| **u** | 4–127 | 0–4 | **0** | 0–4 | 12–16 | **new, 1 byte** | **2 bytes** |
| z (wd) | 10–127 | 0–3 | 4–8 | 4–10 | 16–22 | 2 bytes, union (sh = 4–7) | 3 bytes |

Detail by export, in `r10_word_use.json`:
- **8B dg**: q and k need sh_a 10–11 everywhere, v 9, g 9–10, up 1–3, and z
  5–10. The ao tensor max is already 67–122, so ao has nothing to gain.
- **b7voc0**: z needs only 4–7, so it fits one byte.

The per-channel medians of the largest |W8| show why per-channel scaling (b)
is worth more than a per-tensor window (a):
- 8B dg: q 6, k 7, v 25, o 48, g 12, u 16, d 20.
- TinyLlama: q 6, k 8, v 28, o 50, g 16, u 21.5, d 25.

So `a_need` comes from the data, as the union over the three exports:
- q, k, v and g at two bytes;
- z at two bytes with the union pin;
- a new one-byte remainder at up, window 0..=8;
- ao unchanged.

`b_need` likewise:
- q, k, v, g and z at three bytes, window 16..=24;
- ao at three bytes with the union pin, because TinyLlama and b7voc0 reach
  s = 15;
- up at two bytes.

## 4. Option (a): two-byte remainders. The planes that grow, exactly

`a_need`, plane by plane. Each widened site goes from one limb and one pin to
two limbs and one pin. "Lookups" means byte lookups per position.

| site | plane(s) | domain | A planes | lookups | notes |
|---|---|---|---|---|---|
| Q | `A_RQL` → `RQL0, RQL1` | Q | +1 | +1 | 13 → 14 lookups, helpers 7 → 7 |
| K | `A_RKL` → 2 limbs | Kv | +1 | +1 | |
| V | `A_RVL` → 2 limbs | Kv | +1 | +1 | Kv: 12 → 14 lookups, helpers 6 → 7 |
| gate | `A_RGL` → 2 limbs | F | +1 | +1 | |
| down | `A_RDL` → 2 limbs | D | +1 | +2 | 2 pins (union); D: 34 → 36, helpers 17 → 18 |
| **up** | **new `A_RU`** (1 limb), window 0..=8 | F | +1 | +2 | F: 9 → 12 lookups, helpers 5 → 6. The host `u16 = acc` becomes `2^sh_u · u16 + r_u − 2^(sh_u−1) = acc`: a new clause in `SC_FZC` |

Totals:
- A planes +6, with Dom D +1, Q +1, Kv +2 and F +2.
- H planes +3, with D +1, Kv +1 and F +1.
- Claim sites move with them: each plane or helper adds one site to its
  domain's zero-check and one table to its sumcheck.

The up site costs more than the other six combined. Its remainder sits on the
F domain, which is the largest (T·f_pad, four times D). Per site, at 8B T128,
see §7:
- up, one byte: committed +5.39%;
- gate, two bytes: +1.81%;
- q, k and v together: +1.00% (less than the sum of the three single-site
  rows, because the K and V lookups share one new helper).

**The earlier count is reproduced exactly.** The earlier count's set (`a1`)
gives:
- TinyLlama T128: 70,860,800 committed, 30,638,080 byte lookups, receipt
  +307,312 B per block;
- 8B T128: 122,830,848 committed.

These are the fidelity lane's `fp_cost_weight_options.json` figures to the
element. Its "+3.8 / +4.4 / +3.4% proof" is that lane's speed-law time.
Counted, the set is committed +3.59 / +4.20 / +2.91%. That set does not let
the up words use their range: sh_u stays 0, and wu keeps its 1–4 unused bits.
With one pin it also refuses every layer with sh_z < 8: four TinyLlama dg
layers, two 8B dg layers and every b7voc0 layer.

## 5. Option (b): per-output-channel public 12-bit multipliers

The output becomes `y_j = floor((m_j · acc_j + 2^(s−1)) / 2^s)`, with `m_j`
public and up to 12 bits per output row, as D25 T4's head does.

- **The relation does not change form; it fits the existing requant.**
  - Because `m_j` is public and indexed by the matmul's output row, the
    verifier folds it into the public weights:
    `W̃'(r_j, i) = Σ_j eq(r_j, j) · m_j · w[j, i]`. This multiplies the eq
    table by `m` (O(rows)) before the same O(weights) fold.
  - The matmul slot then proves the MLE of the **scaled accumulator** `m⊙acc`.
  - The hosting zero-check keeps `2^s · y + r − 2^(s−1) = claim`, with `s` in
    place of today's shift.
  - No new slot, no committed multiplier plane, no new table.
  - The matmul slot's tables (two) and degree are unchanged.
- **Ranges.**
  - The scaled accumulator grows by the multiplier's 12 bits.
  - The shift grows to `s = sh_R9 + k_t + 12`, which is 12–23 in the current
    exports (§3).
  - The remainder grows to s bits: **three byte limbs** at q, k, v, ao, g and
    z, and **two** at up.
  - The largest host term grows from 2^36.0 (down, R9) to **2^48.0** (down,
    s ≤ 24). It is 2^48.6 if a four-byte window were used. p is about 2^64,
    so the margin is at least 15 bits, but the bound must be re-derived (§8).
- **The planes that grow** (`b_need`):
  - Q `A_RQL`: 1 → 3 limbs, +2 planes, +2 lookups.
  - Kv `A_RKL` and `A_RVL`: +2 each.
  - D `A_RAL`: 1 → 3 limbs with the union pin, +2 planes, +3 lookups.
  - D `A_RDL`: +2 planes, +2 lookups.
  - F `A_RGL`: +2 planes, +2 lookups.
  - F new up remainder: two limbs, +2 planes, +3 lookups.
  - Totals: A +14 planes and H +8 helpers.
- **The statement gains** the multiplier vectors: 43,008 values per layer at
  8B and 17,920 at TinyLlama. They must be bound wherever the weights are
  bound, in the per-layer manifest hashes behind the trained statement
  identity. A multiplier the prover could choose freely would make the
  relation meaningless. This is a review item (§8).
- **The fidelity lane counted (b) lower** than this count: committed +19.83%
  (TinyLlama) and +22.85% (8B T128). This count's like-for-like row (`b3`,
  three bytes everywhere) gives +22.95% and +26.44%.
  - The gap is exactly one F helper: 130 rows at TinyLlama and 258 at 8B
    T128 (2·rows_of(F) + 2 sites). This count carries 6 new F lookups (gate
    +2, up 3 limbs + pin); a count with 5 has one fewer helper.
  - The exact need (`b_need`) gives +19.07% and +21.96%.
  - I did not re-derive the fidelity lane's script, so this is for the
    reconciliation.

## 6. Option (c): cheaper variants

- **(c1) Per-channel-group multipliers cost exactly what per-channel
  multipliers cost at the same width.** The multiplier is public, so the
  group size changes only the statement's length and the fidelity. The cost
  lever is the multiplier **width**, which sets s and so the remainder limbs.
  Grouping saves no proof work.
- **(c2) Narrow per-channel multipliers inside (a)'s windows**
  (`a3_1`: two bytes at q, k, v, ao, g, z and one byte at up):
  - Cost: +8.72 / +10.06 / +7.05% committed. That is 0.3–0.5 points over
    `a_need`. The extra is ao at two bytes. z needs no union pin, because
    the multiplier bits can lift every z shift to 8 or more.
  - The multiplier width each site can hold in every layer is 16 − max sh_a:
    q and k 5 bits, v 7, g 6, z 6, ao 8, up 4 (8 − 4).
  - Arithmetic [MODEL, for the fidelity lane to measure]: the multiplier's
    width barely limits the **word range**. The words absorb the fine scale,
    and with a b-bit multiplier `m_j ≈ 2^b · max_j / tmax` every channel's
    largest word is at least about `127·(1 − 1/m_j)`. With 5 bits, a channel
    at a tenth of the tensor max still reaches about 85 of 127; today the
    median channel reaches 6–8 at q and k. If that holds in perplexity, (c2)
    buys most of (b)'s range at about half of (b)'s cost.
- **(c3) int12 words with the two-byte class:**
  - Cost: +9.53 / +10.98 / +7.70%. The windows are q, k, v, g, z at two bytes
    (sh_a + 4 = 8–15), ao at two bytes with the union pin (TinyLlama and
    b7voc0 reach 7), and up at one byte (4–8).
  - The matmul relation does not see the weight width. The verifier's fold
    reads i16 instead of i8, and the work per weight is the same.
  - Outside the proof: the public weight bytes double (export, load, digest),
    and the largest host term grows to 2^40 (down).
  - Under P3, where weights are hidden, a wider word would cost committed
    range limbs. That is not a P1 cost.
- **The fused up** (`c_fused`) does not pay off. It widens u to int24 and lets
  the product shift sh_h absorb the extra bits (rh at three limbs) instead of
  adding an up requant. Its counts are the same as or above `a3_1` at every
  shape (+10.30 / +11.87 / +8.33%), and it may need a union pin at sh_h. The
  one-byte up requant is the cheaper way to give wu its range.
- **Zero-cost levers.** Weights are public and fixed, so per D32 calibration
  on the weight side changes no plane. Two examples:
  - GPTQ word rounding, which the fidelity lane has already measured;
  - equalising channel scales across consecutive matmuls: V rows against WO
    columns, up rows against down columns, and q/k pair balancing.

  Both move word range between tensors without any layout change. The
  equalisation is untested here; it is listed for the fidelity lane.

## 7. Cost per site, to sum any subset [COUNTED, against R9 without DD]

Each cell is committed / byte lookups / element-terms, in %. `site:L` means
that site's remainder at L byte limbs with one pin. Every other site stays as
in R9.

| site:L | TinyLlama T128 | 8B T128 | 8B T512 |
|---|---|---|---|
| q:2 | +0.43 / +0.90 / +0.43 | +0.47 / +1.01 / +0.48 | +0.33 / +0.68 / +0.33 |
| q:3 | +1.68 / +1.81 / +1.28 | +1.86 / +2.02 / +1.45 | +1.29 / +1.37 / +0.98 |
| k:2 (= v:2) | +0.24 / +0.11 / +0.11 | +0.39 / +0.25 / +0.24 | +0.26 / +0.17 / +0.16 |
| k:3 (= v:3) | +0.34 / +0.23 / +0.16 | +0.53 / +0.50 / +0.36 | +0.35 / +0.34 / +0.25 |
| ao:2 (= z:2) | +1.25 / +0.90 / +0.85 | +1.39 / +1.01 / +0.97 | +0.97 / +0.68 / +0.65 |
| ao:3 (= z:3) | +1.68 / +1.81 / +1.28 | +1.86 / +2.02 / +1.45 | +1.29 / +1.37 / +0.98 |
| g:2 | +1.58 / +3.62 / +1.71 | +1.81 / +4.04 / +1.93 | +1.27 / +2.74 / +1.31 |
| g:3 | +6.28 / +7.23 / +5.12 | +7.20 / +8.08 / +5.79 | +5.09 / +5.48 / +3.92 |
| u:1 (new) | +4.69 / +7.23 / +3.41 | +5.39 / +8.08 / +3.86 | +3.81 / +5.48 / +2.62 |
| u:2 (new) | +6.28 / +10.85 / +5.12 | +7.20 / +12.11 / +5.79 | +5.09 / +8.22 / +3.92 |
| u:3 (new) | +10.97 / +14.46 / +8.53 | +12.59 / +16.15 / +9.65 | +8.90 / +10.96 / +6.54 |

The four-limb rows are in the JSON. The cells do not add up exactly.
- **Helper pairing:** a helper covers two lookups, so adding lookups on the
  same domain can fill a half-used helper (q:2 is cheap because Q goes from 13
  to 14 lookups) or open a new one (g:3).
- **The union pin:** add one lookup per position at that site.

The bundle rows in §1 are exact.

## 8. Soundness arguments to re-read

None of the following has been done.

- **D24 must be re-read for every option.** D24 accepted the per-profile
  shifts together with the "structure-preserving windows" (`ONE_LIMB_SHIFT`
  1..=8, `TWO_LIMB_SHIFT` 9..=16 at the O and product sites). Each option is a
  new profile with a new plane list and new windows. To re-read:
  1. The top-pin argument at each new window, including its lower end
     8(L−1) and any union pin. The two-limb argument is the O/product one;
     the three-limb argument is the softmax `sigma_s` one, `wrho_s ≤ 24`.
  2. `nowrap_check.py` `shift_bounds` at the new windows (§9 numbers), and its
     exhaustive check that the quotient is unique, extended past sh = 16 for
     (b).
  3. The **new up host clause** in `SC_FZC`, for (a), (b) and (c2).
  4. For (b) and (c2), the public multiplier fold in the matmul slots, and the
     binding of the multipliers into the statement.
  5. D31's reading of identical lookup pairs. At the top of every window the
     pin coefficient is 1, so it pairs with `byte(top)` as at sh = 8 today.
- **D30 (DD) needs no re-reading of its construction.** No relation on S or
  Dd changes, and the Dd block stays below the histograms (E-1): new planes
  land in the D, Q, Kv and F blocks. Its condition (5) lookup term
  `(N + 2303 + 4·rows·cap)/|F|` grows with N, the byte lookups per block, and
  should be recounted. The change is small: N grows by +10.6% at 8B T512 for
  `a_need`.
- **D27's whole-run derived lookup bound** (about 95 bits) falls by at most
  log2(1 + ΔN) if the lookup term is linear in N [MODEL]. That is about 0.15
  bit for `a_need`, 0.25 bit for `b_need` and 0.06 bit for `a1` at 8B T512.
  The bound should be recounted at the chosen profile.
- **Privacy.** Every option is a new profile, so D33 does not cover it. The
  gate (rank lemma, NL-1, joint view) would have to run on captures of that
  profile.

## 9. Method, anchors and how to reproduce

`r10_weight_range_cost.py` restates the counting of the frozen R9 tree
(`r9/frozen-tree/hashline/src/private_block/`), function by function:
- from `shape.rs`: `a_plane_doms`, `lookups_per_position`, `helpers`,
  `h_plane_doms`, `claim_sites`, `slots`, `totals` and the row and term parts
  of `receipt_bytes`;
- from `layout.rs`: `lookups_at` and `domain_log_at`;
- from `argument.rs` `define`: the tables of each slot.

The one generalisation: the remainder of each weight-matmul site is a
parameter (byte limbs, pins).

**Anchor (asserted; the script stops on any difference).** For the four
R9-tree runs at T128, the replica equals every size the prover printed in
HL_PB_TIMING. The four runs are R8 TinyLlama dg and R8 8B b7voc0 (= R9
without DD, byte-identical) and the R9 `--dd` runs on the same exports. The
sizes are A words, H words, byte lookups, both mask-row sizes and the
element-terms of all 23 or 24 slots.
- At 8B T512 the replica gives 663,257,088 committed without DD and
  525,172,736 with DD: the review's D30 anchor.
- The earlier fidelity-lane count of `a1` is reproduced to the element (§4).

No-wrap, as log2 of the largest host term [COUNTED, `nowrap_check.py`
formula, class maxima width 4096 and f_pad 16384]:

| | q/k/v | ao | gate | up | down |
|---|---|---|---|---|---|
| R9 | 25.99 | 26.16 | 25.99 | none (`u16 = acc`) | 36.00 |
| (a) | 26.16 | 31.04 | 26.16 | 26.16 | 36.04 |
| (b), s ≤ 24 | 38.00 | 39.58 | 38.00 | 39.58 | 48.00 |
| (c3) | 30.00 | 31.58 | 30.00 | 30.00 | 40.00 |

To reproduce: `python3 r10_weight_range_cost.py` (pure Python, under a second)
and `python3 r10_word_use.py <export dirs>` (reads about 8 GB of int8
weights, peak RSS 0.44 GiB).
