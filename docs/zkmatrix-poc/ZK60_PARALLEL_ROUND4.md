# ZK60 round 4 — externally bound public block receipt

Base `87c5338`, after Victor asked to continue and report overall progress.
The base is clean and pushed. This is a bounded public-synthetic CPU rung,
not private application enablement or a 5090 performance result.

## Ownership before work

| Lane | Owner | Writable scope |
|---|---|---|
| B4 statement and actual input/output linkage | Codex lead, main tree | new `hashline/src/public_block_receipt.rs`, `hashline/tests/zk60_public_receipt.rs`, optional example; additive extraction of public fixture metadata in `causal_oracle.rs` (no arithmetic change); module registration and integration/shared boards/evidence |
| B4 complete bounded component codec | Codex codec worker, `/tmp/zk60-round4-mEV7fY/codec` | new `hashline/src/public_block_wire.rs`, `hashline/tests/zk60_public_wire.rs`, `docs/zkmatrix-poc/ZK60_PUBLIC_WIRE.md`; local module registration only |
| Overall milestone map | Codex planning worker, `/tmp/zk60-round4-mEV7fY/plan` | new `docs/zkmatrix-poc/ZK60_STATUS.md` only |
| Binding and hostile-input review | Codex independent review worker | read-only receipt/codec/legacy verifier inspection; no owned-source edits |

Workers are Codex agents, not Claude or Fable. Victor said Claude will take
its queue; do not infer which job has started without a handoff. Claude's
`gpu/`, `pcs.rs` and reserved report/tests are untouched. Fable's independent
privacy/P3 model-consistency review remains a separate gate. No changes to
legacy attention, FFN, ZK, PCS or frozen transcript paths in this round.

## B4 acceptance and boundaries

Use a NEW public receipt domain. Bind independently supplied approved block
metadata, request/session context and canonical signed input/output tensors
before challenges. Add actual `x_in` and final residual `xres2` claims to
the attention commitment BEFORE opening it; merely hashing expected output
is insufficient. Preserve both internal FFN seams and approved W roots.
Require wrong independently expected input/output/context and changed proof
messages to reject. Exactly repeated valid bytes/context remain valid to a
stateless verifier; application nonce consumption is outside this proof.

The codec must include all attention/FFN proof components, canonical field
elements, version/type tags, bounded lengths and complete consumption.
Unsupported compact backend/global folding modes must refuse. A decoder
test must not derive trusted validation bounds from the candidate proof.
Use bounded profile checks before low-level verifiers. Preserve legacy flat
serializers and B3's proof domain unchanged.

Demonstrate separate-process verification with bytes plus independently
provided expected public state, no witness/export/prover execution. Test
truncation, extension, bad tags/counts, noncanonical fields and mismatched
expectations. Record exact commands, source/proof hashes and limitations.
Only public synthetic fixtures may be persisted in the repository.

Builds and substantive CPU runs use `/tmp/zk-heavy.lock`, two build/Rayon
threads; expected >5min jobs require persistent detached logs/markers.
No GPU/8B runs or whole-private-proof, no-wrap or throughput claims.

## Handoff

Publication update: round 4 committed and pushed as `5657a8d` on
`perf/zk-batch-optimizations`. The closure snapshot below intentionally records
the validation-time state. Current work is [round 5](ZK60_PARALLEL_ROUND5.md).

Implemented and validated in the main working tree; **not yet committed**.
The concurrent board-only commit `2c88e4a` is preserved and changes no source
covered by these tests. All Codex workers and substantive jobs have finished.

- **124 release Rust tests, 48 targeted Python tests, four frozen CPU proof
  artifacts pass**, exit 0. Full proof SHA-256 and lengths match the old
  v2/v3/P1-seed-1 fixtures. The four locked gates took about 147 seconds.
- `prepare`, `prove` and a separate `verify` process pass. The verifier uses
  only proof bytes, externally supplied public expectations and approved
  roots; no oracle, witness, weight generation or prover execution.
- Public synthetic expected state: **2,120 bytes**. Complete public receipt:
  **2,144,946 bytes**, persisted with its validation record. Wrong approved
  roots and attempted overwrites refuse. Freshly recomputed arithmetic proofs
  with wrong expected input/output reject at the external boundary in tests.
- B3's pre-extraction roots and approved metadata digest are independently
  pinned from the unchanged round-3 checkout. Existing arithmetic and frozen
  transcript paths remain unchanged. Eight inherited attention warnings
  remain; no whole-repository formatting rewrite was performed.
- Review found cached GPU enablement makes environment-only refusal
  insufficient; B4 now refuses GPU-enabled builds before touching hardware.
  Process-isolated policy tests and cross-domain tests pass. The codec is
  bounded and structurally checked, not a whole-verifier panic-freedom theorem.

Evidence: [combined validation](../../results/zk60_round4_validation.json),
[receipt/demo](ZK60_PUBLIC_RECEIPT.md), [codec](ZK60_PUBLIC_WIRE.md),
[overall milestone map](ZK60_STATUS.md).

### Next tasks, with ownership

1. **Codex — public verifier hardening.** Handle challenge-derived zero
   denominators explicitly at legacy attention/FFN verifier boundaries and
   add deterministic negative coverage without altering accepted legacy
   transcript bytes. Add broader hostile-input tests before any network
   service. The exceptional assertion path was found by inspection, not
   reproduced; it is not evidence of a practical arbitrary-byte exploit.
2. **Codex — CL1 integration review and regression infrastructure.** Review
   Claude's actual `zk60-cl1` handoff at `15eeda6`, including pad/coset-aware
   chunked openings and allocation lifetimes. Coordinate shared-file
   integration and rerun merged-tree gates before promoting it. Separately
   repair the full Python suite's export-fixture path selection with explicit
   validation, not silent skips or copied private data; Claude reports three
   failures and one error caused by the old non-WSL fixture path. This round
   ran only the 48 targeted hashline Python tests, not that broader suite.
3. **Fable — independent whole-profile privacy/identity review.** Existing
   F1 brief remains ready for its own session. Audit actual joint opening
   groups, masks and reuse; resolve the singleton-mask hazard and specify
   P3 stable-model consistency. Passing public tests does not clear this gate.
4. **Codex — actual private block after review.** Implement A03/A04 pending
   ownership and private relations, then close internal seams on the actual
   commitments before one opening. Progress from one block to two before
   embedding/head/token/KV coverage. B4 does not complete private A07.
5. **Claude — after the delivered CL1 task.** Keep GPU/PCS ownership; prepare
   a resource-bounded repeat protocol and 5090 handoff. Any new full 8B laptop
   GPU run needs a separate safety decision; do not infer permission from
   the flat four-layer peak or the user asking for continued work.

Coordination: Codex waited behind Claude's shared lock without interrupting
CL1. Its floor log ended with exit 0 and the lane is pushed but not merged;
the source has not been reviewed here. Main-tree board commit `2c88e4a`
records the handoff. Single-layer worker timings are not 60-tokens/s or a
whole-private-proof security result.
