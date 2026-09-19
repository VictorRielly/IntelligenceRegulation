# Native attention and complete-block integration — 2026-09-19

Codex integrated Claude's reviewed attention delivery (`ea81815`) and, after
the overnight handoff became available, the complete tiny-block delivery
(`98a5db9`) into the main worktree. Neither is whole-proof privacy acceptance,
an approved trained model, or a five-second model-scale proof. This work
continues the full MVP goal; it does not replace that goal with a tiny fixture.

The preceding goal turn made concrete progress: the retained token-generation
Groth16 receipt completed and verified. The old temporary work directories are
absent after the restart; historical PIDs were not treated as live jobs.

## Integrated functionality

The attention component proves norm_a, QKV, RoPE, causal scores, integer
softmax, PV, projection and residual 1, with private endpoint bindings.
The block adds norm_m, the actual SiLU FFN and residual 2 in one proof and
one transcript. Each commitment is opened once; there is no shared endpoint
between independently finished component proofs. Both are experimental P1
profiles at T32/d16/F16, with public weights and synthetic fixture data.

The block computation and proof code are unchanged from the reviewed delivery;
three stale documentation statements were corrected after review. Its construction,
arithmetic/code reviews, original public receipt, parity and tamper tests,
and source-derived rank/CFS inventory are retained. See the security owner's
[implementation disposition](ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md).

Codex's changes to attention:

- Reuse the public U8 table's 256 inverse values across 47,104 witness
  lookups, preserving the reference arithmetic for invalid values. No RNG
  draw, mask allocation, transcript input or receipt encoding changes.
- Compare every real lookup column with the original checked batch inverse;
  cover repeated/empty inputs, extreme invalid values and a zero denominator.
- Require witness-tamper candidates to reach the verifier before asserting
  rejection, so prover failure cannot masquerade as a soundness control.
- Integrate the R-2 arithmetic comment corrections and named helper-domain
  bounds; separate integer witness, LogUp helper and H-commitment clocks.
- Correct the public synthetic fixture endpoint tags from `(-3, -3)` to
  `(0, 0)`, matching the approved calibration (D12). This fixture correction
  does not change the generic attention endpoint API. The block API already
  enforces `(0, 0)`.

Two Python integration issues were corrected: the committed schedule's
author-worktree path is normalized only after checking the inventory content
hash, and an optional cross-profile vocabulary test is separated from mandatory
native attention checks. That optional FFN review script is on another branch;
its absence is an explicit skip of that vocabulary comparison. The original
failed run is recorded, not relabelled as passing.

## Measured attention work and verification

[Evidence](../../results/zk60_attention_integration_20260919/) includes source
and binary hashes, commands, exits, samples and the comparison script.
Hardware: Intel Core Ultra 9 185H, CPU only, two Rayon threads. One warm-up
and ten alternating warm samples per implementation, on the shared machine.

| Measurement | Delivered attention | With inverse reuse |
|---|---:|---:|
| Median proving call | 50.5 ms | 49.006 ms |
| Median whole proving process, including preparation and file output | 60.065 ms | 59.393 ms |
| Receipt bytes | 2,245,800 | 2,245,800 |

These are **tiny attention-component diagnostics**. The small median difference
is within plausible shared-machine variation; no established end-to-end speedup
or model-scale projection follows. The deterministic improvement is less
repeated helper arithmetic. Commitments, masked sumchecks and openings remain
larger costs. Baseline printed times have millisecond precision, the new ones
microsecond precision. The comparison predates the fixture scale-tag correction;
`source.json` pins that version, while `integrated-source.json` pins the final
integration separately.

All 17 attention Rust tests pass. Each of the 22 comparison receipts verified
in a fresh process using the other binary, and all three corruptions rejected
each time (66 controls). This establishes verifier/format compatibility, not
identity of independently randomized bytes. Native `ring_matmul freeze-check`
passes with the existing WSL fixture.

The combined block/attention validation passes: **47 unit tests, eight
integration tests and two ownership compile-fail doc tests (57 total)**.
The block source-derived inventory suite passes **29 tests**, including the
46 design counts, paper/source comparison and negative controls. The block
parity suite includes its 1,200 public cases and exact refusal checks.

The newly generated complete block receipt is **2,816,472 bytes**, proves in
**0.062 s** and verifies in a fresh process in **0.020 s** on this shared
two-thread CPU run. The original lane receipt also verifies (0.022 s); all
three corruption controls reject in each verification. These are diagnostic
tiny-block timings, not a model-scale or privacy result.

The independent headless Claude review found no blocking attention-verifier
defect and independently recommended the same complete-block integration.
Its nonblocking draw-order pin recommendation remains follow-up work;
arbitrary scales in the generic attention API remain an experimental-profile
limitation. Its stale block-comment findings are corrected. The review's
claim that chaining is unowned is superseded by the interactive Fable
10:30 handoff, which owns the D12 chaining construction.

The full Python regression passes: **1,098 tests, 61 skipped**, exit 0,
with its complete log retained. The 29 block-inventory tests also pass in a
separate invocation. The skips include the explicitly optional cross-profile
vocabulary comparison; mandatory native attention/block gates executed.

## Next work and ownership

Codex acknowledged Fable's 10:30 split in the coordination file: Codex owns
integration, capture writers and maintained runners; Fable owns the new MVP
and speed plans, the GPU-preserving block/chaining construction and D8/D11
restatement. The source already delivered supersedes the earlier assumption
that norm_m/FFN/residual-2 construction still needed to begin.

Schema-3 captures and a joint/adaptive privacy argument remain open for both
native profiles, including caller-fixed-root history (D8/D11). The full block
is fixed at tiny geometry and does not use the existing GPU FFN prover.
Model-scale proving and the five-second target remain unverified. Fable is
checking newer archived GPU timings before updating the headline baseline;
this tiny-block timing cannot substitute for that model-scale evidence.
