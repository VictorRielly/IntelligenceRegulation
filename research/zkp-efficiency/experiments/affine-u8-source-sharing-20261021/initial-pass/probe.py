"""Independent original affine table-membership comparison; synthetic only."""
import copy, hashlib, itertools, json, pathlib, random, resource, time
import candidate as c
import native_reference as ref

ROOT=pathlib.Path(__file__).resolve().parent
SEED=202610210122; rng=random.Random(SEED); t0=time.monotonic()
checks=0; controls=[]; descriptor_cases=0; enumerated=0; family_count=0
def check(ok):
    global checks
    checks+=1
    if not ok: raise AssertionError(checks)
def control(name, ok):
    check(ok); controls.append(name)

for T in (32,64,128,256,512):
    for dd in (False,True):
        manual=c.catalog(T,dd); native=ref.native_expressions(T,dd)
        check(manual==native); descriptor_cases+=sum(map(len,native.values()))
        for dom,exprs in native.items():
            reduced,aliases=c.dedup(exprs)
            expected_aliases=2 if T==128 and dom==('Dd' if dd else 'S') else 0
            check(len(aliases)==expected_aliases)
            check(len(exprs)-len(reduced)==len(aliases))
            for g in c.groups(exprs):
                family_count+=1
                local=[exprs[i] for i in g['ordinals']]
                reduced_local=c.dedup(local)[0]
                allowed=ref.allowed_residues(local)
                represented=set()
                for bits in itertools.product((0,1), repeat=g['width']):
                    x=(sum(b*2**i for i,b in enumerate(bits))-g['offset'])%c.P
                    accepted=c.check_bits(g,x,bits)
                    check(accepted==ref.accepts(local,x))
                    if accepted: represented.add(x)
                    enumerated+=1
                check(represented==allowed)
                samples=set(range(300))|{(c.P-i)%c.P for i in range(1,301)}
                samples|={rng.randrange(c.P) for _ in range(8)}
                for x in samples:
                    got=c.check_bits(g,x,c.bits_for(g,x))
                    check(got==ref.accepts(local,x))
                    check(ref.accepts(local,x)==ref.accepts(reduced_local,x))

signed={'source':'signed','ordinals':[0,1],'width':8,'offset':127,'forbid255':True}
plain={'source':'plain','ordinals':[0],'width':8,'offset':0,'forbid255':False}
scaled={'source':'scaled','ordinals':[0,1],'width':7,'offset':0,'forbid255':False}
for x in (-128,128):
    control('signed_endpoint_'+str(x),not c.check_bits(signed,x,c.bits_for(signed,x)))
control('dropping_signed_endpoint_guard_accepts_128',c.check_bits(signed,128,[1]*8,endpoint=False))
control('signed_minus127_accepted',c.check_bits(signed,-127,[0]*8))
control('signed_plus127_accepted',c.check_bits(signed,127,[0]+[1]*7))
control('negative_source_not_unsigned_byte',not c.check_bits(plain,c.P-1,[1]*8))
control('nonboolean_bits_refused',not c.check_bits(plain,2,[2]+[0]*7))
control('without_booleanity_fake_bits_pass',c.check_bits(plain,2,[2]+[0]*7,boolean=False))
control('without_source_link_256_passes',c.check_bits(plain,256,[0]*8,link=False))
control('source_link_refuses_256',not c.check_bits(plain,256,[0]*8))
control('scaled128_refused',not c.check_bits(scaled,128,[0]*7))
control('drop_scaled_pin_accepts128',c.check_bits(plain,128,c.bits_for(plain,128)))
half=(c.P+1)//2
control('scaled_only_field_alias_passes',(2*half)%c.P in range(256) and half not in range(256))
control('base_source_link_refuses_scaled_field_alias',not c.check_bits(scaled,half,c.bits_for(scaled,half)))
control('zero_source_signed_padding_requires_127',c.check_bits(signed,0,c.bits_for(signed,0)))
control('zeroed_signed_bit_padding_is_wrong',not c.check_bits(signed,0,[0]*8))
control('padding_source_must_remain_zero',c.check_bits(signed,1,c.bits_for(signed,1)) and 1!=0)
gg=[dict(plain,source='A'),dict(plain,source='B')];values={'A':3,'B':5}
bundle=[(g['source'],c.bits_for(g,values[g['source']])) for g in gg]
check(c.check_bundle(gg,values,bundle))
control('ordered_source_labels_refuse_swap',not c.check_bundle(gg,values,list(reversed(bundle))))
control('source_values_refuse_bit_swap',not c.check_bundle(gg,values,[('A',bundle[1][1]),('B',bundle[0][1])]))
control('dropping_source_bundle_refused',not c.check_bundle(gg,values,bundle[:1]))
control('duplicate_source_bundle_refused',not c.check_bundle(gg,values,[bundle[0],bundle[0]]))

# A same-domain exact alias is removable from BOTH query and table sides,
# but changing only one side's multiplicities fails the rational identity.
exprs=ref.native_expressions(128,False)['S'];reduced,aliases=c.dedup(exprs)
groups=c.groups(exprs);src={g['source']:rng.choice(tuple(ref.allowed_residues([exprs[i] for i in g['ordinals']]))) for g in groups}
def query_values(es):return [(e['cst']+sum(src[n]*a for n,a in e['terms']))%c.P for e in es]
old=query_values(exprs);new=query_values(reduced)
def hist(xs):return [xs.count(v) for v in range(256)]
alpha=1000
invs=[pow((alpha-v)%c.P,-1,c.P) for v in range(256)]
def lhs(xs):return sum(invs[x] for x in xs)%c.P
def rhs(h):return sum(n*inv for n,inv in zip(h,invs))%c.P
check(lhs(old)==rhs(hist(old)));check(lhs(new)==rhs(hist(new)))
control('stale_histogram_after_dedup_refused',lhs(new)!=rhs(hist(old)))
control('old_query_after_histogram_dedup_refused',lhs(old)!=rhs(hist(new)))
control('missing_unqueried_table_denominator_still_refuses',17 not in new and any((17-v)%c.P==0 for v in range(256)))
control('cross_source_identical_value_is_not_public_alias',c.dedup([{'terms':[['A',1]],'cst':0},{'terms':[['B',1]],'cst':0}])[1]==[])
control('signed_symmetric_pair_not_an_alias',c.dedup([{'terms':[['A',1]],'cst':127},{'terms':[['A',-1]],'cst':127}])[1]==[])

census=json.loads((ROOT/'prior-prior-census.json').read_text());costs=[]
for row in census:
    if row['model']!='8B' or row['T'] not in (128,512) or row['norm_window']!=32 or row['f_e']!=9:continue
    T,dd=row['T'],row['dd'];cat=c.catalog(T,dd);domains=[];bits_bytes=0;query_bytes=0;helper_saved=0;old_h=0
    for d in row['domains']:
        dom=d['domain'];es=cat.get(dom,[])
        if not es:continue
        n=d['size'];gs=c.groups(es);red,aliases=c.dedup(es)
        width=sum(g['width'] for g in gs);bitbytes=width*n*8
        saved_helpers=(len(es)+1)//2-(len(red)+1)//2
        saved=saved_helpers*n*16
        bits_bytes+=bitbytes;query_bytes+=len(es)*n*8;helper_saved+=saved;old_h+=d['u8_h_bytes']
        domains.append(dict(domain=dom,size=n,queries=len(es),distinct_original_sources=len(gs),
                            source_bit_widths=width,exact_aliases=aliases,bit_data_bytes=bitbytes,
                            native_u8_helper_bytes=d['u8_h_bytes'],dedup_helper_data_saved_bytes=saved,
                            dedup_removed_helper_planes=saved_helpers))
    check(old_h==row['u8_helper_data_bytes'])
    costs.append(dict(model='8B',T=T,dd=dd,scope=row['scope'],domains=domains,
                      native_u8_helper_data_bytes=old_h,source_shared_bit_data_bytes=bits_bytes,
                      dense_shared_bits_over_native=bits_bytes/old_h,
                      per_query_8bit_data_bytes=query_bytes*8,
                      dedup_helper_data_saved_bytes=helper_saved,
                      dedup_native_u8_helper_fraction=helper_saved/old_h,
                      new_private_mask_words=None,new_PCS_groups=None,new_CFS_coefficients=None,
                      end_to_end_time_saving=None,physical_peak_saving=None))
check(len(costs)==4)
(ROOT/'cost-result.json').write_text(json.dumps(costs,indent=2)+'\n')
result=dict(status='PASS_SYNTHETIC_SEMANTICS_AND_LOGICAL_COST_ONLY',seed=SEED,checks=checks,
            native_descriptor_cases=descriptor_cases,source_family_fixtures=family_count,
            exhaustive_bit_assignments=enumerated,negative_controls=controls,negative_control_types=len(controls),
            measured_script_seconds=time.monotonic()-t0,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            threads=1,estimated_memory_mib=64,new_verified_full_stack_proofs=0,
            private_proof_implemented=False,native_executed=False,
            limits=['Same-researcher independent reference, not external review',
                    'Field range relation tested; native first-refusal/timing equivalence untested',
                    'Padding zero rules remain separately mandatory',
                    'Model arrays symbolic; masks, groups, CFS and launch costs unknown',
                    'Dedup changes transcript/layout and requires profile review; no accepted proof changed'])
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result));print(json.dumps([{k:v for k,v in x.items() if k!='domains'} for x in costs]))
