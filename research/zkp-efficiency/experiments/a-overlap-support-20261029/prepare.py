"""Verify pinned local public source, re-extract helpers, generate case metadata."""
from pathlib import Path
import json,hashlib,re,runpy
D=Path(__file__).resolve().parent
for pin in json.loads((D/'native-pins.json').read_text()):
 p=Path(pin['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==pin['sha256'],str(p)
 assert hashlib.sha256((D/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256']
def extract(s,name):
 at=s.index('fn '+name+'(');start=s.rfind('\n',0,at)+1;brace=s.index('{',at);dep=1;i=brace+1
 while dep:dep+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[start:i]+'\n'
layout=(D/'native/hashline/src/private_block/layout.rs').read_text();arg=(D/'native/hashline/src/private_block/argument.rs').read_text();sh=(D/'native/hashline/src/private_block/shape.rs').read_text();acc=(D/'native/hashline/src/private_block/accuracy_layout.rs').read_text()
(D/'a_constants.rs').write_text('\n'.join(re.findall(r'pub\(crate\) const (?:A_\w+|N_A|N_LIMBS|LN_TOY|LS_TOY|LP_TOY): usize = [^;]+;',layout))+'\n')
start=acc.index('#[derive');end=acc.index('    /// Emit byte and exact top-bit pins')
(D/'a_ids.rs').write_text('use super::accuracy_precision::Stack;\nuse super::layout::*;\n'+acc[start:end]+'}\n')
(D/'a_domains.rs').write_text('impl Shape{\n'+extract(sh,'a_plane_doms')+'}\n')
start=layout.index('        let mut a_off = Vec::with_capacity(a_doms.len());');end=layout.index('        let a_data_rows = row;',start)+len('        let a_data_rows = row;')
(D/'a_offsets.rs').write_text('fn offsets(sh:&Shape)->(Vec<usize>,usize){\nlet a_doms=sh.a_plane_doms();let n=1usize<<sh.log_cols;let mut row=0usize;\n'+layout[start:end]+'\n(a_off,a_data_rows)\n}\n')
(D/'a_builder.rs').write_text("impl<'a>B<'a>{\n"+extract(arg,'a_slice')+'}\n')
(D/'claim_point.rs').write_text(extract(arg,'claim_point'))
runpy.run_path(str(D/'make_cases.py'),run_name='__main__')
print('Pinned local helper extraction PASS; native define/FS not executed')
