# Soundness recount: the native private run at the trained profiles

Soundness-accounting lane, 2026-10-17 (UTC 19:22–19:45). **Paper only.** Nothing
was built, proved or measured, and nothing in git was written. Every number below is
**[COUNTED]**: exact arithmetic, reproduced by `recount.py` in this directory (one
thread, 0.03 s; output in `recount.out.txt` and `recount.json`). This is not a ruling.
Soundness targets are Victor's (D15's open question G.0-2). Nothing here touches
privacy.

Object: register entry D15 (`docs/zkmatrix-poc/ZK60_DECISIONS.md:463–490`) and the
whole-proof figures built on its per-opening 2^-106. Recounted for the four
registered trained profiles of the native tree (`ops/zkp-mvp/trained-1b/`, read
only):
* TinyLlama-1.1B, T32, T64 and T128, each a 22-block stack;
* Llama-3-8B, T32, a 32-block stack.

---

## 1. In plain words

**What D15 got wrong.** A proof opens a commitment by revealing 256 random columns of
its encoded data. A cheater escapes that check with a probability set by one number,
the code's *distance*. D15 took that distance from the commitment module's header,
`1 − 1/inv_rate` = 3/4 at rate 1/4. That gives 2^-106 per opening.

But every commitment of the private block uses the module's **zero-knowledge
encoding**. That encoding adds 256 random pad symbols to every row before encoding,
so the code is RS(n + 256, 4n). Its distance is `1 − (n + 256)/(4n)`, a little below
3/4. The narrower the row, the bigger the loss.

This changes the per-opening figure for the block commitments A and H, the boundary
commitments B_k and the two run endpoints:

| row width n | per opening, real | where it is used |
|---|---:|---|
| 2^12 | **2^-103.69** | TinyLlama T32 |
| 2^13 | **2^-104.97** | TinyLlama T64, Llama-3-8B T32 |
| 2^14 | **2^-105.61** | TinyLlama T128 (and the 125M line) |

The masking commitment M is unaffected, at 2^-106.25 at every profile. So is the
frozen toy (row width 2^8, rate 1/8), where pads bring the rate to exactly 1/4.

**How many bits weaker each stack really is** (cheater's chance per run; a higher bit
number is better):

| stack | commitment term, D15 → real | **whole run (a) D15 convention** | **whole run (b) real distance** | weaker by |
|---|---|---:|---:|---:|
| TinyLlama T32, 22 blocks | 99.77 → 97.55 bits (−2.22) | 2^-98.31 | **2^-97.09** | 1.22 bits |
| TinyLlama T64, 22 blocks | 99.77 → 98.72 bits (−1.05) | 2^-97.52 | **2^-97.23** | 0.29 bits |
| TinyLlama T128, 22 blocks | 99.77 → 99.27 bits (−0.51) | 2^-96.52 | **2^-96.45** | 0.06 bits |
| Llama-3-8B T32, 32 blocks | 99.24 → 98.19 bits (−1.05) | 2^-97.08 | **2^-96.77** | 0.31 bits |

Notes on this table:
* The whole-run figures use the lookup-argument convention D15's own 8B figure used:
  4N/|F|, ruling R14 of the security obligations.
* With the tighter N/|F| that the derivation in §3 gives (and that the 125M figure
  used), (a) → (b) is 99.25 → 97.42, 98.81 → 98.18, 98.12 → 97.94 and 98.34 → 97.68
  bits. That is 1.83, 0.64, 0.18 and 0.66 bits weaker.

**Why the whole-run loss is smaller than the per-opening loss.**
* A run opens **4L + 1** commitments (89 at TinyLlama, 129 at 8B), not "six per
  layer". Six per layer was the older public-IO prover's count.
* From T64 upward the run's lookup (LogUp) term, which grows with the context length,
  is as large as the commitment term or larger. The lookup term does not depend on
  the pads.

**Lines this crosses, and lines it does not.**
* **D3's 97 bits** (accepted for the zkVM line only; the native line has no accepted
  level yet):
  * Under the R14 convention, the **8B T32 stack moves from 2^-97.08 to 2^-96.77**.
    It crosses below 97 only because of this correction.
  * **TinyLlama T128 is below 97 either way** (2^-96.52 → 2^-96.45). That is the
    lookup term, not the pads.
  * TinyLlama T32 (2^-97.09) and T64 (2^-97.23) stay just above 97.
  * Under the derived N/|F| convention, no trained stack is below 97. The lowest is
    TinyLlama T32 at 2^-97.42.
* **MVP_STATUS and D12a, "about 2^-97.5" for the twelve-block 125M run: not
  affected.**
  * That figure was built with the real distance, 2^-105.61 at row width 2^14
    (`results/zk60_private_block_125m_check/recompute.py` §11).
  * Re-derived here with the exact opening set it is 2^-97.53 against the quoted
    2^-97.46. That adds the 12 M openings, which the original left out, and drops 12
    double-counted endpoint openings.
* **D15's "106 bits per opening"** is wrong for every A, H, B_k and endpoint opening
  of the trained profiles (103.69 to 105.61 bits). It is right for M and for the toy.
* **D15's "about 94 bits for the whole 8B proof"** was a projection for the older
  public-IO prover at T512. It is not this object.
  * The native private 8B stack at T32 is 96.8 to 98.3 bits, depending on the
    convention.
  * At an unregistered 8B **T512** geometry (row width 2^16), the native run would be
    2^-92.7 (R14) or 2^-94.7 (N). There the lookup term is everything and the pads
    cost 0.01 bit (projection: copied layout formulas; no Rust count exists for that
    geometry).
* **The token-I/O design's stack term.** It quoted 2^-98.7 at 8B T32 and 2^-99.2 at
  TinyLlama T32: six openings per layer at 2^-106.25. The real commitment term is
  2^-98.19 and 2^-97.55, which is 0.47 and 1.66 bits weaker. Its checker
  (`results/zk60_token_io_design_20261017/check/CHECK.md` §3.3) had flagged the
  per-opening dilution as "roughly 1.3–2.5 bits weaker". With the true opening count
  the stack term is 0.5–1.7 bits weaker.

**Is the (1 − δ/3)^Q formula right?** Yes. The error is in δ, not in the "/3".
* The δ/3 regime comes from the Ligero (AHIV) interleaved-proximity lemma in its
  improved form, which Brakedown cites. It holds for any linear code.
* At these parameters nothing more is needed. The field term is 2^-113 to 2^-115 per
  opening, and column indices are drawn independently and uniformly.
* Because these are Reed–Solomon codes, the tighter δ/2 regime (BCIKS20 proximity
  gaps) would also be available. It would make every opening about 2^-169 to 2^-173
  and remove the commitment term from the whole-run figure. The project explicitly
  did not adopt it (obligations doc §4.3), and adopting it is the security owner's
  call.

**Cheapest repair of the per-opening figure.**
* Raise the column checks, and with them the pads (`ZkOpts::standard` ties the two),
  from 256 to **263 / 260 / 258** at row widths 2^12 / 2^13 / 2^14. Every A, H, B_k
  and endpoint opening is then back at or above 2^-106.25.
* Cost: about +1.88 % / +0.86 % / +0.32 % / +0.83 % of the receipt bytes (TinyLlama
  T32 / T64 / T128, 8B T32), and a new statement version.
* It does **not** lift any whole-run figure above about 97 bits from T64 upward,
  because there the lookup term sets the level.
* Whether ~97 bits is acceptable is still Victor's open question G.0-2 under D15.

---

## 2. Every opening of one run

The sources (read only):
* commitments and openings per block: `protocol.rs` `verify_core`, `:1174–1287`. A
  and H go through `pcs::verify_zk_tagged`; M goes through `zk::mask_verify_tagged`,
  one call each per block.
* boundaries and endpoints: `run.rs`, prover `:884–960` and verifier `:1060–1160`.
  B_k is committed in block k and opened **once**, in block k+1's segment, with both
  blocks' claims. The run input endpoint is opened in block 0's segment, the output
  endpoint in block L−1's.
* geometry: `shape.rs:345–378`. Row width 2^12 / 2^13 / 2^14 for TinyLlama
  T32 / T64 / T128 and 2^13 for 8B T32. `inv_rate` is 4. The endpoint width and rate
  default to the block's (`shape.rs:584`); boundaries use the same (`run.rs:428`).
* checks and pads: Q = 256 (`shape.rs:279`). `ZkOpts::standard` sets pads = checks
  (`zkp-core/src/pcs.rs:582–584`).
* M: `hashline/src/zk.rs:373–375`, `:481–519` and `:648–700`.

No weight commitment exists, because the weights are public in P1. No commitment is
opened twice.

**Per-commitment table** (identical structure at every profile; row counts per
profile below).

Column guide:
* "msg/nn" is the code RS(msg, nn) the verifier decodes against.
* δ = 1 − msg/nn.
* (a) is D15's figure, (3/4)^256. (b) is (1 − δ/3)^256.

| commitment | opened per run | row width n | inv. rate | pads Q / checks | code msg / nn | δ | (a) | (b) at 2^12 / 2^13 / 2^14 |
|---|---:|---|---:|---|---|---|---:|---|
| A, block witness | L | 2^lc | 4 | 256 / 256 | n + 256 / 4n | 1 − (n+256)/4n | 2^-106.25 | 2^-103.69 / 2^-104.97 / 2^-105.61 |
| H, LogUp helpers | L | 2^lc | 4 | 256 / 256 | n + 256 / 4n | same | 2^-106.25 | same |
| M, CFS masks | L | 512-symbol a-rows (256 pads), 1024-coefficient b/u rows | 8 (a-rows) | 256 / 256 | **1024 / 4096** | **3/4** | 2^-106.25 | **2^-106.25** (all) |
| B_k, internal boundary | L − 1 | 2^lc | 4 | 256 / 256 | n + 256 / 4n | 1 − (n+256)/4n | 2^-106.25 | as A |
| E_in, run input endpoint | 1 | 2^lc | 4 | 256 / 256 | n + 256 / 4n | same | 2^-106.25 | as A |
| E_out, run output endpoint | 1 | 2^lc | 4 | 256 / 256 | n + 256 / 4n | same | 2^-106.25 | as A |
| **total** | **4L + 1** | | | | | | | |

Rows committed (the layout replica agrees with the Rust counts at every profile: A
rows, H rows and U8 lookups from `results/zk60_1b_native_20261017/r3-ladder-count.log`
and the R4 counted layouts):

| profile | L | lc | A rows | H rows | M rows | B_k rows | E rows | openings per run |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| TinyLlama T32 | 22 | 12 | 1,729 | 1,798 | 50 | 22 | 21 | 89 |
| TinyLlama T64 | 22 | 13 | 1,817 | 1,926 | 50 | 22 | 21 | 89 |
| TinyLlama T128 | 22 | 14 | 1,993 | 2,182 | 50 | 22 | 21 | 89 |
| Llama-3-8B T32 | 32 | 13 | 1,697 | 1,758 | 50 | 22 | 21 | 129 |

**Why M stays at 3/4.**
* M's rows are evaluated on a 4,096-point coset.
* Its proximity and product vectors are checked as 1,024-coefficient polynomials
  (`zk.rs:615`, `:659`), because its `b` and `u` rows have degree below 1,024
  (`zk.rs:505–507`).
* The code it is tested against is therefore RS(1024, 4096), with δ = 3/4 exactly.
  The 256 pads inside each 512-symbol a-row do not dilute it.
* M's product (consistency) check is 2^-173.88 per opening, which is negligible.

---

## 3. The other terms of the union bound

These follow the obligations doc §4.2–4.6 (the source of D15's whole-proof figure).
They are identical under (a) and (b).

| term | how counted | TinyLlama T32 | T64 | T128 | 8B T32 |
|---|---|---:|---:|---:|---:|
| lookups per block (U8 + exp + act) | `u8_lookups` + \|S\| + \|F\| | 6,266,880 | 13,451,264 | 30,572,544 | 12,271,616 |
| **LogUp, R14 convention** 4N/\|F\|, run | per block, own α, β, γ per block (`protocol.rs:1201–1203`) | 2^-98.96 | 2^-97.86 | 2^-96.67 | 2^-97.45 |
| LogUp, derived (N + 1536)/\|F\|, run | α identity (N + 768 distinct poles) + tuple compression (768 table rows) | 2^-100.96 | 2^-99.86 | 2^-98.67 | 2^-99.45 |
| sumchecks, run | 23 slots per block: rounds × degree + zero-check point + batched terms + 2 | 2^-113.05 | 2^-112.98 | 2^-112.91 | 2^-112.42 |
| PCS field terms, run | proximity combination (e + 1)/\|F\| + λ batching, every opening | 2^-109.77 | 2^-108.85 | 2^-107.89 | 2^-108.32 |
| consistency half of each opening | (1 − 2δ/3)^256 per group, 2^-248 at 2^12 | negligible | negligible | negligible | negligible |

Two notes:
* **The two LogUp conventions differ by exactly 2 bits.** R14's 4N is what the
  obligations doc adopted and what D15's 8B figure (2^-94.2 lookup term) used. The
  derivation gives N plus 1,536. The cheater's lookup must either collide with one of
  the 768 distinct compressed table rows under (β, γ), or survive the α identity,
  whose cleared polynomial has degree below N + 768. The 125M check used N.
* **Challenge reduction bias (D9)** is a privacy term. For soundness, the per-outcome
  relative bias of 2^-64 multiplies every term by (1 + 2^-64), which changes nothing.

---

## 4. Whole-run figures

| stack | (a) D15, R14 LogUp | **(b) real, R14 LogUp** | (a) D15, derived LogUp | **(b) real, derived LogUp** | 6-per-layer convention, R14 | δ/2 regime, R14 (not adopted) |
|---|---:|---:|---:|---:|---:|---:|
| TinyLlama T32 | 2^-98.31 | **2^-97.09** | 2^-99.25 | **2^-97.42** | 2^-98.08 | 2^-98.96 |
| TinyLlama T64 | 2^-97.52 | **2^-97.23** | 2^-98.81 | **2^-98.18** | 2^-97.38 | 2^-97.86 |
| TinyLlama T128 | 2^-96.52 | **2^-96.45** | 2^-98.12 | **2^-97.94** | 2^-96.44 | 2^-96.67 |
| Llama-3-8B T32 | 2^-97.08 | **2^-96.77** | 2^-98.34 | **2^-97.68** | 2^-96.93 | 2^-97.45 |

The commitment term alone, for comparison with the token-I/O figures:

| stack | (a) 4L + 1 at 2^-106.25 | (b) real | token-I/O convention: 6L at 2^-106.25 |
|---|---:|---:|---:|
| TinyLlama T32 | 2^-99.77 | 2^-97.55 | 2^-99.21 |
| TinyLlama T64 | 2^-99.77 | 2^-98.72 | 2^-99.21 |
| TinyLlama T128 | 2^-99.77 | 2^-99.27 | 2^-99.21 |
| Llama-3-8B T32 | 2^-99.24 | 2^-98.19 | 2^-98.66 |

Projections for perspective. These T512 geometries at row width 2^16 are not
registered, have no export and are above the laptop's memory gate:
* TinyLlama T512: whole run 2^-93.76 (R14) or 2^-95.68 (derived). Its layout
  matches the Rust count `r3-ladder-count.log:37`.
* 8B T512: 2^-92.72 or 2^-94.66. No Rust count exists for it.
* In both, (a) and (b) differ by at most 0.01 bit.

**A second reading: the worst single round.**
* The figures above are union bounds of the interactive protocol, which is D15's
  reading.
* After Fiat–Shamir, a cheater who can make 2^t hash calls is bounded, under
  round-by-round soundness, by about 2^t times the worst single round. The
  obligations doc §4.6 notes that this multi-round loss is not quantified anywhere.
* Worst rounds at the four profiles:

  | stack | column test, real | (D15 said) | LogUp per block, R14 | LogUp per block, derived |
  |---|---:|---:|---:|---:|
  | TinyLlama T32 | 2^-103.69 | 2^-106.25 | 2^-103.42 | 2^-105.42 |
  | TinyLlama T64 | 2^-104.97 | 2^-106.25 | 2^-102.32 | 2^-104.32 |
  | TinyLlama T128 | 2^-105.61 | 2^-106.25 | 2^-101.13 | 2^-103.13 |
  | Llama-3-8B T32 | 2^-104.97 | 2^-106.25 | 2^-102.45 | 2^-104.45 |

* On that reading the pads cost the full per-opening loss: 2.56 / 1.28 / 0.64 /
  1.28 bits. Even so, the LogUp round is the worst round in every case but TinyLlama
  T32 under the derived convention.

---

## 5. Cross-check of (1 − δ/3)^Q against the statement the code relies on

**What the code says.**
* `zkp-core/src/pcs.rs:16–19`: "Brakedown Thm. with the conservative δ/3 bound: with
  RS relative distance δ = 1 − 1/inv_rate the column test fails to catch a far matrix
  with probability (1 − δ/3)^Q; at inv_rate 4, Q = 256: (3/4)^256 = 2^-106."
* That is the **non-ZK** encoding's δ. The ZK section of the same file
  (`:557–568`) states the code is RS(n + Q, nn) with distance 1 − (n + Q)/nn. The
  header's example was never restated for it.

**How the error spread.**
* The obligations doc got it right for the toy's hiding form: RS(512, 2048), exactly
  1/4 (§4.3, line 377).
* Its §5 deployment row carried 2^-106.2 to "log_cols 14, inv_rate 4", where the
  hiding form gives 2^-105.61. D15 cited that row.

**What the formula bounds, and that it holds here.**
1. **Proximity half.** If the committed matrix is e-far (e < d/3) from the
   interleaved code, a uniformly random row combination is e-close with probability at
   most (e + 1)/|F|. This is the AHIV/Ligero lemma, improved form, valid for any
   linear code.
   * The combination here: `zk_rhos` draws one fresh Fp2 coefficient per row,
     `challenge_fp2_vec(rows)`, `pcs.rs:954`.
   * The verifier re-encodes whatever n + Q entries it receives as a ZK codeword
     (`verify_zk`, `:1093–1104`). So the clear proximity vector is a codeword of
     RS(n + Q, nn), and it disagrees with the true combined column on at least an
     e/nn fraction of positions.
   * The Q indices are independent and uniform: `transcript.rs:136–148` samples with
     replacement, masking 64-bit words to a power-of-two bound.
   * So all Q miss with probability at most (1 − e/nn)^Q → (1 − δ/3)^Q.
2. **Consistency half.** If the matrix is within e < δ/3 of its unique decoding, a
   group vector that differs from the decoded combination disagrees on at least
   δ − e > 2δ/3 of positions. That is (1 − 2δ/3)^Q per group, 2^-248 at 2^12.
3. **Union per run.** Fresh indices per opening (each opening squeezes after its own
   vectors, `pcs.rs:1029`/`:1089`). The obligations doc §4.4 composition rule applies.

**Verdict on the regime.**
* δ/3 is valid and conservative at every trained profile. δ is between 0.734 and
  0.749, and unique decoding needs only e < δ/2.
* δ/2 (BCIKS20, Reed–Solomon proximity gaps) would also hold for these coset RS codes
  and would give 2^-169 to 2^-173 per opening. It was declined by policy.
* Adopting δ/2 would need its own written check: the exact theorem, the field term
  for a combination of m rows with independent coefficients, and M's affine `u` row.
* **The only correction needed is to use δ_ZK = 1 − (n + Q)/(n · inv_rate).**

**Byte cost of restoring 2^-106.25 per opening.** Counted from the wire layout's
per-column formula, not checked against a Rust count:

| stack | checks = pads | per opening | added bytes per run | share of the measured receipt |
|---|---:|---:|---:|---:|
| TinyLlama T32 (2^12) | 263 | 2^-106.46 | 4,723,320 | +1.88 % of 250,855,088 B |
| TinyLlama T64 (2^13) | 260 | 2^-106.59 | 2,859,680 | +0.86 % of 333,316,880 B |
| TinyLlama T128 (2^14) | 258 | 2^-106.43 | 1,586,192 | +0.32 % of 497,665,904 B |
| Llama-3-8B T32 (2^13) | 260 | 2^-106.59 | 3,863,328 | +0.83 % of 465,815,776 B |

The profile strings carry Q (`protocol.rs:134`), so this is a new statement version
per profile.

---

## 6. Proposed dated correction note under D15

This wording is for the coordinator or the security owner to place. This lane does
not edit the register.

> **Correction, 2026-10-17 (technical clarification; soundness recount,
> `results/zk60_soundness_recount_20261017/RECOUNT.md`, [COUNTED]).** The 2^-106
> above holds only where a commitment's encoded rows have rate exactly 1/4. Every
> private-block commitment uses the zero-knowledge encoding, whose code is
> RS(n + Q, n · inv_rate) (`zkp-core/src/pcs.rs:565`). Its distance is therefore
> 1 − (n + Q)/(n · inv_rate), not the header's 1 − 1/inv_rate (`pcs.rs:16–19`,
> which this entry cited).
>
> With Q = 256 and rate 1/4, one opening of A, H, a boundary or an endpoint is:
> * 2^-103.69 at row width 2^12 (TinyLlama T32);
> * 2^-104.97 at 2^13 (TinyLlama T64, Llama-3-8B T32);
> * 2^-105.61 at 2^14 (TinyLlama T128, 125M);
> * 2^-106.09 at 2^16.
>
> The masking commitment M stays at 2^-106.25 (its code is RS(1024, 4096)), and so
> does the frozen toy. The δ/3 proximity regime is unchanged and correct. A native
> private run opens 4L + 1 commitments (A, H, M per block, L − 1 boundaries, two
> endpoints), not six per layer.
>
> Whole-run figures of the registered trained stacks, with the R14 lookup
> convention 4N/|F| (derived N/|F| in brackets):
> * TinyLlama T32: 2^-97.1 (2^-97.4);
> * TinyLlama T64: 2^-97.2 (2^-98.2);
> * TinyLlama T128: 2^-96.5 (2^-97.9);
> * Llama-3-8B T32: 2^-96.8 (2^-97.7).
>
> That is 0.1–1.2 bits (0.2–1.8) weaker than the same accounting at 2^-106.25 per
> opening. From T64 upward the lookup term, which grows with the context length,
> sets the figure. At an 8B T512 geometry the run would be about 2^-93 (2^-95)
> whatever the opening count (projection). The 125M twelve-block figure of about
> 2^-97.5 (D12a) already used the real distance and stands. The token-I/O design's
> stack term (2^-98.7 at 8B T32) is replaced by these figures.
>
> Raising the column checks and pads to 263 / 260 / 258 at widths
> 2^12 / 2^13 / 2^14 restores 2^-106.25 per opening. It costs +0.3 % to +1.9 % of
> receipt bytes and a new statement version. It does not lift any whole run above
> about 97 bits from T64 upward.
>
> Against D3's 97 bits, which is accepted for the zkVM line only:
> * TinyLlama T128 is below 97 under the R14 convention, with or without this
>   correction.
> * Llama-3-8B T32 moves from 2^-97.1 to 2^-96.8.
>
> The whole-proof target itself remains Victor's pending question (G.0-2).

---

## 7. Reproduction and limits

* `python3 results/zk60_soundness_recount_20261017/recount.py` prints the tables and
  writes `recount.json` (`recount.out.txt` is a copy of the printout). One thread,
  0.03 s, about 12 MB.
* No import from any other lane.
  * The layout formulas (lookups, slots, rows) are copied from
    `results/zk60_token_io_design_20261017/layout.py`, a replica of `shape.rs`.
  * They are re-checked against the Rust counts (A rows, H rows, U8 lookups) at all
    four registered profiles, and against TinyLlama T512 at 2^16. All OK.
* Not covered:
  * the Fiat–Shamir multi-round loss (§4, second reading);
  * hash binding (BLAKE3-256, a 128-bit-class cap, [MODEL]);
  * the standing assumptions of the block's soundness argument (for example the
    weight-range registrar, R31);
  * any privacy property;
  * profiles above T128.
* The sumcheck and PCS field-term counts are upper-bound conventions in the
  obligations doc's style. They sit 9 to 16 bits below the dominant terms, so their
  exact form does not move any headline figure.
