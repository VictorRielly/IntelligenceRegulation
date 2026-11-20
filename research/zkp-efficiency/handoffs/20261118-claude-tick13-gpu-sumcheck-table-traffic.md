# Research handoff: published GPU sumcheck designs that cut table re-reads, set against H133 (2026-11-18 UTC, claude-tick 13, queue item 28)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** Tick 12 found the shipped later-round zero-check kernel is not limited by multiplications. Antigravity's H133 (`results/zk60_slot18_14_breakdown_20261117/README.md:110-113`) proposes a single fetch of each pair per SIMD group plus a fused fold-then-evaluate, and models a 50 to 70% cut of DRAM traffic in rounds 0 to 3. Is there a published GPU sumcheck design with a measured gain on bodies of 30 to 70 tables that either supports or limits that number?

**What was read and how.** 6 searches, 10 page requests (3 failed: the ePrint PDF host returned 403, the DATE proceedings returned 404, the PipeSC page text was abstract-only). Read as full text: Ingonyama's ICICLE sumcheck post (summary by the fetch tool), the Ingonyama "Hardware Friendliness HyperPlonk Part 2" note (summary), Binyi Chen's no-repeated-IO note (summary), the ligerito GPU sumcheck source page (host side only), the Apple-silicon WHIR write-up (summary). Abstract only: Chimera (ePrint 2026/1388), PipeSC (ePrint 2026/691), SumCATS (DATE 2026, via search snippets and the abstract listing). Local: the breakdown README section 4 and tick 12's handoff. All summaries came through a small model, so wording below is theirs, not verbatim.

## 1. Findings

**1.1 "zkDuel" does not resolve.** Two searches (the name alone and with "GPU sumcheck") returned no paper, repository or post by that name. The queue item's citation is unverified and I cannot report any number for it. Someone who knows where the name came from should give the URL.

**1.2 The fused fold-and-evaluate design is the published baseline, not an extra.** ICICLE's CUDA sumcheck, by Ingonyama's own description, "computes both the folding from the previous round and the round polynomial evaluations for the current one" in one pass and does "only the memory operations strictly required for folding"; round 1 only evaluates [authors' description, summary]. They give no byte counts or speedup for the fusion itself. So the second half of H133 (fuse `fold_tab` into the next round's load, `metal.rs:4030-4055`) matches what a 2025 production GPU sumcheck already does; no published number says what it gains over a separate fold pass.

**1.3 Memory-bound, on a different GPU and a small body.** Ingonyama profiled the CUDA kernel with Nsight Compute on an NVIDIA L4: 4 polynomials of size 2^25, body EQ(AB-C), first 13 rounds. Memory throughput is near peak in the early rounds; compute throughput roughly doubles from round 1 to round 2 and only falls once memory throughput is below 60%; the stated conclusion is that the bottleneck is memory access, not computation [authors' profile]. This supports the direction of tick 12's finding (arithmetic is not the limiter) and gives outside support for Antigravity's "early rounds are bandwidth-bound". It is 4 tables with an L4 (hundreds of GB/s class); our slots have 29 to 68 tables on an Apple GPU, so it is not a measurement of our case.

**1.4 Chimera (ePrint 2026/1388, abstract only).** Hybrid CPU-GPU sumcheck for the Spartan R1CS prover (BN254): data stays resident on the GPU across rounds, only compact round values go to the CPU, small late rounds run on the CPU. Standalone quadratic GPU sumcheck at N = 2^22: 28.7 ms against 84.2 ms for ICICLE's CUDA sumcheck, 2.94x [authors' number]. The abstract does not say which design choice gives the 2.94x (the host/device transfer pattern, not table re-reads, is the one named). Full text not read (PDF fetch refused); body is quadratic, so it says nothing about 30 to 70 tables.

**1.5 SumCATS (DATE 2026, binary towers).** Abstract-level only: shared-memory optimisation and precomputation to cut global accesses; 1.81x over Binius-GPU on an RTX 3090 Ti, 1.62x on an A100 [authors' numbers, from the search listing]. Binary-tower fields, not Goldilocks; full text not read (404). A separate vendor claim: a hardware carryless-multiply instruction gives 3 to 4x on an RTX 5090 for binary-field sumcheck [vendor, snippet]: irrelevant to Goldilocks.

**1.6 Things that do not fit the transcript-preserving constraint.** Binyi Chen's note replaces the per-round read-and-write of the table by a streamed first pass that sums over an extra variable Y of degree K and then keeps only N/K words, total work about (1 + 2/K)N, with no later main-memory traffic [author's analysis, no benchmarks; aimed at FPGA/ASIC with small SRAM]. That changes the claim being sumchecked and the verifier (it adds K evaluations to check), so it alters proof bytes: owner ruling, new profile version, Lean re-proof. Not a kernel change; listed for completeness only.

**1.7 Apple silicon, one data point.** A Metal WHIR prover write-up keeps sumcheck on the CPU (about 80 ms of about 537 ms at n = 24, 5 to 15 ms per round) and never builds a GPU sumcheck; it did observe that CPU reads overlapped with GPU work competed for unified-memory bandwidth [authors' observation]. No published Metal sumcheck with table-traffic numbers found (ICICLE has a Metal sumcheck backend; no figures found).

**Not found:** any published GPU sumcheck with 30 to 70 tables in the body, any measured gain from evaluate-all-points-per-thread, and any shared-memory tiling result for a prime field of this size. So H133's 50 to 70% is a model with no external measurement behind it.

## 2. Setting H133 against its own and tick 12's numbers

DERIVED (arithmetic, not run). Let N be the bytes of the live tables at the start of a round.

- Today (per the breakdown README): evaluation reads about e x N, where e is the fetch multiplicity, then `fold_tab` reads N and writes N/2: **(e + 1.5) N**.
- Antigravity's premise is e = 4 to 5 from DRAM (np = 5 at j = 0, np = 4 later). Tick 12's logical-to-distinct load ratio for the benched kernel is **3.0** (856/285 MB and 1.66 GB/554 MB), and those logical loads need not all reach DRAM if neighbouring threads hit in cache.
- Fused fold-eval alone, e unchanged: (e + 0.5) N; for e = 3 that is 3.5N against 4.5N, a **22% cut**; for e = 4.5, 17%.
- Single fetch alone, fold unfused: (1 + 1.5) N = 2.5N, a 44% cut at e = 3 (58% at 4.5).
- Both: 1.5 N, a **67% cut at e = 3, 75% at e = 4.5**.
So a 50 to 70% cut requires both halves and requires the extra fetches to be real DRAM traffic. The first requirement is plausible; the second is not shown. Distinct-data rates from the breakdown README's own times and sizes: slot 18 j = 0, 608 MB in 6.377 ms is 95 GB/s distinct; j = 1, 352 MB in 4.730 ms is 74 GB/s; slot 14 j = 0, 184 MB in 3.546 ms is 52 GB/s. At the claimed multiplicities these would be about 300 to 480 GB/s of DRAM traffic. Whether that is "100% saturation" depends on the achievable bandwidth of the M3 Ultra GPU, which I did not look up and which the breakdown README states without a counter reading. ASSUMED: sustained GPU bandwidth well below the headline peak.

The one check that separates the models is tick 12's K1 (the roofline with a trivial body), plus a DRAM-byte reading from a GPU counter capture (Xcode / Metal counters) for one round; I did not verify that these counters expose DRAM bytes on this machine.

## 3. Falsifiable tests (project terms, nothing run)

- **F1, fused fold-eval alone.** In `kbench`, add a variant of v13 that reads the previous round's table and the challenge and writes the folded table while evaluating (one read of N, one write of N/2), against v13 followed by the separate fold pass, both timed with GPU timestamps on the slot 14 and slot 18 dumps. **Pass: at least 15% below the two-pass total on both, with bit-identical `part` buffers and folded tables** (the host replay refuses any difference). Fail: under 8%: then the fold is not the traffic that matters.
- **F2, single fetch.** Tick 12's K2, unchanged. Together F1 and F2 give the predicted cut for the two halves separately, so the 50 to 70% model can be checked in pieces: predicted 22% and 44% at e = 3.
- **F3, counter read.** DRAM bytes moved by one round-1 dispatch of v13 against the 856 MB and 1.66 GB logical loads. If measured DRAM bytes are within about 1.3x of the distinct data (285, 554 MB), the extra fetches are cache hits and H133's single-fetch half buys almost nothing; if near the logical loads, it buys the modelled amount.

## 4. Honest expected effect

- **Committed words per request: none.** Same field elements, same transcript, same proof bytes, no verifier, profile or Lean change (kernel-only, as tick 12 argued). Binyi Chen's variant, section 1.6, would change bytes and is excluded.
- **Proved tokens per second.** Antigravity's model gives 3.74 s to 3.35 to 3.50 s per request on `serve4` (about x1.07 to x1.12 on cadence, ratio DERIVED from their numbers; their estimate, MODEL). I cannot confirm or refute it from the literature: no outside measurement exists for this body size. Using section 2, a cut of only the fold pass (the published-baseline half) gives about a fifth of the traffic of rounds 0 to 3, so the lower end (about x1.04 to x1.05 if their model's traffic share holds) is better supported than the upper end. This is DERIVED, not measured.

## 5. Risks and what was not verified

- All page content passed through a fetch tool's small model; no page was read verbatim, and Chimera, SumCATS and PipeSC were read at abstract level only. Their numbers are authors' claims on different fields, GPUs and bodies.
- "zkDuel" unresolved. I did not look at ICICLE's source for the fused kernel's shape beyond the vendor post, nor whether its folding keeps the previous table or recomputes from two rounds back.
- Apple GPU sustained bandwidth, SLC size and counter availability not looked up.
- The e = 3 figure is tick 12's own load-count ratio for one round of the benched kernel; the real shipped slots may differ (np = 5 at round 0, base-field tables of 8 bytes).
