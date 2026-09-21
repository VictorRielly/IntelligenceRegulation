# ZK60 run capture bundle

Bundle `run-g-dense-s20`: one honest three-block run at the development rung
(`Shape::rung_g`: 24 tokens, width 96, hidden 192, 6 query heads over 2
key-value heads), under the D19 separating hash tag, with the public
tables' values, and — this is what is new — **under the REPAIRED bilinear
attention argument** (lane stage 20, finding S19-F1).

Hidden input and public weights: the FULLY DENSE recipe at the chain band (`private_block::dense_tests::dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input, the upper hidden half of the feed-forward planes live and the two key-value groups carrying DIFFERENT data in every block. THIS IS THE FIRST CAPTURE EVER TAKEN ON A NON-DEGENERATE WITNESS at a grouped profile

WHAT CHANGED IN THE BYTES. Slots 08 (`10 score matmul`) and 09 (`11 PV
matmul`) now SUM over the 1 key-value group bit(s) instead of fixing
them on both private factors. In this bundle that means:

* `arguments[8]` is (main 5, extension 2, degree 3) and `arguments[9]` is
  (main 6, extension 2, degree 3); their `rounds` arrays are longer and
  each round message carries one more value.
* each of those two slots' `tables` begins with
  `{"kind":"eq","start":0,"point":[...]}` — the PUBLIC group factor. Its
  point is the leading 1 entrie(s) of that slot's head challenge, which a
  reader RE-DERIVES from the slot's own `definition_challenges`; `start: 0`
  says it reads the leading 1 sumcheck variable(s) of `rho`. It is a
  verifier-computed table: never take a value from it, re-derive and compare.
* the PRIVATE tables are unchanged in number, order and role, so
  `plane_index.slot_planes[8]` and `[9]` are the same two-plane lists as
  before and `len(slot_planes[s]) == len(terminals)` still holds.
* every segment is 336 B per block longer than the stage-18 pair's.

The stage-18 bundles `run-e-tame-tagged` and `run-f-zero-tagged` are
therefore SUPERSEDED for gate purposes, as the parent README says.

Still not a privacy result: no gate has read this.

What this is: the VERIFIER'S VIEW of one private run of 3 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-g-t24-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/4-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_s20_gate_bundles -- --ignored --nocapture

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

41292658 bytes of run file, stage files and segments.
