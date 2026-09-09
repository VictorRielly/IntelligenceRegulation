# Round 13 — protected stable-weight registration material

Implemented and validated source: `ccc6f26ea8018324fb9cec526e6e75556dc0728a`,
2026-09-08. The detached validator finished with exit marker 0 in
`/tmp/zk60-round13`. This continues the Codex-owned H2 work while Fable works
on FA6–FA9, CL21 and the remaining CL20 extraction.

## Delivered component

The opt-in `stable-weight-storage` host feature encrypts the registration
matrix, hiding pads and leaf salts using RustCrypto XChaCha20Poly1305. It
binds the file to the trusted slot policy and expected ordered mask/proximity
row roles. Keys are supplied externally; fresh nonces come from the OS.
The [storage contract](ZK60_STABLE_WEIGHT_MATERIAL.md) defines the API, exact
format, allocation limits, key boundary, filesystem and memory assumptions.

Creation reconstructs the commitment from the supplied secrets before writing
an exclusive, owner-only file and syncing the file and parent directory.
Loading checks the expected size, authenticates the header/payload, parses
canonical field words and reconstructs the commitment against the independently
trusted root. Missing, truncated, corrupted, mismatched and oversized material
refuses. Expected row roles come from trusted configuration, not the file.

Reconstruction calls the existing PCS row encoder, column hashing, salting and
canonical NTT/Merkle implementations. No PCS arithmetic, transcript, RNG or
proof format is changed. Owned secret buffers have drop guards; the contract
explicitly excludes existing PCS temporaries and whole-process memory erasure.

The immutable secret file and [durable journal](ZK60_STABLE_WEIGHT_SLOTS.md)
are separate components. Reloading material never creates or resets a journal.
The separate-process test reopens matching material after a spent slot, spends
the next slot, and confirms exhaustion survives subsequent material reloads.
AEAD does not protect the public journal from rollback or establish approval.

## Validation

[Exact validation record](../../results/zk60_round13_validation.json) and
[retained runner, logs and hashes](../../results/zk60_round13_evidence/README.md):

- **202 Rust tests:** 179 hashline unit/integration tests, four compile-fail
  ownership/formatting checks and 19 standalone core tests; zero failures or
  ignored tests. Hashline's tests enable the new storage feature. The process
  helper test entries are included in these counts.
- Nine storage test entries cover exact reconstruction and ordinary PCS
  opening-byte parity, fresh nonces, private file permissions, no overwrite,
  wrong keys, corruption at every byte offset, truncation/trailing data,
  changed policies/roles and clear-header substitution, authenticated malformed
  material/root mismatch, allocation limits/overflow and process/journal reuse.
  These use public synthetic material and keys, not an approved private model.
- All **four frozen CPU proof artifacts** retain their complete SHA-256 hashes
  and byte lengths: v2 66,844,928; v3 70,758,084; ZK 87,228,528; ZK-v3
  87,697,008 bytes. Each newly generated proof verifies before comparison.
- B4 reproduces the original **2,144,946-byte** receipt exactly. B5's existing
  two-block public receipt passes separate-process verification.
- Default hashline and standalone core dependency trees exclude the new
  encryption packages. The lockfile adds ten optional dependency packages
  without changing existing registry-package versions/checksums. The scoped
  [RustSec inventory](../../results/zk60_round13_evidence/dependency_advisory_check.json)
  finds one historical advisory, patched in the locked version. This is not
  a full cryptographic or dependency audit.

The run serializes behind the shared heavy lock, uses two build/Rayon/prover
threads and an 8-GiB process address-space cap. Maximum reported stage RSS is
**1,668,084 KiB**, with zero swaps. All 80 recorded source/manifest/lockfile
hashes remain unchanged through completion. The proof binaries use default
features. The unchanged Python/native suite retains its round-11 result of
546 passing tests; no Python/native or GPU run is attributed to this round.

## Continuation and ownership

Fable's published tips remain review `46608bb`, GPU/tools `5949b38` and core
design `882f037` at this round's fetch. An active core validation was observed
in Fable's sibling checkout; that is not a published delivery or integration
acceptance. Fable retains its existing queue and independent review ownership.

1. Review and integrate Fable's next FA9 arithmetic/registrar proposals and
   CL21/core pushes. R32 already has a production fix; R09/R10/R31 and the
   independent closure remain open.
2. Finish H2 registration orchestration, the reviewed stable-weight layout
   generator and the external key-custody integration. The protected store
   accepts trusted roles but does not establish that a schedule is approved.
3. After FA6–FA8's masking/full-transcript/bounded-reuse review, implement the
   separately versioned repaired prover and its consuming slot API, then the
   matching registered verifier policy. Preserve the frozen legacy path.
4. Validate one private block, then two connected private blocks. Keep host
   persistence outside `zkp-core` as Fable continues the minimal subproject.

This round completes the protected-material storage/reconstruction component.
It does not complete H2, enable approved stable P3 weights, repair the known
privacy defect, implement private blocks, or finish CL20.
