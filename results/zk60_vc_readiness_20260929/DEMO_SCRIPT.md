# Demo script: private proofs of transformer inference (about 7 minutes)

For Victor's Tech Week SF meetings (first meeting assumed Mon 10-05). The
numbers and their sources are in `READINESS.md`: section 1 lists the demos
and section 3 the claims to avoid. Every live step below ran on 2026-09-29
(`rehearsal-20260930T002413Z.json`, 5/5 as expected).

**Before the audience (2 min):**
- Run `python3 /home/victor/IntelligenceRegulation/results/zk60_vc_readiness_20260929/rehearse.py`.
  It must print `ALL AS EXPECTED`.
- Start the stage demo with
  `python3 /home/victor/IntelligenceRegulation/scripts/zk60_techweek_server.py`
  and open <http://127.0.0.1:8765> (local only; see `docs/zkmatrix-poc/ZK60_TECHWEEK_DEMO.md`).
- Make sure no GPU or heavy job is running. Have the recorded 125M GPU run
  (plan P0-3) and the one-slide numbers sheet open.

**1. The problem (30 s).** "A regulator or customer wants to know that the
approved model produced this answer, without ever seeing the prompt or the
answer. We produce a cryptographic proof of exactly that: the input, the
output and every intermediate value stay hidden, and anyone can check the
proof against the public model."

**2. A private token computation, checked instantly (1.5 min), live.**
Browser: choose "Verify a private token computation", then the block
receipt. Say: "This is a whole small model: embedding, two complete
transformer blocks and a next-token step. The input tokens and the output
token are hidden. The receipt is 785 bytes and checks in milliseconds. If we
change the proof or the policy, it is refused." Caveat, said once: "It is a
tiny synthetic, untrained model on a general-purpose zkVM. It takes about two
hours to prove, and it rests on about 97-bit conjectured security and a
Groth16 trusted setup. It shows privacy end to end; it is not our speed
engine."

**3. Our own prover, live (1 min).** Browser: the third option, a fresh
native complete-block proof. Say: "The same kind of block on our native
prover, proved now in about a tenth of a second. A separate process verifies
it from bytes and refuses tampered copies. It uses a public test fixture, so
this run demonstrates the mechanism, not a secret input. This profile is the
one whose privacy argument our security review has accepted, at toy size, on
the CPU path." Say the last sentence only after plan P0-2 has confirmed the
binary's source pins.

**4. Real model geometry on a laptop GPU (2 min), from the recording, or
live if the morning run was clean.** Say: "Now one full-size block with the
geometry of a 125-million-parameter model: 512 hidden tokens, attention with
12 heads, synthetic weights. It takes 17 seconds to prove on this laptop's
RTX 4070 and verifies in under a second. The phase table shows the softmax
check is almost half the time, and that is what we move to the GPU next. We
also chain twelve of these blocks under one proof: 512 tokens through the
whole stack in 6.6 minutes on the CPU, or 1.3 proved tokens per second."

**5. Where we are against the goal (1.5 min), numbers slide.**
Show measured and projected values in two different colors:
- Measured: 1.29 tok/s for the synthetic 125M-geometry stack on CPU.
- Projected: about 0.3 tok/s for an 8B-geometry stack on this laptop, about
  1 on an RTX 5090 with today's code, and about 5-13 on a 5090 once the proof
  sumchecks and witness run on the GPU (not built).
- Target: 50 proved tok/s for a private 8B model.

Say: "Everything above one block of 125M geometry is a projection from
measured per-block costs. This week we measure the 1B-geometry block, and
the first 5090 run if the machine is up."

**6. Close (30 s).** "What exists: a working private transformer-block
prover, chained stacks, a decisions register for every security ruling, and
a trained 1.1B checkpoint pinned for the first trained proof. Next: that
trained proof, then the GPU port toward 50 tokens per second."

**Likely questions, and honest answers:**
- *"Have you proved a real LLM privately?"* "Not yet. Our private proofs use
  synthetic weights at 125M-model geometry. The first trained target,
  TinyLlama 1.1B, is pinned, and integer calibration is next." If the 10-02
  gate passes, add: "one trained block, not yet the whole stack."
- *"How big are the proofs?"* "785 bytes on the zkVM toy. Our fast prover's
  receipts are about 41 MB per 125M block; shrinking them is open work."
- *"Is it secure / audited?"* "Security levels and assumptions are written
  down for every artifact (about 97 bits for the zkVM line; about 94
  projected for a whole 8B proof on ours). The reviews are internal
  adversarial ones; there is no third-party audit yet."
- *"Versus other vendors?"* "We don't compare with unverified vendor
  numbers. We publish our own measured and projected figures, labelled
  separately."
- *"When do you hit 50 tokens/s?"* "Nothing we have measured or counted gets
  there for private 8B yet. The best counted path gives 5-13 on a 5090 after
  a GPU port, and we are measuring its first steps this month."

**Never say:** "full 8B proof", "trained model" (for private runs), "50
tokens/s", "128-bit", "no trusted setup" (for the 785-byte receipts),
"audited", "weights private", or "5090 results".

**Fallbacks:**
- **B, if the browser demo or GPU fails:** use the command-line
  equivalents. The first two commands verify the saved receipts; the last
  two run the fresh native proof and its fresh-process verify:
  ```
  python3 /home/victor/IntelligenceRegulation/scripts/zk60_zkvm_demo.py verify --profile token --expected-image-id 3c0631ee629a40a78421e03cd5c6ac9ffdafa026a1289aa9207fcce6c016430b --wrap /home/victor/IntelligenceRegulation/zkvm-block/target/release/zk60-token-wrap --policy /home/victor/IntelligenceRegulation/results/zk60_loop_20260918/token-integration/token_public/policy.bin --receipt /home/victor/IntelligenceRegulation/results/zk60_loop_20260918/token-integration/token_public/receipt.bin
  python3 /home/victor/IntelligenceRegulation/scripts/zk60_zkvm_demo.py verify --profile block --expected-image-id 8d74aab3d58c1a713045dfd1ea4ffa15e61439e61af58b72a5fdb792111998d9 --wrap /home/victor/IntelligenceRegulation/zkvm-block/target/release/zk60-block-wrap --policy /home/victor/IntelligenceRegulation/results/zk60_loop_20260918/block-integration/groth16_public/policy.bin --receipt /home/victor/IntelligenceRegulation/results/zk60_loop_20260918/block-integration/groth16_public/groth16.bin
  /home/victor/IntelligenceRegulation/hashline/target/release/examples/zk60_private_block prove  /tmp/zk60-vc-demo-01
  /home/victor/IntelligenceRegulation/hashline/target/release/examples/zk60_private_block verify /tmp/zk60-vc-demo-01
  ```
  Play step 4 from the recording.
- **C, if the laptop fails:** play the recorded session and show the
  artifact SHA-256 values from `READINESS.md` section 5.
- **D, if there is no screen:** use the numbers sheet and READINESS
  sections 0 and 3.
