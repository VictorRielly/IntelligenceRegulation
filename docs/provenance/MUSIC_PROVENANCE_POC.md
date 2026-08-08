# Proving Music Is Man-Made — Provenance PoC Design

Status: NEW PILLAR, design doc, written 2026-08-07 on Victor's console
directive ("a proof of concept for proving music is man made"; the
classifier plan below is his stated intent, recorded verbatim in
Section 5). First runnable artifact PV-S1 landed the same day:
`scripts/music_provenance_spike.py`, 7/7 OK — the mixdown statement
class proven end to end with the repo's own `zk_lattice` Pi1.
House discipline applies throughout: measured numbers are labeled,
modeled numbers carry [MODEL], external facts not verifiable from this
repo carry [EXTERNAL — verify at build time].

Related in-repo precedents: `contentzkpfilterpoc (1).py` (ezkl demo —
a BERT-tiny policy classifier proven over a hash-committed private
input with a public verdict) and `docs/zkmatrix-poc/README.md`
Milestone 8 (content-governance integration). There is no prior audio
or provenance work in the repo; this pillar is greenfield.

## 1. The claim, stated honestly

"This music was made by humans" is NOT provable over bare bits: any
waveform, however produced, is just numbers, and a generative model
can in principle emit any of them. Every workable scheme therefore
proves a different, adjacent claim and is honest about the residue:

> **The provable claim.** "This published master derives, through a
> declared chain of allowed edits, from waveforms that entered
> certified capture devices at stated times — and no other source."

That claim IS provable, with two cryptographic layers and one
statistical screen:

| layer | claim | guarantee class |
|---|---|---|
| 1. Attested capture | these takes entered certified device D at time T | cryptographic (device PKI + hash chain), MINUS the analog hole |
| 2. ZK edit chain | master = f(takes), f in the allowed edit family, takes never revealed | cryptographic (the house ZK machinery) |
| 3. Laundering screen | the takes are not microphone recordings OF AI-generated audio played into the mic | statistical ONLY — a classifier score, never a proof |

The analog hole — play AI audio through a loudspeaker into an attested
microphone and collect a genuine capture chain over AI content — is
the irreducible gap of layer 1. No cryptography closes it. Layer 3
(Victor's classifier plan, Section 5) RAISES ITS COST; it does not
close it either, and every label the system emits must carry that
distinction: layers 1-2 are proofs, layer 3 is a screen.

## 2. Layer 1 — attested capture

Per take: the recorder chunks PCM into frames and maintains a hash
chain h_i = H(h_{i-1} || frame_i) seeded from the take metadata
(device id, session, wall time, sample rate); at take end the device's
secure element signs (chain digest || metadata). Verification walks
the chain and checks the signature against the device-class PKI.

- Precedent [EXTERNAL]: C2PA content credentials; signing cameras
  exist as shipped products (Leica M11-P class). Attested MICROPHONES
  are not an established product category — the PoC therefore
  SIMULATES the device (a signing wrapper around capture), which
  changes nothing about the protocol shape and everything about the
  deployment claim. Stated on every artifact.
- PoC form (PV-S1, landed): SHA-256 frame chain + HMAC device tag
  (stand-in for the secure-element signature), tamper legs green
  (flipped frame breaks the chain; forged tag rejects; an unchained
  AI master has no evidence to present).
- Deployment notes for later rounds, recorded now: device key
  extraction breaks the layer for that device class (revocation
  lists); timestamps need either a trusted clock or an external
  anchor (e.g. chain digest posted to a transparency log within the
  session window); multi-take sessions should cross-commit (each
  take's metadata carries the session digest) so a session is one
  evidence object, not loose files.

## 3. Layer 2 — the ZK edit chain

Musicians do not publish raw takes; they mix and master. The layer-2
statement binds the published master to committed (never-revealed)
takes through a declared edit family. The load-bearing observation:

> **The production edit chain decomposes into exactly the gadget
> classes the LLM proof engine already has.**

| edit operation | algebraic form | house gadget class |
|---|---|---|
| mixdown of N takes | matrix multiply (gains x takes) | committed matmul (zkMatrix / Route R) |
| static gain, panning | scalar/row scaling | matmul (fold into the mix matrix) |
| fades, gain automation | per-sample diagonal scaling | Hadamard gadget (U-E2 slot machinery) |
| FIR EQ, resampling | Toeplitz/convolution matmul | committed matmul |
| trims, splices | selection matrix | matmul with a 0/1 matrix + range/binary facts |
| compressor, limiter, saturation | pointwise nonlinear y = f(x) | the committed int8 LOOKUP gadget (M4 LogUp-GKR family — a compressor transfer curve is a frozen table, exactly like SiLU) |
| requantization, dither | rescale + bounded remainder | range family (q46 link) |
| perceptual codec (mp3/AAC/Opus) | non-linear, non-local | OUT OF PROOF BOUNDARY — publish the lossless master's digest; lossy encodes are declared derivatives, not proven ones |

So the music pillar needs NO new cryptographic gadget classes: it is a
new STATEMENT over the same family the FFN chain exercises
(matmul + Hadamard + lookup + range). That is the central feasibility
fact for this pillar, and it cuts both ways: the music PoC inherits
the engine's maturity schedule (matmul claims at scale are still
unmeasured in Rust — TARGET_CONTRACT Section 5), and the music PoC is
a second client that justifies the build round's generality.

PV-S1 (landed, `scripts/music_provenance_spike.py`) proves the
statement class at toy scale TODAY with the pure-Python `zk_lattice`
Pi1 — the A-public/B,C-committed split maps exactly to "edit
parameters public, takes private": master(1x1024) = gains(1x4, public)
x takes(4x1024, committed), integer-exact at q = 2^61-1, honest
ACCEPT + three REJECT legs, prove 1.06 s / verify 0.05 s pure Python
[MEASURED, toy shape; toy soundness 2^-56, NO concrete lattice
hardness at toy dims — reference_params + estimator for any security
claim].

Privacy note (the A1 vocabulary applies verbatim): takes are the
accumulation-light class (fresh witness per work, like activations);
a fixed private MIX preset re-proven across many releases would be
weight-class (accumulates across proofs) and takes the masked path.
The mode table of TARGET_CONTRACT Amendment A1 (P0-P3) carries over
with "takes" for inputs and "edit parameters" for weights.

## 4. What the verifier checks, end to end

1. Layer-1 evidence: every source take's chain digest + device
   signature verifies against the device PKI; session cross-commit
   consistent; timestamps anchored.
2. Layer-2 proof: the ZK edit-chain proof verifies: committed takes
   (matching the layer-1 digests) through the declared edit family to
   the published master's digest.
3. Layer-3 screen: the certified classifier's score on the master
   (and, where the deployment allows, on committed take excerpts
   under ZK — Section 5.4) is below the replay-laundering threshold.
4. Label emitted: "capture-attested + edit-proven (cryptographic);
   laundering screen passed at score s, model v, threshold t
   (statistical)". Never a bare "human-made" stamp.

## 5. Layer 3 — the analog-hole screen (the classifier plan)

Directive being documented (Victor, console, 2026-08-07): "For the
issue of proving the microphone recordings are not recordings of
audio from AI generated content, I plan to use a classification model
based on the work being done in the frugal-llm repository."

The repository is `/Users/victorrielly/frugal-lm` (MLX, Mac Studio,
from-scratch LM training ladder 125M -> 360M -> 1B; M0/M1 complete,
M2 code done). It contains NO classifier work today — the plan is to
REUSE ITS TRAINING STACK (the MLX training loop, the
Llama-3-class transformer implementation, the run/config/results
discipline) for a small audio classifier, not to reuse an existing
model. Recorded as such.

### 5.1 What the classifier must actually decide

Two separable sub-problems, and the distinction matters:

- (a) **Replay detection** ("physical access" in the anti-spoofing
  literature): was this capture a microphone recording of a
  LOUDSPEAKER, rather than of live acoustic sources? Loudspeaker
  playback leaves physical signatures — band-limiting, driver
  nonlinearity, the speaker-room-mic double reverberation — and this
  is the classifier's primary target, because ANY laundering of AI
  audio through an attested mic must transit a transducer.
- (b) **AI-content detection**: does the audio itself carry
  generative-model artifacts? Useful as a second signal on the
  published master, but it is an arms race against improving
  generators and must be weighted accordingly.

(a) is the better-posed problem: it fires on the LAUNDERING CHANNEL
(a physical necessity) rather than on the generator (an adversary's
choice). The ASVspoof physical-access literature [EXTERNAL] shows
replay detection with strong in-domain error rates and known, sharp
degradation across devices/rooms — the plan below assumes both
halves of that finding.

### 5.2 Model and training plan (the frugal-lm reuse)

- Input: log-mel spectrogram patches (plus a raw-waveform stem as an
  ablation — replay artifacts are partly phase/high-frequency
  phenomena that mel front-ends can blur [MODEL]).
- Model: small encoder transformer in the frugal-lm stack —
  spectrogram frames as the token sequence, mean-pool + linear head.
  The 125M config (12 x 768, SwiGLU 2048) is the CEILING, not the
  target; anti-spoofing detectors are typically well under 25M
  parameters [EXTERNAL]. Start at a ~10-25M variant of the frugal-lm
  ladder; the ladder discipline (configs, throughput benchmarks,
  run ledgers) carries over unchanged.
- Data, three tranches:
  1. Replay pairs, SELF-COLLECTED with the PV rig: known-human
     masters played through K loudspeakers into M microphones in R
     rooms, against direct captures of the same performances. The
     attested-capture rig makes collection cheap and labels exact.
  2. Public anti-spoofing corpora for the replay class (ASVspoof
     2019/2021 PA lineage) [EXTERNAL — speech-domain; domain gap to
     music acknowledged].
  3. AI-music sets for signal (b): generations from current
     music models vs licensed human tracks [EXTERNAL — dataset
     availability and licensing verified at build time].
- Report: EER / AUC on held-out splits, with the CROSS-DEVICE and
  CROSS-ROOM splits reported separately and first — the in-domain
  number is not the deployable number. Calibration curve published
  with the model digest.

### 5.3 Feasibility — the honest assessment

- FEASIBLE as a screen: the transducer channel is physically real,
  self-collected replay data is cheap here, the model class is
  years-standard, and the frugal-lm stack is a suitable trainer.
  Expect useful in-domain separation and meaningfully worse
  cross-condition numbers [MODEL until measured].
- NOT feasible as a proof, structurally: a resourced adversary with
  studio monitors, a treated room, and inverse-EQ optimization
  attacks the exact artifacts the classifier keys on; generative
  models improve under signal (b); and a classifier score cannot be
  adversarially sound the way the ZK layers are. The classifier
  raises the cost and scale-difficulty of laundering. That is the
  claim, in full.
- Base rates: at platform scale, even a 1% false-positive rate on
  honest human music is enormous in absolute terms. The score is a
  GATE TO REVIEW, never an automated verdict; the appeal path is a
  witnessed or re-attested session (re-perform under supervised
  capture), which the layer-1 infrastructure makes natural.
- Governance posture: publish the model digest, threshold, and
  evaluation protocol; version the model; expect and budget for
  periodic retraining as generators move. The label format
  (Section 4) keeps the statistical layer visibly statistical.

### 5.4 The unification — proving the classifier itself

The screen creates a new trust question: did the platform actually
run the certified detector, at the certified threshold, on this
audio? That question is THE FLAGSHIP ZK-of-LLM deployment shape:

- `contentzkpfilterpoc (1).py` already demonstrates it at toy scale
  (ezkl: BERT-tiny verdict over a hash-committed input, weights
  fixed, verdict public);
- the frugal-lm-stack detector is a small transformer in exactly the
  125M-class shape family that PROGRESS_UAG4.md names as U-AG-B1's
  first integration rung;
- so the detector can become the FIRST REAL MODEL the lattice engine
  proves end to end: "certified detector v_X, committed weights,
  scored s on committed audio" — P2 mode (weights private or fixed,
  input private, verdict public), Tier Z pass budget per Amendment
  A1.

One small model then serves both pillars: the gatekeeper the
provenance system deploys, and the first end-to-end artifact the
ZK-of-LLM PoC proves. See docs/zkmatrix-poc/LLM_POC_ROADMAP.md.

## 6. Threat model (summary table)

| attack | layer hit | disposition |
|---|---|---|
| forge/alter a take after capture | 1 | broken by the hash chain (PV-S1 leg 2) |
| clone/extract a device key | 1 | device-class revocation; residual risk stated on the label |
| analog hole: play AI audio into an attested mic | 1->3 | NOT closable cryptographically; classifier screen + cost-raising (multi-track consistency below) |
| lie about the edit chain | 2 | impossible within the allowed family (ZK proof fails); edits outside the family are declared, not proven |
| "mix in" an AI stem as a take | 1+2 | every take needs its own capture chain — an AI stem has none; smuggling it requires the analog hole per stem |
| replay a full multi-track session through speakers | 3 | the expensive version of the analog hole: N takes must be laundered with mutually consistent room/bleed signatures — raises attacker cost sharply [MODEL]; primary classifier target |
| timestamp fraud | 1 | transparency-log anchoring within the session window |
| adversarial evasion of the classifier | 3 | expected at the margin; screen-not-proof labeling, thresholds versioned, human review path |

The multi-track lever deserves emphasis: requiring SESSION-level
attestation (all stems, cross-committed, with consistent timing and
acoustics) multiplies the laundering workload by the stem count and
adds a consistency surface the classifier can test [MODEL]. Solo
single-track uploads get weaker labels than full attested sessions —
a natural, honest quality gradient.

## 7. PoC exit criteria and build plan

Exit criteria (each checkable; the PoC is complete when all five
hold):

- PV-1: capture-attestation rig (simulated device) producing
  session-level evidence objects for real WAV multi-track input.
- PV-2: ZK edit-chain proof for mixdown + gain automation (fades) of
  a real session (minutes of audio, block-chained), verified by an
  independent CLI; takes never revealed. Backend: `zk_lattice` at
  reference params, or the Rust engine if the B1 round's matmul
  statement lands first.
- PV-3: classifier v0 trained in the frugal-lm stack; EER/AUC
  reported in-domain AND cross-device/cross-room; model digest +
  threshold + calibration published.
- PV-4: provable-classifier bridge demonstrated at toy scale (the
  ezkl path re-run on the v0 architecture, OR the house-engine
  statement for its FFN blocks — whichever lands first).
- PV-5: end-to-end demo: attested human session ACCEPT with full
  label; AI master REJECT (no evidence); laundered replay FLAGGED by
  the screen; label format of Section 4 emitted in all three cases.

Build plan:

- PV-S1 (DONE 2026-08-07): statement-class spike, 7/7 —
  `scripts/music_provenance_spike.py`.
- PV-S2: WAV I/O + session evidence objects + block-chained Pi1 at
  song scale; measure prove/verify at reference params.
- PV-S3: replay-pair data collection protocol + classifier v0
  training runs in frugal-lm (new `configs/audio-detector-*.yaml`
  family there); the evaluation report.
- PV-S4: the provable-classifier bridge (5.4).
- PV-S5: the end-to-end demo + label emitter; feasibility
  re-assessed against measured EER numbers.

## 8. Feasibility verdict (the summary Victor asked for)

- Layers 1-2 (attested capture + ZK edit chain): FEASIBLE NOW at PoC
  grade with in-repo machinery (PV-S1 is running proof); production
  grade needs a real device-attestation ecosystem [EXTERNAL] and the
  engine's scaled matmul statement (shared with the LLM roadmap).
- Layer 3 (the classifier): FEASIBLE as a cost-raising statistical
  screen with the frugal-lm stack; NOT a proof, and must never be
  labeled as one. The replay-detection framing (5.1a) is the right
  primary target; cross-condition generalization is the known hard
  part and the numbers that matter are the cross- splits.
- The strongest available claim remains conditional: cryptographic
  provenance of capture and edits, plus a priced, versioned,
  reviewable screen on the analog hole. That combination is honest,
  buildable, and — via 5.4 — feeds the ZK-of-LLM PoC its first real
  deployed model.
