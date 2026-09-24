# Twelve-block 125M run captures (lane stage 48, 2026-09-23)

## What these are

The VERIFIER'S VIEW of one private **twelve-block** run at the 125M shape
(`Shape::m125`, run profile `hashline-zk-mr1/private-run-m125/1`, D19 tag),
taken by observing the production run verifier with the `cfg(test)` recorder
in `hashline/src/private_block/run_capture.rs` (schema
`hashline-native-capture/5-run`, the stage-27 writer, not changed). Written by
`private_block::run_capture_tests::s48_capture_a_twelve_block_125m_run`;
re-verified in a fresh process by
`private_block::run_capture_tests::s48_reverify_a_run_capture_bundle`.

Every earlier 125M run capture is a TWO-block run (`m125-capture-dense-l2`,
`m125-capture-zero-l2`, stage 27). These two are the whole twelve-block run:
eleven internal boundaries and two external endpoints under one transcript.
**The all-zero bundle is also the first twelve-block all-zero 125M run ever
proved and verified.**

| bundle | witness | where (NOT in git) | files on disk |
|---|---|---|---:|
| `m125-dense-l12` | the fully dense run recipe (`dense_tests::dense_run_case`, down band 1) — the GENERIC witness, the recipe of the measured 397.71 s run | `/home/victor/zk60-artifacts/m125-capture-dense-l12/` | 1,216,953,306 B |
| `m125-zero-l12` | the all-zero hidden input on the tame fixture (`grow_tests::tame_case`'s public words) — the DEGENERATE partner | `/home/victor/zk60-artifacts/m125-capture-zero-l12/` | 1,208,519,158 B |

Each bundle directory holds:

| path | what | dense | zero |
|---|---|---:|---:|
| `run.json`, `stage-00.json` … `stage-11.json`, `arrays.bin`, `README.md` | the capture (pinned by the manifest) | 732,825,475 B | 724,391,988 B |
| `manifest.json` | every capture file's length and SHA-256, 38 source pins, `source_commit` | 6,187 B | 6,187 B |
| `run/segment-000.bin` … `run/segment-011.bin` | the RECEIPT: the 12 segments that were verified | 484,107,456 B | 484,107,456 B |
| `run/statement/run-statement.json` | the run's PUBLIC statement (`hashline-private-run-statement/1`, stage 18), written only after the run verified (D21) | 12,806 B | 12,145 B |
| `validation.json` | the fresh-process re-verify's record (after the manifest, not pinned by it) | 1,382 B | 1,382 B |

This directory keeps, per bundle, the small files: `manifest.json`,
`validation.json`, `README.md` (the bundle's own) and `run-statement.json`
(which lists all twelve segment files with their lengths and SHA-256). The
large files are pinned by those digests and can be checked where they are.

## Digests

| | dense | zero |
|---|---|---|
| `manifest.json` SHA-256 | `c660d0f41c0896c399aa76d76db0ca52233c66fa00e88a8cc0ff3201cf1b1080` | `c9e91d105659227b7e21a8dbce288fc7a4233c62140e2d813ae60ad7c506b013` |
| `arrays.bin` | 677,634,600 B, `a4c6a36baa56c74b016d5095ed03ab29d2e9c1bb17f11005f8b8c93c3d0983e2` | 669,200,544 B, `82696cc01d5d67b228810e9b93edc1ac0b8434408d3f8105772a46ffd9a4f05a` |
| `run.json` SHA-256 | `59077268efad653eba934e4254adc59e6ba1ef34667cc53c16ae9dbc9157c7b3` | `dd29e6dd1bd316c1165a3eaaaa1a3af306854ebe5bb46acdc4f11c991ca7987d` |
| run statement SHA-256 | `378f0ddc662be1866ee39b53fb10dc898beb28ad5e872188cee878d09f9da5de` | `6ffe8d94423536eb46f3a8743a3eb909f938c61ffcdc177d0fba12c5dc05ab56` |
| run binding | `13a1e36e213d7d2af3a184ccb2fbbfbb1ec6fefddd400d555cf25d87b2a37982` | `69c6e852ab80820939f497740ddcebe88f95f4958ab0d6da588e95adf9b1ee4d` |
| `validation.json` SHA-256 | `46bc56363ef1035e6044bf50194d3425671df35e85e813882899740f40dfeb5b` | `c731f4863cc39bb69d6eaf75c75e54ac0d6ec213eb9ed1343cd4a1020dc5f308` |
| `source_commit` | `17830dcc9f24b0d19e212b0344476e299cfd9be0` | `17830dcc9f24b0d19e212b0344476e299cfd9be0` |

`source_commit` is the full HEAD at capture time, checked by the writer
before anything was proved (finding E32-F1: a 40-hex id equal to `git
rev-parse HEAD`, and every one of the 38 pinned sources plus the five
harness files committed as they stand); a stale or short label is refused
(`s48_a_run_capture_label_that_is_not_head_is_refused`). The per-segment
digests are in each `run-statement.json`.

## Measured (one run each, shared box, not quiesced)

Detached under `/tmp/zk-heavy.lock`, one at a time, with
`MALLOC_MMAP_THRESHOLD_=131072`, `/usr/bin/time -v` inside the wrapper, 13 GiB
available at each launch. Logs: `results/zk60_block125m_lane/s48-m125-*`.

| | dense | zero |
|---|---:|---:|
| chain build (12 witnesses, each dropped) | 62.97 s | 59.75 s |
| **prove** (12 stages) | **309.66 s** | **300.23 s** |
| per stage | 28.17 / 31.65 / 24.39 / 24.77 / 24.41 / 24.84 / 25.25 / 25.04 / 25.14 / 25.77 / 25.09 / 24.97 s | 27.60 / 28.62 / 24.33 / 23.39 / 23.70 / 23.90 / 25.39 / 24.54 / 24.53 / 24.07 / 24.74 / 25.32 s |
| **verify** by streaming, no recorder | **14.45 s** | **14.30 s** |
| verify + record | 26.15 s | 26.10 s |
| write + read-back self-check | 18.78 s | 19.20 s |
| whole test, wall | 433.03 s | 420.55 s |
| **peak RSS** (`VmHWM`) | **10,373 MiB (10.13 GiB)** | **10,366 MiB (10.12 GiB)** |
| `/usr/bin/time` max RSS | 10,621,488 kB | 10,614,992 kB |
| segments | 12 | 12 |
| **receipt** | **484,107,456 B** = the counted figure | **484,107,456 B** = the counted figure |
| segment lengths | 40,033,896 + 10 x 40,302,184 + 41,051,720 | the same |
| capture files + manifest | 732,831,662 B | 724,398,175 B |
| `arrays.bin` | 677,634,600 B, 6,919 distinct arrays, 7,129 references (210 deduplicated) | 669,200,544 B, 6,917 distinct, 7,129 references (212 deduplicated) |
| fresh-process native re-verify | 13.51 s | 13.06 s |
| fresh-process canonical recapture | 25.82 s | 25.68 s |
| fresh-process whole test | 58.43 s, peak 1,605 MiB | 58.03 s, peak 1,597 MiB |

## The fresh-process validation (`validation.json`)

A process that did not prove the run: checked every source pin against this
build (`source_pins_match`); rebuilt the verifier's statement from
`run/statement/run-statement.json` alone (the recipe regenerates the twelve
public blocks and is checked against the block digests; every segment file's
length and SHA-256 is checked against the statement —
`statement_rebuilt_from_its_file`); verified the twelve segment files from
disk with no recorder (`native_reverified`); read the bundle back against its
manifest, its allow-list and its array store, with every stage file's
`segment_bytes` / `segment_sha256` equal to the segment file's
(`segments_match_the_stage_pins`); and recaptured the same files with the
recorder attached: `run.json`, all twelve stage files and `arrays.bin`
byte-identical to the saved ones (`canonical_capture_reproduced`). All `true`
for both bundles; `privacy_review_complete` is `false`.

## What these are NOT

**Not a privacy result and not gate evidence yet.** No gate has read a
twelve-block bundle. A capture is the INPUT to the privacy gate of ruling
M-8 (obligation 7 of `ZK60_SHAPED_PRIVACY_PATH_STATUS.md`); the gate's
tools are shape- and L-driven and were shown at L = 2 and 3, but running them
at L = 12 is the gate's own next step. D22 (the toy) remains the only privacy
statement in force. The timings are one run each on a shared box. No bundle
carries a witness value, pad, mask coefficient, unopened column, unpublished
salt, unmasked round, prover randomness or prover log; the weights are
synthetic and public.
