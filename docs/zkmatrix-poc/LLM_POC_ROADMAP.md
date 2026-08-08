# The ZK-of-LLM PoC Roadmap — From the Closed Design Trench to a Proven Pass

Status: roadmap, written 2026-08-08 on Victor's console ask ("next
steps to complete a proof of concept for the zk proofs of LLMs").
This page consolidates what is otherwise spread across the tranche
ledgers: what exists, what the PoC is, and the ordered path between
them. It invents nothing: every obligation below is a citation into
PROGRESS_UAG4.md's FINAL, TARGET_CONTRACT.md (+ Amendment A1), or the
aggregation design docs. Companion ledger: PROGRESS_UAGB1.md (the
build round this roadmap frames).

## 1. What "PoC-complete" means (proposed, checkable)

The contract's headline (TARGET_CONTRACT.md: 5-15 s, 8B-class, one
consumer GPU) is the DESTINATION, not the PoC. The PoC is the first
end-to-end artifact a skeptic can run, on a REAL model, with the ZK
property Victor made non-negotiable. Proposed definition:

> **PoC-COMPLETE when:** one 12-layer FFN pass of the frugal-lm 125M
> model (real trained weights, shapes 768 -> 2048 SwiGLU, layer count
> per `frugal-lm/configs/125m.yaml`) is proven under ONE statement on
> the CPU reference box, in mode P2 (weights private, masked; inputs
> public) on the W-C two-proof layout, with:
> (a) the serialized aggregate artifact within the scaled Tier Z
>     budget class (pass number derived at 125M shapes by the build
>     round — the frozen 1,114,112 B is the 7B-reference P3 number;
>     the 125M P2 figure must be derived, not assumed [MODEL]);
> (b) verification <= 2 s single-threaded (contract line, unchanged);
> (c) the AZB battery green, including AZB-10 (IXF group-map F5 pair)
>     and AZB-11 (weight-independence canary);
> (d) prover wall-clock measured and reported p50/p95 — measured, not
>     targeted: the 5-15 s line belongs to the GPU rung, not the PoC.

Scope honesty, carried on every artifact: FFN pass only — attention,
softmax, RMSNorm, RoPE, residual, embedding are NOT in the statement
(not yet integer-specified; TARGET_CONTRACT Section 1). The PoC
proves the pass the design trench priced, on a real model, at real
weights — no more, and labeled as such.

Why the 125M rung first (PROGRESS_UAG4.md FINAL item 5): real trained
weights exist locally (frugal-lm, MLX, Mac Studio); the shapes are
6-14x smaller per matmul than the 7B reference (512x768x2048 vs
512x4096x11008), so every engineering wall is met at friendlier
scale; and the same shape family serves the provenance pillar's
detector (Section 6). Reference 7B-surrogate shapes stay in the
ledger as the contract anchor.

## 2. Where the trench stands (designed vs built)

Designed and CLOSED (U-AG -> U-AG2 -> U-AG3 -> U-AG4, every O-item
settled; PROGRESS_UAG4.md FINAL 2026-08-06):

- Fold: IXF flat-32 (5 layer-index MLE variables, zero fold
  messages), W-C two-proof layout adopted; folded Tier N pass
  352,948 B act-only / 505,272 B W-C — 4.25x / 2.97x under the
  1,500,496 B honest floor.
- Privacy: fold/mask lemma holds (FP-L1/FP-L2); Amendment A1 Tier Z
  FROZEN at 1,114,112 B = 1.0625 MiB per 32-layer pass (P3/W-C);
  P2 = Tier N + 283,520 B = 788,792 B; P1-label 508,600 B; the
  ~8-day weight-recovery cliff is the recorded P2/P3 mask motivator.
- Soundness: extraction composes at our ring; knowledge error
  2^-220-class post-FS, 91.5-bit margin; folding costs ~0 bits.
- ALL pass-level byte numbers are [MODEL] until the build round
  measures a wire format (the design discipline says so on every
  table).

Built and measured (Rust engine, TARGET_CONTRACT Section 5 status
table, audits 2026-07-09..14):

- The committed activation-chain rig: range -> masked SiLU lookup ->
  Hadamard, adversarial battery green, at 1020-element row-block
  granularity. It proves NO matmul, no requantization edge, no
  residual binding, no model artifact (the H-03 honesty rename).
- Matmul claim proofs: largest full proof to date 128x256x64 — the
  full-shape claim layer is designed, unmeasured.
- Multi-layer chaining under one statement: NOT implemented
  (statement format exists; `statement-inventory` walks the DAG).
- Known engine walls: the q31 C2 wave cap (~2^17 elements per
  committed descent — the multi-wave lift is designed,
  RANGE_AGGREGATION_DESIGN.md Phase 5); the q46 range side at 96% of
  chain prove time; H-03 memory discipline. No GPU kernel exists.

The gap between those two lists IS the build round.

## 3. U-AG-B1 — the build round (the next steps, ordered)

Queue consolidated at the U-AG4 FINAL (PROGRESS_UAG4.md item 4),
grouped here into workable lanes; ledger: PROGRESS_UAGB1.md.

**BA — freeze-row + discipline lane (paper-to-code, low risk):**
R-EB1 (T_cap = 33 sampled-cap rule), R-EB2 (K-draw restructure),
R-EB3/R-EB4 (corrected floor bases e <= 7, kappa 11) as engine freeze
rows; R-FC2 per-group digit-headroom rows (the < 1-bit knife edges);
E-O1..E-O3 encoding obligations; Q4/SR transcriptions of the folding
lemmas (AFS-L0..L8 into the house lemma docs).

**BB — engine lane (the critical path):**
1. Exact-digit plumbing (F-N2 — load-bearing: the weight-group
   opening is infeasible without it).
2. The dense-encoding committed matmul STATEMENT at 125M layer shape
   (512x768x2048) — closing the "largest full proof 128x256x64" gap;
   C2 cap handled per the multi-wave design.
3. Multi-layer chaining: 12 layers under one statement (the DAG
   exists; the wiring does not).
4. IXF flat fold implemented (index-extension over the layer
   dimension; at 12 layers the index space pads to 16 — a B1 design
   note to settle against F-IF1, flagged, not assumed [MODEL]).
5. The masked evaluation-proof path (Tier Z): mask-then-fold per
   FP-L2, floor-mask sampler discipline F-Z3.
6. Wire format (the audit M-05 gap) — budgets bind on serialized
   bytes, so the canonical encoding is PoC-blocking, not cosmetic.

**BC — measurement + battery lane:**
F-O2 (measure kel(dw,dt) — the descent-size fit is a 4-point [MODEL]
today); F-O1/F-O3/F-O5; F-Z1 (masking corner re-check in build
schedules); F-Z2 (SC-L4 at the masked-floor response bound — Phase
2.5 review item with SC-L6); the AZB battery + AZB-10/AZB-11 legs;
O-5/O-6 models to measurement; Tier N per-layer gate 262,144 B (P0)
and the 2^20 rig Tier Z gate 576,056 B as the running checkpoints;
F-O4 stands: adopt the relaxed-e0 line BEFORE any 8B freeze (the 8B
weight-group headroom is 0.05 bits).

**Integration target (the PoC of Section 1):** import the frugal-lm
125M checkpoint (int8 quantization per the contract's Section 2
semantics — the calibration either passes the range facts or the
model is honestly unprovable, which is intended behavior), run the
12-layer P2 pass, measure, compare against the scaled budgets, brief.

Sequencing note: BA is mergeable immediately and independently; BB
items 1-3 are the critical path and are ordered (digits -> matmul
statement -> chaining -> fold -> mask); BC's F-O2/AZB legs unblock
the Tier Z freeze conditions (F-Z1/F-Z2/F-O2 are carried ON the
frozen A1 number). House pattern: worktree lanes, spikes stay green,
freeze rows both directions, [NOISY-SHARED] timing hygiene, quiesced
reconciliation before any ladder-grade number.

## 4. After B1 — the remaining ladder to the contract headline

In contract order, none of it PoC-blocking:

1. Attention/softmax/RMSNorm/RoPE integer specifications (the
   contract's declared 8B gap) — design round of its own; softmax is
   the hard row (no frozen integer spec exists).
2. The 7B-surrogate full-shape pass at reference dims (the frozen
   TARGET_CONTRACT boundary), then the 8B target with F-O4's
   relaxed-e0 line adopted first.
3. The GPU rung — no kernel exists; every GPU number is [ASSUMED];
   the 5-15 s headline is CONDITIONAL on it (codex-gpu-readiness
   verdict: GO on prototyping, NO-GO on claims).
4. The q46 range wall (96% of chain prove time today): the
   RANGE_AGGREGATION_DESIGN Phase-5 range-lookup rung is the priced
   lever.
5. External estimator re-validation at any parameter move (house
   rule; ESTIMATOR_NOTE.md).

## 5. Risks, ranked (what would move the schedule)

1. Matmul claims at scale are UNMEASURED in the engine — the single
   largest built-vs-designed gap; everything else composes around it
   (mitigation: it is BB item 2, first on the critical path after
   digits).
2. The frozen Tier Z number is [MODEL] until the wire format exists;
   freeze conditions F-Z1/F-Z2/F-O2 are open build obligations — a
   miss reopens the A1 line (the freeze anticipates this: conditions
   are carried, not hidden).
3. The C2 cap lift (multi-wave) is designed but unbuilt; it gates
   full-shape single-statement instances.
4. q46 range dominance caps CPU prover wall-clock regardless of
   aggregation wins (known lever on file, Phase 5).
5. Quantization reality of the 125M checkpoint: if calibration fails
   the range facts, the PoC needs a quantization-aware pass first
   (frugal-lm side work, not proof-system work).

## 6. The provenance tie-in (why the two PoCs converge)

docs/provenance/MUSIC_PROVENANCE_POC.md Section 5.4: the music
pillar's laundering-screen classifier is planned as a small
transformer trained in the frugal-lm stack — the same shape family as
this roadmap's integration rung — and its deployment needs exactly
this PoC's statement ("certified detector, committed weights, scored
s on committed audio", P2 mode). The music pillar's edit chain also
consumes the same gadget classes (matmul, Hadamard, lookup, range)
with no additions. One build round therefore feeds both pillars, and
the detector is the natural candidate for the SECOND real model the
engine proves, after (or alongside) the 125M LM rung.
