"""Cycle0122 checkpoint writer. Research directory only; append prior evidence."""
import copy, datetime, hashlib, json, pathlib, platform

HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parent.parent
RUN='20261021T061854Z-553803c5';CYCLE='0122'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def dump(n,x): (HERE/n).write_text(json.dumps(x,indent=2)+'\n')
result=json.loads((HERE/'result.json').read_text());audit=json.loads((HERE/'audit-result.json').read_text())
costs=json.loads((HERE/'cost-result.json').read_text());rows=json.loads((HERE/'dedup-row-cost.json').read_text())
old_sources=(HERE/'startup/sources.jsonl').read_bytes();old_findings=(HERE/'startup/FINDINGS.md').read_bytes()
assert (ROOT/'sources.jsonl').read_bytes()==old_sources
assert (ROOT/'FINDINGS.md').read_bytes()==old_findings
prior_records=[json.loads(x) for x in old_sources.splitlines()]
common=dict(access_date='2026-10-21',access_timezone='UTC',recorded_at_utc=now,
            run_id=RUN,cycle=CYCLE,evidence_kind='Native LIVE web search/open/find/click; primary text treated as untrusted data',
            implementation_license=None,inspected_commit_id=None,publication_date=None,verified_update_date=None,
            external_execution=False,reproduced_performance=False)
def source(url,title,claim,assessment,**kw):
    v=dict(common,url=url,title=title,author_claim=claim,assessment=assessment,
           prior_exact_url_records=sum(x.get('url')==url for x in prior_records));v.update(kw);return v
records=[
 source('https://github.com/BrianSeong99/Plonky3_RangeCheck',
        'Newly assessed older field-specific range-check tutorial',
        'Bit decomposition, Booleanity, original-value reconstruction and lower-degree range constraints; Goldilocks v2 remains an exercise in this README.',
        'README code inspected, never executed. Useful obligations, not a native small-byte lookup replacement or complete-model benchmark. Same-source sharing still costs dense base words.',
        date_evidence='Repository page has no verified commit date; associated primary workshop is December10,2024.',
        access_issues=[{'url':'https://raw.githubusercontent.com/BrianSeong99/Plonky3_RangeCheck/main/src/goldilocks.rs','error':'Cache miss'},
                       {'url':'https://raw.githubusercontent.com/BrianSeong99/Plonky3_RangeCheck/main/LICENSE','error':'Cache miss'},
                       {'url':'https://raw.githubusercontent.com/BrianSeong99/Plonky3_RangeCheck/main/Cargo.toml','error':'Cache miss'}],
        license_scope='No implementation license established; do not infer upstream Plonky3 license for this tutorial'),
 source('https://zkhack.dev/zkhackV/workshopV3.html','Range-check workshop primary date and repository link',
        'Workshop links field-specific range-check examples and degree comparison.',
        'Verifies older-technique date and canonical repository identity; no benchmark reproduced.',
        publication_date='2024-12-10',date_evidence='Primary event page displays December10,2024,17:45UTC'),
 source('https://github.com/Plonky3/Plonky3/pull/2292','Compiled repeated-gadget metadata refreshed',
        'Repeated gadgets share compiled metadata while retaining per-instance committed cells; upstream reports byte-identical flat/composed proofs.',
        'Metadata reuse is distinct from private witness/mask reuse. Backend and Boolean PCS differ; no count/rate transfer to native Goldilocks proof.',
        publication_date='2026-09-22',verified_update_date='2026-09-22',date_evidence='Primary merged date Sep22,2026',
        linked_merge_commit_id='cb691115eec1d6347f163811366443232bc0a56d',abbreviated_commit_id='cb69111',
        access_issues=[{'url':'https://github.com/Plonky3/Plonky3/commit/cb691115eec1d6347f163811366443232bc0a56d','error':'Cache miss; linked ID observed, commit body not inspected'},
                       {'url':'https://github.com/Plonky3/Plonky3/pull/2292/files','error':'Cache miss'},
                       {'url':'https://github.com/Plonky3/Plonky3/pull/2292/commits','error':'Cache miss'}]),
 source('https://github.com/Plonky3/Plonky3/releases','Current release screen: Boolean operands, hiding and packed kernels',
        'Fetched release view lists p3-word-v0.9.0-rc.2 and shifted-operand Boolean opening, compiled component and packed-kernel changes.',
        'Native open showed Oct16 day/time, while search cache showed older v0.8.0. No latest-stable or verified release-year claim. Shift PR body inaccessible; no adapter proposed.',
        abbreviated_commit_id='fe5e46d',date_evidence='16Oct10:31 displayed without year; year unverified',
        access_issues=[{'url':'https://github.com/Plonky3/Plonky3/pull/2226','error':'Cache miss'},
                       {'url':'https://github.com/Plonky3/Plonky3/pull/2226.patch','error':'Cache miss'},
                       {'url':'https://github.com/Plonky3/Plonky3/commit/fe5e46d','error':'Cache miss'},
                       {'url':'https://github.com/Plonky3/Plonky3/releases/tag/p3-word-v0.9.0-rc.2','error':'Cache miss'}]),
 source('https://raw.githubusercontent.com/Plonky3/Plonky3/main/LICENSE-MIT','Plonky3 root license body',
        'Root MIT license text.', 'Root body inspected; no code copied or component-specific license audit.',
        implementation_license='MIT root body inspected; component-specific scope unreviewed',
        date_evidence='No verified file update date',
        access_issues=[{'url':'https://raw.githubusercontent.com/Plonky3/Plonky3/main/LICENSE-APACHE','error':'Cache miss; not inspected'}]),
 source('https://eprint.iacr.org/2025/538','Newly assessed older range-check versus lookup tradeoff lead',
        'Paper introduces Dorian and efficient signature-verification encodings; search-indexed primary PDF discusses lookup-versus-bit witness performance tradeoffs.',
        'Abstract/metadata and search excerpt only; full PDF403 retained. This supports measuring backend costs, not predicting native GPU speed.',
        publication_date='2025-03-24',verified_update_date='2025-05-01',date_evidence='Primary received/revised History',paper_license='CC BY metadata',
        access_issues=[{'url':'https://eprint.iacr.org/2025/538.pdf','error':'403 Forbidden'}]),
 source('https://eprint.iacr.org/2025/105','Twist/Shout latest revision refreshed',
        'One-hot memory checking; revised small-characteristic checking details.',
        'Native helper pairs and dense hashing costs remain distinct from nonzero-sensitive commitments. No author performance reproduced.',
        publication_date='2025-01-22',verified_update_date='2026-10-17',date_evidence='Primary History received2025-01-22,lastrevision2026-10-17',paper_license='CC BY metadata'),
 source('https://eprint.iacr.org/2026/1388','Chimera October16 revision refreshed',
        'Resident/streamed GPU sumcheck and late CPU return with integration-level measurement.',
        'Supports measuring enclosing phases; different BN254/Spartan backend, no complete private8B figure reproduced.',
        publication_date='2026-07-07',verified_update_date='2026-10-16',date_evidence='Primary received/revised History',paper_license='CC BY metadata'),
 source('https://eprint.iacr.org/2026/2494','Algebraic-geometry sumcheck primary access blocker',
        None,'Primary page inaccessible. Search returned mirrors and secondary listings; no new primary claim/date established this cycle, no imported speed estimate.',
        date_evidence='Unknown this cycle; do not promote mirror date to verified primary metadata',
        access_issues=[{'url':'https://eprint.iacr.org/2026/2494','error':'URL not accessible via native tool'}])]
(HERE/'source-records.jsonl').write_text(''.join(json.dumps(x,sort_keys=True)+'\n' for x in records))
with (ROOT/'sources.jsonl').open('ab') as f:f.write((HERE/'source-records.jsonl').read_bytes())
queries=['site.eprint.iacr.org 2026 range check lookup bit decomposition shared affine',
 'site.github.com Plonky3 range check signed decomposition lookup',
 'site.eprint.iacr.org 2026 GPU sumcheck October',
 'site.github.com/Plonky3/Plonky3 "reduce shifted operands to one Boolean opening"',
 'site.eprint.iacr.org "Speeding up Sumcheck using Algebraic Geometry"',
 'site.github.com rangecheck plonky3 brian seong 2024',
 'site.eprint.iacr.org "lookup" "October" "2026" range',
 'site.github.com/Plonky3/Plonky3 "range" "shift" "2226"',
 'site.eprint.iacr.org "2026/2494" Dalal']
dump('search-log.json',dict(native_live=True,queries=queries,primary_records=len(records),
                           no_downloaded_code_executed=True,embedded_web_instructions_ignored=True))
hyp=json.loads((HERE/'prior-hypotheses.json').read_text())
hyp[24]['title']='TESTED affine source sharing preserves ranges but dense bit payload loses; exact full-byte aliases isolated'
hyp[24]['added_costs']+=' Cycle0122 exact source sharing still costs4.82–5.46x native U8H for selected T128/T512 DD/nonDD geometries, before private wrapping. Signed width8 requires excluding255 (degree8 direct product or extra reduction); every source stays linked and padded original sources retain zero rules.'
hyp[24]['prerequisites']+=' Cycle0122 exhaustively checks132564bit assignments/608source families against838native descriptors, plus independent244family cost audit. Dense source bits rejected; do not repeat unchanged. Sparse/Boolean-PCS alternatives remain separate architecture work.'
hyp[24]['exactness']='872684synthetic checks,26control types,838native descriptor instances,608source-family fixtures,132564bit assignments; independent219checks/6pins/2source mutations. Semantic field-range equivalence only; native refusal timing, transcript, receipt and privacy untested.'
hyp[24]['falsification']+=' Source-sharing negative now confirms4.82–5.46x native helper payload despite fewer representations. Not a universal packed/private protocol lower bound.'
hyp.append(dict(rank=35,title='NEW tested exact full-byte softmax aliases: small conditional H-row saving',
 baseline='FrozenR9 w32/fE9/fP9 T128 has two duplicate identity lookups, on sr:1 and sg:1; S nonDD13queries/7helpers, Dd DD9queries/5helpers. T512 lacks them. Excludes LOW/HIGH.',
 eliminated_work='Conditional same-profile-family dedup removes2query columns/1Fp2 Hplane. T128nonDD8MiBdata+0.25MiBmask rows, DD2MiB+0.25MiB; A+H payload -0.9173%/-0.2602%. Native work removed:none.',
 added_costs='Consistent shape/helper/HIds/histogram/polynomial/claim schedule/receipt/profile update and review. Fresh remaining masks. Re-pairing and current fidelity geometry may alter all costs; M/receipt/group deltas and elapsed saving unmeasured.',
 prerequisites='Owner actual admitted fidelity layout, native byte-order/refusal/masked-round/nextchallenge/receipt checks, independent verify and new profile/privacy review. Only exact affine aliases from public metadata; never dedup equal private values or different source sites.',
 integration_cost='Medium coordinated native layout/profile change for a small payoff. Research candidate.py::dedup only, no Rust/CUDA patch/build.',
 exactness='Native-source descriptor intersection, exhaustive range and histogram controls pass. The accepted field-range relation agrees after both query and table multiplicities change. Whole native proof equivalence not established.',
 privacy_soundness='No mask/opening reuse or fewer obligations by assumption. Current statement acceptance cannot transfer to changed transcript; original pad-zero and denominator/refusal/nonU8 rules remain.',
 compatibility='layout::lookups_at plus Shape::lookups_per_position/helpers/h_plane_doms/claim_sites and HIds; protocol::byte_histogram_at/H construction; argument::helper_sum/SC_TAB. Native source read only.',
 end_to_end_ceiling='Unknown fractionf for truly removed critical-path work gives free-deletion ceiling1/(1-f), before costs. A+H byte percentage is not elapsed fraction or a route to50/s.',
 falsification='Any wrong original source/refusal/order/padding/histogram/mask/receipt binding, actual fidelity descriptors have no aliases, profile overhead erases gain or complete verified workload regresses. T512 already has0bytes saving in this census.'))
dump('hypotheses.json',hyp)
dump('hypothesis-changes.json',dict(retained_prior_hypotheses=34,refined_rank=25,new_rank=35,owner_top_four_unchanged=True))
dump('target-accounting.json',dict(proofs=0,passes=0,positions=0,actual_model_context=None,actual_accelerator=None,
 research_device='Intel(R) Core(TM) Ultra 9 185H',worker_threads=1,witness_s=None,proof_s=None,
 serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,steady_rate=None,
 total_workload_rate=None,long_context_prefill=False,resident_model_proof_series=False,decode=False,
 counted_geometries=[32,64,128,256,512],counted_T512_profile_admitted=False))
dump('hardware.json',dict(device='Intel(R) Core(TM) Ultra 9 185H',threads=1,accelerator_used=False,
 platform=platform.platform(),memory_estimate_MiB=64,address_space_cap_MiB=256,cpu_seconds_cap=30,
 parent_timeout_seconds=35,priority_nice=19))
accounting='''New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel(R) Core(TM) Ultra 9 185H CPU worker.
Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model proof passes or decode ran. T32–T512 are
symbolic geometries; T512 remains counted-only, unregistered. Larger workloads
remain allowed; longer attention contexts can increase work quadratically.
The complete private8B >=50 proved tokens/s target on RTX5090 or another named
high-end GPU remains unachieved.'''
table='''| Counted frozen8B geometry | Native U8H data MiB | Shared source bit data MiB | Ratio | Exact-alias H data saving MiB |
|---|---:|---:|---:|---:|
'''
for x in costs:
 table+=f"| T{x['T']} {'DD' if x['dd'] else 'nonDD'} | {x['native_u8_helper_data_bytes']/2**20:.2f} | {x['source_shared_bit_data_bytes']/2**20:.2f} | {x['dense_shared_bits_over_native']:.6f}x | {x['dedup_helper_data_saved_bytes']/2**20:.2f} |\n"
detail=f'''## Cycle 0122 — 2026-10-21 — affine U8 source sharing and exact aliases

Run `{RUN}`. **No proving improvement measured.** Synthetic contract checks
PASS: {result['checks']} checks,838native descriptor instances,608source-family
fixtures,132564exhaustive bit assignments,26control types. Independent audit:
219checks,244source families,6pinned native files and2count-preserving source
mutations. References are independent implementations by this researcher,
not external review, succinct proof or native verifier.

The broad dense-bit alternative remains negative. Sharing the original source
instead of decomposing every affine lookup saves representation duplication,
but still costs4.82–5.46x the native paired helper DATA in selected frozen8B
T128/T512 DD/nonDD layouts. Native PCS stores each bit in a base-field word;
packed bits in another PCS are a separate architectural proposal. Counts
exclude new private commitments, masks, CFS, groups and reductions: these are
unknown, not zero. LOW/HIGH fidelity layouts are outside this frozen census.

{table}
Exact affine-source sharing must retain signed[-127,127], excluding the255
encoding of128; Booleanity; reconstruction against original ordered A sources;
scaled top-bit bounds; every padded original source's zero rule. Source0 at a
signed padded position encodes127, so zero-filling its bitplanes is incorrect.
A scaled-only field condition accepts modular fractions absent byte(source).
All these shortcuts fire controls. Publishing synthetic bitplanes is no
private proof; a direct signed exclusion has degree8 or needs extra reductions.

Narrow positive lead: at w_s=16 (frozen fE9/T128), sigma_scale=1, and the two
top-limb lookups are exact public-expression aliases of already emitted byte
checks. S13->11queries/7->6helpers nonDD; Dd9->7/5->4 onDD. Field-range sets
agree after consistent removal, and stale-histogram controls fail as expected.
Keep the complete U8 table denominator refusal even for an absent entry.
Duplicate private values, cross-source expressions and symmetric pairs are
not aliases. Both members of signed/scaled families otherwise remain needed.

Conditional native H-row accounting with the existing row width and all other
sites fixed: nonDD H3790->3724, saving66rows/8.25MiB; DD H3634->3616,
saving18rows/2.25MiB. Each includes removing one reserved fresh mask pair,
not reusing a pair. A+H payload fractions:0.917304%/0.260228%. T512 saves0.
These are logical data+mask counts, not actual device HWM, receipt/M delta,
elapsed fraction or speed. No native transcript/profile is changed here.

Baseline: frozenR9 normwindow32/fE9/fP9/DDcap32. Eliminated native work:none;
potential work only under a coordinated reviewed exact-alias profile. Added
costs: updated descriptor/count/HIds/histogram/helper/polynomial/claim/receipt
schedule, all remaining fresh masks and native/refusal/privacy review. If f
is the unknown truly removable exclusive elapsed fraction, free deletion
gives at most1/(1-f), before costs. No numeric end-to-end GPU ceiling follows.
Falsification: any original-source/range/pad/histogram/denominator/refusal/
mask/receipt mismatch; no aliases in actual fidelity geometry; or regression
in independently verified complete workloads. Dense-bit byte improvement is
already falsified for this backend/representation.

All34prior hypotheses retained;25 refined,35 added. Owner rankings1–4 stand:
complete high-endGPU plus verified fixed-context resident1/2/4/8; larger-context
DD with cheapest passing fidelity; complete exclusive/enclosing private phase
and actual capacity telemetry; all-elevenFZC native A/B. DD13/13 gate evidence
does not supply DD privacy acceptance or8B/GPU acceptance. D41/media stand-in
application work does not alter this research target.

Nine LIVE searches and9source records: new older range-check tutorial and
signature-encoding tradeoff; current Plonky3 release/components; Twist/Shout
Oct17 and ChimeraOct16 revisions. Primary links/dates/licenses and access
failures retained in source-records.jsonl. Plonky3 MIT root body inspected;
tutorial license unknown. Linked merge ID cb691115eec1d6347f163811366443232bc0a56d
was visible through primary PR link; commit body cache-missed, so it is not
an inspected commit pin. Release fe5e46d abbreviated only, year unverified.
403PDF/cache-miss/inaccessible primary failures were not bypassed. No author
performance reproduced and no foreign code executed. Next rotation: memory
traffic/commitments and proof composition; stop repeating dense U8 bit layouts.

Final probe/audit research script clocks: {result['measured_script_seconds']:.6f}/
{audit['measured_script_seconds']:.6f}s, RSS{result['rss_kib']}/{audit['rss_kib']}KiB.
Seed202610210122;oneCPU/nice19,30sCPU/alarm,35sparent,256MiBAS,
64MiB estimate. Model-sized arrays never allocated. First successful probe
preserved under initial-pass before control-label metadata cleanup.

{accounting}

Carried baseline, not rerun/reverified: historical nonDD8B T128/L32/one
16-thread CPU pass, GPUoff, total478.737s=0.267370positions/s; prove_run393.785s
includes witness98.348s/load17.595s; seal84.824s overlaps and must not be added.
Receipt922711264B; freshverify42.709s+load13.681s; recheck34.395s+load10.739s.
Startupfraction, isolatedserialization and steadyslope unknown. This is not
a high-endGPU baseline or an8B privacy acceptance.

Next local: inspect exact-alias incidence in the owner's actual cheapest
passing fidelity profile, then independently derive full M/receipt/functional/
group deltas and a native failing-first test plan before any patch proposal.
Owner next: completeGPU exclusive/enclosing clocks, capacity and verified
fixed-context resident1/2/4/8 under shared heavy/build locks. Handoff:
`handoffs/20261021-affine-u8-sharing.md`; main/Claude reviews/integrates, no merge.
Only research outside runtime written. No production/Git/receipt/calibration/
instruction/reviewer changes, builds,GPU,installs,externalwrites/messages,
purchases or escalation. Saved reports do not establish delivered messages
or supervisor liveness. Checkpoint UTC:{now}.
'''
with (ROOT/'FINDINGS.md').open('a') as f:f.write('\n'+detail)
(ROOT/'progress'/f'{RUN}.md').write_text(f'# ZKP efficiency dated progress — cycle0122\n\n'+detail)
(HERE/'README.md').write_text(f'''# Affine U8 source sharing — cycle0122

Run `{RUN}`. **No measured proving gain.** Synthetic semantics and independent
source/cost audits PASS. Dense source-shared bitplanes still cost4.82–5.46x
native U8 helper data. Exact w_s16 aliases have a small conditional benefit:
8MiBdata+0.25MiBmask rows nonDD,2MiB+0.25MiB DD, at frozen8B T128 only.

{table}
`candidate.py::groups/check_bits/check_bundle/dedup` supplies direct research
validators. `native_reference.py` independently interprets the pinned Rust
descriptor source and intersects original affine U8 memberships. `audit.py`
recomputes widths from allowed-set cardinalities and checks native source
roles. No private protocol, native patch, transcript, receipt or verifier.

Signed endpoint, scaled top-bit, Booleanity, ordered-source, padding and
histogram controls pass. 838native descriptors/608families/132564exhaustive
assignments;219independent source/cost checks.6source pins,seed202610210122.

Reproduce sequentially from research root:

```text
python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py probe.py
python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py audit.py
python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py artifact_audit.py
```

OneCPU/nice19;30sCPU/alarm,35sparent,256MiBAS,64MiBestimate. Script clocks
{result['measured_script_seconds']:.6f}/{audit['measured_script_seconds']:.6f}s,
RSS{result['rss_kib']}/{audit['rss_kib']}KiB. These are checker clocks.

Owner seam: layout::lookups_at; Shape counts/helpers/HIds/claim sites;
protocol::byte_histogram_at/helper construction; argument::helper_sum/SC_TAB.
Full native masking/refusal/profile/privacy and M/receipt/group deltas remain
open. New private bitproof costs are null, notzero. Exact aliases change
layout/transcript; do not mutate accepted profiles. See [dated report](../../progress/{RUN}.md),
[ranked queue](hypotheses.json), [source pins](source-manifest.json) and
[handoff](../../handoffs/20261021-affine-u8-sharing.md).

Primary search: [older range examples](https://github.com/BrianSeong99/Plonky3_RangeCheck),
[current compiled components](https://github.com/Plonky3/Plonky3/pull/2292),
[Twist/Shout revision](https://eprint.iacr.org/2025/105),
[Chimera revision](https://eprint.iacr.org/2026/1388). Nine LIVE queries/nine
records; dates/licenses/failures in source-records.jsonl. No upstream timing
or security claim reproduced. Tutorial license remains unknown.

{accounting}
''')
short=f'''# ZKP efficiency progress

Cycle0122 complete — `{RUN}` —2026-10-21UTC.

**No proving speedup measured.** Source-shared byte bits preserve tested
range semantics but still cost4.82–5.46x native helper DATA. This dense
representation is demoted. Exact identity duplicates at frozen8B T128 could
remove8MiBdata+0.25MiBmask rows withoutDD, or2MiB+0.25MiB withDD: conditional
A+H payload reductions0.92%/0.26%. T512 saves0. These are counts, not timings.

{result['checks']}synthetic checks/838native descriptors/608families/132564bit
assignments/26control types PASS; independent219checks/6sourcepins PASS.
Signed endpoints, scaled top bits, source order, padding and histogram/refusal
obligations remain. Nine LIVE queries/nine source records appended. All34prior
hypotheses retained;25refined,35added. Owner topfour unchanged.

{accounting}

Next: actual fidelity-profile alias census and full M/receipt/group budget;
owner completeGPU phases/capacity and verified resident1/2/4/8 remain first.
No nativepatch/proof/GPU or maskreuse. [Experiment](experiments/affine-u8-source-sharing-20261021/README.md),
[dated report](progress/{RUN}.md), [handoff](handoffs/20261021-affine-u8-sharing.md).
Saved reports do not establish delivered messages or supervisor liveness.
'''
(ROOT/'PROGRESS.md').write_text(short)
state=f'''# ZKP efficiency explorer — durable state

Cycle0122 COMPLETE: `{RUN}`. Checkpoint UTC:{now}.
Started06:18:54UTC;deadline06:38:54UTC. Nextcycle no earlier than2026-10-21T07:18:54Z.
AGENDA read at startup/checkpoint. Prior0121 state and all required docs retained
in experiments/affine-u8-source-sharing-20261021/startup/. Prior10447findings
lines/773sources preserved;9records appended. All34prior hypotheses retained,
rank25refined/new35added. No live project docs changed at readback.

No proving gain measured. Probe{result['checks']}checks/838native descriptors/
608families/132564bit assignments/26control types PASS. Independent audit
219checks/244families/6sourcepins/2count-preserving mutations PASS.
Checker clocks{result['measured_script_seconds']:.6f}/{audit['measured_script_seconds']:.6f}s,
RSS{result['rss_kib']}/{audit['rss_kib']}KiB,oneCPU/nice19,seed202610210122.
30sCPU/alarm,35sparent,256MiBAS,64MiBestimate; no model arrays allocated.

Dense source-shared bit data still4.82–5.46x native U8H; reject this directhash
layout, not every sparse/BooleanPCS. Signed endpoint255exclusion, scaled high
bits, Booleanity, ordered originalA/source links and pad-zero obligations stay.
Signed padsource0 encodes127,notallzero bits. Private bitprotocol unbuilt;
mask/group/CFS counts null. No native speed/peak/receipt/privacy claim.

Narrow conditional lead: frozenw_s16/T128 has two exact identity aliases
sr:1/sg:1. Dedup S13->11/nonDD orDd9->7/DD removesoneHplane. Hrows3790->3724
or3634->3616, data+reservedmask rows8.25/2.25MiB, A+Hfractions0.9173/0.2602%.
Full M/receipt/group/time/actualpeak unknown. T512 has0alias benefit. Both
query and histogram changes required; keepalltabledenominator refusals.
Native transcript changes needversioned profile/owner/privacy review.

Topfour: fullGPU+verifiedresident1/2/4/8; larger-contextDD+cheapestpassingfidelity;
privatephase/capacitytelemetry; nativeall-elevenFZC A/B. Scratchpool stillparked.
DD13/13gate evidence is notDDprivacyacceptance nor8B/GPU acceptance. D41/media
stand-in app direction does not amend private8B target. Newer LOW/HIGH excluded.

{accounting}

Nextlocal: exact aliases in owner's actual cheapestpassing fidelity layout,
independent fullM/receipt/functional/group delta and nativefailing-first test
plan before a patch. Ownernext: completeGPU exclusive/enclosing phases,
actualcapacity,verified fixedcontextresident1/2/4/8 under sharedlocks.
Rotate memorytraffic/commitments and proofcomposition; do not repeat rejected
densebit layouts. Reviewnote:handoffs/20261021-affine-u8-sharing.md.

NineLIVEqueries/nine records include newolderfield-range tutorial and
signature-encoding tradeoff; Plonky3releases/components,TwistOct17,ChimeraOct16.
Plonky3rootMITinspected;tutoriallicenseunknown. PRlinkedmergefullID recorded,
commitbodyinaccessible; notinspectedpin. Releaseyearunknown. PDF403/cachemiss/
primaryinaccessible retained;no bypass orupstreamreproduction.

Carried historical8B T128/L32/one16threadCPU pass,GPUoff,total478.737s,
0.267370positions/s;prove_run393.785s includeswitness98.348s/load17.595s;
seal84.824soverlaps. Receipt922711264B;freshverify42.709s+load13.681s,
recheck34.395s+load10.739s. Startupfraction/isolatedserialization/steadyslope
unknown. Not rerun/reverified here; not highendGPU/8Bprivacyacceptance.

Only research outside runtime written;main/Claude reviews/integrates,nomerge.
No production/Git/receipt/calibration/instruction/reviewer edits,build,GPU,
install,externalwrite/message,purchase or escalation. Reports do not establish
delivery/liveness. Completion integrity audit follows this checkpoint.
'''
(ROOT/'STATE.md').write_text(state)
handoff=f'''# Owner review note — affine U8 sharing / small exact-alias candidate

Cycle0122 `{RUN}`. **No measured proving gain or native patch.**
Dense original-source bitplanes lose on logical DATA (4.82–5.46x nativeU8H).
Preserve that negative. A narrower exact-expression alias is reviewable:
at frozenw_s16/T128, `scaled(sr:1,1)` and `scaled(sg:1,1)` duplicate already
present byte lookups. S13->11/nonDD; Dd9->7/DD. Other scaled checks and signed
pairs are not redundant. The condition is public window geometry, not private
value equality. T512 has no such aliases in this census.

Prospective interface in research: `candidate.py::dedup(expressions)` returns
first-occurrence expressions and `(removed_ordinal,kept_ordinal)` aliases;
all identifiers remain ordered original sources. No production patch exists.
`groups/check_bits/check_bundle` are semantic validators only, not private proof.

Pinned native seams (`experiments/affine-u8-source-sharing-20261021/source-anchors.json`):

- `private_block/layout.rs::lookups_at`: select exact aliases only in a new
  reviewed profile; legacy lists stay reproducible.
- `shape.rs::lookups_per_position/helpers/h_plane_doms/claim_sites`, plus
  HIds and layout offsets: coordinate all plane/site/count changes.
- `protocol.rs::lookup_values_at/byte_histogram_at` and H construction:
  use the same reduced descriptor list on both sides; retain whole-table
  denominator and every original refusal/nonU8 check.
- `argument.rs::helper_sum/SC_TAB`: paired-helper polynomial and global sum
  must use that same list; re-pairing moves coefficients/claims and transcript.

Conditional unchanged-rowwidth/all-other-sites H savings: nonDD3790->3724rows,
8MiBdata+0.25MiBreservedmask; DD3634->3616rows,2MiB+0.25MiB. A+H payload
-0.9173%/-0.2602%. Remaining masks are fresh; one removed site means one fewer
required pair only after a reviewed new schedule, never pair reuse. Complete
M/receipt/functional/group costs unknown. Physical HWM/time gain unknown;
f-exclusive free-deletion ceiling1/(1-f), no numeric GPU rate justified.

Validation: {result['checks']}synthetic checks/838native descriptor instances/
608families/132564bit assignments/26control types;219independent source/cost
checks,6pins,2source-mutation controls. Original field-range intersections,
signed[-127,127], highbits, nonBoolean bits, wrong source/order, padded zeros,
stale histogram and absent-entry denominator cases retained. Same researcher
authored reference; not external review, native receipt, or privacy theorem.

Reproduce with `python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py
probe.py`, then `audit.py` through the same wrapper. OneCPU/nice19,<7s measured
per checker,256MiBAS. Source hashes/commands/seed202610210122 retained.

Before integration: inspect owner's actual cheapest passing fidelity descriptors;
derive every M/receipt/group/functional delta; write native failing-first
refusal/round/nextchallenge/receipt tests; owner review/profile/privacy gates;
independent verify; enclosing phase+full-workload A/B under shared heavy/build
locks. Legacy byte equality applies only to untouched profiles; the candidate
needs a distinct pinned profile. Do not launch GPU work from this lane.

Priority: small capacity/count cleanup behind completeGPU and resident clocks,
DD/fidelity and all-elevenFZC. No merge by explorer. No change to private8B
>=50 provedtokens/s target. No mask/opening reuse or coverage weakening.
'''
(ROOT/'handoffs/20261021-affine-u8-sharing.md').write_text(handoff)
dump('checkpoint-summary.json',dict(run_id=RUN,cycle=CYCLE,utc=now,source_records_added=len(records),
 prior_source_records=len(prior_records),prior_findings_lines=len(old_findings.splitlines()),
 result_checks=result['checks'],audit_checks=audit['checks'],hypotheses=len(hyp),new_verified_positions=0))
print(json.dumps(dict(reports_written=True,sources_appended=len(records),hypotheses=len(hyp),utc=now)))
