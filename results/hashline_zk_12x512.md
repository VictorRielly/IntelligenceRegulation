# hashline `--zk` — the zero-knowledge form for the activations, the 12x512 row (U-PERF3 lane ZA, 2026-09-02)

The measured record behind the ZK row in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3, in the form of
lane XX's results/hashline_gpu_12x512.md (the non-zk GPU row it sits
next to). Every number here is [MEASURED] on the WSL laptop (Core
Ultra 9 185H, 22 threads, 15 GB; RTX 4070 Laptop GPU, sm_89, 8 GB,
55-70 W), 8 rayon threads (+ the device on the GPU rows), label
[WSL-BOX 8T NOISY-SHARED] (lane ZB built and ran on the box during
the session). Commits: rungs 0-5 in PROGRESS_UPERF3.md "Agent ZA
status" (3556173, e7d546e, b6d5e05, 4f3ce56, 3501135, the rung-5
commit). Design: hashline/src/zk.rs (the module doc is the plan).

## What was proven, and what is now hidden

THE SAME statement and THE SAME witness as lanes UU/XX: the 125M FFN
pass, 12 layers x 512 tokens, exact int8 semantics, the WSL re-export,
2.899e10 MACs per pass, the same soundness parameters (Goldilocks +
F_{p^2} challenges; Ligero/Brakedown PCS at RS rate 1/4, n = 2^14
columns, Q = 256 column checks; the matmul sumchecks; LogUp; the two
zero-checks; blake3 Fiat-Shamir, one transcript over the 12 layers) —
in MODE P1 of TARGET_CONTRACT Amendment A1: the inputs and activations
are private, the weights are public (the W commitment and its
opening are exactly the non-zk ones).

HIDDEN under `--zk` (each of section 4.1 of U_PERF3_ROUTE_B_THROUGHPUT.md,
closed):
- the opened columns of A and H (256 per commitment per layer): every
  row carries Q = 256 random pad symbols (f_data + Z_n g_pad) and is
  evaluated on the coset 7 G_{4n}, so no opened position is
  systematic and any 256 opened positions are jointly uniform;
- the clear row-combination vectors of A and H (5 + 5 per layer):
  every one touches at least one fresh uniformly random mask row
  (asserted at run time at every site; the proximity vector has its
  own mask row);
- the multiplicity tables: committed in A (before alpha) with their
  own masks; their LogUp table side is a committed helper row of H;
  the identity is one value-0 sum claim on H (masked by a proven
  zero-sum row); no histogram and no helper sum is sent;
- the sumcheck round messages (gu, d, zc20, zc17, the table
  zero-check, the zero-sum sumcheck): masked by a committed
  Chiesa-Forbes-Spooner polynomial per sumcheck, folded in with a
  verifier challenge;
- the matmul claimed sums and every terminal evaluation of a private
  table (10 + 12 + 3 + 1 + 12 + 1 per layer): sent MASKED — the
  claimed sums as S + c G, the terminals as (1 - rho_k) T~ + rho_k R~
  through the last-round extension — so the verifier never sees an
  evaluation of the activations;
- the Merkle leaves: salted (blake3(blake3(col) || salt)).

STILL REVEALED (by the mode, or by construction): the weights and
everything of the W commitment (its 256 opened columns and 3 clear
vectors per layer — public in P1); the shapes, the four shifts, the
table digest; the masked values above (uniform); the mask
commitment's opening (uniform: the mask rows have their own pads, the
product polynomial is blinded by a zero-sum row). The composition of
12 chained layers under one Fiat-Shamir transcript is owed a written
simulator (the same caveat class as the lattice line's lemmas
Q4.7-Q4.9): what is established in code is that every opened object
is uniform given the public data and the previous transcript, per
sub-protocol; a full proof would compose the per-object simulators
in transcript order and argue the ROM programming for the salted
leaves and the derived challenges.

## THE GATE: parity, and the non-zk identity

`pass 12 512 --threads 8 --zk --seed 1 --proof-out <f>` writes
87,228,528 B with

    sha256 021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d

from the CPU-only binary (3 runs) AND from the gpu-cuda binary with
`HL_GPU=1` (4 runs). At 3x16 (`--zk --seed 1`): f9509b9df7e7b747..
(9,509,916 B) from both. Seed 2 gives a different proof of the same
statement. The non-zk path on the same final binaries is unchanged:
12x512 50cf7bdfd6b5b182.. (66,844,928 B) CPU and GPU, 3x16
596b9c79f086d6f1.. — the byte-identity gate of every rung.

## The runs (12 x 512, `/usr/bin/time -v`, under flock /tmp/zk-heavy.lock)

| run | PROVE (incl. the 4 commitments) | VERIFY | proof bytes | peak RSS | VRAM held | proven MAC/s |
|---|---:|---:|---:|---:|---:|---:|
| GPU zk run 1 | 3.87 s | 0.37 s | 87,228,528 B | 904 MB | 3.03 GB | 7.49e9 |
| GPU zk run 2 | 3.94 s | 0.38 s | same | 906 MB | 3.03 GB | 7.36e9 |
| GPU zk run 3 | 3.92 s | 0.39 s | same | 905 MB | 3.03 GB | 7.40e9 |
| GPU zk run 4 | 4.10 s | 0.40 s | same | 905 MB | 3.03 GB | 7.07e9 |
| **GPU zk p50 of 4** | **3.93 s** | **0.38 s** | **87.2 MB** | **0.90 GB** | **3.03 GB** | **7.4e9** |
| GPU non-zk, this tree, 5 runs | 2.46 s p50 (2.40-2.48) | 0.25-0.29 s | 66,844,928 B | 775 MB | 2.43 GB | 1.2e10 |
| **GPU surcharge** | **+1.47 s (+60%)** | **+0.12 s** | **+20.4 MB (+30.5%)** | **+16%** | **+25%** | |
| CPU zk run 1 | 16.52 s | 0.45 s | 87,228,528 B | 1.67 GB | — | 1.75e9 |
| CPU zk run 2 | 16.55 s | 0.50 s | same | 1.68 GB | — | 1.75e9 |
| CPU zk run 3 | 16.65 s | 0.44 s | same | 1.68 GB | — | 1.74e9 |
| **CPU zk p50 of 3** | **16.55 s** | **0.45 s** | **87.2 MB** | **1.68 GB** | — | **1.75e9** |
| CPU non-zk, this tree, 3 runs | 14.78 s p50 (14.70-14.82) | 0.27-0.28 s | 66,844,928 B | 1.56 GB | — | 1.96e9 |
| **CPU surcharge** | **+1.77 s (+12%)** | **+0.18 s** | **+30.5%** | **+8%** | | |

3x16 (GPU, 4 runs each): zk 0.36 s p50 (0.34-0.41) vs non-zk 0.28 s
(0.23-0.31); 9,509,916 vs 7,365,588 B; RSS 0.33 vs 0.33 GB; VRAM 1.49
vs 1.46 GB.

The non-zk rows are this tree's: lane ZA's single-thread path for
small sumcheck rounds (byte-identical) moved the non-zk CPU prover
from 16.9 to 14.8 s and the GPU prover from 2.76-2.88 to 2.46 s
against XX's 3.40 s record; the surcharges are measured against the
faster baseline.

## Prover phases (summed over the 12 layers, p50 runs)

| phase | GPU zk | GPU non-zk | CPU zk | CPU non-zk | what the zk form adds |
|---|---:|---:|---:|---:|---|
| commit W | 0.47 s | 0.34 s | 2.01 s | 1.97 s | nothing (public weights, as built) |
| commit A (zk) | 1.09 s | 0.78 s | 4.13 s | 3.65 s | +26 mask/table rows, the pads, the coset scaling, the gather-form NTT on the device, 65,536 salted leaves |
| mask commit | 0.07 s | — | 0.08 s | — | the six masking polynomials (14 base rows on 4,096 columns) |
| helpers + commit H (zk) | 0.84 s | 0.42 s | 4.78 s | 4.27 s | +37 rows (12 Fp2 masks, u, u', prox, six table helpers with masks), the tail upload on the device |
| matmul g/u (zk) | 0.11 s | 0.12 s | 0.24 s | 0.22 s | the masked claimed sum, the extension round, 3 masked terminals |
| matmul d (zk) | 0.09 s | 0.09 s | 0.14 s | 0.12 s | same |
| zero-check 20 (zk) | 0.36 s | 0.34 s | 2.97 s | 2.95 s | the mask through the transcript hook; 10 masked terminals |
| zero-check 17 (zk) | 0.12 s | 0.10 s | 0.74 s | 0.78 s | same, 12 terminals |
| table zero-check (zk) | 0.24 s | — | 0.40 s | — | 6 tables x 3 rows of 2^14 on the host (a device port would remove ~0.2 s) |
| zsum + mask open | 0.04 s | — | 0.04 s | — | the zero-sum sumcheck; the product-form test of 10 functionals |
| pcs openings (zk) | 0.43 s | 0.24 s | 0.98 s | 0.83 s | 5 + 5 clear vectors of 16,640 Fp2, the pad folds, 63 more rows in the opened columns, the salts |

Device-side sums on the GPU zk p50: h2d 0.25 s (1,425 MB), NTT 0.58
s (non-zk 0.43), hash 0.12, sumcheck 0.44, fold 0.20 (0.16), helpers
0.09. The remaining host work of the zk form: the seeded randomness
(~25 MB of blake3 XOF per layer), the leaf salting, the mask
evaluations and the two host sumchecks.

## The soundness parameters (unchanged in kind)

inv_rate 4, n = 2^14, Q = 256 column checks, blake3 (256-bit) leaves,
F_{p^2} challenges (bias 2^-64 per draw). The ZK code is RS(n + Q, 4n)
on the coset (distance 0.7455 instead of 0.75): the column test's
(1 - delta/3)^Q is 2^-105.6 instead of 2^-106. The mask commitment is
RS(1024, 4096) on the coset with 256 column checks (2^-106). The
masked sumchecks are the same sumchecks over one more variable
(degree unchanged); the masked claimed sums and Gammas are linear
functionals of committed rows, bound by the mask opening. Field
terms O(n / 2^128) as before.

## The uniformity test (in code: `pcs::zk_tests::zk_openings_are_uniform_and_every_site_is_masked`)

Two witnesses of int8 values, 40 independent openings each (fresh
pads, masks and salts per seed), the same claim structure (a private
16-row slice opened through the combined masked claim, a private
sub-row slice with its own mask, a value-0 sum claim over a zero-sum
mask row, a proximity mask row): all 37,000+ opened column entries
and clear-vector entries are DISTINCT and none lies within 2^40 of 0
or p; the chi-square of the top byte against uniform at 256 bins is
275.6 / 259.0 (columns, witness A / B) and 293.0 / 235.7 (clear
vectors) over ~9K values each (critical 310.5 at p = 0.01, df 255);
the two-sample chi-square A vs B is 253.3 (the two witnesses' opened
distributions are not distinguishable by the statistic); the
enumerated sites are asserted at every opening. The contrast: the
NON-zk commitment of the same data opens 42 raw int8 values among
its 252 opened entries (its systematic columns).

THE ENUMERATED SITES of the 12x512 pass (printed by the driver; every
layer identical in structure; the assertion `pcs::assert_mask_sites`
runs at every `open_zk`):

    A: 26 claims in 5 groups
    A group vector 0 (zc20 point): mask rows 520-526       (g8 rg a8 u8 ru h8 rh)
    A group vector 1 (zc17 point): mask rows 527-535       (x_b z_b rd_b)
    A group vector 2 (gu terminals at p2): mask rows 536-538
    A group vector 3 (d terminal at p5): mask row 539
    A group vector 4 (table point): mask rows 542,544,..,552 (the 6 histogram rows' masks)
    A proximity vector: prox mask row 540 (+ every mask row with its random rho)
    A 256 opened columns: 256 pad symbols per row on the coset (no systematic position)
    A 65,536 Merkle leaves salted
    H group vector 0 (zc20): mask rows 432-437 (hg hu hh, re/im)
    H group vector 1 (zc17): mask rows 438-443 (hz_b, re/im)
    H group vector 2 (zsum point): mask rows 444-447 (u, u')
    H group vector 3 (table point): the 6 table helpers' Fp2 masks
    H group vector 4 (the value-0 LogUp sum): mask rows 444-445 (the zero-sum row u)
    H proximity vector: prox mask row 448
    H 256 opened columns: 256 pads per row on the coset; 65,536 leaves salted
    M (the mask commitment): 12 a-rows with 256 pads each, the zero-sum blinding row, the prox mask row; 256 opened columns of 4,096, salted

## The tamper legs

`layer 0 16 --zk --seed 7 --all-tampers` (CPU and `HL_GPU=1`): the
six legs REJECT — flipped X entry and flipped Wg entry at the g/u
matmul sumcheck round 0, wrong requant (h8) at zero-check 20 round 0,
wrong z at the d matmul round 0, and the two lookup legs
(out-of-range remainder, wrong table entry) at "H: pcs zk: group 4:
<v, c> != combined claim" — the value-0 LogUp claim, where the
non-zk verifier rejected at its clear-text table evaluation; `pass 2
64 --zk --tamper z` REJECT (the seventh, pass-level leg). The
pcs-level tests reject a wrong value, a wrong sum, a tampered message
entry, a tampered PAD entry, a tampered salt, a tampered column entry
and a different witness under the same claims.

## Where the memo's sketch did not close, and what was built instead

- The memo's mask row ("v' = rho^T M + u, u's entry read off the
  column") leaves the verifier without <u, c> for a
  challenge-dependent column weight c; letting the prover send it is
  unsound. Built: the mask row's contribution is folded into the
  SUMCHECK by a last-round extension (T_ext = (1 - y) T + y R_T; the
  eq / public factors carry (1 - y)); rounds 0..k-1 are the unmasked
  sumcheck's, round k costs O(1), and the opened claim is the combined
  (1 - rho_k) T~ + rho_k R_T~ with a uniform clear vector AND a uniform
  value. This also closes the terminal evaluations the memo listed as
  revealed — its "masked claims" do not cover a nonlinear terminal
  check. The sum group of H (a challenge-independent key) is masked by
  a zero-sum row whose zero sum is proven by a masked 14-variable
  sumcheck (Ligero's own device).
- The masking polynomial g needs a ZK opening of its own (a plain row
  would unmask the rounds; two rows combined by challenges would
  too): a small per-layer Ligero-form mask commitment opened by the
  product-form linear test (q' = sum_s p_a p_W + p_b, the sum over
  G_512 equals the theta-combined functional, blinded by a zero-sum
  row). The masking polynomial carries one extra coefficient (a' on
  prod x_j) so that its total G and its terminal g(rho) are jointly
  uniform given the rounds.
- The matmul terminals are opened as their own groups (two more A
  clear vectors per layer, +10% bytes) rather than folded into the
  zero-checks: the fold would need a "replicated mask row" table kind
  in XX's device kernels.

## Against the memo's count

The memo's [COUNTED] P1 surcharge was +2-8% prover / +1-8% bytes /
+2-15% verifier; the built form is +60% / +30% / +45% on the GPU and
+12% / +30% / +70% on the CPU. The count assumed the masked objects
ride inside work already paid; the built form pays for one mask row
per (table, point) — 26 + 37 rows per layer — the matmul terminals
as their own groups, the mask commitment, and the host-side
randomness. Byte-preserving levers not applied: the DIF/DIT NTT pair
with a bit-reversed pad kernel (~-0.15 s GPU), the table zero-check
on the device (~-0.2 s), folding the masked matmul terminals into the
zero-checks (-8% bytes), the mask rows' randomness generated on the
device, and the salting on the device.

## Commands

    # CPU
    flock /tmp/zk-build.lock cargo build --release --manifest-path hashline/Cargo.toml
    M125_EXPORT_DIR=results/m125_ffn_export_wsl hashline/target/release/hashline pass 12 512 --threads 8 --zk --seed 1 --proof-out /tmp/zk.bin
    # GPU (the same LD_LIBRARY_PATH / CARGO_TARGET_DIR recipe as the README), then
    HL_GPU=1 ... hashline/target-gpu/release/hashline pass 12 512 --threads 8 --zk --seed 1 --proof-out /tmp/zk_gpu.bin
    # the legs
    ... hashline layer 0 16 --threads 8 --zk --seed 7 --all-tampers
    # the uniformity test
    cargo test --release --manifest-path hashline/Cargo.toml zk_openings -- --nocapture
