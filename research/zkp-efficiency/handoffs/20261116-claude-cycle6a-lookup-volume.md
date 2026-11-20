# Research handoff: lookup arguments that commit less, and what they would do to one block's committed volume (2026-11-16, claude-cycle 6a)

From Claude, the standing researcher (D50). Part A of a three-part session (6a lookups, 6b small-value packing, 6c linear chains).

**Scope.**
- **Web reading plus local counting.** 9 searches, 14 page fetches (five failed: ePrint PDFs return HTTP 403 to the
  fetch tool, other PDFs come back as binary). No build, prover run, GPU run, Git write. Written: this file, the script
  `20261116-claude-cycle6a-lookup-volume.py` (standard library, reads no file, under a second) and a STATE.md entry.
- **Triage material, not a work order.** Any of these changes what is committed, so it changes proof bytes and the verifier; it
  needs the owner's ruling, a new profile string (D17) and re-proved Lean statements (D63). The owner shelved size work on
  2026-11-09; this is about prover speed and codeword volume, and none of it is a privacy acceptance.
- **Builds on, does not repeat,** `20261101-logup-gkr-w16.md` and `experiments/logup-gkr-20261101/` (the measured LogUp-GKR
  prototype and its ZK design note) and cycle 4's census.

Labels: **COUNTED** (code or recorded census, file:line), **MEASURED** (recorded run), **[AUTHORS]** (a number a source
reports, not checked), **DERIVED** (my arithmetic, in the script), **ASSUMED**. Sources I read only as an abstract or a
secondary summary are marked **[abstract]** / **[summary]**.

## 0. Headline

- **What a lookup costs in committed words today.** One committed Fp2 helper plane covers two lookups (`shape.rs:2562-2565`,
  `helpers = ceil(lookups/2)`; an Fp2 plane takes two rows), so **one extra committed message word per lookup**, on top of the
  looked-up value, which is committed anyway as an A plane. In the census this is the 2,514 H rows (49.3% of a block).
  **2,162 of them are range-lookup helpers, 30 are table helpers, 320 are the exp/act tuple helpers, 2 are `u`** [DERIVED from
  the plane lists; script].
- **The only family that removes that word is LogUp-GKR** (fractional sumcheck in a GKR tree; committed: the multiplicities,
  which are already in A). Logup* and Celer target the same regime but I could read only their abstracts; **Lasso, Shout and
  zkLLM's tlookup commit at least as much as today** for 16-bit tables (§2).
- **Derived effect per block (script, DERIVED; masks as in the 2026-11-01 note):**

| Scenario | Rows per block | Share of today's 5,103 | Request codewords (43.19 GB today) |
|---|---:|---:|---:|
| G1: LogUp-GKR for range lookups and tables (exp/act helpers stay) | 2,911 | 57.0% | 24.9 GB (57.5-57.8%) |
| G2: every lookup in the tree (exp/act too; H keeps `u`) | 2,591 | 50.8% | 22.2 GB (51.3-51.6%) |
| G3: G2 and the H site-mask rows go with their planes (ASSUMED) | 2,509 | 49.2% | 21.5 GB (49.7-50.0%) |

  The ranges are the M-row cost the 2026-11-01 note priced (+48 to +144 masking-table rows per block, 4,096-word codewords).
- **Against cycle 4's floor** (5090, plain int8 4.72 ms mid-range): G1 gives write floor 2.9x, G2 2.6x, G3 2.5x plain int8
  (today 5.1x) [DERIVED: 4.72 ms x ratios; the cycle 4 scenario table has "helpers not committed" at 2.50x]. **It halves the
  volume; it does not reach 2x**, and it adds the GKR work the helper columns did not need.
- **Soundness is not the obstacle.** The LogUp term (N+T)/|Fp2| is about 2^-103 for a 2^25-leaf block tree, 2^-98 over 32 blocks
  by the union bound, and is the same term the helper-column LogUp already pays (cycle 2: proof-of-work "capped by the LogUp
  bound"); the GKR sumcheck terms add about 2^-118 per block [DERIVED from the note's §5 item 7 formula].
- **The open problem is zero knowledge, and the literature does not close it.** Every source I found that pairs GKR-style
  lookups with transformers either proves no zero knowledge, or hides only weights, or leaves it as an estimate (§3). The
  only worked-out masked construction I know of is the local, unreviewed one (`ZK_DESIGN_NOTE.md`), plus the tessera PR it cites.

## 1. What each family commits per lookup

Per lookup, beyond the looked-up value (which the project commits anyway), with 2^16-entry range tables, 2^25 lookups per block
(32.28 M counted lookup words, `projection.py:17`) and 2^30 per request.

| Family | Committed per lookup | Prover pays instead | Source and reading |
|---|---|---|---|
| **This project: LogUp with committed helpers** | 1 word (an Fp2 helper per pair of lookups); 1.275 padded words in the census | batch inversions, helper commit | COUNTED (script; the 1.275 includes pad words, 192 rows) |
| **LogUp-GKR** (Papini-Haboeck, ePrint 2023/1284) | 0; multiplicities per table entry only | a GKR tree of about 25 layers over 2^25 leaves; 10.4 Fp2-mult equivalents and 116 B read + 64 B written per leaf | prior local prototype MEASURED (2026-11-01); the paper's own words on ZK relayed by that note: "zero-knowledge if the used sumcheck is"; I did not re-read it (the PDF refused the fetch); the follow-up 2024/2067 [abstract] only addresses the characteristic bound on multiplicities |
| **Logup\*** (Soukhanov, ePrint 2025/946) | 0 per lookup; commits a pushforward in the extension field of table size, plus the index array (a pulled-back array I*T is never committed) | three degree-2 sumchecks of size m "in the small-table regime" [summary], plus a GKR fractional check of the pushforward | [abstract + a third-party summary]; best when table values are large (tuples, extension elements). For pure range lookups there is no pulled-back array to avoid, so it saves the multiplicities and adds an Fp2 vector: **no gain here**. No ZK statement found |
| **Celer** (ePrint 2026/1453, CRYPTO 2026) | "number of commitments sublinear in the query size m"; field operations linear in m | not stated | [abstract only] **same regime as ours**: m = 2^28, n = 2^16, "a real world case ... Llama inference"; [AUTHORS] 25.9x faster than plookup and 9.4x faster than LogUp at that size (hardware, field, PCS and ZK unread; the PDF refused the fetch) |
| **Lasso** (decomposable big tables) | c index chunks plus read counters and final counts: at least 1 counter per lookup (c = 1 for a 2^16 table); more with c > 1 | memory-checking sumchecks | cited from the SoK (ePrint 2025/1876) by the 2026-11-01 note; the 2^16 tables need no decomposition. **No gain** |
| **Shout** (Setty-Thaler, ePrint 2025/105) | the one-hot read addresses `ra` (T x K, one nonzero per row), d chunks of size K^(1/d); read values virtual | sumcheck degree 2+d, work O(K+T) for d = 1 | [summary]: the cost advantage assumes a commitment whose cost follows the non-zeros ("one group operation per bit", elliptic-curve based). **A Merkle/RS code commits the dense vector**: K = 2^16 words per lookup at d = 1, 512 at d = 2, 64 at d = 4 [DERIVED, script]. **Worse than today** on this PCS |
| **zkLLM tlookup** (arXiv 2404.16109) | the looked-up tensor S, the multiplicity vector m, and A = (beta+S)^-1, size D, per lookup | sumchecks | [read, first 100,000 characters of the text]: **same as today** (one inverse word per lookup). Its ZK: "zero-knowledge variations of sumcheck" with Pedersen/Hyrax, and the stated guarantee covers **model parameters only**; the prompt is a public input, the verifier semi-honest (Theorem 7.4). Not our P1 |
| **Range check by sumcheck** (DekartProof, ePrint 2025/1159) | the committed vector only | a ZK sumcheck built from a "Homomorphic PIOP" | [abstract only]: whether it avoids bit decomposition and its PCS requirements are not in the abstract; no prover-time figures |

**"Range checks that avoid limb decomposition."** In this design the 16-bit words are looked up directly (no decomposition); the
1,272 limb and remainder rows are **committed remainders and windows of wider values** (`shape.rs:2466-2489` plane lists:
four two-limb norm remainders in D, one-limb remainders in Q and Kv, the 24-bit product's top limb in F), not bit
decompositions. No range-check method I found removes the need to commit a remainder that is not a linear form of committed
planes; the only way a remainder disappears is by being **virtual** (a linear form of other committed planes, queried by the
lookup directly). That is a Part C question and is taken up there. **Part A finds no range-check method that lowers the
limb-row count by itself.**

## 2. Derivation, using cycle 4's categories

Per block (rows of 2^14 words), from the census: A words 984, A limbs 1,272, A aggregates 8, A tables 15, H helpers 2,514, A site and
proximity masks 222, H site and proximity masks 88; total 5,103. Plane lists give the split of the 2,514 H rows:

- range helpers: L 2, D 640, Q 192, Kv 48, S 256 (4 of 5 planes), F 1,024 (4 of 5): **2,162**
- table helpers: 15 of the 16 Tab planes x 2 rows: **30**
- exp/act tuple helpers: S 1 plane (64 rows), F 1 plane (256 rows): **320**
- `u`, the zero-sum pair: **2**

(The 2026-11-01 note counted 1,970 rows as the counted lookups, before padding: 32,276,480 / 16,384. The planes the layout
allocates are 2,162; the 192-row difference is pad words inside helper planes. For volume, the allocated rows are what is
committed, so G1 uses 2,162.)

- **G1:** 5,103 - 2,162 - 30 = **2,911 rows** (57.0%). Request: (32 x 2,911 + 1,252) x 2^14 x 2 x 8 B = 24.75 GB, plus the M tables
  at (50 + 48..144) rows x 4,096 words x 8 B x 32 = 0.10-0.20 GB: **24.9 GB** [script prints 24.85-24.95].
- **G2:** also retire the 320 exp/act helper rows: 2,591 rows, **22.2 GB**.
- **G3:** also assume the 86 H site-mask rows go with 43 retired planes (82 kept for the proximity pair and a few survivors;
  ASSUMED, not checked against `claim_sites`, `shape.rs:2597`): 2,509 rows, **21.5 GB**.
- **Hashing** falls with the codewords (43.6 GB hashed today; about the codeword bytes plus 0.4-0.5 GB of salts and nodes, so
  roughly 22 GB in G3 to 25 GB in G1, DERIVED).
- **Not changed by any of these:** A words 984 and A limbs 1,272 rows (the lookups' inputs), the activation floor.

**Prover time is not volume.** The prior prototype measured the GKR at 0.160 s per 2^25 leaves on 32 CPU threads (MEASURED,
`20261101-logup-gkr-w16.md` §1) and projected 0.040-0.105 s per block on Metal against 0.110 s for today's helper path
(ESTIMATE); its whole-block gain with `H` retired is x1.07-1.25. A third-party report of SP1's GPU prover on one RTX 5090 puts
its LogUp-GKR stage at 19.9 ms, about 8% of that shard [hackmd post by a competing GPU-compiler team, single workload,
unverified; **it says the stage is cheap in a different system, nothing about ours**]. No GPU number for a Goldilocks
LogUp-GKR at 2^25 leaves exists in anything I read.

## 3. Zero knowledge: what the sources do

- **GKR leaks unless masked.** Plain GKR layer messages are sums of circuit values; Libra masks the sumcheck with a small
  polynomial of logarithmically many random coefficients (ePrint 2019/317, [summary of its abstract via a search result]).
  Barretenberg's ZK-sumcheck write-up applies the same Libra technique to round univariates and treats masking the final
  multilinear evaluations as a separate step [summary]. Local note: a mask `Z` over every coordinate vanishes at the Boolean child
  bit, so `Z` must run over the parent coordinates only (tessera PR #325, unreviewed; reproduced in `ZK_DESIGN_NOTE.md` §2).
- **Transformer systems pairing GKR-lookups with transformers, per search-result summaries (not all verified):**
  PANDA (arXiv 2608.17070 is, by its abstract, a robustness-certification ZK system and says nothing there of lookups; a
  search summary says it uses LogUp-GKR with the non-zero-knowledge variants and only estimates the cost of adding ZK, which I
  could not confirm); zkAgent (ePrint 2026/199: abstract says nothing of ZK; summary says the construction is presented
  without the zero-knowledge property); SUMMER (ePrint 2025/1688, RNN training; summary says ZK follows from the simulators of
  LogUp and GKR). **I did not read any of these beyond the abstract.** Treat "nobody has a published, benchmarked,
  hidden-activation LogUp-GKR transformer proof" as the working reading, flagged unverified.
- **Therefore the project's own masked design is the reference, and its risks stand** (`ZK_DESIGN_NOTE.md` §5: joint-view
  simulation over 25 masked layers unproven; blinding scalars entering a public-coefficient check; split leaf claim).

## 4. Candidates, each with a falsifiable test in this project's terms

Numbers continue STATE's 135.

- **H136: retire every helper plane with LogUp-GKR over all lookups (G2), including exp/act.**
  - *Expected effect.* (i) committed words per request **-49 to -50%** (43.2 to 21.5-22.3 GB codewords) [DERIVED]; (ii) proved
    tokens/s **x1.07-1.25 on Metal** (prior ESTIMATE; the volume floor was 1-2.5% of the measured request, so volume alone is not
    the limit) and the receipt falls by about 5.0-5.2 MB per block (prior COUNTED, G1-type).
  - *Test (count, no prover run).* Re-run the Rust census test (`effplan_census_of_the_committed_rows_by_domain`) on a layout
    with the helper planes deleted and the exp/act tuples folded into the tree; **kill if the allocated rows per block exceed
    2,700** (volume gain under 47%), which would mean a plane I counted as retirable is not.
  - *Test (measurement, shared Metal GPU needed).* The 2026-11-01 prototype with the fan-in-4 bottom layer at 2^25 leaves;
    **kill if GKR prove time exceeds 0.11 s per block** (today's helper path) on the Metal GPU.
  - *Ruling needed:* ZK review of the masked design, profile string, new Lean statements.
- **H137: read Celer in full.** Test: from the PDF, (a) is it zero-knowledge or can ZK be added by Libra-style masking at stated
  cost; (b) are the commitments Merkle/RS-compatible (not KZG/EC); (c) per-lookup committed words at n = 2^16. **Kill** if it needs a
  pairing or elliptic-curve PCS, or if its committed words per lookup at m = 2^30 are not below 0.1. If it survives, it competes
  with H136 on the same words and may avoid the 25-layer GKR; it cannot beat H136's volume (already near the floor) but may beat
  its time. (i) same as H136 or better; (ii) unknown.
- **Dropped:** Lasso, Shout (dense PCS), Logup* and zkLLM's tlookup, for the reasons in §1. Logup* is worth a second look only if
  the project moves to tuple lookups with wide values.

## 5. Corrections and cautions

- The 2026-11-01 note's 1,970 retired rows are lookups, not allocated rows; the allocated figure is 2,162 for ranges alone.
- Cycle 4 listed the LogUp-GKR route as "halves the volume": derived here, 49-57% of today's volume remains (not 50% exactly).
- I could read no ePrint PDF (HTTP 403 for the fetch tool); every ePrint item is an abstract or a third-party summary, marked.
- I did not verify the search summaries on PANDA, zkAgent, SUMMER or SP1's stage timing against the papers.
- Soundness at 2^-98 over 32 blocks for the LogUp term is the same exposure as today's, not a new one; it still sits
  just inside the "about 100 bits" budget and any added lookup count (e.g. exp/act joining the tree) raises N slightly.

## 6. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains
  **unachieved**. Hypotheses: 137 (H136, H137 added).
- Pointer posted to `ops/zkp-mvp/RECOVERY_COORDINATION.md`.

## 7. Next concrete actions (no new permission needed to prepare)

1. Owner or coordinator: decide whether H136 (the 2026-11-01 LogUp-GKR line, "needs a ruling") is wanted; this note's volume
   counts, 49-57% of today's rows, are the benefit side. Cycle 4 shows it alone does not reach 2x plain.
2. Obtain Celer's full paper by a route the fetch tool can read (arXiv, or a project page); do H137.
3. Re-run the census with the helper planes removed when W16R3 lands; the script's constants are the only edit.
