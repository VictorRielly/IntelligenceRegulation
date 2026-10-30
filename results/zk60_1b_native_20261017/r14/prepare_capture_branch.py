"""Prepare test-only native observer hooks in an independent source tree.

Does not mutate the queued arithmetic candidate or launch another heavy job.
"""
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent;BASE=HERE/'actual-working-tree';TREE=HERE/'capture-working-tree'
assert not TREE.exists()
pin=json.loads((HERE/'sol-r14-actual-build-2.source.json').read_text())
for name,want in pin['files'].items():
    source=BASE/name;assert hashlib.sha256(source.read_bytes()).hexdigest()==want,name
    target=TREE/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
src=TREE/'hashline/src/private_block'
def change(name,needle,replacement):
    path=src/name;text=path.read_text();assert text.count(needle)==1,(name,needle,text.count(needle));path.write_text(text.replace(needle,replacement,1))
shutil.copy2(HERE/'staged/split_capture.rs',src/'split_capture.rs')
change('run_capture.rs','use super::argument::{Acc, Coord, Side, SlotDef, SlotProof, Tab};',
    '#[cfg(test)]\n#[path="split_capture.rs"]\npub(crate) mod split;\n\nuse super::argument::{Acc, Coord, Side, SlotDef, SlotProof, Tab};')
needle='    let run_capture_before = if matches!(side, Side::Verify { .. }) { super::run_capture::checkpoint(tr) } else { None };'
change('argument.rs',needle,needle+'\n    #[cfg(test)]\n    let split_capture_before = if matches!(side, Side::Verify { .. }) { super::run_capture::split::checkpoint(tr) } else { None };')
needle='        super::run_capture::slot(&def, acc, &slots[s], &rho_full, c, g_val, run_capture_before, tr);'
change('argument.rs',needle,needle+'\n        super::run_capture::split::slot(&def, acc, &slots[s], &rho_full, c, g_val, split_capture_before, tr);')
needle='        let mut def = argument::split::define(slot, p, ctx, &mut points, sources, tr)?;'
change('split_protocol.rs',needle,'        #[cfg(test)]\n        super::run_capture::split::start_slot(side, tr);\n'+needle)
needle='    protocol::absorb_root(tr, b"H", &v.h_root, s.h_rows, sh.log_cols);'
change('split_protocol.rs',needle,needle+'\n    #[cfg(test)]\n    super::run_capture::split::core_roots(v.a_root, v.h_root, v.mask_root, tr);')
needle='    zk::mask_verify_tagged(&v.mask_root, &specs, &acc.fs, v.mask_open, ntt, tr, &tag)'
change('split_protocol.rs',needle,'    #[cfg(test)]\n    let capture_m = super::run_capture::split::checkpoint(tr);\n'+needle)
needle='        .map_err(|e| format!("R14 M: {e}"))?;'
change('split_protocol.rs',needle,needle+'\n    #[cfg(test)]\n    super::run_capture::split::mask(&specs, &v.mask_root, &acc.fs, v.mask_open, ntt, capture_m, tr);')
for role,root,opening,h in [('A','v.a_root','v.a_open','false'),('H','v.h_root','v.h_open','true')]:
    needle=f'''    pcs::verify_zk_tagged(
        &params,
        &zko,
        &Commitment {{
            root: {root},'''
    change('split_protocol.rs',needle,f'    #[cfg(test)]\n    let capture_{role.lower()} = super::run_capture::split::checkpoint(tr);\n'+needle)
    needle=f'    .map_err(|e| format!("R14 {role}: {{e}}"))?;'
    change('split_protocol.rs',needle,needle+f'\n    #[cfg(test)]\n    super::run_capture::split::pcs(capture_geometry(p, {h}, {root}), &'+('hc' if h=='true' else 'ac')+f', {opening}, ntt, capture_{role.lower()}, tr, None);')
path=src/'split_protocol.rs';path.write_text(path.read_text()+'''
#[cfg(test)]
fn capture_geometry(p: &SplitProfile,h: bool,root: crate::merkle::Digest) -> super::run_capture::Geom {
    let s=p.layout();let rows=if h{s.h_rows}else{s.a_rows};
    let lay=Layout::for_shape(p.base()).expect("already checked native layout");
    super::run_capture::Geom{role:if h{"H"}else{"A"},commitment_kind:"block",params:protocol::pcs_params_at(p.base()),root,rows,
        data_rows:if h{s.h_data_rows}else{s.a_data_rows},site_rows:site_rows(p,h),
        sum_rows:if h{Some(u_rows(p,&lay).expect("native H audit already checked U"))}else{None},
        prox_row:rows-2,boundary:None,claim_sources:vec![]}
}
''')
needle='    pub(crate) fn input(&self) -> Digest {'
change('split_run.rs',needle,'''    #[cfg(test)]
    pub(crate) fn capture_header(&self) -> Result<super::run_capture::split::Header,String> {
        Ok(super::run_capture::split::Header {
            profiles:self.plan.stages.iter().map(|p|SplitProfile::new(p.base().clone())).collect::<Result<Vec<_>,_>>()?,
            block_digests:self.plan.blocks.clone(),plan:self.plan.digest,model:self.plan.model,context:self.plan.context,
            binding:self.binding,input:self.input,output:self.output,scales:self.plan.scales.clone(),
        })
    }
'''+needle)
needle='        self.st.begin_stage(k, &self.blocks[k], &mut self.tr)?;'
change('split_run.rs',needle,'        #[cfg(test)]\n        super::run_capture::split::stage_begin(k, seg.b_root, &self.tr);\n'+needle)
needle='        self.k += 1;\n        Ok(())'
change('split_run.rs',needle,'        #[cfg(test)]\n        super::run_capture::split::stage_end(k, end, &self.tr);\n'+needle)
needle='''            return Err("R14 run: incomplete or failed proof stream".into());
        }
        Ok(())'''
change('split_run.rs',needle,'''            return Err("R14 run: incomplete or failed proof stream".into());
        }
        #[cfg(test)]
        super::run_capture::split::run_accepted();
        Ok(())''')
needle='''    spec.check_opening(claims, tr)?;
    pcs::verify_zk_tagged('''
change('split_endpoint.rs',needle,'''    spec.check_opening(claims, tr)?;
    #[cfg(test)]
    let capture = super::run_capture::split::checkpoint(tr);
    pcs::verify_zk_tagged(''')
needle='''        &spec.tag,
    )
}'''
change('split_endpoint.rs',needle,'''        &spec.tag,
    )?;
    #[cfg(test)]
    super::run_capture::split::joint_pcs(spec, root.root, claims, opening, ntt, capture, tr);
    Ok(())
}''')
shutil.copy2(HERE/'staged/split_capture_tests.rs',src/'split_capture_tests.rs')
needle='mod split_dense_tests;'
change('argument.rs',needle,needle+'\n#[cfg(test)]\n#[path="split_capture_tests.rs"]\nmod split_capture_tests;')
for name in ['split_capture.rs','split_capture_tests.rs','split_run.rs','split_protocol.rs','split_endpoint.rs']:
    subprocess.run(['/home/victor/.cargo/bin/rustfmt','--edition','2021',str(src/name)],check=True)
names=set(pin['files'])|{'hashline/src/private_block/split_capture.rs','hashline/src/private_block/split_capture_tests.rs'}
files={name:hashlib.sha256((TREE/name).read_bytes()).hexdigest() for name in sorted(names)}
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in files.items()).encode()).hexdigest()
(HERE/'sol-r14-capture-build-1.source.json').write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
(HERE/'CAPTURE_BRANCH_STATE.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'source':digest,'files':len(files),
    'status':'Uncompiled native test-only observer hooks in independent tree; arithmetic candidate7152ef1a unchanged',
    'pending':'compile, native accepted/rejected run captures, exact allow-list/array resolution/source-map tests and rank/CFS/NL1/joint adapter; no privacy acceptance'},indent=2)+'\n')
print(json.dumps({'capture_source':digest,'files':len(files),'status':'uncompiled'}))
