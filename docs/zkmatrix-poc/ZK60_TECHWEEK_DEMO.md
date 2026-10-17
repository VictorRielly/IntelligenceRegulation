# Tech Week demonstration and delivery gates

Prepared September 29, 2026 by the integrator with GPT-6.1-Sol backend and
readiness reviews. The existing Claude Sonnet 5.5 lane delivers the separate
native stack CLI in `ops/zkp-mvp/candidate`; that candidate is not the public
demonstration's trusted verifier.

## Run the demonstration

From the repository root:

```bash
python3 scripts/zk60_techweek_server.py
```

Open <http://127.0.0.1:8765>. The server binds only to the local machine. It
needs Python 3.10+, the retained artifacts and existing pinned Linux verifier
binaries in this checkout. It has no JavaScript packages, cloud prover, wallet
or network requirement after those files are present. This is not yet a
portable Mac/Windows distribution. Stop the foreground server with Ctrl-C.

Use **Verify a private token computation** first. It verifies a genuine,
previously generated 785-byte Groth16 receipt in a fresh process, then checks
modified proof bytes and an altered policy. The fixed synthetic model has
32 positions, a vocabulary of 32, two complete transformer blocks and a
greedy token step. The model is untrained; no natural-language chatbot is
being demonstrated. The input tokens and output token remain hidden.

The second option checks the retained complete-block Groth16 receipt. The
third option generates a new native T32/d16/f16 complete-block proof using
a **public synthetic input fixture** and fresh private proof randomness.
Its native verifier also runs in a separate process. It is a live proving
demonstration, not evidence that this particular input is secret.

All native commands now run through `scripts/zk60_resource_guard.py` and
require a terminal result matching the native child outcome. The live option
uses the common heavy lock shared with builds, a 1 GiB memory reservation
and a 2 GiB cap for the toy fixture. It waits at most 30 seconds for admission;
proof generation has a 180-second limit. Retained verifiers use the smaller
`light` class. Admission, guard or verifier failures never count as a proof
success or a tamper rejection. Use retained verification during a
meeting if the shared machine is busy; its fast check is **verification of a
previous proof**, never a fast proof-generation claim.

Each run writes a new directory under `results/zk60_techweek_demo`. Download
the report, proof and policy through the page after success. The server serves
only these explicit public artifacts and the page/API. It does not expose
the repository, private witness files or subprocess logs. Downloads are
rehash-checked against the verified report. The server handles at most four
requests concurrently, expires stalled connections and refuses pipes,
symlinks and oversize downloads before allocating a response. Reports are
written atomically; `run.done` appears only after the run ends, so interrupted
attempts retain evidence without a success marker. Reports are local evidence, not
an independent security audit.

Command-line verification is also available:

```bash
python3 scripts/zk60_techweek_demo.py saved --profile token --out /tmp/zk60-meeting-token-01
python3 scripts/zk60_techweek_demo.py saved --profile block --out /tmp/zk60-meeting-block-01
python3 scripts/zk60_techweek_demo.py native --out /tmp/zk60-meeting-native-01
```

Use a new destination for every run. The runner refuses to overwrite evidence.
The saved receipt, policy, program image and binary expectations are pinned
in the runner independently of downloaded candidate files. Native endpoint
commitments are prover-created under D18 and snapshotted before independent
verification; this does not establish a request chosen by an outside client.
Changing or rebuilding a pinned binary requires a reviewed pin update, not
silently accepting whatever program happens to be on disk.

## A two-minute presentation

1. Explain the problem: an AI service needs to show that a named computation
   ran while keeping its inputs and intermediate data private.
2. Run the private-token verification. Show the real receipt size, actual
   verification result, and failed tampered-proof and policy controls.
3. Download the proof and report. Explain that the verifier checks the program
   identity and statement rather than trusting a service's success message.
4. If the machine is free, generate a new native synthetic-block proof. Say
   explicitly that this option uses a public test fixture and fresh randomness.
5. State the development milestone: integrate trained weights and calibration,
   widen the privacy evidence, and measure complete-stack GPU performance.

Suggested wording: “We have working proofs for complete small AI computations
with independently checkable receipts. This demonstration keeps the token
computation's inputs and result private. Our next milestone is a trained-model
pilot with measured end-to-end proving costs.”

The target remains a complete private 8B stack at **at least 50 proved tokens/s**.
There is no measured result meeting that target. Public weights are allowed
by the P1 scope. Groth16 depends on the accepted trusted setup and underlying
zkVM soundness assumptions; endpoint hiding depends on secret salts. The
program images are **locally built, unreproduced**, and timing is declared
leakage. These qualifiers travel with the private zkVM demonstration under
D3/D4/D5/D7. Successful verification does not approve a model's safety,
training, quality, or regulatory compliance.

## Next-week delivery gates

Assume a first rehearsal by Sunday October 4 and the first meeting Monday
October 5 unless Victor supplies another date. These are delivery targets,
not claims of a scheduled event or a promise of trained 8B performance.

| Target | Deliverable | Gate |
|---|---|---|
| September 29–30 | Runnable local proof demonstration | Both retained receipts verify; changed proof/policy are rejected; downloadable evidence matches pins; live synthetic proof is exercised |
| October 1 | Repeatable native stack CLI | Sonnet's small multi-block candidate builds; independent verification and missing/extra/reordered/modified-segment controls pass; exact sources and binaries retained |
| October 2 | Trained-model go/no-go | TinyLlama calibration, profile and importer match the actual model; a trained block executes within range and proves without weakening constraints |
| October 3 | Freeze the meeting build | Repeat demo from a clean launch; rehearse offline on the actual meeting machine; preserve a known-good bundle and commands |
| October 4 | Rehearsal | Two-minute presentation plus technical Q&A; every performance claim links to measured evidence |

If the trained-block gate does not pass, show the working synthetic proof
prototype with that limit. Do not rename an unchanged synthetic shape as a
trained 1B or 8B proof. The
[trained readiness inventory](../../results/zk60_techweek_20260929/trained-readiness.json)
records the critical path: trusted acquisition, versioned calibration and
profile, streamed trained execution, one trained-block proof with rejection
controls, then full 22-block/device measurement. Downloading weights closes
only acquisition. The TinyLlama checkpoint has 1.100B total parameters;
its 22 transformer blocks contain 968.974M, excluding embeddings and head.

The [efficiency researcher](../../ops/zkp-explorer/README.md) runs bounded hourly
cycles while the host is available, independently of the demo server. Its
agenda covers new proving architectures, GPU sumcheck, memory traffic,
preprocessing, KV/state binding and batching. Findings and negative results
go to `research/zkp-efficiency/PROGRESS.md` and dated handoffs for review.
Supervisor liveness is checked on the host; an old status label or sandbox
PID lookup is not evidence that it has stopped.

## Validation

All three modes passed the actual local HTTP flow: 32 checks, including a
new 2,816,472-byte native proof, the two 785-byte retained Groth16 receipts,
downloads and rejection controls. The complete native demonstration took
0.256 seconds; each saved-receipt demonstration took about 0.093 seconds.
These are shared-machine diagnostics for tiny synthetic profiles, including
the controls, not full-model throughput or Groth16 generation measurements.
Evidence: [all-profile HTTP check](../../results/zk60_techweek_20260929/http-smoke-all-profiles.json)
and [independent native check](../../results/zk60_techweek_20260929/native-live-validation/report.json).
The seven new focused tests and 62 existing zkVM-runner tests pass (69 total).

```bash
python3 -m unittest tests.test_zk60_techweek_demo tests.test_zk60_techweek_server -v
python3 scripts/zk60_techweek_smoke.py --out /tmp/zk60-http-check-01.json
# Include the live prover when the shared heavy-job lock is available:
python3 scripts/zk60_techweek_smoke.py --native --out /tmp/zk60-http-check-02.json
```

The HTTP checks require a running server. They exercise real retained
verifiers, check artifact/report downloads, and reject a foreign Host/Origin,
missing request token, invalid mode, and attempts to read private paths.
The browser source is self-contained; these HTTP checks do not establish
rendered-browser compatibility. No full repository regression or new
cryptographic audit is implied by the demo checks.
