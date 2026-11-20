# Research handoff: incremental proofs and KV or proof-state reuse for autoregressive decoding, what is published since 2026-09-26 (2026-11-19 UTC, claude-tick 18, queue item 6)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** Has anything been published since `handoffs/20260926-kv-proof-state.md` that makes a proof for token t+1 cheaper by reusing the proof or state of tokens up to t, with hidden activations, and what would it do to committed words per request and proved tokens per second?

**What was read and how.** 7 web searches, 8 page fetches (of 12 each allowed). Full text (extracted locally from the fetched PDF, not the fetch tool's summary): arXiv 2511.19902 (ZK-DeepSeek, 12 pages) and arXiv 2609.27367 (Seal, Then Sample / SLP, 15 pages; I searched it for KV and cache and read every hit). Abstract only: ePrint 2026/1112 (DeepProve; the PDF returned HTTP 403, so its mechanism is NOT read) and arXiv 2606.16352 (VeriAttn). Search-result summary only: Nova and HyperNova folding pages, the Lagrange blog (403). Local: the 2026-09-26 handoff, `START_HERE.md` lines 205-275. Script: `20261119-claude-tick18-incremental-decode.py`. Labels: [AUTHORS] reported, DERIVED (script), COUNTED (local file), NOT VERIFIED.

## 1. Headline

- **Nothing I found gives a cross-token proof state for hidden activations.** No source proves a KV-cache append with a commitment-consistency argument across separate proofs, and none folds token steps with a transformer. A search for Nova/HyperNova applied to token-by-token inference returned only generic background and no benchmark [search summary, NOT VERIFIED beyond that]. The 2026-09-26 position stands: the open pieces are the state-binding relation and its cumulative opening and mask budget.
- **The published decoders avoid the question rather than answer it.** DeepProve's abstract says it "certifies the correctness of the output sequence rather than encoding the expensive inference computation in-circuit", avoiding a circuit "quadratic in the sequence length or costly in-circuit modelling of RAM operations" [AUTHORS, abstract]. That reads as a teacher-forced single pass over prompt plus generated tokens, which is what this project's window proof already is. I did not read the body, so whether it carries KV state at all is unverified.
- **Incremental proving would be a step backward for throughput in this project's terms.** The recorded model says one-token-at-a-time decode is about 0.0025 tokens/s against 0.6-0.8 for 512-position prefill because every proof re-proves the weight side (`START_HERE.md:217-219`, MODEL). Reusing old-position work saves nothing the single window pass does not already save (2026-09-26 handoff, H1 section), so the only gain from carrying state is latency for a streaming client, at the price of a state-binding gadget per window.

## 2. What each source does

| Source | State across tokens | Hidden activations | Numbers | Reading |
|---|---|---|---|---|
| ZK-DeepSeek, arXiv 2511.19902 | Two caches (kv cache, pe cache) are loaded from SSD per layer, updated and written back by the plain inference code (full text, Section 5.2); the proofs are per component and merged recursively (o1js). No cache commitment or binding to a previous proof appears in the text. The softmax-qk proof is built "incrementally using segments of size 32" because the head width grows in inference | Stated goal is hiding the model parameters, not activations | CPU proving in o1js, one i9-14900KF plus an RTX 5090 used only for inference; 4,823 s (embedding), 19,275 s (RoPE1), 39,456 s (softmax qk), 204,138 s (wkv a1) [AUTHORS] | Incremental here means a growing softmax input split in segments inside one inference, not reuse of a prior token's proof. Not comparable: hours per component |
| SLP, arXiv 2609.27367 | None. It proves a whole trace and samples chunks. Greedy decoding advances packed request slots in lockstep under a block-diagonal mask | Not an activation-hiding design (commits chunk boundary activations; verifier samples) | Context 8 to 16 raises proving time from 94.8 s to 99.0 s on TinyLlama; 12 packed requests in 181.9 s, 6.5x less than 12 separate proofs [AUTHORS] | Supports "weights dominate, tokens are cheap", the same conclusion as this project's records. Its batching is request packing, the family cycle 2 already priced |
| DeepProve, ePrint 2026/1112 | Not read (403). Abstract: full inference of all generated tokens, sumcheck plus lookups, GPT-2 and Gemma 3 | Abstract does not say | 174 tokens/min GPT-2, 86 Gemma 3, 1,855 distributed, verification 1 to 3.7 s [AUTHORS] | Self-reported; see section 4 |
| VeriAttn, arXiv 2606.16352 | The decode path appends K/V and attends in a TEE-assisted split | No ZK; trusted hardware | 3.86 to 5.42x over a TEE baseline at 10k-token outputs [AUTHORS] | Out of scope: not a proof system |

## 3. What the project's own terms say (DERIVED)

- A driver that re-proves each prefix of length 1..N processes N(N+1)/2 positions: 131,328 at N = 512, 256.5 times one pass (script). A correct streaming driver with append-only state processes N, so state reuse beats prefix re-proving by up to (N+1)/2, but that is the comparison against a naive baseline, not against the existing window proof.
- The costs that remain per new position after reuse are unchanged from 2026-09-26: all layers, FFN, retained-Q checks for the frozen full-square score relation, and the state-binding gadget. The published sources give no figure for the gadget.
- SLP's 8 to 16 context step is +4.4% time for twice the positions (script), a second independent data point that a proof's fixed part, not its position count, sets cost. It argues for larger windows (already the lever), not for carrying state between windows.

## 4. Proposal and falsifiable test

**H163 (no work order).** A multi-window stream may carry the hidden K/V state between windows through the salted-handle construction recorded in D8/D11/D23 with an in-proof binding gadget, instead of re-proving a longer window.
- *Test, local counting, no prover run.* From `shape.rs` and the census, count committed words per window for a W-position window that must also read S old positions of cached K/V: extra rows for the cached K and V planes, their opening claims, and mask pairs under the one-pair-per-claim rule. **Pass:** extra words below 10% of a fresh window at S = W. **Kill:** above 25%, in which case a window of 2W costs less than two windows of W with carried state.
- *Expected effect.* Committed words per request: 0 for today's one-window requests (nothing changes), up for carried state. Proved tokens per second: none expected for the stream cadence; latency only. I do not propose it as a speed item.

## 5. Risks

- Carried state is a cross-receipt interface, which D18 declines for the MVP and the owner has not ruled on beyond the toy statement (2026-09-26 handoff). Any change needs a ruling, a new profile version and re-proving in Lean (D63). The owner shelved size work on 2026-11-09 and put proof gaps first.
- Self-reported throughput claims (DeepProve) say nothing about hidden activations; the project's P1 hides inputs, outputs and intermediate activations (`ZK60_PRIVACY_REQUIREMENTS.md`), a stronger requirement than any source here states.
- A KV commitment that is reopened across proofs spends opening budget and can leak columns (D11 measured leakage at two openings at the endpoint geometry, per the 2026-09-26 handoff).

## 6. Not verified

- DeepProve's body: how it handles the KV cache, whether it hides anything (PDF 403). The unresolved question is whether its "no RAM in-circuit" claim means a single teacher-forced pass.
- TensorCommitments (arXiv 2602.12630) appeared only as a reference entry; not read.
- DeepProve's GitHub README and paper throughput disagree (search summary: 67 and 27 tokens/min at 512 tokens in the README against 174 and 86 in the abstract); not reconciled.
- No Nova/HyperNova decode benchmark exists in what I could reach; absence in 7 searches is not proof of absence.
- Proofs / passes / proved positions from this tick: 0 / 0 / 0. The complete private 8B at >= 50 proved tokens/s remains unachieved. Hypotheses: 163 (H163 added; numbering assumed from tick 14's H161-H162).

## 7. Next actions (no new permission needed)

1. Coordinator: drop item 6 as a speed item; keep H163 only as a counting task if a streaming-latency requirement is ever stated.
2. If anyone can place `eprint.iacr.org/2026/1112.pdf` locally, a reader can settle the DeepProve question in one pass (same blocker as items 9 and 30).
