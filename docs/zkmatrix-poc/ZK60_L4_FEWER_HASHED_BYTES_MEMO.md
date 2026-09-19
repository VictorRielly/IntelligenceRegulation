# L4 — fewer hashed bytes: a costed memo

**Status: DRAFT — delegated, commissioned under D14, to be checked
independently and reviewed by the security owner; paper only.**
Written 2026-09-19. No code was built, no run was launched, nothing in the
tree was changed except this file.

---

## A. Plain words, for the owner

**The question.** Lever L4 says: shrink the data the prover has to
Reed–Solomon-encode, Merkle-hash and stream through the graphics card.
Two ways to shrink it. (1) *The rate half* — encode each row to twice its
length instead of four times, so the encoded object halves. (2) *The field
half* — carry every number in 32 bits instead of 64, so the encoded object
halves again. The plan's step 6 hoped this would take a 5090 from 10–15 s
to 5–10 s per proof. This memo prices it.

**Verdict, in one line: no. 5 s is outside the range, on the 4070 and on
the 5090, with both halves of L4 applied.** The reason is arithmetic, not
pessimism: the block L4 attacks — the encode, the opening's re-encode and
the hashing — is **28.18 s of the measured 58.40 s pass, 48.3%**
[MEASURED, `results/hashline_convert_r3.log`]. Even if that block cost
**nothing at all**, the pass would be 30.2 s. That is a hard ceiling of
**1.93×** on this card, and after the ladder's steps 1–4 have already
trimmed the same block, the ceiling on a 5090 is **7.4–9.2 s**
[MODEL, §E]. L4 cannot reach 5 s because there is not 5 s of encoding
left to remove once the rest of the pass is counted.

**Three findings that matter more than the verdict.**

1. **The lever is misnamed. Hashing is not the cost; encoding is.** The
   device hash counter reads **0.481 s of 58.40**, 0.8% of the pass
   [MEASURED]. The encode NTT reads 13.877 s and the opening's re-encode
   13.826 s. "Fewer hashed bytes" buys almost nothing on the hash line;
   everything it buys, it buys on the two transform lines. (The 0.481 s
   counter is also internally inconsistent with the volume — see §H.)

2. **The rate half's real price is a soundness *assumption*, not extra
   queries — and the project has already written down the assumption and
   declined it.** Today the code reads 106 bits from
   `(1 − δ/3)^256 = (3/4)^256 = 2^−106` at rate 1/4
   (`zkp-core/src/pcs.rs:17-19`). Under that same conservative δ/3 radius,
   rate 1/2 needs **404 opened columns instead of 256** to stay at 106
   bits, and the proof grows from 1.23 GB to **1.95 GB**. But
   `ZK60_FABLE_SECURITY_OBLIGATIONS.md:376` records the alternative — the
   BCIKS20 proximity-gap radius δ/2 — and explicitly does not adopt it.
   Under δ/2, **rate 1/2 with the unchanged 256 columns gives 2^−106.2,
   exactly today's bit level**, with no extra queries, no extra proof
   bytes and no extra masking budget. The rate half is therefore either
   cheap and assumption-dependent, or assumption-free and it makes the
   proof 58% bigger. That is the choice, and it is a ruling, not a lane.

3. **The field half gives back most of what it takes, and may give back
   more than it takes.** A 31-bit field cannot hold this project's
   integers. The largest proved relation at the real 8B shape is the
   RMSNorm square-check with an int24 residual at **≈ 2^58**
   (`ZK60_FABLE_SECURITY_OBLIGATIONS.md:101, :111`); the down-projection
   accumulator is **2^35.8** (`hashline/src/export_v3.rs:30`); the
   feed-forward Hadamard term is **1,610,637,311**, already above
   q31/2 ≈ 2^30 (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2.md:975-1000`).
   Holding those in 31 bits means splitting values into committed limbs,
   which adds committed rows, adds range-check lookups, adds LogUp helper
   rows and adds host→device planes — and the helpers are already the
   single largest phase of the private pass (146.26 s of 265.34, 55%).
   Modelled honestly, the field half is worth between **1.24× and 1.08×**
   on the 4070 (§D) — and the 1.08× end is inside the box's own noise.

**What it would cost to find out.** The rate half is not a rewrite: the
rate is already a parameter (`--inv-rate`, `PcsParams::inv_rate`) and the
GPU test already sweeps 2/4/8. Its cost is the re-freeze and the review:
**3–5 lane-weeks**, of which the code is perhaps one. The field half is a
rewrite of the field, NTT, PCS and CUDA layers (**10,057 lines** define
the two knobs; ~54,500 lines are in scope), plus a new no-wraparound
theorem, plus a new range registry, plus re-derivation of three recorded
soundness items (R09, R31, F7): **12–20 lane-weeks and an external
review**. Both change every frozen proof digest: **4 digest/length pairs
in one authoritative table**, mirrored into 3 Python tests, 2 Python
scripts, 2 Rust files, ~11 shell gates, ~20 documents and 40 checked-in
manifests, plus ~41 distinct sha256 pins in live code.

**The one number that should decide it.** The whole 8B proof's soundness
is already **2^−94.1**, not 2^−106, once the union bound over 32 layers ×
6 openings is taken (`ZK60_FABLE_SECURITY_OBLIGATIONS.md:406-408`). The
106 is a per-opening figure. If the owner's target is a *whole-proof* bit
level, the queries must **rise**, not fall, and every line of §C gets
worse. That ruling should come before any lane is spent.

## B. The baseline — what is encoded and hashed today

All of §B is the **public-IO v3 profile, Mistral-7B, 32 feed-forward
blocks, 512 tokens, laptop RTX 4070 (8,188 MiB), 8 CPU threads, cold
weight cache**, the fastest 8B pass this project has run. Source:
`results/hashline_convert_r3.log` (the `prover phases` block and the
`gpu device-side` line at the tail), reproduced in
`results/hashline_convert_gpu.md` §7 and
`ZK60_FIVE_SECOND_PLAN.md` §1.2. Proof `dc980e81…4536c`,
1,234,936,956 B.

### B.1 The scheme's parameters

| parameter | value | where |
|---|---|---|
| base field | Goldilocks `p = 2^64 − 2^32 + 1`, 8 B per element | `zkp-core/src/field.rs:10` |
| challenge field | quadratic extension `F_{p^2} = F_p[u]/(u^2 − 7)`, ≈ 2^128 | `zkp-core/src/field.rs:1, :133-137` |
| commitment class | Ligero/Brakedown: RS-encode the rows, blake3-hash the columns, open Q random columns | `zkp-core/src/pcs.rs:1-27` |
| message width | `2^log_cols`, `log_cols = 14` → **16,384** | `hashline/src/bin/hashline.rs:59` |
| **inverse rate** | **`inv_rate = 4`** → codeword **65,536** | `hashline/src/bin/hashline.rs:59`; `zkp-core/src/pcs.rs:51-53` |
| **opened columns** | **`num_col_checks = 256`**, drawn from the transcript with replacement | `hashline/src/bin/hashline.rs:59`; `zkp-core/src/pcs.rs:376, :456`; `zkp-core/src/transcript.rs:119-131` |
| Merkle | blake3, binary, 32-byte digests, **columns are the leaves**, paths **full height** (16 levels), no cap | `zkp-core/src/merkle.rs:6, :14-34, :46-54`; `zkp-core/src/ffn_v3/proof.rs:190` |
| per-column proof bytes | `8 + rows·8 + path_len·32` (plain); `+32` salt in ZK | `zkp-core/src/ffn_v3/proof.rs:192-194`; `zkp-core/src/pcs.rs:579` |
| ZK pad symbols per row | `q_pad = num_col_checks` — hiding is **exactly saturated** at Q openings | `zkp-core/src/pcs.rs:540-544`, asserted `:670`, `:892` |

`inv_rate` is **not** overridden per commitment: `pcs_for()` narrows only
`log_cols` and inherits rate and Q (`zkp-core/src/ffn_v3/statement.rs:29-31`).
The other rates the code speaks of are per-*profile*, not per-commitment:
the private block, private attention, the fresh-FFN PoC, the causal
oracle and the private seam all use `log_cols 8, inv_rate 8, Q 256`
(`hashline/src/private_block/protocol.rs:21-23` and siblings), and the
mask commitment is its own RS(1024, 4096) with `MASK_Q = 256`
(`hashline/src/zk.rs:373-375`). Rate 2 appears only in tests and in the
GPU sweep `hashline/tests/zk60_gpu_commit.rs:305`.

### B.2 What is committed per layer, in rows, elements and bytes

| commitment | contents | elements/layer | rows × message cols | message bytes | **codeword bytes** |
|---|---|---:|---|---:|---:|
| **W** | gate, up, down weights, int8 values widened to `Fp` | 176,160,768 [MEASURED, log `conv W … 176 Melem`] | **10,752 × 16,384** [COUNTED: 176,160,768 / 16,384] | 1.409 GB [cross-checked: lane AL's staging buffer is 1.409 GB] | **5.637 GB** |
| **A** | activation planes (x, g8, u16, a16, h16, z16) | ≈ 57.6 M [MEASURED, `conv A … 57 Melem`; buffer 0.461 GB] | ≈ **3,517 × 16,384** [COUNTED] | 0.461 GB | **1.844 GB** |
| **H** | LogUp helper planes (field inverses — full-width, not narrow data) | ≈ 71.7 M [COUNTED, §B.3] | ≈ **4,379 × 16,384** [COUNTED, §B.3] | 0.574 GB | **2.297 GB** |
| **total** | | | ≈ **18,649 rows** | **2.44 GB** | **9.78 GB** |

Per 32-layer proof: **78 GB of message data encoded into 313 GB of
codeword, and 313 GB of codeword Merkle-hashed** [COUNTED]. The opening
re-encode regenerates essentially the same volume a second time (its
measured 13.826 s against the commit's 13.877 s), so the pass moves
roughly **626 GB of field elements through the encoder** and 313 GB
through the hasher.

**How B.2's row counts were obtained, and their status.** `rows_W` is
exact: 176,160,768 / 16,384 = 10,752, and it is confirmed twice —
lane AL's host staging pool is 1.409 GB (= 10,752 × 16,384 × 8) and §2 of
the five-second plan counts the persisted encoded weight rows at
"5.6 GB per layer, 180 GB per model" (= 5.637 × 32 = 180.4). `rows_A` is
from the second staging buffer (0.461 GB → 57.6 M elements). `rows_H` is
**reconstructed, not read from code** (§B.3) — see §H.

### B.3 Reconstructing the proof's composition [COUNTED]

Per layer the proof is 1,234,936,956 / 32 = **38,591,780 B**, i.e.
**150,749 B per opened column**. With three commitments, three full-height
16-level paths and the per-column format `8 + rows·8 + path_len·32`:

```
150,749  =  3·8  +  R·8  +  3·16·32  +  (transcript residue)
R  =  (150,749 − 24 − 1,536) / 8  =  18,649 rows        [COUNTED]
rows_H  =  18,649 − 10,752 − 3,517  =  4,379            [COUNTED]
```

Two consequences, both load-bearing for §C:

* **The proof is ~99% column payload and ~1% Merkle path.** Paths are
  3 × 16 × 32 = 1,536 B of the 150,749 B per column = **1.02%**. So
  **proof bytes scale essentially linearly in Q** and barely at all in
  the tree height.
* **The "Merkle cap = −29% of the proof bytes" figure quoted in
  `ZK60_FIVE_SECOND_PLAN.md` §5 and `ZK60_DECISIONS.md:408` is a
  *compact-PCS* number, not a Ligero number.** Its source,
  `PROVING_CHANNEL_OPTIONS.md:244-248`, says so explicitly: "13.5 MB →
  ~9.6 MB at 125M and 62 MB → ~44 MB at 8B … because ~half the opening
  is path digests (110 levels × 32 B across ~10 trees, times **157
  queries**)". 157 queries is the compact backend
  (`hashline/src/pcs_compact.rs:103`). On the Ligero proof the same cap
  is worth about **1%**, not 29%. D14 asked what L4 does to proof size;
  this correction belongs with the answer.

### B.4 Where the 58.40 s goes [MEASURED, NOISY-SHARED, 2026-09-04]

| phase | seconds | share | scales with |
|---|---:|---:|---|
| **encode transform (NTT)** | **13.877** | 23.8% | codeword bytes = rows × n × inv_rate × width |
| **opening re-encode** | **13.826** | 23.7% | codeword bytes (bulk) + opened-column count (tail) |
| **hashing** | **0.481** | 0.8% | codeword bytes |
| host→device transfer | 8.597 (9,328 MB) | 14.7% | **int8 planes — neither rate nor field changes it** |
| sumchecks | 5.465 | 9.4% | number of instances × extension-field cost |
| folds | 2.850 | 4.9% | message bytes |
| helper kernels | 1.378 | 2.4% | message bytes |
| *device subtotal* | *46.47* | *79.6%* | |
| **host residue** | **11.93** | **20.4%** | nothing in L4 touches it |
| **total** | **58.40** | | |

Prover-phase view of the same run: commit W 19.823, commit A 4.838,
helpers + commit H 5.555, matmul g/u 3.441, matmul d 2.092, zero-check
F 4.651 + D 0.817, PCS openings 17.176.

**The block L4 attacks is encode + re-encode + hash = 28.18 s = 48.3% of
the pass.** Everything else — 30.22 s — is outside the lever.

## C. The rate half, costed alone

The rate half keeps the field, so it keeps every integer bound, every
range decomposition, every no-wraparound argument and the whole
statement. It is by far the cheaper of the two.

### C.1 The soundness accounting, reproduced from the code's parameters

The code states its own formula at `zkp-core/src/pcs.rs:17-19`:

> Soundness (Brakedown Thm. with the conservative delta/3 bound): with
> RS relative distance `delta = 1 - 1/inv_rate` the column test fails to
> catch a far matrix with probability `(1 - delta/3)^Q`; at `inv_rate 4,
> Q = 256: (3/4)^256 = 2^-106`. Field terms are `O(n / 2^128)`.

**Reproduced exactly** [COUNTED]: `δ = 1 − 1/4 = 3/4`; `δ/3 = 1/4`;
per-query error `1 − 1/4 = 3/4`; `−log2(3/4) = 0.41504` bits per query;
`256 × 0.41504 = 106.25 bits`. The 106 is the query/proximity term. The
separate field term is the Schwartz–Zippel / batching cost over the
quadratic extension, `O(n/|F_{p^2}|)` ≈ 2^−103 at n = 2^25, plus
`(e+1)/|F_{p^2}| ≈ 2^−119` per opening for the random row combination and
`4N/|F_{p^2}| ≈ 2^−111` for LogUp
(`ZK60_FABLE_SECURITY_OBLIGATIONS.md:371, :376-379`).

**The regime is unique-decoding-class, not a list-decoding conjecture**,
and the repository says so twice: `pcs.rs:16` ("the conservative delta/3
bound") and `ZK60_FABLE_SECURITY_OBLIGATIONS.md:376` — *"The
proximity-gap regime (e < d/2, BCIKS20) would give `(9/16)^256 = 2^-212`
with a larger field term; it is NOT what the code documents and is not
adopted here."*

**The 106 is per opening.** Over 32 layers × 6 openings the union bound
puts the whole 8B proof at **2^−94.1**
(`ZK60_FABLE_SECURITY_OBLIGATIONS.md:406-408`), against a *product*
target of 128 bits that `ZK60_DECISIONS.md:78-79` records as unchanged
and `ZK60_MVP_COMPLETION_PLAN.md:228` (gate G13) records as already
deviated.

### C.2 What rate 1/2 costs in queries — the fork in the road

| regime | source | rate 1/4, Q = 256 | rate 1/2, Q = 256 | Q needed at rate 1/2 for 106 bits |
|---|---|---:|---:|---:|
| **δ/3** (what the code documents) | `pcs.rs:16-19` | **2^−106.2** | 2^−66.2 | **404** (the repo's own count: **403**, `U_PERF3_ROUTE_B_THROUGHPUT.md:629-631`) |
| **δ/2** (BCIKS20, cited and declined) | `ZK60_FABLE_SECURITY_OBLIGATIONS.md:376` | 2^−173.6 | **2^−106.2** | **256 — unchanged** |

This is the whole story of the rate half. **Under δ/3 the rate change
costs 1.58× the opened columns and 1.58× the proof bytes. Under δ/2 it
costs nothing at all in queries, because rate 1/2 at δ/2 lands on exactly
the same 2^−106.2 the project quotes today.** The price is not queries;
the price is which theorem the security owner is willing to stand behind.
I state that as a finding, not a recommendation: the δ/2 derivation for
the *interleaved* RS column test carries "a larger field term" (already
counted above at 2^−119 per opening) and must be signed by whoever owns
soundness, exactly like the δ/3 form is today.

Two secondary observations from the same table, recorded because they are
free and the owner should see them:

* Under δ/2 at the **current** rate 1/4, 256 columns read 2^−173.6 — i.e.
  106 bits would need only **157** columns, which is precisely the number
  the compact backend already derives (`pcs_compact.rs:1236-1238`,
  `queries_for(4, 106) == 157`). The project's two backends therefore
  already use **different proximity radii** (`δ/3` for Ligero, `(1−ρ)/2`
  for the FRI form, `pcs_compact.rs:122-125`). That inconsistency is
  worth a ruling on its own terms, independent of L4.
* Going the other way — rate **1/8** — needs only 214 columns for 106
  bits under δ/3 and would *shrink* the proof, at the cost of doubling the
  encode. Rate is a direct dial between prover seconds and proof bytes at
  fixed soundness, and the project is currently in the middle of it.

### C.3 The pad feedback, which the repo's "403" does not include

In the **hiding** profile the message is not `n` but `n + Q`: each row
carries Q fresh pad symbols so that any Q opened positions are jointly
uniform (`hashline/src/zk.rs:11-20`; `q_pad = num_col_checks`,
`zkp-core/src/pcs.rs:540-544`). The effective rate is therefore
`(n + Q)/(n · inv_rate)`, and raising Q to fix soundness *lowers* the
distance, which needs more Q. Solving the fixed point [COUNTED]:

| profile | n | inv_rate | effective rate | bits at Q = 256 | Q for 106 bits |
|---|---:|---:|---:|---:|---:|
| 8B ZK v3 today | 16,384 | 4 | 0.2539 | **2^−105.6** (matches `zk.rs:1906-1909`) | 257 |
| 8B ZK v3 at rate 1/2, **δ/3** | 16,384 | 2 | 0.5127 | 2^−66.2 | **415** |
| 8B ZK v3 at rate 1/2, **δ/2** | 16,384 | 2 | 0.5078 | **2^−104.3** | 261 |
| private block today | 256 | 8 | 0.2500 | **2^−106.2** | 256 |
| private block at inv_rate 4, **δ/3** | 256 | 4 | 0.5000 | 2^−67.3 | **impossible — max 74.1 bits at any Q** |
| private block at inv_rate 4, **δ/2** | 256 | 4 | 0.5000 | **2^−106.2** | 256 |

**The private block cannot halve its rate under δ/3 at all.** At
`log_cols 8` the 256 pad symbols already consume a quarter of the
codeword; halving the codeword leaves no room, and the achievable maximum
over all Q is 74.1 bits. Under δ/2 it works at Q = 256 unchanged. This is
the sharpest form of the same fork.

### C.4 Seconds on the RTX 4070

The encoder is a zero-padded radix-2 NTT: a row of `n` coefficients is
evaluated at `n · inv_rate` points (`zkp-core/src/ntt.rs:1-4`), and the
first `log2(inv_rate)` stages of a zero-padded transform are a broadcast,
not arithmetic (lane AO's measured lever). Useful work is therefore
`nn × log2(n)` — `65,536 × 14` today against `32,768 × 14` at rate 1/2 —
**a factor of exactly 2.00**, on both the butterfly count and the bytes
moved. The measured kernels run at 197.6–200.5 GB/s, 77–78% of the
256 GB/s roof (`ZK60_FIVE_SECOND_PLAN.md` §4.2), so they are
bandwidth-bound and the byte halving converts.

| phase | today | rate 1/2, Q = 256 (δ/2) | rate 1/2, Q = 404 (δ/3) | basis |
|---|---:|---:|---:|---|
| encode NTT | 13.877 | **6.94** | **6.94** | ×0.50 [MODEL: codeword bytes halve; bandwidth-bound] |
| opening re-encode | 13.826 | **6.91** | **8.64** | ×0.50 bulk; the δ/3 arm adds ×1.25 for the Q-dependent tail (the pruned final stage serves 404 sampled outputs of 2,048 residues instead of 244 of 4,096) |
| hashing | 0.481 | **0.24** | **0.24** | ×0.50 [MODEL] |
| h2d transfer | 8.597 | 8.597 | 8.597 | unchanged — int8 planes |
| sumchecks | 5.465 | 5.465 | 5.465 | unchanged |
| folds + helpers | 4.228 | 4.228 | 4.228 | unchanged — message domain |
| host residue | 11.93 | 11.93 | 12.23 | +0.3 s to split 404 column vectors instead of 256 |
| **8B prove** | **58.40** | **44.3 s (1.32×)** | **46.3 s (1.26×)** | [MODEL] |

Codeword bytes fall 313 GB → **157 GB** per proof; hashed bytes the same;
encoder throughput 626 GB → **313 GB**.

### C.5 Seconds on an RTX 5090

Using the project's own model and nothing else
(`U_PERF3_THROUGHPUT_MODEL.md` §3.3 via `ZK60_FIVE_SECOND_PLAN.md` §4.1
and §4.3: composed factor `1/(c/k_c + g/k_g + l/k_l)`, same host CPU so
`k_c = 1`, `k_g` 4–7, `k_l` 1.5–3):

| arm | host | link | device | 5090 total |
|---|---:|---:|---:|---:|
| today (§4.3 of the plan, reproduced) | 11.93 | 8.597/1.5–3 | 46.47/4–7 | **20.2–27.1 s** |
| rate 1/2, Q = 256 | 11.93 | 8.597/1.5–3 | 23.78/4–7 | **17.1–23.6 s** |
| rate 1/2, Q = 404 | 12.23 | 8.597/1.5–3 | 25.80/4–7 | **17.8–24.8 s** |

The rate half is worth **2.3–3.5 s on a 5090** applied to today's code,
because the card has already divided the block it attacks. §E applies it
where the plan actually puts it — after steps 1–4.

### C.6 Proof size and verifier time

| | today | rate 1/2, Q = 256 | rate 1/2, Q = 404 |
|---|---:|---:|---:|
| proof bytes (8B, 32 layers) | 1,234,936,956 | **1,234.5 MB** (−0.03%: path 15 levels not 16) | **1,948 MB (+57.7%)** |
| against the frozen 1,114,112 B budget | 1,108× over | 1,108× over | **1,749× over** |
| verify (measured 1.08 s) | 1.08 | ≈1.08 | ≈1.6 s [MODEL, ∝ Q] |

The δ/3 arm therefore **moves the project's worst contract miss 58% in
the wrong direction** and pushes the verifier towards the 2 s budget
(`TARGET_CONTRACT.md:139`). The δ/2 arm is neutral on both.

### C.7 Does the private profile's hiding survive?

Checked against the constants, not assumed. Nothing here is a privacy
claim; it is an inventory of what the code enforces.

* **Pads per row = opened columns, exactly.** `q_pad = num_col_checks`
  (`zkp-core/src/pcs.rs:540-544`), asserted `q_pad >= num_col_checks` at
  commit time (`:670`) and re-asserted at the audit site (`:892`). The
  argument in `hashline/src/zk.rs:11-20` is a bijection on exactly Q
  points, so the budget is saturated, not slack: the (Q+1)-th opened
  position of one commitment is not covered. This is why the code drops
  each commitment immediately after its single opening
  (`hashline/src/private_block/protocol.rs:390-400`).
* **A and H have no ceiling, only a cost.** Extra pads are
  `rows × Q` extra field draws (`zkp-core/src/pcs.rs:673`) plus Q extra
  clear entries per group (`:568-570`). At the private block that is
  `(455 + 384) × ΔQ` draws.
* **The mask commitment M has a hard ceiling.** Each M row holds 512
  message positions (`MASK_LOG_MSG = 9`, `hashline/src/zk.rs:373`); a row
  carries `L` CFS coefficients plus `MASK_Q` pads, and both the runtime
  (`zk.rs:442`) and the layout test
  (`hashline/src/private_block/layout.rs:728-735`) enforce
  `L + MASK_Q <= 512`. The worst slot is `L = 50`, so **Q ≤ 462**. The
  δ/3 arm at the 8B ZK shape needs Q = 415 — it fits, with 47 of slack.
  The escape hatch (`MASK_LOG_MSG 9 → 10`) doubles the M domain and
  changes the degree-<1024 arithmetic at `zk.rs:352, :453-459, :498-500`.
* **Q is transcript-bound, so this is a wire change.** The private
  schedule string is literally
  `"… n=256 inv_rate=8 Q=256; P1 …"` (`layout.rs:653-659`) and Q is
  encoded into the receipt (`private_block_contract.rs:231, :537`).
  Changing either knob changes the schedule digest and the receipt bytes.
* **Verdict for §C:** under δ/2 with Q unchanged, nothing in the hiding
  machinery moves at all. Under δ/3 with Q = 415, A/H pads grow linearly
  and M fits with 10% of its budget left — but the private block's own
  shape (`log_cols 8`) cannot take the rate change under δ/3 at any Q.

### C.8 The video-memory effect, which may be the rate half's best argument

The public 8B pass peaks at 5,249 MB on an 8,188 MiB card; **the private
8B pass peaks at 8,585 MB and pages**, which is why layer 0 proves in
4.36 s and layers 1–31 in 8.42 s, and why this box froze three times
(`results/hashline_zk_8b_gpu.md:29`; `ZK60_FIVE_SECOND_PLAN.md` §3.F).
A rate-1/2 codeword halves the largest device-resident buffers — the
encoded scratch per chunk. If encoded scratch is 50–70% of the private
peak, the peak falls to **≈ 5,600–6,600 MB** [MODEL, assumption named],
i.e. inside the 8 GB card, which the plan values at **~1.9×** on the
private pass. **This can be settled on paper without a run**:
`scripts/hashline_memory_plan.py` counts the GPU buffers of one
`dev_commit_zk_from` call and its buffer counts scale with `inv_rate`.
Caveat from the same plan: CL1's chunking may already have collected this
(per-layer private peak 5,182 MB with 37% headroom), in which case the
two must not be multiplied.

## D. The field half, costed alone

### D.1 The constraint: the statement is exact integer arithmetic

The proof does not compute modulo p; it *embeds* exact integer arithmetic
in the field, and every relation is an identity between integers **only
if no term wraps**. The code says so in a block it calls the
CONSTRUCTION PREMISE, and says it is not machine-checked:

> **CONSTRUCTION PREMISE** (integer soundness; to be re-derived by the
> reviewer, **not checked by code**). Every relation of `argument::define`
> is an identity between integers only if no term wraps the 64-bit field.
> — `hashline/src/private_attention/layout.rs:200-227`, and the same block
> for the feed-forward at `hashline/src/private_block/layout.rs:280-309`

The accepted review `ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md` re-derived
the bound over the **verifier-enforced** ranges (not honest values — `:35-38`)
and found `562,949,886,312,450 < 2^49` as the worst case over all 26
constrained expressions (`:172-174`), with the maximum being the RMSNorm
integer-square-root check `Dsq − D·D` at **5.63e14** (`:151`).

### D.2 The largest integer each family reaches at the 8B shape

`p/2` for a 31-bit prime is ≈ **2^30 ≈ 1.07e9**. Every row below is
measured against that.

| family | largest value at the real 8B shape | bits | cite | fits 31-bit? |
|---|---:|---|---|---|
| **RMSNorm isqrt square-check, int24 residual, d = 4096** | `SSe ≈ 4096 · 8,388,607² ≈ 2.9e17` | **≈ 2^58** | `ZK60_FABLE_SECURITY_OBLIGATIONS.md:101, :111, :459` | **no — 28 bits over** |
| **FFN down accumulator** `dacc = h16 · WdT`, f = 14336 | `14336 · 32767 · 127 = 5.97e10` | **2^35.8** | `hashline/src/export_v3.rs:30` (verbatim: `|dacc| <= f * 32767 * 127 < 2^36: i64`) | **no — 6 bits over** |
| norm division `y · D · 2^(tn+1)` | — | < 2^44 | `private_attention/layout.rs:212`; R2:154, :180 | **no — 14 bits over** |
| int24 norm remainder `dvp = 2·D·2^tn` | — | 2^37 | `ZK60_FABLE_SECURITY_OBLIGATIONS.md:101` | **no — 7 bits over** |
| **FFN Hadamard** `a16·u16 − 2^14·h16 − rh + 2^13` | **1,610,637,311** | just over 2^30 | `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2.md:975-1000`; `private_block/layout.rs:305-307` | **no — over p/2 by 0.6 bits** |
| FFN `hh = a16 · u16` | 1,073,741,824 | = 2^30 | TIER2 row 5 | **at the edge** |
| tiny-profile isqrt `Dsq − D·D` (limb-driven, D,a1,a2 < 2^24) | 562,949,886,312,450 | 2^49 | R2:151, :172-174 | no — 19 bits over |
| gate/up accumulator, int8×int8, d = 4096 | 66,064,384 | s27 | `ATTENTION_INTEGER_SPEC.md:688-696`; `TARGET_CONTRACT.md:42-46` | **yes** |
| int8×int8 accumulator at inner 14336 | 231,225,344 | s29 | `ATTENTION_INTEGER_SPEC.md:688-696` | **yes, 1.2 bits of margin** |
| attention score / PV accumulators | 2,064,512 / 133,247,488 | s22 / s28 | same | yes |
| LogUp multiplicities | ≤ 61,440 | — | `private_block/layout.rs:308-309` | yes |

**Two structural facts that decide the field half.**

1. **It is not the matmuls that break.** The int8×int8 accumulators at
   4096 and 14336 already fit a 31-bit prime — indeed the project's
   *other* line proves exactly these at `q31 = 2^31 − 399`
   (`TARGET_CONTRACT.md:42-46`: "27-bit signed (inner 4096) / 29-bit
   signed (inner 11008) — worst-case exact at q31"). So there is an
   existence proof for the matmul half.
2. **It is the widenings that break.** The int16 activation classes
   adopted in `U_PERF3_QUANTIZATION_MEASUREMENTS.md:28-36, :84-86`
   ("u/z at 2^15, **h at 2^30**") and the **int24 residual** that
   accuracy forced (`TASK_BOARD.md:1181-1191`: "xres needs int24 …
   the seam is int24") are what put 2^30, 2^35.8 and 2^58 into the
   statement. The lattice line survives 31 bits precisely because it
   kept everything int8 — and that is the accuracy the hashline
   statement rejected.

### D.3 What a 31-bit base field would force, option by option

| option | what it does | committed bytes | sumcheck rounds / lookups | soundness | verdict |
|---|---|---|---|---|---|
| **(a) Limb-decompose the wide values and commit the limbs** | split `a16`, `h16`, the down accumulator and the norm chain into ≤ 15-bit limbs with carry relations; re-derive the range registry (currently w ∈ {1,9,10,11,14,18}, `ATTENTION_INTEGER_SPEC.md:528-537`) | **grows**: each split plane is 2 committed planes at half the width (byte-neutral) **plus** a new range fact and its LogUp helper rows (not byte-neutral) | more instances, more lookups; `helpers + commit H` is already 5.555 s public and **146.26 s of 265.34 (55%) private** | new no-wraparound theorem; R09's half-p isqrt alias exclusion rests on "the (tn, n_limbs) coincidence" and must be redone at the new p (`ZK60_FABLE_SECURITY_OBLIGATIONS.md:95-103`) | **the realistic path, and the one that eats the gain** |
| **(b) Prove modulo several small primes (CRT/RNS)** | run the argument 2–3× at different 31-bit primes | ×2–3 | ×2–3 | needs a CRT-composition argument | **dead: costs more than the 2× it buys** |
| **(c) 31-bit field for committed data, 64-bit for the relation layer, with a lifting argument** | the PCS commits narrow data; the sumcheck runs over Goldilocks | best case ×0.5 on W and A only | a new cross-field bridge argument | **new cryptography**: the Ligero column test and the sumcheck must agree on one field, or a lookup/lift argument must prove the 31-bit committed values equal the 64-bit ones | **not an optimization — a new scheme, with its own written soundness argument and external review** |
| **(d) Degree-4 extension for challenges** | `F_{p^4}`, ≈ 2^124, as the 31-bit STARK systems use | none | extension mult goes 3 base-mults (Karatsuba deg 2) → ~9 (deg 4); base mults are ~2–2.5× cheaper at 31 bits, so extension arithmetic is **≈ 1.2× worse, not better** | every field term loses ~4 bits: `O(n/2^128)` → `O(n/2^124)`; at n = 2^25 that is 2^−99 instead of 2^−103 | **mandatory with (a); it is a cost, not a saving** |

Note on (d) and list decoding: lane AF already recorded that the Johnson
regime's field term is `~L²/|F|`, "2^−64 at L = 2^24 over `F_{p^2}` — not
usable at this field" (`PROGRESS_UPERF3.md:10311-10313`). At `F_{p^4}` ≈
2^124 the same term is ~2^−76 at L = 2^24. **A smaller field makes the
list-decoding escape hatch worse, not better** — so the δ/2 fork of §C
and the field half do not compose in the way one might hope.

### D.4 Seconds on the 4070, with the limb overhead priced

Let `f` be the factor by which committed rows grow under (a). `rows_W`
does not move (weights are already int8). `rows_A` grows where the int16
and int24 planes split; `rows_H` grows with the number of new range
facts. Two arms:

* **optimistic, f = 1.15** — only the Hadamard and the down accumulator
  need splitting, the norm chain is re-gadgetized without new rows, and
  the sumcheck grows 1.10×;
* **modelled, f = 1.35** — the int16 sites split, the norm chain needs
  its own limbs, the helper rows grow with them, and the sumcheck grows
  1.30×.

Committed bytes are then `18,649 · f · 4` against today's `18,649 · 8`:
**×0.575** at f = 1.15 and **×0.674** at f = 1.35 — i.e. the "half the
bytes" premise delivers 1.48–1.74×, not 2×.

| phase | today | f = 1.15 | f = 1.35 | basis |
|---|---:|---:|---:|---|
| encode NTT | 13.877 | 7.98 | 9.35 | ×0.5·f |
| opening re-encode | 13.826 | 7.95 | 9.32 | ×0.5·f |
| hashing | 0.481 | 0.28 | 0.32 | ×0.5·f |
| h2d transfer | 8.597 | **9.89** | **11.61** | ×f — **more planes to send; the field does not narrow int8** |
| sumchecks | 5.465 | 6.01 | 7.10 | ×1.10 / ×1.30 |
| folds + helpers | 4.228 | 2.43 | 2.85 | ×0.5·f |
| host residue | 11.93 | 12.53 | **14.32** | more planes to fill; the host does not shrink with the word |
| **8B prove** | **58.40** | **47.2 s (1.24×)** | **54.3 s (1.08×)** | [MODEL] |

**1.08× is inside this box's documented run-to-run noise.** On a 5090 the
same arms give, by the project's model, **17.4–23.1 s** (f = 1.15) and
**19.7–26.0 s** (f = 1.35) against today's 20.2–27.1 s — i.e. **0.5 to
3 s, and at the pessimistic end nothing measurable**, because the field
half moves work out of the bandwidth-bound device phases (which the
bigger card already divides by 4–7) and *into* the host and link phases
(which it does not).

### D.5 The honest statement about the field half

**The field change gives back most of what it takes, and on the private
profile it can give back more than it takes.** The gain is confined to
the encode, re-encode, hash and fold phases, and is bounded above by 2×
on those. The costs — more committed planes, more range facts, more LogUp
helper rows, more host→device traffic, more sumcheck instances, and a
degree-4 extension whose arithmetic is ~1.2× worse than the degree-2 one
— fall on phases the bigger card does *not* help, and on the one phase
that already dominates the private pass. It also changes the **statement**
(a limb-decomposed norm is a different set of relations from the one
`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md` accepted), which means the
integer-soundness review starts again from zero.

## E. Both together — the honest projection

### E.1 Applied to today's measured pass, on the 4070

| arm | 8B public-IO prove | factor | label |
|---|---:|---:|---|
| today | **58.40 s** | 1.00× | [MEASURED, NOISY-SHARED] |
| rate half only, δ/2, Q = 256 | 44.3 s | 1.32× | [MODEL] |
| rate half only, δ/3, Q = 404 | 46.3 s | 1.26× | [MODEL] |
| field half only, f = 1.15 | 47.2 s | 1.24× | [MODEL] |
| field half only, f = 1.35 | 54.3 s | 1.08× | [MODEL] |
| **both, best case** (δ/2, Q = 256, f = 1.15) | **37.9 s** | **1.54×** | [MODEL] |
| **both, modelled** (δ/3, Q = 404, f = 1.35) | **44.8 s** | **1.30×** | [MODEL] |
| *reference: the block L4 attacks reduced to zero* | *30.2 s* | *1.93×* | *[COUNTED — the hard ceiling]* |

### E.2 Applied where the plan actually puts it — step 6, after steps 1–5

This is the number D14 asked for, and it is the one that decides.

The ladder (as corrected on 2026-09-19 by lane `fsp-l9`) reaches **~40 s
on the 4070** after steps 1–4, then **10–15 s on a 5090** at step 5.
Post-step-4 the encode + re-encode block is **18–23 s of the 40 s**
[COUNTED: 27.70 s today, less ~2–4 s from steps 1 and 3 and ~5–6 s of
commit-W encode removed by the warm cache of step 2]. On the 5090 that
block is `18–23 / k_g`, with the plan's own `k_g` of 4–7:

| | seconds | note |
|---|---:|---|
| post-ladder 5090 pass (the plan's step 5) | **10–15** | [MODEL, `ZK60_FIVE_SECOND_PLAN.md` §5] |
| of which encode + re-encode + hash | **2.6–5.8** | [MODEL] |
| **ceiling: that block reduced to literally zero** | **7.4–9.2** | [MODEL] |
| rate half applied (block × 0.5) | **8.7–12.1** | [MODEL] |
| both halves applied (block × 0.29–0.34, link and host up 15–35%) | **8.7–13.2** | [MODEL] |

**Assumptions, all of them, stated.** The plan's own resource model
(`U_PERF3_THROUGHPUT_MODEL.md` §3.3) with the same host CPU; `k_g` 4–7
and `k_l` 1.5–3; the ladder's steps 1–4 land as the plan projects and
the corrected step-3 value (−1 to −2 s, not −7) holds; the warm weight
cache removes 5–6 s of commit-W encode at 8B (never measured — see §H);
the encode and re-encode kernels stay bandwidth-bound on a card with 7×
the bandwidth, which is the least safe assumption here (on a 5090 they
may become latency-bound, in which case L4 buys *less*, not more); the
field half's `f` is between 1.15 and 1.35; and no divisor from
§3.E of the plan is applied.

### E.3 Is 5 s inside the range?

**No — for the public feed-forward pass, on either card, with both halves
of L4.** The best modelled figure is **8.7 s** on a 5090 after the whole
ladder plus both halves of L4, and the *ceiling* — encode, re-encode and
hashing made free — is **7.4 s**. 5 s is below the ceiling of the lever,
which means no amount of success at L4 reaches it. What stands between
8.7 s and 5 s is the host residue, the link, the sumchecks and the LogUp
helpers, and L4 touches none of them; the field half makes two of them
worse.

**15 s remains reachable without L4**, exactly as the plan says.

**For the P1-private pass, no, and the question is not yet answerable.**
Three separate reasons, in order of weight:

1. Every private second in this repository was measured on machinery the
   project recorded on 2026-09-08 as having **demonstrated private-value
   disclosure**; the repaired construction exists only at width 16 and
   its cost at width 4096 is unknown. No projection built on the 265.34 s
   pass means anything for the product.
2. On the numbers that do exist, the private pass is 265.34 s with the
   encode transform at **119.10 s (45%)** — so L4's rate half is worth
   more there in absolute seconds than anywhere else. But the private
   block's own shape (`log_cols 8`, `inv_rate 8`) **cannot halve its rate
   at all under the δ/3 radius the code documents** (§C.3: 74.1 bits
   maximum at any Q). Under δ/2 it can, at Q unchanged. The private path
   is therefore entirely hostage to the §C.2 fork.
3. The plan's own composition puts a complete private 8B layer proof at
   **45–75 s on a 5090** [MODEL on MODEL] or 12–34 s on an H100. Dividing
   the encode block of that by up to 4 does not produce 5 s either.

The single most valuable measurement is still the one the plan names:
**the repaired private construction, at one Mistral-width layer, timed.**
Until it exists, no private L4 number is worth writing down, including
the ones above.

## F. The price

### F.1 The frozen digests that move

Both halves change every proof byte, so every recorded proof digest dies.
Inventory [COUNTED, grep over the repo excluding `.git`]:

| digest | profile | frozen length (B) | files | occurrences |
|---|---|---:|---:|---:|
| `50cf7bdf…` | v2, 12×512 | 66,844,928 | 148 | 526 |
| `5f368db6…` | v3, 12×512 | 70,758,084 | 150 | 513 |
| `021485e4…` | zk, 12×512 | 87,228,528 | 149 | 517 |
| `40eb5479…` | zk-v3, 12×512 | 87,697,008 | 186 | 722 |
| `dc980e81…` | 8B P1 pass | 1,234,936,956 | 18 | 63 |

Most of those occurrences are archival (results logs, `PROGRESS_UPERF3.md`
narrative). **The load-bearing sites that must be edited**, and the count
is small enough to be reassuring on this axis:

* **one authoritative table**: `scripts/hashline_cl_gpu_gates.py:109-114`
  (the whole `FROZEN` dict, all four digest+length pairs; `FROZEN_SHAPE`
  at `:124`);
* **3 Python tests**: `tests/test_hashline_cl_gpu_gates.py` (all four
  literals), `tests/test_hashline_cl_artifact_profile.py`,
  `tests/test_hashline_cl_profile.py`;
* **2 Python scripts**: `scripts/hashline_cl_artifact_profile.py`,
  `scripts/floors_round13_merge.sh` (the live floors gate);
* **2 Rust sources**: `hashline/tests/zk60_gpu_cache.rs:517` and `:524`
  (`FROZEN_P1_SHA`, `P3_SHA_SEED1_CPU`), plus doc comments at
  `hashline/src/zk.rs:4` and `zkp-core/src/ffn_v3/mod.rs:3`;
* **~11 shell byte-gate runners** under `results/` and `scripts/`;
* **40 checked-in fixture/manifest JSONs** per digest, dominated by
  `results/*/floors/manifest.json`;
* **~20 documents** that state the digests in prose (TASK_BOARD 16 hits,
  PROVING_CHANNEL_OPTIONS 11, ZK60_FIVE_SECOND_PLAN 7, …).

Beyond the five: **~41 distinct sha256 pins in live code** (13 in
`tests/`, 13 in `hashline/`, 15 in `scripts/`), **40** in checked-in JSON
fixtures, **~1,070** in archived round-evidence manifests. Other freeze
machinery that must be re-run or re-derived: the 15 `freeze_check*`
functions in `zkmatrix-rs/src/bin/ring_matmul.rs`, the wire-format golden
sample (`tests/test_wire_format.py`), the frozen receipt/chain bytes
(`hashline/tests/zk60_public_receipt.rs`, `zk60_public_chain.rs`), the
frozen attention-schedule digests
(`hashline/src/attention_schedule.rs:113-119`), the frozen SiLU table
digests (`hashline/src/silu.rs:11-12`), and the verifier-hardening
transcript digest (`hashline/src/field/verifier_hardening_tests.rs:156`).
The field half additionally kills the SiLU and activation table digests
outright (a new field means new table encodings).

**The four byte gates must be re-minted on both the CPU and the GPU
binary before any of the above can be updated**, and the twelve-gate
floor (four gates × CPU / GPU / GPU-chunk-forced) is the acceptance
instrument that has to be re-established from scratch.

### F.2 The parameters that are hard-pinned against the change

* `hashline/src/model_identity.rs:131-135` **rejects any `inv_rate != 4`**
  for stable-weight/model registration ("requires Ligero inverse rate 4
  and log_cols in 1..=16"), cross-checked at `:236`. The rate half cannot
  be measured on the registration path without lifting this gate.
* The rate is **baked into domain-separation strings**:
  `hashline/src/private_block/protocol.rs:33`
  (`b"…/log_cols8/inv_rate8/Q256/P1/…"`),
  `private_attention/protocol.rs:27`, `zk_ffn_fresh_poc.rs:85`,
  `zk_ffn_fresh_io.rs:143`, and the self-describing schedule
  `private_block/layout.rs:653-659`. Changing the rate changes the
  transcript label — hence the digest — even where the mathematics would
  be unaffected.
* Q is encoded into the receipt wire
  (`hashline/src/private_block_contract.rs:231, :537`) and bounded by
  `model_identity.rs:143-147`.
* `inv_rate` is part of the weight-cache key and a mismatch is a hard
  miss (`hashline/src/wcache.rs:122, :202, :232, :236-237`) — so every
  cached weight tree in existence is invalidated.

### F.3 The code that changes, and how much of it

| area | files | lines | rate half | field half |
|---|---|---:|---|---|
| **A — field, NTT, MLE, Merkle, RNG** | `zkp-core/src/{field,ntt,mle,merkle,rng,lib}.rs` (+ 6 shims in `hashline/src/`) | **1,026** | parameter only | **rewrite** |
| **B — PCS** | `zkp-core/src/pcs.rs` (1310), `pcs/backend.rs` (80), `hashline/src/pcs_compact.rs` (1358), `hashline/src/pcs.rs` (84) | **2,832** | parameter + query count + pad budget | **rewrite of the encoder and leaf hashing** |
| **C — transcript + sumcheck** | `zkp-core/src/{transcript,sumcheck}.rs` | **691** | domain strings | **rewrite** (degree-4 extension, new challenge sampler, new bias analysis) |
| **D — CUDA** | `hashline/src/gpu/{cuda.rs (3633), kernels.cu (1564), mod.rs (311)}` | **5,508** | retuning (chunk sizes, pruning residues) | **rewrite** — `kernels.cu:6-7` hand-codes the Goldilocks reduction |
| *A–D subtotal (what defines the two knobs)* | | **10,057** | | |
| **E — provers, statements, layer arithmetic** | `zk.rs` 4184, `attention.rs` 3448, `layer.rs` 2198, `ffn_v3/*`, `norm.rs`, `silu.rs`, `tables*`, `causal_oracle.rs`, `private_seam.rs`, `chain.rs` | **~13,000** | minor | **new integer spec: limb splits, new range registry, new bound tables** |
| **F — private block / private attention** | `private_block/*`, `private_attention/*`, `private_block_contract.rs` | **~5,900** | schedule strings, pad budget | **relayout** |
| **G — verifiers** | 28 `pub fn verify*` entry points | — | parameter checks | all |
| **H — wire / serialization** | `public_block_wire.rs`, `zk_ffn_fresh_wire.rs`, `export_v3.rs`, `export.rs`, `native_capture.rs`, `zk_proof_size.rs`, two `wire.rs` | **2,675** | Q-dependent lengths | **element width changes every frame** |
| **Python oracles** | `scripts/attention_hash_ref.py` (735, "THE PYTHON ORACLE" of the integer chain), `attention_x1_layer_ref.py`, `attention_xs1_chain_ref.py`, `hashline_memory_plan.py`, `hashline_cl_pending_memory.py`, `hashline_cl_artifact_profile.py`, `zk60_opus_wire_length.py`, `zk60_opus_io_capture.py`, `zk60_fable_transcript_sim.py`, + ~30 more (41 Python files mention NTT/Merkle/Goldilocks/`inv_rate`) | — | sizing constants | **rewrite of the integer oracle** |

Total realistically in scope: **~54,500 lines** of Rust and CUDA plus the
Python oracle layer.

### F.4 Effort, in the project's own unit

The unit is the **lane-week** (one lane × one week; e.g.
`START_HERE.md:225` "about two lane-weeks to a first measured row",
`ZK60_RULINGS_FOR_VICTOR.md:291` "about a lane-week taken from the
privacy lanes").

| item | lane-weeks | note |
|---|---:|---|
| **rate half — code** | **0.5–1** | the rate is already a parameter (`--inv-rate`, `PcsParams::inv_rate`) and the GPU test already sweeps 2/4/8 (`hashline/tests/zk60_gpu_commit.rs:305`). The real work is lifting `model_identity.rs:131`, raising Q and its pad knock-ons, and the transcript strings |
| **rate half — soundness re-derivation and review** | **1–2** | the δ/3-vs-δ/2 ruling (§C.2), the pad-feedback table (§C.3), the per-profile Q table, and a signature from whoever owns soundness |
| **rate half — re-freeze** | **1–2** | re-mint four digests on two binaries, twelve gates, update the one table and its ~60 live mirrors, 40 manifests, ~20 documents |
| **rate half total** | **3–5** | |
| **field half — Areas A–D rewrite** | **5–8** | 10,057 lines including hand-written CUDA reductions |
| **field half — new integer spec and bound table** | **3–5** | a new `ZK60_..._NATIVE_REVIEW` of R2's kind, at the real 8B shape with the int24 residual; re-derivation of R09 (half-p isqrt alias), R31 (registrar word ranges) and F7 (the non-local `A_MX` bound) |
| **field half — Areas E–H and the Python oracles** | **4–7** | |
| **field half total** | **12–20**, plus an external soundness review | |
| **both** | **15–25** | they share the re-freeze but not much else |

### F.5 What cannot be reused

* **Every proof digest and every proof artifact in `results/`.** They are
  not regenerable at the old parameters once the code moves, so the
  historical A/B series ends.
* **Every cached weight tree** (`inv_rate` is in the key).
* **The accepted integer-soundness review.**
  `ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md` is an argument about a
  specific set of relations in a specific field; a limb-decomposed
  statement in a 31-bit field is a different object and the review does
  not carry. (The *method* carries — §D.2 of that review is explicit that
  bounds must be taken over verifier-enforced ranges.)
* **R09's exclusion of the half-p isqrt alias**, which rests on a
  coincidence between `tn` and the limb count at the current p.
* **`scripts/attention_hash_ref.py`**, the executable integer oracle.
* For the field half only: the SiLU and activation table digests, and the
  frozen attention-schedule digests.
* **Not lost**: the byte-identity *methodology*, the twelve-gate floor
  structure, the CPU-vs-GPU column oracle, the chunked-commit design, and
  lane AL's host staging pool — all of which are parameter-independent.

## G. A staged plan, and the kill criteria

This section exists because D14 asked for it. It is **not** a
recommendation to build; on §E's numbers the lever does not reach the
target it was proposed for. If the owner nevertheless wants the seconds
that §C does buy, this is the cheapest order in which to find out, and
each rung produces a measured number before the expensive rung is
committed.

### G.0 — a ruling, before any lane (paper, zero lane-weeks)

Two questions, both already answerable from what is written down:

1. **δ/3 or δ/2?** (§C.2.) Under δ/2 the rate half costs no queries, no
   proof bytes and no masking budget; under δ/3 it costs 1.58× on all
   three and the private block cannot take it at all. Everything below
   changes shape depending on the answer, so the answer comes first, and
   from the person who owns soundness — not from a lane.
2. **Per-opening 106 bits, or whole-proof?** The 8B proof is already at
   **2^−94.1** (`ZK60_FABLE_SECURITY_OBLIGATIONS.md:406-408`). If the
   target is whole-proof, Q must rise at the *current* rate before any
   rate change is discussed, and L4 becomes a net cost.

### G.1 — rung 1: a rate-only A/B at 12×512, behind the existing switch

*Measured, cheap, no new cryptography, no digest touched.*

* Run the existing binary at `--inv-rate 2` with the Q the G.0 ruling
  implies (256 under δ/2, 404 under δ/3), against the `--inv-rate 4`
  baseline, on the 12×512 shape both arms in one session, one binary.
* **New digests go into a separate table**, never into
  `scripts/hashline_cl_gpu_gates.py:109-114`; the four frozen digests
  must still be green at `inv_rate 4` in the same session.
* The registration gate `model_identity.rs:131` rejects `inv_rate != 4`,
  so the experiment either avoids the stable-weight path or puts that
  gate behind a flag that defaults to the current behaviour.
* **Acceptance**: (i) the twelve byte gates green at `inv_rate 4`
  unchanged; (ii) the CPU and GPU binaries produce the *same* new digest
  at `inv_rate 2` (the existing cross-binary identity instrument, which
  is parameter-independent); (iii) the `gpu-probe` column oracle passes
  at the new rate; (iv) a per-phase split at both rates.
* **Kill criterion**: if the measured encode + re-encode gain at 12×512
  is **below 1.7×**, the §C.4 model is wrong and the 8B projection
  collapses — stop.

### G.2 — rung 2: the memory question, on paper

`scripts/hashline_memory_plan.py` counts the GPU buffers of one
`dev_commit_zk_from` call and its counts scale with `inv_rate`. Re-run it
(it is a Python model, not a proof) at `inv_rate 2` and report the
derived private peak against the 8,188 MiB card. **Kill criterion**: if
the derived peak does not fall below the card, §C.8's best argument for
the rate half is gone.

### G.3 — rung 3: the 8B three-arm measurement, on a quiesced box

Only after G.1 passes. Three arms — `inv_rate 4 / Q 256`,
`inv_rate 2 / Q as ruled`, and the unchanged baseline — at 8B, detached
under the no-hangup protocol, p95 over ≥ 5 runs per
`MEASUREMENT_PROTOCOL.md`. **Kill criterion**: whole-pass gain **below
1.20×** — stop; the lever is inside the noise the box has already shown.

### G.4 — rung 4: the field half's bound table, on paper, before any code

Deliverable: a table of R2's kind — every constrained integer expression
at the **real 8B shape with the int24 residual**, bounded from the
verifier-enforced ranges, against `p/2` for the candidate 31-bit prime,
with the limb decompositions each one would need. Plus a re-derivation
of R09, R31 and F7 at the new p.

**Kill criterion, and I expect it to fire**: if holding the RMSNorm
isqrt chain (`SSe ≈ 2^58`) and the Hadamard term (1,610,637,311 against
`p/2 ≈ 2^30`) requires **more than ~1.3× the committed rows**, the field
half's own arithmetic (§D.4) says it is worth less than the box's noise —
drop it and keep only the rate half.

### G.5 — the re-freeze, last

Only after a rung has produced a gain the owner has accepted. Re-mint the
four gates on both binaries, then update the one authoritative table and
its mirrors in a single tranche, with the old digests retained in the
ledger as history — never silently replaced.

### G.6 — the explicit kill criteria, collected

| # | criterion | fires when | consequence |
|---|---|---|---|
| K1 | the owner rules whole-proof bits | G.0 | L4 is a net cost; stop |
| K2 | the owner declines δ/2 **and** declines a 1.95 GB proof | G.0 | the rate half has no viable arm; stop |
| K3 | 12×512 encode + re-encode gain < 1.7× | G.1 | model wrong; stop |
| K4 | CPU and GPU disagree at the new rate | G.1 | a correctness bug in the parameterisation; stop and fix before anything else |
| K5 | derived private VRAM peak still above the card | G.2 | the rate half's best argument is gone; it is then worth only §C.4's seconds |
| K6 | 8B whole-pass gain < 1.20× | G.3 | stop |
| K7 | 31-bit bound table needs > 1.3× committed rows | G.4 | drop the field half permanently |
| K8 | the private block cannot reach 106 bits at the chosen rate (§C.3) | G.0/G.1 | the rate half applies to the public path only, and the product is private (D1) |

## H. Risks, pollution check, and what I could not determine

### H.1 The pollution check, input by input

This morning lane `fsp-l9` found that step 3 of the five-second plan was
over-counted four to seven times because lane AO's source table had been
measured while another lane loaded the CPU. Every input to this memo is
checked against that failure mode.

| input | label | could it be polluted the same way? |
|---|---|---|
| the 58.40 s pass and its eight prover-phase rows | [MEASURED, NOISY-SHARED, one run per arm, shared box] | **Yes, in magnitude.** Same box, same day (2026-09-04), and the ledger itself records ~6% per-phase and up to ~2× whole-run variance. What protects the *structure* is that both arms were one session on one binary and produced a byte-identical proof. **Direction matters and cuts both ways**: if the host residue (11.9 s) is inflated by load, L4's Amdahl ceiling is *higher* than §E says; if the device counters are inflated, L4's absolute gain is *smaller*. Neither changes the verdict, because the verdict rests on the *ratio* 28.18 / 58.40, and both numbers come from the same run. |
| the device counters (h2d 8.597, ntt 13.877, hash 0.481, sumcheck 5.465, fold 2.850, helpers 1.378, re-encode 13.826) | [MEASURED, same run] | Yes, same exposure. The h2d counter is known to hold waits (9,328 MB in 8.597 s is 1.08 GB/s against a measured 5.4–5.6 GB/s raw rate), so the *link* row is the one most likely to be host-contention in disguise. |
| `rows_W = 10,752`, message 1.409 GB, codeword 5.637 GB | [COUNTED], triple-checked | **No.** Pure arithmetic, cross-confirmed by lane AL's staging-buffer size and by §2 of the plan's independent "5.6 GB per layer, 180 GB per model". |
| `rows_A ≈ 3,517`, `rows_H ≈ 4,379` | [COUNTED, reconstructed] | **No, but they are reconstructions, not readings.** See H.3. |
| the 106-bit derivation | [COUNTED from `zkp-core/src/pcs.rs:17-19`] | No — it is a formula, reproduced exactly (106.25). |
| `Q = 403/404` at rate 1/2 | [COUNTED], independently in `U_PERF3_ROUTE_B_THROUGHPUT.md:629-631` | No. |
| the integer bound table (§D.2) | [MEASURED in the sense of "read from code and accepted reviews"] | No — but see H.3 on the int24/8B row. |
| the 5090 projections | [MODEL] on the project's own §3.3 model | Inherits everything above, plus `k_g` and `k_l` that no one has measured on a 5090 because there is no 5090 installed. |
| `f = 1.15 / 1.35` (the limb-growth factor) | [MODEL], **my own assumption** | Not measurable today. It is the single softest number in the memo and it moves the field half between 1.24× and 1.08×. |
| the post-ladder 18–23 s encode block | [COUNTED on the plan's corrected ladder] | Inherits the ladder's own unverified steps 1 and 2. |

### H.2 An internal inconsistency in the baseline, which I could not resolve

**The `hash 0.481 s` device counter cannot be the whole hashing cost.**
The commitment Merkle-hashes every codeword column of every commitment:
**313 GB per proof** (§B.2). At the 4070's 256 GB/s roof, merely *reading*
313 GB takes ≥ 1.22 s. The counter says 0.481 s, i.e. 650 GB/s. So either
the leaf hashing is fused into the encode kernels and its cost is inside
the 13.877 s `ntt` counter, or the counter is scoped to part of the work
(the chunked path reports `hash 0.0000` per layer in the log while the
summed line reports 0.481 s).

**Why it matters for D14 specifically**: the lever is *named* "fewer
hashed bytes", and the only measured hashing number in the repository is
the one that cannot be right. It does not change the verdict — encode +
re-encode + hash is 28.18 s however it is split internally, and that
total is what §E divides — but any future claim of the form "hashing is
X seconds" should be treated as unestablished until someone instruments
`hash_columns` separately. This is a one-line counter fix, not a run.

### H.3 What I could not determine

1. **`rows_A` and `rows_H` are reconstructed** from lane AL's staging
   buffer (0.461 GB → 57.6 M elements) and from the proof length
   (§B.3), not read off the code. The reconstruction closes to within
   34 KB per layer of transcript residue, which is strong, but the H
   geometry in particular should be confirmed from
   `zkp-core/src/ffn_v3/statement.rs` before anyone quotes it.
2. **The re-encode's Q-dependent tail.** I modelled it at 10–25% of the
   phase, from lane AO's statement that output pruning is worth 4.38× on
   one of four kernels. The true split decides whether the δ/3 arm costs
   1 s or 3 s more than the δ/2 arm.
3. **Whether the encode kernels stay bandwidth-bound on a 5090.** They
   run at 77–78% of a 256 GB/s roof today; at 1,792 GB/s one of them
   (`k_dit_p1_pad_s`, already latency-bound at 105 GB/s) almost certainly
   does not, and L4's gain on that card would then be smaller than §E
   says. Nobody can test this without the card.
4. **The limb-growth factor `f`.** Determinable on paper by G.4 and not
   otherwise.
5. **What the repaired private construction costs at width 4096.** This
   is the plan's own largest uncertainty and it swallows every private
   number in §E.
6. **The warm weight cache at 8B on the current tree** has never been
   run, so the 5–6 s of commit-W encode that §E.2 assumes step 2 removes
   is [COUNTED, unverified].
7. **Whether the δ/2 radius is defensible for the interleaved column
   test.** I reproduced the arithmetic and located the project's own
   citation and its explicit refusal; I am not the reviewer and this memo
   does not rule on it.

### H.4 Risks if the lever were built anyway

* **The rate half's δ/3 arm makes the project's worst contract miss
  worse** — 1.23 GB → 1.95 GB against a 1.06 MiB budget — while buying
  2–3 s on a 5090. That trade should be stated to the owner in those
  words.
* **A rate change invalidates every cached weight tree**, and the weight
  cache is step 2 of the speed ladder. The two levers interact and must
  not be counted independently.
* **The field half changes the statement.** It is the only item in the
  speed ladder that does. A limb-decomposed norm chain is a new set of
  relations with a new no-wraparound theorem, and the project's accepted
  review does not carry.
* **The re-freeze is the moment the byte-identity instrument is blind.**
  Between minting the new digests and re-establishing the twelve-gate
  floor, the strongest correctness instrument this project has is
  switched off. That window should be one tranche, owned by one lane, and
  it is the main reason the re-freeze is rung 5 and not rung 1.
* **Opportunity cost.** 3–5 lane-weeks (rate) or 15–25 (both) against the
  measurement the plan says is worth more than any of it: the repaired
  private construction, timed at one Mistral-width layer.

---

*(draft complete)*
