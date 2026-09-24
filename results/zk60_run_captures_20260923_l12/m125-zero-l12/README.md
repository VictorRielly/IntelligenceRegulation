# ZK60 run capture bundle

Bundle: one honest 12-block private run at the **125M shape**
(`Shape::m125`: 512 tokens, width 768, hidden 2048, 12 query heads of 64 over
4 key-value heads, row width 2^14, rate 4, 256 opened columns, a generalised
endpoint of 37 rows over the padded Dom::D cube), under the D19 separating
hash tag, profile `hashline-zk-mr1/private-run-m125/1`. Lane stage 48.

WHY IT EXISTS. Every 125M run capture before this one is a TWO-block run
(`m125-capture-dense-l2`, `m125-capture-zero-l2`). This is the whole
twelve-block run: eleven internal boundaries and two external endpoints under
one transcript. With the all-zero input it is also the first twelve-block all-zero
125M run ever proved and verified.

Hidden input and public weights: the ALL-ZERO hidden plane on the lane's synthetic tame fixture - the fixed input the privacy case is stated at, and the named DEGENERATE partner of the dense run

THE RECEIPT AND THE PUBLIC RUN STATEMENT ARE IN `run/`: `run/segment-000.bin`
... `run/segment-011.bin` (the 12 segments that were verified, written as
each was proved) and `run/statement/run-statement.json` (the run's PUBLIC
statement, `hashline-private-run-statement/1`, written only after the run
verified; ruling D21). Every stage file pins its segment by `segment_bytes`
and `segment_sha256`, and the statement lists every segment file's length and
SHA-256, so a process that did not prove the run can rebuild the verifier's
statement and check this receipt. `validation.json`, when present, is the
record of such a FRESH-PROCESS re-verify and canonical recapture, written
after the manifest and not pinned by it.

THE ENCODING (schema `hashline-native-capture/5-run`): every field-element
array of at least 256 entries is written in the JSON as
`{"array":"<sha256>","elem":"fp"|"fp2","len":N,"offset":O,"bytes":B}` and its
values are the B bytes at offset O of `arrays.bin`, little-endian: eight bytes
per `fp`, sixteen per `fp2` (`c0` then `c1`). Identical arrays are stored once.
Format note: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md` §12.

WHAT IS NOT HERE, as in every bundle: no witness value, no pad, no mask
coefficient, no unopened column, no unpublished salt, no unmasked sumcheck
round, no prover log and no timing of a witness-dependent step. The verifier's
view and nothing else.

A capture is the INPUT to the privacy gate of ruling M-8 and is NOT a privacy
result. No gate has read this.

What this is: the VERIFIER'S VIEW of one private run of 12 blocks under one
transcript, profile `hashline-zk-mr1/private-run-m125/1`, written by `hashline/src/private_block/run_capture.rs`
(schema `hashline-native-capture/5-run`). It is the INPUT to the privacy gate of ruling M-8 and it
is NOT a privacy result: no gate has read it.

What made it:

    HL_PB_CAPTURE_DIR=<dir> HL_PB_INPUT=<dense|zero> HL_PB_CAPTURE_BLOCKS=12 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<HEAD> cargo test --release --lib private_block::run_capture_tests::s48_capture_a_twelve_block_125m_run -- --ignored --nocapture

Files: `run.json` (the run header, the shape, the external endpoints and the
11 internal boundaries) and `stage-NN.json` (per stage: the roots, the
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
per slot per stage. Here: 7129 references over 6917 distinct arrays
(212 resolved to an array already stored), 6413 small arrays left
inline as plain JSON lists, 669200544 bytes of `arrays.bin`. Everything else
is byte for byte what schema `hashline-native-capture/4-run` writes.

NOT in this bundle: any prover-side value. The list is in `run.json` under
`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if
the writer ever emits a field outside its declared allow-list. The weights are
synthetic and public; the hidden input came from the lane's fixture generator
and is not here.

724387142 bytes of run file, stage files and segments.
