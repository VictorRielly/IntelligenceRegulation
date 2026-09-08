# Round 11 — verifier observations, Fable integration and primitive extraction

Validated source: `c8a342f`, completed 2026-09-08. The combined runner
finished with exit marker 0; exact evidence and remaining gates are below.

## Four-step continuation

1. **Implemented:** verifier-visible A/H/P3-W capture and replay, atomic
   publication after complete FFN acceptance, and an opt-in exact-integer JSON
   export for independent analysis. Five focused tests cover twelve proofs
   with seeded and fresh OS randomness; all six seeded hashes are unchanged.
2. **Integrated and validated:** Fable GPU/tool lane
   through `5949b38`, privacy-analysis lane through `46608bb`, and core design
   `882f037`. CPU review passes 377 GPU/tool tests, 22 original FA2 tests and
   34 updated FA2/FA3 tests. These counts overlap; they are separate runs.
3. **Candidate design received; private acceptance remains open:** FA3's
   `ffn-v3-mr1` schedule pairs single-row masks and proximity masks, reserves
   both real internal seams before commitments, and uses a separate profile.
   Its own B1/B2 blockers leave the CFS channel and transcript simulator
   unreviewed. Actual-coefficient joint analysis, arithmetic obligations and
   P3 stable-model consistency also need closure. No repaired FFN, private
   block or private two-block proof is claimed.
4. **First implementation delivered:** `zkp-core` now owns seven canonical
   CPU primitive modules. Hashline re-exports them; the primitive crate's 19
   tests and public sumcheck example pass. PCS, the full FFN path and bounded
   codec still need extraction. CL20 remains open.

## Observation result and boundary

Commit `8b697b0` adds H groups `[3,1,1,6,1]` and P3 W groups `[2,1]` to
the existing A groups `[7,3,1,1,6]`. Each role captures only public verifier
parameters, commitments, reconstructed claims, openings and transcript
endpoints. The complete verifier publishes all roles together; W/A/H failures
publish none. P1 W remains explicitly public/plain PCS.

The actual Wd-at-p6 singleton discloses 32 functionals of eight-row combinations
at T2/d16/f16. At T32/d16/f16 it recovers **all 256 Wd values**, including with
fresh OS randomness. Existing X/h16 disclosure regressions remain. Truth is
compared only after extraction in the synthetic fixture harness.

The initial twelve JSON captures also feed a restricted rank calculation using
Fable's exact modular arithmetic. Thirty role/proof cases yield per-column
dimensions A=2, H=0 and P3 W=2 for the subset consisting of group-vector message
coordinates and proximity. This confirms those predictions using actual
coefficients. It excludes individual terminal values, cross-column zero-sum
constraints, pads/columns, CFS messages and repeats, so it is neither a full
joint rank result nor a disclosure upper bound. In particular H=0 here does
not establish H privacy. See `results/zk60_round11_captured_rank.json` and
the retained analysis script.

The exported public arrays stay in `/tmp/zk60-round11/observations` and
`final-observations`; full file hashes, proof hashes and parameters identify
them in the reports. They can be regenerated with the command in
[the diagnostic document](ZK60_FFN_MASK_DIAGNOSTIC.md). Captures are in-process
verifier observations, not a standalone FFN byte decoder.

## Fable review and integration

- `6548c8d` integrates the GPU lane. CL14 now validates successful exits and
  finite contained clocks before comparing runs. CL15 handles empty and
  out-of-range column lists before device work. CL16 corrects the resident
  return's 71,168-byte overcount. CL13 records versioned case manifests.
- CL18's compact pad/scale output remains **off by default**. Its `n+q`
  stride is shared by the producer and NTT zero-extension load; full-width
  encoding remains available. Lane timings are diagnostic, not promotion or
  throughput qualification.
- Codex rehashed and reparsed all 42 retained cases of the lane's two completed
  manifests, checked the latest binary files against their recorded hashes,
  and confirmed the reviewed GPU source equals the latest validated source.
  The latest lane manifest at `5bb1546` covers 189 device cases and twelve
  frozen CPU/GPU/forced-chunk proofs. Archived proof files were removed by the
  runner: this review checks their recorded identities and retained logs,
  not deleted files. The new combined run regenerates the frozen artifacts.
  The CPU review snapshot overlays round-10 `zk_proof_size.rs` and its
  validation record so CL19's consumer tests execute. Both files match
  `31544ce` exactly; the overlay hashes are retained separately in
  `results/zk60_round11_review_overlays.json`.
- `1464430` integrates the privacy analyses and model-identity regressions.
  Fable's rank tool passes 34 tests after FA3. Findings remain classified by
  what was executed, modeled or left unresolved. The P3 identity tests pin a
  missing constraint; their passing does not enforce approved private weights.
- `b557a7c` integrates the core design. The dependency graph regenerates
  identically except for its Git baseline annotation in the archive snapshot.
  Original hashed logs retain their original whitespace; they were not edited
  to satisfy a formatting check. Changed implementation files pass diff-check.

## Core boundary

`c8a342f` moves field, NTT, Merkle, transcript, MLE, RNG and sumcheck code into
the new crate. The only dependency-path change inside those algorithms is
`sumcheck`'s RNG import. Application verifier fault-injection tests and
configuration tests stay in hashline; 19 primitive tests move with their code.
No registry dependency version changes. Existing callers use the same Rust
types through re-exports, so no conversion or second implementation is added.

[The migration ledger](../../zkp-core/MIGRATION.md) records hashes, boundaries,
ownership and the remaining PCS/FFN/codec work. The public sumcheck example
checks its terminal relation and an altered-round refusal; it is a primitive
example with no privacy claim. Original experiments remain available.

## Completed validation

The detached runner finished with exit marker **0** at source `c8a342f`.
[Exact stage and source evidence](../../results/zk60_round11_validation.json)
and [retained logs/index](../../results/zk60_round11_evidence/README.md) record:

- **178 Rust tests:** 159 in hashline and 19 in the independently built core;
  no failures or ignored tests. The five focused diagnostic tests also pass
  on the final source and are not counted twice.
- **546 Python/native tests**, with no failures or skips.
- **21/21 suite-v3 GPU/CPU gate cases**, including **189 executed device
  oracle cases**, both missing-feature controls and all **12 frozen full-hash
  proof comparisons** on CPU, GPU and forced hiding chunking.
- Separate-process cold/warm cache parity with the frozen ZK-v3 bytes,
  twelve cold misses/twelve warm hits, and P3-plus-cache refusal.
- B4 is byte-identical to its original 2,144,946-byte receipt; the existing
  B5 two-block public receipt passes separate-process verification.
- Twelve final capture exports pass shape/role checks. All six seeded proof
  and capture hashes match the initial run exactly; the six fresh captures
  differ. [Capture parity](../../results/zk60_round11_capture_parity.json).

The run uses two build/Rayon threads and the shared heavy lock. CPU stages
have an 8-GiB address-space cap; the GPU floors stage does not impose that
virtual-address cap because CUDA requires larger mappings. Maximum reported
stage RSS is **1,707,284 KiB**, with zero swaps. Source hashes across both crates,
their lockfiles and validation tooling remain unchanged through completion.
The standalone floors manifest still needs CL21 to include the extracted
path dependency itself; the outer round-11 record supplies that coverage.
These are correctness and compatibility results on the RTX 4070 laptop,
with no new privacy or throughput qualification.

## Continuation

The current [Fable queue](ZK60_FABLE_QUEUE.md) assigns exact-coefficient joint
analysis, CFS review, transcript simulation, arithmetic/identity closure,
manifest support for the extracted dependency, and the remaining CL20 steps.
Codex's next protocol work is the separately versioned repair and pending FFN
lifecycle after its required privacy obligations are reviewed. It must preserve
legacy compatibility as historical behavior while giving repaired proofs new
domains, layouts, counts, decoding rules and adversarial tests. One private
block precedes two connected private blocks. No full-model or 5090 run follows
from this round.
