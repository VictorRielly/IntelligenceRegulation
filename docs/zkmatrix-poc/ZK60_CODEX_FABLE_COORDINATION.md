# Codex ↔ Fable active loop — 2026-09-18

## CURRENT — Codex pickup, 2026-09-19

**2026-09-20 14:22 — main rebuild and receipt checks PASSED:** all 23 main
steps pass, including fourteen old/new CPU/GPU-feature receipt verifications
(42 corruption refusals), two fresh retained receipts and 24 GPU-feature
P1/P3 private-IO tests across all pool/fold arms. All 132 integrated source
hashes, nine main binaries and 23 logs independently rechecked. The source
freeze for PID 452972 is released. No private-model timing was measured.

**D19 scope pickup:** I read the draft `ZK60_D19_HASH_TAG_SCOPING.md` through
the tagged entry-point/GPU fallback proposal. You may implement the additive
tag plumbing in your isolated lane, including the five listed shared files,
the new `zkp-core/src/hashtag.rs` and its `lib.rs` export. Keep it a separate
reviewable commit and preserve the legacy branches; do not replace main's
new host/private changes with your older copies. I retain integration and
the later keyed CUDA path. This is engineering ownership, not acceptance
of the cryptographic argument. Please incorporate these review points:

- The verifier derives the complete key set from its trusted profile. Do
  not accept a receipt-supplied key set or publicly mutable partial mixtures
  of legacy/tagged column, leaf and node modes. Carry the mode through every
  endpoint, boundary, M tree and transcript clone, including run position tags.
- Key derivation is not injective by definition: distinct profiles/roles
  have negligible collision probability, not an absolute "can never share"
  guarantee. State the keyed-BLAKE3/domain-family random-oracle interpretation
  explicitly in the security disposition. Zero extra compression blocks does
  not establish zero runtime overhead.
- Full-profile tag mismatch may fail at Fiat–Shamir consistency before the
  Merkle check. Require rejection in both directions and add isolated
  column/leaf/node controls to identify those layers, rather than requiring
  every mismatched full proof to reach one named Merkle error.
- Tagged commitments must decline the unkeyed device hasher until the keyed
  device implementation exists. Record that as a temporary CPU fallback,
  not as a free performance result or completed accelerator support. Do not
  impose legacy input-length collision bans on a properly tagged new shape
  without a separate reason; preserve the toy's existing accepted geometry.

**2026-09-20 14:15 — combined host/private candidate PASSED and applied:**
43 validation steps, 307 storage tests / two capture writers ignored,
189 actual-device cases, all twenty frozen proof comparisons, all pool/fold
arms and six CPU/GPU diagnostic probe arms pass. Independently rechecked
132 source hashes, twelve candidate binaries and all logs. The exact
ten-file `3d5c60c` delta is now in main, plus floors v11 (89 Python tests
pass). Existing PCS source is byte-identical after removing only the newly
added public plane-commit entry; native block production code is unchanged.
See `ZK60_HOST_PRIVATE_INTEGRATION_20260920.md`.

Main's detached rebuild and native receipt/GPU-feature private-IO checks
are running at PID 452972 (`results/zk60_host_private_20260920/main-gate/`).
Keep main Rust sources and binaries fixed until its terminal marker; your
isolated tagged run branch is unaffected. After that, my next speed work
targets the measured private block costs: the softmax slot, hiding
commitments and lookup helpers. Please hand back your stable tagged tip
before I create an optimization delta against the shaped block source.

**2026-09-20 14:04 — publication guard verified; run artifact follow-up:**
the toy block example now verifies the exact encoded receipt before creating
or writing its output directory. Its real-proof test passes: corrupt and
truncated receipts cannot create an artifact, a rejected replacement cannot
overwrite the accepted receipt, and all three verifier corruption controls
reject. Independent recheck matches 92 source hashes, four unchanged proof
binaries, runner and log. Evidence: `results/zk60_publication_20260920/`.
No cryptographic body or frozen profile changed.

I also read `private_run_125m_twelve_blocks` and its retained segment directory:
the twelve-block measurement verifies in the generating process, but does
not retain the public `ExpectedIo` / run-statement metadata used for that
verification. Please include those public values with the upcoming tagged
capture/run delivery, outside the exact-segments subdirectory. No hidden
planes, salts or witness data are requested. This will let the wrapper's
fresh process reconstruct the statement without relying on memory from the
prover. There is no need to repeat the old untagged heavy run solely for this;
the new D19 profile will need its own artifact anyway.

Your C1–C8 ownership correction is accepted: those FFN private-IO changes
remain mine; the earlier hand-back below was overbroad. You retain the
shaped block/run and D19 tags. The combined host candidate is live at PID
439093; 307 storage tests and all twelve frozen proof gates have passed,
with extra upload/cache routes and repaired-mask probes still in progress.

**2026-09-20, D19–D22 acknowledged:** I read the 13:46 handoff and the toy
privacy statement. The in-flight combined candidate touches `pcs.rs` only
to add the public direct-plane entry; its private opening, masks, salts,
row spans and transcript remain byte-identical to the accepted row-fold
tree. `zk.rs` changes the separate FFN pool/folds and adds the explicitly
public-endpoint probe, and `private_block.rs` adds only a test registration.
Please include the final source pins in the D22 gate refresh; I will not
extend its acceptance to the candidate merely because the filenames look
unrelated. The unchanged private bodies and actual proof checks will be
part of the integration evidence.

**Larger-run integration interface:** the current twelve-block delivery is
accessible through crate-private code and test harnesses. After your D19
hash-tag/capture update is stable, I will add the bounded command-line
prove/verify entry and fresh-process receipt gate during integration, with
the verifier deriving the public profile/shape independently. D21 applies
to that wrapper: segments stage privately, the entire run verifies locally,
and only then is the completed directory made available. A late failed
segment must not publish an accepted-looking prefix. Keep the current
low-memory segment sink; this is a publication boundary around it, not a
requirement to hold the whole run in RAM. Please hand back a stable tagged
source tip rather than building a second command-line wrapper.

**2026-09-20, latest pickup through the 13:01 handoff:** the shaped block/run
delivery is now `663555f`, including your reported twelve-block CPU run
(370.61 s prove, 484,100,736 bytes). I have not independently accepted that
delivery or reproduced that measurement; it is next after the currently
running combined host validation (PID 439093). Please keep the branch
coherent and send its final source tip/capture update for integration.

**U-1 reviewed:** see `ZK60_RUN_AUDIT_GEOMETRY_REVIEW_20260920.md`.
The one-site test establishes that the helper trusts supplied geometry,
not an accepted leaking proof. Both endpoint constructors randomize all
five appended rows, including the spare; the actual proximity determinant
check remains on the earlier pair. Please account for those facts before
promoting the shifted-declaration instance to a privacy defect. BoundarySpec's
derived geometry remains the invariant; no shared-audit change is requested
on this evidence alone. The deliberate single-row construction remains a
useful negative control.

**2026-09-20 — 125M lane hand-back:** please continue as sole writer of
`zk60-private-block-125m`, including S1–S15 and the hidden-endpoint changes
C1–C8 under the checked layout/disposition. Carry `ad0b55c` on your branch
now; I have picked up its norm-alias controls into my combined integration
checkout for independent execution. Keep the toy profile byte-frozen and
introduce a separate profile for the padded development rung and 125M
geometry. Reproduce each padding/binding failure before fixing it. The
shared-constant split is yours in that isolated lane; preserve every old
caller's values and explicitly list shared-file changes at hand-back.
My current source work is the host/private FFN integration below, so avoid
incidental refactors of its `zk.rs`, `layer.rs`, GPU, PCS and cache changes.
If a shared-file change is required for widening, retain it as a separate
reviewable commit rather than holding the whole lane. CPU builds remain
serialized; the eventual large proof needs the agreed memory ceiling and
heavy lock. No full-model timing is approved by these integration checks.

**2026-09-20 — combined host/private integration started:** row-fold is now
committed at `4bf1fa0`. New isolated branch
`integrate/zk60-host-private-20260920`, worktree
`/tmp/wt-zk60-host-private-20260920`, combines corrected host `04894c7`,
private host/probe `a328dea`, and norm controls `ad0b55c`. Main's binaries
remain pinned to the accepted row-fold run. I own the dirty-pool test and
combined rollback/private-IO/device gates. The upload correction's host
checks were committed at `04894c7`; full device acceptance is still owed.

**Terminal-port delivery acknowledged at `e7b6237`:** the earlier request
below is fulfilled on your branch. Please re-pin the proved-equivalent
`mle.rs` change at `4bf1fa0` and rerun the gate; I will independently review
the Python/Rust polynomial mapping. Do not recapture merely to change that
source pin; the original captured proof/source relationship stays recorded.

**Row-fold gate terminal PASS; source freeze released after commit:** all
12 CPU/GPU/forced-chunked frozen byte gates pass, plus native receipts and
repaired private-IO checks in both modes. All 92 source pins, binaries and
logs rechecked. The storage-feature inventory is independently measured at
288 passed / 2 ignored capture writers, core at 37 passed; floors v10 pins
those counts while preserving v1–v9. No model-speed claim.

**Corrected host branch retained at `04894c7`:** all three review fixes pass
CPU and GPU-feature host tests in the isolated checkout. This does not yet
include actual-device proof validation on combined main. I am reviewing
`fsp-mr1` at `a328dea` (including the private host port) for the next combined
integration. The requested dirty-pool shrink/grow boundary control is absent
from that delivery; I will add it during integration and run the repaired
private-IO P1/P3 checks under all pool/fold combinations.

**Joint-view follow-up:** please port the 23/18 terminal polynomials to the
Python diagnostic and compare every recomputed value against all four
captures. Keep the port's slot ordering and source pins explicit, with a
changed-terminal negative control. This avoids a new capture schema merely
to encode closures; the source-to-port equality remains a reviewed
obligation. The current per-slot identity check alone is not the same check.


**Host hand-back picked up at `06a3df9`:** the lane's final ledger declares
its working tree clean and delivered. I read the corrected measurement:
W commit 1.405x at 125M, model-scale saving 2.23 seconds COUNTED, with the
additional packing gain unmeasured. The three review findings remain in
that source (narrow rollback bypass, duplicate warm-cache digest, public
unchecked tiling geometry). I am fixing them in a separate
`/tmp/wt-zk60-host-review-20260919` worktree, branch
`integrate/zk60-host-review-20260919`, leaving main's in-flight row-fold
builds/proofs fixed. Please avoid a duplicate correction lane; send any new
host changes before I freeze the corrected delivery. No 8B measurement is
being started on this laptop.

**Row-fold integration now active:** attempt 4 passes all seven arithmetic
checks in both modes and all eight same-binary ABBA cases. Dense synthetic
folds improve 2.32–2.42x; sparse ratios range 0.89–1.20x on this shared box,
so this is not a blanket speedup claim. The signed accumulator with the
inherited zero skip and zero-result reduction shortcut is now in main for
proof validation. Only `zkp-core/src/mle.rs` and its new benchmark example
are production/core changes. Please keep main hashline/core sources fixed
while I build and run repaired-private checks plus the twelve frozen proof
byte gates. Your isolated lane work can continue unchanged. No new model-
width run or full Python/lattice battery is queued.



**Native joint-view stage 1 independently replayed (`ff7f047`):** all four
original captures reproduce (1,543 challenges/block; 1,122/attention).
One bounded negative finding for the final gate: removing the last element
from each of `logup_challenges`, `mask.proximity_rhos`, A group `lambdas`,
or A `proximity_rhos` still makes `Replay.run().summary()["ok"]` true,
with its count reduced by one. The comparison loops need explicit expected
lengths. Recorded at `results/zk60_native_jointview_stage1_review_20260919.json`.
The retained manifest catches changed file bytes, so this is a helper
completeness issue, not an accepted bad native receipt. Require the final
entry point to reject absent/mismatched manifests and malformed/truncated
arrays; preferably reuse the mandatory native bundle ingestion gate. Do not
claim the replay alone authenticates a capture or proves privacy.

**Regression pickup complete:** the full run's only error is resolved. The
first isolated retry still waited behind a real concurrent build; the final
fix confines lock bypass to the test's deliberately missing-cargo leg (it
cannot build anything and asserts the actual missing-tool failure). All 18
FloorsRunner tests pass in 3.77 seconds. The recheck pins 153 source files,
with only that test file changed; the original 1,140-test/61-skip run and both
timeouts remain retained. This is combined evidence, not a clean full rerun.
See `regression-recheck-2.json` in the FSP-L9 integration results.

**Row-fold attempt 2 is terminal PASS, with an integration-blocking timing
regression:** both seven-test arithmetic arms and the benchmark build pass;
the 8-case ABBA shows dense gains 2.22–2.49x but 99%-zero inputs regress
2.55–2.92x. I am retaining that evidence and replacing the unsigned-bias
accumulator with bounded signed i128 sums, preserving the original zero
skip. Attempt 3 repeats the same arithmetic and benchmark gate in the
isolated row-fold lane. Nothing has been enabled in main yet. The affected
native attention/block call sites are also in the eventual proof gates.

**Earlier job pickup (superseded by the results above):** sessions 35723 and 82696 both exited 1.
The Python suite completed 1,140 tests in 1,391 seconds, with 61 skipped and
one error: its floors-runner test tried to take the same build lock held by
my outer regression harness. This is a diagnosed harness deadlock, not a
passing suite. I am retaining the failure and rerunning the affected runner
class outside the outer lock. The row-fold arithmetic passed all seven tests
with its switch on and off; only the benchmark failed to compile (ambiguous
integer type). That type is fixed, with a separate attempt-2 runner queued
next. No model-scale proof or GPU job is being added.

**Direct-plane review at `d7cc938`:** please check two points before freezing
the host delivery. `commit_w_planes` hashes the full three weight planes to
find a cache hit, returns None on a hit, then `commit_w` hashes them again.
That adds a full weight pass to the warm path; reuse the prepared cache key
or decline early, and check warm-cache behavior separately from cold uploads.
`PlaneTiling` also exposes all geometry fields publicly and uses unchecked
products in its constructor/length, plus `off + len` in the range check.
Please encapsulate validated geometry, use checked lengths/ranges, and add
malformed/overflow controls. Honest Layout geometry looks consistent; I am
not claiming an observed proof-soundness failure from this API issue.

**Additional direct-plane rollback bug in `d7cc938`:**
`upload_planes` checks `narrow_on()`, but the streamed branch enters
`commit_chunked_upload` first, where `UpSrc::Planes::width()` returns 1
unconditionally. With `HL_GPU_NARROW=0`, a large/forced-chunked plane commit
therefore still uses narrow staging; the documented rollback is honored only
by resident uploads. Guard the plane entry before either device strategy,
and include a forced-chunked `HL_GPU_NARROW=0` arm with a path assertion (byte
identity alone cannot tell which path ran). `layer.rs` / `pcs::commit_planes`
at the reviewed tip do not precheck that switch.

**5090 Linux desktop acknowledged:** no laptop shutdown needed for that
separate installation. Start with GPU identity/free-memory and actual-device
oracles, frozen bytes on CPU/GPU/forced-chunked paths, then paired public,
legacy and repaired-profile cost diagnostics with peak memory. Label the
repaired public-endpoint diagnostic explicitly; the private block still needs
its own acceptance gate. Confirm host RAM before scheduling model-width work.


**Earlier resumed review, after `f002a72`:** the preceding turn made progress (GPU
integration committed, required-device/frozen-byte evidence retained). Both
existing Codex processes are live; no duplicate was launched. The broad
Python run is now in the legacy native backend battery, still under the
build lock. The isolated row-fold check remains queued behind it. Subsequent
byte-preserving speed patches will use focused arithmetic, repaired-profile
and frozen-proof checks; do not repeat the unrelated lattice battery unless
a change or failure justifies it.

**Private host port reviewed through `a25c544`:** the tail-zeroing distinction
is necessary and correct, and the returned A/P3-W data is retired after its
last opening reader. Please retain that distinction if sharing the public
pool later: making the public helper visible is not by itself an equivalent
replacement. Before handoff, include a dirty-buffer test for a shrink/grow
and changed tiled-prefix boundary, plus repaired P1/P3 private-IO verification
with pool/fold switches on and off. Fixed-shape legacy byte gates alone do not
exercise those appended rows or the repaired schedule. The public int8-plane
fold algebra checks out; I am leaving the live `zk.rs` lane with you.

**D14 draft review (`d399b32`):** see
`ZK60_L4_MEMO_INTEGRATION_REVIEW.md` before promoting the headline ceiling.
The streamed commit's source explicitly charges its hashing to `secs_ntt`,
so `hash = 0.481 s` does not measure all hashing. The group also contains
launch/download/wait costs; it is not a hardware lower bound on the complete
lever. Separately, the 192-opening PCS union is 98.6646 bits; ~94.1 includes
the projected LogUp term. The draft's ~94-bit projection may be reasonable,
but its attribution to the PCS union alone is wrong, and more PCS queries
alone do not fix the dominating LogUp contribution. Please fold these source
and arithmetic corrections into the memo/plan before using them as a verdict.

**Private-path priority:** the native capture bundles are ready and replayed.
Please keep the native joint-view adapter/review and the model-width norm
range obligation moving alongside the public-FFN speed lanes; report the next
concrete delivery in your handoff. D13 still requires private model blocks.
The accepted D9 bias term does not resolve D8/D11 or the omitted verifier
channels. Codex's current GPU evidence is compatibility/performance work,
not a substitute for that private-path gate.

**FSP-L9 correctness complete:** 261 CPU Rust tests (two ignored receipt
entry points); four switch configurations each pass the device oracles and
34 commitment tests with 189 actual device cases; 12 device cache tests and
all twelve frozen CPU/GPU/forced-chunked proof-byte gates pass. Native freeze
passes. The first idle preflight refused a recently busy GPU; its terminal
failure is preserved and the successful retry waited for consecutive idle
samples, reusing the exact pinned builds. The GPU lock is released; no Codex
GPU job remains. The full Python regression is running detached under the
build lock (PID 228629, `regression-v2.done`); GPU integration commit follows
the evidence cleanup. **Update: integration committed as `2850436`.** The
broader Python regression is still live (session 35723), now in its native
backend checks. It is not counted as passed. See
`ZK60_FSP_L9_INTEGRATION_20260919.md`.

**Acknowledged 11:53 rulings and 11:56 host delivery.** D13 puts embedding,
head and token generation after the first MVP; it does not close private
model-scale block coverage, whole-proof privacy or five-second proving.
Codex is retaining that distinction. D7's qualifiers remain attached to the
zkVM results. No driver/toolkit change is queued here; when the installation
window is named, coordinate stopping the existing jobs before changing it.
The `fsp-host` packed-plane work stays with your lane. I reviewed the
deferred-reduction fold at `ba6b4b8`; its arithmetic identity and accumulator
bound check out. Please include direct differential cases with signed-byte
extrema and field coefficients near p, in addition to the frozen trained
fixture. Your timer correctly prints the remainder as `rest`; the ledger's
description of that remainder as pure bus time should be narrowed because it
also contains event waits and driver submission. Overlap still matters when
turning a component cost into a predicted end-to-end saving.

**Codex next file lane:** I am taking the deferred-reduction row folds in
`zkp-core/src/mle.rs`, with direct differential arithmetic tests, in an
isolated `/tmp/wt-zk60-rowfold-20260919` worktree. This is the small shared
host-fold follow-up you identified; please keep that file read-only in the
speed lanes. The main-tree regression sources and GPU binaries stay fixed
during their current validation. No new model-width or GPU run is part of
this row-fold experiment until the current integration is committed.
The row-fold checks are queued as detached PID 235057 (session 82696),
under `results/zk60_rowfold_20260919/` in that worktree. Main retains a
recovery snapshot at the same relative results path, explicitly labelled
unvalidated/unintegrated. Inspect the existing handle and terminal marker
before any restart; do not duplicate the queued tests or benchmarks.

**FSP-L9 integration now active:** Codex is reviewing/integrating the frozen
`f0d3481` delivery in the main worktree, with small device oracles and frozen
125M byte gates queued under the heavy lock. No Mistral/8B run. Fable's
`fsp-host` keeps its branch/file lane; Codex will not duplicate its host work.
The delivered code has **not** pooled the output allocation, so the existing
two-scratch-take assertion is still correct and will not be weakened here.
Please include the changed allocation test with an eventual pooling change.

The resumed integration job is confirmed live through its existing session,
not inferred from a marker. Its CPU suite has now passed (261 tests, two
explicitly ignored saved-receipt entry points); required-device checks and
the twelve proof-byte gates remain in progress. Evidence and the independent
review are in `ZK60_FSP_L9_INTEGRATION_20260919.md`. The pinned pre-rebuild
native capture verifier is preserved at
`/tmp/zk60-native-capture-verifier-2b5c65c` with the original SHA-256, so the
GPU/CPU rebuilds do not invalidate the existing capture replay executable.

**Read `fsp-host` stage 2A (`7a2543c`):** the host-fold attribution is useful.
For the finer upload timer, distinguish `pack_narrow` CPU time, staging-buffer
event waits, driver submission and transfer/widen completion. `send_packed`'s
current elapsed region contains all of its event waits and CUDA calls as well
as packing; `commit_chunked_upload` charges the remaining total to `secs_ntt`.
Those counters are not a hardware host/device partition. Keep the proposed
20-second host share labelled as a model until the component measurements
reconcile it; overlap means the component totals are not necessarily additive
critical-path savings. Codex is not editing that lane.

One integration finding: the ledger says `HL_GPU_PAD_SKIP=0` restores the
old producer, but the new compact dispatch tests only `p1_compact()`. Codex
will make the compact choice also respect `pad_skip()` and exercise that
override during integration. Its default path and proof bytes are unchanged.
The archived shell oracle wrapper can mask failing exit codes through its
pipelines; the retained logs themselves are green, but Codex's rerun will
check actual process exit status, nonzero cases and complete SHA-256 digests.

**Hiding-port correction before the next CUDA edit:** the FSP-L9 ledger's
"exact next step" is not a drop-in kernel substitution. The current hiding
producer in `encode_rows_view_zk_gather` is **`k_ntt_p1`**, whose input is
natural-order, pad/coset-scaled coefficients at stride `pw = nn` or `n+q`.
The new non-hiding `k_dit_p1_pad_c` consumes bit-reversed inverse-NTT output
and assumes its particular zero-padding pattern. Substituting it directly
would discard that distinction (and mishandle the hiding pad coefficients).
The compact **store/consumer idea** transfers, but the hiding path needs a
compact-output variant of its actual `k_ntt_p1` producer, retaining its
bit-reversal, bounds and pad/coset semantics. Keep CL18's two pad widths and
CL7/CL15's duplicate/ragged/fallback/negative controls in that acceptance gate.

**Reply to the 11:00 follow-on proposal:** yes, take the narrow shape-general
entry pair and a **new example driver** after `fsp-zkhost`, as a separate
commit. No existing CLI/profile label, default or frozen digest changes.
Start with the tiny CPU anchor, then the scoped 125M three-arm GPU/CPU
comparison under the shared locks, with an idle/memory preflight and retained
peak-memory/source/binary evidence. Codex has no GPU job queued and will
integrate the handoff. No Mistral-width run until we agree the window. The
repair-only arm retains public endpoints and must be labelled as such;
it cannot be described as a P1 private-IO/model result. The native capture
implementation is committed at `2b5c65c`; final artifact validation passed.

**Native capture handoff is ready:**
`results/zk60_native_captures_20260919/validation.json` binds four accepted
capture/receipt/policy bundles, two per profile. The writer's 92 recorded
source-file hashes and all 12 artifact hashes recheck. All four captures
reproduce exactly in fresh native verifier processes; 49 native unit tests,
13 Python controls and both archived pre-instrumentation receipts pass.
The precise guide is `ZK60_NATIVE_CAPTURE.md`. Fable can start the joint-view
review on these actual slots/aliases; schema-3 capture availability is no
longer the blocker. Whole-proof privacy remains unaccepted.

**Capture implementation now active:** Codex is editing only the native
attention/block module declarations, their `protocol.rs` / `argument.rs`, a
shared test-only observer and its native-profile ingestion tests. `zk.rs`
remains available to Fable's staging lane. The observer records accepted
verifier inputs only, including definition draws and every masked slot;
no production capture switch or prover-state export is being added.

The native observer and ingestion gate now pass trial replay of two attention
and two complete-block receipts, with 49 native unit tests and 13 Python
controls. `ZK60_NATIVE_CAPTURE.md` describes the format and exact replay
gate. Final source-pinned artifacts are being retained next. Please review
the observer/slot-to-PCS/M aliases and then own the joint-view analysis;
the older FFN CLI parsers are shape-pinned, so a native adapter is required.
The generic CFS field/evaluation routines already run unchanged on all slots.
No D8/D11 closure or empty-history assumption is made.

Codex also read `ZK60_PRIVATE_FFN_COST_PROBE.md`. The public-endpoint repaired
mask timing probe is useful as an explicitly separate cost diagnostic. After
the staging port, please propose the narrow shape-general entry pair in
`zk.rs` from that memo, in its own reviewable commit with legacy byte gates.
Keep the tiny private-IO entry points pinned. Codex can take the bounded
runner/CPU ladder after integration; no model-width GPU run is authorized
by this handoff, and the current heavy/GPU window remains held.

**Reply to Fable's 10:33/10:39 asks:** the integration is committed as
`f1df3ba`. Yes, take the narrow `zk.rs` staging-pool/int8-fold port in an
isolated worktree; Codex is not editing `zk.rs` for the capture writer.
Keep the legacy frozen-byte gates and repaired private-IO verification
separate; no transcript, mask schedule, endpoint or privacy-policy changes
are part of that lane. Codex integrates the reviewed handoff. The `fsp-l9`
small-shape GPU lane has priority under the shared heavy lock; Codex has no
GPU job queued. Hold the three-arm 8B measurement until the kernel changes
are integrated and the current memory/idle preflight is reviewed; no timing
window is reserved yet. Codex is correcting the headline from the retained
58.40-second log. Capture writers remain Codex's next native-code work;
Fable retains GPU-preserving composition, D12 chaining and D8/D11.

Acknowledged Fable's 10:30 handoff and proposed split. Codex has integrated
the attention delivery from `ea81815` and the reviewed complete-block delivery
at `98a5db9`. Fable retains the two planning documents,
the GPU-preserving construction and D12 chaining design, and D8/D11 work.
Codex will not duplicate those drafts. No GPU job has been launched.

Attention integration includes exact U8 inverse reuse (47,104 lookups reuse
256 table inverses), explicit verifier-side tamper assertions, the R-2 comment
corrections and finer phase clocks. All 17 attention Rust tests, native freeze,
and 22 cross-version fresh-process verifications (66 corruption controls)
pass. Ten alternating warm CPU diagnostics per binary give 50.5 / 49.0 ms;
this noisy difference is not an established speedup. The full Python suite
passes (1,098 tests, 61 skipped); the two known portability issues are corrected.
Evidence is under
`results/zk60_attention_integration_20260919/`.

The old temporary jobs are absent after the restart; none has been counted
as live or blindly restarted. Existing hardening integration edits are
preserved. The bounded headless Fable review found no blocking attention
verifier defect and confirmed integrating the overnight block. Its stale
block-comment findings are corrected; its PCS draw-order pin remains a
follow-up. Both combined profiles pass 47 unit, eight integration and two
ownership doc tests; the block inventory passes 29 tests. A new 2,816,472-byte
block receipt proves in 0.062 s and verifies in 0.020 s on the shared CPU;
the archived lane receipt verifies too, with all corruption controls rejecting.
These are tiny diagnostics, not a privacy/model-scale speed claim. Attention
fixture scales now match `(0, 0)`. See `ZK60_ATTENTION_INTEGRATION_20260919.md`.
Codex next advances captures and the remaining integration work.

Victor explicitly asked the two live loops to collaborate toward the workable
private MVP and the five-second target. This is the current handoff, not a
claim that either target has been reached. Fable can acknowledge and report
its chosen branch/files in `ZK60_FABLE_LANE_HANDOFF.md`; Codex owns this file.

## Codex lane: complete functional receipt and integration

Codex owns `private-block-kernel/`, `private-model-kernel/`, `zkvm-block/`,
`zkvm-model/`, the maintained demo/tool runners, their tests, and integration
evidence. Opus 5's block/token runner and native-tool pin helper are integrated
and tested. A new Opus measurement task is listed below.

- Complete block: 785-byte Groth16 receipt verifies; all eight rejection
  controls pass. The maintained Python verifier also accepts the saved receipt.
  Thank you for independently verifying and preserving the public bundle.
- Full Python suite: **962 tests, 60 skipped, pass**. Original aggregate
  marker preserves the missing-default-fixture failure; the corrected native
  freeze passes using `M125_EXPORT_DIR=results/m125_ffn_export_wsl`.
- Token workspace: **24 Rust tests pass**, and Rust/Python framing vectors
  agree. Codex and Fable independently caught the launcher's `--examples`
  mistake. Corrected `token_build_v2.py` builds `--bins`; it does not repeat
  the passing tests. Detached PID 289296; `token-build-v2.done` is its marker.
  `token_prove_v2.py` (PID 289381) waits for that successful execution gate,
  then proves, wraps and checks rejection controls. Both use the shared lock.
  Records live in `/tmp/zk60-loop-20260917/`; do not launch duplicates.
- Independent source review found that inherited `RISC0_PPROF_OUT` can write
  secret-dependent profiles. All four root host/wrapper CLIs now refuse all
  `RISC0_*` and `BONSAI_*` runtime switches. The runner already scrubs those
  prefixes. The guest computation was unchanged. The token review is
  `ZK60_TOKEN_MODEL_SOURCE_REVIEW.md`.

## Fable request: implement the custom attention path

**Dispatch update:** the headless Claude Fable 5.1 implementation lane now
has worktree `/tmp/wt-zk60-attention-fable-20260918`, branch
`zk60-private-attention-fable-20260918` at checkpoint `db021ba`. It is the
sole writer for the attention Rust files below. The interactive Fable loop
is requested to review that delivery's construction and speed accounting,
and the root token receipt, so two writers do not duplicate the same patch.
Task/log/marker: `/tmp/zk60-loop-20260917/fable-attention-task.txt`,
`fable-attention.log`, `fable-attention.done`. No heavy proof is delegated;
Codex owns the shared heavy queue and integration.

The zkVM computation is a functional intermediate, so its CPU proof duration
cannot close the five-second gap. The next useful parallel delivery is the
**native custom private-attention prover/verifier**, using your A1–A4
construction and the actual repaired FFN conventions. Please take this in an
isolated worktree/branch, record ownership before editing, and hand back a
reviewable implementation with saved-proof verification and negative controls.

Proposed Fable file lane: new `hashline/src/private_attention*`, its examples
and tests; the minimum module export in `hashline/src/lib.rs`; and narrowly
identified shared attention helpers if required. Codex is not editing those
files. Record any wider ownership request in the handoff before changing it.
Keep existing profiles and frozen proof bytes unchanged. Read-only references:
the current repaired FFN, fixed kernel/oracle, and your attention schedule.

Acceptance for this engineering delivery: the full tiny attention relation
(norm, QKV, RoPE, causal scores, softmax, PV, projection, residual) is actually
verified, with explicit private endpoint bindings and the declared masked
channels; malformed and inconsistent witnesses/receipts are refused. Separate
the native implementation result from any whole-proof privacy acceptance.
D8/D11 and the forced-challenge counterexample in
`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md` remain open; do not reduce the
allowed prior history or declare it solved by the consuming API.

For the speed target, attach operation/byte counts and a phase breakdown on a
small correctness run if available. Public 8B FFN timing is not a complete
private-model timing. Shared-box timings are diagnostic; no five-second or
quiesced p95 claim follows from them. Larger timed runs share `/tmp/zk-heavy.lock`.

## Integration and rulings

Opus 5's current worktree is `/tmp/wt-zk60-private-profile-opus-20260918`,
branch `zk60-private-profile-opus-20260918` at `db021ba`. It owns only
`zk_ffn_fresh_io.rs`, a new `zk60_private_ffn_profile.rs` example, narrowly
related IO tests and its new diagnostic guide. It exposes existing phase
durations on explicit request without changing transcript/proof bytes or
default behavior. Fable's attention writer should keep those files read-only.
Task/log/marker are `opus-private-profile-task.txt`, `opus-private-profile.log`,
`opus-private-profile.done` in the loop scratch directory. Parent runs actual
proof measurements and separate-process verification after review.

The reviewed memory-bounded ceremony checker is queued as PID 318776,
`verify_ceremony.py`, behind successful `ceremony-prepare.done` (preparation
PID 297871 waits on the shared lock). `ceremony-check.done` and
`ceremony/check-1/result.json` are the checker's result markers. Six small
controls passed, including strict Node return values, memory-budget refusal,
import side effects and interruption markers. Neither queueing nor verified
downloads establishes ceremony verification. Token work retains priority.

Interactive Fable's hardening branch `zk60-zkvm-hardening` at `12341e6` is
received and under review. Codex owns its integration; a separate Codex
reviewer checks host/wrapper changes while Codex checks runner/cycle handling.
The live token proof's binaries and guest source stay fixed during that review.

Codex will review Fable's attention delivery while Fable reviews the new
token receipt profile and source pins. D3/D4 remain accepted as recorded.
D7 is still pending; the synthetic models are test fixtures, not approved
trained models. No pending ruling blocks independent implementation work.
Keep `MVP_STATUS.md` current and retain original failed run markers alongside
their corrections. Do not publish inner receipts, salts, plaintext outputs,
activation traces, witness files or private prover logs.
