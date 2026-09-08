# Primitive extraction, round 11

Source pin: `b557a7c` (reviewed Fable GPU, privacy-analysis and core-design
merges on top of Codex's `8b697b0` observation diagnostic). GPU implementation
at this pin is identical to Fable's validated `5bb1546`; Codex's combined
post-extraction validation is recorded in `results/zk60_round11_validation.json`.

The first implemented boundary is deliberately smaller than the final CL20
delivery. Seven modules live in this crate, with direct dependencies `blake3`
and `rayon`; there is no dependency on `hashline`, CUDA, exports or model data.

| Canonical module | Existing caller path | Mechanical adjustment |
|---|---|---|
| `field` | `hashline::field` | primitive tests moved; application verifier fault-injection tests remain in hashline |
| `ntt`, `merkle`, `transcript`, `mle` | same module names in hashline | entire implementations and their tests moved |
| `rng::ZkRng` | `hashline::zk::ZkRng` | stream implementation and two RNG-only tests moved; configuration/OS-freshness integration tests remain in hashline |
| `sumcheck` | `hashline::sumcheck` | RNG import points to `rng`; all sumcheck and CFS helper code/tests moved |

The adapters re-export the same Rust types; they do not convert or copy proof
objects. There is one implementation per primitive. Field operations, NTT
order, hash labels, transcript challenge consumption, RNG domains and refill
order, sumcheck messages and serialization are unchanged. Original and moved
source hashes are in `primitive_migration.json`. Existing Cargo dependency
versions are retained by seeding the new lockfile from the legacy lock.

The 19 primitive tests pass independently. The public sumcheck example checks
the terminal polynomial against its public tables; accepting only the round
checks would omit that obligation. The example is not a commitment scheme or
an FFN proof. The CFS helpers are preserved for compatibility with the legacy
FFN; Fable's FA3 B1/B2 review blockers still apply. The A/H/W disclosure and P3
identity regressions remain in hashline and must continue to pass as limitation
tests until a versioned repair changes their expected behavior.

Next boundaries for Fable, in order:

1. Extract PCS types and the CPU commit/open/verify path behind a narrow
   backend interface that the existing GPU code implements. Keep compact PCS,
   cache policy and runtime switches in legacy adapters. `pcs.rs` currently
   obtains the canonical RNG through the legacy re-export; remove that last
   application dependency when PCS moves.
2. Move table registration and typed v3 statement/witness/layout/proof pieces,
   then the selected P0 FFN path and bounded encoding/decoding. Keep the current
   table registry and digest validation; an arbitrary opaque digest must not
   replace the verifier's table semantics.
3. Add tiny old/new FFN proof-byte comparisons and decoder refusals, then keep
   the four complete frozen artifacts and public receipt gates. Preserve both
   compact and GPU consumers; no backend is retired as a side effect.
4. Extract the versioned masking repair only with its reviewed invariants and
   privacy classification. A P0 FFN example alone does not close CL20.

Codex owns this first primitive move and its compatibility validation. Fable
continues the remaining core/PCS design and implementation; shared boundaries
receive review before integration. Experiments, CLI tools, alternate proof
paths and all existing reports remain in their original projects. New protocol
behavior belongs in a separate change with its own profile/version and tests.

`dependency_graph.json` is retained as the original `52a13d1` graph, not
rewritten to pretend it describes this extraction. The design scanner follows
intra-crate imports, so after this move its hashline-only closure ends at the
compatibility exports. Cross-crate reporting must include this crate before
using new closure counts to claim a reduction in implementation size.
