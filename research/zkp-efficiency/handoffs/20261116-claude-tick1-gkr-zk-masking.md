# Research handoff: zero knowledge for GKR-based lookups, published masking techniques against the local design (2026-11-16, claude-tick 1)

From Claude, the standing researcher (D50), background tick 1. Queue item 1.

**Scope.**
- **Web reading plus local counting.** 7 searches, 11 successful page reads (plus 2 fetches that failed with a transient classifier
  error and were retried; one ePrint PDF 403, one review PDF 404, one arXiv PDF unreadable binary). No build, prover run, GPU run, Git write.
  Local: `experiments/logup-gkr-20261101/ZK_DESIGN_NOTE.md` and the 20261101 and 6a handoffs. Arithmetic is in this file (one `python3 -c`).
- **Triage material, not a work order.** Any change to what is committed alters proof bytes and the verifier; it needs the owner's
  ruling, a new profile string (D17) and re-proved Lean statements (D63). Size work is shelved (2026-11-09); this is about prover speed.

Labels: **[AUTHORS]** (a source's number, unchecked), **COUNTED** (file), **DERIVED** (arithmetic shown), **[abstract]** / **[summary]**
(read only that), **MEMORY** (my recollection of a paper I could not read this tick; not a finding).

## 0. Headline

- **No source found publishes zero-knowledge LogUp-GKR for a hidden-activation transformer.** Papini-Haboeck's page (ePrint 2023/1284)
  makes no zero-knowledge statement [abstract]; Celer's page (2026/1453) does not mention zero knowledge, a field or a PCS [abstract].
  The only worked LogUp-specific masking I found is tessera's RFC-0032 (PR #325), unimplemented and with its tree-level simulator
  argument "still pending" [PR text].
- **The local design's mask cost is small and the cost is not the question.** Its mask content is 2,148 Fp2 coefficients (4,296 base
  words) per block [DERIVED from the note's 7k+2 per layer, sum over layers 1-24]; as allocated (48-144 `M` rows of 4,096 words) it is
  0.41-1.24% of a G1 block's 47.7 M words [DERIVED]. **The open item is the simulator argument, not bytes or time.**
- **Two published families fit a Merkle/RS stack; two do not.** Small per-round masks (Libra-style, and the 2026 hash-based
  "ZK sumcheck" of ePrint 2026/391) and the one-time-pad-plus-deferred-constraints route (Longfellow, hash-based, reviewed) fit.
  Full-size random masking oracles (CFS 1704.02086 in its general form) cost another full codeword (below); Hyrax / Virgo-style committed
  messages need EC or univariate PCS commitments (MEMORY; not verified here).

## 1. What each technique commits and costs (about 2^25 leaves per block, 24 layer sumchecks, 300 rounds)

| Technique | What is masked, and by what | Committed words | Source and reading |
|---|---|---|---|
| **Local design** (Libra masks on parent coordinates; per-layer mask `g_k`; blinding leaves) | `V' = V + Z*R` with `Z` over parent coordinates; round messages get a mask `g_k` of k variables, degree 7 in the last round | `g_k`: 2,148 Fp2 per block; `R^p,R^q` at most 12 per layer; 48-144 `M` rows (COUNTED in the note); H: -1,970 rows | COUNTED (note §2, §4); DERIVED sums; **unreviewed** |
| **Libra** (ePrint 2019/317) | GKR made zero-knowledge "using small masking polynomials" | not stated in the abstract; per-layer mask polynomial opened by the PCS | [abstract]; prover time O(C), proof O(d log C) [AUTHORS]; I recall a sum-of-univariates mask with about 1 + l*d coefficients (MEMORY, PDF refused, 403) |
| **CFS zero-knowledge sumcheck** (arXiv 1704.02086) | prover sends a masking oracle; perfect ZK in the IPCP model, via an algebraic commitment | in its general form a mask the size of the polynomial; a full-size mask per layer sums to about 2^26 base words per block (**8,192 rows of 2^14, 281% of a G1 block**) [DERIVED; kills it unless reduced] | [abstract]; "no overhead figures" on the page. This is **not** what the local note calls "CFS mask": that is a low-degree k-variable mask |
| **Virgo++** (ePrint 2020/1247) | ZK GKR via polynomial commitments | not stated | [abstract]; 1 s for 600,000 gates, 229 KB, 0.56 s [AUTHORS]; unclear whether those figures are the ZK variant. EC/other PCS not checked |
| **Hash-based HVZK sumcheck** (Chiesa-Fenzi-Weissenberg, ePrint 2026/391, "ZOOK") | one small mask polynomial per round, `ell_zk >= 3` coefficients, committed under a zero-knowledge code with Merkle commitments | "O(k * ell_zk) extra field elements" [AUTHORS via a Plonky3 crate's docs]: 75 elements for k = 25, 900 for all 24 layers [DERIVED, ell = 3] | paper read only as a search-result abstract; construction details via `p3-sumcheck` docs.rs (secondary). **A mask commitment per round, not one `M` block**, so Merkle root and opening cost per layer is unmeasured |
| **Longfellow ZK** (IETF draft libzk-03; Ligero over RS, GKR-style sumcheck) | one-time pads on round polynomials and layer claims; the verifier's checks become linear and quadratic constraints on committed pads and witness, proved inside Ligero | 4 pads per round plus 3 per layer: **4 x 300 + 3 x 25 = 1,275 Fp2 per block** (2,550 base words, 0.16 row) [DERIVED from the draft's §6.5 counts] | draft read to §6.6 only (text cut off at 100,000 of 171,038 characters). Security level "at least 115 bits" [AUTHORS]; a Dec 2025 security review exists but its PDF returned 404 (not read) |

**Reading.** The Longfellow route is the only published, reviewed, hash-and-RS construction that makes GKR transcripts hidden. It
differs from the local design in kind: pads are committed and the transcript is verified by a constraint proof, instead of masking
inside the sumcheck with polynomials that the PCS opens. Its fit here would mean proving the GKR verifier's checks inside the project's
own domain zero-checks, a larger redesign than the local masks.

## 2. Comparison with the local design

- **Bytes:** every candidate is below 1.3% of a block; only full-size CFS masking is prohibitive. Mask volume does not decide between
  them. [DERIVED]
- **Prover work:** the local design adds O(1) work per layer (last round degree 3 to 7, note §2); Longfellow-style pads add constraint
  terms per round (300 + 25 pad relations) to the domain zero-checks. Neither is measured. Round-latency (H113's 0.3 ms floor) matters
  more than arithmetic: the extra degree adds no rounds.
- **What is published for the local design's specific problems:**
  - Boolean child-bit leak: tessera PR #325 reports the same leak (level evaluations at a pair bit where `Z` vanishes) and fixes it
    differently, with a forest of at least two trees (public padding tree), masked extensions and no root sent. It says that doubles a
    lone tree's leaves in a naive prover, and "a structure-aware prover can compute them in closed form" [PR text]. Soundness there:
    LogUp term becomes 2(N+T)/|Fp2| [PR text]. The local design chose blinding leaves, which the PR explicitly **rejects** ("masking
    leaves" and "independent masking pairs") without giving the reason in the text I read. **Reconcile this before any review.**
  - Shared masking scalar across trees leaks d_a/d_t: same finding in both.
  - Final checks with a public coefficient on a committed scalar: same open item in both.
- **Nobody has published a joint-view simulator for 25 masked layers plus PCS openings.** tessera lists its own as pending.

## 3. What a zero-knowledge review of the local design must check

1. Joint-view simulator over 25 layers: the finals, CFS-masked round messages, zero-check shares, PCS openings, salts and repeated
   attempts, written once, not layer by layer.
2. Degrees of freedom: each `R` (about 6 coefficients, degree at most 2 in one parent coordinate) against the evaluations that layer
   reveals (two per function, at the child bit, plus the round messages); mask degree at least 7 covers the last round.
3. The blinding-leaf choice against tessera's rejection of it; layer 1 and the root `(0, a*b)` alone are a marginal argument.
4. The split leaf claim: per-domain shares must not reveal a domain's sum; the verifier's sum check must hold on masked values only.
5. Committed blinding scalars entering a check with public coefficients (stay inside masked shares).
6. Repeated attempts: whether a failed proof leaks through retried challenges, as the 25-layer GKR is re-run per request.
7. Soundness recount with the masks: LogUp (N+T)/|Fp2|, GKR 3(k-1)+7 per layer, Libra masks, tag fold.

## 4. Candidates

- **H142: write the simulator for the masked tree layers (paper-and-Lean-statement task, no prover).**
  - *Effect.* None on volume or speed directly; it unlocks H136 (-49 to -50% committed words, x1.07-1.25 on Metal per 6a).
  - *Test.* A one-page simulator for layers 1-3 with the exact message list. **Kill** if layer 2's revealed finals exceed the degrees of
    freedom of `R` (a count, not a run); or if blinding leaves cannot be separated from tessera's two-tree argument.
- **H143: cost the Longfellow-style one-time-pad route in the project's terms.** Count pad relations as extra terms in the domain
  zero-checks (1,275 Fp2 per block); **kill** if the zero-checks' degree rises above their current mask degree, or if the verifier's GKR
  checks cannot be expressed as degree-2 constraints on committed values (the draft states linear and quadratic only).

## 5. Risks and what was not verified

- Every paper above except the local note was read as an abstract, a code-doc summary or a partial draft. The Libra coefficient count and
  the Hyrax/Virgo commitment types are from memory, not this tick's reading. The Longfellow review and the Libra and CFS PDFs were
  unreadable by the fetch tool.
- ePrint 2026/391 construction numbers come from a crate's documentation and an unofficial write-up, not the paper.
- I did not compare simulators; I only compared what is committed. Celer's zero-knowledge status stays open (page silent).
- Expected effect on committed words per request: zero until a ruling; on proved tokens per second: zero directly. Complete private 8B at
  50 proved tokens/s remains unachieved. New proofs, passes, positions: 0 / 0 / 0. Hypotheses 143.

## 6. Next concrete actions

1. Coordinator: before any H136 build, have the security owner read tessera RFC-0032 and decide blinding leaves against a two-tree forest.
2. A later tick: read Celer's full text through arXiv or a project page (queue item 2 stays).
3. Optionally, a later tick: read ePrint 2026/391 Construction 6.3 and the Longfellow security review via a route that returns text.
