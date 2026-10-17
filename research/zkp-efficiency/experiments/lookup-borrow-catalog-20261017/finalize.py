#!/usr/bin/env python3
"""Final report after the owner GPU phase diagnostic completed during cycle."""
import datetime
import hashlib
import json
from pathlib import Path
H=Path(__file__).resolve().parent
B=H.parent.parent
RUN='20261017T122624Z-c30acfa0'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((H/'result.json').read_text()); a=json.loads((H/'audit-result.json').read_text())
cpu=json.loads((H/'retained/r4-cpu-phases.json').read_text())
gpu=json.loads((H/'retained/r4-gpu-phases.json').read_text())
for x in [cpu,gpu]:
    assert x['guard']['exit']==x['guard']['child_rc']==0
    assert x['blocks']==x['proved_event']['blocks']==22
assert cpu['proved_event']['statement_identity']==gpu['proved_event']['statement_identity']

accounting='''Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Context, steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, latency, lag and drain remain **unmeasured** for that target. Local experiment: one Intel Core Ultra 9 185H CPU thread, CPU0, nice 19; no GPU. No prefill proof, resident-pass sweep or decode ran here. Larger workloads remain allowed with fresh masks; dense attention grows approximately quadratically with context. The >=50 proved-token/s target is unchanged and unachieved.'''

queue='''1. **Owner: trained GPU D/F zero-checks.** New T128 GPU-assisted slot clocks are D 25.353 s and F 19.484 s, versus softmax 11.834 s. Their shared masked-sumcheck portions are 19.860/16.457 s. Follow these measured costs; retain slot-polynomial/final-oracle, RNG, transcript, PCS, fresh-mask and independent-verifier gates. Charge launches, transfers and scratch. A mismatch or unchanged enclosing workload cost falsifies a speed gain. This is one 1.1B diagnostic, not an 8B forecast.
2. **Owner: resident fixed-context fresh-proof slopes.** Reuse only valid input-independent public model/NTT/digest setup. Measure recurring witness/proof/serialization, verification, startup, backlog and drain. Added retained memory and identity maintenance; no reused private openings or masks. More than 20 ms recurring cost per newly proved position falsifies 50/s for that schedule. Keep prefill, resident passes and decode separate.
3. **Tested, demoted for speed: borrowed identity lookup columns.** Avoid 167.5 MiB of looked payload at TinyLlama T128; final witness unchanged. Public classification, Cow descriptors and possible compiler/task-balance costs are added. No extra affine recomputation or scan. Peak RAM is unmeasured. Deleting the entire lookup+histogram mark gives at most 1.002959x CPU / 1.004643x GPU directly with other costs fixed. Native word/refusal/bytes divergence rejects correctness; unchanged measured peak rejects capacity gain; unchanged complete time rejects speed gain.
4. **New next local experiment: specialize the current F zero-check's public base-field constants.** The pinned `argument.rs:1602` still uses extension multiplication by `p1`, `k_h` and `k_g`; D and softmax have prior Stage35 base-constant work. Capture the F closure's exact current grammar and compare a mul_base rewrite against an independent full-extension reference, including helper, pad and hosted terms. First census actual operations; the compiler may already simplify them. Native integration is small/moderate, but no end-to-end estimate exists. Deleting the entire F slot would give at most 1.136852x on this GPU diagnostic; this local change can remove only a subset. Any polynomial mismatch or no native enclosing benefit falsifies it. Do not redo a generic arithmetic identity toy without the actual F closure.
5. **Retained/deferred:** the duplicate-descriptor histogram idea removes at most 8.36% of histogram input visits at T128, inside a tiny phase, so demote it behind F work. Prior deferred witness allocations/int8 accumulation remain unintegrated owner candidates. HOBBIT is an architecture lead with streaming-access/PCS costs; ring lookup arguments are not a native field replacement. Preserve all prior negative results.'''

phase_table='''| T128 owner phase, summed across 22 blocks | CPU s | RTX 4070 Laptop assisted s |
|---|---:|---:|
| D zero-check | 27.501 | 25.353 |
| F zero-check | 17.631 | 19.484 |
| Softmax zero-check | 11.531 | 11.834 |
| A rows plus witness construction | 17.670 | 21.185 |
| A commit, encode plus Merkle | 16.562 | 3.995 |
| H commit, encode plus Merkle | 18.126 | 3.625 |
| U8 H helper construction | 6.911 | 8.844 |
| A opening | 5.154 | 9.179 |
| Lookup construction plus histogram | 0.517 | 0.748 |'''

clocks='''| Owner run, 1.1B / T128 / one cold pass / 16 Rayon threads | CPU s | GPU-assisted s |
|---|---:|---:|
| Guarded process | 175.258632 | 161.857226 |
| Model load, not isolated startup | 10.862 | 10.038 |
| Prove run | 153.072 | 135.809 |
| Witness, parity and extraction within prove run | 13.236 | 15.899 |
| Prove run minus witness; includes boundaries/serialization/sink | 139.836 | 119.910 |
| In-process verification | 10.514 | 10.148 |
| Fresh-process verification | uninspected | uninspected |
| Serialization and startup fraction | unisolated | unisolated |'''

report=f'''# ZKP efficiency progress — cycle 0062

Run `{RUN}`; final checkpoint {now}.

**No native speedup established.** The completed local experiment identifies
a capacity candidate, while new owner phase clocks redirect the speed queue
toward D/F zero-checks.

Python differential validation passed 48 fixtures, 288 domains, 4,176 columns,
23,834 i64 comparisons and 12,328 Fp2 helper values, with 11 negative controls
and five extra generic fallback expressions. Seed 2026101762; one CPU0 thread,
nice 19, 59-second CPU/wall and 512-MiB address-space caps. Final run:
1.050006 s / 17,464 KiB RSS. Separate accounting/source audit: 235 checks,
0.011948 s / 14,904 KiB. Commands, executed source hashes, hardware, limits
and controls are in the [experiment](../experiments/lookup-borrow-catalog-20261017/README.md).
An initial audit delimiter error is preserved and corrected.

The source-derived current lookup catalog matches an independent semantic
catalog. An independent ctypes/direct-inversion reference checks integer and
helper values. Tests include signed extrema, full padded/oversized prefixes,
invalid bucket-0 fallback, odd helper counts, and present/absent/out-of-range
zero-denominator refusals. Native Rayon execution and whole-proof privacy
were not tested. All 22 public layer manifests agree on lookup-affecting shifts.

The [review patch](../experiments/lookup-borrow-catalog-20261017/protocol-candidate.patch)
uses per-invocation Cow slices for public identity lookups and retains owned
wrapping arithmetic for other expressions. It changes histogram plumbing;
existing H-helper bodies and the drop boundary are unchanged. At TinyLlama
T128, 57 of 83 descriptors can borrow: looked payload 221.25 MiB becomes
53.75 MiB owned, avoiding 167.5 MiB (75.706%). This is a source count, not
measured peak or traffic. No witness/A/H/mask/term is removed in the proposal.
Larger-context and 8B rows are hypothetical counts, not admission or fit.
Patch is uncompiled/unapplied; [handoff](../handoffs/20261017-borrowed-lookup-columns.md)
names exact interfaces, source pins and owner gates. Production is untouched.

New owner R4 CPU and GPU-assisted phase runs both completed during this cycle.
They share the trained statement identity and have 22 phase tables plus a
final proved event and successful guard/terminal records. Each receipt is
497,665,904 B. These are shared-host n=1 diagnostics using R3 binaries and
existing instrumentation, not a controlled optimization A/B. They have
in-process verification but no fresh-verifier evidence inspected here;
**zero newly credited positions**. Only filtered public phase/statistic lines
and metadata hashes are retained; no private payload was copied.

{clocks}

GPU: one RTX 4070 Laptop, sm89, 36 SMs; guard peak VRAM 3,105 MiB and host
RSS 3.07 GiB. CPU guard peak RSS 4.81 GiB. Peak telemetry is diagnostic.
Driver/power settings were not re-established here. Pure proof arithmetic,
serialization, startup, proof lag/drain and steady slopes remain unisolated.

{phase_table}

D/F masked-sumcheck substeps on the GPU-assisted run total 19.860/16.457 s;
extension rounds add 4.871/1.583 s. These phases now outrank a softmax-only
assumption. Source `SC_FZC` still has extension multiplications by public
base constants; check its actual expression before proposing a narrow rewrite.

Deleting the entire lookup+histogram mark gives at most 1.002959x CPU /
1.004643x GPU directly, conditional on all other work staying fixed. Borrowing
retains histogram and H arithmetic. Indirect allocator/cache effects are
unknown, so it remains a capacity candidate. Complete 8B speed ceiling is
unknown: N/(total - removed critical-path work + added costs). No conversion
of 75.7% buffer savings into a proving speedup is justified.

Separately retained R3 GPU T128 diagnostic: 142.783399 s process, 12.872 s
witness, 107.079 s prove-minus-witness including sink, 8.451 s fresh verify
excluding 11.307 s verifier load, 497,665,904 B. Its 0.896463 positions/s is
a diagnostic for trained 1.1B; it establishes no accepted 8B rate. It must
not be combined with the new phase sample as a matched speedup comparison.

Ranked hypotheses, prerequisites, costs and falsifiers:

{queue}

LIVE source searches covered lookup/softmax/GKR and GitHub history/releases.
New older [HOBBIT](https://www.usenix.org/conference/usenixsecurity25/presentation/pappas)
and new [ring lookup work](https://eprint.iacr.org/2026/471) were assessed;
October 10 [StateSync-GKR](https://arxiv.org/abs/2610.14849) reuse/measurement
scope and repository licensing were refreshed. DeepProve history has a
release-labelled commit while its releases page is empty; no new release was
inferred. Five records appended, 320 total. Exact publication/history dates,
URLs, license scope, exposed versus inspected commits and fetch failures are
in sources.jsonl and web-search-notes.json. No author benchmark was reproduced.

Blockers: no native compile/Rayon/peak/byte/fresh-verifier gates for the patch;
new phase diagnostics lack inspected fresh-process verification; target 8B
proof and throughput measurements remain absent. Owner next: review D/F
phase source and select the largest recurring native opportunity. Local next:
source-captured F zero-check constant-multiplication differential/cost census.
Search rotation: memory traffic, then GPU NTT/commitments as the profile warrants.

{accounting}

Research only. No production/runtime/Git/receipt/calibration/gate/instruction/
reviewer-file changes, native build/proof/GPU/install/foreign execution,
external write/message or merge. Reports do not establish delivery or
supervisor liveness. Next cycle not before 2026-10-17T13:26:24Z.
'''
(B/'progress'/f'{RUN}.md').write_text(report)

short=f'''# ZKP efficiency progress

Cycle 0062 — `{RUN}`, completed 2026-10-17 UTC.

**No native speedup established.** The local experiment passed 48 synthetic
fixtures, 23,834 integer comparisons, 12,328 Fp2 checks and 11 negative controls
in 1.050 s / 17,464 KiB on one CPU thread. A separate 235-check audit passed.
The [unapplied patch](experiments/lookup-borrow-catalog-20261017/protocol-candidate.patch)
borrows identity lookup slices. TinyLlama T128 source counts avoid 167.5 MiB
of lookup payload (75.7%); actual peak and runtime gains remain unknown.

New owner GPU-assisted clocks redirect the speed priority: D/F zero-checks
took 25.353/19.484 s, versus softmax 11.834 s. Lookup construction plus
histogram took 0.748 s of a 161.857 s process; deleting the entire mark gives
only 1.005x directly. Borrowing is a capacity candidate. These T128 / 1.1B /
22-block / one-pass phase diagnostics on the RTX 4070 Laptop lack inspected
fresh-process verification and add no credited tokens.

Five LIVE source records were appended. Next local experiment: capture the
actual F zero-check and test public base-constant multiplication shortcuts.
Owner next: native D/F optimization with whole-proof and enclosing clocks.
[Dated report](progress/{RUN}.md) contains both CPU/GPU phase tables,
all clock limits, rankings and sources; [handoff](handoffs/20261017-borrowed-lookup-columns.md)
contains the capacity candidate's validation gates.

{accounting}

Research only; no production/runtime/Git/build/proof/GPU/external messages.
Saved reports do not imply user delivery.
'''
(B/'PROGRESS.md').write_text(short)

finding=f'''\n\n## Cycle 0062 — 2026-10-17 — borrowed lookup catalog; trained GPU phase correction

Run `{RUN}`. [Experiment](experiments/lookup-borrow-catalog-20261017/README.md),
[results](experiments/lookup-borrow-catalog-20261017/result.json),
[handoff](handoffs/20261017-borrowed-lookup-columns.md),
[dated report](progress/{RUN}.md). All historical findings remain intact.

**Tested question:** can current R3/R4 identity lookup expressions borrow an
existing padded witness slice rather than materialize another i64 column?
Yes in a synthetic semantic differential, including scaled expressions whose
public coefficient is 1. The current constructor has only single-plane terms;
general affine/multiterm cases retain owned fallback. Cow plumbing preserves
the original helper bodies, full padded prefixes, invalid bucket-0 behavior,
whole-table denominator refusals and drop order in the uncompiled proposal.
No private state or mask is reused across proofs.

48 fixtures, 288 domains, 4,176 columns, 23,834 i64 comparisons, 12,328 Fp2
helper values and 11 negative controls pass; five extra generic expressions
exercise fallback. Final run 1.050006 s / 17,464 KiB; independent 235-check
audit 0.011948 s / 14,904 KiB. Seed 2026101762, CPU0, one thread, nice 19,
59-second/512-MiB caps. The audit independently checks 12 closed-form census
rows and all 22 public layer manifests. Initial audit span-delimiter failure
is preserved and corrected. No native build/Rayon/proof/GPU/private payload.

At TinyLlama T128, 57/83 descriptors borrow: 221.25 MiB looked payload becomes
53.75 MiB owned, avoiding 167.5 MiB (75.706%). These are source payload counts,
not measured RSS/traffic/time. Final witness/A/H/masks/terms are unchanged in
the proposal. Added costs: classification/descriptors/generic histogram and
compiler/task-balance effects. Larger-context and 8B rows use hypothetical
geometry/calibration; no admission, fit or native speed claim follows.

**Decisive priority correction:** owner R4 instrumented T128 runs completed
during this cycle. CPU/GPU-assisted process 175.258632/161.857226 s; witness
13.236/15.899 s; prove-minus-witness 139.836/119.910 s includes boundaries,
serialization and sink; in-process verify 10.514/10.148 s. Startup and
serialization remain unisolated. Both use 22 linked trained 1.1B blocks,
one cold pass, 16 Rayon threads, n=1, and 497,665,904-B receipts. Guard records
and final events match; fresh-process verifier evidence was not inspected,
so these samples contribute zero credited positions. GPU is RTX 4070 Laptop.
Only filtered public timing/statistic lines and metadata hashes were retained.

GPU D/F zero-checks cost 25.353/19.484 s, softmax 11.834 s; D/F masked
sumcheck substeps cost 19.860/16.457 s. Commit A/H is 3.995/3.625 s. Lookup
construction plus histogram is just 0.748 s (CPU 0.517 s). Even deleting that
whole mark gives at most 1.004643x GPU / 1.002959x CPU directly with other
work fixed. Borrowing keeps histogram/H arithmetic, so demote it for speed
while retaining its unmeasured capacity opportunity. Do not transplant the
old synthetic softmax bottleneck into trained profiles. Source-captured
`SC_FZC` at argument.rs:1602 still uses extension multiplication by public
base constants; this is the next local test, with compiler effects unknown.

LIVE literature/implementation review added five source records (320 total).
New older HOBBIT, ring lookups, recent StateSync-GKR scope and repository
licensing/release metadata were assessed; source details and primary links
are in the dated report/sources.jsonl. No author performance was reproduced.
All access failures and uninspected exposed commit identifiers are explicit.

Current ranked queue:

{queue}

Next owner: D/F native phase optimization and all receipt/privacy/byte gates.
Next local: source-captured F polynomial base-constant specialization, with an
independent full-extension reference, pad/helper/host controls and exact cost
census. Histogram deduplication is demoted because its measured parent is tiny.
The borrow handoff remains review-only; no native build or heavy job queued.

{accounting}
'''
old=(H/'startup/FINDINGS.md').read_bytes(); current=(B/'FINDINGS.md').read_bytes()
assert current.startswith(old)
assert current[len(old):].decode().count('## Cycle 0062')==1
(B/'FINDINGS.md').write_bytes(old+finding.encode())

state=f'''# ZKP efficiency explorer — durable state

Cycle 0062 COMPLETE: `{RUN}`; checkpoint {now}.
AGENDA, current target and durable/project memory read. Startup snapshot:
experiments/lookup-borrow-catalog-20261017/startup/. Latest three research
results read/pinned. Read 315 sources; appended five LIVE records, 320 total.

Local result: 48 fixtures / 288 domains / 4,176 columns / 23,834 i64 words /
12,328 Fp2 checks, 11 controls and five generic fallbacks pass. 1.050006 s,
17,464 KiB; independent 235-check audit 0.011948 s / 14,904 KiB. Seed
2026101762, CPU0, one thread, nice19, 59-second/512-MiB caps.
Per-proof Cow borrows identity lookup slices, including public scaled-1 cases.
TinyLlama T128 source count: avoid 167.5 of 221.25 MiB lookup payload;
53.75 MiB remains owned. Final witness unchanged. All 22 public manifest
shift pins agree. Actual peak/traffic/native time unknown. Patch uncompiled,
unapplied: handoffs/20261017-borrowed-lookup-columns.md. Audit failure retained.

NEW owner R4 CPU/GPU-assisted phase diagnostics completed during this cycle:
trained 1.1B, 22 blocks, T128, one cold pass, 16 threads, n=1. Process
175.258632/161.857226 s; load 10.862/10.038; witness 13.236/15.899;
prove_run 153.072/135.809; prove-minus-witness 139.836/119.910 includes
boundary/serialization/sink. In-process verify 10.514/10.148; fresh verifier
not inspected, zero newly credited positions. Receipt 497665904 B. GPU:
RTX 4070 Laptop; guard VRAM peak 3105 MiB, RSS 3.07 GiB (CPU 4.81 GiB).
Startup/serialization/steady slope/lag/drain unisolated. Filtered public
phase lines and metadata hashes saved; no private payload retained.

GPU D/F zero-checks 25.353/19.484 s, softmax 11.834; D/F shared masked
sumchecks 19.860/16.457 s, extension rounds 4.871/1.583. Commit A/H
3.995/3.625. Lookup+histogram 0.748 s (CPU 0.517); conditional full-mark
deletion ceiling only 1.004643x GPU / 1.002959x CPU. Borrowing demoted for
speed, retained for capacity. Historical synthetic softmax share superseded
as a trained bottleneck assumption; this is no controlled speedup A/B.

Prior R3 T128 GPU fresh-verified diagnostic: 142.783399 s process,
12.872 witness, 107.079 prove-minus-witness including sink, 8.451 fresh
verify plus 11.307 verifier load, 0.896463 diagnostic positions/s. No 8B
credit. D24 conditions are not trained privacy acceptance; R2/R3 exports
differ, so the 529-to-56-second headline is not a controlled A/B.

Ranked hypotheses:
1 OWNER: D/F recurring GPU zero-checks; exact polynomial/final/RNG/PCS/
  transcript/byte/privacy/fresh-verifier gates; charge transfer and scratch.
2 OWNER: complete resident fixed-context fresh-proof slopes, public setup
  reuse only, count verification/lag/drain and fresh masks every pass.
3 TESTED: borrowed lookup capacity; native compiler/Rayon/peak/time gates
  owed, tiny direct time ceiling, final witness unchanged.
4 NEW NEXT LOCAL: capture exact current SC_FZC closure (argument.rs:1602)
  and census/differential public-base-constant mul_base specialization.
  It still uses extension p1/k_h/k_g multiplies; D/softmax Stage35 work is
  already present. Include pad/helper/host/full-extension controls; compiler
  may simplify already. Full F-slot deletion ceiling 1.136852x on this
  one GPU diagnostic; candidate can remove only a subset. No 8B estimate.
5 DEMOTED: duplicate Lk histogram scans, 8.36% of a tiny parent phase;
  retain previous witness/int8 candidates and all negative findings.
  HOBBIT/other architecture leads need PCS/streaming/privacy review.

Next owner: select D/F native opportunity from these clocks, then shared
guard builds/oracles/frozen bytes/fresh verification and enclosing workload.
Borrow patch only if measured capacity warrants it. Recompare pins first.
Next local: source-captured full F-polynomial reference and operation census;
never copy private witnesses/RNG. Search memory traffic then NTT/commitments.

{accounting}

Research only; no production/runtime/Git/calibration/receipts/gates/
instructions/reviewer-file changes, native build/proof/GPU/install/foreign
execution/external write/message/merge. No heavy job queued. Reports do not
establish delivery or supervisor liveness. Next cycle >=2026-10-17T13:26:24Z.
'''
(B/'STATE.md').write_text(state)

# Preserve the earlier checkpoint's interpretation and the evidence that changed it.
(H/'final-phase-update.json').write_text(json.dumps(dict(checkpoint_utc=now,change='GPU phase diagnostic completed after first report; speed priority reranked to D/F; histogram dedup demoted; next local full F closure specialization',cpu_proof_path=cpu['source_path'],gpu_proof_path=gpu['source_path'],newly_credited_positions=0,reason='No independent fresh-verifier evidence inspected for these new samples'),indent=2)+'\n')
print(json.dumps(dict(status='finalized',checkpoint=now,sources=320,run_id=RUN)))
