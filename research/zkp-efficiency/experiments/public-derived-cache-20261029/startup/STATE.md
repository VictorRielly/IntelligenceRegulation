# ZKP efficiency explorer — durable state

Cycle 0130 COMPLETE: `20261028T235649Z-d1bc0725`.
Started 2026-10-28 23:56:49 UTC; deadline 2026-10-29 00:16:49 UTC.
Next cycle no earlier than 2026-10-29 00:56:49 UTC.

No native proving gain. The stock Tensor Core NTT driver selects a reducer
limited to 62-bit moduli. Its template64 parameter does not mean a 64-bit
prime; the test uses a 61-bit modulus. The general Montgomery multiplier
passes in isolation, but a multiplier swap does not fix lazy 2N butterflies.
Canonical P-1 dot16 inputs need 132 bits and top carry15. Dropped intermediate
or top carries fail. These unsupported-port controls are not upstream bugs.

A locally authored carry/scaling contract passes 39,179 synthetic checks:
12,441 products, 18 radix2 fixtures at n2..64, 35 dot16 fixtures, four matrix16
fixtures, 54 negative controls and five public guard cases. Eight overlapping
u32 words pack with explicit carries into lo/hi/top. Goldilocks folds top by
subtracting top<<32, then removes the source matrix scale with EPS. Native
root order and source bit-reversed matrix rows are compared to direct DFTs.
Dot16 combined-word bound2,138,022,000 fits signed32; the same formula at32
would not. No GPU lane/MMA/WMMA/transposition or compiler evidence exists.

Model checking: 0.093988 s /15,608 KiB RSS. Source/provenance audit:774 checks,
0.006968 s /16,648 KiB. One pinned nice19 Core Ultra9 185H worker, 40s CPU /
45s alarm, 256MiB address-space cap, 64MiB estimate. Four adaptive versions,
commands, seeds, dimensions and source hashes retained; no timing A/B.
The CUDA reducer sketch is uncompiled/unapplied. Full native inverse/coset/
pad/q>n/chunk/order, masked RNG/transcript, refusal, PCS, receipts and privacy
remain untested. No heavy job queued.

All44 prior hypotheses retained,46 total:1/44 refined,45/46 added. Top3 remain
whole-prover high-endGPU with verified fixed-context resident1/2/4/8;
DD/fidelity context scaling after the measured T128 null result; complete
exclusive phase/capacity clocks. Current R12b/RC2 fix-scope freezes and D44
resource-guard swap window do not supply private8B GPU throughput.

Nine primary records appended,849 total. Two LIVE search batches plus14
retained followups. Immutable6f407daa8a4cef96331511ae86b922b520d7aa33 modular/
NTT headers and selected driver sections inspected; Apache2 SPDX checked.
Rendered-text hashes are not raw Git blob hashes. Immutable arithmetic-helper
Cache misses, unpinned main-helper dependency, inaccessible DOI, older
Montgomery PDF403/Cambridge Cache miss are recorded. Current release pages,
known2026 sumcheck and older root shifts refreshed; omitted years unknown.
No author performance reproduced or foreign code executed.

Next LOCAL: inspect prior public-loader/cache findings, then R12b
`tied_tables/derive.rs` inputs and refusal order. Test synthetic mutable
public files and changed parameters against a fully bound immutable derived
public object. Owner's7.7GB/17–18s load note is Shieldstral3B, not an8B cost
or startup fraction. Path/size/mtime/inode caches alone cannot suffice.
No P3 weight, mask, pad, salt or opening reuse is assumed. No further
carry-only refinements before native exclusive NTT/enclosing measurements.
Next OWNER: measure those clocks, consider an adapter only if material,
then native golden/masked/next-RNG/refusal/PCS/privacy/independent full
receipts under current shared locks and verified resident1/2/4/8 workloads.

Experiment: `experiments/goldilocks-tc-contract-20261028/README.md`.
Handoff: `handoffs/20261028-goldilocks-tc-contract.md`.
Prior memory,840 sources/44 hypotheses, latest cycle0129 results and required
project documents are preserved in the experiment's startup directory.

New independently verified full-stack proofs/passes/positions:0/0/0.
Model context/accelerator:none. Witness/proof/serialization/verification,
startup/prefill, startup fraction, latency/bytes and steady/total rates are
unmeasured. No long prefill, resident proof series or decode. Larger workloads
remain allowed; attention can grow quadratically. Private8B >=50 proved
tokens/s on RTX5090 or another named high-endGPU remains unachieved.

Historical diagnostic only, not rerun/reverified: nonDD8B T128/L32, one
16-thread CPU pass, GPUoff; total478.737s=0.267370positions/s. prove_run393.785s
includes witness98.348s/load17.595s; seal84.824s overlaps. Receipt922711264B;
freshverify42.709s+load13.681s. Startup fraction, isolated serialization and
steady slope unknown. No GPU/private8B acceptance follows.

Only research outside runtime written. No production/Git/reviewer/instruction/
receipt/calibration/gate mutation, build, GPU, install, external write/message,
purchase or escalation. Main/Claude reviews/integrates; no merge. Saved reports
do not establish delivery or supervisor liveness.

Final evidence audit: 272 checks PASS; 66 immutable artifacts, seven native pins and six required project documents unchanged. All840 prior sources,44 prior hypotheses and prior findings retained. Final checkpoint UTC: 2026-10-29T00:14:29.651392+00:00.
