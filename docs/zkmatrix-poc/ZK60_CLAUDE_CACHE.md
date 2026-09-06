# CL9 — the public weight cache: identity, lifecycle, and what it is actually worth

Task: `zk60_claude_tasks.json` CL9. Tests: `hashline/tests/zk60_gpu_cache.rs`
(12 after round 7 — was 6; CPU-only, in the ordinary suite; the two
process tests skip LOUDLY without the 125M v3 export). Measurements from
CL5's matrix (`results/cl5_matrix.log`) plus a targeted
`HL_WCACHE_VERBOSE=1` pair, and (round 7) this file's own cold/warm/P3
process runs. **Codex's round-7 review is answered in §7**, and the
corrections it forced are marked `[round 7]` in place below.

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
adds `inv_rate`. `[round 7]` `the_shape_and_length_fields_separate_the_entry_too`
adds `log_cols`, `rows`, the packed length and a plane's LENGTH, and every
case now asserts a **clean** miss (no hit, one miss, **nothing rejected**):
if a field were missing from the digest the filename would coincide and
`load_tree`'s own shape check would REJECT — that would be the load check
catching it, not the key. So a stale or mismatched approval cannot collide
onto a usable commitment — the content itself is keyed.

`[round 7]` **A content-derived key does not authenticate approval.** `WKey`
has no approval input: any planes the prover holds get a key and an entry
(`the_callers_packing_ties_the_key_to_the_committed_data` commits arbitrary
planes and they cache like any other). What the key guarantees is that an
entry is never reused for DIFFERENT content; whether the content was
approved is decided elsewhere (the model-identity / receipt lanes), not
here.

`num_col_checks` is deliberately absent from the digest and that is correct:
it governs how many columns are OPENED at proof time, not the committed tree.

Damage is handled: `a_corrupted_entry_is_rejected_and_recommitted` flips a
byte in a stored tree and asserts the entry is **REJECTED and re-committed**,
reproducing the true root — not silently loaded.

Equivalence preserves bytes: `equivalent_approved_state_hits...` asserts a hit
reproduces the commitment root exactly. `[round 7]` That was a ROOT, not a
proof; `cold_and_warm_processes_produce_the_same_verified_proof_bytes` now
runs two prover PROCESSES against one cache directory and compares the
proof FILES byte for byte (§7.2), so "warm and cold proofs are identical
artifacts" is measured, not argued.

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

`[round 7]` Codex was right that the above is an INFERRED refusal. The
executed one is now `p3_with_wcache_is_refused_by_the_driver_before_any_work`
(the real binary, `--p3 --wcache`: exit 2, `REFUSED: --wcache with --p3.`,
no directory created, no export read) and its counterpart
`a_fresh_uncached_p3_process_accepts_and_never_touches_a_cache` (§7.4).

---

## 4. Lifecycle: invalidation, eviction, device state

| question | answer |
|---|---|
| invalidation | **By key only.** A changed profile/shape/weight byte writes a new entry; nothing invalidates an old one. |
| eviction | **None.** `there_is_no_eviction_entries_accumulate_by_key` shows entries accumulate one per distinct key, with no age or size bound. A long-lived cache directory grows without limit and is the operator's to manage. |
| corruption | Detected on load and re-committed (§1). |
| device state | The cache stores a HOST artifact (the Merkle tree). On a hit `reencode_store` will use the device when `gpu::enabled()`, and falls back to the CPU with a printed reason. No device buffer is cached or reused across proofs. |
| thread boundary | The directory is process-global; `Stats` is process-global. Concurrent provers in one process share both. `[round 7]` And they share the entry's TEMPORARY FILE NAME: same-key writers in one process race on `<entry>.wc.tmp` exactly as two processes would — measured in §7.5. |
| process boundary | Two processes may share a directory. Writes are per-entry files; a concurrent write of the same key is not coordinated here — the loser's `save_tree` error is caught and logged as "continuing uncached", so it degrades rather than corrupts. `[round 7]` That sentence was written from the source, not from evidence. Now measured (§7.5): 8 same-key writers x 12 keys gave 15 lost saves out of 96 (`rename: No such file or directory`), 0 rejections, and every surviving entry complete and verifying. "Degrades rather than corrupts" stands, with the precise mechanism and its one caveat (a transient partial file at the entry path) written down there. |

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
  `[round 7]` Still true for CORRECTNESS. Two proposals for its owner are
  now on the table (§7.5, §7.7): a per-writer temporary name in
  `save_tree`, and the driver printing `wcache::report()` in the ZK pass.
- Two behaviours are documented that were not written down: the re-encode on
  hit (§2) and the once-per-process configure with its P3 consequence (§3).
- If either is to change, both live outside this lane's files and need a
  Codex handoff. The one worth considering is caching the encoded store
  alongside the tree, which is what would make a hit actually cheap — at the
  cost of a much larger entry (the encoded matrix, not the tree).

---

## 7. Round-7 review response (Codex, 2026-09-06, `ZK60_CL5_CL9_REVIEW.md`)

Codex reproduced the six tests at `39272d6`: they pass together with one
thread, and `every_keyed_field_separates_the_entry` **fails alone** (the
first `profile` case expects one hit and gets zero). Reproduced here first,
before any edit, with the reviewer's own command:

```
zk60_gpu_cache --exact every_keyed_field_separates_the_entry --test-threads=1
  assertion `left == right` failed: only the repeated BASE key may hit when changing the profile
  left: 0   right: 1
```

Codex then listed what the first round had inferred rather than executed.
Each finding below: what it was, what changed, the test, the command and
its result. All work is in the two files this lane owns; `wcache.rs` is
untouched, and §7.5/§7.7 propose what its owner might change.

### 7.1 The order-dependent test

**Finding.** The test took its hit baseline and then committed `base` and
`other`, expecting exactly one hit — which assumed `base` was already
cached. In the serial suite it was: `a_different_pcs_shape_cannot_reuse_the_entry`
used the SAME key (planes 1/2/3, layer 0) and ran first. Alone, the first
`base` commit was a miss.

**Change.** The test owns its key namespace now (planes 21/22/23, layer 200 —
every test in the file has one; the list is on `shared_dir()`), PRIMES the
base entry explicitly (asserting that prime is itself a clean miss, i.e.
nothing else touched the key), and asserts the two commits SEPARATELY: the
base re-commit must HIT and reproduce the primed root, the mutated key must
be a CLEAN miss `(hits, misses, rejected) == (0, 1, 0)`. The six mutations
(profile, layer, `d`, `f`, one plane byte, plane order) are unchanged. The
pcs-shape test moved to layer 210 and got the same prime + clean-miss shape.
The correction is recorded in the test's doc comment, not erased.

**Result.** §7.6: the reviewer's exact command now passes, as does every
other test alone, the file with 8 threads and the file with 1 thread.

### 7.2 Warm/cold PROOF bytes, in separate configured processes

**Finding.** The tests compared commitment roots, never proof bytes.

**Change.** `cold_and_warm_processes_produce_the_same_verified_proof_bytes`
spawns the prover binary (`env!("CARGO_BIN_EXE_hashline")`) twice with one
fresh `--wcache` directory: `pass 12 512 --threads 4 --zk --seed 1 --profile
v3 --export <v3 export> --proof-out <file> --wcache <dir>`, `HL_GPU` unset,
`HL_WCACHE_VERBOSE=1`. Asserted: both exit 0 and print `PASS-V3 ACCEPT [ZK]`;
the cold log has exactly 12 `wcache MISS -> wrote` lines and no `HIT`, the
warm log exactly 12 `wcache HIT` lines, no `MISS`, no `REJECTED`; the cold
run leaves 12 `.wc` entries; both `PROOF sha256` lines equal the frozen
`40eb5479…aac17 (87697008 B)`; and — the review's point — the two
`--proof-out` FILES are read back, compared byte for byte, and hashed in
the test to the frozen digest. Ground truth (this box, CPU, 4 threads,
2026-09-06): cold `wall 25.37 s`, warm `wall 24.52 s`, both
`40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17`, and the
twelve entries are 4,194,372 B each (`v3-l00-f5b16c12849ffa3b.wc` …
`v3-l11-a6899d170e5ee604.wc`).

**Skip is loud, not silent.** Without the export (`layer00_WgT.bin` missing
under `HL_EXPORT_DIR`, default `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export`)
the test writes a `[ZK60-CL9] SKIPPED … This test was NOT executed.` banner
straight to the process's stderr — libtest captures only the `print!`
macros, so the banner reaches the terminal even though the test then
passes — and returns. Rust's harness has no runtime skip; failing instead
would break the suite on every box without the fixture, which includes
Codex's read-only reproductions.

**Observation for the driver's owner (not this lane's file):** `pass_zk_v3`
never prints `wcache::report()` — only `pass` and `pass_v3` do
(`hashline.rs:764`, `:1039`) — so the ZK pass has no `hits N | misses M`
summary line. The per-layer verbose lines are the evidence here.

### 7.3 A real packing / caller test

**Finding.** The synthetic commitment data was independent of the key's
planes, so the one assumption the cache rests on — that the data paired
with a key is a function of the planes the key digests — was never
exercised.

**Change.** The test file carries `pack_w_v3`, the prover's packing copied
from `layer::prove_layer_v3` ("W data + commit"; `zk::prove_layer_zk_v3`'s
P1 branch is the same loop): per (d-block, f-block) one `db x fb` block each
of Wg^T and Wu^T (row `k`, col `j` within the block) and one of Wd^T (row
`j`, col `n`), at `LayoutV3`'s offsets — and `w_offset_of`, its inverse.
Two tests use them:

- `the_callers_packing_ties_the_key_to_the_committed_data` (synthetic, three
  shapes: 32x16, 16x64, and 8192x16 so that `nb_d = 2` and the second
  d-block's offsets are exercised): packed data + `WKey` commit → clean
  miss, again → HIT with the same root; then ONE byte of each plane in turn
  (in the plane's last third, i.e. the second d-block where there is one)
  changes exactly ONE committed element, at the offset the layout predicts,
  with the new value; the key changes (clean miss) and the root changes.
- **The real-layer cross-check**, inside the process test after the warm
  run: the cold process's layer-0 entry is copied into the test process's
  cache directory; layer 0's three planes are read from the export
  (1,572,864 B each), packed with `pack_w_v3` under `LayoutV3::new(512, 768,
  2048)`, keyed `WKey::new("v3", 0, 768, 2048, ..)` with the driver's PCS
  parameters (`log_cols 14.min(log_wb 19)`, `inv_rate 4`, 256 checks → 288
  rows, as the prover's HIT line says), and committed. It **HITs** —
  `load_tree` compares the file's 32-byte key digest with the one computed
  in the test, so the key the test builds IS the prover's — and the loaded
  root equals `pcs::commit` of the test's packing, so the data the prover
  paired with that key IS this packing of those planes. If either prover
  loop drifts from the copy, this fails.

**Stated (§1 and the test's doc comment):** a content-derived key does not
authenticate approval; it guarantees no reuse across different content.

### 7.4 P3: the executed refusal, and a fresh uncached process that accepts

**Finding.** The P3 test observed `configure(None)` panicking and called
that a refusal.

**Change, with the ACTUAL behaviour established by running the binary.**
`hashline pass 12 512 --threads 4 --p3 --seed 1 --profile v3 --export …
--wcache <dir>` gives **exit 2**, stderr beginning

```
REFUSED: --wcache with --p3.
  Under P3 the WEIGHTS are private, and a cached hash-based weight commitment is
  not merely suboptimal — it is unsound as a privacy claim: …
```

nothing on stdout, and the `--wcache` directory is NOT created: the refusal
sits in `parse_opts` before `wcache::configure` and before the export is
opened. `p3_with_wcache_is_refused_by_the_driver_before_any_work` asserts
exactly that, with a nonexistent export AND a nonexistent cache directory
(so it also proves neither is touched, and needs no fixture).
`a_fresh_uncached_p3_process_accepts_and_never_touches_a_cache` runs `--p3
--seed 1 --proof-out` without `--wcache`: exit 0, `MODE P3`, `PASS-V3 ACCEPT
[ZK]`, no `wcache` substring anywhere in the log (no MISS/HIT lines and
`report()` is `None` unconfigured), proof **88,189,680 B** — the size CL5's
matrix recorded for 12x512 P3 (three GPU reps) — and sha256
`be8d13cc5c2d1b2d515854c30dbc8330c5e4165c0cdc4cb641472ae5744d3bea`,
established on the CPU path under `--seed 1` on 2026-09-06 (the ground-truth
run and the test run agree). The digest is asserted so that P3 under
`--seed 1` stays deterministic; CL5's log printed no P3 digest, so CPU/GPU
parity for P3 is not claimed here.

### 7.5 The remaining key fields, and same-key concurrent writers

**Fields.** `the_shape_and_length_fields_separate_the_entry_too` primes a
base (layer 220) and then: `log_cols` 7 for 8 with the SAME 1024 elements
(rows move alone: 8 for 4, len unchanged); 8 rows for 4 under the same
`log_cols` (rows and len move together — they cannot move independently,
`rows = len / 2^log_cols`); a plane of 65 B (the same 64 plus a trailing
zero) and of 63 B. Each is a CLEAN miss — no hit, one miss, nothing
rejected. The "nothing rejected" is what distinguishes the key from the
load check (§1).

**Writers.** `same_key_concurrent_writers_leave_one_verifying_entry`: 8
threads from a `Barrier`, one key per round, 12 rounds, 1 MB entries
(`log_cols 12`, `inv_rate 4`). Mechanism, from `save_tree`
(`wcache.rs:164-166`): `tmp = path.with_extension("wc.tmp")` — the SAME name
for every writer of a key — then `fs::write(tmp)` (open with `O_TRUNC`,
write all) and `rename(tmp, path)`. Consequences and evidence:

- **Lost saves.** The second writer's `rename` finds the shared tmp already
  renamed away and fails with `No such file or directory (os error 2)`,
  logged `wcache: cannot write <entry> (…); continuing uncached`. Its
  commitment is still used in memory; only the save is lost. `Stats` has no
  counter for it, so the test recovers it as `misses - saves` with
  `saves = bytes_written growth / entry size`. **Observed: 15 lost of 96
  writes** (0 hits, 96 misses, 81 saves), across 11 of the 12 keys.
- **Transient partial entry.** A second writer's `O_TRUNC` open empties the
  first writer's inode, which may already have been renamed into place; a
  reader in that window fails `load_tree` ("truncated"), is REJECTED and
  re-commits. **Observed: 0 rejections** in this run (the barrier makes every
  thread a writer, not a reader), so the window is argued from the source,
  not measured.
- **No wrong entry is possible.** Every writer of a key writes the SAME bytes
  (same data → same tree); after the last truncation the last opener writes
  them completely; `load_tree` re-hashes every level. Asserted per round:
  every thread computed the same root, `hits + misses == 8`, exactly ONE
  `.wc` for the key and no `.wc.tmp` left behind, the survivor has the full
  entry size (1,048,644 B), and a final commit HITs to the writers' root.
  **12/12 rounds.** Writers of DIFFERENT keys never share a tmp name (it
  carries the key digest), so cross-key corruption is not on the table.

The §4 rows for thread and process boundary are corrected in place: the
"degrades rather than corrupts" claim stands, but it was written from the
source; it is now measured, and the shared-name mechanism applies to
threads in one process just as to two processes.

**Proposed `wcache.rs` change, for its owner (not applied — not this
lane's file).** In `save_tree`, use a per-writer temporary name, e.g.
`path.with_extension(format!("wc.tmp.{}.{}", std::process::id(), <thread id
or an atomic counter>))`, write it fully, then `rename` over `path`. Rename
is atomic, so: every writer's rename succeeds (identical bytes, so
last-writer-wins is harmless and the 15/96 lost saves go to 0); the entry
at `path` is never partial (the transient window disappears); and a writer
that dies mid-write leaves a uniquely named `.tmp` that a startup sweep can
remove. Two lines. The test above would then expect `lost == 0`.

### 7.6 The verification matrix

All on this box, 2026-09-06, CPU build (no `gpu-cuda` feature, `HL_GPU`
unset), release profile, under the build lock:

```
flock /tmp/zk-build.lock cargo test --release --manifest-path hashline/Cargo.toml --test zk60_gpu_cache
```

| run | command (test binary = `target/release/deps/zk60_gpu_cache-*`) | result |
|---|---|---|
| the full file, default threads | `cargo test … --test zk60_gpu_cache -- --nocapture` | **12 passed, 0 failed**, 54.06 s |
| the reviewer's command | `-- --exact every_keyed_field_separates_the_entry --test-threads=1` | **1 passed** (was: FAILED, 0 hits for 1), 0.12 s |
| each of the other 11 alone | `-- --exact <name> --test-threads=1`, one process per test | **11 x 1 passed**; the process tests 50.66 s and 26.24 s, the rest ≤ 0.78 s |
| concurrent | `-- --test-threads=8` | **12 passed, 0 failed**, 58.29 s |
| serial | `-- --test-threads=1` | **12 passed, 0 failed**, 78.29 s |

Same-key writers in the `--nocapture` run: `12 rounds x 8 threads: hits 0 |
misses 96 | rejected 0 | saves 81 | lost renames (continuing uncached) 15`,
with the 15 `wcache: cannot write … (No such file or directory (os error
2)); continuing uncached` lines in the log. The two ground-truth prover
runs behind §7.2/§7.4 are in this session's scratchpad log (`truth.log`):
cold `EXIT=0`, 12 MISS; warm `EXIT=0`, 12 HIT; P3 uncached `EXIT=0`; the
refusal `EXIT=2` with the directory left uncreated.

### 7.7 What remains open

- **Suite time.** The two process tests add about 55 s to `cargo test
  --release --test zk60_gpu_cache` (two P1 processes and one P3 process, CPU,
  4 threads each, concurrent under the default thread count). The lead asked
  for real proof comparisons in the ordinary suite; this is their price.
- **The fixture.** The v3 export lives in a sibling worktree's untracked
  `results/` (`HL_EXPORT_DIR` overrides the path). On a box without it the
  two process tests skip loudly and the other ten still run.
- **P3 GPU parity** is not asserted (no P3 digest in CL5's matrix to compare
  against); the P3 digest here is CPU, `--seed 1`.
- **The shared `.wc.tmp` name** is characterised and its fix proposed
  (§7.5), not applied. The transient-partial window is argued, not measured.
- **`wcache::report()` in the ZK pass** — a one-line driver addition for
  `hashline.rs`'s owner (§7.2).
- **Unchanged findings from round 1**, now with Codex's agreement: a hit
  re-encodes (§2), configure is once per process (§3), nothing evicts (§4).
  None of these is a task-acceptance claim on its own.
