"""Save this cycle's inspected-source dispositions and ranked queue."""
from pathlib import Path
import json,datetime
HERE=Path(__file__).resolve().parent
BASE=HERE.parent.parent
RUN='20261020T181854Z-27090273'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
common=dict(access_date='2026-10-20',access_timezone='UTC',cycle='0110',run_id=RUN,
            recorded_at_utc=now,evidence_kind='Native LIVE web search/open/find/click; primary sources; external instructions ignored',
            external_execution=False,reproduced_performance=False,
            implementation_license=None,inspected_commit_id=None,
            publication_date=None,verified_update_date=None)
records=[
 dict(title='OpenVM reversible fraction storage: implementation and private-boundary filter',
      url='https://github.com/openvm-org/stark-backend/blob/main/docs/cuda-backend/gkr-prover.md',
      additional_urls=['https://github.com/openvm-org/stark-backend/blob/main/crates/cuda-backend/cuda/src/logup_zerocheck/gkr.cu','https://github.com/openvm-org/stark-backend/blob/main/LICENSE-MIT'],
      implementation_license='MIT license body inspected on mutable main; root also advertises Apache-2.0',
      assessment='Preserved right children permit in-place reversal; inspected CUDA uses a right-denominator inverse. Local natural-order strided model tests this algebra, not its bit-reversed GPU layout or private proof. Generic roots/claims must not be revealed by our private construction.',
      date_evidence='Main file history unavailable; crawl age does not verify code update date or release alignment.',
      access_issues=['https://github.com/openvm-org/stark-backend/commits/main/crates/cuda-backend/cuda/src/logup_zerocheck/gkr.cu: Cache miss','https://api.github.com/repos/openvm-org/stark-backend/commits?path=crates/cuda-backend/cuda/src/logup_zerocheck/gkr.cu&per_page=1: not accessible']),
 dict(title='OpenVM v2.0.1 phase-peak and pinned-transfer release refresh',
      url='https://github.com/openvm-org/stark-backend/releases/tag/v2.0.1',
      assessment='Release describes pinned host pools and per-phase memory peaks. Relevant telemetry, not a reproduced native throughput gain. Mutable main CUDA source is not pinned to this release.',
      date_evidence='Release displays 14 Aug 14:50 without year; publication/update date unverified. Short release SHA362c7ad visible, commit fetch failed.',
      access_issues=['Release commit click returned Internal Error; full inspected commit unavailable']),
 dict(title='ICICLE v4.0.0 NTT/batching release and version-only commit refresh',
      url='https://github.com/ingonyama-zk/icicle/releases/tag/v4.0.0',
      additional_urls=['https://github.com/ingonyama-zk/icicle/commit/6c77775961b0e4dc2be359feec1ac11536c18043','https://github.com/ingonyama-zk/icicle/blob/v4.0.0/LICENSE'],
      inspected_commit_id='6c77775961b0e4dc2be359feec1ac11536c18043',implementation_license='MIT body inspected at v4.0.0',
      assessment='Release lists NTT/ring, transpose-fusion and API work. Inspected tag commit changes Rust workspace version, not a kernel. No new native NTT incidence, compatible masking, or performance established.',
      date_evidence='Release shows 11 Jul 05:36 without year. Commit page has no parsed timestamp; exact date remains unverified.'),
 dict(title='Small-value/streaming sumcheck and equality factoring refresh',
      url='https://eprint.iacr.org/2026/587',publication_date='2026-03-24',
      paper_license='CC BY metadata',date_evidence='Primary history received2026-03-24, approved2026-03-25; no revision date shown.',
      assessment='Known reference for source enumeration versus retained state and per-factor equality. It does not establish a private fractional-tree protocol or justify uncounted scratch. No author speed reproduced.'),
 dict(title='Chimera October16 revision: whole-prover and residency scope refresh',
      url='https://eprint.iacr.org/2026/1388',publication_date='2026-07-07',verified_update_date='2026-10-16',paper_license='CC BY metadata',
      date_evidence='Primary ePrint received/revised history verified.',
      assessment='BN254 Spartan hybrid chunk-to-resident and late-CPU scheduling separates sumcheck-region gains from enclosing proving gains. Native Goldilocks already has resident-source/CPU-tail mechanisms; no author timing or privacy guarantee transferred.'),
 dict(title='NEW older technique assessed: Twist and Shout, October17 revision',
      url='https://eprint.iacr.org/2025/105',publication_date='2025-01-22',verified_update_date='2026-10-17',paper_license='CC BY metadata',
      additional_urls=['https://www.microsoft.com/en-us/research/publication/twist-and-shout-faster-memory-checking-arguments-via-one-hot/','https://github.com/a16z/jolt/blob/main/README.md','https://github.com/a16z/jolt/blob/main/LICENSE-MIT'],
      implementation_license='Jolt main MIT body inspected; README advertises MIT/Apache dual license; algorithm code/commit not inspected',
      assessment='One-hot addressing/increments avoid grand-product/grand-sum arguments. New direct paper assessment in this ledger; author Jolt/curve-based comparisons differ from the tiny256-entry native table and private PCS. Require full private input-consistency, added-commitment and terminal-cost design before replacing LogUp.',
      date_evidence='Primary received2025-01-22/last-of8 revisions2026-10-17. Microsoft primary labels CRYPTO2026.',
      access_issues=['https://eprint.iacr.org/2025/105.pdf:403 Forbidden']),
 dict(title='Proofs for Deep Thought accumulation/KV composition refresh',
      url='https://eprint.iacr.org/2024/325',publication_date='2024-02-26',verified_update_date='2025-03-03',paper_license='CC BY metadata',
      date_evidence='Primary received and last-of3 revisions verified; ASIACRYPT2024 major-revision label.',
      assessment='Previously assessed at cycle0069. Memory-size-independent IVC and accumulation-friendly GKR concern state binding; they do not remove attention checks or permit repeated native private openings. Backend/security and complete final-proof costs remain unknown.',
      access_issues=['https://eprint.iacr.org/2024/325.pdf:403 Forbidden']),
 dict(title='NEW author negative: OpenVM-zorch71 contention and scan regression',
      url='https://github.com/fractalyze/openvm-zorch/issues/71',verified_update_date='2026-06-20',
      date_evidence='Primary GitHub search excerpts show author comments Jun19/Jun20,2026; last verified inspected comment date, not latest repository update.',
      assessment='Author retracts107s GKR bottleneck after clean-device2.2s measurement and abandons byte-exact scan migration after CPU regression. This reinforces quiesced phase/enclosing clocks and preserving negative results. No author measurement reproduced; mentioned short commit c387a44 was not inspected.'),
 dict(title='Primary seven-day update queue checked October20',
      url='https://eprint.iacr.org/days/7',
      assessment='Live primary listing exposes October20 updates and October17 Twist/Shout plus October16 Chimera revisions. Used for queue freshness; not itself a paper publication date or performance evidence.',
      date_evidence='Listing accessed2026-10-20; individual histories separately checked.')
]
prior=[json.loads(s) for s in (BASE/'sources.jsonl').read_text().splitlines()]
rows=[]
for r in records:
    row=common|r
    row['prior_exact_url_records']=sum(old.get('url')==r['url'] for old in prior)
    rows.append(row)
(HERE/'source-records.json').write_text(json.dumps(rows,indent=2)+'\n')
queries=[
 'site.github.com openvm stark backend gkr revert_layers logup',
 'site.eprint.iacr.org 2026 GPU sumcheck batching memory commitment prover',
 'site.github.com sumcheck fraction tree "revert" denominator',
 'site.eprint.iacr.org "reversible" "GKR"',
 'site.github.com GPU NTT October 2026 release memory preprocessing',
 'site.github.com "frac_unadd_inplace"',
 'site.eprint.iacr.org "2026" "prover" "memory" "October"',
 'site.github.com/ingonyama-zk/icicle/releases v4.0.0',
 '"fractional" "sumcheck" "in-place" inverse',
 '"batch inversion" "product tree" in-place',
 'site.eprint.iacr.org/2026/ "2026-10" "prover" memory',
 '"reversible computation" "1973" Bennett time space',
 'site.eprint.iacr.org "fraction" "batch" "inversion" GKR',
 'site.github.com/fractalyze/openvm-zorch/issues/71 "Jun 20, 2026" "2.2s"',
 'site.github.com/a16z/jolt "Twist" "Shout" "2026"'
]
(HERE/'search-log.json').write_text(json.dumps(dict(tool='native LIVE web__run',access_date='2026-10-20',queries=queries,query_count=len(queries),source_records=len(rows),rotation=['batching/amortization','GPU NTT/commitments','sumcheck/GKR','memory traffic','lookup/softmax','proof composition'],next_rotation=['quantization/arithmetic under D32','composition/private input-consistency'],other_access_limits=['https://research.ibm.com/publications/logical-reversibility-of-computation: not accessible','https://doi.org/10.1147/rd.176.0525 -> IEEE robot/JavaScript gate; no bypass','One erroneous release-list click had invalid arguments; no source evidence obtained'],no_downloaded_code_execution=True),indent=2)+'\n')
hyp=json.loads((HERE/'hypotheses.json').read_text())
hyp[20].update(title='TESTED reversible full-column storage: exact but DEMOTED by selected-capacity floor',
 baseline='Prior adaptive32MiB consumer at frozen8B T128 has36.022MiB selected payload,6.028/6.054x source leaves. Immutable tree has4n-2 E entries; reversible tree has2n E entries. Neither is a native masked proof.',
 eliminated_work='Synthetic reconstruction uses one ordered leaf scan per column; symbolically avoids261128448/244613376 leaf generations at8B T128 nonDD/DD compared with prior adaptive plan. Removes no production work.',
 added_costs='At max2^21 leaves,64MiB tree +16MiB maximum batch prefix. With consumer, selected peak128.023/96.016/80.012/80/80MiB forq0..4. Batched recovery adds311620005/290386395 Fp2 multiplications,1569/1551 inversions and51937452/48398508 subtractions per modeled nonDD/DD forest, besides build/consumer. Actual instructions/transfers unknown.',
 prerequisites='Explicit private recursive GKR/original-A reduction remains a blocker. First investigate a bounded reversible subtree tile and cached leaf reciprocal lookup, charging all repeated source reads, persistent frontier, consumer tails and allocator capacity. GPU source bit-reverses; local tested layout instead has natural-order strided reads.',
 integration_cost='Tested Python layer factory and reversible storage, no native patch. Rust/CUDA replacement remains high-cost protocol integration.',
 exactness='42 trees,306 unmasked consumers,2 build/restore cycles; independent174 layers/348 MSB evaluations plus16pins/10 cost profiles. Native-Fp2 arithmetic, synthetic2..256 leaves, no native GKR/claims/transcript/PCS/receipt.',
 privacy_soundness='Zero denominators rejected even for zero numerator; original ordered MLE catches root-preserving swaps. Consumer must not fold retained tree. No changed native refusals/RNG/transcript, mask/opening reuse or public roots authorized. Last-level reciprocals already exist per-attempt; potential reuse is arithmetic cache only, not proof-randomness reuse.',
 compatibility='Prospective Tree::layer -> existing tested tiled consumer/source factory. Frozen native lookup_values_at/u8_denominator_inverses/helper_one/write_h and argument::helper_sum/SC_TAB still require a reviewed private protocol.',
 end_to_end_ceiling='No speed estimate. Full-column selected floor80MiB exceeds prior36.022MiB model before private costs. Unknown affected exclusive fraction f gives deletion ceiling<=1/(1-f); all new arithmetic reduces it.',
 falsification='Current unblocked full-column plan already fails a <=36.022MiB selected-array goal. Reject any tile if original source/order/field/refusal/claim/PCS differs, omitted capacity erases benefit, no real capacity cliff or slower complete workload.')
hyp.append(dict(rank=22,title='NEW older one-hot addressing/increments screen after Twist/Shout October17 update',
 baseline='Frozen native256-entry U8 global table and recurring helpers; fraction-tree replacement still lacks an integrated private reduction.',
 eliminated_work='Potential alternate route around fractional trees or helper commitments; no native work removed.',
 added_costs='One-hot consistency/lookup reductions, commitments, masking, source binding and final PCS; never assume dense256-way materialization is free.',
 prerequisites='Inspect exact Jolt algorithm/PCS and a reviewable tiny-table private contract; curve/large-structured-table claims cannot be transferred.',
 integration_cost='High protocol change; low-priority paper/source screen, not a ready patch.',
 exactness='Must preserve each ordered U8 query, histogram identity and all refusal/range constraints.',
 privacy_soundness='Private IO/activations and P3 weights, fresh randomness, native composition/soundness obligations; no partial checking.',
 compatibility='Lookup input-consistency alternative only; not drop-in to existing masked SumcheckRounds.',
 end_to_end_ceiling='Unknown until added commitments and exclusive native lookup cost are measured.',
 falsification='At256 table rows added private work exceeds removed helpers, binding/security is unresolved, or enclosing proof does not improve.'))
(HERE/'hypotheses.json').write_text(json.dumps(hyp,indent=2)+'\n')
print(json.dumps({'source_records':len(rows),'queries':len(queries),'hypotheses':len(hyp)}))

# Source ledger append is done only by the final checkpoint, after validation.
