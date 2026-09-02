# TASK BOARD — the standing queue of small, self-checking tasks

Status: LIVE (opened 2026-08-17). Companion to CONTINUATION.md (the
phase plan) and PROGRESS_UPERF.md (the ledger). This page exists so
that ANY agent — Claude, Grok/Cursor, a human — can advance the
prove/verify clocks without reopening design. Every task below names
its files, its exact commands, and a byte-identity acceptance. If a
task's acceptance fails, revert the task's code and record the failure
here; do not "fix forward" into the transcript.

If you are Grok/Cursor: read Section 0, then start at Section 3, take
the first task in the ORDER Section 0 names, and follow it literally.

## 0. HANDOFF STATE (the orchestrator keeps this current at every push)

WHY THIS SECTION: Victor's Claude usage can run out MID-TRANCHE. When
that happens the repository must be continuable by Grok alone. This
block is the always-current answer to "what is going on and what do I
do". If the AS-OF date below is stale by more than a day, trust the
ledger's newest Agent-status sections over this block.

**AS OF 2026-09-02 late (ROUND 10 CLOSED, ROUND 11 OPENED; three
rulings; the Mac runbook unchanged):**
- **ROUND 10 CLOSED**: all four lanes merged at 0dc31f7, floors green
  on the CPU and GPU binaries. Net: no lever measured makes the
  lattice proof faster than today's pass at 125M (QQ: the two-tier
  opening with preprocessed weights at PARITY, bar 5x; RR: Stage A on
  the GPU at parity only with the batched transport); the wins are
  bytes (2.15-2.25x) and memory (7.5 -> 3.1 GB at 12x128; the first
  Stage-A 12x512 run that fits the laptop, 11.2 GB); the tokens/s
  model puts the lattice line at 2-15 tok/s for 30B prefill on one
  H100 at best. Details in the four lane bullets below.
- **RULINGS (Victor, console 2026-09-02: "Let's do 1) and 2) go ahead
  and work on variant B as well as a separate attempt")**: the
  hash-based comparison prototype STARTS NOW; the kappa-4 helper is
  the full-mode encoding; the batched claim transport is the Stage-A
  transcript form; Variant B is built as a separate attempt. The
  ledger's RULINGS block (2026-09-02) records the reading and its
  revert condition.
- **LANE UU LANDED THE SAME DAY (merged 0f51720; `hashline/` builds
  here in 13 s, 19/19 unit tests).** THE COMPARISON ROW [MEASURED,
  WSL-BOX 8T CPU-ONLY NOISY-SHARED]: the hash-based prototype proves
  the IDENTICAL 12x512 exact-int8 statement (48/48 tensor sha256s and
  12/12 layer z digests reproduced) in **23.0 s p50 prove (21.5-23.7
  over 4 runs, incl. all commitments) + 2.8 s verify, 66.8 MB proof,
  1.56 GB peak RSS, 1.26e9 proven MAC/s**; seven tamper legs reject.
  Vs the lattice line: PARITY with its GPU-assisted 21.0 s, 3.5x
  under its CPU-only 81.5 s, 4.3x less memory, 44x larger proofs,
  slower verify (2.8 vs 1.7 s), NOT zero-knowledge, hash-only
  ~100-bit (Goldilocks + deg-2 ext; RS rate 1/4, 256 column checks;
  blake3). Phase shares at 8T: commitments 47%, zero-check sumchecks
  30%, PCS openings 17%, matmul sumchecks 6% — all GPU-native work;
  UU's estimate for the RTX 4070 port: ~1.5-2.5 s per pass [MODEL].
  Thread scaling INVERTED beyond 8T on the hybrid part (22T 37-39 s).
  Record: results/hashline_pass_12x512.md; PROVING_CHANNEL_OPTIONS.md
  §2 status + §3 row. FOLLOW-ON LANES OPENED: **XX** = hashline on the
  GPU (proofs byte-identical CPU vs GPU; the measured wall); **YY** =
  the Route-B throughput model (lane TT's seven items for the hash
  line, incl. the ZK surcharge — Victor's ZK rule is non-negotiable —
  and the proof-size lever).
- **LANE ZZ LANDED (merged; `U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md`,
  1,132 lines, docs only) — THE PRIVATE-WEIGHTS ANSWER FOR ROUTE B.**
  Three ways, one keeps 50 tok/s at 30B reachable: **option 2, never
  send the sampled weight columns** — the weight tree committed ONCE
  per model under an arithmetic hash (Poseidon2; 2-18 min on a GPU
  at 30B, off the clock), and per proof the verifier's column check
  (256 columns x 2,648 rows x 3 inner products + hashes + Merkle
  paths: 5.9e6 Poseidon2 permutations, ~4.4e9 native multiplies at
  30B [COUNTED]) proven inside a fresh ZK GKR/sumcheck proof with
  masked clear vectors. Per-proof surcharge on one H100 50-180 ms
  at the floor, 0.16-3.6 s scaled [MODEL] vs a 3.7-62 s P0 prefill
  proof -> its 30B prefill cells are P0's own (46-137 floor / 7.8-58
  scaled tok/s); reaches 50 under exactly P0's conditions (batched
  or 512-token prefill, upper half of the hardware range, >= ~50
  GB/s device hash rate). Hinges on: the inner ZK prover's overhead
  over native (5-20x, the one uncounted constant), and a WRITTEN
  simulator — the published Orion was found unsound [EXTERNAL,
  ePrint 2024/1164]. Option 1 (re-commit per proof) reaches 50 only
  with >= 16 stacked prefills per proof + a token-streaming
  commitment (258 GB working set). Option 3 (the lattice hybrid) is
  the AUDIT channel, not a throughput route: the lattice weight
  opening is 100-1,000x the hash line's on the same board, and the
  cross-commitment bridge (a Goldilocks-extension claim opened from
  the q31 commitment) has no recorded design — the cheapest honest
  bridge forces a >= 46-bit weight modulus. No fourth way found.
  Batch-1 decode: unreachable for every option. Corrections to YY:
  the recovery horizon is 257/513 proofs at the 8B/30B optimum
  (65 was the 125M set); only W needs the inner proof, not A/H.
  SPIKE LIST with sizes (§7): Z-1 the hashline ZK form (1 lane-day,
  needed under ANY privacy mode); O2-1 Poseidon2 + the W tree behind
  a switch (2-3 d); O2-2 the inner statement + ZK GKR at 12x512 with
  the outer verifier accepting with W columns absent, K_ov measured
  (3-5 d); O2-3 the simulator/extractor (1 d, docs); O2-4 device port
  (an XX rung). **FOR THE RULING: P1 (private inputs) costs 2-8% and
  needs none of this; P2/P3 (private weights) costs option 2's ~two
  lane-weeks to a first measured row.**
- **LANE VV LANDED (merged a630f25; `results/uperf3_vv_variant_b.md`).
  VARIANT B AT THE BAR: NOT MET — 1.77x [MEASURED]** (real 12x512
  weight group, RTX 4070, 8T, per-model part warm, n=5: 1.24 s min /
  1.29 median per proof vs the built opening's 2.20-2.23 s in the
  same run; 2.31x if the built precommit is charged; claims
  byte-identical, wire digest identical x5). Better than QQ's design
  of record (parity) but the floor is the ~200K-ring recursion prove
  (0.39-0.52 s, frozen machinery) + the launch-bound value-fold GEMM
  + the v-pass — the recursion alone exceeds the 0.44 s a 5x bar
  allows at this shape. 8B/30B rows [MODEL on measured constants]:
  14-48 s / 54-201 s per proof = 4.4-15x / 4.6-18x — STRADDLING the
  bar; settleable only by an 8B-shape run (Mac or a desktop board).
  Gates green: +3.45 / +1.74 / +1.42 bits at 12x512 / 8B / 30B
  (QQ's count reproduced). SOUNDNESS (rung 1, before code): not a new
  lemma — the same exact-digit fold-norm law at base 8 (a value ring
  is one balanced digit), 8x fewer MSIS columns — but a NEW PROTOCOL
  OBLIGATION: the int8 range of the value tier must live in a
  per-model certificate (digit planes + recomposition claims + a
  second opening of the value-tier commitment) or a per-proof 256-row
  lookup; neither built. Two attribution fixes landed (QQ's clock
  carried 0.3-0.5 s of differential bookkeeping; the fold's "host
  tail" was a serial challenge draw, now pooled 0.37 -> 0.08 s).
  RULING ITEMS: the int8-value class row; the per-model weight
  certificate form; the pooled draw as a prover-side form. FOR THE
  THROUGHPUT MODEL: the lattice line's 30B band is unchanged.
- **LANE YY LANDED (merged 3c4dc8a): `U_PERF3_ROUTE_B_THROUGHPUT.md`
  — the hash line's tokens/s model on lane TT's yardstick.** From
  UU's measured row and the crate's loops: per-model 2.19 s (the W
  commit), per-proof weight side 1.52 s (linear, 4.33 mult-adds per
  weight), activation side 19.2 s (84%) at 12x512; scaled: 8B x 512 =
  492 s on the laptop CPU (1.0 tok/s), 30B x 512 = 1,546 s (0.33)
  [MODEL from MEASURED]; hardware factor for this device-native mix
  laptop GPU 5-15x [MODEL until XX], 4090 15-75x, H100 25-180x. **THE
  VERDICT: 50 tok/s at 30B on one H100 is reachable on Route B ONLY
  for prefill / batched proving (B >= 4-16), FFN-only, in modes P0/P1
  (weights public), in the upper half of the hardware range (>= ~90x
  over the CPU row; sustained device hash rate >= ~50 GB/s) — it
  hinges on lane XX's two numbers. Batch-1 decode at 50 tok/s: not
  reachable under any counted assumption (the linear weight opening
  alone is 25-60 ms per proof at 30B vs the 20 ms budget). Under
  P2/P3 (weights private) NO counted cell reaches 50.** THE
  STRUCTURAL FINDING (§4.4): a cached hash-based weight commitment
  leaks 256 encoded columns per proof — the weights are recoverable
  after ~65 proofs — so P2/P3 need a fresh W commitment per proof
  (+44% at 8B x 512, +54% at 30B; 7-23 s of hashing per proof on an
  H100), unless an UNCOUNTED design lands: Orion-class hidden-column
  openings (an inner proof of ~1e9 constraints per proof at 30B) or a
  lattice-hybrid weight commitment (the lattice channel's hiding
  commitment for W, the hash channel for the activations, a ZK
  cross-commitment link). ZK for the activations (P1) is cheap:
  +2-8% prover. Proof size: the sqrt class is 613 MB / 1.5 GB per
  8B/30B proof; a WHIR/STIR-class PCS swap gives 3-12 MB at x0.94-1.4
  prover — mandatory before any decode artifact. **RULING FOR
  VICTOR: which privacy mode is the product?** P1 (open weights,
  private inputs — the natural mode for open-weight models such as
  the Mistral/Gemma checkpoints in hand) keeps Route B on the 50
  tok/s path; P2/P3 (proprietary weights) needs the weight-privacy
  design priced first (a docs-only lane, ZZ, opened for that).
- **ROUND 11 LANES** (PROGRESS_UPERF3.md, self-contained briefs):
  **UU** = the hash-based prototype ("Route B") as a NEW crate
  `hashline/` on the SAME 12x512 int8 statement — Goldilocks field,
  Ligero/Brakedown-class multilinear commitment, the matmul sumcheck,
  LogUp lookups; the deliverable is the MEASURED comparison row in
  PROVING_CHANNEL_OPTIONS.md §3 with tamper legs; **VV** = Variant B
  of the two-tier opening (tier-1 over int8 value rings; QQ counted
  8-15x at 8B) against the original >= 5x bar at the 12x512 weight
  group, soundness note first; **WW** = the Stage-A defaults
  (rulings 2-3), the cold-descent-kernels finding from leg C, the
  driver diet so 12x512 runs in both Stage-A modes on the laptop,
  and the honest 12x512 A/B.

**AS OF 2026-09-02 (ROUND 10 OPENED — the throughput round; the Mac
runbook is the Mac's queue):**
- **THE GOAL (Victor 2026-09-02)**: >= 50 proven tokens/s for a
  30B-class model on ONE GPU (H100-class allowed) — "the competition
  to beat" is the Attestable claim (53/77 tok/s, one H100, [EXTERNAL]).
  START_HERE.md §2 has the conversion; lane TT owns the honest model.
- **ROUND 10 LANES (PROGRESS_UPERF3.md, self-contained briefs)**:
  QQ = the two-tier opening + WEIGHT PREPROCESSING on the GPU cost
  model (count, build, measure; the reopen bar = per-proof
  weight-side opening >= 5x the built GPU path at the 12x512 weight
  group, claims bit-identical); RR = Stage A's aggregate on the
  device (measures the factor the 2026-08-30 board line guessed at
  1.2-1.5x — that line is UNSOURCED, see below); SS = committed-h
  V1-V4; TT = the tokens/s model + the audit of the unsourced line.
- **LANE TT LANDED (merged aae3478): `U_PERF3_THROUGHPUT_MODEL.md`
  — THE TOKENS/S MODEL, every number sourced.** The verdict, plain:
  the built system is a ~0.6-0.8 tok/s system at 8B prefill on the
  laptop and ~0.0025 tok/s at batch-1 decode (every proof re-proves
  the whole weight side) [MODEL from the one measured pass]; the
  recorded design path (Stage A + two-tier opening + weight
  preprocessing), at its OWN modelled constants, gives **2-15 tok/s
  at 30B prefill and 0.05-0.7 tok/s at 30B decode on one H100
  [MODEL on MODEL]**, 3-30x lower at the constants the spike
  measured. **Under no assumption recorded in this repository does
  the lattice line reach 50 tok/s at 30B on one GPU.** Batch-1
  decode is floored by reading the weight digits (13 of the 20 ms
  budget even packed and H100-resident); 512-token prefill makes the
  weight side irrelevant and turns the question into the
  activation-side proving rate: 1.6e12 MAC/s needed vs a best
  modelled 0.5-3.3e11 (U2, memo §7.4 — no lane measures it; it is
  the choice-D question). Round 11 is cut from QQ rung 4, RR rung 5
  and Mac M5 — not from any tokens/s number.
- **LANE RR LANDED (merged; the measured Stage-A-on-GPU factor —
  `results/uperf3_rr_stage_a_gpu.md`).** The aggregate zero-check
  prover on the device: 5.0-5.9 s -> 0.58 s (**8.6-10x**,
  bit-identical, agg-battery 46234986.. with the device forced on
  every aggregate). But the Stage-A prove WALL with lane GG's claim
  transport only moves 17.6-19.4 -> 13.4-13.5 s (**1.31-1.44x** —
  the number the retracted line guessed), and Stage A stays
  1.36-1.40x SLOWER than the built pass at 12x128, because the
  critical path is the act-group opening's per-contrib phases (~700
  rank-1 plane claims). With an opt-in BATCHED claim transport
  (`ZK_RR_ZC_CLAIMS=batched`; a Stage-A transcript variant, served
  values unchanged, the claim count 997 -> 439 — **RULING ITEM**):
  Stage-A prove == oracle prove (7.5 s, 1.00x), verify at parity,
  total 1.14x (the planes commit +1.6 s), and **peak RSS 7.5 -> 3.1
  GB** at 12x128. FOR THE THROUGHPUT MODEL: Stage A + GPU buys NO
  speed over the built pass at 125M — it buys bytes (2.15x) and
  memory; the opening is 70% of the prove wall (lane QQ's territory).
  Two device races found and fixed. **Leg C at 12x512 (batched, GPU)
  RAN AND FITS: commit 6.1 / prove 17.9 / verify 4.5 s, 670,891 B,
  accept, 11.2 GB process peak** — the first Stage-A run of the
  reference shape on this box; vs the frozen pass's Aug-18 QUIET row
  (prove 15.5 s) that is parity-class at 2.25x fewer bytes. (Its
  in-process oracle leg ran with cold descent kernels — not the
  reference; see the ledger.) Legs A/B are Mac-only (M1b). All round
  10 floors green on the merged tree, CPU and GPU binaries.
- **LANE QQ LANDED (merged 6b6ae1f; floors green on the merged tree:
  diff-battery 17.2 s, freeze-check 102 ok exit 0, 3752cba4.. /
  46234986.. / be89d5da.. unchanged, range 12x64 digest 44528c6a..
  unchanged). THE REOPEN BAR IS NOT MET — MEASURED 1.00x**: the
  two-tier opening with the weights PREPROCESSED (per-model part
  built once, 2.34 s, held warm) proves the real 12x512 weight group
  in 2.08 s per proof vs 2.09 s for the built GPU opening [WSL-BOX
  8T GPU NOISY-SHARED], claims byte-identical across 3 proofs. On
  the way: the redesign memo's C-R1 count was wrong AGAINST itself —
  the swap-order linear pass is ONE existing GEMM, so on 1 CPU
  thread the spike goes from 1.10x to 3.42x [MEASURED]; but on the
  GPU the built opening already runs that GEMM class, and the
  two-tier's own floors (a ~200K-ring recursion, a fold over 8x the
  value rings, a per-tensor host tail) add up to parity. Projection
  [MODEL from the measured constants K1-K8]: 8B weight side 62-75 s
  per proof vs ~210 s built (2.8-3.4x) on the 4070; a "Variant B"
  (tier-1 over int8 value rings, +1.74 bits at the gate) counts at
  14-27 s (8-15x) — a DESIGN CHANGE needing a ruling, not built.
  The per-proof weight lever is now the digit-ring FOLD (58-73%),
  not the linear pass. **For the 50 tok/s question this settles U1
  at the low band: the lattice line's 30B one-H100 prefill cell is
  the (c') class (~0.5-3 tok/s), not (c).** Weight preprocessing
  itself WORKS and is bit-identical (the per-model/per-proof
  boundary exists: `uperf-t repeat`).
- **LANE SS LANDED (merged 827e90b; floors green on the merged tree:
  diff-battery 16.4 s, freeze-check 102 ok exit 0, 3752cba4.. /
  46234986.. / be89d5da.. unchanged, range 12x64 digest 44528c6a..
  unchanged).** FINDING that corrects the committed-h memo: the
  full-mode "act-h group" is the S2 LogUp HELPER of the SiLU lookups
  (one helper per key, 2 digit rings each), not a range-fact
  commitment of h — so routing range facts through lookups (the
  memo's C2) costs 32x MORE, not less; C2 is retired. What works
  instead: a kappa-level partial-fraction helper (kappa 4 = degree
  18) that cuts the act-h group 16x — **12x128 full mode now runs at
  8,072 MiB (was OOM at 14,777), accept, bytes 860,867**; the 8B
  full-mode peak becomes ~78 GB on OO's 72 GB baseline (~87 GB until
  a claim-kernel diet lands) — the owed recount is CLOSED (the S2
  form would have been ~285 GB and six groups). **TWO RULINGS FOR
  VICTOR**: (1) adopt the kappa-4 helper as THE full-mode encoding
  for T17's freeze set (a Stage-A full-mode transcript change; the
  S2 form stays reachable as `full-s2`); (2) kappa 5+ needs a
  one-line denominator reduction in `sumcheck::lagrange_eval`
  (frozen file, i64 overflow above degree ~20) — not needed for
  kappa 4. **CAVEAT (orchestrator-run, later the same day): the
  Stage-A composed driver at 12x512 OOM-KILLS the 15 GB box in BOTH
  modes** — full 15.18 GB (8.3 GB after the helper commit, 12.2 GB
  after the aggregate checks, killed in the openings), range 14.4 GiB
  (lane GG projected exactly this on 2026-08-28 and deferred the
  shape; the diets since did not bring it under the box). So on the
  laptop the Stage-A reference shape is 12x128 (both modes accept
  there), RR's 12x512 A/B is Mac-only (MAC_RUNBOOK M1b, new — CPU
  numbers for both modes), the 8B full-mode figure (~78-87 GB) is a
  LOWER BOUND until M1b lands, and a Stage-A driver diet (the nrw-88
  zero-check transient ~5 GB, the claim tables, SS's claim kernels)
  is a named round-11 item. The frozen pass at 12x512 is unaffected
  (6.7 GB with the GPU).
- **RETRACTED (lane TT, memo §5.6)**: the 2026-08-30 "~25-35 tok/s
  amortized; levers 1.2-1.5x / 1.3x / 1.1-1.2x -> ~65" line below —
  none of its five numbers derives from anything recorded; the
  nearest recorded row is 13-26 tok/s of an 8B FFN-only model on one
  DESKTOP board [MODEL]; no pipelining or spine-amortization lever
  exists in any design. Weight preprocessing has never been built
  or measured (lane QQ rung 4 is its first measurement).
- **THE MAC QUEUE IS NOW `docs/zkmatrix-poc/MAC_RUNBOOK.md`** — the
  ordered, self-contained list (sync + gate pass, T1 with a thread
  ladder, T13/T14, T15, T16 with the T-scaling leg that measures the
  weight-vs-activation split, T17 both forms). Victor pulls and runs;
  results are pasted back per the runbook's RECORD lines.

**AS OF 2026-09-01 (ROUND 9 MERGED; the speed question put to Victor;
START_HERE.md written):**
- **NEW: `docs/zkmatrix-poc/START_HERE.md`** — the plain-words
  onboarding page (what is built, the measured numbers, why the
  5-15 s goal is hard, what was tried, the five choices A-E, the
  working rules, the map, a glossary). Anyone new reads it FIRST.
- **PP/X2 MERGED (8e2060d)**: the 125M attention calibration table
  (`results/m125_attn_at_o1.json`): core int8-clean without QK-norm,
  ONE poisoned site (xres, rescued by int16), ONE exp member for the
  whole model, stack_wide +0.0314. X3 (one full attention layer
  proven at 125M) is next on the attention ladder.
- The committed-h memo landed (72caf67): the full-mode price is a
  layout artifact; rungs V1-V4 defined for the next round.
- **THE SPEED QUESTION (Victor, console 2026-09-01: "reach the 5-15 s
  per proof goal as quickly as we can" -> "decide how to proceed
  together")**: the recorded state is that the lattice line's
  enumerated moves count to ~100-160 s/board (II's 2026-08-28
  closing verdict); START_HERE.md §7 lists the five choices (A: the
  two-tier opening re-counted and measured on the GPU cost model;
  B: the Stage-A aggregate on the device; C: desktop-class hardware
  under the ladder; D: the hash-based comparison prototype; E: the
  8B MVP on the Mac + committed-h V1-V4 + X3). NOTHING IS STARTED;
  the next round opens when Victor rules.
- Config housekeeping (not project code): the allowlist synced with
  CLAUDE.md (4014cb5); no Bash command has prompted since auto mode
  went on in mid-August.

**AS OF 2026-08-29 evening (MAC-BOX SYNCED to the round-6 tree; full
Mac gate pass green):**
- The Mac pulled 9a8fa3d and now BUILDS — two aarch64 cfg gates were
  missing from the WSL rounds (the `psi_avx2::mac_fold_row` call in
  eval_proof.rs, the sha flag print in uperf-m); fixed, x86
  byte-identical.
- Full MAC gate pass [box QUIET, F2 training not running]:
  freeze-check FULL exit 0 (102 ok rows), suite 81/81 OK,
  diff-battery, uperf-s 48-leg 3752cba4.. + agg 136-leg 46234986..,
  uperf-w 23/23, agg-matmul, bh-verifier, v3 smoke + chain-m125 all
  12 layers, uperf-x 8/8 be89d5da.. Logs:
  `results/uperf/mac_sync_20260829_*`.
- **FINDING**: `pass-agg seam` had been silently broken since
  [UPERF2-Q] — the row-factor memo (keyed (q, s), scale folded in)
  ignores the battery's in-place scale perturbation. Battery
  artifact, production unaffected; the battery now drops the memo at
  the perturbation, seam 12/12 green. The drift-loud-memo question is
  left for Victor. Full record: the 2026-08-29 orchestrator note in
  PROGRESS_UPERF3.md.
- The Mac queue (T13/T14/T15 + the 7B proof rung) is runnable on a
  building, fully gated tree.

**AS OF 2026-08-31 (ROUND 8 MERGED + the day's rulings recorded):**
- **RULED: T17 = BOTH forms; F1 = FULL MODE** (F2 thereby adopted;
  the compact committed-h encoding = the round-9 design item; the
  8B recount owed — see the ledger's 2026-08-31 rulings block).
- **NN/X1 LANDED**: the full attention layer's 66 typed entries
  (spec §4.1 reconciled EXACTLY, 4 deltas flagged), the layer value
  chain byte-identical vs the python oracle at 6 (seed,T) pairs,
  PW-1..4 builders 19/19 F5 legs (digest f2f39137..), per-head
  X-S1 proving 2/2 accepts + 7/7 tampers at pre-registered gates;
  the X3 needs list (10 items, incl. NEW freeze rulings: AM-2 exp
  members, rope rows, range widths). X2 (AT-O1 at 125M) is next on
  the attention ladder.
- **OO/DIET 3 LANDED digest-identical**: the compact BfPlane store
  — 12x64 RSS -23% on top of HH+KK (cumulative -46..47% vs round
  5); **8B: commit ~61 GB, the pass peak now lvl-0 ~72 GB — under
  128 GB with ~56 GB margin (range-form counts); 30B: the layer
  store off the critical list (~40-46 GB), the new 30B peak = the
  weight-group terms ~265-270 GB (future levers named)**. The
  full-mode recount (owed per the F1 ruling) starts from these
  numbers.
- Six battery digests + freeze-check + both anchors green on the
  merged tree. The Mac path unchanged: T15 -> T16 -> T17 (both
  forms).

**AS OF 2026-08-30 late (ROUND 7 MERGED — the PoC sprint's WSL side
is COMPLETE; five battery digests + freeze-check green on the tree):**
- **LL/W-1 LANDED**: the claim tables split at 8B (f k=7, d k=2,
  all under the audited 2^25 cap); null split byte-identical; the
  forced-window battery (zc digest 01ca048b..); honest +139 KB at
  32x512 (corrects the memo's ~30 KB); the yardstick pays +0.
- **MM/THE COMPOSED v3 STATEMENT LANDED**: cross-layer seams BOUND
  (seam-edge MLE pins + the clamp-pair vs a statement-derived
  saturation table + Rs range — all existing machinery classes, no
  registry additions); composed battery 4/4 (digest 7465fa05..,
  surgical rejects incl. the honestly-recorded leg fix); the
  6-layer composed differential PASSED (12L = Mac-class, 10.6 GB
  measured at 6L); **the real-Mistral shape-general smoke is
  PROVABLE (39 legal seam clamps, 0 violations)**.
- **NEW MAC TASK T17 (after T15; KIND=RUN)**: the composed
  32-layer statement — `ZK_MODEL_EXPORT_DIR=<mistral v3 export>
  ring_matmul uperf-v3 composed 16 32` (add `diff` for the 32
  independent-proof differential if time permits; /usr/bin/time
  -l; expect ~40+ GB RSS [MODEL], hours-class at T=16 CPU). THIS
  IS THE WORKING PoC RUN. **RULED (Victor 2026-08-31): BOTH
  forms** — run the declarational composed statement over the real
  export AND the calibrated-tower composed proof (`composed-chain`
  feeds the tower; the same arm family), and the write-up states
  each object's meaning plainly. ALSO RULED: F1 = FULL MODE for
  the freeze set (see the ledger's 2026-08-31 rulings block: F2
  thereby adopted; the compact committed-h encoding is the round-9
  design item; the 8B memory recount owed).
- The Mac queue order stands: T1 -> T13/T14 -> **T15 -> T16 ->
  T17**.

**AS OF 2026-08-30 (MAC SYNC MERGED + the PoC sprint scoped):**
- **THE MAC GATE PASS IS GREEN** (0aed842, box QUIET): freeze-check
  FULL exit 0, suite 81/81, every battery digest byte-identical on
  aarch64 incl. the attention spike (be89d5da..); two aarch64 cfg
  gates fixed; the seam battery's silent-vacuity defect fixed
  (battery artifact; +1 ruling: the drift-loud memo).
- **STILL OPEN ON THE MAC (the PoC path, in order)**: T1 (the
  12x512 walls + digests), T13/T14 (Gemma), **T15 (the v3 exports
  + verify-export + the >15 GB per-layer proof rung)**, and THEN
  the NEW milestone: **the 32x16 8B YARDSTICK — the first full
  8B FFN proof (~95 GB, fits the Mac; needs W-1 column-splitting
  first, ~2-3 d WSL CODE — the last named code blocker)**.
- **THE STANDING TARGET (Victor 2026-08-30): ~80 proven tokens/s
  per H100 board at 30B** — currently counted ~25-35 amortized;
  the enumerated levers (Stage-A aggregate GPU port + fold fusion
  1.2-1.5x, pipelining 1.3x, spine amortization 1.1-1.2x) compose
  to ~65; the last ~1.3x needs an act-side opening idea — the
  round-7+ optimization campaign, informed by the first real
  Mac/H100 measurements. **[RETRACTED 2026-09-02: none of these
  numbers is derived from anything recorded — see
  U_PERF3_THROUGHPUT_MODEL.md §5.6 for the audit and §4 for the
  sourced table; kept here as history.]**
- **ADVERSARIAL_TESTING_PLAN.md is DOCUMENTED AND SHELVED** per
  Victor's directive (surfaces ranked, campaign phased, activates
  by ruling after the PoC); its §3 standing rule (tamper legs ship
  with every statement feature, same commit) is adopted NOW.
- **ROUND 7 (the PoC sprint) IN FLIGHT**: LL = W-1 column-splitting
  (the claim-table blocker); MM = the COMPOSED v3 statement (the
  cross-layer z->X seam binding — 32 per-layer proofs are not a
  model proof; MM's map-the-gap rung defines T17).
- **NEW MAC TASK T16 (after T15's Mistral export; KIND=RUN)** —
  the per-layer 8B evidence ladder (no new code needed): for l in
  0..31: `ZK_MODEL_EXPORT_DIR=<mistral v3 export>
  zkmatrix-rs/target/release/ring_matmul uperf-v3 e2e-m125 <l> 16
  32` (each proves layer l against the 32-layer stack; ~>15 GB RSS
  each, fine on the Mac; wrap each in /usr/bin/time -l). ACCEPT:
  32/32 `accept = true`; paste per-layer wall + peak RSS + the
  statement-bytes line into the log; STOP+paste on any reject.
  This is the first full-model-COVERAGE 8B proof evidence (the
  seams are MM's T17 — say so in any write-up). T17 (the composed
  32-layer statement on the Mac) gets exact commands when lane MM
  lands.

**AS OF 2026-08-29 (ROUND 6 MERGED; main current; four battery
digests + all identity anchors green on the final tree):**
- **JJ — SPIKE X-S1 GREEN ON ALL FOUR ACCEPTANCES: the first
  attention machinery exists** — a committed integer softmax chain
  end-to-end through the real claim machinery (2435 cms / 703
  pins, the REAL fused (d,E) LookupAt pair, one rolling
  transcript); 8/8 tamper legs at pre-registered gates (XS1
  battery digest be89d5da..); values byte-identical to
  scripts/attention_spec_spike.py, synthetic + Gemma-calibrated;
  the Stage-A leg byte-identical vs the descent oracle at
  attention widths. MVP-2's X1 rung (entry classes + PW wirings)
  is UNBLOCKED. New ruling item: the exp-member C5/AM-2 promotion
  (lane-local members await the X1 freeze set).
- **KK — DIET 2 landed digest-identical**: the verifier A_0
  streams (the ~70 GB 8B verify phase -> ~6 GB); phi_1 windowed.
  **8B 32x512 peak ~116 GB with ~12 GB margin, ROBUST (one phase
  above 75 GB, was four)**; next lever = the i8 layer store
  (-> peak ~72 GB class). Cumulative diet at 125M: -23..-31% RSS.
- **The composition ladder**: diet x Stage A ACCEPTS in one binary
  at 12x64 + 12x128 (bytes 2.1-2.15x smaller, prove +15%, the
  diet reaches Stage-A mode) — the F1 ruling input.
- Design memo Appendix A carries the A.1/A.2/A.3 amendment texts;
  U_PERF3_S4_REDESIGN.md is the closed headline record. RULINGS
  PENDING: the round-5 five + AM-2/exp-members.

**AS OF 2026-08-28 (ROUND 5 MERGED; main fast-forwarded; all gates
+ both identity anchors green on the final tree):**
- **ROUND 5 VERDICTS**: **GG — STAGE A IS INTEGRATED ON THE REAL
  PASS**: range AND full modes ACCEPT at 3x16 behind the selector
  (default byte-identical); descent transcript -23x, total -41%;
  12x128 A/B [CPU NOISY]: bytes 2.15x smaller, wall +15%, RSS 2x
  at this small shape (full mode OOM = finding F1's face); every
  claim grounded bit-for-bit; O-4 masked at pass level with real
  commitment binding. **HH — the W-8 diet landed digest-identical**
  (RSS -12..-27% at 125M; walls +8-12% as priced): **32x16 8B
  yardstick ~95 GB (fits 128 GB TODAY); 32x512 ~116 GB without
  descents** [COUNTED]; spec corrections recorded (CRS stream;
  the phi_1 omission ~46 GB at 8B = the next diet rung). **II —
  the S4 redesign memo CLOSED: the composed best case is 1.6-2.5x
  vs the 5x bar; NO spike S5; the 5-15 s question on this line is
  CLOSED absent a structurally new idea**
  (U_PERF3_S4_REDESIGN.md).
- **RULINGS AWAITING VICTOR (the round-6 opening decisions)**:
  (1) adopt the fallback headline posture formally (integrated
  Stage A + route 3, GPU port as multiplier — now the measured
  recommendation of BOTH round-5 paths); (2) F1 — Stage-A round-1
  scope: RANGE-ONLY (84/96 cols, silu descents kept; dodges the
  +25.2M-ring act-h growth) vs full-with-committed-h; (3) F2 —
  the act-h third-group ordering amendment (the design memo's
  ordering is circular as written); (4) OQ-2 — the {0,1} alphabet
  (sign-binary planes prove the two-sided range, not [0, 2^w));
  (5) EE's q46-aggregate question. The Mac/other-compute queue
  (T13/T14/T15) is unchanged and ready.

**AS OF 2026-08-27 (round 3 WSL program COMPLETE; lanes
uperf3-aa/bb/cc pushed):**
- **RULINGS (Victor, console 2026-08-26/27)**: percol-eZ tried and
  MEASURED (whack-a-mole: the z residues are ~7 ROAMING val-tail
  elements; chasing them costs +0.04..+0.09), then **CLAMP-AT-Z
  ADOPTED** — the z requant relation is CLAMPED (the C5 tables' D1
  +-32767 convention extended); free margins (7 bits: X x4 + gate
  l34 + h l30/39/43) carry the other sites. Gemma quality of
  record: **+0.0380** (vs +0.1049 percol / +0.1082 whole-plane
  margins).
- **AA — COMPLETE except the report block**: Mistral export (12-bit
  free margins, 0 viols) AND **the REAL Gemma-4-12B v3 export (48
  x T=512, adopted 7-bit set, 0 viols AND 0 z clamps on the export
  window; sidecar carries `00 zpolicy clamp`)**. --tables C5
  record: 14 members used, EVERY digest byte-matches the frozen
  registry — NO C5 additions needed.
- **BB — both real checkpoints RECONCILE byte-for-bit**: Mistral
  (silu, 128 plane legs) + **Gemma (gelu, 192 plane legs)** through
  verify-export (per-tensor e_w3 + family sniffing + a legible
  zclamps guard). m125 e2e ACCEPT post-migration. Forward: the
  clamp-selector z gadget (only needed when a witness window
  actually clamps); **the 7B/12B PROOF rungs are MAC tasks
  (measured: 15.08 GB OOM at 1x16 on this box, weights-dominated)**.
- **CC — COMPLETE**: attention core INT8-CLEAN per-tensor; the four
  seam sites widened-int16 RESCUE (stack_wide +0.0854 vs +14.83);
  postn +0.19 residue open (MVP-2 design pass). Design memo §1.6b
  = the measured exponent data.
- OPEN: (1) round-3 lane report blocks + MERGE (Claude/Victor); (2)
  the Mac queue after the merge — T13/T1/T4/T12/T14 + the NEW 7B
  proof rung task; (3) MVP-2 planning on §1.6b's measured ground
  (incl. postn); (4) the Euler-architecture weight-smoothness
  thread (PROGRESS_UPERF3.md orchestrator note 2026-08-26 night:
  smoothness must be INDUCED; proof-side delta/K-anchor commitment
  compression once a smooth checkpoint exists — frugal-lm side
  experiment, separate sessions).
- **ROUNDS 3 AND 4 ARE MERGED (2026-08-28) — main is
  FAST-FORWARDED to the merged tree.** Gates on the final tree ALL
  GREEN: diff-battery, freeze-check 102 ok rows, the 48-leg digest
  3752cba4.. UNCHANGED with lanes DD+EE+FF's code live, uperf-w
  23/23, EE's agg-battery 136 legs digest 4623..., v3 smoke +
  chain-m125 12/12, the uperf-t planner arm.
- **ROUND 4 VERDICTS**: DD — the E_c kernels took the zero-check
  from the spike's 1.6x to 2.7x wall vs the descents (AVX2,
  transcript-invariant). EE — the aggregate: rounds 13.3x, wire
  6.6x, MAC-NEUTRAL (structural win); O-4 mask landed. **FF —
  spike S4 is a MEASURED NO-GO on 2 of 4 criteria** (prove-group-
  equivalent 1.1x at 1T / 0.6x at 7T vs the required >= 5x;
  tt_verify 3.9-4.7 s vs sub-second; cause: the memo modeled ~19K
  w-only recursion rings, the real tier-2 input is u-digit-
  dominated at 1.65M). Claims equality and the 8B planner gate
  were GO. **AWAITING VICTOR (ruling-grade per the memo's own
  text): accept the fallback headline posture (Stage A + (iii) +
  route 3, ~100-160 s/board) or commission a redesigned front
  end.** Stage A proper is unaffected and validated.
- **NEW MAC TASK T15 (after T13; Grok-format, KIND=RUN)**: the
  real-checkpoint v3 rungs on the Mac (the bins are WSL-local;
  the Mac re-exports from its own checkpoints): (1) after T12's
  download: `python3 scripts/m8b_export_ffn.py --profile v3
  --margins results/m8b_margins_mistral_wsl.json` per the script
  header, into results/m8b_mistral_v3_export_mac; digests must
  MATCH the committed WSL sidecar rows; (2) after T13: the same
  via `python3 scripts/m8b_gemma4_walker.py --export-v3 ...
  --margins results/m8b_margins_gemma_percol_mz0_wsl.json --text
  <fineweb sample>`; (3) `ZK_MODEL_EXPORT_DIR=<export>
  zkmatrix-rs/target/release/ring_matmul uperf-v3 verify-export`
  (expect PASSED, 128/192 plane legs); (4) THE PROOF RUNG:
  `ZK_MODEL_EXPORT_DIR=<mistral export> ring_matmul uperf-v3
  e2e-m125 0 16 1` — needs > 15 GB RSS (measured OOM on the WSL
  box; the Mac's 256 GB holds it); paste accept/wall/RSS. STOP and
  paste on any digest mismatch — a mismatch is the finding.
- **NEW STANDING PROTOCOL (CLAUDE.md "Heavy runs: detach, queue,
  marker"):** heavy runs launch `setsid nohup` under
  `flock /tmp/zk-heavy.lock` with a `.done` exit-code marker, and
  follow-ups are ENQUEUED on the lock so the box keeps working when
  a session dies. ANY resuming agent: check for fresh `.done`
  markers + half-written logs in the worktrees' results/ FIRST and
  integrate them (ledger line + commit) before starting new work.

**AS OF 2026-08-25 (commit 73adfb3 + round-2 lanes cut):**
- DONE and pushed to main: U-PERF3 round 1 (8B scaling memo, Stage-A
  spike GO/GO, headline-routes memo); the Mistral-7B calibration
  finding (the checkpoint fails TARGET_CONTRACT §2 as written — see
  PROGRESS_UPERF3.md "T12 WSL validation pass"); the general
  quantization contract draft (QUANTIZATION_CONTRACT_DESIGN.md,
  awaiting Victor's ruling); Gemma 4 12B QAT scoped (favorable dims,
  no license gate).
- **v3 ADOPTED (Victor, console 2026-08-26: "Let's continue
  adopting this v3 fix")** — the widened-stack amendment is the
  contract's default qualification profile; both checkpoints
  qualify (Mistral +0.216, Gemma +0.035;
  U_PERF3_QUANTIZATION_MEASUREMENTS.md). ROUND 3 IN FLIGHT
  (branches uperf3-aa/bb/cc): AA = margin bits to 0 violations +
  the v3 witness exports (both checkpoints) + the int16-out table
  digests; BB = the v3 statement in the engine (widened classes,
  h16 limb-split down matmul, round-mode requant, the C5 registry
  rows under the ruling; v2 default byte-identical is the floor);
  CC = the attention-site qualification gate (the MVP-2 de-risk
  measurement). **Grok note: T12's export step stays gated until
  lane AA lands the v3 export flags on main** (the old per-tensor
  export would produce a witness the v3 statement rejects); T13/
  T1/T4 and T12's calibration cross-check unchanged; T14
  unchanged.
- LANE Y LANDED AND MERGED (2026-08-25): the Gemma 4 12B reference
  walker, VALIDATED (semantics pinned to the transformers source;
  templated factual probe 5/5 rank-0; templated greedy "...gold is
  Au."). **T14 is now OPEN with exact commands** (Section 3) — the
  full C4 gate can run on the Mac OR on this box once agent V
  frees the CPU. Gate risk recorded: the smoke shows hot early
  layers (X absmax 165.9 at l0) — whether QAT tamed the outlier
  profile is exactly what the verdict decides.
- LANE W LANDED AND MERGED (2026-08-25, gates re-run green on the
  merged tree): the rig accepts arbitrary model shapes — `BfModel`
  loaded from `ZK_MODEL_EXPORT_DIR`'s digests.txt (default = the
  M125 consts, freeze rows byte-identical), accumulator classes
  derived from the dims, the planner declines infeasible candidates
  instead of panicking (the 8B group counts now plan). FIRST PROOFS
  through the generalized loader: 1x16 + 3x16 accept,
  digest-identical to the m125 path. `uperf-w battery` (23 legs) is
  a standing gate now.
- LANE X LANDED AND MERGED (2026-08-25): the attention statement
  design memo (docs/zkmatrix-poc/U_PERF3_ATTENTION_STATEMENT_
  DESIGN.md, 859 lines) — MVP-2 full-layer multiples ~x2.0 over
  FFN-only at the 8B shapes [MODEL]; finding: as-built full-layer
  8B peak ~260-300 GB exceeds the Mac -> Stage A is MVP-2's
  memory-feasibility REQUIREMENT; spike X-S1 (integer softmax
  chain) named; 10 spec amendments AM-1..AM-10 queued for Victor's
  contract ruling.
- **GROK: your order is T13 -> T1 -> T4 -> T12 -> T14 (Section 3;
  T14 only once its status says its scripts are on main).** Nothing
  else. Specifically:
  - NEVER touch, merge, rebase, or continue the uperf3-* branches —
    even if they look finished. Claude or Victor merges lanes.
  - NEVER edit Rust or protocol files; every Grok task is KIND=RUN
    (run commands, paste outputs, commit results).
  - If a task's ACCEPT fails: STOP that task, paste the full output
    into Section 5's log with the date and box, commit, push, and
    move to the NEXT task in the order. A pasted failure is a
    COMPLETED Grok task — do not try to fix code.
  - Commit and push (main) after EVERY completed task, not at the
    end of the session: one task = one commit, message prefix
    `U-PERF3 GROK: <task id>`.
- RULES FOR WRITING NEW GROK TASKS (Claude/Victor): KIND=RUN only;
  numbered steps with ONE command per step; no compound shell, no
  env-var prefixes unless the task text gives the exact line to
  paste; an explicit ACCEPT and an explicit STOP per step; name the
  RAM/disk/time cost up front; say what to commit.

## 1. Rules (read once)

1. **Differential floor.** A performance change is accepted ONLY if
   (a) its function-level battery leg holds byte equality against the
   reference implementation, (b) `ring_matmul freeze-check` exits 0
   with every pre-existing digest unmoved, and (c) the EVAL-PROOF
   DIGEST printed by `uperf-pc pass-profile` is identical before and
   after at the same shape (Section 2.3). A speedup that moves any of
   those is a bug — revert.
2. **Transcript-preserving only.** Do not change what is absorbed into
   the transcript, the order of RNG draws, planner parameters (r cap,
   kappa, e caps), or any freeze row. Those are R-rows: file them in
   U_PERF_WAVE_REPORT.md Appendix R for Victor's ruling, do not build.
3. **One task, one commit** (or a short series of commits), message
   prefix `U-PERF PC:` and the task id, e.g.
   `U-PERF PC: T4 matvec_modq_small_multi (NTT-domain, O3) — battery leg green`.
4. **Timing labels are mandatory**: `[MAC-BOX]` or `[WSL-BOX]`, `1T` or
   `NT`, `QUIET` or `NOISY-SHARED` (frugal-lm training on the Mac =
   NOISY). Wall numbers without labels are not recorded.
5. **Do NOT touch**: `codex-audit-*`, `scripts/logup_*_spike.py`,
   `src/manifest.rs`, kfield/sumcheck/gkr/gkr_masked internals (PA's
   zone), lookup/digits/fold/pass_agg/t_blind/descent_fold/wire.
   In-scope files for the clock work: `zkmatrix-rs/src/ring/eval_proof.rs`,
   `zkmatrix-rs/src/aux_ntt_core.rs` (additive only), the `bg_*` /
   `agg_*` / `bk_*` / `uperf_pc_*` sections of
   `zkmatrix-rs/src/bin/ring_matmul.rs`, `tests/test_uperf_pc.py`,
   `docs/zkmatrix-poc/U_PERF_WAVE_REPORT.md`, this file,
   `PROGRESS_UPERF.md`.
6. **Record every result** in the task's `RECORD` target with the
   4-line format: date+box+label / command / verdict+numbers /
   commit hash. Then flip the task's status here.

## 2. Box facts and recipes

### 2.1 The two boxes

| | MAC-BOX (M3 Ultra) | WSL-BOX (Intel Core Ultra 9 185H) |
|---|---|---|
| RAM | 256 GB | 15 GB |
| frugal-lm ckpt + `results/m125_ffn_export/*.bin` | YES | ckpt YES (tarball, 2026-08-17); the frozen export's 36 weights YES (byte-identical), its 12 X files **NO** (Mac Metal rounding) — instead the local re-export `results/m125_ffn_export_wsl/` (valid witness, X differs) via `M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl` |
| composed pass 12x512 (RSS 41-47 GiB) | runs | **cannot run** (RAM); 3x16 and per-layer T=16 rigs RUN with `M125_EXPORT_DIR` set |
| `freeze-check` | full, exit 0 required | first 98 rows green, then panics at the UAGB1-BF rows (missing export) — EXPECTED here |
| python suite | all green required | 77 pass, 2 skip, and EXACTLY these 4 fail for the same missing-export reason (freeze-check SIGABRT / layer00_X.bin): `test_ring_freeze_check`, `test_freeze_rows_uagb1_bf`, `test_pass_smoke_real_data`, `test_freeze_rows` (tblind) — measured 2026-08-17 at 213dfa2, 469 s; re-measured 2026-08-18 at a42e54d (after U-PERF2 rounds 1-8): 81 tests, 75 pass / 2 skip / exactly the same 4, 590 s (lanes P/Q building concurrently). Any OTHER failure is real. |
| `uperf-pc diff-battery`, `agg-matmul ...`, `bh-verifier ...`, `agg-kel`, unit rigs | run | run |
| build | `cargo build --release` in `zkmatrix-rs/` (or `--manifest-path` from the root — the two are now the SAME build: `zkmatrix-rs/.cargo/config.toml` no longer sets `target-cpu=native`, which was measured 3-4x SLOWER on the WSL box and applied only cwd-dependently) | same (plain `cargo`; the rustup proxy is ahead of snap on PATH) |
| timing status | frugal-lm F2 training may be running (check `top`) -> label NOISY-SHARED | usually quiet; is the TARGET_CONTRACT "CPU reference machine" |

So: code + function-level batteries can be written and verified on
EITHER box; the 125M profiles / A/Bs / full freeze-check / suite /
pass-agg batteries are MAC-BOX tasks.

### 2.2 Commands (all from the repo root unless noted)

```
# build (from zkmatrix-rs/)
cargo build --release
# gates
zkmatrix-rs/target/release/ring_matmul freeze-check            # exit 0, no FAIL rows [MAC full; WSL panics at BF rows]
zkmatrix-rs/target/release/ring_matmul uperf-pc diff-battery   # every optimization's byte-equality leg
python3 -m unittest discover -s tests                          # suite (~15-20 min MAC; export-dependent tests skip on WSL)
# profiles (MAC only; minutes to ~1.5 h)
zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16      # fast yardstick (~6-8 min): FULL-STATEMENT attribution + EVAL-PROOF DIGEST
zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512    # the real thing (~80 min prove + verify before the kernels)
zkmatrix-rs/target/release/ring_matmul uperf-pc pass-profile 12 512    # composed scope only (no table descents; BG rig)
zkmatrix-rs/target/release/ring_matmul pass-agg prove 12 512 p0        # composed-scope prove+verify (BG rig)
zkmatrix-rs/target/release/ring_matmul table-descent prove 12 512 p0   # FULL-STATEMENT prove+verify (BK rig, the PoC number)
zkmatrix-rs/target/release/ring_matmul pass-agg battery                # 14 legs, ~70 min [MAC]
zkmatrix-rs/target/release/ring_matmul pass-agg seam                   # 12/12 psi-seam differential (~1 min)
zkmatrix-rs/target/release/ring_matmul agg-matmul battery              # 23 legs, ~4 min, synthetic (runs on WSL)
zkmatrix-rs/target/release/ring_matmul bh-verifier battery             # BH differential + BF-F3 legs (synthetic)
```

Wrap long runs in `/usr/bin/time -v` (Linux) or `/usr/bin/time -l`
(macOS) so wall + peak RSS land in the record.

### 2.3 The EVAL-PROOF DIGEST (the composed-pass differential gate) and the two env knobs

`uperf-pc pass-profile <layers> <t>` prints
`[UPERF-PC] EVAL-PROOF DIGEST <hex>` = SHA-256 over both groups'
GroupEvalProof wire fields (b_rows, u0, ugh0, level_us, floor,
tcap_attempts) in order. It must be IDENTICAL at the same
(layers, t, mode) before and after any Phase-0 change. Baselines are
recorded in Section 4 as they are measured (T1).

Two environment knobs make every A/B a ONE-BINARY affair:

- `ZK_UPERF_ORACLE=1` routes every Phase-0 kernel entry point
  (matvec / ring-ip / level-h / the claim-kernel passes / the
  verifier's factored psi) to its pre-optimization oracle at runtime.
  Same binary, same box, same shape: run once with it (the "before")
  and once without (the "after"); the digests must be identical and
  the walls are the A/B.
- `ZK_THREADS=n` (default 1 = the ledger's 1T convention) sizes the
  kernel thread pool; every parallel split is over independent
  exact-integer work with a fixed reduction order, so the digest is
  identical for any n (the battery asserts it at 1/2/7). Record NT
  numbers as a separate row, never in place of the 1T number.

## 3. The queue (ordered; take the first OPEN task your box can do)

Legend: WHO = MAC | WSL | ANY (which box can do it); KIND = RUN (run
commands, paste numbers), CODE (write code + battery leg), DESIGN (not
for a mechanical agent — leave for Claude/Victor).

---

### T0 — hygiene at every commit  `STANDING`  WHO: ANY  KIND: RUN
Before every commit that touches Rust: `cargo build --release` green,
`uperf-pc diff-battery` green, `freeze-check` (MAC: exit 0; WSL: 98
rows then the expected BF panic — paste the last `ok` row). Before
every PUSH from the MAC: full suite green.

---

### T1 — pass-profile BASELINE + AFTER (attribution table + digest)  `OPEN`  WHO: MAC  KIND: RUN
WHY: nobody has run the composed-pass profile; every share above is
BG-F3 arithmetic. This gives the measured before/after tables AND the
digest identity for O2/O3/O5/T8b (which landed 2026-08-17 on the WSL
box with battery legs only). ONE binary, two env settings (2.3).
STEPS (`full-profile` = the FULL-STATEMENT rig incl. the 10 descent
pairs — the PoC number, ~80 min before; `pass-profile` = the composed
scope without table descents — use it only if full-profile cannot run):
1. `git pull`; `cargo build --release` (in zkmatrix-rs/); `mkdir -p results/uperf`.
2. Fast yardstick, BEFORE then AFTER (each ~5-10 min):
   `ZK_UPERF_ORACLE=1 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/fp_3x16_oracle.txt 2>&1`
   `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/fp_3x16_fast.txt 2>&1`
   The two `EVAL-PROOF DIGEST` lines MUST be identical. If not: STOP,
   record, do nothing else (that is a bug report, not a fix).
3. The real thing, AFTER first (so the useful number exists early),
   then BEFORE (~80-90 min; peak RSS ~47 GiB; nothing else heavy):
   `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/fp_12x512_fast.txt 2>&1`
   `ZK_UPERF_ORACLE=1 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/fp_12x512_oracle.txt 2>&1`
4. Optional NT row: `ZK_THREADS=8 ... full-profile 12 512` (digest
   identical; record as a separate NT row). The phase table's
   `bk.descent-trees` / `bk.descent-gkr` / `bg.commit-phase` /
   `bg.claim-layer` / `bg.prove-group` / `bg.verify-group` rows are the
   next round's priority order.
5. Copy the phase tables (the `ep.*` / `bg.*` rows), `accept`, walls
   (commit/prove/verify), and the digests into U_PERF_WAVE_REPORT.md
   Section 4.2 (before/after per shape) and Section 4 of THIS file.
ACCEPT: `accept = true` everywhere; digests identical oracle vs fast
(and vs NT); the 12x512 statement digest equals the frozen
`76dbf2040409333e` prefix printed by the rig.
RECORD: U_PERF_WAVE_REPORT.md Section 4.2; TASK_BOARD Section 4;
PROGRESS_UPERF.md log line ("T1/T4 measured: ...").
NOTE: `results/uperf/` is new; add a `.gitignore` with `*.txt` if the
files are large, and paste the tables into the report.

---

### T2 — the h cross-garbage in the NTT domain (O2)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: ANY  KIND: CODE
DONE: `eval_proof::level_h_pairs` + `ntt_gemm_modq_small` + oracle
`level_h_pairs_ref`; `bg_level_h` / `agg_level_h` switched; battery
leg "O2 level-h" 35/35; freeze-check rows identical to the pre-change
baseline; `agg-matmul battery` 22/22 + passed; `bh-verifier battery`
passed. Kernel-bench [WSL-BOX 1T QUIET] `uperf-pc kernel-bench 64
2048`: 0.245 us/product NTT vs ~5.0 us/product kara (r=16 oracle run)
=> ~20x on the level-0 term on this box (Section 4 of
U_PERF_WAVE_REPORT.md). Remaining for T4: the 12x512 digest + wall.
WHY: the largest term of the composed prove (~500M + ~227M ring-mults at
125M, ~2 us each on `ring_ip_modq_small`). Same arithmetic, ~15-25x.
WHAT: `eval_proof::level_h_pairs(ctx, phi_slices, w_slices) -> Vec<Poly>`
— r x chunk mod-q slices and r x chunk small slices, returns the
r(r+1)/2 h polys in pair order (j <= k), computed as D independent
(r x chunk) x (chunk x r) integer GEMMs in the NTT domain (transform
each ring once, split-halves lazy accumulation, exact-integer capacity
windows from `aux::max_n_acc`, one inverse per (pair, window)), with
`level_h_pairs_ref` = the current kara loop kept as the oracle.
Callers `bg_level_h` (bin, ~line 29152) and `agg_level_h` (bin, ~line
20068) switch to it. Battery leg in `uperf_pc_diff_battery`: random
q31 AND q46, r in {1,2,3,5,8}, chunk in {1,7,64,257}, w with extreme
digits (+-s_max, zero rings, whole-zero slices), windows crossing (q46
+ s_max 64 => 32-term windows), and the over-capacity fallback.
ACCEPT: leg prints `O2 level-h: N/N byte-identical`; freeze-check per
T0; `agg-matmul battery` 23/23; then (MAC) pass-profile 3x16 digest ==
T1 baseline.
RECORD: U_PERF_WAVE_REPORT.md Section 3 (O2), this row.

---

### T3 — matvecs in the NTT domain (O3)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: ANY  KIND: CODE
DONE: `matvec_modq_small` (all call sites, prover + verifier) and
`ring_ip_modq_small` ride the kernel; new `matvec_modq_small_multi`
in `bg_matvec_chunks` / `agg_level_t`; oracles `*_ref`; battery leg
"O3 matvec" 63/63; same transcript gates as T2. Kernel-bench: 0.65
us/product NTT vs ~5.3 us kara [WSL-BOX 1T].
WHAT: `eval_proof::matvec_modq_small_multi(ctx, m, rows, cols, s_list)
-> Vec<Vec<Poly>>` (one M, many small vectors; M transformed once per
call, u-major accumulation into rows x len(s_list) accumulators);
`matvec_modq_small` and `ring_ip_modq_small` bodies switched to the
same window-accumulate primitive with the kara bodies kept as
`*_ref` oracles. Callers: `bg_matvec_chunks` (bin ~29107),
`agg_matvec_chunks` (bin ~20040) use `_multi`. Battery legs as in T2
(shapes rows in {1,11}, cols in {1,5,64,301}, both q's, extreme digits,
window crossings, fallback).
ACCEPT/RECORD: as T2 (leg `O3 matvec: N/N byte-identical`).

---

### T4 — the rest of the rig gates after T1  `OPEN (after T1)`  WHO: MAC  KIND: RUN
STEPS (all at HEAD, fast path): `freeze-check` exit 0 (full, incl. the
BF rows); `pass-agg seam` 12/12; `pass-agg battery` 14/14 (~70 min);
`table-descent prove 12 512 p0` for the full-statement wall (also once
with `ZK_UPERF_ORACLE=1` if time permits — the two `accept`/bytes
lines must match); the python suite green before any push.
RECORD: U_PERF_WAVE_REPORT.md Section 4.2, PROGRESS_UPERF.md log line,
this row.

---

### T5 — the two claim-kernel passes, factored (rows pass + phi pass)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: Claude preferred (ANY with care)  KIND: CODE
DONE: `eval_proof::kernel_pass_factored` (+ `ColBlockCache`, `cq0_block`,
`g_block`), wired at the prover's two passes and the verifier's
non-recursed rows_eval; `bg_kernel_pass` kept as the oracle; battery
leg "O5 kernel-pass" 6/6; kpass-bench 512x2048: rows 42.6x, phi 51.5x
[WSL 1T]. Details: U_PERF_WAVE_REPORT.md Section 3 (O5). The text
below is the derivation as built (kept for the record).
WHY: `bg_kernel_pass` (bin ~29210) is the second-largest prover term:
per DIGIT ring it calls `claims.kw_value_row` (per value ring: 128 x
n_contrib x 2 K-field mults — likely the hidden cost) and then 16
`ring_mul_split_kara_fast`; twice (rows pass, then phi pass): ~365M
ring-mults + ~1.4G K-mults at 125M.
WHAT (exact identities; everything below is a re-association of the
same mod-q sums, so byte identity is by construction; the current
`bg_kernel_pass` is the oracle). Notation: tensor with `rows x cols`,
`cols % 128 == 0` (all 125M tensors; else fall back to the oracle
path), value ring vr = (row, cb) with cb = column block, digit ring u =
(vr, limb), radix_u = 2^(e0*limb); K-field bilinearity:
`kf.mul(x, y)[d] = sum_{d1} x[d1] * (Y^{d1} * y)[d]`; contributions
`c` = (scale_c, row_c[.], col_c[.]) with kw_u[c1] = sum_c
kf.mul(scale_c*row_c[row], col_c[cb*128 + c1]).
- Hoist: `sr_c[row] = kf.mul(scale_c, row_c[row])` once per (c, row).
- phi pass: for each (c, cb, d1) precompute the mod-q RING
  `G_c[cb][d1] = sum_{c1} conj(X^{c1}) * ( sum_d (Y^{d1} * col_c[cb*128+c1])[d] * alpha_d )`
  (n_contrib x nb x 16 rings per tensor — trivial). Then for every
  value ring: `PHI_vr = sum_c sum_{d1} sr_c[row][d1] * G_c[cb][d1]`
  (16 x n_contrib scalar-x-ring MACs with u128 lazy accumulation, one
  mod-q reduce), and `phi_u = radix_limb * PHI_vr` per limb. This is
  the verifier's `psi_level0_factored` trick on the prover side.
- rows pass: `V_vr = sum_limb radix_limb * w_(vr,limb)` (the value
  ring recomposed mod q — small rings x radix, exact); then per
  (c, d1): `T_c[d1][cb] += sr_c[row][d1] * V_vr` over rows (scalar x
  ring MACs, u128 lazy); finally
  `b_rows[d] = sum_c sum_{d1} sum_{c1} conj(X^{c1}) * sum_cb (Y^{d1} * col_c[cb*128+c1])[d] * T_c[d1][cb]`
  (n_contrib x 16 x 128 x nb scalar-x-ring MACs — trivial).
Both passes become O(n_value_rings x 16 x n_contrib) scalar-ring MACs
(~6G mult-adds at 125M, seconds) with NO per-ring K-mults and NO ring
mults. Keep the misaligned/absent-kernel path on the oracle.
Battery leg: synthetic groups (the `bh-verifier` builders + the real
`bg_build_groups` on the 3x16 shape on the MAC), byte identity of
`b_rows` and of every `phi` ring against the oracle.
ACCEPT/RECORD: as T2 (leg `O5 kernel-pass: N/N byte-identical`).

---

### T6 — multithread the kernels (rayon, deterministic)  `LANDED for the Phase-0 kernels 2026-08-17 (Claude, WSL); the rest OPEN`  WHO: ANY  KIND: CODE
DONE: `ZK_THREADS=n` pool in eval_proof.rs; the NTT GEMM (transforms
per ring, the D coefficient positions of the accumulate, the scatter,
the flush), the factored phi pass (value-ring blocks), the rows pass
(per-range partial T sums reduced in order + per-(kernel, cb) block
products) and the verifier's factored psi (value-ring blocks) all
split over independent exact-integer work. Battery identical at
ZK_THREADS 1/2/7. Kernel-bench 64x8192 [WSL]: level-h 7.6 s (1T) ->
1.24 s (20T) = 6.6x on this hybrid 6P+8E box; kpass-bench 512x2048:
rows 2.55 -> 0.74 us/digit ring, phi 2.39 -> 0.91 at 7T (fixed
per-tensor precomputes bound the gain at this size).
OPEN (same recipe): `bg_fold`/`agg_fold` (T7), the transport levels
(T3b), the descents (PA/BK zone — see T11), commit's chain derivation.
RECORD: U_PERF_WAVE_REPORT.md Section 4 (a 1T vs NT row from T1 step 4).

---

### T7 — `bg_fold` / `agg_fold` in the NTT domain (small)  `OPEN`  WHO: ANY  KIND: CODE
`z_u = sum_j c_j * w_{j,u}` (small x small, exact i64) — currently
`poly_mul_small` schoolbook (16K MACs each, n_0 of them, ~1-2% of the
prove). Transform c_j once (r NTTs), per u r forward + 1 inverse
transform; exact by the small-operand bound (128 * 2 * 64 << p/2).
Oracle = current loop; battery leg; ACCEPT/RECORD as T2.

---

### T8 — verifier attribution toward the <= 2 s line  `OPEN`  WHO: MAC  KIND: RUN
`pass-profile` now prints `bg.verify-group` (per-group verifier total)
next to the shared `ep.*` counters; T1's table gives the split. Known
O(n_0)-class verifier terms to expect: `psi_level0_factored_multi`
(per VALUE ring: 16 kara ring-mults beta x conjq + 1 per digit-ring
chunk change — ~24M + ~10M ring-mults at 125M, i.e. ~70 s of the
199.6 s) and `transport_level` at level 1 (~12 kara ring-mults per
next-witness ring, ~750K rings per group, prover AND verifier).
RECORD: U_PERF_WAVE_REPORT.md Section 2 (verify table).

### T8b — the verifier's `psi_level0_factored_multi`, factored  `LANDED 2026-08-17 (Claude, WSL)`  WHO: ANY  KIND: CODE
DONE: the aligned branch now uses `PhiFactored` (T5's machinery: no
per-row K-mults / per-value-ring beta x conjQ ring-mults; one
c_k x PHI ring-mult per (value ring, k-run) remains) — battery leg
inside "O5 kernel-pass" (== compute_psi(phi0_reference_multi) at two
chunk splits, both moduli). Rig verify A/B rides T4.

### T3b — `transport_level_from_psi` in the NTT domain  `OPEN`  WHO: ANY  KIND: CODE
General x general operands: the 12-24 alphas are fixed rings
(transform once); per next-witness ring the operands are psi[src] /
a_mat[.][src] scaled by radix (mod q). Needs the limb-split contract
(aux `A1LimbCommitKernel` pattern, or `ring_mul_q_limbsplit`'s exact
recompose) — ~12 general ring-mults per ring today, ~750K rings per
group at level 1, prover AND verifier. Oracle: the current function.
ACCEPT/RECORD: as T2 (leg `O6 transport: N/N byte-identical`).

---

### T9 — memory diet for the 15 GB reference box  `OPEN`  WHO: ANY (c: Claude preferred)  KIND: CODE
The composed pass peaks at 41-47 GiB. Where it goes: the eval-proof
phase holds phi (n_0 x Poly: ~8 GiB for the act group) + w0 for both
groups (~12 GiB as Vec<Vec<i64>> with per-ring heap headers); but the
PASS PEAK (47 GiB, UAGB1_TABLE_DESCENT_REPORT 3.3) is the DESCENT
phase's tree batches ("nrw-88's 16-tree batch") — so a 15 GB-box diet
needs the descent trees streamed/batched smaller (BK/PA zone; T1's
`/usr/bin/time -l` RSS + the bk.descent-* rows tell how much) AS WELL
AS the two items below. Transcript-neutral steps on the eval-proof
side:
(c) FIRST (biggest, mechanical after T5/T8b): never materialize phi
at level 0. In `bg_prove_group`: (1) replace the level-1
`transport_level(ctx, &phi_cur, ...)` by
`transport_level_from_psi(ctx, &psi0, ...)` with `psi0 =
psi_level0_factored_multi(ctx, kf, group, &mk, &alphas0, &c0,
plan0.chunk)` — EXACTLY what `bg_verify_group` already does at level
1 (the `pass-agg seam` differential is the proof it is
compute_psi(phi_cur) bit for bit); (2) feed `bg_level_h` at level 0
from a phi PROVIDER instead of `phi_cur`: add
`level_h_pairs_with(ctx, phi_block: impl Fn(j, u0, &mut [Poly]),
w_slices, chunk)` whose a-side rings are produced per u-block by
`PhiFactored::value_ring` (per digit ring v = j*chunk + u: locate
(tensor, vr, limb) — consecutive u are consecutive v, so one PHI_vr
per value ring per pass, cached across the l0 limbs; radix scale per
limb) — the same arithmetic as the phi pass, no extra cost, and the
12 GiB `phi_cur` is never allocated (`phi_cur.truncate(n0)` and the
level-1 `phi_cur.resize` go away; deeper levels keep their small
materialized phi). Battery: the O5 leg's groups through the provider
vs `level_h_pairs` on the materialized phi.
(a) then w0 as a flat `Vec<i8>` (digits |w| <= 64) with slice views
at the consumers (matvec / level-h / fold / floor) — invasive, second.
(b) drop slices as level 0 consumes them.
Target: 12x512 P0 under 14 GiB so the TARGET_CONTRACT reference box
can run it. Measure with `/usr/bin/time -v` (Linux) — WSL-verifiable
once the export is copied over (T10).
RECORD: PROGRESS_UPERF.md log; TARGET_CONTRACT note if the reference
box becomes runnable.

---

### T10 — copy the m125 export to the WSL box  `MOSTLY DONE 2026-08-17`  WHO: Victor  KIND: RUN
DONE: Victor delivered the checkpoint tarball + the val shard; the WSL
box re-exported everything (`results/m125_ffn_export_wsl/`, 36/36
weights byte-identical, X differs by mlx CPU-vs-Metal rounding, 0
range violations) — the 3x16 / T=16 rigs run here with
`M125_EXPORT_DIR` set. REMAINING (small): the Mac's 12
`results/m125_ffn_export/layerXX_X.bin` files (~4.7 MB) copied to the
same path here would make freeze-check's UAGB1-BF rows and the frozen
statement digest reproducible on this box too.

---

### T11 — DESIGN items (not for a mechanical agent)  `OPEN`  WHO: Claude/Victor  KIND: DESIGN
(a) Prover-side rank-structured Phi_0: after T5 the prover's phi pass
is `PHI_vr = sum_{c,d1} sr_c[row][d1] * G_c[cb][d1]` per value ring
(16 x n_contrib scalars against 16 cached rings per (col kernel,
cb)); the next step is to feed `level_h_pairs` per u-block from that
form (never materialize the 11 GiB phi) — memory item T9(c).
(a') THE VERIFIER <= 2 s LINE (PoC-complete criterion 1(b)) — memo
2026-08-17 (orchestrator), supersedes the "chunk alignment" sketch:
after T8b the verifier's level-0 work is O(n_value_rings x 16 x
n_contrib) scalar MACs (~8.6G at 125M: ~14 s [WSL 1T], ~7 s [MAC 1T])
plus the transport levels (~25 s -> lane C), the descent verifies
(~36 s -> lane A) and small terms; the 1T verify after this round
lands in the ~40-60 s class, NOT <= 2 s. The chunk-alignment idea is
WITHDRAWN: at the 125M point every tensor (~41K digit rings) is
SMALLER than the level-0 chunk (~122K), so each chunk position u is
folded across ~r different tensors — the fold cannot be pushed
through the row structure and the "S[u'][j]" reuse has size ~1. A
verifier sublinear in n_value_rings needs a PROTOCOL change (a
polylog-verifier opening layer, or the prover supplying Psi_0 with
its own checkable proof) — design-trench work, not an R-row. The
practical route to a 2 s-class verify is `ZK_THREADS` on the
reference box (22 threads: ~2-4 s projected) — which requires
relaxing TARGET_CONTRACT's "single-threaded" wording to "single
machine, N threads stated" (Victor's ruling; an amendment, not code).
(b) R-row: the planner's r = 64 cap trades bytes for the Theta(n_0*r)
garbage; at r = 32 the h term halves and the artifact grows (derive
the bytes; the P0 artifact sits at 0.48x its gate). Transcript-
changing: Victor's ruling, freeze rows re-pinned if adopted.
(c) The GPU rung (CONTINUATION Phase 3): T2/T5's D-batched integer
GEMMs and the A1 commit kernel are the two kernels to port first.

---

### T12 — the 8B FFN calibration + export on the Mac  `OPEN — DOWNLOAD APPROVED (Victor, console 2026-08-24: "Go ahead with the mistral download")`  WHO: MAC  KIND: RUN
WHY: MVP-1 (PROGRESS_UPERF3.md) proves the 8B FFN shape with REAL
int8-calibrated weights; this produces the witness in the rig's
layout. Gates M3/M8 of the MVP plan. Needs Victor's go for the
download (~17 GB network, ~30 GB disk). RAM < 4 GB RSS (streamed) —
F2 training may keep running; nothing here is timed.
PREREQS (one-time): a python3 with numpy;
`pip install huggingface_hub tokenizers pyarrow` (network — part of
the same go-ahead). All commands from the repo root.
STEPS: follow `docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md` Section
5.2 LITERALLY — it is this task in board format with the exact
commands (download Mistral-7B-v0.1 ungated; FineWeb-Edu parquet +
text extraction; the `--decode "The chemical symbol for gold is"`
sanity gate BEFORE anything long — STOP and paste if " Au" is
absent (gate revised 2026-08-24: the earlier France prompt false-
fails in fp32 — memo §5.2 step 3 has the record); calibration
~20-45 min; export ~10-25 min; `--weights-only` re-check). PASTE into the log: the per-layer exponent table, every
`silu-int8-table-v2 member` line (W-6 flags), the variant-A
violation count, the VERDICT block, peak RSS.
COMMIT: results/m8b_int8_calibration.json,
results/m8b_ffn_export/digests.txt + manifest.json (+ the script's
.gitignore). The .bin files stay on the Mac; keep `layer00_*.bin`
handy for the WSL sync (~180 MB).
DO NOT run the rig on the export: the 32x16 rung is GATED on the MVP
plan's M1+M2 code rungs (W-5/W-4/W-2 — the rig is hard-coded to the
125M shape today and will panic). The board gets the exact rig
command when M1 lands.
ACCEPT: memo §5.2 steps 3-6 green; the JSON + manifest + digests
committed; the paste in the log.
RECORD: TASK_BOARD §4 + a PROGRESS_UPERF3.md log line ("T12 done:
eW range …, silu members …, violations 0/…, RSS … GB").

---

### T13 — download Gemma 4 12B QAT on the Mac  `OPEN`  WHO: MAC  KIND: RUN
WHY: the prime "native" candidate checkpoint (QAT-trained with int8
activations) for the general quantization contract; the Mac will run
its qualification gate (T14) and, if it qualifies, the 12B proof.
Verified on the WSL box 2026-08-25: NO license gate, no token needed.
COST: ~23 GB network + 23 GB disk; minutes to ~1 h depending on
bandwidth; no RAM to speak of. F2 training can keep running.
STEPS:
1. `python3 -c "import os; from huggingface_hub import snapshot_download; snapshot_download('google/gemma-4-12B-it-qat-q4_0-unquantized', local_dir=os.path.expanduser('~/models/gemma-4-12B-qat'), allow_patterns=['*.safetensors','*.json','tokenizer.model'])"`
   (If `huggingface_hub` is missing: `pip install huggingface_hub`
   first — that is the T12 prereq set.)
2. `ls ~/models/gemma-4-12B-qat/`
   ACCEPT: config.json, model.safetensors, tokenizer.json present.
   STOP if a login/403 error appears — paste it (the WSL box needed
   no token; a gate here is news).
3. `du -sh ~/models/gemma-4-12B-qat/`
   ACCEPT: ~23 GB.
RECORD: one log line in Section 5 ("T13 done: 23G, files listed"),
commit, push.

---

### T14 — the Gemma 4 qualification-gate run on the Mac  `GATED (watch for scripts/m8b_gemma4_walker.py on main)`  WHO: MAC  KIND: RUN
WHY: THE decisive measurement for the "native" route — does a
QAT-int8-activation checkpoint pass the contract's calibration gate
(0 range-fact violations + small loss delta) where Mistral-7B failed
with 14,531 violations and +8.18 nats? If yes, this checkpoint is
the MVP vehicle.
GATE: OPEN as of 2026-08-25 — lane Y landed; the scripts are on
main. `git pull` first.
PREREQ: T13 done; the FineWeb-Edu text file from T12 step 2 (same
sampler data as the Mistral baseline — REQUIRED so the verdicts are
comparable). COST: each 48-layer decode pass ~2-6 min on the Mac;
the full calibration ~15-40 min [MODEL]; RSS < 6 GB; F2 can run.
STEPS (all from the repo root; the walker defaults to
`~/models/gemma-4-12B-qat` = T13's location):
1. `git pull`
2. `python3 scripts/m8b_gemma4_walker.py --decode "The chemical symbol for gold is" --template`
   ACCEPT: the completion contains " Au".
   STOP+paste if not. **NOTE: `--template` is REQUIRED — without it
   this instruction-tuned checkpoint greedy-decodes degenerate
   zeros; that is a known property of the model (its own
   generation_config suppresses those tokens), NOT a bug — do not
   report a plain-decode failure.**
3. `python3 scripts/m8b_gemma4_walker.py --probe --template`
   ACCEPT: >= 3 of the 5 factual prompts in the top-2 ranks (the
   WSL reference run scored 5/5 at rank 0 — paste your ranks; a
   materially worse table is a STOP+paste).
4. The full qualification gate (the C4 verdict):
   `python3 scripts/m8b_gemma4_walker.py --text ~/models/fineweb-edu/sample_text.txt --out-json results/m8b_gemma4_calibration_mac.json`
   ACCEPT: the script exits 0 and prints a VERDICT block. **The WSL
   verdict already landed 2026-08-25 (FAIL: 116,852 violations,
   almost all at the z site of ~6 layers with the FFN internals
   clean; +17.60 nats; committed as
   results/m8b_gemma4_calibration.json) — your run is the CROSS-
   CHECK: the violation counts, exponent tables and member digests
   must MATCH that JSON. A mismatch is the finding — paste both.**
   Any exception/assert = STOP+paste.
5. Commit `results/m8b_gemma4_calibration_mac.json` + paste the
   VERDICT block into Section 5's log; push.
RECORD: the full verdict block (violations by class, loss delta, the
member digests) pasted into Section 5 + PROGRESS_UPERF3.md log line;
commit results JSONs; push.

## 4. Baselines and digests (append-only)

| date | box/label | shape | command | EVAL-PROOF DIGEST | prove s | verify s | commit |
|---|---|---|---|---|---|---|---|
| (T1 fills this) | | | | | | | |

## 4b. Round 2 + 3 (U-PERF2, 2026-08-17 — PROGRESS_UPERF2.md)

Round 2 LANDED and MERGED (a450b1f): **A** = descents (pads never
materialized, five-table round kernel, deterministic threads: prove
2.07x at 1T, 6.6-7.2x at 8T on the depth-20 bench, RSS -33%) and **C**
= eval-proof leftovers (fold NTT 4-6x, transport 3.4x, psi 3x, and the
FINDING that the Goldilocks NTT was branchy — branchless primitives
1.5/2.07 us per transform now carry every kernel). Real data reached
the WSL box (checkpoint + val shard -> `results/m125_ffn_export_wsl/`),
so the 3x16 full-statement rig runs here: **oracle 682.8 s -> 43.7 s
at 1T (15.6x) -> 16.6 s at 8T (41x), verify 1.9 s at 8T, every digest
identical** (U_PERF_WAVE_REPORT.md 4.2). Round 3 lanes **D** (claim
layer + commit phase threading) and **E** (descent callers on lane
A's drop-ins, descent VERIFY attribution, small-cols aux tensors) are
LANDED and MERGED too (4dcaea6): claim layer 3.5x/11x, chain GEMM
10x, tree callers streamed, small-cols aux K-rows 42x, parallel CRS
XOF; real-data batteries green. **3x16 now: 30.6 s at 1T (22x), 9.9 s
at 8T (69x); 12x64 at 8T: 46.0 s, 12.2 GiB RSS.** Round 4 lanes **F**
(memory diet — w0 compact, phi never materialized; the 12x512 rig on
the 15 GB box) and **G** (descents round 2: fold/extract fusion,
arena, thread scaling) LANDED too (d38e9ce): RSS 3x16 2.9 -> 0.96
GB, 12x64 12.2 -> 4.0 GB; **12x128 runs here now: 58.3 s at 8T, 6.4
GB**; descents -29% more. Round 5 lanes **H** (descent tree layer
checkpointing + pool — the last blocker for 12x512 on the 15 GB box)
and **I** (SIMD Goldilocks NTT) LANDED too (a087a7d, 96559ee): SIMD
transform 2.2-3x; descent trees checkpointed/released/compact — and
**THE PoC SHAPE RAN ON THE 15 GB REFERENCE BOX: 12x512 full statement,
8 threads, 155.6 s wall (commit 11.7 / prove 134.9 / verify 7.3), 1.51
MB artifact, 10.98 GB RSS, accept** (U_PERF_WAVE_REPORT.md 4.2). 3x16:
25.0 s at 1T / 8.5 s at 8T (80x vs the same-box oracle). A 20-run
p50/p95 series at 12x512 DONE (4.3: p50 153.1 / p95 155.9 s at 8T).
Round 6 LANDED (34a8eb8, c210ea9): AVX2 K-field kernels (J) and **the
GPU rung step 1 (K: `--features gpu-cuda`, `ZK_GPU=1`, RTX 4070 Laptop
via WSL2, bit-identical, 8-10x on the ported GEMM)** — **12x512 now
106.8 s CPU-only / 85.0 s with the GPU at 8 threads** (report 4.2).
Round 7 LANDED (100a41c, f90a438): psi0 + leftovers (M) and the descent
round / ixf on the device (L) — **12x512: 96.7 s CPU-only / 60.2 s
with the GPU at 8 threads; verify 2.6 s; 3x16 4.5 s.**
Round 8 LANDED (109b879, 96bac25): the descent tree device-resident
end to end (N) and the claim layer's table pool + device-built
zero-check tables on a device-resident chain (O; the GEMM u32-limb
form was measured and refuted) — **12x512: 34.1 s with the GPU at 8
threads (commit 5.0 / prove 24.9 / verify 2.6), peak RSS 6.7 GB; 86.1
s CPU-only; 12x128 15.6 s; 3x16 4.3 s; every digest identical.**
Round 9 LANDED (214ebc5 + the Q merge): the descent kernels' floor
(P: one launch per round, device eq, slab allocator — the kernels
themselves are at 70-88% of the K-mult ceiling on this part) and the
prover's CPU-side blocks (Q: level-h device session, one combine
kernel family, int8 chain GEMM on device, mask/shift digits, 4-lane
SHA-NI CRS) — **12x512: 21.0 s with the GPU at 8 threads (commit 2.5 /
prove 15.5 / verify 1.7; three QUIET runs 21.0/21.1/20.9), 6.7 GB;
81.5 s CPU-only; 12x128 10.5 s; 3x16 3.4 s; every digest identical.**
THE KERNEL CURVE HAS FLATTENED (what is left sums to ~3-4 s): the
next step is a ruling — PROGRESS_UPERF2.md "Decision memo
(orchestrator, 2026-08-18)": (1) the lattice line's protocol change
(T11: a batched sumcheck-class opening layer; design memo first),
(2) the hash-based/float-mix channel as a comparison prototype,
(3) a Metal port for the M3 Ultra as the named GPU. Grok-shaped
work is (3) once the kernel set is frozen, plus T1.
Honest position: 34 s is a 12x512 slice of the 125M FFN on a laptop
GPU; the 8B contract shape is ~30-100x the work on a ~4-6x part [MODEL]
(3-14 min) — "minutes on one desktop GPU" is the honest projection for
this protocol; 5-15 s needs T11's design items or the float/int-mix route.

**RULING 2026-08-18 (Victor): route (1) — the lattice line, to a
COMPLETE 8B FFN MVP (minutes accepted), the route-1 protocol work
alongside, a creative search for the headline within the line; the
float/int-mix channel documented, not started
(PROVING_CHANNEL_OPTIONS.md). Tranche U-PERF3 (PROGRESS_UPERF3.md):
lanes R (8B scaling memo + MVP plan + the 7B/8B export scripts), S
(spike S1/S2 of the Stage-A protocol change), T (headline routes memo).**

**U-PERF3 round 1 LANDED (2026-08-23, merged to main):** lane R —
`U_PERF3_MVP8B_SCALING.md` complete (counted 8B sizes; the W-1..W-11
what-breaks table; 32x512 needs the W-8(a) memory fix even on the
Mac's 256 GB, ~184 GB peak with it; honest Mac CPU walls [MODEL]
~15-30 min at 32x16, ~35-75 min at 32x512; plan M0-M8) + the m8b
scripts, validated on the 125M ckpt byte-identically (36/36 weight
digests, 108/108 exponents, 12/12 verify checks). Lane S — spike
S1/S2 both **GO** (`U_PERF3_SPIKE_REPORT.md`: S1 9-25x
K-mult-equivalents / 12-16x rounds / 45-55x wire vs the masked
descent at 2^20; S2 claims equal bit-for-bit vs the descent oracle,
rounds 274->20; battery 48 legs byte-identical at 1/2/7T; caveat:
the prototype E_c kernel is ~8x off the K9 kernel's quality — the
counted win needs a production kernel). Lane T —
`U_PERF3_HEADLINE_ROUTES.md`: ranked recommendation for the second
design freeze = the opening re-architecture (Stage A + one-point
front end + two-tier sqrt serving + weight-group preprocessing; 8B
~20-40 s one desktop board, ~6-13 s four [MODEL]; verifier
sub-second 1T), then the route-3 board port; folding deferred to
MVP-2 as the memory tranche; de-risking spike **S4** named (2-4
days, no freeze move). AWAITING VICTOR: the T12 download go, the
S4/round-2 ruling, Mistral-vs-Llama naming (memo §5.1).

**Grok (Mac) — the RUN queue (ORDER PER SECTION 0: T13 -> T1 -> T4
-> T12 -> T14; T13/T14 are in Section 3 above):**
1. **T1 (still open, still valuable):** `uperf-pc full-profile 12 512`
   at ZK_THREADS 1, 8, 16 (and one `ZK_UPERF_ORACLE=1` run); digests
   must match the WSL box's (statement 2f8a92f8… / EVAL 4c259008…);
   record walls + phase table + `/usr/bin/time -l` peak RSS. This is
   the [MAC-BOX] row of the PoC shape and the Mac is where the 8B MVP
   will run CPU-only (256 GB). Walls are NOISY-SHARED while F2
   trains — label them; the digest identity is the load-bearing part.
2. **T4 (open):** the rig gates at HEAD on the Mac — full
   `freeze-check` exit 0 (incl. the BF rows), `pass-agg seam` 12/12,
   `pass-agg battery` 14/14 (~70 min), `table-descent prove 12 512
   p0`, the python suite green. Independent of everything else and
   nobody has run the full-statement rig on the Mac at HEAD.
3. **T12 — AMENDED 2026-08-24 after the WSL validation run
   (PROGRESS_UPERF3.md "T12 WSL validation pass"): the checkpoint
   DOES NOT CALIBRATE under the spec as written** (14,531 held-out
   range-fact violations, +8.18 nats through the int8 chain;
   weights-only +0.08 — emergent activation outliers, the known
   >= 7B phenomenon). Therefore: steps 1-4 of memo §5.2 (download,
   decode gate — now the gold prompt, calibration) are STILL ON as
   a digest cross-check: the calibration JSON's exponent table,
   silu-member list, violation counts and verdict must MATCH
   results/m8b_int8_calibration_wsl.json (committed). **The EXPORT
   (steps 5-6) is GATED on Victor's spec ruling** — its 0-violations
   assert will fail by design; do not run it, that is not a bug.

## 5. Log (append-only, newest last)

- 2026-08-17: board opened by Claude after the status recalculation
  (PROGRESS_UPERF.md 2026-08-17 section). T2 started by Claude on the
  WSL box; T1 is the first MAC task.
- 2026-08-17 (later): T2, T3, T5, T8b, T6(kernels) LANDED on the WSL
  box with their battery legs (`uperf-pc diff-battery`: O1 4/4, O2
  35/35, O3 63/63, O5 12/12, E2E 2/2 — the last is the whole
  bg_prove_group + bg_verify_group on a synthetic mixed-tensor group
  with a forced 2-level schedule, proven under oracle AND fast routing
  in one process: proofs field-identical, both verify), freeze-check
  rows identical to the pre-change baseline, `agg-matmul battery` +
  `bh-verifier battery` green (also at ZK_THREADS=7). Kernel benches
  [WSL 1T]: level-h 21.8x, matvec 8.0x, kernel passes 42.6x / 51.5x,
  all byte-identical; 20T level-h 6.6x more. Commits 353a75d, 31e8840,
  213dfa2 (pushed to main + perf/zk-batch-optimizations).
  NEXT for the MAC (Grok): T1 — one binary, `ZK_UPERF_ORACLE=1` for the
  before, plain for the after; `full-profile 3 16` first (digests must
  match), then `12 512`.
- 2026-08-18 (Claude, WSL): rounds 4-8 of U-PERF2 landed (see 4b) — the
  PoC shape 12x512 is 34.1 s with the reference box's laptop GPU at 8
  threads (155.6 s at the status recalculation), 6.7 GB, byte-identical.
  Round 9 launched (P descent kernels, Q prove-group/commit/CRS/
  transport). Grok/Mac: T1 stands (`uperf-pc full-profile 12 512` at
  ZK_THREADS 1/8/16 + one `ZK_UPERF_ORACLE=1` run, digests must match).
- 2026-08-18 (later): round 9 landed — 12x512 8T+GPU 21.0 s QUIET (x3),
  CPU-only 81.5 s, digests identical; the kernel curve has flattened;
  decision memo written for Victor (PROGRESS_UPERF2.md). Nothing new
  for Grok until the ruling except T1 and the Metal-port question.
- 2026-08-18 (ruling): Victor chose route (1). U-PERF3 opened; T12 (the
  8B export on the Mac) added as the next Grok RUN task, gated on lane
  R's scripts; T1 unchanged.
- 2026-08-23 (Claude, WSL): status check — nothing pushed from the Mac
  since the ruling (T1 unrecorded, §4 baseline table still empty; T12
  was legitimately blocked on lane R). The 2026-08-18 session had died
  ~25 min into round 1 leaving lanes R/S/T stalled with uncommitted
  work in their worktrees; all three resumed, completed, and MERGED
  (see §4b round-1 block). Gates on the merged tree: diff-battery
  green, uperf-s battery 48 legs digest 3752cba4…, freeze-check WSL
  form (98 rows ok, expected BF panic). T12 moved into §3 with exact
  commands and UNBLOCKED (pending Victor's download go); Grok queue
  now T1 -> T4 -> T12.
- 2026-08-24 (Victor, console): T12 download APPROVED ("Go ahead with
  the mistral download"). Claude/WSL starts the same pipeline here as
  a VALIDATION pass (829 GB free disk; the scripts stream < 4 GB RSS):
  download -> decode gate -> calibration -> export into a WSL-labeled
  directory (results/m8b_ffn_export_wsl). Purpose: answer W-6/W-7
  (SiLU member, remainder widths) and memo §4.3's real-7B untested
  items TODAY, and give the Mac run a weight-digest/exponent
  cross-check; it ALSO dissolves memo §5.1 decision (4) (Mac->WSL
  export-slice transport) — the WSL box can cut its own 1x16 dev-rung
  slices from a local export. The Mac T12 remains the digest
  authority for the 8B rig's witness.
