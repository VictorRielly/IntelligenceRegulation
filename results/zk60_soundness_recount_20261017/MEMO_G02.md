# G.0-2: which whole-run soundness target, and what each one costs

**For Victor's pending question G.0-2** (raised in D15 and in the D14 memo,
`docs/zkmatrix-poc/ZK60_L4_FEWER_HASHED_BYTES_MEMO.md` §G.0). The object is the
private Llama-3-8B stack at **T = 512**: 32 blocks, the throughput target of at least
50 proved positions/s on one RTX 5090.

Soundness-accounting lane, 2026-10-17, 19:39–19:53 UTC. **Paper only.** Nothing was
built, proved or measured, and nothing in git was written.

Labels:
* **[COUNTED]** soundness terms, committed elements and receipt bytes.
* **[MODEL]** prover time, from the speed plan's cost model
  (`results/zk60_speed_plan_20261017/cost_model.py`, used through verbatim copies in
  `g02_speedplan_copy/`).
* Lane-day estimates are [MODEL] judgements.

Everything is reproduced by `g02_levers.py` (one thread, 0.25 s; output
`g02_levers.out.txt`, `g02_levers.json`).

This memo makes no ruling. Targets are Victor's, and the security owner signs any
change of accounting.

---

## 1. In plain words

**The question.** "106 bits" was the chance that one check of one commitment is
fooled. A whole 8B run makes about 130 such checks and runs a lookup argument in
every block. A forger needs only one of them to slip, so the run as a whole is
weaker than any single check. D15 asked Victor two things: should the target be per
check or per run, and how many bits?

**Where today's design stands at the throughput workload (8B, T512)** [COUNTED]:
* **The whole run is about 2^-94.7**: 94.7 bits with the lookup bound derived in §3.1,
  or 92.7 bits with the project's older, looser lookup convention (R14).
* **The lookup argument sets this level.** One block has 323 million lookups, and the
  chance the lookup check is fooled grows with that count. One block is about
  2^-99.7; 32 blocks cost 5 more bits.
* **The commitment checks are stronger:** 105.9 bits each, 99.0 bits for all 129
  together.
* **The other terms do not bind below about 105 bits:** the sumchecks are 112.2 bits
  and the commitment field terms 106.4.

**What each target needs** [COUNTED soundness; MODEL speed]:
* The 5090 numbers are the speed plan's roofline: the whole prover on the GPU, every
  kernel at 40 % of the card's memory bandwidth.
* The last column is the kernel efficiency every GPU kernel would need for 50
  positions/s. Today it is 34.5 %; the measured commitment kernel runs at about 13 %
  of the laptop GPU's bandwidth.

| whole-run target | what changes | bits (derived / R14 convention) | receipt per pass | 5090 positions/s at 40 % | kernel efficiency needed for 50/s |
|---|---|---:|---:|---:|---:|
| **today, ~95** | nothing (adopt the derived lookup bound after a check) | 94.7 / 92.7 | 2.23 GB | **57.3** | **34.5 %** |
| ~96 | a second lookup challenge for the score and feed-forward lookups | 96.1 / 94.3 | 2.73 GB | 42.7 | 47.4 % |
| ~97 (D3's level) | the same for score, feed-forward and width-domain lookups | 97.4 / 95.8 | 2.88 GB | 39.7 | 51.2 % |
| ~100 | a second lookup challenge for all lookups, plus 259 column checks instead of 256 | 100.2 | 2.98 GB | 38.4 | 53.1 % |
| ~110 | the same, plus two proximity vectors per opening and 285 column checks | 110.2 | 3.26 GB | 38.4 | 53.1 % |
| ~128 | every challenge in a 256-bit extension field (Fp4), plus 327 column checks | 128.3 | 4.42 GB | 35.2 | 58.2 % |

**The one structural fact.** Above about 95 bits, almost all the cost is the lookup
term.
* With today's design, every way to shrink it adds a second set of committed lookup
  helpers (H):
  * a second, independent challenge; or
  * helpers in a bigger field.
  
  That is +38 % to +55 % committed data and costs **25–33 % of the 5090 throughput**.
  The kernel efficiency needed for 50/s rises from 34.5 % to 47–53 %.
* Once the lookup term is fixed, 99 bits come for free, 100 cost three more column
  checks, and 110 cost about 10 % more receipt.
* The commitment-check term alone is cheap to raise. 17 more column checks give +7 bits
  for +4 % receipt and no prover time. But it does not move the whole-run figure while
  the lookup term dominates.
* **The lever that could buy soundness without the throughput loss** is the speed
  plan's design change D1: LogUp-GKR, which removes the committed H. With its lookup
  challenge drawn in Fp4 it removes the lookup term. My rough sketch puts it at 37–56
  positions/s against 57 today, but its fraction-tree cost is not in the cost model,
  and D1's privacy design is still open (a known counterexample).

**Two readings of "bits", which G.0-2 should name.**
* **D15's reading** adds up every chance of failure over the whole run (a union
  bound). Today that is 94.7 bits (derived) or 92.7 (R14).
* **The other common reading** is the forger's work factor after Fiat–Shamir: about
  the worst single round. On that reading today's design is about **99.7 bits**
  (derived) or 97.7 (R14), limited by one block's lookup round. Bits quoted for
  STARK-style systems are usually of this kind; I did not check how RISC Zero computes
  its 97.
* The zkVM's 97 (D3) is "conjectured", with a lower proven bound. The native figures
  here are proven under the conservative δ/3 regime, with no conjecture.
* So "below D3" is only true on D15's stricter reading.

**Recommendation, in plain words.**
1. **For the MVP, take today's level.** About **95 bits whole-run** at the 8B T512
   workload (94.7, derived lookup bound), or about 99.7 on the work-factor reading.
   Record it as a deviation next to D3, with both readings. The costs:
   * an independent check of the derived lookup bound (§3.1; it is worth 2 bits for
     free);
   * no code;
   * no throughput.

   Raising it to D3's 97 on D15's reading would cost about **31 % of the 5090
   roofline** (57 → 40 positions/s). It would move the kernel efficiency needed for
   50/s from 34.5 % to 51 %, which would make the throughput goal, already the hard
   one, much harder.
2. **After the MVP, target 100 bits whole-run.**
   * Preferably reached through D1 (LogUp-GKR) with an Fp4 lookup challenge, if D1's
     privacy design lands, plus 259 column checks.
   * Otherwise through lookup repetition, at the 33 % throughput cost above.
   * 110 adds two proximity vectors and 285 column checks (+9 % receipt over 100).
3. **Keep 128 as the product target only.** It needs every challenge in Fp4: a
   D14-scale rewrite with an external review, about twice the receipt, and 35
   positions/s at 40 %. BLAKE3-256 caps the hash side at exactly 128.
4. **State every target per workload.** The lookup term grows with the number of
   lookups in a run, so "100 bits" at T512 is not "100 bits" at T2048.

---

## 2. The baseline, every term [COUNTED]

Geometry: Llama-3-8B, T512, row width 2^15. This is the speed plan's receipt-optimal
layout (`projection.best_layout(512)`); no 8B T512 profile is registered yet.
* Rate 1/4, Q = 256 column checks and pads.
* Per block: A 9,185 rows, H 11,056 rows. That is 0.663 G committed elements, and H is
  54.6 % of them.
* Receipt 2.226 GB per pass. The variant class reproduces the counted receipt, A rows
  and H rows exactly (asserted in the script).

| term | per unit | count per run | run total |
|---|---:|---:|---:|
| column test, A / H / B_k / endpoints | 2^-105.93 per opening (δ = 1 − (n+256)/4n) | 97 | — |
| column test, M (CFS masks) | 2^-106.25 per opening (RS(1024, 4096)) | 32 | — |
| **column term** | | 129 openings | **2^-98.99** |
| PCS field terms (proximity combination (e+1)/\|F\|, claim batching) | about 2^-113 per opening | 129 | 2^-106.38 |
| sumchecks (23 slots, rounds × degree + zero-check point + batching) | 2^-117.2 per block | 32 | 2^-112.19 |
| **LogUp, derived (N + 2304)/\|F\|** | 2^-99.73 per block (N = 323,026,944: U8 306,249,728 + exp 8,388,608 + act 8,388,608) | 32 | **2^-94.73** |
| LogUp, R14 convention 4N/\|F\| | 2^-97.73 per block | 32 | 2^-92.73 |
| **whole run** (union) | | | **2^-94.66 (derived) / 2^-92.71 (R14)** |

Lookups per domain and block:

| domain | D | Q | Kv | S (scores) | F (feed-forward) | L |
|---|---:|---:|---:|---:|---:|---:|
| U8 lookups | 71.3 M | 27.3 M | 6.3 M | 125.8 M | 75.5 M | 0.07 M |

The S and F domains also carry the exp and act pairs.

**The worst single round**: one block's LogUp α round, 2^-99.73 derived or 2^-97.73
under R14. The column test is 2^-105.93.

---

## 3. The levers

### 3.1 The lookup term (the one that binds)

**The two conventions differ by exactly 2 bits. Which bound is right for this LogUp
variant?**
* **R14's 4N/|F|** (`ZK60_FABLE_SECURITY_OBLIGATIONS.md` R14):
  * It was derived for the public-IO prover, as Schwartz–Zippel on P′Q − PQ′ with
    P = ∏(α − φ_j) and Q = ∏(α − ψ_i)^{m_i}.
  * That needs **integer** multiplicities with a checked total (R12), giving degree
    2N − 1. It then adds 2N/|F| for "pole avoidance".
* **The private block's variant is different.**
  * Its multiplicities `m` are free committed field elements, with no range or total
    check (`layout.rs:670-671`; the table slot `argument.rs:1862-1877` proves
    h_t · (α − τ_t) = m_t).
  * So R14's product form does not literally apply. The right statement is Haböck's
    logarithmic-derivative criterion (U. Haböck, *Multivariate lookups based on
    logarithmic derivatives*, ePrint 2022/1530): over a field of characteristic
    p > N, Σ_i 1/(X − a_i) = Σ_j m_j/(X − t_j) as rational functions holds only if
    every a_i is a table value.
  * Here p ≈ 2^64 is far above N ≈ 3.2 × 10^8 per block.
  * I could not fetch the PDF (HTTP 403), so no lemma number is quoted.
* **The derived bound** for one block, with the three tables of 256 distinct rows
  each:
  1. **The α identity.** The cleared numerator has degree below the number of distinct
     poles, at most N + 768. Error at most (N + 767)/|F|.
  2. **Tuple compression.** The first bad query collides with one of the 768 distinct
     compressed table rows under (β, γ). Error at most 768/|F|; each collision is a
     nonzero affine equation.
  3. **A table pole with zero multiplicity.** If α equals a table value whose m is 0,
     that row's helper is unconstrained (h · 0 = 0) and could balance the sum. Error
     at most 768/|F|.
  4. **Query-side poles are not a soundness term.** A hit makes h · (α − φ) = 1
     unsatisfiable, so the zero-check rejects. That is a refusal (D22 V-3), not an
     acceptance.

  Total **(N + 2303)/|F| ≈ N/|F|**.
* **Verdict.** 4N/|F| is a valid but loose upper bound for this variant, numerically
  above the derived one by 2.0 bits. Its derivation does not match this variant's
  free multiplicities. Adopting the derived bound is an accounting decision for the
  security owner, after an independent check. It is free: no code, no profile.

**Levers that shrink the term** [COUNTED soundness; MODEL cost]:

| lever | LogUp term per run | committed elements | receipt | CPU law | 5090 roofline at 40 % | privacy argument | new profile / review | lane-days |
|---|---:|---:|---:|---:|---:|---|---|---|
| derived bound instead of R14 | 2^-94.73 (from 2^-92.73) | 0 | 0 | 0 | 57.3 | none | no profile; security-owner sign-off | 0.5–1 |
| second independent (α, β, γ) for the S and F lookups | 2^-96.36 | +38.2 % | +22.7 % | +27.9 % | 42.7 | second helper set, its own table helpers and zero-sum row; split multiplicities (+3 Tab A planes) | yes; privacy re-check (rank/CFS tools on the new layout) and soundness review | 8–15 |
| the same for S, F and D | 2^-98.00 | +49.1 % | +29.3 % | +38.2 % | 39.7 | same | same | 8–15 |
| second independent (α, β, γ) for all lookups | 2^-194.5 | +54.6 % | +32.5 % | +43.4 % | 38.4 | same | same | 8–15 |
| LogUp challenges and helpers in Fp4 | 2^-222.7 | +54.6 % | +32.5 % | +43.3 % (modelled equal; Fp4 arithmetic is heavier) | 38.4 | helpers 4 limbs; terminal masks 4 rows per site; second zero-sum treatment | yes; new field arithmetic on CPU and GPU; review | 20–30 |
| D1 LogUp-GKR with the fraction tree in Fp4 (sketch, assumptions in the script) | 2^-222.7 | **−54.6 %** | not counted | not in the cost model | **37.5–56.3** (2 to 4 Fp2-equivalent element-terms per leaf, doubled for Fp4) | the D1 privacy design, which is open (speed plan: "a lookup recovered exactly from D/C") | yes; ruling, privacy design, review | 25–40 |

Notes:
* **Why Fp4 and not Fp3.** Goldilocks has a cubic extension (3 divides p − 1). But the
  sumcheck challenges live in Fp2, and Fp2 and Fp3 meet only in Fp, so mixing them
  means Fp6 arithmetic. Fp4 = Fp2[v]/(v² − u) is a tower over the existing Fp2. It is
  a field because u's norm, −7, is a non-residue mod p [COUNTED].
* **Splitting or batching lookups does not help.** Under a union bound the term is
  linear in the total number of lookups. Separate challenges per group, or one
  challenge for the whole run, give the same Σ N/|F|.
* **Fewer lookups would help.** 16-bit range tables instead of byte limbs give roughly
  N/2, about +1 bit, and also cut committed elements. But they reopen the P-3
  invariant `log(Tab) == log_cols` (`layout.rs:139-169`) and need a layout design.
  Not priced here.
* **Repetition must also draw β and γ again.** With shared (β, γ), the compression
  term 32 × 768/2^128 = 2^-113.4 becomes the floor.

### 3.2 The opening term

| lever | column term per run | receipt | prover time | 5090 roofline at 40 % | privacy argument | profile / review | lane-days |
|---|---:|---:|---:|---:|---|---|---|
| Q = 262 (checks = pads; M's Q too) | 2^-101.47 (+2.5 bits) | +1.4 % | ≈ 0 (not in the model; column gathering only) | 57.3 | unchanged in form (Q pads, any Q opened columns uniform); M's Q is capped at 512 − 122 = 390 at T512 | new profile (Q is in the profile string); re-freeze; joint-view gate at the new geometry | 2–3 |
| Q = 273 | 2^-106.0 (+7.0 bits) | +4.1 % | ≈ 0 | 57.3 | same | same | 2–3 |
| rate 1/8 at Q = 256 | 2^-101.25 (M becomes the limit) | ≈ 0 | +29.4 % (commit volume ×2) | **36.7** | unchanged in form | new profile | 2–3 |
| D14: batching openings across the 32 layers | 2^-103.67 (+4.7 bits) | small | a second encode pass, or keeping every block's encoded matrix (679 GB at T512) | not feasible on one 5090 without re-encoding | transcript order changes (indices after all blocks); each commitment still opened once | new run design; review | 15–25 |

So column checks dominate both alternatives. Batching across layers buys 4.7 bits; 12
extra column checks (Q = 268) buy 4.96 bits for +2.88 % of receipt. Lowering the rate costs a third of
the throughput.

### 3.3 Sumcheck and PCS field terms

Neither binds below about 105 bits (2^-112.2 and 2^-106.4 per run).
* **For 110:** a second proximity vector per opening takes the PCS field term to
  2^-113.4 (the claim-batching term then dominates). The cost is +3.1 % receipt,
  +0.2 % CPU, 0 on the roofline, and one more reserved proximity mask row per
  commitment. That changes the boundary row derivation to data + 2·sites + 3, so it
  needs a new profile and a joint-view re-check. 3–5 lane-days.
* **For 128:** the sumcheck term (2^-112.2) and the claim batching need every
  challenge in Fp4. Cost: committed +55.8 %, receipt +72 %, CPU +72 %, roofline 35.2.
  * Every mask, terminal pair, CFS mask and the D9 bias term must be re-derived.
  * This is a whole-prover field change of D14's scale, with an external review.
    40–60 lane-days.

### 3.4 The hash cap

Merkle binding rests on BLAKE3-256 collision resistance, a 128-bit generic bound
[MODEL]. Targets up to 128 need nothing; 128 has no headroom.

The Fiat–Shamir multi-round loss is not quantified anywhere in the project
(obligations §4.6). All figures here are interactive union bounds, except the
work-factor reading in §1.

---

## 4. Target bundles at 8B T512

The cheapest combination found for each target. Q is searched to the minimum that
reaches it.

| target | bundle | derived / R14 bits | committed per block | receipt per pass | laptop-CPU law per block | 5090 roofline 25 % / 40 % | anchored central (speed plan step 4) | kernel efficiency for 50/s | needs |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| today | B0 | 94.66 / 92.71 | 0.663 G | 2.226 GB | 51.98 s | 37.1 / 57.3 | 6.89 | 34.5 % | — |
| ~96 | derived bound + repetition on S, F | 96.14 / 94.30 | 0.916 G (+38.2 %) | 2.732 GB (+22.7 %) | 66.49 s (+27.9 %) | 27.4 / 42.7 | 5.47 | 47.4 % | new profile; privacy re-check; derived-bound sign-off |
| ~97 | derived bound + repetition on S, F, D | 97.41 / 95.83 | 0.989 G (+49.1 %) | 2.877 GB (+29.3 %) | 71.82 s (+38.2 %) | 25.4 / 39.7 | 5.09 | 51.2 % | same |
| ~96 under R14 | full repetition | 98.98 / 98.98 | 1.026 G (+54.6 %) | 2.950 GB (+32.5 %) | 74.56 s (+43.4 %) | 24.5 / 38.4 | 4.91 | 53.1 % | new profile; privacy re-check |
| ~100 | full repetition (or Fp4 LogUp) + Q = MQ = 259 | 100.21 / 100.21 | 1.026 G (+54.6 %) | 2.975 GB (+33.7 %) | 74.56 s (+43.4 %) | 24.5 / 38.4 | 4.91 | 53.1 % | same, plus the Q profile |
| ~110 | full repetition + two proximity vectors + Q = MQ = 285 | 110.24 / 110.24 | 1.026 G (+54.6 %) | 3.255 GB (+46.3 %) | 74.72 s (+43.8 %) | 24.5 / 38.4 | 4.90 | 53.1 % | same, plus the proximity row |
| ~128 | every challenge in Fp4 + Q = MQ = 327 | 128.30 / 128.30 | 1.034 G (+55.8 %) | 4.421 GB (+98.6 %) | 89.13 s (+71.5 %) | 22.5 / 35.2 | 4.17 | 58.2 % | whole-prover field change; external review |

Notes on the table:
* The roofline throughput of the 100 and 110 bundles is identical to full repetition's.
  The extra column checks and the proximity vector cost receipt bytes, not modelled
  device time.
* The receipt is the speed plan's measure: 32 × the block receipt.
* M's column ceiling (390 at T512) is never reached.
* **With D1 in place of repetition** (sketch, §3.1), the 100 and 110 bundles would keep
  their Q and proximity costs. Their committed data would fall 55 % instead of rising
  55 %. Roofline 37.5–56.3 positions/s, depending on the fraction tree's real cost.

---

## 5. Recommendation and the question to put to Victor

**Recommendation** [MODEL for the speed effects]:
* **MVP: accept today's level** at the 8B T512 workload: 94.7 bits whole-run (derived
  bound), 92.7 under R14, about 99.7 on the work-factor reading. Record it next to D3
  with both readings.
  * The only work is an independent check of the derived lookup bound (§3.1).
  * Do not spend throughput on 96–97 with the committed-H design. Every such bundle
    raises the kernel efficiency needed for 50/s by 13–19 points (34.5 % → 47–53 %).
    The speed plan already names that efficiency as the single number that decides
    the goal.
  * If Victor nonetheless wants parity with D3 on D15's reading, the cheapest bundle is
    repetition on the S, F and D lookups: 97.4 bits, 39.7 positions/s at 40 %
    (−31 %), +29 % receipt.
* **Post-MVP: 100 bits whole-run.**
  * Through D1 (LogUp-GKR) with an Fp4 fraction-tree challenge, plus Q = 259, if the D1
    privacy design succeeds. The sketch suggests that is the only route that does not
    trade throughput for bits.
  * Otherwise through full repetition (−33 % throughput).
  * 110 adds two proximity vectors and Q = 285.
* **Product: 128 bits** needs an all-Fp4 prover (D14-scale) and is not an MVP item.

**Proposed wording of G.0-2 for Victor** (for the coordinator to adapt):

> The custom line's soundness target is stated **per run at a named workload** (today:
> Llama-3-8B, T = 512), as a whole-run union bound, with the forger-work reading quoted
> beside it.
> * **MVP:** about 95 bits whole-run (about 99.7 work-factor) is accepted as a recorded
>   deviation, next to the zkVM's 97 conjectured (D3), provided the derived lookup bound
>   passes an independent check. Without that check it is 92.7.
> * **Next milestone:** 100 bits whole-run, preferably through LogUp-GKR with a
>   256-bit lookup challenge.
> * **Product:** 128.
>
> Yes / no / other figure?

---

## 6. Reproduction and limits

* `python3 -B results/zk60_soundness_recount_20261017/g02_levers.py` prints every table
  above and writes `g02_levers.json` (`g02_levers.out.txt` is a copy of the printout).
  One thread, 0.25 s, about 13 MB.
* It imports the speed plan's `layout.py`, `cost_model.py` and `projection.py` from
  verbatim copies in `g02_speedplan_copy/` (sha256 equal to the originals, recorded in
  `PROGRESS.md`). The originals are untouched.
* Limits:
  * **Prover time is [MODEL].** The laptop-CPU phase law is fitted on TinyLlama T128
    and validated within 3 % at 8B T32. The roofline uses the speed plan's counted
    bytes per unit at a fraction of the 5090's 1.792 TB/s.
  * **Lever models are first-order.** Repetition doubles the H helper planes, their
    claim sites, table helpers, the zero-sum row and the helper inverses. Fp4 terms are
    priced as two Fp2 terms (bandwidth), which is optimistic for compute. Two proximity
    vectors add one fold per opening.
  * **The D1 rows are a sketch** with a stated assumption, not the cost model.
  * **Q's prover cost is not in the model.** It is column gathering only, and small.
  * **Not covered:**
    * the Fiat–Shamir multi-round loss;
    * the standing assumptions of the block (for example R31);
    * any privacy property: each "privacy argument" cell is an inventory of what would
      have to be re-checked, not a claim;
    * the T512 profile itself (unregistered; calibration and F_P fidelity open,
      speed plan §3).
* Nothing here changes the D15 correction note of 19:40 UTC. At T512 the pad dilution
  is 0.3 bits per opening and invisible in the whole-run figure.
