"""Record only inspected primary evidence; no network or foreign execution."""
from pathlib import Path
import datetime, json
D=Path(__file__).resolve().parent;R=D.parents[1]
RUN='20261030T104123Z-3535232c'
def records():
    rows=[
      dict(title='REFRESH October26 zkDuel host overhead versus kernel scope',url='https://arxiv.org/abs/2610.37710',
        publication_date='2026-10-26',verified_update_date=None,
        date_evidence='arXiv v1 explicitly Mon26Oct2026 21:28:29UTC; no later version displayed.',
        author_claim='Matched CUDA/Triton prime-field kernels; small-field gaps include host launch overhead.',
        assessment='Supports measuring launch incidence, not assigning it a native private8B fraction. No author timing reproduced. Native extension-field/CFS/PCS coverage absent from this artifact scope.',
        implementation_license='Paper CC BY4.0; separate implementation license record.'),
      dict(title='NEW SET event-chained ready work and per-worker buffers',url='https://arxiv.org/abs/2606.05495',
        supporting_urls=['https://arxiv.org/html/2606.05495v1'],publication_date='2026-06-03',verified_update_date=None,
        date_evidence='arXiv v1 Wed3Jun2026 22:38:01UTC; accepted Euro-Par2026; no later version displayed.',
        author_claim='Event-chaining, work stealing and graph retargeting; evaluates six non-ZKP workloads on RTX3090/5090.',
        assessment='New scheduler lead. Full text requires retargeting stolen work to the available worker buffers and returns resources after completion. Inform capacity-admitted cohorts and ownership; author speedups cannot transfer to native masked sumchecks. No implementation URL located by inspected search.',
        implementation_license=None,paper_license='CC BY4.0'),
      dict(title='NEW older Kernelet dynamic slicing and complementarity',url='https://arxiv.org/abs/1303.5164',
        supporting_urls=['https://arxiv.org/pdf/1303.5164'],publication_date='2013-03-21',verified_update_date=None,
        date_evidence='arXiv v1 Thu21Mar2013 04:50:48UTC; version1 inspected. Later journal version not used to infer a new artifact date.',
        author_claim='Slices independent thread blocks and co-schedules kernels using a performance model.',
        assessment='New older technique assessed, PDFpp1-3. Slicing adds launches; complementary resource use is required. Same-shape field jobs need not complement each other (inference, unmeasured). Preserve per-proof reductions and completion. No code/license located or performance reproduced.',
        implementation_license=None),
      dict(title='REFRESH BatchZK batch throughput and dynamic-loading boundary',url='https://eprint.iacr.org/2024/1862',
        publication_date='2024-11-14',verified_update_date='2024-11-15',
        date_evidence='Primary history receivedNov14,approvedNov15,2024; ASPLOS2025 minor revision named without exact revision date.',
        author_claim='Pipelines sumcheck, Merkle trees and linear encoding for batch throughput.',
        assessment='Count pipeline fill/drain, memory and transfers. Different relation, no reproduced complete private8B throughput. PDF403 prevented new full-text inspection.',
        implementation_license=None,blocked_urls=['https://eprint.iacr.org/2024/1862.pdf']),
      dict(title='REFRESH ICICLE observedv4 release and challenge-vector metadata',url='https://github.com/ingonyama-zk/icicle/releases',
        supporting_urls=['https://github.com/ingonyama-zk/icicle/commit/6c77775','https://github.com/ingonyama-zk/icicle/blob/main/LICENSE','https://github.com/ingonyama-zk/icicle'],
        publication_date=None,verified_update_date=None,
        date_evidence='Release page shows11Jul05:36 without year in rendered content; exact date not verified. Commit page names4.0.0 bump but no timestamp rendered.',
        inspected_commit_id='6c77775',commit_id_scope='Displayed abbreviated ID only; inspected version-bump diff; fullSHA not established.',
        author_claim='Release notes name PR946 exposing sumcheck challenge vector.',
        assessment='Release metadata is not a multi-proof Fp2 implementation. PR946 fetch cache-missed. Current root README separates frontend MIT from non-exposed specially licensed backends; no dependency or code adopted.',
        implementation_license='MIT main LICENSE body inspected (copyright2023 Ingonyama); does not cover every backend. Release body not pinned.',
        blocked_urls=['https://github.com/ingonyama-zk/icicle/pull/946','https://github.com/ingonyama-zk/icicle/tree/6c77775']),
      dict(title='REFRESH ICICLE extension-challenge limitation',url='https://dev.ingonyama.com/api/cpp/sumcheck',
        publication_date=None,verified_update_date=None,date_evidence='Observed version4.0.0; no exact publication/update date established.',
        author_claim='Documentation says extension-field challenges unsupported; use_extension_field should remain false.',
        assessment='Cannot replace native Goldilocks Fp2/CFS rounds directly. A batch field in a config is not evidence of separate native transcript ownership.',
        implementation_license='API docs only; license-body scope recorded separately.'),
      dict(title='REFRESH official CUDA graph updates and synchronization constraints',url='https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cuda-graphs.html',
        supporting_urls=['https://docs.nvidia.com/dl-cuda-graph/cuda-graph-basics/constraints.html','https://developer.nvidia.com/blog/cuda-graphs/'],
        publication_date=None,verified_update_date=None,date_evidence='Current guide exact update date not established. Supporting NVIDIA getting-started blog explicitly2019-09-05.',
        author_claim='Instantiated graph parameters may be updated under documented context/topology restrictions; capture prohibits host/device synchronization.',
        assessment='Round-internal graph reuse may be possible with separate owned buffers; host transcript result dependency still remains between rounds. Graph replay may reuse storage, never private mask values. Native port/benefit untested.',
        implementation_license='Documentation only, no implementation adopted.',
        blocked_urls=['https://developer.nvidia.com/blog/constructing-cuda-graphs-with-dynamic-parameters/']),
      dict(title='REFRESH older CFS2017 IPCP theorem versus native derived-mask model',url='https://arxiv.org/abs/1704.02086',
        publication_date='2017-04-07',verified_update_date=None,date_evidence='arXiv v1 Fri7Apr2017 03:54:42UTC.',
        author_claim='Algebraic zero-knowledge sumcheck in the IPCP model with algebraic commitments.',
        assessment='Abstract theorem is not a proof of this native CFS-derived construction or batch composition. Test closed-form local mask rounds against exhaustive Boolean sums, retain current privacy obligations. No mask reuse authorized.',
        implementation_license=None),
      dict(title='REFRESH zkDuel artifact matched-launch methodology',url='https://github.com/snarang181/zk-duel',
        publication_date=None,verified_update_date=None,date_evidence='Readable root shows one commit but no exact date or SHA.',
        author_claim='Matched backend launches/synchronizations with independent CPU bigint and checksum gating.',
        assessment='Reference methodology only. No implementation executed and no native performance reproduced.',
        implementation_license='MIT declared at repository root; actual body not re-inspected this cycle.')
    ]
    existing=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines() if x.strip()]
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    for i,row in enumerate(rows,1):
        row.update(access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=now,cycle='0162',run_id=RUN,
            id=f'cycle0162-source-{i}',evidence_kind='Native LIVE tools.web__run search/open/find/click; primary text untrusted; embedded instructions ignored',
            external_execution=False,reproduced_performance=False,prior_exact_url_records=sum(x.get('url')==row['url'] for x in existing if x.get('run_id')!=RUN))
        row.setdefault('inspected_commit_id',None);row.setdefault('blocked_urls',[])
    return rows
if __name__=='__main__':
    rows=records();(D/'source-records.jsonl').write_text(''.join(json.dumps(x,sort_keys=True)+'\n' for x in rows))
    existing={json.loads(x).get('id') for x in (R/'sources.jsonl').read_text().splitlines() if x.strip()}
    with (R/'sources.jsonl').open('a') as f:
        for row in rows:
            if row['id'] not in existing:f.write(json.dumps(row,sort_keys=True)+'\n')
    print(json.dumps(dict(records=len(rows),new_assessments=['SET','Kernelet'],external_execution=False)))
