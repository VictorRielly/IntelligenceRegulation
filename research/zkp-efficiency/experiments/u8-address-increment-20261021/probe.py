import copy, json, math, pathlib, random, resource, time
import candidate as c
import reference as r

ROOT = pathlib.Path(__file__).resolve().parent
SEED = 202610210121
rng = random.Random(SEED)
checks = 0
controls = []
t0 = time.monotonic()


def check(ok):
    global checks
    assert ok
    checks += 1


def refuse(name, function):
    try:
        function()
    except (ValueError, TypeError):
        controls.append(name)
        check(True)
    else:
        raise AssertionError(name)


def source(values):
    return [(('D' if i % 2 else 'F', i//8, i), q) for i, q in enumerate(values)]


fixtures = 0
mle_cases = 0
for case in range(128):
    n = 1 << (case % 6)
    values = [rng.randrange(256) for _ in range(n)]
    if case == 3:
        values = [0, 255, 17, 17, 128, 0, 255, 64]
    src = source(values)
    table = [rng.randrange(c.P) for _ in range(256)]
    out, hist, before = r.direct(src, table)
    matrix = r.dense(src)
    check(r.matrix_valid(src, matrix))
    trace, got_hist = c.events(src)
    check(c.check_events(src, trace, got_hist))
    check(got_hist == hist)
    check([e[2] for e in trace] == before)
    check([e[3] for e in trace] == [x+1 for x in before])
    bits = c.make_bits(src)
    check(c.check_bits(src,bits))
    check([sum(b*2**j for j,b in enumerate(bs)) for _,bs in bits] == values)
    if case < 48:
        ap = [rng.randrange(c.P) for _ in range(8)]
        tp = [rng.randrange(c.P) for _ in range(int(math.log2(n)))]
        want_mle = r.dense_mle(matrix, ap, tp)
        check(c.sparse_mle(src, ap, tp) == want_mle)
        check(c.bits_mle(bits, ap, tp) == want_mle)
        mle_cases += 1
    for d in (1, 2, 4, 8):
        fs = c.make_factors(src, d)
        check(c.check_factors(src, fs, d))
        expanded = r.expand(fs, d)
        check(expanded == matrix)
        check([sum(x*v for x, v in zip(row, table)) % c.P for row in expanded] == out)
        check([sum(row[a] for row in expanded) for a in range(256)] == hist)
        if case < 48:
            check(c.factored_mle(fs, d, ap, tp) == want_mle)
        fixtures += 1

src = source([1, 7, 1, 255, 0, 9, 7, 128])
ddsrc=[(('Dd',0,0),255)]
check(c.check_factors(ddsrc,c.make_factors(ddsrc,2),2))
check(c.check_bits(ddsrc,c.make_bits(ddsrc)))
trace, hist = c.events(src)
refuse('drop_query', lambda: c.check_events(src, trace[:-1], hist))
dup = trace.copy(); dup[1] = dup[0]
refuse('duplicate_query_site', lambda: c.check_events(src, dup, hist))
bad = trace.copy(); site, q, b, a = bad[0]; bad[0] = (site, 256, b, a)
refuse('out_of_range_event', lambda: c.check_events(src, bad, hist))
bad = trace.copy(); site, q, b, a = bad[2]; bad[2] = (site, q, 0, 1)
refuse('reset_repeated_address_count', lambda: c.check_events(src, bad, hist))
bad = trace.copy(); site, q, b, a = bad[0]; bad[0] = (site, q, b, a+1)
refuse('skip_increment', lambda: c.check_events(src, bad, hist))
bad_hist = hist.copy(); bad_hist[1] -= 1; bad_hist[2] += 1
refuse('tampered_histogram_same_total', lambda: c.check_events(src, trace, bad_hist))
bad_hist = hist.copy(); bad_hist[0] = True
refuse('boolean_is_not_integer_count', lambda: c.check_events(src, trace, bad_hist))
badsrc = src.copy(); badsrc[1] = badsrc[0]
refuse('duplicate_original_source_site', lambda: c.events(badsrc))
refuse('noncanonical_negative_source', lambda: c.events(source([-1])))
refuse('noncanonical_field_alias', lambda: c.events(source([c.P+1])))
refuse('out_of_range_source', lambda: c.events(source([256])))
refuse('unknown_source_domain', lambda: c.events([(('private-payload',0,0),1)]))
permuted = src.copy(); permuted[0] = (src[0][0],src[1][1]); permuted[1] = (src[1][0],src[0][1])
pt, ph = c.events(permuted)
check(ph == hist)
controls.append('histogram_only_accepts_wrong_order')
refuse('ordered_link_refuses_histogram_preserving_permutation', lambda: c.check_events(src, pt, ph))
for d in (1, 2, 4, 8):
    fs = c.make_factors(src, d)
    bad = copy.deepcopy(fs); f = bad[0][1][0]; f[0] = 2
    refuse('nonboolean_factor_d'+str(d), lambda: c.check_factors(src, bad, d))
    bad = copy.deepcopy(fs); bad[0][1][0][:] = [0]*len(bad[0][1][0])
    refuse('zero_factor_d'+str(d), lambda: c.check_factors(src, bad, d))
    bad = copy.deepcopy(fs); bad[0][1][0][0] = 1
    refuse('two_hot_factor_d'+str(d), lambda: c.check_factors(src, bad, d))
    bad = c.make_factors(permuted,d)
    refuse('factor_original_source_link_d'+str(d), lambda: c.check_factors(src,bad,d))
    bad = copy.deepcopy(fs); bad[0] = (('D',99,99),bad[0][1])
    refuse('factor_wrong_site_d'+str(d), lambda: c.check_factors(src,bad,d))
    refuse('factor_missing_query_d'+str(d), lambda: c.check_factors(src,fs[:-1],d))

# Sum-one plus address consistency alone is insufficient without Booleanity.
for q in (2, 17, 255, 256):
    row = [(1-q) % c.P, q] + [0]*254
    check(r.matrix_valid(source([q]),[row],require_bool=False))
    check(not r.matrix_valid(source([q]),[row]))
controls.append('sum_and_address_without_booleanity_accept_out_of_range')
# Small-characteristic caveat is explicit, never transferred to Goldilocks.
row = [1]*252+[0]*4
check(r.matrix_valid(source([0]),[row],p=251,field_guard=False))
check(not r.matrix_valid(source([0]),[row],p=251))
refuse('unsupported_small_characteristic', lambda: c.make_factors(source([0]),1,p=251))
controls.append('small_characteristic_252_hot_counterexample')
# A fixed time point can miss changes; testing a point is not a proof.
a = source([1,7]); b = source([1,9]); ap = [3]*8
check(c.sparse_mle(a,ap,[0]) == c.sparse_mle(b,ap,[0]))
check(c.sparse_mle(a,ap,[1]) != c.sparse_mle(b,ap,[1]))
controls.append('single_fixed_mle_point_is_not_ordered_binding')
check(r.matrix_valid(src,r.dense(permuted),require_order=False))
check(not r.matrix_valid(src,r.dense(permuted)))
controls.append('one_hot_without_ordered_address_link_accepts_permutation')
bits=c.make_bits(src)
bad=copy.deepcopy(bits);bad[0][1][0]=2
refuse('complement_bits_nonboolean',lambda:c.check_bits(src,bad))
refuse('complement_bits_source_permutation',lambda:c.check_bits(src,c.make_bits(permuted)))
refuse('complement_bits_dropped_query',lambda:c.check_bits(src,bits[:-1]))
refuse('complement_bits_cannot_represent_256',lambda:c.check_bits(source([256]),c.make_bits(source([0]))))
controls.append('complements_virtualized_without_new_committed_zero_columns')
# Evaluating each factor at a shared NON-Boolean time and multiplying is wrong:
# the multilinear extension of a product is not the product of the extensions.
mixsrc=source([0,255]); ap=[3]*8; tp=[2]
for d in (2,4,8):
    fs=c.make_factors(mixsrc,d)
    naive=1
    for k in range(d):
        point=ap[k*(8//d):(k+1)*(8//d)]
        factor_eval=sum(c.basis(t,tp)*sum(v*c.basis(a,point) for a,v in enumerate(factors[k]))
                        for t,(_,factors) in enumerate(fs)) % c.P
        naive=naive*factor_eval % c.P
    check(naive != r.dense_mle(r.dense(mixsrc),ap,tp))
    check(c.factored_mle(fs,d,ap,tp)==r.dense_mle(r.dense(mixsrc),ap,tp))
    controls.append('product_of_factor_mles_needs_extra_reduction_d'+str(d))

census = json.loads((ROOT/'prior-census.json').read_text())
costs = []
for entry in census:
    if entry['model'] != '8B' or entry['T'] not in (128,512):
        continue
    if entry['norm_window'] != 32 or entry['f_e'] != 9:
        continue
    n = sum(x['size']*x['u8_columns'] for x in entry['domains'])
    baseline = sum(16*x['size']*((x['u8_columns']+1)//2) for x in entry['domains'])
    check(n == entry['u8_queries'])
    check(baseline == entry['u8_helper_data_bytes'])
    for d in (1,2,4,8):
        cost = c.logical_cost(n,d,baseline)
        check(cost['dense_base_words'] == sum(x['size']*x['u8_columns']*d*2**(8//d) for x in entry['domains']))
        check(cost['encoded_payload_bytes'] == cost['dense_data_bytes']*4)
        cost.update(T=entry['T'],dd=entry['dd'],native_u8_helper_data_bytes=baseline,
                    scope=entry['scope'],norm_window=entry['norm_window'],f_e=entry['f_e'],
                    actual_model_execution=False)
        costs.append(cost)
(ROOT/'cost-result.json').write_text(json.dumps(costs,indent=2)+'\n')
result = dict(status='PASS_SYNTHETIC_CONTRACT_AND_COST_ONLY',seed=SEED,checks=checks,
              ordered_sources=128,factored_fixtures=fixtures,virtual_complement_bit_fixtures=128,dense_mle_cases=mle_cases,
              max_queries=32, table_size=256, field='Goldilocks base field',
              negative_control_types=len(set(controls)),controls=controls,
              wall_seconds=time.monotonic()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
              threads=1,estimated_memory_mib=64,new_verified_full_stack_proofs=0,
              native_proof_executed=False,private_proof_protocol=False,
              limits=['References by same researcher, not external review',
                      'Direct validators inspect synthetic private data; not succinct or zero knowledge',
                      'Dense arrays counted symbolically at model dimensions, never allocated',
                      'Sparse MLE formula is only an evaluation oracle; commitment/input consistency unresolved',
                      'Increment state is a contract control, not a Shout implementation or a required lookup cost',
                      'Masks, reduction claims, CFS, PCS groups, padding and launches unpriced, never zero'])
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
