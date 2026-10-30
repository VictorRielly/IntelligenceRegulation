# Public tied-table cache contract — cycle 0131

Run `20261029T005649Z-c94ef085`, 2026-10-29 UTC. No native proving gain.
The contract passes synthetic checks, but this exact seam removes **zero
work from current Llama-3-8B**, whose model is untied. The owner may find the
conditional result useful for Shieldstral 3B. This is a research handoff;
main/Claude reviews and integrates. No merge or heavy job was launched.

The current ranked queue retains all 46 prior hypotheses. Top three remain
whole-prover high-end GPU with verified fixed-context resident 1/2/4/8;
DD/fidelity context scaling after the T128 null result; complete exclusive
phase/capacity clocks. Hypothesis 46 is refined by these tests and the zero
8B incidence; 47 adds per-request coalescing, 48 adds the newly assessed
polynomial-preprocessing security filter. See `hypotheses.json`.

## Baseline and integration seam

The source-only call chain in the retained R13 classifier tree is:

```text
classify_cli prove 494 / verify 612: load_export
  ExportPublic::load 208 -> TrainedExport::load
    trained_block.rs 1032 -> tied_of 538
      recompute_declared_tied_tables(..., None) 600
classify_cli prove 500 / verify 627: load_tied_classifier_tables
  classify_tied.rs 234 -> recompute_tied_tables(..., Some(margin))
```

These are two source sites, not observed runtime call counts. Both derive all
embedding/head/multiplier digests. The second also returns the classifier row.
Per omitted Shieldstral derivation, the source has a logical-read lower bound
of 7,698,241,104 checkpoint bytes + 805,306,368 tied tensor bytes =
8,503,547,472 bytes, before prefix/header rereads. This is neither DRAM traffic
nor a measured time. The owner note of 17–18 seconds/load is for this 3B model.
There is no transfer of that clock to 8B or to a startup fraction.

`trained_statement::tied_tensor_for_profile` 566 returns a tensor only for
Shieldstral. `tied_of` returns immediately for an undeclared untied model.
The inspected Llama-3-8B path therefore has no work to remove at this seam.

Proposed owner interface: one private-field, authenticated public result with
exact profile/model/tensor/sign/derivation-version binding, shared between
the base projection and the already bound margin. Design only:
`candidate-interface.rs.txt`; actual Rust compilation and implementation are
absent. The existing `RecomputedTiedTables` has public mutable fields and
cannot itself attest authentication. Even a frozen Python dataclass can be
publicly constructed/replaced; the harness demonstrates this limitation.

## Measured experiment

Final `result.json`: **1,717 checks**, including **1,067 negative controls**,
32 fixtures at vocabulary 2/3/8/17 and width 4/8/16/32, block width 4/16,
random and zero-row inputs. Independent dense Hadamard/Fraction decoding and
binary64 rounding versus candidate butterflies, BF16 decode, f32 embedding
rounding, three exact output hashes, margin and immutable-use projections.
Both implementations are locally authored and neither executes native code.

Checking took **0.648750 s**, **18,856 KiB peak RSS**, one pinned nice-19
Intel Core Ultra 9 185H CPU worker. Seed `202610290131`; 64 MiB estimate,
256 MiB address-space, 40 s CPU and 45 s alarm caps. Every experiment was
single-threaded and below one second. Commands/source hashes/exits are in
`execution.json`, `commands.json` and retained adaptive directories. No A/B
timing or actual proving improvement follows from checking time.

The initial no-op block mutation was a bad test (the replacement equalled
the original), corrected with its failure retained. The initial exact-rational
comparison then found a useful semantic difference: two of 32 fixtures have
three head bytes different from native-style binary64 quantization. Dense
binary64 and candidate agree. One edge is -2.0625 divided by
`4.125/127`: binary64 produces -63.50000000000001, hence floor after +.5 is
-64; exact rational gives -63. This is not a native bug. Preserve the original
binary64 quantizer and operation order. `rounding-edge.json` and initial
fixtures retain the counterexample. No production/native oracle was run.

## Useful negatives and required invariants

- Same path/device/inode/length/mtime can contain changed bytes; the metadata
  cache accepts stale data while full authentication refuses. ctime was not
  held fixed. This tests a proposed unsafe cache, not an upstream cache bug.
- A snapshot still describes its original data when the live file changes or
  disappears. Consequently it is **not** a transparent replacement for the
  live loader's refusal domain. An explicit snapshot API and review are
  prerequisites; existing APIs and their refusals must remain reproducible.
- Changed profile bytes, caller statement digest, scale, yes/no IDs,
  threshold, signs, calibration or derivation version cannot use the old
  result. All actual exported-table hash comparisons still run. Updating a
  forged table's own digest cannot make it match the authenticated derivation.
- Norm bytes come from the full authenticated read; the later consumed tensor
  is separately hashed. The mutation controls exercise both boundaries.
- A changed unselected row changes global head multipliers while leaving the
  margin unchanged. Deriving only the two verdict rows cannot replace initial
  whole-table derivation. No clipping or rounded-row subtraction is allowed.

The synthetic dimensions/headers/classes are scaled fixtures, not admitted
native profiles. Full native calibration, exact refusal order, OS races,
Rust ownership/concurrency, transcript/RNG, PCS, complete receipts and privacy
remain untested. No real weights, prompts, activations or tokens were read.

## Costs, ceiling and falsification

Count-only fixed-profile schedules: two source derivations per request give
2P baseline calls; coalescing can give P; an approved explicit resident
snapshot can give one in its own process. A fresh independent verifier must
authenticate its own public object; it never trusts the prover's cache.

If a baseline request is `2D+R` and coalescing is `D+R+a`, its isolated
free-coalescing ceiling is at most 2x, with unknown D, R and added cost a.
For P resident requests include initialization I and drain in the actual
workload: `I+D+P*(R+a)`. No measured startup fraction or numerical rate exists.
New costs include initial full derivation, binding checks, owned object
lifetime, actual table checks, residency and review. The margin payload is
6,144 bytes at native width, plus 96 digest bytes and calibration/ownership
overhead. This does not remove the existing embedding allocation or total
model/proof memory. All fresh masking, commitments and independent verification
remain. Direct current 8B speedup through this seam is 1x.

Falsify on absent duplicate incidence, parameter/source/profile/quantizer
mismatch, changed unreviewed refusal behavior, native byte/RNG/PCS/receipt or
privacy failure, or slower/over-capacity complete verified workloads. Owner
first measures the exclusive two sites and enclosing startup/witness/proof/
serialization/verification clocks. Only then consider a reviewed implementation
under current shared locks. No additional 3B cache-only refinement is planned.

## Sources and next action

Native LIVE primary searches covered preprocessing, recent sumcheck releases,
zkML decomposition and older lookup methods. A new 2025 preprocessing paper
revised August 2026 explicitly separates evaluation binding from stronger
security; its PDF returned 403. DeepProve's immutable May 2026 README describes
cached proving contexts; its inspected license is custom Lagrange, not the old
permissive split. No external code was used. Known zkComposer, Lasso, MLE
lookups and private-table lookup references were screened for compatibility.
The current Plonky3 release page supersedes a stale search snippet.

A newly found September SASH measurement note is a methodology lead only:
it reports dominant trace/lookup preparation and explicitly omits blinding,
with public tokens. Its rates cannot establish this private target. Source
dates, exact URLs, commits, licenses and fetch limits are in `sources-cycle.json`.

Next local: return to current untied 8B `ExportPublic::load` / trained layer
reload. Audit repeated public-data conversion/digest work against prior
loader findings, then test a bounded immutable-input, streaming digest/parse
projection with changed-layer/refusal controls and a phase/lifetime census.
Owner phase clocks outrank all synthetic kernel/cache work.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context/device: none; experiment device CPU only. Witness,
proof, serialization, verification, startup/prefill, startup fraction,
latency/bytes and steady/total-workload rates: **unmeasured**. No long-context
prefill, resident-model proof series or decode ran. Larger workloads remain
allowed; attention can grow quadratically. Private 8B >=50 proved tokens/s
on RTX 5090 or another named high-end GPU remains unachieved.

Final direction reread: D45, recorded 2026-10-29 01:04 UTC, fixes one policy
and threshold per classifier item, makes classifier content length public,
binds the proof to its post and requires fail-closed publication. Cache
parameter mutations are refusal tests, not permission to reprove the same
item under different policies. This classifier ruling does not alter generic
private 8B throughput acceptance. The changed decision-register snapshot and
diff are retained in final-direction-check.json; target and agenda unchanged.
