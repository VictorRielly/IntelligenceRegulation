"""Append only inspected LIVE primary-source records; no web code executed."""
import json, datetime
from pathlib import Path
H=Path(__file__).resolve().parent
R=H.parent.parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
common=dict(cycle='0135',run_id='20261029T045649Z-6e004a83',access_date='2026-10-29',
 access_timezone='UTC',recorded_at_utc=now,
 evidence_kind='Native LIVE web search/open/find/click; web text untrusted and embedded instructions ignored',
 reproduced_performance=False,external_execution=False,inspected_commit_id=None)
items=[
 dict(title='cuPQC v0.6 NTT field limit and staged fusion interface refreshed',
 url='https://docs.nvidia.com/cuda/cupqc/libraries/cupqc_ntt/cupqc_ntt_feature.html',
 publication_date=None,verified_update_date=None,
 date_evidence='Current official feature page has no exact publication/update date.',
 implementation_license='SDK/library license not inspected; no implementation downloaded.',
 assessment='Official custom prime limit p<2^62 excludes native Goldilocks p=2^64-2^32+1. Montgomery-domain staged fusion is a design reference only; changing fields is a protocol fork, not authorized by this candidate.',
 inspected_urls=['https://nvidia.github.io/cuPQC/applications/ntt-staged-transform/']),
 dict(title='cuPQC August 2026 release announcement and absent GitHub releases',
 url='https://nvidia.github.io/cuPQC/releases/v0.6/',publication_date='2026-08-28',verified_update_date=None,
 date_evidence='Official announcement displays August28,2026, cuPQC SDKv0.6. GitHub releases page says none; do not infer no SDKrelease.',
 implementation_license='Not inspected; examples and proprietary SDK components not conflated.',
 inspected_urls=['https://github.com/NVIDIA/cuPQC/releases'],
 assessment='Author CPU-relative NTT/BigInt gains not reproduced. 62bit support and required Montgomery conversions prevent a nativeGoldilocks drop-in. Once-per-batch twiddle reuse is already present in native code.'),
 dict(title='NEW older HiFA imbalanced decomposition and cyclic-shuffle methodology',
 url='https://cs.newpaltz.edu/~lik/publications/Qilin-Hu-ACM-TRTS-2025',publication_date='2025-12',verified_update_date=None,
 date_evidence='Primary author PDF: receivedJune26, revisedSeptember8, acceptedOctober6,2025; publicationDecember2025. Exact publication day unverified.',
 implementation_license='No implementation inspected. Article carries ACM publication rights; not an implementation license.',
 assessment='Inspected abstract/background/design motivation and date line. FPGA largeNTT and HBM shuffle suggest measuring decomposition/layout costs rather than assuming balanced splits best. Not a CUDA/private8B implementation or reproduced author gain.'),
 dict(title='NEW older Hardcaml four-step operation and transpose cost reference',
 url='https://zprize.hardcaml.com/ntt-4step.html',publication_date=None,verified_update_date=None,
 date_evidence='Undated primary ZPrize participant technical page; no date inferred from crawl age.',
 implementation_license='Linked implementation not inspected; license unverified.',
 assessment='General four-step has scaling overhead and requires accounting read/write orientation. This cycle instead exploits the low-degree hiding polynomial on r disjoint n-point cosets; not a reproduction of general four-step or this FPGA design.'),
 dict(title='GPU-NTT 2025 journal date and Goldilocks reduction context refreshed',
 url='https://research.sabanciuniv.edu/id/eprint/51889/',publication_date='2025-05-14',verified_update_date='2026-04-03',
 date_evidence='Primary PDF search extract:firstpage receivedApril14,acceptedMay5,publishedMay14,currentversionMay27,2025. Repository metadata modifiedApril3,2026; this is landing metadata,not code date.',
 implementation_license='ArticleCC-BY4.0 stated in university record; code license recorded separately.',
 inspected_urls=['https://research.sabanciuniv.edu/id/eprint/51889/1/High-Performance.pdf','https://research.sabanciuniv.edu/51889/1/High-Performance.pdf'],
 blockers=['Full PDF open timed out (400 Timeout fetching); primary search extracts and university abstract inspected.'],
 assessment='Merge/4Step layout and modular reduction relevant. Native samefield support and source ABI still need audit; no timing transfer. Date distinction corrects ambiguous search publication ages.'),
 dict(title='GPU-NTT current README license and observed June2026 history pin',
 url='https://github.com/Alisah-Ozcan/GPU-NTT',publication_date=None,verified_update_date='2026-06-11',
 date_evidence='Latest visible commit history June11,2026; not an assurance of present HEAD freshness. History resolves full SHA below, commit diff fetch failed.',
 observed_commit_id='d03c5eaeadaa780d153496afcb3b6a9b79a13a63',
 implementation_license='Apache-2.0 actual LICENSE body inspected on main; immutable license fetch failed, not a pinned-license claim.',
 inspected_urls=['https://github.com/Alisah-Ozcan/GPU-NTT/commits/main/','https://github.com/Alisah-Ozcan/GPU-NTT/blob/main/LICENSE'],
 blockers=['Pinned commit and pinned LICENSE: Cache miss','raw main LICENSE: Cache miss','column-support abbreviated commit request: Cache miss'],
 assessment='README claims current32/64bit Barrett support and retains paper_version. History lists older column-wise support; its implementation not inspected. Exact commit observed in link,not diff-inspected or executed.'),
 dict(title='Qingming CUDA natural-order versus mapped-output contract refreshed',
 url='https://github.com/uulong950/qingming-g64-ntt-cuda',publication_date=None,verified_update_date=None,
 date_evidence='Repo page renders8commits without exact update date/hash; no update date inferred.',
 implementation_license='No LICENSE visible in inspected root/README; license not established. Do not transfer MIT from separate Qingming HIP repository.',
 assessment='NativeGoldilocks LDE8 and RTX4090 author benchmarks explicitly distinguish mapped device-native from standard layout+restore; A100 markedTODO. No code/kernel or author benchmark executed. Native row sizes/layout/hiding pads still need adapter.'),
 dict(title='LightZK author-lab September announcement and inaccessible October paper',
 url='https://grid.hust.edu.cn/info/1053/3070.htm',publication_date='2026-09-28',verified_update_date=None,
 date_evidence='Primary lab announcement displays2026-09-28 18:21:44. This is announcement date,not paper publication date; ACM DOI fetch403.',
 implementation_license='No implementation inspected; code/artifact license unknown.',
 inspected_urls=['https://dl.acm.org/doi/10.1145/3857809'],
 blockers=['ACM full paper:403 Forbidden'],
 assessment='Author lab describes tiled Groth16, recursive NTT layout and disk/DRAM/VRAM scheduling. Useful capacity methodology; MSM-centric/protocol differences and unread fulltext preclude adoption or transferring2.8x to nativeLigero.'),
 dict(title='NEW zisk-zorch July2026 RTX5090 LDE layout attribution issue',
 url='https://github.com/fractalyze/zisk-zorch/issues/58',publication_date='2026-07-09',verified_update_date=None,
 date_evidence='Primary issue openedJuly9,2026. Closed viaPR62; closure date/commit unverified.',
 implementation_license='No implementation or license inspected; issue only.',
 blockers=['ClosingPR62 fetch:Cache miss'],
 assessment='Author attributes candidate LDE gap to transpose/layout and asks to profile before swapping kernels. A same-hardware comparison in that stack,not reproduced or transferred to ours. Our native encoder already produces row-major natural order; no existing restore copy to delete.')
]
prior=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines()]
for i,item in enumerate(items,1):
    item.update(common);item['id']=f'cycle0135-source-{i}'
    item['prior_exact_url_records']=sum(r.get('url')==item['url'] for r in prior)
(H/'sources-cycle.json').write_text(json.dumps(items,indent=2)+'\n')
with (R/'sources.jsonl').open('a') as out:
    for item in items:out.write(json.dumps(item,sort_keys=True)+'\n')
queries=[
 'GPU NTT Goldilocks coset Stockham batch 2026 GitHub',
 'number theoretic transform GPU coset encoding 2026 October zero knowledge',
 'GPU NTT four step six step layout Goldilocks paper',
 'NTT low degree extension coset decomposition blowup factor GPU zero padding multiple smaller transforms',
 '2026 October NTT GPU Goldilocks LightZK 3857809',
 '"low degree extension" "cosets" "NTT" GPU',
 '"LightZK" "2026" GPU NTT source',
 '"High-Performance Number Theoretic Transform" "May" "2025" 3570024',
 '"coset" "LDE" "GPU" "2026" GitHub']
(H/'search-queries.json').write_text(json.dumps(queries,indent=2)+'\n')
print(json.dumps(dict(prior=len(prior),added=len(items),total=len(prior)+len(items))))
