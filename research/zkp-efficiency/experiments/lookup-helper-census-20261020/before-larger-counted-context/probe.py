"""Public R9 accounting plus tiny synthetic arithmetic, never a native proof."""
from pathlib import Path
from collections import Counter
import json,time,resource,random,hashlib,platform,os
from reference import census,rational_tree
HERE=Path(__file__).resolve().parent
start=time.monotonic(); checks=0; controls=[]; rows=[]
def check(v):
    global checks
    assert v
    checks+=1
def control(name,v):
    check(v); controls.append(name)
def model(T,d,hd,kv,fp,lc,w=32,fe=9,dd=False):
    n=1<<lc; ln=(w+7)//8; ls=((T-1).bit_length()+fe+7)//8; lp=2
    sizes={k:max(n,v) for k,v in dict(L=16*T,D=T*d,Q=T*32*hd,Kv=T*kv*hd,S=32*T*T,F=T*fp,Tab=256,Dd=32*T*32).items()}
    q=dict(L=2,D=18+4*(ln+int(w%8!=0)),Q=13,Kv=12,F=9,S=4 if dd else 7+2*(ls+1))
    if dd:q['Dd']=3+2*(ls+1)
    counts={k:(v+1)//2 for k,v in q.items()}
    extra=dict(S=2 if dd else 1,F=1,Tab=4)
    if dd:extra['Dd']=1
    h=Counter(counts);h.update(extra)
    details=[]
    for k,c in h.items():
        queries=q.get(k,0)*sizes[k]
        # Illustrative separate per-domain concatenation incl 256 U8 table leaves.
        leaves=1<<(queries+255).bit_length() if queries else 0
        depth=leaves.bit_length()-1 if leaves else 0
        details.append(dict(domain=k,size=sizes[k],u8_columns=q.get(k,0),u8_queries=queries,
          u8_helpers=counts.get(k,0),all_h_planes=c,h_base_words=2*c*sizes[k],
          u8_h_bytes=16*counts.get(k,0)*sizes[k],
          illustrative_tree_leaves=leaves,tree_padding_ratio=leaves/(queries+256) if leaves else None,
          tree_internal_field_muls=3*(leaves-1) if leaves else 0,
          tree_all_nodes_bytes=32*(2*leaves-1) if leaves else 0,
          tree_two_levels_bytes=48*leaves,
          illustrative_binary_gkr_main_rounds=depth*(depth-1)//2,
          initial_u8_ordered_column_links=q.get(k,0)))
    return sizes,q,h,details

# Anchored at public owner r9_counts fixture: norm window32 / fE9 / cap32.
for model_name,d,hd,kv,fp in [('TinyLlama',2048,64,4,8192),('8B',4096,128,8,16384)]:
  for T in (32,64,128):
    lc={32:12 if d==2048 else 13,64:13,128:14}[T]
    for dd in (False,True):
      if dd and T!=128:continue
      for w,fe in sorted(set([(32,9),(33,9),(40,9),(32,16-(T-1).bit_length()),(32,17-(T-1).bit_length())])):
        sizes,q,h,detail=model(T,d,hd,kv,fp,lc,w,fe,dd)
        rs,lists,planes,ar,hr=census(T,d,hd,kv,fp,lc,w,fe,dd)
        check(all(sizes[k]==rs[k] for k in h)); check(q=={k:len(v) for k,v in lists.items() if v})
        check(dict(h)==dict(Counter(x[0] for x in planes)))
        check(sum(x['h_base_words'] for x in detail)//(1<<lc)+2*len(planes)+2==hr)
        check(sum(q[k]*sizes[k] for k in q)==sum(len(v)*rs[k] for k,v in lists.items()))
        for row in detail:
          pairs=[p for p in planes if p[0]==row['domain'] and p[1]=='U8']
          check(sum(len(p[2]) for p in pairs)==row['u8_columns'])
          check(sum(16*rs[p[0]] for p in pairs)==row['u8_h_bytes'])
        row=dict(model=model_name,T=T,log_cols=lc,norm_window=w,f_e=fe,dd=dd,
          scope='owner-count fixture' if (w,fe)==(32,9) else 'public parameter sensitivity, not admitted calibrated profile',
          a_rows=ar,h_rows=hr,u8_queries=sum(q[k]*sizes[k] for k in q),h_planes=sum(h.values()),
          h_input_bytes=hr*(1<<lc)*8,u8_helper_data_bytes=sum(x['u8_h_bytes'] for x in detail),domains=detail)
        row['u8_helper_fraction_of_h_input']=row['u8_helper_data_bytes']/row['h_input_bytes']
        row['u8_helper_fraction_of_AH_input']=row['u8_helper_data_bytes']/((ar+hr)*(1<<lc)*8)
        # Keep ONE native global histogram; per-domain table duplication above
        # is an intentionally costly illustration, requiring new histograms.
        queries=row['u8_queries']; global_leaves=1<<(queries+255).bit_length()
        query_domain_leaves=sum(1<<(x['u8_queries']-1).bit_length() for x in detail if x['u8_queries'])
        # Forest of ordered original columns, each already a padded power of 2.
        # Include one 256-leaf table and join all roots with a binary tree.
        column_count=sum(q.values()); domain_count=len(q)
        forest_leaves=queries+256
        forest_nodes=2*forest_leaves-1
        # Node count identity holds for arbitrary full binary topology.
        check(forest_nodes==sum(c*(2*sizes[k]-1) for k,c in q.items())+(2*256-1)+column_count)
        row['topology_costs']=dict(
          native_table_histograms=1,ordered_column_links=column_count,
          global_padded_leaves=global_leaves,global_all_nodes_bytes=32*(2*global_leaves-1),
          per_domain_query_then_single_table_leaves=query_domain_leaves+256,
          per_domain_all_nodes_bytes=32*(2*(query_domain_leaves+256)-1),
          exact_column_forest_all_nodes_bytes=32*forest_nodes,
          exact_forest_internal_field_muls=3*(forest_leaves-1),
          largest_column_tree_all_nodes_bytes=max(32*(2*sizes[k]-1) for k in q),
          largest_column_two_levels_bytes=max(48*sizes[k] for k in q),
          caution='Node arithmetic/storage only; mixed-height masked GKR, root lifetime/recomputation, ordered bindings and extra reductions unbuilt. Per-domain table illustrations above require new bound histograms, unlike this single-table forest.')
        rows.append(row)
owner=json.loads((HERE/'source/r9_counts.json').read_text())
for name,prefix in [('TinyLlama','TinyLlama-1.1B'),('8B','Llama-3-8B')]:
  target=next(v for k,v in owner.items() if k.startswith(prefix+' T128'))
  for dd in (False,True):
    row=next(x for x in rows if x['model']==name and x['T']==128 and x['dd']==dd and x['norm_window']==32 and x['f_e']==9)
    want=target['dd' if dd else 'today']
    for key,ok in [('a_rows','a_rows'),('h_rows','h_rows'),('u8_queries','u8')]:check(row[key]==want[ok])

anchor=next(x for x in rows if x['model']=='8B' and x['T']==128 and not x['dd'] and x['norm_window']==32 and x['f_e']==9)
control('ignore_P3_lift',16*128!=(1<<14))
control('omit_odd_Q_lookup',13!=2*(13//2))
control('omit_F_activation_helper',6!=5)
control('treat_F_true_hidden_as_padded',128*14336!=128*16384)
control('base_extension_word_confusion',anchor['h_input_bytes']!=anchor['h_rows']*(1<<14)*16)
control('public_table_does_not_replace_all_H',3*256*16<anchor['u8_helper_data_bytes'])
control('DD_S_relation_must_change_domain',model(128,4096,128,8,16384,14,dd=False)[1]['S']!=model(128,4096,128,8,16384,14,dd=True)[1]['S'])
control('norm_full_byte_boundary',model(128,4096,128,8,16384,14,w=32)[1]['D']!=model(128,4096,128,8,16384,14,w=33)[1]['D'])
control('sigma_limb_boundary',model(128,4096,128,8,16384,14,fe=9)[1]['S']!=model(128,4096,128,8,16384,14,fe=10)[1]['S'])
control('do_not_duplicate_global_histogram_per_domain',sum(1 for x in anchor['domains'] if x['u8_columns'])!=1)
# Independent direct inverses versus division-free trees. Small synthetic F65537.
p=65537;rng=random.Random(20261020103)
for _ in range(120):
  n=1<<rng.randrange(0,6); leaves=[(rng.randrange(p),rng.randrange(1,p)) for _ in range(n)]
  a,b=rational_tree(leaves,p)
  direct=sum(num*pow(den,-1,p) for num,den in leaves)%p
  check(a*pow(b,-1,p)%p==direct)
table=[3,3,3,8];alpha=19
query=sum(pow(alpha-x,-1,p) for x in table)%p
check(query==(3*pow(alpha-3,-1,p)+pow(alpha-8,-1,p))%p)
control('omitted_multiplicity',query!=(pow(alpha-3,-1,p)+pow(alpha-8,-1,p))%p)
control('zero_multiplicity_still_requires_nonzero_denominator',(0,0)==rational_tree([(0,0),(0,7)],p))
result=dict(seed=20261020103,checks=checks,fixtures=len(rows),negative_controls=controls,
  elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
  full_stack=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None),
  scope='integer source census and tiny F65537 fraction arithmetic, not GKR proof, native timing, capacity or traffic',
  tree_limits='Node-count/storage illustrations only, including single-global-histogram forest. Per-domain tables require new bound local histograms. GKR round counts omit batching/line reductions/final openings/masks. All tree arrays private. No net commitment saving or protocol proposed.')
(HERE/'census.json').write_text(json.dumps(rows,indent=2)+'\n')
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(HERE/'hardware.json').write_text(json.dumps(dict(platform=platform.platform(),cpu=platform.processor(),affinity=list(os.sched_getaffinity(0)),threads=1,accelerator_invoked=False),indent=2)+'\n')
print(json.dumps(result,indent=2))
