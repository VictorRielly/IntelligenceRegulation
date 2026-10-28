from pathlib import Path
import json,datetime,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];PROJECT=ROOT.parents[1]
RUN='20261020T191854Z-93bbe548';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
old=[json.loads(s) for s in (ROOT/'sources.jsonl').read_text().splitlines()]
records=[]
def source(title,url,publication,updated,assessment,**extra):
    records.append(dict(title=title,url=url,publication_date=publication,verified_update_date=updated,
        access_date='2026-10-20',access_timezone='UTC',recorded_at_utc=now,cycle='0111',run_id=RUN,
        inspected_commit_id=None,implementation_license=None,reproduced_performance=False,
        external_execution=False,evidence_kind='Native LIVE web search/open/find/click; primary sources; embedded instructions ignored',
        prior_exact_url_records=sum(r.get('url')==url for r in old),assessment=assessment,**extra))
source('OpenVM reversible GKR and online challenge boundary refreshed',
 'https://github.com/openvm-org/stark-backend/blob/main/docs/cuda-backend/gkr-prover.md',None,None,
 'Whole retained buffer supports reversal between global challenge rounds. Disposable tiles are a different schedule, tested locally as a cost negative. Bit-reversed GPU coalescing is not reproduced by natural-order Python storage.',
 date_evidence='Mutable main: latest commit/date not exposed in parsed page.',
 access_issues=['Current LICENSE and raw LICENSE fetches returned Cache miss; no current implementation-license body established.'])
source('OpenVM v2.0.1 memory/transfer release check',
 'https://github.com/openvm-org/stark-backend/releases/tag/v2.0.1',None,None,
 'Release advertises phase-specific proving-memory peaks and pooled pinned host transfers. Relevant to owner telemetry, not a measured native or whole-model gain.',
 date_evidence='Release displays14 Aug14:50 without year; short362c7ad only, full commit not inspected.')
source('Efficient-sumcheck streaming/API and unreleased rewrite screen',
 'https://github.com/compsec-epfl/efficient-sumcheck',None,None,
 'Sequential LSB versus MSB source access and final-oracle responsibility remain relevant. Changelog labels canonical rewrite Unreleased; do not call its API a dated release or infer a private cubic replacement.',
 additional_urls=['https://github.com/compsec-epfl/efficient-sumcheck/blob/main/docs/design.md','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/CHANGELOG.md'],
 date_evidence='Changelog0.0.2 dated2026-02-11; Unreleased rewrite/current main update date unverified.',
 license_evidence='Repository declares Apache-2.0/MIT; both license-body links and raw MIT returned Internal Error/Cache miss.',
 access_issues=['MIT/Apache body fetches failed; full commit/date unavailable.'])
source('Earlier sumcheck time-space baseline refreshed',
 'https://eprint.iacr.org/2024/524','2024-04-03','2024-09-11',
 'Known multilinear streaming/checkpoint tradeoff; not a theorem that reversible disposable cubic layers reduce memory or time. No author runtime reproduced.',
 date_evidence='Primary received and last-of2 revisions verified.',paper_license='CC BY metadata')
source('Product-sumcheck streaming bounds refreshed',
 'https://eprint.iacr.org/2025/1473','2025-08-13','2026-02-25',
 'Product-polynomial time-space tradeoffs distinguish interactive from polynomial-oracle protocols. Does not authorize skipping original-A consistency, treating streams as free, or transferring author performance to the private native proof.',
 date_evidence='Primary received/revised history; TCC2025 publication label.')
source('Bits Under ZK-LLM: detailed exactness and precision-cost screen',
 'https://arxiv.org/abs/2609.36437','2026-09-29',None,
 'Detailed HTML inspected: utility evaluator retains floating attention/RoPE/reductions outside chosen QDQ/LUT operators. Large-model proving comparison covers projections, while full proving uses smaller GPT2. Operator-aware precision is useful; neither utility nor timings establish D32 exact native parity or our full private8B target.',
 additional_urls=['https://arxiv.org/html/2609.36437v1'],date_evidence='v1 submitted2026-09-29T00:54:35UTC; no later revision shown.',paper_license='CC BY4.0 HTML label')
source('Hobbit source-bound chunk folding inspected beyond asymptotics',
 'https://www.usenix.org/system/files/usenixsecurity25-pappas.pdf','2025-08',None,
 'Known paper refreshed at technical highlights: naive independent chunk commitments risk recursive extraction; proposed approach commits original polynomials and adds a streaming input-consistency pass. Relevant gate for future chunk folding, not a compatible private native protocol or replicated author gain.',
 additional_urls=['https://www.usenix.org/conference/usenixsecurity25/presentation/pappas'],date_evidence='Official proceedingsAugust2025, conferenceAugust13–15; exact posting day unverified.')
source('NEW older technique: NeutronNova source-bound zero-check folding',
 'https://eprint.iacr.org/2024/1606','2024-10-09','2026-08-18',
 'Group-based zero-check folding is an architecture lead for removing repeated chunk scans. Group commitments, recursive extraction and final PCS differ from native Goldilocks/Ligero. Author speed is not reproduced; original source binding and fresh private composition remain prerequisites.',
 date_evidence='Primary received/last-of2 revisions; CRYPTO2026 major-revision label.')
source('Microsoft Nova experimental NeutronNova implementation screen',
 'https://github.com/microsoft/Nova',None,None,
 'README marks NeutronNova experimental. No releases on release page. MIT body inspected; guessed neutron/mod.rs source URL unavailable, so no algorithm-code, commit or timing inspected.',
 additional_urls=['https://github.com/microsoft/Nova/blob/main/LICENSE','https://github.com/microsoft/Nova/releases'],
 date_evidence='Current main timestamp/full commit unavailable.',license_body='MIT body inspected at main',
 access_issues=['https://github.com/microsoft/Nova/blob/main/src/neutron/mod.rs:Cache miss'])
records[-1]['implementation_license']='MIT body inspected; current main not pinned'
source('NEW older correction: Scorpius and Orion multi-point soundness',
 'https://eprint.iacr.org/2024/1164','2024-07-18','2025-02-14',
 'Primary abstract reports practical unsoundness of prior Orion revisions and repairs including multi-point openings/non-interactivity. Screen any future faster code-PCS replacement against the repaired model; no replacement code or gain reproduced.',
 date_evidence='Primary received and last-of2 revisions verified.',paper_license='CC BY metadata')
source('Current primary seven-day update queue',
 'https://eprint.iacr.org/days/7',None,None,
 'Checked currentOctober20 listing and October16–19 sumcheck/composition work. Queue freshness only, not individual publication timing or proof evidence.',
 date_evidence='Accessed2026-10-20; no paper date inferred from crawler age.')
source('DeepProve precision/source interface refresh',
 'https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/README.md',None,None,
 'Maintainer README separates inference-only wgpu from CUDA PCS and describes12-bit fidelity using cosine similarity. Cosine is not D32 perplexity/LAMBADA. Changelog1.0.1 is dated2025-11-24; no current release/commit or native compatible private proof established.',
 additional_urls=['https://github.com/Lagrange-Labs/deep-prove/blob/master/CHANGELOG.md'],
 date_evidence='Changelog1.0.1 date2025-11-24 verified in primary search result; mutable README date unverified.',
 license_evidence='No license body inspected; no code adopted.')
(HERE/'source-records.json').write_text(json.dumps(records,indent=2)+'\n')
if not any(r.get('run_id')==RUN for r in old):
    with (ROOT/'sources.jsonl').open('a') as f:
        for r in records:f.write(json.dumps(r,sort_keys=True)+'\n')
queries=[
 'site.eprint.iacr.org 2026 GPU sumcheck quantization lookup October',
 'site.github.com openvm stark-backend logup reversible subtree fraction tree',
 'site.eprint.iacr.org zero knowledge quantization exact inference 2026',
 '"Bits Under ZK-LLM" github',
 'site.github.com/openvm-org/stark-backend/releases "2.0.2"',
 'site.eprint.iacr.org "time-space" "sumcheck" streaming',
 'site.github.com sumcheck checkpointing pebbling memory prover',
 '"Time-Space Trade-Offs for Sumcheck" Baweja 2025',
 'site.usenix.org 2025 Pappas space efficient arguments folding sumcheck',
 'site.github.com neutronnova Microsoft Nova folding 2026',
 'site.github.com Scorpius Orion den Hollander Slamanig 2024',
 'site.github.com Lagrange-Labs deep-prove releases quantization softmax 2026']
(HERE/'search-log.json').write_text(json.dumps(dict(tool='native LIVE web.run',queries=queries,queries_count=len(queries),records=len(records),access_date='2026-10-20',execution_of_external_code=False),indent=2)+'\n')
hyps=json.loads((HERE/'imported/hypotheses.json').read_text())
h=next(x for x in hyps if x['rank']==21)
h.update(title='TESTED full-column and disposable reversible tiles: capacity/operation negatives',
 baseline='Prior full column80–128MiB at2^21 leaves; direct adaptive frontier36.022216796875MiB. Matched-source/matched-consumer tile schedule now tested.',
 eliminated_work='No native work removed. Disposable tiles preserve exactly the direct source reads (8B T128313065984/293011968 per one block forest), and selected peak is identical at frontier16.',
 added_costs='T128 nonDD/DD batch adds287834112/270139392 build multiplications plus467140608/440598528 recovery multiplications and36175872/33226752 inversions. Cached final layer lowers recovery but adds35389440/33619968 source-key reads and still30277632/27328512 inversions.',
 prerequisites='Demote this disposable schedule. Only revisit if retaining more right-child state, a differently reviewed protocol, or measured GPU access effects beat the direct service after full capacity and private costs.',
 integration_cost='Research-only Frontier.layer(d) source factory; no native patch. Actual private GKR/input-consistency/masks/CFS/PCS remain high-cost unresolved work.',
 exactness='45synthetic fixtures2..64leaves;472unmasked consumers,592layers,63controls; independent354consumers/444layers,enumerated operation graph and10prior profile counts. No saved native proof.',
 privacy_soundness='Current-attempt leaf reciprocals only; stale-cache control changes ordered source. Root-preserving permutation and absentzero/m0 controls retained. No mask/opening reuse or native RNG/refusal/order changes.',
 end_to_end_ceiling='No positive count/memory gain at matched schedule; runtime effect unmeasured. Unknown affected exclusive fraction f gives deletion ceiling1/(1-f), before additional work; no complete GPU rate inferred.',
 falsification='The proposed source-reuse saving is falsified by identical source counts plus extra arithmetic at the same selected peak. A GPU timing advantage would require a separate measured coalescing/kernel result and complete-workload validation.')
h=next(x for x in hyps if x['rank']==2)
h['prerequisites']+=' D32 precision co-design: distinguish F_P12 (cap unchanged) from a finer exp-score table S12 (owner models DD infeasible). Reproduce public-table distinct outputs before carrying DD savings to a fidelity configuration.'
hyps.append(dict(rank=23,title='NEW D32 precision versus DD capacity cliff: exact public LUT census',
 baseline='R9 DD cap32, current public exp output counts19/11/6 cited by owner. r11 cost memo says F_P9->12 costs no planes/cap, but finer S12 may raise n_col~128–384 (MODEL). No such profile built here.',
 eliminated_work='Potentially retain exact DD savings at a higher-fidelity configuration; first eliminate unsupported carryover of R9 savings, not native work.',
 added_costs='Public exp-table enumeration; for any proposed larger dictionary charge Dd domain, all limbs/lookups, transient backing, soundness terms and unchanged private composition.',
 prerequisites='Read pinned r11 public count/table definitions; distinguish F_P, f_e, e_s and score range. Follow owner native/fidelity lane and D32; no change to admitted profiles or original arithmetic.',
 integration_cost='Small CPU-only exact public LUT/cardinality and count study; integration would require owner soundness/privacy review and native implementation.',
 exactness='Require exact public table entries and worst-case cardinality including0; compare independent table enumeration/count oracle and reject overcap.',
 privacy_soundness='No private trace/table statistics, no weakening refusals/masks/PCS; D30 conditions and DD gate remain.',
 compatibility='Pinned Shape::DD_CAP/DD profile door, exp table identity and public Table definitions; owner r11 ACTVATION_COST is a count memo.',
 end_to_end_ceiling='Unknown exclusive DD fraction and actual fidelity geometry; no numeric >=50/s prediction from table counts.',
 falsification='A fidelity-relevant table exceeds32 outputs or dictionary/extra proof cost erases DD benefit; F_P-only change must not be misreported as an exp cardinality change.'))
(HERE/'hypotheses.json').write_text(json.dumps(hyps,indent=2)+'\n')
extra=[]
for rel in ['results/zk60_1b_native_20261017/r11/ACTIVATION_COST.md']:
    p=PROJECT/rel;b=p.read_bytes();extra.append(dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),scope='public source/count memo read only; no model data copied'))
(HERE/'additional-read-pins.json').write_text(json.dumps(extra,indent=2)+'\n')
print(json.dumps(dict(records=len(records),source_ledger=len(old)+len(records),hypotheses=len(hyps),queries=len(queries))))
