# Handoff: attention SC_SZC device-round boundary (research only)

Run `20260927T045233Z-e6183046`. The [experiment](../experiments/sc-szc-device-round-20260927/README.md)
checks a **synthetic** three-group degree-four polynomial and the source CFS
round formula against a direct original-hypercube evaluator. Four profiles,
110 round points, 91 terminal values and eight controls pass. The two tile
sizes at 128 rows yield identical masked messages. No production patch,
compiled CUDA, BLAKE3 parity, receipt or measured speed exists.

## Interface and patch location for an owner prototype

- `hashline/src/private_attention/argument.rs::SC_SZC` builds the real slot's
  polynomial/tables; pin its exact table count, degree, ordering, grouped
  equality metadata, hosted terms and extension-round behavior. The toy
  polynomial in this research artifact is **not** a substitute.
- `hashline/src/zk.rs::masked_prove` currently installs `CfsMasker` around
  `zkp-core/src/sumcheck.rs::prove`. A candidate dispatch would keep the
  current CPU path as byte-parity fallback and hand the same slot tables to
  a new, attention-specific device round evaluator.
- Device round interface: active `Fp2[k][len]` plus public slot parameters
  -> exact unmasked vector `s[0..=degree]`. Host must call the existing
  masker and `Transcript::absorb_fp2(b"sc-round", ...)`, draw the real
  challenge, then launch a device fold `t[i]=(1-r)t[i]+rt[i+half]` for all
  tables. It must return finals in original table order. No changes to
  fresh mask generation, transcript bytes, refusal behavior or private
  commitment/opening schedule are authorized.
- `hashline/src/gpu/kernels.cu::k_sc_round_zc*` is an FFN interface example,
  **not** an attention SC_SZC implementation. New CUDA/PyO3 wiring and
  table lifetime/VRAM accounting are required; preserve the already tested
  grouped CPU evaluator and its fallback.

## Validation and measured-cost gate

First run an owner native CPU-only boundary test with the **actual** SC_SZC
closure and BLAKE3 transcript at small/dense/ragged shapes: round vector,
masked bytes, challenges, final table values, extension round, full receipt
bytes, fresh/cross-version verifier replay, and corruption/refusal controls.
Then, under the shared build/GPU locks, measure resident upload, per-round
round/reduction/fold kernels, D2H/H2D and sync, peak VRAM, whole SC_SZC
slot, witness, prove, serialization and verification. Quiesced A/B must
show enclosing complete-proof readiness improvement before promoting.

At the synthetic N=128/k=26/d=4 interface, upload is 53,248 B;
unchanged logical round/fold reads are 211,328 B and writes 52,832 B.
Reduced round messages and returned challenges total 672 B across seven
rounds, with seven sequential Fiat–Shamir dependencies and at least 14
round/fold launches (21 with a separate device reduction). Sending raw tile
partials trades a reduction launch for 880/3,680 B at tile 16/3. These are
logical counts, not hardware traffic or time. Current GPU-assisted 125M
one-block whole-process mean is 30.055 s; even deleting the approximate
half-prover softmax slot entirely would model only a ~28.5% wall reduction
there, and this proposal deletes a subset while adding costs. No complete
private 8B target implication can be quantified yet.

**Stop criteria:** any byte/terminal/refusal mismatch, unacceptable VRAM,
or no quiesced full-proof gain. Privacy/soundness and model-scale profile
acceptance remain with the owner. In particular, D19b/D23 are pending,
D22 covers only the CPU toy, and no mask or private-opening reuse is allowed.
