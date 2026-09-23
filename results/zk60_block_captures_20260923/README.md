# Standalone shaped block captures (lane stage 45, 2026-09-23)

## What these are

The VERIFIER'S VIEW of ONE private block receipt at a shaped profile, taken by
observing the production verifier (`protocol::verify_inner_at`, reached from
`verify_bytes_at`) with the `cfg(test)` recorder in
`hashline/src/private_block/block_capture_shaped.rs`. Schema
`hashline-native-capture/5-block-shaped`. Four bundles:

| bundle | profile | witness | files on disk | where |
|---|---|---|---:|---|
| `rung-g/rung-g-dense` | `hashline-zk-mr1/private-block-rung-g-t24-dev/1` | fully dense run recipe (`dense_run_case`), the GENERIC witness | 12,516,502 B | in git |
| `rung-g/rung-g-zero` | same | all-zero hidden input on the tame fixture (`tame_case`), the DEGENERATE control | 12,456,570 B | in git |
| `m125-dense` | `hashline-zk-mr1/private-block-m125/1` | fully dense run recipe (`dense_run_case`, down band 1) | 276,686,082 B | `/home/victor/zk60-artifacts/block-captures-20260923/m125-dense` |
| `m125-zero` | same | all-zero hidden input on the tame fixture | 268,253,974 B | `/home/victor/zk60-artifacts/block-captures-20260923/m125-zero` |

**The two 125M bundles are NOT in git**: each `arrays.bin` is over 100 MB
(230,479,888 B and 222,045,832 B). This directory's `m125/` holds each one's
`manifest.json` (which pins every file of the bundle by length and SHA-256,
and the 35 source files), its `validation.json` and its README, so the
bundles can be checked where they are.

Every bundle: `block.json`, `observations.json`, `arrays.bin`, `receipt.bin`
(the canonical frame that was verified), `expected.bin` (the endpoint policy),
`README.md`, `manifest.json` (written LAST), and `validation.json` (written by
a FRESH process after the manifest; not pinned by it).

| bundle | `manifest.json` SHA-256 | `receipt.bin` SHA-256 (the proof) | receipt bytes | `arrays.bin` |
|---|---|---|---:|---:|
| rung-g-dense | `d56975b0e68c26aaa03fb50ed82eb8a9d22de29e5b5d6a09208e45062e312164` | `7fb81aff8c05fd4b427b46155a14e892cfd5faccce4f03dde2135f919f33f705` | 4,234,984 | 4,543,928 |
| rung-g-zero | `5455070dd38be13558b04f65cd783791f3674b94815b9e8c0482e7939ea8bdaf` | `6c173105b59723022d5ed25343d97162c9469a554543f02690f92bd0c36fe607` | 4,234,984 | 4,489,488 |
| m125-dense | `49b0336b131a67de883dd1d0724781556518642d00c040780571b24efe40587c` | `bddb04937ec8c0c6a2655fc4e816d625e363694e55b329e9bd21d208d5e386f0` | 40,783,352 | 230,479,888 |
| m125-zero | `f58eb60b15be2a373e3cf337d59c6289c0d038ff38a18f64ca279d91ff647d35` | `8999067de00aea03382984885a90087d19173348072442503693fd102a5b27e9` | 40,783,352 | 222,045,832 |

`source_commit`: rung-G `feae674dbd5c5a3e7646da9e33bc423e76b8ab32`, 125M
`19f06bfde4a1e4fcb0f39acc19da1f6654d66f9c` — each the HEAD at capture time,
checked by the writer (finding E32-F1: a full commit id equal to `git
rev-parse HEAD`, and every pinned source committed as it stands). The two
commits differ only by the rung-G bundles themselves; the 35 source pins are
the same in all four manifests.

**Each bundle was re-verified in a FRESH process** (`validation.json`):
every manifest file and every source pin checked against the tree, the public
statement regenerated from the recipe tag and checked against the digest the
bundle carries, the saved receipt verified FROM BYTES by a fresh verifier
(`native_reverified`), the recapture of that receipt byte-identical to
`block.json`, `observations.json` and `arrays.bin`
(`canonical_capture_reproduced`), and the bundle's roots, slot scalars and
terminals, opened columns, salts, group and proximity vectors and `M` opening
found equal to the decoded receipt's (`values_match_the_decoded_receipt`).

## What these are NOT

**Not a privacy result, and not gate evidence yet.** No gate has read them.
A capture is the INPUT to the Python joint-view gate (obligation 3 of
`ZK60_SHAPED_PRIVACY_PATH_STATUS.md`); the gate still has to be taught the
single-block schema below. D22 (the toy) remains the only privacy statement
in force. The weights are synthetic and public; the rung-G profile is
development grade (ruling P-7).

No bundle carries a witness value, pad, mask coefficient, unopened column,
unpublished salt, unmasked sumcheck round or prover randomness
(`not_in_a_capture` in `block.json`); every key is on the declared allow-list
(the run capture's plus seven block-only keys).

## What a gate has to learn (a standalone block vs a run stage)

1. **Two JSON files, not `run.json` + `stage-NN.json`.** `block.json` is the
   header (the analogue of `run.json`: statement, shape, endpoints, hash tag,
   transcript labels and program, plane index table). `observations.json`
   carries a run stage file's members for the same objects — `a_root`,
   `h_root`, `mask_root`, `logup_challenges`, `layout_digest`,
   `opening_order`, `header`, `arguments`, `mask`, `roles`,
   `transcript_sites` — minus the run's framing (`stage`, `blocks`,
   `segment_*`, `start_tag` / `end_tag`, `boundary_committed`) plus
   `proof_bytes` / `proof_sha256`. Every slot, `M` and role object has the
   run stage's key sequence exactly (asserted against a one-block rung-G run
   capture); a transcript site has no `stage`; a role's `claim_sources[].stage`
   is written as 0 and its `boundary` as null.
2. **The transcript header is the block's.** Domain = the BLOCK profile
   string (a run uses the run profile); absorbed: `expected-IO`,
   `public-statement` = THIS block's digest (a run absorbs
   `H(all block digests)`), `parameters` = this block profile's line (with
   the endpoint parameters written out), `calibration`, `schedule` = the
   block layout's schedule digest. **No `run-shape` word.** The state after
   the header is `block_binding`, which is also the header state in the
   receipt frame's 40-byte envelope.
3. **No stage words and no boundary**: no `pb-run-stage`, no
   `pb-run-block`, no `B`; the `A` root is the first absorb after the header.
4. **Both external endpoints in ONE proof**, opening order
   `M, A, H, Input, Output`: `Input`'s one claim comes from slot 21 alone,
   `Output`'s from slot 22 alone, both at the endpoint geometry (125M: 37
   rows, 32 data rows, reserved pair 32/33, proximity pair 34/35; rung-G: 9
   rows, 4 data rows). The IO tables' `mask_row` is the external endpoint's
   reserved pair, equal to a one-block run's (measured).
5. **The hash tag keys are the block profile's** (`blake3-keyed/1`), the same
   four keys a run of this block shape uses; re-derive them, never consume.
6. **No segments and no position tags**; the receipt is one frame,
   `receipt.bin`, pinned by `proof_sha256`.
7. The public tables carry their VALUES (`public_tables_included: true`):
   31 at rung-G, 28 at 125M.

Writer: `private_block::block_capture_shaped_tests::write_a_shaped_block_bundle`
(`HL_BLOCK_CAPTURE_SHAPE=rung-g|m125 HL_PB_INPUT=dense|zero
HL_BLOCK_CAPTURE_DIR=<new dir> HL_TEST_SOURCE_COMMIT=<HEAD>`); fresh-process
re-verify: `reverify_a_shaped_block_bundle` (`HL_BLOCK_CAPTURE_BUNDLE=<dir>`).
Both `#[ignore]`d. Logs: `results/zk60_block125m_lane/s45-*`.
