"""Append inspected LIVE primary records with explicit uncertainty and blockers."""
import datetime,json,os,resource
from pathlib import Path
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59))
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RUN='20261019T231854Z-28e6b36b'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
common=dict(access_date='2026-10-19',access_timezone='UTC',recorded_at_utc=now,
 cycle='0091',run_id=RUN,evidence_kind='Native LIVE web search/open/find/click; primary sources; no foreign code executed',
 external_execution=False,reproduced_performance=False,implementation_license=None,inspected_commit_id=None,
 published=None,updated=None)
rows=[
dict(title='Rust GlobalAlloc: observed allocations are not a language guarantee',
 url='https://doc.rust-lang.org/std/alloc/trait.GlobalAlloc.html',
 date_evidence='Official current documentation displays std1.99.1,compiler58cf8f9c3 dated2026-10-13; this is a version marker,not the page update date. Local experiment uses installed1.90.0.',
 assessment='Compiler may elide or merge allocations; allocator-side counters do not force them. Local opt0/3 observations establish only those binaries. Avoid recursive allocation or unwind in hooks; fixed atomic log used. No soundness proof relies on allocation counts.'),
dict(title='Rust System allocator: requested allocation accounting wrapper',
 url='https://doc.rust-lang.org/std/alloc/struct.System.html',
 date_evidence='Undated official documentation; current version marker1.99.1/2026-10-13 is not a verified page publication/update date.',
 assessment='System delegates to platform allocator and permits tracking wrappers. Requested Layout bytes are not malloc usable size,RSS or GPU residency. Authored local wrapper forwards untouched Layouts; no library code installed or fetched.'),
dict(title='Chimera October16 revision: resident sumcheck versus complete proving gains',
 url='https://eprint.iacr.org/2026/1388',published='2026-07-07',updated='2026-10-16',
 date_evidence='Primary history:receivedJul7,revisedOct16,2026.',paper_license='CC BY primary metadata,not implementation license',
 author_claim='Keeps profitable sumcheck rounds resident,transfers compact transcript values,switches small tails to CPU and chunks oversized tables. Complete BN254 Spartan gains are smaller than sumcheck-region gains.',
 assessment='Retains owner whole-prover GPU/resident workload priority. Neither Goldilocks/Fp2 native compatibility nor full private8B performance/privacy is reproduced; no factor applied to target.'),
dict(title='NEW older source: Huerta2025 GPU register-file cache and dependency scheduling',
 url='https://arxiv.org/abs/2503.20481',published='2025-03-26',
 inspected_urls=['https://arxiv.org/html/2503.20481v1'],
 date_evidence='Primary arXiv v1 Mar26,2025 12:10:53UTC;no later revision displayed.',paper_license='HTML CC BY4.0 label,not implementation license',
 author_claim='Reverse-engineers Ampere issue behavior,banked register-file/cache and software dependency control;uses RTX A6000 and discusses Turing portability.',
 assessment='Previously absent from507-record ledger and findings keyword census. New older technique lead: after spill reduction,source-order/register-operand reuse may affect issue stalls independently of occupancy. Abstract versus HTML give different simulator-error numbers; none is imported. Needs owner SASS/stall counters on actual supported hardware;no5090 portability or speed factor assumed. No implementation inspected.'),
dict(title='GPU-NTT older layout algorithms and current public implementation interface',
 url='https://eprint.iacr.org/2023/1410',published='2023-09-19',updated='2023-10-06',
 inspected_urls=['https://github.com/Alisah-Ozcan/GPU-NTT','https://github.com/Alisah-Ozcan/GPU-NTT/blob/main/LICENSE','https://github.com/Alisah-Ozcan/GPU-NTT/commits/main/'],
 date_evidence='ePrint receivedSep19/revisedOct6,2023. Repository history includesFeb4,2026 bug fix,but no current latest-update date inferred.2025 journal date is separate.',
 implementation_license='Apache-2.0 root LICENSE text inspected on current main;unpinned,not a backend/transitive license audit',
 author_claim='Merge and four-step NTT improve locality/global-memory traffic;current README says32/64-bit Barrett arithmetic,paper_version retains older manual reduction choice.',
 assessment='Known source refreshed. Native NTT already caches stage-major twiddles and uses split kernels;do not count those as new work. Generic Barrett transform is not an automatically exact Goldilocks hiding encoder replacement. No source commit diff or kernels inspected/executed.',
 access_issues=['https://research.sabanciuniv.edu/id/eprint/51889/1/High-Performance.pdf:400 Timeout fetching']),
dict(title='GoldilocksNTT L2-cache qualification refresh',url='https://github.com/yrrid/GoldilocksNTT',
 date_evidence='Undated README;repository publication/update date unavailable. Search crawl recency is not a release date.',
 license_claim='MIT repository badge only;actual LICENSE fetch failed,so implementation_license remains null',
 author_claim='Uses four signed32-bit limbs for1024-point Goldilocks NTT;reported RTX4070Ti cached batch throughput exceeds sustainable global-memory rate;97KB shared-memory requirement described.',
 assessment='Repeated local/preloaded batches do not predict full-stack residency or steady proved rates. New local scope result is requested host allocation only,not a GPU NTT speedup. No code/commit inspected or executed.',
 access_issues=['https://github.com/yrrid/GoldilocksNTT/commits/main/:Internal Error','https://github.com/yrrid/GoldilocksNTT/commits:Internal Error','https://github.com/yrrid/GoldilocksNTT/blob/main/LICENSE:Internal Error','https://github.com/yrrid/GoldilocksNTT/raw/refs/heads/main/LICENSE:Internal Error']),
dict(title='recmo Goldilocks NTT/PCS license refresh',url='https://github.com/recmo/goldilocks',
 inspected_urls=['https://github.com/recmo/goldilocks/blob/main/mit-license.md'],
 date_evidence='README/license unpinned and undated;copyright2022 is not publication/update date.',
 implementation_license='MIT root mit-license.md text inspected;no transitive dependency/backend audit',
 assessment='Goldilocks field match is useful for future exact transform reference work;does not establish matching native coset,pad,transcript,commitment conventions or performance. No code/commit inspected/executed.',
 access_issues=['https://github.com/recmo/goldilocks/commits/main/:Internal Error']),
dict(title='Plonky3 mask RNG boundary and inconsistent cached release views',url='https://github.com/Plonky3/Plonky3/pull/2260',
 published='2026-09-20',updated='2026-09-20',
 inspected_urls=['https://github.com/Plonky3/Plonky3/releases'],
 date_evidence='PR opened/mergedSep20,2026 visible on primary conversation. Release listing servedSep23 v0.8.0 view despite priorOct16rc2 records;cannot establish current latest release.',
 author_claim='Require CryptoRng at HVZK mask sampling entry points;replaying a predictable seed can expose underlying round coefficients. Reported upstream tests not rerun.',
 assessment='Public storage reuse never permits private mask-stream reuse or a weaker sampler. No native change authorized,PR commit pages not inspected. Preserve prior source/date records instead of overwriting them with inconsistent release-cache output.',
 access_issues=['https://github.com/Plonky3/Plonky3/pull/2038:Internal Error/Cache miss','https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.8.0:Internal Error/Cache miss','https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.2:Internal Error/Cache miss']),
dict(title='NEW older source screen: memory versus arithmetic in FPGA twiddle generation',
 url='https://www.mdpi.com/2079-9292/13/16/3128',published='2024-08-07',
 date_evidence='Publisher primary LIVE search result explicitly7Aug2024,Electronics13(16),3128,doi10.3390/electronics13163128;full page/notes/PDF unavailable. No update date inferred.',
 evidence_scope='Publisher search-result metadata/abstract only;full text blocked',
 author_claim='Compares half-memory,on-the-fly serial and parallel twiddle-factor generators on KCU105 FPGA for FHE.',
 assessment='Previously absent source screened. Memory saved can cost modular arithmetic,so NTT table storage reduction is not automatically throughput improvement. Hardware-generator throughput/area is not transferable to RTX5090 software. No implementation inspected or license inferred.',
 access_issues=['https://www.mdpi.com/2079-9292/13/16/3128:Internal Error','https://www.mdpi.com/2079-9292/13/16/3128/notes:Internal Error','https://cas.cnu.ac.kr/wp-data/international_journal/%5B2024%5D%20Efficient%20Twiddle%20Factor%20Generators%20for%20NTT.pdf:Internal Error']),
dict(title='ZKProphet GPU bottleneck scope refresh',url='https://arxiv.org/abs/2509.22684',published='2025-09-17',
 date_evidence='Primary arXiv v1 Sep17,2025 22:52:19UTC;no later version displayed.',
 author_claim='For studied MSM-accelerated proof systems,NTT and32-bit integer-pipeline dependencies can dominate;precomputation/representations affect runtime tuning.',
 assessment='Known source refreshed. Its up-to90% NTT share is not the measured native private8B phase share. Need actual exclusive commitment/NTT/hash/device clocks before optimizing a kernel or claiming50proved positions/s. No code/commit/license inspected.')]
records=[dict(common,**x) for x in rows]
(HERE/'source-records.json').write_text(json.dumps(records,indent=2)+'\n')
p=ROOT/'sources.jsonl'
old=[json.loads(s) for s in p.read_text().splitlines() if s.strip()]
assert len(old)==507 and not any(x.get('run_id')==RUN for x in old),'append once only'
with p.open('a') as f:
 for row in records:f.write(json.dumps(row,sort_keys=True)+'\n')
(HERE/'source-append.json').write_text(json.dumps(dict(before=len(old),appended=len(records),after=len(old)+len(records)),indent=2)+'\n')
print(json.dumps(dict(before=len(old),appended=len(records),after=len(old)+len(records))))
