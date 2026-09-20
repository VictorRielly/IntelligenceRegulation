# ZK60 run capture bundles — which is which

Four bundles, all of them the VERIFIER'S VIEW of an honest three-block
private run at the development rung (`Shape::rung_g`: 24 tokens, width 96,
hidden 192, 6 query heads over 2 key-value heads), profile
`hashline-zk-mr1/private-run-rung-g-t24-dev/1`. They are the INPUT to the
privacy gate of ruling M-8. **None of them is a privacy result**, and having
them does not meet the ruling.

Format, field by field: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`.
Writer: `hashline/src/private_block/run_capture.rs`.

| bundle | stage | source commit | on disk | has `run.json["plane_index"]` |
|---|---|---|---:|---|
| `run-a-tame` | 14 | `cb27845` | 38,484,890 B | **no** |
| `run-b-zero` | 14 | `cb27845` | 38,482,131 B | **no** |
| `run-c-tame` | 15 | `aff891d` | 38,509,009 B | **yes** |
| `run-d-zero` | 15 | `aff891d` | 38,499,945 B | **yes** |

(The byte figures are each bundle's own `manifest.json["total_bytes"]`.)

## Read `run-c-tame` and `run-d-zero`

**`run-a-tame` and `run-b-zero` PREDATE the plane index table** (stage 15,
2026-09-20). Everything else about their format is identical — the schema
string did not move, because adding the table is a pure addition — but they
do not carry the one field the run gate asked for: for every committed `A`
and `H` plane its id, name, domain and row range, and per slot the ordered
list of planes whose evaluations its terminal vector carries. Without it the
per-slot terminal identity cannot be closed at the rung. Use `run-c-tame` and
`run-d-zero` for that check.

The two older bundles are kept exactly as they were and **their own
`README.md` is deliberately NOT edited**: each bundle's `manifest.json` pins
every file of the bundle, including its README, by byte length and SHA-256,
so editing one would break that bundle's self-consistency. This parent file
carries the note instead.

## The four are four DIFFERENT runs

Each capture was taken with fresh OS randomness and its own external
endpoints, so **the receipts differ and the bundles differ byte for byte**.
`run-c-tame` is not `run-a-tame` with a field added; it is another run. The
one thing that IS equal across bundles is the plane index table itself, which
is a function of the public shape: `run-c-tame` and `run-d-zero` carry the
same 22,411 bytes of it (SHA-256 prefix `fb4cb872…`), and the Rust test
`the_plane_index_is_the_same_in_two_independent_bundles` checks exactly that,
against the table the layout derives.

At this shape the table lists **83 `A` planes tiling 377 rows** and **52 `H`
planes tiling 470 rows** (`H`'s 470 is the same `data_rows` the `H` opening
reports; 468 of those rows carry `kind: "data"`, the other two being the
zero-sum pair at rows 468 and 469 — see §4c of the format note).

## What is NOT in any of them

No witness value, no pad, no mask coefficient, no unopened column, no
unpublished salt, no unmasked sumcheck round, no hidden input, no boundary
plane. Each `run.json` lists this itself under `not_in_a_capture`, and the
test `every_key_of_a_bundle_is_on_the_allow_list` fails if the writer ever
emits a field outside its declared allow-list. The plane index table is
public LAYOUT only — a plane's name, domain and row range, never its
contents. The weights are synthetic and public; the hidden inputs came from
the lane's fixture generator and are not here.

## How they were made

    HL_RUN_CAPTURE_DIR=<this directory> HL_TEST_SOURCE_COMMIT=<commit> \
      cargo test --release --lib \
      private_block::run_capture_tests::write_the_gate_bundles \
      -- --ignored --nocapture

The segments (the receipt itself, 12,413,432 B per run) are written only
under `HL_RUN_CAPTURE_SEGMENTS=1` and are not here: every `stage-NN.json`
carries its own segment's length and SHA-256, so each bundle is pinned to the
exact bytes that were verified, and the gate's loader reads only JSON.
