"""Stage full v2 public-array import, retaining the shared proof refusal."""
from pathlib import Path

out=Path(__file__).resolve().parent
s=(out/'trained_block.profile.candidate.rs').read_text()

def once(old,new):
    global s
    assert s.count(old)==1,old[:100]
    s=s.replace(old,new)

once('fn table_keys_of(c: &J, what: &str) -> Result<TableKeys, String> {','''fn table_keys_of(c:&J,what:&str)->Result<TableKeys,String> {
    table_keys_for_registry(c,what,None)
}
fn table_keys_for_registry(c:&J,what:&str,registry:Option<super::accuracy_tables::Registry>)->Result<TableKeys,String> {''')
once('''    if crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, tk.silu.0, tk.silu.1).is_none() {''','''    let member_ok=match registry {
        Some(r)=>r.permits(tk.silu),
        None=>crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu,tk.silu.0,tk.silu.1).is_some(),
    };
    if !member_ok {''')
once('''        let tk = table_keys_of(m.get("constants").map_err(ctx)?, &mpath.display().to_string())?;''','''        let tk=table_keys_for_registry(m.get("constants").map_err(ctx)?,&mpath.display().to_string(),
            if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {None} else {Some(sh.accuracy_registry())})?;''')
needle='''        let arrays = m.get("arrays").map_err(ctx)?;'''
once(needle,needle+'''
        let accuracy_loaded=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {
            for key in ["m_q","m_k","m_v","m_o","m_g","m_u","m_d","silu_groups","silu_group_ids"] {
                if arrays.opt(key).is_some() {return Err(ctx(format!("legacy export carries R13 array `{key}`")));}
            }
            None
        } else {
            let local=sh.with_layer_calibration(&lc.cal).map_err(ctx)?;
            let geometry=super::accuracy_public::Geometry{width:local.width,query_width:local.q_width(),kv_width:local.kv_heads*local.head_dim,hidden:local.hidden};
            // Read/hash narrow public data before any large weight array.
            Some(accuracy::load_for_registry(local.accuracy_registry(),&dir,arrays,self.accuracy_stack,geometry,local.accuracy_base(),tk.silu).map_err(ctx)?)
        };
''')
needle='''            expect.par_iter().map(|(name, dt, shp)| load_array_checked'''
once(needle,'''            expect.par_iter().filter(|(name,_,_)|self.accuracy_stack==super::accuracy_precision::Stack::Legacy || *name!="act").map(|(name, dt, shp)| load_array_checked''')
once('''        let act = get("act")?;
        act.expect("act", Dtype::I16, &[256])?;''','''        let act=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {
            let a=get("act")?;a.expect("act",Dtype::I16,&[256])?;Some(a)
        } else {None};''')
once('''        let (gact, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, tk.silu.0, tk.silu.1).ok_or_else(|| ctx(format!("silu_member {:?} is not in the frozen SiLU registry", tk.silu)))?;
        if act.i16s() != gact.to_vec() {
            return Err(ctx(format!("the exported act table is not the frozen SiLU member {:?}", tk.silu)));
        }''','''        // R13's ACT relation uses AccuracyPublic exclusively. Keep the old
        // typed field at one canonical, fixed member; its bytes remain bound
        // by the block digest, and the actual raw ACT tables are recorded.
        let member=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {tk.silu} else {(-3,-11)};
        let(gact,_)=crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu,member.0,member.1)
            .ok_or_else(||ctx(format!("unknown SiLU member {member:?}")))?;
        if let Some(act)=&act {if act.i16s()!=gact.to_vec() {
            return Err(ctx(format!("the exported act table is not the frozen SiLU member {:?}",tk.silu)));
        }}''')
once('''        let ff = FeedForwardPublic::new_shaped(sh, &fw[0], &fw[1], &fw[2], &fw[3], &act.i16s()).map_err(ctx)?;
        let blk = BlockPublic::new(public, ff);''','''        let ff=FeedForwardPublic::new_shaped(sh,&fw[0],&fw[1],&fw[2],&fw[3],&gact).map_err(ctx)?;
        let mut blk=BlockPublic::new(public,ff);
        if let Some(loaded)=accuracy_loaded {
            let g=loaded.accuracy.folds().gate.shift;
            blk=blk.with_accuracy(loaded.accuracy);
            let local=sh.with_layer_calibration(&lc.cal)?.with_accuracy_gate_shift(g)?;
            blk.check_accuracy_for_shape(&local).map_err(ctx)?;
        }''')
once('''        record.own = own;''','''        record.own = own;
        record.accuracy_gate_shift=blk.accuracy().map(|a|a.folds().gate.shift);''')
(out/'trained_block.arrays.candidate.rs').write_text(s)
print('Staged v2 typed public import, strict registry/raw ACT regeneration and per-layer scalar record; no install/activation.')
