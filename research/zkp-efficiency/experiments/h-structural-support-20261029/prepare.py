"""Local source extraction only; no foreign code or native prover execution."""
from pathlib import Path
import hashlib,json,shutil
D=Path(__file__).resolve().parent
R=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree')
def extract(s,name):
    at=s.index('fn '+name+'('); start=s.rfind('\n',0,at)+1; brace=s.index('{',at);dep=1;i=brace+1
    while dep:dep+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[start:i]+'\n'
pins=[]
for name in ['zkp-core/src/field.rs','zkp-core/src/pcs.rs','zkp-core/src/mle.rs','hashline/src/private_block/protocol.rs','hashline/src/private_block/layout.rs','hashline/src/private_block/shape.rs','hashline/src/private_block/argument.rs','hashline/src/private_block/argument_accuracy.rs']:
    p=R/name;b=p.read_bytes();q=D/'native'/name;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
    pins.append(dict(path=str(p),snapshot=str(q.relative_to(D)),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b)))
for name in ['model.py','legacy_catalog.py','run_bounded.py']:
    shutil.copyfile(D.parent/'public-row-support-20261029'/name,D/name)
pcs=(D/'native/zkp-core/src/pcs.rs').read_text();mle=(D/'native/zkp-core/src/mle.rs').read_text()
protocol=(D/'native/hashline/src/private_block/protocol.rs').read_text();layout=(D/'native/hashline/src/private_block/layout.rs').read_text();shape=(D/'native/hashline/src/private_block/shape.rs').read_text();arg=(D/'native/hashline/src/private_block/argument.rs').read_text()
(D/'native_groups.rs').write_text('\n'.join(extract(pcs,n) for n in ['zpart_weights','zkey_weights','group_zclaims','zk_rhos']))
(D/'native_audit.rs').write_text('\n'.join(extract(protocol,n) for n in ['part_rows','audit_claims']))
(D/'serial_eq.rs').write_text('\n'.join(extract(mle,n) for n in ['eq_table','eq_table_msb']).replace('.par_iter_mut()', '.iter_mut()'))
start=layout.index('pub(crate) struct HIds');end=layout.index('// ---- lookups',start)
(D/'hids.rs').write_text(layout[start:end])
(D/'h_domains.rs').write_text('impl Shape{\n'+extract(shape,'h_plane_doms')+'}\n')
(D/'builder.rs').write_text(extract(arg,'build_claim'))
(D/'h_builder.rs').write_text("impl<'a>B<'a>{\n"+extract(arg,'h')+'}\n')
(D/'sum_claim.rs').write_text(extract(protocol,'logup_sum_claim'))
start=layout.index('        let mut row = 0usize;',layout.index('        let a_rows = a_prox + 2;'))
end=layout.index('        let h_data_rows = row;',start)+len('        let h_data_rows = row;')
(D/'h_offsets.rs').write_text('fn offsets(sh:&Shape)->(Vec<(usize,usize)>,usize){\nlet h_doms=sh.h_plane_doms();let n=1usize<<sh.log_cols;\n'+layout[start:end]+'\n(h_off,h_data_rows)\n}\n')
src=R.parent/'NATIVE_LAYOUT_CENSUS.json';shutil.copyfile(src,D/'native/NATIVE_LAYOUT_CENSUS.json');pins.append(dict(path=str(src),snapshot='native/NATIVE_LAYOUT_CENSUS.json',sha256=hashlib.sha256(src.read_bytes()).hexdigest(),bytes=src.stat().st_size))
(D/'native-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
(D/'extraction.json').write_text(json.dumps(dict(exact=['HIds struct/impl','Shape::h_plane_doms','B::h','build_claim','logup_sum_claim','part_rows','audit_claims','zpart_weights','zkey_weights','group_zclaims','zk_rhos','Layout H offset loop'],adapters=['equality iterator serial only','local Shape methods supplied public geometry','local Layout wrapper uses unchanged extracted H offset loop','dd_lapse always false, as release','synthetic scripted challenges, not native FS','H evaluation plane/slot schedule source-derived locally, native define not executed']),indent=2)+'\n')
import model,legacy_catalog
cases=[];metadata=[];seen=set()
for row in json.loads(src.read_text())['rows']:
    if '8b-t128' not in row['profile'] or row['f_e']!=9 or row['profile'] in seen:continue
    seen.add(row['profile']);g=model.geometry(row)
    logs=g.domains();helpers=g.helpers()
    metadata.append(dict(profile=row['profile'],dd=bool(g.dd),log_cols=g.row,logs=logs,helpers=helpers,expected_rows=row['h_rows'],expected_sites=row['h_sites'],expected_data=row['h_mask_base']))
    l=','.join(str(logs[k]) for k in ['L','D','Q','Kv','S','F','Tab','Dd'])
    h=','.join(str(helpers.get(k,0)) for k in ['L','D','Q','Kv','S','F','Tab','Dd'])
    cases.append(f'Shape{{log_cols:{g.row},dd_cap:{g.dd},logs:[{l}],hs:[{h}]}}')
(D/'cases.rs').write_text('fn source_cases()->Vec<Shape>{vec!['+','.join(cases)+']}\n')
(D/'source-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('Pinned',len(pins),'source inputs; extracted unchanged native H builders and layout loop')
