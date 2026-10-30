import pathlib,hashlib,json,difflib
D=pathlib.Path(__file__).resolve().parent
R=pathlib.Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree')
paths=['zkp-core/src/pcs.rs','zkp-core/src/field.rs','zkp-core/src/mle.rs','hashline/src/private_block/protocol.rs','hashline/src/private_block/run.rs','hashline/src/private_block/boundary.rs','hashline/src/private_block/shape.rs','hashline/src/private_block/argument.rs','hashline/src/zk.rs','hashline/Cargo.toml']
pins=[]
for f in paths:
 p=R/f;b=p.read_bytes();q=D/'native'/f;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
 pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
for name in ['model.py','legacy_catalog.py']:
 p=D.parent/'fresh-eq-doubling-20261029'/name;b=p.read_bytes();(D/name).write_bytes(b)
 pins.append(dict(path=str(p),snapshot=name,sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),kind='prior locally authored public metadata model'))
p=R.parent/'NATIVE_LAYOUT_CENSUS.json';b=p.read_bytes();(D/'native/NATIVE_LAYOUT_CENSUS.json').write_bytes(b)
pins.append(dict(path=str(p),snapshot='native/NATIVE_LAYOUT_CENSUS.json',sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
def extract(s,name):
 at=s.index('fn '+name+'('); start=s.rfind('\n',0,at)+1; brace=s.index('{',at);dep=1;i=brace+1
 while dep:
  dep+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[start:i]+'\n'
pcs=(R/'zkp-core/src/pcs.rs').read_text();mle=(R/'zkp-core/src/mle.rs').read_text()
eq=extract(mle,'eq_table')+'\n'+extract(mle,'eq_table_msb')
# No Rayon dependency: same native branch/arithmetic with serial iterators.
eq=eq.replace('.par_iter_mut()', '.iter_mut()')
(D/'serial_eq.rs').write_text(eq)
names=['zpart_weights','zkey_weights','group_zclaims','zk_rhos']
(D/'native_groups.rs').write_text('\n'.join(extract(pcs,x) for x in names))
old=extract(pcs,'group_zclaims')
new=old.replace('fn group_zclaims(', 'fn group_zclaims_with_columns(').replace('log_cols: u32) ->','log_cols: u32, columns: bool) ->').replace('let cw = zkey_weights(&key, log_cols);','let cw = if columns { zkey_weights(&key, log_cols) } else { Vec::new() };')
(D/'candidate.rs').write_text(new)
wrapper='fn group_zclaims(claims: &[ZClaim], rows: usize, log_cols: u32) -> Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> {\n    group_zclaims_with_columns(claims, rows, log_cols, true)\n}\n\n'
patched=pcs.replace(old,wrapper+new)
needle='let groups = group_zclaims(claims, rows, cm.params.log_cols);'
assert patched.count(needle)==1
patched=patched.replace(needle,'let groups = group_zclaims_with_columns(claims, rows, cm.params.log_cols, false);')
(D/'native-prover-columns.patch').write_text(''.join(difflib.unified_diff(pcs.splitlines(True),patched.splitlines(True),fromfile='a/zkp-core/src/pcs.rs',tofile='b/zkp-core/src/pcs.rs')))
(D/'extraction.json').write_text(json.dumps({'exact_functions':names,'serial_eq_adapter':'par_iter_mut -> iter_mut only','original_group_sha256':hashlib.sha256(old.encode()).hexdigest(),'candidate_sha256':hashlib.sha256(new.encode()).hexdigest(),'patch_applied_to_production':False},indent=2)+'\n')
print('Pinned',len(pins),'files; extracted four native helpers; generated unapplied patch')

# Only public geometry and synthetic fresh points/coefficients: no native witnesses.
import model,legacy_catalog
rows=json.loads((D/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows'];seen=set();cases=[];meta=[]
for row in rows:
 if '8b-t128' not in row['profile'] or row['f_e']!=9 or row['profile'] in seen:continue
 seen.add(row['profile']);g=model.geometry(row)
 for cm in ['A','H']:
  sites=[p for ss in legacy_catalog.catalog(g)for p in ss if p.cm==cm];nrows=row[cm.lower()+'_rows'];keys={}
  for p in sites:keys[(p.slot,p.tail,p.c0)]=1
  want=len(keys)+(cm=='H');label=('DD' if g.dd else 'nonDD')+'-'+cm
  lines=[]
  fixed={}
  for p in sites:
   coords=[]
   for k,v in p.coords:
    if k=='rho':coords.append(f'r{v}')
    elif k=='flip':coords.append(f'f{v}')
    else:
     if v not in fixed:fixed[v]=len(fixed)
     coords.append(f'x{fixed[v]}')
   lines.append(f'{p.slot}/{p.log}/{p.c0}/{p.pair}/{",".join(coords)}')
  literal=json.dumps('\n'.join(lines))
  cases.append(f'{len(cases)}=>sized_parse({literal},{nrows},{str(cm=="H").lower()},{len(fixed)},{want},"{label}",s)')
  meta.append(dict(label=label,source_profile=row['profile'],rows=nrows,log_cols=14,claims=len(sites)+(cm=='H'),groups=want,scope='Synthetic row placement/coefficients/points at public source-derived descriptor and row dimensions. No native constructor/witness/proof.'))
(D/'sized.rs').write_text('fn sized_fixture(case:usize,s:&mut u64)->(Vec<ZClaim>,usize,u32,usize,&\'static str){match case{'+','.join(cases)+',_=>panic!("case")}}\n')
(D/'sized-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
