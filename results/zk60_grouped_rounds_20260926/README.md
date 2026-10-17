# Native grouped-equality softmax candidate, 2026-09-26

**Benchmark completed; reviewed 2026-09-27 UTC:** six runs pass with the same
40,783,352-byte receipt and successful verification. The predetermined two
non-warm samples per arm give old prove 37.63 / 36.84 s versus new 34.86 /
33.31 s. The precise phase means show an **8.45% observed proving-time
reduction**, 18.39% in the complete softmax slot, and 7.16% in the known
witness+prove+serialization sum. Enclosing test-process time fell 6.97%.
Warmup proving times were nearly equal: 34.69 / 34.38 s. This small shared
two-thread CPU diagnostic includes test oracles; it does not establish a
controlled production speed factor, p95, GPU result or 8B throughput.
All six log hashes, runner hash and terminal marker were independently
checked. [Audited observations](dense-ab-1/measured-summary.json) are reproduced
by `python3 results/zk60_grouped_rounds_20260926/summarize.py`; this only reads
the retained evidence and writes a summary, without rerunning proofs.

**Later checkpoint, 2026-09-26:** full CPU validation has completed: all nine
steps pass, including **512 native library tests, 17 ignored**, core debug and
release (73 unit + 2 integration each), and fresh/cross-version receipt checks.
All 183 source hashes, three binary hashes and nine log hashes were independently
rechecked with no mismatch. `validation-1/run.done` is zero. The continuation
advanced to `dense-ab-1/`, whose grouped A/B is now complete as recorded above.
The queued-state notes below
describe the earlier checkpoint and are superseded by this paragraph.

Victor's later workload clarification permits larger token counts to amortize
startup, targeting an RTX 5090 or another high-end GPU. See the current
[throughput target](../../docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md).

Experimental source in `/tmp/zk60-groups-20260926`, based on the validated
R2a/R1d candidate. Main and both earlier source/binary baselines are unchanged.
`candidate-v1/`, `candidate-v1.patch` and `source-changes-v1.json` retain the
four-file change. `validation-1/validation.json` and its terminal marker are
the authority for native validation; no result is inferred from a queued job.

The previous research experiment is now a native `GroupedEqRounds` evaluator
behind `SumcheckRounds`, used by the actual private block's SC_SZC slot. It
factors the three distinct equality polynomials out of the brackets, samples
each bracket only to its own degree, and reconstructs the unchanged advertised
round arrays. Each group uses only its own preceding actual unmasked round to
recover the sample at one. The first round is unseeded; a zero factor uses
explicit evaluation without refusals or new challenge draws. Split equality
tables preserve partial supports; all original tables still fold in their
original order for final openings. Memory elimination is not part of this port.

SC_SZC keeps separate score and row-sum support gates, all limb/helper clauses,
and continuing pad powers. Its shared polynomial was rewritten as the sum of
three bracket closures; that polynomial is reached by verifier and extension
code too. **The claim is semantic equivalence, not unchanged verifier source.**
The test-only copied stage-35 expression and slot IR remain independent oracles.
The round evaluator assumes correct equality metadata and bracket degrees from
its caller; it does not validate those algebraic preconditions itself.

Core debug and release each pass 73 unit + 2 integration tests. New tests cover
exact masked bytes, challenges, folded tables, final values, transcript state,
one/two extension-round parity, partial/offset/empty supports, one/two-thread
parallel paths, zero factors/prefixes, and a wrong-support negative control.
The generic extension fixtures check parity, not acceptance of arbitrary
extension vectors. Real profile acceptance/refusals belong to the native gates.
The native test-build oracle compares bounded real slots only (<=2^18 table
elements); it is not a large-profile byte-equivalence test.

Release counts reproduce **1,403 -> 1,148 expensive bracket evaluations** in
the 256-row padded fixture, an 18.2% reduction. Equality weights, inversions,
interpolation and dispatch add work, so this does not establish runtime speed.
No GPU run, trained weights, 8B result or privacy extension is implied.

A read-only review by the session research agent found no blocking algebraic
defect and identified the limitations above. The initial debug log is retained:
one new test attempted to create a CFS mask with zero main and extension rounds,
unsupported by the original mask implementation. The fixture now skips that
combination; the original implementation was not changed to accommodate it.

The native validation runner retains commands, source/binary/log hashes, fresh
proof verification, old/new receipt compatibility, and corruption refusals.
The independent allocation A/B is under `../zk60_encode_allocation_20260922/`.
These are shared-CPU diagnostics; native compilation overlaps part of that
allocation A/B, so it is particularly unsuitable for a quiesced speed claim.

## Completed and queued gates at this checkpoint

- `receipt-gate/validation.json`: four real processes pass (fresh proof,
  fresh verifier, old verifier on new receipt, new verifier on old receipt),
  including nine corruption refusals. This is the toy receipt.
- `targeted-native/validation.json`: five bounded native tests pass: rejection
  of inconsistent witnesses across every toy relation family, honest dense
  rung-G and rung-P2 blocks, an honest three-block dense rung-P2 run, and a
  tamper inside the unpadded domain. These exercise accepted actual-profile
  extension rounds and verifier refusals.
- `polynomial-oracles/validation.json`: three tests pass across **every
  registered shape**, including 125M: the copied original expression, the
  independent stage-34 IR, and table order/degree checks. These are polynomial
  checks, not a 125M proof or proof-speed measurement.
- `validation-1/validation.json`: core debug/release and native builds pass;
  the full native suite is **queued on the held shared heavy lock**. Original
  tool session: 76580. It has not been killed, restarted or reported passed.
- `continue_after_validation.py`, tool session 16979: bounded one-hour waiter
  for that existing validation, then the source-pinned dense 125M A/B against
  R2a. It refuses to benchmark on a failed validation; `continuation.json` and
  the eventual `dense-ab-1/comparison.json` record its progress. This yielded
  process is not guaranteed to survive application or machine restart.

The persistent research supervisor is separately verified alive on the host;
`research-supervisor-health.json` records the check. It is idle until its next
hourly cycle (2026-09-26 18:52:33 UTC), after a sandbox-start failure. The host
restart itself does not count as a successful new research cycle. The separate
session research handoff is complete. No production source promotion or broad
test-suite/GPU/privacy acceptance has occurred at this checkpoint.
