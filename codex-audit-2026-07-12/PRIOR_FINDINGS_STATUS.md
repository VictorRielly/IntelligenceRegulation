# Status of the 2026-07-10 findings

| Prior issue | New work | Re-audit status |
|---|---|---|
| Lookup transcript was not ZK | Masked GKR, blinded roots/leaves, aggregate-only pins, rank/leak batteries | **Algebra advanced; concrete fix not closed.** Masks/blinders are publicly reproducible and freshness is reconstructible (C-01). |
| Integer/statement integrity incomplete | Statement v2, quant metadata, range/link wraparound test, model/table digest fields | **Partial; still open.** Narrowing bypasses scale propagation, signed endpoints are wrong, lookup scale/digest is not typed, and most backends still use bare v1 manifests (C-03/H-03). |
| U-K8 full FFN integration absent | Range → masked lookup → Hadamard at 1,020-element row blocks, slot-packed Y, adversarial edge tests | **Useful local integration; original exit remains open.** No full tensor, matmul, requantization, caller input, pass aggregation, or proof artifact (H-01/H-02). |
| Lookup benchmark mislabeled as end-to-end | Core benchmark now says unmasked/uncommitted; live docs separately report committed-chain marginal | **Labeling improved.** GPU/22T rows are still stacked assumptions, and the committed block economics are orders from target (H-05). |
| Lookup memory would not fit target shape | Clean U-K9 packed tables/trees and custom bulk kernels | **Promising partial fix.** Same-machine RSS fell ~2.35x through `2^22`; `2^23` masked run, U-K8 merge, report, and GPU measurement remain absent (H-04/M-01). |
| M5 full-shape result was commitment-only | No new full matmul proof | **Unchanged.** Full-shape proof still absent; target contract lists largest full proof as `128x256x64`. |
| 7B surrogate was presented near an 8B target | Frozen target contract distinguishes 7B FFN surrogate from Llama-3-8B-class missing pieces | **Documentation improved.** Attention, RMSNorm, residuals, embeddings, true 8B width, and even a complete FFN proof are still unimplemented. |
| Production randomness/setup absent | No production RNG/setup implementation | **Unchanged and now directly blocks the claimed masked implementation.** SplitMix/fixed/public seeds remain on every Rust proof path (C-01/H-05). |
| No canonical proof format/independent verifier | No proof serialization/API | **Unchanged.** U-K8 verifies inside the prover function and exposes a new trusted-hash gap (C-02/H-05). |
| Documentation/test evidence fragmented | New target contract, ledgers, larger battery | **Improved but unfinished.** A-D3 is unchecked, status docs conflict, raw logs are not committed, `cargo fmt --check` fails, and side-branch integration is untested (M-02). |

Bottom line: Fable resolved several local algebra and honesty-label problems, but
the prior audit's three gating themes—concrete ZK, statement/integer integrity,
and target-scale end-to-end evidence—are not closed.

