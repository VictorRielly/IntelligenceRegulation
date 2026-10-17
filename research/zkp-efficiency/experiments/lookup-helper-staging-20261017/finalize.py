#!/usr/bin/env python3
"""Polish the final reports and pin reviewable artifacts; no experiment rerun."""
import datetime
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
RESEARCH=HERE.parent.parent
RUN='20261017T192105Z-c342a26b'

def main():
    r=json.loads((HERE/'result.json').read_text());a=json.loads((HERE/'audit-result.json').read_text())
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    assert r['status']==a['status']=='PASS'
    progress=f'''# ZKP efficiency progress

Cycle 0066 — `{RUN}`, 2026-10-17 UTC.

**No proving speedup found.** Rebuilding lookup helpers from A using field
arithmetic changes malformed-witness values and helper refusals. A private-bit
reconstruction prototype matches 4,176 columns, 106,962 field words and 35 H
fixtures. The independent audit passes 5,375 checks. One CPU thread; main
{r['wall_seconds']:.3f} s, audit {a['wall_seconds']:.3f} s, compiler peak {r['child_peak_rss_kib']/1024:.1f} MiB.
[Review handoff](handoffs/20261017-resident-helper-integer-boundary.md) includes
the compiled interface and native gates. No native proof or GPU job ran here.

At the earlier T128 geometry, counted lookup storage is 221.25 MiB versus a
0.609 MiB private bitmap; U8 H still needs 235.25 MiB. Tagged device commitment
and host-reader coherence remain unresolved. Even deleting the entire earlier
1.1B U8 helper phase caps the GPU-assisted process gain at 1.058×.

Carried owner 8B diagnostic: context 32, one cold pass per CPU / RTX 4070 Laptop
arm, 384.54 / 391.29 s. Diagnostic rates: 0.08322 / 0.08178 positions/s, including
in-process checking. Witness: 18.63 / 18.11 s; inclusive proving: 208.02 / 213.83 s,
including reloads. Serialization is unisolated. Partial load/seal startup:
21.60% / 20.34%; full startup and steady-state/target workload rates are unknown.
Fresh check: 96.10 / 90.94 s plus initial load 80.68 / 78.64 s. D24 round 3
accepts 8B-profile soundness; shape privacy remains open. New target-compliant
proofs/passes/positions: **0 / 0 / 0**. No long-prefill, resident-pass or decode
sweep. The >=50 proved-token/s target remains unchanged and unachieved.

Five LIVE primary records added. Next owner: complete device/enclosing-proof
gates and clocks. Next local: Logup* pushforward privacy and binding-cost audit.
[Dated report](progress/{RUN}.md) has full clocks, hypotheses, sources and blockers.
Production, runtime and Git were untouched. Saved reports do not establish delivery.
'''
    (RESEARCH/'PROGRESS.md').write_text(progress)
    state=f'''# ZKP efficiency explorer — durable state

Cycle 0066 COMPLETE: `{RUN}`.
Final checkpoint: {now}. Next cycle no earlier than 2026-10-17T20:21:05Z.
AGENDA, target, durable/project memory and latest three results consulted.
Startup snapshots: `experiments/lookup-helper-staging-20261017/startup/`.
Prior ledger bytes preserved; five LIVE source records added, 342 total.

No proving speedup found. The active F device builder already reads resident
A/H. This cycle tested the earlier U8 H producer at the integer/field boundary.
A-only field evaluation cannot reproduce all old wrapping-i64 behavior:
-2^63 and p-2^63 have identical A but different scale-2 helpers. Both directions
of local denominator-refusal status change occur. These are malformed internal
witness controls, not an accepted-proof forgery or an admissible-input attack.

A private ambiguity bitmap plus unsigned wrapping reconstructs the old words.
Two signed preimages occur iff the residue lies in [p-2^63, 2^63), an interval
of 2^32-1 residues. Identity denominators need no bit. Bits are per-proof private
memory and must never enter receipts/captures or cross-proof caches.

48 catalogs / 288 domains / 4,176 columns / 106,962 field words match.
35 H fixtures / 2,436 Fp2 values, five refusal cases and 12 main controls pass.
Initial codec test: 86,029 entries, including all int16 values; 7,294,208 visits
include repeated FFI fixtures. Independent audit: 5,375 checks, 700 extension
outputs and two actual bit-index mutations. Main {r['wall_seconds']:.6f} s / {r['parent_peak_rss_kib']} KiB,
compiler {r['child_peak_rss_kib']} KiB; audit {a['wall_seconds']:.6f} s / {a['peak_rss_kib']} KiB.
CPU 0, Intel Core Ultra 9 185H, one thread, nice 19, seed 2026101766;
59-second / 512-MiB limits. Std-only Rust source harness, no native crate or GPU.
Compiler temporary files use the experiment's tmp directory. Native failed
buffers, Rayon, transcript/RNG/PCS/masks/receipts/privacy remain untested.

Unapplied handoff: `handoffs/20261017-resident-helper-integer-boundary.md`.
Prototype, captures, logs, commands, hashes and controls:
`experiments/lookup-helper-staging-20261017/`. Existing device-H commitment is
untagged with incomplete host helper rows. Tagged ownership and host-reader
coherence, or explicitly charged D2H/H2D, are prerequisites. No native patch.

Counted earlier TinyLlama T128: looked payload 221.25 MiB; prior borrowing
leaves 53.75 MiB; bitmap 0.609375 MiB; U8 H output 235.25 MiB remains.
These are not peak/traffic/timing measurements. Whole-U8-phase deletion ceilings:
1.057799× GPU-assisted (8.844 / 161.857226 s), 1.041052× CPU (6.911 / 175.258632 s),
from earlier 1.1B T128 cold diagnostics. Candidate retains arithmetic and adds
packing, recovery and transfers. Actual 8B U8/F subclocks are absent.
The captured owner ledger records successful device-body fixtures, then a
failed seeded-test header and queued successor gates. No new complete receipt
or enclosing speed gain inferred from that ledger; no liveness claim.

Carried owner functional 8B: 8,030,261,248 parameters, 32 linked attention+FFN
blocks, T32, one cold pass per CPU / RTX 4070 Laptop arm, 16 threads.
Process 384.542564 / 391.287091 s; diagnostic 32/process rates 0.083216 / 0.081781
include in-process checking. Witness 18.629 / 18.109 s; inclusive proving
208.019 / 213.831 s includes reload 79.222 / 77.997 s; remaining 110.168 / 117.725 s
includes serialization/sink. Partial load+seal startup 21.595% / 20.341%.
Full startup, steady slope, isolated serialization/proof latency, lag/drain are
unknown. Fresh check 96.103 / 90.935 s plus initial load 80.675 / 78.635 s.
Receipt 465,815,776 bytes. D24 round 3 accepts 8B-profile soundness (18:36 UTC);
shape privacy remains open; later R5/GPU changes need their own gates.
No resident repeat, long prefill or decode measurement. New target-compliant
proofs / passes / positions: 0 / 0 / 0.

Ranked hypotheses:

1. OWNER whole-prover GPU: highest potential, high integration cost. Eliminate
   measured recurring work; charge setup, scratch, launches, transfers/drain.
   Any native bytes/refusal/privacy mismatch or no enclosing gain falsifies.
   Earlier whole masked-F deletion ceiling is 1.113184× on one 1.1B diagnostic;
   no 8B/5090 factor follows from fixture timings.
2. OWNER immutable public-model residency: about 80 s initial loading plus
   recurring reloads. Add RAM/identity/invalidation; no fresh-pass slope exists.
   A mutation surviving a cache hit, memory failure, or >20 ms recurring work
   per newly proved position falsifies the relevant correctness/50/s claim.
   No mask/private opening reuse.
3. TESTED resident U8 producer: secondary capacity candidate. Exact private
   codec passes; A-only shortcut fails. Adds bitmap/coherence costs. Reject on
   native word/refusal/RNG/byte mismatch; no peak/enclosing benefit rejects
   its proposed capacity/speed gain. Native gain and 8B attribution unknown.
4. NEW older Logup* architecture: native looked arrays are already uncommitted,
   so no additional query commitment may be deducted. Cost actual H displacement,
   new GKR/PCS, terminal binding, masking and joint view. Prior fractional-tree
   D/C leakage and whole-table zero-denominator negatives remain binding.

Next local: bounded Logup* pushforward privacy/binding audit, small odd/padded
query vectors, unmasked-disclosure control and original denominator schedule.
Count actual displaced H terms and added commitments; no adoption assumed.
Next owner: review gate and measure complete device/enclosing workloads under
shared locks, native/fresh-verifier/privacy gates. No heavy/GPU job queued here.
The >=50/s high-end-GPU target stands. Larger workloads may amortize setup with
fresh masks; resident contexts, long prefill and decode remain distinct;
dense attention can grow quadratically with context.

Research edits only, excluding runtime. No production/Git/receipt/calibration/
instruction/reviewer edits, installs, downloaded code execution, external
messages or escalation. Full report: `progress/{RUN}.md`.
Saved reports do not establish user-message delivery.
'''
    (RESEARCH/'STATE.md').write_text(state)
    # Correct old dynamic test clocks and polish only this cycle's new prose.
    replacements={
      'all65,536':'all 65,536','Seed2026101766':'Seed 2026101766','seed2026101766':'seed 2026101766',
      'Ultra9':'Ultra 9','nice19':'nice 19','Python3.10.12':'Python 3.10.12','rustc1.97.0':'rustc 1.97.0',
      'scale2':'scale-2','yield0':'yield 0','and-8589934590':'and -8589934590','exactly2^32':'exactly 2^32',
      'lengths0':'lengths 0','through129':'through 129','Prior1.1B':'Prior 1.1B','old1.1B':'old 1.1B',
      'actual8B':'actual 8B','No8B':'No 8B','No5090':'No 5090','row3':'row 3','round3':'round 3',
      'maskedF16.457':'masked F 16.457','of161.857':'of 161.857','ceiling1.113184':'ceiling 1.113184',
      'baseline.':'baseline.','about\n   80s':'about\n   80 s','above20ms':'above 20 ms',
      'T128:221.25':'T128: 221.25','bitmap0.609375':'bitmap 0.609375','still235.25':'still 235.25',
      'at1.057799':'at 1.057799','only1.058':'only 1.058','ALL old1.1B':'ALL old 1.1B',
      '1.057799x':'1.057799×','1.041052x':'1.041052×','1.113184x':'1.113184×',
      'complete private8B':'complete private 8B','32linked':'32 linked','8Bprofile':'8B profile',
      'D24round3':'D24 round 3','the8B':'the 8B','the8':'the 8','shapeprivacy':'shape privacy',
      'R5/GPU':'R5/GPU','contextattention':'context attention','at18:36UTC':'at 18:36 UTC',
      'CPU0':'CPU 0','RTX4070Laptop':'RTX 4070 Laptop','onecoldpass':'one cold pass',
      'one pass perarm':'one pass per arm','16threads':'16 threads','n=1':'n=1',
      '8,030,261,248parameters':'8,030,261,248 parameters','Llama3-8B':'Llama-3-8B',
      'embedding/final norm/head/selection':'embedding/final norm/head/selection',
      'with the8B':'with the 8B','CPU verifier\'s11controls':"CPU verifier's 11 controls",
      'guard456.227':'guard 456.227','not96.103':'not 96.103','guard169.595':'guard 169.595',
      'LIVE records appended (342 total)':'LIVE records appended (342 total)',
      'Oct16rc.2':'Oct 16 rc.2','approved2025':'approved 2025','dated2025':'dated 2025',
      'confirms2026':'confirms 2026','remain0.8.0':'remain 0.8.0','throughput50':'throughput 50',
      'No residentrepeat':'No resident repeat','longprefill':'long prefill','ordecode':'or decode',
      'private-view':'private view','binding-cost':'binding cost','fullstartup':'full startup',
      'isolatedserialization':'isolated serialization','prooflatency':'proof latency',
      'helperphase':'helper phase','NoGPU':'No GPU','CPUhelper':'CPU helper',
    }
    report_path=RESEARCH/'progress'/f'{RUN}.md'
    text=report_path.read_text()
    for old,new in replacements.items():text=text.replace(old,new)
    text=re.sub(r'\| Main wall / audit wall \|.*?\|',f"| Main wall / audit wall | {r['wall_seconds']:.6f} / {a['wall_seconds']:.6f} s |",text)
    text=re.sub(r'\| Main / compiler / audit peak RSS \|.*?\|',f"| Main / compiler / audit peak RSS | {r['parent_peak_rss_kib']} / {r['child_peak_rss_kib']} / {a['peak_rss_kib']} KiB |",text)
    text=text.replace('67483 / 35654','67,483 / 35,654').replace('5375 / 700','5,375 / 700')
    text=re.sub(r'(?<=\d)(MiB|KiB|UTC|seconds|words)(?=[ ,.;/\n])',r' \1',text)
    text=re.sub(r'(?<=\d)s(?=[ ,.;/\n])',' s',text)
    report_path.write_text(text)
    # Findings are append-only across cycles: replace only our current addition.
    p=RESEARCH/'FINDINGS.md';body=p.read_text();head,tail=body.split('\n\n## Cycle 0066 —',1)
    for old,new in replacements.items():tail=tail.replace(old,new)
    tail=re.sub(r'Main[0-9.]+s/[0-9]+KiB, compiler[0-9]+KiB;',f"Main {r['wall_seconds']:.6f} s / {r['parent_peak_rss_kib']} KiB, compiler {r['child_peak_rss_kib']} KiB;",tail)
    tail=re.sub(r'audit[0-9.]+s/[0-9]+KiB',f"audit {a['wall_seconds']:.6f} s / {a['peak_rss_kib']} KiB",tail)
    # Preserve any previous cycle byte-for-byte; only current cycle's prose changes.
    p.write_text(head+'\n\n## Cycle 0066 —'+tail)
    cp=json.loads((HERE/'checkpoint.json').read_text());cp['final_checkpoint_utc']=now
    (HERE/'checkpoint.json').write_text(json.dumps(cp,indent=2)+'\n')
    execution=dict(run_id=RUN,commands=[dict(argv=['python3','experiments/lookup-helper-staging-20261017/prepare.py'],exit_code=0,note='Initial capture plus separately retained pcs.rs; prepare now includes pcs.rs.'),dict(argv=['python3','experiments/lookup-helper-staging-20261017/run.py'],exit_code=0,wall_seconds=r['wall_seconds']),dict(argv=['python3','experiments/lookup-helper-staging-20261017/audit.py'],exit_code=0,wall_seconds=a['wall_seconds'])],compiler_argv=r['compiler_argv'],compiler_environment=dict(TMPDIR=str(HERE/'tmp'),RAYON_NUM_THREADS='1',OMP_NUM_THREADS='1'),scope='Final test runs; earlier passing versions retained. All final experiments CPU-light; no native crate/GPU/receipt executed.')
    (HERE/'execution.json').write_text(json.dumps(execution,indent=2)+'\n')
    print('final report clocks refreshed at',now)

if __name__=='__main__':main()
