# ZK60 standalone shaped block capture — `m125-zero`

What this is: the VERIFIER'S VIEW of ONE private block receipt at the shaped
profile `hashline-zk-mr1/private-block-m125/1` (125M private block (T512 / d768 / f2048, 12 heads of 64 over 4 KV heads): 512 tokens, width 768, hidden 2048, 12 query heads of 64 over 4 key-value heads,
row width 2^14, rate 1/4, 256 opened columns), captured by observing the verifier
(`hashline/src/private_block/block_capture_shaped.rs`, lane stage 45), schema
`hashline-native-capture/5-block-shaped`. A STANDALONE block, not a run stage: its transcript opens
with the block's own header (`parameters` is this block profile's line,
`public-statement` is the block's own digest, no `run-shape` word), it has no
stage words and no boundary, and it opens BOTH external endpoints in one
proof. `block.json` carries the transcript program in words.

Witness: the ALL-ZERO hidden input on the lane's synthetic tame fixture (public-weight recipe tag `tame_case`) — the DEGENERATE control

Files: `block.json` (the header: public statement, shape, endpoints, hash rule,
transcript labels and program, plane index table), `observations.json` (the
twenty-three slot transcripts, the M opening and the A, H, Input and Output
openings — a run stage file's field names), `arrays.bin` (the `/5-run` array
store: every field-element array of at least 256 entries, little-endian),
`receipt.bin` (the canonical frame that was verified), `expected.bin` (the
endpoint policy), and `manifest.json` (every file's length and SHA-256, the
source pins, the public-weight recipe tag and the witness tag). A
`validation.json`, when present, is the record of a FRESH-PROCESS re-verify
and canonical recapture, written after the manifest and not pinned by it.

What this is NOT: a privacy result. No gate has read it. It carries no witness
value, pad, mask coefficient, unopened column, unpublished salt, unmasked
round or prover randomness; the list is `not_in_a_capture` in `block.json`.
The weights are synthetic and public.
