# Round 10 — actual proof-size telemetry and continuation

Integrator baseline `52a13d1`. Victor requested continued implementation,
a status update and a concrete continuation plan. Codex refreshed origin;
the latest published Claude/Fable GPU lane remains `3ad4d97`, with no new
lane working-tree edits observed at pickup. The round-9 review still applies.

## Work selected

Codex takes the implementation side of **CL19**, which already proposes a
size-breakdown handoff into Codex-owned serializer/CLI files. Fable keeps
GPU/PCS/planner ownership and the independent review tasks. No GPU lane
source is merged or edited, and no subagents are launched here.

The remaining CL10 byte residual came from subtracting modeled fields from
the observed artifact. `LayerProofZk::size_breakdown()` now counts the actual
proof object's serialized field lengths in the separate `zk_proof_size.rs`
module. It allocates no second proof buffer, reads no witness values, and
changes neither the serializer nor any transcript/mask/RNG operation.

The categories cover:

- Three commitment headers and the mask root.
- All six arguments, each split into its claim/challenge, round evaluations
  and terminals; the optional predicate is counted separately.
- Plain W, hiding W, A and H group/proximity vectors, with column indices,
  base-field values, salts and authentication paths separated.
- The mask opening's functional response, proximity vector and salted columns.

P1's plain W has no salt bytes; P3's hiding W does. Empty optional fields
contribute zero, while repeated indices and ragged physical columns are
counted exactly as serialized. No residual category is obtained by subtraction.
The categories are not contiguous offsets: column framing and values are
interleaved in the existing wire format. The API refuses missing mandatory
commitments but does not otherwise verify the proof or infer its privacy mode.

## CLI contract

The existing CPU-only `pass --zk --profile v3 --phase-profile` command now
prints one `HASHLINE_PROOF_SIZE` JSON row per actual layer. `--p3` works in
the same scope. Default output is unchanged when profiling is off; existing
unsupported-command and GPU profiling refusals remain in force.

Schema 1 records byte units, `coverage=ffn-only`, profile/privacy/layer,
`serialized=true`, `pass_verified` and the nested byte counts. It follows
`HASHLINE_TIMING`, after all recorded proof-ready and verification clocks.
An invocation using `--no-verify` explicitly reports `pass_verified=false`.
Rows count each actual layer rather than projecting layer 0, which matters
when only the last layer contains a predicate.

Example, with an existing synthetic/public diagnostic export:

```sh
hashline/target/release/hashline pass 1 16 --threads 2 --zk --profile v3 --export /path/to/export --phase-profile
```

The library also exposes typed counts and `ProofSizeBreakdown::to_json()`.
This is physical byte accounting, not a timing measurement, a privacy audit,
a standalone private-FFN decoder or an expanded proof relation. CL20 can use
these categories as compatibility checks; code extraction remains lower priority.

## Validation

Validation completed under `/tmp/zk60-round10` with exit marker **0**:

- **156 release Rust tests passed, 0 failed, 0 ignored**, including five new
  byte-accounting tests. Existing fresh-randomness P1/P3 and verified predicate
  tests now check the counter against actual serialization.
- **39 Python consumer tests passed**: profile parser 11, benchmark collector 28.
- All four frozen CPU artifacts retain full SHA-256 and length. The ZK v3
  12-layer proof matches its frozen **87,697,008 bytes** with profiling enabled.
- All 12 ZK v3 per-layer JSON rows match the original per-layer sizes and sum
  to the artifact. Additional P3 and unverified P1 rows also reconcile exactly.
- P3 one-layer/T16 proof files are byte-identical with profiling off/on.
  Default output contains no size rows; `--no-verify` rows explicitly report
  `pass_verified=false`. Size output follows the captured timing row.
- The original `LayerProofZk` layout and `size_bytes`/`to_bytes` implementation
  are source-identical to the baseline; no serializer was replaced to force parity.

[Exact validation evidence](../../results/zk60_round10_validation.json)
records source/binary/log hashes, full proof digests, the actual size rows,
commands, exits and resource measurements. Runs use two threads, offline
builds, the shared heavy lock and an 8 GiB per-process address-space cap.
Maximum reported RSS is **1,667,800 KiB** with zero swaps.
The unchanged broader Python/native suite retains round-8 evidence; it was
not rerun for this Rust-only addition. No GPU or performance benchmark was
executed. The initial sandbox detached child stopped before running; the
approved detached relaunch completed all gates.

CL19 is complete on the integrator side. Fable can consume the actual-object
counts for CL10 instead of preparing another serializer implementation.

## Current status and next work

The accepted foundation remains the tiny public block/two-block receipts,
verifier hardening, actual FFN disclosure diagnostics and atomic public cache.
The lane's archived 12 byte/49 oracle cases are credited at `82314a1`; the
combined GPU gate and CL13–CL16 corrections are still assigned to Fable.
The known FFN privacy and P3 approved-model identity gaps remain open.

The next Codex work is **public-observation support for FA2**: define a
test-only capture contract for the actual H and P3 W openings alongside A,
including the exact reconstructed claims, public opening and verifier
transcript boundaries. The integration sites are the P3 `wcz` verification
branch and the final `hc` verification call in `verify_layer_zk_v3`, surrounding
the existing A observer; the ordinary P1 W branch stays explicitly plain. Release captures only after the entire FFN verifies;
compare an independent replay against ordinary PCS verification. Keep
witness/RNG/full private pad state outside the capture and mark unsupported
cases explicitly. Start with tiny CPU fixtures and coordinate the new
observer contract through the shared queue. This supports Fable's independent
joint review; it cannot count as that review's completion.

After Fable delivers the joint exposure analysis and an accepted complete
mask plan, Codex implements the reviewed repair in a distinct profile,
then pending attention/FFN composition for one private block and two connected
blocks. Review/integrate the GPU lane when CL17 evidence matches the final
source. The maintained `zkp-core` extraction follows the validated baseline
at priority 3, preserving the experimental paths and their history.
