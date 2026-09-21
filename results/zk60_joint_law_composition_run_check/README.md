# Evidence for `docs/zkmatrix-poc/ZK60_JOINT_LAW_COMPOSITION_RUN_CHECK.md`

Written 2026-09-20, 17:47 PDT by the independent adversarial checker of the
run joint-law memo. Nothing was built, no cargo ran, no git write was made,
no existing file was edited. Two Python files, exact integer arithmetic.

## `recount.py` / `recount.txt`

An independent recount of **every** `[COUNTED]` figure in the memo, written
from the LANE SOURCE (`/home/victor/wt-zk60-block125m`, tip `caa9b9a`) and
**not** from the memo's own script in
`results/zk60_joint_law_composition_run/`. The two scripts share no code.

Sources of each constant, one line each:

| constant | source line |
|---|---|
| `p = 2^64 - 2^32 + 1` | `zkp-core/src/field.rs:10` |
| `MASK_Q = 256`, `MASK_LOG_MSG = 9`, `MASK_LOG_DOM = 12` | `hashline/src/zk.rs:373-375` |
| per-shape rows, data rows, sites, groups, round counts, `largest_slot_length`, `u8_lookups`, `exp_pairs`, `act_pairs` | `hashline/src/private_block/grow_tests.rs`, `MODEL_TOY` / `MODEL_RUNG` / `MODEL_M125` |
| pad draws `rows * q` | `hashline/src/pcs.rs:90` (tagged), `zkp-core/src/pcs.rs:725` |
| salts `nn` × `bytes32` (raw bytes, excluded from D9) | `hashline/src/pcs.rs:91` |
| mask-row fill `(rows - data) * n` | `protocol.rs:655`, `:757`, `boundary.rs:324-326` |
| H zero-sum extra `2(n-1)` | `protocol.rs:760-768` |
| `M` draws `2·ΣL_s + 46·256 + 4·1024` | `zk.rs:485-508` |
| `L_s = (main+ext)·deg + 2` | `shape.rs:662-669` |
| boundary rows `data + 2·sites + 2` | `boundary.rs:180-182` |
| endpoint rows `data + 5` | `endpoint_g.rs:52`, `:143-149` |
| inverted LogUp denominators | `protocol.rs:691`, `:702`, `:704`, `:734` |
| proximity-determinant refusal, one per PCS opening | `protocol.rs:289-290` |

Result: **every** figure the memo labels `[COUNTED]` reproduces exactly —
the draw counts (686,990 / 9,029,742 per block; 8,704 / 108,032 per
boundary; 7,424 / 91,392 per endpoint; 2,093,226 / 8,354,472 /
27,488,074 / 109,728,040 per run), the residuals (2^-75.0, 2^-73.0,
2^-71.3, 2^-69.3), the salt count 2,473,984, the published field-word
totals (1,375,206 and 59,695,840), the round-message word counts
(1,034 and 1,519), the terminal counts (176 and 174), the LogUp
denominator counts (64,768 / 439,296 / 103,890,944) and their refusal
probabilities (2^-112.02 / 2^-109.26 / 2^-101.37 per block; 2^-97.78 at
`L = 12` at 125M), the liveness figures (2^-62.00 / 2^-60.68 / 2^-58.79)
and the per-commitment slack table (A 172, H 82/86, endpoint 1,
boundary **0**).

Two further results the memo does not have:

* **§4b, the toy control.** The same formula gives the toy's
  `A` 178,432 + `H` 124,928 + `M` 17,038 + H's zero-sum re-draw 510 +
  two endpoints 6,144 = **327,052**, which is D9's own accepted figure to
  the draw. Without the zero-sum term it is 326,542 and the control fails,
  so the term is required.
* **§4c, the 29,800.** The delta between this recount (and the memo's
  9,029,742 per block) and the design memo's 8,999,942 is exactly two
  things: the design omits H's zero-sum re-draw `2(n−1) = 32,766`
  (`protocol.rs:760-768`) and over-counts `M` by bounding `ΣL_s` at
  `23 × largest_slot_length = 2,691` instead of the true 1,208
  (`+2,966`, which `ZK60_PRIVATE_RUN_MULTI_BLOCK.md:1376-1378` states in as
  many words). `9,029,742 − 32,766 + 2,966 = 8,999,942`, exact.

## `rank_probe.py` / `rank_probe.txt`

A miniature of the run gate's own linear model over one message position of
one interior boundary plane held by three roles (`A_k`, `B_k`, `A_{k+1}`),
computing the gate's own criterion
`disclosed = rank([G_b | G_d]) - rank(G_b)`.

It reproduces two of the project's own controls at the right magnitude —
a shared blinding row gives marginals 0 and joint 1 per message position
(= 1,024 at the rung-G row width, which is exactly the gate's control C3
figure), and the 37-row boundary geometry discloses 1 (ruling M-1,
control C2) — and then exhibits the case the gate cannot see: two
**distinct** rows whose **values** the generator makes equal. The gate
scores that identical to the honest case, because its model assigns
distinct rows distinct free symbols and never looks at a value. The real
disclosed dimension is the shared-row one.
