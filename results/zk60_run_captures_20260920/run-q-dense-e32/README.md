# ZK60 run capture bundle

Bundle `run-q-dense-e32`: one honest 2-block run at the 32-DATA-ROW-ENDPOINT
development shape (`Shape::rung_e32`: 32 tokens, width 768, hidden 1024, 12
query heads of 64 over 4 key-value heads, padded head slots {3, 7, 11, 15}),
under the D19 separating hash tag, with the public tables' values.

WHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Every bundle written before it
has an endpoint of 7, 9 or 21 commitment rows over 2, 4 or 16 data rows. The
endpoint commits the PADDED Dom::D cube in rows of 2^endpoint_log_n, and at
125M that is 2^19 / 2^14 = 32 data rows and 37 commitment rows. This pair is
the first a reader can ingest at that ROW COUNT:

* an external endpoint of 32 data rows and 37 commitment rows, with a
  296-byte opened-column digest -- 125M's own number;
* an internal boundary of 38 rows, one more, which is the run layer's own
  +1 for its second reserved IO tab row;
* an endpoint data row per TOKEN: the cube is 2^15 words over a 2^10-wide
  row, so row r is token r and rows 16..32 exist in no earlier bundle.

WHAT IS THE SAME, deliberately, so that this pair is a regression as well as
new evidence: `Dom::T` (2^5), `Dom::Kv` (2^13) and `Dom::F` (2^15) are exact
powers of two and DO NOT PAD while Ht, L, D, Q, S and Tab do (125M's own
padded-domain set, finding M-F1), and the norm window fills its top byte limb
at width 768, so correction C-6 drops the four `scaled` norm lookups and
Dom::D carries 34 lookups and 17 helpers. Slot 14 therefore carries 54
terminals here too.

WHAT IS NOT 125M's: the endpoint LOG (10 here, 14 there) and with it the
endpoint's row width and Merkle depth, the row width of the A / H / M
commitments (2^10), and the token count. rung-W14 is the bundle pair that
holds the row width; this one holds the row COUNT.

Hidden input and public weights: the FULLY DENSE recipe at this shape's chain band (down band 20, `private_block::dense_tests::dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half of the feed-forward planes live, twelve of twelve true head slots live, all four key-value groups carrying PAIRWISE DIFFERENT rotated keys, and all sixteen upper endpoint data rows live. THE GENERIC WITNESS

This is a NEW PROFILE (D17): `hashline-zk-mr1/private-block-rung-e32-t32-dev/1`
for the block and `hashline-zk-mr1/private-run-rung-e32-t32-dev/1` for the run,
with their own hash-tag key set. No byte of any earlier profile moves.

Development grade (ruling P-7). Still not a privacy result: no gate has read
this.

What this is: the VERIFIER'S VIEW of one private run of 2 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-e32-t32-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/5-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_e32_gate_bundles -- --ignored --nocapture

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
per slot per stage. Here: 1189 references over 1139 distinct arrays
(50 resolved to an array already stored), 1283 small arrays left
inline as plain JSON lists, 25033024 bytes of `arrays.bin`. Everything else
is byte for byte what schema `hashline-native-capture/4-run` writes.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

32747313 bytes of run file, stage files and segments.
