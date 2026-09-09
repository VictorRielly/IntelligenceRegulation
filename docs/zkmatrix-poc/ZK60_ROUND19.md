# Round 19 — verified IO capture and O7 integration

Opus O7 (`4695503`, handoff `321ca22`) is integrated in `5193ee4`.
All fourteen recorded source digests match its implementation pin `137b109`.
Its implementation review found no open defect in the consolidated commitment
schedule. It did not establish privacy of the new IO observation set.

`1f0ff36` adds a separate, unit-test-only capture for the actual `/2` IO
verifier. Combined validation passes, and four complete capture/receipt/policy
triples are retained for the next analysis; details below.
There is no change to the release proving transcript, wire format or API.

## What is captured and checked

The observer retains only public verifier inputs and derived challenges:

- All seven A groups, H, P3 W, and both endpoint groups; complete message and
  pad vectors, proximity coefficients/vectors, sampled columns, salts and paths.
- The single eight-slot M: fourteen public functionals with all coefficient
  weights, its combination challenge, proximity challenges, both full vectors,
  and all 256 sampled twenty-word columns.
- Both IO sumchecks with their challenges, round polynomials, masked terminals
  and mask evaluations; the six FFN sumchecks, terminals and initial claims.
- The expected-policy bytes, full saved receipt, transcript states plus next
  challenges at every opening boundary, and source/layout/artifact digests.

Each hiding PCS observation is replayed through the existing independent
group/transcript diagnostic and the ordinary PCS verifier. M and public W are
reverified from their captured public inputs. Both equality arguments are
replayed, and the joins enforce IO-input, IO-output, M, W, A, H, input endpoint,
output endpoint. This checks opening boundaries; it is not the still-pending
label-by-label whole-transcript test proposed in O7 P9.

Publication happens only after both endpoints accept. A new attempt clears the
previous publication before byte parsing and typed verification. Recommitted
wrong planes, malformed frames and a failure in the last endpoint publish
nothing. Replay controls alter role order, a sampled mask word, transcript
counter, endpoint vector, sampled index and equality point. O7 P3's swapped
and duplicated real endpoint openings and P8's relabelled input scale are now
covered. The archived FFN capture observer remains separate and still receives
no IO publication.

Schema 3 uses coverage `ffn-v3-mr1-fresh-io-poc-function-1` and profile
`ffn-v3-mr1-fresh-io-poc/2`. The digest is of the **complete HFFNIO receipt**,
unlike the archived FFN logical-payload digest. Every capture has sibling
`.receipt` and `.expected` files under the receipt digest. Files use
`create_new`, so a stale artifact cannot be silently overwritten.

The preflight independently recomputes layout geometry using Opus's existing
arithmetic, then checks row roles, aliases, groups, public-vector equations,
column structure, transcript joins and artifact digests. It rejects old
captures and the superseded IO draft. Its ingestion controls mutate real
accepted captures; they do not fabricate cryptographic observations.

## Scope corrections and remaining work

O7 §6 describes each added group vector as combining all commitment rows.
The message portion actually combines only rows selected by that group's
claims; the proximity vector combines all rows. A's IO claims use the real
X rows 14–15 and z16 rows 16–17 plus their respective masks 698–701.
Endpoint rows 4–6 are fresh random rows used by proximity; only rows 2–3 are
the terminal pair. Capture preserves all seven endpoint rows, including row 6.

An IO capture is new evidence, **not a privacy result**. O6 U-2 is still open:
no accepted joint IO analysis exists. Opus O8 adapts the established linear
observation model with its exclusions stated. Codex retains the CFS/encoded
column/adaptive-transcript argument and cryptographic acceptance, then private
attention and the tiny complete block. Registered private model identity,
scale authorization and the priority-3 minimal core extraction remain open.

## Validation

The [validation record](../../results/zk60_round19_validation.json) and
[retained evidence index](../../results/zk60_round19_evidence/index.json) record:

- 227 storage-enabled Rust tests, including ten doctests, with no failures or
  ignored tests. The v9 suite count is unchanged; existing IO tests gained the
  replay, publication and endpoint controls.
- 100 Opus review tests and 57 legacy joint-analysis tests.
- Four complete schema-3 captures, two P1 and two P3, each with a source pin,
  layout digest and saved receipt/expected policy. Full replay and preflight
  pass; P1 receipts are 5,029,244 bytes and P3 receipts 5,066,204 bytes.
- Six separate-process verifications: the four new saved receipts and both
  retained round-18 receipts accept with the release verifier.
- 32 ingestion rejection controls against each of one real P1 and one real P3
  capture, with the unchanged capture accepted before and after each battery.
- Native `freeze-check` passes with the existing WSL fixture directory.

The initial worker omitted `M125_EXPORT_DIR`, so its native check stopped on a
missing default fixture path after the earlier stages passed. The corrected
invocation uses `results/m125_ffn_export_wsl`; the initial failure and successful
retry are both retained. `completion.done` is 0; the original worker's
`validation.done` remains 1 and is not relabelled.

Full capture JSON, receipt and expected-policy files remain under
`/tmp/zk60-round19/captures`. Their names and hashes are in the validation
record. The scripts and logs needed to reproduce the run are retained in the
evidence directory. Regenerate in a checkout of the recorded Rust source with
a **new output directory**; never attach the old source label to changed code.
The `bound_ffn_honest_p1_p3_and_fresh_owners` unit-test filter produces the four
captures with `HL_TEST_FFN_IO_OBSERVATIONS` and `HL_TEST_SOURCE_COMMIT` set.

Workers use `/tmp/zk-heavy.lock` and two build/Rayon/test threads, clearing
`HL_*` before the two explicit capture variables. The final preflight/control
tool digests are recorded separately from the Rust capture source. No GPU,
full Python rerun, new performance measurement or full privacy acceptance is
claimed. The four frozen CPU proof results remain the round-18 evidence;
round 19 changes only code compiled into tests plus analysis tools.
