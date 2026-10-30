"""Stage argument dispatch and public folds; no working source is edited."""
from pathlib import Path

p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block"
s=(src/"argument.rs").read_text()
needle="use super::{AttentionPublic, FeedForwardPublic};"
assert s.count(needle)==1
s=s.replace(needle,needle+'\n#[path = "argument_accuracy.rs"]\nmod accuracy;')
needle="pub(crate) struct Ctx<'a> {"
assert s.count(needle)==1
s=s.replace(needle,needle+"\n    pub accuracy:Option<&'a crate::private_block::accuracy_public::AccuracyPublic>,")
needle="pub(crate) fn define(slot: usize, ctx: &Ctx, pts: &mut Points, tr: &mut Transcript) -> Result<SlotDef, String> {"
assert s.count(needle)==1
s=s.replace(needle,needle+'''
    if ctx.lay.shape().accuracy_stack()!=crate::private_block::accuracy_precision::Stack::Legacy {
        if let Some(def)=accuracy::define_changed(slot,ctx,pts,tr)? {return Ok(def)}
    }
''')
needle="            b.public(fold_rows_i8(w, outer, inner, &eq_table_msb(&r_j)));"
assert s.count(needle)==1
s=s.replace(needle,'''            let weights=eq_table_msb(&r_j);
            let folded=if sh.accuracy_stack()==crate::private_block::accuracy_precision::Stack::Legacy {
                fold_rows_i8(w,outer,inner,&weights)
            } else {
                use crate::private_block::accuracy_fold::{Site,Axis,coefficients,fold};
                let data=ctx.accuracy.ok_or("R13 matmul requires bound accuracy data")?;
                let site=match slot {SC_QMM=>Site::Q,SC_KMM=>Site::K,SC_VMM=>Site::V,_=>Site::O};
                fold(w,outer,inner,Axis::Rows,&coefficients(sh,data,site)?,&weights)?
            };
            b.public(folded);''')
needle="            b.public(fold_cols_i8(w, rows, cols, &eq_table_msb(&r_j)));"
assert s.count(needle)==1
s=s.replace(needle,'''            let weights=eq_table_msb(&r_j);
            let folded=if sh.accuracy_stack()==crate::private_block::accuracy_precision::Stack::Legacy {
                fold_cols_i8(w,rows,cols,&weights)
            } else {
                use crate::private_block::accuracy_fold::{Site,Axis,coefficients,fold};
                let data=ctx.accuracy.ok_or("R13 FFN matmul requires bound accuracy data")?;
                let site=match slot {SC_GMM=>Site::Gate,SC_UMM=>Site::Up,_=>Site::Down};
                fold(w,rows,cols,Axis::Columns,&coefficients(sh,data,site)?,&weights)?
            };
            b.public(folded);''')
(p/"argument.parent.candidate.rs").write_text(s)

names=["tests.rs","s20_review_tests.rs","trained_calib_tests.rs","s35_tests.rs","p2_tests.rs", "grow_tests.rs","slot_ir_tests.rs","s24_tests.rs"]
for name in names:
    s=(src/name).read_text();assert "Ctx {" in s
    (p/(name.replace(".rs",".ctx.candidate.rs"))).write_text(s.replace("Ctx {","Ctx { accuracy:None,"))
s=(src/"protocol.rs").read_text()
needle="Ctx { lay, public, ff, alpha, beta, g_u8, g_exp, g_act, g_dd }"
assert s.count(needle)==2
s=s.replace(needle,"Ctx { accuracy:blk.accuracy(), lay, public, ff, alpha, beta, g_u8, g_exp, g_act, g_dd }")
(p/"protocol.ctx.candidate.rs").write_text(s)
s=(src/"run_capture.rs").read_text()
s=s.replace("OWN_SOURCE_FILES: [&str; 31]", "OWN_SOURCE_FILES: [&str; 32]")
needle="pub(super) const OWN_SOURCE_FILES: [&str; 32] = ["
assert s.count(needle)==1;s=s.replace(needle,needle+'\n    "src/private_block/argument_accuracy.rs",')
(p/"run_capture.candidate.rs").write_text(s)
s=(src/"hash_domain_tests.rs").read_text().replace("let lane: [(&str, &str); 27]", "let lane: [(&str, &str); 28]")
needle="    let lane: [(&str, &str); 28] = ["
assert s.count(needle)==1;s=s.replace(needle,needle+'\n        ("argument_accuracy.rs", include_str!("argument_accuracy.rs")),')
(p/"hash_domain_tests.candidate.rs").write_text(s)
s=(src/"s25_tests.rs").read_text()
needle='[("trained_block.rs","trained_accuracy.rs"),("witness.rs","witness_accuracy.rs")]'
assert s.count(needle)==1
s=s.replace(needle,'[("trained_block.rs","trained_accuracy.rs"),("witness.rs","witness_accuracy.rs"),("argument.rs","argument_accuracy.rs")]')
(p/"s25_tests.candidate.rs").write_text(s)
print("staged child dispatch, seven scaled public folds, Ctx callers and all source censuses")
