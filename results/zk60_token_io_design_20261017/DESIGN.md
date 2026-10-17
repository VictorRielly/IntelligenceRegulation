# Token I/O for the private run — design, counted costs, test-first plan

Lane: TOKEN I/O DESIGN, 2026-10-17. **Version 3** (after the second adversarial
check `check/CHECK2.md`, the security owner's D26 and the D15 correction; version 2
followed the first check `check/CHECK.md`). **Paper only**: nothing here was built, proved or measured. No
privacy property is accepted by this document and no ruling is made; rulings are
Victor's (`docs/zkmatrix-poc/ZK60_DECISIONS.md`). D13 stands: the hidden blocks
are the first MVP, token generation is the next milestone, and this is a design
for that next milestone.

Labels: **[COUNTED]** = exact arithmetic on the plane / site / slot lists written
below, with the conventions of the exact layout replica
(`results/zk60_speed_plan_20261017/layout.py`); **[MODEL]** = the speed plan's
fitted cost model (`cost_model.py`, laptop Core Ultra 9 185H phase run, shared
box) or one of its stated band factors. No number here is [MEASURED].
Reproduce every table with
`python3 results/zk60_token_io_design_20261017/token_io_count.py`
(v3; one thread, under one second; output `token_io_count.json`). Version 1 of
the counter and its output are kept as `token_io_count_v1.py` / `_v1.json`.

---

## 0. Changes in version 3 (2026-10-17, UTC 19:51–20:00)

The second adversarial pass (`check/CHECK2.md`, probes `check/check2_probes.py`)
found B-1 to B-3 closed and the pin drop safe, and one new hole that version 2's
fold-in of D25 T8 had opened. The security owner ruled R9 as **D26** (19:50 UTC),
and the register's **D15 correction** (19:40 UTC, `results/zk60_soundness_recount_20261017/RECOUNT.md`)
replaced the stack accounting this design used.

| item | source | what changed |
|---|---|---|
| V3-1 | **CHECK2 N-1 (hole as written in v2)** | v2 wrote the BOS clause as a bare addend of stage IN's query zero-check. Then `tok_0 = BOS + 1` with `h_q(0) = 0` makes the two clauses cancel at `t = 0`, position 0 leaves the LogUp, and embedded row 0 becomes arbitrary (probe T4 ran; R0 V16 reproduces it). **Now the BOS clause carries its own fresh challenge**, drawn after `A_in` (in the slot's batching draw, after `H_in` is committed), like every batched clause (§2.3). |
| V3-2 | CHECK2 N-2 | The BOS id is a **per-profile statement constant** with declared class `[0, V)` (D24 F-1 rule), validated at the trained door on both sides and bound into the calibration identity: **1 for TinyLlama, 128000 for Llama-3-8B**. R0 takes it as a parameter (V24). |
| V3-3 | CHECK2 N-3 | Stated once (§3.1): **every batched clause of every new slot carries its own fresh challenge** drawn after the commitments it constrains — the query zero-check's LogUp, BOS and pad clauses; the table zero-check's clause and pad; SBOOL's booleanity and sum; RSEL's `c1`, `c2`, `c3`; VZC's and DZC's clauses. |
| V3-4 | CHECK2 N-7 | Hidden-length `A_out` site count fixed: SEL is a standalone slot with three private tables (`s`, `B_out`, `x`) and claims `s` and `x` on `A_out`; with SBOOL (`s`) and IO-s (`s`) that is 4 sites in place of IO-in's 1, so **50** (not 49) sites on `A_out`; 8B: 345 / 236 rows, 2.380 M elements [COUNTED]. |
| V3-5 | CHECK2 N-8 | Deleted v2's wrong clause that every block's `M` would be 2^-96.1: `M` is RS(1024, 4096), distance 3/4, 2^-106.25. |
| V3-6 | **D26** (security owner, 19:50 UTC) | §8 now records the ruling: variant P adopted, F the recorded fallback, C not adopted; the second check's conditions **C-a to C-e bind** and are folded into §8.7. §7: R9 ruled. |
| V3-7 | **D15 correction** (19:40 UTC) | §4.4 now uses the recount's stack accounting: a run opens `4L + 1` commitments, A / H / boundaries / endpoints at the real ZK-code distance, `M` at 2^-106.25. Stack commitment term **8B T32 2^-98.19, TinyLlama T32 2^-97.55** (was 2^-98.66 / 2^-99.21 here). With token I/O: **2^-98.04 / 2^-97.46**; whole run (R14 lookup convention) **2^-96.77 -> 2^-96.71 (8B T32), 2^-97.09 -> 2^-97.02 (TinyLlama T32)** [COUNTED]. R10 is answered by the correction (§7.2). |
| V3-8 | CHECK2 N-10..N-14 | R0 gains vectors V13–V24 and a helper-level stage-IN model, a field-level final-norm checker with explicit windows and an `x` int16 check, and the IO-in / IO-s / IO-out relations (§6.4): 24 vectors, 20 tests, all passing. One sharpening found while writing V15: the A3-only forgery keeps `delta` honest and shifts `M` by `2^-v (tok' - j)` — only A3 binds the output id (§3.1). |
| V3-9 | CHECK2 §3.3 | §6.1 now carries R1's full control list, each with its predicted catching slot and its R0 vector. |

## 0b. Changes in version 2 (2026-10-17, UTC 19:22–19:40)

The adversarial check (`check/CHECK.md`, with `check/check_arith.py`) found the
core sound — the input lookup binds every column of every embedded row, the keyed
argmax forces numpy's first maximum, the tiny endpoints stay private, and the v1
counts reproduce exactly — and required three binding changes before R1. All
are folded in below, with my decision on each recommendation.

| item | from the check | what changed in this design |
|---|---|---|
| C-1 | **B-1 / F-2 (soundness accounting hole)** | v1 put the token endpoints at row width 2^8 with 256 zero-knowledge pads at rate 1/4: that code has distance 1/2, each opening misses with about 2^-67.3, and the **whole proof fell to 2^-66.3** [COUNTED]. Now: token endpoints at **2^8, rate 1/8** (the frozen toy endpoint's geometry, 2^-106.25 per opening); every new stage commitment (`A_in`, `H_in`, `A_out`, `H_out`) at **row width >= 2^12**, rate 1/4 (2^-103.69); section 4.4 recounted with distance `1 - (n + 256)/(n inv_rate)`. Whole-proof commitment term with token I/O: **2^-98.47 (8B), 2^-98.93 (TinyLlama)** at T32 [COUNTED]. |
| C-2 | **B-2 / F-1 (hidden selector not bound)** | v1's hidden selector let a cheating prover return the greedy token after *any* prefix. Now the selector `s` (one-hot over positions) is **sealed under the input root**: the input token endpoint carries a second half holding `s`, claimed by stage OUT, so the endpoint has two claim sites (boundary geometry `data + 2*2 + 2`, opened once at the end of the run — R9). The input owner's check verifies `s = e_{P-1}`. Fallback recorded: `s` in the output endpoint's plane (one site). The public-row variant never had the problem. |
| C-3 | **B-3 / F-3 (specification gaps)** | `tok` lives on the same lifted domain as its LogUp helper `h_q`; every IO slot runs over its token endpoint's **whole padded plane** (>= 256 words) with a public support indicator, so the endpoint's pad words are bound to zero (D17 rule 1); RSEL and IO-out are written with a public factor in every monomial (`u0`, a public one-entry indicator). |
| C-4 | F-4 (recommended) | **Adopted: the argmax difference's top-limb pin is dropped.** Six byte limbs bound `delta` to `[0, 2^48)` and `2^48 + 2^45 < p`; the pin bought nothing. One lookup and one helper fewer per vocabulary entry: 8B mode (i) stage OUT -10.3 %, 8B T512 mode (ii) -12.6 % [COUNTED]. |
| C-5 | F-5 (recommended) | **Adopted**: the owner's decommitment includes every row's 256 pad coefficients (needed to re-encode). |
| C-6 | F-6 | **Adopted**: hiding of tagged-profile token roots rests on D19b's model (pending); listed beside R5. |
| C-7 | F-7 (recommended) | **Decision: let the fidelity numbers choose.** Constants with `g0 Cn_f <= 127 * 2^tn_f` make a final-norm int8 overflow impossible for every input (`|x_i| <= D`), at the cost of about 2.5 bits of output resolution against the margin-1.5 calibration (calibration `|x̂'|` max 5.454, `sqrt(2048) / (1.5 * 5.454) = 5.5`). The fidelity lane's s4 runs both (`diag_safe` and `cal_m1.50`). If the refusal-free form keeps top-1 agreement within ruling R4's threshold it is adopted (no new refusal class); otherwise the calibrated form is used and final-norm overflow is listed in D20's input-dependent class with F2/F6 evidence. |
| C-8 | F-8 (recommended) | **Adopted**: the D16 rule-5 audit of the new layouts is an R1 acceptance item (non-unit coefficients sit on `tok`, `M`, `m`; all three are determined, not free). |
| C-9 | F-9 | **Adopted for R4**: mode (ii) uses factored public tables on the `T x V` cube, and states the verifier's digest-caching assumption for the 1.6 GB of public tables. |
| C-10 | section 4 of the check | Section 7: **R2 amended** (hiding the prompt length = sealing it under the input root); **R9 moved before hidden-length mode (i)**; new **R10** (per-opening counting convention, security owner); D19b beside R5. |
| C-11 | coordinator | Rung R0 (Python reference semantics, no proof) done: section 6.4. |
| C-12 | Victor, 2026-10-17 19:28 UTC | R1–R8 accepted as **D25 T1–T8** (with D23, D19b): section 7 now records them as ruled; R9 stays the security owner's, written up as a separate proposal (section 8); BOS forcing (T8) added to stage IN's query zero-check as a public-constant term. |

Number changes (8B, T32, mode (i)): stage IN 0.436 M -> 0.479 M elements (width
floor), stage OUT 2.621 M -> 2.351 M (no pin), total 3.06 M -> **2.83 M**
[COUNTED]; seconds unchanged to two digits. TinyLlama: stage IN 0.120 M -> 0.184 M,
stage OUT 0.819 M -> 1.073 M. 8B T512 mode (ii), byte limbs: 1,066 M -> 932 M.

---

## 1. Plain-words summary

1. **What is added.** Two new *stages* at the two ends of today's private run,
   under the same single transcript: a *token-in* stage before block 0 (the
   embedding lookup) and a *token-out* stage after the last block (final norm,
   output head, greedy choice of the next token).
2. **The run's sealed endpoints become token ids**: the hidden prompt ids go in,
   the hidden next-token id comes out (mode i). A later mode (ii) proves a whole
   greedily generated continuation in the same single pass.
3. **What stays hidden.** Today's endpoints `x_in_L00` and the last block's output
   become ordinary internal boundaries (D12a); logits, the token selector and the
   maximum live only on prover-generated commitments, each opened once.
4. **What the verifier sees**: two token-endpoint roots, the model statement (now
   also naming the embedding table, the final-norm constants and the head by
   digest), and proof bytes. It learns no token and no logit. The prompt length
   stays hidden inside the public length bucket `T` because the position selector
   is sealed under the input root (D25 T2, D26); the public-row variant instead
   requires the prompt to fill `T`.
5. **Input side**: each hidden token picks its row of the public int16 table
   through one lookup per position on a random compression of the row
   (0.18 M committed elements for TinyLlama, 0.48 M for Llama-3-8B, at every T
   [COUNTED]).
6. **Output side**: the head's integer logits feed a *keyed* argmax — a 0/1
   selector over the vocabulary plus one non-negative difference per entry in six
   byte limbs — which forces numpy's first-maximum tie rule with no separate
   comparison.
7. **Cost at Llama-3-8B, mode (i)**: 2.83 M committed elements (0.31 % of the T32
   stack) [COUNTED]; 3.2 s on the laptop CPU (3.0 % of the T32 stack), 0.43 s on
   one 5090 with the whole prover resident [MODEL]. The verifier pays +1.6 s per
   pass to fold the two 525 M-entry public tables (embedding, head): +12 % at T32,
   +0.8 % at T512 [MODEL]. Soundness (the register's D15 accounting): the commitment
   term moves from 2^-98.19 to 2^-98.04 and the whole run from 2^-96.77 to 2^-96.71
   [COUNTED].
8. **Mode (ii)** costs +4 % to +11 % of the 8B stack depending on T and measure
   (932 M committed elements at T512 with byte limbs, 596 M with 16-bit limbs
   [COUNTED]) and is what lets one prefill-shaped proof count every generated token.
9. **The owner learns the token** from the prover, with the output endpoint's
   decommitment (rows, pads, salts), over a private channel, and checks it against
   the receipt's root; that hand-off is never published (D21) and no root is ever
   chained (D23).
10. **Rulings (section 7)**: Victor accepted all eight product recommendations
    on 2026-10-17 as **D25 T1–T8** (with D23 and D19b); the security owner ruled
    the two-site input endpoint (R9) as **D26** (variant P, conditions C-a to C-e);
    the D15 correction answers R10. No design ruling is open.

---

## 2. Input side: hidden token ids to hidden `x_in_L00`

### 2.1 Where it sits in the run

Today (`private_block/run.rs`): stage 0 claims the **external input endpoint**
(the padded `T x d` int16 plane `x_in_L00`, sealed by the prover under D18) in its
IO-in slot; stage `L-1` closes the external output endpoint.

With token I/O the run becomes `[IN] -> B_in -> block 0 -> B_0 -> ... -> block L-1
-> B_out -> [OUT]`:

* `B_in` is a commitment to `x_in_L00` **generated by the prover inside the run**,
  geometry exactly an internal boundary's: `rows = data + 2*sites + 2` with two
  sites (ruling M-1) — site 0 claimed by stage IN, site 1 by block 0's existing
  IO-in slot — opened once, in block 0's stage, as every boundary is today.
  Block 0 itself is **unchanged**: its A, H, M layouts, slots and profile bytes do
  not move; only the run's stage lines (schedule digest) do (block 0's site-1 pair
  moves from row `data` to `data + 2`, a stage-line fact).
* The new **external input endpoint** holds the `T` token ids: row width 2^8,
  rate 1/8, `ceil(plane / 256)` data rows. Public-row mode (i): one claim site,
  M-7's `data + 5` rows. Hidden-length mode (i) and mode (ii): two sites, boundary
  geometry `data + 6`, opened once at the end of the run (R9).
* Net change in IO commitments [COUNTED]: the two old `data + 5` endpoints become
  two `data + 6` boundaries (+1 row each), plus two token endpoints of 6 rows
  (public row) or 7–8 rows (two-site input endpoint).

### 2.2 The three options compared

The public table is `embedding_int16.bin` (TOKEN_IO_SPEC.md: `x_in_L00[t] =
table[tok_t]` exactly, rotation and `s_in` already applied): 32,000 x 2,048
(TinyLlama, pad `V_pad = 2^15`) and 128,256 x 4,096 (Llama-3-8B, `V_pad = 2^17`).

**(a) Hidden one-hot rows times the public table (matmul slot).** Commit
`O in {0,1}^{T x V_pad}`; prove booleanity, row sum 1, `tok_t = sum_v v O[t,v]`
(one batched slot), and the gather `x~(r_t, r_i) = sum_v O~(r_t, v) E~(v, r_i)` as
a matmul-shaped slot whose public factor is `E` folded with `eq(r_i)`. Simple and
close to existing slots, but it commits `T * V_pad` words and runs a dense
zero-check over that cube (2^26 at 8B T512, eight times the largest block domain).

**(b) Indexed LogUp of a compressed row (chosen).** After `B_in` and the stage's
`A` are committed, draw a column point `r_emb` (with the existing beta, gamma,
alpha, before `H`). Each position contributes ONE two-column tuple
`(tok_t, x~(t, r_emb))`, looked up in the `V`-row table `(v, E~(v, r_emb))`,
compressed with beta and its own table tag `g_emb = gamma * TAG_EMB` exactly like
today's exponential and activation lookups (`protocol.rs`:
`alpha - (d + beta e + g_exp)`). The query's second column is not a committed
plane: it is `B_in` read at the partially fixed point `(rho_t, r_emb)`, one claim
site (a `Tab::Priv` with `Coord::Fixed` column bits). Committed: `tok`, the
multiplicity histogram `m` (V_pad words), two Fp2 helpers (`h_q`, `h_tab`) and the
zero-sum pair. Nothing scales as `T * V`.

**(c) Two-chunk one-hot addresses (Shout).** Twist and Shout (Setty, Thaler,
Zhu, ePrint 2025/105, CRYPTO 2026) commits the address as `d` one-hot chunks of
size `V^{1/d}` and proves reads with a sum-check whose prover is linear in
`T + V` *when it exploits one-hot sparsity*. Committed size is the smallest of
the three, but this codebase's sum-check engine is dense, so the read-checking
sum-check runs over the full `T * V_pad` cube and costs like (a). Recorded as
the route if the engine ever gains a sparse one-hot prover; not chosen.

Other literature checked: LogUp (Haböck, ePrint 2022/1530) is what (b) is; tuple
compression with a challenge is Plookup's multi-column method (Gabizon and
Williamson, ePrint 2020/315); Lasso (Setty, Thaler, Wahby, ePrint 2023/1216)
targets decomposable tables, which an embedding is not; zkLLM (Sun, Li, Zhang,
CCS 2024, arXiv 2404.16109) contributes tlookup / zkAttn for non-arithmetic
operators and offers nothing cheaper for a public row gather than (b).

**Verifier work is the same in all three**: one `O(V * d)` fold of the public
table at a random column point (`E~(., r)`), because `Tab::Pub` vectors are
materialised and MLE-evaluated by the verifier (`argument.rs:612`). That fold is
the dominant input-side cost on both sides (section 5).

### 2.3 Option (b) in detail

Stage IN (its own `A_in`, `H_in`, `M_in` at row width 2^12, under the run
transcript; order: absorb stage tag and the embedding digest, commit `B_in`,
commit `A_in`, commit `M_in`, draw `beta, gamma, alpha, r_emb`, commit `H_in`,
slots, open `M_in`, `A_in`, `H_in`; the token endpoint is opened here when it has
one site, at the end of the run when it has two):

| commitment | planes (domain) |
|---|---|
| `A_in` | `tok` (T **lifted to the row width**, the same domain as `h_q`; pad-zero on the lift), `m` (Voc = V_pad) |
| `H_in` (Fp2) | `h_q` (T lifted), `h_tab` (Voc), `u` (zero-sum pair, Tab) |
| `B_in` | `x_in_L00`, padded `T_pad x d_pad` (internal boundary, 2 sites) |
| input token endpoint | half 0: `tok` (`max(128, T_pad)` or `max(256, T_pad)` words); half 1 (hidden-length mode i only): the selector `s` |

| slot | statement | private tables | degree |
|---|---|---|---|
| IO-in | over the endpoint's whole `tok` half: `end(0, z) = supp_T(z) tok(0, z)` (`tok` read with the lift bits fixed to 0; the public `supp_T` binds the endpoint's pad words to zero, D17 rule 1) | tok, endpoint | 3 |
| query zero-check | `h_q(t) (alpha - tok(t) - beta x~(t, r_emb) - g_emb) = supp_T(t)` over the lifted `T` cube, the BOS clause, pad-zero on `tok`, `h_q` — each clause with its own fresh coefficient (below) | h_q, tok, `B_in` at `(rho_t, r_emb)` (its row bits on the trailing variables, broadcast over the lift bits where `h_q = 0`) | 4 |
| table zero-check | `h_tab(v) (alpha - tau(v)) = m(v)`, `tau(v) = v° + beta E~(v°, r_emb) + g_emb`, `v° = v` for `v < V`, `v° = 0` on padded entries; pad-zero on `m`, `h_tab` | h_tab, m | 4 |
| LogUp sum | `sum_t h_q - sum_v h_tab = 0`, the existing pairless value-0 claim on `H` | — | — |
| ZS | the zero-sum row, as today | u | 2 |

**BOS (D25 T8; v3 repair of CHECK2 N-1 and N-2).** The query zero-check proves,
with fresh challenges `mu_q`, `mu_bos`, `mu_pad`, `zeta` drawn in the slot's batching
draw (after `A_in`, `M_in` and `H_in` are committed):

`eq(tau, t) [ mu_q (h_q(t) (alpha - q_t) - supp_T(t)) + mu_bos [t = 0] (tok(t) - BOS) + mu_pad (1 - supp_T(t)) (tok(t) + zeta h_q(t)) ] = 0`.

The BOS clause's **own** coefficient is load-bearing: written as a bare addend (v2),
`tok_0 = BOS + 1` with `h_q(0) = 0` makes the LogUp clause (`-1`) and the BOS clause
(`+1`) cancel at `t = 0`, position 0 leaves the lookup and embedded row 0 becomes
arbitrary (CHECK2 probe T4; R0 V16: accepted unweighted, rejected with `mu_bos`).
`BOS` is a **per-profile statement constant** with declared class `[0, V)`, checked
at the trained door on both sides and bound into the calibration identity: 1 for
TinyLlama, 128000 for Llama-3-8B (`<|begin_of_text|>`). `[t = 0]` is a public
indicator; no new site or row.

Claim sites [COUNTED]: 3 on `A_in`, 3 on `H_in`, 1 on `B_in` (plus block 0's
existing one), 1 on the input endpoint (plus stage OUT's in the two-site cases);
`M_in` 12 rows (4 slots).

**Soundness of (b)** (confirmed by the check, P-1). (i) LogUp: for random alpha
the fractional identity holds only if the multiset `{q_t}` is contained in
`{tau_v}`; a query outside leaves a pole of residue in `[1, T]`, nonzero because
`p > T`, so `m` needs no range (error `(T + V_pad)/|F_p^2| <= 2^-110.9`). (ii) For
fixed `r_emb`, `q_t - tau_v` is linear in beta, so distinct tuples collide for at
most one beta: `T * V_pad / |F_p^2|` (2^-102 at 8B T512). So `tok_t in [0, V)`.
(iii) `r_emb` is drawn after the roots of `B_in`, `A_in`, `M_in` are absorbed, so
`x~(t, r_emb) = E~(tok_t, r_emb)` gives `x[t, .] = E[tok_t, .]` on every column,
pad columns included, except with `T * log2(d_pad) / |F_p^2|` (2^-115.4). Block 0's
IO-in slot covers the whole `B_in` plane (D17), so block 0's `A_X = B_in = E[tok]`
word for word; block 0 re-proves int16.

### 2.4 Counted comparison

Each stage at its own receipt-optimal row width **at or above 2^12** (B-1).
"elements" = `(A + H rows) * n`; "max zc" = largest dense sum-check domain; "zc
terms" = sum over zero-check slots of domain x private tables; "inv" = LogUp
inversions; "fold" = public-table entries folded by prover AND verifier.
Seconds: laptop CPU [MODEL]; verifier [MODEL] (`1.46 ns` per folded entry +
`31.5 ms`). Every new opening here is 2^-103.69 or better [COUNTED].

**TinyLlama-1.1B** (fold 67.1 M entries in every option)

| T | option | n | A / H rows | elements | max zc | zc terms | LogUp inv | prover s | verifier s | receipt MB |
|---|---|---|---|---:|---|---:|---:|---:|---:|---:|
| 32 | (a) one-hot | 2^12 | 267 / 0 | 1.094 M | 2^20 | 2.10 M | 0 | 0.51 | 0.13 | 1.31 |
| 32 | **(b) LogUp** | 2^12 | 17 / 28 | **0.184 M** | 2^15 | 0.08 M | 32,800 | **0.43** | 0.13 | 1.27 |
| 32 | (c) chunks | 2^12 | 18 / 0 | 0.074 M | 2^20 | 3.16 M | 0 | 0.78 | 0.13 | 0.88 |
| 128 | (a) | 2^13 | 523 / 0 | 4.284 M | 2^22 | 8.39 M | 0 | 1.05 | 0.13 | 2.17 |
| 128 | **(b)** | 2^12 | 17 / 28 | **0.184 M** | 2^15 | 0.08 M | 32,896 | **0.43** | 0.13 | 1.27 |
| 128 | (c) | 2^12 | 27 / 0 | 0.111 M | 2^22 | 12.6 M | 0 | 1.39 | 0.13 | 0.90 |
| 512 | (a) | 2^14 | 1,035 / 0 | 16.96 M | 2^24 | 33.6 M | 0 | 3.16 | 0.13 | 3.89 |
| 512 | **(b)** | 2^12 | 17 / 28 | **0.184 M** | 2^15 | 0.08 M | 33,280 | **0.43** | 0.13 | 1.27 |
| 512 | (c) | 2^12 | 63 / 0 | 0.258 M | 2^24 | 50.5 M | 0 | 3.81 | 0.13 | 0.98 |

**Llama-3-8B** (fold 536.9 M entries in every option)

| T | option | n | A / H rows | elements | max zc | zc terms | LogUp inv | prover s | verifier s | receipt MB |
|---|---|---|---|---:|---|---:|---:|---:|---:|---:|
| 32 | (a) | 2^13 | 523 / 0 | 4.284 M | 2^22 | 8.39 M | 0 | 1.84 | 0.82 | 2.17 |
| 32 | **(b)** | 2^12 | 41 / 76 | **0.479 M** | 2^17 | 0.28 M | 131,104 | **1.24** | 0.82 | 1.42 |
| 32 | (c) | 2^12 | 21 / 0 | 0.086 M | 2^22 | 12.6 M | 0 | 2.18 | 0.82 | 0.89 |
| 128 | (a) | 2^14 | 1,035 / 0 | 16.96 M | 2^24 | 33.6 M | 0 | 3.95 | 0.82 | 3.89 |
| 128 | **(b)** | 2^12 | 41 / 76 | **0.479 M** | 2^17 | 0.28 M | 131,200 | **1.24** | 0.82 | 1.42 |
| 128 | (c) | 2^12 | 39 / 0 | 0.160 M | 2^24 | 50.4 M | 0 | 4.59 | 0.82 | 0.93 |
| 512 | (a) | 2^15 | 2,059 / 0 | 67.47 M | 2^26 | 134 M | 0 | 12.26 | 0.82 | 7.31 |
| 512 | **(b)** | 2^12 | 41 / 76 | **0.479 M** | 2^17 | 0.28 M | 131,584 | **1.24** | 0.82 | 1.42 |
| 512 | (c) | 2^12 | 111 / 0 | 0.455 M | 2^26 | 202 M | 0 | 14.26 | 0.82 | 1.08 |

Byte-table lookups: 0 in all three. LogUp queries: `T` in (b), none in (a)/(c).
With supports over the `T x V` cube materialised as today (`b.supp` builds the
full cube) the verifier pays up to +0.67 s more in (a) at 8B T512 [MODEL]; a
factored (tensor-product) support removes it. Of the 1.24 s of (b) at 8B, 0.90 s
is the fold [MODEL]; the rest is the model's fixed per-slot term (0.08 s per
zero-check slot), an upper-side assumption for slots this small.

### 2.5 Choice

**(b).** It is the only option whose committed size and prover sum-check work do
not grow as `T * V`; it is built from constructs the private block already has (a
committed histogram on `A`, Fp2 helpers on `H`, the single value-0 LogUp sum
claim, beta / tag compression of a two-column tuple, a claim at partially fixed
coordinates as the matmul slots already make); and it makes `B_in` an ordinary
two-site boundary. What is new: a table whose values depend on a challenge
(`r_emb`), a fourth table tag, and the `V`-row table helper.

---

## 3. Output side: final norm, head, greedy argmax

### 3.1 The relation (stage OUT)

1. **Row selection.** *Public last row* (mode i): stage OUT's `x` row equals
   `B_out` at row `T - 1` (`B_out` read at coordinates fixed to the bits of
   `T - 1`); the prompt must fill the bucket `T` exactly. *Hidden length* (mode i,
   R2): the prompt is right-padded inside `T` with any real id, and a one-hot
   selector `s` over positions picks row `P - 1`: `x_sel(i) = sum_t s(t) B_out(t, i)`
   (a standalone slot with three private tables `s`, `B_out`, `x` and a public `u0`
   on the `x` term), booleanity and `sum s = 1` (SBOOL, one slot, each clause with
   its own fresh coefficient). **`s` is sealed under the input
   root (B-2):** it is half 1 of the input token endpoint, and an IO-s slot in
   stage OUT proves `A_out`'s `s` equals that half over its whole padded extent. The
   input owner's check confirms `s = e_{P-1}`; without that seal any prefix would
   verify (check finding F-1). Causal attention makes positions `< P` independent
   of the padding after them. Fallback: `s` in the output endpoint's plane beside
   the token (one site, checked by the output owner).
2. **Final RMSNorm** in the spec's folded form: exactly the block's `norm_a`
   relation with a **uniform gain** (`gamma_f[i] = g0 = 127`): `D = isqrt(sum x^2 +
   Ceps)`, `y = floor((2 x g0 Cn + D 2^tn) / (2 D 2^tn))`, remainder windows exact,
   `y` in `[-127, 127]` by the `sym` lookups — with D24's per-profile `tn` (10 at
   width 2048, 9 at 4096), so the remainder window is exactly 32 bits and D16
   rules 1–4 hold (check table 3.2: every clause below `p/2`). `x`'s int16 range is
   re-proved in the stage, as every block re-proves its input. The calibration of
   `Cn` follows C-7.
3. **Head matmul**, the block's matmul slot over the inner index `d`:
   `l~(p) = sum_i y~(p_t, i) W'~(p_j, i)` with
   `W' = round(lm_head diag(norm_weight) R^T / s_w)` int8, one per-tensor scale
   (the calibration's `qw`, clipped to `[-127, 127]`; the fidelity lane's s4 builds
   exactly this). The logits `l` are the **raw integer accumulators** (no
   requantization; the zkVM token kernel's `head_logits` semantics), `|l| <= d *
   127^2` = 33,032,192 (TinyLlama) / 66,064,384 (8B) [COUNTED]. Like every
   accumulator in the block, `l` is **virtual**, never a plane of its own.
4. **Keyed greedy argmax.** With `V_pad = 2^v`, define the key
   `kappa_i = 2^v l_i + (2^v - 1 - i)`: larger logit first, then smaller index.
   The first maximum of `l` is the **unique** maximum of `kappa`. Commit, per
   output position `t`: a selector `e[t, .]` over the vocabulary, six byte limbs
   `lambda_k[t, .]` of a difference `delta`, and per-position scalars `tok[t]`,
   `M[t]`. Prove:
   * (A1) `e(1 - e) = 0`; `e = 0` and `lambda = 0` on padded vocabulary entries
     (P-1 pad-zero);
   * (A2) `sum_i e[t, i] = 1`; (A3) `tok[t] = sum_i i e[t, i]`;
     (A6) `sum_i e[t, i] delta[t, i] = 0` — batched into one standalone slot written
     with a public factor in every monomial (B-3):
     `sum eq(r, t) [ supp_V e (c1 + c2 iota + c3 delta) - u0 (c1 supp_T + c2 tok) ] = 0`,
     `u0` the public indicator of vocabulary entry 0, and `c1, c2, c3` **fresh
     challenges** drawn after `A_out` (so A2, A3 and A6 hold separately);
   * (A4) `delta = sum_{k<6} 256^k lambda_k`, every limb a byte, so
     `delta in [0, 2^48)` — **no top-limb pin** (C-4);
   * (A5) the head claim lands on the **virtual logits**
     `l*[t, i] = supp_V(i) (M[t] + 2^-v (i - tok[t] - delta[t, i]))` — the host
     term of the vocabulary zero-check, linear in committed planes.

**Why it is the first maximum (soundness).** Fix `t`. (A1)+(A2): `e[t, .]` is
one-hot at some `j < V` (roots of `e(1 - e)` are only 0 and 1, and the sum of at
most `V_pad T_out < p` ones is 1); (A3): `tok = j`; (A6): `delta_j = 0`. (A5) at
`i = j`: `2^v (M - l_j) = 0`, so `M = l_j` — neither under- nor over-stated. Hence
for every `i < V`, `delta_i = 2^v (l_j - l_i) + (i - j)` in the field. The right
side is an integer of absolute value below `2^v * 2 d 127^2 + V < 2^45`; (A4) says
`delta_i` is an integer in `[0, 2^48)`; since `2^48 + 2^45 < p`, the two integers
are equal, so `2^v (l_j - l_i) + (i - j) >= 0`. If `l_i > l_j` the left side is at
most `-2^v + (2^v - 1) < 0`: impossible. If `l_i = l_j` then `i >= j`. So `j` is the
lowest index among the maxima — numpy's first-maximum rule — and `l` is the true
integer product `y W'^T` (matmul slot at a random point drawn after `A_out`; every
term below `2^26 << p`). The check's randomised exhaustive test (1,200 cases,
extreme and tied logits, with and without the pin) found only numpy's first
maximum admissible [COUNTED]. **Completeness:** honest `delta_i = kappa_j -
kappa_i` lies in `[0, 2^44)`; `M = l_j` needs no range. **No honest argmax is ever
refused**, also if the head admitted -128.

**Every relation is load-bearing** (R0 V13–V15, each accepted when its one
relation is removed): A6 alone stops an overstated `M` with a non-maximal `j`
(V13); the pad-zero term alone stops a selector on a padded entry, which would
output id `V`, not a token (V14); and **A3 alone binds the output id**: since
`delta_i = 2^v (l_j - l_i) + (i - j)` does not depend on `tok`, a forger keeping
`e`, `delta` honest for `j` can output any `tok'` by setting
`M = l_j + 2^-v (tok' - j)` in the field, and every relation but A3 holds (V15).

**Batching rule (v3, CHECK2 N-3), stated once for every new slot.** Wherever a slot
batches several clauses into one polynomial — stage IN's query zero-check (LogUp,
BOS, pad), its table zero-check (clause, pad), SBOOL (booleanity, sum), RSEL (A2,
A3, A6), VZC (booleanity, head host term, helpers, pad), DZC (norm quotient, `x`
limbs, helpers, pad), the IO slots — **each clause carries its own fresh challenge
coefficient**, drawn after every commitment the clause constrains. A sum of clauses
with fixed coefficients lets one clause absorb another (CHECK2 N-1 is the instance
that happened).

**Recorded alternatives.** (S) *Step tie rule*: `delta' = M - l_i - [i < tok]`
needs 26 / 27 bits (four limbs) but a committed step vector `s_lt` and a slot
`s_lt = LT * e` with a public prefix matrix: a new slot type for 22 % fewer
committed words at mode (ii) (table below). (U16) *16-bit limbs*: three limbs; the
stage's row width must be at least 2^16 (the stage-23 invariant `log(Tab) == row
width`, `layout.rs::domain_log_at`). (R) *Per-row head scales*, only if the
fidelity check fails with one per-tensor scale: each row multiplied by a public
integer multiplier, widening `delta` by its bit length.

### 3.2 Planes and slots of stage OUT (U8, keyed, no pin; `T_out` output rows)

| domain | A planes | lookups / entry | H helpers (Fp2) |
|---|---|---:|---:|
| To (`T_out`) | `D`, `Dsq`, `tok`, `M` | — | — |
| Lo (16 `T_out`, lifted) | isqrt limb plane | 1 | 1 |
| Do (`T_out x d`, lifted) | `x`, `xl0`, `xl1`, `y`, `rho x4`, `sigma x4` | 12 | 6 |
| Vo (`T_out x V_pad`, lifted) | `e`, `lambda_0..5` | 6 | 3 |
| Tab | U8 multiplicities | — | table helper + `u` |
| Ts (hidden length only) | `s` | — | — |

Slots (11 public row; 13 hidden length, SEL standalone): IO-in (`x` row = `B_out` row `T - 1`) —
or SEL + SBOOL + IO-s for the hidden length — SS (private, hosted by TZC), TZC,
LZC, HEAD (private, hosted by VZC), DZC (norm quotient, `x` limbs, helpers, pad),
VZC (`e(1-e)`, the head's host term on `l*`, helpers, pad), RSEL, TAB, ZS, IO-out
(over the output endpoint's whole 256-word plane: `end(z) = u0(z) tok`). Claim
sites [COUNTED]: 47 on `A_out` (50 hidden length: SEL claims `s` and `x`, SBOOL
and IO-s claim `s`, in place of IO-in's one; v3, CHECK2 N-7), 12 on `H_out`;
`M_out` 26 rows (30 hidden length); `B_out` one site (plus block `L-1`'s); the output endpoint one.

### 3.3 Output endpoint and the two modes

* **Mode (i), next token**: `T_out = 1`. The run's new output endpoint is **one
  hidden token id** (the greedy next token after the prompt) in a 256-word plane
  at 2^8, rate 1/8: one data row plus 5 mask rows. Matches the zkVM token model's
  semantics (one id for the last row, `private-model-kernel::greedy`).
* **Mode (ii), greedy continuation in one pass**: with a prompt of `P` tokens and
  `G` generated tokens, `T = P + G`. The input endpoint holds the whole sequence;
  stage OUT computes the argmax at positions `P-1 .. T-1`; a SHIFT slot proves
  `tok_out[k] = tok_in[k+1]` for `k` in `P-1 .. T-2` (public shifted `eq` table over
  `T`, a public factor in every monomial, verifier `O(T)`); the output endpoint
  holds the answer `tok_out[P-1 .. T-1]` (the `G` generated ids and the next one).
  One proof attests that every generated token was the model's greedy choice. The
  input endpoint carries **two** claim sites (stage IN's IO-in and stage OUT's
  SHIFT), opened once at the end of the run (R9). `P` is public in the first
  version (R2). The prover generates the continuation with the **integer** model;
  the fidelity lane's F4 run confirmed prefix consistency of the integer stack on
  TinyLlama (positions `< T'` identical between T128 and T64 / T32 runs; a control
  with changed later tokens left every earlier position unchanged) [MEASURED by
  that lane, not here].
* Until mode (ii) exists, several tokens come from **repeated mode-(i) runs**.
  Each run's endpoints are fresh prover seals; nothing proves that run `k+1`'s
  input is run `k`'s input plus its output (joining finished runs is forbidden by
  D12a and needs D18 option B plus D8/D11). Only the owner can check that chain;
  it is not a proved token stream (ZK60_THROUGHPUT_TARGET.md workload 3).

### 3.4 How the caller learns the token under P1

Outputs are hidden from the verifier, not from their owner. Under D18 the prover
seals the output endpoint; it sends the authorised owner, over a private channel,
the token id(s) **and the endpoint's decommitment**: every row (data and the 5
mask rows), **each row's 256 pad coefficients** (C-5) and the Merkle leaf salts.
The owner re-encodes, rebuilds the root (no proof work) and compares it with the
output root in the accepted receipt; the input owner checks the input root the
same way, including the sealed selector `s = e_{P-1}` in the hidden-length case.
Because the run verified, the decommitted id is the model's greedy next token on
the input sealed under the input root, after exactly the sealed prompt length.
Needed: a small verifier-side `endpoint_g::owner_check(spec, root, plane,
decommitment)` (does not exist; R0's `owner_check` models its semantics with a
stand-in hash, section 6.4). Rules: the decommitment is a private artifact, never
in a published or retained bundle (D21); the roots are never registered or
chained (D23, accepted 19:28 UTC); under a tagged profile the hiding of the roots
rests on D19b's model (accepted 19:28 UTC) (C-6). The owner check works at the
endpoint's derived geometry and also checks the profile's BOS at position 0 (D26
C-d). The decommitment lets its holder unmask the IO-out
terminal, a function of the token alone; the privacy statement must say the owner
is outside the adversary for its own endpoint. Only one opening of an endpoint
ever happens (two would recover the 512-coefficient row, D11 at its smallest
geometry).

### 3.5 Counted costs of stage OUT

Mode (i) does not depend on `T` (one row through the head). Seconds [MODEL]:
laptop CPU; "5090 S0" = keyed GPU commit, other phases on a desktop host CPU;
"5090 S3" = whole prover resident (speed plan bands, central). Row width 2^12 in
all mode-(i) rows (every opening 2^-103.69).

| model | variant | A / H rows | elements | byte lookups | max zc | laptop s | 5090 S0 / S3 s | verifier s | receipt MB |
|---|---|---|---:|---:|---|---:|---:|---:|---:|
| TinyLlama | mode (i), public row | 170 / 92 | 1.073 M | 0.250 M | 2^15 | 0.97 | 0.63 / 0.19 | 0.13 | 2.37 |
| TinyLlama | mode (i), hidden length (input-sealed) | 177 / 92 | 1.102 M | 0.250 M | 2^15 | 1.06 | 0.67 / 0.19 | 0.13 | 2.40 |
| 8B | mode (i), public row | 338 / 236 | 2.351 M | 0.840 M | 2^17 | 1.94 | 1.10 / 0.23 | 0.82 | 3.01 |
| 8B | mode (i), hidden length (input-sealed) | 345 / 236 | 2.380 M | 0.840 M | 2^17 | 2.02 | 1.14 / 0.23 | 0.82 | 3.04 |
| 8B | mode (i), public row, with pin (v1) | 338 / 302 | 2.621 M | 0.971 M | 2^17 | 1.96 | 1.10 / 0.23 | 0.82 | 3.15 |

Mode (ii), `T_out = T`, Llama-3-8B (stage OUT at its receipt-optimal width):

| T | variant | n | elements | byte lookups | max zc | VZC slot tables | laptop s | 5090 S0 / S3 s | receipt MB |
|---|---|---|---:|---:|---|---:|---:|---:|---:|
| 32 | U8 keyed | 2^14 | 59.9 M | 26.8 M | 2^22 | 0.9 GiB | 9.9 | 4.46 / 0.55 | 12.9 |
| 128 | U8 keyed | 2^15 | 235.1 M | 107.0 M | 2^24 | 3.8 GiB | 33.5 | 14.4 / 1.51 | 24.9 |
| 512 | U8 keyed | 2^16 | 931.7 M | 427.9 M | 2^26 | 15 GiB | 127.1 | 53.9 / 5.32 | 48.7 |
| 512 | U8 step | 2^16 | 730.2 M | 293.7 M | 2^26 | 13 GiB | 106.3 | 45.6 / 4.47 | 42.4 |
| 512 | U16 keyed | 2^16 | 595.5 M | 226.6 M | 2^26 | 11 GiB | 83.6 | 35.7 / 3.55 | 38.2 |

TinyLlama mode (ii) U8 keyed: 16.3 M / 63.0 M / 247.7 M elements at T32 / T128 /
T512 [COUNTED], 3.1 / 9.4 / 33.9 s laptop [MODEL]. The slot-table column (16 bytes
x (tables + 3) x domain, the speed plan's VRAM rule) flags a scaling risk: at 8B
T512 the vocabulary zero-check alone needs 11–15 GiB against 3.4 GiB for the
largest block slot; mode (ii) at `T >= 512` on one GPU needs the vocabulary cube
split into chunks (one VZC instance per chunk: a few more claim sites, no new
relation) or a streaming prover.

---

## 4. Privacy and soundness

### 4.1 The construction rules, item by item

* **D12 item 1 / D12a (no commitment opened twice).** Every new commitment —
  `A_in`, `H_in`, `M_in`, `A_out`, `H_out`, `M_out`, `B_in`, `B_out`, the two token
  endpoints — is opened exactly once. `B_in` / `B_out` are opened in the stage
  after the second claim exists; a two-site input endpoint at the end of the run.
* **D12 item 2 / D12a (one transcript, two external endpoints for the run).**
  Stages IN and OUT are stages of the same run transcript; the run has exactly
  two external endpoints, now the token planes.
* **D12 item 3 / D12a (hidden intermediates only on prover-generated
  commitments).** `x_in_L00` and the last block output move from external
  endpoints to internal boundaries; logits (virtual), `e`, `delta`, `M`, the final
  norm's `D` and `y` sit only on `A_out` / `H_out`. Boundary rows are **derived**
  (`data + 2*sites + 2`), never declared.
* **D12 item 4 analogue (range proofs the next relation relies on).** The final
  norm's int8 output range is mandatory: the argmax soundness uses
  `|l| <= d 127^2`. Stage OUT re-proves `x` in int16.
* **D12 item 5 / D12b(3) (scales bound to the approved calibration).** `B_in`'s
  scale is `s_in` and `B_out`'s is `s_out`; both are constants of the approved
  calibration. The run's calibration identity must additionally absorb the
  embedding-table digest (which encodes `s_in` and the rotation), the final-norm
  constants (`g0`, `Cn_f`, `tn_f`, `Ceps_f`), `V`, the BOS constant (v3, N-2), the
  head digest, the output mode and the selector variant (public row / P / F; D26
  C-a).
* **D12b(1)(2).** The run statement is written only after the whole run,
  including both new stages, verifies; one generator per run.
* **D17.** A token-I/O run is a new run profile (its own string, transcript and
  hash-tag key set); every block profile, every existing run profile and the D22
  toy keep their bytes. Every IO slot covers its endpoint's whole padded plane
  (rule 1; C-3).
* **D18.** The prover seals both token endpoints. **D21 / D23 / D19b**: section 3.4.
* **D24's F-1 rule.** Every constant an export can choose for the new stages
  (`g0`, `Cn_f`, `tn_f`, `Ceps_f`, `V`, the head and embedding digests; the limb
  count is derived, never exported) gets a declared class validated at the trained
  door on both sides and in `Layout::for_shape`, and every no-wrap clause that
  touches it is re-derived over the whole class.
* **D20 (refusals).** Stage IN: out-of-vocabulary ids are refused by the prover
  before any commitment (reason never shown, D12b(1)); a zero LogUp denominator is
  decided by the **table** side, which is public (D22 V-3's argument). Stage OUT:
  final-norm int8 overflow is either impossible (refusal-free constants) or an
  input-dependent refusal of the blocks' norm class, decided by C-7 with F2/F6
  evidence. The argmax never refuses an honest witness. The hidden-length variant
  adds padded positions, which must not refuse either (6.3 F6).
* **D16 rule 5** (every committed value under a non-unit coefficient is ranged or
  determined): the new non-unit coefficients sit on `tok` (`2^-v` in `l*`),
  `M` and `m`; `tok = j` (A3), `M = l_j` (A5 + A6), `m` needs no range for LogUp;
  byte limbs carry `256^k`. Audited at R1 (C-8).

### 4.2 What the rank / CFS gate must re-check

* **G-1** joint rank of every new hidden plane over the commitments that hold it,
  restricted to reserved rows: `tok` (A_in + input endpoint), `s` (A_out + input
  endpoint half 1), `m`, `h_q`, `h_tab`, `e`, `lambda`, `M`, the final-norm planes.
* **G-2** `B_in`'s stage-IN claim is at a point with a **challenge-fixed column
  coordinate** `r_emb`; `B_out`'s claim in the public-row variant is at **public
  fixed row bits** (`T - 1`; at 8B T32 one of them falls in the reserved pair's
  column tail, which the check found still uniformly masked). The tools must
  accept partially fixed points on a boundary.
* **G-3** the CFS slots and functionals of the two new stages (4 and 11–13 slots).
* **G-4** the pad positions of the vocabulary domains (32,000 -> 32,768;
  128,256 -> 131,072), the P-3 lift of every small domain, and the endpoint pad
  words: pad-zero terms present for `m`, `h_tab`, `e`, `lambda`, `tok`, `h_q`, `s`;
  public support factors in the IO slots.
* **G-5** the stage-23 invariant `log(Tab) == row width` for each new stage (2^12
  for U8 — satisfied; U16 needs 2^16).
* **G-6** the token endpoints (2^8 rows at rate 1/8, one or two sites) need the D17
  hard gate: a joint-view analysis on a captured receipt at that geometry.
* **G-7** the two-site input endpoint (hidden-length mode i and mode ii) and the
  SHIFT / IO-s claims on it.

### 4.3 New channels examined

* **Vocabulary-size domain**: `V` and `V_pad` are public model facts. Padding is
  safe with the pad-zero terms (G-4); padded table entries repeating entry 0 is
  belt-and-braces (pad-zero already removes them from the sum).
* **Token histogram `m`**: the prompt's multiset of ids, a new hidden plane of the
  same kind as today's byte histograms; claimed once, masked.
* **Tie rule**: the transcript has the same shape with or without ties; whether a
  tie occurred sits in hidden `delta` limbs. Only the honest prover's own control
  flow depends on it (timing, out of scope by D20).
* **Low-entropy output (one id among 2^17)**: hiding rests on a fresh 32-byte salt
  per encoded column, 256 pads per row and the 5 random rows, not on the value's
  entropy (check P-3). Whoever receives the decommitment learns the id.
* **Public lengths**: `T` (a bucket) is public as today. The public-row variant
  forces prompt length = `T`; the hidden-length variant keeps `P` sealed under the
  input root. Mode (ii) with public `P` publishes prompt and answer lengths.
* **Verifier tables** (`tau`, `iota`, supports, `u0`): functions of public data and
  challenges only.

### 4.4 Soundness: no-wrap clauses and whole-proof terms

Every relation read over the integers must have all terms far below `p/2`:

| clause | bound [COUNTED] |
|---|---|
| N-1 head accumulator `|l|` | `d * 127 * 127` < 2^25.98 (8B); with -128 admitted, `d * 127 * 128` |
| N-2 keyed difference `delta` | `[0, 2^48)` by six byte limbs (no pin); honest `< 2^44` (8B) / `2^41` (TinyLlama) |
| N-3 the identity `delta_i = 2^v (l_j - l_i) + (i - j)` | `< 2^45`; `2^48 + 2^45 < p` |
| N-4 `tok = sum i e` | exactly `j < V` (field identity with one-hot `e`) |
| N-5 byte-lookup multiplicities, stage OUT | at most the stage's lookup count, 0.428 G `< 2^29` (8B T512 mode ii) |
| N-6 LogUp multiplicities, stage IN | `m_v <= T`; no range needed (residues `< p`) |
| N-7 final norm | the block norm's D24 class (window 32, `D` three limbs, `Cn <= 2^20`, `Ceps <= 2^40`, `g0 in [1, 127]`); largest clause `2 g0 Cn |x|` = 2^42.99 at the class edge (check table 3.2) |
| N-8 embedding values | int16 by the table; re-proved by block 0 |

**Per-opening proximity terms** (column test `(1 - delta/3)^256`, ZK code
`RS(n + 256, n inv_rate)`, distance `delta = 1 - (n + 256)/(n inv_rate)`;
`zkp-core/src/pcs.rs`) [COUNTED]:

| commitment | geometry | per opening |
|---|---|---:|
| token endpoints | 2^8, rate 1/8 | 2^-106.25 |
| `A_in`, `H_in`, `A_out`, `H_out` (mode i) | 2^12, rate 1/4 | 2^-103.69 |
| `A_out`, `H_out` (mode ii, 8B T512) | 2^16, rate 1/4 | 2^-106.09 |
| `M_in`, `M_out` | RS(1024, 4096), as every block's `M` | 2^-106.25 |
| `B_in`, `B_out` | as the stack's boundaries (block row width, rate 1/4); they replace the two old endpoints one for one | 2^-103.69 (TinyLlama T32) / 2^-104.97 (8B T32) |
| *v1, for the record:* token endpoints | 2^8, rate 1/4 | *2^-67.34* |

**Whole-proof terms, with the register's accounting (D15 correction of 19:40 UTC,
`results/zk60_soundness_recount_20261017/RECOUNT.md`).** A run opens `4L + 1`
commitments: `A`, `H` per block, `L - 1` boundaries and two endpoints at the real
ZK-code distance, one `M` per block at 2^-106.25. Token I/O turns the two endpoints
into `B_in` / `B_out` at the same geometry and adds eight openings (`A_in`, `H_in`,
`M_in`, `A_out`, `H_out`, `M_out`, two token endpoints). The whole-run figures add
these openings and the new lookups (R14: `4N / |F|`) to the recount's whole-run
figures [COUNTED]:

| configuration | 8B T32 | TinyLlama T32 | TinyLlama T128 | 8B T512 |
|---|---:|---:|---:|---:|
| stack alone, commitment term (RECOUNT) | 2^-98.19 | 2^-97.55 | 2^-99.27 | 2^-98.99 |
| v1 geometry (token endpoints at rate 1/4), commitment term | *2^-66.3* | *2^-66.3* | — | — |
| **with token I/O, mode (i)**, commitment term | **2^-98.04** | **2^-97.46** | **2^-98.98** | **2^-98.75** |
| with token I/O, mode (ii) U8, commitment term | 2^-98.09 | 2^-97.48 | 2^-99.07 | 2^-98.83 |
| stack alone, whole run, R14 (RECOUNT) | 2^-96.77 | 2^-97.09 | 2^-96.45 | (projection about 2^-93) |
| **with token I/O, mode (i)**, whole run, R14 | **2^-96.71** | **2^-97.02** | **2^-96.41** | — |
| with token I/O, mode (ii) U8, whole run, R14 | 2^-96.67 | 2^-97.02 | 2^-96.37 | — |

Token I/O costs at most 0.3 bit of the commitment term and under 0.1 bit of the
whole run at the registered shapes; from T64 up the stack's lookup term, not the
commitments, sets the whole-run figure (D15 correction). The LogUp and
Schwartz–Zippel terms of section 2.3 are at most about 2^-102. Mode (ii) at 8B T512
adds about 4 % to the byte lookups (0.43 G on about 9.8 G). The hidden-length and
public-row variants have the same terms (the two-site endpoint is still one
opening at 2^-106.25, D26).

**Not proved by the receipt** (same status as D24's list): that the embedding
table and `W'` derive from the named checkpoint (the statement names the export's
digests), and the rotated basis.

---

## 5. Cost at Llama-3-8B: where the 525 M-weight head goes

The head has 128,256 x 4,096 = 525.3 M weights (536.9 M padded), against
218.1 M (243.3 M padded) for a block. **In this construction the head's weight
count enters only through the public fold**: once per proof, prover and verifier
each compute `W'` folded with `eq(r_j)` (`fold_rows_i8`), `O(V_pad * d_pad)`. The
embedding table adds the same again (int16). Everything that is committed scales
with the number of output rows, not with the weights.

| item | Llama-3-8B |
|---|---|
| head fold, prover | 536.9 M entries, 0.90 s laptop CPU [MODEL] (1.68 ns / entry; a block's fold is 0.41 s) |
| head fold, verifier | 0.78 s [MODEL] (1.46 ns / entry) |
| embedding fold, prover / verifier | 536.9 M entries, 0.90 s / 0.78 s [MODEL] |
| stage IN committed | 0.479 M elements [COUNTED] |
| stage OUT committed, mode (i) | 2.351 M elements [COUNTED] (a T32 block: 28.3 M) |
| stage OUT committed, mode (ii) T512, U8 / U16 | 932 M / 596 M elements [COUNTED] (a T512 block: 663 M) |

Totals of token I/O (stage IN option b + stage OUT, public row; the hidden-length
variant adds 0.03 M elements and about 0.08 s laptop) against the 32-block stack:

| T | mode | elements | laptop CPU s | 5090 S0 s | 5090 S3 s | verifier s | receipt MB |
|---|---|---:|---:|---:|---:|---:|---:|
| 32 | (i) | 2.83 M (+0.31 %) | 3.18 (+3.0 %) | 1.86 (+3.8 %) | 0.43 (+4.7 %) | +1.63 (+12.4 %) | +4.4 (+0.9 %) |
| 128 | (i) | 2.83 M (+0.08 %) | 3.18 (+0.9 %) | 1.86 (+1.4 %) | 0.43 (+2.3 %) | +1.63 (+6.6 %) | +4.4 (+0.5 %) |
| 512 | (i) | 2.83 M (+0.01 %) | 3.18 (+0.2 %) | 1.86 (+0.3 %) | 0.43 (+0.6 %) | +1.63 (+0.8 %) | +4.4 (+0.2 %) |
| 32 | (ii) U8 | 60.4 M (+6.7 %) | 11.1 (+10.4 %) | 5.22 (+10.7 %) | 0.75 (+8.2 %) | +1.63 | +14.3 |
| 128 | (ii) U8 | 235.6 M (+6.2 %) | 34.7 (+10.2 %) | 15.2 (+11.3 %) | 1.72 (+9.1 %) | +1.63 | +26.3 |
| 512 | (ii) U8 | 932.1 M (+4.4 %) | 128.3 (+7.7 %) | 54.7 (+8.9 %) | 5.52 (+7.5 %) | +1.63 | +50.2 |
| 512 | (ii) U16 | 596.0 M (+2.8 %) | 84.8 (+5.1 %) | 36.4 (+5.9 %) | 3.75 (+5.1 %) | +1.63 | +39.7 |

Elements and receipt bytes [COUNTED]; seconds [MODEL] (stack figures from the
same cost model: 8B stack laptop 106.8 / 339.2 / 1,663 s, S3 9.2 / 18.8 / 73.3 s at
T32 / T128 / T512). TinyLlama mode (i): +1.26 M elements, +1.40 s laptop, +0.26 s
verifier at every T (+3.6 % / +1.0 % / +0.17 % of the 22-block stack's laptop time).

**For the speed plan.** Mode (i) is a constant per pass: about 0.4 s on a 5090
with the whole prover resident, which vanishes at throughput-sized passes. Mode
(ii) behaves like adding 1.4 (elements) to 2.4 (S3 time) blocks to the 32-block
stack at T512 (0.9–1.6 blocks with U16 limbs): plan for +5 % to +9 % and for the
vocabulary-chunked zero-check. The verifier's +1.6 s per pass is the largest
relative item at short T; the lever that would remove it — and the 7.8 G-entry
weight folds of the blocks themselves — is a preprocessed commitment to the public
tables, opened at the fold point instead of folded (the research agenda's "cached
preprocessing"; not designed here, it would change every matmul slot).

---

## 6. Test-first implementation plan

General acceptance for every rung (project rules): a **generic honest witness**
(dense random weights and tables, heads that differ, distinct embedding rows,
logits that are not degenerate) checked against an **independent exact
reference** (R0, section 6.4); prove, then **verify in a fresh process from
bytes**; every tamper control written failing-first with its catching slot
predicted before it is run; existing profiles byte-identical (pins re-run:
blocks, runs, D22 toy); new code behind new profiles only (D17); all heavy runs
through the resource guard.

### 6.1 Rungs

**R0 — reference semantics (no proof). Done (section 6.4).**

**R1 — tiny-vocabulary rung (seconds per proof).** The trained-calibration
development geometry (`rung_tc`: T32, d384, block row width 2^10), `L = 2`
blocks, a synthetic vocabulary `V = 300` (pads to 512, exercising the pad rule),
dense int16 embedding with distinct rows, dense int8 head, the profile's BOS
constant. Stage IN and stage OUT at row width 2^12, token endpoints at 2^8 rate
1/8 (B-1). Build the public-row variant first (its gate is open: N-1 and N-2 are
in this design); the hidden-length variant (D25 T2) follows D26's two-site
endpoint. `r0/vectors.json` is the oracle; every control below is written
failing-first, with the catching slot predicted before it runs.

*Acceptance, general:*

* honest run verifies in a fresh process from bytes; the owner check reproduces
  both token roots at the derived geometry (rows, pads, salts; D26 C-d) and the
  decommitted id equals R0's reference (V01 / V02);
* **per-opening figures stated** for the rung: stages 2^-103.69, token endpoints
  2^-106.25; the rung's own blocks at 2^10 are 2^-96.13 per opening (a
  development fixture, not a security claim);
* **D16 rule-5 audit** of the new layouts (section 4.1) and the D16 item-6
  norm-alias controls re-run on the final norm;
* rank / CFS controls fire on the new stages (G-1 to G-7);
* existing profiles byte-identical (block, run and D22 toy pins re-run).

*Tamper controls* (forgery -> predicted catching slot; R0 vector):

| # | forgery | caught by | R0 |
|---:|---|---|---|
| 1 | `e` on a **padded** vocabulary entry, `tok = V`, `M = max + 1` | VZC pad-zero term | V14 |
| 2 | `e` at a non-maximal `j`, `M = max + 1`, every `delta` in six bytes (**A6-only**) | RSEL (`c3`, A6) | V13 |
| 3 | `e`, `delta` honest for `j`, output `tok' != j` with `M = l_j + 2^-v (tok' - j)` (**A3-only**) | RSEL (`c2`, A3) | V15 |
| 4 | **`tok_0 = BOS + 1`, `h_q(0) = 0`**, row 0 arbitrary, histogram without position 0 | stage IN query zero-check, through the BOS clause's own `mu_bos` | V16 |
| 5 | `tok_0 != BOS`, otherwise honest | the same clause | V17 |
| 6 | position selector **`s = (2, -1)`** summing to 1 | SBOOL (booleanity) | V19 |
| 7 | a **consistent re-lookup** in `A_in` (`tok`, row and histogram changed together) under the honest seal | IO-in | V21 |
| 8 | sealed right (`s = e_{P-1}`), stage OUT uses another position | IO-s | V20 |
| 9 | output plane seals another id (the owner is told that id) | IO-out | V22 |
| 10 | a nonzero pad word in a token endpoint | the IO slot's support factor | V23 |
| 11 | wrong output token (`tok` or the endpoint set to another id) | IO-out / RSEL | V22, V15 |
| 12 | non-maximal token with `M = l_j`, `delta` as field values | byte lookups / A5 | V04 |
| 13 | tie broken the wrong way (identical head rows, higher id chosen) | A5 (`delta_{j1} < 0`) | V03 |
| 14 | two-hot, fractional or `(2, -1)` selector `e` | VZC booleanity / RSEL (A2) | V05 |
| 15 | a `delta` limb that is not a byte (`delta >= 2^48`) | byte lookups | V12 |
| 16 | wrong embedding row; one changed word; a padded token id; histogram off by one | query / table zero-checks, LogUp sum | V06, V08, V07 |
| 17 | final norm: `y` off by one; `D` off by one; the D16 alias; `y` outside int8 with in-window remainders; `x` not int16 | remainder limbs; `D` limbs (twice); `sym` lookups; `x` limbs (DZC) | V18 |
| 18 | public-row variant: logits from row `T - 2` | IO-in (fixed public row bits) | — |
| 19 | hidden length: a sealed `s` that is not `e_{P-1}` | the owner check (not the verifier, by design) | V10 |
| 20 | the input endpoint opened early, twice, or with a claim count other than 2 | run verifier (D26 C-b) | — |
| 21 | a two-site endpoint declaring another row count | its spec constructor (D26 C-c) | — |
| 22 | a receipt re-read under another variant (public row / P / F) | the run statement's parameter and stage lines (D26 C-a) | — |
| 23 | wrong embedding / head digest; a final-norm constant or the BOS constant outside its class | the trained door, both sides | V24 |

**R2 — TinyLlama, mode (i).** The real `embedding_int16.bin` (32,000 x 2,048) and
the fidelity lane's `W'`; 22 blocks; T32 then T128. Acceptance: R1's controls at
this shape; the decommitted next token equals R0 on held-out sequences of both
domains; counted layout equals `token_io_count.py`'s numbers (rows, sites,
receipt bytes); phase timings recorded against section 3.5's [MODEL] figures.

**R3 — Llama-3-8B, mode (i).** 128,256 x 4,096 tables, 32 blocks at T32 (memory:
the int16 embedding is 1.05 GB, `W'` 0.54 GB, loaded per stage like a block).
Acceptance: as R2, plus the fresh-process verifier time against section 5's
+1.6 s.

**R4 — mode (ii).** SHIFT slot, two-site input endpoint (R9), vocabulary-chunked
VZC, factored public tables on the `T x V` cube and a stated digest-caching
assumption (C-9), U16 limbs at 2^16 if chosen. Extra controls: a continuation
token that is not the argmax at its preceding position -> refused; shift by two /
wrong `P` -> refused; first generated token wrong while the last is right ->
refused.

### 6.2 Order of work inside each rung

1. Counted layout and schedule lines first (tests assert row totals, sites and
   receipt bytes against the replica). 2. Witness builders and the reference.
3. Slots one at a time, each with its tamper control written first. 4. Run
integration (stage lines, boundary geometry, endpoint geometry). 5. Owner check.
6. Gate tooling (G-list). Commits stay test-first and each heavy run is guarded.

### 6.3 Fidelity checks the calibration lane must run (both models)

The TinyLlama fidelity lane (`results/zk60_token_io_fidelity_20261017/`) is
running F1, F2, F4 with this head definition; F4 is done (prefix consistency
holds).

* **F1** build the integer head: final-norm constants for a uniform gain (the
  `norm_site` solver with `c = 1`), plus the refusal-free `g0 Cn = 127 * 2^tn`
  (C-7); `W' = qw(lm_head diag(norm_weight) R^T, s_w)` with one per-tensor scale;
  record clipped weights.
* **F2** on the held-out sequences of both domains, at every position and at the
  last position: top-1 agreement of the **integer head vs the float head** on the
  same integer-stack output, and of integer head on integer stack vs the float
  model; exact integer ties and how often the tie rule decided; the integer margin
  `l_1 - l_2`; observed `max |l|` against `d * 127^2`; the honest `delta` maximum
  against `2^44` / `2^41`; final-norm refusals; KL of scaled integer logits vs float.
* **F3** greedy continuations (integer vs float model): first-divergence position.
* **F4** prefix consistency (done on TinyLlama).
* **F5** only if F2 is below R4's threshold: per-row head scales and their cost.
* **F6** hidden-length variant: no refusal in any block or in the final norm on
  right-padded inputs, for the chosen pad id.

### 6.4 R0 — reference semantics (landed 2026-10-17; extended in v3)

Files under `r0/` (pure Python, no third-party imports in the reference; one
thread; the whole suite runs in under a second):

* `token_io_ref.py` — three layers. (1) **Integer semantics**: `embed` (refuses
  out-of-vocabulary ids and a missing BOS first, naming no position), `final_norm`
  (the block's norm relation with a uniform gain, D24 window, refuses instead of
  clamping), `head_logits` (raw integer accumulators), `first_argmax` (numpy's
  rule), `select_row`, `next_token`. (2) **Relation checkers** — the relations
  the slots enforce, entry by entry over the Goldilocks base field, returning
  `(ok, reason)`: `check_stage_in` (BOS term, histogram pad-zero, the
  compressed-row LogUp identity with challenges drawn from a hash of the already
  fixed witness), `check_final_norm`, `check_argmax` (A1–A6, six byte limbs, no
  pin), `check_selector`, `check_selection`. (3) **Owner-side seal** (B-2, D25
  T2 / T5): `input_plane` (two halves `tok | s`), `output_plane`,
  `commit_standin`, `owner_check_input` (prompt, pad ids, zero pad words,
  `s = e_{P-1}`), `owner_check_output`. Also a causal integer stand-in for the
  proved blocks (`stand_in_stack`), so the hidden-length semantics can be run end
  to end. **v3 additions** (CHECK2 N-1, N-2, N-11, N-12, N-14): the BOS id as a
  per-profile parameter with `check_bos_class` (`BOS_TINYLLAMA = 1`,
  `BOS_LLAMA3_8B = 128000`), the owner check's BOS test; `check_argmax(...,
  skip=...)` to show which relation is load-bearing; a **helper-level** stage-IN
  model (`stage_in_helpers`, `check_stage_in_helpers`: committed `h_q`, `h_tab`,
  the query zero-check with LogUp, BOS and pad clauses and fresh coefficients drawn
  after the helpers, the table zero-check, the LogUp sum; an `"unweighted"` mode
  reproduces v2's text); `check_final_norm_field` (every value a field element,
  explicit windows for `x` int16, `D`, `a1`, `a2`, `sym`, remainders, relations
  mod p); and the IO relations `check_io_half` (IO-in / IO-s with the support
  factor over the whole half) and `check_io_out`.
* `token_io_vectors.py` -> `vectors.json` — a deterministic synthetic model under
  the generic-honest-witness rule (V = 300 padding to 512, d = 16, T = 8, dense
  int16 embedding with distinct rows, dense int8 head; the words are stored so R1
  can consume them without Python) and twenty-four vectors (V01–V12 from v2,
  V13–V24 added in v3):

| vector | what | outcome |
|---|---|---|
| V01 | honest, public last row (prompt fills T) | every check accepts; both owner checks accept; next token 229 |
| V02 | honest, hidden length (P = 5, right-padded, `s` sealed in the input plane) | every check accepts; next token 54 = the same prompt run unpadded (causality); the last row would have given 246 (the selector matters) |
| V03 | ties: two head rows made identical and maximal (ids 17, 203) | honest witness accepts with token 17; the witness choosing 203 is rejected (A5) |
| V04 | a non-maximal token (second best; a random index) | both rejected (A5: some difference leaves six limbs) |
| V05 | selector not one-hot: two-hot; two halves; `2` and `-1` | rejected by A2 / A1 / A1 |
| V06 | wrong embedding row; one changed word | both rejected by the LogUp identity |
| V07 | histogram +1; a count moved | both rejected by the LogUp identity |
| V08 | token id outside the vocabulary | honest prover refuses first; forged witnesses rejected (LogUp; pad-zero) |
| V09 | BOS missing | honest prover refuses; forged witness rejected by the BOS term |
| V10 | the check's F-1 attack: select row 0 instead of `P - 1` | **every verifier-side relation passes**; only the sealed input owner check rejects — the reason B-2 / D25 T2 seal the selector |
| V11 | final-norm overflow on a peaked row | an 8x multiplier refuses (the D20 class); refusal-free constants (`g0 Cn = 127 * 2^tn`) give at most 127, also at int16 extremes |
| V12 | a limb that is not a byte (same `delta` value); window arithmetic | rejected (A4); honest differences need 41 / 44 bits (TinyLlama / 8B, also with -128 weights), six limbs cover both with the soundness margin |
| V13 | overstated `M` with a non-maximal index, every `delta` in six bytes | rejected by A6; **accepted if A6 is removed** |
| V14 | `e` on a padded vocabulary entry (`tok = V = 300`), `M = max + 1` | rejected by pad-zero; **accepted without it** (would output a non-token) |
| V15 | `e`, `delta` honest; `tok' = j + 1` with `M = l_j + 2^-v (tok' - j)` | rejected by A3; **accepted without A3** (the naive form, `M` unchanged, is also caught by A5) |
| V16 | the N-1 forgery: `tok_0 = BOS + 1`, `h_q(0) = 0`, row 0 arbitrary | helper-level model: **accepted unweighted (v2 text), rejected with `mu_bos`**; the ideal identity check rejects it only through its separate BOS test |
| V17 | `tok_0 != BOS`, helpers honest for that sequence | rejected by the query zero-check at `t = 0` in both weightings |
| V18 | final norm over F_p: honest; `y` off by one; `D` off by one; the D16 alias; `y` up to 532 with in-window remainders; `x = 40000` (integer relations otherwise hold) | honest accepted; rejected by the remainder window; `D` limbs; `D` limbs; `sym`; `x` int16 window |
| V19 | position selector `s = (2, -1)` summing to 1 | the selection relation alone accepts; SBOOL booleanity rejects |
| V20 | sealed right (`s = e_{P-1}`), stage OUT uses `e_0` | owner check passes; **IO-s rejects** |
| V21 | consistent re-lookup in `A_in` under the honest seal | stage IN's lookup accepts; **IO-in rejects** |
| V22 | output plane seals another id; the owner is told that id | owner check passes; **IO-out rejects** |
| V23 | nonzero pad word in the token half | IO-in rejects (support factor); the owner check rejects too |
| V24 | BOS constants and their class | 1 (V 32,000) and 128000 (V 128,256) in class; 128000 outside a 32,000-entry vocabulary |

* `test_token_io_ref.py` — 20 tests (13 from v2, 7 added in v3), all passing in
  under a second; the v3 tests pin V13–V24, the honest vectors' IO relations, and
  a property test of the helper-level model on random sequences (honest accepted;
  the N-1 forgery accepted unweighted and rejected with fresh coefficients; a
  nonzero helper on a lifted pad position rejected). The v2 tests: the vectors regenerate
  identically and meet their expected outcomes; a randomised exhaustive test over
  every candidate index (extremes at the 8B logit bound, forced ties, near ties,
  all equal; over 500 index trials) accepts a witness exactly at numpy's first
  maximum; `first_argmax` equals `numpy.argmax` with ties; any single-word change
  of an embedded row is caught; the owner check binds salt, plane and length; and
  `final_norm` equals the calibration tool's `tlcalib.i_norm` with a uniform gain
  on random and extreme int16 rows at width 2048 (at least 10 rows compared,
  window identical: 32 bits).

**Head definition.** R0 takes `(g0, Cn, tn, Ceps, W')` as parameters; the
fidelity lane's `s4_head.py` fixes them as g0 = 127, the export's `tn` and
`Ceps`, `Cn` from `norm_site` with `c = 1` (margin 1.5) and the refusal-free
`Cn = 2^tn` beside it, `W'` per-tensor `qw` — the same definition. Its REPORT.md
(the agreement numbers that decide D25 T4 and C-7) had not landed when R0 was
written.

**Limits.** R0 checks the relations entry by entry in the base field; the native
stages prove them with F_p^2 challenges and sum-checks at random points. The
endpoint commitment is a salted-SHA-256 stand-in, not the PCS. The stack is a
causal stand-in; the real blocks are proved elsewhere. Nothing here is a proof,
a measurement or a privacy claim.

---

## 7. Rulings

### 7.1 Ruled by Victor: D25 T1–T8 (2026-10-17 19:28 UTC)

Victor accepted all eight product recommendations ("all recommendations yes",
Claude console; recorded as **D25** in `docs/zkmatrix-poc/ZK60_DECISIONS.md`),
together with **D23** (endpoint roots never registered, republished or referred
to) and **D19b** (the tag's random-function model). Nothing is built yet; D25 is
not a privacy acceptance.

| design item | ruling | what it fixes in this design |
|---|---|---|
| R1 output mode | **D25 T1** | mode (i) — one hidden next token per run — first; mode (ii) later |
| R2 prompt length | **D25 T2** | the prompt length stays hidden in mode (i) **and is sealed inside the input endpoint** so the owner can check it (C-2, check B-2); this needs the security owner's R9 (section 8) before the hidden-length variant is built; until then only the public-row variant may be built |
| R3 tie rule | **D25 T3** | lowest token id among equal maxima (numpy first maximum) |
| R4 integer head | **D25 T4** | accepted if its token equals the float head's on >= 99 % of held-out positions on the same stack output, otherwise per-row head scales; the same threshold decides C-7 (refusal-free final-norm constants if they meet it) |
| R5 owner hand-off | **D25 T5**, with **D23** and **D19b** accepted | the prover hands each owner the token and the endpoint decommitment (rows, pads, salts) privately; roots never chained or registered |
| R6 several tokens | **D25 T6** | repeated one-token runs are not a proved token stream, and every claim says so |
| R7 model identity | **D25 T7** | the receipt names the embedding and head by export digest, not proved to come from the checkpoint |
| R8 BOS | **D25 T8** | the proof forces the profile's BOS id at position 0: a clause `mu_bos [t = 0] (tok - BOS)` in stage IN's query zero-check **with its own fresh coefficient** (v3, CHECK2 N-1), `BOS` a per-profile statement constant in `[0, V)` (1 TinyLlama, 128000 Llama-3-8B; N-2); nothing leaks |

### 7.2 Security-owner items: both settled

* **R9 — the two-site input endpoint geometry: ruled as D26** (2026-10-17 19:50
  UTC, security owner): variant P adopted, F the recorded fallback, C not adopted;
  the second check's conditions C-a to C-e bind (section 8). Not a privacy
  acceptance; the G-6 / G-7 joint-view gate is owed before any figure from a
  hidden-length or mode-(ii) receipt is quoted.
* **R10 — per-opening counting convention: answered by the D15 correction**
  (19:40 UTC): the register now counts every private-block commitment at the
  ZK code's real distance `1 - (n + 256)/(n inv_rate)` and the masks at 2^-106.25,
  which is exactly what this design asked for; no separate ruling is needed. The
  design keeps its own floor (every token-I/O opening at least 2^-103, met at
  row width 2^12). The whole-proof target itself stays Victor's question G.0-2.

---

## 8. The two-site input token endpoint (R9) — ruled as D26

**Ruling (security owner, 2026-10-17 19:50 UTC, D26 in `ZK60_DECISIONS.md`):**
variant **P adopted**; **F** (the selector in the output endpoint, one site) the
recorded fallback; **C** (an in-circuit length) not adopted; the second check's
conditions **C-a to C-e bind** (section 8.7); design fixes N-1, N-2 and N-3 are part
of building to this rule (sections 2.3, 3.1). Construction rule only, not a
privacy acceptance. The proposal as it was put follows (8.1–8.6), then the
binding conditions (8.7).

**Question.** May the run's external *input* token endpoint carry two claim
sites, in two different stages, with the internal-boundary geometry
`rows = data + 2*sites + 2` (ruling M-1) instead of M-7's one-site `data + 5`,
opened exactly once at the end of the run? Scope: the token-I/O run profiles only;
every existing profile and the D22 toy keep their bytes.

**Why it is needed.** D25 T2 hides the prompt length and seals it under the input
root. The check's finding F-1 showed that an unsealed position selector lets a
cheating prover answer after any prefix (even BOS alone) with a receipt that
verifies. Sealing the selector `s` (one-hot over positions, `s = e_{P-1}`) where
the input owner checks it closes that: the receipt then means "the greedy token
after exactly the prefix of length `P` sealed in the input root". Mode (ii) needs
the same geometry for its SHIFT claim on the input tokens.

### 8.1 The variants

| | P — preferred | F — fallback | C — in-circuit (not proposed) |
|---|---|---|---|
| where `s` lives | half 1 of the input token endpoint (half 0 = `tok`) | the output token endpoint's plane, beside the token | nowhere sealed: derived in stage IN from a reserved pad id with monotone validity bits |
| claim sites on the input endpoint | 2: stage IN's IO-in (half 0), stage OUT's IO-s (half 1) | 1 (M-7 unchanged) | 1 |
| new geometry | yes (this ruling) | none | a third prover-generated boundary from stage IN to stage OUT (D12a, 2 sites) |
| who checks the length | the input owner, with the prompt | the output owner, with the answer | nobody needs to: proved |
| extra relations | IO-s equality slot | IO-out reads `tok` and `s` | validity bits, monotonicity (a shift), the extra boundary |

P is recommended: the length belongs to the input, the input owner already checks
the input root, and the geometry is the one boundaries already use. F needs no
ruling but attests the length through the *output* owner; if prompt and answer
owners differ, the input owner cannot check it. C moves no geometry but adds the
most new relations; it is recorded only.

### 8.2 Geometry (variant P) [COUNTED]

Row width 2^8, rate 1/8 (B-1). The plane is two halves of `L_half = max(128, T_pad)`
words: half 0 = `tok` (pad-zero beyond `T`), half 1 = `s` (pad-zero beyond `T`).
Rows = `ceil(2 L_half / 256) + 2*2 + 2`.

| T | plane words | data rows | rows (P, two sites) | rows (public row, one site, today's M-7 form) |
|---:|---:|---:|---:|---:|
| 32 | 256 | 1 | 7 | 6 |
| 128 | 256 | 1 | 7 | 6 |
| 512 | 1,024 | 4 | 10 | 7 |

Mode (ii) uses the same rule with `tok` alone (plane `max(256, T_pad)`; 7 rows at
T32, 8 at T512).

**Schedule.** The root is absorbed in the run header (expected-IO) as today. Stage
IN's IO-in claims half 0 at `(0, rho)` — the half bit a public fixed coordinate —
with reserved pair 0; stage OUT's IO-s claims half 1 at `(1, rho')` with reserved
pair 1. No block claims the endpoint. It is opened once, after stage OUT's own
openings and `B_out`'s, with both claims in that one opening (exactly how a
boundary's two claims are opened today).

### 8.3 Privacy accounting (variant P)

* **One commitment, one opening, two sites with their own reserved pairs**: M-1's
  rank count applies unchanged — `2(G + 1)` real dimensions (two sites' terminals
  plus the proximity vector) against `2*sites + 2 = 6` free base-field mask
  coordinates per column. The single-opening rule (two openings of 256 columns
  would recover a 512-coefficient row, D11) is kept.
* **External, not internal.** Unlike `B_in` / `B_out` its root is public (in the
  statement) and its owner later receives the decommitment (D25 T5). Under D18 (the
  prover seals at proof time) and D23 (accepted: the root is never referred to by a
  later artifact) the standard game applies, as for today's one-site endpoints.
* **Deferred opening.** The commitment stays unopened while the `L` blocks run;
  nothing between its two claims touches it. The opening's column queries are
  drawn from the transcript at the end of the run; a refused run never opens it and
  publishes nothing (D21, D12b(1)).
* **Fixed public half bit.** At `T <= 128` the plane is one 256-word row and the
  half bit is the top column bit: the eq weight zeroes half of each reserved
  pair's columns and the other half stay fresh and uniform (the check's argument
  for `B_out`'s public row bits, G-2). At T512 the half bit is a row bit and only
  selects data rows; the terminal is masked by the reserved pair as usual. Both
  geometries go through the G-6 / G-7 joint-view gate on captured receipts.
* **Owner decommitment.** The input owner receives rows, pads and salts and can
  unmask both terminals (IO-in and IO-s); both are functions of `tok` and `s`, its
  own data. The privacy statement must say the owner is outside the adversary for
  its own endpoint (as D25 T5 already implies).
* **Pad words.** Each IO slot runs over its whole half with the public `supp_T`
  factor, so all pad words of both halves are bound to zero; together the two
  slots cover the whole plane (D17 rule 1, jointly).

### 8.4 Soundness accounting (variant P)

* **Per opening** 2^-106.25 (2^8, rate 1/8), the same as the one-site endpoint, and
  still one opening: the whole-proof commitment term is the same as the public
  row's — 2^-98.04 (8B T32) / 2^-97.46 (TinyLlama T32) under the register's D15
  accounting (§4.4; v2 quoted 2^-98.47 / 2^-98.93 under the old convention)
  [COUNTED].
* **Binding of `s`.** IO-s is an equality sum-check over half 1 at a point drawn
  after the endpoint root (header) and `A_out`: Schwartz–Zippel
  `log2(L_half) / |F_p^2|` (about 2^-125). Booleanity and `sum s = 1` in stage OUT
  make `s` one-hot; the selection slot makes stage OUT's row the selected row of
  `B_out`. That `s` equals `e_{P-1}` for the owner's real `P` is checked by the
  owner (the verifier cannot know `P`, by design).
* **F-1 closed.** A prover choosing another row must seal that `s` under the input
  root; the input owner's check rejects it.
* **Pad tokens** at positions `>= P` are any real ids, also sealed and checked by
  the owner; positions `< P` do not depend on them (causal mask, proved by the
  blocks; the fidelity lane's F4 control confirmed it on the integer stack).

### 8.5 Cost (variant P vs the public row) [COUNTED / MODEL]

8B T32: +0.029 M committed elements (one `s` plane; SEL, SBOOL and IO-s replace
IO-in, so net +3 sites on `A_out` — v3, CHECK2 N-7 — and +2 slots), +0.08 s laptop [MODEL], +30 KB receipt, +1 endpoint row; whole-proof
term unchanged. TinyLlama: the same within rounding.

### 8.6 What the ruling says (D26, as proposed and adopted)

1. The token-I/O run profiles' input endpoint uses the derived geometry
   `data + 2*sites + 2` with `sites = 2`, row width 2^8, rate 1/8, one opening at the
   end of the run (after stage OUT and `B_out`); any other row count is refused by
   name (M-1 applied to an external endpoint).
2. Claims at a public fixed half bit are admitted, subject to the G-6 / G-7 gate.
3. Variant P is the hidden-length construction; F stays the recorded fallback; C
   is not adopted.
4. Not a privacy acceptance; the joint-view gate on a captured receipt (D17 rule
   3) is owed before any number from it is quoted.

### 8.7 Binding conditions C-a to C-e (CHECK2 §3.2) and how the design meets them

| condition | what it requires | where the design meets it |
|---|---|---|
| **C-a** variant bound in the run statement | the parameter and stage lines name the input endpoint's geometry ("sites 2, rows `data + 6`, row width 2^8, rate 1/8, opened after stage OUT and `B_out`") and the selector variant (public row / P / F); the verifier reads them from its own statement, never from a segment; the three variants are distinct run profiles (D17), so a receipt cannot be re-read under another | §4.1 D17 bullet and the calibration-identity list (now also the selector variant and the BOS constant); R1 control 22 |
| **C-b** deferred single opening enforced | the run verifier carries stage IN's claim across all stages (as `pending` / `finish` do for a boundary) and refuses an opening anywhere but the declared place, or with fewer or more than two claims; the prover consumes the endpoint owner by value | §8.2 schedule; R1 control 20 |
| **C-c** its own spec type | not `EndpointSpecG` (whose digest fixes 5 mask rows and two slot indices): a boundary-like spec with its own digest domain string (e.g. `hashline/private-block/two-site-endpoint/v1`) and the input role byte in its seed domain; the constructor derives `data + 2*sites + 2` and refuses any other row count by name | §8.2; R1 control 21 |
| **C-d** owner check at the derived geometry | re-encode at row width 2^8, rate 1/8, the derived row count (7 or 10); check the root, `tok_0` = the profile's BOS, the prompt, pad ids, zero pad words in both halves, `s = e_{P-1}`; refuse a decommitment of any other shape | §3.4; R0 `owner_check_input` (BOS check added, V02 / V10 / V20 / V23) |
| **C-e** G-6 / G-7 gate | a joint-view analysis on captured receipts at both geometries (T <= 128, column half bit; T512, row half bit) before any number is quoted (D17 rule 3) | §4.2 G-6, G-7 |

---

## Appendix: files and reproduction

* `token_io_count.py` (v2) — the counter (imports the unchanged copies `layout.py`,
  `cost_model.py` from `results/zk60_speed_plan_20261017/`); writes
  `token_io_count.json`. v1: `token_io_count_v1.py`, `token_io_count_v1.json`.
* `check/` — the two adversarial passes (another lane's; read-only here):
  `CHECK.md` + `check_arith.py`, `CHECK2.md` + `check2_probes.py`.
* `r0/` — rung R0's reference, its 24 test vectors and 20 tests (section 6.4).
* Soundness accounting: `results/zk60_soundness_recount_20261017/RECOUNT.md` (the
  D15 correction of 19:40 UTC).
* Read-only sources used: `ops/zkp-mvp/trained-1b/hashline/src/private_block/`
  (`layout.rs`, `argument.rs`, `protocol.rs`, `run.rs`, `boundary.rs`,
  `endpoint_g.rs`, `shape.rs`), `results/zk60_1b_calibration_20260929/`
  (`export/TOKEN_IO_SPEC.md`, `tlcalib.py`), `private-model-kernel/src/lib.rs`,
  `results/zk60_token_io_fidelity_20261017/tools/s4_head.py`,
  `docs/zkmatrix-poc/ZK60_DECISIONS.md`, `ZK60_PRIVACY_REQUIREMENTS.md`,
  `ZK60_THROUGHPUT_TARGET.md`, `ZK60_TOKEN_MODEL_SOURCE_REVIEW.md`.
* Literature: LogUp, Haböck, ePrint 2022/1530; Plookup, Gabizon and Williamson,
  ePrint 2020/315; Lasso, Setty, Thaler and Wahby, ePrint 2023/1216; Twist and
  Shout, Setty, Thaler and Zhu, ePrint 2025/105 (CRYPTO 2026); zkLLM, Sun, Li and
  Zhang, CCS 2024, arXiv 2404.16109.
* Modelling caveats: stage counts follow the plane / site / slot lists above, not
  code; column-weight group counts in the receipt estimate are approximations
  (a few KB); the cost model's fixed 0.08 s per zero-check slot dominates the small
  stages and is likely high for them; the verifier's per-entry fold cost is
  assumed equal for int16 and int8 tables.
