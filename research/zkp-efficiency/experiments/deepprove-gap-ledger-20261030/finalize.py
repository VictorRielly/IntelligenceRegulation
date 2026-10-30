"""Reconcile late owner evidence, check local report links and final pins."""
from pathlib import Path
import datetime
import hashlib
import json
import re

E=Path(__file__).resolve().parent
R=E.parent.parent
RUN='20261030T204123Z-0f14d260'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()

late='''
## Closing update: coordinator study and D53 received

The coordinator study landed during closing and was read with its handoff,
arithmetic output and GPU-lane ledger; copies and hashes are in
`late-owner/` and `late-owner-pins.json`. D52 concerns a separate synthetic
privacy challenge. D53 holds publication until GPU proving and verification
exist; the GPU-classifier lane is now owned by Claude. Neither adds research
GPU authority, changes privacy or establishes GPU performance. No owner job
was duplicated or restarted.

This supersedes the initial next-action order: **masked streaming LogUp-GKR
against committed H helpers comes before the derived-linear-plane census**.
The coordinator cites older TinyLlama T128 measured phase rows: H commit +
inverses + open =30.03s/152.2s (19.7%); selected hiding-related rows
18.39s/152.2s (12.1%). Those are historical phase attribution, not a matched
causal P1/public-IO A/B or current Shieldstral/8B-GPU measurement. Its
1.37–1.57 roofline factor for masked LogUp-GKR and 40–50% receipt reduction
are models with unmeasured added GKR/privacy cost. We do not promote them to
observed improvements. MAC/s normalization is a useful workload proxy; it
does not normalize lookup, precision, proof, privacy or witness work.
Multiplying a legacy public-FFN CPU/GPU ratio by bandwidth ratios also
remains an inference, not a measured attribution of all cross-system gaps.

Next bounded local experiment: a streamed Fp2 byte-fraction-tree and fresh
alpha-dependent pair-table oracle, with independent leaf/root/ordered-link
equations and controls for missing leaves, zero denominators anywhere in
the declared public table, changed multiplicities, root disclosure and
binding. Start at2^10..2^16 synthetic lookups and stream larger counts only
if the strict resource estimate permits. Count every layer's arithmetic,
bytes and live buffers. The65536entry pair table must be rebuilt after
each fresh alpha; only its public index plan is reusable. Keep roots and
all intermediate claims private until a reviewed masking construction and
joint-view simulator exist. Two cancelling leaves do not by themselves
prove uniformity or privacy: specify their distribution and check it,
including zero/refusal cases. This arithmetic oracle is not called a GKR
proof. Native masked proof verification remains a separate gate.

The coordinator's handoff suggests up to1GiB and2^20/2^22/2^24 lookups. The
active user limits are stricter: **one thread, at most60s and512MiB**; no
dependency install/build/GPU. Larger native throughput measurements are
proposals for the owner/shared locks, not jobs launched here. A Python
one-thread diagnostic cannot be compared directly with its54ns/lookup
sixteen-thread cost law. The proposed kill condition (CPU cost>=0.7of the
helper baseline AND bytes>=baseline) needs matched implementations and
all masking/setup/binding costs. The170B/lookup GPU traffic baseline is a
model, not current device telemetry. Derived-linear and wider-limb censuses
remain companions, and all previous fraction-tree privacy/capacity negatives
remain binding research evidence.
'''
gap=E/'GAP_ANALYSIS.md'
with gap.open('a') as f:f.write('\n'+late)
handoff=R/'handoffs/20261030-deepprove-gap-path-ceiling.md'
with handoff.open('a') as f:f.write('\n'+late)
progress=R/'PROGRESS.md'
s=progress.read_text().replace('Next: inventory the actual accuracy layout\'s A/H planes, PCS vectors and\nterminal consumers before proposing hidden layer chaining. Main/Claude owns\nreview and integration; no Rust patch or production change was made.',
'''Closing update: the coordinator's gap study arrived and was read. Next is a
small streamed, masked-LogUp-GKR prerequisite against H helpers; retain all
old root-disclosure, binding and memory negatives. Its projected savings
remain models. D53's GPU-classifier lane belongs to Claude; no duplicate
job was launched. Main/Claude owns review and integration. No Rust patch.''')
progress.write_text(s)
dated=R/'progress'/f'{RUN}.md'
with dated.open('a') as f:f.write('\n'+late)
findings=R/'FINDINGS.md'
s=findings.read_text();mark=s.index(f'## Cycle0172 — {RUN}')
prefix,last=s[:mark],s[mark:]
# Dated-report links need a different base when embedded in root FINDINGS.
badlinks=[]
for label,target in re.findall(r'\[([^\]]+)\]\(([^)]+)\)',last):
    if not target.startswith(('https:','http:','#')) and not (findings.parent/target).exists():
        badlinks.append({'label':label,'target':target})
if badlinks:
    (E/'initial-report-link-failure.json').write_text(json.dumps({'scope':'New appended FINDINGS links only; no experiment/native failure','links':badlinks},indent=2)+'\n')
last=last.replace('(../experiments/','(experiments/').replace('(../handoffs/','(handoffs/')
findings.write_text(prefix+last+'\n'+late)
state=R/'STATE.md'
s=state.read_text()
s=s.replace('Coordinator\nresults/zk60_deepprove_gap_20261030/ absent on inspection; local gap prerequisite\nsaved without duplicating owner production work.',
'''Coordinator study absent initially, then received/read at closing with
its arithmetic and handoff. Source pins in late-owner/. D53GPUclassifier
lane belongs toClaude; no duplicatejob. Local path-negative remains valid.''')
old='''Next local: source-pin current accuracy-layout constructors; census A/H
deterministicactivations versusrange/multiplicity/challengehelpers,PCS
groupvectors/queriedcolumns andeveryterminalconsumer. Independentequations
and typedpublicinventory withmissinghost/missingrange/reorderedgroupcontrols.
Then propose versioned hiddenGKR under D8/D11,D12,D18; neverdropcommitments
from currentreceipts. Owner measures exclusiveA/Hencode/hash/open/slots/
witness/serialization andverifiedGPUresidentworkloads undercurrentlocks.
Read coordinatorGAP_ANALYSIS whenitlands. Do notduplicateR14/classifierjobs.'''
new='''Next local perreceivedhandoff: small streamedFp2bytefractiontree plus
freshalpha65536entrypairtable oracle,2^10..2^16syntheticlookups initially.
Independentleaf/root/orderedlink equations; missingleaf,multiplicity,all-
publictablezero/refusal,rootdisclosure andbindingcontrols. Count everylayer
andlivebuffer. Pairtable rebuilds peralpha; no mask/privateopeningreuse.
Specify cancelling-leafdistribution andcheckuniformity; keep allroot/layer
claimsprivate pending reviewedmasking/simulator. ArithmeticnotGKRproof.
Strictusercaps1thread/60s/512MiB overridehandoff1GiB/largersizes; matched
native54ns/lookupbaseline and170B/lookup areownerlaws,notPythoncomparison.
Killrule>=0.7helperCPUcostAND>=helperbytes needsmatchedall-inimplementation.
Derivedlinear/AHvectorcensus andwiderlimbs remaincompanions. OwnerGPUphase
clocks andresidentproofs underlocks; no duplicateR14/classifier/GPUjobs.'''
assert old in s
s=s.replace(old,new)
s=s.replace('H107newconditionalpriority4: hiddenbackwardlayerchaining can potentially\nremove deterministicintermediatecommitments; classify actualaccuracyA/H\nplanesandallterminalconsumers first.',
'''H107refinedpriority4: maskedstreamedLogUpGKR againstHhelpers is first
percoordinatorhandoff; derivedlinearplane census follows. Potential recurring
commitment reduction has unmeasured GKR/privacy/binding costs.''')
s=s.replace('checkpoint'+s.split('checkpoint',1)[1].split(';',1)[0]+';', 'checkpoint'+now+';',1)
state.write_text(s)

hypotheses=E/'hypotheses.json'
h=json.loads(hypotheses.read_text())
for x in h:
    if x.get('rank')==107:
        x['initial_candidate_scope']=x['title']
        x['title']='REFINED masked streamed LogUp-GKR removes committed H; derived linear planes companion'
        x['late_owner_evidence']='Coordinator study/handoff received at closing. Historical TinyLlama H30.03/152.2s;1.37..1.57GPUroofline ismodel,not nativeproof improvement.'
        x['next_experiment']='Streamed synthetic Fp2fractiontree andfreshalpha pairtable oracle,initial2^10..2^16lookups;all originalzero/refusal/orderedbinding negatives;specifyrootmaskdistribution. No publicroot or GKRproofclaim.'
        x['resource_limits']='Activeuser1thread/60s/512MiB dominateslooserhandoff1GiB;largernativework proposedownerlocks.'
        x['baseline']='Current committedHhelpers;54ns/lookupon16threads and170B/lookupGPU areownermodel laws. Needmatchednativecompletecomparison.'
        x['eliminated_work']='Potential Hcommit/open andhelperzero-checktraffic,not yet eliminated. Keeplookupmultiplicities/ranges/leafbinding;freshroot/layerprivacy.'
        x['added_costs']='Alltree layers,pairtableperalpha,zero-checks,root/layerCFSorLibra masking,M/PCSrows,leafbindings,recomputation andverification.'
        x['falsification']='Incorrectleaf/root/orderedbinding/zero/refusal/maskedjointview,oraddedcost>=criticalsaving. Ownerkill>=0.7helperCPUAND>=helperbytes requiresmatchedall-inimplementation.'
hypotheses.write_text(json.dumps(h,indent=2)+'\n')
queue=json.loads((E/'ranking-current.json').read_text())
for i,x in enumerate(queue):
    if x.get('rank')==107:queue[i]=next(z for z in h if z.get('rank')==107)
(E/'ranking-current.json').write_text(json.dumps(queue,indent=2)+'\n')

checks={}
def check(k,v):
    assert v,(k,v)
    checks[k]=checks.get(k,0)+1
for p in [state,progress,dated,gap,handoff,E/'README.md']:
    for label,target in re.findall(r'\[([^\]]+)\]\(([^)]+)\)',p.read_text()):
        if not target.startswith(('https:','http:','#')):
            check('local_report_link',(p.parent/target).exists())
for label,target in re.findall(r'\[([^\]]+)\]\(([^)]+)\)',findings.read_text()[mark:]):
    if not target.startswith(('https:','http:','#')):check('new_findings_link',(R/target).exists())
records=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines() if l.strip()]
check('source_count',len(records)==1168)
cycle=json.loads((E/'sources-cycle.json').read_text())
check('appended_sources',records[-10:]==cycle)
check('hypothesis_history_preserved',len(h)==108)
check('main_result',json.loads((E/'result.json').read_text())['status']=='PASS')
check('audit_result',json.loads((E/'audit-result.json').read_text())['status']=='PASS')
for pin in json.loads((E/'source-pins.json').read_text()):
    check('native_snapshot_pin',hashlib.sha256((R/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
    check('native_source_unchanged',hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
completion=json.loads((E/'completion.json').read_text());completion['checkpoint_utc']=now
completion['late_owner_reconciled']=True
(E/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
# Regenerate the manifest after all report corrections and late evidence.
manifest=[]
for p in sorted(E.rglob('*')):
    if p.is_file() and p.name not in ['artifact-manifest.json','completion.json','final-integrity.json']:
        b=p.read_bytes();manifest.append({'path':str(p.relative_to(R)),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
(E/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for pin in manifest:
    check('artifact_pin',hashlib.sha256((R/pin['path']).read_bytes()).hexdigest()==pin['sha256'])
check('before_deadline',now<'2026-10-30T21:01:23')
out={'status':'PASS','checkpoint_utc':now,'checks':checks,'new_verified_positions':0,'late_owner_reconciled':True}
(E/'final-integrity.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
