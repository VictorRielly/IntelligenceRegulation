# DeepProve-class provers and ours: where the gap is and what transfers (2026-10-30)

Written 2026-10-30 20:45 UTC by a Claude research agent for Victor's question
(console, 2026-10-30): *"Could our proofs use some of the techniques employed by
DeepProve to catch that 100x speedup?"*

This was read-only work plus web reading. There was no build, proof, benchmark or
git write. The one local probe was the arithmetic in `gap_calc.py`, run through
the guard as a light job: under 1 s, peak RSS about 0 GiB. Its output is
`gap_calc.out`.

Labels:
- **[MEASURED]**: one of our runs, on the shared laptop, n = 1.
- **[CLAIMED]**: an author's or vendor's number that we have not reproduced.
- **[COUNTED]**: exact arithmetic on published shapes or our layout.
- **[MODEL]**: an estimate from the speed plan's fitted laws.
- **[INFERRED]**: my own estimate. Its basis is stated each time.
- **unknown**: the information was not available.

## Plain-words summary (deliverable 4)

**DeepProve is not 100× faster than us at the same work.** Its published
single-machine run (Gemma-3-1B, 512 tokens, 24-core server, nothing hidden)
proves 3.3–4.6×10⁸ multiply-adds per second. Our hidden Shieldstral-3B proof
does 8.6×10⁸ on 8 laptop threads. Its lead in tokens per second comes from a
model four times smaller. The headline 1,855 tokens/min (110× ours) also spreads
proofs over several machines; how many is not stated anywhere I could read.

The provers far ahead per unit of work run on datacenter GPUs. Hardware and our
measured CPU-to-GPU gain explain all of zkLLM's 40× lead and about 97× of
Attestable's claimed 1,900×. The rest is GPU engineering the speed plan already
counts.

**Hiding costs about 12% today, an estimated 5% at the 8B target.** It is not the gap.

DeepProve commits less: lookups without committed helper columns, wider range
tables, no stored copies of values that follow linearly. Made zero-knowledge,
these could buy 1.5–2× on a GPU. They would lower the kernel efficiency that
50 tokens/s needs from about 34% to 17–23%, and shrink receipts 2–3×.

**First:** Sol keeps moving the whole prover onto the GPU. The researcher
measures a masked LogUp-GKR against our helper columns.

---

## 0. What was read

All accesses were on 2026-10-30.

| Source | Date of source | What was actually read | Gaps |
|---|---|---|---|
| DeepProve paper, [ePrint 2026/1112](https://eprint.iacr.org/2026/1112) | received 2026-05-30, approved 2026-06-02; "CCS 2026, minor revision" | Abstract page only: about 174 tokens/min (GPT-2) and 86 (Gemma 3); "20-60 faster than the state of the art"; verification 1–3.7 s; distributed proving 1,855 tokens/min | **The PDF returned HTTP 403** to both the fetch tool and curl. Hardware, node count, Gemma size and proof sizes for the paper's numbers are **unknown** |
| [IACR news item 28656](https://iacr.org/news/item/28656) | 2026-06-02 | The same abstract numbers | — |
| [github.com/Lagrange-Labs/deep-prove](https://github.com/Lagrange-Labs/deep-prove) at commit `9d1a53e2ef49` (2026-05-26, after v2.0.1 of 2026-05-15) | — | Root README; `zkml/README.md`; `docs/src/overview.md`; `zkml/docs/src/{commitments, end_to_end_lu, lookups, LLMs, softmax, range_check}.md`; `llms-layers/qkv.md`; `zkml/Cargo.toml`; `zkml/src/lib.rs`; `CHANGELOG.md` (grep only) | The license is the restricted "Lagrange License", so no code was copied. The README publishes no GPU benchmarks |
| lagrange.dev blog and docs.lagrange.dev | — | **HTTP 403** on every page tried | Not read |
| zkLLM, [arXiv 2404.16109](https://arxiv.org/abs/2404.16109) | v1 2024-04-24, CCS 2024 | Abstract: 13B in under 15 min, proof under 200 kB, tlookup, zkAttn, weights kept private | Table 1 figures come from our earlier reading, `results/zk60_lit_zkllmpot_20261017/ASSESSMENT.md`: LLaMA-2-13B, T = 2048, A100 SXM4 40 GB, 803 s, 147–188 kB, verify 0.9–3.95 s. The PDF was not re-read today |
| EZKL, [github.com/zkonduit/ezkl](https://github.com/zkonduit/ezkl), [docs.ezkl.xyz](https://docs.ezkl.xyz/) | — | Halo2 backend; GPU through Icicle; v21.0.0 audited by Trail of Bits; no LLM benchmark | That docs page does not cover the visibility settings |
| Attestable, [attestable.com/blog/proving-llms-scale](https://attestable.com/blog/proving-llms-scale) | no date on the page; company launched 2026-08-11 ([niteagent.com, 2026-08-14](https://niteagent.com/blog/verify-ai-inference-attestation-zk-guide/)) | See the paragraph below the table | No proof system named; no artifact. A secondary source repeats an unverified "85 tok/s, 30B, across H100s" |
| zkGPT, [ePrint 2025/1184](https://eprint.iacr.org/2025/1184) | USENIX Security 2025 | GPT-2 in under 25 s; 279× over Hao et al. and 185× over ZKML | Hardware not on the page |
| NanoZK, [arXiv 2603.18046](https://arxiv.org/abs/2603.18046) | v2 2026-07-18 | Layerwise Halo2 proofs chained by SHA-256; weights and activations hidden from the verifier; 16-bit nonlinear approximations; about 68 s per block projected on a GPU at d = 768 | — |
| Seal, Then Sample, [arXiv 2609.27367](https://arxiv.org/abs/2609.27367) | v1 2026-09-23 | Sampled layerwise proofs, probabilistic audit; at 70B, 5 of 163 chunks proved in 1,259 s with a 4.34 MiB proof | Not a complete proof |
| Maverick, [arXiv 2609.10264](https://arxiv.org/abs/2609.10264) | v1 2026-09-09 | Delegated matrix-vector products with LPN masking | Not a ZK proof of the whole inference |
| Gemma-3-1B configuration, [Hugging Face mirror](https://huggingface.co/unsloth/gemma-3-1b-it/raw/main/config.json) | — | d 1152, F 6912, 26 layers, 4 heads, 1 KV head, head_dim 256, vocabulary 262,144 | — |

**What Attestable's post says:**
- Model and speed: Gemma 4 31B; "53 tokens per second for a batch-one 16K sequence"; "77 tokens per second across four 4K sequences"; on a single H100.
- Proofs: 4.35–7.92 MiB; verification 157–648 ms.
- Security: "100 bits", hash-only, post-quantum.
- Arithmetic: nonlinear operations are proved in floating point; matrix multiplications are int8.
- Privacy: the weights are hidden. Whether the prompt and the activations are hidden is not stated.
- Status: "alpha".

**Repository material read:**
- `docs/zkmatrix-poc/START_HERE.md`
- `MVP_STATUS.md` (the 2026-10-30 entries)
- `ZK60_SPEED_PLAN_20261017.md`
- `ZK60_THROUGHPUT_TARGET.md`
- `ZK60_SOL_ASTRA_TODOS_20261026.md` (backlog S4–S7)
- `PROVING_CHANNEL_OPTIONS.md` §2
- `results/zk60_1b_native_20261017/r4/PHASES_T128.md`
- `results/zk60_1b_native_20261017/r12/SHIELDSTRAL_COST.md`
- `results/zk60_gpu_zerocheck_20261017/REPORT.md`
- `results/zk60_astra_20261026/real_app_demo_1/violence.json` (the timing fields only)
- `apps/proven-media/README.md`
- `results/zk60_token_io_r1_20261017/classifier/DESIGN_CLASSIFIER.md` §8
- `research/zkp-efficiency/{AGENDA,STATE}.md`, and `FINDINGS.md` by search
- the fraction-tree and mask-census handoffs
- the frozen tree `results/zk60_token_io_r1_20261017/frozen-r19b/{hashline,zkp-core}/src/`, specifically:
  - `zkp-core/src/pcs.rs` (header and ZK encoding)
  - `hashline/src/zk.rs` (header)
  - `hashline/src/pcs.rs`
  - `private_block.rs` (header)
  - `private_block/layout.rs` (header and P-3)
  - `private_block/shape.rs` (plane lists, lookups, claim sites, slot schedule)
  - `private_block/run.rs` (header)

`results/zk60_1b_profile_20260929/` holds the September 1B profiling recovery
logs. It has no phase table newer than r4, so I did not use it for numbers.

### What our prover actually is (from the source)

- **PCS.** A Ligero/Brakedown-class multilinear commitment over Goldilocks with an
  Fp2 extension (`zkp-core/src/pcs.rs:1-27`):
  - Reed–Solomon rate 1/4;
  - Q = 256 column checks, giving (3/4)^256 = 2^-106;
  - BLAKE3 Merkle tree;
  - functionals that share column weights are batched.

  The zero-knowledge form (`pcs.rs:555-575`, `hashline/src/zk.rs:1-60`) adds
  three things: pad polynomials on a coset, salted leaves, and mask rows.
- **One block.** Each block is ONE proof over three hiding commitments: `A`
  (every witness plane), `H` (the LogUp helper inverses, in Fp2) and `M`
  (masks). Each commitment is opened exactly once (`private_block/layout.rs:1-35`).
- **Sumchecks.** Every sumcheck is Chiesa–Forbes–Spooner masked, with a one-round
  "extension" that hides the terminal values (`zk.rs:44-60`).
- **Matmuls.** These are sumchecks over the inner index with public weight folds
  (`shape.rs:2366-2400`).
- **Nonlinear relations and ranges.** Every nonlinear relation and every range
  check is an element-wise zero-check over committed planes. Each value is split
  into byte limbs, and every byte is looked up in one 256-entry table:
  - 33–34 lookups per model-axis element;
  - 9–14 per feed-forward element;
  - one Fp2 helper per two lookups (`shape.rs:2242-2300`).
- **Composition.** The blocks of a run are chained by a hiding boundary
  commitment under one Fiat–Shamir chain (`run.rs:1-28`). They are therefore
  proved sequentially.
- **GPU.** The commitments run on the GPU (keyed chunked route). The slot-18
  zero-check runs on the GPU only on the lane patch
  (`results/zk60_gpu_zerocheck_20261017/gzc-vs-review-r3.patch`). The witness is
  computed on the CPU.

---

## 1. The gap, decomposed

### 1.1 Like with like

MACs are the multiply-adds per token of the weight stack [COUNTED from the
published configurations]. Dense T×T attention is included: it is at most 7% of
the total. The script is `gap_calc.py`.

| System and run | Model, MACs per token | T, batch | Hardware | Hidden | Proof | Verify | Security | Wall | Tokens/s | Proven MAC/s | Ratio to ours: tokens/s; MAC/s |
|---|---|---|---|---|---|---|---|---:|---:|---:|---|
| **Ours**: Shieldstral-3B T128 classifier, violence category [MEASURED] | 3.03 G | 128 (90 real), 1 | 8 threads, Core Ultra 9 185H laptop, shared | inputs, outputs, activations (P1); weights public | 848 MB | 69.3 s (includes model load) | 96-bit floor, hash-only (BLAKE3, ROM) | 456.3 s | 0.281 | 8.6e8 | 1; 1 |
| **Ours**: Llama-3-8B T128, 32 blocks, older profile [MEASURED, historical, STATE.md] | 6.98 G | 128, 1 | 16 threads, same laptop, GPU off | P1 | 923 MB | 42.7 s | about 95 bits | prove 393.8 s (total 478.7) | 0.325 | 2.3e9 | 1.16; 2.66 |
| DeepProve README: Gemma-3-1B [CLAIMED] | 0.70 G (+0.30 G if the head is proved at every position) | 512, 1 | 24-core AMD EPYC 9254, 504 GB | **nothing**: "the verifier evaluates himself the input and output claims" | 21.73 MiB (27 MiB in the root README) | 4.32 s | BN254 HyperKZG: pairings, a KZG setup, not post-quantum | 1,137 s | 0.450 | 3.3e8–4.6e8 | **1.61; 0.38–0.54** |
| DeepProve README: GPT-2 124M [CLAIMED] | 0.124 G | 512, 1 | same | nothing | 10.71 MiB | 1.33 s | same | 458 s | 1.12 | 1.5e8 | 3.98; 0.17 |
| DeepProve paper, single machine [CLAIMED] | Gemma 3 (size unknown) / GPT-2 | unknown | **unknown** | nothing | unknown | 1–3.7 s | — | — | 1.43 / 2.90 | 1.0e9 if Gemma-3-1B / 3.6e8 for GPT-2 | 5.1 / 10.3; 1.17 (Gemma-3-1B) / 0.42 (GPT-2) |
| **DeepProve paper, distributed** [CLAIMED] | unknown | unknown | **several nodes, number unknown** | nothing | unknown | — | — | — | **30.9** | 3.8e9 (GPT-2) to 2.2e10 (1B), summed over all nodes | **110**; 4.5–25 |
| zkLLM, CCS 2024 Table 1 [CLAIMED] | LLaMA-2-13B, 12.7 G | 2048, 1 | one A100 SXM4 40 GB | weights hidden; input public | 147–188 kB | 0.9–3.95 s | BLS12-381 Hyrax/Pedersen, not post-quantum | 803 s | 2.55 | 3.5e10 | 9.1; **40** |
| Attestable blog [CLAIMED, alpha, no artifact] | Gemma-4-31B, about 31 G | 16K batch 1 / 4 × 4K | one H100 | weights hidden; prompt and activations not stated | 4.35–7.92 MiB | 0.16–0.65 s | "100 bits", hash-only | — | 53 / 77 | 1.6e12 / 2.4e12 | 189–274; **1,900–2,800** |

**Notes on the table.**
- Ours counts every position of the padded window. Counting only the 90 real
  positions lowers our rates by 30%.
- Whether DeepProve's 18.95 min and zkLLM's 803 s include witness generation
  (the forward pass itself) is **unknown**. Our 456 s includes everything in the
  prover process: loads, digests, witness, token stages, proofs and sealing.

**What the table says:**

1. **Against DeepProve's own single-machine numbers we are not behind per unit of
   work.**
   - Its 24-core server proves 0.38–0.54× our multiply-adds per second.
   - Per unit of hardware we are about 8–10× ahead. This assumes the server is
     3–4× our 8 laptop threads [INFERRED]: 3× the cores, and 12-channel DDR5
     against about 120 GB/s.
   - The likely reason: the current DeepProve does its arithmetic in the
     254-bit BN254 field (`zkml/Cargo.toml` uses `ark-bn254`; "the CPU build
     defaults to BN254") and commits with KZG multi-scalar multiplications.
     Each field operation costs roughly 10–30× a Goldilocks one [INFERRED].
     Its softmax document still says "Goldilocks" and its commitments document
     names Basefold. Both look like leftovers from the earlier version built on
     Ceno [INFERRED].
   - DeepProve's 1.6× lead in tokens/s is its model, which needs 4.3× fewer
     multiply-adds per token.
2. **The "100×" is DeepProve's distributed figure:** 1,855 tokens/min, 110× our
   tokens/s. It is a multi-machine number. Per multiply-add it is 4.5–25× ours,
   summed over all nodes. It is not comparable to the one-GPU target.
3. **The genuinely large per-work leads are GPU systems:** zkLLM 40× and
   Attestable's claim 1,900×.
4. **Where DeepProve is far ahead is size and verification.** Its proofs are
   30–37× smaller (21.7–27 MiB against our 848 MB) and its verification is 16×
   faster (4.3 s against our 69 s).

### 1.2 Attribution of the factor

| Factor | Against DeepProve CPU (README) | Against zkLLM (A100) | Against Attestable (H100, claimed) | Basis |
|---|---|---|---|---|
| **(a) Hardware** | their side ×3–4 | ×45 | ×97 | [INFERRED]. Our measured CPU→GPU port (the legacy public-IO FFN pass: 285 s on 8 CPU threads against 38.6 s on the 4070 Laptop, ×7.4), times each device's bandwidth over 256 GB/s: A100 1,555, H100 3,350, 5090 1,792 GB/s. This assumes our kernels port at today's measured efficiency |
| **(b) Hiding the IO** | ours ×1.14 at TinyLlama T128; about ×1.05 at 8B T512 | zkLLM also hides (weights; masked sumchecks) | Attestable hides weights | **[MEASURED rows]** in `r4/PHASES_T128.md`; see the list below this table. At 8B T512, [MODEL] the extension-round law of 299 ns × terms × row width gives about 1.3 s of a 52 s block (2.5%), and the other items about 2–3% |
| **(c) Committing every intermediate (against GKR chaining)** | ≤ ×1.1 | ≤ ×1.1 | unknown | [INFERRED] from the plane list in `shape.rs:2202-2240`. Most committed planes are byte limbs and lookup helpers, which DeepProve also needs in some form (it commits every lookup layer's output: `end_to_end_lu.md`). GKR chaining only removes planes that follow linearly from other committed planes or from matmul outputs: an estimated 5–10% of committed elements. The matmul sumchecks are already cheap: slots 11 and 13 take 0.44 and 0.54 s summed over 22 blocks |
| **(d) PCS, hash, proof size** | for speed it favours **us** (KZG costs more per committed element); proof size ×30–37 and verify ×16 favour them | proof ×4,500 favours them | proof ×100–190 favours them | Our receipt is 29.3 MB per Shieldstral T128 block [COUNTED, `SHIELDSTRAL_COST.md`]. My recount reaches 26.8 MB of it [INFERRED, using the toy's group count]: Q = 256 columns × (A + H + M rows) is about 50%, and one clear vector of (n + Q) Fp2 values per opening group is about 40%. Commitment and openings are 29% of block walls on the CPU and are the largest phase on a GPU roofline (0.157 of 0.274 s per block) |
| **(e) Lookups and nonlinearities** | **the largest protocol item:** about ×1.3–1.6 recoverable on a GPU | same class: zkLLM's tlookup also commits helpers | unknown (float nonlinears) | [MEASURED] at TinyLlama T128: H commit 18.13 + inverses 8.30 + open H 3.60 = 30.0 s (19.7%). In addition, the H tables carry 36% of zero-check work [MODEL, weighted by terms], about 16% of the walls. So the helper machinery is about 36% of block walls. Our 33–34 byte lookups per model-axis element compare with DeepProve's single lookup per 12-bit value in one table of size 2^BIT_LEN (`range_check.md`). The exact softmax division is 27% of a block at 8B T512 [COUNTED, speed plan] |
| **(f) Batching and amortization** | DeepProve proves T512 in one pass; their distributed run uses many nodes | T2048 | batch 4 gives 1.45× over batch 1 | Our per-token cost is lowest near T128 ([MODEL], speed plan L6), so T itself favours nobody. In our classifier workload, 90 of 128 positions are real, and each post pays for three full passes (one per category). The one-load batch saves 2.4% [MEASURED] |
| **(g) Engineering** | — | zkLLM is fully CUDA | unknown | [MEASURED]. The witness is computed on the CPU and takes 25% of the 8B T128 prove (98.3 of 393.8 s). The sumchecks run on the CPU. Our GPU kernels reach 11.7–19.4% of the laptop's bandwidth, on a clock-capped laptop. For 50 tokens/s at 8B T512, the speed plan needs at least 34% of a 5090's bandwidth: at least 340× the laptop's 16 threads |
| **Residual** | none: we are ahead | ×0.9: nothing left | ×20 after hardware | The speed plan's roofline model (whole prover on the GPU at 40% of a 5090: 57 positions/s at 8B T512 [MODEL]) is an Attestable-class rate. **No residual needs DeepProve's protocol to explain it.** |

**Breakdown of (b), hiding.** The rows measured at TinyLlama T128 [MEASURED]:

| Phase | Seconds |
|---|---:|
| Extension rounds | 13.63 |
| A mask and proximity rows | 1.61 |
| H mask and zero-sum rows | 0.69 |
| M commit | 0.49 |
| IO endpoint slots | 1.97 |
| **Total** | **18.39** (12.1% of 152.2 s) |

Pad symbols and salted leaves sit inside the commitment phase. They are under 2%
of it [INFERRED]: (n + Q)/n is 1.016 at 2^14, and the NTT sizes do not change.
The legacy measurements agree with this order of size: lane AD measured +4.7%
for one 8B-width layer, and lane ZA +12% on the CPU (START_HERE §3, §6). Those
legacy zero-knowledge forms were later found to leak, so they are lower bounds
on what hiding costs.

**The price of hiding is mostly not seconds.** Every public-IO shortcut
DeepProve takes needs a zero-knowledge version before we can use it:
- a published LogUp-GKR root reveals private lookups (the researcher's
  fraction-tree negative);
- each commitment can be opened only once (D12);
- the verifier cannot evaluate the input and output itself.

So hiding is paid in design and review effort per technique, not mainly in
prover time.

### 1.3 Where our time goes (the measured profile, mapped to the factors)

TinyLlama-1.1B, 22 blocks, T128, CPU, block walls 152.2 s [MEASURED,
`r4/PHASES_T128.md`]. This is the newest complete phase table on the
private-block family. No phase table of the real 26-block Shieldstral run was
found (§5).

| Phase | s | % | Factor |
|---|---:|---:|---|
| Five element-wise zero-checks (D 27.5, F 17.6, S 11.5, Q 8.0, Kv 4.4) | 69.0 | 45.3 | (e) about 36% of this is H helper tables; the rest are limb, requant, norm and softmax relations |
| Of which: extension rounds (ZK terminal masking) | 13.6 | 9.0 | (b) |
| H: commit, inverses, open | 30.0 | 19.7 | (e) |
| A: commit, open | 21.7 | 14.3 | (c), (d) |
| A: allocation and witness planes (mostly the witness, 13.2 s) | 17.7 | 11.6 | (g) |
| Masks and endpoints (A, H, M, slots 21/22) | 4.8 | 3.1 | (b) |
| Matmul sumchecks (slots 11, 13) | 1.0 | 0.6 | already GKR-class |

At the target shape (8B T512, CPU law, 52.0 s per block [MODEL]), the shares are:

| Phase | Share |
|---|---:|
| Commit | 29% |
| Zero-checks | 44% |
| Inverses | 8% |
| Openings | 7% |
| Conversion | 4% |
| Rest | 8% |

On a 5090 at 40% of bandwidth [MODEL, speed plan §5], the block costs about
0.274 s (the plan prints 0.279):

| Phase | s per block |
|---|---:|
| Commit | 0.157 |
| Zero-checks | 0.050 |
| Inverses | 0.024 |
| Openings | 0.015 |
| Witness | 0.003 |
| Host | 0.025 |

The budget for 50 positions/s is 0.320 s. **On a GPU the committed volume
decides the result.** That is exactly what DeepProve's "commit less" techniques
attack.

---

## 2. Technique table

Effects are end to end on one block unless stated. "Roofline" means the speed
plan's 8B T512 GPU-resident model at 40% of a 5090's bandwidth. The four
LogUp-GKR and shrinkage figures come from `gap_calc.out`.

| # | Technique (source) | In hashline? | Transfers under P1? Added obligations | End-to-end estimate (basis) | Effort | Risk |
|---|---|---|---|---|---|---|
| DP-1 | **GKR-style back-to-front claim chaining.** Outputs of linear layers are never committed; one end-to-end proof (`zkml/README.md`, `docs/src/overview.md`) | **No.** Every block value and its limbs are A planes (`shape.rs:2202-2240`). Blocks are chained through a boundary commitment (`run.rs:1-18`); the boundary plane is held by three commitments: A_k output, B_k, A_{k+1} input | **Partly**, for linear relations only. A value whose byte limbs are committed (x, x1, x2, z16, …) is a linear function of those limbs, so its claim can be derived instead of opened. Obligations: the derived claims must stay masked (paired-mask linear consistency); a new profile (D17); a D12/D24 re-read; a rerun of the joint-view and NL-1 gates. Full ZK-GKR (Libra-style masking of every layer's claim) is needed only if non-committed nonlinear layers are added | Committed −5–10%, zero-check terms −5–10%: about ×1.05–1.12 [INFERRED from the plane-list comment, `shape.rs:2219-2222`] | 5–10 lane-days | Medium |
| DP-2 | Sumcheck for matmul and einsum (`zkml/README.md`) | **Yes**: slots QMM/KMM/VMM/WO/GMM/UMM/DMM/SCORE/PV (`shape.rs:2366-2400`); 0.6% of walls | — | none | — | — |
| DP-3 | **LogUp-GKR**: fractional sums in a GKR circuit, with no committed inverse helpers (`zkml/docs/src/lookups.md`, `end_to_end_lu.md`) | **No.** We use LogUp with committed Fp2 helpers H, one per two lookups (`layout.rs:1-35`, `shape.rs:2275-2300`). The researcher's fraction-tree experiment exists, with negatives: a published root discloses the lookups; the whole tree takes about 8 GiB at 125M (`handoffs/20260926-logup-fraction-tree.md`) | **Yes, with a zero-knowledge GKR.** (i) Each layer's sumcheck is CFS-masked (our existing M rows). (ii) The layer claims are hidden with Libra-style small mask polynomials. (iii) The root is never published in the clear; one candidate, my own sketch and unreviewed, is two cancelling random leaves, which make q_root uniform while p_root stays 0. (iv) The leaves are bound to the committed limb planes, which means new claim sites and mask pairs. (v) The tree is streamed layer by layer. Then a privacy simulator, a ruling (speed plan D1), and a refusal-order re-check | Committed −55% at T512 (the H share), receipt −40–50%. **Roofline ×1.37–1.57** if the GKR sumcheck work is 50–100% of today's zero-checks [MODEL]. CPU about ×1.0–1.25 [INFERRED: the saving is about 23 s per block; the added GKR work is 11–23 s] | 20–30 lane-days | High |
| DP-4 | One multiplicity polynomial per table type for the whole model; the table-side GKR runs once (`end_to_end_lu.md`) | Per block: three tables, histograms as A rows, slot 19 | Needs a cross-block table and claim design under the one-opening rule | The table side is about 2% of walls (slot 19 is 1.55 s, the table half 1.69 s): ≤ ×1.02 [MEASURED share] | 5 | Low; not worth it alone |
| DP-5 | **Batch opening**: claims on one polynomial reduced to one point by sumcheck ("same poly"); HyperPlonk §3.8 batching; polynomials with ≤ 7 variables sent in the clear (`commitments.md`) | **Partly.** Functionals that share column weights are batched (`zkp-core/src/pcs.rs:9-13`), but each distinct claim point is its own opening group, each with a clear vector of (n + Q) Fp2 values. The toy layout has 35 groups on A and 9 on H (`layout.rs:7-9`); the count at model scale was not checked | **Yes.** The reduction sumcheck must be masked; D12 is unaffected | Openings are 5.8% of walls, so the time effect is ≤ 3%. Receipt **−25–35%** [INFERRED]: my recount, using the toy's 44 groups at n = 2^14, puts the clear vectors at about 40% of a Shieldstral T128 block's 29.3 MB | 5–10 | Medium |
| DP-6 | **Model commitment once at setup**; per-proof weight openings (`commitments.md`, `llms-layers/qkv.md`) | No in the private block: the verifier re-folds every public weight, which is about half of verify work (Sol backlog **S6**). The legacy line has `wcache.rs` | Yes (weights are public under P1; P3 needs a separate review) | **A verifier lever, not a prover lever**: verify about −50% (S6 note). With Ligero, a weight opening adds about Q × weight rows to the proof [INFERRED: about 16 MB per 8B block at n = 2^15], so it needs a cheaper weight PCS or a tensor code | S6 sizing | Medium |
| DP-7 | HyperKZG on BN254 (`zkml/README.md`; older docs say Basefold) | No: hash-based Ligero | **Not for speed**: pairings, a trusted KZG setup, not post-quantum, and more expensive per committed element. The hash-based Basefold or WHIR family is a **proof-size** option (§3, size track) | Speed: none or negative | — | — |
| DP-8 | **12-bit quantization with one range table of 2^BIT_LEN entries**: one lookup per value (`range_check.md`; README "12-bit symmetric") | No: byte limbs, one 256-entry table (`layout.rs:27-33`) | **Yes, if the limb width w equals the row-width log** (14 at T128, 15 at T512). This keeps `log(Tab) == log_cols` exactly; the failure mode in `layout.rs:141-170` is a table *above* the row width. The security owner still re-reads P-3. The calibration windows pinned at byte counts (`shape.rs:411`, `:428`) move. w = 16 needs a row width of 2^16 | Lookups −10–20% at w = 14/15, because int16 values still need two limbs; −40–50% at w = 16 [INFERRED]. About ×1.05–1.3 | 10–15 | Medium |
| DP-9 | **Softmax by prover-supplied log-sum-exp shift**: exp through limb tables, the sum checked within an error band (zkLLM's formula) (`softmax.md`) | No: exact integer softmax. The DD dictionary is admitted (D30) | Only as the speed plan's **L8**: bounded prover slack, so it needs a **ruling**, a privacy re-check and a fidelity check | Committed −17% at T512 after L7: about ×1.15–1.2 [MODEL, speed plan step 7] | 15–25 | Ruling |
| DP-10 | One forward pass over the prompt plus the claimed output with a causal mask (`zkml/README.md`) | **Yes**: the prefill window and token IO | — | none | — | — |
| DP-11 | **Distributed proving** in chunks (1,855 tokens/min; `zkml/src/iop/chunking.rs`) | No. Blocks are separate segments but run under ONE Fiat–Shamir chain, and B_k is opened in stage k+1 (`run.rs:1-18`) | Needs a commit-all-then-challenge run profile: a new transcript (D17); the cross-block joint law, which has "no tools yet" (`run.rs:22-27`); all blocks' matrices live at once, or recommitted | **No saving in total work on one GPU.** Only overlap of host and witness work with device work, about ×1.1–1.3 until L2/L4 land [INFERRED]. Multi-GPU is out of scope (`ZK60_THROUGHPUT_TARGET.md`) | 10–15 | Medium |
| DP-12 | GPU: the PCS on the GPU (`HyperKZGGpu`), inference through burn CUDA (`zkml/README.md`) | **Partly**: commitments (13% of the 4070's bandwidth), slot 18 on a lane patch (19.4%). The witness is on the CPU | Yes (byte-identity gates; no ruling) | **×10–100**: the speed plan's L2–L5, 0.55 → 6.9 anchored / 57 roofline positions/s at 8B T512 on a 5090 [MODEL] | 35–55 | Kernel efficiency |
| ZL-1 | zkLLM **tlookup**: a parallel LogUp-style lookup with committed helper vectors | **Yes**, the same class (committed H) | — | only through the GPU (ZL-4) | — | — |
| ZL-2 | zkLLM **zkAttn**: base-b exponent digits in several tables, with a bounded normalization error | No | = L8 / DP-9 (ruling) | as DP-9 | — | Ruling |
| ZL-3 | zkLLM Hyrax/Pedersen commitments on BLS12-381 with hiding rows (proofs ≤ 188 kB) | No | Not for speed (multi-scalar multiplications per element, not post-quantum); size only | — | — | — |
| ZL-4 | zkLLM fully parallel CUDA: sumcheck, lookups, commitments | Partly (see DP-12) | Yes | **Explains all of zkLLM's lead**: the residual after hardware is ×0.9 (`gap_calc.out`) | as DP-12 | — |
| ZL-5 | Libra masking of the sumchecks for hidden values | **Yes**: CFS masking plus the extension round (`zk.rs:44-60`) | — | — | — | — |
| EZ | EZKL: a Halo2 PLONKish circuit, every value a committed cell, lookups for nonlinearities, Icicle GPU MSMs and NTTs | — | Nothing to adopt for speed; its circuit model commits more than ours | — | — | — |
| AT | Attestable: float nonlinears with int8 matmuls; hash-based | — | Unverifiable. Float nonlinears would change the semantics and need rulings | — | — | — |
| SS | Sampled or layerwise audits (Seal-Then-Sample, NanoZK budget triage) | — | **No.** A sampled audit is not a complete private proof (AGENDA) | — | — | — |

---

## 3. Ranked plan

The three new protocol techniques (2–4) overlap, since all of them shrink the
committed volume. Their combined effect is not the product. My estimate for 2 + 3
+ 4 together: committed −60–65%, **×1.5–2.0 on the GPU roofline** [MODEL on
INFERRED]. That moves the 5090 kernel efficiency needed for 50 positions/s at 8B
T512 from about 34% to about **17–23%**. The time scales as 1/efficiency, plus
0.025 s of host work against the 0.320 s budget. The laptop already measured
19.4% on slot 18. **They lower the bar the GPU work must clear; they do not
replace that work.**

1. **The whole prover on the GPU** (DeepProve DP-12, zkLLM ZL-4; speed plan
   L2–L5). Expected ×10–100 from today's laptop CPU [MODEL]. This is where the
   "100×" lives.
   - **Experiment:** already specified: the 5090 real-slot bandwidth run with
     clocks pinned (`results/zk60_gpu_zerocheck_20261017/NEXT.md`).
   - **Kill observation:** under 10% of the 5090's bandwidth. Then bring
     D1 and D2 to Victor as rulings (the speed plan's task-2 rule).
   - **Lane:** Sol, the native owner. This is not new work.
2. **Masked LogUp-GKR in place of the committed helpers H** (DP-3, with DP-4's
   aggregation). Roofline ×1.37–1.57; receipt −40–50%.
   - **Experiment (explorer; CPU only; ≤ 1 GiB; light guard):**
     - Build a standalone Goldilocks/Fp2 LogUp-GKR prover and verifier for byte
       lookups. The leaves are (1, α − v) with v in [0, 256). The layers are
       streamed. Use the first-layer pair table: after α is drawn, the
       65,536 values of (α − a)(α − b) are public.
     - Measure at 2^20, 2^22 and 2^24 lookups: ns per lookup, field
       multiplications per lookup, bytes touched per lookup, and peak memory.
     - **Baseline:** today's helper path for the same lookups, priced by the
       speed-plan law at about 54 ns per lookup on 16 CPU threads [COUNTED]:
       helper commit about 23, inverse 10.8, and the helper tables' share of the
       zero-checks about 20. On a GPU it costs about 170 B of commitment traffic
       per committed element (speed plan L5). A helper is one Fp2 value per two
       lookups, so that is about one committed element, or 170 B, per lookup.
     - Add a one-page zero-knowledge design note for the security owner: root
       blinding, masking of the layer claims, and the leaf claim sites.
   - **Kill observation:** GKR at ≥ 0.7× the helper path's CPU cost per lookup
     **and** at least the same counted bytes per lookup. That would mean no
     roofline gain, and the technique is dropped.
   - **Lanes:** the explorer runs the experiment; Claude and the security owner
     do the design; Sol builds only after a ruling.
3. **Wider limbs: one range table at the row width** (DP-8).
   - **Experiment (explorer, counting only):** extend the speed plan's
     `results/zk60_speed_plan_20261017/layout.py` replica. Recount A and H
     planes, U8 lookups and zero-check element-terms per block at:
     - 8B T512 with n = 2^15 and w = 15;
     - Shieldstral T128 with n = 2^14 and w = 14;
     - w = 16 with n = 2^16.

     Check every calibration window (`shape.rs:380-430`) under the wider limbs.
   - **Kill observation:** committed elements fall by less than 10% at
     w = log_cols.
   - **Lanes:** the explorer counts; the security owner re-reads P-3; Sol builds.
4. **Derived instead of committed linear planes** (DP-1, GKR-style claim
   reduction).
   - **Experiment (explorer, counting only):** classify every A plane in
     `shape.rs:a_plane_doms` and its slot clauses as looked up, nonlinear input,
     or linear in other committed planes. Count the removable committed elements
     and zero-check terms at 8B T512.
   - **Kill observation:** under 5% of committed elements.
   - **Lanes:** the explorer counts; Sol builds behind a profile.
5. **Bounded-slack softmax** (DP-9 / ZL-2 = speed plan L8): about ×1.15–1.2
   [MODEL].
   - **Experiment:** no new one. It is ruling-gated: Victor decides whether an
     exact relation may become one with bounded prover slack, then the fidelity
     and privacy re-checks follow.

### Two other tracks (not DeepProve speed techniques)

- **Proof size.** The 848 MB receipt and the app's 2.55 GB of public segments
  per post are product costs. The levers are:
  - DP-5 single-point openings: −25–35% [INFERRED];
  - fewer column checks Q, using the proximity-gap bound at δ/2 instead of
    Ligero's conservative δ/3: Q of 256 → about 158, −38% of column bytes
    [INFERRED]. This needs a **security ruling**;
  - a Basefold/WHIR-class hash-based PCS, as DeepProve v1 used Basefold:
    receipts of tens of MB at an unknown prover cost.

  **Experiment:** count the receipt bytes by component (columns, clear vectors,
  paths, sumcheck messages) from the counted layout, before any design.
- **Classifier workload** (from the repository, not from DeepProve):
  - public-prefix reuse F6: 1–4× counted for the classifier's padding ladder
    (`DESIGN_CLASSIFIER.md` §8; Sol backlog S5, which needs a privacy design);
  - split-width S4/R14: −28.8% measured on 2 blocks at T128;
  - the one-load batch.

  For posts on the current laptop, these are larger than anything above.

### Not to repeat

These are already in the record:
- the naive LogUp-GKR port (root disclosure, tree residency);
- DD and L7–L9;
- S4–S6;
- fold/next-round fusion (measured 1.66% slower);
- the KV-reuse negative for a single prefill.

---

## 4. Plain-words summary

At the top of this file.

## 5. What could not be determined

- **The DeepProve paper's body** (ePrint PDF: HTTP 403). Unknown:
  - the hardware behind 86 and 174 tokens/min;
  - the node count and model behind 1,855 tokens/min;
  - which Gemma 3 size was used;
  - whether its prove times include witness generation;
  - whether any part is zero-knowledge.

  The README and docs describe public IO and make no privacy claim.
- **The Lagrange blogs and docs** (HTTP 403 throughout), including the source of
  the "100×-class" marketing figures. A secondary source reports them as up to
  158× over EZKL on a CNN and a dense model, and 1000× on unnamed baselines.
- **Attestable:** whether the prompt and activations are hidden; the proof
  system; any artifact.
- **A phase table for the real 26-block Shieldstral T128 run.** I used the
  TinyLlama T128 measured table and the speed plan's 8B laws. The first cheap
  step is an `HL_PB_TIMING` table of the current profile, as part of an owner
  run that is happening anyway.
- **The cost per lookup of a GKR fraction tree in our field.** It is measured
  nowhere; that is experiment 2.
- **EZKL's LLM throughput**: none is published.
