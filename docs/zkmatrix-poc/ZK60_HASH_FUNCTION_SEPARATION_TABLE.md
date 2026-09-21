# The hash functions of the private block, and what separates each pair

Work-list item **W-5** of `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §8,
written by the lane `zk60-private-block-125m` on 2026-09-21 (stage 25).

**What this is.** A list of every distinct hash FUNCTION the private block
and the private run call, and, for every pair of them, the MODEL under which
the two are different functions — length, a fixed literal inside the input,
BLAKE3's mode, or a key — together with the line where each is constructed
and the test that pins it, or the words **pinned by nothing**.

**What this is not.** It is not a privacy claim, not a soundness claim and
not an acceptance of anything. It says which separations the code has and
which of them a test watches. Two of the rows say that a pair is separated
by nothing at all; one says that a pair is not a separation question but an
AGREEMENT question. Those are the honest answers and they are written as
such.

Every line number is at the lane tip `5758b95` unless it says otherwise.

---

## 1. The functions

A "function" here means one BLAKE3 instance: the same mode AND the same key.
Two calls to the same function on different inputs are two queries to one
oracle; two calls to different functions are queries to two.

| id | function | mode and key | where it is constructed | who uses it |
|---|---|---|---|---|
| **F_U** | the unkeyed hash | `blake3::Hasher::new()` / `blake3::hash` | `zkp-core/src/transcript.rs:30`, `zkp-core/src/rng.rs:54`, `private_block.rs:229`, `:520`, `layout.rs:1289`, `run.rs:221`, `:286`, `endpoint_g.rs:158`, `boundary.rs:211`, `private_seam.rs:116` | at a LEGACY profile: everything. At a TAGGED profile: the generator's refill and the statement digests D1 … D8 only |
| **F_T** | the transcript function | keyed, `tag.transcript_key()` | `zkp-core/src/transcript.rs:41` (`Transcript::new_tagged`), through `protocol::tagged_transcript` | the constructor, every absorb, every squeeze, the position tags and the refusal replay, at a tagged profile |
| **F_C** | the column-digest function | keyed, `tag.column_key()` | `zkp-core/src/pcs.rs:149`, `:196`; `hashline/src/zk.rs:697` | every committed column's digest at a tagged profile |
| **F_L** | the salted-leaf function | keyed, `tag.leaf_key()` | `zkp-core/src/pcs.rs:692` | `leaf = H(column digest ‖ salt)` at a tagged profile |
| **F_N** | the Merkle-node function | keyed, `tag.node_key()` | `zkp-core/src/merkle.rs:28` | `node = H(left ‖ right)` at a tagged profile |
| **R1** | the generator's seed derivation | keyed, **key = 32 raw `/dev/urandom` bytes** | `zkp-core/src/rng.rs:47` | once per generator: `protocol.rs:486`, `run.rs:516`, `endpoint_g.rs:224`, `private_seam.rs:196` |
| **K** | the tag-key derivation | **`derive_key`**, BLAKE3's third mode | `zkp-core/src/hashtag.rs:95-98` | four calls per tagged profile, over the profile string, under the four contexts |
| **C1** | the capture writer's digest | **SHA-256 (`sha2`), not BLAKE3 at all** | `export_v3::sha256_hex`, called from `run_sink.rs:50`, `run_capture.rs` (5 sites), `run_statement_file.rs` (5 sites) | file and public-word digests of a retained bundle; nothing it produces is absorbed |
| **G1 / G2** | two hand-written CUDA BLAKE3 column kernels | unkeyed, **a second implementation of F_U's column digest** | `hashline/src/gpu/kernels.cu:512` (`b3_hash_column`, launched `:582`) and `:1429` (`k_hash_cols_stream`) | the column hashing of `A`, `H` and the endpoints, at the two LEGACY profiles only, in a `gpu-cuda` build with `HL_GPU=1` |

**Two rules decide which of these exist.** Under the **legacy rule** (the
byte-frozen toy and the frozen-seam development rung,
`shape.rs:549-551`) there is **one** BLAKE3 function, F_U, plus R1 and
nothing else: F_T, F_C, F_L, F_N do not exist and every hash of the proof is
a query to the same oracle. Under a **tagged** profile (rung-G, rung-K4,
125M and all three runs) there are five, plus R1 and K.

---

## 2. Every pair, and the model that separates it

`A / B` means: what makes a query of kind A different from a query of kind B.
"**length**" means the two families' input lengths are disjoint and that is
all there is. "**literal**" means the inputs can be the same length and a
fixed byte string at a fixed offset inside one of them is what differs.

### 2.1 Under the LEGACY rule — one BLAKE3 function

| pair | the model that separates them | pinned by |
|---|---|---|
| transcript constructor / absorb / squeeze, against each other | **length**, and inside the absorb family the **label literal and its length prefix** at offset 32 | `s25_tests::every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length` |
| any transcript input / a column digest | **length** — no `8·rows` on a registered path meets a transcript length | the completed guard (`hash_domain::imposed_at_shape`), `hash_domain_tests::every_dangerous_row_count_is_refused_by_name_at_every_shape` |
| any transcript input / the refill (40 B) | **length** | the completed guard; `hash_domain_tests::the_shape_free_dangerous_row_counts_are_the_memos_eight` |
| any transcript input / a statement digest D1 … D8 | **length** — with the one exception in the next row | `s25_tests::every_hash_input_kind_…`, and (for the column side) `s25_tests::the_legacy_length_guard_now_carries_the_statement_digests_and_the_seed_derivations` |
| the `pb-term` absorb with SIX terminals (151 B) / the internal boundary's spec digest (151 B) | **the same length.** The absorb begins with a 32-byte transcript state, the digest with a 43-byte ASCII `DOMAIN`, so a coincidence needs a state to equal that literal's first 32 bytes — `2^-256` per absorb. **Cross-profile and cross-execution: a legacy profile has no internal boundary, so the pair is never live inside one proof.** Ruling J-7: RECORDED, not guarded | `s25_tests::the_per_slot_terminal_absorb_lengths_are_printed_and_recorded_at_every_shape` (which asserts the pair is never in one function inside one profile) |
| the `absorb "log-cols"` input (64 B) / a salted leaf or a Merkle node (64 B) | **a fixed 24-byte literal** — `le64(8) ‖ "log-cols" ‖ le64(8)` at offset 32 | `s25_tests::every_hash_input_kind_…`, where the pair is DECLARED with that literal |
| **a salted leaf / a Merkle inner node** | **NOTHING.** Both are `blake3(32 ‖ 32)` on 64 untagged bytes (`pcs.rs:678`, `merkle.rs:15`). Priced at 2^-484.83 for hiding (ruling L-7 / correction C-4); for SOUNDNESS the depth-confusion ambiguity is closed by the wire format and by ruling T-4's path-length check (`hash_domain.rs`'s `paths_are_the_tree_depth`), not by the hash | the pair is declared, by name, in `s25_tests::every_hash_input_kind_…`; the soundness half by `hash_domain_tests::a_short_or_long_merkle_path_is_refused_by_the_whole_verifier_by_name` |
| a column digest / a leaf or a node (64 B) | **length** — no commitment has 8 rows, and the guard refuses one that did | `hash_domain_tests::the_shape_free_dangerous_row_counts_are_the_memos_eight` |
| a column digest / the frozen seam's spec digest (128 B) | **length** — a 16-row commitment would collide, and since stage 25 the legacy guard refuses one BY NAME | `s25_tests::the_legacy_length_guard_now_carries_the_statement_digests_and_the_seed_derivations` |
| anything in F_U / **R1**, the seed derivation | **BLAKE3's keyed mode, under a key the adversary does not know** (convention V-2). Not a length argument at all: at the generalised endpoint R1's input is **64 bytes**, exactly the leaf and node length, twice per block | **no test, and none is possible** — it is a model statement. What IS pinned is that the key comes from the operating system and nowhere else: `s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system` |
| anything in F_U / **K**, the tag-key derivation | **BLAKE3's third mode** (`derive_key`), a different function of the same library | `zkp-core`'s `hash_tag` tests; the four contexts' lengths are re-derived in `s25_tests::the_memos_length_table_is_re_derived_from_the_code` |
| anything / **C1** | **a different hash function entirely** (SHA-256). It shares no oracle with any row above | `s25_tests::every_hash_call_site_in_the_lanes_own_sources_is_classified` names every C1 site as SHA-256; **no test asserts that it must STAY SHA-256** |
| the CPU column digest / **G1, G2** | **not a separation: an AGREEMENT.** The two CUDA kernels are meant to compute the same function on the same bytes, and they are offered the columns of `A`, `H` and the endpoints at exactly the two legacy profiles (`zkp-core/src/pcs.rs:782-785` declines the device only when a column key exists). What pins the agreement is the differential probe `dev_hash_check` (`hashline/src/gpu/cuda.rs:2783`, device call `:2795`) and the proof-byte parity gates — **not** the hash-domain argument. **Ruling J-3: a GPU-feature build with the accelerator enabled is outside what the accepted toy statement (register entry D22) covers**, until the agreement is cited to a gate by name (W-9) and the device and pinned-host buffer lifetimes are read (W-10) | **pinned by nothing on this lane.** W-9 and W-10 are open, and W-10 is another engineer's file |

### 2.2 Under the TAGGED rule — five BLAKE3 functions, plus R1 and K

| pair | the model that separates them | pinned by |
|---|---|---|
| **F_T / F_C**, **F_T / F_L**, **F_T / F_N** | **the keys.** Two different keyed BLAKE3 instances | `s24_tests::every_registered_profile_is_covered_and_every_tagged_ones_keys_are_pairwise_distinct` (twelve live keys, pairwise distinct, registry read out of the source), confirmed by `s25_tests::stage_24s_twelve_key_test_still_covers_every_tagged_profile` |
| **F_C / F_L**, **F_C / F_N** | the keys, as above | the same |
| **F_L / F_N** | **the two keys — and the model that makes a key enough is proposed decision D19b, the ideal-compression-function reading at an adversary-chosen chaining value. `PROPOSED`, not accepted.** Both inputs are 64 bytes and both are a single compression-function call; that two keyed instances of one compression function are independent at an adversary-chosen input is the assumption D19b names | the keys: the same twelve-key test. **The MODEL is pinned by nothing — it is a proposed decision** |
| **F_T inside itself** (two absorbs of equal length) | **the label literal and its length prefix at offset 32.** Live cases: the four root absorbs at 81 bytes (`A`, `H`, `B`, `M`); `expected-IO` against `parameters` at 171 bytes at the toy; and, at a rung-G or rung-K4 run with `2 ≤ L ≤ 9`, the run's `parameters` line against a 15-terminal `pb-term` absorb, both **295** bytes | `s25_tests::every_hash_input_kind_…` declares each pair with its literal; the 295 case is also recorded by `s25_tests::the_per_slot_terminal_absorb_lengths_…` |
| **F_C inside itself** (two column digests of equal length) | **length** — `A`, `H`, `M`, the external endpoint and the internal boundary have five different row counts at every registered shape | `s25_tests::every_hash_input_kind_…` |
| **F_U / anything keyed** | the mode-and-key. At a tagged profile F_U carries only the refill and the statement digests, so the 151-byte and 64-byte coincidences of §2.1 cease to be coincidences: the absorb is F_T and the digest F_U | `s25_tests::the_per_slot_terminal_absorb_lengths_…` for the 151 case |
| **R1 / F_L, F_N** at the generalised endpoint | **the mode and a secret key, and nothing else** (convention V-2). By LENGTH the seed derivation is in the leaf/node class: `22 + 42 = 64` bytes, twice per block, on the production path. This is the sharpest row in the table | **no test, and none is possible** — a model statement. The freshness of the key is pinned (see §2.1's R1 row) |
| **K / everything** | BLAKE3's `derive_key` mode | as §2.1 |
| **C1 / everything** | SHA-256 | as §2.1 |
| the CPU column digest / G1, G2 | **the pair does not arise**: `zkp-core/src/pcs.rs:782-785` declines the device when a column key exists, so a tagged commitment never offers its columns to the accelerator | the tagged commitment path; the legacy case is §2.1's row |

---

## 3. The rows that are pinned by nothing

Collected here so they cannot be missed by reading only the tables.

1. **A salted leaf and a Merkle inner node, under the legacy rule** — the same
   function on the same 64 bytes. Nothing separates them. Priced, not fixed.
2. **The model behind F_L ≠ F_N under a tag** — proposed decision **D19b**,
   an ideal-compression-function reading at an adversary-chosen chaining
   value. The keys are pinned distinct; the model is a proposal.
3. **R1 against the leaf and node classes** — separated by BLAKE3's keyed
   mode under a secret key (convention V-2) and by nothing else. At the
   generalised endpoint the three even share a length.
4. **That C1 stays SHA-256** — no test says the capture writer may not become
   a BLAKE3 writer, which would put its file digests into F_U.
5. **The two CUDA kernels' agreement with `pcs.rs:171`** — pinned by a
   differential probe and the parity gates, not cited to a gate by name in
   any statement. Ruling J-3 puts that configuration outside D22 until it is
   (W-9), and the device and pinned-host buffer lifetimes are unread (W-10).

---

## 4. Two numbers of the memo the code contradicts

Recorded here because this table is where someone would look for them.

1. **The four `derive_key` contexts are 49 / 44 / 49 / 48 bytes**
   (`zkp-core/src/hashtag.rs:47-53`), not the memo's 48 / 43 / 48 / 47 —
   each is one byte longer than §5's table says. Nothing depends on the
   figure; `derive_key` separates by MODE and not by length.
2. **The `calibration` absorb is 91 bytes** (`48 + 11 + 32`) and appears in
   no list of the memo's §5.1 fixed lengths. It is one byte below the
   `pb-run-block` absorb's 92, which makes it a member of the one-byte-margin
   class the memo's §7 enumerates and does not list.

Both are re-derived from the code by
`s25_tests::the_memos_length_table_is_re_derived_from_the_code`.
