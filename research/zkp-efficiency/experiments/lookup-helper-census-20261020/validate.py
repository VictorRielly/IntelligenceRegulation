"""Source assumptions, independent small tree topology, and negative census audit."""
from pathlib import Path
from collections import Counter
import hashlib,json,time,resource,random
from reference import census,rational_tree
HERE=Path(__file__).resolve().parent; start=time.monotonic(); checks=0
def check(x):
 global checks
 assert x
 checks+=1
pins=json.loads((HERE/'source-manifest.json').read_text())
for p in pins:
 check(hashlib.sha256((HERE/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
 check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
fragments={
 'shape.rs':[
  'self.lookups_per_position(dom).div_ceil(2)',
  'Dom::D => 2 + per_norm + 6 + per_norm + 2 + 4,',
  'Dom::S if self.dd_cap > 0 => 2 + 2,',
  'Dom::F => 9,','Dom::Q => 13,','Dom::Kv => 12,',
  'Dom::S => clog2(self.h_pad * self.t_pad * self.t_pad),',
  'Dom::F => clog2(self.t_pad * self.f_pad),',
  'v.extend(vec![Dom::S; self.helpers(Dom::S) + 1 + usize::from(self.dd_cap > 0)]);',
  'v.extend(vec![Dom::F; self.helpers(Dom::F) + 1]);',
  'v.extend(vec![Dom::Dd; self.helpers(Dom::Dd) + 1]);',
  'v.extend([Dom::Tab; 4]);',
  'let h_data_rows: usize = self.h_plane_doms().iter().map(|d| 2 * self.rows_of(*d)).sum();',
  'h_rows: h_data_rows + 2 * h_sites + 2,',
  'Dom::Tab => U8_LEN,',
  'pub(crate) fn llama3_8b_t128_trained_dd',
 ],
 'layout.rs':[
  'if carries_h_planes && natural < log_n {',
  'pub(crate) const F_P: u32 = 9;',
  'pub(crate) fn lookups_at(sh: &super::shape::Shape, ids: &Ids, dom: Dom) -> Vec<Lk>',
  'v.extend(sym(ids.at(A_Q8)));',
  'v.extend((0..ln).map(|k| byte(ids.nr(k))));',
  'Dom::Dd if sh.dd_cap > 0 => {',
 ],
 'argument.rs':[
  'h.mul(d1).mul(d2).sub(d1.add(d2))',
  'None => h.mul(d1).sub(Fp2::ONE),',
  'b.a(ids.at(A_MU8))?;',
  'b.a(ids.at(A_MEXP))?;',
  'b.a(ids.at(A_MACT))?;',
  'let r0 = v[2].mul(alpha.sub(v[3])).sub(v[1]);',
 ],
 'protocol.rs':[
  'let u8_inv = u8_denominator_inverses(alpha, g_u8);',
  'pub(super) fn u8_denominator_inverses(alpha: Fp2, g_u8: Fp2)',
  'let alpha = tr.challenge_fp2();',
  'helper_pair_inverses_u8(&cols[2 * k], second, alpha, g_u8, &u8_inv)?',
  'write_h(&mut h_data, lay.h_off[hids.gdd()], &col);',
  'let mut h_data = vec![Fp::ZERO; lay.h_rows * n];',
 ]}
mutations=[]
for filename,fs in fragments.items():
 text=(HERE/'source'/filename).read_text()
 for f in fs:
  check(f in text)
  altered=text.replace(f,'MUTATED_FRAGMENT',1)
  # Mutate every occurrence for duplicate sentinels; no code executed.
  altered=altered.replace(f,'MUTATED_FRAGMENT')
  check(not all(x in altered for x in fs))
  mutations.append(dict(file=filename,fragment=f))

rows=json.loads((HERE/'census.json').read_text()); ncontrols=0
for row in rows:
 n=1<<row['log_cols']; dd=row['dd']; T=row['T']; d=4096 if row['model']=='8B' else 2048
 sizes,ls,planes,ar,hr=census(T,d,128 if d==4096 else 64,8 if d==4096 else 4,16384 if d==4096 else 8192,row['log_cols'],row['norm_window'],row['f_e'],dd)
 check(hr==row['h_rows']);check(ar==row['a_rows'])
 check(sum(len(v)*sizes[k] for k,v in ls.items())==row['u8_queries'])
 for dom in row['domains']:
  pairs=[p for p in planes if p[0]==dom['domain'] and p[1]=='U8']
  bytes_ref=sum(16*sizes[p[0]] for p in pairs)
  check(bytes_ref==dom['u8_h_bytes'])
  if pairs:
   # Omitted helper and altered domain sizes must disagree with full census.
   check(bytes_ref!=sum(16*sizes[p[0]] for p in pairs[1:]));ncontrols+=1
   check(bytes_ref!=sum(16*(sizes[p[0]]+1) for p in pairs));ncontrols+=1
 check(row['h_input_bytes']!=hr*n*16);ncontrols+=1
 # Forest materialization is always far larger than removed paired H input.
 check(row['topology_costs']['exact_column_forest_all_nodes_bytes']>row['u8_helper_data_bytes'])

# Explicitly allocate/count only tiny topology nodes, independent of formulas.
rng=random.Random(20261020103); topology_checks=0
for _ in range(80):
 widths=[1<<rng.randrange(0,8) for _ in range(rng.randrange(1,12))]+[256]
 all_nodes=[]; roots=[]
 for w in widths:
  layer=[(1,2)]*w;all_nodes.extend(layer)
  while len(layer)>1:
   layer=[((a*d+c*b)%65537,b*d%65537) for (a,b),(c,d) in zip(layer[::2],layer[1::2])]
   all_nodes.extend(layer)
  roots.append(layer[0])
 while len(roots)>1:
  a,b=roots.pop();c,d=roots.pop();node=((a*d+c*b)%65537,b*d%65537);roots.append(node);all_nodes.append(node)
 check(len(all_nodes)==2*sum(widths)-1)
 check(roots[0][0]*pow(roots[0][1],-1,65537)%65537==sum(widths)*pow(2,-1,65537)%65537)
 topology_checks+=2

result=dict(status='PASS',checks=checks,source_pins=len(pins),source_fragments=sum(map(len,fragments.values())),
 source_fragment_mutation_controls=len(mutations),census_mutation_controls=ncontrols,explicit_topology_checks=topology_checks,
 elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Exact source sentinels/pins, independent symbolic count and tiny topology; no Rust, native relation, transcript, refusal or proof validation')
(HERE/'source-mutations.json').write_text(json.dumps(mutations,indent=2)+'\n')
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
