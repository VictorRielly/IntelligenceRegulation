# ZKP efficiency progress

Cycle0046 — `20261013T032555Z-3e60f70b`, checkpoint 2026-10-13T03:44:35.945641+00:00 UTC.

**Bounded pair-helper fallback passes synthetic checks; no proving speed gain
measured.** The cycle0004 exact-pair inverse cache now uses bounded batch
fallback for invalid pairs and writes directly to split H planes. Short columns
skip setup.203 fixtures,669 schedules,81968 independent helper words,44 modeled
attempt schedules,32 table-helper checks and21 controls pass. Runtime0.761940s/
31000KiB RSS on one low-priority Core Ultra9 CPU thread; no native/GPU proof.

For257 invalid pairs atK1024, inversions fall from prior258 to2, versus native1;
extra cache work remains. Conditional native m125 denominator+prefix logical
peak128MiB becomes about45KiB scratch plus2KiB activation conversion. This is
payload accounting, not measured peak. Sparse invalid words still incur an
inversion per occupied chunk. All full-table zero refusals, future/padded
attention positions and fresh proof challenges remain.

The refreshed native one-block helper phase is0.197s. Even deleting it entirely
bounds savings to0.716% of27.523873s historical test wall; dominant SC_SZC7.794s
and witness work remain. The [experiment](experiments/lookup-reciprocal-plan-20261013/README.md)
and [low-priority handoff](handoffs/20261013-bounded-pair-inverse-fallback.md)
retain commands, code/source hashes, costs, controls and uncompiled Rust sketch.

LIVE searches inspected Plonky3 chunk-local LogUp source/current release
listings/Sep22,2026 obligation review, a newly assessed older MLE lookup paper
and original LogUp metadata. Four qualified records added; commit/PDF/history
fetch failures, unknown HEAD/update dates and unverified release year recorded.
No author performance reproduced or downloaded code executed.

Accepted independently verified complete private8B proofs/passes/tokens:**0**.
Proof context none, device CPU only. Steady/total-workload rates, startup
seconds/fraction, witness/proof/serialization/independent-verification and
latency/lag/drain clocks unmeasured. No long-context prefill, resident passes
or decode proof ran. >=50/s remains unachieved; larger workloads allowed,
quadratic attention, full coverage/privacy and fresh masks remain required.

Next local: source-derived SC_SZC row polynomial coefficient evaluation versus
repeated full-extension bracket products, counting prep/scratch and actual
sample1 recovery/fallback. Owner: dominant SC_SZC and both witness clocks;
only consider this memory candidate after native masked/frozen/refusal/lifetime
and fresh independent verification gates, then shared-lock peak/enclosing A/B.
No production/runtime/Git write, heavy/GPU job, installation or external message.
Saved reports are not evidence of notification delivery.
