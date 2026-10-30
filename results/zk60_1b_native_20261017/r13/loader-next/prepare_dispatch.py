"""Stage record-aware native witness/streaming run preflight paths."""
from pathlib import Path

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'

def once(s,old,new):
    assert s.count(old)==1,old[:100]
    return s.replace(old,new)

s=(src/'trained_statement.rs').read_text()
needle='impl LayerRecord {'
s=once(s,needle,needle+'''
    /// Reconstruct the trusted layer's entire stage context, including the
    /// R13 denominator that is not a base calibration shift.
    pub(crate) fn shape_at(&self,base:&Shape)->Result<Shape,String> {
        self.check_accuracy_gate(base)?;
        let shape=if has_own(&self.own) {base.with_layer_calibration(&apply_own(&base.norm_calibration(),&self.own)?)?} else {base.clone()};
        match self.accuracy_gate_shift {Some(g)=>shape.with_accuracy_gate_shift(g),None=>Ok(shape)}
    }
''')
(out/'trained_statement.dispatch.candidate.rs').write_text(s)

s=(src/'run.rs').read_text()
needle='''        if blocks.len() == rs.l {
            blocks_fit_the_shape(blocks, &rs.sh)?;
        }
        let digests: Vec<Digest> = blocks.iter().map(|b| b.digest()).collect();
        Self::new_bound_from_digests(rs, context, expected, digests, block_scales, model)'''
s=once(s,needle,'''        if blocks.len()==rs.l && rs.sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {
            blocks_fit_the_shape(blocks,&rs.sh)?;
        }
        let digests:Vec<Digest>=blocks.iter().map(|b|b.digest()).collect();
        let st=Self::new_bound_from_digests(rs,context,expected,digests,block_scales,model)?;
        if st.rs.sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            for (k,block) in blocks.iter().enumerate() {block.check_for_shape(&st.stage_shape(k)?).map_err(|e|format!("private run: block{k}: {e}"))?;}
        }
        Ok(st)''')
needle='    fn fit_the_shape(&mut self, sh: &Shape) -> Result<(), String>;'
s=once(s,needle,needle+'''
    /// R13 checks the actual stage context before the run header. A
    /// streaming source may reload public blocks here; it still retains at
    /// most one. Legacy sources keep their original preflight path.
    fn fit_the_stages(&mut self,st:&RunStatement)->Result<(),String> {
        if st.rs.sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {return self.fit_the_shape(&st.rs.sh);}
        if self.count()!=st.rs.l {return Err("private run: public block count differs from the stage count".into());}
        for k in 0..st.rs.l {
            let sh=st.stage_shape(k)?;
            self.block(k)?.check_for_shape(&sh).map_err(|e|format!("private run: block{k}: {e}"))?;
        }
        Ok(())
    }
''')
assert s.count('blocks.fit_the_shape(sh)?;')==2
s=s.replace('blocks.fit_the_shape(sh)?;','blocks.fit_the_stages(st)?;')
(out/'run.dispatch.candidate.rs').write_text(s)

s=(out/'trained_block.arrays.candidate.rs').read_text()
s=once(s,'witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x_in)',
    'witness_for_block(sh,blk,x_in)')
needle='''pub(crate) fn parity(sh: &Shape, blk: &BlockPublic, x_in: &[i16], x_out: &[i16]) -> Result<Witness, String> {'''
assert s.count(needle)==1
s=once(s,needle,'''fn witness_for_block(sh:&Shape,blk:&BlockPublic,input:&[i16])->Result<Witness,String> {
    match blk.accuracy() {
        Some(data)=>{
            let local=sh.clone().with_accuracy_gate_shift(data.folds().gate.shift)?;
            witness::build_for_block(&local,blk,input)
        },
        None=>witness::build_shaped(sh,blk.attention(),blk.feed_forward(),input),
    }
}

'''+needle)
for old,new in [
    ('witness::build_shaped(sh, layer.blk.attention(), layer.blk.feed_forward(), x_in)','witness_for_block(sh,&layer.blk,x_in)'),
    ('witness::build_shaped(&other, layer.blk.attention(), layer.blk.feed_forward(), x_in)','witness_for_block(&other,&layer.blk,x_in)'),
    ('witness::build_shaped(&self.chain.shapes[k], blk.attention(), blk.feed_forward(), &x)','witness_for_block(&self.chain.shapes[k],&blk,&x)'),
    ('let ssh = if has_own(&cur.record.own) { sh.with_layer_calibration(&apply_own(&sh.norm_calibration(), &cur.record.own)?)? } else { sh.clone() };',
     'let ssh=cur.record.shape_at(&sh)?;'),
    ('witness::build_shaped(&ssh, cur.blk.attention(), cur.blk.feed_forward(), &x)','witness_for_block(&ssh,&cur.blk,&x)'),
    ('let mut lays: Vec<(NormCalibration, super::layout::Layout)> = Vec::new();','let mut lays:Vec<(Shape,super::layout::Layout)>=Vec::new();'),
    ('lays.iter().position(|(v, _)| *v == ssh.norm_calibration())','lays.iter().position(|(v,_)|*v==ssh)'),
    ('lays.push((ssh.norm_calibration(), super::layout::Layout::for_shape(&ssh)?));','lays.push((ssh.clone(),super::layout::Layout::for_shape(&ssh)?));'),
]:s=once(s,old,new)
(out/'trained_block.dispatch.candidate.rs').write_text(s)
print('Staged whole stage-record reconstruction, pre-header R13 public validation and witness dispatch; no install/activation.')
