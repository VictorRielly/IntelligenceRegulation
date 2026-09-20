# ZK60 run capture bundle

Bundle `run-b-zero`: one honest three-block run at the development rung
(`Shape::rung_g`: 24 tokens, width 96, hidden 192, 6 query heads over 2
key-value heads), hidden input = the all-zero plane. Fresh OS randomness; the public weights
are the lane's synthetic tame fixture. This is the geometry ruling M-8 names
for the run privacy gate.

What this is: the VERIFIER'S VIEW of one private run of 3 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-g-t24-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/4-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> cargo test --release --lib private_block::run_capture_tests::write_the_gate_bundles -- --ignored --nocapture

Files: `run.json` (the run header, the shape, the external endpoints and the
2 internal boundaries) and `stage-NN.json` (per stage: the roots, the
twenty-three slot transcripts, the M opening, and the A, H and IO openings).
Each stage file carries its segment's length and SHA-256, so the bundle is
pinned to the exact receipt bytes that were verified; the segments themselves
are written into `segments/` only when `HL_RUN_CAPTURE_SEGMENTS=1` asks for
them, because they are a third of a bundle and the gate reads only the JSON.
`manifest.json` lists every file with its SHA-256 and pins the source files.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

38480275 bytes of run file, stage files and segments.
