# GPU port plan for the production classifier (Phase B)

Written 2026-10-30 by the GPU classifier lane (D53: nothing is published until proving and verification run
on the GPU). Inputs: this lane's measured CPU profile (`PHASE_PROFILE.md`), its first GPU-assisted real prove
(§3 below; ledger `PROGRESS.md`), the paused zero-check lane (`results/zk60_gpu_zerocheck_20261017/`), the speed plan
(`docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md`) and the DeepProve gap study. Labels: [MEASURED] (shared
laptop, n = 1), [COUNTED], [MODEL]. Every gain below is a [MODEL] unless marked otherwise.

## Plain words for Victor

<!-- PLAIN -->

## 1. The rule every item follows: byte-identical to the CPU path

- The CPU prover stays the reference. A GPU kernel computes the same field elements (field arithmetic is
  exact, so only the polynomial, the tables, the points and the round order must match, not the operation
  order); the transcript, CFS masking, every challenge and all randomness stay on the host.
- Gates, in this order, for every item: (1) a unit equality of the device result with the CPU result on dense
  random and honest-witness data at the rung and at Shieldstral T128; (2) the rung single prove under fixed
  entropy, CPU path vs GPU path, every file equal (`tools/rung.sh`); (3) **the real-scale job-0 prove under
  r18's fixed public entropy, all 30 files equal to the recorded digests** (`tools/phase_a.sh`); (4) a fresh
  verify of the GPU-made receipt by the frozen production CPU binary; (5) `HL_GPU_REQUIRED=1` with 0
  declines and peak VRAM recorded. Fixed-entropy receipts hide nothing: test only, deleted after the record.
- Because the receipts are byte-identical, the reviewed privacy statements carry over by evidence; only the
  named binaries change (D53, coordinator's reading).

## 2. The phases, ranked by measured share of one category prove (476 s, CPU, 8 threads)

| # | phase (measured share) | GPU design | expected gain on the laptop 4070 (and why) | VRAM: 8 GB laptop / 32 GB 5090 | effort (lane-days), risk, owner |
|---|---|---|---|---|---|
| 1 | **Witness, built twice: ≈ 144 s (≈ 30%)** — 70 s in the blocks, ≈ 74 s again in `seal_chain` | Exact integer kernels: int8 × int8 → int32 GEMMs (exact on IMMA/dp4a), then the requantisation, RMS-norm, RoPE, the exact integer softmax (table lookups + integer division), activation tables and the limb decompositions, writing the A planes **on the device** (they feed the commitment and the zero-check tables without a host round trip). A host copy is returned for the CS-3 / parity checks | 14.9 G int8 MACs per block [COUNTED: 3.03 G per token / 26 layers × 128] and 0.6 GB of A planes: tens of ms per block → **144 s → ≈ 3–6 s** [MODEL] | per block: 243 MB weights + 0.6 GB planes + scratch ≈ 1.5 GB / the whole 6.3 GB padded model can stay resident on the 5090 | 5–8; medium (exactness of rounding and division; the per-layer parity check against the export is already mandatory and is the oracle); **native owner (Sol)** owns `witness.rs`: the GPU lane writes the kernels behind a witness-builder seam |
| 2 | **Commitments A + H + M + B_k: 104 s (22%)** | **Exists** (`gpu-cuda`, `HL_GPU=1`): keyed LDE + BLAKE3 leaves on the device, Merkle top on the host. Next: L5 — fused LDE + hash, device Merkle top, rows produced on the device by item 1 (no upload), encodings kept resident on the 5090 (no chunked re-encode at opening) | measured in this lane: see §3 [MEASURED]; L5 a further ≈ 3× (13% → ≈ 40% of bandwidth) [MODEL, speed plan L5] | chunked: ≈ 1.3–2 GB / resident encodings 4.7 GB per block (146.9 M words × rate 4 × 8 B [COUNTED]) fit easily | 0 (exists) + 5–10 for L5; low (proof-byte gates exist); GPU lane |
| 3 | **Five element-wise zero-checks: 97 s (20%)** — bodies 82.8 s, table builds 6.7 s, extension rounds 6.3 s | Device `SumcheckRounds` evaluators under the unchanged `zk::masked_prove_rounds` (the slot-18 template of the zero-check lane: split kernel, device-built tables from resident A/H rows, fused reduction, mapped-flag result, host tail), plus a batched `mask_eval` kernel for the extension rounds. **The classifier's profile is on the R13 accuracy stack**: slots 14–19 are redefined in `argument_accuracy.rs`, so the legacy slot-18 kernel does not apply as is. Write the five R13 polynomials once as data (extend the test-only slot expression IR, `slot_ir.rs`, to the R13 definitions) and generate each kernel's polynomial body from it (NVRTC source), so the IR == closure oracle guards every Sol round | the measured legacy slot-18 body (25.9 ms per 2^20, 21 tables; 1.2 ns per table entry on the capped clock; 25× the 16-thread CPU) scaled by table entries (127 M per block) or by element-terms (254 M) gives **0.15–0.37 s per block against 3.73 s: ≈ 97 s → 5–10 s** [MODEL] | the largest slot (18) holds 60.8 M Fp2 = 0.97 GB of tables; with resident A/H rows ≈ 2.5 GB / trivial | 8–12 (IR extension 3–5, then about one round per slot on the template); medium-high (the kernels reached only 19% of the laptop's bandwidth so far; descriptor drift); the IR and the dispatch lines are **Sol's** files; kernels and gates are the GPU lane's |
| 4 | **Model passes: ≈ 66 s (14%)** — digest pass 30.8 s, then every block loaded three more times (seal_chain, sealing pass, run) | **Not a GPU item.** One load per block per process: keep the digest pass's `LayerRecord`s, compare on reload instead of re-hashing, hash layers in parallel (speed plan L1 did this for the trained-block CLI: digest 83 → 15 s, loads 79 → 16 s) | ≈ 66 s → ≈ 15–20 s [MODEL] | — | 2–3; low; **token lane** (classify CLI) with Sol (loaders) |
| 5 | **LogUp inverses, A-row conversion, lookup values, histograms, mask rows: 28 s (6%)** | Device kernels on the resident A data: helper inverses (the legacy `dev_helpers` pattern; batch inversion; U8 inverses through the 256-entry table), histograms by atomics, conversion disappears once item 1 writes A rows on the device | 28 s → ≈ 1 s [MODEL] | small | 3–5; low-medium; dispatch in Sol's `protocol.rs`, kernels GPU lane |
| 6 | **Openings: 14 s (3%)** | Already device folds / gathers for device commitments; move the claim assembly's row folds onto resident rows; no re-encode on the 5090 | 14 s → ≈ 4–6 s [MODEL] | — | 2; low; GPU lane |
| 7 | Stage IN-C (vocabulary LogUp over V = 262,144 with the embedding fold): 3.6 s; small slots, frames, stages: ≈ 18 s | The embedding fold is a GEMV over the 1.6 GB int16 table (bandwidth-bound) | 3.6 s → < 0.2 s; the rest stays host-side | 1.6 GB | 2; low; token lane (stage IN-C) + GPU lane |

**Why one generator covers the five R13 zero-checks** (read from `argument_accuracy.rs`, frozen-r19b): every
slot has the same skeleton, `P = E0 · (Σ_k μ_k LogUp-helper_k + pad + S · Σ_i μ_i clause_i) + Σ_j ν_j E_j · S
· host_j`, where each LogUp helper is `H (α − a)(α − b) − (α − a) − (α − b)` over byte limbs, each clause is a
product of at most three linear forms in A planes, limb sums (`Σ 2^(8i) limb_i`), public columns (`γ_a`,
`γ_m`, the activation group column) and constants, and each host term is one such linear form. Slot 14 has 13
clauses, slot 18 four, plus their helpers. The legacy slot-18 split kernel already implements the helpers, the
pad term, the gates and stepped linear forms (`results/zk60_gpu_zerocheck_20261017/NEXT.md` §3); the R13
generator adds general clause lists. A descriptor emitted from the IR (tables in push order, linear forms,
clauses, helper pairs, gates, hosts) and checked against the closure at random points before the first
launch is both the kernel's source and its fail-closed guard.

**GPU verification** (D53 asks for it): the fresh verify is 66.8 s, of which **49 s is reading and hashing the
public model three times** and about 10 s is cryptography. GPU design for the 10 s: the public weight folds of
the matmul slots (2.5 s; a GEMV of int8 weights against eq tables, bandwidth-bound, weights resident on the
5090), the public-table evaluations at the claim points (slot 18's R13 activation-group column and supports
over 2^21 entries, causal mask, RoPE: 2.9 s), and the PCS checks (2.9 s: column re-encodes and BLAKE3 Merkle
paths). Identity method: the verifier's decisions are field equalities, so a shadow mode compares every device
value with the CPU's on the same receipt, and every negative control (the reviewed refusal set) must refuse on
both. Expected: crypto 10 s → ≈ 1 s on the GPU, but **without item 4 the verify stays ≈ 55 s**; with item 4
(one model pass, parallel hashing or a pinned digest cache) ≈ 15 s, then ≈ 6–8 s with the GPU [MODEL].
Effort 3–5 lane-days for the GPU part (GPU lane; the verifier dispatch lines in Sol's files), 2 for the
verifier's run hygiene (token lane).

## 3. Measured: the GPU arm that exists today, on the real classifier

<!-- MEASURED -->

## 4. How the GPU code lives

- **One backend module, selected at run time.** All device code stays in `hashline/src/gpu/` behind the
  `gpu-cuda` feature; `HL_GPU=1` turns it on, `HL_GPU_REQUIRED=1` makes every decline fatal (`gpu::declined`),
  and a CPU build has none of it. Each phase plugs in through a narrow seam whose CPU implementation is the
  reference: `zkp_core::pcs::Backend` / `EncodedStore` (commitments and openings, exists);
  `zkp_core::sumcheck::SumcheckRounds` (the zero-check bodies; the trait was written for a device evaluator and
  the slot-18 lane used it); a witness-builder seam returning the same `Witness` (new); a verifier seam for weight
  folds and public-table evaluations (new). Every device entry has a shadow mode (`HL_GZC_CHECK=1`-style) that
  runs both and asserts equality.
- **Descriptors come from the slot definitions, not from hand copies.** Sol's rounds change polynomials (R13
  changed five; R14's split width changes the layout again). With the IR as the single source, a new round
  changes the polynomial in one place and the IR == closure test fails loudly on drift; an unknown layout is a
  decline (fail closed), never a wrong polynomial.
- **Ownership.** Sol (native owner): `private_block/{argument.rs, argument_accuracy.rs, protocol.rs,
  witness.rs, slot_ir.rs}` and `zkp-core` — the one-line dispatch hooks, the IR extension to R13 and the witness
  seam need Sol's authorship or review, as `device_fzc` did in the zero-check lane. Token lane:
  `private_block/token_io/*` (the classify CLI and run, stage IN-C, the run-hygiene changes, building and pinning
  the GPU release binary, the app's switch). GPU lane: `hashline/src/gpu/*`, the kernels, the device
  descriptors, the gates and the measurements. The privacy statements need no change while bytes are
  identical; the security owner re-reads only the named binaries and the decline rule.
- **Release.** The production classifier binary is today built without `gpu-cuda`. The first deliverable is
  a reviewed GPU build of the same tree (§5 step 0), pinned like the CPU one, with the app passing
  `HL_GPU=1 HL_GPU_REQUIRED=1` and refusing a run that declined.

## 5. Order and timeline [MODEL, lane-days; one lane-day ≈ one agent round]

| step | what lands | owner | days | laptop 4070, one category (CPU today 476 s, 8 threads) |
|---|---|---|---|---|
| 0 | GPU release build of today's tree (commitments + openings), reviewed and pinned | token lane + GPU lane | 1 | see §3 |
| 1 | run hygiene: one model pass; verify loads once | token lane, Sol | 2–3 | −45 to −50 s |
| 2 | witness on the GPU (both passes) | Sol + GPU lane | 5–8 | −135 to −140 s |
| 3 | the five R13 zero-checks + extension rounds on the GPU (IR-generated) | Sol (IR) + GPU lane | 8–12 | −87 to −92 s |
| 4 | inverses, conversion, histograms, openings, stage IN-C | GPU lane (+ Sol's dispatch) | 4–6 | −38 to −40 s |
| 5 | GPU verification (folds, public tables, PCS) + verifier hygiene | GPU lane + token lane | 4–6 | verify 67 → ≈ 8 s |
| 6 | commit kernel to roofline (L5) | GPU lane | 5–10 | further −10 to −15 s |

<!-- END_STATE -->

## 6. What the 5090 changes, and what to measure first

- **Memory stops being the constraint.** 32 GB holds the whole padded model (6.3 GB), a block's resident
  encodings (4.7 GB) and every zero-check table (≤ 1 GB at a time) together: a GPU-resident prover with no
  per-block weight upload and no chunked re-encode. On Linux there is no WSL VRAM freeze, so the laptop's
  4 GiB lane rule does not apply (still record `peak_vram_mib`).
- **Bandwidth and compute:** 1,792 GB/s (7× the laptop's 256), 170 SMs (4.7×) at an unthrottled clock (the
  laptop ran at 1.07–1.6 GHz under SW thermal / power caps). The device phases should scale 5–10×; the host
  remainder (transcript, Merkle top, claims, the model passes until step 1 lands) depends on that box's CPU,
  which is still unknown, so measure it.
- **First runs on the 5090, in order, one guarded job each:** (1) this lane's `tools/rung.sh` and
  `tools/phase_a.sh` unchanged but for the CUDA paths (`/usr/lib/wsl/lib` → the box's driver; nvidia-smi on
  PATH): the real-scale GPU prove's 30-file digest equality, its phase table and clocks; (2) the zero-check
  lane's `NEXT.md` §1 list (gates, ladder, the real slot against 1,792 GB/s); (3) with persistence mode and
  locked clocks if Victor allows (`nvidia-smi -pm 1`, `-lgc`), the same two runs again, recording the clock
  state and throttle reasons with every timing.
