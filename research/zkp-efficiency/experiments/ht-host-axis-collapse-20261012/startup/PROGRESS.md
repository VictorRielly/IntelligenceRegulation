# ZKP efficiency progress

Cycle 0041 — `20261012T222555Z-e2cb7a5e`, checkpoint 2026-10-12T22:39:09.061813+00:00.

**A per-proof equality suffix cache passes synthetic checks; no native proving
improvement was measured.** The bounded run took 9.878 seconds and
22,480 KiB RSS on one Core Ultra 9 CPU thread. It tested 184 suffix fixtures,
32 SC_SZC fixtures, offset supports, actual group recovery, zero factors,
ordered finals and extensions. All 16 negative controls pass.

At the conditional T512 geometry, preparation falls from 41,598 to 12,532
multiplications. That removes only 0.2302% of preparation-plus-weight counts,
before brackets and other work, and adds 100,256 bytes of logical peak storage.
These are counts, not timing gains. The candidate is demoted as a major lever.
Native cache locality, enclosing costs, masked transcripts and privacy remain
untested. GPU sumcheck and recurring witness work retain higher priority.

[Experiment](experiments/split-eq-suffix-cache-20261012/README.md) and
[owner handoff](handoffs/20261012-split-eq-suffix-cache.md) retain commands,
logs, source pins and an uncompiled Rust sketch at GroupedEqRounds. Five LIVE
primary records were added: Akita, BDDT, Dao/Thaler and newly assessed older
Libra. Exact dates, commit/license limits and Cache miss/403 fetches are saved.
No native build, GPU job, production edit, installation, Git or external message.

Accepted independently verified complete private 8B proofs/passes/tokens: **0**.
Device: CPU only. Proof context: null; passes: 0. Steady-state and total-workload
rates, startup duration/fraction, witness/proof/serialization/independent
verification and latency/lag/drain clocks are unmeasured. No long-context
prefill, resident-model pass or decode proof occurred. The >=50 proved-token/s
target and full privacy requirements remain unchanged.

Next local: test trailing-token repetition in the lifted Ht host group, with
source provenance, off-domain/extension checks and sabotaged lifts. Next owner:
measure dominant phases and finish native masked gates; time cache preparation
before considering this small port. Saved reports do not imply message delivery.
