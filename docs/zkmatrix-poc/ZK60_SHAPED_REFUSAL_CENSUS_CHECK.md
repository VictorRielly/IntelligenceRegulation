# ZK60: adversarial check of the shaped refusal census (stages 38–39)

**Date:** 2026-09-22, opened 22:58 PDT. **Checker:** independent adversarial
agent (Claude Opus 5.5), review worktree `wt-zk60-block125m-review`, branch
`zk60-private-block-125m-review`, lane tip `27398d0` merged in (no conflict).
**Under attack:** `ZK60_SHAPED_REFUSAL_CENSUS.md`,
`hashline/src/private_block/census_shaped_tests.rs`, lane ledger stages 38–39,
fix `7472a3c` (ruling S38-F1(a)). **Context:** ruling NL-8 / gap GS-14 of
`ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md`.

**This is not a privacy result.** It checks completeness and statement
admissibility only. Nothing here claims or checks a privacy property.

## 0. Status

IN PROGRESS. The bounds (section 5) and the code enumeration (section 3) are
done; the test runs are pending (section 8).

## 1. Verdict per census claim

(pending the test runs, section 8)

## 2. Findings

(pending the test runs; sections 3–6 carry the analysis)

## 3. Independent site enumeration

(pending)

## 4. Public-statement admissibility (siblings of S38-F1)

(pending)

## 5. Bounds re-derived

`results/zk60_census_check/bounds.py` (output `bounds.log`) re-derives every
figure from the code: `witness.rs`, the shaped kernel, `layout::lookups_at`,
`Shape::new` and `domain_log_at`. It does not use the census test. It uses
exact integer arithmetic and asserts the memo's figures at all ten shapes.
Result: **every figure agrees.**

* **Norm output `y`.** The exact image over `|x| <= D` and `g in [-128, 127]`,
  enumerated, is **[-64, 64]**. Both ends are hit: `x = D, g = 127` gives 64,
  `x = -D, g = -128` gives 64, and `x = D, g = -128` gives -64. The census's
  `(128 + 1) / 2 = 64` is right.
* **Q/K/V image** `requant(width * 64 * 128, 7) = 64 width`: toy 1,024; rungs
  6,144; rung-K8 8,192; rung-C6 24,576; W14 / E32 / 125M 49,152. This agrees
  with the memo.
* **AO image.** The extreme products are `(-127)(-128) = +16,256` and
  `(127)(-128) = -16,256`, so the image is **exactly ±127 · width**: toy
  2,032; rungs 12,192; K8 16,256; C6 48,768; W14 / E32 / 125M 97,536. The
  largest width with `127 w <= 32767` is **258**, computed by scanning widths.
  So `AO` is reachable exactly at C6, W14, E32 and 125M, as the memo says.
* **FFN down** `requant(hidden * 32768 * 128, 6)`: 1,048,576 at the toy up to
  134,217,728 at 125M. The **product** image is [-65,534, 65,536]. The census
  states only `+65,536`, which is the side that matters.
* **Norm windows.** `D_max` over the int16 class (−32768 is legal) is 131,072 /
  321,059 / 370,727 / 642,119 / 908,093. That gives `den_max = D_max · 2^12
  <= 2^norm_wrho` at every shape. The toy sits exactly on its window (ratio
  1.0). The margin at 125M is **0.2075 bits**, matching layout's "0.21". The
  isqrt witness satisfies `2 D_max < 2^24` everywhere.
* **Softmax window.** `tokens · 2^f_e <= 2^wrho_s` holds at all ten shapes
  with the DERIVED `wrho_s`. This premise is the one finding C-2 attacks.
* **Largest LogUp multiplicity.** This is the U8 looked-word total over the
  lifted cubes: toy **61,440**, rung-G 419,840, K8 555,008, C6 1,214,464,
  W14 4,882,432, 125M **98,598,912**. All match the memo; see note C-6 for a
  stale comment elsewhere.
* **Largest kernel intermediate.** `1 + width · 2^30` wins at every shape:
  toy **1.72e10**, 125M **8.25e11**. Both are far below `2^63`. This matches
  the memo.
* **Padded `Dom::F` positions.** Rung, rung-G, K4 and K8 each have **3,584 of
  8,192**; the other six shapes have 0. This matches the memo.

**Do the census tests read these off the shape?** Yes for the rows that carry
a real bound. The norm, Q/K/V, QR/KR, score, O, AO, residual, FFN, multiplicity
and kernel rows each compute `reach` from the `Shape` and the calibration
constants. A changed width, for example, would move AO's class, and the test
asserts the class against a named shape list, so it would fail. **Seven rows
cannot fail, whatever the shape** (finding C-3).

## 6. The fix `7472a3c`

(pending)

## 7. What this check did NOT cover

(pending)

## 8. Evidence

| run | log | result |
|---|---|---|
| bounds, Python | `results/zk60_census_check/bounds.log` | exit 0, `ALL CENSUS FIGURES RE-DERIVED: OK` |
