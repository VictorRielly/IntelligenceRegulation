# zkLLMPoT (arXiv 2610.08258) — literature assessment against hashline

Written 2026-10-17 (about 08:30 UTC) by a Claude literature subagent. Only
reading was done: no builds, no proofs, no git. "Ours" means the hashline
prover and the measured numbers given in the brief and in
`docs/zkmatrix-poc/MVP_STATUS.md`. Labels: **[AUTHORS]** = the paper's own
claim, not reproduced; **[COUNTED]** = my arithmetic on stated numbers;
**[ESTIMATE]** = my rough inference, to be checked before use.

## Plain-words summary (10 lines)

1. zkLLMPoT proves one forward pass of a hidden-weight model on sequences the auditor picks and makes public, then reveals a single loss number. It does not prove training, despite the title.
2. Its headline numbers (41–59 s at 1.1–1.5B, 131 s at 13B, T=512, A100 GPU) are **sums of separate per-operator benchmarks, not one end-to-end proof run**. The inputs were synthetic, not trained weights, and some costs were interpolated or fitted.
3. Several required pieces are absent from both the timings and the text: re-scaling after multiplies, RoPE, the causal mask, softmax's division by the row sum, the vocabulary-wide log-softmax that its own loss needs, and building the witness.
4. The cryptography is zkLLM's (BLS12-381 curve, Pedersen/Hyrax commitments, LogUp, sumcheck), reusing zkLLM's GPU kernels. Per position it is **no faster than zkLLM was in 2024**.
5. At face value it is about 26x faster than our best complete stack (125M shape, T=512). Most of that gap comes from three things: everything runs on an A100 while our sumchecks run on a laptop CPU, the accounting is narrower, and coverage is incomplete. Its proof system is not better: each field operation costs more than ours.
6. Even on its own accounting it does not reach our target. 13B runs at 3.9 positions/s, and 8B would land around 4–9. Our goal is 50 at 8B.
7. Softmax is 56–64% of its prover time. Ours is about half, so the bottleneck is the same even in a fully GPU-resident prover.
8. Its privacy model is roughly the reverse of our P1: weights hidden, inputs public. We cannot adopt its public-input shortcut (P1 is decided).
9. It has no new technique we lack. What it adds is evidence for three levers already on or near our plan (ranked in §5): GPU-resident sumchecks, cheaper softmax normalization, and keeping weight work out of the per-proof path.
10. No code is public. The authors promise it "after the review period", and a GitHub search found nothing on 2026-10-17. The Hollow-LLM ghost-weight critique applies to it (hidden weights). It does not apply to our P1 (public weights), but it will apply to P3.

---

## 0. What was read, and how

- **Paper:** arXiv 2610.08258. v1 is dated 2026-10-06 12:35:49 UTC and v2 2026-10-11 04:45:08 UTC; cs.AI; "18 pages, 4 figures, Preprint". It is formatted for ICLR 2027 (style files in the source); acceptance is not established. The authors are Junkai Liang, Zhanpeng Guo, Pengfei Wu, Qingni Shen, Jiaheng Zhang, Zhonghai Wu, Haiyang Xue and Shengfang Zhai, from Peking University, China Telecom Quantum Information Technology, SMU and NUS. Jiaheng Zhang is also an author of zkGPT.
- **Full text:** I read the complete v2 **LaTeX source** (`arxiv.org/src/2610.08258v2`, sha256 `a274c937…6d49`), every `.tex` file. I also extracted text from the rendered v2 PDF (sha256 `53bea3fd…3a3b`, 18 pages) to get page numbers.
- **v1 versus v2:** the v1 source (sha256 `892562fb…6c19`) has `.tex` files byte-identical to v2. v2 only adds a compiled bibliography (`main.bbl`), so every claim below holds for both versions.
- **Commented-out appendix:** `appendix.tex` contains a whole section, "Details of the Experiments", inside `\iffalse … \fi`. It is not in the rendered PDF. Where I use it, I mark it **[SOURCE-ONLY]**. It is author text the authors chose not to publish, not a claim of the paper.
- **Page map for the rendered v2 PDF:**

  | Page | Contents |
  |---|---|
  | p1 | Abstract, §1 |
  | p2 | Fig. 1 and the contribution list |
  | p3 | §2–2.1 |
  | p4 | §2.2 threat model, §3.1 |
  | p5 | Alg. 1, §3.2 |
  | p6 | §3.2 continued, §3.3 Theorem 1 |
  | p7 | §4.1–4.3 (setup, implementation) |
  | p8 | Table 1, Fig. 2, §4.4–4.5 |
  | p9 | Fig. 3, §4.6, §5 |
  | p10 | Reproducibility statement |
  | p12 | Appendix A and start of B |
  | p13 | B.1–B.2 |
  | p14 | B.3 PCS |
  | p15 | B.4–B.5 |
  | p16 | B.5 normalization and softmax, B.6 |
  | p17 | B.6 numbers, B.7 |
  | p18 | B.7 end |

- **Fetch failures, recorded exactly:**
  - WebFetch on the arXiv HTML would not give near-verbatim text: "I can't reproduce the paper near-verbatim, section by section". I switched to the TeX source.
  - WebFetch on the PDF returned compressed binary: "It is raw, compressed PDF data (FlateDecode object streams …)".
  - The Read tool could not render the PDF: "pdftoppm is not installed". No Python PDF library is installed either. I wrote a small zlib/TJ text extractor in the scratchpad to get page numbers.
  - The DeepProve ePrint PDF (`eprint.iacr.org/2026/1112.pdf`) returned **HTTP 403** to both WebFetch and curl.
  - The Hollow-LLM and GKR-HND HTML pages were read only up to character 100,000 of 127,136 and 113,551 respectively, a WebFetch window limit.
- **Overlap with the hourly researcher:** it already logged this paper in `research/zkp-efficiency/sources.jsonl` (cycles 36, 48 and 57). Its conclusions agree with this note: aggregated microbenchmarks, public audit sequences, no reproducible code. This note adds the source-level detail, the normalization against our numbers, and the adoption ranking.

---

## 1. Exactly what is proved

**The relation (§2.1 p3, §3.1 p4–5, Alg. 1 p5).** Public inputs:
- the architecture A;
- the objective L;
- the auditor's sequences S;
- a commitment to the weights θ;
- the claimed scalar v.

The witness is θ plus the intermediate activations. The claim is v = L(f_{A,θ}(S)), one forward evaluation. The backward pass and optimizer are explicitly excluded (contribution 1, p2; §2.2 last paragraph, p4). Commit-then-challenge is the order of messages (Alg. 1 steps 1–4, p5; §3.2 "Data-related protocol", p6):
1. The auditor fixes L.
2. The trainer commits to the circuit and θ.
3. The auditor reveals S.
4. The trainer proves v.

The default L is masked next-token NLL (eq. 3, p4). Fairness gaps, membership and safety scores only swap the final gadget (§3.2 "Custom loss functions", p6).

**Public versus hidden (B.7 p17–18, §3.2 p5–6).**

| Item | Status |
|---|---|
| A, L, S, quantization parameters, all lookup tables, v, acceptance band | Public |
| Weights θ, every intermediate activation, every data-dependent constant (including the per-row softmax shift, "proved in range rather than revealed", B.7 p18) | Hidden |
| Training data | Never enters the relation |

Compared with our scopes, **inputs are public and only one scalar output is revealed**. That is P3-like on the weights and short of P1 on the inputs.

**Models, sequence length and batch (§4.1 p7).**
- Batch 1, T = 512.
- "Synthetic fixed-point tensors at the dimensions of the public model configurations". **No trained weights were used.**
- Table 1 has four 1.x B shapes: OPT-1.3B, Llama-1.1B (TinyLlama's shape), Qwen2.5-1.5B and DeepSeek-Coder-1.3B.
- The scaling study has 14 configurations from 0.125B to 13B across those four families (§4.5 p8).
- [SOURCE-ONLY] Weights and activations are signed 16-bit fixed point.

**Which operators are in the timed figures.** The abstract and conclusion say "for the covered operators". Fig. 2 (p8) splits proving time into seven terms: Proj, Scores (QKᵀ and PV), Softmax, FFN, Act, Norm and Head. §4.4 (p8) and the [SOURCE-ONLY] per-term table give the numbers.

| Operator | In timed proof? | Where |
|---|---|---|
| Q/K/V/O projections, FFN matmuls, output head W_out | Yes ("fused sumchecks", 4.1–6.0 s total) | §4.4 p8; B.5 p15 |
| Attention products QKᵀ, PV | Yes (4.6–10.3 s) | §4.4 p8 |
| Softmax exponentials (digit decomposition) | Yes (56–64% of proving) | §4.4 p8; B.5 p16 |
| Softmax **normalization** (divide by row sum) | **Not described anywhere** | B.5 p16 describes only the shift and the exponentials |
| LayerNorm / RMSNorm (sum of squares, 1/√ lookup, broadcast product) | Yes (2.6–3.1 s) | §4.4 p8; B.5 p16 |
| GELU / SiLU / ReLU (two-column LogUp) | Yes ("Act", 3.0–5.0 s) | §4.4 p8; B.5 p15 |
| SwiGLU gate×up product | Not itemized | — |
| Residual adds | Free by construction (claim split, no sumcheck) | B.5 p15 |
| **RoPE** | **No gadget, no timing.** "Pos" appears only in the formulation (§3.1 p4) | — |
| **Causal mask** | **Not mentioned** | — |
| **Requantization / rescaling after products** | **Not described or timed.** Only the norm's "proved shift" has a range-checked remainder | B.5 p16 |
| Range reduction into the 4,096-entry activation table [SOURCE-ONLY size] from 16-bit values | Not described | — |
| Embedding | Leftover claims are checked against the public S | §3.2 p6; Alg. 1 step 7 |
| **NLL objective: vocabulary-wide log-softmax** | **Not timed.** "Head" is 0.07–0.64 s, about 0.1–1.5% (§4.6 p9), consistent with the W_out matmul alone | — |
| Witness generation (the forward pass itself) | [SOURCE-ONLY] excluded: per-gadget times exclude "the weight commitment and the forward pass" | appendix.tex (commented out) |
| Weight commitment (138–206 s) | Reported separately as one-time | §4.1 Metrics p7; Table 1 p8 |
| Per-audit activation commitments | **Unclear.** Activations are committed (B.7), but the paper never says whether that time is in "Prove" | §4.1 p7 |

So **the full forward pass is not in the timed proof**. The paper says so: "Our prototype measures the principal Transformer operators" (§1 p2). It also states the totals are "aggregated from per-operator benchmarks" (§4.1 Metrics, p7) and that in Fig. 3 "nonlinear argument costs are interpolated from measured size curves, and their opening-preparation costs are fitted" (Fig. 3 caption, p9).

**[COUNTED] Size of the missing vocabulary softmax.** For Qwen2.5-1.5B the vocabulary grid is 512 × 151,936 ≈ 77.8M entries. All attention-softmax grids together are 28 layers × 12 heads × 512² ≈ 88.1M. For Llama-1.1B the figures are 16.4M against 184.5M.

**[ESTIMATE]** Suppose the NLL's log-softmax cost the same per entry as attention softmax. Qwen's 42.4 s would then grow by roughly 20 s, and Llama's 53.2 s by about 3 s.

---

## 2. Proof system

**Field.** The BLS12-381 scalar field, |F| ≈ 2^255 (B.1 p13; B.6 p17). Tensors are signed fixed point at a public scale s, reduced mod p and padded to 2^n (eq. 6–7, B.1).

**Commitment.** Pedersen vector commitments in the Hyrax matrix layout: one group element per row, rows blinded with ρ_i·h (B.3 p14; §4.2 p7). Openings fold the row commitments homomorphically. A Bulletproofs-style inner-product argument then proves the inner product, so the folded row is never sent (B.3 "Adding hiding", p14; B.7 "Blinding the opening", p18).
- **Setup:** only generators of unknown relative discrete log are needed. That makes it **transparent, with no trusted setup**, though the paper never uses the word. It rests on discrete-log hardness and is not post-quantum.
- **Implementation:** CUDA/C++ prover reusing **zkLLM's BLS12-381 GPU kernels**. The verifier is a separate CPU binary built on mcl (§4.2 p7).
- **Weight commitments:** computed once per checkpoint and reused across audits; activation commitments are made per audit (§3.2 p5).

**Linear layers.** Standard matmul sumcheck: fold X over u_B and W over u_O first, then run the sumcheck only over the contracted dimension (eq. 15, B.5 p15). One gadget serves the projections, FFN, head, QKᵀ and PV.

**Lookups.** A LogUp-style log-derivative argument (B.5 eq. 16–17, p15–16):
- Two-column tables (input, output) are folded with **one global random r**.
- It runs as a two-phase sumcheck over log(D/N) and log N variables, which requires D to be a multiple of N.
- Tables are public and recomputed by the verifier.
- Lookups are "batched across the network".
- [SOURCE-ONLY] Table sizes: a 4,096-entry activation table at scale 256, a 65,536-entry 1/√ table, and four 256-entry digit tables per softmax.

**Normalization (B.5 p16).**
1. A sum-of-squares sumcheck of degree 3 computes the row statistic.
2. A "proved shift" with a range-checked remainder brings it into table range.
3. One 1/√ lookup is made per row.
4. A degree-3 sumcheck computes the broadcast product.

**Softmax (B.5 p16).** This is zkLLM's zkAttn exponent technique:
- Each score row is shifted to be non-positive.
- The shifted value is written in mixed radix with K digits, each with its own public exp table.
- The exponential is the Hadamard product of the digit images, a sumcheck of degree K−L+1 = 4, the highest degree in the protocol.
- Low digits are only range-checked, and the top digit saturates.
- All heads of a layer share one argument.
- **How the result is divided by the row sum is not described.** zkLLM itself handles it by choosing the shift so that row sums land in a tolerance band, checked by one lookup per row; see §5.

**Composition (Alg. 1 steps 5–7, p5; B.4 p15).**
- Claims are reduced backwards layer by layer, GKR-style. Each layer's sumcheck turns an output claim into an input claim plus a weight claim.
- The verifier checks that consecutive claims are equal ("chaining").
- Leftover claims on S are evaluated in the clear; claims on committed tables are opened.
- There is one proof with no recursion: 1,166 to 1,926 arguments per 1.x B model (B.6 p17).
- Alg. 1 is written interactively. Fiat–Shamir is not discussed, though the paper calls the result a zk-SNARK.

**Zero knowledge (B.7 p17–18).** Hyrax row blinding gives perfectly hiding commitments, and the IPA openings reveal only y. Each sumcheck's round polynomials are masked (Chiesa et al. 2017 / Libra), at the cost of one extra committed polynomial per argument. No simulator proof is given beyond this sketch.

**Soundness.** Theorem 1 (p6; proof in B.6 p16–17) is a union bound over three terms: per-argument sumcheck and lookup errors, the aggregate IPA error, and the discrete-log advantage.
- The statistical part is below 2^-209 for all four models.
- Assuming an IPA error ≤ 2^-128 and a DL advantage ≈ 2^-128, the total is about **127 bits** (B.6 p17; §3.3 p6–7).

---

## 3. Numbers

**Hardware (§4.1 p7).** NVIDIA A100-PCIE 40 GB, Xeon with 80 threads, 629 GB RAM, CUDA 12.4. The authors note up to 70× slowdowns when the GPU was shared, and state the reported runs were unshared. [SOURCE-ONLY] The commented-out appendix instead calls it "a rented container", which conflicts with the rendered "dedicated … server". **No memory or VRAM figures are reported.**

**Table 1 (p8) [AUTHORS], T = 512, with positions/s [COUNTED]:**

| Model | Commit W (one-time) | Prove | Verify | Proof | Positions/s, prove only | Positions/s if W commit is paid |
|---|---:|---:|---:|---:|---:|---:|
| OPT-1.3B | 175 s | 58.8 s | 428 ms | 17.0 MiB | 8.7 | 2.2 |
| Llama-1.1B | 138 s | 53.2 s | 423 ms | 17.3 MiB | 9.6 | 2.7 |
| Qwen2.5-1.5B | 206 s | 42.4 s | 416 ms | 19.9 MiB | 12.1 | 2.1 |
| DeepSeek-Coder-1.3B | 171 s | 41.0 s | 406 ms | 16.9 MiB | 12.5 | 2.4 |

**Scaling (§4.5 p8, Fig. 3 p9) [AUTHORS].**
- Covered proving rises from 15.7 s at 0.125B to 130.6 s at 13B. In positions/s that is **32.6 → 3.9** [COUNTED].
- Weight commitment costs 124–142 s per nominal billion parameters.
- Verification stays under 0.5 s.
- Linear shapes were measured. Nonlinear costs were interpolated, and opening preparation was fitted.

**Per-operator breakdown (Fig. 2 and §4.4 p8; exact values from the [SOURCE-ONLY] per-term table, which sums exactly to Table 1), in seconds:**

| Model | Proj | Scores | Softmax | FFN | Act | Norm | Head | Total | Softmax share |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| OPT-1.3B | 2.01 | 10.31 | 37.08 | 2.37 | 4.08 | 2.87 | 0.10 | 58.82 | 63% |
| Llama-1.1B | 1.54 | 9.45 | 33.99 | 2.51 | 3.03 | 2.64 | 0.07 | 53.25 | 64% |
| Qwen2.5-1.5B | 1.71 | 4.57 | 23.77 | 3.64 | 5.04 | 3.06 | 0.64 | 42.44 | 56% |
| DeepSeek-Coder-1.3B | 2.01 | 5.23 | 24.72 | 2.83 | 3.27 | 2.87 | 0.08 | 41.00 | 60% |

[SOURCE-ONLY] Opening preparation is 42% of each linear argument's time.

**Comparison with zkLLM, the paper's own base, which it does not compare against [AUTHORS of zkLLM, CCS 2024, Table 1].** At T = **2048** on an A100 SXM4 40 GB:
- OPT-1.3B proves in 221 s, which is **9.3 positions/s**.
- LLaMA-2-13B proves in 803 s, which is 2.55 positions/s.
- Proofs are about 147–188 kB, verified in 0.9–3.95 s.

So on a per-position basis zkLLMPoT at T = 512 (8.7 positions/s on OPT-1.3B) is **no faster than zkLLM**, even though attention per position at T = 2048 is four times larger. Its proofs are about 100 times larger (17 MiB against 147 kB).

**Is "tokens/s" comparable to ours?** Only as **prefill positions per second over one 512-token sequence**, which is also how we count, but with large differences:
- **What is counted:** their figure is an aggregate of operator benchmarks that excludes witness generation and possibly the per-audit activation commitments. Ours is the whole test wall.
- **Coverage:** see §1.
- **Hardware:** A100 against the 4070 Laptop.
- **Inputs:** synthetic.

None of these is autoregressive decode.

---

## 4. Is it more efficient than us?

**Face-value comparison [COUNTED]:**

| System, workload | Hardware | Rate (positions/s) |
|---|---|---:|
| zkLLMPoT 0.125B, T=512, covered operators, prove only | A100 | 32.6 |
| Ours, synthetic 125M shape (width 768, FFN 2048), 12 blocks, T=512, complete private stack, whole wall | 4070 Laptop, GPU commitments | 1.25 |
| zkLLMPoT Llama-1.1B (TinyLlama shape), T=512 | A100 | 9.6 |
| Ours, trained TinyLlama, 3.5 s per block × 22, T=32 | Laptop CPU | ≈0.42 (extrapolated, not a stack run; T=32 attention is tiny) |
| Ours, model projection: 1B, 22 blocks [MVP_STATUS, MODEL] | Laptop GPU arm | 0.62 |

At the 125M shape that is a **≈26× face-value gap**. Between their 1.1B figure and our 1B projection it is about 15×.

**Normalization: what explains the gap, factor by factor.**

| Factor | Favors | Size |
|---|---|---|
| **Where the sumchecks run.** Theirs: everything on GPU (sumcheck, LogUp, openings). Ours: GPU only for commitments; slots, witness and sumcheck on a laptop CPU. | Them | Our own model puts this lever at about 8–10× (8B on a 5090: 0.62–1.23 → 5.1–12.6 tok/s; 1B: 10.5–26.1 tok/s; MVP_STATUS [MODEL]) |
| **Hardware.** A100-PCIe (1,555 GB/s HBM) against the RTX 4070 Laptop (256 GB/s). Sumcheck is mostly memory-bound. | Them | Up to about 6× on bandwidth [ESTIMATE] |
| **What is counted.** Their aggregate excludes witness generation [SOURCE-ONLY] and perhaps per-audit activation commitments (§3). Ours includes everything; in a private block the commitments alone are about 25%. | Them | Unknown. [ESTIMATE] Llama-1.1B at T=512 has about 0.7–1.4 billion committed activation, digit and score entries per audit, of the same order as its 1.1B weights, whose commitment took 138 s. If that cost is outside "Prove", it is not small. |
| **Coverage.** Missing: requantization, RoPE, causal mask, softmax normalization, NLL vocabulary softmax (§1). | Them | Probably tens of percent [ESTIMATE]. Our softmax division alone carries three extra per-entry tensors and three range lookups (§5). |
| **Field arithmetic.** 255-bit Montgomery (8×32-bit limbs) against 64-bit Goldilocks plus an extension field for challenges. | Us | Several-fold per multiply in our favor [ESTIMATE] |
| **Privacy.** They also hide the weights: per-audit weight openings, hiding weight commitments. They do not hide the inputs. Activation hiding exists in both. | Roughly neutral | — |
| **Soundness.** About 127 bits (theirs) against about 94–97 bits (ours). | Us (they pay for more) | Small |

**Verdict.**
- **No, it is not shown to be more efficient than our proof system.** The face-value gap of about 15–26× is explained, to within the uncertainty, by a fully GPU-resident prover on a datacenter GPU, plus narrower accounting and incomplete coverage.
- Per field operation their construction is heavier than ours. Our own full-GPU projection for 1B on a 5090 (10.5–26.1 positions/s [MODEL]) is at or above their 9.6 on an A100, but that is a projection, not a measurement.
- **Where they are really better:**
  - **Proof size:** 17–20 MiB for a whole 1.x B model at T=512, against our 11.6 MB *per block* at T=32 and 41 MB per 125M block at T=512.
  - **Verifier time:** about 0.42 s for the whole model, against our 0.3 s per block (about 6.6 s for 22 blocks [COUNTED]).

  Both follow from Hyrax's square-root commitments with log-size IPA openings, set against Merkle-path openings.
- **Linear layers are roughly at par.** Their fused linear sumchecks take 4–6 s for about 1B of matmul weights on an A100. Our public-IO Mistral-7B FFN runs about 5.6B FFN weights in 38.6 s of activation-side time on the laptop (MVP_STATUS). Scopes differ (public IO, includes commitments), so treat this as a same-order sanity check only.

**Where the comparison is invalid outright:**
1. **Public sequences.** Inputs are public in their relation and hidden under P1. The embedding and first-layer leftover claims are evaluated in the clear in theirs; ours must stay committed.
2. **Synthetic inputs.** Their timings use synthetic tensors and are never an end-to-end proof. They break our "generic honest witness" rule for any "proves and verifies" claim.
3. **Fixed point is never checked against floating point.** §4.6 (p9) cites published floating-point loss deltas and does not measure its own fixed-point model's loss.
4. **Different sequence lengths for the trained block.** Our trained-TinyLlama figure is at T=32 and theirs at T=512.

**Against our goal, even at face value.**
- 13B runs at 3.9 positions/s.
- An 8B model would fall between their 1.3–1.5B points (8.7–12.5) and 13B (3.9), so roughly 4–9 positions/s on an A100. That is **6–13× short of 50**, before adding the missing operators.

---

## 5. What could we adopt?

### Candidate techniques, checked against P1 (hidden inputs, outputs and activations; public weights) and our transparent hash-based PCS

| Technique (source) | What it is | P1 and hash PCS compatible? | Effect on our bottlenecks | Effort | Risks | Verdict |
|---|---|---|---|---|---|---|
| **A. Whole prover on the GPU** (zkLLM CUDA design, reused by zkLLMPoT §4.2 p7). All heads of a layer in one argument (B.5 p16); lookups batched across the network (B.5 p15). | Sumcheck rounds, LogUp numerators and denominators, batch inversions and openings all resident on the GPU, with layer-wide instances | Yes. Sumcheck and LogUp are agnostic to the field and the PCS, and Goldilocks is cheaper per operation than BLS12-381. | Hits softmax (about half of prover time), lookup inversions (15% of a private block) and witness generation. Our model: about 8–10× at 8B. | Large (weeks, several lanes) | VRAM (8 GB laptop; WSL freezes on overflow); byte-identity with the CPU reference; resource-guard discipline | **#1**, already the MVP's projected lever. zkLLMPoT and zkLLM confirm it works at 1B, T=512 even with 255-bit arithmetic. zkLLM's code (`jvhs0706/zkllm-ccs2024`, MIT per GitHub's license field, last push 2025-07-10) can serve as a kernel-structure reference only: different field, no direct port. |
| **B. Normalize softmax in the exponent and check only a per-row sum band** (zkLLM §5 zkAttn; zkLLMPoT inherits the digit exponent but leaves normalization undocumented) | Shift each row by a committed log-sum-exp offset ẑ, so the exp-table output is already the probability. Then prove each row sum lies in [θ−E, θ+E] with **one range lookup per row**, instead of an exact per-entry floor division. | Yes: ẑ is committed and hidden, row sums are never revealed, and the hash PCS is unaffected. Needs a privacy re-check of the joint view. | Today `ATTENTION_INTEGER_SPEC.md` §2.5 has, per score entry: the argmax selector zsel (binary range), the d range plus exp lookup, the division tensors P, ρ and σ, two 18-bit and one 10-bit range lookups, and a degree-3 division zero-check. Option B keeps roughly d plus the exp lookup per entry. **[ESTIMATE]** It could remove half or more of softmax-entry work, so on the order of 20–30% of prover time, **if** division and argmax dominate our softmax cost. Count this with the throughput model before any build. | Medium: spec change, Python reference, Rust gadget, error bound, privacy re-check | Changes our exact integer semantics to an **approximate relation with prover slack**: any ẑ inside the band is accepted, a small adversarial bias on attention. Our spec chose exactness on purpose. Needs a Decisions-register ruling. Byte-identity holds only if the reference fixes a deterministic ẑ rule. | **#2**, conditional on a count and a ruling |
| **C. Weight work out of the per-proof path** (zkLLMPoT §3.2 p5: "weight roots are computed once per checkpoint and reused"; §4.1 p7 reports W commit separately) | Commit to (or preprocess) the public weights once per model, pin the root in the statement digest, and make only per-proof openings | Yes, and simpler than theirs: under P1 the weights are public, so the commitment needs no hiding and anyone can recompute and check it | The W phase was 19.8 s of 58.4 s (34%) in the 8B public-IO FFN run, and both commitments are about 25% of a private block. It also enables the two-tier opening (lanes QQ/VV). | Medium; partly built (`--wcache`, preprocessed-weights plan in START_HERE §5) | The warm path is unmeasured; the root must be bound in the statement; no reuse of hiding masks (not needed for public weights) | **#3**, already planned. The paper supports charging only activation-side work per proof; finish and measure the warm path. |
| D. Digit-decomposed exp (zkLLMPoT B.5 p16) | K digit tables with a degree-4 product | Compatible | **Worse for us.** Our int8 requant plus exact row max gives a single 256-entry lookup per entry; theirs needs 4 lookups and a degree-4 product. | — | — | Do not adopt |
| E. Hyrax/Pedersen over BLS12-381 | Curve PCS with square-root commitments and IPA openings | Not compatible with the transparent hash-based PCS line; heavier field; not post-quantum | Only proof size and verifier time (not our bottlenecks) | — | — | Do not adopt |
| F. One global fold challenge r for two-column lookups (B.5, Lemma 3 p16) | Folds (in, out) pairs with one r | Safe only in a large field. Their DN/\|F\| term is below 2^-220 at 255 bits; in Goldilocks base field it would be about 2^35 / 2^64 = 2^-29. | — | — | Must keep extension-field challenges, which we already do | Pitfall to note, not a lever |
| G. Fused linear sumchecks, residuals as free claim splits, fold-first matmul sumcheck (B.5 p15) | Standard GKR/Thaler techniques | Compatible | FFN is about 5% of a private block, so little left to gain | Low | — | Already in our design or low value |
| H. Commit-then-challenge with public audit sequences | Audit protocol order | The public-S part violates P1 (decided; must not be reopened) | — | — | — | Do not adopt. The order itself only matters for a future audit product. |

### Top 3, ranked

1. **Put every sumcheck, LogUp argument and the witness build on the GPU, with layer-wide batched instances.** This is the largest lever we know (about 8–10× by our model). zkLLMPoT and zkLLM are external evidence that a fully GPU-resident sumcheck/LogUp prover handles 1B at T=512 in under a minute, even on a 255-bit field.
2. **Count, then consider, zkAttn-style softmax normalization.** That means a log-sum-exp offset plus a per-row sum band in place of per-entry exact division. It targets the operator that is about half of our time and 56–64% of theirs. Because it changes exact semantics into a bounded-slack relation, it needs a ruling.
3. **Finish moving weight-side work out of the per-proof path,** through preprocessed or cached public-weight roots bound in the statement. Under P1 this is easier than in zkLLMPoT because no weight hiding is needed. Measure the warm path.

---

## 6. Soundness and privacy concerns relevant to us

1. **The evidence is aggregated, not end-to-end.**
   - Totals are sums of per-operator benchmarks (§4.1 p7). Nonlinear costs are interpolated and opening preparation is fitted (Fig. 3 caption, p9).
   - The "Effectiveness" dimension promised in §4 (p7) has no reported result.
   - Inputs are synthetic.
   - The same caution applies to any "X tokens/s" we quote from it.
2. **Several gadgets are undescribed, a risk of an under-constrained circuit.**
   - No requantization or rescaling gadget after matmuls: unconstrained rounding gives the prover freedom in the low bits.
   - No causal mask.
   - No RoPE.
   - No range reduction into the 12-bit activation table.
   - No softmax normalization. The per-row shift is only "proved in range" (B.7 p18), not proved to be the row maximum. Without a normalization constraint, a prover could scale all of a row's probabilities.
   - The 2609.10149 paper ("Sound Debloating…") is a reminder that missing range facts are exactly how zkML circuits become forgeable.
3. **The composition argument is drawn as a chain, but the model is a DAG.** Theorem 1's proof (B.6 p17) hands each false claim to "one determined predecessor". The residual stream and the shared norm output feeding Q, K and V create several claims on one tensor, and how those are combined (random linear combination, or separate openings) is not described. This is a gap in the exposition, not necessarily a break.
4. **Fixed-point fidelity.** It proves the 16-bit fixed-point model [SOURCE-ONLY width], never compared with floating point (§4.6 p9 argues only from published loss deltas). This matches our calibration-fidelity lane's concern.
5. **Hollow-LLM (arXiv 2607.28884, IEEE S&P 2026).** Because zkLLMPoT hides the weights, a trainer could commit a "13B" checkpoint that is a smaller model padded with zero-work residual blocks or width-replicated blocks ("ghost weights", Hollow-LLM §IV) and still prove an honest loss.
   - The loss audit itself stays sound: v is computed correctly.
   - Any reading of the certificate as "this is a 13B model" or "this much training compute" is not supported.
   - **For our P1** (public weights) the attack is explicitly out of Hollow-LLM's scope (its §III-A): anyone can inspect the weights. We must still bind the evaluated weights to the published release digest.
   - **For P3** (hidden weights) it applies to us. We would need an extra binding (attested release hash, non-degeneracy or effort evidence), or we must state the limitation. Worth a pending entry in the decisions register when P3 opens.
6. **Zero knowledge is argued, not proved.** It is a sketch: Hyrax hiding, masked sumcheck, IPA openings (B.7). There is no simulator, Fiat–Shamir is not discussed, and the round-polynomial masking is cited rather than shown. Their privacy model also reveals S and v by design, so it says nothing about hiding inputs, which is P1's hardest part.
7. **Reproducibility.** "We will open-source our implementation after the review period" (Reproducibility statement, p10). GitHub repository search on 2026-10-17 returned **0** results for `zkllmpot`; the `llmpot` hits are unrelated honeypot projects. There is no project page and no license. Nothing can be run or checked.
8. **Naming.** "Proof of Training" here means a proof of one forward evaluation of a committed checkpoint (§2.2 p4, last paragraph). Do not cite it as evidence that training can be proved.

---

## 7. Where it sits among 2026 LLM ZK systems

| System | Date / venue | Proof system | Privacy | Headline numbers [AUTHORS] | Relevance to us |
|---|---|---|---|---|---|
| **zkLLM** (2404.16109) | Apr 2024, CCS 2024 | Hyrax/Pedersen, BLS12-381; tlookup; zkAttn | Weights hidden; prompt from the verifier | T=2048, A100: OPT-1.3B 221 s; LLaMA-2-13B 803 s; proofs 141–188 kB; verify 0.34–3.95 s | zkLLMPoT's base. DeepProve's authors say zkLLM covers only components such as softmax rather than whole inference. |
| **zkGPT** (ePrint 2025/1184) | USENIX Sec 2025 | Not stated on the abstract page; constraint fusion, "circuit squeeze" | Weights hidden | GPT-2 in under 25 s; 279× over Hao et al., 185× over ZKML | DeepProve calls it a single-token proof of concept |
| **ZKTorch** (2507.07031) | Jul 2025 | Parallel Mira accumulation, BN254 | Weights hidden | LLaMA2-7B, 1 token: 2,645.5 s prove, 100.14 s verify, 64-thread Xeon (explorer record, cycle 25; not re-read today) | Architecture lead only |
| **NanoZK** (2603.18046) | Mar 2026 (v2 Jul 18), ICICS 2026 | Layerwise Halo2-style proofs chained by SHA-256 commitments; 16-bit LUT approximations | Weights and activations hidden from the verifier; prompt visible to the prover | MLP sub-circuit about 6.3 s prove on CPU; attention up to 184 s at d=256; GPU about 68 s per block at d=768 is a **projection**; about 83 KB total at L=12 | Independent layer proofs conflict with our single-transcript composition (D12) |
| **GKR-HND** (2607.21162) | Jul 2026 | GKR, ML-KZG over BLS12-381, in-process SRS | **Not zero knowledge**; full public witness; honest verifier plus a non-colluding worker | HND-124M at T=8: about 1,093 s prove, single-threaded CPU; needs a modified (polynomial-surrogate) architecture | Not comparable; trust model incompatible |
| **Hollow-LLM attack** (2607.28884) | Jul 2026, S&P 2026 | Attack on private-weight zkLLM/zkGPT-style systems | — | Ghost weights pass verification at the declared size while serving a small inner model | See §6.5 |
| **DeepProve** (ePrint 2026/1112) | CCS 2026 | Sumcheck and logup-GKR on Ceno's sumcheck/GKR code (field and PCS not confirmed this pass; PDF returned HTTP 403) | Not stated | Gemma 3 about 86 tokens/min, GPT-2 about 174/min (paper abstract); README says 0.45 and 1.12 tok/s at 512 tokens on a 24-core CPU; distributed about 1,855 tokens/min; Gemma-3 perplexity about +4% (Lagrange update) | Closest "end-to-end" competitor. Open source under a "Lagrange License" whose terms I did not inspect. Worth a dedicated read. |
| **OpenLLM** (ePrint 2026/1578) | Aug 2026 | Modular per-operator zkSNARKs | Zero knowledge (title) | No numbers on the abstract page | Unread |
| **Bits Under ZK-LLM** (2609.36437) | Sep 29 2026 | Quantization study | — | Activation precision matters more than weight precision; **RMSNorm inverse-square-root lookups are a recurring bottleneck**, fixed by raising precision only there | Directly relevant to the D24 norm-precision ruling |
| **Sound Debloating** (2609.10149) | Sep 2026 | Abstract interpretation over ezkl/zkml circuits | — | Up to 48.7% fewer constraints, up to 72.8% less prover time, soundness preserved | A lead for auditing our many range facts; not top 3 |
| **zkComposer** (2607.08095) | Jul 2026 | Sub-proofs linked by shared activation commitments | Weights hidden | 4.83–6.84× over zkGPT through layer and sequence parallelism | Multi-GPU lever; conflicts with D12 unless analyzed |

**October 2026 newcomers.** An arXiv API search on 2026-10-17 (ZK, zkML, SNARK, verifiable inference and sumcheck terms, sorted by date) found only zkLLMPoT in scope. Two others are adjacent and not LLM forward proofs: StateSync-GKR (2610.14849, a reusable sparse GKR engine) and VeriRouter (2610.17431, ZK proofs for LLM routing). On the ePrint side, I did not survey October beyond the hits above.

---

## Sources (all accessed 2026-10-17)

- zkLLMPoT abstract and history: https://arxiv.org/abs/2610.08258. HTML v2: https://arxiv.org/html/2610.08258v2. PDF v2: https://arxiv.org/pdf/2610.08258v2. TeX source: https://arxiv.org/src/2610.08258v2 and https://arxiv.org/src/2610.08258v1. Local scratch copies were hashed (sha256 values in §0) and are not retained in the repo.
- GitHub repository search via `gh api search/repositories?q=zkllmpot`, returning 0 results; `q=llmpot` returned 7 unrelated honeypot repos.
- zkLLM: https://arxiv.org/abs/2404.16109 and https://arxiv.org/html/2404.16109v1 (Table 1, §5, §7.2). Code: https://github.com/jvhs0706/zkllm-ccs2024 (license field MIT per the GitHub API).
- Hollow-LLM Attack: https://arxiv.org/abs/2607.28884 and https://arxiv.org/html/2607.28884v1 (read to character 100,000 of 127,136).
- GKR-HND: https://arxiv.org/abs/2607.21162 and https://arxiv.org/html/2607.21162v1 (read to character 100,000 of 113,551).
- NanoZK: https://arxiv.org/abs/2603.18046.
- zkGPT: https://eprint.iacr.org/2025/1184 and https://www.usenix.org/conference/usenixsecurity25/presentation/qu-zkgpt.
- ZKTorch: https://arxiv.org/abs/2507.07031, through the explorer's record `cycle25-ZKTorch-parallel-accumulation-older` in `research/zkp-efficiency/sources.jsonl` (not re-read today).
- DeepProve: https://eprint.iacr.org/2026/1112 (abstract page; the PDF https://eprint.iacr.org/2026/1112.pdf returned HTTP 403) and https://raw.githubusercontent.com/Lagrange-Labs/deep-prove/master/README.md.
- OpenLLM: https://eprint.iacr.org/2026/1578.
- Abstracts fetched through the arXiv API (`export.arxiv.org/api/query`):
  - 2609.36437 (Bits Under ZK-LLM)
  - 2609.10149 (Sound Debloating)
  - 2607.08095 (zkComposer)
  - 2609.10264 (Maverick)
  - 2606.16352 (VeriAttn)
  - 2610.14849 (StateSync-GKR)
  - 2610.17431 (VeriRouter)
- Our side, read only:
  - `docs/zkmatrix-poc/MVP_STATUS.md` (headline rates, the [MODEL] projection table, the private-block time split, the W-phase table)
  - `docs/zkmatrix-poc/ATTENTION_INTEGER_SPEC.md` §2.5 (our softmax)
  - `docs/zkmatrix-poc/START_HERE.md` (two-tier opening, preprocessed weights)
  - `research/zkp-efficiency/sources.jsonl` (explorer records cycles 2, 25, 36, 48, 53, 57)
