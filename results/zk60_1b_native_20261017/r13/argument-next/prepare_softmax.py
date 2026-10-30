"""Adapt the reviewed R12b softmax/DD bodies to R13 in a staged child."""
from pathlib import Path
import re

p=Path(__file__).resolve().parent
source=(p.parent/"working-tree/hashline/src/private_block/argument.rs").read_text()

def arm(start,end):
    s=source.split(start,1)[1].split(end,1)[0]
    # The top-level match arm ends with its own brace; the following
    # comment belongs to the next arm and is stripped separately below.
    s=s[:s.rfind("\n        }")]
    return s

dd_s=arm("        SC_SZC if sh.dd_cap > 0 => {","        SC_SZC => {")
s=arm("        SC_SZC => {","        SC_TAB => {")
dd=arm("        SC_DD => {","        SC_IO_IN | SC_IO_OUT => {")

common='''    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let(alpha,beta,g_u8,g_exp)=(ctx.alpha,ctx.beta,ctx.g_u8,ctx.g_exp);
    let(ls,lp)=(sh.limbs_sigma_s(),sh.limbs_p());
    let mut b=B::new(lay,SLOT);
    let pad_on=ALL_DOMS.into_iter().any(|d|crate::private_block::pad::pad_zero_host(d)==SLOT && !crate::private_block::pad::zero_rule_a_planes(sh,ids,d).is_empty());
    let n_pad=usize::from(pad_on);let cube=1usize<<sh.slots()[SLOT].0;
'''

def adapt(body,slot):
    body=body.replace("super::pad::","crate::private_block::pad::").replace("super::witness::","crate::private_block::witness::")
    body=body.replace("sh.sh_s","precision.score").replace("1 << F_P","1 << sh.f_p()")
    body=body.replace(".add(at(A_RSL))", ".add(limbs(v,&rsl_ix))")
    if slot=="SC_SZC":
        needle="            let lks = lk_tables(lay, Dom::S, &b.shaped, g_u8);"
        assert body.count(needle)==1
        body=body.replace(needle,needle+"\n            let rsl_ix=role(&b,low,L::Rs)?;")
    # Retain the legacy differential gate only in the unchanged legacy body.
    body=re.sub(r"\n\s*#\[cfg\(test\)\]\n\s*let s35 = super::s35_tests::Szc \{.*?\n\s*\};", "", body, flags=re.S)
    body=re.sub(r"\n\s*#\[cfg\(test\)\]\n\s*s35\.check\(b.tabs.len\(\), &poly\);", "", body)
    assert "s35.check" not in body and "let s35" not in body
    return common.replace("SLOT",slot)+body+"\n}\n"

out=(p/"argument_accuracy.rs").read_text()
out=out.replace("        // Remaining R13 changed slots are added before activation. The\n        // shared BlockPublic refusal prevents a partial proof entry point.\n","")
out=out.replace("        _=>Ok(None),",'''        SC_SZC if sh.dd_cap>0=>szc_dd(ctx,pts,tr).map(Some),
        SC_SZC=>szc(ctx,pts,tr).map(Some),
        SC_DD=>dd(ctx,tr).map(Some),
        SC_TAB=>tab(ctx,tr).map(Some),
        _=>Ok(None),''')
out+="\nfn szc_dd(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {\n"+adapt(dd_s,"SC_SZC")
out+="\nfn szc(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {\n"+adapt(s,"SC_SZC")
out+="\nfn dd(ctx:&Ctx<'_>,tr:&mut Transcript)->Result<SlotDef,String> {\n"+adapt(dd,"SC_DD")
out+='''
fn tab(ctx:&Ctx<'_>,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let data=ctx.accuracy.ok_or("R13 table relation requires bound accuracy data")?;
    let(alpha,beta,g_u8,g_exp,g_act)=(ctx.alpha,ctx.beta,ctx.g_u8,ctx.g_exp,ctx.g_act);
    let len=sh.size(Dom::Tab);let mut b=B::new(lay,SC_TAB);
    let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::Tab).is_empty();
    let tau=tr.challenge_fp2_vec(sh.log(Dom::Tab));let mu=tr.challenge_fp2_vec(3+usize::from(pad_on));
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};let th=hids.table_helpers();
    let act=crate::private_block::accuracy_act::table(data,len,beta,g_act)?;
    b.eq(&tau,0);
    b.a(ids.at(A_MU8))?;b.h(th[0])?;b.public(table_values_u8_at(len,g_u8));
    b.a(ids.at(A_MEXP))?;b.h(th[1])?;b.public(table_values_exp_at(len,ctx.public,beta,g_exp));
    b.a(ids.at(A_MACT))?;b.h(th[2])?;b.public(act.compressed);
    let mut pz=PadTerm::none();
    if pad_on {
        tab_group_is_declared(sh,ids,&[ids.at(A_MU8),ids.at(A_MEXP),ids.at(A_MACT)],&th)?;
        let bytes=b.supp(Dom::Tab,len)?;let activation=Some(b.public(act.support));
        pz.mu=mu[3];
        // PadTerm::add continues independent zeta powers across all groups.
        pz.add(bytes,&[1,4],zeta);pz.add(bytes,&[2,5],zeta);
        pz.add(activation,&[7],zeta);pz.add(activation,&[8],zeta);
    }
    b.finish(Box::new(move |v:&[Fp2]| {
        let r0=v[2].mul(alpha.sub(v[3])).sub(v[1]);
        let r1=v[5].mul(alpha.sub(v[6])).sub(v[4]);
        let r2=v[8].mul(alpha.sub(v[9])).sub(v[7]);
        v[0].mul(mu[0].mul(r0).add(mu[1].mul(r1)).add(mu[2].mul(r2)).add(pz.eval(v)))
    }),vec![])
}
'''
(p/"argument_accuracy.full.candidate.rs").write_text(out)
print("staged R13 host/softmax/DD/ACT3 table definitions; no working source edits")
