# ZK60 run capture bundle

Bundle `run-s-dense-k8`: one honest three-block run at the EIGHT-KEY-VALUE-HEAD
development shape rung-K8 (24 tokens, width 128, hidden 192, 16 query heads of 8
over 8 key-value heads, two query heads per group, no padded head slot; padded
layout t_pad 32 / d_pad 128 / h_pad 16 / f_pad 256, rung-K4's), under the D19
separating hash tag, with the public tables' values. Lane stage 37.

TEST-ONLY SHAPE. rung-K8 is built in `hashline/src/private_block/k8_tests.rs`
through the existing `Shape::new` / `RunShape::new`; it is NOT registered in
`shape.rs` or `run.rs`, so this build can write no run STATEMENT file for it.
The bundle carries its shape in `run.json`, and the four hash-tag keys derive
from the block profile string alone.

WHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Every bundle written before this
one is at log2(kv_heads) <= 2. The repaired bilinear attention argument (lane
stage 20, finding S19-F1) SUMS over the 3 key-value group bits under a
public eq(r_g, .). Here:

* `arguments[8]` (`10 score matmul`) is (main 6, extension 2, degree 3) and
  `arguments[9]` (`11 PV matmul`) is (main 8, extension 2, degree 3);
* each of those two slots' `tables` begins with
  `{"kind":"eq","start":0,"point":[<THREE Fp2 values>]}`. The point is the
  leading 3 entries of that slot's head challenge, which a reader
  RE-DERIVES from the slot's own `definition_challenges` and COMPARES; it must
  never take a value from it (ruling T-7).
* the PRIVATE tables are unchanged in number, order and role, so
  `plane_index.slot_planes[8]` and `[9]` are the same two-plane lists as at
  rung-G and rung-K4.

Hidden input and public weights: the FULLY DENSE run recipe (`private_block::dense_tests::dense_run_case`, unchanged) at this shape's MEASURED three-block down band, 48, which is the recipe's own single-block band and `band_down_run`'s fallback at (192, 8) (pinned in `k8_tests.rs` as `K8_RUN_BAND`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half of the feed-forward planes live, sixteen of sixteen head slots live, ALL EIGHT key-value groups carrying PAIRWISE DIFFERENT keys and values and the two query heads of every group different, in every block. THE FIRST CAPTURE WITH MORE THAN TWO GROUP BITS

NEW PROFILES (D17): `hashline-zk-mr1/private-block-rung-k8-t24-dev/1` for the block and
`hashline-zk-mr1/private-run-rung-k8-t24-dev/1` for the run. No byte of any earlier profile moves.

Development grade (ruling P-7). Still not a privacy result: no gate has read
this.

What this is: the VERIFIER'S VIEW of one private run of 3 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-k8-t24-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/4-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<HEAD at capture> cargo test --release --lib private_block::k8_tests::write_the_k8_gate_bundles -- --ignored --nocapture

Files: `run.json` (the run header, the shape, the external endpoints and the
2 internal boundaries) and `stage-NN.json` (per stage: the roots, the
twenty-three slot transcripts, the M opening, and the A, H and IO openings).
Each stage file carries its segment's length and SHA-256, so the bundle is
pinned to the exact receipt bytes that were verified; the segments themselves
are written into `segments/` only when `HL_RUN_CAPTURE_SEGMENTS=1` asks for
them, because they are a third of a bundle and the gate reads only the JSON.
`manifest.json` lists every file with its SHA-256 and pins the source files.

Every array is an inline JSON list (schema `hashline-native-capture/4-run`); this bundle has no `arrays.bin`.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

46923819 bytes of run file, stage files and segments.
