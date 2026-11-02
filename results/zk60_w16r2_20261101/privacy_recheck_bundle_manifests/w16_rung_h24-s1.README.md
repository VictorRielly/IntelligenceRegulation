# ZK60 run capture bundle

W16 privacy gate fixture (D54 re-check): one honest one-block run at the W16 block profile `hashline-zk-mr1/private-block-rung-lh-t32-w16-dev/1` under the TEST-ONLY run identity `hashline-zk-mr1/private-run-rung-lh-t32-w16-tst/1`, public synthetic weights (`range16_tests::case`), a hidden synthetic input from seed 1 (`w16_privacy_gate_tests::w16_case`); proved on this path: gpu: off (built with gpu-metal; HL_GPU unset). Test-only: delete once recorded.

EXPORT REPLAY (token round 17, `run_capture::export_replay`): every public table of this bundle's 1 block stage(s) that a reader TAKES rather than rebuilds from the shape (17 tables, 217600 entries: act3_values x1, act_support x1, exp_values x1, fold(w_d) x1, fold(w_g) x1, fold(w_k) x1, fold(w_o) x1, fold(w_q) x1, fold(w_u) x1, fold(w_v) x1, gamma_a x1, gamma_m x1, group_column x1, rope_cos@Kv x1, rope_cos@Q x1, rope_sin@Kv x1, rope_sin@Q x1) was derived again by the recorder from the EXPORT's public layer data, with the stage's own shape, definition challenges and LogUp challenges, and is byte-equal (SHA-256) to the table the verifier evaluated. The other public tables (supports, the causal mask, the byte table, the ones vector) are functions of the shape and the challenges alone and carry their values too.

What this is: the VERIFIER'S VIEW of one private run of 1 blocks under one
transcript, profile `hashline-zk-mr1/private-run-rung-lh-t32-w16-tst/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/5-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_W16PG_CAPTURE_DIR=<dir> [HL_W16PG_PROFILES=<names>] <hashline lib test binary> --ignored --exact --nocapture private_block::w16_privacy_gate_tests::w16_privacy_gate_write_the_w16_bundles

Files: `run.json` (the run header, the shape, the external endpoints and the
0 internal boundaries) and `stage-NN.json` (per stage: the roots, the
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
per slot per stage. Here: 359 references over 355 distinct arrays
(4 resolved to an array already stored), 1027 small arrays left
inline as plain JSON lists, 25355264 bytes of `arrays.bin`. Everything else
is byte for byte what schema `hashline-native-capture/4-run` writes.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

30753980 bytes of run file, stage files and segments.
