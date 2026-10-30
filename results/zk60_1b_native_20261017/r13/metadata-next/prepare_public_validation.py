"""Stage strict component validation while keeping proof activation refused."""
from pathlib import Path

out=Path(__file__).resolve().parent
root=out.parent/'working-tree/hashline/src/private_block.rs'
s=root.read_text()
needle='    pub(crate) fn accuracy(&self) -> Option<&accuracy_public::AccuracyPublic> { self.accuracy.as_ref() }'
assert s.count(needle)==1
s=s.replace(needle,needle+'''

    /// Verifier-derived R13 public context. Calling this validates the
    /// component; the shared proof entry still has its activation refusal.
    pub(crate) fn check_accuracy_for_shape(&self,sh:&shape::Shape)->Result<(),String> {
        if sh.accuracy_stack()==accuracy_precision::Stack::Legacy {
            return Err("R13 public validation requires a registered accuracy profile".into());
        }
        sh.check_constructed()?;
        self.attention.check_for_shape(sh)?;
        self.feed_forward.check_for_shape(sh)?;
        let data=self.accuracy().ok_or("R13 profile is missing its public accuracy data")?;
        let geometry=accuracy_public::Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
        data.check_for_registry(sh.accuracy_registry(),geometry,sh.accuracy_base(),sh.accuracy_stack())?;
        if data.folds().gate.shift!=sh.accuracy_gate_shift {
            return Err("R13 public folded gate denominator differs from the stage shape".into());
        }
        if [&self.attention.wq,&self.attention.wk,&self.attention.wv,&self.attention.wo,&self.attention.gamma_a,
            &self.feed_forward.gamma_m,&self.feed_forward.wg_t,&self.feed_forward.wu_t,&self.feed_forward.wd_t]
            .into_iter().any(|words|words.contains(&i8::MIN)) {
            return Err("R13 public weights/gains must be symmetric int8".into());
        }
        if sh.dd_cap>0 {self.attention.dd_e_column(sh.dd_cap)?;}
        Ok(())
    }
''')
assert 'R13 proof profiles remain disabled until all host and lookup relations are integrated' in s
(out/'private_block.candidate.rs').write_text(s)
print('Staged strict R13 public component validation; proof activation remains refused.')
