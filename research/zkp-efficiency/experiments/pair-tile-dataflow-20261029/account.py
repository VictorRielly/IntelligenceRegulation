"""Logical source accesses, not physical DRAM or compiler register counts."""
from collections import Counter
from dataclasses import replace
import json,pathlib,resource,time
import model as m
import legacy_catalog as old
HERE=pathlib.Path(__file__).resolve().parent
start=time.monotonic();checks=0
def ck(v,label=''):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def groups(g):
 out=[]
 for slot,ss in enumerate(old.catalog(g)):
  group=[];key=None
  for p in old.schedule(ss):
   k=(p.ext,p.tail)
   if k!=key and group:out.append(group);group=[]
   key=k;group.append(p)
  if group:out.append(group)
 return out
rows=json.loads((HERE/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows']
prior=json.loads((HERE/'startup/research__zkp-efficiency__experiments__current-profile-mask-census-20261029__counts.json').read_text())
cost=[];seen=set()
for row in rows:
 g=m.geometry(row);key=(g.name,row['f_e'])
 if key in seen:continue
 seen.add(key);gs=groups(g);count=sum(len(x)for x in gs)
 M=sum(len(x)*(1<<len(x[0].tail))for x in gs)
 prev=next(x for x in prior if x['profile']==row['profile'] and x['f_e']==row['f_e'])
 ck(count==prev['totals']['sites'],'pairs')
 ck(2*M==prev['totals']['private_base_word_reads'],'private reads')
 ck(len(gs)==prev['totals']['builds'],'consecutive groups/extension phase')
 options=[]
 for K in (1,2,4):
  tiled=sum(((len(x)+K-1)//K)*(1<<len(x[0].tail))for x in gs)
  serial_public=16*M;tiled_public=16*tiled;private=16*M
  options.append(dict(K=K,groups=len(gs),pair_coefficients=M,tile_coefficients=tiled,private_reads_words=2*M,serial_public_read_bytes=serial_public,tiled_public_read_bytes=tiled_public,public_read_bytes_removed=serial_public-tiled_public,public_additions_removed=M-tiled,source_read_byte_ratio=(private+serial_public)/(private+tiled_public),added_sum_buffer_bytes=0,accumulator_payload_bytes=24*K,extra_accumulator_payload_bytes=24*(K-1),accumulator_32bit_scalar_lower_bound=6*K,max_private_streams=2*K,extra_scalar_spill_read_write_break_even_per_full_tile=K-1,note='Read model excludes Eq construction, descriptor/output overhead, all spills and all cache effects; ratios are logical byte ceilings for this dot traversal only.'))
  ck(tiled<=M and tiled>=sum((1<<len(x[0].tail))for x in gs))
 cost.append(dict(profile=row['profile'],tokens=row['tokens'],f_e=row['f_e'],dd=bool(g.dd),pairs=count,group_sizes=dict(Counter(len(x)for x in gs)),options=options))

# Independent literal small-width address trace, with pair identity preserved.
trace_checks=0
for count in (0,1,2,3,4,5,6,17):
 for n in (1,2,8,16):
  serial=Counter((p,side,i)for p in range(count)for i in range(n)for side in (0,1))
  for K in (1,2,4):
   trace=[];eq=0
   for base in range(0,count,K):
    for i in range(n):
     eq+=1
     for p in range(base,min(base+K,count)):
      for side in (0,1):trace.append((p,side,i))
   ck(Counter(trace)==serial,'all fresh private addresses')
   ck(eq==((count+K-1)//K)*n,'Eq load tiles')
   trace_checks+=1

# Rejected scheduling controls: extension phase and point order are part of key.
g=m.geometry(rows[0]);p=old.catalog(g)[0][0]
ck((p.ext,p.tail)!=(p.ext+1,p.tail),'never fuse extension rounds')
q=replace(p,coords=(('different',0),)+p.coords[1:]);ck(p.tail!=q.tail or p.log>p.row,'tail contract')
# Full-tile spill accounting: saving =16*(K-1) bytes per coefficient;
# every spilled extra uint64 accumulator update adds 8-byte load +8-byte store.
for K in (2,4):
 saved=16*(K-1);extra=3*(K-1)
 ck(16*(K-1)==saved,'one spilled accumulator/added pair cancels public load saving')
 ck(16*extra==3*saved,'spilling all extra accumulators costs three times saving')
result=dict(status='PASS',checks=checks,trace_cases=trace_checks,geometries=len(cost),registry_rows=len(rows),elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,grouping_scope='consecutive same full ordered public tail within one slot and same extension phase; exact values required by Rust interface; generic distinct symbolic points assumed',physical_bytes=None,gpu_registers=None,occupancy=None,native_time_saved=None,full_stack_proofs=0,proved_positions=0)
(HERE/'costs.json').write_text(json.dumps(cost,indent=2)+'\n');(HERE/'account-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
for r in cost:
 if r['tokens']==128 and 'llama-3-8b' in r['profile']:print(json.dumps(r))
