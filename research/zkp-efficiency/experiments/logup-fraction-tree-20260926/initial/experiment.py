#!/usr/bin/env python3
"""Synthetic fractional LogUp feasibility only; no proof or security claim."""
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time

P = 2**64 - 2**32 + 1
Z = (0, 0)
O = (1, 0)
SEED = 2026092608
HERE = Path(__file__).resolve().parent

def add(a, b): return ((a[0]+b[0]) % P, (a[1]+b[1]) % P)
def neg(a): return ((-a[0]) % P, (-a[1]) % P)
def sub(a, b): return add(a, neg(b))
def mul(a, b): return ((a[0]*b[0]+7*a[1]*b[1]) % P, (a[0]*b[1]+a[1]*b[0]) % P)
def scalar(x): return (x % P, 0)

# Independent oracle: polynomial convolution, followed by X^2 = 7 reduction.
def ref_product(a, b):
    c = [0, 0, 0]
    for i in range(2):
        for j in range(2): c[i+j] += a[i]*b[j]
    c[0] += 7*c.pop()
    return tuple(x % P for x in c)

def ref_inverse(a):
    if a == Z: raise ValueError('zero LogUp denominator; discard attempt')
    # Fermat exponentiation in Fp2, independent of conjugate/norm inversion.
    x, k, out = a, P*P-2, O
    while k:
        if k & 1: out = ref_product(out, x)
        x = ref_product(x, x)
        k >>= 1
    return out

def direct_sum(leaves):
    out = [0, 0]
    for numerator, denominator in leaves:
        term = ref_product(numerator, ref_inverse(denominator))
        for j in range(2): out[j] += term[j]
    return tuple(x % P for x in out)

def expanded_fraction(leaves):
    """Direct O(n^2) product-of-all-others identity, no tree recurrence."""
    denominator = O
    for _, d in leaves: denominator = ref_product(denominator, d)
    numerator = [0, 0]
    for i, (n, _) in enumerate(leaves):
        term = n
        for j, (_, d) in enumerate(leaves):
            if i != j: term = ref_product(term, d)
        for k in range(2): numerator[k] += term[k]
    return tuple(x % P for x in numerator), denominator

def merge(left, right):
    a, b = left
    c, d = right
    return add(mul(a, d), mul(c, b)), mul(b, d)

def tree(leaves, checked=True):
    if not leaves: raise ValueError('empty schema')
    if checked and any(d == Z for _, d in leaves):
        raise ValueError('zero LogUp denominator; discard attempt')
    width = 1 << (len(leaves)-1).bit_length()
    levels = [list(leaves) + [(Z, O)]*(width-len(leaves))]
    while len(levels[-1]) > 1:
        old = levels[-1]
        levels.append([merge(old[i], old[i+1]) for i in range(0, len(old), 2)])
    return levels[-1][0], levels

def fold_mle(values, point):
    a = list(values)
    assert len(a) == 1 << len(point)
    for r in point:
        half = len(a)//2
        a = [add(mul(sub(O, r), a[i]), mul(r, a[i+half])) for i in range(half)]
    return a[0]

def cube_mle(values, point):
    acc = [0, 0]
    for i, value in enumerate(values):
        term = value
        for j, r in enumerate(point):
            factor = r if (i >> (len(point)-1-j)) & 1 else ((1-r[0]) % P, -r[1] % P)
            term = ref_product(term, factor)
        for k in range(2): acc[k] += term[k]
    return tuple(x % P for x in acc)

def link(leaves, point, theta):
    # Diagnostic analogue of a required leaf link, NOT a PCS proof.
    width = 1 << len(point)
    assert len(leaves) <= width
    leaves = leaves + [(Z, O)]*(width-len(leaves))
    return add(fold_mle([n for n, _ in leaves], point),
               mul(theta, fold_mle([sub(d, O) for _, d in leaves], point)))

def lookup_leaves(values, table, multiplicities, alpha, tag=Z):
    assert len(table) == len(multiplicities)
    # Keep every table denominator even when its multiplicity is zero.
    return [(O, sub(alpha, add(scalar(v), tag))) for v in values] + [
        (scalar(-m), sub(alpha, add(scalar(v), tag))) for v, m in zip(table, multiplicities)]

def refused(fn):
    try: fn()
    except ValueError: return True
    return False

def costs():
    # Literal 125M geometry derived from pinned shape.rs, not allocated here.
    n = 1 << 14
    domains = dict(L=(n,2), D=(512*1024,34), Q=(512*16*64,13),
                   Kv=(512*4*64,12), S=(16*512*512,15), F=(512*2048,9))
    rows = {k:2*((count+1)//2)*(size//n) for k,(size,count) in domains.items()}
    rows.update(exp=2*domains['S'][0]//n, act=2*domains['F'][0]//n,
                table_helpers=6, zero_sum_pair=2)
    h_data_rows = sum(rows.values())
    assert h_data_rows == 7018
    assert sum(size*count for size,count in domains.values()) == 98598912
    h_rows = h_data_rows + 100 + 2
    # All padded witness positions remain. Table lift is shown as two choices;
    # removing repeated table padding still requires its zero-multiplicity pin.
    raw = sum(size*count for size,count in domains.values()) + domains['S'][0] + domains['F'][0]
    ledgers=[]
    for table_width in (256,n):
        leaves=raw+3*table_width
        padded=1 << (leaves-1).bit_length()
        ledgers.append(dict(table_width=table_width,active_leaves=leaves,padded_leaves=padded,
            padding_leaves=padded-leaves,merge_count=padded-1,
            extension_multiplications=3*(padded-1),extension_additions=padded-1,
            full_tree_fp2_values=2*(2*padded-1),full_tree_bytes=16*2*(2*padded-1),
            leaf_layer_bytes=16*2*padded,out_of_place_first_parent_bytes=16*3*padded,
            flat_unencoded_tree_base_rows=2*2*(2*padded-1)//n))
    return dict(scope='COUNTED 125M geometry, no model arrays allocated; not an 8B prediction',
        domains=domains,h_rows_by_kind=rows,h_data_rows=h_data_rows,h_rows=h_rows,
        baseline_h_input_bytes=8*h_rows*n,baseline_h_encoded_bytes=8*h_rows*n*4,
        gross_helper_data_rows=h_data_rows-2,removed_mask_rows_assumed=0,
        new_gkr_mask_rows=None,new_leaf_binding_rows=None,new_proof_bytes=None,
        net_commitment_rows_saved=None,tree_options=ledgers,
        notes=['Keeping an uncommitted tree avoids encoding it but requires a new GKR/PCS link',
               'Directly committing the whole tree is a negative comparator, not proposed',
               'Root denominator, internal claims and final openings need a fresh joint privacy argument',
               'In-place/streamed recomputation may lower memory; excluded from this measured experiment'])

def run():
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(55,55))
    signal.alarm(59)
    start=time.perf_counter()
    rng=random.Random(SEED)
    rand=lambda:(rng.randrange(P),rng.randrange(P))
    digest=hashlib.sha256()
    cases=points=lookup_cases=0
    for length in (1,2,3,8,32):
        for trial in range(30):
            leaves=[]
            for i in range(length):
                num=scalar(rng.randint(-5,5)) if trial%3 else rand()
                den=rand() if trial%4 else scalar(rng.choice([1,2,P-1]))
                leaves.append((num,den))
            root,levels=tree(leaves)
            assert root==expanded_fraction(leaves)
            assert mul(root[0],ref_inverse(root[1]))==direct_sum(leaves)
            q=[rand() for _ in range((len(levels[0])-1).bit_length())]
            for vals in ([n for n,d in levels[0]],[sub(d,O) for n,d in levels[0]]):
                assert fold_mle(vals,q)==cube_mle(vals,q)
                points+=1
            digest.update(repr((root,link(leaves,q,rand()))).encode())
            cases+=1
    for length in (1,2,3,8,32):
        for trial in range(20):
            tab=list(range(8))
            values=[rng.randrange(8) for _ in range(length)]
            m=[values.count(v) for v in tab]
            leaves=lookup_leaves(values,tab,m,rand(),rand())
            root,_=tree(leaves)
            assert root[0]==Z and root[1]!=Z and direct_sum(leaves)==Z
            lookup_cases+=1

    controls={}
    a=(91,7); tag=(5,3); tab=[0,1,2,3]
    good=lookup_leaves([0,0,2],tab,[2,0,1,0],a,tag)
    root,lev=tree(good)
    controls['changed_lookup_with_fixed_histogram']=tree(lookup_leaves([0,1,2],tab,[2,0,1,0],a,tag))[0][0]!=Z
    controls['changed_multiplicity']=tree(lookup_leaves([0,0,2],tab,[1,1,1,0],a,tag))[0][0]!=Z
    controls['omitted_nonzero_leaf']=tree(good[1:])[0][0]!=Z
    controls['wrong_table_sign']=tree(good[:3]+[(neg(n),d) for n,d in good[3:]])[0][0]!=Z
    q=[rand() for _ in range(3)];theta=rand()
    controls['wrong_padding_denominator']=link(good+[(Z,scalar(2))],q,theta)!=link(good,q,theta)
    controls['wrong_leaf_order_binding']=link(list(reversed(good)),q,theta)!=link(good,q,theta)
    # Same rational root is NOT same ordered leaf binding.
    assert tree(list(reversed(good)))[0]==root
    bad=good.copy();bad[0]=(O,add(bad[0][1],O))
    controls['stale_bound_input']=link(bad,q,theta)!=link(good,q,theta)
    forged=lev[-2]
    wrong_n=mul(forged[0][0],forged[1][1])
    # Use noncancelling independent fixture for the missing-cross-term control.
    r,_=tree([(scalar(2),(3,4)),(scalar(5),(6,7))])
    controls['omitted_merge_cross_term']=r[0]!=mul(scalar(2),(6,7))
    zero_mult=lookup_leaves([0],tab,[1,0,0,0],add(scalar(3),tag),tag)
    controls['whole_table_zero_denominator_refusal']=refused(lambda:tree(zero_mult))
    pruned=[(n,d) for n,d in zero_mult if n!=Z]
    assert tree(pruned)[0][0]==Z  # bad omission changes refusal domain
    controls['pruning_zero_multiplicity_changes_refusal']=not refused(lambda:tree(pruned))
    controls['witness_zero_denominator_refusal']=refused(lambda:tree(lookup_leaves([0],tab,[1,0,0,0],tag,tag)))
    raw_zero,_=tree([(O,Z),(neg(O),Z)],checked=False)
    assert raw_zero==(Z,Z)
    controls['zero_over_zero_root_ambiguity']=refused(lambda:tree([(O,Z),(neg(O),Z)])) and mul(raw_zero[0],O)==mul(Z,raw_zero[1])
    # Dropping a matching witness and multiplicity preserves root-zero;
    # only binding all original leaves/trace and the public schema prevents it.
    omitted=lookup_leaves([0,2],tab,[1,0,1,0],a,tag)
    assert tree(omitted)[0][0]==Z
    controls['matched_omission_requires_binding']=link(omitted,q,theta)!=link(good,q,theta)
    # Publishing a denominator root leaks a single private value exactly.
    table_product=O
    for value in tab:table_product=ref_product(table_product,sub(a,add(scalar(value),tag)))
    recovered=[]
    for secret in tab:
        ls=lookup_leaves([secret],tab,[int(v==secret) for v in tab],a,tag)
        rr,_=tree(ls)
        witness_den=ref_product(rr[1],ref_inverse(table_product))
        recovered_value=sub(sub(a,tag),witness_den)
        assert recovered_value==scalar(secret)
        recovered.append(secret)
    controls['unmasked_denominator_root_discloses_single_lookup']=recovered==tab
    # Publishing a helper sum in this one-value setting also discloses it.
    hs=direct_sum([(O,sub(a,add(scalar(2),tag)))])
    controls['unmasked_helper_sum_discloses_single_lookup']=sub(sub(a,tag),ref_inverse(hs))==scalar(2)
    assert all(controls.values()),controls
    result=dict(status='passed',run_identity='20260926T235233Z-5f465072',seed=SEED,
        field='Goldilocks Fp2, u^2=7',lengths=[1,2,3,8,32],fraction_cases=cases,
        independent_mle_checks=points,lookup_identities=lookup_cases,negative_controls=controls,
        differential_digest=digest.hexdigest(),costs=costs(),threads=1,
        affinity=sorted(os.sched_getaffinity(0)),cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
        platform=platform.platform(),python=platform.python_version(),estimated_memory_mib=32,
        enforced_limits=dict(wall_s=59,cpu_s=55,address_space_mib=512),
        elapsed_s=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        proving_s=None,verification_s=None,complete_readiness_s=None,native_compiled=False,gpu_executed=False,
        limits=['Algebra and synthetic information disclosure, not a GKR proof',
                'No transcript, RNG, native rejection parity, PCS or joint-view validation',
                'Memory counts exclude GKR scratch, masks, bindings, other live commitments and allocator overhead',
                'Full-tree operation counts include all padding; not timings or lower bounds for an optimized design'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':run()
