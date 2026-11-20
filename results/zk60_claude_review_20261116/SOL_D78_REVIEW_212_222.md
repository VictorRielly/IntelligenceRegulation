# Cross-review of Sol's D78 packages 212 and 222

Reviewer: Claude (Sonnet 5.5), 2026-11-16. Read-only on Sol's directory. Scratch scripts: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/sol-review/` (`b3ref_check.py`, `trace_controls.py`, `rerun219/`). CONFIRMED = I ran or computed it; READ = from reading code only.

## Verdict

Package 212: yes. Package 222: yes with corrections. Every pin matches, the 219 result reproduces exactly, and the 216/218/221/214 controls refuse for real, specific reasons. The corrections are wording and disclosure, not a failed check: "55 terminal equations" overstates independence, the 10 block-stage host coefficients are taken from the capture, and the BLAKE3 provenance and common-mode risk is absent from 222's own statements. Nothing found supports a claim beyond "conditional public synthetic rung".

## Findings

No High findings.

**Medium**

1. Block-stage host coefficients are not independently derived (READ). For the two BLOCK stages the caller passes `hosts=[a["hosted"] ...]` taken from the capture (`probe_actual_chain206.py:49`, `probe_integrated_capture219.py:50`). The checks that then compare `observation["hosted"]` with that same value are tautologies (`d78_public_transcript186.py:210`, `d78_mask_functionals203.py:33`). Only the structure is checked (which slots are Host, prerequisite order). That is 10 coefficients (5 Host slots x 2 stages; `KINDS` in `probe_actual_programs204.py:24`). For IN/OUT, 217 does derive them (`d78_token_polynomials217.py:133,162,179`). Module docstrings (`d78_capture_chain205.py:44-49`) admit "conditional observations", but 222 `remaining` and 219 `pending` do not name host coefficients.
2. "55 terminal equations" (222 `new_evidence`, 219 scope) mixes two strengths (READ). 15 IN/OUT expressions are independently ported (217). The 40 block ones evaluate the capture's own program graph against the capture's own values (`probe_actual_programs204.py:31-34`). 222 `remaining` item 2 says so, but the headline number does not.
3. BLAKE3 is native, and its files are outside the seals (CONFIRMED). `d78_blake3_primitive184.py` launches a Rust worker built with `rustc` against the cached `libblake3` rlib (blake3 1.8.7 from `b1/target/release/deps`). This is the same crate the native prover links, so it is a common-mode dependency. The module, worker source, binary and `probe_blake3183.py` are not in the 212 or 222 `pins` maps. Only `D78_BLAKE3_PRIMITIVE_183.json` is pinned, and it pins those files. I rehashed them against 183 and they match. Of the official vectors, only lengths 0, 1 and 2 (9 answers) are checked (`probe_blake3183.py:18-28`). The 30 streaming cases (lengths 63 to 1,048,579) compare streaming with one-shot and prove nothing about correctness. I closed this gap: my own pure-Python BLAKE3 matches the worker on 208 inputs (plain, keyed and derive-key; lengths 0 to 40,000; 32 and 131-byte outputs; 40 random keyed cases) with 0 mismatches, so the worker is standard BLAKE3.
4. The reports record only counts, not which check fired (CONFIRMED). 216 stores a category list, 218/221/214 only totals. I re-ran all 111 + 20 + 8 + 24 controls and recorded exception type and message. Every refusal is a `ValueError` subclass (`InvalidReplay`/`InvalidEnvelope`) with a specific message, none a crash. Findings from the trace:
   - 218 control `order` (a table kind set to "public") is refused by "token public table grammar" in `terminal_values` (`d78_token_polynomials217.py:57`), before the intended "native token table order" check.
   - 218 control `public` (table sha256 zeroed) is refused by the array-store digest check (`d78_capture_envelope197.py:220`), not by "derived token public table". No control mutates table values so that only the derivation check can catch it.
   - 216 "coherent noncanonical scalar" is refused on the observation side ("noncanonical field coordinate"). The wire-side canonical check (`d78_wire_binding215.py:71`) is never exercised (it is redundant with the byte comparison).

**Low**

5. 219 has no controls of its own (READ). It is a positive run. Its negative evidence is inherited from 214/216/218. It ends `assert ... tr.counter==4815` (`probe_integrated_capture219.py:61`). The counter really is replayed (CONFIRMED in my re-run: counter 4815 after the last role), but 4815 is a regression literal, not independently derived, and `assert` vanishes under `python -O`.
6. 221 model-word controls (`embedding`, `head`, `multiplier`) are refused by the model digest before the fold tables are reached. Only the two fold-point controls exercise a fold. The recipe in `probe_public_model221.py:20-28` matches `source-d78-188/.../token_io/tests.rs:1508`, and the Python-computed digests equal the capture's, which authenticates the recipe (CONFIRMED).
7. `source-d78-188/` holds 113 files beyond the 341 pinned (a `results/` subtree including `token_io/*.bin`, and a named pipe `results/r12b-tests/4385-bounded.fifo` that breaks `shutil.copytree`). They are unpinned and unused by the Python path. Capture `source_commit` is `uncommitted-test`, and `proved_on_gpu` is `true` although this box has no GPU backend. Neither affects the Python checks; both are undisclosed.
8. Sol was still writing in the directory during review (`HANDOFF.json` changed). The pin result is a point-in-time snapshot.

## A. Pin table (CONFIRMED)

| Map | Entries | Mismatches | Missing | Symlinks |
|---|---|---|---|---|
| 222 `pins` | 72 | 0 | 0 | 0 |
| 212 `pins` | 44 | 0 | 0 | 0 |
| `SOURCE-d78-188.json` files | 341 | 0 | 0 | n/a |
| 183 pins (BLAKE3 files) | 7 | 0 | 0 | 0 |

Resolution matches `seal_independent_review222.py:17` (absolute paths kept, others joined to the b3 directory). The three absolute `.rlib` paths exist and match. Two pinned logs hash to the empty string: `d78-mask-probe202/native.log` (stderr of the fixture run) and `build.log` (rustc output). Both are 0 bytes, which is expected for a clean `-O` build and a silent fixture (`fixture.jsonl` is 12.2 MB). `d78-blake3-probe183/build.log` is also empty. Segments total 33,564,688 bytes as claimed.

## B. Independence

Computed in Python from public rules: the transcript chain (header, keys, counter 0; matches `transcript.rs:29-44,59-75,120-130`), field arithmetic (generic `% P`, non-residue 7, matches `field.rs:15,163-168`; I checked that 7 is a non-residue), sumcheck, PCS/M openings and Merkle paths, the 15 IN/OUT expressions, 18 public tables, token digests and calibration (hard-coded registered profiles), the 230,700 model words and both folds, and the endpoint and boundary digests.

Taken on trust from the capture or hard-coded (disclosed unless marked):
- all prover content (terminal values, rounds, roots, PCS claims, columns), legitimately an input;
- `public_statement.json`: `model_identity`, `block_digests`, roots and `segment_blake3` feed the calibration and statement checks (not named in `remaining`);
- `schedule_digest` is header-bound only (disclosed);
- block program graphs, block public tables, private descriptors and plane index (disclosed);
- block-stage host coefficients (NOT disclosed, Finding 1);
- stage geometry, draw counts, batch descriptors, role geometry, wire term and group counts (`probe_actual_chain206.py:28-47`, `probe_wire_binding216.py:25-28`): typed constants cross-checked against the capture (disclosed as "explicit fixture geometry and draw counts");
- anchors: `SOURCE_SHA`, `REGISTERED`, `TIER` constants, and the 4815 literal.

Native-derived data: the capture and receipts (native run 190), the BLAKE3 worker (Finding 3, native crate, disclosed in 183 only), and the 202 differential fixture (`probe_public_mask202.py:28-60` builds a Rust fixture against the `zkp_core` rlib and compares native M openings with Python). The 202 fixture is not consumed by 216, 218, 219 or 221. No Python path in the 214-221 chain loads native code other than the BLAKE3 worker. 222's statements do not mention 202.

## C. Controls sampled (all CONFIRMED by re-run)

| Probe | Control | Check that fired |
|---|---|---|
| 216 | flip header.magic | wire/capture header.magic |
| 216 | flip M.salt | wire/capture M.salt |
| 216 | flip PCS.path | wire/capture PCS.path |
| 216 | flip trailer.end_tag | wire/capture trailer.end_tag |
| 216 | truncate or pad 1 byte (8 cases) | "wire exact counted segment length" (generic length check, intended) |
| 216 | coherent noncanonical scalar | "noncanonical field coordinate" (observation side) |
| 218 | `terminal_polynomial` bit flip, 15 slots | "independent native token terminal expression" |
| 218 | `mu` | same expression check |
| 218 | `host` | "derived token hosted coefficient" |
| 218 | `logup` | same expression check |
| 218 | `order` | earlier grammar check (Finding 4) |
| 218 | `public` | earlier store-digest check (Finding 4) |
| 221 | embedding, head, multiplier | model digest checks |
| 221 | embedding_point, head_point | fold checks |
| 221 | 3 class cases | range ("class") checks |
| 214 | 24 bool/float substitutions | 20 by "endpoint facts require exact JSON integers", 4 by "exact endpoint/boundary scalar integer" |

I confirmed the 214 claim that the old 210 check accepts 23 of the 24. No control counted a crash as a refusal: Sol's probes catch only `ValueError`, not bare `Exception`.

## D. Arithmetic and transcript

Reduction, P and the quadratic non-residue match the Rust source. The transcript starts from `Transcript(primitive, profile, key=derived transcript key)` at counter 0 and absorbs the typed header items (`d78_token_bindings198.py:105-114`). The state must equal the capture's `run_binding`, compared rather than seeded. Replay uses `clone()` of that object, so no state or counter comes from a checkpoint (READ and CONFIRMED by the final counter in the re-run). Captured checkpoints are only compared after each step.

## E. Re-run (CONFIRMED)

`probe_integrated_capture219.py` cannot run in place: `HERE` is Sol's directory and it opens its log and report with mode "x", and both files already exist. I copied the modules, the 341 manifest source files, the capture, the receipts and the BLAKE3 worker to my scratch directory, excluded the two 219 outputs, and ran the copy. It took 30.3 s and 408 MB (Sol: 32.5 s, 361 MB). Output equals Sol's report in every field except `utc`, `wall_seconds`, peak RSS and the progress-log pin: 445 claims, 55 sumchecks, 4815 counter, terminal state `b7c34669...f505`, 33,564,688 bytes. This is under the guard thresholds, so it ran unguarded.

## F. Wording

Stronger than evidence: "55 terminal equations" (Finding 2); "independently consumes" for 216 means an independent reader of the bytes, but the expected values are the native verifier's observations (byte provenance, as 216's own scope says); "closes the two token fold provenance obligations" holds only for the pinned synthetic recipe (stated). Omitted limits: host coefficients, `public_statement`/`model_identity` trust, native BLAKE3 crate and its thin KAT coverage, 219 having no controls of its own, unpinned extras in the source copy.

## Not checked

Internals of 204, 206, 208, 209, 211 and 210 (endpoint derivation) beyond imports; the Rust `reduce128` and `from_u128` correctness; `d78_public_pcs193.py` and `d78_public_mask201.py` against Rust; the 76,179 read count; the constant 133 against Rust (the positive match with the native terminal values supports it); privacy, rank and nonlinear gates (out of scope); and whether native run 190 itself is honest.
