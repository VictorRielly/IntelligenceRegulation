# ZKP efficiency progress

Cycle 0054 — `20261017T042624Z-0f7bf604`, completed 2026-10-17 UTC.

**No native speed improvement established.** An unpadded cubic evaluator
restricted to the first sumcheck round passed 1,890 synthetic schedules,
19,650 independent round samples, 43,920 final values and 144 extension checks.
Five mutation controls caught errors; zero-factor fallbacks and 20 operation
census comparisons passed. The final run took 10.05 seconds and
22,184 KiB RSS on one low-priority CPU thread.

For full heads at T512 with three limbs, the candidate counts **7.02% fewer
field API operations** than scalar evaluation with prepared lookup denominators.
This is a limited arithmetic result, not a proving-time measurement. Applying
coefficients after running-claim recovery adds costly multiplications, so the
broader policy is demoted. The first round recurs on every proof; it is not
reusable startup work.

The candidate adds coefficient construction, Horner evaluation, public dispatch
and temporary storage. Its four output coefficients occupy 64 logical bytes;
native register and scratch costs remain unknown. Next local action: generate
a fixed factory and audit its lifetimes. Main/Claude next: native masked,
refusal, RNG, PCS and independent-verifier gates, then guarded three-arm timing
and complete resident-workload measurements. The seam is SC_SZC in
`argument.rs` and the row/part/sample/recovery loop in `grouped.rs`.
Candidate and sonnet-hardening source pins match. No native build or GPU job ran.

LIVE searches covered Dory's older paper and August 2026 release, EPFL's
coefficient evaluator, Fold-DCS, ICICLE, NVIDIA carryless arithmetic and
October 16 Plonky3 hash metadata. October FAEST primary/PDF access and several
license/commit fetches failed; exact blockers are retained. Seven source
records were appended, bringing the ledger to 276. Author performance and
security claims were not reproduced.

[Experiment](experiments/unpadded-cubic-factory-20261017/README.md) and
[review handoff](handoffs/20261017-unpadded-cubic-round0.md) retain commands,
seed, source hashes, dimensions, controls, counts and limitations.

Accepted independently verified complete private 8B proofs/passes/tokens:
**0/0/0**. Proof context: unmeasured. Device: Intel Core Ultra 9 185H CPU only,
one thread, nice 19. Steady-state and total-workload rates, startup duration
and fraction, witness/proof/serialization/independent-verification clocks, and
proof latency/lag/drain are **unmeasured**. No long-context prefill,
resident-model pass or decode proof ran. Synthetic tests use at most 32 cells;
T512/T1024 counts allocate no model-sized tables. Doubling context quadruples
the modeled attention work. The >=50-token/s target remains unchanged and
unachieved; larger workloads remain allowed with fresh masks and full coverage.

The final integrity/accounting audit passes 445 checks. Its initial assumption
that every historical source record had an id was corrected: five old records
omit it. The failure is retained; historical records were preserved and the
seven new ids checked. This audit is not a native proof or performance gate.
No owner memory file changed during the cycle. Production, runtime, Git,
calibration and reviewer files were untouched. No installation, external
message or merge occurred. Saved reports do not establish delivery or liveness.
