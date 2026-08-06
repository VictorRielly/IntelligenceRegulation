# Status of the 2026-07-09 findings

This table distinguishes a prototype-level repair from production closure.
“Fixed” means the specific prior code/protocol defect now has implementation
and regression evidence; it does not imply external cryptographic audit.

| Prior finding | Current status | Follow-up assessment |
|---|---|---|
| C-01 composed slot-packed Hadamard / E2 | **Fixed at machinery level** | `link_claims_tgt_slot` plus zeta rows covers every non-value CRT coordinate. The U-E2 battery demonstrates the old accept and new reject. Full range -> lookup -> `gate o up` wiring is still absent. |
| C-02 unmasked Route R quadratic images / R1 | **Fixed at prototype protocol level** | R1 is committed and applied to quad-ct, untwisted quad-ring, and twisted quad-ring families. Leak and ordering pairs cover each family. Production RNG, formal composition, and external review remain open. |
| C-03 integer exactness/range coverage | **Open** | q31 non-wrap remains printed as a caveat. Model-weight/input ranges remain declared rather than proven. |
| C-04 production statement/generic verifier | **Open** | The manifest still hashes caller-supplied structs but does not validate a complete, shape-correct, quantized model DAG. No wire format exists. |
| H-01 R1 capacity regressions | **Fixed for frozen demos** | The full suite and freeze checks pass. M5 chunking also makes wide objects practical under a bounded CRS. A general statement-derived wave planner is still absent. |
| H-02 R1 recost missing | **Improved, not closed** | M5 includes R1 pad/chunk volume and measures full-shape commitment streaming. The two pass inventories still disagree by 1.4x, and full CE rounds remain modeled. |
| H-03 five-second result depends on absent GPU | **Open** | No proof GPU backend exists. New measurements make the dependency clearer, but the GPU factor is still assumed and now inconsistently defined across benchmarks. |
| H-04 transformer operations absent | **Open** | A SiLU lookup core now exists, but no complete FFN integration, attention, softmax, normalization, RoPE, multi-layer trace, or exact 8B model exists. |
| H-05 insecure Route R sampling | **Open** | SplitMix64 and floating-point branchy sampling remain in the prover path. |
| H-06 parameter/security level | **Open** | Several documented quantum estimates remain below 128 bits; native estimator and bespoke reduction review remain outstanding. |
| H-07 pairing setup | **Open / track-specific** | The pairing benchmark still uses locally known setup trapdoors. Route R is the active performance track, so this is not the immediate GPU gate. |
| H-08 untrusted proof boundary | **Open** | No canonical parser, length limits, malformed-proof tests, fuzzing, or panic-free generic verifier. |
| M-01 “PROVEN” terminology | **Open** | New lookup documents continue to use `[PROVEN]` for handwritten/spike-checked arguments, including custom adaptations with stated obligations. |
| M-02 publication-grade benchmarks | **Improved, not closed** | M5 records three shared-box sessions and labels assumptions. Lookup parallel/GPU rows still reuse unrelated factors; no p95 or actual GPU run exists. |
| M-03 Rust tests hidden from Cargo | **Open** | `cargo test --all-targets` still runs zero Rust tests. |
| M-04 documentation drift | **Open** | Several status and cost documents conflict with code and with one another. |
| M-05 packaging/CI | **Open** | No CI, license, supported root build command, fuzz configuration, or release process. |

## Net assessment

Fable did resolve the two most acute protocol defects identified in the prior
snapshot. That is real progress. The system has not yet crossed the larger
boundary from “collection of well-tested research subprotocols” to “one secure
and zero-knowledge computation statement.” The new lookup masking and its
integration are now the shortest path to that boundary.

