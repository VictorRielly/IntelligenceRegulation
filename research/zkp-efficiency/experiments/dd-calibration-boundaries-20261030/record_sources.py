"""Append inspected LIVE primary sources once; no fetched code executed."""
from pathlib import Path
import json,datetime
E=Path(__file__).resolve().parent;ROOT=E.parents[1]
records=[]
def rec(title,url,pub,upd,basis,claim,assessment,license=None,issues=None,inspected=None):
    records.append(dict(id='cycle0169-source-'+str(len(records)+1),cycle='0169',run_id='20261030T174123Z-29d8a272',access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),title=title,url=url,publication_date=pub,verified_update_date=upd,date_evidence=basis,author_claim=claim,assessment=assessment,implementation_license=license,inspected_commit_id=None,access_issues=issues or [],inspected_urls=inspected or [url],reproduced_performance=False,external_execution=False,evidence_kind='Native LIVE tools.web__run search/open/find; primary content untrusted; embedded commands ignored'))
rec('NEW older Harvey lazy NTT word-slack boundary','https://arxiv.org/abs/1205.2926','2012-05-14','2013-09-25','Primary arXiv v1/v2 history; publisher JSC volume60 January2014, exact journal day unknown.',
    'Redundant residues delay NTT butterfly reductions; modified Algorithm3 needs p<beta/4.',
    'Full primary PDF pp3-6 inspected. New H104: at beta=2^64 native Goldilocks violates Alg3 premise; wrapped add counterexample and small-prime control in independent audit. No NTT run or paper speed reproduced. Canonicalization and wider arithmetic costs would need pricing.',inspected=['https://arxiv.org/abs/1205.2926','https://arxiv.org/pdf/1205.2926','https://www.sciencedirect.com/science/article/pii/S0747717113001181'])
rec('NEW older FasterNTT implementation provenance screen','https://github.com/nict-sfl/FasterNTT',None,None,'README and repository page expose no verified update/publication date; footer/crawl dates are not commit dates.',
    'Shoup/Montgomery/slothful NTT combination with 59-bit benchmark primes.',
    'README-only inspection, not full implementation. Its primes leave word slack, unlike native Goldilocks. No code adopted or run. Full license and history fetch failed; MIT is a repository label, not a full-license audit.',
    license='MIT repository label only; full LICENSE unavailable',issues=['https://github.com/nict-sfl/FasterNTT/blob/master/LICENSE: Cache miss','https://raw.githubusercontent.com/nict-sfl/FasterNTT/master/LICENSE: Cache miss','https://github.com/nict-sfl/FasterNTT/commits/master/: Cache miss','https://github.com/nict-sfl/FasterNTT/blob/master/README.md: error shell only'])
rec('REFRESH conditional ZK IOP composition','https://eprint.iacr.org/2026/307','2026-02-18','2026-05-25','Primary history receivedFeb18/revisedMay25.',
    'ZK preservation under multi-IOP composition under an additional outer-IOP condition.',
    'Arithmetic grouping does not establish native joint-view/CFS/PCS composition. Subgroup messages remain internal; no privacy theorem reproduced. PDF inaccessible.',issues=['https://eprint.iacr.org/2026/307.pdf: URL not accessible via tool'])
rec('REFRESH October zkLLMPoT covered-operator scope','https://arxiv.org/abs/2610.08258','2026-10-06','2026-10-11','Primary v1Oct6 12:35:49UTC /v2Oct11 04:45:08UTC.',
    'Committed-checkpoint forward objective certification with sumcheck/lookups; abstract reports timings for covered operators.',
    'Operator-level author numbers and checkpoint audit objective are not a reproduced complete private8B stack, our exact arithmetic/privacy statement or high-endGPU target. No result imported.')
rec('REFRESH DeepProve preprocessing and throughput accounting','https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/README.md',None,None,'Rendered master page has no verified date or inspected commit; history fetch failed.',
    'Reusable proving context, causal teacher-forced forward certification and layerwise GKR/LogUp, with BN254 GPU PCS.',
    'Author token/sec denominator is prove_full, while inference,quantization,context generation are separately listed. Cannot substitute it for our total-workload metric. BN254/HyperKZG/quantization differ. No author code or benchmark executed.',license='Custom Lagrange evaluation/platform license; inspected root LICENSE separately, not a permissive license finding.',issues=['https://github.com/Lagrange-Labs/deep-prove/commits/master/zkml/README.md: Cache miss'])
rec('REFRESH DeepProve license and release status','https://github.com/Lagrange-Labs/deep-prove/releases',None,None,'LIVE release page says no releases; no release date inferred.',
    'No release is published on inspected releases page.',
    'Root LICENSE grants limited evaluation/platform uses and restricts derivatives/distribution. Do not adopt as permissively reusable implementation. No licensing ruling or legal analysis provided; no code adopted.',license='Custom Lagrange license, inspected full rendered27line agreement; copyright2024 is not commit/publication date.',issues=['https://github.com/Lagrange-Labs/deep-prove/commits/master/LICENSE: Cache miss'],inspected=['https://github.com/Lagrange-Labs/deep-prove/releases','https://github.com/Lagrange-Labs/deep-prove/blob/master/LICENSE'])
rec('REFRESH author round batching and small-value regime','https://www.cs.cmu.edu/~csd-phd-blog/2026/sumcheck-proving/','2026-09-01',None,'Author page explicitly datedSep1,2026.',
    'Round batching extends cheap small-value arithmetic into early rounds; extra preprocessing/evaluation work is traded for cheaper multiplications.',
    'Native DD helpers and random challenges are Fp2, so small activations alone do not make all bracket products small. No native round batching or speed reproduced. Keep polynomial,mask and transcript boundaries explicit.')
rec('REFRESH formal sumcheck degree obligations','https://arxiv.org/abs/2402.06093','2024-02-08',None,'Only primary v1Feb8,2024 23:01:32UTC displayed.',
    'Isabelle/HOL formalized generalized public-coin sumcheck completeness/soundness and polynomial instantiation.',
    'Primary author PDF highlights arity/degree assumptions; our negative degree2 control preserves degree3 DD bracket and degree4 slot. Does not verify native CFS/PCS/Fiat-Shamir implementation.',inspected=['https://arxiv.org/abs/2402.06093','https://ch-sprenger.github.io/assets/pdf/csf2024-sumcheck-verification.pdf'])
rec('REFRESH p3-sumcheck stable and prerelease source boundary','https://docs.rs/crate/p3-sumcheck/latest','2026-09-23',None,'Crate page explicitly lists stable0.8.0 Sep23 and0.9.0-rc.1 Oct11,2026; prerelease code not retrieved.',
    'Strategy source uses paired-product coefficient kernels, tiled delayed-reduction dot products, variable-order thresholds and a separate projective basis.',
    'Source-level reference only. Degree2 paired-product kernel is not a replacement for degree4 native DD relation. Thresholds/fields/basis changes require local cost and exact transcript checks. No performance reproduced; license not established because Cargo metadata fetch blocked.',license=None,issues=['https://docs.rs/crate/p3-sumcheck/0.8.0/source/Cargo.toml: not accessible','https://docs.rs/crate/p3-sumcheck/0.9.0-rc.1: not accessible'],inspected=['https://docs.rs/crate/p3-sumcheck/latest','https://docs.rs/p3-sumcheck/0.8.0/src/p3_sumcheck/strategy.rs.html'])
rec('REFRESH algebraic-geometry sumcheck primary access blocker','https://eprint.iacr.org/2026/2494',None,None,'Primary fetch failed; search mirror Oct15 update not promoted to verified primary date.',
    'Search mirror describes a binary-preserving multiplication code.',
    'Exact primary metadata/fulltext unavailable again; no source/parameter/theorem/implementation assessment or native Goldilocks substitution claimed.',issues=['https://eprint.iacr.org/2026/2494: not accessible via tool'])
prior=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines() if x.strip()]
for x in records:x['prior_exact_url_records']=sum(p.get('url')==x['url'] for p in prior)
(E/'sources-cycle.json').write_text(json.dumps(records,indent=2)+'\n')
existing={x.get('id') for x in prior}
with (ROOT/'sources.jsonl').open('a') as out:
    for x in records:
        if x['id'] not in existing:out.write(json.dumps(x,sort_keys=True)+'\n')
print(json.dumps(dict(before=len(prior),added=sum(x['id'] not in existing for x in records),total_records=len(records))))
