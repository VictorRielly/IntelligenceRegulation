# hashline `--zk --profile v3` — ZERO KNOWLEDGE ON THE WIDENED STACK, the 12x512 row (U-PERF3 lane AD, 2026-09-03)

The measured record behind the ZK-v3 row in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3, in the form of
lane ZA's results/hashline_zk_12x512.md (the v2 ZK row it composes) and
lane ZB's results/hashline_v3_12x512.md (the v3 semantics it composes).
Every number here is [MEASURED] on the WSL laptop (Core Ultra 9 185H,
22 threads, 15 GB; RTX 4070 Laptop GPU, sm_89, 36 SMs, 8 GB), 8 rayon
threads (+ the device on the GPU rows), label
**[WSL-BOX] [8T] [NOISY-SHARED]** — and NOISY here is not a formality:
lanes AC, AE and AF were building and running on the same box
throughout (load average 5-21, three of the runs queued 5-13 minutes on
`flock /tmp/zk-heavy.lock`). Read the walls as a class, not as a
record; the byte gates below are exact and load-independent.
Commits: rungs 0-5 in PROGRESS_UPERF3.md "Agent AD status"
(5fff287, d8872a9, 2e0d1ed, and the rung 2-5 commits).
Design: the `[UPERF3-AD]` block at the end of hashline/src/zk.rs (its
module comment is the plan).

## What this row is

**The two halves of round 11 joined.** Lane ZB's v3 statement (the
widened stack: the int16-out activation member, the 2^16-row INT16
class for u16/h16/z16, round-to-nearest requant with balanced
remainders, negative shifts, block structure on both axes — the
semantics the 8B proof runs) proven in lane ZA's mode-P1 zero-knowledge
form (inputs and activations private, weights public). Before this rung
the 8B number was v3 and the ZK form was v2-only: two different
statements. `--zk --profile v3` is one statement.

## What is proven, what is now hidden, and what is still revealed

THE STATEMENT is lane ZB's v3 statement, unchanged — same witness (the
125M v3 export, `results/m8b_test/m125_v3_export`, 12 layers x 512
tokens, d 768, f 2048, 2.899e10 MACs per pass), same soundness
parameters (Goldilocks + F_{p^2} challenges; Ligero/Brakedown PCS at RS
rate 1/4, n = 2^14 columns, Q = 256 column checks; the two matmul
sumchecks; LogUp with committed helpers; the two zero-checks; blake3
Fiat-Shamir, ONE transcript over the 12 layers, domain
`hashline-pass-zk-v3`), in **MODE P1** of TARGET_CONTRACT Amendment A1:
inputs and activations private, weights public.

HIDDEN under `--zk --profile v3` — every construction of lane ZA's v2
form, applied to every v3 object:

- **the opened columns of A and H**: Q = 256 random pad symbols per
  row, the rows evaluated on the coset 7 G_{4n}, so no opened position
  is systematic; 65,536 Merkle leaves salted on each of A and H;
- **every clear row-combination vector**: one fresh uniformly random
  mask row per (private table, opening point). In the v3 layout that
  is one mask row per BLOCK-STRUCTURED plane per point — 7 nb_f
  f-planes (g8, rg, a16, u16, ru, h16, rh) at rho_F, 3 nb_d d-planes
  (X, z16, rd) at rho_D, the nb_d X-blocks at the g/u matmul point p2,
  the nb_f h16-blocks at the d matmul point p5 — plus a proximity mask
  row; in H one F_{p^2} mask (re, im) per helper plane per point, the
  zero-sum row u with its extension mask u', and a prox row;
- **the six multiplicity tables of every v3 layer**: the 256-row
  int16-out activation member (ACT16), the 2^16-row INT16 class, and
  the four balanced-remainder windows (one per signed shift g/u/h/z,
  no dedup) — committed as rows of A before alpha, each with a mask of
  its own shape, their table side h_t = m / (alpha - tval) a committed
  helper of H with an F_{p^2} mask; the LogUp identity is ONE value-0
  sum claim. No histogram and no helper sum is sent;
- **every sumcheck's round messages** (the two matmuls, zero-check F,
  zero-check D, the table zero-check, the zero-sum sumcheck): a
  committed Chiesa-Forbes-Spooner masking polynomial per sumcheck,
  folded in with a verifier challenge and opened from a small
  per-layer Ligero-form mask commitment by the product-form linear
  test;
- **every matmul claimed sum and every terminal evaluation of a
  private table**: sent masked through the sumcheck's last-round
  extension, so the verifier never sees an evaluation of the
  activations.

STILL REVEALED — by the mode, or by construction (say this plainly):

- **the weights**, in full: the W commitment, its 256 opened columns
  and its 3 clear row-combination vectors per layer are exactly the
  non-zk ones. Mode P1 is *private inputs, public weights*. Private
  weights are mode P2/P3 and are NOT this row (T18;
  U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md);
- **the shapes**: T, d, f, the layer count, the block structure
  (nb_d x 2^log_db, nb_f x 2^log_fb) — the v3 statement's block
  decomposition is public data;
- **the four signed shifts** per layer (sh_g, sh_u, sh_h, sh_z),
  including which of them is negative (the exact up-scaling branch);
- **the table digests and identities**: the activation member's spec
  digest and family name, the INT16 class bounds, and the SIZE of each
  of the six table slots — a remainder window's size is 2^sh, so
  publishing the shifts already publishes the windows;
- the masked values themselves (uniform), and the mask commitment's
  opening (uniform: the mask rows have their own pads, the product
  polynomial is blinded by a proven zero-sum row).

The simulator caveat is ZA's, unchanged and inherited: what is
established in code is that every opened object is uniform given the
public data and the previous transcript, per sub-protocol (the
uniformity test + the run-time site assertion). A full proof would
compose the per-object simulators in transcript order across the 12
chained layers under one Fiat-Shamir transcript, argue the ROM
programming for the salted leaves and the derived challenges, and do
the statistical-distance bookkeeping of the 2^-64-biased field draws.

## The one structural addition v3 forced on ZA's ZK form

Lane ZA's `TabRows` holds a multiplicity table in ONE commitment row and
asserts it. Two of v3's six table slots do not fit:

- the **INT16 class** is 2^16 rows against n = 2^14 columns at 12x512;
- a **balanced-remainder window** is 2^sh rows, and sh reaches 15 (the
  125M export has sh_h in {13, 14, 15}; Mistral layer 0 has sh_h 15);
- at the 3x16 shape (n = 2^12) every slot overflows.

Built (`TabRowsV3`, `N_TABLE_SLOTS_V3 = 6`): a slot of 2^log_size
entries, log_size = max(log2 size, log n), occupies **2^log_size / n
consecutive rows** of A, and its helper and both masks take the same
shape. The **table zero-check runs over log_S = max(log n, 16)
variables** with every slot's m, h_t and public tval zero-extended to
2^log_S; a slot then contributes `prod_{j<k} (1 - rho_j) * T~(rho[k..])`
with k = log_S - log_size, so its opened claim is the two-part masked
claim at the point rho[k..] carrying that PUBLIC coefficient. Every
slot's column tail is the last log n coordinates of rho_tab, so all six
slots still share ONE column-weight group (as in ZA's form). The RNG
domain is `layer-v3-{l}`: a v3 ZK proof never shares randomness with a
v2 one.

Everything else of ZB's v3 semantics folds into ZA's form without a new
construction: the round-nearest requant identity acc = 2^sh y + r is
still linear with no constant term, so it folds into the masked matmul
claims and the two zero-checks exactly as v2's floor identity did (at
sh <= 0 the field inverse of 2^-sh is the public coefficient and the
remainder column is committed all-zero over the one-row window {0});
the block structure multiplies the number of mask rows, not their kind.

## THE GATE: the new zk-v3 hash, and the three old gates unchanged

    pass 12 512 --zk --seed 1 --profile v3 \
      --export results/m8b_test/m125_v3_export --threads 8 --proof-out F

writes **87,697,008 B** with

    sha256 40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17

from the CPU-only binary (3 runs) AND from the gpu-cuda binary with
`HL_GPU=1` (3 runs) — `cmp` of the written files agrees. ACCEPT on
both. At 3x16: `4d9f7632e7b59b087786b1368b4855591d9cf0719803fa9e1d81dffd5385cf70`
(10,272,540 B), CPU and GPU. Seed 2 at 3x16 gives
`ff8cbbd35236780f361d737ee5342b1203fb29c910d4a8bd1bd8b68984e7864d` —
a different proof of the same statement, the same size.

The three gates that must not move, re-run on this tree at rung 2 on
both binaries:

| gate | command | sha256 | bytes | CPU | GPU |
|---|---|---|---:|---|---|
| v2 | `pass 12 512` (M125_EXPORT_DIR=results/m125_ffn_export_wsl) | `50cf7bdfd6b5b182..` | 66,844,928 | UNCHANGED | UNCHANGED |
| v3 | `pass 12 512 --profile v3 --export ...` | `5f368db6240e0614..` | 70,758,084 | UNCHANGED | UNCHANGED |
| zk-v2 | `pass 12 512 --zk --seed 1` | `021485e4f80ec695..` | 87,228,528 | UNCHANGED | UNCHANGED |

## THE ENUMERATED OPENING SITES of the v3 form (printed by the driver every run; `pcs::assert_mask_sites` runs at every `open_zk`)

Layer 0 of the 12x512 pass (shifts g/u/h/z 9/1/14/10; every layer is
identical in structure up to its window sizes):

    layout: n = 2^14 columns; table zero-check over 2^16 (the INT16
      class spans 4 rows); A 559 rows = 520 data + 21 masks + 18
      table/mask rows; H 485 rows = 432 data + 17 masks + 36
      helper/mask rows
    A masks: 7 f-planes (g8,rg,a16,u16,ru,h16,rh x 1 f-block) at rho_F
      -> rows 520-526; 9 d-planes (X,z16,rd x 3 d-blocks) at rho_D ->
      rows 527-535; X-blocks at p2 -> 536-538; h16-blocks at p5 -> 539;
      prox row 540
    table slot tag 3  (ACT16, 256 entries, 2^14 slice, 1 row):  m at A 541, mask A 542; helper H re 449 im 450, mask re 451 im 452
    table slot tag 4  (INT16, 65536 entries, 2^16 slice, 4 rows): m at A 543-546, mask A 547-550; helper H re 453-456 im 457-460, mask re 461-464 im 465-468
    table slot tag 81 (rem window sh_g 9,  512 entries,  1 row):  m at A 551, mask A 552; helper H re 469 im 470, mask re 471 im 472
    table slot tag 73 (rem window sh_u 1,    2 entries,  1 row):  m at A 553, mask A 554; helper H re 473 im 474, mask re 475 im 476
    table slot tag 86 (rem window sh_h 14, 16384 entries, 1 row): m at A 555, mask A 556; helper H re 477 im 478, mask re 479 im 480
    table slot tag 82 (rem window sh_z 10, 1024 entries, 1 row):  m at A 557, mask A 558; helper H re 481 im 482, mask re 483 im 484
    H masks: 3 helper planes (hg,hu,hh) at rho_F -> (432,433) (434,435)
      (436,437); 3 hz planes at rho_D -> (438,439) (440,441) (442,443);
      zero-sum u rows (444,445) with extension mask u' (446,447); prox 448
    A: 26 claims in 5 groups   H: 14 claims in 5 groups
    A group 0 (zc F point): mask rows 520-526
    A group 1 (zc D point): mask rows 527-535
    A group 2 (g/u terminals at p2): 536-538
    A group 3 (d terminal at p5): 539
    A group 4 (the table point): 542, 547-550, 552, 554, 556, 558
    A proximity vector: prox row 540 (+ every mask row with its random rho)
    A 256 opened columns: 256 pad symbols per row on the coset; 65,536 leaves salted
    H group 0 (zc F): 432-437     H group 1 (zc D): 438-443
    H group 2 (zsum point): 444-447
    H group 3 (the table point): 451,452, 461-468, 471,472, 475,476, 479,480, 483,484
    H group 4 (the value-0 LogUp sum): 444,445 (the zero-sum row u)
    H proximity vector: prox row 448
    H 256 opened columns: 256 pads per row on the coset; 65,536 leaves salted
    M (the mask commitment): 12 a-rows with 256 pads each, the zero-sum
      blinding row, the prox row; 256 opened columns of 4,096, salted

Against ZA's v2 form (A 26 claims / 5 groups, H 14 / 5): the same claim
STRUCTURE with more rows inside it — the six v3 table slots take 18
A rows and 36 H rows (v2's six took 12 and 24), because the INT16
class spans 4 rows and each of its four objects (m, mask, h_t re/im,
mask re/im) spans them too.

## The runs (12 x 512, `/usr/bin/time -v`, under `flock /tmp/zk-heavy.lock`, 3 runs each)

| run | PROVE (incl. the 4 commitments) | VERIFY | proof bytes | peak RSS | VRAM peak | proven MAC/s |
|---|---:|---:|---:|---:|---:|---:|
| CPU zk-v3 run 1 | 17.87 s | 0.41 s | 87,697,008 B | 1.26 GB | — | 1.62e9 |
| CPU zk-v3 run 2 | 18.41 s | 0.58 s | same | 1.28 GB | — | 1.58e9 |
| CPU zk-v3 run 3 | 18.64 s | 0.43 s | same | 1.27 GB | — | 1.56e9 |
| **CPU zk-v3 p50 of 3** | **18.41 s** | **0.43 s** | **87.7 MB** | **1.27 GB** | — | **1.58e9** |
| CPU v3 non-zk, this tree (15.58 / 16.13 / 15.76) | **15.76 s** | 0.29 s | 70,758,084 B | 1.21 GB | — | 1.84e9 |
| **CPU zk surcharge on v3** | **+2.65 s (+16.8%)** | **+0.14 s** | **+16.94 MB (+23.9%)** | **+5.0%** | | |
| GPU zk-v3 run 1 (`HL_GPU=1`) | 5.63 s | 0.44 s | 87,697,008 B | 0.53 GB | 4.44 GB | 5.15e9 |
| GPU zk-v3 run 2 | 4.63 s | 0.54 s | same | 0.52 GB | 4.44 GB | 6.27e9 |
| GPU zk-v3 run 3 | 6.15 s | 0.56 s | same | 0.54 GB | 4.44 GB | 4.72e9 |
| **GPU zk-v3 p50 of 3** | **5.63 s** (4.63-6.15) | **0.54 s** | **87.7 MB** | **0.53 GB** | **4.44 GB** | **5.15e9** |
| GPU v3 non-zk, this tree (3.04 / 2.75 / 2.63) | **2.75 s** | 0.31 s | 70,758,084 B | 0.42 GB | 2.43 GB | 1.05e10 |
| **GPU zk surcharge on v3** | **+2.88 s (+105%)** | **+0.23 s** | **+23.9%** | **+25%** | **+83%** | |

The CPU/GPU spread of the zk-v3 rows (4.63-6.15 s on the GPU) is the
box, not the prover: three other lanes were compiling and running
throughout (§ the header). The **bytes are exact and identical across
all six runs**.

## The comparison rows this rung was asked for (all on THIS tree, THIS session, same box state)

| row | CPU prove | GPU prove | proof bytes | source |
|---|---:|---:|---:|---|
| v2 non-zk (`pass 12 512`) | 15.16 s | 2.53 s | 66,844,928 | rung-2 gate re-run |
| v3 non-zk (`--profile v3`) | 15.76 s | 2.75 s | 70,758,084 | this rung |
| ZK v2 (`--zk`, lane ZA's form) | 17.42 s | 3.98 s | 87,228,528 | rung-2 gate re-run |
| **ZK v3 (`--zk --profile v3`, this lane)** | **18.41 s** | **5.63 s** | **87,697,008** | this rung |
| lane ZB's v3 record (quieter box) | 17.40 s | 2.74 s | 70,758,084 | results/hashline_v3_12x512.md |
| lane ZA's v2 ZK record (quieter box) | 16.55 s | 3.93 s | 87,228,528 | results/hashline_zk_12x512.md |

Read the four rows of this tree against each other (the outside
records agree within the box's noise):

- **the widened semantics cost, in the ZK form, what they cost in the
  clear**: zk-v3 over zk-v2 is +5.7% CPU and +0.54% BYTES
  (+468,480 B). The v3 statement is not more expensive to hide.
- **the ZK form costs +16.8% CPU / +23.9% bytes on v3** against
  +14.9% / +30.5% on v2 — the same class.
- **the GPU is the outlier: +105%.** One phase explains it.

## Prover phases (summed over the 12 layers, p50-class runs)

| phase | CPU zk-v3 | CPU v3 | GPU zk-v3 | GPU v3 | what the ZK form adds |
|---|---:|---:|---:|---:|---|
| commit W | 2.09 s | 2.15 s | 0.51 s | 0.55 s | nothing (public weights, as built) |
| commit A (zk) | 4.22 s | 3.74 s | 1.22 s | 0.91 s | 21 mask rows + 18 table/mask rows, the pads, the coset scaling, 65,536 salted leaves |
| mask commit | 0.09 s | — | 0.07 s | — | the six masking polynomials |
| helpers + commit H (zk) | 4.87 s | 4.69 s | 1.17 s | 0.44 s | 17 masks + 36 helper/mask rows (the INT16 helper alone is 16 rows) |
| matmul g/u (zk) | 0.31 s | 0.25 s | 0.17 s | 0.20 s | the masked claimed sum, the extension round, the masked terminals |
| matmul d (zk) | 0.18 s | 0.14 s | 0.12 s | 0.12 s | same |
| zero-check F (zk) | 2.83 s | 2.86 s | 0.41 s | 0.34 s | the mask through the transcript hook |
| zero-check D (zk) | 0.78 s | 0.83 s | 0.14 s | 0.10 s | same |
| **table zero-check (zk)** | **1.26 s** | — | **1.14 s** | — | **6 slots over 2^16 variables ON THE HOST** |
| zsum + mask open | 0.05 s | — | 0.04 s | — | the zero-sum sumcheck; the product-form test |
| pcs openings (zk) | 1.18 s | 0.90 s | 0.65 s | 0.33 s | the clear vectors, the pad folds, 63+ more rows in the opened columns, the salts |
| **PROVE** | **17.87 s** | **15.58 s** | **5.63 s** | **3.04 s** | |

**THE FINDING, and the lever.** The table zero-check runs on the HOST
(ZA built it there; a device port was listed as a lever and not
applied). In ZA's v2 form it is 6 tables x 3 rows of 2^14 and costs
0.24 s on the GPU. In the v3 form it is a sumcheck over **2^16**
variables — the INT16 class alone is 4 rows of m, 4 of its mask, 8 of
its F_{p^2} helper and 8 of that helper's mask — and costs **1.14 s**,
which is **20% of the whole GPU prover** and about **+0.90 s of the
+1.65 s** that zk-v3 costs over zk-v2 on the GPU (on the CPU the same
phase is 1.26 vs 0.40 s, +0.86 s of +0.99 s — the same absolute work,
invisible against a 15 s CPU baseline). Porting the table zero-check
to lane XX's device kernels is the single byte-preserving fix that
would put the GPU zk-v3 prover back at ~4.7 s. It is not applied here:
this rung's job was the composition and its gate.

## The tamper legs — ZB's eight v3 legs, under `--zk`, at T = 512, on both provers

`layer L 512 --zk --seed 1 --profile v3 --export ... --threads 8
--all-tampers`, run at **layer 0** (shifts g/u/h/z 9/1/14/10) and at
**layer 3** (8/-1/14/9 — the exact up-scaling branch, sh_u negative),
CPU and `HL_GPU=1`. **8/8 REJECT at both layers on both provers;
`layer N (v3) [ZK]: GREEN` four times.**

| leg | what the witness does | rejected by (identical CPU and GPU) |
|---|---|---|
| flipped X entry | X[777] += 1 | `sumcheck round 0: s(0) + s(1) != claim` (the g/u matmul) |
| flipped Wg entry | WgT[4242] += 1 | `sumcheck round 0` |
| out-of-range remainder | rg += 2^sh_g, g8 -= 1 (the identity kept) | `H: pcs zk: group 4: <v, c> != combined claim` |
| wrong int16 table entry | a16 += 1, the chain recomputed consistently | `H: pcs zk: group 4` |
| wrong requant (h16) | h16 += 1, rh unchanged | `sumcheck round 0` (zero-check F) |
| wrong z | z16 += 1 | `sumcheck round 0` (the d matmul) |
| wrong rounding (floor) | floor instead of round at the first element that rounds up, carried through | `H: pcs zk: group 4` |
| out-of-range int16 (z16) | z16 += 65536 with rd compensated | `H: pcs zk: group 4` |
| **pass-level**: `pass 12 512 --zk --seed 1 --profile v3 --tamper requant` (layer 6 of the 12-layer chained transcript) | | `layer 6: REJECT: sumcheck round 0`, CPU and GPU |

The split is exactly ZA's: the four LINEAR-identity legs die in a
sumcheck's round 0; the four LOOKUP legs die at **H group 4, the
value-0 LogUp sum claim** — the place where the ZK form put the
identity that the non-zk verifier checked in clear text against the
table. The two legs v3 adds over v2 (wrong rounding, out-of-range
int16) are both lookup legs, so both are caught there, and they are
caught at layer 3 as well as layer 0 — the negative-shift branch is
inside the masked form, not beside it.

## The 8B-width row: ONE Mistral-7B layer under `--zk --profile v3`

`layer 0 T --zk --seed 1 --profile v3 --export results/m8b_mistral_v3_export
--threads 8`, d 4096, f 14336, log_cols 14, statement shifts
11/2/15/6, member `silu-int16out-table-v3` (-3,-12) 859344ba5ed57bd3..
The box had 13 GB `available` at the start (below the 14 GB the brief
asked for), so the T = 256 pair was run first as the safe rung; T =
512 then fitted with 1.7 GB to spare and **no swapping** (Swaps: 0).

| row | PROVE | of which commit W | VERIFY | proof bytes | peak RSS |
|---|---:|---:|---:|---:|---:|
| **T = 512, ZK, CPU (p50 of 3: 18.67 / 15.14 / 15.73)** | **15.73 s** | 6.7-9.1 s | **0.056 s** | **40,186,228 B** | **13.29 GB** |
| T = 512, non-zk v3, CPU (p50 of 3: 15.40 / 14.65 / 15.02) | 15.02 s | 6.6-7.1 s | 0.038 s | 38,688,700 B | 13.17 GB |
| **T = 512 ZK surcharge at 8B width** | **+0.71 s (+4.7%)** | — | +0.018 s | **+1,497,528 B (+3.9%)** | **+0.12 GB (+0.9%)** |
| T = 512, ZK, `HL_GPU=1` (see below) | 17.01 s | 8.07 s | 0.053 s | 40,186,228 B | 10.13 GB |
| T = 256, ZK, CPU (1 run, a quiet moment) | 11.80 s | — | 0.046 s | 33,566,932 B | 10.40 GB |
| T = 256, non-zk v3, CPU (1 run) | 15.64 s | — | 0.045 s | 32,069,404 B | 10.28 GB |
| T = 256, non-zk v3, lane ZB's record | 14.51 s | 9.37 s | 0.031 s | 32,069,404 B | 10.28 GB |

ACCEPT on every row. (The T = 256 pair is one run each and the ZK one
landed in a quiet window — it is FASTER than its own baseline, which
is the box, not a discovery; the T = 512 triples are the pair to
read.)

**THE READING, and it is the important one of this lane.** At the 125M
shape the P1 ZK form costs +17% prover and +24% bytes. At the 8B width
it costs **+4.7% prover and +3.9% bytes** — inside
U_PERF3_ROUTE_B_THROUGHPUT.md's [COUNTED] +2-8% / +1-8% band that the
125M measurement had blown through. The reason is structural, not
lucky: **mode P1 hides the activations and leaves the weights public**,
and as the model widens the prover and the proof are dominated by the
weight commitment and its 256-column openings, which the ZK form does
not touch (commit W is 6.6-9.1 s of a 15 s prover; the W column
openings are ~22 MB of a 39 MB proof). The masked objects — the
activation planes, the six table slots, the sumcheck rounds — grow
with T x (d + f), not with d x f. **The P1 surcharge therefore shrinks
as the model grows**, and the 8B pass is where that matters.

Extrapolating the 32 x 512 pass on that ratio: the measured 510.4 s /
1,234.9 MB non-zk becomes **~534 s / ~1,283 MB in mode P1** [MODEL,
one-layer ratio x 32] — the 8B FFN proof is affordable in zero
knowledge on this laptop today.

**The GPU at the 8B shape.** `HL_GPU=1` DECLINES the weight commitment
exactly as lane ZB recorded for the non-zk path —

    [UPERF3-XX] gpu commit declined (cuMemAlloc(5376 MB):
    DriverError(CUDA_ERROR_OUT_OF_MEMORY, "out of memory")); CPU path

— and falls back to the host for W (8.07 s) while the ACTIVATION side
does run on the device (commit A 0.98 s vs 2.88 s on the host); the
two zero-checks stay on the host by design at this block shape (nb_f
7, nb_d 1). Net 17.01 s, no faster than CPU-only, with the same proof
bytes. **Lane AC's chunked/streamed W encoding is not in this lane's
base**, so this row is the "records whichever happens" case the brief
allowed: composing AC's chunked encoding with this ZK path is a
one-line base change and an untaken measurement.

## The soundness parameters (unchanged in kind from ZA's form)

inv_rate 4, n = 2^14, Q = 256 column checks, blake3 (256-bit) leaves,
F_{p^2} challenges (bias 2^-64 per draw). The ZK code is RS(n + Q, 4n)
on the coset (distance 0.7455 instead of 0.75): the column test's
(1 - delta/3)^Q is 2^-105.6 instead of 2^-106. The mask commitment is
RS(1024, 4096) on the coset with 256 column checks (2^-106). The
masked sumchecks are the same sumchecks over one more variable (degree
unchanged). The v3 additions do not move any of this: the multi-row
table slots are the SAME sumcheck over more variables (log_S = 16
instead of 14 at 12x512), the zero-extension is a public zero-padding
of a committed row, and the prod(1 - rho_j) coefficient is public data
the verifier recomputes. Field terms O(n / 2^128) as before.

## The uniformity test for the v3 sites (rung 1; `zk::zk_tests`)

A synthetic T=2 d=16 f=16 v3 layer with all six table slots present
(5,150 table/mask rows of n = 32 — every slot multi-row at that n, so
the multi-row path is what is tested), 8 proofs x 2 witnesses with
fresh pads, masks and salts per seed: all opened column entries and
clear-vector entries DISTINCT and none within 2^40 of 0 or p;
chi-square of the top byte against uniform at 256 bins 249.8 / 304.5 /
219.0 (critical 310.5 at p = 0.01, df 255); the two-sample chi-square
of the two witnesses 295.6 < 310.5 (their opened distributions are not
distinguishable by the statistic); the enumerated sites asserted at
every opening; 7 tamper legs reject. 28/28 crate tests green.

## Commands

    # CPU
    flock /tmp/zk-build.lock cargo build --release --manifest-path hashline/Cargo.toml
    hashline/target/release/hashline pass 12 512 --zk --seed 1 --profile v3 \
      --export results/m8b_test/m125_v3_export --threads 8 --proof-out /tmp/zkv3.bin
    # GPU (the README's CUDA_ROOT / LD_LIBRARY_PATH / CARGO_TARGET_DIR recipe), then
    HL_GPU=1 ... hashline/target-gpu/release/hashline pass 12 512 --zk --seed 1 \
      --profile v3 --export results/m8b_test/m125_v3_export --threads 8 --proof-out /tmp/zkv3_gpu.bin
    # the eight legs, at layer 0 and at layer 3 (the negative-shift branch)
    ... hashline layer 0 512 --zk --seed 1 --profile v3 --export ... --all-tampers
    # the 8B-width layer
    ... hashline layer 0 512 --zk --seed 1 --profile v3 \
      --export results/m8b_mistral_v3_export --threads 8
    # the v3 uniformity test
    cargo test --release --manifest-path hashline/Cargo.toml zk_v3 -- --nocapture

## What mode P1 now covers, and what it does not

COVERS, at the 8B semantics, measured: one FFN layer and a 12-layer
FFN pass of the widened (v3) statement — the statement the 8B proof
runs — with the inputs and every activation private, on a laptop CPU
and (at the 125M shape) byte-identically on the laptop GPU.

DOES NOT COVER, and none of it is hidden by this rung:
- **the weights** (mode P1 by definition; P2/P3 is T18);
- **attention, the norms, the embeddings, the head and the layer
  seams** — the statement is FFN-only, X_l committed fresh per layer
  (lane AE's build);
- **the shapes, the four signed shifts, the table digests and the
  table SIZES** — public statement data, and the shifts publish the
  remainder windows;
- **a written simulator** for the composition of the chained layers
  under one Fiat-Shamir transcript (ZA's caveat, inherited).
