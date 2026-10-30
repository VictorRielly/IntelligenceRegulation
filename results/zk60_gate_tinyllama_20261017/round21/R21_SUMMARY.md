# Gate round 21: the Shieldstral classifier privacy statement DRAFT, and the gate's last evidence items

Privacy gate lane, 2026-10-29 21:37–22:5x UTC. **This is NOT a privacy acceptance.** Labels: [MEASURED] a run happened
(laptop, shared box, n = 1); [COUNTED] exact arithmetic; [READ] read from a record or the code.

## 1. Result in plain words

* **The draft exists:** `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT.md` (DRAFT v1,
  sha256 `db89f427…` at this summary). It follows D33 / D36: plain words first, scope, the proposed sentence, steps 1–5,
  residuals with the arithmetic, conditions, operating rules, findings, what must not be claimed, lapse list, owed list,
  evidence index. **Marked DRAFT, not accepted**; next is an independent privacy review, then the security owner, then
  Victor. The policy list is a parameter, evaluated at the registered moderate three, pending Victor's strict /
  moderate ruling.
* **The proposed sentence:** for an accepted run, the verifier's view is within about **2^-68.19 per run** of a
  distribution computed from the public facts alone (verdict bit, policy, n and the chunk facts, model, profiles).
  It also says plainly that **whether an item gets a proof at all depends on its hidden content** (shown by the app as
  "could not be verified", D45(4)), and that at n = 1 the verdict is a function of one hidden id among 130,072.
* **The 15 block tables per stage are no longer taken on trust** [MEASURED]: the gate derived all **442 arrays**
  (17 per block × 26 blocks, 118,210,560 entries) from Astra's T128 export with its own exact arithmetic and found
  **every one equal to the hate-values capture, by SHA-256 and byte for byte**. G_k equals every stage line; the SiLU
  tables match four independent sources; 8 / 8 non-vacuity controls fire.
* **Per-run distance** [COUNTED]: 235,660,902 draws × 2^-96 = 2^-68.19, plus the refusal term 2^-108.25 and smaller
  terms; total **2^-68.19**. The draw count is from the geometry, not confirmed by a replay (owed).
* **Owner checks** [READ]: recorded gate-side for the hate run (token round 16) and the gate's round-19 re-prove; both
  pass. **No owner record exists at n ≠ 35** (round 19's short items have no decommitment on disk); Astra's 17-id post
  will be the first.

## 2. The table derivation (task 1)

`round21/derive_block_tables.py` (sha256 `7eb5917e…`): no token-lane code imported or run. Per block stage:

* the export pinned (each array's SHA-256 against its layer manifest, each manifest against `profile.json`, and
  `profile.json` = the run's `2ba468f9…`);
* the R13 public data rebuilt: group folds c_j = m_j 2^(G − s_j), G_k = max(s_j, 17), scaled SiLU words, the
  registry checks;
* the 17 arrays: fold(w_q / w_k / w_v / w_o) (rows axis, head map), fold(w_g / w_u / w_d) (columns axis), gamma_a /
  gamma_m on Dom::D, RoPE cos / sin on Dom::Q and Dom::Kv, the group column on Dom::F, exp, ACT3 and its support on
  Dom::Tab; folds by 16-bit limbs in float64 (every partial sum an integer < 2^37), reduced mod p;
* compared by SHA-256 and byte for byte (pread of `arrays.bin` at the recorded offset; no mmap, so the store is page
  cache, not RSS: O20-1).

| | result [MEASURED] |
|---|---|
| Development run, stage 1 (`dev/dev_b1.json`, `b2c92067…`) | 17 / 17, controls 8 / 8; guarded light 1.0 / 1.5, 5 s, peak 0.31 GiB |
| **All 26 blocks** (`derive/DERIVE_ALL.json`, `5c2c7111…`) | **442 / 442 equal**; store, stage files and run.json re-hashed equal to the manifest; G_k = the stage line in 26 / 26; guarded cpu 0.5 / 1.0, 22.9 s, peak 0.29 GiB, 22:45:14–22:45:37 UTC |
| SiLU (ACT3) | 7 distinct members incl. the Shieldstral (0, −8); each export table = float64 definition = Sol's formula (transcribed; his script writes into his tree, so it was read, not run) = exact 60-digit Decimal = the native `r13_vectors/silu_*.bin`; closest approach to a rounding tie 1.0e-5 |
| exp | e_s 1, 2, 3, 4, 6 at f_e 9: export = `exp_table_generate` in float64 and exactly |
| Controls C21-1..8 | a w_q weight, a q multiplier, a gate coefficient, slot 6's point for fold(w_v), the sin sign, one SiLU word, G_k + 1, layer 1's export for stage 1: each breaks exactly the tables it touches |

**Order with Astra:** the chain waited for Astra's first real app post (labels `pm-classify-*`). Astra started nothing
after 21:33 UTC, so the job ran at the idle deadline 22:45 UTC, alone, for 23 s.

## 3. The per-run distance (task 2) [COUNTED]

`round21/classify_run_counts.py` (`87492320…`) → `CLASSIFY_RUN_COUNTS.json` (`513c376d…`).

* Draws = IN-C 110,192 + 26 × 8,932,968 (A 5,988,608 + H 2,926,078 + M 18,282) + OUT-C 373,862 + 27 boundaries ×
  108,032 + the input endpoint 2,816 = **235,660,902** (≈ 2^27.81).
* Sampler bias 235,660,902 × 2^-96 = **2^-68.19**. Refusal 879,360 / p² = **2^-108.25**. Salt guessing (N_leaf
  5,359,616) 2^-105.65. Transcript pre-query ≤ 2^-108.0 (A bounded by 2^20, not measured). The rest < 2^-125.
* **Total 2^-68.19 per run** (10^6 runs 2^-48.26; a short post under three categories ≈ 2^-66.6).
* Controls: K-0 the same function reproduces D36's L22 2^-70.35 from round 9's geometry; K-1 every boundary draws
  108,032.

## 4. Owner checks (task 3) [READ]

`round21/owner_record.py` (`46d810b1…`) → `owner/OWNER_RECORD.json` (`09b824df…`). Read only (brief: "read, don't
re-prove"; a re-run would stream the 7.7 GB checkpoint). Nothing private read.

* Hate run: `input-owner` (token round 16), exit 0, content-checked, content_total 35, range [0, 35), against root
  `4cf9e8ae…` = the hate-values capture's root. PASS.
* The gate's round-19 re-prove: the named r16b binary (re-hashed `dfb8025e…`), the same facts. PASS.
* Short items at n ≠ 35: not possible on round 19's captures (the H19-1 hook drops the decommitment; no run dir).
  Astra's 17-id post: not run yet. **Owed.**

## 5. What is still owed (from the draft's §10)

1. An independent privacy review round on the draft (the [MINE] extensions; the refusal-channel wording).
2. The stage-47 root-rebuild replay (draws confirmed by value) at the classifier stages and R13 blocks.
3. NL-1 S3–S5 and the terminal surjection on the 12 classifier slots and the 7 R13-redefined block slots.
4. The C-R1 / C-R2 hash-input census for the classifier absorbs.
5. An owner check at n ≠ 35 (Astra's post), and the delivery of the opening (not built).
6. Victor's strict / moderate ruling (and a re-capture under a strict list).
7. The independent check of token rounds 16b / 17; N20-1.
8. The security owner's decision and Victor's acceptance.

## 6. Notes

* **N21-1 (Sol's `reference_silu.py`):** it writes its vectors into Sol's working tree and covers only the nine
  standard members (not (0, −8)). The gate transcribed its formula instead of running it. The native tree's own
  `r13_vectors/silu_0_-8.bin` covers the tenth member.
* **N21-2 (operations):** the derivation is light (0.3 GiB, 23 s, one thread), not the heavy job the brief expected. It
  was still run as one guarded cpu job, alone, after the Astra wait.
* No checkpoint stream, no prove and no verify in this round. No job of this lane is pending.
