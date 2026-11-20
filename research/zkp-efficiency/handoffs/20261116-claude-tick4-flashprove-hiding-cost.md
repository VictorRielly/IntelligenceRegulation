# Research handoff: what FlashProve's cost owes to hiding the weights (2026-11-16, claude tick 4)

From Claude, the background researcher (D50). Queue item 2 (the co-coordinator's request for D80's future-protocol study).

**Scope.**
- **Local reading plus 6 fetches, 0 searches.** Read in full from the local copy (`results/zk60_astra_20261026/flashprove_comparison_20261104/upstream`): `guide/performance.md`,
  `guide/weight-hiding.md`, `docs/protocol.md` sections 1-7, `docs/architecture.md` lines 100-225, `docs/figures.tsv` (all rows), `operators-duties.md` (public-weights passages),
  and the earlier `REPORT.md` and `guarantees.md`. Fetched (through the fetch tool's summarizer, so its wording, not verbatim): `docs/format/FORMAT.md` (first 100,000 of
  464,254 characters), `docs/format/10-proof-file.md`, `docs/format/11-5-weights-in-the-table.md`, the announcement page, `README.md`, and one test file that proved to hold no byte counts.
  The local copy has no `docs/format/`, no paper and no `docs/limits-all-rows.tsv`; FORMAT.md section 13 was not reached.
- No build, prover run, GPU run or Git write. Arithmetic in one `python3 -c` call (inputs and outputs are quoted below).
- **Triage material, not a work order.** A protocol that drops the weight table changes what is committed, so it changes proof bytes and the verifier; it needs the owner's ruling, a new profile
  string (D17) and re-proved Lean (D63). The owner shelved proof-size work on 2026-11-09.

Labels: **[AUTHORS]** (their statement or number), **COUNTED** (a file I read, named), **DERIVED** (my arithmetic), **ASSUMED**, **SUMMARIZER** (fetch-tool summary).

## 0. Headline

- **The published numbers cannot separate the cost of hiding the weights, and the authors say so by omission.** No row of `figures.tsv` (every row read) and no page names a phase split of
  prover seconds; the announcement and README give no overhead for hiding and no public-weights baseline [SUMMARIZER, both pages]. The only "public weights" mode,
  `cp_commit -public-weights FILE`, **runs the same protocol with a public seed** ("hides nothing") [AUTHORS, `operators-duties.md:200-204, 281`]; it is a labelling switch, not a cheaper protocol, and no timing for it exists.
- **What the batch-size sweep does show (DERIVED, my fit; §2):** per-batch time is close to a straight line in requests, **7.5 to 7.8 s per request plus 34 to 47 s per batch**
  (fixed part 16% to 21% of a 24-request batch). That fixed part is an **upper bound** on work shared across a batch, and the batch-level weight work is a part of it, not all of it.
- **Committed words that exist only because the weights are hidden, per request, are tiny:** the request vector `w` has one element per matrix column, **2^18 = 262,144 words** per request
  [AUTHORS, `11-5` via SUMMARIZER], about **256 words per token**, about **2 to 4 x 10^-5 of the request's trace** (derived from tick 3's 0.14-0.25 M words per token per layer, 48 layers ASSUMED).
  The weight cost is not in committed words per request; it is in passes over the weights and in per-commitment one-off work (§3).
- **No statement by the authors on hiding prompts or outputs.** Prompt and checked reply tokens are public inputs that enter the equations as public values [AUTHORS, `protocol.md` 2 and 6.3]; the corpus I read is silent on any hidden-I/O variant.

## 1. Which parts exist only because the weights are hidden (COUNTED in `protocol.md`, `architecture.md`, SUMMARIZER for the format pages)

| Part | Needed for hiding? | Evidence |
|---|---|---|
| Masked, Reed-Solomon-encoded weight table (anchor); out-of-domain (OOD) answers = masked sums of the weights; key file with range proof and one-time proximity test | masks and OOD answers: yes. A plain commitment to the weights and a range proof would still exist | `protocol.md` 5.1, 5.5, 6.1 |
| M leaf tables (copies re-encoded with fresh masks) with a link proof each, counters, 688,127-batch limit | **yes**: "a table's masks cover only a fixed number of opened columns" | `architecture.md:172-179`, `protocol.md` 4, 6.2 |
| Batch tree of salted seals, per-request slot (240 B at 64 slots) | batch privacy; a salted hash instead of a mask | `protocol.md` 6.3; 14.7 via SUMMARIZER |
| Shared chain: folded row, positions into the stored table, `Omega` with a split mask message, proximity tests | **partly**: the opening of the committed weights per batch is needed for any commitment to M; the mask messages and split are hiding-only | `protocol.md` 6.3, `10-proof-file.md` |
| Request vector `w = g.M` (2^18 words), `PSC` rounds, second chain | the claim `g.M.e + mu = v` exists for any committed M; `mu` (the mask combination) is hiding-only | `protocol.md` 6.3 |
| Masked sumchecks and mask rows in each segment | a hiding-of-**intermediates** cost; this project's P1 pays it too, for activations | `protocol.md` 5.3, 6.3 |

**The caution that matters for D80:** with public weights the verifier still cannot evaluate `g.M.e` itself (M has 806,380,109,824 digit cells: 3,076,096 rows x 2^18 columns
[AUTHORS, full size, `11-5` via SUMMARIZER]; the verifier takes 21 s), so **a committed-weights opening per batch survives** in any public-weights variant. What leaves is the masking,
the leaf-table copies, the counters and the OOD answers. I found no source that prices those separately.

## 2. The one decomposition the numbers allow (DERIVED, script output reproduced)

Batch time T(n) = n x 1,024 / rate, from `figures.tsv` (`rate-1`, `rate-8`, `rate-24`, `rate-48-steady`, `rate-64`; the guide's seconds per request agree: 58.796, 13.413 x 8, 9.206 x 24):

| Requests per batch n | 1 | 8 | 24 | 48 | 64 |
|---|---:|---:|---:|---:|---:|
| T(n), seconds | 58.8 | 107.3 | 220.9 | 406.4 | 531.5 |

- Least squares on n = 24, 48, 64: **c = 7.76 s per request, d = 34.5 s per batch** (predicts 220.7, 407.0, 531.1: within 0.7 s). On all five points: c = 7.52, d = 47.0 (it under-fits n = 1 by 4 s and over-fits n = 24 by 7 s: pass granularity, six requests per pass).
- At n = 24 the fixed part is **15.6% to 20.7%** of the batch (1.4 to 2.0 s per request). **It bundles** the two extra passes over the weights that open the table, the batch tree and anything else once per batch.
  The linear part (7.5 to 7.8 s per request, 79% to 84%) bundles the trace, the per-request `w = g.M` and **one sixth of a pass over the weights per request** ("`-in-step` of them per pass", `architecture.md:189`), and the passes read the 232.13 GB weight files.
- **What I cannot separate:** how much of c is the hidden-weights part (`w = g.M`, mask rows) against the trace that a public-weights proof would also do; how much of d is hiding against ordinary batch overhead.
  I give **no seconds per hiding phase** because none is published; a number like "4.2 s per pass over 232 GB at 55 GB/s PCIe" is ASSUMED hardware arithmetic, not a measured pass time, and I do not use it.
- Cross-check on what batching amortizes: tick/cycle 2 found ~6.4x throughput from batch 1 to 24; the straight line explains it (d spread over 24 requests, 1 request pays d + c = 42 to 54 s).

## 3. Committed words and one-off cost per 1,024-token request

| Part | Per request | Per commitment / batch | Label |
|---|---|---|---|
| Request vector `w` | 262,144 words (256 per token) | | AUTHORS (`11-5`, SUMMARIZER) |
| Trace (tick 3 estimate x 48 layers) | 6.9 to 12.3 x 10^9 words | | DERIVED (tick 3; layers ASSUMED) |
| `w` share of trace | 2.1 to 3.8 x 10^-5 | | DERIVED |
| Folded row, `Omega`, mask messages | not given | once per batch, shared by n requests | **not found** |
| Key file + leaf file | | 3.29 + 2.95 = 6.24 MB per commitment, downloaded once; checked inside every `cp_verify` call | AUTHORS |
| Committing | | 38:43.77 minutes once; 688,127 batches per leaf table, about 16.5 M requests at 24 per batch | AUTHORS (`commit-time-drawn`, `batches-per-leaf-table`; 688,127 x 24 DERIVED) |
| Proof | 18.78 MB mean (`proof-size-mean`), planned maximum 19.26 MB; chain split not published | | AUTHORS |

(The announcement's own text, as the summarizer returned it, reads "18.78 MB" in a way that could be per batch; `figures.tsv` says "one request's proof", 241 proofs per run, and I use that.)

Amortized: committing 2,324 s over 16.5 M requests is 0.00014 s per request [DERIVED]. **The hiding costs that matter per request are therefore the weight passes and the masked arithmetic, not the commitment.**

## 4. What it means for this project's scope (P1: hide inputs, outputs, activations; weights public)

- **No data transfers from FlashProve on the prompt/reply side:** its prompt and reply are public, so the embedding and head stages here differ (tick 3 caution stands).
- **Weights-side saving for P1 is real but unpriced:** P1 has public weights already, so it carries **none** of the leaf tables, counters, OOD answers or masked weight rows. FlashProve's cost
  includes them; ours does not. That makes FlashProve's 9.2 s per request an **upper bound** for a P1-style prover on the same trace, and the two numbers are not the same quantity either way.
- **A P1-on-FlashProve-like design must still open a committed M per batch** (§1 caution): plain Merkle/RS commitment, no masks, one table, opened once per batch. That is the part a future-protocol study should price,
  and it is the part that makes the weight side cheap in committed words (2^18 per request) but not free in passes.

## 5. Falsifiable tests in this project's terms

- **H148 (the straight line is the model).** Claim: FlashProve batch time is `7.7 n + 35` s at n = 8 to 64 (this fit). **Test (count):** the runs' `figures.json` per-batch times and the n = 8 row;
  **kill** if n = 8 is above 107.3 s by more than 10% on a refit including pass granularity (`ceil(n/6)`), i.e. if time is not linear in requests once granularity is modelled. Expected effect on this project: none directly; it fixes what "amortized" means in D80.
- **H149 (hiding-only share of the fixed part).** The fixed 35 to 47 s contains the two table-opening passes. **Test (needs the authors' code, a GPU, not run here):** time `cp_prove` at n = 6 with `-public-weights` against the same
  with a secret seed; they run the same protocol, so **expect no difference**, which would confirm that no public-weights saving exists in this code. **Kill H149's premise** if the two differ by more than 3%.
- **Not proposed:** any change to this project's protocol. The saving a public-weights FlashProve variant could show (leaf tables, masks, OOD answers) is one this project's P1 never paid.

## 6. Honest expected effect

- **Committed words per request:** the hiding of weights accounts for **at most about 4 x 10^-5** of FlashProve's per-request committed words (the `w` vector); the rest of its volume is trace and masks for intermediates, which this project also pays.
  **Effect on our committed words per request: none**; nothing here is a lever for our protocol.
- **Proved tokens per second:** FlashProve's 111.23 tokens/s at 24 includes a fixed 16% to 21% (batch-level, partly weight opening). A P1-style prover that reads public weights could drop the weight-hiding share of that, but **the size is not determinable from the published data**; I support no multiplier.

## 7. Risks and what was not verified

- **Summarizer reliance.** `11-5`, `10-proof-file`, FORMAT.md first 100,000 characters, announcement and README came through the summarizer: the 2^18 columns, 3,076,096 rows, 262,144-element `w`, "once per batch instead of once per request" are its wording. The numbers 3,076,096 x 2^18 = 8.064 x 10^11 cells agree with a Maverick-scale model (about 4 x 10^11 parameters x 2 digits) [DERIVED], which supports them but is not a verification.
- **The paper's own accounting of the weight-related rounds and the technical report were not read** (tick 3 read the paper's Table 2 and Construction D.6 only). **FORMAT.md section 13 (R14.10, 13.9) not read.**
- **Layer count 48 is ASSUMED** from tick 3's recollection of the paper's Construction D.3; the `w`-share range moves with it.
- The linear fit uses six-request passes at n = 8 (two passes) and 24 (four) as if per-request cost were uniform; the model fits n = 24, 48, 64 and misses n = 1, 8 by 4 to 11 s.
- The three timing machines and runs differ by up to 9% (`performance.md`), larger than some effects I distinguish.

## 8. Pointer on queue item 2b (needed by whoever runs it next)

**The 2b pointer looks wrong.** `11-5-weights-in-the-table.md` (SUMMARIZER) says sections 9 and "13.9 write M", and `protocol.md` maps "format 13.9" to the verifier's segment-and-second-chain step (R14.10). That is the **weight-matrix** claim, not the packing of cell rows into words.
Tick 3 took the radix-2^20 packing from `11-1-machinery.md`. 2b should start at `11-1` (and `11-2`/`11-3` for the cell lists), not at 13.9.

## 9. Status

New proofs, passes, proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains **unachieved**. Hypotheses: 149 (H148, H149 added).

## 10. Next concrete actions

1. Coordinator: tell D80's study that FlashProve offers **no separable hiding price**; price a plain-commitment opening per batch from this project's own measured opening cost instead (queue item 13).
2. Run 2b from `11-1`, not 13.9.
3. If a GPU box is available later, H149 is one run pair on the authors' code.
