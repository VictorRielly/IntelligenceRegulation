# ZKP efficiency explorer — durable state

Cycle 0066 COMPLETE: `20261017T192105Z-c342a26b`.
Final checkpoint: 2026-10-17T19:35:01.104980+00:00. Next cycle no earlier than 2026-10-17T20:21:05Z.
AGENDA, target, durable/project memory and latest three results consulted.
Startup snapshots: `experiments/lookup-helper-staging-20261017/startup/`.
Prior ledger bytes preserved; five LIVE source records added, 342 total.

No proving speedup found. The active F device builder already reads resident
A/H. This cycle tested the earlier U8 H producer at the integer/field boundary.
A-only field evaluation cannot reproduce all old wrapping-i64 behavior:
-2^63 and p-2^63 have identical A but different scale-2 helpers. Both directions
of local denominator-refusal status change occur. These are malformed internal
witness controls, not an accepted-proof forgery or an admissible-input attack.

A private ambiguity bitmap plus unsigned wrapping reconstructs the old words.
Two signed preimages occur iff the residue lies in [p-2^63, 2^63), an interval
of 2^32-1 residues. Identity denominators need no bit. Bits are per-proof private
memory and must never enter receipts/captures or cross-proof caches.

48 catalogs / 288 domains / 4,176 columns / 106,962 field words match.
35 H fixtures / 2,436 Fp2 values, five refusal cases and 12 main controls pass.
Initial codec test: 86,029 entries, including all int16 values; 7,294,208 visits
include repeated FFI fixtures. Independent audit: 5,375 checks, 700 extension
outputs and two actual bit-index mutations. Main 4.336897 s / 29740 KiB,
compiler 133848 KiB; audit 0.192148 s / 17664 KiB.
CPU 0, Intel Core Ultra 9 185H, one thread, nice 19, seed 2026101766;
59-second / 512-MiB limits. Std-only Rust source harness, no native crate or GPU.
Compiler temporary files use the experiment's tmp directory. Native failed
buffers, Rayon, transcript/RNG/PCS/masks/receipts/privacy remain untested.

Unapplied handoff: `handoffs/20261017-resident-helper-integer-boundary.md`.
Prototype, captures, logs, commands, hashes and controls:
`experiments/lookup-helper-staging-20261017/`. Existing device-H commitment is
untagged with incomplete host helper rows. Tagged ownership and host-reader
coherence, or explicitly charged D2H/H2D, are prerequisites. No native patch.

Counted earlier TinyLlama T128: looked payload 221.25 MiB; prior borrowing
leaves 53.75 MiB; bitmap 0.609375 MiB; U8 H output 235.25 MiB remains.
These are not peak/traffic/timing measurements. Whole-U8-phase deletion ceilings:
1.057799× GPU-assisted (8.844 / 161.857226 s), 1.041052× CPU (6.911 / 175.258632 s),
from earlier 1.1B T128 cold diagnostics. Candidate retains arithmetic and adds
packing, recovery and transfers. Actual 8B U8/F subclocks are absent.
The captured owner ledger records successful device-body fixtures, then a
failed seeded-test header and queued successor gates. No new complete receipt
or enclosing speed gain inferred from that ledger; no liveness claim.

Carried owner functional 8B: 8,030,261,248 parameters, 32 linked attention+FFN
blocks, T32, one cold pass per CPU / RTX 4070 Laptop arm, 16 threads.
Process 384.542564 / 391.287091 s; diagnostic 32/process rates 0.083216 / 0.081781
include in-process checking. Witness 18.629 / 18.109 s; inclusive proving
208.019 / 213.831 s includes reload 79.222 / 77.997 s; remaining 110.168 / 117.725 s
includes serialization/sink. Partial load+seal startup 21.595% / 20.341%.
Full startup, steady slope, isolated serialization/proof latency, lag/drain are
unknown. Fresh check 96.103 / 90.935 s plus initial load 80.675 / 78.635 s.
Receipt 465,815,776 bytes. D24 round 3 accepts 8B-profile soundness (18:36 UTC);
shape privacy remains open; later R5/GPU changes need their own gates.
No resident repeat, long prefill or decode measurement. New target-compliant
proofs / passes / positions: 0 / 0 / 0.

Ranked hypotheses:

1. OWNER whole-prover GPU: highest potential, high integration cost. Eliminate
   measured recurring work; charge setup, scratch, launches, transfers/drain.
   Any native bytes/refusal/privacy mismatch or no enclosing gain falsifies.
   Earlier whole masked-F deletion ceiling is 1.113184× on one 1.1B diagnostic;
   no 8B/5090 factor follows from fixture timings.
2. OWNER immutable public-model residency: about 80 s initial loading plus
   recurring reloads. Add RAM/identity/invalidation; no fresh-pass slope exists.
   A mutation surviving a cache hit, memory failure, or >20 ms recurring work
   per newly proved position falsifies the relevant correctness/50/s claim.
   No mask/private opening reuse.
3. TESTED resident U8 producer: secondary capacity candidate. Exact private
   codec passes; A-only shortcut fails. Adds bitmap/coherence costs. Reject on
   native word/refusal/RNG/byte mismatch; no peak/enclosing benefit rejects
   its proposed capacity/speed gain. Native gain and 8B attribution unknown.
4. NEW older Logup* architecture: native looked arrays are already uncommitted,
   so no additional query commitment may be deducted. Cost actual H displacement,
   new GKR/PCS, terminal binding, masking and joint view. Prior fractional-tree
   D/C leakage and whole-table zero-denominator negatives remain binding.

Next local: bounded Logup* pushforward privacy/binding audit, small odd/padded
query vectors, unmasked-disclosure control and original denominator schedule.
Count actual displaced H terms and added commitments; no adoption assumed.
Next owner: review gate and measure complete device/enclosing workloads under
shared locks, native/fresh-verifier/privacy gates. No heavy/GPU job queued here.
The >=50/s high-end-GPU target stands. Larger workloads may amortize setup with
fresh masks; resident contexts, long prefill and decode remain distinct;
dense attention can grow quadratically with context.

Research edits only, excluding runtime. No production/Git/receipt/calibration/
instruction/reviewer edits, installs, downloaded code execution, external
messages or escalation. Full report: `progress/20261017T192105Z-c342a26b.md`.
Saved reports do not establish user-message delivery.
