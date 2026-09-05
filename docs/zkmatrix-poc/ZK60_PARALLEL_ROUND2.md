# ZK60 round 2 — complete PoC, profiling and research

Opened 2026-09-04 after Victor approved the complete-PoC direction and
autonomous parallel work while away. Base `19ebd18` plus the integrated,
uncommitted C0 and round-1 work. Preserve every existing change. These
are Codex workers, not instances of Fable or Claude. Claude's existing
task and reserved GPU/PCS lane remain undisturbed.

## Ownership before work starts

| Lane | Owner | Checkout | Writable files |
|---|---|---|---|
| A00 fixed block contract | Codex correctness worker | `/tmp/zk60-round2-oNXEVd/contract` | new `hashline/src/private_block_contract.rs`, `hashline/tests/zk60_block_contract.rs`, `docs/zkmatrix-poc/ZK60_BLOCK_CONTRACT.md`; local `lib.rs` registration |
| P2 end-to-end attribution | Codex profiling worker | `/tmp/zk60-round2-oNXEVd/profile` | `hashline/src/chain.rs`, `hashline/src/export_v3.rs`, `hashline/src/bin/hashline.rs`; new `scripts/hashline_profile.py`, `tests/test_hashline_profile.py`, `docs/zkmatrix-poc/ZK60_PROFILE_SWEEP.md`; optional new profiling module/test and local `lib.rs` registration |
| R2 decision-focused literature | Codex research/security worker | `/tmp/zk60-round2-oNXEVd/research` | new `docs/zkmatrix-poc/ZK60_RESEARCH_DECISIONS.md` only |
| S2 private equality prototype and integration | Codex lead | main tree | new `hashline/src/private_seam.rs`, `hashline/tests/zk60_private_seam.rs`, `hashline/examples/zk60_seam_receipt.rs`, `docs/zkmatrix-poc/ZK60_PRIVATE_SEAM.md`; minimal crate-private reuse in `zk.rs`, `lib.rs`; shared coordination/evidence and accepted lane integration |

The isolated checkouts contain the current `hashline` source snapshot.

Follow-on ownership after initial handoffs: A00's worker additionally owns
new `hashline/src/causal_oracle.rs`, `hashline/tests/zk60_sequence_equivalence.rs`
and `docs/zkmatrix-poc/ZK60_CAUSAL_ORACLE.md` for a bounded fixed-calibration
CPU witness builder and fixed-T causality checks. S2 lead additionally owns
`hashline/tests/zk60_mask_rank.rs`, preserving the research worker's tiny
inherited singleton-mask interface diagnostic. It is not a whole-FFN exploit
or a security acceptance test. No existing PCS implementation is changed.

Read current ZK60 documents in the main tree. Workers do not edit shared
boards or other lanes. No source edits in `gpu/` or `pcs.rs`, driver/toolkit
changes, commits, pushes, or private 8B GPU runs are part of this round.

## Bounded acceptance

- A00: explicit approved fixed-calibration/shape/rounding policy and checked
  preconditions; no input-dependent fitting or unsupported security claim.
  Test honest tiny constants, mutated fields, invalid bounds and shapes.
- P2: opt-in phase attribution preserving exact arithmetic and proof bytes;
  bounded real 125M CPU evidence, raw logs, checked analysis and honest
  unknown coverage. No claim that a CPU ranking predicts the 5090.
- R2: primary sources tied to decisions about sequence receipts, private
  composition/identity and proving cost. Distinguish paper, implementation,
  vendor claim and reproduction. Recommend small experiments, not a rewrite.
- S2: experimental equality relation between independently hiding committed
  planes, challenge after both roots, reserved independent terminal masks,
  masked sumcheck and authenticated openings. Malicious unequal witnesses
  must be rejected by the verifier. Independent review before integration;
  neither standalone equality nor its tests certify a private transformer.

Small CPU tests only. Serialize builds and substantive runs with
`/tmp/zk-heavy.lock`; jobs expected to exceed five minutes must detach and
write exit markers. Keep raw commands and results. Final integration checks
include relevant Python/Rust tests and the four frozen CPU proof fixtures.
GPU checks await a safe hardware window; do not silently weaken parameters.

## Product direction

First application target: an experimental short response with a delayed,
independently verifiable proof receipt, public approved weights and private
input/activations. Tiny correctness model -> existing 125M -> 8B. Token
selection, embeddings/head, private block coverage and independent byte
verification remain required before calling it complete. Proof lag and
throughput are different metrics. Security review remains a separate gate
before relying on the prototype for sensitive applications.

## Handoff — bounded round integrated

All accepted code is in the main working tree, uncommitted. No GPU/PCS
implementation, driver/toolkit, Claude-owned or Fable-owned source was
changed. Three Codex workers performed bounded tasks; this is not a claim
that Fable or Claude ran these reviews. No worker/job is left running.

| Result | Evidence | What it does not establish |
|---|---|---|
| A00 approved fixed-T32 block contract | [Contract](ZK60_BLOCK_CONTRACT.md), seven tests; pins real attention/gamma and FFN roots plus calibration/shape/rounding/PCS policy | Metadata approval and conditional host bounds are not proof-level range/no-wrap soundness |
| E1 full integer block witness oracle | [Oracle](ZK60_CAUSAL_ORACLE.md), seven tests; attention, both norms/residuals and FFN; fixed-T suffix causality; asymmetric signed-weight regression | Not a block proof, variable-length/KV equivalence, embedding/head or token choice |
| S2 experimental private equality receipt | [Seam](ZK60_PRIVATE_SEAM.md), nine tests; paired masks, one-shot ownership and bounded framed decoder; separate-process byte verification | Equality of standalone committed planes does not link actual FFN/attention arithmetic; no complete joint-transcript ZK theorem |
| P2 phase attribution | [Profile sweep](ZK60_PROFILE_SWEEP.md), six Rust/11 Python tests; nine real one-layer 125M CPU samples; on/off byte parity in all three modes | FFN-only, not a full-model sweep or a GPU/60-generated-tokens/s result |
| R2 primary-source decisions | [Research memo](ZK60_RESEARCH_DECISIONS.md), DeepProve/Attestable/Scorpius/zkLLM/ZKTorch with evidence and licensing limits | External performance and security claims were not reproduced or certified |

### Findings that change priorities

**Privacy gate:** a tiny verified diagnostic reproduces an inherited PCS
singleton-claim configuration where one base-field mask fails to hide a
clear extension-field vector. Two regression/negative-control tests pass.
The new S2 gadget uses independent paired masks, but the actual impact on
FFN groups and the joint-opening transcript still require audit. Neither
passing old byte gates nor OS randomness establishes privacy. Do not use
the experimental/private paths for sensitive application data yet.

**Performance evidence:** uncached weight commitment was largest in all
nine small CPU FFN samples (348–452 ms); exclusive attribution leaves less
than 0.078% unknown inside proof-ready. These are individual runs with
uncontrolled page-cache state, not p50/p95 or GPU forecasts. Historical
8B witness costs and these tiny commitment costs describe different
workloads; do not multiply speedup factors or extrapolate linearly.

**Application direction:** completed-sequence, delayed proof receipts are
worth pursuing. The oracle supplies fixed-calibration causality evidence;
the gadget supplies an actual byte-decoded receipt interface. The next
milestone remains a fully covered tiny private block, then two blocks,
then embedding/head/token-selection coverage for a generated response.

### Validation and artifact

Main-tree release `cargo test --all-targets`: **94 passed**. Targeted
`test_hashline_*.py`: **48 passed**. All four CPU v2/v3 P0/P1 explicit-seed
frozen proof artifacts retain their complete SHA-256 digests and sizes;
the shared-lock run used two threads and took about 149 seconds. No GPU
or full Python/native-suite rerun is claimed in this round.

The fresh public synthetic equality receipt is
`results/zk60_round2_seam.proof` (416,456 bytes), with public handles and
verification command in `results/zk60_round2_seam.json`. Its verifier
loaded no witness/export, rejected a wrong independently supplied root,
and creation refused to overwrite it. This is **experimental equality
only**, not approved-model generation. Full commands, source/binary
hashes, raw-artifact locations and test outputs are recorded in
`results/zk60_round2_validation.json`.

### Next assignments, without the 5090

1. **Fable / independent privacy reviewer:** pick up F1 in
   [the execution queue](ZK60_EXECUTION.md). Start with actual opening-group
   rank and joint-transcript analysis, then approved P3 model consistency.
   The tiny diagnostic is a lead, not a complete impact assessment. Produce
   a reviewed versioned repair/interface before private application use.
2. **Codex correctness/integration:** finish A01's machine-checkable
   exposure schedule and A03's pending FFN lifecycle; connect real
   arithmetic commitments before opening once. Complete private lookup,
   norm and attention relations (A04–A07), then two-block composition (A08).
   Keep the fixed oracle as the integer reference. Do not enable legacy
   `attn-pass --zk` or substitute separately committed copies.
3. **Claude, after its current handoff:** CL1 bounded-memory commitments
   and small CPU/GPU oracle tests, in its reserved lane. On the 5090,
   measure one safe layer before scaling, compare cold/warm public-weight
   caching and record residency, peak memory and all proof-ready costs.
4. **Subsequent PoC:** A10 embedding/final-head/argmax and request/state
   binding, an independently decoded complete receipt and distinct decode,
   proof-ready and post-decode-lag clocks. Protocol-level commitment
   avoidance remains a separate measured experiment after correctness.

The task JSON records partial implementation explicitly. The project has
not reached a full private LLM proof or demonstrated 60 generated tokens/s.
