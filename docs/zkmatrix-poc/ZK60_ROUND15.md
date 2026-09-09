# Round 15 — reviewed safeguards, validation provenance and typed core

Source: `612ff9cef4ab857510223716eb040b2df8434828`, 2026-09-08. Validation is recorded separately below.

## Changes and review dispositions

Fable's FA6/FA7/FA8 reports and CL21 tooling are integrated from published
`7624bcb` and `e18994c`. The completed local FA9 delivery `6673209` adds six
adversarial arithmetic tests and independently confirms R32's typed-message
refusal. Original reports and unsuccessful proposal runs retain their own scope.

`a5aea1d` implements FA6 I1/I3 (FA8 S2): all thirteen FFN CFS coefficients
abort on zero immediately after their single draw, before masked claims are
absorbed. No resampling occurs. Masked extension rounds check the mask degree
and vector lengths before zipping or changing output/transcript state. Three
regressions test refusals, unchanged state and normal transcript/algebra parity.
This safeguard does not implement the proposed privacy repair.

`1eb5852` implements the public-tensor R31 constructor and an explicit fixed
norm limb restriction. The constructor recomputes both commitment roots from
public int8 tensors (including gamma), binds them into the approved contract,
and rejects invalid shapes. The public synthetic fixture uses it. The root-only
compatibility constructor still requires the trusted registrar to establish
weight ranges independently; it does not authenticate a root's contents.

R10's actual proved remainder width is `16 * n_limbs`, not `wrho`. The fixed
contract explicitly requires two limbs. R09's fixed-profile exclusion and the
wider-profile false acceptance are both retained as tests. The proposed direct
D range fact changes the attention statement and proof bytes: it must become a
separate version with corresponding receipt/schedule rules. It is not applied
as a replacement for the frozen legacy attention path. R09 wider profiles and
private registrar authentication remain open.

The suggested R31 change to B4 `check_profile` is not applied: that function
has only an already approved root and public metadata, not the public weights.
Inventing or regenerating a fixture's weights there would authorize a different
model. The constructor is used where actual public tensors are available.

CL21 initially bound revalidation to committed tree IDs and lock hashes, but
discarded the current dirty deltas and presence. A synthetic green manifest in
a real temporary Git checkout was accepted by both `validate --repo` and
`finalize --repo` after a tracked core source edit. Neither HEAD tree nor lock
hash changed. The retained before/after CLI reproduction shows both original
commands return 0 and both fixed commands return 1.

`22c9b35` binds live HEAD, both crate layouts/deltas, untracked non-ignored
files and lock hashes at initialization, finalization, validation and preflight.
A new automatic `build.rs` is refused even though it is not in `git diff HEAD`.
Suite v5 preserves v4's 19-test meaning and adds the then-current 22 core tests
and separate 210-test protected-storage coverage. Suite v6 records the typed
core integration's 32 core and 215 storage-enabled hashline tests. Both are
24-case suites; v6 is the default. Archived v1–v5 definitions remain unchanged.
Stored test counts and v5/v6 core/storage command requirements are recomputed.
`612ff9c` isolates the storage-feature Cargo target under
`hashline/target/storage-tests`, preserving the already recorded default CPU
binary. A tiny standalone Cargo reproduction confirms that a feature-enabled
integration test overwrites the ordinary binary in a shared target; an isolated
target preserves its full hash. The runner regression fails before the fix and
passes afterwards. The first combined attempt was intentionally interrupted
before proof cases while its default CPU tests were running; its partial logs
and exit marker 143 remain separate from the final result.
These are source-provenance checks in a cooperating checkout, not protection
against a malicious machine changing and restoring inputs between probes.

Fable's correction `50f1ea5` addresses C20-R1–R3: expected query counts and
shifts have explicit supported domains, size arithmetic is checked, vector
allocation is preceded by input-length checks, and log_cols=0 follows actual
PCS grouping (1/1/2). The previously held table/typed FFN extraction is accepted
with that correction. `zkp-core` now owns tables, FFN parameters/statements,
layout, proof serialization and bounded decoding alongside its primitives/PCS.
Hashline re-exports those types and retains the full prover/verifier bodies,
GPU/compact/cache integration and host storage. A complete independent FFN
prover/verifier and reviewed ZKP path remain open; CL20 is not complete.

## Conditional privacy review and remaining gates

FA6's exact CFS calculation, FA7's joint captured-observation results and
FA8's transcript simulator are accepted as construction-specific analyses with
their documented assumptions. They do not describe an implemented repaired
proof. Current legacy disclosure tests continue to reproduce the known defect.

FA8 S1 remains a gate for the repaired API: it must accept no caller-supplied
seed and use fresh OS entropy; frozen deterministic legacy fixtures retain
their old behavior. S3 requires actual repaired-profile and function-2 captures,
including terminal and seam observations, checked by the independent model.

Round 13/14 encrypted material and local consuming registration implement part
of E1/E2 and one canonical directory per root within a trusted registry. They
do not enforce the future prover's per-slot mask schedule or prevent malicious
rollback/copying across registries. Authenticated approval/key custody and an
external anti-rollback authority remain required for stable P3. E4's changed
code-rate bound and attention A1–A4 also remain explicit gates.

## Validation

The [machine-readable report](../../results/zk60_round15_validation.json) and
[retained evidence](../../results/zk60_round15_evidence/README.md) identify each
source pin, command, log, failure/interruption and successful final result.
Final detached exit marker: **0**.

- **247 Rust tests:** 215 hashline tests including nine compile-fail doc checks
  with protected storage enabled, plus 32 standalone core tests; no failures
  or ignored tests. The default hashline suite separately passes 188 tests
  (overlapping), and all 32 core tests also pass in debug.
- **564 proof-tooling tests** pass on the final source with zero skips. The
  earlier complete Python/native run executed 659 tests at `22c9b35`: 658
  passed and one stale help-text expectation failed. That test was corrected;
  every affected hashline/zk60 tool is rerun in the final 564-test set, including
  the new storage-isolation regression. The unchanged native/freezing results
  retain their earlier source attribution; no final-source full-suite run is
  claimed. The native crate tree is unchanged, and every changed Python module
  is covered by the rerun (review/python_coverage_provenance.json).
- **24/24 suite-v6 floor cases pass**, including 189 actual RTX 4070 Laptop
  device oracle cases, the missing-feature controls, core tests/example,
  isolated protected-storage tests, cache cold/warm parity and P3 cache refusal.
- **All 12 frozen proofs match full hashes and lengths**, after their ordinary
  verifier accepts: v2 66,844,928; v3 70,758,084; ZK 87,228,528; ZK-v3 87,697,008
  bytes, on CPU, GPU and GPU forced-chunk routes. These legacy FFN tests are
  not a decoded full-relation or repaired-privacy approval.
- **B4** reproduces the original 2,144,946-byte public receipt exactly; **B5**
  separately verifies the existing public two-block receipt.
- Original C20-R1/R2/R3 probes pass in both debug and release: query MAX refuses
  without panic, shift 64 refuses without panic, and the valid one-column
  legacy proof both verifies and decodes with matching 1/1/2 groups.
- Default hashline/core dependency trees exclude optional encryption and CUDA;
  combined GPU/storage compilation passes. The static two-crate dependency
  graph regenerates identically twice.

All 191 tracked implementation/tool/manifest/lockfile hashes
remain unchanged through final validation. Maximum reported stage RSS is
1,670,012 KiB; 0 swaps are reported. Commands use two build/Rayon/prover
threads and the shared heavy-job lock. Separately launched CPU stages have an
8-GiB address-space cap; the mixed CPU/GPU floor runner has no virtual-address
cap because CUDA needs large reservations. This is bounded correctness work,
not a performance qualification.

The failed broad run and the intentionally interrupted artifact-isolation run
remain identifiable by their own source pins and markers (1 and 143). Neither
is promoted to a successful full validation.


## Continuation and ownership

1. Codex specifies and implements the versioned repaired FFN path, starting
   with a checked mask-layout generator and an OS-randomness-only API. Bind
   each opening to the exact reviewed slot schedule. Produce digest-bound
   schema-2 captures for ordinary and function-2/predicate cases.
2. Fable reviews those new captures and the implemented schedule against FA6–8;
   in parallel, inventory the attention CFS/terminal/seam channels (A1–A4)
   and review Codex's fixed-profile R10/R31 hardening. Do not redo delivered
   legacy capture analysis, PCS extraction or CL21 provenance work.
3. Codex implements versioned attention D-range enforcement, authenticated
   registration and key provisioning, and the reserved-slot prover/verifier.
   Stable P3 needs an external rollback-resistant authority before approval.
   One private block and a linked two-block proof follow the arithmetic and
   privacy gates; the current receipts remain public-only.
4. Fable continues lower-priority CL20 with a complete selected P0 FFN
   prover/verifier in the maintained core and actual old/new cross-verification.
   Promote the repaired ZKP profile only after its invariants are reviewed.
   Preserve existing experiments and the frozen CPU/GPU proof gates.

No full-model benchmark, 5090 qualification, complete private LLM proof or
throughput claim follows from this round.
