# Status of the 2026-07-12 audit findings

This table distinguishes genuine closures from renamed or partial closures.

| Prior ID | Current status | Evidence / remaining gap |
|---|---|---|
| C-01 public/repeatable lookup masks | **Partially fixed** | Main benchmark modes now use `ProverRng::from_os`, and masks are moved into proving. Deterministic construction/deep copy remain shipped, the private nonce is not bound, and fork-safe uniqueness is not enforced (new H-01). |
| C-02 verifier trusts `h0_lkp` | **Fixed in U-K8/U-R monolithic rigs** | Verifier recomputes from statement context and the full commitment list; tamper legs reject. The dirty U-S1 serializer is not the complete proof boundary and introduces separate C-04 gaps. |
| C-03 statement integer semantics | **Fixed at the reviewed baseline; broader v3 work remains** | `c377d0d` enforces rescale fraction bits even after narrowing, asymmetric signed capacity, the canonical SiLU digest/quantization, DAG acyclicity, nonempty Add, and orientation checks. Phase 2 is still needed for typed multiple tables/raw encodings and repository-wide adoption, not to reopen those corrected validators. |
| H-01 row-block scale does not close target | **Engineering improvement, target still open** | Multi-wave one-instance execution reaches `2^20`, removing the old per-descent C2 cap. It peaks at 8.23 GiB, cannot run the 5.6m-element layer on this box, leaks partials, and emits GiB-class ct proofs. |
| H-02 chain is not an FFN proof | **Open** | U-R remains Lookup/Range/Hadamard only; no three matmuls or requantization are proved (new H-03). |
| H-03 validated statement not repository-wide | **Open** | Bare manifest digest call sites remain in structured/lattice binaries; Phase 2 is unchecked (new H-04). |
| H-04 U-K9 interrupted/unmerged | **Substantially improved** | Packed kernel work is present in the current combined source and the release build/batteries pass. This does not close protocol security, proof size, or GPU integration. |
| H-05 no production proof artifact | **Open** | Dirty U-S1 adds toy dump/load plumbing only; `PROGRESS_US.md` explicitly defers the full artifact to Phase 3 (new C-04/H-04). |
| M-01 kernel boundary coverage | **Improved** | U-K9 batteries include residue boundaries, portable/AVX/scalar equality, and tails. Full property/overflow/device coverage remains a pre-GPU gate. |
| M-02 documentation/Git inconsistency | **Text reconciled, semantic overclaim remains** | Documents now agree on “row-block closed/FFN-integrated,” but that label still exceeds the implemented activation fragment (new H-03/M-02). |

## New regressions or discoveries in this audit

- ARP restart optimization weakened the rejection-sampling statistical
  guarantee from the documented `t = 12` class to `t = 1.5` (C-01).
- Multi-wave composition introduced public partition sums without a ZK
  composition analysis (C-02).
- Per-wave ct proof bytes were omitted from the new amortization report (C-03).
- The first serialized verifier experiment turns off the exact pin check that
  an existing attack proves necessary (C-04).
- The exact range pilot is fast, but Statement v2 cannot express it (H-02).

## Bottom line

Fable resolved important implementation defects from July 12, especially
verifier-side prehash recomputation and the immediate public-seed behavior in
normal benchmark modes. The new work also exposed deeper architectural costs.
The security boundary, proof artifact, full FFN relation, and target economics
remain open; GPU integration should wait on those items.
