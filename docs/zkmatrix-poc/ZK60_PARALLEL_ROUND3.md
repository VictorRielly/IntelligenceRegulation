# ZK60 round 3 — mapped claims and a tiny block proof

Opened after Victor requested commit/push and continuation. The completed
C0/round-1/round-2 snapshot is committed and pushed as
`24ae7466aad9e0f56be442ed2a8fad04cf7b5f15` on
`origin/perf/zk-batch-optimizations`. Previous evidence remains historical;
its references to an uncommitted tree describe when those checks ran.

## Ownership before work

| Lane | Owner / checkout | Writable scope |
|---|---|---|
| A01 observable attention schedule | Codex inventory worker, `/tmp/zk60-round3-Uz3L1F/inventory` | new `hashline/src/attention_schedule.rs`, `hashline/tests/zk60_attention_schedule.rs`, `docs/zkmatrix-poc/ZK60_ATTENTION_SCHEDULE.md`; minimal opt-in metadata instrumentation in `hashline/src/attention.rs`; local `lib.rs` |
| B3 fixed-oracle public block proof | Codex correctness worker, `/tmp/zk60-round3-Uz3L1F/block_proof` | new `hashline/src/public_block_oracle.rs`, `hashline/tests/zk60_public_block.rs`, optional `hashline/examples/zk60_public_block.rs`, `docs/zkmatrix-poc/ZK60_PUBLIC_BLOCK.md`; additive public synthetic fixture helper in `causal_oracle.rs` if needed; local `lib.rs` |
| A03 reviewed interface preparation / integration | Codex lead, main tree | new `docs/zkmatrix-poc/ZK60_PENDING_FFN.md`, new `hashline/tests/zk60_pending_layout.rs` (pure layout/count oracle), shared boards/task JSON/evidence; integration of reviewed worker changes |

Workers are Codex agents, not Fable or Claude. Fable's independent privacy
review remains explicitly queued, including actual opening-group rank and
P3 approved-model consistency. Claude's current task and reserved `gpu/`
and `pcs.rs` files are not modified. Workers do not commit/push, edit shared
boards, alter proof parameters, or enable unsupported private commands.

## Acceptance

- A01: record the real executed argument/claim schedule, not only a
  hand-maintained list. Cover sumchecks, direct linear checks, A/W/H claim
  sites, helper sums, ranges, internal and cross-layer seams; distinguish
  supported fixed-profile coverage from unobserved branches. Metadata only,
  no witness values or evaluations. Check honest replay, order/count drift,
  malformed schedules and unchanged proof bytes when instrumentation is off/on.
  This is an inventory prerequisite, not proof privacy or a complete audit.
- B3: feed the fixed-calibration oracle into the existing **P0** block
  prover/verifier, with both internal FFN seams and independently approved
  public W/gamma roots. Preserve the original approved P1 contract object;
  explicitly treat this as public validation of its arithmetic. Rebuilt
  inconsistent witnesses or mismatched statements must reach verifier
  rejection when safely supported. No private proof or generation claim.
  A decoder is not implied by merely serializing existing proof objects.
- A03: specify actual prepare/argument/seam/open ownership, reserved masks,
  transcript order, two-extension obligations, memory lifetime and versioned
  compatibility. Do not refactor a private production path before interface
  review and the unresolved mask-rank/joint-transcript gate.

Only bounded tiny CPU work; jobs/builds use `/tmp/zk-heavy.lock` and two
threads. Runs expected over five minutes must be detached with logs/markers
using a tool/environment that supports persistent processes. No GPU/8B run
or externally reproduced performance claim. Lead reviews and validates
integration and records exact commands and unresolved gaps before closure.

## Handoff

**Bounded integration complete.** All workers have handed off; no round job
is running. This continuation is validated separately from the already-pushed
`24ae746` snapshot and prepared for its own lead commit/push checkpoint.

- **B3:** one fixed T32/d16/f16 public block proves/verifies with both actual
  internal FFN seams and independently approved W/gamma roots. Six tests
  include freshly recommitted mismatched X and residual Z-copy witnesses,
  changed weights and statements. Payload is 2,137,764 bytes, excluding
  wrapper framing. The exact public short-W subcube adapter fixes the tiny
  128-value-slice/256-column mismatch without changing roots or parameters.
- **A01:** four tests pin 593 prover, 586 replay and 562 shared metadata
  events, 12 argument sumchecks and 133 claim-value slots. On/off component
  bytes match; side-specific fingerprints and a conservative source guard
  detect drift. Persisted public traces are in `results/zk60_round3_attention/`.
  This records layout/arity/order, not point-transform or masking correctness.
  Cross-layer coverage is only a synthetic hook replay, not a two-block proof.
- **A03:** reviewed interface proposal plus four pure layout/count tests.
  The enclosing block owner must retain both pending component states and
  route claims before opening either. Wrong request-context rejection and
  application-level replay consumption are distinguished. Legacy terminal
  order is grouped by X/Z/rd/hz, not interleaved. No pending ZK prover is
  implemented, and no whole-profile privacy review is claimed.
- **Combined gates:** 108 release Rust tests, 48 targeted Python tests and
  four frozen CPU proof files pass, exit0. Full SHA-256 values and sizes are
  unchanged; the four locked two-thread compatibility runs took about152s.
  New-file formatting and whitespace checks pass. Eight inherited attention
  warnings remain. Commands, outputs and hashes are in
  `results/zk60_round3_validation.json`.

No GPU/PCS/private-core source, named reviewers' reserved files or current
Claude task was changed. No GPU, 8B, full Python/native-suite or statistically
quiesced performance run is claimed. B3 has no external input/output binding
or complete hostile-byte decoder. Private application use and the 60-tokens/s
goal remain unachieved; the substantive privacy gate is still open.

### Next independent assignments

1. **Fable / independent privacy reviewer:** the F1 brief in
   [ZK60_EXECUTION.md](ZK60_EXECUTION.md) now links to the executed A01
   schedule and A03 owner/mask-layout proposal. Review the actual core and
   seam composition before approving a concrete private mask/claim layout.
   The Codex interface reviewer checked ownership/order/count facts only;
   Fable's substantive privacy and P3 approved-model review remains queued.
2. **Codex, CPU-only public receipt rung:** first specify the independently
   expected input/output relation and request context for B3, then bind it
   to the actual arithmetic commitments. Add a new complete bounded proof
   frame and a separate-process verifier using only expected public state.
   Wrong input/output/context, truncated/extra messages and changed weights
   must refuse. Use public synthetic data: this is not permission to expose
   sensitive inputs through P0. Existing component serializers are not a
   decoder, and a stateless verifier does not consume replayed nonces.
3. **Codex, private composition after review:** implement the approved A03
   block-owner lifecycle and A04 attention lookup side in separate files,
   preserving legacy fixtures. Connect actual arithmetic commitments rather
   than separately committed copies. Whole-profile masking, integer/range
   obligations and all required interfaces must be reviewed first.
4. **Claude, after finishing its current task:** CL1 remains the bounded
   GPU-memory lane. A03's 36,974,592-byte A+H data/encoding count is a tiny
   partial retention budget, not peak RAM or a GPU measurement. Account for
   simultaneous pending attention/FFN ownership when planning lifetimes.
   No reassignment or interruption of its current work is implied.

No assignment depends on pretending the tiny public proof reaches the
60-tokens/s target. The 5090 benchmark lane still requires the documented
driver/device checks, quiesced runs and complete coverage/security gates.
