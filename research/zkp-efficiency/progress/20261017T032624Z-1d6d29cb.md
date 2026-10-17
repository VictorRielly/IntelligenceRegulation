# ZKP efficiency progress

Cycle 0053 — `20261017T032624Z-1d6d29cb`, checkpoint 2026-10-17T03:37:07.491122+00:00.

**No native improvement established.** Corrected optional Ht/S padding
supports and unpadded sample widths in the research model. The CPU experiment
passed 600 schedules, 5,520 independent round samples, 14,532 final values and
384 extension clause checks. It took 16.31 seconds and 25,428 KiB RSS on one
low-priority Core Ultra 9 thread. No native proof or GPU job ran.

At full heads and T512, the corrected three-limb bracket count is 37.57%
below the old always-padded formula. Native already omits that work: this
corrects the estimate and establishes no speedup. Padded-case counts stay
the same. The current factory policy selects no coefficient group on the
full-domain branch, so earlier padded gains cannot predict an 8B gain.

Next local test: a separate four-coefficient unpadded factory. Charge
construction, reduction, Horner evaluation, setup, dispatch and scratch
against repeated scalar evaluation; preserve samples, claims and refusals.
Main/Claude next: native profile/privacy gates, then guarded SC_SZC, both
witness paths, peak memory and complete workload clocks.

LIVE search examined SpaGKR, GoQuant and Plonky3 jagged authentication with
the October 16 release, plus cache/coverage refreshes. Five source records
retain dates, license scope and failed fetches; author claims are unreproduced.
The final artifact audit passes 144 integrity/accounting checks.
[Experiment](experiments/optional-support-port-20261017/README.md) and
[owner note](handoffs/20261017-optional-support-port.md) retain commands,
source pins, controls and superseded local modeling attempts.

Accepted complete private 8B proofs/passes/tokens: **0/0/0**. Device: CPU only;
proof context unmeasured. Steady-state and total-workload rates, startup
duration/fraction, witness/proof/serialization/independent-verification clocks,
and latency/lag/drain remain unmeasured. No long-context prefill, resident-model
pass or decode proof. The >=50-token/s target is unchanged and unachieved.
Larger workloads remain allowed with quadratic attention, fresh masks and
complete coverage/privacy.

No production/runtime/Git/heavy/GPU/install/external actions. Saved reports
do not establish message delivery or job liveness.
