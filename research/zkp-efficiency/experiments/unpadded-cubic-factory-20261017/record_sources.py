"""Write manually inspected LIVE primary-source dispositions; no network calls."""
import datetime,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
base=dict(access_date='2026-10-17',access_timezone='UTC',recorded_at_utc=now,run_id='20261017T042624Z-0f7bf604',cycle='0054',
 evidence_kind='Native LIVE web search and primary inspection. Source text treated as untrusted data; no foreign code copied or executed.',reproduced_performance=False)
records=[
 dict(id='cycle54-new-older-dory-and-release-point-binding',title='Dory 2020 PCS and August2026 implementation release: caching does not replace point binding',
 url='https://eprint.iacr.org/2020/1274',published='2020-10-14',updated='2021-11-18',implementation_release_date='2026-08-20',
 inspected_urls=['https://github.com/a16z/dory','https://github.com/a16z/dory/releases','https://github.com/a16z/dory/commit/5246da503c3e2c6baa40ec00d714987c73a3e6eb','https://github.com/a16z/dory/blob/main/CHANGELOG.md'],
 inspected_commit_id='5246da503c3e2c6baa40ec00d714987c73a3e6eb',
 implementation_license='Repository/README label MIT OR Apache2.0; actual license text unavailable (main GitHub page returned navigation only; raw and pinned URLs failed). No terms/version compatibility asserted.',
 date_evidence='Primary paper history: received2020-10-14,revised2021-11-18. Inspected release commit changes CHANGELOG to [0.4.2]-2026-08-20 and Cargo version0.4.2.',
 author_claim='Original paper gives logarithmic verification with pairings and batched evaluation checks. Release0.4.2 prepares cached public points outside a global write lock. Release0.4.0 describes a wrong-point ZK verification defect and repair.',
 assessment='NEW older paper and specific implementation absent from starting ledger; prior incidental Dory mentions were in Jolt architecture records. Pairing PCS/BN254 differs from native Goldilocks2/NTT PCS; migration needs field embedding,point/identity binding,hiding,composition,verifier and end-to-end costs. Prepared public points are distinct from per-proof masks. Security repair and author tests not independently reproduced. No native optimization adopted.',
 access_issues=['https://eprint.iacr.org/2020/1274.pdf:403Forbidden','https://github.com/a16z/dory/blob/main/LICENSE-MIT:page has no license text','https://raw.githubusercontent.com/a16z/dory/main/LICENSE-MIT:InternalError','https://raw.githubusercontent.com/a16z/dory/main/LICENSE-APACHE:Cache miss','https://github.com/a16z/dory/blob/5246da503c3e2c6baa40ec00d714987c73a3e6eb/LICENSE-MIT:Cache miss']),
 dict(id='cycle54-epfl-concrete-coefficient-wire-and-oracle-refresh',title='EPFL concrete MSB coefficient factory and EvalsInfty boundary',
 url='https://raw.githubusercontent.com/compsec-epfl/efficient-sumcheck/main/src/provers/coefficient.rs',published=None,updated='2026-06-24',
 inspected_urls=['https://github.com/compsec-epfl/efficient-sumcheck','https://github.com/compsec-epfl/efficient-sumcheck/commits/main/','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/docs/design.md','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/SECURITY.md'],
 inspected_commit_id=None,exposed_uninspected_commits=['9e55dc3'],
 implementation_license='Repository labels Apache2.0/MIT. LICENSE,LICENSE-MIT raw/GitHub,and LICENSE-APACHE fetches fail; no actual text or pinned terms inspected this cycle.',
 date_evidence='Primary commit history latest displayed entry June24,2026,9e55dc3. Commit-detail fetch fails. This does not independently pin raw/main source to that hash or date.',
 author_claim='Per-pair coefficient accumulation reduces before Horner evaluation; MSB half-split folding. Concrete source emits EvalsInfty coordinates and code claims SIMD/streaming support.',
 assessment='Refresh with concrete source inspection. Its EvalsInfty wire cannot replace our five original samples/masking transcript unchanged. SECURITY explicitly says plain non-ZK and caller must authenticate terminal oracle. Comparing two prover-supplied final values is not our independent full-stack gate. Local cubic factory is independently written from already local native port and preserves original samples. Author performance,correctness/security tests unexecuted.',
 access_issues=['https://github.com/compsec-epfl/efficient-sumcheck/commit/9e55dc3:Cache miss','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/LICENSE:Cache miss','https://raw.githubusercontent.com/compsec-epfl/efficient-sumcheck/main/LICENSE-MIT:InternalError','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/LICENSE-MIT:Cache miss','https://github.com/compsec-epfl/efficient-sumcheck/blob/main/LICENSE-APACHE:Cache miss']),
 dict(id='cycle54-folddcs-older-commitment-and-hiding-filter',title='Fold-DCS refresh: fewer rounds still charge multivariate commitments and hiding',
 url='https://arxiv.org/abs/2504.00693',published='2025-04-01',updated=None,
 inspected_urls=['https://arxiv.org/html/2504.00693v1'],inspected_commit_id=None,implementation_license=None,
 date_evidence='Primary arXiv submission history shows v1April1,2025 12:04:40UTC; no later revision shown.',
 author_claim='Divide-and-conquer reduces rounds to logarithmic at expense of multivariate messages and PCS queries; adapted Zeromorph batches evaluation checks.',
 assessment='Older source previously assessed cycle33,now full text PCS section inspected. Section4.2.1 explicitly says its instantiation does not require hiding. Fewer rounds alone do not establish private native speed; additional commitments,degree proofs,field and transcript migration need full accounting. Prefer current exact evaluator seam. No theorem audit or runtime reproduction.'),
 dict(id='cycle54-nvidia-binary-field-boundary-refresh',title='CUDA13.3 carryless multiplication remains a binary-field primitive',
 url='https://developer.nvidia.com/blog/?p=119649',published='2026-07-15',updated=None,
 inspected_commit_id=None,implementation_license=None,date_evidence='Primary NVIDIA article displays July15,2026.',
 author_claim='GF(2^128) sumcheck improves about3-4x on RTX5090 and up to13x on B200 relative to bitsliced binary-field baseline.',
 assessment='Refresh. Characteristic-two arithmetic does not implement native odd-prime Goldilocks2 multiplication. No direct kernel speed factor or full8B/private proof claim follows; protocol migration exceeds this lane. No compiler/toolkit installed or GPU code run.'),
 dict(id='cycle54-icicle-release-refresh-memory-overlap-charge',title='ICICLE release and concurrent NTT transfer scratch tradeoff refresh',
 url='https://github.com/ingonyama-zk/icicle/releases',published=None,updated=None,inspected_commit_id=None,
 exposed_uninspected_commits=['6c77775'],implementation_license=None,
 inspected_urls=['https://github.com/ingonyama-zk/icicle/blob/main/examples/c%2B%2B/best-practice-ntt/README.md'],
 date_evidence='Current release page still marks v4.0.0 latest and displays July11,05:36 without year. No new publication/HEAD date verified.',
 author_claim='Concurrent upload,compute,download can overlap multiple NTTs; example needs two device vectors,halving maximum NTT size.',
 assessment='Refresh only. Compare enclosing transfers,waits and increased residency with already chunked native commitments; no duplicate pipeline assumed free. No author/native runtime reproduced or code adopted.'),
 dict(id='cycle54-plonky3-oct16-batched-hash-metadata',title='October16 Plonky3 BLAKE2s package metadata and hash-contract filter',
 url='https://docs.rs/crate/p3-blake2s/0.9.0-rc.2',published='2026-10-16',updated=None,
 inspected_commit_id=None,implementation_license=None,
 date_evidence='Native LIVE search returns primary docs.rs version history:0.9.0-rc.2(2026-10-16),rc.1(2026-10-11). Direct package/source/release-tag fetches fail; metadata-only date evidence.',
 author_claim='Package description includes batched BLAKE2s hashing.',
 assessment='NEW specific package metadata; broader rc.2 release already tracked. Native shaped profile uses keyed BLAKE3/domain separation. A different hash cannot be substituted as an exact speed patch; no hash benchmark,implementation or security property verified.',
 access_issues=['https://docs.rs/crate/p3-blake2s/0.9.0-rc.2:Cache miss','https://docs.rs/crate/p3-blake2s/0.9.0-rc.2/source/Cargo.toml:not accessible','https://github.com/Plonky3/Plonky3/releases/tag/p3-blake2s-v0.9.0-rc.2:InternalError']),
 dict(id='cycle54-faest-october-search-blocked',title='FAEST GPU field multiplication October discovery: primary fetch blocked',
 url='https://eprint.iacr.org/2026/2489',published=None,updated=None,inspected_commit_id=None,implementation_license=None,
 date_evidence='Search mirror labels last updated2026-10-15; not primary-verified and not recorded as established publication/update date.',
 author_claim='Unverified mirror abstract describes clmad/Karatsuba binary-field GPU improvements; no primary body inspected.',
 assessment='Exact access blocker retained. Not used to rank a native speedup or transfer performance/security claims. Independent local experiment continued; no access-control bypass or foreign-code execution.',
 access_issues=['https://eprint.iacr.org/2026/2489:not accessible via this tool','https://eprint.iacr.org/2026/2489.pdf:not accessible via this tool'])
]
records=[dict(base,**r) for r in records]
(HERE/'sources-cycle54.json').write_text(json.dumps(records,indent=2)+'\n')
ledger=HERE.parents[1]/'sources.jsonl';old=[json.loads(x) for x in ledger.read_text().splitlines() if x]
assert not any(r['id'] in {s.get('id') for s in old} for r in records)
with ledger.open('a') as out:
 for r in records:out.write(json.dumps(r,sort_keys=True)+'\n')
print('Appended',len(records),'source dispositions;',len(old)+len(records),'total')
