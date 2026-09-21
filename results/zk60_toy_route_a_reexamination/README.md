# Evidence for `docs/zkmatrix-poc/ZK60_TOY_ROUTE_A_REEXAMINATION.md`

Two exact-arithmetic Python scripts, written and run on 2026-09-21 by an
independent adversarial checker re-examining Route A for the toy private-block
profile `hashline-zk-mr1/private-block-t32-poc/1` (register entry **D22**)
under the complete query table (gap **GAP-QC-5**).

Both read **nothing**: no capture, no receipt, no witness, no salt. Every
input is a constant re-read from the MAIN tree's source at commit `4751b93`,
with the `file:line` written beside it in the script. Nothing was built,
proved, verified or benchmarked. Each runs in well under a second with no
dependencies beyond the standard library.

| file | what it does |
|---|---|
| `toy_query_table.py` | enumerates **every BLAKE3 query kind on the toy's path** — transcript constructor, every absorb label with its exact byte length, the live squeeze and the refusal replay, the four column-digest lengths, salted leaves, Merkle nodes, the generator's seed derivation and refill, and the four public digests — then finds every length coincidence inside the one unkeyed function, every one-byte margin, and counts the absorbs and squeezes per proof |
| `toy_query_table.txt` / `.json` | its output |
| `toy_residuals.py` | recomputes **every number in §4 of the accepted statement** in exact integers / `Fraction`: the sampler's per-draw distance and rejection region, the 327,052 `fp()` draws call site by call site, the LogUp-refusal counts in three forms (one-world all / one-world distinct / two-world union), the five hash-layer terms, the liveness figure, and the total `ε(q)` at `q = 2^12, 2^50, 2^80, 2^128` under each refusal form |
| `toy_residuals.txt` / `.json` | its output |

## The headline numbers, all reproduced

| | |
|---|---|
| `fp()` draws per toy proof | **327,052** [COUNTED] — agrees with the memo's table site by site |
| per-draw sampler **distance** | exactly **2^-96.000000**; the rejection region is **2^-64**, 32 bits larger, and is never used |
| sampler residual | **2^-77.6808** (written 2^-77.7); at 10^6 proofs **2^-57.7493** |
| LogUp denominators inverted per proof | **64,768** = 61,440 + 2,048 + 512 + 768 [COUNTED] |
| the refusal term, three forms | one-world all **2^-112.017**; one-world distinct **2^-118.415**; two-world union **2^-111.017** / **2^-117.415** |
| encoded columns / salts drawn | **12,288**; internal nodes **12,283**; `N_overlap` **24,571** |
| hash-layer terms | `q·2^-242.415`, **2^-229.830**, **2^-241.415**, **2^-484.831**, `q·2^-244.034`, **2^-233.069**, `q·2^-253.415` |
| liveness | four base-field proximity determinants, **2^-62.000** |
| total `ε(2^128)` | **2^-77.6808…**, identical to ten decimals under all three refusal forms |
| absorbs / distinct squeeze points / replayed points per proof | **317 / 1,863 / 1,027** [COUNTED] — so `A = 2,180` distinct points, 3,207 calls; the memo's bound `A ≤ 4,000` holds |
| distinct unkeyed input lengths at the toy | **37**, with **three** genuine clashes: 64, 81, 171 |

## Reproduce

```
python3 results/zk60_toy_route_a_reexamination/toy_query_table.py
python3 results/zk60_toy_route_a_reexamination/toy_residuals.py
```
