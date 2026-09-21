# ZK60 run capture bundle

Bundle `run-k-dense-p2`: one honest 2-block run at the BOTH-PAD-BRANCHES
development shape (`Shape::rung_p2`: 32 tokens, width 96, hidden 256, 12 query
heads of 8 over 4 key-value heads, padded head slots {3, 7, 11, 15}), under
the D19 separating hash tag, with the public tables' values.

WHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Ruling P-1's pad-zero term is
drawn per HOST SLOT and only when the domain that slot hosts actually PADS:
the slot draws one extra `mu` and one `zeta` if it does, and neither if it
does not, and the support indicator (one public table, one degree) exists
only in the first case. Every bundle written before this pair is at a shape
where all nine domains pad, so no reader has ever seen the other arm at a
size it can ingest; the only shape that takes it is 125M.

Here `Dom::T` (32 = 2^5), `Dom::Kv` (32 * 4 * 8 = 2^10) and `Dom::F`
(32 * 256 = 2^13) are exact powers of two and DO NOT PAD, while `Dom::Ht`,
`Dom::L`, `Dom::D`, `Dom::Q`, `Dom::S` and `Dom::Tab` do — which is 125M's own
padded-domain set. Concretely, against `run-i-dense-k4` (the same padded
layout with every domain padded):

* `arguments[2]` (`02 norm squares zero-check`), `arguments[16]`
  (`05 KV zero-check`) and `arguments[18]` (`14 F zero-check`) each carry TWO
  FEWER entries in `definition_challenges` — the `mu` entry and the `zeta`;
* `arguments[16]` and `arguments[18]` report `"degree":4` where the rung-K4
  bundles report 5, and their `rounds` carry one value fewer each;
* those three slots' `tables` lists carry no support-indicator table.

Everything else — the plane index, the slot order, the terminals, the two
group bits of the bilinear slots — is rung-K4's.

Hidden input and public weights: the FULLY DENSE recipe at this shape's MEASURED chain band (down band 39; `private_block::dense_tests::dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half of the feed-forward planes live, twelve of twelve true head slots live and all four key-value groups carrying PAIRWISE DIFFERENT rotated keys. THE GENERIC WITNESS

This is a NEW PROFILE (D17): `hashline-zk-mr1/private-block-rung-p2-t32-dev/1`
for the block and `hashline-zk-mr1/private-run-rung-p2-t32-dev/1` for the run,
with their own hash-tag key set. No byte of any earlier profile moves.

Development grade (ruling P-7). Still not a privacy result: no gate has read
this.

What this is: the VERIFIER'S VIEW of one private run of 2 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-p2-t32-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/5-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_p2_gate_bundles -- --ignored --nocapture

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
per slot per stage. Here: 1177 references over 1134 distinct arrays
(43 resolved to an array already stored), 1295 small arrays left
inline as plain JSON lists, 9097448 bytes of `arrays.bin`. Everything else
is byte for byte what schema `hashline-native-capture/4-run` writes.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

15997144 bytes of run file, stage files and segments.
