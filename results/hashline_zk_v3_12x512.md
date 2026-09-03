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

