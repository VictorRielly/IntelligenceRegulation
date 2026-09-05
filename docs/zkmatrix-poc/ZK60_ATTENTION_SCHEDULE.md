# A01: executed attention claim schedule

Round 3, Codex inventory worker, 2026-09-04 local. This is an opt-in,
metadata-only inventory prerequisite, **not** a privacy/soundness audit,
full-private-block proof, decoder, or throughput result. Claude's reserved
GPU/PCS files and Fable's independent review queue were not modified.

## What is observed

`attention_schedule::Capture::begin(true)` records calling-thread execution;
the default path records nothing. `finish()` returns a typed `Trace` with
fixed semantic role/site labels and named numeric metadata. No field values,
evaluation results, challenges, tensor values/digests, commitment roots,
histogram entries/nonzero indexes, timings or GPU counters are recorded.
Only public offsets, logs, lengths, arities, table tags and schedule indexes
enter recorder calls. The observer does not alter the transcript or arithmetic.

Instrumentation sits at the executed sites, not only in a static checklist:

| Hook | Metadata / semantic role |
| --- | --- |
| `Ctx::sc` | Sumcheck name, degree, variable count and domain length |
| `Ctx::check` | Reached direct/terminal equality check and fixed equation label |
| `Cc::take` | Ordered transcript claim-value slot index; never its value |
| `Cc::a1/w1/h1` | A/W/H commitment role, slice offsets/logs, point arity and claim index |
| `Cc::hsum` | Extension helper pair offsets, sum domain and claim index |
| `terms` | Terminal table order, public/A/W/H/class-reconstruction role, parts and arity |
| `build_helpers` pair writer | Actual produced helper-pair offsets and lengths; prover only |
| Argument lookup layout | D/Q/KV lookup descriptors taken from the actual layout helpers |
| Special lookup descriptors | S-domain exp/probability/remainder and packed norm-limb roles |
| Histogram traversal | Visited table tag/row count; individual multiplicities are excluded |
| `attn_seam/layer_seam` | Internal X/Z and cross-layer residual/input seam hooks |
| `collapse_range` | Public selected range, selected-claim count and executed folding sumcheck |
| W/H/A openings | Final opening-slice offsets/logs/arity after any wrapper adaptation |

Thirteen fixed argument section roles distinguish norm row facts, norm
squares, D ranges/norm/residuals, Q RoPE, KV RoPE, softmax, masked row
sums/selector, packed limbs, QKV, GQA scores, PV, output projection and the
LogUp helper/histogram identity. Each low-level event carries its enclosing
role. Special S/limb descriptor annotations complement the dynamically
observed claims/helpers; they are not a separate execution of each lookup
constraint. The full source guard below covers this annotation's source.

## Executed reference and acceptance

The reference uses B3's independent public synthetic weights/input and the
immutable A00 contract: T32, d=f=16, H=2, KV heads=1, head width=8, INT16
residual classes, two limbs at each norm, log_cols=8, inverse rate=8,
256 column checks, default folding. B3 retains the approved P1 contract but
explicitly proves only **P0 public arithmetic**. Both internal FFN seams
execute in the real proof. No two-layer proof executes in this lane.

An initial raw tiny attention opening hit the existing short-W limitation:
Wk/Wv slices have log7 while the PCS row has log8. B3's separately owned
`lift_public_weight_claims` adapter lifts these public claims into their
enclosing committed row on both sides. Its version is transcript-bound by
B3. A01 does not modify PCS or implement the adapter. The final opening
metadata exposes lifted slices, whereas the earlier terminal events retain
their original slices. Reference coverage depends on that reviewed wrapper.

Observed full-block payload is **2,137,764 bytes** (existing component
encodings, not a new framed transport). Profiling on/off produced identical
attention bytes and identical FFN bytes. Both proofs verified in memory.

| Event family | Prover | Replay |
| --- | ---: | ---: |
| Total events | 593 | 586 |
| Argument sumchecks / terminal-table batches | 12 / 12 | 12 / 12 |
| A evaluations | 89 | 89 |
| W evaluations | 6 | 6 |
| H extension evaluations | 19 | 19 |
| H extension sums | 19 | 19 |
| Claim-value slots (`take`) | 133 | 133 |
| Direct/terminal/seam checks | 12 | 24 |
| Terminal descriptors | 99 | 99 |
| Paired D/Q/KV lookup descriptors | 30 | 30 |
| Required histogram shapes / visited tables | 10 / 10 | 10 / 10 |
| Actual helper-pair builds | 19 | 0 |
| Collapse ranges / executed collapse sumchecks | 4 / 4 | 4 / 4 |

Replay executes twelve terminal checks that proving does not; proving builds
nineteen helper pairs that replay does not. `Trace::shared()` excludes **all
check events and helper-build events**, producing an identical 562-event
sequence. This is explicitly not equality of the complete execution paths.
Complete side-specific traces are retained and checked independently.

Frozen BLAKE3 metadata fingerprints (framed schema v1):

- Prover: `990fbb5a199e8e59aff18e606be729e0a8c4547fb63f9078630aa710dbd32162`
- Replay: `1ce8017710e21fc9c098d0d7513aef3239d02731ab0f26d764c50ac8a4b66429`
- Shared: `2d8d3be42c90b66dfa61af40b338effad3741fd8832dc2f54274a2db4751c7ce`

`check_fixed_reference` checks these explicitly; `ensure_matches` compares
complete ordered traces. Tests reject missing/extra/reordered/unknown events,
changed offsets, empty schedules, truncated proof claims and reordered
sumchecks. They do not regenerate expected snapshots from candidate output.

An independent conservative SHA-256 guard freezes the entire instrumented
`attention.rs` source as
`fec19c0f03a50052a92bf71579446d0885f543fc6fc45282a04f229aa9a732b2`, alongside
hook-family counts, the twelve actual `ctx.sc` call sites and nineteen role
sites. This catches deleted or newly uninstrumented source changes even if
someone regenerates a runtime trace. **It is a drift alarm, not a security
hash**: unrelated formatting also trips it and requires explicit review.
Any baseline update must review source/hook coverage and record the reason;
never automatically bless regenerated fingerprints.

## Running and inspecting

After integrating the exact B3 fixture/wrapper dependency, from the source root:

```bash
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 flock /tmp/zk-heavy.lock \
  cargo test --release --offline --manifest-path hashline/Cargo.toml \
  --test zk60_attention_schedule -- --test-threads=1 --nocapture
```

Unset `HL_GPU`, `HL_FOLD` and `HL_NO_FOLD`; the full-reference test refuses
non-default settings. The test also requires honest attention tamper mode.
No datasets, network access, GPU work or large model are involved. Builds and
substantive runs use the shared lock and two threads. Compilation took under
a minute in this checkout; the four tests themselves took about 0.1 seconds,
which is a correctness-run observation, not a benchmark.

For complete human-readable event listings, create a fresh local directory
and add `A01_TRACE_DIR=/absolute/new/directory` to that command's `env`.
The test writes `prove.txt`, `replay.txt`, `shared.txt` using create-new semantics
and refuses to overwrite evidence. Artifacts from this lane are under
`/tmp/zk60-a01-evidence-fwsPwy`. No proof/tensor values are written there.

The API also supports local programmatic inspection:

```rust
let capture = hashline::attention_schedule::Capture::begin(true)?;
// Execute an existing proof or verifier and separately require success.
let trace = capture.finish();
// trace.events / trace.listing() contain only recorded public metadata.
```

## Limits and handoff

- A reached check/opening event does not mean it succeeded. Always require the
  proof/verifier's actual result. Metadata alone is forgeable and is not a receipt.
- This does not observe coefficients, challenge-coordinate equality, PCS
  opening groups, joint mask rank, transcript challenges, or histogram values.
  It cannot establish point-transform correctness, privacy, soundness, integer
  no-wrap or mask freshness; it is not a complete private-masking inventory.
- No private attention implementation, INT24 residual branch, different norm
  limb count, alternative folding mode, large shape, GQA ratio, or accelerator
  branch is validated by this tiny reference. Different calibration may change
  table tags and therefore the schedule; do not call all A00 contracts covered.
- The cross-layer hook is exercised by a synthetic `Cc` replay with equal and
  unequal public scalar claims; it is **not** a complete two-layer proof or an
  argument that layer commitments/input-output semantics are bound correctly.
- Generic PCS internals and FFN-internal schedules remain outside this recorder.
  The separate B3 wrapper establishes the tested public internal-seam flow.
- Calling-thread capture is intentional; future claim scheduling from worker
  threads would require explicit design and new coverage tests.

Owned handoff: `attention_schedule.rs`, `zk60_attention_schedule.rs`, this
report, minimal `attention.rs` instrumentation and the single local module
registration. Exact copies of B3's `public_block_oracle.rs` and additive
`causal_oracle::public_synthetic_fixture` were used only as test dependencies;
they belong to B3 and are not A01 changes. No commits or shared-board edits.

Lead integration repeats all four tests after formatting and records the
same fingerprints/counts and byte parity. Exact metadata-only listings are
preserved in `results/zk60_round3_attention/{prove,replay,shared}.txt`;
`results/zk60_round3_validation.json` records the combined gate and source
hashes. These are local public diagnostics, not a cryptographic receipt.
