# RISC Zero source review for the private block prototype — 2026-09-18

**Conclusion: Groth16 provides a defensible outer privacy construction without
requiring the inner STARK to be zero knowledge.** The installed Rust code
supports the public-input boundary, and the pinned CPU prover source supplies
the required fresh blinding. This is a construction review, not an assertion
that the current succinct-only prototype has produced that artifact, met the
model-scale target, or completed a circuit/ceremony audit.

Reviewed the Fable proposal at
`/tmp/wt-zk60-loop-fable-20260917/docs/zkmatrix-poc/ZK60_ZKVM_CONSTRUCTION_REVIEW.md`
against installed `risc0-zkvm 3.0.6`, `risc0-zkp 3.0.5`, and
`risc0-groth16 3.0.5`. The zkvm and groth16 crates' `.cargo_vcs_info.json`
both identify upstream commit `8c215e2f4ccdd935f0517bf05d90f1ae032840a9`.
Paths below are relative to those installed crate directories under
`/home/victor/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/`.

## Verified public boundary and the privacy argument

| Claim | Source and result |
|---|---|
| The succinct seal is private input to the outer prover | `risc0-zkvm-3.0.6/src/host/server/prove/mod.rs:193`: `identity_p254`, then `shrink_wrap(seal_bytes)`. The returned Groth16 receipt retains the outer seal, original claim and fixed verifier-parameter digest; it does not include the inner seal. |
| Exactly five scalar public inputs | `risc0-groth16-3.0.5/src/verifier.rs:93`: two limbs of the control root, two of the claim digest, and the BN254 identity control ID. No segment count, private endpoint opening or execution trace is a public input here. |
| Parameters come from the verifier | `risc0-zkvm-3.0.6/src/receipt/groth16.rs:76`: compare the receipt's parameter digest to the trusted context, then verify with that context's control root, identity ID and key. The receipt cannot nominate an arbitrary key. |
| The claim is fixed by image ID and journal | `risc0-zkvm-3.0.6/src/receipt.rs:173`: `verify_with_context` compares the verified claim digest with `ReceiptClaim::ok(image_id, journal_digest)`. `src/claim/receipt.rs:75` sets `Halted(0)`, zero post-state, no input claim and empty assumptions. |
| Outer seal has fixed size | `risc0-groth16-3.0.5/src/types.rs:42`: exactly 256 bytes, representing two G1 points and one G2 point; decode refuses another length. |
| Fake receipts can be disabled explicitly | Current host calls `with_dev_mode(false)` on prover options and verifier context and filters receipt kind first. Cargo also provides `disable-dev-mode` at `risc0-zkvm-3.0.6/Cargo.toml:69`. |

For a fixed accepted image and journal, the outer statement is therefore
publicly computable. The inner STARK seal and its verification computation
are merely a witness for that statement. Groth's **Theorem 3**, section 3.2,
proves perfect zero knowledge of the outer scheme with its well-formed setup
and independently uniform proof coins. Simulation uses the public statement
and setup trapdoor, not the inner witness. Consequently this argument does
not need the inner STARK's hiding property. The inner STARK's soundness and
the correctness of its verifier circuit remain necessary for the final
computation claim. Fresh independent proof coins permit repeated-proof
composition; endpoint hiding remains a separate salted-hash assumption.
[Groth's accepted paper, page 17](https://discovery.ucl.ac.uk/id/eprint/1501201/1/Groth_SNARK9.pdf).

Succinct receipts have no such outer Groth16 layer. The vendor's current
3.0 security page says it has not supplied a mathematical ZK argument;
its STARK hiding claim cannot be substituted for the reviewed argument
above. Composite receipts additionally disclose execution-length information.
Continue using succinct only as explicitly experimental functional evidence.
[RISC Zero security model](https://dev.risczero.com/api/security-model).

## Integration addendum — actual native proof and hardened entry points

The native route below has now executed successfully: a 785-byte Groth16
receipt verifies against the original block image and caller policy, and the
public verifier rejects the inner succinct receipt plus seven altered inputs.
The saved public bundle and exact tool hashes are under
`results/zk60_loop_20260918/block-integration/`. D3 and D4 now record Victor's
accepted intermediate soundness/setup choices; D7 remains pending. The
installed circuit calculator outputs are separately recorded in
`results/zk60_loop_20260918/risc0-security.json`; they are not a composed
whole-proof bound.

All four block/token CLIs now refuse inherited `RISC0_*` and `BONSAI_*`
runtime switches, including `RISC0_PPROF_OUT`, which upstream otherwise turns
into an arbitrary profiler output path. Both wrappers use the shared
`zkvm-native-tools/` streaming checker before native execution. The pinned
files and focused refusal tests pass; this establishes file provenance, not
ceremony well-formedness. Detailed token review:
`ZK60_TOKEN_MODEL_SOURCE_REVIEW.md`.

## CPU proof randomness: checked beyond the Rust wrapper

The installed Rust crate does not implement CPU Groth16 proving itself.
`risc0-groth16-3.0.5/src/prove/docker.rs:33` writes the inner seal and JSON
input to a work directory and invokes
`risczero/risc0-groth16-prover:v2025-04-03.1`.

The matching upstream source establishes this chain:

1. The pinned [Dockerfile](https://raw.githubusercontent.com/risc0/risc0/8c215e2f4ccdd935f0517bf05d90f1ae032840a9/groth16_proof/docker/prover.Dockerfile)
   compiles the witness generator with Circom commit
   `e410b0d5cd2948a15931df0bc50d79ce56fa8c32` and builds the Go prover.
2. [The prover entry point](https://raw.githubusercontent.com/risc0/risc0/8c215e2f4ccdd935f0517bf05d90f1ae032840a9/groth16_proof/circom-compat/cmd/prover/main.go)
   calls `groth16.Prove(r1cs, pk, fullWitness)` without caller-specified
   blinding or deterministic proving options.
3. [The module manifest](https://raw.githubusercontent.com/risc0/risc0/8c215e2f4ccdd935f0517bf05d90f1ae032840a9/groth16_proof/circom-compat/go.mod)
   replaces gnark 0.12.0 with `github.com/risc0/gnark v0.12.0-risczero.0`
   and uses gnark-crypto 0.15.0.
4. That exact [BN254 prover](https://raw.githubusercontent.com/risc0/gnark/v0.12.0-risczero.0/backend/groth16/bn254/prove.go)
   samples `r` and `s` with two separate `SetRandom()` calls and propagates
   either failure. It adds the corresponding delta multiples to A and B
   and the usual randomizing terms to C.
5. [The pinned field sampler](https://raw.githubusercontent.com/Consensys/gnark-crypto/v0.15.0/ecc/bn254/fr/element.go),
   lines 298–342, reads `crypto/rand.Reader`, masks unused high bits and
   rejects candidates at least the modulus. This is unbiased field sampling
   under the OS randomness assumption, not reduction of a short hash seed.

These are inspected source facts. They do not establish that an arbitrary
container bearing the mutable image tag has those exact binaries. Record
the resolved image digest and the actual executable/key hashes used in the
run. Prove/verify success alone does not validate a prover's randomness.

Integration has resolved the official image manifest to
`sha256:7f173963196570b7a71816ed70565a4579264c5d2e3e0ecb028102538ad0e331`;
this review read that digest in
`/tmp/zk60-loop-20260917/groth16-image.json`. Extraction and the hashes of
the binaries/key actually executed are subsequent evidence, not asserted here.

## CRS and circuit provenance: checked versus still assumed

The Dockerfile downloads the compressed 2024-05-17.1 ceremony key with
SHA-256
`69c6056451ea814b37e30ccbc44639dbaafef73540cbfbff6ec7e68e2d325735`, then
converts that key and the compiled circuit to gnark format. The installed
verifier's constants identify `risc0-ethereum`'s Groth16 verifier as their
source (`risc0-groth16-3.0.5/src/verifier.rs:33`). The stable default
verifier-parameter digest is pinned by the upstream test in
`risc0-zkvm-3.0.6/src/receipt/groth16.rs:198` to
`73c457ba541936f0d907daf0c7253a39a9c5c427c225ba7709e44702d3c6eedc`.

RISC Zero publishes the circuit/ceremony verification procedure, including
the expected R1CS hash and a `snarkjs zkey verify` check. This review did
**not** run that large check, independently audit the circuit, or verify
every ceremony attestation. Thus well-formed setup, honest contribution for
soundness, correct conversion and faithful compiled prover remain stated
deployment assumptions. Trapdoor secrecy is needed for soundness; it is not
the privacy premise of Groth16's honest-setup theorem.
[Official ceremony verification procedure](https://dev.risczero.com/api/trusted-setup-ceremony).

## Running the same CPU construction without Docker

Docker is packaging for this CPU path, not a cryptographic necessity. The
pinned [launcher](https://raw.githubusercontent.com/risc0/risc0/8c215e2f4ccdd935f0517bf05d90f1ae032840a9/groth16_proof/scripts/prover.sh)
runs the witness generator and then the ordinary native Go executable:

```
stark_verify input.json witness.wtns
prover stark_verify.cs stark_verify_final.pk.dmp witness.wtns proof.json
```

The image carries `stark_verify`, its `stark_verify.dat`, `prover`,
`stark_verify.cs`, and `stark_verify_final.pk.dmp`. Extracting those exact
artifacts from a resolved official image, retaining required runtime
libraries, and using the same files supports the same proof relation/key.
This is feasible by source inspection, not an executed native-prover result.
The image launcher sets a 16 MiB stack and overlaps witness generation and
proving through a FIFO. Its fixed `/tmp/output.wtns` is unsuitable for shared
native runs; use a unique private directory/FIFO and keep all inner receipts,
input JSON, witness data and logs there. Only the final outer receipt is a
public artifact.

The Fable memo's unconditional Docker requirement is inaccurate:
`risc0-groth16-3.0.5/src/prove/mod.rs:31` also selects a native CUDA path
when compiled with `cuda`. This review does not recommend or validate that
path, and did not investigate the reported 3.0.5/3.0.6 CUDA failure.

## Actual project security requirements

No universal **at least 128-bit** acceptance requirement was found in the
current `ZK60_EXECUTION.md`, privacy contract, or ZK60 requirement search.
`ZK60_EXECUTION.md:80` requires an explicit whole-proof security argument
and forbids silently weakening parameters (`:252`). `START_HERE.md:212`
reports default hashline soundness of 106 bits and treats its separate
95–98-bit compact option as a pending product decision.
`SOUNDNESS_REFERENCE.md:144` discusses lattice shapes below a quantum
128-bit yardstick; it does not impose that yardstick on every new backend.
Fable's alleged 128-bit blocker came from the task brief, not a verified
user requirement. Do not create a user approval gate from it.

The new backend's actual assumptions must remain visible. The official
3.0 page reports 96 bits for the RISC-V prover, 99 for recursion and 99+
for the pairing wrapper, under its listed assumptions. Installed source
comments instead target 97 conjectured bits at the default segment limit;
`risc0-zkp-3.0.5/src/lib.rs:40` fixes 50 queries and rate 1/4. These are
different reported estimates, not a proven 128-bit bound. Record the
actual build's calculator results and segment parameters when proving;
do not present the outer wrapper as upgrading inner soundness.
[Vendor security estimates](https://dev.risczero.com/api/security-model).

Also correct Fable's recalled blinding comment: installed
`risc0-zkp-3.0.5/src/lib.rs:42` sets `ZK_CYCLES = 1024` with a TODO to
compute it programmatically. It does not contain the recalled statement
that the value needs to be bigger. The vendor's explicit missing-proof
statement is the relevant limitation.

## Minimal prototype change

The current host explicitly chooses and accepts only Succinct receipts.
For the outer-privacy artifact, use `ProverOpts::groth16()` and require
`InnerReceipt::Groth16` in `real_verify`, retaining the exact caller-policy
comparison, pinned image ID, trusted verifier context, size limits and
dev-mode rejection. A saved succinct intermediate can also be compressed
through the existing `Prover::compress`/server compression interface after
the CPU wrapper is operational, avoiding another block proof. Keep that
intermediate private. Where using a native extracted wrapper, the same
`identity_p254` conversion and upstream seal decoder are still required;
ordinary succinct bytes are not direct Groth16 prover input.

The Fable 260-byte journal is a proposal, not the implemented statement.
Current `zkvm-block/statement/src/lib.rs` uses a **144-byte** versioned
statement binding context, complete model/calibration payload digest, and
role-separated input/output commitments. It explicitly rejects compatibility
with old PCS roots. Nothing in the outer Groth16 argument requires adopting
the proposed 260-byte layout. Conversely the current role-separated endpoint
format does not support Fable's suggested direct cross-block root equality;
that future seam must be implemented explicitly.

No production source was edited, no proof or heavy test was run for this
review. This memo records checked construction premises and remaining
implementation/provenance work, without changing MVP acceptance flags.
