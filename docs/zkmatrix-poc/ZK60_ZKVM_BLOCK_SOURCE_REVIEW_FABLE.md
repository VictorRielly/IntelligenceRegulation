# Security owner's review of `zkvm-block/` (guest, host, wrap, statement, model) — 2026-09-18

| | |
|---|---|
| Author | Claude Fable 5.1 (interactive session, security owner) |
| Reviewed | `zkvm-block/` in the main checkout at the time of the first real succinct receipt (223,514 bytes, verified) and the queued Groth16 wrap; 1,056 lines across `methods/guest`, `statement`, `model`, `host`, `wrap`, `security` |
| Against | the headless review's §3 construction and §13 acceptance cases (`ZK60_ZKVM_CONSTRUCTION_REVIEW.md`), my disposition's §2 corrections (`ZK60_ZKVM_REVIEW_DISPOSITION.md`), and the decisions register D3–D7 |
| Verdict | **Consistent with D5 and the disposition. No defect found. Six hardening items and two evidence gaps, listed in §3, none blocking the Groth16 artifact.** This is a source review, not a privacy acceptance; D7 (the profile ruling) is still Victor's. |

## 1. What the code does, checked line by line

**Guest** (`methods/guest/src/main.rs`, 20 lines). Reads three fixed-length
frames with `env::read_slice` (public model 6,184 bytes; private request
144 + 1,024 bytes: context, two salts, 512 `i16`; the expected 144-byte
policy), decodes them with strict length and magic checks, runs the kernel,
computes both salted endpoints, asserts the computed statement equals the
supplied policy, and commits exactly the 144 statement bytes. No `env::log`,
no `env::verify`, no pause; every abort is a static string. Release profile
has `overflow-checks = true`; the kernel itself uses checked arithmetic and
refuses out-of-range values rather than clamping. `risc0-zkvm` is pulled
with `default-features = false`.

**Statement** (`statement/src/lib.rs`). Journal = 16-byte profile
`zk60-r0-block-v1` ‖ context ‖ model digest ‖ input endpoint ‖ output
endpoint. Endpoint = SHA-256 over a domain tag, the profile, a role byte
(input 0 / output 1), context, model digest, the 32-byte salt, the element
count and the 512 little-endian words. `check_journal` is a byte comparison
against the caller's independently supplied policy; nothing is parsed out of
a candidate journal to decide acceptance. Model digest is SHA-256 over the
complete canonical model payload under its own tag. Tests flip every journal
byte and every endpoint input.

**Model** (`model/src/lib.rs`). Public model decoding validates the nine
weight shapes and the table structure (`PublicTables::from_slices`); the
model digest is computed over exactly the bytes decoded, so the policy binds
what the guest used. The request type deliberately has no `Debug`/serialize.

**Host** (`host/src/main.rs`). `prepare` draws context and both salts from
`/dev/urandom` (96 bytes) and the demo input from further OS bytes, writes
the request and plaintext output to a new 0700 private directory as 0600
files, and only `policy.bin` and `model.bin` to a new, disjoint public
directory; symlinked or aliased destinations are refused (tests). `prove`
recomputes the block natively, checks the policy, builds the executor
environment with `segment_limit_po2(18)` and a 64M-cycle session limit,
uses an **explicit local `ExternalProver` on the given `r0vm` path** (never
`default_prover`; the crate is built with `client` only, so the Bonsai path
is not even compiled), proves with `ProverOpts::succinct().with_dev_mode
(false)`, and then `real_verify` accepts **only** `InnerReceipt::Succinct`
against the compiled image ID and the policy with a context whose dev mode
is explicitly false. The succinct receipt is saved 0600: it is the witness
to the Groth16 layer, never the public artifact. `RUST_LOG=off` and no
backtraces are set before any thread starts.

**Wrap** (`wrap/src/main.rs`; crate features `client` + `disable-dev-mode`).
Verifies the inner succinct receipt first (policy, image ID, dev mode off),
converts it with `identity_p254` through a sub-process `r0vm` and checks the
claim digest is unchanged, writes `input.json` 0600 into a new 0700 work
directory that must lie outside the public artifact's parent, runs the
extracted native `stark_verify` and `prover` under a 16 MiB stack limit with
owner-only logs, assembles `Groth16Receipt::new(seal, claim,
Groth16ReceiptVerifierParameters::default().digest())`, and accepts the
result only if `verify` passes: **`InnerReceipt::Groth16` only**, policy
byte-equal, `verify_with_context` with dev mode off and the compiled image
ID. Fake and zero-seal Groth16 receipts and truncated/trailing encodings are
rejected in tests. The public receipt is written 0644 with `create_new`.

**Security calculator** (`security/src/main.rs`). Calls the installed
`risc0_zkp::prove::soundness::{toy_model_security, proven}` on each
circuit's real tap set for `po2` 14..20 with the prover's coefficient
count; this is where the D3 addendum's figures come from (rv32im at 2^18:
98.64 conjectured / 45.30 proven; at 2^20: 97.14 / 41.57).

## 2. Acceptance cases of the headless review's §13, as covered today

| Case | Status |
|---|---|
| S1–S3 statement binding (wrong context/model/input/output, truncated, trailing, tampered receipt) | executed by Codex on the real succinct receipt: all rejected (`ZK60_MVP_LOOP_20260918.md`) |
| S4 different image ID | enforced by `verify_with_context(…, PRIVATE_BLOCK_ID)`; the claim digest comparison in `risc0-zkvm-3.0.6/src/receipt.rs:171–201` is what fails |
| D1/D2 fake receipts | unit tests in host and wrap; wrap also compiles with `disable-dev-mode` |
| D3 composite / succinct presented to the public verifier | refused by the explicit `matches!` before any verification, in both binaries |
| D4 paused, non-zero exit, assumptions, other version | not tested here; enforced upstream by the `ReceiptClaim::ok` digest comparison and the `verifier_parameters` check (source verified in the disposition) |
| D5 bounded decode | bincode fixint, 16 MiB limit, trailing bytes rejected; tests |
| G1/G2 guest input | strict decoders and static aborts in the guest; exercised by the executor-only stage |
| P2 fresh salts per run | by construction (`/dev/urandom` per `prepare`) |
| P4 host refuses Bonsai / dev-mode environment | Bonsai not compiled; dev mode forced off in options and context; the Python runner scrubs `BONSAI_*`, `RISC0_*`, `RUST_LOG*` from the child environment |
| P5 private work directory | 0700, outside the public parent, retained for diagnosis (not removed; see §3.3) |
| P1 grep-scan of the public directory for salts, values and their hashes | **not evidenced** |
| P3 constant-cycle gate (timing side channel) | **not run**; timing stays declared leakage |

## 3. Hardening items and evidence gaps (none blocking)

1. **Host does not scrub `RISC0_DEV_MODE` itself.** It sets `RUST_LOG` and
   `RUST_BACKTRACE` but relies on the Python runner to remove `RISC0_*` and
   `BONSAI_*` from the child environment. Defence in depth already holds
   (`real_verify` rejects a fake receipt whatever `r0vm` did), but the host
   should `remove_var` those names too, so the binary is safe when run by
   hand.
2. **Wrap does not check the native tool hashes itself.** The runner
   compares them via `--native-hashes`; the wrap binary trusts whatever is
   in `NATIVE_TOOLS_DIR`. Embedding the five expected SHA-256 values in the
   wrap binary (or requiring the artifact record) would make the pinning a
   property of the artifact producer, not of the orchestration.
3. **The private work directory retains the full inner STARK seal**
   (`input.json`, `witness.wtns`, the identity seal) after a successful
   wrap. Retention is documented and the directory is 0700, but per D5 that
   material must never become public; a `--keep-work` flag defaulting to
   removal after a verified wrap would make the safe path the default.
4. **P1 evidence.** Add to the runner's post-wrap stage a scan of the public
   directory and all public logs for the salts, the request bytes, the
   output words and their SHA-256 digests; record the negative result.
5. **P3 evidence.** Run the executor-only stage over the hostile input set
   (all-zero, all-min, all-max, alternating extremes, softmax ties, random)
   and record whether total cycles and segment counts are identical; if not,
   record the spread as declared leakage in the register.
6. **Image ID reproducibility.** The verifier embeds the image ID of the
   locally built ELF. Until a reproducible build (upstream's Docker path)
   confirms it, any approval record for `8d74aab3…98d9` must say "locally
   built, unreproduced", as the headless review §10 asked.
7. **Segment size.** `segment_limit_po2(18)` is below the 2^20 the D3
   figure assumes, which slightly raises the per-segment figure (98.64 bits
   conjectured); keep it at or below 2^20 as D3 requires, and record it
   with every proving run.
8. **D4 cases.** A cheap regression: construct a `Receipt` whose journal is
   correct but whose inner Groth16 claim has `Paused(0)` or a non-empty
   assumptions list with a zero seal, and assert `verify` fails (it fails at
   seal integrity first; the test documents the ordering).

## 4. What this review does not do

It does not re-verify the ceremony, the extracted native binaries or the
prover's randomness (Codex's source review covers the provenance chain and
the extracted-file hashes). It does not test the running Groth16 wrap; when
its marker lands, the independent check is `zk60-block-wrap verify` in a
fresh process with a policy obtained separately from the receipt, and the
receipt kind in the result must be `groth16`. It does not change D7: the
salted-SHA-256 profile is implemented and reviewed here, and its acceptance
as the P1 statement for the intermediate remains Victor's ruling.
