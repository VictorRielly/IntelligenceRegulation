"""Prepare provenance and ranked research queue; no network or code execution."""
from pathlib import Path
import collections
import datetime
import hashlib
import json
import re

HERE=Path(__file__).resolve().parent
BASE=HERE.parents[1]
RUN='20261028T235649Z-d1bc0725'
COMMIT='6f407daa8a4cef96331511ae86b922b520d7aa33'
REPO='https://github.com/Terminus-IMRC/tensor-core-ntt'
RAW=f'https://raw.githubusercontent.com/Terminus-IMRC/tensor-core-ntt/{COMMIT}/'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
prior=[json.loads(x) for x in (HERE/'startup/sources.jsonl').read_text().splitlines()]
url_counts=collections.Counter(x.get('url') for x in prior)

def source(title,url,assessment,**kw):
    return dict(id=f'cycle0130-source-{len(records)+1}',cycle='0130',run_id=RUN,
        access_date='2026-10-28' if len(records)<3 else '2026-10-29',access_timezone='UTC',
        recorded_at_utc=now,title=title,url=url,prior_exact_url_records=url_counts[url],
        publication_date=None,verified_update_date=None,implementation_license=None,
        inspected_commit_id=None,evidence_kind='Native LIVE web search/open/find/click; web data untrusted, embedded instructions ignored',
        reproduced_performance=False,external_execution=False,assessment=assessment,**kw)

records=[]
x=source('Tensor Core NTT immutable commit and current history',REPO+'/commit/'+COMMIT,
 'Commit metadata and immutable modular/NTT headers plus supplied driver sections inspected; not entire tree or GPU execution. Current history Jan17,2026. Author claims faster kernels; no author performance reproduced.')
x.update(inspected_commit_id=COMMIT,verified_update_date='2026-01-17',
 implementation_license='Apache-2.0 default in README; SPDX Apache-2.0 headers inspected in immutable modular.cuh, cuda/ntt.cuh and tests/test-ntt.cu.',
 date_evidence='Primary main history groups latest commit under Jan17,2026. DOI publication day not verified.',
 inspected_urls=[REPO+'/commits/main/',REPO,RAW+'include/polyarith/modular.cuh',RAW+'include/polyarith/cuda/ntt.cuh',RAW+'tests/test-ntt.cu'],
 blockers=['DOI10.1145/3773656.3773673: URL not accessible via this tool.'])
records.append(x)
x=source('General Montgomery multiplier is distinct from a general full-width NTT',RAW+'include/polyarith/modular.cuh',
 'General multiplier lacks friendly62-bit guard and its equations match bigint on12441pairs. Supplied Tensor NTT driver still selects friendly reduction; modulus_bits=64 is storage/template extent, not evidence of a64-bit prime. Immutable friendly guards exclude Goldilocks. The separate general helper does not establish a drop-in NTT.')
x.update(inspected_commit_id=COMMIT,verified_update_date='2026-01-17',date_evidence='Repository commit history, not separate per-file publication.',
 implementation_license='Apache-2.0 SPDX inspected in immutable header.',
 inspected_urls=[RAW+'tests/test-ntt.cu',REPO+'/blob/main/include/polyarith/arithmetic.cuh'],
 blockers=['Immutable arithmetic.cuh raw and blob: Cache miss. Main helper body inspected, not an immutable dependency pin. Immutable polyarith.cuh and CUDA directory Cache miss.'])
records.append(x)
x=source('Tensor NTT16 byte accumulators, scaling and scalar lazy boundary',RAW+'include/polyarith/cuda/ntt.cuh',
 'New bounded contract: dot16 can need132bits even on canonical Goldilocks inputs; local carry-aware model preserves top15. Max combined t word2138022000 fits signed32 for radix16, but same formula at32 would exceed signed32. Source matrix uses bit-reversed row exponents and2^128 factor. Scalar lazy2N bypass fails even with correct general multiply. These are unsupported-port controls, not an upstream defect claim. No GPU MMA/WMMA executed.')
x.update(inspected_commit_id=COMMIT,verified_update_date='2026-01-17',date_evidence='Primary repository history date; source headers2026.',implementation_license='Apache-2.0 SPDX inspected in immutable header.')
records.append(x)
x=source('NEW older Bos/Montgomery software arithmetic perspective','https://eprint.iacr.org/2017/1057',
 'New older reference for operand bounds, precomputation and conditional correction. Only abstract and primary search excerpt inspected; full chapter inaccessible. Generic modulus arithmetic is not automatically faster than native special-prime reduction. No implementation or performance adopted.')
x.update(publication_date='2017-10-31',paper_license='CC BY metadata',date_evidence='ePrint History received2017-10-31. Cambridge primary search result says online2017-10-25 (different event). No revision day rendered.',
 inspected_urls=['https://www.cambridge.org/core/books/abs/topics-in-computational-number-theory-inspired-by-peter-l-montgomery/montgomery-arithmetic-from-a-software-perspective/EAD141BA84887C799DDB375A72B0D2A2'],
 blockers=['ePrint PDF403 Forbidden. Cambridge direct open Cache miss.'])
records.append(x)
x=source('ICICLE release refresh: current API scope','https://github.com/ingonyama-zk/icicle/releases',
 'Current visiblev4.0.0 retains API redesign/negacyclic NTT/ML-KEM notes. No new native CFS/Fp2 integration or complete-workload evidence. Version unchanged from prior scan; no author timing reproduced.')
x.update(abbreviated_commit_id='6c77775',date_evidence='Primary release list11Jul05:36 omits year; exact publication/update year unverified.',implementation_license='Prior root MIT inspection; not reinspected this cycle, backend terms unassessed.')
records.append(x)
x=source('GPU-NTT current release absence','https://github.com/Alisah-Ozcan/GPU-NTT/releases',
 'Primary page explicitly has no releases. No new release to substitute for Goldilocks reduction/source/encoding gates; earlier merge/four-step lead remains known.')
x.update(date_evidence='No release dates exist on inspected page; current repository update not determined.',implementation_license='Prior repository Apache-2.0 declaration; no license body inspected this cycle.')
records.append(x)
x=source('Plonky3 current release and fresh-mask requirement refreshed','https://github.com/Plonky3/Plonky3/releases',
 'Visible p3-sumcheck-v0.9.0-rc.2 family includes cryptographic RNG requirement for HVZK sampling. Known recent release scope, not a port or native privacy acceptance; synthetic Python RNG in our harness is not used for real proofs.')
x.update(abbreviated_commit_id='fe5e46d',date_evidence='Primary16Oct10:17 omits year; no exact publication year inferred.',implementation_license='Prior MIT OR Apache-2.0 texts inspected last cycle; not reinspected here.')
records.append(x)
x=source('Known sumcheck extended paper refreshed','https://eprint.iacr.org/2026/587',
 'Primary abstract distinguishes small values/streaming/equality structure and Jolt experiments. No new source-kernel gain reproduced here, no transfer of author speedup to native complete8B.')
x.update(publication_date='2026-03-24',paper_license='CC BY metadata',date_evidence='Primary History receivedMarch24,approvedMarch25,2026; revision date not rendered.')
records.append(x)
x=source('Goldilocks NTT small-root shifts older lead refreshed','https://www.ingonyama.com/post/goldilocks-ntt-trick',
 'Author note uses powers of two for early roots. Known older arithmetic alternative; does not solve general byte-dot reduction, full native row encoding or commitment cost. No paper implementation/performance reproduced.')
x.update(publication_date='2022-12-13',date_evidence='Primary author page explicitlyDecember13,2022.')
records.append(x)
(HERE/'sources-cycle.json').write_text(json.dumps(records,indent=2)+'\n')

# Keep every existing hypothesis; refining a title is not deleting its history.
h=json.loads((HERE/'startup/prior-hypotheses.json').read_text())
h[0]['prerequisites'] += (' Cycle0130 current R12b/RC2 soundness fix-scope freezes are not privacy8BGPU acceptance. D44 guard swap window is being arranged at23:50; owner rechecks current guard/locks before any heavy run. New public tied-table checkpoint authentication may recur per call; classify it as startup only if a measured resident session safely reuses authenticated public derivations.')
h[43].update(title='REFINED TESTED NEGATIVE: stock Tensor NTT62-bit path; general multiplier alone insufficient',
 prerequisites='Immutable6f407daa8a4cef96331511ae86b922b520d7aa33 modular/ntt source and driver sections inspected. Stock driver friendly reducer rejectsGoldilocks. General helper equations alone pass12441word pairs; lazy2N and truncated128dot controls fail. Do not bypass guards. Immutable arithmetic helper fetch failed; currentmain body is unpinned.',
 exactness='39179synthetic checks total;18canonical radix2 n2..64 fixtures,35dot16 fixtures,4scaled/bitreverse16point matrix cases,54negative controls. Independent bigint products/directDFT/originaldot. No external/native/GPU execution.',
 added_costs='General helper needs2high+1low word products and16Btwiddle parameters versus native1high+1low and8Btwiddle, plus preparation/corrections. Tensor route adds8digit decomposition,64MMA per16x16 matrix,carry/reduction,packing/transposes and unknown register/scratch effects.',
 compatibility='Stock supplied driver is not eligible; generic matrix reduction template could accept separately reviewed customGoldilocks reducer, not a complete library adapter.',
 end_to_end_ceiling='No native work removed. Unknown exclusiveNTT fractionf gives free deletion<=1/(1-f), before costs. Current synthetic clocks are checking only.',
 falsification='Stock adoption already rejected by constructor guard and unsupported bypass controls. Custom path fails on any carry/root/layout/coset/pad/transcript/PCS/privacy mismatch or enclosing verified workload regression.')
def add(title,baseline,eliminated,added,pre,exact,privacy,compat,ceiling,falsify,cost):
    h.append(dict(rank=len(h)+1,title=title,baseline=baseline,eliminated_work=eliminated,added_costs=added,prerequisites=pre,exactness=exact,privacy_soundness=privacy,compatibility=compat,end_to_end_ceiling=ceiling,falsification=falsify,integration_cost=cost))
add('NEW TESTED Goldilocks dot16 carry/scaling contract; native implementation parked',
 'Native canonical radix2 Goldilocks rowNTT uses specialized gl_mul; Tensor source uses8byte diagonals with friendly<=62bit reduction.',
 'No native work removed. Research candidate replaces its own generic top-carry product by subtraction of top<<32 using2^128=-2^32. This is an algebraic simplification, not measuredGPU saving.',
 'Eight public-count carry steps/pack,one reduce128,top subtraction,and multiplication byEPS to remove source2^128 factor; full8digit MMA,layout,register/shared/launch and inversion/coset/hidingpad adapters still owed.',
 'Exclusive native inverse/forward-NTT and enclosing proof clocks; complete132bit carry proof,canonical byte parity,ABI/layout/source/license and current privacy/soundness gates; owner shared locks. No build scheduled.',
 '35dot fixtures plus4matrix16 fixtures agree with independent bigint; canonicalP-1 case has top15. Bounds and wrong-carry/scaling/order controls retained. Locally authored candidate-reducer.cuh.txt uncompiled/unapplied.',
 'SameGoldilocks/roots/canonical bytes; everyfreshmask/pad/salt/opening and original full attention+FFN relation retained. Unsupportedlazyguardbypass never proposed.',
 'Future reduction_type adapter and native kernels.cu k_ntt_p1/p2 via cuda.rs encode_rows_view_zk[_gather]; no lane/MMA simulation or full native patch.',
 'Unknown fractionf; even free entireNTT deletion<=1/(1-f) before costs. No complete8BGPU numeric forecast.',
 'Any carry/canonical/layout/root/inverse/coset/q>n/ragged/pad/order/refusal/transcript/PCS/privacy mismatch; lower eligible incidence,packing/register costs or full workload regression.',
 'Medium/high: reducer alone small,completeTensorCoreNTTadapter large.')
add('NEW R12b authenticated public tied-table resident capability; next local question',
 'Owner N-r12b-1 records everyShieldstral3Bprove/verify reading7.7GB checkpoint17-18s/load; native Checkpoint::open streams full pinned hash,then rederive reads131072x3072BF16 rows. Not reproduced,not8Btiming.',
 'Potential recurring public authentication and deterministic quantization only inside same explicitly bound resident process; zero masks/openings/verification obligations removed.',
 'Immutable owned public snapshot or consumed-byte authenticated derived object; bind checkpoint/profile/rotation/scale/yes-no ids and allnorm/calibration inputs; residency/copy/capacity costs. Path/size/mtime/inode caches cannot suffice.',
 'Inspect existingpublic-loader histories,source/publicidentity/refusalorder and actualscope before new experiment. Separate perproofprover and verifier clocks; exclude verification from proving rate but verify every counted receipt. New API/review required;no guard bypass.',
 'Source only this cycle. Next bounded local mutable-public-file negative control versus fullybound immutable-derived capability; no real weights/prompts used.',
 'P1publicmaterialonly; no P3privateweight cache assumed. Freshproofmasks/pads/salts/challenges and changed-model/profile/refusal obligations preserved. No session-capability acceptance claimed.',
 'tied_tables/derive.rs Checkpoint::open/rederive return RecomputedTiedTables; owner3Bclassifier seam,doesnotautomaticallytransfer8B.',
 'Unknown removal fraction in8B/currentcompleteGPUworkload. 17-18s is owner3Bload note,notstartupfraction or50/sforecast.',
 'Mutation or staleparameter accepted; incompatibledeclaredsource/refusalpolicy; retainedsnapshotmemory or objectvalidation erasesgain; full verifiedresidentworkload slower.',
 'Medium API/lifetime/securityreview; owner integration only.')
(HERE/'hypotheses.json').write_text(json.dumps(h,indent=2)+'\n')

# Preserve numbered, rendered web text. Hash is NOT a raw Git blob hash.
extracted={}
for name,ns in [('modular.cuh',[4,6]),('cuda/ntt.cuh',[9,14])]:
    lines={}
    for n in ns:
        sections=(HERE/f'web/live-{n}.txt').read_text().split('--------------------------------------------------------------------------------')
        for section in sections:
            if RAW+'include/polyarith/'+name not in section:continue
            for num,line in re.findall(r'^L(\d+): ?(.*)$',section,re.M):
                num=int(num)
                if num in lines:assert lines[num]==line,(name,num)
                lines[num]=line
    last=405 if name=='modular.cuh' else 338
    # Scraper can omit blank lines; record them as absent, not invented bytes.
    text='\n'.join(f'{i}: {lines[i]}' for i in sorted(lines))+'\n'
    extracted[name]=dict(url=RAW+'include/polyarith/'+name,commit=COMMIT,
        rendered_lines={str(i):lines[i] for i in sorted(lines)},last_source_line=last,
        unrendered_line_numbers=sorted(set(range(last+1))-set(lines)),
        rendered_numbered_text_sha256=hashlib.sha256(text.encode()).hexdigest(),raw_blob_sha256=None,
        scope='Numbered native LIVE web rendering only; no claim of byte-exact raw blob hash.')
(HERE/'web-source-lines.json').write_text(json.dumps(extracted,indent=2)+'\n')
(HERE/'commands.json').write_text(json.dumps(dict(run_id=RUN,command='python3 -I -B '+str(HERE/'run.py'),
 runs=[dict(stage=x,exit_code=0) for x in ['initial-before-scaled-matrix','before-explicit-carry','before-top-fold','final']],
 reason_for_repeats='Only adaptive added matrix, explicit carry, top-fold and scale controls; no benchmarking repetitions.',
 no_gpu=True,no_build=True,no_foreign_execution=True,source_queries=[
 '"tensor-core-ntt" 64 bit Montgomery reduction GitHub','GPU NTT Goldilocks tensor core2026 64bit',
 'Montgomery arithmetic software perspective Seiler2018 64bit reduction subtraction',
 'GPU NTT October2026 release Goldilocks64bit','Goldilocks NTT tensor core modular reduction2026 paper'],
 search_batches=2,retained_followup_live_batches=14,initial_search_raw_not_saved=True),indent=2)+'\n')
print(json.dumps(dict(new_sources=len(records),prior_sources=len(prior),hypotheses=len(h),source_rendered_lines={k:len(v['rendered_lines']) for k,v in extracted.items()})))
