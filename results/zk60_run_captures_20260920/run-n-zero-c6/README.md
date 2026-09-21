# ZK60 run capture bundle

Bundle `run-n-zero-c6`: one honest 2-block run at the FULL-TOP-BYTE
development shape (`Shape::rung_c6`: 32 tokens, width 384, hidden 512, 12
query heads of 32 over 4 key-value heads, padded head slots {3, 7, 11, 15}),
under the D19 separating hash tag, with the public tables' values.

WHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Correction C-6: a window of w
bits held in l byte limbs leaves 8l - w slack bits in its top limb, so the
layout pins that limb with `scaled(top, 1 << (8l - w))` beside the `byte`
lookup every limb already gets. When the window FILLS its top limb the
coefficient is 1, the scaled entry is the same lookup as the byte entry, and
all four of them -- rho and sigma of norm_a and of norm_m -- are dropped.
That happens exactly when the width passes 256: D_max = isqrt(1 + width *
32767^2), the window is 12 + bit_length(D_max), and at width 384 it is 32 =
8 * 4 limbs. Every bundle written before this pair is at width 96 or 16, so
no reader has ever seen the corrected layout at a size it can ingest; the
only shape that takes it is 125M.

Concretely, against `run-k-dense-p2` (the same pad-rule arm, the same two
group bits, the same row width):

* the plane index carries SEVENTEEN `Dom::D` helper planes, not nineteen, and
  the `H` plane list is 50 planes, not 52;
* `arguments[14]` (`03 D zero-check`) carries 54 terminals, not 56 -- the two
  dropped helper claims;
* the `H` commitment's opening counts and row totals follow from that, and no
  other domain's helper block moves.

WHAT IS THE SAME, deliberately: `Dom::T` (32 = 2^5), `Dom::Kv` (32 * 4 * 32 =
2^12) and `Dom::F` (32 * 512 = 2^14) are exact powers of two and DO NOT PAD,
while Ht, L, D, Q, S and Tab do -- 125M's own padded-domain set. So slots 02,
16 and 18 still carry two fewer `definition_challenges` than an all-padded
shape and slots 16 and 18 still report "degree":4, and this pair is a
regression for finding M-F1 too.

Hidden input and public weights: the ALL-ZERO hidden plane on the lane's synthetic tame fixture — the fixed input the privacy case is stated at, and a DEGENERATE witness: every key-value group is identically zero, so it says nothing about the group bits and is kept as the pair's control

This is a NEW PROFILE (D17): `hashline-zk-mr1/private-block-rung-c6-t32-dev/1`
for the block and `hashline-zk-mr1/private-run-rung-c6-t32-dev/1` for the run,
with their own hash-tag key set. No byte of any earlier profile moves.

Development grade (ruling P-7). Still not a privacy result: no gate has read
this.

What this is: the VERIFIER'S VIEW of one private run of 2 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-c6-t32-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/5-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_c6_gate_bundles -- --ignored --nocapture

Files: `run.json` (the run header, the shape, the external endpoints and the
1 internal boundaries) and `stage-NN.json` (per stage: the roots, the
twenty-three slot transcripts, the M opening, and the A, H and IO openings).
Each stage file carries its segment's length and SHA-256, so the bundle is
pinned to the exact receipt bytes that were verified; the segments themselves
are written into `segments/` only when `HL_RUN_CAPTURE_SEGMENTS=1` asks for
them, because they are a third of a bundle and the gate reads only the JSON.
`manifest.json` lists every file with its SHA-256 and pins the source files.

THE ARRAYS ARE IN `arrays.bin` (schema `hashline-native-capture/5-run`). A field-element
array of at least 256 entries is written in the JSON as
`{"array":"<sha256>","elem":"fp"|"fp2","len":N,"offset":O,"bytes":B}` and its
values are the B bytes at offset O of that file, little-endian: eight bytes
per `fp`, sixteen per `fp2` (`c0` then `c1`). Identical arrays are stored
ONCE and every reference to them names the same offset, which is why the
shape-only public tables cost one copy for the whole bundle rather than one
per slot per stage. Here: 1189 references over 1144 distinct arrays
(45 resolved to an array already stored), 1283 small arrays left
inline as plain JSON lists, 15464440 bytes of `arrays.bin`. Everything else
is byte for byte what schema `hashline-native-capture/4-run` writes.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

22695323 bytes of run file, stage files and segments.
