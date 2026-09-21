# ZK60 run capture bundles — which is which

Eight bundles, all of them the VERIFIER'S VIEW of an honest three-block
private run at the development rung (`Shape::rung_g`: 24 tokens, width 96,
hidden 192, 6 query heads over 2 key-value heads), run profile
`hashline-zk-mr1/private-run-rung-g-t24-dev/1`. They are the INPUT to the
privacy gate of ruling M-8. **None of them is a privacy result**, and having
them does not meet the ruling.

Format, field by field: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`.
Writer: `hashline/src/private_block/run_capture.rs`.

## READ `run-g-dense-s20` AND `run-h-zero-s20`. The other six are superseded.

| bundle | stage | hash rule | public tables' values | plane index | bilinear slots | witness | source commit | on disk |
|---|---|---|---|---|---|---|---|---:|
| `run-a-tame` | 14 | **legacy** | no | no | pre-repair | degenerate | `cb27845` | 38,484,890 B |
| `run-b-zero` | 14 | **legacy** | no | no | pre-repair | all-zero | `cb27845` | 38,482,131 B |
| `run-c-tame` | 15 | **legacy** | no | yes | pre-repair | degenerate | `aff891d` | 38,509,009 B |
| `run-d-zero` | 15 | **legacy** | no | yes | pre-repair | all-zero | `aff891d` | 38,499,945 B |
| `run-e-tame-tagged` | 18 | `blake3-keyed/1` | yes | yes | **pre-repair** | degenerate | `facc057` | 41,256,627 B |
| `run-f-zero-tagged` | 18 | `blake3-keyed/1` | yes | yes | **pre-repair** | all-zero | `facc057` | 41,249,809 B |
| `run-g-dense-s20` | 21 | **`blake3-keyed/1`** | **yes** | yes | **REPAIRED** | **FULLY DENSE, generic** | `0426ad2` | 41,296,268 B |
| `run-h-zero-s20` | 21 | **`blake3-keyed/1`** | **yes** | yes | **REPAIRED** | all-zero | `0426ad2` | 41,270,047 B |

(The byte figures are each bundle's own `manifest.json["total_bytes"]`.)

## Why e and f are superseded, and why `run-g-dense-s20` is the one that matters

**Two reasons, and the second one is the new one.**

1. **They carry the PRE-REPAIR bilinear argument.** Lane stage 20 repaired
   finding S19-F1: the two bilinear attention slots — 08 `10 score matmul`
   and 09 `11 PV matmul` — now SUM over the `log2(kv_heads)` key-value group
   bits under a public `eq(r_g, ·)` instead of fixing them as a coordinate of
   both private factors, which is a different polynomial and made the honest
   verifier reject honest proofs at every profile with more than one
   key-value head. At rung-G that gives each of those two slots one more main
   round and degree 3 instead of 2, so every segment of a run is **336 bytes
   per block** longer than `run-e` / `run-f`'s, and their `arguments[8]` /
   `arguments[9]` describe a schedule the code no longer builds.
2. **Every bundle before stage 21 was taken on a DEGENERATE witness.** The
   tame fixture is diagonal, so at `f > d` the whole upper hidden half
   `[d, f)` of every `Dom::F` plane is identically zero; its hidden state is
   the same in every head, so the two key-value groups carry identical keys
   and values and `A_RQL` is identically zero; and the all-zero input is that
   degeneracy taken further. Those are exactly the conditions that hid
   S19-F1 for nineteen stages. **The privacy gate has therefore never seen a
   non-degenerate witness.**

`run-g-dense-s20` is a FULLY DENSE run: no zero entry in any of the nine
public words, a non-constant hidden input, the upper hidden half live, and
the two key-value groups carrying DIFFERENT data in every block — the regime
S19-F1 rejected outright, so no capture could have been taken in it before.
`run-h-zero-s20` keeps the all-zero input, which is the fixed input the
privacy case is stated at, under the repaired argument.

## The group `eq` of slots 08 and 09, and how to read it

No new field: `Tab::Eq` already serialises the way the format note describes,
so in both stage-21 bundles

    arguments[8]["tables"][0] == {"kind":"eq","start":0,"point":[<1 Fp2>]}
    arguments[9]["tables"][0] == {"kind":"eq","start":0,"point":[<1 Fp2>]}

in **all three stages** (`lkv = log2(2) = 1` at rung-G). **Re-derive it, never
consume it** — the same rule as the hash-tag keys:

* `start` is an index into the slot's own `rho`, so the factor's value at the
  end of the sumcheck is `eq(point, rho[start : start + len(point)])`;
* `point` is the LEADING `lkv` entries of that slot's head challenge `r_h`,
  which a reader draws for itself from the slot's `definition_challenges`
  (slot 08 draws `r_h`, `r_t`, `r_j` in that order; slot 09 draws `r_h`,
  `r_t`, `r_i`). **Checked on these files after the write: for all six
  occurrences, `point == definition_challenges[:1]`.**

The PRIVATE tables did not move: `plane_index.slot_planes[8]` is still
`[A_QR8 (id 45), A_KR8 (id 54)]` and `[9]` is still `[A_P (id 60), A_V8
(id 52)]`, in the as-built push order, which the recorder's replay enforces
at every slot of every stage. `len(slot_planes[s].planes) == len(terminals)`
therefore still holds — it counts private tables only.

Slots 08 / 09 in these bundles: `(main, extension, degree)` = **(5, 2, 3)**
and **(6, 2, 3)**, 7 and 8 round messages, **4 values per round**, 2 terminals
each. Before the repair they were (4, 2, 2) and (5, 2, 2) with 3 values a
round.

## Sanity, checked on the stage-21 files as committed

* **every manifest entry** of both bundles — five files each (`run.json`,
  three stage files, `README.md`) — matches its recorded byte length AND its
  recorded SHA-256. **0 mismatches.**
* **93 public tables** in each bundle's three stages, **all 93 carrying
  values**, and for all 93 the recorded SHA-256 is the SHA-256 of the
  concatenated 16-byte little-endian `Fp2` encodings of exactly the values
  included. **0 mismatches.**
* `public_tables_included` is `true` and `hash_tag.rule` is
  `"blake3-keyed/1"` in both.
* **the plane index table is byte-identical across `g` and `h`** — and across
  `run-e-tame-tagged` too, since the repair does not move it: the same
  canonical 22,397 bytes, SHA-256 prefix `d2361312…`.
* 81 `eq` tables per bundle, of which the six above are the new group factor.

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

`run-e-tame-tagged` and `run-f-zero-tagged` fixed both: they are tagged, and
they carry every public table's values. **They are in turn superseded by
`run-g-dense-s20` / `run-h-zero-s20` for the two reasons at the top of this
file** — the pre-repair bilinear slots, and the degenerate witness.

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

## The eight are eight DIFFERENT runs

Each capture was taken with fresh OS randomness and its own external
endpoints, so **the receipts differ and the bundles differ byte for byte**.
`run-e-tame-tagged` is not `run-c-tame` re-keyed; it is another run. Do not
compare a byte of one bundle with a byte of another, with ONE exception: the
plane index table is a function of the public shape and IS equal across
bundles that carry it — `run-c-tame`, `run-d-zero`, `run-e-tame-tagged`,
`run-f-zero-tagged`, `run-g-dense-s20` and `run-h-zero-s20` all carry the
same table (22,411 bytes as the writer emits it, SHA-256 prefix
`fb4cb872…`; 22,397 bytes re-serialised canonically, prefix `d2361312…`),
which the Rust test
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

The stage-21 repaired pair:

    HL_RUN_CAPTURE_DIR=<this directory> HL_RUN_CAPTURE_PUBLIC_TABLES=1 \
      HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib \
      private_block::run_capture_tests::write_the_s20_gate_bundles \
      -- --ignored --nocapture

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

The segments (the receipt itself, 12,413,432 B per run before the repair and
**12,414,440 B after it** — the counted `+336 B` per block) are written only
under `HL_RUN_CAPTURE_SEGMENTS=1` and are not here: every `stage-NN.json`
carries its own segment's length and SHA-256, so each bundle is pinned to the
exact bytes that were verified, and the gate's loader reads only JSON.

## Nothing is deleted here, and the directory now holds 319 MB

The six older bundles stay byte for byte where they are and their own
`README.md` files are NOT edited (each `manifest.json` pins its own README by
length and SHA-256, so editing one would break that bundle's
self-consistency). This parent file carries every note instead. 319,048,726
bytes in eight bundles is the cost of keeping the record of what each stage
produced.
