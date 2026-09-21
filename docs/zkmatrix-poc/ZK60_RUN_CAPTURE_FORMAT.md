# The RUN CAPTURE format — what a bundle contains, field by field

**Written 2026-09-20 on lane `zk60-private-block-125m` (stage 14), for the
agent extending the Python privacy gates.** The writer is
`hashline/src/private_block/run_capture.rs`. It is a NEW module, never an edit
of the integrator's `hashline/src/native_capture.rs` (ruling M-8), and its
schema is a strict superset of that writer's.

**Revised 2026-09-20 (stage 15): the PLANE INDEX TABLE was added** — the one
field the run privacy gate asked for and would not guess at (§3a). **The
schema string does NOT move**: it stays `"hashline-native-capture/4-run"`,
because the change is a PURE ADDITION — one new member `plane_index` of
`run.json`, no existing field renamed, removed, re-typed or re-meant, so
every reader written against stage 14's bundles still reads a stage-15 bundle
correctly and simply ignores a key it does not know. The same revision writes
down three field MEANINGS the gate found and did not change (§4a `claim`,
§4c `data_rows`, §5 the endpoints' spare mask row). Bundles `run-c-tame` and
`run-d-zero` carry the table; `run-a-tame` and `run-b-zero` predate it and are
otherwise identical in format.

**Revised 2026-09-20 (stage 17): the `hash_tag` member was added** — WHICH
HASH RULE made the bundle (§2a), under decision D19's separating hash tag.
**The schema string does NOT move again**: it stays
`"hashline-native-capture/4-run"`, for the same reason as in stage 15 — this
is a PURE ADDITION of one member of `run.json`, with no existing field
renamed, removed, re-typed or re-meant, so a reader written against stage 14
or stage 15 reads a stage-17 bundle unchanged and ignores a key it does not
know. **But the BYTES of every tagged profile's proof move once**, so the
four existing bundles (`run-a-tame`, `run-b-zero`, `run-c-tame`,
`run-d-zero`) were all made under the legacy rule and must be re-taken before
any tagged run is judged; until the Python run gate learns the rule, a tagged
bundle is not gate evidence (ruling T-6).

**Revised 2026-09-20 (stage 18): the bundles were RE-TAKEN under the tag,
with the public tables' values** — `run-e-tame-tagged` and
`run-f-zero-tagged` (§10). Nothing in the schema moves: the two new bundles
are the same format written by the same writer, with `hash_tag.rule` =
`blake3-keyed/1` and `public_tables_included` = `true`. The four older
bundles are LEGACY-RULE bundles and are superseded for gate purposes. The
same stage adds a SEPARATE artifact that is not a capture at all — the
public RUN STATEMENT retained beside a run's segments (§11).

**What a bundle is.** The VERIFIER'S VIEW of one private run of `L` blocks
under one transcript, at the development rung (ruling M-8's geometry: 24
tokens, width 96, hidden 192, 6 query heads over 2 key-value heads, `L = 3`).
It is the INPUT to a privacy gate that does not exist yet. **Nothing about a
bundle is a privacy statement**, and writing one does not meet ruling M-8.

**What a bundle is not.** It holds no witness value, no pad, no mask
coefficient, no unopened column, no unpublished salt and no unmasked sumcheck
round. A retained capture counts as publishing, so the writer emits only keys
on a declared allow-list (`run_capture::ALLOWED_KEYS`) and the test
`every_key_of_a_bundle_is_on_the_allow_list` fails if one appears that is not
on it.

---

## 0. Read this first: the five things that differ from a single-block capture

1. **The schema string is new.** `"schema": "hashline-native-capture/4-run"`
   (a string, where the single-block writer emits the integer `3`), and
   `"kind"` is `"zk60-run-verifier-observations"` for the run file and
   `"zk60-run-stage-observations"` for a stage file. Today's loader
   (`zk60_native_jv_capture.Capture.__init__`) refuses both by version, which
   is the intent: a loader that does not know runs must refuse rather than
   read a stage as a proof.
2. **A bundle is a DIRECTORY, not one file.** `run.json` (the run header,
   once) plus `stage-00.json … stage-{L-1}.json` (one per stage), plus
   `manifest.json` and `README.md`. The single-block bundle's per-proof
   content lives in a STAGE file: `header`, `logup_challenges`, `arguments`
   (23 slots), `mask`, `roles`. Point the existing per-commitment analyses at
   a stage file.
3. **A run has TWO profile strings.** `profile` (= `transcript_domain`) is the
   RUN profile `hashline-zk-mr1/private-run-rung-g-t24-dev/1` — the
   `Transcript::new` domain — and `block_profile` is the per-block shape's
   profile `hashline-zk-mr1/private-block-rung-g-t24-dev/1`. The per-block one
   never appears in a run's transcript.
4. **Four NEW Fiat-Shamir labels**, all listed as data in
   `run.json["transcript_labels"]`: `run-shape`, `pb-run-stage`,
   `pb-run-block`, `B`. The per-slot labels are the block family's
   (`pb-slot`, `pb-scalar`, `pb-term`).
5. **The IO role names still name the CLAIM SITE, not the commitment.** A
   stage's incoming opening is `"role":"Input"` whether the commitment behind
   it is the external input endpoint (stage 0) or internal boundary `k-1`
   (every later stage); `"commitment_kind"` and `"boundary"` say which. The
   four role names `A`, `H`, `Input`, `Output` are unchanged, so `ROLE_ORDER`
   keeps working — but see §6, the openings per stage are 3, 3, …, 4.

---

## 1. The files

| file | what |
|---|---|
| `run.json` | the run statement, the shape as data, the external endpoints, the `L-1` internal boundaries, the transcript labels and program |
| `stage-NN.json` | one per stage `NN = 00 … L-1`: the stage's roots, its 23 slot transcripts, its M opening, and its A / H / IO openings |
| `manifest.json` | every file with its byte length and SHA-256, plus the SHA-256 of every Rust source file that decides what a bundle contains |
| `README.md` | what the bundle is, the command that made it, what is not in it |
| `segments/segment-NN.bin` | the receipt segments that were verified. **Written only when `HL_RUN_CAPTURE_SEGMENTS=1`**: each stage file already carries its segment's `segment_bytes` and `segment_sha256`, so the bundle is pinned to the exact bytes either way, and the gate's loader reads only JSON |

Encodings, unchanged from the single-block writer: an `Fp` is a decimal `u64`;
an `Fp2` is `[c0, c1]` (two decimal `u64`, `u^2 = NONRESIDUE`); a 32-byte
digest, salt, Merkle-path node or transcript state is a JSON array of 32
integers `0..255`; a SHA-256 is a lowercase hex string. There is no
whitespace.

---

## 2. `run.json`

| field | type | what |
|---|---|---|
| `schema` | str | `"hashline-native-capture/4-run"` |
| `kind` | str | `"zk60-run-verifier-observations"` |
| `coverage` | str | `"native-run-all-stages-v1"` |
| `profile`, `transcript_domain` | str | the RUN profile; equal, as in the single-block schema |
| `transcript_domain_bytes` | [u8] | the same string as bytes — the `Transcript::new` domain, so nothing is re-encoded by hand |
| `block_profile` | str | the per-block shape's profile (NOT in the run transcript) |
| `blocks` | int | `L` |
| `boundaries` | int | `L - 1` |
| `fully_verified` | bool | always `true`: a bundle exists only for a run the verifier accepted |
| `privacy`, `privacy_review_complete`, `weight_policy` | str/bool/str | `"P1"`, `false`, `"public-statement"` |
| `field_modulus`, `extension_nonresidue` | int | the field |
| `public_tables_included` | bool | whether each slot's public tables carry their `values` (see §4) |
| `source_commit` | str | `HL_TEST_SOURCE_COMMIT` or `"uncommitted-test"` |
| `run_binding` | [u8;32] | the transcript state after the run header and before any commitment |
| `context` | [u8;32] | the run's context digest (in every endpoint and boundary statement) |
| `calibration` | [u8;32] | the ONE calibration identity of the whole run (ruling M-4) |
| `public_statement_digest` | [u8;32] | `H("hashline/private-run-blocks/1" ‖ block digests)` — a RUN digest, not a block's |
| `parameter_line` | str | the exact bytes absorbed under `parameters` (the Python `PARAMETERS[profile]` literal, now data) |
| `schedule_digest` | [u8;32] | the run schedule digest |
| `expected_policy`, `expected_policy_sha256` | [u8] / hex | the endpoint policy bytes absorbed under `expected-IO` |
| `run_shape_words` | [u64;7] | `[L, tokens, width, hidden, q_heads, kv_heads, head_dim]`, absorbed little-endian under `run-shape` |
| `shape` | object | §3 |
| `external_endpoints` | object | §5 |
| `block_digests` | [[u8;32]; L] | block `k`'s public digest, absorbed under `pb-run-block` in stage `k` |
| `internal_boundaries` | [object; L-1] | §5 |
| `boundary_scales` | [i32; L-1] | ruling M-4: ONE scale per boundary |
| `stage_lines` | [str; L] | the run schedule's own stage lines (what each stage commits, which reserved pair each IO tab uses, what it opens) |
| `layout_description` | [str] | the block layout's declared schedule lines |
| `stage_files` | [str; L] | `["stage-00.json", …]` |
| `transcript_labels` | [{`label`,`what`}] | every Fiat-Shamir label, with what it carries |
| `transcript_program` | [str] | the whole transcript in words, header to trailer (§7) |
| `mask_domain` | {`log_dom`,`columns`} | the M commitment's evaluation domain (`2^12`) and opened columns |
| `plane_index` | object | **NEW in stage 15**: the committed `A` and `H` planes with their names, domains and row ranges, and the per-slot terminal push order. §3a |
| `hash_tag` | object | **NEW in stage 17**: which hash rule made this bundle. §2a |
| `not_in_a_capture` | [str] | the writer's own statement of what it never emits |

## 2a. `run.json["hash_tag"]` — which hash rule made the bundle (stage 17, D19)

Added 2026-09-20 under ruling T-1 of
`ZK60_D19_HASH_TAG_DISPOSITION.md`. Every hash on a TAGGED profile's path is
BLAKE3 in KEYED mode under one fixed public key per domain, derived from the
profile string; a LEGACY-rule profile hashes with no key anywhere, which is
what every byte to date was made under.

Under the legacy rule the member is exactly

```json
"hash_tag": {"rule": "legacy"}
```

and under the tag it is

```json
"hash_tag": {
  "rule": "blake3-keyed/1",
  "profile": "hashline-zk-mr1/private-block-rung-g-t24-dev/1",
  "contexts": {
    "transcript": "hashline-zk-mr1 2026-09-20 fiat-shamir transcript",
    "column":     "hashline-zk-mr1 2026-09-20 pcs column digest",
    "leaf":       "hashline-zk-mr1 2026-09-20 pcs salted merkle leaf",
    "node":       "hashline-zk-mr1 2026-09-20 pcs merkle inner node"
  },
  "keys_hex": {"transcript": "...", "column": "...", "leaf": "...", "node": "..."}
}
```

**What a tool must do with it.** RE-DERIVE the four keys itself, with
`blake3.blake3(profile.encode(), derive_key_context=<context>).digest()`, and
COMPARE them against `keys_hex`; a mismatch is a refusal, not a repair. The
keys are in the file only so that the comparison is possible offline; the
Python side must never take a key from a bundle and use it. Nothing in a
capture SELECTS a rule for anyone: a verifier derives its tag from the
profile it trusts (ruling T-7).

**Which profiles are which.** The byte-frozen toy and the frozen-seam
development rung (`hashline-zk-mr1/private-block-rung-t24-dev/1`) are LEGACY,
wholly; `rung_g`, the 125M shape and every run over them are TAGGED. The two
legacy profiles are development fixtures barred by name from any privacy
statement.

**Where the keys act.** `transcript` keys `Transcript::new`, every `absorb`
and every squeeze — including the two squeezes of a segment's position tag,
which are taken from a discarded transcript CLONE that carries the key.
`column` keys each committed column's digest; `leaf` keys the salted leaf;
`node` keys every Merkle inner node. `run_binding`, `start_tag` and `end_tag`
are transcript outputs and so inherit the transcript's key with no rule of
their own. The wire format carries no tag and no receipt byte count moves.

## 3. `run.json["shape"]` — every number the gate would otherwise port

`name`, `profile`, `tokens`, `width`, `hidden`, `q_heads`, `kv_heads`,
`head_dim`, `t_pad`, `d_pad`, `h_pad`, `f_pad`, `log_cols`, `cols`
(`= 1 << log_cols`), `inv_rate`, `opened_cols` (`Q`), `f_e`, `endpoint_rows`,
`endpoint_log_n`, `endpoint_inv_rate`, `endpoint_general`, `norm_wrho`,
`wrho_s`, `slots` (`[[main, extension, degree]; 23]`), `a_groups`, `h_groups`,
`n_slots`.

At the development rung: `cols = 1024`, `inv_rate = 4` (so the PCS encoding
domain is `4096` and a Merkle path is 12 nodes), `opened_cols = 256`,
`endpoint_log_n = 10`, `endpoint_inv_rate = 4`, `endpoint_rows = 9`,
`t_pad = 32`, `d_pad = 128` (the padded plane is `4096` words, so **4 data
rows** in an IO commitment). **These are not the toy's** `log_cols 8`,
`inv_rate 8`, `ENC_COLS 2048`; the flat Python constants at
`zk60_native_jv_capture.py:38-46` and `zk60_native_mask_commit.py:99-105` must
come from here instead.

## 3a. `run.json["plane_index"]` — the plane numbering and the push order

**NEW in stage 15 (2026-09-20).** It is a property of the SHAPE, not of a
stage, so there is exactly one copy and it lives in the run file. The writer
is `hashline/src/private_block/plane_index.rs`.

**Everything in it is PUBLIC.** A plane's id, name, domain and row range and
the order in which a slot pushes its private tables are functions of the
public `Shape` and of nothing else. **No plane CONTENT is here** — not a
witness word, not a pad, not a salt, not a mask coefficient. The table says
where a plane lives and what it is called; it says nothing about what is in
it. Its keys are on the capture allow-list like every other field.

| member | what |
|---|---|
| `a_data_rows`, `h_data_rows` | the counted data rows of the `A` and `H` commitments; the plane lists tile exactly these |
| `a_planes` | one object per committed `A` plane, in plane order |
| `h_planes` | one object per committed `H` plane, in plane order |
| `slot_planes` | 23 objects `{slot, name, planes}`, the terminal push order |

`a_planes[i]` = `{id, name, domain, first_row, rows, offset, log_size}`.
`id` is `i` (the plane's own index at this shape, which is `Ids`' numbering);
`name` is the `layout.rs` constant (`A_D`, `A_X`, `A_MU8`, …), with an index
appended inside a group whose length moves with the shape (`A_NR0 … A_NR3`,
`A_SR0 … A_SR2`, `A_PL0`, `A_MR*`, `A_MS*`, `A_NS*`, `A_SG*`); `domain` is
one of `T, Ht, L, D, Q, Kv, S, F, Tab`; `first_row`/`rows` is the plane's row
range and `offset = first_row * cols` is the element offset a slot's
`tables[i].slices[].offset` is measured in; `log_size` is the plane's OWN
domain log (a slot may read it on a coarser cube, and that slot's own
`log_size` says so — `SC_TZC` reads the limb planes at `log(Dom::T)`).

`h_planes[i]` = `{id, name, domain, rows, re_first_row, im_first_row,
re_offset, im_offset, log_size}`. An `H` plane is `Fp2`-valued and therefore
TWO equal runs of rows, the `re` half then the `im` half; `rows` is the
length of ONE half. The names are `H_L0`, `H_D0 … `, `H_Q0 … `, `H_KV0 … `,
`H_S0 … `, `H_SEXP`, `H_F0 … `, `H_FACT`, `H_GU8`, `H_GEXP`, `H_GACT`, `H_U`.

`slot_planes[s].planes[j]` = `{role, id, name}` — **the plane whose
evaluation the slot's `terminals[j]` is**, in the order the prover pushes
them. `role` is `A`, `H`, `Input` or `Output` (the same four names the
openings use); `id` indexes `a_planes` / `h_planes`, and is `null` for the two
IO commitments, whose `name` is then `IO_IN` / `IO_OUT`. So
`len(slot_planes[s].planes) == len(arguments[s].terminals)` in every stage,
and the `j`-th private table of `arguments[s].tables` is the `j`-th entry
here.

A plane read on a SUB-SLICE or at a flipped coordinate appears AGAIN at its
own position, because the terminal is another evaluation of the same
committed plane: `SC_TZC` lists `A_LIMB` nine times and `A_LIMBM` nine times
(the eighteen limb sub-planes), `SC_DZC` lists `A_D` and `A_DM` a second time
(their `Dom::T` slices), `SC_SZC` lists `A_MX` and `A_SUM` (their `Dom::Ht`
slices) and `SC_QZC` / `SC_KVZC` list `A_Q8` / `A_K8` a second time (the RoPE
partner at the flipped bit). The `slices[].offset` of the stage file, against
this table's `offset` and `rows`, says which evaluation it is.

**What makes the table trustworthy.** It is derived in its own module from
`layout.rs` and `shape.rs`, independently of `argument.rs`, and it is then
checked against four things, each of which refuses:

1. every plane's domain, against `Ids::dom` / `HIds::dom`;
2. the row ranges: the `A` planes must tile `[0, a_data_rows)` and each `H`
   plane's two halves must tile `[0, h_data_rows)`, with no gap and no
   overlap;
3. the per-slot `A` / `H` / IO counts, against `Shape::claim_sites`;
4. **the ACTUAL private-table sequence of every slot of every stage of the
   captured run** (`run_capture::slot`), located by role and slice offset. A
   capture is refused if one slot of one stage differs, and `stage_begin`
   rebuilds the whole table from each stage's own layout and refuses if it is
   not the run's.

At the development rung: **83 `A` planes tiling 377 rows** and **52 `H`
planes tiling 470 rows** (the rung's third `sigma_s` limb adds two `A` planes
and one `S` helper to the toy's 81 / 51, and the `Dom::D` helper block keeps
its 19). `h_data_rows = 470` is the same 470 as `roles["H"].data_rows`, and
468 of those rows carry `kind: "data"` — see §4c. Read every number from the
file, never from this sentence.

## 4. `stage-NN.json`

| field | type | what |
|---|---|---|
| `schema`, `kind` | str | `"hashline-native-capture/4-run"`, `"zk60-run-stage-observations"` |
| `stage`, `blocks` | int | `k`, `L` |
| `block_digest` | [u8;32] | `= run.json["block_digests"][k]` |
| `segment_bytes`, `segment_sha256` | int / hex | the segment the verifier read |
| `start_tag`, `end_tag` | [u8;32] | the segment's header and trailer transcript-position tags. **Outside the Fiat-Shamir chain**: the verifier COMPARES them against its own position and never adopts them (ruling M-6) |
| `boundary_committed` | null \| {`boundary`,`root`,`rows`,`log_cols`} | the boundary this stage commits, absorbed under `B` before any challenge of either adjacent equality slot. `null` in the last stage |
| `a_root`, `a_rows`, `h_root`, `h_rows`, `mask_root`, `log_cols` | | the three block commitments, exactly as absorbed |
| `logup_challenges` | [Fp2;3] | `beta, gamma, alpha`, drawn between `M` and `H` |
| `layout_digest` | [u8;32] | this stage's `Layout::schedule_digest()` (the stage layout has the two IO tabs pointed at this stage's reserved pairs) |
| `opening_order` | [str] | the openings of this stage in transcript order: `["M","A","H","Input"]`, and `["M","A","H","Input","Output"]` in the last stage |
| `header` | {`state`,`next`} | the transcript position at the START of the stage, before `pb-run-stage` is absorbed |
| `arguments` | [object; 23] | one per slot, §4a |
| `mask` | object | §4b |
| `roles` | [object] | one per opening after M, in `opening_order`, §4c |
| `transcript_sites` | [{`stage`,`site`,`before`,`after`}] | the ordered index of this stage's sites, `slot 00 … slot 22`, `M opening`, `A opening`, `H opening`, `Input opening`, `Output opening` |

A transcript position is always `{"state": [u8;32], "next": [u64,u64]}` — the
32-byte state and the Fp2 challenge that WOULD be drawn next, exactly as the
single-block schema writes it.

### 4a. `arguments[s]` — one slot

Every field of the single-block schema, unchanged: `slot`, `name`, `kind`
(`Private` / `Host` / `Standalone`), `main`, `extension`, `degree`,
`definition_challenges`, `c`, `scalar`, `claimed_sum`, `rho`,
`sumcheck_final`, `mask_eval`, `terminal_polynomial`, `terminals`, `rounds`,
`hosted` (`[{slot, coefficient}]`), `tables`, `before_definition`, `before`,
`after`.

`main`, `extension` and `degree` are **the stage's shape's**, read from the
slot definition, not from the toy's `SLOTS` literal. `tables[i]` is one of

* `{"kind":"eq","start":int,"point":[Fp2]}`
* `{"kind":"public","len":int,"sha256":hex}` — and `"values":[Fp2]` only when
  the capture was written with `HL_RUN_CAPTURE_PUBLIC_TABLES=1`. **This is the
  one place the run schema carries LESS than the single-block one.** A public
  table is a function of the public statement and the stage's challenges, and
  at the rung the 23 public cubes dominate a bundle; the digest pins the
  values a re-derivation must reproduce. `run.json["public_tables_included"]`
  says which form a bundle is in.
* `{"kind":"private","role":str,"claim":int,"log_size":int,"mask_row":int,"extension_round":int,"slices":[{offset,coefficient}],"coordinates":[{rho|flip|fixed}]}`
  — `role` is one of `A`, `H`, `Input`, `Output` and names **the claim site**,
  so slot 21's private IO table says `"Input"` and slot 22's says `"Output"`
  even when the commitment behind them is an internal boundary.

**`claim` is the index inside THIS STAGE's claim list for that role, not
inside the commitment's** (stage 15, recorded after the run privacy gate
found it; a documentation fix, nothing in the writer changed). The index is
`acc.claims[role].len()` at the moment the slot runs, and `acc` is the
stage's accumulator: `hashline/src/private_block/run_capture.rs:509` computes
it and `:520` writes it. Every stage has its own `Acc`, so **every IO table
of a run carries `claim: 0`**, including stage `k+1`'s slot 21, whose claim is
index **1** of the boundary commitment it discharges. A tool that trusted this
field would attribute both of a boundary's claims to claim 0. Take the claim
index for an IO commitment from `internal_boundaries[].claim_sites` /
`roles[].claim_sources` instead, and cross-check it against the table's
`mask_row` (site 0 at `data`, site 1 at `data + 2`). For `A` and `H` the
field means what it says, because those commitments are the stage's own.

### 4b. `mask` — the M commitment's one opening

`root`, `specs` (`[[n_vars, degree]; 23]`), **`rows`** (`2*slots + 4`, NEW and
explicit), `theta`, `proximity_rhos`, `before`, `after`, `functionals`
(`[{value, terms:[{slot, weights}]}]`), `q`, `prox`, `columns`.

### 4c. `roles[i]` — one hiding commitment's one opening

Single-block fields, unchanged: `role`, `params`
(`{log_cols, inv_rate, num_col_checks}`), `commitment` (`{root, rows}`),
`before`, `after`, `claims` (`[{value, parts:[{offset, log_size, coefficient,
point}]}]`), `groups` (`[{members, lambdas, key:{tail, offset, len},
vector}]`), `proximity_rhos`, `proximity_vector`, `columns`
(`[{index, values, salt, path}]`), `q_pad`, `row_roles`
(`[{row, kind, site}]`), `public_linear_constraints`.

NEW, and the reason the Python side needs no ported layout:

| field | what |
|---|---|
| `commitment_kind` | `"block"` (A, H), `"external-endpoint"`, `"internal-boundary"` |
| `boundary` | which internal boundary this opening discharges, else `null` |
| `data_rows` | rows carrying plane or witness words |
| `site_rows` | every reserved claim-pair row, first row of each pair first |
| `prox_row` | the first row of the proximity PAIR |
| `sum_rows` | `H`'s two zero-sum rows (`null` elsewhere) |
| `claim_sources` | `[{stage, slot, claims}]` in claim order — WHICH BLOCK AND SLOT raised each claim of this opening. For a boundary: `[{stage k-1, slot 22, n}, {stage k, slot 21, m}]` |

`row_roles[].kind` is `"data"` (row `< data_rows`), `"prox"` (the proximity
pair) or `"mask"` (everything else, including `H`'s zero-sum rows, the
reserved claim pairs, and an endpoint's spare mask row). The single-block
writer labelled an endpoint's rows `data+2 … data+4` all `"prox"`; here only
the proximity PAIR is `"prox"`, which is what `pcs::OpeningZk`'s own
`prox_mask_row` says. Use the explicit `data_rows` / `site_rows` / `prox_row`
/ `sum_rows` fields rather than the `kind` strings where it matters.

**`H`'s `data_rows` COUNTS the two zero-sum rows and `row_roles` does not**
(stage 15, recorded after the run privacy gate found it; nothing in the
writer changed). `H`'s `data_rows` is `Layout::h_data_rows`
(`hashline/src/private_block/protocol.rs:893`), which is the sum over every
`H` plane of `2 * rows_of(domain)`
(`hashline/src/private_block/layout.rs:1042`) — and the zero-sum masking pair
`u` IS one of those planes
(`hashline/src/private_block/shape.rs:490`, the last entry of
`Shape::h_plane_doms`). `row_roles` labels those same two rows `"mask"`,
because `row_kind` tests `sum_rows` FIRST
(`hashline/src/private_block/run_capture.rs:884-894`). So for `H` the count
of rows with `kind: "data"` is `data_rows - 2`, and the two missing rows are
exactly `sum_rows`. Neither number is wrong: `data_rows` is where the
committed planes end, `row_roles` is what each row is FOR. Split data from
non-data with `row_roles`, as the toy tool does, and check the difference is
`sum_rows`.

## 5. The endpoints and the boundaries

`external_endpoints`: `input_root`, `output_root`, `rows`, `data_rows`,
`log_n`, `inv_rate`, `input_scale`, `output_scale`, `opened_at_stage`
(`[0, L-1]`). The run's two external endpoints keep today's `endpoint_g`
geometry unchanged (ruling M-7): `data + 5` rows, one claim site at
`(data, data+1)`, proximity pair `(data+2, data+3)`.

**An external endpoint has one SPARE mask row and a derived boundary has
none** (stage 15, recorded after the run privacy gate found it; nothing in
the writer changed). `MASK_ROWS = 5`
(`hashline/src/private_block/endpoint_g.rs:51`) and the assignment is the
frozen seam's, word for word: the claim pair at `data, data+1`, the proximity
pair at `data+2, data+3`
(`hashline/src/private_block/endpoint_g.rs:205-206`) — leaving `data+4`
masked, committed, published in no `site_rows` and used by nothing. That is
ruling M-7's "a pair, a proximity pair and a spare". A boundary's row count
is DERIVED as `data + 2*sites + 2`
(`hashline/src/private_block/boundary.rs:161`, site rows at `:166`,
proximity row at `:170`), so it has exactly `site_rows ∪ {prox, prox+1}` and
no spare at all. At the rung: an endpoint is 9 rows with `site_rows = [4,5]`,
proximity `(6,7)` and the spare `8`; a boundary is 10 rows with
`site_rows = [4,5,6,7]` and proximity `(8,9)`. Report `spare_mask_rows` per
opening; do not expect the two commitment kinds to agree.

`internal_boundaries[k]`, one per internal boundary:

| field | what |
|---|---|
| `boundary` | `k`, `0 … L-2` |
| `index` | `k+1`, the index inside the boundary's own statement digest |
| `scale` | the ONE shared scale (ruling M-4) |
| `sites` | 2 |
| `plane` | `[t_pad, d_pad]`, the padded hidden plane this boundary commits |
| `data_rows`, `rows`, `site_rows`, `prox_row` | the DERIVED geometry |
| `row_rule` | `"data + 2*sites + 2"` — ruling M-1: the row count is derived from the plane and the site count, never accepted from a caller. A single-proximity-row boundary (`data + 2*sites + 1`) has joint rank 5 of 6 on its reserved rows and is refused by name |
| `log_n`, `inv_rate`, `checks` | the boundary's PCS parameters |
| `statement_digest` | the boundary statement's own digest |
| `committed_at_stage` | `k` |
| `opened_at_stage` | `k+1` — the commitment is opened EXACTLY ONCE, and only there, because its second claim does not exist until then |
| `claim_sites` | `[{site:0, stage:k, slot:22, first_row}, {site:1, stage:k+1, slot:21, first_row}]` |
| `opening_in_stage_file` | `k+1`: the opening's payload is `stage-{k+1}.json["roles"]`'s `"Input"` entry |

At the rung-G plane: `data_rows = 4`, `sites = 2`, so `rows = 10`,
`site_rows = [4,5,6,7]` (site 0 at `(4,5)`, site 1 at `(6,7)`), `prox_row = 8`
(the pair `(8,9)`).

## 6. How the three roles of a boundary plane meet (what the M-8 gate needs)

Ruling M-8 asks for the joint rank of **block `k`'s activation commitment, the
boundary commitment, and block `k+1`'s activation commitment**, restricted to
the reserved mask rows. Everything needed to identify the three is in one
place:

* Block `k`'s output-equality slot is `stage-{k}.json["arguments"][22]`. Its
  two private tables are `role "A"` (block `k`'s activation commitment) and
  `role "Output"` (the claim site on the boundary).
* Block `k+1`'s input-equality slot is `stage-{k+1}.json["arguments"][21]`,
  with private tables `role "A"` and `role "Input"`.
* Both claims are discharged by ONE opening:
  `stage-{k+1}.json["roles"]` entry with `"commitment_kind":"internal-boundary"`
  and `"boundary": k`. Its `claim_sources` says, in claim order, which stage
  and slot raised each claim; its `claims[].parts[].point` are the two
  evaluation points; its `site_rows` are the two reserved pairs.

So the existing `discover_shared_rows` pattern (a slot with exactly two
private tables, one of them `"A"`) fires **twice** for one boundary — once in
stage `k` and once in stage `k+1` — and the union-find merges
`A_k[row] ~ Boundary_k[row] ~ A_{k+1}[row]` provided the tool knows that stage
`k`'s `"Output"` site and stage `k+1`'s `"Input"` site are the SAME
commitment. That fact is `claim_sources` (and `internal_boundaries[].claim_sites`);
it cannot be inferred from the role names alone.

The two controls the ruling names are checkable from the same fields: the
**shared-pair** control is `site_rows` — the two sites must use DISJOINT
adjacent pairs (`[4,5]` and `[6,7]`), and the claim audit refuses a shared
pair; the **single-proximity-row** control is `row_rule` with `prox_row` and
`rows` — a boundary must have a proximity PAIR, `rows = data + 2*sites + 2`.

## 7. The transcript, and what a replay must do

`run.json["transcript_program"]` states it in words and
`run.json["transcript_labels"]` gives every label. In short:

```
Transcript::new(transcript_domain_bytes)
absorb run-shape(run_shape_words, u64 LE) ; expected-IO(expected_policy)
absorb public-statement ; parameters(parameter_line) ; calibration ; schedule
-> the state here is run_binding
for k in 0..L:
    absorb pb-run-stage(k) ; pb-run-block(block_digests[k])
    if k+1 < L: absorb B(root) ; rows ; log-cols          # boundary k
    absorb A(root) ; rows ; log-cols ; M(mask_root)
    draw 3 Fp2 = logup_challenges
    absorb H(root) ; rows ; log-cols
    for s in 0..23:  (the block family's own slot transcript, unchanged)
        draw len(definition_challenges) ; absorb pb-slot(s) ; draw c
        absorb pb-scalar ; per round absorb sc-round then draw ; absorb pb-term
    M:  draw theta ; absorb mask-q(q) ; draw 2*23+2 ; absorb mask-prox(prox)
        draw 256 indices over 2^12
    then one PCS opening per role in opening_order[1:]:
        per group draw |members| lambdas ; draw `rows` proximity coefficients
        absorb pcs-vec per group ; absorb pcs-prox ; draw Q indices over cols*inv_rate
```

The Rust recorder does exactly this, from a transcript it seeds itself out of
the run statement's public words, and compares its own state with the
verifier's at every site; the first mismatch aborts the capture and no bundle
is written. A Python replay can do the same and should refuse on the first
mismatch, comparing both `state` and `next` at every recorded position.

## 8. What is deliberately NOT in a capture

Witness values; pad values; mask coefficients; unopened columns; unpublished
salts; unmasked sumcheck rounds; the hidden input, the hidden output and every
boundary plane; prover randomness; the `L-1` boundary ROOTS as part of the
STATEMENT (they are in the stage files as observed commitments, because an
internal boundary is a hidden intermediate and not an endpoint).

Also not in a capture, and not a privacy matter: each slot's polynomial
`def.poly` (a Rust closure — absent from the single-block capture for the same
reason, which is why `zk60_native_terminal_polys.py` hand-ports them), and the
public table VALUES unless asked for.

## 9. What the Python agent must change first

From a read of the current loader (`zk60_native_jv_capture.py`,
`zk60_native_jv_replay.py`, `zk60_native_jv_pcs.py`, `zk60_native_jv_joint.py`,
`zk60_native_mask_commit.py`, `zk60_native_terminal_polys.py`,
`zk60_native_privacy_gate.py`):

1. **Accept the new schema.** `Capture.__init__` refuses on `schema != 3`,
   `kind`, `coverage` and `profile not in PARAMETERS`. A run bundle needs its
   own loader: `run.json` once, then one `Capture`-like object per stage file.
2. **Stop porting the shape.** `LOG_COLS`, `N_COLS`, `INV_RATE`, `ENC_COLS`,
   `NUM_COL_CHECKS`, `Q_PAD`, `MASK_LOG_DOM` are toy literals at
   `zk60_native_jv_capture.py:38-46` (and again in
   `zk60_native_mask_commit.py:99-105`). Take them from `run.json["shape"]`
   and `run.json["mask_domain"]`; `params` and `q_pad` are also in every
   opening. At the rung they are 10 / 1024 / 4 / 4096 / 256 / 256 / 12.
3. **`PARAMETERS[profile]` is now data.** Use `parameter_line` and
   `transcript_domain_bytes` rather than a new literal; `calibration` is the
   digest itself, so no `CALIBRATION_PREIMAGE` entry is needed.
4. **The header is a RUN header.** `run-shape` comes FIRST, before
   `expected-IO`; `public-statement` is the run's digest over the `L` block
   digests. Then per stage the two new locality words and, before the A root,
   the boundary root.
5. **`ROLE_ORDER` is per stage.** Read `opening_order`: `M, A, H, Input` in
   every stage but the last, which adds `Output`. `ENDPOINT_ROLES`,
   `EXPECTED_PCS` and `privacy_gate.pcs_roles` keep the same four names, but
   an `Input` opening whose `commitment_kind` is `"internal-boundary"` is a
   different commitment from the external one and must be kept apart by
   `(stage, boundary)`, not by role name.
6. **The joint view is now run-wide.** §6. The per-boundary identification is
   `claim_sources` / `internal_boundaries[].claim_sites`, not the role names.
7. **Re-pin the sources.** `SOURCE_PINS` in `zk60_native_terminal_polys.py`
   and `zk60_native_mask_commit.py` pin the toy's files; a run bundle carries
   its own pins in `manifest.json["source_pins"]` (this writer, `run.rs`,
   `boundary.rs`, `protocol.rs`, `argument.rs`, `layout.rs`).

   **STAGE 24 (2026-09-21): `source_pins` grows from 8 entries to 15, and
   nothing else about a bundle moves.** Round 6 of the native run gate
   (`ZK60_NATIVE_RUN_GATE.md` §10.2, §10.8) found that its pin mechanism is
   bundle-side — a gate can pin a file only if the WRITER pins it — and that
   four files on the run's own path were in no bundle's `source_pins`:
   `wire.rs`, `run_sink.rs`, `endpoint_g.rs` and `hash_domain.rs`. No port
   depends on any of them today, which is exactly the fact that would stop
   being true if a port grew. `run_capture.rs::SOURCE_FILES` now lists the
   whole of the run's path, enumerated from the modules the run prover and
   verifier reach: the eight it had, those four, and three the enumeration
   itself turned up — `src/private_block.rs` (the PARENT module, where
   `ExpectedIo::to_bytes`, `IoSpec` and `calibration_identity` live, so the
   run header's own absorbed bytes come from it), `witness.rs` and `pad.rs`.
   The one production module deliberately left out is `timing.rs`, named with
   its reason in `NOT_ON_THE_RUNS_PATH` (the phase clock is write-only and
   decides no byte), and
   `s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on`
   asserts that the two lists partition the module list parsed from
   `private_block.rs`, so a module added later cannot slip through
   undecided.

   **THE SCHEMA NAME DOES NOT MOVE, because this is a PURE ADDITION.**
   `manifest.json["source_pins"]` is a list of `{"file", "sha256"}` objects;
   the change adds entries to that list and touches no field, no field order
   and no existing entry, so a loader written for the eight-entry list reads
   a fifteen-entry one unchanged. **The ten committed bundles are NOT
   re-taken and are not edited**: each still carries, and its own
   `manifest.json` still pins, the eight-entry list it was written with. Only
   bundles taken after this change carry the longer list.
8. **The slot port table is shape-dependent.** `BLOCK_PORTS` and the `_Layout`
   namespace in `zk60_native_terminal_polys.py` are the toy's `T=32, D=16,
   H=2, DH=8, F=16, LOG_N=8, N=256`. The slot COUNT, names, kinds and table
   push order do not move at the rung; the geometry constants do, and every
   one of them is in `run.json["shape"]`.
9. **STAGE 15: `_Layout`'s plane numbering is now data too.** The gate's one
   missing field is `run.json["plane_index"]` (§3a): every committed `A` and
   `H` plane with its id, name, domain and row range, and per slot the
   ordered plane list its `terminals` evaluates. Read the plane numbering,
   the row ranges and the push order from there instead of porting them, and
   the per-slot terminal identity can be closed at the rung. Two facts the
   same revision wrote down rather than changed, each of which a tool can get
   wrong silently: an IO table's `claim` is per STAGE and is always 0 (§4a);
   `H`'s `data_rows` includes the two zero-sum rows and `row_roles` does not
   (§4c); and an external endpoint has one spare mask row while a boundary
   has none (§5).

## 10. The bundles

Written by `private_block::run_capture_tests::write_the_gate_bundles`
(`#[ignore]`d; `HL_RUN_CAPTURE_DIR` chooses the directory). Two independent
honest three-block rung-G runs, fresh OS randomness each, synthetic public
weights from the lane's tame fixture, one on the fixture's hidden input and
one on the all-zero hidden input. Neither hidden input is in its bundle.
About 38.5 MB each without the segments.

**Four bundles now, in `results/zk60_run_captures_20260920/`.**
`run-c-tame` and `run-d-zero` (stage 15) carry the plane index table and are
the ones to read. `run-a-tame` and `run-b-zero` (stage 14) PREDATE it and are
otherwise identical in format; they are kept exactly as they were, and their
per-bundle `README.md` is not edited because each `manifest.json` pins it by
length and SHA-256. The parent `README.md` of that directory says which is
which. **The four are FOUR DIFFERENT RUNS**: fresh randomness means fresh
receipts, so `run-c-tame` is not `run-a-tame` with a field added, and no byte
of one bundle should be compared with a byte of another except the plane
index table itself, which is a function of the shape and IS equal.

**STAGE 18: two TAGGED bundles, with the public tables' values.**
`run-e-tame-tagged` and `run-f-zero-tagged`, written by
`private_block::run_capture_tests::write_the_tagged_gate_bundles`
(`#[ignore]`d; `HL_RUN_CAPTURE_DIR` chooses the directory, and the test
REFUSES unless `HL_RUN_CAPTURE_PUBLIC_TABLES=1` is set). They exist because
stage 17's D19 tag moved every proof byte of the two tagged profiles — so
`run-a-tame` … `run-d-zero` are legacy-rule bundles and are not evidence
about what the code produces now — and because the run gate could close only
twelve of its twenty-three per-slot terminal checks without the public
tables' values. `run.json` carries `"hash_tag":{"rule":"blake3-keyed/1",…}`
and `"public_tables_included":true`; everything else is the format above,
unchanged. **Re-derive the four keys from the contexts and the profile and
COMPARE; never take a key from a bundle** (§2a, ruling T-7).

**STAGE 20: THE SIX EXISTING BUNDLES ARE LEGACY IN ONE MORE WAY.** The
repair of finding S19-F1 (lane `zk60-private-block-125m`, stage 20) changes
the two BILINEAR attention slots at every profile with more than one
key-value head — every shaped profile, the toy excepted. In a capture of such
a profile:

* `arguments[8]` (`10 score matmul`) and `arguments[9]` (`11 PV matmul`) have
  `main` raised by `log2(kv_heads)` and `degree` raised from 2 to 3, so their
  `rounds` arrays are longer and each round message carries one more value.
  `shape.slots` reports the new triples, as it always did — nothing in this
  format is a literal.
* each of those two slots' `tables` gains ONE entry, at position 0:
  `{"kind":"eq","start":0,"point":[…]}` over the key-value GROUP bits, which
  are the leading `log2(kv_heads)` entries of the slot's head challenge. The
  PRIVATE tables are unchanged in number, in order and in role, so
  `plane_index.slot_planes[8]` / `[9]` and `arguments[*].terminals` do not
  move, and the rule `len(slot_planes[s].planes) == len(terminals)` still
  holds — it counts private tables only.
* every segment therefore grows by the counted per-block delta (336 B at
  both rungs, 560 B at 125M), and so does every `receipt_bytes` figure.

A capture taken before stage 20 at a shaped profile is not evidence about
what the code produces now. The toy is unaffected: `kv_heads = 1` leaves the
group empty, no table is pushed and no byte moves.

**STAGE 21 (2026-09-20): two bundles TAKEN UNDER THE REPAIRED ARGUMENT, one
of them on a NON-DEGENERATE witness.** `run-g-dense-s20` and
`run-h-zero-s20`, written by
`private_block::run_capture_tests::write_the_s20_gate_bundles` (`#[ignore]`d;
`HL_RUN_CAPTURE_DIR` chooses the directory, `HL_RUN_CAPTURE_PUBLIC_TABLES=1`
is required). They supersede `run-e-tame-tagged` / `run-f-zero-tagged` for
gate purposes, for the reason above: those two predate the repair, so at
rung-G every one of their segments is 336 B per block short of what the code
produces and their `arguments[8]` / `arguments[9]` carry the pre-repair
schedule.

**`run-g-dense-s20` is the one that matters.** Every capture before it was
taken on the diagonal tame fixture or on the all-zero input, and BOTH are
degenerate in exactly the way that hid finding S19-F1 for nineteen stages:
the hidden state is the same in every head, the key-value groups carry the
same data, the upper hidden half `[d, f)` of every `Dom::F` plane is
identically zero and `A_RQL` is identically zero. `run-g-dense-s20` is a
FULLY DENSE run — no zero entry in any of the nine public words, a
non-constant hidden input, the upper hidden half live and the two key-value
groups carrying different data in every block. **The privacy gate has never
seen a non-degenerate witness; this is it.** `run-h-zero-s20` keeps the
all-zero input, which is the fixed input the privacy case is stated at.

**THE GROUP `eq` NEEDS NO NEW FIELD, and that is checked in the writer
before anything is written.** `Tab::Eq` already serialises as

```
{"kind":"eq","start":int,"point":[Fp2]}
```

so in `run-g-dense-s20` / `run-h-zero-s20`, `arguments[8]["tables"][0]` and
`arguments[9]["tables"][0]` are each `{"kind":"eq","start":0,"point":[…]}`
with `lkv = log2(kv_heads) = 1` point entry at rung-G. **How a tool
re-derives it, which is the only legitimate use:** `start` is an index into
the slot's own `rho`, so the factor's value at the sumcheck's end is
`eq(point, rho[start .. start + len(point)])`; and `point` itself is the
LEADING `lkv` entries of that slot's head challenge `r_h`, which the tool
draws for itself from `definition_challenges` (slot 08 draws `r_h`, `r_t`,
`r_j` in that order; slot 09 draws `r_h`, `r_t`, `r_i`). It is a
VERIFIER-COMPUTED table: re-derive and compare, never consume — the same
rule as the hash-tag keys (§2a, ruling T-7).

`plane_index.slot_planes[8]` and `[9]` are unchanged and still list exactly
two planes each, in the as-built push order (`[A_QR8, A_KR8]` and
`[A_P, A_V8]`): the group `eq` is PUBLIC, and the plane index lists only
`Tab::Priv` tables. The recorder's replay enforces that order against the
index at every slot of every stage, so the bundle could not be written if it
had drifted. `len(slot_planes[s]) == len(terminals)` therefore still holds.

**STAGE 22 (2026-09-20): two bundles at a shape with TWO GROUP BITS.**
`run-i-dense-k4` and `run-j-zero-k4`, written by
`private_block::run_capture_tests::write_the_k4_gate_bundles` (`#[ignore]`d;
same two environment variables). They do NOT supersede `run-g-dense-s20` /
`run-h-zero-s20` — they are a DIFFERENT SHAPE, and both pairs are current.

**Why a reader needs them.** Everything above about the group `eq` is
written at `lkv = 1`, because until stage 22 every bundle at every stage was
at one key-value group bit (rung-G) or none (the toy). A port that read
`point[0]` and stopped, or that assumed the group sum has two terms, would
have passed every check ever run. `Shape::rung_k4` is rung-G's geometry with
the heads recut as **12 query heads of 8 over FOUR key-value heads**, padded
head slots `{3, 7, 11, 15}` — 125M's own head geometry — so `lkv = 2`, the
group sum has FOUR terms and

```
arguments[8]["tables"][0] == {"kind":"eq","start":0,"point":[<TWO Fp2>]}
arguments[9]["tables"][0] == {"kind":"eq","start":0,"point":[<TWO Fp2>]}
```

in all three stages of both bundles, with `point == definition_challenges[:2]`
at all six occurrences (checked on the files after the write). Everything
else in this format is unchanged; nothing was added for them.

**What a tool must NOT do with them.** They are a different profile
(`hashline-zk-mr1/private-block-rung-k4-t24-dev/1` for the block,
`…/private-run-rung-k4-t24-dev/1` for the run), so they have their OWN
hash-tag key set — re-derive it from the contexts and THIS block profile
(§2a) — and their own plane index table: 83 `A` planes over **481** rows and
52 `H` planes over **614** rows, 22,419 canonical bytes, SHA-256 prefix
`89cd8a46…`, against rung-G's 377 / 470 and `d2361312…`. The two tables are
equal across `i` and `j` and must never be compared with rung-G's. Slots 08
/ 09 are `(5, 2, 3)` and `(7, 2, 3)` here, 7 and 9 round messages of 4
values, 2 terminals each; `slot_planes[8]` / `[9]` are the same two-plane
lists as at rung-G. One block's receipt is 4,743,128 B and a three-block
run's segments are 4,575,304 / 4,597,832 / 4,765,736 B.

Development grade (ruling P-7); no privacy claim, and no gate has read them.

## 11. A DIFFERENT artifact: the public run statement (stage 18)

Not a capture and not in a bundle. A run leaves `L` segment files in its run
directory; the SEGMENTS are the proof and they are not the STATEMENT, so
until stage 18 a run's 484 MB of receipt could not be checked by any process
but the one that proved it. `hashline/src/private_block/run_statement_file.rs`
retains the public statement beside them:

```
<run dir>/segment-000.bin … segment-(L-1).bin   (bytes and names unchanged)
<run dir>/statement/run-statement.json
```

`run_sink::segment_paths` allows exactly that one extra entry, which must be
a DIRECTORY; every other foreign entry is refused before a byte of a segment
is read, as before. Schema `hashline-private-run-statement/1`; one top-level
member per line, every digest lower-case hex.

It carries ONLY what the verifier already takes as its public statement: the
run and block profiles, `L`, the shape numbers, the run-shape words, the
context, the two external endpoint commitments with their scales and the
endpoint policy bytes, the `L` block digests, the block and boundary scales,
the calibration identity, the derived public-statement digest / parameter
line / schedule digest / run binding, the stage lines, the hash tag, the
`L-1` internal boundaries' public facts and statement digests, and the `L`
segment files' names, lengths and SHA-256. **The public weights are NOT
dumped**: the file names a deterministic RECIPE and the reader regenerates
them and checks them against the block digests. A reader rebuilds a
`RunStatement` from the file plus its own shape and recipe, recomputes every
derived member and refuses by name on any mismatch, then verifies the run
from the segments in a fresh `RunVerifier`.

**Ruling D21**: `verify_then_write` is the only writer and it verifies the
whole run first, so a failed run leaves no statement file and no `statement/`
directory. The full member list, and the trace of each member to the line of
`run.rs` at which the verifier consumes it, is in the stage 18 section of
`ZK60_BLOCK125M_LANE_PROGRESS.md`.
