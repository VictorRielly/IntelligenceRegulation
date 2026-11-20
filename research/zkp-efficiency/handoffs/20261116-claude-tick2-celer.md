# Research handoff: Celer (ePrint 2026/1453), what it commits per lookup and whether it fits this project's commitment (2026-11-16, claude tick 2)

From Claude, the standing background researcher (D50). Takes queue item 1 (H137 from `20261116-claude-cycle6a-lookup-volume.md`).

**Scope.**
- **Web reading only.** 4 searches, 12 page reads (two of them failed or returned a redirect I did not follow). No build, prover
  run, GPU run, Git write. Written: this file, a STATE.md entry, a queue update and a coordination pointer.
- **The paper's PDF could not be read.** `eprint.iacr.org/2026/1453.pdf` and the `/archive/` path both return HTTP 403 to the fetch tool;
  the Springer chapter redirects to a login (not followed). So **this is not a full read of the paper.** What I read: the ePrint
  abstract page (full abstract), one search-result summary of the PDF text, and the authors' public C++ prototype
  (`github.com/quwenjie/Celer`: README, file list, `main.cpp`, `celer_prove.hpp`, `celer_logup_digitcat.hpp`). Statements about the
  protocol below come from the code and are marked **[code]**; they are inferences from code I read through a summarising fetch, not from the
  paper's text.
- **Triage material, not a work order.** Anything here that changed what is committed would change proof bytes and the verifier and
  would need the owner's ruling, a new profile string and re-proved Lean statements (D63). Size work was shelved on 2026-11-09; this concerns
  prover time and committed words.

Labels: **[authors]** (a number the paper or abstract states, unchecked), **[code]** (read in their prototype via a summarising fetch),
**[summary]** (third-party or search-engine summary of the PDF), **DERIVED**, **COUNTED**.

## 0. Headline

- **Celer, as implemented, uses a pairing curve and a Dory commitment, not a hash-based one.** The prototype calls `initPairing(mcl::BN254)`,
  has a `dory_pcs.hpp`, and reports proof size with compressed GT (pairing target group) elements [code]. The abstract says the
  commitment count is "sublinear in m" while field operations stay linear, and a search summary of the PDF says the PIOP is paired
  with Dory to get sublinear *group operations* and that compiling with a multilinear PCS in general is "still missing" [summary, one
  secondary reading, not checked against the PDF].
- **Against the kill test I set in cycle 6a (H137: "kill if it needs a pairing or elliptic-curve PCS"), Celer as published is killed for a
  drop-in.** This project commits with Merkle-hashed Reed-Solomon codewords over Goldilocks; Celer's saving is stated in group operations,
  a cost this project does not pay.
- **No zero knowledge is claimed or visible.** The abstract does not mention it; the code has no blinding or hiding step, and its test
  driver seeds a plain Mersenne Twister with a fixed constant [code]. It is a soundness-only prototype, as far as I can see.
- **The idea may still port; that is unverified.** What the code shows is a LogUp-style argument (inverse columns `F`, `FP`, multiplicities `C`,
  four sumchecks) run over **two base-`b` digits** with `b = ceil(sqrt(m+1))` [code], so the committed columns live on domains of size about
  sqrt(m), not m. If so, committed words per lookup fall with m. I could not confirm that reading from the paper.

## 1. What was read, and what it says

| Item | Source and depth | Finding |
|---|---|---|
| Abstract | ePrint page, full abstract | Lookup argument for m much larger than table size n. Commitments sublinear in m; field ops linear in m. At m = 2^28, n = 2^16 ("proving Llama inference"), prover **25.9x faster than plookup and 9.4x faster than LogUp** [authors]. Minor revision of a CRYPTO 2026 paper. |
| Hardware, field, PCS, ZK of the 25.9x / 9.4x | not in the abstract; PDF unreadable | **Not verified.** The prototype's field is BN254 `Fr` [code], so the comparison field is not Goldilocks. |
| README | repo | C++17, `mcl` library; `./celer n m` with powers of two; **no benchmark numbers, no hardware, no ZK statement** [code]. Two repositories carry the name (a Rust one from 2025-01 with 0 stars; I read only the one owned by the first author's handle). Authorship of the repository is inferred from the handle. |
| `celer_prove.hpp` | repo source | One **Wave A** commitment packs eight blocks: U, D, C, h_F, R0_F, R1_F, P, S (sizes not shown to me); a **Wave B** commits the gamma-dependent inverse columns `cmF`, `cmFp` separately. The query vector commitment `cmA` is a pre-existing input, "excluded from proof size." One batched Dory opening at **24 points** for Wave A [code]. |
| `celer_logup_digitcat.hpp` | repo source | `F = 1/(P + gamma*S)` on query rows, `FP = C/(idx + gamma*D)` on table rows; four sumchecks (query inverse, table inverse, two sum checks); each value split into W = 2 digits base `base_s`, each digit with `base_s - 1` active values [code]. No hiding. |
| `main.cpp` | repo source | `BASE_S = ceil_sqrt(m+1)` (for m = 2^28 that is 2^14 + 1, DERIVED); `W = 2`; table domain extended to 2n; timing brackets exclude the `cmA` commitment from prover total [code]. |

Note the last row: **the benchmark's prover time excludes committing the query vector** (labelled in the driver), which is the cost this project
cannot exclude: the looked-up values are committed anyway as A planes, so the exclusion matches this project's accounting, but the
speed-ups versus plookup and LogUp may or may not use the same exclusion for the baselines. Not verified.

## 2. Against this project's numbers (cycle 6a, COUNTED)

- Today: one committed Fp2 helper plane per two lookups, so **1 extra committed word per lookup**; 2,162 range-helper rows plus 30 table-helper
  rows of 5,103 per block. At m = 2^30 per request that is about 2^30 helper words (DERIVED from 6a).
- LogUp-GKR (6a G1/G2): 0 per lookup, at the cost of a GKR tree. Celer's claim: sublinear in m, linear field work, **no GKR tree** [authors,
  abstract] but **a pairing PCS** [code].
- Volume can fall no further than G2/G3 (49-51% of today's block rows), because the A words and limbs stay. So Celer **cannot improve the volume
  result of 6a**; it could at most improve prover *time* relative to the 25-layer GKR (0.160 s per 2^25 leaves on 32 CPU threads, MEASURED in
  `20261101-logup-gkr-w16.md`).

## 3. Candidate, with a falsifiable test

- **H144: port the Celer PIOP (digit decomposition plus four sumchecks) to open the project's committed planes by Ligero-style
  evaluation, in place of Dory.**
  - *What I do not know.* Whether the digit trick is PCS-agnostic; how many evaluation points one lookup instance needs (the code shows 24 in
    Wave A for one instance [code]); whether the two digit domains of about 2^14 words can be committed as ordinary rows of the existing
    4,096-word-row layout.
  - *Test (reading, no prover run).* From the PDF's PIOP section, list the evaluation claims the verifier is left with; **kill if the count
    exceeds 24 per instance per block** (each is a separate evaluation of a committed plane, and the project already pays for those in the
    sumcheck matmul checks) or if any claim needs a pairing or group-structured homomorphism.
  - *Test (count).* With `b = 2^14` and W = 2, count the committed rows per block that replace 2,162 + 30 helper rows;
    **kill if they exceed 600 rows** (a quarter of today's helper rows).
  - *Expected effect if it survives.* (i) committed words per request: **same as the G1/G2 range of 6a at best (-43% to -50%)**; not better, because the
    lookup inputs stay committed. (ii) proved tokens per second: **unknown**, no GPU Goldilocks implementation exists, and the authors'
    prototype is CPU C++ on BN254. Ruling needed: owner (profile, Lean) and the ZK question (below).
- **H137 is closed as stated:** Celer as published does not pass the cycle 6a screen (pairing/EC PCS).

## 4. Risks

- **Zero knowledge is absent in the prototype, and the digit decomposition changes what a lookup reveals.** Digit counts and multiplicities are the
  verifier's view in any LogUp; for hidden activations the local masked design (tick 1) already has to cover them. The digit layer adds data,
  not removes any. Treat the ZK question as open (H142/H143).
- **Soundness over a different field.** The authors' soundness is for BN254 `Fr` (about 254 bits). Over Goldilocks with an extension, the LogUp term
  is the same ~2^-103 per block the project already pays (6a, DERIVED there); any new random-evaluation claims add terms. Not computed.
- **Speed-ups are against plookup and LogUp, not against LogUp-GKR or a helper-column LogUp.** 9.4x over "LogUp" does not translate to a gain over
  this project's path, which is already cheaper than a naive LogUp.

## 5. What was not verified

- Everything in the paper's body: the PIOP statement, the stated soundness, the ZK section if any, the benchmark hardware and baselines.
- The reading of the Dory-compilation sentence is from a search-engine summary of the PDF, not the PDF.
- The meaning of the two digits in the code is my inference; the fetch tool summarised the sources and could not give me the file text verbatim.
- Two nearby papers surfaced in search results, titles only and unread: TenseUp (ePrint 2026/2435, "doubly-efficient lookup arguments") and Rogue
  (ePrint 2026/1890, updatable matrix lookups).

## 6. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**.
  Hypotheses: 144 (H144 added; H137 closed).

## 7. Next concrete actions (no new permission needed to prepare)

1. Anyone with a browser: download `eprint.iacr.org/2026/1453.pdf` to a local path so the PIOP section can be read with the file tools (the fetch tool is
   refused by that host); then run H144's reading test.
2. Not before then: do not spend prover-side effort on Celer.
