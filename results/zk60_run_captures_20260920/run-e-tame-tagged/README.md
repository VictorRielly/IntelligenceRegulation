# ZK60 run capture bundle

Bundle `run-e-tame-tagged`: one honest three-block run at the development rung
(`Shape::rung_g`: 24 tokens, width 96, hidden 192, 6 query heads over 2
key-value heads), hidden input = the lane fixture's tame plane. Fresh OS randomness; the public weights
are the lane's synthetic tame fixture. This is the geometry ruling M-8 names
for the run privacy gate.

STAGE 18, and this is what is new about it:

* the run is proved and verified under the **D19 SEPARATING HASH TAG**
  (stage 17, ruling T-1): every hash of every stage is keyed BLAKE3 under one
  of the four public keys derived from the block profile string. `run.json`
  carries `hash_tag` with the rule name `blake3-keyed/1`, the profile, the
  four context strings and the four keys as hex. A reader must RE-DERIVE
  those keys from the contexts and the profile and COMPARE; it must never
  take a key from a bundle (ruling T-7).
* it was taken with `HL_RUN_CAPTURE_PUBLIC_TABLES=1`, so every public table
  carries its **values** as well as its length and SHA-256. That is what the
  run gate needs to close the per-slot terminal identity at every slot.

The four earlier bundles `run-a-tame`, `run-b-zero`, `run-c-tame` and
`run-d-zero` are LEGACY-RULE bundles taken before the tag and without the
public tables' values; the parent README says so.

Still not a privacy result: no gate has read this.

What this is: the VERIFIER'S VIEW of one private run of 3 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-g-t24-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/4-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_tagged_gate_bundles -- --ignored --nocapture

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

41253678 bytes of run file, stage files and segments.
