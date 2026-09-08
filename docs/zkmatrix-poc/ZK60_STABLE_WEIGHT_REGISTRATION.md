# Stable-weight local registration and reserved material access

`hashline::stable_weight_registration`, behind `stable-weight-storage`,
connects the [encrypted material](ZK60_STABLE_WEIGHT_MATERIAL.md) and
[durable slot journal](ZK60_STABLE_WEIGHT_SLOTS.md). It implements local storage
orchestration for FA4 H2. It does not authenticate model approval, generate the
reviewed mask layout, implement H3/H4's stable P3 proof path or close privacy review.

## One counter per commitment in the configured registry

The application supplies one existing, private registry directory from its
trusted configuration. `RegistrationStore::path_for(registry, policy)` derives
the child name `weights-<64 lowercase hexadecimal commitment-root digits>`.
The child name depends only on the commitment root. Changing a manifest, layer,
layout, row-role assignment, query count or budget cannot allocate a new counter
for the same root within this registry. A changed policy must fail reopening;
it must not trigger creation of a second registration.

Inside that child directory are three fixed files:

| File | Meaning |
|---|---|
| `journal` | The existing exclusively locked opening-slot journal |
| `material` | The existing immutable AEAD-protected data, pads and salts |
| `ready` | A 40-byte completion marker: ASCII `HLWREG01` and the 32-byte material-policy digest |

The marker is a durable publication signal and corruption/policy check, not a
signature or authentication token. Authentication and root reconstruction of
the encrypted material remain mandatory. No policy, key, geometry or mask roles
are learned from the marker. Expected policy and roles come from the caller's
independently trusted configuration.

## Creation and reopening

`RegistrationStore::create(registry, policy, material, limits, key_source)`:

1. Require a private local Unix registry directory, claim the new root-derived
   child with owner-only permissions, and sync its parent.
2. Create and sync the fresh journal while holding its exclusive OS lock.
3. Invoke the external key lookup callback, persist the encrypted material,
   reload it and verify its exact reconstructed root. Drop the returned key.
4. Exclusively create and sync the completion marker, then sync its directory.
5. Return the registration with validated owned material and the still-held
   journal lock. Owned material is dropped before that lock is released.

Creation intentionally performs the material store's write validation and a
second reconstruction on reload. This is registration work, outside the proof
clock. It gives the returned handle the same validation boundary as reopening.

Any failure leaves the claimed directory intact. Creation never overwrites,
removes, retries or adopts an existing directory, including empty or incomplete
ones. A missing key, invalid material, exhausted allocation limit or failed
publication can therefore require operator handling of an inactive registration.
There is no automatic delete/recreate recovery or fresh-budget fallback. The
application must not change the registry directory to bypass such a refusal.

`RegistrationStore::open(registry, policy, limits, key_source)` checks the
private directories, completion marker and required private regular files,
then locks and validates the existing journal. It refuses an exhausted journal
before key lookup. It then retrieves the key, authenticates/reconstructs material,
drops the key, and syncs the marker and parent directories before returning.

Missing state is never created. Symlinks, nonregular files and group/other
permissions refuse. A bad marker, missing file, policy mismatch, busy lock or
exhausted journal is refused before the key callback. Encrypted-content
validation additionally needs the key. A key/material failure releases the lock
without spending a new slot; subsequent reopening must validate the existing
counter. Complete state left by an uncertain final sync is validated and synced
on reopening. Torn or incomplete state refuses.

## Key custody boundary

`key_source` is a synchronous `FnOnce(&MaterialPolicy) ->
Result<MaterialKey, KeyUnavailable>`. It receives only independently trusted
configuration and runs under the journal lock. The application supplies the
registered uniformly random 256-bit key through this callback, using its chosen
key store and its own authentication, lookup and timeout policy.

The library generates or persists no key, has no environment-variable or
fixture-seed fallback, and does not select or contact a key service. The opaque
`KeyUnavailable` error keeps provider-specific diagnostics outside this API.
This is the provider interface; production key provisioning, distribution and
revocation remain application integration work. Secret-buffer erasure retains
the limits documented by the material component.

## One reserved operation through this handle

`store.reserve()` appends and syncs a spent journal slot before returning a
non-Clone `RegistrationAttempt`. That attempt borrows the store exclusively;
another attempt through the handle cannot coexist. Dropping it burns the slot.

`attempt.consume(operation)` moves the attempt into one synchronous callback
and passes the actual non-Clone `ReservedSlot` plus a borrow of the reconstructed
`CommittedZk`. The callback can inspect the token's index and policy digest.
It cannot return borrowed material or the token, clone the attempt or reuse it
after consumption. The registration handle has no raw-material accessor.
Operation failure, unwind or process death never refunds the slot. Journal
storage errors retain the existing poisoned-handle refusal until validated
reopening; `remaining()` is not permission to bypass that refusal.

The callback is trusted protocol code. Rust's `FnOnce` limits callback invocation,
not how many low-level openings arbitrary code inside it can perform. The future
versioned prover must enforce the reviewed per-slot mask schedule and consume
this token. Existing low-level PCS and material APIs remain available. This
component does not turn those legacy openings into an approved stable P3 API.

## Validation and trust limits

Tests cover actual ordinary PCS access only after the durable reservation;
lock ownership during key retrieval and the operation; drop/error/unwind and
exhaustion; missing/partial creation states; corruption of every marker byte;
policy substitution and attempts to allocate a second counter by changing
manifest/layer/layout/budget; missing or unsuitable files; key and authenticated
material failure; failed publication; and real process termination during
creation and during a material operation. Compile-fail tests enforce exclusive
borrowing, non-Clone attempts, nonescaping material/tokens and one consumption.
All keys, commitments and operations in these tests are public synthetic fixtures.

The application must configure one canonical registry for a commitment across
its users, layers and processes. Trusted local Unix filesystem locking and sync
semantics remain assumptions. Copying a registry, deleting/replacing files,
restoring a backup or deliberately using a different registry can reset state;
an external monotonic authority is needed for that threat. Path checks do not
provide an adversarial filesystem capability boundary against concurrent path
replacement. Linux/WSL is exercised; other Unix filesystems are not qualified.

H2's reviewed stable-weight generator and authenticated registration/application
integration remain open. FA6–FA8's masking, full-transcript and bounded-reuse
argument still gates H3/H4 and subsequent private-block composition. This host
module stays outside the maintained minimal `zkp-core` subproject.
