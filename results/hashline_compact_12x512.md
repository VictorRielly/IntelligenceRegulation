# hashline with a compact PCS — the 12x512 row and the 8B projection (U-PERF3 lane AF, 2026-09-03)

The measured record behind the compact-PCS row in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3, in the form of
lane XX's results/hashline_gpu_12x512.md (the GPU row it sits next to).
Every number here is [MEASURED] on the WSL laptop (Core Ultra 9 185H,
22 threads, 15 GB), 8 rayon threads, CPU only, label
[WSL-BOX 8T CPU NOISY-SHARED] — lanes AC, AD and AE were building and
running on the box throughout; every pass-level and layer-level run was
taken under `flock /tmp/zk-heavy.lock`, and both sides of every
comparison were taken the same way. Commits: see PROGRESS_UPERF3.md
"Agent AF status" (rungs 0-5, `ade2b7f` .. the rung-5 commit).

## What changed, and what did not

Nothing about the STATEMENT changed. The same 125M FFN pass (12 layers
x 512 tokens, T 512, d 768, f 2048), the same exact int8 semantics, the
same witness (`results/m125_ffn_export_wsl`), the same 2.899e10 MACs;
and for the 8B row the same Mistral-7B FFN layer (d 4096, f 14336) from
`m8b_mistral_v3_export`. The same matmul sumchecks, the same LogUp
lookups with committed helpers, the same two zero-checks, the same
blake3 Fiat-Shamir over one transcript.

What changed is the POLYNOMIAL COMMITMENT underneath, behind a new
`--pcs compact` flag. The default is `--pcs ligero` and is byte-identical
to everything that came before: the three byte gates
(`50cf7bdfd6b5b182..` v2, `5f368db6240e0614..` v3, `021485e4f80ec695..`
zk at seed 1) were re-run on this binary before every commit that
touched Rust and are green.

## The construction

A **BaseFold-class** commitment (Zeilberger-Chen-Fisch, ePrint
2023/1705 [EXTERNAL]): a batched-evaluation SUMCHECK whose round
challenges simultaneously drive a **FRI fold** of the Reed-Solomon
codeword of the same polynomial.

- A committed vector of N base-field values is the Lagrange table of a
  multilinear `f` in `k = ceil(log2 N)` variables (variable `j` = bit
  `j` of the index, least significant folded first). N is cut into at
  most 3 power-of-two PIECES — committed lengths here are not powers of
  two (a 125M layer's W is `9 x 2^19`; a Mistral layer's is
  `2^27 + 2^25 + 2^23`), and a piece may run past N with zeros that no
  claim ever weights.
- Each piece is Mobius-transformed to coefficient form, read as a
  univariate, and RS-encoded at rate 1/4 by one decimation-in-frequency
  NTT. That NTT's output is BIT-REVERSED, which is the point: the 16
  positions that fold together over four rounds are then one contiguous
  block, so a Merkle leaf is exactly a fold coset. Pieces of the same
  size share a tree; the commitment root is the blake3 of the per-size
  roots.
- **One opening per LAYER, over W, A and H together.** Every claim this
  prover makes is a linear functional `<f, w_c>` — `eq(point)` on an
  aligned slice, or the constant 1 on a slice for the LogUp helper sums
  — so a random `lambda`-combination of them is another linear
  functional, and the whole batch is one degree-2 sumcheck
  `sum_p sum_b f_p(b) g_p(b)`. `g_p` is never materialised at full
  size: it is a sum over distinct eq tables `E_t` of
  `sel_t[b >> s_t] * E_t[b mod 2^s_t]`, and LSB-first folding collapses
  each `E_t` only when its arity runs out. A slice that is unaligned or
  crosses a piece boundary is split recursively.
- A piece with `k_p < k_max` joins at round `k_max - k_p` (its round
  message before that is the affine pair `(beta S_p, 0, -beta S_p)`),
  and its codeword joins the running `R = sum_p mu_p Enc(f_p)` at the
  round where the domains coincide. Every 4th round the prover commits
  `Enc(folded R)`; at `2^k_end` coefficients the final polynomial goes
  in the clear; then `f_p(r)` per piece. The verifier checks the
  sumcheck terminal, the final polynomial against `sum_p mu_p f_p(r)`,
  and runs `Q` query walks against the fold trees.

**Parameters.** `inv_rate 4`, `target_bits 106`, `Q = 157` (derived),
`log_final 7`, `max_pieces 3`, fold-by-16. All settable:
`--pcs-inv-rate`, `--pcs-queries`, `--pcs-bits`, `--pcs-log-final`,
`--pcs-pieces`, `--pcs-reencode`.

**Soundness, per proof.** Query term `(1 - delta)^Q` at the
unique-decoding radius `delta = (1 - 1/inv_rate)/2 = 3/8`:
`(5/8)^157 = 2^-106.45`, meeting the Ligero form's `2^-106`. Fold and
batching field terms `~(k_max + pieces) L_0 / |F_{p^2}|`: `2^-98.2` at
12x512 (`L_0 = 2^25`) and `2^-95.1` at the 8B shape (`L_0 = 2^28`).
Sumcheck `2 k_max / |F_{p^2}| < 2^-122`. **Total `2^-98.2` / `2^-95.1`
— 3 to 11 bits BELOW the Ligero form's `2^-106`**, because Ligero's
proximity test pays no per-round affine-line term. That margin is
recovered by a bigger field (a degree-3 extension) or smaller pieces,
NOT by more queries, and the record does not pretend otherwise. The
list-decoding (Johnson) regime would halve `Q` but its field term is
`~L^2/|F| = 2^-64` at `L = 2^24` over `F_{p^2}` — unusable at this
field, which is why the construction stays inside unique decoding.

## The rows

### 125M, 12 x 512 (`hashline pass 12 512 [--profile v3] --pcs compact --threads 8`)

| statement | form | proof bytes | prove | verify | peak RSS | sha256 |
|---|---|---:|---:|---:|---:|---|
| v2 | Ligero (default) | 66,844,928 (66.8 MB) | 15.40 s | 0.30 s | 1.56 GB | `50cf7bdf..` |
| v2 | **compact** | **13,487,744 (13.5 MB)** | 28.76 s | **0.01 s** | 1.78 GB | `f84432ea..` |
| v2 | compact, `--pcs-inv-rate 8` (Q 128) | 11,518,208 (11.5 MB) | 47.93 s | 0.02 s | — | `3c02420b..` |
| v2 | compact, `--pcs-reencode` | 13,487,744 (identical) | 40.24 s | 0.01 s | 1.62 GB | `f84432ea..` |
| v3 | Ligero (default) | 70,758,084 (70.8 MB) | 16.48 s | 0.30 s | 1.58 GB | `5f368db6..` |
| v3 | **compact** | **17,400,900 (17.4 MB)** | 29.92 s | **0.03 s** | 1.80 GB | `621c2633..` |

**4.96x smaller at v2, 4.07x at v3, at 1.8-2.1x the prover and a
10-15x FASTER verifier.**

The v3-over-v2 surcharge is `3,913,156 B` under Ligero and
`3,913,156 B` under compact — the same number to the byte. It is
entirely the committed multiplicity vectors, which no polynomial
commitment touches; the compact opening itself is the same size in v2
and v3.

### 8B, one Mistral-7B FFN layer at T = 512 (`hashline layer 0 512 --profile v3 --export .../m8b_mistral_v3_export`)

| form | proof bytes (one layer) | prove | verify | peak RSS |
|---|---:|---:|---:|---:|
| Ligero (default) | 38,688,700 (38.7 MB) | 15.497 s | 0.041 s | 13.17 GB |
| **compact** (`--pcs-reencode`) | **1,940,684 (1.94 MB)** | 67.593 s | **0.010 s** | 13.92 GB |

**19.94x smaller.** Both ACCEPT.

### The 32 x 512 projection [COUNTED from a MEASURED layer]

The measured Ligero layer (38,688,700 B) matches the measured 32x512
pass's per-layer average (`1,234,936,956 / 32 = 38,591,780 B`) to
0.25%, and every layer of the pass has the same shape.

| 8B FFN pass, 32 x 512 | Ligero [MEASURED] | compact [COUNTED] |
|---|---:|---:|
| proof bytes | 1,234,936,956 (1.235 GB) | **62,101,888 (62.1 MB)** |
| prove | 510.38 s | ~2,163 s (4.24x) |
| verify | 1.21 s | ~0.3 s |
| peak RSS | 13.99 GB | ~13.9 GB |

## Why 19.9x at 8B and only 5x at 125M

This is the square-root law showing itself, and it is the whole reason
the lane exists. The Ligero opening grows as `sqrt(N)`: from a `2^23`
commitment to a `2^27` one it grows about 4x. The compact opening grows
LOGARITHMICALLY: 1.11 MB at `k_max = 23` becomes ~1.9 MB at
`k_max = 27` — four more Merkle levels per tree, and nothing else. The
bigger the model, the bigger the win. The 1.23 GB per-proof number that
made the 8B row awkward becomes 62 MB.

A second, independent effect drives the 125M row: **the compact
opening's size does not depend on the claim count.** Measured alone
(`hashline pcs-bench 14 20`), the opening is 162,588 B at `2^14` and
383,228 B at `2^20` for ONE claim and, to the byte, the same for EIGHT;
the Ligero opening pays a fresh `group_vec` of `rows` field elements
per distinct column-weight group and grows from 659 KB to 2.49 MB over
the same span. A layer here has 37 claims across three commitments, and
the compact form answers all of them with one sumcheck.

## Prover phases (12 x 512 v2, summed over the 12 layers)

| phase | Ligero | compact | delta |
|---|---:|---:|---|
| commit W | 2.009 s | 3.659 s | +82% |
| commit A | 3.626 s | 7.553 s | +108% |
| helpers + commit H | 4.438 s | 7.358 s | +66% |
| matmul g/u | 0.226 s | 0.241 s | = |
| matmul d | 0.142 s | 0.151 s | = |
| zero-check 20 | 3.141 s | 3.105 s | = |
| zero-check 17 | 0.912 s | 0.906 s | = |
| PCS openings | 0.880 s | 8.793 s | 10.0x |
| **PROVE** | **15.40 s** | **31.78 s** | **2.06x** |

(The 31.78 s row is the pre-fix measurement kept for phase
attribution; the borrow fix below took the same proof to 28.76 s.)

The commit slowdown is STRUCTURAL, not a bug: Ligero encodes each
`2^14`-column row independently (`4N log 4n` butterflies), the compact
form encodes the whole vector as ONE polynomial (`4N log 4N`, 1.56x the
butterflies at `N = 2^23`) and pays a Mobius transform on top. That is
the price of having a single low-degree codeword to fold. The opening
is 10x slower because it IS a full sumcheck over the combined table
plus a re-encode per fold stretch, where Ligero's opening is a handful
of row-combinations.

## Against the count, plainly

`U_PERF3_ROUTE_B_THROUGHPUT.md` §5 counted the trade at **x0.94-1.4
prover for 3-12 MB per pass**. What was built lands at **x2.06 prover
for 13.5 MB at 125M** and **x4.36 for 1.94 MB per layer at 8B** —
outside the count on both axes. The bytes side is close and has a known
way in (below); the prover side is not close, and three quarters of the
excess at 8B is the opening.

## The two levers left, counted not measured

1. **A Merkle CAP.** Per layer at 12x512 the batched opening is
   1,113,888 B of the layer's 1,127,136 B (98.8%), and roughly half of
   that is Merkle path digests — about 110 levels x 32 B across ~10
   trees, times `Q = 157`. Truncating every tree at a fixed level and
   sending that level once per proof removes `8 x 10 x 32 x 157 =
   402 KB` per layer and adds `10 x 256 x 32 = 82 KB`: a net **-29%**,
   i.e. **13.5 MB -> ~9.6 MB at 125M and 62 MB -> ~44 MB at 8B
   [COUNTED]**, at zero soundness cost and zero prover cost. Not
   implemented in this lane. It is the first thing to do next.
2. **The rate knob, measured and NOT recommended.**
   `--pcs-inv-rate 8` (rate 1/8, `delta = 7/16`, `Q = 128` for the same
   106 bits: `(9/16)^128 = 2^-106.2`) gives 11.5 MB — inside the
   counted band — but at 47.93 s prove: **-15% bytes for +51% prove**.
   `inv_rate 4` stays the operating point.

## The memory wall at 8B, and the two fixes this lane made

Ligero's Merkle tree has only `enc_cols = 2^16` leaves however large
the commitment is — it hashes COLUMNS of a `rows x enc_cols` matrix.
The compact tree has `L/16` leaves, which at `L = 2^29` (a Mistral
layer's W) is 33.5M leaves, about 1.4 GB of tree for W alone. Holding
the codewords resident on top of that (5.64 GB for W, ~10 GB across
W/A/H) puts one layer at ~15.4 GB [COUNTED] on a 15 GB box: OOM.

Two changes made the 8B layer measurable:

- **The query phase no longer clones resident codewords.**
  `group_codewords` returned `g.codewords.clone()` — a full copy of
  every commitment's codeword at the moment of peak use. At 12x512 that
  is ~270 MB; at 8B it is gigabytes. [MEASURED] 12x512 v2 compact peak
  RSS 2.23 -> 1.78 GB and prove 31.78 -> 28.76 s, proof `f84432ea..`
  unchanged to the byte.
- **The query phase runs one GROUP at a time, not one QUERY at a
  time**, so under `--pcs-reencode` only one codeword is ever
  materialised. Byte-identical with and without the flag.

With `--pcs-reencode` the 8B layer peaks at 13.92 GB against Ligero's
13.17 GB (+6%). About 16 s of the 38.8 s opening phase is the re-encode
that flag forces; on a box with ~20 GB the resident path would prove
the layer in ~52 s [COUNTED], i.e. ~1,654 s / 3.24x for the 32x512
pass.

## Tamper legs — all REJECT

| leg | where |
|---|---|
| **The PCS alone** (`pcs-bench`, every size 2^14..2^20) | |
| a wrong claimed evaluation | sumcheck round 0: `s(0) + s(1) != claim` |
| a corrupted opening value | Merkle path fails |
| a swapped Merkle path | Merkle path fails |
| a corrupted fold leaf (unit test) | fold tree Merkle path fails |
| a corrupted round message (unit test) | sumcheck round check |
| a corrupted terminal (unit test) | sumcheck terminal check |
| a corrupted final polynomial (unit test) | final polynomial vs the mu-combination |
| an honest opening of a DIFFERENT witness, vs both commitments (unit test) | rejects both ways |
| **The v2 statement** (`layer 0 512 --pcs compact --all-tampers`) — 6/6 | |
| flipped X entry; flipped Wg entry | matmul sumcheck round 0 |
| out-of-range remainder; wrong table entry | LogUp identity fails |
| wrong requant (h8) | zero-check round 0 |
| wrong z | matmul sumcheck round 0 |
| **The v3 statement** (`--profile v3 --pcs compact --all-tampers`) — 8/8 | |
| flipped X; flipped Wg; wrong requant (h16); wrong z | matmul / zero-check round 0 |
| out-of-range remainder; wrong int16 table entry; wrong rounding (floor); out-of-range int16 (z16) | LogUp identity fails |

Same sites as the Ligero path in every case. The compact opening never
masks a statement tamper: the claims it answers are the same claims.

## GPU: not ported, and exactly what a port needs

The device module's NTT kernels (`k_ntt_p1`/`k_ntt_p2`,
`k_dif_pa`/`k_dif_pb`, `k_dit_p1_pad`) are built for the Ligero
LAYOUT — a batch of `rows` independent transforms of `2^log_cols`
each, twiddles stage-major — and `k_hash_cols` hashes one blake3 leaf
per COLUMN of that matrix. The compact form needs:

1. a SINGLE transform of up to `2^29` elements in the DIF
   bit-reversed output order this module's `ntt_dif` produces. The
   existing `k_dif_pa`/`k_dif_pb` pair is the right shape but is sized
   for one row; it needs the strided multi-block tail stages that
   `k_ntt_p2` already has.
2. a blake3 kernel over 16-symbol CONTIGUOUS blocks instead of strided
   columns — `k_hash_cols`'s gather is the only part that changes.
3. a Mobius-transform kernel (a `k`-pass in-place kernel, trivial).
4. a sumcheck round kernel for the `f * g` product where `g` is the
   selector/eq-table structure of this module's `GTab` list.
   `k_sc_round_zc20` is the closest existing kernel, but its `g` is a
   fixed table set.

(1)-(3) are a day. (4) is the real work, and it is where 8.8 of the
31.8 s (and 38.8 of the 67.6 s at 8B) sit. Nothing in the port changes
a byte of the proof, exactly as in lane XX's row.

## THE ZK INTERACTION

**The compact form as built is NOT hiding, and the driver refuses
`--pcs compact --zk` with a message rather than producing a proof that
looks private and is not.** Lane ZA's `--zk` path (mode P1: activations
private, weights public) still works, unchanged and byte-identical
(`021485e4..`), on the Ligero form.

### What of ZA's construction survives, device by device

- **PAD ROWS — do NOT survive.** ZA's pads are per-ROW: each row's
  message polynomial becomes `f_data + Z_n g_pad` with `Q` fresh random
  coefficients, and the evaluation domain moves to a coset `h G_{4n}`
  disjoint from `G_n` so that no opened position is systematic and any
  `Q` opened COLUMNS are jointly uniform. The compact form has no rows
  and no systematic positions — it encodes the coefficient form of one
  polynomial over the whole domain — so both halves of the device are
  meaningless here. The coset trick is not NEEDED (no position is
  systematic already); the randomness still is.
- **MASK ROWS — do NOT survive, and what they hid is now exposed
  differently.** ZA's mask rows hide `T~(rho)`, the private table's
  evaluation at the opening point, by opening a combined value instead.
  The compact opening has no row openings at all. What it does reveal,
  and what a ZK version must therefore cover, is four distinct
  surfaces: (i) `terminals` — `f_p(r)` for each piece, i.e. exactly the
  evaluation the mask rows existed to hide; (ii) `final_coeffs` — the
  `2^k_end = 128` coefficients of the fully folded polynomial, each a
  linear functional of the witness; (iii) `rounds` — 3 `F_{p^2}` values
  per round over 23-27 rounds, the sumcheck partial sums; (iv) the
  query cosets — `157 x 16` codeword symbols per group, each a linear
  functional of the data. ZA's "every opening site carries a mask"
  assertion is checked against Ligero's opening sites and does not
  transfer; it would have to be re-derived for these four.
- **CFS-masked sumchecks and the last-round extension — SURVIVE, and
  are the right tool.** The batched opening is a sumcheck like any
  other, and `sumcheck.rs`'s masking machinery applies to it directly.
  The one catch specific to BaseFold: the mask must ALSO be carried by
  the FRI fold, or the codeword and the sumcheck decouple and the query
  walks stop closing. The clean way is to commit the mask as one more
  PIECE of the same batch, so the same `mu`-combination and the same
  challenges fold it along with everything else.
- **SALTED LEAVES — survive verbatim.** `leaf = blake3(blake3(block) ||
  salt)` is one line in `group_leaf_hash` and `hash_fp2_block`, and it
  is needed: the compact trees are currently unsalted, so identical
  cosets hash identically and that is itself a leak.
- **COMMITTED MULTIPLICITIES — survive unchanged.** They are a
  statement-side device, not a PCS-side one. Rung 3 measured this: the
  multiplicity bytes pass through the compact form identically, to the
  byte.

### What a ZK-compact form needs, concretely

1. **Randomness in extra multilinear VARIABLES, not in pad rows.**
   Commit `f` extended by `c` extra variables carrying uniformly random
   values (equivalently: one extra random PIECE of size `2^c` in the
   batch, `c ~ log Q`). The folded object stays a multilinear encoding,
   so the FRI fold still closes — which is precisely what a naive
   `P(Y) + Y^{2^k} R(Y)` pad would break.
2. **The CFS mask on the batched opening sumcheck**, committed as a
   piece of the same batch so the fold carries it. This covers surfaces
   (i) and (iii) above, and — because `final_coeffs` is then a
   combination that includes the mask — surface (ii) as well.
3. **Salted leaves** on the group trees and the fold trees, covering
   surface (iv) together with (1).
4. **A re-derived query count**, because the added randomness changes
   the effective rate slightly, and a re-derived field term, because
   the extra piece raises `pieces` in the `(k_max + pieces) L_0 / |F|`
   bound.

The counted cost is the same shape as ZA's: bytes up by the extra
piece's share of the queries (a few percent, since the extra piece is
tiny and joins late), prover up by one more piece in the sumcheck and
one more mask commitment. None of it is built here; this section is the
specification, not a claim.

## Caveats — every one of the B row's, unchanged

FFN-only: no attention, no norms, no layer seams (`X_l` committed
fresh). X and weight ranges declared, not range-proven. The prover
clock includes the per-layer commitments (weights recommitted every
proof). Witness derivation is outside the clock. NOT zero-knowledge
under `--pcs compact` (see above), and the soundness total is
`2^-98.2` / `2^-95.1`, below the Ligero form's `2^-106`. No GPU code
for this PCS. Untuned single-lane Rust. The walls are
[NOISY-SHARED]: three sibling lanes were active on the box, and both
sides of every comparison were taken under the same lock to keep the
comparison honest rather than to make the numbers pretty.

## Postscript: the compact form on the gpu-cuda binary

`--pcs compact` under `HL_GPU=1` on the `gpu-cuda` binary produces
`f84432ea..` — byte-identical to the CPU-only binary's compact proof —
at PROVE 34.96 s, which is SLOWER than the CPU-only 28.76 s. A compact
commitment is never device-resident (`dev_of` returns `None` for it),
so the device helper and commit paths decline and the GPU contributes
nothing while the process still pays for the CUDA context. **There is
no GPU benefit for the compact form until the four kernels above
exist.** That matters more than it looks: the Ligero form on the GPU
proves the same pass in 2.50 s. Today the choice is 2.50 s / 66.8 MB
(GPU + Ligero) or 28.76 s / 13.5 MB (CPU + compact) — the size win and
the speed win do not yet compose, and making them compose is item (2)
on this lane's list.
