# Handoff: grouped full-validation tile reads

Cycle 0015, run `20260930T004944Z-77f0d93d`. Research only; main/Claude reviews
and integrates. **No native proving gain or 50-token/s result.**

## Interface and patch location

Candidate implementation is `read_tiles` in
`experiments/validated-tile-batch-20260930/experiment.py`.
Potential additive owner patch: a method beside `TensorRef.read_tile` in
`results/zk60_1b_checkpoint_20260927/importer_zk60_1b_checkpoint.py` (or the
importer's maintained copy), accepting ordered `(offset, length)` requests.
Preflight BF16 alignment, range, per-tile cap, request count and aggregate
payload; scan the **entire** tensor once against the existing pinned SHA-256;
return the buffered tuple after equality. No mutable-file verified flag or
per-chunk-only integrity shortcut is part of this method.

Future Rust consumer: calibrated public words enter `private_block::BlockPublic`
then `private_block::witness::build_shaped`, called at
`ops/zkp-mvp/driver-overlay/hashline/src/private_block/mvp_driver.rs::StackSource::advance`.
There is no calibrated consumer or Rust/CUDA patch in this handoff, and no
profile/calibration change is authorized. Current native softmax boundary
work stays with its owner.

## Validation and costs

The actual inspected local reader, imported read-only with bytecode disabled,
and an independent original-byte oracle match on seven tensor sizes and 88
ordered slices. Eight control categories (including ten malformed batches)
refuse as intended, notably corruption outside all selected tiles. Final
suite: seed 2026093015, 0.098 s, 37,096 KiB, one CPU thread. Commands,
SHA-256 pins, retained stdout and result are in the experiment directory.
Only synthetic files/config dimensions were used, never trained payloads.

K tile calls cost K whole scans; one group costs one scan. Eight 1-MiB
tiles can buffer 8 MiB, briefly about 18 MiB raw copy/scan storage plus
allocator overhead. Added costs: request intersection bookkeeping, batched
return allocation and delayed availability until the full digest gate.
No weaker refusal for outside-tile mutation, partial return, mask/salt reuse,
or repeated private commitment opening is proposed.

**Existing alternative matters:** `read_bytes` already scans once and returns
one entire tensor. Largest raw tensor is 22 MiB at TinyLlama / 112 MiB at
Llama-3-8B dimensions; where its temporary copy peak fits, use that existing
method before adding this API. Grouped scans only improve a repeated-tile
caller that must bound returned memory. Counted full tiling reduction is
86.35% / 87.50%; no timing gain or current whole-stack tiling caller is known.

## Promotion and unresolved risks

First identify a real calibrated caller and measure validation reads/hash
time, conversion, upload, peak RAM and enclosing readiness. If it reads each
tensor once, or the import is immaterial startup, demote the throughput claim.
Deleting the whole import phase caps the gain at its measured workload
fraction; changing startup does not change resident steady proving.
Do not transfer scan-byte ratios into elapsed-time ratios.

Review batch failure behavior, full-tensor integrity and future caller
lifetimes, including simultaneous mutation and trusted bounds. Like the
existing reader, this checks the captured scanned bytes against a pin; it
does not promise the pathname remains immutable after return. The tuple
must not be incrementally consumed before digest success. It retains all
returned bytes until the caller releases them; batch lifetimes can erase
the memory benefit. Trained quantization/orientation, integer-kernel parity,
approved statement identity, and larger-profile privacy/soundness remain
separate gates. P3 needs separate handling; no private artifacts are published.

Next useful research seam is `StackSource::prepass` / `restart` / `advance`:
the source discards every sealing-pass witness and builds it again for the
same run. Count a bounded private witness-replay schedule against storage
traffic/peak and refusal equivalence before proposing any cache. Preserve
one run transcript, fresh proof randomness and publish-only-after-verification.
