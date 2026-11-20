# ZK60 Research North Star Proposal: `<= 2x` Total Computational Overhead for Verifiable Model Inference

**Date Drafted:** `2026-11-16`  
**Document Status:** Long-Term Research North Star Proposal *(recorded alongside active `D64` `>= 110 tok/s` private `8B` target and `D80` / `D80a` next-protocol parallel exploration in `ZK60_NEXT_PROTOCOL_CANDIDATES.md`)*

---

## 1. Statement of the Long-Term Technological Goal

> **Ultimate Research Goal:** Advance zero-knowledge proof (ZKP) protocols and hardware-aligned prover engines until proving a neural network's feedforward pass adds **no more than `2.0x` total computational overhead** relative to standard floating-point inference ($T_{\text{forward + ZKP}} \le 2.0 \times T_{\text{float forward}}$), with **manageable, compact proof sizes** and **negligible model quality degradation** (`<= 2%` perplexity delta, `0` integer refusals).

At `<= 2x` total compute overhead and compact megabyte-scale receipts, cryptographic verification becomes economically viable across nearly every commercial, regulatory, privacy, safety, and media-provenance deployment of AI.

---

## 2. Exact `[MEASURED]` Baseline Today (`2026-11-16`, Apple M3 Ultra)

| Benchmark / Metric (`T = 128` Tokens) | `[MEASURED]` Value | Source & Verification Status |
|---|---|---|
| **`Llama-3-8B` Native GPU `float16` Forward** (`32` layers + `128,256` head) | **`120.96 ms`** (`1058.2 tok/s`) | `working_model_metrics.json` (M3 Ultra `MPSMatrixMultiplication` + Metal RMSNorm/SwiGLU) |
| **`Llama-3-8B` 0-ULP GPU Exact-Integer GEMMs** (`225` matrices, `512`-col flush) | **`509.77 ms`** (`251.1 tok/s`, **`4.21x`** of `float16`) | `metal_int_gemm.mm` + `stage2_r2_hardening_audit.json` (Claude R2-audited; `0` diff on `255x-128` adversarial + `66` raw GEMMs + `16.4M` logits) |
| **`Llama-3-8B` Production `[A4]` Block Witness GEMMs** (`k_wprod_sg_2x4`, `32` blocks) | **`~316.5 ms`** GPU (`9.89 ms/block`, `~453 ms` cmdbuf) | `MVP_STATUS.md` / `witness_speed_tests.rs` (`64x64x32` tile, zero-copy `pages_view`) |
| **`Llama-3-8B` CPU Exact-Integer Forward** (`32` layers + `128,256` head) | **`5739.61 ms`** (`22.3 tok/s`) | `working_model_metrics.json` (`0` refusals, `0` diff vs GPU) |
| **W16R2 `Llama-3-8B` ZKP Prover (`A22+A23` `stack-serve` steady)** | **`~3938.5 ms`** (`32.4–32.6 proved tok/s`; `29.4–29.7` 8-req amort.) | `MVP_STATUS.md` `8B` steady stream (**`~32.6x` vs M3 Ultra GPU `float16`**; **`0.69x` faster** than CPU exact-int forward!) |
| **Qualified `Shieldstral-3B` Classifier ZKP (`W16R2` `A31`/`A32`)** | **`4,380.6–4,491.2 ms`** (`28.50–29.22 tok/s` streamed / `33.34 tok/s` proof-only) | Coordinator Batch 2/3 `Shieldstral-3B` `26`-layer classifier stream |
| **Provable `Llama-3-8B` Benchmark Quality (`D32`)** | **`1.0155x` FineWeb PPL**, **`1.0059x` WikiText-2 PPL**, **`100.0%` LAMBADA**, **`0` refusals** | `d32_and_shift_audit.json` (**already meets** `< 2%` quality budget!) |

---

## 3. Why Larger Models Scale More Favorably — And What Current Bottlenecks Must Change

### A. Favorable Width Scaling ($\Theta(d^2)$ Dense Matmuls vs $\Theta(d)$ Activation Non-Linearities)
- Dense transformer matmuls (`Q, K, V, O, Gate, Up, Down`) scale quadratically with hidden width: $W_{\text{forward}} = \Theta(L \cdot T \cdot d^2)$.
- Bilinear matmul sumchecks project weights against random challenges in $O(d \cdot f)$ plus $O(T(d+f))$ vector folds, while per-activation non-linearities (range limbs, SiLU/softmax lookups, RMSNorm `isqrt`, witness commitments) scale only linearly with width: $\Theta(L \cdot T \cdot d)$.
- Consequently, the ratio of prover commitment/lookup work to dense forward FLOPs shrinks steadily as model width grows from `3B` ($d=3072$) $\rightarrow$ `8B` ($d=4096$) $\rightarrow$ `70B` ($d=8192$) $\rightarrow$ `405B` ($d=16384$).

### B. Hard Physical Floor & Volume-Reduction Roadmap (`Cycles 4 & 6a–6c`, `H133`/`H134`)
Co-coordinator review & committed-volume census (`20261116-claude-cycle4-committed-volume-census.md` and `20261116-claude-cycle6a/6b/6c`) established the exact byte-traffic floor of our current `W16R2` `8B` (`T=128`, `32`-block) layout:
- **Committed Rows per `8B` `T=128` Request:** `164,548` rows $\times 16,384$ words = `21.6 GB` message words $\rightarrow$ **`43.2 GB` rate-`1/2` codewords** (`43.6 GB` Merkle-hashed), vs `15.4–16.5 GB` weight read for a plain `float16` pass (`7.9–9.0 GB` in `int8`).
- **Where `74.5%` of Prover Volume Goes (`5,103` rows/block):** `49.3%` `Fp2` LogUp helper polynomials (`2,162` range + `320` exp/act + `30` table of `2,514` `H` rows), `24.9%` byte-limb decomposition planes, `19.3%` activations, `6.1%` masks, `0.3–0.5%` tables.
- **Two Concrete Architectural Levers Close `~32.5x -> <= 2x` Across `W16R4+` and `30B–70B+` Scales:**
  1. **Lookup & Committed-Volume Compression (`D80` Candidates A & B in `ZK60_NEXT_PROTOCOL_CANDIDATES.md`, Requires Ruling + Lean):**
     - **Candidate A (`Cycle 6a`):** Masked LogUp-GKR / helper-free lookups remove committed lookup helpers (`5,103 -> 2,509` rows/block, `-50%` of `43.2 GB` $\rightarrow$ **`21.5 GB`**; paper step passed `2026-11-16`);
     - **Candidate B (`Cycles 6b/6c` + `Ticks 5/6`, Goldilocks Packing + Determined Planes):** Dropping `424` pointwise-determined `A` rows (`SR, SG, RH`, norm top limbs, RoPE remainders) and packing three byte-scale cells per `64`-bit Goldilocks word with a `tau = 128` ternary smallness test cuts `8B` codeword traffic from **`43.2 GB` down to `10.5–13.2 GB` (`24%–31%` of today, `1,201–1,525` rows/block)** while keeping Goldilocks exact arithmetic *(whereas `D56` / Candidate C showed switching to a `31`-bit field adds wide-accumulator carry digits and worsens volume to `27.1 GB`)*, alongside wide-row openings (`B6b` models `40–52 MB` receipts vs `819 MB`).
  2. **Exact INT8 / Tensor-Core Witness & Sumcheck Execution (`H128` / `[A4]` + Stage 2 Verified Kernel) + Batched/Larger-Model Amortization (`H132`):**
     - Replaces scalar/CPU witness generation with exact chunked matrix-core execution (`316.5 ms` `[A4]` 32-block GEMMs + `509.8 ms` 225-matrix GEMMs on M3 Ultra; `< 9 ms/block` target on RTX 5090 INT8 Tensor Cores), while larger widths (`70B+`) quadraticize the forward denominator relative to linear activation commitments.

---

## 4. High-Impact Use Cases Unlocked as ZKP Overhead Approaches `2x`

1. **Verifiable Cloud & Decentralized AI APIs:** Cryptographic proof that exact `70B`/`405B` weights and safety policies executed without silent model downgrade or tampering.
2. **AI Safety & Frontier Governance Audits:** Proving safety classifiers (`Shieldstral`) or pre-deployment evaluations ran faithfully without revealing proprietary weights or private user prompts.
3. **Regulated Healthcare, Finance & Legal AI:** Auditable compliance on confidential patient/financial records with mathematical zero-knowledge privacy.
4. **End-to-End Proven Media (`Pixtral` + `Shieldstral`):** Sensor-to-verdict cryptographic receipts verifying media authenticity and safety properties.
5. **Trustless Autonomous Agents:** Succinct execution proofs enabling high-stakes financial and contractual settlement.
