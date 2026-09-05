# CL9 — the public weight cache: identity, lifecycle, and what it is actually worth

Task: `zk60_claude_tasks.json` CL9. Tests: `hashline/tests/zk60_gpu_cache.rs`
(6, CPU-only, in the ordinary suite). Measurements from CL5's matrix
(`results/cl5_matrix.log`) plus a targeted `HL_WCACHE_VERBOSE=1` pair.

**Scope limit, restated from the task:** this is about reuse of PUBLIC weight
commitments. It is not a solution to P3 approved-model consistency, and it is
not the singleton-mask privacy gate. Nothing here is a privacy claim.

---

## 1. Identity — what separates one entry from another

`WKey::digest` (wcache.rs:116) hashes a version tag, the profile, `l`, `d`,
`f`, `log_cols`, `inv_rate`, `rows`, `len`, and then **each weight plane's
length and content digest**. The entry filename carries that digest and
`load_tree` re-verifies it on load.

Tested (`every_keyed_field_separates_the_entry`): changing the profile, the
layer index, `d`, `f`, **one byte of one weight plane**, or the plane ORDER
all produce a different entry rather than a reuse. `a_different_pcs_shape_...`
adds `inv_rate`. So a stale or mismatched approval cannot collide onto a
usable commitment — the content itself is keyed.

`num_col_checks` is deliberately absent from the digest and that is correct:
it governs how many columns are OPENED at proof time, not the committed tree.

Damage is handled: `a_corrupted_entry_is_rejected_and_recommitted` flips a
byte in a stored tree and asserts the entry is **REJECTED and re-committed**,
reproducing the true root — not silently loaded.

Equivalence preserves bytes: `equivalent_approved_state_hits...` asserts a hit
reproduces the commitment root exactly, so warm and cold proofs are identical
artifacts.

---

## 2. FINDING: the cache saves the hashing, never the encoding

CL5's matrix showed cold, warm and *absent* indistinguishable
(prove 5.476 / 5.436 / 5.377 s, all inside a 2.5-4.3% spread). The obvious
reading — "it never hits" — is wrong. It hits. `HL_WCACHE_VERBOSE=1`:

```
MISS -> wrote v3-l00-....wc (4.2 MB, commit 0.087 s, write 0.002 s)
HIT     v3-l00-....wc (rows 288, 4.2 MB, load+verify 0.008 s, re-encode 0.088 s)
```

**A hit still re-encodes.** `commit_w` stores only the Merkle tree; on a hit it
calls `reencode_store` to rebuild the encoded store from the data. The saving
is the hashing alone — per layer ~0.031 s of commit against ~0.019 s of
re-encode, so **~0.012 s x 12 layers ≈ 0.14 s of a 5.4 s prove, ~2.6% at best
and inside the run-to-run spread.**

This is existing behaviour working as designed, not a regression, and no fix
is proposed: the tests found no correctness issue, and CL9 says to propose
narrow fixes *only* where tests find one. But it should be recorded plainly:
**a plan that assumes warm-cache proofs are materially cheaper is assuming
something the measurements do not support.** Making a hit skip the re-encode
would be a real change and belongs to whoever owns `wcache.rs` — not this
lane, and it would need a Codex handoff.

---

## 3. FINDING: `configure` is once per process, and that decides deployment

`DIR` is a `OnceLock<Option<PathBuf>>` (wcache.rs:54). `configure` **panics on
a second call** and there is no way to clear it.

The P3 prover asserts `wcache::dir().is_none()` (zk.rs:2453) — a belt-and-
braces stop behind the driver's flag refusal, because a cached weight
commitment opens 256 encoded columns per proof and the weights become
recoverable after ~65 proofs.

Put those together:

> **A process that has configured a weight cache can never serve a P3 proof.**
> It would trip that assert. A server must choose cached-P1 or P3 **at
> startup**; it cannot mix them in one process.

`configure_is_once_per_process_so_a_cached_process_cannot_later_serve_p3`
pins this: it asserts the second `configure` panics and that the directory is
still set afterwards. This is a real deployment constraint that was not
written down anywhere, and it is the answer to CL9's "thread/process
boundaries" item.

---

## 4. Lifecycle: invalidation, eviction, device state

| question | answer |
|---|---|
| invalidation | **By key only.** A changed profile/shape/weight byte writes a new entry; nothing invalidates an old one. |
| eviction | **None.** `there_is_no_eviction_entries_accumulate_by_key` shows entries accumulate one per distinct key, with no age or size bound. A long-lived cache directory grows without limit and is the operator's to manage. |
| corruption | Detected on load and re-committed (§1). |
| device state | The cache stores a HOST artifact (the Merkle tree). On a hit `reencode_store` will use the device when `gpu::enabled()`, and falls back to the CPU with a printed reason. No device buffer is cached or reused across proofs. |
| thread boundary | The directory is process-global; `Stats` is process-global. Concurrent provers in one process share both. |
| process boundary | Two processes may share a directory. Writes are per-entry files; a concurrent write of the same key is not coordinated here — the loser's `save_tree` error is caught and logged as "continuing uncached", so it degrades rather than corrupts. |

---

## 5. What P3 cannot get through this cache

- It cannot get a cached **weight** commitment: the flag combination is
  refused by the driver and the prover asserts on it independently.
- It cannot get cached **masks or randomness** of any kind: the cache stores a
  Merkle tree of the public W encoding and nothing else. There is no hiding
  state, no pads, no salts and no RNG in an entry — `save_tree`/`load_tree`
  carry the params, rows and tree only.
- The re-encode on a hit rebuilds from the caller's own data, so no witness
  material persists between proofs in the cache.

---

## 6. Handoff

- No change was made to `wcache.rs`; the tests found no correctness defect.
- Two behaviours are documented that were not written down: the re-encode on
  hit (§2) and the once-per-process configure with its P3 consequence (§3).
- If either is to change, both live outside this lane's files and need a
  Codex handoff. The one worth considering is caching the encoded store
  alongside the tree, which is what would make a hit actually cheap — at the
  cost of a much larger entry (the encoded matrix, not the tree).
