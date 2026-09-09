# Stable-weight opening slots — FA4 H2, public-state component

Codex implementation, 2026-09-08. The user assigned Fable the independent
review tasks and asked Codex to continue its implementation work. FA4 §7
explicitly permits deterministic H2 plumbing alongside the H1 privacy review.

`hashline::stable_weight_slots` implements a durable public slot journal.
It does not generate stable commitments, persist secret weights/pads/salts,
authenticate manifests, or enable a new P3 proof path. **H2 is partially
implemented; H1 and H3–H7 remain open.** The repeated-opening privacy argument,
repaired mask schedule and approved-model verifier still require review and
implementation. This journal is an application component outside `zkp-core`.

## Public policy and API

`StableWeightBinding` identifies one manifest, layer, mask-layout digest,
commitment (root/rows/log_cols), PCS parameters, hiding options and opening
budget. Construct `SlotPolicy` from independently authenticated application
state, never from a candidate proof. Its constructor checks geometry and
canonicality; it does not authenticate the input or approve the construction.

The policy requires:

- Nonzero manifest/layout/root identifiers and positive commitment rows.
- `1 <= log_cols <= 31`, matching commitment width, a power-of-two inverse
  rate of at least two, and encoded domain at most `2^32`.
- Positive Q and `1 <= budget <= 65,536`; checked `q_pad = budget * Q` and
  `n + q_pad <= n * inv_rate`. Equality is allowed as a storage geometry;
  it supplies no positive distance or acceptable soundness bound.
- A canonical nonzero base-field coset outside the encoded subgroup.

The immutable policy exposes its binding and digest. Storage accepts a
caller-chosen path in a trusted local Unix directory:

```rust,ignore
// `policy` comes from trusted configuration; `path` is the ONE canonical
// journal for this commitment. Creation is an explicit registration action.
let mut journal = SlotJournal::create(path, policy)?;
let slot = journal.reserve()?; // append + sync complete before this returns
let index = slot.index();
let policy_digest = slot.policy_digest();
// A future prover consumes this non-Clone token. Dropping it burns the slot.
drop(slot);
drop(journal);

// Normal restart MUST open existing state; a missing file is an error.
let mut journal = SlotJournal::open(path, trusted_policy)?;
```

`ReservedSlot` exclusively borrows the journal and is neither Clone nor Copy.
Compile-fail checks exercise overlapping reservations and token duplication.
The future proof API must consume this token and enforce the bound layout;
copying a numeric index does not by itself enforce any cryptographic rule.
No existing prover or verifier consumes slots yet.

## Persistence and failure semantics

Creation uses an exclusive new file, Unix mode 0600, an exclusive OS lock,
file sync and parent-directory sync. Existing files are never overwritten,
even if empty or corrupt. Reopening locks the file, checks the supplied policy
and all records, then syncs the file and directory before returning a handle.
The OS releases the lock on handle close or process death. A second cooperating
handle/process gets `Busy`; there is no internal blocking wait.

Every reservation appends its next sequential slot and syncs it before
returning the token. Dropping the token, panicking or terminating the prover
does not refund it. After a storage error, the handle becomes poisoned and
cannot reserve again. Reopening a complete record burns it even if its caller
died before receiving a token. A partial or corrupt tail refuses the whole
journal; the library never silently truncates or repairs it.

The fixed header is `HLSLOT01`, three 32-byte identities (manifest, layout,
root), eight little-endian u64 words (layer, rows, log_cols, inverse rate, Q,
budget, q_pad, coset), then its BLAKE3 digest: 200 bytes total. Each record is
a little-endian u32 slot and a 32-byte digest over the record domain, policy
digest, previous digest and slot. The header digest is the first predecessor.
Parsing streams 36-byte records and bounds their count by the trusted budget;
it does not allocate in proportion to an untrusted file length. Excess,
reordered, repeated, partial and checksum-corrupt records refuse.

Checksums detect corruption; they do not authenticate the disk or detect
rollback to an earlier valid prefix. The caller must retain one canonical
journal per commitment and protect it from replacement, deletion, copied
journals and restored backups. An adversarial storage/rollback threat needs
an external monotonic authority. File locks are advisory; local filesystem
lock and sync guarantees are assumptions, not properties certified by this
module. Linux/WSL is tested; other Unix filesystems are not qualified by this
run. The implementation uses Rust's standard file-lock API (stable since
1.89); no dependency or registry version changes are needed.

## Validation and continuation

The tests cover policy mismatches and invalid geometries, noncanonical cosets,
drop/unwind/restart/exhaustion, create/open refusal, competing handles,
truncated/corrupt/reordered/over-budget records, injected failed sync/torn
tails, poisoned handles, real process termination, and eight unique slots
reserved by competing processes. They use public synthetic policy identifiers;
no fixture here represents an approved private model.

Round 14 additionally reproduces a child startup inheriting a journal's open
file description between fork and exec. Closing the owner's descriptor alone
can retain that lock briefly. The private lock guard explicitly unlocks before
close, including create/open error paths; its deterministic regression also
checks that dropping the inherited descriptor cannot release a later owner's
separately acquired lock. Production code never exposes or clones the descriptor.
Drop cannot report an unlock I/O failure, so reopening must still acquire and
validate the journal; it may never bypass a `Busy` refusal.

[Round 12](ZK60_ROUND12.md) records this journal's source pin, full-suite counts,
receipt and frozen-proof checks. [Round 13](ZK60_ROUND13.md) implements the
opt-in [protected material store](ZK60_STABLE_WEIGHT_MATERIAL.md) and exact CPU
commitment reconstruction, bound to this same policy. [Round 14's registration
handle](ZK60_STABLE_WEIGHT_REGISTRATION.md) coordinates both components and
reserves a durable slot before giving trusted protocol code material access.
The reviewed layout generator and authenticated application/key provisioning
remain open. H3/H4 must integrate a consuming token API with the reviewed
versioned mask layout and registered verifier policy. Fable retains FA6–FA9,
CL21 and the remaining CL20 extraction; Codex owns this journal and attention
verifier changes. The journal closes neither the CFS privacy argument nor
approved P3 model consistency.
