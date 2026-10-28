"""Source-backed schedules and conditional traffic, not elapsed time."""
from pathlib import Path
import itertools,json,resource,time
import tail
H=Path(__file__).resolve().parent
def main():
    start=time.monotonic();rows=[];checks=0
    for n,th,k,d,f,s,m,p in itertools.product((1,2,3,5,6,8,9,10,11,18,21,26),(0,5,8,10),(20,21),(4,5),(False,True),(False,True),(False,True),(False,True)):
        for candidate in (False,True):
            r=tail.schedule(n,th,k,d,f,s,m,p,candidate)
            assert r['host_rounds']+r['gpu_rounds']==n;checks+=1
            # Closed-form logical handoff length, independent of deferred physical stride.
            h=min(th,n-1) if th else 0
            assert r['host_rounds']==h;checks+=1
            assert r['boundary_copy_bytes']==(16*k*(1<<h) if h else 0);checks+=1
            assert r['host_pairs']==(1<<h)-1;checks+=1
            assert r['host_fold_outputs']==k*((1<<h)-1);checks+=1
            r['host_parallel_regions']=sum(e['kind']=='host_round' and e['half']>64 for e in r['events'])
            # Mapped messages still traverse system memory; explicit-copy count excludes them.
            r['mapped_result_store_bytes']=r['gpu_rounds']*(16*(d+1)+8) if s and m else 0
            r['tail_counter_reported_bytes']=r['boundary_copy_bytes']
            r['boundary_logical_bytes']=sum(e.get('logical_bytes',0) for e in r['events'] if e['kind'] in ('fold_pack','pack') or e['kind']=='gpu_fold' and any(x['kind']=='tail_copy' and x['round']==e['round'] for x in r['events']))
            r['events']=None;rows.append(r)
    example=[r for r in rows if r['n']==21 and r['k']==21 and r['degree']==5 and r['fused'] and r['split'] and r['mapped'] and not r['profile']]
    # Existing layout retained throughout the CPU tail; no live arena release is implied.
    for r in example:
        r['device_table_request_bytes_retained_until_drop']=16*r['kd']*(1<<r['n'])
        r['free_removal_end_to_end_ceiling']='1/(1-f_boundary), exclusive boundary time f unknown; this removes only part'
    result=dict(status='PASS_COUNT_MODEL_ONLY',checks=checks,schedules=len(rows),wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,scope='12 n values, four thresholds, both k/degree/fused/split/mapped/profile choices, baseline/candidate; no actual runtime incidence or CUDA clocks')
    for name,data in [('census-result.json',result),('schedules.json',rows),('illustrative-f21.json',example)]: (H/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(result));print(json.dumps(example,indent=2))
if __name__=='__main__':main()
