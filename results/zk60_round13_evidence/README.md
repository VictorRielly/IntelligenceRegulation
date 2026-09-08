# Round-13 retained validation evidence

Source `ccc6f26ea8018324fb9cec526e6e75556dc0728a`; exit marker 0.
`index.json` binds retained files by full SHA-256 and byte length.
`summary.json` is the unmodified detached-run record. The sibling
`../zk60_round13_validation.json` adds retained-path and resource summaries.

The runner queues on the shared heavy lock, uses two build/Rayon/prover
threads and an 8-GiB process address-space cap. Hashline tests enable
`stable-weight-storage`; core tests are standalone. Dependency checks and
proof binaries use default features. All four frozen proof hashes/lengths,
B4 reproduction and B5 separate-process verification pass. Large proof files
remain in `/tmp/zk60-round13`; their hashes and executed commands are retained.
No GPU or Python/native test run is attributed to this round.

The dependency note inventories the ten newly added packages against a pinned
RustSec advisory-database tree. The one listed advisory is patched in the
locked version. This is a scoped dependency check, not a full dependency or
cryptographic audit. Source URLs and the advisory hash remain in the note.
