# Round 14 — local registration and PCS core integration

Source: `df7fb0d6860b41e3af421b9f99d3b672e9736d32`, 2026-09-08.
The local registration component is `7a9273b`; Fable's PCS/scanner extraction
is integrated in `b044e20`, with host storage compatibility fixed in `83115b5`
and explicit journal lock cleanup in `df7fb0d`.
Fable retains its existing independent review, tooling and remaining core work.

## Delivered registration boundary

The optional `stable-weight-storage` feature now coordinates the encrypted
material store and durable opening journal through `RegistrationStore`.
The [contract](ZK60_STABLE_WEIGHT_REGISTRATION.md) records the API, publication
sequence, key-provider interface and local filesystem assumptions.

Within one configured private registry, the commitment root determines one
registration directory. A changed manifest, layer, layout or budget cannot
allocate another counter for that root. Creation claims the directory, locks
and syncs the journal, obtains the external key, persists and reconstructs the
authenticated material, then publishes a synced completion marker. Incomplete
creation is retained and refused; reopening never creates fresh state.

A reservation is appended and synced before the handle exposes material to
trusted protocol code. The attempt is non-Clone, borrows the store exclusively,
and is consumed once while passing the actual reserved token and borrowed PCS
material. Borrowed material and tokens cannot escape the callback. Drop, error,
unwind and process death burn the slot. The future prover must still enforce
the reviewed per-slot opening schedule inside that callback.

Eleven registration tests cover ordinary PCS access after durable reservation,
key/material failures, incomplete publication, marker corruption, policy changes,
permissions, locks, exhaustion and process termination during creation/use. Five
compile-fail checks guard ownership and consumption. All keys and witnesses are
public synthetic fixtures; no production model or key service was registered.

## Reviewed core integration

Fable's committed local `76ee275` moves the canonical CPU PCS into `zkp-core`;
`ee775be` extends the static source scanner across both crates. Hashline keeps
the GPU adapter, environment selection and timing output. The core's tests grow
from 19 to 22 because three existing PCS tests move with their implementation.
Host encryption, filesystem storage and key custody remain outside the core.

The [review](ZK60_CL20_ROUND14_REVIEW.md) records unchanged function hashes and
the backend/RNG/serialization inspection. It also holds the subsequent local
`f8d40a7` typed-decoder commit for three reproduced findings: unbounded query
allocation, unchecked shifts in shape construction, and incorrect group counts
for an honest one-column legacy proof. These are configuration robustness and
compatibility findings; no fixed-profile soundness exploit is claimed.

The held commit is not integrated. A retained patch against the integrated PCS
pin reconstructs its exact two-crate snapshot, with all 94 tracked file hashes
checked. Fable can reproduce the findings without losing its local work.

## Validation

The [machine-readable record](../../results/zk60_round14_validation.json) and
[retained evidence](../../results/zk60_round14_evidence/README.md) identify the
source, commands, raw logs, exit markers, binaries and full proof hashes.

Final detached validator exit marker: **0**.

- **219 Rust tests:** 188 hashline unit/integration tests, nine compile-fail
  ownership checks and 22 standalone core tests; zero failed or ignored. This
  includes the added journal descriptor-inheritance regression and synthetic
  process-helper entries. Hashline enables `stable-weight-storage` here.
- **343 Python tooling/consumer tests**, zero failures or skips, at the final
  source pin. The separate full Python/native suite retains round 11's 546
  passing tests; it is not counted as a new full run.
- **All 21 suite-v3 floor cases pass**, including 189 device oracle cases,
  default-feature Rust coverage (170 tests, overlapping the count above),
  no-feature controls, cold/warm cache checks and P3 cache refusal.
- **All 12 frozen CPU/GPU/chunk proofs retain exact hashes and lengths**:
  v2 66,844,928; v3 70,758,084; ZK 87,228,528; ZK-v3 87,697,008 bytes.
  Each generated proof verifies before byte comparison. These legacy FFN gates
  are not independently decoded full-relation verification or privacy approval.
- **B4** reproduces the original 2,144,946-byte public receipt exactly; **B5**
  passes separate-process verification of the existing two-block public receipt.
- Default hashline/core dependency trees exclude optional encryption and CUDA
  packages. Combined `gpu-cuda,stable-weight-storage` compilation passes.
  The static two-crate graph regenerates byte-identically on two runs.

All **84 tracked source/manifest/lockfile/tool hashes** remain unchanged
through completion. Maximum reported stage RSS is **1,675,812 KiB**, with
**0 reported swaps**. Hardware execution is the bounded RTX 4070 Laptop
fixture/oracle suite, not a 5090 run or a throughput qualification.

The first registration-only run at `7a9273b` independently passed 218 Rust
tests, four frozen CPU proofs and both public receipt checks. After merging
PCS, two attempts stopped at the same compile error in protected-material Drop:
the new generic store requires an explicit impossible external-store arm even
when borrowed in a CPU build. The second attempt had corrected unused report
parser keys but still encountered that source error. `83115b5` fixes the match
and its test. Both failed logs are retained; neither executed a GPU stage.

The next combined run at `83115b5` passed all 218 storage/core Rust tests,
189 device oracle cases and all 12 frozen proof comparisons, but the separate
default-feature suite exposed an intermittent `Busy` refusal immediately after
dropping a journal. Its overall floor verdict is red and is retained as such.
A child starting on another test thread can inherit the open file description
between fork and exec, briefly keeping a lock after the parent closes its copy.

A controlled native fork/exec reproduction confirms that close alone retains
the lock during that interval, while explicit unlock releases it. A deterministic
unit regression models the inherited descriptor with a duplicate: it fails on
the original implementation and passes after `df7fb0d`. The private lock guard
now unlocks before closing on normal drop and initialization errors. It exposes
no cloned descriptors through the production API. All eight journal unit tests
pass after the fix. This corrects availability and does not change the journal
format, reservation order, spent counts or proof bytes.

The round uses two build/Rayon/prover threads and the shared heavy-job lock.
CPU stages have an 8-GiB process address-space cap. The bounded GPU floor stage
has no virtual address-space cap because CUDA needs large reservations. The
standalone legacy suite-v3 runner still covers only hashline in its source
delta; this round additionally checks both crates and their lockfiles before
and after execution. That outer check does not complete Fable's CL21 upgrade.

## Continuation

1. **Fable:** continue FA6–FA9's independent review and CL21's permanent
   both-crate validation provenance. For lower-priority CL20, correct C20-R1–R3,
   then deliver the selected P0 FFN prover/verifier extraction and old/new parity.
2. **Codex:** review and integrate those bounded deliveries. Continue H2 with
   the reviewed mask-layout generator, authenticated approval/application
   binding and production key provisioning. Local storage orchestration and
   its external provider callback are now implemented.
3. After the masking/full-transcript/bounded-reuse review and arithmetic
   closure, implement the separately versioned prover consuming the reserved
   token and the matching registered verifier policy. Preserve frozen legacy
   behavior and explicit limitation tests.
4. Validate one private block, then two connected private blocks. Promote the
   reviewed path into the maintained core without removing experiments.

The registration component does not authenticate model approval, protect against
malicious registry rollback/copies, prove the mask schedule private, enable
stable P3 proofs or finish H2. PCS extraction does not finish CL20. These remain
explicit gates in the [Fable queue](ZK60_FABLE_QUEUE.md).
