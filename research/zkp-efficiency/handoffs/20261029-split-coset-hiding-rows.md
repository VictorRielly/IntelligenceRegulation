# Conditional hiding-encoder coset split — cycle0135, 2026-10-29

**Exact CPU model passes; no native proving gain measured.** Keep below
whole-prover GPU/resident workloads and complete phase/capacity measurements.
No native patch, build, GPU job or integration. Main/Claude reviews and promotes.

[Experiment](../experiments/ntt-coset-layout-20261029/README.md) and
[adapter contract](../experiments/ntt-coset-layout-20261029/interface.md).
Patch location: research `candidate.py`, `reference.py`, `large_rows.py`;
these are executable models, not a Rust/CUDA patch. Native seam is trained-1b
cuda.rs `encode_rows_view_zk[_gather]` / `ntt_rows[_view]` and kernels.cu
`k_ntt_p1/p2*`, with CPU oracle `zkp-core::pcs::encode_row_zk`.
Eight exact source/vector pins are retained next to the models.

Keep normalized inverse n. Let N=r*n; for s=0..r-1, a=h*omega_N^s, A=a^n.
Evaluate `(f[t]+(A-1)*sum_l pad[t+l*n]*A^l)*a^t` with n-point forward,
then store j at logical column s+r*j. For q<=n, a guarded specialization can
skip absent pad terms. q>n needs the full fold or incumbent fallback. Existing
native admission/refusal guards must remain, regardless of Python fixtures.
Preserve canonical column bytes, original rows/chunks, unsorted/duplicate
gather requests, every fresh pad/mask/salt and unchanged transcript/openings.
Same proof's masked polynomial across cosets is not cross-proof mask reuse.

Validation: 21,424 checks on186tinyfixtures,20,104outputpoints,744Lagrange
checks,15retained synthetic native conformance rows; 13wrongcontrol families
and6algebrafixture refusals. Larger n4096/8192/16384 sparse-f/g independent
recurrence checks all114,688outputs. Small/large checking0.610484/1.181438s,
17,308/43,100KiBRSS,onepinnednice19CPUworker,seed202610290135;40sCPU/45salarm/
256MiBAS/64MiBestimate. Source/evidence audit101checksPASS. These are not
native tests or proof clocks; no model proof, verification or privacy test ran.

Cost: r4 removes4n forward butterflies, but extra coefficient/pad scales
leave only n-3q mul savings. At n16384/q256:672000->656384encoderfieldmul,
2.3238% fewer,130560feweradd/sub; +49152coefficient reads, +512padreads,
+48896powerreads (logical words, not DRAM). q=n has4.7619% MOREmul, a bounded
negative for broad claims. n>=8192 keeps both forward kernel groups. n4096
may eliminate P2 if cosets are batched, but final stores/gather need adaptation.
Public preparation, indices, barriers, occupancy and full clocks unknown.

Naive split materialization grows compact input scratch n+q->r*n:
+391168logicalB/row at n16384/q256. A custom first load avoids it but may
repeat the earlier scattered-read regression. Natural-order restoration costs
16NlogicalB/row if used; otherwise test direct strided-store/gather behavior.
Native already produces natural order and caches twiddles; no redundant
restore or twiddle setup is newly removed. Current full pows storage isN,
even though compact source accesses onlyn+q; charge new public table factors.

End-to-end ceiling remains Npositions/(T-Cremoved+Aadded); exclusive affected
fraction f unmeasured gives only free-deletion1/(1-f), not a GPU forecast.
First owner action: measure inverse/prepare/expandedforward/gather/hash and
enclosing phase time, source incidence, public setup and capacity. Only if
material, build an isolated same-lock adapter with all field/layout/q>n fallback/
masked-round/nextRNG/challenge/refusal/PCS/root/receipt-byte and strictGPU gates,
independent fresh-process complete verification, current fidelity/soundness/
privacy reviews and enclosing resident1/2/4/8 workloads. No heavy job queued.

Reject any parity/refusal/lifetime/privacy mismatch, absent eligible calls,
scratch/traffic regression or no enclosing verified gain. The legacy q>n
branched-producer finding and prior gather/pad/cache negatives are preserved;
this cycle's pinned trained-1b GPU producer already uses independent additions.

Nine LIVE primary records saved: current cuPQC p<2^62 excludesGoldilocks;
GPU-NTT/Qingming/LightZK and new older HiFA/Hardcaml plus zisk-zorch layout
attribution inform methodology. Licenses/dates/commit-fetch blockers are
explicit; no external code or author timing reproduced. No private8B/GPU
throughput/privacy acceptance. New complete proofs/passes/positions0/0/0;
context/accelerator none, all proof/startup/rate clocks unmeasured.
