# ZKP efficiency explorer — durable state

Cycle0059 COMPLETE: `20261017T092624Z-0a2ee588`; checkpoint 2026-10-17T09:36:09.547899+00:00.
Agenda/current throughput target and durable/project memory read/snapshotted;
297 sources parsed,6 LIVE records appended,303 total; latest3 results read.
Historical findings and negatives preserved. No native speedup established.

New trained CPU evidence:22 separately verified TinyLlama one-block T32 runs,
not a linked stack, sum405.980s reported main path. Sequence-load/native-witness/
parity294.314s (72.49%),load16.046s,prove_run82.500s,in-process verify7.400s,
unclassified5.720s±0.055s rounding radius. Fresh verifier load/read18.822s and
verify/decode7.265s separately. No researcher proof or verification rerun.
One-block witness is outside prove timer; new stack seals then rebuilds.
RunStats comment incorrectly excludes witness: actual timer includes source,
encoding and sink. Stack witness cache avoids extra boundary rebuilds.
Input-dependent sealing is not automatically reusable public startup.

Experiment: experiments/trained-phase-accounting-20261017.
16,219 accounting/reference checks,200 synthetic traces,15 controls;0.107200s,
17,052KiB RSS,one nice19 CPU0 thread,seed2026101759,59s/512MiB limits.
Independent audit499 checks; archived CLI/run match t5 manifest;140 pins match.
Uncompiled research clock patch: phase-probe-candidate.patch,8 replacements /
6 hunks. No native compile/RNG/transcript/bytes/privacy/fresh-verifier gate.
Handoff: handoffs/20261017-trained-phase-accounting.md.

Ranked hypotheses:
1 REFINED/OWNER both recurring exact trained witness paths; newT32 diagnostic
 share72.49%; isolate exact matmul/requant/materialization before speed estimate.
2 OWNER GPU SC_SZC,all native masked/oracle/bytes/refusal/privacy gates.
3 TESTED ACCOUNTING/OWNER resident complete linked passes and true startup/slope/
 lag/drain; recurring>20ms/proved position rejects50/s for that schedule.
4 OWNER public dependency selector/factory actual capture/three-arm profile.
5 ARCHITECTURE MORPH/zkMatrix/TaSSLE/TensorZKP; field/PCS/joint-hiding migration.
All prior cubic/CSE/fusion/twiddle/table-cache negatives remain preserved.
Eliminating measured proof phase yields at most1.255x on summed one-block
 diagnostics; deleting measured load only1.041x. Complete8B ceiling unknown.

Next LOCAL: allocation-free read-only census of witness::build_shaped and its
 callees, separating full-K matmul,requant/range/refusal checks,plane/helper
 materialization and repeated passes. Identify an exact Rust/CUDA seam and
 independent scalar edge-case differential fixture; no native build/proof/GPU.
Next OWNER: review clock patch,split both witnesses/encoding/durable sink and
 fresh verifier read/decode/crypto on linked trained stack; preserve native
 samples/finals/RNG/refusals/transcript/proof bytes and fresh independent verify.
 Then resident fixed-context complete workloads with fresh masks and startup,
 slope,lag/drain/peak. Original block timing thread count not established here.

LIVE search rotation memory/batching/quantization. New MORPH Apr20,2026 and
 older zkMatrix Feb4/Feb7,2024;TensorZKP/TaSSLE refresh. ICICLE full commit
 6c77775961b0e4dc2be359feec1ac11536c18043 and MIT repo license text inspected;
 extension challenge limitation persists,release year not verified. MORPH
 history/license,zkMatrixPDF and OctoberPlonky3 exact release/crate blocked.
 No foreign performance reproduced. Next rotation exact witness arithmetic,
 then NTT/commitments based on native bottlenecks.

Accepted independently verified complete private 8B proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag/drain and proof context: **unmeasured**. This cycle used one Intel Core Ultra 9 185H CPU thread (CPU0, nice19), no GPU. The retained native records are CPU-only T32, 22 separate one-block runs, zero linked complete-model passes; original thread count is not established here. No long-context prefill, resident complete-model workload or decode proof ran. Dense attention work grows approximately quadratically with context. Larger workloads remain allowed, fresh masks and privacy obligations remain unchanged, and the >=50 proved-token/s target remains unachieved.

Research only. Production/runtime/Git/calibration/gates/instructions/reviewer
 files untouched. No build,GPU,install,downloaded-script execution,external
 write/message,merge or heavy job queued. Main agent/Claude reviews/integrates.
Saved reports do not prove delivery or supervisor liveness. D24 remains proposed;
 current owner fixes are not a new privacy acceptance.
Next cycle not before2026-10-17T10:26:24Z.

Final checkpoint 2026-10-17T09:36:35.383884+00:00:28 accounting/artifact checks pass,49 artifact pins;303 source records and historical prefixes preserved;no concurrent owner-memory changes observed. Native compile/proof/privacy gates remain unrun.
