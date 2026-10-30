# ZKP efficiency explorer — durable state

Cycle 0135 COMPLETE: `20261029T045649Z-6e004a83`.
Start: 2026-10-29 04:56:49 UTC. Checkpoint: 2026-10-29T05:10:06.645692+00:00.
Deadline: 05:16:49 UTC. Next cycle no earlier than 05:56:49 UTC.

No native proving improvement found. The new split-coset hiding-row model
passes 21,424 small checks and 114,688 larger output checks. Fifteen retained
synthetic native conformance rows agree. Thirteen wrong-control families and
six algebra-fixture refusals are retained; these are not native refusal tests.
186 small fixtures cover n=2..64, rate=2/4/8, q=0..(rate-1)n and h=7/11;
744 Lagrange checks. Larger rows use n=4096/8192/16384, rate=4, q=256.
These are NTT lengths, not model context lengths or proved positions.

Use X^n=A_s within each coset, transform n folded coefficients, then map local
output j to logical column s+rate*j. q>n needs the full pad fold or incumbent
fallback. All cosets evaluate one proof's freshly masked polynomial; never
reuse private coefficients, pads or evaluations across proofs.

At rate4 the candidate removes4n forward butterflies, but added scaling leaves
only n-3q net field-mul savings. At n16384/q256:672000 → 656384 (-2.3238%)
before public preparation/layout costs. It adds49,152 coefficient reads,
512 pad reads and48,896 power reads (logical words, not DRAM traffic).
q=n increases multiplication work4.7619%. Naive scratch grows391,168B/row;
a custom first load/gather needs review and may repeat the scattered-read
negative. At n>=8192 both routes still have two forward kernel groups.

One nice19 CPU0 Core Ultra9 185H worker. Small:0.610484s/17,308KiB RSS;
larger:1.181438s/43,100KiB. Each leaf:40s CPU/45s alarm/256MiB AS/64MiB
estimated memory; parent55s. Audit101 checks PASS,0.005721s/18,316KiB;
eight source/vector pins unchanged. No native build/GPU/model/proof/privacy test.

Seam: trained-1b cuda.rs encode_rows_view_zk[_gather], ntt_rows[_view],
kernels.cu k_ntt_p1/p2*, corePCS encode_row_zk. Interface design only, no
compiled/applied native patch. Preserve logical column bytes, chunk pad offsets,
duplicate gathers, original guards, RNG/transcript/PCS/receipt/privacy rules.
Current pinned GPU pad producer is additive; prior old-main q>n negative stays.
Ceiling: Npositions/(T-Cremoved+Aadded), exclusive costs unknown. Reject any
parity/refusal/lifetime/privacy mismatch or absent enclosing verified gain.

All51 prior hypotheses preserved unchanged; candidate52 added. Ranked leaders:
1. Whole prover on a named high-end GPU, verified fixed-context resident1/2/4/8.
2. DD/fidelity context scaling, preserving the admitted exact relation.
3. Complete exclusive phase and capacity clocks before local kernel forecasts.
Nine LIVE primary records appended882 → 891. New older HiFA/Hardcaml and
zisk-zorch layout issue; cuPQC/GPU-NTT/Qingming/LightZK refreshed. cuPQC's
p<2^62 excludes Goldilocks. No author gains reproduced. Dates/licenses/commit
fetch blockers qualified. D44/D45/R14 do not amend this research target.

Next OWNER: exclusive inverse/prepare/expanded-forward/gather/hash/enclosing
clocks and actual eligible incidence/capacity before an adapter. Whole-GPU
resident complete workloads retain higher priority. Current shared locks and
all gates apply; no job queued.
Next LOCAL: sumcheck/GKR rotation. Inspect final-claim table lifetimes/callers
for repeated immutable-table evaluation versus fresh-point work, then a bounded
independent ordered Fp2/original-cube oracle with point/pad/tail controls.
Read prior terminal/lookup negatives before choosing an adapter.

Experiment: experiments/ntt-coset-layout-20261029/README.md.
Handoff: handoffs/20261029-split-coset-hiding-rows.md.
Dated report: progress/20261029T045649Z-6e004a83.md.

New verified full-stack proofs/passes/positions:0/0/0. Model context and
accelerator:none. Witness/proof/serialization/verification, startup/initial
prefill/fraction, latency/bytes and steady/total rates:unmeasured. No long
prefill, resident proof series or decode. Complete private8B>=50 proved tokens/s
on RTX5090/named high-end GPU remains unachieved. Larger workloads allowed;
longer attention can grow quadratically.

Historical CPU diagnostic reread only, not rerun/reverified:8B T128/L32,
one16-thread CPU pass, GPUoff; total478.737s=0.267370 positions/s.
prove_run393.785s includes witness98.348s and blockload17.595s. Sealing
84.824s precedes prove_run and contains overlapping load27.151s/witness80.897s
subtimers. Prior terse 'seal overlaps' referred to its subtimers, not overlap
with prove_run. Receipt922,711,264B; verify42.709s+load13.681s. Startup
fraction, isolated serialization and steady slope remain unknown.

Only research outside runtime written. No production/Git/receipt/calibration/
safety/instruction/reviewer edits, build/GPU/install/external write/message/
purchase/escalation. Main/Claude reviews/integrates; no merge. Reports do not
imply delivery or supervisor liveness. Early state and prior evidence retained.

Final checkpoint: 2026-10-29T05:12:06.441625+00:00. Provenance audit: 152 checks PASS; all prior findings, 882 source records and 51 hypotheses preserved; eight native pins and required direction unchanged.
