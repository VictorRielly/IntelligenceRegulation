# Next protocol candidates, compared with the current line (first version, 2026-11-16)

Kept under D80 (Victor, 2026-11-16): explore later, more efficient protocol versions beside the Lean proofs of the
current one, compare them from time to time, and decide whether one is clearly better. This is a paper study by Claude
(co-coordinator). Nothing was built, run or proved for it. Two helper scripts, standard library only, read-only:
`results/zk60_claude_review_20261116/next_protocol/candidate_volume.py` (volume arithmetic) and `lean_families.py`
(Lean line counts). D63, P1, the approved statements and every proof lane stand as they are (D80).

**Labels.** COUNTED: read from code or a recorded output (file given). MEASURED: a recorded run in this repository.
DERIVED: my arithmetic, shown here or in the scripts. AUTHORS: another system's own figure, with its source; never ours.
ASSUMED: a number I chose. ARGUED: a reasoned judgement with no count or proof behind it.

**Internal labels used below.** W16R2: the profile the code runs today (16-bit range words, rate 1/2, 280 opened
columns). W16R3: the next profile, ruled in D67/D78 (B1-B3 plus the Lean-found savings C1, C2, C3, C5, C7 and a token
I/O profile). R13: the older profile the media classifier's Lean theorems are stated at. A, H, M: the three
commitments of a block (A: activations and range limbs; H: the LogUp helper columns; M: the small masking table).
LogUp: the lookup argument; a "helper" is a committed column of inverses it needs. GKR: a layered sumcheck protocol
that lets a lookup run with no helper columns. D55: the fork-join schedule that proves the 32 blocks of one request in
parallel. P1: the decided privacy scope (input, output and every intermediate value hidden; weights public).

## 1. In plain words

- **Candidates.** A: stop committing the lookup helper columns (half of today's data). B: A, plus three small numbers
  per field word, minus values a relation already fixes. C: B on a 31-bit field. D: FlashProve's design, changed to hide
  our input and output instead of the weights. E: exact integer GPU kernels; no proof byte changes.
- **Best today: A, then B on top of it.** A halves the committed data and keeps the field, commitment and most Lean;
  B would reach about a quarter, near FlashProve's own figure. E goes ahead regardless. C is worse than A. D is where
  A+B lead, with a working published system behind it, but for a different hidden set and a new prover.
- **How sure: low to moderate.** Nothing is built on even one 8B block; A's speed gain is modest (x1.07-1.25, older
  estimate) because volume is not today's bottleneck; A's zero knowledge is an unreviewed local design.
- **Update 2026-11-17, from the measured profile (section 6, rows under A, B and E).** On the Mac, on the current
  build, A's gross ceiling is about x1.2 on a block and x1.1 to x1.3 on the stream, and its own cost is of the
  same size; B adds at most about x1.05; E's products are worth x1.01 to x1.02 and its fold has no kernel. No
  candidate reaches x1.5 here, so no prototype is started. The measured targets are the host's 65% share of a
  block and the witness pass, a third of a request. The ranking above still holds for committed volume and
  memory, and it may differ on the RTX 5090.
- **Abandon nothing before** a full 8B block prototype with word-for-word outputs and a measured factor on the same
  machine, a reviewed zero-knowledge argument for P1, and a costed Lean re-proof (section 5). About 24% of today's Lean
  carries to A and B unchanged and about 71% is redone in the same pattern (section 4).

## 2. The baseline: the current line

| Quantity | W16R2 today | W16R3 as ruled | Label and source |
|---|---:|---:|---|
| Committed rows per 8B block (rows of 2^14 words, A + H) | 5,103 | 4,859 (B1-B3); about 4,290 with C1-C5, C7 | COUNTED (cycle 4 census, `census.log:218-237`); W16R3 MODEL (`model.py:246`); the -11.7% is an ESTIMATE (D78), applied multiplicatively (ASSUMED) |
| Committed message words per token per layer | 653 k | 622 k; about 549 k | DERIVED: rows x 16,384 / 128 |
| Shares of a W16R2 block | activations 19.3%, range and remainder limbs 24.9%, LogUp helpers 49.3%, masks 6.1%, tables 0.5% | about the same | COUNTED (cycle 4 §1.2) |
| Codeword bytes per 8B T128 request (rate 1/2) | 43.19 GB | 41.1 GB; about 36.4 GB | COUNTED rows, DERIVED bytes (cycle 4 §1.3; `candidate_volume.py`) |
| Plain int8 forward pass, same request, bytes moved | 7.9-9.0 GB | same | DERIVED (cycle 4 §3) |
| Receipt per request | 818,728,672 B | about 767 MB before the smaller changes | MEASURED (`a12merge_d55.log:233`); W16R3 MODEL (`W16R3_DESIGN_B1_B3_20261105.md:92`) |
| Proved tokens/s, 8B T128, M3 Ultra, production stream of 4, steady | 32.4-32.6 | not built | MEASURED (`MVP_STATUS.md:366`), synthetic diagonal public weights, not dense trained weights |
| One request, production path | 18.3-18.8 tok/s (6.82-6.98 s) | not built | MEASURED (`MVP_STATUS.md:365`) |
| Expected W16R3 device gain | | x1.08-1.19 on the forks wall | MODEL (`W16R3_DESIGN_B1_B3_20261105.md:40-44`) |
| GPU busy in the forks phase | 53-59% | | MEASURED (A7, `MVP_STATUS.md:376-378`): the prover is not GPU-bound |
| Soundness, union count | 2^-97.78 (8B T128, Q = 280) | recount pending | COUNTED (D59) |
| Soundness, Lean path-wise | query-free floor 155/2^110 = 2^-102.72; meets q·2^-100 + 2^-100 for q ≤ 2^75 | re-proof needed | PROVED given the zone premises (D66; `FSPathBlock.lean`) |
| Zero knowledge | per-part lemmas PROVED (opened columns, M, masked sumcheck, salted Merkle, one block with a stand-in simulator); the run-level theorem (O12) open | re-gate needed | `formal/README.md`; MVP_STATUS gap list |
| What leaks | T, d, layer count, served or refused; for the classifier its verdict | same | approved statements as amended (D76) |

The committed-volume floor (write once, hash once) is 1.2-2.5% of the measured Mac request (cycle 4 §4). Cutting
volume therefore helps the prover only through the phases that scale with rows: on the 2026-10-31 instrumented warm
block, committing A and H took 0.096 s of 0.578 s, and the helper path about 0.110 s (MEASURED and ESTIMATE,
`20261101-logup-gkr-w16.md` §1-2; before the Phase A work). Every speed expectation below is bounded by that.

## 3. The candidates

Each candidate is described against W16R2. Every one except E changes the receipt and the verifier, so each needs a
ruling, a new profile string (D17), a privacy re-gate and a Lean re-proof (D63).

### A. Helper-free lookups (masked LogUp-GKR, or a masked product-tree lookup as in FlashProve)

**What changes.** The H commitment loses its helper columns. Lookups are proved by a GKR tree of fractional sums
(LogUp-GKR) or of products (FlashProve's form, which commits the multiplicities as 32 bit-planes per table entry).
The domain zero-checks lose their helper terms and gain one linear "leaf claim" share per domain
(`research/zkp-efficiency/experiments/logup-gkr-20261101/ZK_DESIGN_NOTE.md` §3). The receipt loses the H opened
columns and claim groups and gains about 300 GKR rounds: net about -5.0 to -5.2 MB per block (COUNTED there, §4). The
verifier runs the GKR rounds and checks the root denominator is nonzero. The field, the commitment, the openings, the
D55 schedule and the integer model are unchanged.

**Volume** (DERIVED, `candidate_volume.py`, from cycle 6a §2):

| Variant | Rows per block | Words per token-layer | Codewords per request |
|---|---:|---:|---:|
| G1: range and table helpers retired (5,103 - 2,162 - 30) | 2,911 | 373 k | 24.9 GB |
| G2: every lookup in the tree, H keeps only the zero-sum pair (- 320 exp/act rows) | 2,591 | 332 k | 22.2 GB |
| G3: G2 and 82 H mask rows go with their planes (ASSUMED) | 2,509 | 321 k | 21.5 GB |
| A2: G3 with FlashProve's bit-plane multiplicities, one lookup argument per block (ASSUMED) | 2,974 | 381 k | 25.4 GB |

The M table grows by 48 to 144 rows of 4,096 words (0.05-0.15 GB per request). The bit-plane form costs 32 words per
table entry against LogUp's one (tick 3 §3); it only pays if one lookup argument spans many layers.

**Prover time.** x1.07-1.25 per block on Metal with H retired (ESTIMATE, `20261101-logup-gkr-w16.md` §1, made before
the Phase A work, and with the GKR proving at 0.160 s per 2^25 leaves on 32 CPU threads, MEASURED there). The CPU
prototype's GKR scales poorly with threads (x8.7 at 32 threads against x16.5 for the commit, MEASURED there). No GPU GKR
exists here. On the 5090 the host residue, not the volume, is the modelled cap (same note §2).

**Soundness** (DERIVED, cycle 6a §0 and the design note §5.7). The LogUp term (N + T)/|Fp2| is about 2^-103 per
block, the same term today's LogUp pays; the GKR sumchecks add about Σ_k (3(k - 1) + 7)/|Fp2| = 996/2^128 ≈ 2^-118 per
block. Today's largest round is LogUp's α at 135/2^110 (`FSComposeBlock.lean`, `Kind8B.eps_le`), so the block zone
should stay near 2^-102.7 (ARGUED). tessera's two-tree forest doubles the LogUp term (one bit). The path-wise proof
of D66 must be redone with the GKR rounds in the zone.

**Hiding.** Two routes, different status.
- Masked LogUp-GKR: a **local design only** (`ZK_DESIGN_NOTE.md`, unreviewed): blinding leaves for the root, Libra
  masks over the parent coordinates, CFS masks on round messages. Its open items: a joint-view simulator over 25 masked
  layers, the split leaf claim, the blinding scalars in a public-coefficient check (tick 1 §3). tessera's RFC-0032
  rejects blinding leaves for reasons not read (tick 1 §2). No published hidden-activation LogUp-GKR found.
- Masked product-tree lookup: **published and machine-checked inside FlashProve** (Lean zero knowledge for one
  request per proof, exact match, ≤ 2^64 queries, AUTHORS: `upstream/lean/THEOREM.md:20-24`). FlashProve hides weights and
  intermediates, not the prompt and reply, and its lookups run inside its own protocol; the theorem does not transfer
  as a statement, only as a construction and a proof pattern (ARGUED).

**P1.** Meets P1 if the zero-knowledge argument holds; nothing is published. **Engineering.** A CPU prototype of the
streamed LogUp-GKR prover and verifier exists (112 checks, `experiments/logup-gkr-20261101/`). Still to build: masks,
a Metal kernel for the bottom layers, the new slot schedule, the leaf-claim shares, the stages' byte lookups, a new
profile; about 6-10 lane-weeks of code plus a zero-knowledge review (ESTIMATE). **Code that survives:** field, NTT,
commitment, Merkle, transcript, sumcheck engine, witness builder, D55, openings; replaced: helper writing, the H
commitment, the helper terms of the zero-checks and of the stages.

### B. A, plus three small cells per field word with a smallness test, plus not committing determined planes

**What changes.** On top of A (B needs A: packing does not touch the helpers, which are full-field values):
- **Determined planes.** 424 of the 2,279 A data rows per block are fixed pointwise by other committed planes: the
  residual sums X1, X2 and the RoPE remainders (linear), the single-limb remainders SR, SG, RH (degree 2), the norm
  remainders' top limbs (COUNTED, cycle 6c §1, `slot_ir_accuracy.rs` clauses). The lookup then queries the expression.
- **Packing.** FlashProve stores "three cell rows 3i, 3i + 1, 3i + 2 of a column [as] one element of F, with the radix
  2^20", its cells are byte-scale digits (remainders split into low and high byte; q, k, v, o in two limbs), and a
  request is accepted only for cells below a relaxed bound 2^18 (AUTHORS, `docs/format/11-1-machinery.md`, read via
  tick 3 and two fetches today). A ternary **smallness test** (random combinations with entries in {-1, 0, 1}, split
  into a 10-bit and an 8-bit digit and looked up) keeps the packed slots from wrapping. Exact ranges stay as lookups.
  So to pack, our 16-bit words and limbs become byte cells first, and our exact word classes are still checked by
  lookups; nothing here is B4 (D67 refused probabilistic range checks that replace the exact W16 word checks).
- **The open mechanism.** FlashProve's own format gives the weight of cell row i in a claim as
  `rw(floor(i/3)) · 2^(20·(i mod 3))`: claims see a packed row only through the radix powers (AUTHORS, 11-1, fetched
  today). How a sumcheck's claim on one cell row is then checked against packed words is in its §13.9 and source,
  which I have not read. Cycle 6b's argument (an opening of a packed word gives one linear combination of three
  unknowns) stands until that is read. **B's volume below is conditional on this mechanism.**
  **Read since (tick 5, later on 2026-11-16):** the mechanism exists and is not an opening; cycle 6b's objection is
  answered in its premise. FlashProve's verifier caps the row width at 8,191 columns, so the 16,384-column figure in
  the volume paragraph below understates the digit term (2·τ/k is 3.1% of unpacked cells at k = 8,191, 6.3% at
  4,096, against the 1.6% used). The table below is not recomputed; see the status line under B in section 6.

**Volume** (DERIVED, `candidate_volume.py`): start from G3 (2,509 rows); drop the 424 determined rows; re-express the
remaining 1,855 data rows as byte cells at 1.5-2.0 bytes per value (ASSUMED: most planes are int16 words or 16-bit
windows, some int8, a few 24-bit); pack three per word; add the smallness digits (2 x 128 words per cell row of 16,384
columns, 1.6%); keep the 222 A site-mask rows.

| | Rows per block | Words per token-layer | Codewords per request | Against plain int8 bytes |
|---|---:|---:|---:|---:|
| B, 1.5 bytes per value | 1,201 | 154 k | 10.5 GB | 1.2-1.3x |
| B, 2.0 bytes per value | 1,525 | 195 k | 13.2 GB | 1.5-1.7x |
| FlashProve, per token per layer, for comparison | | 140-250 k | | AUTHORS-based DERIVED (tick 3 §3), its model, not ours |

The agreement with FlashProve's range is a sanity check, not a confirmation. At our row width the smallness test's
completeness holds for byte cells (a ±1 combination of 16,384 bytes has a spread near 2^13.5 against the ±2^17
window, DERIVED) and fails for 16-bit cells; that is why the cells must be bytes.

**Prover time.** The commit phase (0.096 s of a 0.578 s warm block, MEASURED 2026-10-31) falls with the rows, about
-0.07 s per block, so x1.1-1.2 beyond A from volume (ESTIMATE). Sumcheck work over byte cells may grow, because there
are more cells than today's values; unknown. Combined with A: x1.2-1.5 per block on Metal (ESTIMATE, wide).

**Soundness.** A's terms, plus the smallness test: per cell with |cell| ≥ 2^18 each ternary column catches it with
probability at least 1/2, so 2^-τ per cell; FlashProve's own union over its tested columns reaches only 113.44 bits at
its parameters (AUTHORS via tick 3 §1, paper Remark G.2). For our 2^-100 budget τ = 128 leaves room (ARGUED). Raising
the lookup degree for determined planes adds one degree per helper clause (cycle 6c §1). Packing must be shown
injective under the relaxed bound (2^18 cells in 2^20 slots; ARGUED).

**Hiding.** Pads and masks are per row and do not care what the words encode (cycle 6b §2), so the opened-column lemmas
carry (ARGUED). A determined plane is never opened; its clause's mask degree rises by one (cycle 6c §2, unverified).
The smallness digits are hidden values like any other and need masking and a place in the simulator. Status: **local
design to be written**; FlashProve's machine-checked argument covers its packed trace (AUTHORS), for its hidden set.

**P1.** Yes, if the argument holds. **Engineering.** Every plane list, witness writer, pad rule and range family
changes; the smallness test is new: about 3-6 months of lane work on top of A (ESTIMATE). **Code that survives:** as A,
minus the layout, plane lists and witness layout.

### C. B on a 31-bit prime field with an extension

**What changes.** Every committed word is 4 bytes; challenges come from a degree-4 extension. D56's study counted the
cost: fifteen relations of the W16 block exceed 2^31 (2^37 to 2^49.8), and the cheapest exact fix carries every wide
matmul accumulator as digits and carries: A x2.5 elements, lookups x2.6, helpers x4.5 elements (ESTIMATE,
`results/zk60_metal_20261031/D56_FIELD_SWITCH_STUDY.md` §0-2.3).

**Volume** (DERIVED from D56's ESTIMATE, H retired as in A): about 104.3 M 31-bit elements per block, 815 k words
(3.3 MB) per token-layer against 653 k words (5.2 MB) today; about 27.1 GB of codewords per request. That is **more
than A alone** (21.5 GB). Packing does not rescue it: a 31-bit word has room for three 10-bit slots at most, and the
smallness test's honest combinations (about 2^16.7 at 16,384 columns of bytes) do not fit such slots (DERIVED; ARGUED
that no packing remains).

**Prover time.** D56's model: 0.19-0.29 s per block with LogUp-GKR, against 0.14-0.17 s for Goldilocks with LogUp-GKR
(MODEL). Slower. **Soundness.** LogUp in a degree-4 extension worsens the whole-run term to about 2^-92.2 with
committed helpers (COMPUTED in D56 §0.4); with GKR the lookup challenges can come from a larger field. Small-field
codes must be argued in the unique-decoding regime (Fenzi-Sanso, cycle 6b). **Hiding.** Re-derive every
Fp2-specific lemma (the base-row pair that hides one Fp2 vector becomes a 4-row group). **Engineering.** 17-33
lane-weeks for the field switch alone (D56 §4.1, ESTIMATE). **Verdict:** dominated by A; rank last.

### D. FlashProve's construction re-targeted to P1

FlashProve proves a public prompt and reply against committed hidden weights; intermediates are hidden; zero knowledge,
soundness and completeness are Lean-checked for one request per proof, exact match, at its own stored full-size files
(AUTHORS, `upstream/docs/protocol.md` §7-8, `guarantees.md`).

**What falls away when weights are public.** The weight table, the anchor and leaf copies, the link proofs, the
39-minute offline commitment, the opening budget (688,127 batches per leaf table) and its durable counters, the batch
tree and shared chain, the weight tables' OOD answers. The final claim g·M·e + μ = v on the weights becomes a claim the
verifier computes from public M (one pass over the 8B weights per request, as our verifier's weight folds already do,
ARGUED). Cycle 2 found FlashProve's batch curve is weight-streaming amortization (fixed part about 52 s per batch,
DERIVED from AUTHORS), so its 17 → 111 tok/s batch gain does not transfer.

**What must be added for P1.** (1) The prompt enters the first chain in the clear ("the request itself, byte for
byte", protocol.md §6.3): it must become an input commitment opened only by the owner, and the embedding a hidden
lookup into a public table (our stage IN). (2) The next token is "sent in the clear" and replies are public: the head
must prove the greedy choice over hidden logits into a hidden-output commitment (our stage OUT; the classifier's
verdict stays public, D40/D76). (3) The leakage becomes our D76 list; FlashProve's served/refused bit depends on the
weights and its hidden-set theorem must be re-stated with the input as the hidden data. (4) Our integer model and its
word classes stay exactly as approved (D67, D78); FlashProve's cells and tables must be fitted to them.

**Volume.** About B's (FlashProve: 140-250 k words per token-layer, tick 3 §3). Receipt: its fold-and-hop tower gives
18.78 MB per proof at a 1,024-token window (AUTHORS, cycle 5); our wide-row study models 40-52 MB per 8B request for
the same idea (B6b, `W16R3_DESIGN_B6_20261105.md` §0). **Prover time.** No basis to project for our model. FlashProve's
marginal is about 7.05 s per extra 1,024-token request on one H100 (DERIVED by cycle 2 from AUTHORS) for 16.15 B
active parameters; ours is 3.94 s per 128 tokens on the M3 Ultra (MEASURED). Hardware, model, window and hidden set
differ; neither figure says which construction is faster on our workload, and nothing here claims we are faster.
**Soundness.** Its Lean theorem: about q/2^124 + 2^-101 at its files (AUTHORS); its programs reach 128 bits per round
only by counting 20-32 bits of proof of work, 96.23 bits without (AUTHORS, protocol.md §6.4). A re-targeted version
needs its own count against our target. **Hiding.** Published and machine-checked for its hidden set; for P1, a
re-statement and re-proof. **Engineering.** A new prover: FlashProve's prover is CUDA for the H100 and cannot run on
the Mac; 6-12 months or more of lane work (ESTIMATE, unanchored). **Code that survives:** the integer model and witness,
the input and output stages' relations, BLAKE3 if kept (FlashProve uses BLAKE2b), parts of the sumcheck engine.

### E. Exact integer matrix-unit kernels for the witness forward pass and the folds

**What changes.** Nothing in the receipt, the verifier or the statements, if every output is the same field element
(byte-identical). This is the sound form of track G1: INT8 limbs, exact integer accumulation, carried recombination,
compared word for word with the production kernels (`GPU_FRIENDLY_REVIEW.md` §5). An exact Metal integer GEMM already
exists and is exact as written (same review, addendum A1-A3); it was self-checked on one 128-token input and its
timing scope excludes copies and conversions (A4-A5). **Volume:** unchanged (653 k words per token-layer).
**Prover time:** the sealing chain is 1.5-1.7 s per request (MEASURED, `MVP_STATUS.md:359`), already overlapped in the
stream; stream gain x1.00-1.15 on the Mac (ESTIMATE, cycle 2 M3, M6); on the 5090 the exact GPU forward is the
central lever of the 48-76 tok/s model (MODEL, `20261103-rtx5090-projection.md`). **Soundness and hiding:** unchanged.
**Lean:** unchanged; the tested premise "the integer model equals the code" (L1Check) is re-run on the new kernels.
E is not an alternative protocol: it carries over to every candidate.

### Also considered

- **F. Recursive openings (B6a, B6b).** Receipt 819 MB → 387 MB (B6a) or 40-52 MB (B6b); prover +2-6 ms (B6a) or +13 to
  +42 ms per block (B6b) (MODEL, B6 note §0). A size lever, not a speed lever; size work is shelved (2026-11-09). It is
  orthogonal to A and B and is half of what D would bring. It changes the commitment, the largest Lean change of all.
- **G. Rows committed in coefficient form (H117b; added 2026-11-19).** Today each commit runs an inverse transform
  on every row before the forward transform. Committing the rows as coefficients removes the inverse transform:
  8.3 ms per block at W16R2_8B and 14.5 ms at the older R13 Shieldstral block (label corrected 2026-11-20,
  research tick 27; the installed W16R2 Shieldstral block has the 8B block's commit time, measured that day,
  so its figure is the 8B one), about 9% of block GPU
  (DERIVED from diagnostic re-runs of
  the commit parts, research tick 21; block GPU taken as 91.46 and 174.25 ms, the 2026-11-17 breakdown's totals
  without its diagnostic records; a ceiling on block GPU, and at most x1.076 on the W16R2_8B stream cadence at
  full pass-through, research tick 22). It changes every commitment root
  and receipt byte (deferred for that reason on 2026-11-03, `DEFERRED.md` entry 1), so it belongs with a profile
  version that already changes the commitment (B, C or F), not on its own. Lean: the binding statements are about
  the code and the Merkle tree, not about which basis the prover holds the message in, so the expected change is
  to the Rust commit path and the fixtures; that is argued, not checked against the Lean files.
- **H. Not committing padded columns (a compact or "jagged" layout; added 2026-11-20).** Padded columns are
  committed and proved zero today. They are 304 of 5,103 rows per block at W16R2_8B (5.96%) and 1,376 rows at the
  Shieldstral profile (26.96%), because Shieldstral's width 3,072 and hidden size 9,216 sit in 4,096 and 16,384
  columns (DERIVED from the plane lists and `results/zk60_w16r2_20261101/ACCOUNTING.md`, research tick 26; the
  Shieldstral plane lists are inferred from equal row totals, not counted). Ceiling if every padded row left the
  commitment: 1.7 ms per block at W16R2_8B (at most 1.4% of the stream cadence). At the installed W16R2
  Shieldstral profile the block's commit time is the 8B block's (MEASURED 2026-11-20: 28.95 ms over ten warm
  passes, block GPU about 94 ms, `results/zk60_w16r2_shield_block_20261120/README.md`), so the ceiling is 7.8 ms
  per block, 4.6% of the measured stream cadence of 4.381 s per request (benchmark of 2026-11-13, older
  binary; range over the passes 4.3 to 5.3%; research tick 27 estimated 4.5 to 5.1%).
  (Corrected 2026-11-20: the first version of this entry gave 20.5 ms of 174.25 ms, 11.8%; that paired the
  W16R2 padded fraction with the commit time and block GPU of the older R13 Shieldstral block.) So it is a
  Shieldstral lever more than an 8B one, and at the 5% line, not clearly above it.
  It needs either a commitment over stacked columns (jagged commitments, ePrint 2025/917, read at abstract level
  only; zero knowledge and fit with a row code unknown) or a non-power-of-two code length; both change the
  commitment, the verifier and the pad rule's Lean statements, so it belongs with a profile version that already
  changes the commitment.
- **Not ranked:** a shared batch transcript (cycle 2 M2: x1.00-1.15, couples users' receipts, no Lean batch statement
  exists even in FlashProve); chained fork seeds (M5: latency only); Celer (pairing commitment, no zero knowledge,
  tick 2); Binius-family fields (break exact integer arithmetic, cycle 6b).

### Side-by-side

| | Today W16R2 | A (G3) | B | C | D | E |
|---|---|---|---|---|---|---|
| Words per token-layer | 653 k | 321 k | 154-195 k | 815 k 31-bit | ≈ B (AUTHORS-based) | 653 k |
| Codewords per request | 43.2 GB | 21.5 GB | 10.5-13.2 GB (conditional) | ≈ 27 GB | not derived | 43.2 GB |
| Prover expectation | 32.4 tok/s (MEASURED) | x1.07-1.25 (ESTIMATE) | x1.2-1.5 with A (ESTIMATE) | slower (MODEL) | unknown | x1.00-1.15 Mac; central on 5090 (MODEL) |
| Soundness vs 2^-100 | 2^-102.72 floor (PROVED, premises) | ≈ same (ARGUED) | ≈ same + smallness (ARGUED) | short without redesign (COMPUTED in D56) | its own 2^-101 (AUTHORS); recount | unchanged |
| Zero knowledge | parts PROVED, run open | local design / FlashProve's form machine-checked | local design to write | re-derive | machine-checked for weights; re-prove for P1 | unchanged |
| Meets P1 | yes, as designed | if ZK holds | if ZK holds | if ZK holds | after additions | yes |
| Size | | 6-10 lane-weeks + review | 3-6 months more | 4-8 months more | 6-12+ months | weeks |
| Ruling needed | | yes | yes | yes | yes | no |

## 4. The Lean reuse map

### 4.1 The development today, by family

COUNTED by `lean_families.py` over `formal/ZK60Formal/` (518 files, 192,740 lines on the main checkout, including the
untracked `RunBlkShieldInst.lean`; lane branches not merged are not counted). Families are assigned by file name; the
rule is in the script and is approximate at the edges.

| Family | Files | Lines | Share | What it holds |
|---|---:|---:|---:|---|
| F1 foundations: field, hash, transcript, Merkle, random oracle | 16 | 5,289 | 2.7% | Goldilocks prime, executable Fp and Fp2, BLAKE3, the transcript chain, Merkle binding and extraction, the oracle lemmas |
| F2 sumcheck, zero-check, Fiat-Shamir | 23 | 11,942 | 6.2% | sumcheck soundness and its executable verifier, round-by-round FS, composition, the D55 tree of chains, path-wise counts |
| F3 commitment, openings, M, binding | 40 | 13,960 | 7.2% | column test, δ/3 and δ/2 proximity (with 15 adapted FlashProve files, 2,580 lines), openings under FS, M's product test, binding |
| F4 LogUp and lookups | 44 | 10,966 | 5.7% | the LogUp identity (`SoundLogUp`, 292), the helper-column form (`SoundLogUpBlock`, 357), FS for LogUp, the block and R13 lookup covers |
| F5 block slots, layout, block verifier | 152 | 58,286 | 30.2% | the 23 W16R2 slots, the R13 slots (50 files, 17,047 lines name R13; 52 files, 19,783 lines name W16), layout maps, block extraction |
| F6 token stages | 45 | 19,955 | 10.4% | IN, IN-C, OUT, OUT-C: extraction, whole-stage soundness, executable stage verifiers, stage covers |
| F7 run chain, endpoints, bad-event budget, classify protocol | 141 | 50,552 | 26.2% | the run's transcript, alive and doom covers, endpoint extractors, opening geometry, the classify `Protocol` and its gates |
| F8 zero knowledge | 34 | 12,889 | 6.7% | generic hiding lemmas (12 files, 4,921 lines: `Hiding*`, `ZKHybrid`) and per-profile simulation (22 files, 7,968 lines) |
| F9 integer model and CircuitIff | 15 | 4,831 | 2.5% | `ModelInt`, `ModelOut`, the per-operation iff lemmas, `block_circuitIff`, `tokenRun_circuitIff` |
| F10 approved statements and assembly | 8 | 4,070 | 2.1% | `Statements.lean`, the D76 amendments, `Assembly`, `CompleteSub` |

Two facts frame the map. First, `Statements.lean` and the assembly are stated for an abstract profile, so they carry
over to any protocol. Second, the top theorems today are stated at the media classifier's **R13** block profile
(`RunShapeShield.lean`, `shield_shapes_r13`), while the app's installed development build runs W16R2
(`MVP_STATUS.md:33`) and the 8B line goes to W16R3 (D67, D78). So F5-F7 already face one re-instantiation that has
nothing to do with D80.

### 4.2 Per candidate

"Carries": used as is. "Re-instantiated": the same theorems and the same proof pattern at new parameters, slots or
lists; work, but not new mathematics. "Replaced": new mathematics. All entries ARGUED unless marked.

| Family | A | B | C | D | E |
|---|---|---|---|---|---|
| F1 foundations | carries | carries | Goldilocks, Fp/Fp2 executable and challenge-bias lemmas replaced; hash, Merkle, oracle carry | carries if BLAKE3 is kept | carries |
| F2 sumcheck and FS | carries; GKR adds a layer-reduction lemma and its FS instance | carries, plus A's | generic lemmas carry; executable instances re-instantiated | carries if ported into our framework | carries |
| F3 commitment | carries (fewer instances: no H) | carries; a packed-row claim lemma added | proximity lemmas are field-generic and carry; executable openings re-instantiated | replaced by the fold-and-hop tower (the adapted FlashProve code lemmas carry) | carries |
| F4 lookups | the identity carries (LogUp-GKR) or a product-form identity is added; the helper form and all covers replaced | as A, plus the smallness test | as A, in a degree-4 field | replaced | carries |
| F5 blocks | re-instantiated (slot set and layout change) | re-instantiated more deeply (byte cells, determined planes, higher degrees) | relations redesigned (digits and carries): replaced | replaced | carries |
| F6 stages | re-instantiated (byte lookups lose helpers) | re-instantiated | replaced | re-instantiated (IN and OUT are what D adds) | carries |
| F7 run chain and budget | re-instantiated; zone recount | re-instantiated; recount with smallness terms | re-instantiated; LogUp term short (D56) | replaced | carries |
| F8 zero knowledge | generic lemmas carry, except `HidingOpeningSum` (H's zero-sum mask) in part; a masked-GKR simulator is new | as A, plus smallness digits | Fp2-pair lemmas re-proved for Fp4 | generic oracle and Merkle lemmas carry; the tower's hiding is new | carries |
| F9 model and CircuitIff | the integer model carries; the iff lemmas carry; `CircuitHelpers` goes | integer model carries; `CircuitBlock`'s plane form re-expressed in cells | no-wrap lemmas (`CircuitField`, `CircuitMatmul`'s 2^58 bound) replaced | integer model carries; arithmetization replaced | carries |
| F10 statements | carries | carries | carries | carries (FlashProve's own top theorems are different objects and would need a bridge) | carries |

In lines, for the two leading candidates A and B (DERIVED from 4.1, ARGUED classification):
- **Carries:** F1, F2, F3, F9, F10, the generic F8 lemmas, `SoundLogUp` and most of `FSLogUp`: about 45,600 lines, 24%.
- **Re-instantiated:** F5, F6, F7 and the per-profile F8 files: about 136,800 lines, 71%.
- **Replaced:** the rest of F4: about 10,400 lines, 5%.

Re-instantiation is not free and not lost. The covers, the alive/doom method, the path-wise count and the extraction
pattern were the hard part and are reusable; several lanes already regenerate files from scripts (the L60/L61
generators reproduce their nine files byte for byte, `MVP_STATUS.md:50`). How much of the 71% is mechanical is not
measured; I would guess between a third and two thirds, and that guess is the largest uncertainty in this section.

### 4.3 The lanes open now

| Open item (MVP_STATUS gap list) | A | B | C | D | E | Comment |
|---|---|---|---|---|---|---|
| L62's block bundle `hblkS` (define and lookup draws in the right lists, header length, block IO reading) | at risk | at risk | at risk | lost | safe | Its lookup draw lists and slot schedule change under every protocol candidate. Its proved "fixed public half" (layout, tables, IO algebra) is the pattern a re-instantiation would follow. Safe under all for the R13 app if the app stays on R13. |
| L63's stage claims parts `hTrIC`, `hTrOC` | mostly safe | mostly safe | at risk | at risk | safe | They rest on stage openings and M, which A and B keep. |
| L63's stage LogUp facts `hLI_stg`, `hLO_stg` | at risk | at risk | at risk | lost | safe | The stages' byte lookups use helpers today. |
| L63's stage dooms `hdinS`, `hdoutS`, the stage degrees | re-instantiated | re-instantiated | at risk | lost | safe | Tied to the run chain's shape. |
| L63's generic lemma for refused zero challenges (`RunStgShieldRbr`, lane branch) | safe | safe | safe | safe | safe | Generic over the protocol. |
| Block alive lists `hR0_blk` … `hH1_blk`, `hLU_blk` | at risk (the H lists vanish, `hLU_blk` changes form) | at risk | at risk | lost | safe | The alive method carries. |
| `hdzero` (input endpoint) | safe | safe | at risk | at risk | safe | A and B keep the endpoint commitment as it is (ARGUED). |
| `O` (O1-O7 public facts; O8 completeness contracts; O9 refusal sites; O12 zero knowledge) | O1-O7 re-instantiated (cheap); O8, O9 redone; O12 at risk | same | same | same | safe | O12 is open today under every option, so no proof is lost there; what is lost is design effort spent on today's simulator. |
| `hzk` | safe | safe | safe | safe | safe | An inequality on the error term (gap audit row 22). |

**Safe under every candidate:** the approved statements and their amendments (F10), the integer model (`ModelInt`,
`ModelOut`) and, except under C, the per-operation CircuitIff lemmas, the oracle, Merkle and transcript foundations,
the generic sumcheck and Fiat-Shamir theory, and E entirely. **At risk under every protocol candidate:** the
helper-column lookup family (F4), the block and stage lookup facts, and the per-profile zero-knowledge simulation.
**The work most exposed by A or B is exactly what L62 and half of L63 are proving now.** That is a reason to keep
those lanes on the media app's profile, where they keep their value whatever the 8B line does, and not a reason to stop
them (ARGUED; D80 leaves the decision to Victor).

## 5. A proposed meaning of "clearly superior"

A later protocol is clearly superior when all of these hold (proposal; the owner accepts or edits):

1. **Same privacy scope:** P1 as decided, the same declared leakage (D76), no weakened statement, no change of the
   model's word classes (D67, D78).
2. **Soundness written down:** every error term listed and summed, meeting q·2^-100 + 2^-100 with no proof-of-work
   credit unless separately ruled, checked by a second person.
3. **Zero knowledge at least as well founded as today's:** a written simulator for the whole receipt, reviewed
   independently; or a machine-checked one.
4. **Measured on a full 8B block:** a prototype that proves one full 8B block (or the 26-layer classifier) with every
   output word equal to the reference witness, every receipt verified in a fresh process, tampering controls rejected.
5. **A stated factor on the same hardware:** at least x1.5 on proved tokens/s (or x2 on receipt size, if size is
   reopened) against the current profile on the same machine, same model, same clock definition, alternating A/B runs.
6. **A costed Lean re-proof:** the section 4 map turned into lane-weeks, with the families that carry named.
7. **No regression elsewhere:** verifier time and memory within the deployment's limits.

## 6. The cheapest next experiment for each candidate

| | What is built or counted | Pass | Kill | Hardware | Ruling first? | Size |
|---|---|---|---|---|---|---|
| A | (1) Paper: one-page simulator for layers 1-3 of the masked tree, and a side-by-side of FlashProve's product-tree masking against the local blinding-leaf design. (2) Count: re-run the Rust census test with the helper planes deleted | (1) the revealed finals fit the masks' degrees of freedom; (2) ≤ 2,700 rows per block | (1) more revealed values than mask freedom, or blinding leaves fail tessera's objection; (2) > 2,700 rows | none; the census is a CPU test | no | 2-4 days |
| | **Status 2026-11-16: paper step PASSED** (`ZK60_NEXT_PROTOCOL_A_PAPER_STEP_20261116.md`): layers 1-3 reveal 3, 12, 15 free values against 3, 20, 23 mask degrees of freedom; 2,502-2,512 rows per block (320-322 k words per token-layer) by script from the recorded census, the Rust census still to confirm; recommended masking form a hybrid (local mechanics, FlashProve's discipline); the product-tree variant A2 is at 2,710-2,725 rows, above the kill line. Not a zero-knowledge proof: four steps remain new and unreviewed. Next: the single-block prototype | | | | | |
| | **Status 2026-11-17, 11:37 UTC: the block and the stream are re-measured on the current build; A's gross ceiling is about x1.2 and its own cost is of the same size** (Antigravity's Batch 6, `results/zk60_h132_batched_forward_20261116/BATCH6_HEAD_PROFILE_METRICS.json`; independent reading review `results/zk60_claude_review_20261116/BATCH6_REVIEW.md`: stands with corrections; the reviewer recomputed every headline from the raw logs and the coordinator re-ran the stream recomputation; nothing was re-measured). (1) **One 8B block on the current build:** proof core 268 ms (MEASURED, median of 7 warm passes; the last five give 266 ms), of which the GPU is busy 93 ms (35%) and the host accounts for the rest. The 337 ms in the 09:00 row under E was taken with a diagnostic switch that re-runs the commitment's GPU parts, so it overstated the two commitments; this row supersedes it. (2) **What A removes, measured:** helper inverses 17 ms, the H commitment 23 ms, the H opening 10 ms, H's masks 2 ms: 52 ms, 19% of the proof core, a gross ceiling of x1.24. That is variant G3, every helper retired; for G1 it is about 36 ms and x1.15. (3) **What that list leaves out (ESTIMATE by table count, not measured):** the helper terms inside the five domain zero-checks, 8 to 17 ms of their 74 ms, and up to 8 ms for the table-helper slot. With them the gross ceiling is x1.29 to x1.41. The per-slot trace that could measure this was deleted by the batch's script. (4) **A's own cost is not netted off and is the same size:** the 2026-11-01 estimate for the tree's rounds on Metal is 40 to 105 ms per block, with about 9 ms of leaf-claim terms and 48 to 144 more mask rows. On those figures the one-block result lies between a loss (x0.8) and x1.1 (ARITHMETIC on an older estimate; no GPU version of the tree exists). (5) **Stream, six forks, 32 blocks:** 6.09 s per request alone (21.0 tok/s) and 3.61 s per request pipelined on two lanes (35.5 tok/s) (MEASURED, 6 warm passes each). The pipeline is balanced to within 0.14 s: its cadence is the larger of the prove call and half of (witness pass + receipt write + prove call), and the witness pass runs x1.53 slower while a proof runs beside it. Removing 19% of the proving time therefore gives x1.09 to x1.19 on the stream, or x1.13 to x1.27 with the estimate of item 3, both gross. The batch's own x1.18 to x1.22 rested on a floor of 3.05 s that is a mean including one unoverlapped request. (6) **A second channel, not measured:** A halves the codewords held per request (43.2 to 21.5 GB), which could pay for a third lane inside the same memory budget. **Reading (Claude, co-coordinator):** on this machine A alone does not reach section 5's x1.5 line even gross, and its net gain is inside the uncertainty of its own cost estimate. The single-block prototype is not justified by speed on the Mac, so A stays on paper. Three things could change this: a measured third lane, B's saving on top of A (H153 and H154 are open), or the RTX 5090, where the GPU's share differs. The witness pass is now the larger target in the stream: 2.17 s of 6.09 s alone, and with the prove call it sets the pipelined cadence; it has not been profiled by phase | | | | | |
| | **Status 2026-11-17, 16:07 UTC: the witness pass is profiled and a three-lane stream is measured; neither changes A's standing, and one remark about A is withdrawn** (`results/zk60_batch7_sealing_lanes3_20261117/`, measured by Antigravity; reviewed and recomputed, `results/zk60_claude_review_20261116/BATCH7_REVIEW.md`: the measurements stand, most of the report's explanation of them does not). (1) **A third lane gives no gain today** (3.617 s per request on two lanes against 3.676 s on three, like for like, about 2% slower at the noise floor). A lane holds a request's witnesses, not its codewords, so the coordinator's 11:37 remark that A's second channel could pay for a third lane is withdrawn. (2) **The two-lane stream is balanced on both terms** (coordinator's ARITHMETIC on the measured medians): the prove call beside sealing is 3.70 s and (sealing + write + prove)/2 is 3.64 s, against a 3.67 s cadence. A faster proof alone, which is all any candidate in this document offers, moves the cadence only until the sealing term binds: at A's gross x1.2 on the prove call the two-lane cadence falls from 3.67 s to about 3.33 s (x1.10), with sealing held at today's overlapped 3.35 s [MODEL]. 50 tok/s (2.56 s per request) needs the prove call and the sealing side both down by about x1.3 to x1.45. (3) **The sealing pass is therefore a co-target, and it is engineering, not protocol:** 2.2 s alone, 3.35 s beside a proof; alone, 71% to 75% of it has no GPU product in flight, and 1.17 s of it is the gaps between blocks, whose content is not measured yet (a sampler split is running, `results/zk60_claude_batch8_sealing_split_20261117/`). No change to proof bytes, the verifier or the Lean statements is involved in that work | | | | | |
| | **Status 2026-11-17, 16:48 UTC: A re-priced in GPU time from the kept stream traces; it does not pay on the Mac on the current estimate of its own cost** (`results/zk60_claude_review_20261116/STREAM_GPU_PHASES.md`; recomputed from the Batch 7 traces by one agent, read by the coordinator, not cross-reviewed). (1) **In the stream the prove call is limited mostly by the GPU:** a prover buffer is executing 2.5 to 2.7 s of a 3.5 to 3.8 s call, the GPU is saturated while busy (overlap buys x1.11 to x1.19 over serial execution), and 1.0 to 1.2 s is host-only. The wall-time list of the 11:37 row therefore mis-weights A: its host parts (helper inverses, masks) are mostly hidden behind other forks' GPU work, and what counts is GPU time. (2) **A's measured GPU part** (helper commit and opening) is 15.2% of the prover's GPU time, 0.41 s per request: x1.12 on the prove call. With a modelled helper share of slots 14 to 18 and slot 19: 20.6% to 29.9%, up to x1.28 on the prove call and x1.08 to x1.14 on the two-lane cadence [MODEL], before A's own cost. (3) **A's own cost in the same terms:** the 2026-11-01 estimate of its tree rounds, 40 to 105 ms per block on Metal, exceeds the 13 to 25 ms of GPU time per block that A removes [ARITHMETIC on an estimate]. Unless the rounds are several times cheaper than estimated, A is a net loss of GPU time on this machine. (4) **What the traces point at instead:** the five domain zero-check slots own 49.5% of the prover's GPU time. A prover-side way to compute the same round messages with less work would convert about one for one into the prove call with no change to the protocol or the Lean statements; the researcher's queue now leads with that question (H157). **Reading (Claude, co-coordinator):** A stays on paper. On this Mac 50 tok/s needs GPU work removed (the floor is 2.5 to 2.7 s of GPU per request against a 2.56 s budget), so a candidate is now judged first by the GPU time it removes net of the GPU time it adds | | | | | |
| B | Read FlashProve's format §13.9 and the source that turns a claim on one cell row into a check on packed words; then count the byte width of every A plane at 8B | a mechanism that serves per-cell claims from packed words, with its cost; mean ≤ 2 bytes per value | no such mechanism (cycle 6b's negative stands); or mean > 2.5 bytes per value | none (reading, a count script) | no | 2-3 days |
| | **Status 2026-11-16: the reading half PASSED on paper, the count half is open** (`research/zkp-efficiency/handoffs/20261116-claude-tick5-flashprove-packed-claims.md`; the packing is in format doc 11-1, not §13.9). A mechanism exists and it is not an opening: a sumcheck end value lands on a committed row-contracted vector, and a random ternary column-compression ties that vector to the packed words through range-checked digits. Cost of the cell part: 1/3 + 2·tau/k of the unpacked cells, so 0.40 at k = 4,096 and 0.365 at k = 8,191 with tau = 128 (derived by the researcher from the authors' formulas, not measured). **Three things this adds against the table above:** (1) the digit term is larger than the 1.6% assumed in section 3, which used k = 16,384, and FlashProve's verifier refuses k above 8,191; (2) a new completeness gate: an honest cell must be byte-scale (RMS about 450 at k = 4,096), 12-bit cells already fail about 1.4% of combinations, so the byte re-expression is required, not optional; (3) the check is statistical, 2^-tau per column, and the authors themselves say it gives no knowledge error, so tau = 128 is forced for a 100-bit budget and the bound is their claim, not a verified one. Hiding of the digits and the contraction vector under P1 is not reviewed. **Decision (Claude, co-coordinator): B is not costed beside A until two counts are in**, the row width k and honest cell size per A plane (H150, H151) and whether the local schedule allows commit-after-point for the contraction vector; both are the researcher's next two ticks. B's rows in section 3 stand only if both hold | | | | | |
| | **Status 2026-11-17: the count half is in, by count from the layout code, no proof or witness run** (`research/zkp-efficiency/handoffs/20261117-claude-tick6-cell-width.md`, script beside it, re-run by the coordinator). (1) **Bytes per value: PASS on this row's condition.** Of the 2,256 A cell rows, 832 are already byte-scale, 480 are 16-bit lookup limbs that must become two byte cells, 272 are 9-to-16-bit remainders whose width the calibration sets, 672 are int16 words not measured; that is 1.2 to 1.6 byte cells per value (coordinator's arithmetic from those counts), under the 2.0 line. (2) **Row width: mixed.** k is 4,096 for the residual and query planes and 7,168 for the feed-forward planes after a split (cell cost 0.40 and 0.37); the key/value planes have k = 1,024 (0.58); the score planes at k = 128 would cost more packed than unpacked, so they stay as they are or are reshaped with heads in the columns. (3) **Result:** the A data rows fall to 0.47-0.67 of today's 2,279, close to the 0.50-0.67 this table assumed, so B's rows in section 3 are not contradicted; the low end needs the score planes reshaped and the int16 planes to pass. (4) **B without A is small:** splitting the 480 limbs adds about 480 lookups, and with helper columns still committed the whole block is about 0.86 of today's. B is A plus packing, as defined above, and is not worth building alone. **Still open for B:** the honest size of the int16 planes (needs one trained witness capture, per-plane RMS; none found in the repository), the transcript-order question (the researcher's next tick), the attention format page, and hiding under P1 | | | | | |
| | **Status 2026-11-17, 07:55 UTC: the order question is answered on paper, and it adds a cost** (`research/zkp-efficiency/handoffs/20261117-claude-tick7-commit-after-point.md`, script beside it, re-run by the coordinator; local code reading only, no proof run). (1) **The order can be met, but by nothing that exists today.** The vector the local opening sends contracts packed words, so the three cell lanes arrive summed and cannot be separated; it also mixes all claims of a group, and it is a masked message, not a commitment. B needs a new hiding commitment holding one contraction vector per cell read, and two or three more commit-then-challenge phases after the 23 sumchecks. (2) **Cost not counted by ticks 5 and 6.** Under the local rule of one reserved mask pair per claim, that commitment is 302 to 452 rows per block if all 120 claim sites of commitment A are cell reads. This is a bound: the number of cell reads is not counted. It is 25% to 61% of the 747 to 1,202 rows B saves. Whole block at the bound: 0.82 to 0.94 of today's, against 0.76 to 0.85 before; 0.79 at the low end if only half the sites are cell reads (assumed, not counted). (3) **Coordinator's notes.** The 452 figure uses the feed-forward width before the split tick 6 requires; after the split each read is half as wide, but a split plane may need two reads, so the count must use the split layout. The handoff's sentence on the opening's order follows a stale code comment: the code, and the Lean model of it, draw the proximity weights before the group vectors are absorbed; the handoff's conclusion does not depend on it. (4) **Decision (Claude, co-coordinator): B stays uncosted beside A.** Two cheap checks can stop it and run first: the cell-read count (H153; B is parked if the new commitment exceeds 20% of B's saving) and the smallness test against knowledge soundness (H154; the authors say the test gives no knowledge error, and our statement T1b is knowledge soundness). Sharing one mask pair between several reads would cut the commitment to 60-210 rows, but it changes the privacy argument; that would be a P1 ruling for the owner and is not proposed. **Still open for B:** H153, H154, the honest size of the int16 planes, the attention format page, and hiding under P1 | | | | | |
| | **Status 2026-11-17, 11:53 UTC: the cell reads are counted; the new commitment is 17% to 37% of B's saving, and which end applies turns on the int16 planes** (`research/zkp-efficiency/handoffs/20261117-claude-tick8-cell-read-count.md`, script beside it, re-run by the coordinator; a count from the layout rule, checked only against the census's 2,501 A rows, no proof run). (1) **The 120 sites of the 07:55 row were the toy shape's count.** The 8B profile has 110 claim sites on commitment A, and 67 of them read cell planes. (2) **Cost of the contraction commitment with its mask pairs:** 198 to 204 rows if only the 16-bit lookup limbs are split (17% to 19% of the A rows B saves, under the 20% line), 222 rows if the 9-to-16-bit remainders split too (20.3%), and 277 to 286 rows if the int16 word planes must split (34% to 37%, over the line). (3) **Which end applies:** the only data on the int16 planes is Batch 5's census, which is indicative only (fallback prompts, the Stage 2 model's planes): two of them, 256 rows, run 2.3 to 5 times over the byte cap. On that evidence the upper end applies at least in part. (4) **A credit not taken:** moving the 67 reads off packed A may release some of A's own 134 mask rows there, 38 to 114 rows depending on a count not yet made (H155). (5) **Whole block:** about 0.80 to 0.90 of today's rows before helper columns. (6) **What that buys in speed, from Batch 6's profile (coordinator's ARITHMETIC):** the A commitment and its opening are 37 ms of a 268 ms block, so a third fewer A rows is at most about 12 ms, x1.05, before the new commitment and its extra phases. **Decision (Claude, co-coordinator): B is not costed further for speed.** On the Mac, A and B together stay under section 5's x1.5 line even gross. B's remaining case is committed volume and memory, which the owner shelved on 2026-11-09. One cheap check stays first in the researcher's queue because it can close B for good: the smallness test against knowledge soundness (H154). The net-volume count (H152) and the tie-claim count (H155) move behind the witness-pass item | | | | | |
| | **Status 2026-11-17, 15:54 UTC: the knowledge-soundness check does not close B; it stays alive on paper under three conditions** (`research/zkp-efficiency/handoffs/20261117-claude-tick9-smallness-knowledge.md`, toy script beside it, re-run by the coordinator: worst pass probability exactly 0.5 in all five runs; a reading of FlashProve's `rng.h` and its format page; no Lean file read, no proof run). (1) **No rewind past the test's challenge is needed, on the authors' argument:** the packed cells, the reads and the weights are fixed before the challenge is drawn, so the test is one more round in the round-by-round framework already built here, with a state function that reads the commit log. The authors' step is argued on paper and not refereed, and the researcher's reading of their "no knowledge error" remark is an interpretation. (2) **Conditions, none met today:** a new Lean round with a new combinatorial lemma about packing and reads together (H156); `circuit_iff` proved for cells in (-2^18, 2^18) instead of bytes, or the byte bound enforced by separate lookups (a count is queued); and the commit order of the 07:55 row. (3) **A tighter honest cap:** a combination outside the window is a refusal, and T1a's approved target is a refusal rate of at most 2^-40 (`ZK60_LEAN_PRODUCTION_STATEMENTS.md`), so the cap on honest cell RMS is about 311 at k = 4,096 and 235 at k = 7,168, not the 453 and 342 sized for a 1% failure [DERIVED by the researcher, Gaussian tails]. That makes the int16 planes more likely to need splitting, the expensive end of the 11:53 row. **Reading (Claude, co-coordinator):** B is neither closed nor advanced. Its speed value is unchanged (at most about x1.05 on the Mac), so the 11:53 decision stands: B is not costed further for speed, and its remaining counts sit behind the speed items in the researcher's queue. No ruling is asked of the owner: the 2^-40 target is already the approved statement, and relaxing it is not proposed | | | | | |
| C | None recommended; D56's own first step (a census of the 31-bit layout) only if A is built and a field change is still wanted | census below Goldilocks + GKR | as D56: more words than Goldilocks + GKR | CPU | no | 1 week |
| D | A written mapping: every FlashProve chain and theorem, what P1 removes, adds and re-states; a count of its trace cells at our 8B shape from its formulas | the additions fit in its framework without new mathematics beyond IN and OUT stages | the input or output hiding needs a structure FlashProve has no counterpart for | none | no | 1 week |
| E | G1 as the review defines it: INT8-limb fold against the production fold, full 64-bit operands, word-for-word over a whole 8B block, ≥ 30 repeats on a quiet box | every word equal; ≥ x1.5 end to end over the production kernel | any word differs; or < x1.2 | M3 Ultra now (quiet window); RTX 5090 later | no | 1-2 weeks |
| | **Status 2026-11-17, 09:00 UTC: the witness product is measured; the fold is not; D80a's gate is not met as written** (Antigravity's Batch 5, `results/zk60_h132_batched_forward_20261116/`; independent reading review `results/zk60_claude_review_20261116/BATCH5_REVIEW.md`: the measurement stands with corrections; no figure below was re-measured by the coordinator). (1) **The existing exact kernel is slower than production:** x0.56 on GPU time, x0.67 end to end (MEASURED, medians of 32, outputs equal word for word to CPU integer arithmetic). That is below this row's kill line. (2) **A new kernel written in the same batch is faster:** x1.40 end to end like for like (13.475 to 9.625 ms for the seven products of one 8B block, seven command buffers on both sides, same host packing), x1.84 on GPU time alone. It depends on the data: six of the seven inputs fit one byte on trained activations; on full-range 16-bit inputs the gain is x1.03. Between this row's kill and pass lines on trained data, below the kill line on full-range data. The larger figures quoted with the batch (x1.75, x1.88, x2.09) set one command buffer against seven, or a minimum against a median. (3) **Worth on a whole block: x1.01 to x1.02** (the seven products are about 3% of a 414 ms block; ARITHMETIC from the batch's own profile). Removing the whole witness would bound the gain at x1.23 on that profile. (4) **The profile itself** (GPU at most 33-38% of a single block, host at least 62-67%) is one warm pass at 1 ms resolution from a test binary built 2026-11-06, before four later prover commits; treat as indicative. (5) **Not measured:** the fold kernel this row defines, and the witness forward pass against the production witness builder. (6) Two side results: batching several requests in one forward fails its gate on the right baseline (x0.89 at four requests, line x0.80; H132), and sharing request-independent helper tables is small (2.7% to 12.8% of the proof core depending on the bucket; H127). **Reading (Claude, co-coordinator):** on the Mac the exact integer product work is at the low end of this section's x1.00-1.15 estimate and does not change the ranking of the candidates. The prototype of A does not start on this batch: the ruling waits for the measurement as written, and where a request's time goes must first be re-measured on the current build | | | | | |
| | **Status 2026-11-17, 11:37 UTC: this row's fold experiment cannot be run as defined, because no exact-integer fold kernel exists** (Batch 6 item 2; confirmed by the reviewer's search: the only fold kernels are the production Goldilocks ones, and the one earlier mock was a 24-bit floating-point test already marked invalid). The production fold in the openings runs on the host by default, about 11 ms per block, 4% of the proof core (from Batch 5's log; the 0.175 ms quoted with Batch 6 is the gather buffers, not the fold). So the fold half of E has a small target and no kernel, and it is dropped from this row unless someone writes one. The forward-pass half remains open: Batch 5 measured the seven products (x1.01 to x1.02 of a block), and the witness pass as a whole, 2.17 s of a 6.09 s stream request, has not been profiled by phase. **D80a (Claude's reading, for the owner):** the exact integer work is now measured as far as it exists: the products yes, the fold has no kernel. Whether that meets the ruling's gate is the owner's call; the coordinator's recommendation in the row under A is not to start A's prototype either way | | | | | |

Then, for whichever of A or B survives its paper step: a single-block prototype on the M3 Ultra (masked GKR on Metal,
one 8B block, byte-checked witness, fresh-process verify), which is the first test that can satisfy section 5 item 4.
Kill if the block's proving time does not fall by at least x1.1 against W16R2 on the same binary build.

## 7. Questions for the owner

1. **Accept or edit section 5 as the meaning of "clearly superior".** Recommendation: accept it, with x1.5 as the
   speed threshold.
2. **May the A paper step and count run now** (section 6, no code in the prover, no ruling)? Recommendation: yes; it
   is the cheapest way to learn whether A's zero knowledge can be written.
3. **Should the Lean lanes stay on the media app's profile** (R13 today; W16R2 when the app's statement moves), where
   their proofs keep their value whatever the 8B line does? Recommendation: yes; it is what protects the work most
   exposed in section 4.
4. **Is the 8B line's next profile after W16R3 allowed to be a larger break** (A, and later B) rather than another
   increment? Recommendation: yes in principle, decided only after a section 5 comparison.
5. **Should E proceed as ordinary byte-preserving work** under the existing rules? Recommendation: yes; it needs no
   ruling and carries to every candidate.

## Sources read

Handoffs of 2026-11-16 (cycles 2-6c, ticks 1-3) and 2026-11-01 (`20261101-logup-gkr-w16.md`) in
`research/zkp-efficiency/handoffs/`; `research/zkp-efficiency/experiments/logup-gkr-20261101/ZK_DESIGN_NOTE.md`;
`docs/zkmatrix-poc/W16R3_DESIGN_B6_20261105.md` (the B6 and B6b wide-row study); `W16R3_DESIGN_B1_B3_20261105.md`;
`ZK60_EFFICIENCY_PLAN_20261105.md`; `ZK60_DECISIONS.md` (D63, D66, D67, D76-D80); `ZK60_PRIVACY_REQUIREMENTS.md`;
`ZK60_LEAN_PRODUCTION_STATEMENTS.md`; `MVP_STATUS.md`; `formal/README.md`; `ZK60_ULTIMATE_GOAL_2X_OVERHEAD.md` (its
"22% of today" combines cycle 6b's 31-bit byte halving with 6a and 6c; D56 shows the 31-bit field adds digits, so that
figure does not hold); `results/zk60_claude_review_20261116/GPU_FRIENDLY_REVIEW.md`;
`results/zk60_metal_20261031/D56_FIELD_SWITCH_STUDY.md`; `results/zk60_astra_20261026/flashprove_comparison_20261104/`
(REPORT, architecture, guarantees, `upstream/docs/protocol.md`, `upstream/lean/THEOREM.md`, `upstream_tree.json`:
FlashProve's `lean/` holds 29,563 `.lean` files, COUNTED). Two web fetches of FlashProve's
`docs/format/11-1-machinery.md` at commit `9e2bdd8f` (public, no project detail sent), read through a summarizing tool,
for the packing question in 3.B.

**Not done in this version:** no candidate's soundness was recounted in full; FlashProve's §13.9 and source were not
read; the Lean classification is by file name, not by reading each file; the share of re-instantiation that is
mechanical is a guess.
