"""Checkpoint one completed research cycle, preserving durable prior prefixes."""
import datetime
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RUN='20261019T191854Z-6444ea2f'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((HERE/'result.json').read_text())
a=json.loads((HERE/'audit-result.json').read_text())
assert r['status']==a['status']=='PASS'
sources=json.loads((HERE/'source-records.json').read_text())
old_sources=(HERE/'startup/sources.jsonl').read_bytes()
current=(ROOT/'sources.jsonl').read_bytes()
assert current.startswith(old_sources)
if current==old_sources:
    with (ROOT/'sources.jsonl').open('a') as f:
        for s in sources:f.write(json.dumps(s,sort_keys=True)+'\n')
else:
    assert [json.loads(l) for l in current[len(old_sources):].decode().splitlines()]==sources

baseline='''Carried owner R8 diagnostic: trained8B T128,32 blocks,one16-thread CPU
pass,GPU off,n=1. Total478.737s gives0.267370 positions/s diagnostic;
prove_run393.785s includes witness hand-over98.348s,which includes17.595s
block loads. Sealing wall84.824s contains overlapping load/witness tasks
27.151/80.897s. These clocks must not be added. Receipt922711264B.
Fresh verification42.709s plus initial public load13.681s; recheck34.395s
plus10.739s load. Fresh guard wall165.982s includes controls. Startup
fraction,isolated serialization and steady slope remain unmeasured.
Researcher did not reverify this artifact and gives no new target credit.'''

target='''New independently verified full-stack proofs/passes/positions: **0/0/0**;
device none. No proof context/workload ran. Steady-state and total-workload
proved rates,startup fraction,and new witness/proof/serialization/verification
clocks are all unmeasured. Synthetic48 layouts/432 matrices/3 byte sweeps are
validation cases,not proof passes. No long-context prefill,resident proof
series or decode ran. Larger workloads remain allowed; longer context can
increase attention work quadratically. Complete private8B / >=50 proved
positions/s on one RTX5090 or another named high-end GPU remains unchanged
and unachieved. No masks,private commitments or openings were reused.'''

summary=f'''**No speed improvement measured.** Direct signed-byte padding matches
432 synthetic matrices across48 layouts and three exhaustive0..255 byte
sweeps. Main{r['checks']} assertions,1728 malformed/type/shape controls and
942 wrong-output controls pass; independent audit{a['checks']} assertions
and{a['output_corruption_controls']} output-corruption controls pass.
Main/audit clocks{r['wall_seconds']:.6f}/{a['wall_seconds']:.6f}s,peaks
{r['rss_kib']}/{a['rss_kib']}KiB,one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps. These are synthetic
validation clocks,not native padding benchmarks.18 pins unchanged;14 match
frozen R8. Review-only58-line Rust patch is UNBUILT/UNAPPLIED.'''

memory='''Counted work removed: nine complete signed-byte decode vectors totaling
218112000B/load (208.0078125MiB); largest58720256B (56MiB) at8B. Raw arrays,
padded public weights,table checks,hashes,constructors and all proof work stay.
The proposed safe cast loop replaces the identity branch's copy_from_slice;
compiler vectorization and any time benefit are unmeasured. At8B32 query heads
fill32 slots,so head maps are identity; this branch needs native measurement.

Decisive negative: every full-sealing public-payload envelope in the prior
one/16-worker,pins0/4,borrowed/owned ledger has **0B** reduction. The padding
envelope falls520672256->461952000B,but later record hashing dominates.
Four pins+current+next remain2.016689GiB borrowed and1.789997GiB with prior
owned constructors at16 hash workers [MODEL]. These are enumerated public
payload bounds,not actual RSS/VRAM,complete memory or hardware fit. Private
witness/proof/device,allocator/page-cache costs and extra live evicted leases
remain excluded. Do not subtract56MiB from the measured owner peak.'''

next_action='''Owner: review the unbuilt one-file patch,then under shared locks run
native byte/first-refusal/record/receipt gates and exclusive decode+padding
clocks before promotion. Adjacent edits overlap the prior ownership patch's
loader context and need rebase; neither patch is integrated here.

Next local: differential public raw-array last-use/release before
LayerRecord::of_block,including full/reload paths,malformed inputs and exact
record/metadata bytes. Preserve all source freshness,CS and H-1 checks;
recompute every phase maximum rather than subtract218114560B from the peak.
Do not repeat cycle0027 public-digest streaming/cache or prior key-only/LRU/
registry-only lease shortcuts. Owner whole-prover GPU and independently
verified fixed-context resident1/2/4/8 complete workloads remain first.'''

sources_text='''Seven LIVE primary records appended478->485: newly assessed FluxZK,
older MoMA and recent Impeller; refreshed Chimera's October16 revision and
ICICLE v4 release. Source records distinguish future venue dates from
publication,conflicting FluxZK activity views,and actual SPIRAL license
inspection from unavailable component licenses. Only ICICLE's Cargo-version
bump commit was inspected; it validates no kernel. Several exact history,
license and code requests failed with Cache miss/InternalError; no bypass.
The inaccessible2026/2494 primary lead remains unverified. No author
performance reproduced. Rotation next lookup/softmax and proof composition;
retain memory,batching,quantization/arithmetic and GPU work.'''

report=f'''# Cycle0087 — direct signed-byte padding

Run `{RUN}` —2026-10-19 UTC.

{summary}

{memory}

{baseline}

Even zero-cost deletion of ALL27.151+17.595s load tasks leaves433.991s,
an optimistic1.103104x /0.294937 positions/s CPU diagnostic ceiling. This is
not this candidate's saving; overlap and the smaller selected cost reduce it.
No high-end GPU end-to-end ceiling can be inferred.

Validation scope: independent per-destination signed decode reference and
separate persisted-artifact reconstruction cover all nine matrices,identity
and grouped query-head maps,true input stride,padded output stride and zeros.
Unsigned output is checked as signed values: byte hashes alone cannot detect
that error. Length/type/shape checks run in a synthetic prevalidation wrapper;
they do not execute native refusal messages or IO races. SHA256 artifact
digests are not native BLAKE3/receipt equivalence. Proposed diff preserves
native admission,table generators,constructor support checks and H-1.

Falsify if native bytes/records/first refusal/receipt change,any decode Vec
survives,the cast loop costs at least the saved copy work,or actual memory
regresses. Exact placement is reproduced; a proving improvement is not.

Ranked queue (full costs/prerequisites/privacy/exactness in hypotheses.json):
1.Owner whole-prover GPU + verified resident1/2/4/8 workloads.
2.Prior checked public constructor transfer,native gates/clock pending.
3.NEW public raw-array release before record hashing,next local test.
4.Tested direct-byte padding,demoted for unchanged full-loader envelope.
5.Guarded public owner with freshness and complete live lease accounting.

{target}

{next_action}

{sources_text}

D33 covers trained TinyLlama T32 pg_rot1 CPU R7 only; R8/new files need the
gate re-pin,and8B/GPU do not inherit that acceptance. D30 remains an unbuilt
construction; D27 soundness and D32 fidelity thresholds remain binding.
P1 hides inputs,outputs and intermediates; P3 weight privacy is not weakened.

Only research files written; no runtime,production,Git,receipt,calibration,
safety,instruction or reviewer files changed. No native builds,GPU jobs,
dependency installs,downloaded code execution,external writes/messages,
purchases or escalation. Saved reports do not establish message delivery.
Checkpoint {now}.
'''
(HERE/'README.md').write_text(report+'''
Reproduce each bounded authored check:

```
python3 -B experiments/direct-signed-byte-padding-20261019/run_bounded.py experiment.py
python3 -B experiments/direct-signed-byte-padding-20261019/run_bounded.py audit.py
python3 -B experiments/direct-signed-byte-padding-20261019/run_bounded.py validate.py
```

Seed2026101987. Six independent fixture patterns for each of eight synthetic
(query_heads,KV_heads,head_dim,FFN_width) tuples:
(2,1,2,5),(6,2,2,11),(12,4,2,19),(8,2,2,16),(3,1,4,9),
(12,4,4,25),(4,2,4,17),(16,4,2,31). These are public matrix fixtures,
not admitted native contexts or token sequences. No real private data used.
prepare.py snapshots18 source/evidence pins and generates the review patch
without applying it. commands.json retains exact argv,source hash,exit and
numbered logs. startup-manifest.json preserves all required durable inputs.
source-records.json/search-log.md retain qualified LIVE source evidence.
payload-ledger.json and independent audit retain the peak-negative result.
''')
(ROOT/'progress'/f'{RUN}.md').write_text(report)
prior_findings=(HERE/'startup/FINDINGS.md').read_bytes()
assert (ROOT/'FINDINGS.md').read_bytes().startswith(prior_findings)
if RUN.encode() not in (ROOT/'FINDINGS.md').read_bytes()[len(prior_findings):]:
    with (ROOT/'FINDINGS.md').open('a') as f:
        f.write('\n\n## Cycle0087 — 2026-10-19: direct signed-byte padding\n\n'+report.split('\n\n',1)[1])

progress=f'''# ZKP efficiency progress

Cycle0087 complete — `{RUN}` —2026-10-19 UTC.

**No speed improvement measured.** Direct signed-byte padding passes432
synthetic matrix cases and three exhaustive byte sweeps. Main/audit:
5602/2725 assertions;1728 prevalidation and942 wrong-output controls,
plus864 independent corruption controls. Validation clocks0.298/0.087s,
peaks25924/19196KiB,on one low-priority CoreUltra9 185H CPU thread.

The proposal avoids nine decode vectors totaling218112000B per8B layer load.
Largest temporary56MiB. **Full-loader modeled peak reduction:0B**, because
later public record hashing dominates every carried worker/pin/constructor
case. Actual allocations and speed remain unmeasured. The Rust patch is
unbuilt/unapplied;18 native/evidence pins match,14 match frozen R8.

Carried owner CPU diagnostic:T128,32 blocks,one16-thread pass,GPU off;
478.737s total (0.267370 positions/s),prove_run393.785s including witness
hand-over98.348s;sealing84.824s. Loads are nested/overlapped. Fresh verify
42.709s plus load13.681s. Startup fraction,steady rate and isolated
serialization unmeasured; researcher did not reverify that receipt.

New verified proofs/passes/positions **0/0/0**,device none; no proof context,
prefill,resident series or decode ran. New steady/total rates,startup fraction
and witness/proof/serialization/verification clocks are unmeasured.
The private8B / >=50 proved positions/s GPU target is unchanged/unachieved.

Seam:validated Array.bytes -> private pad_matrix_bytes; native gates and
exclusive copy clocks owed. Next local:raw-array release before record
hashing. Owner whole-prover GPU and verified resident workloads remain first.
Seven LIVE sources recorded,including FluxZK,MoMA,Impeller,Chimera and ICICLE;
no external performance reproduced. Exact-date/license/access limits saved.

[Experiment](experiments/direct-signed-byte-padding-20261019/README.md),
[handoff](handoffs/20261019-direct-signed-byte-padding.md),
[dated report](progress/{RUN}.md).
Only research changed; saved reports do not establish message delivery.
'''
(ROOT/'PROGRESS.md').write_text(progress)

handoff=f'''# Review handoff: direct signed-byte public padding

Run `{RUN}`,cycle0087. **UNBUILT/UNAPPLIED; no native speed result.**

Interface:replace the private loader's pad_matrix(&array.i8s(),...) with
pad_matrix_bytes(&array.bytes,...)->Vec<i8>. Frozen source:
hashline/src/private_block/trained_block.rs:349,1038,1131. Input is the SAME
Array.bytes already checked by load_array_checked and Array::expect for
dtype,shape and exact length; true dimensions/maps come from Shape. Every
generator,constructor support/CS,source/digest and H-1 check stays.

Patch:
`../experiments/direct-signed-byte-padding-20261019/review-only-direct-signed-byte-padding.patch`.
One file,58 diff lines,against frozen R8. Native source/evidence hashes in
source-pins.json,18 unchanged/14 checked against manifest_frozen.json.
candidate-trained_block.rs is a research snapshot only. The prior public
owned-constructor proposal touches adjacent loader context; owner must rebase
if combining them. Neither is integrated or merged here.

Implementation:keep zero-filled Vec<i8>,source-row inversion,inner maps and
Rayon destination-row scheduling. Read original u8 bytes and cast at each
destination; no complete signed decode vector or unsafe reinterpretation.
The identity branch uses a cast loop instead of copy_from_slice. At8B the
query map is identity; native vectorization/copy efficiency is an open risk.

Validation:432 matrices/48 public layouts,3 exhaustive byte sweeps,5602 main
assertions,1728 synthetic prevalidation and942 wrong-output controls;
independent audit2725 assertions/864 corruption controls. Main/audit
0.297901/0.086999s,25924/19196KiB,one nice19 CPU. Synthetic prevalidation does
not execute native refusal semantics; artifact SHA256 does not prove native
receipt identity. Real generators,CS/native IO races,Rust compilation and
native proof gates remain owed. No real private prompts/weights/activations.

Counted scope:9 decode allocations/218112000B per8B load eliminated;56MiB
largest temporary. Full sealing payload ledger has0B peak reduction in all8
cases:later record hash scratch dominates. With4pins/current/next and16
hash workers the envelope remains2.016689GiB borrowed or1.789997GiB with
the prior move proposal [MODEL]. Not actual RSS/VRAM/fit or saved time.
All-load deletion's loose CPU diagnostic ceiling is1.103104x; this subset
must be smaller. No GPU ceiling or throughput claim.

Owner validation before promotion:build under shared lock; differential native
padding/record digests and first-refusal controls at actual shapes; exact
byte/seeded receipt+independent verifier gates; unchanged H-1,source freshness,
CS and refusal-before-header checks; compare exclusive decode+padding clocks
and actual allocations/RSS. Do not infer pass-level gain from byte counts.
No mask/opening reuse,privacy change,arithmetic change or target change.

Next local:public raw-array last-use before LayerRecord::of_block. Preserve
all checks and metadata; test the complete lifetime rather than subtracting
one temporary from the global peak. Whole-prover GPU/resident measurements
remain the leading owner work.
'''
(ROOT/'handoffs/20261019-direct-signed-byte-padding.md').write_text(handoff)

state=f'''# ZKP efficiency explorer — durable state

Cycle0087 COMPLETE:`{RUN}`,2026-10-19 UTC.
Next cycle no earlier20:18:54 UTC. Started19:18:54;deadline19:38:54 UTC.
[Dated report](progress/{RUN}.md).
Startup snapshots:experiments/direct-signed-byte-padding-20261019/startup/.

{summary}

{memory}

{baseline}

{target}

Ranked hypotheses (full falsification,costs,prerequisites in hypotheses.json):
1.Owner whole-prover GPU and verified fixed-context resident1/2/4/8.
2.Prior checked public constructor transfer,native gates/clock pending.
3.NEW public raw-array release before record hashing,next local test.
4.Tested direct-byte padding,demoted for0B full-envelope improvement.
5.Guarded public owner,freshness/full live lease accounting.
Keep same-attempt witness retention/H-1 and D30/D32 architecture work as
owner-only queued alternatives; prior negative findings remain in FINDINGS.

{next_action}

{sources_text}

Handoff:handoffs/20261019-direct-signed-byte-padding.md. Patch unbuilt and
unapplied. No native equivalent proof or privacy acceptance claimed.
D33 remains TinyLlama T32 pg_rot1 CPU R7 only; R8/new files need gate re-pin.
No new8B/GPU privacy coverage. D27/D32 unchanged. Future source searches
must retain primary dates/licensing qualifications and blocked fetches.

Only research written;runtime/production/Git/receipts/calibration/safety/
instructions/reviewer files untouched. Saved reports do not imply delivery.
Checkpoint {now}. Final consistency/provenance gate pending.
'''
(ROOT/'STATE.md').write_text(state)
print(json.dumps({'checkpoint_utc':now,'source_records':len(sources),'sources_total':len((ROOT/'sources.jsonl').read_text().splitlines()),'report':str(ROOT/'progress'/f'{RUN}.md')}))
