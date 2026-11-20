# Research handoff: receipt size and prover-cost-near-computation, what is published (2026-11-16, claude-cycle 3)

From Claude, the standing researcher (D50).

**Scope.**
- **Read and web search only.** 15 searches and 14 page reads, plus local reading. No build, proof, GPU run,
  experiment or Git write. Only this file and a dated STATE.md entry were written.
- **Triage material, not a work order.** The owner shelved proof-size work on 2026-11-09 in favour of closing proof
  gaps (`MVP_STATUS.md`), and D67 already put recursive openings (B6) in the next profile, not W16R3. Nothing here asks
  for work on size now; it is for the owner and the other coordinator to decide what, if anything, to pull forward.
- **Questions from the other coordinator** about `docs/zkmatrix-poc/ZK60_ULTIMATE_GOAL_2X_OVERHEAD.md` (a proposed
  target; every number in it is treated as unreviewed, and its "measured" section rests on a benchmark an independent
  review found invalid: `results/zk60_claude_review_20261116/GPU_FRIENDLY_REVIEW.md`, summary section).
  (A) How do systems get a many-layer proof to megabytes with activations hidden? (B) Which systems report prover
  time within a small constant of plain evaluation, on what, and what do they leave out of the clock?
- **Builds on:** cycles 1 and 2 of today (not repeated), and the local B6 design study
  `docs/zkmatrix-poc/W16R3_DESIGN_B6_20261105.md` (which already models recursive openings and wide rows from
  FlashProve's tower). **Read that note before this one**; this cycle adds outside evidence and a floor argument.
- **Searches and fetches carried no project name, owner name, path or detail.** Pages were treated as data. Nothing
  fetched was executed. Two PDFs (Jolt Atlas, a training-verification paper) could not be rendered by the fetch tool and
  were not read beyond their abstract pages.

Labels: [MEASURED] (a run in this repository), [AUTHORS] (the source's own unreplicated number), [DERIVED] (my arithmetic
on stated inputs), [MODEL], [ESTIMATE]. Most search snippets came through a summarizing tool; "(summary)" marks a figure
I did not see in the source's own text. Nothing below is a measurement of this project's new work.

## 0. Headline

- **Receipt size: megabytes with hidden intermediates has one published precedent in our family, FlashProve at
  18.8 MB per 1,024-token request** (cycle 1, 2; weights hidden, prompt and reply public, about 96-bit soundness
  without grinding) [AUTHORS]. Our 819 MB at 128 tokens is 6.4 MB per token against their 18 KB per token. The
  other "KB-sized" systems either hide less (zkLLM, under 200 kB, hides weights; NANOZK, 83 KB, d = 128 toy widths) or
  say nothing on hidden values. **Nothing found supports the "< 1-5 MB for 8B" figure in the 2x goal file.**
- **The mechanism that gets there is not GKR claim reduction or batching openings.** 372 of our 819 MB is opened
  column data, Q x rows x 8 B (B6 note §0, §2.2). No change that leaves the rows 2^14 wide removes it. What does: **wide
  rows (a few rows of 2^18-2^20 entries) plus a code-switch tower that opens a short folded vector** (B6b: 40-52 MB
  modelled locally, costing +13 to +42 ms GPU per block). That is the same structure FlashProve ships. Wrapping in a
  pairing SNARK or a zkVM recursion does not fit at this witness size (§1.2 and §4, R1-R2).
- **Prover cost: no published system comes near 2x for a hidden-intermediate model proof.**
  - Best "matrix part only" figure: Thaler's matmul sumcheck adds about 0.03 s to a 2.17 s 1,024 x 1,024 product (about
    1.4%), interactive, no commitment, no zero knowledge, 2013 CPU [AUTHORS (summary of a slide table)]. The reason is
    arithmetic: the check costs O(n^2) against O(n^3) for the product.
  - Best measured full-model constant with hidden intermediates: **FlashProve, 71-93x slower than vLLM prefill of the
    same tokens per GPU** [AUTHORS, cycle 1]. Ours: about **80-100x at 128 tokens, 140-190x at 32** against plain 8-bit
    inference [MEASURED, demo kit, `MVP_STATUS.md`; older binary, n = 1].
- **Is 2x plausible for an 8B model?** **No, not with this commit-everything design, and no published system suggests
  otherwise.** A counting floor (§1.5) puts the codeword traffic alone at about 3-4x plain's total memory time on a 5090,
  before the NTT, hashing, sumchecks or lookups. Getting near 2x needs the committed volume cut by an order of
  magnitude, which no published full-model system has shown with hidden activations.

## 1. External evidence, what it actually claims

### 1.1 Size and zero knowledge, system by system

| System (source, date) | Proof size | Witness or model | Hardware, field | Hidden | Prover overhead reported |
|---|---|---|---|---|---|
| FlashProve (cycle 1, 2) [AUTHORS] | 18.8 MB per 1,024-token request | ~17B active, 4-bit | H100, ~64-bit field + extension | weights, intermediates, routing; prompt/reply public | 71-93x vs vLLM prefill (their calculation) |
| zkLLM (arXiv 2404.16109, 2024; abstract + summary) [AUTHORS] | under 200 kB; one summary lists 160 kB, verify 3.71 s | 13B (OPT-13B) | CUDA GPU, model not named in abstract | **weights**; abstract silent on inputs and activations | "under 15 minutes" for a full inference; the summary lists 713 s; no plain baseline on the page |
| NANOZK (arXiv 2603.18046, ICLR 2026 version differs) [AUTHORS] | 3.5-3.7 KB per layer proof, ~83 KB at L = 12; 22 ms verify | widths up to d = 128 measured; d = 768 GPU figure "about 68 s per block" is a **projection** | CPU measured; Halo2-style circuits; SHA-256 commitment chain | weights and activations (prompt not hidden from prover) | none against plain inference; "full soundness still requires verifying every layer" |
| zkAgent (ePrint 2026/199) [AUTHORS] | not stated on the page | GPT-2, 512-token transcript | not stated | not stated | 0.30-0.40 s/token (summary); only a speedup over zkGPT |
| zkPyTorch (ePrint 2025/535; press release) [AUTHORS, unreviewed] | no figure found | Llama-3 8B | one CPU core, Expander | not clear | about 150 s per token |
| Jolt Atlas (arXiv 2602.17452, Feb 2026) | not read (PDF unreadable here) | ONNX lookup-based | not read | ZK via BlindFold | third-party docs: about 5-10% prover overhead and ~3 KB for ZK on the sumchecks (two figures that do not agree, unreconciled) |
| Ligerito (ePrint 2025/1187) [AUTHORS] | 255 KiB for 2^24 coefficients; a crate says ~147 KB at 2^20 | 2^24 | M1 laptop; 32-bit binary field | **no ZK found** | 1.3 s prover |
| WHIR (ePrint 2024/1586) [AUTHORS (summary)] | 63 KiB at degree 2^22; ~360 us verify; prover 1.2 s | 2^22 | not stated | **no ZK** | n/a |
| Orion / Scorpius (ePrint 2024/1164 repair; ePrint 2024/1871 for a Brakedown note) | Orion 5.7 MB at 2^25 (a course slide, summary); Brakedown-type O(sqrt M); the repaired scheme claims smaller than original Orion | 2^25 | not stated | Orion adds ZK; **"still unsound with and without ZK" in the repair paper's words** | n/a |
| ZK IOPP (ePrint 2026/391; Chiesa, Fenzi, Weissenberg) [AUTHORS] | "negligible" overhead for HVZK vs non-ZK; abstract only, no figures | n/a | n/a | HVZK proximity with ZK sumcheck and ZK code switching | negligible, unquantified |

What these say, in order of relevance:
- **FlashProve is the only row that matches our setting** (code-based, Goldilocks-class field, hidden intermediates, ~96-100
  bits, a big model) and it shows MB-scale is reachable by a tower of FOLD + code switch with wide rows, which is B6b.
- **WHIR, Ligerito and the code-switch family give 63-255 KiB for 2^22-2^24 polynomials but without ZK.** The step from
  there to a hidden-witness receipt is exactly the "tower's own zero knowledge" item the B6 note flags as unproved
  (§0 risks). ePrint 2026/391 is the first source claiming that step at negligible overhead; **I read its abstract only**.
- **Orion's polylog proof size is real but its soundness and ZK handling were found broken** (2024/1164). Not a base to
  adopt; it is the same code-switch idea B6 already takes from FlashProve.

### 1.2 Wrapping and recursion

- **RISC Zero** documents three receipt kinds: composite (one STARK per segment, "can be quite large"), succinct
  (one STARK over a recursion tree) and Groth16 (a few hundred bytes; one source quotes a 773-byte example). Groth16 is
  the only shrink-wrap type, **cannot be re-composed**, and needs a trusted setup [AUTHORS (summary of docs); sizes and
  timings were not on the page I read].
- Recursion hides the inner proof by construction (the outer proof is zero-knowledge about its witness, which is the
  inner receipt). That is a **real property, not an optimization for us**: the inner proof's own hiding would then be moot.
- **It does not fit this witness size** (§4, R1-R2): the circuit that verifies one block's 24.5 MB opening is tens of
  millions of BLAKE3 compressions and 8-byte field operations; the wrap's prover would cost more than the block's proof.
  I found no published figure of wrapping a multi-hundred-megabyte hash-based receipt. [DERIVED, order of magnitude]
- **Decisions register note:** the Groth16 trusted-setup deviation is already recorded there as a ruling; a wrap would
  need a new receipt kind and the D63 Lean statements.

### 1.3 Folding and accumulation for multilinear or code-based commitments

- WARP (ePrint 2025/753): hash-based accumulation, linear prover and logarithmic verifier [AUTHORS (summary)].
- ePrint 2026/538 (Paslis, Ràfols, Zacharakis): hash-based PCD from accumulation; the decider collapses accumulated checks
  into one polynomial evaluation [AUTHORS (summary)].
- ePrint 2026/289 (Zheng, Gao, Liu): zero-knowledge accumulation with masking vectors and ZK sumcheck, revised 2026-07-30.
- ePrint 2026/1857: most folding beyond Nova is randomizing, not blinding; shows a SuperNeo transcript can leak.
- **None gives numbers at multi-gigabyte witness size, and none addresses a ZK Ligero-style opening.** They target
  chains of many small steps. A layered model proof is such a chain, but each of our 32 blocks is already a 24 MB frame
  and the final decider still opens a full-size commitment. The ZK caveat in 2026/1857 is directly relevant: any
  folding used here has to carry its own hiding argument.

### 1.4 What is built into "cross-layer claim reduction" and "one combined polynomial"

- **GKR or sumcheck chaining** reduces a claim on layer l's output to a claim on its input, so one commitment to the
  input and one evaluation claim at the end can replace per-layer commitments. This is how zkLLM-type systems reach small
  proofs, but their layer relations are arithmetic; the non-linearities (softmax, norms, SiLU) need lookups over committed
  values, so the **committed volume falls only by what is purely linear**. Zero knowledge needs ZK sumchecks (Libra-style
  masking or BlindFold-style); I did not check Libra's overhead this cycle.
- **One combined polynomial** (a random linear combination of every committed row into one evaluation claim) is what D59's
  independent row weights already do for the proximity test. **It does not reduce opened columns**: Q columns of the full
  height are opened either way. That is why 372 MB survives all batching.

### 1.5 The counting floor for 2x (my derivation; check before use)

Inputs and where they come from:
- Opened data 372 MB per request = Q x rows x 8 B with Q = 280 (B6 note §0). That gives about **166,000 committed rows**
  per request; at 2^14 columns, **about 2.7 x 10^9 committed field elements, 22 GB of 8-byte words** [DERIVED; order of
  magnitude only, since the census could count rows across several commitment shapes; recount from
  `results/zk60_effplan_20261105/b6/model.py`'s census before quoting]. A cross-check from first principles (about 8 M
  activations per block at T128 times a limb/helper factor of 5-10 times 32 blocks) gives 1.3-2.6 x 10^9, the same order.
- Code rate 1/2 (D59), so the codewords are about 2x that: **about 40 GB written, then read for Merkle hashing**.
- Plain 8B int8 prefill at T = 128 on an RTX 5090: weights 8 GB read once at about 1.8 TB/s (published bandwidth, not
  verified this cycle) is about 4.5 ms; compute is about 2 x 10^12 int8 ops at a dense rate I did not confirm (cycle 1
  doubts the 1,500 TOPS figure): 2-4 ms. **Plain is about 5-8 ms per request** [ESTIMATE].
- 2x total overhead would allow about **10-16 ms per request** for everything: witness, encode, Merkle, sumchecks, lookups.
- **Writing 40 GB of codewords once at 1.8 TB/s takes about 22 ms** [DERIVED], above the whole 2x budget, before reading
  them back to hash, the NTT's several passes, and the column opens. A realistic 3-pass lower bound is 8-12x plain.
- **At the D64 target (110 tok/s, 1.16 s per request) the ratio is about 180x** [DERIVED, same plain estimate], which
  agrees with the 80-190x measured locally and FlashProve's 71-93x.
- **Conclusion.** The memory-traffic floor of today's committed volume is about 3-4x plain for one pass and about 10x
  for a realistic pipeline. To approach 2x the committed volume per request has to fall by roughly 10x (for example
  small-value packing, 8 int8 per word, and not committing what a chained sumcheck can carry) **and** the kernels have to
  run near bandwidth peak. Neither is shown by any published full-model system.

### 1.6 Prover cost near the computation: what is published, and what each leaves out of the clock

| Source | Reported constant | Hardware | Left out of the clock or not comparable |
|---|---|---|---|
| Thaler 2013, matmul protocol (CRYPTO 2013; snippet-level) [AUTHORS] | about 0.03 s extra over 2.17 s for 1,024 x 1,024 (about 1.4%); generic circuits "less than 10x slower than a C++ program that evaluates the circuit" | 2013 CPU | interactive, no commitment, no zero knowledge, verifier holds the data; matrices not hidden |
| Sumcheck streaming prover (Baweja, Chiesa, Fedele, Applebaum; summary) [AUTHORS] | under 2x time overhead for up to 120x less memory | not stated | that is overhead against a linear-time **prover**, not against plain computation |
| TensorZKP (ePrint 2026/1250, NUS) [AUTHORS, abstract via summary] | 215.28 ms proof for 2^25 multiplication gates; encoder 11.58 ms, degree-2 sumcheck 4.04 ms at 2^25; 955x over a CPU baseline, 36.2x over SIMT GPU | hardware not verified here; "Tensor-Core-compatible finite field"; a Spielman-style code | **no plain-evaluation baseline**; field and hiding not read |
| zkPHIRE (arXiv 2508.16738) [AUTHORS] | 1486x over CPU; 4-5 KB proofs | an accelerator design | no plain baseline; ZK not stated; not a GPU |
| FlashProve (cycle 1, 2) [AUTHORS] | 71-93x slower than vLLM prefill per GPU | H100 + 24 CPU cores | start-up and the 39-minute weight commitment; **reply generated by a separate engine**, off the clock |
| zkLLM [AUTHORS] | under 15 minutes for a 13B inference | CUDA GPU | no plain baseline on the page read; hides weights |
| Jolt BlindFold (third-party docs) | 5-10% extra for ZK on the sumchecks | CPU | the sumcheck part only |
| This project [MEASURED, `MVP_STATUS.md`] | about 80-100x plain int8 at 128 tokens; 140-190x at 32 | M3 Ultra | demo kit n = 1; older binary; plain baseline is the project's own |

**Reading.** The 1-2x results are for the **check** (sumcheck over a matmul, streaming, ZK masking), not for the whole
proof. The reason is structural: for W (n x m) times X (m x T) the plain work is n m T multiply-adds and the sumcheck is
O(n m + m T + n T), about 1/T of it, so at T = 128 the arithmetic of the matmul check is around 1% of plain. What every
full system pays instead is **committing the intermediates** (encode + hash, with the 8-byte-per-int8 expansion and
limb/helper columns) and **non-linearity lookups**. TensorZKP's per-element numbers (11.58 ms to encode 2^25 words, about
3 x 10^9 words per second) are the only recent evidence on the encoding side; at our 2.7 x 10^9 elements that is
about 1 s per request, in line with a 110 tok/s clock, not a 2x one. [DERIVED, taking their rate at face value for a
different code and field.]

## 2. Candidates

Each: source, claim, what it replaces, bytes and verifier, falsifier in project terms, honest effect on (i) receipt size
and (ii) proved tokens per second, risks. All change bytes unless stated, so each needs the owner's ruling, a new profile
version (D17) and a Lean statement (D63).

### H133 (new, measurement only). The denominator: committed-volume census and a plain-int8 baseline

- **Source.** §1.5 above; local B6 census (`model.py`).
- **Claim.** The 2x target and the "< 1-5 MB" target both need a stated plain baseline and a committed-volume budget; the
  2x file's own numbers rest on an invalid benchmark.
- **What it replaces.** Nothing in the prover. It is two figures: (a) **committed field elements per request, split into
  activations that must exist, limb/range columns, helpers, masks and weights-derived columns**, from the census; (b) a
  plain int8 prefill clock of the same 128 tokens on the same box with a mature engine, run quiet.
- **Bytes / verifier.** None.
- **Falsifier.** **Kill the "2x" planning number if the census puts the per-request memory-traffic floor above 4x the
  plain clock after a 3x kernel gain**, i.e. if (floor bytes / bandwidth) > 4 x (plain time). Equivalent paper form:
  committed bytes per request above about 15 GB at 1.8 TB/s. Conversely, **if activations plus required outputs are under
  10% of committed elements, H134's packing has room**; if over 50% it does not.
- **Honest effect.** No effect on bytes or tok/s; it decides whether H134 is worth a ruling. Cost: a counting script
  (no guarded run) plus one light timing of an existing int8 engine.
- **Risks.** A plain baseline on the Mac shares the GPU with another researcher; wait for a quiet window
  (`ZK60_RESOURCE_PROTOCOL.md`). Do not compare to float inference; the goal file's "float forward" baseline is a
  different, and weaker, denominator.

### H134 (new). Shrink the committed volume: small-value packing and chaining linear layers

- **Source.** Cross-layer GKR-style chaining (zkLLM family, §1.4) and bit-packed small-value commitments (Binius/Jolt
  style; not reviewed this cycle for 64-bit fields). My adaptation.
- **Claim.** Two ways to commit fewer words: (a) pack several int8 values or limbs per Goldilocks element with range
  checks on the packed word (an 8x cut on the activation planes if the checks hold); (b) chain the purely linear parts
  (QKV, output and FFN matmuls) through a sumcheck reduction so only layer-boundary and lookup-feeding planes are
  committed.
- **What it replaces.** The one-element-per-limb layout and the per-matmul committed output planes. The local Lean-found
  savings C1-C3, C5 already trim about 11.7% of rows (`MVP_STATUS.md`); this would be a far larger structural change.
- **Bytes / verifier.** Changes everything: new relations, new range arguments, new soundness bound, a ZK sumcheck chain.
  A new profile, not an increment of W16R3. Needs owner ruling plus a full redo of the D63 statements.
- **Falsifier.** After H133: **kill if the packable fraction of committed elements is under 40%** (a 2x cut at best), or
  if a packed range lookup costs more than the elements it removes (measure on the A commit and one LogUp domain).
- **Honest effect.** (i) Receipt bytes and prover memory traffic scale with committed volume: x1/1.5 to x1/3 on bytes if
  40-70% of elements pack [ESTIMATE]; the B6b wide-row structure is still needed for MB scale. (ii) Tokens per second:
  on the 5090 the central case is host-bound (cycle 1, 20261103), so x1.00-1.10; on the Mac's GPU-bound path up to
  about x1.3-1.8 if the forks phase scales with committed volume [ESTIMATE, not measured].
- **Risks.** Soundness of packed range checks (a mis-packed word is a wrong witness), a bigger Lean surface than B6, and
  zero knowledge for any sumcheck chain. This is the one idea here that could move overhead by an order of magnitude, and
  also the one with the least published support for hidden activations.

### H135 (existing B6b, with new evidence). Wide rows plus a code-switch tower

- **Source.** Local B6 study (from FlashProve's tower); outside support: WHIR 63 KiB at 2^22 and Ligerito 255 KiB at 2^24
  (both without ZK), ePrint 2026/391 (HVZK proximity at "negligible" overhead; abstract only).
- **Claim.** 819 MB to about 40-52 MB per request [MODEL, B6 note]; B6a alone (clear vectors committed in a small
  matrix) is 387 MB and misses a MB target by about 8x because 372 MB is opened columns.
- **What it replaces.** The Q x rows x 8 B opened columns; the clear vectors.
- **Bytes / verifier.** Both change: new profile, a tower verifier, about x5-15 faster PCS-side verification [MODEL].
- **Falsifier.** The B6 note's own half-day timing (§9.3): **kill B6b if the added GPU work exceeds +25 ms per block**
  (its rule); kill the whole line if the tower's HVZK is not proved or taken from a reviewed source (2026/391 is the
  first candidate, **unread beyond the abstract**).
- **Honest effect.** (i) Size: 819 MB to about 40-52 MB [MODEL]. (ii) Prover: B6a within about +-5%; **B6b +13 to +42 ms
  per block, forks phase x0.99-1.36 (up to 36% slower) on the Mac** [MODEL, B6 note]. A size win that slows the prover,
  stated plainly. Throughput on the 5090 is unmodelled.
- **Risks.** The largest Lean change of Phase B; hiding of compact masks is argued only on a toy field; owner has shelved
  size work.

## 3. Ranking for triage (at most three)

1. **H133, the denominator.** A counting and one light timing job; decides whether the 2x number and the
   committed-volume ideas are worth a ruling, and it gives the goal file honest figures. No protocol change.
   Test: kill the 2x planning number if the memory floor of the committed volume exceeds 4x the measured plain clock.
2. **H134, shrink the committed volume.** The only lever that can move both size and overhead by a large factor. Gate it
   on H133's packable fraction (kill under 40%) and on a packed-range lookup cost test. High risk, new profile.
3. **H135 (B6b), wide rows and tower.** The only path to MB-scale receipts with published precedent. Pull forward only
   if the owner reopens size; its own kill rule (+25 ms per block GPU, +3% net for B6a) applies.

**Implication for the 2x goal.** No published system supports it for an 8B model with hidden activations; the best
constant for a full proof is about 71-93x (FlashProve) and ours about 80-190x. The goal file's size target (1-5 MB for
all layers) is 4-18x below FlashProve's published 18.8 MB for 1,024 tokens, which already uses the best structure found.

## 4. Looked at and rejected (one line each)

- **R1. Wrapping the receipt in Groth16 (RISC Zero-style shrink wrap).** Final proof is hundreds of bytes and hides the
  inner receipt, but verifying 24.5 MB of openings per block in-circuit costs more than the proof it wraps; trusted-setup
  ruling and no re-composition (docs). Not at this witness size.
- **R2. Recursion tree over blocks (succinct-receipt style).** Needs each leaf to verify a hash-based opening in a
  proof system; same cost problem as R1 at 32 leaves of 24.5 MB; the B6 tower is the cheaper form of the same idea.
- **R3. WHIR or Ligerito as the commitment.** 63-255 KiB at 2^22-2^24, but no ZK found, RS rate and field differ
  (Ligerito: 32-bit binary field), and neither has a hidden-witness opening analysis. No transfer without 2026/391.
- **R4. Orion / Scorpius (ePrint 2024/1164).** Polylog size through code switching, but the repair paper says the
  original is unsound with and without ZK; the repaired scheme is unreviewed against our field. Same idea as B6's tower.
- **R5. Accumulation and folding (WARP 2025/753; 2026/538; 2026/289; 2026/1857).** Built for PCD chains; no numbers at
  our size; ZK accumulation is young and 2026/1857 shows folding can leak. Decider still opens a full commitment.
- **R6. Batching all openings into one claim.** Already done in effect (D59 row weights); does not shrink opened columns,
  the bulk of the receipt.
- **R7. Jolt Atlas / BlindFold (arXiv 2602.17452).** Replaces per-round masking with a proved verifier circuit;
  could not read the numbers (PDF); the 5-10% and 3 KB claims are third-party and disagree. Re-read before dismissing.
- **R8. NANOZK (arXiv 2603.18046).** 83 KB for 12 layers of width 128 on a CPU; the d = 768 GPU figure is a projection;
  SHA-256 chain and Halo2-style circuits; no plain baseline. Not a bound for 8B.
- **R9. zkLLM (arXiv 2404.16109).** Under 200 kB and under 15 minutes at 13B, but it hides weights and its page read
  says nothing about hidden activations; different threat model from P1.
- **R10. zkPyTorch, zkAgent.** Press-level or abstract-only numbers (150 s per token on one core; 0.30-0.40 s per token
  for GPT-2), hardware and hiding not stated.
- **R11. TensorZKP as a prover-cost bound.** Real evidence that sumcheck and encoding can run on tensor cores, but no
  plain baseline, field and hiding unread, hardware unverified. See §5, correction to cycle 1.
- **R12. Thaler-style 1.4% matmul overhead as a target.** It is the check, not the proof; commitments and lookups are
  outside that clock, and they dominate (§1.6).
- **R13. Grinding bits or a smaller Q for size.** Cycle 1's H129: under 1-3% of receipt, capped by the LogUp bound.

## 5. Corrections and cautions about inputs

- **Cycle 1's R14** ("Tensor-core finite-field GEMM: nothing published for a 64-bit prime") needs softening:
  **TensorZKP (ePrint 2026/1250)** builds tensor-core-compatible finite-field arithmetic and recasts sumcheck and a
  Spielman encoder as matrix products. I did not read its field, its hardware or any hiding property. Treat the R14 claim
  as "not found for Goldilocks", and read the paper before saying anything further.
- **Goal file.** Its "<= 2x", "< 1-5 MB", "4.97x", "8x-14x on the 5090" and "1.5x-2x" figures are the coordinator's
  own or rest on the benchmark the independent review found invalid; none is supported by an external source I read.
  Its description of "cross-layer claim folding plus wide-row tensor commitments" matches B6b only in the wide-row half.
- **Summaries.** Most sizes in §1.1 came through search summaries. The ones I would re-check against the source before
  quoting: zkLLM's 160 kB / 713 s, WHIR's 63 KiB, Orion's 5.7 MB at 2^25, Thaler's table.
- **The "committed elements" figure in §1.5** is derived from a byte census, not read from a count. Recount it.
- **5090 specifications** (1.8 TB/s, dense int8 rate) are published-spec figures not verified this cycle.

## 6. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0**.
- The complete private 8B at >= 50 proved tokens/s on an RTX 5090 (D64 target about 110) remains **unachieved**.
- Hypotheses: H133-H135 added (135 in total). No `progress/` entry or `PROGRESS.md` refresh was written, by the
  instruction for this cycle.

## 7. Next concrete actions (each needs no new permission to prepare)

1. H133(a): a counting script over the B6 census that prints committed elements per request by class and the
   memory-traffic floor at 1.8 TB/s and at the Mac's bandwidth.
2. Read ePrint 2026/391 in full (cost tables for ZK code switching and ZK sumcheck) and 2026/1250 (field, hardware,
   hiding): both decide whether B6b's ZK step has an outside source.
3. Read Jolt Atlas (arXiv 2602.17452) through an HTML copy for its tables.
4. H133(b), when the Mac's GPU is quiet: one plain int8 prefill timing of the same 128 tokens on a mature engine, so the
   2x discussion has a denominator.
