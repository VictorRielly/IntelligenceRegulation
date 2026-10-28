# Public PCS preprocessing incidence — cycle 0115

Run `20261020T231854Z-2da27679`, 2026-10-20 UTC. No proving speedup measured.

The device's NTT twiddles already use a process-wide, monotonically growing
cache. Cycle 0084 established this; inspection of the separately pinned active
GPU and reviewed R9 source confirms it. Caching these roots again removes no
upload. Opening-index plans depend on the current transcript's sampled columns
and cannot be reused by shape alone.

A different public object recurs: `coset_powers(h, nn)` is built at every
hiding PCS commitment, uploaded at every accepted GPU hiding commitment, and
retained separately by each deferred `ZkReenc`. The CPU-only CFS commitment M
also builds its own 4096-entry public powers. This experiment tests an immutable
public owner and counts its potential effect. It does not change any native code.

For the source-backed 32-layer T128 scheduling skeleton, there are 2 external
endpoints, 31 internal boundaries and 64 A/H hiding offers. There are also
32 CPU M commitments. All main domains have 65536 columns, distinct from the
128-token context. Conditional counts assuming all 97 hiding offers take the
GPU path:

| Fixed-context trace passes | Baseline powers uploads | Cached powers uploads | CPU public-power builds, baseline / cached |
|---:|---:|---:|---:|
| 1 | 48.5 MiB | 0.5 MiB | 129 / 1 |
| 2 | 97 MiB | 0.5 MiB | 258 / 1 |
| 4 | 194 MiB | 0.5 MiB | 516 / 1 |
| 8 | 388 MiB | 0.5 MiB | 1032 / 1 |

These are synthetic request traces, not completed passes, observed launches,
physical traffic or timings. GPU admission/declines must be measured. Active
GPU source and reviewed R9 private profiles are separately pinned; their
combination is not asserted to be an admitted GPU profile. No T512 profile is
assumed. The DD and non-DD A/H role counts are the same, but their other costs
are not equated.

One pass builds 6,488,064 public field powers without caching versus 65,536
with this public owner. Each source-loop iteration includes a multiplication;
this is an operation count, not compiled instructions. A cache hit adds a key
lookup, reference lifetime work and a requested-domain validity check. An
immutable replacement on growth can retain both old and new allocations.

In the fully deferred schedule, the selected device powers peak is 2.5 MiB
without sharing and 0.5 MiB with sharing. A fully resident schedule has a
0.5 MiB selected powers peak in either case; the cache retains 0.5 MiB at idle
where the original retains zero. A separate 0.5 MiB host owner is needed.
These selected arrays exclude private pads, data, encoded matrices, masks,
histograms, pooled/idle capacity, driver allocations and transfers. This does
not establish a capacity cliff or actual HWM. Evicting between eight passes
requires eight uploads rather than one. Eviction never invalidates live leases.

Every private pad, salt, mask and proof operation remains fresh per proof.
The unchanged counted salt stream is 207,618,048 bytes per T128/L32 trace,
including M; pad words remain `sum(rows * q_pad)` and were not numerically
censused. This is a source count, not sampled production randomness. Test pads
and salts come from a deterministic synthetic PRNG and provide no privacy proof.

`probe.py` uses a native-style radix-2 Goldilocks encoder and an independent
quadratic interpolation/Horner reference. Its 192 synthetic rows, 7392 encoded
positions and 286 assertions pass. Random, zero, one, monomial and field-edge
messages cover lengths 2..32, rate 2/4, different q and cosets 7/11. Fifteen
control families cover mutation, wrong coset/order, fresh private draws, growth,
eviction and device/context/representation identity. The source helper accepts
h=0; that behavior is preserved here without asserting profile admission.
A coset with order 32 accepts a 16-entry request but refuses a 32-entry request.
This catches caching away a refusal when capacity grows.

`census.py` passes 1442 assertions across 145 synthetic schedules and 22 source
fragments. `audit.py` imports neither producer: independent explicit polynomial
coefficient evaluation and a separate live-lease oracle pass 92,531 assertions,
50,240 capacity events and 21 source/prior pins. The 32+64-byte growth example
peaks at 96 bytes, stays live after eviction and releases only with its leases.
These are arithmetic, source and lifetime checks, not Rust/CUDA, transcript,
leaf-hash, native refusal, privacy-gate or saved-proof verification tests.

Final research clocks: probe 0.393082 s / 18,052 KiB RSS; census 0.211661 s /
84,740 KiB; independent audit 0.830058 s / 72,684 KiB. One nice-19 worker on the
first allowed core, Intel Core Ultra 9 185H, Python 3.10.12, WSL2. Each child has
59-second CPU/alarm, 60-second parent and 512 MiB address-space limits. Revised
memory estimates are 128 MiB for census/audit, 64 MiB for probe; initial 64 MiB
estimates were low but no cap was reached. Commands, raw stdout/stderr, seed
20261020115 and source hashes are retained. Earlier passing results and
development corrections are preserved.

Expected full-workload effect is unknown. For exclusive affected fraction f,
even free deletion has ceiling `1/(1-f)`, before cache/validation/capacity costs.
For fixed-context resident workloads `time(R) = startup + R * recurring + drain`;
amortization cannot exceed `context / recurring`. Neither startup nor recurring
GPU clocks are measured here. A cache miss, eviction or larger context changes
that accounting; increasing context can increase attention quadratically.
Reject promotion on changed bytes/refusals/lifetimes, stale keys, material
retention cost, or no enclosing benefit. Rank 28 remains below whole-GPU work,
DD fidelity/context scaling, complete phase/capacity clocks and FZC A/B.

Six native LIVE queries yield nine primary records. The ICICLE domain contract,
current release/commit and October-16 Chimera revision were refreshed. Newly
screened older OpenNTT is an FPGA/FHE processing-order lead, not a CUDA plug-in.
Its paper dates, MIT body, PDF 403 and unavailable commit/date are recorded.
All author performance claims remain unreproduced. See `source-records.json`,
`search-log.json`, `hypotheses.json` and `queue.json`.

New completed independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. Witness, proof,
serialization, verification, startup duration/fraction and steady-state /
total-workload proved rates: **unmeasured**. No long-context prefill, resident
model proof series or decode ran. The complete private 8B >=50 proved tokens/s
target on RTX 5090 or another named high-end GPU remains unachieved.

Only research artifacts excluding runtime were written. No production, reviewer,
calibration, instruction, Git or receipt edits; no native build, GPU, dependency
installation, downloaded-script execution, external write/message or escalation.
Main/Claude reviews and integrates; no merge. See the research handoff.
