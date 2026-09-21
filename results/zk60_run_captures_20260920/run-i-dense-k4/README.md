# ZK60 run capture bundle

Bundle `run-i-dense-k4`: one honest three-block run at the FOUR-KEY-VALUE-HEAD
development shape (`Shape::rung_k4`: 24 tokens, width 96, hidden 192, 12 query
heads of 8 over 4 key-value heads, padded head slots {3, 7, 11, 15} — 125M's
own head geometry), under the D19 separating hash tag, with the public tables'
values.

WHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Every bundle written before this
one is at log2(kv_heads) <= 1. The repaired bilinear attention argument (lane
stage 20, finding S19-F1) SUMS over the 2 key-value group bit(s) under a
public eq(r_g, .), so at one group bit that eq carries a ONE-element point and
the sum has two terms — and no tool has ever read a bundle where it carries
more. Here:

* `arguments[8]` (`10 score matmul`) is (main 5, extension 2, degree 3) and
  `arguments[9]` (`11 PV matmul`) is (main 7, extension 2, degree 3);
* each of those two slots' `tables` begins with
  `{"kind":"eq","start":0,"point":[<TWO Fp2 values>]}`. The point is the
  leading 2 entries of that slot's head challenge, which a reader
  RE-DERIVES from the slot's own `definition_challenges` and COMPARES; it must
  never take a value from it (ruling T-7). `start: 0` says the factor reads
  the leading 2 sumcheck variables of `rho`.
* the PRIVATE tables are unchanged in number, order and role, so
  `plane_index.slot_planes[8]` and `[9]` are the same two-plane lists as at
  rung-G and `len(slot_planes[s]) == len(terminals)` still holds.

Hidden input and public weights: the FULLY DENSE recipe at the chain band (`private_block::dense_tests::dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half of the feed-forward planes live, twelve of twelve head slots live and ALL FOUR key-value groups carrying PAIRWISE DIFFERENT rotated keys in every block. THIS IS THE FIRST CAPTURE EVER TAKEN WITH MORE THAN ONE GROUP BIT

This is a NEW PROFILE (D17): `hashline-zk-mr1/private-block-rung-k4-t24-dev/1`
for the block and `hashline-zk-mr1/private-run-rung-k4-t24-dev/1` for the run,
with their own hash-tag key set. No byte of any earlier profile moves.

Development grade (ruling P-7). Still not a privacy result: no gate has read
this.

What this is: the VERIFIER'S VIEW of one private run of 3 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-k4-t24-dev/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/4-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_k4_gate_bundles -- --ignored --nocapture

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

46441129 bytes of run file, stage files and segments.
