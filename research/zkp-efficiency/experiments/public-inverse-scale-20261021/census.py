"""Source-backed fixed-scale incidence and explicit synthetic batch budgets."""
from pathlib import Path
import hashlib,json,math,re,resource,time
HERE=Path(__file__).resolve().parent

def run():
    start=time.monotonic();checks=0;sites=[]
    def ck(x):
        nonlocal checks
        assert x;checks+=1
    pins=json.loads((HERE/'source-pins.json').read_text())
    for pin in pins:
        ck(hashlib.sha256((HERE/pin['copy']).read_bytes()).hexdigest()==pin['sha256'])
    for scope in ['r9','active','gpu-owner']:
        root=HERE/'source'
        cpu=(root/(scope+'__zkp-core__src__ntt.rs')).read_text()
        field=(root/(scope+'__zkp-core__src__field.rs')).read_text()
        gpu=(root/(scope+'__hashline__src__gpu__cuda.rs')).read_text()
        kernels=(root/(scope+'__hashline__src__gpu__kernels.cu')).read_text()
        for text,fragment in [(cpu,'let ninv = Fp::new(n).inv();'),(cpu,'*v = v.mul(ninv);'),
           (field,'self.pow(P - 2)'),(field,'base = base.square();'),
           (field,'pub const P: u64 = 0xFFFF_FFFF_0000_0001;'),
           (field,'pub const TWO_ADICITY: u32 = 32;'),
           (gpu,'self.ntt_rows_view(data, coef, rows, n, log_n, true)?;'),
           (gpu,'for &(r0, rc) in &plan {'),
           (kernels,'if (last && scale != 1ULL) v = gl_mul(v, scale);'),
           (kernels,'if (scale != 1ULL) v = gl_mul(v, scale);')]:ck(fragment in text)
        # Inventory definitions, not dynamic execution counts or a Rust AST.
        last_fn='';scope_sites=[]
        for i,line in enumerate(gpu.splitlines(),1):
            if re.match(r'\s*(?:pub(?:\([^)]*\))?\s+)?fn\s+',line):
                last_fn=re.search(r'fn\s+(\w+)',line).group(1)
            if 'Fp::new(1u64 << log_n).inv().0' in line:
                scope_sites.append(dict(scope=scope,line=i,function=last_fn,
                                        unit='one host inverse per invocation with inverse=true, not per row',
                                        definition_kind='benchmark' if last_fn=='reenc_bench_at' else 'device wrapper'))
        ck(len(scope_sites)==6);sites.extend(scope_sites)
    rows=[];exponent=18446744069414584319
    # Source pow has 64 squares including the last, plus 63 accumulator muls.
    inv_ops=exponent.bit_length()+exponent.bit_count();ck(inv_ops==127)
    for log_n in [0,1,8,12,13,14,16,24,32]:
        n=1<<log_n
        for batch_rows in [1,32,128,4096]:
            for chunk_rows in [1,32,128,4096]:
                batches=(batch_rows+chunk_rows-1)//chunk_rows
                cpu_inv=batch_rows;gpu_inv=batches
                inverse_butterfly=n*log_n//2
                cpu_scale=n
                # For these synthetic examples: rate4, q256 only when n>=256.
                q=min(n,256);nn=4*n
                expanded_butterfly=nn*(log_n+2)//2
                one_cpu_encode_mul=inv_ops+inverse_butterfly+cpu_scale+(n+q)+expanded_butterfly
                r=dict(log_n=log_n,message_n=n,rows=batch_rows,chunk_rows=chunk_rows,
                       geometry_scope='Algebraic count only; no device/profile admission. Device wrapper limit <=24; log0/32 are boundary diagnostics.',
                       row_batches=batches,cpu_inverse_calls=cpu_inv,device_host_inverse_calls=gpu_inv,
                       cpu_scale_multiplies_unchanged=batch_rows*n,
                       device_scale_multiplies_unchanged=(batch_rows*n if log_n else 0),
                       cpu_removed_source_muls=cpu_inv*inv_ops,device_host_removed_source_muls=gpu_inv*inv_ops,
                       cpu_inverse_only_multiply_share=inv_ops/(inv_ops+inverse_butterfly+cpu_scale),
                       cpu_complete_row_encode_multiply_share=inv_ops/one_cpu_encode_mul,
                       cpu_complete_row_encode_multiply_speed_ratio=one_cpu_encode_mul/(one_cpu_encode_mul-inv_ops),
                       removed_device_launches=0,removed_device_transfers=0,removed_device_bytes=0)
                ck(gpu_inv<=cpu_inv);ck(r['removed_device_bytes']==0)
                rows.append(r)
    # Prior source-derived commit offers: do not convert these into actual
    # launches. Each admitted event still needs actual rows/chunk/fallback clocks.
    prior=json.loads((HERE/'source/prior__public-ntt-cache-incidence-20261020__trace-ledger.json').read_text())
    schedules=[]
    for x in prior:
        if x['cached'] or x['deferred'] or x['evict_per_pass']:continue
        offered=x['device_offered_requests']
        ck(offered==x['passes']*(3*x['layers']+1))
        schedules.append(dict(context=x['tokens'],layers=x['layers'],passes=x['passes'],
            hypothetical_resident_commit_inverse_calls=offered,
            hypothetical_removed_host_muls=offered*inv_ops,
            scope='Conditional one accepted resident commit per offered event; openings/fallback/extra CPU transforms excluded; not observed launches'))
    controls=[]
    def control(name,predicate):
        ck(predicate);controls.append(dict(name=name,detected=True))
    control('per-row GPU inversion count is wrong',next(x for x in rows if x['log_n']==14 and x['rows']==4096 and x['chunk_rows']==4096)['device_host_inverse_calls']==1)
    control('one inverse per entire chunked commitment is wrong',next(x for x in rows if x['log_n']==14 and x['rows']==4096 and x['chunk_rows']==1)['device_host_inverse_calls']==4096)
    control('mutated modulus pin rejected','pub const P: u64 = 0xFFFF_FFFF_0000_0001;' not in field.replace('0xFFFF_FFFF_0000_0001','17'))
    control('mutated inversion algorithm rejected','self.pow(P - 2)' not in field.replace('self.pow(P - 2)','Fp::ONE'))
    control('mutated normalization store rejected','if (last && scale != 1ULL) v = gl_mul(v, scale);' not in kernels.replace('if (last && scale != 1ULL) v = gl_mul(v, scale);','v = v;'))
    result=dict(status='PASS',checks=checks,source_definitions=sites,synthetic_batch_cases=len(rows),
                conditional_commit_schedules=len(schedules),negative_controls=controls,
                table_bytes=33*8,closed_form_table_bytes=0,
                wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                scope='Source arithmetic/incidence counts; CPU multiply shares are not elapsed shares and compare no host arithmetic to device arithmetic. No full-proof rate ceiling measured.')
    (HERE/'batch-ledger.json').write_text(json.dumps(rows,indent=2)+'\n')
    (HERE/'schedule-ledger.json').write_text(json.dumps(schedules,indent=2)+'\n')
    (HERE/'census-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':run()
