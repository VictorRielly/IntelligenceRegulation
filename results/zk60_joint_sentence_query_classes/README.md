# Evidence for `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md`

Drafted by a delegated Opus agent for the security owner, 2026-09-21, 02:55
(started 02:21; `date` read at each write).

Four read-only Python scripts, no dependencies outside the standard library,
no network, no build, nothing heavy. Every one is exact: `fractions.Fraction`
and integers, never floating point except in a printed `log2`. Every one ends
with `ALL ASSERTIONS PASSED` or fails loudly. Outputs are saved beside them
as `<name>.out`.

```
python3 sampler_coupling.py     # ~35 s
python3 stream_positions.py     # ~1 s
python3 counterexamples.py      # ~3 s
python3 query_classes.py        # ~1 s
```

| script | what it establishes | memo claims |
|---|---|---|
| `sampler_coupling.py` | the sampler's bias in event form costs `2^-64` per draw, not `2^-96`; `2^-64` is a lower bound for ANY exactly-uniform good event; the closed-form criterion `2(p−r) < p`; an exact end-to-end adaptive model licensing the distance hop by data processing | A-10 … A-14, F-1 |
| `stream_positions.py` | the ordered stream-segment table with exact byte offsets at five shapes and three runs; pairwise disjointness; totals reproduce D9's 327,052 and ruling H-6's figures; what a rejection sampler would have cost the argument | A-1 … A-9, A-17 |
| `counterexamples.py` | counterexample (i) a shared blinding row; counterexample (ii) ruling R-3's two distinct rows with coinciding values, invisible to every rank gate; the pricing of an accident against a broken draw discipline | A-15, A-16 |
| `query_classes.py` | every BLAKE3 input length per shape and per function instance; every within-family and cross-family coincidence, classified by what separates the pair; the dangerous row counts, including one in no guard | B-1 … B-9 |

## Where the code facts come from

Every constant is transcribed from the lane worktree
`/home/victor/wt-zk60-block125m` at commit **`8c5922b`**, read with
`git --no-pager -C /home/victor/wt-zk60-block125m show 8c5922b:<path>`.
Nothing was built or run in Rust. The load-bearing ones:

| fact | file:line at `8c5922b` |
|---|---|
| `p = 2^64 − 2^32 + 1` | `zkp-core/src/field.rs:10` |
| `Fp::from_u128(v) = v % P` — modular reduction, no rejection | `zkp-core/src/field.rs:36-38` |
| `fp()` = two `next_u64` = **16 stream bytes, always** | `zkp-core/src/rng.rs:73-77` |
| `bytes32()` = four `next_u64` = 32 bytes | `zkp-core/src/rng.rs:93-99` |
| `next_u64` = 8 bytes; `RNG_BLOCK = 8192`, a multiple of 8 | `zkp-core/src/rng.rs:16, 63-70` |
| refill = unkeyed `blake3(key(32) ‖ le64(counter))`, 40 B, XOF | `zkp-core/src/rng.rs:53-61` |
| seed derivation = **keyed** BLAKE3, `"hashline-zk-os-rng/v1/"(22) ‖ domain` | `zkp-core/src/rng.rs:44-51` |
| the generalised endpoint's domain is 42 B, so the seed input is **exactly 64** | `hashline/src/private_block/endpoint_g.rs:45, 224` |
| commit: pads (`fp_vec(rows·Q)`) **then** salts (`nn × bytes32`) | `zkp-core/src/pcs.rs:777-778` (tagged), `:724-725` (legacy) |
| `M`: 23 CFS masks, 46 pad blocks, `b_re,b_im,u_re,u_im`, 4096 salts | `hashline/src/zk.rs:485, 496, 503-508, 513` |
| `b_re[m] = b_re[0].neg()` — an overwrite, **not** a re-draw | `hashline/src/zk.rs:505-506` |
| `H` zero-sum rows: `n−1` draws, last entry computed — no loop | `hashline/src/private_block/protocol.rs:760-768` |
| `A` / `H` mask+proximity rows | `protocol.rs:655-658`, `:757-759` |
| one generator per block proof | `protocol.rs:486` |
| **one generator for a whole run**, threaded across all stages | `run.rs:475`, loop at `:487` |
| a boundary uses the caller's generator | `boundary.rs:315-328` |
| an external endpoint makes its own | `endpoint_g.rs:224`, `private_seam.rs:196` |
| `ζ` and `mu_pad` are TRANSCRIPT squeezes | `argument.rs:961, 1027, 1028, 1224, 1299, 1352, 1410, 1485` |
| transcript constructor / absorb / squeeze / `clone_state` | `zkp-core/src/transcript.rs:30, 41, 61, 103, 156-162` |
| salted leaf 64 B / Merkle node 64 B, same shape | `zkp-core/src/pcs.rs:678`, `zkp-core/src/merkle.rs:15` |
| `EXPECTED_BYTES = 8+32+4+4+2·32 = 112` | `hashline/src/private_block.rs:213` |
| the lane's own length bookkeeping and its guard | `hashline/src/private_block/hash_domain.rs:58-88, 240-256, 320-332` |
| the four tag keys, `derive_key` | `zkp-core/src/hashtag.rs:47-53, 92-101` |
| the capture writer is SHA-256, not BLAKE3 | `hashline/src/export_v3.rs:54, 168-173` |

## What is NOT here

- No Rust was compiled, no test was run, no proof was produced. Every claim
  about the code is a **reading** at `8c5922b`.
- The per-slot `pb-term` terminal counts were not read; the range 1..56 is an
  over-approximation taken from the toy memo. Work-list item W-6.
- `rung-K4`'s `parameters` line length was not read; it is `None` in the
  shape table and its absorb is omitted from that shape's length set.
- No privacy property of any artifact is established by anything in this
  directory.
