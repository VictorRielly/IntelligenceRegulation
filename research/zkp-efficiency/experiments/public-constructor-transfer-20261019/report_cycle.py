"""Checkpoint cycle0086. Writes research artifacts only; no notifications."""
import datetime
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RUN='20261019T181854Z-f5bd1f03'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((HERE/'result.json').read_text())
a=json.loads((HERE/'audit-result.json').read_text())
l=json.loads((HERE/'payload-ledger.json').read_text())
assert r['status']==a['status']=='PASS'

sources=[
 dict(title='Expander public clone and batch scratch allocation leads, newly assessed historical metadata',url='https://github.com/PolyhedraZK/Expander/commits/main/',
      published=None,updated=None,
      date_evidence='Primary history lists clone_for_batch on2026-03-20, ScratchPadBatch on2026-03-21, and resident-tree lifetime work2026-07-20. Not verified current HEAD. Exact diffs failed Cache miss/InternalError.',
      displayed_uninspected_commits=['01a35d8','302fc4a','096581e'],
      implementation_license='AGPLv3 text read in current main/LICENSE. No code adopted; historical commit license not verified.',
      inspected_urls=['https://github.com/PolyhedraZK/Expander/blob/main/LICENSE','https://github.com/PolyhedraZK/Expander/releases'],
      assessment='New older allocation/ownership lead only. Shared public descriptors do not authorize witness/mask reuse. Actual source/diff unavailable, no implementation or speed factor assessed.'),
 dict(title='Bits Under ZK-LLM: refreshed quantization and complete-clock boundary',url='https://arxiv.org/abs/2609.36437',published='2026-09-29',updated=None,
      date_evidence='Primary v1 history2026-09-29 00:54:35UTC; HTML AppendixE inspected.',implementation_license=None,
      inspected_urls=['https://arxiv.org/html/2609.36437v1'],
      assessment='Known source refreshed. GPT2 cost rows use T16,batch1,32CPU threads and exclude graph preparation,inference,verification. QDQ utility leaves several operators floating. No precision reduction or performance transfer authorized; D32 remains binding.'),
 dict(title='zkLLMPoT v2: October operator/commitment accounting refresh',url='https://arxiv.org/abs/2610.08258',published='2026-10-06',updated='2026-10-11',
      date_evidence='Primary v1 Oct6 12:35:49UTC; v2 Oct11 04:45:08UTC. Third-party search incorrectly suggested Oct7; primary used.',implementation_license=None,
      inspected_urls=['https://arxiv.org/html/2610.08258v2'],
      assessment='Known source refreshed. Dense-weight commitment is separate from covered operators; nonlinear and opening-preparation costs include fitted/interpolated terms. Auditor sequences differ from private-prompt target. Not a reproduced complete private8B rate.'),
 dict(title='zkLLM historical CUDA lookup/softmax and independent-verifier boundary refresh',url='https://arxiv.org/abs/2404.16109',published='2024-04-24',updated=None,
      date_evidence='Primary v1 Apr24,2024 18:04:50UTC. Current repository date not verified.',
      implementation_license='MIT, actual current repository LICENSE read; no code adopted.',
      inspected_urls=['https://github.com/jvhs0706/zkllm-ccs2024','https://github.com/jvhs0706/zkllm-ccs2024/blob/main/LICENSE'],
      assessment='Known older source refreshed. Author repository explicitly describes side-by-side interactive prover/verifier components requiring redesign for independent noninteractive use. CUDA lookup techniques need exact relation and privacy review; author gains not reproduced.'),
 dict(title='When Proofs Meet Hardware: memory availability and primitive comparison refresh',url='https://arxiv.org/abs/2606.16146',published='2026-06-15',updated=None,
      date_evidence='Primary v1 Jun15,2026 03:03:54UTC.',implementation_license=None,
      assessment='Known source refreshed. Equal SRAM/bandwidth primitive comparison does not turn a vector lifetime reduction into end-to-end proving speed. No implementation execution, GPU transfer or rate reproduced.'),
 dict(title='Plonky3 release lookup: fresh retrieval has inconsistent cached release views',url='https://github.com/Plonky3/Plonky3/releases',published=None,updated=None,
      date_evidence='Retrieved page displays v0.8.0 on Sep23 20:02, without year. Prior cycle retrieved October rc2. Do not assert newest release, date year or current HEAD from this view.',implementation_license=None,
      displayed_uninspected_commits=['a21e3ed'],
      assessment='Lists fused FRI/hiding LDE and bind/measure sumcheck changes. Exact PR2036 and rc2 page failed Cache miss. A lead, not source-inspected code, timing evidence or permission to change masks/transcript.'),
 dict(title='Small-table nonlinear protocols: older metadata refresh',url='https://eprint.iacr.org/2025/507',published='2025-03-20',updated=None,
      date_evidence='Primary received2025-03-18, approved2025-03-20; labels major revision of USENIX Security2024 work. No inferred2024 ePrint date.',implementation_license=None,
      assessment='Known older lead refreshed; no PDF/code implementation inspected this cycle. Existing native byte lookup and exact division remain the baseline. No author speed ratio reproduced.'),
]
for s in sources:
    s.update(run_id=RUN,cycle='0086',access_date='2026-10-19',recorded_at_utc=now,
             evidence_kind='Native LIVE web search/open/find/click; primary pages; untrusted source text not executed',
             inspected_commit_id=None,reproduced_performance=False,external_execution=False)
(HERE/'source-records.json').write_text(json.dumps(sources,indent=2)+'\n')
old=(HERE/'startup/sources.jsonl').read_bytes()
current=(ROOT/'sources.jsonl').read_bytes()
assert current.startswith(old)
if RUN.encode() not in current[len(old):]:
    with (ROOT/'sources.jsonl').open('a') as f:
        for s in sources:f.write(json.dumps(s,sort_keys=True)+'\n')
source_count=len((ROOT/'sources.jsonl').read_text().splitlines())

prior=json.loads((HERE.parent/'public-owner-identity-20261019/hypotheses.json').read_text())
queue=[prior[0],prior[2],prior[1],prior[3],prior[4]]
queue[1].update(hypothesis='NEW tested: checked public constructor ownership transfer with full loader lifetime',
    eliminated_work='12 to_vec allocations and243410944 copied vector bytes per T128 8B load, COUNTED unbuilt proposal; raw reads, decode, padding and all checks remain.',
    added_costs='Owned API and loader destructuring, native validation/re-pin and allocation measurement. No new protocol work; no code port executed.',
    baseline='Frozen R8 keeps218114560 raw11 bytes,243277824 padded i8 bytes,cos/sin originals and243411456 public payload; full record hashes may allocate all9 padded byte buffers concurrently.',
    end_to_end_ceiling='Candidate unknown. Deleting all27.151s sealing-load tasks +17.595s prove-load tasks at zero cost gives only1.103104x on carried478.737s CPU diagnostic, an optimistic ceiling; actual exclusive copy cost unisolated. No GPU prediction.',
    exactness='48 synthetic fixtures,2200 refusal mutations, encoding and first-error classes match independent references. No native check/proof equivalence claimed.',
    prerequisites='Owner review of unbuilt patch, locked native CPU byte/refusal/parity checks and fresh independent verification; separate source-pin/privacy re-gate as required.',
    falsification='Native byte/refusal mismatch, lost gate or source freshness, no actual allocation removal, increased peak or added costs>=exclusive saved work.')
queue.insert(3,dict(hypothesis='NEW next local: direct signed-byte padding from verified Array.bytes',
    baseline='Array::i8s allocates a temporary for each pad_matrix call; largest raw matrix58720256B at8B.',
    eliminated_work='Potential signed decode Vec and one copy before padding; full raw source and padded output still needed.',
    added_costs='Checked byte reader, signed reinterpretation, row/head mapping, integration and source-digest validation.',
    end_to_end_ceiling='Unknown; full sealing record scratch currently dominates enumerated payload envelope, so padding-only temporary removal may not lower peak.',
    prerequisites='Exhaustive256-byte signed oracle, true/head-slot and stride maps, invalid lengths/pads and original manifest/refusal gates.',
    integration_cost='Moderate local loader helper; owner only native port.',exactness='No quantization or integer-function change.',
    privacy_soundness='Public P1 arrays only; no private buffer/mask/opening reuse.',
    falsification='Any signed value, padding, shape, refusal or byte mismatch, or no enclosing benefit.'))
for i,h in enumerate(queue,1):h['rank']=i
(HERE/'hypotheses.json').write_text(json.dumps(queue,indent=2)+'\n')

target=json.loads((HERE.parent/'public-owner-identity-20261019/target-accounting.json').read_text())
target.update(run_id=RUN,workload='No proof workload ran; synthetic constructor fixtures only',
              context_length=None,device=None,passes=0,synthetic_scan_pairs=[],synthetic_layer_count=None,
              synthetic_payload_count_context=128,synthetic_fixture_count=48)
target['carried_owner']['all_load_deletion_optimistic_speedup_ceiling']=478.737/(478.737-27.151-17.595)
(HERE/'target-accounting.json').write_text(json.dumps(target,indent=2)+'\n')

baseline='''Carried owner R8 CPU 8B diagnostic: T128,32 blocks,one16-thread pass,
GPU off,n=1. Total478.737s (128/478.737=0.267370 positions/s diagnostic),
prove_run393.785s includes witness hand-over98.348s, itself including17.595s
block loads. Sealing wall84.824s includes overlapping27.151s load tasks and
80.897s witness tasks. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial load13.681s; recheck34.395s plus10.739s load.
Fresh guard wall165.982s includes controls. Startup fraction, isolated
serialization and steady slope are unmeasured. Researcher did not reverify
a receipt; no new target credit. Owner RSS6.69GiB/cgroup9.76GiB includes
existing allocations; do not add this public ledger to those peaks.'''
target_text='''New independently verified complete-stack proofs/passes/positions: **0/0/0**;
device none. Target steady-state/total-workload rates, startup fraction and
witness/proof/serialization/verification clocks: all unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic48
fixtures are constructor cases, not proof passes. Larger workloads remain
allowed; attention work can grow quadratically with context. Complete private
8B / >=50 proved positions/s on one RTX5090 or a named high-end GPU is
unchanged and unachieved. No fresh masks, private commitments or openings
were reused or changed.'''
next_action='''Owner: review the unbuilt two-file patch, then run locked native constructor
byte/refusal/parity gates and isolate allocation/copy clocks before any claim.
Whole-prover GPU and independently verified fixed-context resident1/2/4/8
workloads stay first. Next local: differential direct signed-byte padding
from Array.bytes versus i8s()+pad_matrix (all256 byte values, interleaved
query-head slots, strides, malformed lengths and zero-pad controls). Account
for whether removing58720256B decode scratch changes the dominant full-loader
peak; do not repeat cycle0027's completed public-digest streaming/cache study.'''
summary=f'''Cycle0086 — `{RUN}` — 2026-10-19 UTC.

**No speed improvement measured.** Checked public ownership transfer matches
48 synthetic layouts and preserves tested refusal/encoding outcomes. Native
R8 source shows12 vector clones totalling243410944B per8B T128 load that an
owned constructor could avoid. The512B inline activation copy remains.
No native code was modified, built or proved; proposed patch is unbuilt.

Main PASS {r['checks']} assertions / {r['rejected_mutations']} rejected mutations;
independent audit PASS {a['checks']} assertions /624 output-corruption controls.
Main/audit {r['wall_seconds']:.6f}/{a['wall_seconds']:.6f}s, peaks
{r['rss_kib']}/{a['rss_kib']}KiB, one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s/512MiB caps. These are synthetic validation clocks,
not a native constructor benchmark.18 pins unchanged;14 match frozen R8.

The previous pins4+current/next1.360168GiB ledger excluded loader temporaries.
This cycle counts raw/padded/owned buffers, decode/maps, optional RoPE reserve
and full sealing record hash scratch. Enumerated public-payload envelope with
four distinct pins+current+next load, accounting for16 native hash workers:
**2.016689GiB borrowed ->1.789997GiB moved** [MODEL]. One-worker ledger:
1.852619->1.625927GiB. Not actual RSS/VRAM, complete memory or hardware fit;
private witness/proof/device/allocator/page-cache costs remain excluded.
Evicted live leases from prior findings must still be charged separately.

{baseline}

{target_text}

{next_action}
'''
progress=f'''# ZKP efficiency progress

Cycle0086 — `{RUN}` — 2026-10-19 UTC.

**No speed improvement measured.** A source-pinned proposal would avoid12
public-vector copies (243410944B/load at8B T128).48 synthetic layouts and2200
refusal mutations pass; independent audit passes624 output-corruption controls.
The Rust patch is unbuilt/unapplied. Source lifetime accounting raises the
old pin4 public envelope to2.016689GiB; checked moves model1.789997GiB.
These are enumerated public payloads, not actual total memory or GPU fit.

Validation clocks: {r['wall_seconds']:.3f}s main/{a['wall_seconds']:.3f}s audit,
one low-priority CPU thread, peaks{r['rss_kib']}/{a['rss_kib']}KiB.
No native constructor/proof speed measured.18 pins/14 R8 manifest matches.
Independent audit caught and corrected double-counted scratch; that failure
and an earlier single-KV control classification failure remain preserved.

{baseline}

{target_text}

Seam: load_layer_mode -> checked owned AttentionPublic/FeedForwardPublic
constructors. Every existing check_words/CS/H-1/source freshness check stays.
Next: owner native gates and exclusive clocks; local direct signed-byte
padding oracle. Whole-prover GPU/resident verified workloads remain priority.
Seven LIVE primary-source records appended471->{source_count}; Expander clone/
scratch history is a new lead with exact diff access blocked; known lookup/
quantization sources refreshed. No external performance reproduced.

[Experiment](experiments/public-constructor-transfer-20261019/README.md),
[handoff](handoffs/20261019-public-constructor-transfer.md),
[dated report](progress/{RUN}.md).
Only research files written; saved reports do not establish message delivery.
'''
report=f'''# Cycle0086 — checked public constructor transfer

{summary}

Baseline and eliminated work: native Array objects keep eleven raw source
buffers until loader return; aw/fw hold nine padded i8 vectors. Borrowed
constructors check_words, then copy twelve vectors into the block. The owned
proposal calls the SAME check_words before moving those vectors and retains
the typed[i16;256] table and original constructor order. No IO, table generator,
hash, support scan, CS recheck, witness, mask or proof work is eliminated.
Added costs are API/lifetime integration and native validation; native timing
is absent. Even deleting ALL load task time at zero cost gives only
{target['carried_owner']['all_load_deletion_optimistic_speedup_ceiling']:.6f}x
on this CPU diagnostic. The copy subset is smaller; overlap lowers the bound.
No high-end GPU ceiling is known.

Falsification: any native byte, first refusal or gate mismatch; allocations
not actually avoided; actual peak regression; or overhead >= exclusive saved
copy time. Python consumed-wrapper checks model transfer, not Rust borrow
safety. Synthetic SHA256 framing is not native BLAKE3/transcript equivalence.

Negative findings retained: one KV group has tail-only head padding, so a
prefix map is valid there; the first test overclassified it, saved exit1.
An audit caught an accounting reservation accumulating between worker rows;
source, failed ledger and stderr saved before fixing. The final audit passes.
Key-only public owners, registry-only lease accounting, cyclic partial-LRU,
and repeated public digest claims remain rejected/demoted from prior cycles.

LIVE search rotation: lookup/softmax and quantization with memory ownership.
Seven records in source-records.json retain exact URLs/access dates/primary
date evidence/license qualifications. Expander's older clone/batch-scratch
history is newly assessed; exact PR/commit/source fetches were Cache miss or
InternalError, so inspected_commit_id stays null and short IDs are explicitly
uninspected. Plonky3 release views conflict with prior retrieval; do not infer
latest release/year. Known zkLLM, Bits Under ZK-LLM, zkLLMPoT and primitive
comparison refreshed; author evidence unexecuted. Next rotation GPU
NTT/commitments and sumcheck/GKR, retaining lookup/softmax,memory,batching,
quantization and proof composition in the queue.

Privacy/fidelity: D33 is trained TinyLlama T32 pg_rot1 CPU R7 only; R8/new
sources require re-pin and do not inherit8B/GPU coverage. D30's counted
dictionary is unbuilt; D32 thresholds stay binding. No P3 weight-cache or
mask/opening reuse is authorized.

Only research files changed. No runtime/production/Git/receipt/calibration/
safety/instruction/reviewer changes, downloads executed, installs, GPU jobs
or external messages. Reports alone do not establish delivery.
Checkpoint {now}.
'''
(ROOT/'PROGRESS.md').write_text(progress)
(ROOT/'progress'/f'{RUN}.md').write_text(report)
findings=(ROOT/'FINDINGS.md').read_bytes()
assert findings.startswith((HERE/'startup/FINDINGS.md').read_bytes())
if RUN.encode() not in findings[len((HERE/'startup/FINDINGS.md').read_bytes()):]:
    with (ROOT/'FINDINGS.md').open('a') as f:f.write('\n\n## Cycle0086 — 2026-10-19: checked public constructor transfer\n\n'+report.split('\n\n',1)[1])

handoff=f'''# Review handoff: public constructor moves, unbuilt proposal

{summary}

Patch: ../experiments/public-constructor-transfer-20261019/review-only-owned-constructors.patch
(UNBUILT, UNAPPLIED, not merged). Frozen R8 source hashes in source-pins.json.
Seam private_block.rs: AttentionPublic::new_shaped at521 and
FeedForwardPublic::new_shaped at658; trained_block.rs: load_layer_mode at921,
aw/fw at1037..1046. Full record scratch trained_statement.rs:474..497.

Interface proposal adds crate-private new_shaped_owned functions taking Vec
weights/RoPE/exp; each calls existing check_words, then moves into the same
private fields. FFN act remains &[i16] -> [i16;256] after the same check.
Loader destructures aw/fw and hands vectors across once. Borrowed entry
points remain available. Native check_words, at-use rechecks, source
SHA/digest/table/calibration admission, CS1/3/4/6/8/9 and H-1 stay unchanged.

Owner acceptance before integration: inspect and compile in owned lane under
shared locks; differential constructor bytes and refusal order at toy/rung,
ragged multi-KV and trained shapes; seeded complete receipts and all tamper/
source-change controls; separate-process verifier; actual allocation/copy
and current/next/lease peaks. Re-pin any changed privacy-gate source. No speed
or privacy acceptance follows from this Python model or uncompiled patch.
No production write or merge was made by this researcher.
'''
(ROOT/'handoffs/20261019-public-constructor-transfer.md').write_text(handoff)
(HERE/'README.md').write_text(f'''# Checked public constructor transfer — cycle0086

{summary}

Reproduce (each <=59s CPU/wall,512MiB address space,one nice19 CPU):

```
python3 -B experiments/public-constructor-transfer-20261019/run_bounded.py experiment.py
python3 -B experiments/public-constructor-transfer-20261019/run_bounded.py audit.py
```

Seed2026101986. Six shape patterns repeated with independent random public
fixtures: (query heads,KV heads,head dim,FFN width) =
(2,1,2,5),(6,2,2,11),(12,4,2,19),(8,2,2,16),(3,1,4,9),(12,4,4,25).
Token axis3 is a synthetic table extent, not an admitted native context.
Candidate row-copy/scatter padding is compared with per-destination inversion;
constructor checks use a separate support-set/error-class reference. Separate
audit imports no candidate and reconstructs every byte/length-delimited SHA
encoding from raw public miniatures. Raw signed samples include i8 extrema;
tables are structure fixtures, not the real exp/SiLU/RoPE generators.

Mutation coverage: all13 array lengths, off-support entries for all9 matrices,
interleaved query support, RoPE range/initial row, exp scale/range/order,
act[128] at padded/unpadded FFN, first error class, consumed-wrapper reuse.
624 independent output-corruption controls belong to the artifact audit,
not additional candidate differential cases. Python ownership is a model;
no native Rust ownership, exact native error strings, CS checks or receipt
equivalence was executed. The review-only patch is uncompiled.

payload-ledger.json counts218114560 raw11 bytes,243277824 padded-i8 bytes,
243411456 public bytes at8B T128. Full sealing LayerRecord uses9 parallel
byte conversions;16-worker reservation is their SUM, one-worker reservation
their MAX. Actual concurrency/capacity/allocator/page-cache/private/proof/device
memory is unmeasured. Supports/maps and an optional generated-RoPE extra pair
are reserved. Reload skips LayerRecord and needs a different detailed timeline;
this full-sealing ledger does not claim identical reload overlap.

An avoided copy volume is neither physical memory-bus traffic nor a time
saving. Current/pin blocks are distinct for the reported envelope; evicted live
leases require extra accounting. The inline512B act copy remains. Native
allocation behavior, critical-path savings and high-end GPU memory/throughput
remain unknown. Candidate ceiling and falsification are in hypotheses.json.

Source pins and startup snapshots preserve durable inputs. Initial test/control
failure and scratch-accounting audit failure remain under initial-control-
misclassification/ and before-support-reservation-fix/. commands.json records
exact argv/exits/source hashes; final invocations use distinct numbered logs.
search-log.md and source-records.json retain LIVE evidence/access failures.
No foreign code was executed or dependency installed.
''')
(ROOT/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0086 COMPLETE: `{RUN}`,2026-10-19 UTC.
Next cycle no earlier19:18:54 UTC. Deadline18:38:54 UTC.
[Dated report](progress/{RUN}.md).
Startup snapshots:experiments/public-constructor-transfer-20261019/startup/.

{summary}

Ranked hypotheses (full prerequisites/exactness/privacy/falsification in
experiment hypotheses.json):
1.Owner whole-prover GPU + independently verified resident1/2/4/8 workloads.
2.Tested checked public constructor transfer; native port/clock gates pending.
3.Guarded public owner with source freshness and full live leases.
4.NEW next local direct signed-byte padding, no raw decode Vec.
5.Owner same-attempt witness retention with prior negatives and H-1.
6.Owner D30 architecture with D32 fidelity and all privacy/soundness gates.

Seven LIVE source records471->{source_count}. Newly assessed older Expander
clone/scratch history has exact diff/code access blocked; no full commit was
inspected. Actual floating LICENSE AGPLv3 read, no code adopted. Known
lookup/quantization papers refreshed; no author results reproduced. Plonky3
release view stale/inconsistent, no newest release or date year claim.
Rotation: next GPU NTT/commitments and sumcheck/GKR; retain lookup/softmax,
memory,batching,quantization/arithmetic,proof composition.

Handoff:handoffs/20261019-public-constructor-transfer.md. Review-only patch
under experiment; UNBUILT/UNAPPLIED. 18pins/14manifest matches unchanged.
Preserve first single-KV control failure and independent scratch-ledger audit
failure; final gates PASS. Prior public-digest streaming/cache cycle0027
remains complete/demoted. Key-only owner, cyclic-LRU and registry-only lease
shortcuts remain rejected. No private masks or openings reused.

Only research written; runtime/production/Git/receipts/calibration/safety/
instructions/reviewer files untouched. Saved reports do not establish delivery.
Checkpoint {now}.
''')
print(json.dumps(dict(checkpoint=now,source_records=source_count,main=r['status'],audit=a['status'],report=str(ROOT/'progress'/f'{RUN}.md'))))
