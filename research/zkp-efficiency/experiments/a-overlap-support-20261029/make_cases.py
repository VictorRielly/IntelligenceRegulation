from pathlib import Path
import json,sys
D=Path(__file__).resolve().parent
import model,legacy_catalog as base
rows=json.loads((D/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows'];seen=set();cases=[]
for r in rows:
 if '8b-t128' in r['profile'] and r['f_e']==9 and r['profile'] not in seen:
  seen.add(r['profile']);cases.append((model.geometry(r),0,True,r))
for log in [3,5]:
 for dd in [0,32]:
  for mode in [0,1,2]:
   g=model.Geometry('synthetic-small',4,16,32,4,4,2,log,log,ln=3,ls=2,lp=2,dd=dd)
   cases.append((g,mode,False,{}))
text=[];metadata=[]
for g,mode,source,r in cases:
 logs=g.domains();hs=g.helpers();doms='T Ht L D Q Kv S F Tab Dd'.split()
 text.append('Case{sh:Shape{log_cols:%d,dd_cap:%d,logs:[%s],ls:%d,h24:true},t:%d,d:%d,f:%d,h:%d,dh:%d,kv:%d,mode:%d,source:%s}'%(g.row,g.dd,','.join(str(logs[x]) for x in doms),g.ls,g.t,g.d,g.f,g.h,g.dh,g.kv,mode,str(source).lower()))
 metadata.append(dict(geometry=g.__dict__,mode=mode,source=source,native_census=r))
(D/'cases.rs').write_text('fn cases()->Vec<Case>{vec!['+','.join(text)+']}\n')
(D/'case-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(len(cases),'public/synthetic cases')
