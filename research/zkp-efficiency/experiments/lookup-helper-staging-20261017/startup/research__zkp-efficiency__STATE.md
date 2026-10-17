# ZKP efficiency explorer — durable state

Cycle 0065 COMPLETE: `20261017T182105Z-44205280`.
Final checkpoint: 2026-10-17T18:33:15.746071+00:00. Next cycle no earlier than 2026-10-17T19:21:05Z.
AGENDA, target, durable/project memory and latest three results read.
Startup memory: `experiments/fzc-device-traffic-20261017/startup/`.
All 331 source records preserved; six LIVE records appended (337 total).

No proving speedup found. The captured active owner F-device source has these
round/fold table access counts, N = 2^n, K = 20/21 without/with support:

- Direct separate: 80 K (N-1); direct fused: 64 K N - 48 K.
- Lean either schedule: (32 M + 48 K)(N-1), M = 32 or 33 + W, where W is
  the number of nonzero public pad weights. It stores then rereads folds.
- Direct fusion removes about 20% of table bytes, 15.38% including the stated
  504 N construction counter. The captured design-note fused TOTAL of 1344 N
  should approach 1848 N at K = 21. The Rust direct counter already agrees.
- Eq construction counts outputs only. Source accesses, normalized work,
  optimized GPU accesses and hardware traffic must have separate labels.
  All tables, including round 0, are 16-byte Fp2 in this captured variant.

96 fixtures / 384 schedules pass independent arithmetic, fold and access
checks, with ten controls. Independent audit: 148 checks, 7,687 Eq outputs,
three controls, including an actual wrong-stride mutation. Main 0.759414 s,
16,820 KiB parent / 34,620 KiB compiler; audit 0.368121 s, 16,608 / 34,956 KiB.
CPU Core Ultra 9 185H, CPU 0, one thread, nice 19, seed 2026101765, g++ 11.4
O0, 59-second and 512 MiB caps per experiment. CPU CUDA/field substitutes;
no native GPU arithmetic, concurrency, transcript, mask, RNG, PCS or proof gate.
Final artifact audit passes 62 checks with 57 files pinned. Kernel/Rust pins
match. Owner progress ledger changed during the audit; both versions retained.
It records a successor build and queued t2 test; no accepted device result or
liveness inferred. No owner source/document was edited.

Unapplied handoff: `handoffs/20261017-fzc-device-traffic.md`. Self-contained
code, captured sources, hashes, commands, logs and a design-note patch remain
under `experiments/fzc-device-traffic-20261017/`.

Owner functional 8B baseline carried forward, not rerun: 8,030,261,248
parameters, 32 linked attention+FFN blocks, T32, one cold pass per CPU/GPU arm,
16 threads. CPU process 384.542564 s / RTX 4070 Laptop 391.287091 s;
diagnostic rates 0.083216 / 0.081781 positions/s. Witness 18.629 / 18.109 s;
inclusive proving 208.019 / 213.831 s includes reload 79.222 / 77.997 s and
remainder 110.168 / 117.725 s with serialization/sink. Partial load+seal startup
fractions 21.595% / 20.341%. In-process verification 93.356 / 92.741 s;
fresh check 96.103 / 90.935 s plus initial load 80.675 / 78.635 s. Receipt
465,815,776 bytes per arm. Full startup/prefill, isolated serialization,
steady slope, proof-only latency, lag/drain are unknown. Shape privacy and
independent 8B review remain open. No resident repeats, long prefill or decode.

Ranked hypotheses:

1. OWNER: all recurring prover phases resident on GPU. Highest end-to-end
   potential, high integration cost. Include scratch, transfers and full
   native byte/refusal/privacy/fresh-verifier gates. Earlier 1.1B T128 GPU
   F masked body 16.457 / 161.857226 s: deleting that whole body caps direct
   gain at 1.113184x. Actual 8B F clock absent. Enclosing regression falsifies.
2. OWNER: immutable public model/digest residency over fresh complete passes.
   Measured cold loads above; charge RAM/revalidation/startup and retain
   mutation refusal. No measured pass-count slope; no mask/opening reuse.
3. NEW/TESTED: variant-aware F traffic accounting. Low cost for labels and
   formulas; prevents unsupported bandwidth interpretation. No prover work
   removed here, no new timing ceiling beyond item 1. Hardware inference
   still requires actual hierarchy/instruction/occupancy/spill measurements.
4. NEXT LOCAL: rotate to lookup/softmax/composition. Capture helper producer
   -> commitment -> F-reader representations, lifetimes and duplicate staging.
   Test paired/odd/refusal cases before proposing removed work. Preserve
   LogUp-GKR D/C leakage and borrowed-catalog negatives. Inverse-only speed
   remains low priority: prior GPU lookup+histogram deletion ceiling 1.004643x.

Next owner: review handoff and collect unprofiled slot/enclosing proof clocks
plus device counters under shared locks and native gates. No heavy/GPU job
queued by this cycle. Accepted new target proofs/passes/positions: 0 / 0 / 0.
The >=50/s target is unchanged and unachieved. Larger workloads may amortize
setup with fresh masks; resident contexts, long prefill and decode stay
separate, and dense attention can grow quadratically with context.

All writes stayed within research, excluding runtime. No production, Git,
receipt, calibration, gate, instruction or reviewer write; no GPU/native
build/proof, installs, foreign script execution, external messages, purchases
or escalation. No supervisor liveness claim. Saved reports do not establish
user-message delivery. Full report: `progress/20261017T182105Z-44205280.md`.
