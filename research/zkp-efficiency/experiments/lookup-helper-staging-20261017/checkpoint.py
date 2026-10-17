#!/usr/bin/env python3
"""Write this bounded research cycle's durable records, never production."""
import datetime
import hashlib
import json
from pathlib import Path
import shutil

HERE=Path(__file__).resolve().parent
RESEARCH=HERE.parent.parent
RUN='20261017T192105Z-c342a26b'

def dump(p,x):p.write_text(json.dumps(x,indent=2,sort_keys=True)+'\n')

def main():
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    result=json.loads((HERE/'result.json').read_text());audit=json.loads((HERE/'audit-result.json').read_text())
    assert result['status']==audit['status']=='PASS'
    c=result['counts'];rwall=result['wall_seconds'];awall=audit['wall_seconds']
    common=dict(cycle='0066',run_id=RUN,access_date='2026-10-17',access_timezone='UTC',recorded_at_utc=now,inspected_commit_id=None,reproduced_performance=False,evidence_kind='Native LIVE web search and primary inspection; no downloaded code executed; embedded instructions ignored')
    records=[
      dict(id='cycle66-new-older-logup-star-actual-commitment-boundary',title='Logup*: small-table indexed lookup and already-uncommitted native query boundary',url='https://eprint.iacr.org/2025/946',published='2025-05-26',updated=None,date_evidence='Primary metadata: received May24, approved May26 2025; no later revision displayed.',implementation_license=None,paper_license='CC BY per primary metadata; implementation not inspected.',author_claim='An indexed LogUp reduction avoiding extra query-length committed arrays.',assessment='New older architecture lead. Native looked columns are already uncommitted temporaries; no such commitment saving may be deducted again. Replacing reciprocal H helpers requires new bindings, GKR, hiding and composition, not this local producer rewrite.',inspected_urls=['https://eprint.iacr.org/2025/946','https://eprint.iacr.org/2025/946.pdf'],access_issues=['PDF open returned Internal Error; assessment limited to primary abstract/metadata.']),
      dict(id='cycle66-new-older-powdr-logup-star-hash-pcs',title='Twist and Shout via logup*: hash PCS, pushforward commitment and terminal binding',url='https://powdr.org/papers/twist_shout_logup_star.pdf',published='2025-10-30',updated=None,date_evidence='Date printed on page1 of author PDF; no revision history inspected.',implementation_license=None,author_claim='Adapts one-hot memory checking to hash commitments with batched small pushforwards.',assessment='New older design inspected, not implemented. Its opening protocol still commits the pushforward and verifies GKR terminal PCS claims. No masked/private native adaptation or performance is established; retain earlier unmasked fractional-tree leakage negatives.',inspected_urls=['https://powdr.org/papers/twist_shout_logup_star.pdf'],access_issues=[]),
      dict(id='cycle66-binius-logup-star-scope-license-no-release',title='Binius64 LogUp* task: reduction outputs remain caller-owned claims',url='https://github.com/binius-zk/binius64/issues/1368',published='2026-01-04',updated='2026-07-06',date_evidence='Issue opened Jan4 2026 and closed completed Jul6 2026. Closure is not a dated release or inspected implementation commit.',implementation_license='MIT full LICENSE-MIT.txt terms inspected; README also declares Apache-2.0 OR MIT; Apache file not opened.',author_claim='Task defines indexed lookup reduction; caller verifies three reduced evaluation claims.',assessment='No releases listed on accessed release page. README describes binary-field CPU-oriented word circuits, not a drop-in Goldilocks private block. No implementation source or full commit was verified.',inspected_urls=['https://github.com/binius-zk/binius64/issues/1368','https://github.com/binius-zk/binius64','https://github.com/binius-zk/binius64/releases','https://github.com/binius-zk/binius64/blob/main/LICENSE-MIT.txt','https://github.com/binius-zk/binius64/blob/main/Cargo.toml','https://api.github.com/repos/binius-zk/binius64/commits/main','https://github.com/binius-zk/binius64/tree/main/crates/prover/src/protocols/logup'],access_issues=['Wrong generic raw LICENSE path returned Internal Error; actual MIT file subsequently inspected.','Commit API and attempted logup source path returned Internal Error; no full commit pin inferred.']),
      dict(id='cycle66-oct16-plonky3-release-docs-scope',title='October16 Plonky3 rc.2 refresh: current release versus served docs',url='https://github.com/Plonky3/Plonky3/releases',published='2026-10-16',updated=None,date_evidence='Release list sumcheck rc.2: Oct16 10:17 without year; LIVE primary docs.rs search for p3-bus/multi-stark rc.2 explicitly gives2026-10-16. Exact sumcheck date retains this qualification.',exposed_uninspected_commit_id='fe5e46d',implementation_license='Not re-inspected for this tag/cycle; prior main license inspection is not a tag pin.',author_claim='Release lists fusion, crypto-RNG mask sampling and caller-soundness enforcement.',assessment='Retains all fresh-mask and terminal-binding obligations. docs.rs latest currently serves0.8.0 and lists rc.1; exact rc.2 fetch failed, so do not describe latest docs as rc.2 implementation evidence.',inspected_urls=['https://github.com/Plonky3/Plonky3/releases','https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.2','https://docs.rs/crate/p3-sumcheck/0.9.0-rc.2','https://docs.rs/crate/p3-sumcheck/latest','https://docs.rs/crate/p3-bus/0.9.0-rc.2','https://docs.rs/crate/p3-multi-stark/0.9.0-rc.2'],access_issues=['Exact sumcheck tag, exact rc.2 crate and commit-detail opens returned Internal Error.','Companion rc.2 date confirmed by LIVE primary search results, not a direct source-file inspection.']),
      dict(id='cycle66-september-quantization-query-count-refresh',title='Bits Under ZK-LLM: table/precision savings require whole-prover accounting',url='https://arxiv.org/abs/2609.36437',published='2026-09-29',updated=None,date_evidence='Primary arXiv v1 submission2026-09-29 00:54:35UTC; only v1 displayed.',implementation_license=None,author_claim='Studies precision/utility and reports non-proportional end-to-end savings from smaller bit widths/tables.',assessment='Metadata/abstract refresh only, author evidence not reproduced. Native fixed exact relation and per-query helper traffic remain; no quantization change or table reduction is authorized by this experiment.',inspected_urls=['https://arxiv.org/abs/2609.36437'],access_issues=[]),
    ]
    records=[common|x for x in records];dump(HERE/'searched-sources.json',records)
    queries=['LogUp lookup argument batch inversion memory efficient prover streaming 2026 github','zero knowledge lookup helper batch inversion streaming Montgomery trick 2025 2026','site.github.com binius64 "logup" October 2026','site.arxiv.org lookup small tables zero knowledge October 2026 logup','"p3-sumcheck-v0.9.0-rc.2" "2026-10-16" site:github.com/Plonky3','"p3-sumcheck" "0.9.0-rc.2" "2026-10-16" site:docs.rs']
    dump(HERE/'search-queries.json',dict(accessed_at_utc=now,tool='native LIVE web.run search/open/click/find',queries=queries,selected_primary_records=[x['id'] for x in records],foreign_code_execution=False,blockers=[dict(id=x['id'],issues=x['access_issues']) for x in records if x['access_issues']]))
    # Preserve and pin only previously retained public aggregate records, not proofs.
    retained=HERE/'retained';retained.mkdir(exist_ok=True)
    prior_files=[RESEARCH/'experiments/fzc-public-constants-20261017/owner-accounting.json',RESEARCH/'experiments/lookup-borrow-catalog-20261017/retained/r4-cpu-phases.json',RESEARCH/'experiments/lookup-borrow-catalog-20261017/retained/r4-gpu-phases.json',RESEARCH/'experiments/lookup-borrow-catalog-20261017/public-calibration.json']
    for p in prior_files:shutil.copy2(p,retained/p.name)
    dump(HERE/'retained-provenance.json',[dict(source=str(p),capture='retained/'+p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in prior_files])
    # Append without rewriting a previous byte of either memory ledger.
    srcfile=RESEARCH/'sources.jsonl';prefix=srcfile.read_bytes();start=(HERE/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
    assert prefix.startswith(start)
    existing=[json.loads(l) for l in prefix.decode().splitlines()]
    ids={x.get('id') for x in existing};new=[x for x in records if x['id'] not in ids]
    with srcfile.open('a') as f:
        for x in new:f.write(json.dumps(x,sort_keys=True)+'\n')
    total_sources=len(existing)+len(new)
    finding=f'''\n\n## Cycle 0066 — resident helper integer/field boundary, 2026-10-17

Run `{RUN}`. No proving speedup established. AGENDA/target and durable/project
memory consulted; current sources and latest three results inspected, early
STATE/startup snapshots retained. Five LIVE primary records appended (342 total).

Source audit: the active F device builder already reads resident A/H; no per-F
helper host reupload is removed here. Earlier producer still materializes
wrapping-i64 lookup columns, makes U8 helpers on CPU, copies each Fp2 Vec into
planar H and uses the tagged owned committer. Existing legacy device-H API
needs tagged ownership and host-reader coherence before a block port.

NEW tested hypothesis: generate U8 H from resident A, drop looked after the
histogram. **A-only field affine evaluation fails.** Signed -2^63 and p-2^63
have the same A residue but native wrapping scale2 yields 0/-8589934590 and
different H. Scale2 is a real Q/K rotation pin. Across 48 public catalogs,
4176columns/106962fieldwords, field-only has5323differences. Helper-stage zero
status reverses in both directions. This is malformed/internal full-i64
compatibility evidence, not an admissible-input attack or accepted-proof forgery.

Compiled research codec adds one PRIVATE bit for each relevant source word;
only residues [p-2^63,2^63) have two i64 preimages (2^32-1 residues). Unsigned
word reconstruction + wrapping affine evaluation exactly match native values.
Identity denominators need no bit; bounded synthetic arithmetic also matches
field evaluation. {c['identity_fast_path_words']}identity and {c['bounded_field_only_words']}bounded words pass.
86,029initialcodec entries include allint16/randomi64/ambiguity boundaries;
7,294,208codec visits include repeated FFI fixtures, not unique/proved positions.
35Hfixtures/2436Fp2values, sentinel gaps and5refusal cases pass;12controls.
Independent {audit['checks']}-check audit +700full-extension inverse outputs and2bit-index
controls pass. Main{rwall:.6f}s/{result['parent_peak_rss_kib']}KiB, compiler{result['child_peak_rss_kib']}KiB;
audit{awall:.6f}s/{audit['peak_rss_kib']}KiB. OneCPU0/CoreUltra9 185H thread,nice19,
seed2026101766,59s/512MiB limits;std-only Rust, no Cargo/native proof/GPU.
Failed-buffer/Rayon/transcript/RNG/PCS/mask/receipt/privacy gates remain owed.
First passing evidence and a strengthened midpoint-control revision retained.

COUNTED illustrative TinyLlama T128:221.25MiB looked (prior borrowing leaves
53.75MiB),0.609375MiB source ambiguity bitmap,235.25MiB U8 H still required.
No peak/traffic/time saving measured. Add packing/transfer/metadata/reconstruction,
fallback and tagged device H/CPU coherence. Earlier1.1B T128 cold GPU process
has8.844/161.857226s in allU8H: entire-parent deletion ceiling1.057799x;
CPU6.911/175.258632 ->1.041052x. No actual8B helper clock or5090 estimate.

Unapplied handoff:`handoffs/20261017-resident-helper-integer-boundary.md`;
prototype:`experiments/lookup-helper-staging-20261017/resident_codec.rs`.
Rank:1owner whole prover GPU;2owner immutable public-model residency;3tested
resident U8 compatibility/capacity (secondary);4NEW older Logup* virtual lookup
architecture. Native looked columns are already uncommitted; do not deduct
that nonexistent commitment again. Next local: small pushforward/private-view
and binding audit, preserving fractional-GKR D/C leakage and full-table
refusal negatives. Added GKR/PCS/masks/composition cost and exact displacement
must precede any proposed H-row saving. All older negatives remain.

Owner functional8B T32 cold baseline carried, not rerun:32linked blocks,
one pass perCPU/RTX4070Laptop arm,16threads. Process384.542564/391.287091s;
diagnostic32/process .083216/.081781 positions/s includes in-process check.
Witness18.629/18.109;inclusiveprove208.019/213.831 includes reload79.222/77.997;
remaining110.168/117.725 includes sink/serialization. Partial load+seal startup
21.595%/20.341%;fullstartup/steady slope/isolatedserialization/latency/lag/drain
unknown. Fresh check96.103/90.935 plusinitialload80.675/78.635s;receipt465815776B.
D24 round3 now explicitly accepts8B profile soundness (18:36UTC); shapeprivacy
still open, laterR5/GPU changes not thereby accepted. Owner captured ledger
has successful device-body fixtures and a failed seeded TEST header, then
queued successor gates; no complete new device receipt or speed claim here.

New target-compliant fullprivate8B proofs/passes/positions0/0/0. No resident
repeats, longer prefill or decode ran. >=50/s on5090/high-end unchanged and
unachieved; larger workloads allowed with fresh masks, and contextattention
can grow quadratically. Research/runtime/production boundaries held. Full
clocks/ranks/sources/blockers:`progress/{RUN}.md`.
'''
    ff=RESEARCH/'FINDINGS.md';fb=ff.read_bytes();assert fb.startswith((HERE/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes())
    if f'Run `{RUN}`.' not in fb.decode():
        with ff.open('a') as f:f.write(finding)
    report=f'''# Cycle 0066 — resident helper production needs integer provenance

Run `{RUN}`, 2026-10-17 UTC. Checkpoint `{now}`. Research only; production,
runtime, Git, receipts, calibration, instructions, gates and reviewer files
untouched. No heavy/GPU job, dependency installation, downloaded code execution,
external message or escalation. Required startup memory retained; prior ledger
bytes preserved. Saved reports are not evidence of user-message delivery.

**No proving speedup found.** A source-captured CPU experiment falsifies an
A-only helper shortcut and validates a private-bit compatibility prototype.
[Experiment](../experiments/lookup-helper-staging-20261017/README.md),
[result](../experiments/lookup-helper-staging-20261017/result.json),
[audit](../experiments/lookup-helper-staging-20261017/audit-result.json),
[handoff](../handoffs/20261017-resident-helper-integer-boundary.md).

## Completed work and measured scope

The active device F evaluator already expands resident A/H into working tables.
The earlier U8 H producer is still on the host. Tested question: can it read A
alone and release looked columns immediately after the byte histogram?
Baseline is the current wrapping-i64 lookup closure and canonical field/helper
bodies from `ops/zkp-mvp/gpu-zerocheck`, compiled in a tiny std-only Rust harness.
Independent reference: Python integers/signed conversion/modular inversion;
separate audit uses full-extension exponentiation and preimage analysis.

**Negative:** integer wrapping and field arithmetic differ on malformed words.
The same A residue has two signed preimages (-2^63 and p-2^63), whose scale2
lookups yield0 and-8589934590. The actual catalog includes scale2. Both possible
helper refusal-status reversals are demonstrated. This blocks all-witness
byte/refusal compatibility of the naïve port; it is not a soundness finding,
an accepted-proof forgery or a counterexample on admissible bounded inputs.

**Positive compatibility evidence:** a per-proof PRIVATE bit for ambiguous
residues reconstructs the original integer; unsigned wrapping affine operations
then match. Ambiguity interval [p-2^63,2^63) contains exactly2^32-1 residues.
Identity denominators already match A directly and need no sidecar. The codec
is not a native H producer or CUDA implementation. Bits must never enter a
public receipt/capture or cross-proof cache. Existing fresh masks remain.

| Check | Result |
|---|---:|
| Initial codec test entries (includes all65,536 int16 values) | 86,029 |
| Total codec visits including repeated FFI fixtures | 7,294,208 |
| Public catalogs / domains / lookup columns | 48 / 288 / 4,176 |
| Lookup field words matching native/reference/corrected port | 106,962 |
| Field-only word mismatches / missing-sidecar mismatches | 5,323 / 2,572 |
| Identity fast-path / bounded field-only words | {c['identity_fast_path_words']} / {c['bounded_field_only_words']} |
| H fixtures / canonical Fp2 values / sentinel words checked | 35 / 2,436 / 5,250 |
| Refusal fixtures / main controls | 5 / 12 |
| Independent audit checks / Fp2 inverse-derived outputs / bit mutations | {audit['checks']} / 700 / 2 |
| Main wall / audit wall | {rwall:.6f} / {awall:.6f} s |
| Main / compiler / audit peak RSS | {result['parent_peak_rss_kib']} / {result['child_peak_rss_kib']} / {audit['peak_rss_kib']} KiB |

Seed2026101766; Intel Core Ultra9 185H, CPU0, one thread, nice19; Python3.10.12,
rustc1.97.0,59-second and512-MiB caps per experiment. Vector lengths0,1,2,3,7,
63,64,65 and codec packing through129; odd/paired helpers, signed extremes,
generic affine/multiterm, used/unused/out-of-range zeros and synthetic padded
words. Tests are not trained witnesses or proved tokens. Commands/source hashes
and exact compiler arguments are retained. A first passing control was weak;
its evidence was preserved and the actual wrong midpoint lift was then tested.
Native failed-buffer behavior, Rayon, masking/RNG/transcript/PCS/receipt bytes
and privacy gates are untested. No native or GPU timing was measured.

## Costs, ceilings and ranked hypotheses

1. **Owner whole-prover GPU work:** highest expected impact, high integration
   cost. Baseline is the measured trained slot/commitment schedule. Move only
   recurring work actually offloaded; add table construction, scratch, launches,
   transfers, compilation and drain. Prior1.1B T128 maskedF16.457s of161.857226s
   has a whole-body deletion ceiling1.113184x; actual8B F attribution absent.
   Captured owner ledger now records successful actual-device body fixtures,
   then a failed seeded-test header and queued successor gates. No new complete
   receipt or speed gain is inferred. Any native transcript/bytes/privacy/refusal
   mismatch, or no enclosing improvement, falsifies promotion.
2. **Owner public model/setup residency:** actual8B initial load/digest is about
   80s and blocks reload in proving and checking. Eliminate only authenticatable
   repeated public work; add retained RAM, immutable identity checks, cache
   invalidation and fallback. No pass-count slope exists. A public-content
   mutation surviving a cache hit, memory failure, or recurring cost above20ms
   per new verified position falsifies the respective correctness/50/s claim.
   Public residency never licenses mask/private opening reuse.
3. **Refined/tested resident U8 producer:** moderate/high actual integration
   cost, secondary capacity opportunity. Could eliminate looked retention and
   host helper production; no production work eliminated by this experiment.
   Earlier TinyLlama T128 counts:221.25MiB looked; prior borrowing already leaves
   53.75MiB; ambiguity bitmap0.609375MiB; U8 H still235.25MiB. Count packing,
   integer recovery, invalid-value inverse fallback, device status/reduction,
   masks, whole-table checks and host/device coherence. The existing device-H
   committer is untagged and leaves helper host rows incomplete, while this
   block has tagged H and CPU consumers. Need a tagged owned API plus consistent
   host data, or charge D2H/H2D. Deleting ALL old1.1B U8 helper parent gives only
   1.057799x GPU-assisted (8.844/161.857226s),1.041052x CPU (6.911/175.258632s).
   Candidate retains arithmetic and adds costs. No8B/5090 ceiling is known.
   Any native word/refusal/RNG/receipt divergence rejects; unchanged peak or
   enclosing time rejects the claimed capacity or speed benefit.
4. **NEW older Logup* architecture lead:** could revisit committed inverse
   helpers, high protocol/PCS/masking/composition cost, unknown end-to-end gain.
   Native looked query arrays are already UNCOMMITTED: do not deduct a new
   query commitment simply because a paper avoids it. Cost the actual displaced
   H rows and new pushforward/GKR/terminal openings. Next local: small masked
   versus unmasked pushforward/private-view and binding audit, preserving the
   earlier fractional-GKR leakage/full-table-zero negatives. A leak, unbound
   terminal, changed exact relation or nonpositive net cost falsifies a port.

All earlier slower fusion, small-parent cache, reconstruction/traffic, borrowed
catalog and fractional-GKR privacy negative findings remain in FINDINGS.

## Complete-stack target and owner baseline

New target-compliant complete private8B proofs / passes / positions: **0 / 0 / 0**.
>=50 proved tokens/s on one RTX5090 or named high-end GPU is unchanged and
unachieved. This cycle ran CPU synthetic vectors, no model prefill/pass/decode.

Carried-forward owner functional diagnostic, NOT rerun: Llama3-8B,
8,030,261,248parameters,32linked attention+FFN blocks,T32,one cold pass perarm,
16threads,shared laptop,n=1. P1 candidate with public weights; D13 excludes
embedding/final norm/head/selection. D24 round3 now explicitly accepts the8B
profile changes on soundness (18:36UTC); shape privacy remains open and R5/GPU
changes are not accepted by that review. Prior public event/hash records are
retained separately from receipts.

| Clock / evidence | CPU | RTX4070Laptop assisted |
|---|---:|---:|
| Guard child process wall s |384.542564|391.287091|
| Internal total s, includes in-process checking |384.497|391.012|
| Initial load/digest s |83.012|79.490|
| Endpoint seal s |0.020|0.044|
| Partial load+seal startup fraction of internal total |21.595%|20.341%|
| Witness s within prove_run |18.629|18.109|
| Inclusive prove_run s, includes witness/reload/sink |208.019|213.831|
| Prove_run block reload s |79.222|77.997|
| Remainder s, includes boundaries/serialization/sink |110.168|117.725|
| In-process verification s |93.356|92.741|
| Fresh verifier initial load s |80.675|78.635|
| Fresh verifier check s, includes more block loading |96.103|90.935|
| Fresh first-success load+check s |176.778|169.570|
| Receipt bytes |465,815,776|465,815,776|
| Diagnostic32/process positions/s, includes in-process check |0.083216|0.081781|
| Sampled host peak GiB / device VRAM MiB |1.90 / none|1.57 /2,369|

**Steady-state and target total-workload rates: unmeasured.** The final row's
diagnostic rates are process ratios for functional samples, not privacy-accepted
50/s throughput. Full startup/initial-prefill fraction, isolated proof latency,
serialization, lag and drain are unmeasured. Fresh verification is separate;
the CPU verifier's11controls make its whole guard456.227s, not96.103s honest
check. GPU fresh verifier guard169.595s is honest-only. Long single-context
prefill, resident repeated passes and authenticated decode remain distinct,
unmeasured schedules. Increasing context can increase dense attention as T².

## Sources, blockers and next action

LIVE rotation covered lookup/softmax, representation/memory, composition and
recent quantization. Five qualified records (337 -> {total_sources}) retain exact
URLs, access and verified/qualified dates, licenses and null commit pins.
New older [Logup*](https://eprint.iacr.org/2025/946), approved2025-05-26, and
[Powdr hash-based adaptation](https://powdr.org/papers/twist_shout_logup_star.pdf),
dated2025-10-30, remain architecture leads. The [Binius64 task](https://github.com/binius-zk/binius64/issues/1368)
leaves reduced claims to its caller; no releases listed; MIT terms inspected,
no full commit/source pin. [Plonky3 current releases](https://github.com/Plonky3/Plonky3/releases)
list Oct16rc.2; companion primary package metadata confirms2026-10-16, while
served latest sumcheck docs remain0.8.0. The [September quantization study](https://arxiv.org/abs/2609.36437)
is an author-cost qualification, not new native evidence. No author performance
was reproduced. Exact fetch failures are in `search-queries.json` and
`searched-sources.json`: PDF/tag/crate/commit/source opens returned Internal
Error; no bypass, alternate login or network-dependent execution attempted.

Next owner: review compatibility gate and measure complete device/enclosing
phases under shared locks and all native/fresh-verifier/privacy gates. Device
H is secondary unless actual capacity/phase measurements justify it. Next
local: costed pushforward/private-view and binding audit; never assume fewer
committed helpers from an unrelated query-commitment claim. No heavy work queued.
'''
    (RESEARCH/'progress'/f'{RUN}.md').write_text(report)
    progress=f'''# ZKP efficiency progress

Cycle0066 — `{RUN}`,2026-10-17UTC.

**No proving speedup found; an A-only GPU-helper shortcut is incompatible.**
The wrapping-i64 producer can require different H words for identical field
A values. A private-bit reconstruction prototype matches4,176lookup columns,
106,962fieldwords and35Hfixtures; the independent audit passes{audit['checks']}checks.
One CPU thread; main{rwall:.3f}s,audit{awall:.3f}s;compiler peak<128MiB.
[Review handoff](handoffs/20261017-resident-helper-integer-boundary.md) includes
the compiled interface and native gates. No GPU/native receipt or speed claim.

Illustrative T128 looked payload221.25MiB could shrink to a0.609MiB bitmap,
but U8H235.25MiB remains; tagged device commitment and CPU-reader coherence
are unresolved. Earlier1.1B entire-U8-phase deletion ceiling is only1.058xGPU.

Carried owner8B T32,one cold pass perCPU/RTX4070Laptop arm:384.54/391.29s,
diagnostic0.08322/0.08178positions/s. Witness18.63/18.11s;inclusiveprove
208.02/213.83s includes reloads;serialization unisolated. Partial load/seal
startup21.60%/20.34%;fullstartup and steady/target rates unknown. Freshcheck
96.10/90.94s plusinitialload80.68/78.64s. D24round3 accepts8B-profile
soundness;shapeprivacy remains open. Newtargetproofs/passes/positions0/0/0.
No longprefill,residentrepeat ordecode sweep;>=50/s remains unachieved.

Five LIVE primary records added. Next owner: device/enclosing-proof gates and
clocks. Next local: Logup* pushforward/private-view and actual binding-cost audit.
[Dated report](progress/{RUN}.md) has full clocks,ranks,sources and blockers.
Production/runtime/Git untouched. Saved reports do not establish message delivery.
'''
    (RESEARCH/'PROGRESS.md').write_text(progress)
    state=f'''# ZKP efficiency explorer — durable state

Cycle0066 COMPLETE:`{RUN}`.
Checkpoint:{now}. Next cycle no earlier than2026-10-17T20:21:05Z.
AGENDA/target,durable/project memory and latest three results consulted;
startup captures:`experiments/lookup-helper-staging-20261017/startup/`.
Prior findings/source bytes preserved;5LIVE records appended,{total_sources}total.

No proving speedup found. New active-source U8 producer audit:
- F device builder already uses resident A/H. It adds scratch expansion,
  not another host helper upload when commitments are resident.
- A-only affine FIELD evaluation cannot preserve arbitrary old wrapping-i64
  helper behavior. -2^63 and p-2^63 have identical A but scale2 gives different
  H; both directions of local zero-denominator status change demonstrated.
  Internal malformed-witness compatibility issue, not an accepted-proof forgery.
- Private ambiguity bits + unsigned wrapping recover exact native arithmetic.
  Two preimages iff residue in[p-2^63,2^63),length2^32-1. Identity denominators
  need no bit. No bit is public/cached/across-proof. No privacy weakening.
-48catalogs/288domains/4176columns/106962Fpwords;35Hfixtures/2436Fp2values,
  5refusals/12controls. Initialcodec86029entries incl allint16;7,294,208visits
  include repeats. Independent{audit['checks']}checks/700extensionvalues/2bitmutations.
  Main{rwall:.6f}s/{result['parent_peak_rss_kib']}KiB,compiler{result['child_peak_rss_kib']}KiB;
  audit{awall:.6f}s/{audit['peak_rss_kib']}KiB. CPU0/CoreUltra9 185H,one thread,nice19,
  seed2026101766,59s/512MiB caps,std-onlyRust. Native/Rayon/CUDA/failedbuffer/
  transcript/RNG/PCS/mask/receipt/privacy gates untested. Earlier passes retained.

Unapplied handoff:`handoffs/20261017-resident-helper-integer-boundary.md`.
Compiled codec/interface and all source/log/hash evidence:
`experiments/lookup-helper-staging-20261017/`. Existing device-H committer is
untagged with incomplete host helper rows. New tagged ownership and host-reader
coherence or chargedD2H/H2D are prerequisites. No native patch or merge.

Counted TinyLlamaT128 looked221.25MiB,priorborrowing leaves53.75MiB;
ambiguity bitmap0.609375MiB;U8H235.25MiB remains. Not peak/traffic/time.
Whole old1.1B T128 U8H deletion ceiling1.057799xGPU(8.844/161.857226s),
1.041052xCPU(6.911/175.258632s). Candidate retains arithmetic/adds packing,
reconstruction,transfers. Actual8B U8phase absent. Earlier maskedF body whole
deletion ceiling1.113184x remains diagnostic only. Owner fixture device gates
now pass;seeded-test header failed then queued successor gates in captured
ledger. No successful new complete receipt or enclosing gain inferred.

Owner functional8B baseline carried,notrerun:8,030,261,248params,32linked
attention+FFNblocks,T32,onecoldpass perCPU/RTX4070Laptop arm,16threads.
Process384.542564/391.287091s;32/process diagnostics.083216/.081781 inclcheck.
Witness18.629/18.109s;inclusiveprove208.019/213.831 includes reload79.222/77.997,
remaining110.168/117.725 includes sink/serialization. Partial load+seal startup
21.595%/20.341%;fullstartup/steady slope/isolatedserialization/prooflatency/
lag/drain unknown. Freshcheck96.103/90.935 plusinitialload80.675/78.635s.
Receipt465815776B. D24round3 accepts8Bprofile soundness at18:36UTC;shapeprivacy
remains open;laterR5/GPUchanges require their own gates. No residentrepeat,
longprefill ordecode measurement. Newtargetproofs/passes/positions0/0/0.

Ranked hypotheses:
1OWNER wholeprover GPU:highest impact,highcost. Eliminate only measured work;
charge launch/build/scratch/transfers/drain. Any native bytes/refusal/privacy
mismatch or no enclosinggain falsifies. No8B/5090factor from devicefixtures.
2OWNER immutable publicmodel residency:~80s initialload and recurringreloads;
addRAM/identity/invalidation. Complete freshpass slope unmeasured. Mutation
survivescache/memoryfailure or >20ms per newlyprovedposition falsifies relevant
correctness/50s claim. Never reuse masks/privateopenings.
3TESTED residentU8 producer:secondarycapacity;exactcodec positive,A-onlynegative.
Addedprivatebitmap and coherence costs;no native gain. Reject value/refusal/
RNG/byte mismatch;no peak or enclosingbenefit rejects claimed optimization.
4NEW older Logup* architecture:looked arrays already UNCOMMITTED here,so no
extra querycommitment can be deducted. Need actualHdisplacement,newGKR/PCS,
masking/terminalbinding and jointview costs. Prior fractiontree D/Cleakage
and whole-table-denominator negatives remain binding.

Next local:bounded Logup* pushforward private-view/binding audit,including
actual displacedH terms,small odd/padded query vectors,unmasked disclosure
control and zero-denominator schedule. No protocol change/adoption assumed.
Next owner:review gate,higher-priority complete device/enclosing clocks under
shared locks and native/fresh-verifier/privacy checks. No heavy/GPUjob queued.
>=50/s on5090/high-end unchanged/unachieved;largerworkloads allowed with fresh
masks;residentcontexts,longprefill anddecode stay distinct;attention can growT².

Research writes only,excludingruntime. No production/Git/receipt/calibration/
instruction/reviewer edit,installs,foreign-codeexecution,externalmessages or
escalation. Fullreport:`progress/{RUN}.md`. Reports do not imply delivery.
'''
    (RESEARCH/'STATE.md').write_text(state)
    dump(HERE/'checkpoint.json',dict(run_id=RUN,checkpoint_utc=now,source_records_added=len(new),total_sources=total_sources,findings_prefix_sha256=hashlib.sha256(fb).hexdigest(),sources_prefix_sha256=hashlib.sha256(prefix).hexdigest(),files=['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl','progress/'+RUN+'.md','handoffs/20261017-resident-helper-integer-boundary.md']))
    print('checkpointed',RUN,'sources',total_sources,'at',now)

if __name__=='__main__':main()
