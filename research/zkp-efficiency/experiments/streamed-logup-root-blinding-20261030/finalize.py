"""Checkpoint research artifacts only; never edits production or runtime/."""
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PROJECT = ROOT.parent.parent
RUN = '20261030T214123Z-4c34fc82'
NOW = datetime.now(timezone.utc).isoformat()
EXP = HERE.name


def save(name, value):
    (HERE/name).write_text(json.dumps(value, indent=2)+'\n')


main = json.loads((HERE/'result.json').read_text())
audit = json.loads((HERE/'audit-result.json').read_text())
rec = json.loads((HERE/'recurrence-result.json').read_text())
execs = {name: json.loads((HERE/(name+'.execution.json')).read_text()) for name in ('experiment.py','audit.py','pair_table_recurrence.py')}
assert all(x['exit_code'] == 0 for x in execs.values())
assert main['status'] == audit['status'] == rec['status'] == 'PASS'
slower = sum(c['all_in_recurrence_s_diagnostic'] >= c['direct_root_s'] for row in rec['rows'] for c in row['cases'])

# Preserve the required read-only project memory in the startup evidence.
docs = ['CLAUDE.md', 'docs/zkmatrix-poc/MVP_STATUS.md', 'docs/zkmatrix-poc/ZK60_DECISIONS.md',
        'docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md', 'docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md',
        'docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md']
doc_pins = []
for rel in docs:
    p = PROJECT/rel; b = p.read_bytes(); (HERE/'startup'/p.name).write_bytes(b)
    doc_pins.append({'path': str(p), 'sha256': sha256(b).hexdigest(), 'bytes': len(b)})
save('startup/required-doc-pins.json', doc_pins)
findings = (ROOT/'FINDINGS.md').read_text()
save('startup/findings-read-index.json', {'lines': len(findings.splitlines()),
    'headings': [line for line in findings.splitlines() if line.startswith('## Cycle')],
    'latest_reviewed_cycle': '0172', 'prior_source_records_fully_parsed': 1168})

source_specs = [
 ('LogUp-GKR construction and current revision', 'https://eprint.iacr.org/2023/1284', '2023-08-27', '2025-02-20',
  'Primary metadata lists received Aug27,2023 and last of3 revisions Feb20,2025.',
  'An informal fractional-sumcheck construction commits multiplicities instead of per-query helpers.',
  'Refresh, not newly discovered. Public roots/claims do not meet P1; local root distribution tests sharpen the privacy gate.',
  ['Linked PDF HTTP403 Forbidden'], None, []),
 ('Libra small-mask GKR, privacy scope', 'https://eprint.iacr.org/2019/317', '2019-03-29', '2021-11-20',
  'Primary metadata: receivedMar29,2019; last of8 revisions Nov20,2021. CRYPTO2019.',
  'Small random masking polynomials convert GKR to zero knowledge with linear prover asymptotics.',
  'Known technique, newly focused on the missing joint layer-claim wrapper. Not a theorem for our Fp2/PCS/one-opening composition; no author performance reproduced.',
  ['ePrint PDF and IACR archive PDF both HTTP403 Forbidden; abstract metadata inspected'], None, ['https://www.iacr.org/archive/crypto2019/116940229/116940229.pdf']),
 ('Libra implementation/license/history screen', 'https://github.com/sunblaze-ucb/Libra', None, '2022-10-11',
  'Branch history displays Oct11,2022 for latest visible .gitmodules commit; not a verified release date. Full commit fetch Cache miss.',
  'Repository accompanies Libra; README describes test harnesses.',
  'Apache2.0 LICENSE body inspected. README instructions ignored as untrusted data; no scripts/source implementation run or copied. Referenced commit5ffbad560474fa30fd771da75aa29a2fead1b9a3 could not be inspected.',
  ['Commit fetch Cache miss; raw LICENSE and guessed prover.cpp fetch Cache miss'], 'Apache-2.0 (GitHub LICENSE body inspected)',
  ['https://github.com/sunblaze-ucb/Libra/blob/Libra/LICENSE','https://github.com/sunblaze-ucb/Libra/commits/Libra/']),
 ('DeepProve lookup commitments and root checks', 'https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/docs/src/end_to_end_lu.md', None, None,
  'Specific document publication/update date unverified; crawler age is not a publication date.',
  'Separate lookup/table GKR circuits, one multiplicity polynomial per table type, combined numerator0/nonzero denominator; lookup outputs still committed.',
  'Architecture evidence only. Root0/nonzero alone does not bind ordered original leaves. Custom restrictive license read separately; no foreign implementation adopted.',
  [], 'Custom Lagrange License (root text inspected)',
  ['https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/docs/src/lookups.md','https://raw.githubusercontent.com/Lagrange-Labs/deep-prove/master/LICENSE']),
 ('Logup* small-table alternative re-screen', 'https://eprint.iacr.org/2025/946', '2025-05-24', None,
  'Primary receivedMay24,approvedMay26,2025; approval is not a revision. Author PDF says May2025.',
  'Indexed lookups can avoid committing extra arrays of the indexing-array size; uses a small extension-field pushforward.',
  'Previously assessed in cycles66..68, not new. Author PDF inspected; does not remove hidden original-index binding or the GKR masking cost. No port.',
  [], None, ['https://levs57.github.io/logup_.pdf']),
 ('Recent zkDuel matched-kernel boundary', 'https://arxiv.org/abs/2610.37710', '2026-10-26', None,
  'Primary submission v1Oct26,2026 21:28:29UTC; no later version displayed.',
  'Matched CUDA/Triton prime-field sumcheck kernels with CPU-reference/checksum validation on H100/A100.',
  'Refresh: kernel counts and cross-backend checks do not give masked GoldilocksFp2 complete-model rates. No author result reproduced.',
  [], None, []),
 ('NEW older finite-difference technique assessment for public table generation', 'https://dlmf.nist.gov/3.3', None, '2026-09-15',
  'DLMF footer states Version1.2.8 releaseSep15,2026; this is the site release, not a chapter revision. Section3.3(iv) cites1974/1975 treatments; original chapter publication date unverified.',
  'Newton/divided-difference representations describe low-degree polynomial evaluation and updates.',
  'Background mathematics, not a supplied GPU algorithm. Our independently derived degree1 row/column recurrence cuts setup multiplications but adds subtractions and retains1MiB/gather traffic. Local tests establish exactness, not this source.',
  [], 'No implementation inspected/adopted', []),
 ('Current DeepProve release availability', 'https://github.com/Lagrange-Labs/deep-prove/releases', None, None,
  'No release timestamp or artifact exists on inspected page; no current update date established.',
  'Page explicitly reports no releases.',
  'Do not treat changelog version labels or commit messages as published release benchmarks. No download or execution.',
  [], None, [])]
existing = [json.loads(line) for line in (ROOT/'sources.jsonl').read_text().splitlines() if line.strip()]
records = []
for i, (title,url,published,updated,date_evidence,claim,assessment,issues,license_,extra) in enumerate(source_specs, 1):
    records.append({'id': f'cycle0173-source-{i}', 'cycle': '0173', 'run_id': RUN,
        'recorded_at_utc': NOW, 'access_date': '2026-10-30', 'access_timezone': 'UTC',
        'title': title, 'url': url, 'inspected_urls': [url]+extra,
        'publication_date': published, 'verified_update_date': updated, 'date_evidence': date_evidence,
        'implementation_license': license_, 'inspected_commit_id': None,
        'author_claim': claim, 'assessment': assessment, 'access_issues': issues,
        'prior_exact_url_records': sum(row.get('url') == url for row in existing),
        'evidence_kind': 'Native LIVE tools.web__run search/open/find/click; source instructions ignored',
        'external_execution': False, 'reproduced_performance': False})
save('sources-cycle.json', records)
existing_ids = {row.get('id') for row in existing}
with (ROOT/'sources.jsonl').open('a') as f:
    for row in records:
        if row['id'] not in existing_ids:
            f.write(json.dumps(row, sort_keys=True)+'\n')
save('web-searches-and-blockers.json', {
    'queries': ['LogUp GKR zero knowledge fractional sums root denominator random leaves Libra zero knowledge 2026',
                'Libra zero knowledge GKR masking polynomial 2019 paper github',
                'site:github.com Lagrange-Labs deep-prove logup gkr fractional sum lookups',
                'LogUp* paper 2026', 'site:github.com/sunblaze-ucb/Libra/commit 2019',
                'site:github.com/Lagrange-Labs/deep-prove/releases 2026 October',
                'GKR zero knowledge sumcheck lookup October 2026 site:arxiv.org/abs',
                'site:eprint.iacr.org/2026 streaming zero knowledge GKR October lookup'],
    'excluded_secondary_page': 'sasha.place October12 LogUp* blog search result; full page inaccessible, not relied on for technical facts',
    'primary_fetch_issues': [issue for row in records for issue in row['access_issues']],
    'bypass': False, 'downloaded_code_executed': False, 'inspected_external_commits': []})

prior = json.loads((ROOT/'experiments/deepprove-gap-ledger-20261030/hypotheses.json').read_text())
save('prior-hypotheses.json', prior)
hyp = json.loads(json.dumps(prior))
h107 = next(x for x in hyp if x.get('rank') == 107)
h107.update({'tested_cycle0173': 'Bottom-up streamed arithmetic16cases N1024..65536, complete table and independent roots pass. No GKR proof.',
             'root_mask_gate': 'Equal-denominator cancelling leaves rejected: square-coset leakage; independent extension-field nonzero scaling has only a root-marginal proof.',
             'next_experiment': 'Reuse prior tiny top-down layer consumer; add an explicit hidden-root/leaf-mask contract and enumerate all layer messages, leaf sites and masks. Price it before larger root-only benchmarks.'})
hyp.extend([
 {'rank': 109, 'priority': 4.1, 'title': 'NEW TESTED cancelling-leaf root marginal and its failure modes',
  'baseline': 'Unmasked LogUp root reveals private denominator product; equal-denominator cancellation was an unspecified candidate, not native code.',
  'eliminated_work': 'No native work removed. Proposed independent-scale pair can remove root-denominator marginal dependence, unlike square scaling.',
  'added_costs': 'Fresh s inFp2, r uniform nonzeroFp2; constrain zero-pair/nonzero relation, new private leaf sites, padding/topology, masks and all joint-message costs.',
  'prerequisites': 'Simulator for complete view, fresh per-proof distributions, bounded sampler/refusal schedule, versioned relation and security-owner review.',
  'integration_cost': 'High protocol design; no Rust patch or native masking change.',
  'exactness': 'Exhaust F121 all121s/120r for2secrets/2variants; GLFp2 opposite-character example, complete public table preserved.',
  'privacy_soundness': 'Equal-denominator mask leaks a bit; base-field scaling also fails; public/reused scale leaks D/ratios; unconstrained leaves can repair a false identity. Corrected root marginal is insufficient for P1.',
  'compatibility': 'Prospective private_block H-helper replacement and ordered original A/histogram links; existing transcripts unchanged.',
  'end_to_end_ceiling': 'Unknown. This is a mandatory privacy gate, not a speed improvement.',
  'falsification': 'Any secret-dependent joint view, unconstrained/nonzero/sampler drift, omitted original binding or weaker refusals. Equal-denominator realization already falsified.'},
 {'rank': 110, 'priority': 4.2, 'title': 'NEW TESTED additive recurrence for fresh public byte-pair table',
  'baseline': '65536Fp2 multiplications build1MiB table after each effectivealpha; direct first layer usesN/2Fp2 multiplies.',
  'eliminated_work': '65535of65536table-setupFp2 multiplies replaced exactly using degree1 row/column differences.',
  'added_costs': '65535Fp2 subtractions+256base denominator subtractions,1MiB writes/storage,8logicalB/lookup gather,serial dependency or256parallel row seeds.',
  'prerequisites': 'Fresh effectivealpha=alpha-gamma*TAG_U8; exact canonical GoldilocksFp2; aggregate same-challenge U8 incidence; matched native all-in costs.',
  'integration_cost': 'Small table-builder in future arithmetic module, but only after reviewed private GKR architecture; no native patch.',
  'exactness': '196608entries versus independent polynomial-basis multiplication,12root comparisons,4controls including corrupted entry vs independent root.',
  'privacy_soundness': 'Only public table/index plan reusable; never cache alpha-dependent values across a new challenge or reuse private masks/openings.',
  'compatibility': 'Private_block U8 helper seam; not a table for exp/act tuple lookups. GPU random-gather costs unknown.',
  'end_to_end_ceiling': 'Unknown setup fraction. Final diagnostic all-in root build slower12/12 despite faster setup. No full-proof factor.',
  'falsification': 'Entry/root/refusal mismatch or table setup+gathers>=direct first-layer critical cost. Native decision deferred; lower priority than privacy design.'}])
save('hypotheses.json', hyp)
ranked = [
 {'priority':1, 'hypothesis':'Owner verified complete high-end GPU resident1/2/4/8 workloads', 'ceiling':'Unknown complete-proof slope', 'action':'Owner lane/shared locks; not launched'},
 {'priority':2, 'hypothesis':'Admitted context/DD/fidelity/proof-window scaling', 'ceiling':'Unknown; dense attention grows quadratically', 'action':'Distinguish long prefill, resident passes and bound decode'},
 {'priority':3, 'hypothesis':'Exclusive native clocks/capacity', 'ceiling':'Unknown critical A/H,slot,witness,serialization and startup shares', 'action':'Owner measurement, avoid nested-clock sums'},
 {'priority':4, 'hypothesis':'H107 masked streamed LogUp-GKR', 'ceiling':'Unknown all-in, owner1.37..1.57GPUroofline remains model', 'action':'Hidden top-down layer/leaf contract before bigger arrays'},
 {'priority':4.1, 'hypothesis':'H109 root marginal gate', 'ceiling':'No speed result', 'action':'Reject equal denominators; keep corrected marginal private pending full simulator'},
 {'priority':4.2, 'hypothesis':'H110 public table recurrence', 'ceiling':'Unknown full-proof setup share', 'action':'Retain exact recurrence; count all-in native costs only after architecture review'},
 {'priority':5, 'hypothesis':'H103 grouped-DD native gates', 'ceiling':'Prior product counts are not timing', 'action':'Existing owner handoff, no duplicate job'},
 {'priority':8, 'hypothesis':'H108 path compression', 'ceiling':'All paths only1.6096%receipt bytes', 'action':'Keep negative/demoted'}]
save('ranking-current.json', ranked)
save('rotation-queue.json', {'this_cycle':['lookup arguments and softmax','sumcheck/GKR','batching/amortization','memory traffic'],
    'next':['masked GKR layer claims and composition','quantization/wider-limb census','GPU NTT/commitments owner phase evidence'],
    'preserved':['proof-window/KV binding','public preprocessing','proof composition'], 'no_foreign_execution':True})

metrics = {'new_independently_verified_full_stack_proofs':0,'complete_model_passes':0,'proved_positions':0,
           'actual_model_context':None,'passes':0,'device':main['hardware']['cpu'],'gpu_used':False,
           'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,'startup_s':None,
           'initial_prefill_s':None,'startup_fraction':None,'proof_latency_s':None,'proof_bytes':None,
           'steady_state_proved_tokens_per_s':None,'total_workload_proved_tokens_per_s':None,
           'long_context_prefill':False,'resident_model_series':False,'decode':False,
           'synthetic_scope':'Byte lookup arrays N1024..65536 are not model context lengths or proved tokens',
           'target':'Complete private8B >=50provedtokens/s RTX5090 or named high-endGPU remains unachieved'}
save('target-accounting.json', metrics)
save('hardware.json', dict(main['hardware'], resource_executions=execs))

design = '''# Root marginal is necessary, not a private GKR construction

For fractions combine `(p,q)+(r,s)=(p*s+r*q,q*s)`. The complete byte
identity has root `(0,D)` with D nonzero and generally dependent on hidden
lookups, even at fixed public length. Publishing D is forbidden here.

The natural cancelling pair `(s,r),(-s,r)` has root `(0,r²)`. For uniform
nonzero r in Fp2, `D*r²` preserves the quadratic character of D. In F121,
two valid lookup cases have disjoint60-element supports, total variation1.
The exact Goldilocks/Fp2 example uses the full public256-entry table and
synthetic private values0/1, with opposite characters. This rejects that
realization, not every possible cancelling-pair construction and not native
code (which never implemented this sketch).

A root-marginal candidate is `(s,1),(-s*r,r)`, with s uniform in Fp2 and
r independent uniform in Fp2 excluding0. It combines to `(0,r)`; adding
it to `(0,D)` gives `(0,D*r)`. Multiplication by any fixed nonzero D is a
bijection of Fp2*, so its denominator is exactly uniform on Fp2*, independent
of D. It is not uniform on the entire field, whose zero is excluded. The
F121 exhaustion has120 outputs, each121times, for both secrets.

This candidate is UNREVIEWED and does not authorize a new native draw or
resampling rule. Define the fresh full-extension-field sampler, bounded
zero handling and complete transcript/refusal schedule for a new profile.
Base-field-only r leaves small cosets. Disclosing r recovers D; reusing r
reveals denominator ratios. Never reuse masks, private openings or scales.

The prover must prove that the two extra leaves cancel and have nonzero
denominators. Otherwise arbitrary leaves cancel a false original identity.
Account for an unbalanced graft versus neutral `(0,1)` padding: a balanced
power-of-two tree can grow to the next power, so two leaves are not
automatically constant-cost inside a frozen layout. This experiment tests
the algebra, not a reviewed topology or soundness theorem.

Every internal numerator/denominator evaluation and sumcheck message still
needs a hiding construction (e.g. an explicitly instantiated Libra/CFS
wrapper), including the joint view with masked PCS openings, salted columns,
root claims and repeated attempts. The earlier mask-per-intermediate row
explosion remains a negative finding. Do not merely attach fresh native
row pairs at every tree terminal and claim a memory win.

Leaves must link to ordered original A limb planes, complete public-table
denominators and committed multiplicities. Reject zero denominators on unused
table entries too. Permuting or deleting matched query/table leaves preserves
the root identity yet changes the proved statement; `(0,0)` passes a weak
cross-product equality. Derive all leaf sites, degrees, mask rows and one
joint opening per commitment (D12), a versioned profile and simulator before
integration. No root, layer claim or mask leaf from this design is proposed
for publication. No whole-proof privacy acceptance follows from this note.
'''
(HERE/'ZK_DESIGN_NOTE.md').write_text(design)

cost_rows = []
for n in (1024,4096,16384,65536):
    c = next(c for c in main['cases'] if c['n'] == n and c['pattern'] == 'uniform')
    cost_rows.append(f"| {n:,} | {c['direct']['fp2_multiplies']:,} | {c['cold_cached_fp2_multiplies']:,} | {1+c['cached']['fp2_multiplies']:,} | {c['packed_peak_selected_bytes']/1048576:.3f} |")
cost_table = '\n'.join(cost_rows)
setup_rows = '\n'.join(f"| {i+1} | {row['direct_build_s']*1000:.3f} | {row['recurrence_build_s']*1000:.3f} |" for i,row in enumerate(rec['rows']))

accounting = '''New independently verified full-stack proofs / complete-model passes /
proved positions: **0 / 0 / 0**. Actual model context: **none**; passes: **0**.
Device: Intel Core Ultra9 185H, one low-priority CPU affinity, **no GPU**.
Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model
proof series or decode ran. Synthetic lookup count is not context length.
Complete private8B **>=50 proved tokens/s on RTX5090 or another named high-end
GPU remains unachieved**. Larger workloads remain allowed; attention can
grow quadratically. No mask, pad or private-opening reuse is proposed.'''

next_action = '''Next local experiment: adapt the existing cycle0109 tiny top-down fraction
layer consumer to an explicit hidden-root/leaf-mask contract. Enumerate every
new layer message, original-A/histogram leaf claim, CFS/Libra mask and opening
group; test its joint-view distribution/rank in a toy field before larger
arrays. Preserve the prior mask-row capacity negative. Main/Claude and the
security owner review the construction; the native owner handles matched
masked receipts and exclusive whole-workload GPU clocks under shared locks.
Do not duplicate D53's Claude GPU-classifier lane or the R14 review.'''

readme = f'''# Streamed LogUp arithmetic and root-blinding prerequisite — cycle0173

Run `{RUN}`, checkpoint {NOW}; deadline22:01:23UTC.
**No measured proving improvement. No GKR proof or Rust patch.**

The current bottleneck lead is recurring H helper work. The coordinator's
historical TinyLlamaT128 profile attributes30.03/152.2s (19.7%) to H commit,
inverses and openings, plus unmeasured/modeled H zero-check share. These are
historical phase rows, not a matched P1/public-IO causal comparison or an8B
GPU profile. Its54ns/lookup16-thread CPU and170B/lookup GPU values are cost
laws, not measurements against this one-thread Python arithmetic.

Baseline: committed inverse helpers and their zero-check/PCS work. Potential
eliminated work: those H commitments, inverses and helper constraints; **none
is removed by this prototype**. Added costs: public pair-table setup, every
fraction layer, top-down GKR reductions/recomputation, mask and root constraints,
ordered A/table bindings, new PCS sites, serialization and verification.
End-to-end ceiling remains `N/(T-C_removed+A_added)`, unknown until exclusive
native clocks and a complete masked construction exist. Free removal of only
the three historical H phases would give1.246x on that historical block,
before added work; that is not a bound on other savings or GPU throughput.
The coordinator's1.37–1.57GPU roofline/40–50%receipt models remain unmeasured.
Falsify on any arithmetic/binding/refusal/joint-view mismatch or A_added>=the
critical removed cost. The coordinator's0.7CPU-and-equal-bytes kill rule needs
matched all-in native implementations; it cannot be evaluated here.

`candidate.py` keeps only current/next packed layers, not the complete tree.
It is a bottom-up root builder. Discarding a layer creates future recomputation
or storage work for top-down GKR, which is absent here and must be charged.
`reference.py` uses independent polynomial-basis arithmetic, histogram sums
and sequential fraction addition. `audit.py` imports neither implementation
and uses Karatsuba products/norm inverses to reconstruct all16large cases,
all10tiny fixtures, costs and root distributions.

Main PASS: {main['total_checks']:,} checks;16cases (two synthetic challenges,
uniform/single-hot arrays,2^10..2^16lookups), all131,072pair-table entries,
ten tiny sequential roots and13negative controls. Every query/table identity
matches; all public-table entries are checked even with multiplicity0.
Audit PASS: {audit['total_checks']} checks and3additional controls. Roots alone
do not bind order/multiplicity/leaves; those controls expose the obligation.

**Root result:** `(s,r),(-s,r)` is rejected because D*r² leaks the quadratic
character. F121 exhaustive supports are disjoint60-element sets (TV1), and
GoldilocksFp2 confirms an opposite-character pair at equal public length.
`(s,1),(-s*r,r)` with fresh uniform nonzero extension-field r makes only the
root denominator uniform on Fp2* (TV0 in exhaustion). It does not hide other
messages or prove cancellation/binding. [Design note](ZK_DESIGN_NOTE.md).

| Query lookups | Direct root Fp2 mul | Full table + root mul | Additive table + root mul | Selected packed peak MiB |
|---:|---:|---:|---:|---:|
{cost_table}

Direct counts:2N-3; full table:65536+3(N/2-1). The latter saves multiplications
only above131072aggregate lookups under one effective challenge. This threshold
is **superseded for multiplication counts** by the additive recurrence:
`Q(a,b+1)=Q(a,b)-(alpha-a)` and `Q(a+1,0)=Q(a,0)-alpha`.
It needs1Fp2multiply+65535Fp2subtracts+256base denominator subtractions.
The1MiB table and8logical extra gather bytes/lookup remain. Logical operand
byte counts are an ideal packed accounting model, not DRAM telemetry; scratch,
Python objects, reference tables, GKR and private wrappers are excluded from
selected-array peaks; diagnostic layer-hash copies are included. Process RSS
is measured separately. The initial buffer ledger omitted hash copies and
is preserved under initial-layer-buffer-ledger/; the corrected ledger passed
the independent audit, and noncanonical challenges are now explicitly refused.

Recurrence PASS: {rec['checks']:,} checks,196608entries across3challenges,
12root comparisons and4controls; the mutated table entry changes a two-leaf
root against the independent oracle. Setup diagnostic milliseconds:

| Synthetic challenge | Ordinary | Additive recurrence |
|---:|---:|---:|
{setup_rows}

Final all-in root construction is slower in **{slower}/12** cases. The initial
run was slower11/12; it is preserved under initial-recurrence/. The rerun
strengthened the entry-corruption control; timings are noisy diagnostics,
not a selected best-case speed claim. Reduced arithmetic is useful to retain,
but neither table generation nor this root is the native full prover.

CPU executions (one nice19 affinity,256MiBAS,40/42sCPU,45s alarm,50sparent):
main {execs['experiment.py']['wall_s']:.3f}s/{execs['experiment.py']['peak_rss_kib']}KiB;
audit {execs['audit.py']['wall_s']:.3f}s/{execs['audit.py']['peak_rss_kib']}KiB;
recurrence {execs['pair_table_recurrence.py']['wall_s']:.3f}s/{execs['pair_table_recurrence.py']['peak_rss_kib']}KiB.
Memory estimate64MiB; every experiment below60s/512MiB. Python3.10.12,
Intel Core Ultra9 185H, seed20261030173; recurrence seed2026103017301.

```
python3 -B experiments/{EXP}/run_bounded.py experiment.py
python3 -B experiments/{EXP}/run_bounded.py audit.py
python3 -B experiments/{EXP}/run_bounded.py pair_table_recurrence.py
```

Future seam: `hashline/src/private_block/protocol.rs::{{write_h,logup_sum_claim,prove_core}}`,
actual shape's helpers/H-plane schedule and leaf bindings; GoldilocksFp2 in
`zkp-core/src/field.rs`. FrozenR18 shape/layout and main toy protocol are
pinned separately; do not claim the toy protocol is the registered classifier.
No production edit or profile change. Public table key is the **effective**
alpha (native U8 alpha-gamma*TAG_U8), field and alphabet. Rebuild per challenge;
only share within the same public challenge/type, never masks or private
openings. This256byte pair table is not an exp/act tuple lookup replacement.

Eight LIVE primary-source records1168->1176: LogUp-GKR, Libra paper/repository,
DeepProve lookup docs/license, prior Logup*, currentOct26zkDuel, and newly
assessed older finite-difference background in NISTDLMF. Exact dates/limits,
URLs and licence details are in sources-cycle.json. No external implementation
commit inspected; the Libra commit fetch failed. PDFs403, raw/commit Cache
misses and inaccessible secondary blog are recorded without bypass. No foreign
code copied/executed or author performance reproduced.

All108prior hypotheses preserved; H107 refined, new H109root-marginal and
H110public-table hypotheses added (110total). Top3remain whole high-endGPU
verified workloads, admitted context/DD/fidelity scaling and exclusive native
clocks/capacities. [Ranking](ranking-current.json).

{accounting}

{next_action}

Only this research directory outside runtime/ was written. No production,
Git metadata, receipts, calibration, safety gates, instructions or reviewer
files changed. No builds, GPU jobs, installs, downloaded scripts, external
writes/messages, purchases, escalation, merges or supervisor/liveness actions.
Saved reports do not establish delivery to Victor.
'''
(HERE/'README.md').write_text(readme)

handoff = f'''# Review handoff: streamed LogUp root masks and additive public table

Cycle0173, `{RUN}`. No proving improvement, native proof, Rust patch or privacy
acceptance. [Evidence](../experiments/{EXP}/README.md) and
[one-page design note](../experiments/{EXP}/ZK_DESIGN_NOTE.md).

The equal-denominator realization `(s,r),(-s,r)` of the coordinator's
cancelling-leaf sketch leaks the quadratic character of hidden D. This is a
counterexample to that realization, not a native vulnerability. Exhaustive
F121 shows TV1 for valid equal-length cases; the full-byte GoldilocksFp2
example confirms opposite characters. A pair `(s,1),(-s*r,r)`, with fresh
uniform nonzero Fp2 r and independent Fp2 s, has exactly uniform nonzero root
denominator after multiplication by any fixed D. Only the root marginal is
proved. All intermediate/leaf claims remain private pending a joint simulator.
Constrain the zero-pair itself: otherwise mask leaves can fix a false identity.
Base-field scales, disclosed/reused scales and `(0,0)` are explicitly negative.

Useful exact table refinement: initialize `Q(0,0)=alpha²`, step b by subtracting
`alpha-a`, and step row starts by subtracting alpha. Full65536entry setup
falls from65536Fp2multiplications to1multiply+65535Fp2subtracts (plus256base
subtractions). All196608entries across3challenges match independently; a
corrupted entry changes the two-leaf root. A parallel per-row version would
cost256multiplies instead of1; no GPU test. The1MiB table, fresh-alpha rebuild,
8logicalB/lookup gathers and every private-GKR cost remain. Final all-in
root construction slower{slower}/12 diagnostic cases; **do not claim speedup**.

Interface: local `query_root(values,alpha,table)` returns PRIVATE `(numerator,
denominator)` plus every layer's arithmetic/byte/buffer ledger. `additive_table`
returns the public effective-alpha keyed array. Neither returns a proof.
`cancelling_pair(field,s,r,mode)` is arithmetic only. Patch/design location:
native private_block H helper generation (`write_h`, `logup_sum_claim`,
`prove_core`), shape/layout H domains, masked argument and ordered original-A
terminal claims. Main toy protocol and frozenR18 shape are pinned separately.
No production change is supplied or authorized; main/Claude reviews/integrates.

Validation: main247337checks/16large+10tiny fixtures/13controls; independent
audit179checks/3extra controls; recurrence196627checks/12roots/4controls.
One nice19CPU; main2.131s/19992KiB; audit0.167s/15400KiB;
recurrence1.730s/20716KiB. No nativeGKR/PCS/CFS/proof verification.

Baseline current helper commit/inverse/open plus constraints. Potential
elimination is recurring H work, not startup. Added masks, all tree reductions,
leaf bindings, new sites, topology/padding, recomputation and verifier costs
are unpriced. Historical30.03/152.2sH attribution and owner54ns/lookup16-thread
law/170B GPU model are not matched Python baselines. Complete8B gain unknown.
Reject any arithmetic/order/multiplicity/whole-table-zero/refusal/privacy
mismatch or all-in added cost>=removed critical work. The native0.7helperCPU
AND equal-bytes kill rule is still unevaluated.

{next_action}
'''
(ROOT/'handoffs/20261030-streamed-logup-root-blinding.md').write_text(handoff)

progress = f'''# ZKP efficiency progress

Cycle0173 complete — {RUN}; {NOW}.

**No measured proving improvement.** A privacy prerequisite found a useful
negative: two cancelling fractions sharing one random denominator preserve a
hidden square-class bit. The unequal-denominator alternative passes exhaustive
root-marginal uniformity tests; it still needs complete layer/leaf privacy,
sound cancellation constraints and original-witness binding.

The streamed byte-lookup arithmetic matches independent references in16cases
through65536lookups. Main247337checks and13controls; independently authored
audit179checks plus3controls pass. A public first-difference recurrence cuts
table setup from65536Fp2multiplications to1multiply+65535subtracts;196608entries
and12roots match. It retains1MiB and gather costs. Final all-in root construction
is slower{slower}/12cases, so the arithmetic reduction is not a proof-speed result.

One low-priority CPU only: main2.131s/19992KiB, audit0.167s/15400KiB,
recurrence1.730s/20716KiB. All within60s/512MiB. No GPU or native build.

{accounting}

Eight LIVE records searched/refreshed LogUp-GKR, Libra, DeepProve, Logup*,
recentOct26GPU kernels and older finite-difference background. Dates/licences
and403/Cache-miss limits retained; no external code run. H107 refined;
H109/H110 added; all108previous hypotheses/negative findings preserved.

{next_action}

[Experiment](experiments/{EXP}/README.md) ·
[Design note](experiments/{EXP}/ZK_DESIGN_NOTE.md) ·
[Handoff](handoffs/20261030-streamed-logup-root-blinding.md) ·
[Dated report](progress/{RUN}.md).
Saved reports do not establish message delivery.
'''
(ROOT/'PROGRESS.md').write_text(progress)
dated = readme.replace('](ZK_DESIGN_NOTE.md)',f'](../experiments/{EXP}/ZK_DESIGN_NOTE.md)').replace('](ranking-current.json)',f'](../experiments/{EXP}/ranking-current.json)')
(ROOT/'progress'/f'{RUN}.md').write_text(dated)
findings_path = ROOT/'FINDINGS.md'
marker = f'\n\n## Cycle0173 — {RUN}: streamed LogUp root-mask and table prerequisite\n\n'
prior_findings = findings_path.read_text().split(marker, 1)[0]
findings_report = readme.replace('](ZK_DESIGN_NOTE.md)', f'](experiments/{EXP}/ZK_DESIGN_NOTE.md)').replace('](ranking-current.json)', f'](experiments/{EXP}/ranking-current.json)')
findings_path.write_text(prior_findings+marker+findings_report+'\n')

state = f'''# ZKP efficiency explorer — durable state

Cycle0173 COMPLETE: {RUN}.
Start21:41:23Z; checkpoint{NOW}; deadline22:01:23Z.
Next cycle no earlier2026-10-30T22:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Coordinator DeepProve mandate/study read.
H107streamedLogUp-GKR prerequisite:16synthetic byte-lookup casesN1024..65536,
10tiny roots, every layer,131072pairentries and query/table identities match
independent arithmetic. Main247337checks/13controls; standaloneaudit179checks
plus3controls. Bottom-up root construction only, NOT a GKR proof. Discarded
layers still need recomputation/storage during top-down proving.

NewH109: equal-denominator cancelling leaves(s,r),(-s,r) yield(0,r²) and leak
quadratic character of privateD. F121two valid equal-length cases have disjoint
60element supports(TV1); GLFp2withcomplete256byte table confirms values0/1
oppositecharacters. This rejects one sketch realization, not native code.
Candidate(s,1),(-s*r,r) with fresh r uniform nonzeroFp2 and s uniformFp2 yields
(0,r), so D*r is uniform Fp2* only. Root marginal is NOT joint-view privacy.
Base-field-only scales, disclosed/reused scales,unconstrained false-statement
cancellation and zero denominators remain negatives. Keep all roots/layers
private pending simulator/versioned construction. No native RNG change.

NewH110: public pairtable finite differences use1Fp2multiply+65535subtracts
instead of65536multiplies;196608entries/12roots/4controls pass.1MiBtable and
8logicalB/lookup gathers remain. Rebuild for fresh effectivealpha(alpha-
gamma*TAG_U8); only public shape/index plans reusable. Final all-inroot slower
{slower}/12diagnostic cases; initial11/12 retained. No wall/proof gain claim.
Main2.131s/19992KiB;audit0.167s/15400KiB;recurrence1.730s/20716KiB,
one nice19CPU/256MiBAS. Every experiment<60s/512MiB. No native build/GPU.

All108prior hypotheses preserved,110total. Top3: ownerverifiedhighendGPU
resident1/2/4/8;admittedcontext/DD/fidelity;exclusivenativeclocks/capacity.
H107architecture priority4,H109/H110components4.1/4.2;H103priornativegates5;
H108pathsizeexplanation remainsnegative8. HistoricalH30.03/152.2s is phase
attribution only;54ns/lookup16-thread and170B/lookupGPU areownercostlaws.
All-inGKR/privatebindings unknown; owner1.37..1.57roofline remainsmodel.

{next_action}

{accounting}

Historicalolder8BCPUT128/L32 one16-threadGPU-offpass478.737s(0.267370/s),
prove393.785s includeswitness98.348s/load17.595s;seal84.824soverlapswitness
80.897s/load27.151s;receipt922711264B;verify42.709s+load13.681s carriedonly,
notrerun/reverified/newlycounted. Do notsum nestedclocks. R18one-loadbatch
2.407%saving andloadshare3.193% arecarry-only;loadshareisnotstartupfraction.

EightLIVErecords1168->1176. LogUp-GKR/Libra/Logup*refresh;DeepProve
lookupdocs/release/license;Oct26zkDuel;newolderfinite-differenceassessment
viaNISTDLMF(siteversion1.2.8Sep15,2026,notchapterrevision). PDF403/raw/commit
Cachemisses recorded; no inspected externalcommit or foreign execution.
Onlyresearchoutside runtimewritten;no production/Git/receipts/calibration/
gates/instructions/reviewer/build/GPU/install/externalwrite/message/purchase/
escalation/merge/restart/liveness action. Main/Claude reviews and integrates.

[Experiment](experiments/{EXP}/README.md) ·
[Handoff](handoffs/20261030-streamed-logup-root-blinding.md) ·
[Dated report](progress/{RUN}.md).
'''
(ROOT/'STATE.md').write_text(state)

commands = [{'command':f'python3 -B experiments/{EXP}/run_bounded.py {name}', 'execution':record} for name,record in execs.items()]
save('commands.json', commands)
save('completion.json', {'run_id':RUN,'cycle':'0173','checkpoint_utc':NOW,'deadline_utc':'2026-10-30T22:01:23Z',
    'completed':True,'sources_added':8,'source_total':1176,'hypotheses':len(hyp),'native_proofs':0,'proved_positions':0,
    'scope':'Synthetic arithmetic and root-marginal prerequisite; full private8B goal unachieved'})
print(json.dumps({'checkpoint_utc':NOW,'hypotheses':len(hyp),'sources_added':8,'all_in_cases_slower':slower,
                  'main_checks':main['total_checks'],'audit_checks':audit['total_checks'],'recurrence_checks':rec['checks']}))
