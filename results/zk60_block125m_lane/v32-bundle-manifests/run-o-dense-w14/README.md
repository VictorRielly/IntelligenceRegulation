# ZK60 run capture bundle

Bundle `run-o-dense-w14`: one honest 2-block run at the 125M-ROW-WIDTH
development shape (`Shape::rung_w14`: 64 tokens, width 768, hidden 1024, 12
query heads of 64 over 4 key-value heads, padded head slots {3, 7, 11, 15}),
under the D19 separating hash tag, with the public tables' values.

WHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Every bundle written before it
is at a row width of 2^8 or 2^10. This pair is at 2^14 -- 125M's own -- so a
reader sees, for the first time at a size it can ingest:

* `log_cols` 14 in every stage file, a message of 2^14 field elements
  encoded to 2^16 at inverse rate 4, and Merkle paths of SIXTEEN entries;
* A 527 rows and H 436 rows -- FEWER rows than any development bundle but
  the toy's, because a row sixteen times as wide holds the same planes;
* the lookup-table domain lifted from 2^8 to 2^14, a factor of SIXTY-FOUR,
  which is 125M's own lift distance (every earlier bundle lifts by 4);
* the endpoint and boundary commitments at an endpoint log of 14.

WHAT IS THE SAME, deliberately, so that this pair is a regression for both
earlier findings as well as new evidence: `Dom::T` (2^6), `Dom::Kv` (2^14)
and `Dom::F` (2^16) are exact powers of two and DO NOT PAD while Ht, L, D,
Q, S and Tab do (125M's own padded-domain set, finding M-F1), and the norm
window fills its top byte limb at width 768, so correction C-6 drops the
four `scaled` norm lookups and `Dom::D` carries 34 lookups and 17 helpers.
Slot 14 therefore carries 54 terminals here too.

The head axis, the width, D_max, the norm and softmax windows, the plane
lists, the per-position lookup counts, the slot degrees, the opening-group
counts and the endpoint log are 125M's EXACTLY. What is not 125M's is the
token count (64 against 512) and everything that scales with it, including
the endpoint's data rows (4 against 32).

Hidden input and public weights: the FULLY DENSE recipe at this shape's MEASURED chain band (down band 20, which is also the recipe's own single-block band; `private_block::dense_tests::dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half of the feed-forward planes live, twelve of twelve true head slots live, all four key-value groups carrying PAIRWISE DIFFERENT rotated keys, and the 64-wide rotation live. THE GENERIC WITNESS

This is a NEW PROFILE (D17): `hashline-zk-mr1/private-block-rung-w14-t64-dev/1`
for the block and `hashline-zk-mr1/private-run-rung-w14-t64-dev/1` for the run,
with their own hash-tag key set. No byte of any earlier profile moves.

Development grade (ruling P-7). Still not a privacy result: no gate has read
this.

What this is: the VERIFIER'S VIEW of one private run of 2 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-w14-t64-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/5-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir outside the repository> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_w14_gate_bundles -- --ignored --nocapture

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
per slot per stage. Here: 1189 references over 1164 distinct arrays
(25 resolved to an array already stored), 1283 small arrays left
inline as plain JSON lists, 42424904 bytes of `arrays.bin`. Everything else
is byte for byte what schema `hashline-native-capture/4-run` writes.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

50570640 bytes of run file, stage files and segments.
