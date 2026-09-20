# ZK60 run capture bundles — which is which

Six bundles, all of them the VERIFIER'S VIEW of an honest three-block private
run at the development rung (`Shape::rung_g`: 24 tokens, width 96, hidden 192,
6 query heads over 2 key-value heads), run profile
`hashline-zk-mr1/private-run-rung-g-t24-dev/1`. They are the INPUT to the
privacy gate of ruling M-8. **None of them is a privacy result**, and having
them does not meet the ruling.

Format, field by field: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`.
Writer: `hashline/src/private_block/run_capture.rs`.

## READ `run-e-tame-tagged` AND `run-f-zero-tagged`. The other four are superseded.

| bundle | stage | hash rule | public tables' values | plane index | source commit | on disk |
|---|---|---|---|---|---|---:|
| `run-a-tame` | 14 | **legacy** | no | no | `cb27845` | 38,484,890 B |
| `run-b-zero` | 14 | **legacy** | no | no | `cb27845` | 38,482,131 B |
| `run-c-tame` | 15 | **legacy** | no | yes | `aff891d` | 38,509,009 B |
| `run-d-zero` | 15 | **legacy** | no | yes | `aff891d` | 38,499,945 B |
| `run-e-tame-tagged` | 18 | **`blake3-keyed/1`** | **yes** | yes | `facc057` | 41,256,627 B |
| `run-f-zero-tagged` | 18 | **`blake3-keyed/1`** | **yes** | yes | `facc057` | 41,249,809 B |

(The byte figures are each bundle's own `manifest.json["total_bytes"]`.)

## Why a–d are superseded for gate purposes

**Two reasons, and the first one is decisive.**

1. **They are LEGACY-RULE bundles.** Stage 17 landed decision D19's
   separating hash tag (ruling T-1): on a TAGGED profile — and rung-G is one
   — every hash of every stage is BLAKE3 in KEYED mode, under one of four
   fixed public keys derived from the block profile string. That moved every
   proof byte the two tagged profiles produce. Bundles `run-a-tame` …
   `run-d-zero` were all captured before the tag, so they are the verifier's
   view of a run made under a rule the code no longer uses for this profile.
   A gate that judged them would be judging bytes nothing produces now.
2. **They were taken with `public_tables_included: false`.** The run gate
   could close the per-slot terminal identity `fin = c·mask_eval +
   poly(terminals)` at only twelve of the twenty-three slots, because the
   other eleven read a PUBLIC table whose values it would not guess at.

`run-e-tame-tagged` and `run-f-zero-tagged` fix both: they are tagged, and
they carry every public table's values.

## What the tag means in a bundle, and the one rule about it

`run.json["hash_tag"]` carries the rule name `"blake3-keyed/1"`, the block
profile string, the four CONTEXT strings and the four keys as hex. A
legacy-rule bundle carries `{"rule":"legacy"}` and nothing else.

**RE-DERIVE, NEVER CONSUME (ruling T-7).** A reader computes each key itself
as `blake3.derive_key(<context>, <block profile>)` and COMPARES it with
`keys_hex`; nothing may ever select a hash rule or take a key from a bundle.
The keys are public functions of public strings, so publishing them discloses
nothing — but they are never an input.

The four keys of `hashline-zk-mr1/private-block-rung-g-t24-dev/1`, pinned in
both Rust and Python (stage 17's ledger section):

| role | key |
|---|---|
| transcript | `51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe` |
| column | `2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c` |
| leaf | `fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032` |
| node | `8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc` |

Note that a RUN is keyed under its BLOCK shape's four keys, not under keys of
the run profile. `transcript_domain` is the run profile; the tag is the block
profile's. That is deliberate and is recorded in stage 17's ledger section.

## The public tables, and why including their values publishes nothing

A slot's public table is a function of the PUBLIC statement and that stage's
challenges. Weights are public under this project's privacy model (P1 hides
inputs, outputs and intermediate activations; weights may be public), so a
public table's values are already implied by what the verifier holds. They
are opt-in only because they are the largest thing in a bundle.

Every public table carries `len` and `sha256` in both forms; with
`public_tables_included: true` it also carries `values`, and the SHA-256 is
over the concatenated 16-byte little-endian `Fp2` encodings of exactly those
values, so a reader can check the two against each other. **Checked here
after the write**: each of these two bundles carries **93** public tables
across its three stages, all 93 with their values, and all 93 SHA-256 agree
with the values included. Adding them cost **2.75 MB** per bundle
(38.5 MB -> 41.3 MB).

## The six are six DIFFERENT runs

Each capture was taken with fresh OS randomness and its own external
endpoints, so **the receipts differ and the bundles differ byte for byte**.
`run-e-tame-tagged` is not `run-c-tame` re-keyed; it is another run. Do not
compare a byte of one bundle with a byte of another, with ONE exception: the
plane index table is a function of the public shape and IS equal across
bundles that carry it — `run-c-tame`, `run-d-zero`, `run-e-tame-tagged` and
`run-f-zero-tagged` all carry the same 22,411 bytes of it (SHA-256 prefix
`fb4cb872…`), which the Rust test
`the_plane_index_is_the_same_in_two_independent_bundles` checks against the
table the layout derives.

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

## Nothing is ever edited or deleted here

The four older bundles are kept exactly as they were and **their own
`README.md` files are deliberately NOT edited**: each bundle's
`manifest.json` pins every file of the bundle, including its README, by byte
length and SHA-256, so editing one would break that bundle's
self-consistency. This parent file carries every note instead.

## How they were made

The stage-18 tagged pair:

    HL_RUN_CAPTURE_DIR=<this directory> HL_RUN_CAPTURE_PUBLIC_TABLES=1 \
      HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib \
      private_block::run_capture_tests::write_the_tagged_gate_bundles \
      -- --ignored --nocapture

The four legacy-rule bundles, at stages 14 and 15:

    HL_RUN_CAPTURE_DIR=<this directory> HL_TEST_SOURCE_COMMIT=<commit> \
      cargo test --release --lib \
      private_block::run_capture_tests::write_the_gate_bundles \
      -- --ignored --nocapture

The segments (the receipt itself, 12,413,432 B per run) are written only
under `HL_RUN_CAPTURE_SEGMENTS=1` and are not here: every `stage-NN.json`
carries its own segment's length and SHA-256, so each bundle is pinned to the
exact bytes that were verified, and the gate's loader reads only JSON.
