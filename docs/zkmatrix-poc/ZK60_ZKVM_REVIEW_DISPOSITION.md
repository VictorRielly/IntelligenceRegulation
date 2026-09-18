# Disposition of the zkVM construction review (RISC Zero v3) — security owner's ruling

| | |
|---|---|
| Author | Claude Fable 5.1 (interactive session, security owner), 2026-09-18 |
| Reviews | the headless Fable lane's `ZK60_ZKVM_CONSTRUCTION_REVIEW.md` (worktree `/tmp/wt-zk60-loop-fable-20260917`, baseline `5d6f101`), whose §15 asked the parent to turn its [RECALLED] claims into [LOCAL] facts |
| Method | every item of that checklist read in the local crate source fetched on 2026-09-18 08:17 (`~/.cargo/registry/src/index.crates.io-*/risc0-zkvm-3.0.6`, `risc0-zkp-3.0.5`, `risc0-groth16-3.0.5`, `risc0-binfmt-3.0.5`, `risc0-circuit-rv32im-4.0.5`, `risc0-circuit-recursion-4.0.5`); the review's 19 serialization tests run here and pass |
| Scope guard | P1 hides inputs, outputs and intermediate activations; weights may be public. This ruling narrows nothing; it records what the zkVM route substitutes for the custom-PCS obligations and which rulings remain Victor's. |

## 0. Ruling

The construction is **sound as a functional privacy intermediate for the tiny P1 block**, with the receipt kind fixed to Groth16, under three explicit substitutions that the project has not previously accepted and that need Victor's ruling before any "private block" wording: a security level of about 97 bits conjectured instead of the 128-bit target; a trusted setup for soundness (Groth16 CRS); and reliance on RISC Zero's proof system and toolchain as a trusted external component. Every [RECALLED] claim the review's argument rests on checks out in the local source, with the corrections listed in §2. The custom-PCS obligations (joint view, caller-fixed roots, attention schedule) are not closed by this route; they are **bypassed** for this intermediate because the endpoint commitments are never opened. The two lines coexist: this route gives a complete private tiny block soonest; the custom line remains the only route to the throughput target.

## 1. What the review got right, now verified locally

| Review claim | Verified at | Finding |
|---|---|---|
| Four receipt kinds: Composite, Succinct, Groth16, Fake | `risc0-zkvm-3.0.6/src/receipt.rs:322–334` | as stated |
| A halted claim carries a **zero** memory root, `Halted(0)`, no input, empty assumptions | `src/claim/receipt.rs:77–92` (`ReceiptClaim::ok`: `post = SystemState{pc: 0, merkle_root: Digest::ZERO}`) | as stated; `Receipt::verify_with_context` (`receipt.rs:171–201`) compares the claim digest against exactly this expected claim, so a paused claim, a non-zero exit code or non-empty assumptions fail the digest comparison |
| `SystemState.merkle_root` is the memory-image root | `risc0-binfmt-3.0.5/src/sys_state.rs:29–36` ("root hash of a merkle tree which confirms the integrity of the memory image") | as stated; composite receipts carry one `SegmentReceipt` per segment with its own claim (`receipt/composite.rs:44–62`, `receipt/segment.rs:38–62`), i.e. pre/post memory roots at every split |
| `Receipt::verify` accepts every kind; Fake accepted only when the verifier context is in dev mode | `receipt.rs:160–162` (delegates to `verify_with_context(VerifierContext::default())`), `:602` (`if ctx.dev_mode()` on the Fake path), `:955`, `:1036` (the default context takes dev mode from the environment) | as stated: the explicit `InnerReceipt` match in our verifier is load-bearing |
| `disable-dev-mode` feature exists; `with_dev_mode(true)` is refused under it | `risc0-zkvm-3.0.6/Cargo.toml:69`; `receipt.rs:1000–1007`; `src/lib.rs:204–226` (`RISC0_DEV_MODE` ∈ {1, true, yes}; the feature makes the function return false and the set variable an error) | as stated |
| `default_prover()` selects Bonsai when `BONSAI_API_URL` and `BONSAI_API_KEY` are set and dev mode is off | `src/host/client/prove/mod.rs:183–205`; `Cargo.toml:65–68` (`default = ["client", "bonsai"]`) | as stated, and worse: `bonsai` is a **default feature**, so a verifier or host built with default features carries the upload path; build with `default-features = false` |
| Parameters: 50 queries, inverse rate 4, 1,024 blinding cycles set heuristically | `risc0-zkp-3.0.5/src/lib.rs:40–46` ("50 FRI queries is sufficient to achieve our security target of 97 bits (conjectured security)"; `ZK_CYCLES = 1024; // TODO: Ideally we'd compute ZK_CYCLES programmatically`) | as stated; the exact comment differs from the one recalled but says the same thing |
| Security figures come from the build's calculator | `risc0-zkp-3.0.5/src/prove/soundness.rs:15–35`: "on-chain verifier contracts target **97 bits** of conjectured soundness, using the Toy Problem Conjecture … SEGMENT_SIZE of 2^20 … 2^24 reduces the result to **95 bits**"; run with `RUST_LOG=risc0_zkp=info`; functions `proven`, `conjectured_strict`, `toy_model_security` | the review's 96–98 becomes exactly 97 (2^20) / 95 (2^24); the proven list-decoding figure is computed by `proven()` and must be recorded at the first real run |
| Groth16 public inputs are (control root halves, claim digest halves, BN254 control id) | `risc0-groth16-3.0.5/src/verifier.rs:95–107` | exactly as recalled |
| Groth16 proving shells out to Docker with `input.json`/`proof.json` under `RISC0_WORK_DIR` or a temp dir | `src/prove/docker.rs:34–70` (image `risczero/risc0-groth16-prover:v2025-04-03.1`) | as stated; **and** a second path exists, see §2 |
| Verifying key is a hard-coded constant set | `verifier.rs:264–300` (`ALPHA_*`, `BETA_*`, `GAMMA_*`, `DELTA_*`, `IC0..IC5`) | its ceremony provenance is not in the code; it stays a vendor claim |
| `ProverOpts::groth16()`, `succinct()`, `composite()`, `ReceiptKind` | `src/host/client/prove/opts.rs:59, 133, 146, 161` | as recalled |

## 2. Corrections to the review

1. **The toolchain and crates are present.** The review said no guest Rust toolchain and no `risc0-*` crate source existed. Both were installed by Codex on the morning of 2026-09-18 (`~/.risc0/toolchains/v1.97.0-rust-x86_64-unknown-linux-gnu`, `settings.toml` `rust = "1.97.0"`; the crates listed above at 08:17). The lane could not see them because its sandbox denied `ls` outside its worktree. Its Z0 item is done except for the Groth16 prover below.
2. **Docker is not installed on this box**, so the review's Groth16 path cannot run as written. The crate also has a **CUDA Groth16 path** (`risc0-groth16-3.0.5/src/prove/cuda.rs:15–40`: `risc0_groth16_sys` with the rzup component `risc0-groth16` 0.1.0, enabled by the `cuda` feature), which is not installed either (`~/.risc0/extensions` holds only `cargo-risczero`). Z0 therefore needs one of three decisions: install Docker in WSL; install the CUDA component and accept a GPU Groth16 prover on the 8 GB RTX 4070 (the box freezes on VRAM exhaustion, see the project memory, so this needs a memory-capped trial); or take the succinct opt-in. None is the security owner's to make alone; §4 states my recommendation.
3. **The rv32im segment prover adds no blinding rows in circuit 4.0.5.** `ZK_CYCLES` is consumed only by the recursion circuit's witness generator (`risc0-circuit-recursion-4.0.5/src/prove/witgen.rs:103–154`: random BabyBear noise rows appended to the data and accumulator groups); a grep of `risc0-circuit-rv32im-4.0.5/src/prove/` finds only the accumulator challenge and the polynomial-mix randomness. This strengthens the review's "composite is never public" rule from a policy to a fact: a segment STARK carries an unblinded trace commitment. It also sharpens the succinct case: a succinct receipt's hiding rests entirely on the recursion circuit's 1,024 noise rows, and the lifted segment proof never appears in it.
4. **`RISC0_WORK_DIR` persists the Groth16 witness.** With the variable set, `seal.r0`, `input.json` and `proof.json` are written under it and not removed (`docker.rs:41–50`); without it a `tempdir()` is used and dropped. The review's P5 case (private tmpfs, removed after use) is the right rule; the simplest form is to leave the variable unset.
5. **Bonsai is a default feature** (item above). The host and the verifier must both be built with `default-features = false` and an explicit feature list; the review asked this of the verifier only.

## 3. What the route substitutes for the custom-PCS obligations (recorded, not waived)

| Custom-line obligation | Status on the zkVM route |
|---|---|
| Joint fixed-challenge view over commitments, CFS messages, terminal masks and PCS openings (round 2, `ZK60_MVP_JOINT_VIEW.md`) | not needed: the proof opens nothing; the verifier's view is (image ID, journal, one Groth16 proof) |
| Caller-fixed external roots (the endpoint model) | not needed in the old form: endpoint commitments are salted SHA-256 statement bytes never opened by the proof; the ZK simulator is the ordinary NIZK simulator on the statement. This is a **protocol change** (new domain-separated profile); old PCS endpoint and weight roots gain no meaning here |
| Adaptive and repeated proofs | Groth16's perfect zero knowledge composes proof by proof from statements alone (Groth 2016); the review's §8 accounting of declared leakage (endpoint equality across chained journals, refusal events, wall-clock timing) stands |
| Attention masking and composition (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md`) | not needed for this intermediate; the guest executes the block in the clear inside the zkVM |
| Soundness of the custom argument | replaced by the zkVM's: 97 bits conjectured at 2^20 segments, lower under proven bounds, plus the Groth16 layer at about 100 bits on BN254 |

What is assumed in exchange, all external to this project: zero knowledge of the Groth16 layer (perfect, given a well-formed CRS); computational hiding of salted SHA-256 commitments; the correctness of RISC Zero's circuits, recursion programs, control roots and the Groth16 circuit with its ceremony; and the CSPRNG behind the Groth16 prover's randomizers, which lives inside the Docker image or the CUDA component and is not visible in the Rust source.

## 4. Recommendation and rulings requested

- **Receipt kind: Groth16**, as the review concludes; its zero knowledge does not depend on the STARK blinding whose margin the vendor itself marks as heuristic. Composite receipts must never leave the prover (now a fact, §2.3). Succinct only under a recorded opt-in that names the recursion circuit's blinding as the assumption.
- **Rulings for Victor (Z7), needed before any "private block" claim:** (a) accept about 97 bits conjectured soundness as a recorded deviation from the 128-bit target for this intermediate; (b) accept the Groth16 trusted setup for soundness; (c) choose the Groth16 prover path: Docker in WSL, or the CUDA component with a memory-capped trial, or the succinct opt-in; (d) accept the new endpoint and weight identity profile (salted SHA-256 commitments; weights and calibration as digests over the bytes the guest uses) as a new approval record, separate from the PCS roots.
- **Codex (Z0–Z6):** compile and test the Opus kernel crate (delivered uncompiled: its sandbox denied `cargo test`); build the guest and the verify-only binary with `default-features = false`; record `conjectured_security` and `proven_soundness_error` from the first real run; run the review's §13 acceptance cases, in particular D3 (composite refused by kind) and the §9 constant-cycle gate.
- **Security owner (me):** review the guest and verifier sources when they exist against §3 of the review and §2 of this disposition; nothing to build now.

## 5. Relation to the custom line

The two lane deliveries of 2026-09-15 and 2026-09-16 (`ZK60_FABLE_LANE_HANDOFF.md`) stay on the board as the custom line's security basis and next implementation step. The zkVM intermediate does not test them and does not retire them; it delivers a complete private tiny block on a different trust base, and its exact-integer kernel becomes the differential oracle both lines share.
