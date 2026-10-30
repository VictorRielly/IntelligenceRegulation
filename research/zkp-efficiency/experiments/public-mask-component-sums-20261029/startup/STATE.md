# ZKP efficiency explorer — durable state

Cycle0140 COMPLETE: `20261029T095649Z-50135f2e`.
Started2026-10-29 09:56:49UTC; early checkpoint09:57:34UTC;
final checkpoint2026-10-29T10:10:51.585056+00:00. Deadline10:16:49UTC.
Next cycle no earlier than10:56:49UTC.

No native proving improvement measured. New hypothesis59's compiled local
CPU encoder reuses only its own final output prefix for inverse-NTT scratch.
606row calls allocate606→0 coefficient vectors;713448→0B cumulatively.
Live coefficient payload saved8*n per active worker;128KiB at n16384,
at most2MiB for16active workers. Do not count rows*n as simultaneous savings.
Encoded matrix, NTT butterflies, pads/salts and nominal copies remain.
Accepted CUDA commitments have zero direct incidence. No mask/private reuse.

168fixtures/606rows/360882encoded values pass;29106direct-DFT values;
five serial matrices/ten refusals/ten negative controls. Harness0.104446s,
8352KiB RSS. Source audit74checks/four static mutations/11pins PASS.
Std-only local component compiled against copied frozen Fp/NTT; matrix
adapters replace Rayon traversal with serial only. No full native/Cargo build.
One pinned nice19 CPU;40sCPU/45salarm/50sparent/384MiBAS caps.
Full native Rayon, alias safety, RNG/transcript/CFS/PCS/receipt/privacy gates owed.

All58prior hypotheses remain;1/12/34refined;59added and PARKED behind
exclusive native allocator/enclosing clocks. Global top3: complete-prover named
high-endGPU with independently verified resident1/2/4/8; DD/fidelity context
scaling; exclusive phase/capacity clocks. Eight LIVE primary records924→932:
ICICLE1046/1047,GPIR,Artemarius releases,DESILO2.0,older in-place hardware,
2022HE NTT,Qingming. Verified dates/licenses/access blockers saved. No foreign
code executed or author speed reproduced. D45/token16 concurrent review
accepted-with-fixes is separate and does not change private8B target/privacy.

Owner next: CPU/fallback incidence and exclusive allocator/encoding/hash/
enclosing clocks; safety/native goldens if useful. Whole-prover GPU/resident
measurements retain priority. Owner S4 split-width design was only read;
no protocol/layout implementation or heavy job queued. Main/Claude integrates.
Next local: sumcheck/GKR hypothesis57 public component-sum preparation versus
existing paired3, with general/zero/Boolean Fp2 tails, ordered offsets,
changed challenges and full added scan/traffic/storage/dispatch accounting.

Experiment: experiments/commitment-width-lifetimes-20261029/README.md.
Patch: initialize-in-output.patch in that experiment; unapplied.
Handoff: handoffs/20261029-cpu-encode-prefix-scratch.md.
Dated report: progress/20261029T095649Z-50135f2e.md.

New independently verified full-stack proofs / model passes / proved positions: 0 / 0 / 0.
Actual model context and accelerator: none; research used one pinned
Intel Core Ultra 9 185H CPU worker. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload rates: unmeasured. No long-context prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
longer dense attention may grow quadratically. The complete private 8B
>=50 proved-token/s target on an RTX 5090 or another named high-end GPU remains
unachieved.

Carried historical CPU 8B T128/L32, one 16-thread pass, GPU off:
total478.737s =0.267370positions/s; prove_run393.785s includes witness98.348s
and blockload17.595s. Sealing84.824s precedes prove_run; its internal load27.151s
and witness80.897s overlap. Receipt922711264B; verify42.709s plus load13.681s.
Not rerun/reverified or newly counted. Isolated serialization, startup fraction
and steady-state slope remain unknown. These are older-profile measurements.

Prior STATE and early checkpoint preserved under startup. FINDINGS/sources
appended only. Only research outside runtime written; no production/Git/
receipt/calibration/instruction/safety/reviewer changes. No GPU, large build,
install, external write/message, purchase or escalation. Saved reports are
not delivery or supervisor liveness evidence.
