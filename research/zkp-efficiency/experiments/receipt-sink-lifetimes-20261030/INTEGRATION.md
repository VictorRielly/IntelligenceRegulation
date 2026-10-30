# Receipt emission: conditional review handoff

This research code is a Python wire-shape projection. It is not a native Rust
patch, a cryptographic verifier, or evidence of reduced native peak memory.
Main/Claude owns any port and integration; nothing is merged.

The eight source pins are from the active `ops/zkp-mvp/trained-1b` tree.
`protocol.rs::prove_core` already drops witness/lookup transients, then M, A
and H commitment owners before returning. `run.rs::prove_run_with` releases
the input/output endpoint owners after opening, serializes `Segment`, drops
the structured segment, calls the sink, and only then moves `cur` into `prev`.
The public cache can retain its own Arc, and the pending boundary must survive.
There is no authorization to drop either early or to reuse their openings.

The actual remaining seam is `wire.rs::encode_segment` -> the owned `Vec<u8>`
sink closure -> `run_sink.rs::DirSink::accept`. The encoder allocates the
whole counted segment while the typed segment is alive. DirSink writes that
vector, syncs its file, renames it and computes its digest. This happens once
per segment; a full run's receipt is already streamed. No whole-run byte
buffer is available to remove. Current `prove_s` includes encoding and sink.

A possible additive API, for owner review only:

```rust
// Names/signatures are a design, not compiled implementation.
fn preflight_segment(s: &Segment, layout: &Layout, geom: SegGeom)
    -> Result<usize, String>;
fn encode_segment_to<W: std::io::Write>(
    s: &Segment, layout: &Layout, geom: SegGeom,
    binding: &Digest, start: &[u8; 32], end: &[u8; 32], writer: &mut W,
) -> Result<usize, String>;
```

Keep the current contiguous encoder and memory-sink route. A directory-only
route could preflight the entire immutable typed segment and the counted
ceiling, validate sink index/range/existing destination, then emit through a
bounded buffer with incremental SHA-256. Flush the buffer, check exact emitted
length, sync the file, rename, then record length/digest. The corresponding
SumcheckProof, MaskOpening and OpeningZk writers need additive `Write` routes;
their present APIs require `&mut Vec<u8>`. Use stable `write_all` handling for
short writes and EINTR. Current Rust docs mark `write_all_vectored` nightly;
do not silently require a newer toolchain or nightly API. This prototype does
not implement vectored I/O.

All fixed-width raw u64/extension encodings, field order, roots, column order,
paths, salts, tags and fresh proof contents must remain identical. Native
`encode_segment` does not run its decoder: do not transplant the standalone
block encoder's decode-and-drop allocation into this cost model. In the
projection, noncanonical field representations are preserved by both encoders
and refused by the independent strict reader; no invalid field is accepted as
a proof. Wire shape and transport equality do not establish proof validity.

The modeled old/new sink states agree for create/write/zero-progress/sync/
rename failures, out-of-order/out-of-range indices and existing destinations;
EINTR retries succeed. `.partial` files may remain after failure, matching
the source model. No new run statement or publication authority is supplied.
D12b/D21 full-run verification, refusal confidentiality and cleanup remain
with the existing caller. Crash/power-loss behavior, directory syncing,
symlink/race attacks, permission/space errors, native error strings/order and
private transcript/PCS/privacy gates are not tested. The actual tiny file
smoke performs file fsync and rename only; it proves no crash durability.

Let S be the typed segment's actual allocated capacity, B its counted wire
length and K a fixed buffer budget. The selected serialization payload changes
from S+B to S+K. This is an isolated logical buffer formula, not a whole-run
peak theorem. The typed S survives through I/O in the candidate, whereas the
incumbent drops it before I/O. Account for this extended lifetime, allocator
capacity, hash/buffer copies, dirty file pages and other run/cache owners.
The prototype's buffer `high` bounds its logical bytearray length, not Python
allocation capacity, OS pages, allocator RSS or native Rust peak. No private
witness/weights/state spill or removed file sync is proposed.

Eliminated work: one B-byte contiguous staging allocation and potentially its
exposed memory-pressure cost; fresh proof field/mask work and written bytes
are unchanged. Added costs: writer dispatch, buffering, error handling,
incremental-hash placement and longer typed ownership during I/O. Some scalar
copying remains; do not claim zero-copy or a B-byte DRAM saving. Tiny budgets
increase write calls drastically, as `wire-counts.json` shows.

For N independently verified complete positions, let C be exclusive removed
critical-path cost and A added cost: rate N/(T-C+A), even free deletion bounded
by N/(T-C). Necessary >=50/s: T-C+A <= N/50. C and A are unmeasured. Falsify
promotion on any native byte/refusal/RNG/transcript mismatch, peak regression,
negligible serialization cost or A>=C. If proving has already established the
peak and serialization has no pressure/stall, this has no useful peak saving.

First owner action: collect instrumentation-off/on exclusive encode/write/
file-sync/rename/hash and owner-capacity clocks from an admitted whole proof.
Only if material, port the additive writer and run native frozen-byte,
failure, independent verifier, RNG/PCS/privacy gates and actual peak checks
under current shared build/heavy locks. Then compare complete independently
verified high-end GPU resident 1/2/4/8 workloads. No such job was launched.
