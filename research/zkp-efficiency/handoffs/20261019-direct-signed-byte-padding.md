# Review handoff: direct signed-byte public padding

Run `20261019T191854Z-6444ea2f`,cycle0087. **UNBUILT/UNAPPLIED; no native speed result.**

Interface:replace the private loader's pad_matrix(&array.i8s(),...) with
pad_matrix_bytes(&array.bytes,...)->Vec<i8>. Frozen source:
hashline/src/private_block/trained_block.rs:349,1038,1131. Input is the SAME
Array.bytes already checked by load_array_checked and Array::expect for
dtype,shape and exact length; true dimensions/maps come from Shape. Every
generator,constructor support/CS,source/digest and H-1 check stays.

Patch:
`../experiments/direct-signed-byte-padding-20261019/review-only-direct-signed-byte-padding.patch`.
One file,58 diff lines,against frozen R8. Native source/evidence hashes in
source-pins.json,18 unchanged/14 checked against manifest_frozen.json.
candidate-trained_block.rs is a research snapshot only. The prior public
owned-constructor proposal touches adjacent loader context; owner must rebase
if combining them. Neither is integrated or merged here.

Implementation:keep zero-filled Vec<i8>,source-row inversion,inner maps and
Rayon destination-row scheduling. Read original u8 bytes and cast at each
destination; no complete signed decode vector or unsafe reinterpretation.
The identity branch uses a cast loop instead of copy_from_slice. At8B the
query map is identity; native vectorization/copy efficiency is an open risk.

Validation:432 matrices/48 public layouts,3 exhaustive byte sweeps,5602 main
assertions,1728 synthetic prevalidation and942 wrong-output controls;
independent audit2725 assertions/864 corruption controls. Main/audit
0.297901/0.086999s,25924/19196KiB,one nice19 CPU. Synthetic prevalidation does
not execute native refusal semantics; artifact SHA256 does not prove native
receipt identity. Real generators,CS/native IO races,Rust compilation and
native proof gates remain owed. No real private prompts/weights/activations.

Counted scope:9 decode allocations/218112000B per8B load eliminated;56MiB
largest temporary. Full sealing payload ledger has0B peak reduction in all8
cases:later record hash scratch dominates. With4pins/current/next and16
hash workers the envelope remains2.016689GiB borrowed or1.789997GiB with
the prior move proposal [MODEL]. Not actual RSS/VRAM/fit or saved time.
All-load deletion's loose CPU diagnostic ceiling is1.103104x; this subset
must be smaller. No GPU ceiling or throughput claim.

Owner validation before promotion:build under shared lock; differential native
padding/record digests and first-refusal controls at actual shapes; exact
byte/seeded receipt+independent verifier gates; unchanged H-1,source freshness,
CS and refusal-before-header checks; compare exclusive decode+padding clocks
and actual allocations/RSS. Do not infer pass-level gain from byte counts.
No mask/opening reuse,privacy change,arithmetic change or target change.

Next local:public raw-array last-use before LayerRecord::of_block. Preserve
all checks and metadata; test the complete lifetime rather than subtracting
one temporary from the global peak. Whole-prover GPU/resident measurements
remain the leading owner work.
