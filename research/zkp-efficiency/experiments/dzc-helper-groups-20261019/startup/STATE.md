# ZKP efficiency explorer — durable state

Cycle 0080 COMPLETE: `20261019T121854Z-575be12a`, 2026-10-19 UTC.
Next cycle no earlier than **13:18:54 UTC**.
[Dated report](progress/20261019T121854Z-575be12a.md).
Startup memory: experiments/dzc-static-runtime-20261019/startup/.

**Compiler storage result; no proving speedup measured.** Static D coefficients
with runtime proof-local parameters compile using the unchanged native field.
Affine-first versus use-driven CPU caller local stack: **1,160→360 bytes**,
with 48 extra callee-saved push bytes each and the same 884 Fp2 calls.
Caller instruction lines 6,986→7,011; symbol bytes 33,878→32,967. These are
unintegrated coefficient prototypes, not installed sampler A/B or GPU metrics.
All 59 original tables, folds and finals remain. Scalar SSA peak including
round accumulator 76→26 differs from prior buffer model 77→27. Static stack
and RSP references do not measure dynamic spill traffic, DRAM or proof timing.

Interface: run.py::graph/Lower.emit → kernels.rs::driven(raw,params,bases,out).
118 Fp2 low/high inputs, 129 Fp2 parameters, 36 canonical base parameters,
five coefficients. Runtime pack 2,352 bytes; logical requested traffic 4,320
bytes/row in both arms; physical DRAM unknown. No field-value/zero pruning.
Signed lookup −1 must reduce modulo P: a u64 cast caused the first caught
failure. Native all-inlined compilation exceeded 40 seconds. The successful
adapter uses non-inlined Fp2 calls; it is not fully fused device code.
Substitute-field and failed artifacts are preserved separately.

PASS: six synthetic fixtures, two public scalar catalogs, N=2/8/32,
seed 2026101980; 780 coefficients, 390 captured-Rust grid/78 off-grid values,
18 messages, 354 original finals, six relations, 36 zero bindings, seven
controls and 2,372 independent audit checks. Six live native pins and five
owner evidence pins unchanged. Candidate field source is byte-identical;
captured full D/catalog still uses Shape/Layout substitutes. Actual profile
admission/challenges/alpha/g_u8/RNG/transcript/masks/PCS/proofs/privacy remain
owner gates. Compiled scope: unpadded four-limb 59-table catalog. Previous
generic Python tests are not native admission. D30 remains separate/unbuilt.

Native main 3.807474s including compiler 1.055092s; RSS 37,976 KiB, compiler
130,212 KiB. Audit 1.005090s/RSS 24,252 KiB. One nice19 Core Ultra 9 185H
CPU0, WSL2, rustc1.97.1, opt1, one codegen unit; each 59s CPU/wall and
512 MiB address space. No Cargo/GPU/install/foreign code. Correctness clocks,
not kernel latency A/B. Field add/sub/mul/base: 272/209/331/72. Original
folds add 118 reads,59 writes,59 each add/sub/mul. Common reduction,
conversion,plan and enclosing proof remain outside that count.

Unapplied handoff: handoffs/20261019-dzc-static-runtime.md.
Seam: pinned gpu-zerocheck SC_DZC / SumcheckRounds. Main/Claude integrates.
Native seeded bytes/RNG/refusals, extension/mask/PCS/final order, fresh
verify/tamper, joint-view privacy and enclosing clocks remain acceptance gates.
No additional private claims/openings, mask reuse or privacy weakening.

Carried R6/b7 8B diagnostic: T128,32 blocks,one pass,16 Rayon threads,GPU off;
total471.580s,proof region370.137s includes witness94.021/load17.408s;
seal101.279s,922,711,264 bytes,D44.833s=9.507%. Delete-ALL-D zero-cost
ceiling:1.105058x /0.299944 diagnostic positions/s versus0.271428. This bounds
only that CPU diagnostic, not candidate/GPU performance or target acceptance.
Verify34.587+load11.599s;recheck32.311+load9.903s. Serialization,startup
fraction,steady slope unisolated;seal is not startup. Other owner clocks
remain separately labeled in target-accounting.json. Evidence read/hashed;
no receipt reverified by this researcher.

Distinct carried 8B next-token diagnostic: T32,32 blocks,one CPU pass;
test230.5s,prove191.7s including witness17.3/load14.3s;owner verify43.4s;
471,285,072 bytes. Independent R3 soundness review permits it; reviewer
verify37.7s/second route41.8s. Native R7 accepted on soundness. Trained
privacy acceptance,hidden length and decode remain pending.

Ranked hypotheses:
1. OWNER whole-prover GPU D/A and completed resident-pass slopes. Broad scope,
   high integration cost; charge traffic,serialization,drain,fresh verify and
   masks/openings. Falsify enclosing regression,backlog or privacy failure.
2. NEW LOCAL helper-group code generation. Baseline884 scalar calls; full
   inlining exceeds40s. Fuse within small public helper groups; charge argument
   traffic,callee scratch,deepest stack,compile/code growth and original reads.
   Moderate incremental cost,ceiling unknown. Falsify any differential,secret
   dispatch,uncharged reads,compile-limit failure or enclosing regression.
3. OWNER public setup residency. Potential startup benefit;slope unknown.
   Identity,lifetime,transfer and fresh witness/mask/opening gates; reject
   stale setup or no completed-proof benefit.
4. OWNER D30 dictionary and architecture comparisons. New RS interleaving
   lead has high hiding/soundness/composition cost; no D10 override.

NEXT: bounded native helper-group emitter with the same independent oracles,
call-chain storage and compile/code-growth audit. Device compiler,whole-D and
complete resident-stack measurements stay with the owner/shared locks.
Rotation next: sumcheck/GKR and batching/amortization; retain lookup/softmax,
memory,NTT/commitments,quantization/arithmetic and composition.

Eight LIVE records appended427→435: new ReedWeave(Sep22/revised24),
Quasar(Aug31),Terrazzo(Sep2),older Sethi-Ullman author bibliography(Oct1970);
Min-Reg,LLVM,Zorch runtime kernels and current NTT source/releases/license
refreshed. PDF/commit/history blockers retained. Actual NTT MIT file inspected;
7b1e6b9ce865ea45f6c601a33118512dd98e1149 exposed only,not an inspected pin.
No foreign implementation or performance reproduced.

New target proofs/passes/positions **0/0/0**, device none. Target context,
steady/total rates,startup fraction,witness/proof/serialization/verification
unmeasured. No prefill,resident series or decode. Larger workloads allowed;
attention can grow quadratically. Complete private8B >=50 proved positions/s
on5090/named high-end GPU remains unchanged and unachieved. Only research
files written; runtime/production/Git/receipts/calibration/safety/instructions/
reviewer files untouched. Saved reports do not establish delivery.

Final artifact/source integrity: PASS,53 checks at2026-10-19T12:34:14Z.
Prior findings/source prefixes preserved;435 source records parse. Production
startup documents retain source hashes only; narrative contents are not copied.
