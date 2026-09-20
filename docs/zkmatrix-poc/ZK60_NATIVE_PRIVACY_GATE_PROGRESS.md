# Ledger — the block-scope privacy gate P10 (`zk60_native_privacy_gate.py`)

Lane `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`,
opened 2026-09-20 01:40 (PDT). Sole writer: one delegated Opus implementer
working for the security owner. PYTHON ONLY — no cargo, no builds, no GPU.

**What this lane built.** A NEW tool, `scripts/zk60_native_privacy_gate.py`,
that does what the existing joint-view tool does not: for each captured
receipt it **constructs and exhibits** a preimage of the verifier's linear
view under a FIXED hidden input (the all-zero one, and a pseudorandom one
from a public seed), by solving exactly over the Goldilocks field; verifies
it by recomputing the view entry by entry; and labels **every** channel of
the privacy case's §2 as CONSTRUCTED / DERIVED / ARGUED / OPEN in a
machine-readable record. Definition: `ZK60_PRIVACY_CASE_FIRST_MVP.md` §4
(rewritten under ruling C-6) and §2; `..._CHECK.md` §8. Report:
`ZK60_NATIVE_PRIVACY_GATE.md`.

**This is not a privacy acceptance and does not establish a privacy
property.** It is a statement about the linear channels of four captured
receipts at two toy layouts.

## 0. Status

| # | item | state |
|---|---|---|
| S0 | skeleton ledger, baseline suite | DONE — 85 tests, 72.8 s, OK (1 skip), commit `4305d63` |
| S1 | the linear model written down; which capture fields carry `y` | DONE — report §1 |
| S2 | the exact constructive solver for the four PCS commitments | DONE — commit (step 1); A, H, Input, Output all exhibited and verified |
| S3 | the masking-commitment (CFS) channel | DONE — commit (step 2); rounds, scalars, both accountings |
| S4 | the `channels` array, 28 channels, the §4.2 fail rules | DONE — 8 constructed / 2 derived / 8 argued / 10 open |
| S5 | negative controls, honest-passes and perturbed-fails | DONE — 7 controls, all fire on all four captures |
| S6 | tests, evidence, report, ledger | DONE — 27 new tests; `results/zk60_native_privacy_gate/`; `ZK60_NATIVE_PRIVACY_GATE.md` |

Gate run (`--columns full --controls-on all`): **four captures, ok, 179.2 s**,
`results/zk60_native_privacy_gate/privacy_gate.json`, marker `0`.

## 1. Commands and logs

| what | command | log |
|---|---|---|
| baseline suite | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native*.py'` | `results/zk60_native_privacy_gate/tests_baseline.log` — Ran 85 in 72.8 s, OK (1 skip) |
| the gate | `python3 scripts/zk60_native_privacy_gate.py --captures results/zk60_native_captures_20260919 --evidence results/zk60_native_privacy_gate --columns full --controls-on all` | `gate_run.log`, `gate_run.done` = 0 |
| suite after | the same discover command | `tests_after.log`, `tests_after.done` — Ran 112, OK (1 skip) |

Both long runs were launched detached (`setsid nohup … ; echo $? > *.done`)
under the no-hangup protocol. Neither takes the heavy lock: the gate is a
single-core Python job of about 380 MB, and the box's other lanes are
building Rust.

## 2. Findings

1. **The preimage exists and is exhibited on every linear commitment
   channel, at both fixed inputs, on all four captures.** Every entry of the
   recomputed view equals the capture's: **802,920 commitment-side entries
   per fixed input** across the four receipts (88,064 group-vector, 8,192
   proximity, 574 claim values, 706,090 opened column values) and **2,676**
   on the masking side (2,594 masked round entries, 82 masked scalars), with
   zero differing anywhere.
2. **The fibre dimension does not depend on the fixed input, by
   construction.** `M_nondata` is a function of `rho`, `rw`, `cw` and the
   sampled nodes only. The gate hashes every matrix it solves and requires the
   digests to be equal across the two runs; the numbers agree (A on the first
   block capture: 47,180 Fp of 178,432 blinding unknowns).
3. **Not every perturbation of `y` stays in the image, and the reason is the
   verifier's own identities.** The column identity and the group identity
   tie the channels together, so perturbing one channel alone leaves the
   image and the gate finds no preimage. The fallback control the brief asked
   for (remove blinding unknowns until the block loses rank) is implemented
   too and also fires.
4. **Two channels refuse a fixed input that is off a public identity, and
   that refusal IS the disclosed dimension.** H's LogUp sum claim: a
   pseudorandom input has no preimage until it is projected onto the plane
   `sum_i rw[i] (row sum) = 0`. The masking commitment: the canonical zero
   transcript is infeasible until it is projected onto the identities the M
   opening pins — 68 Fp of conditions on the conservative accounting, 2 Fp on
   the opening-only one, reproducing stage 3's `disclosed_all_values_fp` and
   `disclosed_opening_only_fp` exactly.
5. **A blinding unknown shared between two commitments has no joint
   preimage, exhibited.** Both per-commitment preimages exist and force
   DIFFERENT values on the shared row at all 256 message positions; each is
   the unique solution of an invertible 2x2 system, so no joint assignment
   exists.
6. **Three channels of the M opening are OPEN by this lane's choice, not for
   want of a capture field**: `q`, the M proximity vector and the M opening's
   own 256 columns. Closing them needs a port of `zk.rs::mask_commit`'s row
   layout and of `encode_coeffs_coset`. No capture field is missing for them.
7. **One capture field IS missing, and the privacy case already asks for
   it**: the unmasked honest round messages of one slot on a synthetic
   fixture (§4.3, the security owner's answer 4(a) to Codex). Without it the
   masking channel's fixed data is a named, publicly computable element of
   the channel's data space rather than the zero witness's own transcript.
8. **Two defects were found and fixed in this lane's own code before any
   number was recorded**: a slice copy that silently discarded the pad
   correction (every pad-half entry then mismatched), and a missing
   dependency order between opening groups (H's zsum claim reads the u pair
   another group owns). Both were caught by the entry-by-entry verification —
   which is the argument for having it.

## 3. What this lane did NOT do

* It did not run, build or touch any Rust. The component's zero-witness
  acceptance test (`hashline/src/private_block/zero_witness_tests.rs`,
  branch `zk60-private-block-125m`, commit `ec84dac`) is CITED in the
  record with `run_by_this_gate: false`.
* It did not change the existing joint-view tool, its tests or its outputs:
  the only files this lane writes are its own three scripts, its own test
  file, its own evidence directory and these two documents.
* It did not claim a privacy property anywhere.

## 4. NEXT

1. **The integrator**: the capture field of finding 7 (one slot's unmasked
   honest round messages on a synthetic fixture, labelled a test fixture),
   and the real-receipt "same commitment opened twice" fixture the privacy
   case's §4.4 also asks for.
2. **This tool, if the security owner wants the last three channels closed**:
   port `mask_commit`'s row layout and `encode_coeffs_coset`, then construct
   the b row, the u row and the a-row pads. The a-row pad solve has the same
   shape as the PCS one (interpolate through the sampled nodes after dividing
   by the vanishing polynomial of the non-pad positions), so the machinery is
   already here.
3. **The security owner**: rung (ii)'s sentence should read "a zero-witness
   preimage was constructed on the linear channels; the hash channels rest on
   M-2 and M-3 and were not constructed", never "P10 passed" (the check's
   §8).
