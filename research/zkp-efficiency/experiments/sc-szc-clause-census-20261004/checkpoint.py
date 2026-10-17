"""Save research-only artifacts. No source edits, external writes or Git."""
import datetime,hashlib,json
from pathlib import Path

HERE=Path(__file__).resolve().parent
RESEARCH=HERE.parent.parent
RUN='20261004T140146Z-7230b465'
r=json.loads((HERE/'result.json').read_text())
assert r['status']=='pass'
assert json.loads((HERE/'execution.json').read_text())['exit_code']==0
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
p=next(x for x in r['projections'] if x['n']==23 and x['padded'] and 'nonzero' in x['recovery'])
proof='Accepted independently verified complete private 8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; model passes: 0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are unmeasured. No long-context prefill, repeated resident-model pass or decode proof occurred. The >=50 proved-token/s target remains unachieved. Larger workloads are allowed; attention grows quadratically with context, with fresh masks and full coverage/privacy preserved.'
summary=f"64 source-derived clause fixtures passed 576 independent original-cube samples against 1,728 candidate samples, 5,280 direct-MLE final values, 192 arbitrary-input clause values, 36 even-lookup values, 128 native declaration checks, 192 independent arithmetic-formula checks, 576 repeated counter checks and 288 adaptive guards. Ten negative controls fired. Final run: {r['elapsed_seconds']:.6f} s / {r['peak_rss_kib']:,} KiB RSS; seed {r['seed']}, one pinned nice19 Core Ultra 9 185H CPU thread; 59 s wall/CPU and 512 MiB address-space caps. No native proof or proving speed measured."
finding=f"Illustrative n23/short-Ht14/ls3/padded/release nonzero-recovery case has 30 native-style tables, 15 lookups and eight helpers. The complete zero-check bracket takes 54 Fp2 mul, 21 mul_base, 65 add and 33 sub API calls per evaluation; host groups each take two mul. Equality accumulation removes {p['removed_weight_mul']:,} mul from {p['complete_scanned_loop_mul_unit_aware']:,} counted scan+table-fold mul ({100*p['fraction_of_scanned_loop_fp2_mul_removed']:.3f}%), adds 83,904 Fp2 additions and 176 B logical scratch per part plus metadata. Including source-lowered base multiplications (5 per Fp2 mul, 2 per mul_base) makes the removed fraction {100*p['fraction_of_lowered_base_mul_removed']:.3f}%. Literal API count reduction is {100*p['literal_api_operation_fraction_removed']:.3f}%; none of these fractions is a time ceiling or native speedup. Table construction, Eq setup, inversions, group interpolation/recovery/reduction, masks/extensions, transcript, witness, PCS, transfers, serialization and verification are excluded and remain. Data/table folds are unchanged; symbolic Eq storage is a separate candidate."
negative='Two preserved mistakes matter: the initial all-zero IR lost its source-declared degree (fixed with zero metadata sentinels); the first passing port incorrectly batched the exempt A_E plane and used the wrong S-plane order. An independent pad.rs/layout.rs declaration audit corrected both, and added explicit exempt-E and wrong-order controls. The before-pad-plane-audit result is not native-relation evidence. The tuple-field expanded oracle is algebraically independent, but both evaluators consume a descriptor; that descriptor needs its own source-derived gate. Preserve all earlier slower fusion, compiler/small-phase, LRU, hash-prefix, reconstruction, privacy and tiny-chunk negatives.'
ranking='''| Rank | Hypothesis / end-to-end scope | Prerequisites, added costs and falsification |
|---|---|---|
| 1, owner | GPU SC_SZC plus recurring witness work; greatest measured remaining scope in prior single-block GPU diagnostics. | High CUDA/representation/masking integration; isolate both witness builds and native slot phases. Full degree/samples, fresh randomness, native transcript/finals/receipt and independent complete-workload verification; mismatch or enclosing regression rejects. No duplicate job. |
| 2, owner | Exact full-K split-int16 FFN-down. | Moderate/high packing, two byte products, i64 accumulation/requantization, refusal, transfer/workspace costs. Native down share unknown. Exact integer/support/native receipt parity and enclosing benefit required. |
| 3, NEW refined local | Compile lookup denominators once per proof definition: precompute alpha-cst, tag Unit/Neg/Scale rather than general mul_base for +/-1. Actual ls3 S lookup list has ten +1 and one -1 coefficient. | Moderate typed local helper/definition seam; setup/tag/dispatch costs, constant binding and term order. Potentially remove 11 mul_base and 15 accumulation adds per bracket call, subject to exact negative-coefficient rewrite. No tested/runtime gain yet. Native helper range/layout/odd-pair/mask/refusal/bytes must remain. Lost parity or enclosing regression rejects. |
| 4, tested/reranked | Symbolic Eq storage and adaptive weight accumulation. Memory storage remains useful; weighting alone is about 1% of counted padded scan/fold mul. | Moderate role-aware builder/storage/part scratch/reset work. Both pads, all clauses/helpers, explicit debug sample1, zero fallback, extension/RNG/finals/native receipt/peak gates. Any mismatch or no actual peak/enclosing benefit rejects. Keep these independent adaptations. |
| 5 | Immutable public digest/TN weight owner. | Moderate/high admission, all-consumer/clone/lease migration; import/transposes/scatter/hash and transfer costs. Setup-only current digest benefit, conditional duplicate memory. P3 identities stay private/reviewed; native identity/RNG/peak and enclosing gates. |
| 6 | Fresh resident-model complete-pass amortization. | Startup/slope, fixed context/pass count, pipeline lag/drain/independent verification and peaks required. Every recurring mask/commitment stays. Independent contexts are aggregate throughput; decode needs growing KV-state binding. Sustained recurring cost >20 ms/newly proved position falsifies >=50/s for that schedule. |
| 7, new primary lead | One-multiplication contiguous Eq-table expansion and borrowed point view, suggested by recent Plonky3 PR2305. Native eq_table still uses two mul and an MSB reverse Vec. | Low/moderate local constructor seam, extra subtraction/packing/thread policy costs. Full MSB/suffix/chunk/zero parity, allocation/clocks required. Unknown small setup share; source subtraction saving cannot be a complete-prover gain. |
'''
sources=[
 dict(title='More Optimizations to Sum-Check Proving, scope recheck',url='https://eprint.iacr.org/2024/1210',publication_date='2024-07-27',update_date=None,date_evidence='Received July27 2024; approved July29, not independently verified revision. Version archive unavailable.',author_claim='Reduces equality-factor work for product polynomials. Reported prover improvements concern common workloads; no native SC_SZC transfer assumed.',assessment='Actual SC_SZC brackets/helper/pad arithmetic dominates the local equality count. No author performance reproduced.'),
 dict(title='The Sum-Check Protocol over the Monomial Basis, and Other Optimizations',url='https://eprint.iacr.org/2026/762',publication_date='2026-04-17',update_date=None,date_evidence='Received April17 2026; approved April21. History endpoint and archive Cache miss. Earlier source record4 update_date April21 was approval, not a verified revision.',author_claim='Projective basis removes binding subtractions; authors report about10% on BN254/Fp128. Challenges/representation/round identities change.',assessment='Protocol/PCS/masking migration and basis costs prevent a local drop-in or Goldilocks2 speed inference.'),
 dict(title='Monomial sumcheck benchmark implementation and September methodology update',url='https://github.com/quangvdao/monomial-sumcheck-benchmarks',publication_date=None,update_date='2026-09-04',date_evidence='History https://github.com/quangvdao/monomial-sumcheck-benchmarks/commits/main/ latest displayed commits Sep4 2026; cached history does not establish current live HEAD.',exposed_commit='b2e6df5 (abbreviated history only)',implementation_license='Unknown: root shows no license; Cargo.toml/GitHub/raw fetches failed.',author_claim='README describes degree2 and degree2*Eq kernels, precomputed challenges and separate-process benchmark methodology. Apple M4 target.',assessment='Newly inspected implementation boundary/methodology, not runtime source. generic.rs/Cargo.toml Cache miss; no downloaded code run or commit inspected.'),
 dict(title='Plonky3 PR2305: borrowed points and packed equality kernel',url='https://github.com/Plonky3/Plonky3/pull/2305',publication_date='2026-09-22',update_date='2026-09-23',date_evidence='PR opened Sep22 2026, merged Sep23 2026, both full-year dates visible.',exposed_commit='cdb48a06c1a8fe0b5622ccadebceffc7bba2a1c6 (merge link; commit fetch failed)',implementation_license='MIT terms inspected at https://github.com/Plonky3/Plonky3/blob/main/LICENSE-MIT; not commit-pinned. Repo advertises dual MIT/Apache, only MIT read.',author_claim='One multiplication plus subtraction per expansion entry, contiguous packing and conditional extension-field chunking. Loaded-host diagnostic numbers include a small regression and parallel base-field negative.',assessment='Useful new setup/locality question at native mle.rs eq_table_msb/eq_table. PR description/review read; files diff/commit Cache miss. No performance reproduced.'),
 dict(title='Small-characteristic sumcheck: base-vs-extension cost qualification',url='https://eprint.iacr.org/2024/1046',publication_date='2024-06-27',update_date=None,date_evidence='Received June27 2024; approved June28. Revision not verified this cycle.',author_claim='Trades extra total multiplications for fewer extension-field multiplications when input polynomials have base-field values.',assessment='Current SC_SZC contains extension-valued LogUp helpers/challenges and degree3/4 clauses. No assumption that all products remain base-valued; prior implementation negative preserved.')]
for d in sources:
 d.update(run_id=RUN,cycle='0032',access_date='2026-10-04',accessed_utc=now,search_method='native LIVE web search and primary-page open',inspected_commit=None,reproduced=False)
(HERE/'sources-added.jsonl').write_text(''.join(json.dumps(d,sort_keys=True)+'\n' for d in sources))
with (RESEARCH/'sources.jsonl').open('a') as out: out.write((HERE/'sources-added.jsonl').read_text())
source_note='Five LIVE primary records cover 2024 equality/small-field techniques, the April2026 projective paper and newly inspected September benchmark methodology, plus Plonky3 PR2305 merged September23 2026. Native web search also checked recent release/mixed-field leads. Raw runtime files, some histories, PR2050/diff/full-commit and direct release-tag fetches failed with Cache miss/InternalError; exact attempted URLs are recorded below. No network bypass, installations, foreign-code execution or author-speed reproduction. MIT main terms inspected only for Plonky3; monomial repository license remains unknown.'
next_action='Next LOCAL: exact compiled-denominator Unit/Neg/Scale prototype at argument.rs helper_sum/definition, using this complete-clause cube oracle; include paired/odd multi-term lookups, nonzero tags, arbitrary Fp2 and zero challenges, preparation counts and branch costs. Owner first measures native Eq-weight/helper/bracket/interpolation/fold/reset phases and both witness builds/down, then shared-lock native masked/frozen/fresh independently verified complete-stack A/B. No heavy job queued.'
readme=f'''# Actual SC_SZC clause and arithmetic census

Cycle0032 `{RUN}`, {now}. **No proving speed improvement measured.**

{summary}

{finding}

Baseline: prior equality-factored native evaluator, all original tables folded; the tested Python arm has tagged Eq descriptors. Equality weighting compares both literal native calls and a fair unit-aware baseline. Eliminate repeated left*right weight products; retain original data scan, all expensive brackets and higher-degree samples. Add per-group/chunk accumulation, flushes, reset/index/guard branches and 176B scratch payload. Complete ceiling `N/(T-Cweight+Cnew)` remains unknown because no accepted8B T or isolated weighting clock exists. Counted arithmetic proportions cannot supply a native CPU/GPU ceiling. Falsify any original sample/final/index/support/helper/pad/native mask/RNG/transcript/extension/receipt/refusal/privacy mismatch, actual peak failure or enclosing regression.

{negative}

Fixture scope: n0/1/2/3, ls2/3, both support tables or neither, base/full/zero/Boolean data/challenges; Ht fields lifted over trailing j, S has distinct padding. Both odd13/15 and even14 lookup counts tested (even direct-clause cases only). Native names, limb lookup list, helper count and A_E exemption/order audited from pinned layout/shape/pad. Synthetic scale windows15/18, not new admitted profiles. Partial support configurations, native private source maps, honest witness/refusals, CFS/extension masking/RNG/transcript/PCS/parallel scheduler are unexecuted. Source-derived evaluator port is not the owned native boundary lane.

Files: `source_port.py` uses an instrumented literal Rust-API-style evaluation; `polynomial_ir.py` independently expands mathematical equations with tuple-field coefficients; `oracle.py` separately evaluates every original-cube sample/final without fold/recovery code. `candidate.py` is the earlier split accumulator, changed only through baseline bracket dispatch; copied baseline/field/oracle provenance in snapshots. Counters are independently checked by closed clause formulas and per-call repetition. Seed, dimensions, hardware, all code/native hashes and limits in `result.json`, `native-pins.json`, `memory-pins.json`; `execution.json` and `run.log` retain command/exit.

Reproduce: `python3 -B experiments/sc-szc-clause-census-20261004/experiment.py` from the research directory. It pins one low-priority core and enforces59s wall/CPU/512MiB. Do not run alongside proof timing; this is correctness/accounting only. No dependency/build/GPU job is needed.

{ranking}

{source_note}

{proof}

Historical cold synthetic12-block125M/T512 RTX4070Laptop diagnostic unchanged:408.609226s workload wall,318.22s combined run prover,12.15s in-process verification,484107456B,independent fresh verification false. Not an accepted8B/P1 rate. LaterCLI has no terminal result after reboot; no liveness inferred from stale state.

{next_action}
'''
(HERE/'README.md').write_text(readme)
seam='Native seam: `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/argument.rs:894` helper_sum, `:1788` SC_SZC bracket; `zkp-core/src/sumcheck/grouped.rs:99` part and `:162` table fold. Pad schema: private_block/pad.rs a_rule/zero_rule_a_planes and layout.rs Dom::S plane order. Native source hashes/snapshots retained; no Rust patch compiled/applied. Owner/Claude reviews and integrates, this lane never merges.'
handoff=f'''# Owner handoff — actual clauses narrow equality saving

Cycle0032 `{RUN}`, {now}. **Synthetic prerequisite and useful negative scope finding, no native speed result.**

{summary}

{finding}

Interface: adapt a bracket evaluator through `Terms.evaluate(values)` in the standalone Python prototype; native actual closure is unchanged. The separate expanded IR covers five softmax clauses, exp lookup, paired/single U8 helpers, both host groups and two pad groups with continued zeta powers. Preserve A_E exemption, original zero-rule plane order and Ht support over j padding. The attached independent arithmetic formula distinguishes Fp2 mul/mul_base/add/sub. Illustrative n23 profile/census is not an admitted proof workload.

{seam}

{negative}

Native adaptation gates: actual registered profiles including partial pad support/source-map builds, arbitrary/zero challenges and explicit debug sample1; masked round/extension/final/RNG parity, frozen bytes, fresh-process independent verification and corruption/refusal controls; parent phase/capacity/peak and complete workload clocks. Fresh masks/openings and full checked relation remain; no changed field/PCS/challenge set or privacy weakening. Exact prototype parity alone does not discharge native soundness/privacy obligations. Candidate weighting should be prioritized only after isolated native cost measurement; storage removal remains independently useful for memory.

NEW next candidate: construct per-proof helper denominators with prepared alpha-cst and typed Unit/Neg/Scale operations. Counted ls3 lookup list has10 +1 and1 -1 coefficients; a correct specialized rewrite could remove11 general mul_base per group0 call plus the current per-term accumulation. This has not been tested and may add dispatch/preparation costs. Do not adopt until the full current oracle and native byte/privacy gates pass.

{source_note}

{proof}

{next_action}

Review [experiment](../experiments/sc-szc-clause-census-20261004/README.md), source/results/logs/pins and preserved mistakes. No heavy job queued, no production/source/Git edit or message delivered externally.
'''
(RESEARCH/'handoffs/20261004-sc-szc-clause-census.md').write_text(handoff)
progress=f'''# ZKP efficiency progress

Cycle0032 — `{RUN}`, checkpoint {now}.

**No proving speed improvement measured.** {summary}

The corrected actual-clause census narrows the earlier equality result:25,079,832 removed weight multiplications are1.012% of the counted padded n23 scan/fold Fp2 multiplications, or0.894% of source-lowered base multiplications. Brackets and helper arithmetic dominate. These fractions omit setup/protocol work and are not runtime/complete-proof rates. The A_E exemption/plane-order error in the initial prototype is preserved and fixed, with controls. No production patch.

[Experiment](experiments/sc-szc-clause-census-20261004/README.md) · [Owner handoff](handoffs/20261004-sc-szc-clause-census.md). Five LIVE primary source records saved; remote runtime/diff/history failures blocked source inspection only, local work completed.

{proof}

{next_action} Saved reports are local artifacts, not notification-delivery evidence.
'''
(RESEARCH/'PROGRESS.md').write_text(progress)
(RESEARCH/'progress'/f'{RUN}.md').write_text(progress)
with (RESEARCH/'FINDINGS.md').open('a') as out:
 out.write(f'\n\n## Cycle0032 — actual SC_SZC clauses and weighting ceiling (2026-10-04)\n\nRun `{RUN}`, checkpoint {now}. AGENDA, durable state/findings/all172 prior source records/latest results and required project documents read/snapshotted; early state14:03UTC. Research-only one-thread CPU work, no production/runtime/GPU/build/install/Git/downloaded execution/external-write/message action.\n\n'+summary+'\n\n'+finding+'\n\n'+negative+'\n\n'+ranking+'\n\n'+source_note+'\n\n'+seam+'\n\nBaseline keeps data/brackets/folds/commitments; added weighting accumulators/branches/reset scratch. Complete ceilingN/(T-Cweight+Cnew) remains unmeasured; exact arithmetic, full checked relation, masks/RNG/transcript/refusal/extension/receipt/privacy/peak/enclosing gates required.\n\n'+proof+'\n\n'+next_action+'\n\n[Experiment](experiments/sc-szc-clause-census-20261004/README.md), [handoff](handoffs/20261004-sc-szc-clause-census.md). Reports are local artifacts, not delivery records.\n')
state=f'''# ZKP efficiency explorer — durable state

Cycle0032 COMPLETE: `{RUN}`, checkpoint {now}; deadline2026-10-04T14:21:46Z, next cycle no earlier than2026-10-04T15:01:46Z. Read AGENDA every cycle. Prior memory and native pins retained in experiments/sc-szc-clause-census-20261004/snapshots/. Research-only writes excluding runtime; one thread/<=60s/<=512MiB. No native/build/GPU/install/Git/downloaded execution/production/external-write/message action.

{proof}

{summary}

{finding}

{negative}

Ranked:1owner GPU SC_SZC+witness;2full-K exact split-int16down;3NEW compiled lookup denominator Unit/Neg/Scale and alpha-cst;4symbolicEq memory+adaptiveweighting (small counted share);5publicdigest/TN;6freshresidentcomplete-pass startup/slope/drain/verify;7NEW one-mul packed Eq construction/borrowed point. Baseline/eliminated/addcost/prerequisite/falsification/unknowncompleteceilings in README/FINDINGS. No Rust patch or heavy job queued.

{source_note}

Historical synthetic12block125M/T5124070Laptop remains408.609226swall/318.22runprover/12.15inprocessverify/484107456B/independentfalse. LaterCLI no terminal result; stale state not liveness.

{next_action}

Handoff handoffs/20261004-sc-szc-clause-census.md. PROGRESS.md and progress/{RUN}.md saved locally; no delivery record claimed.
'''
(RESEARCH/'STATE.md').write_text(state)
(HERE/'checkpoint.json').write_text(json.dumps(dict(run_id=RUN,checkpoint_utc=now,status='complete',source_records_added=len(sources),report_paths=['STATE.md','PROGRESS.md','progress/'+RUN+'.md','FINDINGS.md','handoffs/20261004-sc-szc-clause-census.md']),indent=2)+'\n')
print(json.dumps(dict(checkpoint_utc=now,source_records_added=len(sources),result=r['status'])))
