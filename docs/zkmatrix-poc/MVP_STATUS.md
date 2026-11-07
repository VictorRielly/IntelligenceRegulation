# Where the MVP stands, in plain words

**2026-11-05: efficiency first (Victor). Plan: `ZK60_EFFICIENCY_PLAN_20261105.md`. Phase A results so far
(byte-preserving, measured on the Mac, every receipt verified; `results/zk60_effplan_20261105/`):**
These timings use synthetic diagonal public weights at the true 8B geometry, so dense-weight work is not yet measured
here. The rates count proving and witness work. Verification time is recorded separately, as
`ZK60_THROUGHPUT_TARGET.md` asks: about 2.3 s per receipt, from four stream receipts verified in 9.3–9.9 s.

| One W16R2 8B T128 request, 32 blocks, forks N = 6 | before (2026-11-04 night) | now |
|---|---:|---:|
| preflight (A2) | 0.35 s | 0.08 s |
| the sealing pass, the serial forward chain (A4: weight products on the GPU, exact; A15: its own 8-thread pool) | 5.45 s | 3.3–3.4 s |
| the fork run's host work (A11: one rayon pool per fork, not one shared pool) | about 0.5 s per block | stream +19%, proof only −9.5% (A/B, both orders) |
| the device slots' tables, 1.32 GB per block (A12: built on the GPU, not the CPU) | about 47 ms per block per fork | stream +5%, proof only −6.5% (A/B, both orders) |
| the openings' store folds (A8: row-sparse, prefetched, 16-bit lanes) | A 24.6 ms, H 31.5 ms per fold | stream +2.2%, proof only −2.9% (A/B, both orders) |
| the forks' host sums (A14: summed exactly, reduced once) | — | proof only −2.8%; the stream unchanged when re-checked on top of A15 (A/B, both orders) |
| the sealing pass's thread pool (A15: 8 threads, not the 32-thread global pool) | sealing 4.3 s | one request −10.5%, stream +16.1% (A/B, both orders, every pair) |
| the forks' lookups and repeated public checks (A17: lookups read in place; the preflight's check record reused) | — | proof only −3.6%, stream +2.6% (A/B, both orders, every pair) |
| the sealing builder's serial work (A16: cached layouts, parallel loops, one public check per block) | sealing 3.5 s | **sealing 1.5–1.7 s**; one request −23.8%, stream +12.8% (A/B, both orders, every pair) |
| the forks' table helpers and registry re-check (A18: inverse tables reused; the preflight's record stands in for `define`'s check) | 4.65 ms per block | 0.78 ms; neutral overall: one request −1.9%, proof only +0.7%, stream +0.3% (A/B, both orders) |
| production's D55 path proves with the blocks its sealing pass loaded (A19: no second load of all 32 blocks) | 19.3 s per request in production | **15.3 s**; one request −20.9% (A/B through production's function, both orders, every pair) |
| production's per-request host work (A20: the loads 4 layers ahead on their own threads, the record's digest beside its SHA-256s, the receipt written by 16 threads) | 16.1 s per request in production | **8.0 s**; one request −50.1% (A/B through production's function, both orders, every pair) |
| production's host hashing (A21: SHA-256 on the Arm SHA-2 instructions, in-tree; the block digest as BLAKE3's tree in parallel) | 7.86 s per request in production | **7.23 s**; one request −8.0% on the merged tree (−10.5% in the agent's 6-pass A/B), every pair; the verifier −30% |
| **one request from its input, all witness work on the clock (the harness: the model already in memory)** | 11.1 tok/s | **23.4–23.9 tok/s** (best 5.35–5.47 s) |
| **one request through production's `stack-prove` path (each layer loaded and hashed per request; synthetic 8B stack)** | 6.6 tok/s (19.3 s, before A19) | **18.3–18.8 tok/s** (best 6.82–6.98 s) |
| **production's stream, `stack-serve` (A22: the model loaded once, one request's sealing beside the last one's proof; A23: the resident blocks shared, their startup digests and checks reused, D72/D74), 4 requests, steady** | — (no production stream before A22; 29.2–29.7 with A22 alone) | **32.4–32.6 tok/s** (amortized 27.5–27.8; 8 requests 31.9–32.2 steady, 29.4–29.7 amortized; one request 20.2 tok/s) |
| **a stream of 4 requests, steady (the harness)** | 15.9 tok/s | **32.3–33.4 tok/s** (amortized 28.8–29.6; latency 5.8–10.9 s) |
| proof only | 22.7 tok/s | **32.5–34.2 tok/s** (best 3.75–3.94 s; it varies from run to run on the shared Mac) |
| **the media app (Shieldstral classifier, R13 blocks, T128, 3 category proofs per post), through the app end to end: every receipt freshly verified, publication included (A24, 2026-11-07, merged 9be693d0; development mode `shieldstral-fast`, privacy statement pending, not production)** | 0.17 proved tok/s (r16b, CPU 2 threads; Astra 2026-11-05) | **one post 5.5 tok/s (70 s); an 8-post stream 11.4 tok/s** (269 s; second half 15.4) [MEASURED, public posts, single runs on the shared Mac] |
| **the media app with lane A26's binary (the same receipts byte for byte; the CPU work per category proof cut by a third; development mode `shieldstral-fast`, privacy statement pending, not production)** | A24: native stream 11.25 tok/s, one post 55.2 s; app stream 11.4 | **native stream 14.10 tok/s (+25%, A/B pairs both orders), one post 46.7 s (+18%); through the app: stream 13.8 tok/s, one post 54.4 s (7.1 tok/s); proof only 15.5** [MEASURED; app rows single runs] |

- The CLI's witness cache is now sized to the machine (A3).
- A row census: 52% of a block's committed rows are LogUp helpers, the target of the B4 and B5 protocol levers.
- **A7 (GPU timestamps): the fork run is not GPU-bound** [MEASURED].
  - In the forks phase the GPU is busy only 53–59% of the time. It sits idle when all six forks are doing host work at
    once.
  - A fork's host work per block takes 0.47–0.62 s with six forks running, against 0.22 s alone, while only about 20
    of the 32 cores are busy.
  - Per-thread GPU queues did not help once the A/B ran in both orders (+1.4% proof only, −2.7% stream). They stay
    opt-in.
  - The zero-check kernel work (A6) is deferred, since kernels are not the limit.
- **A11 found and fixed the cause** [MEASURED]: the six forks shared one rayon thread pool, so each fork's parallel
  steps waited behind the other forks' work. Each fork now has its own pool. Byte-identical; the A/B was repeated
  independently on the merged tree.
- **A12: the device slots' tables are now built on the GPU** [MEASURED]. Every table word is checked equal to the CPU's;
  the A/B was repeated independently on the merged tree. The forks phase is now about 3.9–4.0 s, against about 2.75 s
  of GPU work.
- **A8: the store folds are 2–2.5× faster** [MEASURED]. There was no Gram folding to do (each opening already reads its
  rows once); the fold was waiting on memory. The independent A/B gain is smaller than the agent's (−2.9% against
  −5.1% proof only). One note for the privacy gate: its fast path makes the prover's time depend slightly on whether
  the hidden words are 16-bit.
- **A13 did not pay, and A14 helped proof only but not the stream** [MEASURED]:
  - A13, doing each block's before-challenge work during the sealing pass: what the forks saved, the sealing pass lost.
  - A14's lazy sums: proof only −2.8%, the stream −1.8%. Re-checked on top of A15, the stream is unchanged; they stay on.
- **A15: the sealing pass now runs in its own 8-thread pool** [MEASURED].
  - On the 32-thread global pool, 25 of its 40 CPU-seconds were rayon's own waits and spins.
  - Independent A/B on the merged tree against production's previous form, every pair: one request −10.5%, the stream
    steady +16.1%. Byte-identical.
  - Phase A's expected Mac result (16–18 tok/s for one request, 22–25 for the stream) is now met.
  - The stream is now balanced: about 4.4 s of proof per request against about 4.6 s of sealing beside the forks.
- **A17: the forks' host work is 10% lower** [MEASURED].
  - At W16, lookups are read straight from the witness planes instead of being copied first (about 220 MB of fresh
    pages per block [INFERRED]).
  - Each fork reuses the preflight's record of its block's public checks. The record is used only for that very block
    object at that shape; anything else re-checks.
  - Independent A/B on the merged tree, every pair: proof only −3.6%, the stream steady +2.6%. Byte-identical.
  - On its own, A17 left the stream limited by sealing: about 3.9 s of proof per request against about 4.4 s of sealing
    beside the forks. A16 (below) fixed that side.
- **A16: the sealing pass is twice as fast** [MEASURED].
  - The builder's serial work fell from about 1.1 s to 0.04 s per pass. The block layouts are now cached per
    geometry, the per-position loops and normalization run in parallel, and production checks each block's public
    data once instead of three times.
  - Independent A/B on the merged tree through production's builder, every pair: one request −23.8% (17.4 → 22.8
    tok/s), the stream +12.8% steady and +17.1% amortized. Byte-identical; refusals unchanged.
  - **The stream is now limited by the six proving forks** (about 3.9 s per request) and no longer by sealing (about
    2.6 s beside the forks). Its steady rate is the forks' own, about 33 tok/s. The forks' host work and W16R3 are
    the next levers.
- **A18: two small fork savings, neutral overall; A13 now pays but is not in production yet** [MEASURED].
  - Each fork's table helpers reuse inverse tables already made (4.65 → 0.78 ms per block), and the preflight's record
    replaces `define`'s repeated registry check. Independent A/B on the merged tree, both orders: one request −1.9%
    (4 of 4 pairs), proof only +0.7%, stream +0.3%. That is within noise; both stay on and `0` restores either.
    Byte-identical.
  - A13's window (each fork's before-challenge work done during the sealing pass) now pays, because the stream is
    fork-bound. In the harness, at window 16: the stream +5.0% steady (6 of 6 pairs), one request −2.3%, about 12 GiB
    more memory. It stays off until production's D55 path can use it; A19 is doing that port.
  - Adding short parallel regions to the forks made them slower, since six fork pools already fill the cores.
- **A19: production's own path, measured for the first time; 21% faster; a gap to the harness found** [MEASURED].
  - `stack-prove --d55-workers` now proves with the blocks its sealing pass already loaded and checked, instead of
    loading all 32 again. Independent A/B on the merged tree through production's function, every pair: one request
    −20.9% (19.3 → 15.3 s). Byte-identical. H-1 still holds (D68, security owner's reading).
  - A13's window now works from production, but stays off: one request −0.4% to −1.0%, inside the noise, for 10–30
    GiB more memory. Production proves one request per process, and the window paid only on the harness's stream.
  - **Production's one request is 15.3 s = 8.4 tok/s, against the harness's 5.4 s = 23.7.**
    - The harness keeps the model in memory. Production loads every layer again for each request and hashes its
      record. Those loads slow the witness builds beside them about 5×, so the sealing pass takes 9.1 s instead of
      about 1.5 s.
    - Writing the 819 MB receipt adds about 1.9 s.
    - A real export also reads and pads the weight files, so production's figure is a lower bound until a trained 8B
      export is measured.
  - The harness rows above are what a server that keeps the model in memory could reach. They are not what today's
    one-request CLI gives.
- **A20: production's one request halved, 16.1 → 8.0 s (16.3–16.9 tok/s)** [MEASURED, A/B on the merged tree through
  production's function, every pair; byte-identical; H-1 still holds, D71].
  - SHA-256 runs in software on this Mac (about 0.5 GB/s). Each layer's record took 252 ms, and the receipt write was
    mostly frame hashing.
  - A19's "the loads slow the builds 5×" was a clock artifact: the builds take 40 ms each, and the sealing pass was
    waiting for its loads. With 4 loads ahead on their own threads, the record's digest beside its SHA-256s and 16
    receipt writers, the sealing pass fell from 9.7 to 3.3 s and the write from 1.95 to 0.33 s. The prove call (4.3 s)
    is now more than half of the request.
- **A21: host hashing, 8–10% off production's one request** [MEASURED, every pair; byte-identical].
  - SHA-256 now runs on the Arm SHA-2 instructions, written in-tree with no new crate: 0.5 → 2.3 GB/s.
  - The block digest is BLAKE3's own tree, hashed in parallel: 115 → 6 ms.
  - Production's one request: 18.3–18.8 tok/s. The verifier is 30% faster.
- **A22: production now has a stream form, `stack-serve`: 29.2–29.7 proved tok/s steady** [MEASURED, merged tree,
  independent A/B; D70].
  - It loads and checks the model once, then proves one request per input line. Each request's sealing runs beside the
    previous request's proof.
  - Each request has `stack-prove`'s statement identity, receipt size and frames, and passes `stack-verify`. Randomness
    is fresh per request.
  - H-1 holds per request: a refused or failed request leaves the stream running (D73).
  - **One data owner per process** (D73). A request's latency shows the previous request's timing.
  - **The gap to the harness (32.7 on the same tree) is about 11%:** the preflight re-hashes 32 block copies, and the
    forks slow beside the next request's copy of 7.8 GB of layers.
  - D72 allows CS-6 to use a digest kept with the block.
- **A23: production's stream within 2% of the harness, 32.4 tok/s steady** [MEASURED, merged tree, independent A/B,
  4 of 4 pairs].
  - The resident blocks are shared across requests instead of copied (+7.9%).
  - Their startup CS-1/CS-4 pass is reused at an equal shape (D74, +4.4%). The verifier still runs every check.
  - Peak memory is down from 60 to 46 GiB.
  - One request through the server: 20.2 tok/s.
  - What is left is the prover core: the fork run is 3.64 s of a 3.93 s period.
- **D63 Lean, the block-level `CircuitIff` proved (second round, 2026-11-06)** [PROVED; MEASURED for L1].
  - `block_circuitIff : CircuitIff (blockModel S P) (blockArith S P)` is an instance of the approved statement: a W16R2
    block's constraint system is satisfiable exactly when its output is the integer model's. `run_circuitIff` chains
    blocks through their boundary planes. Both are at the block's logical positions.
  - Newly in the iff: the matmul hand-off (every hosted value below 2^58, so the 2^62 premise is proved), RoPE, the
    products, the exp and SiLU lookups, and the gate with its class.
  - The full Lean build is green, with no warnings, `sorry`, `native_decide` or new axiom.
  - L1: the fixture passes 101,956 checks and the T = 128 rung 760,388 checks, 0 failed.
  - **Premises left:**
    - what `Satisfies` asserts, which is L3's to discharge: the zero-checks, the hosted sums and the row sums;
    - the LogUp premise, stated exactly: every looked-up tuple is in the code's table;
    - the layout map;
    - the run's boundary link.
  - **Fourth round (merged after the second): the whole forward pass.**
    - `tokenRun_circuitIff` covers the prompt ids, stage IN, every W16R2 block and stage OUT: the run's constraints
      are satisfiable exactly when the attested next token is the integer model's. The argmax ties go to the lowest
      id, as the code's `first_argmax` does.
    - `classifyRun_circuitIff` does the same for the classifier verdict.
    - The Low stack's int16 product is now inside `block_circuitIff`.
    - L1: stage OUT and OUT-C pass 992 checks, 0 failed.
    - Further candidates C10–C13 are estimates. C12 would drop the last block's dead rows, about −2.5% of a run, but it
      is a model change.
  - Not modelled: DD and the sealed-selector variants.
  - **Next:** compose with L3, which turns an accepting transcript into `Satisfies`; then the layout map; then
    `ProductionReady`. Both touch what W16R3 changes, so they wait for its freeze.
- **D63 Lean, the two statements assembled (generic, 2026-11-06)** [PROVED; `formal/ZK60Formal/Assembly.lean`,
  `ZK60_LEAN_ASSEMBLY_20261106.md`].
  - **Statement 2:** `semanticHiding_of_zeroKnowledge` turns zero knowledge into the "learns nothing about any
    property" form exactly as approved. So the receipts' hiding reduces to building one simulator.
  - **Statement 1:** `knowledgeSound_of_extract` turns an extractor of a satisfying witness into knowledge soundness,
    using `CircuitIff`. This is where the L3 soundness work and the L2 `tokenRun_circuitIff` meet.
  - **The gate:** `productionReady_of` assembles `ProductionReady` from its parts. `binding_of_colCommit` derives
    binding from the proved Merkle binding.
  - No gap was found in the approved statements.
  - **What is left for a production profile:**
    - the Lean `Protocol` instance, its prover and verifier (L5);
    - the per-profile extraction (L3 composed, the layout map, the M opening under Fiat–Shamir);
    - completeness (that an honest prover is accepted, which nothing proves yet);
    - the column-commitment instance for binding;
    - the zero-knowledge simulator (Fiat–Shamir programming, composition over the run, R receipts).

    Most of these wait for W16R3's freeze.
  - **The generic halves of the last two, proved the same day** [PROVED; `CompleteSub.lean`, `ZKHybrid.lean`].
    - **Completeness:** every sub-protocol model accepts its honest prover. That covers the sumcheck (masked,
      extended and CFS forms), the zero-check, LogUp (refusing only with probability at most M/|F|), the openings,
      M's tests and the Merkle paths. They compose into the approved `Complete` form, where each refusal is about
      2^-111 against the 2^-40 target.
    - **Zero knowledge:** the random-oracle programming lemma and the R-receipt hybrid, ending in
      `zeroKnowledge_of_hybrid` and its target corollary.
    - What is left per profile: the Lean prover and verifier, the per-receipt simulation step, the layout links, and
      the extraction.
    - **Finding A5, a ruling owed later:** summing the per-receipt bounds leaves a q·R cross term that the approved
      zero-knowledge target has no slot for. It matters only at absurd scales (about 2^126 queries and 2^118
      receipts). The fix is a sharper per-profile argument, or a cross term in the target, or a cap on R.
- **D63 Lean, L5's foundation: the verifier's primitives in executable Lean (2026-11-06)** [PROVED; MEASURED for the
  agreement check; `ExecField.lean`, `ExecTranscript.lean`, `ExecMerkle.lean`, `ExecBlake3.lean`;
  `results/zk60_lean_l5_20261106/`].
  - The field (Goldilocks and its quadratic extension), the Fiat–Shamir transcript and the Merkle column check are
    written in Lean as the Rust code runs them. Each is proved equal to the model the soundness proofs use:
    - each field operation is the field's;
    - the transcript is the Fiat–Shamir chain, and its challenges are the modelled ones;
    - the column check accepts exactly when the Merkle opening holds, so Merkle binding holds for the program itself.
  - BLAKE3 is written too, in its three modes. It stays the random oracle, so it is tested, not proved.
  - Agreement with Rust: 5,553 checks, 0 failed, including the official BLAKE3 vectors and three whole PCS openings
    replayed. A negative control of six single changes fails exactly 6.
  - On the merged tree: zkp-core's 81 tests and the export test pass, and the regenerated corpus is byte-identical.
    The Lean build has 3449 jobs and no warning. 74 declarations use at most `propext`, `Classical.choice` and
    `Quot.sound`. The L1 check still gives 101,956, 0 failed.
  - W16R3 changes none of these.
  - Finding L5-2 is already handled in the code. `Fp2::from_bytes` would read a word w ≥ p as w − p, but no decoder
    calls it. The block receipt decoder (`wire.rs`) and the ffn_v3 decoder refuse any word ≥ p, so the Lean decoder
    must copy that refusal.
  - **Left for the per-profile verifier, after W16R3's freeze:**
    - the `Protocol` instance and the receipt decoder;
    - the sumcheck and LogUp arithmetic;
    - the opening's checks (B1 changes the PCS encoder);
    - M's mask check and the D55 run schedule, each proved equal to its model;
    - a corpus from real W16R3 receipts.
- **D63 Lean, L6: the generic sumcheck verifier in executable Lean (2026-11-06)** [PROVED; MEASURED for the agreement
  check; `ExecSumcheck.lean`, `ExecMle.lean`, `ExecCfs.lean`; `results/zk60_lean_l6_20261106/`].
  - Every block slot checks its sumchecks through zkp-core's one generic verifier. That verifier now exists in Lean,
    together with its interpolation, its eq and multilinear evaluations and its zero-knowledge mask pieces.
  - **Main theorem (`scVerify_accept_iff`):** the program accepts a sumcheck exactly when the soundness proofs' model
    does, with the challenges taken from the transcript chain. This holds for every hash function. So the proved
    Fiat–Shamir soundness of the sumcheck applies to the code itself.
    - It needs degree ≥ 1 and canonical words. The block decoder enforces canonical words, and every slot has degree
      ≥ 2.
    - The caller still checks the terminal identity, the claimed sum and the openings.
  - The mask's weights give its cube sum and its value at ρ, and its rounds are the model's. The masked terminal and
    the extension round are the models', so the extended soundness theorem applies to what the code sends.
  - Agreement with Rust: 1,206 checks, 0 failed. Among them are 171 runs, honest and tampered, whose verdict, error
    message and transcript state all match. A negative control of eight single changes fails exactly 8.
  - Sol's W16R3 design keeps this mathematics; B2 only batches slots into one larger sumcheck.
  - Findings (all Info):
    - L6-1: a degree-0 round would make the verifier panic, but no slot has one.
    - L6-2: the mask weights need fewer than 64 variables, a per-profile `decide`.
    - L6-4: the Fiat–Shamir chain model counts with a natural number, while the code uses a u64. Mapping one onto the
      other is per-profile glue. (Closed by L7, below, with no premise.)
- **D63 Lean, L7: Fiat–Shamir soundness of the executable sumcheck verifier (2026-11-06)** [PROVED;
  `ExecSumcheckFS.lean`; `results/zk60_lean_l7_20261106/`].
  - **Main theorem (`exec_sumcheck_fs_sound`):** take a cheating prover that makes q hash queries and picks any
    transcript header of s operations, a false claimed sum fixed by that header, and the round messages. The code's own
    sumcheck verifier, run on the code's transcript after that header with the caller's terminal check, accepts with
    probability at most T·d/|K|·(1 + p/2^128)² plus two hash-collision terms, where T = q + s + 2n + 1.
  - At a slot's shape (degree ≤ 4, up to 2^64 hash queries, 30 rounds, a header of up to about a million operations)
    this is at most 2^-61, a Lean corollary. The exact figure, about 2^-62, is arithmetic done outside Lean.
  - L6-4 is closed with no premise. The proof reads the protocol's state off the code's own chain and never reads the
    wrapping u64 squeeze counter; two squeezes with equal counters still hash different inputs unless digests collide,
    and collisions are already counted.
  - On the merged tree: the Lean build has 3453 jobs and no warning. All 39 new theorems use at most `propext`,
    `Classical.choice` and `Quot.sound`. L6Check (1,206), L5Check (5,553) and the L1 check (101,956) still give 0 failed,
    and both Rust corpora regenerate byte for byte.
  - Findings (all Info):
    - L7-2: `sumcheck::verify` does not absorb the claimed sum, so each slot's claim must be fixed by the transcript
      before its rounds. Today's block code meets this [CODE, read 2026-11-06]: in `private_block/argument.rs`,
      `token_io.rs` and `private_attention/argument.rs`, the claim is the slot's own scalar, absorbed under
      `pb-scalar` just before the rounds, plus earlier slots' absorbed scalars times coefficients drawn from the
      transcript. The per-profile proof must show it again for W16R3's batched slots.
    - L7-3: the theorem takes a fixed header length per slot.
    - L7-4: Lean runs away on the literal Goldilocks p and on huge concrete finite types (the first draft hit the
      guard's 24 GiB cap). Later lanes state such facts for a variable p and then instantiate.
  - **After L7, the Lean work that W16R3 doesn't change is finished** apart from one generic piece: re-stating the
    composition files (`FSCompose.lean`, `FSWideRbr.lean`) on this reader, so the whole receipt's chain, including
    rounds with several squeezes (LogUp's), gets the composed bound. L8, below, does that.
- **D63 Lean, L8: Fiat–Shamir composition on the code's own transcript (2026-11-06)** [PROVED; `ExecComposeFS.lean`;
  `results/zk60_lean_l8_20261106/`].
  - A receipt checks many sub-protocols one after another on one transcript. L8 proves the combined bound for any such
    schedule, on the code's own transcript chain.
    - **`fs_code_chain_sound_sched`** (the general form): the schedule may include rounds without a message and vector
      challenges of several squeezes. The chance that some sub-protocol starts from a false claim and yet all of them
      pass is at most T·ε plus two hash-collision terms, where ε is the largest per-round error and T the hash queries
      plus the receipt's items plus 1.
    - **`exec_sumchecks_fs_sound`** (on the code): a run of the code's sumcheck slots on one transcript, each slot's
      claim fixed by the transcript before its rounds. The chance that some slot's claim is false and yet every slot's
      verifier accepts is at most the bound of ONE slot of the largest degree, with no factor for the number of slots.
      At a slot's shape this is at most 2^-61, a Lean corollary.
  - W16R3's batching (B2, B3) only changes the list of slots the theorem is applied to.
  - On the merged tree: the Lean build has 3454 jobs and no warning. All 64 new theorems use at most `propext`,
    `Classical.choice` and `Quot.sound`, and L7's 39 still do. L6Check, L5Check and the L1 check still give 0 failed,
    and both Rust corpora regenerate byte for byte.
  - Findings (all Info):
    - L8-4: a slot's terminal claim handed on to an opening needs a "release" step and its proof in the per-profile
      instance.
    - L8-5: the existing LogUp and opening round lemmas use a two-halves digest type rather than the code's 32-byte
      digests. They need a short transfer through a bijection, not yet done.
  - **With L8, the Lean work that W16R3 doesn't change is finished.** The rest waits for W16R3's freeze:
    - each slot's claim as a function of its transcript (the arithmetization);
    - the batching and zero-check rounds as their own sub-protocols;
    - the extractor (the polynomial is the committed tables');
    - LogUp, the openings and M, plus the L8-5 transfer;
    - the receipt decoder, the D55 schedule and the simulator.
- **The media app on the fast machinery (A24, 2026-11-07, merged 9be693d0)** [MEASURED; `results/zk60_a24_app_20261107/README.md`].
  - What A24 built:
    - `zk60_classify serve` keeps the classifier resident, loaded and checked once, and reuses the sealing pass's
      witnesses.
    - `check-serve` verifies each receipt once, where the CLI verified it three times.
    - The app's new development mode `PM_PROVER=shieldstral-fast` uses both servers.
  - The receipts are ordinary classify receipts: the unchanged CLI verifier accepts them. No 8B path changed.
  - Every record says "privacy statement pending" and "not production". D58 covers only the r16b CPU binary; D63 still
    holds.
  - **11.4 proved tok/s for a stream of posts, from 0.17. Victor's 30 is not reached.**
    - The stream is CPU-bound: about 300 core-seconds per category proof, a third of it verification.
    - The next lever was meant to be the classifier on W16R2 blocks, with about 1.8× fewer committed rows than R13
      (efficiency plan A10). **Lane A25 found that the real model cannot run at W16R2 as the code stands**
      [MEASURED; `results/zk60_a25_app_20261107/README.md`]:
      - At W16/W16R2, the 16-bit range families depend on each layer's requantization shifts and gate.
      - The real Shieldstral export has 17 distinct shift sets over its 26 layers. The trained-model check refuses 8
        layers, and the 26 layers would need 3 different plane lists.
      - **The 8B W16R2 figures above use one synthetic calibration in every block, so they do not yet transfer to a
        real trained model.**
      - The routes, each needing design, review and a ruling by Victor:
        - (a) per-layer plane lists in the statement's schedule;
        - (b) an export with one calibration for all layers, which is a new integer model to re-validate;
        - (c) R13 at rate 1/2 (D59-style), for a smaller gain.
      - A25's unregistered W16R2 development profile is kept on its branch, not merged. The R13 path is unchanged.
- **The media app's CPU work per proof cut by a third, the receipts unchanged (A26, 2026-11-07)** [MEASURED;
  `results/zk60_a26_app_20261107/README.md`].
  - Measured, A24's stream was not CPU-bound: about 185 CPU-s per category proof, half the cores busy. 37% of
    the prover's CPU was one product: R13 LOW+h24's FFN down projection reads a 24-bit activation, which A4's
    int16 GPU kernel declined. It now runs on the GPU as two exact int16 halves. The verifier's column test
    sums only over each weight's nonzero rows; its public tables use split eq tables.
  - A/B pairs in both orders, every receipt freshly verified: the 8-post stream 11.25 → 14.10 proved tok/s
    (+25%), one post 55.2 → 46.7 s, the proof-only clock 12.4 → 15.5. Through the app: 13.8 tok/s (stream),
    54.4 s (one post). CPU per proof 185 → 124 CPU-s.
  - **Byte identity on the real export:** a new fixed-entropy harness for the Mac (an interposer for
    `/dev/urandom`) shows A24's and A26's binaries make identical receipts, every file of every category, and
    each verifier accepts the other's. The app pins the A26 binary; statement identity `e4f97455…` unchanged.
  - **30 tok/s is not reached: the stream is now GPU-bound** (83% mean utilization, 96% median). What is left
    needs less GPU work per proof (A10/A25's W16R2 route and a ruling, faster device sumcheck kernels) or a
    second GPU.
  - Two further cuts are in the binary but off, for the security owner's reading of D72 / D74: the prover's
    kept digest and startup check for `classify-serve`, and a verifier that checks and re-hashes each block once
    per verification instead of twice (−20% verifier CPU).
- **D63 Lean, per profile at W16R2 (2026-11-07, Victor away: "focus on completing the lean proofs")** [PROVED; each
  lane checked on the merged tree; docs `ZK60_LEAN_L9/L11/L12_*_20261107.md`].
  - The W16R3 freeze needs Victor's approval, so the per-profile proofs now target **W16R2**, the profile that the
    code, the 8B stack and the media app's classifier run today. W16R3 will then be a swap of named definitions, not a
    rewrite.
  - **L9, the block verifier in executable Lean.** It decodes a real W16R2 block receipt (14.3 MB) byte for byte and
    replays all 1,609 of its challenges: 273 checks, 0 failed. Its Fiat–Shamir bound on the block's real schedule is
    one slot's bound for all 23 slots, at most 2^-61. Finding L9-5 (Low): W16R2 slots reach degree 5, so the L7/L8
    degree-4 figures must not be quoted for a W16R2 block.
  - **L11, the slots and the layout map.** The slots' checks and LogUp's conclusion give the block's constraint system
    at the model's positions (`blockSat_of_slots`, which feeds the proved `CircuitIff`). Checked against a real receipt:
    404 checks, 0 failed. One latent Low finding: a hard-coded lookup width that agrees today.
  - **L12, the classifier's token stages.** The embedding stage IN-C is proved as one theorem. The head stage OUT-C's
    byte lookup and margin are proved, and the run's boundary links are in place. About 2^-111 per stage
    [ESTIMATE].
  - **L10, the openings, M's test and `Binding`.**
    - The opening and M checks are executable Lean and agree with the code on a real receipt: 48 checks, 0 failed.
    - M's Fiat–Shamir bound is now PROVED on the code's own transcript at 2^-106. Until now it was assumed.
    - `Binding` is proved at the target, for the token runs and for the classifier.
    - Open (L10-6, Medium): each slot's final claim is true of the committed tables. That is the knowledge step, and
      it is L16's target.
  - **L13, the slot builders.** Lean rebuilds all 23 slot IRs of a real receipt from the shape alone, equal to the
    code's: 179 checks. Each slot is proved sound at ≤ 2^-120. The block's composed bound is an ESTIMATE so far, about
    20 bits under the target per query.
  - **L14, zero knowledge for one block (Statement 2).**
    - The chain from the honest-verifier lemmas to `ZeroKnowledge` is proved, generic in the receipt's shape.
    - The simulator runs the honest prover on a stand-in input.
    - Within the target for up to 2^96 receipts. The honest prover's model is still a hypothesis.
    - **For Victor (L14-1, Low):** the approved target is for any number of receipts. Today's proof reaches 2^96. Lane L19
      is trying a sharper count; otherwise it is a cap or a cross term, which is your call.
  - **L15, the token stages whole.** The verdict stage OUT-C (about 2^-112) and the next-token stage OUT (about 2^-108)
    are each proved as one theorem. Their sumchecks are ≤ 2^-61 under Fiat–Shamir. The registered Shieldstral policies'
    parameters are checked.
  - **L17, the block results at R13, the media app's real profile.**
    - The decoder (including the classify run's D12a segment frame), the block's Fiat–Shamir bound (≤ 2^-61), the
      openings at rate 1/4, `Binding` and the layout map all hold at R13. Every bound meets its target.
    - All 26 real Shieldstral layer calibrations pass R13's check, with a constant plane list (proved).
    - Checked on real R13 receipts: 408, 302 and 35 checks, 0 failed.
  - **L16 and L20, the block's knowledge statement.**
    - For any block shape: an accepted block yields extracted planes that satisfy the block's constraints, except with
      probability ≤ εsTarget for every q.
    - L20's per-position count brought the constant term from 2^-82.6 to 2^-104.2.
    - Premises left: two deterministic code-to-model links (lane L22), and the slot relations plus LogUp within a
      budget (lane L21).
  - **Running:**
    - L18, the classify run's `Protocol` and the top-level `ProductionReady` with the remaining premises named;
    - L19, zero knowledge's links and the sharper count;
    - L21, the slot relations and LogUp under Fiat–Shamir;
    - L22, the openings' deterministic links (hexec, hsem) and the extraction-failure instance.
  - **Still open before production:**
    - the run level: the D12a frame for the classifier, the D55 tree for the 8B stack;
    - the honest prover as a Lean model;
    - the `Protocol` instance and its assembly into `ProductionReady` (L18);
    - then W16R3's delta.
- **A gap the Lean work exposed: W16R2 has no token-I/O run profile yet** [CODE, `run.rs`].
  - Token-I/O runs (embedding in, LM head and argmax out) are registered for the older trained-statement profiles
    (TinyLlama, and Llama-3-8B at T32 and T128), not for W16R2.
  - So today's W16R2 throughput figures prove the 32 transformer blocks: the next-token stages are not in a W16R2
    receipt yet.
  - A W16R2 (or W16R3) token-I/O profile has to be registered, gated, and its stage cost measured. The 8B head is a
    4096 × 128,256 product on the last row.
  - `tokenRun_circuitIff` gets its production instance from that profile.
  - **For Victor, later:** the statement's admissibility cannot see the weights. This is sound under P1, but P3 (hidden
    weights) will need a statement change.
- **D63 Lean, L1 and L2 begun (merged acf5c78a; checked on the merged tree)** [PROVED; MEASURED for the L1 check].
  - The integer model is written in executable Lean.
  - The constraint families requantization (with the residuals), RMSNorm and softmax hold exactly when the integer
    model's computation does, at W16R2. They are proved one position at a time, given their inputs.
  - Goldilocks is proved prime, so the earlier L3/L4 lemmas now apply to the code's own field.
  - L1 check against the Rust witness: 101,956 checks, 0 failed. The axioms are `propext`, `Classical.choice` and
    `Quot.sound` only, and the full Lean build is green with no warnings.
  - **Not yet proved:** the block-level `CircuitIff` and `ProductionReady`.
  - **Victor's idea worked: the proofs found slack.** Candidates C1, C2, C3 and C5 together save about 11.7% of
    committed rows and 3.7 M lookups per 8B block [ESTIMATE]. None changes the discretized model, but each is a
    protocol change. C4 would widen a word class (`ZK60_LEAN_L1L2_FINDINGS_20261106.md`).
  - **Waiting on Victor:** whether these join W16R3. Recommended: C1, C2, C3, C5 and C7 in, so there is one re-proof;
    C4 declined, like B4.
- **From 2026-11-05 the Mac's GPU is shared** with a frugal-lm research agent (Victor). Timing runs wait for it to be
  idle, and clocks taken beside it are not used (`ZK60_RESOURCE_PROTOCOL.md`, last section).
- **W16R3 is worth less than first modeled** (Sol's B1–B3 note, reviewed and accepted, 2026-11-05):
  - the forks phase ×1.08–1.19 [MODEL], against ×1.44–1.64 on 2026-11-01. The old figure counted the rate change that
    W16R2 already made, and the batching saves less than assumed.
  - about 2–8% off one request, and the receipt 819 → about 767 MB [MODEL].
  - The soundness rate improves slightly (2^-102.93 → 2^-103.02). B1 carries most of the saving, and B6 needs it.
- **D64's target is ≥ 110.** Next:
  - the prover core: the forks (3.6 s a request) now bound production's stream as they bound the harness's. W16R3,
    the Lean-found row savings (C1–C5, a ruling owed) and the RTX 5090 are the levers;
  - the forks' remaining host work (zero-fill, store fold, helper inverses, public weight folds, randomness), since the
    forks now bound the stream;
  - the protocol bundle W16R3, ruled 2026-11-05 (D67): B1 + B2 + B3, no B4. Sol builds B1 first, then B2 and B3, each
    after a measured gain (`W16R3_HANDOFF_20261105.md`). B6 goes to the next profile;
    - **Sol's progress, 2026-11-06** [MEASURED, Sol's candidate sources, not merged; the public synthetic fixture,
      proof only, N = 6 quiet pairs in both orders; every receipt verified; no stream, privacy or production claim;
      `results/zk60_sol_20261105_w16r3/`]:
      - B1 passed its stage gates: proof wall −5.0% (4.103 → 3.895 s; 6 of 6 pairs favour B1), and the A/H rows take
        9.5 ms less per block.
      - B2 passed its stage gates: proof wall −0.84% more (4 of 6 pairs favour B2), and the receipt shrinks from
        818.7 to 792.8 MB.
      - B3: the lifted sumcheck's arithmetic matches the expanded reference exactly in native code. The real block,
        PCS and lookup integration is next. After that come the bundle's freeze, its full gates and one Lean / privacy
        cycle.
    - Sol is building to D67's scope. C1–C7 join W16R3 only if Victor says so before the freeze. Otherwise they go to
      the next profile;
  - the RTX 5090: the bring-up guide and scripts are ready (`ZK60_RTX5090_BRINGUP.md`: Ubuntu 24.04 LTS, the open
    NVIDIA driver, CUDA 12.9, every project tool). After it, the CUDA backend must catch up with the Metal-era device
    work under the same byte gates.

**2026-11-04 (night): Lean, Fiat–Shamir part 6 merged; the soundness target needs one more theorem (F20, Medium).**
- Proved: the wide-digest lemma, LogUp and one commitment opening under Fiat–Shamir (with the extractor), and the
  code's challenge derivations. 83 theorems, no `sorry`, standard axioms only.
- **F20.** Combining the separately proved pieces by a union bound gives 2^-97.79 per hash query for a 32-block run.
  That is 2.21 bits short of the approved 2^-100.
  - **Later that night, the one-chain composition was proved:** the rate is the maximum over rounds, 2^-102.92 per
    hash query for a block and for a 32-block D12a run (Part 7 of the L3 findings).
  - This assumes M's opening at ≤ 2^-106 per round (its proof waits on F12), and the hand-off premises (proved for
    the zero-check, premises elsewhere).
- **Two new Medium findings (Victor's decisions):**
  - **F25:** the approved target's query-free part (2^-100) is not met, because the protocol's own interactive
    soundness is about 2^-97.8.
  - **F26:** a D55 fork run is a tree of transcripts. Only a union over its 32 forks is proved (2^-97.93); a tree
    version of the chain theorem is needed.
    - **The tree version was proved the same night:** D55's per-query rate is 2^-102.92 for any number of forks,
      the same as a D12a run, given its hand-off premises and the M assumption (Part 8 of the L3 findings).
  - **Victor's rulings (D65, D66):**
    - F12 is fixed, under new profile versions (see the top).
    - One constant external refusal: done.
    - The DD dictionary's refusal is challenge-only: done, no receipt byte moved.
    - **F25 closed by the path-wise proof (2026-11-05, Part 9), for a D12a run:** a D12a run meets the approved
      target q·2^-100 + 2^-100 for every q ≤ 2^75. The query-free part is ≤ 2^-101.85 and the per-query rate is
      2^-102.92. This holds given the hand-off premises and M (both still to prove). The wider-field fallback is not
      needed.
      - **For D55,** the per-query rate is Part 8's tree theorem. Its query-free part, Part 9's zones composed over the
        fork tree, is not yet proved (L3 findings, W5; noted by Sol, 2026-11-05).
- Fixed today: F16, a run receipt now attests its context. F23: `autoImplicit` is off in `formal/`, so a mistyped
  name in a statement can no longer compile silently.
- Fixed today: L4 finding 3. The mask schedule audit now checks that each pair's actual row weights are independent,
  which hiding needs; before, it checked only that the coefficients were nonzero. It caught a leaking test fixture.
  The full suite is 904 / 3 known / 93.
- **Speed correction (H124c):** with the serial forward chain on the clock, one request on the Mac is measured at
  8.2 tok/s, not the 15.3 inferred earlier today (details below).
  - The builder's single-threaded remainder was then parallelized, byte-identically (goldens and the six pinned
    digests unchanged). The witness per block went from 0.249 to 0.167 s.
  - **One request end to end is now 12.54 s = 10.2 tok/s** [MEASURED].
  - **With the sealing pass's witnesses kept, one request from its input is 11.50 s = 11.1 tok/s** [MEASURED, all
    witness work on the clock, the receipt verified]: the serial chain 5.9 s, then the fork run.
  - **A stream of 4 requests** (the next one sealed while this one proves; D64 allows batching): 13.8 tok/s
    amortized, **15.9 tok/s steady state**, 13 to 15 s latency per request [MEASURED, all 4 receipts verified]. The
    two stages share the Mac's CPU. D64's target is ≥ 110.

**2026-11-04 (late night): F12 FIXED (D65(1)).** M now combines its claims with powers of θ starting at θ¹, for
the prover and the verifier alike. Every profile that uses M has a new version string (`/1` → `/2`), and the old ones
are refused by name. The forgery below is now rejected. Every moved golden and digest is accounted for in
`results/zk60_f12_fix_20261104/REPIN.md`. The D55 privacy-gate records and all `/1` captures are invalidated and must
be redone before any real-content switch. That switch was closed anyway: it waits on GPU-made bundles and on D63.

**2026-11-04 (evening): a soundness defect found by the Lean work, confirmed in Rust (F12, High).**
- The mask commitment M certifies its first claimed value only up to an offset the prover picks when it commits:
  the sum of its blinding polynomial, which nothing verifies.
- The forgery is reproduced against `mask_verify` (`hashline/src/zk_f12_tests.rs`).
- In the token-I/O OUT stages (next-token and classifier verdict), this would let a receipt from a shifted final
  hidden state verify. That end-to-end case is not yet reproduced.
- **Until fixed, no soundness claim is made for token-I/O or classifier receipts.** Nothing is in production.
- The fix (θ powers starting at θ¹) is proved correct in Lean. It changes every receipt's bytes, so it needs new
  profile versions (`docs/zkmatrix-poc/ZK60_LEAN_L3_FINDINGS_20261104.md`).

**2026-11-04: the D55 privacy gate is complete, the repository is public, and production now needs Lean proofs.**
- **Gate:** the merged 18-part gate ran on all 12 registered R13 D55 bundles: 12/12 D55-PASS, re-scored with the fixed
  rules (18/18 parts, pins 75/75), the only open item being the accepted G_k residual. Also: the fixed tools'
  suite (203 tests, the known r19b failure only), a rung re-gate (2/2), and FR25-17 (all 23 slots on 8B, Shieldstral
  T256 and TinyLlama). Not yet a privacy acceptance: the CLI still refuses D55 real-content runs. Victor ruled (D60, 2026-11-04) to
  "build it proper" for GPUs. The switch waits until GPU-made bundles pass the gate too (the Metal device code read,
  the backend recorded by the prover itself), and production waits for D63.
- **Anthropic's FlashProve** (Apache-2.0, `github.com/anthropics/FlashProve`) is a strong, complementary result:
  - It proves Llama 4 Maverick (400B MoE, about 17B active) at about 110 tok/s of batched prefill (24 requests) on
    one H100.
  - Its zero knowledge hides the WEIGHTS; prompt and reply are public. It has Lean proofs of soundness,
    completeness and zero knowledge.
  - Ours (P1) hides the user's inputs, outputs and activations, with weights public. Our measured figures: 22.9
    tok/s proof-only on one request, about 9 counting witness building (Mac, 8B dense, no batching).
- **Production rule (D63):** before production, every ZKP needs two Lean theorems. (1) The proof is accepted exactly
  when the output is the discretized model's output. (2) The receipts reveal nothing useful about the hidden data.
  The statements: `ZK60_LEAN_PRODUCTION_STATEMENTS.md` (approved by Victor, 2026-11-04). The latency work continues
  in parallel.
- **The witness (H124): measured, then made about 2.8× faster, byte-identically** (`results/zk60_h124_witness_20261104/`):
  - The weight products were 95% of the witness CPU time and memory-bound: every token re-read the whole weight
    matrix. Tiling them by output columns and summing i16 inputs exactly in i32 blocks cut one 8B block's products
    from 0.361 to 0.085 s, and its witness from 0.438 to 0.249 s (5.94 to 1.38 CPU s).
  - Goldens and all six pinned trained digests are unchanged.
  - ~~One request on the target's clock (proof + witness) is now about 15.3 tok/s~~ **Corrected the same night
    (H124c):** that figure built the 32 witnesses in parallel from block inputs a real request does not know yet. The
    forward chain is serial, and it was outside every clock so far. **Measured with it on the clock, one request is
    15.57 s = 8.2 tok/s** (sealing pass 8.22 s, then forks with every witness built just in time 7.35 s). Keeping
    the sealing pass's witnesses would give about 13.9 s = 9.2 tok/s [INFERRED]. The critical path is the serial
    chain, 0.257 s per block (`results/zk60_h124_witness_20261104/README.md`, H124c).
  - Proof-only is 22.7 to 24.25 tok/s at Q = 280.
  - Next: the builder's poorly parallel remainder (it shortens the serial chain), a fork-run source that keeps the
    sealing pass's witnesses, a multi-request pipelined measurement, then GPU products.
  - The new target is ≥ 110 (D64).
- **The repository is public, and all work is open source (D62)**, under Apache-2.0 (`LICENSE`, `NOTICE`,
  `SECURITY.md`). The Lean statements (D63) were approved by Victor on 2026-11-04.

**2026-11-03: correction — every proved-tokens/s figure since the Mac bring-up is proof-only; witness building was outside the clock.**
- **What was missed:** the D55 A/B harness (`run_fork_tests.rs`, `d55_ab_one_request_serial_against_forks`) builds every block's
  witness before it starts each clock. Our own target (`ZK60_THROUGHPUT_TARGET.md`) counts witness work.
- **Size** [INFERRED from measured walls, W16R2 8B T128, `results/zk60_w16r2_20261101/logs/ab/m_d55_r2b.log`]: total 110.9 s, minus
  setup 15.1 s, five timed calls 45.6 s and two verifications 7.0 s, leaves 43.2 s: about **8.6 s of witness building per request** (32
  blocks, 8 builder threads), against 5.6 s of proving. Counting it, one request on the Mac is about **9 tokens/s, not 22.9**.
  All earlier rows of the speed table (7.6 / 12.0 / 20.8 / 22.9) are on the same proof-only clock.
- **What it means for 50:** the researcher's 5090 model (`research/zkp-efficiency/handoffs/20261103-rtx5090-projection.md`) gives
  54–82 proof-only [MODEL], but 6–11 counting today's witness code, and 48–76 with an exact SIMD/GPU forward pass (H124, byte-identical,
  no ruling). The witness is now the first lever, ahead of the GPU kernels. A direct clock of `witness::build_accuracy` comes first.

**2026-11-02: the rate-1/2 commitment (D59) is built as an opt-in profile and about 10% faster, with no soundness given up.**
- **What it is:** the W16R2 profiles encode A, H, the run boundaries and the endpoints at code rate 1/2 (was 1/4) with 260 opened columns,
  counted at the Reed–Solomon unique-decoding radius. The mask commitment M is unchanged.
- **Speed** [MEASURED, 8B T128, synthetic weights, one binary, warm]: prove core 0.373 → 0.336 s per block; one request with D55 at six forks
  goes from 20.8 to 22.9 proved tokens/s; receipts grow 0.6%.
- **Soundness** [COUNTED, builder's recount]: 2^-105.93 per opening (was 2^-105.61); 8B whole run 2^-97.36 (was 2^-97.27).
- **Correctness:** all D59 malicious controls are rejected; existing bytes and goldens are unchanged; full suite 872/6/84 (the known Mac-only six).
- **Due diligence, all done the same day:** the recount was independently re-checked (every figure reproduces); the independent code
  review found no soundness defect, and its findings F1, F3–F5 and F7 are closed (including a built close-case attack that is rejected
  at exactly the counted rate); the privacy re-check found no leak.
- **Open:** Victor's ruling on Q (260 counts the proven bound; 280 also matches today's design against the best known attack, for
  about +3.5% receipt bytes), and the token and classifier bit counters must learn the new count before registration.
- **D55 is now registered (D60)** over the 12 R13 block-run profiles, with test receipts verified in a fresh process. On R13 8B T128 it
  measures 7.59 → 11.95 proved tokens/s at six forks. Its independent review found no soundness defect or leak, and its findings are
  closed. Every source file that moved since the privacy gate last read it has now been read and found safe, including an
  independent check of the three readings the wiring agent did itself (one latent issue, W-1, goes to the freeze review).
  CPU-made bundles only; GPU-made bundles are refused until the Metal code is fully read.
  The older gate items for R13 are now ported to D55. Each check passes on every bundle it has run on: all 12 registered bundles
  (now including TinyLlama and Shieldstral T128/T256) for the hash and claim checks, and the four R13 bundles for NL-1 and the
  full preimage. The hash census found one gap in the Rust table (it had never measured runs of 2 to 9 blocks), now fixed in test
  code. **Correction:** the earlier records were PASS only for the checks run at the time. Each still listed privacy checks not
  yet run on it, so none of them is a privacy PASS record. Only the gate with every check combined can give one. It is now
  running on all 12 bundles, and its first record is a full PASS.
  The separate review of the gate before its freeze is done: freeze after named fixes. It found no leak in any recorded bundle, but
  the status could reach PASS with a check skipped or a pin list cut short. Those fixes are made and are being re-checked.
  The CLI still refuses D55 real-content runs. Lifting that needs the combined records, the fixed gate frozen, and Victor's go-ahead.
- **The Mac's ceiling is about 23 tokens/s per request.** 50 still needs the RTX 5090.

**2026-11-01 (night): one request now proves at about 21 proved tokens/s with the D55 prototype (opt-in, unreviewed).**
- **What changed:** Victor approved D55. Its "commit, fork, join" profile lets one request's 32 blocks prove concurrently.
- **Speed** [MEASURED, W16 8B T128, synthetic weights, one process, best of 3]: one request goes from 10.57 tokens/s (serial) to 20.85 at
  six forks (1.97×), and verification takes about 2.5 s against 4.8 s.
- **Correctness:** the four malicious controls are rejected, and existing proof bytes and goldens are unchanged.
- **Before any receipt uses it:** an independent review and a privacy re-check (`results/zk60_d55_20261101/SOUNDNESS_NOTE.md`).
- **Housekeeping found by the D55 agent:** four source-scan tests (r19b, the s24 pin list, the s25 module graph, the absorb-label scan) fail on files added by
  the Metal and W16 work. Those files need adding to the scans' lists.
- **Also today:** the W16 privacy gate passes on the Metal path and in a Python v25 subset (no leak found).
- **Still the gap to 50:** the RTX 5090 CUDA port.

**2026-11-01 (evening): the Shieldstral classifier privacy statement is accepted (D58).** Victor accepted v3 with the checker's two text fixes. It is in force for the named CPU binaries at the moderate policy list; conditions C-7 and C-8 still stand before non-public posts, and GPU proving is not yet covered. W16's F3 malicious controls are closed. A funding push is under way (D57; the application material is kept outside the public repository since 2026-11-04).

**2026-11-01 (Mac, latest): one request now proves at about 11 proved tokens/s (13 at 256 tokens per block), and about
22 with six requests at once.**
- **Measured** on the committed code [MEASURED, W16 8B blocks, every proof byte-identical to a solo proof, synthetic
  diagonal weights]:
  - T128: 0.356 s per block, **11.1 tokens/s** for a 32-layer stack; 22.3 tokens/s aggregate with six requests at
    once;
  - T256: 0.597 s per block, **13.2 tokens/s**; 20.8 tokens/s aggregate.
- **The rest of the gap to 50** (Attestable: 53 on one H100):
  - the Mac's GPU caps the aggregate near 22 tokens/s;
  - one request's own blocks cannot overlap without Victor's ruling D55;
  - the biggest remaining step is the RTX 5090 with all of this work ported to CUDA.
- **New research result (M18, D56 open question):** a 31-bit field (Mersenne-31 or BabyBear) multiplies 3.5–3.9x
  faster than today's on this GPU, and its secure extension 1.8x faster [MEASURED]. A cost study the same day found
  that the bit-exact arithmetic needs Goldilocks' 64-bit headroom: 15 relations exceed a 31-bit field (up to 2^49.8),
  and carrying them as digits makes a block slower overall (about 0.24–0.34 s of GPU work against 0.165 s) [MODEL].
  Recommendation: **not now** (`results/zk60_metal_20261031/D56_FIELD_SWITCH_STUDY.md`).
- **W16 independent soundness review done (2026-11-01):**
  - **Verdict:** sound as built, about 0.9 bit better than R13 per block (LogUp 2^-102.92).
  - **Fixed:** the Medium finding F1 (two receipt guards missed the W16 profile names) and Lows F2 and F4. All
    gates pass.
  - **Still owed before any W16 receipt:**
    - ~~the malicious-prover controls F3~~: **done 2026-11-01** (four test-only controls, each refused by the verifier; every gate green, golden 8/8; `results/zk60_metal_20261031/logs/m22f3/`);
    - the privacy gate run on W16: **the Rust gate is done (2026-11-01).** The plane index and recorder now cover W16's
      range histograms and helpers, and they PASS at the rung and both T128 shapes with no leak found
      (`results/zk60_metal_20261031/logs/m23pg/`). Still owed: the Python gate (v24) for W16, a W16 statement text, a
      GPU-path capture and an independent privacy review;
    - registration;
    - the DD variants.
  - Report: `results/zk60_limb16_20261031/REVIEW_W16_20261101.md`.
- **D55 design draft:** `docs/zkmatrix-poc/ZK60_D55_CONCURRENT_RUN_DESIGN.md` (one request's blocks proved at once).
- **Tried this round and reverted (no gain, diffs kept):** Gruen's trick on the GPU zero-checks, and a host pool for
  the commitment matrices. Details: `results/zk60_metal_20261031/README.md` M6–M16.

**2026-11-01 (early morning, Mac): each step's GPU rounds now go to the GPU as one batch (about 7% faster), and
measured context scaling shows that longer contexts buy little.**
- **M6 (byte-identical, kept).**
  - **Before:** every sumcheck round was its own GPU submission, costing about 0.21 ms of fixed overhead.
  - **Now:** all of a step's GPU rounds go in one submission. The Fiat-Shamir hashing and masking run on the GPU, and
    the CPU then replays every round to check each challenge, so a GPU fault cannot change a proof byte.
  - **Speed** [MEASURED, A/B on one binary, warm n=3, shared Mac, prove core]:
    - W16 8B 0.468–0.476 → **0.435–0.441 s**;
    - W16 Shieldstral 0.476–0.519 → 0.446–0.484 s;
    - on a quieter pass the W16 8B core was 0.400–0.403 s, about **10 proved tokens/s** for a 32-layer 8B stack
      (block proofs only).
  - **Gates:** all pass (dev-shape bytes, trained digests, R13 run, golden 8/8).
- **M7 (measurement).** W16 8B blocks at longer contexts [MEASURED, warm n=2]:
  - **T256:** 0.78 s, **10.3 tokens/s**, the best of the three;
  - **T512:** 1.7–2.0 s, 7.8–9.4 tokens/s.

  Cost grows almost linearly with context, so a longer workload is not the route to 50. The remaining factor of
  about 5 must come from per-token work. The largest piece is now the CPU side of the 23 zero-check steps (about
  0.125 s of 0.40 s: building their tables), then the two commitments (about 0.15 s).
- **M8 (byte-identical, kept).**
  - **Small slots on the GPU.** A small zero-check step with an expensive polynomial now runs on the GPU: 8 → 2 ms.
  - **Faster weight fold.** The feed-forward weight fold adds exact integers and reduces once per row: 10 → 3.5 ms
    per 8B matrix, on dense weights.
- **M9 (byte-identical, kept):** two CPU steps on the critical path fixed (the Merkle tree builder was split into
  per-pair tasks, and one table builder ran on a single thread). W16 8B block 0.408–0.422 → **0.373–0.375 s**
  [MEASURED, A/B on one binary, warm n=3, oracle off], about **10.7 proved tokens/s** for a 32-layer 8B stack
  (about 10.3 with real dense weights).
- **M10 (measured): independent proofs at once.**
  - **Result:** 6 block proofs at once give **5.5 blocks/s, about 22 proved tokens/s aggregate** for a 32-layer 8B
    stack, against 10.6 for one at a time [MEASURED, one process, all proofs byte-identical to the solo one].
  - **What it means:** this is throughput over separate requests or stacks; one request's own blocks share a
    transcript and still run one after another (changing that would need Victor's ruling).
  - **Bottleneck:** it saturates at the GPU's own work per block (about 0.165 s), so faster GPU kernels are now what
    raises throughput.
- **M11 (byte-identical, kept):** the opening's row fold reduces once per entry: −5 ms per block. A faster field
  multiply on the GPU was tried; there is no gain (the compiler already does it well). The big GPU kernels are near
  the multiply ceiling, so what is left on the GPU is algebra: fewer evaluation points (Gruen's trick) and a leaner
  NTT.
- **M12 (kept, small):** the GPU transform reads its twiddles from a compact table, −1 ms per commitment.
- **M13 (tried, reverted):** Gruen's trick on the GPU zero-checks was byte-identical but not faster (the GPU cost per
  point is memory and latency as much as arithmetic); the diff is kept.
- **M14 (measured):** at 256 tokens per block, one request now proves at **13.0 tokens/s** for a 32-layer 8B
  stack (0.60 s per block). Six requests at once give 21 tokens/s aggregate.
- **M15 (byte-identical, kept):** two CPU steps of the activation lookup are fused or made parallel; W16 8B T128
  block **0.358 s** (about 11.2 tokens/s), from 0.380.
- **Open question for Victor (D55):** letting one request's blocks prove at the same time would need a new
  construction, because rule D12a makes a run one transcript.
- **Caveat on all block timings above.** The timing test's synthetic weights are diagonal, so weight folds are
  nearly free in it. A real 8B layer adds about 15 ms per block (about 35 ms before M8) [ESTIMATE]. So the real-weight
  8B figure is about 9–9.5 tokens/s at T128 and about 10 at T256, not 10 and 10.3.
- Record: `results/zk60_metal_20261031/README.md` (M6, M7, M8).

**2026-11-01 (night, Mac): two more byte-identical speedups to the W16 format; an 8B-shaped block now proves in about 0.43 s on the GPU.**
- **M5b** builds the activation lookup's queries in parallel.
- **M5c** builds each large eq table from two small half-tables, one multiplication per entry, instead of a full
  table plus a copy.
- **M5a** (gathering plane tables on the GPU) was byte-identical but gave no gain in a side-by-side comparison on
  one binary, so it was reverted and its diff kept.
- **Gates:** every existing format's bytes are unchanged at each step (golden 8/8, trained digests, R13 run).
- **Speed** [MEASURED, Metal prove core, T128, warm passes n=3, shared Mac]:
  - W16 Shieldstral 0.452-0.469 s;
  - W16 8B 0.432-0.435 s, about 9.2 proved tokens per second for a 32-layer 8B stack (proof call only), still
    about 5.4 times short of 50.
- **Researcher (D50).** A Claude researcher ran on the Mac, because the Codex explorer needs bubblewrap. It
  measured LogUp-GKR against W16's helpers: marginal, about x1.00-1.25 (estimate), so not recommended
  (`research/zkp-efficiency/handoffs/20261101-logup-gkr-w16.md`). Its top idea is overlapping the about 0.2 s of
  host-CPU work with GPU work.
- **Timing noise.** Spotlight re-indexing new build output slowed one run's CPU path about 2x. Excluding the repo
  from Spotlight would help.

**2026-10-31 (late evening, Mac): 16-bit range lookups (W16, D54) built and measured: a block now takes about 0.47 s on the GPU.**
- **What changed.** Victor approved wider range-check limbs (D54).
  - A new, opt-in proof format replaces most byte limbs with 16-bit range lookups.
  - Its profiles: `W16_SHIELD_T128_H24`, `W16_8B_T128_H24`, and a development rung.
  - Each block commits about half the words: `A` is 0.55 of R13, `H` 0.59, lookups 0.50.
  - The existing proof formats are unchanged byte for byte (the development-shape digests, the trained R13
    digests, the R13 run and golden 8/8 all pass).
  - Design and evidence: `results/zk60_limb16_20261031/DESIGN.md`.
- **Speed** [MEASURED, Metal prove core, T128, warm passes n=3, shared Mac; synthetic weights at the true geometry;
  the proof call alone]:

  | Block | R13 (today's format) | W16 |
  |---|---:|---:|
  | Shieldstral | 0.654–0.667 s | **0.469–0.507 s** (×1.39) |
  | Llama-3-8B | 0.605–0.631 s | **0.467–0.482 s** (×1.30) |

  For a 32-layer 8B stack that is about 15 s per 128 tokens, about **8.4 proved tokens per second** (was about 6.5),
  still about 6 times short of 50. For the 26-layer classifier it is about 10 tokens per second.
- **Before any receipt uses it:**
  - a run profile and receipt registration;
  - the DD variants;
  - an independent soundness review;
  - the privacy statements re-checked for the new plane list.

  Tests already show the W16 core proves and verifies, and that out-of-range limbs from a cheating prover are
  rejected.
- **Next levers:**
  - LogUp-GKR, which drops the committed helper column (needs Victor's ruling);
  - non-power-of-two domains: Shieldstral's feed-forward axis is 44% padding;
  - the RTX 5090.
- **Lanes.** Sol and Astra are paused for their weekly limits (handoffs in their result directories). Their detached
  runs continue: Astra's A2 replay, analysis, score-fix candidate and calibration replay.

**2026-10-31 (evening, Mac): the real classifier's zero-checks now run on the Mac's GPU too, byte for byte the same.**
- **What changed.** The classifier (Shieldstral) uses the R13 accuracy stack. Its five heavy zero-checks had
  stayed on the CPU, because the GPU's expression description covered only the older stack. They now run on the
  GPU. The proof bytes are identical to the CPU's at every shape tested: four small development shapes, and the
  Shieldstral and 8B geometries at 128 tokens. The older proofs are unchanged (golden gate 8 of 8).
  Record: `results/zk60_metal_20261031/README.md` (M4 to M4l).
- **Speed of one Shieldstral-shaped accuracy block at 128 tokens** [MEASURED, GPU rows n=9 warm passes in three
  processes (median), Mac quiet at the time; synthetic weights at the true geometry; the proof call alone, so no
  witness, model loading or receipt assembly]:

  | Path | Block proof |
  |---|---:|
  | Mac CPU, 32 threads (n=4, not a quiesced ladder) | 2.9-4.5 s |
  | Mac GPU, later blocks (a new GPU kernel's first compile on a machine can add a few seconds, once) | **0.65-0.68 s (median 0.656)** |

  Fixes that change no bytes took the GPU block from 2.86 s to about 0.66 s (the older figures in the record
  also counted the test's own digest text, about 0.16 s): on the CPU side (used by both paths) the extension
  rounds, the LogUp helper columns, the commitment masks' randomness, the exp/activation helper inverses and the
  witness planes now run in parallel; on the GPU, the zero-check kernels run one thread per evaluation point,
  one point per group of 32 lanes, skipping the point the protocol recovers from the claim; the zero-check
  tables are built straight into GPU memory instead of being built, zeroed and copied, and in parallel over
  their entries; the last, tiny sumcheck rounds of each slot run on the CPU (a GPU round costs about 0.4 ms
  whatever its size); small helper tables no longer pay a thread-pool start-up each; GPU buffers are reused
  from block to block (about 2.4 GB more peak memory).
  For the 26 layers at 128 tokens that is about 17 s of proof core, or about **7.5 proved tokens per second**.
  The target is at least 50, so we are still about **6.7 times short**.
- **Longer blocks do not close the gap here** [MEASURED, n=3]: the same block at 256 tokens takes 1.59 s, 2.1
  times the 128-token block (measured before the last three fixes), so proof time is about linear in tokens on
  this design. Closing the gap needs the structural levers or a faster GPU, not more tuning of phases.
- **A lever that needs Victor's ruling:** most of what each block commits is range-check byte limbs and their
  lookup helpers (the lookups read 64.3 M of the 75.0 M words of `A`; their helpers are 64.3 M of the 71.9 M of
  `H`). Wider limbs (16-bit) would shrink both commitments and openings roughly in proportion, a rough
  estimate of 0.1-0.2 s per block. It changes the proof layout, verifier and receipts, so it is not done.
- **Still on the CPU:** the witness, the LogUp helper inverses (in parallel), the extension rounds, the openings,
  and one small table slot per block. The DD softmax and dictionary slots also stay on the CPU.
- **Sol and Astra** (Codex sessions on this Mac) have written nothing since about 08:45 UTC. Their processes are
  alive but idle and need a "continue" from Victor. Astra's 12-hour replay was prepared but has not been launched.

**2026-10-31 (afternoon, Mac): the prover runs on the Mac's GPU, byte for byte the same; R14's security tier is accepted.**
- **Apple GPU (Metal), new.** The commitments and the five heavy zero-check sumchecks now run on the M3 Ultra's
  GPU. Four full block proofs made this way (TinyLlama and Llama-3-8B shapes at 128 tokens, with and without
  DD) are byte-identical to the proofs recorded on the Linux laptop. Record: `results/zk60_metal_20261031/README.md`.
- **Speed of one 8B-shaped block at 128 tokens** [MEASURED, n=1, shared Mac; synthetic weights at the true
  geometry]:

  | Machine and path | Block proof |
  |---|---:|
  | Laptop CPU, 16 threads (historical) | ~12.3 s |
  | Mac CPU, 32 threads | 4.66 s |
  | Mac GPU (commitments + zero-checks) | 2.20 s |

  That is about 1.8 proved positions per second for a 32-block 8B stack on the Mac, before witness and model
  loading. Attestable claims 53 tokens/s on one H100 for a 31B model; we are still far from that.
- **Not yet on the GPU:** the real classifier's accuracy-stack zero-checks (their expression IR is not written),
  the witness, the LogUp helper inverses and the extension rounds. The DD profiles keep one slot on the CPU.
- **R14 security tier (D27): accepted on soundness** by an independent review, three low fixes
  (`results/zk60_d24_review_20261017/REVIEW_R14_TIER.md`). Registration still needs one CLI run on the restored
  export and the privacy gate.
- **Astra restored the Shieldstral native export** on the Mac (8.47 GB, every file hash-matched) and is
  re-running the benchmark replay (about 12 h, CPU).

**2026-10-31 07:45 UTC: work moved to the M3 Ultra Mac Studio; the laptop is no longer reachable.**
- **The code is all here.** The last push (Snapshot 15) is pulled. The production prover builds on the Mac and
  passes its tests apart from three macOS bugs and some missing test files. Proofs made on the laptop verify on
  the Mac. Record: `ZK60_MAC_BRINGUP_20261031.md`.
- **What stayed on the laptop:** about 446 GiB of large files (model exports, captures, receipts) and everything
  kept outside the repo. That includes the private store of the durable demo post, so **its openings are not
  available from here**. Its anchor on Base Sepolia is unaffected. The app also kept the public segments
  outside the repo (`~/zk60-artifacts/proven-media`), so those are on the laptop too.
- **No GPU proving on the Mac yet.** The GPU code is NVIDIA-only; an Apple GPU (Metal) port is planned but not
  started (`ZK60_METAL_PORT_PLAN.md`). The safety guard for heavy jobs now runs on macOS.
- **Every number below was measured on the laptop.** None has been re-measured on the Mac.

**2026-10-30 21:55 UTC: a second real post, now with durable openings; the R14 prover passes its soundness review.**
- **Durable demo post** (Astra): 19 tokens, all three categories accepted as not flagged, 84 public segments
  (2.55 GB). Anchored on Base Sepolia, transaction `0x6e6d5166…8181`, block 52,373,745.
  - Its openings are kept in durable private storage, so the link between the proof and the post's text can be
    checked from an opening (D45). The first post's openings were lost in the crash.
  - Proving per category: 444–452 s on 8 threads, peak 8.2 GiB [MEASURED, n=1, shared laptop].
- **Native prover R14 is accepted on soundness** (independent review): about 97.3 bits.
  - It proves all 26 real Shieldstral layers in about 440 s at 5.6 GiB peak (the current app binary needs
    8.2 GiB).
  - It is not yet registered: that waits on a security tier in the statement, one T256 proof and the privacy gate.
- **Nothing is published until proving and verification run on the GPU** (D53). The GPU lane is profiling.
  - The laptop GPU now runs at full clocks after Victor's power-mode change (about 2.0 GHz, memory 8,000 MHz).
  - Every GPU figure measured before today was taken with the GPU capped.

**2026-10-30 11:35 UTC: work interrupted by the crash is caught up.**
- **The one-load batch (token round 18)** is frozen and passed its independent review, with one fix required on
  the app side (R18-1). One process now proves all the categories of a post after loading the model once. Each
  category's proof comes out byte for byte the same as a separate run [MEASURED: the public 17-token post, three
  categories]. It saves little time (2.4 %); the gain is a single model load. The app stays on the per-category
  path until Astra's fix for crashed batches is in and reviewed.
- **The classifier privacy statement, draft v3,** is complete. Both checks the review asked for passed on the
  real model:
  - C-9 on a real block: TS-1 fires on every role, with no identical claims and no equal published values.
  - NL-1 on all 26 blocks: 182 of 182.
  A short check that v3 contains the review's text fixes is running. After that, Victor decides whether to
  accept the statement. It is not accepted yet.
- **Token round 19** is running: the review's three small fixes, plus a setting for the model's location, so
  that anyone can verify a receipt (needed for the open-source release, D48).
- **Sol (R14)** is close to a freeze; its independent soundness review follows.

**2026-10-30 05:30 UTC: the laptop crashed at about 02:50 UTC and work has resumed; safeguards added (D46).**
- **Why it crashed:** the Windows drive C: was full (about 5 GB free). It holds the
  Linux disk file and Windows' page file, so neither could grow while a
  full-size test proof was writing. Linux itself still had 5 GiB of memory free.
- **Fixed:** about 135 GB of unused Windows AI tools removed, with Victor's yes, so
  C: now has about 135 GB free. The resource guard now holds heavy jobs while C: has
  under 40 GiB free, and stops any job under 8 GiB. The box watch now reports
  low C: space and low Windows memory. When Windows runs short of memory it
  releases Linux's cached copies of large files; the first run released 5.5 GiB
  and the Linux VM's share of Windows memory fell from 14.9 to 10.5 GiB. Still
  for Victor: the 5-minute cron entry for the watch, which the session's safety
  check blocked, and the Linux disk compaction (about 45 GB) at a quiet moment.
- **Lost in the crash:** token round 18's full-size byte-identity test, which is
  being rerun; the gate's C-9 and NL-1 checks, also rerunning. The first post's
  proofs and public segments survived and still verify, but the app had kept
  its database, key and openings in /tmp, so the openings that link the proofs
  to the post's text are gone. Astra moved the app's state to durable storage
  (05:23 UTC).
- **The first real post is now published and anchored on testnet** (05:23 UTC,
  Astra): Base Sepolia transaction `0x0f2dc9dd…ad01a`, block 52,075,726. All three
  publication checks pass. All 84 public segments (2.55 GB) were re-hashed, and the
  three receipts verified again from the public store, in 79–82 s each
  [MEASURED, n=1, the box shared]. The proofs were not redone. Still open: the
  classifier privacy acceptance (draft v3, after gate round 23), the benchmark
  verdict metrics and the one-load batch adoption (token round 18).
- **Unchanged:** the results below, including the first real post's three
  accepted proofs.

**2026-10-30 01:54 UTC: the first real post went through the app, and all three classifier
proofs passed.**
- **The post:** a public 17-token garden text (Astra's demo), proved on the
  real Shieldstral-1.0-3B classifier with the pinned r16b binary (dfb8025e).
- **Verdicts:** sexual, violence and hate all *not flagged*. Each receipt was
  verified in a fresh process, and its input-owner and label checks passed
  [MEASURED].
- **Numbers** [MEASURED, n=1, this laptop, alone]:
  - proving time per category: 456 s with 8 threads (violence, hate); 1,031 s
    for the first (sexual), which used 2 threads;
  - total work per category with the checks: 688 s (8 threads);
  - receipt 848 MB; peak memory 8.0 to 8.2 GiB; 96-bit floor.
- **Not yet:** the publication and testnet anchor (Astra's next step); the
  privacy statement (draft under review; gate round 22 is closing the
  review's two blocking checks); private posts through the app (blocked until
  the app shows failures only to the authenticated author; Astra's fix is
  staged).

**2026-10-29 22:50 UTC: the classifier privacy statement exists as a draft and
is under independent review.**
- **The draft** (then `…_DRAFT.md`, now kept as `ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v1.md`; current: `_DRAFT_v3.md`)
  says what is public (the verdict bit, the post's length, the policy), what
  stays hidden (the post's tokens and every intermediate value), and how a
  refusal ("could not be verified") is reported.
- **The tables check:** the gate re-derived all 442 public tables of the real
  model itself (118 million entries), and every one matched the proof's
  [MEASURED].
- **Per-run distance:** about 2^-68 [COUNTED]. This bounds how far a real
  proof's view can be from one that reveals nothing. The TinyLlama statement
  had about 2^-70.
- **Next:**
  1. The independent privacy review (running).
  2. Gate round 22: three remaining checks (a draw replay by value, a
     surjection check, a hash-input census).
  3. Victor's acceptance and his strict / moderate wording.
- **The one-load batch** (all three categories after loading the model once)
  passed its code review with two fixes. Token round 18 is now adopting it,
  with a byte-for-byte equality test.
- **Correction to the 21:37 note:** Astra's first real post has not started
  yet. The Sol and Astra sessions are idle and wait for Victor's "continue".

**2026-10-29 21:37 UTC — the real classifier proof passed the full privacy
gate with no limits; the privacy statement draft has started.**
- **Gate round 20** closed both of round 19's limits on a real Shieldstral
  proof:
  - all 23 checks per block on all 26 real blocks;
  - the complete input-reconstruction check: **81.7 million entries compared,
    0 differing**;
  - nothing disclosed on hidden data, and every tamper check fires.

  4.06 h on this laptop, alone, with one read of the model.
- **Next:**
  1. The classifier privacy statement **draft** (running): what is public,
     what stays hidden, the per-run distance figure, and the refusal channel
     stated plainly. An independent derivation of the 15 tables the gate
     takes from the capture runs alongside it.
  2. An independent privacy review.
  3. Victor's acceptance, and his strict / moderate wording ruling.
- **The first real post through the app** (Astra) runs now that the box is
  free.

**2026-10-29 15:13 UTC — the privacy gate passed the real Shieldstral
classifier proof (with two stated limits); work continues to close them.**
- **The gate checks** that a proof reveals nothing about the hidden post
  beyond the public verdict and length. On the real classifier proof:
  - nothing is disclosed on any of the 84 hidden-data commitments;
  - all 15 tamper checks fire;
  - the yes / no / tie verdicts look identical apart from the verdict bit.

  13 small-model captures also pass.
- **Two limits to close** before a privacy statement:
  1. 12 of 23 per-block checks need the capture to record its public tables
     (token round 17, running);
  2. the full input reconstruction was checked on a sample of commitments.
     The complete check is a 3-hour job (gate round 20).
- **One thing the statement must say plainly:** whether an honest post gets
  *refused* (shown as "could not be verified") can depend on its hidden
  content. That is a small side channel, inherent to fail-closed.
- **Also today:** the proof anchor contract is live on the Base Sepolia
  testnet.
- **Speed (Sol's split-width round, S4 / R14), 16:53 UTC:** on a matched
  2-block, 128-token comparison (same inputs and model identity), proving
  dropped **49.2 s → 35.1 s (−28.8%)** and peak memory **7.49 → 5.56 GiB
  (−25.8%)**, with receipts about 6% larger [MEASURED, n=1, shared box].
  This is not yet frozen or reviewed. Next: freeze, soundness review, then a
  privacy-gate round.

**2026-10-29 12:09 UTC — the proof anchor contract is live on a public
testnet; both Codex lanes need a restart.**
- **Base Sepolia (testnet) anchor contract deployed** by Astra. Contract
  `0x8432eba82b1a402f4da7680f6b8f9c9fae185cbe`, deployment transaction
  `0xfaa03b5a…` (status success; code confirmed on-chain by the coordinator,
  read-only). It was funded from the ETH Victor mined, bridged from Sepolia.
  No proof batch has been anchored yet; that comes once the app makes real
  proofs.
- **Sol stopped at 11:12 UTC on an OpenAI content filter** ("flagged for
  possible cybersecurity risk", `cyber_policy`). The ZK work's routine
  attack / forgery testing probably triggered it. **Astra's turn ended at
  06:44 UTC.** Both need a "continue" from Victor.
- Claude lanes: token round 16b frozen (the real classifier, exactly three
  policies); privacy gate round 19 on the real classifier is running.

**2026-10-29 08:47 UTC — the first real proof of a safety-classifier verdict
on a real post.** Mistral's Shieldstral-1.0-3B judged a 35-token ToxicChat
post under the moderate "sexual" policy. The proof shows the public verdict,
"not flagged", while the post's text stays hidden [MEASURED, n=1, this laptop,
nothing else running]:
- **prove:** 328 s (439 s including model load); receipt 848 MB in 28
  segments; soundness floor 96 bits; peak memory 8.15 GiB;
- **verify** in a fresh process: 36 s (68 s including model load), 2.3 GiB;
- the **owner check** (the proof matches the actual post) and the **label**
  step (whole post covered) both pass.

Category 1 of 3 has been through the app's whole flow. Violence and hate are
proving now. Not yet a privacy acceptance: the privacy gate on the real
classifier and the policy wording (strict vs moderate, Victor) come next.
**Update 09:31 UTC: all three categories passed the whole flow** (each
proof about 7.5 minutes, 848 MB). The round is frozen: 934 tests passed,
96.9 bits per whole run. Next:
- an independent review (running);
- the privacy gate on the real classifier;
- Astra making the app produce each post's activations from its own integer
  model.

Then the app switches from the stand-in to real proofs.

**2026-10-29 07:21 UTC — the accuracy round (R13) passed its soundness
review; the real Shieldstral classifier is being registered now.**
- **R13 accepted** at all twelve registered profiles. The reviewer's own
  integer model matches the prover exactly, including the real Shieldstral
  layers. Shieldstral proofs carry **97.3 bits at 128 tokens** and **96.1–96.3
  at 256**, over the ~95 floor.
- **Next (token round 16, running):** register the Shieldstral classifier on
  R13, then prove and verify real posts for all three categories on this
  laptop, with timings. After that comes the privacy gate on the real
  classifier, and then the app switches off its stand-in prover.
- **One open question for Victor (not urgent, not blocking the MVP):** the
  8B model at 512 tokens counts 94.5 bits (94.8 with DD), just under the ~95
  target. Sol is costing the cheapest way to reach 95.
- Astra: the full benchmark on the integer model continues (zero refusals so
  far). Sol: the split-width design (about 24% less proof data) is under an
  independent design check; then the verifier-commitment paper.

**2026-10-28 21:05 UTC — back after a two-day stop; the classifier proof
passes the privacy gate on all seven test captures; funding is now the top
priority (D43).**
- **The stop:** the coordinator session stopped answering on 10-26 at about
  20:26 UTC, and the laptop then shut down cleanly at 20:33 (a normal power-off,
  not a freeze). Nothing ran until today's boot at 20:56. Every job queued on
  10-26 had already finished; nothing was lost. Sol and Astra resumed at 20:59.
- **Privacy gate, round 17:** all 7 test proofs of the classifier verdict stage
  (1- and 2-block models; verdict yes, no and a tie; one item split into 2
  chunks) pass: no commitment reveals more than expected, all 11 tamper checks
  fire, and the yes / no / tie runs look identical apart from the public verdict
  bit [MEASURED, n=1, shared box]. These are small test models, and this is not
  a privacy acceptance.
- **Classifier verdict stage on the new prover (token lane):** rebased onto
  native R12 and the full suite is green (819 passed, 0 failed). **Update
  23:11 UTC:** Sol froze R12b at 22:33. It is the fix that makes the prover
  recompute the classifier's tables from the model's pinned weights instead
  of trusting the files. The independent review accepted it on soundness with
  no fixes: 27 forgery attempts were refused, and an independent
  recomputation matches bit for bit. The token lane is now rebasing onto R12b
  and building R-C2, in which the classifier's verifier derives its scoring
  row itself. Not a privacy acceptance. **Update 23:45 UTC:** token round 13
  (R-C2) is frozen on R12b. The classifier verifier now rebuilds its scoring
  row, embedding, start token and final normalization from the model's
  pinned weights and the bound profile. Doctored tables are refused even when
  their fingerprints were updated to match: 4 tests failed first against the
  old stage and pass now. Full suite 832 passed, 0 failed [MEASURED]. On
  Astra's real Shieldstral export, the rebuilt tables match the native
  reference exactly. An independent review is running, and the privacy gate
  re-captures afterwards. **Update 00:56 UTC: R-C2 is accepted on soundness**
  with no required fixes: 51 forgery attempts were refused, and the old stage's
  flipped-verdict gap is shown closed. Next, token round 14 (running):
  - bind the tables inside the library functions too, not only the
    command-line tool;
  - fix the gate's capture tool;
  - support posts shorter than one chunk (today they are refused: 32–77% of
    short posts at the laptop setting).

  Then the privacy gate re-captures. **Update 02:14 UTC: round 14 is done**
  (frozen, under independent review):
  - the tie to the real weights is now enforced in the library too;
  - short posts are proved as one chunk with public padding, so by length
    every one of the 4,872 benchmark items is now admissible at both laptop
    settings (it was 0–67%);
  - full suite 845 passed, 0 failed.

  The privacy gate (round 18) is re-capturing the new classifier stage now.
  **Update 04:14 UTC: round 14 accepted on soundness; gate round 18 passed
  all 21 captures** on the new classifier stage:
  - covered: both test models, all three verdicts, a 2-chunk post, short
    posts of 1–22 tokens, and two runs through the command-line tool;
  - the verdict changes nothing but its public bit;
  - a short post discloses nothing beyond its public length;
  - every tamper check fires.

  Still owed before a classifier privacy statement: the Shieldstral profile
  (waits on Sol's R13), the statement text, an independent privacy review and
  the sign-offs. Sol and Astra (Codex) are idle since 03:09 and 01:29 UTC and
  need a "continue" from Victor.
- **Now running:** Sol on R12b, Astra on the Shieldstral benchmark report and
  the integer export (the one open range question: two layer-25 channels).
  **Update 23:39 UTC:** layer 25 is fixed, with one extra Shieldstral-only
  SiLU table and a re-quantized up-projection. The integer Shieldstral now
  runs all 192 calibration inputs through all 26 layers with **zero
  refusals** [MEASURED, n=1]. Still to come: whether the integer model gives
  the same verdicts as the float model on the 4,872 benchmark items.
  Separately, Astra's float benchmark report is done (strict vs. moderate
  policy wording: nearly tied; the choice is Victor's).
- **New direction (D43):** finding funding as fast as possible comes first. A
  paper with the demo follows once the PoC works. Three research agents are
  surveying government grants, philanthropic and ZK-ecosystem grants, and
  investors / accelerators / venues. The ranked plan goes to Victor next.

**2026-10-26 18:05 UTC — the work is split with GPT Sol and Astra; the
prover's Shieldstral features pass their golden and dense proofs; the
accuracy stack is chosen.**
- **Team:** after the weekly usage stop (10-21 06:30 → 10-26), Sol (prover)
  and Astra (models, app) took over lanes; split and live logs in
  `docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md`.
- **Prover features for Shieldstral (native R12, Sol):** build, 207 focused
  tests, golden proof (41.6 s, 6.18 GiB) and dense proof (153.5 s, 6.59 GiB)
  all pass [MEASURED, n=1, shared box]. **Update 20:10 UTC:** frozen and
  independently reviewed — accepted with fixes on soundness (about 97.6 bits
  at T128, 95.0–95.4 at T512; existing proofs unchanged). One medium fix
  matters for the classifier: the prover must check that the output head is
  really the model's tied embedding, not just trust the export's declaration
  (fix in R12b, Sol). Not a privacy acceptance.
- **Resource guard fix installed (D42, 19:00 UTC):** jobs no longer block the
  shared lock while waiting for memory.
- **Accuracy (fidelity lane, final):** 8B uses **LOW + 24-bit h**: perplexity
  1.011x / 1.009x of float, LAMBADA 0.80 vs float 0.78, and the 2 refusals
  are fixed at no proof cost. It costs **+22.8% committed proof at 8B T128**
  (+24.9% against today's DD prover at T512). TinyLlama needs only LOW. One
  confirmation re-run with the two fixes is still owed. Report:
  `results/zk60_fidelity_parity_20261019/REPORT.md`; build spec for the next
  prover round R13: `S2_BUILD_SPEC.json` beside it.
- **Classifier verdict stage (token R-C1, Claude):** registry tests green;
  the freeze waits for one full suite run.
- **App (Astra):** canonical integer image preprocessing in (42/42 app
  tests); Base Sepolia (testnet) publisher wired up, nothing broadcast yet;
  Shieldstral strict-policy benchmarks continuing.

**2026-10-21 05:00 UTC — the media app runs end to end (on a stand-in prover).**
- `apps/proven-media/` (FastAPI + SQLite + plain JS; README has a 3-minute demo
  script; served locally at http://127.0.0.1:8765 on the laptop): compose
  text or image posts; each post is chunked (D41), labelled per category
  (explicit / violence / hate, D37), proved once at creation, verified in a
  fresh process, published to a content-addressed store, anchored in a
  hash-chained local "chain" (stand-in for Base), and served with an
  app-signed proof manifest; viewers set an audience (adult / minor) and
  restricted items are hidden with the reason; a "re-verify" button and an
  offline verify command check everything. Fail-closed per category.
- **Honest label:** today each post gets a real zero-knowledge proof of the
  TinyLlama next-token run as a stand-in; the labels come from a placeholder
  and are not yet bound by the proof. The real Shieldstral classifier proof
  (native R12 + token R-C1, in progress) swaps in through one interface.
- First stand-in post: prove 104 s, verify 19 s, 255 MB bundle; 36/36 app
  tests [MEASURED, shared box].

**2026-10-21 02:40 UTC — the full MVP is now a proven-safe media app (D37, D38).**
- **Direction (Victor):** the first application is safety classification: a
  media app whose posts carry public proofs that they passed a
  harmful-content classifier. **Model (D38):** Mistral's open classifier
  Shieldstral-1.0-3B (Apache 2.0), text only; the proof states that its
  yes-score beat its no-score by a public threshold; only the verdict, model
  and policy are public, the content stays hidden. Survey:
  `results/zk60_classifier_survey_20261021/REPORT.md`.
- **Lanes started:** model import + float reference + benchmark F1
  (calibration prep); prover features for Shieldstral's shapes (decoupled
  head size, YaRN rotary table, tied embedding; native R12); the classifier
  verdict stage with a public verdict bit (token round 12, design first);
  the media app with proof badges (`apps/proven-media/`, stub prover first).
- **Privacy:** D33 and D36 extended to frozen-r11 — both now cover the
  demo's exact binaries. DD passed the privacy gate on its first 8
  captures (gate evidence).
- **Fidelity:** 8B meets the amended bar (≤1.02x, zero refusals) with the
  LOW + 12-bit-score stack (1.011x / 1.010x); TinyLlama with LOW (1.009x /
  1.010x); cheapest DD-compatible 8B stack being measured; the chosen stack
  becomes the native build spec.

**2026-10-21 00:20 UTC — privacy accepted for a whole AI answer (D36); D33
extended to the current code.** Victor accepted both in the console:
- **D36, the next-token privacy statement:** a verifier who checks a proof
  of TinyLlama's next word (prompt lookup → all 22 trained layers → final
  norm → head → word choice, one proof) is never given the prompt, the
  activations, the scores or the word itself, and learns essentially nothing
  about them (~1 in 2^70 per run). Scope: TinyLlama, 32 tokens, calibration
  b4, public prompt length, CPU, round-9 code and its named binary
  `b56f1b71…`. Text: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_NEXT_TOKEN_TINYLLAMA_T32.md`.
- **D33 extended** to the round-9 code (same claim and limits).
- **Next:** a short re-pin reading so both name the demo's current round-11
  binary; the 8B and the accuracy-fix profiles need their own gate and
  statement later.
- **Fidelity:** the 8B now meets the perplexity bar with the HIGH stack
  (1.0045x / 1.0034x, 1 refusal from a calibration bound) at about +29% proof
  size; a cheaper stack (~+23%) is being measured; TinyLlama passes
  perplexity and LAMBADA (refusal fixes queued, no proof cost).

**2026-10-20 07:40 UTC — first configuration inside the fidelity bar (TinyLlama,
perplexity); the price of parity is now counted.**
- **Fidelity (D32 bar: perplexity <= 1.01x float, LAMBADA >= 99%, 0 refusals):**
  TinyLlama with the "LOW" stack — per-channel weight multipliers, per-group
  SiLU tables, 16-bit norm outputs, 12-bit softmax precision, 16-bit
  attention words — measures **1.006x / 1.008x** (FineWeb / WikiText) with 1
  refusal (a calibration bound, fix queued, no proof cost); LAMBADA not yet
  measured [MEASURED in the fidelity replica, 48+48 sequences; not yet a
  built proof profile]. 8B: the weight multipliers alone take it from 1.28x
  to 1.16x; the full stacks are being measured now.
- **What parity costs in proof size** (native count, exact against R9's
  layout): weight multipliers alone +10% (8B T128) / +7% (8B T512); the full
  stacks +22% to +29% (8B T128, prove time about +15% to +19%) and +18% to
  +26% (8B T512); TinyLlama LOW +21%. Softmax precision to 12 bits and the
  per-group SiLU tables cost nothing. Any such profile needs a soundness
  re-review and is outside today's privacy statements
  (`results/zk60_1b_native_20261017/r10/WEIGHT_RANGE_COST.md`, `r11/ACTIVATION_COST.md`).
- **Division dictionary (DD) accepted on soundness** (D24 review r9); privacy
  gate on DD captures in progress. Measured effect at 128 tokens: none
  visible (counted −3.9% committed at 8B); its payoff is at 512 tokens.
- **Demo kit measured on its final binary** (token round 11, `0c9f247c…`,
  frozen; REVIEW6 items closed): 8B 32-token demo prove 296 s with loading,
  verify 50 s; 8B 128-token demo prove 569 s, verify 55 s; both open token 11
  [MEASURED, n=1]. The presenter page now labels every speed ratio: the whole
  next-word proof is ~140–190x plain 8-bit inference at 32 tokens, ~80–100x
  at 128.
- **Waiting on Victor (console):** "extend D33 to frozen-r9" and "accept the
  next-token privacy statement" (both independently reviewed: yes / ready).

**2026-10-20 03:49 UTC — presenter demo kit ready; next-token prover hardened.**
- **Demo kit for presentations:** `results/zk60_token_io_r1_20261017/tools/demo_present.sh`
  (one command, narrates each step in plain words; options 8B 32-token,
  TinyLlama, 8B 128-token) and the one-page script
  `results/zk60_token_io_r1_20261017/DEMO_PRESENTER.md` (what is shown, what
  each step proves and hides, honest numbers, what NOT to claim, five Q&As).
  TinyLlama dry run: ~130 s of work end to end, token decoded for the owner
  [MEASURED]. Quiet the box before showing it.
- **Next-token prover round 9** (named CPU binary `b56f1b71…`): every refusal
  now happens before anything is written (privacy review PR4-4); the prompt is
  read from a protected file, never the command line; owner files live in
  `~/zk60-owner-private/`. Independent code review (REVIEW5): demo-fit, nothing
  affecting soundness; forged next-token proofs are rejected by the verifier
  in every tested case (8 of 8 on the old code, 4 of 4 on the new).
- **Privacy:** D33 re-pin onto the newer code reviewed YES — awaiting Victor's
  word ("extend D33 to frozen-r7"); next-token statement draft: 7 review items,
  most now closed (gate round 10 finishing the rest); D34 records the tiny
  input-dependent refusal term (~2^-117).

**2026-10-19 23:25 UTC — the next-token stages pass the privacy gate; first
128-token next-token proof.**
- **Privacy gate on the next-token stages** (prompt lookup, final norm + head
  + token choice, token endpoints; gate tools v10,
  `results/zk60_gate_tinyllama_20261017/token_io/TOKEN_GATE_REPORT_T32_v10.md`):
  all 10 captures PASS — TinyLlama T32 at 1, 2 and 22 layers and Llama-3-8B
  T32 at 1 and 2 layers, each with a real and a fixed prompt. The new
  commitments disclose nothing beyond the public lookup identity; the joint
  view across the shared planes is computed (0); full preimage on every
  commitment, 0 entries differing; 36 tamper controls fire on every capture
  [MEASURED, n=1]. Gate evidence, not a privacy acceptance: a next-token
  privacy statement is being drafted, then an independent review, then
  Victor. Not covered: the hidden-length variant, the GPU path.
- **First private next-token proof of a 128-token prompt:** TinyLlama
  (per-layer calibration), prove 192 s, about 0.67 prompt tokens/s (0.38 at
  32 tokens), integer and float references agree on the token (491, "by")
  [MEASURED, shared box]. **Llama-3-8B, 128-token prompt (01:12 UTC):** two
  exports proved end to end — b7voc0 501.6 s total (3.9 s per prompt token;
  8.3 s at 32 tokens) and the per-layer dg export 529.2 s; verify ~57 s;
  receipt 928 MB; whole-run floor 96 bits; owner decommits token 11 = integer
  and float references on both [MEASURED, shared box, n=1]. In tokens/s on
  the laptop CPU: 8B ~0.26 prompt tokens/s at 128 (0.12 at 32); TinyLlama
  ~0.67.
- **Fidelity, 8B with per-layer constants (dg):** perplexity 1.28x float (was
  1.63x / 1.77x), LAMBADA 0.69 vs float 0.78 (was 0.54) — about half the gap
  closed; bar (D32) is 1.01x and 99%. On TinyLlama the remaining loss is
  mainly the int8 weights (~1.5–2%); wider or better-rounded weights are
  being costed.
- **D33 re-pin** onto the tree the demo runs (R8 + token code): every pass at
  1 and 2 layers clean; 22-layer passes pending.

**2026-10-19 16:57 UTC — first privacy acceptance at a trained model's size
(D33).** Victor accepted the trained TinyLlama-1.1B T32 privacy statement in
the console. In plain words: a verifier who checks a proof of the 22-layer
trained TinyLlama stack learns nothing about the hidden prompt, activations or
output, except with odds around 1 in 2^70 per run (about 1 in 2^40 over a
billion runs). Scope is narrow on purpose: calibration pg_rot1, 32 tokens, the
CPU binary from native R7. Not covered yet: the per-layer recalibrations, the
next-token stages (gate round 7 running), Llama-3-8B, the GPU path; native R8
changed pinned files, so R8 needs a gate re-pin before it inherits this.
Text: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`.
- **Fidelity threshold ruled (D32, ~17:00 UTC):** integer perplexity <= 1.01x
  float (FineWeb and WikiText), LAMBADA >= 99% of float, zero refusals. Today
  [MEASURED]: TinyLlama b4 1.23x / 1.29x, LAMBADA 0.512 vs 0.628 (82% of
  float); 8B b7 LAMBADA 0.54 vs 0.78 on 100 items (69%). Far from the bar;
  the per-layer (dg) and GPTQ levers are being measured.
- **Same afternoon:** the 8B next-token demo ran end to end on native R8 with
  the recalibrated export (b7voc0: no layer-0 refusals over the whole
  vocabulary): prove 265 s, verify 81 s, owner reads token 11 = the integer
  and float references; token suite 748 passed / 0 failed [MEASURED, n=1].

**2026-10-19 16:18 UTC — the prover now carries the fidelity fixes.**
- **Both recalibrated stacks proved on native R8** (per-layer values for every
  calibration constant), bit-exact against the integer reference at every
  layer, verified in a fresh process from a verifier's copy, 11/11 controls
  refused [MEASURED, n=1]: TinyLlama `dg` T128 (every layer at its own
  constants) prove 183 s, receipt 498 MB; Llama-3-8B `b7voc0` T128 (b7 + the
  layer-0 vocabulary recalibration) prove 479 s quiet box, receipt 923 MB,
  verify 43 s. Receipt sizes are unchanged: the fixes cost no proof size.
- **The 8B layer-0 refusals are gone:** the recalibrated layer 0 accepts all
  128,256 vocabulary tokens (it refused " ." and "Tags" before) [MEASURED,
  exhaustive]. On the demo prompt, integer and float agree on the next token
  (11, margins 9.5 / 7.0 logits).
- **Fidelity is still far from parity** [MEASURED]: 8B b7 LAMBADA first 100
  items 0.54 vs float 0.78 (−24 points); TinyLlama b4 perplexity 1.23x / 1.29x.
  The `dg` per-layer calibration and the 8B dg build are being measured next.
- **Token lane round 6 done** (owner-directory race fixed, the demo reads its
  pins from an approval record, 8B demo passed end to end, full suite 740/0);
  round 7 moves it onto R8 and runs the demo on the recalibrated 8B export.

**2026-10-19 13:38 UTC — demo-ready CLI, honest baselines, fidelity target set.**
- **Demo flow for the trained 8B next-token proof** (`results/zk60_token_io_r1_20261017/tools/r4_cli_demo.sh`):
  `prove` 227 s (laptop CPU; 471 MB) -> `verify` 90 s (pinned to the trained
  model identity and the token-profile digest; the verifier publishes the
  statement itself) -> `owner` 83 s (re-verifies, then the prompt owner reads
  token 11) -> `input-owner` (the prompt owner confirms the proof used their
  32-token prompt). A layer-0 pre-check refuses the two tokens that overflow on
  today's 8B export (" ." and "Tags") by name before anything runs. Reviewed
  (token review rounds 1–4; round-4 fixes under confirmation).
- **Honest speed baseline** (`results/zk60_cpu_inference_baseline_20261019/README.md`):
  plain CPU inference of an 8B Llama at 8-bit takes ~1.55 s for 32 tokens and
  ~5.6 s for 128; the private proof takes 156 s and 433 s — about 100x and
  77x [MEASURED]. Tokens/s improves with prompt length up to ~128–256 tokens
  (~0.3 tok/s on the laptop CPU), then falls as attention grows.
- **Fidelity (D32: no performance degradation versus float).** Proposed
  threshold (for Victor): perplexity <= 1.01x float on FineWeb and WikiText,
  LAMBADA >= 99% of float, zero refusals. Today: TinyLlama 1.23x / 1.28x, 8B
  1.63x / 1.77x. Per-layer constants close ~52% of TinyLlama's gap (1.105x /
  1.121x) with no new proof planes; native round R8 is adding them for every
  shift. The 8B refused every WikiText window at layer 0 (token " ."); a
  vocabulary-wide recalibration of layer 0 (no proof cost) is in progress.
- **Privacy at trained TinyLlama size:** the statement is final after three
  independent review rounds and the gate's R7 re-gate; acceptance awaits
  Victor's word in the console.

**2026-10-19 10:20 UTC — first private proof of a trained Llama-3-8B's NEXT
TOKEN.** One proof: a 32-token hidden prompt -> the trained int16 embedding ->
all 32 trained blocks (streamed; layer 1 at its own score shift) -> final norm
-> per-row int8 head -> greedy token, sealed in a hidden output fingerprint;
the verifier sees no prompt, no activation and no token (D25). Token 11,
confirmed by three independent references (float head's top-2 margin 4.40
logits); bit-exact at all 32 layers; receipt 471,285,072 B; prove 191.7 s on
the laptop CPU, peak 3.44 GiB; fresh-process verify 43.4 s under a 95-bit
policy; 65 of 65 applicable tamper controls caught; whole-run soundness 97
bits; full suite 729 passed / 0 failed [MEASURED, shared box, n=1;
`results/zk60_token_io_r1_20261017/runs/r3/trained-ho00/`]. The integer head
meets D25 T4 at 8B (100% agreement with the float head wherever its margin is
>= 0.3; 99.1–99.8% overall). Independent review of this rung running.

**Also since 10-18:** the fidelity-improved 8B T128 block stack (layer 1 at
score shift 7; held-out top-1 0.651 -> 0.673) proved (471.6 s, shared box) and
was re-verified independently (identity 97c4acda…); quiet-box 8B stacks: T32
156.2 s, T128 432.5 s. Native R6 and R7 frozen and accepted / under review
(R7: stale-writer handling, backend allow-list). Privacy evidence at trained
TinyLlama size complete on R5b; the second independent privacy review lists
five closing items (re-pin and re-gate on R7, G-7, a 2-block root-rebuild
check, a text consolidation, owner confirmations D28/D29 — done); those are in
progress. GPU slot-18 kernel at 25.9 ms = 19.4% of 256 GB/s (laptop clock
capped at ~1.1 GHz); lane paused with a 5090 start plan. Victor's GPT
conversations yielded DD (per-row division dictionary, −20.8% committed at
8B T512, exact), admitted into the 8B T512 profile specification as D30; FN
withdrawn as a question.

**2026-10-18 01:42 UTC — first private proof of a trained model's NEXT TOKEN.**
TinyLlama-1.1B, a 32-token hidden prompt: hidden token ids -> embedding (indexed
lookup into the public int16 table) -> all 22 trained blocks -> final norm ->
per-row int8 head with 12-bit multipliers -> greedy choice (lowest-id ties),
the token sealed in a hidden output fingerprint, all **one proof under one
transcript**; the verifier sees no prompt, no activation and no token (D25).
Next token 29914, confirmed four independent ways (in-test reference, the
Python reference, the fidelity lane's integer head and its float head).
Receipt 255,258,816 B in 24 segments (equal to the counted lengths); prove
85.3 s on the laptop CPU, peak 2.45 GiB; fresh-process verify 10.6 s under a
95-bit minimum policy; a one-bit change refused; 55 of 55 applicable tamper
controls caught exactly where predicted; whole-run soundness 97 bits (meets
D27); full suite 708 passed / 0 failed [MEASURED, shared box, n=1;
`results/zk60_token_io_r1_20261017/runs/r2/ho00/`]. Built on the design that
passed two adversarial checks and on the tiny rung R1 that passed an
independent code review; the review of this rung (R2) is running. **Not yet:**
the hidden-length variant (D26), the privacy gate for the token stages
(G-1..G-7), and Llama-3-8B (rung R3). Not a privacy acceptance.

**2026-10-18 00:10 UTC — overnight checkpoint.**
- **First private Llama-3-8B stack at T128:** all 32 blocks, a 128-token
  hidden prompt, one proof: 607 s total on the laptop CPU with the R5b
  safeguards (487 s before them; the difference is a second witness build for
  the refusal-before-header rule), receipt 922,711,264 B, parity bit-exact,
  fresh-process verify with 11 tamper controls refused (0.21–0.26 proved
  positions/s) [MEASURED, shared box, n=1]. The T64/T128 profiles are under
  independent review (round 5).
- **R5b frozen (2026-10-18 00:06:31Z):** fixes the privacy review's blocker P-1
  (inadmissible inputs refused before the run header; the public statement is
  promoted only after a fresh verify), review r4's two verifier-DoS findings,
  and the gate's operating rules (allow-listed run label, hidden inputs kept
  out of the verifier's copy, refusal messages without data-derived counts,
  backend recorded). Suite 692 passed / 0 failed. Privacy gate re-capture and
  re-gate with tools v5 (pins now enforced) running on it.
- **GPU go/no-go:** 11.7% of the laptop GPU's bandwidth on the feed-forward
  zero-check, byte-identical to the CPU: improve kernels before porting more
  (register spills found; next round estimated 33–42%). Refitting the cost model
  on the 8B T128 stack confirms the plan: T512 on a 5090 is about 0.6–0.8
  positions/s with today's code, 6.6–8.6 with the whole prover on the GPU at
  today's efficiency, 9.4–11.8 with the attention-layout changes; 50 needs
  kernels near roofline.
- **Next-token proof:** rung R1 (tiny vocabulary) passes its full suite after
  census fixes and an independent code review (sound as built); review fixes
  TR-1..TR-4 and rung R2 (TinyLlama, 22 blocks) in progress.
- **Fidelity:** 8B T64 and T128 exports verified bit-exact; layer 1's weak spot
  traced to large negative attention scores setting a coarse scale; a per-layer
  score shift lifts held-out top-1 at T128 from 0.651 to 0.673 (KL 0.61 -> 0.50)
  with no layout change — native round R6 is adding it.

**2026-10-17 21:10 UTC — evening checkpoint: 8B stack 2.2x faster end to end,
security accounting corrected, five rulings recorded, next-token proof
designed and being built.**
- **Speed (startup cleanup, speed plan task 1 MET):** the private 32-block
  Llama-3-8B stack at T32 now takes **171.6 s total** (was 384.5 s this
  morning; target <= 180 s): weight digest pass 15.3 s (was 83.0), block
  reloads 16.0 s (was 79.2), witness 21.4 s, block proofs 118.8 s, in-process
  verify off (the fresh-process verify remains the check). Same statement
  identity 259dad7c…, same 465,815,776-byte receipt, parity bit-exact
  [MEASURED, shared box, n=1; `results/zk60_1b_native_20261017/r5/`]. That is
  0.19 proved positions/s at T32; the speed target (50/s on a 5090 at T512)
  still needs the whole prover on the GPU (speed plan).
- **GPU go/no-go (task 2), interim:** slot 18's zero-check runs on the laptop
  GPU with byte-identical rounds and seeded proof bytes at four shapes, 0
  silent fallbacks; a 22-block TinyLlama T128 stack with it proves and
  verifies fresh. Open: inside the stack the slot runs ~5x slower than in
  isolation; the bandwidth verdict waits for that diagnosis.
- **Reviews:** the independent review accepted the Llama-3-8B profile changes
  on soundness (round 3); its verifier-DoS finding (unbounded segment reads)
  is fixed in the frozen round-5 tree, which is under review now (round 4).
- **Security accounting (register D15, two notes):** the "106 bits per
  opening" ignored padding, and the lookup bound is now the checked
  (N + 2303)/|F|. Trained stacks are **about 97.4–98.2 bits whole-run**; an
  8B run at 512 tokens about 94.7 (about 99.7 as forger work per attempt).
  **Victor's D27:** about 95 bits whole-run is the MVP target at the named
  workload, 100 next, 128 for the product, with selectable tiers later for
  critical applications; throughput is not traded for bits at the MVP.
- **Rulings recorded today:** D23 and D19b accepted; D25 (next-token proof:
  one hidden token per run, hidden and sealed prompt length, lowest-id ties,
  per-row integer head matching the float head wherever its top-2 margin is
  >= 0.3 logits, private owner hand-off, BOS forced); D26 (security owner:
  the two-site input endpoint); D27 (soundness target).
- **Next-token proof:** design v3 passed two adversarial checks (three holes
  found and fixed before any code), paper reference 20 tests green; integer
  head fidelity measured on TinyLlama (98.9% overall, 100% wherever the float
  head is not a near-tie); the first native rung (tiny vocabulary, 2 blocks)
  is being built. Cost at 8B T32: about +3% proving time [MODEL].
- **Privacy gate (TinyLlama T32, 22 blocks):** the dense 22-block pass PASSES
  with every control family firing; the all-zero pass reconstructs every
  published value with 0 differing (25 million in the joint check); finding
  G-10 repaired. Owed before any acceptance: re-capture from the frozen
  round-5 tree (running), an independent re-read and adversarial review of
  the draft (running), and the remaining items of the draft's §10b. **No
  privacy acceptance at the trained shape yet.**

**2026-10-17 18:35 UTC — clean shutdown at 14:59, resumed at 18:21; no new
result yet.** The laptop shut down cleanly at 14:59:58 UTC (every guarded job
got SIGTERM; not a freeze) and booted again at 18:21. Correction to the 14:00
block below: the GPU go/no-go experiment had code written but **never ran on
the GPU** — its first device test was killed after 6 s by the shutdown. Also
cut off: the native round-5 test suite (never started), the 8B T64 calibration
export, and the review's last checks. The privacy gate's 22-block all-zero
pass finished before the shutdown: 0 differing values in the masking layer
(355,410 checked) and in the joint run (25,005,697); its FAIL flag appears to
come from controls that were not requested in that pass (being confirmed).
Everything uncommitted was pushed as snapshot 6 of
`snapshot/20261017-uncommitted`. Six lanes restarted behind the resource guard
(`ops/zkp-mvp/LANE_RULES_20261017.md`): GPU zero-check go/no-go, native R5
suite + startup cleanup + 8B T64/T128 phase ladder, review verdict on the 8B
profile, privacy gate controls and G-10, 8B calibration B6, and a paper design
for proving embedding, head and token choice (D13's next milestone).

**2026-10-17 14:00 UTC — how far from 50 proved tokens/s, measured-model
answer.** The costed speed plan ([ZK60_SPEED_PLAN_20261017.md](ZK60_SPEED_PLAN_20261017.md))
fits a per-phase cost model to today's TinyLlama ladder and predicts the
measured 8B T32 stack within 3.1%. Its projection for private Llama-3-8B at
T=512 on one RTX 5090 [MODEL]: today's code ~0.55 positions/s; the whole prover
on the GPU at this project's measured GPU efficiency ~7–9; with commitment
kernel and attention layout improvements ~11 (high end 22). **50 is reachable
only if every GPU kernel moves its counted bytes at about 23–34% of the 5090's
bandwidth** (today's commitment kernel: ~13% on the laptop). The plan's
go/no-go experiment — the FFN zero-check (slot 18) on the laptop GPU, with
measured bandwidth — started at 13:55 UTC; below ~10% the remaining levers
are design changes needing Victor's rulings (LogUp-GKR helpers, code rate
1/2, 16-bit range tables), which together still reach only ~13–16 [MODEL].

**2026-10-17 13:20 UTC — first complete private proof of a trained 8B model's
transformer stack.** All 32 blocks of Llama-3-8B (NousResearch/Meta-Llama-3-8B
rev 315b2009…, 8,030,261,248 parameters) proved as ONE bound private run at
T=32 (hidden input, output, activations and boundaries; public weights);
native witness bit-exact with the Python integer reference at all 32 layers;
calibration export `llama3_8b_pg_rot1_T32` (held-out top-1 0.62 FineWeb /
0.55 licence). Laptop CPU, shared box, n=1: total 384 s (weight loading 79 s,
witness 19 s, block proofs ~110 s, in-process verify 93 s), receipt
465,815,776 B in 32 segments, fresh-process verify 96 s, peak RSS < 2 GiB; 11
run-level tamper controls refused, honest run still verifies. Statement
identity 259dad7c…. Evidence `results/zk60_1b_native_20261017/r4/`.
The same stack on the laptop GPU (commitments on the device, "gpu: ON", 0
declines) took 391 s with the same statement identity: level with the CPU at
T32, where reloading the 8B weights (about 2.5 s per layer, three times per
run) dominates and the block proofs are 3.4–3.7 s each.
**Not yet:** speed (0.08 proved positions/s total; target 50 on a 5090),
T > 32, embedding/head (D13), fidelity (layer-1 attention sink), independent
review of the 8B profile changes, privacy acceptance at this shape, D23.

**2026-10-17 11:15 UTC — trained 1.1B stack 9x faster; first context ladder.**
Building the witness once and in parallel took the 22-block TinyLlama stack
from 529 s to 56 s at T32. Ladder on identical weights (CPU / laptop GPU,
shared box, n=1, each verified in a fresh process): T32 56 / 61 s, T64 85 /
89 s, T128 169 / 143 s — **0.76 proved positions/s on CPU and 0.90 with the
GPU at T128**, receipts 251 / 333 / 498 MB. The block proofs are now 72–81% of
the time; GPU commitments help from T128. T256+ needs more host memory than the
laptop has. D24 and the trained profile are accepted on soundness after two
independent review rounds. Next: Llama-3-8B calibration (running), an 8B
profile, and a T32 private 8B stack attempt on this laptop.

**2026-10-17 10:15 UTC — first complete linked proof of a trained model's
transformer stack.** All 22 TinyLlama-1.1B blocks as ONE private run (hidden
32-token input, output, activations and every block boundary; public weights),
calibration `pg_rot1` (held-out top-1 agreement with the float model 0.70–0.73,
no refused inputs). CPU, shared laptop, n=1: 528.9 s total, of which ~450 s is
building the witness twice on one thread and ~60 s the block proofs; receipt
251 MB; fresh-process verify 4.9 s; peak 2.15 GiB; 11 run-level tamper controls
refused. Before it, the independent review accepted the D24 norm rule but
found a real hole in the trained loader (an unchecked export constant let a
forged output verify); fixed the same morning (every export-chosen constant now
has a checked class; the forgery is refused) and under focused re-review.
**Not yet:** privacy acceptance at this shape, T above 32, GPU stack timing
(running), embedding/head (D13's next milestone), 8B.

**2026-10-17 05:20 UTC — first proofs of a real trained model's blocks.**
Every one of TinyLlama-1.1B's 22 transformer blocks was proved privately
(hidden 32-token input, output and activations; public weights) and each proof
verified in a fresh process from its bytes; the native prover's numbers equal
the independent Python integer reference bit for bit at every layer. Per block
on the laptop CPU: prove 3.2–4.2 s, verify 0.27–0.40 s, 11.6 MB, under 0.9 GiB
[MEASURED, shared box, n=1]. Layer 0 refused all 15 tamper/mismatch controls.
Full native suite 518 passed / 0 failed; frozen toy receipts unchanged.
**What it is not:** 22 separate one-block proofs, not a linked stack (nothing
yet ties block k's output to block k+1's input); proved on the low-fidelity
calibration `a` (held-out top-1 0.136 vs float); conditional on the independent
review of proposed ruling D24 (running); no privacy acceptance at this shape.
The calibration lane found a usable per-profile calibration (`pg_rot1`: top-1
0.698, perplexity 36.5 vs 29.3 float, no refusals) that needs four requant
shifts to become profile constants; the native lane is doing that now, then
the linked 22-block stack on CPU and GPU. Victor flagged arXiv 2610.08258
(zkLLMPoT, v2 11 Oct 2026): it hides weights with public audit inputs (the
reverse of our P1) and reports 41–59 s at 1.1–1.5B for "covered operators";
an assessment is running. Mac M3 Ultra (256 GB) not yet reachable; 5090 not
yet installed. [Checkpoint](ZK60_1B_CHECKPOINT.md).

**2026-10-17 02:20 UTC — work resumed after a 17-day gap; no new proof yet.**
Nothing native ran between 2026-09-30 01:38 UTC and today: the recovery session
of 09-29 ended abruptly (cause unknown; one minute earlier the resource guard's
memory cap had correctly killed an oversized test), and since then only the
hourly researcher worked (cycles 41–51, CPU-only arithmetic studies; none
changes the prover). The three answers are unchanged from the 09-30 block
below: **(1) workable proof:** complete private proofs exist for the tiny
block (two lines, privacy accepted only there) and for synthetic 125M-shape
stacks; **no trained block has been proved yet**. **(2) speed:** best complete
stack rate is 1.25 proved positions/s (synthetic 12-block 125M shape, laptop
GPU-assisted), about 40x short of 50 even at that small size; for 8B the
project's own projection is 0.6–1.2 tokens/s on a 5090 with today's code and
5–13 with every sumcheck on the GPU (not built), so **50 needs a design change,
not tuning**. **(3) what blocks the MVP:** a trained-model profile (norm
constants, calibration, weight loading), then the 22-block TinyLlama stack,
privacy re-checks at the new shape, and for 8B the RTX 5090 machine (Linux not
yet installed). Today: all uncommitted work since 09-23 was pushed as branch
`snapshot/20261017-uncommitted` (preservation only); the Llama-3-8B download
resumed; two lanes started — the native TinyLlama profile (proposed ruling D24:
lower the norm precision constant instead of adding a fifth limb) and the
calibration fidelity ladder with exports for a bit-exact parity check.
[Checkpoint and lanes](ZK60_1B_CHECKPOINT.md).

**2026-09-30 01:27 UTC: the box froze on 2026-09-29 (17:40 PDT); heavy work now goes through one
guard.** The machine died with five heavy jobs live, including the first
production 12-block GPU stack run, which therefore has **no result** (its log
stops after a GPU commitment; nothing was published). The exact cause is not
proven (no out-of-memory or GPU-memory error was logged); the fix is that
every build, proof, calibration and benchmark now runs through
`scripts/zk60_resource_guard.py`: one heavy job at a time, kernel-enforced
memory caps, GPU-idle checks and a permanent record of measured peaks
([rules and limits](ZK60_RESOURCE_PROTOCOL.md); 45 tests pass; Codex found and
we fixed a bug where the guard could have adopted its caller's session scope).
Nothing about proof speed changed. Best measured number is still the earlier
**synthetic** 12-block, 125M-geometry stack on this laptop's 4070:
1.25 proved positions/s over the whole test wall, about **40x short** of 50.
No trained 1B block or stack has been proved. Lane status: TinyLlama
calibration (Python reference) and the trained-profile prototype (five-limb
norm; its lost scratch work was recovered from a transcript, 7 fast tests pass)
are running again behind the guard; the production stack run waits for the
guard's small-shape canary. This is a stability fix, not a milestone.

**September 29, Tech Week demonstration:** the local browser demo now uses
real retained 785-byte Groth16 receipts for the small block and synthetic
two-block token model. Fresh-process verification and proof/policy tampering
controls pass. The HTTP path passes 32 checks across all three modes,
including artifact downloads and request boundaries; 69 demo and existing
zkVM-runner tests pass. Saved verification does not generate a new proof.
The live native synthetic-block option also passes, generating a 2,816,472-byte
proof and independently verifying it with tamper controls. Its 0.256-second
complete check is a shared-machine toy diagnostic, not a trained-model rate.
It uses a public fixture and the shared heavy-job lock; its first attempt
deferred while another proof held that lock. Trained
calibration/import and model-scale privacy/performance remain outstanding.
[Run the demo and review its exact scope](ZK60_TECHWEEK_DEMO.md).
GPT-6.1-Sol supplied the demo backend/readiness review; the existing Sonnet 5.5
lane supplies the separate native stack CLI. The hourly research supervisor
was confirmed alive and unpaused on the host at 00:12 UTC September 30
(17:12 PDT September 29); its next cycle is due at 17:45 PDT.

**Latest direction, 2026-09-26.** Target a complete private **8B-parameter
forward-pass proof at >=50 proved tokens/s on an RTX 5090 or another high-end
GPU**. Victor explicitly permits more tokens to amortize initialization and
initial prefill. The old 512-token / 10.24-second window is a reference, not
a mandatory latency limit. Measure larger workloads, report both sustained
and total-workload throughput, and retain setup, witness, proof and verification
clocks. [Current target and workload accounting](ZK60_THROUGHPUT_TARGET.md).
D13's first MVP still covers the hidden transformer blocks; token generation
is the following milestone. No complete private 8B timing exists yet.

**2026-09-27 UTC, Sol team checkpoint.** Three GPT-6 Sol agents completed
their native fusion, keyed GPU commitment and memory/model-readiness batches. The
fusion candidate passes core debug/release, 512 native tests (17 ignored),
fresh/cross-version receipt verification and nine corruption refusals. Its
six-run CPU A/B completed: the fused evaluator was 1.66% slower in mean
proving and 10.38% slower in the softmax slot (two non-warm samples per arm).
It is demoted; the grouped baseline stays in place. The keyed GPU candidate
now passes resident, forced streaming, compact-pad and complete small tagged
block CPU/GPU receipt checks on the RTX 4070 Laptop. The first streaming
launch failure is retained separately; the corrected attempt passed and all
source/binary/log hashes were rechecked. Independent review found no concrete
static defect; core debug/release pass 74 unit + 2 integration tests each.
The broader device oracle passes all 189 cases. Native GPU-feature release
coverage is 491 passing tests plus one successful missing-fixture rerun,
17 ignored; it is not a single full-suite pass. All eight frozen legacy
proofs now match exactly across resident/forced-chunk configurations. One
runner falsely rejected v3's success marker; its failed report is preserved,
with an explicit source/log/proof-hash adjudication and six passing remaining
cases. Root rechecked the 184 source, six binary and six continuation log
hashes. The six-run dense CPU/GPU A/B is complete and all receipts verify.
Two non-warm samples per arm give mean proving **32.95 s CPU / 17.13 s GPU**
and whole test-process elapsed **39.895 s / 30.055 s**. Mean peak host RSS
falls from **10,524 MiB to 4,411.5 MiB**; VRAM peak was not measured.
This is one synthetic 125M block, two CPU threads, RTX 4070 Laptop, shared
host. One GPU witness build took 10.66 s versus 5.77 s in the other sample;
the hourly researcher was active. Each sample uses a fresh process, so
startup and verification remain in whole-process elapsed. This is not
steady-state throughput or a complete-model rate. Softmax proof work remains
roughly half the GPU-assisted prover's time. See the
[A/B evidence](../../results/zk60_sol_gpu_20260927/attempt-5-dense-ab/report.json).
No 5090, full trained 8B or larger-profile privacy result is established.
[Team/evidence map](ZK60_SOL_TEAM_20260927.md).

An allocation-free audit of the historical 7.24B Mistral geometry counts
25.70 GiB retained payload at 512 tokens and 70.57 GiB at 1,024 tokens,
before weights and some scratch. These are lower bounds for unregistered
layouts, not measured peak memory or 8B proofs. All 256 historical FFN
export tensor files are missing; their manifest survives. A trained full-
block importer/calibration and a literal 8B checkpoint remain outstanding.
[Model and memory audit](../../results/zk60_sol_model_20260927/layout-readiness.md).

Victor has both the RTX 5090 machine and the M3 Ultra available (256 GB
unified memory, corrected by Victor on 2026-10-17; earlier text said 512 GB).
The 5090 machine needs a fresh Linux installation; neither new machine has
been validated remotely. The [setup guide](ZK60_HARDWARE_SETUP.md) starts
with a USB Ubuntu installer made on the Mac, followed by driver and read-only
host checks. The Mac's first role is CPU reference/witness work; there is no
Metal proof backend. Memory-bounded commitments are an active follow-up.
A small CPU streaming-root/recomputed-opening prototype passes eight legacy
and tagged fixtures: identical leaves, roots, opening bytes, transcripts and
RNG continuation, with mutation refusals. Releasing A/H codewords would
reduce the T512 retained floor to 5.35 GiB. This is a test-only prototype;
production lifetimes, measured peaks and throughput still need validation.
The successful **GPU chunked path already streams codewords and recomputes
queried columns**. Its separate A/H retained bounds are 5.18/14.23 GiB on
host and 5.17/14.22 GiB in VRAM at T512/T1024; the earlier 25.70/70.57 GiB
floors describe materialized storage or CPU fallback. Host witness/helper
overlap remains at least 9.86/27.17 GiB before other scratch.
[Updated tier-specific audit](../../results/zk60_sol_model_20260927/gpu-chunked-memory-audit.md).

The persistent hourly research supervisor was resumed and its host process
confirmed alive; its first sandbox restart failed before research began, and
the host restart retains the hourly schedule. A separate session research
agent completed a [resource-budget handoff](../../research/zkp-efficiency/handoffs/20260926-forward-budget-and-traffic.md).
Its 14 arithmetic checks are not prover or GPU measurements. Raw-log correction:
the historical FFN-only 196.79 s is internal wall time; enclosing process elapsed
is 200.09 s. Both exclude the earlier witness export/inference work.

Implementation has resumed in an isolated Rust candidate: the research lane's
grouped-equality softmax evaluator is wired into the real SC_SZC slot. Core
debug/release tests pass (73 unit + 2 integration each), including masked
bytes/challenges/finals and a release work-count check (1,403 -> 1,148 expensive
bracket calls). Eight targeted native tests also pass: dense/padded block and
three-block-run verification, inconsistent-witness refusals, and independent
polynomial oracles at every registered shape. Fresh/archived receipts cross-
verify in four processes with nine corruption refusals. **The full native suite
has now passed: 512 tests, 17 explicitly ignored.** All nine validation steps
pass; 183 source hashes, three binaries and all nine log hashes were rechecked.
The dense grouped A/B has completed: all six proofs verify at 40,783,352
bytes. Two non-warm runs per arm show proving 37.63 / 36.84 s before versus
34.86 / 33.31 s after: about 8.5% less proving time on average in this
shared two-thread CPU diagnostic. The full softmax slot falls about 18.4%;
the known witness+prove+serialization sum falls about 7.2%. Warmup proving
times were nearly equal (34.69 / 34.38 s), and two samples per arm do not
establish a stable production speed factor or p95. Both binaries include
small-slot test oracles; no GPU/8B or privacy-scope result follows.
[Retained candidate and validation](../../results/zk60_grouped_rounds_20260926/README.md)
record the evidence and audited phase summary.

**Live work checked at 05:41 UTC:** the hourly GPT-6 Sol research supervisor
is alive and unpaused, idle between cycles; cycle 0013 completed and the next
is due at 05:52:33 UTC. The earlier implementation/benchmark batches are
finished; no full 8B proof or 5090 benchmark is running. Cycle 0013 tests a
synthetic device-round schedule for softmax sumcheck: 110 round-point checks,
91 final-table checks and eight mutation controls pass on CPU. It does not
implement the actual native polynomial, BLAKE3 transcript or CUDA path.
The next implementation gate is exact native masked-transcript parity before
a device round/fold implementation and whole-proof timing. The eleventh
cycle's direct-helper experiment has a roughly 3% parent-phase ceiling in
the cited earlier CPU workload. The ninth cycle's fused fold/next-round
proposal was implemented and measured above, then demoted after slower
results despite lower counted table traffic.
Victor requested periodic updates; active sessions report here in chat, and
each background cycle must refresh the durable
[progress report](../../research/zkp-efficiency/PROGRESS.md). Local reports
are not automatic chat notifications.

The separate R2a allocation A/B completed: all six dense 125M proofs verify
at 40,783,352 bytes. Non-warm proving seconds: old 44.51 / 40.27, new
39.73 / 40.10, two CPU threads. Native compilation overlapped part of this
shared-box measurement; no reliable end-to-end gain is established. These
conditions differ from the earlier 17.4–19.4 s CPU runs, which they do not
replace. No new privacy acceptance or private-model speed is claimed.

**Updated 2026-09-22, during shaped-block integration, by the Codex/Fable
loop (after the 01:04 laptop restart; see §3 item 4).** This page
answers three questions and is refreshed whenever the loop produces news.
Rulings are in [the decisions register](ZK60_DECISIONS.md); measurements
carry their labels ([MEASURED] a run happened, [COUNTED] arithmetic on
measured pieces, [MODEL] an estimate). Nothing here is a quiesced benchmark;
the laptop is shared with other jobs.

**Current speed and completeness (2026-09-22).** The latest dense synthetic
block at the 125M geometry proves in **17.4–19.4 seconds on CPU**, down from
27.7 seconds; its receipt is 40,783,352 bytes and verification takes
1.15–1.34 seconds [MEASURED, shared box]. The 17.40-second run separately
spent 5.24 seconds preparing the witness, so it is at least 22.64 seconds
before verification. The latest twelve-block dense run remains **397.71
seconds**, with 14.45-second verification and 484,107,456 receipt bytes; it
predates the latest speed changes and has not been re-timed with them. The
five-second goal concerns a model pass; the single-block clock alone does
not establish its distance from that goal.

All transformer-block operations and twelve-block chaining are implemented
and exercised on synthetic public weights with hidden activations. The
grouped-attention completeness repair has been independently reviewed.
Whole-proof privacy acceptance remains confined to the small CPU toy block;
the larger profiles' privacy argument, trained-model integration and the
production run interface remain unfinished. Main's host optimization is
accepted; the combined larger-block source at lane `fee1a8d` has passed its
16-step CPU integration baseline in `/tmp/wt-zk60-shaped-20260920`, with
source-pinned results under `results/zk60_shaped_integration_20260922/baseline/`
there. The retained logs and all 179 source hashes were checked again: no
mismatch. This is not final integration acceptance; device checks, wider
privacy acceptance and the production model run remain outstanding. No new
model-scale or GPU timing is implied by that integration work.

**2026-09-22, isolated sumcheck candidate:** an additive evaluator interface
and redundant-evaluation shortcut pass core debug/release checks, all 512
native tests across a full run plus a fixture-only rerun, and old/new receipt
verification. Four dense 125M block proofs also pass at the unchanged receipt
size. On two Rayon threads, the softmax sumcheck phase measured 9.05–9.26 s
before versus 8.55–8.59 s after (two samples each). Whole proving time varied
from 38.96–61.79 s before and 38.06–43.02 s after, so no reliable end-to-end
speedup is established. The candidate test binary includes extra small-slot
oracle checks. This is not yet integrated into main or a new privacy/GPU
acceptance; it does not replace the earlier differently situated CPU clocks
or the 8B target. [Source, tests and retained measurements](../../results/zk60_sumcheck_rounds_20260922/README.md).

**Target reaffirmed by Victor, 2026-09-22:** five seconds for an **8B-parameter
model on better hardware with a GPU**. The 125M CPU runs are development
measurements, not the target workload/hardware. Retain the current 512-token
prefill window when comparing throughput, and report proof generation,
witness preparation and complete readiness separately. The recorded public
Mistral-7B measurement is **58.40 seconds for FFN only**, or **8.77 proved
tokens/s** over that window; attention is excluded. Its complete logged wall
time is 196.79 seconds (2.60 tokens/s). There is no measured 54-second
FFN-plus-attention result. Five seconds over the same window would be 102.4
proved tokens/s; none of these rates measures autoregressive generation.

**Latest integrated speed work:** corrected direct-plane GPU uploads and
private host buffer/fold reuse pass 43 isolated validation steps, including
307 storage-feature tests, 189 actual-device cases and twenty frozen proof
comparisons. Main's separate rebuild and receipt checks also pass: two fresh
receipts, fourteen cross-version verifications and 24 GPU-feature private-IO
tests under all buffer/fold settings. Floors v11 pins the new inventory, with
89 tooling tests passing. [Evidence and limits](ZK60_HOST_PRIVATE_INTEGRATION_20260920.md).
These checks establish correctness; they do not measure private-model speed.

The preceding exact int8/int32 row folds pass all twelve
CPU/GPU proof-byte gates, fresh native receipt verification in both modes,
and repaired private-IO P1/P3 checks. Dense synthetic folds improve
2.32–2.42x; sparse cases are mixed. Full-model proving time remains
unmeasured. [Evidence and limits](ZK60_ROWFOLD_INTEGRATION_20260919.md).

> **CORRECTION, 2026-09-20 18:40 — read this before the 125M paragraphs
> below.** A defect was found today in the private block at every shape with
> more than one key-value head (both development sizes and the 125M shape;
> **not** the small accepted test block, whose acceptance D22 stands). **The
> verifier refuses an honest proof as soon as the hidden data differs between
> attention heads.** Every 125M result below — one block, two blocks, twelve
> blocks, tagged and untagged — was obtained on a synthetic input in which
> every head sees the same data, where the defect does not show. **So those
> results are true of the input they proved, and the 125M private block is NOT
> yet a working proof for general inputs.** The cause is understood (two
> attention steps treat a shared index as fixed where it must be summed over —
> the security owner's own construction error in generalising to grouped
> heads, missed by the design's checker and the code review because nobody
> proved a generic honest input); it costs completeness, and as far as argued
> not soundness: nothing false was accepted. The fix is being written now; it
> will change the proof bytes and sizes of the shaped profiles, and the 125M
> figures will be re-measured on dense weights and a generic input. The
> feed-forward half held up under the same test: dense weights, generic data,
> tampering at the wide hidden indices rejected. Found by the dense-weights
> test added this afternoon (finding S19-F1, lane `zk60-private-block-125m`).
>
> **Repaired the same evening (19:30), review pending.** The two attention
> steps now sum over the shared index. The honest input that was refused is
> accepted; a generic input on **fully dense** weights proves and verifies at
> the development size, as a three-block run too; tampering in the second
> key-value group is rejected by the verifier; the small accepted test block's
> bytes did not move. **At the 125M shape, one block on fully dense weights
> with a generic hidden input: prove 27.67 s, verify 1.12 s, receipt
> 40,783,352 bytes, peak 9.99 GiB; on the all-zero input: prove 26.98 s,
> verify 1.23 s** [MEASURED by the security owner, one run each, laptop CPU,
> shared box, 19:25]. Dense weights cost no measurable time. **These two are
> the first 125M results on a non-degenerate input; the twelve-block figures
> below have NOT been re-measured yet**, and an independent review of the
> repair (soundness, masking budget, completeness) is running. Still no
> privacy claim for anything but the small test block.
>
> **21:02 the same evening — reviewed, and the twelve-block run redone on a
> non-degenerate input.** The independent review found no hole in soundness,
> completeness or the masking budget, and confirmed that nothing false could
> have been accepted before the repair. **All twelve blocks at the 125M shape,
> fully dense public weights, a generic hidden input, one run under one
> transcript: prove 397.71 s, verify by streaming 14.45 s, receipt
> 484,107,456 bytes (equal to the counted figure), peak memory 10.15 GiB**
> [MEASURED by the security owner, one run, laptop CPU, shared box, 20:53].
> Every block's wide hidden layer, every attention head and every key-value
> group carries non-trivial values in that run. **This supersedes the
> twelve-block figures below as the project's 125M result**; they stay on the
> page as the record of what was run on the degenerate input. The privacy
> gate has not yet been run on a non-degenerate input (in progress at the
> development size), and **no privacy is claimed for any of this.**

**The 125M-shape block now proves in 17.4–19.4 s instead of 27.7 s — same
bytes, same refusals; independently reviewed (added 2026-09-21 10:00; second
sample and the range added 12:57).** *A second run of the same prover on the
same shared laptop, with a counting diagnostic switched on, took 19.36 s
(verify 1.34 s, same receipt length, peak 10,141 MiB); the parts of that run
the diagnostic does not touch moved more than the prove did, so it reads as
run-to-run spread, and the honest statement is a range from two runs, not
17.40 s.* One
block at the 125M shape, fully dense public weights, a generic hidden input:
**prove 27.71 → 17.40 s (37% less), verify 1.28 → 1.15 s, receipt 40,783,352
bytes in both, peak memory 10,232 → 10,156 MiB** [MEASURED, one run each,
laptop CPU, shared box; lane `zk60-private-block-125m` at `309d238`, log
`q28-m125-final-dense.log`, re-read by the security owner]. Nothing the prover
sends changed: the work was in how the same numbers are computed — the
lookup inverses come from a 256-entry table instead of 98.6 million
inversions (4.06 → 1.08 s), and the tables each of the 23 sub-arguments
starts from are built once and faster (6.01 → 0.59 s), with the slowest
sub-arguments roughly halved. The small accepted test block's bytes did not
move; the test filter is 319 passed, 0 failed. Because receipts are not
reproducible (fresh randomness every attempt, by an accepted privacy
condition), "same bytes" rests on ten old-against-new equality tests, the
size pins and honest proofs verifying — so an independent reviewer who did
not write the code attacked it. **Reviewed 10:40: no defect found, no
production line changed.** A complete twelve-block 125M run written by the
OLD prover is accepted by the NEW verifier (15.20 s, 476 MiB); 1,800
randomised old-against-new comparisons agree; the whole test filter passes
again on one thread (327 passed, 0 failed); no changed computation is
reachable from the verifier. The review also found four places where the
tests are thinner than the claim (one changed sum has no direct
old-against-new test, and the small shapes never take the parallel branches);
the security owner ruled that these are closed on the lane before the
integrator takes the stage (`ZK60_BLOCK125M_S28_DISPOSITION.md`). The all-zero
control run: 17.71 s, same receipt length. **What this does and does not mean
for the target:**
about 79% of the remaining 17.40 s (13.8 s: the shared masked-sumcheck loop
6.6 s, the two commitments 6.5 s, the openings 0.7 s) sits in code the
integrator owns, and the commitments are exactly what a GPU takes — but the
hash rule this profile uses does not run on the GPU path yet. This is a CPU
result at a 125M-shape block; the 5-second target is defined on the 8B
model's pass, where the best measured figure is still 58.4 s on public
inputs. It does not move that figure.

**Where the privacy of the 125M-shape block and of a twelve-block run stands
(added 2026-09-21 00:06).** Privacy is **accepted for one artifact only**, the
small test block (register D22); it was re-confirmed last night against the
integrator's newly merged code, and its checks now watch every source file on
its path. *2026-09-22: the integrator delivered a capture of a proof made by
the merged code's own binary; the gate replayed on it — every one of its 132
source pins matches the tree the acceptance names, no figure of record moved,
all ten tamper controls fire — so the acceptance now rests on the merged
tree's proofs as well as the old tree's. Same scope: that one small block, on
the CPU.* For the shaped block and a run, **nothing is accepted**, and this is
the honest state of the five-step argument:

| Step | Development sizes (two head geometries) | The 125M shape |
|---|---|---|
| The all-zero reference input proves and verifies | done | one block done; a two-block all-zero run done and captured (2026-09-21 08:57); a twelve-block all-zero run not run |
| Per commitment, the verifier's linear view discloses nothing | argument checked by an independent implementation and ruled; measured on fully dense inputs | **MEASURED for the first time (2026-09-21 11:18), on two two-block runs, dense and all-zero: the big commitment of hidden values discloses 0; the helper commitment discloses 2, checked to be exactly the public lookup identity; endpoints 0; the boundary between blocks 0 on all 6 of its reserved rows; the masking commitment 0; the whole run the sum of its parts.** 180 figures were predicted from the shape before the run and none came out unexplained. The independent tool first failed on three sub-arguments — a defect in the TOOL that only this shape could show (three of its domains are exact powers of two), now fixed with its own control |
| The gate constructs matching blinding values | **done for all ten commitments of a run, the two big ones included (2026-09-21 05:59): 4.76 million published values of four real runs reproduced from all-zero data, none differing**; **since 08:03 also the masking commitments, and one joint assignment for a whole run (4.95 million values over four runs, none differing)** | **done for two-block runs (2026-09-21 12:49, read out of the committed record by the security owner): all seven commitments on both the dense and the all-zero capture — 8.26 million published values each reproduced from all-zero data, none differing — and these per-commitment assignments are shown to be compatible with one another (no coupling between commitments touches a blinding row), so together with the masking layer they form one assignment for the whole run, 8.30 million values; about 21 minutes a run at 5.5 GB.** *Said more exactly at 14:26 after a second agent verified the first: the 8.30 million is the SUM of values each checked once in its own part, not a separate third check.* **Completed 2026-09-22 10:02: the repaired tool's full pass at 125M landed — every tamper-control family now fires at this size, and the 125M record carries the same channel table as the small shapes (28 channels: 10 constructed, 5 derived, 4 argued, 9 open). Three more small shapes that reach the 125M block's row width, head size, endpoint geometry and a layout correction went through the whole gate with nothing unexplained.** Not done: a twelve-block run (eleven internal boundaries instead of one) |
| All published values jointly do not depend on the input | accepted as a reduction; three named gaps being drafted or tested | the same |
| The hash layer and the step to the real (hashed) protocol | computed for what a proof opens; the argument for a run was checked independently and ruled on 2026-09-21 01:15 — it holds with changes, and its last step (composing the blocks of a run in sequence) is reduced to named hypotheses, not closed | for what a proof opens: 2,304 opened columns (52.9 MB) re-hashed under independently derived keys and authenticated, and all 27,828 challenges re-derived (11:18); the argument is the same document as at the development sizes |

Sized terms so far for a twelve-block 125M run [COUNTED, each recounted
independently]: the blinding sampler's bias about 2^-69.3 (decision D9); a
refusal that could depend on the input about 2^-114.8; a refusal on unlucky
challenges about 2^-58.8 per run, which costs a failed run and discloses
nothing. **What this means in plain words: the
construction has survived every attack thrown at it on the privacy side, one
of yesterday's attacks found a real completeness bug that is now fixed, and
the remaining work is argument and measurement, not redesign — but it is not
finished, and at the 125M size part of it will rest on argument plus
measurements at smaller sizes that share its geometry.**

**Latest on the fast line's private block (added 2026-09-20 07:10 by the
security owner's session):** one **complete transformer block with hidden
input, hidden output and hidden activations now proves and verifies at a real
model's shape** — the 125M class: 512 tokens, width 768, hidden 2048, 12 query
heads over 4 key-value heads — on the fast native line, on this laptop's CPU.
**Prove 26.89 s, verify from bytes 1.04 s, receipt 40,782,792 bytes, peak
memory 10.42 GiB** [MEASURED, one run, shared box, 2026-09-20 07:03; the
paper model had said 25–36 s and about 11 GiB]. What that is and is not:
**synthetic weights, one block of twelve, no GPU, and NOT a privacy claim at
this shape** — the privacy checks are owed again at every new shape and need
capture bundles that do not exist yet. Before it ran, the design was attacked
on paper (a padding hole was found and closed before anyone built it), grown
test-first through a small padded shape, and the code was attacked by an
independent reviewer who could not get a false statement accepted; the toy
block's bytes are unchanged, confirmed by verifying receipts made before the
work began. Lane `zk60-private-block-125m` (pushed, not yet integrated);
ledger `ZK60_BLOCK125M_LANE_PROGRESS.md` on that branch. **For the toy block
only, the privacy argument now has a checked core at every step**;
the three rulings from Victor were accepted at 13:45, followed by D22 below
([one page](ZK60_RULINGS_FOR_VICTOR_PRIVACY.md);
[superseded draft](ZK60_PRIVACY_STATEMENT_TOY_PROFILE_DRAFT.md)).

**First privacy acceptance on the fast line (2026-09-20 13:46, register
D22):** the **toy private block** — one block, 32 tokens, width 16, public
synthetic weights — is accepted as private by the security owner, in the model
Victor accepted the same day (D19 the hash as an ideal random function, D20
timing/memory/power out of scope with refusals kept in, D21 rejected receipts
never sent and captures counted as publishing): a verifier's view is within
about 2^-77.7 per proof of one that does not depend on the hidden data. **For
that one small artifact and nothing else** — not the 125M block below, not any
multi-block run, not real weights, not sealing in advance. It is an argument
whose every step survived one independent attack, not a proof the security
owner re-derived; [the statement](ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md) lists
its residuals, the seven conditions under which it lapses and what reopens it.

**The separating hash tag is in, and the twelve-block run was re-measured
under it (added 2026-09-20 16:40):** decision D19 obliged every new shape to
hash its transcript, its column digests, its Merkle leaves and its Merkle
nodes under separate keys. That is built (register D19a; BLAKE3's keyed mode,
four public keys per shape, the verifier deriving them from the profile it
trusts; the toy block is never tagged, so the accepted bytes above do not
move), reviewed by the security owner, and authorised by the integrator as an
additive change to its files. **Under the tag, all twelve blocks at the 125M
shape prove and verify as one run: prove 393.59 s, verify by streaming
14.09 s, receipt 484,100,736 bytes (equal to the counted figure), peak memory
10.15 GiB; one block alone: prove 27.87 s, verify 1.21 s, 40,782,792 bytes**
[MEASURED, one run each, shared laptop with an agent active, CPU only, finished
16:39]. That is about 5% slower than the morning's untagged runs (370.61 s;
26.54 s) — **not attributable to the tag**: the two hashing phases moved one
up and one down, and a phase with no hashing in it moved more than either.
**A caveat on every 125M figure on this page, found 2026-09-20 17:30:** the
synthetic public weights used by all shaped tests are *diagonal* (64 on the
diagonal, zero elsewhere). Where the hidden layer is wider than the model
(2048 against 768), the upper part of the hidden layer therefore carries zeros
in every proof run so far: the wide geometry has been exercised in its sizes,
padding and checks, **not in its numbers**. No defect was found (the layout
was read line by line and one public table re-derived by arithmetic), and
proving time barely depends on the values (one phase skips zero weights; about
a second per twelve-block run [MODEL]). A dense-weights test with a
non-trivial hidden input is being added now, at the development size first.
The run now leaves its **public statement** beside its segments (written only
after the whole run verified), so a fresh process can check it. **Still no
privacy claim for anything but the toy block**, and the integrator has not yet
integrated or reproduced these runs.

**ALL TWELVE BLOCKS, ONE PROOF (added 2026-09-20 11:25):** a **private run of
all twelve transformer blocks at the 125M shape — hidden input, hidden output,
every activation and every block-to-block boundary hidden — proves and
verifies under one transcript: prove 370.6 s (6.2 minutes, about 30.9 s per
block, flat), verify 13.7 s by streaming one 40 MB segment at a time, receipt
484,100,736 bytes (equal to the counted figure to the byte), peak memory
10.15 GiB, on this laptop's CPU** [MEASURED, one run, shared box, finished
11:22]. What it is not: **synthetic weights, not a trained checkpoint; the
blocks only (no embedding, no output head — decision D13 says the blocks are
enough for the first MVP); no GPU; and no privacy claim for a run exists yet**
— the privacy checks for a multi-block run are designed and not built. Its
whole-run soundness is about 2^-97.5 by the project's accounting and its
receipt is 484 MB against a 256 KB budget; both are on Victor's page as
deviations for him to rule on.

**And blocks now chain (added 2026-09-20 10:48):** a private **run of two
blocks under one transcript** — block 1's hidden output is block 2's hidden
input, never published — proves and verifies at the same 125M shape: **prove
62.9 s, verify 2.0 s, receipt 81.1 MB in two segments** [MEASURED, one run,
shared box, CPU]. A verifier rejects a second block that was run on anything
other than the first block's output. This matters because separately finished
private proofs cannot be joined afterwards; a full model has to be one run.
Twelve blocks are counted at about 6.3 minutes of proving, 12.5 s of verifying
and 484 MB [COUNTED], with a whole-run soundness of about 2^-97.5 by the
project's accounting — and **no privacy claim exists for any run yet**; the
design, its independent check and the rulings are
[here](ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md) (register entry D12a).
Where a private block's 26.5 s goes is measured too: one softmax check 25%,
lookup inversions 15%, the two commitments 25%, the feed-forward part 5%
([plan §5.2b](ZK60_MVP_COMPLETION_PLAN.md)).

## 1. Do we have a workable proof?

**A complete small-block experiment works. The model MVP remains open.** Today at 19:18 the
first complete transformer block (T32 tokens, width 16, FFN 16, two heads,
the real integer kernel: both RMS norms, QKV, RoPE, causal integer softmax
attention, PV, output projection, both residuals, SiLU FFN) was proven by
re-execution inside the RISC Zero zkVM and wrapped into a **785-byte Groth16
receipt** that verifies in a fresh process in 8 ms. Seven corruption
controls (wrong context, model, input, output; truncated, trailing,
tampered bytes), plus the inner receipt kind, are rejected. Inputs, outputs
and activations are hidden under the reviewed Groth16 premises;
the public artifact is the receipt plus a 144-byte policy of digests.

| Stage | Result | Label |
|---|---|---|
| inner STARK proof (succinct receipt, 223,514 bytes) | 3,743 s on the shared laptop CPU, two threads | [MEASURED, NOISY-SHARED] |
| Groth16 wrap with the extracted native prover | 197 s | [MEASURED, NOISY-SHARED] |
| independent verification | 0.008 s | [MEASURED] |

**And, at 21:34, the first proof of actual token generation:** the
two-block token model (public embedding, two complete blocks with their
hidden seam, final norm and head, greedy next token; synthetic T32 fixture
with a 32-word vocabulary, not a trained model) proven by re-execution and
wrapped to a 785-byte Groth16 receipt; independently verified, eleven
rejection controls pass, and the block-profile verifier refuses it as a
different profile. Prove 7,488 s (2 h 5 min) on the shared CPU, wrap 197 s
[MEASURED, NOISY-SHARED]. Public artifacts retained under
`results/zk60_loop_20260918/token-integration/token_public/`.

What it rests on: RISC Zero's proof system at about 97 bits conjectured
soundness (D3), the Groth16 trusted setup (D4), Groth16 receipts only (D5),
and the salted-SHA-256 endpoint profile accepted under D7 at 11:50 on
September 19. The D7 qualifiers remain explicit: salt secrecy protects the
toy answer (the model library still accepts zero/repeated salts), the image
is locally built and not independently reproduced across directories, and
timing is declared leakage; the scan and cycle check cover only the block
program. Both receipts use synthetic tiny fixtures and make no model-speed
claim. D13 makes hidden model blocks the first MVP; token generation follows.

**On the custom prover line (hashline), the first complete private block now
proves and verifies (2026-09-19, 05:14), and at 06:25 the security owner
accepted it as an experimental component — still not a privacy acceptance.**
The same kind of block as above (T32 tokens, width 16, two heads,
feed-forward width 16: attention, both norms, both residuals, the SiLU
feed-forward) in **one native proof with no seam**, inputs, outputs and
activations hidden, weights public, on a public synthetic fixture. On the
security owner's own run: **prove 0.095 s, verify 0.043 s in a fresh process
from bytes only, receipt 2,816,472 bytes** — exactly the size the design
derived before any code existed [MEASURED, NOISY-SHARED, diagnostic only]; 38
unit, parity and tamper tests and 4 integration tests pass; the witness
matches the integer reference kernel element for element on 1,200 cases,
refusing exactly where the kernel refuses; nine tampers, including the one
that would let a prover choose the block's output, are rejected by the
verifier. For scale: the zkVM line needed 3,743 s for the same block. Since
then (05:49) **the project's leak-checking tools have been run on the real
source** (46 of 46 counts equal the design, nothing disclosed in any opening
group or at either endpoint, all 22 negative controls fire, zero differences
from the paper run) and **an independent adversarial code review found no
blocking problem** (every hidden plane is pinned, every relation equals the
reference kernel's, it could not construct a false proof the verifier
accepts); its two small defects and its missing tamper tests were closed by
06:19, every new tamper caught exactly where it was predicted, including the
one case where only a single lookup stands between a prover and a free hidden
value; 46 unit and 4 integration tests pass on the security owner's own run,
and a receipt made before those fixes still verifies after them. **What it
is not:** not a privacy acceptance (those tools check a
linear-algebra model that leaves out several channels; the caller-fixed-root
obligation D8/D11 is open; the joint-view gate on captured receipts is
unmet), not a trained model, and **not a speed result for 8B**: the form
built here deliberately gives up the GPU feed-forward prover, and a tenth of
a second at width 16 says nothing about width 4096. Branch
`zk60-private-block`; record
`results/zk60_private_block_evidence/README.md` there.

**Codex integration, 2026-09-19:** both native profiles are now in the main
worktree. The integrated block produces a fresh 2,816,472-byte receipt in
0.062–0.064 s and verifies it independently in 0.020–0.021 s on this shared
CPU with two threads; the original lane receipt verifies too [MEASURED,
NOISY-SHARED, tiny fixture only]. Fifty-seven combined Rust tests, 29
block-inventory tests, the full Python regression (1,098 tests, 61 skipped)
and native freeze pass. Attention's repeated byte-lookup inversions are
removed and its fixture scale labels corrected. Whole-proof privacy and
model-scale speed remain open. [Integration and evidence](ZK60_ATTENTION_INTEGRATION_20260919.md).

**Verifier captures now retained:** source-pinned recordings from two fresh
attention receipts and two complete-block receipts reproduce exactly in fresh
verifier processes. They include all 18/23 slots, M and PCS openings, pads,
sampled columns, salts and paths. Forty-nine native unit tests and 13 Python
capture controls pass; both pre-instrumentation receipts still verify.
[Capture format and review boundary](ZK60_NATIVE_CAPTURE.md),
[validation manifest](../../results/zk60_native_captures_20260919/validation.json).
This closes the capture-writer prerequisite. The complete joint-view analysis
and D8/D11 still need acceptance; no new proving-speed claim follows.

**GPU optimization validated:** Claude's compact intermediate for non-hiding
openings and the parallel host column split pass the integration checks:
261 CPU Rust tests, four configurations of 34 required-device commitment
tests, 12 device cache tests, all twelve frozen CPU/GPU/forced-chunked proof
digests, and native freeze. The full Python run covered 1,140 tests (61
skipped); its single lock-related error is resolved by a test-isolation fix
and a passing 18-test targeted rerun.
The local four-kernel gain is 1.162× [MEASURED]; its full-pass saving is only
0.8–1.8 seconds [COUNTED]. No new 8B proof clock is claimed. The next host
work targets redundant integer conversion/packing and repeated reductions.
[Review and retained evidence](ZK60_FSP_L9_INTEGRATION_20260919.md).

What else exists on that line: a private feed-forward component at the same tiny shape
with a bounded privacy diagnostic (whole-proof privacy not accepted, D8
open); public-IO proofs of real 8B feed-forward stacks (below); the private
attention schedule designed and rank-checked, and its native implementation
built and reviewed at the tiny geometry as an experimental component (§3
item 1).

## 2. How slow are we against the target?

The active target is **five seconds for an 8B model on better GPU hardware**,
reaffirmed by Victor on 2026-09-22. The older written 5–15-second FFN-only
contract remains a historical component benchmark; it does not establish
completion of the private model pass including attention. Keep the 512-token
prefill workload and the p95-over-20-warm-runs, idle-machine reporting rules.
The custom prover is the speed path; the 125M CPU clocks are development data.

| What was proven | Where | Time | Distance from 5 s | Label |
|---|---|---|---|---|
| Mistral-7B, all 32 feed-forward layers × 512 tokens, **public IO**, lane AL after the host fix | laptop RTX 4070 (55–70 W) | prove **58.40 s**, verify 1.08 s, proof 1.23 GB | **11.7× slower** than 5 s, 3.9× slower than 15 s, for the proving phase | [MEASURED, NOISY-SHARED, 2026-09-04] |
| same, CPU only | laptop, 8 threads | 510 s | 100× | [MEASURED] |
| the same stack **with attention and accepted P1 privacy** | not yet built at 8B | no measurement | unknown | earlier ~290 s estimate withdrawn: the +4.7% CPU surcharge does not transfer to the GPU, and the legacy privacy profile has disclosure defects |
| one tiny complete block in the zkVM (above) | laptop CPU | 3,743 s for roughly 10^5 multiply-accumulates; the 8B FFN pass is 2.9 × 10^12 | not a performance path at all: the zkVM line is the privacy demonstrator, never the product prover (D2) | [MEASURED; COUNTED] |

The newer lane-AL result supersedes the earlier 95-second lane-AH headline.
Its retained log also records **134.50 s witness load+chain** and **196.79 s
total wall**; 58.40 s is the proving phase, not complete request readiness.
[Original measurement](../../results/hashline_convert_r3.log).

**Activation-side arithmetic (weight-commit phase subtracted).** The table
divides 512 tokens by the measured prove time minus its weight-commit phase
(Mistral-7B, 32 FFN layers, `results/hashline_zk_8b_gpu.md` §2). This is an
optimistic accounting boundary, not a measured warm-cache rate: `--wcache`
still pays validation, upload and encoding work. Its warm-path performance
must be measured on the current implementation.

| run | prove | of which commit W | activation side | **tokens/s, W phase subtracted** | with W |
|---|---:|---:|---:|---:|---:|
| public IO, laptop GPU (lane AL, 2026-09-04, host fix, cold W cache) | 58.40 s | 19.823 s | 38.577 s | **13.3** | 8.8 |
| public IO, laptop GPU (lane AH, 2026-09-04) | 95.5 s | 41.9 s | 53.5 s | **9.6** | 5.4 |
| legacy `--zk`, laptop GPU (lane AI, same day; card 8.2 GB, run paged at 8.6 GB; privacy claim subsequently invalidated) | 265.3 s | 54.2 s | 211.2 s | **2.4** | 1.9 |
| public IO, laptop CPU (2026-09-03) | 510 s | 225 s | 285 s | **1.8** | 1.0 |

Labels: [MEASURED, NOISY-SHARED] per row; the division is [COUNTED]. These
are prefill rates (512 tokens per proof), FFN-only. The legacy `--zk` row was
starved of video memory (55% of its time is one paging-bound phase). It is
not a measurement of the repaired private profile or of a larger card.
The legacy profile's known disclosure defects remain decisive regardless
of those timings. One-token-at-a-time decode is far worse per
token: a single layer at 16 tokens cost 72% of the same layer at 256 on
the CPU, so per-token cost at small batches is 10–20× the prefill figure
[COUNTED from one measurement]; no decode run exists at 8B.

A bigger GPU (a 5090 or an H100) has not been measured. The project's own
throughput model says the built design does not reach the goal on any GPU
without the recorded design changes (preprocessed weights, the two-tier
opening; `START_HERE.md` §2 and §5), and that those changes were counted,
not built. Honest summary: **on today's laptop the public-IO 8B proof is
one to two orders of magnitude off the target, and the private version of
it does not exist yet.**

## 3. What blocks a private, model-scale MVP at speed, and what is being done

1. **Private attention on the custom line: implemented and reviewed at the
   tiny geometry (2026-09-18, late evening).** A delegated Fable lane built
   the native masked prover and verifier to the construction; the security
   owner's lane compiled it with zero fixes, ran its 16 tests, proved and
   fresh-process-verified the example (0.09 s, 2.2 MB receipt), regenerated
   the rank and CFS checks on the layout it actually declares (nothing
   disclosed; H residual = the public identity; all 18 slots and 5 host
   groups pass) and re-derived the arithmetic bounds (all hold). Accepted as
   an experimental component (`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md`
   on branch `zk60-attention-compile`). Using one 8-bit range table instead
   of the 65,536-entry ones cut the commitments to 306 and 290 rows. Still
   missing for this attention-only profile: the second norm, the FFN and
   residual 2; the complete-block profile above now includes them.
   The 2026-09-19 gap inventory
   (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md` on `zk60-attention-compile`)
   sorted fifteen gaps into engineering and construction work under D12.
   The capture writer, fixture scale-tag fix and tiny-block kernel parity
   are now implemented and tested; model-width construction remains open.
2. **Whole-proof privacy acceptance on the custom line.** The joint-view
   tools exist and real native captures are retained. Their joint-view
   adapters and the caller-fixed-root obligation are still open (D8/D11).
3. **Speed.** The gap above is a design gap, not a tuning gap.
4. **Current lanes:** Fable's GPU kernels and host staging port, then a
   separately labelled repaired-mask cost probe; Codex's capture review
   handoff and remaining zkVM hardening/ceremony integration. No model-width
   GPU measurement window is reserved. The two-block token-model proof landed
   (§1). **Earlier restart/build history:** the
   laptop restarted at 01:04 on 2026-09-19**: git and the retained receipts
   are intact and everything was already pushed, but the `/tmp` scratch area
   is gone, which killed the queued ceremony checker before it ran (Codex
   relaunches it) and erased the uncommitted Opus phase-diagnostics work
   (restarts from zero). **Both Groth16 receipts were re-verified in fresh
   processes after the restart** (block and token; each profile's verifier
   refuses the other's receipt) [MEASURED]. Three read-only reviews by the
   security owner's Opus agents landed by 01:30: the token model's source
   review (no code defect; the retained build-source record is stale for
   the wrapper; hardening items for Codex), the response to Codex's review
   of the hardening lane (all six of its findings correct, four already
   fixed soundly, one new low-severity gap), and the inventory of what a
   complete private block on the custom line still needs. That inventory's
   central finding is now **ruling D12**: the two existing components may
   not be joined by sharing one hidden commitment between two proofs,
   because two openings at that geometry reveal all 512 hidden words; a
   block is one proof under one transcript, and the second norm must prove
   its output's range because the feed-forward prover does not. **At 03:01
   the design of the complete private block was accepted as the design to
   build** (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` on
   `zk60-attention-compile`): the attention construction is grown into the
   whole block, so there is no seam to prove; drafted and independently
   checked by delegated agents, with the project's rank and slot tools run on
   a paper description of the whole block (nothing disclosed; every negative
   control fires) [COUNTED on a description, not measured on code]; 22
   corrections made binding, including two that would have been soundness
   holes (a block whose output the prover could choose, and an activation
   table whose value range nothing enforced). This is a design, not a privacy
   acceptance and not a speed result. Expected size at the tiny shape: a
   2.8 MB receipt. Building started on `zk60-private-block` at 04:07;
   the initial witness-only checkpoint was subsequently superseded by the
   complete proof and its integration described in §1. Earlier items:
   the security owner's source review of `zkvm-block/` with eight hardening
   items (`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md` on branch
   `zk60-mvp-fable`), now implemented and verified on branch
   `zk60-zkvm-hardening` for Codex to integrate (secret-scan stage,
   environment refusal and scrub, cycle reporting, constant-cycle gate with a
   real executor run, tool-check command, work-directory cleanup,
   claim-shape regressions). Codex reviewed that delivery (no acceptance
   defect in the Rust; one runner incompatibility with the token profile and
   several wording and test-scope corrections, which Codex is applying). The
   ceremony checker never ran (see the restart above); no ceremony-check
   success is claimed. **Rulings made by Victor on 2026-09-19 (11:50):** D7
   accepted — the zkVM line's two receipts may now be called private under
   D3, D4, D5 and D7, with three written qualifiers (salt secrecy carries the
   32-value toy answer; the program's identity depends on its build
   directory; timing is declared leakage); D9 accepted as stated (a privacy
   residual of about 2^-72); D10 declined (the compact proof format cannot
   run privately); new D13, the hidden blocks are enough for the first MVP
   and generating a word is the next milestone; new D14, a costed memo for
   the one design lever that could take a 5090 below 10 s, paper only; and
   the RTX 5090 install is a go (date, machine and RAM still to be named).
   **Speed, honestly, as of 13:42 (`ZK60_FIVE_SECOND_PLAN.md`, three dated
   corrections at the top of its §5):** 5 s is outside every assumption
   recorded in this repository, and the costed memo commissioned under D14
   confirms the one design lever left cannot reach it (best case on a 5090
   about 7–9 s, for 15–25 lane-weeks and a 60% larger proof). The plan's three
   software steps were built today, all byte-identical and green: together
   they are worth **about 4–5 s of the 58.40 s [COUNTED]**, not the 24 s first
   projected — every counted step shrank three- to seven-fold when measured.
   On this laptop the public 8B pass is a roughly 55 s pass. Whether the 5090
   reaches 15 s is **open** until its first measurement; 16–19 s of today's
   pass is host work the card does not touch.
   **The most valuable missing number now exists, at the small shape:** the
   *repaired* private mask scheme ran for the first time above the tiny shape
   (45 runs, zero refusals, 12 layers × 512 tokens at the 125M shape, three
   arms on one binary, endpoints public in all three — a cost probe, not a
   privacy result): **repaired ÷ legacy = 1.06 on the GPU binary and 1.00 on
   the CPU binary; repaired ÷ public = 2.05 on the GPU** [MEASURED]; proof
   bytes +0.75% over legacy; by row count +1.8% at Mistral width and about
   +1.6% on a Mistral layer [COUNTED, not run]. So the repaired masks cost
   what the legacy ones did, within a few per cent; what is still unmeasured
   is the other half of P1, the hidden endpoints at model width.
   **Privacy path, same day:** on Codex's retained captures of two block and
   two attention receipts, a gate that replays the transcript at the
   receipts' real challenges finds nothing determined about the hidden data
   beyond public identities, with the 256 sampled columns included, and every
   sabotage control caught — evidence on a linear model of four receipts,
   **not** a privacy acceptance (D8/D11 open); and the private block's norm
   was shown free of the soundness gap the older prover has, with the
   precondition for widening it recorded as D16.
5. **A reproducibility fact to settle before any approval record:** the
   guest image ID depends on the build directory (the ELF embeds one
   absolute source path and the non-Docker build applies no path remap), so
   the approved ID `8d74aab3…98d9` is reproducible only from the main
   checkout's path or from a reproducible Docker build.

## 4. Where the evidence is

Public artifacts of today's Groth16 receipt are retained under
`results/zk60_loop_20260918/block-integration/groth16_public/` (policy,
receipt, public model, stage records, hashes); the `/tmp` originals do not
survive a reboot and a new randomized receipt would have different bytes. The loop's own
record is `ZK60_MVP_LOOP_20260918.md`.

## 2026-09-29 (PDT): VC readiness snapshot for Tech Week SF

Added 17:40 PDT on 2026-09-29 (00:40 UTC on 09-30) by the Lane D agent.
This section repeats the facts in
[`results/zk60_vc_readiness_20260929/READINESS.md`](../../results/zk60_vc_readiness_20260929/READINESS.md).
That note also has a one-page `DEMO_SCRIPT.md`, the projection arithmetic
(`extrapolate.py` → `extrapolation.json`) and a light rehearsal script. No
heavy proof ran. Nothing in this section is a new ruling or privacy
acceptance.

**What can be shown truthfully now.** Everything below was re-checked on the
laptop CPU between 17:18 and 17:24 PDT (`rehearsal-20260930T002413Z.json`):
- Both retained 785-byte Groth16 receipts verify in fresh processes, with
  exit 0 in about 0.08 s each including the wrapper. One is the tiny complete
  block; the other is the synthetic two-block token model.
- A one-bit-flipped copy of the block receipt is refused.
- The toy native private block (the D22 profile) proves in 0.10-0.11 s.
  A fresh process verifies it in 0.05-0.06 s and refuses three corrupted
  copies [MEASURED].

Before quoting D22 on stage, confirm that the 2026-09-20 example binary
matches D22's source pins. The integrator's browser demo
(`ZK60_TECHWEEK_DEMO.md`) is the stage vehicle for these checks.

The scale evidence is unchanged:
- One synthetic 125M-geometry block: 17.13 s GPU-arm proving versus 32.95 s
  on a 2-thread CPU.
- The twelve-block 125M-geometry run: 397.71 s on CPU, or **1.29 proved
  tokens/s**. This is the only measured complete-stack rate: synthetic
  weights, CPU, one run.
- A twelve-block GPU attempt today (`results/zk60_mvp_20260929/baseline-stack-gpu/`)
  failed at harness setup because its receipt directory was missing. It was
  not a proof failure.

**Projection, labelled [MODEL].** Each measured phase of the 125M A/B is
scaled by its own layout domain. This gives 2.18x per block at the TinyLlama
1B geometry and 3.09x at the Llama-3-8B block geometry. Plain row counts give
2.25x and 3.25x. Prove-only rates for 512 tokens:

| Configuration | Stack prove | Proved tokens/s |
|---|---:|---:|
| 1B, 22 blocks, laptop GPU arm | 822 s | **0.62** |
| 8B, 32 blocks, laptop GPU arm (does not fit this laptop) | 1,692 s | **0.30** |
| 8B, RTX 5090 with today's code | — | 0.62-1.23 |
| 8B, 5090 with every proof sumcheck on the GPU (not built) | — | 5.1-12.6 |
| 1B, 5090 with every proof sumcheck on the GPU (not built) | — | 10.5-26.1 |

The witness build must also move to the GPU. At 8B it is 27-285 s per block
on CPU [MODEL band]. The gap to 50 at 8B is 165x on the laptop today and
4-10x in the best counted scenario. **No recorded assumption reaches 50
proved tokens/s for a private 8B stack.** Larger workloads amortize under 1%
today, because per-token proof work dominates.

**Claims to avoid** are listed in READINESS §3. In short: no full or trained
model has been proved privately; no private rate exists at 1B or 8B; D22
covers only the CPU toy; the 97-bit, Groth16-setup and unreproduced-image
qualifiers travel with the 785-byte receipts; the fast line's receipts are
about 41 MB per 125M block; there are no 5090 numbers; and there has been no
third-party audit.

**Next measurements** (the READINESS §4 week plan, aligned with the
integrator's gates):
1. Retry the twelve-block 125M GPU run.
2. One synthetic TinyLlama-geometry block on the 4070. It is projected at
   37 s, and the counted floors are about 3.7 GiB VRAM and 6.9 GiB host.
3. The 22-block 1B-geometry run.
4. Laptop thread scaling.
5. The first 5090 A/B, only if Linux is installed by about 10-02.

The trained TinyLlama block is the integrator's 10-02 stretch gate.
