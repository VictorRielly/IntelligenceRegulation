"""Separate interval/cost/source audit; no candidate hash implementation import."""
from pathlib import Path
import hashlib,json,resource,time
R=Path(__file__).resolve().parent
start=time.monotonic();checks=0;controls=[]
def check(ok):
    global checks
    checks+=1;assert ok

# Count visits from explicit ranges/levels rather than candidate counters.
for logn in range(12):
    n=1<<logn
    levels=[[(j,j+1) for j in range(n)]]
    reads=64*n;writes=32*n;nodes=0;fused_reads=64*n
    while len(levels[-1])>1:
        p=levels[-1];out=[]
        for j in range(0,len(p),2):
            a,b=p[j:j+2];check(a[1]==b[0]);out.append((a[0],b[1]))
            nodes+=1;reads+=64;writes+=32
            if len(levels)>1:fused_reads+=64
        levels.append(out)
    check(nodes==n-1);check(reads==128*n-64);check(writes==64*n-32)
    check(fused_reads==(64 if n==1 else 96*n-64))
    check(reads-fused_reads==(0 if n==1 else 32*n))
    for j in range(n):
        siblings=[p[(j>>depth)^1] for depth,p in enumerate(levels[:-1])]
        sizes=[b-a for a,b in siblings];check(sizes==[1<<d for d in range(logn)])
        covered={(j,j+1),*siblings}
        ordered=sorted(covered);check(ordered[0][0]==0 and ordered[-1][1]==n)
        check(all(a[1]==b[0] for a,b in zip(ordered,ordered[1:])))

for e in json.loads((R/'source-manifest.json').read_text()):
    check(hashlib.sha256((R/e['snapshot']).read_bytes()).hexdigest()==e['sha256'])
    check(hashlib.sha256(Path(e['path']).read_bytes()).hexdigest()==e['sha256'])
pcs=(R/'source/active-core-pcs.rs').read_text();merkle=(R/'source/active-merkle.rs').read_text()
checks_text=[(pcs,'let pads = rng.fp_vec(rows * q);'),(pcs,'let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();'),
             (pcs,'let tree = MerkleTree::build_keyed(salted, tag.node_key());'),
             (pcs,'cm.tree.path(j)'),(pcs,'if path.len() != depth'),
             (merkle,'levels.push(next);'),(merkle,'hash_pair_keyed(&pair[0], &pair[1], key)'),
             ((R/'source/active-hashtag.rs').read_text(),'pcs salted merkle leaf'),
             ((R/'source/active-hashtag.rs').read_text(),'pcs merkle inner node'),
             ((R/'source/rayon-collect.rs').read_text(),'let (left_r, right_r) = unzip_indexed(pi, left_consumer, right_consumer);'),
             ((R/'source/vec-mod.rs.html').read_text(),'since = <span class="string">"1.80.0"')]
for s,needle in checks_text:check(needle in s)
result=json.loads((R/'result.json').read_text())
check(result['checks']>0 and result['fixtures']==120 and result['path_positions']==3825)
for c in result['cases']:
    n=c['encoded_columns'];cost=c['counts']
    check(cost['salt_calls']+cost['node_calls']==2*n-1)
    check(cost['read_bytes']+cost['write_bytes']==(96 if n==1 else 160*n-96))

costs=[]
counts=json.loads((R/'source/r9-counts.json').read_text())
for label,variants in counts.items():
    if not label.startswith('Llama-3-8B'):continue
    context=128 if 'T128' in label else 512
    n=65536 if context==128 else 131072
    for variant in ['today','dd']:
        for role in ['a','h']:
            rows=variants[variant][role+'_rows']
            blocks=(rows+7)//8;chunks=(rows+127)//128
            col=n*(blocks+chunks-1);salt=n;nodes=n-1
            read=128*n-64;write=64*n-32;fused_read=96*n-64
            # Work only; no hardware timing or concurrent-lifetime claim.
            c=dict(context=context,variant=variant,role=role,rows=rows,encoded_columns=n,
                   column_message_bytes=8*rows*n,column_compressions=col,salt_compressions=salt,node_compressions=nodes,
                   salt_plus_tree_compression_fraction=(salt+nodes)/(col+salt+nodes),
                   salt_tree_logical_read_bytes=read,salt_tree_logical_write_bytes=write,
                   fused_logical_read_bytes=fused_read,fused_logical_write_bytes=write,
                   removed_logical_read_bytes=read-fused_read,retained_tree_bytes=32*(2*n-1),
                   original_digest_download_bytes=32*n,
                   gpu_full_tree_download_bytes=32*(2*n-1),gpu_salts_upload_bytes=32*n,
                   gpu_full_tree_extra_round_trip_bytes=64*n-32,
                   naive_zero_initialized_fusion_extra_write_bytes=48*n,
                   naive_zero_initialized_net_extra_logical_bytes=16*n,
                   full_stack_rate=None,elapsed_saving_s=None,physical_traffic_saving_bytes=None,
                   scope='One frozen R9 A/H commitment; no M/endpoints/other owners/LOW-HIGH/token stages')
            check(c['removed_logical_read_bytes']==32*n)
            check(c['gpu_full_tree_download_bytes']-c['original_digest_download_bytes']+c['gpu_salts_upload_bytes']==c['gpu_full_tree_extra_round_trip_bytes'])
            check(c['naive_zero_initialized_fusion_extra_write_bytes']-c['removed_logical_read_bytes']==c['naive_zero_initialized_net_extra_logical_bytes'])
            costs.append(c)

# Falsifying accounting controls. "One root" is not sufficient path storage;
# no-query root timing excludes later paths. Multiplying by layers counts work,
# not additional tokens. Public domain keys cannot be merged across roles.
for name,wrong,right in [('root_only_as_tree',32,32*(2*65536-1)),
                         ('drop_salt_hashes',65536-1,2*65536-1),
                         ('GPU_full_tree_same_transfer',32*65536,32*(2*65536-1)),
                         ('bytes_fraction_as_time',32*65536/(192*65536-96),None),
                         ('count_tokens_per_layer',128*32,128)]:
    check(wrong!=right);controls.append(name)
out=dict(status='PASS_INDEPENDENT_INTERVAL_COST_SOURCE_AUDIT',checks=checks,
         explicit_tree_sizes=12,max_explicit_leaves=2048,source_pins=len(json.loads((R/'source-manifest.json').read_text())),
         control_types=len(controls),controls=controls,costs=costs,
         diagnostic_wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
         caveat='Audit and candidate authored by same researcher; independent crypto oracle is installed blake3; no native run')
(R/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
(R/'cost-result.json').write_text(json.dumps(costs,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='costs'},indent=2))
