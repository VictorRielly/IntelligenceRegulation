# Read-only review: keyed GPU commitment candidate (2026-09-27)

Reviewed `/tmp/zk60-sol-gpu-20260927` against
`/tmp/zk60-groups-20260926`. The seven inspected candidate files are pinned
in [gpu-review-source-pins.json](gpu-review-source-pins.json). I did not edit,
build, or run the device lane. **No concrete keyed-hash or ownership defect
was found by static inspection.** The GPU lane's separate
[attempt-2 device report](../zk60_sol_gpu_20260927/attempt-2/device_report.json)
records five passing RTX 4070 Laptop cases: resident keyed, forced chunked,
forced compact chunked, CPU receipt and GPU receipt. I independently rehashed
its 184 source pins, two binaries and five logs with no mismatch. That is
actual-device correctness evidence for those cases, not a throughput result.
The separate [CPU core regression](gpu-cpu-regression/report.json) on the
same frozen source passed 74 unit and two integration tests in both debug and
release with source pins unchanged.

The CPU oracle uses `blake3::Hasher::new_keyed(tag.column_key())` over each
column's `Fp::to_bytes()` in row order. The candidate loads each 32-byte key
as eight little-endian `u32`s, starts chunk and parent chaining values from
those words, adds `KEYED_HASH=16` to every chunk and parent compression, and
keeps `ROOT` on the final chunk or parent compression. Its column words use
the low 32 bits of each encoded `u64` first; returned digest words are written
with `to_le_bytes()`. Those choices match the CPU byte order and BLAKE3 keyed
mode. The keyed streaming kernel mirrors the existing lazy CV-stack schedule,
using the same key/flag at both pre-chunk merges and final root roll-up.

Tagged dispatch calls only the new `try_commit_zk_keyed` backend method;
its default is `None`. CUDA errors return `None` and the core CPU oracle then
hashes with the same key. The unkeyed hook is never used for tagged columns.
Pads and salts are drawn before the backend offer in the old order. A decline
does not redraw them; the core regression test checks pads, salts, root and
RNG continuation. The GPU integration test additionally requires a device
store for a full tagged commitment, preventing a CPU fallback from passing
that positive device gate. `HL_GPU_REQUIRED=1` is enforced by this test, not
by general production dispatch: an ordinary CUDA failure logs and falls back
to CPU, which is correctness preserving but cannot be counted as device work.

The revised pad kernel now applies both `-pad[i]` and `+pad[i-n]` when
`n <= i < q`, matching the CPU loop when `q>n`; its direct device test includes
`q=257` with `n=256`. The retained device commitment keeps data and the
encoded buffer for openings. On chunked paths it keeps pads and coset powers
for re-encoding; the uploaded key buffer lives through every hash launch and
the synchronous leaf download. Neither opening path needs the key after the
leaf hashes have been returned. The ordinary unkeyed entry points still pass
`None` and select the prior kernels.

The attempt-2 device tests cover keyed leaf parity in resident and forced
chunked modes, including the 128/129-row BLAKE3 boundary, `q>n`, wrong-key
rejection, opened-column parity, and a full tagged commitment root/pad/salt/RNG
comparison asserting `Store::Device`. Its CPU/GPU receipt cases passed. The
legacy device suite, frozen proof-byte controls and full candidate library
gate are being run separately; this review does not mark them passed. The
direct device-resident `dev_commit_zk_from` API still
has only an unkeyed public entry; tagged core commitments use the keyed
host-upload entry. No D19b/D22 privacy conclusion follows from leaf parity or
from this static review, and no complete private 8B throughput result follows.

The GPU-feature native test binary lists 509 tests versus 529 in the prior
`stable-weight-storage` non-GPU binary. The
[exact inventory diff](gpu-cpu-regression/test-inventory.json) is explained
by 20 storage-feature tests and three CPU-only hardening tests absent under
`gpu-cuda`, plus three CUDA plane-oracle tests present only there. This is a
feature-matrix difference; it is not evidence of tests dropped by this patch.
