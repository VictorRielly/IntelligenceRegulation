# ZK60 — private T32/d16/f16 block by exact re-execution in RISC Zero v3

Fable 5.1 delivery, 2026-09-18, baseline `5d6f101`. Owned files: this memo,
`scripts/zk60_zkvm_contract_probe.py`, `tests/test_zk60_zkvm_contract_probe.py`.
No production source changed, nothing committed, no zkVM run, no proof made.

**This memo does not claim the P1 target is reached.** It assesses one
construction, fixes its public statement byte for byte, and lists what must
be built, verified and decided. P1 still hides inputs, outputs and
intermediates; the caller-fixed-endpoint obligation of
[ZK60_MVP_REVIEW.md](ZK60_MVP_REVIEW.md) is kept, not narrowed. The tiny block
is an intermediate, not an 8B performance result.

## 0. Verdict

1. **Valid functional intermediate: yes, conditionally.** Running the exact
   integer block as a RISC-V guest and publishing only a fixed 260-byte journal
   of public digests and salted endpoint commitments removes the custom
   PCS/sumcheck simulator from the privacy argument. Endpoint commitments
   become plain statement bytes that the proof never opens, so "simulate for a
   caller-fixed valid root" is the ordinary zero-knowledge experiment of a
   general-purpose NIZK, for which the simulator receives the statement only.
2. **It is a protocol change, not a closure of the old gate.** The endpoint
   handle changes from a seven-row PCS root to a salted SHA-256 commitment
   under a new domain-separated profile. Old PCS endpoint roots and PCS weight
   roots are **not** compatible and nothing here implies they are. Whether this
   change "supports the same statement" in the sense of the MVP review's next
   gate is the parent's / Victor's ruling.
3. **Required public receipt kind: Groth16.** A composite receipt exposes
   per-segment machine state and must never leave the prover. A succinct
   receipt's hiding rests on RISC Zero's STARK blinding, for which I can point
   to no reviewed theorem at the actual parameters. For a Groth16 receipt the
   whole public artifact is (journal, image ID, one Groth16 proof), and
   Groth16's perfect zero knowledge is a published theorem (§5). Succinct is
   admissible only under an explicit, recorded "vendor-ZK" opt-in.
4. **The ≥128-bit target is NOT met and cannot be met by configuration.**
   RISC Zero's own figures are below 100 bits conjectured for the STARK layers
   and about 100 bits for BN254 Groth16 (§6). This is a concrete barrier. It
   needs an explicit ruling for the intermediate; I do not waive it.
5. **Groth16 adds a trusted setup** (soundness only) and, in the locally
   installed 3.0.6, **Docker** (§6, §1). Dev-mode "fake" receipts must be
   refused by construction (§7).
6. **Wrapping the existing public argument buys nothing at this size** and
   costs soundness and roughly two orders of magnitude more guest cycles; it
   is a possible later scaling route only (§11).
7. **Not locally buildable today.** The box has `r0vm`/`cargo-risczero`
   3.0.6 but no RISC Zero Rust guest toolchain and no `risc0-*` crate source
   (§1). Both need a network fetch that root must decide on.

## 1. Evidence base, and what was blocked

Labels used below:

- **[LOCAL]** observed in this session in files on this box.
- **[RECALLED]** my recollection of upstream RISC Zero source/docs. **Not
  verified in this session.** Each carries the upstream path to check; §15
  collects them as a gate. Treat every [RECALLED] item as a claim to confirm,
  not as a finding.
- **[MODEL]** arithmetic estimate, unmeasured.

Blocked in this session (automatic denial, no approval surface): `ls` outside
the worktree, executing `r0vm`, `WebFetch`, `WebSearch`, and running the probe
script directly (its tests ran under the allowlisted `python3 -m unittest`).
I therefore could not read official docs or upstream source. The requested
"actual local RISC0 source in `~/.cargo/registry/src`" **does not exist**:

| Fact | Evidence |
|---|---|
| Installed: `cargo-risczero` 3.0.6, `r0vm` 3.0.6, C++ toolchain 2024.1.5 | [LOCAL] `/home/victor/.risc0/settings.toml`; binaries under `/home/victor/.risc0/extensions/v3.0.6-cargo-risczero-x86_64-unknown-linux-gnu/` |
| No RISC Zero **Rust** guest toolchain | [LOCAL] `~/.risc0/toolchains/` holds only `v2024.1.5-cpp-…`; glob for `*rust*` is empty. `settings.toml` has no `rust` entry |
| No `risc0-*` crates in the cargo registry; no `~/.cargo/git` | [LOCAL] grep of every `Cargo.toml` under `~/.cargo/registry/src` for `risc0`: none. An `--offline` host build cannot succeed |
| Receipt variants `Composite`/`Succinct`/`Groth16`/`Fake`; `SegmentReceipt{index, hashfn, verifier_parameters, …}`; `SystemState{pc, merkle_root}` | [LOCAL] type/field names embedded in `r0vm` (source paths `risc0/zkvm/src/receipt.rs`, `receipt/composite.rs`, `receipt/segment.rs`, `receipt/succinct.rs`) |
| `ProverOpts` carries `hashfn`, `prove_guest_errors`, `receipt_kind`, `control_ids`, `max_segment_po2`, dev-mode flag; CLI has `--receipt-kind` and a segment po2 limit | [LOCAL] `r0vm` strings |
| Recursion accepts only Poseidon2 | [LOCAL] `"recursion programs only supports poseidon2 hashfn"`, `supported hashfn values are: "poseidon2"` |
| Groth16 proving shells out to Docker | [LOCAL] `risc0/groth16/src/prove/docker.rs`, `"Please install docker first."`, image `risczero/risc0-groth16-prover:v2025-04-03.1`, work files `input.json` / `proof.json`, env `RISC0_WORK_DIR` |
| Dev mode exists and is warned about | [LOCAL] `"WARNING: proving in dev mode. This will not generate valid, secure proofs."`; `"zkVM: dev mode is disabled. Unset RISC0_DEV_MODE environment variable to produce valid proofs"`; symbol `is_dev_mode_enabled_via_environment`; `"dev mode must be enabled to compress fake receipts"` |
| The build computes its own security estimate | [LOCAL] `risc0/zkp/src/prove/soundness.rs` with output labels `conjectured_security:` and `proven_soundness_error:` |
| Proof-of-verifiable-work plumbing present | [LOCAL] `povw_job_id` |

String evidence shows that a name exists in the 3.0.6 build. It does not show
semantics. Semantics below are [RECALLED] unless stated.

## 2. What the route removes, and what it substitutes

The open gate is a joint simulator over commitments, CFS messages, terminal
masks and PCS openings for a **caller-fixed** endpoint root. It is hard
because the proof *opens* the endpoint commitment: authentication paths under
a fixed Merkle root cannot be produced without preimages
([ZK60_ENDPOINT_SIMULATION_MODEL.md](ZK60_ENDPOINT_SIMULATION_MODEL.md)).

Here the relation is

> ∃ (x, salt_in, salt_out) : C_in = Com(ctx, model, calib, l, salt_in, x) ∧
> y = Block_l(W, calib; x) exactly over machine integers, no overflow ∧
> C_out = Com(ctx, model, calib, l+1, salt_out, y) ∧
> H(W) = weights_digest ∧ H(calib) = calibration_digest,

and the proof is a NIZK for the fixed guest program. C_in and C_out are inputs
to the statement. They are never opened, partially or otherwise. Consequences:

- The "external statement, root-only" experiment is the **default** ZK
  experiment: the simulator is given (image ID, journal) and nothing else.
  No hash is programmed for the endpoint commitments.
- There is no pad budget. Repeating a proof about the same commitment does
  not consume or expose anything of it (contrast START_HERE's cached-column
  leak after ~65 proofs).
- Field-alias and range-fact obligations disappear: arithmetic is `i32`/`i64`
  in a proven RISC-V execution, with overflow made a guest abort (§3).

What is substituted, all of which must be stated in any claim:

- the zero knowledge of the chosen receipt kind (§5), an external property of
  a third-party system, plus faithfulness of its implementation;
- computational hiding of salted SHA-256 commitments. This is a standard
  random-oracle-style **assumption**; I assert no theorem for it;
- a lower security level and, for Groth16, a trusted setup (§6);
- trust in the RISC Zero toolchain, circuits and recursion programs, which is
  a far larger trusted code base than `hashline/`.

## 3. Construction

Roles are unchanged from P1: the prover acts for the IO owner and sees x and
y; the verifier sees neither.

**Shared kernel crate** (Opus lane): `no_std`, no floats, no `unsafe`, no
data-dependent allocation. One function
`block(weights, calib, x: &[i16; 512]) -> Result<[i16; 512], Refusal>`
computing the exact T32/d16/f16 block of
[ZK60_BLOCK_CONTRACT.md](ZK60_BLOCK_CONTRACT.md) (round-only RMSNorm, fixed
shifts/classes, integer softmax, frozen tables; **never** `fit_*`). All
arithmetic through `checked_*`; the guest profile sets
`overflow-checks = true` and `panic = "abort"`. An out-of-class intermediate is
a refusal, never a wrap or a refit.

**Guest** (new crate, outside `hashline/`): read one fixed-length input frame
to end of stream and abort on any length mismatch; compute
`weights_digest`/`calibration_digest` over exactly the bytes it will use
(this also touches every table page unconditionally, §9); run the kernel;
compute both endpoint commitments with the accelerated SHA-256; write the
journal with a single `env::commit_slice(&[u8; 260])`. No `env::log`, no
`env::write` to other descriptors, no `env::verify` (no assumptions), no
`env::pause`. Abort messages are static strings with no formatted values.

**Host prover**: constructs the local prover explicitly (never
`default_prover()`, which [RECALLED] selects Bonsai when `BONSAI_API_KEY` /
`BONSAI_API_URL` are set and would upload the private input); refuses to start
if `BONSAI_*`, `RISC0_DEV_MODE` or a PoVW option is present; draws both salts
from the OS CSPRNG per endpoint; proves with `ProverOpts::groth16()`; runs the
Docker stage with a private `RISC0_WORK_DIR` on tmpfs and removes it; publishes
**only** the Groth16 receipt. Composite, succinct and `identity_p254`
intermediates, the input frame, executor traces, segment files and guest
stdio are prover-private and are not written to shared paths or logs.

**Verifier** (separate small binary; depends on `risc0-zkvm` with
`default-features = false`, no `prove`/`client`, feature `disable-dev-mode`
[RECALLED name], version pinned with `=`):

1. size-limit and decode the receipt; reject trailing bytes;
2. `match receipt.inner`: accept `Groth16` only (or `Succinct` under the
   opt-in). `Receipt::verify` by default accepts every kind [RECALLED], so this
   explicit match is load-bearing;
3. refuse if `RISC0_DEV_MODE` is present in its own environment, any value;
4. `receipt.verify(IMAGE_ID)` with IMAGE_ID from the verifier's approved
   registry, never from the receipt or the prover's build output;
5. rebuild the expected 260-byte journal from its own registry values and the
   caller's independently fixed endpoints and compare **bytes**
   (`verify_journal` in the probe). It never parses values out of the
   candidate journal to decide acceptance;
6. check context freshness in its own replay table. A receipt is a
   transferable proof; the context digest binds it to a request, the verifier
   enforces single use.

## 4. The public statement (executable: the probe)

`scripts/zk60_zkvm_contract_probe.py` fixes the layout; 19 tests in
`tests/test_zk60_zkvm_contract_probe.py` pass
(`python3 -m unittest discover -s tests -p "test_zk60_zkvm_contract_probe.py"`,
2026-09-18, this worktree). All integers little-endian; every tag is 32 bytes,
ASCII NUL-padded, prefix `ZK60/zkvm-p1-block/`.

Journal, 260 bytes, no optional or variable fields:

| offset | bytes | field |
|---:|---:|---|
| 0 | 32 | tag `…/journal/v1` |
| 32 | 24 | T=32, d=16, f=16, heads=2, kv_heads=1, head_dim=8 (u32 each) |
| 56 | 4 | layer index, 0..=31 |
| 60 | 4 | privacy mode = 1 (P1) |
| 64 | 4 | reserved = 0 |
| 68 | 32 | context digest = SHA-256(tag ‖ u32 len ‖ caller context) |
| 100 | 32 | approved model artifact ID |
| 132 | 32 | weights digest (tag ‖ layer ‖ nine int8 tensors, each id‖rows‖cols‖bytes, fixed order) |
| 164 | 32 | calibration digest (tag ‖ u32 len ‖ kernel lane's canonical blob) |
| 196 | 32 | input commitment (boundary l) |
| 228 | 32 | output commitment (boundary l+1) |

Endpoint commitment = SHA-256 of a fixed 1200-byte preimage:
tag(32) ‖ context(32) ‖ model(32) ‖ calibration(32) ‖ boundary u32 ‖ T ‖ d ‖
bits=16 ‖ **salt(32, offset 144)** ‖ 512 × i16.

Design decisions and their reasons:

- **Boundary index, not an in/out role.** The output of layer l and the input
  of layer l+1 are the same bytes when the owner reuses salt and values, so a
  two-block chain needs no seam argument: the verifier checks
  `journal_l.output == journal_{l+1}.input`. Reuse is harmless here because
  the commitment is never opened. Swapping endpoints inside one journal
  changes the boundary and fails (tested).
- **Context, model and calibration inside the commitment.** A commitment
  cannot be replayed under another request, model or scale set; equal integer
  words at different scales are different statements (the A00 concern).
- **Whole-journal byte equality** leaves no parser in the acceptance path.
  `decode_journal` exists for diagnostics and is equally strict.
- **Pinned vector** for the Rust guest: fixture journal SHA-256
  `d0301af975dbe36e773c6f732abe16d195fc213cf4bfd9a1162d4d641bd380b5`, input
  commitment `b6de5c6a…3d86b7`. The fixture's "output" is a serialization
  vector, not a block result; its salts are public test values.
- The image ID is **not** in the journal; it is the receipt claim's pre-state
  and is checked by `verify(IMAGE_ID)`.

The probe's tests are serialization evidence. They are not privacy evidence.

## 5. Receipt kinds: what each exposes, and which is required

| Kind | Public content beyond (image ID, journal) | Verdict |
|---|---|---|
| Fake | none; **no proof at all** | refuse always (§7) |
| Composite | one STARK seal and one `ReceiptClaim` **per segment**: segment count, each segment's po2 (seal length), and each boundary's `SystemState{pc, merkle_root}` | **never public** |
| Succinct | one recursion STARK seal, one claim | opt-in only, labelled vendor-ZK |
| Groth16 | one Groth16 proof, one claim digest | **required for the privacy artifact** |

**Composite.** [LOCAL] the types carry `SystemState{pc, merkle_root}` per
segment. [RECALLED] `merkle_root` is the root of the full guest memory image
at the split, a deterministic unsalted hash. After the input frame is read,
that memory holds x, both salts and live intermediates. Two hazards follow.
(a) It is a handle on private state outside the contract's salted commitments;
its hiding would rest on "some page holds a 256-bit salt", which nobody has
argued and which fails for any boundary before the salt is read or after it is
dropped. The probe test
`test_unsalted_state_digest_confirms_a_guess…` illustrates the inference (an
unsalted digest confirms a guessed input); it is **not** an attack on a RISC
Zero artifact. (b) Segment count and po2 reveal cycle count, which is
input-dependent unless §9's gate passes. A composite receipt also hands the
verifier many more STARK transcripts to reason about. None of this is needed,
so the rule is absolute rather than argued case by case.

**Halt, never pause.** [RECALLED] `ReceiptClaim::ok` expects the post-state of
a `Halted(0)` session to be the zero state, so a halted succinct/Groth16 claim
carries no memory root; a `Paused` claim carries a live one.
`Receipt::verify` rejects anything but `Halted(0)` with an all-zero input and
empty assumptions. Check: `risc0/zkvm/src/claim/receipt.rs`,
`risc0/zkvm/src/receipt.rs` near the [LOCAL] event sites `:348`, `:802`.

**Succinct.** Hiding depends on the STARK prover's trace blinding (random
"ZK cycles" rows and salted/blinded commitments) in both the rv32im and
recursion provers. [RECALLED] `risc0/zkp/src/lib.rs` defines `ZK_CYCLES` next
to `QUERIES`, with a source comment to the effect that the tap structure means
it "needs to be bigger". If that comment is still present in 3.0.x it is a
direct statement that the blinding margin is heuristic. I know of no published
zero-knowledge proof for RISC Zero's STARK at its shipped parameters. That
makes succinct-receipt privacy a vendor design claim. It may well be fine; it
is not something this project can currently cite.

**Groth16.** The public artifact is a Groth16 proof whose public inputs are
[RECALLED] the control root, the claim digest and the BN254 control ID, all
functions of (toolchain version, image ID, journal). The succinct seal is the
Groth16 *witness* and stays with the prover. Groth16 has perfect zero
knowledge (Groth, EUROCRYPT 2016, ePrint 2016/260; the main construction's
theorem — I have not re-read it this session, so confirm the statement and
number before quoting): for a well-formed CRS the simulator outputs identically distributed proofs from the
statement and trapdoor alone. Hence the verifier's view is simulatable from
(image ID, journal) **whether or not the inner STARKs hide anything**. That is
the reason to require this kind. Premises to check, not assume: the shipped
CRS is well-formed (subversion-ZK needs CRS checks; Fuchsbauer, PKC 2018); the
Docker prover draws Groth16's r, s fresh from a CSPRNG; the public inputs are
exactly as recalled. Groth16 proofs are re-randomizable, so receipt bytes are
not a unique identifier; harmless here.

## 6. Security level against the ≥128-bit target; trusted setup

The ≥128-bit figure is the target given in this task's brief
(`SOUNDNESS_REFERENCE.md:144` uses 128 bits as the lattice line's yardstick);
`START_HERE.md:212` records the hash line itself at 106 bits default and
95–98 compact, so the existing line is also below it.

| Layer | Vendor figure | Basis | Label |
|---|---|---|---|
| rv32im segment STARK | 96–98 bits | random oracle + ethSTARK "toy problem" conjecture; 50 FRI queries, rate 1/4, degree-4 BabyBear extension (~124-bit field) | [RECALLED] `dev.risczero.com/api/security-model`, `risc0/zkp/src/lib.rs` |
| recursion STARK (lift/join/resolve) | 99 bits | same | [RECALLED] |
| STARK→SNARK | "99+" bits | BN254 pairing (≈100 bits after exTNFS), knowledge-of-exponent/generic group, ceremony integrity | [RECALLED] |
| Poseidon2-BabyBear digests | 8 × 31-bit words ⇒ ≤124-bit collision bound | structure | [RECALLED] |
| proven (non-conjectured) FRI bound | materially lower; I do not recall a number | — | obtain from the build, below |

I am confident of the ordering (everything below 128, BN254 ≈ 100) and not of
the exact integers. **Exact values must come from the installed build**:
[LOCAL] 3.0.6 contains `risc0/zkp/src/prove/soundness.rs`, which emits
`conjectured_security:` and `proven_soundness_error:`. Root's first proving run
records both at the actual po2, with the log configuration that enables them
(to be located in that source file once fetched).

**Barrier.** `QUERIES`, the rate, the extension degree and the digest width
are compile-time constants baked into the recursion verifier circuits, the
control IDs and the Groth16 circuit with its ceremony output. No `ProverOpts`
field raises them. Reaching 128 bits means a different proof system, not a
setting. The composed system is at best about min(96–98, 99, ~100) bits
conjectured, and lower under proven bounds. **The requirement is unmet.** The
intermediate can proceed only under an explicit ruling that records the
measured figure as a deviation; this memo does not grant one.

**Trusted setup.** Composite and succinct: transparent, none. Groth16:
circuit-specific CRS from RISC Zero's public ceremony [RECALLED]; soundness
fails if every participant colluded (a holder of the trapdoor forges any
receipt, including for a false block result). Zero knowledge does **not** rest
on ceremony honesty, only on CRS well-formedness. So Groth16 trades a
soundness assumption for a citable privacy argument. The project currently
lacks the latter, which is why I recommend it for this intermediate while
recording the former as a limit.

## 7. Dev mode and fake receipts

[LOCAL] strings confirm the mechanism exists in 3.0.6. [RECALLED] semantics:
with `RISC0_DEV_MODE` truthy the prover skips proving and returns
`InnerReceipt::Fake`; a verifier *also* running with dev mode enabled accepts
it; the `disable-dev-mode` cargo feature compiles the acceptance path out and
makes a set variable a hard error (the [LOCAL] "dev mode is disabled. Unset
RISC0_DEV_MODE…" message). v3 may also expose a dev-mode switch on
`VerifierContext`; check `risc0/zkvm/src/receipt.rs` and
`risc0/zkvm/src/lib.rs::is_dev_mode_enabled_via_environment`.

Contract: three independent barriers, each with its own acceptance case
(§13 D1–D4): the feature flag; the explicit `InnerReceipt` match; the
environment refusal. Development uses executor-only runs (no receipt) rather
than fake receipts, so no fake receipt is ever a fixture that "verifies".

## 8. Joint and repeated proofs

- **Same statement, many proofs.** Groth16 zero knowledge is perfect, so any
  number of adaptively requested proofs under one CRS is simulated proof by
  proof from statements alone; joint views compose with no loss. This is the
  standard multi-theorem consequence of *perfect* ZK and is the property the
  custom line could not get from marginal rank checks (the MVP review's
  `H(mask)`, `mask ⊕ witness` counterexample does not arise, because no
  prover randomness is shared between a commitment and a proof message).
- **Shared endpoints across blocks / requests.** Two journals may carry the
  same commitment (the chain case). The joint view is (commitments, proofs);
  proofs simulate from statements, so what remains is the joint hiding of the
  commitments themselves: fresh 32-byte CSPRNG salt per *distinct* endpoint
  value; reuse of (salt, value) only to reproduce the identical commitment.
  Equal commitments publicly reveal equality of endpoints. That is inherent
  to chaining and must be listed as declared leakage.
- **Same x, fresh salts, different contexts**: commitments are unlinkable
  under the hash assumption; nothing else in the journal depends on x.
- **Succinct opt-in**: multi-proof composition additionally needs independent
  prover randomness per proof and the vendor ZK claim; the host must not seed
  the prover deterministically.
- **Refusals** are part of the view. A guest abort (out-of-class value,
  overflow) yields no receipt, which tells the requester that x left the
  calibrated range. The existing design has the same leak ("reject instead of
  fitting"). Record it as declared leakage; do not print which check failed.

## 9. Segment metadata and timing

With a Groth16 (or succinct) artifact, size is constant and no cycle or
segment count is published, provided PoVW is off ([LOCAL] `povw_job_id`
exists; a work receipt would disclose cycles). What remains is wall-clock
time, visible to whoever waits for the proof. Proving time follows total
cycles and segment count.

Sources of input-dependent cycles in this kernel: 64-bit division by a
data-dependent denominator (softmax, RMSNorm; on rv32 this is a software
routine whose iteration count depends on operands), branchy max/argmax and
clamps, and paging (cycles charged per page first touched in a segment, which
depends on table indices; the SiLU table spans many pages).

Gate (executor only, cheap): over a hostile input set — all-zero, all-min,
all-max, alternating extremes, softmax ties, random — the **total cycle count
and segment count are identical**. Expect to need a fixed-iteration branchless
division and branchless selects. Paging differences may survive; if the gate
cannot be made to pass, the residual timing leak is recorded with its measured
spread and the service pads release time to a fixed deadline. Either outcome
is reported; neither is silently dropped.

Cost [MODEL, unmeasured]: about 8×10⁴ MACs plus 2×10³ softmax divisions and
the norms gives an estimated 2–6 M cycles, i.e. a handful of segments at po2
20. On this 15 GB shared box cap `segment_limit_po2` at 18–19 until peak
memory is measured, and run proving detached under `flock /tmp/zk-heavy.lock`
per CLAUDE.md. CPU proving is likely minutes. None of this scales: 2.9×10¹²
MACs at 8B is ~10¹³–10¹⁴ cycles. This route is a functional privacy
intermediate and has no performance future on its own.

## 10. Approved weights, calibration and image ID

Two separable identities, both taken from the verifier's registry:

- **Image ID** identifies the audited program: kernel + framing + hashing, for
  one profile. One image per profile and semantics version, independent of the
  model. It must be reproducible by the approver: [RECALLED] deterministic
  guest builds need `cargo risczero build`'s Docker path; a locally built ELF
  gives an image ID only this box can reproduce. Until reproducible, the
  registry entry says "locally built, unreproduced".
- **Model** is identified by `model` (the existing approved artifact ID),
  `weights_digest` and `calibration_digest`, which the guest computes over the
  bytes it actually uses. Public weights enter as public input; they are not
  baked into the ELF, so approving a new model does not need a new audit.

The registrar computes `weights_digest`/`calibration_digest` from the same
approved material that produced the existing `BlockRegistration`. This is a
**new approval record**. The PCS weight roots in
`ApprovedP1BlockContract` are not checked by the guest and gain no meaning
here; bridging them would mean recomputing the PCS commitment in the guest,
which is expensive and pointless for public weights. The A00 caveats carry
over: a digest does not establish weight ranges (the registrar's duty), and
integer `Ceps` is approved as an integer.

## 11. Would wrapping the existing public argument buy anything?

Option W: the guest runs the hashline **P0 verifier** on a P0 proof held as
private witness; the journal is unchanged. The P0 proof's leaks stop mattering
because nobody sees it.

- **Soundness gets worse**: zkVM soundness × hashline soundness at the
  experimental inverse-rate-8 tiny profile (unreviewed bits), versus zkVM
  soundness alone for re-execution.
- **Cost gets much worse at this size** [MODEL]: the verifier must hash the
  opened columns and paths of a ~5 MB proof with BLAKE3, which has no RISC
  Zero accelerator (SHA-256 and Keccak do), and do Goldilocks `Fp2` arithmetic
  in 32-bit software. ~8×10⁴ compressions at a few thousand cycles each is
  order 10⁸ cycles against order 10⁶–10⁷ for re-execution.
- **Endpoint binding still needs x and y in the guest**: the P0 argument binds
  unsalted deterministic PCS roots, which cannot be published. The guest must
  evaluate MLE(x), MLE(y) at the proof's points and compare with the clear
  terminals, then form the salted commitments. Linear in the endpoints, fine,
  but it means the wrapper does not avoid holding private data in the guest.
- **When it could matter**: verification is sublinear in the computation, so
  at 8B (native verify ~1 s, re-execution impossible) wrapping is the only
  zkVM-shaped option. Even then hashing 1.23 GB (or ~62 MB compact) of proof
  in-guest needs a SHA-256 Merkle profile and a field-friendly verifier, i.e.
  another new profile and a composition review. Out of scope now.

Recommendation: do not wrap for this intermediate.

## 12. Implementation contract (ordered; each step has a gate)

| # | Owner | Deliverable | Gate |
|---|---|---|---|
| Z0 | root | Decide and perform the network fetches: `rzup install rust`, `cargo fetch` of `risc0-zkvm`/`risc0-build` pinned `=3.0.x` matching r0vm 3.0.6, Docker + the Groth16 prover image | versions and hashes recorded; §15 checklist executed against the fetched source and this memo corrected where [RECALLED] was wrong |
| Z1 | Opus | `no_std` checked-integer kernel crate; native tests reproduce every plane of the existing T32 oracle fixtures | digests equal the current oracle; zero `unsafe`, zero float, no `fit_*` |
| Z2 | impl | guest + input frame + journal per §3–4 | **executor-only** run reproduces the probe's pinned vector logic for a real block: journal bytes equal `encode_journal` on independently computed digests; trailing/short input aborts |
| Z3 | impl | constant-cycle work | §9 gate, or a measured recorded spread |
| Z4 | root | first real proof, detached under the heavy lock, `ProverOpts::groth16()`, po2 cap 18–19 | wall, peak RSS, cycle/segment counts [MEASURED]; `conjectured_security` and `proven_soundness_error` recorded from the build |
| Z5 | impl | standalone verifier per §3 | every §13 case |
| Z6 | impl | two-block chain by commitment equality | §13 C-cases |
| Z7 | parent/Victor | rulings: sub-128-bit deviation; trusted setup; Docker; new endpoint/weight identity profile; declared leakage list (§8, §9) | recorded in the ledger before any "private block" wording |

Nothing in `hashline/`, `src/manifest.rs`, freeze rows or existing receipts
changes. The new crates live in their own directory with their own lockfile.

## 13. Adversarial acceptance cases

Every negative case must reach the **verifier** and be rejected there.

Statement binding (S):
- S1 each of the seven journal fields altered in the verifier's expectation;
  each of the 260 journal bytes flipped (probe: done at serialization level;
  repeat against real receipts).
- S2 valid receipt for layer l presented for layer l′; for another context;
  for another model/weights/calibration digest.
- S3 endpoints swapped; C_in replaced by a commitment to the same x with
  another salt; C_out taken from a different honest run.
- S4 receipt from a **different image ID** with an identical journal (a guest
  that commits the journal without computing) — must fail `verify(IMAGE_ID)`.
- S5 prover host modified to supply y′ ≠ Block(x): impossible to express
  except by changing the guest, which is S4; confirm the input frame has no
  field for y.

Envelope (D):
- D1 fake receipt with the correct journal, verifier environment clean.
- D2 the same with `RISC0_DEV_MODE=1` in the verifier's environment: refused
  by the environment rule **and**, with that rule disabled in a test build,
  by `disable-dev-mode`.
- D3 composite receipt and (without opt-in) succinct receipt for the correct
  statement: refused by kind before verification.
- D4 receipt with `Paused(0)`, `Halted(1)`, non-empty assumptions, or built by
  another risc0 version (verifier-parameter mismatch).
- D5 truncated, oversized, trailing-byte and bit-flipped receipt encodings: a
  typed error, no panic.

Guest input (G):
- G1 input frame short/long by one byte; G2 out-of-class or overflowing
  witness → abort, no receipt, static message; G3 weights differing in one
  byte from the approved set → journal mismatch at the verifier.

Privacy regression (P) — diagnostics, **not** a ZK proof:
- P1 public artifact directory contains exactly one Groth16 receipt; grep-scan
  it and all logs for the salts, x/y encodings and their SHA-256.
- P2 same (x, context) proven twice with fresh salts: commitments differ,
  proofs differ, journals otherwise equal.
- P3 §9 cycle-count gate. P4 host refuses under `BONSAI_*`, dev-mode or PoVW
  configuration. P5 `RISC0_WORK_DIR` is private, tmpfs, removed after use.

Chain (C):
- C1 two blocks verify and `out_0 == in_1` bytewise; C2 block 1 rebuilt on a
  different input verifies alone but the chain check fails; C3 layers swapped
  or duplicated fail by boundary index.

## 14. Remaining limits — none waived

1. No code was built, executed or proved. Feasibility on this box is unmeasured.
2. Security is below the 128-bit target with no available parameter fix (§6).
3. Groth16 needs a trusted setup for soundness and Docker locally; succinct
   avoids both but has no citable ZK argument.
4. Every [RECALLED] statement is unverified; several carry the argument
   (halted post-state zeroing, Groth16 public inputs, default verify accepting
   all kinds, dev-mode feature semantics, security figures).
5. Privacy reduces to cited external properties **plus** implementation
   faithfulness of a large third-party stack that this project has not
   audited; commitment hiding is an assumption.
6. Declared leakage remains: refusal events, endpoint equality across
   journals, wall-clock timing (unless Z3 passes), shape, layer, model
   identity.
7. One tiny block. Attention-complete per the kernel, but no embedding, head,
   token selection, KV state or generation; no P3 weight privacy (weights are
   public inputs here; hiding them would need a committed-weights statement
   and approved-model identity, not addressed).
8. The old endpoint/weight roots are not supported; the external-root
   obligation for the **hashline** construction stays open as written.
9. No performance path to 8B (§9). The custom line remains the performance
   line; this is a functional privacy intermediate and a differential oracle.

## 15. Verification checklist for the parent (turn [RECALLED] into [LOCAL])

After Z0, in the fetched `risc0-zkvm`/`risc0-zkp`/`risc0-groth16` 3.0.x source:

1. `risc0-zkvm/src/receipt.rs`: `InnerReceipt` variants; what `verify` and
   `verify_with_context` accept; exit-code and assumptions checks; Fake
   handling; any `VerifierContext` dev-mode switch.
2. `risc0-zkvm/src/claim/receipt.rs`: `ReceiptClaim::ok` — post-state for
   `Halted`, `input` digest, `Output{journal, assumptions}`.
3. `risc0-zkvm/src/receipt/composite.rs`, `segment.rs`: fields published per
   segment; confirm `merkle_root` semantics in `risc0-binfmt` `SystemState`.
4. `risc0-zkvm/Cargo.toml`: exact name and effect of `disable-dev-mode`;
   features needed for a verify-only build.
5. `risc0-zkp/src/lib.rs`: `QUERIES`, `INV_RATE`, `ZK_CYCLES` and its comment,
   extension degree; `src/prove/soundness.rs`: how to obtain the two figures.
6. `risc0-groth16`: public-input layout; Docker invocation, work-dir contents
   and cleanup; prover randomness source; verifying-key provenance/ceremony.
7. `risc0-zkvm/src/host/client/prove/mod.rs`: `default_prover()` selection
   rules (Bonsai/IPC/local), to confirm the explicit-prover requirement.
8. Official security-model page: the three published bit figures and their
   stated assumptions, quoted verbatim into the ledger.

Any item that contradicts this memo overrides it; items 1, 2 and 6 can change
the §5 recommendation and must be checked before Z4.
