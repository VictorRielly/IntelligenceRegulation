# slot expression IR inventory
# source (read-only): /home/victor/wt-zk60-block125m/hashline/src/private_block/argument.rs [extracted]
# arms of `define` extracted: 16; slots named by them: 23 of 23

## toy — toy block (T32 / d16 / f16, 2 heads of 8 over 1 KV head)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 9 | 1 | 3 | 3 | 2 | 1/1 | 1 | 0 | 0 | 1 | 3 | 1,024 | 43,450 | 23,763 | 45.3% |
| 01 | SC_SSM | priv | 9 | 1 | 3 | 3 | 2 | 1/1 | 1 | 0 | 0 | 1 | 3 | 1,024 | 43,450 | 23,763 | 45.3% |
| 02 | SC_TZC | host | 5 | 1 | 3 | 3 | 25 | 22/3 | 3 | 3 | 6 | 36 | 28 | 800 | 21,235 | 8,741 | 58.8% |
| 03 | SC_LZC | stan | 9 | 1 | 4 | 4 | 4 | 2/2 | 1 | 2 | 2 | 8 | 5 | 2,048 | 84,315 | 49,039 | 41.8% |
| 04 | SC_RS | priv | 11 | 1 | 3 | 3 | 4 | 3/1 | 1 | 1 | 0 | 2 | 4 | 8,192 | 245,660 | 153,530 | 37.5% |
| 05 | SC_QMM | priv | 4 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32 | 455 | 359 | 21.1% |
| 06 | SC_KMM | priv | 4 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32 | 455 | 359 | 21.1% |
| 07 | SC_VMM | priv | 4 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32 | 455 | 359 | 21.1% |
| 08 | SC_SCORE | priv | 3 | 2 | 2 | 2 | 2 | 2/0 | 1 | 0 | 0 | 1 | 2 | 16 | 360 | 183 | 49.2% |
| 09 | SC_PV | priv | 5 | 2 | 2 | 2 | 2 | 2/0 | 1 | 0 | 0 | 1 | 2 | 64 | 1,560 | 807 | 48.3% |
| 10 | SC_WO | priv | 4 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32 | 455 | 359 | 21.1% |
| 11 | SC_GMM | priv | 4 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32 | 455 | 359 | 21.1% |
| 12 | SC_UMM | priv | 4 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32 | 455 | 359 | 21.1% |
| 13 | SC_DMM | priv | 4 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32 | 455 | 359 | 21.1% |
| 14 | SC_DZC | host | 9 | 1 | 4 | 4 | 61 | 39/22 | 3 | 23 | 51 | 218 | 122 | 31,232 | 1,908,585 | 825,331 | 56.8% |
| 15 | SC_QZC | host | 9 | 1 | 4 | 4 | 20 | 10/10 | 3 | 9 | 16 | 63 | 36 | 10,240 | 577,430 | 283,728 | 50.9% |
| 16 | SC_KVZC | host | 8 | 1 | 4 | 4 | 18 | 9/9 | 3 | 8 | 15 | 59 | 33 | 4,608 | 263,925 | 130,053 | 50.7% |
| 17 | SC_SZC | host | 11 | 1 | 4 | 4 | 25 | 14/11 | 3 | 15 | 20 | 82 | 54 | 51,200 | 3,285,435 | 1,495,140 | 54.5% |
| 18 | SC_FZC | host | 9 | 1 | 4 | 4 | 20 | 11/9 | 3 | 9 | 14 | 56 | 37 | 10,240 | 569,765 | 255,133 | 55.2% |
| 19 | SC_TAB | stan | 8 | 1 | 3 | 3 | 10 | 4/6 | 1 | 4 | 3 | 9 | 8 | 2,560 | 53,550 | 38,112 | 28.8% |
| 20 | SC_ZS | stan | 8 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 512 | 6,375 | 4,839 | 24.1% |
| 21 | SC_IO_IN | stan | 9 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 1,536 | 15,330 | 11,490 | 25.0% |
| 22 | SC_IO_OUT | stan | 9 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 1,536 | 15,330 | 11,490 | 25.0% |
| — | **all 23** | | | | | | **217** | | **35** | | | **549** | | **127,056** | **7,138,940** | **3,317,655** | **53.5%** |

peak single-slot table set: 0.8 MiB (slot 17 SC_SZC, 25 tables of 2^11 `Fp2` words), or 0.6 MiB with its 14 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.00 GiB (0.00 GiB mixed) [COUNTED]

launch / hand-back counts: 159 main rounds over the 23 slots plus 25 extension rounds — one round message (86 `Fp2` values in total over the main rounds of one round index each, 721 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 6,447,465 | 634,195 | 57,280 | 7,138,940 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 5,138,913 | 634,195 | 57,280 | 5,830,388 | 18.3% |
| + (a) base-field operands in round 1 | 3,999,353 | 523,027 | 57,280 | 4,579,660 | 21.5% |
| + (c) finite differences per sub-expression | 2,737,348 | 523,027 | 57,280 | 3,317,655 | 27.6% |
| **all three together** | | | | **3,317,655** | **53.5% of the baseline** |

table traffic of the round loop: 253,678 `Fp2` words read, 126,839 written — 0.00 GiB read at 16 B a word. 132 of the 217 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +1 | 28 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +1 | 5 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +57; `PadTerm::eval` +1 | 122 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +1 | 36 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +1 | 33 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +6; `helper_sum` +20; `PadTerm::eval` +1 | 54 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +1 | 37 |
| 19 SC_TAB | 7 | `PadTerm::eval` +1 | 8 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

## rung — rung (T24 / d96 / f192, 6 heads of 16 over 2 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 01 | SC_SSM | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 02 | SC_TZC | host | 5 | 1 | 3 | 3 | 26 | 23/3 | 3 | 4 | 8 | 44 | 33 | 832 | 24,490 | 11,656 | 52.4% |
| 03 | SC_LZC | stan | 10 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 5,120 | 250,635 | 147,283 | 41.2% |
| 04 | SC_RS | priv | 13 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 40,960 | 1,187,715 | 827,287 | 30.3% |
| 05 | SC_QMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 06 | SC_KMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 07 | SC_VMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 08 | SC_SCORE | priv | 5 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 96 | 2,025 | 1,390 | 31.4% |
| 09 | SC_PV | priv | 6 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 192 | 4,105 | 2,830 | 31.1% |
| 10 | SC_WO | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 11 | SC_GMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 12 | SC_UMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 13 | SC_DMM | priv | 8 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 512 | 7,655 | 6,119 | 20.1% |
| 14 | SC_DZC | host | 12 | 1 | 5 | 4 | 62 | 40/22 | 3 | 24 | 53 | 288 | 158 | 253,952 | 22,547,070 | 7,972,391 | 64.6% |
| 15 | SC_QZC | host | 12 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 86,016 | 6,474,195 | 2,819,228 | 56.5% |
| 16 | SC_KVZC | host | 10 | 1 | 5 | 4 | 19 | 10/9 | 3 | 9 | 17 | 71 | 40 | 19,456 | 1,472,097 | 650,971 | 55.8% |
| 17 | SC_SZC | host | 13 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 245,760 | 21,132,780 | 8,698,555 | 58.8% |
| 18 | SC_FZC | host | 13 | 1 | 5 | 4 | 21 | 12/9 | 3 | 10 | 16 | 78 | 49 | 172,032 | 13,785,453 | 5,426,369 | 60.6% |
| 19 | SC_TAB | stan | 10 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 11,264 | 383,625 | 245,490 | 36.0% |
| 20 | SC_ZS | stan | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 25,575 | 19,431 | 24.0% |
| 21 | SC_IO_IN | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| 22 | SC_IO_OUT | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| — | **all 23** | | | | | | **234** | | **35** | | | **730** | | **888,928** | **68,425,990** | **27,613,014** | **59.6%** |

peak single-slot table set: 3.9 MiB (slot 14 SC_DZC, 62 tables of 2^12 `Fp2` words), or 2.6 MiB with its 40 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.01 GiB (0.01 GiB mixed) [COUNTED]

launch / hand-back counts: 217 main rounds over the 23 slots plus 25 extension rounds — one round message (96 `Fp2` values in total over the main rounds of one round index each, 1055 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 63,689,720 | 4,443,470 | 292,800 | 68,425,990 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 56,824,702 | 4,443,470 | 292,800 | 61,560,972 | 10.0% |
| + (a) base-field operands in round 1 | 43,272,958 | 3,631,070 | 292,800 | 47,196,828 | 23.3% |
| + (c) finite differences per sub-expression | 23,689,144 | 3,631,070 | 292,800 | 27,613,014 | 41.5% |
| **all three together** | | | | **27,613,014** | **59.6% of the baseline** |

table traffic of the round loop: 1,777,388 `Fp2` words read, 888,694 written — 0.03 GiB read at 16 B a word. 146 of the 234 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +6 | 33 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +57; `PadTerm::eval` +37 | 158 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +8 | 40 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +13 | 49 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |
| 16 SC_KVZC | 4 | 5 | same |
| 18 SC_FZC | 4 | 5 | same |

## rung_g — rung-G (T24 / d96 / f192, 6 heads of 16 over 2 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 01 | SC_SSM | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 02 | SC_TZC | host | 5 | 1 | 3 | 3 | 26 | 23/3 | 3 | 4 | 8 | 44 | 33 | 832 | 24,490 | 11,656 | 52.4% |
| 03 | SC_LZC | stan | 10 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 5,120 | 250,635 | 147,283 | 41.2% |
| 04 | SC_RS | priv | 13 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 40,960 | 1,187,715 | 827,287 | 30.3% |
| 05 | SC_QMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 06 | SC_KMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 07 | SC_VMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 08 | SC_SCORE | priv | 5 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 96 | 2,025 | 1,390 | 31.4% |
| 09 | SC_PV | priv | 6 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 192 | 4,105 | 2,830 | 31.1% |
| 10 | SC_WO | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 11 | SC_GMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 12 | SC_UMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 13 | SC_DMM | priv | 8 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 512 | 7,655 | 6,119 | 20.1% |
| 14 | SC_DZC | host | 12 | 1 | 5 | 4 | 62 | 40/22 | 3 | 24 | 53 | 288 | 158 | 253,952 | 22,547,070 | 7,972,391 | 64.6% |
| 15 | SC_QZC | host | 12 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 86,016 | 6,474,195 | 2,819,228 | 56.5% |
| 16 | SC_KVZC | host | 10 | 1 | 5 | 4 | 19 | 10/9 | 3 | 9 | 17 | 71 | 40 | 19,456 | 1,472,097 | 650,971 | 55.8% |
| 17 | SC_SZC | host | 13 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 245,760 | 21,132,780 | 8,698,555 | 58.8% |
| 18 | SC_FZC | host | 13 | 1 | 5 | 4 | 21 | 12/9 | 3 | 10 | 16 | 78 | 49 | 172,032 | 13,785,453 | 5,426,369 | 60.6% |
| 19 | SC_TAB | stan | 10 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 11,264 | 383,625 | 245,490 | 36.0% |
| 20 | SC_ZS | stan | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 25,575 | 19,431 | 24.0% |
| 21 | SC_IO_IN | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| 22 | SC_IO_OUT | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| — | **all 23** | | | | | | **234** | | **35** | | | **730** | | **888,928** | **68,425,990** | **27,613,014** | **59.6%** |

peak single-slot table set: 3.9 MiB (slot 14 SC_DZC, 62 tables of 2^12 `Fp2` words), or 2.6 MiB with its 40 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.01 GiB (0.01 GiB mixed) [COUNTED]

launch / hand-back counts: 217 main rounds over the 23 slots plus 25 extension rounds — one round message (96 `Fp2` values in total over the main rounds of one round index each, 1055 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 63,689,720 | 4,443,470 | 292,800 | 68,425,990 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 56,824,702 | 4,443,470 | 292,800 | 61,560,972 | 10.0% |
| + (a) base-field operands in round 1 | 43,272,958 | 3,631,070 | 292,800 | 47,196,828 | 23.3% |
| + (c) finite differences per sub-expression | 23,689,144 | 3,631,070 | 292,800 | 27,613,014 | 41.5% |
| **all three together** | | | | **27,613,014** | **59.6% of the baseline** |

table traffic of the round loop: 1,777,388 `Fp2` words read, 888,694 written — 0.03 GiB read at 16 B a word. 146 of the 234 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +6 | 33 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +57; `PadTerm::eval` +37 | 158 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +8 | 40 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +13 | 49 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |
| 16 SC_KVZC | 4 | 5 | same |
| 18 SC_FZC | 4 | 5 | same |

## rung_k4 — rung-K4 (T24 / d96 / f192, 12 heads of 8 over 4 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 01 | SC_SSM | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 02 | SC_TZC | host | 5 | 1 | 3 | 3 | 26 | 23/3 | 3 | 4 | 8 | 44 | 33 | 832 | 24,490 | 11,656 | 52.4% |
| 03 | SC_LZC | stan | 10 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 5,120 | 250,635 | 147,283 | 41.2% |
| 04 | SC_RS | priv | 14 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 81,920 | 2,375,555 | 1,654,679 | 30.3% |
| 05 | SC_QMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 06 | SC_KMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 07 | SC_VMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 08 | SC_SCORE | priv | 5 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 96 | 2,025 | 1,390 | 31.4% |
| 09 | SC_PV | priv | 7 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 384 | 8,265 | 5,710 | 30.9% |
| 10 | SC_WO | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 11 | SC_GMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 12 | SC_UMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 13 | SC_DMM | priv | 8 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 512 | 7,655 | 6,119 | 20.1% |
| 14 | SC_DZC | host | 12 | 1 | 5 | 4 | 62 | 40/22 | 3 | 24 | 53 | 288 | 158 | 253,952 | 22,547,070 | 7,972,391 | 64.6% |
| 15 | SC_QZC | host | 12 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 86,016 | 6,474,195 | 2,819,228 | 56.5% |
| 16 | SC_KVZC | host | 10 | 1 | 5 | 4 | 19 | 10/9 | 3 | 9 | 17 | 71 | 40 | 19,456 | 1,472,097 | 650,971 | 55.8% |
| 17 | SC_SZC | host | 14 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 491,520 | 42,268,140 | 17,398,459 | 58.8% |
| 18 | SC_FZC | host | 13 | 1 | 5 | 4 | 21 | 12/9 | 3 | 10 | 16 | 78 | 49 | 172,032 | 13,785,453 | 5,426,369 | 60.6% |
| 19 | SC_TAB | stan | 10 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 11,264 | 383,625 | 245,490 | 36.0% |
| 20 | SC_ZS | stan | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 25,575 | 19,431 | 24.0% |
| 21 | SC_IO_IN | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| 22 | SC_IO_OUT | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| — | **all 23** | | | | | | **234** | | **35** | | | **730** | | **1,175,840** | **90,753,350** | **37,143,190** | **59.1%** |

peak single-slot table set: 7.5 MiB (slot 17 SC_SZC, 30 tables of 2^14 `Fp2` words), or 5.2 MiB with its 18 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.02 GiB (0.01 GiB mixed) [COUNTED]

launch / hand-back counts: 220 main rounds over the 23 slots plus 25 extension rounds — one round message (96 `Fp2` values in total over the main rounds of one round index each, 1070 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 84,418,040 | 5,878,030 | 457,280 | 90,753,350 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 75,390,334 | 5,878,030 | 457,280 | 81,725,644 | 9.9% |
| + (a) base-field operands in round 1 | 57,356,670 | 4,795,102 | 457,280 | 62,609,052 | 23.4% |
| + (c) finite differences per sub-expression | 31,890,808 | 4,795,102 | 457,280 | 37,143,190 | 40.7% |
| **all three together** | | | | **37,143,190** | **59.1% of the baseline** |

table traffic of the round loop: 2,351,212 `Fp2` words read, 1,175,606 written — 0.04 GiB read at 16 B a word. 146 of the 234 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

MEASURED base-field census of the lane ledger against this model [cross-check 2]:

| slot | measured tables | counted | measured wholly base-field | counted | agree |
|---|--:|--:|--:|--:|---|
| 04 SC_RS | 5 | 5 | 4 | 4 | YES |
| 14 SC_DZC | 62 | 62 | 40 | 40 | YES |
| 15 SC_QZC | 21 | 21 | 11 | 11 | YES |
| 17 SC_SZC | 30 | 30 | 18 | 18 | YES |
| 18 SC_FZC | 21 | 21 | 12 | 12 | YES |

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +6 | 33 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +57; `PadTerm::eval` +37 | 158 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +8 | 40 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +13 | 49 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |
| 16 SC_KVZC | 4 | 5 | same |
| 18 SC_FZC | 4 | 5 | same |

## rung_p2 — rung-P2 (T32 / d96 / f256, 12 heads of 8 over 4 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 01 | SC_SSM | priv | 12 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 12,288 | 429,990 | 290,736 | 32.4% |
| 02 | SC_TZC | host | 5 | 1 | 3 | 3 | 25 | 22/3 | 3 | 3 | 6 | 36 | 28 | 800 | 21,235 | 8,741 | 58.8% |
| 03 | SC_LZC | stan | 10 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 5,120 | 250,635 | 147,283 | 41.2% |
| 04 | SC_RS | priv | 14 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 81,920 | 2,375,555 | 1,654,679 | 30.3% |
| 05 | SC_QMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 06 | SC_KMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 07 | SC_VMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 08 | SC_SCORE | priv | 5 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 96 | 2,025 | 1,390 | 31.4% |
| 09 | SC_PV | priv | 7 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 384 | 8,265 | 5,710 | 30.9% |
| 10 | SC_WO | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 11 | SC_GMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 12 | SC_UMM | priv | 7 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 256 | 3,815 | 3,047 | 20.1% |
| 13 | SC_DMM | priv | 8 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 512 | 7,655 | 6,119 | 20.1% |
| 14 | SC_DZC | host | 12 | 1 | 5 | 4 | 62 | 40/22 | 3 | 24 | 53 | 288 | 158 | 253,952 | 22,547,070 | 7,972,391 | 64.6% |
| 15 | SC_QZC | host | 12 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 86,016 | 6,474,195 | 2,819,228 | 56.5% |
| 16 | SC_KVZC | host | 10 | 1 | 4 | 4 | 18 | 9/9 | 3 | 8 | 15 | 59 | 33 | 18,432 | 1,058,805 | 522,117 | 50.7% |
| 17 | SC_SZC | host | 14 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 491,520 | 42,268,140 | 17,398,459 | 58.8% |
| 18 | SC_FZC | host | 13 | 1 | 4 | 4 | 20 | 11/9 | 3 | 9 | 14 | 56 | 37 | 163,840 | 9,132,965 | 4,091,293 | 55.2% |
| 19 | SC_TAB | stan | 10 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 11,264 | 383,625 | 245,490 | 36.0% |
| 20 | SC_ZS | stan | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 25,575 | 19,431 | 24.0% |
| 21 | SC_IO_IN | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| 22 | SC_IO_OUT | stan | 12 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 12,288 | 122,850 | 92,130 | 25.0% |
| — | **all 23** | | | | | | **231** | | **35** | | | **688** | | **1,166,592** | **85,684,315** | **35,676,345** | **58.4%** |

peak single-slot table set: 7.5 MiB (slot 17 SC_SZC, 30 tables of 2^14 `Fp2` words), or 5.2 MiB with its 18 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.02 GiB (0.01 GiB mixed) [COUNTED]

launch / hand-back counts: 220 main rounds over the 23 slots plus 25 extension rounds — one round message (94 `Fp2` values in total over the main rounds of one round index each, 1045 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 79,395,230 | 5,831,805 | 457,280 | 85,684,315 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 69,658,246 | 5,831,805 | 457,280 | 75,947,331 | 11.4% |
| + (a) base-field operands in round 1 | 53,119,942 | 4,762,749 | 457,280 | 58,339,971 | 23.2% |
| + (c) finite differences per sub-expression | 30,456,316 | 4,762,749 | 457,280 | 35,676,345 | 38.8% |
| **all three together** | | | | **35,676,345** | **58.4% of the baseline** |

table traffic of the round loop: 2,332,722 `Fp2` words read, 1,166,361 written — 0.03 GiB read at 16 B a word. 143 of the 231 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +1 | 28 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +57; `PadTerm::eval` +37 | 158 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +1 | 33 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +1 | 37 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |

## rung_c6 — rung-C6 (T32 / d384 / f512, 12 heads of 32 over 4 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 14 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 49,152 | 1,720,230 | 1,163,184 | 32.4% |
| 01 | SC_SSM | priv | 14 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 49,152 | 1,720,230 | 1,163,184 | 32.4% |
| 02 | SC_TZC | host | 5 | 1 | 3 | 3 | 25 | 22/3 | 3 | 3 | 6 | 36 | 28 | 800 | 21,235 | 8,741 | 58.8% |
| 03 | SC_LZC | stan | 10 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 5,120 | 250,635 | 147,283 | 41.2% |
| 04 | SC_RS | priv | 14 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 81,920 | 2,375,555 | 1,654,679 | 30.3% |
| 05 | SC_QMM | priv | 9 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 1,024 | 15,335 | 12,263 | 20.0% |
| 06 | SC_KMM | priv | 9 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 1,024 | 15,335 | 12,263 | 20.0% |
| 07 | SC_VMM | priv | 9 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 1,024 | 15,335 | 12,263 | 20.0% |
| 08 | SC_SCORE | priv | 7 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 384 | 8,265 | 5,710 | 30.9% |
| 09 | SC_PV | priv | 7 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 384 | 8,265 | 5,710 | 30.9% |
| 10 | SC_WO | priv | 9 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 1,024 | 15,335 | 12,263 | 20.0% |
| 11 | SC_GMM | priv | 9 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 1,024 | 15,335 | 12,263 | 20.0% |
| 12 | SC_UMM | priv | 9 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 1,024 | 15,335 | 12,263 | 20.0% |
| 13 | SC_DMM | priv | 9 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 1,024 | 15,335 | 12,263 | 20.0% |
| 14 | SC_DZC | host | 14 | 1 | 5 | 4 | 60 | 40/20 | 3 | 22 | 49 | 272 | 152 | 983,040 | 86,305,644 | 29,963,961 | 65.3% |
| 15 | SC_QZC | host | 14 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 344,064 | 25,901,523 | 11,279,516 | 56.5% |
| 16 | SC_KVZC | host | 12 | 1 | 4 | 4 | 18 | 9/9 | 3 | 8 | 15 | 59 | 33 | 73,728 | 4,238,325 | 2,090,373 | 50.7% |
| 17 | SC_SZC | host | 14 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 491,520 | 42,268,140 | 17,398,459 | 58.8% |
| 18 | SC_FZC | host | 14 | 1 | 4 | 4 | 20 | 11/9 | 3 | 9 | 14 | 56 | 37 | 327,680 | 18,267,045 | 8,183,197 | 55.2% |
| 19 | SC_TAB | stan | 10 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 11,264 | 383,625 | 245,490 | 36.0% |
| 20 | SC_ZS | stan | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 25,575 | 19,431 | 24.0% |
| 21 | SC_IO_IN | stan | 14 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 49,152 | 491,490 | 368,610 | 25.0% |
| 22 | SC_IO_OUT | stan | 14 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 49,152 | 491,490 | 368,610 | 25.0% |
| — | **all 23** | | | | | | **229** | | **35** | | | **672** | | **2,525,728** | **184,584,617** | **74,151,979** | **59.8%** |

peak single-slot table set: 15.0 MiB (slot 14 SC_DZC, 60 tables of 2^14 `Fp2` words), or 10.0 MiB with its 40 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.04 GiB (0.03 GiB mixed) [COUNTED]

launch / hand-back counts: 250 main rounds over the 23 slots plus 25 extension rounds — one round message (94 `Fp2` values in total over the main rounds of one round index each, 1163 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 171,117,442 | 12,627,495 | 839,680 | 184,584,617 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 148,843,626 | 12,627,495 | 839,680 | 162,310,801 | 12.1% |
| + (a) base-field operands in round 1 | 113,215,338 | 10,290,183 | 839,680 | 124,345,201 | 23.4% |
| + (c) finite differences per sub-expression | 63,022,116 | 10,290,183 | 839,680 | 74,151,979 | 40.4% |
| **all three together** | | | | **74,151,979** | **59.8% of the baseline** |

table traffic of the round loop: 5,050,998 `Fp2` words read, 2,525,499 written — 0.08 GiB read at 16 B a word. 143 of the 229 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +1 | 28 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +51; `PadTerm::eval` +37 | 152 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +1 | 33 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +1 | 37 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |

## rung_w14 — rung-W14 (T64 / d768 / f1024, 12 heads of 64 over 4 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 16 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 196,608 | 6,881,190 | 4,652,976 | 32.4% |
| 01 | SC_SSM | priv | 16 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 196,608 | 6,881,190 | 4,652,976 | 32.4% |
| 02 | SC_TZC | host | 6 | 1 | 3 | 3 | 25 | 22/3 | 3 | 3 | 6 | 36 | 28 | 1,600 | 43,155 | 17,861 | 58.6% |
| 03 | SC_LZC | stan | 14 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 81,920 | 4,013,835 | 2,359,123 | 41.2% |
| 04 | SC_RS | priv | 16 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 327,680 | 9,502,595 | 6,619,031 | 30.3% |
| 05 | SC_QMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 06 | SC_KMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 07 | SC_VMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 08 | SC_SCORE | priv | 8 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 768 | 16,585 | 11,470 | 30.8% |
| 09 | SC_PV | priv | 8 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 768 | 16,585 | 11,470 | 30.8% |
| 10 | SC_WO | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 11 | SC_GMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 12 | SC_UMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 13 | SC_DMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 14 | SC_DZC | host | 16 | 1 | 5 | 4 | 60 | 40/20 | 3 | 22 | 49 | 272 | 152 | 3,932,160 | 345,238,380 | 119,862,969 | 65.3% |
| 15 | SC_QZC | host | 16 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 1,376,256 | 103,610,835 | 45,120,668 | 56.5% |
| 16 | SC_KVZC | host | 14 | 1 | 4 | 4 | 18 | 9/9 | 3 | 8 | 15 | 59 | 33 | 294,912 | 16,956,405 | 8,363,397 | 50.7% |
| 17 | SC_SZC | host | 16 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 1,966,080 | 169,080,300 | 69,597,883 | 58.8% |
| 18 | SC_FZC | host | 16 | 1 | 4 | 4 | 20 | 11/9 | 3 | 9 | 14 | 56 | 37 | 1,310,720 | 73,071,525 | 32,734,621 | 55.2% |
| 19 | SC_TAB | stan | 14 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 180,224 | 6,143,625 | 3,931,890 | 36.0% |
| 20 | SC_ZS | stan | 14 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32,768 | 409,575 | 311,271 | 24.0% |
| 21 | SC_IO_IN | stan | 16 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 196,608 | 1,966,050 | 1,474,530 | 25.0% |
| 22 | SC_IO_OUT | stan | 16 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 196,608 | 1,966,050 | 1,474,530 | 25.0% |
| — | **all 23** | | | | | | **229** | | **35** | | | **672** | | **10,306,624** | **746,012,745** | **301,368,523** | **59.6%** |

peak single-slot table set: 60.0 MiB (slot 14 SC_DZC, 60 tables of 2^16 `Fp2` words), or 40.0 MiB with its 40 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.15 GiB (0.11 GiB mixed) [COUNTED]

launch / hand-back counts: 292 main rounds over the 23 slots plus 25 extension rounds — one round message (94 `Fp2` values in total over the main rounds of one round index each, 1342 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 691,163,010 | 51,531,975 | 3,317,760 | 746,012,745 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 602,073,834 | 51,531,975 | 3,317,760 | 656,923,569 | 11.9% |
| + (a) base-field operands in round 1 | 458,586,346 | 42,031,239 | 3,317,760 | 503,935,345 | 23.3% |
| + (c) finite differences per sub-expression | 256,019,524 | 42,031,239 | 3,317,760 | 301,368,523 | 40.2% |
| **all three together** | | | | **301,368,523** | **59.6% of the baseline** |

table traffic of the round loop: 20,612,790 `Fp2` words read, 10,306,395 written — 0.31 GiB read at 16 B a word. 143 of the 229 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +1 | 28 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +51; `PadTerm::eval` +37 | 152 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +1 | 33 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +1 | 37 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |

## rung_e32 — rung-E32 (T32 / d768 / f1024, 12 heads of 64 over 4 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 15 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 98,304 | 3,440,550 | 2,326,448 | 32.4% |
| 01 | SC_SSM | priv | 15 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 98,304 | 3,440,550 | 2,326,448 | 32.4% |
| 02 | SC_TZC | host | 5 | 1 | 3 | 3 | 25 | 22/3 | 3 | 3 | 6 | 36 | 28 | 800 | 21,235 | 8,741 | 58.8% |
| 03 | SC_LZC | stan | 10 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 5,120 | 250,635 | 147,283 | 41.2% |
| 04 | SC_RS | priv | 14 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 81,920 | 2,375,555 | 1,654,679 | 30.3% |
| 05 | SC_QMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 06 | SC_KMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 07 | SC_VMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 08 | SC_SCORE | priv | 8 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 768 | 16,585 | 11,470 | 30.8% |
| 09 | SC_PV | priv | 7 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 384 | 8,265 | 5,710 | 30.9% |
| 10 | SC_WO | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 11 | SC_GMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 12 | SC_UMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 13 | SC_DMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 14 | SC_DZC | host | 15 | 1 | 5 | 4 | 60 | 40/20 | 3 | 22 | 49 | 272 | 152 | 1,966,080 | 172,616,556 | 59,930,297 | 65.3% |
| 15 | SC_QZC | host | 15 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 688,128 | 51,804,627 | 22,559,900 | 56.5% |
| 16 | SC_KVZC | host | 13 | 1 | 4 | 4 | 18 | 9/9 | 3 | 8 | 15 | 59 | 33 | 147,456 | 8,477,685 | 4,181,381 | 50.7% |
| 17 | SC_SZC | host | 14 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 491,520 | 42,268,140 | 17,398,459 | 58.8% |
| 18 | SC_FZC | host | 15 | 1 | 4 | 4 | 20 | 11/9 | 3 | 9 | 14 | 56 | 37 | 655,360 | 36,535,205 | 16,367,005 | 55.2% |
| 19 | SC_TAB | stan | 10 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 11,264 | 383,625 | 245,490 | 36.0% |
| 20 | SC_ZS | stan | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 25,575 | 19,431 | 24.0% |
| 21 | SC_IO_IN | stan | 15 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 98,304 | 983,010 | 737,250 | 25.0% |
| 22 | SC_IO_OUT | stan | 15 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 98,304 | 983,010 | 737,250 | 25.0% |
| — | **all 23** | | | | | | **229** | | **35** | | | **672** | | **4,458,400** | **323,845,673** | **128,829,099** | **60.2%** |

peak single-slot table set: 30.0 MiB (slot 14 SC_DZC, 60 tables of 2^15 `Fp2` words), or 20.0 MiB with its 40 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 0.07 GiB (0.05 GiB mixed) [COUNTED]

launch / hand-back counts: 266 main rounds over the 23 slots plus 25 extension rounds — one round message (94 `Fp2` values in total over the main rounds of one round index each, 1226 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 300,204,418 | 22,290,855 | 1,350,400 | 323,845,673 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 259,986,026 | 22,290,855 | 1,350,400 | 283,627,281 | 12.4% |
| + (a) base-field operands in round 1 | 197,781,354 | 18,172,167 | 1,350,400 | 217,303,921 | 23.4% |
| + (c) finite differences per sub-expression | 109,306,532 | 18,172,167 | 1,350,400 | 128,829,099 | 40.7% |
| **all three together** | | | | **128,829,099** | **60.2% of the baseline** |

table traffic of the round loop: 8,916,342 `Fp2` words read, 4,458,171 written — 0.13 GiB read at 16 B a word. 143 of the 229 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +1 | 28 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +51; `PadTerm::eval` +37 | 152 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +1 | 33 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +1 | 37 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |

## m125 — 125M (T512 / d768 / f2048, 12 heads of 64 over 4 KV)

| slot | name | kind | main | ext | deg | IR deg | tables | base/ext | IR terms | nodes | forms | monomials | mul/eval | cube words | Fp mul, closure | Fp mul, IR | saved |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 00 | SC_SS | priv | 19 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 1,572,864 | 55,050,150 | 37,224,368 | 32.4% |
| 01 | SC_SSM | priv | 19 | 1 | 4 | 4 | 3 | 2/1 | 1 | 0 | 0 | 1 | 3 | 1,572,864 | 55,050,150 | 37,224,368 | 32.4% |
| 02 | SC_TZC | host | 9 | 1 | 3 | 3 | 25 | 22/3 | 3 | 3 | 6 | 36 | 28 | 12,800 | 350,035 | 145,541 | 58.4% |
| 03 | SC_LZC | stan | 14 | 1 | 4 | 4 | 5 | 3/2 | 1 | 3 | 4 | 12 | 8 | 81,920 | 4,013,835 | 2,359,123 | 41.2% |
| 04 | SC_RS | priv | 22 | 1 | 4 | 4 | 5 | 4/1 | 1 | 1 | 0 | 2 | 4 | 20,971,520 | 608,173,955 | 423,624,599 | 30.3% |
| 05 | SC_QMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 06 | SC_KMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 07 | SC_VMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 08 | SC_SCORE | priv | 8 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 768 | 16,585 | 11,470 | 30.8% |
| 09 | SC_PV | priv | 11 | 2 | 3 | 3 | 3 | 2/1 | 1 | 0 | 0 | 1 | 2 | 6,144 | 133,065 | 92,110 | 30.8% |
| 10 | SC_WO | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 11 | SC_GMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 12 | SC_UMM | priv | 10 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 2,048 | 30,695 | 24,551 | 20.0% |
| 13 | SC_DMM | priv | 11 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 4,096 | 61,415 | 49,127 | 20.0% |
| 14 | SC_DZC | host | 19 | 1 | 5 | 4 | 60 | 40/20 | 3 | 22 | 49 | 272 | 152 | 31,457,280 | 2,761,943,916 | 958,920,377 | 65.3% |
| 15 | SC_QZC | host | 19 | 1 | 5 | 4 | 21 | 11/10 | 3 | 10 | 18 | 77 | 44 | 11,010,048 | 828,897,747 | 360,971,420 | 56.5% |
| 16 | SC_KVZC | host | 17 | 1 | 4 | 4 | 18 | 9/9 | 3 | 8 | 15 | 59 | 33 | 2,359,296 | 135,658,485 | 66,911,621 | 50.7% |
| 17 | SC_SZC | host | 22 | 1 | 5 | 5 | 30 | 18/12 | 3 | 17 | 26 | 121 | 75 | 125,829,120 | 10,821,301,740 | 4,454,349,499 | 58.8% |
| 18 | SC_FZC | host | 20 | 1 | 4 | 4 | 20 | 11/9 | 3 | 9 | 14 | 56 | 37 | 20,971,520 | 1,169,161,125 | 523,763,101 | 55.2% |
| 19 | SC_TAB | stan | 14 | 1 | 3 | 3 | 11 | 5/6 | 1 | 5 | 7 | 21 | 16 | 180,224 | 6,143,625 | 3,931,890 | 36.0% |
| 20 | SC_ZS | stan | 14 | 1 | 2 | 2 | 2 | 1/1 | 1 | 0 | 0 | 1 | 1 | 32,768 | 409,575 | 311,271 | 24.0% |
| 21 | SC_IO_IN | stan | 19 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 1,572,864 | 15,728,610 | 11,796,450 | 25.0% |
| 22 | SC_IO_OUT | stan | 19 | 1 | 2 | 2 | 3 | 2/1 | 1 | 1 | 0 | 2 | 1 | 1,572,864 | 15,728,610 | 11,796,450 | 25.0% |
| — | **all 23** | | | | | | **229** | | **35** | | | **672** | | **219,221,248** | **16,478,006,793** | **6,893,630,091** | **58.2%** |

peak single-slot table set: 1,920.0 MiB (slot 17 SC_SZC, 30 tables of 2^22 `Fp2` words), or 1,344.0 MiB with its 18 base-field tables as `Fp` cubes; the sum over all 23 slots, if every set were resident at once: 3.27 GiB (2.25 GiB mixed) [COUNTED]

launch / hand-back counts: 336 main rounds over the 23 slots plus 25 extension rounds — one round message (94 `Fp2` values in total over the main rounds of one round index each, 1554 over the whole proof) crosses back to the host per round, and one challenge crosses to the device [COUNTED]

### the three levers, cumulative, against the closure [COUNTED]

Base-field (Fp) multiplications over all 23 slots: the round loop, the table fold and the claimed sum. Each row adds one lever to the row above; `marginal` is what that lever alone removes.

| form | round loop | fold | claimed sum | total | marginal |
|---|--:|--:|--:|--:|--:|
| closure as written (the baseline) | 15,282,222,978 | 1,096,105,095 | 99,678,720 | 16,478,006,793 | — |
| + (b) shared sub-expressions, hoisted wrappers, coefficients typed by provenance | 13,482,649,066 | 1,096,105,095 | 99,678,720 | 14,678,432,881 | 10.9% |
| + (a) base-field operands in round 1 | 10,254,440,426 | 891,965,319 | 99,678,720 | 11,246,084,465 | 23.4% |
| + (c) finite differences per sub-expression | 5,901,986,052 | 891,965,319 | 99,678,720 | 6,893,630,091 | 38.7% |
| **all three together** | | | | **6,893,630,091** | **58.2% of the baseline** |

table traffic of the round loop: 438,442,038 `Fp2` words read, 219,221,019 written — 6.53 GiB read at 16 B a word. 143 of the 229 tables are wholly base-field, and handing those out as `Fp` cubes halves their round-0 read and their resident size [COUNTED].

### the cross-checks

MEASURED base-field census of the lane ledger against this model [cross-check 2]:

| slot | measured tables | counted | measured wholly base-field | counted | agree |
|---|--:|--:|--:|--:|---|
| 04 SC_RS | 5 | 5 | 4 | 4 | YES |
| 14 SC_DZC | 60 | 60 | 40 | 40 | YES |
| 15 SC_QZC | 21 | 21 | 11 | 11 | YES |
| 17 SC_SZC | 30 | 30 | 18 | 18 | YES |
| 18 SC_FZC | 20 | 20 | 11 | 11 | YES |

lane Python layout model [cross-check 3]: 23 slots compared, 0 differences []

the token identity [cross-check 1], slot by slot (`dynamic = tokens + adjustments`):

| slot | tokens | adjustments | dynamic |
|---|--:|---|--:|
| 00 SC_SS | 3 | none | 3 |
| 01 SC_SSM | 3 | none | 3 |
| 02 SC_TZC | 17 | `l3` is one named closure of 2 tokens, called 6x +10; `PadTerm::eval` +1 | 28 |
| 03 SC_LZC | 1 | `helper_sum` +3; `PadTerm::eval` +4 | 8 |
| 04 SC_RS | 4 | none | 4 |
| 05 SC_QMM | 1 | none | 1 |
| 06 SC_KMM | 1 | none | 1 |
| 07 SC_VMM | 1 | none | 1 |
| 08 SC_SCORE | 2 | none | 2 |
| 09 SC_PV | 2 | none | 2 |
| 10 SC_WO | 1 | none | 1 |
| 11 SC_GMM | 1 | none | 1 |
| 12 SC_UMM | 1 | none | 1 |
| 13 SC_DMM | 1 | none | 1 |
| 14 SC_DZC | 24 | `l2` is one named closure of 1 token, called 5x +4; the 11-clause loop body (2 tokens) runs 11x +20; `limbs()` over four limb groups +16; `helper_sum` +51; `PadTerm::eval` +37 | 152 |
| 15 SC_QZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -2; `helper_sum` +20; `PadTerm::eval` +9 | 44 |
| 16 SC_KVZC | 17 | the unused branch of `if q` (its tokens are counted, not run) -3; `helper_sum` +18; `PadTerm::eval` +1 | 33 |
| 17 SC_SZC | 19 | the 5-clause loop body (2 tokens) runs 5x +8; `limbs()` over sr, sg and pl +8; `helper_sum` +23; `PadTerm::eval` +17 | 75 |
| 18 SC_FZC | 16 | `l2` is one named closure of 1 token, called 3x +2; the 3-clause loop body (2 tokens) runs 3x +4; `helper_sum` +14; `PadTerm::eval` +1 | 37 |
| 19 SC_TAB | 7 | `PadTerm::eval` +9 | 16 |
| 20 SC_ZS | 1 | none | 1 |
| 21 SC_IO_IN | 1 | none | 1 |
| 22 SC_IO_OUT | 1 | none | 1 |

slots whose DECLARED degree exceeds the maximum product degree the IR computes. The declared degree is an upper bound and is what the round message length is built from, so lowering it would MOVE BYTES: it is reported here as a count, not proposed.

| slot | IR max product degree | declared | why |
|---|--:|--:|---|
| 14 SC_DZC | 4 | 5 | the ungated LogUp arm already reaches 4; the support indicator raises only the clause arm, from 3 to 4 |
| 15 SC_QZC | 4 | 5 | same |

# json written to results/zk60_slot_ir/slot_ir_counts.json
