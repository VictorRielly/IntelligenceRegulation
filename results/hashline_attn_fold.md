# THE ATTENTION EXPORTS RE-ESTABLISHED, AND THE CLAIM FOLD (U-PERF3 lane AK, 2026-09-04)

Two things: (1) the attention export directories that the 2026-09-03
19:14 hard reboot destroyed with `/tmp` are regenerated, and lane AG's
full-layer digests reproduce **byte for byte on the merged tree**; (2)
the 60 tokens/s plan's lever **L5, "fold the claims"**, is built and
measured.

Every number is [MEASURED] on the WSL laptop (Core Ultra 9 185H, 22
threads, 15 GB), 8 rayon threads unless stated, CPU only, label
`[WSL-BOX 8T CPU NOISY-SHARED]` — lanes AI and AJ were building and
running 8B jobs on the same box throughout, so walls carry noise and
BYTES do not.

---

## 1. Part one: AG's results are verifiable again

`/tmp` held every attention oracle export lane AG's gates consume, and
the reboot wiped it. Regenerating them costs nothing once you know
where the inputs are:

    # the 125M oracle needs NO token cache: m125_attn_gate.TOKENS is
    # /home/victor/shard-00000.npy, which is not in /tmp
    python3 scripts/attention_hash_ref.py --arch 125m --layer L \
        --export results/ak_attn_exports/m125_lL          # 2.6-5.9 s each

    # the Mistral oracle needs the tokenized stream; tokenizing
    # ~/models/fineweb-edu/sample_text.txt is the ~5.5 min step, so the
    # cache is kept OUT of /tmp this time
    python3 scripts/attention_hash_ref.py --arch mistral --layer 0 \
        --tokens-cache results/ak_mistral_toks.npy \
        --export results/ak_attn_exports/mistral_l0        # 21.9 s

Regenerated artifacts, all under `/home/victor/wt-uperf3-ak/results/`
(worktree-local, deliberately untracked — a `.gitignore` entry tagged
`[UPERF3-AK]` keeps 279 MB of int32 planes out of the repository):

| what | path | size |
|---|---|---|
| the twelve 125M attention exports | `ak_attn_exports/m125_l{0..11}` | 91 MB |
| the Mistral-7B layer-0 attention export | `ak_attn_exports/mistral_l0` | 169 MB |
| the Mistral token stream (4,748,171 tokens) | `ak_mistral_toks.npy` | 19 MB |

Each export is 7 int32 planes (`x_in`, `wq`, `wk`, `wv`, `wo`, `gA`,
`gM`) plus `manifest.json` / `manifest.txt`. **Whoever needs these next
should copy them rather than re-derive them**, and if they must be
re-derived, the 125M set takes 45 s in total and the Mistral one 22 s
GIVEN the token cache.

### 1.1 The 12-layer 125M full-model pass — AG's digest, on the merged tree

    hashline attn-pass results/ak_attn_exports/m125_l 12 \
        --export <aa m125_v3_export> --t 512 --threads 8

| run | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| **AK, merged tree (6854d2c), regenerated exports** | **100.47 s** | 2.66 s | **404,327,452 B** | 6.62 GB | **ACCEPT** |
| AG rung 5, pre-merge tree, `/tmp` exports | 94.54 s | 2.03 s | 404,327,452 B | 6.56 GB | ACCEPT |

    PROOF sha256 c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece

identical to AG's. **The AG merge (on top of AH's shape-general kernels
and AI's rung-2 ZK device gate) did not disturb the full-layer
statement.** The 6% wall difference is box noise.

### 1.2 One full Mistral-7B layer

| shape (layer 0, int24 residual) | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| **T = 16** (AK) | 12.712 s | 0.097 s | **48,478,456 B** (attention half 22.6 MB) | 10.10 GB | **ACCEPT, 10/10 legs REJECT** |
| T = 16 (AG) | 12.91 s | 0.11 s | 48.5 MB (22.6) | 10.08 GB | ACCEPT, 10/10 |
| **T = 64** (AK) | 15.008 s | 0.243 s | **52,756,584 B** | 11.24 GB | **ACCEPT** |
| T = 64 (AG) | 14.27 s | 0.13 s | 52.8 MB | 11.24 GB | ACCEPT |

`attn-chain results/ak_attn_exports/mistral_l0`: **64/64 tensor digests
match the oracle** (4.16 s), oracle CHAIN `4085604b8d61ce8c..` — AG's
digest exactly.

### 1.3 The floor

The four byte gates on BOTH binaries (`results/ak_floors.sh`, a copy of
`scripts/floors_round13_merge.sh` pointed at this worktree): v2
`50cf7bdfd6b5b182..` / 66,844,928 B, v3 `5f368db6240e0614..` /
70,758,084 B, zk `021485e4f80ec695..` / 87,228,528 B, zk-v3
`40eb54795e023c77..` / 87,697,008 B — **8/8 GATE OK**, `cargo test
--release` 40/40.

---

## 2. Part two: lever L5, the claim fold

### 2.1 Where the attention half's bytes actually are

A Ligero opening costs ONE clear row-combination of `2^log_cols` Fp2 —
**262,144 B at log_cols = 14** — per GROUP, and `pcs::group_claims` keys
a group by the claim's **column tail**: the last `log_cols` coordinates
of its point. Two claims at different points are two groups and two
262,144 B vectors, however small the plane they speak about.

The new `HL_ATTN_CLAIMS=1` report (`attention::claim_groups_report`,
stderr only — it touches neither transcript nor proof) on one 125M full
layer, before any change:

| commitment | claims | groups | group vectors | at T = 512 |
|---|---:|---:|---:|---:|
| Wa | 6 | 6 | 1.50 MB | 6 groups |
| Ha | 38 | 6 | 1.50 MB | 6 groups |
| **Aa** | **93** | **49** (T=128) | **12.25 MB** | **41 groups, 10.25 MB** |

So it is **15.25 MB of the 19.7 MB attention half at T = 128, and 13.25
MB of the 27.3 MB at T = 512** — not the ~8 MB AG estimated. And **24 of
Aa's 49 groups are single claims on the two PACKED SMALL slices** `sm`
and `lm`: the norm rows (D, Dsq, a1, a2) and the isqrt limbs live there
as T-long sub-rows of a 2^14 / 2^15 packed slice, so one claim about a
512-element row costs a whole 262,144 B vector.

### 2.2 The mechanism, and why it is not the v3 fold verbatim

The v3 FFN prover folds every pending claim into its two zero-checks —
one `nu`-weighted `eq` term each — so A and H open at exactly two
points. The attention argument runs its five zero-checks BEFORE its four
matmul sumchecks, so most of its claims are raised *after* the last
zero-check and cannot ride one; folding them into zero-checks would mean
reordering the entire argument.

The same arithmetic as its own reduction is `attention::collapse_range`:
for a committed range and the claims inside it,

    sum_c nu_c P(p_c)  =  sum_x [ sum_c nu_c eq(p_c^full, x) ] P(x)

is ONE degree-2 sumcheck over the range whose terminal is ONE claim at
ONE point. `p_c^full` is the claim's point lifted to the range's arity by
the existing `sub_point` (sub-block index in the high bits), and the
verifier evaluates the bracket itself as `sum_c nu_c eq(p_c^full, rho)`,
each term O(log). **No soundness property changes** (Schwartz-Zippel on
`nu`, then the sumcheck) and **no new primitive is introduced**; the cost
in the proof is `n_rounds x 3 x 16 B` plus one Fp2 terminal per collapse.

Which ranges are collapsed is decided by `collapse_plan(lay)` from the
LAYOUT ALONE, so prover and verifier agree by construction:

* **default** — the binary decomposition of the whole A range into
  aligned power-of-two blocks. Every plane is allocated aligned to its
  own size, so each plane sits wholly inside one block and every claim
  collapses; A opens at one point per block (4 at 125M, against 41).
* `HL_FOLD=small` — the two packed small slices only (free, but the
  sumcheck terminals stay unfolded).
* `HL_FOLD=nos` — the whole range minus the six `H x T x T` S-domain
  planes.
* `HL_NO_FOLD=1` — off, i.e. the pre-fold proof.

### 2.3 Measured: one 125M full layer, T = 512, 8 threads

| mode | Aa groups | attention half | FULL LAYER proof | PROVE | peak RSS | verdict |
|---|---:|---:|---:|---:|---:|---|
| `HL_NO_FOLD=1` (AG's proof) | 41 | 27.3 MB | **33,234,332 B** | 7.661 s | 5.102 GB | ACCEPT |
| `HL_FOLD=small` | 25 | 23.1 MB | 29,041,500 B | 7.499 s | 5.102 GB | ACCEPT |
| **default (whole range)** | **4** | **17.6 MB** | **23,539,100 B** | 8.297 s | 5.102 GB | **ACCEPT** |

**−29.2% on the full layer's proof, −35.5% on the attention half, for
+8.3% of prover time and NO change in peak RSS** — inside the plan's own
modelled band for L5 (bytes x0.44-0.50 on the attention half's group
vectors, time x1.05-1.15).

At T = 128 the same three modes give 24,102,524 / 17,812,492 /
12,309,708 B (−26% and −49%), so the fold's absolute saving is
T-independent (the group vectors are) while the rest of the proof grows
with T. Verification also gets FASTER — 0.146 s -> 0.077 s at T = 512 —
because the verifier checks one group vector per block instead of one per
point.

### 2.4 Measured: one full Mistral-7B layer, T = 16

| mode | PROVE | VERIFY | attention half | FULL LAYER proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---:|---|
| pre-fold (AG / AK rung 1) | 12.712 s | 0.097 s | 22.6 MB | **48,478,456 B** | 10.10 GB | ACCEPT, 10/10 |
| **folded (default)** | 12.865 s | 0.072 s | **17.1 MB** | **42,977,736 B** | 10.09 GB | **ACCEPT, 10/10 legs REJECT** |

−11.3% on the whole layer and **−24% on the attention half for +1.2% of
prover time** at 8B width. The surcharge shrinks because at 8B width the
weight commitment dominates the layer and `cols_log` drops to 13 (a group
vector is 131,072 B rather than 262,144).

### 2.5 The tamper legs, with the fold on

All of AG's legs still reject, at both widths — the collapse is a
reduction of the claims, not of the statement:

* `attn-full` 125M T = 512: **10/10 REJECT**, GREEN.
* `attn-layer` 125M T = 512 (the attention half alone): **10/10 REJECT**
  including *wrong isqrt D* (the isqrt pair), *attainment selector moved*
  and *broken residual/seam plane*, GREEN.
* `attn-full` Mistral T = 16: **10/10 REJECT**, GREEN.

---

## 3. What is left on this lever (for the next agent)

1. **Wa and Ha are not folded.** They cost 6 groups each at 125M — 1.50
   MB apiece at T = 512, about 13% of the folded layer. The same
   `collapse_range` applies verbatim; the only work is keeping the W and
   H data alive in `AttnPending` until `attn_open_wh` (today only
   `a_data` is kept). Judgement: worth it for H, whose small helper
   ranges are cheap; W at Mistral width is 42M entries per layer and the
   collapse would cost more than the 786 KB it saves.
2. **The collapse sumcheck copies A into Fp2** (`tab2`) to satisfy
   `sumcheck::prove`'s `Vec<Vec<Fp2>>`. A specialised first round reading
   the base-field plane in place would remove one 16-byte-per-element
   copy of the whole witness. It did not show up in peak RSS at 125M
   (5.102 GB in every mode) but it will at Mistral T = 512, where A is
   ~80M entries.
3. **`HL_FOLD=nos` measured worse than the default at 125M** on both
   axes. It is kept because at Mistral T = 512 the six S-domain planes
   are the majority of A and the trade may invert; nobody has run that
   shape yet (it needs the Mac).
4. **The plan's C2** — the batched-evaluation reduction proper (every
   claim to ONE point, W/A/H merged into one commitment, `n`
   re-optimised) — subsumes this rung. What this rung shows is that the
   first half of C2 is worth −29% on its own and costs +8% of prove.
5. **`docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` section 3 and
   `results/hashline_attn_fulllayer.md` still carry the PRE-FOLD proof
   sizes** (33.2 MB per 125M layer, 404.3 MB for the pass). Neither file
   is in lane AK's ownership block; they need the folded numbers from
   this record at merge.

### 2.6 THE 12-LAYER 125M FULL-MODEL PASS, FOLDED

    hashline attn-pass results/ak_attn_exports/m125_l 12 \
        --export <aa m125_v3_export> --t 512 --threads 8 --all-tampers

| pass | witness | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---:|---|
| pre-fold (AG / AK rung 0) | 5.22 s | 100.47 s | 2.66 s | **404,327,452 B** | 6.62 GB | ACCEPT |
| **folded (default)** | 4.94 s | **107.63 s** | **0.83 s** | **282,217,500 B** | 6.44 GB | **ACCEPT** |
| change | | **+7.1%** | **-69%** | **-30.2%** | -2.7% | |

    PROOF sha256 2d5791ff8e153b4946086386b508ce65f6f9b8b6e48bf95a4a67f1b22eefdf43
                 (282,217,500 B)   [the FOLDED 12-layer full-model proof]
    PROOF sha256 c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece
                 (404,327,452 B)   [HL_NO_FOLD=1: AG's proof, still reproduced]

**The layer-seam leg still rejects** with the fold on: layer 1's `x_in`
changed by one and its whole witness rebuilt on it —
`PASS-FULL REJECT: layers 0->1: layer seam: the previous layer's xres2 !=
this layer's x_in`. `attn-pass: GREEN`.

The verify time is the surprise: **2.66 s -> 0.83 s**, because the
verifier now checks four group vectors per layer instead of forty-one.

### 2.7 THE FOLD IS THE ONLY CHANGE — the pre-fold proof is bit-identical

With `HL_NO_FOLD=1` the FOLDED tree re-runs the 12-layer pass and gives
AG's digest back, byte for byte:

    HL_NO_FOLD=1 hashline attn-pass ... 12 --export <v3> --t 512 --threads 8
    PROOF sha256 c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece
                 (404,327,452 B)
    PASS-FULL ACCEPT | witness 5.11 s | PROVE 94.09 s | VERIFY 1.99 s

(prove 94.09 s here against 100.47 s for the same command at rung 0 —
the box was quieter; AG measured 94.54 s.) So nothing in the argument,
the witness, the transcript or the commitments moved: the ONLY difference
between the 404.3 MB proof and the 282.2 MB one is how many points the A
commitment is opened at. That also means **AG's round-13 record stays
checkable on the merged tree** — `HL_NO_FOLD=1` is its gate.

### 2.8 The floor, with the fold in

`results/ak_floors.sh` on BOTH binaries built from the folded tree:
**ALL FLOORS GREEN — 8 byte gates** (v2 `50cf7bdfd6b5b182..` /
66,844,928 B, v3 `5f368db6240e0614..` / 70,758,084 B, zk
`021485e4f80ec695..` / 87,228,528 B, zk-v3 `40eb54795e023c77..` /
87,697,008 B, on cpu and gpu) — and `cargo test --release` **40/40**. The
fold touches `attention.rs` only; the v2/v3/ZK FFN statements are
untouched, as their digests say.
