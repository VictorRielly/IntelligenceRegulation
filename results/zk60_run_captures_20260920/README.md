# ZK60 run capture bundles — which is which

TEN bundles, all of them the VERIFIER'S VIEW of an honest three-block private
run. Eight are at the development rung (`Shape::rung_g`: 24 tokens, width 96,
hidden 192, 6 query heads over 2 key-value heads), run profile
`hashline-zk-mr1/private-run-rung-g-t24-dev/1`. **The two newest,
`run-i-dense-k4` and `run-j-zero-k4`, are at a DIFFERENT shape**
(`Shape::rung_k4`: the same 24 tokens, width 96 and hidden 192, with the
heads recut as 12 query heads of 8 over FOUR key-value heads), run profile
`hashline-zk-mr1/private-run-rung-k4-t24-dev/1`. They are the INPUT to the
privacy gate of ruling M-8. **None of them is a privacy result**, and having
them does not meet the ruling.

Format, field by field: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md`.
Writer: `hashline/src/private_block/run_capture.rs`.

## READ `run-g-dense-s20`, `run-h-zero-s20`, `run-i-dense-k4` and `run-j-zero-k4`. The other six are superseded.

**The `g`/`h` pair and the `i`/`j` pair are not versions of each other; they
are two DIFFERENT SHAPES and both are current.** `g`/`h` are the profile the
lane's runs are taken at, at ONE key-value group bit. `i`/`j` are the only
bundles anywhere with TWO group bits, which is the case the repaired
bilinear argument has and no tool has ever read (see the rung-K4 section
below).

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
| `run-i-dense-k4` | 22 | **`blake3-keyed/1`** | **yes** | yes | **REPAIRED, `lkv = 2`** | **FULLY DENSE, generic** | `3247a89` | 46,444,960 B |
| `run-j-zero-k4` | 22 | **`blake3-keyed/1`** | **yes** | yes | **REPAIRED, `lkv = 2`** | all-zero (degenerate) | `3247a89` | 46,418,960 B |

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

## `run-i-dense-k4` and `run-j-zero-k4`: the only bundles with TWO group bits

**The gap.** The repaired bilinear argument SUMS over `lkv =
log2(kv_heads)` key-value group bits under a public `eq(r_g, ·)`. At every
bundle before these two that is ONE bit: the sum has two terms and the eq's
point has one entry. The only shape with two bits is 125M, whose runs are
484 MB and which the Python gate cannot ingest. **So a reader of these
bundles has never had to handle a group of more than one bit, and a port
that quietly assumed one would have passed every check ever run.**

`Shape::rung_k4` is that case at a size a gate can read. It is rung-G's
geometry with the head axis recut:

| | rung-G | **rung-K4** |
|---|---|---|
| tokens / width / hidden | 24 / 96 / 192 | 24 / 96 / 192 (the same) |
| query heads × head_dim | 6 × 16 | **12 × 8** |
| key-value heads, `lkv` | 2, `lkv = 1` | **4, `lkv = 2`** |
| padded head slots | `{3, 7}` | **`{3, 7, 11, 15}`** (125M's own geometry) |
| `t_pad, d_pad, h_pad, f_pad` | 32, 128, 8, 256 | 32, 128, **16**, 256 |
| `Dom::S` | `2^13` | **`2^14`** (sixteen head slots, not eight) |
| row width, rate, `F_E`, endpoint | 10, 4, 12, generalised (9 rows) | the same |
| one block's receipt | 4,234,984 B | **4,743,128 B** |
| block profile | `…/private-block-rung-g-t24-dev/1` | `…/private-block-rung-k4-t24-dev/1` |
| run profile | `…/private-run-rung-g-t24-dev/1` | `…/private-run-rung-k4-t24-dev/1` |

`head_dim = 8` is forced, not chosen: `d_pad = h_pad * head_dim` must hold
and `width = q_heads * head_dim`, and a smaller head dimension would put
`Dom::Kv` BELOW the row width, where the P-3 lift makes the bilinear
coordinate lists unwritable and `Shape::new` refuses by name. At `head_dim =
8`, `Dom::Kv = 32 * 4 * 8 = 2^10` sits EXACTLY at the row width, which is
the toy's case and not a lift.

### What is different in the bytes

    arguments[8]["tables"][0] == {"kind":"eq","start":0,"point":[<TWO Fp2>]}
    arguments[9]["tables"][0] == {"kind":"eq","start":0,"point":[<TWO Fp2>]}

in all three stages of both bundles — a **two**-element point, so the group
sum has FOUR terms. The same rule applies as at rung-G: `start` indexes the
slot's own `rho`, so the factor is `eq(point, rho[start : start +
len(point)])`, and `point` is the LEADING `lkv` entries of that slot's head
challenge, which a reader draws for itself. **Checked on these files after
the write: for all six occurrences, `point == definition_challenges[:2]`.**

Slots 08 / 09 here: `(main, extension, degree)` = **(5, 2, 3)** and
**(7, 2, 3)**, 7 and 9 round messages, **4 values per round**, 2 terminals
each. (`SC_SCORE` is `lkv + log2(head_dim) = 2 + 3`, which is rung-G's
`1 + 4` by coincidence; `SC_PV` is `lkv + log2(t_pad) = 2 + 5`, one more
than rung-G's.)

The PRIVATE tables did not move: `plane_index.slot_planes[8]` is
`[A_QR8 (id 45), A_KR8 (id 54)]` and `[9]` is `[A_P (id 60), A_V8 (id 52)]`,
exactly as at rung-G, so `len(slot_planes[s].planes) == len(terminals)`
still holds.

### The plane index at rung-K4 is a DIFFERENT table

83 `A` planes tiling **481** rows and 52 `H` planes tiling **614** rows
(against rung-G's 377 and 470): the head axis doubles `Dom::S`. Canonically
re-serialised it is **22,419 bytes, SHA-256 prefix `89cd8a46…`**, and it is
byte-identical across `i` and `j` — but it is NOT rung-G's `d2361312…`
table and must never be compared with it.

### Sanity, checked on the stage-22 files as committed

* **every manifest entry** of both bundles — five files each — matches its
  recorded byte length AND its recorded SHA-256. **0 mismatches.**
* **93 public tables** per bundle across its three stages, **all 93 carrying
  values**, and for all 93 the recorded SHA-256 is the SHA-256 of the
  concatenated 16-byte little-endian `Fp2` encodings of exactly the values
  included. **0 mismatches.**
* `public_tables_included` is `true` and `hash_tag.rule` is
  `"blake3-keyed/1"` in both; both name the rung-K4 run and block profiles.
* the plane index is byte-identical across `i` and `j`.
* 81 `eq` tables per bundle, of which the six above are the group factor.
* `run-i-dense-k4`'s witness: twelve of twelve head slots live, all FOUR
  key-value groups live and **pairwise different**, the upper hidden half of
  the feed-forward planes live, in every one of the three blocks.
  `run-j-zero-k4` is the all-zero input and is degenerate by construction.

Segments (not written here) are 4,575,304 / 4,597,832 / 4,765,736 B =
**13,938,872 B** per run, the counted lengths.

Development grade (ruling P-7), one profile per shape (D17). **No byte of
any earlier profile moves**, and none of the eight earlier bundles is
touched.

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

The stage-22 rung-K4 pair (`run-i-dense-k4`, `run-j-zero-k4`):

    HL_RUN_CAPTURE_DIR=<this directory> HL_RUN_CAPTURE_PUBLIC_TABLES=1 \
      HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib \
      private_block::run_capture_tests::write_the_k4_gate_bundles \
      -- --ignored --nocapture

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

## Nothing is deleted here, and the directory now holds 412 MB

The eight older bundles stay byte for byte where they are and their own
`README.md` files are NOT edited (each `manifest.json` pins its own README by
length and SHA-256, so editing one would break that bundle's
self-consistency). This parent file carries every note instead. 411,912,646
bytes in TEN bundles is the cost of keeping the record of what each stage
produced.

## Stage 27 (2026-09-21): all ten bundles here are schema `hashline-native-capture/4-run`

The writer gained a second encoding, `hashline-native-capture/5-run`, in
which a field-element array of at least 256 entries is written in the JSON as
`{"array":"<sha256>","elem":"fp"|"fp2","len":N,"offset":O,"bytes":B}` and its
values are the B bytes at offset O of the bundle's one `arrays.bin`,
little-endian. **None of the ten bundles here uses it**: the default is
unchanged, nothing here was re-taken, and everything above still reads as
written.

It exists because a 125M bundle does not fit in decimal JSON — a uniformly
random `Fp` costs 21.4 bytes of text against 8 in binary, and the 125M shape's
five `2^22`-entry public tables per stage are 409 MB raw — while the same
bundle with the store, whose shape-only tables are stored ONCE for the whole
bundle, is about 350 MB for two blocks. The format is in
`docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md` §12, and a Rust test captures
one run BOTH ways and compares the two bundles byte for byte.

**125M bundles are written OUTSIDE the repository** (`HL_PB_CAPTURE_DIR` is
refused inside the tree) and are never committed here. The launch commands
are in stage 27 of `ZK60_BLOCK125M_LANE_PROGRESS.md`.

## Stage 30 (2026-09-21): `run-k-dense-p2` and `run-l-zero-p2` — the first bundles with an UNPADDED domain

The directory now holds **TWELVE bundles**; the two new ones are the first
written at a shape that takes the OTHER arm of ruling P-1's pad rule, and the
first here in schema `hashline-native-capture/5-run`.

**Why they exist.** The pad-zero term is drawn per HOST SLOT and only when
the domain that slot hosts actually pads: that slot then draws one extra `mu`
and one `zeta`, and its support indicator adds a public table and (at the
eight indicator slots) one degree. Every one of the ten older bundles is at a
shape where **all nine domains pad**, so all eight host slots are on the
padded arm in every one of them. The only shape that takes the other arm is
125M, and the Python run gate's port of the rule was wrong on that arm until
2026-09-21 because no bundle it could read contained it (its finding
**M-F1**).

`Shape::rung_p2` — 32 tokens, width 96, hidden 256, twelve query heads of 8
over four key-value heads — is 125M's padded-domain set on rung-K4's padded
layout: `Dom::T` (2^5), `Dom::Kv` (32·4·8 = 2^10) and `Dom::F` (32·256 =
2^13) are exact powers of two and do NOT pad; `Dom::Ht`, `Dom::L`, `Dom::D`,
`Dom::Q`, `Dom::S` and `Dom::Tab` do.

### What is different in the bytes, against `run-i-dense-k4` / `run-j-zero-k4`

Read off the committed files (`results/zk60_block125m_lane/t30-bundle-check.log`,
0 mismatches), stage 0 against stage 0, **20 of 23 slots identical** in both
their schedule and their `definition_challenges` length:

| slot | name | rung-P2 draws / degree | rung-K4 draws / degree |
|---|---|---:|---:|
| 02 | `02 norm squares zero-check` | **13** / 3 | 15 / 3 |
| 16 | `05 KV zero-check` | **19** / **4** | 21 / 5 |
| 18 | `14 F zero-check` | **24** / **4** | 26 / 5 |

Two fewer challenges is exactly the `mu` entry and the `zeta`; the lost
degree at 16 and 18 is the support indicator, which is why those slots'
`rounds` carry one value fewer each. Both stages of each bundle carry the
same schedule and the same counts. A port that models the pad rule as "always
on" fails on these two bundles in seconds, which is the whole reason they are
here.

### The pair, as written

| bundle | blocks | `run.json` | stage files | `arrays.bin` | on disk |
|---|---:|---:|---:|---:|---:|
| `run-k-dense-p2` (FULLY DENSE, generic) | 2 | 34,950 B | 3,151,494 / 3,713,252 B | 9,097,448 B | **16,001,981 B** |
| `run-l-zero-p2` (all-zero, degenerate) | 2 | 34,947 B | 3,148,521 / 3,709,513 B | 9,014,520 B | **15,912,181 B** |

**Two blocks and the array store, deliberately**: the classic encoding at
three blocks would be about 46 MB each, as the rung-K4 pair is. Both are
schema `/5-run`, both carry the public tables' VALUES
(`"public_tables_included":true`), both are tagged
(`"rule":"blake3-keyed/1"`), both name
`hashline-zk-mr1/private-run-rung-p2-t32-dev/1`, and each manifest's five
files match their recorded length and SHA-256 with the source pin `4ccbad1`
over 38 files.

They are **not gate evidence** (ruling T-6): the Python run gate has to learn
this profile's key set and this shape's plane index before a bundle is
judged. They are the INPUT to that work, and the reason they exist is finding
M-F1.

## Stage 31 (2026-09-21): `run-m-dense-c6` and `run-n-zero-c6` — the first bundles with CORRECTION C-6 applied

The directory now holds **FOURTEEN bundles**; the two new ones are the first
written at a shape whose norm window fills its top byte limb, so the layout
they carry is the CORRECTED one.

**Why they exist.** A window of `w` bits held in `l` byte limbs leaves
`8l − w` slack bits in its top limb, so the layout pins that limb with
`scaled(top, 1 << (8l − w))` beside the `byte` lookup every limb already
gets. When the window FILLS its top limb the coefficient is `1 << 0 = 1`,
the scaled entry is the very same lookup as the byte entry, and all four of
them — `rho` and `sigma` of `norm_a` and of `norm_m` — are dropped. That is
**correction C-6**, and it happens exactly when the width passes 256:
`D_max = isqrt(1 + width · 32767²)`, the window is `12 + bit_length(D_max)`,
and at width 384 it is `32 = 8 · 4` limbs. Every one of the twelve older
bundles is at width 96 or 16, so no reader has ever seen the corrected
layout at a size it can ingest; the only shape that takes it is 125M.

`Shape::rung_c6` — 32 tokens, width 384, hidden 512, twelve query heads of
**32** over four key-value heads — is `Shape::rung_p2` with the head
dimension widened, which is the smallest move that crosses the window.

### What is different in the bytes, against `run-k-dense-p2`

Read off the committed files
(`results/zk60_block125m_lane/u31-bundle-check.log`, **0 mismatches**),
stage 0 against stage 0:

| what | rung-C6 | rung-P2 |
|---|---:|---:|
| `Dom::D` helper planes in the plane index | **17** | 19 |
| `H` planes in the plane index | **50** | 52 |
| `arguments[14]` (`03 D zero-check`) terminals | **54** | 56 |
| `a_rows` / `h_rows` | 1,337 / 1,408 | 727 / 720 |

The two missing terminals of slot 14 are the two dropped helper claims; the
row totals also carry the widened head dimension, which is why they are not
simply two rows apart. **No other domain's helper block moves**, which is the
whole of C-6.

### What is deliberately the SAME: stage 30's unpadded arm

This shape keeps 125M's padded-domain set — `Dom::T` (2^5), `Dom::Kv`
(32·4·32 = 2^12) and `Dom::F` (32·512 = 2^14) do not pad — so slots 16 and
18 still report `"degree":4` where the rung-K4 bundles report 5, and slot 02
still draws no `zeta`. The pair is therefore a regression for finding
**M-F1** as well as the first evidence for C-6. (The absolute
`definition_challenges` counts are NOT rung-P2's: every domain log is larger
here, so each `tau` is longer. The pad-rule fact a port has to get right is
the DEGREE and the presence of the support-indicator table, and those are
rung-P2's exactly.)

### The pair, as written

| bundle | blocks | `run.json` | stage files | `arrays.bin` | on disk |
|---|---:|---:|---:|---:|---:|
| `run-m-dense-c6` (FULLY DENSE, generic) | 2 | 34,847 B | 3,275,672 / 3,913,538 B | 15,635,336 B | **22,864,518 B** |
| `run-n-zero-c6` (all-zero, degenerate) | 2 | 34,852 B | 3,282,805 / 3,913,226 B | 15,464,440 B | **22,700,238 B** |

**22.9 and 22.7 MB, with both size levers already taken**: two blocks (one
internal boundary, the least a run-level reader needs) and the `/5-run`
array store, which deduplicated 52 arrays here. What is left is the shape
itself — the helper commitment is 1,408 rows against rung-P2's 720 because
the head dimension is four times as wide — and it is not C-6's doing: C-6
makes the bundle SMALLER by two helper planes. A one-block bundle would be
about 12 MB and would carry no internal boundary, so it was not taken.

Both are schema `/5-run`, both carry the public tables' VALUES
(`"public_tables_included":true`), both are tagged
(`"rule":"blake3-keyed/1"`), both name
`hashline-zk-mr1/private-run-rung-c6-t32-dev/1`, and each manifest's five
files match their recorded length and SHA-256 with the source pin `3e106e1`
over 38 files.

They are **not gate evidence** (ruling T-6): the Python run gate has to learn
this profile's key set and this shape's plane index before a bundle is
judged. They are the INPUT to that work.

## Stage 32 (2026-09-21) — `run-o-dense-w14` and `run-p-zero-w14`, at the 125M ROW WIDTH, and NOT in this directory

**They are not here.** The two stage-32 bundles are **50.6 MB and 49.5 MB**,
past the ~40 MB a file in this repository should be, so they live beside the
125M captures at

```
/home/victor/zk60-artifacts/run-o-dense-w14
/home/victor/zk60-artifacts/run-p-zero-w14
```

and what is committed is their manifests, their own notes and the self-check
that reads them off disk:
`results/zk60_block125m_lane/v32-bundle-manifests/` and
`results/zk60_block125m_lane/v32-bundle-check.log`.

**What is new in them.** Every bundle above is at a row width of 2^8 or
2^10. This pair is at **2^14 — 125M's own** — so a reader sees, for the
first time at a size it can ingest:

* `"log_cols":14` in every stage file: a message of 2^14 field elements
  encoded to 2^16 at inverse rate 4, and Merkle paths of **sixteen** entries;
* `"a_rows":527` and `"h_rows":436` — FEWER rows than any development bundle
  but the toy's, because a row sixteen times as wide holds the same planes;
* the lookup-table domain lifted from 2^8 to 2^14, a factor of **64**, which
  is 125M's own lift distance (every earlier bundle lifts by 4);
* the endpoint and boundary commitments at an endpoint log of 14 (a ten-row
  internal boundary over a 2^16-word padded cube).

**What is deliberately the same**, so that the pair is a regression for both
earlier findings: `Dom::T` (2^6), `Dom::Kv` (2^14) and `Dom::F` (2^16) do not
pad while Ht, L, D, Q, S and Tab do — 125M's padded-domain set, finding
**M-F1** — and the norm window fills its top byte at width 768, so
correction **C-6** applies and slot 14 carries **54 terminals**, as in the
rung-C6 pair.

| bundle | blocks | `run.json` | stage files | `arrays.bin` | on disk |
|---|---:|---:|---:|---:|---:|
| `run-o-dense-w14` (FULLY DENSE, generic) | 2 | 34,845 B | 3,695,023 / 4,415,868 B | 42,424,904 B | **50,575,731 B** |
| `run-p-zero-w14` (all-zero, degenerate) | 2 | 34,828 B | 3,694,816 / 4,418,843 B | 41,380,544 B | **49,533,887 B** |

Both are schema `/5-run`, both carry the public tables' VALUES, both are
tagged, both name `hashline-zk-mr1/private-run-rung-w14-t64-dev/1`, and each
manifest's five files match their recorded length and SHA-256 with the
source pin `11703c9` over 38 files.

They are **not gate evidence** (ruling T-6) and not a privacy result: they
are the INPUT to the independent Python run gate.
